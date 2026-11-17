-- HomeAfterPvPMain.lua: Entry point; wires state, saved vars, the travel
-- handlers and the settings page.

local HomeAfterPvP = HomeAfterPvP

local function Initialize()
    HomeAfterPvP.state = HomeAfterPvP.State.Create()
    HomeAfterPvP.state.savedVars = ZO_SavedVars:NewAccountWide(
        HomeAfterPvP.savedVarsName,
        HomeAfterPvP.savedVarsVersion,
        nil,
        HomeAfterPvP.state.savedVars
    )

    HomeAfterPvP.TravelActions.Initialize()
    HomeAfterPvP.SettingsActions.Initialize()

    HomeAfterPvP.Log(string.format("Loaded v%s", HomeAfterPvP.version))
end

EVENT_MANAGER:RegisterForEvent(HomeAfterPvP.name .. "_Load", EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == HomeAfterPvP.name then
        EVENT_MANAGER:UnregisterForEvent(HomeAfterPvP.name .. "_Load", EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)
