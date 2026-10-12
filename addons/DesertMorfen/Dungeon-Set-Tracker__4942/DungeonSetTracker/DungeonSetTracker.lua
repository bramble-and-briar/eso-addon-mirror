-- DungeonSetTracker: while you hover a dungeon in the Dungeon Finder, or a dungeon, trial or arena on the world map,
-- shows which pieces of its sets you have collected; on the map of an open zone an icon shows the zone's sets. Also an optional HUD panel inside dungeons and optional chat
-- messages. It only reads the game's own set collection data and displays it; it never acts for you.

DungeonSetTracker = DungeonSetTracker or {}
local DST = DungeonSetTracker
DST.name = "DungeonSetTracker"
DST.version = "1.1.0"
local L = DST.L

local SV_VERSION = 1
local SUMMARY_REPEAT_SECONDS = 30 * 60  -- no second chat summary for the same dungeon within this time

-- Saved setting names are kept from earlier versions (e.g. "finderTooltip", "tipSide") so no migration is needed.
local defaults = {
    finderTooltip = true,       -- set chart while hovering dungeons in the Dungeon Finder
    mapTooltip = true,          -- set chart while hovering dungeons, trials and arenas on the world map
    mapZoneButton = true,       -- icon on the map of an open zone that shows the zone's sets
    tipSide = "left",           -- "left" / "right" screen edge, or "preview": next to the game's dungeon preview
    tipOffsetX = 40,
    tipOffsetY = 0,
    tipScale = 100,             -- percent
    tipBgAlpha = 100,           -- percent
    tipHideCompleted = false,   -- leave fully collected sets out of the chart
    tipShowLegend = true,
    showPanel = false,
    panelLocked = false,
    panelScale = 100,           -- percent
    panelHideCompleted = false,
    -- panelPos = { x, y }: offset of the panel's center from the screen center, once it has been moved
    chatOnEnter = false,
    chatNewPiece = false,       -- the game itself already announces new collection pieces
}

local sv
local ui = {}
-- "Dungeons" here also means trials and arenas; isDungeon is true only for the dungeons of the Dungeon Finder.
local dungeons              -- { { category, id, name, key, isDungeon, sets = { setData, ... } }, ... } in book order
local dungeonsByKey         -- [normalized name] = dungeon entry
local dungeonsBySetId       -- [itemSetId] = dungeon entry
local dungeonsProvisional   -- true when built without Dungeon Finder data, rebuilt on next use
local finderZoneIds         -- [normalized zone name] = zoneId of each Dungeon Finder dungeon
local currentDungeon        -- entry for the dungeon the player is in, or nil
local currentZoneId         -- zone the player is in

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(fmt, ...)
    CHAT_ROUTER:AddSystemMessage(string.format("|cC8A86B[%s]|r ", L.TITLE) .. string.format(fmt, ...))
end

local function FormatCount(unlocked, total)
    return string.format("%d / %d", unlocked, total)
end

-- Category and zone names come from different string tables and can differ in grammar markers
-- ("^n") and capitalization, so both are reduced to the same plain lower-case form.
-- Spaces and ASCII punctuation are dropped too, so "Banished Cells I" and "Banished Cells  I" match.
local function NormalizeName(name)
    if not name or name == "" then return nil end
    local key = zo_strlower(zo_strformat("<<1>>", name)):gsub("ё", "е"):gsub("[%s%p]", "")
    if key == "" then return nil end
    return key
end

-- Completed sets in green; everything else in the normal text color, so even a set without any collected
-- piece stays readable.
local function ProgressColor(unlocked, total)
    if total > 0 and unlocked >= total then
        return ZO_SUCCEEDED_TEXT
    end
    return ZO_NORMAL_TEXT
end

---------------------------------------------------------------------------
-- Collection data
---------------------------------------------------------------------------

-- "Fungal Grotto II" -> "Fungal Grotto": removes a trailing part number (Latin I/V/X, digits, the Cyrillic "І",
-- full-width "Ⅰ".."Ⅻ"), with or without a space or no-break space before it. Returns nil when there is none.
local function StripPartNumber(name)
    local base = zo_strformat("<<1>>", name):gsub("\194\160", " "):gsub("%s+$", "")
    local stripped = false
    repeat
        local before = base
        base = base:gsub("[IVX%d]$", ""):gsub("\208\134$", ""):gsub("\226\133[\160-\171]$", "")
        stripped = stripped or base ~= before
    until base == before
    if stripped then
        return (base:gsub("%s+$", ""))
    end
end

-- Finds a dungeon entry by name in a { [normalized name] = entry } map. Two-part dungeons ("Fungal Grotto I" and
-- "Fungal Grotto II") share one Sets book category without the part number, so a name that doesn't match as is
-- is tried again without it.
local function LookupByName(keyMap, name)
    if not name or name == "" then return nil end
    local key = NormalizeName(name)
    if key and keyMap[key] then
        return keyMap[key]
    end
    local base = StripPartNumber(name)
    key = base and NormalizeName(base)
    return key and keyMap[key] or nil
end

