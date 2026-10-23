-- One encounter clock for all-target, boss and non-boss DPS.
-- Battle Scrolls clock: combat-entry time to last observed damage event.
-- A hit at combat entry uses a fixed one-second estimate until a later damage timestamp exists.
-- Dummies, adds and bosses use the same DPS clock; no dummy/chat correction.
-- HUD timer, DPS and saved result use the same measured damage duration.
-- Damage uses effective hitValue; overkill is not added to the total.
local meter = {}
SimpleGroupDPS_DamageMeter = meter
local state
local last = { total = 0, dps = 0, durationMS = 0 }
local completedClock
local pending = {}
local RESET_UPDATE = "SimpleGroupDPSDamageReset"
local lastAliveMS
local portalEffects = { [108045] = true, [121216] = true }
local results = {}
for _, name in ipairs({ "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE",
    "ACTION_RESULT_DOT_TICK", "ACTION_RESULT_DOT_TICK_CRITICAL",
    "ACTION_RESULT_BLOCKED_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED",
    "ACTION_RESULT_PRECISE_DAMAGE", "ACTION_RESULT_WRECKING_DAMAGE" }) do
    if _G[name] ~= nil then results[_G[name]] = true end
end
local healingResults = {}
for _, name in ipairs({"ACTION_RESULT_HEAL", "ACTION_RESULT_CRITICAL_HEAL", "ACTION_RESULT_HOT_TICK",
    "ACTION_RESULT_HOT_TICK_CRITICAL", "ACTION_RESULT_HEAL_ABSORBED"}) do
    if _G[name] ~= nil then healingResults[_G[name]] = true end
end
local rememberUnit

local function isType(value, name)
    return _G[name] ~= nil and value == _G[name]
end

local function isPersonal(value)
    return isType(value, "COMBAT_UNIT_TYPE_PLAYER") or isType(value, "COMBAT_UNIT_TYPE_PLAYER_PET")
        or isType(value, "COMBAT_UNIT_TYPE_PLAYER_COMPANION")
end

local function isFriendly(value)
    return isPersonal(value) or isType(value, "COMBAT_UNIT_TYPE_GROUP")
        or isType(value, "COMBAT_UNIT_TYPE_GROUP_PET")
end

local function normalizeName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if zo_strformat then name = zo_strformat(_G.SI_UNIT_NAME or "<<1>>", name) end
    name = zo_strlower and zo_strlower(name) or string.lower(name)
    return name:match("^%s*(.-)%s*$")
end

local function isBossTarget(target)
    return state.bossIds[target.id] or (state.bossNames[target.name] and not state.confirmedNames[target.name])
end

local function currentZone()
    if GetZoneId and GetCurrentMapZoneIndex then return GetZoneId(GetCurrentMapZoneIndex()) end
end

function meter:RefreshBosses()
    if not state then return end
    for i = 1, (_G.MAX_BOSSES or _G.BOSS_RANK_ITERATION_END or 12) do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            local name = normalizeName(GetRawUnitName and GetRawUnitName(tag) or GetUnitName(tag))
            if name and name ~= "" then state.bossNames[name] = true end
        end
    end
end

function meter:CorrelateBoss(tag, id, name)
    if not state or type(tag) ~= "string" or not tag:match("^boss%d+$") or not id or id == 0 then return end
    state.bossIds[id] = true
    rememberUnit(id, false)
    name = normalizeName(name)
    if name and name ~= "" then
        state.bossNames[name] = true
        state.confirmedNames[name] = true
    end
end

