InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- EQUIPPED group: what the character is wearing right now, under the MODULES heading of the bag.
-- Worn pieces live in the worn bag, not the backpack, so the game's list never holds them: they
-- are added here as extra rows sharing the worn bag's own slot data through a proxy, the same
-- way ARMORY shows the pieces you have on. The proxy's inventory says "equipment", so the game
-- binds each row as an equipment slot: its tooltip, and a right click that offers Unequip.
--
-- Only in the character's own bag window. At the bank, a mail, a trade or a merchant the list
-- is about what can be handed over, and nothing you are wearing can be.
--
-- Taking this module out of the addon: drop this file and its line in the manifest, the
-- EQUIPPED line in Colors.lua, the EQUIPPED entry in MODULE_GROUPS and the collector call in
-- InventoryGrouping.lua, and equippedEnabled in Settings.lua.

-- Worn pieces aren't part of any inventory; this stands in for the inventory the row setup expects.
local WORN_INVENTORY = { slotType = SLOT_TYPE_EQUIPMENT }

-- Set when the worn bag, the quickslot wheel or the food buff changes, cleared by the next build
-- of the bag; the wait below only rebuilds if nothing else has rebuilt the bag in the meantime.
local wornChanged = false

local function Enabled()
    return IG.sv ~= nil and IG.sv.equippedEnabled == true
end

-- Fixed headings, in this order, whatever Split Long Categories says. Costume is worn over the
-- armour and goes with it; a slot not named here (none today) falls to the end of ARMOR.
-- What you eat and what is on the quickslot wheel are two headings: the food is a buff you keep
-- up, the wheel is what you reach for in a fight (the same two an equipment setup keeps).
local SUB_ARMOR, SUB_JEWELRY, SUB_WEAPONS, SUB_FOOD, SUB_QUICK = 1, 2, 3, 4, 5
local SUB_LABELS = { "Armor", "Jewelry", "Weapons", "Buff Food", "Quick Slots" }
local SUB_ICONS = {
    [SUB_FOOD] = "FOODDRINK",
    [SUB_QUICK] = "CONSUMABLES",
}
local SLOT_PLACES = {}
for index, slot in ipairs({ EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HAND,
        EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_COSTUME }) do
    SLOT_PLACES[slot] = { sub = SUB_ARMOR, rank = index }
end
for index, slot in ipairs({ EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 }) do
    SLOT_PLACES[slot] = { sub = SUB_JEWELRY, rank = index }
end
-- Front bar, then back bar; each bar's poison right after its weapons.
for index, slot in ipairs({ EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_POISON,
        EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF, EQUIP_SLOT_BACKUP_POISON }) do
    SLOT_PLACES[slot] = { sub = SUB_WEAPONS, rank = index }
end
local OTHER_SLOT = { sub = SUB_ARMOR, rank = 99 }

-- Food and drink buffs, learned: the game has no call that says which item a buff came from, so
-- when a food or drink stack in the backpack goes down and a long buff lands on the player at
-- the same moment, that buff is written down as coming from that item (sv.foodBuffItems, buff
-- ability id -> item id). Eating the last one of a stack teaches nothing, but then there is
-- nothing left in the bag to show either.
local FOOD_TYPES = { [ITEMTYPE_FOOD] = true, [ITEMTYPE_DRINK] = true }
local PAIR_WINDOW = 2000      -- ms between the stack going down and the buff landing
local MIN_FOOD_DURATION = 600 -- s; every food and drink lasts far longer, most combat buffs far less
local pendingItemId, pendingItemTime, pendingBuffId, pendingBuffTime

-- Whether a buff is food or drink. LibFoodDrinkBuff, when installed, knows every one by id
-- (IsAbilityAFoodOrDrinkBuff, its API.lua:105); without it, a long buff is taken for one.
-- The library has no buff -> item table, so the pairing above is still what names the item.
local function IsFoodBuff(abilityId, effectType, beginTime, endTime)
    local lib = LIB_FOOD_DRINK_BUFF
    if lib and lib.IsAbilityAFoodOrDrinkBuff then return lib:IsAbilityAFoodOrDrinkBuff(abilityId) end
    return effectType == BUFF_EFFECT_TYPE_BUFF and (endTime or 0) - (beginTime or 0) >= MIN_FOOD_DURATION
