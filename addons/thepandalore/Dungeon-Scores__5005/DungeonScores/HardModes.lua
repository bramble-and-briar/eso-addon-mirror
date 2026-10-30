DungeonScores = DungeonScores or {}

-- Hard Mode attempt state, observer lifecycle, and HM credit reconciliation.

local DS = DungeonScores
local EM = EVENT_MANAGER
local Scoring = DS.Scoring
local Data = DS.Data
local Evidence = DS.EncounterEvidence

local HasHealthLoss = DS.Util.HasHealthLoss
local ConditionalHMResolvers = DS.ConditionalHMResolvers or {}
local HM_NONHM_RESET_CONFIRM_MS = 3000

local function IsPlayerSideCombatUnitType(unitType)
    return unitType == COMBAT_UNIT_TYPE_PLAYER
        or unitType == COMBAT_UNIT_TYPE_GROUP
        or unitType == COMBAT_UNIT_TYPE_PLAYER_PET
        or (COMBAT_UNIT_TYPE_COMPANION ~= nil and unitType == COMBAT_UNIT_TYPE_COMPANION)
end

-- Health-signature HM evidence belongs to the *current pull*, not to the
-- lifetime of an ESO bossN tag or run-local identity. A full, out-of-combat
-- boss with a non-HM max-health pool disproves the old pull's positive sample.
-- This must also clear the *encounter-scoped* attempt latch: otherwise the
-- boss HUD can de-arm while a multi-HM attempt remains qualified for credit.
--
-- Earthgore's identity-count final encounter can transition through distinct
-- health pools and incarnations. A full non-HM pool alone is not sufficient
-- evidence of a wipe there; keep that exception until numeric lifecycle
-- evidence reliably distinguishes phase transitions from resets.
-- Retain one tiny, stable-key-only history of *direct* numeric HM evidence.
-- The ordinary HM attempt state is correctly reset on wipes; it must not be
-- reused as evidence for the separately scored abandoned-HM penalty.
-- Conditional/speed-alternative HMs and same-max-health active-pool signatures
-- never enter this ledger.
function DS:RecordHealthHMActivation(encounterKey)
    if not self.run or type(encounterKey) ~= "string" or encounterKey == ""
        or not Scoring:IsHealthBasedHMAllowed(self.run.zoneId)
        or (Data.ALTERNATE_HM_SCORING_ZONES
            and Data.ALTERNATE_HM_SCORING_ZONES[tonumber(self.run.zoneId)] == true) then
        return false
    end
    self.run.hmAbandonmentEvidence = self.run.hmAbandonmentEvidence or {}
    local record = self.run.hmAbandonmentEvidence[encounterKey]
    if type(record) == "table" and record.activated == true then
        return false
    end
    self.run.hmAbandonmentEvidence[encounterKey] = {
        activated = true,
        deactivated = false,
    }
    self:TouchActiveRunPersistence()
    return true
end

function DS:RecordHealthHMDeactivation(encounterKey, boss)
    local ledger = self.run and self.run.hmAbandonmentEvidence
    local record = type(ledger) == "table" and ledger[encounterKey] or nil
    if type(record) ~= "table" or record.activated ~= true then
        return false
    end
    local changed = record.deactivated ~= true
    record.deactivated = true
    -- A later ordinary-Veteran death must be linked to the SAME observed
    -- run-local boss identity. Never guess this link from localized names or
    -- a reused bossN tag. If ESO replaces its identity, fail closed instead
    -- of inventing a penalized completed encounter.
    local identityId = boss and tonumber(boss.identityId) or nil
    if identityId and identityId > 0 then
        record.deactivatedIdentityIds = record.deactivatedIdentityIds or {}
        if record.deactivatedIdentityIds[identityId] ~= true then
            record.deactivatedIdentityIds[identityId] = true
            changed = true
        end
    end
    if changed then
        self:TouchActiveRunPersistence()
    end
    return changed
end

function DS:RecordHealthHMNonHMDefeat(boss)
    if not self.run or not boss or boss.hmActive == true
        or boss.hmEncounterKey ~= nil then
        return false
    end
    local identityId = tonumber(boss.identityId)
    if not identityId or identityId <= 0 then
        return false
    end
    local changed = false
    for encounterKey, record in pairs(self.run.hmAbandonmentEvidence or {}) do
        if type(record) == "table" and record.activated == true
            and record.deactivated == true
            and type(record.deactivatedIdentityIds) == "table"
            and record.deactivatedIdentityIds[identityId] == true then
            record.nonHMDefeatedIdentityIds = record.nonHMDefeatedIdentityIds or {}
            if record.nonHMDefeatedIdentityIds[identityId] ~= true then
                record.nonHMDefeatedIdentityIds[identityId] = true
                changed = true
            end
            local matched = 0
            for _ in pairs(record.nonHMDefeatedIdentityIds) do
                matched = matched + 1
            end
            local encounter = Scoring:FindHardModeEncounterConfigByKey(
                self.run.zoneId, encounterKey)
            local required = tonumber(encounter and encounter.required)
            if not required then
                -- Base-game composite final encounters (Volenfell, CoH I)
                -- carry their cohort size on finalEncounter, not on the DLC
                -- hardModeEncounters table. Do not mark completion after the
                -- first of three Guardians or the first Ilambris twin dies.
                local final = Scoring:GetFinalEncounterConfig(self.run.zoneId)
                if final and final.mode == "composite"
                    and final.hmCreditKey == encounterKey then
                    required = tonumber(final.required)
                end
            end
            required = math.max(1, required or 1)
            if matched >= required and record.completedNonHM ~= true then
                record.completedNonHM = true
                changed = true
            end
        end
    end
    if changed then
        self:TouchActiveRunPersistence()
    end
    return changed
end

function DS:ClearBossHMHealthSignatureOnReset(boss)
    if not self.run or not boss then
        return false
    end
    local source = boss.hmEncounterResolutionSource
    if source ~= "zone-max-health" and source ~= "verified-encounter-cohort" then
        return false
    end

    local currentHealth = tonumber(boss.currentHealth)
    local maxHealth = tonumber(boss.maxHealth)
    if not currentHealth or not maxHealth or maxHealth <= 0
        or currentHealth < maxHealth
        or Scoring:GetKnownHMHealthEncounterKey(self.run.zoneId, maxHealth) ~= nil
        or not boss.unitTag then
        boss.hmNormalHealthResetCandidate = nil
        return false
    end

    -- ESO can briefly report a full ordinary-Veteran pool and a false combat
    -- state while an HM boss changes health during a live pull. One such frame
    -- is not a wipe. Require the same full non-HM pool to remain out of combat
    -- across multiple boss observations before invalidating the HM attempt.
    if IsUnitInCombat(boss.unitTag) then
        boss.hmNormalHealthResetCandidate = nil
        return false
    end
    local nowMs = GetGameTimeMilliseconds()
    local candidate = boss.hmNormalHealthResetCandidate
    if type(candidate) ~= "table" or candidate.maxHealth ~= maxHealth
        or nowMs < (tonumber(candidate.firstSeenAtMs) or nowMs) then
        boss.hmNormalHealthResetCandidate = {
            maxHealth = maxHealth,
            firstSeenAtMs = nowMs,
        }
        return false
    end
    if nowMs - (tonumber(candidate.firstSeenAtMs) or nowMs)
        < HM_NONHM_RESET_CONFIRM_MS then
        return false
    end
    boss.hmNormalHealthResetCandidate = nil

    -- Avoid expensive metadata work during ordinary combat-power updates.
    local finalEncounter = Scoring:GetFinalEncounterConfig(self.run.zoneId)
    if Scoring:RequiresAggregateFinalEncounterHM(self.run.zoneId)
        and finalEncounter and finalEncounter.mode == "identity-count" then
        return false
    end

    local identity, ledger = Evidence:GetIdentity(self.run, boss, false)
    if not identity then
        return false
    end
    local previousKey = boss.hmEncounterKey
    if type(previousKey) ~= "string" or previousKey == "" then
        return false
    end

    -- Older preview builds sometimes replaced a direct numeric source with an
    -- inferred cohort source. A retained exact signature on this *same* boss
    -- identity proves that it was directly classified; permit its reset after
    -- upgrade, but do not clear an exclusively inferred sibling on its own.
    if source == "verified-encounter-cohort" then
        local hadDirectSample = false
        for sampledMax in pairs(identity.maxHealthSamples or {}) do
            if Scoring:GetKnownHMHealthEncounterKey(self.run.zoneId, sampledMax)
                == previousKey then
                hadDirectSample = true
                break
            end
        end
        if not hadDirectSample then
            return false
        end
    end

    -- A direct, out-of-combat switch back to a non-HM pool is the evidence
    -- that this HM was *deactivated*. Mere tag churn or a wipe that preserves
    -- HM health cannot prove abandonment.
    self:RecordHealthHMDeactivation(previousKey, boss)

    -- Remove only the previous HM signature(s), keeping ordinary numeric boss
    -- samples and any unrelated encounter evidence intact. The reverse index
    -- must agree with the remaining attempt-local samples.
    for sampledMax in pairs(identity.maxHealthSamples or {}) do
        if Scoring:GetKnownHMHealthEncounterKey(self.run.zoneId, sampledMax) == previousKey then
            identity.maxHealthSamples[sampledMax] = nil
            local indexed = ledger.maxHealthIndex and ledger.maxHealthIndex[sampledMax]
            if type(indexed) == "table" then
                indexed[identity.identityId] = nil
                if next(indexed) == nil then
                    ledger.maxHealthIndex[sampledMax] = nil
                end
            end
        end
    end

    if identity.hmEncounterResolutionSource == "zone-max-health"
        or identity.hmEncounterResolutionSource == "verified-encounter-cohort" then
        identity.hmEncounterKey = nil
        identity.hmSignatureMaxHealth = nil
        identity.hmEncounterResolutionSource = nil
    end
    if type(identity.semanticBindings) == "table" then
        identity.semanticBindings["hm-encounter:" .. previousKey] = nil
    end
    -- A contradictory sample from an abandoned attempt cannot permanently
    -- prohibit a later clean pull from showing valid positive HM evidence.
    identity.hmHealthConflict = nil
    identity.hmHealthConflictAtMs = nil
    -- Prevent another member's still-cached HM sample from resurrecting this
    -- invalidated identity through encounter-wide cohort propagation. Only a
    -- fresh, direct positive numeric signature clears this disproof marker.
    identity.hmResetContradictedKey = previousKey
    identity.hmActive = false

    boss.hmEncounterKey = nil
    boss.hmSignatureMaxHealth = nil
    boss.hmEncounterResolutionSource = nil
    boss.hmEncounterIndex = nil
    boss.hmEncounterResolved = false
    boss.hmHealthEvidenceConflict = nil
    boss.hmActive = false
    boss.hmSource = nil

    -- Non-scoped single and composite HMs use only the boss identity latch.
    -- Scoped DLC encounters additionally retain hmMembers, hmObserved, and
    -- pending death/credit evidence independently of the boss identity. Reset
    -- that provisional attempt as a unit; credited encounters remain immutable.
    local encounter, encounterIndex = Scoring:FindHardModeEncounterConfigByKey(
        self.run.zoneId, previousKey)
    if encounter then
        self:ResetHardModeEncounterAttempt(encounter, encounterIndex)
    end
    return true
