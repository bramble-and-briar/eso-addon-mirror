AtlasAddon = AtlasAddon or {}
local AE = AtlasAddon

-- Atlas folgt automatisch der ESO-Clientsprache. Englisch dient als Fallback.
AE:SetLanguage("auto")
local T = AE.T

AE.name = "Atlas"
AE.version = "2.0.0"
AE.savedVersion = 1
AE.dataFormat = 2
AE.gridSize = 48
AE.bitsPerNumber = 31
AE.totalCells = AE.gridSize * AE.gridSize
AE.blockCount = math.ceil(AE.totalCells / AE.bitsPerNumber)
AE.textureRoot = "Atlas/textures/"

AE.defaultsSettings = {
    enabled = true,
    style = "pergament",
    opacity = 1.0,
    radius = 2,
    subzoneRadius = 3,
    exploreSubzones = true,
    refreshMilliseconds = 750,
    worldMigrationVersion = 0,
}

AE.defaultsProgress = {
    maps = {},
    imports = {},
    dataFormat = AE.dataFormat,
    worldMigrationVersion = 0,
}

AE.styleFiles = {
    pergament = "pergament_atlas.dds",
    papier = "papier_atlas.dds",
    pergament_dunkel = "pergament_dunkel_atlas.dds",
    nebel = "nebel_atlas.dds",
    kohle = "kohle_atlas.dds",
    schwarz = "schwarz_atlas.dds",
}

