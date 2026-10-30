DungeonScores = DungeonScores or {}

local DS = DungeonScores
DS.Scoring = DS.Scoring or {}
local Scoring = DS.Scoring
local Data = DS.Data

local function NormalizeRunGroupSize(value)
    local groupSize = tonumber(value)
    if not groupSize then
        return nil
    end
    groupSize = math.floor(groupSize)
    if groupSize < 1 or groupSize > (Data.ELIGIBILITY and Data.ELIGIBILITY.maxGroupSize or 4) then
        return nil
    end
    return groupSize
end

function Scoring:GetRunGroupSize(run)
    if not run then
        return nil
    end
    local size = run.completionAchieved == true
        and run.maxConcurrentGroupSizeAtCompletion or run.maxConcurrentGroupSize
    return NormalizeRunGroupSize(size)
end

function Scoring:GetVitalityScore(deaths)
    local cfg = Data.SCORING
    local livesRemaining = cfg.vitalityStartingLives - deaths

    if livesRemaining >= 0 then
        return livesRemaining * cfg.vitalityPerRemainingLife
    end

    return livesRemaining * cfg.vitalityDeathPastZero
end

function Scoring:GetAdditionalSpeedBonus(zoneConfig, elapsedMs)
    local tiers = zoneConfig and zoneConfig.additionalSpeedBonusTiers or nil
    if type(tiers) ~= "table" or not elapsedMs or elapsedMs < 0 then
        return nil, nil
    end

    local totalPoints = 0
    local strictestThresholdMs = nil
    for _, tier in ipairs(tiers) do
        local maxMs = tonumber(tier.maxMs)
        local points = tonumber(tier.points)
        if maxMs and maxMs > 0 and points and points > 0 and elapsedMs <= maxMs then
            totalPoints = totalPoints + points
            if not strictestThresholdMs or maxMs < strictestThresholdMs then
                strictestThresholdMs = maxMs
            end
        end
    end

    return totalPoints, strictestThresholdMs
end

function Scoring:GetCurrentSpeedBonusTarget(zoneConfig, elapsedMs)
    if type(zoneConfig) ~= "table" then
        return nil, 0
    end

    elapsedMs = tonumber(elapsedMs) or 0
    if elapsedMs < 0 then
        elapsedMs = 0
    end

    local targetMs = nil
    local availablePoints = 0
    local speedThresholdMs = tonumber(zoneConfig.speedThresholdMs)
    local speedPoints = tonumber(Data.SCORING and Data.SCORING.speedRun) or 0
    if speedThresholdMs and speedThresholdMs > 0 and elapsedMs <= speedThresholdMs then
        targetMs = speedThresholdMs
        availablePoints = availablePoints + math.max(0, speedPoints)
    end

    local tiers = zoneConfig.additionalSpeedBonusTiers
    if type(tiers) == "table" then
        for _, tier in ipairs(tiers) do
            local maxMs = tonumber(tier.maxMs)
            local points = tonumber(tier.points)
            if maxMs and maxMs > 0 and points and points > 0 and elapsedMs <= maxMs then
                availablePoints = availablePoints + points
                if not targetMs or maxMs < targetMs then
                    targetMs = maxMs
                end
            end
        end
    end

    return targetMs, availablePoints
end

function Scoring:GetTempoScore(elapsedMs, thresholdMs)
    elapsedMs = tonumber(elapsedMs)
    thresholdMs = tonumber(thresholdMs)
    if not elapsedMs or elapsedMs < 0 or not thresholdMs or thresholdMs <= 0 then
        return nil
    end

    local pointsPerSecond = tonumber(Data.SCORING.tempoPointsPerSecond) or 0
    if pointsPerSecond <= 0 then
        return 0
    end

    -- Each complete second under the configured Speed Run cutoff earns the same
    -- amount that a complete second over it loses. Truncating toward zero keeps
    -- sub-second timer precision symmetric on both sides of the cutoff.
    local deltaMs = thresholdMs - elapsedMs
    local wholeSeconds = math.floor(math.abs(deltaMs) / 1000)
    if deltaMs < 0 then
        wholeSeconds = -wholeSeconds
    end
    return wholeSeconds * pointsPerSecond
end

