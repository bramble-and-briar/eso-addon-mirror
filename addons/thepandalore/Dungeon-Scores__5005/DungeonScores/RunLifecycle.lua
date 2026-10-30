DungeonScores = DungeonScores or {}

-- Run creation, persistence, completion snapshots, integrity state, and finalization.

local DS = DungeonScores
local Diagnostics = DS.Diagnostics
local Scoring = DS.Scoring
local Data = DS.Data
local History = DS.History

local NormalizeName = DS.Util.NormalizeName
local IsAuthoritativeCompletionReason = DS.Util.IsAuthoritativeCompletionReason
local DeepCopy = DS.Util.DeepCopy
local FormatDurationMs = DS.Util.FormatDurationMs
local FormatString = DS.Util.FormatString

local function NormalizeRunId(value)
    local runId = tonumber(value)
    if not runId or runId < 1 or runId ~= math.floor(runId) then
        return nil
    end
    return runId
end

local function NormalizePartySize(value)
    local maximumSize = Data.ELIGIBILITY and Data.ELIGIBILITY.maxGroupSize or 4
    local size = math.floor(tonumber(value) or 1)
    return math.max(1, math.min(maximumSize, size))
end

local CURRENT_RUN_TABLE_FIELDS = {
    "activeBosses",
    "seenBossNames",
    "groupDeathState",
    "groupMembers",
    "hmCreditedBossNames",
    "hardModeEncounterAttempts",
    "encounterEvidence",
    "bossDeathState",
    "terminalBossDeathEvidence",
    "reconciledBossKills",
    "bossEncounterLedger",
    "partySizeDurationsMs",
}