function AE:GetStyleTextureChoices()
    local result = {}
    for _, style in ipairs(T.STYLE_VALUES) do
        result[#result + 1] = self:GetStyleTextureFor(style)
    end
    return result
end

local function Clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function IsWorldMapShowing()
    return ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing()
end

-- Beim ersten Oeffnen der Weltkarte nach einem Login kann ESO die Karten-
-- texturen und die Einblendanimation noch nicht vollstaendig abgeschlossen
-- haben. In diesem Zustand koennen Vertex-Alpha-Werte unserer weichen Maske
-- wieder auf Standardwerte gesetzt werden. Atlas wartet daher auf die erste
-- geladene ESO-Kachel und zeichnet danach noch einmal stabil nach.
function AE:IsWorldMapTextureReady()
    if not ZO_WorldMapContainer1 then return false end
    if ZO_WorldMapContainer1.IsTextureLoaded then
        return ZO_WorldMapContainer1:IsTextureLoaded()
    end
    return true
end

function AE:ScheduleStableOverlayRefresh(delay)
    zo_callLater(function()
        if not IsWorldMapShowing() then return end
        if AE:IsWorldMapTextureReady() then
            AE.pendingOverlayRefresh = false
            AE:RefreshOverlay(true)
        else
            AE.pendingOverlayRefresh = true
        end
    end, delay or 0)
end

local function SetRawBit(bits, col, row)
    if col < 1 or col > AE.gridSize or row < 1 or row > AE.gridSize then return false end
    local index = (row - 1) * AE.gridSize + (col - 1)
    local block = math.floor(index / AE.bitsPerNumber)
    local bit = index % AE.bitsPerNumber
    local bitValue = 2 ^ bit
    local current = tonumber(bits[block]) or 0
    if (math.floor(current / bitValue) % 2) >= 1 then return false end
    bits[block] = current + bitValue
    return true
end

function AE:Msg(text)
    d(T.PREFIX .. tostring(text))
end

function AE:NormalizeMapPath(path)
    if type(path) ~= "string" or path == "" then return nil end

    local normalized = string.lower(path)
    normalized = string.gsub(normalized, "\\", "/")
    normalized = string.gsub(normalized, "^/+", "")
    normalized = string.gsub(normalized, "^esoui/", "")

    local artStart = string.find(normalized, "art/maps/", 1, true)
    if artStart then normalized = string.sub(normalized, artStart) end

    return normalized
end

function AE:GetCurrentMapPath()
    if not GetMapTileTexture then return nil, nil end
    local raw = GetMapTileTexture()
    if type(raw) ~= "string" or raw == "" then return nil, nil end
    return self:NormalizeMapPath(raw), raw
end

function AE:IsWorldLikeMap()
    if not GetMapType then return false end
    local mapType = GetMapType()
    if _G.MAPTYPE_WORLD and mapType == MAPTYPE_WORLD then return true end
    if _G.MAPTYPE_COSMIC and mapType == MAPTYPE_COSMIC then return true end
    if _G.MAPTYPE_ALLIANCE and mapType == MAPTYPE_ALLIANCE then return true end
    return false
end

function AE:IsSubzoneMap()
    if not GetMapType or not _G.MAPTYPE_SUBZONE then return false end
    return GetMapType() == MAPTYPE_SUBZONE
end

function AE:IsTrackableCurrentMap()
    local key = self:GetCurrentMapPath()
    if not key then return false end
    if self:IsWorldLikeMap() then return false end
    if self:IsSubzoneMap() and not self.settings.exploreSubzones then return false end
    return true
end

function AE:EnsureMapFormat(map)
    if type(map) ~= "table" then return nil end
    if type(map.bits) ~= "table" then map.bits = {} end

    -- Alte Atlas-Versionen konnten beim Aufdecken am Kartenrand versehentlich
    -- Bits ausserhalb des 48x48-Rasters anlegen (z. B. Block -1). Sie wurden
    -- zwar nie gezeichnet, sollen aber nicht dauerhaft in SavedVariables bleiben.
    for block in pairs(map.bits) do
        if type(block) == "number" and (block < 0 or block >= self.blockCount) then
            map.bits[block] = nil
        end
    end

    -- Migration der allerersten Atlas-Testfassung. Dort wurden 48-Bit-
    -- Zeilenmasken benutzt. Wir wandeln sie einmalig in ESO-sichere 31-Bit-Blöcke um.
    if type(map.rows) == "table" then
        local oldRows = map.rows
        map.rows = nil
        for row = 1, self.gridSize do
            local mask = tonumber(oldRows[row]) or 0
            if mask > 0 then
                for col = 1, self.gridSize do
                    local bitValue = 2 ^ (col - 1)
                    if (math.floor(mask / bitValue) % 2) >= 1 then
                        SetRawBit(map.bits, col, row)
                    end
                end
            end
        end
    end

    map.dataFormat = self.dataFormat
    return map
end

function AE:GetMapData(key, create)
    if not key then return nil end
    local map = self.progress.maps[key]
    if not map and create then
        map = { bits = {}, full = false, dataFormat = self.dataFormat }
        self.progress.maps[key] = map
    end
    if map then self:EnsureMapFormat(map) end
    return map
end

function AE:GetCellBit(col, row)
    if col < 1 or col > self.gridSize or row < 1 or row > self.gridSize then return nil end
    local index = (row - 1) * self.gridSize + (col - 1)
    local block = math.floor(index / self.bitsPerNumber)
    local bit = index % self.bitsPerNumber
    return block, 2 ^ bit
end

function AE:IsCellDiscovered(map, col, row)
    if not map then return false end
    if map.full then return true end
    self:EnsureMapFormat(map)

    local block, bitValue = self:GetCellBit(col, row)
    if block == nil then return false end
    local value = tonumber(map.bits[block]) or 0
    return (math.floor(value / bitValue) % 2) >= 1
end

function AE:SetCellDiscovered(map, col, row)
    if not map or map.full then return false end
    self:EnsureMapFormat(map)
    return SetRawBit(map.bits, col, row)
end

function AE:MergePackedBlocks(map, incomingBits)
    if not map or map.full or type(incomingBits) ~= "table" then return 0 end
    local added = 0

    for block = 0, self.blockCount - 1 do
        local value = tonumber(incomingBits[block]) or 0
        if value > 0 then
            for bit = 0, self.bitsPerNumber - 1 do
                local index = block * self.bitsPerNumber + bit
                if index >= self.totalCells then break end
                local bitValue = 2 ^ bit
                if (math.floor(value / bitValue) % 2) >= 1 then
                    local row = math.floor(index / self.gridSize) + 1
                    local col = (index % self.gridSize) + 1
                    if self:SetCellDiscovered(map, col, row) then added = added + 1 end
                end
            end
        end
    end

    return added
end

function AE:CaptureCurrentMapMetadata(map, rawPath)
    if type(map) ~= "table" then return end

    if type(rawPath) == "string" and rawPath ~= "" then
        map.lastPath = rawPath
    end

    if GetCurrentMapId then
        local mapId = GetCurrentMapId()
        if type(mapId) == "number" and mapId > 0 then map.mapId = mapId end
    end

    if GetCurrentMapIndex then
        local mapIndex = GetCurrentMapIndex()
        if type(mapIndex) == "number" and mapIndex > 0 then map.mapIndex = mapIndex end
    end

    if GetMapName then
        local mapName = GetMapName()
        if type(mapName) == "string" and mapName ~= "" then map.displayName = mapName end
    end

    if GetMapType then map.mapType = GetMapType() end
    if GetMapContentType then map.contentType = GetMapContentType() end
    if GetCurrentMapZoneIndex then map.zoneIndex = GetCurrentMapZoneIndex() end
    if GetTimeStamp then map.lastSeen = GetTimeStamp() end

    -- Sobald die Karte einmal wirklich angezeigt wurde, ist eine eventuell aus
    -- einem Altimport stammende erfolglose Archiv-Suche nicht mehr relevant.
    map.archiveResolveScanned = nil
end

function AE:RevealAtCurrentMapPosition(x, y)
    if not self.settings.enabled or not self:IsTrackableCurrentMap() then return false end
    if type(x) ~= "number" or type(y) ~= "number" then return false end
    if x < 0 or x > 1 or y < 0 or y > 1 then return false end
    if x == 0 and y == 0 then return false end

    local key, raw = self:GetCurrentMapPath()
    if not key then return false end
    local map = self:GetMapData(key, true)
    self:CaptureCurrentMapMetadata(map, raw)
    if map.full then return false end

    local col = Clamp(math.floor(x * self.gridSize) + 1, 1, self.gridSize)
    local row = Clamp(math.floor(y * self.gridSize) + 1, 1, self.gridSize)
    local radius = tonumber(self.settings.radius) or 2
    if self:IsSubzoneMap() then radius = tonumber(self.settings.subzoneRadius) or radius end
    radius = Clamp(math.floor(radius + 0.5), 1, 8)

    local changed = false
    for dy = -radius, radius do
        for dx = -radius, radius do
            if (dx * dx + dy * dy) <= (radius * radius + 0.25) then
                if self:SetCellDiscovered(map, col + dx, row + dy) then changed = true end
            end
        end
    end

    return changed
end

function AE:DiscoverPlayerPosition()
    if not self.settings.enabled then return false end
    if IsWorldMapShowing() then return false end
    if not SetMapToPlayerLocation or not GetMapPlayerPosition then return false end

    local mapWasChanged = SetMapToPlayerLocation() == _G.SET_MAP_RESULT_MAP_CHANGED
    local changedAny = false
    local Coordinates = self.Coordinates
    local canZoomOut = type(MapZoomOut) == "function"
    local hasUniversalCoordinates = Coordinates
        and type(Coordinates.LocalToGlobal) == "function"
        and type(Coordinates.GlobalToLocal) == "function"

    local playerX, playerY = GetMapPlayerPosition("player")
    if type(playerX) ~= "number" or type(playerY) ~= "number" then return false end

    -- In Staedten, Verliesen und anderen Unterkarten darf nicht nur die gerade
    -- aktive Unterkarte Fortschritt bekommen. Der Spieler befindet sich zugleich
    -- weiterhin auf der uebergeordneten Gebietskarte. Deshalb laufen wir, solange
    -- die Weltkarte geschlossen ist, die Elternkarten nach oben ab und decken den
    -- Spielerstandort auf jeder trackbaren Ebene auf.
    --
    -- Atlas wandelt die lokale Spielerposition einmal mit ESOs universeller
    -- Kartenmessung in globale Koordinaten um. Nach jedem Wechsel auf eine
    -- Elternkarte werden dieselben globalen Koordinaten wieder in die lokale
    -- Position dieser Karte zurueckgerechnet. Damit bleibt die Position ueber
    -- Unterkarten und Gebietskarten hinweg deckungsgleich, ohne externe Library.
    local globalX, globalY = nil, nil
    if hasUniversalCoordinates then
        globalX, globalY = Coordinates:LocalToGlobal(playerX, playerY)
    end

    local visited = {}
    while true do
        local key = self:GetCurrentMapPath()
        if not key or visited[key] then break end
        visited[key] = true

        if self:IsWorldLikeMap() then break end

        local revealX, revealY = nil, nil
        if type(globalX) == "number" and type(globalY) == "number" and hasUniversalCoordinates then
            revealX, revealY = Coordinates:GlobalToLocal(globalX, globalY)
        end

        -- Sicherheitsfallback: Sollte ESO fuer eine einzelne Karte keine gueltige
        -- universelle Messung liefern, verwenden wir die Spielerposition auf der
        -- aktuell gesetzten Karte.
        if type(revealX) ~= "number" or type(revealY) ~= "number"
            or revealX < 0 or revealX > 1 or revealY < 0 or revealY > 1
            or (revealX == 0 and revealY == 0) then
            revealX, revealY = GetMapPlayerPosition("player")
        end

        if type(revealX) == "number" and type(revealY) == "number"
            and revealX >= 0 and revealX <= 1 and revealY >= 0 and revealY <= 1
            and not (revealX == 0 and revealY == 0) then
            if self:RevealAtCurrentMapPosition(revealX, revealY) then changedAny = true end
        end

        if not canZoomOut then break end
        if MapZoomOut() ~= _G.SET_MAP_RESULT_MAP_CHANGED then break end
    end

    -- Die versteckte Karteninstanz wieder auf die echte Spielerkarte setzen, damit
    -- wir das ESO-Kartenverhalten fuer andere Addons nicht veraendern.
    SetMapToPlayerLocation()

    if mapWasChanged and CALLBACK_MANAGER then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end

    return changedAny
end

function AE:GetStyleTextureFor(style)
    local fileName = self.styleFiles[style] or self.styleFiles.pergament
    return self.textureRoot .. fileName
end

function AE:GetStyleTexture()
    return self:GetStyleTextureFor(self.settings.style)
end

function AE:GetStyleFromTexture(texturePath)
    if type(texturePath) ~= "string" then return nil end
    local wanted = string.lower(string.gsub(texturePath, "\\", "/"))
    for style, fileName in pairs(self.styleFiles) do
        local candidate = string.lower(string.gsub(self.textureRoot .. fileName, "\\", "/"))
        if wanted == candidate then return style end
    end
    return nil
end

function AE:GetStyleName(style)
    style = style or self.settings.style
    for i, value in ipairs(T.STYLE_VALUES) do
        if value == style then return T.STYLE_NAMES[i] end
    end
    return T.STYLE_NAMES[1]
end

function AE:EnsureOverlay()
    if self.overlay or not WINDOW_MANAGER or not ZO_WorldMapContainer then return end

    self.overlay = WINDOW_MANAGER:CreateControl("AtlasOverlay", ZO_WorldMapContainer, CT_CONTROL)
    self.overlay:SetAnchor(TOPLEFT, ZO_WorldMapContainer, TOPLEFT, 0, 0)
    self.overlay:SetDimensions(1, 1)
    self.overlay:SetMouseEnabled(false)
    self.overlay:SetHidden(true)
    if self.overlay.SetScale then self.overlay:SetScale(1) end

    -- ESOs eigentliche Kartenkacheln liegen im mittleren Draw-Tier auf der
    -- Hintergrundebene. Atlas muss im selben Tier knapp darüber liegen; sonst
    -- wird die Abdeckung zwar erzeugt, aber hinter der Weltkarte gezeichnet.
    -- Die Controls-/Overlay-Ebenen von ESO (Pins, Navigation usw.) bleiben
    -- dadurch weiterhin oberhalb der Atlas-Abdeckung.
    if self.overlay.SetDrawTier then
        local mapTier = ZO_WorldMapContainer.GetDrawTier and ZO_WorldMapContainer:GetDrawTier() or _G.DT_MEDIUM
        if mapTier then self.overlay:SetDrawTier(mapTier) end
    end
    if self.overlay.SetDrawLayer and _G.DL_BACKGROUND then self.overlay:SetDrawLayer(DL_BACKGROUND) end
    if self.overlay.SetDrawLevel then self.overlay:SetDrawLevel(1) end

    -- Atlas zeichnet die Abdeckung als 48x48 Ausschnitte EINER gemeinsamen
    -- Kartentextur. Die Kacheln werden nur bei einem echten Kartenwechsel
    -- neu angeordnet. Beim Zoomen wird der komplette Overlay-Container
    -- synchron skaliert. Das vermeidet 2304 Layout-Aenderungen pro Frame.
    self.maskTilePool = {}
    self.overlayLayoutWidth = 0
    self.overlayLayoutHeight = 0
    self.lastContainerWidth = 0
    self.lastContainerHeight = 0
end

function AE:SetOverlayLayoutSize(width, height)
    if not self.overlay then return end
    if width <= 0 or height <= 0 then return end

    if self.overlay.SetScale then self.overlay:SetScale(1) end
    self.overlay:SetDimensions(width, height)
    self.overlayLayoutWidth = width
    self.overlayLayoutHeight = height
    self.lastContainerWidth = width
    self.lastContainerHeight = height
end

function AE:SyncOverlayToMapDimensions()
    if not self.overlay or self.overlay:IsHidden() or not ZO_WorldMapContainer then return end

    local width, height = ZO_WorldMapContainer:GetDimensions()
    if not width or not height or width <= 0 or height <= 0 then return end

    local baseWidth = tonumber(self.overlayLayoutWidth) or 0
    local baseHeight = tonumber(self.overlayLayoutHeight) or 0
    if baseWidth <= 0 or baseHeight <= 0 then return end

    if math.abs(width - (self.lastContainerWidth or 0)) < 0.05 and math.abs(height - (self.lastContainerHeight or 0)) < 0.05 then
        return
    end

    local scaleX = width / baseWidth
    local scaleY = height / baseHeight

    -- Weltkarten bleiben beim Zoomen proportional. Falls sich das Seiten-
    -- verhaeltnis wider Erwarten aendert (z.B. durch einen UI-Umbau), wird
    -- einmal exakt neu aufgebaut statt den Overlay zu verzerren.
    if math.abs(scaleX - scaleY) > 0.002 or not self.overlay.SetScale then
        self:RefreshOverlay(true)
        return
    end

    self.overlay:SetScale((scaleX + scaleY) * 0.5)
    self.lastContainerWidth = width
    self.lastContainerHeight = height
end

function AE:OnZoomSync()
    if not IsWorldMapShowing() then return end

    -- Nur solange wirklich ein Neuaufbau aussteht, pruefen wir pro Frame, ob
    -- ESOs Kartenkachel inzwischen geladen ist. Danach bleibt wie bisher nur
    -- die sehr leichte Zoom-Synchronisation aktiv.
    if self.pendingOverlayRefresh then
        if self:IsWorldMapTextureReady() then
            self.pendingOverlayRefresh = false
            self:RefreshOverlay(true)
        end
        return
    end

    self:SyncOverlayToMapDimensions()
end

function AE:GetMaskTile(index)
    local tile = self.maskTilePool[index]
    if tile then return tile end

    tile = WINDOW_MANAGER:CreateControl("AtlasMaskTile" .. index, self.overlay, CT_TEXTURE)
    tile:SetMouseEnabled(false)
    if tile.SetDrawTier and self.overlay.GetDrawTier then tile:SetDrawTier(self.overlay:GetDrawTier()) end
    if tile.SetDrawLayer and _G.DL_BACKGROUND then tile:SetDrawLayer(DL_BACKGROUND) end
    if tile.SetDrawLevel then tile:SetDrawLevel(2) end
    tile:SetHidden(true)
    self.maskTilePool[index] = tile
    return tile
end

function AE:HideUnusedMaskTiles(firstUnused)
    for i = firstUnused, #self.maskTilePool do
        self.maskTilePool[i]:SetHidden(true)
    end
end

local DEFAULT_TE_RADIUS = {
    [768] = 4,
    [1280] = 3,
    [1536] = 2,
    [2048] = 1,
    [5120] = 1,
}

function AE:GetLegacyTERadiusForCurrentMap()
    local radiusTable = DEFAULT_TE_RADIUS
    local importInfo = self.progress and self.progress.imports and self.progress.imports.trueExploration
    if importInfo and type(importInfo.radius) == "table" then radiusTable = importInfo.radius end

    local numTiles = GetMapNumTiles and GetMapNumTiles() or nil
    local tileSize = nil
    if ZO_WorldMapContainer1 and ZO_WorldMapContainer1.GetTextureFileDimensions then
        tileSize = ZO_WorldMapContainer1:GetTextureFileDimensions()
    end
    if type(numTiles) ~= "number" or type(tileSize) ~= "number" or numTiles <= 0 or tileSize <= 0 then
        return 1
    end

    local mapSize = numTiles * tileSize
    local chosen, smallest = 1, math.huge
    for size, radius in pairs(radiusTable) do
        size = tonumber(size)
        radius = tonumber(radius)
        if size and radius and size >= mapSize and size < smallest then
            smallest = size
            chosen = radius
        end
    end
    chosen = math.floor((chosen or 1) + 0.5)
    if chosen < 1 then chosen = 1 end
    if chosen > 8 then chosen = 8 end
    return chosen
end

function AE:PrepareLegacyTEVisualBits(map)
    if type(map) ~= "table" or type(map.legacyTEBits) ~= "table" then return nil end

    local key = self:GetCurrentMapPath()
    local units = self:GetLegacyTERadiusForCurrentMap()
    if self.legacyTECache and self.legacyTECache.map == map and self.legacyTECache.key == key
        and self.legacyTECache.units == units then
        return self.legacyTECache.bits
    end

    local visual = {}
    local half = math.floor(units / 2)
    for block = 0, self.blockCount - 1 do
        local packed = tonumber(map.legacyTEBits[block]) or 0
        if packed > 0 then
            for bit = 0, self.bitsPerNumber - 1 do
                local index = block * self.bitsPerNumber + bit
                if index >= self.totalCells then break end
                local bitValue = 2 ^ bit
                if (math.floor(packed / bitValue) % 2) >= 1 then
                    local row = math.floor(index / self.gridSize) + 1
                    local col = (index % self.gridSize) + 1
                    -- TrueExploration speicherte nur den besuchten Mittelpunkt.
                    -- Sichtbar war dort aber je nach Kartengroesse ein 1x1 bis
                    -- 4x4 grosser Bereich. Beim Import stellen wir genau diese
                    -- alte Darstellung wieder her, ohne Atlas-eigene Daten zu
                    -- veraendern.
                    for dy = -half, -half + units - 1 do
                        for dx = -half, -half + units - 1 do
                            SetRawBit(visual, col + dx, row + dy)
                        end
                    end
                end
            end
        end
    end

    self.legacyTECache = { map = map, key = key, units = units, bits = visual }
    return visual
end

function AE:IsLegacyTECellDiscovered(map, col, row)
    if col < 1 or col > self.gridSize or row < 1 or row > self.gridSize then return false end
    if not map or map.legacyTEFull then return map and map.legacyTEFull == true end
    local bits = self:PrepareLegacyTEVisualBits(map)
    if not bits then return false end
    local block, bitValue = self:GetCellBit(col, row)
    if block == nil then return false end
    local value = tonumber(bits[block]) or 0
    return (math.floor(value / bitValue) % 2) >= 1
end

function AE:GetCoverValue(map, col, row)
    if col < 1 or col > self.gridSize or row < 1 or row > self.gridSize then return nil end
    if self:IsCellDiscovered(map, col, row) then return 0 end
    if self:IsLegacyTECellDiscovered(map, col, row) then return 0 end
    return 1
end

-- Die Deckkraft an einem Gitter-Eckpunkt wird aus den bis zu vier
-- angrenzenden Erkundungsfeldern gebildet. Benachbarte Texturen benutzen
-- damit exakt dieselben Eckwerte. ESO interpoliert zwischen diesen vier
-- Werten und erzeugt einen weichen, nahtlosen Übergang an der Entdeckungsgrenze.
function AE:GetVertexCover(map, vertexCol, vertexRow)
    local sum, count = 0, 0

    for dy = 0, 1 do
        for dx = 0, 1 do
            local value = self:GetCoverValue(map, vertexCol + dx, vertexRow + dy)
            if value ~= nil then
                sum = sum + value
                count = count + 1
            end
        end
    end

    if count == 0 then return 1 end
    return sum / count
end

function AE:SetMaskTileVertexAlpha(tile, topLeft, topRight, bottomLeft, bottomRight, opacity)
    local function setVertex(point, value)
        tile:SetVertexColors(point, 1, 1, 1, Clamp(value * opacity, 0, 1))
    end

    setVertex(VERTEX_POINTS_TOPLEFT, topLeft)
    setVertex(VERTEX_POINTS_TOPRIGHT, topRight)
    setVertex(VERTEX_POINTS_BOTTOMLEFT, bottomLeft)
    setVertex(VERTEX_POINTS_BOTTOMRIGHT, bottomRight)
end

function AE:RefreshOverlay(force)
    self:EnsureOverlay()
    if not self.overlay then return end

    if not IsWorldMapShowing() or not self.settings.enabled or not self:IsTrackableCurrentMap() then
        self.overlay:SetHidden(true)
        self:HideUnusedMaskTiles(1)
        return
    end

    -- Noch nicht gegen eine halb geladene ESO-Weltkarte zeichnen. Genau das
    -- fuehrte nach einem Spielstart zu den rechteckigen Puzzleflaechen.
    if not self:IsWorldMapTextureReady() then
        self.pendingOverlayRefresh = true
        self.overlay:SetHidden(true)
        return
    end
    self.pendingOverlayRefresh = false

    local key = self:GetCurrentMapPath()
    if not key then
        self.overlay:SetHidden(true)
        self:HideUnusedMaskTiles(1)
        return
    end

    local map = self:GetMapData(key, false)
    if map and map.full then
        self.overlay:SetHidden(true)
        self:HideUnusedMaskTiles(1)
        return
    end

    local width, height = ZO_WorldMapContainer:GetDimensions()
    if not width or not height or width <= 0 or height <= 0 then return end

    self:SetOverlayLayoutSize(width, height)
    self.overlay:SetHidden(false)
    local cellW = width / self.gridSize
    local cellH = height / self.gridSize
    local texturePath = self:GetStyleTexture()
    local opacity = Clamp(tonumber(self.settings.opacity) or 1.0, 0.10, 1.0)
    local tileIndex = 1

    for row = 1, self.gridSize do
        local v0 = (row - 1) / self.gridSize
        local v1 = row / self.gridSize

        for col = 1, self.gridSize do
            local u0 = (col - 1) / self.gridSize
            local u1 = col / self.gridSize

            -- Gitter-Eckpunkte sind 0..48. Ein Eckpunkt mittelt die dort
            -- zusammentreffenden Erkundungsfelder und wird dadurch weich.
            local topLeft = self:GetVertexCover(map, col - 1, row - 1)
            local topRight = self:GetVertexCover(map, col, row - 1)
            local bottomLeft = self:GetVertexCover(map, col - 1, row)
            local bottomRight = self:GetVertexCover(map, col, row)

            -- Vollständig transparente Zellen brauchen nicht gezeichnet zu werden.
            if topLeft > 0.001 or topRight > 0.001 or bottomLeft > 0.001 or bottomRight > 0.001 then
                local tile = self:GetMaskTile(tileIndex)
                tileIndex = tileIndex + 1

                tile:ClearAnchors()
                tile:SetAnchor(TOPLEFT, self.overlay, TOPLEFT, (col - 1) * cellW, (row - 1) * cellH)
                tile:SetDimensions(cellW, cellH)
                tile:SetTexture(texturePath)
                tile:SetTextureCoords(u0, u1, v0, v1)
                tile:SetAlpha(1)
                self:SetMaskTileVertexAlpha(tile, topLeft, topRight, bottomLeft, bottomRight, opacity)
                tile:SetHidden(false)
            end
        end
    end

    self:HideUnusedMaskTiles(tileIndex)
    self.lastContainerWidth = width
    self.lastContainerHeight = height
end

function AE:RevealCurrentMapFully()
    local key, raw = self:GetCurrentMapPath()
    if not key then self:Msg(T.NO_MAP) return end

    local map = self:GetMapData(key, true)
    self:CaptureCurrentMapMetadata(map, raw)
    map.full = true
    map.bits = {}
    map.legacyTEBits = nil
    map.legacyTEFull = nil
    self.legacyTECache = nil
    self:RefreshOverlay(true)
    self:Msg(T.CURRENT_MAP_REVEALED)
end

function AE:ClearCurrentMap()
    local key = self:GetCurrentMapPath()
    if not key then self:Msg(T.NO_MAP) return end
    self.progress.maps[key] = nil
    self.legacyTECache = nil
    self:RefreshOverlay(true)
    self:Msg(T.CURRENT_MAP_CLEARED)
end

function AE:CountMapCells(map)
    if not map then return 0 end
    if map.full then return self.totalCells end
    self:EnsureMapFormat(map)

    local count = 0
    for block = 0, self.blockCount - 1 do
        local value = tonumber(map.bits[block]) or 0
        if value > 0 then
            for bit = 0, self.bitsPerNumber - 1 do
                local index = block * self.bitsPerNumber + bit
                if index >= self.totalCells then break end
                if (math.floor(value / (2 ^ bit)) % 2) >= 1 then count = count + 1 end
            end
        end
    end
    return count
end

function AE:ShowStatus()
    local key, raw = self:GetCurrentMapPath()
    if not key then self:Msg(T.NO_MAP) return end
    local map = self:GetMapData(key, false)
    local count = self:CountMapCells(map)
    self:Msg(string.format(T.STATUS, raw or key, count, self.totalCells, count * 100 / self.totalCells, self:GetStyleName()))
end

function AE:SetStyleByIndex(index)
    index = tonumber(index)
    if not index or not T.STYLE_VALUES[index] then self:Msg(T.BAD_VALUE) return end
    self.settings.style = T.STYLE_VALUES[index]
    self:RefreshOverlay(true)
    self:Msg(string.format(T.STYLE_SET, T.STYLE_NAMES[index]))
end

function AE:SetRadius(value)
    value = tonumber(value)
    if not value or value < 1 or value > 8 then self:Msg(T.BAD_VALUE) return end
    self.settings.radius = math.floor(value + 0.5)
    self:Msg(string.format(T.RADIUS_SET, self.settings.radius))
end

function AE:SetOpacityPercent(value)
    value = tonumber(value)
    if not value or value < 10 or value > 100 then self:Msg(T.BAD_VALUE) return end
    self.settings.opacity = value / 100
    self:RefreshOverlay(true)
    self:Msg(string.format(T.OPACITY_SET, math.floor(value + 0.5)))
end

function AE:HandleSlash(text)
    text = zo_strtrim(text or "")
    local command, rest = string.match(text, "^(%S+)%s*(.-)$")
    command = command and string.lower(command) or "settings"

    if command == "settings" or command == "setting" or command == "optionen" or command == "einstellungen" then
        if self.OpenSettings then self:OpenSettings() end
    elseif command == "hilfe" or command == "help" or command == "?" then
        self:Msg(T.HELP)
    elseif command == "an" or command == "on" or command == "enable" then
        self.settings.enabled = true
        self:RefreshOverlay(true)
        self:Msg(T.ENABLED)
    elseif command == "aus" or command == "off" or command == "disable" then
        self.settings.enabled = false
        self:RefreshOverlay(true)
        self:Msg(T.DISABLED)
    elseif command == "aufdecken" or command == "reveal" then
        self:RevealCurrentMapFully()
    elseif command == "vergessen" or command == "loeschen" or command == "löschen" or command == "forget" or command == "clear" then
        self:ClearCurrentMap()
    elseif command == "import" then
        self:ImportTrueExploration(false)
    elseif command == "importalle" or command == "importall" then
        self:ImportTrueExploration(true)
    elseif command == "status" then
        self:ShowStatus()
    elseif command == "archiv" or command == "archive" then
        if self.OpenArchive then self:OpenArchive() end
    elseif command == "stil" or command == "style" then
        self:SetStyleByIndex(rest)
    elseif command == "radius" then
        self:SetRadius(rest)
    elseif command == "deckkraft" or command == "opacity" then
        self:SetOpacityPercent(rest)
    else
        self:Msg(T.BAD_VALUE)
    end
end

function AE:MigrateOwnSavedData()
    if type(self.progress.maps) ~= "table" then self.progress.maps = {} end
    for _, map in pairs(self.progress.maps) do
        if type(map) == "table" then self:EnsureMapFormat(map) end
    end
    self.progress.dataFormat = self.dataFormat
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(child, seen)
    end
    return copy
end

function AE:GetLegacyDefaultProfileData()
    local root = _G.Atlas_SavedVars
    if type(root) ~= "table" then return nil, nil end

    local legacy = root["Default"]
    if type(legacy) ~= "table" then return nil, nil end

    local displayName = GetDisplayName and GetDisplayName() or nil
    if type(displayName) ~= "string" or displayName == "" then return nil, nil end

    local account = legacy[displayName]
    if type(account) ~= "table" then return nil, nil end

    local settings = nil
    local accountWide = account["$AccountWide"]
    if type(accountWide) == "table" and type(accountWide.Einstellungen) == "table" then
        settings = DeepCopy(accountWide.Einstellungen)
    end

    local progress = nil
    local characterId = GetCurrentCharacterId and GetCurrentCharacterId() or nil
    if characterId ~= nil then
        local character = account[characterId] or account[tostring(characterId)]
        if type(character) == "table" and type(character.Fortschritt) == "table" then
            progress = DeepCopy(character.Fortschritt)
        end
    end

    return settings, progress
end

local function CopyInto(target, source, excludedKey)
    if type(target) ~= "table" or type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if key ~= excludedKey then
            target[key] = DeepCopy(value)
        end
    end
end

function AE:MigrateLegacyDefaultProfileToWorld(legacySettings, legacyProgress)
    -- Atlas <= 0.7.0 stored everything in ZO_SavedVars' implicit "Default"
    -- profile. ESOUI recommends server/world-specific profiles so EU, NA and PTS
    -- cannot overwrite one another. Each world performs this migration once.
    if tonumber(self.settings.worldMigrationVersion) ~= 1 then
        if type(legacySettings) == "table" then
            CopyInto(self.settings, legacySettings, "worldMigrationVersion")
        end
        self.settings.worldMigrationVersion = 1
    end

    if tonumber(self.progress.worldMigrationVersion) ~= 1 then
        if type(legacyProgress) == "table" then
            CopyInto(self.progress, legacyProgress, "worldMigrationVersion")
        end
        self.progress.worldMigrationVersion = 1
    end
end

function AE:OnUpdate()
    if not IsWorldMapShowing() then
        self:DiscoverPlayerPosition()
        if self.overlay then self.overlay:SetHidden(true) end
        return
    end

    local key = self:GetCurrentMapPath()
    local mapChanged = key ~= self.lastMapKey
    if mapChanged then
        self.lastMapKey = key
        self:RefreshOverlay(true)
    end
end

function AE:Initialize()
    -- Snapshot the pre-0.7.1 default-profile data before opening the new world-specific
    -- SavedVariables profile. This preserves existing maps/settings on the first load.
    local legacySettings, legacyProgress = self:GetLegacyDefaultProfileData()
    local worldName = (GetWorldName and GetWorldName()) or "Default"

    self.settings = ZO_SavedVars:NewAccountWide("Atlas_SavedVars", self.savedVersion, "Einstellungen", self.defaultsSettings, worldName)
    self.progress = ZO_SavedVars:NewCharacterIdSettings("Atlas_SavedVars", self.savedVersion, "Fortschritt", self.defaultsProgress, worldName)
    self:MigrateLegacyDefaultProfileToWorld(legacySettings, legacyProgress)
    self:SetLanguage("auto")
    self:MigrateOwnSavedData()

    self:EnsureOverlay()
    if self.SetupSettings then self:SetupSettings() end
    if self.SetupAddonListIntegration then self:SetupAddonListIntegration() end
    if self.SetupArchive then self:SetupArchive() end

    SLASH_COMMANDS["/atlas"] = function(text) self:HandleSlash(text) end
    SLASH_COMMANDS["/ae"] = function(text) self:HandleSlash(text) end

    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
            AE.pendingOverlayRefresh = true
            AE:RefreshOverlay(true)
            -- Ein zweiter Durchgang nach der ESO-Kartenanimation stellt sicher,
            -- dass die weichen Vertex-Alphas nicht vom Client zurueckgesetzt bleiben.
            AE:ScheduleStableOverlayRefresh(650)
        end)
    end

    local mapScene = SCENE_MANAGER and SCENE_MANAGER:GetScene("worldMap")
    if mapScene then
        mapScene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then
                AE.pendingOverlayRefresh = true
                AE:ScheduleStableOverlayRefresh(75)
            elseif newState == SCENE_SHOWN then
                -- Besonders der erste Kartenaufruf nach dem Login braucht einen
                -- spaeten Stabilisierungslauf. Das ersetzt keinen Dauer-Refresh.
                AE:ScheduleStableOverlayRefresh(150)
                AE:ScheduleStableOverlayRefresh(750)
            elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                if AE.overlay then AE.overlay:SetHidden(true) end
                AE.pendingOverlayRefresh = false
                AE.lastMapKey = nil
            end
        end)
    end

    -- Beim Login initialisiert ESO einige Weltkartenbestandteile erst nach den
    -- Addons. Wir markieren nur den ersten Kartenaufbau als neu zu zeichnen.
    EVENT_MANAGER:RegisterForEvent(self.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        AE.pendingOverlayRefresh = true
        AE.lastMapKey = nil
    end)

    EVENT_MANAGER:RegisterForUpdate(self.name .. "Update", tonumber(self.settings.refreshMilliseconds) or 750, function() self:OnUpdate() end)
    -- Nur die Zoom-Synchronisation laeuft pro Frame. Sie skaliert genau einen
    -- Container und zeichnet die 48x48 Maske nicht staendig neu.
    EVENT_MANAGER:RegisterForUpdate(self.name .. "ZoomSync", 0, function() self:OnZoomSync() end)
    self:RefreshOverlay(true)
    self:Msg(T.LOADED)
end

function AE.OnAddOnLoaded(_, addonName)
    if addonName ~= AE.name then return end
    EVENT_MANAGER:UnregisterForEvent(AE.name, EVENT_ADD_ON_LOADED)
    AE:Initialize()
end

EVENT_MANAGER:RegisterForEvent(AE.name, EVENT_ADD_ON_LOADED, AE.OnAddOnLoaded)
