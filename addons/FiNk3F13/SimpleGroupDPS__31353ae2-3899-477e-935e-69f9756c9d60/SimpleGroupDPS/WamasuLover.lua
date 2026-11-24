-- Wamasu death-marker integration based on the local TrueShotMarkers 1.0.6.
-- Only fatal charge events/recaps qualify; no DPS, healing or group data is changed.
local W = {corpses = {}, markers = {}, ids = {}, tagIds = {}}
SimpleGroupDPS_WamasuLover = W
local NAME, ZONE = 'SimpleGroupDPSWamasu', 1427
local EM = EVENT_MANAGER
local chargeIds = {
    [191133] = true, -- Boss charge windup
    [191139] = true, -- Boss charge lethal hit, reported from in-game death
    [200544] = true, -- Trash charge windup
    [200558] = true, -- Trash charge hit
}
local active, running, initialized, serial = false, false, false, 0
local ownDeath
local ownImpact, lastDeath
local wamasuIds = {}
local registrations = {}

local function playerTag(tag)
    return tag == 'player' or (type(tag) == 'string' and tag:match('^group%d+$') ~= nil)
end

local function unitName(tag)
    return zo_strformat('<<1>>', GetUnitName(tag) or '')
end

local function identity(tag)
    return (GetUnitDisplayName(tag) or '') .. '/' .. unitName(tag)
end

local function available(tag)
    if not playerTag(tag) or not DoesUnitExist(tag) then return false end
    if tag ~= 'player' then
        if not IsUnitOnline(tag) or not IsGroupMemberInSameWorldAsPlayer(tag)
            or not IsGroupMemberInSameInstanceAsPlayer(tag) then return false end
    end
    return true
end

local function position(tag, zone)
    local unitZone, x, y, z = GetUnitRawWorldPosition(tag)
    if unitZone and unitZone ~= 0 and unitZone == zone and x and y and z
        and (x ~= 0 or y ~= 0 or z ~= 0) then return x, y, z end
end

local function hideMarkers()
    for _, marker in pairs(W.markers) do marker.control:SetHidden(true); marker.shown = false end
end

local function stopRecap()
    EM:UnregisterForUpdate(NAME .. 'Recap')
    ownDeath = nil
end

function W:Clear()
    stopRecap()
    ownImpact, wamasuIds = nil, {}
    self.corpses, self.ids, self.tagIds = {}, {}, {}
    hideMarkers()
    SimpleGroupDPSWamasuRoot:SetHandler('OnUpdate', nil)
    running = false
end

local function getMarker(tag)
    local marker = W.markers[tag]
    if not marker then
        serial = serial + 1
        local control = WINDOW_MANAGER:CreateControlFromVirtual(NAME .. serial,
            SimpleGroupDPSWamasuRoot, NAME .. 'World')
        control:SetTransformNormalizedOriginPoint(0.5, 0.5)
        marker = {control = control, text = control:GetNamedChild('Text'), arrow = control:GetNamedChild('Arrow')}
        marker.text:SetText('Wamasu Lover')
        marker.text:SetColor(1, 0.7, 0.08, 1)
        marker.arrow:SetColor(1, 0.7, 0.08, 1)
        control:SetTransformScale(0.00875)
        W.markers[tag] = marker
    end
    return marker
end

function W:Update()
    local now = GetGameTimeMilliseconds()
    for tag, corpse in pairs(self.corpses) do
        if not available(tag) or identity(tag) ~= corpse.identity or IsUnitReincarnating(tag) then
            self.corpses[tag] = nil
        elseif IsUnitDead(tag) then
            corpse.confirmed = true
        elseif corpse.confirmed or now >= corpse.deadline then
            self.corpses[tag] = nil
        end
    end
    if not next(self.corpses) then
        hideMarkers()
        SimpleGroupDPSWamasuRoot:SetHandler('OnUpdate', nil)
        running = false
        return
    end
    if SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
        local scene = SCENE_MANAGER:GetCurrentScene()
        local name = scene and scene:GetName()
        if name ~= 'hud' and name ~= 'hudui' then hideMarkers(); return end
    end
    Set3DRenderSpaceToCurrentCamera(NAME .. 'Camera')
    local fx, fy, fz = SimpleGroupDPSWamasuCamera:Get3DRenderSpaceForward()
    local pitch = zo_atan2(fy, math.sqrt(fx * fx + fz * fz))
    local yaw = zo_atan2(fx, fz) - math.pi
    local ox, _, oz = GuiRender3DPositionToWorldPosition(0, 0, 0)
    local zone = GetUnitRawWorldPosition('player')
    for _, marker in pairs(self.markers) do marker.active = false end
    for tag, corpse in pairs(self.corpses) do
        if corpse.confirmed then
            local x, y, z = position(tag, zone)
            if tag == 'player' and ownDeath then
                if x then ownDeath.x, ownDeath.y, ownDeath.z = x, y, z
                else x, y, z = ownDeath.x, ownDeath.y, ownDeath.z end
            end
            if x then
                local marker = getMarker(tag)
                marker.control:SetTransformOffset((x - ox) / 100, (y + 280) / 100, (z - oz) / 100)
                marker.control:SetTransformRotation(pitch, yaw, 0)
                if not marker.shown then marker.control:SetHidden(false); marker.shown = true end
                marker.active = true
            end
        end
    end
    for _, marker in pairs(self.markers) do
        if not marker.active and marker.shown then marker.control:SetHidden(true); marker.shown = false end
    end
