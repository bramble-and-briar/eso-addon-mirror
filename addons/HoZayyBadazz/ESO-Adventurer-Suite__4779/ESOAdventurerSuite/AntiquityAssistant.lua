-- ESO Adventurer Suite
-- Antiquity navigation, excavation guidance, and skill-point recommendations.

ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.AntiquityAssistant = EPC.AntiquityAssistant or {}
local A = EPC.AntiquityAssistant

local wm = WINDOW_MANAGER
local GPS = LibGPS3
local LMP = LibMapPins
local KNOWN_DIG_SPAWNS = EPC.AntiquityKnownDigSpawns or {}
local WORLD_PIN_TYPE = "EAS_ANTIQUITY_SHOVEL_PIN"
local SHOVEL_TEXTURE = "/esoui/art/icons/u26_ability_digging_02.dds"
local GLOW_TEXTURE = "EsoUI/Art/MapPins/MapPing.dds"
local ARROW_TEXTURE = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds"
local UPDATE_NAME = (EPC.name or "EAS") .. "_AntiquityAssistant"
local TWO_PI = math.pi * 2
local LEARNED_DIG_MAX = 600
local LEARNED_DIG_FORWARD_CM = 220
local LEARNED_DIG_MATCH_EPSILON = 0.018
local KNOWN_SPAWN_CONFIRM_METERS = 22
local KNOWN_SPAWN_DEDUPE_METERS = 10
local KNOWN_SPAWN_DEFAULT_BLOB_METERS = 290
local KNOWN_SPAWN_MAX_RENDER = 12

-- ESO does not expose the exact overland Antiquity mound as a map/world
-- coordinate.  It does expose the real interaction target when the reticle
-- acquires it, so the Suite uses that as the authoritative exact-spot signal
-- instead of drawing a misleading marker at the center of the search area.
local EXACT_DIG_INTERACT_HINTS = {
    "excavat",       -- English / Spanish variants
    "dig site",
    "digsite",
    "ausgrab",       -- German: Ausgraben / Ausgrabungsstätte
    "fouill",        -- French: fouiller / fouilles
    "scav",          -- Italian-ish/localized fallback
    "раскоп",        -- Russian lowercase
    "Раскоп",        -- Russian uppercase fallback (Lua string.lower is byte based)
}

