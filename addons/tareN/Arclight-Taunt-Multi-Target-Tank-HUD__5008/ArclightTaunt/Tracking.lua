-- Arclight Taunt 1.0.3 | Tracking module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local T = A.T
local COUNTER_NAMES = A.COUNTER_NAMES
local CanonicalEffectName = A.CanonicalEffectName
local EXPIRED_LINGER = A.EXPIRED_LINGER
local IMMUNITY_NAMES = A.IMMUNITY_NAMES
local IMMUNITY_STACK_THRESHOLD = A.IMMUNITY_STACK_THRESHOLD
local MAX_TRACKED_TARGETS = A.MAX_TRACKED_TARGETS
local Now = A.Now
local TAUNT_IDS = A.TAUNT_IDS

local function CreateDemo(count)
    local now = Now()
    local names = {
        T("Scorpion"), T("Scorpion"), T("Bone Colossus"), T("Daedra Guardian"),
        T("Scorpion"), T("Shadow Beast"), T("Bone Golem"), T("Bone Golem"),
        "Lord Okyl", T("Scorpion"), T("Daedra Guardian"), T("Ogrim"),
        T("Shadow Beast"), T("Skeleton Guardian"), T("Scorpion"), T("Shadow Beast"),
        T("Daedroth"), T("Bone Golem"), T("Ogrim"), T("Ogrim"), T("Gargoyle"), T("Scorpion"),
        T("Atronach"), T("Bone Golem"),
    }
    -- A tiny preview-only easter egg: Lord Okyl is one of the sample bosses.
    -- Character names stay language-neutral and do not affect real tracking.
    -- The preview includes genuine lost-taunt examples for testing the red state.
    local durations = {-0.4, -1.1, 1.2, 2.8, 3.8, 4.5, 5.8, 6.7, 7.6, 8.4, 9.2, 10.5,
                       11.9, 12.9, 13.7, 14.2, 14.6, 14.7, 14.8, 14.9, 15.0, 15.0, 15.0, 15.0}
    local entries = {}
    for i = 1, count do
        local name = names[i]
        entries[#entries + 1] = {
            name = name, unitId = "demo" .. i,
            startTime = now - (15 - durations[i]), endTime = now + durations[i],
            expiredAt = (durations[i] <= 0) and (now + durations[i]) or nil,
            mine = true, order = i, isBoss = (i == 3 or i == 9),
            tauntStacks = ((i == 4) and 3 or (i == 3 and 5 or nil)),
            counterEnd = (i == 3 or i == 4) and (now + 6.8) or nil,
            immuneUntil = (i == 3) and (now + 6.8) or nil,
        }
    end
    A.demoAt = now
    return entries
end

-- A faded or elapsed taunt no longer means an active taunt. Keep a brief
-- 0,0 indicator (or a persistent one if the user explicitly opts in).
local function IsLost(t, now)
    return t.expiredAt ~= nil or t.endTime <= now
end

-- Using the first-seen sequence as a tie-breaker keeps same-color enemies
-- stable even when their countdowns differ or a taunt gets refreshed.
local function AlertRank(t, now)
    local remaining = t.endTime - now
    if remaining <= A.saved.dangerAt then return 1 end
    if remaining <= A.saved.warningAt then return 2 end
    return 3
end
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
-- table.sort is synchronous; all comparisons in this Gather use one timestamp.
local sortNow
local function WarningLess(a, b)
    local aRank, bRank = AlertRank(a, sortNow), AlertRank(b, sortNow)
    if aRank ~= bRank then return aRank < bRank end
    return StableLess(a, b)
end

