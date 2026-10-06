-- DevSandbox3DetectionActions.lua: where are the harvest nodes around me? (HarvestMap's technique)
--
-- Every HARVEST_NODE compass pin the engine creates is handed to us by the XML (addedAnimation OnPlay/OnStop).
-- Every 50 ms each not-yet-located pin is sampled: strip position -> cot(angle) (Shinni's table), scale -> distance,
-- cast from the camera in the raw world frame. After 3 samples within 3 m the node is located and never resampled.
-- Every 100 ms the pin under the reticle is named from the compass description (-> pin type).
--
-- Console facts that cost a day (2026-10-05): pin controls arrive as USERDATA, not Lua tables - never guard with
-- type(control) == "table". And d() output is not a reliable way to see load/event-time logs on console; use
-- LibConsoleLogger + the receiver (/ds3 export).
local Detection = {}

local Utils = DevSandbox3.DetectionUtils
local PinTypeUtils = DevSandbox3.PinTypeUtils
local LogUtils = DevSandbox3.LogUtils

Detection.pins = {}        -- control -> DevSandbox3Node (every live pin)
Detection.located = {}     -- control -> DevSandbox3Node (subset with x/z)
-- The engine recycles pin controls: a located pin is removed and re-added seconds later (field log 4.3.1: same
-- userdata handles cycle OnStop -> OnPlay). Dropping the node on OnStop made every covered slot blink orange until
-- the new pin re-located. So removed located nodes linger here for GRACE_MS (or until re-located nearby).
Detection.lingering = {}   -- node -> expiry frame ms
Detection.GRACE_MS = 8000   -- 4 s still let a dot flicker in the field
Detection.liveCount = 0
Detection.locatedCount = 0
Detection.distanceScale = 1
Detection.measure = nil

local function IsControl(c)
    local t = type(c)
    return t == "userdata" or t == "table"
end

function Detection.OnPinAdded(control)
    if not IsControl(control) then LogUtils.Log("OnPinAdded rejected: type=%s", type(control)); return end
    if Detection.pins[control] then return end
    Detection.pins[control] = { control = control, samplesX = {}, samplesZ = {} }
    Detection.liveCount = Detection.liveCount + 1
    LogUtils.Debug("pin + live=%d", Detection.liveCount)
end

function Detection.OnPinRemoved(control)
    if not IsControl(control) then return end
    local node = Detection.pins[control]
    if not node then return end
    Detection.pins[control] = nil
    if Detection.located[control] then
        Detection.located[control] = nil
        Detection.locatedCount = Detection.locatedCount - 1
        Detection.lingering[node] = GetFrameTimeMilliseconds() + Detection.GRACE_MS
    end
    Detection.liveCount = Detection.liveCount - 1
    LogUtils.Debug("pin - live=%d located=%d%s", Detection.liveCount, Detection.locatedCount, node.x and string.format(" (was %.1f,%.1f)", node.x, node.z) or "")
end

local function ExpireLingering()
    local now = GetFrameTimeMilliseconds()
    for node, expiry in pairs(Detection.lingering) do
        if now >= expiry then Detection.lingering[node] = nil end
    end
end

---50 ms: HarvestMap OnUpdateNodeListHandler
local function SamplePositions()
    ExpireLingering()
    if ZO_CompassContainer:IsHidden() then return end
    local m = Detection.measure
    Set3DRenderSpaceToCurrentCamera(m:GetName())
    local camX, camZ, camY = m:Get3DRenderSpaceOrigin()
    local forwardX, _fz, forwardY = m:Get3DRenderSpaceForward()
    local rightX, _rz, rightY = m:Get3DRenderSpaceRight()
    camX, camZ, camY = GuiRender3DPositionToWorldPosition(camX, camZ, camY)
    camX, camY = camX / 100, camY / 100
    local left, width = ZO_CompassContainer:GetLeft(), ZO_CompassContainer:GetWidth()
    for control, node in pairs(Detection.pins) do
        if not node.x then
            local relativeX = 2 * (control:GetCenter() - left) / width - 1
            local cot = Utils.ComputeCotangent(relativeX)
            local distance = (2 - control:GetScale()) * 100 * Detection.distanceScale
            -- pins outside the strip read center 0 / scale 0 until they come into view: skip silently
            if cot and distance < 190 then
                local fl = math.sqrt(forwardX * forwardX + forwardY * forwardY)
                local dirX, dirY = forwardX / fl + rightX * cot, forwardY / fl + rightY * cot
                local dl = math.sqrt(dirX * dirX + dirY * dirY)
                dirX, dirY = dirX / dl, dirY / dl
                local xs, zs = node.samplesX, node.samplesZ
                -- only the last 3 samples matter (IsStable); shift in place, no allocation
                xs[1], xs[2], xs[3] = xs[2], xs[3], camX + dirX * distance
                zs[1], zs[2], zs[3] = zs[2], zs[3], camY + dirY * distance
                if xs[1] and Utils.IsStable(xs, zs) then
                    node.x, node.z = xs[#xs], zs[#zs]
                    Detection.located[control] = node
                    Detection.locatedCount = Detection.locatedCount + 1
                    for old in pairs(Detection.lingering) do
                        local dx, dz = old.x - node.x, old.z - node.z
                        if dx * dx + dz * dz <= 9 then Detection.lingering[old] = nil end
                    end
                    LogUtils.Debug("located node at %.1f, %.1f (%dm)", node.x, node.z, math.floor(distance + 0.5))
                end
            end
        end
    end
end

---100 ms: HarvestMap OnUpdatePinTypeHandler - name the pin under the reticle
local function NamePins()
    local c = ZO_CompassContainer
    local left, width = c:GetLeft(), c:GetWidth()
    for i = 1, c:GetNumCenterOveredPins() do
        if c:GetCenterOveredPinType(i) == MAP_PIN_TYPE_HARVEST_NODE then
            local pinTypeId = PinTypeUtils.FromName(c:GetCenterOveredPinDescription(i))
            if pinTypeId then
                local _, level = c:GetCenterOveredPinLayerAndLevel(i)
                local match
                for control, node in pairs(Detection.pins) do
                    if not node.pinTypeId and control:GetDrawLevel() == level and (2 * (control:GetCenter() - left) / width - 1) < 0.14 then
                        if match then match = nil; break end -- ambiguous
                        match = node
                    end
                end
                if match then
                    match.pinTypeId = pinTypeId
                    LogUtils.Debug("named '%s' -> type %d", tostring(c:GetCenterOveredPinDescription(i)), pinTypeId)
                end
            end
        end
    end
end

local function OnActivated()
    local zoneid, x, y, z = GetUnitRawWorldPosition("player")
    local r1 = GetNormalizedWorldPosition(zoneid, x + 1000, y, z) - GetNormalizedWorldPosition(zoneid, x, y, z)
    local zoneid2, x2, y2, z2 = GetUnitWorldPosition("player")
    local r2 = GetRawNormalizedWorldPosition(zoneid2, x2 + 1000, y2, z2) - GetRawNormalizedWorldPosition(zoneid2, x2, y2, z2)
    Detection.distanceScale = (r1 and r1 ~= 0 and r2) and (r2 / r1) or 1
    LogUtils.Debug("player activated: distanceScale %.3f", Detection.distanceScale)
    if not Detection.running then
        EVENT_MANAGER:RegisterForUpdate(DevSandbox3.name .. "_Sample", 50, SamplePositions)
        EVENT_MANAGER:RegisterForUpdate(DevSandbox3.name .. "_Name", 100, NamePins)
        Detection.running = true
    end
end

function Detection.Initialize()
    Detection.measure = CreateControl(DevSandbox3.name .. "_Measure", GuiRoot, CT_CONTROL)
    Detection.measure:Create3DRenderSpace()
    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        Detection.pins, Detection.located, Detection.lingering, Detection.liveCount, Detection.locatedCount = {}, {}, {}, 0, 0
    end)
    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_Activated", EVENT_PLAYER_ACTIVATED, OnActivated)
end

function DevSandbox3_CompassPinAdded(control) Detection.OnPinAdded(control) end
function DevSandbox3_CompassPinRemoved(control) Detection.OnPinRemoved(control) end

DevSandbox3.Detection = Detection
