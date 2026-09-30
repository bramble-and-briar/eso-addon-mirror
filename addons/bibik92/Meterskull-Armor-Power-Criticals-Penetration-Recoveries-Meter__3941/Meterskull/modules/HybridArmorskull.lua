--------------------------------------------------------------------------------
-- HYBRIDARMORSKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local function HybridArmorskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    local physicalResist = GetPlayerStat(STAT_DAMAGE_RESIST_PHYSICAL, STAT_BONUS_OPTION_APPLY_BONUS)
    local spellResist    = GetPlayerStat(STAT_DAMAGE_RESIST_MAGIC, STAT_BONUS_OPTION_APPLY_BONUS)

    local lowestResist  = math.min(physicalResist, spellResist)
    local isPhysicalLow = (physicalResist <= spellResist)

    local oldVal        = self.currentData.resistLevel   or 0
    local oldIsPhysical = self.currentData.isPhysicalLow

    if initial or lowestResist ~= oldVal or isPhysicalLow ~= oldIsPhysical then
        self.currentData.resistLevel   = lowestResist
        self.currentData.isPhysicalLow = isPhysicalLow

        if skipAnimation then
            self.uiRefs.Resist:SetText(string.format("%d", lowestResist))
        else
            MS.AnimateTextTransition(
                self.uiRefs.Resist, oldVal, lowestResist, "%d", self.name
            )
        end
        self.uiRefs.Resist:SetColor(unpack(
            MS.GetThresholdColor(
                MS.db.hybridarmorskull.settings.levels.lowestResist,
                lowestResist
            )
        ))

        self.uiRefs.ResistLabel:SetText(isPhysicalLow and "PR" or "SR")
    end
end

local HybridArmorskullModule = MS.CreateModule(
    "hybridarmorskull",
    "hybridarmorskull",
    nil,
    "MSHybridArmorskull",
    HybridArmorskullRender,
    MS.DefaultScale
)
MS.RegisterModule(HybridArmorskullModule)
