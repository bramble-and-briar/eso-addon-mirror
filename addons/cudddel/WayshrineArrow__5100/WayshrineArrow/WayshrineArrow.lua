-- WayshrineArrow: a movable HUD arrow that points in a straight line to the nearest wayshrine of the current map.

WayshrineArrow = WayshrineArrow or {}
local WA = WayshrineArrow

local ADDON_NAME = "WayshrineArrow"
WA.name = ADDON_NAME
WA.version = "0.1.0"

local EM = EVENT_MANAGER
local UPDATE_NAME = ADDON_NAME .. "_Update"
local UPDATE_INTERVAL_MS = 50
local MAP_RESET_INTERVAL_MS = 1000   -- at most one SetMapToPlayerLocation() per second
local CALIBRATION_MIN_SPAN = 0.005   -- normalized map distance needed before the map scale is measured
local STATIC_WORLD_MOVE = 800        -- cm walked ...
local STATIC_MAP_MOVE = 0.0002       -- ... while the map position moved less than this: inside a building
local MISMATCH_TOLERANCE = 5000      -- cm, plus MISMATCH_FACTOR of the distance: world position does not fit the map
local MISMATCH_FACTOR = 0.1
local DOOR_VALID_MS = 10000          -- a jump this long after opening a door counts as going through it
local DOOR_JUMP = 1000               -- cm between two updates: teleported by a door
local DOOR_SAME_HEIGHT = 500         -- cm: back at the height of the entrance means outside again
local INDOOR_RESTORE_RANGE = 15000   -- cm around the place inside where the saved state is restored
local ARROW_TEXTURE = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds"

local TARGET_ALL = 1
local TARGET_UNKNOWN = 2
local TARGET_KNOWN = 3
local TARGET_STRINGS = {
    [TARGET_ALL] = SI_WAYSHRINEARROW_TARGET_ALL,
    [TARGET_UNKNOWN] = SI_WAYSHRINEARROW_TARGET_UNKNOWN,
    [TARGET_KNOWN] = SI_WAYSHRINEARROW_TARGET_KNOWN,
}

local DEFAULTS = {
    enabled = true,
    target = TARGET_ALL,
    locked = true,
    posX = 0,
    posY = -280,
    arrowSize = 56,
    fontSize = 18,
    alpha = 1,
    showName = true,
    showStatus = true,
    showDistance = true,
    knownColor = { 0.45, 0.85, 1, 1 },
    unknownColor = { 1, 0.78, 0.25, 1 },
    hideInCombat = false,
    hideNear = 0,
}

-- SavedVariables, all with GetWorldName() as profile: WayshrineArrow_Saved[server][@account][...]
--  * account-wide: the account-wide settings (DEFAULTS) plus data that is the same for all characters
--  * per character id: the character's own settings (DEFAULTS) and the choice which settings it uses
local ACCOUNT_DEFAULTS = ZO_ShallowTableCopy(DEFAULTS, {
    indoorByCharacter = {},   -- [characterId] = building without loading screen the character is in, see SetIndoor
    mapScale = {},   -- [mapId] = { ratio = world cm per normalized map unit, span = normalized span it was measured over }
})
local CHARACTER_DEFAULTS = ZO_ShallowTableCopy(DEFAULTS, {
    useAccountWide = true,
    copiedFromAccount = false,   -- own settings start as a copy of the account-wide ones
})

local accountSV, characterSV
local sv     -- settings in use: accountSV or characterSV
local data   -- account-wide data: accountSV
local window, content, backdrop, arrow, label

-- state
local nodes = {}            -- wayshrines of the cached map: { known, name, x, y }
local cachedMapId
local nodesDirty = true
local inBlockedArea = false
local inCombat = false
local lastMapReset = 0
local lastText
local segment               -- see StartSegment

local sqrt, atan2, floor = math.sqrt, math.atan2, math.floor

local function Print(text)
    d("|c88CCFF[WayshrineArrow]|r " .. text)
end

------------------------------------------------------------------------------------------------
-- Areas without the arrow
------------------------------------------------------------------------------------------------

local function IsInBlockedArea()
    -- delves, public and group dungeons, solo and group arenas
    if IsUnitInDungeon("player") then return true end
    -- trials
    if IsPlayerInRaid() then return true end
    if IsInstanceEndlessDungeon() then return true end
    if IsActiveWorldBattleground() then return true end
    if GetCurrentZoneHouseId() ~= 0 then return true end
    return false
end

------------------------------------------------------------------------------------------------
-- Map and wayshrines
------------------------------------------------------------------------------------------------

-- Makes sure the current map is the player's map. Returns false while the world map is open,
-- because then the player browses maps and the coordinates belong to another map.
local function EnsurePlayerMap()
    if ZO_WorldMap_IsWorldMapShowing() then return false end
    if not DoesCurrentMapMatchMapForPlayerLocation() then
        local now = GetFrameTimeMilliseconds()
        if now - lastMapReset < MAP_RESET_INTERVAL_MS then return false end
        lastMapReset = now
        if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
        end
    end
    return true
end

local function IsInsideMap(x, y)
    return x > 0 and x < 1 and y > 0 and y < 1
end