local function Gather(now, skipSort)
    local active, lost = {}, {}
    if A.demo then
        if not A.demoEntries or now - A.demoAt >= 16 then
            A.demoEntries = CreateDemo(A.demoCount or 14)
        end
        for _, t in ipairs(A.demoEntries) do
            if t.endTime <= now and not t.expiredAt then t.expiredAt = now end
            if not IsLost(t, now) then
                active[#active + 1] = t
            elseif A.saved.showExpired or (t.immuneUntil and t.immuneUntil > now)
                or now - t.expiredAt < EXPIRED_LINGER then
                lost[#lost + 1] = t
            end
        end
    else
        for key, t in pairs(A.targets) do
            if t.immuneUntil and t.immuneUntil <= now then t.immuneUntil = nil end
            if t.counterEnd and t.counterEnd <= now then
                t.tauntStacks, t.counterEnd = nil, nil
            end
            if t.endTime <= now and not t.expiredAt then t.expiredAt = now end
            if not IsLost(t, now) then
                active[#active + 1] = t
            elseif A.saved.showExpired or (t.immuneUntil and t.immuneUntil > now)
                or now - t.expiredAt < EXPIRED_LINGER then
                lost[#lost + 1] = t
            else
                A.targets[key] = nil
                if A.reticleUnitId == key then A.reticleUnitId = nil end
            end
        end
    end
    if not skipSort and #active > 1 then
        sortNow = now
        table.sort(active, A.saved.sortMode == "stable" and WarningLess or RemainingLess)
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
    -- active boss timers retain the user-selected sort mode from Gather.
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
    local lostBudget = #nonBossActive > 0
        and math.min(3, math.max(1, math.floor(remainingSlots / 4))) or remainingSlots
    -- Both active sort modes place danger-zone taunts first. Protect those
    -- slots before reserving space for losses; explicit boss pins stay above.
    local now, criticalCount = Now(), 0
    for _, t in ipairs(nonBossActive) do
        if t.endTime - now <= A.saved.dangerAt then
            criticalCount = criticalCount + 1
        end
    end
    lostBudget = math.min(lostBudget, math.max(0, remainingSlots - criticalCount))
    local lostCount = math.min(#nonBossLost, lostBudget)
    local activeCount = math.min(#nonBossActive, remainingSlots - lostCount)
    lostCount = math.min(#nonBossLost, remainingSlots - activeCount)
    for i = 1, lostCount do items[#items + 1] = nonBossLost[i] end
    for i = 1, activeCount do items[#items + 1] = nonBossActive[i] end
    return items
end
-- The ESO buff API exposes real stack counts. We only display values when
-- the current target has been matched to a tracked taunt by ability/time.
-- The observed name fallback is intentionally conservative: unknown
-- translations produce no badge rather than a false immunity warning.
local function TargetChanged()
    A.activeTarget = nil
    A.reticleDirty = nil
    A.lastReticleScan = Now()
    if not DoesUnitExist("reticleover") then
        A.reticleUnitId = nil
        return
    end
    local candidates
    local now = Now()
    local identified = A.reticleUnitId and A.targets[A.reticleUnitId]
    local diagnostics = A.saved.showImmunity or A.saved.showTauntStacks
    if identified and not identified.dead and not IsLost(identified, now) then
        A.activeTarget = identified.unitId
    end
    if identified and not diagnostics then
        -- Direct identity already resolves focus; timing guesses need no buff
        -- scan here. Boss observation still follows the current valid unit tag.
        if A.activeTarget then
            A.ObserveBoss(identified, "reticleover")
            identified.tauntStacks, identified.counterEnd, identified.immuneUntil = nil, nil, nil
        end
        return
    end
    if not identified then
        candidates = {}
        for _, t in pairs(A.targets) do
            if not t.dead and not IsLost(t, now) then candidates[#candidates + 1] = t end
        end
    end
    local observedCounter, observedCounterEnd, observedImmuneEnd
    local buffCount = GetNumBuffs("reticleover") or 0
    for i = 1, buffCount do
        local effectName, beginTime, endTime, _, stackCount, _, _, _, _, _, abilityId, _, castByPlayer =
            GetUnitBuffInfo("reticleover", i)
        -- Foreign/pet effects cannot prove which of our entries is under the
        -- reticle. They need a direct event identity instead of a timer guess.
        if not identified and castByPlayer == true and TAUNT_IDS[abilityId]
            and type(beginTime) == "number" and type(endTime) == "number" then
            local match, matchCount = nil, 0
            for _, t in ipairs(candidates) do
                if t.sourceType == COMBAT_UNIT_TYPE_PLAYER and t.abilityId == abilityId
                    and math.abs(t.startTime - beginTime) < 0.12
                    and math.abs(t.endTime - endTime) < 0.12 then
                    match, matchCount = t, matchCount + 1
                end
            end
            -- Two simultaneous identical timers are ambiguous; never mark
            -- a specific enemy on a guessed match.
            if matchCount > 1 then
                A.activeTarget = nil
                return
            elseif matchCount == 1 then
                if A.activeTarget and A.activeTarget ~= match.unitId then
                    A.activeTarget = nil
                    return -- conflicting matches: refuse to highlight any target
                end
                A.activeTarget = match.unitId
            end
        end
        if diagnostics then
            local canonical = CanonicalEffectName(effectName)
            if COUNTER_NAMES[canonical] and type(stackCount) == "number"
                and stackCount >= 1 and stackCount <= IMMUNITY_STACK_THRESHOLD
                and type(endTime) == "number" and endTime > now then
                observedCounter, observedCounterEnd = stackCount, endTime
            elseif IMMUNITY_NAMES[canonical] and type(endTime) == "number" and endTime > now then
                observedImmuneEnd = endTime
            end
        end
    end
    -- Do not reuse the previous target merely because its immunity timer is active.
    -- The reticle may already be on a different, equally named enemy.
    local matched = A.activeTarget and A.targets[A.activeTarget]
    if not matched then return end
    A.ObserveBoss(matched, "reticleover")
    -- A complete new observation replaces stale diagnostic state. Keep an
    -- explicit immunity effect even when the independently observed counter is low.
    matched.tauntStacks, matched.counterEnd = observedCounter, observedCounterEnd
    local counterImmuneEnd = observedCounter and observedCounter >= IMMUNITY_STACK_THRESHOLD
        and observedCounterEnd or nil
    local immuneEnd = math.max(observedImmuneEnd or 0, counterImmuneEnd or 0)
    matched.immuneUntil = immuneEnd > now and immuneEnd or nil
end

local function ReticleChanged()
    A.reticleUnitId = nil -- unit tags are dynamic; a target switch invalidates proof
    TargetChanged()
    A.Tick()
end

local function ObserveReticleIdentity(key, unitTag)
    if type(unitTag) ~= "string" or unitTag == "" or not DoesUnitExist("reticleover") then return end
    if unitTag == "reticleover" or (type(AreUnitsEqual) == "function"
        and DoesUnitExist(unitTag) and AreUnitsEqual(unitTag, "reticleover")) then
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
        A.targets[oldestId] = nil
        if A.activeTarget == oldestId then A.activeTarget = nil end
        if A.reticleUnitId == oldestId then A.reticleUnitId = nil end
        return true
    end
    return false -- do not evict an active taunt in order to accept another
end

local function EffectChanged(_, changeType, _, _, unitTag, beginTime, endTime,
                             _, _, _, effectType, _, _, unitName, unitId, abilityId, sourceType)
    if not TAUNT_IDS[abilityId] or not unitId or unitId == 0 then return end
    local key = tostring(unitId)
    local t = A.targets[key]
    local now = Now()

    -- Handle FADED before testing sourceType: fade events may report a different
    -- origin than the original application. Avoid erasing newer re-taunts.
    if changeType == EFFECT_RESULT_FADED then
        -- End-time-free fades cannot be attributed to a specific generation.
        -- Ignore them rather than clearing a taunt that may have been renewed.
        if t and t.abilityId == abilityId
            and type(endTime) == "number" and endTime > 0
            and math.abs(t.endTime - endTime) < 0.2 then
            t.endTime, t.expiredAt = now, now
            A.DismissBossAlertForTarget(key, "early")
            A.RequestEffectTick()
        end
        return
    end
    if effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return end
    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED
        and changeType ~= EFFECT_RESULT_FULL_REFRESH then return end
    local mine = sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
    local fromGroup = sourceType == COMBAT_UNIT_TYPE_GROUP
    if not mine and (A.saved.onlyMine or not fromGroup) then return end
    if not endTime or endTime <= now then return end
    -- Distinguish an actual re-taunt (new duration / returned lost target)
    -- from duplicate EFFECT_RESULT_UPDATED notifications with the same timer.
    local renewed = not t or t.expiredAt ~= nil or t.abilityId ~= abilityId
        or t.mine ~= mine or endTime > (t.endTime or 0) + 0.1
    local startTime = (beginTime and beginTime > 0 and beginTime < endTime) and beginTime or (endTime - 15)
    local observationChanged = renewed or t.startTime ~= startTime or t.endTime ~= endTime
        or t.sourceType ~= sourceType or t.dead
    local oldReticleId = A.reticleUnitId
    local oldBoss, oldDifficulty = t and t.isBoss, t and t.bossDifficulty
    if not t then
        if not MakeSpaceForTrackedTarget(now) then return end
        A.nextOrder = A.nextOrder + 1
        t = { unitId = key, order = A.nextOrder }
        A.targets[key] = t
    end
    local rawName = (unitName and unitName ~= "") and unitName or nil
    local displayChanged = not t.name or t.rawName ~= rawName
    if displayChanged then
        t.name = rawName and zo_strformat("<<!aC:1>>", rawName) or T("Unknown enemy")
        t.rawName = rawName
    end
    t.startTime = startTime
    t.endTime = endTime
    t.abilityId = abilityId
    t.mine = mine
    t.sourceType = sourceType
    -- Accurate on events where ESO identifies the affected unit as bossN,
    -- or where a reticle unit is confirmed to equal an exposed boss tag.
    A.ObserveBoss(t, unitTag)
    ObserveReticleIdentity(key, unitTag)
    observationChanged = observationChanged or oldReticleId ~= A.reticleUnitId
        or oldBoss ~= t.isBoss or oldDifficulty ~= t.bossDifficulty
    t.expiredAt = nil -- re-taunt immediately removes the red lost marker
    if renewed then
        t.tauntGeneration = (t.tauntGeneration or 0) + 1
        t.bossWarnQueued = nil
        t.dead = nil
        if A.pendingBossWarnings then A.pendingBossWarnings[key] = nil end
        -- Also handle re-taunts after the expired entry left the HUD, but
        -- while its 2.5-second notification is still visible.
        A.DismissBossAlertForTarget(key)
    end
    -- A new taunt does not itself prove the current immunity/counter state.
    -- Reticle observation will refresh those separately.
    if observationChanged or displayChanged then
        A.RequestEffectTick(observationChanged)
    else
        -- Exact repeats carry no new display data. Keep the normal timer awake
        -- instead of running a complete HUD tick for each notification.
        A.RefreshUpdateState()
    end
end
local function CombatChanged(_, inCombat)
    A.inCombat = inCombat == true
    if not A.inCombat then
        A.targets, A.activeTarget, A.reticleUnitId = {}, nil, nil
        A.pendingBossWarnings, A.pendingFirstAt = nil, nil
        A.HideBossWarning()
    end
    A.Tick()
end

-- Only remove a tracked entry if the game supplies its exact combat unit ID.
-- Several monsters can have the same name; deleting by name would remove wrong taunts.
local function RemoveDeadUnit(unitId)
    if not unitId or unitId == 0 then return end
    local key = tostring(unitId)
    local target = A.targets[key]
    if target then
        -- Mark death regardless of the display removal preference.
        target.dead = true
        if A.activeTarget == key then A.activeTarget = nil end
        if A.reticleUnitId == key then A.reticleUnitId = nil end
        if A.pendingBossWarnings then A.pendingBossWarnings[key] = nil end
        A.DismissBossAlertForTarget(key)
        if A.saved.removeDead then
            A.targets[key] = nil
        end
        A.Tick()
    end
end

-- EVENT_COMBAT_EVENT:
-- (eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
--  sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType,
--  log, sourceUnitId, targetUnitId, abilityId, overflow)
local function CombatDeath(_, result, _, _, _, _, _, _, _, _, _, _, _, _, _, targetUnitId)
    if result == ACTION_RESULT_DIED or result == ACTION_RESULT_DIED_XP then
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
A.CreateDemo = CreateDemo
A.IsLost = IsLost
A.Gather = Gather
A.SelectVisible = SelectVisible
A.TargetChanged = TargetChanged
A.ReticleChanged = ReticleChanged
A.EffectChanged = EffectChanged
A.CombatChanged = CombatChanged
A.RemoveDeadUnit = RemoveDeadUnit
A.CombatDeath = CombatDeath
A.ReticleDeath = ReticleDeath
