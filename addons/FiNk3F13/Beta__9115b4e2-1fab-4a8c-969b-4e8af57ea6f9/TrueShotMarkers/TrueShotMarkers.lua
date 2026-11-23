-- Independent ESO addon. No CrutchAlerts, group messaging or DPS changes.
local NAME, TRUE_SHOT, ZONE = "TrueShotMarkers", 184802, 1427
local EM = EVENT_MANAGER
local T = { casts = {}, markers = {}, ids = {}, tagIds = {}, enabled = true }
TrueShotMarkers = T
local running, registered, serial = false, false, 0
local settings

local function UnitName(tag)
    return zo_strformat("<<1>>", GetUnitName(tag) or "")
end

local function Identity(tag)
    return GetUnitDisplayName(tag) .. "/" .. UnitName(tag)
end

local function IsPlayerTag(tag)
    return tag == "player" or (type(tag) == "string" and tag:match("^group%d+$") ~= nil)
end

local function ValidUnit(tag)
    return IsPlayerTag(tag) and DoesUnitExist(tag) and not IsUnitDead(tag)
        and (tag == "player" or (IsUnitOnline(tag)
            and IsGroupMemberInSameWorldAsPlayer(tag)
            and IsGroupMemberInSameInstanceAsPlayer(tag)))
end

local function ResolveTarget(id, name, kind)
    if kind == COMBAT_UNIT_TYPE_PLAYER then return "player" end
    local entry = T.ids[id]
    if entry and ValidUnit(entry.tag) and Identity(entry.tag) == entry.identity then
        if AreUnitsEqual(entry.tag, "player") then return "player" end
        return entry.tag
    end
    -- Combat events carry character names; this also works before the first buff event.
    local wanted = zo_strformat("<<1>>", name or "")
    if wanted == "" then return nil end
    local found
    for i = 0, GetGroupSize() do
        local tag = i == 0 and "player" or GetGroupUnitTagByIndex(i)
        if tag and ValidUnit(tag) and (wanted == UnitName(tag) or wanted == GetUnitDisplayName(tag)) then
            if found and not AreUnitsEqual(found, tag) then return nil end
            found = tag
        end
    end
    if found and AreUnitsEqual(found, "player") then return "player" end
    return found
end

local function HideMarkers()
    for _, marker in pairs(T.markers) do
        marker.control:SetHidden(true)
        marker.shown = false
        marker.x, marker.y, marker.z, marker.lastMS = nil, nil, nil, nil
    end
end

function T.Clear()
    T.casts = {}
    HideMarkers()
    EM:UnregisterForUpdate(NAME .. "Update")
    TrueShotMarkersRoot:SetHandler("OnUpdate", nil)
    EM:UnregisterForUpdate(NAME .. "Preview")
    running = false
end

local function GetMarker(tag, identity)
    -- Reuse one control per group slot; never create controls per combat event.
    local marker = T.markers[tag]
    if not marker then
        serial = serial + 1
        local control = WINDOW_MANAGER:CreateControlFromVirtual(NAME .. "World" .. serial,
            TrueShotMarkersRoot, NAME .. "World")
        control:SetTransformNormalizedOriginPoint(0.5, 0.5)
        marker = { control = control, timer = control:GetNamedChild("Timer"),
            arrow = control:GetNamedChild("Arrow") }
        T.markers[tag] = marker
    end
    if marker.identity ~= identity then marker.x, marker.y, marker.z, marker.lastMS = nil, nil, nil, nil end
    marker.identity = identity
    return marker
end

