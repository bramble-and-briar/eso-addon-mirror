DeskUI = DeskUI or {}
DeskUI.Core = {}
local C = DeskUI.Core

-- Pure data operations: no keyboard-mode inventory controls or PC-only templates.
function C.Filter(items, query, category, sortKey, descending)
    local result = {}
    query = string.lower(query or "")
    for _, item in ipairs(items) do
        if C.MatchesCategory(item, category)
            and string.find(string.lower(item.name .. " " .. item.kind), query, 1, true) then
            result[#result + 1] = item
        end
    end
    table.sort(result, function(a, b)
        local av, bv = a[sortKey], b[sortKey]
        if sortKey == "name" then av, bv = string.lower(av), string.lower(bv) end
        if av == bv then
            local an, bn = string.lower(a.name), string.lower(b.name)
            if an == bn then return a.slot < b.slot end
            return an < bn
        end
        if descending then return av > bv end
        return av < bv
    end)
    return result
end

function C.MatchesCategory(item, category)
    if category == "All" then return true end
    if category == "Junk" then return item.junk == true or item.category == "Junk" end
    if category == "Companion" then return item.category == "Companion" end
    local filters = {Weapons = "WEAPONS", Armor = "ARMOR", Jewelry = "JEWELRY", Consumables = "CONSUMABLE",
        Crafting = "CRAFTING", Furnishing = "FURNISHING", Miscellaneous = "MISCELLANEOUS"}
    local filter = filters[category] and _G["ITEMFILTERTYPE_" .. filters[category]]
    if filter and item.filters and #item.filters > 0 then
        for _, value in ipairs(item.filters) do if value == filter then return true end end
        return false
    end
    return category == item.category
end

function C.ClampOffset(offset, count, visible)
    return math.max(0, math.min(offset, math.max(0, count - visible)))
end

function C.Category(itemType, equipType, bag, slot)
    if bag and C.Try("IsItemJunk", bag, slot) then return "Junk" end
    if equipType and ((EQUIP_TYPE_RING and equipType == EQUIP_TYPE_RING)
        or (EQUIP_TYPE_NECK and equipType == EQUIP_TYPE_NECK)) then return "Jewelry" end
    if bag and C.Try("GetItemActorCategory", bag, slot) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
        and GAMEPLAY_ACTOR_CATEGORY_COMPANION ~= nil then return "Companion" end
    if itemType == ITEMTYPE_WEAPON then return "Weapons" end
    if itemType == ITEMTYPE_ARMOR then return "Armor" end
    if itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK
        or itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON then return "Consumables" end
    if ITEMTYPE_FURNISHING and itemType == ITEMTYPE_FURNISHING then return "Furnishing" end
    for _, name in ipairs({"BLACKSMITHING_RAW_MATERIAL", "BLACKSMITHING_MATERIAL", "BLACKSMITHING_BOOSTER",
        "CLOTHIER_RAW_MATERIAL", "CLOTHIER_MATERIAL", "CLOTHIER_BOOSTER", "WOODWORKING_RAW_MATERIAL",
        "WOODWORKING_MATERIAL", "WOODWORKING_BOOSTER", "JEWELRYCRAFTING_RAW_MATERIAL", "JEWELRYCRAFTING_MATERIAL",
        "JEWELRYCRAFTING_BOOSTER", "JEWELRYCRAFTING_RAW_BOOSTER", "INGREDIENT", "REAGENT", "POTION_BASE",
        "POISON_BASE", "ENCHANTING_RUNE_ASPECT", "ENCHANTING_RUNE_ESSENCE", "ENCHANTING_RUNE_POTENCY",
        "STYLE_MATERIAL", "RAW_MATERIAL", "ARMOR_TRAIT", "WEAPON_TRAIT", "JEWELRY_TRAIT", "FURNISHING_MATERIAL"}) do
        if _G["ITEMTYPE_" .. name] and itemType == _G["ITEMTYPE_" .. name] then return "Crafting" end
    end
    return "Miscellaneous"
end

function C.ReadBackpack()
    local items = {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local item = C.ReadItem(BAG_BACKPACK, slot)
        if item then items[#items + 1] = item end
    end
    return items
end

function C.ReadItem(bag, slot)
        if slot ~= nil and GetSlotStackSize(bag, slot) > 0 then
            local icon, stack, price, _, locked, equipType, _, quality, displayQuality = GetItemInfo(bag, slot)
            local itemType = GetItemType(bag, slot)
            local name = GetItemName(bag, slot)
            if zo_strformat and SI_TOOLTIP_ITEM_NAME then name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name) end
            return {
                bag = bag, slot = slot, name = name, icon = icon, stack = stack,
                value = price or 0, quality = displayQuality or quality or 1, locked = locked,
                itemType = itemType, equipType = equipType,
                filters = {C.Try("GetItemFilterTypeInfo", bag, slot)}, junk = C.Try("IsItemJunk", bag, slot) == true,
                kind = GetString("SI_ITEMTYPE", itemType), category = C.Category(itemType, equipType, bag, slot),
                link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT),
            }
        end
end

-- Optional detail APIs are isolated: a missing API must not break browsing.
function C.Try(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local result = {pcall(fn, ...)}
    if result[1] then return unpack(result, 2) end
end

function C.QualityColor(quality)
    local colors = {
        [0] = {0.55, 0.55, 0.55, 1}, [1] = {0.94, 0.93, 0.88, 1},
        [2] = {0.30, 0.80, 0.16, 1}, [3] = {0.28, 0.61, 0.94, 1},
        [4] = {0.67, 0.34, 0.94, 1}, [5] = {0.91, 0.75, 0.29, 1},
    }
    return unpack(colors[quality] or colors[1])
end

C.Slots = {
    {"HEAD", "Head", "head", 92, 300},
    {"SHOULDERS", "Shoulders", "shoulders", 20, 375},
    {"CHEST", "Chest", "chest", 164, 375},
    {"HAND", "Hands", "hands", 20, 450},
    {"WAIST", "Waist", "belt", 164, 450},
    {"LEGS", "Legs", "legs", 20, 525},
    {"FEET", "Feet", "feet", 164, 525},
    {"NECK", "Neck", "neck", 20, 650},
    {"RING1", "Ring 1", "ring", 92, 650},
    {"RING2", "Ring 2", "ring", 164, 650},
    {"MAIN_HAND", "Main", "mainhand", 20, 775},
    {"OFF_HAND", "Off", "offhand", 92, 775},
    {"BACKUP_MAIN", "Back main", "mainhand", 20, 860},
    {"BACKUP_OFF", "Back off", "offhand", 92, 860},
}

function C.ReadEquipment()
    local items = {}
    if not BAG_WORN then return items end
    for _, definition in ipairs(C.Slots) do
        local slot = _G["EQUIP_SLOT_" .. definition[1]]
        local item = C.ReadItem(BAG_WORN, slot)
        if item then item.slotLabel = definition[2]; items[slot] = item end
    end
    return items
end

function C.Comparison(item, equipment)
    if not item or item.bag == BAG_WORN then return nil end
    local types = {CHEST = "CHEST", FEET = "FEET", HAND = "HAND", HEAD = "HEAD", LEGS = "LEGS",
        NECK = "NECK", RING = "RING1", SHOULDERS = "SHOULDERS", WAIST = "WAIST",
        ONE_HAND = "MAIN_HAND", TWO_HAND = "MAIN_HAND", MAIN_HAND = "MAIN_HAND", OFF_HAND = "OFF_HAND"}
    for kind, slotName in pairs(types) do
        if _G["EQUIP_TYPE_" .. kind] ~= nil and item.equipType == _G["EQUIP_TYPE_" .. kind] then
            local activePair = C.Try("GetActiveWeaponPairInfo")
            if activePair == ACTIVE_WEAPON_PAIR_BACKUP and activePair ~= nil then
                if slotName == "MAIN_HAND" then slotName = "BACKUP_MAIN"
                elseif slotName == "OFF_HAND" then slotName = "BACKUP_OFF" end
            end
            return equipment[_G["EQUIP_SLOT_" .. slotName]]
        end
    end
end

function C.Stat(item)
    if item.itemType == ITEMTYPE_WEAPON then return C.Try("GetItemLinkWeaponPower", item.link), "DAMAGE" end
    if item.itemType == ITEMTYPE_ARMOR then return C.Try("GetItemLinkArmorRating", item.link, true), "ARMOR" end
    return nil, "QUANTITY"
end

function C.Description(item)
    local lines = {}
    local function Add(text) if text and text ~= "" then lines[#lines + 1] = text end end
    local _, enchant, description = C.Try("GetItemLinkEnchantInfo", item.link)
    if enchant and enchant ~= "" then Add(enchant); Add(description); Add(" ") end
    local trait, traitDescription = C.Try("GetItemLinkTraitInfo", item.link)
    if trait and trait ~= ITEM_TRAIT_TYPE_NONE and traitDescription and traitDescription ~= "" then
        Add(GetString("SI_ITEMTRAITTYPE", trait)); Add(traitDescription); Add(" ")
    end
    local hasSet, setName, bonuses, equipped, maxEquipped = C.Try("GetItemLinkSetInfo", item.link, true)
    if hasSet then
        Add(string.format("%s (%d/%d)", setName, equipped or 0, maxEquipped or 0))
        for index = 1, bonuses or 0 do
            local required, bonus = C.Try("GetItemLinkSetBonusInfo", item.link, true, index)
            if bonus then Add(string.format("(%d items) %s", required or 0, bonus)) end
        end
        Add(" ")
    end
    Add(C.Try("GetItemLinkFlavorText", item.link))
    Add(" "); Add(item.locked and "Locked" or "Unlocked")
    Add("Quantity: " .. item.stack)
    Add("Stack vendor value: " .. item.value * item.stack .. " gold")
    return table.concat(lines, "\n")
end
