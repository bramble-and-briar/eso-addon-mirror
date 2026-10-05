-- Skillbound_Items.lua : where an item is.
-- A build remembers each piece by its unique id (that exact item). If that item is
-- gone (deconstructed, sold, improved into a new one...), Find looks for a copy:
-- the same set (or the same item when it isn't a set piece), the same kind of piece
-- (weapon type / armor weight / slot), best with the same trait and quality.
-- Also remembers which equipment each character carries and what's in the bank, so a
-- missing piece can say "on <character>" / "in the bank".

local B = Skillbound
local L = B.L
local Items = {}
B.Items = Items

-- paperdoll order (the costume slot is left out on purpose: disguises, tabards)
Items.SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HAND, EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
    EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_POISON,
    EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF, EQUIP_SLOT_BACKUP_POISON,
}
Items.POISON = { [EQUIP_SLOT_POISON] = true, [EQUIP_SLOT_BACKUP_POISON] = true }
Items.WEAPON = {
    [EQUIP_SLOT_MAIN_HAND] = true, [EQUIP_SLOT_OFF_HAND] = true,
    [EQUIP_SLOT_BACKUP_MAIN] = true, [EQUIP_SLOT_BACKUP_OFF] = true,
}
Items.BACK = { [EQUIP_SLOT_BACKUP_MAIN] = true, [EQUIP_SLOT_BACKUP_OFF] = true, [EQUIP_SLOT_BACKUP_POISON] = true }

-- the game's empty-slot pictures (same paths Wizard's Wardrobe uses)
local ART = "/esoui/art/characterwindow/gearslot_"
Items.SLOT_ICON = {
    [EQUIP_SLOT_HEAD] = ART .. "head.dds", [EQUIP_SLOT_SHOULDERS] = ART .. "shoulders.dds",
    [EQUIP_SLOT_CHEST] = ART .. "chest.dds", [EQUIP_SLOT_HAND] = ART .. "hands.dds",
    [EQUIP_SLOT_WAIST] = ART .. "belt.dds", [EQUIP_SLOT_LEGS] = ART .. "legs.dds",
    [EQUIP_SLOT_FEET] = ART .. "feet.dds", [EQUIP_SLOT_NECK] = ART .. "neck.dds",
    [EQUIP_SLOT_RING1] = ART .. "ring.dds", [EQUIP_SLOT_RING2] = ART .. "ring.dds",
    [EQUIP_SLOT_MAIN_HAND] = ART .. "mainhand.dds", [EQUIP_SLOT_OFF_HAND] = ART .. "offhand.dds",
    [EQUIP_SLOT_POISON] = ART .. "poison.dds",
    [EQUIP_SLOT_BACKUP_MAIN] = ART .. "mainhand.dds", [EQUIP_SLOT_BACKUP_OFF] = ART .. "offhand.dds",
    [EQUIP_SLOT_BACKUP_POISON] = ART .. "poison.dds",
}

function Items.SlotName(equipSlot)
    local name = GetString("SI_EQUIPSLOT", equipSlot)
    if Items.BACK[equipSlot] then name = L("BACK_BAR_SLOT", name) end
    return name
end

function Items.Uid(bag, slot)
    local id = GetItemUniqueId(bag, slot)
    if not id then return nil end
    local s = Id64ToString(id)
    if s == "0" or s == "" then return nil end
    return s
end

-- what a build stores for one piece (also used to compare pieces)
function Items.Info(link)
    local hasSet, _, _, _, maxEquipped, setId = GetItemLinkSetInfo(link, false)
    return {
        link = link,
        id = GetItemLinkItemId(link),
        set = hasSet and setId or nil,
        max = hasSet and maxEquipped or nil,
        trait = GetItemLinkTraitInfo(link),
        et = GetItemLinkEquipType(link),
        wt = GetItemLinkWeaponType(link),
        at = GetItemLinkArmorType(link),
        q = GetItemLinkDisplayQuality(link),
    }
end

