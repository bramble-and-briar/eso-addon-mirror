-- LibESQL public API and start-up. See README.md for the full reference.

local E = LibESQL
local SQL = E.SQL

local DEFAULTS = {
    scans = {},
    effectsSeen = {},
    userTables = {},
    trackEffects = false,
}

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

-- Synchronous. Returns result, or nil + error text.
--   result = { columns = { "id", "name" }, rows = { { 1, "x" }, ... }, truncated, elapsedMs, message }
-- opts: params = { ... } values for ? placeholders, maxRows = cap on returned rows.
-- An un-indexed scan table (abilities, items) is indexed inside this call and
-- blocks the frame; use QueryAsync the first time.
function E.Query(text, opts)
    local ok, res = E.RunSync(function() return SQL.Run(text, opts) end)
    if ok then return res end
    return nil, SQL.ErrorText(res)
end

-- Background: work is spread over frames. callback(result) or callback(nil, errorText).
-- Returns a job handle for CancelJob.
function E.QueryAsync(text, callback, opts)
    return E.RunAsync(function() return SQL.Run(text, opts) end, function(ok, res)
        if not callback then return end
        if ok then callback(res) else callback(nil, SQL.ErrorText(res)) end
    end, "api")
end

-- Rows as tables keyed by column name.
function E.ToObjects(res)
    local out = {}
    for r, arr in ipairs(res.rows) do
        local o = {}
        for c, name in ipairs(res.columns) do o[name] = arr[c] end
        out[r] = o
    end
    return out
end

-- Query and return rows as objects: for _, a in ipairs(LibESQL.Select(...)) do ... end
function E.Select(text, params)
    local res, err = E.Query(text, params and { params = params } or nil)
    if not res then return nil, err end
    return E.ToObjects(res)
end

-- First column of the first row (or nil).
function E.Scalar(text, params)
    local res, err = E.Query(text, params and { params = params } or nil)
    if not res then return nil, err end
    local row = res.rows[1]
    return row and row[1]
end

-- SQL text with |c colour markup for an ESO label (keywords, functions,
-- tables, strings, numbers, ?, comments). colors: optional overrides of
-- LibESQL.SQL.HIGHLIGHT_COLORS ({ keyword = "RRGGBB", ... }).
function E.Highlight(text, colors)
    if colors then
        local merged = {}
        for k, v in pairs(SQL.HIGHLIGHT_COLORS) do merged[k] = v end
        for k, v in pairs(colors) do merged[k] = v end
        colors = merged
    end
    return SQL.Highlight(text, colors)
end

-- Quote a value as an SQL literal: Quote("Kinras's") -> 'Kinras''s'
function E.Quote(v)
    if v == nil then return "NULL" end
    if v == true then return "TRUE" end
    if v == false then return "FALSE" end
    if type(v) == "number" then return SQL.ToText(v) end
    return "'" .. tostring(v):gsub("'", "''") .. "'"
end

