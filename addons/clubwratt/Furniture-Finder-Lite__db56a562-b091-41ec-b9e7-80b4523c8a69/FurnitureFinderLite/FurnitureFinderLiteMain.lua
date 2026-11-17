-- FurnitureFinderLiteMain.lua: load sequence and slash commands.
--   /ffl            status: data age, credits, hooks, counters, errors
--   /ffl on | off   source lines in tooltips on / off
--   /ffl <item id>  the source lines of that furnishing, in chat
--   /ffl debug      diagnostics on / off
--   /ffl export     ship the LibConsoleLogger buffer
-- The add-on has no settings page and needs no library: it works as installed.
local FFL = FurnitureFinderLite

local CREDITS = "data: the Furniture Catalogue database by wookiefriseur, manavortex and contributors; after Furniture Finder by @Aldimar77. A separate add-on by clubwratt, not theirs."

---@return string how much data there is and when it was last updated
local function DataText()
    local data = FFL.Data
    if not data then
        return "data module missing"
    end
    return FFL.Fmt("%s furnishings, %s sources, last updated %s", FFL.LinesUtils.NumberText(data.count), FFL.LinesUtils.NumberText(data.records), tostring(data.updated))
end

local function Status()
    local d = FFL.diagnostics
    FFL.Chat(FFL.Fmt("v%s; %s", FFL.version, DataText()))
    FFL.Chat(CREDITS)
    FFL.Chat(FFL.Fmt("tooltips: %s; %s", FFL.Tooltip and FFL.Tooltip.StateText() or "module missing", FFL.state.savedVars.enabled and "on" or "switched off (/ffl on)"))
    FFL.Chat(FFL.Fmt("memory: %s (at this add-on's first line: %s; after its last: %s)", FFL.MemText(), tostring(d.memAtFileStart), tostring(d.memAtFileEnd)))
    FFL.Chat(FFL.Fmt("tooltips written: %d; debug %s; %d init error(s), %d runtime error(s)", d.counters.tooltips or 0, FFL.state.savedVars.debug and "on" or "off", #d.initErrors, #d.errors))
    for _, err in ipairs(d.initErrors) do
        FFL.Chat("  init: " .. err)
    end
    for index = math.max(1, #d.errors - 4), #d.errors do
        FFL.Chat("  error: " .. d.errors[index])
    end
end

---The source lines of a furnishing, by item id, to chat.
---@param itemId integer
local function Show(itemId)
    local lines = FFL.Lines and FFL.Lines.ForFurnishing(itemId)
    if not lines then
        FFL.Chat(FFL.Fmt("item %d is not in the data (updated %s)", itemId, tostring(FFL.Data and FFL.Data.updated)))
        return
    end
    FFL.Chat(FFL.Fmt("item %d:", itemId))
    for _, line in ipairs(lines) do
        FFL.Chat(line)
    end
end

-- Registered at file scope so "/ffl" answers even if Initialize never runs.
local function HandleCommand(args)
    local command = string.lower(string.match(args or "", "^%s*(%S*)") or "")
    if command == "" or command == "status" then
        FFL.SafeCall("Status", Status)
    elseif tonumber(command) then
        FFL.SafeCall("Show", Show, tonumber(command))
    elseif command == "on" or command == "off" then
        FFL.state.savedVars.enabled = command == "on"
        FFL.Chat(FFL.Fmt("source lines in tooltips: %s", command))
    elseif command == "debug" then
        FFL.state.savedVars.debug = not FFL.state.savedVars.debug
        FFL.Chat(FFL.Fmt("debug mode %s", FFL.state.savedVars.debug and "ON" or "OFF"))
    elseif command == "export" then
        FFL.Export()
    else
        FFL.Chat("/ffl (status) | on | off (source lines in tooltips) | <item id> (that furnishing's sources) | debug | export")
    end
end

SLASH_COMMANDS["/ffl"] = HandleCommand
SLASH_COMMANDS["/furniturefinderlite"] = HandleCommand

local function Initialize()
    local d = FFL.diagnostics
    if d.initialized then
        return
    end
    d.initialized = true

    local okSV, savedVars = pcall(ZO_SavedVars.NewAccountWide, ZO_SavedVars, FFL.savedVarsName, FFL.savedVarsVersion, nil, FFL.state.savedVars)
    if okSV then
        FFL.state.savedVars = savedVars
    else
        table.insert(d.initErrors, "savedVars: " .. tostring(savedVars))
    end
    for _, moduleName in ipairs({ "Data", "DataUtils", "LinesUtils", "Lines", "Tooltip" }) do
        if not FFL[moduleName] then
            table.insert(d.initErrors, "module missing: " .. moduleName)
        end
    end
    if FFL.Tooltip then
        FFL.SafeCall("TooltipInitialize", FFL.Tooltip.Initialize)
    end
    FFL.Log("loaded v%s (%d init errors); data %s, updated %s, %s furnishings; memory at this add-on's first line: %s, after its last: %s, now: %s", FFL.version, #d.initErrors,
        tostring(FFL.Data and FFL.Data.version), tostring(FFL.Data and FFL.Data.updated), tostring(FFL.Data and FFL.Data.count), tostring(d.memAtFileStart), tostring(d.memAtFileEnd), FFL.MemText())
    FFL.Log("tooltips: %s", FFL.Tooltip and FFL.Tooltip.StateText() or "module missing")
    for _, err in ipairs(d.initErrors) do
        FFL.Log("  initError: %s", err)
    end
    -- A broken install should be visible even without debug mode.
    if #d.initErrors > 0 then
        FFL.Chat(FFL.Fmt("v%s loaded with %d init error(s); /ffl for details", FFL.version, #d.initErrors))
    end
end

EVENT_MANAGER:RegisterForEvent(FFL.name .. "_Loaded", EVENT_ADD_ON_LOADED, function(_event, addonName)
    if addonName == FFL.name then
        EVENT_MANAGER:UnregisterForEvent(FFL.name .. "_Loaded", EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)

-- Debug mode: a Lua error that names this add-on goes to the log (consoles show none of them).
local luaErrors = 0
EVENT_MANAGER:RegisterForEvent(FFL.name .. "_LuaError", EVENT_LUA_ERROR, function(_event, errorText, errorCode)
    local text = tostring(errorText)
    if FFL.state.savedVars.debug ~= true or not string.find(text, FFL.name, 1, true) then
        return
    end
    luaErrors = luaErrors + 1
    if luaErrors <= 10 then
        FFL.Log("LUA ERROR #%d (code %s): %s", luaErrors, tostring(errorCode), string.sub(text, 1, 900))
    end
end)

-- Last line of this add-on's last file.
FFL.diagnostics.memAtFileEnd = FFL.MemText()
