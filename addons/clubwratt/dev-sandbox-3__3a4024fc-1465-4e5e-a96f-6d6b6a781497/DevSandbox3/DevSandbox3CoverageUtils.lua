-- DevSandbox3CoverageUtils.lua: Pure helpers for covered-ground cells and the player radius (no side effects)

local CoverageUtils = {}

-- Detection radius of the compass HARVEST_NODE pins (maxDistanceM in DevSandbox3Compass.xml).
CoverageUtils.DETECTION_RADIUS_METERS = 200

-- One cell = one detection diameter. Cyrodiil (~8 km) is at most ~400 cells, which bounds the pin count.
CoverageUtils.CELL_METERS = CoverageUtils.DETECTION_RADIUS_METERS * 2

-- Hard cap on blobs drawn for coverage, whatever the data says.
CoverageUtils.MAX_COVERAGE_PINS = 500

CoverageUtils.SAMPLE_INTERVAL_MS = 2000
CoverageUtils.RADIUS_REFRESH_MS = 1000

---@param metersPerUnit number meters per 1.0 of zone-normalized space
---@return number cellSizeNormalized
function CoverageUtils.CellSize(metersPerUnit)
    return CoverageUtils.CELL_METERS / metersPerUnit
end

---@param nx number
---@param ny number
---@param cellSize number
---@return string key
---@return integer cx
---@return integer cy
function CoverageUtils.CellKey(nx, ny, cellSize)
    local cx = math.floor(nx / cellSize)
    local cy = math.floor(ny / cellSize)
    return cx .. ":" .. cy, cx, cy
end

---@param key string
---@return integer|nil cx
---@return integer|nil cy
function CoverageUtils.ParseKey(key)
    local cx, cy = string.match(key, "^(-?%d+):(-?%d+)$")
    if not cx then return nil, nil end
    return tonumber(cx), tonumber(cy)
end

---@param cx integer
---@param cy integer
---@param cellSize number
---@return number nx center
---@return number ny center
---@return number radius normalized (slightly over half a cell so neighbours overlap)
function CoverageUtils.CellCircle(cx, cy, cellSize)
    return (cx + 0.5) * cellSize, (cy + 0.5) * cellSize, cellSize * 0.58
end

---@param meters number
---@param metersPerUnit number
---@return number
function CoverageUtils.MetersToNormalized(meters, metersPerUnit)
    return meters / metersPerUnit
end

---@param cells table<string, boolean>
---@return integer
function CoverageUtils.CountCells(cells)
    local n = 0
    for _ in pairs(cells) do n = n + 1 end
    return n
end

DevSandbox3.CoverageUtils = CoverageUtils
