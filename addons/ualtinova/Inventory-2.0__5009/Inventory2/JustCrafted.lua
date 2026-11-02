InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- JUST CRAFTED: the pieces made at a smithing-type bench since you walked up to it, repeated at
-- the top of its improvement and deconstruction lists. Never in the bag.
--
-- A piece is listed here as well as where it already stands, the same proxy row ARMORY and
-- RECENT LOOT use. It leaves once it is improved (its link changes) or is gone from the list
-- (deconstructed, destroyed), and the whole group is emptied when you leave the station.
--
-- Detection: the game says a craft started (EVENT_CRAFT_STARTED, craftingType) and ended
-- (EVENT_CRAFT_COMPLETED), craftingresults_base.lua. What arrives in the backpack in between as a
-- new item, while the bench is on its Creation tab (ZO_Smithing_Common:GetMode(),
-- SMITHING_MODE_CREATION, smithing_common.lua / smithing_keyboard.lua), is what was made.

local NAME = "InventoryGroupingJustCrafted"
local SETTLE_MS = 1000  -- how long after a craft ends a new slot still counts as its result
local REFRESH_MS = 150  -- one list rebuild for a burst of crafts

local SMITHING_TYPES = {}
for _, name in ipairs({ "CRAFTING_TYPE_BLACKSMITHING", "CRAFTING_TYPE_CLOTHIER",
    "CRAFTING_TYPE_WOODWORKING", "CRAFTING_TYPE_JEWELRYCRAFTING" }) do
    if _G[name] then SMITHING_TYPES[_G[name]] = true end
end

local crafted = {}   -- [pieceId] = its current link (kept up to date through improvement)
local order = {}     -- pieceIds, the newest last
local crafting = false

local function Enabled()
    return IG.sv ~= nil and IG.sv.justCraftedEnabled == true
end

local function RefreshSoon()
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Refresh", REFRESH_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
        if IG.RefreshCraftLists then IG.RefreshCraftLists() end
    end)
end

local function Clear()
    ZO_ClearTable(crafted)
    ZO_ClearNumericallyIndexedTable(order)
    crafting = false
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Settle")
end

local function OnCraftStarted(_, craftingType)
    if not Enabled() or not SMITHING_TYPES[craftingType] then return end
    -- Improving and deconstructing start a craft too; only the Creation tab makes new pieces.
    if SMITHING and SMITHING.GetMode and SMITHING_MODE_CREATION
        and SMITHING:GetMode() ~= SMITHING_MODE_CREATION then return end
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Settle")
    crafting = true
end

local function OnCraftCompleted()
    if not crafting then return end
    -- The new slot may land just after the craft is reported done: keep listening a moment.
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Settle")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Settle", SETTLE_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Settle")
        crafting = false
    end)
    RefreshSoon()
end

local function OnSlotUpdate(_, bagId, slotIndex, isNewItem)
    if not crafting or not isNewItem or not HasItemInSlot(bagId, slotIndex) then return end
    local itemType = GetItemType(bagId, slotIndex)
    if itemType ~= ITEMTYPE_WEAPON and itemType ~= ITEMTYPE_ARMOR then return end
    local pieceId = IG.PieceId(bagId, slotIndex)
    if not pieceId then return end
    if not crafted[pieceId] then order[#order + 1] = pieceId end
    crafted[pieceId] = GetItemLink(bagId, slotIndex)
    RefreshSoon()
end

local function OnLeaveStation()
    if not next(crafted) and not crafting then return end
    Clear()
end

-- One row per piece made this visit, newest first. rawEntries: the bench's own rows.
function IG.CollectJustCraftedEntries(rawEntries)
    local result = {}
    if not Enabled() or not next(crafted) then return result end

    local rank = {}
    for index, pieceId in ipairs(order) do rank[pieceId] = #order - index + 1 end

    local root
    for _, entry in ipairs(rawEntries) do
        local data = entry.data
        local bagId, slotIndex = data and data.bagId, data and data.slotIndex
        local pieceId = bagId and slotIndex and IG.PieceId(bagId, slotIndex)
        local link = pieceId and crafted[pieceId]
        if link then
            -- Improved pieces stay; the id survives, only the link (quality) moves on.
            crafted[pieceId] = GetItemLink(bagId, slotIndex)
            root = root or IG.MakeGroupNode("JUSTCRAFTED")
            result[#result + 1] = {
                -- Drawn as the bench row it repeats: that type is registered on this list.
                typeId = entry.typeId,
                data = setmetatable({ igJustCrafted = true }, { __index = data }),
                path = { root },
                slotRank = rank[pieceId],
            }
        end
    end
    return result
end

-- Registered only while the module itself is on (IG.MODULE_APPLY, called from IG.SetModuleEnabled
-- and once at load): EVENT_INVENTORY_SINGLE_SLOT_UPDATE fires on every bag change all session
-- long, not only while crafting, so a switch left off should not keep paying for it.
local registered = false

local function ApplyEnabled(on)
    if on == registered then return end
    registered = on
    if on then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CRAFT_STARTED, OnCraftStarted)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CRAFT_COMPLETED, OnCraftCompleted)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_END_CRAFTING_STATION_INTERACT, OnLeaveStation)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
        EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    else
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_CRAFT_STARTED)
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_CRAFT_COMPLETED)
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_END_CRAFTING_STATION_INTERACT)
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        Clear()
    end
end

IG.MODULE_APPLY = IG.MODULE_APPLY or {}
IG.MODULE_APPLY.justCraftedEnabled = ApplyEnabled
