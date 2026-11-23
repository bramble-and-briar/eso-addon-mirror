local AH = _G.MarkTrialHelper
ZO_CreateStringId("SI_BINDING_NAME_MARKTRIALHELPER_SKYSHARD_ROUTE", "Маршрут по несобранным скайшардам зоны")
ZO_CreateStringId("SI_BINDING_NAME_MARKTRIALHELPER_SKYSHARD_NEXT", "Следующий скайшард в маршруте")

local activeRoute, activeZoneId, currentStep, lineControls = nil, nil, 0, {}
local checkTimerName = "MarkTrialHelper_SkyshardWatch"
local DUMB_ZONE_FIX = { ["1160"] = 1160, ["1207"] = 1207, ["1413"] = 1413, ["1011"] = 1011, ["1286"] = 1286 }
local EXTRA_ZONE_SHARDS = {
    ["1502"] = {
        { x = 0.514, y = 0.429, skyshardId = 569 }, { x = 0.476, y = 0.711, skyshardId = 570 },
        { x = 0.272, y = 0.454, skyshardId = 571 }, { x = 0.309, y = 0.595, skyshardId = 572 },
        { x = 0.724, y = 0.686, skyshardId = 587 }, { x = 0.733, y = 0.572, skyshardId = 578 },
        { x = 0.659, y = 0.366, skyshardId = 579 }, { x = 0.619, y = 0.505, skyshardId = 580 },
    }
}

local function GetLineControl(idx)
    if not lineControls[idx] then
        local line = WINDOW_MANAGER:CreateControlFromVirtual("MarkTrialHelper_SkyLine_" .. idx, ZO_WorldMapContainer, "HarvestLink")
        line:SetDrawTier(DT_HIGH)
        line:SetDrawLayer(DL_OVERLAY)
        lineControls[idx] = line
    end
    return lineControls[idx]
end

local function ClearRouteLines()
    for _, line in pairs(lineControls) do line:SetHidden(true) end
end

local function GetUnlockedWayshrines()
    local list = {}
    for i = 1, GetNumFastTravelNodes() do
        local known, name, x, y, _, _, poiType, isShown = GetFastTravelNodeInfo(i)
        if known and isShown and poiType == POI_TYPE_WAYSHRINE and x > 0 and x < 1 and y > 0 and y < 1 then
            table.insert(list, { name = zo_strformat("<<1>>", name), x = x, y = y })
        end
    end
    return list
end

local function FindBestWayshrine(targetX, targetY, fromX, fromY, wayshrines)
    if AH.Vars and AH.Vars.SkyshardUseWayshrines == false then return nil end
    local bestWs, bestWsDist = nil, math.sqrt((targetX - fromX)^2 + (targetY - fromY)^2)
    for _, ws in ipairs(wayshrines) do
        local d = math.sqrt((targetX - ws.x)^2 + (targetY - ws.y)^2)
        if d * 1.4 < bestWsDist then bestWsDist, bestWs = d, ws end
    end
    return bestWs
end

local function DrawRouteLines()
    ClearRouteLines()
    if not activeRoute or not activeRoute[currentStep] then return end
    local currentZone = GetZoneId(GetCurrentMapZoneIndex())
    currentZone = DUMB_ZONE_FIX[tostring(currentZone)] or currentZone
    if currentZone ~= activeZoneId or GetMapType() == MAPTYPE_SUBZONE then return end
    local mapW, mapH = ZO_WorldMapContainer:GetDimensions()
    if not mapW or mapW <= 0 then return end

    local lineIdx, target = 0, activeRoute[currentStep]
    local px, py = GetMapPlayerPosition("player")

    if target.wayshrine and ((px > 0 and py > 0 and math.sqrt((px - target.wayshrine.x)^2 + (py - target.wayshrine.y)^2) > 0.03) or px <= 0) then
        lineIdx = lineIdx + 1
        local wsLine = GetLineControl(lineIdx)
        wsLine:SetColor(1.0, 0.8, 0.1, 0.95)
        wsLine:SetHidden(false)
        ZO_Anchor_LineInContainer(wsLine, nil, target.wayshrine.x * mapW, target.wayshrine.y * mapH, target.x * mapW, target.y * mapH, 3)
    elseif px > 0 and py > 0 then
        lineIdx = lineIdx + 1
        local pLine = GetLineControl(lineIdx)
        pLine:SetColor(0.2, 0.9, 1.0, 0.95)
        pLine:SetHidden(false)
        ZO_Anchor_LineInContainer(pLine, nil, px * mapW, py * mapH, target.x * mapW, target.y * mapH, 3)
    end

    for i = currentStep, #activeRoute - 1 do
        local p1, p2 = activeRoute[i], activeRoute[i + 1]
        lineIdx = lineIdx + 1
        local line = GetLineControl(lineIdx)
        line:SetColor(0.2, 0.9, 1.0, 0.75)
        line:SetHidden(false)
        ZO_Anchor_LineInContainer(line, nil, p1.x * mapW, p1.y * mapH, p2.x * mapW, p2.y * mapH, 3)
    end
end

