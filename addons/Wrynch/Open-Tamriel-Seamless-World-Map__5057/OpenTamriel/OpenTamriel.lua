local addon = OpenTamriel
local ADDON_NAME = addon.name
local ui = addon.UI
local WINDOW_MANAGER, EVENT_MANAGER, CALLBACK_MANAGER = WINDOW_MANAGER, EVENT_MANAGER, CALLBACK_MANAGER
local WORLD_MAP_MANAGER, WORLD_MAP_TILES_MANAGER, WORLD_MAP_SCENE = WORLD_MAP_MANAGER, WORLD_MAP_TILES_MANAGER, WORLD_MAP_SCENE
local ZO_WorldMapContainer, ZO_MAP_CONSTANTS = ZO_WorldMapContainer, ZO_MAP_CONSTANTS
local SLASH_COMMANDS, ZO_SavedVars, LAM = SLASH_COMMANDS, ZO_SavedVars, LibAddonMenu2
local math, string, ipairs, pairs, tostring = math, string, ipairs, pairs, tostring
local zo_clamp, d = zo_clamp, d
local GetCurrentMapId, GetFrameTimeSeconds, GetUIMousePosition = GetCurrentMapId, GetFrameTimeSeconds, GetUIMousePosition
local GetMapInfoById, GetMapMouseoverInfo = GetMapInfoById, GetMapMouseoverInfo
local GetMapTileTextureForMapId, GetMapNumTilesForMapId = GetMapTileTextureForMapId, GetMapNumTilesForMapId
local GetUniversallyNormalizedMapInfo, SetMapToMapId = GetUniversallyNormalizedMapInfo, SetMapToMapId
local GetMapInfoByIndex, GetMapIdByIndex, GetNumMaps = GetMapInfoByIndex, GetMapIdByIndex, GetNumMaps
local GetMapBlobNameInfo, GetNumMapBlobs = GetMapBlobNameInfo, GetNumMapBlobs
local GetCurrentMapZoneIndex, GetNumPOIs, GetPOIMapInfo = GetCurrentMapZoneIndex, GetNumPOIs, GetPOIMapInfo
local WouldProcessMapClick = WouldProcessMapClick
local ZO_PreHook, ZO_PostHook, ZO_EaseNormalizedZoom = ZO_PreHook, ZO_PostHook, ZO_EaseNormalizedZoom
local settings
local defaults = { emptyTerrain = true, zoneNames = true, clouds = true }
local TAMRIEL_MAP_ID, CANVAS_SIZE = 27, 1000
local MAX_ZOOM, ZOOM_STEP, ZOOM_SECONDS = 256, 1.32, 0.18
local PIN_FADE_SECONDS = 0.30
local CLOUD_TEXTURES = {
    "OpenTamriel/Textures/Atmosphere/cloud-bank.dds",
    "OpenTamriel/Textures/Atmosphere/cloud-stratus.dds",
    "OpenTamriel/Textures/Atmosphere/cloud-front.dds",
    "OpenTamriel/Textures/Atmosphere/cloud-scattered.dds",
    "OpenTamriel/Textures/Atmosphere/cloud-feather.dds",
    "OpenTamriel/Textures/Atmosphere/cloud-hook.dds",
}
local function RandomizeCloud(spec)
    spec[2], spec[3] = 0.025 + math.random() * 0.95, 0.20 + math.random() * 0.14
    spec.texture = CLOUD_TEXTURES[math.random(#CLOUD_TEXTURES)]
    spec.aspect = 0.40 + math.random() * 0.28
    spec.rotation = math.random() * math.pi * 2
    spec.opacity = 0.38 + math.random() * 0.10
    spec.flipX, spec.flipY = math.random() < 0.5, math.random() < 0.5
end
-- Smaller, staggered banks keep regional approaches from landing in a giant empty gap.
local CLOUD_BANKS = {}
for row = 0, 5 do
    for column = 0, 6 do
        local index = row * 7 + column + 1
        local spec = {
            (column + 0.15 + math.random() * 0.70) / 7, 0, 0, (index - 1) % 2 + 1,
        }
        RandomizeCloud(spec)
        spec[2] = (row + 0.15 + math.random() * 0.70) / 6
        spec.speed = (spec[4] == 1 and 0.0027 or 0.002025) * (0.9 + math.random() * 0.2)
        CLOUD_BANKS[index] = spec
    end
end

-- Separate planes and underground layers do not share Tamriel's surface.
local separateMaps = {
    [108] = true, [255] = true, [1313] = true, [1429] = true,
    [1747] = true, [1782] = true, [1850] = true, [2021] = true,
    [2119] = true, [2275] = true,
}
local world, maps, byId, currentMap
local cosmic, minimumZoom = nil, 1
local sceneWorld
local cloudLayer, cloudRoot, cloudStartedAt
local cloudBanks = ui.cloudBanks
local atlases, backdrop
local backdropOpacity = 0
local originX, originY, worldWidth, worldHeight
local canvas, surface, viewport, pan, labels
local active, changing, applying = false, false, false
local cameraX, cameraY, zoom = 0.5, 0.5, 1
local fitSize, viewWidth, viewHeight
local motion, press, settleAt, modifiedPress
local oldAlpha, oldMin, oldMax = {}
local nativeMouseDown, nativeMouseUp
local pinOpacity, pinZoomOpacity, basePinAlpha, pinTransition = 1, 1, 1, nil
local focusX, focusY, pendingArt
local namedMap, nameProbeX, nameProbeY, nameProbeAt, nameUpdatedAt
local nameMouseX, nameMouseY, nameUseCenter

local function UsesAtlas(id)
    -- Scholarium is an explicitly supported quest hub despite its native content classification.
    if id == 2515 then return true end
    local _, _, content, zoneIndex = GetMapInfoById(id)
    if content ~= MAP_CONTENT_NONE then return false end
    if zoneIndex and zoneIndex > 0 then
        local zoneId = GetZoneId(zoneIndex)
        local parentId = GetParentZoneId(zoneId)
        if zoneId == 181 or zoneId == 584 or parentId == 181 or parentId == 584 then return false end
    end
    return true
end

local function SmoothStep(value)
    local t = zo_clamp(value, 0, 1)
    return t * t * (3 - 2 * t)
end

local function SetPinOpacity(value)
    pinOpacity = value
    ZO_WorldMapContainer:SetAlpha(basePinAlpha * value * pinZoomOpacity)
end

local function FadePins(target, map)
    pinTransition = { start = GetFrameTimeSeconds(), from = pinOpacity, target = target, map = map }
end

local function CancelPinChange()
    if pinTransition and pinTransition.map then FadePins(1) end
end

local function ReadMap(id, unplaced)
    local x, y, width, height = GetUniversallyNormalizedMapInfo(id)
    if not width or width <= 0 or height <= 0 then
        if not unplaced then return end
        x, y, width, height = 0, 0, 0, 0
    end
    local columns, rows = GetMapNumTilesForMapId(id)
    if columns < 1 or rows < 1 then return end
    local map = { id = id, x = x, y = y, width = width, height = height, columns = columns, rows = rows }
    local art = addon.Regions and addon.Regions[id] or addon.Realms and addon.Realms[id]
    if art and columns == art.columns and rows == art.rows then
        local file = GetMapTileTextureForMapId(id, 1):lower():gsub("\\", "/"):gsub("%.dds$", "")
        if file:sub(-#art.source) == art.source then map.art = art end
    end
    return map
end

local function NormalizeMap(map)
    map.x, map.y = (map.x - originX) / worldWidth, (map.y - originY) / worldHeight
    map.width, map.height = map.width / worldWidth, map.height / worldHeight
    map.native = { x = map.x, y = map.y, width = map.width, height = map.height }
end

local function Contains(map, x, y)
    return x >= map.x and x <= map.x + map.width and y >= map.y and y <= map.y + map.height
end

local function RealmForMap(map)
    while map and map.parent do map = map.parent end
    if map == cosmic then return end
    return map and map.realm and map or world
end

local function RememberPortal(parent, x, y, subregion)
    local _, _, width, height, left, top, id = GetMapMouseoverInfo(x, y)
    if not id or id == 0 or id == parent.id or width <= 0 or height <= 0 then return end
    if not UsesAtlas(id) then return end
    if byId[id] then
        local map = byId[id]
        return (map.parent == parent or map.linkParent == parent or map.portalParent == parent) and map or nil
    end
    local _, kind = GetMapInfoById(id)
    if kind ~= MAPTYPE_WORLD and kind ~= MAPTYPE_ZONE and kind ~= MAPTYPE_SUBZONE then return end
    local map = ReadMap(id, true)
    if not map then return end
    if map.width > 0 then NormalizeMap(map) end
    -- Portals are symbolic locations, not universal coordinates shared with Tamriel.
    local side = math.min(width, height)
    map.x, map.y = parent.x + (left + (width - side) / 2) * parent.width,
        parent.y + (top + (height - side) / 2) * parent.height
    map.width, map.height = side * parent.width, side * parent.height
    map.depth = (parent.depth or 0) + 1
    if subregion then
        map.parent, map.realmRoot = parent, RealmForMap(parent)
    else
        map.linkParent = parent
        map.portalParent = parent == cosmic and parent or RealmForMap(parent)
        map.realm = true
    end
    map.outline = { x = map.x, y = map.y, width = map.width, height = map.height }
    maps[#maps + 1], byId[id] = map, map
    return map
end

local function HoverBounds(parent, file, width, height, left, top)
    return { file = file, x = parent.x + left * parent.width, y = parent.y + top * parent.height,
        width = width * parent.width, height = height * parent.height }
end

local function RememberChild(parent, x, y)
    local _, file, width, height, left, top, id = GetMapMouseoverInfo(x, y)
    if not id or id == 0 or id == parent.id then return end
    if not UsesAtlas(id) then return end
    -- Keep the return medallion, clipped to its own native silhouette instead of its surrounding paper.
    local exitId = parent.id == 1747 and 1719 or parent.id == 1850 and 1814
    if parent.footprint and id == exitId and not parent.navigation and file ~= "" and width > 0 and height > 0 then
        local navigation = { footprint = HoverBounds(parent, file, width, height, left, top) }
        for _, key in ipairs({ "id", "x", "y", "width", "height", "columns", "rows", "depth", "parent", "realmRoot" }) do
            navigation[key] = parent[key]
        end
        parent.navigation = navigation
    end
    if byId[id] then
        local map = byId[id]
        return (map.parent == parent or map.linkParent == parent or map.portalParent == parent) and map or nil
    end
    if separateMaps[id] and not parent.realm and not parent.realmRoot then return end
    -- ESO classifies Scholarium differently from dungeon interiors; its Eyevea medallion is authoritative.
    if parent.id == 108 and id == 2515 then return RememberPortal(parent, x, y) end
    local _, mapType, contentType = GetMapInfoById(id)
    local inRealm = parent.realm or parent.realmRoot
    if contentType ~= MAP_CONTENT_NONE then return end
    if mapType ~= MAPTYPE_SUBZONE and not (inRealm and (mapType == MAPTYPE_ZONE or mapType == MAPTYPE_WORLD)) then return end
    local _, parentType = GetMapInfoById(parent.id)
    local subregion = mapType == MAPTYPE_ZONE and (parent.id == 1782 or parentType == MAPTYPE_WORLD)
    local map = ReadMap(id)
    if not map or not parent.native then return inRealm and RememberPortal(parent, x, y, subregion) or nil end
    NormalizeMap(map)
    local native = parent.native
    map.x, map.y = parent.x + (map.x - native.x) * parent.width / native.width,
        parent.y + (map.y - native.y) * parent.height / native.height
    map.width, map.height = map.width * parent.width / native.width, map.height * parent.height / native.height
    -- A schematic cavern can have valid coordinates that do not match its drawn entrance.
    local misplaced = inRealm and width > 0 and height > 0 and not Contains(map,
        parent.x + (left + width / 2) * parent.width, parent.y + (top + height / 2) * parent.height)
    if map.width >= parent.width * 0.95 or map.height >= parent.height * 0.95
        or not Contains(parent, map.x + map.width / 2, map.y + map.height / 2) or misplaced then
        return inRealm and RememberPortal(parent, x, y, subregion) or nil
    end
    map.parent, map.depth = parent, parent.depth + 1
    map.realmRoot = parent.realmRoot or (parent.realm and parent)
    -- Blackreach's local sheets contain hatching and navigation paper outside the cave footprint.
    if parent.id == 1782 and (id == 1747 or id == 1850) and file ~= "" and width > 0 and height > 0 then
        map.footprint = HoverBounds(parent, file, width, height, left, top)
    end
    maps[#maps + 1], byId[id] = map, map
    return map
end

local function LoadCosmicMaps()
    local id
    for index = 1, GetNumMaps() do
        local _, kind = GetMapInfoByIndex(index)
        if kind == MAPTYPE_COSMIC then id = GetMapIdByIndex(index); break end
    end
    if not id then return end
    local base = ReadMap(id, true)
    if not base then return end
    local source = GetMapTileTextureForMapId(id, 1):lower():gsub("\\", "/"):gsub("%.dds$", "")
    local tamriel = GetMapTileTextureForMapId(TAMRIEL_MAP_ID, 1):lower():gsub("\\", "/"):gsub("%.dds$", "")
    if base.columns ~= 2 or base.rows ~= 2 or world.columns ~= 4 or world.rows ~= 4
        or not source:match("/tamriel/mundus_base_0$") or not tamriel:match("/tamriel/tamriel_0$") then return end
    SetMapToMapId(id)
    if GetCurrentMapId() ~= id then return end
    -- Coastline registration of the shipped mundus_base and tamriel tiles (proof/aurbis-registration.txt).
    local scale, left, top = 0.569706, 0.221370, 0.218849
    base.x, base.y, base.width, base.height = -left / scale, -top / scale, 1 / scale, 1 / scale
    cosmic, minimumZoom, byId[id], world.portalParent = base, scale, base, base
    for index = 1, GetNumMapBlobs() do
        local _, x, y = GetMapBlobNameInfo(index)
        RememberPortal(base, x, y)
    end
    -- Aurbis portals may have no name blob. Hit-test the native map, once, without clicking it.
    for row = 1, 25 do
        for column = 1, 25 do RememberPortal(base, column / 26, row / 26) end
    end
end

local function DiscoverChildren(parent)
    if parent.scanned or parent.depth >= 4 or not UsesAtlas(parent.id) then return end
    local previous = GetCurrentMapId()
    SetMapToMapId(parent.id)
    if GetCurrentMapId() == parent.id then
        for index = 1, GetNumMapBlobs() do
            local _, x, y = GetMapBlobNameInfo(index)
            RememberChild(parent, x, y)
        end
        -- Realm medallions can be small and have no name blob; scan once, then cache.
        local steps = (parent.realm or parent.realmRoot) and 26 or 10
        for row = 1, steps - 1 do
            for column = 1, steps - 1 do RememberChild(parent, column / steps, row / steps) end
        end
        parent.scanned = true
    end
    SetMapToMapId(previous)
end

local function RememberOutline(x, y)
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    local _, file, width, height, left, top, id = GetMapMouseoverInfo(x, y)
    local map = byId[id]
    if map and map ~= world and not map.realm and file ~= "" and width > 0 and height > 0 then
        map.outline = { file = file, x = left, y = top, width = width, height = height }
        local fit = addon.Fit and addon.Fit[id]
        if fit and map.art and map.art.source == fit.source and not map.fitted then
            local source = file:lower():gsub("\\", "/"):gsub("%.dds$", "")
            if source:sub(-#fit.outline) == fit.outline then
                map.x, map.y = left + fit.x * width, top + fit.y * height
                map.width, map.height = fit.width * width, fit.height * height
                map.fitted = true
            end
        end
        return map
    end
end

local function CenterZoneName(map)
    local bounds = map.outline
    if not bounds then return end
    local points, sumX, sumY = {}, 0, 0
    for row = 1, 7 do
        for column = 1, 7 do
            local x, y = bounds.x + bounds.width * (column - 0.5) / 7,
                bounds.y + bounds.height * (row - 0.5) / 7
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local _, _, _, _, _, _, id = GetMapMouseoverInfo(x, y)
                if id == map.id then
                    points[#points + 1] = { x = x, y = y }
                    sumX, sumY = sumX + x, sumY + y
                end
            end
        end
    end
    if #points == 0 then return end
    local x, y = sumX / #points, sumY / #points
    local _, _, _, _, _, _, id = GetMapMouseoverInfo(x, y)
    if id == map.id then map.namePosition = { x = x, y = y }; return end
    -- Concave territories can have a centroid outside their land; use the nearest interior sample.
    local nearest = math.huge
    for _, point in ipairs(points) do
        local distance = (point.x - x) ^ 2 + (point.y - y) ^ 2
        if distance < nearest then nearest, map.namePosition = distance, point end
    end
end

local function LoadMaps()
    local base = ReadMap(TAMRIEL_MAP_ID)
    if not base then return false end
    local previous = GetCurrentMapId()
    SetMapToMapId(TAMRIEL_MAP_ID)
    if GetCurrentMapId() ~= TAMRIEL_MAP_ID then return false end
    maps, byId = {}, {}
    addon.maps, addon.byId = maps, byId
    originX, originY, worldWidth, worldHeight = base.x, base.y, base.width, base.height
    for index = 1, GetNumMaps() do
        local _, mapType, contentType = GetMapInfoByIndex(index)
        if mapType == MAPTYPE_ZONE and (contentType == MAP_CONTENT_NONE or contentType == MAP_CONTENT_AVA) then
            local id = GetMapIdByIndex(index)
            local map = not separateMaps[id] and not byId[id] and ReadMap(id)
            if map then
                NormalizeMap(map)
                local x, y = map.x + map.width / 2, map.y + map.height / 2
                if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    map.depth = 1
                    maps[#maps + 1], byId[id] = map, map
                end
            end
        end
    end
    base.x, base.y, base.width, base.height = 0, 0, 1, 1
    world, byId[TAMRIEL_MAP_ID] = base, base
    addon.world = world
    backdrop = addon.Backdrop
    if backdrop then
        local source = GetMapTileTextureForMapId(TAMRIEL_MAP_ID, 1):lower():gsub("\\", "/"):gsub("%.dds$", "")
        if base.columns ~= 4 or base.rows ~= 4 or source:sub(-#backdrop.source) ~= backdrop.source then backdrop = nil end
    end
    atlases = {}
    for _, atlas in ipairs({ addon.Proof }) do
        -- Refuse a stale calibration instead of silently separating artwork from native pins.
        local valid = true
        for id, expected in pairs(atlas.expected) do
            local map = byId[id]
            if expected.source and (not map or not map.art or map.art.source ~= expected.source) then valid = false end
            for _, key in ipairs({ "x", "y", "width", "height" }) do
                if not map or math.abs(map[key] - expected[key]) > (atlas.tolerance or 0.00001) then valid = false; break end
            end
            if not valid then break end
        end
        if valid then
            atlases[#atlases + 1] = atlas
            for id in pairs(atlas.expected) do byId[id].atlas = atlas end
        end
    end
    for index = 1, GetNumMapBlobs() do
        local _, x, y = GetMapBlobNameInfo(index)
        RememberOutline(x, y)
    end
    for _, map in ipairs(maps) do
        if not map.outline then
            for row = 1, 5 do
                for column = 1, 5 do
                    RememberOutline(map.x + map.width * column / 6, map.y + map.height * row / 6)
                end
            end
        end
    end
    for _, map in ipairs(maps) do CenterZoneName(map) end
    LoadCosmicMaps()
    -- Blackreach has no Aurbis portal. Keep a separate scene beneath Skyrim, reached through its lifts.
    if cosmic and byId[1719] and not byId[1782] then
        local underground, skyrim = ReadMap(1782), byId[1719]
        if underground then
            NormalizeMap(underground)
            underground.x, underground.y = skyrim.x, skyrim.y
            underground.width, underground.height = skyrim.width, skyrim.height
            underground.depth, underground.realm, underground.underground = 1, true, true
            underground.portalParent = world
            underground.outline = { x = underground.x, y = underground.y, width = underground.width, height = underground.height }
            maps[#maps + 1], byId[1782] = underground, underground
        end
    end
    SetMapToMapId(previous)
    return true
end

local function WorldAt(x, y)
    if not cosmic then return world end
    local previous = GetCurrentMapId()
    SetMapToMapId(cosmic.id)
    local map
    if GetCurrentMapId() == cosmic.id and Contains(cosmic, x, y) then
        local _, _, _, _, _, _, id = GetMapMouseoverInfo((x - cosmic.x) / cosmic.width, (y - cosmic.y) / cosmic.height)
        map = byId[id]
    end
    SetMapToMapId(previous)
    -- Native portal silhouettes win over Tamriel's overlapping paper rectangle.
    if map == world or map and map.portalParent == cosmic then return map end
    return Contains(world, x, y) and world or cosmic
end

local function PickMap(x, y)
    local previous = GetCurrentMapId()
    local map = sceneWorld or WorldAt(x, y)
    if map == world then
        SetMapToMapId(TAMRIEL_MAP_ID)
        if GetCurrentMapId() == TAMRIEL_MAP_ID then map = RememberOutline(x, y) or world end
    end
    if map == world or map == cosmic then SetMapToMapId(previous); return map end
    if not Contains(map, x, y) then SetMapToMapId(previous); return map end
    while map and map.depth < 4 do
        DiscoverChildren(map)
        SetMapToMapId(map.id)
        if GetCurrentMapId() ~= map.id then break end
        local child = RememberChild(map, (x - map.x) / map.width, (y - map.y) / map.height)
        if not child or not Contains(child, x, y) then break end
        map = child
    end
    SetMapToMapId(previous)
    return map or world
end

local function ResolveRealmMap(id)
    if not cosmic then return end
    -- These entrances have a known parent even when native zoom-out takes another route.
    local rootId = (id == 1747 or id == 1850) and 1782 or id == 2515 and 108
    if rootId and byId[rootId] then
        DiscoverChildren(byId[rootId])
        if byId[id] then return byId[id] end
    end
    local previous, chain = GetCurrentMapId(), {}
    SetMapToMapId(id)
    for _ = 1, 6 do
        local childId = GetCurrentMapId()
        if byId[childId] then break end
        chain[#chain + 1] = childId
        MapZoomOut()
        if GetCurrentMapId() == childId then break end
    end
    local parent = byId[GetCurrentMapId()]
    for index = #chain, 1, -1 do
        if not parent or parent == cosmic or parent == world then break end
        DiscoverChildren(parent)
        local childId = chain[index]
        if not byId[childId] and parent.native then
            local child = ReadMap(childId)
            if child then
                NormalizeMap(child)
                SetMapToMapId(parent.id)
                if GetCurrentMapId() == parent.id then
                    RememberChild(parent, (child.x + child.width / 2 - parent.native.x) / parent.native.width,
                        (child.y + child.height / 2 - parent.native.y) / parent.native.height)
                end
            end
        end
        parent = byId[childId]
    end
    SetMapToMapId(previous)
    return byId[id]
end

local function WorldLayer(map)
    if not map.sceneLayer then
        local layer = WINDOW_MANAGER:CreateControl(nil, canvas, CT_CONTROL)
        layer:SetAnchor(TOPLEFT, canvas, TOPLEFT, map.x * CANVAS_SIZE, map.y * CANVAS_SIZE)
        layer:SetDimensions(map.width * CANVAS_SIZE, map.height * CANVAS_SIZE)
        layer:SetMaskMode(CONTROL_MASK_MODE_THRESHOLD)
        layer:SetMaskThresholdZeroAlphaEdge(0.001)
        layer:SetMaskTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
        map.sceneLayer = layer
        ui.worldLayers[map.id] = layer
        if map.art and map.art.surround then
            local surround = WINDOW_MANAGER:CreateControlFromVirtual(nil, viewport, "OpenTamrielMapTile")
            surround:SetDrawTier(DT_MEDIUM)
            surround:SetDrawLayer(DL_BACKGROUND)
            surround:SetDrawLevel(1 + (map.depth or 0) * 8)
            surround:SetAddressMode(TEX_MODE_WRAP)
            surround:SetAutoAdjustWrappedCoords(false)
            surround:SetAnchor(TOPLEFT, viewport, TOPLEFT)
            surround:SetMouseEnabled(false)
            surround:SetHidden(true)
            map.surround = surround
            ui.surrounds[map.id] = surround
        end
    end
    return map.sceneLayer
end

local function CreateLayer(map)
    local bounds = map.footprint or (map.art or map.parent or map.realm) and map or map.outline or map
    local owner = cosmic and RealmForMap(map)
    local parent = owner and WorldLayer(owner) or canvas
    local originX, originY = owner and owner.x or 0, owner and owner.y or 0
    local layer = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    layer:SetAnchor(TOPLEFT, parent, TOPLEFT, (bounds.x - originX) * CANVAS_SIZE, (bounds.y - originY) * CANVAS_SIZE)
    layer:SetDimensions(bounds.width * CANVAS_SIZE, bounds.height * CANVAS_SIZE)
    if map.footprint then
        map.maskFile = bounds.file
        layer:SetMaskMode(CONTROL_MASK_MODE_THRESHOLD)
        layer:SetMaskThresholdZeroAlphaEdge(0.002)
        layer:SetMaskThresholdThickness(0.018)
    elseif map.art or map.parent then
        map.maskFile = map.art and map.art.mask or "OpenTamriel/Textures/detail_mask.dds"
        layer:SetMaskMode(CONTROL_MASK_MODE_BASIC)
        if map.art and map.art.edge then
            local edge = WINDOW_MANAGER:CreateControlFromVirtual(nil, parent, "OpenTamrielMapTile")
            edge:SetDrawLayer(DL_BACKGROUND)
            edge:SetDrawLevel(cosmic and 4 or 2)
            edge:SetAnchor(TOPLEFT, parent, TOPLEFT, (map.x - originX) * CANVAS_SIZE, (map.y - originY) * CANVAS_SIZE)
            edge:SetDimensions(map.width * CANVAS_SIZE, map.height * CANVAS_SIZE)
            map.edge = edge
        end
    elseif map.outline and not map.realm then
        map.maskFile = bounds.file
        -- ESO samples the mask's red channel; hover artwork is too dim for a basic mask.
        layer:SetMaskMode(CONTROL_MASK_MODE_THRESHOLD)
        layer:SetMaskThresholdZeroAlphaEdge(0.002)
        layer:SetMaskThresholdThickness(0.018)
    end
    if map.maskFile then layer:SetMaskTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES) end
    map.layer, map.tiles = layer, {}
    for row = 0, map.rows - 1 do
        for column = 0, map.columns - 1 do
            local index = row * map.columns + column + 1
            local file = map.files and map.files[index] or GetMapTileTextureForMapId(map.id, index)
            local x, y = map.x + column * map.width / map.columns, map.y + row * map.height / map.rows
            if file ~= "" and (not map.footprint or (x < bounds.x + bounds.width and y < bounds.y + bounds.height
                and x + map.width / map.columns > bounds.x and y + map.height / map.rows > bounds.y)) then
                local tile = WINDOW_MANAGER:CreateControlFromVirtual(nil, layer, "OpenTamrielMapTile")
                tile:SetDrawLayer(DL_BACKGROUND)
                local level = map == world and 0 or map == backdrop and 1 or map.files and 4
                    or map.parent and 3 + map.depth or 3
                tile:SetDrawLevel(map == cosmic and 1 or level + (cosmic and 2 + (owner.depth or 0) * 8 or 0))
                if map.uv then tile:SetTextureCoords(map.uv, 1 - map.uv, map.uv, 1 - map.uv) end
                tile:SetAnchor(TOPLEFT, layer, TOPLEFT,
                    (map.x - bounds.x + column * map.width / map.columns) * CANVAS_SIZE,
                    (map.y - bounds.y + row * map.height / map.rows) * CANVAS_SIZE)
                tile:SetDimensions(map.width * CANVAS_SIZE / map.columns, map.height * CANVAS_SIZE / map.rows)
                map.tiles[#map.tiles + 1] = { control = tile, file = file }
            end
        end
    end
end

local function SetLayer(map, alpha, preload)
    local visible = alpha > 0 or preload
    if not map.layer then
        if not visible then return end
        CreateLayer(map)
    end
    if map.visible ~= visible then
        map.visible = visible
        map.ready, map.loadedAt = false, nil
        map.layer:SetHidden(not visible)
        if map.maskFile then map.layer:SetMaskTexture(visible and map.maskFile or "") end
        for _, tile in ipairs(map.tiles) do tile.control:SetTexture(visible and tile.file or nil) end
        if map.edge then
            map.edge:SetHidden(not visible)
            map.edge:SetTexture(visible and map.art.edge or nil)
        end
    end
    if visible then
        if not map.ready then
            map.ready = true
            for _, tile in ipairs(map.tiles) do
                if not tile.control:IsTextureLoaded() then map.ready = false; break end
            end
            if map.edge and not map.edge:IsTextureLoaded() then map.ready = false end
            if map.surround and not map.surround:IsTextureLoaded() then map.ready = false end
            if map.ready then map.loadedAt = GetFrameTimeSeconds() end
        end
        local reveal = map.ready and ((map == cosmic or map == world and not cosmic) and 1
            or SmoothStep((GetFrameTimeSeconds() - map.loadedAt) / 0.16)) or 0
        if not map.ready or reveal < 1 then pendingArt = true end
        map.layer:SetAlpha(alpha * reveal)
        -- Native-mask contours and sea corrections accompany the zoomed background only.
        if map.edge then map.edge:SetAlpha(alpha * reveal * backdropOpacity) end
    end
    if map.navigation then SetLayer(map.navigation, alpha, preload) end
end

local function HideArt(control)
    -- GetAlpha includes the parent's pin fade; only the control's own alpha can be restored safely.
    if oldAlpha[control] == nil then oldAlpha[control] = control:GetControlAlpha() end
    control:SetAlpha(0)
end

local function HideNativeArt()
    if not active or not UsesAtlas(GetCurrentMapId()) or not (cosmic or world).ready then return end
    for _, tile in WORLD_MAP_TILES_MANAGER:ActiveObjectIterator() do HideArt(tile) end
    HideArt(ZO_WorldMapContainerBackground)
    HideArt(ZO_WorldMapContainerRaggedEdge)
end

local function MapScale(map)
    if map == cosmic then return minimumZoom end
    return math.max(1, 0.8 * math.min(viewWidth / map.width, viewHeight / map.height) / fitSize)
end

local function WorldFitZoom(map)
    return math.max(viewWidth / map.width, viewHeight / map.height) / fitSize
end

local function RegionZoom(map)
    if cosmic and (map == world or map.realm) then
        return math.min(MAX_ZOOM, 1.05 * WorldFitZoom(map))
    end
    return math.min(MapScale(map), MAX_ZOOM)
end

local function EntryStart(map)
    return ((map == world or map.underground) and 0.65 or 0.26) * WorldFitZoom(map)
end

local function ViewCoverage(map)
    local size = fitSize * zoom
    return math.min(math.min(cameraX - map.x, map.x + map.width - cameraX) * size * 2 / viewWidth,
        math.min(cameraY - map.y, map.y + map.height - cameraY) * size * 2 / viewHeight)
end

local function UpdateWorldScene()
    local chain, included = {}, {}
    local map = sceneWorld
    while map and map ~= cosmic do
        table.insert(chain, 1, map)
        included[map] = true
        map = map.portalParent
    end
    for _, root in ipairs(chain) do
        WorldLayer(root)
        if root.surround then root.surround:SetTexture(root.art.surround) end
        SetLayer(root, 0, true)
        local reveal = root.ready and SmoothStep((GetFrameTimeSeconds() - root.loadedAt) / 0.16) or 0
        root.coverage = ViewCoverage(root)
        -- Preview a realm inside its portal before the portal surrounds the camera.
        local progress = (root == world or root.underground) and SmoothStep((zoom / WorldFitZoom(root) - 0.65) / 0.4)
            or SmoothStep((zoom / WorldFitZoom(root) - 0.26) / 0.59)
        root.entryWeight = progress * reveal
        root.surroundWeight = root.surround and root.entryWeight * SmoothStep((zoom / WorldFitZoom(root) - 0.30) / 0.40) or 0
        root.coversView = root.entryWeight == 1 and root.coverage >= 1.05
    end
    for index, root in ipairs(chain) do
        local child = chain[index + 1]
        local nextWeight = child and child.entryWeight or 0
        -- An opaque native surround can retire the portal before its map fills the screen.
        root.contextAlpha = child and (child.surroundWeight == 1 or child.coversView) and 0 or root.entryWeight
        root.pinContextAlpha = root.entryWeight * (1 - nextWeight)
    end
    local function ApplyRoot(root)
        if not included[root] then
            root.entryWeight, root.contextAlpha, root.pinContextAlpha, root.coversView, root.surroundWeight = 0, 0, 0, false, 0
        end
        if root.sceneLayer then
            local visible = (root.contextAlpha or 0) > 0
            root.sceneLayer:SetHidden(not visible)
            root.sceneLayer:SetAlpha(root.contextAlpha or 0)
            local feather = visible and not root.surround and not root.coversView
            root.sceneLayer:SetMaskMode(feather and CONTROL_MASK_MODE_THRESHOLD or CONTROL_MASK_MODE_NONE)
            root.sceneLayer:SetMaskTexture(feather and "OpenTamriel/Textures/detail_mask.dds" or "")
            -- Keep a broad edge while any of the paper rectangle can still be seen.
            local edgeFade = 0.28 * (1 - SmoothStep(((root.coverage or 0) - 1) / 0.05))
            root.sceneLayer:SetMaskThresholdThickness(math.max(0.001, edgeFade, (1 - root.entryWeight) ^ 2))
        end
        if root.surround then
            local visible = included[root] and root.contextAlpha > 0
            root.surround:SetHidden(not visible)
            root.surround:SetAlpha(visible and root.surroundWeight or 0)
            if visible then
                root.surround:SetDimensions(viewWidth, viewHeight)
                local u, v = (cameraX - root.x) / root.width, (cameraY - root.y) / root.height
                local halfU, halfV = viewWidth / (2 * root.width * fitSize * zoom), viewHeight / (2 * root.height * fitSize * zoom)
                root.surround:SetTextureCoords((u - halfU) * 4, (u + halfU) * 4, (v - halfV) * 4, (v + halfV) * 4)
            elseif not included[root] then
                root.surround:SetTexture(nil)
            end
        end
    end
    ApplyRoot(world)
    for _, root in ipairs(maps) do if root.realm then ApplyRoot(root) end end
    local immersion = chain[1] and chain[1].entryWeight or 0
    SetLayer(cosmic, 1)
    cosmic.layer:SetAlpha(chain[1] and (chain[1].surroundWeight == 1 or chain[1].coversView) and 0 or 1)
    cosmic.pinContextAlpha = 1 - immersion
    if sceneWorld and sceneWorld.entryWeight == 0 and zoom <= EntryStart(sceneWorld)
        and (not motion or motion.zoom <= EntryStart(sceneWorld)) then
        sceneWorld = sceneWorld.portalParent ~= cosmic and sceneWorld.portalParent or nil
    end
    return included
end

local function DetailAlpha(map)
    if map.realm then return 1 end
    if map.realmRoot then
        return SmoothStep((zoom / MapScale(map) - 0.25) / 0.55) * DetailAlpha(map.parent)
    end
    -- Overland art shares the world's reveal. A small zone must not remain translucent
    -- just because its rectangle occupies less of Tamriel; cities still use local LOD.
    if not map.parent then return SmoothStep((zoom - 1.35) / 1.15) end
    local gate = SmoothStep((zoom - 1.35) / 0.9)
    local alpha = gate * SmoothStep((zoom / MapScale(map) - 0.25) / 0.55)
    if map.parent then alpha = alpha * DetailAlpha(map.parent) end
    return alpha
end

local function HideClouds()
    if cloudLayer then cloudLayer:SetHidden(true) end
    if cloudRoot then
        for _, bank in ipairs(cloudBanks) do bank:SetTexture(nil); bank.loadedAt = nil end
    end
    cloudRoot = nil
end

local function ApplyCloudAppearance(bank, spec)
    bank:SetTexture(spec.texture)
    bank.loadedAt = nil
    bank:SetTextureCoords(spec.flipX and 1 or 0, spec.flipX and 0 or 1, spec.flipY and 1 or 0, spec.flipY and 0 or 1)
    bank:SetTextureRotation(spec.rotation, 0.5, 0.5)
end

local function UpdateClouds(now)
    local root = sceneWorld
    if not cosmic then root = world end
    local weight = root and (not cosmic and 1 or root.pinContextAlpha or 0) or 0
    if not settings.clouds or not active or not root or root ~= world or not root.ready or weight == 0 or zoom >= 6.4 then
        HideClouds()
        return
    end
    if not cloudLayer then
        cloudLayer = WINDOW_MANAGER:CreateControl(nil, viewport, CT_CONTROL)
        ui.clouds = cloudLayer
        cloudLayer:SetAnchorFill(viewport)
        cloudLayer:SetDrawTier(DT_MEDIUM)
        cloudLayer:SetDrawLayer(DL_OVERLAY)
        cloudLayer:SetMouseEnabled(false)
        for index, spec in ipairs(CLOUD_BANKS) do
            local bank = WINDOW_MANAGER:CreateControlFromVirtual(nil, cloudLayer, "OpenTamrielMapTile")
            bank:SetDrawTier(DT_MEDIUM)
            -- Masked terrain is composited as a group; background levels cannot put clouds above it.
            bank:SetDrawLayer(DL_OVERLAY)
            bank:SetDrawLevel(4 - spec[4])
            bank:SetMouseEnabled(false)
            bank:SetColor(1, 1, 1, 1)
            cloudBanks[index] = bank
        end
    end
    if cloudRoot ~= root then
        cloudRoot, cloudStartedAt = root, now
        for index, bank in ipairs(cloudBanks) do
            ApplyCloudAppearance(bank, CLOUD_BANKS[index])
        end
    end
    cloudLayer:SetHidden(false)
    cloudLayer:SetAlpha(weight * SmoothStep((now - cloudStartedAt) / 0.30))
    local entry = SmoothStep((zoom - 0.72) / 0.32)
    for index, bank in ipairs(cloudBanks) do
        local spec = CLOUD_BANKS[index]
        local distance = spec[1] + 0.25 + now * spec.speed
        local cycle, drift = math.floor(distance / 1.5), distance % 1.5
        if spec.cycle ~= cycle then
            if spec.cycle ~= nil then
                RandomizeCloud(spec)
                ApplyCloudAppearance(bank, spec)
            end
            spec.cycle = cycle
        end
        local start = spec[4] == 1 and 0.95 or 1.18
        local finish = spec[4] == 1 and 5.2 or 6.4
        local approach = zo_clamp((zoom - start) / (finish - start), 0, 1)
        -- A nearer plane expands and moves faster than the land, then passes behind the camera.
        local perspective = 1 / (1 - approach * 0.78)
        local size = fitSize * zoom * perspective
        -- A transparent interval hides the new position and silhouette at each wrap.
        local driftAlpha = SmoothStep((drift - 0.025) / 0.14) * SmoothStep((1.475 - drift) / 0.14)
        local x = root.x + (drift - 0.25) * root.width
        local y = root.y + (spec[2] + 0.006 * math.cos(now * 0.03 + index * 1.3)) * root.height
        local width = spec[3] * root.width * size
        bank:SetDimensions(width, width * spec.aspect)
        bank:SetAnchor(CENTER, viewport, CENTER, (x - cameraX) * size, (y - cameraY) * size)
        if bank:IsTextureLoaded() then bank.loadedAt = bank.loadedAt or now else bank.loadedAt = nil end
        local loaded = bank.loadedAt and SmoothStep((now - bank.loadedAt) / 0.20) or 0
        bank:SetAlpha(spec.opacity * driftAlpha * entry * (1 - SmoothStep((approach - 0.30) / 0.70)) * loaded)
        bank:SetHidden(approach == 1)
    end
end

local function ReportClouds()
    local root = sceneWorld
    if not cosmic then root = world end
    local loaded, visible, peakAlpha = 0, 0, 0
    local cx, cy = viewport:GetCenter()
    local vw, vh = viewport:GetDimensions()
    for _, bank in ipairs(cloudBanks) do
        if bank:GetTextureFileName() ~= "" and bank:IsTextureLoaded() then loaded = loaded + 1 end
        if not bank:IsHidden() and cloudLayer and not cloudLayer:IsHidden() then
            local x, y = bank:GetCenter()
            local w, h = bank:GetDimensions()
            if math.abs(x - cx) < (vw + w) / 2 and math.abs(y - cy) < (vh + h) / 2 then
                local alpha = bank:GetAlpha()
                peakAlpha = math.max(peakAlpha, alpha)
                if alpha > 0.01 then visible = visible + 1 end
            end
        end
    end
    d(string.format("%s %s | active=%s map=%d zoom=%.2f root=%s ready=%s weight=%.2f",
        ADDON_NAME, addon.version, tostring(active), GetCurrentMapId(), zoom, tostring(root and root.id), tostring(root and root.ready),
        root and (not cosmic and 1 or root.pinContextAlpha or 0) or 0))
    d(string.format("Clouds | loaded=%d/%d onScreen=%d alpha=%.2f layerHidden=%s layerAlpha=%.2f",
        loaded, #cloudBanks, visible, peakAlpha, tostring(not cloudLayer or cloudLayer:IsHidden()),
        cloudLayer and cloudLayer:GetAlpha() or 0))
end

local function CaptureMaps()
    local previous = GetCurrentMapId()
    local capture = { version = addon.version, current = previous, active = active, zoom = zoom, maps = {}, tiles = {},
        constants = { subzone = MAPTYPE_SUBZONE, zone = MAPTYPE_ZONE, world = MAPTYPE_WORLD,
            none = MAP_CONTENT_NONE, dungeon = MAP_CONTENT_DUNGEON, ava = MAP_CONTENT_AVA } }
    for _, tile in WORLD_MAP_TILES_MANAGER:ActiveObjectIterator() do
        capture.tiles[#capture.tiles + 1] = { file = tile:GetTextureFileName(), alpha = tile:GetAlpha(),
            controlAlpha = tile:GetControlAlpha(), hidden = tile:IsHidden(), loaded = tile:IsTextureLoaded(), restoredAlpha = oldAlpha[tile] }
    end
    local ids = {108, 1719, 1747, 1782, 1814, 1850, GetMapIdByZoneId(1463), previous}
    local function Metadata(id)
        local info = { info = {GetMapInfoById(id)}, universal = {GetUniversallyNormalizedMapInfo(id)},
            tiles = {GetMapNumTilesForMapId(id)}, file = GetMapTileTextureForMapId(id, 1), index = GetMapIndexById(id) }
        local map = byId and byId[id]
        if map then
            info.atlas = { x = map.x, y = map.y, width = map.width, height = map.height, realm = map.realm,
                parent = map.parent and map.parent.id, portalParent = map.portalParent and map.portalParent.id,
                outline = map.outline, ready = map.ready, visible = map.visible,
                alpha = map.layer and map.layer:GetAlpha(), native = map.native }
        end
        return info
    end
    -- Always restore the selected map after this opt-in diagnostic, including failed API reads.
    local ok, errorMessage = pcall(function()
        for _, id in ipairs(ids) do
            if id and id > 0 and not capture.maps[id] then
                local record = Metadata(id)
                capture.maps[id] = record
                SetMapToMapId(id)
                record.selected = GetCurrentMapId()
                if record.selected == id then
                    record.currentTiles, record.currentFile = {GetMapNumTiles()}, GetMapTileTexture(1)
                    record.floor, record.links, record.locations, record.pois = {GetMapFloorInfo()}, {}, {}, {}
                    for row = 1, 49 do
                        for column = 1, 49 do
                            local x, y = column / 50, row / 50
                            local hover = {GetMapMouseoverInfo(x, y)}
                            local child = hover[7]
                            if child and child > 0 and child ~= id and not record.links[child] then
                                record.links[child] = { x = x, y = y, hover = hover, target = Metadata(child),
                                    click = {WouldProcessMapClick(x, y)} }
                            end
                        end
                    end
                    for index = 1, GetNumMapLocations() do
                        record.locations[index] = {GetMapLocationIcon(index)}
                    end
                    local zoneIndex = GetCurrentMapZoneIndex()
                    if zoneIndex and zoneIndex > 0 then
                        for index = 1, GetNumPOIs(zoneIndex) do
                            record.pois[index] = { name = GetPOIInfo(zoneIndex, index),
                                kind = GetPOIType(zoneIndex, index), map = {GetPOIMapInfo(zoneIndex, index)} }
                        end
                    end
                end
            end
        end
    end)
    SetMapToMapId(previous)
    capture.error = not ok and tostring(errorMessage) or nil
    OpenTamrielDiagnostics = capture
    d(ok and "OpenTamriel: map captured. Use /reloadui to save the local diagnostic."
        or "OpenTamriel: partial capture: " .. tostring(errorMessage))
end

local function UpdateZoneName(map, size)
    if map.parent or not map.outline then return end
    local titleEntry = map.realm and WorldFitZoom(map) * 0.78 or 1
    local startZoom = map.realm and math.max(minimumZoom, titleEntry * 0.45) or 1
    local passZoom = math.min(MAX_ZOOM, map.realm and titleEntry * 1.15
        or math.max(startZoom + 0.7, MapScale(map) * 0.68))
    local approach = zo_clamp((zoom - startZoom) / (passZoom - startZoom), 0, 1)
    local alpha = SmoothStep(map.nameWeight or 0)
        * (1 - SmoothStep((approach - 0.5) / 0.5))
    if cosmic then
        if map.realm then
            if sceneWorld and sceneWorld ~= map then alpha = 0 end
        else
            alpha = alpha * (world.pinContextAlpha or 0)
        end
    end
    if alpha == 0 then
        if map.label then map.label:SetHidden(true) end
        return
    end
    local bounds = map.outline
    local position = map.namePosition
    local x, y = bounds.x + bounds.width / 2, bounds.y + bounds.height / 2
    if position then x, y = position.x, position.y end
    local label = map.label
    if not label then
        label = WINDOW_MANAGER:CreateControl(nil, labels, CT_LABEL)
        ui.zoneNames[map.id] = label
        local relief = WINDOW_MANAGER:CreateControl(nil, label, CT_LABEL)
        local name = zo_strformat(SI_ZONE_NAME, GetMapNameById(map.id))
        for _, part in ipairs({ label, relief }) do
            part:SetFont("OpenTamrielZoneNameFont")
            part:SetSmallCaps(true)
            part:SetTracking(0.06)
            part:SetPixelRoundingEnabled(false)
            part:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            part:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            part:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
            part:SetDrawLayer(DL_OVERLAY)
            part:SetMouseEnabled(false)
            part:SetDimensions(0, 0)
            part:SetText(name)
        end
        label:SetColor(0.93, 0.82, 0.57, 1)
        label:SetStyleColor(0.09, 0.065, 0.035, 0.85)
        label:SetDrawLevel(20)
        -- Measure the laid-out small caps and tracking, not the unformatted string.
        local textWidth, textHeight = label:GetTextDimensions()
        map.nameWidth, map.nameHeight = math.ceil(math.max(1, textWidth)) + 32, math.max(60, math.ceil(textHeight) + 16)
        label:SetDimensions(map.nameWidth, map.nameHeight)
        relief:SetDimensions(map.nameWidth, map.nameHeight)
        relief:SetColor(0.32, 0.18, 0.07, 1)
        relief:SetStyleColor(0, 0, 0, 0)
        relief:SetAnchor(CENTER, label, CENTER, 0.5, 1)
        relief:SetDrawLevel(19)
        map.label = label
    end
    -- Grow visibly before fading; keep the center fixed and finish before local navigation.
    local perspective = 1 / math.max(0.16, 1 - approach)
    local scale = perspective * math.min(0.82, math.max(0.68, bounds.width * fitSize * 0.8 / map.nameWidth),
        viewWidth * 0.42 / map.nameWidth)
    local offsetX, offsetY = (x - cameraX) * size, (y - cameraY) * size
    local visible = alpha > 0 and math.abs(offsetX) < (viewWidth + map.nameWidth * scale) / 2
        and math.abs(offsetY) < (viewHeight + map.nameHeight * scale) / 2
    label:SetHidden(not visible)
    if visible then
        label:SetAnchor(CENTER, labels, CENTER, offsetX, offsetY)
        label:SetScale(scale)
        label:SetAlpha(alpha)
    end
end

local function UpdateZoneNames(now)
    labels:SetHidden(not settings.zoneNames)
    if not settings.zoneNames then nameUpdatedAt = now; return end
    local mouseX, mouseY = GetUIMousePosition()
    local cx, cy = viewport:GetCenter()
    local x, y = cameraX, cameraY
    if press and press.moved then
        nameUseCenter = true
    elseif motion or mouseX ~= nameMouseX or mouseY ~= nameMouseY then
        nameUseCenter = false
    end
    nameMouseX, nameMouseY = mouseX, mouseY
    if motion then
        x, y = focusX or x, focusY or y
    elseif not nameUseCenter and math.abs(mouseX - cx) < viewWidth / 2 and math.abs(mouseY - cy) < viewHeight / 2 then
        x, y = x + (mouseX - cx) / (fitSize * zoom), y + (mouseY - cy) / (fitSize * zoom)
    end
    if (x ~= nameProbeX or y ~= nameProbeY) and (not nameProbeAt or now >= nameProbeAt) then
        namedMap = PickMap(x, y)
        while namedMap and namedMap.parent do namedMap = namedMap.parent end
        if namedMap == world or namedMap == cosmic or zoom < 0.9 and not namedMap.realm then namedMap = nil end
        nameProbeX, nameProbeY, nameProbeAt = x, y, now + 0.08
    end
    local step = math.max(0, now - (nameUpdatedAt or now)) / 0.18
    nameUpdatedAt = now
    for _, map in ipairs(maps) do
        if not map.parent then
            map.nameWeight = zo_clamp((map.nameWeight or 0) + (map == namedMap and step or -step), 0, 1)
            UpdateZoneName(map, fitSize * zoom)
        end
    end
end

local function MapAtZoom(map)
    while map ~= (cosmic or world) do
        local threshold = (map == world or map.realm) and EntryStart(map)
            or math.max(2.1, MapScale(map) * 0.82)
        if currentMap == map then threshold = threshold * (map == world and 0.94 or 0.85) end
        if zoom >= threshold then break end
        map = map.parent or map.linkParent or map.portalParent or world
    end
    return map
end

local function SliderValue(value)
    local target, low, high = (value - minimumZoom) / (MAX_ZOOM - minimumZoom), 0, 1
    for _ = 1, 24 do
        local middle = (low + high) / 2
        if ZO_EaseNormalizedZoom(middle) < target then low = middle else high = middle end
    end
    return (low + high) / 2
end

local function ApplyView()
    if not active or applying or not UsesAtlas(GetCurrentMapId()) then return end
    viewWidth, viewHeight = viewport:GetDimensions()
    fitSize = math.min(viewWidth, viewHeight)
    if fitSize <= 0 then return end
    local size = fitSize * zoom
    applying = true
    pendingArt = false
    local bounds, included = cosmic or world, {}
    local halfWidth, halfHeight = viewWidth / (2 * size), viewHeight / (2 * size)
    local insetX, insetY = math.min(bounds.width / 2, halfWidth), math.min(bounds.height / 2, halfHeight)
    cameraX, cameraY = zo_clamp(cameraX, bounds.x + insetX, bounds.x + bounds.width - insetX),
        zo_clamp(cameraY, bounds.y + insetY, bounds.y + bounds.height - insetY)
    if cosmic then included = UpdateWorldScene() end
    -- Zoom visibility and the map-change fade are independent, so neither resets the other.
    pinZoomOpacity = currentMap == cosmic and 1 or currentMap == world and (cosmic and SmoothStep((zoom - 0.86) / 0.14) or 1)
        or SmoothStep((zoom / MapScale(currentMap) - 0.76) / 0.24)
    if cosmic then
        pinZoomOpacity = pinZoomOpacity * (currentMap == cosmic and cosmic.pinContextAlpha or (RealmForMap(currentMap).pinContextAlpha or 0))
    end
    SetPinOpacity(pinOpacity)
    pan:SetCurrentNormalizedZoom(SliderValue(zoom))
    -- Pin positions stay local to their map; its fitted rectangle moves artwork and pins together.
    ZO_MAP_CONSTANTS.MAP_WIDTH, ZO_MAP_CONSTANTS.MAP_HEIGHT = currentMap.width * size, currentMap.height * size
    ZO_WorldMapContainer:SetDimensions(ZO_MAP_CONSTANTS.MAP_WIDTH, ZO_MAP_CONSTANTS.MAP_HEIGHT)
    pan:SetCurrentOffset((currentMap.x + currentMap.width / 2 - cameraX) * size,
        (currentMap.y + currentMap.height / 2 - cameraY) * size)
    ZO_WorldMap_GetPinManager():UpdatePinsForMapSizeChange()
    canvas:SetScale(size / CANVAS_SIZE)
    canvas:SetAnchor(CENTER, viewport, CENTER, (0.5 - cameraX) * size, (0.5 - cameraY) * size)
    SetLayer(world, not cosmic and 1 or (world.contextAlpha or 0) > 0 and 1 or 0, included[world])
    backdropOpacity = 0
    if backdrop then
        SetLayer(backdrop, settings.emptyTerrain and (not cosmic or (world.contextAlpha or 0) > 0) and SmoothStep((zoom - 1.35) / 1.15) or 0)
        backdropOpacity = backdrop.visible and backdrop.layer:GetAlpha() or 0
    end
    for _, atlas in ipairs(atlases) do atlas.alpha = 0 end
    for _, map in ipairs(maps) do
        UpdateZoneName(map, size)
        local visible = (map.outline or map.parent)
            and math.abs(cameraX - map.x - map.width / 2) < halfWidth + map.width / 2
            and math.abs(cameraY - map.y - map.height / 2) < halfHeight + map.height / 2
        local owner = cosmic and RealmForMap(map)
        local alpha = visible and (not owner or (owner.contextAlpha or 0) > 0) and DetailAlpha(map) or 0
        if alpha > 0 then DiscoverChildren(map) end
        if map.atlas then
            map.atlas.alpha = math.max(map.atlas.alpha, alpha)
        else
            SetLayer(map, alpha, included[map])
        end
    end
    for _, atlas in ipairs(atlases) do SetLayer(atlas, atlas.alpha) end
    UpdateClouds(GetFrameTimeSeconds())
    HideNativeArt()
    applying = false
end

local function ChooseSceneWorld(x, y, target)
    if not cosmic or sceneWorld and target < zoom then return end
    local root
    local inside = sceneWorld and (sceneWorld.coversView or sceneWorld.surroundWeight == 1
        or sceneWorld.realm and Contains(sceneWorld, x, y))
    if inside then
        if target <= zoom then return end
        root = RealmForMap(PickMap(x, y))
        if not root or root.portalParent ~= sceneWorld then return end
    else
        -- Aurbis is still exposed: arriving from the side must reconsider the native portal.
        root = WorldAt(x, y)
    end
    if root ~= cosmic and target > EntryStart(root) then sceneWorld = root end
end

local function Animate(x, y, target)
    ChooseSceneWorld(x, y, target)
    focusX, focusY = x, y
    motion = { start = GetFrameTimeSeconds(), x = x, y = y, zoom = target,
        fromX = cameraX, fromY = cameraY, fromZoom = zoom }
    settleAt = GetFrameTimeSeconds()
end

local function LiftDestination(x, y, targetZoom)
    local id = currentMap.id == 1719 and 1747 or currentMap.id == 1814 and 1850
    if not id or not cosmic or not WORLD_MAP_MANAGER:IsMapChangingAllowed() then return end
    local u, v = (x - currentMap.x) / currentMap.width, (y - currentMap.y) / currentMap.height
    if u < 0 or u > 1 or v < 0 or v > 1 then return end
    local _, _, _, _, _, _, hoverId = GetMapMouseoverInfo(u, v)
    if hoverId == id then return ResolveRealmMap(id) end
    if targetZoom < MapScale(currentMap) * 2.2 then return end
    local zoneIndex = GetCurrentMapZoneIndex()
    for index = 1, GetNumPOIs(zoneIndex) do
        local px, py, _, icon, shown = GetPOIMapInfo(zoneIndex, index)
        if shown and icon:find("poi_u26_dwemergear_", 1, true) then
            local dx, dy = (u - px) * currentMap.width * fitSize * zoom,
                (v - py) * currentMap.height * fitSize * zoom
            if dx * dx + dy * dy <= 26 * 26 then return ResolveRealmMap(id) end
        end
    end
end

local function ZoomAt(factor, x, y)
    if press then return end
    local cx, cy = viewport:GetCenter()
    local dx, dy = x - cx, y - cy
    local size = fitSize * zoom
    local wx, wy = cameraX + dx / size, cameraY + dy / size
    local targetZoom = zo_clamp((motion and motion.zoom or zoom) * factor, minimumZoom, MAX_ZOOM)
    local destination = factor > 1 and LiftDestination(wx, wy, targetZoom)
    if destination then
        sceneWorld = RealmForMap(destination)
        Animate(destination.x + destination.width / 2, destination.y + destination.height / 2, RegionZoom(destination))
        return
    end
    Animate(wx, wy, targetZoom)
    motion.dx, motion.dy = dx, dy
end

local function SelectMap(map)
    if map.id == GetCurrentMapId() then CancelPinChange(); return end
    changing = UsesAtlas(map.id)
    local previous = currentMap
    SetPinOpacity(0)
    currentMap = map
    WORLD_MAP_MANAGER:SetMapById(map.id)
    if GetCurrentMapId() ~= map.id then currentMap = previous end
    changing = false
    if not active then return end
    ApplyView()
    FadePins(1)
end

local function Drag(x, y)
    local dx, dy = x - press.x, y - press.y
    if not press.moved and dx * dx + dy * dy < 16 then return end
    press.x, press.y, press.moved = x, y, true
    cameraX, cameraY = cameraX - dx / (fitSize * zoom), cameraY - dy / (fitSize * zoom)
    if sceneWorld and sceneWorld.coversView then
        -- Confine dragging inside a world; wheel zoom never recentres its cursor anchor.
        local insetX, insetY = 1.05 * viewWidth / (2 * fitSize * zoom), 1.05 * viewHeight / (2 * fitSize * zoom)
        cameraX = zo_clamp(cameraX, sceneWorld.x + insetX, sceneWorld.x + sceneWorld.width - insetX)
        cameraY = zo_clamp(cameraY, sceneWorld.y + insetY, sceneWorld.y + sceneWorld.height - insetY)
    end
    focusX, focusY = cameraX, cameraY
    ChooseSceneWorld(cameraX, cameraY, zoom)
    ApplyView()
end

local function Update(now)
    if press then
        Drag(GetUIMousePosition())
    elseif motion then
        local t = zo_clamp((now - motion.start) / ZOOM_SECONDS, 0, 1)
        local ease = 1 - (1 - t) ^ 3
        zoom = motion.fromZoom * (motion.zoom / motion.fromZoom) ^ ease
        if motion.dx then
            cameraX, cameraY = motion.x - motion.dx / (fitSize * zoom), motion.y - motion.dy / (fitSize * zoom)
        else
            cameraX = motion.fromX + (motion.x - motion.fromX) * ease
            cameraY = motion.fromY + (motion.y - motion.fromY) * ease
        end
        ApplyView()
        if t == 1 then motion, settleAt = nil, now end
    end
    if settleAt and now >= settleAt then
        settleAt = (motion or press) and now + 0.08 or nil
        local map = MapAtZoom(PickMap(focusX or cameraX, focusY or cameraY))
        if map == currentMap then
            CancelPinChange()
        elseif not pinTransition or pinTransition.map ~= map then
            local art = map.atlas or map
            if art.ready == false then settleAt = now + 0.05 else FadePins(0, map) end
        end
    end
    if not motion and pendingArt then ApplyView() end
    if pinTransition then
        local t = zo_clamp((now - pinTransition.start) / PIN_FADE_SECONDS, 0, 1)
        SetPinOpacity(pinTransition.from + (pinTransition.target - pinTransition.from) * SmoothStep(t))
        if t == 1 then
            local map = pinTransition.map
            pinTransition = nil
            if map then SelectMap(map) end
        end
    end
    if pan.jumpWhenAvailableExpiresAt and now > pan.jumpWhenAvailableExpiresAt then
        pan:ClearJumpToPinWhenAvailable()
    end
    UpdateZoneNames(now)
    UpdateClouds(now)
end

local function MouseDown(_, button, ctrl, alt, shift)
    CancelPinChange()
    if ctrl or alt or shift then
        local x, y = GetUIMousePosition()
        local cx, cy = viewport:GetCenter()
        SelectMap(MapAtZoom(PickMap(cameraX + (x - cx) / (fitSize * zoom), cameraY + (y - cy) / (fitSize * zoom))))
        modifiedPress, press, motion = true, nil, nil
        nativeMouseDown(button, ctrl, alt, shift)
    elseif button == MOUSE_BUTTON_INDEX_LEFT then
        local x, y = GetUIMousePosition()
        press, motion, settleAt = { x = x, y = y }, nil, nil
    end
end

local function MouseUp(_, button, inside)
    if modifiedPress then
        modifiedPress, press = nil, nil
        nativeMouseUp(ZO_WorldMapContainer, button, false)
        ApplyView()
        return
    elseif IsControlKeyDown() or IsAltKeyDown() or IsShiftKeyDown() then
        press = nil
        return
    end
    if button == MOUSE_BUTTON_INDEX_LEFT and press then
        Drag(GetUIMousePosition())
        local clicked = inside and not press.moved
        if press.moved then settleAt = GetFrameTimeSeconds() + 0.08 end
        press = nil
        if clicked and WORLD_MAP_MANAGER:IsMapChangingAllowed() then
            local x, y = GetUIMousePosition()
            local cx, cy = viewport:GetCenter()
            local u = (cameraX + (x - cx) / (fitSize * zoom) - currentMap.x) / currentMap.width
            local v = (cameraY + (y - cy) / (fitSize * zoom) - currentMap.y) / currentMap.height
            if u < 0 or u > 1 or v < 0 or v > 1 or not WouldProcessMapClick(u, v) then return end
            local _, _, _, _, _, _, id = GetMapMouseoverInfo(u, v)
            if not id or id == 0 or id == currentMap.id then return end
            local child = RememberChild(currentMap, u, v)
            if child then
                Animate(child.x + child.width / 2, child.y + child.height / 2, RegionZoom(child))
            else
                -- Cross-world medallions keep their native destination, even with no shared projection.
                WORLD_MAP_MANAGER:SetMapById(id)
            end
        end
    end
end

local function Stop()
    if not active then return end
    active, motion, press, settleAt, modifiedPress = false, nil, nil, nil, nil
    pinTransition = nil
    pinZoomOpacity = 1
    SetPinOpacity(1)
    surface:SetHidden(true)
    canvas:SetHidden(true)
    labels:SetHidden(true)
    HideClouds()
    SetLayer(world, 0)
    if cosmic then SetLayer(cosmic, 0) end
    if backdrop then SetLayer(backdrop, 0) end
    for _, atlas in ipairs(atlases) do SetLayer(atlas, 0) end
    for _, map in ipairs(maps) do
        SetLayer(map, 0)
        map.nameWeight = 0
        if map.label then map.label:SetHidden(true) end
    end
    if world.sceneLayer then world.sceneLayer:SetMaskTexture(""); world.sceneLayer:SetHidden(true) end
    for _, map in ipairs(maps) do
        if map.sceneLayer then map.sceneLayer:SetMaskTexture(""); map.sceneLayer:SetHidden(true) end
        if map.surround then map.surround:SetTexture(nil); map.surround:SetHidden(true) end
    end
    sceneWorld = nil
    namedMap, nameProbeX, nameProbeY, nameProbeAt, nameUpdatedAt = nil, nil, nil, nil, nil
    nameMouseX, nameMouseY, nameUseCenter = nil, nil, nil
    for control, alpha in pairs(oldAlpha) do control:SetAlpha(alpha) end
    oldAlpha = {}
    if oldMin then pan:SetCustomZoomMinMax(oldMin, oldMax) else pan:ClearCustomZoomMinMax() end
    WORLD_MAP_MANAGER:ResizeAndReanchorMap()
    pan:InitializeMap()
end

local function Refresh()
    if changing or applying then return end
    if not WORLD_MAP_SCENE:IsShowing() or IsInGamepadPreferredMode() or not WORLD_MAP_MANAGER:IsMapChangingAllowed() then
        Stop()
        return
    end
    if not UsesAtlas(GetCurrentMapId()) then Stop(); return end
    if not world and not LoadMaps() then return end
    local id = GetCurrentMapId()
    local map = byId[id] or ResolveRealmMap(id)
    if not map then
        local _, mapType, contentType = GetMapInfoById(id)
        if mapType == MAPTYPE_SUBZONE and contentType == MAP_CONTENT_NONE then
            local candidate = ReadMap(id)
            if candidate then
                NormalizeMap(candidate)
                local x, y = candidate.x + candidate.width / 2, candidate.y + candidate.height / 2
                for _, parent in ipairs(maps) do
                    if parent.fitted and Contains(parent.native, x, y) then
                        PickMap(parent.x + (x - parent.native.x) * parent.width / parent.native.width,
                            parent.y + (y - parent.native.y) * parent.height / parent.native.height)
                        if byId[id] then break end
                    end
                end
                if not byId[id] then PickMap(x, y) end
                map = byId[id]
            end
        end
    end
    if not map or (map ~= world and map ~= cosmic and not map.outline and not map.parent) then Stop(); return end
    if not active then
        if pan.pendingInitializeMap or not pan:CanInitializeMap() then return end
        oldMin, oldMax = pan.customMin, pan.customMax
        basePinAlpha = ZO_WorldMapContainer:GetControlAlpha()
        active = true
        pan:ClearTargetOffset()
        pan:ClearTargetNormalizedZoom()
        pan:ClearLockPoint()
        pan:SetCustomZoomMinMax(minimumZoom, MAX_ZOOM)
        surface:SetHidden(false)
        canvas:SetHidden(false)
        labels:SetHidden(not settings.zoneNames)
        nameUpdatedAt = GetFrameTimeSeconds()
    end
    local previous = currentMap
    currentMap = map
    sceneWorld = cosmic and RealmForMap(map) or nil
    pinTransition = nil
    if previous and previous ~= map then
        SetPinOpacity(0)
        FadePins(1)
    else
        SetPinOpacity(1)
    end
    WORLD_MAP_MANAGER:ResetBlobs()
    viewWidth, viewHeight = viewport:GetDimensions()
    fitSize = math.min(viewWidth, viewHeight)
    if fitSize <= 0 then Stop(); return end
    cameraX, cameraY = map.x + map.width / 2, map.y + map.height / 2
    focusX, focusY = cameraX, cameraY
    zoom, motion, press, settleAt = RegionZoom(map), nil, nil, nil
    ApplyView()
end

local function Focus(x, y, useCurrentZoom)
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        Animate(currentMap.x + x * currentMap.width, currentMap.y + y * currentMap.height,
            useCurrentZoom and zoom or math.min(MAX_ZOOM, RegionZoom(currentMap) * 1.5))
    end
end

local function Initialize()
    settings = ZO_SavedVars:NewAccountWide("OpenTamrielSettings", 1, nil, defaults, GetWorldName())
    addon.settings = settings
    -- LAM requires a named control; it must not overwrite the shared addon namespace.
    local panelName = ADDON_NAME .. "SettingsPanel"
    ui.settingsPanel = LAM:RegisterAddonPanel(panelName, {
        type = "panel", name = ADDON_NAME, displayName = ADDON_NAME, author = "Wrynch",
        version = addon.version, registerForRefresh = true, registerForDefaults = true,
    })
    local options = {}
    for _, option in ipairs({
        { "emptyTerrain", "Use empty terrain artwork", "Show detailed terrain artwork in areas without playable zones." },
        { "zoneNames", "Show zone names", "Show zone names over the map." },
        { "clouds", "Show clouds", "Show moving clouds over Tamriel." },
    }) do
        local key = option[1]
        options[#options + 1] = {
            type = "checkbox", name = option[2], tooltip = option[3], default = defaults[key],
            getFunc = function() return settings[key] end,
            setFunc = function(value)
                settings[key] = value
                if active then
                    labels:SetHidden(not settings.zoneNames)
                    ApplyView()
                end
            end,
        }
    end
    LAM:RegisterOptionControls(panelName, options)
    viewport, pan = ZO_WorldMapScroll, ZO_WorldMap_GetPanAndZoom()
    surface = WINDOW_MANAGER:CreateControl(nil, viewport, CT_CONTROL)
    ui.surface = surface
    surface:SetAnchorFill(viewport)
    surface:SetDrawTier(DT_MEDIUM)
    surface:SetDrawLevel(1)
    surface:SetMouseEnabled(true)
    surface:SetHidden(true)
    surface:SetHandler("OnMouseDown", MouseDown)
    surface:SetHandler("OnMouseUp", MouseUp)
    surface:SetHandler("OnMouseWheel", function(_, delta) ZoomAt(ZOOM_STEP ^ delta, GetUIMousePosition()) end)
    surface:SetHandler("OnMouseEnter", ZO_WorldMap_MouseEnter)
    surface:SetHandler("OnMouseExit", ZO_WorldMap_MouseExit)
    canvas = WINDOW_MANAGER:CreateControl(nil, viewport, CT_CONTROL)
    ui.canvas = canvas
    canvas:SetDrawTier(DT_MEDIUM)
    canvas:SetDimensions(CANVAS_SIZE, CANVAS_SIZE)
    canvas:SetHidden(true)
    labels = WINDOW_MANAGER:CreateControl(nil, viewport, CT_CONTROL)
    ui.labels = labels
    labels:SetAnchorFill(viewport)
    labels:SetDrawTier(DT_MEDIUM)
    labels:SetMouseEnabled(false)
    labels:SetHidden(true)

    nativeMouseDown = ZO_PreHook("ZO_WorldMap_MouseDown", function(...)
        if active then MouseDown(nil, ...); return true end
    end)
    nativeMouseUp = ZO_PreHook("ZO_WorldMap_MouseUp", function(...)
        if active then MouseUp(...); return true end
    end)
    ZO_PreHook(pan, "Update", function(_, now) if active then Update(now); return true end end)
    ZO_PreHook(pan, "InitializeMap", function()
        -- Restore native state before it consumes pending quest/pin navigation in an excluded map.
        if active and not UsesAtlas(GetCurrentMapId()) then Stop(); return true end
        local map = byId and byId[GetCurrentMapId()]
        return active and map and (map == world or map == cosmic or map.outline or map.parent) and true
    end)
    ZO_PostHook(pan, "InitializeMap", function() if not active then Refresh() end end)
    ZO_PreHook(pan, "AddZoomDelta", function(_, delta, x, y)
        if active then ZoomAt(ZOOM_STEP ^ delta, x, y); return true end
    end)
    ZO_PreHook(pan, "Step", function(_, amount)
        if active then ZoomAt(ZOOM_STEP ^ amount, viewport:GetCenter()); return true end
    end)
    ZO_PreHook(pan, "SetTargetNormalizedZoom", function(_, value)
        if active and not applying then
            Animate(cameraX, cameraY, minimumZoom + (MAX_ZOOM - minimumZoom) * ZO_EaseNormalizedZoom(zo_clamp(value, 0, 1)))
            return true
        end
    end)
    ZO_PostHook(pan, "JumpToPin", function(_, pin, keepZoom)
        if active and not applying and pin then
            local x, y = pin:GetNormalizedPosition()
            Focus(x, y, keepZoom)
            ApplyView()
        end
    end)
    ZO_PreHook(pan, "PanToPin", function(_, pin, keepZoom)
        if active then
            if pin then local x, y = pin:GetNormalizedPosition(); Focus(x, y, keepZoom) end
            return true
        end
    end)
    ZO_PreHook(pan, "PanToNormalizedPosition", function(_, x, y, keepZoom)
        if active then Focus(x, y, keepZoom); return true end
    end)
    ZO_PreHook(WORLD_MAP_MANAGER, "UpdateBlobs", function() return active and UsesAtlas(GetCurrentMapId()) end)
    ZO_PostHook(WORLD_MAP_TILES_MANAGER, "LayoutTiles", HideNativeArt)
    ZO_PostHook(WORLD_MAP_MANAGER, "ResizeAndReanchorMap", ApplyView)
    ZO_PostHookHandler(viewport, "OnRectChanged", ApplyView)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", Refresh)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapModeChanged", Refresh)
    WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWN then Refresh() elseif state == SCENE_HIDING then Stop() end
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, Refresh)
    SLASH_COMMANDS["/opentamriel"] = ZO_WorldMap_ShowWorldMap
    SLASH_COMMANDS["/otclouds"] = ReportClouds
    SLASH_COMMANDS["/otmaps"] = CaptureMaps
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end)
