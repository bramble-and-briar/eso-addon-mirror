--------------------------------------------------------------------------------
-- POWERSKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local function PowerskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    local power  = math.max(
        GetPlayerStat(STAT_POWER, STAT_BONUS_OPTION_APPLY_BONUS),
        GetPlayerStat(STAT_SPELL_POWER, STAT_BONUS_OPTION_APPLY_BONUS)
    )

    local oldVal = self.currentData.powerLevel or 0

    if initial or power ~= oldVal then
        self.currentData.powerLevel = power

        if skipAnimation then
            self.uiRefs.Power:SetText(string.format("%d", power))
        else
            MS.AnimateTextTransition(self.uiRefs.Power, oldVal, power, "%d", self.name)
        end
        self.uiRefs.Power:SetColor(unpack(
            MS.GetThresholdColor(MS.db.powerskull.settings.levels.power, power)
        ))
    end
end

local PowerskullModule = MS.CreateModule(
    "powerskull",
    "powerskull",
    nil,
    "MSPowerskull",
    PowerskullRender,
    MS.DefaultScale
)
MS.RegisterModule(PowerskullModule)
