local OS = OneSettings

function OS:Initialize()
    local defaults = { sync = { settings = false, bindings = false, windows = false, addons = false },
        shared = {}, presets = {} }
    self.account = ZO_SavedVars:NewAccountWide("OneSettingsSavedVariables", 1, nil, defaults, GetWorldName())
    self.character = ZO_SavedVars:NewCharacterIdSettings("OneSettingsSavedVariables", 1, nil, {}, GetWorldName())
    -- Retire the former local-profile adoption state without changing shared data.
    self.account.selfObserved, self.account.addonObserved, self.account.rejoining = nil, nil, nil
    self.account.syncDiagnostics, self.character.lastLocal = nil, nil
    if self.account.shared.addons then self.account.shared.addons.states[self.name] = nil end
    self.modules.addons:Initialize()
    self.modules.settings:Initialize()
    self.modules.bindings:Initialize()
    self.modules.windows:Initialize()
    self.UI:Initialize()

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        if self.active then return end
        self.active = true
        self.ready = true
        for _, category in ipairs({ "addons", "settings", "bindings", "windows" }) do self:Apply(category) end
        if not self.reloadPending then
            self.character.reloadAttempt = nil
            self:ShowPendingWarnings()
        end
        if self.reloadPending then self:Later("Reload", function() self:TryReload() end) end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_DEACTIVATED, function() self:Flush() end)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat and self.ready then
            if self.modules.bindings.deferred then self:Apply("bindings") end
            self:TryReload()
        end
    end)
    ZO_PreHook("ReloadUI", function() self:Flush() end)
end

EVENT_MANAGER:RegisterForEvent(OS.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= OS.name then return end
    EVENT_MANAGER:UnregisterForEvent(OS.name, EVENT_ADD_ON_LOADED)
    OS:Initialize()
end)
