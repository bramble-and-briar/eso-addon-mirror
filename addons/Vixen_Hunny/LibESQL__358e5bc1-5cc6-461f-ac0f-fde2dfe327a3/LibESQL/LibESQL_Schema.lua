-- ESQL table registry.
--
-- A table definition:
--   name, desc            table name and one-line description
--   key                   primary-key column (enables fast "WHERE key = x" lookups)
--   columns               { {name, type, desc, get}, ... }
--                         type: int | num | text | bool. `get(row)` makes the column lazy:
--                         it is computed the first time a query reads it.
--   build(rows, def)      fills `rows` (array of row tables keyed by lower-case column names)
--   live = true           rebuild on every query (inventory, effects, ...) instead of caching
--   scan = {...}          rows come from an id scan (abilities, items); see EnsureScanned
--   lookup(key) -> row    optional direct fetch by primary key
--
-- Other add-ons register their own tables the same way: LibESQL.RegisterTable(def).
-- Tables are built on first use inside the query coroutine, so builders call
-- ESQL.Tick() in their loops and must not yield inside pcall.

local E = LibESQL
local lower, format = string.lower, string.format

E.tables = E.tables or {}
E.tableOrder = E.tableOrder or {}

local function normalizeColumns(def)
    local cols, index = {}, {}
    for i, c in ipairs(def.columns or {}) do
        local col = c
        if c[1] then
            col = { name = c[1], type = c[2] or "text", desc = c[3] or "", get = c[4] }
        end
        col.key = lower(col.name)
        col.position = i
        cols[i] = col
        if index[col.key] then error("ESQL: duplicate column " .. col.key .. " in " .. def.name) end
        index[col.key] = col
    end
    def.columns, def.colIndex = cols, index
end

