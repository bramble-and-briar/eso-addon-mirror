local LIVE_SNAPSHOT_CACHE_MS = 200

function ConsoleMetrics:AcquireTargetInfo(targetName)
    local key = targetName
    if not key or key == "" then
        key = "Unknown"
    end

    local info = self.fight.targetMap[key]
    if not info then
        info = {
            name = key,
            damage = 0,
            effective = 0,
            overflow = 0,
            blocked = 0,
            shielded = 0,
            hits = 0,
        }
        self.fight.targetMap[key] = info
    end

    return info
end

function ConsoleMetrics:SampleFightResources(nowMs, forceSample)
    if not self.fight or not self.fight.resourceSamples then
        return
    end

    if self.saved
        and self.saved.ioTraceEnabled
        and self.saved.ioTraceTargetOnlyProcessing
        and self.saved.ioTraceSkipResourceSampling
        and self.saved.ioTraceTargetMode ~= "off"
    then
        local graceMs = tonumber(self.saved.ioTraceTargetGraceMs) or 1500
        graceMs = math.max(250, math.min(5000, math.floor(graceMs + 0.5)))
        local lastMatchMs = self.lastTraceTargetMatchMs or 0
        if not forceSample and nowMs > (lastMatchMs + graceMs) then
            if self.ioTraceState then
                self.ioTraceState.skippedSampleByFocus = (self.ioTraceState.skippedSampleByFocus or 0) + 1
            end
            return
        end
    end

    local resourceSamples = self.fight.resourceSamples
    if not forceSample and resourceSamples.lastSampleMs and nowMs < (resourceSamples.lastSampleMs + RESOURCE_SAMPLE_INTERVAL_MS) then
        return
    end

    local resourceTypes = GetResourcePowerTypes()
    local sampleLimit = tonumber(RESOURCE_SAMPLE_MAX_POINTS) or 1200

    local function PushSample(sampleList, value)
        sampleList[#sampleList + 1] = value
        local startIndex = tonumber(sampleList._cmStart) or 1
        local sampleCount = (#sampleList - startIndex) + 1
        if sampleCount > sampleLimit then
            startIndex = startIndex + (sampleCount - sampleLimit)
            sampleList._cmStart = startIndex
        else
            sampleList._cmStart = startIndex
        end

        -- Compact infrequently so we avoid O(n) front-shifts on every sample push.
        if startIndex > 256 then
            local dst = 1
            for i = startIndex, #sampleList do
                sampleList[dst] = sampleList[i]
                dst = dst + 1
            end
            for i = dst, #sampleList do
                sampleList[i] = nil
            end
            sampleList._cmStart = 1
        end
    end

    local healthPct = SafeGetPowerPctFromList(resourceTypes.health)
    local magickaPct = SafeGetPowerPctFromList(resourceTypes.magicka)
    local staminaPct = SafeGetPowerPctFromList(resourceTypes.stamina)
    local sampledAny = false

    if healthPct then
        PushSample(resourceSamples.healthPct, healthPct)
        sampledAny = true
    end
    if magickaPct then
        PushSample(resourceSamples.magickaPct, magickaPct)
        sampledAny = true
    end
    if staminaPct then
        PushSample(resourceSamples.staminaPct, staminaPct)
        sampledAny = true
    end

    local pingMs = SafeGetLatencyMs()
    if pingMs ~= nil then
        local pingSamples = resourceSamples.pingMs or {}
        resourceSamples.pingMs = pingSamples
        PushSample(pingSamples, pingMs)
        if resourceSamples.minPingMs == nil or pingMs < resourceSamples.minPingMs then
            resourceSamples.minPingMs = pingMs
        end
        if resourceSamples.maxPingMs == nil or pingMs > resourceSamples.maxPingMs then
            resourceSamples.maxPingMs = pingMs
        end

        local lastPing = resourceSamples.lastPingMs
        if lastPing ~= nil then
            local delta = pingMs - lastPing
            if delta <= -PING_DIP_DELTA_MS then
                resourceSamples.pingDipCount = (resourceSamples.pingDipCount or 0) + 1
            elseif delta >= PING_SPIKE_DELTA_MS then
                resourceSamples.pingSpikeCount = (resourceSamples.pingSpikeCount or 0) + 1
            end
        end

        if pingMs >= PING_HIGH_DELAY_MS then
            resourceSamples.highDelaySamples = (resourceSamples.highDelaySamples or 0) + 1
        end

        resourceSamples.lastPingMs = pingMs
        sampledAny = true
    end

    if sampledAny then
        resourceSamples.lastSampleMs = nowMs
        self.fight.snapshotRev = (self.fight.snapshotRev or 0) + 1
    end

    -- Track absolute resource deltas: positive = regen, negative = drain.
    local hpCurr   = SafeGetCurrentPowerFromList(resourceTypes.health)
    local magCurr  = SafeGetCurrentPowerFromList(resourceTypes.magicka)
    local stamCurr = SafeGetCurrentPowerFromList(resourceTypes.stamina)
    local ultCurr  = SafeGetCurrentPowerFromList(resourceTypes.ultimate)

    local function AccumulateDelta(lastKey, regenKey, drainKey, current)
        if current == nil then return end
        local last = resourceSamples[lastKey]
        if last ~= nil then
            local delta = current - last
            if delta > 0 then
                resourceSamples[regenKey] = (resourceSamples[regenKey] or 0) + delta
            elseif delta < 0 then
                resourceSamples[drainKey] = (resourceSamples[drainKey] or 0) - delta
            end
        end
        resourceSamples[lastKey] = current
    end

    AccumulateDelta("lastAbsHealth",   "totalHealthRegen",   "totalHealthDrain",   hpCurr)
    AccumulateDelta("lastAbsMagicka",  "totalMagickaRegen",  "totalMagickaDrain",  magCurr)
    AccumulateDelta("lastAbsStamina",  "totalStaminaRegen",  "totalStaminaDrain",  stamCurr)
    AccumulateDelta("lastAbsUltimate", "totalUltimateGen",   "totalUltimateDrain", ultCurr)

    if sampledAny and self.TraceResourceSample then
        self:TraceResourceSample(nowMs, hpCurr, magCurr, stamCurr, ultCurr, pingMs, forceSample)
    end
end

local function FormatWindowRelativeTime(offsetMs)
    local safeOffsetMs = math.max(0, math.floor(tonumber(offsetMs) or 0))
    local totalSeconds = math.floor(safeOffsetMs / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local millis = safeOffsetMs % 1000
    return string.format("t+%02d:%02d.%03d", minutes, seconds, millis)
end

local function FormatWindowDateTime(startTimestampSec, offsetMs)
    local epochStart = tonumber(startTimestampSec)
    if epochStart == nil then
        return "n/a"
    end

    if type(os) ~= "table" or type(os.date) ~= "function" then
        return "n/a"
    end

    local stamp = math.floor(epochStart + math.floor(math.max(0, tonumber(offsetMs) or 0) / 1000))
    local ok, formatted = pcall(os.date, "%Y-%m-%d %H:%M:%S", stamp)
    if ok and type(formatted) == "string" and formatted ~= "" then
        return formatted
    end

    return "n/a"
end

local function BuildThroughputWindowStats(windowTracker, fight, nowMs)
    local source = windowTracker or {}
    local tracker = {
        intervalMs = source.intervalMs,
        currentWindowIndex = source.currentWindowIndex,
        currentWindowValue = source.currentWindowValue,
        finalizedWindowCount = source.finalizedWindowCount,
        finalizedPeakValue = source.finalizedPeakValue,
        finalizedPeakIndex = source.finalizedPeakIndex,
        finalizedLowestValue = source.finalizedLowestValue,
        finalizedLowestIndex = source.finalizedLowestIndex,
        finalizedLowestNonZeroValue = source.finalizedLowestNonZeroValue,
        finalizedLowestNonZeroIndex = source.finalizedLowestNonZeroIndex,
    }
    local intervalMs = math.max(1, math.floor(tonumber(tracker.intervalMs) or tonumber(THROUGHPUT_WINDOW_INTERVAL_MS) or 1000))
    local startMs = tonumber(fight and fight.startMs) or tonumber(nowMs) or 0
    local endMs = tonumber((fight and fight.endMs) or nowMs) or startMs
    if endMs < startMs then
        endMs = startMs
    end

    local durationMs = math.max(0, endMs - startMs)
    local durationWindowIndex = 0
    if durationMs > 0 then
        durationWindowIndex = math.floor((durationMs - 1) / intervalMs)
    end
    local currentWindowIndex = math.max(0, math.floor(tonumber(tracker.currentWindowIndex) or 0))
    local targetWindowIndex = math.max(currentWindowIndex, durationWindowIndex)

    if targetWindowIndex > currentWindowIndex then
        local finalizedCount = tonumber(tracker.finalizedWindowCount) or 0
        local finalizedPeakValue = tonumber(tracker.finalizedPeakValue)
        local finalizedPeakIndex = tonumber(tracker.finalizedPeakIndex)
        local finalizedLowestValue = tonumber(tracker.finalizedLowestValue)
        local finalizedLowestIndex = tonumber(tracker.finalizedLowestIndex)
        local finalizedLowestNonZeroValue = tonumber(tracker.finalizedLowestNonZeroValue)
        local finalizedLowestNonZeroIndex = tonumber(tracker.finalizedLowestNonZeroIndex)
        local currentValue = tonumber(tracker.currentWindowValue) or 0

        finalizedCount = finalizedCount + 1
        if finalizedPeakValue == nil or currentValue > finalizedPeakValue then
            finalizedPeakValue = currentValue
            finalizedPeakIndex = currentWindowIndex
        end
        if finalizedLowestValue == nil or currentValue < finalizedLowestValue then
            finalizedLowestValue = currentValue
            finalizedLowestIndex = currentWindowIndex
        end
        if currentValue > 0 and (finalizedLowestNonZeroValue == nil or currentValue < finalizedLowestNonZeroValue) then
            finalizedLowestNonZeroValue = currentValue
            finalizedLowestNonZeroIndex = currentWindowIndex
        end

        if targetWindowIndex > (currentWindowIndex + 1) then
            local firstGapIndex = currentWindowIndex + 1
            local gapCount = targetWindowIndex - currentWindowIndex - 1
            finalizedCount = finalizedCount + gapCount

            if finalizedPeakValue == nil or 0 > finalizedPeakValue then
                finalizedPeakValue = 0
                finalizedPeakIndex = firstGapIndex
            end
            if finalizedLowestValue == nil or 0 < finalizedLowestValue then
                finalizedLowestValue = 0
                finalizedLowestIndex = firstGapIndex
            end
        end

        tracker.finalizedWindowCount = finalizedCount
        tracker.finalizedPeakValue = finalizedPeakValue
        tracker.finalizedPeakIndex = finalizedPeakIndex
        tracker.finalizedLowestValue = finalizedLowestValue
        tracker.finalizedLowestIndex = finalizedLowestIndex
        tracker.finalizedLowestNonZeroValue = finalizedLowestNonZeroValue
        tracker.finalizedLowestNonZeroIndex = finalizedLowestNonZeroIndex
        tracker.currentWindowIndex = targetWindowIndex
        tracker.currentWindowValue = 0
    end

    local peakValue = tonumber(tracker.finalizedPeakValue)
    local peakIndex = tonumber(tracker.finalizedPeakIndex)
    local lowestValue = tonumber(tracker.finalizedLowestValue)
    local lowestIndex = tonumber(tracker.finalizedLowestIndex)
    local lowestNonZeroValue = tonumber(tracker.finalizedLowestNonZeroValue)
    local lowestNonZeroIndex = tonumber(tracker.finalizedLowestNonZeroIndex)
    local currentValue = tonumber(tracker.currentWindowValue) or 0

    if peakValue == nil or currentValue > peakValue then
        peakValue = currentValue
        peakIndex = targetWindowIndex
    end

    if lowestValue == nil or currentValue < lowestValue then
        lowestValue = currentValue
        lowestIndex = targetWindowIndex
    end

    if currentValue > 0 and (lowestNonZeroValue == nil or currentValue < lowestNonZeroValue) then
        lowestNonZeroValue = currentValue
        lowestNonZeroIndex = targetWindowIndex
    end

    -- Ignore zero windows for "lowest" when the fight has any non-zero window.
    if lowestNonZeroValue ~= nil then
        lowestValue = lowestNonZeroValue
        lowestIndex = lowestNonZeroIndex
    end

    peakValue = peakValue or 0
    lowestValue = lowestValue or 0
    peakIndex = peakIndex or 0
    lowestIndex = lowestIndex or 0

    local peakOffsetMs = peakIndex * intervalMs
    local lowestOffsetMs = lowestIndex * intervalMs
    local startTimestampSec = fight and fight.startTimestampSec or nil

    return {
        intervalMs = intervalMs,
        windowCount = targetWindowIndex + 1,
        peakValue = peakValue,
        peakWindowIndex = peakIndex,
        peakWindowOffsetMs = peakOffsetMs,
        peakWindowTime = FormatWindowRelativeTime(peakOffsetMs),
        peakWindowDateTime = FormatWindowDateTime(startTimestampSec, peakOffsetMs),
        lowestValue = lowestValue,
        lowestWindowIndex = lowestIndex,
        lowestWindowOffsetMs = lowestOffsetMs,
        lowestWindowTime = FormatWindowRelativeTime(lowestOffsetMs),
        lowestWindowDateTime = FormatWindowDateTime(startTimestampSec, lowestOffsetMs),
    }
end

function ConsoleMetrics:BuildFightSummaryFromFight(fight, nowMs)
    local duration = GetFightDurationSeconds(fight, nowMs)
    local totalDamage = fight.totalDamage or 0
    local totalHeal = fight.totalHeal or 0
    local totalTaken = fight.totalTaken or 0
    local hits = fight.hits or 0
    local crits = fight.crits or 0
    local dps = duration > 0 and (totalDamage / duration) or 0
    local hps = duration > 0 and (totalHeal / duration) or 0
    local critPct = hits > 0 and ((crits / hits) * 100) or 0

    local snapshotRev = tonumber(fight.snapshotRev) or 0
    local sortCache = fight.summarySortCache
    if not sortCache or sortCache.rev ~= snapshotRev then
        local targetList = {}
        for _, target in pairs(fight.targetMap or {}) do
            local estimatedResistance, mitigationPct = EstimateTargetResistance(target)
            targetList[#targetList + 1] = {
                name = target.name,
                damage = target.damage,
                effective = target.effective,
                overflow = target.overflow,
                blocked = target.blocked,
                shielded = target.shielded,
                hits = target.hits,
                estimatedResistance = estimatedResistance,
                mitigationPct = mitigationPct,
            }
        end

        table.sort(targetList, function(a, b)
            return a.damage > b.damage
        end)

        sortCache = {
            rev = snapshotRev,
            skillList = SortSkillEntries(fight.skillMap or {}),
            healSkillList = SortSkillEntriesByHeal(fight.skillMap or {}),
            incomingSkillList = SortSkillEntries(fight.incomingSkillMap or {}),
            incomingSetDamageList = SortSkillEntries(fight.incomingSetDamageMap or {}),
            incomingLikelySetProcList = SortSkillEntries(fight.incomingLikelySetProcMap or {}),
            dotList = SortSkillEntries(fight.dotMap or {}),
            hotList = SortSkillEntriesByHeal(fight.hotMap or {}),
            targetList = targetList,
        }
        fight.summarySortCache = sortCache
    end

    local function CloneListShallow(list)
        local clone = {}
        for i = 1, #list do
            clone[i] = list[i]
        end
        return clone
    end

    -- Build pre-sorted lists once so live and historical views share identical ordering.
    local protectionSummary = BuildProtectionSummary(fight.protectionInfo, nowMs)
    local allEffectList = BuildTrackedEffectList(fight.allEffects, duration, nowMs)
    local majorMinorList = BuildTrackedEffectList(fight.majorMinorEffects, duration, nowMs)
    local setProcList = BuildTrackedEffectList(fight.setEffects, duration, nowMs)
    local buffList    = BuildTrackedEffectList(fight.buffEffects,   duration, nowMs)
    local debuffList  = BuildTrackedEffectList(fight.debuffEffects, duration, nowMs)
    local resourceSamples = fight.resourceSamples or {}
    local healthResourceSummary = BuildResourceSampleSummary(resourceSamples.healthPct or {})
    local magickaResourceSummary = BuildResourceSampleSummary(resourceSamples.magickaPct or {})
    local staminaResourceSummary = BuildResourceSampleSummary(resourceSamples.staminaPct or {})
    local pingSampleSummary = BuildNumericSampleSummary(resourceSamples.pingMs or {})
    local sustainSummary = BuildSustainPerformanceSummary(magickaResourceSummary, staminaResourceSummary)
    local resourceSampleCount = math.max(healthResourceSummary.samples, magickaResourceSummary.samples, staminaResourceSummary.samples, pingSampleSummary.samples)
    local burstWindowStats = BuildThroughputWindowStats(fight.damageWindowTracker, fight, nowMs)
    local healingWindowStats = BuildThroughputWindowStats(fight.healWindowTracker, fight, nowMs)
    local incomingSkillList = CloneListShallow(sortCache.incomingSkillList or {})
    local incomingSetDamageList = CloneListShallow(sortCache.incomingSetDamageList or {})
    local incomingLikelySetProcList = CloneListShallow(sortCache.incomingLikelySetProcList or {})

    return {
        startMs = fight.startMs,
        endMs = fight.endMs,
        duration = duration,
        dps = dps,
        hps = hps,
        totalDamage = totalDamage,
        totalOverflowDamage = fight.totalOverflowDamage or 0,
        totalBlockedDamage = fight.totalBlockedDamage or 0,
        totalShieldedDamage = fight.totalShieldedDamage or 0,
        totalHeal = totalHeal,
        totalOverflowHeal = fight.totalOverflowHeal or 0,
        totalTaken = totalTaken,
        totalIncomingOverflowDamage = fight.totalIncomingOverflowDamage or 0,
        totalIncomingBlockedDamage = fight.totalIncomingBlockedDamage or 0,
        totalIncomingShieldedDamage = fight.totalIncomingShieldedDamage or 0,
        minHitValue = fight.minHitValue,
        maxHitValue = fight.maxHitValue,
        critPct = critPct,
        skillList = CloneListShallow(sortCache.skillList or {}),
        healSkillList = CloneListShallow(sortCache.healSkillList or {}),
        incomingSkillList = incomingSkillList,
        incomingSetDamageList = incomingSetDamageList,
        incomingLikelySetProcList = incomingLikelySetProcList,
        dotList = CloneListShallow(sortCache.dotList or {}),
        hotList = CloneListShallow(sortCache.hotList or {}),
        targetList = CloneListShallow(sortCache.targetList or {}),
        peakDps = fight.peakDps or 0,
        peakHps = fight.peakHps or 0,
        burstWindowStats = burstWindowStats,
        healingWindowStats = healingWindowStats,
        topHealingMoments = CloneMoments(fight.topHealingMoments or {}),
        topMitigationMoments = CloneMoments(fight.topMitigationMoments or {}),
        allEffectList = allEffectList,
        majorMinorList = majorMinorList,
        setProcList = setProcList,
        buffList    = buffList,
        debuffList  = debuffList,
        protectionSummary = protectionSummary,
        inferredProtectionLabel = (fight.protectionInfo and fight.protectionInfo.currentLabel) or "No mitigation data",
        inferredProtectionConfidence = (fight.protectionInfo and fight.protectionInfo.confidence) or 0,
        inferredDrPct = (fight.protectionInfo and fight.protectionInfo.currentDrPct) or 0,
        resourceSummary = {
            sampleCount = resourceSampleCount,
            health = healthResourceSummary,
            magicka = magickaResourceSummary,
            stamina = staminaResourceSummary,
            sustain = sustainSummary,
            totalHealthRegen  = resourceSamples.totalHealthRegen  or 0,
            totalHealthDrain  = resourceSamples.totalHealthDrain  or 0,
            totalMagickaRegen = resourceSamples.totalMagickaRegen or 0,
            totalMagickaDrain = resourceSamples.totalMagickaDrain or 0,
            totalStaminaRegen = resourceSamples.totalStaminaRegen or 0,
            totalStaminaDrain = resourceSamples.totalStaminaDrain or 0,
            totalUltimateGen  = resourceSamples.totalUltimateGen  or 0,
            totalUltimateDrain = resourceSamples.totalUltimateDrain or 0,
            ping = {
                hasData = pingSampleSummary.hasData,
                samples = pingSampleSummary.samples,
                averageMs = pingSampleSummary.average,
                medianMs = pingSampleSummary.median,
                minMs = pingSampleSummary.min,
                maxMs = pingSampleSummary.max,
                dips = resourceSamples.pingDipCount or 0,
                spikes = resourceSamples.pingSpikeCount or 0,
                highDelaySamples = resourceSamples.highDelaySamples or 0,
                highDelayThresholdMs = PING_HIGH_DELAY_MS,
            },
        },
    }
end

local function TrimListInPlace(list, limit)
    if type(list) ~= "table" then
        return
    end

    while #list > limit do
        table.remove(list)
    end
end

function ConsoleMetrics:CompactFightSummaryForHistory(summary)
    if type(summary) ~= "table" then
        return summary
    end

    local listLimit = tonumber(LOW_MEMORY_LIST_LIMIT) or 20
    local momentsLimit = tonumber(LOW_MEMORY_MOMENTS_LIMIT) or 12
    local effectLimit = tonumber(LOW_MEMORY_EFFECT_LIMIT) or 20

    TrimListInPlace(summary.skillList, listLimit)
    TrimListInPlace(summary.healSkillList, listLimit)
    TrimListInPlace(summary.incomingSkillList, listLimit)
    TrimListInPlace(summary.incomingSetDamageList, listLimit)
    TrimListInPlace(summary.incomingLikelySetProcList, listLimit)
    TrimListInPlace(summary.dotList, listLimit)
    TrimListInPlace(summary.hotList, listLimit)
    TrimListInPlace(summary.targetList, listLimit)
    TrimListInPlace(summary.topHealingMoments, momentsLimit)
    TrimListInPlace(summary.topMitigationMoments, momentsLimit)
    TrimListInPlace(summary.allEffectList, effectLimit)
    TrimListInPlace(summary.majorMinorList, effectLimit)
    TrimListInPlace(summary.setProcList, effectLimit)
    TrimListInPlace(summary.buffList,   effectLimit)
    TrimListInPlace(summary.debuffList, effectLimit)

    return summary
end

function ConsoleMetrics:ApplyLowMemoryModeToHistory()
    if not (self.saved and self.saved.lowMemoryMode) then
        return
    end

    for i = 1, #(self.fightHistory or {}) do
        self:CompactFightSummaryForHistory(self.fightHistory[i])
    end
end

function ConsoleMetrics:RecordTopHealingMoment(abilityId, abilityName, targetName, effectiveHeal, overflowHeal, isCrit)
    if not self.fight then
        return
    end

    local totalHeal = (effectiveHeal or 0) + (overflowHeal or 0)
    if totalHeal <= 0 then
        return
    end

    local critTag = isCrit and " [CRIT]" or ""
    local healHex = isCrit and COMBAT_COLOR_HEX.healCrit or COMBAT_COLOR_HEX.heal
    local overflowTag = (overflowHeal or 0) > 0 and string.format(" (+%s ovh)", ColorShort(overflowHeal, COMBAT_COLOR_HEX.overflow)) or ""
    AddTopMoment(self.fight.topHealingMoments, {
        value = totalHeal,
        abilityId = SafeAbilityId(abilityId),
        abilityName = abilityName,
        effectName = abilityName,
        label = string.format("+%s  %s%s", ColorShort(totalHeal, healHex), FormatAbilityIdentity(abilityName, abilityId), critTag),
        tooltip = string.format("Healed %s for %s%s | Ability: %s", targetName, NumberText(effectiveHeal or 0), overflowTag, FormatAbilityIdentity(abilityName, abilityId)),
    })
end

function ConsoleMetrics:RecordTopMitigationMoment(labelPrefix, actorName, reason, amount, abilityId, abilityName)
    if not self.fight or amount <= 0 then
        return
    end

    AddTopMoment(self.fight.topMitigationMoments, {
        value = amount,
        abilityId = SafeAbilityId(abilityId),
        abilityName = abilityName,
        effectName = abilityName,
        label = string.format("%s%s  %s (%s)", labelPrefix, ColorShort(amount, COMBAT_COLOR_HEX.mitigation), actorName, reason),
        tooltip = string.format("%s via %s", reason, FormatAbilityIdentity(abilityName, abilityId)),
    })
end

-- Central effect tracker used by the Buff Uptime panel.
-- It records all effects first, then derives focused subsets (Major/Minor and popular sets).
function ConsoleMetrics:TrackMajorMinorAndSets(nowMs, result, abilityId, abilityName, sourceIsPlayer, targetIsPlayer, didDamage, didHeal, totalValue)
    if not self.fight or not abilityName or abilityName == "" then
        return
    end

    local touchesPlayer = sourceIsPlayer or targetIsPlayer
    if not touchesPlayer then
        return
    end

    local gained = IsEffectGainedResult(result)
    local faded = IsEffectFadedResult(result)
    local lowerName = string.lower(abilityName)

    if gained or faded then
        local allEffectTrack = AcquireTrackedEffect(self.fight.allEffects, lowerName, abilityName, "Effect", abilityId, abilityName)
        if gained then
            StartTrackedEffect(allEffectTrack, nowMs)
        else
            StopTrackedEffect(allEffectTrack, nowMs)
        end

        -- Buff/debuff separation: effect on player = buff; player applies to enemy = debuff.
        if targetIsPlayer then
            local buffTrack = AcquireTrackedEffect(self.fight.buffEffects, lowerName, abilityName, "Buff", abilityId, abilityName)
            if gained then StartTrackedEffect(buffTrack, nowMs) else StopTrackedEffect(buffTrack, nowMs) end
        elseif sourceIsPlayer then
            local debuffTrack = AcquireTrackedEffect(self.fight.debuffEffects, lowerName, abilityName, "Debuff", abilityId, abilityName)
            if gained then StartTrackedEffect(debuffTrack, nowMs) else StopTrackedEffect(debuffTrack, nowMs) end
        end
    end

    -- Use pre-lowered lowerName directly; avoids a second string.lower inside IsMajorMinorEffectName.
    local isMajorEffect = string.find(lowerName, "major ", 1, true) == 1
    if isMajorEffect or string.find(lowerName, "minor ", 1, true) == 1 then
        local category = isMajorEffect and "Major" or "Minor"
        local majorMinorTrack = AcquireTrackedEffect(self.fight.majorMinorEffects, lowerName, abilityName, category, abilityId, abilityName)

        if gained then
            StartTrackedEffect(majorMinorTrack, nowMs)
        elseif faded then
            StopTrackedEffect(majorMinorTrack, nowMs)
        end

        if didDamage or didHeal then
            majorMinorTrack.procs = (majorMinorTrack.procs or 0) + 1
            majorMinorTrack.totalValue = (majorMinorTrack.totalValue or 0) + (totalValue or 0)
        end
    end

    local setMatch = self:MatchTrackedSet(abilityId, abilityName)
    if setMatch then
        local setKey = string.lower(setMatch.label)
        local setTrack = AcquireTrackedEffect(self.fight.setEffects, setKey, setMatch.label, setMatch.scene, abilityId, abilityName)

        if gained then
            StartTrackedEffect(setTrack, nowMs)
        elseif faded then
            StopTrackedEffect(setTrack, nowMs)
        end

        if didDamage or didHeal then
            setTrack.procs = (setTrack.procs or 0) + 1
            setTrack.totalValue = (setTrack.totalValue or 0) + (totalValue or 0)
        end
    end
end

function ConsoleMetrics:UpdateProtectionInference(nowMs)
    if not self.fight or not self.fight.protectionInfo then
        return
    end

    local topTarget = nil
    local topDamage = -1
    for _, target in pairs(self.fight.targetMap or {}) do
        local damage = tonumber(target.damage) or 0
        if damage > topDamage then
            topDamage = damage
            topTarget = target
        end
    end

    local estimatedResistance = nil
    if topTarget then
        estimatedResistance = EstimateTargetResistance(topTarget)
    end

    local hasData = estimatedResistance ~= nil
    local resistance = estimatedResistance or 0
    local drPct = hasData and Clamp((resistance / RESISTANCE_SCALE) * 100, 0, 50) or 0

    local info = self.fight.protectionInfo
    local alpha = Clamp(tonumber(self.saved.drSampleAlpha) or self.defaults.drSampleAlpha, 0.05, 0.85)
    if info.samples <= 0 then
        info.drEma = drPct
    else
        info.drEma = (alpha * drPct) + ((1 - alpha) * (info.drEma or drPct))
    end

    local inferredLabel, inferredKey, confidence = InferProtectionFromDr(info.drEma or drPct, hasData)

    local previousState = info.currentState or "unknown"
    local elapsed = 0
    if info.lastSampleMs and nowMs > info.lastSampleMs then
        elapsed = nowMs - info.lastSampleMs
    end
    if elapsed > 0 then
        info.stateMs[previousState] = (info.stateMs[previousState] or 0) + elapsed
    end

    info.currentState = inferredKey
    info.currentLabel = inferredLabel
    info.currentResistance = resistance
    info.currentDrPct = drPct
    info.confidence = confidence
    info.lastSampleMs = nowMs
    info.samples = (info.samples or 0) + 1
    self.fight.snapshotRev = (self.fight.snapshotRev or 0) + 1
end

local function RuleToMatchResult(rule, safeId)
    return {
        label            = rule.label or string.format("Custom Set %d", safeId),
        scene            = NormalizeCustomSetScene(rule.scene),
        fromCustom       = not rule.fromPCT,
        fromPCT          = rule.fromPCT or false,
        cooldownDurationMs = rule.cooldownDurationMs,
        procType         = rule.procType,
        result           = rule.result,
        texture          = rule.texture,
        showFrame        = rule.showFrame,
        description      = rule.description,
        settingsColor    = rule.settingsColor,
    }
end

function ConsoleMetrics:MatchCustomSetRule(abilityId, abilityName)
    if not self.saved or type(self.saved.customSetRules) ~= "table" then
        return nil
    end

    local safeId = SafeAbilityId(abilityId)
    local lowerName = string.lower(abilityName or "")

    -- Prefer exact abilityId match first; check primary abilityId and all entries in abilityIds.
    if safeId > 0 then
        for i = 1, #self.saved.customSetRules do
            local rule = self.saved.customSetRules[i]
            -- Check primary stored ID.
            if SafeAbilityId(rule.abilityId) == safeId then
                return RuleToMatchResult(rule, safeId)
            end
            -- Check multi-ID list (PCT sets like Pirate Skeleton).
            if type(rule.abilityIds) == "table" then
                for k = 1, #rule.abilityIds do
                    if SafeAbilityId(rule.abilityIds[k]) == safeId then
                        return RuleToMatchResult(rule, safeId)
                    end
                end
            end
        end
    end

    if lowerName == "" then
        return nil
    end

    for i = 1, #self.saved.customSetRules do
        local rule = self.saved.customSetRules[i]
        local aliases = rule.aliases
        if type(aliases) ~= "table" then
            aliases = BuildCustomAliasList(rule.abilityName)
            rule.aliases = aliases
        end
        for j = 1, #aliases do
            local alias = aliases[j]
            if alias ~= "" and string.find(lowerName, alias, 1, true) ~= nil then
                return RuleToMatchResult(rule, SafeAbilityId(rule.abilityId))
            end
        end
    end

    return nil
end

function ConsoleMetrics:InvalidateTrackedSetMatchCache()
    self.trackedSetMatchById = {}
    self.trackedSetMatchByName = {}
end

function ConsoleMetrics:MatchTrackedSet(abilityId, abilityName)
    local byId = self.trackedSetMatchById
    if type(byId) ~= "table" then
        byId = {}
        self.trackedSetMatchById = byId
    end

    local byName = self.trackedSetMatchByName
    if type(byName) ~= "table" then
        byName = {}
        self.trackedSetMatchByName = byName
    end

    local safeId = SafeAbilityId(abilityId)
    if safeId > 0 then
        local cachedById = byId[safeId]
        if cachedById ~= nil then
            return cachedById or nil
        end
    end

    local lowerName = string.lower(abilityName or "")
    if lowerName ~= "" then
        local cachedByName = byName[lowerName]
        if cachedByName ~= nil then
            if safeId > 0 then
                byId[safeId] = cachedByName
            end
            return cachedByName or nil
        end
    end

    local matched = self:MatchCustomSetRule(safeId, abilityName)
    if not matched then
        matched = MatchPopularSet(abilityName)
    end

    local cachedValue = matched or false
    if safeId > 0 then
        byId[safeId] = cachedValue
    end
    if lowerName ~= "" then
        byName[lowerName] = cachedValue
    end

    return matched
end

function ConsoleMetrics:AddCustomSetRule(label, scene, abilityId, abilityName)
    if not self.saved then
        return false, "Settings are not initialized yet."
    end

    self.saved.customSetRules = self.saved.customSetRules or {}

    local cleanName = TrimText(abilityName)
    local cleanLabel = TrimText(label)
    local safeId = SafeAbilityId(abilityId)
    local normalizedScene = NormalizeCustomSetScene(scene)

    if cleanLabel == "" then
        if cleanName ~= "" then
            cleanLabel = cleanName
        elseif safeId > 0 then
            cleanLabel = string.format("Custom Set %d", safeId)
        else
            return false, "Add Custom Set: provide ability ID and/or ability name."
        end
    end

    if safeId <= 0 and cleanName == "" then
        return false, "Add Custom Set: provide ability ID and/or ability name."
    end

    local aliases = BuildCustomAliasList(cleanName)
    for i = 1, #self.saved.customSetRules do
        local existing = self.saved.customSetRules[i]
        local existingId = SafeAbilityId(existing.abilityId)
        local existingName = string.lower(TrimText(existing.abilityName))
        if safeId > 0 and existingId == safeId then
            return false, string.format("Custom set already exists for ability ID %d.", safeId)
        end
        if cleanName ~= "" and existingName ~= "" and existingName == string.lower(cleanName) then
            return false, string.format("Custom set already exists for ability name '%s'.", cleanName)
        end
    end

    self.saved.customSetRules[#self.saved.customSetRules + 1] = {
        label    = cleanLabel,
        scene    = normalizedScene,
        abilityId = safeId,
        abilityIds = { safeId },
        abilityName = cleanName,
        aliases  = aliases,
        fromCustom = true,
    }

    self:InvalidateTrackedSetMatchCache()

    return true, string.format("Added custom set rule: %s (scene=%s, id=%d, name=%s)", cleanLabel, normalizedScene, safeId, cleanName ~= "" and cleanName or "n/a")
end

-- Import one full PvPCooldownTracker Data.Sets entry by set name key.
-- Handles id as number or array, carries all PCT fields verbatim.
function ConsoleMetrics:AddPCTSetEntry(setName, entry)
    if not self.saved then
        return false, "Settings not initialized."
    end

    self.saved.customSetRules = self.saved.customSetRules or {}

    local cleanLabel = TrimText(setName)
    if cleanLabel == "" then
        return false, "PCT entry has no set name."
    end

    -- Deduplicate by normalized label.
    local lowerLabel = string.lower(cleanLabel)
    for i = 1, #self.saved.customSetRules do
        if string.lower(TrimText(self.saved.customSetRules[i].label)) == lowerLabel then
            return false, string.format("Already have rule for '%s'.", cleanLabel)
        end
    end

    -- Normalise id: may be number or array of numbers.
    local primaryId = 0
    local allIds = {}
    if type(entry.id) == "table" then
        for _, v in ipairs(entry.id) do
            local sid = SafeAbilityId(v)
            if sid > 0 then
                allIds[#allIds + 1] = sid
            end
        end
        primaryId = allIds[1] or 0
    else
        primaryId = SafeAbilityId(entry.id)
        if primaryId > 0 then
            allIds[1] = primaryId
        end
    end

    -- Derive scene from procType (synergies/passives -> PvE leaning; sets -> PvP default).
    local scene = "PvP"
    if type(entry.procType) == "string" then
        local pt = string.lower(entry.procType)
        if pt == "synergy" or pt == "passive" then
            scene = "PvE"
        end
    end

    self.saved.customSetRules[#self.saved.customSetRules + 1] = {
        label              = cleanLabel,
        scene              = scene,
        abilityId          = primaryId,
        abilityIds         = allIds,
        abilityName        = "",
        aliases            = {},
        fromPCT            = true,
        -- Full PCT fields preserved:
        cooldownDurationMs = tonumber(entry.cooldownDurationMs),
        procType           = type(entry.procType) == "string" and entry.procType or nil,
        result             = tonumber(entry.result),
        texture            = type(entry.texture) == "string" and entry.texture or nil,
        showFrame          = entry.showFrame ~= false,
        description        = type(entry.description) == "string" and entry.description or nil,
        settingsColor      = type(entry.settingsColor) == "string" and entry.settingsColor or nil,
    }

    self:InvalidateTrackedSetMatchCache()

    return true, string.format("Imported: %s (id=%d, cooldown=%sms)",
        cleanLabel, primaryId, tostring(tonumber(entry.cooldownDurationMs) or "?"))
end

function ConsoleMetrics:ImportSetsFromPvPCooldownTracker()
    if not self.saved then
        return 0, "Settings are not initialized yet."
    end

    -- Primary path: PvPCooldownTracker.Data.Sets is the canonical structured source.
    -- Each key is the set display name; value contains id, cooldownDurationMs, procType, result, etc.
    local g = type(_G) == "table" and _G or nil
    local pct = g and g.PvPCooldownTracker or nil
    local dataTable = pct and type(pct.Data) == "table" and pct.Data.Sets or nil

    if type(dataTable) ~= "table" then
        return 0, "PvPCooldownTracker.Data.Sets not found. Ensure PvPCooldownTracker is loaded before importing."
    end

    local addedCount = 0
    local skippedCount = 0
    local messages = {}

    for setName, entry in pairs(dataTable) do
        if type(setName) == "string" and type(entry) == "table" then
            local ok, msg = self:AddPCTSetEntry(setName, entry)
            if ok then
                addedCount = addedCount + 1
            else
                skippedCount = skippedCount + 1
                -- Only collect non-duplicate skip messages for debugging.
                if not string.find(msg, "Already have rule", 1, true) then
                    messages[#messages + 1] = msg
                end
            end
        end
    end

    if addedCount == 0 and skippedCount == 0 then
        return 0, "PvPCooldownTracker.Data.Sets is empty."
    end

    if addedCount == 0 then
        return 0, string.format("No new entries imported (%d already present).", skippedCount)
    end

    local summary = string.format("Imported %d set rules from PvPCooldownTracker", addedCount)
    if skippedCount > 0 then
        summary = summary .. string.format(" (%d already present, skipped)", skippedCount)
    end
    summary = summary .. "."

    if #messages > 0 then
        for i = 1, math.min(5, #messages) do
            self:Print("PCT import: " .. messages[i])
        end
    end

    return addedCount, summary
end

function ConsoleMetrics:PrintHelp()
    local helpLines = {
        "Commands:",
        "/cm view - Open the Console Metrics dialog.",
        "/cm close - Close the dialog immediately.",
        "/cm prev - View the previous saved fight.",
        "/cm next - View the next saved fight.",
        "/cm clear - Clear live fight data and all history.",
        "/cm savefight [name] - Save the currently viewed fight to a persistent slot.",
        "/cm loadfight <name> - Load one saved fight by name into history.",
        "/cm loadfightexact <name> - Load one saved fight by exact name only.",
        "/cm loadsaves - Load all saved fight slots into session fight history.",
        "/cm debugbuild - Print build snapshot debug details.",
        "/cm trace on|off - Enable or disable live event/resource trace output.",
        "/cm trace mode summary|all|in|out - Choose trace scope.",
        "/cm trace target off|reticle|<name> - Restrict trace to one target.",
        "/cm trace focus on|off - Skip non-target combat processing during trace.",
        "/cm trace samples on|off - Toggle non-target sample skipping in focus mode.",
        "/cm trace min <value> - Ignore per-event trace lines below this value.",
        "/cm trace cap <lines/sec> - Limit trace print spam per second.",
        "/cm trace status - Print current trace mode and limits.",
        "WARNING: Trace logging is expensive on console. Keep it short and disable with /cm trace off after debugging.",
        "/cm linkbuild - Pre-fill chat with a compact build summary to share.",
        "/cm dumpcpslottables - Dump confirmed Champion slottable skill IDs.",
        "/cm autoclear on|off - Toggle auto clear when a new fight starts.",
        "/cm autohide on|off - Toggle dialog auto close after combat.",
        "/cm perf on|off|status - Toggle Series S performance preset mode.",
        "/cm inject - Retry Journal menu/keybind integration.",
        "/cm reset - Reset addon options to defaults.",
        "/cm dumpsets - Dump all game item sets (API) and session-observed ability IDs.",
        "/cm importpct - Import custom set rules from PvPCooldownTracker.",
        "/cm addset <label>|<scene>|<abilityId>|<abilityName> - Add custom set matcher.",
    }

    for i = 1, #helpLines do
        self:Print(helpLines[i])
    end
end

function ConsoleMetrics:RegisterLAMSettings()
    if not LibAddonMenu2 then
        return
    end

    local panelData = {
        type = "panel",
        name = "Console Metrics",
        displayName = "Console Metrics",
        author = "Vixen Hunny",
        version = self.version,
        registerForRefresh = true,
    }
    local sceneChoices = { "PvP", "PvE", "Custom" }
    local function NormalizeDraftAbilityId()
        local id = SafeAbilityId(self.saved.customSetDraftAbilityId)
        if id > 0 then
            return tostring(id)
        end
        return ""
    end
        local optionsTable = {
                {
                    type = "button",
                    name = "Open Console Metrics",
                    tooltip = "Opens the combat metrics dialog window",
                    func = function()
                        self:OpenFightViewDialog(true)
                    end,
                    width = "full",
                },
                {
                    type = "header",
                    name = "Dialog Options",
                },
                {
                    type = "checkbox",
                    name = "Auto Hide Dialog",
                    tooltip = "Automatically close the dialog after leaving combat",
                    getFunc = function()
                        return self.saved.dialogAutoHide
                    end,
                    setFunc = function(value)
                        self.saved.dialogAutoHide = value
                        self:ArmDialogAutoHide()
                    end,
                    default = self.defaults.dialogAutoHide,
                },
                {
                    type = "slider",
                    name = "Auto Hide Delay (seconds)",
                    tooltip = "How long to wait after combat ends before closing the dialog",
                    getFunc = function()
                        return self.saved.dialogAutoHideSeconds
                    end,
                    setFunc = function(value)
                        self.saved.dialogAutoHideSeconds = value
                        self:ArmDialogAutoHide()
                    end,
                    min = 3,
                    max = 120,
                    step = 1,
                    default = self.defaults.dialogAutoHideSeconds,
                },
                {
                    type = "checkbox",
                    name = "Auto Clear on Next Fight",
                    tooltip = "Clear displayed metrics when a new fight starts",
                    getFunc = function()
                        return self.saved.autoClearOnNextFight
                    end,
                    setFunc = function(value)
                        self.saved.autoClearOnNextFight = value
                    end,
                    default = self.defaults.autoClearOnNextFight,
                },
                {
                    type = "slider",
                    name = "Max Fight History",
                    tooltip = "Maximum number of previous fights to keep in history",
                    getFunc = function()
                        return self.saved.maxFightHistory
                    end,
                    setFunc = function(value)
                        self.saved.maxFightHistory = value
                        self:EnforceFightHistoryLimit()
                    end,
                    min = 5,
                    max = tonumber(MAX_FIGHT_HISTORY_HARD_CAP) or 40,
                    step = 1,
                    default = self.defaults.maxFightHistory,
                },
                {
                    type = "checkbox",
                    name = "Low Memory Mode",
                    tooltip = "Compacts stored history snapshots (top-N lists) to reduce memory on console.",
                    getFunc = function()
                        return self.saved.lowMemoryMode == true
                    end,
                    setFunc = function(value)
                        self.saved.lowMemoryMode = value == true
                        if self.saved.lowMemoryMode then
                            self:ApplyLowMemoryModeToHistory()
                        end
                        self:EnforceFightHistoryLimit()
                    end,
                    default = self.defaults.lowMemoryMode,
                },
                {
                    type = "checkbox",
                    name = "Performance Mode (Series S)",
                    tooltip = "Applies conservative update rates and disables costly features for smoother console frame times.",
                    getFunc = function()
                        return self.saved.performanceMode == true
                    end,
                    setFunc = function(value)
                        self.saved.performanceMode = value == true
                        if self.saved.performanceMode then
                            self:ApplyConsolePerformancePreset()
                        end
                    end,
                    default = self.defaults.performanceMode,
                },
                {
                    type = "checkbox",
                    name = "Enable ML Behavior Model",
                    tooltip = "When off, disables behavior prediction math and returns lightweight placeholder values for better performance.",
                    getFunc = function()
                        return self.saved.behaviorModelEnabled == true
                    end,
                    setFunc = function(value)
                        self.saved.behaviorModelEnabled = value == true
                        self.behaviorModelCache = nil
                    end,
                    default = self.defaults.behaviorModelEnabled,
                },
                {
                    type = "slider",
                    name = "ML DR Learning Weight",
                    tooltip = "Higher values adapt faster to changes in inferred DR",
                    getFunc = function()
                        return math.floor((self.saved.drSampleAlpha or self.defaults.drSampleAlpha) * 100 + 0.5)
                    end,
                    setFunc = function(value)
                        self.saved.drSampleAlpha = Clamp(value / 100, 0.05, 0.85)
                    end,
                    disabled = function()
                        return self.saved.behaviorModelEnabled ~= true
                    end,
                    min = 5,
                    max = 85,
                    step = 1,
                    default = math.floor(self.defaults.drSampleAlpha * 100 + 0.5),
                },
                {
                    type = "header",
                    name = "Custom Set Matching",
                },
                {
                    type = "description",
                    text = "Add custom set rules by ability ID/name and optionally import from PvPCooldownTracker.",
                    width = "full",
                },
                {
                    type = "editbox",
                    name = "Set Label",
                    tooltip = "Friendly label for this set entry in panel output.",
                    getFunc = function()
                        return self.saved.customSetDraftLabel or ""
                    end,
                    setFunc = function(value)
                        self.saved.customSetDraftLabel = TrimText(value)
                    end,
                    width = "full",
                },
                {
                    type = "dropdown",
                    name = "Set Scene",
                    tooltip = "Classification tag shown in set-proc rows.",
                    choices = sceneChoices,
                    getFunc = function()
                        return NormalizeCustomSetScene(self.saved.customSetDraftScene)
                    end,
                    setFunc = function(value)
                        self.saved.customSetDraftScene = NormalizeCustomSetScene(value)
                    end,
                    width = "half",
                },
                {
                    type = "editbox",
                    name = "Ability ID",
                    tooltip = "Exact match ability ID (optional, but recommended).",
                    getFunc = function()
                        return NormalizeDraftAbilityId()
                    end,
                    setFunc = function(value)
                        self.saved.customSetDraftAbilityId = TrimText(value)
                    end,
                    width = "half",
                },
                {
                    type = "editbox",
                    name = "Ability Name / Alias",
                    tooltip = "Name matcher. Comma-separated tokens are accepted as aliases.",
                    getFunc = function()
                        return self.saved.customSetDraftAbilityName or ""
                    end,
                    setFunc = function(value)
                        self.saved.customSetDraftAbilityName = TrimText(value)
                    end,
                    width = "full",
                },
                {
                    type = "button",
                    name = "Add Custom Set Rule",
                    tooltip = "Adds the current draft as a custom set matcher.",
                    func = function()
                        local abilityId = tonumber(self.saved.customSetDraftAbilityId)
                        local ok, message = self:AddCustomSetRule(
                            self.saved.customSetDraftLabel,
                            self.saved.customSetDraftScene,
                            abilityId,
                            self.saved.customSetDraftAbilityName
                        )
                        self:Print(message)
                        if ok then
                            self.saved.customSetDraftAbilityId = ""
                            self.saved.customSetDraftAbilityName = ""
                        end
                    end,
                    width = "half",
                },
                {
                    type = "button",
                    name = "Import PvPCooldownTracker Rules",
                    tooltip = "Scans PvPCooldownTracker tables and imports ability-based set rules.",
                    func = function()
                        local added, message = self:ImportSetsFromPvPCooldownTracker()
                        self:Print(message)
                        if added > 0 then
                            self:Print(string.format("Custom set rule count: %d", #(self.saved.customSetRules or {})))
                        end
                    end,
                    width = "half",
                },
                {
                    type = "button",
                    name = "Clear Custom Set Rules",
                    tooltip = "Removes all custom set rules added through settings/import.",
                    func = function()
                        self.saved.customSetRules = {}
                        self:InvalidateTrackedSetMatchCache()
                        self:Print("Cleared all custom set rules.")
                    end,
                    width = "half",
                },
            }

    LibAddonMenu2:RegisterAddonPanel("ConsoleMetricsPanel", panelData)
    LibAddonMenu2:RegisterOptionControls("ConsoleMetricsPanel", optionsTable)
end

function ConsoleMetrics:GetFightSnapshot()
    local nowMs = GetFrameTimeMilliseconds()
    if not self.fight then
        return self:BuildFightSummaryFromFight(NewFight(nowMs), nowMs)
    end

    local fight = self.fight
    local function SafeInt(value)
        return math.floor(tonumber(value) or 0)
    end
    local signature = string.format(
        "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d",
        SafeInt(fight.snapshotRev),
        SafeInt(fight.startMs),
        SafeInt(fight.endMs),
        SafeInt(fight.totalDamage),
        SafeInt(fight.totalHeal),
        SafeInt(fight.totalTaken),
        SafeInt(fight.hits),
        SafeInt(fight.crits),
        SafeInt(fight.totalOverflowDamage),
        SafeInt(fight.totalOverflowHeal),
        SafeInt(fight.totalIncomingOverflowDamage),
        SafeInt(fight.peakDps),
        SafeInt(fight.peakHps),
        SafeInt(fight.resourceSamples and fight.resourceSamples.lastSampleMs)
    )

    local cache = self.fightSnapshotCache
    if cache and cache.signature == signature and nowMs < (cache.computedAtMs + LIVE_SNAPSHOT_CACHE_MS) then
        return cache.summary
    end

    local summary = self:BuildFightSummaryFromFight(fight, nowMs)
    self.fightSnapshotCache = {
        signature = signature,
        computedAtMs = nowMs,
        summary = summary,
    }
    return summary
end

function ConsoleMetrics:GetViewedFightSnapshot()
    if self.viewFightIndex >= 1 and self.viewFightIndex <= #self.fightHistory then
        return self.fightHistory[self.viewFightIndex], false
    end

    return self:GetFightSnapshot(), true
end

function ConsoleMetrics:GetBehaviorModel(liveSummaryOverride)
    if not (self.saved and self.saved.behaviorModelEnabled) then
        if not self.behaviorModelDisabledResult then
            self.behaviorModelDisabledResult = {
                samples = 0,
                predictedDps = 0,
                predictedHps = 0,
                predictedTaken = 0,
                predictedResistance = 0,
                predictedDrPct = 0,
                predictedProtectionLabel = "Disabled for performance",
                predictedProtectionConfidence = 0,
                resistanceSamples = 0,
                volatilityPct = 0,
                pressureProfile = "Behavior model disabled",
                rhythmProfile = "Behavior model disabled",
                hasHistory = false,
            }
        end
        self.behaviorModelCache = nil
        return self.behaviorModelDisabledResult
    end

    local nowMs = GetFrameTimeMilliseconds()
    local liveFight = self.fight or {}
    local lastHistory = self.fightHistory[#self.fightHistory] or {}
    local signature = string.format(
        "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d",
        #self.fightHistory,
        math.floor(lastHistory.startMs or 0),
        math.floor(lastHistory.endMs or 0),
        math.floor(lastHistory.totalDamage or 0),
        math.floor(liveFight.totalDamage or 0),
        math.floor(liveFight.totalHeal or 0),
        math.floor(liveFight.totalTaken or 0),
        math.floor(liveFight.hits or 0),
        math.floor(liveFight.startMs or 0),
        math.floor(liveFight.endMs or 0)
    )

    local refreshMs = tonumber(self.saved and self.saved.behaviorModelRefreshMs) or self.defaults.behaviorModelRefreshMs
    refreshMs = math.max(250, math.min(5000, math.floor(refreshMs + 0.5)))
    local cache = self.behaviorModelCache

    if cache and cache.signature == signature then
        return cache.model
    end
    if cache and self.inCombat and nowMs < (cache.computedAtMs + refreshMs) then
        return cache.model
    end

    local dpsValues = {}
    local hpsValues = {}
    local takenValues = {}
    local resistanceValues = {}

    local function AddSummary(summary)
        dpsValues[#dpsValues + 1] = summary.dps or 0
        hpsValues[#hpsValues + 1] = summary.hps or 0
        takenValues[#takenValues + 1] = summary.totalTaken or 0
        if summary.targetList then
            for j = 1, #summary.targetList do
                local resistance = summary.targetList[j].estimatedResistance
                if resistance ~= nil then
                    resistanceValues[#resistanceValues + 1] = math.max(0, resistance)
                end
            end
        end
    end

    for i = 1, #self.fightHistory do
        AddSummary(self.fightHistory[i])
    end

    local liveSummary = liveSummaryOverride or self:GetFightSnapshot()
    if liveSummary and (liveSummary.totalDamage > 0 or liveSummary.totalHeal > 0 or liveSummary.totalTaken > 0) then
        AddSummary(liveSummary)
    end

    if #dpsValues == 0 then
        local emptyModel = {
            samples = 0,
            predictedDps = 0,
            predictedHps = 0,
            predictedTaken = 0,
            predictedResistance = 0,
            predictedDrPct = 0,
            predictedProtectionLabel = "No mitigation data",
            predictedProtectionConfidence = 0,
            resistanceSamples = 0,
            volatilityPct = 0,
            pressureProfile = "Need completed fights for pressure profile",
            rhythmProfile = "Need completed fights for rhythm profile",
            hasHistory = false,
        }
        self.behaviorModelCache = {
            signature = signature,
            computedAtMs = nowMs,
            model = emptyModel,
        }
        return emptyModel
    end

    local dpsMean = Mean(dpsValues)
    local dpsStd = StdDev(dpsValues, dpsMean)
    local volatility = dpsMean > 0 and (dpsStd / dpsMean) or 0

    local predictedDps = math.max(0, ExponentialAverage(dpsValues, 0.35) + LinearSlope(dpsValues))
    local predictedHps = math.max(0, ExponentialAverage(hpsValues, 0.35) + LinearSlope(hpsValues))
    local predictedTaken = math.max(0, ExponentialAverage(takenValues, 0.35) + LinearSlope(takenValues))
    local predictedResistance = Mean(resistanceValues)
    if #resistanceValues > 0 then
        predictedResistance = math.max(0, ExponentialAverage(resistanceValues, 0.35) + LinearSlope(resistanceValues))
        predictedResistance = Clamp(predictedResistance, 0, RESISTANCE_CAP)
    end

    local predictedDrPct = Clamp((predictedResistance / RESISTANCE_SCALE) * 100, 0, 50)
    local predictedProtectionLabel, _, predictedProtectionConfidence = InferProtectionFromDr(predictedDrPct, #resistanceValues > 0)

    local pressureProfile = "Balanced pressure"
    if predictedTaken > (predictedDps * 0.8) then
        pressureProfile = "High incoming pressure"
    elseif predictedTaken < (predictedDps * 0.25) then
        pressureProfile = "Low incoming pressure"
    end

    local rhythmProfile = volatility > 0.35 and "Bursty fight rhythm" or "Stable fight rhythm"

    local model = {
        samples = #dpsValues,
        predictedDps = predictedDps,
        predictedHps = predictedHps,
        predictedTaken = predictedTaken,
        predictedResistance = predictedResistance,
        predictedDrPct = predictedDrPct,
        predictedProtectionLabel = predictedProtectionLabel,
        predictedProtectionConfidence = predictedProtectionConfidence,
        resistanceSamples = #resistanceValues,
        volatilityPct = volatility * 100,
        pressureProfile = pressureProfile,
        rhythmProfile = rhythmProfile,
        hasHistory = true,
    }

    self.behaviorModelCache = {
        signature = signature,
        computedAtMs = nowMs,
        model = model,
    }

    return model
end

function ConsoleMetrics:AddCurrentFightToHistory()
    if not self.fight then
        return
    end

    local nowMs = GetFrameTimeMilliseconds()
    local summary = self:BuildFightSummaryFromFight(self.fight, nowMs)
    if summary.totalDamage <= 0 and summary.totalHeal <= 0 and summary.totalTaken <= 0 then
        return
    end

    if self.saved and self.saved.lowMemoryMode then
        summary = self:CompactFightSummaryForHistory(summary)
    end

    self.fightHistory[#self.fightHistory + 1] = summary

    self:EnforceFightHistoryLimit()

    self.viewFightIndex = #self.fightHistory
    self.behaviorModelCache = nil
end

function ConsoleMetrics:EnforceFightHistoryLimit()
    if type(self.fightHistory) ~= "table" then
        self.fightHistory = {}
    end

    local hardCap = tonumber(MAX_FIGHT_HISTORY_HARD_CAP) or 40
    local maxHistory = tonumber(self.saved and self.saved.maxFightHistory) or self.defaults.maxFightHistory
    maxHistory = math.max(5, math.min(hardCap, math.floor(maxHistory + 0.5)))
    if self.saved then
        self.saved.maxFightHistory = maxHistory
    end

    local removed = 0
    while #self.fightHistory > maxHistory do
        table.remove(self.fightHistory, 1)
        removed = removed + 1
    end

    if #self.fightHistory == 0 then
        self.viewFightIndex = 0
    elseif self.viewFightIndex and self.viewFightIndex > 0 then
        self.viewFightIndex = self.viewFightIndex - removed
        if self.viewFightIndex < 1 then
            self.viewFightIndex = 1
        elseif self.viewFightIndex > #self.fightHistory then
            self.viewFightIndex = #self.fightHistory
        end
    end

    if removed > 0 then
        self.behaviorModelCache = nil
        self.fightSnapshotCache = nil
        if type(collectgarbage) == "function" then
            collectgarbage("step", 200)
        end
    end

    return removed, maxHistory
end

function ConsoleMetrics:StepFightView(step)
    if #self.fightHistory == 0 then
        self.viewFightIndex = 0
        return false
    end

    if self.viewFightIndex == 0 then
        if step < 0 then
            self.viewFightIndex = #self.fightHistory
        else
            self.viewFightIndex = 1
        end
    else
        self.viewFightIndex = self.viewFightIndex + step
        if self.viewFightIndex < 1 then
            self.viewFightIndex = #self.fightHistory
        elseif self.viewFightIndex > #self.fightHistory then
            self.viewFightIndex = 1
        end
    end

    return true
end

function ConsoleMetrics:ResetFightData(keepHistory)
    local nowMs = GetFrameTimeMilliseconds()
    self.fight = NewFight(nowMs)
    self.hideAtMs = nil
    self.viewFightIndex = 0
    self.scrollEntries = {}
    self.lastSortedSkillList = {}
    self.lastSkillMapSize = 0
    self.lastProtectionUpdateMs = 0
    self.skillListDirty = true
    self.lastScrollLineAtMs = 0
    self.lastEffectStateEventMs = 0
    self.lastTraceTargetMatchMs = nil
    self.behaviorModelCache = nil
    self.fightSnapshotCache = nil
    self.uiMetricCache = nil

    if not keepHistory then
        self.fightHistory = {}
    end

    if self.ui.root then
        self.ui.root:SetHidden(true)
    end

    self:RefreshScroll()
    self:UpdateMetrics()
end

function ConsoleMetrics:SaveViewedFight()
    local snapshot = self:GetViewedFightSnapshot()
    if not snapshot then
        return false, "No fight data to save."
    end
    if (snapshot.totalDamage or 0) <= 0 and (snapshot.totalHeal or 0) <= 0 and (snapshot.totalTaken or 0) <= 0 then
        return false, "Fight has no data worth saving."
    end
    local maxSaves = tonumber(self.saved.maxSavedFights) or self.defaults.maxSavedFights
    if #self.saved.savedFights >= maxSaves then
        return false, string.format("Saves full (%d/%d). Delete a save slot first.", #self.saved.savedFights, maxSaves)
    end

    local requestedLabel = TrimText((self.saved and self.saved.saveFightDraftName) or "")
    local autoLabel = requestedLabel == ""
    local label = autoLabel and BuildDefaultFightSaveName(snapshot, #self.saved.savedFights + 1) or requestedLabel
    snapshot.savedLabel = label
    self.saved.savedFights[#self.saved.savedFights + 1] = {
        label = label,
        autoLabel = autoLabel,
        snapshot = snapshot,
    }
    return true, string.format("Fight saved: %s", label)
end

function ConsoleMetrics:DeleteSavedFight(index)
    if type(index) ~= "number" or index < 1 or index > #self.saved.savedFights then
        return false, "Invalid save slot."
    end
    local removedLabel = self.saved.savedFights[index].label or string.format("Slot %d", index)
    table.remove(self.saved.savedFights, index)
    -- Re-label only auto-generated entries so custom names remain unchanged.
    for i = 1, #self.saved.savedFights do
        local entry = self.saved.savedFights[i]
        if entry and entry.autoLabel and type(entry.snapshot) == "table" then
            entry.label = BuildDefaultFightSaveName(entry.snapshot, i)
            entry.snapshot.savedLabel = entry.label
        end
    end
    return true, string.format("Deleted: %s", removedLabel)
end

function ConsoleMetrics:LoadSavedFightIntoHistory(index)
    local entry = self.saved.savedFights and self.saved.savedFights[index]
    if not entry or type(entry.snapshot) ~= "table" then
        return false, "Invalid or empty save slot."
    end
    local summary = entry.snapshot
    if self.saved and self.saved.lowMemoryMode then
        summary = self:CompactFightSummaryForHistory(summary)
    end
    self.fightHistory[#self.fightHistory + 1] = summary
    self:EnforceFightHistoryLimit()
    self.viewFightIndex = #self.fightHistory
    return true, string.format("Loaded: %s (history slot %d/%d)", entry.label, self.viewFightIndex, #self.fightHistory)
end

function ConsoleMetrics:LoadSavedFightIntoHistoryByName(rawName)
    local query = TrimText(rawName)
    if query == "" then
        return false, "Provide a saved fight name."
    end

    local saves = self.saved and self.saved.savedFights or nil
    if type(saves) ~= "table" or #saves == 0 then
        return false, "No saved fights available."
    end

    local lowerQuery = string.lower(query)
    local exactIndex = nil
    local partialMatches = {}

    for i = 1, #saves do
        local entry = saves[i]
        local label = TrimText(entry and entry.label or "")
        local lowerLabel = string.lower(label)

        if label ~= "" then
            if lowerLabel == lowerQuery then
                exactIndex = i
                break
            end
            if string.find(lowerLabel, lowerQuery, 1, true) ~= nil then
                partialMatches[#partialMatches + 1] = i
            end
        end
    end

    if exactIndex then
        return self:LoadSavedFightIntoHistory(exactIndex)
    end

    if #partialMatches == 1 then
        return self:LoadSavedFightIntoHistory(partialMatches[1])
    end

    if #partialMatches > 1 then
        local names = {}
        for i = 1, math.min(5, #partialMatches) do
            names[#names + 1] = saves[partialMatches[i]].label
        end
        local suffix = #partialMatches > 5 and "..." or ""
        return false, string.format("Multiple saved fights match '%s': %s%s", query, table.concat(names, " | "), suffix)
    end

    return false, string.format("Saved fight '%s' not found.", query)
end

function ConsoleMetrics:LoadSavedFightIntoHistoryByExactName(rawName)
    local query = TrimText(rawName)
    if query == "" then
        return false, "Provide a saved fight name."
    end

    local saves = self.saved and self.saved.savedFights or nil
    if type(saves) ~= "table" or #saves == 0 then
        return false, "No saved fights available."
    end

    local lowerQuery = string.lower(query)
    for i = 1, #saves do
        local entry = saves[i]
        local label = TrimText(entry and entry.label or "")
        if label ~= "" and string.lower(label) == lowerQuery then
            return self:LoadSavedFightIntoHistory(i)
        end
    end

    return false, string.format("Exact saved fight '%s' not found.", query)
end

function ConsoleMetrics:FindCustomSetRuleByLabel(label)
    if type(label) ~= "string" or label == "" then
        return nil
    end
    if not self.saved or type(self.saved.customSetRules) ~= "table" then
        return nil
    end

    local lowerLabel = string.lower(TrimText(label))
    for i = 1, #self.saved.customSetRules do
        local rule = self.saved.customSetRules[i]
        if type(rule) == "table" and string.lower(TrimText(rule.label or "")) == lowerLabel then
            return rule
        end
    end

    return nil
end

function ConsoleMetrics:BuildProcTimerSnapshot(nowMs)
    local entries = {}
    local seen = {}
    local currentMs = nowMs
    if type(currentMs) ~= "number" then
        if type(GetGameTimeMilliseconds) == "function" then
            currentMs = GetGameTimeMilliseconds()
        else
            currentMs = GetFrameTimeMilliseconds()
        end
    end

    local g = type(_G) == "table" and _G or nil
    local pctData = g and g.PvPCooldownTracker and g.PvPCooldownTracker.Data and g.PvPCooldownTracker.Data.Sets or nil
    local equippedSets = BuildEquippedSetSummary()

    local function AddEntry(label, equippedInfo)
        if type(label) ~= "string" or label == "" then
            return
        end

        local lowerLabel = string.lower(label)
        if seen[lowerLabel] then
            return
        end

        local rule = self:FindCustomSetRuleByLabel(label)
        local pctEntry = pctData and pctData[label] or nil
        local track = self.fight and self.fight.setEffects and self.fight.setEffects[lowerLabel] or nil
        if not rule and not pctEntry and not track then
            return
        end

        seen[lowerLabel] = true
        local cooldownMs = tonumber((pctEntry and pctEntry.cooldownDurationMs) or (rule and rule.cooldownDurationMs)) or 0
        local onCooldown = pctEntry and pctEntry.onCooldown or false
        local procTimeMs = tonumber(pctEntry and pctEntry.timeOfProc) or 0
        local remainingMs = 0
        if onCooldown and cooldownMs > 0 and procTimeMs > 0 then
            remainingMs = math.max(0, (procTimeMs + cooldownMs) - currentMs)
        end

        local stateText = "Ready"
        if track and track.activeSinceMs then
            if remainingMs > 0 then
                stateText = string.format("Active | Ready %.1fs", remainingMs / 1000)
            else
                stateText = "Active"
            end
        elseif remainingMs > 0 then
            stateText = string.format("Ready %.1fs", remainingMs / 1000)
        end

        entries[#entries + 1] = {
            label = label,
            stateText = stateText,
            cooldownMs = cooldownMs,
            remainingMs = remainingMs,
            numEquipped = equippedInfo and equippedInfo.numEquipped or 0,
            maxEquipped = equippedInfo and equippedInfo.maxEquipped or 0,
            slots = equippedInfo and equippedInfo.slots or {},
            fromPCT = pctEntry ~= nil,
            fromCustomRule = rule ~= nil,
        }
    end

    for i = 1, #equippedSets do
        AddEntry(equippedSets[i].setName, equippedSets[i])
    end

    for i = 1, #(self.saved and self.saved.customSetRules or {}) do
        local rule = self.saved.customSetRules[i]
        if type(rule) == "table" and type(rule.label) == "string" and rule.label ~= "" then
            AddEntry(rule.label, nil)
        end
    end

    table.sort(entries, function(a, b)
        local function Rank(entry)
            if string.find(entry.stateText or "", "Active", 1, true) ~= nil then
                return 1
            end
            if (entry.remainingMs or 0) > 0 then
                return 2
            end
            return 3
        end

        local rankA = Rank(a)
        local rankB = Rank(b)
        if rankA == rankB then
            return tostring(a.label) < tostring(b.label)
        end
        return rankA < rankB
    end)

    return entries
end

