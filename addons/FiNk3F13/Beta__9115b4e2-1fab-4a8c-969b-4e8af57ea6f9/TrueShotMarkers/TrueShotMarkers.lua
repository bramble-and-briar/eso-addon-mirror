-- Independent ESO addon. No CrutchAlerts, group messaging or DPS changes.
local NAME, TRUE_SHOT, ZONE = "TrueShotMarkers", 184802, 1427
local EM = EVENT_MANAGER
local T = { casts = {}, corpses = {}, markers = {}, ids = {}, tagIds = {}, enabled = true }
TrueShotMarkers = T
local running, registered, serial = false, false, 0
local settings
local wamasuChargeAbilities = {
    [191133] = true, -- Boss charge
    [200544] = true, -- Trash charge windup
}
local trashImpact = 200558
local bossImpact = 191139
local chargeImpacts = { [bossImpact] = true, [trashImpact] = true }
local lastFatalHit
local wamasuIds = {}
local ownDeath, lastDeath
local lastChargeHit
local ownImpact

local function StopDeathCheck()
    ownDeath = nil
    EM:UnregisterForUpdate(NAME .. "DeathCheck")
end

local function UnitName(tag)
    return zo_strformat("<<1>>", GetUnitName(tag) or "")
end

local function Identity(tag)
    return GetUnitDisplayName(tag) .. "/" .. UnitName(tag)
end

local function IsPlayerTag(tag)
    return tag == "player" or (type(tag) == "string" and tag:match("^group%d+$") ~= nil)
end

local function UnitProblem(tag, allowDead)
    if not IsPlayerTag(tag) or not DoesUnitExist(tag) then return "Gruppenplatz ist leer." end
    if not allowDead and IsUnitDead(tag) then return "Spieler ist tot." end
    if tag ~= "player" then
        if not IsUnitOnline(tag) then return "Spieler ist offline." end
        if not IsGroupMemberInSameWorldAsPlayer(tag) then return "Spieler ist in einer anderen Welt." end
        if not IsGroupMemberInSameInstanceAsPlayer(tag) then return "ESO meldet eine andere Instanz." end
    end
end

local function ValidUnit(tag)
    return UnitProblem(tag) == nil
end

local function MarkerPosition(tag, playerZone)
    local zone, x, y, z = GetUnitRawWorldPosition(tag)
    if zone and zone ~= 0 and zone == playerZone and x and y and z and (x ~= 0 or y ~= 0 or z ~= 0) then
        return x, y, z
    end
end

local function ResolveTarget(id, name, kind, allowDead)
    if kind == COMBAT_UNIT_TYPE_PLAYER then return "player" end
    local entry = T.ids[id]
    if entry and not UnitProblem(entry.tag, allowDead) and Identity(entry.tag) == entry.identity then
        if AreUnitsEqual(entry.tag, "player") then return "player" end
        return entry.tag
    end
    -- Combat events carry character names; this also works before the first buff event.
    local wanted = zo_strformat("<<1>>", name or "")
    if wanted == "" then return nil end
    local found
    for i = 0, GetGroupSize() do
        local tag = i == 0 and "player" or GetGroupUnitTagByIndex(i)
        if tag and not UnitProblem(tag, allowDead) and (wanted == UnitName(tag) or wanted == GetUnitDisplayName(tag)) then
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
    ownImpact = nil
    StopDeathCheck()
    T.casts = {}
    T.corpses = {}
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
    for tag, corpse in pairs(T.corpses) do
        if UnitProblem(tag, true) or Identity(tag) ~= corpse.identity or IsUnitReincarnating(tag) then
            T.corpses[tag] = nil
        elseif IsUnitDead(tag) then
            corpse.confirmed = true
            targets[tag] = corpse
        elseif corpse.confirmed or now >= corpse.deadline then
            T.corpses[tag] = nil
        end
    end
    if not next(T.casts) and not next(T.corpses) then
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
        local x, y, z = MarkerPosition(tag, playerZone)
        if tag == "player" and target.confirmed then
            local death = ownDeath
            if x and death then
                death.x, death.y, death.z = x, y, z
            elseif death then
                x, y, z = death.x, death.y, death.z
            end
            if death then death.position = x and "vorhanden" or "fehlt" end
        end
        if x then
            local marker = GetMarker(tag, target.identity)
            local seconds, text
            if target.finish then
                seconds = (target.finish - now) / 1000
                text = string.format("%.1f", math.ceil(seconds * 10) / 10)
                if target.count > 1 then text = text .. " x" .. target.count end
            else
                text = "Bodeninspektor"
            end
            if marker.text ~= text then marker.timer:SetText(text); marker.text = text end
            local r, g, b, a = unpack(settings.color)
            if settings.warnRed and seconds and seconds <= 1 then r, g, b = 1, 0.12, 0.08 end
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