local function accumulate(event)
    local key = event.id and event.id ~= 0 and event.id or ("name:" .. (event.name or ""))
    if not event.outgoing then
        if not event.catchAll or not event.id or event.id == 0 then return end
        local friendly = state.friendly[event.id]
        if friendly == true then return end
        if friendly == nil then
            local unknown = state.unassigned[event.id] or {value = 0, name = event.name}
            unknown.value = unknown.value + event.value
            if event.name then unknown.name = event.name end
            state.unassigned[event.id] = unknown
            return
        end
    end
    if event.id and state.friendly[event.id] == true then return end
    state.observedTargets[key] = { id = event.id, name = event.name }
    local target = state.targets[key]
    if not target then
        target = { id = event.id, name = event.name, total = 0, groupTotal = 0 }
        state.targets[key] = target
    end
    target.groupTotal = target.groupTotal + event.value
    state.groupTotal = state.groupTotal + event.value
    if event.personal then
        target.total = target.total + event.value
        state.total = state.total + event.value
    end
end

rememberUnit = function(id, friendly)
    if not id or id == 0 or state.friendly[id] ~= nil then return end
    state.friendly[id] = friendly
    local unknown = state.unassigned[id]
    state.unassigned[id] = nil
    if unknown and not friendly then
        accumulate({id = id, name = unknown.name, value = unknown.value, outgoing = true})
    end
end

local function rememberEventUnits(event)
    if isFriendly(event.sourceType) then rememberUnit(event.sourceId, true) end
    if isFriendly(event.targetType) then rememberUnit(event.id, true) end
    -- Untyped third-party hits alone cannot establish whether their target is hostile.
    if event.outgoing or isPersonal(event.sourceType) or isPersonal(event.targetType) then
        rememberUnit(event.sourceId, isFriendly(event.sourceType))
        rememberUnit(event.id, isFriendly(event.targetType))
    end
end

function meter:Start(timeMS)
    EVENT_MANAGER:UnregisterForUpdate(RESET_UPDATE)
    if state then return end
    state = { startMS = timeMS, endMS = timeMS, total = 0, groupTotal = 0, targets = {},
        friendly = {}, unassigned = {},
        observedTargets = {}, bossIds = {}, bossNames = {}, confirmedNames = {}, zoneId = currentZone(),
        damageEvents = 0, personalEvents = 0, otherEvents = 0 }
    self:RefreshBosses()
    for _, event in ipairs(pending) do
        if event.time >= timeMS - 1000 then rememberEventUnits(event); accumulate(event) end
    end
    pending = {}
    -- Peers can be in a different encounter and may not send another result yet.
    if SimpleGroupDPS_BattleScrolls then SimpleGroupDPS_BattleScrolls:ResetSendClock() end
end

function meter:IsActive() return state ~= nil end

function meter:ClearResult()
    if state then return false end
    last = {total = 0, dps = 0, durationMS = 0}
    completedClock = nil
    return true
end

-- On-demand diagnostics: receiving damage and refreshing the UI are separate clocks.
function meter:GetDiagnostics()
    local stats = self:GetStats()
    local clock = state or completedClock
    return {
        active = state ~= nil, inCombat = IsUnitInCombat("player"),
        durationMS = stats.durationMS, dps = stats.dps,
        damageAgeMS = clock and clock.damageAtMS and math.max(0, GetGameTimeMilliseconds() - clock.damageAtMS),
        finishedAgeMS = not state and clock and math.max(0, GetGameTimeMilliseconds() - clock.finishedAtMS),
        damageEvents = clock and clock.damageEvents or 0,
        personalEvents = clock and clock.personalEvents or 0,
        otherEvents = clock and clock.otherEvents or 0,
    }
end

