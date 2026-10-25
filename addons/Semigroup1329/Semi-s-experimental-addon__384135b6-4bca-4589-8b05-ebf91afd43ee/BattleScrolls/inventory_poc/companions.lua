if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocCompanions
---@field kept table<string, boolean>
---@field complete boolean
---@field bank InventoryPocItem[]
local companions = { kept = {}, complete = false, bank = {} }
BattleScrolls.inventoryPocCompanions = companions
local poc = BattleScrolls.inventoryPoc
local facts = BattleScrolls.inventoryPocFacts
-- Confirmed by the player's Xbox client, 18 October 2026.
local SHARP, EMBER, ZERITH = 8, 5, 13
local TARGETS = { SHARP, EMBER, ZERITH }
local TARGET_IDS = { [SHARP] = true, [EMBER] = true, [ZERITH] = true }
local ARMOR_TYPES = { EQUIP_TYPE_HEAD, EQUIP_TYPE_CHEST, EQUIP_TYPE_SHOULDERS,
    EQUIP_TYPE_HAND, EQUIP_TYPE_WAIST, EQUIP_TYPE_LEGS, EQUIP_TYPE_FEET }
local JEWELRY_SLOTS = { EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 }
local TRAIT_PRIORITY = {
    [ITEM_TRAIT_TYPE_ARMOR_QUICKENED] = 2, [ITEM_TRAIT_TYPE_ARMOR_AUGMENTED] = 1,
    [ITEM_TRAIT_TYPE_WEAPON_QUICKENED] = 2, [ITEM_TRAIT_TYPE_WEAPON_AUGMENTED] = 1,
    [ITEM_TRAIT_TYPE_JEWELRY_QUICKENED] = 2, [ITEM_TRAIT_TYPE_JEWELRY_AUGMENTED] = 1,
}

---@param item InventoryPocItem
---@return string|nil
local function piece(item)
    if item.weaponType == WEAPONTYPE_AXE or item.weaponType == WEAPONTYPE_SWORD
        or item.weaponType == WEAPONTYPE_HAMMER or item.weaponType == WEAPONTYPE_DAGGER then return 'oneHand' end
    if item.weaponType == WEAPONTYPE_TWO_HANDED_AXE or item.weaponType == WEAPONTYPE_TWO_HANDED_SWORD
        or item.weaponType == WEAPONTYPE_TWO_HANDED_HAMMER then return 'twoHand' end
    if item.weaponType == WEAPONTYPE_HEALING_STAFF then return 'resto' end
    if item.weaponType == WEAPONTYPE_SHIELD then return 'shield' end
    if item.armorType == ARMORTYPE_HEAVY then return 'armor:' .. tostring(item.equipType) end
    if item.equipType == EQUIP_TYPE_RING or item.equipType == EQUIP_TYPE_NECK then return 'jewelry:' .. tostring(item.equipType) end
end

---@param item InventoryPocItem
---@return string|nil
local function key(item)
    return TRAIT_PRIORITY[item.trait] and piece(item) or nil
end

---Quality wins, then Quickened over Augmented, then equipped copies and stable ID.
---Each equipped or loose instance participates only once, even after a swap.
---@param kits table<number, InventoryPocItem[]>
---@param loose InventoryPocItem[]
---@return table<string, boolean>, boolean
function companions.allocate(kits, loose)
    local demand, candidates = {}, {}
    local function need(category, quantity)
        demand[category] = (demand[category] or 0) + quantity
    end
    for _, id in ipairs(TARGETS) do
        local kit = kits[id]
        if not kit then return {}, false end
        for _, item in ipairs(kit) do
            candidates[item.uniqueId] = item
        end
        for _, equipType in ipairs(ARMOR_TYPES) do
            need('armor:' .. tostring(equipType), 1)
        end
        for _, slot in ipairs(JEWELRY_SLOTS) do
            local equipType = slot == EQUIP_SLOT_NECK and EQUIP_TYPE_NECK or EQUIP_TYPE_RING
            need('jewelry:' .. tostring(equipType), 1)
        end
        if id == SHARP then
            need('twoHand', 1); need('oneHand', 2)
        elseif id == EMBER then
            need('resto', 1)
        else
            need('oneHand', 1); need('shield', 1)
        end
    end
    -- Live bags take precedence over a former equipped location in a snapshot.
    for _, item in ipairs(loose) do if item.kind == 'companion' then candidates[item.uniqueId] = item end end
    local groups = {}
    for _, item in pairs(candidates) do
        local k = key(item)
        if k and demand[k] then
            groups[k] = groups[k] or {}; table.insert(groups[k], item)
        end
    end
    local kept = {}
    for k, items in pairs(groups) do
        table.sort(items, function(a, b)
            if a.quality ~= b.quality then return a.quality > b.quality end
            if TRAIT_PRIORITY[a.trait] ~= TRAIT_PRIORITY[b.trait] then return TRAIT_PRIORITY[a.trait] > TRAIT_PRIORITY[b.trait] end
            if (a.bag == BAG_COMPANION_WORN) ~= (b.bag == BAG_COMPANION_WORN) then return a.bag == BAG_COMPANION_WORN end
            return a.uniqueId < b.uniqueId
        end)
        for index = 1, math.min(demand[k], #items) do kept[items[index].uniqueId] = true end
    end
    return kept, true
end

function companions.capture()
    if not poc.enabled or not poc.saved then return end
    local id = GetActiveCompanionDefId()
    if TARGET_IDS[id] then poc.saved.companions[id] = facts.bag(BAG_COMPANION_WORN) end
end

function companions.reset()
    companions.kept, companions.complete, companions.bank = {}, false, {}
end

---@param item InventoryPocItem
---@return boolean|nil
function companions.isNeeded(item)
    if not key(item) then return false end
    if not companions.complete then return nil end
    return companions.kept[item.uniqueId] == true
end

---@param backpack InventoryPocItem[]
function companions.refresh(backpack)
    if not poc.saved then return end
    companions.capture()
    if IsBankOpen() and (GetBankingBag() == BAG_BANK or GetBankingBag() == BAG_SUBSCRIBER_BANK) then
        companions.bank = {}
        local bags = IsESOPlusSubscriber() and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { BAG_BANK }
        for _, bag in ipairs(bags) do for _, item in ipairs(facts.bag(bag)) do
            if item.kind == 'companion' then companions.bank[#companions.bank + 1] = item end
        end end
    end
    local loose = {}
    for _, item in ipairs(companions.bank) do loose[#loose + 1] = item end
    for _, item in ipairs(backpack) do loose[#loose + 1] = item end
    companions.kept, companions.complete = companions.allocate(poc.saved.companions, loose)
    for _, item in ipairs(backpack) do
        if item.kind == 'companion' then
            item.companionNeeded = companions.isNeeded(item)
        end
    end
end
