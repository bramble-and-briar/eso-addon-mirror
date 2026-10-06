local function Initialize()
    DevSandbox3.state = DevSandbox3.State.Create()
    DevSandbox3.state.savedVars = ZO_SavedVars:NewAccountWide(DevSandbox3.savedVarsName, 17, nil, DevSandbox3.State.CreateSavedVarsDefaults())
    DevSandbox3.Detection.Initialize()
    DevSandbox3.SlotActions.Initialize()
    DevSandbox3.Markers.Initialize()
    DevSandbox3.Settings.Initialize()
    SLASH_COMMANDS["/ds3"] = DevSandbox3.Slash.Handle
end

EVENT_MANAGER:RegisterForEvent(DevSandbox3.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName == DevSandbox3.name then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent(DevSandbox3.name, EVENT_ADD_ON_LOADED)
    end
end)