-- Match Battle Scrolls' encounter lifetime, including temporary combat drops.
function meter:ShouldFinish()
    if not state or IsUnitInCombat("player") or state.inPortal then return false end
    local pvp = (IsPlayerInAvAWorld and IsPlayerInAvAWorld())
        or (IsActiveWorldBattleground and IsActiveWorldBattleground())
    if not pvp and GetGroupSize and ZO_Group_GetUnitTagForGroupIndex and IsUnitOnline then
        for i = 1, GetGroupSize() do
            local tag = ZO_Group_GetUnitTagForGroupIndex(i)
            if tag and not AreUnitsEqual(tag, "player") and IsUnitOnline(tag) and IsUnitInCombat(tag) then
                return false
            end
        end
    end
    local now = GetGameTimeMilliseconds()
    local dead = IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating("player")
    if (dead or (lastAliveMS and now - lastAliveMS < 500)) and now - state.endMS < 4000 then
        return false
    end
    local health, maximum = 0, 0
    if GetUnitPower and GetRawUnitName and IsUnitDead then
        for i = (_G.BOSS_RANK_ITERATION_BEGIN or 1), (_G.BOSS_RANK_ITERATION_END or _G.MAX_BOSSES or 12) do
            local tag = "boss" .. i
            if GetRawUnitName(tag) ~= "" and not IsUnitDead(tag) then
                local current, max = GetUnitPower(tag, COMBAT_MECHANIC_FLAGS_HEALTH)
                health, maximum = health + current, maximum + max
            end
        end
    end
    return not (health > 0 and health < maximum)
end

function meter:ScheduleFinish()
    EVENT_MANAGER:UnregisterForUpdate(RESET_UPDATE)
    if not state then return end
    local function check()
        EVENT_MANAGER:UnregisterForUpdate(RESET_UPDATE)
        if self:ShouldFinish() then
            self:Finish()
        elseif state and not IsUnitInCombat("player") then
            EVENT_MANAGER:RegisterForUpdate(RESET_UPDATE, 500, check)
        end
    end
    EVENT_MANAGER:RegisterForUpdate(RESET_UPDATE, 150, check)
end

function meter:GetStats()
    if not state then return last end
    local endMS = state.endMS
    if endMS <= state.startMS then
        if state.damageEvents > 0 or state.groupTotal > 0 then
            endMS = state.startMS + 1000
        else
            endMS = GetGameTimeMilliseconds()
        end
    end
    local durationMS = math.max(0, endMS - state.startMS)
    local bossTotal, groupBossTotal
    local hasBoss = false
    for _, target in pairs(state.observedTargets) do
        if isBossTarget(target) then hasBoss = true; break end
    end
    if hasBoss then
        bossTotal, groupBossTotal = 0, 0
        for _, target in pairs(state.targets) do
            if isBossTarget(target) then
                bossTotal = bossTotal + target.total
                groupBossTotal = groupBossTotal + target.groupTotal
            end
        end
    end
    local scale = durationMS >= 1 and 1000 / durationMS or 0
    return {
        total = state.total, dps = state.total * scale, durationMS = durationMS,
        bossTotal = bossTotal, bossDPS = bossTotal and bossTotal * scale,
        addsDPS = bossTotal and math.max(0, state.total - bossTotal) * scale,
        groupTotal = state.groupTotal, groupDPS = durationMS >= 1 and state.groupTotal * scale or nil,
        groupBossTotal = groupBossTotal,
        groupBossDPS = durationMS >= 1 and groupBossTotal and groupBossTotal > 0 and groupBossTotal * scale or nil,
    }
end

function meter:Finish()
    EVENT_MANAGER:UnregisterForUpdate(RESET_UPDATE)
    if not state then return end
    last = self:GetStats()
    completedClock = { damageAtMS = state.damageAtMS, finishedAtMS = GetGameTimeMilliseconds(),
        damageEvents = state.damageEvents, personalEvents = state.personalEvents, otherEvents = state.otherEvents }
    state = nil
    if self.onFinished then self.onFinished(last) end
end

