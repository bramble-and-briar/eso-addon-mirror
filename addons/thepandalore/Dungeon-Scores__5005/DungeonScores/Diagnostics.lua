DungeonScores = DungeonScores or {}

-- Minimal completed-run support snapshots for the BETA tab.

local DS = DungeonScores
DS.Diagnostics = DS.Diagnostics or {}
local Diagnostics = DS.Diagnostics
local Scoring = DS.Scoring
local DeepCopy = DS.Util.DeepCopy

local MAX_BETA_SNAPSHOTS = 10

local function CountKeys(value)
    local count = 0
    if type(value) == "table" then
        for _ in pairs(value) do
            count = count + 1
        end
    end
    return count
end

function Diagnostics:CountObservedHardModeAttempts(attempts)
    local count = 0
    for _, attempt in pairs(attempts or {}) do
        if type(attempt) == "table" and (attempt.hmObserved == true
            or attempt.conditionSatisfied == true or attempt.credited == true) then
            count = count + 1
        end
    end
    return count
end

local function BuildTerminalAbilityAttemptEvidence(run)
    local entries = {}
    if not Scoring or type(Scoring.GetHardModeEncounterConfigs) ~= "function"
        or type(Scoring.GetHardModeEncounterKey) ~= "function" then
        return entries
    end

    for index, encounter in ipairs(Scoring:GetHardModeEncounterConfigs(run.zoneId) or {}) do
        if type(encounter.terminalAbilityEvidence) == "table" then
            local encounterKey = Scoring:GetHardModeEncounterKey(encounter, index)
            local attempt = run.hardModeEncounterAttempts
                and run.hardModeEncounterAttempts[encounterKey] or {}
            local confirmedEmitterCount = 0
            for _, emitter in pairs(attempt.terminalAbilityEmitters or {}) do
                if type(emitter) == "table" and emitter.confirmed == true then
                    confirmedEmitterCount = confirmedEmitterCount + 1
                end
            end

            entries[#entries + 1] = {
                encounterKey = encounterKey,
                attemptId = attempt.id,
                confirmedEmitterCount = confirmedEmitterCount,
                matchedDeathCount = CountKeys(attempt.terminalAbilityActorDeaths),
                cohortIdentityCount = CountKeys(attempt.cohortIdentityIds),
                hmObserved = attempt.hmObserved == true,
                terminalDeathSatisfied = attempt.terminalDeathSatisfied == true,
                terminalAbilityDeathAmbiguous = attempt.terminalAbilityDeathAmbiguous == true,
                credited = attempt.credited == true,
                terminalIdentitySource = attempt.terminalIdentitySource,
                terminalDeathSource = attempt.terminalDeathSource,
            }
        end
    end
    return entries
end

function Diagnostics:Initialize(savedVariables)
    self.saved = savedVariables
    self.saved.betaRunSnapshots = self.saved.betaRunSnapshots or {}

    -- Trim retired, write-only chronology from saved diagnostic snapshots and
    -- any suspended run. Preserve boss identities, max-health samples, semantic
    -- joins, and all HM/terminal evidence used by live troubleshooting.
    local evidence = DS.EncounterEvidence
    if evidence and evidence.PruneRetiredTelemetry then
        local active = self.saved.activeRun
        if type(active) == "table" then
            evidence:PruneRetiredTelemetry(active.encounterEvidence)
        end
        for _, snapshot in ipairs(self.saved.betaRunSnapshots) do
            if type(snapshot) == "table" then
                evidence:PruneRetiredTelemetry(snapshot.encounterEvidence)
            end
        end
    end
end

