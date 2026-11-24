-- Arclight Taunt | Taunt effects and tracked target lifecycle
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local T = A.T
local EXPIRED_LINGER = A.EXPIRED_LINGER
local MAX_TRACKED_TARGETS = A.MAX_TRACKED_TARGETS
local Now = A.Now
local DemoNow = A.DemoNow
local TAUNT_IDS = A.TAUNT_IDS
local TAUNT_TIME_EPSILON = 0.01
-- Conservative signed-32-bit millisecond envelope for native cooldown/size
-- durations (over 24 days), not an assumed gameplay taunt duration.
local MAX_NATIVE_SECONDS = 2147483
local function FiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function ValidTauntRange(beginTime, endTime, now)
    if not FiniteNumber(beginTime) or not FiniteNumber(endTime) then return false end
    local duration, remaining = endTime - beginTime, endTime - now
    return duration > 0 and duration <= MAX_NATIVE_SECONDS
        and remaining > 0 and remaining <= MAX_NATIVE_SECONDS
end
local playerTargetIds, playerTargetCount = {}, 0
-- ESO can replay an application after its row or its successor has gone.
-- Keep at most one pool of 128 effect signatures, never row/target objects.
-- Rotating slots bound storage across combats; lookup visits only this ID.
local endedById, endedSlots, nextEndedSlot = {}, {}, 1
local function RememberEndedApplication(t, now, combatExit)
    if t.dead or t.expiredAt or t.endTime <= now then return end
    local slot = nextEndedSlot
    local entry = endedSlots[slot]
    if entry then
        local old = endedById[entry.key]
        old[slot] = nil
        if not next(old) then endedById[entry.key] = nil end
    else
        entry = {}
        endedSlots[slot] = entry
    end
    local key = t.unitId
    local entries = endedById[key]
    if not entries then entries = {}; endedById[key] = entries end
    entry.key, entry.source, entry.ability = key, t.sourceType, t.abilityId
    entry.startTime, entry.endTime = t.startKnown and t.startTime or nil, t.endTime
    entry.endedAt, entry.combatExit = now, combatExit
    entries[slot] = entry
    nextEndedSlot = slot % MAX_TRACKED_TARGETS + 1
end
local function RepeatsEndedApplication(entries, source, ability, startTime, startKnown, endTime)
    for _, ended in pairs(entries) do
        if (not ended.combatExit or not A.inCombat)
            and ended.source == source and ended.ability == ability
            and math.abs(endTime - ended.endTime) < TAUNT_TIME_EPSILON then
            if not startKnown or (ended.startTime and math.abs(startTime - ended.startTime) < TAUNT_TIME_EPSILON)
                or (not ended.startTime and startTime < ended.endedAt) then return true end
        end
    end
    return false
end
local ObserveTargetMarker = A.ObserveTargetMarker
local QueueTargetMarkerRefresh = A.QueueTargetMarkerRefresh
local RefreshTargetMarker = A.RefreshTargetMarker
local CancelTargetMarkerRefresh = A.CancelTargetMarkerRefresh
-- Event sourceType describes the caster, never the affected target. Only a
-- currently valid unit tag can establish player/NPC type for this exact ID.
local function ObservePlayerTarget(key, unitTag)
    if type(unitTag) == "string" and unitTag ~= "" and DoesUnitExist(unitTag) then
        if IsUnitPlayer(unitTag) then
            if not playerTargetIds[key] then
                if playerTargetCount >= MAX_TRACKED_TARGETS then
                    playerTargetIds, playerTargetCount = {}, 0
                end
                playerTargetIds[key] = true
                playerTargetCount = playerTargetCount + 1
            end
        elseif playerTargetIds[key] then
            playerTargetIds[key] = nil
            playerTargetCount = playerTargetCount - 1
        end
        return playerTargetIds[key] == true, true
    end
    return playerTargetIds[key] == true, false
end
local function CancelPendingBossWarning(key)
    local pending = A.pendingBossWarnings
    if not pending then return end
    pending[key] = nil
    -- The next unrelated loss needs its own complete batching window.
    if not next(pending) then A.pendingBossWarnings, A.pendingFirstAt = nil, nil end
