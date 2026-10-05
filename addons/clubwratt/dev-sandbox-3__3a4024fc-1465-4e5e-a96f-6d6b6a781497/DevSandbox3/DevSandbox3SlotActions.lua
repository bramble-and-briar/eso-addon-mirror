-- DevSandbox3SlotActions.lua: Track expected material slots (bundled HarvestMap data) and flag the ones with no node
--
-- Every 250 ms in Cyrodiil: expected slots within 200 m are compared with the engine's HARVEST_NODE compass pins.
--   present : a centred harvest pin sits at the slot's distance while the camera faces it
--   missing : the camera faced the slot (<= 150 m) for 400 ms and no harvest pin was there, OR the compass has
--             zero harvest pins in range at all while the slot is <= 120 m away
-- Missing slots persist in SavedVars (with a TTL), draw on the Cyrodiil map, and are listed by /ds3 empties.

local SlotActions = {}

local SlotUtils = DevSandbox3.SlotUtils
local NodeUtils = DevSandbox3.NodeUtils
local CompassUtils = DevSandbox3.CompassUtils
local PinUtils = DevSandbox3.PinUtils
local LogUtils = DevSandbox3.LogUtils

local POLL_UPDATE = DevSandbox3.name .. "_SlotPoll"
local MAP_UPDATE = DevSandbox3.name .. "_SlotMapRefresh"
local EXPIRE_UPDATE = DevSandbox3.name .. "_SlotExpire"

SlotActions.grid = nil
SlotActions.inRange = {}          -- DevSandbox3SlotHit[] from the latest poll
SlotActions.presentAt = {}        -- index -> frame ms the slot was last confirmed present
SlotActions.facingSince = {}      -- index -> frame ms the camera started facing an unpinned slot
SlotActions.normalized = {}       -- index -> { nx, ny } cache for map pins
SlotActions.activatedAt = 0
SlotActions.mapShowing = false
SlotActions.cameraControl = nil
SlotActions.centeredDistances = {}

local function GetSettings()
    return DevSandbox3.state.savedVars.settings
end

local function Expected()
    return DevSandbox3.ExpectedNodes
end

local function Empties()
    return DevSandbox3.state.savedVars.emptySlots
end

---@param index integer
---@return string
local function TypeNameOf(index)
    local _, _, _, typeName = SlotUtils.NodeAt(Expected(), index)
    return typeName
end

---Zone-normalized map position of an expected node (cached).
---@param index integer
---@return number nx
---@return number ny
local function NormalizedOf(index)
    local cached = SlotActions.normalized[index]
    if cached then return cached[1], cached[2] end
    local x, z, h = SlotUtils.NodeAt(Expected(), index)
    local nx, ny = GetNormalizedWorldPosition(NodeUtils.CYRODIIL_ZONE_ID, x * 100, h * 100, z * 100)
    SlotActions.normalized[index] = { nx, ny }
    return nx, ny
end

---@return number forwardX
---@return number forwardZ
local function CameraForward()
    local control = SlotActions.cameraControl
    Set3DRenderSpaceToCurrentCamera(control:GetName())
    local fx, _fy, fz = control:Get3DRenderSpaceForward()
    return fx, fz
end

---@return boolean
local function IsOnCyrodiilZoneMap()
    return GetMapType() == MAPTYPE_ZONE and GetZoneId(GetCurrentMapZoneIndex()) == NodeUtils.CYRODIIL_ZONE_ID
end

local function RefreshMapPins()
    LibMapPins:RefreshPins(DevSandbox3.expectedSlotPinType)
    LibMapPins:RefreshPins(DevSandbox3.emptySlotPinType)
end

-- ---------------------------------------------------------------- marking

---@param index integer
---@param method string
---@param dist number
local function MarkMissing(index, method, dist)
    local now = GetTimeStamp()
    local isNew, counted = SlotUtils.MarkEmpty(Empties(), index, method, dist, now)
    if not (isNew or counted) then return end
    local typeName = TypeNameOf(index)
    if GetSettings().logEmptySlots then
        LogUtils.Log("Expected %s node missing @ %dm (%s) - %s, %d flagged", typeName, math.floor(dist + 0.5),
            method == SlotUtils.METHOD_NO_PINS and "no harvest pins nearby" or "faced it, nothing there",
            isNew and "new" or ("seen " .. Empties()[index].emptyCount .. "x"), SlotUtils.CountEmpties(Empties()))
    end
    if isNew and GetSettings().alertOnEmptySlots then
        DevSandbox3.AlertActions.Show(string.format("Expected %s node missing", typeName), string.format("%dm", math.floor(dist + 0.5)), true)
    end
    if SlotActions.mapShowing then RefreshMapPins() end
