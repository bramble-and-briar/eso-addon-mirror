-- DevSandbox3SlotUtils.lua: Pure helpers for "expected node slot" tracking (no side effects)
--
-- An expected slot is a Cyrodiil material spawn point from the bundled HarvestMap data. The war torte book
-- replaces a material node, so a slot that is in compass range yet has NO harvest pin is a candidate.

local SlotUtils = {}

-- Expected nodes within this many metres of the player are tracked.
SlotUtils.TRACK_RADIUS_METERS = 200
-- Beyond this distance a missing pin is not trusted (the engine may simply not have streamed the object).
SlotUtils.VERIFY_RADIUS_METERS = 150
-- Zero-harvest-pin shortcut only applies this close.
SlotUtils.NO_PINS_RADIUS_METERS = 120
-- A slot counts as "faced" when the camera forward vector is within this many degrees of it.
SlotUtils.FACING_TOLERANCE_DEGREES = 2.5
-- The player must keep facing an unpinned slot this long before it is marked missing (two polls).
SlotUtils.FACING_DWELL_MS = 400
-- A centred harvest pin whose distance is within this many metres of a slot's distance confirms that slot.
SlotUtils.MATCH_TOLERANCE_METERS = 15
-- A slot already marked missing is counted as a *new* sighting only after this long.
SlotUtils.REMARK_SECONDS = 60
-- Do not trust the compass this soon after a zone load (pins are still being created).
SlotUtils.ACTIVATION_GRACE_MS = 10000
-- A loot event this close to an expected slot is attributed to that slot.
SlotUtils.LOOT_ATTRIBUTION_METERS = 20

SlotUtils.POLL_INTERVAL_MS = 250
SlotUtils.MAP_REFRESH_MS = 1000
SlotUtils.GRID_CELL_METERS = 100

SlotUtils.METHOD_FACING = "facing"
SlotUtils.METHOD_NO_PINS = "nopins"

---@class DevSandbox3ExpectedNodeSet
---@field types string[]
---@field stride integer
---@field count integer
---@field data number[] flat x, z, height, typeIndex
---@field version string

---Read one expected node.
---@param expected DevSandbox3ExpectedNodeSet
---@param index integer 1-based
---@return number x metres
---@return number z metres
---@return number height metres
---@return string typeName
function SlotUtils.NodeAt(expected, index)
    local base = (index - 1) * expected.stride
    local data = expected.data
    return data[base + 1], data[base + 2], data[base + 3], expected.types[data[base + 4]] or "?"
end

---@param x number
---@param z number
---@return string key
local function CellKey(x, z)
    return math.floor(x / SlotUtils.GRID_CELL_METERS) .. ":" .. math.floor(z / SlotUtils.GRID_CELL_METERS)
end