end

local function FoodBuffItems()
    if not IG.sv then return nil end
    IG.sv.foodBuffItems = IG.sv.foodBuffItems or {}
    return IG.sv.foodBuffItems
end

-- Item ids wanted under BUFF FOOD and QUICK SLOTS, each with its place: the quickslot wheel in wheel order,
-- then whatever food or drink is on you now.
local function WantedConsumables()
    local wanted, any = {}, false
    if HOTBAR_CATEGORY_QUICKSLOT_WHEEL and ACTION_BAR_UTILITY_BAR_SIZE then
        for slot = 1, ACTION_BAR_UTILITY_BAR_SIZE do
            if GetSlotType(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) == ACTION_TYPE_ITEM then
                local itemLink = GetSlotItemLink(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                local itemId = itemLink and itemLink ~= "" and GetItemLinkItemId(itemLink) or 0
                if itemId ~= 0 and not wanted[itemId] then wanted[itemId], any = slot, true end
            end
        end
    end
    -- The poisons on your weapons: the stack in the bag that will refill them.
    for rank, slot in ipairs({ EQUIP_SLOT_POISON, EQUIP_SLOT_BACKUP_POISON }) do
        local itemId = GetItemId(BAG_WORN, slot)
        if itemId and itemId ~= 0 and not wanted[itemId] then wanted[itemId], any = 50 + rank, true end
    end
    -- Food on you: the learned pairing (FoodBuffItems), buff ability id -> the item it came from.
    local known = FoodBuffItems()
    if known and next(known) then
        for buffIndex = 1, GetNumBuffs("player") do
            local abilityId = select(11, GetUnitBuffInfo("player", buffIndex))
            local itemId = abilityId and known[abilityId]
            -- The same item on the wheel keeps its wheel place: one row, not two.
            if itemId and not wanted[itemId] then wanted[itemId], any = 100, true end
        end
    end
    return any and wanted or nil
end

-- The same answer for an equipment setup being saved (Setups.lua): [itemId] = place, where a
-- place under 100 is the wheel (1..8) or a weapon poison (51, 52) and 100 is food on you.
IG.EquippedConsumables = WantedConsumables

-- Returns { { data = proxy, path = path, slotRank = n }, ... }: every piece the character is
-- wearing, and the backpack stacks of what is on the quickslot wheel or being eaten now.
function IG.CollectEquippedEntries(inventory, inventoryType, searchText, items)
    local result = {}
    if inventoryType ~= INVENTORY_BACKPACK then return result end
    wornChanged = false
    if not Enabled() or not SCENE_MANAGER:IsShowing("inventory") then return result end
    local root = IG.MakeGroupNode("EQUIPPED")
    local paths = {}
    -- "Merge into one list" from its right click menu: no headings, slot order kept by slotRank.
    local merged = IG.SplitChoice and IG.SplitChoice("EQUIPPED") == "merge"
    local function PathFor(sub)
        if merged then
            paths.merged = paths.merged or { root }
            return paths.merged
        end
        if not paths[sub] then
            local node = IG.MakeSubNode(root, SUB_LABELS[sub])
            node.order = sub
            local iconGroup = SUB_ICONS[sub] and IG.GROUP_BY_KEY and IG.GROUP_BY_KEY[SUB_ICONS[sub]]
            if iconGroup then node.icon = iconGroup.icon or node.icon end
            paths[sub] = { root, node }
        end
        return paths[sub]
    end

    local wornCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_WORN)
    if wornCache then
        for _, slotData in pairs(wornCache) do
            if type(slotData) == "table" and slotData.bagId == BAG_WORN
                and (not IG.PassesListFilter or IG.PassesListFilter(inventory, slotData, searchText)) then
                local proxy = setmetatable({ igEquipped = true, inventory = WORN_INVENTORY },
                    { __index = slotData })
                local place = SLOT_PLACES[slotData.slotIndex] or OTHER_SLOT
                result[#result + 1] = { data = proxy, path = PathFor(place.sub),
                    slotRank = place.sub * 1000 + place.rank }
            end
        end
    end

    -- Backpack stacks: real bag items, so every menu and key works on them as anywhere else;
    -- they stay in their own category too, this is a second row. Taken from the list the game
    -- built, so its filter and search already apply.
    local wanted = items and WantedConsumables()
    if wanted then
        for _, entry in ipairs(items) do
            local data = entry.data
            if data and data.bagId == BAG_BACKPACK and data.slotIndex
                and not (IG.IsSetAside and IG.IsSetAside(data)) then
                local place = wanted[GetItemId(data.bagId, data.slotIndex)]
                if place then
                    local proxy = setmetatable({ igEquippedConsumable = true }, { __index = data })
                    -- 100 is the food on you (WantedConsumables); the wheel and the poisons
                    -- that refill your weapons are what you reach for, under QUICK SLOTS.
                    local sub = place >= 100 and SUB_FOOD or SUB_QUICK
                    result[#result + 1] = { data = proxy, path = PathFor(sub),
                        slotRank = sub * 1000 + place }
                end
            end
        end
    end
    return result
