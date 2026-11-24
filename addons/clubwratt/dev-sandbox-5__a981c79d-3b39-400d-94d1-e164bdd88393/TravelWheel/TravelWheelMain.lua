-- TravelWheelMain.lua: Entry point; wires state, saved vars, the catalog, the
-- queue accept, the wheel entries and the settings page.

local TravelWheel = TravelWheel

local function Initialize()
    TravelWheel.state = TravelWheel.State.Create()
    TravelWheel.state.savedVars = ZO_SavedVars:NewAccountWide(
        TravelWheel.savedVarsName,
        TravelWheel.savedVarsVersion,
        nil,
        TravelWheel.state.savedVars
    )

    -- Settings from before 0.7.0 that nothing reads any more.
    TravelWheel.state.savedVars.afterInstance = nil
    TravelWheel.state.savedVars.fromScoreboard = nil
    -- And the ones of the trip back after an instance, gone in 0.15.0.
    TravelWheel.state.savedVars.returnHouse = nil
    TravelWheel.state.savedVars.requeueCampaign = nil
    TravelWheel.state.savedVars.autoReturn = nil
    -- A destination saved before 0.10.0 has only the name and icon it was
    -- given: those are its own.
    for _, destination in ipairs(TravelWheel.state.savedVars.destinations) do
        destination.defaultName = destination.defaultName or destination.name
        destination.defaultIcon = destination.defaultIcon or destination.icon
    end
    local dropped = TravelWheel.SettingsUtils.MigrateBattlegroundEntries(
        TravelWheel.state.savedVars.destinations, TravelWheel.state.savedVars.battlegroundQueues)
    TravelWheel.state.savedVars.battlegroundQueues = nil
    if dropped > 0 then
        TravelWheel.Log(string.format("battleground entries from before 0.11.0: %d dropped, one kept", dropped))
    end

    TravelWheel.CatalogActions.Initialize()
    TravelWheel.TravelActions.Initialize()
    TravelWheel.AcceptActions.Initialize()
    TravelWheel.WheelActions.Initialize()
    TravelWheel.SettingsActions.Initialize()

    -- The console shows no error window: every Lua error goes to the log,
    -- whoever raised it.
    EVENT_MANAGER:RegisterForEvent(TravelWheel.name .. "_LuaError", EVENT_LUA_ERROR, function(_, errorText)
        errorText = tostring(errorText)
        TravelWheel.Log("lua error: " .. string.sub(errorText, 1, 900))
        TravelWheel.TravelActions.OnLuaError(errorText)
    end)

    TravelWheel.Log(string.format("Loaded v%s with %d destinations",
        TravelWheel.version, #TravelWheel.state.savedVars.destinations))
end

EVENT_MANAGER:RegisterForEvent(TravelWheel.name .. "_Load", EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == TravelWheel.name then
        EVENT_MANAGER:UnregisterForEvent(TravelWheel.name .. "_Load", EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)