-- which equip types can go into each slot (for picking another piece in the window)
local FITS = {
    [EQUIP_SLOT_HEAD] = { EQUIP_TYPE_HEAD }, [EQUIP_SLOT_SHOULDERS] = { EQUIP_TYPE_SHOULDERS },
    [EQUIP_SLOT_CHEST] = { EQUIP_TYPE_CHEST }, [EQUIP_SLOT_HAND] = { EQUIP_TYPE_HAND },
    [EQUIP_SLOT_WAIST] = { EQUIP_TYPE_WAIST }, [EQUIP_SLOT_LEGS] = { EQUIP_TYPE_LEGS },
    [EQUIP_SLOT_FEET] = { EQUIP_TYPE_FEET }, [EQUIP_SLOT_NECK] = { EQUIP_TYPE_NECK },
    [EQUIP_SLOT_RING1] = { EQUIP_TYPE_RING }, [EQUIP_SLOT_RING2] = { EQUIP_TYPE_RING },
    [EQUIP_SLOT_MAIN_HAND] = { EQUIP_TYPE_MAIN_HAND, EQUIP_TYPE_ONE_HAND, EQUIP_TYPE_TWO_HAND },
    [EQUIP_SLOT_BACKUP_MAIN] = { EQUIP_TYPE_MAIN_HAND, EQUIP_TYPE_ONE_HAND, EQUIP_TYPE_TWO_HAND },
    [EQUIP_SLOT_OFF_HAND] = { EQUIP_TYPE_OFF_HAND, EQUIP_TYPE_ONE_HAND },
    [EQUIP_SLOT_BACKUP_OFF] = { EQUIP_TYPE_OFF_HAND, EQUIP_TYPE_ONE_HAND },
    [EQUIP_SLOT_POISON] = { EQUIP_TYPE_POISON }, [EQUIP_SLOT_BACKUP_POISON] = { EQUIP_TYPE_POISON },
}

function Items.FitsSlot(link, slot)
    local et = GetItemLinkEquipType(link)
    for _, t in ipairs(FITS[slot] or {}) do
        if t == et then return true end
    end
    return false
end

