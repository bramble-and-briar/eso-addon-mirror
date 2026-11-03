-- ConsoleMetrics_FightData.lua
-- The fight data model: live fight state, summaries/snapshots, fight history,
-- persisted saved fights and the ML-lite behavior model.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local BuildDefaultFightSaveName = Util.BuildDefaultFightSaveName
local BuildNumericSampleSummary = Util.BuildNumericSampleSummary
local BuildResourceSampleSummary = Util.BuildResourceSampleSummary
local BuildSustainPerformanceSummary = Util.BuildSustainPerformanceSummary
local Clamp = Util.Clamp
local DeepCopy = Util.DeepCopy
local ExponentialAverage = Util.ExponentialAverage
local LOW_MEMORY_EFFECT_LIMIT = Util.LOW_MEMORY_EFFECT_LIMIT
local LOW_MEMORY_LIST_LIMIT = Util.LOW_MEMORY_LIST_LIMIT
local LOW_MEMORY_MOMENTS_LIMIT = Util.LOW_MEMORY_MOMENTS_LIMIT
local LinearSlope = Util.LinearSlope
local MAJOR_PROTECTION_DR_PCT = Util.MAJOR_PROTECTION_DR_PCT
local MAX_FIGHT_HISTORY_HARD_CAP = Util.MAX_FIGHT_HISTORY_HARD_CAP
local MINOR_PROTECTION_DR_PCT = Util.MINOR_PROTECTION_DR_PCT
local Mean = Util.Mean
local PING_HIGH_DELAY_MS = Util.PING_HIGH_DELAY_MS
local RESISTANCE_CAP = Util.RESISTANCE_CAP
local RESISTANCE_SCALE = Util.RESISTANCE_SCALE
local SafeAbilityId = Util.SafeAbilityId
local StdDev = Util.StdDev
local THROUGHPUT_WINDOW_INTERVAL_MS = Util.THROUGHPUT_WINDOW_INTERVAL_MS
local TOP_MOMENTS_LIMIT = Util.TOP_MOMENTS_LIMIT
local TrimText = Util.TrimText


local LIVE_SNAPSHOT_CACHE_MS = 200


---------------------------------------------------------------------------
-- Sorting, top moments, throughput windows
---------------------------------------------------------------------------
-- Module-level comparators: avoids allocating a new closure on every sort call (GC win on console).
local function _SkillByDamageDesc(a, b) return (a.damage or 0) > (b.damage or 0) end
local function _SkillByHealDesc(a, b) return (a.heal or 0) > (b.heal or 0) end
local function _TopMomentByValueDesc(a, b) return (a.value or 0) > (b.value or 0) end