local COLORS = {
    gold = { 1.00, 0.78, 0.24, 1.00 },
    green = { 0.16, 0.88, 0.34, 1.00 },
    yellow = { 1.00, 0.82, 0.14, 1.00 },
    orange = { 1.00, 0.42, 0.08, 1.00 },
    red = { 0.80, 0.10, 0.08, 1.00 },
    text = { 0.96, 0.94, 0.88, 1.00 },
    muted = { 0.72, 0.74, 0.78, 1.00 },
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local values = { pcall(fn, ...) }
    if not values[1] then return fallback end
    table.remove(values, 1)
    return unpack(values)
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then return GetFrameTimeMilliseconds() end
    return math.floor((tonumber(GetFrameTimeSeconds and GetFrameTimeSeconds()) or 0) * 1000)
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function distance2D(x1, y1, x2, y2)
    local dx = (tonumber(x2) or 0) - (tonumber(x1) or 0)
    local dy = (tonumber(y2) or 0) - (tonumber(y1) or 0)
    return math.sqrt((dx * dx) + (dy * dy))
end

local function rotationForDelta(dx, dy)
    dx, dy = tonumber(dx) or 0, tonumber(dy) or 0
    if dx == 0 and dy == 0 then return 0 end
    local angle
    if dy < 0 then
        angle = math.atan(dx / -dy)
    elseif dy > 0 and dx >= 0 then
        angle = math.atan(dx / -dy) + math.pi
    elseif dy > 0 and dx < 0 then
        angle = math.atan(dx / -dy) - math.pi
    elseif dx > 0 then
        angle = math.pi * 0.5
    else
        angle = -math.pi * 0.5
    end
    if angle < 0 then angle = angle + TWO_PI end
    return angle
end

local function directionName(dx, dy)
    local horizontal = dx > 0 and "RIGHT" or (dx < 0 and "LEFT" or "")
    local vertical = dy > 0 and "DOWN" or (dy < 0 and "UP" or "")
    if horizontal ~= "" and vertical ~= "" then return vertical .. " + " .. horizontal end
    if horizontal ~= "" then return horizontal end
    if vertical ~= "" then return vertical end
    return "HERE"
end

local function normalizedLower(text)
    text = tostring(text or "")
    if type(zo_strlower) == "function" then
        local lowered = safe(zo_strlower, nil, text)
        if type(lowered) == "string" then return lowered end
    end
    return string.lower(text)
end

local function validDigCell(row, column)
    row, column = tonumber(row), tonumber(column)
    if not row or not column then return nil end
    row, column = math.floor(row), math.floor(column)
    if row < 1 or column < 1 or row > 30 or column > 30 then return nil end
    return row, column
end

function A:GetShovelTexture()
    -- Use ESO's shipped Heavy Shovel ability art directly.  The previous
    -- digsite_unknown fallback is not a valid texture on all clients and
    -- renders as ESO's red question-mark placeholder.
    self.shovelTexture = SHOVEL_TEXTURE
    return SHOVEL_TEXTURE
end

function A:InvalidateDigSites()
    self.cachedMapId = nil
    self.cachedDigSites = nil
    self.cachedAt = 0
end

function A:GetCurrentMapDigSites(force)
    if not EPC.saved or EPC.saved.antiquityAssistantEnabled == false then return {} end
    if type(GetNumInProgressAntiquities) ~= "function" or type(GetDigSiteNormalizedCenterPosition) ~= "function" then return {} end
    local mapId = tonumber(safe(GetCurrentMapId, 0)) or 0
    local stamp = nowMs()
    if force ~= true and self.cachedMapId == mapId and type(self.cachedDigSites) == "table" and stamp - (self.cachedAt or 0) < 650 then
        return self.cachedDigSites
    end

    local sites, seen = {}, {}
    local antiquityCount = tonumber(safe(GetNumInProgressAntiquities, 0)) or 0
    for antiquityIndex = 1, antiquityCount do
        local antiquityId = tonumber(safe(GetInProgressAntiquityId, 0, antiquityIndex)) or 0
        local antiquityName = type(GetAntiquityName) == "function" and tostring(safe(GetAntiquityName, "Antiquity", antiquityId) or "Antiquity") or "Antiquity"
        local digSiteCount = tonumber(safe(GetNumDigSitesForInProgressAntiquity, 0, antiquityIndex)) or 0
        for digSiteIndex = 1, digSiteCount do
            local digSiteId = tonumber(safe(GetInProgressAntiquityDigSiteId, 0, antiquityIndex, digSiteIndex)) or 0
            if digSiteId > 0 and not seen[digSiteId] then
                local x, y, shown = safe(GetDigSiteNormalizedCenterPosition, nil, digSiteId)
                x, y = tonumber(x), tonumber(y)
                if x and y and shown == true and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    seen[digSiteId] = true
                    sites[#sites + 1] = { digSiteId = digSiteId, antiquityId = antiquityId, name = antiquityName, x = x, y = y }
                end
            end
        end
    end
    self.cachedMapId, self.cachedDigSites, self.cachedAt = mapId, sites, stamp
    return sites
end

function A:RegisterWorldMapPins()
    if type(ZO_WorldMap_GetPinManager) ~= "function" then return end
    local manager = ZO_WorldMap_GetPinManager()
    if not manager or type(manager.AddCustomPin) ~= "function" then return end
    self.worldMapPinManager = manager
    if _G[WORLD_PIN_TYPE] == nil then
        manager:AddCustomPin(WORLD_PIN_TYPE, function(pinManager)
            local pinType = _G[WORLD_PIN_TYPE]
            if not pinType then return end
            for _, site in ipairs(A:GetCurrentMapDigSites(true)) do
                pinManager:CreatePin(pinType, site, site.x, site.y)
            end
        end, nil, {
            level = 176,
            size = 40,
            minSize = 30,
            texture = self:GetShovelTexture(),
            tint = function() return ZO_ColorDef:New(1.00, 0.78, 0.24, 1.00) end,
        }, nil)
    end
    self:RefreshWorldMapPins()
end

function A:RefreshWorldMapPins()
    local manager = self.worldMapPinManager
    local pinType = _G[WORLD_PIN_TYPE]
    if not manager or not pinType then return end
    local enabled = EPC.saved and EPC.saved.antiquityAssistantEnabled ~= false and EPC.saved.antiquityShowWorldMap ~= false
    if type(manager.SetCustomPinEnabled) == "function" then manager:SetCustomPinEnabled(pinType, enabled == true) end
    if type(manager.RefreshCustomPins) == "function" then manager:RefreshCustomPins(pinType) end
end

function A:EnsureWorldRoot()
    if self.worldRoot or not wm then return end
    local root = wm:CreateTopLevelWindow("EAS_AntiquityWorldPins")
    root:SetHidden(false)
    root:SetMouseEnabled(false)
    if type(root.Create3DRenderSpace) == "function" then root:Create3DRenderSpace() end
    self.worldRoot = root
    if ZO_SimpleSceneFragment and type(ZO_SimpleSceneFragment.New) == "function" then
        local ok, fragment = pcall(ZO_SimpleSceneFragment.New, ZO_SimpleSceneFragment, root)
        if ok and fragment then
            self.worldFragment = fragment
            for _, scene in ipairs({ HUD_SCENE, HUD_UI_SCENE, LOOT_SCENE }) do
                if scene and type(scene.AddFragment) == "function" then pcall(scene.AddFragment, scene, fragment) end
            end
        end
    end
    self.worldOriginReady = false
end

function A:IsNormalWorldSceneActive()
    if type(IsDiggingGameActive) == "function" and safe(IsDiggingGameActive, false) == true then return false end
    if not SCENE_MANAGER or type(SCENE_MANAGER.GetCurrentScene) ~= "function" then return false end
    local scene = safe(function() return SCENE_MANAGER:GetCurrentScene() end, nil)
    local name = ""
    if scene and type(scene.GetName) == "function" then name = normalizedLower(safe(function() return scene:GetName() end, "") or "") end
    if name == "hud" or name == "hudui" or name == "loot" then return true end
    if string.find(name, "hud", 1, true) and not string.find(name, "menu", 1, true) then return true end
    return false
end

function A:RecoverWorldRenderer(reason)
    if not self:IsNormalWorldSceneActive() then return false end
    self:EnsureWorldRoot()
    if self.worldRoot and type(self.worldRoot.SetHidden) == "function" then self.worldRoot:SetHidden(false) end
    self.worldOriginReady = false
    self:UpdateWorldOrigin()
    self.lastWorldRendererRecoveryAt = nowMs()
    self.lastWorldRendererRecoveryReason = tostring(reason or "automatic recovery")
    self:RefreshWorldMarkers()
    return true
end

function A:UpdateWorldOrigin()
    self:EnsureWorldRoot()
    if not self.worldRoot or type(WorldPositionToGuiRender3DPosition) ~= "function" then return false end
    local gx, gz, gy = safe(WorldPositionToGuiRender3DPosition, nil, 0, 0, 0)
    gx, gz, gy = tonumber(gx), tonumber(gz), tonumber(gy)
    if not gx or not gz or not gy then return false end
    self.worldOriginX, self.worldOriginZ, self.worldOriginY = gx, gz, gy
    self.worldRoot:Set3DRenderSpaceOrigin(gx, gz, gy)
    self.worldOriginReady = true
    return true
end

function A:EnsureWorldMarker(index)
    self:EnsureWorldRoot()
    self.worldMarkers = self.worldMarkers or {}
    if self.worldMarkers[index] then return self.worldMarkers[index] end
    local pin = wm:CreateControl("EAS_AntiquityWorldPin" .. tostring(index), self.worldRoot, CT_CONTROL)
    local glow = wm:CreateControl(nil, pin, CT_TEXTURE)
    local icon = wm:CreateControl(nil, pin, CT_TEXTURE)
    pin.glow, pin.icon = glow, icon
    for _, control in ipairs({ pin, glow, icon }) do
        control:SetMouseEnabled(false)
        if type(control.Create3DRenderSpace) == "function" then control:Create3DRenderSpace() end
    end
    glow:SetTexture(GLOW_TEXTURE)
    if type(glow.SetBlendMode) == "function" and TEX_BLEND_MODE_ADD ~= nil then glow:SetBlendMode(TEX_BLEND_MODE_ADD) end
    icon:SetTexture(self:GetShovelTexture())
    pin:SetHidden(true)
    self.worldMarkers[index] = pin
    return pin
end

function A:HideWorldMarkers(reason)
    for _, marker in ipairs(self.worldMarkers or {}) do marker:SetHidden(true) end
    self.lastWorldHiddenReason = reason
end

function A:GetLearnedDigSpots()
    if not EPC.saved then return {} end
    if type(EPC.saved.antiquityLearnedDigSpots) ~= "table" then EPC.saved.antiquityLearnedDigSpots = {} end
    return EPC.saved.antiquityLearnedDigSpots
end

function A:GetPlayerZoneId()
    local zoneId = 0
    if type(GetUnitZoneIndex) == "function" and type(GetZoneId) == "function" then
        local index = tonumber(safe(GetUnitZoneIndex, 0, "player")) or 0
        if index > 0 then zoneId = tonumber(safe(GetZoneId, 0, index)) or 0 end
    end
    if zoneId <= 0 and type(GetUnitRawWorldPosition) == "function" then
        zoneId = tonumber((safe(GetUnitRawWorldPosition, 0, "player"))) or 0
    end
    return zoneId
end

function A:GetNearestActiveDigSiteToPlayer()
    local sites = self:GetCurrentMapDigSites(false)
    if #sites == 0 then return nil end
    if #sites == 1 then return sites[1] end
    if type(GetMapPlayerPosition) ~= "function" then return sites[1] end
    local px, py, _, shown = safe(GetMapPlayerPosition, nil, "player")
    px, py = tonumber(px), tonumber(py)
    if not px or not py or shown == false then return sites[1] end
    local best, bestDistance = nil, nil
    for _, site in ipairs(sites) do
        local d = distance2D(px, py, site.x, site.y)
        if not best or d < bestDistance then best, bestDistance = site, d end
    end
    return best
end


-- Known-spawn support -------------------------------------------------------
-- ScrySpy's strongest idea is not a hidden-API trick: it maintains a library
-- of real dig-spawn observations and filters that library to the active ESO
-- Antiquity search-area polygon.  The Suite uses the same concept as a
-- candidate layer, then promotes a candidate to a learned exact mound when ESO
-- exposes the real interaction target under the reticle.
function A:GetKnownSpawnZoneKey()
    if LMP and type(LMP.GetZoneAndSubzone) == "function" then
        local key = safe(LMP.GetZoneAndSubzone, "", LMP, true, false, true)
        if type(key) == "string" and key ~= "" then return key end
    end
    return ""
end

function A:GetKnownSpawnsForCurrentArea()
    local key = self:GetKnownSpawnZoneKey()
    local rows = key ~= "" and KNOWN_DIG_SPAWNS[key] or nil
    if type(rows) ~= "table" then rows = {} end
    return rows, key
end

local function scrySpyBlobScale()
    local zoom = 0
    if type(ZO_WorldMap_GetPanAndZoom) == "function" then
        local pan = safe(ZO_WorldMap_GetPanAndZoom, nil)
        zoom = pan and tonumber(pan.currentNormalizedZoom) or 0
    end
    zoom = clamp(zoom, 0, 1)
    local bucket = math.floor(zoom * 10)
    local sizeMapping = { [0]=10,[1]=10,[2]=9,[3]=8,[4]=7,[5]=6,[6]=5,[7]=4,[8]=3,[9]=2,[10]=1 }
    local factorMapping = { [0]=2.9,[1]=3.7,[2]=3.4,[3]=3.0,[4]=2.6,[5]=2.2,[6]=1.7,[7]=1.1,[8]=1.5,[9]=-0.2,[10]=-0.9 }
    return sizeMapping[bucket] or 1, factorMapping[bucket] or 0
end

function A:UpdateKnownActiveDigAreas()
    local areas = {}
    local pinManager = LMP and LMP.pinManager
    local mapping = pinManager and pinManager.m_keyToPinMapping and pinManager.m_keyToPinMapping["antiquityDigSite"]
    local active = pinManager and pinManager.m_Active
    if type(mapping) == "table" and type(active) == "table" then
        local indexes = {}
        for _, outer in pairs(mapping) do
            if type(outer) == "table" then
                for _, index in pairs(outer) do
                    if tonumber(index) then indexes[#indexes + 1] = tonumber(index) end
                end
            elseif tonumber(outer) then
                indexes[#indexes + 1] = tonumber(outer)
            end
        end
        local zoomFactor, zoomModifier = scrySpyBlobScale()
        for _, index in ipairs(indexes) do
            local pin = active[index]
            if type(pin) == "table" then
                local x, y = tonumber(pin.normalizedX), tonumber(pin.normalizedY)
                if x and y then
                    local meters = KNOWN_SPAWN_DEFAULT_BLOB_METERS
                    local blobKey = pin.polygonBlobKey
                    if blobKey and wm and type(wm.GetControlByName) == "function" then
                        local control = wm:GetControlByName("ZO_WorldMapContainerPinPolygonBlob", blobKey)
                        if control and type(control.GetDimensions) == "function" then
                            local width = tonumber((safe(control.GetDimensions, nil, control)))
                            if width and width > 0 then
                                meters = math.max(80, (width * zoomFactor) - (width * zoomModifier))
                            end
                        end
                    end
                    areas[#areas + 1] = { x = x, y = y, size = meters, blobKey = blobKey }
                end
            end
        end
    end

    -- Fallback for clients/contexts where LibMapPins has not materialized the
    -- polygon control yet.  The native active dig-site center is still useful
    -- enough to restrict the known-spawn library to the local search region.
    if #areas == 0 then
        for _, site in ipairs(self:GetCurrentMapDigSites(false)) do
            areas[#areas + 1] = { x = site.x, y = site.y, size = KNOWN_SPAWN_DEFAULT_BLOB_METERS, digSiteId = site.digSiteId }
        end
    end
    self.knownActiveDigAreas = areas
    self.knownActiveDigAreasAt = nowMs()
    return areas
end

function A:GetKnownActiveDigAreas(force)
    if force == true or type(self.knownActiveDigAreas) ~= "table" or nowMs() - (tonumber(self.knownActiveDigAreasAt) or 0) > 1000 then
        return self:UpdateKnownActiveDigAreas()
    end
    return self.knownActiveDigAreas
end

function A:GetKnownSpawnCandidates(force)
    if not EPC.saved or EPC.saved.antiquityKnownSpawnAssist == false then return {} end
    if not GPS or type(GPS.GetLocalDistanceInMeters) ~= "function" then return {} end
    local rows, zoneKey = self:GetKnownSpawnsForCurrentArea()
    if #rows == 0 then return {} end
    local areas = self:GetKnownActiveDigAreas(force)
    if #areas == 0 then return {} end

    local px, py = nil, nil
    if type(GetMapPlayerPosition) == "function" then
        px, py = safe(GetMapPlayerPosition, nil, "player")
        px, py = tonumber(px), tonumber(py)
    end
    local maxDistance = clamp(EPC.saved.antiquity3DRange or 1200, 100, 3000)
    local result = {}
    for index, loc in ipairs(rows) do
        if type(loc) == "table" then
            local x, y = tonumber(loc[1]), tonumber(loc[2])
            if x and y then
                local inside = false
                for _, area in ipairs(areas) do
                    local meters = tonumber(safe(GPS.GetLocalDistanceInMeters, 999999, GPS, area.x, area.y, x, y)) or 999999
                    if meters <= (tonumber(area.size) or KNOWN_SPAWN_DEFAULT_BLOB_METERS) then inside = true break end
                end
                if inside then
                    local playerDistance = 0
                    if px and py then playerDistance = tonumber(safe(GPS.GetLocalDistanceInMeters, 999999, GPS, px, py, x, y)) or 999999 end
                    if not px or playerDistance <= maxDistance then
                        result[#result + 1] = {
                            known = true, knownIndex = index, zoneKey = zoneKey,
                            mapX = x, mapY = y,
                            globalX = tonumber(loc[3]), globalY = tonumber(loc[4]),
                            worldX = tonumber(loc[5]), worldY = tonumber(loc[6]), worldZ = tonumber(loc[7]),
                            playerDistance = playerDistance,
                        }
                    end
                end
            end
        end
    end
    table.sort(result, function(left, right) return (left.playerDistance or 999999) < (right.playerDistance or 999999) end)
    return result
end

function A:DistanceKnownCandidateToMapPoint(candidate, mapX, mapY)
    if not candidate or not mapX or not mapY or not GPS or type(GPS.GetLocalDistanceInMeters) ~= "function" then return math.huge end
    return tonumber(safe(GPS.GetLocalDistanceInMeters, math.huge, GPS, candidate.mapX, candidate.mapY, mapX, mapY)) or math.huge
end

function A:FindNearestKnownCandidate(mapX, mapY, candidates, maxMeters)
    candidates = candidates or self:GetKnownSpawnCandidates(false)
    local best, bestMeters = nil, nil
    for _, candidate in ipairs(candidates or {}) do
        local meters = self:DistanceKnownCandidateToMapPoint(candidate, mapX, mapY)
        if (not best or meters < bestMeters) and (not maxMeters or meters <= maxMeters) then
            best, bestMeters = candidate, meters
        end
    end
    return best, bestMeters
end

function A:FindLearnedSpotForKnownCandidate(candidate)
    if not candidate or not GPS or type(GPS.GetLocalDistanceInMeters) ~= "function" then return nil end
    for _, spot in ipairs(self:GetLearnedDigSpots()) do
        if type(spot) == "table" then
            if spot.knownZoneKey == candidate.zoneKey and tonumber(spot.knownIndex) == tonumber(candidate.knownIndex) then return spot end
            if spot.knownZoneKey == candidate.zoneKey and tonumber(spot.knownMapX) and tonumber(spot.knownMapY) then
                local meters = tonumber(safe(GPS.GetLocalDistanceInMeters, math.huge, GPS, spot.knownMapX, spot.knownMapY, candidate.mapX, candidate.mapY)) or math.huge
                if meters <= KNOWN_SPAWN_DEDUPE_METERS then return spot end
            end
        end
    end
    return nil
end

function A:EstimateExactMoundPosition()
    if type(GetMapPlayerPosition) ~= "function" or not GPS or type(GPS.GetCurrentMapMeasurement) ~= "function" then return nil end
    local px, py, _, shown = safe(GetMapPlayerPosition, nil, "player")
    px, py = tonumber(px), tonumber(py)
    if not px or not py or shown == false then return nil end
    local measurement = GPS:GetCurrentMapMeasurement()
    if not measurement or type(measurement.ToWorld) ~= "function" then return nil end

    -- Convert a small normalized map step to world centimeters so the saved
    -- point can be placed approximately at the interactable mound rather than
    -- at the player's feet. The camera heading is in the same north-up map
    -- convention used by ESO's player/map heading.
    local ok1, wx1, wy1, wz1 = pcall(measurement.ToWorld, measurement, px, py)
    local step = 0.001
    local ok2, wx2, wy2, wz2 = pcall(measurement.ToWorld, measurement, clamp(px + step, 0, 1), py)
    wx1, wy1, wz1 = tonumber(wx1), tonumber(wy1), tonumber(wz1)
    wx2, wy2, wz2 = tonumber(wx2), tonumber(wy2), tonumber(wz2)
    if not ok1 or not ok2 or not wx1 or not wz1 or not wx2 or not wz2 then return nil end
    local cmPerStep = distance2D(wx1, wz1, wx2, wz2)
    if cmPerStep <= 1 then return nil end
    local normalizedForward = (LEARNED_DIG_FORWARD_CM / cmPerStep) * step
    local heading = tonumber(safe(GetPlayerCameraHeading, 0)) or 0
    local tx = clamp(px + (math.sin(heading) * normalizedForward), 0, 1)
    local ty = clamp(py - (math.cos(heading) * normalizedForward), 0, 1)
    local ok3, wx, wy, wz = pcall(measurement.ToWorld, measurement, tx, ty)
    wx, wy, wz = tonumber(wx), tonumber(wy), tonumber(wz)
    if not ok3 or not wx or not wy or not wz then return nil end
    return { mapX = tx, mapY = ty, worldX = wx, worldY = wy, worldZ = wz }
end

function A:FindLearnedDigSpot(site)
    if not site then return nil end
    local zoneId = self:GetPlayerZoneId()
    local mapId = tonumber(safe(GetCurrentMapId, 0)) or 0
    local best, bestDistance = nil, nil
    for _, spot in ipairs(self:GetLearnedDigSpots()) do
        if type(spot) == "table" then
            local sameZone = zoneId <= 0 or tonumber(spot.zoneId) == zoneId
            if sameZone and not spot.knownZoneKey and tonumber(spot.digSiteId) == tonumber(site.digSiteId) then return spot end
            if sameZone and not spot.knownZoneKey and tonumber(spot.mapId) == mapId and tonumber(spot.centerX) and tonumber(spot.centerY) then
                local d = distance2D(site.x, site.y, spot.centerX, spot.centerY)
                if d <= LEARNED_DIG_MATCH_EPSILON and (not best or d < bestDistance) then best, bestDistance = spot, d end
            end
        end
    end
    return best
end

function A:SaveLearnedDigSpot(site, estimate, knownCandidate)
    if not EPC.saved or EPC.saved.antiquityLearnExactDigSpots == false or not site or not estimate then return nil end
    local spots = self:GetLearnedDigSpots()
    local zoneId = self:GetPlayerZoneId()
    local mapId = tonumber(safe(GetCurrentMapId, 0)) or 0
    local existing = knownCandidate and self:FindLearnedSpotForKnownCandidate(knownCandidate) or self:FindLearnedDigSpot(site)
    local now = tonumber(safe(GetTimeStamp, 0)) or 0
    if not existing then
        existing = {}
        spots[#spots + 1] = existing
    end

    -- Smooth repeat sightings so a location gets more accurate every time ESO
    -- exposes the real mound under the reticle.
    local samples = math.max(0, tonumber(existing.samples) or 0)
    local weightOld = math.min(samples, 7)
    local weightNew = 1
    local divisor = math.max(1, weightOld + weightNew)
    local function blend(old, new)
        old, new = tonumber(old), tonumber(new)
        if not old then return new end
        return ((old * weightOld) + (new * weightNew)) / divisor
    end
    existing.worldX = blend(existing.worldX, estimate.worldX)
    existing.worldY = blend(existing.worldY, estimate.worldY)
    existing.worldZ = blend(existing.worldZ, estimate.worldZ)
    existing.mapX = blend(existing.mapX, estimate.mapX)
    existing.mapY = blend(existing.mapY, estimate.mapY)
    existing.centerX, existing.centerY = site.x, site.y
    existing.digSiteId = site.digSiteId
    existing.antiquityId = site.antiquityId
    existing.name = site.name
    existing.zoneId = zoneId
    existing.mapId = mapId
    if knownCandidate then
        existing.knownZoneKey = knownCandidate.zoneKey
        existing.knownIndex = knownCandidate.knownIndex
        existing.knownMapX = knownCandidate.mapX
        existing.knownMapY = knownCandidate.mapY
    end
    existing.samples = samples + 1
    existing.lastSeen = now

    while #spots > LEARNED_DIG_MAX do
        local oldestIndex, oldestTime = 1, math.huge
        for index, spot in ipairs(spots) do
            local stamp = tonumber(spot and spot.lastSeen) or 0
            if stamp < oldestTime then oldestIndex, oldestTime = index, stamp end
        end
        table.remove(spots, oldestIndex)
    end
    return existing
end

function A:ClearLearnedDigSpots()
    if EPC.saved then EPC.saved.antiquityLearnedDigSpots = {} end
    self.learnedExactSpot = nil
    self:HideWorldMarkers("learned dig spots cleared")
end

function A:RenderLearnedDigSpot(spot, index, style)
    if not spot or type(WorldPositionToGuiRender3DPosition) ~= "function" then return false end
    local wx, wy, wz = tonumber(spot.worldX), tonumber(spot.worldY), tonumber(spot.worldZ)
    if (not wx or not wy or not wz) and tonumber(spot.mapX) and tonumber(spot.mapY) and GPS and type(GPS.GetCurrentMapMeasurement) == "function" then
        local measurement = GPS:GetCurrentMapMeasurement()
        if measurement and type(measurement.ToWorld) == "function" then
            local ok
            ok, wx, wy, wz = pcall(measurement.ToWorld, measurement, tonumber(spot.mapX), tonumber(spot.mapY))
            wx, wy, wz = tonumber(wx), tonumber(wy), tonumber(wz)
            if not ok then wx, wy, wz = nil, nil, nil end
        end
    end
    if not wx or not wy or not wz then return false end
    if not self.worldOriginReady and not self:UpdateWorldOrigin() then return false end

    local marker = self:EnsureWorldMarker(index or 1)
    local gx, gz, gy = safe(WorldPositionToGuiRender3DPosition, nil, wx, wy, wz)
    gx, gz, gy = tonumber(gx), tonumber(gz), tonumber(gy)
    if not gx or not gz or not gy then marker:SetHidden(true) return false end

    local size = clamp(EPC.saved and EPC.saved.antiquity3DScale or 1.0, 0.60, 2.00)
    if style == "CANDIDATE" then size = size * 0.78 end
    local heading = tonumber(safe(GetPlayerCameraHeading, 0)) or 0
    local useDepth = EPC.saved and EPC.saved.antiquity3DThroughWalls == false
    marker:Set3DRenderSpaceOrigin(gx - self.worldOriginX, gz - self.worldOriginZ, gy - self.worldOriginY)
    marker:Set3DRenderSpaceOrientation(0, heading, 0)
    marker:Set3DRenderSpaceUsesDepthBuffer(useDepth)
    marker.glow:Set3DRenderSpaceUsesDepthBuffer(useDepth)
    marker.icon:Set3DRenderSpaceUsesDepthBuffer(useDepth)
    marker.glow:Set3DRenderSpaceOrigin(0, 2.25 * size, 0)
    marker.icon:Set3DRenderSpaceOrigin(0, 2.25 * size, 0)
    marker.glow:Set3DLocalDimensions(2.35 * size, 2.35 * size)
    marker.icon:Set3DLocalDimensions(1.60 * size, 1.60 * size)
    if style == "CANDIDATE" then
        marker.glow:SetColor(0.12, 0.70, 0.95, 0.26)
        marker.icon:SetColor(0.58, 0.88, 1.00, 0.78)
    else
        marker.glow:SetColor(1.00, 0.62, 0.10, 0.46)
        marker.icon:SetColor(1.00, 0.92, 0.55, 1.00)
    end
    marker.icon:SetTexture(self:GetShovelTexture())
    marker.glow:SetHidden(false)
    marker.icon:SetHidden(false)
    marker:SetHidden(false)
    return true
end

function A:CreateExactDigSpotMarker()
    if self.exactSpotMarker or not wm then return end
    local marker = wm:CreateTopLevelWindow("EAS_AntiquityExactDigSpot")
    marker:SetDimensions(100, 100)
    marker:SetDrawTier(DT_HIGH)
    marker:SetDrawLayer(DL_OVERLAY)
    marker:SetDrawLevel(120)
    marker:SetMouseEnabled(false)
    marker:SetHidden(true)

    local glow = wm:CreateControl(nil, marker, CT_TEXTURE)
    glow:SetAnchor(CENTER, marker, CENTER, 0, 0)
    glow:SetTexture(GLOW_TEXTURE)
    if type(glow.SetBlendMode) == "function" and TEX_BLEND_MODE_ADD ~= nil then glow:SetBlendMode(TEX_BLEND_MODE_ADD) end
    glow:SetColor(1.00, 0.62, 0.10, 0.48)

    local icon = wm:CreateControl(nil, marker, CT_TEXTURE)
    icon:SetAnchor(CENTER, marker, CENTER, 0, 0)
    icon:SetTexture(self:GetShovelTexture())
    icon:SetColor(1.00, 0.92, 0.55, 1.00)

    marker.glow, marker.icon = glow, icon
    self.exactSpotMarker = marker
end

function A:HasActiveAntiquitySearch()
    if not EPC.saved or EPC.saved.antiquityAssistantEnabled == false then return false end
    if type(GetNumInProgressAntiquities) ~= "function" then return false end
    return (tonumber(safe(GetNumInProgressAntiquities, 0)) or 0) > 0
end

function A:IsExactDigMoundUnderReticle()
    if not self:HasActiveAntiquitySearch() then return false end
    if type(IsDiggingGameActive) == "function" and safe(IsDiggingGameActive, false) == true then return false end
    if type(GetGameCameraInteractableActionInfo) ~= "function" then return false end

    local action, name, interactBlocked = safe(GetGameCameraInteractableActionInfo, nil)
    if action == nil and name == nil then return false end
    local combined = normalizedLower(tostring(action or "") .. " " .. tostring(name or ""))
    if combined == " " or combined == "" then return false end

    for _, hint in ipairs(EXACT_DIG_INTERACT_HINTS) do
        local normalizedHint = normalizedLower(hint)
        if normalizedHint ~= "" and string.find(combined, normalizedHint, 1, true) then
            return true, tostring(action or ""), tostring(name or ""), interactBlocked == true
        end
    end
    return false
end

function A:RefreshExactDigSpotMarker()
    -- The old screen-space marker remains disabled. 0.29.50 layers the Suite's
    -- learned exact-mound system on top of a known-spawn candidate library.
    self:CreateExactDigSpotMarker()
    if self.exactSpotMarker then self.exactSpotMarker:SetHidden(true) end

    local enabled = EPC.saved and EPC.saved.antiquityAssistantEnabled ~= false and EPC.saved.antiquityShow3D ~= false
    if not enabled or not self:HasActiveAntiquitySearch() then
        self:HideWorldMarkers("disabled or no active antiquity")
        return
    end

    local activeSite = self:GetNearestActiveDigSiteToPlayer()
    local knownCandidates = self:GetKnownSpawnCandidates(false)
    local exact = self:IsExactDigMoundUnderReticle()

    -- When ESO exposes the actual interaction target, use the current camera
    -- estimate for the visible mound but also bind it to the nearest known
    -- ScrySpy spawn reference. That gives the learned point a stable spawn
    -- identity for future visits instead of tying it only to the broad dig-site
    -- search region.
    if exact and activeSite then
        local estimate = self:EstimateExactMoundPosition()
        if estimate then
            local known = self:FindNearestKnownCandidate(estimate.mapX, estimate.mapY, knownCandidates, KNOWN_SPAWN_CONFIRM_METERS)
            self.learnedExactSpot = self:SaveLearnedDigSpot(activeSite, estimate, known) or estimate
            self.learnedExactSiteId = activeSite.digSiteId
            self.currentKnownSpawnIndex = known and known.knownIndex or nil
            self.currentKnownSpawnZoneKey = known and known.zoneKey or nil
            self.lastExactLearnAt = nowMs()
        end
    end

    local render = {}
    local seenKnown = {}

    -- Once this session has actually acquired the mound, show only the learned
    -- exact point. This is the large gold shovel the user asked to see directly
    -- above the exposed dig location.
    if activeSite and self.learnedExactSpot and tonumber(self.learnedExactSiteId) == tonumber(activeSite.digSiteId) then
        render[#render + 1] = { spot = self.learnedExactSpot, style = "CONFIRMED" }
        if self.learnedExactSpot.knownZoneKey and self.learnedExactSpot.knownIndex then
            seenKnown[tostring(self.learnedExactSpot.knownZoneKey) .. ":" .. tostring(self.learnedExactSpot.knownIndex)] = true
        end
    else
        -- Before ESO exposes the mound, use the known-spawn database as a
        -- locator aid. Previously confirmed spawns are gold; unconfirmed known
        -- possibilities are smaller cyan shovels. The active search-area blob
        -- filters out unrelated locations.
        for _, candidate in ipairs(knownCandidates) do
            if #render >= KNOWN_SPAWN_MAX_RENDER then break end
            local key = tostring(candidate.zoneKey or "") .. ":" .. tostring(candidate.knownIndex or "")
            if not seenKnown[key] then
                local learned = self:FindLearnedSpotForKnownCandidate(candidate)
                if learned then
                    render[#render + 1] = { spot = learned, style = "CONFIRMED" }
                else
                    render[#render + 1] = { spot = candidate, style = "CANDIDATE" }
                end
                seenKnown[key] = true
            end
        end

        -- Preserve compatibility with exact spots learned before the known
        -- spawn database was added. Only use this fallback when no database
        -- candidate is available for the active area.
        if #render == 0 and activeSite then
            local legacy = self:FindLearnedDigSpot(activeSite)
            if legacy then render[#render + 1] = { spot = legacy, style = "CONFIRMED" } end
        end
    end

    local shown = 0
    for _, entry in ipairs(render) do
        local index = shown + 1
        if self:RenderLearnedDigSpot(entry.spot, index, entry.style) then shown = shown + 1 end
    end
    for index = shown + 1, #(self.worldMarkers or {}) do self.worldMarkers[index]:SetHidden(true) end
    if shown == 0 then self:HideWorldMarkers("no known or learned dig spawn in active area") end
end

function A:RefreshWorldMarkers()
    -- Exact learned-spawn behavior: never draw the old approximate search-area
    -- center as a 3D marker. ESO's Eye mist remains the route guide. Once ESO
    -- exposes the real mound, the Suite learns that spawn and reuses it later.
    self:RefreshExactDigSpotMarker()
end

local function setBackdrop(control, color, edgeColor)
    control:SetCenterColor(unpack(color))
    control:SetEdgeColor(unpack(edgeColor))
    control:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 1, 1, 1)
end

-- 0.29.37: The Excavation helper windows participate in the Suite's HUD
-- Layout Mode.  Their saved coordinates are screen-space TOPLEFT values so
-- they remain independent of the excavation board itself.
function A:AnchorExcavationOverlay(control, kind)
    if not control then return end
    control:ClearAnchors()
    local leftKey = kind == "PICKER" and "antiquityTilePickerLeft" or "antiquityGuideLeft"
    local topKey = kind == "PICKER" and "antiquityTilePickerTop" or "antiquityGuideTop"
    local left = tonumber(EPC.saved and EPC.saved[leftKey]) or -1
    local top = tonumber(EPC.saved and EPC.saved[topKey]) or -1
    if left >= 0 and top >= 0 then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    elseif kind == "PICKER" then
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 20)
    else
        control:SetAnchor(TOP, GuiRoot, TOP, 0, 94)
    end
end

function A:SaveExcavationOverlayPosition(control, kind)
    if not control or not EPC.saved then return end
    local left = tonumber(control:GetLeft())
    local top = tonumber(control:GetTop())
    if not left or not top then return end
    local rootWidth = tonumber(GuiRoot and GuiRoot:GetWidth()) or 1920
    local rootHeight = tonumber(GuiRoot and GuiRoot:GetHeight()) or 1080
    local width = tonumber(control:GetWidth()) or 0
    local height = tonumber(control:GetHeight()) or 0
    left = clamp(left, 0, math.max(0, rootWidth - math.min(width, rootWidth)))
    top = clamp(top, 0, math.max(0, rootHeight - math.min(height, rootHeight)))
    if kind == "PICKER" then
        EPC.saved.antiquityTilePickerLeft = left
        EPC.saved.antiquityTilePickerTop = top
    else
        EPC.saved.antiquityGuideLeft = left
        EPC.saved.antiquityGuideTop = top
    end
    self:AnchorExcavationOverlay(control, kind)
end

function A:CreateLayoutDragShield(parent, kind)
    local shield = wm:CreateControl(nil, parent, CT_CONTROL)
    shield:SetAnchorFill(parent)
    shield:SetMouseEnabled(true)
    shield:SetHidden(true)
    shield:SetDrawLayer(DL_OVERLAY)
    shield:SetDrawLevel(250)

    local labelBg = wm:CreateControl(nil, shield, CT_BACKDROP)
    labelBg:SetDimensions(kind == "PICKER" and 230 or 260, 34)
    labelBg:SetAnchor(TOP, shield, TOP, 0, 6)
    setBackdrop(labelBg, { 0.02, 0.03, 0.04, 0.96 }, { 0.00, 0.95, 1.00, 1.00 })

    local label = wm:CreateControl(nil, labelBg, CT_LABEL)
    label:SetAnchorFill(labelBg)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(0.00, 0.95, 1.00, 1.00)
    label:SetText(kind == "PICKER" and "DRAG • AUGUR TILE SELECTOR" or "DRAG • AUGUR GUIDE")

    shield:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and A.layoutMode then
            parent:StartMoving()
        end
    end)
    shield:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and A.layoutMode then
            parent:StopMovingOrResizing()
            A:SaveExcavationOverlayPosition(parent, kind)
        end
    end)
    return shield
end

function A:SetNativeEditHudPreview(active)
    active = active == true
    self.nativeEditHudPreview029780 = active

    self:CreateExcavationGuide()
    self:CreateTilePicker()

    if active then
        if self.guide then
            if self.SetGuideMessage then
                pcall(self.SetGuideMessage, self,
                    "EXCAVATION GUIDE",
                    "Use Augur, then follow the Suite recommendation.",
                    "GREEN = dig. Other colors guide the next scan.",
                    0)
            end
            if self.SetAugurButtonsVisible then pcall(self.SetAugurButtonsVisible, self, true) end
        end
        if self.tilePicker then
            if self.tilePicker.title then self.tilePicker.title:SetText("SELECT AUGUR TILE") end
            if self.tilePicker.detail then self.tilePicker.detail:SetText("Select the scanned tile so the Suite can continue the route.") end
        end
        for _, control in ipairs({ self.guide, self.tilePicker }) do
            if control then
                control:SetHidden(false)
                control:SetAlpha(1)
                control:SetMouseEnabled(false)
                control:SetMovable(false)
                if control.SetClampedToScreen then control:SetClampedToScreen(true) end
                if control.SetTopLevel then control:SetTopLevel(true) end
                if control.SetDrawTier and DT_HIGH then control:SetDrawTier(DT_HIGH) end
                if control.SetDrawLayer and DL_OVERLAY then control:SetDrawLayer(DL_OVERLAY) end
                -- Keep the real preview below ESO's transparent editor hitbox.
                if control.SetDrawLevel then control:SetDrawLevel(100) end
            end
        end
        if self.guide and self.guide.layoutDragShield then
            self.guide.layoutDragShield:SetHidden(true)
            self.guide.layoutDragShield:SetMouseEnabled(false)
        end
        if self.tilePicker and self.tilePicker.layoutDragShield then
            self.tilePicker.layoutDragShield:SetHidden(true)
            self.tilePicker.layoutDragShield:SetMouseEnabled(false)
        end
    else
        -- Return to the normal Antiquity runtime visibility rules.
        local enabled = EPC.saved and EPC.saved.antiquityAssistantEnabled ~= false and EPC.saved.antiquityExcavationGuide ~= false
        local digging = type(IsDiggingGameActive) == "function" and safe(IsDiggingGameActive, false) == true
        if self.nativeEditHudPreview029780 ~= true then
            if self.guide then self.guide:SetHidden(not (enabled and digging)) end
            if self.tilePicker then self.tilePicker:SetHidden(not (enabled and digging and self.pendingManualColor ~= nil)) end
        end
    end
end

function A:SetLayoutMode(active)
    self.layoutMode = active == true
    self:CreateExcavationGuide()
    self:CreateTilePicker()

    local function configure(control, shield)
        if not control then return end
        control:SetMovable(self.layoutMode)
        if type(control.SetClampedToScreen) == "function" then control:SetClampedToScreen(true) end
        if shield then shield:SetHidden(not self.layoutMode) end
        if self.layoutMode then control:SetHidden(false) end
    end

    configure(self.guide, self.guide and self.guide.layoutDragShield)
    configure(self.tilePicker, self.tilePicker and self.tilePicker.layoutDragShield)

    if self.layoutMode then
        if self.guide then
            self.guide:SetDrawTier(DT_HIGH)
            self.guide:SetDrawLayer(DL_OVERLAY)
            self.guide:SetDrawLevel(240)
        end
        if self.tilePicker then
            self.tilePicker:SetDrawTier(DT_HIGH)
            self.tilePicker:SetDrawLayer(DL_OVERLAY)
            self.tilePicker:SetDrawLevel(245)
        end
    else
        local enabled = EPC.saved and EPC.saved.antiquityAssistantEnabled ~= false and EPC.saved.antiquityExcavationGuide ~= false
        local digging = type(IsDiggingGameActive) == "function" and safe(IsDiggingGameActive, false) == true
        if self.nativeEditHudPreview029780 ~= true then
            if self.guide then self.guide:SetHidden(not (enabled and digging)) end
            if self.tilePicker then self.tilePicker:SetHidden(not (enabled and digging and self.pendingManualColor ~= nil)) end
        end
    end
end

function A:ResetPositions()
    if not EPC.saved then return end
    EPC.saved.antiquityGuideLeft = -1
    EPC.saved.antiquityGuideTop = -1
    EPC.saved.antiquityTilePickerLeft = -1
    EPC.saved.antiquityTilePickerTop = -1
    if self.guide then self:AnchorExcavationOverlay(self.guide, "GUIDE") end
    if self.tilePicker then self:AnchorExcavationOverlay(self.tilePicker, "PICKER") end
end

function A:CreateExcavationGuide()
    if self.guide or not wm then return end
    local guide = wm:CreateTopLevelWindow("EAS_ExcavationDirectionGuide")
    guide:SetDimensions(680, 148)
    self:AnchorExcavationOverlay(guide, "GUIDE")
    guide:SetDrawTier(DT_HIGH)
    guide:SetDrawLayer(DL_OVERLAY)
    guide:SetDrawLevel(100)
    guide:SetMouseEnabled(true)
    guide:SetMovable(false)
    if type(guide.SetClampedToScreen) == "function" then guide:SetClampedToScreen(true) end
    guide:SetHandler("OnMoveStop", function(control) A:SaveExcavationOverlayPosition(control, "GUIDE") end)
    guide:SetHidden(true)

    local background = wm:CreateControl(nil, guide, CT_BACKDROP)
    background:SetAnchorFill(guide)
    setBackdrop(background, { 0.025, 0.03, 0.045, 0.94 }, { 0.82, 0.60, 0.18, 0.95 })

    local arrow = wm:CreateControl(nil, guide, CT_TEXTURE)
    arrow:SetDimensions(72, 72)
    arrow:SetAnchor(LEFT, guide, LEFT, 18, -12)
    arrow:SetTexture(ARROW_TEXTURE)
    arrow:SetColor(unpack(COLORS.gold))
    guide.arrow = arrow

    local title = wm:CreateControl(nil, guide, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetColor(unpack(COLORS.gold))
    title:SetAnchor(TOPLEFT, guide, TOPLEFT, 104, 12)
    title:SetDimensions(550, 28)
    title:SetText("EXCAVATION GUIDE")
    guide.title = title

    local resetBg = wm:CreateControl(nil, guide, CT_BACKDROP)
    resetBg:SetAnchor(TOPRIGHT, guide, TOPRIGHT, -14, 12)
    resetBg:SetDimensions(74, 24)
    setBackdrop(resetBg, { 0.14, 0.15, 0.18, 0.96 }, { 0.48, 0.50, 0.55, 0.90 })
    local resetButton = wm:CreateControl(nil, guide, CT_BUTTON)
    resetButton:SetAnchorFill(resetBg)
    resetButton:SetFont("ZoFontGameSmall")
    resetButton:SetNormalFontColor(0.90, 0.90, 0.90, 1)
    resetButton:SetMouseOverFontColor(1.00, 0.82, 0.28, 1)
    resetButton:SetText("RESET")
    resetButton:SetHandler("OnClicked", function()
        if A.bonusMode == true then
            A:ResetBonusSearch(true)
            A:ShowNextBonusPrediction("Bonus search route reset.")
            return
        end
        A:ResetExcavationSolver()
        A.scanHistory = {}
        A:SetAugurButtonsVisible(true)
        local first = A:ChooseNextProbe()
        if first then
            A.lastRecommendation = first
            A:SetGuideMessage("FIRST AUGUR — START HERE", string.format("Scan ROW %d, COLUMN %d, then press the color ESO shows.", first.row, first.column), "GREEN = dig. Other colors only choose the next scan.", 0)
        else
            A:SetGuideMessage("USE AUGUR", "Scan a tile, then choose the matching color.", "GREEN = dig. Yellow / Orange / Red only guide the next scan.", 0)
        end
    end)
    guide.resetButton = resetButton

    local instruction = wm:CreateControl(nil, guide, CT_LABEL)
    instruction:SetFont("ZoFontGameBold")
    instruction:SetColor(unpack(COLORS.text))
    instruction:SetAnchor(TOPLEFT, guide, TOPLEFT, 104, 42)
    instruction:SetDimensions(552, 42)
    instruction:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    guide.instruction = instruction

    local detail = wm:CreateControl(nil, guide, CT_LABEL)
    detail:SetFont("ZoFontGameSmall")
    detail:SetColor(unpack(COLORS.muted))
    detail:SetAnchor(TOPLEFT, guide, TOPLEFT, 104, 78)
    detail:SetDimensions(552, 22)
    guide.detail = detail

    guide.buttons = {}
    local choices = {
        { "GREEN", COLORS.green }, { "YELLOW", COLORS.yellow },
        { "ORANGE", COLORS.orange }, { "RED", COLORS.red },
    }
    for index, choice in ipairs(choices) do
        local x = 104 + ((index - 1) * 138)
        local bg = wm:CreateControl(nil, guide, CT_BACKDROP)
        bg:SetAnchor(TOPLEFT, guide, TOPLEFT, x, 106)
        bg:SetDimensions(128, 30)
        setBackdrop(bg, { choice[2][1] * 0.42, choice[2][2] * 0.42, choice[2][3] * 0.42, 0.96 }, choice[2])
        local button = wm:CreateControl(nil, guide, CT_BUTTON)
        button:SetAnchorFill(bg)
        button:SetFont("ZoFontGameBold")
        button:SetNormalFontColor(1, 1, 1, 1)
        button:SetMouseOverFontColor(1, 0.92, 0.55, 1)
        button:SetText(choice[1])
        button:SetHandler("OnClicked", function() A:RecordAugurColor(choice[1]) end)
        guide.buttons[index] = { button = button, background = bg }
    end
    guide.layoutDragShield = self:CreateLayoutDragShield(guide, "GUIDE")
    self.guide = guide
    self:SetGuideMessage("USE AUGUR", "Scan a tile, then choose the matching ESO color below.", "GREEN = dig. Yellow / Orange / Red only guide the next scan.", 0)
end

function A:CreateTilePicker()
    if self.tilePicker or not wm then return end
    local picker = wm:CreateTopLevelWindow("EAS_ExcavationTilePicker")
    picker:SetDimensions(390, 455)
    self:AnchorExcavationOverlay(picker, "PICKER")
    picker:SetDrawTier(DT_HIGH)
    picker:SetDrawLayer(DL_OVERLAY)
    picker:SetDrawLevel(130)
    picker:SetMouseEnabled(true)
    picker:SetMovable(false)
    if type(picker.SetClampedToScreen) == "function" then picker:SetClampedToScreen(true) end
    picker:SetHandler("OnMoveStop", function(control) A:SaveExcavationOverlayPosition(control, "PICKER") end)
    picker:SetHidden(true)

    local background = wm:CreateControl(nil, picker, CT_BACKDROP)
    background:SetAnchorFill(picker)
    setBackdrop(background, { 0.025, 0.03, 0.045, 0.98 }, { 0.82, 0.60, 0.18, 1.00 })

    local title = wm:CreateControl(nil, picker, CT_LABEL)
    title:SetAnchor(TOP, picker, TOP, 0, 14)
    title:SetDimensions(360, 28)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetFont("ZoFontWinH2")
    title:SetColor(unpack(COLORS.gold))
    title:SetText("SELECT AUGUR TILE")
    picker.title = title

    local detail = wm:CreateControl(nil, picker, CT_LABEL)
    detail:SetAnchor(TOP, picker, TOP, 0, 46)
    detail:SetDimensions(350, 46)
    detail:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    detail:SetFont("ZoFontGameSmall")
    detail:SetColor(unpack(COLORS.text))
    detail:SetText("ESO did not expose the tile coordinate. Click the same grid square you just used Augur on.")
    picker.detail = detail

    local startX, startY = 60, 108
    local cell, gap = 26, 3
    picker.cells = {}

    for column = 1, 10 do
        local label = wm:CreateControl(nil, picker, CT_LABEL)
        label:SetDimensions(cell, 18)
        label:SetAnchor(TOPLEFT, picker, TOPLEFT, startX + ((column - 1) * (cell + gap)), startY - 22)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetFont("ZoFontGameSmall")
        label:SetColor(unpack(COLORS.muted))
        label:SetText(tostring(column))
    end

    for row = 1, 10 do
        local rowLabel = wm:CreateControl(nil, picker, CT_LABEL)
        rowLabel:SetDimensions(22, cell)
        rowLabel:SetAnchor(TOPLEFT, picker, TOPLEFT, startX - 28, startY + ((row - 1) * (cell + gap)))
        rowLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        rowLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        rowLabel:SetFont("ZoFontGameSmall")
        rowLabel:SetColor(unpack(COLORS.muted))
        rowLabel:SetText(tostring(row))

        for column = 1, 10 do
            local bg = wm:CreateControl(nil, picker, CT_BACKDROP)
            bg:SetDimensions(cell, cell)
            bg:SetAnchor(TOPLEFT, picker, TOPLEFT, startX + ((column - 1) * (cell + gap)), startY + ((row - 1) * (cell + gap)))
            setBackdrop(bg, { 0.10, 0.11, 0.14, 0.98 }, { 0.40, 0.42, 0.48, 0.90 })

            local button = wm:CreateControl(nil, bg, CT_BUTTON)
            button:SetAnchorFill(bg)
            button:SetFont("ZoFontGameSmall")
            button:SetNormalFontColor(0.88, 0.88, 0.90, 1)
            button:SetMouseOverFontColor(1.00, 0.82, 0.28, 1)
            button:SetText("")

            -- Lua 5.1 closes over numeric-for variables by reference. Keep a
            -- per-cell copy so every button reports its own row/column instead
            -- of all callbacks ending up on the final grid cell.
            local cellRow, cellColumn, cellBg = row, column, bg
            button:SetHandler("OnMouseEnter", function()
                picker.detail:SetText(string.format("ROW %d, COLUMN %d — click if this is the tile you just Augured.", cellRow, cellColumn))
                cellBg:SetCenterColor(0.24, 0.20, 0.08, 0.98)
                cellBg:SetEdgeColor(1.00, 0.78, 0.24, 1.00)
            end)
            button:SetHandler("OnMouseExit", function()
                picker.detail:SetText("Select the scanned tile once. The Suite saves this tile + color so the next scans only need the new color.")
                cellBg:SetCenterColor(0.10, 0.11, 0.14, 0.98)
                cellBg:SetEdgeColor(0.40, 0.42, 0.48, 0.90)
            end)
            button:SetHandler("OnClicked", function()
                local color = A.pendingManualColor
                A.pendingManualColor = nil
                picker:SetHidden(true)
                -- Once the player manually identifies one scan tile, keep that
                -- tile+color as the route anchor. Every recommended tile after
                -- this can be inferred from the previous recommendation, so
                -- the player only needs to press the new color each scan.
                A.followSavedPath = true
                A.pendingProbe = { row = cellRow, column = cellColumn }
                if color then A:RecordAugurColor(color) end
            end)
            picker.cells[#picker.cells + 1] = { row = cellRow, column = cellColumn, button = button, background = cellBg }
        end
    end

    local cancelBg = wm:CreateControl(nil, picker, CT_BACKDROP)
    cancelBg:SetDimensions(120, 30)
    cancelBg:SetAnchor(BOTTOM, picker, BOTTOM, 0, -14)
    setBackdrop(cancelBg, { 0.13, 0.14, 0.17, 0.98 }, { 0.48, 0.50, 0.55, 0.90 })
    local cancel = wm:CreateControl(nil, cancelBg, CT_BUTTON)
    cancel:SetAnchorFill(cancelBg)
    cancel:SetFont("ZoFontGameBold")
    cancel:SetNormalFontColor(0.92, 0.92, 0.92, 1)
    cancel:SetMouseOverFontColor(1.00, 0.82, 0.28, 1)
    cancel:SetText("CANCEL")
    cancel:SetHandler("OnClicked", function()
        A.pendingManualColor = nil
        picker:SetHidden(true)
    end)

    picker.layoutDragShield = self:CreateLayoutDragShield(picker, "PICKER")
    self.tilePicker = picker
end

function A:ShowTilePicker(color)
    self:CreateTilePicker()
    if not self.tilePicker then return end
    self.pendingManualColor = tostring(color or "")
    self.tilePicker.title:SetText("SELECT AUGUR TILE — " .. self.pendingManualColor)
    self.tilePicker.detail:SetText("Select the tile you just scanned once. The Suite will save this tile + color, then future scans only need the new color.")
    self.tilePicker:SetHidden(false)
end

function A:SetGuideMessage(title, instruction, detail, rotation)
    if not self.guide then return end
    self.guide.title:SetText(tostring(title or "EXCAVATION GUIDE"))
    self.guide.instruction:SetText(tostring(instruction or ""))
    self.guide.detail:SetText(tostring(detail or ""))
    if type(self.guide.arrow.SetTextureRotation) == "function" then self.guide.arrow:SetTextureRotation(tonumber(rotation) or 0, 0.5, 0.5) end
end


function A:SetAugurButtonsVisible(visible)
    if not self.guide or type(self.guide.buttons) ~= "table" then return end
    visible = visible == true
    for _, entry in ipairs(self.guide.buttons) do
        if entry.background then entry.background:SetHidden(not visible) end
        if entry.button then entry.button:SetHidden(not visible) end
    end
end

local function cellKey(row, column)
    return tostring(math.floor(tonumber(row) or 0)) .. ":" .. tostring(math.floor(tonumber(column) or 0))
end

function A:GetBonusDigStatusText()
    local stability, stabilityMax = safe(GetDigSpotStability, 0)
    local timeLeft = tonumber(safe(GetDigSpotStabilityTimeRemainingSeconds, 0)) or 0
    local power, powerMax = safe(GetDigSpotDigPower, 0)
    stability, stabilityMax = tonumber(stability) or 0, tonumber(stabilityMax) or 0
    power, powerMax = tonumber(power) or 0, tonumber(powerMax) or 0
    return string.format("Bonus found: %d  •  Stability: %d/%d  •  Time: %ds  •  Dig Power: %d/%d",
        tonumber(self.bonusFound) or 0, stability, stabilityMax, math.max(0, math.floor(timeLeft)), power, powerMax)
end

function A:ResetBonusSearch(keepFound)
    local found = keepFound == true and (tonumber(self.bonusFound) or 0) or 0
    self.bonusMode = true
    self.mainUnearthed = true
    self.bonusFound = found
    self.bonusAttempts = {}
    self.bonusExhausted = {}
    self.bonusVisited = {}
    self.bonusFoundCells = {}
    self.bonusCurrentTarget = nil
    self.bonusLastAction = nil
    self.bonusBannerUntil = 0
    self.pendingProbe = nil
    self.expectedProbe = nil
    self.pendingManualColor = nil
    if self.nativeEditHudPreview029780 ~= true and self.tilePicker then self.tilePicker:SetHidden(true) end

    -- Preserve the confirmed Green scan as a strong indication of the area
    -- already consumed by the primary Antiquity. This is only a coverage
    -- heuristic; it does not claim bonus loot cannot be nearby.
    self.bonusMainCells = {}
    for _, scan in ipairs(self.scanHistory or {}) do
        if tostring(scan.color or "") == "GREEN" then
            self.bonusMainCells[cellKey(scan.row, scan.column)] = true
        end
    end
    if self.lastProbe then self.bonusMainCells[cellKey(self.lastProbe.row, self.lastProbe.column)] = true end
end

function A:GetBonusSearchAnchor()
    local row, column = self:GetSelectedDigCellSafe()
    if row and column then return { row = row, column = column } end
    if type(self.bonusLastAction) == "table" then return { row = self.bonusLastAction.row, column = self.bonusLastAction.column } end
    if type(self.lastProbe) == "table" then return { row = self.lastProbe.row, column = self.lastProbe.column } end
    return { row = math.ceil((self.gridRows or 10) * 0.5), column = math.ceil((self.gridColumns or 10) * 0.5) }
end

function A:ChooseBonusSearchTile()
    local rows, columns = tonumber(self.gridRows) or 10, tonumber(self.gridColumns) or 10
    local anchor = self:GetBonusSearchAnchor()
    local best, bestScore = nil, nil

    local referenceCells = {}
    for key in pairs(self.bonusVisited or {}) do
        local r, c = key:match("^(%d+):(%d+)$")
        if r and c then referenceCells[#referenceCells + 1] = { row = tonumber(r), column = tonumber(c) } end
    end
    for key in pairs(self.bonusMainCells or {}) do
        local r, c = key:match("^(%d+):(%d+)$")
        if r and c then referenceCells[#referenceCells + 1] = { row = tonumber(r), column = tonumber(c) } end
    end

    for row = 1, rows do
        for column = 1, columns do
            local key = cellKey(row, column)
            if not (self.bonusExhausted and self.bonusExhausted[key]) then
                local attempts = tonumber(self.bonusAttempts and self.bonusAttempts[key]) or 0
                local minSpread = math.max(rows, columns)
                if #referenceCells > 0 then
                    minSpread = 999
                    for _, seen in ipairs(referenceCells) do
                        local d = math.max(math.abs(row - seen.row), math.abs(column - seen.column))
                        if d < minSpread then minSpread = d end
                    end
                end

                -- This is a search-efficiency score, not hidden-data access:
                -- favor untouched cells, spread searches across the board, and
                -- slightly prefer interior cells where area tools can cover more
                -- neighboring dirt. Never present the result as guaranteed.
                local edgeDistance = math.min(row - 1, rows - row, column - 1, columns - column)
                local score = 100 - (attempts * 34) + (minSpread * 11) + (math.min(edgeDistance, 2) * 4)
                if self.bonusMainCells and self.bonusMainCells[key] then score = score - 28 end
                if anchor then
                    local travel = math.abs(row - anchor.row) + math.abs(column - anchor.column)
                    score = score - math.min(travel, 12) * 0.35
                end
                if (row + column) % 2 == 0 then score = score + 1.5 end

                if bestScore == nil or score > bestScore then
                    bestScore = score
                    best = { row = row, column = column, score = score }
                end
            end
        end
    end
    return best
end

function A:FormatRelativeMove(fromCell, toCell)
    if not fromCell or not toCell then return "GO TO THE MARKED TILE", 0 end
    local dx = (tonumber(toCell.column) or 0) - (tonumber(fromCell.column) or 0)
    local dy = (tonumber(toCell.row) or 0) - (tonumber(fromCell.row) or 0)
    local moves = {}
    if math.abs(dx) > 0 then moves[#moves + 1] = tostring(math.abs(dx)) .. " " .. (dx > 0 and "RIGHT" or "LEFT") end
    if math.abs(dy) > 0 then moves[#moves + 1] = tostring(math.abs(dy)) .. " " .. (dy > 0 and "DOWN" or "UP") end
    return (#moves > 0 and table.concat(moves, " + ") or "THIS TILE"), rotationForDelta(dx, dy)
end

function A:ShowNextBonusPrediction(prefix)
    if self.bonusMode ~= true then return end
    self:SetAugurButtonsVisible(false)
    local target = self:ChooseBonusSearchTile()
    self.bonusCurrentTarget = target
    if not target then
        self:SetGuideMessage("BONUS LOOT SEARCH", "No unexhausted search tile remains in the Suite route.", self:GetBonusDigStatusText(), 0)
        return
    end
    local anchor = self:GetBonusSearchAnchor()
    local moveText, rotation = self:FormatRelativeMove(anchor, target)
    local instruction = string.format("BEST SEARCH: %s — work ROW %d, COLUMN %d toward bottom.", moveText, target.row, target.column)
    local detail = self:GetBonusDigStatusText() .. "  •  Coverage prediction — not guaranteed."
    if prefix and prefix ~= "" then detail = tostring(prefix) .. "  •  " .. detail end
    self:SetGuideMessage("BONUS LOOT SEARCH", instruction, detail, rotation)
end

function A:OnMainAntiquityUnearthed()
    self.mainUnearthed = true
    if not EPC.saved or EPC.saved.antiquityAssistantEnabled == false or EPC.saved.antiquityBonusLootGuide == false then return end
    self:ResetBonusSearch(false)
    self:ShowNextBonusPrediction("MAIN ANTIQUITY FOUND")
end

function A:OnBonusLootUnearthed()
    if self.mainUnearthed ~= true then self.mainUnearthed = true end
    if self.bonusMode ~= true then self:ResetBonusSearch(true) end
    self.bonusFound = (tonumber(self.bonusFound) or 0) + 1
    local row, column = self:GetSelectedDigCellSafe()
    local foundCell = row and column and { row = row, column = column } or self.bonusLastAction or self.bonusCurrentTarget
    if foundCell then
        local key = cellKey(foundCell.row, foundCell.column)
        self.bonusFoundCells[key] = true
        self.bonusVisited[key] = true
        self.bonusExhausted[key] = true
    end
    self.bonusCurrentTarget = nil
    self.bonusBannerUntil = nowMs() + 1800
    self:ShowNextBonusPrediction(string.format("BONUS FOUND #%d", self.bonusFound))
end

function A:OnBonusDiggingAction(result, selectedSkill)
    if self.bonusMode ~= true then return false end
    local row, column = self:GetSelectedDigCellSafe()
    if row and column then
        local key = cellKey(row, column)
        self.bonusVisited[key] = true
        self.bonusAttempts[key] = (tonumber(self.bonusAttempts[key]) or 0) + 1
        self.bonusLastAction = { row = row, column = column, skill = selectedSkill }
    end

    if DIGGING_ACTIVE_SKILL_USE_RESULT_AT_BOTTOM ~= nil and result == DIGGING_ACTIVE_SKILL_USE_RESULT_AT_BOTTOM then
        if row and column then self.bonusExhausted[cellKey(row, column)] = true end
        self.bonusCurrentTarget = nil
        self:ShowNextBonusPrediction("That tile is at bottom; moving to the next coverage target.")
        return true
    end

    if DIGGING_ACTIVE_SKILL_USE_RESULT_CANNOT_RADAR_BONUS_LOOT ~= nil and result == DIGGING_ACTIVE_SKILL_USE_RESULT_CANNOT_RADAR_BONUS_LOOT then
        self:SetAugurButtonsVisible(false)
        self:SetGuideMessage("BONUS LOOT — AUGUR CANNOT LOCATE IT", "Use the Suite coverage route instead of spending Augur charges.", self:GetBonusDigStatusText() .. "  •  Bonus positions are hidden from addons/Augur.", 0)
        return true
    end

    if result == DIGGING_ACTIVE_SKILL_USE_RESULT_SUCCESS then
        local target = self.bonusCurrentTarget
        if target and row and column and row == target.row and column == target.column then
            local detail = self:GetBonusDigStatusText() .. "  •  Continue this tile/area until loot appears or the tile reaches bottom."
            self:SetGuideMessage("BONUS SEARCH — KEEP WORKING THIS AREA", string.format("ROW %d, COLUMN %d is the current best coverage target.", row, column), detail, 0)
        else
            self:ShowNextBonusPrediction("Search action recorded")
        end
        return true
    end
    return false
end

function A:ResetExcavationSolver()
    self.gridRows, self.gridColumns = 10, 10
    if type(GetDigSpotDimensions) == "function" then
        local rows, columns = safe(GetDigSpotDimensions, nil)
        self.gridRows = clamp(math.floor(tonumber(rows) or 10), 1, 30)
        self.gridColumns = clamp(math.floor(tonumber(columns) or 10), 1, 30)
    elseif type(ANTIQUITY_DIGGING) == "table" then
        self.gridRows = clamp(math.floor(tonumber(ANTIQUITY_DIGGING.numRows) or 10), 1, 30)
        self.gridColumns = clamp(math.floor(tonumber(ANTIQUITY_DIGGING.numColumns) or 10), 1, 30)
    end
    self.candidates = {}
    self.probed = {}
    for row = 1, self.gridRows do
        for column = 1, self.gridColumns do self.candidates[#self.candidates + 1] = { row = row, column = column } end
    end
    self.pendingProbe = nil
    self.lastProbe = nil
    self.lastRecommendation = nil
    self.expectedProbe = nil
    self.lastSavedScan = nil
    self.followSavedPath = false
    self.lastLiveDigCell = nil
    self.pendingManualColor = nil
    self.mainUnearthed = false
    self.bonusMode = false
    self.bonusFound = 0
    self.bonusAttempts = {}
    self.bonusExhausted = {}
    self.bonusVisited = {}
    self.bonusFoundCells = {}
    self.bonusCurrentTarget = nil
    self.bonusLastAction = nil
    if self.nativeEditHudPreview029780 ~= true and self.tilePicker then self.tilePicker:SetHidden(true) end
    self:SetAugurButtonsVisible(true)
end

local function readObjectMember(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return nil
end

function A:ExtractDigCellFromObject(object)
    if object == nil then return nil end

    -- Common tile/data accessors used by ESO keyboard UI objects.
    local pairsOfMethods = {
        { "GetGridCoordinates" }, { "GetGridPosition" }, { "GetRowColumn" },
    }
    for _, entry in ipairs(pairsOfMethods) do
        local method = readObjectMember(object, entry[1])
        if type(method) == "function" then
            local row, column = safe(method, nil, object)
            row, column = validDigCell(row, column)
            if row and column then return row, column end
        end
    end

    local getRow, getColumn = readObjectMember(object, "GetRow"), readObjectMember(object, "GetColumn")
    if type(getRow) == "function" and type(getColumn) == "function" then
        local row, column = safe(getRow, nil, object), safe(getColumn, nil, object)
        row, column = validDigCell(row, column)
        if row and column then return row, column end
    end

    local fieldPairs = {
        { "row", "column" }, { "gridRow", "gridColumn" },
        { "rowIndex", "columnIndex" },
    }
    for _, keys in ipairs(fieldPairs) do
        local row, column = readObjectMember(object, keys[1]), readObjectMember(object, keys[2])
        row, column = validDigCell(row, column)
        if row and column then return row, column end
    end

    local data = readObjectMember(object, "data") or readObjectMember(object, "tileData")
    if data and data ~= object then
        local row, column = self:ExtractDigCellFromObject(data)
        if row and column then return row, column end
    end
    return nil
end

function A:GetDigCellFromESOUI()
    -- Keyboard UI-object fallbacks identify the tile the player actually clicked;
    -- they do NOT reveal the hidden relic.
    local controllers = {
        _G.ANTIQUITY_DIGGING_KEYBOARD,
        _G.ANTIQUITY_DIGGING,
    }
    local methods = { "GetMouseOverTile", "GetSelectedTile", "GetMouseOverDigTile", "GetSelectedDigTile" }
    for _, controller in ipairs(controllers) do
        if controller then
            for _, methodName in ipairs(methods) do
                local method = readObjectMember(controller, methodName)
                if type(method) == "function" then
                    local first, second = safe(method, nil, controller)
                    local row, column = validDigCell(first, second)
                    if row and column then return row, column, "ui:" .. methodName end
                    row, column = self:ExtractDigCellFromObject(first)
                    if row and column then return row, column, "ui:" .. methodName end
                end
            end
            local row, column = self:ExtractDigCellFromObject(controller)
            if row and column then return row, column, "ui:digging" end
        end
    end
    return nil
end

function A:RememberDigCell(row, column, source)
    row, column = validDigCell(row, column)
    if not row or not column then return nil end
    self.lastLiveDigCell = { row = row, column = column, source = source or "unknown", stamp = nowMs() }
    return row, column
end

function A:TrackSelectedDigCell()
    if type(IsDiggingGameActive) == "function" and safe(IsDiggingGameActive, false) ~= true then return end

    -- Cache the real board cell continuously before the mouse moves from the
    -- board to the Suite color buttons. Try the public cell helpers first,
    -- then ESO's live keyboard UI objects as a compatibility fallback.
    if type(GetSelectedDigCell) == "function" then
        local row, column = safe(GetSelectedDigCell, nil)
        row, column = validDigCell(row, column)
        if row and column then self:RememberDigCell(row, column, "selected") return end
    end
    if type(GetMouseOverDigCell) == "function" then
        local row, column = safe(GetMouseOverDigCell, nil)
        row, column = validDigCell(row, column)
        if row and column then self:RememberDigCell(row, column, "mouseover") return end
    end
    local row, column, source = self:GetDigCellFromESOUI()
    if row and column then self:RememberDigCell(row, column, source) return end
    if type(ANTIQUITY_DIGGING) == "table" then
        row, column = validDigCell(ANTIQUITY_DIGGING.selectedRow, ANTIQUITY_DIGGING.selectedColumn)
        if row and column then self:RememberDigCell(row, column, "ui") return end
    end
end

function A:GetSelectedDigCellSafe()
    if type(GetSelectedDigCell) == "function" then
        local row, column = safe(GetSelectedDigCell, nil)
        row, column = validDigCell(row, column)
        if row and column then return self:RememberDigCell(row, column, "selected") end
    end
    if type(GetMouseOverDigCell) == "function" then
        local row, column = safe(GetMouseOverDigCell, nil)
        row, column = validDigCell(row, column)
        if row and column then return self:RememberDigCell(row, column, "mouseover") end
    end
    local row, column, source = self:GetDigCellFromESOUI()
    if row and column then return self:RememberDigCell(row, column, source) end
    if type(ANTIQUITY_DIGGING) == "table" then
        row, column = validDigCell(ANTIQUITY_DIGGING.selectedRow, ANTIQUITY_DIGGING.selectedColumn)
        if row and column then return self:RememberDigCell(row, column, "ui") end
    end
    if type(self.lastLiveDigCell) == "table" then
        row, column = validDigCell(self.lastLiveDigCell.row, self.lastLiveDigCell.column)
        if row and column then return row, column end
    end
    return nil
end

function A:ColorForDistance(distance)
    if distance <= 0 then return "GREEN" end
    if distance <= 2 then return "YELLOW" end
    if distance <= 4 then return "ORANGE" end
    return "RED"
end

function A:FilterCandidates(row, column, color)
    local filtered = {}
    for _, candidate in ipairs(self.candidates or {}) do
        local distance = math.max(math.abs(candidate.row - row), math.abs(candidate.column - column))
        if self:ColorForDistance(distance) == color then filtered[#filtered + 1] = candidate end
    end
    return filtered
end

function A:ChooseNextProbe()
    local candidates = self.candidates or {}
    if #candidates == 0 then return nil end
    if #candidates == 1 then return { row = candidates[1].row, column = candidates[1].column, certain = true } end

    -- Never recommend an already-eliminated square. Every suggested Augur tile
    -- is still a possible green square in the point-distance model, so the
    -- player always has a chance to hit Green while gathering information.
    local centerRow, centerColumn = 0, 0
    for _, candidate in ipairs(candidates) do
        centerRow = centerRow + candidate.row
        centerColumn = centerColumn + candidate.column
    end
    centerRow, centerColumn = centerRow / #candidates, centerColumn / #candidates

    local best, bestWorst, bestExpected, bestCenter = nil, nil, nil, nil
    for _, probe in ipairs(candidates) do
        local key = tostring(probe.row) .. ":" .. tostring(probe.column)
        if not self.probed[key] then
            local buckets = { GREEN = 0, YELLOW = 0, ORANGE = 0, RED = 0 }
            for _, candidate in ipairs(candidates) do
                local distance = math.max(math.abs(candidate.row - probe.row), math.abs(candidate.column - probe.column))
                local resultColor = self:ColorForDistance(distance)
                buckets[resultColor] = buckets[resultColor] + 1
            end
            local worst = math.max(buckets.YELLOW, buckets.ORANGE, buckets.RED)
            local expected = ((buckets.GREEN * buckets.GREEN) + (buckets.YELLOW * buckets.YELLOW) + (buckets.ORANGE * buckets.ORANGE) + (buckets.RED * buckets.RED)) / #candidates
            local centerDistance = math.abs(probe.row - centerRow) + math.abs(probe.column - centerColumn)
            if not best or worst < bestWorst or (worst == bestWorst and expected < bestExpected) or (worst == bestWorst and expected == bestExpected and centerDistance < bestCenter) then
                best = { row = probe.row, column = probe.column, worst = worst, expected = expected }
                bestWorst, bestExpected, bestCenter = worst, expected, centerDistance
            end
        end
    end
    return best or { row = candidates[1].row, column = candidates[1].column }
end

function A:GetCandidateSummary()
    local count = #(self.candidates or {})
    if count <= 0 then return "No model cells remain." end
    if count == 1 then return "1 model cell remains." end
    return string.format("%d model cells remain.", count)
end

function A:RecordAugurColor(color)
    color = string.upper(tostring(color or ""))

    if not self.pendingProbe then
        local row, column = self:GetSelectedDigCellSafe()
        if row and column then
            self.pendingProbe = { row = row, column = column }
        elseif self.followSavedPath == true and type(self.expectedProbe) == "table" then
            -- ESO sometimes stops exposing the hovered tile as soon as the
            -- mouse leaves the board. If the player is following the Suite's
            -- saved route, the next scan tile is already known exactly from
            -- the prior recommendation. Reuse it instead of opening the 10x10
            -- picker again.
            self.pendingProbe = { row = self.expectedProbe.row, column = self.expectedProbe.column }
        end
    end

    local probe = self.pendingProbe
    if not probe then
        if color == "GREEN" then
            self:SetGuideMessage("DIG THE GREEN TILE", "Green is exact: excavate the same tile you just Augured.", "No coordinate is needed when ESO itself showed Green.", 0)
            self.pendingManualColor = nil
            if self.nativeEditHudPreview029780 ~= true and self.tilePicker then self.tilePicker:SetHidden(true) end
            return
        end
        self:SetGuideMessage("SELECT THIS SCAN TILE ONCE", "ESO did not expose the clicked tile coordinate.", "Pick the tile you just scanned. It will be saved with " .. color .. "; after this, follow the move instruction and press only the next color.", 0)
        self:ShowTilePicker(color)
        return
    end

    -- A valid tile+color pair is now authoritative for the route. Save it and
    -- enable follow mode so subsequent missing API coordinates can use the
    -- Suite's previously recommended tile without another manual selection.
    self.followSavedPath = true
    self.lastSavedScan = { row = probe.row, column = probe.column, color = color }
    self.expectedProbe = nil
    self.scanHistory = self.scanHistory or {}
    self.scanHistory[#self.scanHistory + 1] = { row = probe.row, column = probe.column, color = color }

    local filtered = self:FilterCandidates(probe.row, probe.column, color)
    if #filtered == 0 then
        -- The real Antiquity can occupy multiple cells, while this lightweight
        -- model tracks possible Green cells. If observations conflict, rebuild
        -- the candidate set rather than claiming an exact location.
        self.candidates = {}
        for row = 1, self.gridRows do
            for column = 1, self.gridColumns do
                local key = tostring(row) .. ":" .. tostring(column)
                if not self.probed[key] then self.candidates[#self.candidates + 1] = { row = row, column = column } end
            end
        end
        filtered = self:FilterCandidates(probe.row, probe.column, color)
        if #filtered > 0 then self.candidates = filtered end
    else
        self.candidates = filtered
    end

    self.probed[tostring(probe.row) .. ":" .. tostring(probe.column)] = true
    self.lastProbe = { row = probe.row, column = probe.column }
    self.pendingProbe = nil

    if color == "GREEN" then
        self.lastRecommendation = { row = probe.row, column = probe.column }
        self.expectedProbe = nil
        self:SetGuideMessage("GUARANTEED GREEN — DIG HERE", string.format("ROW %d, COLUMN %d is confirmed Green.", probe.row, probe.column), "Stop scanning. Switch to Hand Brush and excavate this exact green tile.", 0)
        return
    end

    local nextProbe = self:ChooseNextProbe()
    if not nextProbe then
        self.expectedProbe = nil
        self:SetGuideMessage("USE YOUR CLOSEST RESULT", "The helper could not produce another safe recommendation.", "Only dig when ESO actually shows Green.", 0)
        return
    end

    self.lastRecommendation = { row = nextProbe.row, column = nextProbe.column }
    self.expectedProbe = { row = nextProbe.row, column = nextProbe.column }
    local dx, dy = nextProbe.column - probe.column, nextProbe.row - probe.row
    local moves = {}
    if math.abs(dx) > 0 then moves[#moves + 1] = tostring(math.abs(dx)) .. " " .. string.upper(dx > 0 and "RIGHT" or "LEFT") end
    if math.abs(dy) > 0 then moves[#moves + 1] = tostring(math.abs(dy)) .. " " .. string.upper(dy > 0 and "DOWN" or "UP") end
    local moveText = #moves > 0 and table.concat(moves, " + ") or "THIS TILE"

    self:SetGuideMessage(
        "NEXT AUGUR — " .. moveText,
        string.format("From the saved %s tile, move %s. Use Augur there, then press ONLY the new color.", color, moveText),
        string.format("Saved %s @ R%d C%d  •  Next R%d C%d  •  %s", color, probe.row, probe.column, nextProbe.row, nextProbe.column, self:GetCandidateSummary()),
        rotationForDelta(dx, dy)
    )
end

function A:OnDiggingReady()
    self:CreateExcavationGuide()
    self:ResetExcavationSolver()
    self.scanHistory = {}
    self.mainUnearthed = false
    self.bonusMode = false
    self.bonusFound = 0
    self:SetAugurButtonsVisible(true)
    local enabled = EPC.saved and EPC.saved.antiquityExcavationGuide ~= false and EPC.saved.antiquityAssistantEnabled ~= false
    if self.nativeEditHudPreview029780 == true then
        self.guide:SetHidden(false)
    else
        self.guide:SetHidden(not enabled)
    end
    if enabled then
        local first = self:ChooseNextProbe()
        if first then
            self.lastRecommendation = first
            self:SetGuideMessage("FIRST AUGUR — START HERE", string.format("Scan ROW %d, COLUMN %d, then press the color ESO shows.", first.row, first.column), "Once one tile+color is captured/saved, future instructions become simple moves such as 3 LEFT + 4 DOWN.", 0)
        else
            self:SetGuideMessage("USE AUGUR", "Scan a tile, then press the matching ESO color below.", "GREEN = dig that exact tile. Other colors are used only to choose the next scan.", 0)
        end
    end
end

function A:OnDiggingSkillResult(result)
    if not self.guide or self.guide:IsHidden() then return end
    local selectedSkill = safe(GetSelectedDiggingActiveSkill, nil)
    if self.bonusMode == true then
        if self:OnBonusDiggingAction(result, selectedSkill) then return end
    end
    if selectedSkill ~= DIGGING_ACTIVE_SKILL_RADAR_SENSE then return end
    if result == DIGGING_ACTIVE_SKILL_USE_RESULT_SUCCESS then
        self:TrackSelectedDigCell()
        local row, column = self:GetSelectedDigCellSafe()

        -- If ESO only returned the previous/stale board cell but the player is
        -- following a saved Suite recommendation, prefer the expected next
        -- tile. If ESO exposes a different fresh tile, trust ESO instead.
        if self.followSavedPath == true and type(self.expectedProbe) == "table" then
            local expectedRow, expectedColumn = self.expectedProbe.row, self.expectedProbe.column
            local stalePrevious = row and column and self.lastProbe
                and row == self.lastProbe.row and column == self.lastProbe.column
                and (row ~= expectedRow or column ~= expectedColumn)
            if (not row or not column) or stalePrevious then
                row, column = expectedRow, expectedColumn
            end
        end

        if row and column then
            self.pendingProbe = { row = row, column = column }
            if self.followSavedPath == true and self.expectedProbe
                and row == self.expectedProbe.row and column == self.expectedProbe.column then
                self:SetGuideMessage("PRESS ONLY THE NEW COLOR", string.format("Saved route confirms this scan as ROW %d, COLUMN %d.", row, column), "No tile picker needed. Choose Green / Yellow / Orange / Red from the Augur result.", 0)
            else
                self:SetGuideMessage("WHAT COLOR DID AUGUR SHOW?", string.format("Captured ROW %d, COLUMN %d — choose the Augur color below.", row, column), "This tile will be saved together with the color you press.", 0)
            end
        else
            self.pendingProbe = nil
            self:SetGuideMessage("WHAT COLOR DID AUGUR SHOW?", "Choose the result below after the Augur flash.", "If this is the first uncaptured scan, select its tile once; future recommended scans will be remembered automatically.", 0)
        end
    elseif result == DIGGING_ACTIVE_SKILL_USE_RESULT_RADAR_TOO_DEEP then
        self:SetGuideMessage("AUGUR CANNOT REACH", "Brush this selected tile down one layer, then use Augur again.", "The soil is currently too deep for a reliable reading.", 0)
    elseif result == DIGGING_ACTIVE_SKILL_USE_RESULT_NO_MORE_RADARS then
        self:SetGuideMessage("NO AUGUR USES LEFT", "Dig at the last recommended cell or nearest yellow result.", "Use Hand Brush first, then Heavy Shovel on even layers.", 0)
    elseif DIGGING_ACTIVE_SKILL_USE_RESULT_CANNOT_RADAR_BONUS_LOOT ~= nil and result == DIGGING_ACTIVE_SKILL_USE_RESULT_CANNOT_RADAR_BONUS_LOOT then
        if self.mainUnearthed == true then
            self:OnMainAntiquityUnearthed()
        else
            self:SetGuideMessage("AUGUR CANNOT SCAN BONUS LOOT", "Finish locating the main Antiquity first.", "After the main item is unearthed, the Suite can switch to its bonus-loot coverage route.", 0)
        end
    end
end

function A:BuildSkillLineView(lineId, kind)
    local points = tonumber(safe(GetAvailableSkillPoints, 0)) or 0
    if not lineId or lineId == 0 or type(GetSkillLineIndicesFromSkillLineId) ~= "function" then
        return "Skill line unavailable. Unlock Antiquities to begin."
    end
    local skillType, skillLineIndex = safe(GetSkillLineIndicesFromSkillLineId, nil, lineId)
    if skillType == nil or skillLineIndex == nil then return "Skill line not discovered yet. Unlock Antiquities to begin." end
    local lineRank, _, _, discovered = safe(GetSkillLineDynamicInfo, nil, skillType, skillLineIndex)
    lineRank = tonumber(lineRank) or 0
    if discovered == false then return "Skill line not discovered yet. Unlock Antiquities to begin." end
    local multiplier = math.max(1, tonumber(safe(GetSkillLinePointCostMultiplier, 1, skillType, skillLineIndex)) or 1)

    local fixedPriority = {}
    if kind == "SCRYING" and type(GetScryingPassiveSkillIndex) == "function" then
        local constants = {
            SCRYING_PASSIVE_SKILL_ANTIQUARIAN_INSIGHT,
            SCRYING_PASSIVE_SKILL_AUGURIST_PATIENCE,
            SCRYING_PASSIVE_SKILL_FUTURE_FOCUS,
            SCRYING_PASSIVE_SKILL_PREEMPTIVE_POWER,
        }
        for order, value in ipairs(constants) do
            if value ~= nil then
                local index = tonumber(safe(GetScryingPassiveSkillIndex, nil, value))
                if index then fixedPriority[index] = order end
            end
        end
    elseif kind == "EXCAVATION" and type(GetDiggingActiveSkillIndices) == "function" then
        local constants = {
            DIGGING_ACTIVE_SKILL_RADAR_SENSE,
            DIGGING_ACTIVE_SKILL_BASIC_EXCAVATION,
            DIGGING_ACTIVE_SKILL_CAREFUL_TOUCH,
            DIGGING_ACTIVE_SKILL_HEAVY_SHOVEL,
        }
        for order, value in ipairs(constants) do
            if value ~= nil then
                local _, lineIndex, skillIndex = safe(GetDiggingActiveSkillIndices, nil, value)
                if tonumber(lineIndex) == tonumber(skillLineIndex) and skillIndex then fixedPriority[tonumber(skillIndex)] = order end
            end
        end
    end

    local namePriority = kind == "SCRYING" and {
        { "antiquarian insight", 1 }, { "patience", 2 }, { "future focus", 3 },
        { "preemptive", 4 }, { "coalescence", 5 }, { "farsight", 6 }, { "dilation", 7 },
    } or {
        { "augur", 1 }, { "hand brush", 2 }, { "reserves", 3 }, { "heavy shovel", 4 },
        { "trowel", 5 }, { "keen eye: dig", 6 }, { "keen eye: treasure", 8 },
    }
    local recommendations = {}
    local abilityCount = tonumber(safe(GetNumSkillAbilities, 0, skillType, skillLineIndex)) or 0
    for skillIndex = 1, abilityCount do
        local name, _, _, _, _, purchased = safe(GetSkillAbilityInfo, nil, skillType, skillLineIndex, skillIndex)
        name = tostring(name or ("Skill " .. tostring(skillIndex)))
        local isAuto = safe(IsSkillAbilityAutoGrant, false, skillType, skillLineIndex, skillIndex) == true
        local currentRank, maxRank = safe(GetSkillAbilityUpgradeInfo, nil, skillType, skillLineIndex, skillIndex)
        currentRank, maxRank = tonumber(currentRank), tonumber(maxRank)
        local passiveRanks = tonumber(safe(GetNumPassiveSkillRanks, 0, skillType, skillLineIndex, skillIndex)) or 0
        maxRank = math.max(maxRank or 0, passiveRanks, 1)
        currentRank = purchased == true and math.max(currentRank or 1, 1) or 0
        if not isAuto and currentRank < maxRank then
            local nextRank = currentRank + 1
            local morphBase = MORPH_SLOT_BASE or 0
            local _, rankNeeded, levelNeeded = safe(GetSpecificSkillAbilityInfo, nil, skillType, skillLineIndex, skillIndex, morphBase, nextRank)
            rankNeeded = tonumber(rankNeeded) or tonumber(safe(GetSkillAbilityLineRankNeededToUnlock, 1, skillType, skillLineIndex, skillIndex)) or 1
            levelNeeded = tonumber(levelNeeded) or tonumber(safe(GetSkillAbilityCharacterLevelNeededToUnlock, 1, skillType, skillLineIndex, skillIndex)) or 1
            local priority = fixedPriority[skillIndex]
            if not priority then
                local lowerName = string.lower(name)
                priority = 50 + skillIndex
                for _, rule in ipairs(namePriority) do
                    if string.find(lowerName, rule[1], 1, true) then priority = rule[2] break end
                end
            end
            local state
            if lineRank < rankNeeded then state = string.format("UNLOCKS AT LINE %d", rankNeeded)
            elseif points >= multiplier then state = string.format("BUY NOW • %d POINT%s", multiplier, multiplier == 1 and "" or "S")
            else state = string.format("SAVE %d POINT%s", multiplier, multiplier == 1 and "" or "S") end
            recommendations[#recommendations + 1] = {
                priority = priority, rankNeeded = rankNeeded, name = name,
                text = string.format("%s %d/%d — %s", name, currentRank, maxRank, state),
                levelNeeded = levelNeeded,
            }
        end
    end
    table.sort(recommendations, function(left, right)
        if left.priority ~= right.priority then return left.priority < right.priority end
        if left.rankNeeded ~= right.rankNeeded then return left.rankNeeded < right.rankNeeded end
        return left.name < right.name
    end)
    local lines = { string.format("Line rank %d • %d unspent skill point%s", lineRank, points, points == 1 and "" or "s"), "", "RECOMMENDED ORDER" }
    if #recommendations == 0 then
        lines[#lines + 1] = "All available upgrades are purchased."
    else
        for index = 1, math.min(#recommendations, 7) do lines[#lines + 1] = string.format("%d. %s", index, recommendations[index].text) end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "The Suite recommends only; it never spends points automatically."
    return table.concat(lines, "\n")
end

function A:BuildOptimizerView()
    if type(AreAntiquitySkillLinesDiscovered) == "function" and safe(AreAntiquitySkillLinesDiscovered, false) ~= true then
        local locked = "Antiquities skill lines are not discovered yet. Complete the Antiquities introduction, then reopen this page."
        return locked, locked
    end
    local scryingId = tonumber(safe(GetAntiquityScryingSkillLineId, 0)) or 0
    local diggingId = tonumber(safe(GetAntiquityDiggingSkillLineId, 0)) or 0
    return self:BuildSkillLineView(scryingId, "SCRYING"), self:BuildSkillLineView(diggingId, "EXCAVATION")
end

function A:RefreshSettings()
    if self.bonusMode == true and (not EPC.saved or EPC.saved.antiquityBonusLootGuide == false) then
        self.bonusMode = false
        self:SetAugurButtonsVisible(true)
    end
    if self.nativeEditHudPreview029780 ~= true then
        if self.guide and (not EPC.saved or EPC.saved.antiquityAssistantEnabled == false or EPC.saved.antiquityExcavationGuide == false) then self.guide:SetHidden(true) end
        if self.tilePicker and (not EPC.saved or EPC.saved.antiquityAssistantEnabled == false or EPC.saved.antiquityExcavationGuide == false) then self.tilePicker:SetHidden(true) end
    end
    if not EPC.saved or EPC.saved.antiquityAssistantEnabled == false or EPC.saved.antiquityShow3D == false then
        self:HideWorldMarkers("disabled")
        if self.exactSpotMarker then self.exactSpotMarker:SetHidden(true) end
    end
    self:InvalidateDigSites()
    self:RefreshWorldMapPins()
    if EPC.MiniMap then EPC.MiniMap.staticPinsDirty = true end
end

function A:RegisterEvents()
    local function register(suffix, eventId, callback)
        if eventId ~= nil then EVENT_MANAGER:RegisterForEvent(UPDATE_NAME .. suffix, eventId, callback) end
    end
    register("_DigReady", EVENT_ANTIQUITY_DIGGING_READY_TO_PLAY, function() self:OnDiggingReady() end)
    register("_DigResult", EVENT_ANTIQUITY_DIGGING_ACTIVE_SKILL_USE_RESULT, function(_, result) self:OnDiggingSkillResult(result) end)
    register("_MainLoot", EVENT_ANTIQUITY_DIGGING_ANTIQUITY_UNEARTHED, function() self:OnMainAntiquityUnearthed() end)
    register("_BonusLoot", EVENT_ANTIQUITY_DIGGING_BONUS_LOOT_UNEARTHED, function() self:OnBonusLootUnearthed() end)
    register("_DigOver", EVENT_ANTIQUITY_DIGGING_GAME_OVER, function()
        if self.nativeEditHudPreview029780 ~= true then
            if self.guide and not self.layoutMode then self.guide:SetHidden(true) end
            if self.tilePicker and not self.layoutMode then self.tilePicker:SetHidden(true) end
        end
        self.pendingManualColor = nil
        self.bonusMode = false
        self.mainUnearthed = false
        for _, delay in ipairs({ 180, 550, 1250 }) do
            zo_callLater(function()
                if EPC.ResourcePins and type(EPC.ResourcePins.RecoverSuite3DWorldPins) == "function" then
                    EPC.ResourcePins:RecoverSuite3DWorldPins("Antiquity excavation ended")
                else
                    self:RecoverWorldRenderer("Antiquity excavation ended")
                end
            end, delay)
        end
    end)
    local function resetWorldSearchState()
        self.learnedExactSpot = nil
        self.learnedExactSiteId = nil
        self.currentKnownSpawnIndex = nil
        self.currentKnownSpawnZoneKey = nil
        self.knownActiveDigAreas = nil
        self.knownActiveDigAreasAt = 0
        self:InvalidateDigSites()
        self:RefreshWorldMapPins()
    end
    register("_Sites", EVENT_ANTIQUITY_DIG_SITES_UPDATED, resetWorldSearchState)
    register("_Tracking", EVENT_ANTIQUITY_TRACKING_UPDATE, resetWorldSearchState)
    register("_TrackingInit", EVENT_ANTIQUITY_TRACKING_INITIALIZED, resetWorldSearchState)
    register("_RevealSites", EVENT_REVEAL_ANTIQUITY_DIG_SITES_ON_MAP, function() resetWorldSearchState() self:UpdateKnownActiveDigAreas() end)
    register("_Activated", EVENT_PLAYER_ACTIVATED, function() self.worldOriginReady = false resetWorldSearchState() self:UpdateKnownActiveDigAreas() end)
    register("_Interact", EVENT_CLIENT_INTERACT_RESULT, function(_, _, interactTargetName)
        if not self:HasActiveAntiquitySearch() then return end
        local combined = normalizedLower(interactTargetName or "")
        local isDigSite = false
        for _, hint in ipairs(EXACT_DIG_INTERACT_HINTS) do
            local normalizedHint = normalizedLower(hint)
            if normalizedHint ~= "" and string.find(combined, normalizedHint, 1, true) then isDigSite = true break end
        end
        if not isDigSite then return end
        local site = self:GetNearestActiveDigSiteToPlayer()
        local estimate = self:EstimateExactMoundPosition()
        if site and estimate then
            local knownCandidates = self:GetKnownSpawnCandidates(true)
            local known = self:FindNearestKnownCandidate(estimate.mapX, estimate.mapY, knownCandidates, KNOWN_SPAWN_CONFIRM_METERS)
            self.learnedExactSpot = self:SaveLearnedDigSpot(site, estimate, known) or estimate
            self.learnedExactSiteId = site.digSiteId
            self.currentKnownSpawnIndex = known and known.knownIndex or nil
            self.currentKnownSpawnZoneKey = known and known.zoneKey or nil
        end
    end)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME .. "_World", 650, function()
        if self.worldRoot and type(self.worldRoot.IsHidden) == "function" and self.worldRoot:IsHidden()
            and self:IsNormalWorldSceneActive()
            and (nowMs() - (tonumber(self.lastWorldRendererRecoveryAt) or 0)) >= 1200 then
            self:RecoverWorldRenderer("Antiquity 3D root stuck hidden")
        else
            self:RefreshWorldMarkers()
        end
        if self.bonusMode == true and self.guide and not self.guide:IsHidden() and nowMs() >= (tonumber(self.bonusBannerUntil) or 0) then
            if self.bonusCurrentTarget then
                local anchor = self:GetBonusSearchAnchor()
                local moveText, rotation = self:FormatRelativeMove(anchor, self.bonusCurrentTarget)
                self:SetGuideMessage("BONUS LOOT SEARCH", string.format("BEST SEARCH: %s — ROW %d, COLUMN %d.", moveText, self.bonusCurrentTarget.row, self.bonusCurrentTarget.column), self:GetBonusDigStatusText() .. "  •  Coverage prediction — not guaranteed.", rotation)
            end
        end
        if self.nativeEditHudPreview029780 ~= true and not self.layoutMode and self.guide and not self.guide:IsHidden() and type(IsDiggingGameActive) == "function" and safe(IsDiggingGameActive, false) ~= true then self.guide:SetHidden(true) end
    end)
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME .. "_DigCell", 150, function()
        if type(IsDiggingGameActive) == "function" and safe(IsDiggingGameActive, false) ~= true then return end
        self:TrackSelectedDigCell()
    end)
end

function A:Initialize()
    self.layoutMode = false
    self.worldMarkers = {}
    self:CreateExcavationGuide()
    self:CreateTilePicker()
    self:CreateExactDigSpotMarker()
    self:EnsureWorldRoot()
    self:RegisterWorldMapPins()
    self:RegisterEvents()
end
