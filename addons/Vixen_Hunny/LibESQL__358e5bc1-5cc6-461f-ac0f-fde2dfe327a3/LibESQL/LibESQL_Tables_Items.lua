-- Tables: sets, set_bonuses, set_pieces, items (scanned), inventory.

local E = LibESQL
local Try, Clean, Tick, EnumShort = E.Try, E.CleanName, E.Tick, E.EnumShort
local FUNCS = E.SQL.FUNCS
local format = string.format

local ITEM_LINK_FMT = "|H1:item:%d:0:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"

local function itemLink(id) return format(ITEM_LINK_FMT, id) end
E.ItemLink = itemLink

---------------------------------------------------------------------------
-- Columns derived from an item link (shared by items, inventory, set_pieces)
---------------------------------------------------------------------------
local function typeInfo(r)
    if r._typeDone then return end
    r._typeDone = true
    local t, s = Try(GetItemLinkItemType, r.link)
    r.item_type = t and EnumShort("ITEMTYPE_", t)
    r.specialized_type = s and EnumShort("SPECIALIZED_ITEMTYPE_", s)
end

local function setInfo(r)
    if r._setDone then return end
    r._setDone = true
    local hasSet, setName, _, _, maxEquipped, setId = Try(GetItemLinkSetInfo, r.link, false)
    if hasSet then
        r.set_name = Clean(setName)
        r.set_id = setId
        r.set_max_equipped = maxEquipped
    end
end

local function enumGetter(fn, prefix, skipZero)
    return function(r)
        local v = Try(fn, r.link)
        if v == nil or (skipZero and v == 0) then return nil end
        return EnumShort(prefix, v)
    end
end

