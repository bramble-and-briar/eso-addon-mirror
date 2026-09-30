--------------------------------------------------------------------------------
-- MAGSKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local function MagskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    if initial then
        self.uiRefs.RecoveryLabel:SetColor(0.12, 0.49, 1, 0.75)
    end

    local magRecovery = GetPlayerStat(STAT_MAGICKA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
    local oldVal      = self.currentData.recoveryLevel or 0

    if initial or magRecovery ~= oldVal then
        self.currentData.recoveryLevel = magRecovery
        if skipAnimation then
            self.uiRefs.Recovery:SetText(string.format("%.0f", magRecovery))
        else
            MS.AnimateTextTransition(self.uiRefs.Recovery, oldVal, magRecovery, "%.0f", self.name)
        end
        self.uiRefs.Recovery:SetColor(unpack(
            MS.GetThresholdColor(MS.db.magskull.settings.levels.recovery, magRecovery)
        ))
    end
end

local MagskullModule = MS.CreateModule(
    "magskull",
    "magskull",
    nil,
    "MSMagskull",
    MagskullRender,
    MS.DefaultScale
)
MS.RegisterModule(MagskullModule)