end

local function refreshMarkers()
    if not running then
        SimpleGroupDPSWamasuRoot:SetHandler('OnUpdate', function() W:Update() end)
        running = true
    end
    W:Update()
end

local function resolveTarget(id, name, kind)
    if kind == COMBAT_UNIT_TYPE_PLAYER then return 'player' end
    local cached = W.ids[id]
    if cached and available(cached.tag) and identity(cached.tag) == cached.identity then
        return AreUnitsEqual(cached.tag, 'player') and 'player' or cached.tag
    end
    local wanted = zo_strformat('<<1>>', name or '')
    if wanted == '' then return end
    local found
    for i = 0, GetGroupSize() do
        local tag = i == 0 and 'player' or GetGroupUnitTagByIndex(i)
        if tag and available(tag) and (wanted == unitName(tag) or wanted == GetUnitDisplayName(tag)) then
            if found and not AreUnitsEqual(found, tag) then return end
            found = tag
        end
    end
    return found and (AreUnitsEqual(found, 'player') and 'player' or found)
end

local function mark(tag)
    if not tag or not available(tag) or IsUnitReincarnating(tag) then return end
    if W.corpses[tag] and W.corpses[tag].identity == identity(tag) then return end
    W.corpses[tag] = {identity = identity(tag), deadline = GetGameTimeMilliseconds() + 1500}
    refreshMarkers()
end

local function isCharge(abilityId, abilityName, sourceName)
    if chargeIds[abilityId] then return true end
    local source = zo_strlower(sourceName or '')
    local attack = zo_strlower(abilityName or '')
    return source:find('%f[%a]wamasu%f[%A]') ~= nil
        and (attack:find('charge', 1, true) ~= nil or attack:find('ansturm', 1, true) ~= nil)
end

-- ESO can omit the attacker in the death recap. Retain the actual charge hit,
-- never just its cast: a later unrelated hit must invalidate this evidence.
local function onChargeSource(_, _, err, _, _, _, _, kind, _, _, _, _, _, _, id)
    if not err and id and id ~= 0
        and (kind == COMBAT_UNIT_TYPE_OTHER or kind == COMBAT_UNIT_TYPE_NONE) then
        wamasuIds[id] = true
    end
end

local function onOwnDamage(_, result, err, attack, _, _, source, kind, _, targetType,
        _, _, _, _, sourceId, _, abilityId)
    if err or targetType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if result ~= ACTION_RESULT_DAMAGE and result ~= ACTION_RESULT_CRITICAL_DAMAGE
        and result ~= ACTION_RESULT_BLOCKED_DAMAGE and result ~= ACTION_RESULT_DAMAGE_SHIELDED then return end
    if result == ACTION_RESULT_DAMAGE_SHIELDED then return end
    ownImpact = nil
    if kind ~= COMBAT_UNIT_TYPE_OTHER and kind ~= COMBAT_UNIT_TYPE_NONE then return end
    local label = attack
    if (not label or label == '') and GetAbilityName then label = GetAbilityName(abilityId) end
    if isCharge(abilityId, label, wamasuIds[sourceId] and 'Wamasu' or source) then
        ownImpact = {id = abilityId, time = GetGameTimeMilliseconds()}
    end
end

local function checkRecap()
    if not active or not ownDeath then return end
    if IsUnitReincarnating('player') then stopRecap(); return end
    if GetGameTimeMilliseconds() >= ownDeath.deadline then EM:UnregisterForUpdate(NAME .. 'Recap') end
    if not IsUnitDead('player') then return end
    for i = 1, GetNumKillingAttacks() do
        local attack, _, _, fatal, _, _, _, abilityId = GetKillingAttackInfo(i)
        if fatal then
            local attacker, isPlayer
            if DoesKillingAttackHaveAttacker(i) then
                local name, _, _, _, player = GetKillingAttackerInfo(i)
                attacker, isPlayer = name, player
            end
            ownDeath.hit = tostring(attack) .. ' [' .. tostring(abilityId) .. ']'
            local matchedImpact = (attacker or '') == '' and ownDeath.impact
                and ownDeath.impact.id == abilityId
            if not isPlayer and (isCharge(abilityId, attack, attacker) or matchedImpact) then
                mark('player')
                ownDeath.matched = true
                EM:UnregisterForUpdate(NAME .. 'Recap')
            end
            return
        end
    end
end

local function onOwnDeath()
    if not active or IsUnitReincarnating('player') then return end
    if not ownDeath then
        local x, y, z = position('player', GetUnitRawWorldPosition('player'))
        ownDeath = {deadline = GetGameTimeMilliseconds() + 6000, x = x, y = y, z = z}
        if ownImpact and GetGameTimeMilliseconds() - ownImpact.time <= 1500 then ownDeath.impact = ownImpact end
        lastDeath = ownDeath
        EM:RegisterForUpdate(NAME .. 'Recap', 250, checkRecap)
    end
    checkRecap()
