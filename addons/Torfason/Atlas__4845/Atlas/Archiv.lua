local AE = AtlasAddon
local T = AE.T

local ARCHIVE_ROWS_PER_PAGE = 14
local ARCHIVE_SCAN_MAX_MAP_ID = 6000
local ARCHIVE_SCAN_BATCH = 160

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

function AE:GetArchiveEntries()
    local entries = {}
    if not self.progress or type(self.progress.maps) ~= "table" then return entries end

    for key, map in pairs(self.progress.maps) do
        if type(map) == "table" then
            local count = self:CountMapCells(map)
            if count > 0 then
                entries[#entries + 1] = {
                    key = key,
                    map = map,
                    name = self:GetArchiveFallbackName(key, map),
                }
            end
        end
    end

    table.sort(entries, function(a, b)
        local an = string.lower(a.name or "")
        local bn = string.lower(b.name or "")
        if an == bn then return (a.key or "") < (b.key or "") end
        return an < bn
    end)
    return entries
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
    local map = entry.map

    if not map.mapId then
        self:StartArchiveResolver()
        self:Msg(T.ARCHIVE_UNRESOLVED)
        return
    end

    local result = nil
    if SetMapToMapId then
        result = SetMapToMapId(map.mapId)
    elseif map.mapIndex and SetMapToMapListIndex then
        result = SetMapToMapListIndex(map.mapIndex)
    end

    if result == nil or (_G.SET_MAP_RESULT_FAILED and result == SET_MAP_RESULT_FAILED) then
        self:Msg(T.ARCHIVE_OPEN_FAILED)
        return
    end

    if CALLBACK_MANAGER then CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged") end
    self.lastMapKey = nil
    self:RefreshOverlay(true)
    self:ScheduleStableOverlayRefresh(100)
end

function AE:SetArchivePage(page)
    local total = #(self.archiveEntries or {})
    local maxPage = math.max(1, math.ceil(total / ARCHIVE_ROWS_PER_PAGE))
    self.archivePage = math.max(1, math.min(tonumber(page) or 1, maxPage))
    self:RefreshArchiveList()
end

function AE:RefreshArchiveList()
    if not self.archivePanel then return end

    self.archiveEntries = self:GetArchiveEntries()
    local total = #self.archiveEntries
    local maxPage = math.max(1, math.ceil(total / ARCHIVE_ROWS_PER_PAGE))
    self.archivePage = math.max(1, math.min(self.archivePage or 1, maxPage))

    if self.archiveCountLabel then
        self.archiveCountLabel:SetText(string.format(T.ARCHIVE_COUNT, total))
    end

    if self.archiveEmptyLabel then
        self.archiveEmptyLabel:SetHidden(total > 0)
        if total == 0 then self.archiveEmptyLabel:SetText(T.ARCHIVE_EMPTY) end
    end

    local startIndex = (self.archivePage - 1) * ARCHIVE_ROWS_PER_PAGE + 1
    for rowIndex, row in ipairs(self.archiveRows or {}) do
        local entry = self.archiveEntries[startIndex + rowIndex - 1]
        row.entry = entry
        if entry then
            row:SetHidden(false)
            row.nameLabel:SetText(entry.name)
            row.nameLabel:SetColor(0.86, 0.80, 0.63, 1)
        else
            row:SetHidden(true)
        end
    end

    if self.archivePageLabel then
        self.archivePageLabel:SetText(string.format(T.ARCHIVE_PAGE, self.archivePage, maxPage))
    end
    if self.archivePrevButton then self.archivePrevButton:SetEnabled(self.archivePage > 1) end
    if self.archiveNextButton then self.archiveNextButton:SetEnabled(self.archivePage < maxPage) end
end

