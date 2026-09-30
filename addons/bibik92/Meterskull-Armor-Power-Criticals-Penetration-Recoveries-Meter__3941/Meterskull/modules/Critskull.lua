--------------------------------------------------------------------------------
-- CRITSKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local targetDebuffs = {
    [142610] = 5,   -- Flame Weakness
    [142652] = 5,   -- Frost Weakness
    [142653] = 5,   -- Shock Weakness
    [181606] = 15,  -- Elemental Catalyst (Target Dummy)
    [145975] = 10,  -- Minor Brittle
    [145977] = 20,  -- Major Brittle
}

local cpCritMod     = 0
local debuffCritMod = 0
local advCritDamage = 0

local function UpdateCritDamage()
    _, _, advCritDamage = GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_CRITICAL_DAMAGE)
end

local function UpdateTargetDebuffs()
    debuffCritMod = 0
    if DoesUnitExist("reticleover") and not IsUnitPlayer("reticleover") then
        for i = 1, GetNumBuffs("reticleover") do
            local _, _, _, _, _, _, _, _, _, _, abilityId =
                GetUnitBuffInfo("reticleover", i)
            if targetDebuffs[abilityId] then
                debuffCritMod = debuffCritMod + targetDebuffs[abilityId]
            end
        end
    end
end

local function UpdateCPMod()
    cpCritMod = 0
    for disciplineIndex = 1, 12 do
        local championSkillId = GetSlotBoundId(disciplineIndex, HOTBAR_CATEGORY_CHAMPION)
        if championSkillId == 31 then            -- Backstabber CP
            cpCritMod = cpCritMod + 10
        end
    end
end

local function CalculateTotalCritDamage()
    return 50 + advCritDamage + cpCritMod + debuffCritMod
end

local function CritskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    UpdateCritDamage()
    UpdateTargetDebuffs()
    UpdateCPMod()

    local critChance = math.max(
        GetPlayerStat(STAT_SPELL_CRITICAL, STAT_BONUS_OPTION_APPLY_BONUS),
        GetPlayerStat(STAT_CRITICAL_STRIKE, STAT_BONUS_OPTION_APPLY_BONUS)
    ) / 219.12
    local critDamage = CalculateTotalCritDamage()

    local oldChance = self.currentData.critChance or 0
    if initial or critChance ~= oldChance then
        self.currentData.critChance = critChance
        if skipAnimation then
            self.uiRefs.CritChance:SetText(string.format("%.1f%%", critChance))
        else
            MS.AnimateTextTransition(self.uiRefs.CritChance, oldChance, critChance, "%.1f%%", self.name)
        end
        self.uiRefs.CritChance:SetColor(unpack(
            MS.GetThresholdColor(MS.db.critskull.settings.levels.critChance, critChance)
        ))
    end

    local oldDamage = self.currentData.critDamage or 0
    if initial or critDamage ~= oldDamage then
        self.currentData.critDamage = critDamage
        if skipAnimation then
            self.uiRefs.CritDamage:SetText(string.format("%d%%", critDamage))
        else
            MS.AnimateTextTransition(self.uiRefs.CritDamage, oldDamage, critDamage, "%d%%", self.name)
        end
        self.uiRefs.CritDamage:SetColor(unpack(
            MS.GetThresholdColor(MS.db.critskull.settings.levels.critDamage, critDamage)
        ))
    end
end

local CritskullModule = MS.CreateModule(
    "critskull",
    "critskull",
    nil,
    "MSCritskull",
    CritskullRender,
    MS.DefaultScale
)
MS.RegisterModule(CritskullModule)