end

function DS:ResolveBossHMHealthEvidence(boss, observedAtMs)
    if not self.run or not boss then
        return nil, false
    end
    if not Scoring:IsHealthBasedHMAllowed(self.run.zoneId) then
        boss.healthHMAllowed = false
        return nil, false
    end

    local resetChanged = self:ClearBossHMHealthSignatureOnReset(boss)
    local identity = Evidence:GetIdentity(self.run, boss, false)
    if not identity then
        return nil, resetChanged
    end
    if identity.hmHealthConflict == true then
        boss.hmHealthEvidenceConflict = true
        boss.healthHMAllowed = false
        return nil, false
    end

    local resolvedKey = nil
    local resolvedMaxHealth = nil
    for maxHealth in pairs(identity.maxHealthSamples or {}) do
        local encounterKey = Scoring:GetKnownHMHealthEncounterKey(self.run.zoneId, maxHealth)
        if encounterKey then
            if resolvedKey and resolvedKey ~= encounterKey then
                identity.hmHealthConflict = true
                identity.hmHealthConflictAtMs = tonumber(observedAtMs) or 0
                boss.hmHealthEvidenceConflict = true
                boss.healthHMAllowed = false
                return nil, true
            end
            resolvedKey = encounterKey
            resolvedMaxHealth = tonumber(maxHealth)
        end
    end

    if not resolvedKey then
        return nil, resetChanged
    end
    if boss.hmEncounterKey and boss.hmEncounterKey ~= resolvedKey then
        identity.hmHealthConflict = true
        identity.hmHealthConflictAtMs = tonumber(observedAtMs) or 0
        boss.hmHealthEvidenceConflict = true
        boss.healthHMAllowed = false
        return nil, true
    end

    -- Record only a direct exact maximum-health signature, not an inferred
    -- cohort member. The ledger persists through wipe/reset without changing
    -- live Hard Mode credit or attempt re-arming.
    self:RecordHealthHMActivation(resolvedKey)

    -- Verified HM health observed again after a reset is affirmative evidence
    -- of a new activation for this identity; historic cohort inference is not.
    if identity.hmResetContradictedKey == resolvedKey then
        identity.hmResetContradictedKey = nil
    end

    local changed = boss.hmEncounterKey ~= resolvedKey
        or boss.hmSignatureMaxHealth ~= resolvedMaxHealth
    boss.hmEncounterKey = resolvedKey
    boss.hmSignatureMaxHealth = resolvedMaxHealth
    boss.hmEncounterResolutionSource = "zone-max-health"
    identity.hmEncounterKey = resolvedKey
    identity.hmSignatureMaxHealth = resolvedMaxHealth
    identity.hmEncounterResolutionSource = "zone-max-health"
    changed = Evidence:BindSemanticKey(
        self.run,
        boss,
        "hm-encounter:" .. resolvedKey,
        "zone-max-health",
        observedAtMs) or changed
    return resolvedKey, changed or resetChanged
end

function DS:ResolveBossHMActiveHealthPoolEvidence(boss, observedAtMs)
    if not self.run or not boss then
        return nil, false
    end
    if not Scoring:IsHealthBasedHMAllowed(self.run.zoneId) then
        boss.healthHMAllowed = false
        return nil, false
    end

    local identity = Evidence:GetIdentity(self.run, boss, false)
    if not identity then
        return nil, false
    end
    if identity.hmHealthConflict == true then
        boss.hmHealthEvidenceConflict = true
        boss.healthHMAllowed = false
        return nil, false
    end

    -- Active-pool evidence is a positive latch for this run-local identity. Once
    -- the verified HM pool has been seen, later damage (including health below
    -- the base pool and the terminal zero) must not erase the classification.
    local resolvedKey = nil
    if identity.hmEncounterResolutionSource == "zone-active-health-pool"
        and type(identity.hmEncounterKey) == "string"
        and identity.hmEncounterKey ~= "" then
        resolvedKey = identity.hmEncounterKey
    else
        resolvedKey = Scoring:GetKnownHMActiveHealthPoolEncounterKey(
            self.run.zoneId,
            boss.currentHealth,
            boss.maxHealth)
    end
    if not resolvedKey then
        return nil, false
    end
    if boss.hmEncounterKey and boss.hmEncounterKey ~= resolvedKey then
        identity.hmHealthConflict = true
        identity.hmHealthConflictAtMs = tonumber(observedAtMs) or 0
        boss.hmHealthEvidenceConflict = true
        boss.healthHMAllowed = false
        return nil, true
    end

    local changed = boss.hmEncounterKey ~= resolvedKey
        or boss.hmEncounterResolutionSource ~= "zone-active-health-pool"
    boss.hmEncounterKey = resolvedKey
    boss.hmActivePoolHealth = boss.hmActivePoolHealth
        or tonumber(boss.currentHealth)
    boss.hmEncounterResolutionSource = "zone-active-health-pool"
    identity.hmEncounterKey = resolvedKey
    identity.hmActivePoolHealth = identity.hmActivePoolHealth
        or tonumber(boss.currentHealth)
    identity.hmEncounterResolutionSource = "zone-active-health-pool"
    changed = Evidence:BindSemanticKey(
        self.run,
        boss,
        "hm-encounter:" .. resolvedKey,
        "zone-active-health-pool",
        observedAtMs) or changed
    return resolvedKey, changed
end

function DS:ClearBossHMActiveHealthPoolEvidenceOnReset(
    boss, previousHealth, currentHealth, maxHealth, bossInCombat)

    if not self.run or not boss
        or boss.hmEncounterResolutionSource ~= "zone-active-health-pool"
        or bossInCombat == true
        or not previousHealth or not currentHealth
        or tonumber(currentHealth) <= tonumber(previousHealth)
        or not Scoring:IsHMActiveHealthPoolResetValue(
            self.run.zoneId, currentHealth, maxHealth) then
        return false
    end

    local encounterKey = boss.hmEncounterKey
    local identity = Evidence:GetIdentity(self.run, boss, false)
    local identityId = tonumber(boss.identityId)
    local encounter, index = Scoring:FindHardModeEncounterConfigByKey(
        self.run.zoneId, encounterKey)
    local attempt = encounter and self:GetHardModeEncounterAttempt(encounter, index) or nil
    if attempt and identityId then
        attempt.hmMembers["identity:" .. tostring(identityId)] = nil
        attempt.hmObserved = next(attempt.hmMembers) ~= nil
    end

    boss.hmEncounterKey = nil
    boss.hmEncounterIndex = nil
    boss.hmEncounterResolved = false
    boss.hmEncounterResolutionSource = nil
    boss.hmActivePoolHealth = nil
    boss.hmActive = false
    boss.hmSource = nil
    if identity and identity.hmEncounterResolutionSource == "zone-active-health-pool" then
        identity.hmEncounterKey = nil
        identity.hmEncounterResolutionSource = nil
        identity.hmActivePoolHealth = nil
        if type(identity.semanticBindings) == "table" and encounterKey then
            identity.semanticBindings["hm-encounter:" .. tostring(encounterKey)] = nil
        end
    end
    return true
end

