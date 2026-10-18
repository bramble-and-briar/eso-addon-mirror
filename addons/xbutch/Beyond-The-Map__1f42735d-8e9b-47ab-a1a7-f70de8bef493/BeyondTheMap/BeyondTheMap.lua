BTM = {
    name = "BeyondTheMap",
}

local PIN_TYPE = "BTM_UNKNOWN_POI"
local FILTER_KEY = "BTM_UNKNOWN_POIS"
local FALLBACK_ICON = "EsoUI/Art/Icons/poi/poi_areaofinterest_incomplete.dds"
local UPDATE_NAME = BTM.name .. "_Pins"
local SLICE_INTERVAL_MS = 16
local SLICE_TARGET_MS = 2
local MAX_POIS_PER_SLICE = 16
local CPU_RESERVE_MS = 20
local installedPanels = {}
local pinManager
local pinTypeId
local playerActive = false
local updatePending = false
local scan
local lastSliceFrame
local RefreshPins

local function IsSupportedMap()
    local mapType = GetMapType()
    if mapType ~= MAPTYPE_ZONE and mapType ~= MAPTYPE_SUBZONE then
        return false
    end

    local filterType = GetMapFilterType()
    return filterType == MAP_FILTER_TYPE_STANDARD
        or filterType == MAP_FILTER_TYPE_AVA_CYRODIIL
        or filterType == MAP_FILTER_TYPE_AVA_IMPERIAL
end

local function CanShowPins()
    return playerActive and IsSupportedMap()
        and pinManager:IsCustomPinEnabled(pinTypeId)
        and ZO_WorldMap_IsPinGroupShown(FILTER_KEY)
        and GetCurrentMapZoneIndex() > 0
end

local function HasCPUBudget()
    if GetTotalUserAddOnCPUTimeAvailableEachFrameMS and GetTotalUserAddOnCPUTimeUsedNowMS then
        local available = GetTotalUserAddOnCPUTimeAvailableEachFrameMS()
        if available > 0 then
            return GetTotalUserAddOnCPUTimeUsedNowMS() + CPU_RESERVE_MS < available
        end
    end
    return true
end

local function CancelScan(clearPins)
    if updatePending then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        updatePending = false
    end
    scan = nil
    if clearPins then
        pinManager:RemovePins(PIN_TYPE)
    end
end

local function IsCurrentScan(job)
    return scan == job and job.mapId == GetCurrentMapId()
        and job.floor == GetMapFloorInfo()
        and job.zoneIndex == GetCurrentMapZoneIndex()
        and job.filterType == GetMapFilterType()
        and job.mode == WORLD_MAP_MANAGER:GetMode()
end

local function AddUnknownPOI(job, poiIndex)
    local zoneIndex = job.zoneIndex
    if GetPOIType(zoneIndex, poiIndex) ~= POI_TYPE_HOUSE then
        local x, y, _, icon, isShownOnMap, _, isDiscovered = GetPOIMapInfo(zoneIndex, poiIndex)
        if not isDiscovered and isShownOnMap
            and x >= 0 and x <= 1 and y >= 0 and y <= 1
            and (x > 0 or y > 0)
            and not pinManager:FindPin("poi", zoneIndex, poiIndex) then
            local name = GetPOIInfo(zoneIndex, poiIndex)
            if name and name ~= "" then
                -- A native API can consume the remaining budget or fire a map
                -- callback. Retry this POI next frame instead of losing it.
                if not IsCurrentScan(job) or not HasCPUBudget() then
                    return false
                end
                pinManager:CreatePin(pinTypeId, {
                    name = name,
                    texture = icon and icon ~= "" and icon or FALLBACK_ICON,
                }, x, y)
            end
        end
    end
    return scan == job
end

local function ProcessSlice()
    if not updatePending then
        return
    end
    if not CanShowPins() then
        CancelScan(true)
        return
    end

    local frame = GetFrameTimeMilliseconds()
    if lastSliceFrame == frame then
        return
    end
    lastSliceFrame = frame

    local job = scan
    if job and not IsCurrentScan(job) then
        CancelScan(true)
        RefreshPins()
        return
    end
    if not HasCPUBudget() then
        return
    end

    local started = GetGameTimeMilliseconds()
    if not job then
        job = {
            zoneIndex = GetCurrentMapZoneIndex(),
            mapId = GetCurrentMapId(),
            floor = GetMapFloorInfo(),
            filterType = GetMapFilterType(),
            mode = WORLD_MAP_MANAGER:GetMode(),
            nextIndex = 1,
        }
        scan = job
        pinManager:RemovePins(PIN_TYPE)
        job.count = GetNumPOIs(job.zoneIndex)
    end

    local processed = 0
    while scan == job and job.nextIndex <= job.count and processed < MAX_POIS_PER_SLICE
        and GetGameTimeMilliseconds() - started < SLICE_TARGET_MS and HasCPUBudget() do
        if not AddUnknownPOI(job, job.nextIndex) then
            return
        end
        job.nextIndex = job.nextIndex + 1
        processed = processed + 1
    end
    if scan == job and job.nextIndex > job.count then
        CancelScan(false)
    end
