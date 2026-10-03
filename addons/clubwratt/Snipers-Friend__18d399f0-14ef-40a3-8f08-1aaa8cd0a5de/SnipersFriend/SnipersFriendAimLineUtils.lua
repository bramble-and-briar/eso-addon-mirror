-- SnipersFriendAimLineUtils.lua: Pure math for the aim line / max-range marker

local AimLineUtils = {}

---Point along the camera ray where HORIZONTAL distance from the player equals
---rangeM. Looking up or down lengthens the ray; a near-vertical look caps at
---maxRayM so we never divide by ~0.
---@param camX number camera origin (render space, metres)
---@param camY number
---@param camZ number
---@param fwdX number camera forward (unit vector)
---@param fwdY number  up component
---@param fwdZ number
---@param playerX number player position (render space)
---@param playerZ number
---@param rangeM number horizontal range in metres
---@param maxRayM number cap on ray length
---@return number endX, number endY, number endZ, number rayLenM, boolean capped
function AimLineUtils.RangeEndPoint(camX, camY, camZ, fwdX, fwdY, fwdZ, playerX, playerZ, rangeM, maxRayM)
    -- solve |(cam + t*fwd)_xz - player_xz| = range for t >= 0
    local dx, dz = camX - playerX, camZ - playerZ
    local a = fwdX * fwdX + fwdZ * fwdZ
    local b = 2 * (dx * fwdX + dz * fwdZ)
    local c = dx * dx + dz * dz - rangeM * rangeM
    local t, capped = maxRayM, true
    if a >= 1e-6 then
        local disc = b * b - 4 * a * c
        if disc >= 0 then
            t = (-b + math.sqrt(disc)) / (2 * a)
            if t < 0 then t = 0 end
            capped = false
            if t > maxRayM then t, capped = maxRayM, true end
        end
    end
    return camX + fwdX * t, camY + fwdY * t, camZ + fwdZ * t, t, capped
end

---Euler orientation for a quad lying along the segment p1 -> p2 with its local +Y
---(texture height) along the segment and its face horizontal (seen from above).
---Convention verified in production by CrutchAlerts' Drawing.CreateLine.
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return number pitch, number yaw, number length
function AimLineUtils.LineOrientation(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
    local xz = math.sqrt(dx * dx + dz * dz)
    local pitch = math.pi / 2 - math.atan2(dy, xz)
    local yaw = math.pi / 2 - math.atan2(dz, dx)
    return pitch, yaw, math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Where the camera ray meets the player's floor plane (More Markers' cursor placement).
---Only valid when looking down at least minPitch radians; returns nil otherwise.
---@param camX number
---@param camY number
---@param camZ number
---@param fwdX number
---@param fwdY number
---@param fwdZ number
---@param floorY number
---@param minPitch number
---@return number|nil x, number y, number z, number horizontalFromCam
function AimLineUtils.GroundPoint(camX, camY, camZ, fwdX, fwdY, fwdZ, floorY, minPitch)
    local horiz = math.sqrt(fwdX * fwdX + fwdZ * fwdZ)
    local pitchDown = -math.atan2(fwdY, horiz)
    if pitchDown <= minPitch or camY <= floorY then return nil end
    local r = (camY - floorY) / math.tan(pitchDown)
    local yaw = math.atan2(fwdX, fwdZ)
    return camX + r * math.sin(yaw), floorY, camZ + r * math.cos(yaw), r
end

---@param a number
---@param b number
---@param t number
---@return number
function AimLineUtils.Lerp(a, b, t)
    return a + (b - a) * t
end

---@return number, number, number
function AimLineUtils.Normalize(x, y, z)
    local len = math.sqrt(x * x + y * y + z * z)
    if len < 1e-9 then return 0, 1, 0 end
    return x / len, y / len, z / len
end

---@return number, number, number
function AimLineUtils.Cross(ax, ay, az, bx, by, bz)
    return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

---Orthonormal basis for a strip whose local +Y (texture height) runs along the
---segment and whose face is turned toward the camera as far as possible.
---A quad is seen edge-on when the camera lies in its plane, so the width axis is
---chosen perpendicular to both the segment and the direction to the camera.
---@param dx number segment direction (unit)
---@param dy number
---@param dz number
---@param toCamX number midpoint -> camera (any length)
---@param toCamY number
---@param toCamZ number
---@return number rx, number ry, number rz, number ux, number uy, number uz, number fx, number fy, number fz
function AimLineUtils.StripBasis(dx, dy, dz, toCamX, toCamY, toCamZ)
    local rx, ry, rz = AimLineUtils.Cross(dx, dy, dz, toCamX, toCamY, toCamZ)
    if rx * rx + ry * ry + rz * rz < 1e-9 then
        -- camera exactly on the segment line: any perpendicular will do
        rx, ry, rz = AimLineUtils.Cross(dx, dy, dz, 0, 1, 0)
        if rx * rx + ry * ry + rz * rz < 1e-9 then rx, ry, rz = 1, 0, 0 end
    end
    rx, ry, rz = AimLineUtils.Normalize(rx, ry, rz)
    local fx, fy, fz = AimLineUtils.Cross(rx, ry, rz, dx, dy, dz) -- normal, points toward camera side
    return rx, ry, rz, dx, dy, dz, fx, fy, fz
end

---Basis for a billboard quad facing the camera, kept upright.
---@return number rx, number ry, number rz, number ux, number uy, number uz, number fx, number fy, number fz
function AimLineUtils.BillboardBasis(toCamX, toCamY, toCamZ)
    local fx, fy, fz = AimLineUtils.Normalize(toCamX, toCamY, toCamZ)
    local rx, ry, rz = AimLineUtils.Cross(0, 1, 0, fx, fy, fz)
    if rx * rx + ry * ry + rz * rz < 1e-9 then rx, ry, rz = 1, 0, 0 end
    rx, ry, rz = AimLineUtils.Normalize(rx, ry, rz)
    local ux, uy, uz = AimLineUtils.Cross(fx, fy, fz, rx, ry, rz)
    return rx, ry, rz, ux, uy, uz, fx, fy, fz
end

SnipersFriend.AimLineUtils = AimLineUtils
