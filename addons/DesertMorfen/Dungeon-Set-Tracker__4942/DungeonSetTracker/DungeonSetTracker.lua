-- DungeonSetTracker: while you hover a dungeon in the Dungeon Finder, shows which pieces of its sets you have
-- collected. Also an optional HUD panel inside dungeons and optional chat messages. It only reads the game's own
-- set collection data and displays it; it never acts for you.

DungeonSetTracker = DungeonSetTracker or {}
local DST = DungeonSetTracker
DST.name = "DungeonSetTracker"
DST.version = "1.0.0"
local L = DST.L

local SV_VERSION = 1
local SUMMARY_REPEAT_SECONDS = 30 * 60  -- no second chat summary for the same dungeon within this time

-- Saved setting names are kept from earlier versions (e.g. "finderTooltip", "tipSide") so no migration is needed.
local defaults = {
    finderTooltip = true,       -- set chart while hovering dungeons in the Dungeon Finder
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
local dungeons              -- { { category, id, name, key, sets = { setData, ... } }, ... } in Sets book order
local dungeonsByKey         -- [normalized name] = dungeon entry
local dungeonsBySetId       -- [itemSetId] = dungeon entry
local dungeonsProvisional   -- true when built without Dungeon Finder data, rebuilt on next use
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
-- possibly nested in groups. A top-level category is used when it contains dungeons of the Dungeon Finder, so
-- trials and arenas are left out, and no category id or localized name is hardcoded.
local function BuildDungeons()
    dungeons, dungeonsByKey, dungeonsBySetId = {}, {}, {}
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
        for _, subcategory in top:SubcategoryIterator() do
            Walk(subcategory)
        end
        entriesByTop[top], keysByTop[top] = entries, keyMap
    end

    local useTop = {}
    for _, activityType in ipairs({ LFG_ACTIVITY_DUNGEON, LFG_ACTIVITY_MASTER_DUNGEON }) do
        for index = 1, GetNumActivitiesByType(activityType) do
            local zoneId = GetActivityZoneId(GetActivityIdByTypeAndIndex(activityType, index))
            local zoneName = zoneId and zoneId ~= 0 and GetZoneNameById(zoneId)
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
        if useTop[top] then
            for _, entry in ipairs(entriesByTop[top]) do
                -- Two categories with the same name are treated as one dungeon, so no set is lost.
                local existing = entry.key and dungeonsByKey[entry.key]
                if existing then
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

local function FindCurrentDungeon(zoneId)
    if not IsUnitInDungeon("player") then return nil end
    return FindDungeonByZoneId(zoneId) or FindDungeonByName(GetUnitZone("player"))
end

-- Both parts of a two-part dungeon share one Sets book category, but each part has its own monster set. With the
-- optional library LibSets (by Baertram) installed, monster sets that LibSets says drop elsewhere are left out.
-- Other sets are always kept, and without LibSets (or without data for a set, e.g. while LibSets is still scanning
-- right after login) nothing is filtered; the next hover then shows the filtered result.
local function MonsterSetDropsInZone(setData, zoneId)
    local libSets = LibSets
    if not (zoneId and libSets and libSets.GetZoneIds) or setData:GetSetType() ~= ITEM_SET_TYPE_MONSTER then
        return true
    end
    local ok, zoneIds = pcall(libSets.GetZoneIds, setData:GetId())
    if not ok or type(zoneIds) ~= "table" or next(zoneIds) == nil then
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
-- Fixed window size: room for two rows of sets (four sets). With more sets only the content is scaled down
-- to fit; with fewer the rest of the window stays empty. The legend always sits at the bottom.
local CONTENT_TOP = TIP_PADDING + TITLE_HEIGHT
local CONTENT_HEIGHT = 2 * (HEADER_HEIGHT + 5 * CELL_STEP) + SET_GAP
local LEGEND_AREA = 34
local TIP_WIDTH = 2 * TIP_PADDING + NUM_COLUMNS * GRID_WIDTH + (NUM_COLUMNS - 1) * COLUMN_GAP
local TIP_HEIGHT = CONTENT_TOP + CONTENT_HEIGHT + LEGEND_AREA + TIP_PADDING
local PREVIEW_DURATION_MS = 4000
local PREVIEW_GAP = 10          -- distance from the game's dungeon preview in the "next to the preview" position
local FADE_IN_MS = 120
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

local function SetCell(cell, icon, collected)
    cell.frame:SetColor((collected and COLLECTED_FRAME or MISSING_FRAME):UnpackRGBA())
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

local function PlaceChart(chart)
    chart:ClearAnchors()
    local preview = ZO_ActivityFinderTemplateTooltip_Keyboard
    if sv.tipSide == "preview" and preview and not preview:IsHidden() then
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
    scale = zo_min(scale, (GuiRoot:GetHeight() - 20) / TIP_HEIGHT, (GuiRoot:GetWidth() - 20) / TIP_WIDTH)
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
    local sets = allSets
    if sv.tipHideCompleted then
        sets = {}
        for _, setData in ipairs(allSets) do
            if setData:GetNumUnlockedPieces() < setData:GetNumPieces() then
                table.insert(sets, setData)
            end
        end
    end

    -- Long dungeon names get a smaller font instead of being cut off.
    chart.title:SetFont("ZoFontWinH2")
    chart.title:SetText(dungeon.name)
    if chart.title:GetTextWidth() > TIP_WIDTH - 2 * TIP_PADDING then
        chart.title:SetFont("ZoFontWinH3")
    end
    SetProgress(chart.totalBar, SumPieces(allSets))

    local markedVeteran = false
    local y = 0
    local rowHeight = 0
    for rowStart = 1, #sets, NUM_COLUMNS do
        if rowStart > 1 then
            y = y + rowHeight + SET_GAP
        end
        -- Every set header has the same fixed height, with name and progress bar centered in it, so names,
        -- bars and icons always stay at the same place whatever the length of the names.
        local rowSets = {}
        for column = 0, NUM_COLUMNS - 1 do
            local setData = sets[rowStart + column]
            if setData then
                local x = TIP_PADDING + column * (GRID_WIDTH + COLUMN_GAP)
                local su, st = setData:GetNumUnlockedPieces(), setData:GetNumPieces()
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
                table.insert(rowSets, { setData = setData, x = x })
            end
        end

        rowHeight = 0
        for _, entry in ipairs(rowSets) do
            local rows = LayoutPieces(entry.setData)
            for rowIndex, pieces in ipairs(rows) do
                local cellY = y + HEADER_HEIGHT + (rowIndex - 1) * CELL_STEP
                for i, pieceData in ipairs(pieces) do
                    numCells = numCells + 1
                    local cell = AcquireChartControl(chart.cells, numCells, "DungeonSetTracker_ChartCell", "Cell")
                    cell:ClearAnchors()
                    cell:SetAnchor(TOPLEFT, content, TOPLEFT, entry.x + (i - 1) * CELL_STEP, cellY)
                    SetCell(cell, pieceData:GetIcon(), pieceData:IsUnlocked())
                end
            end
            rowHeight = zo_max(rowHeight, HEADER_HEIGHT + #rows * CELL_STEP)
        end
    end
    if #sets == 0 then
        AddLabel(L.ALL_COLLECTED, ZO_SUCCEEDED_TEXT, TIP_PADDING, y, TIP_WIDTH - 2 * TIP_PADDING)
        rowHeight = HEADER_HEIGHT
    end
    HideUnused(chart.labels, numLabels)
    HideUnused(chart.cells, numCells)
    HideUnused(chart.bars, numBars)
    -- More sets than the fixed window holds: scale the content down, the window keeps its size.
    content:SetScale(zo_min(1, CONTENT_HEIGHT / zo_max(y + rowHeight, 1)))

    -- Legend with a real piece of this dungeon: in color for "collected", as a silhouette for "missing".
    local legend = chart.legend
    legend:SetHidden(not sv.tipShowLegend)
    local sampleIcon = FALLBACK_ICON
    if dungeon.sets[1] then
        for _, pieceData in dungeon.sets[1]:PieceIterator() do
            sampleIcon = pieceData:GetIcon()
            break
        end
    end
    SetCell(legend.have, sampleIcon, true)
    SetCell(legend.missing, sampleIcon, false)
    legend.veteran:SetHidden(not markedVeteran)

    chart.bg:SetAlpha(sv.tipBgAlpha / 100)
    PlaceChart(chart)
    if chart:IsHidden() then
        chart.fade:FadeIn(0, FADE_IN_MS)
    end
end

local function HideSetChart()
    local chart = ui.chart
    if chart then
        chart.fade:Stop()
        chart:SetHidden(true)
        chart.shown = nil
    end
end

local function RefreshSetChart()
    local chart = ui.chart
    if chart and chart.shown and not chart:IsHidden() then
        ShowSetChart(chart.shown.dungeon, chart.shown.zoneId, chart.shown.isNormalDifficulty)
    end
end

-- Shows the chart for a few seconds while its settings are changed. The dungeon with the most sets is used,
-- so every part of the chart is visible.
local previewToken = 0
local function PreviewSetChart()
    if not sv.finderTooltip then
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
    previewToken = previewToken + 1
    local token = previewToken
    zo_callLater(function()
        if token == previewToken then
            HideSetChart()
        end
    end, PREVIEW_DURATION_MS)
end

local function OnFinderEntryMouseEnter(control)
    HideSetChart()
    if not sv.finderTooltip then return end
    local data = control and control.node and control.node.data
    -- Only single activities have a zone; "random dungeon" entries (activity sets) have none.
    if not (data and data.IsSpecificEntryType and data:IsSpecificEntryType() and data.GetZoneId) then
        return
    end
    local zoneId = data:GetZoneId()
    local dungeon = FindDungeonByZoneId(zoneId) or FindDungeonByName(data:GetRawName())
    if dungeon then
        local isNormal = data.GetActivityType and data:GetActivityType() == LFG_ACTIVITY_DUNGEON
        ShowSetChart(dungeon, zoneId, isNormal)
    end
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
    chart.content:SetAnchor(TOP, chart, TOP, 0, CONTENT_TOP)  -- scaled down content stays centered
    chart.content:SetDimensions(TIP_WIDTH, CONTENT_HEIGHT)
    chart.labels, chart.cells, chart.bars = {}, {}, {}

    local legend = chart:GetNamedChild("Legend")
    chart.legend = legend
    legend:SetDimensions(TIP_WIDTH - 2 * TIP_PADDING, LEGEND_AREA - 10)
    legend:SetAnchor(BOTTOMLEFT, chart, BOTTOMLEFT, TIP_PADDING, -TIP_PADDING)
    legend.have = InitCell(legend:GetNamedChild("Have"))
    legend.missing = InitCell(legend:GetNamedChild("Missing"))
    legend.have:SetDimensions(22, 22)
    legend.missing:SetDimensions(22, 22)
    legend:GetNamedChild("HaveText"):SetText(L.LEGEND_HAVE)
    legend:GetNamedChild("MissingText"):SetText(L.LEGEND_MISSING)
    legend.veteran = legend:GetNamedChild("Veteran")
    legend.veteran:SetText(zo_iconTextFormat(ZO_GetVeteranIcon(), 20, 20, L.LEGEND_VETERAN_ONLY))

    -- The keyboard Activity Finder calls these when the mouse enters/leaves a list entry.
    -- Post-hooks only add our own chart; the game's behaviour and preview are not changed.
    -- Not on consoles: there is only the gamepad Activity Finder.
    if ZO_ActivityFinderTemplate_Keyboard and not IsConsoleUI() then
        ZO_PostHook(ZO_ActivityFinderTemplate_Keyboard, "ShowActivityTooltip", OnFinderEntryMouseEnter)
        ZO_PostHook(ZO_ActivityFinderTemplate_Keyboard, "HideActivityTooltip", HideSetChart)
        ui.finderHooked = true
    end
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
    for _, dungeon in ipairs(GetDungeons()) do
        local u, t = SumPieces(dungeon.sets)
        unlocked, total = unlocked + u, total + t
    end
    Print(L.CHAT_TOTAL, #GetDungeons(), FormatCount(unlocked, total))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local function OnPlayerActivated()
    if DST.loadErrors then
        for _, err in ipairs(DST.loadErrors) do
            Print("|cFF4444error|r %s", err)
        end
        if ui.chart and not ui.finderHooked and not IsConsoleUI() then
            Print("%s", L.CHAT_FINDER_MISSING)
        end
        DST.loadErrors = nil
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
            local pieceData = setData and setData:GetPieceDataBySlot(unlocked.slot)
            if pieceData then
                Print(L.CHAT_NEW_PIECE, pieceData:GetItemLink(), setData:GetFormattedName(),
                    FormatCount(setData:GetNumUnlockedPieces(), setData:GetNumPieces()))
            end
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
    local function chartOff() return not sv.finderTooltip end
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

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= DST.name then return end
    EVENT_MANAGER:UnregisterForEvent(DST.name, EVENT_ADD_ON_LOADED)

    -- Account-wide (the set collection itself is account-wide), separated per server: NA, EU and PTS.
    sv = ZO_SavedVars:NewAccountWide("DungeonSetTrackerSV", SV_VERSION, nil, defaults, GetWorldName())
    SLASH_COMMANDS["/dst"] = OnSlashCommand
    EVENT_MANAGER:RegisterForEvent(DST.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- Each part starts on its own, so one failing part doesn't take the others down. Errors are shown in chat
    -- once the player is in the world.
    local errors = {}
    local function Try(partName, func)
        local ok, err = pcall(func)
        if not ok then
            table.insert(errors, partName .. ": " .. tostring(err))
        end
    end
    Try("panel", CreatePanel)
    Try("chart", CreateSetChart)
    Try("settings", CreateSettings)
    Try("events", function()
        ITEM_SET_COLLECTIONS_DATA_MANAGER:RegisterCallback("CollectionsUpdated", OnCollectionsUpdated)
        ITEM_SET_COLLECTIONS_DATA_MANAGER:RegisterCallback("SlotsJustUnlocked", OnSlotsJustUnlocked)
    end)
    DST.loadErrors = errors
end

EVENT_MANAGER:RegisterForEvent(DST.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
