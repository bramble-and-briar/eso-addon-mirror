--------------------------------------------------------------------------------
-- HEALTHSKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local function HealthskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    if initial then
        self.uiRefs.RecoveryLabel:SetColor(1, 0.3, 0.3, 0.75)
    end

    local healthRecovery = GetPlayerStat(STAT_HEALTH_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
    local oldVal         = self.currentData.recoveryLevel or 0

    if initial or healthRecovery ~= oldVal then
        self.currentData.recoveryLevel = healthRecovery
        if skipAnimation then
            self.uiRefs.Recovery:SetText(string.format("%.0f", healthRecovery))
        else
            MS.AnimateTextTransition(self.uiRefs.Recovery, oldVal, healthRecovery, "%.0f", self.name)
        end
        self.uiRefs.Recovery:SetColor(unpack(
            MS.GetThresholdColor(MS.db.healthskull.settings.levels.recovery, healthRecovery)
        ))
    end
end

local HealthskullModule = MS.CreateModule(
    "healthskull",
    "healthskull",
    nil,
    "MSHealthskull",
    HealthskullRender,
    MS.DefaultScale
)
MS.RegisterModule(HealthskullModule)
