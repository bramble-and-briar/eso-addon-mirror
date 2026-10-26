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
local ARMOR_SLOTS = { EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_HAND, EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET }
local JEWELRY_SLOTS = { EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 }
local EQUIPMENT_SLOTS = { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND }
for _, slot in ipairs(ARMOR_SLOTS) do EQUIPMENT_SLOTS[#EQUIPMENT_SLOTS + 1] = slot end
for _, slot in ipairs(JEWELRY_SLOTS) do EQUIPMENT_SLOTS[#EQUIPMENT_SLOTS + 1] = slot end
---@class InventoryPocCompanionUpgrade
---@field moves InventoryPocCompanionEquip[]
---@field worn table<number, string> Equipped instance IDs when the upgrade was planned
---@type table<number, InventoryPocCompanionUpgrade>
local upgrades = {}
local reportPending = false
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
    local category = piece(item)
    return TRAIT_PRIORITY[item.trait] and category ~= 'twoHand' and category or nil
end

---@param a InventoryPocItem
---@param b InventoryPocItem
---@return boolean
local function stronger(a, b)
    if a.quality ~= b.quality then return a.quality > b.quality end
    return (TRAIT_PRIORITY[a.trait] or 0) > (TRAIT_PRIORITY[b.trait] or 0)
end

---@class InventoryPocCompanionEquip
---@field item InventoryPocItem
---@field slot number

---Choose a small group of upgrades. Weapon changes require a usable full setup.
---@param id number
---@param backpack InventoryPocItem[] Eligible, currently equipable backpack items
---@param worn InventoryPocItem[]
---@param locked table<number, boolean> Locked equipment slots
---@return InventoryPocCompanionEquip[]
function companions.nextEquipment(id, backpack, worn, locked)
    if not TARGET_IDS[id] then return {} end
    local equipped = {} ---@type table<number, InventoryPocItem>
    for _, item in ipairs(worn) do equipped[item.slot] = item end
    local candidates = {} ---@type table<string, InventoryPocItem[]>
    for _, item in ipairs(backpack) do
        local category = key(item)
        if item.kind == 'companion' and item.bag == BAG_BACKPACK and category
            and not item.reserved and not item.stolen and not item.crown then
            candidates[category] = candidates[category] or {}
            table.insert(candidates[category], item)
        end
    end
    for _, items in pairs(candidates) do
        table.sort(items, function(a, b)
            if stronger(a, b) then return true end
            if stronger(b, a) then return false end
            return a.uniqueId < b.uniqueId
        end)
    end
    ---@param category string
    ---@param slots number[]
    ---@return InventoryPocCompanionEquip[]
    local function choose(category, slots)
        -- Fill missing weapon halves first, then improve the weakest copy.
        local function rank(slot)
            local item = equipped[slot]
            if not item or piece(item) ~= category then return -2 end
            if key(item) ~= category then return -1 end
            return item.quality * 10 + TRAIT_PRIORITY[item.trait]
        end
        table.sort(slots, function(a, b)
            if rank(a) ~= rank(b) then return rank(a) < rank(b) end
            return a < b
        end)
        local moves, index = {}, 1
        for _, slot in ipairs(slots) do
            local candidate, current = (candidates[category] or {})[index], equipped[slot]
            if candidate and not locked[slot] and (not current or key(current) ~= category or stronger(candidate, current)) then
                moves[#moves + 1] = { item = candidate, slot = slot }
                index = index + 1
            end
        end
        return moves
    end
    for index, equipType in ipairs(ARMOR_TYPES) do
        local moves = choose('armor:' .. tostring(equipType), { ARMOR_SLOTS[index] })
        if #moves > 0 then return moves end
    end
    local moves = choose('jewelry:' .. tostring(EQUIP_TYPE_NECK), { EQUIP_SLOT_NECK })
    if #moves > 0 then return moves end
    moves = choose('jewelry:' .. tostring(EQUIP_TYPE_RING), { EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 })
    if #moves > 0 then return moves end
    if id == EMBER then return choose('resto', { EQUIP_SLOT_MAIN_HAND }) end
    if id == SHARP then
        moves = choose('oneHand', { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND })
    else
        moves = choose('oneHand', { EQUIP_SLOT_MAIN_HAND })
        local shield = choose('shield', { EQUIP_SLOT_OFF_HAND })
        if shield[1] then moves[#moves + 1] = shield[1] end
    end
    local final = { [EQUIP_SLOT_MAIN_HAND] = equipped[EQUIP_SLOT_MAIN_HAND],
        [EQUIP_SLOT_OFF_HAND] = equipped[EQUIP_SLOT_OFF_HAND] }
    for _, move in ipairs(moves) do final[move.slot] = move.item end
    if not final[EQUIP_SLOT_MAIN_HAND] or piece(final[EQUIP_SLOT_MAIN_HAND]) ~= 'oneHand'
        or not final[EQUIP_SLOT_OFF_HAND] or piece(final[EQUIP_SLOT_OFF_HAND]) ~= (id == SHARP and 'oneHand' or 'shield') then
        return {}
    end
    -- Establish the main hand before filling the off hand during a conversion.
    table.sort(moves, function(a, b) return a.slot == EQUIP_SLOT_MAIN_HAND and b.slot ~= EQUIP_SLOT_MAIN_HAND end)
    return moves
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
            need('oneHand', 2)
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
            if stronger(a, b) then return true end
            if stronger(b, a) then return false end
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
    if TARGET_IDS[id] then
        local worn = facts.bag(BAG_COMPANION_WORN)
        if GetActiveCompanionDefId() == id then poc.saved.companions[id] = worn end
    end
end

function companions.reset()
    companions.kept, companions.complete, companions.bank = {}, false, {}
    upgrades, reportPending = {}, false
end

---The next inventory pass reports carried upgrades once for this activation.
function companions.requestReport()
    if poc.enabled then reportPending = true end
end

---@param id number
---@return boolean
local function upgradeAvailable(id)
    local upgrade = upgrades[id]
    if not upgrade then return false end
    local active = id == GetActiveCompanionDefId()
    for _, move in ipairs(upgrade.moves) do
        local item = move.item
        if Id64ToString(GetItemUniqueId(item.bag, item.slot)) ~= item.uniqueId
            or GetItemLink(item.bag, item.slot, LINK_STYLE_DEFAULT) ~= item.link
            or IsItemPlayerLocked(item.bag, item.slot) or IsItemInArmory(item.bag, item.slot)
            or (active and not IsEquipable(item.bag, item.slot)) then return false end
        if active and IsItemPlayerLocked(BAG_COMPANION_WORN, move.slot) then return false end
        if active and move.slot == EQUIP_SLOT_MAIN_HAND and item.equipType == EQUIP_TYPE_TWO_HAND
            and GetItemLink(BAG_COMPANION_WORN, EQUIP_SLOT_OFF_HAND, LINK_STYLE_DEFAULT) ~= ''
            and (IsItemPlayerLocked(BAG_COMPANION_WORN, EQUIP_SLOT_OFF_HAND) or GetNumBagFreeSlots(BAG_BACKPACK) == 0) then
            return false
        end
    end
    if active then
        for _, slot in ipairs(EQUIPMENT_SLOTS) do
            if Id64ToString(GetItemUniqueId(BAG_COMPANION_WORN, slot)) ~= (upgrade.worn[slot] or '0') then return false end
        end
    end
    return true
end

---Only the active companion can receive equipment during this interaction.
---@return boolean
function companions.hasUpgrade()
    return poc.enabled and upgradeAvailable(GetActiveCompanionDefId())
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
    upgrades = {}
    for _, id in ipairs(TARGETS) do
        local kit = poc.saved.companions[id]
        if kit then
            local locked, worn = {}, {}
            for _, item in ipairs(kit) do
                locked[item.slot], worn[item.slot] = item.locked == true, item.uniqueId
            end
            local available = backpack
            if id == GetActiveCompanionDefId() then
                available = {}
                for _, item in ipairs(backpack) do
                    if item.kind == 'companion' and IsEquipable(item.bag, item.slot) then available[#available + 1] = item end
                end
            end
            local moves = companions.nextEquipment(id, available, kit, locked)
            if #moves > 0 then upgrades[id] = { moves = moves, worn = worn } end
        end
    end
    if reportPending and poc.enabled then
        reportPending = false
        for _, id in ipairs(TARGETS) do
            if upgradeAvailable(id) then
                d(zo_strformat(GetString(BATTLESCROLLS_IPOC_COMPANION_UPGRADE), GetCompanionName(id)))
            end
        end
    end
end
