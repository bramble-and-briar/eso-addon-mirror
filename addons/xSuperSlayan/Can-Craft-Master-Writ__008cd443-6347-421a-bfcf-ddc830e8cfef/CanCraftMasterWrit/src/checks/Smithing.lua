-- Blacksmithing, clothing, woodworking and jewelry master writs.
-- Checks the motif page (LibCharacterKnowledge), the trait, the set's trait count (LibLazyCrafting's set data),
-- the material skill rank, and the materials: base material, style stone, trait stone and improvement items.

local addon = CanCraftMasterWrit
local Data = addon.Data
local Util = addon.Util
local Result = addon.Result

local Smithing = {}
addon.checks[Data.KIND_SMITHING] = Smithing

---------------------------------------------------------------------------------------------------
-- Knowledge
---------------------------------------------------------------------------------------------------

local function GetMotifName(styleId, chapterId)
    local items = LibCharacterKnowledge.GetMotifItemsFromStyle(styleId)
    if type(items) == "table" then
        local itemId = (items.chapters and items.chapters[chapterId]) or (items.books and items.books[1])
        if itemId then
            return Util.ItemName(Util.ItemLink(itemId))
        end
    end
    return zo_strformat("<<1>> <<2>>", GetItemStyleName(styleId), GetString("SI_ITEMSTYLECHAPTER", chapterId))
end

local function CheckMotif(result, styleId, chapterId)
    local LCK = LibCharacterKnowledge
    local knowledge = LCK.GetMotifKnowledgeForCharacter(styleId, chapterId)
    local category = Result.CATEGORY_MOTIF
    if knowledge == LCK.KNOWLEDGE_KNOWN then
        result:Pass(category, GetString(SI_CCMW_MOTIF_KNOWN))
    elseif knowledge == LCK.KNOWLEDGE_UNKNOWN then
        result:Fail(category, GetString(SI_CCMW_MOTIF_MISSING), GetMotifName(styleId, chapterId))
    elseif knowledge == LCK.KNOWLEDGE_NODATA then
        result:Unknown(category, GetString(SI_CCMW_MOTIF_NO_DATA))
    else
        result:Unknown(category, GetString(SI_CCMW_MOTIF_UNKNOWN_STYLE), zo_strformat("<<1>>", GetItemStyleName(styleId)))
    end
end

-- Returns whether the trait is researched on the research line, and how many traits the line has researched.
local function ScanResearchLine(craftType, researchLine, traitType)
    local _, _, numTraits = GetSmithingResearchLineInfo(craftType, researchLine)
    local traitKnown, knownCount = false, 0
    for traitIndex = 1, numTraits or 0 do
        local lineTraitType, _, known = GetSmithingResearchLineTraitInfo(craftType, researchLine, traitIndex)
        if known then
            knownCount = knownCount + 1
        end
        if lineTraitType == traitType then
            traitKnown = known
        end
    end
    return traitKnown, knownCount
end

local function CheckSet(result, setId, knownCount)
    local setIndexes = LibLazyCrafting.GetSetIndexes and LibLazyCrafting.GetSetIndexes()
    local setInfo = setIndexes and setIndexes[setId]
    local traitsRequired = setInfo and (Data.SET_TRAITS_REQUIRED_FIXES[setId] or setInfo[3])
    local category = Result.CATEGORY_SET
    if not traitsRequired then
        result:Unknown(category, GetString(SI_CCMW_SET_UNKNOWN), zo_strformat("<<1>>", GetItemSetName(setId)))
        return
    end
    local count = Result.Count(knownCount, traitsRequired)
    if knownCount >= traitsRequired then
        result:Pass(category, GetString(SI_CCMW_SET_TRAITS), count)
    else
        result:Fail(category, GetString(SI_CCMW_SET_TRAITS), count)
    end
end

---------------------------------------------------------------------------------------------------
-- Materials
---------------------------------------------------------------------------------------------------

local function GetBaseMaterialLink(craftType, pattern)
    if craftType == CRAFTING_TYPE_CLOTHIER and pattern >= Data.CLOTHIER_FIRST_LEATHER_PATTERN then
        return Util.ItemLink(Data.SMITHING_CP150_LEATHER)
    end
    return Util.ItemLink(Data.SMITHING_CP150_MATERIAL[craftType])
end

local traitMaterialLinks

local function GetTraitMaterialLink(traitType)
    if not traitMaterialLinks then
        traitMaterialLinks = {}
        for traitItemIndex = 1, GetNumSmithingTraitItems() do
            local itemTraitType = GetSmithingTraitItemInfo(traitItemIndex)
            if itemTraitType and itemTraitType ~= ITEM_TRAIT_TYPE_NONE then
                traitMaterialLinks[itemTraitType] = GetSmithingTraitItemLink(traitItemIndex, LINK_STYLE_DEFAULT)
            end
        end
    end
    local link = traitMaterialLinks[traitType]
    if not link or link == "" then
        -- Trait item indexes are the trait type plus one; LibLazyCrafting relies on the same rule.
        link = GetSmithingTraitItemLink(traitType + 1, LINK_STYLE_DEFAULT)
    end
    return link ~= "" and link or nil
