DungeonScores = DungeonScores or {}

-- Outcome-conditional Hard Mode resolver definitions.

local DS = DungeonScores
local Scoring = DS.Scoring

local NormalizeName = DS.Util.NormalizeName

-- Outcome-conditional HM resolver framework. Each criterion type owns only the
-- event surfaces it needs; the runtime dispatcher handles arming, persistence,
-- encounter completion, and the single HM credit path uniformly.
DS.ConditionalHMResolvers = DS.ConditionalHMResolvers or {}
local ConditionalHMResolvers = DS.ConditionalHMResolvers

local function IsPlayerSideCombatUnitType(unitType)
    return unitType == COMBAT_UNIT_TYPE_PLAYER
        or unitType == COMBAT_UNIT_TYPE_GROUP
        or unitType == COMBAT_UNIT_TYPE_PLAYER_PET
        or (COMBAT_UNIT_TYPE_COMPANION ~= nil and unitType == COMBAT_UNIT_TYPE_COMPANION)
end

local function CountKeys(value)
    local count = 0
    if type(value) == "table" then
        for _ in pairs(value) do
            count = count + 1
        end
    end
    return count
end

local function CriterionNameMatches(criterion, value, exactField, containsField)
    if type(criterion) ~= "table" then
        return false
    end
    return Scoring:ConditionalTextMatches(value, criterion[exactField], criterion[containsField])
end

local function GetTrackedHostileParticipant(criterion, context)
    if type(criterion) ~= "table" or type(context) ~= "table" then
        return nil
    end

    if IsPlayerSideCombatUnitType(context.sourceType)
        and context.targetUnitId and context.targetUnitId ~= 0
        and CriterionNameMatches(criterion, context.targetName, "trackedNames", "trackedNameContainsAny") then
        return context.targetName, context.targetUnitId, "target"
    end

    if IsPlayerSideCombatUnitType(context.targetType)
        and context.sourceUnitId and context.sourceUnitId ~= 0
        and CriterionNameMatches(criterion, context.sourceName, "trackedNames", "trackedNameContainsAny") then
        return context.sourceName, context.sourceUnitId, "source"
    end

    return nil
end

local function MarkConditionalFailure(self, encounter, attempt, encounterKey, reason, fields)
    if not attempt or attempt.conditionFailed then
        return false
    end
    attempt.conditionFailed = true
    attempt.conditionFailureReason = reason
    attempt.conditionFailureAtMs = GetGameTimeMilliseconds()
    fields = fields or {}
    fields.encounterKey = encounterKey
    fields.attemptId = attempt.id
    fields.criterionType = encounter and encounter.criterion and encounter.criterion.type or nil
    fields.reason = reason
    self:TouchActiveRunPersistence()
    return true
end

ConditionalHMResolvers["assumed-hm"] = {
    -- Explicit scoring-policy resolver for a conditional HM whose failure action
    -- is not reliably observable groupwide. Encounter completion is sufficient.
    requiresCleanPrepull = false,
    isSatisfied = function()
        return true
    end,
}

ConditionalHMResolvers["no-npc-deaths"] = {
    -- Spindleclutch II's protected sacrifices are passive/non-hostile. Do not
    -- require hostile participation or COMBAT_UNIT_TYPE_NONE: any non-boss death
    -- that is not a player/group/pet/companion death is a conservative failure
    -- signal while Vorenor's encounter is actively engaged.
    requiresCleanPrepull = true,
    requiresContinuousObservation = true,
    onDeath = function(self, encounter, attempt, encounterKey, context)
        if context.class == "boss"
            or IsPlayerSideCombatUnitType(context.targetType)
            or attempt.conditionDeaths[context.deathKey] then
            return false
        end
        attempt.conditionDeaths[context.deathKey] = true
        attempt.conditionFailureName = NormalizeName(context.targetName)
        return MarkConditionalFailure(self, encounter, attempt, encounterKey, "protected-npc-died", {
            targetName = context.targetName,
            targetType = context.targetType,
        })
    end,
    isSatisfied = function(_, _, attempt)
        return attempt.conditionArmed == true
            and attempt.conditionFailed ~= true
            and attempt.conditionContinuityBroken ~= true
    end,
}

