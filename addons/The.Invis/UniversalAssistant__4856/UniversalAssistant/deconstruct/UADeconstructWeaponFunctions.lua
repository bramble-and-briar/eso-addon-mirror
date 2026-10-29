local ua = UAssistant
local deconstruct = ua.Deconstruct

local function IsShield(itemLink)
    return GetItemLinkItemType(itemLink) == ITEMTYPE_ARMOR
        and GetItemLinkEquipType(itemLink) == EQUIP_TYPE_OFF_HAND
end

local function IsWeaponOrShield(itemLink)
    return GetItemLinkItemType(itemLink) == ITEMTYPE_WEAPON or IsShield(itemLink)
end

local function IsWeaponStation()
    if deconstruct.IsUniversalStation() then
        return true
    end

    return deconstruct.currentCraftingType == CRAFTING_TYPE_BLACKSMITHING
        or deconstruct.currentCraftingType == CRAFTING_TYPE_WOODWORKING
end

local function IsWeaponTradeable(bagId, slotIndex)
    return IsItemBoPAndTradeable(bagId, slotIndex)
end

local function IsOrnateWeapon(itemLink, traitInformation)
    local traitType = GetItemLinkTraitType(itemLink)

    return traitInformation == ITEM_TRAIT_INFORMATION_ORNATE
        or traitType == ITEM_TRAIT_TYPE_WEAPON_ORNATE
        or traitType == ITEM_TRAIT_TYPE_ARMOR_ORNATE
end

local function IsIntricateWeapon(itemLink, traitInformation)
    local traitType = GetItemLinkTraitType(itemLink)

    return traitInformation == ITEM_TRAIT_INFORMATION_INTRICATE
        or traitType == ITEM_TRAIT_TYPE_WEAPON_INTRICATE
        or traitType == ITEM_TRAIT_TYPE_ARMOR_INTRICATE
end

local function IsNirnhonedWeapon(itemLink)
    local traitType = GetItemLinkTraitType(itemLink)

    return traitType == ITEM_TRAIT_TYPE_WEAPON_NIRNHONED
        or traitType == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED
end

local function CanExtractWeapon(bagId, slotIndex)
    if deconstruct.IsUniversalStation() then
        return CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, CRAFTING_TYPE_BLACKSMITHING)
            or CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, CRAFTING_TYPE_WOODWORKING)
    end

    return CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, deconstruct.currentCraftingType)
end

local function GetBagItemQuality(bagId, slotIndex)
    local _, _, _, _, _, _, _, quality = GetItemInfo(bagId, slotIndex)

    return quality
end

local function IsResearchableWeaponTrait(traitType)
    return traitType == ITEM_TRAIT_TYPE_WEAPON_POWERED
        or traitType == ITEM_TRAIT_TYPE_WEAPON_CHARGED
        or traitType == ITEM_TRAIT_TYPE_WEAPON_PRECISE
        or traitType == ITEM_TRAIT_TYPE_WEAPON_INFUSED
        or traitType == ITEM_TRAIT_TYPE_WEAPON_DEFENDING
        or traitType == ITEM_TRAIT_TYPE_WEAPON_TRAINING
        or traitType == ITEM_TRAIT_TYPE_WEAPON_SHARPENED
        or traitType == ITEM_TRAIT_TYPE_WEAPON_DECISIVE
        or traitType == ITEM_TRAIT_TYPE_WEAPON_NIRNHONED
        or traitType == ITEM_TRAIT_TYPE_ARMOR_STURDY
        or traitType == ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE
        or traitType == ITEM_TRAIT_TYPE_ARMOR_REINFORCED
        or traitType == ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED
        or traitType == ITEM_TRAIT_TYPE_ARMOR_TRAINING
        or traitType == ITEM_TRAIT_TYPE_ARMOR_INFUSED
        or traitType == ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS
        or traitType == ITEM_TRAIT_TYPE_ARMOR_DIVINES
        or traitType == ITEM_TRAIT_TYPE_ARMOR_NIRNHONED
end

