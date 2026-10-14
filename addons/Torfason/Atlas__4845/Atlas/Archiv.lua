local AE = AtlasAddon
local T = AE.T

local ARCHIVE_ROW_HEIGHT = 29
local ARCHIVE_ROW_GAP = 2
local ARCHIVE_SCAN_MAX_MAP_ID = 6000
local ARCHIVE_SCAN_BATCH = 160

local ARCHIVE_TOOLTIP_MARGIN = 14
local ARCHIVE_TOOLTIP_UPDATE_HANDLER = "AtlasArchiveFollowMouse"

-- Keep archive hints in the free space to the LEFT of ESO's world-map side
-- panel. Only the vertical position follows the cursor. The tooltip is
-- triggered by the visible lettering, never by vacant row space.
local function PositionArchiveTooltip()
    if not AE.archiveTooltipOwner or not InformationTooltip or not GuiRoot or
        not AE.archivePanel or not GetUIMousePosition then return end

    local panelLeft = AE.archivePanel:GetLeft()
    local _, mouseY = GetUIMousePosition()
    if type(panelLeft) ~= "number" or type(mouseY) ~= "number" then return end

    local uiHeight = GuiRoot:GetHeight()
    if type(uiHeight) ~= "number" or uiHeight <= 0 then return end

    -- The tooltip is aligned by its RIGHT edge, so it cannot overlap the
    -- archive panel. Clamp its centre to the screen's vertical safe area.
    local tooltipHeight = math.max(InformationTooltip:GetHeight() or 0, 40)
    local halfHeight = tooltipHeight / 2
    local minY = halfHeight + 8
    local maxY = math.max(minY, uiHeight - halfHeight - 8)
    local anchorY = math.max(minY, math.min(mouseY, maxY))
    local anchorX = panelLeft - ARCHIVE_TOOLTIP_MARGIN

    -- Do not change the shared InformationTooltip's parent, draw layer or
    -- behaviour outside this specific archive tooltip.
    InformationTooltip:ClearAnchors()
    InformationTooltip:SetAnchor(RIGHT, GuiRoot, TOPLEFT, anchorX, anchorY)
end

local function HideArchiveTooltip(owner)
    if owner and AE.archiveTooltipOwner ~= owner then return end
    local previousOwner = AE.archiveTooltipOwner
    AE.archiveTooltipOwner = nil
    if previousOwner then
        previousOwner:SetHandler("OnUpdate", nil, ARCHIVE_TOOLTIP_UPDATE_HANDLER)
        previousOwner.atlasArchiveTooltipY = nil
    end
    if InformationTooltip then ClearTooltip(InformationTooltip) end
end