local function CreateArchiveRow(index, panel, anchorControl)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl("AtlasArchiveRow" .. index, panel, CT_CONTROL)
    row:SetDimensions(300, 31)
    if index == 1 then
        row:SetAnchor(TOPLEFT, anchorControl, BOTTOMLEFT, 0, 8)
    else
        row:SetAnchor(TOPLEFT, AE.archiveRows[index - 1], BOTTOMLEFT, 0, 2)
    end
    row:SetMouseEnabled(true)

    local bg = wm:CreateControl(nil, row, CT_TEXTURE)
    bg:SetAnchorFill(row)
    bg:SetColor(0.08, 0.08, 0.08, 0.45)
    row.bg = bg

    local nameLabel = wm:CreateControl(nil, row, CT_LABEL)
    nameLabel:SetAnchor(LEFT, row, LEFT, 8, 0)
    nameLabel:SetDimensions(284, 28)
    nameLabel:SetFont("ZoFontGame")
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    row.nameLabel = nameLabel

    local function ChangePage(delta)
        AE:SetArchivePage((AE.archivePage or 1) + delta)
    end

    row:SetHandler("OnMouseEnter", function(self)
        self.bg:SetColor(0.20, 0.27, 0.28, 0.72)
        if self.entry then
            InitializeTooltip(InformationTooltip, self, LEFT, -8, 0, RIGHT)
            InformationTooltip:AddLine(self.entry.name, "ZoFontGameBold", 0.50, 0.78, 1.00)
            InformationTooltip:AddLine(T.ARCHIVE_OPEN_HINT, "ZoFontGame", 0.86, 0.80, 0.63)
        end
    end)
    row:SetHandler("OnMouseExit", function(self)
        self.bg:SetColor(0.08, 0.08, 0.08, 0.45)
        ClearTooltip(InformationTooltip)
    end)
    row:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and self.entry then AE:OpenArchivedMap(self.entry) end
    end)
    row:SetHandler("OnMouseWheel", function(_, delta)
        if delta > 0 then ChangePage(-1) elseif delta < 0 then ChangePage(1) end
    end)
    return row
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

    local title = wm:CreateControl(nil, panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    title:SetDimensions(300, 26)
    title:SetFont("ZoFontWinH2")
    title:SetText("|c7FC7FF" .. T.ARCHIVE_TITLE .. "|r")
    self.archiveTitleLabel = title

    local subtitle = wm:CreateControl(nil, panel, CT_LABEL)
    subtitle:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 0)
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

    self.archiveRows = {}
    for i = 1, ARCHIVE_ROWS_PER_PAGE do
        self.archiveRows[i] = CreateArchiveRow(i, panel, countLabel)
    end

    local footer = wm:CreateControl(nil, panel, CT_CONTROL)
    footer:SetDimensions(300, 30)
    footer:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 0, -4)

    local prev = wm:CreateControl(nil, footer, CT_BUTTON)
    prev:SetAnchor(LEFT, footer, LEFT, 0, 0)
    prev:SetDimensions(80, 28)
    prev:SetFont("ZoFontGame")
    prev:SetText(T.ARCHIVE_PREV)
    prev:SetHandler("OnClicked", function() AE:SetArchivePage((AE.archivePage or 1) - 1) end)
    self.archivePrevButton = prev

    local pageLabel = wm:CreateControl(nil, footer, CT_LABEL)
    pageLabel:SetAnchor(CENTER, footer, CENTER, 0, 0)
    pageLabel:SetDimensions(120, 28)
    pageLabel:SetFont("ZoFontGame")
    pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    pageLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.archivePageLabel = pageLabel

    local nextButton = wm:CreateControl(nil, footer, CT_BUTTON)
    nextButton:SetAnchor(RIGHT, footer, RIGHT, 0, 0)
    nextButton:SetDimensions(80, 28)
    nextButton:SetFont("ZoFontGame")
    nextButton:SetText(T.ARCHIVE_NEXT)
    nextButton:SetHandler("OnClicked", function() AE:SetArchivePage((AE.archivePage or 1) + 1) end)
    self.archiveNextButton = nextButton

    panel:SetHandler("OnMouseWheel", function(_, delta)
        if delta > 0 then AE:SetArchivePage((AE.archivePage or 1) - 1)
        elseif delta < 0 then AE:SetArchivePage((AE.archivePage or 1) + 1) end
    end)

    return true
end

function AE:RefreshArchiveLocalization()
    if self.archiveTitleLabel then self.archiveTitleLabel:SetText("|c7FC7FF" .. T.ARCHIVE_TITLE .. "|r") end
    if self.archiveSubtitleLabel then self.archiveSubtitleLabel:SetText(T.ARCHIVE_SUBTITLE) end
    if self.archivePrevButton then self.archivePrevButton:SetText(T.ARCHIVE_PREV) end
    if self.archiveNextButton then self.archiveNextButton:SetText(T.ARCHIVE_NEXT) end
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

    ZO_CreateStringId("SI_ATLAS_ARCHIVE_MODE", "Atlas")
    self.archiveFragment = ZO_FadeSceneFragment:New(self.archivePanel)

    local buttonData = {
        normal = "EsoUI/Art/MainMenu/menubar_journal_up.dds",
        pressed = "EsoUI/Art/MainMenu/menubar_journal_down.dds",
        highlight = "EsoUI/Art/MainMenu/menubar_journal_over.dds",
        callback = function()
            AE.archivePage = 1
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
            AE.archivePage = 1
            AE:RefreshArchiveList()
            AE:StartArchiveResolver()
        end
    end, 100)
end
