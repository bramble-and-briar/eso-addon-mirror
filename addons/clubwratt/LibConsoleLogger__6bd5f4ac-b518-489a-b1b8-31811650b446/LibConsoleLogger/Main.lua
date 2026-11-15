-- Main.lua: entry point (events)

LibConsoleLogger = LibConsoleLogger or {}

---One line per UI load, so an export that spans several reads apart: wall clock, the game's clock (it restarts
---with the game, so a low value means the game itself was restarted) and how many lines came from before.
---@param kept number
---@return string
local function LoadMarker(kept)
    local stamp = GetTimeStamp and GetTimeStamp() or 0
    local wallClock = "t=" .. tostring(stamp)
    local osLib = rawget(_G, "os")
    if type(osLib) == "table" and type(osLib.date) == "function" then
        local ok, formatted = pcall(osLib.date, "%Y-%m-%d %H:%M:%S", stamp)
        if ok and type(formatted) == "string" then wallClock = formatted end
    elseif GetDateStringFromTimestamp and GetTimeString then
        local ok, formatted = pcall(function() return GetDateStringFromTimestamp(stamp) .. " " .. GetTimeString() end)
        if ok and type(formatted) == "string" then wallClock = formatted end
    end
    local gameClock = GetGameTimeMilliseconds and GetGameTimeMilliseconds() / 1000 or 0
    return string.format("[LibConsoleLogger] --- UI loaded %s (game clock %.1f s, %d earlier lines kept) ---",
        wallClock, gameClock, kept)
end

local function OnAddonLoaded(_eventId, addonName)
    if addonName ~= LibConsoleLogger.name then
        return
    end

    LibConsoleLogger:_EnsureSavedVars()
    local sv = LibConsoleLogger.savedVars
    local enabled = (sv and sv.enabled) == true

    if LibConsoleLogger.State then
        LibConsoleLogger.State.runtimeEnabled = enabled
    end

    -- The log saved by the previous UI load (a /reloadui, a relog, a zone change before a restart) comes back
    -- in front of this one's, with a line marking where this load begins.
    local webExport = LibConsoleLogger.WebExport
    if webExport and webExport.AdoptSavedBuffer then
        local kept = webExport.AdoptSavedBuffer(enabled)
        if enabled then
            kept = math.min(kept, webExport.GetMaxLines() - 1) -- at the cap, the marker itself takes one line
            webExport.BufferD(LoadMarker(kept))
        end
    end

    if LibConsoleLogger.Settings and LibConsoleLogger.Settings.Initialize then
        LibConsoleLogger.Settings.Initialize()
    end

    if EVENT_MANAGER and EVENT_MANAGER.UnregisterForEvent then
        EVENT_MANAGER:UnregisterForEvent(LibConsoleLogger.name, EVENT_ADD_ON_LOADED)
    end
end

if EVENT_MANAGER and EVENT_MANAGER.RegisterForEvent then
    EVENT_MANAGER:RegisterForEvent(LibConsoleLogger.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
end