end

RefreshPins = function()
    -- Coalesce native layout callbacks and POI events before doing any scans.
    -- Invalidating an active scan also revisits POIs changed behind its cursor.
    scan = nil
    if not CanShowPins() then
        CancelScan(true)
    elseif not updatePending then
        updatePending = true
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, SLICE_INTERVAL_MS, ProcessSlice)
    end
end

local function OnMapChanged()
    CancelScan(true)
    RefreshPins()
end

local function OnPlayerActivated()
    playerActive = true
    RefreshPins()
end

local function OnPlayerDeactivated()
    playerActive = false
    CancelScan(true)
end

local function AddFilterControl(panel)
    if not panel:FindCheckBox(pinTypeId) then
        panel:AddPinFilterCheckBox(pinTypeId, RefreshPins)
    end
end

local function InstallFilterPanel(panel)
    if not panel or installedPanels[panel] then
        return
    end
    installedPanels[panel] = true

    -- Native checkbox labels require a numeric group, but custom pin IDs can
    -- change with addon load order. Persist the value under our stable key.
    local getPinFilter = panel.GetPinFilter
    panel.GetPinFilter = function(self, group)
        return getPinFilter(self, group == pinTypeId and FILTER_KEY or group)
    end
    local setPinFilter = panel.SetPinFilter
    panel.SetPinFilter = function(self, group, shown)
        setPinFilter(self, group == pinTypeId and FILTER_KEY or group, shown)
        if group == pinTypeId or group == MAP_FILTER_OBJECTIVES then
            RefreshPins()
        end
    end

    -- Gamepad lists must receive the entry before PostBuildControls commits them.
    ZO_PreHook(panel, "PostBuildControls", AddFilterControl)
    if panel.list then
        panel:BuildControls()
    else
        AddFilterControl(panel)
        if panel.modeVars then
            panel:LoadInitialState()
        end
    end
end

local function InstallMapFilters()
    for _, filterName in ipairs({ "WORLD_MAP_FILTERS", "GAMEPAD_WORLD_MAP_FILTERS" }) do
        local filters = _G[filterName]
        if filters then
            InstallFilterPanel(filters.pvePanel)
            InstallFilterPanel(filters.pvpPanel)
            InstallFilterPanel(filters.imperialPvPPanel)
        end
    end
end

local function ShowTooltip(pin)
    local _, tag = pin:GetPinTypeAndTag()
    local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, tag.name)
    if IsInGamepadPreferredMode() then
        local tooltip = ZO_MapLocationTooltip_Gamepad
        local section = tooltip.tooltip
        tooltip:LayoutIconStringLine(section, nil, name, section:GetStyle("mapLocationTooltipContentName"))
    else
        SetTooltipText(InformationTooltip, name)
    end
end

local function OnPOIChanged(_, zoneIndex)
    if zoneIndex == GetCurrentMapZoneIndex() then
        RefreshPins()
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= BTM.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(BTM.name, EVENT_ADD_ON_LOADED)

    pinManager = ZO_WorldMap_GetPinManager()
    playerActive = IsPlayerActivated()
    local nativeLayout = ZO_MapPin.PIN_DATA[MAP_PIN_TYPE_POI_SEEN]
    pinManager:AddCustomPin(PIN_TYPE, RefreshPins, nil, {
        level = nativeLayout.level - 1,
        size = nativeLayout.size,
        texture = function(pin)
            local _, tag = pin:GetPinTypeAndTag()
            return tag.texture
        end,
        hitInsetX = nativeLayout.hitInsetX,
        hitInsetY = nativeLayout.hitInsetY,
    }, {
        creator = ShowTooltip,
        tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
    })
    pinTypeId = _G[PIN_TYPE]
    pinManager:SetCustomPinEnabled(pinTypeId, true)

    -- A stable string key lets ESO save this filter with its own map settings.
    ZO_CreateStringId("SI_MAPFILTER" .. pinTypeId, "Unknown POIs")
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapSavedVarsReady", InstallMapFilters)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", OnMapChanged)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapModeChanged", RefreshPins)
    InstallMapFilters()

    -- Native nearby pins can appear or disappear when Show Details is toggled.
    ZO_PostHook("ZO_WorldMap_RefreshAllPOIs", RefreshPins)
    EVENT_MANAGER:RegisterForEvent(BTM.name, EVENT_POI_DISCOVERED, OnPOIChanged)
    EVENT_MANAGER:RegisterForEvent(BTM.name, EVENT_POI_UPDATED, OnPOIChanged)
    EVENT_MANAGER:RegisterForEvent(BTM.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(BTM.name, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
    RefreshPins()
end

EVENT_MANAGER:RegisterForEvent(BTM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
