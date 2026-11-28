local addon = ShadowStrikerrWaypointPathfinder
local name = "WaypointPathfinder"
local active, target, arrived, recording, placementMap
local placedWayshrine
local waypointOutline, outlinedControl
local autoCandidates, autoMap, autoZone, nextAutoScan
local ground, nextMapSync = {}, 0
local selectedRoute, autoRoutes = {}, {}
local status = "Waiting for player"
local settings
local mapTooltipsRegistered
local hoveredWayshrine
local trailColors = {
    near = { 1, 219 / 255, 112 / 255 },
    middle = { 1, 149 / 255, 78 / 255 },
    far = { 1, 112 / 255, 159 / 255 },
}
local previousTrailColors = {
    near = { 0, 229 / 255, 224 / 255 },
    middle = { 56 / 255, 141 / 255, 1 },
    far = { 176 / 255, 96 / 255, 1 },
}

local function finite(value)
    return type(value) == "number" and math.abs(value) < math.huge
end

local function inside(u, v)
    return finite(u) and finite(v) and u > 0 and u < 1 and v > 0 and v < 1
end

local function isFollowingMapWaypoint()
    return active and not settings.paused and not settings.collapsed and not arrived
        and ZO_WorldMap_IsWorldMapShowing()
end

local function registerMapTooltips()
    local wayshrineHeader, nativeWayshrine, nativeTravelTooltip
    local function observeTravelPin(pin)
        local node = pin:GetFastTravelNodeIndex()
        if node then
            nativeTravelTooltip = true
            if (GetFastTravelNodeHouseId(node) or 0) == 0
                and select(7, GetFastTravelNodeInfo(node)) ~= POI_TYPE_HOUSE then
                nativeWayshrine = true
            end
        end
    end
    -- Add-ons can replace the creator and render undiscovered wayshrines themselves.
    local creators = ZO_MapPin.TOOLTIP_CREATORS
    local wayshrine = creators[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE]
    local currentLocation = creators[MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC]
    if wayshrine then SecurePostHook(wayshrine, "creator", observeTravelPin) end
    if currentLocation and currentLocation ~= wayshrine then
        SecurePostHook(currentLocation, "creator", observeTravelPin)
    end
    ZO_PostHook(InformationTooltip, "AppendWayshrineTooltip", function(_, pin)
        observeTravelPin(pin)
    end)
    -- ESO's wayshrine tooltip sets this header while composing its native lines.
    -- Remember that signal even if an overlapping pin changes the header later.
    SecurePostHook(WORLD_MAP_MANAGER, "SetMapHeader", function(_, header)
        if header.owner == "fastTravelWayshrine" then wayshrineHeader = true end
    end)
    SecurePostHook(WORLD_MAP_MANAGER, "UpdatePinTooltips", function(manager)
        local hasWayshrine = nativeWayshrine or (not nativeTravelTooltip and wayshrineHeader)
        wayshrineHeader, nativeWayshrine, nativeTravelTooltip = nil, nil, nil
        if not active or IsInGamepadPreferredMode() or not ZO_WorldMap_IsWorldMapShowing() then return end
        local map = GetCurrentMapId()
        local selectedNode = (placementMap == map and placedWayshrine and placedWayshrine.node)
            or (target and target.map == map and target.wayshrineNode)
        local selectedName = selectedNode and select(2, GetFastTravelNodeInfo(selectedNode))
        if selectedName then selectedName = zo_strformat(SI_WORLD_MAP_LOCATION_NAME, selectedName) end
        local hasWaypoint, hasSelectedWayshrine
        for _, pin in ipairs(manager.foundTooltipMouseOverPins) do
            if pin:GetPinType() == MAP_PIN_TYPE_PLAYER_WAYPOINT then
                hasWaypoint = true
            elseif pin:IsFastTravelWayShrine() then
                local node = pin:GetFastTravelNodeIndex()
                if node and (GetFastTravelNodeHouseId(node) or 0) == 0 then
                    hasWayshrine = true
                    if node == selectedNode then hasSelectedWayshrine = true end
                end
            elseif pin:IsPOI() and pin:GetPOIType() == POI_TYPE_WAYSHRINE then
                hasWayshrine = true
                if selectedNode then
                    local zone, poi = GetFastTravelNodePOIIndicies(selectedNode)
                    if zone == pin:GetPOIZoneIndex() and poi == pin:GetPOIIndex() then
                        hasSelectedWayshrine = true
                    end
                end
            elseif Destinations and pin.GetPinTypeAndTag then
                local _, tag = pin:GetPinTypeAndTag()
                -- Destinations uses type 33 for wayshrines on its custom undiscovered pins.
                if type(tag) == "table" and tag.newFormat and tag.destinationsPinType == 33
                    and tag.objectiveName then
                    hasWayshrine = true
                    if tag.objectiveName == selectedName then hasSelectedWayshrine = true end
                end
            end
        end
        local hoveredNode = hoveredWayshrine()
        if hoveredNode and hoveredNode == selectedNode then hasSelectedWayshrine = true end
        local tooltip = ZO_WorldMap_GetTooltipForMode(ZO_MAP_TOOLTIP_MODE.INFORMATION)
        hasWayshrine = hasWayshrine or hoveredNode ~= nil
        -- The map destination stays selected when HUD guidance is paused or hidden.
        if hasSelectedWayshrine or hasWaypoint then
            tooltip:AddLine("WayShrine Pathfinder · Following", "ZoFontGame", .96, .82, .47)
        elseif hasWayshrine and not hasSelectedWayshrine then
            tooltip:AddLine("WayShrine Pathfinder - Click F to set target", "ZoFontGame", .65, .87, .9)
        end
    end)