-- Every Sets book category that directly holds sets is one dungeon (its monster set included). Dungeon sets are
-- spread over several top-level categories ("Dungeons", "DLC Dungeons", but also trials, arenas...), with dungeons
-- possibly nested in groups. A top-level category that contains dungeons of the Dungeon Finder holds dungeons; the
-- others hold trials and arenas. No category id or localized name is hardcoded.
local function BuildDungeons()
    dungeons, dungeonsByKey, dungeonsBySetId, finderZoneIds = {}, {}, {}, {}
    local manager = ITEM_SET_COLLECTIONS_DATA_MANAGER

    local topVotes, tops = {}, {}
    for _, setData in manager:ItemSetCollectionIterator() do
        if setData:GetSetType() == ITEM_SET_TYPE_DUNGEON then
            local top = setData:GetCategoryData()
            while top and top:GetParentCategoryData() do
                top = top:GetParentCategoryData()
            end
            if top then
                if not topVotes[top] then
                    table.insert(tops, top)
                end
                topVotes[top] = (topVotes[top] or 0) + 1
            end
        end
    end
    table.sort(tops, function(a, b) return a:GetOrder() < b:GetOrder() end)

    -- Entries of each top-level category, in the game's order.
    local entriesByTop, keysByTop = {}, {}
    for _, top in ipairs(tops) do
        local entries, keyMap = {}, {}
        local function Walk(category)
            local entry =
            {
                category = category,
                id = category:GetId(),
                name = category:GetFormattedName(),
                key = NormalizeName(category:GetName()),
                sets = {},
            }
            for _, setData in category:CollectionIterator() do
                table.insert(entry.sets, setData)
            end
            if #entry.sets > 0 then
                table.insert(entries, entry)
                if entry.key and not keyMap[entry.key] then
                    keyMap[entry.key] = entry
                end
            end
            for _, subcategory in category:SubcategoryIterator() do
                Walk(subcategory)
            end
        end
        Walk(top)
        entriesByTop[top], keysByTop[top] = entries, keyMap
    end

    local useTop = {}
    for _, activityType in ipairs({ LFG_ACTIVITY_DUNGEON, LFG_ACTIVITY_MASTER_DUNGEON }) do
        for index = 1, GetNumActivitiesByType(activityType) do
            local zoneId = GetActivityZoneId(GetActivityIdByTypeAndIndex(activityType, index))
            local zoneName = zoneId and zoneId ~= 0 and GetZoneNameById(zoneId)
            local zoneKey = NormalizeName(zoneName)
            if zoneKey then
                finderZoneIds[zoneKey] = zoneId
            end
            for _, top in ipairs(tops) do
                if not useTop[top] and LookupByName(keysByTop[top], zoneName) then
                    useTop[top] = true
                end
            end
        end
    end
    dungeonsProvisional = not next(useTop)
    if dungeonsProvisional then
        -- Fallback (Dungeon Finder data not available yet): the top-level category with the most dungeon sets.
        -- The result is not kept, so the list is built again the next time it is needed.
        local best, bestVotes = nil, 0
        for _, top in ipairs(tops) do
            if topVotes[top] > bestVotes then
                best, bestVotes = top, topVotes[top]
            end
        end
        if best then useTop[best] = true end
    end

    for _, top in ipairs(tops) do
        -- Trials and arenas only once the dungeons are known for sure.
        if useTop[top] or not dungeonsProvisional then
            for _, entry in ipairs(entriesByTop[top]) do
                entry.isDungeon = useTop[top] or false
                -- Two categories with the same name are treated as one dungeon, so no set is lost.
                local existing = entry.key and dungeonsByKey[entry.key]
                if existing then
                    existing.isDungeon = existing.isDungeon or entry.isDungeon
                    for _, setData in ipairs(entry.sets) do
                        table.insert(existing.sets, setData)
                    end
                else
                    table.insert(dungeons, entry)
                    if entry.key then
                        dungeonsByKey[entry.key] = entry
                    end
                end
                local owner = existing or entry
                for _, setData in ipairs(entry.sets) do
                    dungeonsBySetId[setData:GetId()] = owner
                end
            end
        end
    end

    -- A place may also have its sets in subcategories with other names (the Infinite Archive): its top-level
    -- category's name then finds all of them. Only looked up by name, not listed with the dungeons.
    if not dungeonsProvisional then
        for _, top in ipairs(tops) do
            local key = NormalizeName(top:GetName())
            if not useTop[top] and key and not dungeonsByKey[key] then
                local entry = { category = top, id = top:GetId(), name = top:GetFormattedName(), key = key, isDungeon = false, sets = {} }
                for _, subEntry in ipairs(entriesByTop[top]) do
                    for _, setData in ipairs(subEntry.sets) do
                        table.insert(entry.sets, setData)
                    end
                end
                dungeonsByKey[key] = entry
            end
        end
    end
end

local function GetDungeons()
    if not dungeons or dungeonsProvisional then
        BuildDungeons()
    end
    return dungeons
end

local function FindDungeonByName(name)
    GetDungeons()
    return LookupByName(dungeonsByKey, name)
end

local function FindDungeonByZoneId(zoneId)
    if not zoneId or zoneId == 0 then return nil end
    return FindDungeonByName(GetZoneNameById(zoneId))
end

-- A dungeon counts only inside an instance; trials and arenas are found by their zone name alone.
local function FindCurrentDungeon(zoneId)
    local dungeon = FindDungeonByZoneId(zoneId) or FindDungeonByName(GetUnitZone("player"))
    if dungeon and (IsUnitInDungeon("player") or not dungeon.isDungeon) then
        return dungeon
    end
end

-- Both parts of a two-part dungeon share one Sets book category, but each part has its own monster set. With the
-- optional library LibSets (by Baertram) installed, monster sets that LibSets says drop elsewhere are left out.
-- Other sets are always kept, and without LibSets (or without data for a set, e.g. while LibSets is still scanning
-- right after login) nothing is filtered; the next hover then shows the filtered result.
local function MonsterSetDropsInZone(setData, zoneId)
    if not (zoneId and LibSets) or setData:GetSetType() ~= ITEM_SET_TYPE_MONSTER then
        return true
    end
    local zoneIds = LibSets.GetZoneIds(setData:GetId())
    if ZO_IsTableEmpty(zoneIds) then
        return true
    end
    for _, dropZoneId in pairs(zoneIds) do
        if dropZoneId == zoneId then
            return true
        end
    end
    return false
end

local function GetZoneSets(dungeon, zoneId)
    local sets = {}
    for _, setData in ipairs(dungeon.sets) do
        if MonsterSetDropsInZone(setData, zoneId) then
            table.insert(sets, setData)
        end
    end
    -- Never show an empty dungeon because of the filter (e.g. incomplete LibSets data): show everything instead.
    if #sets == 0 then
        return dungeon.sets
    end
    return sets
end

---------------------------------------------------------------------------
-- Zone sets: the overland sets of an open zone (they drop all over the zone: delves, public dungeons, world
-- bosses, chests), shown by an icon on the zone's map
---------------------------------------------------------------------------

local zonesByKey            -- [normalized Sets book category name] = zone entry, for categories of overland sets
local zonesByZoneId = {}    -- [zoneId] = zone entry already found for a map

local function BuildZones()
    zonesByKey = {}
    for _, setData in ITEM_SET_COLLECTIONS_DATA_MANAGER:ItemSetCollectionIterator() do
        if setData:GetSetType() == ITEM_SET_TYPE_WORLD then
            local category = setData:GetCategoryData()
            local key = NormalizeName(category:GetName())
            if key then
                local entry = zonesByKey[key]
                if not entry then
                    entry = { category = category, id = category:GetId(), name = category:GetFormattedName(), key = key, sets = {} }
                    zonesByKey[key] = entry
                end
                table.insert(entry.sets, setData)
            end
        end
    end
end

-- When no category has the zone's name (e.g. one named after its chapter), LibSets tells where overland sets drop.
local function FindZoneSetsWithLibSets(zoneId, zoneName)
    if not LibSets then return nil end
    local entry = { id = zoneId, name = zo_strformat(SI_ZONE_NAME, zoneName), sets = {} }
    for _, setData in ITEM_SET_COLLECTIONS_DATA_MANAGER:ItemSetCollectionIterator() do
        if setData:GetSetType() == ITEM_SET_TYPE_WORLD then
            for _, dropZoneId in pairs(LibSets.GetZoneIds(setData:GetId()) or {}) do
                if dropZoneId == zoneId then
                    table.insert(entry.sets, setData)
                    break
                end
            end
        end
    end
    if #entry.sets > 0 then
        return entry
    end
end

-- The zone of the map shown, if it is an open zone with overland sets. Not for the world map, nor for the maps of
-- dungeons, delves, trials, arenas and the like: those have their own sets or none.
local function FindMapZone()
    local mapType = GetMapType()
    if mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC or GetMapContentType() == MAP_CONTENT_DUNGEON then
        return nil
    end
    local zoneId = GetZoneId(GetCurrentMapZoneIndex())
    if zoneId == 0 then return nil end
    if not zonesByZoneId[zoneId] then
        if not zonesByKey then
            BuildZones()
        end
        local zoneName = GetZoneNameById(zoneId)
        zonesByZoneId[zoneId] = LookupByName(zonesByKey, zoneName) or FindZoneSetsWithLibSets(zoneId, zoneName)
    end
    return zonesByZoneId[zoneId]
end

local function SumPieces(sets)
    local unlocked, total = 0, 0
    for _, setData in ipairs(sets) do
        unlocked, total = unlocked + setData:GetNumUnlockedPieces(), total + setData:GetNumPieces()
    end
    return unlocked, total