local function itemLinkColumns(skip)
    skip = skip or {}
    local cols = {}
    if not skip.name then
        cols[#cols + 1] = { "name", "text", "Item name", function(r) return Clean(Try(GetItemLinkName, r.link)) end }
    end
    local more = {
        { "icon", "text", "Icon", function(r) return Try(GetItemLinkIcon, r.link) end },
        { "item_type", "text", "weapon, armor, potion, food, recipe, furnishing...", function(r) typeInfo(r); return r.item_type end },
        { "specialized_type", "text", "Specialized item type", function(r) typeInfo(r); return r.specialized_type end },
        { "quality", "text", "normal, magic, arcane, artifact, legendary, mythic_override", enumGetter(GetItemLinkDisplayQuality, "ITEM_DISPLAY_QUALITY_") },
        { "equip_type", "text", "head, chest, ring, one_hand...", enumGetter(GetItemLinkEquipType, "EQUIP_TYPE_", true) },
        { "armor_type", "text", "light, medium, heavy", enumGetter(GetItemLinkArmorType, "ARMORTYPE_", true) },
        { "weapon_type", "text", "sword, bow, fire_staff...", enumGetter(GetItemLinkWeaponType, "WEAPONTYPE_", true) },
        { "trait", "text", "Item trait", enumGetter(GetItemLinkTraitType, "ITEM_TRAIT_TYPE_", true) },
        { "set_id", "int", "Item set id", function(r) setInfo(r); return r.set_id end },
        { "set_name", "text", "Item set name", function(r) setInfo(r); return r.set_name end },
        { "level", "int", "Required level", function(r) return Try(GetItemLinkRequiredLevel, r.link) end },
        { "cp", "int", "Required champion points", function(r) return Try(GetItemLinkRequiredChampionPoints, r.link) end },
        { "value", "int", "Vendor value", function(r) return Try(GetItemLinkValue, r.link, false) end },
        { "bind_type", "text", "on_pickup, on_equip, ...", enumGetter(GetItemLinkBindType, "BIND_TYPE_") },
        { "style", "text", "Motif style", function(r)
            local s = Try(GetItemLinkItemStyle, r.link)
            if not s or s == 0 then return nil end
            return Clean(Try(GetItemStyleName, s)) end },
        { "unique", "bool", "Unique item", function(r) return Try(IsItemLinkUnique, r.link) and true or false end },
        { "armor_rating", "int", "Armor rating", function(r) local v = Try(GetItemLinkArmorRating, r.link, false); if v and v > 0 then return v end end },
        { "weapon_power", "int", "Weapon damage", function(r) local v = Try(GetItemLinkWeaponPower, r.link); if v and v > 0 then return v end end },
        { "on_use", "text", "On-use effect description", function(r)
            local has, header, desc = Try(GetItemLinkOnUseAbilityInfo, r.link)
            if not has then return nil end
            if header and header ~= "" then return header .. ": " .. (desc or "") end
            return desc end },
        { "flavor", "text", "Flavor text", function(r) local v = Try(GetItemLinkFlavorText, r.link); if v ~= "" then return v end end },
    }
    for _, c in ipairs(more) do
        if not skip[c[1]] then cols[#cols + 1] = c end
    end
    return cols
end
E.ItemLinkColumns = itemLinkColumns

local function withColumns(base, extra)
    local out = {}
    for _, c in ipairs(base) do out[#out + 1] = c end
    for _, c in ipairs(extra) do out[#out + 1] = c end
    return out
end

---------------------------------------------------------------------------
-- sets
---------------------------------------------------------------------------
local function setBasics(id)
    local a, b, c, d, e2 = Try(GetItemSetInfo, id)
    local name, numBonuses, maxEquipped
    if type(a) == "string" then
        name, numBonuses, maxEquipped = a, b, d
    else
        name, numBonuses, maxEquipped = b, c, e2
    end
    name = Clean(Try(GetItemSetName, id)) or Clean(name)
    return name, numBonuses, maxEquipped
end

local function forEachSetId(fn)
    local seen, maxId = {}, 0
    local id = Try(GetNextItemSetCollectionId)
    while id do
        Tick()
        seen[id] = true
        if id > maxId then maxId = id end
        fn(id, true)
        id = Try(GetNextItemSetCollectionId, id)
    end
    -- sets that are not in the collections UI
    for sid = 1, maxId + 300 do
        Tick()
        if not seen[sid] then
            local n = Try(GetItemSetName, sid)
            if n and n ~= "" then fn(sid, false) end
        end
    end
end

local function setBonuses(id, numBonuses)
    local out = {}
    local n = numBonuses or 12
    for i = 1, n do
        local req, desc, perfected = Try(GetItemSetBonusInfo, id, i)
        if not req or not desc or desc == "" then
            if not numBonuses then break end
        else
            out[#out + 1] = { req, desc, perfected and true or false }
        end
    end
    return out
end

E.RegisterTable({
    name = "sets",
    desc = "Every item set: type, category, pieces, bonuses",
    key = "id",
    columns = {
        { "id", "int", "Item set id" },
        { "name", "text", "Set name" },
        { "set_type", "text", "crafted, dungeon, monster, trial, overland, arena, mythic, cyrodiil..." },
        { "max_equipped", "int", "Pieces for the full bonus" },
        { "num_bonuses", "int", "Number of bonus lines" },
        { "in_collection", "bool", "Listed in the set collections UI" },
        { "category", "text", "Collection category", },
        { "parent_category", "text", "Parent collection category" },
        { "category_id", "int", "Collection category id" },
        { "perfected", "bool", "Perfected version of another set" },
        { "unperfected_id", "int", "Set id of the non-perfected version" },
        { "num_pieces", "int", "Collectible pieces" },
        { "pieces_unlocked", "int", "Pieces you have unlocked", function(r) return Try(GetNumItemSetCollectionSlotsUnlocked, r.id) end },
        { "bonuses", "text", "All bonus lines in one text", function(r)
            local parts = {}
            for _, b in ipairs(setBonuses(r.id, r.num_bonuses)) do parts[#parts + 1] = E.StripMarkup(b[2]) end
            return table.concat(parts, " | ") end },
    },
    build = function(rows)
        forEachSetId(function(id, inCollection)
            local name, numBonuses, maxEquipped = setBasics(id)
            local st = Try(GetItemSetType, id)
            local catId = Try(GetItemSetCollectionCategoryId, id)
            local parentId = catId and catId > 0 and Try(GetItemSetCollectionCategoryParentId, catId)
            local unperf = Try(GetItemSetUnperfectedSetId, id)
            rows[#rows + 1] = {
                id = id, name = name,
                set_type = st and EnumShort("ITEM_SET_TYPE_", st),
                max_equipped = maxEquipped, num_bonuses = numBonuses,
                in_collection = inCollection,
                category_id = catId and catId > 0 and catId or nil,
                category = catId and catId > 0 and Clean(Try(GetItemSetCollectionCategoryName, catId)) or nil,
                parent_category = parentId and parentId > 0 and Clean(Try(GetItemSetCollectionCategoryName, parentId)) or nil,
                perfected = unperf ~= nil and unperf > 0 and unperf ~= id,
                unperfected_id = unperf and unperf > 0 and unperf ~= id and unperf or nil,
                num_pieces = Try(GetNumItemSetCollectionPieces, id),
            }
        end)
    end,
})

E.RegisterTable({
    name = "set_bonuses",
    desc = "One row per set bonus line",
    columns = {
        { "set_id", "int", "Item set id" },
        { "set_name", "text", "Set name" },
        { "bonus_index", "int", "Bonus line number" },
        { "num_required", "int", "Pieces required" },
        { "description", "text", "Bonus text" },
        { "perfected", "bool", "Perfected-only bonus" },
    },
    build = function(rows)
        for _, set in ipairs(E.GetRows(E.GetTable("sets"))) do
            Tick()
            for i, b in ipairs(setBonuses(set.id, set.num_bonuses)) do
                rows[#rows + 1] = {
                    set_id = set.id, set_name = set.name, bonus_index = i,
                    num_required = b[1], description = E.StripMarkup(b[2]), perfected = b[3],
                }
            end
        end
    end,
})

E.RegisterTable({
    name = "set_pieces",
    desc = "Every collectible piece of every set, with item details",
    columns = withColumns({
        { "set_id", "int", "Item set id" },
        { "set_name", "text", "Set name" },
        { "piece_id", "int", "Collection piece id" },
        { "item_id", "int", "Item id", function(r) return Try(GetItemLinkItemId, r.link) end },
        { "link", "text", "Item link" },
        { "unlocked", "bool", "You have it in your collection", function(r) return Try(IsItemSetCollectionPieceUnlocked, r.piece_id) and true or false end },
    }, itemLinkColumns({ set_id = true, set_name = true })),
    build = function(rows)
        for _, set in ipairs(E.GetRows(E.GetTable("sets"))) do
            for i = 1, (set.num_pieces or 0) do
                Tick()
                local pieceId = Try(GetItemSetCollectionPieceInfo, set.id, i)
                if pieceId then
                    rows[#rows + 1] = {
                        set_id = set.id, set_name = set.name, piece_id = pieceId,
                        link = Try(GetItemSetCollectionPieceItemLink, pieceId, LINK_STYLE_DEFAULT or 0, ITEM_TRAIT_TYPE_NONE or 0),
                    }
                end
            end
        end
    end,
})

FUNCS.SET_NAME = function(id) id = tonumber(id); return id and Clean(Try(GetItemSetName, id)) end

---------------------------------------------------------------------------
-- items (every item id, by scanning)
---------------------------------------------------------------------------
E.RegisterTable({
    name = "items",
    desc = "Every item id in the game (scanned once per update; run SCAN items). Columns are read on demand.",
    key = "id",
    columns = withColumns({
        { "id", "int", "Item id" },
        { "link", "text", "Item link (base quality, level 1)" },
    }, itemLinkColumns()),
    scan = {
        label = "item",
        from = 1, to = 450000, gap = 40000, minTo = 230000,
        exists = function(id)
            local n = GetItemLinkName(itemLink(id))
            return n ~= nil and n ~= ""
        end,
        makeRow = function(id) return { id = id, link = itemLink(id) } end,
    },
})

FUNCS.ITEM_LINK = function(id) id = tonumber(id); return id and itemLink(id) end
FUNCS.ITEM_NAME = function(v)
    if v == nil then return nil end
    local link = tonumber(v) and itemLink(tonumber(v)) or tostring(v)
    local n = Try(GetItemLinkName, link)
    if n == "" then return nil end
    return Clean(n)
end
FUNCS.ITEM_ID = function(link) return link and Try(GetItemLinkItemId, tostring(link)) end

---------------------------------------------------------------------------
-- inventory
---------------------------------------------------------------------------
local function bagList()
    local bags = {}
    for _, name in ipairs({ "BAG_WORN", "BAG_BACKPACK", "BAG_BANK", "BAG_SUBSCRIBER_BANK", "BAG_VIRTUAL" }) do
        if _G[name] then bags[#bags + 1] = _G[name] end
    end
    for i = 1, 10 do
        local name = "BAG_HOUSE_BANK_" .. ({ "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN" })[i]
        if _G[name] then bags[#bags + 1] = _G[name] end
    end
    return bags
end

local function forEachSlot(bag, fn)
    if bag == BAG_VIRTUAL then
        local slot = Try(GetNextVirtualBagSlotId)
        while slot do
            fn(slot)
            slot = Try(GetNextVirtualBagSlotId, slot)
        end
        return
    end
    local size = Try(GetBagSize, bag) or 0
    for slot = 0, size - 1 do fn(slot) end
end

E.RegisterTable({
    name = "inventory",
    desc = "Items in your equipped slots, backpack, bank, craft bag and open house storage",
    live = true,
    columns = withColumns({
        { "bag", "text", "worn, backpack, bank, subscriber_bank, virtual (craft bag), house_bank_*" },
        { "slot", "int", "Slot index" },
        { "item_id", "int", "Item id" },
        { "name", "text", "Item name" },
        { "count", "int", "Stack size" },
        { "link", "text", "Item link" },
        { "equipped", "bool", "Worn by you" },
        { "stolen", "bool", "Stolen", function(r) return Try(IsItemStolen, r.bag_id, r.slot) and true or false end },
        { "locked", "bool", "Player locked", function(r) return Try(IsItemPlayerLocked, r.bag_id, r.slot) and true or false end },
        { "bound", "bool", "Bound", function(r) return Try(IsItemBound, r.bag_id, r.slot) and true or false end },
        { "bag_id", "int", "Bag id" },
    }, itemLinkColumns({ name = true })),
    build = function(rows)
        for _, bag in ipairs(bagList()) do
            local bagName = EnumShort("BAG_", bag)
            forEachSlot(bag, function(slot)
                Tick()
                local id = Try(GetItemId, bag, slot)
                if id and id > 0 then
                    local link = Try(GetItemLink, bag, slot, LINK_STYLE_DEFAULT or 0)
                    rows[#rows + 1] = {
                        bag = bagName, bag_id = bag, slot = slot, item_id = id,
                        name = Clean(Try(GetItemLinkName, link)),
                        count = Try(GetSlotStackSize, bag, slot),
                        link = link, equipped = bag == BAG_WORN,
                    }
                end
            end)
        end
    end,
})
