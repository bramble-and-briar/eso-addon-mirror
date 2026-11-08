local BEV = BetterEffectViewer

function BEV:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide("BetterEffectViewer_SV", 3, nil, self.defaults)
    self:MigrateSavedVars()

    self.hasTarget = false
    self.targetLostAt = nil
    self.needsRedraw = false
    self.nextRescanAt = 0
    self.nextMaintenanceAt = 0
    self.nextVisualUpdateAt = 0

    self:ApplyRuntimePlatformTuning()
    self:CreateUI()
    self:ApplyCurrentLayout()
    self:ApplyLockState()

    self:CreateSettingsMenu()
    self:RegisterSlashCommands()
    self:RegisterEvents()

    self:OnReticleTargetChanged()
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= BEV.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(BEV.name, EVENT_ADD_ON_LOADED)
    BEV:Initialize()
end

EVENT_MANAGER:RegisterForEvent(BEV.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
