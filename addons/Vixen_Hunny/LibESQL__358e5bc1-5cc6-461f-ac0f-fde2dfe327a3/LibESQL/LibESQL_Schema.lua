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

-- Built-in tables: every table LibESQL itself registers while it loads. The
-- list is private (not a flag on the definition) so nothing can unmark one.
-- Built-in tables can never be written to, replaced, dropped or overwritten.
local builtinNames = {}
local registeringBuiltins = true

-- Called once by LibESQL_API.lua, the library's last file. After this every
-- RegisterTable call comes from another add-on.
function E.EndBuiltinRegistration()
    registeringBuiltins = false
end

function E.IsBuiltinTable(name)
    return type(name) == "string" and builtinNames[lower(name)] == true
end

local WRITE_HANDLER = { INSERT = "insert", UPDATE = "update", DELETE = "delete" }

-- The one check every write goes through. Returns "user" (a table made with
-- CREATE TABLE / SELECT ... INTO) or "handler" (an add-on table with its own
-- insert/update/delete function); raises for everything else.
function E.CheckWritable(def, action)
    if builtinNames[def.name] then
        E.SQL.Fail("'%s' is a built-in table and is read-only; %s works on tables you create (CREATE TABLE or SELECT ... INTO)", def.name, action)
    end
    if def.kind == "user" then return "user" end
    local handler = WRITE_HANDLER[action] and def[WRITE_HANDLER[action]]
    if type(handler) == "function" then return "handler" end
    E.SQL.Fail("'%s' is read-only; %s works on tables you create (CREATE TABLE or SELECT ... INTO)", def.name, action)
end

-- A new user table may not take the name of a built-in or of an add-on's table.
local function checkFreeForUserTable(name)
    if builtinNames[name] then
        E.SQL.Fail("'%s' is a built-in table; pick another name", name)
    end
    local existing = E.tables[name]
    if existing and existing.kind ~= "user" then
        E.SQL.Fail("'%s' is another add-on's table; pick another name", name)
    end
