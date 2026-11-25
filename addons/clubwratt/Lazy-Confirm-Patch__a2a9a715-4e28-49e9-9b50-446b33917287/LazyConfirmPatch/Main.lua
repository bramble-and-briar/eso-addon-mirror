-- Main.lua: entry point
local LazyConfirmPatch = LazyConfirmPatch

EVENT_MANAGER:RegisterForEvent(LazyConfirmPatch.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == LazyConfirmPatch.name then
        EVENT_MANAGER:UnregisterForEvent(LazyConfirmPatch.name, EVENT_ADD_ON_LOADED)
        LazyConfirmPatch.CooldownActions.Install()
    end
end)
