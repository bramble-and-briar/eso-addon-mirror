local addon = SkyshardPathfinder
local name = "SkyshardPathfinder"
local destination
local settings
local collectedCount
local confirmationUntil
local candidates, candidateZone, candidateMap
local selectedShardId, selectedWasCollected
local trackedShard
local confirmationTarget
local active = false
local trailState = "Waiting for player activation."
local groundSamples = {}
local recording, routeCache, routeAnchor
local nextRouteSearch = 0

local function countCollected(zone)
    local count = 0
    addon.VisitZoneShards(zone, function(_, collected)
        if collected then count = count + 1 end
    end)
    return count
end

local function selectIcon(style)
    if not addon.SetIconStyle(style) then return false end
    settings.icon = style
    if addon.UpdateGroundIconPreview then addon.UpdateGroundIconPreview() end
    return true
end

local function say(message)
    d("[SkyShard Pathfinder] " .. message)
end

local function readPlayer()
    local zone, x, y, z = GetUnitRawWorldPosition("player")
    if not zone or zone == 0 or (x == 0 and y == 0 and z == 0) then return end
    return { zone = zone, map = GetCurrentMapId(), x = x, y = y, z = z }
end

local function clear()
    destination = nil
    confirmationUntil = nil
    confirmationTarget = nil
    candidates = nil
    trackedShard = nil
    groundSamples = {}
    recording, routeCache, routeAnchor = nil, nil, nil
    nextRouteSearch = 0
    trailState = "Trail inactive."
    EVENT_MANAGER:UnregisterForUpdate(name)
    EVENT_MANAGER:UnregisterForEvent(name, EVENT_SKYSHARDS_UPDATED)
    addon.HideTrail()
    addon.HideMinimapTrail()
end

local function collectUpdate()
    candidates = nil
    if destination then
        local count = countCollected(GetZoneId(GetUnitZoneIndex("player")))
        if count > collectedCount then confirmationUntil = GetFrameTimeMilliseconds() + 1500 end
        collectedCount = count
    elseif trackedShard and not trackedShard.alreadyCollected
        and GetSkyshardDiscoveryStatus(trackedShard.id) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then
        confirmationTarget = trackedShard
        confirmationUntil = GetFrameTimeMilliseconds() + 1500
        trackedShard = nil
    end
    if selectedShardId and not selectedWasCollected
        and GetSkyshardDiscoveryStatus(selectedShardId) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then
        selectedShardId = nil
        addon.InvalidateMapTooltip()
    end
end

local function getPlayerMapZone(player)
    local index = GetUnitZoneIndex("player")
    local zone = GetZoneId(index)
    local currentMap = DoesCurrentMapMatchMapForPlayerLocation()
    if not currentMap and DoesCurrentMapShowPlayerWorld and GetMapIdByZoneId then
        currentMap = DoesCurrentMapShowPlayerWorld() and GetCurrentMapZoneIndex() == index
            and player.map == GetMapIdByZoneId(zone)
    end
    if currentMap then return zone end
end