local function UpdateMarkers()
    if not running then
        TrueShotMarkersRoot:SetHandler("OnUpdate", T.Update)
        running = true
    end
    T.Update()
end

local function Start(key, sourceId, targetId, tag, duration)
    if not ValidUnit(tag) then return end
    T.casts[key] = { sourceId = sourceId, targetId = targetId, tag = tag,
        identity = Identity(tag), finish = GetGameTimeMilliseconds() + duration }
    UpdateMarkers()
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

local function IsWamasu(sourceName, abilityId)
    return chargeImpacts[abilityId]
        or zo_strlower(sourceName or ""):find("%f[%a]wamasu%f[%A]") ~= nil
end

local function OnWamasuCharge(_, _, isError, _, _, _, _, sourceType, _, _, _, _, _, _, sourceId)
    if not isError and sourceId and sourceId ~= 0
        and (sourceType == COMBAT_UNIT_TYPE_OTHER or sourceType == COMBAT_UNIT_TYPE_NONE) then
        wamasuIds[sourceId] = true
    end
end

local function MarkCorpse(tag)
    if not settings.showCorpseMarker then return "ausgeschaltet" end
    if not tag then return "Spieler unbekannt" end
    local problem = UnitProblem(tag, true)
    if problem then return problem end
    if IsUnitReincarnating(tag) then return "Geistform" end
    if T.corpses[tag] and T.corpses[tag].identity == Identity(tag) then return "zugeordnet" end
    -- The killing blow can arrive shortly before the group unit's dead flag.
    T.corpses[tag] = { identity = Identity(tag), deadline = GetGameTimeMilliseconds() + 1500 }
    UpdateMarkers()
    return "zugeordnet"
end

local function OnOwnDamage(_, result, err, attack, _, _, name, kind, _, targetType, amount, _, _, _, sourceId, _, abilityId)
    if err or targetType ~= COMBAT_UNIT_TYPE_PLAYER or (result ~= ACTION_RESULT_DAMAGE
        and result ~= ACTION_RESULT_CRITICAL_DAMAGE and result ~= ACTION_RESULT_BLOCKED_DAMAGE
        and result ~= ACTION_RESULT_DAMAGE_SHIELDED) then return end
    local shielded = result == ACTION_RESULT_DAMAGE_SHIELDED
    if not shielded then ownImpact = nil end
    if (kind == COMBAT_UNIT_TYPE_OTHER or kind == COMBAT_UNIT_TYPE_NONE)
        and abilityId and abilityId > 0 and not wamasuChargeAbilities[abilityId]
        and (IsWamasu(name, abilityId) or wamasuIds[sourceId]) then
        if not shielded then ownImpact = { id = abilityId, time = GetGameTimeMilliseconds() } end
        if abilityId == bossImpact then return end -- Display the boss charge only on confirmed death.
        if not attack or attack == "" then attack = GetAbilityName(abilityId) end
        local label = zo_strformat("<<1>>", attack or "")
        local normalized = zo_strlower(label)
        if chargeImpacts[abilityId] or normalized == "ansturm" or normalized == "charge"
            or (label ~= "" and label == zo_strformat("<<1>>", GetAbilityName(trashImpact))) then
            lastChargeHit = string.format("TrueShotMarkers – Wamasu trifft dich: %s [%d], %d %s.",
                label ~= "" and label or "Ansturm", abilityId, amount, shielded and "absorbiert" or "Schaden")
            d(lastChargeHit)
        end
    end
end