end

local function updateWaypointOutline(show)
    local control
    if show then
        local pin = ZO_WorldMap_GetPinManager():FindPin("pings", MAP_PIN_TYPE_PLAYER_WAYPOINT)
        control = pin and pin:GetControl()
    end
    if not control or control:IsHidden() then
        if waypointOutline then waypointOutline:SetHidden(true) end
        return
    end
    if not waypointOutline then
        waypointOutline = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
        waypointOutline:SetMouseEnabled(false)
        waypointOutline:SetDrawLayer(DL_OVERLAY)
        waypointOutline:SetCenterColor(0, 0, 0, 0)
        waypointOutline:SetEdgeTexture(nil, 1, 1, 2)
        waypointOutline:SetEdgeColor(.96, .82, .47, 1)
    end
    if outlinedControl ~= control then
        outlinedControl = control
        waypointOutline:SetParent(control)
        waypointOutline:ClearAnchors()
        waypointOutline:SetAnchor(TOPLEFT, control, TOPLEFT, -3, -3)
        waypointOutline:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 3, 3)
    end
    waypointOutline:SetHidden(false)
end

local function wayshrineNodeFromPin(pin)
    if pin:IsFastTravelWayShrine() then
        local node = pin:GetFastTravelNodeIndex()
        if node and (GetFastTravelNodeHouseId(node) or 0) == 0 then return node end
    elseif pin:IsPOI() and pin:GetPOIType() == POI_TYPE_WAYSHRINE then
        local zone, poi = pin:GetPOIZoneIndex(), pin:GetPOIIndex()
        for node = 1, GetNumFastTravelNodes() do
            local nodeZone, nodePOI = GetFastTravelNodePOIIndicies(node)
            if nodeZone == zone and nodePOI == poi then return node end
        end
    end
end

hoveredWayshrine = function()
    if not settings or IsInGamepadPreferredMode() or not ZO_WorldMap_IsMouseOverMap() then return end
    local mapType = GetMapType()
    if mapType ~= MAPTYPE_ZONE and mapType ~= MAPTYPE_SUBZONE then return end

    local mouseX, mouseY = GetUIMousePosition()
    local node
    for pin, hovered in pairs(ZO_WorldMap_GetPinManager():GetCurrentMouseOverPins()) do
        if hovered and pin:MouseIsOver(mouseX, mouseY) then
            local index = wayshrineNodeFromPin(pin)
            if index then
                if node and node ~= index then
                    return nil, true
                end
                node = index
            end
        end
    end
    return node