function Diagnostics:CaptureRunSnapshot(settlement, run)
    if not self.saved or type(settlement) ~= "table" or type(run) ~= "table" then
        return nil
    end

    -- A score can finalize before the first boss evidence read after restoring
    -- an older SavedVariables table. Never duplicate its retired streams.
    if DS.EncounterEvidence then
        DS.EncounterEvidence:PruneRetiredTelemetry(run.encounterEvidence)
    end

    local finalAttempt = run.finalEncounterAttempt or {}
    local terminalAbilityAttempts = BuildTerminalAbilityAttemptEvidence(run)
    local terminalAbilityEmitterCount = 0
    local terminalAbilityDeathCount = 0
    for _, evidence in ipairs(terminalAbilityAttempts) do
        terminalAbilityEmitterCount = terminalAbilityEmitterCount
            + evidence.confirmedEmitterCount
        terminalAbilityDeathCount = terminalAbilityDeathCount
            + evidence.matchedDeathCount
    end
    local snapshotId = run.runId and string.format("DS-R%s", tostring(run.runId))
        or string.format(
            "DS-%s-%s-%s",
            tostring(run.zoneId or 0),
            tostring(run.generation or 0),
            tostring(run.completedAtTimeStamp or settlement.completedAtTimeStamp or GetTimeStamp()))
    local snapshot = {
        snapshotId = snapshotId,
        addonVersion = DS.VERSION,
        createdAtTimeStamp = GetTimeStamp(),
        runId = run.runId,
        runGeneration = run.generation,
        zoneId = run.zoneId,
        zoneName = run.zoneName,
        isVeteran = run.isVeteran == true,

        startReason = run.startReason,
        eligibilityReason = run.eligibilityReason,
        eligibleAtReset = run.eligible == true,
        groupSizeAtReset = run.groupSizeAtReset,
        maxConcurrentGroupSize = run.maxConcurrentGroupSize,
        maxConcurrentGroupSizeAtCompletion = run.maxConcurrentGroupSizeAtCompletion,
        settlementGroupSize = settlement.runGroupSize,
        partyChallengePolicy = settlement.partyChallengePolicy,
        terminalEncounterPartySize = settlement.terminalEncounterPartySize,
        terminalEncounterPartySizeSource = settlement.terminalEncounterPartySizeSource,
        partyAverageGroupSize = settlement.partyAverageGroupSize,
        partyChallengeScore = settlement.partyChallengeScore,
        partySizeDurationsMs = DeepCopy(settlement.partySizeDurationsMs or {}),
        restoreCount = tonumber(run.restoreCount) or 0,
        lifecycleTrace = DeepCopy(run.lifecycleTrace or {}),
        observedParticipantCount = #(settlement.groupMembers or {}),

        wasLFG = run.wasLFG == true,
        lfgCompleteState = run.lfgCompleteState == true,
        startedAtTimeStamp = run.startedAtTimeStamp,
        completedAtTimeStamp = run.completedAtTimeStamp,
        finalizedAtTimeStamp = settlement.finalizedAtTimeStamp,
        elapsedMs = settlement.elapsedMs,
        scoreSessionOpen = settlement.scoreSessionOpen == true,
        scoreAtCompletion = settlement.scoreAtCompletion or run.scoreAtCompletion,
        currentScore = settlement.finalScore,
        postCompletionGain = settlement.postCompletionGain or 0,
        competitiveEligible = run.competitiveEligible ~= false,
        integrityStatus = run.integrityStatus,
        integrityReason = run.integrityReason,
        deathsAtCompletion = run.completionDeaths,
        hmBossKillsAtCompletion = run.completionHmBossKills,
        bossKillsAtCompletion = run.bossKillsAtCompletion,
        bossEncountersAtCompletion = run.bossEncountersAtCompletion,
        expectedBossEncountersAtCompletion = run.expectedBossEncountersAtCompletion,
        bossEncountersObserved = run.bossEncountersObserved,
        routeAbilityEncounterCount = DS.CountObservedRouteAbilityEncounters
            and DS:CountObservedRouteAbilityEncounters(run) or 0,

        finalizeReason = settlement.finalizeReason,
        completionReason = run.completionReason or settlement.completionReason,
        completionBossName = settlement.completionBossName,
        completionCandidateReason = run.completionCandidateReason,
        completionCandidateAuthoritative = run.completionCandidateAuthoritative == true,
        completionCandidateAtMs = run.completionCandidateAtMs,
        completionCandidateSetAtMs = run.completionCandidateSetAtMs,

        finalEncounterArmed = run.finalEncounterArmed == true,
        finalEncounterCompleted = run.finalEncounterCompleted == true,
        finalEncounterAttemptId = finalAttempt.id,
        finalEncounterDeathCount = CountKeys(finalAttempt.deaths),
        finalEncounterIdentityDeathCount = CountKeys(finalAttempt.identityDeaths),
        activeBossCountAtCapture = CountKeys(run.activeBosses),
        seenBossNameCount = CountKeys(run.seenBossNames),
        bossIdentitySequence = run.bossIdentitySequence,
        hmEvidencePolicyVersion = run.hmEvidencePolicyVersion,
        bossDeathStateCreditCount = CountKeys(run.bossDeathStateCredits),
        terminalBossDeathEvidenceCount = CountKeys(run.terminalBossDeathEvidence),
        reconciledBossKillCount = CountKeys(run.reconciledBossKills),
        -- A tracker is allocated for every configured encounter as it is observed,
        -- including base Veteran. Keep that count separate from actual HM evidence.
        hardModeTrackerCount = CountKeys(run.hardModeEncounterAttempts),
        hardModeObservedCount = self:CountObservedHardModeAttempts(
            run.hardModeEncounterAttempts),
        hardModeAttemptCount = CountKeys(run.hardModeEncounterAttempts),
        hmCreditedBossCount = CountKeys(run.hmCreditedBossNames),
        encounterEvidenceIdentityCount = CountKeys(
            run.encounterEvidence and run.encounterEvidence.identities),
        terminalAbilityEmitterCount = terminalAbilityEmitterCount,
        terminalAbilityDeathCount = terminalAbilityDeathCount,
        terminalAbilityAttempts = terminalAbilityAttempts,

        lastBossDeathName = run.lastBossDeathName,
        lastBossDeathAtMs = run.lastBossDeathAtMs,
        lastDeathAtMs = run.lastDeathAtMs,
        lastPersistedAtTimeStamp = run.lastPersistedAtTimeStamp,
        persistedElapsedMs = run.persistedElapsedMs,
        persistedCompletedElapsedMs = run.persistedCompletedElapsedMs,
        exitCompletionRecoveryUntilMs = run.exitCompletionRecoveryUntilMs,

        -- Preserve the compact state that is most useful when the scorer disagrees
        -- with ESO. This is intentionally not a chronological event log.
        hardModeEncounterAttempts = DeepCopy(run.hardModeEncounterAttempts or {}),
        hmCreditedBossNames = DeepCopy(run.hmCreditedBossNames or {}),
        encounterEvidence = DeepCopy(run.encounterEvidence or {}),
        seenBossNames = DeepCopy(run.seenBossNames or {}),
        bossEncounterLedger = DeepCopy(run.bossEncounterLedger or {}),
        finalEncounterAttempt = DeepCopy(run.finalEncounterAttempt or {}),
        bossDeathState = DeepCopy(run.bossDeathState or {}),
        bossDeathStateCredits = DeepCopy(run.bossDeathStateCredits or {}),
        terminalBossDeathEvidence = DeepCopy(run.terminalBossDeathEvidence or {}),
        reconciledBossKills = DeepCopy(run.reconciledBossKills or {}),
    }

    settlement.runGeneration = run.generation
    local replaced = false
    for index = #self.saved.betaRunSnapshots, 1, -1 do
        if self.saved.betaRunSnapshots[index].snapshotId == snapshotId then
            self.saved.betaRunSnapshots[index] = snapshot
            replaced = true
            break
        end
    end
    if not replaced then
        self.saved.betaRunSnapshots[#self.saved.betaRunSnapshots + 1] = snapshot
        while #self.saved.betaRunSnapshots > MAX_BETA_SNAPSHOTS do
            table.remove(self.saved.betaRunSnapshots, 1)
        end
    end
    return snapshot
end

function Diagnostics:GetBetaRunSnapshots()
    if not self.saved then
        return {}
    end
    self.saved.betaRunSnapshots = self.saved.betaRunSnapshots or {}
    return self.saved.betaRunSnapshots
end

function Diagnostics:ShowReport()
    if DS.History and DS.History.ShowBeta then
        DS.History:ShowBeta()
        return
    end
    DS:Chat(GetString(SI_DUNGEON_SCORES_CHAT_BETA_UNAVAILABLE))
end