end

local function CreateProgressBar(name, parent, width, height)
    local bar = CreateControlFromVirtual(name, parent, "ZO_ArrowProgressBarWithBG")
    bar:SetDimensions(width, height)
    bar.progress = bar:GetNamedChild("Progress")
    ZO_StatusBar_SetGradientColor(bar, ZO_XP_BAR_GRADIENT_COLORS)
    return bar
end

local function SetProgress(bar, unlocked, total)
    bar:SetMinMax(0, zo_max(total, 1))
    bar:SetValue(unlocked)
    bar.progress:SetText(FormatCount(unlocked, total))
end

---------------------------------------------------------------------------
-- Dungeon panel (HUD), styled like the set chart: title, total progress, one line with a progress bar per set
---------------------------------------------------------------------------

local PANEL_WIDTH = 340
local PANEL_PADDING = 10
local PANEL_TITLE_HEIGHT = 26
local PANEL_LINE_HEIGHT = 24
local PANEL_BAR_WIDTH = 92
local PANEL_BAR_HEIGHT = 16

local function GetPanelLine(index)
    local line = ui.panelLines[index]
    if not line then
        line = CreateControlFromVirtual("$(parent)Line", ui.panel, "DungeonSetTracker_PanelLine", index)
        line:SetHeight(PANEL_LINE_HEIGHT)
        line.name = line:GetNamedChild("Name")
        line.bar = CreateProgressBar("$(parent)Bar", line, PANEL_BAR_WIDTH, PANEL_BAR_HEIGHT)
        line.bar:SetAnchor(RIGHT, line, RIGHT, 0, 0)
        line.name:SetAnchor(RIGHT, line.bar, LEFT, -8, 0)
        local y = PANEL_PADDING + PANEL_TITLE_HEIGHT + PANEL_LINE_HEIGHT + (index - 1) * PANEL_LINE_HEIGHT
        line:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, PANEL_PADDING, y)
        line:SetAnchor(TOPRIGHT, ui.panel, TOPRIGHT, -PANEL_PADDING, y)
        ui.panelLines[index] = line
    end
    return line
end

local function RefreshPanel()
    if not ui.panel then return end
    local dungeon = currentDungeon
    local show = sv.showPanel and dungeon ~= nil
    ui.panelFragment:SetHiddenForReason("disabled", not show)
    if not show then return end

    local sets = GetZoneSets(dungeon, currentZoneId)
    ui.panelTitle:SetText(dungeon.name)
    SetProgress(ui.panelTotal, SumPieces(sets))

    local index = 0
    for _, setData in ipairs(sets) do
        local su, st = setData:GetNumUnlockedPieces(), setData:GetNumPieces()
        if not (sv.panelHideCompleted and su >= st) then
            index = index + 1
            local line = GetPanelLine(index)
            line.name:SetText(setData:GetFormattedName())
            line.name:SetColor(ProgressColor(su, st):UnpackRGBA())
            SetProgress(line.bar, su, st)
            line:SetHidden(false)
        end
    end
    for i = index + 1, #ui.panelLines do
        ui.panelLines[i]:SetHidden(true)
    end
    ui.panel:SetHeight(2 * PANEL_PADDING + PANEL_TITLE_HEIGHT + PANEL_LINE_HEIGHT + index * PANEL_LINE_HEIGHT)
end

local function ApplyPanelSettings()
    ui.panel:SetMovable(not sv.panelLocked)
    ui.panel:SetMouseEnabled(not sv.panelLocked)
    ui.panel:SetScale(sv.panelScale / 100)
end

-- The position is kept as an offset from the screen center, so it stays sensible after a resolution change.
local function AnchorPanel()
    ui.panel:ClearAnchors()
    if sv.panelPos and sv.panelPos.x and sv.panelPos.y then
        ui.panel:SetAnchor(CENTER, GuiRoot, CENTER, sv.panelPos.x, sv.panelPos.y)
    else
        ui.panel:SetAnchor(RIGHT, GuiRoot, RIGHT, -40, 0)
    end
end

local function CreatePanel()
    local panel = DungeonSetTrackerPanel
    ui.panel = panel
    panel:SetWidth(PANEL_WIDTH)
    ui.panelTitle = panel:GetNamedChild("Title")
    ui.panelTitle:SetAnchor(TOPLEFT, panel, TOPLEFT, PANEL_PADDING, PANEL_PADDING)
    ui.panelTitle:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -PANEL_PADDING, PANEL_PADDING)
    ui.panelTotal = CreateProgressBar("$(parent)Total", panel, PANEL_WIDTH - 2 * PANEL_PADDING, PANEL_BAR_HEIGHT)
    ui.panelTotal:SetAnchor(TOPLEFT, panel, TOPLEFT, PANEL_PADDING, PANEL_PADDING + PANEL_TITLE_HEIGHT)
    ui.panelLines = {}

    AnchorPanel()
    ApplyPanelSettings()
    panel:SetHandler("OnMoveStop", function()
        local x, y = panel:GetCenter()
        local cx, cy = GuiRoot:GetCenter()
        sv.panelPos = { x = x - cx, y = y - cy }
    end)

    -- The fragment shows the panel only on the HUD (not in menus), and only while a reason doesn't hide it.
    ui.panelFragment = ZO_HUDFadeSceneFragment:New(panel)
    ui.panelFragment:SetHiddenForReason("disabled", true)
    HUD_SCENE:AddFragment(ui.panelFragment)
    HUD_UI_SCENE:AddFragment(ui.panelFragment)
end

---------------------------------------------------------------------------
-- Set chart in the Dungeon Finder
---------------------------------------------------------------------------

