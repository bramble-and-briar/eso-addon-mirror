-- Arclight Taunt 1.1.0 | Tracking module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local T = A.T
local EXPIRED_LINGER = A.EXPIRED_LINGER
local MAX_TRACKED_TARGETS = A.MAX_TRACKED_TARGETS
local Now = A.Now
local TAUNT_IDS = A.TAUNT_IDS
local TAUNT_TIME_EPSILON = 0.01
local playerTargetIds, playerTargetCount = {}, 0
-- Event sourceType describes the caster, never the affected target. Only a
-- currently valid unit tag can establish player/NPC type for this exact ID.
local function ObservePlayerTarget(key, unitTag)
    if type(unitTag) == "string" and unitTag ~= "" and type(IsUnitPlayer) == "function"
        and DoesUnitExist(unitTag) then
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
local function DropPlayerTarget(key)
    local existed = A.targets[key] ~= nil
    A.targets[key] = nil
    if A.activeTarget == key then A.activeTarget = nil end
    if A.reticleUnitId == key then A.reticleUnitId = nil end
    if A.pendingBossWarnings then
        A.pendingBossWarnings[key] = nil
        if not next(A.pendingBossWarnings) then
            A.pendingBossWarnings, A.pendingFirstAt = nil, nil
        end
    end
    A.DismissBossAlertForTarget(key)
    return existed
end
local function PrunePlayerTargets()
    if A.saved.trackPlayerTargets then return end
    for key, target in pairs(A.targets) do
        if target.isPlayer or playerTargetIds[key] then DropPlayerTarget(key) end
    end
end

-- Display samples only, never a boss-detection list. Sources: docs/VORSCHAU_2026-11-02.md.
local DEMO_BOSSES = {"Rakkhat", "Nahviintaas", "Yolnahkriin", "Grundwulf", "Maarselok", "Balorgh"}
local DEMO_ENEMIES = {
    "Dro-m'Athra Hulk", "Dro-m'Athra Shadowguard", "Void Caller", "Alkosh's Roar",
    "Iron Servant", "Sea Behemoth", "Hulking Werewolf", "Flame Atronach",
    "Frost Atronach", "Storm Atronach", "Daedroth", "Ogrim", "Gargoyle", "Bone Colossus",
}
local MAX_DEMO_ENEMIES, DEMO_TAUNT_SECONDS = 24, 15
local DEMO_COMBAT_SECONDS = 60
local demoRoster
local function DemoNow(now)
    return A.demo and A.demoPausedAt or now
end
local function ShuffledSamples(source)
    local result = {}
    for i, name in ipairs(source) do result[i] = name end
    -- Use the client's random generator without reseeding shared addon state.
    for i = #result, 2, -1 do
        local j = math.random(i)
        result[i], result[j] = result[j], result[i]
    end
    return result
