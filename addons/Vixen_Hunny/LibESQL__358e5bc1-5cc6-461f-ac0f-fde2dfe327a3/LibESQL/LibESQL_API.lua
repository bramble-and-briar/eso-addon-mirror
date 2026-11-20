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

-- Quote a value as an SQL literal: Quote("Kinras's") -> 'Kinras''s'
function E.Quote(v)
    if v == nil then return "NULL" end
    if v == true then return "TRUE" end
    if v == false then return "FALSE" end
    if type(v) == "number" then return SQL.ToText(v) end
    return "'" .. tostring(v):gsub("'", "''") .. "'"
end

-- Parse only; returns true or false + error text (for validating user input).
function E.Validate(text)
    local ok, err = pcall(SQL.Parse, text, setmetatable({}, { __index = function() return 0 end }))
    if ok then return true end
    return false, SQL.ErrorText(err)
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
