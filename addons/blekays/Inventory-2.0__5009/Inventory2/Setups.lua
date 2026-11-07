InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- SETUPS: gear you keep together, saved from what you are wearing. A module under MODULES
-- (setupsEnabled): the SETUPS category holds one sub-category per setup ("SETUP: <name>"), with
-- ARMOR / JEWELRY / WEAPONS / BUFF FOOD / QUICK SLOTS inside each. Switched off, setup pieces
-- stand in their own categories again; the setups themselves are kept.
--
-- A gear piece in a setup belongs to that setup and to no other category (the classifier asks
-- IG.SetupPathFor first); a piece in two setups stands in both (a proxy copy for the second).
-- Food and quickslot items are only remembered by item id: they are shown in the setup as a
-- copy and stay in their own categories too.
--
-- Setups are character data: csv.setups = { nextId = n, list = { [id] = setup } }, where
--   setup = { id, name (nil = named after its roles), order,
--             gear  = { [equipSlot] = { piece = uniqueId string, link } },
--             quick = { [wheelSlot] = { itemId, link } },
--             food  = { itemId, link } or nil }
-- Every change replaces list[id] with a new table, so Ctrl+Z (Undo.lua) puts the old one back.
--
-- Taking this module out: drop this file and its manifest line, the SETUPS lines in Colors.lua
-- (IG.GROUPS, DEFAULT_SECTION), ModuleStrip.lua (MODULE_ICONS), Settings.lua (setupsEnabled),
-- the IG.SetupPathFor lines in Classify.lua and the IG.*Setup* hook lines and MODULE_GROUPS
-- entry in InventoryGrouping.lua, Overrides.lua and InventoryGrouping.xml.

IG.SETUPS_KEY = "SETUPS"
local KEY_PREFIX = "SETUP_"
-- The section the setups had before they were a module; its saved state is dropped at load.
local OLD_SECTION = "EQUIPMENT SETUPS"
local SETUP_COLOR = "E8C872"
local SETUP_ICON = "EsoUI/Art/Armory/buildItem_icon.dds" -- the same art ARMORY wears (Colors.lua)

local store            -- csv.setups
local dirty = true      -- index and category registry want rebuilding
local byPiece = {}      -- [piece id] = { setup ids, lowest order first }
local slotOfPiece = {}  -- [setup id] = { [piece id] = equipSlot }
local pathCache = {}    -- [setup id .. "/" .. sub] = path

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

local SUB_ARMOR, SUB_JEWELRY, SUB_WEAPONS, SUB_FOOD, SUB_QUICK = 1, 2, 3, 4, 5
local SUB_LABELS = { "Armor", "Jewelry", "Weapons", "Buff Food", "Quick Slots" }
local SUB_ICON_GROUP = { [SUB_FOOD] = "FOODDRINK", [SUB_QUICK] = "CONSUMABLES" }

-- Every worn slot a setup can fill, in body order, with its name and heading.
IG.SETUP_SLOTS = {
    { slot = EQUIP_SLOT_HEAD,        name = "Head",            sub = SUB_ARMOR },
    { slot = EQUIP_SLOT_SHOULDERS,   name = "Shoulders",       sub = SUB_ARMOR },
    { slot = EQUIP_SLOT_CHEST,       name = "Chest",           sub = SUB_ARMOR },
    { slot = EQUIP_SLOT_HAND,        name = "Gloves",          sub = SUB_ARMOR },
    { slot = EQUIP_SLOT_WAIST,       name = "Waist",           sub = SUB_ARMOR },
    { slot = EQUIP_SLOT_LEGS,        name = "Legs",            sub = SUB_ARMOR },
    { slot = EQUIP_SLOT_FEET,        name = "Feet",            sub = SUB_ARMOR },
    { slot = EQUIP_SLOT_NECK,        name = "Neck",            sub = SUB_JEWELRY },
    { slot = EQUIP_SLOT_RING1,       name = "Ring 1",          sub = SUB_JEWELRY },
    { slot = EQUIP_SLOT_RING2,       name = "Ring 2",          sub = SUB_JEWELRY },
    { slot = EQUIP_SLOT_MAIN_HAND,   name = "Front Main Hand", sub = SUB_WEAPONS },
    { slot = EQUIP_SLOT_OFF_HAND,    name = "Front Off Hand",  sub = SUB_WEAPONS },
    { slot = EQUIP_SLOT_BACKUP_MAIN, name = "Back Main Hand",  sub = SUB_WEAPONS },
    { slot = EQUIP_SLOT_BACKUP_OFF,  name = "Back Off Hand",   sub = SUB_WEAPONS },
}
local SLOT_INFO = {}
for rank, info in ipairs(IG.SETUP_SLOTS) do
    info.rank = rank
    SLOT_INFO[info.slot] = info
