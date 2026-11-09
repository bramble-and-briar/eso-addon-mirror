-- Combat timing follows BattleScrolls ef6d762d48998fa91e302d99fafce334568a3845:
-- combat initialization -> last damage event of any source; current-time fallback
-- only until a later damage timestamp exists. No backdating or one-second DPS floor.
-- DPS and HPS rates use this encounter duration; the standalone healing HUD retains its display clock.
-- Reference: BattleScrolls/combat/{state,arithmancer,scribe}.lua
local meter = {}
SimpleGroupDPS_DamageMeter = meter
local state
local last = { total = 0, dps = 0, durationMS = 0 }
local completedClock
local pending = {}
local RESET_UPDATE = "SimpleGroupDPSDamageReset"
local lastAliveMS
local AETHERIAN_ARCHIVE_ZONE_ID = 638
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
end

local function normalizeName(name)
    if type(name) ~= "string" or name == "" then return nil end
    -- BattleScrolls compares raw names, including grammar suffixes and case.
    -- Stripping ^n can merge a boss and a distinct same-display-name target.
    return name
end

local function isBossTarget(target)
    return state.bossIds[target.id] == true
end

local function currentZone()
    if GetZoneId and GetCurrentMapZoneIndex then return GetZoneId(GetCurrentMapZoneIndex()) end
end

function meter:RefreshBosses()
    if not state then return end
    for i = 1, (_G.MAX_BOSSES or _G.BOSS_RANK_ITERATION_END or 12) do
        local tag = "boss" .. i
        if DoesUnitExist(tag) and (not IsUnitDead or not IsUnitDead(tag)) then
            local name = normalizeName(GetRawUnitName and GetRawUnitName(tag) or GetUnitName(tag))
            if name and name ~= "" then
                local previous = state.bossTags[tag]
                if not previous or previous.name ~= name then
                    state.bossTags[tag] = {name = name}
                end
            end
        end
    end
end

function meter:CorrelateBoss(tag, id, name)
    if not state or type(tag) ~= "string" or not tag:match("^boss%d+$") or not id or id == 0 then return end
    local boss = state.bossTags[tag]
    name = normalizeName(name)
    if not boss then
        boss = {name = name, id = id, confirmed = true}
        state.bossTags[tag] = boss
        state.bossIds[id] = true
        return
    end
    if boss.id == id then boss.confirmed = true; return end
    if state.bossRedirects[id] then return end
    if boss.id and boss.confirmed and boss.name == name then
        -- Same raw-name boss recreated: keep a stable canonical ID and merge
        -- damage already recorded under the new ID, as redirectBossUnitId does.
        local canonical = boss.id
        state.bossRedirects[id] = canonical
        state.bossIds[id] = true
        local from = state.targets[id]
        if from then
            local target = state.targets[canonical]
            if target then
                target.total = target.total + from.total
                target.groupTotal = target.groupTotal + from.groupTotal
            else
                from.id = canonical
                state.targets[canonical] = from
            end
            state.targets[id] = nil
        end
        if state.observedTargets[id] then
            state.observedTargets[canonical] = {id = canonical, name = name}
            state.observedTargets[id] = nil
        end
        local unknown = state.unassigned[id]
        if unknown then
            local target = state.unassigned[canonical]
            if target then target.value = target.value + unknown.value
            else state.unassigned[canonical] = unknown end
            state.unassigned[id] = nil
        end
        return
    end
    if boss.id and not boss.confirmed then state.bossIds[boss.id] = nil end
    if boss.id and boss.confirmed and boss.name ~= name then
        boss = {name = name}
        state.bossTags[tag] = boss
    end
    boss.id, boss.confirmed = id, true
    state.bossIds[id] = true
    -- A boss effect establishes identity only. Native BattleScrolls does not
    -- release unknown group damage until an actual personal interaction does.
end

