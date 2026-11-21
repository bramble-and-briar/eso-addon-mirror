-- ESQL start-up and slash commands. The query API lives in LibESQL.

local E = ESQL
local L = LibESQL
local format = string.format

if ZO_CreateStringId then
    ZO_CreateStringId("SI_BINDING_NAME_ESQL_TOGGLE", "Toggle ESQL window")
end

local DEFAULTS = {
    history = {},
    uiScale = 1.2,
    highlight = true,
}

-- Save the last result into SavedVariables for use outside the game.
-- name: letters, digits and _ (default "export"). Saved as ESQL_SV.exports[name];
-- ESQL/tools/esql_to_mysql.py turns them into a phpMyAdmin .sql file.
function E.ExportLast(name)
    local res = E.lastResult
    if not res then L.Print("Run a query first."); return end
    name = tostring(name or ""):lower():gsub("[^%w_]", "_")
    if name == "" or name == "_" then name = "export" end
    local cap = L.isConsole and 2000 or 20000
    local rows = {}
    for r = 1, math.min(#res.rows, cap) do
        local copy = {}
        for c = 1, #res.columns do
            local v = res.rows[r][c]
            local tv = type(v)
            if tv == "number" or tv == "string" or tv == "boolean" then copy[c] = v end
        end
        rows[r] = copy
    end
    local saved = { query = res.query or E.sv.lastQuery, columns = res.columns, rows = rows, time = GetTimeStamp and GetTimeStamp() }
    E.sv.exports = E.sv.exports or {}
    E.sv.exports[name] = saved
    E.sv.export = saved   -- the most recent export, as before
    L.Print("Saved %d row(s) as export '%s'. It is written to SavedVariables/ESQL.lua on /reloadui or logout; run ESQL/tools/esql_to_mysql.py to make a .sql file for phpMyAdmin.", #rows, name)
end

function E.ListExports()
    local names = {}
    for n, x in pairs(E.sv.exports or {}) do names[#names + 1] = format("%s (%d rows)", n, #(x.rows or {})) end
    table.sort(names)
    return names
end

---------------------------------------------------------------------------
-- Slash commands (PC)
---------------------------------------------------------------------------
local function slash(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = arg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    if not cmd then
        E.UI.Toggle()
    elseif cmd == "log" then
        if rest == "on" then L.SetCombatLogging(true); L.Print("Combat logging on (table combat_log).")
        elseif rest == "off" then L.SetCombatLogging(false); L.Print("Combat logging off.")
        elseif rest == "clear" then L.ClearCombatLog(); L.Print("Combat log cleared.")
        else L.Print("Combat log: %s, %d events. /esql log on|off|clear", L.IsCombatLogging() and "on" or "off", L.combatLog.n) end
    elseif cmd == "track" then
        if rest == "on" or rest == "off" then
            L.SetEffectTracking(rest == "on")
            L.Print("Effect tracking %s (table effects_seen).", rest)
        else
            L.Print("Effect tracking is %s. /esql track on|off", L.IsEffectTracking() and "on" or "off")
        end
    elseif cmd == "size" or cmd == "scale" then
        if tonumber(rest) then E.UI.SetScale(tonumber(rest))
        else L.Print("Text size is %.1f. /esql size 0.6-2.5 (e.g. /esql size 1.4)", E.sv.uiScale or 1) end
    elseif cmd == "highlight" then
        if rest == "on" or rest == "off" then
            E.UI.SetHighlight(rest == "on")
            L.Print("Syntax highlighting %s.", rest)
        else
            L.Print("Syntax highlighting is %s. /esql highlight on|off", E.UI.HighlightEnabled() and "on" or "off")
        end
    elseif cmd == "export" then
        E.ExportLast(rest)
    elseif cmd == "exports" then
        if rest == "clear" then
            E.sv.exports, E.sv.export = {}, nil
            L.Print("Removed all saved exports.")
        else
            local names = E.ListExports()
            L.Print(#names > 0 and ("Saved exports: " .. table.concat(names, ", ")) or "No saved exports. Run a query, then /esql export <name>.")
        end
    elseif cmd == "reset" then
        E.sv.window = nil
        E.UI.SetScale(E.sv.uiScale or 1)
        L.Print("Window position reset.")
    else
        -- anything else is SQL (SELECT, SHOW TABLES, DESCRIBE, SCAN, HELP, ...)
        E.UI.RunText(arg)
    end
end

---------------------------------------------------------------------------
-- Load
---------------------------------------------------------------------------
local function onLoaded(_, addonName)
    if addonName ~= E.name then return end
    EVENT_MANAGER:UnregisterForEvent(E.name, EVENT_ADD_ON_LOADED)

    E.sv = ZO_SavedVars:NewAccountWide("ESQL_SV", 2, nil, DEFAULTS)
    if E.sv.history == nil then E.sv.history = {} end
    -- the ESQL add-on records effects by default (the library alone does not)
    if not E.sv.trackingChosen then
        E.sv.trackingChosen = true
        L.SetEffectTracking(true)
    end
    if SLASH_COMMANDS then
        SLASH_COMMANDS["/esql"] = slash
        if not SLASH_COMMANDS["/sql"] then SLASH_COMMANDS["/sql"] = slash end
    end
    E.Console.Init()
end

EVENT_MANAGER:RegisterForEvent(E.name, EVENT_ADD_ON_LOADED, onLoaded)