end
local function DropPlayerTarget(key)
    local existed = A.targets[key] ~= nil
    if existed then CancelTargetMarkerRefresh(A.targets[key]) end
    A.targets[key] = nil
    if A.activeTarget == key then A.activeTarget = nil end
    if A.reticleUnitId == key then A.reticleUnitId = nil end
    CancelPendingBossWarning(key)
    A.DismissBossAlertForTarget(key)
    return existed
end
local function PrunePlayerTargets()
    if A.saved.trackPlayerTargets then return end
    for key, target in pairs(A.targets) do
        if target.isPlayer or playerTargetIds[key] then DropPlayerTarget(key) end
    end
end

-- A faded or elapsed taunt no longer means an active taunt. Keep a brief
-- 0,0 indicator (or a persistent one if the user explicitly opts in).
local function IsLost(t, now)
    return t.expiredAt ~= nil or t.endTime <= now
end

-- Using the first-seen sequence as a tie-breaker keeps same-color enemies
-- stable even when their countdowns differ or a taunt gets refreshed.
local function StableLess(a, b)
    local aOrder, bOrder = a.order or 0, b.order or 0
    if aOrder ~= bOrder then return aOrder < bOrder end
    return tostring(a.unitId) < tostring(b.unitId)
end

local function RemainingLess(a, b)
    if a.endTime ~= b.endTime then return a.endTime < b.endTime end
    return StableLess(a, b)
end
local function LostLess(a, b)
    if a.expiredAt ~= b.expiredAt then return a.expiredAt > b.expiredAt end
    return tostring(a.unitId) < tostring(b.unitId)
end

