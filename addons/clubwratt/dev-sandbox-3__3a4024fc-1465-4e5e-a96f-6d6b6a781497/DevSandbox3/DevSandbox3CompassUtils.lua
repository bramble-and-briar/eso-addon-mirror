-- DevSandbox3CompassUtils.lua: Pure helpers for compass-based node detection (no side effects)

local CompassUtils = {}

-- The engine reports MAP_PIN_TYPE_HARVEST_NODE (179) for resource nodes once the pin type is declared in XML.
CompassUtils.HARVEST_NODE_PIN_TYPE = MAP_PIN_TYPE_HARVEST_NODE or 179

-- Every compass pin category we declare invisibly in DevSandbox3Compass.xml, keyed by pin type id.
-- drawLevel = drawLevelOffsetBase from the XML, used to classify a pin control at add/remove time.
CompassUtils.PROBE_TYPES = {
    [MAP_PIN_TYPE_HARVEST_NODE or 179] = { name = "HARVEST_NODE", drawLevel = 120 },
    [MAP_PIN_TYPE_LOCATION or 178]     = { name = "LOCATION",     drawLevel = 121 },
    [MAP_PIN_TYPE_VENDOR or 180]       = { name = "VENDOR",       drawLevel = 122 },
    [MAP_PIN_TYPE_TRAINER or 181]      = { name = "TRAINER",      drawLevel = 123 },
    [MAP_PIN_TYPE_NPC_FOLLOWER or 182] = { name = "NPC_FOLLOWER", drawLevel = 124 },
}

---@param pinType integer|nil
---@return string
function CompassUtils.PinTypeName(pinType)
    local probe = pinType and CompassUtils.PROBE_TYPES[pinType]
    return probe and probe.name or ("type " .. tostring(pinType))
end

---@param pinType integer|nil
---@return boolean
function CompassUtils.IsProbeType(pinType)
    return pinType ~= nil and CompassUtils.PROBE_TYPES[pinType] ~= nil
end

---Map a compass pin control's draw level back to the pin type we declared it with.
---@param drawLevel integer|nil
---@return integer|nil pinType
function CompassUtils.PinTypeFromDrawLevel(drawLevel)
    if not drawLevel then return nil end
    for pinType, probe in pairs(CompassUtils.PROBE_TYPES) do
        if probe.drawLevel == drawLevel then
            return pinType
        end
    end
    return nil
end

-- Poll cadence for the centered-pin query while any harvest pin is in range.
CompassUtils.POLL_INTERVAL_MS = 150

-- Debug log throttle: the same description is logged at most once per this many seconds.
CompassUtils.DEBUG_LOG_COOLDOWN_SECONDS = 20

---Project a point `distanceMeters` ahead of the player along the camera's horizontal forward vector.
---World units are centimeters; Y is height.
---@param playerX integer
---@param playerY integer height (cm)
---@param playerZ integer
---@param forwardX number camera forward X (render space)
---@param forwardZ number camera forward Z (render space)
---@param distanceCm number
---@return integer worldX
---@return integer worldY
---@return integer worldZ
function CompassUtils.ProjectAhead(playerX, playerY, playerZ, forwardX, forwardZ, distanceCm)
    local length = math.sqrt(forwardX * forwardX + forwardZ * forwardZ)
    if length < 1e-6 then
        return playerX, playerY, playerZ
    end
    local dirX = forwardX / length
    local dirZ = forwardZ / length
    return math.floor(playerX + dirX * distanceCm + 0.5), playerY, math.floor(playerZ + dirZ * distanceCm + 0.5)
end

---@param lastLoggedAt table<string, integer>
---@param description string
---@param now integer
---@return boolean shouldLog
function CompassUtils.ShouldDebugLog(lastLoggedAt, description, now)
    local last = lastLoggedAt[description]
    if last and now - last < CompassUtils.DEBUG_LOG_COOLDOWN_SECONDS then
        return false
    end
    lastLoggedAt[description] = now
    return true
end

---@param distanceCm number
---@return string
function CompassUtils.FormatDistance(distanceCm)
    return string.format("%dm", math.floor(distanceCm / 100 + 0.5))
end

DevSandbox3.CompassUtils = CompassUtils