end

function addon.TargetHoveredWayshrine()
    local node, ambiguous = hoveredWayshrine()
    if ambiguous then d("[WayShrine Pathfinder] Wayshrines overlap here. Zoom in and try again.") end
    if not node then return end
    local _, _, u, v, _, _, kind, shown = GetFastTravelNodeInfo(node)
    if shown and kind == POI_TYPE_WAYSHRINE and inside(u, v) then
        PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, u, v)
    end
end

local function readPlacedWayshrine(u, v)
    if not inside(u, v) then return end
    local node = hoveredWayshrine()
    if not node then return end
    local mouseU, mouseV = NormalizeMousePositionToControl(ZO_WorldMapContainer)
    local dx = (u - mouseU) * ZO_WorldMapContainer:GetWidth()
    local dy = (v - mouseV) * ZO_WorldMapContainer:GetHeight()
    if dx * dx + dy * dy > 12 ^ 2 then return end
    local _, name = GetFastTravelNodeInfo(node)
    if name and name ~= "" then
        return { map = GetCurrentMapId(), u = u, v = v, node = node, name = zo_strformat(SI_TOOLTIP_UNIT_NAME, name) }
    end
end

local function rememberWayshrine(association)
    placedWayshrine = association
    settings.lastWayshrineWaypoint = association
end

local function clearRoute()
    selectedRoute = {}
end

local function stopMotion()
    ground, recording = {}, nil
    clearRoute()
    autoRoutes = {}
end

local function buildTrail(player, destination, seconds, state, continueDirect)
    local trail = addon.GetDirectTrail(player, destination, seconds, ground)
    trail.target = destination
    trail.routeStatus = "Direct bearing (unverified)"
    if settings.followWalkedPaths then
        local upcoming = state.route and addon.AdvanceWalkedPath(state.route, player)
        if not upcoming and seconds >= (state.nextSearch or 0) then
            state.nextSearch = seconds + .5
            state.route = addon.FindWalkedPath(settings.walkedPaths, player, destination, seconds)
            upcoming = state.route and addon.AdvanceWalkedPath(state.route, player)
        end
        if upcoming then
            local continuation = continueDirect and not upcoming.complete and destination or nil
            addon.ApplyWalkedPath(trail, player, upcoming, seconds, continuation)
            trail.directContinuation = continuation ~= nil
            trail.routeStatus = continuation and "Walked path, then direct bearing (unverified)" or "Recorded walked path"
        end
    end
    trail.noWalkedPath = not trail.waypoints
    return trail
end

local function resetTarget()
    target, arrived = nil, nil
    clearRoute()
end

local function readPlayer()
    local zone, x, y, z = GetUnitRawWorldPosition("player")
    local map = GetCurrentMapId()
    if not (finite(zone) and zone > 0 and finite(map) and map > 0 and finite(x) and finite(y)
        and finite(z)) or (x == 0 and y == 0 and z == 0) then return end
    return { zone = zone, map = map, x = x, y = y, z = z }
end

-- Invert a local basis from ESO's raw world-to-map transform. Reject symbolic
-- player pins, degenerate projections and targets that fail the round trip.
local function resolve(player, u, v)
    local zone, x, y, z = player.zone, player.x, player.y, player.z
    local project = GetRawNormalizedWorldPosition
    local mapU, mapV, _, shown, symbolic = GetMapPlayerPosition("player")
    local a, c = project(zone, x, y, z)
    if not (shown and not symbolic and inside(mapU, mapV) and inside(a, c))
        or math.abs(mapU - a) > .001 or math.abs(mapV - c) > .001 then return end

    local ex, ey = project(zone, x + 1000, y, z)
    local sx, sy = project(zone, x, y, z + 1000)
    if not (finite(ex) and finite(ey) and finite(sx) and finite(sy)) then return end
    local b, d = sx - a, sy - c
    ex, ey = ex - a, ey - c
    local determinant = ex * d - b * ey
    if math.abs(determinant) < 1e-12 then return end

    local du, dv = u - a, v - c
    local destX = x + (d * du - b * dv) * 1000 / determinant
    local destZ = z + (ex * dv - ey * du) * 1000 / determinant
    if not (finite(destX) and finite(destZ)) or math.abs(destX - x) > 1000000
        or math.abs(destZ - z) > 1000000 then return end
    local checkU, checkV = project(zone, zo_round(destX), y, zo_round(destZ))
    if not inside(checkU, checkV) or math.abs(checkU - u) > .0001 or math.abs(checkV - v) > .0001 then return end
    return { x = destX, z = destZ, mapX = u, mapY = v, map = player.map, zone = zone }