local function CheckDeathRecap()
    local death = ownDeath
    if not death then return end
    if IsUnitReincarnating("player") then StopDeathCheck(); return end
    if GetGameTimeMilliseconds() >= death.deadline then
        EM:UnregisterForUpdate(NAME .. "DeathCheck")
    end
    if not IsUnitDead("player") then return end
    death.entries = GetNumKillingAttacks()
    for i = 1, death.entries do
        local attack, _, _, fatal, _, _, _, abilityId = GetKillingAttackInfo(i)
        if fatal then
            local name, isPlayer
            if DoesKillingAttackHaveAttacker(i) then
                local attacker, _, _, _, player = GetKillingAttackerInfo(i)
                name, isPlayer = attacker, player
            end
            death.hit = string.format("%s [%s], %s", attack or "", tostring(abilityId), name or "unbekannte Quelle")
            if abilityId and abilityId > 0 and not wamasuChargeAbilities[abilityId] and not death.reportedHit then
                lastFatalHit = UnitName("player") .. " – " .. death.hit
                death.reportedHit = true
            end
            local matchedImpact = (name or "") == "" and death.impact and death.impact.id == abilityId
            if not wamasuChargeAbilities[abilityId] and not isPlayer and (IsWamasu(name, abilityId) or matchedImpact) then
                death.assignment = MarkCorpse("player")
                if death.assignment == "zugeordnet" then EM:UnregisterForUpdate(NAME .. "DeathCheck") end
            else
                death.assignment = "kein Wamasu zugeordnet"
            end
            return
        end
    end
end

local function OnPlayerDead()
    if IsUnitReincarnating("player") then return end
    if not ownDeath then
        local x, y, z = MarkerPosition("player", GetUnitRawWorldPosition("player"))
        ownDeath = { deadline = GetGameTimeMilliseconds() + 6000, x = x, y = y, z = z, entries = 0 }
        if ownImpact and GetGameTimeMilliseconds() - ownImpact.time <= 1500 then ownDeath.impact = ownImpact end
        lastDeath = ownDeath
        EM:RegisterForUpdate(NAME .. "DeathCheck", 250, CheckDeathRecap)
    end
    CheckDeathRecap()
end

local function OnPlayerAlive()
    ownImpact = nil
    StopDeathCheck()
    if T.corpses.player then T.corpses.player = nil; T.Update() end
end

local function OnDeathState(_, tag, dead)
    if not IsPlayerTag(tag) then return end
    if AreUnitsEqual(tag, "player") then
        if dead then OnPlayerDead() else OnPlayerAlive() end
    elseif not dead and T.corpses[tag] then
        T.corpses[tag] = nil
        T.Update()
    end
end