local function RecountMinimumEmitterDeaths(encounter, attempt)
    local windowStartAtMs = tonumber(attempt.conditionWindowStartAtMs)
    if not windowStartAtMs then
        return false
    end

    local windowEndAtMs = tonumber(attempt.conditionClosedAtMs)
    local oldCount = tonumber(attempt.conditionCount) or 0
    local oldRecoveredCount = tonumber(attempt.conditionClusterRecoveredCount) or 0
    attempt.conditionDeaths = {}
    attempt.conditionDeadEntities = {}

    -- A classified terminal is always a seed. Unclassified zero-health actors
    -- may join only the same tightly timed terminal-event component as a seed.
    -- This recovers ghouls killed before their first cast without turning every
    -- add death in the final room into Ghoul Slayer evidence.
    local candidatesByKey = {}
    local function AddCandidate(unitKey, terminal, classified)
        local terminalAtMs = type(terminal) == "table"
            and tonumber(terminal.firstObservedAtMs) or nil
        if not terminalAtMs or terminalAtMs < windowStartAtMs
            or (windowEndAtMs and terminalAtMs > windowEndAtMs) then
            return
        end

        unitKey = tostring(unitKey)
        local candidate = candidatesByKey[unitKey]
        if not candidate or terminalAtMs < candidate.terminalAtMs then
            candidate = {
                unitKey = unitKey,
                terminalAtMs = terminalAtMs,
                classified = classified == true,
            }
            candidatesByKey[unitKey] = candidate
        elseif classified == true then
            candidate.classified = true
        end
    end

    for unitKey, terminal in pairs(attempt.conditionTerminalEntities or {}) do
        AddCandidate(unitKey, terminal, true)
    end
    for unitKey, terminal in pairs(attempt.conditionTerminalCandidates or {}) do
        AddCandidate(
            unitKey,
            terminal,
            attempt.conditionAbilityEmitters
                and attempt.conditionAbilityEmitters[tostring(unitKey)] ~= nil)
    end

    local candidates = {}
    for _, candidate in pairs(candidatesByKey) do
        candidates[#candidates + 1] = candidate
    end
    table.sort(candidates, function(left, right)
        if left.terminalAtMs == right.terminalAtMs then
            return left.unitKey < right.unitKey
        end
        return left.terminalAtMs < right.terminalAtMs
    end)

    local admitted = {}
    local clusterJoinMs = math.max(
        0, tonumber(encounter.criterion.terminalClusterJoinMs) or 0)
    if clusterJoinMs > 0 then
        local componentStart = 1
        local componentHasSeed = false
        local function AdmitComponent(componentEnd)
            if not componentHasSeed then
                return
            end
            for index = componentStart, componentEnd do
                admitted[candidates[index].unitKey] = true
            end
        end

        for index, candidate in ipairs(candidates) do
            if index > componentStart
                and candidate.terminalAtMs - candidates[index - 1].terminalAtMs
                    > clusterJoinMs then
                AdmitComponent(index - 1)
                componentStart = index
                componentHasSeed = false
            end
            if candidate.classified then
                componentHasSeed = true
            end
        end
        AdmitComponent(#candidates)
    else
        for _, candidate in ipairs(candidates) do
            if candidate.classified then
                admitted[candidate.unitKey] = true
            end
        end
    end

    local count = 0
    local seedCount = 0
    for _, candidate in ipairs(candidates) do
        if admitted[candidate.unitKey] then
            attempt.conditionDeaths["unit:" .. candidate.unitKey] = true
            attempt.conditionDeadEntities[candidate.unitKey] = true
            count = count + 1
            if candidate.classified then
                seedCount = seedCount + 1
            end
        end
    end
    attempt.conditionCount = count
    attempt.conditionClusterSeedCount = seedCount
    attempt.conditionClusterRecoveredCount = math.max(0, count - seedCount)
    local minimum = math.max(0, tonumber(encounter.criterion.minimum) or 0)
    attempt.conditionSatisfied = count >= minimum
        or attempt.conditionPositiveEvidence == true
    attempt.conditionOpen = attempt.conditionSatisfied
    return oldCount ~= count
        or oldRecoveredCount ~= attempt.conditionClusterRecoveredCount
end

local function IsKnownBossCombatUnitId(self, unitId)
    unitId = tonumber(unitId) or 0
    if unitId <= 0 then
        return false
    end
    for _, boss in pairs(self.run and self.run.activeBosses or {}) do
        if tonumber(boss.unitId) == unitId then
            return true
        end
    end
    return false
end

local function RecordMinimumTerminalCandidate(self, encounter, attempt, unitId, eventTimeMs, source)
    unitId = tonumber(unitId) or 0
    if unitId <= 0 or attempt.conditionArmed ~= true
        or IsKnownBossCombatUnitId(self, unitId) then
        return false
    end

    attempt.conditionTerminalCandidates = attempt.conditionTerminalCandidates or {}
    local unitKey = tostring(unitId)
    if attempt.conditionTerminalCandidates[unitKey] then
        return false
    end

    eventTimeMs = tonumber(eventTimeMs) or GetGameTimeMilliseconds()
    attempt.conditionTerminalCandidates[unitKey] = {
        sourceUnitId = unitId,
        firstObservedAtMs = eventTimeMs,
        source = source,
    }
    RecountMinimumEmitterDeaths(encounter, attempt)
    self:TouchActiveRunPersistence()
    return true
end

local function RecordMinimumEmitterTerminal(self, encounter, attempt, unitId, eventTimeMs, source)
    unitId = tonumber(unitId) or 0
    if unitId <= 0 then
        return false
    end

    attempt.conditionAbilityEmitters = attempt.conditionAbilityEmitters or {}
    attempt.conditionTerminalEntities = attempt.conditionTerminalEntities or {}
    local unitKey = tostring(unitId)
    if not attempt.conditionAbilityEmitters[unitKey]
        or attempt.conditionTerminalEntities[unitKey] then
        return false
    end

    eventTimeMs = tonumber(eventTimeMs) or GetGameTimeMilliseconds()
    attempt.conditionTerminalEntities[unitKey] = {
        sourceUnitId = unitId,
        firstObservedAtMs = eventTimeMs,
        source = source,
    }
    RecountMinimumEmitterDeaths(encounter, attempt)
    self:TouchActiveRunPersistence()
    return true
end

ConditionalHMResolvers["minimum-emitter-deaths"] = {
    -- Wayrest II uses only numeric event evidence. The encounter is selected by
    -- the paired Pellingare ability signature. Ghoul emissions provide positive
    -- seeds; a zero-cast terminal can join only the same bounded event cluster.
    -- Numeric combat unit IDs are ephemeral in-session join keys, never static IDs.
    requiresCleanPrepull = false,
    requiresContinuousObservation = true,
    observeBeforeArm = true,
    observeBeforeRunStart = true,
    allowPreArmDeath = true,
    combatObserver = true,
    onEncounterBound = function(self, encounter, attempt)
        RecountMinimumEmitterDeaths(encounter, attempt)
        attempt.conditionObserverVerified = true
        self:TouchActiveRunPersistence()
        return true
    end,
    onCombat = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion or {}
        if attempt.conditionClosed or attempt.conditionSnapshotTaken then
            return false
        end

        local changed = false
        local eventTimeMs = tonumber(context.eventTimeMs) or GetGameTimeMilliseconds()
        local abilityId = tonumber(context.abilityId) or 0
        local hostileSource = not IsPlayerSideCombatUnitType(context.sourceType)

        if hostileSource and self:IsConditionalAbilityIdMatch(
            abilityId, criterion.encounterAbilityIds) then
            if attempt.conditionEncounterAbilityIds[abilityId] ~= true then
                attempt.conditionEncounterAbilityIds[abilityId] = true
                attempt.conditionCaptureStartedAtMs = attempt.conditionCaptureStartedAtMs
                    or eventTimeMs
                changed = true
            end
            if self:TryBindConditionalAbilityEncounterCohort(
                encounter, nil, attempt, eventTimeMs) then
                changed = true
            end
        end

        if hostileSource and self:IsConditionalAbilityIdMatch(
            abilityId, criterion.hardModeAbilityIds) then
            if attempt.conditionHardModeAbilityIds[abilityId] ~= true then
                attempt.conditionHardModeAbilityIds[abilityId] = true
                changed = true
            end
            local observedHardModeAbilityCount = 0
            for observedAbilityId, enabled in pairs(
                attempt.conditionHardModeAbilityIds) do
                if enabled == true and self:IsConditionalAbilityIdMatch(
                    observedAbilityId, criterion.hardModeAbilityIds) then
                    observedHardModeAbilityCount = observedHardModeAbilityCount + 1
                end
            end
            local requiredHardModeAbilityCount = math.max(
                1, tonumber(criterion.requiredHardModeAbilityIds) or 1)
            if observedHardModeAbilityCount >= requiredHardModeAbilityCount
                and attempt.conditionPositiveEvidence ~= true then
                attempt.conditionPositiveEvidence = true
                attempt.conditionPositiveEvidenceAtMs = eventTimeMs
                attempt.conditionPositiveEvidenceAbilityId = abilityId
                attempt.conditionSatisfied = true
                changed = true
            end
        end

        local sourceUnitId = tonumber(context.sourceUnitId) or 0
        if hostileSource and sourceUnitId > 0
            and self:IsConditionalAbilityIdMatch(abilityId, criterion.emitterAbilityIds) then
            local unitKey = tostring(sourceUnitId)
            local emitter = attempt.conditionAbilityEmitters[unitKey]
            if type(emitter) ~= "table" then
                attempt.conditionAbilityEmitters[unitKey] = {
                    sourceUnitId = sourceUnitId,
                    firstObservedAtMs = eventTimeMs,
                    lastObservedAtMs = eventTimeMs,
                    abilityIds = { [abilityId] = true },
                }
                attempt.conditionCaptureStartedAtMs = attempt.conditionCaptureStartedAtMs
                    or eventTimeMs
                changed = true
            else
                emitter.lastObservedAtMs = eventTimeMs
                emitter.abilityIds = emitter.abilityIds or {}
                if emitter.abilityIds[abilityId] ~= true then
                    emitter.abilityIds[abilityId] = true
                    changed = true
                end
            end
            if attempt.conditionTerminalCandidates
                and attempt.conditionTerminalCandidates[unitKey]
                and RecountMinimumEmitterDeaths(encounter, attempt) then
                changed = true
            end
        end

        local overflow = tonumber(context.overflow) or 0
        if overflow > 0 and (tonumber(context.hitValue) or 0) > 0
            and not IsPlayerSideCombatUnitType(context.targetType) then
            if RecordMinimumTerminalCandidate(
                self, encounter, attempt, context.targetUnitId, eventTimeMs, "lethal-overflow") then
                changed = true
            end
            if RecordMinimumEmitterTerminal(
                self, encounter, attempt, context.targetUnitId, eventTimeMs, "lethal-overflow") then
                changed = true
            end
        end

        if changed then
            self:TouchActiveRunPersistence()
        end
        return changed
    end,
    onDeath = function(self, encounter, attempt, encounterKey, context)
        if attempt.conditionClosed or attempt.conditionSnapshotTaken then
            return false
        end
        if context.class == "boss"
            or IsPlayerSideCombatUnitType(context.targetType) then
            return false
        end
        local changed = RecordMinimumTerminalCandidate(
            self, encounter, attempt, context.targetUnitId,
            context.eventTimeMs, "combat-death")
        if RecordMinimumEmitterTerminal(
            self, encounter, attempt, context.targetUnitId,
            context.eventTimeMs, "combat-death") then
            changed = true
        end
        return changed
    end,
    onTerminalDeath = function(self, encounter, attempt, encounterKey, context)
        if context.source ~= "boss-death-state" then
            -- Activity completion proves encounter completion, but it cannot
            -- reconstruct the first-twin cutoff when direct death state was lost.
            attempt.conditionContinuityBroken = true
            attempt.conditionFailureReason = "missing-first-boss-death-boundary"
            self:TouchActiveRunPersistence()
            self:RefreshConditionalRuntimeObservers()
            return false
        end

        local cutoffIdentityId = tonumber(context.identityId)
        local liveBoundaryMembers = 0
        for _, boss in pairs(self.run and self.run.activeBosses or {}) do
            local identityId = tonumber(boss.identityId)
            if identityId and attempt.cohortIdentityIds[identityId] == true
                and (identityId == cutoffIdentityId
                    or (boss.deathStateObserved ~= true
                        and (tonumber(boss.currentHealth) or 0) > 0)) then
                liveBoundaryMembers = liveBoundaryMembers + 1
            end
        end
        local requiredMembers = math.max(1, tonumber(encounter.required) or 1)
        if liveBoundaryMembers ~= requiredMembers then
            -- If the other twin is already absent/dead, this could be the second
            -- death after a missed first death-state callback. That cannot define
            -- the achievement cutoff safely, so the attempt fails closed.
            attempt.conditionContinuityBroken = true
            attempt.conditionFailureReason = "ambiguous-first-boss-death-boundary"
            self:TouchActiveRunPersistence()
            self:RefreshConditionalRuntimeObservers()
            return false
        end

        attempt.conditionClosed = true
        attempt.conditionClosedAtMs = tonumber(context.eventTimeMs)
            or GetGameTimeMilliseconds()
        RecountMinimumEmitterDeaths(encounter, attempt)
        attempt.conditionOpen = false
        attempt.conditionSnapshotTaken = true
        attempt.conditionSnapshotAtMs = attempt.conditionClosedAtMs
        attempt.conditionSnapshotCount = attempt.conditionCount or 0
        attempt.conditionSnapshotPositiveEvidence =
            attempt.conditionPositiveEvidence == true
        self:TouchActiveRunPersistence()
        self:RefreshConditionalRuntimeObservers()
        return true
    end,
    isSatisfied = function(_, encounter, attempt)
        local minimum = math.max(0, tonumber(encounter.criterion.minimum) or 0)
        return attempt.conditionArmed == true
            and attempt.conditionEngaged == true
            and attempt.conditionSnapshotTaken == true
            and attempt.conditionObserverVerified == true
            and attempt.conditionFailed ~= true
            and attempt.conditionContinuityBroken ~= true
            and (attempt.conditionSnapshotPositiveEvidence == true
                or (attempt.conditionSnapshotCount or 0) >= minimum)
    end,
}

ConditionalHMResolvers["effect-violation"] = {
    requiresCleanPrepull = true,
    requiresContinuousObservation = true,
    effectObserver = true,
    onEffect = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion
        if attempt.conditionFailed or attempt.conditionContinuityBroken then
            return false
        end
        if criterion.requireBossCombat ~= false
            and not self:IsConditionalHardModeEncounterEngaged(encounter, attempt) then
            return false
        end

        -- Some conditional mechanics have names that collide with ordinary player
        -- abilities. In those cases semantic text is descriptive only; scoring may
        -- fail the HM only from an exact, previously verified ability ID.
        if criterion.requireVerifiedAbilityId == true then
            if self:IsConditionalAbilityIdMatch(context.abilityId, criterion.effectAbilityIds) then
                attempt.conditionObserverVerified = true
                return MarkConditionalFailure(self, encounter, attempt, encounterKey, "forbidden-effect-gained", {
                    effectName = context.effectName,
                    abilityId = context.abilityId,
                    unitTag = context.unitTag,
                    unitName = context.unitName,
                })
            end

            return false
        end

        if not self:IsConditionalAbilityMatch(context.abilityId, context.effectName,
            criterion.effectAbilityIds, criterion.effectNames, criterion.effectNameContainsAny) then
            return false
        end

        attempt.conditionObserverVerified = true
        return MarkConditionalFailure(self, encounter, attempt, encounterKey, "forbidden-effect-gained", {
            effectName = context.effectName,
            abilityId = context.abilityId,
            unitTag = context.unitTag,
            unitName = context.unitName,
        })
    end,
    isSatisfied = function(_, encounter, attempt)
        local criterion = encounter.criterion or {}
        local proofReady = criterion.assumeCleanUntilViolation == true
            or attempt.conditionObserverVerified == true
        return attempt.conditionArmed == true
            and proofReady
            and attempt.conditionFailed ~= true
            and attempt.conditionContinuityBroken ~= true
    end,
}

ConditionalHMResolvers["positive-mechanic-evidence"] = {
    -- Positive-evidence HM for encounters whose HM activation does not alter boss
    -- health. The condition latches only from an exact configured combat/effect
    -- ability ID or an explicitly named activation object death.
    requiresCleanPrepull = true,
    allowPreEngagementDeath = true,
    allowPreArmDeath = true,
    stopObserversWhenSatisfied = true,
    combatObserver = true,
    effectObserver = true,
    onCombat = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion or {}
        if attempt.conditionSatisfied then
            return false
        end
        if criterion.requireBossCombat ~= false
            and not self:IsConditionalHardModeEncounterEngaged(encounter, attempt) then
            return false
        end

        if self:IsConditionalAbilityIdMatch(context.abilityId, criterion.combatAbilityIds) then
            attempt.conditionSatisfied = true
            attempt.conditionObserverVerified = true
            self:TouchActiveRunPersistence()
            return true
        end

        return false
    end,
    onEffect = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion or {}
        if attempt.conditionSatisfied then
            return false
        end
        if criterion.requireBossCombat ~= false
            and not self:IsConditionalHardModeEncounterEngaged(encounter, attempt) then
            return false
        end

        if self:IsConditionalAbilityIdMatch(context.abilityId, criterion.effectAbilityIds) then
            attempt.conditionSatisfied = true
            attempt.conditionObserverVerified = true
            self:TouchActiveRunPersistence()
            return true
        end

        return false
    end,
    onDeath = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion or {}
        if attempt.conditionSatisfied then
            return false
        end
        if not Scoring:ConditionalTextMatches(context.targetName, criterion.activationNames, criterion.activationNameContainsAny) then
            return false
        end
        if not attempt.conditionArmed then
            attempt.conditionArmed = true
            attempt.conditionFailed = false
            attempt.conditionCount = 0
            attempt.conditionDeaths = attempt.conditionDeaths or {}
            attempt.conditionAliveEntities = {}
            attempt.conditionDeadEntities = {}
            attempt.conditionOpen = false
            attempt.conditionSnapshotTaken = false
            attempt.conditionContinuityBroken = false
            attempt.conditionEngaged = false
            attempt.conditionArmedAtMs = GetGameTimeMilliseconds()
        end
        attempt.conditionSatisfied = true
        attempt.conditionObserverVerified = true
        self:TouchActiveRunPersistence()
        return true
    end,
    isSatisfied = function(_, _, attempt)
        return attempt.conditionArmed == true and attempt.conditionSatisfied == true
    end,
}

ConditionalHMResolvers["minimum-live-at-terminal-death"] = {
    -- Dynamic live-state gate. Tracked NPCs are admitted only by positive combat
    -- participation, removed by confirmed death, and the threshold may open,
    -- close, and reopen any number of times before the terminal boss dies.
    requiresCleanPrepull = true,
    requiresContinuousObservation = true,
    recoverLiveStateAfterReload = true,
    combatObserver = true,
    onCombat = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion or {}
        if attempt.conditionSnapshotTaken then
            return false
        end
        if criterion.requireBossCombat ~= false
            and not self:IsConditionalHardModeEncounterEngaged(encounter, attempt) then
            return false
        end

        local changed = false
        local function updateOpenState()
            local aliveCount = CountKeys(attempt.conditionAliveEntities)
            local required = math.max(0, tonumber(criterion.minimumAlive) or 0)
            local oldOpen = attempt.conditionOpen == true
            local newOpen = aliveCount >= required
            attempt.conditionOpen = newOpen
            attempt.conditionCount = aliveCount
            attempt.conditionSatisfied = newOpen
            if oldOpen ~= newOpen then
                changed = true
            end
        end

        local name, unitId = GetTrackedHostileParticipant(criterion, context)
        if name and unitId then
            local key = tostring(unitId)
            if not attempt.conditionDeadEntities[key] and not attempt.conditionAliveEntities[key] then
                attempt.conditionAliveEntities[key] = NormalizeName(name)
                changed = true
                updateOpenState()
            end
        end

        if changed then
            self:TouchActiveRunPersistence()
        end
        return changed
    end,
    onDeath = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion or {}
        if attempt.conditionSnapshotTaken then
            return false
        end

        local function updateOpenState()
            local aliveCount = CountKeys(attempt.conditionAliveEntities)
            local required = math.max(0, tonumber(criterion.minimumAlive) or 0)
            local newOpen = aliveCount >= required
            attempt.conditionOpen = newOpen
            attempt.conditionCount = aliveCount
            attempt.conditionSatisfied = newOpen
        end

        if CriterionNameMatches(criterion, context.targetName, "trackedNames", "trackedNameContainsAny")
            and context.targetUnitId and context.targetUnitId ~= 0 then
            local key = tostring(context.targetUnitId)
            local oldName = attempt.conditionAliveEntities[key]
            if oldName then
                attempt.conditionAliveEntities[key] = nil
                attempt.conditionDeadEntities[key] = oldName
                updateOpenState()
                self:TouchActiveRunPersistence()
                return true
            end
            return false
        end

        if Scoring:ConditionalTextMatches(context.targetName, encounter.members, nil) then
            local aliveCount = CountKeys(attempt.conditionAliveEntities)
            local required = math.max(0, tonumber(criterion.minimumAlive) or 0)
            attempt.conditionSnapshotTaken = true
            attempt.conditionSnapshotAtMs = context.eventTimeMs or GetGameTimeMilliseconds()
            attempt.conditionSnapshotCount = aliveCount
            attempt.conditionSatisfied = attempt.conditionOpen == true and aliveCount >= required
            self:TouchActiveRunPersistence()
            return true
        end

        return false
    end,
    isSatisfied = function(_, _, attempt)
        return attempt.conditionArmed == true
            and attempt.conditionSnapshotTaken == true
            and attempt.conditionSatisfied == true
            and attempt.conditionContinuityBroken ~= true
    end,
}

ConditionalHMResolvers["snapshot-alive"] = {
    requiresCleanPrepull = true,
    requiresContinuousObservation = true,
    combatObserver = true,
    onCombat = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion
        if attempt.conditionSnapshotTaken or attempt.conditionContinuityBroken then
            return false
        end
        if criterion.requireBossCombat ~= false
            and not self:IsConditionalHardModeEncounterEngaged(encounter, attempt) then
            return false
        end

        local changed = false
        local name, unitId = GetTrackedHostileParticipant(criterion, context)
        if name and unitId then
            local key = tostring(unitId)
            if not attempt.conditionDeadEntities[key] and not attempt.conditionAliveEntities[key] then
                attempt.conditionAliveEntities[key] = NormalizeName(name)
                changed = true
            end
        end

        local sourceMatches = true
        if type(criterion.triggerSourceNames) == "table" then
            sourceMatches = Scoring:ConditionalTextMatches(context.sourceName, criterion.triggerSourceNames, nil)
        end
        local triggerMatches = sourceMatches and self:IsConditionalAbilityMatch(
            context.abilityId,
            context.abilityName,
            criterion.triggerAbilityIds,
            criterion.triggerAbilityNames,
            criterion.triggerAbilityNameContainsAny)

        if triggerMatches then
            local aliveCount = CountKeys(attempt.conditionAliveEntities)
            local required = math.max(0, tonumber(criterion.minimumAlive) or 0)
            attempt.conditionSnapshotTaken = true
            attempt.conditionSnapshotAtMs = GetGameTimeMilliseconds()
            attempt.conditionSnapshotCount = aliveCount
            attempt.conditionSatisfied = aliveCount >= required
            changed = true
        end

        if changed then
            self:TouchActiveRunPersistence()
        end
        return changed
    end,
    onDeath = function(self, encounter, attempt, encounterKey, context)
        local criterion = encounter.criterion
        if attempt.conditionSnapshotTaken then
            return false
        end
        if not CriterionNameMatches(criterion, context.targetName, "trackedNames", "trackedNameContainsAny") then
            return false
        end
        if not context.targetUnitId or context.targetUnitId == 0 then
            return false
        end
        local key = tostring(context.targetUnitId)
        local oldName = attempt.conditionAliveEntities[key]
        if not oldName then
            return false
        end
        attempt.conditionAliveEntities[key] = nil
        attempt.conditionDeadEntities[key] = oldName
        self:TouchActiveRunPersistence()
        return true
    end,
    isSatisfied = function(_, _, attempt)
        return attempt.conditionArmed == true
            and attempt.conditionSnapshotTaken == true
            and attempt.conditionSatisfied == true
    end,
}