end

local function onAlive()
    ownImpact = nil
    stopRecap()
    W.corpses.player = nil
    if running then W:Update() end
end

local function onFatal(_, _, isError, abilityName, _, _, sourceName, sourceType,
        targetName, targetType, _, _, _, _, sourceId, targetId, abilityId)
    if not active or isError then return end
    if (sourceType == COMBAT_UNIT_TYPE_OTHER or sourceType == COMBAT_UNIT_TYPE_NONE)
        and isCharge(abilityId, abilityName, wamasuIds[sourceId] and 'Wamasu' or sourceName) then
        mark(resolveTarget(targetId, targetName, targetType))
    end
end

local function cacheUnit(_, _, _, _, tag, _, _, _, _, _, _, _, _, _, id)
    if playerTag(tag) and DoesUnitExist(tag) and id and id ~= 0 then
        local old = W.tagIds[tag]
        if old and old ~= id then W.ids[old] = nil end
        W.tagIds[tag] = id
        W.ids[id] = {tag = tag, identity = identity(tag)}
    end
end

local function register(suffix, event, callback, ...)
    if not event then return end
    local key = NAME .. suffix
    EM:RegisterForEvent(key, event, callback)
    registrations[key] = event
    if select('#', ...) > 0 then EM:AddFilterForEvent(key, event, ...) end
end

function W:RefreshZone()
    self:Clear()
    for key, event in pairs(registrations) do EM:UnregisterForEvent(key, event) end
    registrations = {}
    active = GetZoneId(GetUnitZoneIndex('player')) == ZONE
    if not active then return end
    register('Effects', EVENT_EFFECT_CHANGED, cacheUnit, REGISTER_FILTER_UNIT_TAG_PREFIX, 'group')
    register('OwnEffects', EVENT_EFFECT_CHANGED, cacheUnit, REGISTER_FILTER_UNIT_TAG_PREFIX, 'player')
    register('OwnDamage', EVENT_COMBAT_EVENT, onOwnDamage)
    if REGISTER_FILTER_ABILITY_ID then
        for id in pairs(chargeIds) do
            register('Source' .. id, EVENT_COMBAT_EVENT, onChargeSource, REGISTER_FILTER_ABILITY_ID, id)
        end
    end
    register('OwnDeath', EVENT_PLAYER_DEAD, onOwnDeath)
    register('RecapInfo', EVENT_PLAYER_DEATH_INFO_UPDATE, checkRecap)
    register('Alive', EVENT_PLAYER_ALIVE, onAlive)
    register('Spirit', EVENT_PLAYER_REINCARNATED, onAlive)
    register('DeathState', EVENT_UNIT_DEATH_STATE_CHANGED, function(_, tag, dead)
        if not playerTag(tag) then return end
        if AreUnitsEqual(tag, 'player') then
            if dead then onOwnDeath() else onAlive() end
        elseif not dead then W.corpses[tag] = nil; if running then W:Update() end end
    end)
    for _, entry in ipairs({{ACTION_RESULT_DIED, 'Died'}, {ACTION_RESULT_DIED_XP, 'DiedXP'},
            {ACTION_RESULT_KILLING_BLOW, 'KillingBlow'}}) do
        if entry[1] then register(entry[2], EVENT_COMBAT_EVENT, onFatal, REGISTER_FILTER_COMBAT_RESULT, entry[1]) end
    end
end

function W:Initialize()
    if initialized then return end
    initialized = true
    if SLASH_COMMANDS then
        SLASH_COMMANDS['/sgdwamasu'] = function()
            local corpse, marker = self.corpses.player, self.markers.player
            local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
            d('SimpleGroupDPS Wamasu 2: Gebiet ' .. tostring(GetZoneId(GetUnitZoneIndex('player')))
                .. ', aktiv ' .. tostring(active) .. ', tot ' .. tostring(IsUnitDead('player')))
            d('Letzter Todesstoss: ' .. tostring(lastDeath and lastDeath.hit or 'keine Todesrueckschau')
                .. ', Ansturm erkannt ' .. tostring(lastDeath and lastDeath.matched or false))
            d('Leiche zugeordnet ' .. tostring(corpse ~= nil) .. ', Text sichtbar ' .. tostring(marker and marker.shown or false)
                .. ', Szene ' .. tostring(scene and scene:GetName()))
        end
    end
    SimpleGroupDPSWamasuCamera:Create3DRenderSpace()
    EM:RegisterForEvent(NAME .. 'Zone', EVENT_PLAYER_ACTIVATED, function() self:RefreshZone() end)
    EM:RegisterForEvent(NAME .. 'Leave', EVENT_PLAYER_DEACTIVATED, function() active = false; self:Clear() end)
    EM:RegisterForEvent(NAME .. 'Group', EVENT_GROUP_UPDATE, function()
        self.ids, self.tagIds = {}, {}
        if running then self:Update() end
    end)
    self:RefreshZone()
end
