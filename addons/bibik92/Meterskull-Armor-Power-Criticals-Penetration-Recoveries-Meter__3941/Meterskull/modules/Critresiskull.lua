--------------------------------------------------------------------------------
-- CRITRESISKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local function CritresiskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    local critResist = GetPlayerStat(STAT_CRITICAL_RESISTANCE, STAT_BONUS_OPTION_APPLY_BONUS)
    local oldVal     = self.currentData.critResistLevel or 0
    local percent    = math.floor(-critResist / 66)

    if initial or critResist ~= oldVal then
        self.currentData.critResistLevel = critResist
        -- Numeric value
        if skipAnimation then
            self.uiRefs.CritResistValue:SetText(string.format("%d", critResist))
        else
            MS.AnimateTextTransition(self.uiRefs.CritResistValue, oldVal, critResist, "%d", self.name)
        end
        self.uiRefs.CritResistValue:SetColor(unpack(
            MS.GetThresholdColor(MS.db.critresiskull.settings.levels.critResist, critResist)
        ))
        -- Percentage value
        local oldPercent = self.currentData.critResistPercent or 0
        self.currentData.critResistPercent = percent
        if skipAnimation then
            self.uiRefs.CritResistPercent:SetText(string.format("%d%%", percent))
        else
            MS.AnimateTextTransition(self.uiRefs.CritResistPercent, oldPercent, percent, "%d%%", self.name)
        end
        self.uiRefs.CritResistPercent:SetColor(unpack(
            MS.GetThresholdColor(MS.db.critresiskull.settings.levels.critResist, critResist)
        ))
    end
end

local CritresiskullModule = MS.CreateModule(
    "critresiskull",
    "critresiskull",
    nil,
    "MSCritresiskull",
    CritresiskullRender,
    MS.DefaultScale
)
MS.RegisterModule(CritresiskullModule)
