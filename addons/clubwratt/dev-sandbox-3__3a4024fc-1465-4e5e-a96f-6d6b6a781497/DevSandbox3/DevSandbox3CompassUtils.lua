-- DevSandbox3CompassUtils.lua: Pure helpers for compass-based node detection (no side effects)

local CompassUtils = {}

-- The engine reports MAP_PIN_TYPE_HARVEST_NODE (179) for resource nodes once the pin type is declared in XML.
CompassUtils.HARVEST_NODE_PIN_TYPE = MAP_PIN_TYPE_HARVEST_NODE or 179

-- Every compass pin category we declare invisibly in DevSandbox3Compass.xml, keyed by pin type id.
-- Each type has its own added-animation in the XML, which passes the name to the add/remove callbacks.
CompassUtils.PROBE_TYPES = {
    [MAP_PIN_TYPE_HARVEST_NODE or 179] = { name = "HARVEST_NODE" },
    [MAP_PIN_TYPE_LOCATION or 178]     = { name = "LOCATION" },
    [MAP_PIN_TYPE_VENDOR or 180]       = { name = "VENDOR" },
    [MAP_PIN_TYPE_TRAINER or 181]      = { name = "TRAINER" },
    [MAP_PIN_TYPE_NPC_FOLLOWER or 182] = { name = "NPC_FOLLOWER" },
}

CompassUtils.PROBE_TYPE_BY_NAME = {}
for pinType, probe in pairs(CompassUtils.PROBE_TYPES) do
    CompassUtils.PROBE_TYPE_BY_NAME[probe.name] = pinType
end

-- Names seen per type are kept in memory for /ds3 scan; cap so a long session can't grow unbounded.
CompassUtils.MAX_SEEN_NAMES_PER_TYPE = 40

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

---Resolve the type name the XML animation passed to the add/remove callbacks.
---@param typeName string|nil
---@return integer|nil pinType
function CompassUtils.PinTypeFromName(typeName)
    return typeName and CompassUtils.PROBE_TYPE_BY_NAME[typeName] or nil
end

---Sorted "NAME xN" summary of a per-type count table.
---@param counts table<integer, integer>
---@return string
function CompassUtils.DescribeCounts(counts)
    local parts = {}
    for pinType, count in pairs(counts) do
        if count > 0 then
            parts[#parts + 1] = string.format("%s x%d", CompassUtils.PinTypeName(pinType), count)
        end
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "none"
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
