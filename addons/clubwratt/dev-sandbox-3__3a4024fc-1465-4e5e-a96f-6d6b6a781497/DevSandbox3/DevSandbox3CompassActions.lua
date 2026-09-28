-- DevSandbox3CompassActions.lua: HarvestMap-style detection via the engine's hidden HARVEST_NODE compass pins.
--
-- Once DevSandbox3Compass.xml declares the HARVEST_NODE compass pin type, the client creates an (invisible)
-- compass pin for every resource node within 200 m. When the player faces one, the compass reports its
-- description and distance from the player, which is enough to place it in the world.

local CompassActions = {}

local CompassUtils = DevSandbox3.CompassUtils
local NodeUtils = DevSandbox3.NodeUtils
local LogUtils = DevSandbox3.LogUtils

local UPDATE_NAME = DevSandbox3.name .. "_CompassPoll"

CompassActions.pinsInRange = 0
CompassActions.pinsInRangeByType = {}
CompassActions.lastLoggedAt = {}
CompassActions.lastRecordedKey = nil
CompassActions.cameraControl = nil

---@param pinType integer|nil
---@return boolean
local function IsTypeActive(pinType)
    if pinType == CompassUtils.HARVEST_NODE_PIN_TYPE then return true end
    return CompassUtils.IsProbeType(pinType) and DevSandbox3.state.savedVars.settings.probeAllTypes == true
end

---@param control table
---@return integer|nil pinType
local function PinTypeOfControl(control)
    local ok, drawLevel = pcall(function() return control:GetDrawLevel() end)
    if not ok then return nil end
    return CompassUtils.PinTypeFromDrawLevel(drawLevel)
end