local function autoTarget(player, zone)
    if not zone then
        candidates, trackedShard, confirmationTarget = nil, nil, nil
        trailState = "Displayed map does not match the player map."
        return
    end
    if not candidates or candidateZone ~= player.zone or candidateMap ~= player.map then
        if candidateZone ~= player.zone or candidateMap ~= player.map then confirmationTarget = nil end
        candidates = addon.GetNavigationShards(zone, player, settings.includeCollectedInTrails, selectedShardId)
        candidateZone, candidateMap = player.zone, player.map
        routeCache, routeAnchor = nil, nil
    end
    local confirmed = confirmationTarget and GetFrameTimeMilliseconds() < confirmationUntil
    if not confirmed then confirmationTarget = nil end
    if selectedShardId then
        for _, shard in ipairs(candidates) do
            if shard.id == selectedShardId then
                trackedShard = shard
                return { shard }, confirmationTarget
            end
        end
        trackedShard = nil
        trailState = "The selected SkyShard is unavailable on this map. Use clear target to resume automatic guidance."
        return
    end
    local ordered = addon.GetOrderedShards(candidates, player.x, player.z)
    local maxDistance = settings.trailMaxDistance or 0
    if maxDistance > 0 then
        local limitSquared = (maxDistance * 100) ^ 2
        while #ordered > 0 and ordered[#ordered].distanceSquared > limitSquared do
            ordered[#ordered] = nil
        end
    end
    trackedShard = ordered[1]
    if trackedShard or confirmationTarget then return ordered, confirmationTarget end
    trailState = string.format("No eligible uncollected shard coordinates on map %d.", player.map)
end

local function getTrail(player, target, seconds, secondary)
    local trail = addon.GetDirectTrail(player, target, seconds, secondary, groundSamples)
    trail.target = target
    if not settings.followWalkedPaths or not target.id then return trail end
    local moved = routeAnchor and ((player.x - routeAnchor.x) ^ 2 + (player.z - routeAnchor.z) ^ 2 >= 70 ^ 2
        or math.abs(player.y - routeAnchor.y) >= 75)
    if not routeAnchor or (moved and seconds >= nextRouteSearch) then
        if not routeCache then routeCache = {} end
        for id, cached in pairs(routeCache) do
            if cached == false then routeCache[id] = nil end
        end
        routeAnchor = player
        nextRouteSearch = seconds + .35
    end
    local route = routeCache[target.id]
    local upcoming = route and addon.AdvanceWalkedPath(route, player)
    if route and not upcoming then routeCache[target.id] = false end
    if routeCache[target.id] == nil then
        route = addon.FindWalkedPath(settings.walkedPaths, player, target, seconds)
        upcoming = route and addon.AdvanceWalkedPath(route, player)
        routeCache[target.id] = upcoming and route or false
    end
    if upcoming then
        local continuation = not upcoming.complete and settings.allowDirectFallback and target
        addon.ApplyWalkedPath(trail, player, upcoming, seconds, continuation)
        if not upcoming.complete then
            trail.routeNote = continuation and "Walked path, then direct bearing" or "Connected path ends before shard"
        end
    elseif not settings.allowDirectFallback then
        trail.points = {}
        trail.noWalkedPath = true
        trail.routeNote = "No walked path here"
    else
        trail.noWalkedPath = true
        trail.routeNote = "Direct bearing (unverified)"
    end
    return trail
end

local function update()
    local player = readPlayer()
    if not player or (not HUD_SCENE:IsShowing() and not HUD_UI_SCENE:IsShowing()) then
        trailState = player and "Gameplay HUD is hidden." or "Player position unavailable."
        addon.HideTrail()
        addon.HideMinimapTrail()
        recording = nil
        return
    end
    local targets, confirmation
    groundSamples = addon.SampleGround(groundSamples, player)
    local zone = getPlayerMapZone(player)
    if settings.followWalkedPaths and zone and (not IsUnitDead or not IsUnitDead("player"))
        and (not IsUnitSwimming or not IsUnitSwimming("player")) then
        recording = addon.RecordWalkedPoint(settings.walkedPaths, recording, player)
    else
        recording = nil
    end
    if destination then
        if player.zone == destination.zone and player.map == destination.map then
            targets = { destination }
        end
    else
        targets, confirmation = autoTarget(player, zone)
    end
    if targets then
        local trails, headings = {}, {}
        local seconds = GetFrameTimeMilliseconds() / 1000
        if confirmation and not settings.includeCollectedInTrails then
            local trail = getTrail(player, confirmation, seconds, false)
            trail.collected = true
            trails[1] = trail
        end
        local count = settings.trailLimit > 0 and math.min(#targets, settings.trailLimit) or #targets
        for index = 1, count do
            local trail = getTrail(player, targets[index], seconds, index > 1)
            trail.selected = targets[index].id and targets[index].id == selectedShardId
            if confirmation and targets[index].id == confirmation.id then trail.collected = true end
            if destination and confirmationUntil and GetFrameTimeMilliseconds() < confirmationUntil then
                trail.collected = true
            end
            if trail.yaw then
                for _, heading in ipairs(headings) do
                    if math.cos(trail.yaw - heading) > .985 then
                        trail.points = {}
                        break
                    end
                end
                if #trail.points > 0 then headings[#headings + 1] = trail.yaw end
            end
            trails[#trails + 1] = trail
        end
        local first = trails[1]
        trailState = string.format("%d destinations, %d distinct trails%s.", count, #headings,
            first and string.format(", nearest %.0f m", first.distance) or "")
        addon.RenderTrails(trails, settings)
        addon.DrawMinimapTrail(trails, player, settings, seconds)
    elseif selectedShardId then
        addon.RenderTrails({}, settings, true)
        addon.HideMinimapTrail()
    else
        addon.RenderTrails({}, settings, false, trailState)
        addon.HideMinimapTrail()
    end
end

local function startTrail()
    if type(WorldPositionToGuiRender3DPosition) ~= "function" then return end
    EVENT_MANAGER:RegisterForEvent(name, EVENT_SKYSHARDS_UPDATED, collectUpdate)
    EVENT_MANAGER:RegisterForUpdate(name, 0, update)
end

function addon.RefreshResumeIcon()
    addon.ShowResumeIcon(active and settings.collapsed == true and settings.showCollapsedIcon ~= false,
        settings.distancePanelPosition)
end

local function useAutomaticTrail()
    clear()
    addon.RefreshResumeIcon()
    if active and settings.autoTrail and not settings.collapsed then startTrail() end
end

function addon.SetCollapsed(collapsed)
    settings.collapsed = collapsed
    if not collapsed then settings.showDistancePanel = true end
    useAutomaticTrail()
end

function addon.IsFollowingShard(id)
    return selectedShardId ~= nil and selectedShardId == id
end

function addon.FollowShard(id, collected, entrance, zoneIndex)
    if selectedShardId == id and settings.autoTrail and not settings.collapsed then return end
    selectedShardId, selectedWasCollected = id, collected
    addon.InvalidateMapTooltip()
    settings.autoTrail = true
    settings.collapsed = false
    if settings.announceTargets ~= false then
        local hint = GetSkyshardHint(id)
        hint = hint and hint ~= "" and hint:gsub("[\r\n]+", " ") or ("SkyShard " .. id)
        local place = entrance and entrance.name or (zoneIndex and zoneIndex > 0 and GetZoneNameByIndex(zoneIndex))
        say(place and place ~= "" and ("Target: " .. place .. " - " .. hint) or ("Target: " .. hint))
    end
    useAutomaticTrail()
end

function addon.ClearSelectedShard()
    if not selectedShardId then return end
    selectedShardId, selectedWasCollected = nil, nil
    addon.InvalidateMapTooltip()
    useAutomaticTrail()
end

local function reportShards()
    local probeZone = GetZoneId(GetUnitZoneIndex("player"))
    if GetParentZoneId then
        local parent = GetParentZoneId(probeZone)
        if parent and parent > 0 then probeZone = parent end
    end
    local total = GetNumSkyshardsInZone(probeZone)
    say(string.format("API %d, zone %d, displayed map %d, %d shards.",
        GetAPIVersion(), probeZone, GetCurrentMapId(), total))
    for index = 1, total do
        local id = GetZoneSkyshardId(probeZone, index)
        if id and id > 0 then
            local zone, x, y, z = GetWorldPositionForSkyshardId(id)
            local _, _, onMap = GetNormalizedPositionForSkyshardId(id)
            say(string.format("Shard %d, status %s, on map %s, world %s/%s/%s/%s.",
                id, tostring(GetSkyshardDiscoveryStatus(id)), tostring(onMap),
                tostring(zone), tostring(x), tostring(y), tostring(z)))
        end
    end
end

local defaultCommand = "/ssp"
local activeCommand

function addon.MoveDistancePanel()
    if addon.EnablePanelMove() then
        say("Drag the panel header to move it or the bottom-right grip to resize it. Press your cursor-mode key to return to gameplay.")
    else
        say("The distance panel must be visible before moving it.")
    end
end

function addon.ToggleGroundTrail()
    if not settings then return end
    if settings.collapsed then
        addon.SetCollapsed(false)
    else
        settings.autoTrail = not settings.autoTrail
        useAutomaticTrail()
    end
end

local function handleSlashCommand(command)
    local prefix = activeCommand or defaultCommand
    command = command:lower():match("^%s*(.-)%s*$")
    if command == "" or command == "menu" then
        addon.ToggleQuickSettings()
    elseif command == "panel" then
        if settings.collapsed then
            addon.SetCollapsed(false)
        else
            settings.showDistancePanel = settings.showDistancePanel == false
        end
    elseif command == "reset" then
        addon.ClearSelectedShard()
    elseif command == "clear" then
        selectedShardId, selectedWasCollected = nil, nil
        addon.InvalidateMapTooltip()
        clear()
        say("Trail cleared. Use " .. prefix .. " auto to resume automatic guidance.")
    elseif command == "auto" then
        selectedShardId, selectedWasCollected = nil, nil
        addon.InvalidateMapTooltip()
        settings.autoTrail = true
        useAutomaticTrail()
    elseif command == "mark" then
        if type(WorldPositionToGuiRender3DPosition) ~= "function" then
            say("3D render-space conversion is unavailable on this client.")
            return
        end
        local player = readPlayer()
        if not player then
            say("Player position unavailable.")
            return
        end
        clear()
        destination = player
        local zone = GetZoneId(GetUnitZoneIndex("player"))
        collectedCount = countCollected(zone)
        startTrail()
        say("Test point marked. Walk 10-20 meters away, then turn to face it.")
    elseif command == "probe" then
        reportShards()
    elseif command == "move" then
        addon.MoveDistancePanel()
    elseif command == "trail" then
        say(trailState)
    elseif command == "icon" then
        say("Current icon: " .. settings.icon .. ". Choices: chevron, arrowhead, shard, flat-chevron, double-chevron, needle-arrow, eso.")
    elseif command:match("^icon%s+") then
        local style = command:match("^icon%s+(.+)$")
        if selectIcon(style) then
            say("Ground trail icon set to " .. style .. ".")
        else
            say("Use " .. prefix .. " icon to list the available styles.")
        end
    else
        say(prefix .. " commands: menu, auto, mark, clear, reset, panel, trail, move, probe, icon")
    end
end

function addon.SetSlashCommand(value)
    local word = value:lower():match("^%s*/?(.-)%s*$")
    if word == "" then word = "ssp" end
    if not word:match("^[a-z][a-z0-9]*$") then
        say("Enter one command word starting with a letter. Use letters and numbers only.")
        return false
    end
    local command = "/" .. word
    if SLASH_COMMANDS[command] and SLASH_COMMANDS[command] ~= handleSlashCommand then
        say(command .. " is already in use.")
        return false
    end
    if activeCommand ~= command then
        if activeCommand and SLASH_COMMANDS[activeCommand] == handleSlashCommand then
            SLASH_COMMANDS[activeCommand] = nil
        end
        SLASH_COMMANDS[command] = handleSlashCommand
        activeCommand = command
    end
    settings.slashCommand = command
    return true
end

ZO_CreateStringId("SI_BINDING_NAME_SKYSHARD_PATHFINDER_QUICK_SETTINGS", "Open quick settings")
ZO_CreateStringId("SI_BINDING_NAME_SKYSHARD_PATHFINDER_TOGGLE_TRAIL", "Toggle ground trail")
ZO_CreateStringId("SI_BINDING_NAME_SKYSHARD_PATHFINDER_MOVE_PANEL", "Move distance panel")

EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, function(_, loadedAddon)
    if loadedAddon ~= name then return end
    EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide("SkyshardPathfinderSavedVariables", 1, nil, {
        slashCommand = defaultCommand,
        icon = "chevron",
        mapIcon = "ESO",
        pinSize = 36,
        pinLayer = 52,
        showUncollected = true,
        showCollected = true,
        autoTrail = true,
        followWalkedPaths = true,
        allowDirectFallback = true,
        visibleThroughTerrain = true,
        minimapTrail = true,
        announceTargets = true,
        showDistancePanel = true,
        collapsed = false,
        showCollapsedIcon = true,
        walkedPaths = {},
        arrowsOnly = false,
        trailLimit = 0,
        trailMaxDistance = 0,
        includeCollectedInTrails = false,
        distancePanelPosition = {},
        quickSettingsPosition = {},
        uncollectedColor = { 0, 0, 0 },
        collectedColor = { 1, 1, 1 },
        groundColors = {
            near = { 0, 229 / 255, 224 / 255 },
            middle = { 56 / 255, 141 / 255, 1 },
            far = { 176 / 255, 96 / 255, 1 },
            collected = { 0.24, 0.85, 0.47 },
        },
    })
    if not addon.SetSlashCommand(settings.slashCommand or defaultCommand) then
        addon.SetSlashCommand(defaultCommand)
    end
    if not selectIcon(settings.icon) then
        selectIcon("chevron")
    end
    addon.RegisterMapPins(settings)
    addon.RegisterIconSettings(settings, selectIcon, useAutomaticTrail)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function() candidates = nil end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        active = true
        addon.RegisterCompatiblePinClicks()
        useAutomaticTrail()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_DEACTIVATED, function()
        active = false
        addon.CloseQuickSettings()
        useAutomaticTrail()
    end)
end)

