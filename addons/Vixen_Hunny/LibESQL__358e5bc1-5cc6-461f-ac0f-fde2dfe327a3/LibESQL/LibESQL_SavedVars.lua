-- Other add-ons' SavedVariables as SQL tables.
--
-- SavedVariables are ordinary global Lua tables once the game has loaded them,
-- on PC and on console alike. Add-ons that use ZO_SavedVars store them as
--   Global["Default"]["@account"]["$AccountWide" | characterId] = data
-- which LibESQL recognises without being told. Plain tables can be added by
-- name with LibESQL.AddSavedVariable("Name").
--
-- Tables:
--   saved_variables   one row per SavedVariables table found
--   sv_tables         the tables generated from them
--   sv_values         every value, one row per leaf (path / value)
--   sv_<name>_<path>  generated: each list of records (saved fights, items...)
--                     becomes its own table, with one column per field
--
-- Everything here is read-only: other add-ons' data is never changed. Tables
-- are read live from the current data on every query. Before walking a table
-- LibESQL copies its keys, because the owning add-on may change it while a
-- query is spread over several frames.

local E = LibESQL
local Tick = E.Tick
local format, lower = string.format, string.lower

E.SV_MAX_NODES = E.isConsole and 30000 or 250000   -- tables visited per saved variable while looking for lists
E.SV_MAX_VALUES = E.isConsole and 20000 or 200000  -- rows sv_values builds per query
E.SV_MAX_COLUMNS = 60                               -- fields per generated table
E.SV_EXCLUDE = { LibESQL_SV = true, ESQL_SV = true } -- LibESQL's own data is already queryable
E.SV_INCLUDE_GAME = false   -- true also scans the game's own ZO_* saved variables (UI settings)

local WILD = {}            -- "any key" in a path pattern
local discovered = {}      -- { info, ... } from the last scan
local generated = {}       -- generated table name -> true
E.svScanned = false

local function isScalar(v)
    local t = type(v)
    return t == "string" or t == "number" or t == "boolean"
end

local function keyText(k)
    if type(k) == "number" then return E.SQL.ToText(k) end
    return tostring(k)
end