function DS:PropagateVerifiedHMEncounterCohort(boss, encounter, encounterKey, observedAtMs)
    if not self.run or not boss or not encounter or not encounterKey then
        return false
    end
    if math.max(1, tonumber(encounter.required) or 1) <= 1
        or Scoring:EncounterUsesConditionalHM(encounter) then
        return false
    end

    local required = math.max(1, tonumber(encounter.required) or 1)
    local activeEncounter = self.run.activeBossEncounter
    local activeIdentities = activeEncounter and activeEncounter.identities or nil
    local sourceIdentity, ledger = Evidence:GetIdentity(self.run, boss, false)
    local sourceIdentityId = tonumber(boss.identityId)
    if type(activeIdentities) ~= "table" or not sourceIdentity or not ledger
        or not sourceIdentityId or activeIdentities[sourceIdentityId] ~= true then
        return false
    end

    local cohort = {}
    local cohortCount = 0
    for identityKey, enabled in pairs(activeIdentities) do
        local identityId = tonumber(identityKey)
        local identity = identityId and ledger.identities[identityId] or nil
        local linked = identityId == sourceIdentityId
            or (sourceIdentity.coobservedIdentityIds
                and type(sourceIdentity.coobservedIdentityIds[identityId]) == "table")
        local engaged = identityId == sourceIdentityId
            or (identity and (identity.sawHealthLoss == true or identity.sawCombat == true))
        local predatesSource = identity and identity.deathState == true
            and tonumber(identity.deathStateChangedAtMs)
            and tonumber(sourceIdentity.firstObservedAtMs)
            and identity.deathStateChangedAtMs < sourceIdentity.firstObservedAtMs
        if enabled == true and identity and linked and engaged and not predatesSource
            and identity.hmResetContradictedKey ~= encounterKey then
            cohort[identityId] = identity
            cohortCount = cohortCount + 1
        end
    end

    -- An exact-sized co-observed cohort is required. Extra or missing identities
    -- are ambiguous and deliberately remain unbound rather than risking HM credit
    -- for a lingering boss tag or an incompletely observed composite encounter.
    if cohortCount ~= required then
        return false
    end

    for identityId, identity in pairs(cohort) do
        if identityId ~= sourceIdentityId and identity.hmEncounterKey
            and identity.hmEncounterKey ~= encounterKey then
            identity.hmHealthConflict = true
            identity.hmHealthConflictAtMs = tonumber(observedAtMs) or 0
            return false
        end
    end

    local changed = false
    local attempt = nil
    if Scoring:UsesTerminalCohortCompletion(encounter) then
        attempt = self:GetHardModeEncounterAttempt(encounter)
        if not attempt then
            return false
        end

        -- The exact verified cohort establishes HM identity for the encounter as
        -- a whole. Completion remains separate and still requires a direct death
        -- state from the terminal member selected by numeric lifecycle evidence.
        for identityId in pairs(cohort) do
            if attempt.cohortIdentityIds[identityId] ~= true then
                attempt.cohortIdentityIds[identityId] = true
                changed = true
            end
            local memberKey = "identity:" .. tostring(identityId)
            if attempt.hmMembers[memberKey] ~= true then
                attempt.hmMembers[memberKey] = true
                changed = true
            end
        end
        if not attempt.hmObserved then
            attempt.hmObserved = true
            changed = true
        end
        attempt.cohortBoundAtMs = attempt.cohortBoundAtMs
            or tonumber(observedAtMs) or 0
    end

    for identityId, identity in pairs(cohort) do
        if identityId ~= sourceIdentityId then
            local candidate = nil
            for _, activeBoss in pairs(self.run.activeBosses or {}) do
                if tonumber(activeBoss.identityId) == identityId then
                    candidate = activeBoss
                    break
                end
            end
            candidate = candidate or { identityId = identityId }
            -- Direct numeric evidence outranks indirect cohort inference. Do
            -- not replace a directly verified source with a derived one: wipe
            -- invalidation depends on knowing which source saw the HM max.
            local directBoss = candidate.hmEncounterResolutionSource == "zone-max-health"
                or candidate.hmEncounterResolutionSource == "zone-active-health-pool"
            local directIdentity = identity.hmEncounterResolutionSource == "zone-max-health"
                or identity.hmEncounterResolutionSource == "zone-active-health-pool"
            if not directBoss then
                candidate.hmEncounterKey = encounterKey
                candidate.hmEncounterResolutionSource = "verified-encounter-cohort"
                candidate.hmEncounterResolved = true
                candidate.hmActive = true
                candidate.hmSource = "encounter-cohort-known-health-signature"
            end
            if not directIdentity then
                identity.hmEncounterKey = encounterKey
                identity.hmEncounterResolutionSource = "verified-encounter-cohort"
            end
            identity.hmActive = true
            changed = Evidence:BindSemanticKey(
                self.run,
                candidate,
                "hm-encounter:" .. encounterKey,
                "verified-encounter-cohort",
                observedAtMs) or changed
        end
    end

    -- Replay only retained direct boss death-state evidence. This is what makes
    -- late encounter recognition safe when a composite member died first. Guard
    -- the replay because the direct signature-bearing member can itself be dead,
    -- and resolving that synthetic member re-enters this cohort resolver.
    local replayAttempt = attempt or self:GetHardModeEncounterAttempt(encounter)
    if replayAttempt and replayAttempt.cohortReplayInProgress ~= true then
        replayAttempt.cohortReplayInProgress = true
        for identityId, identity in pairs(cohort) do
            if identity.deathState == true then
                local candidate = {
                    identityId = identityId,
                    hmEncounterKey = encounterKey,
                    hmEncounterResolutionSource = identityId == sourceIdentityId
                        and "zone-max-health" or "verified-encounter-cohort",
                    hmActive = true,
                    hmSource = "encounter-cohort-known-health-signature",
                }
                self:RecordHardModeEncounterIdentityDeath(
                    candidate,
                    "boss-death-state",
                    identity.deathStateChangedAtMs or observedAtMs)
            end
        end
        replayAttempt.cohortReplayInProgress = nil
    end

    if changed then
        self:TouchActiveRunPersistence()
    end
    return changed
end

function DS:ResolveBossHardModeMetadata(boss)
    if not self.run or not boss then
        return nil, nil
    end

    local stableKey = boss.hmEncounterKey
    if stableKey and Scoring:IsVerifiedHMEncounterResolutionSource(
        boss.hmEncounterResolutionSource) then
        local encounter, index = Scoring:FindHardModeEncounterConfigByKey(
            self.run.zoneId,
            stableKey)
        if encounter then
            boss.hmEncounterIndex = index
            boss.hmEncounterResolved = true
            boss.healthHMAllowed = Scoring:IsHealthBasedHMAllowed(self.run.zoneId)
                and not Scoring:EncounterUsesConditionalHM(encounter)
                and boss.hmHealthEvidenceConflict ~= true
            if boss.hmEncounterResolutionSource == "zone-max-health"
                or boss.hmEncounterResolutionSource == "zone-active-health-pool" then
                self:PropagateVerifiedHMEncounterCohort(
                    boss,
                    encounter,
                    stableKey,
                    GetGameTimeMilliseconds())
            end
            return encounter, index
        end
        -- Non-scoped dungeons still use the verified key for duplicate-safe HM
        -- credit even though there is no scoped encounter configuration to return.
        boss.hmEncounterResolved = false
        boss.healthHMAllowed = Scoring:IsHealthBasedHMAllowed(self.run.zoneId)
            and boss.hmHealthEvidenceConflict ~= true
        return nil, nil
    end

    -- A stable scoped encounter key may only come from retained numeric health
    -- evidence. Older development runs could persist a key selected by localized
    -- display name; clear that tainted binding rather than reusing it.
    if stableKey and not Scoring:IsVerifiedHMEncounterResolutionSource(
        boss.hmEncounterResolutionSource) then
        boss.hmEncounterKey = nil
        boss.hmEncounterIndex = nil
    end
    boss.hmEncounterResolved = false
    boss.hmEncounterResolutionSource = nil
    boss.healthHMAllowed = Scoring:IsHealthBasedHMAllowed(self.run.zoneId)
        and boss.hmHealthEvidenceConflict ~= true
    return nil, nil
end

function DS:GetHardModeEncounterAttempt(encounter, index)
    if not self.run or not encounter then
        return nil, nil
    end

    self.run.hardModeEncounterAttempts = self.run.hardModeEncounterAttempts or {}
    self.run.hmCreditedBossNames = self.run.hmCreditedBossNames or {}
    local encounterKey = Scoring:GetHardModeEncounterKey(encounter, index)
    local attempt = self.run.hardModeEncounterAttempts[encounterKey]
    if type(attempt) ~= "table" then
        attempt = {
            id = 1,
            deaths = {},
            identityDeaths = {},
            cohortIdentityIds = {},
            terminalDeathSatisfied = false,
            terminalAbilityEmitters = {},
            terminalAbilityActorDeaths = {},
            hmObserved = false,
            hmMembers = {},
            credited = false,
            conditionArmed = false,
            conditionFailed = false,
            conditionCount = 0,
            conditionDeaths = {},
            conditionAliveEntities = {},
            conditionDeadEntities = {},
            conditionEncounterAbilityIds = {},
            conditionHardModeAbilityIds = {},
            conditionAbilityEmitters = {},
            conditionTerminalEntities = {},
            conditionTerminalCandidates = {},
            conditionSatisfied = false,
            conditionOpen = false,
            conditionClosed = false,
            conditionSnapshotTaken = false,
            conditionContinuityBroken = false,
            conditionObserverVerified = false,
            conditionEngaged = false,
        }
        self.run.hardModeEncounterAttempts[encounterKey] = attempt
    end

    attempt.deaths = attempt.deaths or {}
    attempt.identityDeaths = attempt.identityDeaths or {}
    attempt.cohortIdentityIds = attempt.cohortIdentityIds or {}
    attempt.terminalDeathSatisfied = attempt.terminalDeathSatisfied == true
    attempt.terminalAbilityEmitters = attempt.terminalAbilityEmitters or {}
    attempt.terminalAbilityActorDeaths = attempt.terminalAbilityActorDeaths or {}
    attempt.hmMembers = attempt.hmMembers or {}
    attempt.hmObserved = attempt.hmObserved == true
    attempt.conditionArmed = attempt.conditionArmed == true
    attempt.conditionFailed = attempt.conditionFailed == true
    attempt.conditionCount = tonumber(attempt.conditionCount) or 0
    attempt.conditionDeaths = attempt.conditionDeaths or {}
    attempt.conditionAliveEntities = attempt.conditionAliveEntities or {}
    attempt.conditionDeadEntities = attempt.conditionDeadEntities or {}
    attempt.conditionEncounterAbilityIds = attempt.conditionEncounterAbilityIds or {}
    attempt.conditionHardModeAbilityIds = attempt.conditionHardModeAbilityIds or {}
    attempt.conditionAbilityEmitters = attempt.conditionAbilityEmitters or {}
    attempt.conditionTerminalEntities = attempt.conditionTerminalEntities or {}
    attempt.conditionTerminalCandidates = attempt.conditionTerminalCandidates or {}
    attempt.conditionPositiveEvidence = attempt.conditionPositiveEvidence == true
    attempt.conditionSnapshotPositiveEvidence =
        attempt.conditionSnapshotPositiveEvidence == true
    attempt.conditionSatisfied = attempt.conditionSatisfied == true
    attempt.conditionOpen = attempt.conditionOpen == true
    attempt.conditionClosed = attempt.conditionClosed == true
    attempt.conditionSnapshotTaken = attempt.conditionSnapshotTaken == true
    attempt.conditionContinuityBroken = attempt.conditionContinuityBroken == true
    attempt.conditionObserverVerified = attempt.conditionObserverVerified == true
    attempt.conditionEngaged = attempt.conditionEngaged == true
    attempt.credited = attempt.credited == true
        or self.run.hmCreditedBossNames["encounter:" .. encounterKey] == true
    attempt.authoritativeCompletion = attempt.authoritativeCompletion == true
    attempt.cumulativeCompletion = attempt.cumulativeCompletion == true
    return attempt, encounterKey
