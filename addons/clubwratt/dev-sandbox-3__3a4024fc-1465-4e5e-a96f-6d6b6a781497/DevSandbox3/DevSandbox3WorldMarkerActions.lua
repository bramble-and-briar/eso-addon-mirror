-- DevSandbox3WorldMarkerActions.lua: HarvestMap-style markers in the 3D world and on the compass
--
-- Every frame-ish (100 ms) while the HUD is up and the player is in Cyrodiil:
--   * orange dot floating above each MISSING expected slot within range (where the book may be)
--   * green dot above each confirmed war torte spawn recorded with world coordinates
-- Both sets also get a small pin on the compass strip, positioned by the signed bearing from the camera
-- (CustomCompassPins technique: offset = bearing / (fov/2) * width/2) and faded with distance.
--
-- 3D: controls with Create3DRenderSpace, placed with WorldPositionToGuiRender3DPosition. Recorded positions
-- are GetUnitWorldPosition metres; the render API wants RAW world cm, so positions are translated through
-- the player (world -> raw) each tick. Billboards face the camera (snipers-friend Euler convention).

local WorldMarkerActions = {}

local Utils = DevSandbox3.WorldMarkerUtils
local SlotUtils = DevSandbox3.SlotUtils
local NodeUtils = DevSandbox3.NodeUtils
local LogUtils = DevSandbox3.LogUtils

local UPDATE_NAME = DevSandbox3.name .. "_WorldMarkers"
local UPDATE_MS = 100
local MAX_MARKERS = 48
local TEXTURE = "DevSandbox3/textures/dot_plain.dds"
local COMPASS_PIN_PX = 14

WorldMarkerActions.ready = false
WorldMarkerActions.world = {}    -- 3D texture controls
WorldMarkerActions.compass = {}  -- compass texture controls
WorldMarkerActions.shown = 0
WorldMarkerActions.lastTargets = {}

local function GetSettings()
    return DevSandbox3.state.savedVars.settings
end

---@param name string
---@return boolean
local function IsCallable(name)
    if type(IsPrivateFunction) == "function" and IsPrivateFunction(name) then return false end
    return type(_G[name]) == "function"
end

-- ---------------------------------------------------------------- controls

local function EnsureControls()
    if WorldMarkerActions.tl then return end
    local tl = WINDOW_MANAGER:CreateTopLevelWindow(DevSandbox3.name .. "_WorldMarkersTL")
    tl:SetDrawLayer(DL_BACKGROUND)
    tl:SetMouseEnabled(false)
    local probe = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. "_WorldMarkersProbe", tl, CT_CONTROL)
    probe:Create3DRenderSpace()

    for i = 1, MAX_MARKERS do
        local marker = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. "_WorldMarker" .. i, tl, CT_TEXTURE)
        marker:Create3DRenderSpace()
        marker:SetTexture(TEXTURE)
        marker:SetHidden(true)
        WorldMarkerActions.world[i] = marker
    end

    -- Compass pins live inside the compass frame so they inherit its fade / hide behaviour.
    local compassParent = ZO_CompassFrame or tl
    local strip = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. "_CompassStrip", compassParent, CT_CONTROL)
    strip:SetAnchorFill(compassParent)
    strip:SetMouseEnabled(false)
    for i = 1, MAX_MARKERS do
        local pin = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. "_CompassPin" .. i, strip, CT_TEXTURE)
        pin:SetTexture(TEXTURE)
        pin:SetDimensions(COMPASS_PIN_PX, COMPASS_PIN_PX)
        pin:SetDrawLevel(10)
        pin:SetHidden(true)
        WorldMarkerActions.compass[i] = pin
    end

    -- Only over the HUD, never inside menus / the map.
    local fragment = ZO_HUDFadeSceneFragment:New(tl)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    WorldMarkerActions.tl, WorldMarkerActions.probe, WorldMarkerActions.strip = tl, probe, strip
end

---@param fromIndex integer
local function HideFrom(fromIndex)
    for i = fromIndex, MAX_MARKERS do
        local w, c = WorldMarkerActions.world[i], WorldMarkerActions.compass[i]
        if w and not w:IsHidden() then w:SetHidden(true) end
        if c and not c:IsHidden() then c:SetHidden(true) end
    end
    WorldMarkerActions.shown = math.min(WorldMarkerActions.shown, fromIndex - 1)
end

-- ---------------------------------------------------------------- targets