local function IsCurrentRunShape(run)
    -- Preserve eligible open runs across these compatible beta incrementals.
    -- A pre-0.5.21 run starts with no companion evidence, then samples on resume.
    local compatibleEarlierRun = type(run) == "table" and
        ((DS.VERSION == "0.5.19" and run.runtimeVersion == "0.5.18")
        or (DS.VERSION == "0.5.20"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"))
        or (DS.VERSION == "0.5.21"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20"))
        or (DS.VERSION == "0.5.22"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"))
        or (DS.VERSION == "0.5.23"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22"))
        or (DS.VERSION == "0.5.24"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"))
        or (DS.VERSION == "0.5.25"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24"))
        or (DS.VERSION == "0.5.26"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"))
        or (DS.VERSION == "0.5.27"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26"))
        or (DS.VERSION == "0.5.28"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"))
        or (DS.VERSION == "0.5.29"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"
                or run.runtimeVersion == "0.5.28"))
        or (DS.VERSION == "0.5.30"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"
                or run.runtimeVersion == "0.5.28" or run.runtimeVersion == "0.5.29"))
        or (DS.VERSION == "0.5.31"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"
                or run.runtimeVersion == "0.5.28" or run.runtimeVersion == "0.5.29"
                or run.runtimeVersion == "0.5.30"))
        or (DS.VERSION == "0.5.32"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"
                or run.runtimeVersion == "0.5.28" or run.runtimeVersion == "0.5.29"
                or run.runtimeVersion == "0.5.30" or run.runtimeVersion == "0.5.31"))
        or (DS.VERSION == "0.5.33"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"
                or run.runtimeVersion == "0.5.28" or run.runtimeVersion == "0.5.29"
                or run.runtimeVersion == "0.5.30" or run.runtimeVersion == "0.5.31"
                or run.runtimeVersion == "0.5.32"))
        or (DS.VERSION == "0.5.34"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"
                or run.runtimeVersion == "0.5.28" or run.runtimeVersion == "0.5.29"
                or run.runtimeVersion == "0.5.30" or run.runtimeVersion == "0.5.31"
                or run.runtimeVersion == "0.5.32" or run.runtimeVersion == "0.5.33"))
        or (DS.VERSION == "0.5.35"
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"
                or run.runtimeVersion == "0.5.28" or run.runtimeVersion == "0.5.29"
                or run.runtimeVersion == "0.5.30" or run.runtimeVersion == "0.5.31"
                or run.runtimeVersion == "0.5.32" or run.runtimeVersion == "0.5.33"
                or run.runtimeVersion == "0.5.34"))
        or ((DS.VERSION == "0.5.36" or DS.VERSION == "0.5.37")
            and (run.runtimeVersion == "0.5.18" or run.runtimeVersion == "0.5.19"
                or run.runtimeVersion == "0.5.20" or run.runtimeVersion == "0.5.21"
                or run.runtimeVersion == "0.5.22" or run.runtimeVersion == "0.5.23"
                or run.runtimeVersion == "0.5.24" or run.runtimeVersion == "0.5.25"
                or run.runtimeVersion == "0.5.26" or run.runtimeVersion == "0.5.27"
                or run.runtimeVersion == "0.5.28" or run.runtimeVersion == "0.5.29"
                or run.runtimeVersion == "0.5.30" or run.runtimeVersion == "0.5.31"
                or run.runtimeVersion == "0.5.32" or run.runtimeVersion == "0.5.33"
                or run.runtimeVersion == "0.5.34" or run.runtimeVersion == "0.5.35"
                or run.runtimeVersion == "0.5.36"))
        )
    if type(run) ~= "table" or run.finalized
        or (run.runtimeVersion ~= DS.VERSION and not compatibleEarlierRun) then
        return false
    end
    if not NormalizeRunId(run.runId)
        or type(run.generation) ~= "number" or type(run.zoneId) ~= "number" then
        return false
    end
    for _, field in ipairs(CURRENT_RUN_TABLE_FIELDS) do
        if type(run[field]) ~= "table" then
            return false
        end
    end
    local finalAttempt = run.finalEncounterAttempt
    return type(finalAttempt) == "table"
        and type(finalAttempt.deaths) == "table"
        and type(finalAttempt.hmMembers) == "table"
end

function DS:AllocateRunId()
    local nextRunId = NormalizeRunId(self.saved and self.saved.nextRunId) or 0
    nextRunId = nextRunId + 1
    self.saved.nextRunId = nextRunId
    return nextRunId
end

-- Coalesce retained personal bests without rescoring history or inventing a
-- party division for old rows which did not record one. Equal-score local PBs
-- retain their existing snapshot, matching PreserveHighScore's tie rule.
function DS:InitializeScoreHistoryState()
    if not self.saved then
        return
    end

    self.saved.highScores = self.saved.highScores or {}
    self.saved.highScoresByParty = self.saved.highScoresByParty or {}
    local candidates = {}
    local function Remember(settlement, wasPersonalBest)
        if type(settlement) ~= "table"
            or settlement.competitiveEligible == false
            or settlement.runOutcome == "abandoned"
            or settlement.scoreSessionOpen == true
            or (not wasPersonalBest and (settlement.competitiveEligible ~= true
                or settlement.scoreSessionOpen ~= false
                or settlement.finalizeReason == "orphaned-open-entry-closed"
                or tostring(settlement.finalizeReason or ""):find("completed-entry-closed", 1, true))) then
            return
        end
        local zoneId = tonumber(settlement.zoneId)
        local finalScore = tonumber(settlement.finalScore)
        if not zoneId or finalScore == nil then
            return
        end
        local current = self.saved.highScores[zoneId]
        if not current or finalScore > (tonumber(current.finalScore) or -math.huge) then
            self.saved.highScores[zoneId] = DeepCopy(settlement)
        end
        self:PreserveHighScore(settlement)
    end
    -- Gather first: do not mutate a table while enumerating its original PBs.
    for _, settlement in pairs(self.saved.highScores) do
        candidates[#candidates + 1] = settlement
    end
    for _, bySize in pairs(self.saved.highScoresByParty) do
        for _, settlement in pairs(type(bySize) == "table" and bySize or {}) do
            candidates[#candidates + 1] = settlement
        end
    end
    for _, archived in pairs(self.saved.legacyHighScoresByEpoch or {}) do
        for _, settlement in pairs(type(archived) == "table" and archived or {}) do
            candidates[#candidates + 1] = settlement
        end
    end
    for _, settlement in ipairs(candidates) do
        Remember(settlement, true)
    end
    for _, settlement in ipairs(self.saved.history or {}) do
        Remember(settlement, false)
    end
    local seen = {}
    local function RemoveRetiredFields(value)
        if type(value) ~= "table" or seen[value] then return end
        seen[value] = true
        value.scoringEpoch = nil
        value.legacyHighScoresByEpoch = nil
        for _, item in pairs(value) do RemoveRetiredFields(item) end
    end
    RemoveRetiredFields(self.saved)
    if IsCurrentRunShape(self.saved.activeRun) then
        local active = self.saved.activeRun
        if active.completionAchieved == true
            and not active.scoreCapturedAddonVersion then
            active.scoreCapturedAddonVersion = active.runtimeVersion
        end
        if tonumber(active.zoneId) == 933 and active.runtimeVersion ~= self.VERSION then
            -- Wayrest II now uses the alternate whole-run speed path. Preserve
            -- an in-progress timer and boss accounting across this update, but
            -- never carry an old conditional HM credit into the new score.
            active.hmBossKills = 0
            active.hmScore = 0
            active.completionHmBossKills = active.completionAchieved and 0 or nil
            active.hmCreditedBossNames = {}
            active.hmAbandonmentEvidence = {}
            active.hardModeEncounterAttempts = {}
            if type(active.finalEncounterAttempt) == "table" then
                active.finalEncounterAttempt.hmObserved = false
                active.finalEncounterAttempt.hmMembers = {}
            end
            if active.completionAchieved == true then
                active.scoreCapturedAddonVersion = self.VERSION
            end
            active.lastOpenSettlementInputSignature = nil
        end
        self.saved.activeRun.runtimeVersion = self.VERSION
    end
end

local function LegacyOpenSettlementMatchesRun(settlement, run)
    return type(settlement) == "table"
        and settlement.scoreSessionOpen == true
        and settlement.runId == nil
        and settlement.zoneId == run.zoneId
        and settlement.runGeneration == run.generation
        and settlement.startedAtTimeStamp == run.startedAtTimeStamp
        and settlement.completedAtTimeStamp == run.completedAtTimeStamp
end

function DS:InitializeRunIdentityState()
    if not self.saved then
        return
    end

    self.saved.history = self.saved.history or {}
    local activeRun = type(self.saved.activeRun) == "table" and self.saved.activeRun or nil
    local highestRunId = NormalizeRunId(self.saved.nextRunId) or 0
    if activeRun then
        highestRunId = math.max(highestRunId, NormalizeRunId(activeRun.runId) or 0)
    end
    for _, settlement in ipairs(self.saved.history) do
        if type(settlement) == "table" then
            highestRunId = math.max(highestRunId, NormalizeRunId(settlement.runId) or 0)
        end
    end
    for _, settlement in pairs(self.saved.highScores or {}) do
        if type(settlement) == "table" then
            highestRunId = math.max(highestRunId, NormalizeRunId(settlement.runId) or 0)
        end
    end
    for _, bySize in pairs(self.saved.highScoresByParty or {}) do
        if type(bySize) == "table" then
            for _, settlement in pairs(bySize) do
                if type(settlement) == "table" then
                    highestRunId = math.max(highestRunId, NormalizeRunId(settlement.runId) or 0)
                end
            end
        end
    end
    for _, snapshot in ipairs(self.saved.betaRunSnapshots or {}) do
        if type(snapshot) == "table" then
            highestRunId = math.max(highestRunId, NormalizeRunId(snapshot.runId) or 0)
        end
    end
    self.saved.nextRunId = highestRunId

    if activeRun and not NormalizeRunId(activeRun.runId) then
        activeRun.runId = self:AllocateRunId()
    end

    local activeRunId = activeRun and NormalizeRunId(activeRun.runId) or nil
    local activeCanOwnOpenSettlement = activeRunId ~= nil
        and activeRun.finalized ~= true
        and activeRun.completionAchieved == true
        and activeRun.scoreSessionOpen ~= false
    local activeOwnedIndex = nil
    if activeCanOwnOpenSettlement then
        local indexed = tonumber(activeRun.openSettlementHistoryIndex)
        local indexedSettlement = indexed and self.saved.history[indexed] or nil
        if type(indexedSettlement) == "table"
            and indexedSettlement.scoreSessionOpen == true
            and NormalizeRunId(indexedSettlement.runId) == activeRunId then
            activeOwnedIndex = indexed
        else
            for index, settlement in ipairs(self.saved.history) do
                if type(settlement) == "table"
                    and settlement.scoreSessionOpen == true
                    and NormalizeRunId(settlement.runId) == activeRunId then
                    activeOwnedIndex = index
                end
            end
        end
    end
    local legacyMatchIndex = nil
    local legacyMatchCount = 0
    if activeCanOwnOpenSettlement then
        for index, settlement in ipairs(self.saved.history) do
            if LegacyOpenSettlementMatchesRun(settlement, activeRun) then
                legacyMatchIndex = index
                legacyMatchCount = legacyMatchCount + 1
            end
        end
    end

    local nowTimeStamp = GetTimeStamp()
    for index, settlement in ipairs(self.saved.history) do
        if type(settlement) == "table" and settlement.scoreSessionOpen == true then
            local settlementRunId = NormalizeRunId(settlement.runId)
            local ownedByActiveRun = activeCanOwnOpenSettlement
                and settlementRunId ~= nil
                and settlementRunId == activeRunId
                and activeOwnedIndex == index
            local uniqueLegacyMatch = activeCanOwnOpenSettlement
                and activeOwnedIndex == nil
                and settlementRunId == nil
                and legacyMatchCount == 1
                and legacyMatchIndex == index
            if uniqueLegacyMatch then
                settlement.runId = activeRunId
                activeRun.openSettlementHistoryIndex = index
            elseif ownedByActiveRun then
                activeRun.openSettlementHistoryIndex = index
            elseif not ownedByActiveRun then
                -- Pre-ID or orphaned open rows remain valid historical snapshots,
                -- but they are closed permanently and can never be reused by a
                -- later run. No PB/high-score promotion occurs during migration.
                settlement.scoreSessionOpen = false
                settlement.finalizedAtTimeStamp = settlement.finalizedAtTimeStamp
                    or settlement.completedAtTimeStamp or nowTimeStamp
                settlement.finalizeReason = settlement.finalizeReason
                    or "orphaned-open-entry-closed"
            end
        end
    end
end

function DS:RemoveOpenSettlementForRun(run)
    if not self.saved or type(run) ~= "table" then
        return false
    end
    local runId = NormalizeRunId(run.runId)
    if not runId then
        return false
    end

    local removed = false
    for index = #(self.saved.history or {}), 1, -1 do
        local settlement = self.saved.history[index]
        if type(settlement) == "table"
            and settlement.scoreSessionOpen == true
            and NormalizeRunId(settlement.runId) == runId then
            table.remove(self.saved.history, index)
            removed = true
        end
    end
    run.openSettlementHistoryIndex = nil
    if removed and History and History.OnRunFinalized then
        History:OnRunFinalized()
    end
    return removed
end

function DS:CloseCompletedSettlementForRun(run, reason)
    if not self.saved or type(run) ~= "table"
        or run.completionAchieved ~= true or run.scoreSessionOpen == false then
        return false
    end
    local runId = NormalizeRunId(run.runId)
    if not runId then
        return false
    end

    local closed = false
    local nowTimeStamp = GetTimeStamp()
    for _, settlement in ipairs(self.saved.history or {}) do
        if type(settlement) == "table"
            and settlement.scoreSessionOpen == true
            and NormalizeRunId(settlement.runId) == runId then
            -- The saved settlement is already the authoritative completion
            -- snapshot. If obsolete or stale live state cannot be resumed safely,
            -- retain that score but do not rebuild it or promote it as a PB.
            settlement.scoreSessionOpen = false
            settlement.finalizedAtTimeStamp = settlement.finalizedAtTimeStamp
                or settlement.completedAtTimeStamp or nowTimeStamp
            settlement.finalizeReason = settlement.finalizeReason
                or reason or "unrestorable-completed-entry-closed"
            closed = true
        end
    end
    run.scoreSessionOpen = false
    run.openSettlementHistoryIndex = nil
    if closed and History and History.OnRunFinalized then
        History:OnRunFinalized()
    end
    return closed
end

function DS:DiscardUnrestorableRun(run, reason)
    if not self:CloseCompletedSettlementForRun(run, reason) then
        self:RemoveOpenSettlementForRun(run)
    end
    if self.saved then
        self.saved.activeRun = nil
    end
end

-- A numeric terminal candidate is separately verifiable from retained
-- run-local boss identities and direct death transitions. It remains provisional
-- during the grace interval (and may be canceled on a revive), but a confirmed
-- session boundary must not discard its verified completion evidence.
function DS:IsVerifiedNumericTerminalCandidate(run)
    if type(run) ~= "table" or run.completionCandidateAtMs == nil
        or run.completionCandidateReason ~= "numeric-terminal-cohort"
        or type(run.startedAtMs) ~= "number"
        or type(run.completedAtMs) ~= "number"
        or run.completedAtMs < run.startedAtMs then
        return false
    end
    local config = Data.NUMERIC_TERMINAL_COHORTS
        and Data.NUMERIC_TERMINAL_COHORTS[tonumber(run.zoneId)]
    local cohort = run.numericTerminalCohort
    if not config or type(cohort) ~= "table"
        or type(cohort.identities) ~= "table" or type(cohort.deaths) ~= "table"
        or config.maxHealth[tonumber(cohort.maxHealth)] ~= true then
        return false
    end
    local count = 0
    for identityId, enabled in pairs(cohort.identities) do
        if enabled ~= true or not cohort.deaths[identityId] then
            return false
        end
        count = count + 1
    end
    return count == tonumber(config.required)
end

function DS:ResolveRunBeforeReplacement(reason)
    local run = self.run
    if not run or run.finalized then
        return true
    end

    if not run.completionAchieved and self:IsVerifiedNumericTerminalCandidate(run) then
        self:CheckPendingHardModeEncounterCredits(GetGameTimeMilliseconds())
        self:OpenCompletionSnapshot(run.completionCandidateReason)
    end
    if run.completionAchieved
        and self:FinalizeRun(reason or "run-replaced") then
        return true
    end
    if run.startedAtMs and self:FinalizeAbandonedRun(reason or "run-replaced") then
        return true
    end

    -- An unstarted run should not own a settlement, but remove an exact-ID
    -- open row if corrupt or interrupted state left one behind.
    self:RemoveOpenSettlementForRun(run)
    if self.saved and self.saved.activeRun == run then
        self.saved.activeRun = nil
    end
    return false
end

-- Changing grouped dungeon difficulty away from Veteran is a terminal
-- boundary for the old instance, not a deferred action when porting back.
-- Only an already-completed run, an authoritative official completion,
-- or a directly verified numeric terminal cohort can produce a settlement.
-- Every other interrupted attempt is abandoned.
function DS:EndRunForGroupDifficultyReset(exitedZoneId)
    local run = self.run
    if not run or run.finalized or tonumber(run.zoneId) ~= tonumber(exitedZoneId)
        or IsUnitInDungeon("player") then
        return false
    end

    -- A verified numeric death cohort is stronger than a generic provisional
    -- candidate. Preserve it even when the player resets the group difficulty
    -- during its ordinary 1-second grace window, but never promote a merely
    -- observed boss set or an arbitrary unverified candidate.
    if not run.completionAchieved and run.completionCandidateAtMs
        and (run.completionCandidateAuthoritative == true
            or self:IsVerifiedNumericTerminalCandidate(run)) then
        self:CheckPendingHardModeEncounterCredits(GetGameTimeMilliseconds())
        self:OpenCompletionSnapshot(run.completionCandidateReason or "group-difficulty-reset")
    end

    if run.completionAchieved then
        -- Keep the exact run ID and finalized settlement in history. An earlier
        -- zone-exit finalization is idempotent, because finalized runs return
        -- above and are never settled twice.
        return self:FinalizeRun("group-difficulty-reset") ~= nil
    end

    -- A difficulty reset is a definitive termination. Keep the negative
    -- local settlement, without claiming that the final boss was defeated.
    if run.startedAtMs then
        return self:FinalizeAbandonedRun("group-difficulty-reset") ~= nil
    end
    self:CancelQueuedBossRefresh()
    self:StopConditionalRuntimeObservers()
    self:StopPulse()
    self:RemoveOpenSettlementForRun(run)
    if self.saved then
        self.saved.activeRun = nil
    end
    self.run = nil
    self:RefreshHud()
    return true
end

function DS:PreserveHighScore(settlement)
    if not self.saved or type(settlement) ~= "table" then
        return false
    end
    if settlement.competitiveEligible == false then
        return false
    end

    local zoneId = tonumber(settlement.zoneId)
    local score = tonumber(settlement.finalScore)
    if not zoneId or score == nil then
        return false
    end

    local groupSize = tonumber(settlement.runGroupSize)
    if not groupSize or groupSize ~= math.floor(groupSize)
        or groupSize < 1 or groupSize > 4 then
        return false
    end

    self.saved.highScores = self.saved.highScores or {}
    self.saved.highScoresByParty = self.saved.highScoresByParty or {}
    local bySize = self.saved.highScoresByParty[zoneId] or {}
    self.saved.highScoresByParty[zoneId] = bySize
    local currentParty = bySize[groupSize]
    local partyImproved = not currentParty
        or score > (tonumber(currentParty.finalScore) or -math.huge)
    if partyImproved then
        bySize[groupSize] = DeepCopy(settlement)
    end

    local current = self.saved.highScores[zoneId]
    local currentScore = current and tonumber(current.finalScore) or nil
    local overallImproved = currentScore == nil or score > currentScore
    if overallImproved then
        self.saved.highScores[zoneId] = DeepCopy(settlement)
    end

    return partyImproved or overallImproved
end

function DS:GetCurrentZoneInfo()
    local zoneId = select(1, GetUnitWorldPosition("player")) or 0
    local zoneName = zoneId > 0 and GetZoneNameById(zoneId) or GetUnitZone("player")
    local difficulty = GetCurrentZoneDungeonDifficulty()
    local isVeteran = difficulty == DUNGEON_DIFFICULTY_VETERAN
    local inDungeon = IsUnitInDungeon("player")
    return zoneId, zoneName, isVeteran, inDungeon
end

function DS:GetEligibility()
    local zoneId, zoneName, isVeteran, inDungeon = self:GetCurrentZoneInfo()
    local groupSize = GetGroupSize() or 0
    local eligibility = Data.ELIGIBILITY or {}
    local maxGroupSize = eligibility.maxGroupSize or 4
    local excludedZoneIds = eligibility.excludedZoneIds or {}
    local excludedActivity = excludedZoneIds[zoneId]

    if not inDungeon then
        return false, "not-dungeon", zoneId, zoneName, groupSize
    end

    if excludedActivity then
        return false, "excluded:" .. tostring(excludedActivity), zoneId, zoneName, groupSize
    end

    -- IsUnitInDungeon() is true in trial instances as well as four-player
    -- dungeons. Only zones with an explicit scoring configuration may arm the
    -- addon; adding future solo dungeons remains a data-only configuration step.
    local configuredZones = Data.ZONES or {}
    if type(configuredZones[tonumber(zoneId)]) ~= "table" then
        return false, "unsupported-zone", zoneId, zoneName, groupSize
    end

    if not isVeteran then
        return false, "not-veteran", zoneId, zoneName, groupSize
    end

    if groupSize > maxGroupSize then
        return false, "group-too-large", zoneId, zoneName, groupSize
    end

    return true, "eligible", zoneId, zoneName, groupSize
end

function DS:InvalidateEligibilityCache()
    self.eligibilityCache = nil
end

function DS:RefreshEligibilityCache()
    local eligible, reason, zoneId, zoneName, groupSize = self:GetEligibility()
    self.eligibilityCache = { eligible = eligible == true }
    return eligible, reason, zoneId, zoneName, groupSize
end

function DS:IsArmed()
    -- During /reloadui or a loading transition, do not let combat/death callbacks
    -- create or extend a run before PLAYER_ACTIVATED revalidates the instance.
    if self.pendingActiveRunRestore or self.pendingFrozenZoneCheck or self.playerDeactivated
        or self.sessionTrackingSuppressed
        or (self.run and self.run.zoneExitSuspended == true) then
        return false
    end

    -- Eligibility is stable while the player remains activated in one instance.
    -- Refresh it only on activation/group changes instead of re-querying multiple
    -- zone/dungeon APIs on every boss-health or death event.
    if self.eligibilityCache then
        return self.eligibilityCache.eligible == true
    end
    return select(1, self:RefreshEligibilityCache())
end

-- Only lifecycle transitions enter this small support trace; combat events and
-- player identities never do. It persists with the active run and BETA snapshot.
function DS:RecordLifecycleTransition(kind, reason)
    local run = self.run
    if not run or run.finalized then
        return
    end
    local trace = run.lifecycleTrace or {}
    run.lifecycleTrace = trace
    trace[#trace + 1] = {
        at = GetTimeStamp(),
        kind = kind,
        reason = reason,
        zoneId = run.zoneId,
    }
    if #trace > 20 then
        table.remove(trace, 1)
    end
end

function DS:NewRun(allowActiveSameZoneReplacement, trigger)
    local active = self.run
    if allowActiveSameZoneReplacement ~= true and active and active.startedAtMs
        and not active.finalized and not active.completionAchieved then
        local currentZoneId = tonumber((select(1, self:GetCurrentZoneInfo())))
        if not currentZoneId or currentZoneId <= 0
            or currentZoneId == tonumber(active.zoneId) then
            -- A group member joining, a transient activation, or any other
            -- incidental caller cannot discard an unfinished run in the same
            -- dungeon. Only an explicit reset may bypass this guard.
            self:RecordLifecycleTransition("replacement-blocked", trigger or "unspecified")
            return false
        end
    end
    self:RecordLifecycleTransition("replacement", trigger or "unspecified")
    self:ResolveRunBeforeReplacement("run-replaced")
    self:StopZoneExitTimeout()
    self:StopConditionalRuntimeObservers()
    self:StopPulse()
    self:CancelQueuedBossRefresh()
    self:ResetRoutineDeathDedupe()

    local zoneId, zoneName, isVeteran = self:GetCurrentZoneInfo()
    local eligible, eligibilityReason, _, _, groupSize = self:RefreshEligibilityCache()
    local inLFG = IsInLFGGroup() == true
    local lfgComplete = IsCurrentLFGActivityComplete() == true

    self.runGeneration = (self.runGeneration or 0) + 1
    self.run = {
        runId = self:AllocateRunId(),
        generation = self.runGeneration,
        runtimeVersion = self.VERSION,
        scoreCapturedAddonVersion = nil,
        zoneId = zoneId,
        zoneName = zoneName,
        isVeteran = isVeteran,
        eligible = eligible,
        eligibilityReason = eligibilityReason,
        groupSizeAtReset = groupSize,

        startedAtMs = nil,
        startedAtTimeStamp = nil,
        startReason = nil,
        completedAtMs = nil,
        completedAtTimeStamp = nil,
        abandoned = false,
        companionObserved = false,
        pitstopObserved = false,
        pitstopMemberStates = {},
        abandonedAtMs = nil,
        abandonedAtTimeStamp = nil,
        departureStartedElapsedMs = nil,
        departureStartedAtTimeStamp = nil,
        completionBossName = nil,
        completionAchieved = false,
        completionReason = nil,
        completionDeaths = nil,
        completionHmBossKills = nil,
        bossKillsAtCompletion = nil,
        scoreAtCompletion = nil,
        scoreSessionOpen = false,
        openSettlementHistoryIndex = nil,
        completionCandidateAtMs = nil,
        completionCandidateSetAtMs = nil,
        completionCandidateReason = nil,
        completionCandidateAuthoritative = false,
        completionCandidateDeaths = nil,
        finalizeAfterCompletion = false,
        exitCompletionRecoveryUntilMs = nil,
        lastDeathAtMs = nil,
        lastBossDeathAtMs = nil,
        lastBossDeathName = nil,
        wasLFG = inLFG,
        lfgCompleteState = inLFG and lfgComplete or false,

        uniqueDeaths = 0,
        xpKills = 0,
        noXpDeaths = 0,
        bossKills = 0,
        bossDeathStateCredits = {},
        hmAbandonmentEvidence = {},
        bossEncountersObserved = 0,
        bossEncounterLedger = {},
        activeBossEncounter = nil,
        routeAbilityEvidence = {},
        bossEncountersAtCompletion = nil,
        expectedBossEncountersAtCompletion = Scoring:GetExpectedBossEncountersAtCompletion(zoneId),
        hmBossKills = 0,
        hmCreditedBossNames = {},
        hardModeEncounterAttempts = {},
        hmEvidencePolicyVersion = self.HM_EVIDENCE_POLICY_VERSION,
        encounterEvidence = self.EncounterEvidence:NewLedger(zoneId),
        finalEncounterAttempt = {
            id = 1,
            deaths = {},
            identityDeaths = {},
            hmObserved = false,
            hmMembers = {},
        },
        finalEncounterCompleted = false,
        finalEncounterArmed = false,
        bossDeathState = {},
        terminalBossDeathEvidence = {},
        reconciledBossKills = {},
        bossIdentitySequence = 0,
        competitiveEligible = true,
        integrityStatus = "full",
        integrityReason = nil,
        killScore = 0,
        hmScore = 0,
        deaths = 0,
        activeBosses = {},
        seenBossNames = {},
        groupDeathState = {},
        groupMembers = {},
        groupRosterFingerprint = nil,
        maxConcurrentGroupSize = nil,
        maxConcurrentGroupSizeAtCompletion = nil,
        partyChallengePolicy = "peak-terminal-weighted-10pct",
        terminalEncounterPartySize = nil,
        terminalEncounterPartySizeSource = nil,
        partySizeDurationsMs = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 },
        partySizeDurationsAtCompletion = nil,
        partySizeCurrent = nil,
        partySizeLastAtMs = nil,
        partySizeLastAtTimeStamp = nil,
        restoreCount = 0,
        lifecycleTrace = {},
        finalized = false,

        lastPersistedAtTimeStamp = GetTimeStamp(),
        persistedElapsedMs = nil,
        persistedCompletedElapsedMs = nil,
    }

    self:RefreshRunEncounterLookups()
    self:RecordLifecycleTransition("new-run", trigger or "unspecified")
    self.saved.activeRun = eligible and self.run or nil
    self:CaptureGroupMembers("run-reset")
    -- Fixed-terminal composite encounters use exact ability-ID filters from the
    -- moment an eligible zone run exists. Their numeric emitter evidence may be
    -- observed before boss health resolves the HM cohort.
    self:RefreshConditionalRuntimeObservers()

    self:RefreshBosses()
    self:RefreshHud()
end

function DS:GetGroupMemberIdentity(unitTag)
    if not unitTag or not DoesUnitExist(unitTag) then
        return nil
    end

    local accountName = GetUnitDisplayName(unitTag) or ""
    local characterName = NormalizeName(GetUnitName(unitTag))
    if characterName == "" then
        characterName = unitTag
    end

    local key = accountName ~= "" and accountName or characterName
    if key == "" then
        return nil
    end

    return key, accountName, characterName
end

function DS:FlushPartySizeClock(targetMs, segmentSize)
    local run = self.run
    if not run or run.finalized or not run.startedAtMs then
        return
    end

    local endAtMs = tonumber(targetMs) or GetGameTimeMilliseconds()
    if run.completedAtMs then
        endAtMs = math.min(endAtMs, tonumber(run.completedAtMs) or endAtMs)
    end
    endAtMs = math.max(tonumber(run.startedAtMs) or endAtMs, endAtMs)

    local lastAtMs = tonumber(run.partySizeLastAtMs) or tonumber(run.startedAtMs) or endAtMs
    if endAtMs <= lastAtMs then
        return
    end

    local size = NormalizePartySize(segmentSize or run.partySizeCurrent
        or run.maxConcurrentGroupSize or run.groupSizeAtReset)
    run.partySizeDurationsMs = run.partySizeDurationsMs
        or { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    run.partySizeDurationsMs[size] = (tonumber(run.partySizeDurationsMs[size]) or 0)
        + (endAtMs - lastAtMs)
    run.partySizeLastAtMs = endAtMs
    run.partySizeLastAtTimeStamp = GetTimeStamp()
end

function DS:ObservePartySize(groupSize, reason, observedAtMs)
    local run = self.run
    if not run or run.finalized then
        return
    end

    local observedSize = NormalizePartySize(groupSize)
    if not run.startedAtMs then
        run.partySizeCurrent = observedSize
        return
    end

    local previousSize = NormalizePartySize(run.partySizeCurrent
        or run.maxConcurrentGroupSize or run.groupSizeAtReset)
    local conservativeBoundary = reason == "player-activated" or reason == "reload-restore"
    self:FlushPartySizeClock(
        observedAtMs or GetGameTimeMilliseconds(),
        conservativeBoundary and math.max(previousSize, observedSize) or previousSize)
    run.partySizeCurrent = observedSize
end

function DS:RestorePartySizeClockAfterReload(elapsedMs, completedElapsedMs, nowMs)
    local run = self.run
    if not run or not run.startedAtMs then
        return
    end

    local maximumSize = Data.ELIGIBILITY and Data.ELIGIBILITY.maxGroupSize or 4
    local durations = run.partySizeDurationsMs
    if type(durations) ~= "table" then
        durations = {}
        run.partySizeDurationsMs = durations
    end

    local total = 0
    for size = 1, maximumSize do
        durations[size] = math.max(0, tonumber(durations[size]) or 0)
        total = total + durations[size]
    end

    local targetElapsedMs = tonumber(completedElapsedMs)
        or math.max(0, tonumber(elapsedMs) or 0)
    if targetElapsedMs > total then
        local currentSize = NormalizePartySize(GetGroupSize() or 0)
        local previousSize = NormalizePartySize(run.partySizeCurrent
            or run.maxConcurrentGroupSize or run.groupSizeAtReset)
        local conservativeSize = math.max(previousSize, currentSize)
        durations[conservativeSize] = durations[conservativeSize]
            + (targetElapsedMs - total)
    end

    run.partySizeCurrent = NormalizePartySize(GetGroupSize() or 0)
    run.partySizeLastAtMs = tonumber(nowMs) or GetGameTimeMilliseconds()
    run.partySizeLastAtTimeStamp = GetTimeStamp()
end

function DS:CaptureGroupMembers(reason)
    if not self.run or self.run.finalized then
        return
    end

    self.run.groupMembers = self.run.groupMembers or {}
    local snapshotKeys = {}
    local now = GetTimeStamp()

    local function CaptureUnit(unitTag)
        local key, accountName, characterName = self:GetGroupMemberIdentity(unitTag)
        if not key then
            return
        end

        snapshotKeys[key] = true
        local member = self.run.groupMembers[key]
        if not member then
            member = {
                accountName = accountName,
                characterName = characterName,
                firstSeenAtTimeStamp = now,
            }
            self.run.groupMembers[key] = member
        else
            if accountName ~= "" then
                member.accountName = accountName
            end
            if characterName ~= "" then
                member.characterName = characterName
            end
        end
        member.lastSeenAtTimeStamp = now
    end

    -- GetGroupUnitTagByIndex() does not substitute for the local player tag in
    -- every group state, so capture the player explicitly and deduplicate below.
    CaptureUnit("player")

    local groupSize = GetGroupSize() or 0
    for index = 1, groupSize do
        local unitTag = GetGroupUnitTagByIndex(index)
        if unitTag and DoesUnitExist(unitTag) then
            CaptureUnit(unitTag)
        end
    end

    local orderedKeys = {}
    for key in pairs(snapshotKeys) do
        orderedKeys[#orderedKeys + 1] = key
    end
    table.sort(orderedKeys)
    local fingerprint = table.concat(orderedKeys, "|")

    -- WR composition is intentionally only the maximum simultaneous party size
    -- observed from the universal first-hostile-combat timer onward. Roster
    -- identity and substitutions do not invalidate a run or alter this value.
    if self.run.startedAtMs or reason == "run-start" then
        local concurrentGroupSize = math.max(1, groupSize, #orderedKeys)
        self.run.maxConcurrentGroupSize = math.max(tonumber(self.run.maxConcurrentGroupSize) or 0, concurrentGroupSize)
        self:ObservePartySize(concurrentGroupSize, reason)
        local activeEncounter = self.run.activeBossEncounter
        if type(activeEncounter) == "table" and activeEncounter.engaged == true
            and not self.run.completionCandidateAtMs then
            activeEncounter.maxPartySize = math.max(
                tonumber(activeEncounter.maxPartySize) or 0,
                NormalizePartySize(concurrentGroupSize))
        end
    end

    if fingerprint ~= self.run.groupRosterFingerprint then
        if self.run.startedAtMs then
            self:RecordLifecycleTransition("roster-change", reason or "group-update")
        end
        self.run.groupRosterFingerprint = fingerprint
    end
    return math.max(1, groupSize, #orderedKeys)
end

function DS:TouchActiveRunPersistence()
    if not self.saved or not self.run or self.run.finalized or not self.run.eligible then
        return
    end

    local nowMs = GetGameTimeMilliseconds()
    self:FlushPartySizeClock(nowMs)
    self.run.lastPersistedAtTimeStamp = GetTimeStamp()
    if self.run.startedAtMs then
        self.run.persistedElapsedMs = math.max(0, nowMs - self.run.startedAtMs)
        if self.run.completedAtMs then
            self.run.persistedCompletedElapsedMs = math.max(0, self.run.completedAtMs - self.run.startedAtMs)
        else
            self.run.persistedCompletedElapsedMs = nil
        end
    end

    -- Keep the live run table directly under SavedVariables. ESO serializes the
    -- current table on /reloadui, so counters, death ledgers, HM state, roster,
    -- and completion provenance survive without a separate copy pass.
    self.saved.activeRun = self.run
end

function DS:StopZoneExitTimeout()
    if self.zoneExitTimeoutActive then
        EVENT_MANAGER:UnregisterForUpdate(self.NAME .. "_ZoneExitTimeout")
        self.zoneExitTimeoutActive = false
    end
end

function DS:ExpireSuspendedRunIfNeeded(reason)
    local run = self.run
    if not run or run.finalized or run.zoneExitSuspended ~= true
        or not run.startedAtMs then
        return false
    end
    local exitedAt = tonumber(run.zoneExitSuspendedAtTimeStamp)
        or tonumber(run.departureStartedAtTimeStamp)
    if not exitedAt or GetTimeStamp() - exitedAt < self.ZONE_EXIT_ABANDON_SECONDS then
        return false
    end
    self:StopZoneExitTimeout()
    self:RecordLifecycleTransition("exit-timeout", reason or "outside-240-seconds")
    self:FinalizeSessionOnConfirmedExit("instance-exit-timeout")
    return true
end

function DS:StartZoneExitTimeout()
    local run = self.run
    if not run or run.zoneExitSuspended ~= true or run.finalized then
        return
    end
    self:StopZoneExitTimeout()
    if self:ExpireSuspendedRunIfNeeded("outside-240-seconds") then
        return
    end
    local exitedAt = tonumber(run.zoneExitSuspendedAtTimeStamp) or GetTimeStamp()
    local remainingMs = math.max(1000,
        (self.ZONE_EXIT_ABANDON_SECONDS - math.max(0, GetTimeStamp() - exitedAt)) * 1000)
    self.zoneExitTimeoutActive = true
    EVENT_MANAGER:RegisterForUpdate(self.NAME .. "_ZoneExitTimeout", remainingMs, function()
        self:StopZoneExitTimeout()
        if not self:ExpireSuspendedRunIfNeeded("outside-240-seconds")
            and self.run and self.run.zoneExitSuspended == true then
            self:StartZoneExitTimeout()
        end
    end)
end

function DS:SuspendActiveRunForZoneExit(reason, completionRecoveryUntilMs)
    local run = self.run
    if not run or run.finalized or not run.startedAtMs then
        return false
    end

    -- The official timer continues across the loading boundary. Close the
    -- uncertain interval at the larger before/after composition before the run
    -- is persisted outside the instance; this can only reduce the challenge award.
    self:ObservePartySize(GetGroupSize() or 0, "player-activated")

    -- Leaving for an overland, house, or other non-dungeon zone is not a new run.
    -- Keep the original monotonic timer anchor so the entire port-out interval is
    -- charged when the same veteran dungeon is entered again.
    if run.zoneExitSuspended ~= true then
        run.zoneExitSuspended = true
        run.zoneExitSuspendedAtTimeStamp = run.departureStartedAtTimeStamp or GetTimeStamp()
        run.zoneExitSuspensionReason = reason or "non-dungeon-zone-exit"
        self:RecordLifecycleTransition("suspend", run.zoneExitSuspensionReason)

        -- A loading boundary invalidates event-local NPC IDs and boss unit-tag
        -- latches. Preserve durable encounter/HM conclusions, but fail continuous
        -- conditional evidence closed if the player left during an active attempt.
        self:MarkConditionalObservationGapsAfterReload(run)
        self:ResetTerminalAbilityRuntimeEvidenceAfterReload(run)
        run.activeBosses = {}
        run.bossDeathState = {}
        run.lastDeathAtMs = nil
        run.lastBossDeathAtMs = nil
        self:ResetRoutineDeathDedupe()
        self:RefreshRunEncounterLookups()
    end

    run.exitCompletionRecoveryUntilMs = tonumber(completionRecoveryUntilMs)
    self:StartZoneExitTimeout()
    if run.finalized then
        return true
    end
    self:CancelQueuedBossRefresh()
    self:StopConditionalRuntimeObservers()
    if run.exitCompletionRecoveryUntilMs then
        -- Keep only the lightweight authoritative-completion poll alive during
        -- the bounded LFG recovery window; the pulse callback skips all encounter
        -- sampling while the run is suspended.
        self:StartPulse()
    else
        self:StopPulse()
    end
    self:TouchActiveRunPersistence()
    self:RefreshHud()
    return true
end

function DS:ResumeActiveRunAfterZoneReturn(zoneName)
    local run = self.run
    if not run or run.finalized then
        return false
    end
    if run.zoneExitSuspended == true and self:ExpireSuspendedRunIfNeeded("return-after-240-seconds") then
        return false
    end
    self:StopZoneExitTimeout()

    -- Re-entry into the *same* instance and /reloadui are not departures.
    -- Clear the old loading-screen stamp so a later real exit is charged its
    -- actual duration, rather than reusing an earlier UI reload timestamp.
    run.departureStartedElapsedMs = nil
    run.departureStartedAtTimeStamp = nil
    if run.zoneExitSuspended == true then
        self:RecordLifecycleTransition("resume", "same-dungeon-return")
        run.zoneExitSuspended = nil
        run.zoneExitSuspendedAtTimeStamp = nil
        run.zoneExitSuspensionReason = nil
        run.zoneExitResumeCount = (tonumber(run.zoneExitResumeCount) or 0) + 1
    end
    run.exitCompletionRecoveryUntilMs = nil
    run.zoneName = zoneName or run.zoneName

    self:ResetRoutineDeathDedupe()
    self:RefreshRunEncounterLookups()
    self:CaptureGroupMembers("player-activated")
    self:ClearPitstopObservationGaps()
    self:ObserveCompanionPresence()
    self:ObservePitstopPresence()
    self:RefreshBosses()
    self:RefreshConditionalRuntimeObservers()
    self:TouchActiveRunPersistence()
    if run.startedAtMs then
        self:StartPulse()
    end
    self:RefreshHud()
    return true
end

function DS:TryRestoreActiveRun()
    local run = self.saved and self.saved.activeRun or nil
    local completedRecoveryZoneId = type(run) == "table"
        and run.completionAchieved == true
        and run.scoreSessionOpen ~= false
        and tonumber(run.zoneId) or nil
    if not IsCurrentRunShape(run) then
        if self.saved then
            self:DiscardUnrestorableRun(run, "invalid-completed-entry-closed")
        end
        return false, completedRecoveryZoneId
    end

    local eligible, _, zoneId = self:RefreshEligibilityCache()
    local inDungeon = IsUnitInDungeon("player") == true
    local pendingAuthoritativeCompletion = run.completionCandidateAtMs ~= nil
        and (run.completionCandidateAuthoritative == true or IsAuthoritativeCompletionReason(run.completionCandidateReason))
    local pendingNumericCompletion = self:IsVerifiedNumericTerminalCandidate(run)
    run.completionCandidateAuthoritative = pendingAuthoritativeCompletion == true
    local completedOpenRestore = run.completionAchieved == true and run.scoreSessionOpen ~= false

    -- A queued authoritative completion or completed-but-open score can survive a
    -- loading screen. Outside the original dungeon, restore only long enough to
    -- settle/freeze that already-completed session.
    local completionOnlyRestore = (pendingAuthoritativeCompletion or pendingNumericCompletion or completedOpenRestore)
        and (not eligible or run.zoneId ~= zoneId)
    local outsideFinalizationRestore = run.startedAtTimeStamp ~= nil
        and run.zoneId ~= zoneId and not inDungeon
    local suspendedOutsideRestore = run.zoneExitSuspended == true and not inDungeon
    local differentDungeonRestore = run.startedAtTimeStamp ~= nil
        and run.zoneId ~= zoneId and inDungeon
    if (not eligible or run.zoneId ~= zoneId)
        and not completionOnlyRestore and not suspendedOutsideRestore
        and not outsideFinalizationRestore and not differentDungeonRestore then
        self:DiscardUnrestorableRun(run, "ineligible-completed-entry-closed")
        return false, completedRecoveryZoneId
    end

    local nowTimeStamp = GetTimeStamp()
    local lastPersisted = run.lastPersistedAtTimeStamp or run.startedAtTimeStamp or nowTimeStamp
    if nowTimeStamp - lastPersisted > self.ACTIVE_RUN_RESTORE_MAX_AGE_SECONDS
        and run.zoneExitSuspended ~= true and not outsideFinalizationRestore
        and not differentDungeonRestore then
        self:DiscardUnrestorableRun(run, "stale-completed-entry-closed")
        return false, completedRecoveryZoneId
    end

    -- Unit tags and millisecond event coordinates do not survive /reloadui as
    -- stable identity evidence. Preserve durable run state, but rebuild transient
    -- tag/death latches and timing anchors in the new UI session.
    run.activeBosses = {}
    run.bossDeathState = {}
    -- A death timestamp from the old UI session cannot identify a later boss
    -- fight. A completion candidate already carries its frozen party size.
    run.lastBossFightDeathAtMs = nil
    run.lastBossFightIdentityId = nil
    run.lastBossFightMaxPartySize = nil
    if not run.partyChallengePolicy then
        run.partyChallengePolicy = run.completionAchieved == true
            and "duration-weighted" or "peak-terminal-weighted-10pct"
    end
    if run.completionAchieved == true and not run.maxConcurrentGroupSizeAtCompletion then
        run.maxConcurrentGroupSizeAtCompletion = NormalizePartySize(
            run.maxConcurrentGroupSize or run.partySizeCurrent)
    end
    run.validationTrace = nil
    run.lastOpenSettlementInputSignature = nil
    run.restoreCount = (tonumber(run.restoreCount) or 0) + 1
    self.run = run
    self:RecordLifecycleTransition("restore", "reload")
    run.pitstopMemberStates = run.pitstopMemberStates or {}
    self:ClearPitstopObservationGaps()
    self:ResetRoutineDeathDedupe()

    run.bossDeathStateCredits = run.bossDeathStateCredits or {}
    if tonumber(run.hmEvidencePolicyVersion) ~= self.HM_EVIDENCE_POLICY_VERSION then
        -- Older development runs may contain boss/HM credit selected through
        -- localized combat names. That evidence cannot be upgraded. Preserve the
        -- timer/kill/roster state, but discard the tainted classifications and hold
        -- the run out of whole-run competition.
        run.bossKills = 0
        run.bossKillsAtCompletion = run.completionAchieved and 0 or nil
        run.bossDeathStateCredits = {}
        run.reconciledBossKills = {}
        run.hmBossKills = 0
        run.hmScore = 0
        -- Superseded HM evidence cannot justify an abandoned-HM penalty.
        run.hmAbandonmentEvidence = {}
        run.hmCreditedBossNames = {}
        run.hardModeEncounterAttempts = {}
        run.finalEncounterAttempt.hmObserved = false
        run.finalEncounterAttempt.hmMembers = {}
        run.hmEvidencePolicyVersion = self.HM_EVIDENCE_POLICY_VERSION
        self:MarkRunPartial("superseded-boss-hm-evidence-policy")
    end
    self:RefreshRunEncounterLookups()
    self:ResetTerminalAbilityRuntimeEvidenceAfterReload(run)
    self:MarkConditionalObservationGapsAfterReload(run)
    self.runGeneration = math.max(self.runGeneration or 0, run.generation)
    run.exitCompletionRecoveryUntilMs = nil

    local nowMs = GetGameTimeMilliseconds()
    local restoredElapsedMs = nil
    local restoredCompletedElapsedMs = nil
    if run.startedAtTimeStamp then
        local elapsedMs = tonumber(run.persistedElapsedMs)
        if elapsedMs == nil then
            elapsedMs = math.max(0, nowTimeStamp - run.startedAtTimeStamp) * 1000
        else
            elapsedMs = math.max(0, elapsedMs + math.max(0, nowTimeStamp - lastPersisted) * 1000)
        end
        restoredElapsedMs = elapsedMs
        run.startedAtMs = nowMs - elapsedMs

        if run.persistedCompletedElapsedMs ~= nil then
            restoredCompletedElapsedMs = math.max(0, tonumber(run.persistedCompletedElapsedMs) or 0)
            run.completedAtMs = run.startedAtMs + restoredCompletedElapsedMs
        elseif run.completedAtTimeStamp then
            restoredCompletedElapsedMs = math.max(
                0, run.completedAtTimeStamp - run.startedAtTimeStamp) * 1000
            run.completedAtMs = run.startedAtMs + restoredCompletedElapsedMs
        else
            run.completedAtMs = nil
        end
    end
    self:RestorePartySizeClockAfterReload(
        restoredElapsedMs, restoredCompletedElapsedMs, nowMs)

    run.lastDeathAtMs = nil
    run.lastBossDeathAtMs = nil
    if run.completionCandidateAtMs then
        run.completionCandidateAtMs = run.completedAtMs or nowMs
        run.completionCandidateSetAtMs = nowMs
    else
        run.completionCandidateSetAtMs = nil
    end

    if completionOnlyRestore then
        if not run.completionAchieved and run.completionCandidateAtMs then
            self:OpenCompletionSnapshot(run.completionCandidateReason or "authoritative-completion-reload")
        end
        self:FinalizeRun("instance-exit-after-reload")
        return true
    end

    if differentDungeonRestore then
        self:RecordLifecycleTransition("different-dungeon", "reload-arrival")
        self:FinalizeSessionOnConfirmedExit("different-dungeon-after-reload")
        return true
    end

    if suspendedOutsideRestore or outsideFinalizationRestore then
        -- A UI reload while outside preserves the same 240-second return window.
        -- The departure timestamp survives SavedVariables and remains the anchor.
        self:SuspendActiveRunForZoneExit("outside-reload")
        self:ExpireSuspendedRunIfNeeded("outside-reload-after-240-seconds")
        return true
    end

    if run.zoneExitSuspended == true
        and self:ExpireSuspendedRunIfNeeded("return-after-reload-240-seconds") then
        return true
    end

    run.departureStartedElapsedMs = nil
    run.departureStartedAtTimeStamp = nil
    if run.zoneExitSuspended == true then
        run.zoneExitSuspended = nil
        run.zoneExitSuspendedAtTimeStamp = nil
        run.zoneExitSuspensionReason = nil
        run.zoneExitResumeCount = (tonumber(run.zoneExitResumeCount) or 0) + 1
    end

    self:CaptureGroupMembers("reload-restore")
    self:ObserveCompanionPresence()
    self:RefreshBosses()
    self:RefreshConditionalRuntimeObservers()
    self:TouchActiveRunPersistence()

    if run.startedAtMs then
        self:StartPulse()
    end
    self:RefreshHud()

    if run.completionCandidateAtMs then
        self:CheckAutoCompletion("reload-restore")
    end
    return true
end

function DS:ObserveCompanionPresence(observedZoneId, observedInDungeon)
    local run = self.run
    if not run or run.finalized or run.eligible ~= true or not run.startedAtMs
        or run.companionObserved == true or self.playerDeactivated
        or run.zoneExitSuspended == true then
        return false
    end

    local zoneId = observedZoneId or self:GetCurrentZoneInfo()
    local inDungeon = observedInDungeon
    if inDungeon == nil then
        inDungeon = IsUnitInDungeon("player") == true
    end
    if not inDungeon or tonumber(zoneId) ~= tonumber(run.zoneId) then
        return false
    end

    local localCompanion = type(HasActiveCompanion) == "function"
        and HasActiveCompanion() == true
        and not (type(HasSuppressedCompanion) == "function"
            and HasSuppressedCompanion() == true)
        and not (type(HasBlockedCompanion) == "function"
            and HasBlockedCompanion() == true)
    local groupCompanions = false
    if type(GetNumCompanionsInGroup) == "function"
        and (tonumber(GetNumCompanionsInGroup()) or 0) > 0 then
        if type(GetCompanionUnitTagByGroupUnitTag) == "function"
            and type(GetGroupUnitTagByIndex) == "function"
            and type(IsGroupMemberInSameInstanceAsPlayer) == "function" then
            for index = 1, math.max(0, tonumber(GetGroupSize()) or 0) do
                local memberTag = GetGroupUnitTagByIndex(index)
                if memberTag and IsGroupMemberInSameInstanceAsPlayer(memberTag) == true then
                    local companionTag = GetCompanionUnitTagByGroupUnitTag(memberTag)
                    if companionTag and companionTag ~= ""
                        and IsUnitInDungeon(companionTag) == true then
                        groupCompanions = true
                        break
                    end
                end
            end
        else
            -- Older API versions have only the group-wide count.
            groupCompanions = true
        end
    end
    if not localCompanion and not groupCompanions then
        return false
    end

    run.companionObserved = true
    self:TouchActiveRunPersistence()
    if run.completionAchieved then
        self:UpdateOpenSettlement(true)
    end
    self:RefreshHud()
    return true
end

function DS:ObservePitstopPresence(observedZoneId, observedInDungeon)
    local run = self.run
    if not run or run.finalized or run.eligible ~= true or not run.startedAtMs
        or run.completionAchieved or run.pitstopObserved == true
        or self.playerDeactivated or run.zoneExitSuspended == true
        or type(IsGroupMemberInSameInstanceAsPlayer) ~= "function"
        or type(IsUnitOnline) ~= "function" then
        return false
    end
    local zoneId = observedZoneId or self:GetCurrentZoneInfo()
    local inDungeon = observedInDungeon
    if inDungeon == nil then
        inDungeon = IsUnitInDungeon("player") == true
    end
    if not inDungeon or tonumber(zoneId) ~= tonumber(run.zoneId) then
        return false
    end

    local localKey = self:GetGroupMemberIdentity("player")
    local now = GetTimeStamp()
    run.pitstopMemberStates = run.pitstopMemberStates or {}
    for index = 1, math.max(0, tonumber(GetGroupSize()) or 0) do
        local unitTag = GetGroupUnitTagByIndex(index)
        local key = unitTag and self:GetGroupMemberIdentity(unitTag)
        if key and key ~= localKey then
            local state = run.pitstopMemberStates[key] or {}
            run.pitstopMemberStates[key] = state
            local online = IsUnitOnline(unitTag) == true
            local inInstance = IsGroupMemberInSameInstanceAsPlayer(unitTag) == true
            if online and inInstance then
                state.seenInInstance = true
                state.outsideSince = nil
            elseif online and state.seenInInstance then
                state.outsideSince = state.outsideSince or now
                if now - state.outsideSince >= 15 then
                    run.pitstopObserved = true
                    self:TouchActiveRunPersistence()
                    self:RefreshHud()
                    return true
                end
            else
                -- Going offline is not a pitstop and must not accumulate time.
                state.outsideSince = nil
            end
        end
    end
    return false
end

function DS:ClearPitstopObservationGaps()
    local states = self.run and self.run.pitstopMemberStates or nil
    if type(states) == "table" then
        for _, state in pairs(states) do
            state.outsideSince = nil
        end
    end
end

function DS:EnsureRunStarted(reason)
    if not self.run then
        self:NewRun(false, "run-start")
    end
    if self.run.startedAtMs then
        return
    end

    local startingGroupSize = self:CaptureGroupMembers("run-start")
    self.run.startedAtMs = GetGameTimeMilliseconds()
    self.run.startedAtTimeStamp = GetTimeStamp()
    self.run.partySizeCurrent = NormalizePartySize(startingGroupSize)
    self.run.partySizeLastAtMs = self.run.startedAtMs
    self.run.partySizeLastAtTimeStamp = self.run.startedAtTimeStamp
    self.run.startReason = reason
    self:RecordLifecycleTransition("start", reason)
    self:ObserveCompanionPresence()
    self:ObservePitstopPresence()
    -- Conditional encounters are commonly armed before pull. Refresh their
    -- observers immediately at the first run-start signal; fixed-terminal exact
    -- ability observers were already registered when the eligible run was built.
    self:RefreshConditionalRuntimeObservers()
    self:StartPulse()
    self:TouchActiveRunPersistence()
end

function DS:MarkRunPartial(reason)
    if not self.run or self.run.competitiveEligible == false then
        return
    end
    self.run.competitiveEligible = false
    self.run.integrityStatus = "partial"
    self.run.integrityReason = reason or "partial-observation"
end

function DS:FindOpenSettlementHistoryIndex(run)
    if not self.saved or not run then
        return nil
    end
    local runId = NormalizeRunId(run.runId)
    if not runId then
        return nil
    end
    local index = tonumber(run.openSettlementHistoryIndex)
    local indexedSettlement = index and self.saved.history[index] or nil
    if type(indexedSettlement) == "table"
        and indexedSettlement.scoreSessionOpen == true
        and NormalizeRunId(indexedSettlement.runId) == runId then
        return index
    end
    for candidate = #self.saved.history, 1, -1 do
        local settlement = self.saved.history[candidate]
        if type(settlement) == "table"
            and settlement.scoreSessionOpen == true
            and NormalizeRunId(settlement.runId) == runId then
            run.openSettlementHistoryIndex = candidate
            return candidate
        end
    end
    run.openSettlementHistoryIndex = nil
    return nil
end

function DS:GetOpenSettlementStateSignature(run)
    if not run then
        return nil
    end
    return table.concat({
        tostring(run.killScore or 0),
        tostring(run.hmScore or 0),
        tostring(run.deaths or 0),
        tostring(run.uniqueDeaths or 0),
        tostring(run.xpKills or 0),
        tostring(run.noXpDeaths or 0),
        tostring(run.bossKills or 0),
        tostring(run.hmBossKills or 0),
        tostring(run.bossEncountersObserved or 0),
        tostring(run.maxConcurrentGroupSize or 0),
        tostring(run.groupRosterFingerprint or ""),
        tostring(run.companionObserved == true),
        tostring(run.competitiveEligible ~= false),
    }, ":")
end

function DS:UpdateOpenSettlement(forceUpdate)
    if not self.run or self.run.finalized or not self.run.completionAchieved then
        return nil
    end

    -- Post-completion trash can die in large bursts. Do not rebuild the complete
    -- settlement and refresh history on every individual kill. A cheap run-state
    -- signature collapses those bursts into at
    -- most one update on the existing 500 ms pulse. Finalization always rebuilds
    -- from live run state, so no score data is lost.
    local inputSignature = self:GetOpenSettlementStateSignature(self.run)
    if not forceUpdate and inputSignature == self.run.lastOpenSettlementInputSignature then
        local historyIndex = self:FindOpenSettlementHistoryIndex(self.run)
        return historyIndex and self.saved.history[historyIndex] or nil
    end

    local settlement = Scoring:BuildSettlement(self.run)
    if not settlement then
        return nil
    end
    settlement.completionReason = self.run.completionReason
    settlement.scoreSessionOpen = true
    settlement.finalizedAtTimeStamp = nil
    settlement.finalizeReason = nil
    settlement.runId = self.run.runId
    settlement.runGeneration = self.run.generation
    settlement.scoreAtCompletion = self.run.scoreAtCompletion or settlement.finalScore
    settlement.postCompletionGain = settlement.finalScore - settlement.scoreAtCompletion

    local historyIndex = self:FindOpenSettlementHistoryIndex(self.run)
    if historyIndex then
        self.saved.history[historyIndex] = settlement
    else
        self.saved.history[#self.saved.history + 1] = settlement
        while #self.saved.history > 50 do
            table.remove(self.saved.history, 1)
        end
        self.run.openSettlementHistoryIndex = #self.saved.history
    end

    self.run.lastOpenSettlementInputSignature = inputSignature
    History:OnRunFinalized()
    self:TouchActiveRunPersistence()
    return settlement
end

function DS:OpenCompletionSnapshot(reason)
    if not self.run or self.run.finalized then
        return nil
    end
    if self.run.completionAchieved then
        return self:UpdateOpenSettlement(false)
    end
    self:ObserveCompanionPresence()
    self:ObservePitstopPresence()

    -- Whole-run competitive integrity is locale-safe and route-aware. Each scored
    -- dungeon has a conservative minimum number of boss encounters that a client
    -- should have observed by ESO's official completion milestone. This is not a
    -- requirement to kill every optional/secret boss; legitimate skip routes are
    -- represented by the per-zone floor. Post-completion scoring cannot repair a
    -- partial completion window.
    self.run.bossKillsAtCompletion = self.run.bossKills or 0
    self.run.bossEncountersAtCompletion = self:GetObservedBossEncounterCountForCompletion()
    self.run.expectedBossEncountersAtCompletion = self.run.expectedBossEncountersAtCompletion
        or Scoring:GetExpectedBossEncountersAtCompletion(self.run.zoneId)
    if not self.run.expectedBossEncountersAtCompletion then
        self:MarkRunPartial("missing-boss-encounter-integrity-threshold")
    elseif self.run.bossEncountersAtCompletion < self.run.expectedBossEncountersAtCompletion then
        self:MarkRunPartial("boss-encounters-below-zone-expectation")
    end

    self.run.completionAchieved = true
    self.run.scoreCapturedAddonVersion = self.run.scoreCapturedAddonVersion
        or self.VERSION
    if not self.run.maxConcurrentGroupSizeAtCompletion then
        self.run.maxConcurrentGroupSizeAtCompletion = NormalizePartySize(
            self.run.maxConcurrentGroupSize or self.run.partySizeCurrent)
    end
    self:RecordLifecycleTransition("completion", reason or "automatic")
    self.run.scoreSessionOpen = true
    self.run.completionReason = reason or self.run.completionCandidateReason or "automatic"
    -- The final boss death / explicit Freeze marks the *actual* completion
    -- boundary. A death during the one-second HM reconciliation grace must
    -- not retroactively revoke the canonical no-death/trifecta snapshot.
    self.run.completionDeaths = tonumber(self.run.completionCandidateDeaths)
        or self.run.deaths or 0
    self.run.completionHmBossKills = self.run.hmBossKills or 0
    -- Restored in-flight candidates from earlier versions may predate the
    -- terminal-fight observation. Use the run maximum conservatively.
    if self.run.partyChallengePolicy ~= "duration-weighted"
        and self.run.terminalEncounterPartySizeSource ~= "observed-final-fight" then
        -- The direct death-state event may arrive during the completion grace
        -- after an Activity Finder completion signal.
        self:CaptureTerminalEncounterPartySize(self.run.completedAtMs)
    end
    self.run.exitCompletionRecoveryUntilMs = nil
    local completedElapsedMs = self.run.startedAtMs and self.run.completedAtMs
        and math.max(0, self.run.completedAtMs - self.run.startedAtMs) or nil
    self.run.partySizeDurationsAtCompletion =
        Scoring:GetPartySizeDurations(self.run, completedElapsedMs)

    local settlement = Scoring:BuildSettlement(self.run)
    if not settlement then
        return nil
    end
    self.run.scoreAtCompletion = settlement.finalScore

    self.run.completionCandidateAtMs = nil
    self.run.completionCandidateSetAtMs = nil
    self.run.completionCandidateReason = nil
    self.run.completionCandidateAuthoritative = false
    self.run.completionCandidateDeaths = nil

    settlement = self:UpdateOpenSettlement(true)
    if settlement then
        Diagnostics:CaptureRunSnapshot(settlement, self.run)
    end
    if settlement and not self.run.completionNotified then
        self:ShowFinalScoreNotification(settlement)
        self.run.completionNotified = true
    end
    self:RefreshHud()
    return settlement
end

-- An unfinished session has a legitimate negative settlement of its own.
-- It never creates a completion snapshot, PB, or ordinary WR submission. The
-- final timestamp is the player's last observed departure from the scoring
-- instance (when present), not the destination loading-screen completion.
function DS:FinalizeAbandonedRun(reason)
    local run = self.run
    if not run or run.finalized or run.completionAchieved or not run.startedAtMs then
        return nil
    end

    local elapsedMs = tonumber(run.departureStartedElapsedMs)
    if elapsedMs == nil then
        elapsedMs = math.max(0, GetGameTimeMilliseconds() - run.startedAtMs)
    end
    run.abandonedAtMs = run.startedAtMs + math.max(0, elapsedMs)
    run.abandonedAtTimeStamp = run.departureStartedAtTimeStamp or GetTimeStamp()
    run.abandoned = true
    self:RecordLifecycleTransition("abandon", reason or "abandoned")
    run.competitiveEligible = false
    run.integrityStatus = "abandoned"
    run.integrityReason = "unfinished-run"
    -- A genuine scored boss death, rather than merely observing a boss tag,
    -- supplies the minimum credible progress for eventual Race to the Bottom.
    -- This is a separate local eligibility flag, not server authorization.
    run.minimumCredibleBossKills = Scoring:GetAbandonmentProgressFloor(run.zoneId)
    run.raceToBottomEligible = (tonumber(run.bossKills) or 0) >= run.minimumCredibleBossKills
    run.completionCandidateAtMs = nil
    run.completionCandidateSetAtMs = nil
    run.completionCandidateReason = nil
    run.completionCandidateAuthoritative = false
    run.completionCandidateDeaths = nil
    run.exitCompletionRecoveryUntilMs = nil
    run.finalizeAfterCompletion = nil

    return self:FinalizeRun(reason or "abandoned")
end

-- Finalize on an independently confirmed instance boundary. Activity Finder
-- and exact numeric terminal evidence take precedence over abandonment.
function DS:FinalizeSessionOnConfirmedExit(reason)
    local run = self.run
    if not run or run.finalized or not run.startedAtMs then
        return nil
    end
    if not run.completionAchieved and run.completionCandidateAtMs
        and (run.completionCandidateAuthoritative == true
            or IsAuthoritativeCompletionReason(run.completionCandidateReason)
            or self:IsVerifiedNumericTerminalCandidate(run)) then
        self:CheckPendingHardModeEncounterCredits(GetGameTimeMilliseconds())
        self:OpenCompletionSnapshot(run.completionCandidateReason or reason)
    end
    if run.completionAchieved then
        return self:FinalizeRun(reason or "instance-exit")
    end
    return self:FinalizeAbandonedRun(reason or "instance-exit-abandoned")
end

-- Finalize only an already captured completion. This closes the score and
-- prevents further credit within the current instance; the existing keybind
-- previously conflated this with manually asserting completion.
function DS:FinalizeCompletedScore(reason)
    if not self.run or self.run.finalized then
        self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_NO_OPEN_SCORE))
        return nil
    end
    if not self.run.completionAchieved then
        self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_COMPLETION_NOT_CAPTURED))
        return nil
    end
    local zoneId = self.run.zoneId
    local settlement = self:FinalizeRun(reason or "manual-score-finalize")
    if settlement and self.saved then
        self.saved.frozenSessionZoneId = zoneId
        self.sessionTrackingSuppressed = true
    end
    return settlement
end

-- Freeze Completion captures the canonical time, deaths, HM and trifecta
-- snapshot, but intentionally leaves the score session OPEN. Solo, duo,
-- trio and premade quartet runs do not need Activity Finder participation.
function DS:HandleManualFreeze(quiet)
    if not self.run or self.run.finalized or not self.run.startedAtMs
        or not self:IsArmed() then
        -- A stale run suspended outside its Veteran instance cannot assert
        -- a completion timestamp simply by pressing the freeze keybind.
        self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_NO_ACTIVE_RUN))
        return nil
    end

    if self.run.completionAchieved then
        self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_COMPLETION_ALREADY_FROZEN))
        return self:UpdateOpenSettlement(false)
    end
    if self.run.completionCandidateAtMs and self.run.completionCandidateAuthoritative then
        -- Do not move an already locked completion timestamp with repeated
        -- freeze presses while the one-second HM grace is still pending.
        if not quiet then
            self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_MANUAL_RECONCILING))
        end
        return true
    end

    local nowMs = GetGameTimeMilliseconds()
    local completionBoss = self:ReconcileActivityCompletionHM()
    local encounter = Scoring:GetFinalEncounterConfig(self.run.zoneId)
    local bossName = (completionBoss and completionBoss.normalizedName)
        or self.run.lastBossDeathName
    local eventTimeMs = nowMs

    if self.run.lastBossDeathAtMs
        and nowMs - self.run.lastBossDeathAtMs <= self.RECENT_BOSS_DEATH_WINDOW_MS then
        eventTimeMs = self.run.lastBossDeathAtMs
        if not encounter or encounter.mode ~= "composite" then
            bossName = self.run.lastBossDeathName or bossName
        end
    end

    self:MarkCompletionCandidate("manual-completion", bossName, eventTimeMs, true)
    self:CheckAutoCompletion("manual-completion")
    if not quiet then
        self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_MANUAL_RECONCILING))
    end
    return true