local function accumulate(event)
    event.id = state.bossRedirects[event.id] or event.id
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
    -- BattleScrolls records every personal damage event, including self/friendly
    -- damage. Friendliness only filters third-party damage from the group bucket.
    if not event.personal and event.id and state.friendly[event.id] == true then return end
    -- BattleScrolls uses a name fallback only for a boss tag without an ID,
    -- and only from personal damage. A second same-name target is not a boss.
    if event.personal and event.id and event.id ~= 0 and not state.bossIds[event.id] then
        for _, boss in pairs(state.bossTags) do
            if boss.id == nil and boss.name == event.name then
                boss.id, boss.confirmed = event.id, false
                state.bossIds[event.id] = true
                break
            end
        end
    end
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
    -- Group damage does not identify targets in BattleScrolls. Only a personal
    -- outgoing/incoming interaction may resolve the pending group-damage bucket.
    if isPersonal(event.sourceType) or isPersonal(event.targetType) then
        rememberUnit(event.sourceId, isFriendly(event.sourceType))
        rememberUnit(event.id, isFriendly(event.targetType))
    end
end

function meter:Start(timeMS)
    EVENT_MANAGER:UnregisterForUpdate(RESET_UPDATE)
    if state then return end
    state = { startMS = timeMS, endMS = timeMS, total = 0, groupTotal = 0, targets = {},
        rawHealingTotal = 0, effectiveHealingTotal = 0,
        friendly = {}, unassigned = {},
        observedTargets = {}, bossIds = {}, bossTags = {}, bossRedirects = {}, zoneId = currentZone(),
        damageEvents = 0, personalEvents = 0, otherEvents = 0 }
    self:RefreshBosses()
    if SimpleGroupDPS_HealthRecovery then SimpleGroupDPS_HealthRecovery:Start(timeMS) end
    -- Replay damage without backdating the combat initialization timestamp.
    for _, event in ipairs(pending) do
        if event.time >= timeMS - 1000 then rememberEventUnits(event); accumulate(event) end
    end
    pending = {}
    if SimpleGroupDPS_BattleScrolls then SimpleGroupDPS_BattleScrolls:ResetSendClock() end
    -- Like BattleScrolls' OnStateInitialized: start a fresh HUD update cadence
    -- once per encounter, never on temporary combat-state re-entry.
    if self.onStarted then self.onStarted() end
end

function meter:IsActive() return state ~= nil end

-- Read-only input for the diagnostic comparison, never used to calculate HUD values.
function meter:GetComparisonSnapshot()
    if not state then return nil end
    local stats = self:GetStats()
    local targets = {}
    for id, target in pairs(state.targets) do
        if target.total > 0 then targets[id] = {total = target.total, name = target.name} end
    end
    return {stats = stats, startMS = state.startMS, endMS = state.endMS, targets = targets}
end

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
        durationMS = stats.durationMS, dps = stats.dps, total = stats.total,
        bossTotal = stats.bossTotal, bossDPS = stats.bossDPS,
        damageAgeMS = clock and clock.damageAtMS and math.max(0, GetGameTimeMilliseconds() - clock.damageAtMS),
        finishedAgeMS = not state and clock and math.max(0, GetGameTimeMilliseconds() - clock.finishedAtMS),
        damageEvents = clock and clock.damageEvents or 0,
        personalEvents = clock and clock.personalEvents or 0,
        otherEvents = clock and clock.otherEvents or 0,
    }
end

-- Match Battle Scrolls' encounter lifetime, including temporary combat drops.
function meter:ShouldFinish()
    if not state then return false end
    if IsUnitInCombat("player") or state.inPortal then
        return false
    end
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
    if health > 0 and health < maximum then
        return false
    end
    return true
end

