-- TravelWheelMain.lua: Entry point; wires state, saved vars, the catalog, the
-- trip after an instance, the queue accept, the wheel entries and the
-- settings page.

local TravelWheel = TravelWheel

local function Initialize()
    TravelWheel.state = TravelWheel.State.Create()
    TravelWheel.state.savedVars = ZO_SavedVars:NewAccountWide(
        TravelWheel.savedVarsName,
        TravelWheel.savedVarsVersion,
        nil,
        TravelWheel.state.savedVars
    )

    TravelWheel.CatalogActions.Initialize()
    TravelWheel.ReturnActions.Initialize()
    TravelWheel.AcceptActions.Initialize()
    TravelWheel.WheelActions.Initialize()
    TravelWheel.SettingsActions.Initialize()

    TravelWheel.Log(string.format("Loaded v%s with %d destinations",
        TravelWheel.version, #TravelWheel.state.savedVars.destinations))
end

EVENT_MANAGER:RegisterForEvent(TravelWheel.name .. "_Load", EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == TravelWheel.name then
        EVENT_MANAGER:UnregisterForEvent(TravelWheel.name .. "_Load", EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)