local function EnsureZoneMap()
    SetMapToPlayerLocation()
    if GetMapType() == MAPTYPE_SUBZONE then MapZoomOut() end
    local zoneId = GetZoneId(GetCurrentMapZoneIndex())
    return DUMB_ZONE_FIX[tostring(zoneId)] or zoneId
end

local function SetWaypointToShard(shard)
    if not shard then return end
    PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, shard.x, shard.y)
    DrawRouteLines()
    if shard.wayshrine then
        d(string.format("|cff9900[Mark Trial Helper]|r Скайшард %d/%d: ближе через святилище |cffe066%s|r", currentStep, #activeRoute, shard.wayshrine.name))
    else
        d(string.format("|cff9900[Mark Trial Helper]|r Скайшард %d/%d: метка установлена (%.1f, %.1f)", currentStep, #activeRoute, shard.x * 100, shard.y * 100))
    end
end

function AH.StopSkyshardRoute(silent)
    EVENT_MANAGER:UnregisterForUpdate(checkTimerName)
    activeRoute, activeZoneId, currentStep = nil, nil, 0
    ClearRouteLines()
    if not silent then d("|cff9900[Mark Trial Helper]|r Маршрут по скайшардам остановлен.") end
end

function AH.NextSkyshard()
    if not activeRoute or not activeRoute[currentStep] then d("|cff9900[Mark Trial Helper]|r Маршрут не запущен. Введите /skyroute") return end
    currentStep = currentStep + 1
    if activeRoute[currentStep] then EnsureZoneMap(); SetWaypointToShard(activeRoute[currentStep])
    else d("|cff9900[Mark Trial Helper]|r |c00ff00Все открытые скайшарды пройдены!|r"); AH.StopSkyshardRoute(true) end
end

local function CheckPlayerProgress()
    if not activeRoute or not activeRoute[currentStep] then AH.StopSkyshardRoute(true) return end
    local target = activeRoute[currentStep]
    local px, py = GetMapPlayerPosition("player")
    if GetSkyshardDiscoveryStatus(target.skyshardId) == 2 or math.sqrt((px - target.x)^2 + (py - target.y)^2) < 0.012 then AH.NextSkyshard()
    else DrawRouteLines() end
end

function AH.StartSkyshardRoute()
    local zoneId = EnsureZoneMap()
    local uncollected, seenIds = {}, {}
    for idx = 1, 30 do
        local sid = GetZoneSkyshardId(zoneId, idx)
        if not sid or sid == 0 then break end
        seenIds[sid] = true
        if GetSkyshardDiscoveryStatus(sid) ~= 2 then
            local x, y = GetNormalizedPositionForSkyshardId(sid)
            if x and y and x > 0 and x < 1 and y > 0 and y < 1 then table.insert(uncollected, { x = x, y = y, skyshardId = sid }) end
        end
    end
    local extra = EXTRA_ZONE_SHARDS[tostring(zoneId)]
    if extra then
        for _, item in ipairs(extra) do
            if not seenIds[item.skyshardId] and GetSkyshardDiscoveryStatus(item.skyshardId) ~= 2 then
                table.insert(uncollected, { x = item.x, y = item.y, skyshardId = item.skyshardId })
            end
        end
    end
    if #uncollected == 0 then d("|cff9900[Mark Trial Helper]|r |c00ff00На поверхности этой зоны нет несобранных скайшардов.|r") return end

    local wayshrines = GetUnlockedWayshrines()
    local curX, curY = GetMapPlayerPosition("player")
    if curX <= 0 or curY <= 0 then curX, curY = 0.5, 0.5 end
    local sorted = {}
    while #uncollected > 0 do
        local bestIdx, bestEff, bestWs = 1, 999999, nil
        for i, s in ipairs(uncollected) do
            local ws = FindBestWayshrine(s.x, s.y, curX, curY, wayshrines)
            local eff = ws and (math.sqrt((s.x - ws.x)^2 + (s.y - ws.y)^2) * 1.15) or math.sqrt((s.x - curX)^2 + (s.y - curY)^2)
            if eff < bestEff then bestEff, bestIdx, bestWs = eff, i, ws end
        end
        local nextShard = table.remove(uncollected, bestIdx)
        nextShard.wayshrine = bestWs
        table.insert(sorted, nextShard)
        curX, curY = nextShard.x, nextShard.y
    end

    activeRoute, activeZoneId, currentStep = sorted, zoneId, 1
    d(string.format("|cff9900[Mark Trial Helper]|r Построен маршрут по |c00ff00%d|r открытым скайшардам зоны.", #activeRoute))
    SetWaypointToShard(activeRoute[currentStep])
    EVENT_MANAGER:UnregisterForUpdate(checkTimerName)
    EVENT_MANAGER:RegisterForUpdate(checkTimerName, 1000, CheckPlayerProgress)
end

ZO_PreHook(ZO_WorldMapContainer, "SetDimensions", function() if activeRoute then zo_callLater(DrawRouteLines, 10) end end)
CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function() DrawRouteLines() end)
SLASH_COMMANDS["/skyroute"] = function() AH.StartSkyshardRoute() end
SLASH_COMMANDS["/skynext"]  = function() AH.NextSkyshard() end
SLASH_COMMANDS["/skystop"]  = function() AH.StopSkyshardRoute(false) end