-- every piece you could put into a slot: worn first, then bag, then bank (poisons once per kind)
function Items.Candidates(slot, max)
    local list, seenPoison = {}, {}
    for _, e in ipairs(Items.Index().list) do
        if Items.FitsSlot(e.link, slot) then
            local id = GetItemLinkItemId(e.link)
            if not (Items.POISON[slot] and seenPoison[id]) then
                seenPoison[id] = true
                list[#list + 1] = e
            end
        end
    end
    local order = { [BAG_WORN] = 0, [BAG_BACKPACK] = 1 }
    table.sort(list, function(a, b)
        local oa, ob = order[a.bag] or 2, order[b.bag] or 2
        if oa ~= ob then return oa < ob end
        return GetItemLinkName(a.link) < GetItemLinkName(b.link)
    end)
    while max and #list > max do table.remove(list) end
    return list
end

function Items.IsMythic(info)
    return info and info.q == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
end

local function IsEquipment(link)
    local et = GetItemLinkEquipType(link)
    return et ~= EQUIP_TYPE_INVALID and et ~= EQUIP_TYPE_COSTUME
end

-- ---------------------------------------------------------------------------
-- Index of every piece of equipment you can reach (worn, bag, bank, ESO Plus bank).
-- Rebuilt only after the inventory changed.

local BAGS = { BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
local cache, dirty = nil, true

function Items.MarkDirty()
    dirty = true
end

function Items.Index()
    if cache and not dirty then return cache end
    local byUid, list = {}, {}
    for _, bag in ipairs(BAGS) do
        for slot in ZO_IterateBagSlots(bag) do
            local link = GetItemLink(bag, slot)
            if link ~= "" and IsEquipment(link) then
                local e = { bag = bag, slot = slot, uid = Items.Uid(bag, slot), link = link }
                if e.uid then byUid[e.uid] = e end
                list[#list + 1] = e
            end
        end
    end
    cache, dirty = { byUid = byUid, list = list }, false
    return cache
end

function Items.EntryInfo(e)
    if not e.info then e.info = Items.Info(e.link) end
    return e.info
end

function Items.Kind(bag)
    if bag == BAG_WORN then return "worn" end
    if bag == BAG_BACKPACK then return "bag" end
    return "bank"
end

-- "the same piece" for copies (shared builds, other characters): a set piece of the same set and
-- kind (armor weight / weapon type / slot), else the same item. Trait, level, quality and
-- enchantment don't matter (user: "as long as the name is the same").
function Items.Sig(info)
    if info.set then
        local et = (info.wt and info.wt ~= WEAPONTYPE_NONE) and "" or tostring(info.et)
        return "s" .. info.set .. ":" .. tostring(info.wt) .. ":" .. tostring(info.at) .. ":" .. et
    end
    return "i" .. tostring(info.id)
end

local function SameKind(want, have)
    if want.wt ~= have.wt or want.at ~= have.at then return false end
    if want.wt ~= WEAPONTYPE_NONE then return true end   -- same weapon type is enough (one-hand / main hand)
    return want.et == have.et
end

-- entry = a build's piece. used = { [uid] = true } pieces already given to other slots.
-- Returns nil, or { e = index entry, exact, otherTrait, kind = "worn"|"bag"|"bank" },
-- or { other = character name } (only that exact item, on another character).
function Items.Find(entry, used)
    used = used or {}
    local idx = Items.Index()
    local e = entry.uid and idx.byUid[entry.uid]
    if e and not used[e.uid] then
        return { e = e, exact = true, kind = Items.Kind(e.bag) }
    end
    local best, bestScore
    for _, c in ipairs(idx.list) do
        if not (c.uid and used[c.uid]) then
            local i = Items.EntryInfo(c)
            local sameItem = (entry.set and i.set == entry.set) or (not entry.set and i.id == entry.id)
            if sameItem and SameKind(entry, i) then
                local score = 0
                if i.trait == entry.trait then score = score + 4 end
                if (i.q or 0) >= (entry.q or 0) then score = score + 2 end
                if c.bag ~= BAG_BANK and c.bag ~= BAG_SUBSCRIBER_BANK then score = score + 1 end
                if not best or score > bestScore then best, bestScore = c, score end
            end
        end
    end
    if best then
        return { e = best, exact = false, otherTrait = Items.EntryInfo(best).trait ~= entry.trait, kind = Items.Kind(best.bag) }
    end
    local me = B.CharId()
    -- the exact piece on another character
    if entry.uid then
        for charId, c in pairs(B.sv.chars) do
            if charId ~= me and c.items and c.items[entry.uid] then
                return { other = c.name or "?" }
            end
        end
    end
    -- else a copy (same set and kind / same item) on another character (shared builds too)
    local sig = Items.Sig(entry)
    for charId, c in pairs(B.sv.chars) do
        if charId ~= me and c.kinds and c.kinds[sig] then
            return { other = c.name or "?", copy = true }
        end
    end
    return nil
end

-- the other character who carries this exact piece (by its unique id), or nil
function Items.Holder(uid)
    if not uid then return nil end
    local me = B.CharId()
    for charId, c in pairs(B.sv.chars) do
        if charId ~= me and c.items and c.items[uid] then return c.name or "?" end
    end
    return nil
end

-- "in your bag", "in the bank", "on Anna", "missing"
function Items.WhereText(found)
    if not found then return L("WHERE_MISSING") end
    if found.other then return L(found.copy and "WHERE_OTHER_COPY" or "WHERE_OTHER", found.other) end
    if found.kind == "bank" then return L("WHERE_BANK") end
    if found.kind == "worn" then return L("WHERE_WORN") end
    return L("WHERE_BAG")
end

-- Poisons are matched by item: every stack of the same poison counts.
-- Returns the bag/slot of the biggest stack in the backpack (same link first) and the total.
function Items.FindPoison(entry)
    local bestBag, bestSlot, bestN, total = nil, nil, 0, 0
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        local link = GetItemLink(BAG_BACKPACK, slot)
        if link ~= "" and GetItemLinkItemId(link) == entry.id then
            local n = GetSlotStackSize(BAG_BACKPACK, slot)
            total = total + n
            local bonus = link == entry.link and 100000 or 0
            if n + bonus > bestN then bestBag, bestSlot, bestN = BAG_BACKPACK, slot, n + bonus end
        end
    end
    for _, s in ipairs({ EQUIP_SLOT_POISON, EQUIP_SLOT_BACKUP_POISON }) do
        local link = GetItemLink(BAG_WORN, s)
        if link ~= "" and GetItemLinkItemId(link) == entry.id then
            total = total + GetSlotStackSize(BAG_WORN, s)
        end
    end
    return bestBag, bestSlot, total
end

-- every build piece that could be this item (for marks and Set Hunter):
-- [uid] = { build names }
local usedCache, usedDirty = nil, true
function Items.MarkBuildsDirty() usedDirty = true end

function Items.UsedByBuilds()
    if usedCache and not usedDirty then return usedCache end
    local byUid, byKey = {}, {}
    for _, b in pairs(B.sv.builds) do
        for _, pieces in ipairs({ b.gear or {}, b.companion and b.companion.gear or {} }) do
            for slot, p in pairs(pieces) do
                if not Items.POISON[slot] then
                    if p.uid then
                        byUid[p.uid] = byUid[p.uid] or {}
                        table.insert(byUid[p.uid], b.name)
                    end
                    if p.id then
                        local key = p.id .. ":" .. tostring(p.trait)
                        byKey[key] = true
                    end
                end
            end
        end
    end
    usedCache, usedDirty = { byUid = byUid, byKey = byKey }, false
    return usedCache
end

-- Remember what this character carries (and what's in the bank) for "on <character>".
local function Remember()
    local c = B.Char()
    local items, kinds = {}, {}
    for _, bag in ipairs({ BAG_WORN, BAG_BACKPACK }) do
        for slot in ZO_IterateBagSlots(bag) do
            local link = GetItemLink(bag, slot)
            if link ~= "" and IsEquipment(link) then
                local uid = Items.Uid(bag, slot)
                if uid then items[uid] = true end
                -- (copies count too: a shared build's piece is found on this character later)
                kinds[Items.Sig(Items.Info(link))] = true
            end
        end
    end
    c.items = items
    c.kinds = kinds
    if GetBagSize(BAG_BANK) > 0 then
        local bank = {}
        for _, bag in ipairs({ BAG_BANK, BAG_SUBSCRIBER_BANK }) do
            for slot in ZO_IterateBagSlots(bag) do
                local link = GetItemLink(bag, slot)
                if link ~= "" and IsEquipment(link) then
                    local uid = Items.Uid(bag, slot)
                    if uid then bank[uid] = true end
                end
            end
        end
        B.sv.bank = bank
    end
end

local function RememberSoon()
    B.EM:UnregisterForUpdate("Skillbound_Remember")
    B.EM:RegisterForUpdate("Skillbound_Remember", 4000, function()
        B.EM:UnregisterForUpdate("Skillbound_Remember")
        Remember()
    end)
end

function Items.Init()
    B.EM:RegisterForEvent("Skillbound_Items", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
        dirty = true
        RememberSoon()
        B.callbacks:FireCallbacks("InventoryChanged")
    end)
    B.EM:RegisterForEvent("Skillbound_Items", EVENT_INVENTORY_FULL_UPDATE, function()
        dirty = true
        RememberSoon()
        B.callbacks:FireCallbacks("InventoryChanged")
    end)
    B.EM:RegisterForEvent("Skillbound_ItemsLogin", EVENT_PLAYER_ACTIVATED, function()
        dirty = true
        RememberSoon()
    end)
    B.callbacks:RegisterCallback("BuildsChanged", Items.MarkBuildsDirty)
end
