-- CanCraftMasterWrit
-- Shows on every master writ tooltip whether the current character can craft it, and what is missing.
-- This file creates the addon namespace. It must be the first file in the manifest.

CanCraftMasterWrit = {
    name = "CanCraftMasterWrit",
    version = "1.0", -- Keep in step with ## Version in CanCraftMasterWrit.addon.
    author = "xSuperSlayan",
    checks = {},       -- Craft-specific evaluators, keyed by writ kind (see src/checks).
    debug = false,
}

local addon = CanCraftMasterWrit

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
    addon.WritParser.Initialize()
    addon.Tooltip.Initialize()
    addon.Commands.Initialize()
    addon.Menu.Initialize()
    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