end

function DS:UpdateHardModeEncounterCohortPresence(observedAtMs)
    if not self.run or not Scoring:UsesEncounterScopedHM(self.run.zoneId) then
        return false
    end

    local activeEncounter = self.run.activeBossEncounter
    if not activeEncounter or activeEncounter.engaged ~= true then
        return false
    end

    observedAtMs = tonumber(observedAtMs) or GetGameTimeMilliseconds()
    local changed = false
    for index, encounter in ipairs(Scoring:GetHardModeEncounterConfigs(self.run.zoneId) or {}) do
        if Scoring:UsesTerminalCohortCompletion(encounter) then
            local attempt = self:GetHardModeEncounterAttempt(encounter, index)
            local required = math.max(1, tonumber(encounter.required) or 1)
            local boundCount = 0
            for _, enabled in pairs(attempt.cohortIdentityIds or {}) do
                if enabled == true then
                    boundCount = boundCount + 1
                end
            end

            if not attempt.credited and not attempt.terminalDeathSatisfied
                and not attempt.terminalIdentityId and boundCount == required
                and type(encounter.terminalAbilityEvidence) ~= "table" then
                local liveCount = 0
                local soleIdentityId = nil
                for _, boss in pairs(self.run.activeBosses or {}) do
                    local identityId = tonumber(boss.identityId)
                    if identityId and attempt.cohortIdentityIds[identityId] == true
                        and boss.deathStateObserved ~= true
                        and (tonumber(boss.currentHealth) or 0) > 0 then
                        liveCount = liveCount + 1
                        soleIdentityId = identityId
                    end
                end

                if liveCount == 1 then
                    if attempt.terminalCandidateIdentityId ~= soleIdentityId then
                        attempt.terminalCandidateIdentityId = soleIdentityId
                        attempt.terminalCandidateSinceMs = observedAtMs
                        changed = true
                    elseif observedAtMs - (tonumber(attempt.terminalCandidateSinceMs) or observedAtMs)
                        >= self.COMPLETION_GRACE_MS then
                        attempt.terminalIdentityId = soleIdentityId
                        attempt.terminalIdentitySource = "stable-cohort-survivor"
                        attempt.terminalIdentityObservedAtMs = observedAtMs
                        attempt.terminalCandidateIdentityId = nil
                        attempt.terminalCandidateSinceMs = nil
                        changed = true
                    end
                elseif attempt.terminalCandidateIdentityId ~= nil
                    or attempt.terminalCandidateSinceMs ~= nil then
                    attempt.terminalCandidateIdentityId = nil
                    attempt.terminalCandidateSinceMs = nil
                    changed = true
                end
            end
        end
    end

    if changed then
        self:TouchActiveRunPersistence()
    end
    return changed
end

function DS:ApplyCumulativeHardModeEvidence(successorIndex, successorKey, observedAtMs)
    if not self.run then
        return false
    end

    local encounters = Scoring:GetHardModeEncounterConfigs(self.run.zoneId)
    successorIndex = tonumber(successorIndex)
    if not Scoring:UsesCumulativeHardModeProgression(self.run.zoneId)
        or type(encounters) ~= "table" or not successorIndex
        or successorIndex <= 1 then
        return false
    end

    successorKey = tostring(successorKey or successorIndex)
    observedAtMs = tonumber(observedAtMs) or GetGameTimeMilliseconds()
    local changed = false
    for priorIndex = 1, successorIndex - 1 do
        local priorEncounter = encounters[priorIndex]
        local priorAttempt, priorKey = self:GetHardModeEncounterAttempt(
            priorEncounter,
            priorIndex)
        if priorAttempt and not priorAttempt.credited then
            local memberKey = "cumulative-successor:" .. successorKey
            if priorAttempt.hmMembers[memberKey] ~= true then
                priorAttempt.hmMembers[memberKey] = true
                changed = true
            end
            if priorAttempt.hmObserved ~= true then
                priorAttempt.hmObserved = true
                changed = true
            end
            if priorAttempt.cumulativeCompletion ~= true then
                priorAttempt.cumulativeCompletion = true
                priorAttempt.cumulativeCompletionSource = "verified-successor-hm"
                priorAttempt.cumulativeSuccessorKey = successorKey
                priorAttempt.cumulativeObservedAtMs = observedAtMs
                changed = true
            end
            if self:CommitHardModeEncounterCredit(
                priorEncounter,
                priorAttempt,
                priorKey) then
                changed = true
            end
        end
    end

    if changed then
        self:TouchActiveRunPersistence()
    end
    return changed
end

function DS:SetHardModeEncounterMemberHM(boss, hmActive, encounter, index)
    if not self.run or not boss then
        return false
    end

    if not encounter then
        encounter, index = self:ResolveBossHardModeMetadata(boss)
    end
    if not encounter then
        return false
    end

    local attempt, encounterKey = self:GetHardModeEncounterAttempt(encounter, index)
    local identityId = tonumber(boss.identityId)
    local memberKey = identityId and identityId > 0
        and "identity:" .. tostring(identityId)
        or (boss.hmEncounterKey and "hm-encounter:" .. tostring(boss.hmEncounterKey))
    if not attempt or not memberKey then
        return false
    end

    -- Outcome-conditional HMs are never inferred from boss max-health state.
    if Scoring:EncounterUsesConditionalHM(encounter) then
        return false
    end

    local oldObserved = attempt.hmObserved == true
    local oldMember = attempt.hmMembers[memberKey] == true
    if hmActive then
        attempt.hmMembers[memberKey] = true
    else
        attempt.hmMembers[memberKey] = nil
    end
    attempt.hmObserved = next(attempt.hmMembers) ~= nil

    if oldObserved ~= attempt.hmObserved
        or oldMember ~= (attempt.hmMembers[memberKey] == true) then
        self:TouchActiveRunPersistence()
    end

    if hmActive and (boss.hmEncounterResolutionSource == "zone-max-health"
        or boss.hmEncounterResolutionSource == "zone-active-health-pool") then
        self:ApplyCumulativeHardModeEvidence(
            index,
            encounterKey,
            GetGameTimeMilliseconds())
    end

    return true
end

function DS:ResetHardModeEncounterAttempt(encounter, index)
    if not self.run or not encounter then
        return false
    end

    local attempt, encounterKey = self:GetHardModeEncounterAttempt(encounter, index)
    if not attempt or attempt.credited then
        return false
    end

    local previousId = attempt.id or 1
    if encounter.criterion
        and encounter.criterion.type == "minimum-emitter-deaths" then
        local encounterKeyValue = Scoring:GetHardModeEncounterKey(encounter, index)
        local ledger = Evidence:EnsureLedger(self.run)
        for _, boss in pairs(self.run.activeBosses or {}) do
            if boss.hmEncounterKey == encounterKeyValue
                and boss.hmEncounterResolutionSource == "verified-ability-cohort" then
                boss.hmEncounterKey = nil
                boss.hmEncounterIndex = nil
                boss.hmEncounterResolved = false
                boss.hmEncounterResolutionSource = nil
            end
        end
        for _, identity in pairs(ledger and ledger.identities or {}) do
            if identity.hmEncounterKey == encounterKeyValue
                and identity.hmEncounterResolutionSource == "verified-ability-cohort" then
                identity.hmEncounterKey = nil
                identity.hmEncounterResolutionSource = nil
                if type(identity.semanticBindings) == "table" then
                    identity.semanticBindings["hm-encounter:" .. encounterKeyValue] = nil
                end
            end
        end
    end
    self.run.hardModeEncounterAttempts[encounterKey] = {
        id = previousId + 1,
        deaths = {},
        identityDeaths = {},
        cohortIdentityIds = {},
        terminalDeathSatisfied = false,
        terminalAbilityEmitters = {},
        terminalAbilityActorDeaths = {},
        authoritativeCompletion = false,
        hmObserved = false,
        hmMembers = {},
        credited = false,
        conditionArmed = false,
        conditionFailed = false,
        conditionCount = 0,
        conditionDeaths = {},
        conditionAliveEntities = {},
        conditionDeadEntities = {},
        conditionEncounterAbilityIds = {},
        conditionHardModeAbilityIds = {},
        conditionAbilityEmitters = {},
        conditionTerminalEntities = {},
        conditionTerminalCandidates = {},
        conditionSatisfied = false,
        conditionOpen = false,
        conditionClosed = false,
        conditionSnapshotTaken = false,
        conditionContinuityBroken = false,
        conditionObserverVerified = false,
        conditionEngaged = false,
    }

    self:RefreshConditionalRuntimeObservers()
    self:TouchActiveRunPersistence()
    return true
end

function DS:GetConditionalHMResolver(encounter)
    if not Scoring:IsConditionalHMAutomaticScoringEnabled(encounter) then
        return nil
    end
    return ConditionalHMResolvers[encounter.criterion.type]
end

