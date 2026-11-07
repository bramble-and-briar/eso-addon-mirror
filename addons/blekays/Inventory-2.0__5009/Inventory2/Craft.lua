InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Crafting stations keep their own lists: deconstruction, improvement and universal
-- deconstruction. Each one is an inventory with a SortData step, so it gets the same grouping
-- as the bag. Deconstruction keeps its answers under "craft:<skill>", improvement under
-- "improve:<skill>", one per crafting skill (BenchKey, InventoryGrouping.lua).

-- The stations' tie-break table, copied from craftinginventory.lua (sortKeys there is local).
local STATION_SORT_KEYS = {
    slotIndex = { isNumeric = true },
    stackCount = { tiebreaker = "slotIndex", isNumeric = true },
    name = { tiebreaker = "displayQuality" },
    displayQuality = { tiebreaker = "quality", isNumeric = true },
    quality = { tiebreaker = "stackCount", isNumeric = true },
    statusSortOrder = { tiebreaker = "name", isNumeric = true },
    stackSellPrice = { tiebreaker = "name", isNumeric = true },
    traitInformationSortOrder = { tiebreaker = "name", isNumeric = true },
    level = { tiebreaker = "name", isNumeric = true, tieBreakerSortOrder = ZO_SORT_ORDER_UP },
    custom = { tiebreaker = "name", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
}

local stations = {} -- { inventory, control, defaultSort, inventoryType } for every list we took over

-- The bag and the bank have a search box of the game's own, and everything this addon does
-- while a search runs -- opening every group into a memory of its own, counting what is left --
-- hangs off it. A crafting bench has none: ZO_CraftingInventoryTemplate (craftinginventory.xml)
-- carries the filter tabs, a divider, a sort header and the list, and nothing to type in. The
-- one search box on the smithing screen belongs to the set-crafting tab (smithing_keyboard.lua,
-- setSearchBox) and never reaches these lists.
--
-- So the box is ours. One per bench, built from the game's own edit templates so it is the box
-- the player already knows, and what is typed in it is read back by the list build.
local searchTexts = {} -- [inventoryType] = what is typed, in lower case ("" for nothing)
local searchBoxes = {} -- [inventoryType] = the box, for the keybind that focuses a search

local SEARCH_WIDTH = 200
local SEARCH_HEIGHT = 28
local SEARCH_RISE = 6   -- the same gap the bench's own buttons keep above the sort header
local SEARCH_NARROW_WIDTH = 170 -- universal deconstruction: between Include Banked and its combo
local SEARCH_GAP = 10
local SEARCH_DRAW_LEVEL = 5
local searchBoxCount = 0 -- CreateControlFromVirtual answers nil for a name used twice

-- What is typed at this bench right now, in lower case; "" while nothing is.
function IG.CraftSearchText(inventoryType)
    return searchTexts[inventoryType] or ""
end

-- The box itself, so the search keybind can reach the bench it is standing at.
function IG.CraftSearchBox(inventoryType)
    return searchBoxes[inventoryType]
end

-- Whether a row survives what is typed. The name and nothing else, which is what the bag's own
-- box asks of a row before it keeps it.
local function MatchesSearch(entry, text)
    local name = entry.data and entry.data.name
    if not name then return false end
    return zo_strlower(name):find(text, 1, true) ~= nil
end

-- Runs when a station rebuilds its list; returns false so the station's own sorting still runs.
local function GroupStationList(inventory)
    local station
    for _, candidate in ipairs(stations) do
        if candidate.inventory == inventory then station = candidate end
    end
    if not station then return false end

    -- Minimal leaves the stations to the game: their lists are short and already filtered.
    if IG.sv.flatGrouping then
        inventory.sortFunction = station.defaultSort
        return false
    end
    -- The craft station switches (Settings.lua: CRAFT_STATION_TYPES): off for the skill the
    -- player is standing at right now, this one station is left to the game too.
    if IG.CraftStationCategoryOff() then
        inventory.sortFunction = station.defaultSort
        return false
    end

    local scrollData = ZO_ScrollList_GetDataList(inventory.list)
    -- Headers in the list mean it is one of ours, and the items inside closed groups are gone:
    -- let the station build it from its slots again, which comes back through here with raw rows.
    for _, entry in ipairs(scrollData) do
        if IG.IsOwnRowType(entry.typeId) then
            inventory:PerformFullRefresh()
            return true
        end
    end

    -- What is typed in our box. The bench has no search of its own, so nothing has thinned the
    -- list before it got here: the rows that do not match are taken out now, before the grouping
    -- reads them, so the counts on every heading are counts of what is actually on screen.
    local text = IG.CraftSearchText(station.inventoryType)
    if text ~= "" then
        local kept = {}
        for _, entry in ipairs(scrollData) do
            if MatchesSearch(entry, text) then kept[#kept + 1] = entry end
        end
        ZO_ClearNumericallyIndexedTable(scrollData)
        for _, entry in ipairs(kept) do scrollData[#scrollData + 1] = entry end
    end

    -- The station's own column header (NAME, VALUE, ...) orders the items inside each category:
    -- its current key and direction (ZO_CraftingInventory:ChangeSort, craftinginventory.lua).
    IG.headerSort = { key = inventory.sortKey, order = inventory.sortOrder, keys = STATION_SORT_KEYS }
    -- The bench's own item row type, which proxy rows (JUST CRAFTED) are drawn with.
    local itemType = inventory.GetScrollDataType and inventory:GetScrollDataType()
    IG.BuildCraftList(inventory.list, station.inventoryType, itemType, station.lead)
    IG.headerSort = nil
    -- The station sorts the list right after this; keeping each row's position as its sort key
    -- leaves our grouping intact.
    for index, entry in ipairs(ZO_ScrollList_GetDataList(inventory.list)) do entry.igOrder = index end
    inventory.sortFunction = function(left, right)
        return (left.igOrder or 0) < (right.igOrder or 0)
    end
    return false
end

-- Rebuilds whichever station list is on screen (after a settings change or a group being opened).
function IG.RefreshCraftLists()
    for _, station in ipairs(stations) do
        if station.control and not station.control:IsHidden() then
            station.inventory:PerformFullRefresh()
        end
    end
end

-- The station list the player is looking at right now, for anything that has to reach the rows
-- it already drew rather than have it built again.
function IG.VisibleCraftList()
    for _, station in ipairs(stations) do
        if station.control and not station.control:IsHidden() then
            return station.inventory and station.inventory.list
        end
    end
end

-- The same, with the list type it is built as: the header buttons ask it at a bench.
function IG.VisibleCraftStation()
    for _, station in ipairs(stations) do
        if station.control and not station.control:IsHidden() then
            return station.inventoryType, station.inventory and station.inventory.list
        end
    end
end

-- Smithing deconstruction: the right end of the Include Banked row, SEARCH_WIDTH wide. The
-- checkbox writes its label to its own right (ZO_CheckButton_SetLabelText, buttontemplates.lua),
-- as long as the client's language makes it, so a box a fixed width in from the right can start
-- before that label ends. When it would, it starts just after the label instead and keeps the
-- same right edge. Measured again every time the bench opens.
local function PlaceOnBankedRow(backdrop, sortBy, banked)
    backdrop:ClearAnchors()
    local label = banked.label
    local labelRight = label and label:GetRight() or 0
    local sortRight = sortBy:GetRight() or 0
    if labelRight > 0 and sortRight > 0 and labelRight + SEARCH_GAP > sortRight - SEARCH_WIDTH then
        backdrop:SetAnchor(LEFT, label, RIGHT, SEARCH_GAP, 0)
        backdrop:SetAnchor(RIGHT, sortBy, RIGHT, 0, 0, ANCHOR_CONSTRAINS_X)
    else
        backdrop:SetAnchor(RIGHT, sortBy, RIGHT, 0, 0, ANCHOR_CONSTRAINS_X)
        backdrop:SetAnchor(RIGHT, banked, RIGHT, 0, 0, ANCHOR_CONSTRAINS_Y)
    end
end

-- Universal deconstruction: both a CraftingTypes combo and an Include Banked row sit on this
-- line, the combo to the right. The box stands left of the combo, narrow; when the checkbox
-- label would run under it, it starts after the label instead and keeps the same right edge --
-- the same give-way PlaceOnBankedRow makes for the smithing bench, bounded by the combo's left
-- edge here rather than by the sort header's right.
local function PlaceBeforeTypes(backdrop, types, banked)
    backdrop:ClearAnchors()
    local label = banked.label
    local labelRight = label and label:GetRight() or 0
    local typesLeft = types:GetLeft() or 0
    if labelRight > 0 and typesLeft > 0
        and labelRight + SEARCH_GAP > typesLeft - SEARCH_GAP - SEARCH_NARROW_WIDTH then
        backdrop:SetAnchor(LEFT, label, RIGHT, SEARCH_GAP, 0)
        backdrop:SetAnchor(RIGHT, types, LEFT, -SEARCH_GAP, 0, ANCHOR_CONSTRAINS_X)
    else
        backdrop:SetWidth(SEARCH_NARROW_WIDTH)
        backdrop:SetAnchor(RIGHT, types, LEFT, -SEARCH_GAP, 0)
    end
end

-- The box, one per bench. Our own switches and marks stand on the bench's bottom bar
-- (Toolbar.lua), so the rows up here are left to the game's controls and this box.
local function CreateSearchBox(station, inventory)
    local control = inventory.control
    local sortBy = control and control.GetNamedChild and control:GetNamedChild("SortBy")
    if not (control and sortBy) then return end

    searchBoxCount = searchBoxCount + 1
    local name = "InventoryGroupingCraftSearch" .. searchBoxCount
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(name, control, "ZO_EditBackdrop")
    if not backdrop then return end
    backdrop:SetDimensions(SEARCH_WIDTH, SEARCH_HEIGHT)
    -- Where the bench leaves room, which is not the same place on all three
    -- (smithingextraction_keyboard.xml, universaldeconstructionpanel_keyboard.xml,
    -- smithingimprovement_keyboard.xml):
    --   universal deconstruction: its Include Banked row ends in the CraftingTypes combo on the
    --     right, so the box stands just left of that combo;
    --   smithing deconstruction: the Include Banked row is free on the right;
    --   improvement: no such row, and the sort header sits right under the filter tabs, so the
    --     box takes the empty left end of the tabs row.
    local types = control:GetNamedChild("CraftingTypes")
    local banked = control:GetNamedChild("IncludeBanked")
    local tabs = control:GetNamedChild("Tabs")
    if types and banked then
        PlaceBeforeTypes(backdrop, types, banked)
        control:SetHandler("OnEffectivelyShown", function()
            PlaceBeforeTypes(backdrop, types, banked)
        end, "InventoryGroupingCraftSearchPlace")
    elseif types then
        backdrop:SetWidth(SEARCH_NARROW_WIDTH)
        backdrop:SetAnchor(RIGHT, types, LEFT, -SEARCH_GAP, 0)
    elseif banked then
        PlaceOnBankedRow(backdrop, sortBy, banked)
        control:SetHandler("OnEffectivelyShown", function()
            PlaceOnBankedRow(backdrop, sortBy, banked)
        end, "InventoryGroupingCraftSearchPlace")
    elseif tabs then
        backdrop:SetAnchor(LEFT, control, LEFT, SEARCH_GAP, 0, ANCHOR_CONSTRAINS_X)
        backdrop:SetAnchor(LEFT, tabs, LEFT, 0, 0, ANCHOR_CONSTRAINS_Y)
        -- Over the tabs' Active label, which spans this end of the row with nothing drawn here.
        backdrop:SetDrawLevel(SEARCH_DRAW_LEVEL)
    else
        backdrop:SetAnchor(BOTTOMRIGHT, sortBy, TOPRIGHT, 0, -SEARCH_RISE)
    end

    local box = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Edit", backdrop,
        "ZO_DefaultEditForBackdrop")
    if not box then return end
    box:SetDefaultText("Search")

    local inventoryType = station.inventoryType
    box:SetHandler("OnTextChanged", function(self)
        local text = zo_strlower(self:GetText() or "")
        if searchTexts[inventoryType] == text then return end
        searchTexts[inventoryType] = text
        -- Rebuilt from the bench's own slots: the rows this search took out are not in the
        -- list to be put back, so the list has to be made again rather than sorted again.
        if not control:IsHidden() then inventory:PerformFullRefresh() end
    end)
    -- A bench locks its controls while something is being made; the game's own boxes are
    -- handed to it the same way (ZO_CraftingUtils_ConnectEditBoxToCraftingProcess,
    -- craftingutils.lua).
    if ZO_CraftingUtils_ConnectEditBoxToCraftingProcess then
        ZO_CraftingUtils_ConnectEditBoxToCraftingProcess(box)
    end

    -- Leaving the bench leaves the search behind: coming back to a list quietly thinned by
    -- something typed an hour ago reads as a bench that lost half your gear.
    control:SetHandler("OnEffectivelyHidden", function()
        if (searchTexts[inventoryType] or "") == "" then return end
        searchTexts[inventoryType] = ""
        box:SetText("")
    end, "InventoryGroupingCraftSearch")

    searchBoxes[inventoryType] = box
    -- After the handler above: the X chains onto it and empties the box through it.
    IG.AttachSearchClear(box)
end

-- A bench with a lead (DECONSTRUCT at deconstruction) draws it first and opens it every time it
-- is come back to (LeadFirst, InventoryGrouping.lua). Leaving the bench is what starts the next
-- visit: the lead is owed its opening again, and the list goes back to its top so the visit
-- starts there rather than wherever the last one was scrolled to. Put there while hidden, the
-- first build of the next visit commits at the top and nothing is built twice for it.
local function WatchVisits(station, inventory)
    local lead, control, list = station.lead, inventory.control, inventory.list
    if not (lead and control and list) then return end
    control:SetHandler("OnEffectivelyHidden", function()
        lead.fresh = true
        ZO_ScrollList_ResetToTop(list)
    end, "InventoryGroupingCraftLead")
end

function IG.InitCraftStations()
    local panels = {}
    if SMITHING then
        -- Smithing, clothing, woodworking and jewelry all take things apart in this one panel.
        -- Refining is a panel of its own and is never grouped (SMITHING.refinementPanel).
        panels[#panels + 1] = { panel = SMITHING.deconstructionPanel, name = "deconstruction",
            lead = "DECON" }
        -- ZO_SmithingImprovement (smithing_keyboard.lua): its inventory is a
        -- ZO_SmithingImprovementInventory, a ZO_CraftingInventory like deconstruction's.
        panels[#panels + 1] = { panel = SMITHING.improvementPanel, name = "improvement",
            inventoryType = IG.IMPROVE_INVENTORY_TYPE }
    end
    if UNIVERSAL_DECONSTRUCTION then
        panels[#panels + 1] = { panel = UNIVERSAL_DECONSTRUCTION.deconstructionPanel,
            name = "universal deconstruction", lead = "DECON" }
    end

    for _, entry in ipairs(panels) do
        local panel = entry.panel
        local inventory = panel and panel.inventory
        if inventory and inventory.list and inventory.SortData then
            stations[#stations + 1] = {
                inventory = inventory,
                control = panel.control,
                defaultSort = inventory.sortFunction,
                inventoryType = entry.inventoryType or IG.CRAFT_INVENTORY_TYPE,
                -- The first visit is a visit too: owed its opening from the start.
                lead = entry.lead and { key = entry.lead, fresh = true } or nil,
            }
            IG.RegisterRowTypes(inventory.list)
            IG.HookRowSetup(inventory.list)
            ZO_PreHook(inventory, "SortData", GroupStationList)
            CreateSearchBox(stations[#stations], inventory)
            WatchVisits(stations[#stations], inventory)
        else
            -- Said out loud once: a station missed here is a list the game draws ungrouped,
            -- with nothing else to tell why.
            d("|cFF8800Inventory 2.0:|r the " .. entry.name
                .. " station list was not found; it stays ungrouped.")
        end
    end
end