end

-- Which slots a piece of this equip type can go in (GetItemLinkEquipType, ESOUIDocumentation
-- EquipType). Poisons and costumes are not gear a setup keeps.
local function SlotsForEquipType(equipType)
    if equipType == EQUIP_TYPE_HEAD then return { EQUIP_SLOT_HEAD } end
    if equipType == EQUIP_TYPE_SHOULDERS then return { EQUIP_SLOT_SHOULDERS } end
    if equipType == EQUIP_TYPE_CHEST then return { EQUIP_SLOT_CHEST } end
    if equipType == EQUIP_TYPE_HAND then return { EQUIP_SLOT_HAND } end
    if equipType == EQUIP_TYPE_WAIST then return { EQUIP_SLOT_WAIST } end
    if equipType == EQUIP_TYPE_LEGS then return { EQUIP_SLOT_LEGS } end
    if equipType == EQUIP_TYPE_FEET then return { EQUIP_SLOT_FEET } end
    if equipType == EQUIP_TYPE_NECK then return { EQUIP_SLOT_NECK } end
    if equipType == EQUIP_TYPE_RING then return { EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 } end
    if equipType == EQUIP_TYPE_ONE_HAND then
        return { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }
    end
    if equipType == EQUIP_TYPE_TWO_HAND or equipType == EQUIP_TYPE_MAIN_HAND then
        return { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_BACKUP_MAIN }
    end
    if equipType == EQUIP_TYPE_OFF_HAND then return { EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_OFF } end
    return nil
end
IG.SetupSlotsForLink = function(itemLink)
    if not itemLink or itemLink == "" then return nil end
    return SlotsForEquipType(GetItemLinkEquipType(itemLink))
end

function IG.SetupSlotName(slot)
    local info = SLOT_INFO[slot]
    return info and info.name or "?"
end

---------------------------------------------------------------------------
-- Store and index
---------------------------------------------------------------------------

local function List()
    return store and store.list or {}
end

function IG.SetupKey(id) return KEY_PREFIX .. id end

-- The module is on (Settings: Modules > Setups).
function IG.SetupsOn()
    return IG.sv ~= nil and IG.sv.setupsEnabled == true
end

-- A setup's own key ("SETUP_3") or its sub-category's heading key ("SETUPS/SETUP_3").
function IG.SetupIdOfKey(key)
    if type(key) ~= "string" then return nil end
    local id = key:match("^" .. KEY_PREFIX .. "(%d+)$")
        or key:match("^" .. IG.SETUPS_KEY .. "/" .. KEY_PREFIX .. "(%d+)$")
    return id and tonumber(id) or nil
end

function IG.GetSetup(id)
    return id and List()[id] or nil
end