local function ShowArchiveTooltip(owner, entry, hint)
    if not owner or not entry or not InformationTooltip then return end
    HideArchiveTooltip()
    InitializeTooltip(InformationTooltip)
    InformationTooltip:AddLine(entry.name, "ZoFontGameBold", 0.50, 0.78, 1.00)
    InformationTooltip:AddLine(hint, "ZoFontGame", 0.86, 0.80, 0.63)
    AE.archiveTooltipOwner = owner
    PositionArchiveTooltip()

    -- Only active while hovering this row/button; no permanent polling.
    owner:SetHandler("OnUpdate", function(self)
        if AE.archiveTooltipOwner ~= self then
            self:SetHandler("OnUpdate", nil, ARCHIVE_TOOLTIP_UPDATE_HANDLER)
            return
        end
        if not AE.archivePanel or AE.archivePanel:IsHidden() or self:IsHidden() then
            HideArchiveTooltip(self)
            return
        end
        if GetUIMousePosition then
            local _, y = GetUIMousePosition()
            if y ~= self.atlasArchiveTooltipY then
                self.atlasArchiveTooltipY = y
                PositionArchiveTooltip()
            end
        end
    end, ARCHIVE_TOOLTIP_UPDATE_HANDLER)
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function FormatMapName(name)
    if not IsNonEmptyString(name) then return nil end

    -- ESO liefert Namen in einigen Sprachen mit Grammatik-Markierungen wie
    -- "Glenumbra^N,in" oder "Grab^nd,in". Diese muessen ueber
    -- zo_strformat verarbeitet werden, bevor sie angezeigt werden.
    if zo_strformat then
        local ok, formatted = pcall(zo_strformat, "<<C:1>>", name)
        if ok and IsNonEmptyString(formatted) then name = formatted end
    end

    -- Sicherheitsnetz fuer Clients/Faelle, in denen eine Markierung uebrig bleibt.
    name = string.gsub(name, "%^.*$", "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return name
end


function AE:GetArchiveFallbackName(key, map)
    -- Wenn eine ESO-Karten-ID bekannt ist, holen wir den Namen frisch aus dem
    -- Spiel. So werden auch aeltere gespeicherte Roh-Namen automatisch sauber.
    if map and type(map.mapId) == "number" and map.mapId > 0 and GetMapNameById then
        local liveName = FormatMapName(GetMapNameById(map.mapId))
        if IsNonEmptyString(liveName) then return liveName end
    end

    if map and IsNonEmptyString(map.displayName) then
        local displayName = FormatMapName(map.displayName)
        if IsNonEmptyString(displayName) then return displayName end
    end

    local path = (map and map.lastPath) or key or ""
    local normalized = string.lower(string.gsub(path, "\\", "/"))
    local folder = string.match(normalized, "art/maps/([^/]+)/")
    local file = string.match(normalized, "([^/]+)%.dds$")
    local rawName = folder or file or T.ARCHIVE_UNKNOWN_MAP
    rawName = string.gsub(rawName, "_base_?%d*$", "")
    rawName = string.gsub(rawName, "_", " ")
    rawName = string.gsub(rawName, "(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. rest
    end)
    return FormatMapName(rawName) or rawName
end

function AE:ApplyArchiveMetadataFromMapId(map, mapId)
    if type(map) ~= "table" or type(mapId) ~= "number" or mapId <= 0 then return false end

    map.mapId = mapId
    if GetMapIndexById then
        local mapIndex = GetMapIndexById(mapId)
        if type(mapIndex) == "number" and mapIndex > 0 then map.mapIndex = mapIndex end
    end

    if GetMapInfoById then
        local name, mapType, contentType, zoneIndex = GetMapInfoById(mapId)
        if IsNonEmptyString(name) then map.displayName = FormatMapName(name) or name end
        map.mapType = mapType
        map.contentType = contentType
        map.zoneIndex = zoneIndex
    elseif GetMapNameById then
        local name = GetMapNameById(mapId)
        if IsNonEmptyString(name) then map.displayName = FormatMapName(name) or name end
    end

    map.archiveResolveScanned = nil
    return true
end

-- Archive display groups maps with identical localized names, but NEVER merges
-- their independent 48x48 exploration masks. Map IDs and normalized texture
-- paths, not the name, define individual stored map records.
function AE:GetArchiveEntries()
    local visible = {}
    local rawCount = 0
    if not self.progress or type(self.progress.maps) ~= "table" then return visible, rawCount end

    local grouped = {}
    for key, map in pairs(self.progress.maps) do
        if type(key) == "string" and type(map) == "table" and self:CountMapCells(map) > 0 then
            rawCount = rawCount + 1
            local name = self:GetArchiveFallbackName(key, map)
            local groupKey = string.lower(name)
            local group = grouped[groupKey]
            if not group then
                group = { kind = "group", groupKey = groupKey, name = name, members = {} }
                grouped[groupKey] = group
            end
            group.members[#group.members + 1] = { kind = "map", key = key, map = map, name = name }
        end
    end

    local sortedGroups = {}
    for _, group in pairs(grouped) do
        table.sort(group.members, function(a, b)
            local aid = (type(a.map.mapId) == "number" and a.map.mapId > 0) and a.map.mapId or math.huge
            local bid = (type(b.map.mapId) == "number" and b.map.mapId > 0) and b.map.mapId or math.huge
            if aid ~= bid then return aid < bid end
            return a.key < b.key
        end)
        sortedGroups[#sortedGroups + 1] = group
    end
    table.sort(sortedGroups, function(a, b)
        if a.groupKey == b.groupKey then return a.name < b.name end
        return a.groupKey < b.groupKey
    end)

    self.archiveExpandedGroups = self.archiveExpandedGroups or {}
    for _, group in ipairs(sortedGroups) do
        if #group.members == 1 then
            visible[#visible + 1] = group.members[1]
        else
            group.expanded = self.archiveExpandedGroups[group.groupKey] == true
            visible[#visible + 1] = group
            if group.expanded then
                for i, member in ipairs(group.members) do
                    member.variantIndex = i
                    member.parentGroup = group.groupKey
                    visible[#visible + 1] = member
                end
            end
        end
    end
    return visible, rawCount
end

function AE:ResolveArchiveFromMapList()
    if not GetNumMaps or not GetMapIdByIndex or not GetMapTileTextureForMapId then return end

    local wanted = {}
    for key, map in pairs(self.progress.maps or {}) do
        if type(map) == "table" and not map.mapId and self:CountMapCells(map) > 0 then
            wanted[key] = map
        end
    end
    if next(wanted) == nil then return end

    local numMaps = GetNumMaps() or 0
    for mapIndex = 1, numMaps do
        local mapId = GetMapIdByIndex(mapIndex)
        if type(mapId) == "number" and mapId > 0 then
            local tile = GetMapTileTextureForMapId(mapId, 1)
            local key = self:NormalizeMapPath(tile)
            local target = key and wanted[key]
            if target then
                self:ApplyArchiveMetadataFromMapId(target, mapId)
                target.mapIndex = mapIndex
                wanted[key] = nil
                if next(wanted) == nil then break end
            end
        end
    end
end

function AE:StartArchiveResolver()
    if self.archiveResolverActive then return end
    if not GetMapNameById or not GetMapTileTextureForMapId then return end

    self:ResolveArchiveFromMapList()

    local unresolved = {}
    for key, map in pairs(self.progress.maps or {}) do
        if type(map) == "table" and not map.mapId and not map.archiveResolveScanned and self:CountMapCells(map) > 0 then
            unresolved[key] = map
        end
    end
    if next(unresolved) == nil then return end

    self.archiveResolverActive = true
    self.archiveResolverGeneration = (self.archiveResolverGeneration or 0) + 1
    local generation = self.archiveResolverGeneration
    local mapId = 1

    if not self.archiveResolverMessageShown then
        self.archiveResolverMessageShown = true
        self:Msg(T.ARCHIVE_RESOLVING)
    end

    local function Finish()
        for _, map in pairs(unresolved) do
            if type(map) == "table" and not map.mapId then map.archiveResolveScanned = true end
        end
        AE.archiveResolverActive = false
        if AE.archivePanel and not AE.archivePanel:IsHidden() then AE:RefreshArchiveList() end
    end

    local function Step()
        if generation ~= AE.archiveResolverGeneration then return end
        if next(unresolved) == nil or mapId > ARCHIVE_SCAN_MAX_MAP_ID then
            Finish()
            return
        end

        local stopId = math.min(mapId + ARCHIVE_SCAN_BATCH - 1, ARCHIVE_SCAN_MAX_MAP_ID)
        for id = mapId, stopId do
            local name = GetMapNameById(id)
            if IsNonEmptyString(name) then
                local tile = GetMapTileTextureForMapId(id, 1)
                local key = AE:NormalizeMapPath(tile)
                local target = key and unresolved[key]
                if target then
                    AE:ApplyArchiveMetadataFromMapId(target, id)
                    unresolved[key] = nil
                    if next(unresolved) == nil then break end
                end
            end
        end
        mapId = stopId + 1
        zo_callLater(Step, 10)
    end

    zo_callLater(Step, 10)
end

function AE:OpenArchivedMap(entry)
    if not entry or type(entry.map) ~= "table" then return end
    -- The row stores the exact map table, not merely its display name.
    -- A stale row must not navigate using an entry that has just been deleted.
    if not self.progress or not self.progress.maps or
        self.progress.maps[entry.key] ~= entry.map then
        self:RefreshArchiveList()
        return
    end
    local map = entry.map

    if not map.mapId then
        self:StartArchiveResolver()
        self:Msg(T.ARCHIVE_UNRESOLVED)
        return
    end

    -- ESO's world-map manager records this as a player-selected map.
    -- Direct SetMapToMapId() does not and the native map update can
    -- otherwise snap the view back to the character's current location.
    if WORLD_MAP_MANAGER and type(WORLD_MAP_MANAGER.SetMapById) == "function" then
        if WORLD_MAP_MANAGER.IsMapChangingAllowed and
            not WORLD_MAP_MANAGER:IsMapChangingAllowed() then
            self:Msg(T.ARCHIVE_OPEN_FAILED)
            return
        end
        WORLD_MAP_MANAGER:SetMapById(map.mapId)
        -- The manager already fires OnWorldMapChanged when appropriate.
    else
        -- Older clients: best effort without redefining any ESO globals.
        local result
        if SetMapToMapId then
            result = SetMapToMapId(map.mapId)
        elseif map.mapIndex and SetMapToMapListIndex then
            result = SetMapToMapListIndex(map.mapIndex)
        else
            self:Msg(T.ARCHIVE_OPEN_FAILED)
            return
        end
        if result == _G.SET_MAP_RESULT_FAILED then
            self:Msg(T.ARCHIVE_OPEN_FAILED)
            return
        end
        if result == _G.SET_MAP_RESULT_MAP_CHANGED and CALLBACK_MANAGER then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
        end
    end

    self.lastMapKey = nil
    self:RefreshOverlay(true)
    self:ScheduleStableOverlayRefresh(100)
end

-- Explicitly reveal a single saved ESO map. This reuses the exact meaning of
-- the existing "Fully reveal current map" action without changing map IDs,
-- texture keys, or any other stored exploration record.
function AE:RevealArchivedMap(entry)
    if not entry or entry.kind ~= "map" or type(entry.key) ~= "string" or
        type(entry.map) ~= "table" or not self.progress or
        type(self.progress.maps) ~= "table" or
        self.progress.maps[entry.key] ~= entry.map then
        if self.RefreshArchiveList then self:RefreshArchiveList() end
        return false
    end

    local map = entry.map
    map.full = true
    map.bits = {}
    map.legacyTEBits = nil
    map.legacyTEFull = nil
    self.legacyTECache = nil
    self.lastMapKey = nil
    self:RefreshOverlay(true)
    self:RefreshArchiveList()
    self:Msg(string.format(T.ARCHIVE_MAP_REVEALED, entry.name or entry.key))
    return true
end

-- Use ESO's own context menu; no extra addon dependency. Both actions operate
-- on the exact archive map selected when the menu was opened. The second
-- action is the former "Forget" operation, including its confirmation dialog.
local function ShowArchiveActions(owner, entry)
    if not entry or entry.kind ~= "map" then return end
    if not ClearMenu or not AddMenuItem or not ShowMenu then
        AE:Msg(T.ARCHIVE_MENU_UNAVAILABLE)
        return
    end
    HideArchiveTooltip()
    ClearMenu()
    AddMenuItem(T.ARCHIVE_REVEAL, function()
        AE:RevealArchivedMap(entry)
    end)
    AddMenuItem(T.ARCHIVE_FORGET, function()
        AE:ConfirmClearArchivedMap(entry)
    end)
    ShowMenu(owner)
end

-- Restrict the label's hit area to the visible lettering (not the vacant
-- right-hand part of a row). GetTextWidth is provided by ESO's label control.
-- Long titles still have the full row width available to them.
local function FitArchiveTextHitbox(row)
    if not row or not row.nameLabel then return end
    local label = row.nameLabel
    local maxWidth = math.max(50, (AE.archiveRowWidth or 270) - 16)
    -- ESO's GetTextWidth() measures only the *visible* portion if the label
    -- was made narrow for a previous scroll-row item. Always restore the full
    -- row width before measuring a different text, otherwise a long label
    -- can be trapped at a stale width (e.g. "Karte" instead of "Karte 2 · ID 896").
    label:SetDimensions(maxWidth, 27)
    local measured = label.GetTextWidth and label:GetTextWidth() or maxWidth
    if type(measured) ~= "number" or measured <= 0 then measured = maxWidth end
    local measuredHeight = label.GetTextHeight and label:GetTextHeight() or 25
    if type(measuredHeight) ~= "number" or measuredHeight <= 0 then measuredHeight = 25 end
    label:SetDimensions(math.min(maxWidth, math.ceil(measured + 8)),
        math.min(27, math.max(12, math.ceil(measuredHeight + 2))))
end

function AE:RefreshArchiveList()
    if not self.archivePanel or not self.archiveScrollChild then return end
    if self.archiveTooltipOwner then HideArchiveTooltip() end

    local total
    self.archiveEntries, total = self:GetArchiveEntries()
    local visibleCount = #self.archiveEntries

    if self.archiveCountLabel then
        self.archiveCountLabel:SetText(string.format(T.ARCHIVE_COUNT, total))
    end
    if self.archiveEmptyLabel then
        self.archiveEmptyLabel:SetHidden(total > 0)
        if total == 0 then self.archiveEmptyLabel:SetText(T.ARCHIVE_EMPTY) end
    end
    if self.archiveScroll then self.archiveScroll:SetHidden(total == 0) end

    self:EnsureArchiveRows(visibleCount)
    for index, row in ipairs(self.archiveRows or {}) do
        local entry = self.archiveEntries[index]
        row.entry = entry
        if entry then
            row:SetHidden(false)
            if entry.kind == "group" then
                local symbol = entry.expanded and "- " or "+ "
                row.nameLabel:SetText(symbol .. entry.name .. " (" .. #entry.members .. ")")
                row.nameLabel:SetFont("ZoFontGameBold")
                row.nameLabel:SetColor(0.50, 0.78, 1.00, 1)
                -- Group headers only expand/collapse; no bulk data action.
            else
                if entry.variantIndex then
                    local mapId = (entry.map and entry.map.mapId) or "?"
                    row.nameLabel:SetText("  " .. string.format(T.ARCHIVE_VARIANT_LABEL, entry.variantIndex, tostring(mapId)))
                else
                    row.nameLabel:SetText(entry.name)
                end
                row.nameLabel:SetFont("ZoFontGame")
                row.nameLabel:SetColor(0.86, 0.80, 0.63, 1)
            end
            FitArchiveTextHitbox(row)
        else
            row:SetHidden(true)
        end
    end

    -- The count still reports every individually saved map. The scrollbar
    -- tracks the currently visible rows, including expanded variants.
    local contentHeight = visibleCount > 0 and
        (visibleCount * ARCHIVE_ROW_HEIGHT + (visibleCount - 1) * ARCHIVE_ROW_GAP) or 1
    self.archiveScrollChild:SetHeight(contentHeight)
    if ZO_Scroll_UpdateScrollBar then
        ZO_Scroll_UpdateScrollBar(self.archiveScroll)
    end
end

local function CreateArchiveRow(index, parent)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl("AtlasArchiveRow" .. index, parent, CT_CONTROL)
    row:SetDimensions(AE.archiveRowWidth or 270, ARCHIVE_ROW_HEIGHT)
    if index == 1 then
        row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    else
        row:SetAnchor(TOPLEFT, AE.archiveRows[index - 1], BOTTOMLEFT, 0, ARCHIVE_ROW_GAP)
    end
    row:SetMouseEnabled(true)

    local bg = wm:CreateControl(nil, row, CT_TEXTURE)
    bg:SetAnchorFill(row)
    bg:SetColor(0.08, 0.08, 0.08, 0.45)
    row.bg = bg

    -- The whole row highlights under the mouse, but it no longer owns a
    -- tooltip. Only the actual, tightly fitted name label can show one.
    local nameLabel = wm:CreateControl(nil, row, CT_LABEL)
    nameLabel:SetAnchor(LEFT, row, LEFT, 8, 0)
    nameLabel:SetDimensions((AE.archiveRowWidth or 270) - 16, 27)
    nameLabel:SetFont("ZoFontGame")
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    nameLabel:SetMouseEnabled(true)
    row.nameLabel = nameLabel

    local function ActivateEntry(button, upInside, owner)
        if not upInside or not row.entry then return end
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            if row.entry.kind == "map" then
                ShowArchiveActions(owner or row, row.entry)
            end
            return
        end
        if button == MOUSE_BUTTON_INDEX_LEFT then
            if row.entry.kind == "group" then
                AE.archiveExpandedGroups = AE.archiveExpandedGroups or {}
                local groupKey = row.entry.groupKey
                AE.archiveExpandedGroups[groupKey] = not AE.archiveExpandedGroups[groupKey]
                AE:RefreshArchiveList()
            else
                AE:OpenArchivedMap(row.entry)
            end
        end
    end

    nameLabel:SetHandler("OnMouseEnter", function(self)
        if not row.entry then return end
        local hint
        if row.entry.kind == "group" then
            hint = row.entry.expanded and T.ARCHIVE_GROUP_COLLAPSE_HINT or T.ARCHIVE_GROUP_EXPAND_HINT
        else
            hint = T.ARCHIVE_OPEN_HINT
            if row.entry.variantIndex then
                hint = hint .. "\n" .. string.format(T.ARCHIVE_PATH, row.entry.key)
            end
        end
        ShowArchiveTooltip(self, row.entry, hint)
    end, "AtlasArchiveTooltip")
    nameLabel:SetHandler("OnMouseExit", function(self)
        HideArchiveTooltip(self)
    end, "AtlasArchiveTooltip")
    nameLabel:SetHandler("OnMouseUp", function(self, button, upInside)
        ActivateEntry(button, upInside, self)
    end)

    row:SetHandler("OnMouseEnter", function(self)
        self.bg:SetColor(0.20, 0.27, 0.28, 0.72)
    end)
    row:SetHandler("OnMouseExit", function(self)
        self.bg:SetColor(0.08, 0.08, 0.08, 0.45)
    end)
    row:SetHandler("OnMouseUp", function(self, button, upInside)
        -- The label handles clicks over the lettering. The vacant part of the
        -- row still allows opening a map or accessing the context menu.
        if MouseIsOver and MouseIsOver(self.nameLabel) then return end
        ActivateEntry(button, upInside, self)
    end)
    -- Forward wheel events from the name label and the row to ESO's
    -- native scrollbar without interrupting the continuous archive list.
    local function ScrollWheel(_, delta)
        if AE.archiveScroll and ZO_Scroll_ScrollRelative then
            ZO_Scroll_ScrollRelative(AE.archiveScroll, -delta * 90)
        end
    end
    row:SetHandler("OnMouseWheel", ScrollWheel)
    nameLabel:SetHandler("OnMouseWheel", ScrollWheel)
    return row
end

function AE:EnsureArchiveRows(count)
    if not self.archiveScrollChild then return end
    while #self.archiveRows < count do
        local index = #self.archiveRows + 1
        self.archiveRows[index] = CreateArchiveRow(index, self.archiveScrollChild)
    end
end

function AE:CreateArchivePanel()
    if self.archivePanel or not WINDOW_MANAGER or not ZO_WorldMapInfo then return self.archivePanel ~= nil end

    local wm = WINDOW_MANAGER
    local panel = wm:CreateControl("AtlasArchivePanel", ZO_WorldMapInfo, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, ZO_WorldMapInfo, TOPLEFT, 10, 88)
    panel:SetAnchor(BOTTOMRIGHT, ZO_WorldMapInfo, BOTTOMRIGHT, -10, -8)
    panel:SetHidden(true)
    panel:SetMouseEnabled(true)
    self.archivePanel = panel

    -- The ESO mode bar now displays the localized archive title. Do not
    -- repeat it inside the panel: this leaves more room for map names.
    local subtitle = wm:CreateControl(nil, panel, CT_LABEL)
    subtitle:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    subtitle:SetDimensions(300, 36)
    subtitle:SetFont("ZoFontGameSmall")
    subtitle:SetColor(0.72, 0.70, 0.62, 1)
    subtitle:SetText(T.ARCHIVE_SUBTITLE)
    self.archiveSubtitleLabel = subtitle

    local countLabel = wm:CreateControl(nil, panel, CT_LABEL)
    countLabel:SetAnchor(TOPLEFT, subtitle, BOTTOMLEFT, 0, 0)
    countLabel:SetDimensions(300, 24)
    countLabel:SetFont("ZoFontGameBold")
    countLabel:SetColor(0.86, 0.80, 0.63, 1)
    self.archiveCountLabel = countLabel

    local empty = wm:CreateControl(nil, panel, CT_LABEL)
    empty:SetAnchor(TOPLEFT, countLabel, BOTTOMLEFT, 8, 20)
    empty:SetDimensions(280, 60)
    empty:SetFont("ZoFontGame")
    empty:SetColor(0.65, 0.65, 0.65, 1)
    empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.archiveEmptyLabel = empty

    -- Reuse the ESO-native scroll container already proven in Atlas settings.
    -- The child is a continuous list; there is no paging or custom scrollbar.
    local scroll = wm:CreateControlFromVirtual("AtlasArchiveScroll", panel, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, countLabel, BOTTOMLEFT, 0, 4)
    scroll:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, 0, -4)
    if ZO_Scroll_SetUseFadeGradient then ZO_Scroll_SetUseFadeGradient(scroll, false) end
    local child = GetControl(scroll, "ScrollChild") or scroll:GetNamedChild("ScrollChild")
    if not child then return false end
    self.archiveScroll = scroll
    self.archiveScrollChild = child
    local panelWidth = panel:GetWidth()
    if not panelWidth or panelWidth < 220 then panelWidth = 300 end
    self.archiveRowWidth = math.max(200, panelWidth - 24)
    child:SetWidth(self.archiveRowWidth)
    child:SetHeight(1)
    self.archiveRows = {}

    return true
end

function AE:RefreshArchiveLocalization()
    -- The world map's own tab heading uses this string ID. Update its
    -- value when the addon language changes, without touching ESO's language.
    if self.archiveSetupDone and SI_ATLAS_ARCHIVE_MODE and SafeAddString then
        self.archiveModeLabelVersion = (self.archiveModeLabelVersion or 1) + 1
        SafeAddString(SI_ATLAS_ARCHIVE_MODE, T.ARCHIVE_TITLE, self.archiveModeLabelVersion)
    end
    if self.archiveSubtitleLabel then self.archiveSubtitleLabel:SetText(T.ARCHIVE_SUBTITLE) end
    if self.archivePanel and not self.archivePanel:IsHidden() then self:RefreshArchiveList() end
end

function AE:SetupArchive()
    if self.archiveSetupDone then return end
    if not WORLD_MAP_INFO or not WORLD_MAP_INFO.modeBar or not ZO_WorldMapInfo then
        zo_callLater(function() AE:SetupArchive() end, 500)
        return
    end
    if not self:CreateArchivePanel() then
        zo_callLater(function() AE:SetupArchive() end, 500)
        return
    end

    -- Reuse ESO's main world-map heading rather than showing ATLAS and
    -- KARTENARCHIV as two stacked, redundant headings.
    ZO_CreateStringId("SI_ATLAS_ARCHIVE_MODE", T.ARCHIVE_TITLE)
    self.archiveModeLabelVersion = 1
    self.archiveFragment = ZO_FadeSceneFragment:New(self.archivePanel)

    -- Gemeinsame Torfason x Atlas Icon-Familie (Standard 1.2).
    -- Alle drei Zustaende verwenden das unveraenderte Atlas-Motiv;
    -- die Modusleiste uebernimmt die eigentliche Zustandsdarstellung.
    local archiveIcon = "Atlas/textures/atlas_icon.dds"
    local buttonData = {
        normal = archiveIcon,
        pressed = archiveIcon,
        highlight = archiveIcon,
        callback = function()
            AE:RefreshArchiveList()
            AE:StartArchiveResolver()
        end,
    }

    WORLD_MAP_INFO.modeBar:Add(SI_ATLAS_ARCHIVE_MODE, { self.archiveFragment }, buttonData)
    self.archiveSetupDone = true
end

function AE:OpenArchive()
    self:SetupArchive()
    local mapScene = SCENE_MANAGER and SCENE_MANAGER:GetScene("worldMap")
    if mapScene and SCENE_MANAGER then SCENE_MANAGER:Show("worldMap") end

    zo_callLater(function()
        if WORLD_MAP_INFO and WORLD_MAP_INFO.modeBar and SI_ATLAS_ARCHIVE_MODE then
            WORLD_MAP_INFO.modeBar:SelectDescriptor(SI_ATLAS_ARCHIVE_MODE)
            AE:RefreshArchiveList()
            AE:StartArchiveResolver()
        end
    end, 100)
end