function Scoring:GetDifficultyCoefficient(zoneConfig, hmBossKills)
    zoneConfig = type(zoneConfig) == "table" and zoneConfig or {}
    local configuredVeteranCoefficient = tonumber(zoneConfig.veteranCoefficient) or 100
    local configuredHardModeCoefficient = tonumber(zoneConfig.hardModeCoefficient)
        or configuredVeteranCoefficient
    if configuredHardModeCoefficient < configuredVeteranCoefficient then
        configuredHardModeCoefficient = configuredVeteranCoefficient
    end

    local premiumScale = tonumber(Data.DIFFICULTY_PREMIUM_SCALE) or 1
    premiumScale = math.max(0, premiumScale)
    local veteranCoefficient = 100
        + (configuredVeteranCoefficient - 100) * premiumScale
    local hardModeCoefficient = 100
        + (configuredHardModeCoefficient - 100) * premiumScale

    local expectedHardModes = tonumber(zoneConfig.expectedHardModes)
    local hardModeProgress = 0
    if expectedHardModes and expectedHardModes > 0 then
        hardModeProgress = math.min(math.max(tonumber(hmBossKills) or 0, 0), expectedHardModes)
            / expectedHardModes
    elseif expectedHardModes == nil and (tonumber(hmBossKills) or 0) > 0 then
        hardModeProgress = 1
    end

    local coefficient = veteranCoefficient
        + (hardModeCoefficient - veteranCoefficient) * hardModeProgress
    return coefficient, veteranCoefficient, hardModeCoefficient, hardModeProgress
end

function Scoring:CalculateFinalScore(achievementScore, vitalityScore, tempoScore, coefficient, partyChallengeScore)
    achievementScore = tonumber(achievementScore) or 0
    vitalityScore = tonumber(vitalityScore) or 0
    tempoScore = tonumber(tempoScore) or 0
    coefficient = tonumber(coefficient) or 100
    partyChallengeScore = tonumber(partyChallengeScore) or 0
    return vitalityScore + tempoScore + partyChallengeScore
        + zo_round(achievementScore * coefficient / 100)
end

