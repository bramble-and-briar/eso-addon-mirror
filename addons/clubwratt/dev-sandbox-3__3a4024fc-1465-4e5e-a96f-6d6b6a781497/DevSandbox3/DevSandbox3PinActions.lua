-- DevSandbox3PinActions.lua: LibMapPins registration and pin population

local PinActions = {}

local PinUtils = DevSandbox3.PinUtils
local LogUtils = DevSandbox3.LogUtils

---LibMapPins add-callback: place a pin for every saved node that falls on the current map.
---@param wantCandidates boolean
local function AddPinsForCurrentMap(wantCandidates)
    local state = DevSandbox3.state
    if not state then return end

    local zoneId = GetZoneId(GetCurrentMapZoneIndex())
    if not PinUtils.ShouldShowOnMap(GetMapType(), zoneId) then
        return
    end

    local gps = LibGPS3
    for _, node in ipairs(state.savedVars.nodes) do
        if (node.candidate == true) == wantCandidates then
            local lx, ly = gps:GlobalToLocal(node.gx, node.gy)
            if PinUtils.IsOnCurrentMap(lx, ly) then
                LibMapPins:CreatePin(wantCandidates and DevSandbox3.candidatePinType or DevSandbox3.pinType, node, lx, ly)
            end
        end
    end
end

local function AddConfirmedPins() AddPinsForCurrentMap(false) end
local function AddCandidatePins() AddPinsForCurrentMap(true) end

---Tooltip creator (gamepad + keyboard aware, mirrors LibMapPins' own helper).
---@param pin table ZO_MapPin
local function LayoutTooltip(pin)
    local _, node = pin:GetPinTypeAndTag()
    if type(node) ~= "table" then return end
    local lines = PinUtils.BuildTooltipLines(node, GetTimeStamp())

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

function PinActions.RegisterPinType()
    local state = DevSandbox3.state
    local tooltipCreator = {
        creator = LayoutTooltip,
        tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
        gamepadSpacing = true,
    }

    state.pinTypeId = LibMapPins:AddPinType(DevSandbox3.pinType, AddConfirmedPins, nil, PinUtils.CreateLayout(false), tooltipCreator)
    LibMapPins:AddPinFilter(DevSandbox3.pinType, PinUtils.FILTER_LABEL, nil, state.savedVars.filters)
    state.candidatePinTypeId = LibMapPins:AddPinType(DevSandbox3.candidatePinType, AddCandidatePins, nil, PinUtils.CreateLayout(true), tooltipCreator)
    LibMapPins:AddPinFilter(DevSandbox3.candidatePinType, PinUtils.CANDIDATE_FILTER_LABEL, nil, state.savedVars.filters)

    -- Only the Cyrodiil (AvA) map filter list is relevant for these pins.
    for _, pinType in ipairs({ DevSandbox3.pinType, DevSandbox3.candidatePinType }) do
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_PVE_MAPGROUP, true)
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_AVA_IMPERIAL_MAPGROUP, true)
        LibMapPins:SetPinFilterHidden(pinType, LIBMAPPINS_BATTLEGROUND_MAPGROUP, true)
    end

    LogUtils.Debug("pin type registered as id %s", tostring(state.pinTypeId))
end

function PinActions.RefreshPins()
    local state = DevSandbox3.state
    if state and state.pinTypeId then
        LibMapPins:RefreshPins(DevSandbox3.pinType)
    end
    if state and state.candidatePinTypeId then
        LibMapPins:RefreshPins(DevSandbox3.candidatePinType)
    end
end

DevSandbox3.PinActions = PinActions
