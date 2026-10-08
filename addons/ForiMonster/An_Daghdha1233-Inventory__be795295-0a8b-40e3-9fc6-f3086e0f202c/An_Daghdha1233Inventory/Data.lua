-- Read-only inventory data for An_Daghdha1233 Inventory.
An_Daghdha1233Inventory = An_Daghdha1233Inventory or {}
local Data = {}
An_Daghdha1233Inventory.Data = Data

local PLAYER_WORN_SLOTS = {
    { EQUIP_SLOT_HEAD, "Head" },
    { EQUIP_SLOT_CHEST, "Chest" },
    { EQUIP_SLOT_SHOULDERS, "Shoulders" },
    { EQUIP_SLOT_HAND, "Hands" },
    { EQUIP_SLOT_WAIST, "Waist" },
    { EQUIP_SLOT_LEGS, "Legs" },
    { EQUIP_SLOT_FEET, "Feet" },
    { EQUIP_SLOT_NECK, "Neck" },
    { EQUIP_SLOT_RING1, "Ring 1" },
    { EQUIP_SLOT_RING2, "Ring 2" },
    { EQUIP_SLOT_MAIN_HAND, "Main hand" },
    { EQUIP_SLOT_OFF_HAND, "Off hand" },
    { EQUIP_SLOT_BACKUP_MAIN, "Backup main hand" },
    { EQUIP_SLOT_BACKUP_OFF, "Backup off hand" },
}

local WEAPON_SLOTS = {
    [EQUIP_SLOT_MAIN_HAND] = true,
    [EQUIP_SLOT_OFF_HAND] = true,
    [EQUIP_SLOT_BACKUP_MAIN] = true,
    [EQUIP_SLOT_BACKUP_OFF] = true,
}

local function ReadItem(bagId, slotIndex)
    if not HasItemInSlot(bagId, slotIndex) then
        return nil
    end

    local uniqueId = GetItemUniqueId(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" then
        return nil
    end

    local icon, stackCount, _, _, _, equipType, _, _, displayQuality = GetItemInfo(bagId, slotIndex)
    local itemType = GetItemType and GetItemType(bagId, slotIndex) or GetItemLinkItemType(itemLink)
    local filterTypes = GetItemFilterTypeInfo and { GetItemFilterTypeInfo(bagId, slotIndex) } or {}
    local isNew = false
    if bagId == BAG_BACKPACK and SHARED_INVENTORY and SHARED_INVENTORY.IsItemNew then
        isNew = SHARED_INVENTORY:IsItemNew(bagId, slotIndex) == true
    end

    local item = {
        bagId = bagId,
        slotIndex = slotIndex,
        uniqueId = uniqueId,
        itemLink = itemLink,
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bagId, slotIndex)),
        icon = icon,
        quality = displayQuality,
        stackCount = stackCount or 1,
        equipType = equipType,
        itemType = itemType,
        armorType = itemType == ITEMTYPE_ARMOR and GetItemLinkArmorType
            and GetItemLinkArmorType(itemLink) or nil,
        weaponType = GetItemLinkWeaponType and GetItemLinkWeaponType(itemLink) or nil,
        filterTypes = filterTypes,
        locked = IsItemPlayerLocked(bagId, slotIndex) == true,
        isNew = isNew,
    }

    -- Discard a partial read if this slot changed while collecting its fields.
    if not HasItemInSlot(bagId, slotIndex) then
        return nil
    end
    local currentId = GetItemUniqueId(bagId, slotIndex)
    if GetItemLink(bagId, slotIndex) ~= itemLink
        or (uniqueId ~= nil and (currentId == nil or not AreId64sEqual(currentId, uniqueId))) then
        return nil
    end
    return item
end

local function HasFilterType(item, expected)
    if expected == nil then return false end
    for _, filterType in pairs(item.filterTypes or {}) do
        if filterType == expected then return true end
    end
    return false
end

function Data.IsSlottable(item)
    return type(item) == "table" and not item.isQuest
        and HasFilterType(item, ITEMFILTERTYPE_QUICKSLOT)
end

function Data.GetGearGroup(item)
    if type(item) ~= "table" then return nil end
    if item.itemType == ITEMTYPE_WEAPON
        or (WEAPONTYPE_SHIELD and item.weaponType == WEAPONTYPE_SHIELD) then
        return "weapons"
    end
    if item.itemType ~= ITEMTYPE_ARMOR then return nil end
    if (EQUIP_TYPE_NECK and item.equipType == EQUIP_TYPE_NECK)
        or (EQUIP_TYPE_RING and item.equipType == EQUIP_TYPE_RING) then
        return "jewelry"
    end
    if ARMORTYPE_HEAVY and item.armorType == ARMORTYPE_HEAVY then return "heavy" end
    if ARMORTYPE_MEDIUM and item.armorType == ARMORTYPE_MEDIUM then return "medium" end
    if ARMORTYPE_LIGHT and item.armorType == ARMORTYPE_LIGHT then return "light" end
    return "other"