end

-- Finalize performs the same explicit completion capture as Freeze when needed,
-- then closes the score after the ordinary 1-second HM reconciliation grace.
function DS:HandleManualFinalize()
    if not self.run or self.run.finalized or not self.run.startedAtMs then
        self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_NO_OPEN_SCORE))
        return nil
    end
    if self.run.completionAchieved then
        return self:FinalizeCompletedScore("manual-score-finalize")
    end
    if not self.run.completionCandidateAtMs then
        -- This is the same player-authoritative completion assertion as the
        -- Freeze keybind. A failed capture must leave the run intact rather
        -- than silently converting a completed run into abandonment.
        if not self:HandleManualFreeze(true) then
            return nil
        end
        if self.run.completionAchieved then
            return self:FinalizeCompletedScore("manual-score-finalize")
        end
        if not self.run.completionCandidateAtMs then
            return nil
        end
    end

    self.run.finalizeAfterCompletion = true
    self:TouchActiveRunPersistence()
    self:CheckAutoCompletion("manual-finalize-request")
    if self.run and self.run.finalized then
        return self.run.settlement
    end
    self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_FINALIZE_PENDING))
    return true
end

-- Backward-compatible internal entrypoint for code that still calls Finish.
function DS:HandleManualFinish()
    return self:HandleManualFinalize()