end

-- A piece in the worn bag: none of our own actions (sending it to SELL or DECONSTRUCT, junking
-- it, marking it with ctrl) mean anything for something you are wearing.
function IG.IsWornSlot(bagId)
    return bagId == BAG_WORN
end

---------------------------------------------------------------------------
-- Keeping it current
---------------------------------------------------------------------------

-- Changing gear sends a run of slot updates (an Armory loadout sends a dozen), so the rebuild
-- waits a moment. Most changes also move a piece in or out of the backpack, which the game
-- rebuilds by itself; the build clears the flag, and then nothing more is done here.
local SETTLE = "InventoryGroupingEquippedRows"
local SETTLE_DELAY = 150

local function Rebuild()
    EVENT_MANAGER:UnregisterForUpdate(SETTLE)
    if not wornChanged or not Enabled() then return end
    wornChanged = false
    -- UpdateList only marks the list dirty while it is hidden; shown, the game sorts and commits.
    PLAYER_INVENTORY.isListDirty[INVENTORY_BACKPACK] = true
    PLAYER_INVENTORY:UpdateList(INVENTORY_BACKPACK)
end

local function OnWornSlotUpdate()
    if not Enabled() then return end
    wornChanged = true
    EVENT_MANAGER:UnregisterForUpdate(SETTLE)
    EVENT_MANAGER:RegisterForUpdate(SETTLE, SETTLE_DELAY, Rebuild)
end