function T.Update()
    local now = GetGameTimeMilliseconds()
    local targets = {}
    for key, cast in pairs(T.casts) do
        if now >= cast.finish or not ValidUnit(cast.tag) or Identity(cast.tag) ~= cast.identity then
            T.casts[key] = nil
        else
            local target = targets[cast.tag]
            if not target then
                targets[cast.tag] = { finish = cast.finish, count = 1, identity = cast.identity }
            else
                target.finish = math.min(target.finish, cast.finish)
                target.count = target.count + 1
            end
        end
    end
    for _, marker in pairs(T.markers) do marker.active = false end
    if not next(T.casts) then
        HideMarkers()
        EM:UnregisterForUpdate(NAME .. "Update")
        TrueShotMarkersRoot:SetHandler("OnUpdate", nil)
        running = false
        return
    end

    Set3DRenderSpaceToCurrentCamera(NAME .. "Camera")
    local fx, fy, fz = TrueShotMarkersCamera:Get3DRenderSpaceForward()
    local pitch = zo_atan2(fy, math.sqrt(fx * fx + fz * fz))
    local yaw = zo_atan2(fx, fz) - math.pi
    local ox, _, oz = GuiRender3DPositionToWorldPosition(0, 0, 0)
    local playerZone = GetUnitRawWorldPosition("player")
    for tag, target in pairs(targets) do
        local zone, x, y, z = GetUnitRawWorldPosition(tag)
        if zone == playerZone and zone ~= 0 and not (x == 0 and y == 0 and z == 0) then
            local marker = GetMarker(tag, target.identity)
            local seconds = (target.finish - now) / 1000
            local text = string.format("%.1f", math.ceil(seconds * 10) / 10)
            if target.count > 1 then text = text .. " x" .. target.count end
            if marker.text ~= text then marker.timer:SetText(text); marker.text = text end
            local r, g, b, a = unpack(settings.color)
            if settings.warnRed and seconds <= 1 then r, g, b = 1, 0.12, 0.08 end
            marker.timer:SetColor(r, g, b, a)
            marker.arrow:SetColor(r, g, b, a)
            -- Raw world units are centimeters; WORLD transforms use meters.
            -- Direct attachment: no smoothing delay or lateral sway relative to the player.
            marker.control:SetTransformScale(0.007 * settings.size / 100)
            marker.control:SetTransformOffset((x - ox) / 100, (y + settings.height) / 100, (z - oz) / 100)
            marker.control:SetTransformRotation(pitch, yaw, 0)
            if not marker.shown then marker.control:SetHidden(false); marker.shown = true end
            marker.active = true
        end
    end
    for _, marker in pairs(T.markers) do
        if not marker.active and marker.shown then
            marker.control:SetHidden(true); marker.shown = false
            marker.x, marker.y, marker.z, marker.lastMS = nil, nil, nil, nil
        end
    end
end

local function Start(key, sourceId, targetId, tag, duration)
    if not ValidUnit(tag) then return end
    T.casts[key] = { sourceId = sourceId, targetId = targetId, tag = tag,
        identity = Identity(tag), finish = GetGameTimeMilliseconds() + duration }
    if not running then
        TrueShotMarkersRoot:SetHandler("OnUpdate", T.Update)
        running = true
    end
    T.Update()
end

local function CancelCaster(id)
    if not id or id == 0 then return end
    for key, cast in pairs(T.casts) do
        if cast.sourceId == id then T.casts[key] = nil end
    end
end

local function OnShot(_, result, isError, _, _, _, _, _, targetName, targetType,
        hitValue, _, _, _, sourceId, targetId)
    if isError or not T.enabled then return end
    if result == ACTION_RESULT_BEGIN then
        if not sourceId or sourceId == 0 then return end
        local tag = ResolveTarget(targetId, targetName, targetType)
        if not tag then return end
        local duration = hitValue
        if type(duration) ~= "number" or duration < 100 or duration > 30000 then
            local channeled, castTime, channelTime = GetAbilityCastInfo(TRUE_SHOT)
            duration = channeled and channelTime or castTime
        end
        -- Do not invent a countdown if ESO supplied no usable duration.
        if type(duration) ~= "number" or duration < 100 or duration > 30000 then return end
        Start(sourceId, sourceId, targetId, tag, duration)
    elseif result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_DAMAGE_SHIELDED
        or result == ACTION_RESULT_DODGED or result == ACTION_RESULT_MISS
        or result == ACTION_RESULT_PARRIED or result == ACTION_RESULT_IMMUNE
        or result == ACTION_RESULT_REFLECTED or result == ACTION_RESULT_BLOCKED then
        CancelCaster(sourceId)
        if running then T.Update() end
    end
