CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

-- The addon's one EVENT_ADD_ON_LOADED and one EVENT_PLAYER_ACTIVATED handler.
-- The other files only define functions; this file calls them in a fixed
-- order, saved data first. It is listed last in the manifest.
local EVENT_NAMESPACE = "CompanionRoster"

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= CompanionRoster.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)

    CompanionRoster.Data.Initialize()
    CompanionRoster.UI.Initialize()
    CompanionRoster.HUD.Initialize()
    CompanionRoster.Settings.Initialize()
end

-- Every activation: login, /reloadui and each loading screen.
local function OnPlayerActivated()
    CompanionRoster.Data.OnPlayerActivated()
    CompanionRoster.HUD.OnPlayerActivated()
    CompanionRoster.UI.OnPlayerActivated()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