end

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
    if registeringBuiltins then
        builtinNames[def.name] = true
    elseif builtinNames[def.name] then
        error(format("LibESQL: '%s' is a built-in table and can't be replaced", def.name), 2)
    end
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
    local listed = false
    for _, n in ipairs(E.tableOrder) do
        if n == def.name then listed = true; break end
    end
    if not listed then E.tableOrder[#E.tableOrder + 1] = def.name end
    E.tables[def.name] = def
    return def
end

-- Remove a table that isn't built in (used for tables made from SavedVariables).
function E.UnregisterTable(name)
    name = lower(name or "")
    if builtinNames[name] or not E.tables[name] then return false end
    E.tables[name] = nil
    for i, n in ipairs(E.tableOrder) do
        if n == name then table.remove(E.tableOrder, i); break end
    end
    return true
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
-- Result tables (subqueries) and user tables (SELECT ... INTO, CREATE TABLE, INSERT)
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

local function stamp()
    return os and os.date and os.date("%Y-%m-%d %H:%M") or ""
end

local function savable(v)
    local tv = type(v)
    return tv == "number" or tv == "string" or tv == "boolean"
end

-- Write a user table to SavedVariables (rows as arrays in column order).
local function saveUserTable(def)
    if not E.sv then return end
    E.sv.userTables = E.sv.userTables or {}
    local colNames, types = {}, {}
    for i, c in ipairs(def.columns) do colNames[i] = c.name; types[i] = c.type end
    local saved = {}
    for r, row in ipairs(def.rows) do
        local arr = {}
        for i, c in ipairs(def.columns) do
            local v = row[c.key]
            if savable(v) then arr[i] = v end
        end
        saved[r] = arr
    end
    E.sv.userTables[def.name] = { columns = colNames, types = types, rows = saved, desc = def.desc,
        primaryKey = def.primaryKey }
end

local function registerUserTable(name, cols, rows, desc)
    checkFreeForUserTable(name)
    local def = { name = name, kind = "user", columns = cols, desc = desc }
    E.RegisterTable(def)
    def.rows = rows or {}
    return def
end

function E.CreateUserTable(name, res)
    name = lower(name)
    local arrays = res.rows
    if #arrays > E.USER_TABLE_MAX_ROWS then
        E.SQL.Fail("INTO is limited to %d rows (got %d); add a LIMIT", E.USER_TABLE_MAX_ROWS, #arrays)
    end
    local cols = columnsFromResult(res)
    local def = registerUserTable(name, cols, nil, format("your table (created %s)", stamp()))
    def.rows = rowsFromArrays(def.columns, arrays)
    saveUserTable(def)
    E.FireCallbacks("UserTableCreated", name)
    return def
end

local TYPE_ALIASES = {
    int = "int", integer = "int", bigint = "int", smallint = "int",
    num = "num", real = "num", float = "num", double = "num", number = "num", numeric = "num", decimal = "num",
    text = "text", string = "text", varchar = "text", char = "text",
    bool = "bool", boolean = "bool",
}

-- CREATE TABLE: cols = { {name = "x", type = "int"}, ... }
-- Returns def, created (false when it already existed and ifNotExists was set).
function E.CreateEmptyUserTable(name, cols, ifNotExists, primaryKey)
    name = lower(name)
    checkFreeForUserTable(name)
    local existing = E.tables[name]
    if existing then
        if ifNotExists then return existing, false end
        E.SQL.Fail("table '%s' already exists (DROP TABLE it first, or use IF NOT EXISTS)", name)
    end
    if #cols == 0 then E.SQL.Fail("CREATE TABLE needs at least one column") end
    local defCols, have = {}, {}
    local pk = {}
    for i, c in ipairs(cols) do
        local key = lower(c.name)
        if have[key] then E.SQL.Fail("column '%s' is listed twice", key) end
        have[key] = true
        defCols[i] = { name = key, type = TYPE_ALIASES[c.type or ""] or "any", desc = "" }
        if c.primary then pk[#pk + 1] = key end
    end
    if primaryKey and #primaryKey > 0 then
        if #pk > 0 then E.SQL.Fail("PRIMARY KEY is given twice") end
        for _, k in ipairs(primaryKey) do
            k = lower(k)
            if not have[k] then E.SQL.Fail("PRIMARY KEY names column '%s', which the table doesn't have", k) end
            for _, existing in ipairs(pk) do
                if existing == k then E.SQL.Fail("column '%s' is in the PRIMARY KEY twice", k) end
            end
            pk[#pk + 1] = k
        end
    end
    for _, c in ipairs(defCols) do
        for _, k in ipairs(pk) do if c.name == k then c.desc = "primary key" end end
    end
    local def = registerUserTable(name, defCols, {}, format("your table (created %s)", stamp()))
    if #pk > 0 then def.primaryKey = pk end
    saveUserTable(def)
    E.FireCallbacks("UserTableCreated", name)
    return def, true
end

local function coerce(v, colType)
    if v == nil then return nil end
    if colType == "int" or colType == "num" then
        if type(v) == "string" then return tonumber(v) or v end
        if v == true then return 1 elseif v == false then return 0 end
        if colType == "int" and type(v) == "number" and v ~= math.floor(v) then
            return v >= 0 and math.floor(v) or math.ceil(v)
        end
    elseif colType == "text" then
        if type(v) ~= "string" then return E.SQL.ToText(v) end
    elseif colType == "bool" then
        if type(v) == "number" then return v ~= 0 end
        if type(v) == "string" then
            local l = v:lower()
            if l == "true" or l == "1" or l == "yes" then return true end
            if l == "false" or l == "0" or l == "no" then return false end
        end
    end
    return v
end

E.CoerceValue = coerce

-- A row object with every column converted to the column's type.
function E.CoerceRow(def, obj)
    local row = {}
    for _, c in ipairs(def.columns) do
        local v = obj[c.key]
        if v == E.NULL then v = nil end
        row[c.key] = coerce(v, c.type)
    end
    return row
end

-- Identity of a row for the given key columns (strings compare without case,
-- like "="); nil when any part is NULL (NULLs never conflict).
function E.RowKey(row, cols)
    local parts = {}
    for i, k in ipairs(cols) do
        local v = row[k]
        if v == nil or v == E.NULL then return nil end
        local nk = E.SQL.NormKey(v)
        parts[i] = (type(nk) == "number" and "n" or "s") .. tostring(nk)
    end
    return table.concat(parts, "\31")
end

local function keyText(def, row)
    local parts = {}
    for i, k in ipairs(def.primaryKey) do parts[i] = tostring(E.SQL.ToText(row[k])) end
    return table.concat(parts, ", ")
end

-- PRIMARY KEY checks for new rows (before anything is changed)
local function checkNewKeys(def, newRows)
    local pk = def.primaryKey
    if not pk then return end
    local seen = {}
    for _, r in ipairs(def.rows) do
        local k = E.RowKey(r, pk)
        if k then seen[k] = true end
    end
    for _, r in ipairs(newRows) do
        local k = E.RowKey(r, pk)
        if not k then E.SQL.Fail("the PRIMARY KEY of %s (%s) can't be NULL", def.name, table.concat(pk, ", ")) end
        if seen[k] then E.SQL.Fail("duplicate PRIMARY KEY (%s) in %s; use UPSERT or ON CONFLICT to update it", keyText(def, r), def.name) end
        seen[k] = true
    end
end

-- PRIMARY KEY checks for updates (before anything is changed)
local function checkUpdatedKeys(def, updates)
    local pk = def.primaryKey
    if not pk then return end
    local isPk, touches = {}, false
    for _, k in ipairs(pk) do isPk[k] = true end
    for _, u in ipairs(updates) do
        for k in pairs(u.changes) do if isPk[k] then touches = true end end
    end
    if not touches then return end
    local newKey = {}
    for _, u in ipairs(updates) do
        local probe = {}
        for _, k in ipairs(pk) do
            local v = u.changes[k]
            if v == nil then v = u.row[k] elseif v == E.NULL then v = nil else v = coerce(v, def.colIndex[k].type) end
            probe[k] = v
        end
        local key = E.RowKey(probe, pk)
        if not key then E.SQL.Fail("the PRIMARY KEY of %s (%s) can't be NULL", def.name, table.concat(pk, ", ")) end
        newKey[u.row] = { key = key, probe = probe }
    end
    local seen = {}
    for _, r in ipairs(def.rows) do
        local nk = newKey[r]
        local key = nk and nk.key or E.RowKey(r, pk)
        if key then
            if seen[key] then
                E.SQL.Fail("duplicate PRIMARY KEY (%s) in %s", keyText(def, nk and nk.probe or r), def.name)
            end
            seen[key] = true
        end
    end
end

-- Insert row objects (keyed by lower-case column name) into a user table,
-- or into an add-on table that defines def.insert(row). Returns the count.
function E.InsertRows(def, objs)
    if E.CheckWritable(def, "INSERT") == "user" then
        if #def.rows + #objs > E.USER_TABLE_MAX_ROWS then
            E.SQL.Fail("table %s would have %d rows; the limit is %d", def.name, #def.rows + #objs, E.USER_TABLE_MAX_ROWS)
        end
        local newRows = {}
        for i, obj in ipairs(objs) do newRows[i] = E.CoerceRow(def, obj) end
        checkNewKeys(def, newRows)
        for _, row in ipairs(newRows) do def.rows[#def.rows + 1] = row end
        def.index = nil
        saveUserTable(def)
    else
        for _, obj in ipairs(objs) do def.insert(obj, def) end
        def.cache, def.index = nil, nil
    end
    E.FireCallbacks("RowsInserted", def.name, #objs)
    return #objs
end

-- Apply UPDATE changes: updates = { { row = row, changes = { col = value } }, ... }.
-- A change to nil is stored as NULL. Returns the number of rows changed.
function E.UpdateRows(def, updates)
    if E.CheckWritable(def, "UPDATE") == "user" then
        checkUpdatedKeys(def, updates)
        for _, u in ipairs(updates) do
            for key, v in pairs(u.changes) do
                local col = def.colIndex[key]
                if v == E.NULL then v = nil end
                u.row[key] = coerce(v, col and col.type)
            end
        end
        def.index = nil
        if #updates > 0 then saveUserTable(def) end
    else
        for _, u in ipairs(updates) do
            local changes = {}
            for key, v in pairs(u.changes) do
                if v == E.NULL then v = nil end
                changes[key] = v
            end
            def.update(u.row, changes, def)
        end
        def.cache, def.index = nil, nil
    end
    E.FireCallbacks("RowsUpdated", def.name, #updates)
    return #updates
end

-- Remove rows (the row tables themselves) from a user table, or hand them to
-- an add-on table's def.delete(row). Returns the number of rows removed.
function E.DeleteRows(def, doomed)
    if E.CheckWritable(def, "DELETE") == "user" then
        if #doomed > 0 then
            local kill = {}
            for _, r in ipairs(doomed) do kill[r] = true end
            local kept = {}
            for _, r in ipairs(def.rows) do
                if not kill[r] then kept[#kept + 1] = r end
            end
            def.rows = kept
            def.index = nil
            saveUserTable(def)
        end
    else
        for _, r in ipairs(doomed) do def.delete(r, def) end
        def.cache, def.index = nil, nil
    end
    E.FireCallbacks("RowsDeleted", def.name, #doomed)
    return #doomed
end

--[[
    Insert rows, or change the ones that are already there (upsert).
    opts:
      keyCols   columns that identify a row (default: the table's PRIMARY KEY)
      mode      "merge"    update the columns each new row gives (UPSERT)
                "replace"  overwrite the whole row; missing columns become NULL (REPLACE)
                "nothing"  keep the existing row (INSERT OR IGNORE / DO NOTHING)
                "custom"   opts.merge(current, excluded) returns { col = value } or nil
    Rows are matched like "=": text without case. A row with a NULL in a key
    column never matches. Rows earlier in the same call count too, so two new
    rows with one key give one insert and one update.
    Returns { inserted = n, updated = n, unchanged = n }.
]]
function E.UpsertRows(def, objs, opts)
    opts = opts or {}
    local mode = opts.mode or "merge"
    E.CheckWritable(def, "INSERT")
    if mode ~= "nothing" then E.CheckWritable(def, "UPDATE") end
    local keyCols = opts.keyCols or def.primaryKey
    if not keyCols or #keyCols == 0 then
        E.SQL.Fail("%s has no PRIMARY KEY; name the columns that identify a row: ON CONFLICT (col, ...)", def.name)
    end
    local isKeyCol = {}
    for _, k in ipairs(keyCols) do
        if not def.colIndex[k] then E.SQL.Fail("table %s has no column '%s'", def.name, k) end
        isKeyCol[k] = true
    end

    local index = {}
    local existing = def.kind == "user" and def.rows or E.GetRows(def)
    for _, r in ipairs(existing) do
        E.Tick()
        local k = E.RowKey(r, keyCols)
        if k and not index[k] then index[k] = { row = r } end
    end

    local inserts, touched = {}, {}
    local stats = { inserted = 0, updated = 0, unchanged = 0 }
    for _, obj in ipairs(objs) do
        E.Tick()
        local excluded = E.CoerceRow(def, obj)
        local k = E.RowKey(excluded, keyCols)
        local hit = k and index[k]
        if not hit then
            inserts[#inserts + 1] = obj
            stats.inserted = stats.inserted + 1
            if k then index[k] = { pending = obj } end
        else
            -- the row as it is now, including earlier changes in this call
            if not hit.view then
                hit.view = hit.pending and E.CoerceRow(def, hit.pending) or E.ShallowCopy(hit.row)
            end
            local changes
            if mode == "replace" then
                changes = {}
                for _, c in ipairs(def.columns) do
                    local v = excluded[c.key]
                    changes[c.key] = v == nil and E.NULL or v
                end
            elseif mode == "merge" then
                -- the columns the new row gives, except the key: it identifies
                -- the row and keeps its spelling ('HEAD' matched 'head')
                changes = {}
                for key, v in pairs(obj) do
                    if def.colIndex[key] and not isKeyCol[key] then changes[key] = (v == nil) and E.NULL or v end
                end
            elseif mode == "custom" then
                changes = opts.merge(hit.view, excluded)
            end
            if changes and next(changes) then
                for key, v in pairs(changes) do
                    local col = def.colIndex[key]
                    local val = v ~= E.NULL and E.CoerceValue(v, col and col.type) or nil
                    hit.view[key] = val
                    if hit.pending then
                        hit.pending[key] = val
                    else
                        hit.changes = hit.changes or {}
                        hit.changes[key] = v
                    end
                end
                if not hit.pending and not hit.listed then
                    hit.listed = true
                    touched[#touched + 1] = hit
                end
                stats.updated = stats.updated + 1
            else
                stats.unchanged = stats.unchanged + 1
            end
        end
    end

    local updates = {}
    for i, hit in ipairs(touched) do updates[i] = { row = hit.row, changes = hit.changes } end
    if #inserts > 0 then E.InsertRows(def, inserts) end
    if #updates > 0 then E.UpdateRows(def, updates) end
    E.FireCallbacks("RowsUpserted", def.name, stats.inserted, stats.updated)
    return stats
end

function E.DropUserTable(name)
    local def = E.tables[name]
    if not def then return false, format("no table '%s'", name) end
    if builtinNames[name] then return false, format("'%s' is a built-in table and cannot be dropped", name) end
    if def.kind ~= "user" then return false, format("'%s' is another add-on's table and cannot be dropped", name) end
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
        if not builtinNames[name] and (not E.tables[name] or E.tables[name].kind == "user") then
            local cols = {}
            local types = saved.types or {}
            for i, n in ipairs(saved.columns or {}) do cols[i] = { name = n, type = types[i] or "any", desc = "" } end
            local def = { name = name, kind = "user", columns = cols, desc = saved.desc or "your table" }
            E.RegisterTable(def)
            if type(saved.primaryKey) == "table" and #saved.primaryKey > 0 then
                def.primaryKey = saved.primaryKey
                for _, k in ipairs(def.primaryKey) do
                    if def.colIndex[k] then def.colIndex[k].desc = "primary key" end
                end
            end
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