end

local function OnInterrupt(_, _, isError, _, _, _, _, _, _, _, _, _, _, _, _, targetId)
    if isError then return end
    -- The TARGET of the interrupt is the archer, regardless of the interrupt skill ID.
    CancelCaster(targetId)
    if running then T.Update() end
end

local function OnDeath(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, targetId)
    CancelCaster(targetId)
    for key, cast in pairs(T.casts) do
        if cast.targetId == targetId then T.casts[key] = nil end
    end
    if running then T.Update() end
end

local function CacheUnit(_, _, _, _, tag, _, _, _, _, _, _, _, _, _, id)
    if IsPlayerTag(tag) and DoesUnitExist(tag) and id and id ~= 0 then
        local oldId = T.tagIds[tag]
        if oldId and oldId ~= id then T.ids[oldId] = nil end
        T.tagIds[tag] = id
        T.ids[id] = { tag = tag, identity = Identity(tag) }
    end
end

local stopResults = {
    { ACTION_RESULT_INTERRUPT, "Interrupt" },
    { ACTION_RESULT_STUNNED, "Stunned" },
    { ACTION_RESULT_FEARED, "Feared" },
}

local function RefreshZone()
    T.Clear()
    T.ids = {}
    T.tagIds = {}
    local active = T.enabled and GetZoneId(GetUnitZoneIndex("player")) == ZONE
    if active == registered then return end
    registered = active
    if active then
        EM:RegisterForEvent(NAME .. "Effects", EVENT_EFFECT_CHANGED, CacheUnit)
        EM:AddFilterForEvent(NAME .. "Effects", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
        EM:RegisterForEvent(NAME .. "PlayerEffects", EVENT_EFFECT_CHANGED, CacheUnit)
        EM:AddFilterForEvent(NAME .. "PlayerEffects", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "player")
        EM:RegisterForEvent(NAME .. "Shot", EVENT_COMBAT_EVENT, OnShot)
        EM:AddFilterForEvent(NAME .. "Shot", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, TRUE_SHOT)
        for _, entry in ipairs(stopResults) do
            EM:RegisterForEvent(NAME .. entry[2], EVENT_COMBAT_EVENT, OnInterrupt)
            EM:AddFilterForEvent(NAME .. entry[2], EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, entry[1])
        end
        for _, entry in ipairs({ { ACTION_RESULT_DIED, "Died" }, { ACTION_RESULT_DIED_XP, "DiedXP" } }) do
            EM:RegisterForEvent(NAME .. entry[2], EVENT_COMBAT_EVENT, OnDeath)
            EM:AddFilterForEvent(NAME .. entry[2], EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, entry[1])
        end
    else
        EM:UnregisterForEvent(NAME .. "Effects", EVENT_EFFECT_CHANGED)
        EM:UnregisterForEvent(NAME .. "PlayerEffects", EVENT_EFFECT_CHANGED)
        for _, suffix in ipairs({ "Shot", "Interrupt", "Stunned", "Feared", "Died", "DiedXP" }) do
            EM:UnregisterForEvent(NAME .. suffix, EVENT_COMBAT_EVENT)
        end
    end
end

local function Preview()
    T.Clear()
    local function Ready()
        return not SCENE_MANAGER or not SCENE_MANAGER.IsShowing
            or SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
    end
    local function Show() Start("test:player", -1, -1, "player", 15000) end
    if Ready() then Show(); return end
    local deadline = GetGameTimeMilliseconds() + 60000
    EM:RegisterForUpdate(NAME .. "Preview", 100, function()
        if GetGameTimeMilliseconds() >= deadline then EM:UnregisterForUpdate(NAME .. "Preview")
        elseif Ready() then EM:UnregisterForUpdate(NAME .. "Preview"); Show() end
    end)
    d("TrueShotMarkers: Einstellungen schließen, dann startet die 15-Sekunden-Vorschau.")
end

local function CreateSettings()
    local lib = LibHarvensAddonSettings
    local menu = lib:AddAddon(NAME, { allowDefaults = false, allowRefresh = true })
    if not menu then return end
    local function RefreshAppearance() if running then T.Update() end end
    menu:AddSettings({
        { type = lib.ST_LABEL, label = "Timer und Pfeil direkt am Spieler, ohne verzögertes Nachziehen" },
        { type = lib.ST_SLIDER, label = "Markergröße (%)", min = 50, max = 250, step = 5,
            getFunction = function() return settings.size end,
            setFunction = function(v) settings.size = v; RefreshAppearance() end },
        { type = lib.ST_SLIDER, label = "Höhe über Spieler (cm)", min = 100, max = 600, step = 10,
            tooltip = "Höherer Wert setzt Timer und Pfeil weiter nach oben. Niedrigerer Wert setzt sie tiefer.",
            getFunction = function() return settings.height end,
            setFunction = function(v) settings.height = v; RefreshAppearance() end },
        { type = lib.ST_COLOR, label = "Markerfarbe",
            tooltip = "Gemeinsame Farbe für Countdown und Pfeil.",
            getFunction = function() return unpack(settings.color) end,
            setFunction = function(r,g,b,a) settings.color = {r,g,b,a or 1}; RefreshAppearance() end },
        { type = lib.ST_CHECKBOX, label = "Letzte Sekunde rot anzeigen",
            getFunction = function() return settings.warnRed end,
            setFunction = function(v) settings.warnRed = v; RefreshAppearance() end },
        { type = lib.ST_BUTTON, label = "Vorschau starten", buttonText = "15 Sekunden über dir", clickHandler = Preview },
        { type = lib.ST_BUTTON, label = "Vorschau beenden", buttonText = "Marker ausblenden", clickHandler = T.Clear },
    }, nil, false)
end

local function Command(text)
    text = zo_strlower(text or "")
    if text == "aus" or text == "off" then
        T.enabled = false
        RefreshZone()
        d("TrueShotMarkers: aus.")
    elseif text == "an" or text == "on" then
        T.enabled = true
        RefreshZone()
        d("TrueShotMarkers: an (Rand des Wahnsinns).")
    elseif text == "stop" then
        T.Clear()
    elseif text:match("^test") then
        local tag = text:match("^test%s+(group%d+)$") or "player"
        Start("test:" .. tag, -1, -1, tag, 5000)
        d("TrueShotMarkers: 5 Sekunden Test auf " .. tag .. ".")
    else
        d("TrueShotMarkers 1.0.2: " .. (registered and "aktiv in Rand des Wahnsinns" or "wartet auf Rand des Wahnsinns")
            .. ". /tshot test | test group1 | stop | an | aus")
    end
end

local function Initialize(_, addon)
    if addon ~= NAME then return end
    EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide("TrueShotMarkersSavedVariables", 1, nil,
        { size = 125, height = 280, color = {1,0.7,0.08,1}, warnRed = false })
    TrueShotMarkersCamera:Create3DRenderSpace()
    CreateSettings()
    SLASH_COMMANDS["/tshot"] = Command
    EM:RegisterForEvent(NAME .. "Zone", EVENT_PLAYER_ACTIVATED, RefreshZone)
    EM:RegisterForEvent(NAME .. "Leave", EVENT_PLAYER_DEACTIVATED, T.Clear)
    EM:RegisterForEvent(NAME .. "Group", EVENT_GROUP_UPDATE, function()
        T.Clear(); T.ids = {}; T.tagIds = {}
    end)
    EM:RegisterForEvent(NAME .. "Combat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then T.Clear() end
    end)
    RefreshZone()
end
EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