end
local function DemoRoster(count)
    local bosses, enemies = ShuffledSamples(DEMO_BOSSES), ShuffledSamples(DEMO_ENEMIES)
    local bossCount = count >= 17 and 3 or (count >= 9 and 2 or 1)
    -- Once per new roster, not once per tick or countdown loop.
    if math.random(10) == 1 then bosses[math.random(bossCount)] = "Lord Okyl" end
    local roster, bossIndex, enemyIndex = {}, 1, 1
    for i = 1, count do
        local boss = i == (count < 3 and 1 or 3) or i == 9 or i == 17
        local name
        if boss then
            name, bossIndex = bosses[bossIndex], bossIndex + 1
        else
            name = enemies[(enemyIndex - 1) % #enemies + 1]
            enemyIndex = enemyIndex + 1
        end
        roster[i] = {name = T(name), isBoss = boss}
    end
    return roster
end

local function CreateDemo(count, keepRoster, startedAt)
    local now = startedAt or DemoNow(Now())
    count = math.floor(A.Clamp(count or 14, 1, MAX_DEMO_ENEMIES))
    if not keepRoster or not demoRoster or #demoRoster ~= count then demoRoster = DemoRoster(count) end
    -- Join an encounter already in progress. Stagger old applications and later
    -- single arrivals; random values are drawn only when a cycle is created.
    local initialCount = math.min(count, 4 + math.random(3))
    local nextArrival, lastEnd = 0, now
    local entries = {}
    for i = 1, count do
        local sample = demoRoster[i]
        local startTime
        if i <= initialCount then
            local age = 0.5 + (i - 1) * 11.5 / math.max(1,initialCount - 1) + math.random(1000) / 1250
            startTime = now - age
        else
            nextArrival = nextArrival + 0.55 + math.random(1550) / 1000
            startTime = now + nextArrival
        end
        local starts = {startTime}
        -- Prepare a bounded minute of irregular re-taunts once, not per tick.
        -- Some refresh before expiry; others leave a brief lapse in coverage.
        local nextStart = math.max(now + 0.8 + math.random(2000) / 1000,
            startTime + 11 + math.random(10000) / 1000)
        while nextStart < now + DEMO_COMBAT_SECONDS do
            starts[#starts + 1] = nextStart
            nextStart = nextStart + 11 + math.random(10000) / 1000
        end
        entries[#entries + 1] = {
            name = sample.name, unitId = "demo" .. i,
            startTime = startTime, endTime = startTime + DEMO_TAUNT_SECONDS,
            order = i, isBoss = sample.isBoss,
            demoStarts = starts, demoApplication = 1,
        }
        lastEnd = math.max(lastEnd, starts[#starts] + DEMO_TAUNT_SECONDS)
    end
    A.demoAt = now
    A.demoFocusId, A.demoFocusUntil, A.demoFocusOrder = nil, nil, 0
    A.demoCycleLength = lastEnd - now + EXPIRED_LINGER + 1 + math.random(1000) / 1000
    return entries
end

local function SetDemoPaused(paused)
    if not A.demo then A.demoPausedAt = nil; return end
    local now = Now()
    if paused then
        A.demoPausedAt = A.demoPausedAt or now
    elseif A.demoPausedAt then
        local delta = now - A.demoPausedAt
        for _, t in ipairs(A.demoEntries or {}) do
            t.startTime, t.endTime = t.startTime + delta, t.endTime + delta
            for i, start in ipairs(t.demoStarts or {}) do t.demoStarts[i] = start + delta end
            if t.expiredAt then t.expiredAt = t.expiredAt + delta end
        end
        if A.demoAt then A.demoAt = A.demoAt + delta end
        if A.demoFocusUntil then A.demoFocusUntil = A.demoFocusUntil + delta end
        if A.focusAcquiredAt then A.focusAcquiredAt = A.focusAcquiredAt + delta end
        for target, at in pairs(A.rowEntryStarts or {}) do A.rowEntryStarts[target] = at + delta end
        for _, row in ipairs(A.rows or {}) do
            if row.stripeAt then row.stripeAt = row.stripeAt + delta end
        end
        A.demoPausedAt = nil
    end
end
local function SetDemoEnabled(enabled)
    A.demoPausedAt = nil
    A.demoFocusId, A.demoFocusUntil, A.demoFocusOrder = nil, nil, 0
    A.demo = enabled == true
    if A.demo then A.demoEntries = CreateDemo(A.demoCount or 14) end
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

local function Gather(now, skipSort)
    now = DemoNow(now)
    local active, lost = {}, {}
    if A.demo then
        if not A.demoEntries then
            A.demoEntries = CreateDemo(A.demoCount or 14)
        elseif now - A.demoAt >= A.demoCycleLength then
            A.demoEntries = CreateDemo(A.demoCount or 14, false, now)
        end
        for _, t in ipairs(A.demoEntries) do
            local starts, application = t.demoStarts, t.demoApplication or 1
            if starts then
                while starts[application + 1] and starts[application + 1] <= now do
                    application = application + 1
                end
                if application ~= t.demoApplication then
                    t.demoApplication = application
                    t.startTime = starts[application]
                    t.endTime = t.startTime + DEMO_TAUNT_SECONDS
                    t.expiredAt = nil
                end
            end
            if t.startTime <= now then
                if t.endTime <= now and not t.expiredAt then t.expiredAt = t.endTime end
                if not IsLost(t, now) then
                    active[#active + 1] = t
                elseif A.saved.showExpired or now - t.expiredAt < EXPIRED_LINGER then
                    lost[#lost + 1] = t
                end
            end
        end
    else
        for key, t in pairs(A.targets) do
            if t.endTime <= now and not t.expiredAt then t.expiredAt = now end
            if not IsLost(t, now) then
                active[#active + 1] = t
            elseif A.saved.showExpired
                or now - t.expiredAt < EXPIRED_LINGER then
                lost[#lost + 1] = t
            else
                A.targets[key] = nil
                if A.reticleUnitId == key then A.reticleUnitId = nil end
            end
        end
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
    local now, criticalCount = DemoNow(Now()), 0
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
-- Resolve focus from direct identity or a unique own-taunt timing match.
local function TargetChanged()
    A.activeTarget = nil
    A.reticleDirty = nil
    A.lastReticleScan = Now()
    if not DoesUnitExist("reticleover") then
        A.reticleUnitId = nil
        return
    end
    local now = Now()
    local identified = A.reticleUnitId and A.targets[A.reticleUnitId]
    local player = type(IsUnitPlayer)=="function" and IsUnitPlayer("reticleover")
    if identified then
        identified.isPlayer=ObservePlayerTarget(identified.unitId,"reticleover")
        if identified.isPlayer and not A.saved.trackPlayerTargets then DropPlayerTarget(identified.unitId);return end
    elseif player and not A.saved.trackPlayerTargets then
        return -- a timer match is not permission to delete an uncertain NPC row
    end
    -- Death notifications need not arrive while the target is under the
    -- reticle. Reuse the existing observation interval, but only remove a row
    -- with direct event identity, never a matching name or guessed timer.
    if identified and type(IsUnitDead) == "function" and IsUnitDead("reticleover") then
        A.RemoveDeadUnit(identified.unitId, true)
        return
    end
    if identified and not identified.dead and not IsLost(identified, now) then
        A.activeTarget = identified.unitId
    end
    if identified then
        -- Direct identity already resolves focus; timing guesses need no buff
        -- scan here. Boss observation still follows the current valid unit tag.
        if A.activeTarget then
            A.ObserveBoss(identified, "reticleover")
        end
        return
    end
    local candidates = {}
    for _, t in pairs(A.targets) do
        if not t.dead and not IsLost(t, now) then candidates[#candidates + 1] = t end
    end
    if #candidates == 0 then return end
    local buffCount = GetNumBuffs("reticleover") or 0
    for i = 1, buffCount do
        local _, beginTime, endTime, _, _, _, _, _, _, _, abilityId, _, castByPlayer =
            GetUnitBuffInfo("reticleover", i)
        -- Foreign/pet effects cannot prove which of our entries is under the
        -- reticle. They need a direct event identity instead of a timer guess.
        if castByPlayer == true and TAUNT_IDS[abilityId]
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
    end
    local matched = A.activeTarget and A.targets[A.activeTarget]
    if not matched then return end
    A.ObserveBoss(matched, "reticleover")
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
    -- Only the player and their own pet can create or alter tracked taunts.
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER_PET then return end
    if not TAUNT_IDS[abilityId] or not unitId or unitId == 0 then return end
    local key = tostring(unitId)
    local t = A.targets[key]
    local now = Now()
    local isPlayer,playerTypeKnown = ObservePlayerTarget(key,unitTag)
    if (isPlayer or (t and t.isPlayer and not playerTypeKnown)) and not A.saved.trackPlayerTargets then
        if DropPlayerTarget(key) then A.RequestEffectTick() end
        return
    end

    -- A fade must match the source and application timing of the tracked taunt.
    -- Old applications must not erase a newer re-taunt.
    if changeType == EFFECT_RESULT_FADED then
        if t and t.sourceType ~= sourceType then return end
        local knownBegin = type(beginTime) == "number" and beginTime > 0
        if t and knownBegin and t.startKnown ~= false
            and math.abs(t.startTime - beginTime) > TAUNT_TIME_EPSILON then return end
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
    if not endTime or endTime <= now then return end
    local startKnown = type(beginTime) == "number" and beginTime > 0 and beginTime < endTime
    local startTime = startKnown and beginTime or (endTime - 15)
    if t and t.startKnown ~= false and startKnown then
        if startTime < t.startTime - TAUNT_TIME_EPSILON then return end
    end
    -- Distinguish an actual re-taunt (new duration / returned lost target)
    -- from duplicate EFFECT_RESULT_UPDATED notifications with the same timer.
    local renewed = not t or t.expiredAt ~= nil or t.abilityId ~= abilityId
        or endTime > (t.endTime or 0) + 0.1
    local observationChanged = renewed or t.startTime ~= startTime or t.endTime ~= endTime
        or t.sourceType ~= sourceType or t.dead
    local oldReticleId = A.reticleUnitId
    local oldBoss, oldDifficulty, oldPlayer = t and t.isBoss, t and t.bossDifficulty, t and t.isPlayer
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
    t.sourceType = sourceType
    t.startKnown = startKnown
    -- Accurate on events where ESO identifies the affected unit as bossN,
    -- or where a reticle unit is confirmed to equal an exposed boss tag.
    if playerTypeKnown or isPlayer then t.isPlayer=isPlayer end
    A.ObserveBoss(t, unitTag)
    ObserveReticleIdentity(key, unitTag)
    observationChanged = observationChanged or oldReticleId ~= A.reticleUnitId
        or oldBoss ~= t.isBoss or oldDifficulty ~= t.bossDifficulty or oldPlayer ~= t.isPlayer
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
        playerTargetIds,playerTargetCount={},0
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
        -- Mark death regardless of the display removal preference.
        target.dead = true
        if A.activeTarget == key then A.activeTarget = nil end
        if A.reticleUnitId == key then A.reticleUnitId = nil end
        if A.pendingBossWarnings then A.pendingBossWarnings[key] = nil end
        A.DismissBossAlertForTarget(key)
        if A.saved.removeDead then
            A.targets[key] = nil
        end
        -- Observations already run inside a tick, or their caller draws next.
        -- Avoid recursively rendering the HUD from the reticle polling fallback.
        if not deferTick then A.Tick() end
    end
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
A.CreateDemo = CreateDemo
A.PrunePlayerTargets = PrunePlayerTargets
A.DemoNow = DemoNow
A.SetDemoPaused = SetDemoPaused
A.SetDemoEnabled = SetDemoEnabled
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
