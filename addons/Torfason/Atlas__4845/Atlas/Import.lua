local AE = AtlasAddon
local T = AE.T

local function IsMapPath(value)
    if type(value) ~= "string" then return false end
    local lowered = string.lower(string.gsub(value, "\\", "/"))
    return string.find(lowered, "art/maps/", 1, true) ~= nil and string.find(lowered, ".dds", 1, true) ~= nil
end

local function NewDecoded()
    return { full = false, bits = {}, recognized = false }
end

local function SetDecodedCell(decoded, col, row)
    if col < 1 or col > AE.gridSize or row < 1 or row > AE.gridSize then return end
    local index = (row - 1) * AE.gridSize + (col - 1)
    local block = math.floor(index / AE.bitsPerNumber)
    local bit = index % AE.bitsPerNumber
    local bitValue = 2 ^ bit
    local current = tonumber(decoded.bits[block]) or 0
    if (math.floor(current / bitValue) % 2) < 1 then decoded.bits[block] = current + bitValue end
end

local function DecodeModern31Bit(value, decoded)
    local sawNumeric = false
    for block = 0, AE.blockCount - 1 do
        local packed = value[block]
        if packed ~= nil then
            if type(packed) ~= "number" or packed < 0 then return false end
            sawNumeric = true
            packed = math.floor(packed + 0.5)
            for bit = 0, AE.bitsPerNumber - 1 do
                local index = block * AE.bitsPerNumber + bit
                if index >= AE.totalCells then break end
                local bitValue = 2 ^ bit
                if (math.floor(packed / bitValue) % 2) >= 1 then
                    local row = math.floor(index / AE.gridSize) + 1
                    local col = (index % AE.gridSize) + 1
                    SetDecodedCell(decoded, col, row)
                end
            end
        end
    end
    return sawNumeric
end

local function DecodeVeryOld50x50(value, decoded)
    local sawBoolean = false
    for index, found in pairs(value) do
        if type(index) == "number" and type(found) == "boolean" then
            sawBoolean = true
            if found then
                local oldY = math.floor(index / 50)
                local oldX = index % 50
                if oldX > 0 and oldX < 49 and oldY > 0 and oldY < 49 then
                    -- Das historische 50x50-Format hatte einen Rand. Nach dessen
                    -- Entfernung entsprechen oldX/oldY direkt unseren 1-basierten Zellen.
                    SetDecodedCell(decoded, oldX, oldY)
                end
            end
        end
    end
    return sawBoolean
end

local function DecodeTrueExplorationMap(value)
    local decoded = NewDecoded()
    if type(value) ~= "table" then return decoded end

    if value.discovered == true then
        decoded.full = true
        decoded.recognized = true
        return decoded
    end

    -- Aktuelles TrueExploration-Format: 2304 fortlaufende Zellen, jeweils
    -- 31 Bits pro gespeicherter Zahl (Blöcke 0..74).
    if DecodeModern31Bit(value, decoded) then
        decoded.recognized = true
        return decoded
    end

    -- Unterstützung für das sehr alte Format vor der Umstellung auf 48x48.
    if DecodeVeryOld50x50(value, decoded) then
        decoded.recognized = true
        return decoded
    end

    -- Eine leere Tabelle ist ebenfalls eine gültige, nur noch völlig
    -- unerforschte TrueExploration-Karte.
    if next(value) == nil then decoded.recognized = true end
    return decoded
end

local function ContainsMapEntries(tbl)
    if type(tbl) ~= "table" then return false end
    for key in pairs(tbl) do
        if IsMapPath(key) then return true end
    end
    return false
end