-- children of a table as a stable list { k1, v1, k2, v2, ... } (no yields while copying)
local function entries(t, limit)
    local out, n = {}, 0
    for k, v in next, t do
        out[#out + 1] = k; out[#out + 1] = v
        n = n + 1
        if limit and n >= limit then break end
    end
    return out
end

---------------------------------------------------------------------------
-- Finding SavedVariables
---------------------------------------------------------------------------

-- The scopes of a ZO_SavedVars table:
-- { { profile, account, scopeId, scope, accountWide, data }, ... } or nil
local function zoScopes(t)
    local scopes = {}
    for profile, accounts in next, t do
        if type(profile) == "string" and type(accounts) == "table" then
            for account, chars in next, accounts do
                if type(account) == "string" and account:sub(1, 1) == "@" and type(chars) == "table" then
                    for scopeId, data in next, chars do
                        if type(data) == "table" then
                            local wide = scopeId == "$AccountWide"
                            local name = wide and "account-wide"
                                or (type(data["$LastCharacterName"]) == "string" and data["$LastCharacterName"])
                                or keyText(scopeId)
                            scopes[#scopes + 1] = {
                                profile = profile, account = account, scopeId = keyText(scopeId),
                                scope = name, accountWide = wide, data = data,
                            }
                        end
                    end
                end
            end
        end
    end
    return #scopes > 0 and scopes or nil
end

-- cheap first check before walking a global table
local function looksLikeZOSavedVars(t)
    local d = rawget(t, "Default")
    if type(d) == "table" then
        local k, v = next(d)
        return type(k) == "string" and k:sub(1, 1) == "@" and type(v) == "table"
    end
    -- other profiles (rare): the first entry holds @accounts
    local profile, accounts = next(t)
    if type(profile) ~= "string" or type(accounts) ~= "table" then return false end
    local k, v = next(accounts)
    return type(k) == "string" and k:sub(1, 1) == "@" and type(v) == "table"
end

local addonNames
local function guessAddon(globalName)
    if not addonNames then
        addonNames = {}
        local mgr = GetAddOnManager and GetAddOnManager()
        if mgr and mgr.GetNumAddOns then
            for i = 1, mgr:GetNumAddOns() do
                local name = mgr:GetAddOnInfo(i)
                if type(name) == "string" and #name >= 3 then addonNames[#addonNames + 1] = name end
            end
        end
        table.sort(addonNames, function(a, b) return #a > #b end)   -- longest match first
    end
    local g = lower(globalName)
    for _, name in ipairs(addonNames) do
        if g:sub(1, #name) == lower(name) then return name end
    end
    for _, name in ipairs(addonNames) do
        if #name >= 5 and g:find(lower(name), 1, true) then return name end
    end
    return nil
end

local function extraNames()
    local list = E.sv and E.sv.extraSavedVariables or E.extraSavedVariables or {}
    E.extraSavedVariables = list
    return list
end

---------------------------------------------------------------------------
-- Finding lists of records inside one saved variable
---------------------------------------------------------------------------

local function patternText(parts)
    local out = {}
    for i, p in ipairs(parts) do out[i] = p == WILD and "*" or keyText(p) end
    return table.concat(out, ".")
end

-- Walks `data` and records every list of records in `found` (pattern -> info).
-- A node is a collection when most of its children are tables and they look
-- alike (array-like keys, or sharing their most common field). It's a list of
-- records when those children also hold plain values.
local function findLists(data, found, budget)
    local seen = {}
    local function walk(node, parts, depth)
        if budget.nodes <= 0 or depth > 12 or seen[node] then return end
        seen[node] = true
        budget.nodes = budget.nodes - 1
        Tick()
        local items = entries(node, 50000)
        local total, tables, numericKeys, records = #items / 2, 0, 0, 0
        local fieldCount, keyFreq = {}, {}
        for i = 1, #items, 2 do
            local k, v = items[i], items[i + 1]
            if type(k) == "number" then numericKeys = numericKeys + 1 end
            if type(v) == "table" then
                tables = tables + 1
                local scalars = 0
                for fk, fv in next, v do
                    if type(fk) == "string" or type(fk) == "number" then
                        keyFreq[fk] = (keyFreq[fk] or 0) + 1
                        if isScalar(fv) then
                            scalars = scalars + 1
                            fieldCount[fk] = (fieldCount[fk] or 0) + 1
                        end
                    end
                end
                if scalars > 0 then records = records + 1 end
            end
        end
        local common = 0
        for _, c in pairs(keyFreq) do if c > common then common = c end end
        local collection = tables >= 2 and tables >= total * 0.6
            and (numericKeys >= total * 0.6 or (tables >= 3 and common >= tables * 0.5))
        if collection and records >= 2 then
            local pt = patternText(parts)
            local info = found[pt]
            if not info then
                local copy = {}
                for i, p in ipairs(parts) do copy[i] = p end
                info = { parts = copy, pattern = pt, records = 0, fields = {} }
                found[pt] = info
            end
            info.records = info.records + records
            for f, c in pairs(fieldCount) do info.fields[f] = (info.fields[f] or 0) + c end
        end
        for i = 1, #items, 2 do
            local k, v = items[i], items[i + 1]
            if type(v) == "table" then
                parts[#parts + 1] = collection and WILD or k
                walk(v, parts, depth + 1)
                parts[#parts] = nil
            end
        end
    end
    walk(data, {}, 0)
end

-- Every record of a list pattern inside one scope's data:
-- fn(record, key, pathText)
local function eachRecord(data, parts, fn)
    local function go(node, i, path)
        if type(node) ~= "table" then return end
        if i > #parts then
            local items = entries(node)
            for j = 1, #items, 2 do
                Tick()
                local k, v = items[j], items[j + 1]
                if type(v) == "table" then
                    fn(v, k, path == "" and keyText(k) or (path .. "." .. keyText(k)))
                end
            end
            return
        end
        local p = parts[i]
        if p == WILD then
            local items = entries(node)
            for j = 1, #items, 2 do
                local k, v = items[j], items[j + 1]
                if type(v) == "table" then go(v, i + 1, path == "" and keyText(k) or (path .. "." .. keyText(k))) end
            end
        else
            go(rawget(node, p), i + 1, path == "" and keyText(p) or (path .. "." .. keyText(p)))
        end
    end
    go(data, 1, "")
end

---------------------------------------------------------------------------
-- Generated tables
---------------------------------------------------------------------------

local function safeName(s)
    s = lower(tostring(s)):gsub("[^%w_]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
    return s
end

local function shortGlobal(name)
    local s = safeName(name)
    for _, suffix in ipairs({ "_savedvariables", "savedvariables", "_saved_variables", "_savedvars", "savedvars",
        "_saved_vars", "_settings", "_sv", "sv", "_vars", "_data" }) do
        if #s > #suffix + 2 and s:sub(-#suffix) == suffix then return (s:sub(1, -#suffix - 1):gsub("_$", "")) end
    end
    return s
end

local function tableNameFor(svName, parts, taken)
    local bits = {}
    for _, p in ipairs(parts) do
        if p ~= WILD then bits[#bits + 1] = safeName(keyText(p)) end
    end
    local base = "sv_" .. shortGlobal(svName) .. (#bits > 0 and ("_" .. table.concat(bits, "_")) or "")
    base = base:sub(1, 60)
    local name, n = base, 1
    while taken[name] or (E.tables[name] and not generated[name]) do
        n = n + 1
        name = base:sub(1, 57) .. "_" .. n
    end
    taken[name] = true
    return name
end

local FIXED = { account = true, scope = true, key = true, path = true, character_id = true }

local function columnsFor(info)
    local fields = {}
    for f, c in pairs(info.fields) do fields[#fields + 1] = { f = f, c = c } end
    table.sort(fields, function(a, b)
        if a.c ~= b.c then return a.c > b.c end
        return keyText(a.f) < keyText(b.f)
    end)
    local cols = {
        { name = "account", type = "text", desc = "@account" },
        { name = "scope", type = "text", desc = "Character name, or account-wide" },
        { name = "character_id", type = "text", desc = "Character id (empty for account-wide)" },
        { name = "key", type = "text", desc = "The record's key in its list" },
        { name = "path", type = "text", desc = "Where the record is inside the saved variable" },
    }
    local map, used = {}, {}
    for name in pairs(FIXED) do used[name] = true end
    for i = 1, math.min(#fields, E.SV_MAX_COLUMNS) do
        local f = fields[i].f
        local base = type(f) == "number" and ("c" .. keyText(f)) or safeName(f)
        if base == "" then base = "field" end
        if base:find("^%d") then base = "c" .. base end
        local name, n = base, 1
        if used[name] then name = "f_" .. base end
        while used[name] do n = n + 1; name = base .. "_" .. n end
        used[name] = true
        cols[#cols + 1] = { name = name, type = "any", desc = "field " .. keyText(f) }
        map[#map + 1] = { col = name, field = f }
    end
    return cols, map
end

local function scopesOf(info)
    local t = rawget(_G, info.name)
    if type(t) ~= "table" then return {} end
    if info.style == "ZO_SavedVars" then return zoScopes(t) or {} end
    return { { profile = "", account = "", scopeId = "", scope = "(whole table)", accountWide = true, data = t } }
end

local function registerGenerated(info, list, taken)
    local name = tableNameFor(info.name, list.parts, taken)
    local cols, map = columnsFor(list)
    local parts = list.parts
    E.RegisterTable({
        name = name,
        desc = format("%s %s (from %s's saved variables)", info.name, list.pattern, info.addon or "an add-on"),
        live = true,
        columns = cols,
        build = function(rows)
            for _, sc in ipairs(scopesOf(info)) do
                eachRecord(sc.data, parts, function(rec, k, path)
                    local row = {
                        account = sc.account, scope = sc.scope, key = keyText(k), path = path,
                        character_id = not sc.accountWide and sc.scopeId or nil,
                    }
                    for _, m in ipairs(map) do
                        local v = rawget(rec, m.field)
                        if isScalar(v) then row[m.col] = v end
                    end
                    rows[#rows + 1] = row
                end)
            end
        end,
    })
    generated[name] = true
    return { table_name = name, sv = info.name, addon = info.addon, pattern = list.pattern,
             records = list.records, columns = #cols }
end

---------------------------------------------------------------------------
-- Scan
---------------------------------------------------------------------------

-- Finds every SavedVariables table and (re)builds the generated tables.
-- Runs inside a query / job (it ticks). Returns the number found.
function E.ScanSavedVariables()
    -- one pass over _G without yielding
    local names = {}
    for k, v in E.GlobalPairs() do
        if type(k) == "string" and type(v) == "table" and not E.SV_EXCLUDE[k]
            and (E.SV_INCLUDE_GAME or k:sub(1, 3) ~= "ZO_") then
            names[#names + 1] = k
        end
    end
    table.sort(names)
    local extras = {}
    for _, n in ipairs(extraNames()) do extras[n] = true end

    local found = {}
    for _, name in ipairs(names) do
        Tick()
        local t = rawget(_G, name)
        if type(t) == "table" then
            local ok, isZO = pcall(looksLikeZOSavedVars, t)
            local style
            if ok and isZO and zoScopes(t) then style = "ZO_SavedVars"
            elseif extras[name] then style = "registered" end
            if style then
                found[#found + 1] = { name = name, style = style, addon = guessAddon(name) }
            end
        end
    end
    for n in pairs(extras) do
        local listed = false
        for _, f in ipairs(found) do if f.name == n then listed = true end end
        if not listed and type(rawget(_G, n)) == "table" then
            found[#found + 1] = { name = n, style = "registered", addon = guessAddon(n) }
        end
    end

    -- drop the tables from the last scan
    for name in pairs(generated) do
        E.UnregisterTable(name)
    end
    generated = {}

    local taken = {}
    for _, info in ipairs(found) do
        local scopes = scopesOf(info)
        local lists = {}
        local budget = { nodes = E.SV_MAX_NODES }
        local accounts, chars, wide = {}, 0, false
        for _, sc in ipairs(scopes) do
            if sc.account ~= "" then accounts[sc.account] = true end
            if sc.accountWide then wide = true else chars = chars + 1 end
            findLists(sc.data, lists, budget)
        end
        local nAcc = 0
        for _ in pairs(accounts) do nAcc = nAcc + 1 end
        info.accounts, info.characters, info.accountWide = nAcc, chars, wide
        info.truncated = budget.nodes <= 0
        info.nodes = E.SV_MAX_NODES - budget.nodes
        info.tables = {}
        local patterns = {}
        for pt in pairs(lists) do patterns[#patterns + 1] = pt end
        table.sort(patterns)
        for _, pt in ipairs(patterns) do
            -- count records and gather fields from every place the pattern
            -- matches (discovery only sees lists big enough to recognise)
            local list = lists[pt]
            list.records, list.fields = 0, {}
            for _, sc in ipairs(scopes) do
                eachRecord(sc.data, list.parts, function(rec)
                    list.records = list.records + 1
                    for fk, fv in next, rec do
                        if isScalar(fv) and (type(fk) == "string" or type(fk) == "number") then
                            list.fields[fk] = (list.fields[fk] or 0) + 1
                        end
                    end
                end)
            end
            info.tables[#info.tables + 1] = registerGenerated(info, list, taken)
        end
    end
    discovered = found
    E.svScanned = true
    E.FireCallbacks("SavedVariablesScanned", #found)
    return #found
end

function E.EnsureSavedVariablesScanned()
    if not E.svScanned then E.ScanSavedVariables() end
end

---------------------------------------------------------------------------
-- Built-in tables
---------------------------------------------------------------------------

E.RegisterTable({
    name = "saved_variables",
    desc = "Other add-ons' SavedVariables found in memory (read-only; SCAN savedvariables to refresh)",
    key = "name",
    live = true,
    columns = {
        { "name", "text", "Global name of the saved variable" },
        { "addon", "text", "Add-on it most likely belongs to (guessed from the name)" },
        { "style", "text", "ZO_SavedVars, or registered (added with LibESQL.AddSavedVariable)" },
        { "accounts", "int", "Accounts with data" },
        { "characters", "int", "Characters with their own data" },
        { "account_wide", "bool", "Has account-wide data" },
        { "tables", "int", "Tables generated from it" },
        { "tables_list", "text", "Names of those tables" },
        { "nodes", "int", "Tables inside it that were looked at" },
        { "truncated", "bool", "Too big to look through completely" },
    },
    build = function(rows)
        E.EnsureSavedVariablesScanned()
        for _, info in ipairs(discovered) do
            local names = {}
            for i, t in ipairs(info.tables or {}) do names[i] = t.table_name end
            rows[#rows + 1] = {
                name = info.name, addon = info.addon, style = info.style,
                accounts = info.accounts, characters = info.characters, account_wide = info.accountWide,
                tables = #names, tables_list = table.concat(names, ", "),
                nodes = info.nodes, truncated = info.truncated,
            }
        end
    end,
})

E.RegisterTable({
    name = "sv_tables",
    desc = "Tables made from other add-ons' SavedVariables (each list of records becomes a table)",
    key = "table_name",
    live = true,
    columns = {
        { "table_name", "text", "Query it: SELECT * FROM <table_name>" },
        { "sv", "text", "Saved variable it comes from" },
        { "addon", "text", "Add-on it most likely belongs to" },
        { "pattern", "text", "Where the list is inside the saved variable (* = any key)" },
        { "records", "int", "Records when it was found" },
        { "columns", "int", "Columns" },
    },
    build = function(rows)
        E.EnsureSavedVariablesScanned()
        for _, info in ipairs(discovered) do
            for _, t in ipairs(info.tables or {}) do
                rows[#rows + 1] = {
                    table_name = t.table_name, sv = t.sv, addon = t.addon, pattern = t.pattern,
                    records = t.records, columns = t.columns,
                }
            end
        end
    end,
})

E.RegisterTable({
    name = "sv_values",
    desc = "Every value in other add-ons' SavedVariables, one row per value (filter with WHERE sv = '...')",
    live = true,
    columns = {
        { "sv", "text", "Saved variable" },
        { "addon", "text", "Add-on it most likely belongs to" },
        { "account", "text", "@account" },
        { "scope", "text", "Character name, or account-wide" },
        { "path", "text", "Path inside the data, e.g. settings.window.x" },
        { "key", "text", "Last part of the path" },
        { "value", "any", "The value" },
        { "type", "text", "string, number or boolean" },
        { "depth", "int", "How deep it is" },
    },
    build = function(rows, def)
        E.EnsureSavedVariablesScanned()
        local left = E.SV_MAX_VALUES
        def.truncated = false
        for _, info in ipairs(discovered) do
            for _, sc in ipairs(scopesOf(info)) do
                local seen = {}
                local function walk(node, path, depth)
                    if left <= 0 or seen[node] or depth > 20 then return end
                    seen[node] = true
                    local items = entries(node)
                    for i = 1, #items, 2 do
                        if left <= 0 then def.truncated = true; return end
                        Tick()
                        local k, v = items[i], items[i + 1]
                        local p = path == "" and keyText(k) or (path .. "." .. keyText(k))
                        if type(v) == "table" then
                            walk(v, p, depth + 1)
                        elseif isScalar(v) then
                            left = left - 1
                            rows[#rows + 1] = {
                                sv = info.name, addon = info.addon, account = sc.account, scope = sc.scope,
                                path = p, key = keyText(k), value = v, type = type(v), depth = depth,
                            }
                        end
                    end
                end
                walk(sc.data, "", 1)
            end
        end
        if def.truncated then
            E.Print("sv_values stopped at %d values; filter by sv or raise LibESQL.SV_MAX_VALUES.", E.SV_MAX_VALUES)
        end
    end,
})

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

-- Include a SavedVariables table that doesn't use ZO_SavedVars. Remembered.
-- Returns true, or nil + error text.
function E.AddSavedVariable(globalName)
    if type(globalName) ~= "string" or globalName == "" then return nil, "give the global name of the saved variable" end
    if type(rawget(_G, globalName)) ~= "table" then return nil, format("no global table '%s' (is its add-on loaded?)", globalName) end
    local list = extraNames()
    for _, n in ipairs(list) do if n == globalName then return true end end
    list[#list + 1] = globalName
    if E.sv then E.sv.extraSavedVariables = list end
    E.svScanned = false
    return true
end

function E.RemoveSavedVariable(globalName)
    local list = extraNames()
    for i = #list, 1, -1 do if list[i] == globalName then table.remove(list, i) end end
    E.svScanned = false
    return true
end

-- Rescan in the background. callback(count) when done.
function E.RescanSavedVariables(callback)
    return E.RunAsync(function() return E.ScanSavedVariables() end, function(ok, res)
        if callback then callback(ok and res or nil, not ok and E.SQL.ErrorText(res) or nil) end
    end, "savedvariables")
end

-- What the last scan found: { { name, addon, style, tables = { {table_name, pattern, records, columns}, ... } }, ... }
function E.GetSavedVariables()
    local out = {}
    for i, info in ipairs(discovered) do
        local tables = {}
        for j, t in ipairs(info.tables or {}) do
            tables[j] = { table_name = t.table_name, pattern = t.pattern, records = t.records, columns = t.columns }
        end
        out[i] = { name = info.name, addon = info.addon, style = info.style, tables = tables }
    end
    return out
end

-- First scan once the world is loaded (every add-on's SavedVariables are in by then).
if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED then
    EVENT_MANAGER:RegisterForEvent("LibESQL_SavedVars", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent("LibESQL_SavedVars", EVENT_PLAYER_ACTIVATED)
        if not E.svScanned then E.RescanSavedVariables() end
    end)
end