function meter:OnDamage(result, isError, sourceType, targetName, targetType, hitValue, targetId, sourceId)
    hitValue = tonumber(hitValue)
    if isError or (not results[result] and not healingResults[result]) or not hitValue or hitValue < 0
        or hitValue ~= hitValue or hitValue == math.huge then return end
    local timeMS = GetGameTimeMilliseconds()
    local event = { time = timeMS, name = normalizeName(targetName), id = targetId, value = hitValue,
        sourceType = sourceType, targetType = targetType, sourceId = sourceId,
        catchAll = not isFriendly(sourceType) and not isFriendly(targetType),
        outgoing = isFriendly(sourceType) and not isFriendly(targetType),
        personal = isPersonal(sourceType) and not isFriendly(targetType) }
    if not state then
        -- Initialize on the combat-state event, not on a preceding hit.
        local recent = {}
        for _, previous in ipairs(pending) do
            if previous.time >= timeMS - 1000 then recent[#recent + 1] = previous end
        end
        if results[result] and hitValue > 0 and (event.outgoing or event.catchAll or isPersonal(targetType)) then
            recent[#recent + 1] = event
        end
        if #recent > 200 then table.remove(recent, 1) end
        pending = recent
        return
    end
    rememberEventUnits(event)
    if not results[result] then return end
    state.endMS = math.max(state.endMS, timeMS)
    state.damageAtMS = timeMS
    state.damageEvents = state.damageEvents + 1
    if event.personal then state.personalEvents = state.personalEvents + 1
    else state.otherEvents = state.otherEvents + 1 end
    if hitValue > 0 and not (isFriendly(sourceType) and isFriendly(targetType)) then accumulate(event) end
end

function meter:Initialize(saved)
    if type(saved) == "table" then
        last = { total = tonumber(saved.damageTotal) or 0, dps = tonumber(saved.dps) or 0,
            bossTotal = tonumber(saved.bossDamageTotal), bossDPS = tonumber(saved.bossDPS),
            addsDPS = tonumber(saved.addsDPS), durationMS = tonumber(saved.damageDurationMS or saved.durationMS) or 0,
            groupTotal = tonumber(saved.groupDamageTotal), groupDPS = tonumber(saved.groupDPS),
            groupBossTotal = tonumber(saved.groupBossDamageTotal), groupBossDPS = tonumber(saved.groupBossDPS) }
    end
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamage", EVENT_COMBAT_EVENT,
        function(_, result, isError, _, _, _, _, sourceType, targetName, targetType, hitValue, _, _, _, sourceId, targetId)
            self:OnDamage(result, isError, sourceType, targetName, targetType, hitValue, targetId, sourceId)
        end)
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageState", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if inCombat then self:Start(GetGameTimeMilliseconds()) else self:ScheduleFinish() end
    end)
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageBosses", EVENT_BOSSES_CHANGED, function()
        self:RefreshBosses()
        self:ScheduleFinish()
    end)
    if EVENT_PLAYER_ALIVE then
        EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageAlive", EVENT_PLAYER_ALIVE, function()
            lastAliveMS = GetGameTimeMilliseconds()
            self:ScheduleFinish()
        end)
    end
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageActivated", EVENT_PLAYER_ACTIVATED, function()
            local zone = currentZone()
            if state and zone and state.zoneId and zone ~= state.zoneId then self:Finish() end
            if state then state.inPortal = false; self:RefreshBosses(); self:ScheduleFinish() end
            if IsUnitInCombat("player") then self:Start(GetGameTimeMilliseconds()) end
        end)
    end
    if EVENT_UNIT_CREATED then
        EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageCreated", EVENT_UNIT_CREATED, function(_, tag)
            if type(tag) == "string" and tag:match("^boss%d+$") then self:RefreshBosses() end
        end)
    end
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageEffects", EVENT_EFFECT_CHANGED,
        function(_, changeType, _, _, tag, _, _, _, _, _, _, _, _, name, id, abilityId)
            -- Aetherian Archive: the Mage arrival starts a new encounter after the add waves.
            if state and abilityId == 50184 and changeType == _G.EFFECT_RESULT_GAINED and state.total > 0 then
                self:Finish()
                self:Start(GetGameTimeMilliseconds())
            end
            if state and portalEffects[abilityId] then
                state.inPortal = changeType == _G.EFFECT_RESULT_GAINED
                if not state.inPortal then self:RefreshBosses(); self:ScheduleFinish() end
            end
            if changeType ~= _G.EFFECT_RESULT_FADED then self:CorrelateBoss(tag, id, name) end
        end)
end
