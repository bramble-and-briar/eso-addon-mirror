local R = Relais

function R:Initialize()
    local defaults = {
        schema = 2, nextId = 1, profiles = {}, order = {}, log = {},
        pages = { [1] = "Mes setups" }, pageOrder = { 1 }, nextPageId = 2,
        settings = { automatic = false },
        rules = { zones = {}, bosses = {}, positions = {}, trashAfterBosses = {}, nextPointId = 1 },
    }
    -- Keep this SavedVars version stable. Migrations must preserve previous profiles.
    self.db = ZO_SavedVars:NewCharacterIdSettings("RelaisSavedVariables", 1, nil, defaults, GetWorldName())
    if self.InitializeContentCatalog then self:InitializeContentCatalog() end
    self:NormalizeSavedData()
    self.adapter = self.AdapterClass.New()
    self.engine = self.EngineClass.New(self.adapter, function(state, message, id, components) self:OnEngineState(state, message, id, components) end)
    self:InitializeAutomation()
    self:InitializeUI()
    if self.InitializeExtras then self:InitializeExtras() end
    EVENT_MANAGER:RegisterForUpdate("RelaisEngine", 150, function()
        local ok = pcall(self.TickEngine, self)
        if not ok then
            self.db.settings.automatic = false
            self:SavedDataChanged()
            self.engine.pending, self.engine.active, self.engine.pausedAt = nil, nil, nil
            self:OnEngineState("error", "Le changement s'est interrompu. Vérifie ton équipement et tes compétences, puis réessaie.")
        end
    end)
    self.statusMessage = self.statusMessage or "Prêt."
    self:RefreshUI()
    for _, event in ipairs({ EVENT_PLAYER_DEACTIVATED, EVENT_PLAYER_ACTIVATED }) do
        local registeredEvent = event
        EVENT_MANAGER:RegisterForEvent("RelaisSave", event, function()
            self:RequestSavedVariablesSave()
            if registeredEvent == EVENT_PLAYER_ACTIVATED and self.InitializeContentCatalog then
                self:InitializeContentCatalog()
                self:RefreshUI()
            end
        end)
    end
end

EVENT_MANAGER:RegisterForEvent("RelaisLoaded", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= R.name then return end
    EVENT_MANAGER:UnregisterForEvent("RelaisLoaded", EVENT_ADD_ON_LOADED)
    local ok = pcall(function() R:Initialize() end)
    if not ok then
        if R.db and type(R.db.settings) == "table" then R.db.settings.automatic = false; R:SavedDataChanged() end
        EVENT_MANAGER:UnregisterForUpdate("RelaisEngine")
        EVENT_MANAGER:UnregisterForUpdate("RelaisAutomation")
        EVENT_MANAGER:UnregisterForUpdate("RelaisBank")
        EVENT_MANAGER:UnregisterForEvent("RelaisSave", EVENT_PLAYER_DEACTIVATED)
        EVENT_MANAGER:UnregisterForEvent("RelaisSave", EVENT_PLAYER_ACTIVATED)
        for _, event in ipairs({ EVENT_PLAYER_DEACTIVATED, EVENT_PLAYER_ACTIVATED, EVENT_ZONE_CHANGED,
            EVENT_BOSSES_CHANGED, EVENT_PLAYER_COMBAT_STATE, EVENT_PLAYER_DEAD, EVENT_PLAYER_ALIVE,
            EVENT_RETICLE_TARGET_CHANGED }) do
            EVENT_MANAGER:UnregisterForEvent("RelaisAutomation", event)
        end
        if EVENT_UNIT_DEATH_STATE_CHANGED then EVENT_MANAGER:UnregisterForEvent("RelaisAutomation", EVENT_UNIT_DEATH_STATE_CHANGED) end
        R:Notify("Impossible d'ouvrir Setup Assist. Recharge l'interface du jeu et réessaie.")
    end
end)