-- Styled like the game's own Sets collection: every piece in a slot frame, in color with a green frame when
-- collected, as a dark silhouette when missing. Title: dungeon, total progress bar, divider.
-- Shown at a fixed place while a dungeon is hovered. Sets in two columns; per set: name and progress bar,
-- then rows of up to 7 icons: light, medium and heavy armor (one row each), then jewelry, shield and weapons.
-- All sizes are defined here; the XML only declares the controls.
local NUM_COLUMNS = 2
local ICONS_PER_ROW = 7
local CELL_SIZE = 32
local CELL_STEP = 34
local TIP_PADDING = 16
local TITLE_HEIGHT = 74         -- title, total progress bar and divider
local TOTAL_BAR_HEIGHT = 20
local HEADER_HEIGHT = 48        -- fixed: room for a set name on two lines, so nothing moves between dungeons
local SET_BAR_WIDTH = 92
local SET_BAR_HEIGHT = 18
local SET_GAP = 14
local COLUMN_GAP = 20
local GRID_WIDTH = ICONS_PER_ROW * CELL_STEP
-- Window size: room for two rows of sets (four sets); with fewer the rest of the window stays empty, so nothing
-- moves between dungeons. Places with more sets (arenas, trials) get a taller window with icons of the same size.
-- The legend always sits at the bottom.
local CONTENT_TOP = TIP_PADDING + TITLE_HEIGHT
local CONTENT_HEIGHT = 2 * (HEADER_HEIGHT + 5 * CELL_STEP) + SET_GAP
local LEGEND_AREA = 34
local HINT_HEIGHT = 36          -- the Shift hint under the legend, up to two lines
local TIP_WIDTH = 2 * TIP_PADDING + NUM_COLUMNS * GRID_WIDTH + (NUM_COLUMNS - 1) * COLUMN_GAP
local TIP_HEIGHT = CONTENT_TOP + CONTENT_HEIGHT + LEGEND_AREA + HINT_HEIGHT + TIP_PADDING
local PREVIEW_DURATION_MS = 4000
local PREVIEW_GAP = 10          -- distance from the game's dungeon preview in the "next to the preview" position
local FADE_IN_MS = 120
local KEEP_CHECK_MS = 100       -- while Shift keeps the chart open: how often to check whether it can hide
local ARMOR_ROWS =
{
    [EQUIPMENT_FILTER_TYPE_LIGHT] = 1,
    [EQUIPMENT_FILTER_TYPE_MEDIUM] = 2,
    [EQUIPMENT_FILTER_TYPE_HEAVY] = 3,
}
local OTHER_ORDER =
{
    [EQUIPMENT_FILTER_TYPE_NECK] = 1,
    [EQUIPMENT_FILTER_TYPE_RING] = 2,
    [EQUIPMENT_FILTER_TYPE_SHIELD] = 3,
    [EQUIPMENT_FILTER_TYPE_ONE_HANDED] = 4,
    [EQUIPMENT_FILTER_TYPE_TWO_HANDED] = 5,
    [EQUIPMENT_FILTER_TYPE_BOW] = 6,
    [EQUIPMENT_FILTER_TYPE_DESTRO_STAFF] = 7,
    [EQUIPMENT_FILTER_TYPE_RESTO_STAFF] = 8,
}
local COLLECTED_FRAME = ZO_ColorDef:New(0.35, 0.9, 0.35, 1)
local MISSING_FRAME = ZO_ColorDef:New(0.55, 0.55, 0.55, 1)
local PERFECTED_FRAME = ZO_ColorDef:New(0.95, 0.75, 0.25, 1)
local PERFECTED_MISSING_FRAME = ZO_ColorDef:New(0.6, 0.48, 0.2, 1)
local FALLBACK_ICON = "EsoUI/Art/Icons/crafing_universal_item.dds"

