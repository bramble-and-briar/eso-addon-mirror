-- SatchelExchangeMain.lua: Entry point; wires state, saved vars, the store keybind,
-- the unboxer's triggers, and the wheel entry.

local SatchelExchange = SatchelExchange

local function Initialize()
    local State = SatchelExchange.State

    SatchelExchange.state = State.Create()
    SatchelExchange.state.savedVars = ZO_SavedVars:NewAccountWide(
        SatchelExchange.savedVarsName,
        SatchelExchange.savedVarsVersion,
        nil,
        SatchelExchange.state.savedVars
    )

    SatchelExchange.KeybindActions.Initialize()
    SatchelExchange.StoreActions.InitializeSessionHandlers()
    SatchelExchange.UnboxActions.InitializePersistentHandlers()
    SatchelExchange.SettingsActions.Initialize()
    SatchelExchange.RadialActions.Initialize()

    SatchelExchange.Log(string.format("Loaded v%s", SatchelExchange.version))
end

EVENT_MANAGER:RegisterForEvent(SatchelExchange.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == SatchelExchange.name then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent(SatchelExchange.name, EVENT_ADD_ON_LOADED)
    end
end)
