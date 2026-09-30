--------------------------------------------------------------------------------
-- STAMSKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local function StamskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    if initial then
        self.uiRefs.RecoveryLabel:SetColor(0, 0.7, 0, 0.75)
    end

    local stamRecovery = GetPlayerStat(STAT_STAMINA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
    local oldVal       = self.currentData.recoveryLevel or 0

    if initial or stamRecovery ~= oldVal then
        self.currentData.recoveryLevel = stamRecovery
        if skipAnimation then
            self.uiRefs.Recovery:SetText(string.format("%.0f", stamRecovery))
        else
            MS.AnimateTextTransition(self.uiRefs.Recovery, oldVal, stamRecovery, "%.0f", self.name)
        end
        self.uiRefs.Recovery:SetColor(unpack(
            MS.GetThresholdColor(MS.db.stamskull.settings.levels.recovery, stamRecovery)
        ))
    end
end

local StamskullModule = MS.CreateModule(
    "stamskull",
    "stamskull",
    nil,
    "MSStamskull",
    StamskullRender,
    MS.DefaultScale
)
MS.RegisterModule(StamskullModule)
