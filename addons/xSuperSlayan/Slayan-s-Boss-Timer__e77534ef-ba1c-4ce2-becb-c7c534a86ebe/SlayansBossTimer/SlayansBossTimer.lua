-- SlayansBossTimer
-- Respawn timers for world, delve and public dungeon bosses.
-- This file creates the add-on namespace. It must be the first file in the manifest.

SlayansBossTimer = {
    name = "SlayansBossTimer",
    version = "1.0.0", -- Keep in step with ## Version in SlayansBossTimer.addon.
    author = "xSuperSlayan",
    debug = false,
}

local addon = SlayansBossTimer

-- The first time the player arrives in the world this session: the chat window is ready for the Loaded message,
-- and the What's New pop-up can show after an update.
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED)
    addon.Commands.PrintLoadedMessage()
    addon.Popup.ShowAfterUpdate()
end

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= addon.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

    addon.Settings.Initialize()
    addon.Timers.Initialize()
    addon.Countdown.Initialize()
    addon.Detector.Initialize()
    addon.Commands.Initialize()
    addon.Menu.Initialize()
    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