local function OnDeath(_, _, isError, attack, _, _, sourceName, sourceType, targetName, targetType,
        _, _, _, _, sourceId, targetId, abilityId)
    if isError then return end
    if abilityId and abilityId > 0 and not wamasuChargeAbilities[abilityId] then
        local tag = ResolveTarget(targetId, targetName, targetType, true)
        if tag then
            local npc = sourceType == COMBAT_UNIT_TYPE_OTHER or sourceType == COMBAT_UNIT_TYPE_NONE
            local wamasu = npc and (IsWamasu(sourceName, abilityId) or wamasuIds[sourceId])
            local source = sourceName ~= "" and sourceName or (wamasu and "Wamasu" or "unbekannt")
            lastFatalHit = string.format("%s – %s [%d], %s", UnitName(tag), attack or "", abilityId, source)
            if wamasu then MarkCorpse(tag) end
        end
    end
    if targetId then wamasuIds[targetId] = nil end
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
    wamasuIds = {}
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
        EM:RegisterForEvent(NAME .. "OwnDeath", EVENT_PLAYER_DEAD, OnPlayerDead)
        EM:RegisterForEvent(NAME .. "OwnDamage", EVENT_COMBAT_EVENT, OnOwnDamage)
        EM:AddFilterForEvent(NAME .. "OwnDamage", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        EM:RegisterForEvent(NAME .. "DeathInfo", EVENT_PLAYER_DEATH_INFO_UPDATE, CheckDeathRecap)
        EM:RegisterForEvent(NAME .. "Alive", EVENT_PLAYER_ALIVE, OnPlayerAlive)
        EM:RegisterForEvent(NAME .. "Spirit", EVENT_PLAYER_REINCARNATED, OnPlayerAlive)
        for abilityId in pairs(wamasuChargeAbilities) do
            local key = NAME .. abilityId
            EM:RegisterForEvent(key, EVENT_COMBAT_EVENT, OnWamasuCharge)
            EM:AddFilterForEvent(key, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
        end
        EM:RegisterForEvent(NAME .. "DeathState", EVENT_UNIT_DEATH_STATE_CHANGED, OnDeathState)
        for _, entry in ipairs({ { ACTION_RESULT_DIED, "Died" }, { ACTION_RESULT_DIED_XP, "DiedXP" },
                { ACTION_RESULT_KILLING_BLOW, "KillingBlow" } }) do
            EM:RegisterForEvent(NAME .. entry[2], EVENT_COMBAT_EVENT, OnDeath)
            EM:AddFilterForEvent(NAME .. entry[2], EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, entry[1])
        end
    else
        EM:UnregisterForEvent(NAME .. "Effects", EVENT_EFFECT_CHANGED)
        EM:UnregisterForEvent(NAME .. "PlayerEffects", EVENT_EFFECT_CHANGED)
        EM:UnregisterForEvent(NAME .. "OwnDeath", EVENT_PLAYER_DEAD)
        EM:UnregisterForEvent(NAME .. "OwnDamage", EVENT_COMBAT_EVENT)
        EM:UnregisterForEvent(NAME .. "DeathInfo", EVENT_PLAYER_DEATH_INFO_UPDATE)
        EM:UnregisterForEvent(NAME .. "Alive", EVENT_PLAYER_ALIVE)
        EM:UnregisterForEvent(NAME .. "Spirit", EVENT_PLAYER_REINCARNATED)
        for abilityId in pairs(wamasuChargeAbilities) do
            EM:UnregisterForEvent(NAME .. abilityId, EVENT_COMBAT_EVENT)
        end
        EM:UnregisterForEvent(NAME .. "DeathState", EVENT_UNIT_DEATH_STATE_CHANGED)
        for _, suffix in ipairs({ "Shot", "Interrupt", "Stunned", "Feared", "Died", "DiedXP", "KillingBlow" }) do
            EM:UnregisterForEvent(NAME .. suffix, EVENT_COMBAT_EVENT)
        end
    end
end

local function Preview(tag, duration)
    local expected = Identity(tag)
    local function Ready()
        return not SCENE_MANAGER or not SCENE_MANAGER.IsShowing
            or SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
    end
    local function Show()
        local problem = UnitProblem(tag)
        if not problem and Identity(tag) ~= expected then problem = "Gruppenplatz hat gewechselt." end
        if not problem and not MarkerPosition(tag, GetUnitRawWorldPosition("player")) then
            problem = "ESO liefert keine Position in deiner Zone."
        end
        if problem then d("TrueShotMarkers: " .. expected .. " – " .. problem); return end
        Start("test:" .. tag, -1, -1, tag, duration)
        d(string.format("TrueShotMarkers: %d Sekunden über %s (%s).", duration/1000, UnitName(tag), tag))
    end
    EM:UnregisterForUpdate(NAME .. "Preview")
    if Ready() then Show(); return end
    local deadline = GetGameTimeMilliseconds() + 60000
    EM:RegisterForUpdate(NAME .. "Preview", 100, function()
        if GetGameTimeMilliseconds() >= deadline then EM:UnregisterForUpdate(NAME .. "Preview")
        elseif Ready() then EM:UnregisterForUpdate(NAME .. "Preview"); Show() end
    end)
    d("TrueShotMarkers: Chat oder Menü schließen, dann beginnt der Test.")
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
        { type = lib.ST_CHECKBOX, label = "Bodeninspektor bei Wamasu-Tod anzeigen",
            tooltip = "Zeigt Text und Pfeil über dir und gestorbenen Gruppenmitgliedern.",
            getFunction = function() return settings.showCorpseMarker end,
            setFunction = function(value)
                settings.showCorpseMarker = value
                if not value then
                    T.corpses = {}
                    if running then T.Update() end
                end
            end },
        { type = lib.ST_CHECKBOX, label = "Letzte Sekunde rot anzeigen",
            getFunction = function() return settings.warnRed end,
            setFunction = function(v) settings.warnRed = v; RefreshAppearance() end },
        { type = lib.ST_BUTTON, label = "Vorschau starten", buttonText = "15 Sekunden über dir",
            clickHandler = function() Preview("player", 15000) end },
        { type = lib.ST_BUTTON, label = "Vorschau beenden", buttonText = "Marker ausblenden", clickHandler = T.Clear },
    }, nil, false)
