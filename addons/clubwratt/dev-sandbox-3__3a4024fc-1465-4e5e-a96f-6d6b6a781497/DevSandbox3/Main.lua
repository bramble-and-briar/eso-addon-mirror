local DevSandbox3 = DevSandbox3
local LogUtils = DevSandbox3.LogUtils

local function Initialize()
    local State = DevSandbox3.State

    DevSandbox3.state = State.Create()
    DevSandbox3.state.savedVars = ZO_SavedVars:NewAccountWide(
        DevSandbox3.savedVarsName,
        DevSandbox3.savedVarsVersion,
        nil,
        State.CreateSavedVarsDefaults()
    )

    if State.Migrate(DevSandbox3.state.savedVars) then
        LogUtils.Log("Settings updated for v%s: chat lines for empty slots are OFF (re-enable in settings if you want them)", DevSandbox3.version)
    end

    if not LibMapPins or not LibGPS3 then
        LogUtils.Log("Missing LibMapPins-1.0 or LibGPS - addon disabled")
        return
    end

    DevSandbox3.PinActions.RegisterPinType()
    DevSandbox3.NodeActions.RegisterEvents()
    DevSandbox3.CompassActions.Initialize()
    DevSandbox3.AlertActions.Initialize()
    DevSandbox3.CoverageActions.Initialize()
    DevSandbox3.SlotActions.Initialize()
    DevSandbox3.WorldMarkerActions.Initialize()
    DevSandbox3.Settings.Initialize()

    SLASH_COMMANDS["/ds3"] = DevSandbox3.SlashCommandActions.HandleCommand

    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name, EVENT_PLAYER_ACTIVATED, function()
        DevSandbox3.PinActions.RefreshPins()
    end)

    LogUtils.Log("Loaded v%s - %d saved spawn(s). DO NOT INSTALL (dev sandbox). /ds3 for commands", DevSandbox3.version, #DevSandbox3.state.savedVars.nodes)
end

EVENT_MANAGER:RegisterForEvent(DevSandbox3.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == DevSandbox3.name then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent(DevSandbox3.name, EVENT_ADD_ON_LOADED)
    end
end)