end

function DS:CaptureTerminalEncounterPartySize(eventMs)
    local run = self.run
    if not run or run.partyChallengePolicy == "duration-weighted" then
        return
    end
    eventMs = tonumber(eventMs) or GetGameTimeMilliseconds()
    local deathAtMs = tonumber(run.lastBossFightDeathAtMs)
    local deathIdentityId = tonumber(run.lastBossFightIdentityId)
    local recentWindowMs = tonumber(self.RECENT_BOSS_DEATH_WINDOW_MS) or 5000
    if deathAtMs and deathIdentityId
        and deathIdentityId == tonumber(run.lastBossDeathIdentityId)
        and math.abs(eventMs - deathAtMs) <= recentWindowMs
        and run.lastBossFightMaxPartySize then
        run.terminalEncounterPartySize = NormalizePartySize(
            run.lastBossFightMaxPartySize)
        run.terminalEncounterPartySizeSource = "observed-final-fight"
    elseif run.terminalEncounterPartySizeSource ~= "observed-final-fight" then
        run.terminalEncounterPartySize = NormalizePartySize(
            run.terminalEncounterPartySize or run.maxConcurrentGroupSizeAtCompletion
                or run.maxConcurrentGroupSize or run.partySizeCurrent)
        run.terminalEncounterPartySizeSource = "run-maximum-fallback"
    end