end

local function getWayshrineName(player, waypoint)
    local match, node
    for index = 1, GetNumFastTravelNodes() do
        local _, name, u, v, _, _, kind, shown = GetFastTravelNodeInfo(index)
        if shown and kind == POI_TYPE_WAYSHRINE and name ~= "" and inside(u, v) then
            local shrine = resolve(player, u, v)
            if shrine and (shrine.x - waypoint.x) ^ 2 + (shrine.z - waypoint.z) ^ 2 <= 2500 ^ 2 then
                if match then return end
                match = zo_strformat(SI_TOOLTIP_UNIT_NAME, name)
                node = index
            end
        end
    end
    return match, node
end

local function display(message, distance, trails, player, seconds, autoMode)
    status = message
    addon.DrawGround(settings.groundTrail and trails or nil, settings)
    if trails then
        addon.DrawMinimapTrail(trails, player, settings, seconds)
    else
        addon.HideMinimapTrail()
    end
    addon.DrawPanel(settings, message, distance, distance and target and target.name, autoMode, trails)
end

local function showAutomaticWayshrines(player, seconds)
    if settings.paused or settings.collapsed then return display("Guidance paused", nil, nil, nil, nil, true) end
    if autoMap ~= player.map or autoZone ~= player.zone or seconds >= nextAutoScan then
        if autoMap ~= player.map or autoZone ~= player.zone then autoRoutes = {} end
        autoCandidates, autoMap, autoZone, nextAutoScan = {}, player.map, player.zone, seconds + 1
        for index = 1, GetNumFastTravelNodes() do
            local known, name, u, v, _, _, kind, shown, locked = GetFastTravelNodeInfo(index)
            if known and shown and not locked and kind == POI_TYPE_WAYSHRINE and inside(u, v) then
                local shrine = resolve(player, u, v)
                if shrine then
                    shrine.name = zo_strformat(SI_TOOLTIP_UNIT_NAME, name)
                    shrine.id = index
                    autoCandidates[#autoCandidates + 1] = shrine
                end
            end
        end
    end
    for _, shrine in ipairs(autoCandidates) do
        shrine.distanceSquared = (shrine.x - player.x) ^ 2 + (shrine.z - player.z) ^ 2
    end
    table.sort(autoCandidates, function(a, b)
        if a.distanceSquared == b.distanceSquared then return a.id < b.id end
        return a.distanceSquared < b.distanceSquared
    end)
    local trails, walkedCount = {}, 0
    for _, shrine in ipairs(autoCandidates) do
        if shrine.distanceSquared > 300 ^ 2 then
            local state = autoRoutes[shrine.id]
            if not state or state.u ~= shrine.mapX or state.v ~= shrine.mapY then
                state = { u = shrine.mapX, v = shrine.mapY }
                autoRoutes[shrine.id] = state
            end
            local trail = buildTrail(player, shrine, seconds, state, false)
            if trail.waypoints then walkedCount = walkedCount + 1 end
            trails[#trails + 1] = trail
            if #trails == settings.autoWayshrineCount then break end
        end
    end
    if #trails == 0 then return display("No nearby wayshrines on this map", nil, nil, nil, nil, true) end
    local message = "Direct bearings (unverified)"
    if walkedCount > 0 then
        message = walkedCount == #trails and "Recorded walked paths" or "Recorded paths and unverified direct bearings"
    end
    display(message, nil, trails, player, seconds, true)
end

function addon.IsHud()
    return active and (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()) and not ZO_WorldMap_IsWorldMapShowing()
end

local function update()
    updateWaypointOutline(isFollowingMapWaypoint())
    if not addon.IsHud() then
        stopMotion()
        addon.HideGround()
        addon.HideMinimapTrail()
        addon.HidePanels()
        return
    end

    local seconds = GetFrameTimeMilliseconds() / 1000
    -- A browsed map can remain selected when the map scene closes. Reset only
    -- from the gameplay HUD and notify the standard map consumers if it changed.
    if not DoesCurrentMapMatchMapForPlayerLocation() and seconds >= nextMapSync then
        nextMapSync = seconds + .5
        if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
        end
    end
    if not DoesCurrentMapMatchMapForPlayerLocation() or not DoesCurrentMapShowPlayerWorld() then
        stopMotion()
        return display("Player map unavailable")
    end

    local mapType, content = GetMapType(), GetMapContentType()
    if IsUnitInDungeon("player") or content ~= MAP_CONTENT_NONE
        or (mapType ~= MAPTYPE_ZONE and mapType ~= MAPTYPE_SUBZONE)
        or GetCurrentZoneHouseId() ~= 0 then
        stopMotion()
        return display("Overland guidance unavailable here")
    end
    local player = readPlayer()
    if not player or IsUnitDead("player") then
        stopMotion()
        return display("Player position unavailable")
    end

    if ground[#ground] and (ground[#ground].map ~= player.map or ground[#ground].zone ~= player.zone) then
        stopMotion()
    end
    if not settings.paused and not settings.collapsed then
        ground = addon.SampleGround(ground, player)
        if settings.followWalkedPaths and not IsUnitSwimming("player") then
            recording = addon.RecordWalkedPoint(settings.walkedPaths, recording, player)
        else
            recording = nil
        end
    end

    if placementMap and placementMap ~= player.map then
        resetTarget()
        return display("Waypoint is on another map")
    end
    local u, v = GetMapPlayerWaypoint()
    if not inside(u, v) then
        if placedWayshrine and placedWayshrine.map == player.map then rememberWayshrine(nil) end
        resetTarget()
        if u == 0 and v == 0 and settings.autoWayshrines then
            return showAutomaticWayshrines(player, seconds)
        end
        return display(u == 0 and v == 0 and "No waypoint on this map" or "Waypoint coordinates unavailable")
    end
    if placedWayshrine and placedWayshrine.map == player.map and (math.abs(u - placedWayshrine.u) > .00001
        or math.abs(v - placedWayshrine.v) > .00001) then
        rememberWayshrine(nil)
    end
    if not target or target.map ~= player.map or target.zone ~= player.zone
        or math.abs(u - target.mapX) > 1e-7 or math.abs(v - target.mapY) > 1e-7 then
        resetTarget()
        addon.HideMinimapTrail()
    end

    local resolved = resolve(player, u, v)
    if not resolved then
        clearRoute()
        return display("Waypoint coordinates unavailable")
    end
    if not target then
        if placedWayshrine and placedWayshrine.map == player.map then
            resolved.name, resolved.wayshrineNode = placedWayshrine.name, placedWayshrine.node
        else
            resolved.name, resolved.wayshrineNode = getWayshrineName(player, resolved)
        end
        target = resolved
    end
    local distance = math.sqrt((resolved.x - player.x) ^ 2 + (resolved.z - player.z) ^ 2) / 100
    if settings.paused or settings.collapsed then return display("Guidance paused", distance) end
    if distance <= 3 then arrived = true end
    if arrived then return display("Arrived", distance) end

    local trail = buildTrail(player, resolved, seconds, selectedRoute, true)
    display(trail.routeStatus, distance, { trail }, player, seconds)
end

function addon.Refresh()
    stopMotion()
    autoMap = nil
    addon.HideMinimapTrail()
    update()
end

function addon.UseAutoWayshrines()
    settings.autoWayshrines = true
    settings.paused, settings.collapsed = false, false
    addon.ClearWaypoint()
end

function addon.ClearWaypoint()
    RemovePlayerWaypoint()
    placementMap = nil
    rememberWayshrine(nil)
    resetTarget()
    addon.Refresh()
end

function addon.SetCollapsed(collapsed)
    settings.collapsed = collapsed
    if not collapsed then settings.paused = false end
    addon.Refresh()
end

function addon.SetPaused(paused)
    settings.paused = paused
    if not paused then settings.collapsed = false end
    addon.Refresh()
end

function addon.ToggleGuidance()
    if settings then addon.SetPaused(not (settings.paused or settings.collapsed)) end
end

function addon.MovePanel()
    if not settings or not addon.IsHud() then return end
    if settings.collapsed then settings.showCompact = true else settings.showPanel = true end
    SetGameCameraUIMode(true)
    update()
end

local function slash(command)
    command = command:lower():match("^%s*(.-)%s*$")
    if command == "panel" then
        settings.showPanel = true
        addon.SetCollapsed(false)
    elseif command == "move" then
        addon.MovePanel()
    elseif command == "pause" or command == "resume" then
        addon.SetPaused(command == "pause")
    elseif command == "trail" then
        settings.groundTrail = not settings.groundTrail
        addon.Refresh()
        d("[WayShrine Pathfinder] Ground arrows " .. (settings.groundTrail and "on" or "off"))
    elseif command == "settings" then
        addon.ToggleQuickSettings()
    elseif command == "status" then
        d("[WayShrine Pathfinder] " .. status)
    else
        d(addon.command .. " help | panel | move | trail | pause | resume | settings | status")
    end
end

local function onLoaded(_, loaded)
    if loaded ~= name then return end
    EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide("ShadowStrikerrWaypointPathfinderSavedVariables", 1, nil, {
        icon = "Chevron", groundTrail = true, followWalkedPaths = true, visibleThroughTerrain = true,
        minimapTrail = false, showPanel = true, showCompact = true, collapsed = false, paused = false,
        autoWayshrines = false, autoWayshrineCount = 3,
        panel = {}, walkedPaths = {},
        groundColors = trailColors,
    })
    if not settings.waypointPaletteInitialized then
        for band, old in pairs(previousTrailColors) do
            local color = settings.groundColors[band]
            if math.abs(color[1] - old[1]) < 1e-6 and math.abs(color[2] - old[2]) < 1e-6
                and math.abs(color[3] - old[3]) < 1e-6 then
                local replacement = trailColors[band]
                settings.groundColors[band] = { replacement[1], replacement[2], replacement[3] }
            end
        end
        settings.waypointPaletteInitialized = true
    end
    addon.settings = settings
    placedWayshrine = settings.lastWayshrineWaypoint
    for _, command in ipairs({ "/wpf", "/wayshrinepathfinder", "/shadowstrikerrwayshrinepathfinder",
        "/waypointpathfinder", "/shadowstrikerrwaypointpathfinder" }) do
        if not SLASH_COMMANDS[command] then
            addon.command = command
            SLASH_COMMANDS[command] = slash
            break
        end
    end
    addon.RegisterSettings()
    EVENT_MANAGER:RegisterForEvent(name, EVENT_MAP_PING, function(_, change, pinType, _, u, v, localOwner)
        if pinType ~= MAP_PIN_TYPE_PLAYER_WAYPOINT or not localOwner then return end
        placementMap = change == PING_EVENT_ADDED and ZO_WorldMap_IsWorldMapShowing() and GetCurrentMapId() or nil
        rememberWayshrine(placementMap and readPlacedWayshrine(u, v) or nil)
        resetTarget()
        addon.HideGround()
        addon.HideMinimapTrail()
    end)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
        autoMap = nil
        stopMotion()
        addon.HideGround()
        addon.HideMinimapTrail()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        if not mapTooltipsRegistered then
            registerMapTooltips()
            mapTooltipsRegistered = true
        end
        active = true
        nextMapSync = 0
        EVENT_MANAGER:UnregisterForUpdate(name)
        EVENT_MANAGER:RegisterForUpdate(name, 33, update)
        update()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_DEACTIVATED, function()
        active = false
        EVENT_MANAGER:UnregisterForUpdate(name)
        update()
    end)
end

EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, onLoaded)
