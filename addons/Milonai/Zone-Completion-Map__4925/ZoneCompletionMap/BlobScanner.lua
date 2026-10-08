ZoneCompletionMap = ZoneCompletionMap or {}

local BlobScanner = {}
ZoneCompletionMap.BlobScanner = BlobScanner

local GRID_SIZE = 50
-- Fine search around labels whose zone the coarse passes missed, e.g. thin
-- outlines like Stonefalls on the Tamriel map.
local LABEL_SEARCH_RADIUS = 0.06
local LABEL_SEARCH_STEP = 0.002
local cache = {}

-- Finds the zone highlight textures of the current map by probing points with
-- the mouseover API: first every zone label position, then a regular grid, then
-- a fine search around every label whose zone is still missing.
-- Results are deduplicated by texture path, in order of discovery.
function BlobScanner.Scan(api, gridSize)
    local blobs = {}
    local seen = {}
    local foundNames = {}

    -- Returns the normalized location name when a blob was added or already known.
    local function probe(nx, ny)
        local locationName, texture, w, h, x, y, mapId = api.mouseover(nx, ny)
        if not texture or texture == "" then
            return nil
        end
        local name = api.normalizeName(locationName)
        if seen[texture] then
            return name
        end
        local zoneId = mapId and api.zoneIdForMapId(mapId)
        if not zoneId then
            return nil
        end
        seen[texture] = true
        foundNames[name] = true
        blobs[#blobs + 1] = { zoneId = zoneId, texture = texture, x = x, y = y, w = w, h = h }
        return name
    end

    for i = 1, api.getNumLabels() do
        local nx, ny = api.getLabelPos(i)
        probe(nx, ny)
    end
    for row = 1, gridSize do
        local ny = (row - 0.5) / gridSize
        for col = 1, gridSize do
            probe((col - 0.5) / gridSize, ny)
        end
    end

    local steps = zo_floor(LABEL_SEARCH_RADIUS / LABEL_SEARCH_STEP)
    for i = 1, api.getNumLabels() do
        local nx, ny, labelName = api.getLabelPos(i)
        local wanted = api.normalizeName(labelName)
        if wanted ~= "" and not foundNames[wanted] then
            local matched = false
            for dy = -steps, steps do
                for dx = -steps, steps do
                    local px, py = nx + dx * LABEL_SEARCH_STEP, ny + dy * LABEL_SEARCH_STEP
                    if px >= 0 and px <= 1 and py >= 0 and py <= 1 then
                        local locationName, texture = api.mouseover(px, py)
                        if texture and texture ~= "" and api.normalizeName(locationName) == wanted then
                            probe(px, py)
                            matched = true
                            break
                        end
                    end
                end
                if matched then
                    break
                end
            end
        end
    end

    return blobs
end

function BlobScanner.DefaultApi()
    return {
        getNumLabels = GetNumMapBlobs,
        getLabelPos = function(i)
            local labelName, nx, ny = GetMapBlobNameInfo(i)
            return nx, ny, labelName
        end,
        mouseover = GetMapMouseoverInfo,
        -- Strips grammar suffixes such as "^N,in" so label and location names compare.
        normalizeName = function(name)
            if not name or name == "" then
                return ""
            end
            return zo_strformat("<<1>>", name)
        end,
        zoneIdForMapId = function(mapId)
            if mapId == 0 then
                return nil
            end
            local zoneIndex = GetZoneIndexByMapId(mapId)
            if not zoneIndex or zoneIndex == 0 then
                return nil
            end
            local zoneId = GetZoneId(zoneIndex)
            if not zoneId or zoneId == 0 then
                return nil
            end
            -- Zone Guide data is keyed by the zone-story zone; fall back to the map's zone.
            local storyZoneId = GetZoneStoryZoneIdForZoneId(zoneId)
            if storyZoneId and storyZoneId ~= 0 then
                return storyZoneId
            end
            return zoneId
        end,
    }
end

-- Blobs of the currently displayed map, which must have the given mapId.
function BlobScanner.GetBlobs(mapId)
    if not cache[mapId] then
        cache[mapId] = BlobScanner.Scan(BlobScanner.DefaultApi(), GRID_SIZE)
    end
    return cache[mapId]
end