end

function DS:MarkCompletionCandidate(reason, bossName, eventTimeMs, authoritative)
    if not self.run or self.run.finalized or self.run.completionAchieved then
        return false
    end

    local eventMs = eventTimeMs or GetGameTimeMilliseconds()
    local isAuthoritative = authoritative == true or IsAuthoritativeCompletionReason(reason)
    local nowMs = GetGameTimeMilliseconds()

    if not self.run.completionCandidateAtMs then
        self.run.completionCandidateAtMs = eventMs
        self.run.completionCandidateSetAtMs = nowMs
        self.run.completionCandidateReason = reason
        self.run.completionCandidateAuthoritative = isAuthoritative
        self.run.completionCandidateDeaths = self.run.deaths or 0
        self.run.completedAtMs = eventMs
        self.run.maxConcurrentGroupSizeAtCompletion = NormalizePartySize(math.max(
            tonumber(self.run.maxConcurrentGroupSize) or 1,
            tonumber(self.run.partySizeCurrent) or 1,
            tonumber(GetGroupSize()) or 1))
        self:CaptureTerminalEncounterPartySize(eventMs)
        self.run.completedAtTimeStamp = GetTimeStamp()
        self.run.completionBossName = bossName
        self:RecordLifecycleTransition("completion-candidate", reason)

        self:TouchActiveRunPersistence()
        return true
    end

    -- Activity Finder and explicit manual completion are authoritative and must
    -- promote/lock any older provisional candidate rather than being ignored by
    -- first-write-wins restore state.
    if isAuthoritative and not self.run.completionCandidateAuthoritative then
        self.run.completionCandidateAuthoritative = true
        self.run.completionCandidateReason = reason
        if bossName and bossName ~= "" then
            self.run.completionBossName = bossName
        end

        self:TouchActiveRunPersistence()
        return true
    end

    return false