---Bucket every expected node into 100 m grid cells for cheap radius queries.
---@param expected DevSandbox3ExpectedNodeSet
---@return table<string, integer[]> grid
function SlotUtils.BuildGrid(expected)
    local grid = {}
    for index = 1, expected.count do
        local x, z = SlotUtils.NodeAt(expected, index)
        local key = CellKey(x, z)
        local bucket = grid[key]
        if not bucket then
            bucket = {}
            grid[key] = bucket
        end
        bucket[#bucket + 1] = index
    end
    return grid
end

---@class DevSandbox3SlotHit
---@field index integer
---@field dx number metres from player
---@field dz number
---@field dist number metres

---Expected nodes within `radius` metres of (px, pz), unsorted.
---@param expected DevSandbox3ExpectedNodeSet
---@param grid table<string, integer[]>
---@param px number
---@param pz number
---@param radius number
---@return DevSandbox3SlotHit[]
function SlotUtils.QueryInRange(expected, grid, px, pz, radius)
    local hits = {}
    local cells = math.ceil(radius / SlotUtils.GRID_CELL_METERS)
    local cx = math.floor(px / SlotUtils.GRID_CELL_METERS)
    local cz = math.floor(pz / SlotUtils.GRID_CELL_METERS)
    local radiusSq = radius * radius
    for ix = cx - cells, cx + cells do
        for iz = cz - cells, cz + cells do
            local bucket = grid[ix .. ":" .. iz]
            if bucket then
                for _, index in ipairs(bucket) do
                    local x, z = SlotUtils.NodeAt(expected, index)
                    local dx, dz = x - px, z - pz
                    local distSq = dx * dx + dz * dz
                    if distSq <= radiusSq then
                        hits[#hits + 1] = { index = index, dx = dx, dz = dz, dist = math.sqrt(distSq) }
                    end
                end
            end
        end
    end
    return hits
end

---Nearest expected node to (x, z) within `maxMeters`.
---@param expected DevSandbox3ExpectedNodeSet
---@param grid table<string, integer[]>
---@param x number
---@param z number
---@param maxMeters number
---@return integer|nil index
---@return number|nil dist
function SlotUtils.FindNearest(expected, grid, x, z, maxMeters)
    local best, bestDist = nil, maxMeters
    for _, hit in ipairs(SlotUtils.QueryInRange(expected, grid, x, z, maxMeters)) do
        if hit.dist <= bestDist then
            best, bestDist = hit.index, hit.dist
        end
    end
    return best, bestDist
end

---Unsigned angle (degrees) between the horizontal camera forward vector and the direction to a slot.
---@param fx number
---@param fz number
---@param dx number
---@param dz number
---@return number degrees 0..180
function SlotUtils.BearingDelta(fx, fz, dx, dz)
    local fl = math.sqrt(fx * fx + fz * fz)
    local dl = math.sqrt(dx * dx + dz * dz)
    if fl < 1e-6 or dl < 1e-6 then
        return 180
    end
    local cosine = (fx * dx + fz * dz) / (fl * dl)
    if cosine > 1 then cosine = 1 elseif cosine < -1 then cosine = -1 end
    return math.deg(math.acos(cosine))
end

---Is any centred harvest pin at (about) this slot's distance?
---@param centeredDistances number[] metres, one per centred HARVEST_NODE pin
---@param slotDist number
---@return boolean
function SlotUtils.IsCoveredByCenteredPin(centeredDistances, slotDist)
    for _, dist in ipairs(centeredDistances) do
        if math.abs(dist - slotDist) <= SlotUtils.MATCH_TOLERANCE_METERS then
            return true
        end
    end
    return false
end

---@class DevSandbox3EmptySlot
---@field index integer expected node index
---@field firstEmpty integer unix timestamp
---@field lastEmpty integer
---@field emptyCount integer distinct sightings (REMARK_SECONDS apart)
---@field method string METHOD_FACING | METHOD_NO_PINS of the latest sighting
---@field dist number metres from the player at the latest sighting

---Create or refresh a missing-slot record. Returns true when the record is new.
---@param empties table<integer, DevSandbox3EmptySlot>
---@param index integer
---@param method string
---@param dist number
---@param now integer unix seconds
---@return boolean isNew
---@return boolean counted true when emptyCount was incremented (new or REMARK_SECONDS elapsed)
function SlotUtils.MarkEmpty(empties, index, method, dist, now)
    local entry = empties[index]
    if entry then
        local counted = now - entry.lastEmpty >= SlotUtils.REMARK_SECONDS
        if counted then entry.emptyCount = entry.emptyCount + 1 end
        entry.lastEmpty = now
        entry.method = method
        entry.dist = dist
        return false, counted
    end
    empties[index] = { index = index, firstEmpty = now, lastEmpty = now, emptyCount = 1, method = method, dist = dist }
    return true, true
end

---Drop records whose last sighting is older than ttlSeconds.
---@param empties table<integer, DevSandbox3EmptySlot>
---@param now integer
---@param ttlSeconds integer
---@return integer removed
function SlotUtils.ExpireEmpties(empties, now, ttlSeconds)
    local removed = 0
    for index, entry in pairs(empties) do
        if now - entry.lastEmpty > ttlSeconds then
            empties[index] = nil
            removed = removed + 1
        end
    end
    return removed
end

---@param empties table<integer, DevSandbox3EmptySlot>
---@return integer
function SlotUtils.CountEmpties(empties)
    local n = 0
    for _ in pairs(empties) do n = n + 1 end
    return n
end

---@param entry DevSandbox3EmptySlot
---@param typeName string
---@param now integer
---@return string[] lines tooltip / list lines
function SlotUtils.DescribeEmpty(entry, typeName, now)
    local FormatAge = DevSandbox3.NodeUtils.FormatAge
    return {
        string.format("Expected %s node missing", typeName),
        string.format("Seen empty %dx - first %s, last %s", entry.emptyCount, FormatAge(now - entry.firstEmpty), FormatAge(now - entry.lastEmpty)),
        entry.method == SlotUtils.METHOD_NO_PINS and "No harvest pins at all nearby" or "Faced it, no harvest pin there",
    }
end

DevSandbox3.SlotUtils = SlotUtils