-- Escape LIKE wildcards so text matches itself: % _ and the escape character
-- get the escape character (default "\") in front. Use it with ESCAPE '\':
--   Select("... WHERE name LIKE ? ESCAPE '\\'", { "%" .. LibESQL.Escape(text) .. "%" })
-- Returns the text, nil for nil, or nil + error text for a bad escape character.
function E.Escape(text, escapeChar)
    if text == nil then return nil end
    local ok, res = pcall(SQL.FUNCS.ESCAPE, text, escapeChar)
    if not ok then return nil, SQL.ErrorText(res) end
    return res
end

-- Parse only; returns true or false + error text (for validating user input).
function E.Validate(text)
    local ok, err = pcall(SQL.Parse, text, setmetatable({}, { __index = function() return 0 end }))
    if ok then return true end
    return false, SQL.ErrorText(err)
end

---------------------------------------------------------------------------
-- Writing to your own tables
---------------------------------------------------------------------------

-- Create a table you can INSERT into. columns: { "id INT", "name TEXT" } or
-- { {name = "id", type = "int"}, ... }. Returns true (created), false (it
-- already existed and ifNotExists was set), or nil + error text.
function E.CreateTable(name, columns, ifNotExists)
    local cols = {}
    for i, c in ipairs(columns or {}) do
        if type(c) == "string" then
            local n, t = c:match("^%s*([%w_]+)%s*([%w_]*)")
            local primary = c:lower():find("primary%s+key") ~= nil
            if t and t:lower() == "primary" then t = "" end
            cols[i] = { name = n, type = t ~= "" and t:lower() or nil, primary = primary }
        else
            cols[i] = { name = c.name or c[1], type = c.type or c[2], primary = c.primaryKey or c.primary }
        end
        if not cols[i].name then return nil, "bad column definition #" .. i end
    end
    local ok, a, b = pcall(E.CreateEmptyUserTable, name, cols, ifNotExists)
    if not ok then return nil, SQL.ErrorText(a) end
    return b
end

-- Insert one row object ({ id = 1, name = "x" }) or an array of them.
-- Keys are column names; missing columns are NULL. Returns the count, or nil + error text.
function E.Insert(tableName, rowOrRows)
    local def = E.GetTable(tableName or "")
    if not def then return nil, "no table '" .. tostring(tableName) .. "'" end
    local list = rowOrRows
    if type(list) ~= "table" then return nil, "Insert needs a row table or an array of rows" end
    if list[1] == nil or type(list[1]) ~= "table" then list = { list } end
    local objs = {}
    for i, row in ipairs(list) do
        local obj = {}
        for k, v in pairs(row) do
            local key = type(k) == "string" and k:lower() or k
            if not def.colIndex[key] then
                return nil, string.format("row %d: table %s has no column '%s'", i, def.name, tostring(k))
            end
            obj[key] = v
        end
        objs[i] = obj
    end
    local ok, res = pcall(E.InsertRows, def, objs)
    if not ok then return nil, SQL.ErrorText(res) end
    return res
end

-- Update rows: Update("kills", { secs = 50 }, "boss = ?", { "Zaan" }).
-- changes: { column = value }; use LibESQL.NULL to set NULL. where: optional SQL
-- condition (all rows when nil), whereParams: values for its ? placeholders.
-- Returns the number of rows changed, or nil + error text.
function E.Update(tableName, changes, where, whereParams)
    local def = E.GetTable(tableName or "")
    if not def then return nil, "no table '" .. tostring(tableName) .. "'" end
    if type(changes) ~= "table" or next(changes) == nil then return nil, "Update needs a table of { column = value } changes" end
    local keys = {}
    for k in pairs(changes) do
        local key = type(k) == "string" and k:lower() or k
        if not def.colIndex[key] then return nil, string.format("table %s has no column '%s'", def.name, tostring(k)) end
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local sets, params = {}, {}
    for i, k in ipairs(keys) do
        sets[i] = k:lower() .. " = ?"
        local v = changes[k]
        if v == E.NULL then v = nil end
        params[i] = v
    end
    local n = #keys
    for i, v in ipairs(whereParams or {}) do params[n + i] = v end
    params.n = n + (whereParams and (whereParams.n or #whereParams) or 0)
    local sql = "UPDATE " .. def.name .. " SET " .. table.concat(sets, ", ")
    if where and where ~= "" then sql = sql .. " WHERE " .. where end
    local res, err = E.Query(sql, { params = params })
    if not res then return nil, err end
    return res.rowsAffected
end

-- Delete rows: Delete("kills", "boss = ?", { "Zaan" }). where: optional SQL
-- condition; nil deletes every row (the table stays, DropTable removes it).
-- Returns the number of rows removed, or nil + error text.
function E.Delete(tableName, where, whereParams)
    local def = E.GetTable(tableName or "")
    if not def then return nil, "no table '" .. tostring(tableName) .. "'" end
    local sql = "DELETE FROM " .. def.name
    if where and where ~= "" then sql = sql .. " WHERE " .. where end
    local res, err = E.Query(sql, whereParams and { params = whereParams } or nil)
    if not res then return nil, err end
    return res.rowsAffected
end

-- Insert rows, or update the ones that already exist (matched on keyColumns,
-- default: the table's PRIMARY KEY). Only the columns each row gives are
-- changed. Returns inserted + updated, { inserted, updated, unchanged }
-- or nil + error text.
function E.Upsert(tableName, rowOrRows, keyColumns)
    local def = E.GetTable(tableName or "")
    if not def then return nil, "no table '" .. tostring(tableName) .. "'" end
    local list = rowOrRows
    if type(list) ~= "table" then return nil, "Upsert needs a row table or an array of rows" end
    if list[1] == nil or type(list[1]) ~= "table" then list = { list } end
    local objs = {}
    for i, row in ipairs(list) do
        local obj = {}
        for k, v in pairs(row) do
            local key = type(k) == "string" and k:lower() or k
            if not def.colIndex[key] then
                return nil, string.format("row %d: table %s has no column '%s'", i, def.name, tostring(k))
            end
            obj[key] = v
        end
        objs[i] = obj
    end
    local keyCols
    if keyColumns then
        keyCols = {}
        for i, k in ipairs(type(keyColumns) == "table" and keyColumns or { keyColumns }) do keyCols[i] = tostring(k):lower() end
    end
    local ok, res = pcall(E.UpsertRows, def, objs, { mode = "merge", keyCols = keyCols })
    if not ok then return nil, SQL.ErrorText(res) end
    return res.inserted + res.updated, res
end

-- Drop one of your tables. Returns true, or nil + error text.
function E.DropTable(name)
    local ok, msg = E.DropUserTable((name or ""):lower())
    if ok then return true end
    return nil, msg
end

---------------------------------------------------------------------------
-- Extending
---------------------------------------------------------------------------

-- Add an SQL function: RegisterFunction("double", function(x) return x and x * 2 end)
-- It receives evaluated argument values (nil for NULL) and returns one value.
function E.RegisterFunction(name, fn)
    assert(type(name) == "string" and type(fn) == "function", "RegisterFunction(name, fn)")
    SQL.FUNCS[name:upper()] = fn
end

function E.GetTableNames()
    local out = {}
    for i, n in ipairs(E.tableOrder) do out[i] = n end
    return out
end

function E.GetColumns(tableName)
    local def = E.GetTable(tableName)
    if not def then return nil end
    local out = {}
    for i, c in ipairs(def.columns) do out[i] = { name = c.name, type = c.type, description = c.desc, lazy = c.get ~= nil } end
    return out
end

-- Drop cached rows so the next query rebuilds them (nil = every table).
-- Returns the number of tables cleared, or nil + error text.
function E.Refresh(tableName)
    local ok, res = pcall(E.RefreshTables, tableName and tableName:lower() or nil)
    if ok then return res end
    return nil, SQL.ErrorText(res)
end

function E.IsScanned(tableName)
    local def = E.GetTable(tableName)
    if not def or def.kind ~= "scan" then return false end
    if def.ranges then return true, def.count end
    local saved = E.sv and E.sv.scans and E.sv.scans[def.name]
    return saved ~= nil and saved.api == (GetAPIVersion and GetAPIVersion()), saved and saved.count
end

-- Build the id index of abilities / items in the background. callback(count) when done.
function E.Scan(tableName, callback, force)
    local def = E.GetTable(tableName)
    assert(def and def.kind == "scan", "Scan works on: abilities, items")
    if force then E.ResetScan(def) end
    return E.RunAsync(function() return E.EnsureScanned(def) end, function(ok, res)
        if callback then callback(ok and res or nil, not ok and SQL.ErrorText(res) or nil) end
    end, "scan")
end

function E.IsEffectTracking() return E.trackEffects == true end
function E.IsCombatLogging() return E.combatLogging == true end

---------------------------------------------------------------------------
-- Load
---------------------------------------------------------------------------
local function onLoaded(_, addonName)
    if addonName ~= E.name then return end
    EVENT_MANAGER:UnregisterForEvent(E.name, EVENT_ADD_ON_LOADED)

    E.sv = ZO_SavedVars:NewAccountWide("LibESQL_SV", 1, nil, DEFAULTS)
    for k, v in pairs(DEFAULTS) do
        if E.sv[k] == nil then E.sv[k] = type(v) == "table" and {} or v end
    end
    local n = 0
    for _ in pairs(E.sv.effectsSeen) do n = n + 1 end
    E.effectsSeenCount = n
    E.LoadUserTables()
    E.SetEffectTracking(E.sv.trackEffects)
    E.loaded = true
    E.FireCallbacks("Loaded")
end

E.effectsSeenCount = 0
EVENT_MANAGER:RegisterForEvent(E.name, EVENT_ADD_ON_LOADED, onLoaded)

-- Everything registered up to here is built in (and read-only). This is the
-- library's last file, so later RegisterTable calls come from other add-ons.
E.EndBuiltinRegistration()