function meter:ScheduleFinish()
    EVENT_MANAGER:UnregisterForUpdate(RESET_UPDATE)
    if not state then return end
    local function check()
        EVENT_MANAGER:UnregisterForUpdate(RESET_UPDATE)
        if self:ShouldFinish() then
            self:Finish()
        elseif state then
            -- A temporary combat drop must not freeze a still-running group fight.
            if not IsUnitInCombat("player") then
                EVENT_MANAGER:RegisterForUpdate(RESET_UPDATE, 500, check)
            end
        end
    end
    EVENT_MANAGER:RegisterForUpdate(RESET_UPDATE, 150, check)
end

function meter:GetStats()
    if not state then return last end
    local startMS = state.startMS
    local endMS = state.endMS
    if endMS <= startMS then endMS = GetGameTimeMilliseconds() end
    local durationMS = math.max(0, endMS - startMS)
    local healingDurationMS = state.healingStartMS and math.max(0, state.healingEndMS - state.healingStartMS) or 0
    -- BattleScrolls HPS uses the encounter duration, just like DPS. Do not divide
    -- a late passive heal by a short first-to-last-heal window.
    local healingScale = durationMS >= 1 and 1000 / durationMS or 0
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
    local regenRaw, regenEffective = 0, 0
    if SimpleGroupDPS_HealthRecovery then regenRaw, regenEffective = SimpleGroupDPS_HealthRecovery:GetTotals() end
    return {
        total = state.total, dps = state.total * scale, durationMS = durationMS,
        bossTotal = bossTotal, bossDPS = bossTotal and bossTotal * scale,
        addsDPS = bossTotal and math.max(0, state.total - bossTotal) * scale,
        groupTotal = state.groupTotal, groupDPS = durationMS >= 1 and state.groupTotal * scale or nil,
        groupBossTotal = groupBossTotal,
        groupBossDPS = durationMS >= 1 and groupBossTotal and groupBossTotal > 0 and groupBossTotal * scale or nil,
        rawHealingTotal = state.rawHealingTotal + regenRaw, effectiveHealingTotal = state.effectiveHealingTotal + regenEffective,
        rawHPS = (state.rawHealingTotal + regenRaw) * healingScale,
        effectiveHPS = (state.effectiveHealingTotal + regenEffective) * healingScale,
        recoveryRaw = regenRaw, recoveryEffective = regenEffective,
        healingDurationMS = healingDurationMS,
    }
end

function meter:Finish()
    EVENT_MANAGER:UnregisterForUpdate(RESET_UPDATE)
    if not state then return end
    last = self:GetStats()
    completedClock = { damageAtMS = state.damageAtMS, finishedAtMS = GetGameTimeMilliseconds(),
        damageEvents = state.damageEvents, personalEvents = state.personalEvents, otherEvents = state.otherEvents }
    state = nil
    if SimpleGroupDPS_HealthRecovery then SimpleGroupDPS_HealthRecovery:Stop() end
    if self.onFinished then self.onFinished(last) end
end