end

function DS:CancelCompletionCandidate()
    if not self.run or not self.run.completionCandidateAtMs or self.run.finalized then
        return false
    end

    if self.run.completionCandidateAuthoritative then
        return false
    end

    self.run.completionCandidateAtMs = nil
    self.run.completionCandidateSetAtMs = nil
    self.run.completionCandidateReason = nil
    self.run.completionCandidateAuthoritative = false
    self.run.completionCandidateDeaths = nil
    self.run.completedAtMs = nil
    self.run.completedAtTimeStamp = nil
    self.run.persistedCompletedElapsedMs = nil
    self.run.completionBossName = nil
    self.run.maxConcurrentGroupSizeAtCompletion = nil
    self.run.terminalEncounterPartySize = nil
    self.run.terminalEncounterPartySizeSource = nil
    -- A canceled provisional completion cannot finalize some later attempt.
    self.run.finalizeAfterCompletion = false
    self:TouchActiveRunPersistence()
    return true
end

function DS:HandleAuthoritativeActivityCompletion(reason)
    if not self.run or self.run.finalized or not self.run.startedAtMs then
        return
    end

    self.run.wasLFG = true
    if self.run.completionAchieved then
        self.run.lfgCompleteState = true
        return
    end
    local nowMs = GetGameTimeMilliseconds()
    local completionBoss = self:ReconcileActivityCompletionHM()
    self:ReconcileTerminalBossDeathCredits()
    local encounter = Scoring:GetFinalEncounterConfig(self.run.zoneId)
    local bossName = (completionBoss and completionBoss.normalizedName)
        or self.run.lastBossDeathName
    local eventTimeMs = nowMs

    -- A boss death observed within the last few seconds is a better timestamp
    -- than the completion signal. Never reuse a stale earlier boss death.
    if self.run.lastBossDeathAtMs and nowMs - self.run.lastBossDeathAtMs <= self.RECENT_BOSS_DEATH_WINDOW_MS then
        eventTimeMs = self.run.lastBossDeathAtMs
        if not encounter or encounter.mode ~= "composite" then
            bossName = self.run.lastBossDeathName or bossName
        end
    end

    self:MarkCompletionCandidate(reason or "activity-finder-complete", bossName, eventTimeMs, true)
    self.run.lfgCompleteState = true
