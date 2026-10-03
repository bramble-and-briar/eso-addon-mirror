-- Atlas 2.0.0
-- Standalone map-coordinate conversion for Atlas.
--
-- Atlas uses ESO's universally normalized map measurements directly. The
-- conversion is intentionally small and self-contained: no LibGPS or other
-- runtime library is required.

AtlasAddon = AtlasAddon or {}
local AE = AtlasAddon

AE.Coordinates = AE.Coordinates or {}
local Coordinates = AE.Coordinates

local TAMRIEL_MAP_ID = 27
local calibrationX = nil
local calibrationY = nil

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Coordinates:InitializeCalibration()
    if IsFiniteNumber(calibrationX) and IsFiniteNumber(calibrationY) then
        return true
    end

    if type(GetUniversallyNormalizedMapInfo) ~= "function" then
        return false
    end

    local offsetX, offsetY = GetUniversallyNormalizedMapInfo(TAMRIEL_MAP_ID)
    if not IsFiniteNumber(offsetX) or not IsFiniteNumber(offsetY) then
        return false
    end

    calibrationX = offsetX
    calibrationY = offsetY
    return true
end

function Coordinates:GetMeasurement(mapId)
    if not self:InitializeCalibration() then return nil end

    if not IsFiniteNumber(mapId) or mapId <= 0 then
        if type(GetCurrentMapId) ~= "function" then return nil end
        mapId = GetCurrentMapId()
    end

    if not IsFiniteNumber(mapId) or mapId <= 0 then return nil end

    local offsetX, offsetY, scaleX, scaleY = GetUniversallyNormalizedMapInfo(mapId)
    if not IsFiniteNumber(offsetX) or not IsFiniteNumber(offsetY)
        or not IsFiniteNumber(scaleX) or not IsFiniteNumber(scaleY)
        or scaleX == 0 or scaleY == 0 then
        return nil
    end

    -- ESO's universal coordinate space contains a small origin offset. Using
    -- Tamriel's map origin as calibration makes the coordinate space stable and
    -- directly comparable between a submap and all of its parent maps.
    return offsetX - calibrationX, offsetY - calibrationY, scaleX, scaleY
end

function Coordinates:LocalToGlobal(x, y, mapId)
    if not IsFiniteNumber(x) or not IsFiniteNumber(y) then return nil end

    local offsetX, offsetY, scaleX, scaleY = self:GetMeasurement(mapId)
    if not offsetX then return nil end

    return x * scaleX + offsetX, y * scaleY + offsetY
end

function Coordinates:GlobalToLocal(x, y, mapId)
    if not IsFiniteNumber(x) or not IsFiniteNumber(y) then return nil end

    local offsetX, offsetY, scaleX, scaleY = self:GetMeasurement(mapId)
    if not offsetX then return nil end

    return (x - offsetX) / scaleX, (y - offsetY) / scaleY
end