function meter:OnDamage(result, isError, sourceType, targetName, targetType, hitValue, targetId, sourceId, overflow, abilityId)
    hitValue = tonumber(hitValue)
    if isError or (not results[result] and not healingResults[result]) or not hitValue or hitValue < 0
        or hitValue ~= hitValue or hitValue == math.huge then return end
    local timeMS = GetGameTimeMilliseconds()
    local event = { time = timeMS, name = normalizeName(targetName), id = targetId, value = hitValue,
        sourceType = sourceType, targetType = targetType, sourceId = sourceId,
        catchAll = isType(sourceType, "COMBAT_UNIT_TYPE_GROUP")
            or (not isPersonal(sourceType) and not isPersonal(targetType)
                and not isType(targetType, "COMBAT_UNIT_TYPE_GROUP")),
        outgoing = isPersonal(sourceType),
        personal = isPersonal(sourceType) }
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
    if not results[result] then
        if SimpleGroupDPS_HealthRecovery and isType(targetType, "COMBAT_UNIT_TYPE_PLAYER")
            and (isPersonal(sourceType) or isType(sourceType, "COMBAT_UNIT_TYPE_GROUP"))
            and abilityId ~= 126366 and result ~= _G.ACTION_RESULT_HEAL_ABSORBED then
            SimpleGroupDPS_HealthRecovery:OnHealing(hitValue)
        end
        -- Ignore unsupported/empty healing routes for identity discovery too.
        local personalSource, personalTarget = isPersonal(sourceType), isPersonal(targetType)
        local supported = (personalSource and (personalTarget or isType(targetType, "COMBAT_UNIT_TYPE_GROUP")))
            or (isType(sourceType, "COMBAT_UNIT_TYPE_GROUP") and personalTarget)
        if supported and abilityId ~= 126366 and hitValue + (tonumber(overflow) or 0) > 0 then
            rememberEventUnits(event)
        end
        -- Count only our outgoing healing (including self, pets and companions).
        -- Incoming/group healing never becomes our output. Pet spawn initialization
        -- is not a heal; absorbed-heal events carry no reliable overheal amount.
        if isPersonal(sourceType) and isFriendly(targetType) and abilityId ~= 126366 then
            overflow = tonumber(overflow) or 0
            if result == _G.ACTION_RESULT_HEAL_ABSORBED then overflow = 0 end
            if overflow < 0 or overflow ~= overflow or overflow == math.huge then return end
            if hitValue + overflow > 0 then
                state.healingStartMS = state.healingStartMS or timeMS
                state.healingEndMS = timeMS
            end
            state.rawHealingTotal = state.rawHealingTotal + hitValue + overflow
            state.effectiveHealingTotal = state.effectiveHealingTotal + hitValue
        end
        -- Healing must not change the existing DPS clock or damage totals.
        return
    end
    -- Like BattleScrolls, every valid damage event advances this timestamp.
    -- Incoming/unknown damage advances time but is never added to own damage.
    state.endMS = timeMS
    state.damageAtMS = timeMS
    state.damageEvents = state.damageEvents + 1
    if event.personal then state.personalEvents = state.personalEvents + 1
    else state.otherEvents = state.otherEvents + 1 end
    if hitValue > 0 then
        rememberEventUnits(event)
        accumulate(event)
    end
end

function meter:Initialize(saved)
    if SimpleGroupDPS_HealthRecovery then SimpleGroupDPS_HealthRecovery:Initialize() end
    if type(saved) == "table" then
        last = { total = tonumber(saved.damageTotal) or 0, dps = tonumber(saved.dps) or 0,
            bossTotal = tonumber(saved.bossDamageTotal), bossDPS = tonumber(saved.bossDPS),
            addsDPS = tonumber(saved.addsDPS), durationMS = tonumber(saved.damageDurationMS or saved.durationMS) or 0,
            groupTotal = tonumber(saved.groupDamageTotal), groupDPS = tonumber(saved.groupDPS),
            groupBossTotal = tonumber(saved.groupBossDamageTotal), groupBossDPS = tonumber(saved.groupBossDPS),
            rawHealingTotal = tonumber(saved.rawHealingTotal), effectiveHealingTotal = tonumber(saved.effectiveHealingTotal),
            rawHPS = tonumber(saved.rawHPS), effectiveHPS = tonumber(saved.effectiveHPS),
            healingDurationMS = tonumber(saved.healingDurationMS) }
    end
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamage", EVENT_COMBAT_EVENT,
        function(_, result, isError, _, _, _, _, sourceType, targetName, targetType, hitValue, _, _, _, sourceId, targetId, abilityId, overflow)
            self:OnDamage(result, isError, sourceType, targetName, targetType, hitValue, targetId, sourceId, overflow, abilityId)
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
            if state and state.zoneId == AETHERIAN_ARCHIVE_ZONE_ID
                and abilityId == 50184 and changeType == _G.EFFECT_RESULT_GAINED and state.total > 0 then
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