-- Setups in their order (the order they were made in).
function IG.OrderedSetups()
    local ordered = {}
    for _, setup in pairs(List()) do ordered[#ordered + 1] = setup end
    table.sort(ordered, function(a, b) return (a.order or a.id) < (b.order or b.id) end)
    return ordered
end

-- The roles a setup's sets serve, weighted by how many of its pieces wear them.
local ROLE_WORDS = { damage = "DAMAGER", tank = "TANK", support = "HEALER" }
local CLOSE_SHARE = 0.75

function IG.SetupAutoName(setup)
    local scores = {}
    for _, gear in pairs(setup.gear or {}) do
        local link = gear.link
        local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link or "", false)
        if hasSet and IG.GetSetRoles then
            local roles = IG.GetSetRoles(setId, link) or {}
            for rank, role in ipairs(roles) do
                scores[role.key] = (scores[role.key] or 0) + (rank == 1 and 1 or 0.5)
            end
        end
    end
    local ranked = {}
    for key in pairs(scores) do ranked[#ranked + 1] = key end
    table.sort(ranked, function(a, b)
        if scores[a] ~= scores[b] then return scores[a] > scores[b] end
        return a < b
    end)
    if not ranked[1] then return "GEAR" end
    local name = ROLE_WORDS[ranked[1]] or zo_strupper(ranked[1])
    if ranked[2] and scores[ranked[2]] >= scores[ranked[1]] * CLOSE_SHARE then
        name = name .. " / " .. (ROLE_WORDS[ranked[2]] or zo_strupper(ranked[2]))
    end
    return name
end

function IG.SetupName(setup)
    if not setup then return "" end
    return setup.name or IG.SetupAutoName(setup)
end

-- The colour the setup's name is written in (after the fixed "SETUP:"): its own when one was
-- picked (setup.nameColor), otherwise one from the distinct run by setup id, so two setups
-- differ by default and each keeps its colour.
function IG.SetupNameColor(setup)
    if not setup then return IG.DEFAULT_ICON_COLOR end
    if setup.nameColor then return setup.nameColor end
    if IG.DistinctPaletteColor then return IG.DistinctPaletteColor(setup.id or 1) end
    return SETUP_COLOR
end

-- "SETUP: <name>" for menus and panels: the prefix in the SETUPS colour, the name in its own.
function IG.SetupColoredName(setup)
    return string.format("|c%sSETUP:|r |c%s%s|r", SETUP_COLOR, IG.SetupNameColor(setup),
        zo_strupper(IG.SetupName(setup)))
end

-- Setups are sub-categories of SETUPS (one IG.GROUPS entry, Colors.lua): their heading is
-- built here per setup, in the order they were made in.
local rankOf = {}       -- [setup id] = its place among the setups
local anySlotView = false -- some setup is shown By Slot (rows then wear their slot name)

-- How a setup lays out its gear: "type" (ARMOR / JEWELRY / WEAPONS), "set" (one set heading per
-- set, setless pieces under No Set) or "slot" (one list in body order). Food and quickslots are
-- their own headings in all three. Kept on the setup (setup.view), nil = "type".
local VIEWS = { type = true, set = true, slot = true }
local function SetupView(setup)
    local view = setup and setup.view
    return VIEWS[view] and view or "type"
end
IG.SetupView = SetupView

local function Rebuild()
    dirty = false
    ZO_ClearTable(byPiece)
    ZO_ClearTable(slotOfPiece)
    ZO_ClearTable(pathCache)
    ZO_ClearTable(rankOf)
    anySlotView = false
    for rank, setup in ipairs(IG.OrderedSetups()) do
        rankOf[setup.id] = rank
        if SetupView(setup) == "slot" then anySlotView = true end
        local slots = {}
        slotOfPiece[setup.id] = slots
        for slot, gear in pairs(setup.gear or {}) do
            if gear.piece then
                slots[gear.piece] = slot
                byPiece[gear.piece] = byPiece[gear.piece] or {}
                table.insert(byPiece[gear.piece], setup.id)
            end
        end
    end
end

-- How many different sets a setup's gear is made of (setless pieces not counted). The setup
-- heading says "(Sets: N)" in every view: By Type would otherwise count its ARMOR/JEWELRY/...
-- headings and By Set its set headings, two numbers for the same setup.
local function SetupSetCount(setup)
    local seen, count = {}, 0
    for _, gear in pairs(setup.gear or {}) do
        local node = gear.link and IG.GetSetNode(gear.link)
        if node and node.id ~= nil and not seen[node.id] then
            seen[node.id] = true
            count = count + 1
        end
    end
    return count
end

local function Fresh()
    if dirty then Rebuild() end
end

function IG.SetupsChanged()
    dirty = true
end

-- Every list rebuild we ask for goes through here (IG.RefreshLists), Ctrl+Z included.
local baseClearClassifyCache = IG.ClearClassifyCache
function IG.ClearClassifyCache(...)
    dirty = true
    return baseClearClassifyCache(...)
end

-- The setups a piece is in, lowest order first.
function IG.SetupsOfPiece(pieceId)
    Fresh()
    return pieceId and byPiece[pieceId] or nil
end

function IG.SetupSlotOfPiece(setupId, pieceId)
    Fresh()
    local slots = slotOfPiece[setupId]
    return slots and slots[pieceId] or nil
end

---------------------------------------------------------------------------
-- Classification
---------------------------------------------------------------------------

-- By Set: set headings first, then No Set, then BUFF FOOD (4) and QUICK SLOTS (5).
local SET_ORDER, NO_SET_ORDER = 0, 3.5

-- slot: the worn slot a gear piece stands for (nil for food and quickslots). The path carries
-- the slot's body-order rank (path.slotRank) so every row of a setup keeps slot order.
function IG.SetupPath(setupId, sub, slot)
    if not IG.SetupsOn() then return nil end
    Fresh()
    local setup = IG.GetSetup(setupId)
    if not (setup and rankOf[setupId] and IG.GROUP_BY_KEY[IG.SETUPS_KEY]) then return nil end
    local view = SetupView(setup)
    local info = slot and SLOT_INFO[slot]
    local isGear = sub <= SUB_WEAPONS
    local gear = info and setup.gear and setup.gear[slot]
    local setNode = isGear and view == "set" and gear and gear.link and IG.GetSetNode(gear.link) or nil
    local cacheKey = setupId .. "/" .. sub .. "/" .. (isGear and view or "") .. "/"
        .. (info and info.rank or 0) .. "/" .. (setNode and setNode.id or "")
    local path = pathCache[cacheKey]
    if path then return path end
    local root = IG.MakeGroupNode(IG.SETUPS_KEY)
    -- The heading counts setups, and its second bracket the rows under them (OVERLAND: Sets).
    root.countLabel = "Setups"
    root.chipBothCounts = true
    -- SETUPS > SETUP: <name> > ARMOR ... (three levels, like ARMORY > loadout > set).
    local setupNode = { id = IG.SetupKey(setupId), label = "SETUP: " .. IG.SetupName(setup),
        color = IG.Adapt and IG.Adapt(SETUP_COLOR) or SETUP_COLOR, icon = SETUP_ICON,
        iconKey = IG.SETUPS_KEY, order = rankOf[setupId],
        countLabel = "Sets", fixedCount = SetupSetCount(setup),
        -- The heading writes the name part in the setup's own colour (InventoryGrouping.lua).
        labelName = IG.SetupName(setup),
        nameColor = IG.Adapt and IG.Adapt(IG.SetupNameColor(setup)) or IG.SetupNameColor(setup) }
    if isGear and view == "slot" then
        -- Straight under the setup: rows under a node come before its sub-headings.
        path = { root, setupNode }
    else
        local node
        if isGear and view == "set" and setNode then
            node = ZO_ShallowTableCopy(setNode)
            node.order = SET_ORDER
        elseif isGear and view == "set" then
            node = IG.MakeSubNode(setupNode, "No Set")
            node.order = NO_SET_ORDER
        else
            node = IG.MakeSubNode(setupNode, SUB_LABELS[sub])
            node.order = sub
            local iconGroup = SUB_ICON_GROUP[sub] and IG.GROUP_BY_KEY[SUB_ICON_GROUP[sub]]
            if iconGroup then node.icon = iconGroup.icon or node.icon end
        end
        path = { root, setupNode, node }
    end
    path.slotRank = info and info.rank or nil
    pathCache[cacheKey] = path
    return path
end

-- Setup sub-category heading: Show as > By Type / By Set / By Slot (SetupsUI.lua). A way of
-- looking, not an edit of the setup: no Ctrl+Z step.
function IG.SetSetupView(id, view)
    local setup = IG.GetSetup(id)
    if not (setup and VIEWS[view]) then return end
    setup.view = view ~= "type" and view or nil
    dirty = true
    if IG.RefreshLists then IG.RefreshLists() end
end

local function SlotPiece(slotData)
    if not slotData then return nil end
    local uniqueId = slotData.uniqueId
    if uniqueId then return Id64ToString(uniqueId) end
    if slotData.bagId and slotData.slotIndex then return IG.PieceId(slotData.bagId, slotData.slotIndex) end
    return nil
end
IG.SetupSlotPiece = SlotPiece

-- Where a gear piece of a setup stands: its first setup. Nil for everything else, and cheap
-- while there are no setups at all.
function IG.SetupPathFor(slotData)
    if not store or not next(List()) or not IG.SetupsOn() then return nil end
    if not slotData or slotData.bagId == BAG_WORN then return nil end
    local pieceId = SlotPiece(slotData)
    local ids = pieceId and IG.SetupsOfPiece(pieceId)
    if not ids or not ids[1] then return nil end
    local slot = IG.SetupSlotOfPiece(ids[1], pieceId)
    local info = slot and SLOT_INFO[slot]
    return IG.SetupPath(ids[1], info and info.sub or SUB_ARMOR, info and slot)
end

-- Module copies of a setup piece (RECENT LOOT, ARMORY, UNCOLLECTED, ...) are dropped: the
-- piece belongs to its setup. EQUIPPED keeps showing what you wear, and the setups' own rows stay.
function IG.FilterSetupExtras(extras)
    if not store or not next(List()) or not IG.SetupsOn() then return extras end
    local kept = {}
    for _, extra in ipairs(extras) do
        local path = extra.path
        local top = path and path[1] and path[1].id
        local keep = top == "EQUIPPED" or top == IG.SETUPS_KEY
        if not keep then
            local data = extra.data
            local pieceId = data and data.bagId and data.bagId ~= BAG_WORN and SlotPiece(data)
            keep = not (pieceId and IG.SetupsOfPiece(pieceId))
        end
        if keep then kept[#kept + 1] = extra end
    end
    return kept
end

---------------------------------------------------------------------------
-- Extra rows: a piece in a second setup, and each setup's food and quickslot items
---------------------------------------------------------------------------

local function Copy(data, fields)
    fields.igSetupCopy = true
    return setmetatable(fields, { __index = data })
end

function IG.CollectSetupEntries(inventory, inventoryType, items, searchText, storedType)
    local result = {}
    if not store or not next(List()) or not IG.SetupsOn() then return result end
    if inventoryType == INVENTORY_BANK and IG.sv.bankModules and IG.sv.bankModules.SETUPS == false then
        return result
    end
    Fresh()
    local isBackpack = inventoryType == INVENTORY_BACKPACK

    -- A gear piece in more than one setup: a copy under each setup after the first.
    local byItemId = {}
    for _, entry in ipairs(items) do
        local data = entry.data
        if data and rawget(data, "bagId") and data.slotIndex then
            local pieceId = SlotPiece(data)
            local ids = pieceId and byPiece[pieceId]
            if ids then
                for index = 2, #ids do
                    local slot = IG.SetupSlotOfPiece(ids[index], pieceId)
                    local info = slot and SLOT_INFO[slot]
                    local path = IG.SetupPath(ids[index], (info or SLOT_INFO[EQUIP_SLOT_HEAD]).sub, info and slot)
                    if path then
                        result[#result + 1] = { data = Copy(data, { igSetupOf = ids[index] }), path = path,
                            slotRank = path.slotRank }
                    end
                end
            end
            if isBackpack and data.bagId == BAG_BACKPACK then
                local itemId = GetItemId(data.bagId, data.slotIndex)
                if itemId and itemId ~= 0 and not byItemId[itemId] then byItemId[itemId] = data end
            end
        end
    end

    -- Food and quickslot items: a copy of the bag stack, or a faded line when there is none.
    if isBackpack then
        for _, setup in ipairs(IG.OrderedSetups()) do
            local wanted = {}
            if setup.food and setup.food.itemId then
                wanted[#wanted + 1] = { item = setup.food, sub = SUB_FOOD, rank = 0 }
            end
            for wheel, item in pairs(setup.quick or {}) do
                wanted[#wanted + 1] = { item = item, sub = SUB_QUICK, rank = wheel }
            end
            for _, want in ipairs(wanted) do
                local path = IG.SetupPath(setup.id, want.sub)
                local data = byItemId[want.item.itemId]
                if path and data then
                    result[#result + 1] = { data = Copy(data, {}), path = path, slotRank = want.rank }
                elseif path and IG.SetupStoredEntry then
                    local extra = IG.SetupStoredEntry(inventory, searchText, storedType, want.item.link,
                        "none in bag", setup.id, nil)
                    if extra then
                        extra.path, extra.slotRank = path, want.rank
                        result[#result + 1] = extra
                    end
                end
            end
        end
    end
    if IG.CollectSetupGearLines then
        for _, extra in ipairs(IG.CollectSetupGearLines(inventory, inventoryType, searchText, storedType)) do
            result[#result + 1] = extra
        end
    end
    return result
end

-- A read-only line for something the setup names but the list cannot show as a real row
-- (drawn by InventoryGrouping's saved-item row, faded). Only on the "All" tab: it has no item
-- type the tab filters could be matched against (the same rule as HOME CONTAINERS).
local storedCounter = 0
function IG.SetupStoredEntry(inventory, searchText, storedType, link, note, setupId, slot, bagId, slotIndex)
    if not (storedType and link and link ~= "") then return nil end
    if inventory and inventory.currentFilter ~= ITEM_TYPE_DISPLAY_CATEGORY_ALL then return nil end
    local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))
    if searchText and searchText ~= "" and not zo_strlower(name):find(searchText, 1, true) then return nil end
    storedCounter = storedCounter + 1
    return {
        typeId = storedType,
        data = { link = link, count = 1, igStored = true, igFaded = true,
            name = string.format("%s  |c9A9AA2(%s)|r", name, note),
            -- A slot of its own for other addons that read one off the row; never the worn bag.
            bagId = bagId or -1, slotIndex = slotIndex or -storedCounter,
            igSetupId = setupId, igSetupSlot = slot },
    }
end

---------------------------------------------------------------------------
-- Gear lines in the bag: worn pieces (a copy with a WORN mark; EQUIPPED keeps its own), pieces
-- in the bank (faded "in bank"), pieces gone (faded "Missing"). The bank list needs nothing:
-- a setup piece there is classified into its setup like any other row.
---------------------------------------------------------------------------

local WORN_INVENTORY = { slotType = SLOT_TYPE_EQUIPMENT }
local BANK_BAGS = { [BAG_BANK] = true }
if BAG_SUBSCRIBER_BANK then BANK_BAGS[BAG_SUBSCRIBER_BANK] = true end

function IG.CollectSetupGearLines(inventory, inventoryType, searchText, storedType)
    local result = {}
    if inventoryType ~= INVENTORY_BACKPACK then return result end
    local where = {}
    for _, bagId in ipairs({ BAG_WORN, BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        local cache = bagId and SHARED_INVENTORY:GetOrCreateBagCache(bagId)
        for _, slotData in pairs(cache or {}) do
            if type(slotData) == "table" and slotData.slotIndex then
                local pieceId = SlotPiece(slotData)
                if pieceId and not where[pieceId] then where[pieceId] = slotData end
            end
        end
    end
    for _, setup in ipairs(IG.OrderedSetups()) do
        for _, info in ipairs(IG.SETUP_SLOTS) do
            local gear = setup.gear and setup.gear[info.slot]
            local path = gear and IG.SetupPath(setup.id, info.sub, info.slot)
            if path then
                local found = where[gear.piece]
                if found and found.bagId == BAG_WORN then
                    if not IG.PassesListFilter or IG.PassesListFilter(inventory, found, searchText) then
                        result[#result + 1] = { path = path, slotRank = info.rank,
                            data = setmetatable({ igSetupWorn = true, igSetupCopy = true,
                                igSetupOf = setup.id, inventory = WORN_INVENTORY }, { __index = found }) }
                    end
                elseif found and BANK_BAGS[found.bagId] then
                    local extra = IG.SetupStoredEntry(inventory, searchText, storedType, gear.link,
                        "in bank", setup.id, info.slot, found.bagId, found.slotIndex)
                    if extra then
                        extra.path, extra.slotRank = path, info.rank
                        result[#result + 1] = extra
                    end
                elseif not found then
                    local extra = IG.SetupStoredEntry(inventory, searchText, storedType, gear.link,
                        "Missing", setup.id, info.slot)
                    if extra then
                        extra.path, extra.slotRank = path, info.rank
                        result[#result + 1] = extra
                    end
                end
            end
        end
    end
    return result
end

-- The slot name a row wears when its setup is shown By Slot, or nil.
local function RowSlotName(data)
    Fresh()
    if not (anySlotView and IG.SetupsOn()) then return nil end
    local id, slot = data.igSetupId or data.igSetupOf, data.igSetupSlot
    if not id then
        if data.igStored or data.bagId == BAG_WORN or not data.slotIndex then return nil end
        local pieceId = SlotPiece(data)
        local ids = pieceId and IG.SetupsOfPiece(pieceId)
        id = ids and ids[1]
        slot = id and IG.SetupSlotOfPiece(id, pieceId)
    elseif not slot and not data.igStored then
        local pieceId = SlotPiece(data)
        slot = pieceId and IG.SetupSlotOfPiece(id, pieceId)
    end
    if not (slot and SLOT_INFO[slot] and SetupView(IG.GetSetup(id)) == "slot") then return nil end
    return SLOT_INFO[slot].name
end

-- After the name of a setup row: its slot name when the setup is shown By Slot (grey), then
-- the WORN mark of a worn piece's copy (InventoryGrouping's row decoration calls this; returns
-- where the notes after the name now end).
local WORN_FONT = "$(BOLD_FONT)|13|soft-shadow-thin"
local WORN_GAP = 8
function IG.DressSetupRow(control, data, nameLabel, nameRight)
    local slotLabel = control.igSetupSlotLabel
    local slotName = nameLabel and RowSlotName(data)
    if slotName then
        if not slotLabel then
            slotLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
            slotLabel:SetFont(WORN_FONT)
            slotLabel:SetColor(0.60, 0.60, 0.64)
            slotLabel:SetMouseEnabled(false)
            control.igSetupSlotLabel = slotLabel
        end
        slotLabel:SetText(zo_strupper(slotName))
        slotLabel:ClearAnchors()
        slotLabel:SetAnchor(LEFT, nameLabel, LEFT, nameRight + WORN_GAP, 0)
        slotLabel:SetHidden(false)
        nameRight = nameRight + WORN_GAP + slotLabel:GetTextWidth()
    elseif slotLabel then
        slotLabel:SetHidden(true)
    end
    local mark = control.igSetupWornMark
    if not (data.igSetupWorn and nameLabel) then
        if mark then mark:SetHidden(true) end
        return nameRight
    end
    if not mark then
        mark = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        mark:SetFont(WORN_FONT)
        mark:SetColor(0.36, 0.88, 0.48)
        mark:SetText("WORN")
        mark:SetMouseEnabled(false)
        control.igSetupWornMark = mark
    end
    mark:ClearAnchors()
    mark:SetAnchor(LEFT, nameLabel, LEFT, nameRight + WORN_GAP, 0)
    mark:SetHidden(false)
    return nameRight + WORN_GAP + mark:GetTextWidth()
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

-- Called from InventoryGrouping's ADD_ON_LOADED with the character's saved table, before the
-- saved-variable cleanup runs (which drops state for categories GROUP_BY_KEY does not know).
function IG.InitSetups(csv)
    if not csv then return end
    csv.setups = csv.setups or { nextId = 1, list = {} }
    csv.setups.list = csv.setups.list or {}
    csv.setups.nextId = csv.setups.nextId or 1
    store = csv.setups
    -- The setups were a section of their own once; what was saved about that section goes.
    local sv = IG.sv
    for _, name in ipairs({ "sectionCollapsed", "sectionDisplay", "sectionStripOpen" }) do
        for _, perList in pairs(sv and type(sv[name]) == "table" and sv[name] or {}) do
            if type(perList) == "table" then perList[OLD_SECTION] = nil end
        end
    end
    Rebuild()
end

function IG.SetupStore()
    return store
end