local function SortSkillEntries(skillMap)
    local list = {}
    for _, info in pairs(skillMap) do
        list[#list + 1] = info
    end
    table.sort(list, _SkillByDamageDesc)
    return list
end

local function SortSkillEntriesByHeal(skillMap)
    local list = {}
    for _, info in pairs(skillMap) do
        if (info.heal or 0) > 0 then
            list[#list + 1] = info
        end
    end
    table.sort(list, _SkillByHealDesc)
    return list
end

local function AddTopMoment(momentList, moment)
    local count = #momentList
    -- Skip sort entirely when the list is full and this moment won't rank.
    if count >= TOP_MOMENTS_LIMIT and (momentList[count].value or 0) >= (moment.value or 0) then
        return
    end
    momentList[count + 1] = moment
    table.sort(momentList, _TopMomentByValueDesc)
    if #momentList > TOP_MOMENTS_LIMIT then
        table.remove(momentList, #momentList)
    end
end

local function CloneMoments(momentList)
    local clone = {}
    for i = 1, #momentList do
        local moment = momentList[i]
        clone[i] = {
            value = moment.value,
            label = moment.label,
            tooltip = moment.tooltip,
            abilityId = moment.abilityId,
            abilityName = moment.abilityName,
            effectName = moment.effectName,
        }
    end
    return clone
end

local function NewThroughputWindowTracker(intervalMs)
    return {
        intervalMs = math.max(1, math.floor(tonumber(intervalMs) or 1000)),
        currentWindowIndex = 0,
        currentWindowValue = 0,
        finalizedWindowCount = 0,
        finalizedPeakValue = nil,
        finalizedPeakIndex = nil,
        finalizedLowestValue = nil,
        finalizedLowestIndex = nil,
        finalizedLowestNonZeroValue = nil,
        finalizedLowestNonZeroIndex = nil,
    }
end

local function FinalizeThroughputWindow(tracker, windowIndex, value)
    tracker.finalizedWindowCount = (tonumber(tracker.finalizedWindowCount) or 0) + 1

    local peakValue = tonumber(tracker.finalizedPeakValue)
    if peakValue == nil or value > peakValue then
        tracker.finalizedPeakValue = value
        tracker.finalizedPeakIndex = windowIndex
    end

    local lowValue = tonumber(tracker.finalizedLowestValue)
    if lowValue == nil or value < lowValue then
        tracker.finalizedLowestValue = value
        tracker.finalizedLowestIndex = windowIndex
    end

    if value > 0 then
        local lowNonZero = tonumber(tracker.finalizedLowestNonZeroValue)
        if lowNonZero == nil or value < lowNonZero then
            tracker.finalizedLowestNonZeroValue = value
            tracker.finalizedLowestNonZeroIndex = windowIndex
        end
    end
end

local function AdvanceThroughputWindowTracker(tracker, targetWindowIndex)
    if type(tracker) ~= "table" then
        return
    end

    local targetIndex = math.max(0, math.floor(tonumber(targetWindowIndex) or 0))
    local currentIndex = math.max(0, math.floor(tonumber(tracker.currentWindowIndex) or 0))
    if targetIndex <= currentIndex then
        return
    end

    local currentValue = tonumber(tracker.currentWindowValue) or 0
    FinalizeThroughputWindow(tracker, currentIndex, currentValue)

    if targetIndex > (currentIndex + 1) then
        local firstGapIndex = currentIndex + 1
        local gapCount = targetIndex - currentIndex - 1
        tracker.finalizedWindowCount = (tonumber(tracker.finalizedWindowCount) or 0) + gapCount

        local peakValue = tonumber(tracker.finalizedPeakValue)
        if peakValue == nil or 0 > peakValue then
            tracker.finalizedPeakValue = 0
            tracker.finalizedPeakIndex = firstGapIndex
        end

        local lowValue = tonumber(tracker.finalizedLowestValue)
        if lowValue == nil or 0 < lowValue then
            tracker.finalizedLowestValue = 0
            tracker.finalizedLowestIndex = firstGapIndex
        end
    end

    tracker.currentWindowIndex = targetIndex
    tracker.currentWindowValue = 0
end

local function AddThroughputWindowValueByTime(tracker, startMs, nowMs, value)
    if type(tracker) ~= "table" then
        return
    end

    local amount = tonumber(value) or 0
    if amount <= 0 then
        return
    end

    local intervalMs = math.max(1, math.floor(tonumber(tracker.intervalMs) or 1000))
    local baseMs = tonumber(startMs) or tonumber(nowMs) or 0
    local stampMs = tonumber(nowMs) or baseMs
    local elapsedMs = math.max(0, stampMs - baseMs)
    local targetIndex = math.floor(elapsedMs / intervalMs)

    AdvanceThroughputWindowTracker(tracker, targetIndex)
    tracker.currentWindowValue = (tonumber(tracker.currentWindowValue) or 0) + amount
end

---------------------------------------------------------------------------
-- Fight model
---------------------------------------------------------------------------
local function NewFight(nowMs)
    local startTimestampSec = nil
    if type(GetTimeStamp) == "function" then
        startTimestampSec = tonumber(GetTimeStamp())
    end

    return {
        startMs = nowMs,
        startTimestampSec = startTimestampSec,
        endMs = nil,
        snapshotRev = 0,
        totalDamage = 0,
        totalOverflowDamage = 0,
        totalBlockedDamage = 0,
        totalShieldedDamage = 0,
        totalHeal = 0,
        totalOverflowHeal = 0,
        totalTaken = 0,
        totalIncomingOverflowDamage = 0,
        totalIncomingBlockedDamage = 0,
        totalIncomingShieldedDamage = 0,
        hits = 0,
        crits = 0,
        minHitValue = nil,
        maxHitValue = nil,
        peakDps = 0,
        peakHps = 0,
        damageWindowTracker = NewThroughputWindowTracker(THROUGHPUT_WINDOW_INTERVAL_MS),
        healWindowTracker = NewThroughputWindowTracker(THROUGHPUT_WINDOW_INTERVAL_MS),
        skillMap = {},
        incomingSkillMap = {},
        incomingSetDamageMap = {},
        incomingLikelySetProcMap = {},
        dotMap = {},
        hotMap = {},
        targetMap = {},
        topHealingMoments = {},
        topMitigationMoments = {},
        -- Tracks every effect seen via ACTION_RESULT_EFFECT_GAINED/FADED style events.
        allEffects = {},
        -- Tracks major/minor subsets for fast console-friendly filtering.
        majorMinorEffects = {},
        -- Tracks popular PvE/PvP set procs by alias.
        setEffects = {},
        -- Separated tracking: buffs = effects whose target is the player,
        -- debuffs = effects the player applies to non-player targets.
        buffEffects   = {},
        debuffEffects = {},
        -- Resource snapshots sampled during combat for avg/median display.
        resourceSamples = {
            lastSampleMs = nil,
            healthPct = {},
            magickaPct = {},
            staminaPct = {},
            pingMs = {},
            -- Absolute value tracking for per-fight regen/drain/ultimate gen.
            lastAbsHealth = nil,
            lastAbsMagicka = nil,
            lastAbsStamina = nil,
            lastAbsUltimate = nil,
            lastPingMs = nil,
            minPingMs = nil,
            maxPingMs = nil,
            pingDipCount = 0,
            pingSpikeCount = 0,
            highDelaySamples = 0,
            totalHealthRegen = 0,
            totalHealthDrain = 0,
            totalMagickaRegen = 0,
            totalMagickaDrain = 0,
            totalStaminaRegen = 0,
            totalStaminaDrain = 0,
            totalUltimateGen = 0,
            totalUltimateDrain = 0,
        },
        protectionInfo = {
            currentState = "unknown",
            currentLabel = "No mitigation data",
            currentResistance = 0,
            currentDrPct = 0,
            confidence = 0,
            samples = 0,
            lastSampleMs = nowMs,
            drEma = 0,
            stateMs = {
                majorMinor = 0,
                major = 0,
                minor = 0,
                none = 0,
                unknown = 0,
            },
        },
    }
end

---------------------------------------------------------------------------
-- Duration, resistance and protection inference
---------------------------------------------------------------------------
local function GetFightDurationSeconds(fight, nowMs)
    if not fight or not fight.startMs then
        return 0
    end

    local endMs = fight.endMs or nowMs
    return math.max((endMs - fight.startMs) / 1000, 0)
end

local function EstimateTargetResistance(target)
    if not target then
        return 0, 0
    end

    local mitigatedLike = (target.blocked or 0) + (target.shielded or 0)
    local totalObserved = (target.effective or 0) + (target.overflow or 0) + mitigatedLike
    if totalObserved <= 0 then
        return 0, 0
    end

    local mitigationRatio = Clamp(mitigatedLike / totalObserved, 0, 0.5)
    local resistance = Clamp(mitigationRatio * RESISTANCE_SCALE, 0, RESISTANCE_CAP)
    return resistance, mitigationRatio * 100
end

local function InferProtectionFromDr(drPct, hasData)
    if not hasData then
        return "No mitigation data", "unknown", 0
    end

    if drPct >= (MAJOR_PROTECTION_DR_PCT + MINOR_PROTECTION_DR_PCT - 1.0) then
        local confidence = Clamp(0.65 + ((drPct - (MAJOR_PROTECTION_DR_PCT + MINOR_PROTECTION_DR_PCT)) / 20), 0.45, 0.98)
        return "Major + Minor Protection (inferred)", "majorMinor", confidence
    end

    if drPct >= (MAJOR_PROTECTION_DR_PCT - 1.0) then
        local confidence = Clamp(0.60 + ((drPct - MAJOR_PROTECTION_DR_PCT) / 18), 0.40, 0.95)
        return "Major Protection (inferred)", "major", confidence
    end

    if drPct >= (MINOR_PROTECTION_DR_PCT - 1.0) then
        local confidence = Clamp(0.55 + ((drPct - MINOR_PROTECTION_DR_PCT) / 15), 0.35, 0.90)
        return "Minor Protection (inferred)", "minor", confidence
    end

    local confidence = Clamp(0.50 + ((MINOR_PROTECTION_DR_PCT - drPct) / 15), 0.30, 0.90)
    return "No Protection inferred", "none", confidence
end

---------------------------------------------------------------------------
-- Protection summary and tracked effects
---------------------------------------------------------------------------
local function BuildProtectionSummary(protectionInfo, nowMs)
    local stateMs = {
        majorMinor = 0,
        major = 0,
        minor = 0,
        none = 0,
        unknown = 0,
    }

    if protectionInfo and protectionInfo.stateMs then
        stateMs.majorMinor = protectionInfo.stateMs.majorMinor or 0
        stateMs.major = protectionInfo.stateMs.major or 0
        stateMs.minor = protectionInfo.stateMs.minor or 0
        stateMs.none = protectionInfo.stateMs.none or 0
        stateMs.unknown = protectionInfo.stateMs.unknown or 0

        if protectionInfo.lastSampleMs and protectionInfo.currentState and nowMs > protectionInfo.lastSampleMs then
            local elapsed = nowMs - protectionInfo.lastSampleMs
            local key = protectionInfo.currentState
            stateMs[key] = (stateMs[key] or 0) + elapsed
        end
    end

    local totalMs = stateMs.majorMinor + stateMs.major + stateMs.minor + stateMs.none + stateMs.unknown
    local trackedKnownMs = stateMs.majorMinor + stateMs.major + stateMs.minor + stateMs.none
    local anyProtectionMs = stateMs.majorMinor + stateMs.major + stateMs.minor

    local function Ratio(ms)
        if totalMs <= 0 then
            return 0
        end
        return (ms / totalMs) * 100
    end

    return {
        totalMs = totalMs,
        trackedKnownMs = trackedKnownMs,
        majorMinorMs = stateMs.majorMinor,
        majorMs = stateMs.major,
        minorMs = stateMs.minor,
        noneMs = stateMs.none,
        unknownMs = stateMs.unknown,
        anyProtectionMs = anyProtectionMs,
        majorMinorPct = Ratio(stateMs.majorMinor),
        majorPct = Ratio(stateMs.major),
        minorPct = Ratio(stateMs.minor),
        nonePct = Ratio(stateMs.none),
        unknownPct = Ratio(stateMs.unknown),
        anyProtectionPct = Ratio(anyProtectionMs),
    }
end

local function AcquireTrackedEffect(effectMap, key, name, category, abilityId, effectName)
    local track = effectMap[key]
    if not track then
        track = {
            key = key,
            name = name,
            category = category,
            abilityId = SafeAbilityId(abilityId),
            effectName = effectName or name,
            uptimeMs = 0,
            activeSinceMs = nil,
            activations = 0,
            fades = 0,
            procs = 0,
            totalValue = 0,
        }
        effectMap[key] = track
    else
        if (track.name == nil or track.name == "") and name and name ~= "" then
            track.name = name
        end
        if (track.effectName == nil or track.effectName == "") and effectName and effectName ~= "" then
            track.effectName = effectName
        end
        if (track.abilityId == nil or track.abilityId == 0) and SafeAbilityId(abilityId) > 0 then
            track.abilityId = SafeAbilityId(abilityId)
        end
    end

    return track
end

local function StartTrackedEffect(track, nowMs)
    if track.activeSinceMs == nil then
        track.activeSinceMs = nowMs
        track.activations = (track.activations or 0) + 1
    end
end

local function StopTrackedEffect(track, nowMs)
    if track.activeSinceMs ~= nil and nowMs >= track.activeSinceMs then
        track.uptimeMs = (track.uptimeMs or 0) + (nowMs - track.activeSinceMs)
        track.activeSinceMs = nil
        track.fades = (track.fades or 0) + 1
    end
end

-- Convert internal per-effect runtime state into sorted, render-ready summary rows.
local function _EffectByUptimeThenProcsDesc(a, b)
    if a.uptimePct == b.uptimePct then
        return (a.procs or 0) > (b.procs or 0)
    end
    return a.uptimePct > b.uptimePct
end

local function BuildTrackedEffectList(effectMap, durationSeconds, nowMs)
    local list = {}
    local durationMs = math.max((durationSeconds or 0) * 1000, 0)

    for _, track in pairs(effectMap or {}) do
        local uptimeMs = track.uptimeMs or 0
        if track.activeSinceMs and nowMs > track.activeSinceMs then
            uptimeMs = uptimeMs + (nowMs - track.activeSinceMs)
        end

        local uptimePct = 0
        if durationMs > 0 then
            uptimePct = Clamp((uptimeMs / durationMs) * 100, 0, 100)
        end

        list[#list + 1] = {
            name = track.name,
            category = track.category,
            abilityId = SafeAbilityId(track.abilityId),
            effectName = track.effectName or track.name,
            uptimeMs = uptimeMs,
            uptimePct = uptimePct,
            activations = track.activations or 0,
            fades = track.fades or 0,
            procs = track.procs or 0,
            totalValue = track.totalValue or 0,
        }
    end

    table.sort(list, _EffectByUptimeThenProcsDesc)

    return list
end

---------------------------------------------------------------------------
-- Fight summary
---------------------------------------------------------------------------
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

---------------------------------------------------------------------------
-- Live snapshot cache
---------------------------------------------------------------------------
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

---------------------------------------------------------------------------
-- Viewed snapshot
---------------------------------------------------------------------------
-- Returns the snapshot being viewed plus true when it is the live fight.
function ConsoleMetrics:GetViewedFightSnapshot()
    local history = self.fightHistory or {}
    local index = tonumber(self.viewFightIndex) or 0
    if index >= 1 and index <= #history then
        return history[index], false
    end
    return self:GetFightSnapshot(), true
end

---------------------------------------------------------------------------
-- Fight history
---------------------------------------------------------------------------
-- Appends a finished summary to history (compacting it first in low-memory
-- mode), enforces the history limit and points the view at the new entry.
function ConsoleMetrics:PushHistorySummary(summary)
    if self.saved and self.saved.lowMemoryMode then
        summary = self:CompactFightSummaryForHistory(summary)
    end
    self.fightHistory[#self.fightHistory + 1] = summary
    self:EnforceFightHistoryLimit()
    self.viewFightIndex = #self.fightHistory
    self.behaviorModelCache = nil
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

    self:PushHistorySummary(summary)
end

function ConsoleMetrics:ResetFightData(keepHistory)
    local nowMs = GetFrameTimeMilliseconds()
    self.fight = NewFight(nowMs)
    self.viewFightIndex = 0
    self.lastProtectionUpdateMs = 0
    self.lastMetricsUpdateMs = 0
    self.lastEffectStateEventMs = 0
    self.lastTraceTargetMatchMs = nil
    self.behaviorModelCache = nil
    self.fightSnapshotCache = nil

    if not keepHistory then
        self.fightHistory = {}
    end
end

---------------------------------------------------------------------------
-- Saved fights (persisted in saved variables)
---------------------------------------------------------------------------
-- Saved snapshots are always deep-copied on the way in and on the way out so
-- live updates, low-memory compaction and relabeling never corrupt the data
-- that is written to disk.

local function HasFightData(snapshot)
    return (snapshot.totalDamage or 0) > 0 or (snapshot.totalHeal or 0) > 0 or (snapshot.totalTaken or 0) > 0
end

function ConsoleMetrics:GetSavedFights()
    if not self.saved then
        return {}
    end
    if type(self.saved.savedFights) ~= "table" then
        self.saved.savedFights = {}
    end
    return self.saved.savedFights
end

function ConsoleMetrics:SaveViewedFight()
    if not self.saved then
        return false, "Settings are not initialized yet."
    end

    local snapshot = self:GetViewedFightSnapshot()
    if not snapshot then
        return false, "No fight data to save."
    end
    if not HasFightData(snapshot) then
        return false, "Fight has no data worth saving."
    end

    local saves = self:GetSavedFights()
    local maxSaves = tonumber(self.saved.maxSavedFights) or self.defaults.maxSavedFights
    if #saves >= maxSaves then
        return false, string.format("Saves full (%d/%d). Delete a save slot first.", #saves, maxSaves)
    end

    local requestedLabel = TrimText(self.saved.saveFightDraftName or "")
    local autoLabel = requestedLabel == ""
    local label = autoLabel and BuildDefaultFightSaveName(snapshot, #saves + 1) or requestedLabel

    snapshot.savedLabel = label
    local stored = DeepCopy(snapshot)
    stored.savedLabel = label
    saves[#saves + 1] = {
        label = label,
        autoLabel = autoLabel,
        snapshot = stored,
    }
    return true, string.format("Fight saved: %s", label)
end

function ConsoleMetrics:DeleteSavedFight(index)
    local saves = self:GetSavedFights()
    if type(index) ~= "number" or index < 1 or index > #saves then
        return false, "Invalid save slot."
    end

    local removedLabel = saves[index].label or string.format("Slot %d", index)
    table.remove(saves, index)

    -- Re-label only auto-generated entries so custom names remain unchanged.
    for i = 1, #saves do
        local entry = saves[i]
        if entry and entry.autoLabel and type(entry.snapshot) == "table" then
            entry.label = BuildDefaultFightSaveName(entry.snapshot, i)
            entry.snapshot.savedLabel = entry.label
        end
    end
    return true, string.format("Deleted: %s", removedLabel)
end

function ConsoleMetrics:ClearSavedFights()
    if self.saved then
        self.saved.savedFights = {}
    end
end

function ConsoleMetrics:LoadSavedFightIntoHistory(index)
    local saves = self:GetSavedFights()
    local entry = saves[index]
    if not entry or type(entry.snapshot) ~= "table" then
        return false, "Invalid or empty save slot."
    end

    self:PushHistorySummary(DeepCopy(entry.snapshot))
    local label = tostring(entry.label or string.format("Slot %d", index))
    return true, string.format("Loaded: %s (history slot %d/%d)", label, self.viewFightIndex, #self.fightHistory)
end

-- Finds a saved fight by label (case-insensitive). Exact matches win; with
-- allowPartial a single unique substring match is accepted as well.
-- Returns the slot index, or nil plus a user-facing message.
function ConsoleMetrics:FindSavedFightIndex(rawName, allowPartial)
    local query = TrimText(rawName)
    if query == "" then
        return nil, "Provide a saved fight name."
    end

    local saves = self:GetSavedFights()
    if #saves == 0 then
        return nil, "No saved fights available."
    end

    local lowerQuery = string.lower(query)
    local partialMatches = {}
    for i = 1, #saves do
        local entry = saves[i]
        local label = string.lower(TrimText(entry and entry.label or ""))
        if label ~= "" then
            if label == lowerQuery then
                return i
            end
            if allowPartial and string.find(label, lowerQuery, 1, true) ~= nil then
                partialMatches[#partialMatches + 1] = i
            end
        end
    end

    if #partialMatches == 1 then
        return partialMatches[1]
    end
    if #partialMatches > 1 then
        local names = {}
        for i = 1, math.min(5, #partialMatches) do
            names[#names + 1] = tostring(saves[partialMatches[i]].label)
        end
        local suffix = #partialMatches > 5 and "..." or ""
        return nil, string.format("Multiple saved fights match '%s': %s%s", query, table.concat(names, " | "), suffix)
    end

    if allowPartial then
        return nil, string.format("Saved fight '%s' not found.", query)
    end
    return nil, string.format("Exact saved fight '%s' not found.", query)
end

function ConsoleMetrics:LoadSavedFightIntoHistoryByName(rawName)
    local index, message = self:FindSavedFightIndex(rawName, true)
    if not index then
        return false, message
    end
    return self:LoadSavedFightIntoHistory(index)
end

function ConsoleMetrics:LoadSavedFightIntoHistoryByExactName(rawName)
    local index, message = self:FindSavedFightIndex(rawName, false)
    if not index then
        return false, message
    end
    return self:LoadSavedFightIntoHistory(index)
end

-- Loads every saved slot into session history (used at startup and by /cm loadsaves).
-- Returns the number of fights loaded.
function ConsoleMetrics:RestoreSavedFightsIntoHistory()
    local saves = self:GetSavedFights()
    local loaded = 0
    for i = 1, #saves do
        local entry = saves[i]
        if entry and type(entry.snapshot) == "table" then
            self:PushHistorySummary(DeepCopy(entry.snapshot))
            loaded = loaded + 1
        end
    end
    return loaded
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

---------------------------------------------------------------------------
-- Behavior model (ML-lite)
---------------------------------------------------------------------------
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

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

ConsoleMetrics.Fight = {
    AcquireTrackedEffect = AcquireTrackedEffect,
    AddThroughputWindowValueByTime = AddThroughputWindowValueByTime,
    AddTopMoment = AddTopMoment,
    AdvanceThroughputWindowTracker = AdvanceThroughputWindowTracker,
    BuildProtectionSummary = BuildProtectionSummary,
    BuildThroughputWindowStats = BuildThroughputWindowStats,
    BuildTrackedEffectList = BuildTrackedEffectList,
    CloneMoments = CloneMoments,
    EstimateTargetResistance = EstimateTargetResistance,
    FinalizeThroughputWindow = FinalizeThroughputWindow,
    FormatWindowDateTime = FormatWindowDateTime,
    FormatWindowRelativeTime = FormatWindowRelativeTime,
    GetFightDurationSeconds = GetFightDurationSeconds,
    HasFightData = HasFightData,
    InferProtectionFromDr = InferProtectionFromDr,
    NewFight = NewFight,
    NewThroughputWindowTracker = NewThroughputWindowTracker,
    SortSkillEntries = SortSkillEntries,
    SortSkillEntriesByHeal = SortSkillEntriesByHeal,
    StartTrackedEffect = StartTrackedEffect,
    StopTrackedEffect = StopTrackedEffect,
    TrimListInPlace = TrimListInPlace,
}