---@return string
local function DescribeInRange()
    local parts = {}
    for pinType, count in pairs(CompassActions.pinsInRangeByType) do
        if count > 0 then
            parts[#parts + 1] = string.format("%s x%d", CompassUtils.PinTypeName(pinType), count)
        end
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "none"
end

---@return number forwardX
---@return number forwardZ
local function GetCameraForward()
    local control = CompassActions.cameraControl
    Set3DRenderSpaceToCurrentCamera(control:GetName())
    local forwardX, _forwardY, forwardZ = control:Get3DRenderSpaceForward()
    return forwardX, forwardZ
end

---Resolve a centered harvest pin into a zone-normalized position.
---@param distanceCm number
---@return integer zoneId
---@return number nx
---@return number ny
local function ResolveCenteredPinPosition(distanceCm)
    local zoneId, px, py, pz = GetUnitWorldPosition("player")
    local forwardX, forwardZ = GetCameraForward()
    local wx, wy, wz = CompassUtils.ProjectAhead(px, py, pz, forwardX, forwardZ, distanceCm)
    local nx, ny = GetNormalizedWorldPosition(zoneId, wx, wy, wz)
    return zoneId, nx, ny
end

---Poll the compass for harvest pins the player is currently facing.
local function PollCenteredPins()
    if CompassActions.pinsInRange <= 0 then
        return
    end
    local container = ZO_CompassContainer
    if container:IsHidden() then
        return
    end

    local now = GetTimeStamp()
    for i = 1, container:GetNumCenterOveredPins() do
        local description, pinType, distanceCm = container:GetCenterOveredPinInfo(i)
        if IsTypeActive(pinType) and description and description ~= "" then
            local typeName = CompassUtils.PinTypeName(pinType)
            if CompassUtils.ShouldDebugLog(CompassActions.lastLoggedAt, typeName .. "|" .. description, now) then
                LogUtils.Debug("compass: [%s] %s @ %s (in range: %s)", typeName, description, CompassUtils.FormatDistance(distanceCm), DescribeInRange())
            end

            local savedVars = DevSandbox3.state.savedVars
            local class = NodeUtils.ClassifyHarvestNode(description, savedVars.ignoredNames)
            -- Non-harvest probe types (LOCATION etc.) have no known-material list: anything unignored is a candidate.
            if pinType ~= CompassUtils.HARVEST_NODE_PIN_TYPE and class == NodeUtils.CLASS_MATERIAL and not (savedVars.ignoredNames and savedVars.ignoredNames[string.lower(description)]) then
                class = NodeUtils.CLASS_UNKNOWN
            end
            local shouldRecord = class == NodeUtils.CLASS_WAR_TORTE or (class == NodeUtils.CLASS_UNKNOWN and savedVars.recordUnknown)
            if shouldRecord then
                local key = description .. ":" .. math.floor(distanceCm / 500)
                if key ~= CompassActions.lastRecordedKey then
                    CompassActions.lastRecordedKey = key
                    local isCandidate = class == NodeUtils.CLASS_UNKNOWN
                    local zoneId, nx, ny = ResolveCenteredPinPosition(distanceCm)
                    local taggedName = pinType == CompassUtils.HARVEST_NODE_PIN_TYPE and description or string.format("%s [%s]", description, typeName)
                    local node, isNew = DevSandbox3.NodeActions.RecordAtNormalized(zoneId, nx, ny, taggedName, false, isCandidate)
                    if node then
                        local distanceText = CompassUtils.FormatDistance(distanceCm)
                        if isCandidate then
                            LogUtils.Log("Unrecognized %s '%s' @ %s - saved as candidate (%d total). If it's nothing: /ds3 ignore %s", typeName, description, distanceText, #savedVars.nodes, description)
                        else
                            LogUtils.Log("%s war torte recipe spawn via compass: %s @ %s (%d total)", isNew and "New" or "Known", description, distanceText, #savedVars.nodes)
                        end
                        DevSandbox3.AlertActions.Show(description, distanceText, isCandidate)
                    end
                end
            end
        end
    end
end

local function StartPolling()
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, CompassUtils.POLL_INTERVAL_MS, PollCenteredPins)
end

local function StopPolling()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    CompassActions.lastRecordedKey = nil
end

---XML callback: the engine added one of our probe compass pins (an object entered 200 m).
---@param control table
function CompassActions.OnPinAdded(control)
    CompassActions.pinsInRange = CompassActions.pinsInRange + 1
    local pinType = PinTypeOfControl(control)
    if pinType then
        CompassActions.pinsInRangeByType[pinType] = (CompassActions.pinsInRangeByType[pinType] or 0) + 1
    end
    if CompassActions.pinsInRange == 1 then
        StartPolling()
    end
    -- Non-harvest pins entering range get a loud line only when the (testing-only) probe option is on.
    if pinType and pinType ~= CompassUtils.HARVEST_NODE_PIN_TYPE and IsTypeActive(pinType) then
        LogUtils.Log("compass: %s pin entered 200m - face it to identify (in range: %s)", CompassUtils.PinTypeName(pinType), DescribeInRange())
    else
        LogUtils.Debug("compass: %s pin added (in range: %s)", CompassUtils.PinTypeName(pinType), DescribeInRange())
    end
end

---XML callback: the engine removed one of our probe compass pins.
---@param control table
function CompassActions.OnPinRemoved(control)
    CompassActions.pinsInRange = math.max(0, CompassActions.pinsInRange - 1)
    local pinType = PinTypeOfControl(control)
    if pinType and CompassActions.pinsInRangeByType[pinType] then
        CompassActions.pinsInRangeByType[pinType] = math.max(0, CompassActions.pinsInRangeByType[pinType] - 1)
    end
    if CompassActions.pinsInRange == 0 then
        StopPolling()
    end
end

---Manual snapshot for /ds3 scan.
function CompassActions.Scan()
    local container = ZO_CompassContainer
    local centered = container:GetNumCenterOveredPins()
    LogUtils.Log("compass: %d probe pin(s) within 200m (%s), %d pin(s) centered%s", CompassActions.pinsInRange, DescribeInRange(), centered, DevSandbox3.state.savedVars.settings.probeAllTypes and "" or " [only HARVEST_NODE is acted on; enable 'Probe all compass pin types' to test the rest]")
    for i = 1, centered do
        local description, pinType, distanceCm = container:GetCenterOveredPinInfo(i)
        LogUtils.Log("  centered %d: [%s] '%s' @ %s", i, CompassUtils.PinTypeName(pinType), tostring(description), CompassUtils.FormatDistance(distanceCm or 0))
    end
end

function CompassActions.Initialize()
    CompassActions.cameraControl = CreateControl(DevSandbox3.name .. "_CameraSpace", GuiRoot, CT_CONTROL)
    CompassActions.cameraControl:Create3DRenderSpace()

    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_CompassReset", EVENT_PLAYER_DEACTIVATED, function()
        CompassActions.pinsInRange = 0
        CompassActions.pinsInRangeByType = {}
        StopPolling()
    end)
end

-- Globals referenced from DevSandbox3Compass.xml
function DevSandbox3_OnCompassPinAdded(control)
    CompassActions.OnPinAdded(control)
end

function DevSandbox3_OnCompassPinRemoved(control)
    CompassActions.OnPinRemoved(control)
end

DevSandbox3.CompassActions = CompassActions