function E.RegisterTable(def)
    def.name = lower(def.name)
    normalizeColumns(def)
    if def.key then def.key = lower(def.key) end
    def.kind = def.kind or (def.scan and "scan") or (def.live and "live") or "static"
    if def.scan and not def.lookup then
        local scan = def.scan
        def.lookup = function(id)
            id = tonumber(id)
            if not id or id < 1 or id ~= math.floor(id) then return nil end
            local ok, exists = pcall(scan.exists, id)
            if ok and exists then return scan.makeRow(id) end
            return nil
        end
    end
    if def.kind == "static" and def.key and not def.lookup then
        def.lookup = function(k)
            if not def.index then
                local idx = {}
                local key = def.key
                for _, r in ipairs(E.GetRows(def)) do
                    local v = r[key]
                    if v ~= nil then idx[E.SQL.NormKey(v)] = r end
                end
                def.index = idx
            end
            return def.index[E.SQL.NormKey(k)]
        end
    end
    if not E.tables[def.name] then
        E.tableOrder[#E.tableOrder + 1] = def.name
    end
    E.tables[def.name] = def
    return def
end

function E.GetTable(name)
    return E.tables[lower(name)]
end

---------------------------------------------------------------------------
-- Row access
---------------------------------------------------------------------------
function E.GetRows(def)
    if def.kind == "scan" then return E.Materialize(def) end
    if def.rows then return def.rows end -- user / temp tables
    if def.cache and not def.live then return def.cache end
    local rows = {}
    if def.build then
        def.build(rows, def)
    end
    if not def.live then def.cache = rows end
    return rows
end

-- fn(row) returns true to stop
function E.ForEachRow(def, fn)
    if def.kind == "scan" then
        E.EnsureScanned(def)
        local ranges, makeRow = def.ranges, def.scan.makeRow
        for i = 1, #ranges, 2 do
            for id = ranges[i], ranges[i + 1] do
                if fn(makeRow(id)) then return true end
            end
        end
        return false
    end
    local rows = E.GetRows(def)
    for i = 1, #rows do
        if fn(rows[i]) then return true end
    end
    return false
end

function E.Materialize(def)
    if def.kind ~= "scan" then return E.GetRows(def) end
    local out = {}
    E.ForEachRow(def, function(r) out[#out + 1] = r; E.Tick() end)
    return out
end

function E.RefreshTables(name)
    local n = 0
    for tname, def in pairs(E.tables) do
        if (not name or tname == name) and def.kind ~= "user" then
            def.cache, def.index = nil, nil
            if def.onRefresh then def.onRefresh(def) end
            n = n + 1
        end
    end
    if name and n == 0 then E.SQL.Fail("no table '%s'", name) end
    return n
end

---------------------------------------------------------------------------
-- Id scans (abilities, items)
---------------------------------------------------------------------------
-- def.scan = { from, to, gap, exists(id), makeRow(id), label }
-- The id list is stored in SavedVariables per API version as a compact
-- base-36 string of (gap, run-length) pairs.

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local function toB36(n)
    if n == 0 then return "0" end
    local s = ""
    while n > 0 do
        local d = n % 36
        s = B36:sub(d + 1, d + 1) .. s
        n = (n - d) / 36
    end
    return s
end

function E.EncodeRangeString(ranges)
    local parts, prev = {}, 0
    for i = 1, #ranges, 2 do
        parts[#parts + 1] = toB36(ranges[i] - prev) .. "." .. toB36(ranges[i + 1] - ranges[i])
        prev = ranges[i + 1]
    end
    return table.concat(parts, ",")
end

function E.DecodeRangeString(s)
    local ranges, prev = {}, 0
    for gap, len in s:gmatch("(%w+)%.(%w+)") do
        local a = prev + tonumber(gap, 36)
        local b = a + tonumber(len, 36)
        ranges[#ranges + 1] = a; ranges[#ranges + 1] = b
        prev = b
    end
    return ranges
end

local function apiVersion()
    return GetAPIVersion and GetAPIVersion() or 0
end

-- after a cancelled job, no scan is running any more
function E.ResetScanFlags()
    for _, def in pairs(E.tables) do def.scanning = false end
end

function E.ResetScan(def)
    def.ranges = nil
    if E.sv and E.sv.scans then E.sv.scans[def.name] = nil end
end

-- Ensure the id list exists; scans if needed. Returns the id count.
function E.EnsureScanned(def)
    if def.ranges then return def.count end
    local saved = E.sv and E.sv.scans and E.sv.scans[def.name]
    if saved and saved.api == apiVersion() and saved.ranges then
        def.ranges = E.DecodeRangeString(saved.ranges)
        def.count = E.CountRanges(def.ranges)
        return def.count
    end
    if def.scanning then
        if not coroutine.running() then E.SQL.Fail("%s is being indexed, try again in a moment", def.name) end
        while def.scanning do coroutine.yield() end
        return def.count or 0
    end

    local scan = def.scan
    def.scanning = true
    local ids = {}
    local lastFound, nextReport = 0, 0.1
    local from, to, gap = scan.from or 1, scan.to, scan.gap or 50000
    local span = to - from + 1
    local t0 = E.NowMs()
    E.Print("Indexing %s ids (one time per game update)...", scan.label or def.name)
    E.FireCallbacks("ScanProgress", def.name, 0, 0)
    local exists = scan.exists
    for id = from, to do
        E.Tick()
        local ok, yes = pcall(exists, id)
        if ok and yes then
            ids[#ids + 1] = id
            lastFound = id
        end
        local frac = (id - from + 1) / span
        if frac >= nextReport then
            nextReport = nextReport + 0.1
            E.FireCallbacks("ScanProgress", def.name, frac, #ids)
        end
        if id > (scan.minTo or 0) and id - lastFound > gap then break end
    end
    def.ranges = E.EncodeRanges(ids)
    def.count = #ids
    def.scanning = false
    if E.sv then
        E.sv.scans = E.sv.scans or {}
        E.sv.scans[def.name] = { api = apiVersion(), ranges = E.EncodeRangeString(def.ranges), count = def.count, maxId = lastFound }
    end
    E.Print("Indexed %d %s (highest id %d) in %.1fs", def.count, scan.label or def.name, lastFound, (E.NowMs() - t0) / 1000)
    E.FireCallbacks("ScanProgress", def.name, 1, def.count)
    E.FireCallbacks("ScanDone", def.name, def.count)
    return def.count
end

---------------------------------------------------------------------------
-- Result tables (subqueries) and user tables (SELECT ... INTO)
---------------------------------------------------------------------------
local function columnsFromResult(res)
    local cols, used = {}, {}
    for i, name in ipairs(res.columns) do
        local base = lower(tostring(name))
        local key, n = base, 1
        while used[key] do n = n + 1; key = base .. "_" .. n end
        used[key] = true
        cols[i] = { name = key, type = "any", desc = "" }
    end
    return cols
end

local function rowsFromArrays(cols, arrays)
    local rows = {}
    for r, arr in ipairs(arrays) do
        local row = {}
        for i, col in ipairs(cols) do row[col.name] = arr[i] end
        rows[r] = row
    end
    return rows
end

function E.MakeResultTable(alias, res)
    local def = { name = alias, kind = "temp", columns = columnsFromResult(res) }
    normalizeColumns(def)
    def.rows = rowsFromArrays(def.columns, res.rows)
    return def
end

E.USER_TABLE_MAX_ROWS = E.isConsole and 5000 or 50000

function E.CreateUserTable(name, res)
    name = lower(name)
    local existing = E.tables[name]
    if existing and existing.kind ~= "user" then
        E.SQL.Fail("'%s' is a built-in table; pick another name", name)
    end
    local arrays = res.rows
    if #arrays > E.USER_TABLE_MAX_ROWS then
        E.SQL.Fail("INTO is limited to %d rows (got %d); add a LIMIT", E.USER_TABLE_MAX_ROWS, #arrays)
    end
    local cols = columnsFromResult(res)
    local def = {
        name = name, kind = "user", columns = cols,
        desc = format("your table (%d rows, created %s)", #arrays, os and os.date and os.date("%Y-%m-%d %H:%M") or ""),
    }
    E.RegisterTable(def)
    def.rows = rowsFromArrays(def.columns, arrays)
    if E.sv then
        E.sv.userTables = E.sv.userTables or {}
        local colNames = {}
        for i, c in ipairs(def.columns) do colNames[i] = c.name end
        -- arrays may have holes (NULLs); store as keyed tables per row index
        local saved = {}
        for r, arr in ipairs(arrays) do
            local copy = {}
            for i = 1, #colNames do
                local v = arr[i]
                local tv = type(v)
                if tv == "number" or tv == "string" or tv == "boolean" then copy[i] = v end
            end
            saved[r] = copy
        end
        E.sv.userTables[name] = { columns = colNames, rows = saved, desc = def.desc }
    end
    E.FireCallbacks("UserTableCreated", name)
    return def
end

function E.DropUserTable(name)
    local def = E.tables[name]
    if not def then return false, format("no table '%s'", name) end
    if def.kind ~= "user" then return false, format("'%s' is built in and cannot be dropped", name) end
    E.tables[name] = nil
    E.FireCallbacks("UserTableDropped", name)
    for i, n in ipairs(E.tableOrder) do
        if n == name then table.remove(E.tableOrder, i); break end
    end
    if E.sv and E.sv.userTables then E.sv.userTables[name] = nil end
    return true, format("Dropped table %s", name)
end

function E.LoadUserTables()
    if not (E.sv and E.sv.userTables) then return end
    for name, saved in pairs(E.sv.userTables) do
        if not E.tables[name] or E.tables[name].kind == "user" then
            local cols = {}
            for i, n in ipairs(saved.columns or {}) do cols[i] = { name = n, type = "any", desc = "" } end
            local def = { name = name, kind = "user", columns = cols, desc = saved.desc or "your table" }
            E.RegisterTable(def)
            local rows = {}
            for r, arr in ipairs(saved.rows or {}) do
                local row = {}
                for i, c in ipairs(def.columns) do row[c.key] = arr[i] end
                rows[r] = row
            end
            def.rows = rows
        end
    end
end

---------------------------------------------------------------------------
-- Small builders used by the table modules
---------------------------------------------------------------------------

-- Iterate enum values lo..hi, skipping values with no name.
function E.EnumValues(prefix, lo, hi)
    local out = {}
    local a, b = E.EnumRange(prefix, lo, hi)
    if not a or not b then return out end
    for v = a, b do
        if E.EnumName(prefix, v) then out[#out + 1] = v end
    end
    return out
end
