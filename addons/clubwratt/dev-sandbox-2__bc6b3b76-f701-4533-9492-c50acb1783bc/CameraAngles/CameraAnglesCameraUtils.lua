-- CameraAnglesCameraUtils.lua: Pure angle math and formatting for a camera reading

local CameraUtils = {}

local RAD_TO_DEG = 180 / math.pi

---Round to a number of decimals; a rounded zero is +0 so it never prints as "-0.00".
---@param value number
---@param decimals number
---@return number
function CameraUtils.Round(value, decimals)
    local scale = 10 ^ decimals
    local rounded = math.floor(value * scale + 0.5) / scale
    if rounded == 0 then return 0 end
    return rounded
end

---@param radians number
---@return number degrees
function CameraUtils.ToDegrees(radians)
    return radians * RAD_TO_DEG
end

---Degrees as a compass-style value in [0, 360), rounded to two decimals.
---@param radians number
---@return number
function CameraUtils.ToCompassDegrees(radians)
    local wrapped = CameraUtils.Round(CameraUtils.ToDegrees(radians), 2) % 360
    if wrapped == 0 then return 0 end
    return wrapped
end

---Degrees as a signed value, rounded to two decimals.
---@param radians number
---@return number
function CameraUtils.ToSignedDegrees(radians)
    return CameraUtils.Round(CameraUtils.ToDegrees(radians), 2)
end

---Yaw and pitch of a look direction (Y up): yaw turns about the vertical axis from +Z
---toward +X, the way the housing editor measures it (atan2(x, z)); pitch is the
---elevation, positive looking up.
---@param forwardX number
---@param forwardY number
---@param forwardZ number
---@return number yawRadians, number pitchRadians
function CameraUtils.LookAngles(forwardX, forwardY, forwardZ)
    local horizontal = math.sqrt(forwardX * forwardX + forwardZ * forwardZ)
    local yaw = math.atan2(forwardX, forwardZ)
    local pitch = math.atan2(forwardY, horizontal)
    return yaw, pitch
end

---The chat lines for one reading.
---@param reading CameraAnglesReading
---@return string[]
function CameraUtils.FormatReading(reading)
    local lookYaw, lookPitch = CameraUtils.LookAngles(reading.forwardX, reading.forwardY, reading.forwardZ)
    return {
        string.format("yaw %.2f  pitch %.2f  roll %.2f  (degrees)",
            CameraUtils.ToCompassDegrees(reading.yaw),
            CameraUtils.ToSignedDegrees(reading.pitch),
            CameraUtils.ToSignedDegrees(reading.roll)),
        string.format("radians: yaw %.4f  pitch %.4f  roll %.4f",
            CameraUtils.Round(reading.yaw, 4),
            CameraUtils.Round(reading.pitch, 4),
            CameraUtils.Round(reading.roll, 4)),
        string.format("check: heading %.2f  look yaw %.2f  look pitch %.2f",
            CameraUtils.ToCompassDegrees(reading.heading),
            CameraUtils.ToCompassDegrees(lookYaw),
            CameraUtils.ToSignedDegrees(lookPitch)),
    }
end

CameraAngles.CameraUtils = CameraUtils
