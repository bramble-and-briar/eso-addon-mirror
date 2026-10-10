ZoneCompletionMap = ZoneCompletionMap or {}

local ADDON_NAME = "ZoneCompletionMap"
local addon = ZoneCompletionMap
local Completion = addon.Completion
local BlobScanner = addon.BlobScanner
local Overlay = addon.Overlay

local sv

local function IsTypeEnabled(completionType)
    return sv.types[completionType] ~= false
end

local function IsOverviewMap()
    local mapType = GetMapType()
    return mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC
end

local function Refresh()
    if not sv.enabled or not IsOverviewMap() then
        Overlay.Hide()
        return
    end

    local api = Completion.DefaultApi()
    local tinted = {}
    for _, blob in ipairs(BlobScanner.GetBlobs(GetCurrentMapId())) do
        -- Zones without any tracked activity (nil) stay untinted in both modes.
        local isComplete = Completion.IsZoneComplete(blob.zoneId, IsTypeEnabled, api)
        if isComplete ~= nil and isComplete ~= sv.invert then
            tinted[#tinted + 1] = blob
        end
    end
    Overlay.Show(tinted, sv.color)
end

local function PrintDebug()
    if not IsOverviewMap() then
        return
    end
    local api = Completion.DefaultApi()
    local blobs = BlobScanner.GetBlobs(GetCurrentMapId())
    d(zo_strformat(GetString(ZCM_DEBUG_HEADER), #blobs))
    for _, blob in ipairs(blobs) do
        local isComplete = Completion.IsZoneComplete(blob.zoneId, IsTypeEnabled, api)
        local status = GetString(isComplete and ZCM_DEBUG_COMPLETE or ZCM_DEBUG_INCOMPLETE)
        d(zo_strformat(GetString(ZCM_DEBUG_LINE), GetZoneNameById(blob.zoneId), blob.zoneId, status))
    end
end

-- Diagnostic: raw mouseover data of the current map, including hits the scanner
-- rejects (no texture, no zone). Optional filter matches the location name.
local function DescribeHit(locationName, texture, mapId)
    local zoneIndex = mapId and mapId ~= 0 and GetZoneIndexByMapId(mapId) or nil
    local zoneId = zoneIndex and zoneIndex ~= 0 and GetZoneId(zoneIndex) or nil
    local storyZoneId = zoneId and zoneId ~= 0 and GetZoneStoryZoneIdForZoneId(zoneId) or nil
    return string.format("%s | mapId=%s zoneIndex=%s zoneId=%s storyZoneId=%s | %s",
        tostring(locationName), tostring(mapId), tostring(zoneIndex), tostring(zoneId),
        tostring(storyZoneId), tostring(texture))
end

local function PrintRaw(filter)
    local function matches(name)
        return filter == "" or zo_strlower(name or ""):find(zo_strlower(filter), 1, true) ~= nil
    end

    d("-- labels --")
    for i = 1, GetNumMapBlobs() do
        local labelName, nx, ny = GetMapBlobNameInfo(i)
        local locationName, texture, _, _, _, _, mapId = GetMapMouseoverInfo(nx, ny)
        if matches(labelName) or matches(locationName) then
            d(string.format("[%s @ %.3f,%.3f] %s", tostring(labelName), nx or -1, ny or -1,
                DescribeHit(locationName, texture, mapId)))
        end
    end

    d("-- grid --")
    local counts, order = {}, {}
    for row = 1, 50 do
        for col = 1, 50 do
            local locationName, texture, _, _, _, _, mapId = GetMapMouseoverInfo((col - 0.5) / 50, (row - 0.5) / 50)
            local key = tostring(locationName) .. "|" .. tostring(texture) .. "|" .. tostring(mapId)
            if not counts[key] then
                counts[key] = 0
                order[#order + 1] = { key = key, name = locationName, texture = texture, mapId = mapId }
            end
            counts[key] = counts[key] + 1
        end
    end
    for _, hit in ipairs(order) do
        if matches(hit.name) then
            d(string.format("x%d %s", counts[hit.key], DescribeHit(hit.name, hit.texture, hit.mapId)))
        end
    end
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("ZoneCompletionMap_SV", 1, nil, addon.Settings.DEFAULTS)
    addon.Settings.Init(sv, Refresh)

    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", Refresh)
    WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            Refresh()
        end
    end)

    SLASH_COMMANDS["/zcm"] = function(args)
        if args == "debug" then
            PrintDebug()
        elseif args:sub(1, 3) == "raw" then
            PrintRaw(zo_strtrim(args:sub(4)))
        end
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
