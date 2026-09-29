-- SetHunter_Inventory.lua : remembers every set item you own, account-wide:
-- what each character wears and carries, the bank (and ESO Plus bank) and the
-- storage chests in your houses. Other characters are updated whenever you log in
-- on them; house chests whenever you're in your own house.
-- Also XP boost items (Experience Scrolls, Ambrosia, Ring of Mara, Training gear).
-- Only those are stored, as item links (trait, quality, level are in the link).

local S = SetHunter
local L = S.L

local HOUSE_BAGS = {}
for _, n in ipairs({ "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN" }) do
    local bag = _G["BAG_HOUSE_BANK_" .. n]
    if bag then HOUSE_BAGS[#HOUSE_BAGS + 1] = bag end
end

local function IsHouseBag(bagId)
    for _, bag in ipairs(HOUSE_BAGS) do
        if bag == bagId then return true end
    end
    return false
end

-- XP boost items (see D.XP_BOOSTS): name parts to look for, and the Training trait.
-- English names always, plus the names for the game's own language (German, French,
-- Spanish clients), so this works for every player.
local BOOST_NAMES = {}   -- { { part = "experience scroll", key = "scroll" }, ... }
local clientLanguage = GetCVar and GetCVar("language.2") or "en"
for _, boost in ipairs(S.DATA.XP_BOOSTS) do
    local parts = {}
    for _, part in ipairs(boost.items or {}) do parts[#parts + 1] = part end
    for _, part in ipairs((boost.itemsByLang or {})[clientLanguage] or {}) do parts[#parts + 1] = part end
    for _, part in ipairs(parts) do
        -- ringOnly: the Ring of Mara name part is short, so only rings count for it.
        BOOST_NAMES[#BOOST_NAMES + 1] = { part = zo_strlower(part), key = boost.key, ringOnly = boost.key == "mara" }
    end
end
local TRAINING = {}
if ITEM_TRAIT_TYPE_ARMOR_TRAINING then TRAINING[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = true end
if ITEM_TRAIT_TYPE_WEAPON_TRAINING then TRAINING[ITEM_TRAIT_TYPE_WEAPON_TRAINING] = true end

-- Which XP boost an item counts for (nil if none).
local function BoostKeyFor(link)
    local name = zo_strlower(zo_strformat("<<1>>", GetItemLinkName(link)))
    for _, entry in ipairs(BOOST_NAMES) do
        if name:find(entry.part, 1, true)
            and (not entry.ringOnly or GetItemLinkEquipType(link) == EQUIP_TYPE_RING) then
            return entry.key
        end
    end
    if TRAINING[GetItemLinkTraitInfo(link)] then return "training" end
    return nil
end

-- Two lists for a bag:
--   set items:   { { link, n = count, b = bound, s = setId }, ... }
--   boost items: { { link, n = count, b = bound, k = boost key }, ... }
local function ScanBag(bagId)
    local items, boosts = {}, {}
    local slot = ZO_GetNextBagSlotIndex(bagId)
    while slot do
        local link = GetItemLink(bagId, slot)
        if link ~= "" then
            local count, bound = GetSlotStackSize(bagId, slot), IsItemBound(bagId, slot) or nil
            local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
            if hasSet and setId and setId > 0 then
                items[#items + 1] = { link = link, n = count, b = bound, s = setId }
            end
            local key = BoostKeyFor(link)
            if key then
                boosts[#boosts + 1] = { link = link, n = count, b = bound, k = key }
            end
        end
        slot = ZO_GetNextBagSlotIndex(bagId, slot)
    end
    return items, boosts
end

local function InOwnHouse()
    return GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0
        and IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse()
end

local function HouseBankName(bagId)
    local id = GetCollectibleForHouseBankBag and GetCollectibleForHouseBankBag(bagId)
    if id and id ~= 0 then
        local nick = GetCollectibleNickname(id)
        if nick and nick ~= "" then return zo_strformat("<<1>>", nick) end
        return zo_strformat("<<1>>", GetCollectibleName(id))
    end
    return L("WHERE_HOUSE")
end

-- Name of the house you're standing in (your nickname for it if you gave one).
local function CurrentHouseName()
    local houseId = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0
    local id = houseId ~= 0 and GetCollectibleIdForHouse and GetCollectibleIdForHouse(houseId)
    if id and id ~= 0 then
        local nick = GetCollectibleNickname(id)
        if nick and nick ~= "" then return zo_strformat("<<1>>", nick) end
        return zo_strformat("<<1>>", GetCollectibleName(id))
    end
    return nil
end

-- Forget characters that no longer exist on the account (deleted), so their old
-- items don't stay in the list.
local function ForgetDeletedCharacters()
    local existing = {}
    for i = 1, GetNumCharacters() do
        local _, _, _, _, _, _, id = GetCharacterInfo(i)
        if id then existing[tostring(id)] = true end
    end
    if next(existing) == nil then return end   -- list not available: change nothing
    for id in pairs(S.sv.inv.chars) do
        if not existing[id] then S.sv.inv.chars[id] = nil end
    end
end

function S.ScanCharacter()
    ForgetDeletedCharacters()
    local worn, wornBoosts = ScanBag(BAG_WORN)
    local backpack, boosts = ScanBag(BAG_BACKPACK)
    S.sv.inv.chars[GetCurrentCharacterId()] = {
        name = zo_strformat("<<1>>", GetUnitName("player")),
        worn = worn,
        backpack = backpack,
        wornBoosts = wornBoosts,
        boosts = boosts,
        t = GetTimeStamp(),
    }
end

function S.ScanBank()
    if GetBagSize(BAG_BANK) == 0 then return end   -- not loaded: keep the last snapshot
    local items, boosts = ScanBag(BAG_BANK)
    -- The ESO Plus half of the bank (only reachable while subscribed) is marked.
    if BAG_SUBSCRIBER_BANK and GetBagSize(BAG_SUBSCRIBER_BANK) > 0 then
        local plusItems, plusBoosts = ScanBag(BAG_SUBSCRIBER_BANK)
        for _, item in ipairs(plusItems) do
            item.plus = true
            items[#items + 1] = item
        end
        for _, item in ipairs(plusBoosts) do
            item.plus = true
            boosts[#boosts + 1] = item
        end
    end
    S.sv.inv.bank = { items = items, boosts = boosts, t = GetTimeStamp() }
end

-- House chests can only be read inside your own house. Remembers the chest's name
-- and the house it was read in.
function S.ScanHouseBanks()
    if not InOwnHouse() then return end
    local house = CurrentHouseName()
    for _, bag in ipairs(HOUSE_BAGS) do
        if GetBagSize(bag) > 0 then
            local items, boosts = ScanBag(bag)
            S.sv.inv.houses[bag] = { name = HouseBankName(bag), house = house, items = items, boosts = boosts, t = GetTimeStamp() }
        end
    end
end

-- ---------------------------------------------------------------------------
-- Owned items by set, and XP boost items by boost
-- ---------------------------------------------------------------------------
local index        -- [setId] = { entry, ... }; rebuilt after every scan
local boostIndex   -- [boost key] = { entry, ... }

function S.MarkOwnedDirty()
    index, boostIndex = nil, nil
end

-- where:  short text for the list ("Bank", "Asaki Mozu (backpack)")
-- how:    how to get to it (tooltip)
-- t:      when that storage was last read
local function BuildIndex()
    index, boostIndex = {}, {}
    local function add(target, keyField, items, info)
        for _, item in ipairs(items or {}) do
            local key = item[keyField]
            local list = target[key]
            if not list then
                list = {}
                target[key] = list
            end
            local where, how = info.where, info.how
            if item.plus then where, how = L("WHERE_BANK_PLUS"), L("HOW_BANK_PLUS") end
            list[#list + 1] = {
                link = item.link, count = item.n or 1, bound = item.b == true,
                setId = item.s, boostKey = item.k, owner = info.owner, ownerId = info.ownerId,
                where = where, how = how, whereKind = info.kind, t = info.t,
                inMyBag = info.inMyBag,
            }
        end
    end
    local function addBoth(items, boosts, info)
        add(index, "s", items, info)
        add(boostIndex, "k", boosts, info)
    end
    local inv = S.sv.inv
    local me = GetCurrentCharacterId()
    for id, char in pairs(inv.chars) do
        local how = id == me and L("HOW_THIS_CHAR") or L("HOW_OTHER_CHAR", char.name)
        addBoth(char.worn, char.wornBoosts,
            { where = L("WHERE_WORN", char.name), how = how, kind = "worn", t = char.t, owner = char.name, ownerId = id })
        addBoth(char.backpack, char.boosts,
            { where = L("WHERE_BACKPACK", char.name), how = how, kind = "char", t = char.t, owner = char.name,
              ownerId = id, inMyBag = id == me })
    end
    if inv.bank then
        addBoth(inv.bank.items, inv.bank.boosts, { where = L("WHERE_BANK"), how = L("HOW_BANK"), kind = "bank", t = inv.bank.t })
    end
    for _, chest in pairs(inv.houses) do
        local where = chest.house and L("WHERE_CHEST", chest.name, chest.house) or chest.name
        local how = chest.house and L("HOW_CHEST", chest.house, chest.name) or L("HOW_CHEST_NO_HOUSE", chest.name)
        addBoth(chest.items, chest.boosts, { where = where, how = how, kind = "house", t = chest.t })
    end
end

-- XP boost items you own for one boost (Experience Scrolls, Ambrosia, ...).
function S.GetBoostItems(key)
    if not boostIndex then BuildIndex() end
    return boostIndex[key] or {}
end

function S.BoostCount(key)
    local n = 0
    for _, entry in ipairs(S.GetBoostItems(key)) do n = n + entry.count end
    return n
end

-- "just now", "12 min ago", "3 h ago", "2 days ago"
function S.FormatAgo(timestamp)
    if not timestamp then return "" end
    local seconds = GetDiffBetweenTimeStamps(GetTimeStamp(), timestamp)
    if seconds < 60 then return L("AGO_NOW") end
    if seconds < 3600 then return L("AGO_MIN", zo_floor(seconds / 60)) end
    if seconds < 86400 then return L("AGO_HOUR", zo_floor(seconds / 3600)) end
    return L("AGO_DAY", zo_floor(seconds / 86400))
end

function S.GetOwnedIndex()
    if not index then BuildIndex() end
    return index
end

function S.GetOwned(setId)
    return S.GetOwnedIndex()[setId] or {}
end

function S.OwnedCount(setId)
    local n = 0
    for _, entry in ipairs(S.GetOwned(setId)) do n = n + entry.count end
    return n
end

-- Every character on the account, and whether its bags have been read yet:
-- { { name, scanned = true/false, t = when }, ... } (this character first, then A-Z).
function S.GetCharacterScanList()
    local list, me = {}, GetCurrentCharacterId()
    local chars = S.sv.inv.chars
    for i = 1, GetNumCharacters() do
        local name, _, _, _, _, _, id = GetCharacterInfo(i)
        id = id and tostring(id)
        if name and id then
            local saved = chars[id]
            list[#list + 1] = {
                id = id,
                name = zo_strformat("<<1>>", name),
                scanned = saved ~= nil,
                t = saved and saved.t,
                me = id == me,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.me ~= b.me then return a.me end
        return a.name < b.name
    end)
    return list
end

function S.NumScannedCharacters()
    local n = 0
    for _ in pairs(S.sv.inv.chars) do n = n + 1 end
    return n
end

-- Readable details of one owned piece (worked out once, from the item link).
function S.PieceInfo(entry)
    if entry.info then return entry.info end
    local link = entry.link
    local quality = GetItemLinkDisplayQuality and GetItemLinkDisplayQuality(link) or GetItemLinkQuality(link)
    local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))
    local trait = GetItemLinkTraitInfo(link)
    local cp = GetItemLinkRequiredChampionPoints(link)
    local _, setName = GetItemLinkSetInfo(link, false)

    -- In the Set Collection yet? Only for sets that have a collection.
    local collected
    if entry.setId and GetItemLinkItemSetCollectionSlot and GetNumItemSetCollectionPieces(entry.setId) > 0 then
        collected = IsItemSetCollectionSlotUnlocked(entry.setId, GetItemLinkItemSetCollectionSlot(link))
    end

    entry.info = {
        name = name,
        coloredName = GetItemQualityColor(quality):Colorize(name),
        quality = GetString("SI_ITEMQUALITY", quality),
        trait = (trait and trait ~= ITEM_TRAIT_TYPE_NONE) and GetString("SI_ITEMTRAITTYPE", trait) or L("NO_TRAIT"),
        traitType = trait,
        slotKey = S.SlotKey(link),
        level = cp > 0 and ("CP " .. cp) or (L("LEVEL") .. " " .. GetItemLinkRequiredLevel(link)),
        icon = GetItemLinkIcon(link),
        setName = zo_strformat("<<1>>", setName or ""),
        qualityValue = quality,
        collected = collected,
        -- for the My items groupings (By slot, By armor weight, Below max level)
        cp = cp,
        equipType = GetItemLinkEquipType(link),
        weaponType = GetItemLinkWeaponType(link),
        armorType = GetItemLinkArmorType(link),
    }
    return entry.info
end

-- ---------------------------------------------------------------------------
-- Keeping it up to date
-- ---------------------------------------------------------------------------
local pending = {}

local function RunPendingScans()
    EVENT_MANAGER:UnregisterForUpdate("SetHunter_InvScan")
    if pending.char then S.ScanCharacter() end
    if pending.bank then S.ScanBank() end
    if pending.house then S.ScanHouseBanks() end
    pending = {}
    S.MarkOwnedDirty()
    if S.RefreshAll then S.RefreshAll() end
end

-- Many slot updates come at once (looting, depositing): scan once they settle.
local function Schedule(kind)
    pending[kind] = true
    EVENT_MANAGER:UnregisterForUpdate("SetHunter_InvScan")
    EVENT_MANAGER:RegisterForUpdate("SetHunter_InvScan", 800, RunPendingScans)
end

local function OnSlotUpdate(_, bagId)
    if bagId == BAG_WORN or bagId == BAG_BACKPACK then
        Schedule("char")
    elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
        Schedule("bank")
    elseif IsHouseBag(bagId) then
        Schedule("house")
    end
end

function S.InitInventory()
    local name = "SetHunter_Inv"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        pending.char, pending.bank, pending.house = true, true, true
        RunPendingScans()
    end)
    -- only the bags we read, and only real item changes (no durability ticks in combat):
    -- one registration per bag, because a bag filter takes one bag
    local bags = { BAG_WORN, BAG_BACKPACK, BAG_BANK }
    if BAG_SUBSCRIBER_BANK then bags[#bags + 1] = BAG_SUBSCRIBER_BANK end
    for _, bag in ipairs(HOUSE_BAGS) do bags[#bags + 1] = bag end
    for _, bag in ipairs(bags) do
        local namespace = name .. "_Bag" .. bag
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
        EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, bag,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    end
    EVENT_MANAGER:RegisterForEvent(name, EVENT_OPEN_BANK, function()
        Schedule("bank")
        Schedule("house")
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CLOSE_BANK, function()
        Schedule("bank")
        Schedule("house")
    end)
end
