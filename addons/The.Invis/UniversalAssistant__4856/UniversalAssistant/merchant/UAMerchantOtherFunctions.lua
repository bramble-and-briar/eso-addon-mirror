local ua = UAssistant
local merchant = ua.Merchant

local UNDAUNTED_PLUNDER_ITEM_ID = 114427

local function CreateDefaults()
    return {
        emptySoulGemsEnabled = false,
        undauntedPlunderEnabled = false,
        treasuresEnabled = false,
        trashEnabled = false,
        monsterTrophiesEnabled = false,
        fishingBaitEnabled = false,
        trophyFishEnabled = false,
    }
end

merchant.RegisterProfile("other", CreateDefaults)

merchant.RegisterCategory("other", function(profile, bagId, slotIndex, itemLink)
    local itemType, specializedItemType = GetItemLinkItemType(itemLink)

    if
        profile.emptySoulGemsEnabled
        and itemType == ITEMTYPE_SOUL_GEM
        and IsItemSoulGem(SOUL_GEM_TYPE_EMPTY, bagId, slotIndex)
    then
        return true
    end

    if
        profile.undauntedPlunderEnabled
        and GetItemLinkItemId(itemLink) == UNDAUNTED_PLUNDER_ITEM_ID
    then
        return true
    end

    if
        profile.treasuresEnabled
        and itemType == ITEMTYPE_TREASURE
        and GetItemLinkItemId(itemLink) ~= UNDAUNTED_PLUNDER_ITEM_ID
    then
        return true
    end

    if profile.trashEnabled and itemType == ITEMTYPE_TRASH then
        return true
    end

    if
        profile.monsterTrophiesEnabled
        and itemType == ITEMTYPE_COLLECTIBLE
        and specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_MONSTER_TROPHY
    then
        return true
    end

    if profile.fishingBaitEnabled and itemType == ITEMTYPE_LURE then
        return true
    end

    return profile.trophyFishEnabled
        and itemType == ITEMTYPE_COLLECTIBLE
        and specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH
end)