end

-- Quest inventory is separate from backpack slots in ESO. Keep its entries
-- read-only: they have no bag/slot identity and must never reach equip actions.
function Data.CollectQuest()
    local items = {}
    if not SHARED_INVENTORY or not SHARED_INVENTORY.GenerateFullQuestCache then
        return items
    end
    local cache = SHARED_INVENTORY:GenerateFullQuestCache()
    if type(cache) ~= "table" then
        return items
    end
    for _, questItems in pairs(cache) do
        if type(questItems) == "table" then
            for _, questItem in pairs(questItems) do
                if type(questItem) == "table" and questItem.questItemId ~= nil then
                    items[#items + 1] = {
                        isQuest = true,
                        questItemId = questItem.questItemId,
                        questIndex = questItem.questIndex,
                        toolIndex = questItem.toolIndex,
                        stepIndex = questItem.stepIndex,
                        conditionIndex = questItem.conditionIndex,
                        name = questItem.name or "Quest item",
                        icon = questItem.iconFile,
                        stackCount = questItem.stackCount or 1,
                        equipType = EQUIP_TYPE_INVALID,
                        locked = false,
                        isNew = false,
                    }
                end
            end
        end
    end
    table.sort(items, function(a, b)
        if a.questIndex ~= b.questIndex then
            return (a.questIndex or 0) < (b.questIndex or 0)
        end
        -- Place quest tools before their associated collected items.
        if (a.toolIndex ~= nil) ~= (b.toolIndex ~= nil) then
            return a.toolIndex ~= nil
        end
        if (a.toolIndex or 0) ~= (b.toolIndex or 0) then
            return (a.toolIndex or 0) < (b.toolIndex or 0)
        end
        if (a.stepIndex or 0) ~= (b.stepIndex or 0) then
            return (a.stepIndex or 0) < (b.stepIndex or 0)
        end
        if (a.conditionIndex or 0) ~= (b.conditionIndex or 0) then
            return (a.conditionIndex or 0) < (b.conditionIndex or 0)
        end
        return a.name < b.name
    end)
    return items
end

function Data.GetCategory(item)
    if type(item) ~= "table" then
        return nil
    end
    if item.isQuest or item.questItemId ~= nil then
        return "quest"
    end
    if item.itemType == ITEMTYPE_WEAPON or item.itemType == ITEMTYPE_ARMOR then
        return "gear"
    end
    if ITEMFILTERTYPE_CRAFTING then
        for _, filterType in pairs(item.filterTypes or {}) do
            if filterType == ITEMFILTERTYPE_CRAFTING then
                return "materials"
            end
        end
    end
    return "supplies"
end