end

---@param index integer
---@param nowMs integer
local function MarkPresent(index, nowMs)
    SlotActions.presentAt[index] = nowMs
    SlotActions.facingSince[index] = nil
    local empties = Empties()
    if empties[index] then
        LogUtils.Debug("slot %d (%s) has a node again - no longer missing", index, TypeNameOf(index))
        empties[index] = nil
        if SlotActions.mapShowing then RefreshMapPins() end
    end
end

-- ---------------------------------------------------------------- poll

local function Poll()
    local zoneId, pxCm, _pyCm, pzCm = GetUnitWorldPosition("player")
    if zoneId ~= NodeUtils.CYRODIIL_ZONE_ID then
        if #SlotActions.inRange > 0 then SlotActions.inRange = {} end
        return
    end
    local px, pz = pxCm / 100, pzCm / 100
    local expected, grid = Expected(), SlotActions.grid
    SlotActions.inRange = SlotUtils.QueryInRange(expected, grid, px, pz, SlotUtils.TRACK_RADIUS_METERS)
    if #SlotActions.inRange == 0 then return end

    local container = ZO_CompassContainer
    if container:IsHidden() then return end
    local nowMs = GetFrameTimeMilliseconds()
    if nowMs - SlotActions.activatedAt < SlotUtils.ACTIVATION_GRACE_MS then return end

    local fx, fz = CameraForward()
    local centered = SlotActions.centeredDistances
    for i = #centered, 1, -1 do centered[i] = nil end
    for i = 1, container:GetNumCenterOveredPins() do
        local _description, pinType, distanceCm = container:GetCenterOveredPinInfo(i)
        if pinType == CompassUtils.HARVEST_NODE_PIN_TYPE and distanceCm then
            local dist = distanceCm / 100
            centered[#centered + 1] = dist
            local index = SlotUtils.FindNearest(expected, grid, px + fx * dist, pz + fz * dist, SlotUtils.MATCH_TOLERANCE_METERS)
            if index then MarkPresent(index, nowMs) end
        end
    end

    local harvestPinsInRange = DevSandbox3.CompassActions.pinsInRangeByType[CompassUtils.HARVEST_NODE_PIN_TYPE] or 0
    local useNoPins = harvestPinsInRange == 0 and GetSettings().emptyByPinCount

    for _, hit in ipairs(SlotActions.inRange) do
        local index = hit.index
        if useNoPins and hit.dist <= SlotUtils.NO_PINS_RADIUS_METERS then
            MarkMissing(index, SlotUtils.METHOD_NO_PINS, hit.dist)
        elseif hit.dist <= SlotUtils.VERIFY_RADIUS_METERS
            and SlotUtils.BearingDelta(fx, fz, hit.dx, hit.dz) <= SlotUtils.FACING_TOLERANCE_DEGREES then
            if SlotUtils.IsCoveredByCenteredPin(centered, hit.dist) then
                MarkPresent(index, nowMs)
            else
                local since = SlotActions.facingSince[index]
                if not since then
                    SlotActions.facingSince[index] = nowMs
                elseif nowMs - since >= SlotUtils.FACING_DWELL_MS then
                    MarkMissing(index, SlotUtils.METHOD_FACING, hit.dist)
                    SlotActions.facingSince[index] = nowMs -- re-arm so a long stare doesn't spam MarkEmpty
                end
            end
        else
            SlotActions.facingSince[index] = nil
        end
    end
end

local function ExpireEmpties()
    local removed = SlotUtils.ExpireEmpties(Empties(), GetTimeStamp(), GetSettings().emptySlotTtlMinutes * 60)
    if removed > 0 then
        LogUtils.Debug("forgot %d missing slot(s) older than %d min", removed, GetSettings().emptySlotTtlMinutes)
        if SlotActions.mapShowing then RefreshMapPins() end
    end
end

-- ---------------------------------------------------------------- map pins

local function AddExpectedSlotPins()
    if not GetSettings().showExpectedSlots or not IsOnCyrodiilZoneMap() then return end
    local empties = Empties()
    for _, hit in ipairs(SlotActions.inRange) do
        if not empties[hit.index] and not SlotActions.presentAt[hit.index] then
            local nx, ny = NormalizedOf(hit.index)
            LibMapPins:CreatePin(DevSandbox3.expectedSlotPinType, hit.index, nx, ny)
        end
    end
end

local function AddEmptySlotPins()
    if not GetSettings().showEmptySlots or not IsOnCyrodiilZoneMap() then return end
    local empties = Empties()
    if GetSettings().showEmptySlotsOutOfRange then
        for index, entry in pairs(empties) do
            local nx, ny = NormalizedOf(index)
            LibMapPins:CreatePin(DevSandbox3.emptySlotPinType, entry, nx, ny)
        end
        return
    end
    -- Default: only the missing slots currently within compass range.
    for _, hit in ipairs(SlotActions.inRange) do
        local entry = empties[hit.index]
        if entry then
            local nx, ny = NormalizedOf(hit.index)
            LibMapPins:CreatePin(DevSandbox3.emptySlotPinType, entry, nx, ny)
        end
    end
end

---@param pin table ZO_MapPin
local function LayoutEmptyTooltip(pin)
    local _, entry = pin:GetPinTypeAndTag()
    if type(entry) ~= "table" or not entry.index then return end
    local lines = SlotUtils.DescribeEmpty(entry, TypeNameOf(entry.index), GetTimeStamp())
    if IsInGamepadPreferredMode() then
        local tooltip = ZO_MapLocationTooltip_Gamepad
        local section = tooltip.tooltip
        tooltip:LayoutIconStringLine(section, nil, lines[1], section:GetStyle("mapLocationTooltipContentName"))
        for i = 2, #lines do
            tooltip:LayoutIconStringLine(section, nil, lines[i], section:GetStyle("mapLocationTooltipContentHeader"))
        end
    else
        InformationTooltip:AddLine(lines[1], "", ZO_SELECTED_TEXT:UnpackRGB())
        for i = 2, #lines do
            InformationTooltip:AddLine(lines[i], "", ZO_NORMAL_TEXT:UnpackRGB())
        end
    end
end

local function OnMapStateChange(_oldState, newState)
    if newState == SCENE_SHOWING then
        SlotActions.mapShowing = true
        EVENT_MANAGER:RegisterForUpdate(MAP_UPDATE, SlotUtils.MAP_REFRESH_MS, RefreshMapPins)
        RefreshMapPins()
    elseif newState == SCENE_HIDDEN then
        SlotActions.mapShowing = false
        EVENT_MANAGER:UnregisterForUpdate(MAP_UPDATE)
    end
end

-- ---------------------------------------------------------------- public

---Nearest expected slot to the player (for loot attribution).
---@param maxMeters number
---@return integer|nil index
---@return number|nil dist
---@return string|nil typeName
function SlotActions.NearestSlotToPlayer(maxMeters)
    local zoneId, pxCm, _py, pzCm = GetUnitWorldPosition("player")
    if zoneId ~= NodeUtils.CYRODIIL_ZONE_ID or not SlotActions.grid then return nil, nil, nil end
    local index, dist = SlotUtils.FindNearest(Expected(), SlotActions.grid, pxCm / 100, pzCm / 100, maxMeters)
    if not index then return nil, nil, nil end
    return index, dist, TypeNameOf(index)
end

function SlotActions.ClearEmpties()
    DevSandbox3.state.savedVars.emptySlots = {}
    LogUtils.Log("Missing-slot candidates cleared")
    RefreshMapPins()
end

---@return integer
function SlotActions.CountEmpties()
    return SlotUtils.CountEmpties(Empties())
end

---/ds3 slots - one-line status.
function SlotActions.Status()
    local present, missing, unverified = 0, 0, 0
    local empties = Empties()
    for _, hit in ipairs(SlotActions.inRange) do
        if empties[hit.index] then missing = missing + 1
        elseif SlotActions.presentAt[hit.index] then present = present + 1
        else unverified = unverified + 1 end
    end
    local harvestPins = DevSandbox3.CompassActions.pinsInRangeByType[CompassUtils.HARVEST_NODE_PIN_TYPE] or 0
    LogUtils.Log("slots: %d expected nodes loaded (%s); %d within 200m: %d present, %d missing, %d unverified; compass harvest pins in range: %d; %d missing-slot candidate(s) saved",
        Expected().count, Expected().version, #SlotActions.inRange, present, missing, unverified, harvestPins, SlotUtils.CountEmpties(empties))
end

---/ds3 empties - nearest-first list.
function SlotActions.ListEmpties()
    local empties = Empties()
    local list = {}
    local zoneId, pxCm, _py, pzCm = GetUnitWorldPosition("player")
    local px, pz = pxCm / 100, pzCm / 100
    for index, entry in pairs(empties) do
        local x, z = SlotUtils.NodeAt(Expected(), index)
        local dist = zoneId == NodeUtils.CYRODIIL_ZONE_ID and math.sqrt((x - px) ^ 2 + (z - pz) ^ 2) or math.huge
        list[#list + 1] = { entry = entry, dist = dist }
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    LogUtils.Log("%d missing-slot candidate(s)", #list)
    local now = GetTimeStamp()
    for i = 1, math.min(#list, 15) do
        local item = list[i]
        local lines = SlotUtils.DescribeEmpty(item.entry, TypeNameOf(item.entry.index), now)
        LogUtils.Log("  %s - %s (%s)", item.dist < math.huge and string.format("%dm", math.floor(item.dist + 0.5)) or "?", lines[1], lines[2])
    end
end

function SlotActions.Initialize()
    local expected = Expected()
    if not expected or expected.count == 0 then
        LogUtils.Log("No expected-node data bundled - slot tracking disabled")
        return
    end
    local savedVars = DevSandbox3.state.savedVars
    if savedVars.emptySlotsVersion ~= expected.version then
        savedVars.emptySlots = {}
        savedVars.emptySlotsVersion = expected.version
    end
    SlotActions.grid = SlotUtils.BuildGrid(expected)
    SlotActions.cameraControl = CreateControl(DevSandbox3.name .. "_SlotCameraSpace", GuiRoot, CT_CONTROL)
    SlotActions.cameraControl:Create3DRenderSpace()

    local tooltipCreator = { creator = LayoutEmptyTooltip, tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION, gamepadSpacing = true }
    local pinSize = savedVars.settings.mapPinSize
    LibMapPins:AddPinType(DevSandbox3.expectedSlotPinType, AddExpectedSlotPins, nil, PinUtils.CreateExpectedSlotLayout(pinSize), nil)
    LibMapPins:AddPinType(DevSandbox3.emptySlotPinType, AddEmptySlotPins, nil, PinUtils.CreateEmptySlotLayout(pinSize), tooltipCreator)
    LibMapPins:AddPinFilter(DevSandbox3.emptySlotPinType, PinUtils.EMPTY_SLOT_FILTER_LABEL, nil, savedVars.filters)
    for _, pinType in ipairs({ DevSandbox3.expectedSlotPinType, DevSandbox3.emptySlotPinType }) do
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_PVE_MAPGROUP, true)
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_AVA_IMPERIAL_MAPGROUP, true)
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_BATTLEGROUND_MAPGROUP, true)
    end

    for _, sceneName in ipairs({ "worldMap", "gamepad_worldMap" }) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then scene:RegisterCallback("StateChange", OnMapStateChange) end
    end

    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_SlotActivated", EVENT_PLAYER_ACTIVATED, function()
        SlotActions.activatedAt = GetFrameTimeMilliseconds()
        SlotActions.presentAt = {}
        SlotActions.facingSince = {}
        ExpireEmpties()
    end)
    EVENT_MANAGER:RegisterForUpdate(POLL_UPDATE, SlotUtils.POLL_INTERVAL_MS, Poll)
    EVENT_MANAGER:RegisterForUpdate(EXPIRE_UPDATE, 60000, ExpireEmpties)
    LogUtils.Debug("slot tracking: %d expected nodes (%s)", expected.count, expected.version)
end

DevSandbox3.SlotActions = SlotActions
