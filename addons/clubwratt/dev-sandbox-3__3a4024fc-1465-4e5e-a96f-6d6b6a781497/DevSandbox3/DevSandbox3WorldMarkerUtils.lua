-- DevSandbox3WorldMarkerUtils.lua: Pure math for the HarvestMap-style 3D world markers and compass pins (no side effects)

local WorldMarkerUtils = {}

-- The compass strip shows roughly this much of the horizon (CustomCompassPins' defaultFOV).
WorldMarkerUtils.COMPASS_FOV = math.pi * 0.6
-- Markers float this far above the recorded node position (metres).
WorldMarkerUtils.MARKER_HEIGHT_M = 1.5
-- Constant-screen-size mode: markerSizeM is the world size at this distance.
WorldMarkerUtils.REF_DISTANCE_M = 10
-- Compass pins fade from full alpha at 0 m to this alpha at max distance.
WorldMarkerUtils.COMPASS_FAR_ALPHA = 0.35

---Signed horizontal angle from the camera forward vector to a target direction, positive = to the viewer's
---RIGHT. Uses the camera's own right vector so axis handedness never has to be guessed.
---@param fx number camera forward X (horizontal)
---@param fz number camera forward Z (horizontal)
---@param rx number camera right X (horizontal)
---@param rz number camera right Z (horizontal)
---@param dx number player -> target X
---@param dz number player -> target Z
---@return number radians in (-pi, pi]
function WorldMarkerUtils.SignedBearing(fx, fz, rx, rz, dx, dz)
    local forward = fx * dx + fz * dz
    local right = rx * dx + rz * dz
    return math.atan2(right, forward)
end

---Horizontal pixel offset of a compass pin from the compass centre, or nil when outside the compass arc.
---@param bearing number signed radians (positive = right)
---@param compassWidth number pixels
---@param fov number|nil radians shown across the whole compass (default COMPASS_FOV)
---@return number|nil offsetX
function WorldMarkerUtils.CompassOffset(bearing, compassWidth, fov)
    fov = fov or WorldMarkerUtils.COMPASS_FOV
    local normalized = bearing / (fov / 2)
    if normalized < -1 or normalized > 1 then return nil end
    return normalized * compassWidth / 2
end

---Alpha for a compass pin at a distance: 1 when adjacent, COMPASS_FAR_ALPHA at maxDistance.
---@param dist number metres
---@param maxDistance number metres
---@return number alpha
function WorldMarkerUtils.CompassAlpha(dist, maxDistance)
    if maxDistance <= 0 then return 1 end
    local t = math.min(math.max(dist / maxDistance, 0), 1)
    return 1 - t * (1 - WorldMarkerUtils.COMPASS_FAR_ALPHA)
end

---World size for a billboard that should read as a constant size on screen.
---@param baseSizeM number size at REF_DISTANCE_M
---@param dist number metres from the camera
---@param constant boolean false = fixed world size
---@return number metres
function WorldMarkerUtils.BillboardSize(baseSizeM, dist, constant)
    if not constant then return baseSizeM end
    return baseSizeM * math.max(dist, 1) / WorldMarkerUtils.REF_DISTANCE_M
end

---Euler orientation that makes a 3D quad face the camera (snipers-friend / CrutchAlerts convention).
---@param fx number camera forward X
---@param fy number camera forward Y
---@param fz number camera forward Z
---@return number pitch
---@return number yaw
function WorldMarkerUtils.BillboardEuler(fx, fy, fz)
    local pitch = math.atan2(fy, math.sqrt(fx * fx + fz * fz))
    local yaw = math.atan2(fx, fz) - math.pi
    return pitch, yaw
end

---Translate a recorded world position (metres, world space) into the RAW world space the 3D render API wants,
---using the player's position in both spaces as the anchor.
---@param nodeX number metres
---@param nodeY number metres (height)
---@param nodeZ number metres
---@param playerWorldXcm integer GetUnitWorldPosition
---@param playerWorldYcm integer
---@param playerWorldZcm integer
---@param playerRawXcm integer GetUnitRawWorldPosition
---@param playerRawYcm integer
---@param playerRawZcm integer
---@return integer rawXcm
---@return integer rawYcm
---@return integer rawZcm
function WorldMarkerUtils.NodeToRawWorld(nodeX, nodeY, nodeZ, playerWorldXcm, playerWorldYcm, playerWorldZcm, playerRawXcm, playerRawYcm, playerRawZcm)
    return nodeX * 100 - playerWorldXcm + playerRawXcm,
        nodeY * 100 - playerWorldYcm + playerRawYcm,
        nodeZ * 100 - playerWorldZcm + playerRawZcm
end

DevSandbox3.WorldMarkerUtils = WorldMarkerUtils
