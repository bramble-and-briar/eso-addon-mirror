DungeonScores = DungeonScores or {}

-- Boss encounter observation, death classification, and encounter identity tracking.

local DS = DungeonScores
local EM = EVENT_MANAGER
local Scoring = DS.Scoring
local Data = DS.Data
local Evidence = DS.EncounterEvidence

local NormalizeName = DS.Util.NormalizeName
local HasHealthLoss = DS.Util.HasHealthLoss

local function GetBossIdentityStartReason(previous, forceReset, wasDead, currentHealth)
    if not previous then
        return "boss-tag-appeared"
    end
    if forceReset == true then
        return "boss-list-force-reset"
    end
    if wasDead == true and tonumber(currentHealth) and currentHealth > 0 then
        return "boss-dead-to-live"
    end
    return nil
end

local function BossEncounterIdentitiesOverlap(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    for identityId, enabled in pairs(left) do
        if enabled and right[identityId] then
            return true
        end
    end
    return false
end

local function HasTableKeys(value)
    return type(value) == "table" and next(value) ~= nil
end

local function GetObservedPartySize(run)
    local maximumSize = Data.ELIGIBILITY and Data.ELIGIBILITY.maxGroupSize or 4
    local size = math.max(1, tonumber(run and run.partySizeCurrent) or 0,
        tonumber(GetGroupSize()) or 0)
    return math.min(maximumSize, math.floor(size))
end

local DEATH_LEDGER_NO_XP = 1
local DEATH_LEDGER_XP = 2
local ROUTINE_DEATH_DEDUPE_TTL_MS = 10000
local ROUTINE_DEATH_PRUNE_INTERVAL_MS = 2000
local BOSS_REFRESH_COALESCE_MS = 50

function DS:ResetRoutineDeathDedupe()
    -- Routine mob death IDs are needed only long enough to merge the immediate
    -- DIED/DIED_XP pair. Keeping every trash unit ID for the full dungeon grows a
    -- SavedVariables-backed hash table and can trigger Lua table rehash/GC work on
    -- the exact frames where packs die. Keep this dedupe state ephemeral and short.
    self.recentRoutineDeathStates = {}
    self.recentRoutineDeathTimes = {}
    self.nextRoutineDeathPruneAtMs = nil
end

function DS:PruneRoutineDeathDedupe(nowMs)
    local states = self.recentRoutineDeathStates
    local times = self.recentRoutineDeathTimes
    if not states or not times then
        return
    end

    nowMs = nowMs or GetGameTimeMilliseconds()
    if self.nextRoutineDeathPruneAtMs and nowMs < self.nextRoutineDeathPruneAtMs then
        return
    end
    self.nextRoutineDeathPruneAtMs = nowMs + ROUTINE_DEATH_PRUNE_INTERVAL_MS

    local cutoff = nowMs - ROUTINE_DEATH_DEDUPE_TTL_MS
    for key, seenAtMs in pairs(times) do
        if seenAtMs < cutoff then
            times[key] = nil
            states[key] = nil
        end
    end
end

function DS:GetRoutineDeathDedupeState(key, nowMs)
    local states = self.recentRoutineDeathStates
    local times = self.recentRoutineDeathTimes
    if not states or not times then
        self:ResetRoutineDeathDedupe()
        states = self.recentRoutineDeathStates
        times = self.recentRoutineDeathTimes
    end

    local seenAtMs = times[key]
    if not seenAtMs or (nowMs - seenAtMs) > ROUTINE_DEATH_DEDUPE_TTL_MS then
        if seenAtMs then
            times[key] = nil
            states[key] = nil
        end
        return nil
    end
    return states[key]
end

function DS:SetRoutineDeathDedupeState(key, state, nowMs)
    if not self.recentRoutineDeathStates or not self.recentRoutineDeathTimes then
        self:ResetRoutineDeathDedupe()
    end
    self.recentRoutineDeathStates[key] = state
    self.recentRoutineDeathTimes[key] = nowMs
end

function DS:RefreshRunEncounterLookups()
    -- EVENT_UNIT_DEATH_STATE_CHANGED is keyed by reusable bossN tags. Scope the
    -- cached prior state to the current boss identity so a dead boss1 cannot make
    -- the next boss1 look like an already-dead duplicate.
    self.bossDeathStateIdentity = {}

    if not self.run then
        return
    end

    -- Localized terminal-member rows remain display/legacy metadata only. The
    -- runtime lookup is deliberately empty because no generic numeric terminal
    -- resolver has been verified across all scored dungeons.

    -- Phase 4 and earlier persisted route-integrity records were keyed by
    -- normalized display names. They cannot be upgraded into identity evidence.
    -- Drop them and hold the restored run out of competitive settlement rather
    -- than silently treating localized strings as proof.
    local legacyRouteEvidence = false
    local identityLedger = {}
    for _, encounter in ipairs(self.run.bossEncounterLedger or {}) do
        if type(encounter) == "table"
            and (HasTableKeys(encounter.identities)
                or HasTableKeys(encounter.routeAbilityKeys)) then
            identityLedger[#identityLedger + 1] = encounter
        else
            legacyRouteEvidence = true
        end
    end
    self.run.bossEncounterLedger = identityLedger
    self.run.bossEncountersObserved = #identityLedger
    local active = self.run.activeBossEncounter
    if type(active) == "table"
        and (type(active.identities) ~= "table" or next(active.identities) == nil) then
        self.run.activeBossEncounter = nil
        legacyRouteEvidence = true
    end
    if legacyRouteEvidence and self.MarkRunPartial then
        self:MarkRunPartial("legacy-name-based-boss-encounter-ledger")
    end

    -- Numeric route evidence is durable, but event-local emitter IDs are not.
    -- Preserve completed semantic encounter keys and encounter-wide numeric
    -- counts across reload. Discard only incomplete per-emitter accumulation
    -- that cannot safely span UI sessions.
    self.run.routeAbilityEvidence = self.run.routeAbilityEvidence or {}
    for _, state in pairs(self.run.routeAbilityEvidence) do
        if type(state) == "table" and state.confirmed ~= true then
            state.emitters = {}
            if state.captureScope ~= "encounter-wide" then
                state.observedAbilityIds = {}
                state.observedAbilityCounts = {}
                state.lastEventFingerprint = nil
                state.lastEventAtMs = nil
            end
        end
    end
end

function DS:FindObservedBossEncounterByIdentities(identities)
    if not self.run or type(identities) ~= "table" then
        return nil
    end
    self.run.bossEncounterLedger = self.run.bossEncounterLedger or {}
    for index, encounter in ipairs(self.run.bossEncounterLedger) do
        if type(encounter) == "table"
            and BossEncounterIdentitiesOverlap(encounter.identities, identities) then
            return encounter, index
        end
    end
    return nil
end

function DS:FindObservedBossEncounterByRouteAbilityKey(encounterKey)
    if not self.run or type(encounterKey) ~= "string" or encounterKey == "" then
        return nil
    end
    for index, encounter in ipairs(self.run.bossEncounterLedger or {}) do
        if type(encounter) == "table" and type(encounter.routeAbilityKeys) == "table"
            and encounter.routeAbilityKeys[encounterKey] == true then
            return encounter, index
        end
    end
    return nil
end

function DS:FinalizeObservedBossEncounter(force)
    if not self.run or type(self.run.activeBossEncounter) ~= "table" then
        return false
    end

    local active = self.run.activeBossEncounter
    local identities = active.identities or {}
    if next(identities) == nil then
        self.run.activeBossEncounter = nil
        return false
    end

    local nowMs = GetGameTimeMilliseconds()
    if not force then
        -- Do not discard an unengaged boss set while its boss tags are still
        -- present. Preserve it until a real quiet gap so transient combat-state
        -- changes cannot force unnecessary boss rescans.
        local emptySinceMs = tonumber(active.emptySinceMs)
        if not emptySinceMs or nowMs - emptySinceMs < self.BOSS_ENCOUNTER_QUIET_MS then
            return false
        end
    end
    if active.engaged ~= true then
        self.run.activeBossEncounter = nil
        return false
    end

    local existing = self:FindObservedBossEncounterByIdentities(identities)
    if not existing then
        for encounterKey, enabled in pairs(active.routeAbilityKeys or {}) do
            if enabled == true then
                existing = self:FindObservedBossEncounterByRouteAbilityKey(encounterKey)
                if existing then
                    break
                end
            end
        end
    end
    if existing then
        for identityId, enabled in pairs(identities) do
            if enabled then
                existing.identities[identityId] = true
            end
        end
        existing.names = existing.names or {}
        for name, enabled in pairs(active.names or {}) do
            if enabled then
                existing.names[name] = true
            end
        end
        existing.lastSeenAtMs = active.lastSeenAtMs or nowMs
        existing.observationCount = (tonumber(existing.observationCount) or 1) + 1
        existing.routeAbilityKeys = existing.routeAbilityKeys or {}
        for encounterKey, enabled in pairs(active.routeAbilityKeys or {}) do
            if enabled == true then
                existing.routeAbilityKeys[encounterKey] = true
            end
        end
    else
        self.run.bossEncountersObserved = (tonumber(self.run.bossEncountersObserved) or 0) + 1
        local record = {
            number = self.run.bossEncountersObserved,
            identities = {},
            names = {},
            routeAbilityKeys = {},
            firstSeenAtMs = active.firstSeenAtMs,
            lastSeenAtMs = active.lastSeenAtMs or nowMs,
            observationCount = 1,
        }
        for identityId, enabled in pairs(identities) do
            if enabled then
                record.identities[identityId] = true
            end
        end
        -- Names are diagnostics only. They are never read to merge, split, count,
        -- complete, or establish competitive eligibility.
        for name, enabled in pairs(active.names or {}) do
            if enabled then
                record.names[name] = true
            end
        end
        for encounterKey, enabled in pairs(active.routeAbilityKeys or {}) do
            if enabled == true then
                record.routeAbilityKeys[encounterKey] = true
            end
        end
        self.run.bossEncounterLedger = self.run.bossEncounterLedger or {}
        self.run.bossEncounterLedger[#self.run.bossEncounterLedger + 1] = record
    end

    self.run.activeBossEncounter = nil
    self:TouchActiveRunPersistence()
    return true
end

function DS:ObserveBossEncounterSet(currentBosses)
    if not self.run then
        return
    end

    local nowMs = GetGameTimeMilliseconds()
    local currentIdentities = {}
    local currentNames = {}
    local currentEngaged = false
    for _, boss in pairs(currentBosses or {}) do
        local identityId = tonumber(boss.identityId)
        if identityId and identityId > 0 then
            currentIdentities[identityId] = true
        end
        local normalized = boss.normalizedName or NormalizeName(boss.name)
        if normalized and normalized ~= "" then
            currentNames[normalized] = true
        end
        if boss.hasTakenDamage == true or (boss.unitTag and IsUnitInCombat(boss.unitTag)) then
            currentEngaged = true
        end
    end

    if next(currentIdentities) == nil then
        local active = self.run.activeBossEncounter
        if active and not active.emptySinceMs then
            active.emptySinceMs = nowMs
        end
        return
    end

    -- If a defeated encounter is replaced directly by a disjoint boss set, close
    -- it even when ESO never exposes an intermediate empty boss list. This avoids
    -- merging two sequential fights into one integrity encounter. A direct death
    -- state is the split proof; localized death-event names are not.
    local previousActive = self.run.activeBossEncounter
    if previousActive and previousActive.engaged == true and previousActive.defeatObserved == true
        and not BossEncounterIdentitiesOverlap(previousActive.identities, currentIdentities) then
        self:FinalizeObservedBossEncounter(true)
    end

    -- If the previous boss set has been absent long enough, close it before a new
    -- set appears. This splits chain-of-encounter state without relying on English
    -- names or a hard-coded boss order.
    self:FinalizeObservedBossEncounter(false)

    local active = self.run.activeBossEncounter
    if not active then
        active = {
            identities = {},
            names = {},
            firstSeenAtMs = nowMs,
            lastSeenAtMs = nowMs,
            emptySinceMs = nil,
            engaged = false,
            defeatObserved = false,
        }
        self.run.activeBossEncounter = active
    end
    active.emptySinceMs = nil
    active.lastSeenAtMs = nowMs
    active.engaged = active.engaged == true or currentEngaged
    if currentEngaged then
        active.maxPartySize = math.max(tonumber(active.maxPartySize) or 0,
            GetObservedPartySize(self.run))
    end
    for identityId in pairs(currentIdentities) do
        active.identities[identityId] = true
    end
    for name in pairs(currentNames) do
        active.names[name] = true
    end
end

-- A verified three-boss health cohort is evidence of Volenfell's terminal
-- encounter in either Veteran difficulty mode. The identities are run-local
-- boss-tag generations, not unstable NPC spawn unit IDs or localized names.
-- The cohort is re-established on a new attempt; no old death can contribute.
function DS:InvalidateNumericTerminalCohort()
    local run = self.run
    if not run or not run.numericTerminalCohort then
        return false
    end
    run.numericTerminalCohort = nil
    if run.completionCandidateReason == "numeric-terminal-cohort"
        and run.completionCandidateAuthoritative ~= true
        and not run.completionAchieved then
        self:CancelCompletionCandidate()
    end
    self:TouchActiveRunPersistence()
    return true
end

function DS:ObserveNumericTerminalCohort(currentBosses, observedAtMs)
    local run = self.run
    local config = run and Data.NUMERIC_TERMINAL_COHORTS
        and Data.NUMERIC_TERMINAL_COHORTS[tonumber(run.zoneId)]
    if not config or run.finalized or run.completionAchieved then
        return false
    end

    local prior = run.numericTerminalCohort
    if prior then
        -- A fresh numeric-signature boss identity after a reset/wipe invalidates
        -- the entire previous pull, including any provisional completion.
        for _, boss in pairs(currentBosses or {}) do
            local id, maxHealth = tonumber(boss.identityId), tonumber(boss.maxHealth)
            if id and config.maxHealth[maxHealth] and not prior.identities[id] then
                self:InvalidateNumericTerminalCohort()
                prior = nil
                break
            end
        end
        if prior then
            return false
        end
    end

    local pools = {}
    for _, boss in pairs(currentBosses or {}) do
        local id, maxHealth = tonumber(boss.identityId), tonumber(boss.maxHealth)
        if id and id > 0 and config.maxHealth[maxHealth] then
            local pool = pools[maxHealth]
            if not pool then
                pool = { identities = {}, count = 0 }
                pools[maxHealth] = pool
            end
            if not pool.identities[id] then
                pool.identities[id] = true
                pool.count = pool.count + 1
            end
        end
    end

    local required = tonumber(config.required) or 0
    if required < 2 then
        return false
    end
    for maxHealth, pool in pairs(pools) do
        if pool.count == required then
            run.numericTerminalCohort = {
                identities = pool.identities,
                deaths = {},
                maxHealth = maxHealth,
                observedAtMs = observedAtMs or GetGameTimeMilliseconds(),
            }
            self:TouchActiveRunPersistence()
            return true
        end
    end
    return false
end

function DS:ObserveNumericTerminalCohortDeath(boss, eventTimeMs)
    local run = self.run
    local cohort = run and run.numericTerminalCohort
    local config = run and Data.NUMERIC_TERMINAL_COHORTS
        and Data.NUMERIC_TERMINAL_COHORTS[tonumber(run.zoneId)]
    local identityId = boss and tonumber(boss.identityId)
    if not config or not cohort or not identityId
        or not cohort.identities[identityId]
        or not run.startedAtMs
        or run.finalized or run.completionAchieved then
        return false
    end
    if cohort.deaths[identityId] then
        return false
    end
    cohort.deaths[identityId] = eventTimeMs or GetGameTimeMilliseconds()
    local deadCount = 0
    for id in pairs(cohort.identities) do
        if cohort.deaths[id] then
            deadCount = deadCount + 1
        end
    end
    self:TouchActiveRunPersistence()
    if deadCount == tonumber(config.required) then
        return self:MarkCompletionCandidate(
            "numeric-terminal-cohort", nil, cohort.deaths[identityId], false)
    end
    return false
end

function DS:MarkBossEncounterEngaged(boss)
    if not self.run or type(boss) ~= "table" then
        return false
    end
    local identityId = tonumber(boss.identityId)
    if not identityId or identityId <= 0 then
        return false
    end
    local nowMs = GetGameTimeMilliseconds()
    local active = self.run.activeBossEncounter
    if not active then
        active = {
            identities = {},
            names = {},
            firstSeenAtMs = nowMs,
            lastSeenAtMs = nowMs,
            emptySinceMs = nil,
            engaged = true,
            defeatObserved = false,
        }
        self.run.activeBossEncounter = active
    end
    active.identities = active.identities or {}
    active.identities[identityId] = true
    active.names = active.names or {}
    local normalized = boss.normalizedName or NormalizeName(boss.name)
    if normalized and normalized ~= "" then
        active.names[normalized] = true
    end
    active.engaged = true
    active.maxPartySize = math.max(tonumber(active.maxPartySize) or 0,
        GetObservedPartySize(self.run))
    active.lastSeenAtMs = nowMs
    return true
end

function DS:MarkBossEncounterDefeated(boss)
    if not self:MarkBossEncounterEngaged(boss) then
        return false
    end
    local active = self.run and self.run.activeBossEncounter or nil
    if active then
        active.defeatObserved = true
        active.lastDefeatAtMs = GetGameTimeMilliseconds()
        -- Freeze this attempt's party maximum at death. A later roster change
        -- during Activity Finder's completion delay cannot alter the fight.
        self.run.lastBossFightMaxPartySize = active.maxPartySize
        self.run.lastBossFightDeathAtMs = active.lastDefeatAtMs
        self.run.lastBossFightIdentityId = tonumber(boss.identityId)
        return true
    end
    return false
end

function DS:RecordRouteAbilityEncounter(encounterKey, state, observedAtMs)
    if not self.run or type(encounterKey) ~= "string" or encounterKey == "" then
        return false
    end

    observedAtMs = tonumber(observedAtMs) or GetGameTimeMilliseconds()
    local existing = self:FindObservedBossEncounterByRouteAbilityKey(encounterKey)
    if existing then
        existing.lastSeenAtMs = observedAtMs
        existing.observationCount = (tonumber(existing.observationCount) or 1) + 1
        return false
    end

    local active = self.run.activeBossEncounter
    if type(active) == "table" and HasTableKeys(active.identities) then
        local differentRouteKey = false
        for retainedKey, enabled in pairs(active.routeAbilityKeys or {}) do
            if enabled == true and retainedKey ~= encounterKey then
                differentRouteKey = true
                break
            end
        end
        if differentRouteKey then
            self:FinalizeObservedBossEncounter(true)
            active = nil
        end
    end

    if type(active) == "table" and HasTableKeys(active.identities) then
        active.routeAbilityKeys = active.routeAbilityKeys or {}
        active.routeAbilityKeys[encounterKey] = true
        active.engaged = true
        active.lastSeenAtMs = observedAtMs
        return true
    end

    self.run.bossEncountersObserved = (tonumber(self.run.bossEncountersObserved) or 0) + 1
    self.run.bossEncounterLedger = self.run.bossEncounterLedger or {}
    self.run.bossEncounterLedger[#self.run.bossEncounterLedger + 1] = {
        number = self.run.bossEncountersObserved,
        identities = {},
        names = {},
        routeAbilityKeys = { [encounterKey] = true },
        firstSeenAtMs = state and state.firstObservedAtMs or observedAtMs,
        lastSeenAtMs = observedAtMs,
        observationCount = 1,
        evidenceSource = "zone-ability-emission",
    }
    return true
end

function DS:HasObservedRouteAbilityEncounter(encounterKey)
    local state = self.run and self.run.routeAbilityEvidence
        and self.run.routeAbilityEvidence[encounterKey]
    if type(state) == "table" and state.confirmed == true then
        return true
    end
    return self:FindObservedBossEncounterByRouteAbilityKey(encounterKey) ~= nil
end

local function IsRouteDamageResult(result)
    if result == nil then
        return false
    end
    return (ACTION_RESULT_DAMAGE ~= nil and result == ACTION_RESULT_DAMAGE)
        or (ACTION_RESULT_CRITICAL_DAMAGE ~= nil and result == ACTION_RESULT_CRITICAL_DAMAGE)
        or (ACTION_RESULT_BLOCKED_DAMAGE ~= nil and result == ACTION_RESULT_BLOCKED_DAMAGE)
        or (ACTION_RESULT_DAMAGE_SHIELDED ~= nil and result == ACTION_RESULT_DAMAGE_SHIELDED)
end

local function BuildRouteEventFingerprint(abilityId, result, sourceUnitId,
    targetUnitId, hitValue, overflow)
    return table.concat({
        tostring(abilityId or 0),
        tostring(result or 0),
        tostring(sourceUnitId or 0),
        tostring(targetUnitId or 0),
        tostring(hitValue or 0),
        tostring(overflow or 0),
    }, ":")
end

function DS:ObserveRouteAbilityEmission(abilityId, sourceUnitId, observedAtMs,
    result, targetUnitId, hitValue, overflow)
    if not self.run or self.run.finalized or self.run.eligible == false then
        return false
    end

    abilityId = tonumber(abilityId) or 0
    sourceUnitId = tonumber(sourceUnitId) or 0
    targetUnitId = tonumber(targetUnitId) or 0
    if abilityId <= 0 then
        return false
    end

    local configs = Scoring:GetRouteAbilityEncounterConfigs(self.run.zoneId)
    if type(configs) ~= "table" then
        return false
    end

    observedAtMs = tonumber(observedAtMs) or GetGameTimeMilliseconds()
    self.run.routeAbilityEvidence = self.run.routeAbilityEvidence or {}
    local changed = false
    for index, config in ipairs(configs) do
        local encounterKey = type(config.key) == "string" and config.key
            or ("route-ability-" .. tostring(index))
        local priorKey = config.requiredPriorEncounterKey
        local prerequisiteReady = type(priorKey) ~= "string" or priorKey == ""
            or self:HasObservedRouteAbilityEncounter(priorKey)
        local directAbilityIds = type(config.directAbilityIds) == "table"
            and config.directAbilityIds or nil
        local sameEmitterAbilityIds = type(config.sameEmitterAbilityIds) == "table"
            and config.sameEmitterAbilityIds or config.abilityIds
        local encounterWideAbilityIds = type(config.encounterWideAbilityIds) == "table"
            and config.encounterWideAbilityIds or nil
        local directMatched = directAbilityIds
            and directAbilityIds[abilityId] == true
        local sameEmitterMatched = type(sameEmitterAbilityIds) == "table"
            and sameEmitterAbilityIds[abilityId] == true
        local encounterWideMatched = encounterWideAbilityIds
            and encounterWideAbilityIds[abilityId] == true
        local resultAccepted = config.requireDamageResult ~= true
            or IsRouteDamageResult(result)
        if prerequisiteReady and resultAccepted
            and (directMatched or sameEmitterMatched or encounterWideMatched) then
            local required = math.max(
                1, tonumber(config.requiredDistinctAbilityIds) or 1)

            -- ESO may omit sourceUnitId from a filtered combat event even when it
            -- supplies the numeric ability ID. A zone-unique, one-ability route
            -- signature does not need an actor join, so retain it encounter-wide.
            -- Multi-ability signatures still fail closed without a positive ID:
            -- their safety depends on proving that one run-local emitter supplied
            -- every configured ability.
            local canRetain = directMatched or encounterWideMatched
                or sourceUnitId > 0 or required <= 1
            if canRetain then
                local state = self.run.routeAbilityEvidence[encounterKey]
                if type(state) ~= "table" then
                    state = {
                        key = encounterKey,
                        firstObservedAtMs = observedAtMs,
                        observedAbilityIds = {},
                        observedAbilityCounts = {},
                        emitters = {},
                        captureScope = encounterWideAbilityIds
                            and "encounter-wide" or "event-local-emitter",
                        confirmed = false,
                    }
                    self.run.routeAbilityEvidence[encounterKey] = state
                    changed = true
                end
                state.lastObservedAtMs = observedAtMs

                if state.confirmed ~= true and directMatched then
                    state.observedAbilityIds[abilityId] = true
                    state.confirmed = true
                    state.confirmedAtMs = observedAtMs
                    state.confirmedSourceUnitId = sourceUnitId > 0
                        and sourceUnitId or nil
                    state.confirmationScope = "zone-unique-ability"
                    self:RecordRouteAbilityEncounter(
                        encounterKey, state, observedAtMs)
                    changed = true
                elseif state.confirmed ~= true and encounterWideMatched then
                    local fingerprint = BuildRouteEventFingerprint(
                        abilityId, result, sourceUnitId, targetUnitId,
                        hitValue, overflow)
                    local lastEventAtMs = tonumber(state.lastEventAtMs) or 0
                    local duplicate = state.lastEventFingerprint == fingerprint
                        and observedAtMs >= lastEventAtMs
                        and observedAtMs - lastEventAtMs <= 25
                    if not duplicate then
                        state.lastEventFingerprint = fingerprint
                        state.lastEventAtMs = observedAtMs
                        state.observedAbilityIds[abilityId] = true
                        state.observedAbilityCounts[abilityId] =
                            (tonumber(state.observedAbilityCounts[abilityId]) or 0) + 1
                        changed = true

                        local distinctCount = 0
                        local minimumsSatisfied = true
                        for configuredAbilityId, enabled in pairs(
                            encounterWideAbilityIds) do
                            if enabled == true then
                                local count = tonumber(
                                    state.observedAbilityCounts[configuredAbilityId]) or 0
                                if count > 0 then
                                    distinctCount = distinctCount + 1
                                end
                                local minimum = math.max(1, tonumber(
                                    config.minimumAbilityCounts
                                        and config.minimumAbilityCounts[configuredAbilityId]) or 1)
                                if count < minimum then
                                    minimumsSatisfied = false
                                end
                            end
                        end

                        -- Some mechanics emit a family of numeric events whose
                        -- combined frequency is the useful discriminator. Keep
                        -- the individual-ID minima above, then apply any
                        -- configured aggregate floors without inferring actor
                        -- identity from transient or missing source IDs.
                        if minimumsSatisfied
                            and type(config.minimumAbilityGroupCounts) == "table" then
                            for _, group in ipairs(
                                config.minimumAbilityGroupCounts) do
                                local groupCount = 0
                                if type(group) == "table"
                                    and type(group.abilityIds) == "table" then
                                    for groupedAbilityId, enabled in pairs(
                                        group.abilityIds) do
                                        if enabled == true then
                                            groupCount = groupCount + (tonumber(
                                                state.observedAbilityCounts[
                                                    groupedAbilityId]) or 0)
                                        end
                                    end
                                end
                                local groupMinimum = math.max(
                                    1, tonumber(type(group) == "table"
                                        and group.minimumCount or nil) or 1)
                                if groupCount < groupMinimum then
                                    minimumsSatisfied = false
                                    break
                                end
                            end
                        end
                        if distinctCount >= required and minimumsSatisfied then
                            state.confirmed = true
                            state.confirmedAtMs = observedAtMs
                            state.confirmationScope =
                                "encounter-wide-ability-threshold"
                            self:RecordRouteAbilityEncounter(
                                encounterKey, state, observedAtMs)
                        end
                    end
                elseif state.confirmed ~= true and sameEmitterMatched then
                    local emitterKey = sourceUnitId > 0
                        and tostring(sourceUnitId) or "encounter-wide"
                    local emitter = state.emitters[emitterKey]
                    if type(emitter) ~= "table" then
                        emitter = {
                            sourceUnitId = sourceUnitId > 0 and sourceUnitId or nil,
                            firstObservedAtMs = observedAtMs,
                            abilityIds = {},
                        }
                        state.emitters[emitterKey] = emitter
                        changed = true
                    end
                    emitter.lastObservedAtMs = observedAtMs
                    if emitter.abilityIds[abilityId] ~= true then
                        emitter.abilityIds[abilityId] = true
                        state.observedAbilityIds[abilityId] = true
                        changed = true
                    end

                    local distinctCount = 0
                    for configuredAbilityId, enabled in pairs(
                        sameEmitterAbilityIds or {}) do
                        if enabled == true
                            and emitter.abilityIds[configuredAbilityId] == true then
                            distinctCount = distinctCount + 1
                        end
                    end
                    if distinctCount >= required then
                        state.confirmed = true
                        state.confirmedAtMs = observedAtMs
                        state.confirmedSourceUnitId = sourceUnitId > 0
                            and sourceUnitId or nil
                        state.confirmationScope = sourceUnitId > 0
                            and "event-local-emitter" or "zone-unique-ability"
                        self:RecordRouteAbilityEncounter(
                            encounterKey, state, observedAtMs)
                        changed = true
                    end
                end
            end
        end
    end

    if changed then
        self:TouchActiveRunPersistence()
    end
    return changed
end

function DS:CountObservedRouteAbilityEncounters(run)
    run = run or self.run
    local count = 0
    for _, state in pairs(run and run.routeAbilityEvidence or {}) do
        if type(state) == "table" and state.confirmed == true then
            count = count + 1
        end
    end
    return count
end

function DS:GetObservedBossEncounterCountForCompletion()
    if not self.run then
        return 0
    end
    -- The official completion milestone proves the currently observed terminal
    -- boss encounter has concluded even if boss tags have not disappeared yet.
    self:FinalizeObservedBossEncounter(true)
    return tonumber(self.run.bossEncountersObserved) or 0
end

function DS:PollBossPowerStates()
    if not self.run or not self.run.startedAtMs or self.run.finalized or not self:IsArmed() then
        return
    end

    for unitTag in pairs(self.run.activeBosses or {}) do
        if DoesUnitExist(unitTag) then
            local currentHealth, maxHealth, effectiveMax = GetUnitPower(unitTag, POWERTYPE_HEALTH)
            self:OnBossPowerUpdate(unitTag, currentHealth, maxHealth, effectiveMax)
        end
    end
    self:UpdateHardModeEncounterCohortPresence(GetGameTimeMilliseconds())
end

function DS:CancelQueuedBossRefresh()
    if self.bossRefreshQueued then
        EM:UnregisterForUpdate(self.NAME .. "_BossRefreshCoalesce")
    end
    self.bossRefreshQueued = false
    self.pendingBossRefreshGeneration = nil
    self.pendingBossForceReset = nil
end

function DS:QueueBossRefresh(forceReset)
    if not self:IsArmed() then
        self:CancelQueuedBossRefresh()
        return
    end

    self.pendingBossRefreshGeneration = self.run and self.run.generation or nil
    if forceReset == true then
        self.pendingBossForceReset = true
    end

    if self.bossRefreshQueued then
        return
    end

    self.bossRefreshQueued = true
    EM:RegisterForUpdate(self.NAME .. "_BossRefreshCoalesce", BOSS_REFRESH_COALESCE_MS, function()
        EM:UnregisterForUpdate(self.NAME .. "_BossRefreshCoalesce")
        self.bossRefreshQueued = false

        local generation = self.pendingBossRefreshGeneration
        local pendingForceReset = self.pendingBossForceReset == true
        self.pendingBossRefreshGeneration = nil
        self.pendingBossForceReset = nil

        if not self.run or not self:IsArmed()
            or (generation and self.run.generation ~= generation) then
            return
        end

        self:RefreshBosses(pendingForceReset)
    end)
end

function DS:RefreshBosses(forceReset)
    if not self.run or not self:IsArmed() then
        return
    end

    local current = {}
    local observedAtMs = GetGameTimeMilliseconds()
    for index = 1, self.MAX_BOSS_TAGS do
        local unitTag = "boss" .. tostring(index)
        if DoesUnitExist(unitTag) then
            local name = GetUnitName(unitTag)
            local normalizedName = NormalizeName(name)
            local currentHealth, maxHealth, effectiveMax = GetUnitPower(unitTag, POWERTYPE_HEALTH)
            local previous = self.run.activeBosses[unitTag]
            local latestIdentityId = Evidence:GetLatestIdentityIdForUnitTag(self.run, unitTag)
            local previousIdentityId = previous and previous.identityId or nil
            local wasDead = previousIdentityId ~= nil
                and self.bossDeathStateIdentity
                and self.bossDeathStateIdentity[unitTag] == previousIdentityId
                and self.run.bossDeathState
                and self.run.bossDeathState[unitTag] == true
            local identityStartReason = GetBossIdentityStartReason(
                previous,
                forceReset,
                wasDead,
                currentHealth)
            if identityStartReason then
                previous = nil
            end

            local oldMax = previous and previous.maxHealth or nil
            local oldCurrent = previous and previous.currentHealth or nil
            local hadTakenDamage = (previous and previous.hasTakenDamage) or HasHealthLoss(oldCurrent, oldMax) or false
            local bossInCombat = IsUnitInCombat(unitTag)
            local returnedToPrepull = hadTakenDamage and maxHealth and maxHealth > 0 and currentHealth and currentHealth >= maxHealth and not bossInCombat

            local boss = previous
            if not boss then
                self.run.bossIdentitySequence = (self.run.bossIdentitySequence or 0) + 1
                -- bossN tags are recycled between encounters. Reset the tag-level
                -- death latch whenever a fresh boss identity is created; otherwise
                -- a prior boss1 death suppresses the next boss1 death transition.
                self.run.bossDeathState = self.run.bossDeathState or {}
                self.run.bossDeathState[unitTag] = false
                self.bossDeathStateIdentity = self.bossDeathStateIdentity or {}
                self.bossDeathStateIdentity[unitTag] = self.run.bossIdentitySequence
                boss = {
                    identityId = self.run.bossIdentitySequence,
                    predecessorIdentityId = latestIdentityId,
                    identityStartReason = identityStartReason,
                    unitTag = unitTag,
                    name = name,
                    normalizedName = normalizedName,
                    firstSeenMaxHealth = maxHealth,
                    maxObservedHealth = maxHealth,
                    hmActive = false,
                    hasTakenDamage = HasHealthLoss(currentHealth, maxHealth),
                    hmEncounterIndex = nil,
                    hmEncounterResolved = false,
                    healthHMAllowed = Scoring:IsHealthBasedHMAllowed(self.run.zoneId),
                }
            end

            boss.name = name
            boss.normalizedName = normalizedName
            boss.currentHealth = currentHealth
            boss.maxHealth = maxHealth
            boss.effectiveMaxHealth = effectiveMax
            boss.maxObservedHealth = math.max(boss.maxObservedHealth or 0, maxHealth or 0)
            boss.hasTakenDamage = hadTakenDamage or boss.hasTakenDamage or false

            local activePoolResetChanged =
                self:ClearBossHMActiveHealthPoolEvidenceOnReset(
                    boss,
                    oldCurrent,
                    currentHealth,
                    maxHealth,
                    bossInCombat)

            local _, evidenceChanged = Evidence:ObserveBoss(
                self.run,
                boss,
                currentHealth,
                maxHealth,
                effectiveMax,
                bossInCombat,
                observedAtMs)
            local hmHealthEncounterKey, hmEvidenceChanged =
                self:ResolveBossHMHealthEvidence(boss, observedAtMs)
            local hmActivePoolEncounterKey, hmActivePoolEvidenceChanged =
                self:ResolveBossHMActiveHealthPoolEvidence(boss, observedAtMs)
            if evidenceChanged or hmEvidenceChanged or hmActivePoolEvidenceChanged
                or activePoolResetChanged then
                self:TouchActiveRunPersistence()
            end

            if currentHealth and currentHealth > 0 then
                local deathStateIdentity = self.bossDeathStateIdentity
                    and self.bossDeathStateIdentity[unitTag] or nil
                local stillReportedDead = self.run.bossDeathState
                    and self.run.bossDeathState[unitTag] == true
                    and deathStateIdentity == boss.identityId
                if not stillReportedDead then
                    self:ClearTerminalBossDeathEvidenceForLiveBoss(boss)
                end
            end

            local hmEncounter, hmEncounterIndex = self:ResolveBossHardModeMetadata(boss)
            local healthHMAllowed = boss.healthHMAllowed ~= false
            if not healthHMAllowed then
                boss.hmActive = false
                boss.hmSource = "health-evidence-disabled"
            elseif hmActivePoolEncounterKey then
                boss.hmActive = true
                boss.hmSource = "known-active-health-pool"
            elseif hmHealthEncounterKey then
                boss.hmActive = true
                boss.hmSource = "known-health-signature"
            else
                boss.hmActive = false
                boss.hmSource = nil
            end

            if boss.hmActive then
                self:SetHardModeEncounterMemberHM(boss, true, hmEncounter, hmEncounterIndex)
            end

            if returnedToPrepull then
                boss.hasTakenDamage = false
            elseif HasHealthLoss(currentHealth, maxHealth) then
                boss.hasTakenDamage = true
            end

            current[unitTag] = boss
            if normalizedName ~= "" then
                self.run.seenBossNames[normalizedName] = boss
            end
        end
    end

    if Evidence:RecordBossCohort(self.run, current, observedAtMs) then
        self:TouchActiveRunPersistence()
    end
    self.run.activeBosses = current
    self:ObserveBossEncounterSet(current)
    self:ObserveNumericTerminalCohort(current, observedAtMs)
    -- Re-run verified-key resolution after the complete bossN snapshot and its
    -- numeric co-observation links have been retained. This closes the first-poll
    -- ordering gap and permits safe replay of an earlier member's death state.
    for _, boss in pairs(current) do
        if boss.hmEncounterResolutionSource == "zone-max-health"
            or boss.hmEncounterResolutionSource == "zone-active-health-pool" then
            self:ResolveBossHardModeMetadata(boss)
        end
    end
    local encounterAttemptReset = self:MaybeResetHardModeEncounterAttemptsFromBossReappearance()
    if encounterAttemptReset then
        -- Rebuild verified cohort state into the fresh attempt immediately. This
        -- keeps a wipe/re-pull reset from depending on a later health change.
        for _, boss in pairs(current) do
            if boss.hmEncounterResolutionSource == "zone-max-health"
                or boss.hmEncounterResolutionSource == "zone-active-health-pool" then
                self:ResolveBossHardModeMetadata(boss)
            end
        end
    end
    self:UpdateHardModeEncounterCohortPresence(observedAtMs)
    self:RefreshHud()
end

function DS:OnBossPowerUpdate(unitTag, powerValue, powerMax, powerEffectiveMax)
    if not self.run or not self:IsArmed() then
        return
    end

    local boss = self.run.activeBosses[unitTag]
    if not boss then
        self:RefreshBosses()
        boss = self.run.activeBosses[unitTag]
    end
    if not boss then
        return
    end

    -- A settled, engaged boss with the same health sample has supplied no new
    -- evidence. Skip the encounter and HM reconciliation work on idle polls.
    local activeEncounter = self.run.activeBossEncounter
    if boss.hasTakenDamage == true and activeEncounter and activeEncounter.engaged == true
        and boss.currentHealth == powerValue and boss.maxHealth == powerMax
        and boss.effectiveMaxHealth == powerEffectiveMax then
        return
    end

    local oldMax = boss.maxHealth
    local oldCurrent = boss.currentHealth
    local oldHM = boss.hmActive
    local maxHealthChanged = oldMax ~= powerMax
    local hasHealthLoss = HasHealthLoss(powerValue, powerMax)

    boss.currentHealth = powerValue
    boss.maxHealth = powerMax
    boss.effectiveMaxHealth = powerEffectiveMax
    if powerMax and powerMax > (boss.maxObservedHealth or 0) then
        boss.maxObservedHealth = powerMax
    end

    local observedAtMs = GetGameTimeMilliseconds()
    local bossInCombatForPoolReset = nil
    local activePoolResetChanged = false
    if boss.hmEncounterResolutionSource == "zone-active-health-pool"
        and oldCurrent and powerValue and tonumber(powerValue) > tonumber(oldCurrent) then
        bossInCombatForPoolReset = IsUnitInCombat(unitTag)
        activePoolResetChanged = self:ClearBossHMActiveHealthPoolEvidenceOnReset(
            boss,
            oldCurrent,
            powerValue,
            powerMax,
            bossInCombatForPoolReset)
    end
    local _, evidenceChanged = Evidence:ObserveBoss(
        self.run,
        boss,
        powerValue,
        powerMax,
        powerEffectiveMax,
        nil,
        observedAtMs)
    local hmHealthEncounterKey, hmEvidenceChanged = self:ResolveBossHMHealthEvidence(
        boss,
        observedAtMs)
    local hmActivePoolEncounterKey, hmActivePoolEvidenceChanged =
        self:ResolveBossHMActiveHealthPoolEvidence(boss, observedAtMs)
    if evidenceChanged or hmEvidenceChanged or hmActivePoolEvidenceChanged
        or activePoolResetChanged then
        self:TouchActiveRunPersistence()
    end

    -- Boss power changes were previously delivered through one of ESO's highest-frequency
    -- event streams. Even under 500 ms polling, keep the steady-state path minimal:
    -- once a boss has already taken damage, an unchanged max-health sample
    -- carries no new HM/pre-pull information. Keep that overwhelmingly common path
    -- allocation-free and avoid IsUnitInCombat/config/signature work entirely.
    if not maxHealthChanged and boss.hasTakenDamage == true and hasHealthLoss
        and (not (hmHealthEncounterKey or hmActivePoolEncounterKey)
            or boss.hmActive == true)
        and not activePoolResetChanged
        and boss.hmHealthEvidenceConflict ~= true then
        local activeEncounter = self.run.activeBossEncounter
        if not activeEncounter or activeEncounter.engaged ~= true then
            self:MarkBossEncounterEngaged(boss)
        end
        return
    end

    local hmEncounter, hmEncounterIndex = self:ResolveBossHardModeMetadata(boss)
    local hadTakenDamage = boss.hasTakenDamage or HasHealthLoss(oldCurrent, oldMax) or false
    local bossInCombat = bossInCombatForPoolReset
    if bossInCombat == nil then
        bossInCombat = IsUnitInCombat(unitTag)
    end
    local returnedToPrepull = hadTakenDamage and powerMax and powerMax > 0
        and powerValue and powerValue >= powerMax and not bossInCombat
    local healthHMAllowed = boss.healthHMAllowed ~= false
    local knownHMSignature = healthHMAllowed and hmHealthEncounterKey ~= nil
    local knownHMActivePool = healthHMAllowed and hmActivePoolEncounterKey ~= nil

    if not healthHMAllowed then
        boss.hmActive = false
        boss.hmSource = "health-evidence-disabled"
    elseif knownHMActivePool then
        boss.hmActive = true
        boss.hmSource = "known-active-health-pool"
    elseif knownHMSignature then
        boss.hmActive = true
        boss.hmSource = "known-health-signature"
    else
        boss.hmActive = false
        boss.hmSource = nil
    end

    if boss.hmActive then
        self:SetHardModeEncounterMemberHM(boss, true, hmEncounter, hmEncounterIndex)
    end

    if returnedToPrepull then
        boss.hasTakenDamage = false
    elseif hasHealthLoss then
        boss.hasTakenDamage = true
    end

    if (bossInCombat or hasHealthLoss) and (not activeEncounter or activeEncounter.engaged ~= true) then
        self:MarkBossEncounterEngaged(boss)
    end

    if maxHealthChanged or oldHM ~= boss.hmActive then
        self:RefreshHud()
    end
end

function DS:RecordTerminalBossDeathEvidence(boss, unitTag, eventTimeMs)
    if not self.run or not boss then
        return false
    end

    local identityId = tonumber(boss.identityId)
    local normalized = boss.normalizedName or NormalizeName(boss.name)
    if not identityId or identityId <= 0 then
        return false
    end

    self.run.terminalBossDeathEvidence = self.run.terminalBossDeathEvidence or {}
    self.run.terminalBossDeathEvidence[identityId] = {
        identityId = identityId,
        normalizedName = normalized,
        bossName = boss.name,
        unitTag = unitTag or boss.unitTag,
        unitId = tonumber(boss.unitId),
        observedAtMs = eventTimeMs or GetGameTimeMilliseconds(),
        maxHealth = boss.maxHealth,
    }
    return true
end

function DS:RecordBossDeathStateCredit(boss, eventTimeMs)
    if not self.run or not boss then
        return false
    end

    local identityId = tonumber(boss.identityId)
    if not identityId or identityId <= 0 then
        return false
    end

    self.run.bossDeathStateCredits = self.run.bossDeathStateCredits or {}
    if self.run.bossDeathStateCredits[identityId] then
        return false
    end

    eventTimeMs = eventTimeMs or GetGameTimeMilliseconds()
    self.run.bossDeathStateCredits[identityId] = {
        identityId = identityId,
        observedAtMs = eventTimeMs,
        unitTag = boss.unitTag,
        -- Display text is retained only for diagnostics/history presentation.
        bossName = boss.name,
        normalizedName = boss.normalizedName or NormalizeName(boss.name),
    }
    self.run.bossKills = (tonumber(self.run.bossKills) or 0) + 1
    self.run.lastBossDeathAtMs = eventTimeMs
    self.run.lastBossDeathIdentityId = identityId
    self.run.lastBossDeathName = boss.normalizedName or NormalizeName(boss.name)
    return true
end

function DS:ClearTerminalBossDeathEvidenceForLiveBoss(boss)
    if not self.run or not boss or type(self.run.terminalBossDeathEvidence) ~= "table" then
        return false
    end

    local identityId = tonumber(boss.identityId)
    local predecessorIdentityId = tonumber(boss.predecessorIdentityId)
    local removed = false

    if identityId and self.run.terminalBossDeathEvidence[identityId] then
        self.run.terminalBossDeathEvidence[identityId] = nil
        removed = true
    end

    -- A dead-to-live identity transition explicitly links to the prior boss-tag
    -- identity. Invalidate that exact predecessor without comparing display text.
    if predecessorIdentityId and self.run.terminalBossDeathEvidence[predecessorIdentityId] then
        self.run.terminalBossDeathEvidence[predecessorIdentityId] = nil
        removed = true
    end

    return removed
end

function DS:ReconcileTerminalBossDeathCredits()
    if not self.run or self.run.finalized then
        return 0
    end

    local evidenceLedger = self.run.terminalBossDeathEvidence
    if type(evidenceLedger) ~= "table" then
        return 0
    end

    self.run.reconciledBossKills = self.run.reconciledBossKills or {}
    local reconciled = 0

    for identityKey, evidence in pairs(evidenceLedger) do
        if type(evidence) == "table" then
            local identityId = tonumber(evidence.identityId) or tonumber(identityKey)
            local normalized = evidence.normalizedName or NormalizeName(evidence.bossName)
            local seen = nil
            for _, candidate in pairs(self.run.activeBosses or {}) do
                if tonumber(candidate.identityId) == identityId then
                    seen = candidate
                    break
                end
            end
            if not seen then
                for _, candidate in pairs(self.run.seenBossNames or {}) do
                    if tonumber(candidate.identityId) == identityId then
                        seen = candidate
                        break
                    end
                end
            end
            local seenIdentityId = seen and tonumber(seen.identityId) or nil
            local seenHealth = seen and tonumber(seen.currentHealth) or nil

            -- Reconciliation is intentionally narrow: the boss must have retained
            -- death-state evidence for this exact identity and its retained boss
            -- state must still be at zero health when authoritative completion is
            -- processed. Merely being observed, disappearing, or completing an
            -- encounter is insufficient.
            local terminalEvidence = identityId ~= nil
                and seen ~= nil
                and seenIdentityId == identityId
                and seenHealth ~= nil
                and seenHealth <= 0

            if terminalEvidence
                and not (self.run.bossDeathStateCredits
                    and self.run.bossDeathStateCredits[identityId])
                and not self.run.reconciledBossKills[identityId] then
                self.run.reconciledBossKills[identityId] = {
                    identityId = identityId,
                    normalizedName = normalized,
                    bossName = evidence.bossName or (seen and seen.name) or normalized,
                    unitId = evidence.unitId,
                    observedAtMs = evidence.observedAtMs,
                    reconciledAtMs = GetGameTimeMilliseconds(),
                    source = "terminal-death-evidence",
                }
                self.run.bossKills = (self.run.bossKills or 0) + 1
                if type(self.RecordHealthHMNonHMDefeat) == "function" then
                    self:RecordHealthHMNonHMDefeat(seen)
                end
                reconciled = reconciled + 1
            end
        end
    end

    if reconciled > 0 then
        self:TouchActiveRunPersistence()
    end
    return reconciled
end

function DS:BuildDeathKey(targetUnitId, eventTimeMs, targetType, sourceUnitId, abilityId)
    local numericUnitId = tonumber(targetUnitId)
    if numericUnitId and numericUnitId ~= 0 then
        -- Use the native numeric unit id directly instead of allocating a string
        -- for every DIED/DIED_XP event in the short-lived dedupe cache.
        return numericUnitId
    end

    -- No language-independent target identity exists when the combat event omits
    -- targetUnitId. Use only numeric event evidence and a narrow time bucket. An
    -- ambiguous simultaneous kill may undercount, but display text never decides
    -- whether score is duplicated.
    local bucket = math.floor((eventTimeMs or GetGameTimeMilliseconds()) / 250)
    return string.format(
        "fallback:%d:%d:%d:%d",
        tonumber(targetType) or 0,
        tonumber(sourceUnitId) or 0,
        tonumber(abilityId) or 0,
        bucket)
end

function DS:ClassifyDeath(result)
    -- EVENT_COMBAT_EVENT exposes numeric source/target IDs, but the supported boss
    -- unit-tag APIs do not expose the same ID for a language-independent join.
    -- Combat deaths therefore remain ordinary scored kills. Boss/HM accounting is
    -- driven separately by direct boss-tag death-state identities.
    if result == ACTION_RESULT_DIED_XP then
        return "mob"
    end
    return "no_xp_unclassified"
end

function DS:CanProcessDeathEvent()
    -- Normal in-instance deaths are the highest-volume path. Once an eligible run
    -- is active, rely on the activation/group-maintained eligibility cache rather
    -- than calling the full zone/dungeon API stack for every mob death.
    if self.run and self.run.eligible and not self.run.finalized
        and not self.pendingActiveRunRestore and not self.pendingFrozenZoneCheck
        and not self.playerDeactivated and self:IsArmed() then
        return true
    end

    if not self.run and self:IsArmed() then
        return true
    end

    return false
end

function DS:OnDeathCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
    sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log,
    sourceUnitId, targetUnitId, abilityId, overflow)

    if not self:CanProcessDeathEvent() then
        return
    end

    if not self.run then
        self:NewRun(false, "encounter-death-event")
    end
    if self.run.finalized then
        return
    end

    self:EnsureRunStarted("death-event-fallback")

    local eventTimeMs = GetGameTimeMilliseconds()
    self:ObserveTerminalAbilityActorDeath(targetUnitId, eventTimeMs)
    -- Only scoring and numeric terminal-cohort evidence is retained here. The former
    -- chronological combat-death log was write-only and allocated one table per
    -- death, plus an index entry, without any downstream consumers.
    local key = self:BuildDeathKey(
        targetUnitId,
        eventTimeMs,
        targetType,
        sourceUnitId,
        abilityId)

    local class = self:ClassifyDeath(result)

    local routineState = self:GetRoutineDeathDedupeState(key, eventTimeMs)
    if routineState ~= nil then
        if result == ACTION_RESULT_DIED_XP and routineState == DEATH_LEDGER_NO_XP then
            self:SetRoutineDeathDedupeState(key, DEATH_LEDGER_XP, eventTimeMs)
            self.run.noXpDeaths = math.max(0, self.run.noXpDeaths - 1)
            self.run.xpKills = self.run.xpKills + 1
            local noXpValue = Data.SCORING.noXpKill or 0
            self.run.killScore = self.run.killScore + math.max(0, Data.SCORING.xpKill - noXpValue)
        end
        return
    end

    self.run.uniqueDeaths = self.run.uniqueDeaths + 1
    self.run.lastDeathAtMs = eventTimeMs

    local killPoints
    if result == ACTION_RESULT_DIED_XP then
        self.run.xpKills = self.run.xpKills + 1
        killPoints = Data.SCORING.xpKill
        self.run.killScore = self.run.killScore + killPoints
    else
        self.run.noXpDeaths = self.run.noXpDeaths + 1
        killPoints = Data.SCORING.noXpKill or 0
        self.run.killScore = self.run.killScore + killPoints
    end

    -- Keep only the short-lived two-state marker needed to merge the immediate
    -- DIED/DIED_XP pair. This state is deliberately not under SavedVariables.
    self:SetRoutineDeathDedupeState(
        key,
        result == ACTION_RESULT_DIED_XP and DEATH_LEDGER_XP or DEATH_LEDGER_NO_XP,
        eventTimeMs)
end

function DS:OnBossDeathStateChanged(unitTag, isDead)
    if not self.run or self.run.finalized or not self:IsArmed() then
        return
    end

    local boss = self.run.activeBosses and self.run.activeBosses[unitTag] or nil
    if not boss and self:IsArmed() then
        self:RefreshBosses()
        boss = self.run.activeBosses and self.run.activeBosses[unitTag] or nil
    end

    self.run.bossDeathState = self.run.bossDeathState or {}
    self.bossDeathStateIdentity = self.bossDeathStateIdentity or {}
    local currentIdentityId = boss and boss.identityId or nil
    local previousIdentityId = self.bossDeathStateIdentity[unitTag]
    local sameIdentity = currentIdentityId ~= nil
        and previousIdentityId ~= nil
        and currentIdentityId == previousIdentityId
    local previousState = sameIdentity and self.run.bossDeathState[unitTag] == true

    self.run.bossDeathState[unitTag] = isDead == true
    self.bossDeathStateIdentity[unitTag] = currentIdentityId
    if boss then
        boss.deathStateObserved = isDead == true
    end

    local eventTimeMs = GetGameTimeMilliseconds()
    if Evidence:RecordDeathState(
        self.run,
        boss,
        isDead,
        eventTimeMs) then
        self:TouchActiveRunPersistence()
    end

    if isDead and not previousState and boss then
        self:RecordTerminalBossDeathEvidence(boss, unitTag, eventTimeMs)
        self:RecordBossDeathStateCredit(boss, eventTimeMs)
        -- An abandoned-HM penalty requires the reset HM encounter to have
        -- actually been defeated on ordinary Veteran, not merely wiped.
        if type(self.RecordHealthHMNonHMDefeat) == "function" then
            self:RecordHealthHMNonHMDefeat(boss)
        end
        self:MarkBossEncounterDefeated(boss)
        if Scoring:UsesEncounterScopedHM(self.run.zoneId) then
            self:RecordHardModeEncounterIdentityDeath(
                boss,
                "boss-death-state",
                eventTimeMs)
        else
            local aggregateFinalHM = Scoring:RequiresAggregateFinalEncounterHM(self.run.zoneId)
            local hasStableEncounterKey = Scoring:IsVerifiedHMEncounterResolutionSource(
                    boss.hmEncounterResolutionSource)
                and type(boss.hmEncounterKey) == "string"
                and boss.hmEncounterKey ~= ""
            if boss.hmActive and (not aggregateFinalHM or hasStableEncounterKey) then
                self:AwardHardModeCredit(boss)
            end
        end

        -- The zone-specific numeric terminal cohort is sufficient completion
        -- evidence even without Activity Finder. A snapshot, not the final score
        -- freeze, follows once the normal HM grace interval has elapsed.
        self:ObserveNumericTerminalCohortDeath(boss, eventTimeMs)
        self:CheckAutoCompletion("boss-death-state")
    elseif not isDead and previousState and boss then
        local cohort = self.run.numericTerminalCohort
        if cohort and cohort.identities[tonumber(boss.identityId)] then
            -- A revived member is proof the previous pull was not complete.
            self:InvalidateNumericTerminalCohort()
        end
        self:ClearTerminalBossDeathEvidenceForLiveBoss(boss)
        local hmEncounter, hmIndex = self:ResolveBossHardModeMetadata(boss)
        if hmEncounter then
            local hmAttempt = self:GetHardModeEncounterAttempt(hmEncounter, hmIndex)
            local identityId = tonumber(boss.identityId)
            if hmAttempt and identityId and hmAttempt.identityDeaths
                and hmAttempt.identityDeaths[identityId] and not hmAttempt.credited then
                self:ResetHardModeEncounterAttempt(hmEncounter, hmIndex)
            end
        end
    end

    self:TouchActiveRunPersistence()
end

function DS:GetStableGroupMemberKey(unitTag)
    local displayName = GetUnitDisplayName(unitTag)
    if displayName and displayName ~= "" then
        return displayName
    end

    local name = GetUnitName(unitTag)
    if name and name ~= "" then
        return NormalizeName(name)
    end

    return unitTag
end

function DS:OnGroupDeathStateChanged(unitTag, isDead)
    if not self:IsArmed() or not self.run or self.run.finalized then
        return
    end

    local key = self:GetStableGroupMemberKey(unitTag)
    local previous = self.run.groupDeathState[key] == true
    self.run.groupDeathState[key] = isDead == true

    if isDead and not previous then
        self:EnsureRunStarted("group-death-fallback")
        self.run.deaths = self.run.deaths + 1
        self:TouchActiveRunPersistence()
        self:RefreshHud()
    end
end

function DS:OnBossesChanged(forceReset)
    -- Boss-list churn can arrive during /reloadui, loading, a suspended port-out,
    -- or a terminal session boundary. None of those states may create or extend
    -- durable encounter evidence before PLAYER_ACTIVATED revalidates the instance.
    if not self:IsArmed() then
        return
    end

    if not self.run then
        -- NewRun already performs one authoritative boss refresh. Do not queue a
        -- second scan for the same first boss-change signal.
        self:NewRun(false, "encounter-boss-change")
        return
    end

    -- This event is a refresh hint, not scoring evidence. Avoid allocating an
    -- unused timeline entry or flushing persistence before the coalesced scan.
    -- The live run is already saved by reference, and RefreshBosses persists
    -- relevant identity/HM transitions as they are observed.

    -- EVENT_BOSSES_CHANGED can burst repeatedly around phase swaps, summons, and
    -- encounter cleanup. Collapse those signals into one boss-tag scan instead of
    -- repeating the full 20-tag/HM/observer/HUD path in the same short window.
    self:QueueBossRefresh(forceReset)
end