end

local function Command(text)
    text = zo_strlower(text or ""):match("^%s*(.-)%s*$")
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
    elseif text == "charge" then
        d(lastChargeHit or "TrueShotMarkers – Bisher kein Ansturm-Treffer auf dich erfasst.")
    elseif text == "treffer" then
        d("TrueShotMarkers – Letzter gemeldeter Todestreffer (du oder Gruppe): " .. (lastFatalHit or "noch keiner"))
    elseif text == "tod" then
        if lastDeath then
            d(string.format("TrueShotMarkers 1.0.11 – Letzter eigener Tod: %d Einträge. Tödlicher Treffer: %s. Marker: %s. Position: %s.",
                lastDeath.entries, lastDeath.hit or "nicht gemeldet", lastDeath.assignment or "keine Rückblick-Zuordnung",
                lastDeath.position or "nicht geprüft"))
        else
            d("TrueShotMarkers 1.0.11 – Bisher kein eigener Tod in Rand des Wahnsinns erfasst.")
        end
    elseif text == "test" then
        Preview("player", 5000)
    elseif text:match("^test%s+group%d+$") then
        local index = tonumber(text:match("(%d+)$"))
        local size = GetGroupSize()
        local tag = index >= 1 and index <= size and GetGroupUnitTagByIndex(index)
        if index == 1 and (not tag or not DoesUnitExist(tag) or AreUnitsEqual(tag, "player")) then
            tag = nil
            local zone = GetUnitRawWorldPosition("player")
            for i = 1, size do
                local member = GetGroupUnitTagByIndex(i)
                if member and DoesUnitExist(member) and not AreUnitsEqual(member, "player") then
                    tag = tag or member
                    if ValidUnit(member) and MarkerPosition(member, zone) then tag = member; break end
                end
            end
        end
        if tag and DoesUnitExist(tag) then Preview(tag, 10000)
        else d("TrueShotMarkers: Kein Mitspieler auf dem angeforderten Gruppenplatz.") end
    else
        d("TrueShotMarkers 1.0.11: " .. (registered and "aktiv in Rand des Wahnsinns" or "wartet auf Rand des Wahnsinns")
            .. ". /tshot test | test group1 | tod | treffer | charge | stop | an | aus")
    end
end

local function Initialize(_, addon)
    if addon ~= NAME then return end
    EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide("TrueShotMarkersSavedVariables", 1, nil,
        { size = 125, height = 280, color = {1,0.7,0.08,1}, warnRed = false, showCorpseMarker = true })
    TrueShotMarkersCamera:Create3DRenderSpace()
    CreateSettings()
    SLASH_COMMANDS["/tshot"] = Command
    EM:RegisterForEvent(NAME .. "Zone", EVENT_PLAYER_ACTIVATED, RefreshZone)
    EM:RegisterForEvent(NAME .. "Leave", EVENT_PLAYER_DEACTIVATED, T.Clear)
    EM:RegisterForEvent(NAME .. "Group", EVENT_GROUP_UPDATE, function()
        T.casts = {}; T.ids = {}; T.tagIds = {}
        EM:UnregisterForUpdate(NAME .. "Preview")
        if running then T.Update() end
    end)
    EM:RegisterForEvent(NAME .. "Combat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then
            T.casts = {}
            wamasuIds = {}
            EM:UnregisterForUpdate(NAME .. "Preview")
            if running then T.Update() end
        end
    end)
    RefreshZone()
end
EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