local function IsWeaponAllowed(profile, bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex)

    if not itemLink or itemLink == "" then
        return false
    end

    if not IsWeaponOrShield(itemLink) then
        return false
    end

    if IsItemPlayerLocked(bagId, slotIndex) then
        return false
    end

    if bagId ~= BAG_BACKPACK and not profile.fromBank then
        return false
    end

    if not CanExtractWeapon(bagId, slotIndex) then
        return false
    end

    local quality = GetBagItemQuality(bagId, slotIndex)

    local maxQuality = deconstruct.GetMaxQuality(profile)

    if not quality or quality > maxQuality then
        return false
    end

    local traitType = GetItemLinkTraitType(itemLink)

    local traitInformation = GetItemTraitInformationFromItemLink(itemLink)

    local nirnhoned = IsNirnhonedWeapon(itemLink)

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

    if IsWeaponTradeable(bagId, slotIndex) and profile.tradable then
        matchesFilter = true
    end

    if IsItemLinkCrafted(itemLink) and profile.crafted then
        matchesFilter = true
    end

    if IsOrnateWeapon(itemLink, traitInformation) and profile.ornate then
        matchesFilter = true
    end

    if IsIntricateWeapon(itemLink, traitInformation) and profile.intricate then
        matchesFilter = true
    end

    if nirnhoned and profile.nirnhoned then
        matchesFilter = true
    end

    if
        (profile.researchMode == "all" or profile.researchMode == "keep_lowest_unresearched")
        and IsResearchableWeaponTrait(traitType)
    then
        matchesFilter = true
    end

    if traitType == ITEM_TRAIT_TYPE_NONE and profile.noTrait then
        matchesFilter = true
    end

    return matchesFilter
end

local function CreateWeaponCandidate(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)

    return {
        bagId = bagId,
        slotIndex = slotIndex,
        itemLink = itemLink,

        quality = GetBagItemQuality(bagId, slotIndex),

        traitType = GetItemLinkTraitType(itemLink),

        weaponType = IsShield(itemLink) and "shield" or GetItemLinkWeaponType(itemLink),

        researchable = CanItemLinkBeTraitResearched(itemLink),
    }
end

local function GetWeaponResearchKey(candidate)
    return tostring(candidate.weaponType) .. ":" .. tostring(candidate.traitType)
end

local function RemoveLowestResearchWeapons(candidates, profile)
    if profile.researchMode ~= "keep_lowest_unresearched" then
        return candidates
    end

    local lowestItemByTrait = {}

    for _, candidate in ipairs(candidates) do
        if candidate.researchable then
            local key = GetWeaponResearchKey(candidate)

            local current = lowestItemByTrait[key]

            if not current or candidate.quality < current.quality then
                lowestItemByTrait[key] = candidate
            end
        end
    end

    local filteredCandidates = {}

    for _, candidate in ipairs(candidates) do
        local shouldKeepForResearch = candidate.researchable
            and lowestItemByTrait[GetWeaponResearchKey(candidate)] == candidate

        if not shouldKeepForResearch then
            table.insert(filteredCandidates, candidate)
        end
    end

    return filteredCandidates
end

local function ScanWeaponBag(bagId, profile, candidates)
    local bagSize = GetBagSize(bagId)

    for slotIndex = 0, bagSize - 1 do
        if IsWeaponAllowed(profile, bagId, slotIndex) then
            table.insert(candidates, CreateWeaponCandidate(bagId, slotIndex))
        end
    end
end

local function CollectWeaponCandidates(allCandidates)
    if not IsWeaponStation() then
        return
    end

    local profiles = ua.savedVariables and ua.savedVariables.deconstructProfiles

    local profile = profiles and profiles.weapon

    if not profile or not profile.enabled then
        return
    end

    local weaponCandidates = {}

    ScanWeaponBag(BAG_BACKPACK, profile, weaponCandidates)

    if profile.fromBank then
        ScanWeaponBag(BAG_BANK, profile, weaponCandidates)

        if IsESOPlusSubscriber() then
            ScanWeaponBag(BAG_SUBSCRIBER_BANK, profile, weaponCandidates)
        end
    end

    weaponCandidates = RemoveLowestResearchWeapons(weaponCandidates, profile)

    for _, candidate in ipairs(weaponCandidates) do
        table.insert(allCandidates, candidate)
    end
end

deconstruct.RegisterCollector("weapon", CollectWeaponCandidates)