end

local function GetImprovementRank(craftType)
    local rank = Util.GetPassiveRank(Data.IMPROVEMENT_PASSIVE[craftType])
    if rank == nil then
        rank = GetNonCombatBonus(Data.IMPROVEMENT_BONUS[craftType])
    end
    return zo_clamp(rank or 0, 0, 3)
end

local function CheckMaterials(result, writ, pattern, baseMaterialLink)
    local craftType = writ.craftType
    local materials = {}

    local GetMatRequirements = LibLazyCrafting.functionTable and LibLazyCrafting.functionTable.GetMatRequirements
    local baseCount = GetMatRequirements and GetMatRequirements(pattern, Data.SMITHING_CP150_MATERIAL_INDEX, craftType)
    if baseCount then
        table.insert(materials, { link = baseMaterialLink, needed = baseCount })
    end

    if craftType ~= CRAFTING_TYPE_JEWELRYCRAFTING and writ.styleId > 0 then
        -- Either the style's own stone or a Crown Mimic Stone will do.
        local styleLink = GetItemStyleMaterialLink(writ.styleId, LINK_STYLE_DEFAULT)
        local mimicLink = GetItemStyleMaterialLink(GetUniversalStyleId(), LINK_STYLE_DEFAULT)
        if styleLink ~= "" then
            table.insert(materials, { links = { styleLink, mimicLink }, needed = 1 })
        else
            table.insert(materials, { link = mimicLink, needed = 1 })
        end
    end

    if writ.traitType ~= ITEM_TRAIT_TYPE_NONE then
        local traitLink = GetTraitMaterialLink(writ.traitType)
        if traitLink then
            table.insert(materials, { link = traitLink, needed = 1 })
        end
    end

    local improvementCounts = Data.IMPROVEMENT_MATERIAL_COUNTS[GetImprovementRank(craftType)]
    for step = 1, writ.quality - 1 do
        local improvementLink = GetSmithingImprovementItemLink(craftType, step, LINK_STYLE_DEFAULT)
        if improvementLink ~= "" and improvementCounts[step] then
            table.insert(materials, { link = improvementLink, needed = improvementCounts[step] })
        end
    end

    result:AddMaterials(materials)
    if not baseCount then
        result:Unknown(Result.CATEGORY_MATERIALS, GetString(SI_CCMW_MATERIAL_AMOUNT_UNKNOWN), Util.ItemName(baseMaterialLink))
    end
end

---------------------------------------------------------------------------------------------------
-- Evaluation
---------------------------------------------------------------------------------------------------

function Smithing.Evaluate(writ, result)
    local craftType = writ.craftType
    local pattern = LibLazyCrafting.GetItemTemplateIdPatternIndex(writ.templateId)
    if not pattern then
        result:Unknown(Result.CATEGORY_GENERAL, GetString(SI_CCMW_ITEM_UNKNOWN))
        return
    end

    if craftType ~= CRAFTING_TYPE_JEWELRYCRAFTING then
        local chapters = Data.MOTIF_CHAPTER_BY_PATTERN[craftType]
        local chapterId = chapters and chapters[pattern]
        if chapterId then
            CheckMotif(result, writ.styleId, chapterId)
        else
            result:Unknown(Result.CATEGORY_MOTIF, GetString(SI_CCMW_ITEM_UNKNOWN))
        end
    end

    local researchLine = Data.GetResearchLineForPattern(craftType, pattern)
    local traitKnown, knownCount = ScanResearchLine(craftType, researchLine, writ.traitType)
    if writ.traitType ~= ITEM_TRAIT_TYPE_NONE then
        if traitKnown then
            result:Pass(Result.CATEGORY_TRAIT, GetString(SI_CCMW_TRAIT_KNOWN))
        else
            result:Fail(Result.CATEGORY_TRAIT, GetString(SI_CCMW_TRAIT_MISSING), GetString("SI_ITEMTRAITTYPE", writ.traitType))
        end
    end

    if writ.setId > 0 then
        CheckSet(result, writ.setId, knownCount)
    end

    local baseMaterialLink = GetBaseMaterialLink(craftType, pattern)
    result:AddSkills({
        {
            name = Util.LevelPassiveName(craftType),
            required = GetItemLinkRequiredCraftingSkillRank(baseMaterialLink),
            current = Util.LevelPassiveRank(craftType),
        },
    })

    CheckMaterials(result, writ, pattern, baseMaterialLink)
end