-- The quickslot wheel: only its own category, the skill bars send the same event.
local function OnHotbarSlotUpdated(_, _, hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then OnWornSlotUpdate() end
end

local function Pair()
    if not (pendingItemId and pendingBuffId) then return end
    if zo_abs(pendingItemTime - pendingBuffTime) <= PAIR_WINDOW then
        local known = FoodBuffItems()
        if known then known[pendingBuffId] = pendingItemId end
        pendingItemId, pendingBuffId = nil, nil
        OnWornSlotUpdate()
    end
end

-- A food or drink stack in the backpack going down: half of a pairing.
local function OnBackpackSlotUpdate(_, bagId, slotIndex, _, _, _, stackCountChange)
    if not Enabled() or not stackCountChange or stackCountChange >= 0 then return end
    if not FOOD_TYPES[GetItemType(bagId, slotIndex)] then return end
    pendingItemId, pendingItemTime = GetItemId(bagId, slotIndex), GetFrameTimeMilliseconds()
    Pair()
end

-- Every buff on the player comes through here, in combat many a second, so it stays a table
-- lookup: a buff already known as food rebuilds when it lands or ends; any other one is only
-- looked at if it is a long buff, the other half of a pairing.
local function OnEffectChanged(_, changeType, _, _, _, beginTime, endTime, _, _, _, effectType,
        _, _, _, _, abilityId)
    if not Enabled() then return end
    local known = IG.sv and IG.sv.foodBuffItems
    if known and known[abilityId] then
        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_FADED then
            OnWornSlotUpdate()
        end
        if changeType == EFFECT_RESULT_FADED then return end
    end
    if (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED)
        and IsFoodBuff(abilityId, effectType, beginTime, endTime) then
        pendingBuffId, pendingBuffTime = abilityId, GetFrameTimeMilliseconds()
        Pair()
    end
end

-- Food pairing name, same scheme as SETTLE's own child names below.
local foodSlots, buffs, wheel = SETTLE .. "Food", SETTLE .. "Buffs", SETTLE .. "Wheel"

-- All four of these only feed EQUIPPED's own rows (CollectEquippedEntries reads the worn bag and
-- the saved food-buff pairing fresh each time it is asked, not any state these keep), so there is
-- nothing left depending on them with the module off. Registered only while equippedEnabled is on
-- (IG.MODULE_APPLY, called from IG.SetModuleEnabled and once at load) rather than left listening
-- to every worn-slot change, buff and hotbar update for the rest of the session regardless -- the
-- heaviest of the three, EVENT_EFFECT_CHANGED, fires many times a second in combat.
local registered = false

local function ApplyEnabled(on)
    if on == registered then return end
    registered = on
    if on then
        EVENT_MANAGER:RegisterForEvent(SETTLE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnWornSlotUpdate)
        EVENT_MANAGER:AddFilterForEvent(SETTLE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_WORN)
        EVENT_MANAGER:RegisterForEvent(foodSlots, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBackpackSlotUpdate)
        EVENT_MANAGER:AddFilterForEvent(foodSlots, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
        EVENT_MANAGER:RegisterForEvent(buffs, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(buffs, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:RegisterForEvent(wheel, EVENT_HOTBAR_SLOT_UPDATED, OnHotbarSlotUpdated)
        EVENT_MANAGER:RegisterForEvent(wheel, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnWornSlotUpdate)
    else
        -- Also drops whatever Rebuild() was waiting on (OnWornSlotUpdate's own RegisterForUpdate),
        -- so a switch pulled mid-settle does not leave a timer firing into a module that no
        -- longer wants it -- one guard here, a second inside Rebuild/Enabled() itself.
        EVENT_MANAGER:UnregisterForEvent(SETTLE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        EVENT_MANAGER:UnregisterForEvent(foodSlots, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        EVENT_MANAGER:UnregisterForEvent(buffs, EVENT_EFFECT_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(wheel, EVENT_HOTBAR_SLOT_UPDATED)
        EVENT_MANAGER:UnregisterForEvent(wheel, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED)
        EVENT_MANAGER:UnregisterForUpdate(SETTLE)
        wornChanged = false
        pendingItemId, pendingBuffId = nil, nil
    end
end

IG.MODULE_APPLY = IG.MODULE_APPLY or {}
IG.MODULE_APPLY.equippedEnabled = ApplyEnabled

function IG.InitEquipped()
    if not IG.IsEnabled() then return end
    -- The bag window and the bank share one backpack list, and the game only rebuilds it on
    -- opening when it is dirty. Left dirty on closing, it is rebuilt for whichever window opens
    -- next, so EQUIPPED is there in the bag and gone at the bank. Cheap (one scene state change
    -- at a time) and already checks Enabled() itself, so this one stays registered regardless.
    if INVENTORY_FRAGMENT then
        INVENTORY_FRAGMENT:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_FRAGMENT_HIDDEN and Enabled() then
                PLAYER_INVENTORY.isListDirty[INVENTORY_BACKPACK] = true
            end
        end)
    end
end