function DS:TryBindConditionalAbilityEncounterCohort(encounter, index, attempt, observedAtMs)
    if not self.run or not encounter or not attempt or attempt.conditionArmed
        or not Scoring:IsConditionalHMAutomaticScoringEnabled(encounter) then
        return false
    end

    local criterion = encounter.criterion or {}
    if criterion.type ~= "minimum-emitter-deaths" then
        return false
    end

    local observedAbilityCount = 0
    for abilityId, enabled in pairs(attempt.conditionEncounterAbilityIds or {}) do
        if enabled == true and self:IsConditionalAbilityIdMatch(
            abilityId, criterion.encounterAbilityIds) then
            observedAbilityCount = observedAbilityCount + 1
        end
    end
    local requiredAbilityCount = math.max(
        1, tonumber(criterion.requiredEncounterAbilityIds) or 1)
    if observedAbilityCount < requiredAbilityCount then
        return false
    end

    local activeEncounter = self.run.activeBossEncounter
    local activeIdentities = activeEncounter and activeEncounter.identities or nil
    if type(activeIdentities) ~= "table" then
        return false
    end

    local requiredMembers = math.max(1, tonumber(encounter.required) or 1)
    local cohort = {}
    local cohortCount = 0
    local ledger = Evidence:EnsureLedger(self.run)
    for identityKey, enabled in pairs(activeIdentities) do
        local identityId = tonumber(identityKey)
        local identity = identityId and ledger and ledger.identities[identityId] or nil
        if enabled == true and identityId and identity then
            cohort[identityId] = identity
            cohortCount = cohortCount + 1
        end
    end
    if cohortCount ~= requiredMembers then
        return false
    end

    local encounterKey = Scoring:GetHardModeEncounterKey(encounter, index)
    for _, identity in pairs(cohort) do
        if identity.hmEncounterKey and identity.hmEncounterKey ~= encounterKey then
            attempt.conditionFailed = true
            attempt.conditionFailureReason = "ability-cohort-binding-conflict"
            self:TouchActiveRunPersistence()
            return false
        end
    end

    observedAtMs = tonumber(observedAtMs) or GetGameTimeMilliseconds()
    attempt.conditionArmed = true
    attempt.conditionArmedAtMs = observedAtMs
    attempt.conditionEngaged = true
    attempt.conditionEngagedAtMs = observedAtMs
    attempt.conditionWindowStartAtMs = tonumber(activeEncounter.firstSeenAtMs)
        or tonumber(attempt.conditionCaptureStartedAtMs)
        or observedAtMs
    attempt.conditionFailed = false
    attempt.conditionContinuityBroken = false
    attempt.conditionOpen = true
    attempt.cohortBoundAtMs = observedAtMs

    local changed = true
    for identityId, identity in pairs(cohort) do
        attempt.cohortIdentityIds[identityId] = true
        local candidate = nil
        for _, boss in pairs(self.run.activeBosses or {}) do
            if tonumber(boss.identityId) == identityId then
                candidate = boss
                break
            end
        end
        if not candidate then
            for _, boss in pairs(self.run.seenBossNames or {}) do
                if tonumber(boss.identityId) == identityId then
                    candidate = boss
                    break
                end
            end
        end
        candidate = candidate or { identityId = identityId }
        candidate.hmEncounterKey = encounterKey
        candidate.hmEncounterIndex = index
        candidate.hmEncounterResolved = true
        candidate.hmEncounterResolutionSource = "verified-ability-cohort"
        candidate.healthHMAllowed = false
        identity.hmEncounterKey = encounterKey
        identity.hmEncounterResolutionSource = "verified-ability-cohort"
        Evidence:BindSemanticKey(
            self.run,
            candidate,
            "hm-encounter:" .. encounterKey,
            "verified-ability-cohort",
            observedAtMs)
    end

    local resolver = self:GetConditionalHMResolver(encounter)
    if resolver and resolver.onEncounterBound then
        resolver.onEncounterBound(self, encounter, attempt, encounterKey, observedAtMs)
    end

    -- Numeric ability recognition can occur after the pull or after one member's
    -- death. Replay only retained direct boss-tag death state for this exact
    -- two-member cohort; localized combat-death names never participate.
    for identityId, identity in pairs(cohort) do
        if identity.deathState == true then
            self:RecordHardModeEncounterIdentityDeath({
                identityId = identityId,
                hmEncounterKey = encounterKey,
                hmEncounterResolutionSource = "verified-ability-cohort",
                hmActive = false,
            }, "boss-death-state", identity.deathStateChangedAtMs or observedAtMs)
        end
    end

    self:TouchActiveRunPersistence()
    return changed
end

function DS:TryBindPendingConditionalAbilityCohorts(observedAtMs)
    if not self.run or not Scoring:UsesEncounterScopedHM(self.run.zoneId) then
        return false
    end

    local changed = false
    for index, encounter in ipairs(Scoring:GetHardModeEncounterConfigs(self.run.zoneId) or {}) do
        if encounter.criterion
            and encounter.criterion.type == "minimum-emitter-deaths" then
            local attempt = self:GetHardModeEncounterAttempt(encounter, index)
            if attempt and self:TryBindConditionalAbilityEncounterCohort(
                encounter, index, attempt, observedAtMs) then
                changed = true
            end
        end
    end
    return changed
end

function DS:MaybeArmConditionalHardModeEncounter(boss, bossInCombat)
    if not self.run or not boss then
        return false
    end

    local encounter, index = self:ResolveBossHardModeMetadata(boss)
    local resolver = self:GetConditionalHMResolver(encounter)
    if not resolver then
        return false
    end

    local attempt, encounterKey = self:GetHardModeEncounterAttempt(encounter, index)
    if not attempt or attempt.credited then
        return false
    end

    local currentHealth = boss.currentHealth or 0
    local maxHealth = boss.maxHealth or 0
    if bossInCombat == nil and boss.unitTag then
        bossInCombat = IsUnitInCombat(boss.unitTag)
    end

    -- Once armed, preserve encounter engagement as a latch. ESO boss combat flags
    -- and unit tags can churn during phases; losing a transient live flag must not
    -- create a blind spot for a condition that is already underway.
    if attempt.conditionArmed then
        if not attempt.conditionEngaged
            and (bossInCombat or HasHealthLoss(currentHealth, maxHealth) or boss.hasTakenDamage) then
            self:MarkConditionalHardModeEncounterEngaged(attempt)
        end
        return false
    end

    if resolver.requiresCleanPrepull ~= false
        and (bossInCombat or maxHealth <= 0 or currentHealth < maxHealth or boss.hasTakenDamage) then
        return false
    end

    attempt.conditionArmed = true
    attempt.conditionFailed = false
    attempt.conditionCount = 0
    attempt.conditionDeaths = {}
    attempt.conditionAliveEntities = {}
    attempt.conditionDeadEntities = {}
    attempt.conditionSatisfied = false
    attempt.conditionOpen = false
    attempt.conditionClosed = false
    attempt.conditionSnapshotTaken = false
    attempt.conditionSnapshotCount = nil
    attempt.conditionSnapshotAtMs = nil
    attempt.conditionContinuityBroken = false
    attempt.conditionEngaged = false
    local effectIds = encounter.criterion and encounter.criterion.effectAbilityIds
    attempt.conditionObserverVerified = resolver.effectObserver == true
        and type(effectIds) == "table" and next(effectIds) ~= nil
        or false
    attempt.conditionArmedAtMs = GetGameTimeMilliseconds()

    self:TouchActiveRunPersistence()
    self:RefreshConditionalRuntimeObservers()
    return true
end

function DS:IsHardModeEncounterCurrentlyInCombat(encounter)
    if not self.run or not encounter then
        return false
    end

    local encounters = Scoring:GetHardModeEncounterConfigs(self.run.zoneId) or {}
    for unitTag, boss in pairs(self.run.activeBosses or {}) do
        local configured = boss.hmEncounterIndex and encounters[boss.hmEncounterIndex] or nil
        if configured == encounter and IsUnitInCombat(unitTag) then
            return true
        end
    end
    return false
end

function DS:MarkConditionalHardModeEncounterEngaged(attempt)
    if not attempt or attempt.conditionEngaged then
        return attempt and attempt.conditionEngaged == true or false
    end
    attempt.conditionEngaged = true
    attempt.conditionEngagedAtMs = GetGameTimeMilliseconds()
    self:TouchActiveRunPersistence()
    return true
end

function DS:IsConditionalHardModeEncounterEngaged(encounter, attempt)
    if not attempt then
        return false
    end
    if attempt.conditionEngaged then
        return true
    end
    if self:IsHardModeEncounterCurrentlyInCombat(encounter) then
        self:MarkConditionalHardModeEncounterEngaged(attempt)
        return true
    end
    return false
end

function DS:IsHardModeEncounterQualified(encounter, attempt)
    if Scoring:EncounterUsesConditionalHM(encounter) then
        if not Scoring:IsConditionalHMAutomaticScoringEnabled(encounter) then
            return false
        end
        local resolver = self:GetConditionalHMResolver(encounter)
        return resolver ~= nil and resolver.isSatisfied ~= nil
            and resolver.isSatisfied(self, encounter, attempt) == true
    end
    if not attempt or attempt.hmObserved ~= true then
        return false
    end
    if encounter.requireHMIdentityDeath == true then
        local requiredLatestIdentityId = encounter.requireLatestBossDeathIdentity == true
            and tonumber(self.run and self.run.lastBossDeathIdentityId) or nil
        for identityKey, evidence in pairs(attempt.identityDeaths or {}) do
            local identityId = type(evidence) == "table"
                and tonumber(evidence.identityId) or tonumber(identityKey)
            if identityId
                and (not encounter.requireLatestBossDeathIdentity
                    or identityId == requiredLatestIdentityId)
                and attempt.hmMembers["identity:" .. tostring(identityId)] == true then
                return true
            end
        end
        return false
    end
    return true
end

function DS:IsConditionalAbilityIdMatch(abilityId, configuredIds)
    abilityId = tonumber(abilityId) or 0
    return abilityId > 0 and type(configuredIds) == "table" and configuredIds[abilityId] == true
end

function DS:IsConditionalAbilityMatch(abilityId, abilityName, configuredIds, exactNames, containsNames)
    if self:IsConditionalAbilityIdMatch(abilityId, configuredIds) then
        return true
    end
    return Scoring:ConditionalTextMatches(abilityName, exactNames, containsNames)
end