-- A hidden list only needs marker settlement and expiry cleanup. The visible
-- path supplies destination arrays and applies its optional boss filter.
local function MaintainLiveTargets(now, active, lost, bossOnly)
    RefreshTargetMarker(now)
    for key, t in pairs(A.targets) do
        if not t.expiredAt and t.endTime <= now then t.expiredAt = now end
        if t.expiredAt and not A.saved.showExpired and now - t.expiredAt >= EXPIRED_LINGER then
            CancelTargetMarkerRefresh(t)
            A.targets[key] = nil
            CancelPendingBossWarning(key)
            if A.reticleUnitId == key then A.reticleUnitId = nil end
        elseif active and (not bossOnly or A.BossVisible(t)) then
            local list = t.expiredAt and lost or active
            list[#list + 1] = t
        end
    end
end
local function Gather(now, skipSort, bossOnly)
    local active, lost
    if A.demo then
        active, lost = A.GatherDemo(now, bossOnly)
    else
        active, lost = {}, {}
        MaintainLiveTargets(now, active, lost, bossOnly)
    end
    if not skipSort and #active > 1 then
        table.sort(active, RemainingLess)
    end
    -- The most recently expired taunt goes first in the optional expired section.
    if not skipSort and #lost > 1 then table.sort(lost, LostLess) end
    return active, lost
end

-- Official boss tags are definitive; difficulty ranks widen coverage for
-- world-/delve-/Craglorn bosses but are not a perfect boss classifier.
-- A rank is only taken from the *same identified unit* (unitTag or a uniquely
-- matched reticle taunt), never from a shared display name.
local function SelectVisible(active, lost, capacity)
    local items, nonBossActive, nonBossLost = {}, active, lost
    -- Optional boss priority: pin only *positively identified* bosses.
    -- Reserve visible slots before processing regular targets, even if the
    -- boss has a longer timer than every other enemy. Expired bosses go first;
    -- active boss timers retain remaining-time order from Gather.
    if A.saved.pinBosses then
        nonBossActive, nonBossLost = {}, {}
        for _, t in ipairs(lost) do
            if A.BossVisible(t) then
                if #items < capacity then items[#items + 1] = t end
            else
                nonBossLost[#nonBossLost + 1] = t
            end
        end
        for _, t in ipairs(active) do
            if A.BossVisible(t) then
                if #items < capacity then items[#items + 1] = t end
            else
                nonBossActive[#nonBossActive + 1] = t
            end
        end
    end

    local remainingSlots = capacity - #items
    if remainingSlots <= 0 then return items end
    -- When many taunts are running, reserve up to three lost-taunt slots.
    -- Never evict a pinned boss to make room for an expired trash mob.
    local lostCount = math.min(#nonBossLost, remainingSlots)
    if lostCount > 0 and #nonBossActive > 0 and #nonBossActive + lostCount > remainingSlots then
        -- Only competing active and expired rows need a danger-zone count.
        local lostBudget = math.min(3, math.max(1, math.floor(remainingSlots / 4)))
        local now, criticalCount = DemoNow(Now()), 0
        for _, t in ipairs(nonBossActive) do
            if t.endTime - now <= A.saved.dangerAt then
                criticalCount = criticalCount + 1
                if criticalCount == remainingSlots then break end
            end
        end
        lostCount = math.min(lostCount, lostBudget, remainingSlots - criticalCount)
    end
    local activeCount = math.min(#nonBossActive, remainingSlots - lostCount)
    lostCount = math.min(#nonBossLost, remainingSlots - activeCount)
    for i = 1, lostCount do items[#items + 1] = nonBossLost[i] end
    for i = 1, activeCount do items[#items + 1] = nonBossActive[i] end
    return items
end
-- Preserve a normal expired record's last displayed rank during its existing
-- linger time. Active records still sort by deadline; pinned bosses still lead.
-- Only actually rendered identities qualify, never names or hidden old records.
local function StabilizeVisible(items, now, noActiveCandidates)
    local previous = A.lastVisibleItems
    if not previous then return items end
    local hasExpired = false
    local unchangedExpired = noActiveCandidates and not A.saved.pinBosses and #previous == #items
    for i, target in ipairs(items) do
        local keepRank = IsLost(target, now) and not (A.saved.pinBosses and A.BossVisible(target))
        hasExpired = hasExpired or keepRank
        unchangedExpired = unchangedExpired and keepRank and previous[i] == target
        if hasExpired and not unchangedExpired then break end
    end
    -- With only unpinned expired records, stabilization reproduces the last
    -- visible ranks exactly. Mixed lists and changed identities take the normal path.
    if not hasExpired or unchangedExpired then return items end
    local ranks = {}
    for _, target in ipairs(items) do ranks[target] = math.huge end
    local rank = 0
    for _, target in ipairs(previous) do
        if ranks[target] then
            rank = rank + 1
            ranks[target] = rank
        end
    end
    local result, expired = {}, {}
    for _, target in ipairs(items) do
        if IsLost(target, now) and not (A.saved.pinBosses and A.BossVisible(target)) then
            expired[#expired + 1] = target
        else
            result[#result + 1] = target
        end
    end
    local pinned = 0
    if A.saved.pinBosses then
        for _, target in ipairs(result) do
            if not A.BossVisible(target) then break end
            pinned = pinned + 1
        end
    end
    table.sort(expired, function(a, b)
        local ar, br = ranks[a] or math.huge, ranks[b] or math.huge
        if ar ~= br then return ar < br end
        return LostLess(a, b)
    end)
    local lastSlot = pinned
    for _, target in ipairs(expired) do
        local slot = math.min(#result + 1, math.max(lastSlot + 1, ranks[target] or (#result + 1)))
        table.insert(result, slot, target)
        lastSlot = slot
    end
    return result
end
-- One native buff scan serves the existing focus/indicator observation and
-- the optional, stricter marker correlation. A marker-only call never changes
-- focus, indicator observations or boss state.
local function FindReticleTaunts(now, observeReticle)
    local candidates = {}
    for _, t in pairs(A.targets) do
        if not t.dead and not IsLost(t, now) then candidates[#candidates + 1] = t end
    end
    if #candidates == 0 and not observeReticle then return end
    local focusId, markerTarget, focusAmbiguous
    local markerBlocked = not A.saved.showTargetMarkers
    local buffCount = GetNumBuffs("reticleover")
    for i = 1, buffCount do
        local _, beginTime, endTime, _, _, _, _, _, _, _, abilityId, _, castByPlayer =
            GetUnitBuffInfo("reticleover", i)
        if castByPlayer == true and TAUNT_IDS[abilityId] and not markerBlocked
            and (not ValidTauntRange(beginTime, endTime, now)
                or beginTime <= 0 or beginTime > now) then markerBlocked = true end
        -- Foreign/pet effects still need direct identity. The broader focus
        -- match does not authorize marker changes without the stricter check.
        if castByPlayer == true and TAUNT_IDS[abilityId]
            and type(beginTime) == "number" and type(endTime) == "number" then
            -- A supported own effect on this unit is sufficient for the small
            -- indicator, even when identical timers cannot identify a list row.
            -- Keep this observation out of combat records and boss warnings.
            if observeReticle and not focusAmbiguous and beginTime <= now and ValidTauntRange(beginTime, endTime, now)
                and (not A.reticleTaunt or endTime < A.reticleTaunt.endTime) then
                local observation = A.reticleObservation or {}
                A.reticleObservation = observation
                observation.startTime, observation.endTime = beginTime, endTime
                A.reticleTaunt = observation
            end
            local match, matchCount, strictMatch, strictCount = nil, 0, nil, 0
            for _, t in ipairs(candidates) do
                if t.sourceType == COMBAT_UNIT_TYPE_PLAYER and t.abilityId == abilityId
                    and math.abs(t.startTime - beginTime) < 0.12
                    and math.abs(t.endTime - endTime) < 0.12 then
                    match, matchCount = t, matchCount + 1
                    if not markerBlocked
                        and math.abs(t.startTime - beginTime) < TAUNT_TIME_EPSILON
                        and math.abs(t.endTime - endTime) < TAUNT_TIME_EPSILON then
                        strictMatch, strictCount = t, strictCount + 1
                    end
                end
            end
            -- Preserve the broader focus's ambiguity and its early-stop
            -- indicator behavior, while finishing independent marker checks.
            if not focusAmbiguous then
                if matchCount > 1 or (matchCount == 1 and focusId and focusId ~= match.unitId) then
                    focusId, focusAmbiguous = nil, true
                elseif matchCount == 1 then
                    focusId = match.unitId
                end
            end
            if not markerBlocked then
                if strictCount ~= 1 or strictMatch.startKnown ~= true
                    or (markerTarget and markerTarget ~= strictMatch) then
                    markerBlocked = true
                else markerTarget = strictMatch end
            end
            if focusAmbiguous and markerBlocked then return end
        end
    end
    return focusId, not markerBlocked and markerTarget or nil
end

local function CorrelatedMarkerTarget(now)
    if not A.saved.showTargetMarkers or not DoesUnitExist("reticleover")
        or IsUnitDead("reticleover")
        or (not A.saved.trackPlayerTargets and IsUnitPlayer("reticleover")) then return end
    local _, target = FindReticleTaunts(now, false)
    if target and A.targets[target.unitId] == target then return target end
end

-- Resolve focus from direct identity or the existing own-taunt timing match.
local function TargetChanged(eligibleWithoutRecords)
    A.activeTarget = nil
    A.reticleTaunt = nil
    A.reticleBossTarget = nil
    A.reticleDirty = nil
    local now = Now()
    A.lastReticleScan = now
    if eligibleWithoutRecords then
        -- The immediately preceding empty-list check accepted this target.
        -- Only the own buff observation remains; never forward this evidence
        -- to a later display, scheduler check, or marker callback.
        FindReticleTaunts(now, true)
        return
    end
    if not DoesUnitExist("reticleover") then
        A.reticleUnitId = nil
        return
    end
    local identified = A.reticleUnitId and A.targets[A.reticleUnitId]
    local player
    if identified then
        identified.isPlayer=ObservePlayerTarget(identified.unitId,"reticleover")
        if identified.isPlayer and not A.saved.trackPlayerTargets then DropPlayerTarget(identified.unitId);return end
    else
        player = IsUnitPlayer("reticleover")
        if player and not A.saved.trackPlayerTargets then
            return -- a timer match is not permission to delete an uncertain NPC row
        end
    end
    -- Death notifications need not arrive while the target is under the
    -- reticle. Reuse the existing observation interval, but only remove a row
    -- with direct event identity, never a matching name or guessed timer.
    if identified and IsUnitDead("reticleover") then
        A.RemoveDeadUnit(identified.unitId, true)
        return
    end
    if identified and not identified.dead and not IsLost(identified, now) then
        A.activeTarget = identified.unitId
    end
    local bossFilter = A.saved.reticleStyle ~= "off" and A.saved.reticleBossOnly
        and A.inCombat
    if identified then
        ObserveTargetMarker(identified, "reticleover")
        -- Direct identity already resolves focus; timing guesses need no buff
        -- scan here. Boss observation still follows the current valid unit tag.
        if A.activeTarget or bossFilter then A.ObserveBoss(identified, "reticleover") end
        if bossFilter then A.reticleBossTarget = identified end
        if A.activeTarget then
            if A.saved.reticleStyle ~= "off" then A.reticleTaunt = identified end
        end
        return
    end
    if bossFilter then
        -- Classification of the current unit needs no guessed list identity or
        -- active taunt. Reuse the existing observation and polling interval.
        local observation = A.reticleObservation or {}
        A.reticleObservation = observation
        observation.isBoss, observation.bossDifficulty, observation.isPlayer = nil, nil, player
        A.ObserveBoss(observation, "reticleover")
        A.reticleBossTarget = observation
    end
    -- Without a boss observation these native existence/player facts are
    -- still from this call. Re-read them after the classification boundary.
    local knownPlayer
    if not bossFilter then knownPlayer = player end
    local observeReticle = A.ReticleNeedsUpdate and A.ReticleNeedsUpdate(knownPlayer)
    local markerTarget
    A.activeTarget, markerTarget = FindReticleTaunts(now, observeReticle)
    if markerTarget and A.targets[markerTarget.unitId] == markerTarget
        and not IsUnitDead("reticleover") then
        ObserveTargetMarker(markerTarget, "reticleover")
    end
    local matched = A.activeTarget and A.targets[A.activeTarget]
    if not matched then return end
    if bossFilter then
        -- A unique match may reuse this unit's already-read classification.
        local observation = A.reticleBossTarget
        if observation.isBoss then matched.isBoss = true end
        if observation.bossDifficulty then
            matched.bossDifficulty = math.max(matched.bossDifficulty or 0, observation.bossDifficulty)
        end
    else
        A.ObserveBoss(matched, "reticleover")
    end
end

local function ReticleChanged()
    CancelTargetMarkerRefresh()
    A.reticleUnitId = nil -- unit tags are dynamic; a target switch invalidates proof
    if not next(A.targets) and (A.saved.reticleStyle == "off" or not A.inCombat) then
        A.activeTarget, A.reticleTaunt, A.reticleBossTarget = nil, nil, nil
        return
    end
    TargetChanged()
    A.Tick()
end

local function ObserveReticleIdentity(key, unitTag)
    if type(unitTag) ~= "string" or unitTag == "" or not DoesUnitExist("reticleover") then return end
    if unitTag == "reticleover" or (DoesUnitExist(unitTag) and AreUnitsEqual(unitTag, "reticleover")) then
        A.reticleUnitId = key
    end
end

-- EVENT_EFFECT_CHANGED: (eventCode, changeType, effectSlot, effectName, unitTag,
-- beginTime, endTime, stackCount, icon, buffType, effectType, abilityType,
-- statusEffectType, unitName, unitId, abilityId, sourceType)
local function MakeSpaceForTrackedTarget(now)
    local count = 0
    local oldestId, oldestAt
    for id, t in pairs(A.targets) do
        count = count + 1
        if (t.expiredAt or t.endTime <= now)
            and (not oldestAt or (t.expiredAt or t.endTime) < oldestAt) then
            oldestId, oldestAt = id, t.expiredAt or t.endTime
        end
    end
    if count < MAX_TRACKED_TARGETS then return true end
    if oldestId then
        CancelTargetMarkerRefresh(A.targets[oldestId])
        A.DismissBossAlertForTarget(oldestId, "early")
        A.targets[oldestId] = nil
        CancelPendingBossWarning(oldestId)
        if A.activeTarget == oldestId then A.activeTarget = nil end
        if A.reticleUnitId == oldestId then A.reticleUnitId = nil end
        return true
    end
    return false -- do not evict an active taunt in order to accept another
end

local function ReticleContextContradicts(key, unitTag, beginTime, endTime, abilityId, sourceType, now, previous)
    if unitTag ~= "reticleover" or A.reticleUnitId == key or sourceType ~= COMBAT_UNIT_TYPE_PLAYER
        or not ValidTauntRange(beginTime, endTime, now) or beginTime <= 0
        or not DoesUnitExist("reticleover") then return false end
    -- A queued effect can carry a dynamic tag after the aim point changed.
    -- Different currently visible own-taunt timing is a contradiction, not
    -- permission to identify any other record from that timing. No visible
    -- own effect is inconclusive (new effects may not be visible yet).
    local hasOwnTaunt = false
    for i = 1, GetNumBuffs("reticleover") do
        local _, currentBegin, currentEnd, _, _, _, _, _, _, _, currentAbility, _, own =
            GetUnitBuffInfo("reticleover", i)
        if own == true and TAUNT_IDS[currentAbility] and ValidTauntRange(currentBegin, currentEnd, now)
            and currentBegin <= now then
            hasOwnTaunt = true
            if currentAbility == abilityId and math.abs(currentBegin - beginTime) < 0.12
                and math.abs(currentEnd - endTime) < 0.12 then return false end
            -- A legitimate renewal event can precede its buff-list refresh.
            -- The same record's previous application is not a contradiction.
            if previous and previous.sourceType == COMBAT_UNIT_TYPE_PLAYER and previous.abilityId == currentAbility
                and ValidTauntRange(previous.startTime, previous.endTime, now)
                and math.abs(currentBegin - previous.startTime) < 0.12
                and math.abs(currentEnd - previous.endTime) < 0.12 then return false end
        end
    end
    return hasOwnTaunt
end

local function EffectChanged(_, changeType, _, _, unitTag, beginTime, endTime,
                             _, _, _, effectType, _, _, unitName, unitId, abilityId, sourceType)
    -- Only the player and their own pet can create or alter tracked taunts.
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET then return end
    if not TAUNT_IDS[abilityId] or not unitId or unitId == 0 then return end
    local key = tostring(unitId)
    local t = A.targets[key]
    local ended = endedById[key]
    local now = Now()
    -- Fades carry their own ID and timing; the dynamic tag may already name
    -- a different unit. Never use it to reclassify a tracked enemy on a fade.
    if changeType == EFFECT_RESULT_FADED then
        if not t or t.expiredAt or t.sourceType ~= sourceType then return end
        local knownBegin = type(beginTime) == "number" and beginTime > 0
        if knownBegin and t.startKnown ~= false
            and math.abs(t.startTime - beginTime) > TAUNT_TIME_EPSILON then return end
        -- End-time-free fades cannot be attributed to a specific generation.
        -- Ignore them rather than clearing a taunt that may have been renewed.
        if t.abilityId == abilityId
            and type(endTime) == "number" and endTime > 0
            and math.abs(t.endTime - endTime) < 0.2 then
            -- A partial fade can also match a superseded application, even
            -- just after its original deadline. Let the current timer stand.
            if ended and RepeatsEndedApplication(ended, sourceType, abilityId, beginTime, knownBegin, endTime) then return end
            RememberEndedApplication(t, now)
            t.endTime, t.expiredAt = now, now
            A.DismissBossAlertForTarget(key, "early")
            A.RequestEffectTick()
        end
        return
    end
    if effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return end
    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED
        and changeType ~= EFFECT_RESULT_FULL_REFRESH then return end
    if not FiniteNumber(endTime) or endTime <= now
        or (beginTime ~= nil and not FiniteNumber(beginTime)) then return end
    local startKnown = type(beginTime) == "number" and beginTime > 0 and beginTime < endTime
    local startTime = startKnown and beginTime or (endTime - 15)
    if not ValidTauntRange(startTime, endTime, now) then return end
    if ended and RepeatsEndedApplication(ended, sourceType, abilityId, startTime, startKnown, endTime) then return end
    -- A repeat without a start time adds no evidence against the confirmed
    -- duration of this exact application (which need not last 15 seconds).
    if not startKnown and t and t.startKnown and t.sourceType == sourceType
        and t.abilityId == abilityId and t.endTime == endTime then
        startTime, startKnown = t.startTime, true
    end
    if t and t.startKnown ~= false and startKnown then
        if startTime < t.startTime - TAUNT_TIME_EPSILON then return end
    end
    local observationTag = unitTag
    if ReticleContextContradicts(key, unitTag, beginTime, endTime, abilityId, sourceType, now, t) then
        observationTag = nil
    end
    local isPlayer, playerTypeKnown = ObservePlayerTarget(key, observationTag)
    if (isPlayer or (t and t.isPlayer and not playerTypeKnown)) and not A.saved.trackPlayerTargets then
        if DropPlayerTarget(key) then A.RequestEffectTick() end
        return
    end
    -- Distinguish an actual re-taunt (new duration / returned lost target)
    -- from duplicate EFFECT_RESULT_UPDATED notifications with the same timer.
    local renewed = not t or t.expiredAt ~= nil or t.abilityId ~= abilityId or t.sourceType ~= sourceType
        or (startKnown and t.startKnown and startTime > t.startTime + TAUNT_TIME_EPSILON)
        or endTime > (t.endTime or 0) + 0.1
    if t and renewed then RememberEndedApplication(t, now) end
    -- A confirmed new application takes over from configuration samples.
    -- Exact duplicate updates and fades are not another taunt action.
    if not t and not MakeSpaceForTrackedTarget(now) then return end
    if renewed and A.EndDisplayPreviews then A.EndDisplayPreviews(true) end
    local observationChanged = renewed or t.startTime ~= startTime or t.endTime ~= endTime
        or t.sourceType ~= sourceType or t.dead
    local oldReticleId = A.reticleUnitId
    local oldBoss, oldDifficulty, oldPlayer = t and t.isBoss, t and t.bossDifficulty, t and t.isPlayer
    if not t then
        A.nextOrder = A.nextOrder + 1
        t = { unitId = key, order = A.nextOrder }
        A.targets[key] = t
    end
    local rawName = (unitName and unitName ~= "") and unitName or nil
    local displayChanged = not t.name or (rawName ~= nil and t.rawName ~= rawName)
    if displayChanged then
        t.name = rawName and zo_strformat("<<!aC:1>>", rawName) or T("Unknown enemy")
        t.rawName = rawName
    end
    t.startTime = startTime
    t.endTime = endTime
    t.abilityId = abilityId
    t.sourceType = sourceType
    t.startKnown = startKnown
    -- Accurate on events where ESO identifies the affected unit as bossN,
    -- or where a reticle unit is confirmed to equal an exposed boss tag.
    if playerTypeKnown or isPlayer then t.isPlayer=isPlayer end
    A.ObserveBoss(t, observationTag)
    observationChanged = ObserveTargetMarker(t, observationTag) or observationChanged
    ObserveReticleIdentity(key, observationTag)
    observationChanged = observationChanged or oldReticleId ~= A.reticleUnitId
        or oldBoss ~= t.isBoss or oldDifficulty ~= t.bossDifficulty or oldPlayer ~= t.isPlayer
    t.expiredAt = nil -- re-taunt immediately removes the red lost marker
    if renewed then
        t.tauntGeneration = (t.tauntGeneration or 0) + 1
        t.bossWarnQueued = nil
        t.dead = nil
        CancelPendingBossWarning(key)
        -- Also handle re-taunts after the expired entry left the HUD, but
        -- while its 2.5-second notification is still visible.
        A.DismissBossAlertForTarget(key)
    end
    if renewed or oldReticleId ~= A.reticleUnitId then QueueTargetMarkerRefresh(t) end
    if observationChanged or displayChanged then
        A.RequestEffectTick(observationChanged)
    elseif not A.updateRunning then
        -- An exact repeat has no new display data. Wake a sleeping scheduler
        -- if needed; an already registered tick will see the current record.
        A.RefreshUpdateState()
    end
end
local function CombatChanged(_, inCombat)
    A.inCombat = inCombat == true
    if A.inCombat and (A.reticlePreview or A.reticleMoving) then
        A.SetReticleMoveMode(false, true)
        A.reticlePreview, A.reticlePreviewAt = nil, nil
        A.reticleDirty = true -- resume real evidence, never the preview sample
        if A.RefreshSettingsPanel then A.RefreshSettingsPanel() end
    end
    -- Re-observe the aimed unit when the combat-only indicator becomes visible,
    -- even if the crosshair itself did not move.
    if A.saved.reticleStyle ~= "off" then A.reticleDirty = true end
    if not A.inCombat then
        CancelTargetMarkerRefresh()
        A.lastVisibleItems = nil
        A.listPeakRows, A.listPeakFooter = nil, nil
        playerTargetIds,playerTargetCount={},0
        if next(A.targets) then
            local now = Now()
            for _, target in pairs(A.targets) do RememberEndedApplication(target, now, true) end
        end
        A.targets, A.activeTarget, A.reticleUnitId = {}, nil, nil
        A.pendingBossWarnings, A.pendingFirstAt = nil, nil
        A.HideBossWarning()
    end
    A.Tick()
end

-- Only remove a tracked entry if the game supplies its exact combat unit ID.
-- Several monsters can have the same name; deleting by name would remove wrong taunts.
local function RemoveDeadUnit(unitId, deferTick)
    if not unitId or unitId == 0 then return end
    local key = tostring(unitId)
    local target = A.targets[key]
    if target then
        CancelTargetMarkerRefresh(target)
        -- Mark death regardless of the display removal preference.
        if not target.dead then RememberEndedApplication(target, Now()) end
        target.dead = true
        if A.activeTarget == key then A.activeTarget = nil end
        if A.reticleUnitId == key then A.reticleUnitId = nil end
        CancelPendingBossWarning(key)
        A.DismissBossAlertForTarget(key)
        if A.saved.removeDead then
            A.targets[key] = nil
        end
        -- Observations already run inside a tick, or their caller draws next.
        -- Avoid recursively rendering the HUD from the reticle polling fallback.
        if not deferTick then A.RequestEffectTick() end
    elseif A.bossAlerts.expired.subjects and A.bossAlerts.expired.subjects[key] then
        -- A red banner may outlive the row's two-second linger.
        A.DismissBossAlertForTarget(key, "expired")
        if not deferTick then A.RefreshUpdateState() end
    end
end

local function SetRemoveDead(enabled)
    if type(enabled) ~= "boolean" then return end
    A.saved.removeDead = enabled
    if enabled then
        -- Apply the preference to deaths already confirmed while rows were
        -- retained. Reuse exact-ID cleanup without rendering inside the loop.
        for key, target in pairs(A.targets) do
            if target.dead then RemoveDeadUnit(key, true) end
        end
    end
    A.Tick()
end

-- EVENT_COMBAT_EVENT:
-- (eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
--  sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType,
--  log, sourceUnitId, targetUnitId, abilityId, overflow)
local function CombatDeath(_, result, isError, _, _, _, _, _, _, _, _, _, _, _, _, targetUnitId)
    if not isError and A.DEATH_RESULTS[result] then
        RemoveDeadUnit(targetUnitId)
    end
end

-- Fallback for an enemy that dies while under the reticle. Only use the
-- ID confirmed by an effect event's current unit tag. Timer matching is only
-- a display hint and must never authorize deleting a tracked enemy.
local function ReticleDeath(_, unitTag, isDead)
    if unitTag == "reticleover" and isDead and A.reticleUnitId then
        RemoveDeadUnit(A.reticleUnitId)
    end
end

-- Public entry points used across modules.
A.PrunePlayerTargets = PrunePlayerTargets
A.IsLost = IsLost
A.Gather = Gather
A.MaintainLiveTargets = MaintainLiveTargets
A.SelectVisible = SelectVisible
A.StabilizeVisible = StabilizeVisible
A.ResolveReticleMarkerTarget = CorrelatedMarkerTarget
A.TargetChanged = TargetChanged
A.ReticleChanged = ReticleChanged
A.EffectChanged = EffectChanged
A.CombatChanged = CombatChanged
A.RemoveDeadUnit = RemoveDeadUnit
A.SetRemoveDead = SetRemoveDead
A.CombatDeath = CombatDeath
A.ReticleDeath = ReticleDeath