---Collect everything worth marking: { x, y, z (metres, world space), r, g, b, dist }.
---@param px number player X metres
---@param pz number player Z metres
---@return table[] targets
local function CollectTargets(px, pz)
    local settings = GetSettings()
    local targets = WorldMarkerActions.lastTargets
    for i = #targets, 1, -1 do targets[i] = nil end
    local rangeM = settings.worldMarkerRangeM or SlotUtils.TRACK_RADIUS_METERS

    -- Missing expected slots within range (orange).
    local SlotActions = DevSandbox3.SlotActions
    local empties = DevSandbox3.state.savedVars.emptySlots
    local expected = DevSandbox3.ExpectedNodes
    if settings.markMissingSlotsInWorld and SlotActions and expected then
        for _, hit in ipairs(SlotActions.inRange or {}) do
            if empties[hit.index] and hit.dist <= rangeM then
                local x, z, h = SlotUtils.NodeAt(expected, hit.index)
                targets[#targets + 1] = { x = x, y = h, z = z, r = 1.0, g = 0.55, b = 0.15, dist = hit.dist }
            end
        end
    end

    -- Confirmed spawns recorded with world coordinates (green).
    if settings.markSpawnsInWorld then
        for _, node in ipairs(DevSandbox3.state.savedVars.nodes) do
            if node.wx and node.wz and node.zoneId == NodeUtils.CYRODIIL_ZONE_ID and not node.candidate then
                local dx, dz = node.wx - px, node.wz - pz
                local dist = math.sqrt(dx * dx + dz * dz)
                if dist <= rangeM then
                    targets[#targets + 1] = { x = node.wx, y = node.wy or 0, z = node.wz, r = 0.45, g = 1.0, b = 0.45, dist = dist }
                end
            end
        end
    end

    table.sort(targets, function(a, b) return a.dist < b.dist end)
    return targets
end

-- ---------------------------------------------------------------- update

local function Update()
    local settings = GetSettings()
    if not (settings.showWorldMarkers or settings.showCompassMarkers) then
        if WorldMarkerActions.shown > 0 then HideFrom(1) end
        return
    end
    if IsReticleHidden() then
        if WorldMarkerActions.shown > 0 then HideFrom(1) end
        return
    end
    local zoneId, pwx, pwy, pwz = GetUnitWorldPosition("player")
    if zoneId ~= NodeUtils.CYRODIIL_ZONE_ID then
        if WorldMarkerActions.shown > 0 then HideFrom(1) end
        return
    end
    local px, pz = pwx / 100, pwz / 100
    local targets = CollectTargets(px, pz)
    if #targets == 0 then
        if WorldMarkerActions.shown > 0 then HideFrom(1) end
        return
    end

    local probe = WorldMarkerActions.probe
    Set3DRenderSpaceToCurrentCamera(probe:GetName())
    local cx, cy, cz = probe:Get3DRenderSpaceOrigin()
    local fx, fy, fz = probe:Get3DRenderSpaceForward()
    local rx, _ry, rz = probe:Get3DRenderSpaceRight()
    local _, prx, pry, prz = GetUnitRawWorldPosition("player")
    local pitch, yaw = Utils.BillboardEuler(fx, fy, fz)

    local compassWidth = ZO_CompassContainer and ZO_CompassContainer:GetWidth() or 0
    local showWorld = settings.showWorldMarkers
    local showCompass = settings.showCompassMarkers and compassWidth > 0
    local rangeM = settings.worldMarkerRangeM or SlotUtils.TRACK_RADIUS_METERS

    local shown = 0
    for i = 1, math.min(#targets, MAX_MARKERS) do
        local t = targets[i]
        local marker, pin = WorldMarkerActions.world[i], WorldMarkerActions.compass[i]

        if showWorld then
            local rawX, rawY, rawZ = Utils.NodeToRawWorld(t.x, t.y + Utils.MARKER_HEIGHT_M, t.z, pwx, pwy, pwz, prx, pry, prz)
            local mx, my, mz = WorldPositionToGuiRender3DPosition(rawX, rawY, rawZ)
            local camDist = math.sqrt((mx - cx) ^ 2 + (my - cy) ^ 2 + (mz - cz) ^ 2)
            local size = Utils.BillboardSize(settings.worldMarkerSizeM, camDist, settings.worldMarkerConstantSize)
            marker:Set3DRenderSpaceOrigin(mx, my, mz)
            marker:Set3DLocalDimensions(size, size)
            marker:Set3DRenderSpaceOrientation(pitch, yaw, 0)
            marker:SetColor(t.r, t.g, t.b, 0.9)
            marker:SetDrawLevel(-math.floor(camDist * 100))
            marker:SetHidden(false)
        elseif not marker:IsHidden() then
            marker:SetHidden(true)
        end

        if showCompass then
            local dx, dz = t.x - px, t.z - pz
            local bearing = Utils.SignedBearing(fx, fz, rx, rz, dx, dz)
            local offset = Utils.CompassOffset(bearing, compassWidth)
            if offset then
                pin:ClearAnchors()
                pin:SetAnchor(CENTER, WorldMarkerActions.strip, CENTER, offset, 0)
                pin:SetColor(t.r, t.g, t.b, Utils.CompassAlpha(t.dist, rangeM))
                pin:SetHidden(false)
            elseif not pin:IsHidden() then
                pin:SetHidden(true)
            end
        elseif not pin:IsHidden() then
            pin:SetHidden(true)
        end
        shown = shown + 1
    end
    WorldMarkerActions.shown = shown
    HideFrom(shown + 1)
end

-- ---------------------------------------------------------------- public

---@return string
function WorldMarkerActions.Status()
    if not WorldMarkerActions.ready then return "world markers unavailable (3D API not callable)" end
    return string.format("world markers: %d shown (3D %s, compass %s)", WorldMarkerActions.shown,
        GetSettings().showWorldMarkers and "on" or "off", GetSettings().showCompassMarkers and "on" or "off")
end

function WorldMarkerActions.Initialize()
    for _, name in ipairs({ "Set3DRenderSpaceToCurrentCamera", "GetUnitRawWorldPosition", "WorldPositionToGuiRender3DPosition", "IsReticleHidden" }) do
        if not IsCallable(name) then
            LogUtils.Debug("world markers unavailable: %s not callable", name)
            return false
        end
    end
    EnsureControls()
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, UPDATE_MS, Update)
    WorldMarkerActions.ready = true
    return true
end

DevSandbox3.WorldMarkerActions = WorldMarkerActions