function DS:ObserveTerminalAbilityEmission(abilityId, sourceUnitId, sourceType, observedAtMs)
    if not self.run or self.run.finalized or IsPlayerSideCombatUnitType(sourceType) then
        return false
    end

    abilityId = tonumber(abilityId) or 0
    sourceUnitId = tonumber(sourceUnitId) or 0
    if abilityId <= 0 or sourceUnitId <= 0 then
        return false
    end

    local observers = self.activeTerminalAbilityObserversById
        and self.activeTerminalAbilityObserversById[abilityId]
    if type(observers) ~= "table" then
        return false
    end

    observedAtMs = tonumber(observedAtMs) or GetGameTimeMilliseconds()
    local changed = false
    for _, observer in ipairs(observers) do
        local attempt = observer.attempt
        local evidence = observer.evidence
        if attempt and evidence and not attempt.credited and not attempt.terminalDeathSatisfied then
            attempt.terminalAbilityEmitters = attempt.terminalAbilityEmitters or {}
            local emitter = attempt.terminalAbilityEmitters[sourceUnitId]
            if type(emitter) ~= "table" then
                emitter = {
                    sourceUnitId = sourceUnitId,
                    abilityIds = {},
                    distinctAbilityCount = 0,
                    firstObservedAtMs = observedAtMs,
                }
                attempt.terminalAbilityEmitters[sourceUnitId] = emitter
                changed = true
            end

            emitter.abilityIds = emitter.abilityIds or {}
            if emitter.abilityIds[abilityId] ~= true then
                emitter.abilityIds[abilityId] = true
                emitter.distinctAbilityCount = (tonumber(emitter.distinctAbilityCount) or 0) + 1
                changed = true
            end
            emitter.lastObservedAtMs = observedAtMs

            local requiredDistinct = math.max(1, tonumber(evidence.requiredDistinct) or 1)
            if not emitter.confirmed
                and (tonumber(emitter.distinctAbilityCount) or 0) >= requiredDistinct then
                emitter.confirmed = true
                emitter.confirmedAtMs = observedAtMs
                attempt.terminalAbilityEmitterConfirmed = true
                attempt.terminalAbilityEmitterConfirmedAtMs = observedAtMs
                changed = true
            end
        end
    end

    if changed then
        self:TouchActiveRunPersistence()
    end
    return changed
end

function DS:TryResolveTerminalAbilityDeath(encounter, attempt, observedAtMs)
    local evidence = encounter and encounter.terminalAbilityEvidence
    if type(evidence) ~= "table" or not attempt or attempt.terminalDeathSatisfied then
        return false
    end

    local required = math.max(1, tonumber(encounter.required) or 1)
    local boundCount = 0
    for _, enabled in pairs(attempt.cohortIdentityIds or {}) do
        if enabled == true then
            boundCount = boundCount + 1
        end
    end
    if boundCount ~= required then
        return false
    end

    local joinWindowMs = math.max(0, tonumber(self.TERMINAL_ABILITY_DEATH_JOIN_MS) or 0)
    local candidates = {}
    for _, actorDeath in pairs(attempt.terminalAbilityActorDeaths or {}) do
        local actorDeathAtMs = type(actorDeath) == "table"
            and tonumber(actorDeath.firstObservedAtMs) or nil
        if actorDeathAtMs then
            for identityKey, identityDeath in pairs(attempt.identityDeaths or {}) do
                local identityId = type(identityDeath) == "table"
                    and tonumber(identityDeath.identityId) or tonumber(identityKey)
                local identityDeathAtMs = type(identityDeath) == "table"
                    and tonumber(identityDeath.firstObservedAtMs) or nil
                local hasDirectDeath = type(identityDeath) == "table"
                    and type(identityDeath.sources) == "table"
                    and identityDeath.sources["boss-death-state"] == true
                if identityId and identityDeathAtMs and hasDirectDeath
                    and attempt.cohortIdentityIds[identityId] == true
                    and math.abs(identityDeathAtMs - actorDeathAtMs) <= joinWindowMs then
                    candidates[identityId] = {
                        identityId = identityId,
                        actorDeathAtMs = actorDeathAtMs,
                        identityDeathAtMs = identityDeathAtMs,
                        sourceUnitId = tonumber(actorDeath.sourceUnitId),
                    }
                end
            end
        end
    end

    local candidateCount = 0
    local candidate = nil
    for _, value in pairs(candidates) do
        candidateCount = candidateCount + 1
        candidate = value
    end
    if candidateCount ~= 1 then
        if candidateCount > 1 then
            attempt.terminalAbilityDeathAmbiguous = true
            attempt.terminalAbilityDeathAmbiguousAtMs = tonumber(observedAtMs)
                or GetGameTimeMilliseconds()
        end
        return false
    end

    local resolvedAtMs = tonumber(observedAtMs) or GetGameTimeMilliseconds()
    attempt.terminalIdentityId = candidate.identityId
    attempt.terminalIdentitySource = "ability-emitter-death-join"
    attempt.terminalIdentityObservedAtMs = resolvedAtMs
    attempt.terminalDeathSatisfied = true
    attempt.terminalDeathIdentityId = candidate.identityId
    attempt.terminalDeathObservedAtMs = candidate.identityDeathAtMs
    attempt.terminalDeathSource = "boss-death-state+ability-emitter-death"
    attempt.terminalAbilityMatchedUnitId = candidate.sourceUnitId
    attempt.terminalAbilityDeathAmbiguous = false
    attempt.terminalAbilityDeathAmbiguousAtMs = nil
    if not attempt.pendingCreditAtMs and self:IsHardModeEncounterQualified(encounter, attempt) then
        attempt.pendingCreditAtMs = candidate.identityDeathAtMs
    end
    return true
end

function DS:ObserveTerminalAbilityActorDeath(targetUnitId, observedAtMs)
    if not self.run or self.run.finalized then
        return false
    end

    targetUnitId = tonumber(targetUnitId) or 0
    if targetUnitId <= 0 then
        return false
    end

    observedAtMs = tonumber(observedAtMs) or GetGameTimeMilliseconds()
    local changed = false
    for index, encounter in ipairs(Scoring:GetHardModeEncounterConfigs(self.run.zoneId) or {}) do
        if type(encounter.terminalAbilityEvidence) == "table" then
            local attempt = self:GetHardModeEncounterAttempt(encounter, index)
            local emitter = attempt and attempt.terminalAbilityEmitters
                and attempt.terminalAbilityEmitters[targetUnitId]
            if attempt and not attempt.credited and not attempt.terminalDeathSatisfied
                and type(emitter) == "table" and emitter.confirmed == true then
                attempt.terminalAbilityActorDeaths = attempt.terminalAbilityActorDeaths or {}
                local actorDeath = attempt.terminalAbilityActorDeaths[targetUnitId]
                if type(actorDeath) ~= "table" then
                    actorDeath = {
                        sourceUnitId = targetUnitId,
                        firstObservedAtMs = observedAtMs,
                    }
                    attempt.terminalAbilityActorDeaths[targetUnitId] = actorDeath
                    changed = true
                end
                actorDeath.lastObservedAtMs = observedAtMs
                if self:TryResolveTerminalAbilityDeath(encounter, attempt, observedAtMs) then
                    changed = true
                end
            end
        end
    end

    if changed then
        self:RefreshConditionalRuntimeObservers()
        self:TouchActiveRunPersistence()
    end
    return changed
end

function DS:OnConditionalCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
    sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log,
    sourceUnitId, targetUnitId, abilityId, overflow)

    if not self.run or self.run.finalized or not self:IsArmed() then
        return
    end

    local eventTimeMs = GetGameTimeMilliseconds()
    local routeChanged = self.ObserveRouteAbilityEmission
        and not IsPlayerSideCombatUnitType(sourceType)
        and self:ObserveRouteAbilityEmission(
            abilityId, sourceUnitId, eventTimeMs, result,
            targetUnitId, hitValue, overflow) or false
    if routeChanged and not self.run.startedAtMs then
        self:EnsureRunStarted("route-ability-emission")
    end
    local terminalChanged = self:ObserveTerminalAbilityEmission(
        abilityId, sourceUnitId, sourceType, eventTimeMs)
    if terminalChanged and not self.run.startedAtMs then
        self:EnsureRunStarted("terminal-ability-emission")
    end
    if routeChanged or terminalChanged then
        self:RefreshConditionalRuntimeObservers()
    end
end