function Data.CollectBag()
    local items = {}
    local bagSize = GetBagSize(BAG_BACKPACK)
    if not bagSize or bagSize <= 0 then
        return items
    end
    for slotIndex = 0, bagSize - 1 do
        local item = ReadItem(BAG_BACKPACK, slotIndex)
        if item then
            items[#items + 1] = item
        end
    end
    return items
end

function Data.GetEquipped()
    local items = {}
    for _, slot in ipairs(PLAYER_WORN_SLOTS) do
        local item = ReadItem(BAG_WORN, slot[1])
        if item then
            item.equipSlot = slot[1]
            item.slotLabel = slot[2]
            items[#items + 1] = item
        end
    end
    return items
end

function Data.ValidateItem(ref)
    if type(ref) ~= "table" or (ref.bagId ~= BAG_BACKPACK and ref.bagId ~= BAG_WORN)
        or type(ref.slotIndex) ~= "number" or ref.uniqueId == nil then
        return nil
    end
    if not HasItemInSlot(ref.bagId, ref.slotIndex) then
        return nil
    end
    local currentId = GetItemUniqueId(ref.bagId, ref.slotIndex)
    if currentId == nil or not AreId64sEqual(currentId, ref.uniqueId) then
        return nil
    end
    local fresh = ReadItem(ref.bagId, ref.slotIndex)
    if not fresh or fresh.uniqueId == nil or not AreId64sEqual(fresh.uniqueId, ref.uniqueId) then
        return nil
    end
    return fresh
end

-- Use the same broad capability checks as ESO's inventory. Reward boxes,
-- bags, books, and consumables need not share an item type.
function Data.GetUseAction(ref)
    local item = Data.ValidateItem(ref)
    if not item or item.bagId ~= BAG_BACKPACK
        or type(IsItemUsable) ~= "function"
        or type(CanInteractWithItem) ~= "function"
        or type(GetItemUseType) ~= "function"
        or type(GetItemCooldownInfo) ~= "function" then
        return nil
    end

    local usable, onlyFromActionSlot = IsItemUsable(item.bagId, item.slotIndex)
    if not usable or onlyFromActionSlot
        or not CanInteractWithItem(item.bagId, item.slotIndex) then
        return nil
    end
    local remaining = GetItemCooldownInfo(item.bagId, item.slotIndex)
    if remaining and remaining > 0 then
        return nil
    end

    local useType = GetItemUseType(item.bagId, item.slotIndex)
    if useType ~= nil and (useType == ITEM_USE_TYPE_ITEM_DYE_STAMP
        or useType == ITEM_USE_TYPE_COSTUME_DYE_STAMP
        or useType == ITEM_USE_TYPE_KEEP_RECALL_STONE
        or useType == ITEM_USE_TYPE_SKILL_RESPEC
        or useType == ITEM_USE_TYPE_MORPH_RESPEC
        or useType == ITEM_USE_TYPE_ATTRIBUTE_RESPEC) then
        return nil
    end

    if ITEM_USE_TYPE_COMBINATION and useType == ITEM_USE_TYPE_COMBINATION then
        return { label = "Combine", protectedFunction = "InitiateConfirmUseInventoryItem" }
    end
    local isContainer = (ITEMTYPE_CONTAINER and item.itemType == ITEMTYPE_CONTAINER)
        or (ITEMTYPE_CONTAINER_CURRENCY and item.itemType == ITEMTYPE_CONTAINER_CURRENCY)
        or (ITEMTYPE_CONTAINER_STACKABLE and item.itemType == ITEMTYPE_CONTAINER_STACKABLE)
    return { label = isContainer and "Open" or "Use", protectedFunction = "UseItem" }
end

function Data.GetDestinations(ref)
    local item = Data.ValidateItem(ref)
    local destinations = {}
    if not item or item.bagId ~= BAG_BACKPACK or item.equipType == EQUIP_TYPE_INVALID then
        return destinations
    end
    if GetItemActorCategory(item.bagId, item.slotIndex) ~= GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        return destinations
    end
    local canEquip = IsEquipable(item.bagId, item.slotIndex) == true

    for _, slot in ipairs(PLAYER_WORN_SLOTS) do
        local equipSlot, label = slot[1], slot[2]
        if ZO_Character_DoesEquipSlotUseEquipType(equipSlot, item.equipType) then
            local equippedLink = ""
            if HasItemInSlot(BAG_WORN, equipSlot) then
                equippedLink = GetItemLink(BAG_WORN, equipSlot)
            end
            destinations[#destinations + 1] = {
                equipSlot = equipSlot,
                wornBagId = BAG_WORN,
                equippedLink = equippedLink,
                label = label,
                canEquip = canEquip and (not WEAPON_SLOTS[equipSlot] or not IsLockedWeaponSlot(equipSlot)),
            }
        end
    end
    return destinations
end

local function IsCurrentDestination(destinations, destination)
    if type(destination) ~= "table" or destination.wornBagId ~= BAG_WORN
        or type(destination.equipSlot) ~= "number" then
        return false
    end
    for _, legalDestination in ipairs(destinations) do
        if legalDestination.equipSlot == destination.equipSlot then
            return true
        end
    end
    return false
end

function Data.DescribeComparison(ref, destination)
    local item = Data.ValidateItem(ref)
    if not item or not IsCurrentDestination(Data.GetDestinations(item), destination) then
        return nil
    end

    -- Read the worn item again; a destination snapshot can be stale.
    local equipped = ReadItem(BAG_WORN, destination.equipSlot)
    if not equipped then
        return nil
    end

    local candidateType = GetItemLinkItemType(item.itemLink)
    local currentType = GetItemLinkItemType(equipped.itemLink)
    if candidateType ~= currentType then
        return nil
    end

    if candidateType == ITEMTYPE_WEAPON then
        local candidate = GetItemLinkWeaponPower(item.itemLink)
        local current = GetItemLinkWeaponPower(equipped.itemLink)
        if not candidate or not current or candidate <= 0 or current <= 0 then
            return nil
        end
        return {
            kind = "weaponPower",
            label = "Item damage",
            candidate = candidate,
            current = current,
            delta = candidate - current,
        }
    end

    if candidateType == ITEMTYPE_ARMOR then
        local candidate = GetItemLinkArmorRating(item.itemLink, true)
        local current = GetItemLinkArmorRating(equipped.itemLink, true)
        local candidateBase = GetItemLinkArmorRating(item.itemLink, false)
        local currentBase = GetItemLinkArmorRating(equipped.itemLink, false)
        if not candidate or not current or not candidateBase or not currentBase
            or candidateBase <= 0 or currentBase <= 0 then
            return nil
        end
        local conditionAdjusted = candidate ~= candidateBase or current ~= currentBase
        return {
            kind = "armorRating",
            label = conditionAdjusted and "Armor rating (current condition)" or "Armor rating",
            candidate = candidate,
            current = current,
            delta = candidate - current,
            candidateBase = candidateBase,
            currentBase = currentBase,
            candidateCondition = GetItemLinkCondition(item.itemLink),
            currentCondition = GetItemLinkCondition(equipped.itemLink),
        }
    end

    return nil
end
