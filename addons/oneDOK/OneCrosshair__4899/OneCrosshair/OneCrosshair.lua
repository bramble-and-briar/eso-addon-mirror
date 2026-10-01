local O = OneCrosshair
EVENT_MANAGER:RegisterForEvent(O.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= O.name then return end
    EVENT_MANAGER:UnregisterForEvent(O.name, EVENT_ADD_ON_LOADED)
    O.settings = O.Settings.Load()
    O.runtime = O.Runtime.New(O.settings)
    O.Settings.Initialize(O.settings)
end)