function Scoring:GetPartySizeDurations(run, elapsedMs)
    elapsedMs = tonumber(elapsedMs)
    if not run or not elapsedMs or elapsedMs <= 0 then
        return { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    end

    local maximumSize = Data.ELIGIBILITY and Data.ELIGIBILITY.maxGroupSize or 4
    local source = type(run.partySizeDurationsAtCompletion) == "table"
        and run.partySizeDurationsAtCompletion or run.partySizeDurationsMs
    local durations = {}
    local total = 0
    for size = 1, maximumSize do
        local value = math.max(0, tonumber(source and source[size]) or 0)
        durations[size] = value
        total = total + value
    end

    -- The live clock retains its open segment instead of rewriting SavedVariables
    -- on every frame. Include that segment in a settlement projection. A frozen
    -- completion histogram has already consumed the complete official window.
    if type(run.partySizeDurationsAtCompletion) ~= "table" then
        local startedAtMs = tonumber(run.startedAtMs)
        local lastAtMs = tonumber(run.partySizeLastAtMs) or startedAtMs
        local endAtMs = startedAtMs and (startedAtMs + elapsedMs) or nil
        if lastAtMs and endAtMs and endAtMs > lastAtMs then
            local size = NormalizeRunGroupSize(run.partySizeCurrent)
                or NormalizeRunGroupSize(run.maxConcurrentGroupSize)
                or maximumSize
            durations[size] = (durations[size] or 0) + (endAtMs - lastAtMs)
            total = total + (endAtMs - lastAtMs)
        end
    end

    -- Reload/loading boundaries can leave a sub-second unaccounted remainder.
    -- Charge ambiguity to the larger observed composition, which can only reduce
    -- the challenge award. Conversely, trim any event-timestamp overrun from the
    -- smallest groups first so a past completion timestamp cannot inflate it.
    if total < elapsedMs then
        local conservativeSize = math.max(
            NormalizeRunGroupSize(run.partySizeCurrent) or 1,
            NormalizeRunGroupSize(run.maxConcurrentGroupSize) or 1)
        durations[conservativeSize] = (durations[conservativeSize] or 0) + (elapsedMs - total)
    elseif total > elapsedMs then
        local excess = total - elapsedMs
        for size = 1, maximumSize do
            local removable = math.min(excess, durations[size] or 0)
            durations[size] = (durations[size] or 0) - removable
            excess = excess - removable
            if excess <= 0 then
                break
            end
        end
    end

    return durations
end

function Scoring:GetPartyChallengeScore(run, elapsedMs)
    elapsedMs = tonumber(elapsedMs)
    if not run or not elapsedMs or elapsedMs <= 0 then
        return 0, nil, self:GetPartySizeDurations(run, elapsedMs)
    end

    local durations = self:GetPartySizeDurations(run, elapsedMs)
    local values = Data.SCORING.partyChallengeByGroupSize or {}
    local weightedPoints = 0
    local weightedSize = 0
    for size = 1, (Data.ELIGIBILITY and Data.ELIGIBILITY.maxGroupSize or 4) do
        local duration = tonumber(durations[size]) or 0
        local share = duration / elapsedMs
        weightedPoints = weightedPoints + share * (tonumber(values[size]) or 0)
        weightedSize = weightedSize + share * size
    end

    -- The largest party seen at any time sets the record division and the
    -- guaranteed challenge endpoint. Time spent in smaller groups can recover
    -- only 10% of the gap to the whole-run weighted score, and the largest
    -- party in the terminal fight caps that recovery. Porting out while still
    -- grouped does not reduce the observed party size. Unfinished RTB runs
    -- have no terminal fight, so they retain the previous weighted rule.
    if run.completionAchieved == true
        and run.partyChallengePolicy ~= "duration-weighted" then
        local peakSize = self:GetRunGroupSize(run)
        local terminalSize = NormalizeRunGroupSize(run.terminalEncounterPartySize)
            or peakSize
        if peakSize and terminalSize then
            local peakPoints = tonumber(values[peakSize]) or 0
            local terminalPoints = tonumber(values[terminalSize]) or 0
            local recoveredPoints = math.max(0, weightedPoints - peakPoints) * 0.10
            return zo_round(math.min(terminalPoints, peakPoints + recoveredPoints)),
                weightedSize, durations
        end
    end
    return zo_round(weightedPoints), weightedSize, durations
end

local function NormalizeUnitName(name)
    if not name or name == "" then
        return ""
    end
    return zo_strformat(SI_UNIT_NAME, name)
end

function Scoring:GetZoneConfig(zoneId)
    return Data.ZONES[zoneId]
end

function Scoring:IsHealthBasedHMAllowed(zoneId)
    local zoneConfig = self:GetZoneConfig(tonumber(zoneId))
    return not zoneConfig or zoneConfig.healthBasedHM ~= false
end

function Scoring:GetExpectedBossEncountersAtCompletion(zoneId)
    local value = Data.EXPECTED_BOSS_ENCOUNTERS_AT_COMPLETION
        and Data.EXPECTED_BOSS_ENCOUNTERS_AT_COMPLETION[tonumber(zoneId)]
    value = tonumber(value)
    if not value or value < 2 then
        return nil
    end
    return math.floor(value)
end

function Scoring:GetRouteAbilityEncounterConfigs(zoneId)
    local zoneConfig = self:GetZoneConfig(tonumber(zoneId))
    if not zoneConfig or type(zoneConfig.routeAbilityEncounters) ~= "table" then
        return nil
    end
    return zoneConfig.routeAbilityEncounters
end

function Scoring:GetHardModeEncounterConfigs(zoneId)
    local zoneConfig = self:GetZoneConfig(zoneId)
    if not zoneConfig or type(zoneConfig.hardModeEncounters) ~= "table" then
        return nil
    end
    return zoneConfig.hardModeEncounters
end

function Scoring:UsesEncounterScopedHM(zoneId)
    local encounters = self:GetHardModeEncounterConfigs(zoneId)
    return encounters ~= nil and #encounters > 0
end

function Scoring:UsesCumulativeHardModeProgression(zoneId)
    local zoneConfig = self:GetZoneConfig(tonumber(zoneId))
    local encounters = zoneConfig and zoneConfig.hardModeEncounters
    local expectedHardModes = zoneConfig and tonumber(zoneConfig.expectedHardModes)
    return expectedHardModes ~= nil
        and expectedHardModes > 1
        and type(encounters) == "table"
        and #encounters == expectedHardModes
end

function Scoring:EncounterUsesConditionalHM(encounter)
    return encounter ~= nil and type(encounter.criterion) == "table" and encounter.criterion.type ~= nil
end

function Scoring:UsesTerminalCohortCompletion(encounter)
    return encounter ~= nil and encounter.completionMode == "terminal-cohort-death"
end

function Scoring:IsConditionalHMAutomaticScoringEnabled(encounter)
    if not self:EncounterUsesConditionalHM(encounter) then
        return false
    end
    local criterion = encounter.criterion
    return criterion.automaticScoring == true
        and criterion.evidenceMode == "verified-numeric"
end

function Scoring:HasKnownHMHealthEvidence(zoneId, encounterKey)
    local signatures = Data.HM_HEALTH_SIGNATURES[tonumber(zoneId)]
    if type(signatures) ~= "table" then
        return false
    end

    if encounterKey == nil then
        return next(signatures) ~= nil
    end

    encounterKey = tostring(encounterKey)
    for _, stableKey in pairs(signatures) do
        if stableKey == encounterKey then
            return true
        end
    end
    return false
end

function Scoring:HasKnownHMActiveHealthPoolEvidence(zoneId, encounterKey)
    local signature = Data.HM_ACTIVE_HEALTH_POOL_SIGNATURES
        and Data.HM_ACTIVE_HEALTH_POOL_SIGNATURES[tonumber(zoneId)]
    if type(signature) ~= "table" then
        return false
    end
    if encounterKey == nil then
        return type(signature.encounterKey) == "string"
            and signature.encounterKey ~= ""
    end
    return tostring(signature.encounterKey or "") == tostring(encounterKey)
end

function Scoring:IsDirectFirstSightHardModeEncounterSupported(zoneId, encounter, index)
    if not encounter then
        return false
    end
    if self:EncounterUsesConditionalHM(encounter) then
        return self:IsConditionalHMAutomaticScoringEnabled(encounter)
    end
    local encounterKey = self:GetHardModeEncounterKey(encounter, index)
    return self:HasKnownHMHealthEvidence(zoneId, encounterKey)
        or self:HasKnownHMActiveHealthPoolEvidence(zoneId, encounterKey)
end

function Scoring:IsFirstSightHardModeEncounterSupported(zoneId, encounter, index)
    if self:IsDirectFirstSightHardModeEncounterSupported(zoneId, encounter, index) then
        return true
    end

    local encounters = self:GetHardModeEncounterConfigs(zoneId)
    index = tonumber(index)
    if not self:UsesCumulativeHardModeProgression(zoneId)
        or type(encounters) ~= "table" or not index then
        return false
    end

    -- ESO multi-HM dungeons are cumulative: a verified later HM cannot be reached
    -- until every preceding HM has succeeded. A later first-sight signal is
    -- therefore positive evidence for the earlier encounter, without relying on
    -- display text or requiring the client to witness activation.
    for successorIndex = index + 1, #encounters do
        if self:IsDirectFirstSightHardModeEncounterSupported(
            zoneId,
            encounters[successorIndex],
            successorIndex) then
            return true
        end
    end
    return false
end

function Scoring:IsTrifectaSupported(zoneId)
    local zoneConfig = self:GetZoneConfig(tonumber(zoneId))
    local expectedHardModes = zoneConfig and tonumber(zoneConfig.expectedHardModes)
    if Data.ALTERNATE_HM_SCORING_ZONES
        and Data.ALTERNATE_HM_SCORING_ZONES[tonumber(zoneId)] == true then
        return false
    end
    if not expectedHardModes or expectedHardModes <= 0 then
        return false
    end

    -- Trifecta scoring is available only when every configured HM has a positive
    -- language-independent path that works even if the client's first encounter
    -- observation is already HM. A witnessed health transition is not a
    -- competitive capability because boss acquisition may occur after activation.
    local encounters = zoneConfig.hardModeEncounters
    if type(encounters) == "table" and #encounters > 0 then
        if #encounters ~= expectedHardModes then
            return false
        end
        for index, encounter in ipairs(encounters) do
            if not self:IsFirstSightHardModeEncounterSupported(
                zoneId,
                encounter,
                index) then
                return false
            end
        end
        return true
    end

    -- Non-scoped legacy dungeons have one final HM. Zone-scoped positive health
    -- evidence is sufficient because there is no second scored HM to confuse it.
    return expectedHardModes == 1 and self:HasKnownHMHealthEvidence(zoneId)
end

local function TableContainsNormalizedValue(values, normalizedValue)
    if type(values) ~= "table" or normalizedValue == "" then
        return false
    end

    for key, value in pairs(values) do
        local candidate = nil
        if type(key) == "string" and value == true then
            candidate = key
        elseif type(value) == "string" then
            candidate = value
        end
        if candidate and zo_strlower(NormalizeUnitName(candidate)) == zo_strlower(normalizedValue) then
            return true
        end
    end
    return false
end

function Scoring:ConditionalTextMatches(value, exactValues, containsValues)
    local normalized = NormalizeUnitName(value or "")
    if normalized == "" then
        return false
    end

    if TableContainsNormalizedValue(exactValues, normalized) then
        return true
    end

    if type(containsValues) == "table" then
        local haystack = zo_strlower(normalized)
        for _, needleValue in pairs(containsValues) do
            if type(needleValue) == "string" then
                local needle = zo_strlower(NormalizeUnitName(needleValue))
                if needle ~= "" and string.find(haystack, needle, 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

function Scoring:GetHardModeEncounterKey(encounter, index)
    if not encounter then
        return nil
    end
    return tostring(encounter.key or encounter.label or index or "unknown")
end

function Scoring:IsValidHardModeEncounterCreditKey(zoneId, creditKey)
    if not creditKey then
        return false
    end
    local encounters = self:GetHardModeEncounterConfigs(zoneId)
    if not encounters then
        return false
    end
    for index, encounter in ipairs(encounters) do
        if creditKey == "encounter:" .. self:GetHardModeEncounterKey(encounter, index) then
            return true
        end
    end
    return false
end

function Scoring:FindHardModeEncounterConfigByKey(zoneId, encounterKey)
    if encounterKey == nil then
        return nil
    end

    encounterKey = tostring(encounterKey)
    for index, encounter in ipairs(self:GetHardModeEncounterConfigs(zoneId) or {}) do
        if self:GetHardModeEncounterKey(encounter, index) == encounterKey then
            return encounter, index
        end
    end
    return nil
end

function Scoring:GetHardModeEncounterProgress(encounter, attempt)
    if not encounter or type(attempt) ~= "table" then
        return false, 0, 0
    end

    local required = math.max(1, tonumber(encounter.required) or 1)
    if encounter.requireAuthoritativeCompletion == true
        and attempt.authoritativeCompletion ~= true then
        return false, 0, required
    end
    if attempt.authoritativeCompletion == true
        or attempt.cumulativeCompletion == true then
        return true, required, required
    end

    local matched = 0
    local seenIdentities = {}
    for identityKey, evidence in pairs(attempt.identityDeaths or {}) do
        local identityId = type(evidence) == "table" and tonumber(evidence.identityId)
            or tonumber(identityKey)
        if identityId and identityId > 0 and not seenIdentities[identityId] then
            seenIdentities[identityId] = true
            matched = matched + 1
            if matched >= required then
                break
            end
        end
    end

    if self:UsesTerminalCohortCompletion(encounter) then
        if attempt.terminalDeathSatisfied == true then
            return true, required, required
        end
        return false, matched, required
    end

    return matched >= required, matched, required
end

function Scoring:GetFinalEncounterConfig(zoneId)
    local zoneConfig = self:GetZoneConfig(zoneId)
    return zoneConfig and zoneConfig.finalEncounter or nil
end

function Scoring:IsAutomaticTerminalCompletionEnabled(zoneId)
    -- There is no generic language-independent terminal-boss identity API.
    -- Enable direct completion only for a zone whose numeric co-observation
    -- and death-state cohort has been independently verified. Display names
    -- must never become scoring authority.
    return type(Data.NUMERIC_TERMINAL_COHORTS) == "table"
        and type(Data.NUMERIC_TERMINAL_COHORTS[tonumber(zoneId)]) == "table"
end

function Scoring:GetFinalHardModeEncounterConfig(zoneId)
    local finalEncounter = self:GetFinalEncounterConfig(zoneId)
    local encounterKey = finalEncounter and finalEncounter.hmEncounterKey or nil
    if type(encounterKey) ~= "string" or encounterKey == "" then
        return nil
    end
    return self:FindHardModeEncounterConfigByKey(zoneId, encounterKey)
end

function Scoring:RequiresAggregateFinalEncounterHM(zoneId)
    local encounter = self:GetFinalEncounterConfig(zoneId)
    return encounter ~= nil
        and (encounter.mode == "composite" or encounter.mode == "identity-count")
        and encounter.hmCreditMode == "single"
end

function Scoring:GetKnownHMHealthEncounterKey(zoneId, maxHealth)
    if not zoneId or not maxHealth or maxHealth <= 0 then
        return nil
    end
    if not self:IsHealthBasedHMAllowed(zoneId) then
        return nil
    end

    -- Hot-path lookup: boss health samples are frequent. Static signatures are
    -- zone-scoped and return stable internal keys, never localized unit names.
    local signatures = Data.HM_HEALTH_SIGNATURES[tonumber(zoneId)]
    local encounterKey = type(signatures) == "table" and signatures[tonumber(maxHealth)] or nil
    if type(encounterKey) ~= "string" or encounterKey == "" then
        return nil
    end
    return encounterKey
end

function Scoring:GetKnownHMActiveHealthPoolEncounterKey(zoneId, currentHealth, maxHealth)
    if not zoneId or not currentHealth or not maxHealth then
        return nil
    end
    if not self:IsHealthBasedHMAllowed(zoneId) then
        return nil
    end

    local signature = Data.HM_ACTIVE_HEALTH_POOL_SIGNATURES
        and Data.HM_ACTIVE_HEALTH_POOL_SIGNATURES[tonumber(zoneId)]
    if type(signature) ~= "table"
        or tonumber(maxHealth) ~= tonumber(signature.reportedMaxHealth) then
        return nil
    end

    currentHealth = tonumber(currentHealth)
    local basePoolHealth = tonumber(signature.basePoolHealth)
    local hardModePoolHealth = tonumber(signature.hardModePoolHealth)
    if not currentHealth or not basePoolHealth or not hardModePoolHealth
        or currentHealth <= basePoolHealth
        or currentHealth > hardModePoolHealth then
        return nil
    end

    local encounterKey = signature.encounterKey
    if type(encounterKey) ~= "string" or encounterKey == "" then
        return nil
    end
    return encounterKey
end

function Scoring:IsHMActiveHealthPoolResetValue(zoneId, currentHealth, maxHealth)
    local signature = Data.HM_ACTIVE_HEALTH_POOL_SIGNATURES
        and Data.HM_ACTIVE_HEALTH_POOL_SIGNATURES[tonumber(zoneId)]
    currentHealth = tonumber(currentHealth)
    maxHealth = tonumber(maxHealth)
    if type(signature) ~= "table" or not currentHealth or not maxHealth
        or maxHealth ~= tonumber(signature.reportedMaxHealth) then
        return false
    end
    return currentHealth == tonumber(signature.basePoolHealth)
        or currentHealth >= tonumber(signature.reportedMaxHealth)
end

function Scoring:IsVerifiedHMEncounterResolutionSource(source)
    return source == "zone-max-health"
        or source == "zone-active-health-pool"
        or source == "verified-encounter-cohort"
        or source == "verified-ability-cohort"
end

function Scoring:IsKnownHMHealth(zoneId, maxHealth)
    return self:GetKnownHMHealthEncounterKey(zoneId, maxHealth) ~= nil
end

local function BuildGroupMemberList(run)
    local members = {}
    for _, member in pairs(run.groupMembers or {}) do
        members[#members + 1] = {
            accountName = member.accountName,
            characterName = member.characterName,
            firstSeenAtTimeStamp = member.firstSeenAtTimeStamp,
            lastSeenAtTimeStamp = member.lastSeenAtTimeStamp,
        }
    end

    table.sort(members, function(a, b)
        local aKey = (a.accountName and a.accountName ~= "" and a.accountName) or a.characterName or ""
        local bKey = (b.accountName and b.accountName ~= "" and b.accountName) or b.characterName or ""
        return zo_strlower(aKey) < zo_strlower(bKey)
    end)

    return members
end

-- Count explicitly deactivated HM encounters only when they have not
-- subsequently been completed on HM. This is deliberately not inferred from
-- missing HM credit: a group that never activated HM incurs no subtraction.
function Scoring:GetAbandonmentProgressFloor(zoneId)
    local policy = Data.ABANDONMENT_PROGRESS or {}
    local override = type(policy.byZone) == "table"
        and policy.byZone[tonumber(zoneId)] or nil
    return math.max(1, math.floor(tonumber(override)
        or tonumber(policy.defaultBossKills) or 1))
end

function Scoring:GetAbandonedHardModeCount(run)
    if not run or not self:IsHealthBasedHMAllowed(run.zoneId)
        or (Data.ALTERNATE_HM_SCORING_ZONES
            and Data.ALTERNATE_HM_SCORING_ZONES[tonumber(run.zoneId)] == true) then
        return 0
    end
    local valid = {}
    for _, key in pairs(Data.HM_HEALTH_SIGNATURES[tonumber(run.zoneId)] or {}) do
        valid[key] = true
    end
    local count = 0
    for key, record in pairs(run.hmAbandonmentEvidence or {}) do
        if valid[key] and type(record) == "table"
            and record.activated == true and record.deactivated == true
            and record.completedNonHM == true
            and not (run.hmCreditedBossNames
                and run.hmCreditedBossNames["encounter:" .. tostring(key)] == true) then
            count = count + 1
        end
    end
    return count
end

function Scoring:BuildSettlement(run)
    if not run then
        return nil
    end

    local cfg = Data.SCORING
    local zoneConfig = self:GetZoneConfig(run.zoneId) or {}
    local abandoned = run.abandoned == true and run.completionAchieved ~= true
    local nowMs = abandoned and run.abandonedAtMs or run.completedAtMs
        or GetGameTimeMilliseconds()
    local elapsedMs = run.startedAtMs and math.max(0, nowMs - run.startedAtMs) or nil
    local speedThresholdMs = zoneConfig.speedThresholdMs
    local runGroupSize = self:GetRunGroupSize(run)

    local competitiveEligible = run.competitiveEligible ~= false
    local speedQualified = not abandoned and competitiveEligible and speedThresholdMs and elapsedMs and elapsedMs <= speedThresholdMs or false
    local speedKnown = (competitiveEligible or abandoned) and speedThresholdMs ~= nil and elapsedMs ~= nil
    local paceRatio = speedKnown and speedThresholdMs > 0 and (elapsedMs / speedThresholdMs) or nil
    local tempoScore = (competitiveEligible or abandoned)
        and (self:GetTempoScore(elapsedMs, speedThresholdMs) or 0) or 0
    if abandoned then
        -- Quitting early cannot earn positive tempo. Overtime still subtracts
        -- exactly as it does on a completed run.
        tempoScore = math.min(0, tempoScore)
    end
    local partyChallengeScore, partyAverageGroupSize, partySizeDurationsMs =
        self:GetPartyChallengeScore(run, elapsedMs)
    if not competitiveEligible then
        partyChallengeScore = 0
    end
    local completionDeaths = run.completionAchieved and tonumber(run.completionDeaths) or (run.deaths or 0)
    local completionHmBossKills = run.completionAchieved and tonumber(run.completionHmBossKills) or (run.hmBossKills or 0)
    local noDeathQualified = not abandoned and competitiveEligible and completionDeaths == 0

    local expectedHardModes = zoneConfig.expectedHardModes
    local trifectaSupported = self:IsTrifectaSupported(run.zoneId)
    local hmBossKills = run.hmBossKills or 0
    local coefficient, veteranCoefficient, hardModeCoefficient, hardModeProgress =
        self:GetDifficultyCoefficient(zoneConfig, hmBossKills)

    local allHardModesAtCompletion = trifectaSupported
        and expectedHardModes ~= nil
        and expectedHardModes > 0
        and completionHmBossKills >= expectedHardModes

    local veteranBase = not abandoned and run.isVeteran and cfg.veteranBase or 0
    local speedBonus = speedKnown and speedQualified and cfg.speedRun or 0
    local additionalSpeedBonus = nil
    local additionalSpeedTierMs = nil
    if type(zoneConfig.additionalSpeedBonusTiers) == "table" then
        if competitiveEligible and elapsedMs ~= nil then
            additionalSpeedBonus, additionalSpeedTierMs = self:GetAdditionalSpeedBonus(zoneConfig, elapsedMs)
        else
            additionalSpeedBonus = 0
        end
    end
    local noDeathBonus = noDeathQualified and cfg.noDeath or 0
    local trifectaQualified = competitiveEligible and allHardModesAtCompletion and speedKnown and speedQualified and noDeathQualified
    local trifectaBonus = trifectaQualified and (cfg.trifecta or 0) or 0
    local vitality = self:GetVitalityScore(run.deaths or 0)

    -- Vitality, Tempo, and Party Challenge are universal measurements: every death,
    -- every complete second from the Speed Run cutoff, and each observed
    -- party-size composition must retain the same point value in every dungeon. Difficulty
    -- therefore scales only the achievement subtotal. All
    -- values in that subtotal are non-negative, so a coefficient can reward
    -- dungeon difficulty without amplifying a negative run.
    local achievementScore = veteranBase
        + (run.killScore or 0)
        + (run.hmScore or 0)
        + speedBonus
        + (additionalSpeedBonus or 0)
        + noDeathBonus
        + trifectaBonus
    local abandonmentPenalty = abandoned and -(tonumber(cfg.abandonmentPenalty) or 0) or 0
    -- All losses are universal, flat penalties. Never amplify a negative
    -- penalty with the dungeon's positive difficulty coefficient.
    local abandonedHardModeCount = (abandoned or run.completionAchieved)
        and self:GetAbandonedHardModeCount(run) or 0
    local abandonedHardModeScore = -abandonedHardModeCount
        * math.max(0, tonumber(cfg.abandonedHardModePenalty) or 0)
    local companionPenalty = run.companionObserved == true
        and -math.max(0, tonumber(cfg.companionPenalty) or 0) or 0
    local pitstopPenalty = run.pitstopObserved == true
        and -math.max(0, tonumber(cfg.pitstopPenalty) or 0) or 0
    local finalScore = self:CalculateFinalScore(
        achievementScore, vitality, tempoScore, coefficient, partyChallengeScore)
    local raceToBottomScore = finalScore + abandonmentPenalty
        + abandonedHardModeScore + companionPenalty + pitstopPenalty
    local groupMembers = BuildGroupMemberList(run)

    return {
        addonVersion = run.scoreCapturedAddonVersion or DS.VERSION,
        runId = run.runId,
        zoneId = run.zoneId,
        zoneName = run.zoneName,
        isVeteran = run.isVeteran,
        startedAtTimeStamp = run.startedAtTimeStamp,
        finalizedAtTimeStamp = GetTimeStamp(),
        completedAtTimeStamp = run.completedAtTimeStamp,
        completionBossName = run.completionBossName,
        runOutcome = abandoned and "abandoned" or "completed",
        abandonmentPenalty = abandonmentPenalty,
        abandonedHardModeCount = abandonedHardModeCount,
        abandonedHardModeScore = abandonedHardModeScore,
        companionObserved = run.companionObserved == true,
        companionPenalty = companionPenalty,
        pitstopObserved = run.pitstopObserved == true,
        pitstopPenalty = pitstopPenalty,
        raceToBottomScore = raceToBottomScore,
        abandonedAtTimeStamp = abandoned and run.abandonedAtTimeStamp or nil,
        raceToBottomEligible = abandoned and run.raceToBottomEligible == true
            or (not abandoned and competitiveEligible and run.completionAchieved == true),
        minimumCredibleBossKills = abandoned and (run.minimumCredibleBossKills or 1) or nil,
        scoreSessionOpen = run.scoreSessionOpen == true,
        competitiveEligible = competitiveEligible,
        integrityStatus = run.integrityStatus or (competitiveEligible and "full" or "partial"),
        integrityReason = run.integrityReason,
        elapsedMs = elapsedMs,
        speedThresholdMs = speedThresholdMs,
        paceRatio = paceRatio,
        runGroupSize = runGroupSize,
        terminalEncounterPartySize = run.completionAchieved == true
            and NormalizeRunGroupSize(run.terminalEncounterPartySize) or nil,
        terminalEncounterPartySizeSource = run.completionAchieved == true
            and (run.terminalEncounterPartySizeSource or "run-maximum-fallback") or nil,
        partyChallengePolicy = run.partyChallengePolicy
            or (run.completionAchieved == true
                and "peak-terminal-weighted-10pct" or "duration-weighted"),
        partyAverageGroupSize = partyAverageGroupSize,
        partySizeDurationsMs = partySizeDurationsMs,

        uniqueDeaths = run.uniqueDeaths or 0,
        xpKills = run.xpKills or 0,
        noXpDeaths = run.noXpDeaths or 0,
        bossKills = run.bossKills or 0,
        bossEncountersObserved = tonumber(run.bossEncountersObserved) or 0,
        bossEncountersAtCompletion = run.bossEncountersAtCompletion,
        expectedBossEncountersAtCompletion = run.expectedBossEncountersAtCompletion
            or self:GetExpectedBossEncountersAtCompletion(run.zoneId),
        deaths = run.deaths or 0,
        deathsAtCompletion = completionDeaths,
        hmBossKills = run.hmBossKills or 0,
        groupMembers = groupMembers,
        publicationTeamName = nil,
        publicationTeamMembers = nil,
        publicationTeamResolution = "unassigned",
        publicationGuildId = nil,
        publicationGuildName = nil,
        publicationGuildEventId = nil,
        publicationGuildEventName = nil,

        veteranBase = veteranBase,
        killScore = run.killScore or 0,
        hmScore = run.hmScore or 0,
        speedKnown = speedKnown,
        speedQualified = speedQualified,
        speedBonus = speedBonus,
        additionalSpeedBonus = additionalSpeedBonus,
        additionalSpeedTierMs = additionalSpeedTierMs,
        noDeathQualified = noDeathQualified,
        noDeathBonus = noDeathBonus,
        trifectaQualified = trifectaQualified,
        trifectaBonus = trifectaBonus,
        trifectaSupported = trifectaSupported,
        tempoScore = tempoScore,
        partyChallengeScore = partyChallengeScore,
        vitalityScore = vitality,
        coefficient = coefficient,
        veteranCoefficient = veteranCoefficient,
        hardModeCoefficient = hardModeCoefficient,
        hardModeProgress = hardModeProgress,
        expectedHardModes = expectedHardModes,
        finalScore = finalScore,
    }
end
