-- DevSandbox3CoverageActions.lua: Record covered ground while riding; draw it and a player radius on the map

local CoverageActions = {}

local CoverageUtils = DevSandbox3.CoverageUtils
local NodeUtils = DevSandbox3.NodeUtils
local PinUtils = DevSandbox3.PinUtils
local LogUtils = DevSandbox3.LogUtils

local SAMPLE_UPDATE = DevSandbox3.name .. "_CoverageSample"
local RADIUS_UPDATE = DevSandbox3.name .. "_RadiusRefresh"

CoverageActions.metersPerUnit = {}   -- zoneId -> meters per normalized unit
CoverageActions.mapShowing = false

local function GetSettings()
    return DevSandbox3.state.savedVars.settings
end

---Measure (once per zone) how many meters one zone-normalized unit is.
---@param zoneId integer
---@param wx integer
---@param wy integer
---@param wz integer
---@return number|nil
local function GetMetersPerUnit(zoneId, wx, wy, wz)
    local cached = CoverageActions.metersPerUnit[zoneId]
    if cached then return cached end
    local nx1 = GetNormalizedWorldPosition(zoneId, wx, wy, wz)
    local nx2 = GetNormalizedWorldPosition(zoneId, wx + 10000, wy, wz) -- +100 m
    local delta = nx2 - nx1
    if not delta or delta <= 0 then return nil end
    local value = 100 / delta
    CoverageActions.metersPerUnit[zoneId] = value
    return value
end

---@return integer zoneId
---@return number|nil nx
---@return number|nil ny
---@return number|nil metersPerUnit
local function GetPlayerZonePosition()
    local zoneId, wx, wy, wz = GetUnitWorldPosition("player")
    local metersPerUnit = GetMetersPerUnit(zoneId, wx, wy, wz)
    if not metersPerUnit then return zoneId, nil, nil, nil end
    local nx, ny = GetNormalizedWorldPosition(zoneId, wx, wy, wz)
    return zoneId, nx, ny, metersPerUnit
end

---@return boolean
local function IsOnCyrodiilZoneMap()
    return GetMapType() == MAPTYPE_ZONE and GetZoneId(GetCurrentMapZoneIndex()) == NodeUtils.CYRODIIL_ZONE_ID
end

-- ---------------------------------------------------------------- sampling

local function SampleCoverage()
    if not GetSettings().trackCoverage then return end
    local zoneId, nx, ny, metersPerUnit = GetPlayerZonePosition()
    if zoneId ~= NodeUtils.CYRODIIL_ZONE_ID or not nx then return end

    local coverage = DevSandbox3.state.savedVars.coverage
    coverage[zoneId] = coverage[zoneId] or {}
    local key = CoverageUtils.CellKey(nx, ny, CoverageUtils.CellSize(metersPerUnit))
    if coverage[zoneId][key] then return end
    coverage[zoneId][key] = true
    if CoverageActions.mapShowing and GetSettings().showCoverage then
        LibMapPins:RefreshPins(DevSandbox3.coveragePinType)
    end
end

-- ---------------------------------------------------------------- pin callbacks

local function AddCoveragePins()
    if not GetSettings().showCoverage or not IsOnCyrodiilZoneMap() then return end
    local zoneId = NodeUtils.CYRODIIL_ZONE_ID
    local cells = DevSandbox3.state.savedVars.coverage[zoneId]
    local metersPerUnit = CoverageActions.metersPerUnit[zoneId]
    if not cells or not metersPerUnit then return end

    local cellSize = CoverageUtils.CellSize(metersPerUnit)
    local drawn = 0
    for key in pairs(cells) do
        local cx, cy = CoverageUtils.ParseKey(key)
        if cx then
            local nx, ny, radius = CoverageUtils.CellCircle(cx, cy, cellSize)
            LibMapPins:CreatePin(DevSandbox3.coveragePinType, key, nx, ny, radius)
            drawn = drawn + 1
            if drawn >= CoverageUtils.MAX_COVERAGE_PINS then break end
        end
    end
end

local function AddPlayerRadiusPin()
    if not GetSettings().showPlayerRadius or not IsOnCyrodiilZoneMap() then return end
    local zoneId, nx, ny, metersPerUnit = GetPlayerZonePosition()
    if zoneId ~= NodeUtils.CYRODIIL_ZONE_ID or not nx then return end
    local radius = CoverageUtils.MetersToNormalized(GetSettings().playerRadiusMeters, metersPerUnit)
    LibMapPins:CreatePin(DevSandbox3.radiusPinType, "player", nx, ny, radius)
end

local function RefreshRadiusPin()
    LibMapPins:RefreshPins(DevSandbox3.radiusPinType)
end

-- ---------------------------------------------------------------- map scene hooks

local function OnMapStateChange(_oldState, newState)
    if newState == SCENE_SHOWING then
        CoverageActions.mapShowing = true
        EVENT_MANAGER:RegisterForUpdate(RADIUS_UPDATE, CoverageUtils.RADIUS_REFRESH_MS, RefreshRadiusPin)
    elseif newState == SCENE_HIDDEN then
        CoverageActions.mapShowing = false
        EVENT_MANAGER:UnregisterForUpdate(RADIUS_UPDATE)
    end
end

-- ---------------------------------------------------------------- public

function CoverageActions.RefreshAll()
    LibMapPins:RefreshPins(DevSandbox3.coveragePinType)
    LibMapPins:RefreshPins(DevSandbox3.radiusPinType)
end

function CoverageActions.ResetCoverage()
    DevSandbox3.state.savedVars.coverage = {}
    LogUtils.Log("Covered ground reset")
    CoverageActions.RefreshAll()
end

---@return integer cells
function CoverageActions.CountCoveredCells()
    local cells = DevSandbox3.state.savedVars.coverage[NodeUtils.CYRODIIL_ZONE_ID]
    return cells and CoverageUtils.CountCells(cells) or 0
end

function CoverageActions.Initialize()
    -- Area-only pins: a zero-size layout with radius > 0 draws just the circle blob (no icon).
    LibMapPins:AddPinType(DevSandbox3.coveragePinType, AddCoveragePins, nil, PinUtils.CreateAreaLayout(45), nil)
    LibMapPins:AddPinType(DevSandbox3.radiusPinType, AddPlayerRadiusPin, nil, PinUtils.CreateAreaLayout(46), nil)
    for _, pinType in ipairs({ DevSandbox3.coveragePinType, DevSandbox3.radiusPinType }) do
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_PVE_MAPGROUP, true)
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_AVA_IMPERIAL_MAPGROUP, true)
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_BATTLEGROUND_MAPGROUP, true)
    end

    for _, sceneName in ipairs({ "worldMap", "gamepad_worldMap" }) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", OnMapStateChange)
        end
    end

    EVENT_MANAGER:RegisterForUpdate(SAMPLE_UPDATE, CoverageUtils.SAMPLE_INTERVAL_MS, SampleCoverage)
end

DevSandbox3.CoverageActions = CoverageActions
