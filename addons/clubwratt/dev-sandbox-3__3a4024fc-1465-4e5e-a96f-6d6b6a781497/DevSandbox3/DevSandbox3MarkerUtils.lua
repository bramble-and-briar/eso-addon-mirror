-- DevSandbox3MarkerUtils.lua: pure math for the 3D dots (no side effects). Unchanged math since 0.8 (renders correctly on console).
local MarkerUtils = {}

MarkerUtils.REF_DISTANCE_M = 10

---Edge length (render units) so a dot keeps a constant apparent size: `baseSizeM` as seen at REF_DISTANCE_M.
---@return number
function MarkerUtils.BillboardSize(baseSizeM, dist)
    return baseSizeM * math.max(dist, 1) / MarkerUtils.REF_DISTANCE_M
end

---Shrink with distance: 1.0 near, `farScale` at `maxDistance` and beyond (farScale 1 = constant).
---@return number
function MarkerUtils.DistanceScale(dist, maxDistance, farScale)
    if farScale >= 1 or maxDistance <= 0 then return 1 end
    local t = dist / maxDistance
    if t > 1 then t = 1 end
    return 1 - t * (1 - farScale)
end

---Orientation (pitch, yaw) that faces a billboard toward the camera, from the camera forward vector.
---@return number pitch, number yaw
function MarkerUtils.BillboardEuler(fx, fy, fz)
    local pitch = math.atan2(fy, math.sqrt(fx * fx + fz * fz))
    local yaw = math.atan2(fx, fz) - math.pi
    return pitch, yaw
end

DevSandbox3.MarkerUtils = MarkerUtils
