--------------------------------------------------------------------------------
-- ARMORSKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local function ArmorskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    local physicalResist = GetPlayerStat(STAT_DAMAGE_RESIST_PHYSICAL, STAT_BONUS_OPTION_APPLY_BONUS)
    local spellResist    = GetPlayerStat(STAT_DAMAGE_RESIST_MAGIC, STAT_BONUS_OPTION_APPLY_BONUS)

    if initial or physicalResist ~= (self.currentData.physicalResist or 0) then
        if skipAnimation then
            self.uiRefs.PhysicalResist:SetText(string.format("%d", physicalResist))
        else
            MS.AnimateTextTransition(
                self.uiRefs.PhysicalResist,
                self.currentData.physicalResist or 0,
                physicalResist,
                "%d",
                self.name
            )
        end
        self.currentData.physicalResist = physicalResist
        self.uiRefs.PhysicalResist:SetColor(unpack(
            MS.GetThresholdColor(
                MS.db.armorskull.settings.levels.physical,
                physicalResist
            )
        ))
    end

    if initial or spellResist ~= (self.currentData.spellResist or 0) then
        if skipAnimation then
            self.uiRefs.SpellResist:SetText(string.format("%d", spellResist))
        else
            MS.AnimateTextTransition(
                self.uiRefs.SpellResist,
                self.currentData.spellResist or 0,
                spellResist,
                "%d",
                self.name
            )
        end
        self.currentData.spellResist = spellResist
        self.uiRefs.SpellResist:SetColor(unpack(
            MS.GetThresholdColor(
                MS.db.armorskull.settings.levels.spell,
                spellResist
            )
        ))
    end
end

local ArmorskullModule = MS.CreateModule(
    "armorskull",
    "armorskull",
    nil,
    "MSArmorskull",
    ArmorskullRender,
    MS.DefaultScale
)
MS.RegisterModule(ArmorskullModule)