function DS:RefreshConditionalRuntimeObservers()
    -- Conditional HM criteria have been replaced by alternate speed scoring.
    -- Only exact numeric route-boss and terminal-cohort evidence is observed.
    local exactCombatAbilityIds = {}
    local terminalAbilityObserversById = {}

    local function AddConfiguredAbilityIds(configured)
        if type(configured) ~= "table" then
            return
        end
        for abilityId, enabled in pairs(configured) do
            abilityId = tonumber(abilityId)
            if enabled and abilityId and abilityId > 0 then
                exactCombatAbilityIds[abilityId] = true
            end
        end
    end

    if self.run and not self.run.finalized and self.run.eligible then
        local routeAbilityEncounters = Scoring.GetRouteAbilityEncounterConfigs
            and Scoring:GetRouteAbilityEncounterConfigs(self.run.zoneId) or nil
        for _, encounter in ipairs(routeAbilityEncounters or {}) do
            local state = self.run.routeAbilityEvidence
                and self.run.routeAbilityEvidence[encounter.key]
            if not (type(state) == "table" and state.confirmed == true) then
                AddConfiguredAbilityIds(encounter.abilityIds)
            end
        end

        for index, encounter in ipairs(Scoring:GetHardModeEncounterConfigs(self.run.zoneId) or {}) do
            local evidence = encounter.terminalAbilityEvidence
            if Scoring:UsesTerminalCohortCompletion(encounter)
                and type(evidence) == "table" and type(evidence.abilityIds) == "table" then
                local attempt, encounterKey = self:GetHardModeEncounterAttempt(encounter, index)
                if attempt and not attempt.credited and not attempt.terminalDeathSatisfied then
                    for configuredAbilityId, enabled in pairs(evidence.abilityIds) do
                        local abilityId = tonumber(configuredAbilityId)
                        if enabled == true and abilityId and abilityId > 0 then
                            exactCombatAbilityIds[abilityId] = true
                            terminalAbilityObserversById[abilityId] =
                                terminalAbilityObserversById[abilityId] or {}
                            terminalAbilityObserversById[abilityId][
                                #terminalAbilityObserversById[abilityId] + 1] = {
                                encounter = encounter,
                                index = index,
                                encounterKey = encounterKey,
                                evidence = evidence,
                                attempt = attempt,
                            }
                        end
                    end
                end
            end
        end
    end

    self.activeTerminalAbilityObserversById = terminalAbilityObserversById
    local combatIds = {}
    for abilityId in pairs(exactCombatAbilityIds) do
        combatIds[#combatIds + 1] = abilityId
    end
    table.sort(combatIds)
    local signatureParts = {}
    for _, abilityId in ipairs(combatIds) do
        signatureParts[#signatureParts + 1] = tostring(abilityId)
    end
    local registrationSignature = table.concat(signatureParts, ":")
    if registrationSignature == self.conditionalObserverRegistrationSignature then
        return
    end

    for _, eventName in ipairs(self.conditionalCombatEventNames or {}) do
        EM:UnregisterForEvent(eventName)
    end
    for _, eventName in ipairs(self.conditionalEffectEventNames or {}) do
        EM:UnregisterForEvent(eventName)
    end
    self.conditionalCombatEventNames = {}
    self.conditionalEffectEventNames = nil
    self.conditionalCombatObserverActive = false
    self.conditionalEffectObserverActive = false
    self.conditionalObserverRegistrationSignature = registrationSignature

    for _, abilityId in ipairs(combatIds) do
        local eventName = self.NAME .. "_RuntimeAbility_" .. tostring(abilityId)
        EM:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, function(...)
            self:OnConditionalCombatEvent(...)
        end)
        EM:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
        self.conditionalCombatEventNames[#self.conditionalCombatEventNames + 1] = eventName
    end
    self.conditionalCombatObserverActive = #self.conditionalCombatEventNames > 0
end

function DS:StopConditionalRuntimeObservers()
    self.activeConditionalCombatObservers = nil
    self.activeConditionalEffectObservers = nil
    self.activeConditionalDeathObservers = nil
    self.activeTerminalAbilityObserversById = nil
    for _, eventName in ipairs(self.conditionalCombatEventNames or {}) do
        EM:UnregisterForEvent(eventName)
    end
    for _, eventName in ipairs(self.conditionalEffectEventNames or {}) do
        EM:UnregisterForEvent(eventName)
    end
    self.conditionalCombatEventNames = nil
    self.conditionalEffectEventNames = nil
    self.conditionalCombatObserverActive = false
    self.conditionalEffectObserverActive = false
    self.conditionalObserverRegistrationSignature = nil
end

function DS:ResetTerminalAbilityRuntimeEvidenceAfterReload(run)
    if not run or not Scoring:UsesEncounterScopedHM(run.zoneId) then
        return false
    end

    local changed = false
    for index, encounter in ipairs(Scoring:GetHardModeEncounterConfigs(run.zoneId) or {}) do
        if type(encounter.terminalAbilityEvidence) == "table" then
            local encounterKey = Scoring:GetHardModeEncounterKey(encounter, index)
            local attempt = run.hardModeEncounterAttempts
                and run.hardModeEncounterAttempts[encounterKey]
            if type(attempt) == "table" and attempt.terminalDeathSatisfied ~= true then
                if next(attempt.terminalAbilityEmitters or {}) ~= nil
                    or next(attempt.terminalAbilityActorDeaths or {}) ~= nil
                    or attempt.terminalAbilityEmitterConfirmed == true then
                    changed = true
                end
                -- Combat unit IDs are valid only inside the current UI session.
                -- Preserve a completed join, but never carry a live emitter identity
                -- through /reloadui where ESO may recycle the numeric ID.
                attempt.terminalAbilityEmitters = {}
                attempt.terminalAbilityActorDeaths = {}
                attempt.terminalAbilityEmitterConfirmed = false
                attempt.terminalAbilityEmitterConfirmedAtMs = nil
                attempt.terminalAbilityMatchedUnitId = nil
                attempt.terminalAbilityDeathAmbiguous = false
                attempt.terminalAbilityDeathAmbiguousAtMs = nil
            end
        end
        if encounter.criterion
            and encounter.criterion.type == "minimum-emitter-deaths" then
            local encounterKey = Scoring:GetHardModeEncounterKey(encounter, index)
            local attempt = run.hardModeEncounterAttempts
                and run.hardModeEncounterAttempts[encounterKey]
            if type(attempt) == "table" then
                if next(attempt.conditionAbilityEmitters or {}) ~= nil
                    or next(attempt.conditionTerminalEntities or {}) ~= nil
                    or next(attempt.conditionTerminalCandidates or {}) ~= nil
                    or next(attempt.conditionEncounterAbilityIds or {}) ~= nil
                    or next(attempt.conditionHardModeAbilityIds or {}) ~= nil then
                    changed = true
                end
                -- Combat source/target unit IDs and in-session encounter timing
                -- cannot cross /reloadui. A completed first-death snapshot keeps
                -- its numeric count; unfinished evidence is cleared and the
                -- continuous-observation guard below fails it closed if engaged.
                attempt.conditionAbilityEmitters = {}
                attempt.conditionTerminalEntities = {}
                attempt.conditionTerminalCandidates = {}
                attempt.conditionEncounterAbilityIds = {}
                attempt.conditionHardModeAbilityIds = {}
                attempt.conditionCaptureStartedAtMs = nil
                if attempt.conditionSnapshotTaken ~= true then
                    attempt.conditionWindowStartAtMs = nil
                    attempt.conditionClusterSeedCount = 0
                    attempt.conditionClusterRecoveredCount = 0
                    attempt.conditionPositiveEvidence = false
                    attempt.conditionPositiveEvidenceAtMs = nil
                    attempt.conditionPositiveEvidenceAbilityId = nil
                end
            end
        end
    end
    return changed
end

function DS:MarkConditionalObservationGapsAfterReload(run)
    if not run or not Scoring:UsesEncounterScopedHM(run.zoneId) then
        return false
    end
    local changed = false
    local encounters = Scoring:GetHardModeEncounterConfigs(run.zoneId) or {}
    for index, encounter in ipairs(encounters) do
        local resolver = self:GetConditionalHMResolver(encounter)
        local encounterKey = Scoring:GetHardModeEncounterKey(encounter, index)
        local attempt = run.hardModeEncounterAttempts and run.hardModeEncounterAttempts[encounterKey]
        if resolver and resolver.requiresContinuousObservation and attempt
            and attempt.conditionArmed and not attempt.credited then
            local snapshotAlreadySatisfied = attempt.conditionSnapshotTaken == true
                and attempt.conditionSatisfied == true
            if not snapshotAlreadySatisfied then
                local wasInProgress = attempt.conditionEngaged == true
                for _, boss in pairs(run.activeBosses or {}) do
                    local configured = nil
                    if Scoring:IsVerifiedHMEncounterResolutionSource(
                        boss.hmEncounterResolutionSource) then
                        configured = Scoring:FindHardModeEncounterConfigByKey(
                            run.zoneId,
                            boss.hmEncounterKey)
                    end
                    if configured == encounter
                        and (boss.hasTakenDamage or HasHealthLoss(boss.currentHealth, boss.maxHealth)) then
                        wasInProgress = true
                        break
                    end
                end
                if wasInProgress then
                    attempt.conditionAliveEntities = {}
                    attempt.conditionDeadEntities = {}
                    attempt.conditionCount = 0
                    attempt.conditionOpen = false
                    attempt.conditionSatisfied = false
                    if resolver.recoverLiveStateAfterReload == true then
                        attempt.conditionContinuityBroken = false
                        changed = true
                    else
                        attempt.conditionContinuityBroken = true
                        changed = true
                    end
                end
            end
        end
    end
    return changed
end

function DS:MaybeResetHardModeEncounterAttemptsFromBossReappearance()
    if not self.run or not Scoring:UsesEncounterScopedHM(self.run.zoneId) then
        return false
    end

    for _, boss in pairs(self.run.activeBosses or {}) do
        local encounter, index = self:ResolveBossHardModeMetadata(boss)
        if encounter then
            local attempt = self:GetHardModeEncounterAttempt(encounter, index)
            local predecessorIdentityId = tonumber(boss.predecessorIdentityId)
            local shouldReset = attempt and predecessorIdentityId
                and attempt.identityDeaths[predecessorIdentityId] ~= nil
            if attempt and predecessorIdentityId
                and Scoring:UsesTerminalCohortCompletion(encounter) then
                if encounter.allowCohortReentry == true then
                    -- Bar-Sakka legitimately leaves and re-enters. Only a new
                    -- incarnation of the already-selected terminal member proves
                    -- that this encounter attempt restarted.
                    shouldReset = tonumber(attempt.terminalIdentityId)
                        == predecessorIdentityId
                else
                    shouldReset = shouldReset
                        or (attempt.cohortIdentityIds[predecessorIdentityId] == true
                            and attempt.terminalIdentityId ~= nil)
                end
            end
            if attempt
                and not attempt.credited
                and predecessorIdentityId
                and shouldReset
                and (boss.currentHealth or 0) > 0 then
                return self:ResetHardModeEncounterAttempt(encounter, index)
            end
        end
    end

    return false
end

function DS:CommitHardModeEncounterCredit(encounter, attempt, encounterKey)
    if not self.run or not encounter or not attempt or attempt.credited then
        return false
    end

    local complete = select(1, Scoring:GetHardModeEncounterProgress(encounter, attempt))
    local qualified = self:IsHardModeEncounterQualified(encounter, attempt)
    if not complete or not qualified then
        return false
    end

    local creditKey = "encounter:" .. encounterKey
    local syntheticBoss = {
        name = encounterKey,
        normalizedName = creditKey,
        hmActive = true,
        hmSource = Scoring:EncounterUsesConditionalHM(encounter) and "conditional-encounter-hm" or "encounter-scoped-hm",
    }
    local awarded = self:AwardHardModeCredit(
        syntheticBoss,
        creditKey)
    if awarded or self.run.hmCreditedBossNames[creditKey] then
        attempt.credited = true
        attempt.pendingCreditAtMs = nil
        self:RefreshConditionalRuntimeObservers()
        local _, encounterIndex = Scoring:FindHardModeEncounterConfigByKey(
            self.run.zoneId,
            encounterKey)
        if encounterIndex and encounterIndex > 1 then
            self:ApplyCumulativeHardModeEvidence(
                encounterIndex,
                encounterKey,
                GetGameTimeMilliseconds())
        end
        return true
    end
    return false
end

function DS:CheckPendingHardModeEncounterCredits(nowMs)
    if not self.run or not Scoring:UsesEncounterScopedHM(self.run.zoneId) then
        return
    end

    nowMs = nowMs or GetGameTimeMilliseconds()
    local encounters = Scoring:GetHardModeEncounterConfigs(self.run.zoneId) or {}
    for index, encounter in ipairs(encounters) do
        local attempt, encounterKey = self:GetHardModeEncounterAttempt(encounter, index)
        if attempt and not attempt.credited and attempt.pendingCreditAtMs
            and nowMs - attempt.pendingCreditAtMs >= self.COMPLETION_GRACE_MS then
            local complete = select(1, Scoring:GetHardModeEncounterProgress(encounter, attempt))
            if complete and self:IsHardModeEncounterQualified(encounter, attempt) then
                self:CommitHardModeEncounterCredit(
                    encounter,
                    attempt,
                    encounterKey)
            else
                attempt.pendingCreditAtMs = nil
            end
        end
    end
end

function DS:RecordHardModeEncounterIdentityDeath(boss, source, eventTimeMs)
    if not self.run or not boss then
        return false
    end

    local identityId = tonumber(boss.identityId)
    if not identityId or identityId <= 0 then
        return false
    end
    source = tostring(source or "unknown")
    if source ~= "boss-death-state" then
        return false
    end

    local encounter, index = self:ResolveBossHardModeMetadata(boss)
    if not encounter then
        return false
    end

    local attempt, encounterKey = self:GetHardModeEncounterAttempt(encounter, index)
    if not attempt then
        return false
    end

    eventTimeMs = eventTimeMs or GetGameTimeMilliseconds()
    local death = attempt.identityDeaths[identityId]
    local isNewIdentityDeath = death == nil

    if isNewIdentityDeath then
        death = {
            identityId = identityId,
            encounterKey = encounterKey,
            firstObservedAtMs = eventTimeMs,
            sources = {},
        }
        attempt.identityDeaths[identityId] = death
    end
    death.sources = death.sources or {}
    local changed = death.sources[source] ~= true
    death.sources[source] = true
    death.lastObservedAtMs = eventTimeMs

    if isNewIdentityDeath and Scoring:EncounterUsesConditionalHM(encounter) then
        local resolver = self:GetConditionalHMResolver(encounter)
        if resolver and resolver.onTerminalDeath and not attempt.conditionSnapshotTaken
            and source == "boss-death-state" then
            resolver.onTerminalDeath(self, encounter, attempt, encounterKey, {
                identityId = identityId,
                source = source,
                eventTimeMs = eventTimeMs,
            })
        end
    elseif isNewIdentityDeath and boss.hmActive then
        attempt.hmMembers["identity:" .. tostring(identityId)] = true
        attempt.hmObserved = true
    end

    if isNewIdentityDeath then
        attempt.lastDeathAtMs = eventTimeMs
        attempt.lastDeathIdentityId = identityId
    end

    if Scoring:UsesTerminalCohortCompletion(encounter)
        and type(encounter.terminalAbilityEvidence) == "table" then
        if self:TryResolveTerminalAbilityDeath(encounter, attempt, eventTimeMs) then
            changed = true
        end
    elseif isNewIdentityDeath and Scoring:UsesTerminalCohortCompletion(encounter) then
        local required = math.max(1, tonumber(encounter.required) or 1)
        local boundCount = 0
        for _, enabled in pairs(attempt.cohortIdentityIds or {}) do
            if enabled == true then
                boundCount = boundCount + 1
            end
        end

        if boundCount == required and attempt.cohortIdentityIds[identityId] == true then
            local cohortDeathCount = 0
            local survivingIdentityId = nil
            for cohortIdentityId in pairs(attempt.cohortIdentityIds) do
                if attempt.identityDeaths[cohortIdentityId] then
                    cohortDeathCount = cohortDeathCount + 1
                else
                    survivingIdentityId = tonumber(cohortIdentityId)
                end
            end

            -- In a role-independent cohort, a direct first-member death identifies
            -- the other member as the terminal actor. Stable survivor presence
            -- covers a missing first death-state without relying on display text.
            if cohortDeathCount == required - 1 and survivingIdentityId
                and not attempt.terminalIdentityId then
                attempt.terminalIdentityId = survivingIdentityId
                attempt.terminalIdentitySource = "cohort-member-death"
                attempt.terminalIdentityObservedAtMs = eventTimeMs
            end

            if tonumber(attempt.terminalIdentityId) == identityId
                or cohortDeathCount >= required then
                attempt.terminalDeathSatisfied = true
                attempt.terminalDeathIdentityId = identityId
                attempt.terminalDeathObservedAtMs = eventTimeMs
                attempt.terminalDeathSource = source
            end
        end
    end

    local complete = select(1, Scoring:GetHardModeEncounterProgress(encounter, attempt))
    local qualified = self:IsHardModeEncounterQualified(encounter, attempt)

    if isNewIdentityDeath and complete and qualified and not attempt.credited
        and source == "boss-death-state" then
        if not attempt.pendingCreditAtMs then
            attempt.pendingCreditAtMs = eventTimeMs
        end
    end

    if isNewIdentityDeath or changed then
        self:TouchActiveRunPersistence()
        return true
    end
    return false
end

function DS:GetSingleActiveBoss()
    if not self.run then
        return nil
    end

    local found = nil
    local count = 0
    for _, boss in pairs(self.run.activeBosses) do
        count = count + 1
        found = boss
        if count > 1 then
            return nil
        end
    end
    return found
end

function DS:GetBossCreditKey(boss)
    if not boss then
        return nil
    end
    if boss.hmEncounterKey and Scoring:IsVerifiedHMEncounterResolutionSource(
        boss.hmEncounterResolutionSource) then
        return "encounter:" .. tostring(boss.hmEncounterKey)
    end
    local identityId = tonumber(boss.identityId)
    if identityId and identityId > 0 then
        return "identity:" .. tostring(identityId)
    end
    return nil
end

function DS:AwardHardModeCredit(boss, creditKeyOverride)
    if not self.run or not boss or not boss.hmActive then
        return false
    end

    local key = creditKeyOverride or self:GetBossCreditKey(boss)
    if not key then
        return false
    end

    if Scoring:UsesEncounterScopedHM(self.run.zoneId)
        and not Scoring:IsValidHardModeEncounterCreditKey(self.run.zoneId, creditKeyOverride) then
        return false
    end

    if key and self.run.hmCreditedBossNames[key] then
        return false
    end

    local zoneConfig = Scoring:GetZoneConfig(self.run.zoneId) or {}
    local expected = zoneConfig.expectedHardModes
    if expected and self.run.hmBossKills >= expected then
        return false
    end

    self.run.hmBossKills = self.run.hmBossKills + 1
    self.run.hmScore = self.run.hmScore + Data.SCORING.hardModeBoss
    if key then
        self.run.hmCreditedBossNames[key] = true
    end

    self:TouchActiveRunPersistence()
    return true
end

function DS:FindFinalEncounterBossEvidence()
    if not self.run then
        return nil
    end

    local encounter = Scoring:GetFinalEncounterConfig(self.run.zoneId)
    local terminalEncounterKey = encounter
        and (encounter.hmEncounterKey or encounter.hmCreditKey)
    if type(terminalEncounterKey) ~= "string" or terminalEncounterKey == "" then
        return nil
    end

    for _, boss in pairs(self.run.activeBosses or {}) do
        if Scoring:IsVerifiedHMEncounterResolutionSource(
                boss.hmEncounterResolutionSource)
            and boss.hmEncounterKey == terminalEncounterKey then
            return boss
        end
    end

    for _, seen in pairs(self.run.seenBossNames or {}) do
        if Scoring:IsVerifiedHMEncounterResolutionSource(
                seen.hmEncounterResolutionSource)
            and seen.hmEncounterKey == terminalEncounterKey then
            return seen
        end
    end

    return nil
end

function DS:ReconcileActivityCompletionHM()
    if not self.run then
        return nil
    end

    -- Activity Finder completion is authoritative that the terminal encounter
    -- completed. Refresh only while still inside the dungeon; completion events
    -- can arrive during/after zone transition.
    if self:IsArmed() then
        self:RefreshBosses()
    end

    local finalBoss = self:FindFinalEncounterBossEvidence()

    if Scoring:UsesEncounterScopedHM(self.run.zoneId) then
        local hmEncounter, hmIndex = Scoring:GetFinalHardModeEncounterConfig(self.run.zoneId)
        if not hmEncounter then
            return finalBoss
        end

        local hmAttempt, encounterKey = self:GetHardModeEncounterAttempt(hmEncounter, hmIndex)
        if not hmAttempt or hmAttempt.credited then
            return finalBoss
        end

        -- Activity Finder completion is authoritative encounter completion, but it
        -- is not HM evidence. It closes progress by stable configuration key while
        -- the retained HM/conditional evidence still decides qualification.
        local completedAtMs = GetGameTimeMilliseconds()
        hmAttempt.authoritativeCompletion = true
        hmAttempt.authoritativeCompletionSource = "activity-finder"
        hmAttempt.authoritativeCompletionAtMs = completedAtMs

        if Scoring:EncounterUsesConditionalHM(hmEncounter) then
            local resolver = self:GetConditionalHMResolver(hmEncounter)
            if resolver and resolver.onTerminalDeath and not hmAttempt.conditionSnapshotTaken then
                resolver.onTerminalDeath(self, hmEncounter, hmAttempt, encounterKey, {
                    source = "activity-completion-reconcile",
                    eventTimeMs = completedAtMs,
                    authoritativeCompletion = true,
                })
            end
        end

        if self:IsHardModeEncounterQualified(hmEncounter, hmAttempt) then
            self:CommitHardModeEncounterCredit(hmEncounter, hmAttempt, encounterKey)
        end
        self:TouchActiveRunPersistence()
        return finalBoss
    end

    if finalBoss and finalBoss.hmActive then
        self:AwardHardModeCredit(finalBoss)
    else
        -- Conservative registry-gap fallback for ESO encounters whose terminal
        -- boss has not yet been explicitly modeled in the data table.
        local singleBoss = self:GetSingleActiveBoss()
        if singleBoss and singleBoss.hmActive then
            self:AwardHardModeCredit(singleBoss)
            finalBoss = singleBoss
        end
    end

    return finalBoss
end

