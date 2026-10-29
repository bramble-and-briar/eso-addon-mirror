local ua = UAssistant
local deconstruct = ua.Deconstruct

local function IsClothingStation()
    if deconstruct.IsUniversalStation() then
        return true
    end

    return deconstruct.currentCraftingType == CRAFTING_TYPE_BLACKSMITHING
        or deconstruct.currentCraftingType == CRAFTING_TYPE_CLOTHIER
end

local function IsWearableClothing(itemLink)
    if GetItemLinkItemType(itemLink) ~= ITEMTYPE_ARMOR then
        return false
    end

    local armorType = GetItemLinkArmorType(itemLink)

    if
        armorType ~= ARMORTYPE_LIGHT
        and armorType ~= ARMORTYPE_MEDIUM
        and armorType ~= ARMORTYPE_HEAVY
    then
        return false
    end

    local equipType = GetItemLinkEquipType(itemLink)

    if equipType == EQUIP_TYPE_OFF_HAND then
        return false
    end

    return true
end

local function IsClothingTradeable(bagId, slotIndex)
    return IsItemBoPAndTradeable(bagId, slotIndex)
end

local function IsOrnateClothing(itemLink, traitInformation)
    local traitType = GetItemLinkTraitType(itemLink)

    return traitInformation == ITEM_TRAIT_INFORMATION_ORNATE
        or traitType == ITEM_TRAIT_TYPE_ARMOR_ORNATE
end

local function IsIntricateClothing(itemLink, traitInformation)
    local traitType = GetItemLinkTraitType(itemLink)

    return traitInformation == ITEM_TRAIT_INFORMATION_INTRICATE
        or traitType == ITEM_TRAIT_TYPE_ARMOR_INTRICATE
end

local function IsNirnhonedClothing(itemLink)
    return GetItemLinkTraitType(itemLink) == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED
end

local function CanExtractClothing(bagId, slotIndex)
    if deconstruct.IsUniversalStation() then
        local canExtractBlacksmithing =
            CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, CRAFTING_TYPE_BLACKSMITHING)

        local canExtractClothier =
            CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, CRAFTING_TYPE_CLOTHIER)

        return canExtractBlacksmithing or canExtractClothier
    end

    return CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, deconstruct.currentCraftingType)
end

local function GetBagItemQuality(bagId, slotIndex)
    local _, _, _, _, _, _, _, quality = GetItemInfo(bagId, slotIndex)

    return quality
end

local function IsResearchableClothingTrait(traitType)
    return traitType == ITEM_TRAIT_TYPE_ARMOR_STURDY
        or traitType == ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE
        or traitType == ITEM_TRAIT_TYPE_ARMOR_REINFORCED
        or traitType == ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED
        or traitType == ITEM_TRAIT_TYPE_ARMOR_TRAINING
        or traitType == ITEM_TRAIT_TYPE_ARMOR_INFUSED
        or traitType == ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS
        or traitType == ITEM_TRAIT_TYPE_ARMOR_DIVINES
        or traitType == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED
end

local function IsClothingAllowed(profile, bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex)

    if not itemLink or itemLink == "" then
        return false
    end

    if not IsWearableClothing(itemLink) then
        return false
    end

    if IsItemPlayerLocked(bagId, slotIndex) then
        return false
    end

    if bagId ~= BAG_BACKPACK and not profile.fromBank then
        return false
    end

    if not CanExtractClothing(bagId, slotIndex) then
        return false
    end

    local quality = GetBagItemQuality(bagId, slotIndex)

    local maxQuality = deconstruct.GetMaxQuality(profile)

    if not quality or quality > maxQuality then
        return false
    end

    local traitType = GetItemLinkTraitType(itemLink)

    local traitInformation = GetItemTraitInformationFromItemLink(itemLink)

    local nirnhoned = IsNirnhonedClothing(itemLink)

    if nirnhoned and not profile.nirnhoned then
        return false
    end

    local reconstructed = IsItemReconstructed(bagId, slotIndex)

    if reconstructed and not profile.reconstructed then
        return false
    end

    local matchesFilter = false

    if reconstructed then
        matchesFilter = true
    end

    if IsClothingTradeable(bagId, slotIndex) and profile.tradable then
        matchesFilter = true
    end

    if IsItemLinkCrafted(itemLink) and profile.crafted then
        matchesFilter = true
    end

    if IsOrnateClothing(itemLink, traitInformation) and profile.ornate then
        matchesFilter = true
    end

    if IsIntricateClothing(itemLink, traitInformation) and profile.intricate then
        matchesFilter = true
    end

    if nirnhoned and profile.nirnhoned then
        matchesFilter = true
    end

    if
        (profile.researchMode == "all" or profile.researchMode == "keep_lowest_unresearched")
        and IsResearchableClothingTrait(traitType)
    then
        matchesFilter = true
    end

    if traitType == ITEM_TRAIT_TYPE_NONE and profile.noTrait then
        matchesFilter = true
    end

    return matchesFilter
end

local function CreateClothingCandidate(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)

    return {
        bagId = bagId,
        slotIndex = slotIndex,
        itemLink = itemLink,

        quality = GetBagItemQuality(bagId, slotIndex),

        traitType = GetItemLinkTraitType(itemLink),

        armorType = GetItemLinkArmorType(itemLink),

        equipType = GetItemLinkEquipType(itemLink),

        researchable = CanItemLinkBeTraitResearched(itemLink),
    }
end

local function GetClothingResearchKey(candidate)
    return tostring(candidate.armorType)
        .. ":"
        .. tostring(candidate.equipType)
        .. ":"
        .. tostring(candidate.traitType)
end

local function RemoveLowestResearchClothing(candidates, profile)
    if profile.researchMode ~= "keep_lowest_unresearched" then
        return candidates
    end

    local lowestItemByTrait = {}

    for _, candidate in ipairs(candidates) do
        if candidate.researchable then
            local key = GetClothingResearchKey(candidate)

            local current = lowestItemByTrait[key]

            if not current or candidate.quality < current.quality then
                lowestItemByTrait[key] = candidate
            end
        end
    end

    local filteredCandidates = {}

    for _, candidate in ipairs(candidates) do
        local shouldKeepForResearch = candidate.researchable
            and lowestItemByTrait[GetClothingResearchKey(candidate)] == candidate

        if not shouldKeepForResearch then
            table.insert(filteredCandidates, candidate)
        end
    end

    return filteredCandidates
end

local function ScanClothingBag(bagId, profile, candidates)
    local bagSize = GetBagSize(bagId)

    for slotIndex = 0, bagSize - 1 do
        if IsClothingAllowed(profile, bagId, slotIndex) then
            table.insert(candidates, CreateClothingCandidate(bagId, slotIndex))
        end
    end
end

local function CollectClothingCandidates(allCandidates)
    if not IsClothingStation() then
        return
    end

    local profiles = ua.savedVariables and ua.savedVariables.deconstructProfiles

    local profile = profiles and profiles.clothing

    if not profile or not profile.enabled then
        return
    end

    local clothingCandidates = {}

    ScanClothingBag(BAG_BACKPACK, profile, clothingCandidates)

    if profile.fromBank then
        ScanClothingBag(BAG_BANK, profile, clothingCandidates)

        if IsESOPlusSubscriber() then
            ScanClothingBag(BAG_SUBSCRIBER_BANK, profile, clothingCandidates)
        end
    end

    clothingCandidates = RemoveLowestResearchClothing(clothingCandidates, profile)

    for _, candidate in ipairs(clothingCandidates) do
        table.insert(allCandidates, candidate)
    end
end

deconstruct.RegisterCollector("clothing", CollectClothingCandidates)
