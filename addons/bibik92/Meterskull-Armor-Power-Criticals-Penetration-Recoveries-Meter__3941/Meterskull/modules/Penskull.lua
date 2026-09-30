--------------------------------------------------------------------------------
-- PENSKULL MODULE
--------------------------------------------------------------------------------

local MS = Meterskull

local targetPenDebuffs = {
    [61742]  = 2974,  -- Minor Breach
    [61743]  = 5948,  -- Major Breach
    [120007] = 2108,  -- Infused Crusher Dummy
    [17906]  = 2108,  -- Infused Crusher
    [120018] = 6000,  -- Alkosh Dummy
    [76667]  = 6000,  -- Alkosh
    [159288] = 3541,  -- Crimson Oath
    [143808] = 1000,  -- Crystal Weapon
    [187742] = 2200,  -- Runic Sunder
}

local targetDebuffsFoN = {
    [18084]  = 660,   -- Burning
    [21929]  = 660,   -- Poisoned
    [148801] = 660,   -- Hemorrhaging
    [88401]  = 660,   -- Minor Magickasteal (work-around)
    [145875] = 660,   -- Minor Brittle  (work-around)
    [79717]  = 660,   -- Minor Vulnerability (work-around)
    [61742]  = 660,   -- Minor Breach (work-around)
    [61726]  = 660,   -- Minor Defile (work-around)
}

local forceOfNature           = false
local playerPenetrationBuff   = 0
local targetPenetrationDebuff = 0

local function IsChampionPointFoNEquipped()
    forceOfNature = false
    for disciplineIndex = 1, 12 do
        if GetSlotBoundId(disciplineIndex, HOTBAR_CATEGORY_CHAMPION) == 276 then
            forceOfNature = true
        end
    end
    return forceOfNature
end

local function GetAdditionalPenetrationFromStatusEffects()
    local additional = 0
    if DoesUnitExist("reticleover") then
        for i = 1, GetNumBuffs("reticleover") do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("reticleover", i)
            if targetDebuffsFoN[abilityId] and forceOfNature then
                additional = additional + targetDebuffsFoN[abilityId]
            end
        end
    end
    return additional
end

local function UpdatePenetrationBuffs()
    playerPenetrationBuff = 0
    if IsChampionPointFoNEquipped() then
        playerPenetrationBuff = playerPenetrationBuff + GetAdditionalPenetrationFromStatusEffects()
    end
end

local function UpdateTargetPenDebuffs()
    targetPenetrationDebuff = 0
    if DoesUnitExist("reticleover") and not IsUnitPlayer("reticleover") then
        for i = 1, GetNumBuffs("reticleover") do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("reticleover", i)
            if targetPenDebuffs[abilityId] then
                targetPenetrationDebuff = targetPenetrationDebuff + targetPenDebuffs[abilityId]
            end
        end
    end
end

local function CalculateTotalPenetration()
    return playerPenetrationBuff + targetPenetrationDebuff
end

local function PenskullRender(self, initial, skipAnimation)
    if not self.uiRefs then return end

    UpdatePenetrationBuffs()
    UpdateTargetPenDebuffs()

    local totalPen    = CalculateTotalPenetration()
    local physicalPen = GetPlayerStat(STAT_PHYSICAL_PENETRATION, STAT_BONUS_OPTION_APPLY_BONUS) + totalPen
    local spellPen    = GetPlayerStat(STAT_SPELL_PENETRATION, STAT_BONUS_OPTION_APPLY_BONUS)    + totalPen
    local maxPen      = math.max(physicalPen, spellPen)

    local oldVal = self.currentData.penetrationLevel or 0
    if initial or maxPen ~= oldVal then
        self.currentData.penetrationLevel = maxPen
        if skipAnimation then
            self.uiRefs.Penetration:SetText(string.format("%d", maxPen))
        else
            MS.AnimateTextTransition(self.uiRefs.Penetration, oldVal, maxPen, "%d", self.name)
        end
        self.uiRefs.Penetration:SetColor(unpack(
            MS.GetThresholdColor(MS.db.penskull.settings.levels.penetration, maxPen)
        ))
    end
end

local PenskullModule = MS.CreateModule(
    "penskull",
    "penskull",
    nil,
    "MSPenskull",
    PenskullRender,
    MS.DefaultScale
)
MS.RegisterModule(PenskullModule)