end

function DS:OnActivityFinderActivityComplete()
    self:HandleAuthoritativeActivityCompletion("activity-finder-event")
    self:CheckAutoCompletion("activity-finder-event")
end

function DS:FinalizeCompletionCandidate(reason)
    if not self.run or self.run.finalized then
        return nil
    end

    local recoveringAfterExit = self.run.exitCompletionRecoveryUntilMs ~= nil
    local completedZoneId = self.run.zoneId
    -- Preserve a pending explicit Finalize request across the reconciliation
    -- window and /reloadui. The legacy flag represents an in-flight finish
    -- from a pre-split preview and must still be honored once.
    local finalizeAfterCompletion = self.run.finalizeAfterCompletion == true
        or self.run.manualFreezeAfterCompletion == true
    self.run.finalizeAfterCompletion = false
    self.run.manualFreezeAfterCompletion = nil
    local settlement = self:OpenCompletionSnapshot(reason)

    if settlement and finalizeAfterCompletion then
        return self:FinalizeCompletedScore("manual-score-finalize")
    end

    if settlement and recoveringAfterExit then
        local currentZoneId = select(1, self:GetCurrentZoneInfo())
        if currentZoneId ~= completedZoneId then
            self:FinalizeRun("instance-exit-after-completion")
            self:NewRun(false, "completed-instance-exit")
        end
    end

    return settlement
end

function DS:CheckAutoCompletion(reason)
    if not self.run or self.run.finalized or not self.run.startedAtMs then
        return
    end

    local nowMs = GetGameTimeMilliseconds()
    self:CheckPendingHardModeEncounterCredits(nowMs)

    if self.run.completionAchieved then
        self:UpdateOpenSettlement(false)
        return
    end

    -- A pending completion remains valid even if the player has already left the
    -- dungeon. Process it before any eligibility check so a zone transition cannot
    -- strand a completed run during the grace window.
    if self.run.completionCandidateAtMs then
        local setAtMs = self.run.completionCandidateSetAtMs or self.run.completionCandidateAtMs
        if nowMs - setAtMs >= self.COMPLETION_GRACE_MS then
            self:FinalizeCompletionCandidate(self.run.completionCandidateReason or reason or "automatic")
            return
        end
    end

    -- LFG provenance is a run property, not a live roster property. Poll the
    -- authoritative completion flag even after eligibility changes/zone exit.
    if IsInLFGGroup() then
        self.run.wasLFG = true
    end

    local isLFGComplete = IsCurrentLFGActivityComplete() == true
    if self.run.wasLFG and isLFGComplete and not self.run.lfgCompleteState then
        self:HandleAuthoritativeActivityCompletion("lfg-activity-complete")
    else
        self.run.lfgCompleteState = self.run.wasLFG and isLFGComplete or false
    end

    if self.run and self.run.completionCandidateAtMs and not self.run.finalized then
        nowMs = GetGameTimeMilliseconds()
        local setAtMs = self.run.completionCandidateSetAtMs or self.run.completionCandidateAtMs
        if nowMs - setAtMs >= self.COMPLETION_GRACE_MS then
            self:FinalizeCompletionCandidate(self.run.completionCandidateReason or reason or "automatic")
            return
        end
    end

    -- EVENT_PLAYER_ACTIVATED can precede the queued completion event/poll state.
    -- Keep an Activity Finder run alive for a short bounded window so the
    -- authoritative completion signal can still be attributed after zone exit.
    -- No ordinary post-exit kills are accepted by CanProcessDeathEvent().
    if self.run
        and not self.run.finalized
        and not self.run.completionCandidateAtMs
        and self.run.exitCompletionRecoveryUntilMs
        and GetGameTimeMilliseconds() >= self.run.exitCompletionRecoveryUntilMs then
        local oldZoneId = self.run.zoneId
        local currentZoneId = select(1, self:GetCurrentZoneInfo())
        self.run.exitCompletionRecoveryUntilMs = nil
        if currentZoneId ~= oldZoneId then
            if self.run.zoneExitSuspended == true then
                self:StopPulse()
                self:TouchActiveRunPersistence()
            else
                self:SuspendActiveRunForZoneExit("completion-recovery-expired")
            end
            return
        end
        self:TouchActiveRunPersistence()
    end
end

function DS:OnPlayerCombatState(inCombat)
    -- Combat-state transitions can flap repeatedly while moving through trash.
    -- Keep this callback O(1); boss discovery belongs to boss-specific events,
    -- not to every player enter/leave-combat transition.
    if not inCombat then
        return
    end
    if not self:IsArmed() then
        return
    end

    if not self.run then
        self:NewRun(false, "combat-state")
    end
    if self.run.finalized then
        return
    end

    self:EnsureRunStarted("first-in-instance-hostile-combat")
    self:RefreshHud()
end

-- Zone ID identifies dungeon content, not a particular instance. Distinguish
-- a second finder queue for the same dungeon from /reloadui and same-instance
-- travel using a queue transition followed by an actual loading-screen arrival
-- into an in-progress, non-completed Activity Finder dungeon.
function DS:IsNewFinderDungeonArrival(initial, hadPriorActivation, zoneId, inDungeon)
    if initial ~= true or not hadPriorActivation
        or self.pendingNewFinderInstance ~= true or not inDungeon then
        return false
    end
    local run = self.run
    if run and run.startedAtMs and not run.finalized and not run.completionAchieved
        and tonumber(run.zoneId) == tonumber(zoneId) then
        -- Queue state does not identify an instance. An unfinished score may
        -- include a group refill, respawn, or temporary port out and back.
        -- Preserve it until a separately confirmed terminal boundary/reset.
        return false
    end
    local previousZoneId = self.saved and tonumber(self.saved.frozenSessionZoneId)
        or (self.run and tonumber(self.run.zoneId))
    if previousZoneId ~= tonumber(zoneId) then
        return false
    end
    if not select(1, self:GetEligibility()) then
        return false
    end
    if IsInLFGGroup() ~= true or IsCurrentLFGActivityComplete() == true then
        return false
    end
    -- The status API is queried at arrival: receiving QUEUED earlier alone
    -- must never reset a score, nor may an unrelated same-zone teleport.
    return type(GetActivityFinderStatus) == "function"
        and GetActivityFinderStatus() == ACTIVITY_FINDER_STATUS_IN_PROGRESS
end

-- A group-difficulty flip is evidence of a reset only after the player has
-- left a supported dungeon, observed Normal and then Veteran, and arrived
-- again via a loading transition. Ordinary same-instance port-backs remain
-- eligible for continuous timing; /reloadui must not count as an arrival.
function DS:IsNewGroupResetDungeonArrival(initial, hadPriorActivation, zoneId, inDungeon)
    if initial ~= true or not hadPriorActivation or not inDungeon
        or tonumber(self.pendingDifficultyResetZoneId) ~= tonumber(zoneId) then
        return false
    end
    return select(1, self:GetEligibility()) == true
end