local function FindAllMapTables(root)
    local result = {}
    local visited = {}
    local added = {}

    local function AddMapTable(tbl)
        if not added[tbl] then
            added[tbl] = true
            result[#result + 1] = tbl
        end
    end

    local function Walk(tbl, depth)
        if depth > 10 or type(tbl) ~= "table" or visited[tbl] then return end
        visited[tbl] = true

        if type(tbl.maps) == "table" and ContainsMapEntries(tbl.maps) then AddMapTable(tbl.maps) end

        for _, child in pairs(tbl) do
            if type(child) == "table" then Walk(child, depth + 1) end
        end
    end

    Walk(root, 0)
    return result
end

local function CurrentCharacterMapTable()
    local TE = _G.TrueExplor
    if type(TE) == "table" and type(TE.save) == "table" and type(TE.save.maps) == "table" then
        return TE.save.maps
    end
    return nil
end

local function CopyPackedBits(bits)
    local copy = {}
    if type(bits) ~= "table" then return copy end
    for block = 0, AE.blockCount - 1 do
        local value = tonumber(bits[block]) or 0
        if value > 0 then copy[block] = math.floor(value + 0.5) end
    end
    return copy
end

local function CopyTERadiusSettings()
    local TE = _G.TrueExplor
    local source = nil
    if type(TE) == "table" then
        if type(TE.settings) == "table" and type(TE.settings.radius) == "table" then
            source = TE.settings.radius
        elseif type(TE.save) == "table" and type(TE.save.radius) == "table" then
            source = TE.save.radius
        end
    end
    if type(source) ~= "table" then return nil end
    local result = {}
    for size, radius in pairs(source) do
        if type(size) == "number" and type(radius) == "number" then result[size] = radius end
    end
    return result
end

local function CasePreservingMapPath(path)
    if type(path) ~= "string" then return nil end
    local cleaned = string.gsub(path, "\\", "/")
    cleaned = string.gsub(cleaned, "^/+", "")
    cleaned = string.gsub(cleaned, "^[Ee][Ss][Oo][Uu][Ii]/", "")
    local lower = string.lower(cleaned)
    local pos = string.find(lower, "art/maps/", 1, true)
    if pos then cleaned = string.sub(cleaned, pos) end
    return cleaned
end

local function BuildCurrentMapPathLookup()
    local lookup = {}
    if not GetNumMaps or not GetMapIdByIndex or not GetMapTileTextureForMapId then return lookup end
    local numMaps = GetNumMaps() or 0
    for mapIndex = 1, numMaps do
        local mapId = GetMapIdByIndex(mapIndex)
        if type(mapId) == "number" and mapId > 0 then
            local raw = GetMapTileTextureForMapId(mapId, 1)
            local key = AE:NormalizeMapPath(raw)
            if key and type(raw) == "string" and raw ~= "" then
                lookup[key] = { raw = CasePreservingMapPath(raw), mapId = mapId, mapIndex = mapIndex }
            end
        end
    end
    return lookup
end

local function CombineDecoded(list)
    local combined = NewDecoded()
    for _, item in ipairs(list) do
        local decoded = item.decoded
        if decoded and decoded.recognized then
            combined.recognized = true
            if decoded.full then
                combined.full = true
                combined.bits = {}
                return combined
            end
            for block = 0, AE.blockCount - 1 do
                local incoming = tonumber(decoded.bits[block]) or 0
                if incoming > 0 then
                    local current = tonumber(combined.bits[block]) or 0
                    -- 31-Bit-Werte sind klein genug, um die Vereinigung bitweise
                    -- durch Addition fehlender Einzelbits sicher aufzubauen.
                    for bit = 0, AE.bitsPerNumber - 1 do
                        local bitValue = 2 ^ bit
                        if (math.floor(incoming / bitValue) % 2) >= 1
                            and (math.floor(current / bitValue) % 2) < 1 then
                            current = current + bitValue
                        end
                    end
                    combined.bits[block] = current
                end
            end
        end
    end
    return combined
end

function AE:MergeDecodedTrueExplorationMap(path, decoded, mapMeta)
    local key = self:NormalizeMapPath(path)
    if not key or not decoded.recognized then return 0, false end

    local target = self:GetMapData(key, true)
    target.lastPath = path
    target.archiveResolveScanned = nil
    if mapMeta then
        if mapMeta.mapId then target.mapId = mapMeta.mapId end
        if mapMeta.mapIndex then target.mapIndex = mapMeta.mapIndex end
    end

    -- TrueExploration speicherte nur die besuchten Mittelpunkt-Zellen. Die alte
    -- Anzeige vergroesserte diese Punkte je nach Kartengroesse auf 1x1 bis 4x4.
    -- Wir behalten deshalb eine unveraenderte Kopie der TE-Bits, damit Atlas beim
    -- Zeichnen die alte Darstellung originalgetreu rekonstruieren kann.
    target.legacyTEFull = decoded.full == true
    target.legacyTEBits = decoded.full and {} or CopyPackedBits(decoded.bits)

    if target.full then return 0, true end
    if decoded.full then
        local before = self:CountMapCells(target)
        target.full = true
        target.bits = {}
        return self.totalCells - before, true
    end

    return self:MergePackedBlocks(target, decoded.bits), true
end

function AE:ImportTrueExploration(importAll)
    local source = _G.TE_SavedVars
    if type(source) ~= "table" then
        self:Msg(T.IMPORT_NO_TE)
        return
    end

    self:Msg(T.IMPORT_START)
    local mapTables = {}

    if importAll then
        self:Msg(T.IMPORT_ALL_WARNING)
        mapTables = FindAllMapTables(source)
    else
        local current = CurrentCharacterMapTable()
        if current then mapTables[1] = current end
    end

    if #mapTables == 0 then
        self:Msg(importAll and T.IMPORT_NONE_ALL or T.IMPORT_NONE)
        return
    end

    local found = 0
    local unrecognized = 0
    local cellsAdded = 0
    local mapsMerged = {}
    local groups = {}
    local currentPaths = BuildCurrentMapPathLookup()

    -- Zuerst nach normalisiertem Kartenpfad gruppieren. ESO hat bei einigen
    -- Karten im Lauf der Jahre nur die Gross-/Kleinschreibung des Pfades geaendert.
    -- Alte TrueExploration-Dateien koennen deshalb zwei Staende derselben Karte
    -- enthalten. Atlas bevorzugt den Pfad, den der aktuelle ESO-Client meldet,
    -- statt beide alten Masken blind uebereinander zu legen.
    for _, maps in ipairs(mapTables) do
        for path, value in pairs(maps) do
            if IsMapPath(path) then
                found = found + 1
                local decoded = DecodeTrueExplorationMap(value)
                if decoded.recognized then
                    local key = self:NormalizeMapPath(path)
                    if key then
                        groups[key] = groups[key] or {}
                        groups[key][#groups[key] + 1] = { path = path, decoded = decoded }
                    end
                else
                    unrecognized = unrecognized + 1
                end
            end
        end
    end

    for key, group in pairs(groups) do
        local selected = nil
        local currentMeta = currentPaths[key]
        if currentMeta and currentMeta.raw then
            for _, item in ipairs(group) do
                if CasePreservingMapPath(item.path) == currentMeta.raw then
                    selected = item
                    break
                end
            end
        end

        local decoded, path
        if selected then
            decoded = selected.decoded
            path = selected.path
        elseif #group == 1 then
            decoded = group[1].decoded
            path = group[1].path
        else
            decoded = CombineDecoded(group)
            path = group[1].path
        end

        local added, ok = self:MergeDecodedTrueExplorationMap(path, decoded, currentMeta)
        if ok then
            cellsAdded = cellsAdded + added
            mapsMerged[key] = true
        end
    end

    local mapCount = 0
    for _ in pairs(mapsMerged) do mapCount = mapCount + 1 end

    self.progress.imports.trueExploration = {
        timestamp = GetTimeStamp and GetTimeStamp() or 0,
        allProfiles = importAll == true,
        profiles = #mapTables,
        found = found,
        merged = mapCount,
        cellsAdded = cellsAdded,
        unrecognized = unrecognized,
        sourceFormat = "TrueExploration-31Bit",
        radius = CopyTERadiusSettings(),
        faithfulVisualImport = true,
    }

    self.legacyTECache = nil
    self:RefreshOverlay(true)
    self:Msg(string.format(T.IMPORT_DONE, found, mapCount, cellsAdded, unrecognized))
end