local function RebuildNodes()
    nodes = {}
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local known, name, x, y, _, _, poiType, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        if poiType == POI_TYPE_WAYSHRINE and isShownInCurrentMap and IsInsideMap(x, y) then
            if name == nil or name == "" then
                name = GetString(SI_WAYSHRINEARROW_UNNAMED)
            else
                name = zo_strformat(SI_WORLD_MAP_LOCATION_NAME, name)
            end
            nodes[#nodes + 1] = { known = known, name = name, x = x, y = y }
        end
    end
    cachedMapId = GetCurrentMapId()
    nodesDirty = false
    lastText = nil
end

local function FindNearest(px, py)
    local target = sv.target
    local best, bestDist2
    for i = 1, #nodes do
        local node = nodes[i]
        if target == TARGET_ALL or (target == TARGET_UNKNOWN) ~= node.known then
            local dx, dy = node.x - px, node.y - py
            local dist2 = dx * dx + dy * dy
            if not bestDist2 or dist2 < bestDist2 then
                best, bestDist2 = node, dist2
            end
        end
    end
    return best, bestDist2 and sqrt(bestDist2)
end

local function Distance(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return sqrt(dx * dx + dy * dy)
end

-- A segment is the time on one map between two loading screens. It starts with a sample of map and world position.
-- Buildings entered through a door with a loading screen (banks, shops, inns ...) are worlds of their own, but the
-- game keeps showing the city or zone map. They are recognized in two ways:
--  * the map position does not follow the world position while walking (sticky until the next loading screen)
--  * the world position does not fit the measured map scale and anchor of this map
local function StartSegment(mapId, px, py, worldX, worldZ)
    segment = { mapId = mapId, x = px, y = py, worldX = worldX, worldZ = worldZ, isStatic = false }
end

-- Returns isInterior, worldDistToAnchor, expectedDistToAnchor (cm) for the debug output.
local function CheckInterior(mapId, px, py, worldX, worldZ)
    if not segment or segment.mapId ~= mapId then
        StartSegment(mapId, px, py, worldX, worldZ)
    end
    if not segment.isStatic
        and Distance(worldX, worldZ, segment.worldX, segment.worldZ) > STATIC_WORLD_MOVE
        and Distance(px, py, segment.x, segment.y) < STATIC_MAP_MOVE then
        segment.isStatic = true
    end
    local entry = data.mapScale[mapId]
    local worldDist, expected
    if entry then
        worldDist = Distance(worldX, worldZ, entry.worldX, entry.worldZ)
        expected = Distance(px, py, entry.x, entry.y) * entry.ratio
        if math.abs(worldDist - expected) > MISMATCH_TOLERANCE + MISMATCH_FACTOR * expected then
            return true, worldDist, expected
        end
    end
    return segment.isStatic, worldDist, expected
end

-- Buildings without a loading screen (the screen only turns black for a moment, e.g. inns in villages) lie in the
-- same world, usually below the ground. They are recognized by the door: an "Open" interaction followed by a jump
-- of the player position. The door names its destination: the outside location when leaving, the building otherwise.
local lastDoorInteract      -- { name, at }
local prevWorld             -- world position of the previous update
local indoor                -- { mapId, entryY, name } while inside such a building
local lastDoor = "-"        -- for /wsarrow debug
local restorePending = false

local function NormalizeName(name)
    return zo_strlower(zo_strformat("<<1>>", name))
end

local function IsOutsideName(name)
    local names = { GetPlayerLocationName(), GetPlayerActiveSubzoneName(), GetPlayerActiveZoneName(), GetMapName() }
    for i = 1, #names do
        if names[i] ~= "" and NormalizeName(names[i]) == name then return true end
    end
    return false
end

local function OnInteractionStart()
    local action, name = GetGameCameraInteractableActionInfo()
    if action == GetString(SI_GAMECAMERAACTIONTYPE13) and name and name ~= "" then
        lastDoorInteract = { name = NormalizeName(name), at = GetFrameTimeMilliseconds() }
    end
end

-- The state is also saved per character: after login or /reloadui inside the building the door is not seen again.
local function SetIndoor(value)
    indoor = value
    data.indoorByCharacter[GetCurrentCharacterId()] = value
end

-- After every loading screen (login, /reloadui, travel): restore the saved state if the player is still there,
-- i.e. on the same map, near the place inside and not at the height of the entrance.
local function RestoreIndoor(mapId, worldX, worldY, worldZ)
    restorePending = false
    local saved = data.indoorByCharacter[GetCurrentCharacterId()]
    if saved and saved.mapId == mapId
        and Distance(worldX, worldZ, saved.x, saved.z) < INDOOR_RESTORE_RANGE
        and math.abs(worldY - saved.entryY) >= DOOR_SAME_HEIGHT then
        indoor = saved
        lastDoor = "restored: " .. saved.name
    else
        SetIndoor(nil)
    end
end

local function UpdateIndoor(mapId, worldX, worldY, worldZ)
    if restorePending then
        RestoreIndoor(mapId, worldX, worldY, worldZ)
    end
    local prev = prevWorld
    prevWorld = { x = worldX, y = worldY, z = worldZ }
    if indoor and indoor.mapId ~= mapId then SetIndoor(nil) end
    if not prev or not lastDoorInteract then return end
    if GetFrameTimeMilliseconds() - lastDoorInteract.at > DOOR_VALID_MS then
        lastDoorInteract = nil
        return
    end
    local dx, dy, dz = worldX - prev.x, worldY - prev.y, worldZ - prev.z
    if dx * dx + dy * dy + dz * dz < DOOR_JUMP * DOOR_JUMP then return end

    local name = lastDoorInteract.name
    lastDoorInteract = nil
    if indoor then
        -- a door inside may also lead to another room (cellar, upper floor): only leave on the way out
        if IsOutsideName(name) or math.abs(worldY - indoor.entryY) < DOOR_SAME_HEIGHT then
            lastDoor = "out: " .. name
            SetIndoor(nil)
        else
            lastDoor = "room: " .. name
        end
    elseif not IsOutsideName(name) then
        lastDoor = "in: " .. name
        SetIndoor({ mapId = mapId, entryY = prev.y, name = name, x = worldX, z = worldZ })
    else
        lastDoor = "outside: " .. name
    end
end

-- The map scale (centimeters per normalized map unit) is measured from the player's own movement:
-- world and map position at the start of the segment and now. The start sample is kept as anchor.
local function Calibrate(mapId, px, py, worldX, worldZ)
    local span = Distance(px, py, segment.x, segment.y)
    if span < CALIBRATION_MIN_SPAN then return end
    local entry = data.mapScale[mapId]
    if entry and entry.span >= span then return end
    local worldDist = Distance(worldX, worldZ, segment.worldX, segment.worldZ)
    if worldDist > 0 then
        data.mapScale[mapId] = {
            ratio = worldDist / span, span = span,
            x = segment.x, y = segment.y, worldX = segment.worldX, worldZ = segment.worldZ,
        }
    end
end

local function GetDistanceMeters(mapId, normalizedDist)
    local entry = data.mapScale[mapId]
    if entry then
        return normalizedDist * entry.ratio / 100
    end
end

local function FormatDistance(meters)
    if meters < 1000 then
        return zo_strformat(SI_WAYSHRINEARROW_METERS, floor(meters + 0.5))
    end
    return zo_strformat(SI_WAYSHRINEARROW_KILOMETERS, string.format("%.1f", meters / 1000))
end

------------------------------------------------------------------------------------------------
-- Display
------------------------------------------------------------------------------------------------

local function SetText(text)
    if text ~= lastText then
        lastText = text
        label:SetText(text)
    end
end

local function ShowPlaceholder()
    content:SetHidden(false)
    arrow:SetTextureRotation(0)
    arrow:SetColor(1, 1, 1, 1)
    SetText(GetString(SI_WAYSHRINEARROW_DRAG_HINT))
end

local function HideArrow()
    content:SetHidden(true)
end

local function BuildText(node, meters)
    local lines = {}
    if sv.showName then
        lines[#lines + 1] = node.name
    end
    local info = {}
    if sv.showStatus then
        local color = node.known and sv.knownColor or sv.unknownColor
        local status = GetString(node.known and SI_WAYSHRINEARROW_KNOWN or SI_WAYSHRINEARROW_UNKNOWN)
        info[#info + 1] = ZO_ColorDef:New(unpack(color)):Colorize(status)
    end
    if sv.showDistance and meters then
        info[#info + 1] = FormatDistance(meters)
    end
    if #info > 0 then
        lines[#lines + 1] = table.concat(info, " · ")
    end
    return table.concat(lines, "\n")
end

-- Runs only while the arrow can be shown, see RefreshUpdateLoop.
local function OnUpdate()
    if not sv.locked then
        ShowPlaceholder()
        return
    end
    if not EnsurePlayerMap() then return end

    local mapId = GetCurrentMapId()
    if nodesDirty or mapId ~= cachedMapId then
        RebuildNodes()
    end

    local px, py, _, isShownInCurrentMap, isSymbolicLocation = GetMapPlayerPosition("player")
    if not isShownInCurrentMap or isSymbolicLocation then
        HideArrow()
        return
    end
    local _, worldX, worldY, worldZ = GetUnitRawWorldPosition("player")
    UpdateIndoor(mapId, worldX, worldY, worldZ)
    if indoor or CheckInterior(mapId, px, py, worldX, worldZ) then
        HideArrow()
        return
    end
    Calibrate(mapId, px, py, worldX, worldZ)

    local node, dist = FindNearest(px, py)
    if not node then
        HideArrow()
        return
    end
    local meters = GetDistanceMeters(mapId, dist)
    if sv.hideNear > 0 and meters and meters < sv.hideNear then
        HideArrow()
        return
    end

    -- Map x grows to the east, y to the south. Heading and texture rotation count counter-clockwise from north.
    local bearing = atan2(px - node.x, py - node.y)
    arrow:SetTextureRotation(bearing - GetPlayerCameraHeading())
    local color = node.known and sv.knownColor or sv.unknownColor
    arrow:SetColor(unpack(color))
    SetText(BuildText(node, meters))
    content:SetHidden(false)
end

local function ApplyLayout()
    local size = sv.arrowSize
    window:SetDimensions(size, size)
    window:ClearAnchors()
    window:SetAnchor(CENTER, GuiRoot, CENTER, sv.posX, sv.posY)
    -- on the content, not the window: the HUD fade fragment animates the window alpha back to 1
    content:SetAlpha(sv.alpha)
    label:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", sv.fontSize))
    window:SetMovable(not sv.locked)
    window:SetMouseEnabled(not sv.locked)
    backdrop:SetHidden(sv.locked)
    lastText = nil
end

local function SavePosition()
    local cx, cy = window:GetCenter()
    local gx, gy = GuiRoot:GetCenter()
    sv.posX = floor(cx - gx + 0.5)
    sv.posY = floor(cy - gy + 0.5)
end

local function CreateControls()
    window = WINDOW_MANAGER:CreateTopLevelWindow("WayshrineArrow_Window")
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_LOW)
    window:SetHandler("OnMoveStop", SavePosition)

    backdrop = WINDOW_MANAGER:CreateControl("WayshrineArrow_WindowBackdrop", window, CT_BACKDROP)
    backdrop:SetAnchor(TOPLEFT, window, TOPLEFT, -4, -4)
    backdrop:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, 4, 4)
    backdrop:SetCenterColor(0, 0, 0, 0.5)
    backdrop:SetEdgeColor(1, 1, 1, 0.6)
    backdrop:SetEdgeTexture("", 1, 1, 1)

    content = WINDOW_MANAGER:CreateControl("WayshrineArrow_WindowContent", window, CT_CONTROL)
    content:SetAnchorFill(window)
    content:SetHidden(true)

    arrow = WINDOW_MANAGER:CreateControl("WayshrineArrow_WindowArrow", content, CT_TEXTURE)
    arrow:SetAnchorFill(content)
    arrow:SetTexture(ARROW_TEXTURE)

    label = WINDOW_MANAGER:CreateControl("WayshrineArrow_WindowLabel", content, CT_LABEL)
    label:SetAnchor(TOP, content, BOTTOM, 0, 2)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 1, 1, 1)

    -- visible only in the normal game view (and the HUD with mouse cursor, needed for moving)
    local fragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

------------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------------

-- The update loop runs only while the arrow can be shown: switched on, and not in a dungeon, trial ... or in combat
-- (with "Hide in combat"). While unlocked it always runs, because it shows the placeholder for moving.
local function RefreshUpdateLoop()
    EM:UnregisterForUpdate(UPDATE_NAME)
    local canShow = not inBlockedArea and not (sv.hideInCombat and inCombat)
    if sv.enabled and (canShow or not sv.locked) then
        EM:RegisterForUpdate(UPDATE_NAME, UPDATE_INTERVAL_MS, OnUpdate)
    else
        HideArrow()
    end
end

local function RefreshArea()
    inBlockedArea = IsInBlockedArea()
    nodesDirty = true
    RefreshUpdateLoop()
end

-- for /wsarrow debug: what the game reports when entering buildings
local lastZoneChange = "-"
local activationCount = 0

local function OnPlayerActivated()
    activationCount = activationCount + 1
    -- after every loading screen: new segment, it starts with the next sample on the player's map
    segment = nil
    indoor, prevWorld, lastDoorInteract = nil, nil, nil
    restorePending = true
    RefreshArea()
end

local function OnZoneChanged(_, zoneName, subZoneName, newSubzone, zoneId, subZoneId)
    lastZoneChange = string.format("'%s' / '%s' (new %s, ids %s / %s)", tostring(zoneName), tostring(subZoneName),
        tostring(newSubzone), tostring(zoneId), tostring(subZoneId))
    RefreshArea()
end

local function OnFastTravelNetworkUpdated()
    nodesDirty = true
end

local function OnCombatState(_, isInCombat)
    inCombat = isInCombat
    RefreshUpdateLoop()
end

-- The door hook cannot be removed again, so it is only installed once the arrow is switched on.
local doorHookInstalled = false

function WA.CheckEvents()
    EM:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ZONE_CHANGED)
    EM:UnregisterForEvent(ADDON_NAME, EVENT_FAST_TRAVEL_NETWORK_UPDATED)
    EM:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE)
    EM:UnregisterForUpdate(UPDATE_NAME)
    inCombat = false

    if not sv.enabled then
        HideArrow()
        return
    end

    if not doorHookInstalled then
        -- remember doors when the interact key is pressed; the hook returns nothing, so the interaction continues
        ZO_PreHook(INTERACTIVE_WHEEL_MANAGER, "StartInteraction", OnInteractionStart)
        doorHookInstalled = true
    end
    EM:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EM:RegisterForEvent(ADDON_NAME, EVENT_ZONE_CHANGED, OnZoneChanged)
    EM:RegisterForEvent(ADDON_NAME, EVENT_FAST_TRAVEL_NETWORK_UPDATED, OnFastTravelNetworkUpdated)
    if sv.hideInCombat then
        EM:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
        inCombat = IsUnitInCombat("player")
    end
    -- loading screens may have been missed while switched off
    segment = nil
    indoor, prevWorld, lastDoorInteract = nil, nil, nil
    restorePending = true
    RefreshArea()
end

------------------------------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------------------------------

-- Switches between the account-wide settings and the character's own ones. The own settings start as a copy
-- of the account-wide ones the first time they are used.
local function SetUseAccountWide(useAccountWide)
    characterSV.useAccountWide = useAccountWide
    if not useAccountWide and not characterSV.copiedFromAccount then
        for key in pairs(DEFAULTS) do
            local value = accountSV[key]
            characterSV[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
        end
        characterSV.copiedFromAccount = true
    end
    sv = useAccountWide and accountSV or characterSV
    ApplyLayout()
    WA.CheckEvents()
end

local ACCOUNT_WIDE_KEY = "$AccountWide"

-- The raw saved settings of this account on this server: [characterId or "$AccountWide"] = settings
local function GetRawAccountTable()
    local servers = WayshrineArrow_Saved or {}
    local accounts = servers[GetWorldName()] or {}
    return accounts[GetDisplayName()] or {}
end

-- Sources for copying settings: the account-wide settings and every other character of this account on this
-- server that has its own settings (characters with shared settings would only copy the account-wide ones).
local function GetCopySources()
    local names = { GetString(SI_WAYSHRINEARROW_COPY_ACCOUNT_WIDE) }
    local ids = { ACCOUNT_WIDE_KEY }
    local others = {}
    local ownId = GetCurrentCharacterId()
    for key, entry in pairs(GetRawAccountTable()) do
        if key ~= ACCOUNT_WIDE_KEY and key ~= ownId and type(entry) == "table" and entry.useAccountWide == false then
            others[#others + 1] = { id = key, name = zo_strformat("<<1>>", entry["$LastCharacterName"] or key) }
        end
    end
    table.sort(others, function(a, b) return a.name < b.name end)
    for i = 1, #others do
        names[#names + 1] = others[i].name
        ids[#ids + 1] = others[i].id
    end
    return names, ids
end

-- Copies the settings of another character (or the account-wide ones) into this character's own settings.
-- This character uses its own settings afterwards, so the copy never changes other characters.
local function CopySettingsFrom(sourceId)
    local source = GetRawAccountTable()[sourceId]
    if not source or sourceId == GetCurrentCharacterId() then return false end
    for key, default in pairs(DEFAULTS) do
        local value = source[key]
        if value == nil then value = default end
        characterSV[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
    end
    characterSV.useAccountWide = false
    characterSV.copiedFromAccount = true
    sv = characterSV
    ApplyLayout()
    WA.CheckEvents()
    return true
end

local function SetEnabled(enabled)
    sv.enabled = enabled
    WA.CheckEvents()
end

local function SetLocked(locked)
    sv.locked = locked
    ApplyLayout()
    -- the update loop also shows the placeholder while unlocked, so it must run
    if not locked and not sv.enabled then
        SetEnabled(true)
    else
        RefreshUpdateLoop()
    end
end

function WA.ToggleEnabled()
    SetEnabled(not sv.enabled)
    Print(GetString(sv.enabled and SI_WAYSHRINEARROW_MSG_ON or SI_WAYSHRINEARROW_MSG_OFF))
end

function WA.CycleTarget()
    sv.target = sv.target % 3 + 1
    lastText = nil
    Print(zo_strformat(SI_WAYSHRINEARROW_MSG_TARGET, GetString(TARGET_STRINGS[sv.target])))
end

local function PrintDebug()
    local onMap, known, outside = 0, 0, 0
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local isKnown, _, x, y, _, _, poiType, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        if poiType == POI_TYPE_WAYSHRINE and isShownInCurrentMap then
            if IsInsideMap(x, y) then
                onMap = onMap + 1
                if isKnown then known = known + 1 end
            else
                outside = outside + 1
            end
        end
    end
    local px, py, heading = GetMapPlayerPosition("player")
    local scale = data.mapScale[GetCurrentMapId()]
    Print(string.format("map %s (id %d), wayshrines %d (known %d, unknown %d, outside %d), blocked %s",
        zo_strformat(SI_WORLD_MAP_LOCATION_NAME, GetMapName()), GetCurrentMapId(), onMap, known, onMap - known, outside,
        tostring(inBlockedArea)))
    Print(string.format("settings %s, server '%s', account %s", characterSV.useAccountWide and "account-wide" or "character",
        GetWorldName(), GetDisplayName()))
    if segment and segment.mapId == GetCurrentMapId() then
        local _, worldX, _, worldZ = GetUnitRawWorldPosition("player")
        local isInterior, worldDist, expected = CheckInterior(segment.mapId, px, py, worldX, worldZ)
        local segWorld = Distance(worldX, worldZ, segment.worldX, segment.worldZ) / 100
        local segMap = Distance(px, py, segment.x, segment.y)
        Print(string.format("interior %s: walked %.1f m / map %.5f since loading (static %s), anchor %s",
            tostring(isInterior), segWorld, segMap, tostring(segment.isStatic),
            worldDist and string.format("%.0f m, expected %.0f m", worldDist / 100, expected / 100) or "-"))
    else
        Print("interior: no sample on this map yet")
    end
    -- candidates for recognizing buildings without a loading screen
    local rawZoneId, _, rawY = GetUnitRawWorldPosition("player")
    local zoneId, _, worldY = GetUnitWorldPosition("player")
    local currentFloor, numFloors = GetMapFloorInfo()
    Print(string.format("location '%s', zone '%s', subzone '%s', unit zone '%s'",
        zo_strformat("<<1>>", GetPlayerLocationName()), zo_strformat("<<1>>", GetPlayerActiveZoneName()),
        zo_strformat("<<1>>", GetPlayerActiveSubzoneName()), zo_strformat("<<1>>", GetUnitZone("player"))))
    Print(string.format("map type %d, content %d, floor %d/%d, shows world %s, raw zone %d y %d, zone %d y %d",
        GetMapType(), GetMapContentType(), currentFloor, numFloors, tostring(DoesCurrentMapShowPlayerWorld()),
        rawZoneId, rawY, zoneId, worldY))
    Print(string.format("loading screens %d, last zone change %s", activationCount, lastZoneChange))
    Print(string.format("indoor %s, last door %s", indoor and ("yes (" .. indoor.name .. ")") or "no", lastDoor))
    Print(string.format("player %.4f / %.4f, heading %.2f, camera %.2f, scale %s",
        px, py, heading, GetPlayerCameraHeading(), scale and string.format("%.0f (span %.3f)", scale.ratio, scale.span) or "-"))
end

local settingsPanel

-- Slash commands: every setting of the settings menu is also available without LibAddonMenu-2.0.
-- Keywords are English in every language; /wsarrow help lists them.

local TARGET_KEYWORDS = { all = TARGET_ALL, unknown = TARGET_UNKNOWN, known = TARGET_KNOWN }

-- on/off settings: keyword = { setting, label of the settings menu }
local TOGGLES = {
    name = { "showName", SI_WAYSHRINEARROW_OPT_SHOW_NAME },
    status = { "showStatus", SI_WAYSHRINEARROW_OPT_SHOW_STATUS },
    distance = { "showDistance", SI_WAYSHRINEARROW_OPT_SHOW_DISTANCE },
    combat = { "hideInCombat", SI_WAYSHRINEARROW_OPT_HIDE_COMBAT },
}

-- number settings: keyword = { setting, label, min, max, factor between command value and setting }
local NUMBERS = {
    size = { "arrowSize", SI_WAYSHRINEARROW_OPT_SIZE, 24, 160, 1 },
    font = { "fontSize", SI_WAYSHRINEARROW_OPT_FONT_SIZE, 12, 36, 1 },
    alpha = { "alpha", SI_WAYSHRINEARROW_OPT_ALPHA, 20, 100, 100 },
    near = { "hideNear", SI_WAYSHRINEARROW_OPT_HIDE_NEAR, 0, 100, 1 },
}

local COLORS = {
    known = { "knownColor", SI_WAYSHRINEARROW_OPT_KNOWN_COLOR },
    unknown = { "unknownColor", SI_WAYSHRINEARROW_OPT_UNKNOWN_COLOR },
}

local BOOLEAN_WORDS = { on = true, off = false, ["1"] = true, ["0"] = false, an = true, aus = false }

local function OnOffText(value)
    return GetString(value and SI_WAYSHRINEARROW_VALUE_ON or SI_WAYSHRINEARROW_VALUE_OFF)
end

local function PrintSetting(labelId, valueText)
    Print(zo_strformat(SI_WAYSHRINEARROW_MSG_SET, GetString(labelId), valueText))
end

local function PrintInvalid()
    Print(GetString(SI_WAYSHRINEARROW_MSG_INVALID))
end

-- Applies a changed setting: layout settings resize the arrow, the combat setting needs other events.
local function ApplySetting(key)
    if key == "hideInCombat" then
        WA.CheckEvents()
    elseif key == "arrowSize" or key == "fontSize" or key == "alpha" then
        ApplyLayout()
    end
    lastText = nil
end

local function ColorToHex(color)
    return string.format("%02X%02X%02X", floor(color[1] * 255 + 0.5), floor(color[2] * 255 + 0.5),
        floor(color[3] * 255 + 0.5))
end

local function PrintHelp()
    for line in string.gmatch(GetString(SI_WAYSHRINEARROW_HELP), "[^\n]+") do
        d(line)
    end
end

local function PrintSettings()
    Print(zo_strformat(SI_WAYSHRINEARROW_MSG_INFO_HEADER,
        GetString(characterSV.useAccountWide and SI_WAYSHRINEARROW_SCOPE_ACCOUNT or SI_WAYSHRINEARROW_SCOPE_CHARACTER)))
    PrintSetting(SI_WAYSHRINEARROW_OPT_ENABLED, OnOffText(sv.enabled))
    PrintSetting(SI_WAYSHRINEARROW_OPT_TARGET, GetString(TARGET_STRINGS[sv.target]))
    PrintSetting(SI_WAYSHRINEARROW_OPT_LOCKED, OnOffText(sv.locked))
    for _, keyword in ipairs({ "name", "status", "distance", "combat" }) do
        local toggle = TOGGLES[keyword]
        PrintSetting(toggle[2], OnOffText(sv[toggle[1]]))
    end
    for _, keyword in ipairs({ "near", "size", "font", "alpha" }) do
        local number = NUMBERS[keyword]
        PrintSetting(number[2], tostring(floor(sv[number[1]] * number[5] + 0.5)))
    end
    for _, keyword in ipairs({ "known", "unknown" }) do
        local color = COLORS[keyword]
        PrintSetting(color[2], ColorToHex(sv[color[1]]))
    end
end

-- /wsarrow copy: list the sources; /wsarrow copy <character name | account>: copy from it
local function CopyCommand(rest)
    local names, ids = GetCopySources()
    if rest == "" then
        Print(zo_strformat(SI_WAYSHRINEARROW_MSG_COPY_SOURCES, table.concat(names, ", ")))
        return
    end
    local wanted = zo_strlower(rest)
    for i = 1, #ids do
        local matches = zo_strlower(names[i]) == wanted or (wanted == "account" and ids[i] == ACCOUNT_WIDE_KEY)
        if matches and CopySettingsFrom(ids[i]) then
            Print(zo_strformat(SI_WAYSHRINEARROW_MSG_COPIED, names[i]))
            return
        end
    end
    Print(zo_strformat(SI_WAYSHRINEARROW_MSG_COPY_UNKNOWN, rest))
end

local function SetColorCommand(value)
    local which, hex = value:match("^(%S+)%s*(%S*)$")
    local color = which and COLORS[which]
    if not color then
        PrintInvalid()
        return
    end
    local key, labelId = color[1], color[2]
    if hex == "reset" then
        sv[key] = ZO_DeepTableCopy(DEFAULTS[key])
    else
        local r, g, b = hex:gsub("^#", ""):match("^(%x%x)(%x%x)(%x%x)$")
        if not r then
            PrintInvalid()
            return
        end
        sv[key] = { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, 1 }
    end
    ApplySetting(key)
    PrintSetting(labelId, ColorToHex(sv[key]))
end

local function OnSlashCommand(args)
    local cmd, rest = zo_strtrim(args or ""):match("^(%S*)%s*(.-)$")
    cmd = zo_strlower(cmd)
    local value = zo_strlower(rest)

    if cmd == "" then
        WA.ToggleEnabled()
    elseif cmd == "on" or cmd == "off" then
        SetEnabled(cmd == "on")
        Print(GetString(sv.enabled and SI_WAYSHRINEARROW_MSG_ON or SI_WAYSHRINEARROW_MSG_OFF))
    elseif cmd == "lock" then
        SetLocked(true)
        Print(GetString(SI_WAYSHRINEARROW_MSG_LOCKED))
    elseif cmd == "unlock" then
        SetLocked(false)
        Print(GetString(SI_WAYSHRINEARROW_MSG_UNLOCKED))
    elseif cmd == "reset" then
        sv.posX, sv.posY = DEFAULTS.posX, DEFAULTS.posY
        ApplyLayout()
        Print(GetString(SI_WAYSHRINEARROW_MSG_RESET))
    elseif cmd == "target" then
        if value == "" then
            WA.CycleTarget()
        elseif TARGET_KEYWORDS[value] then
            sv.target = TARGET_KEYWORDS[value]
            lastText = nil
            Print(zo_strformat(SI_WAYSHRINEARROW_MSG_TARGET, GetString(TARGET_STRINGS[sv.target])))
        else
            PrintInvalid()
        end
    elseif TOGGLES[cmd] then
        local key, labelId = TOGGLES[cmd][1], TOGGLES[cmd][2]
        local enabled = BOOLEAN_WORDS[value]
        if value == "" then enabled = not sv[key] end
        if enabled == nil then
            PrintInvalid()
        else
            sv[key] = enabled
            ApplySetting(key)
            PrintSetting(labelId, OnOffText(enabled))
        end
    elseif NUMBERS[cmd] then
        local key, labelId, min, max, factor = unpack(NUMBERS[cmd])
        local number = tonumber(value)
        if not number then
            PrintInvalid()
        else
            number = zo_clamp(floor(number + 0.5), min, max)
            sv[key] = number / factor
            ApplySetting(key)
            PrintSetting(labelId, tostring(number))
        end
    elseif cmd == "color" then
        SetColorCommand(value)
    elseif cmd == "account" then
        SetUseAccountWide(true)
        Print(GetString(SI_WAYSHRINEARROW_MSG_ACCOUNT))
    elseif cmd == "character" then
        SetUseAccountWide(false)
        Print(GetString(SI_WAYSHRINEARROW_MSG_CHARACTER))
    elseif cmd == "copy" then
        CopyCommand(rest)
    elseif cmd == "show" then
        PrintSettings()
    elseif cmd == "debug" then
        PrintDebug()
    elseif cmd == "settings" and settingsPanel then
        LibAddonMenu2:OpenToPanel(settingsPanel)
    elseif cmd == "settings" then
        Print(GetString(SI_WAYSHRINEARROW_MSG_NO_LAM))
    else
        PrintHelp()
    end
end

------------------------------------------------------------------------------------------------
-- Settings (LibAddonMenu-2.0 is optional)
------------------------------------------------------------------------------------------------

local function CreateSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    settingsPanel = LAM:RegisterAddonPanel("WayshrineArrow_Settings", {
        type = "panel",
        name = "WayshrineArrow",
        displayName = "Wayshrine Arrow",
        author = "cudddel",
        version = WA.version,
        slashCommand = "/wsarrowsettings",
        registerForRefresh = true,
    })

    -- other characters are only known from the SavedVariables, so the list is built once when the panel is created
    local copyNames, copyIds = GetCopySources()
    local copyFrom = copyIds[1]

    local function refreshText()
        lastText = nil
    end

    local function colorOption(nameId, key)
        return {
            type = "colorpicker",
            name = GetString(nameId),
            getFunc = function() return unpack(sv[key]) end,
            setFunc = function(r, g, b, a)
                sv[key] = { r, g, b, a }
                refreshText()
            end,
            default = ZO_ColorDef:New(unpack(DEFAULTS[key])),
        }
    end

    local function checkbox(nameId, key, tooltipId)
        return {
            type = "checkbox",
            name = GetString(nameId),
            tooltip = tooltipId and GetString(tooltipId) or nil,
            getFunc = function() return sv[key] end,
            setFunc = function(value)
                sv[key] = value
                refreshText()
            end,
            default = DEFAULTS[key],
        }
    end

    LAM:RegisterOptionControls("WayshrineArrow_Settings", {
        { type = "description", text = GetString(SI_WAYSHRINEARROW_OPT_INFO) },
        {
            type = "checkbox",
            name = GetString(SI_WAYSHRINEARROW_OPT_ACCOUNT_WIDE),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_ACCOUNT_WIDE_TT),
            getFunc = function() return characterSV.useAccountWide end,
            setFunc = SetUseAccountWide,
            default = CHARACTER_DEFAULTS.useAccountWide,
        },
        {
            type = "dropdown",
            name = GetString(SI_WAYSHRINEARROW_OPT_COPY_FROM),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_COPY_FROM_TT),
            choices = copyNames,
            choicesValues = copyIds,
            getFunc = function() return copyFrom end,
            setFunc = function(value) copyFrom = value end,
            scrollable = true,
        },
        {
            type = "button",
            name = GetString(SI_WAYSHRINEARROW_OPT_COPY),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_COPY_TT),
            isDangerous = true,
            warning = GetString(SI_WAYSHRINEARROW_OPT_COPY_WARNING),
            func = function()
                if CopySettingsFrom(copyFrom) then
                    for i = 1, #copyIds do
                        if copyIds[i] == copyFrom then
                            Print(zo_strformat(SI_WAYSHRINEARROW_MSG_COPIED, copyNames[i]))
                        end
                    end
                end
            end,
        },
        {
            type = "checkbox",
            name = GetString(SI_WAYSHRINEARROW_OPT_ENABLED),
            getFunc = function() return sv.enabled end,
            setFunc = SetEnabled,
            default = DEFAULTS.enabled,
        },
        {
            type = "dropdown",
            name = GetString(SI_WAYSHRINEARROW_OPT_TARGET),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_TARGET_TT),
            choices = {
                GetString(SI_WAYSHRINEARROW_TARGET_ALL),
                GetString(SI_WAYSHRINEARROW_TARGET_UNKNOWN),
                GetString(SI_WAYSHRINEARROW_TARGET_KNOWN),
            },
            choicesValues = { TARGET_ALL, TARGET_UNKNOWN, TARGET_KNOWN },
            getFunc = function() return sv.target end,
            setFunc = function(value)
                sv.target = value
                refreshText()
            end,
            width = "full",
            default = DEFAULTS.target,
        },
        {
            type = "checkbox",
            name = GetString(SI_WAYSHRINEARROW_OPT_HIDE_COMBAT),
            getFunc = function() return sv.hideInCombat end,
            setFunc = function(value)
                sv.hideInCombat = value
                WA.CheckEvents()
            end,
            default = DEFAULTS.hideInCombat,
        },
        {
            type = "slider",
            name = GetString(SI_WAYSHRINEARROW_OPT_HIDE_NEAR),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_HIDE_NEAR_TT),
            min = 0, max = 100, step = 5,
            getFunc = function() return sv.hideNear end,
            setFunc = function(value) sv.hideNear = value end,
            default = DEFAULTS.hideNear,
        },
        {
            type = "checkbox",
            name = GetString(SI_WAYSHRINEARROW_OPT_LOCKED),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_LOCKED_TT),
            getFunc = function() return sv.locked end,
            setFunc = SetLocked,
            default = DEFAULTS.locked,
        },
        {
            type = "button",
            name = GetString(SI_WAYSHRINEARROW_OPT_RESET),
            func = function()
                sv.posX, sv.posY = DEFAULTS.posX, DEFAULTS.posY
                ApplyLayout()
            end,
        },
        { type = "header", name = GetString(SI_WAYSHRINEARROW_OPT_HEADER_DISPLAY) },
        checkbox(SI_WAYSHRINEARROW_OPT_SHOW_NAME, "showName"),
        checkbox(SI_WAYSHRINEARROW_OPT_SHOW_STATUS, "showStatus"),
        checkbox(SI_WAYSHRINEARROW_OPT_SHOW_DISTANCE, "showDistance", SI_WAYSHRINEARROW_OPT_SHOW_DISTANCE_TT),
        colorOption(SI_WAYSHRINEARROW_OPT_KNOWN_COLOR, "knownColor"),
        colorOption(SI_WAYSHRINEARROW_OPT_UNKNOWN_COLOR, "unknownColor"),
        {
            type = "slider",
            name = GetString(SI_WAYSHRINEARROW_OPT_SIZE),
            min = 24, max = 160, step = 4,
            getFunc = function() return sv.arrowSize end,
            setFunc = function(value)
                sv.arrowSize = value
                ApplyLayout()
            end,
            default = DEFAULTS.arrowSize,
        },
        {
            type = "slider",
            name = GetString(SI_WAYSHRINEARROW_OPT_FONT_SIZE),
            min = 12, max = 36, step = 1,
            getFunc = function() return sv.fontSize end,
            setFunc = function(value)
                sv.fontSize = value
                ApplyLayout()
            end,
            default = DEFAULTS.fontSize,
        },
        {
            type = "slider",
            name = GetString(SI_WAYSHRINEARROW_OPT_ALPHA),
            min = 20, max = 100, step = 5,
            getFunc = function() return floor(sv.alpha * 100 + 0.5) end,
            setFunc = function(value)
                sv.alpha = value / 100
                ApplyLayout()
            end,
            default = DEFAULTS.alpha * 100,
        },
    })
end

------------------------------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- one profile per server, separate for every account (ZO_SavedVars adds GetDisplayName())
    accountSV = ZO_SavedVars:NewAccountWide("WayshrineArrow_Saved", 1, nil, ACCOUNT_DEFAULTS, GetWorldName())
    characterSV = ZO_SavedVars:NewCharacterIdSettings("WayshrineArrow_Saved", 1, nil, CHARACTER_DEFAULTS, GetWorldName())
    data = accountSV
    sv = characterSV.useAccountWide and accountSV or characterSV
    -- map scales from 0.1.0 have no anchor and may have been measured across a building door: measure again
    for mapId, entry in pairs(data.mapScale) do
        if entry.worldX == nil then
            data.mapScale[mapId] = nil
        end
    end

    CreateControls()
    ApplyLayout()
    CreateSettings()
    SLASH_COMMANDS["/wsarrow"] = OnSlashCommand
    WA.CheckEvents()
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