-- Rows of icons for one set: { { pieceData, ... }, ... }, armor rows first, then the rest wrapped at 7.
local function LayoutPieces(setData)
    local armor, others = { {}, {}, {} }, {}
    local index = 0
    for _, pieceData in setData:PieceIterator() do
        index = index + 1
        local filterType = pieceData:GetEquipmentFilterType()
        local armorRow = ARMOR_ROWS[filterType]
        if armorRow then
            table.insert(armor[armorRow], pieceData)
        else
            table.insert(others, { piece = pieceData, order = OTHER_ORDER[filterType] or 99, index = index })
        end
    end
    table.sort(others, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)

    local rows = {}
    for _, pieces in ipairs(armor) do
        for first = 1, #pieces, ICONS_PER_ROW do
            table.insert(rows, { unpack(pieces, first, zo_min(first + ICONS_PER_ROW - 1, #pieces)) })
        end
    end
    local row
    for i, entry in ipairs(others) do
        if (i - 1) % ICONS_PER_ROW == 0 then
            row = {}
            table.insert(rows, row)
        end
        table.insert(row, entry.piece)
    end
    return rows
end

-- A set and its perfected version (arenas, trials) form one block: the set's rows, then the perfected rows.
-- Returns { { setData, perfected = setData or nil, unlocked, total }, ... } in the order of the sets.
local function GroupPerfectedSets(sets)
    local blocks, blocksBySetId = {}, {}
    for _, setData in ipairs(sets) do
        local block = { setData = setData, unlocked = setData:GetNumUnlockedPieces(), total = setData:GetNumPieces() }
        table.insert(blocks, block)
        blocksBySetId[setData:GetId()] = block
    end
    local grouped = {}
    for _, block in ipairs(blocks) do
        local base = blocksBySetId[block.setData:GetUnperfectedSetId()]
        if base then
            base.perfected = block.setData
            base.unlocked, base.total = base.unlocked + block.unlocked, base.total + block.total
        else
            table.insert(grouped, block)
        end
    end
    return grouped
end

local function SetCell(cell, icon, collected, perfected)
    local frame
    if perfected then
        frame = collected and PERFECTED_FRAME or PERFECTED_MISSING_FRAME
    else
        frame = collected and COLLECTED_FRAME or MISSING_FRAME
    end
    cell.frame:SetColor(frame:UnpackRGBA())
    cell.icon:SetTexture(icon)
    -- Same look as an uncollected piece in the game's Sets collection.
    ZO_SetDefaultIconSilhouette(cell.icon, not collected)
end

local function InitCell(cell)
    cell:SetDimensions(CELL_SIZE, CELL_SIZE)
    cell.icon = cell:GetNamedChild("Icon")
    cell.frame = cell:GetNamedChild("Frame")
    return cell
end

-- Pointing at a piece shows it like the game's Sets collection does. The mouse reaches the chart while Shift keeps
-- it open.
local function OnCellMouseEnter(cell)
    if not cell.pieceData then return end
    ClearTooltip(ItemTooltip)
    if cell:GetCenter() < GuiRoot:GetWidth() / 2 then
        InitializeTooltip(ItemTooltip, cell, LEFT, 5, 0, RIGHT)
    else
        InitializeTooltip(ItemTooltip, cell, RIGHT, -5, 0, LEFT)
    end
    local HIDE_TRAIT = true
    ItemTooltip:SetItemSetCollectionPieceLink(cell.pieceData:GetItemLink(), HIDE_TRAIT)
    ui.pieceTooltipShown = true
end

local function OnCellMouseExit()
    if ui.pieceTooltipShown then
        ClearTooltip(ItemTooltip)
        ui.pieceTooltipShown = false
    end
end

local function AcquireChartControl(list, index, template, suffix)
    local control = list[index]
    if not control then
        local content = ui.chart.content
        if template == "Bar" then
            control = CreateProgressBar("$(parent)" .. suffix .. index, content, SET_BAR_WIDTH, SET_BAR_HEIGHT)
        else
            control = CreateControlFromVirtual("$(parent)" .. suffix, content, template, index)
            if template == "DungeonSetTracker_ChartCell" then
                InitCell(control)
                control:SetMouseEnabled(true)
                control:SetHandler("OnMouseEnter", OnCellMouseEnter)
                control:SetHandler("OnMouseExit", OnCellMouseExit)
            end
        end
        list[index] = control
    end
    control:SetHidden(false)
    return control
end

local function HideUnused(list, used)
    for i = used + 1, #list do
        list[i]:SetHidden(true)
    end
end

local function PlaceChart(chart, height)
    chart:ClearAnchors()
    local preview = ZO_ActivityFinderTemplateTooltip_Keyboard
    if sv.tipSide == "preview" and not preview:IsHidden() then
        -- Next to the game's dungeon preview (its frame reaches 2px further left); the vertical position setting
        -- still applies, the distance setting does not.
        chart:SetAnchor(TOPRIGHT, preview, TOPLEFT, -2 - PREVIEW_GAP, sv.tipOffsetY)
    elseif sv.tipSide == "right" then
        chart:SetAnchor(RIGHT, GuiRoot, RIGHT, -sv.tipOffsetX, sv.tipOffsetY)
    else
        chart:SetAnchor(LEFT, GuiRoot, LEFT, sv.tipOffsetX, sv.tipOffsetY)
    end
    -- The chosen size, but never larger than the screen.
    local scale = sv.tipScale / 100
    scale = zo_min(scale, (GuiRoot:GetHeight() - 20) / height, (GuiRoot:GetWidth() - 20) / TIP_WIDTH)
    chart:SetScale(scale)
end

-- isNormalDifficulty: hovering the normal version of a dungeon, where monster sets don't drop (their helms drop
-- on veteran only); their names get the veteran icon.
local function ShowSetChart(dungeon, zoneId, isNormalDifficulty)
    local chart = ui.chart
    local content = chart.content
    local numLabels, numCells, numBars = 0, 0, 0
    chart.shown = { dungeon = dungeon, zoneId = zoneId, isNormalDifficulty = isNormalDifficulty }

    local function AddLabel(text, color, x, y, labelWidth)
        numLabels = numLabels + 1
        local label = AcquireChartControl(chart.labels, numLabels, "DungeonSetTracker_ChartLabel", "Label")
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT, content, TOPLEFT, x, y)
        label:SetDimensions(labelWidth, HEADER_HEIGHT - 4)
        label:SetText(text)
        label:SetColor(color:UnpackRGBA())
        return label
    end

    local allSets = GetZoneSets(dungeon, zoneId)
    local blocks = {}
    for _, block in ipairs(GroupPerfectedSets(allSets)) do
        if not (sv.tipHideCompleted and block.unlocked >= block.total) then
            table.insert(blocks, block)
        end
    end

    -- Long dungeon names get a smaller font instead of being cut off.
    chart.title:SetFont("ZoFontWinH2")
    chart.title:SetText(dungeon.name)
    if chart.title:GetTextWidth() > TIP_WIDTH - 2 * TIP_PADDING then
        chart.title:SetFont("ZoFontWinH3")
    end
    SetProgress(chart.totalBar, SumPieces(allSets))

    local markedVeteran, markedPerfected = false, false
    local y = 0
    local rowHeight = 0
    for rowStart = 1, #blocks, NUM_COLUMNS do
        if rowStart > 1 then
            y = y + rowHeight + SET_GAP
        end
        -- Every set header has the same fixed height, with name and progress bar centered in it, so names,
        -- bars and icons always stay at the same place whatever the length of the names.
        local rowBlocks = {}
        for column = 0, NUM_COLUMNS - 1 do
            local block = blocks[rowStart + column]
            if block then
                local setData = block.setData
                local x = TIP_PADDING + column * (GRID_WIDTH + COLUMN_GAP)
                local su, st = block.unlocked, block.total
                local name = setData:GetFormattedName()
                if isNormalDifficulty and setData:GetSetType() == ITEM_SET_TYPE_MONSTER then
                    name = zo_iconTextFormat(ZO_GetVeteranIcon(), 20, 20, name)
                    markedVeteran = true
                end
                AddLabel(name, ProgressColor(su, st), x, y, GRID_WIDTH - SET_BAR_WIDTH - 8)
                numBars = numBars + 1
                local bar = AcquireChartControl(chart.bars, numBars, "Bar", "Bar")
                bar:ClearAnchors()
                bar:SetAnchor(TOPRIGHT, content, TOPLEFT, x + GRID_WIDTH - 4, y + (HEADER_HEIGHT - 4 - SET_BAR_HEIGHT) / 2)
                SetProgress(bar, su, st)
                table.insert(rowBlocks, { block = block, x = x })
            end
        end

        rowHeight = 0
        for _, entry in ipairs(rowBlocks) do
            local rows = {}
            for _, pieces in ipairs(LayoutPieces(entry.block.setData)) do
                table.insert(rows, { pieces = pieces })
            end
            if entry.block.perfected then
                for _, pieces in ipairs(LayoutPieces(entry.block.perfected)) do
                    table.insert(rows, { pieces = pieces, perfected = true })
                end
                markedPerfected = true
            end
            for rowIndex, row in ipairs(rows) do
                local cellY = y + HEADER_HEIGHT + (rowIndex - 1) * CELL_STEP
                for i, pieceData in ipairs(row.pieces) do
                    numCells = numCells + 1
                    local cell = AcquireChartControl(chart.cells, numCells, "DungeonSetTracker_ChartCell", "Cell")
                    cell:ClearAnchors()
                    cell:SetAnchor(TOPLEFT, content, TOPLEFT, entry.x + (i - 1) * CELL_STEP, cellY)
                    cell.pieceData = pieceData
                    SetCell(cell, pieceData:GetIcon(), pieceData:IsUnlocked(), row.perfected)
                end
            end
            rowHeight = zo_max(rowHeight, HEADER_HEIGHT + #rows * CELL_STEP)
        end
    end
    if #blocks == 0 then
        AddLabel(L.ALL_COLLECTED, ZO_SUCCEEDED_TEXT, TIP_PADDING, y, TIP_WIDTH - 2 * TIP_PADDING)
        rowHeight = HEADER_HEIGHT
    end
    HideUnused(chart.labels, numLabels)
    HideUnused(chart.cells, numCells)
    HideUnused(chart.bars, numBars)
    -- More sets than the window holds: the window grows (PlaceChart keeps it within the screen).
    local contentHeight = zo_max(CONTENT_HEIGHT, y + rowHeight)
    local height = TIP_HEIGHT + contentHeight - CONTENT_HEIGHT
    content:SetHeight(contentHeight)
    chart:SetHeight(height)

    -- Legend with a real piece of this dungeon: in color for "collected", as a silhouette for "missing".
    local legend = chart.legend
    legend:SetHidden(not sv.tipShowLegend)
    chart.hint:SetHidden(not sv.tipShowLegend)
    local sampleIcon = FALLBACK_ICON
    if dungeon.sets[1] then
        for _, pieceData in dungeon.sets[1]:PieceIterator() do
            sampleIcon = pieceData:GetIcon()
            break
        end
    end
    SetCell(legend.have, sampleIcon, true)
    SetCell(legend.missing, sampleIcon, false)
    SetCell(legend.perfected, sampleIcon, true, true)
    legend.perfected:SetHidden(not markedPerfected)
    legend.perfectedText:SetHidden(not markedPerfected)
    legend.veteran:SetHidden(not markedVeteran)
    legend.veteran:ClearAnchors()
    legend.veteran:SetAnchor(LEFT, markedPerfected and legend.perfectedText or legend.missingText, RIGHT, 20, 0)

    chart.bg:SetAlpha(sv.tipBgAlpha / 100)
    PlaceChart(chart, height)
    if chart:IsHidden() then
        chart.fade:FadeIn(0, FADE_IN_MS)
    end
end

-- Shift keeps a chart shown by hovering open after the dungeon is no longer hovered, so the mouse can reach it.
local KEEP_UPDATE_NAME = DST.name .. "KeepChart"
local hoverActive = false   -- the Dungeon Finder entry or map pin that showed the chart is still hovered

local function HideSetChart()
    local chart = ui.chart
    EVENT_MANAGER:UnregisterForUpdate(KEEP_UPDATE_NAME)
    hoverActive = false
    OnCellMouseExit()
    chart.fade:Stop()
    chart:SetHidden(true)
    chart.shown = nil
    chart.source = nil  -- what showed the chart: "finder", "map", "zone" or "preview"
end

local function IsChartKept()
    return IsShiftKeyDown() or MouseIsOver(ui.chart)
end

-- A chart kept open with Shift (or with the mouse on it) is not replaced by other dungeons the mouse passes.
local function IsChartFrozen()
    local source = ui.chart.source
    return (source == "finder" or source == "map" or source == "zone") and IsChartKept()
end

local function CheckKeptChart()
    if not (hoverActive or IsChartKept()) then
        HideSetChart()
    end
end

-- The hovered dungeon is left: the chart hides, unless Shift or the mouse on the chart keeps it open.
local function ReleaseSetChart()
    hoverActive = false
    if ui.chart:IsHidden() then return end
    if IsChartKept() then
        EVENT_MANAGER:RegisterForUpdate(KEEP_UPDATE_NAME, KEEP_CHECK_MS, CheckKeptChart)
    else
        HideSetChart()
    end
end

local function ShowHoveredChart(dungeon, zoneId, isNormalDifficulty, source)
    EVENT_MANAGER:UnregisterForUpdate(KEEP_UPDATE_NAME)
    ShowSetChart(dungeon, zoneId, isNormalDifficulty)
    ui.chart.source = source
    hoverActive = true
end

local function RefreshSetChart()
    local chart = ui.chart
    if chart.shown and not chart:IsHidden() then
        ShowSetChart(chart.shown.dungeon, chart.shown.zoneId, chart.shown.isNormalDifficulty)
    end
end

-- Shows the chart for a few seconds while its settings are changed. The dungeon with the most sets is used,
-- so every part of the chart is visible.
local previewToken = 0
local function PreviewSetChart()
    if not (sv.finderTooltip or sv.mapTooltip or sv.mapZoneButton) then
        HideSetChart()
        return
    end
    local example
    for _, dungeon in ipairs(GetDungeons()) do
        if not example or #dungeon.sets > #example.sets then
            example = dungeon
        end
    end
    if not example then return end
    ShowSetChart(example)
    ui.chart.source = "preview"
    previewToken = previewToken + 1
    local token = previewToken
    zo_callLater(function()
        if token == previewToken then
            HideSetChart()
        end
    end, PREVIEW_DURATION_MS)
end

local function OnFinderEntryMouseEnter(control)
    if IsChartFrozen() then return end
    HideSetChart()
    if not sv.finderTooltip then return end
    local data = control.node.data
    -- Only single activities have one zone; "random dungeon" entries (activity sets) are left out.
    if not data:IsSpecificEntryType() then
        return
    end
    local zoneId = data:GetZoneId()
    local dungeon = FindDungeonByZoneId(zoneId) or FindDungeonByName(data:GetRawName())
    if dungeon then
        local isNormal = data:GetActivityType() == LFG_ACTIVITY_DUNGEON
        ShowHoveredChart(dungeon, zoneId, isNormal, "finder")
    end
end

-- World map: dungeons, trials and arenas are fast travel nodes, or points of interest before they are discovered.
-- Matched by name like the Dungeon Finder; the result per pin name is kept until the list is rebuilt.
local mapPinDungeons = {}   -- [pin name] = dungeon entry, or false

local function GetMapPinName(pin)
    if pin:IsFastTravelWayShrine() then
        local _, name = GetFastTravelNodeInfo(pin:GetFastTravelNodeIndex())
        return name
    elseif pin:IsPOI() then
        return (GetPOIInfo(pin:GetPOIZoneIndex(), pin:GetPOIIndex()))
    end
end

-- Pin names have a prefix: "Dungeon: Fungal Grotto I", "Подземелье: пещеры Глубокой Тени I". Returns the part after
-- the first colon (also the full-width "：" of Japanese and Chinese), or nil when there is none.
local function StripMapPinPrefix(name)
    return name:match("^.-:%s*(.+)$") or name:match("^.-\239\188\154%s*(.+)$")
end

local function FindMapPinDungeon(pin)
    local name = GetMapPinName(pin)
    if not name or name == "" then return nil end
    local entry = mapPinDungeons[name]
    if entry == nil then
        local placeName = name
        local dungeon = FindDungeonByName(name)
        if not dungeon then
            placeName = StripMapPinPrefix(name)
            dungeon = placeName and FindDungeonByName(placeName)
        end
        -- Part I and II of a two-part dungeon are separate pins: the zone id selects the part's monster set.
        entry = dungeon and { dungeon = dungeon, zoneId = finderZoneIds[NormalizeName(placeName)] } or false
        if not dungeonsProvisional then
            mapPinDungeons[name] = entry
        end
    end
    if entry then
        return entry.dungeon, entry.zoneId
    end
end

-- Called by the world map after it laid out the tooltip for the pins under the mouse.
local function OnMapPinTooltipsUpdated()
    if not sv.mapTooltip or IsInGamepadPreferredMode() then return end
    local chart = ui.chart
    for _, pin in ipairs(WORLD_MAP_MANAGER:GetFoundTooltipMouseOverPins()) do
        local dungeon, zoneId = FindMapPinDungeon(pin)
        if dungeon then
            if chart.source == "map" and chart.shown.dungeon == dungeon and chart.shown.zoneId == zoneId then
                EVENT_MANAGER:UnregisterForUpdate(KEEP_UPDATE_NAME)
                hoverActive = true
            elseif not IsChartFrozen() then
                ShowHoveredChart(dungeon, zoneId, nil, "map")
            end
            return
        end
    end
    if chart.source == "map" then
        ReleaseSetChart()
    end
end

local function OnMapTooltipHidden()
    if ui.chart.source == "map" then
        ReleaseSetChart()
    end
end

-- Icon in the top left corner of an open zone's map: pointing at it shows the zone's sets.
local ZONE_BUTTON_SIZE = 40
local mapZone               -- zone entry of the map shown, while the icon is shown

local function RefreshZoneButton()
    mapZone = sv.mapZoneButton and not IsInGamepadPreferredMode() and FindMapZone() or nil
    ui.zoneButton:SetHidden(not mapZone)
end

local function OnZoneButtonMouseEnter()
    if mapZone and not IsChartFrozen() then
        HideSetChart()
        ShowHoveredChart(mapZone, nil, nil, "zone")
    end
end

local function OnZoneButtonMouseExit()
    if ui.chart.source == "zone" then
        ReleaseSetChart()
    end
end

local function CreateZoneButton()
    local button = CreateControlFromVirtual("DungeonSetTrackerZoneButton", ZO_WorldMap, "DungeonSetTracker_ZoneButton")
    ui.zoneButton = button
    button:SetDimensions(ZONE_BUTTON_SIZE, ZONE_BUTTON_SIZE)
    button:SetAnchor(TOPLEFT, ZO_WorldMapScroll, TOPLEFT, 8, 8)
    button:SetHandler("OnMouseEnter", OnZoneButtonMouseEnter)
    button:SetHandler("OnMouseExit", OnZoneButtonMouseExit)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", RefreshZoneButton)
    WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            RefreshZoneButton()
        end
    end)
end

local function CreateSetChart()
    local chart = DungeonSetTrackerChart
    ui.chart = chart
    chart:SetDimensions(TIP_WIDTH, TIP_HEIGHT)
    chart.bg = chart:GetNamedChild("Bg")
    chart.fade = ZO_AlphaAnimation:New(chart)

    chart.title = chart:GetNamedChild("Title")
    chart.title:SetAnchor(TOPLEFT, chart, TOPLEFT, TIP_PADDING, 10)
    chart.title:SetAnchor(TOPRIGHT, chart, TOPRIGHT, -TIP_PADDING, 10)
    chart.totalBar = CreateProgressBar("$(parent)TotalBar", chart, TIP_WIDTH - 2 * TIP_PADDING, TOTAL_BAR_HEIGHT)
    chart.totalBar:SetAnchor(TOPLEFT, chart.title, BOTTOMLEFT, 0, 6)
    local divider = chart:GetNamedChild("Divider")
    divider:SetAnchor(TOPLEFT, chart.totalBar, BOTTOMLEFT, -TIP_PADDING, 6)
    divider:SetAnchor(TOPRIGHT, chart.totalBar, BOTTOMRIGHT, TIP_PADDING, 6)

    chart.content = chart:GetNamedChild("Content")
    chart.content:SetAnchor(TOP, chart, TOP, 0, CONTENT_TOP)
    chart.content:SetDimensions(TIP_WIDTH, CONTENT_HEIGHT)
    chart.labels, chart.cells, chart.bars = {}, {}, {}

    chart.hint = chart:GetNamedChild("Hint")
    chart.hint:SetDimensions(TIP_WIDTH - 2 * TIP_PADDING, HINT_HEIGHT)
    chart.hint:SetAnchor(BOTTOMLEFT, chart, BOTTOMLEFT, TIP_PADDING, -TIP_PADDING)
    chart.hint:SetText(L.HINT_KEEP_OPEN)

    local legend = chart:GetNamedChild("Legend")
    chart.legend = legend
    legend:SetDimensions(TIP_WIDTH - 2 * TIP_PADDING, LEGEND_AREA - 10)
    legend:SetAnchor(BOTTOMLEFT, chart.hint, TOPLEFT, 0, 0)
    legend.have = InitCell(legend:GetNamedChild("Have"))
    legend.missing = InitCell(legend:GetNamedChild("Missing"))
    legend.perfected = InitCell(legend:GetNamedChild("Perfected"))
    legend.have:SetDimensions(22, 22)
    legend.missing:SetDimensions(22, 22)
    legend.perfected:SetDimensions(22, 22)
    legend:GetNamedChild("HaveText"):SetText(L.LEGEND_HAVE)
    legend.missingText = legend:GetNamedChild("MissingText")
    legend.missingText:SetText(L.LEGEND_MISSING)
    legend.perfectedText = legend:GetNamedChild("PerfectedText")
    legend.perfectedText:SetText(L.LEGEND_PERFECTED)
    legend.veteran = legend:GetNamedChild("Veteran")
    legend.veteran:SetText(zo_iconTextFormat(ZO_GetVeteranIcon(), 20, 20, L.LEGEND_VETERAN_ONLY))

    -- The keyboard Activity Finder calls these when the mouse enters/leaves a list entry.
    -- Post-hooks only add our own chart; the game's behaviour and preview are not changed.
    ZO_PostHook(ZO_ActivityFinderTemplate_Keyboard, "ShowActivityTooltip", OnFinderEntryMouseEnter)
    ZO_PostHook(ZO_ActivityFinderTemplate_Keyboard, "HideActivityTooltip", ReleaseSetChart)
    -- The world map lays out the keyboard tooltip of the pins under the mouse; its own tooltip is not changed.
    ZO_PostHook(WORLD_MAP_MANAGER, "UpdatePinTooltips", OnMapPinTooltipsUpdated)
    CALLBACK_MANAGER:RegisterCallback("OnHideWorldMapTooltip", OnMapTooltipHidden)
    CreateZoneButton()
    -- Safety net: closing a menu (e.g. with Esc) while a dungeon is hovered never leaves the chart on screen.
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(_, _, newState)
        if newState == SCENE_HIDING then
            HideSetChart()
        end
    end)
end

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------

local function PrintDungeonSummary(dungeon, zoneId)
    local sets = GetZoneSets(dungeon, zoneId)
    local u, t = SumPieces(sets)
    Print(L.CHAT_ENTER, dungeon.name, FormatCount(u, t))
    for _, setData in ipairs(sets) do
        local su, st = setData:GetNumUnlockedPieces(), setData:GetNumPieces()
        if su < st then
            Print("  %s: %s", setData:GetFormattedName(), FormatCount(su, st))
        end
    end
end

-- One summary per dungeon visit: not again after /reloadui or a wipe within SUMMARY_REPEAT_SECONDS.
local function ShouldPrintSummary(zoneId)
    local last = sv.lastSummary
    local now = GetTimeStamp()
    if last and last.zoneId == zoneId and GetDiffBetweenTimeStamps(now, last.time) < SUMMARY_REPEAT_SECONDS then
        return false
    end
    sv.lastSummary = { zoneId = zoneId, time = now }
    return true
end

local function PrintTotal()
    local unlocked, total = 0, 0
    local count = 0
    for _, dungeon in ipairs(GetDungeons()) do
        if dungeon.isDungeon then
            local u, t = SumPieces(dungeon.sets)
            unlocked, total, count = unlocked + u, total + t, count + 1
        end
    end
    Print(L.CHAT_TOTAL, count, FormatCount(unlocked, total))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local dungeonsRequested = false

local function OnPlayerActivated()
    if not dungeonsRequested then
        dungeonsRequested = true
        -- Build the dungeon list now rather than on the first hover.
        zo_callLater(GetDungeons, 2000)
    end

    currentZoneId = GetUnitWorldPosition("player")
    currentDungeon = FindCurrentDungeon(currentZoneId)
    if currentDungeon and sv.chatOnEnter and ShouldPrintSummary(currentZoneId) then
        PrintDungeonSummary(currentDungeon, currentZoneId)
    end
    RefreshPanel()
end

local function OnCollectionsUpdated()
    RefreshPanel()
    RefreshSetChart()
end

-- slotsJustUnlocked: { { itemSetId = id, slot = slot }, ... }, sent once per batch by the data manager.
local function OnSlotsJustUnlocked(slotsJustUnlocked)
    if not (sv.chatNewPiece and currentDungeon) then return end
    for _, unlocked in ipairs(slotsJustUnlocked) do
        local dungeon = dungeonsBySetId[unlocked.itemSetId]
        -- Compared by category id: the dungeon list may have been rebuilt since currentDungeon was found.
        if dungeon and dungeon.id == currentDungeon.id then
            local setData = ITEM_SET_COLLECTIONS_DATA_MANAGER:GetItemSetCollectionData(unlocked.itemSetId)
            local pieceData = setData:GetPieceDataBySlot(unlocked.slot)
            Print(L.CHAT_NEW_PIECE, pieceData:GetItemLink(), setData:GetFormattedName(),
                FormatCount(setData:GetNumUnlockedPieces(), setData:GetNumPieces()))
        end
    end
end

---------------------------------------------------------------------------
-- Settings (needs LibAddonMenu-2.0; without it the addon runs with its default settings)
---------------------------------------------------------------------------

local function ResetChartPlacement()
    sv.tipSide, sv.tipOffsetX, sv.tipOffsetY = defaults.tipSide, defaults.tipOffsetX, defaults.tipOffsetY
    sv.tipScale, sv.tipBgAlpha = defaults.tipScale, defaults.tipBgAlpha
    PreviewSetChart()
end

local function CreateSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    local panelName = DST.name .. "Settings"
    DST.settingsPanel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = L.TITLE,
        displayName = L.TITLE,
        author = "@DesertMorfen",
        version = DST.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    -- Slider ranges follow the screen, so every value moves the chart.
    local maxOffsetX = zo_max(0, zo_floor((GuiRoot:GetWidth() - TIP_WIDTH) / 10) * 10)
    local maxOffsetY = zo_max(0, zo_floor((GuiRoot:GetHeight() - TIP_HEIGHT) / 20) * 10)
    local function chartOff() return not (sv.finderTooltip or sv.mapTooltip or sv.mapZoneButton) end
    local function Checkbox(key, name, tooltip, onChange, disabled)
        return {
            type = "checkbox", name = name, tooltip = tooltip, disabled = disabled,
            getFunc = function() return sv[key] end,
            setFunc = function(value) sv[key] = value; if onChange then onChange(value) end end,
            default = defaults[key],
        }
    end
    local function Slider(key, name, tooltip, min, max, step, onChange, disabled)
        return {
            type = "slider", name = name, tooltip = tooltip, min = min, max = max, step = step, disabled = disabled,
            getFunc = function() return sv[key] end,
            setFunc = function(value) sv[key] = value; if onChange then onChange(value) end end,
            default = defaults[key],
        }
    end

    LAM:RegisterOptionControls(panelName, {
        { type = "description", text = L.SETTINGS_INTRO },

        { type = "header", name = L.SETTINGS_FINDER },
        { type = "description", text = L.SETTINGS_FINDER_DESC },
        Checkbox("finderTooltip", L.SETTINGS_FINDER_TOOLTIP, L.SETTINGS_FINDER_TOOLTIP_TT, function(value)
            if not value then HideSetChart() end
        end),
        Checkbox("mapTooltip", L.SETTINGS_MAP_TOOLTIP, L.SETTINGS_MAP_TOOLTIP_TT, function(value)
            if not value then HideSetChart() end
        end),
        Checkbox("mapZoneButton", L.SETTINGS_MAP_ZONE, L.SETTINGS_MAP_ZONE_TT, RefreshZoneButton),
        {
            type = "dropdown",
            name = L.SETTINGS_TIP_POSITION,
            tooltip = L.SETTINGS_TIP_POSITION_TT,
            choices = { L.SETTINGS_POS_LEFT, L.SETTINGS_POS_RIGHT, L.SETTINGS_POS_PREVIEW },
            choicesValues = { "left", "right", "preview" },
            getFunc = function() return sv.tipSide end,
            setFunc = function(value) sv.tipSide = value; PreviewSetChart() end,
            default = defaults.tipSide,
            disabled = chartOff,
        },
        Slider("tipOffsetX", L.SETTINGS_TIP_OFFSET_X, L.SETTINGS_TIP_OFFSET_X_TT, 0, maxOffsetX, 10, PreviewSetChart, chartOff),
        Slider("tipOffsetY", L.SETTINGS_TIP_OFFSET_Y, L.SETTINGS_TIP_OFFSET_Y_TT, -maxOffsetY, maxOffsetY, 10, PreviewSetChart, chartOff),
        Slider("tipScale", L.SETTINGS_TIP_SCALE, L.SETTINGS_TIP_SCALE_TT, 60, 150, 5, PreviewSetChart, chartOff),
        Slider("tipBgAlpha", L.SETTINGS_TIP_BG, L.SETTINGS_TIP_BG_TT, 0, 100, 5, PreviewSetChart, chartOff),
        Checkbox("tipHideCompleted", L.SETTINGS_TIP_HIDE_COMPLETED, L.SETTINGS_TIP_HIDE_COMPLETED_TT, PreviewSetChart, chartOff),
        Checkbox("tipShowLegend", L.SETTINGS_TIP_LEGEND, L.SETTINGS_TIP_LEGEND_TT, PreviewSetChart, chartOff),
        { type = "button", name = L.SETTINGS_TIP_PREVIEW, tooltip = L.SETTINGS_TIP_PREVIEW_TT, func = PreviewSetChart, disabled = chartOff },
        { type = "button", name = L.SETTINGS_TIP_RESET, tooltip = L.SETTINGS_TIP_RESET_TT, func = ResetChartPlacement, disabled = chartOff },

        { type = "header", name = L.SETTINGS_PANEL },
        Checkbox("showPanel", L.SETTINGS_SHOW_PANEL, L.SETTINGS_SHOW_PANEL_TT, RefreshPanel),
        Checkbox("panelLocked", L.SETTINGS_LOCK_PANEL, L.SETTINGS_LOCK_PANEL_TT, ApplyPanelSettings),
        Slider("panelScale", L.SETTINGS_PANEL_SCALE, L.SETTINGS_PANEL_SCALE_TT, 60, 150, 5, ApplyPanelSettings),
        Checkbox("panelHideCompleted", L.SETTINGS_PANEL_HIDE_COMPLETED, L.SETTINGS_PANEL_HIDE_COMPLETED_TT, RefreshPanel),
        {
            type = "button",
            name = L.SETTINGS_RESET_PANEL,
            tooltip = L.SETTINGS_RESET_PANEL_TT,
            func = function() sv.panelPos = nil; AnchorPanel() end,
        },

        { type = "header", name = L.SETTINGS_CHAT },
        Checkbox("chatOnEnter", L.SETTINGS_CHAT_ENTER, L.SETTINGS_CHAT_ENTER_TT),
        Checkbox("chatNewPiece", L.SETTINGS_CHAT_NEW_PIECE, L.SETTINGS_CHAT_NEW_PIECE_TT),
    })
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

local function OnSlashCommand(args)
    args = zo_strlower(zo_strtrim(args or ""))
    if args == "" or args == "settings" then
        if DST.settingsPanel then
            LibAddonMenu2:OpenToPanel(DST.settingsPanel)
        else
            Print("%s", L.CHAT_NO_SETTINGS)
        end
    elseif args == "panel" then
        sv.showPanel = not sv.showPanel
        RefreshPanel()
        Print("%s", sv.showPanel and L.CHAT_PANEL_ON or L.CHAT_PANEL_OFF)
    elseif args == "total" then
        PrintTotal()
    else
        Print("%s", L.CHAT_HELP)
    end
end

local function RegisterSetCollectionsCallbacks()
    ITEM_SET_COLLECTIONS_DATA_MANAGER:RegisterCallback("CollectionsUpdated", OnCollectionsUpdated)
    ITEM_SET_COLLECTIONS_DATA_MANAGER:RegisterCallback("SlotsJustUnlocked", OnSlotsJustUnlocked)
end

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= DST.name then return end
    EVENT_MANAGER:UnregisterForEvent(DST.name, EVENT_ADD_ON_LOADED)

    -- Account-wide (the set collection itself is account-wide), separated per server: NA, EU and PTS.
    sv = ZO_SavedVars:NewAccountWide("DungeonSetTrackerSV", SV_VERSION, nil, defaults, GetWorldName())
    SLASH_COMMANDS["/dst"] = OnSlashCommand
    EVENT_MANAGER:RegisterForEvent(DST.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    CreatePanel()
    CreateSetChart()
    CreateSettings()
    RegisterSetCollectionsCallbacks()
end

EVENT_MANAGER:RegisterForEvent(DST.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