function DS:OnPlayerActivated(initial)
    local hadPriorActivation = self.hasActivatedOnce == true
    self.hasActivatedOnce = true
    self.playerDeactivated = false
    self:InvalidateEligibilityCache()
    local zoneId, zoneName, _, inDungeon = self:GetCurrentZoneInfo()
    local scoredZoneId = inDungeon and type(Data.ZONES[tonumber(zoneId)]) == "table"
        and tonumber(zoneId) or nil

    -- Record a real departure from a scored dungeon, not a /reloadui. Keep
    -- this in memory only; a future client session must establish its own
    -- observed reset sequence rather than trusting stale SavedVariables.
    if self.activeScoredDungeonZoneId and self.activeScoredDungeonZoneId ~= scoredZoneId then
        self.lastExitedScoredDungeonZoneId = self.activeScoredDungeonZoneId
        self.activeScoredDungeonZoneId = nil
        self.normalDifficultyObservedForZoneId = nil
        self.pendingDifficultyResetZoneId = nil
    end

    local isNewFinderArrival = self:IsNewFinderDungeonArrival(initial, hadPriorActivation, zoneId, inDungeon)
    local isNewGroupResetArrival = self:IsNewGroupResetDungeonArrival(initial, hadPriorActivation, zoneId, inDungeon)

    if scoredZoneId then
        self.activeScoredDungeonZoneId = scoredZoneId
        -- Any dungeon entry consumes the out-of-instance difficulty history.
        -- Do not reuse that history for a later unrelated zone activation.
        self.lastExitedScoredDungeonZoneId = nil
        self.normalDifficultyObservedForZoneId = nil
        self.pendingDifficultyResetZoneId = nil
    end

    if isNewFinderArrival or isNewGroupResetArrival then
        -- Preserve the previous run's exact-ID completed settlement before
        -- replacing it. If completion authority arrived during the preceding
        -- loading screen, settle that candidate first rather than discarding it.
        if self.run and not self.run.finalized and self.run.completionCandidateAtMs
            and (self.run.completionCandidateAuthoritative == true
                or IsAuthoritativeCompletionReason(self.run.completionCandidateReason)
                or self:IsVerifiedNumericTerminalCandidate(self.run)) then
            self:FinalizeCompletionCandidate("new-activity-finder-arrival")
        end
        self.pendingNewFinderInstance = nil
        self.groupResetSessionClosedZoneId = nil
        if self.saved then
            self.saved.frozenSessionZoneId = nil
        end
        self.pendingFrozenZoneCheck = false
        self.pendingActiveRunRestore = false
        self.sessionTrackingSuppressed = false
        self:NewRun(false, isNewFinderArrival and "new-finder-arrival" or "group-reset-arrival")
        return
    end

    -- A new queue to a different dungeon uses the normal zone-change path;
    -- it must not leave the old same-zone queue hint armed indefinitely.
    if initial == true and self.pendingNewFinderInstance == true and inDungeon
        and IsInLFGGroup() == true and IsCurrentLFGActivityComplete() ~= true
        and type(GetActivityFinderStatus) == "function"
        and GetActivityFinderStatus() == ACTIVITY_FINDER_STATUS_IN_PROGRESS then
        self.pendingNewFinderInstance = nil
    end

    if scoredZoneId and tonumber(self.groupResetSessionClosedZoneId) == scoredZoneId then
        -- After a difficulty reset, a same-zone UI-only activation cannot
        -- resurrect the terminated session or allocate a replacement run.
        -- Only a verified fresh finder/group-reset arrival above lifts the gate.
        self.sessionTrackingSuppressed = true
        self:StopPulse()
        self:StopConditionalRuntimeObservers()
        self:RefreshHud()
        return
    elseif scoredZoneId and self.groupResetSessionClosedZoneId then
        -- Entering another scored dungeon is a normal new session.
        self.groupResetSessionClosedZoneId = nil
        self.sessionTrackingSuppressed = false
    end

    if self.saved and self.saved.frozenSessionZoneId then
        local frozenZoneId = tonumber(self.saved.frozenSessionZoneId)
        if inDungeon and frozenZoneId == tonumber(zoneId) then
            self.pendingFrozenZoneCheck = false
            self.pendingActiveRunRestore = false
            self.sessionTrackingSuppressed = true
            self.saved.activeRun = nil
            if not self.run or not self.run.finalized then
                self.run = nil
            end
            self:StopPulse()
            self:StopConditionalRuntimeObservers()
            self:RefreshHud()
            return
        end
        self.saved.frozenSessionZoneId = nil
        self.pendingFrozenZoneCheck = false
        self.sessionTrackingSuppressed = false
    end

    if self.pendingActiveRunRestore then
        self.pendingActiveRunRestore = false
        local restored, completedRecoveryZoneId = self:TryRestoreActiveRun()
        if restored then
            if self.run and self.run.finalized then
                self:NewRun(false, "restored-finalized-run")
            end
            return
        end
        if completedRecoveryZoneId and inDungeon
            and tonumber(completedRecoveryZoneId) == tonumber(zoneId) then
            -- The completed score was recovered conservatively from stale or
            -- obsolete live state. Treat this instance like a finalized score:
            -- do not let post-completion combat create a second run.
            self.saved.frozenSessionZoneId = completedRecoveryZoneId
            self.sessionTrackingSuppressed = true
            self.run = nil
            self:StopPulse()
            self:StopConditionalRuntimeObservers()
            self:RefreshHud()
            return
        end
        -- PLAYER_ACTIVATED is the first reliable point after /reloadui at which
        -- dungeon identity/eligibility can be trusted. Only now may a stale or
        -- invalid persisted run be discarded and replaced.
        self:NewRun(false, "unrestorable-run")
        return
    end

    if self.run and not self.run.finalized and self.run.startedAtMs
        and (self.run.zoneId ~= zoneId or not inDungeon) then
        -- A departure to a non-dungeon destination retains the run for 240
        -- seconds. Entry into another dungeon is a distinct terminal boundary.
        local exitingRun = self.run
        self:CheckAutoCompletion("player-activated-pre-zone")
        if self.run ~= exitingRun then
            -- Completion processing may already have finalized/replaced the run.
            -- Never allocate a second phantom run during the same activation.
            return
        end
        if not self.run or self.run.finalized then
            self:NewRun(false, "exit-completion-finalized")
            return
        end
        if self.run.completionAchieved or (self.run.completionCandidateAtMs
            and (self.run.completionCandidateAuthoritative == true
                or self:IsVerifiedNumericTerminalCandidate(self.run))) then
            self:FinalizeSessionOnConfirmedExit("instance-exit")
            self:NewRun(false, "completed-instance-exit")
            return
        end
        if inDungeon and self.run.zoneId ~= zoneId then
            self:RecordLifecycleTransition("different-dungeon", "player-activated")
            self:FinalizeSessionOnConfirmedExit("different-dungeon-arrival")
            self:NewRun(false, "different-dungeon-arrival")
            return
        end
        self:SuspendActiveRunForZoneExit("non-dungeon-zone-exit",
            self.run.wasLFG and (GetGameTimeMilliseconds()
                + self.POST_EXIT_COMPLETION_RECOVERY_MS) or nil)
        return
    end

    if self.run and not self.run.finalized and self.run.startedAtMs then
        -- Completion can become authoritative during a loading screen. Check the
        -- LFG state before deciding that a zone change invalidates the old run.
        self:CheckAutoCompletion("player-activated-pre-zone")

        if self.run and not self.run.finalized and self.run.zoneId ~= zoneId then
            if self.run.zoneExitSuspended == true and not inDungeon then
                self:SuspendActiveRunForZoneExit("non-dungeon-zone-exit")
                return
            end
            if self.run.completionCandidateAtMs then
                -- CheckAutoCompletion() above intentionally preserves a candidate
                -- until its grace has matured. Do not bypass that grace merely
                -- because EVENT_PLAYER_ACTIVATED fired during a loading screen;
                -- pending HM evidence may need the same final second to commit.
                self.run.exitCompletionRecoveryUntilMs = GetGameTimeMilliseconds() + self.POST_EXIT_COMPLETION_RECOVERY_MS
                self:TouchActiveRunPersistence()
                self:RefreshHud()
                return
            else
                local currentEligible = select(1, self:GetEligibility())
                local hasVerifiedManualFallback = Scoring:IsAutomaticTerminalCompletionEnabled(self.run.zoneId)
                if not inDungeon and not currentEligible
                    and (self.run.wasLFG or hasVerifiedManualFallback) then
                    self:SuspendActiveRunForZoneExit(
                        "non-dungeon-completion-recovery",
                        GetGameTimeMilliseconds() + self.POST_EXIT_COMPLETION_RECOVERY_MS)
                    return
                end
            end

            if not inDungeon then
                self:SuspendActiveRunForZoneExit("non-dungeon-zone-exit")
                return
            end
        end
    end

    if not inDungeon and (not self.run or self.run.finalized)
        and tonumber(self.lastExitedScoredDungeonZoneId)
            == tonumber(self.groupResetSessionClosedZoneId)
        and (self.normalDifficultyObservedForZoneId or self.pendingDifficultyResetZoneId) then
        -- The prior run is already closed at the difficulty reset. An outside
        -- activation must not allocate a phantom run ID before dungeon entry.
        self:RefreshHud()
        return
    end

    if not self.run or self.run.zoneId ~= zoneId then
        self:NewRun(false, "player-activated-zone-change")
    else
        if inDungeon and self.run.zoneExitSuspended == true
            and self:ExpireSuspendedRunIfNeeded("return-after-240-seconds") then
            self:NewRun(false, "return-after-exit-timeout")
            return
        end
        local currentEligible = select(1, self:RefreshEligibilityCache())
        if not inDungeon or not currentEligible then
            if not inDungeon and self.run.startedAtMs then
                self:SuspendActiveRunForZoneExit("non-dungeon-zone-exit")
            elseif inDungeon and self.run.startedAtMs and not self.run.finalized then
                -- Group and difficulty APIs can be briefly unsettled on a
                -- same-instance activation. Pause through the eligibility cache;
                -- do not abandon the accumulated run and allocate a fresh one.
                self:RefreshHud()
            else
                self:NewRun(false, "ineligible-activation")
            end
            return
        end
        self:ResumeActiveRunAfterZoneReturn(zoneName)
    end
end

function DS:OnLocalPlayerLeftGroup(reason)
    self:InvalidateEligibilityCache()

    local run = self.run
    if not run or run.finalized or not run.eligible then
        return false
    end

    local zoneId = run.zoneId
    self.sessionTrackingSuppressed = true
    self.pendingActiveRunRestore = false
    self.pendingFrozenZoneCheck = false
    self:CancelQueuedBossRefresh()
    self:StopConditionalRuntimeObservers()
    self:StopPulse()
    self:StopZoneExitTimeout()
    self:ResetRoutineDeathDedupe()

    -- Leaving the local group is a terminal boundary for this dungeon instance.
    -- Preserve a completed-open score, including a verified numeric final-boss
    -- death during its grace interval. Never manufacture completion from
    -- partial boss progress or other provisional evidence.
    local settlement = nil
    if run.startedAtMs then
        settlement = self:FinalizeSessionOnConfirmedExit("local-player-left-group")
    end
    if not settlement then
        self:RemoveOpenSettlementForRun(run)
        self.run = nil
        if self.saved then
            self.saved.activeRun = nil
        end
    end

    if self.saved then
        self.saved.frozenSessionZoneId = zoneId
    end
    self:RefreshHud()
    return true
end

function DS:OnGroupChanged(reason)
    self:InvalidateEligibilityCache()
    if self.run and not self.run.finalized then
        if IsInLFGGroup() then
            self.run.wasLFG = true
        end
        self:CaptureGroupMembers(reason or "group-update")
        self:ObserveCompanionPresence()
        if self.run.startedAtMs then
            self:CheckAutoCompletion(reason or "group-update")
        end
    end
end

function DS:FinalizeRun(reason)
    if not self.run or self.run.finalized
        or (not self.run.completionAchieved and self.run.abandoned ~= true) then
        return nil
    end

    self:CaptureGroupMembers("finalize")
    self:ObserveCompanionPresence()
    local settlement = Scoring:BuildSettlement(self.run)
    if not settlement then
        return nil
    end

    settlement.finalizeReason = reason or "finalized"
    settlement.completionReason = self.run.completionReason or self.run.completionCandidateReason
    settlement.scoreSessionOpen = false
    settlement.finalizedAtTimeStamp = GetTimeStamp()
    settlement.runId = self.run.runId
    settlement.runGeneration = self.run.generation
    -- Preserve canonical completion value independently of post-completion
    -- farming; abandoned runs never invent a completion snapshot.
    settlement.scoreAtCompletion = self.run.completionAchieved
        and (self.run.scoreAtCompletion or settlement.finalScore) or nil
    settlement.postCompletionGain = self.run.completionAchieved
        and (settlement.finalScore - settlement.scoreAtCompletion) or 0

    local historyIndex = self:FindOpenSettlementHistoryIndex(self.run)
    if historyIndex then
        self.saved.history[historyIndex] = settlement
    else
        self.saved.history[#self.saved.history + 1] = settlement
        while #self.saved.history > 50 do
            table.remove(self.saved.history, 1)
        end
    end

    self:RecordLifecycleTransition("finalize", reason or "finalized")
    self.run.finalized = true
    self.run.scoreSessionOpen = false
    self.run.settlement = settlement
    self:StopConditionalRuntimeObservers()
    self:StopPulse()
    self:StopZoneExitTimeout()
    self.saved.activeRun = nil

    Diagnostics:CaptureRunSnapshot(settlement, self.run)

    local newHighScore = self.run.completionAchieved
        and self:PreserveHighScore(settlement) or false

    History:OnRunFinalized()
    if not self.run.completionNotified then
        self:ShowFinalScoreNotification(settlement)
    end
    local highScoreText = newHighScore
        and GetString(SI_DUNGEON_SCORES_CHAT_NEW_HIGH_SCORE) or ""
    local trifectaStatus = ""
    if Data.ALTERNATE_HM_SCORING_ZONES[tonumber(settlement.zoneId)] ~= true then
        trifectaStatus = " | TF " .. (settlement.trifectaQualified
            and GetString(SI_DUNGEON_SCORES_YES)
            or GetString(SI_DUNGEON_SCORES_NO))
    end
    self:Chat(FormatString(
        SI_DUNGEON_SCORES_CHAT_SETTLEMENT,
        settlement.finalScore,
        highScoreText,
        FormatDurationMs(settlement.elapsedMs),
        settlement.speedKnown
            and (settlement.speedQualified and GetString(SI_DUNGEON_SCORES_YES)
                or GetString(SI_DUNGEON_SCORES_NO))
            or GetString(SI_DUNGEON_SCORES_INELIGIBLE),
        settlement.noDeathQualified and GetString(SI_DUNGEON_SCORES_YES)
            or GetString(SI_DUNGEON_SCORES_NO),
        trifectaStatus))
    self:RefreshHud()
    return settlement
end

