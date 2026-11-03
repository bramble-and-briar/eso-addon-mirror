-- ConsoleMetrics_Combat.lua
-- Combat event processing: per-ability tracking, targets, effects, resource
-- sampling, protection inference and the optional live trace output.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local COMBAT_COLOR_HEX = Util.COMBAT_COLOR_HEX
local Clamp = Util.Clamp
local ColorShort = Util.ColorShort
local EFFECT_STATE_EVENT_THROTTLE_MS = Util.EFFECT_STATE_EVENT_THROTTLE_MS
local FormatAbilityIdentity = Util.FormatAbilityIdentity
local GetResourcePowerTypes = Util.GetResourcePowerTypes
local IsCriticalResult = Util.IsCriticalResult
local IsDamageResult = Util.IsDamageResult
local IsEffectFadedResult = Util.IsEffectFadedResult
local IsEffectGainedResult = Util.IsEffectGainedResult
local IsHealResult = Util.IsHealResult
local NumberText = Util.NumberText
local OBSERVED_ABILITY_LOG_MAX = Util.OBSERVED_ABILITY_LOG_MAX
local PING_DIP_DELTA_MS = Util.PING_DIP_DELTA_MS
local PING_HIGH_DELAY_MS = Util.PING_HIGH_DELAY_MS
local PING_SPIKE_DELTA_MS = Util.PING_SPIKE_DELTA_MS
local RESISTANCE_SCALE = Util.RESISTANCE_SCALE
local RESOURCE_SAMPLE_INTERVAL_MS = Util.RESOURCE_SAMPLE_INTERVAL_MS
local RESOURCE_SAMPLE_MAX_POINTS = Util.RESOURCE_SAMPLE_MAX_POINTS
local SafeAbilityId = Util.SafeAbilityId
local SafeGetCurrentPowerFromList = Util.SafeGetCurrentPowerFromList
local SafeGetLatencyMs = Util.SafeGetLatencyMs
local SafeGetPowerPctFromList = Util.SafeGetPowerPctFromList
local ShortNumber = Util.ShortNumber
local THROUGHPUT_WINDOW_INTERVAL_MS = Util.THROUGHPUT_WINDOW_INTERVAL_MS
local UnitName = Util.UnitName

local Sets = ConsoleMetrics.Sets
local ClassifyLikelySetProc = Sets.ClassifyLikelySetProc

local Fight = ConsoleMetrics.Fight
local AcquireTrackedEffect = Fight.AcquireTrackedEffect
local AddThroughputWindowValueByTime = Fight.AddThroughputWindowValueByTime
local AddTopMoment = Fight.AddTopMoment
local EstimateTargetResistance = Fight.EstimateTargetResistance
local GetFightDurationSeconds = Fight.GetFightDurationSeconds
local InferProtectionFromDr = Fight.InferProtectionFromDr
local NewFight = Fight.NewFight
local NewThroughputWindowTracker = Fight.NewThroughputWindowTracker
local StartTrackedEffect = Fight.StartTrackedEffect
local StopTrackedEffect = Fight.StopTrackedEffect


---------------------------------------------------------------------------
-- Trace output
---------------------------------------------------------------------------
function ConsoleMetrics:NormalizeIoTraceMode(mode)
    local normalized = string.lower(tostring(mode or "summary"))
    if normalized == "in" or normalized == "incoming" then
        return "in"
    end
    if normalized == "out" or normalized == "outgoing" then
        return "out"
    end
    if normalized == "all" or normalized == "full" or normalized == "events" then
        return "all"
    end
    return "summary"
end

function ConsoleMetrics:NormalizeIoTraceName(name)
    local text = tostring(name or "")
    text = zo_strtrim(text)
    if text == "" then
        return ""
    end
    return string.lower(UnitName(text))
end

function ConsoleMetrics:ResolveIoTraceTargetFilter()
    if not self.saved then
        return "", nil
    end

    local mode = string.lower(tostring(self.saved.ioTraceTargetMode or "off"))
    if mode ~= "reticle" and mode ~= "name" then
        return "", nil
    end

    if mode == "reticle" then
        -- An empty reticle name must disable matching, not match "Unknown".
        local rawName = type(GetUnitName) == "function" and GetUnitName("reticleover") or nil
        if not rawName or rawName == "" then
            return "", "reticle"
        end
        return self:NormalizeIoTraceName(rawName), "reticle"
    end

    return self:NormalizeIoTraceName(self.saved.ioTraceTargetName), "name"
end

function ConsoleMetrics:ShouldTraceTarget(sourceName, targetName)
    local normalizedFilter, mode = self:ResolveIoTraceTargetFilter()
    if not mode then
        return true
    end
    if normalizedFilter == "" then
        return false
    end

    local src = self:NormalizeIoTraceName(sourceName)
    local tgt = self:NormalizeIoTraceName(targetName)
    return src == normalizedFilter or tgt == normalizedFilter
end

function ConsoleMetrics:IsTraceFocusProcessingEnabled()
    return self.saved
        and self.saved.ioTraceEnabled == true
        and self.saved.ioTraceTargetOnlyProcessing == true
        and self.saved.ioTraceTargetMode ~= "off"
end

function ConsoleMetrics:EnsureIoTraceState(nowMs)
    self.ioTraceState = self.ioTraceState or {
        lineWindowStartMs = nowMs or GetFrameTimeMilliseconds(),
        lineWindowCount = 0,
        lineWindowDropped = 0,
        lineBuffer = {},
        lineBufferChars = 0,
        lastBufferFlushMs = nowMs or GetFrameTimeMilliseconds(),
        summaryStartMs = nowMs or GetFrameTimeMilliseconds(),
        eventSeen = 0,
        eventProcessed = 0,
        eventIncoming = 0,
        eventOutgoing = 0,
        eventOther = 0,
        eventDamage = 0,
        eventHeal = 0,
        eventEffect = 0,
        totalValue = 0,
        totalOverflow = 0,
        hitValueSamples = 0,
        minHitValue = nil,
        maxHitValue = nil,
        skippedNotCombat = 0,
        skippedZero = 0,
        skippedEffectThrottle = 0,
        skippedTargetFilter = 0,
        skippedProcessingFilter = 0,
        skippedSampleByFocus = 0,
        resourceSamples = 0,
        updateTicks = 0,
        fpsTotal = 0,
        fpsSamples = 0,
        fpsMin = nil,
        fpsBins = {},
    }
    return self.ioTraceState
end

function ConsoleMetrics:ResetIoTraceState(nowMs)
    local state = self:EnsureIoTraceState(nowMs)
    local anchor = nowMs or GetFrameTimeMilliseconds()
    state.lineWindowStartMs = anchor
    state.lineWindowCount = 0
    state.lineWindowDropped = 0
    state.lineBuffer = {}
    state.lineBufferChars = 0
    state.lastBufferFlushMs = anchor
    state.summaryStartMs = anchor
    state.eventSeen = 0
    state.eventProcessed = 0
    state.eventIncoming = 0
    state.eventOutgoing = 0
    state.eventOther = 0
    state.eventDamage = 0
    state.eventHeal = 0
    state.eventEffect = 0
    state.totalValue = 0
    state.totalOverflow = 0
    state.hitValueSamples = 0
    state.minHitValue = nil
    state.maxHitValue = nil
    state.skippedNotCombat = 0
    state.skippedZero = 0
    state.skippedEffectThrottle = 0
    state.skippedTargetFilter = 0
    state.skippedProcessingFilter = 0
    state.skippedSampleByFocus = 0
    state.resourceSamples = 0
    state.updateTicks = 0
    state.fpsTotal = 0
    state.fpsSamples = 0
    state.fpsMin = nil
    state.fpsBins = {}
end

function ConsoleMetrics:FlushIoTraceBuffer(nowMs, force)
    local state = self.ioTraceState
    if not state then
        return
    end

    local lines = state.lineBuffer
    if type(lines) ~= "table" or #lines == 0 then
        return
    end

    local stamp = nowMs or GetFrameTimeMilliseconds()
    local flushDue = force == true or stamp >= ((state.lastBufferFlushMs or stamp) + 250)
    local charLimitReached = (state.lineBufferChars or 0) >= 700
    local lineLimitReached = #lines >= 6
    if not flushDue and not charLimitReached and not lineLimitReached then
        return
    end

    self:Print(table.concat(lines, "\n"))
    state.lineBuffer = {}
    state.lineBufferChars = 0
    state.lastBufferFlushMs = stamp
end

function ConsoleMetrics:TraceIoLine(nowMs, text)
    if not self.saved or not self.saved.ioTraceEnabled then
        return false
    end

    local state = self:EnsureIoTraceState(nowMs)
    local stamp = nowMs or GetFrameTimeMilliseconds()
    if stamp >= (state.lineWindowStartMs + 1000) then
        state.lineWindowStartMs = stamp
        state.lineWindowCount = 0
        state.lineWindowDropped = 0
    end

    local lineCap = tonumber(self.saved.ioTraceMaxLinesPerSecond) or 40
    lineCap = math.max(1, math.min(400, lineCap))
    if state.lineWindowCount >= lineCap then
        state.lineWindowDropped = state.lineWindowDropped + 1
        return false
    end

    state.lineWindowCount = state.lineWindowCount + 1
    local lines = state.lineBuffer or {}
    state.lineBuffer = lines
    lines[#lines + 1] = text
    state.lineBufferChars = (state.lineBufferChars or 0) + #tostring(text)
    self:FlushIoTraceBuffer(stamp, false)
    return true
end


function ConsoleMetrics:GetTraceFpsValue()
    if type(GetFramerate) ~= "function" then
        return nil
    end
    return tonumber(GetFramerate())
end

function ConsoleMetrics:GetTraceFpsDisplayForValue(fps)
    if type(fps) ~= "number" then
        return "|cB0B0B0n/a|r"
    end

    local colorHex = "FF4242"
    if fps >= 55 then
        colorHex = "73FF8C"
    elseif fps >= 35 then
        colorHex = "FFB04D"
    end

    return string.format("|c%s%.1f|r", colorHex, fps)
end

function ConsoleMetrics:GetTraceFpsDisplay()
    return self:GetTraceFpsDisplayForValue(self:GetTraceFpsValue())
end

function ConsoleMetrics:RecordTraceFpsSample(state)
    local fps = self:GetTraceFpsValue()
    if type(fps) ~= "number" then
        return
    end

    state.fpsTotal = (state.fpsTotal or 0) + fps
    state.fpsSamples = (state.fpsSamples or 0) + 1
    if state.fpsMin == nil or fps < state.fpsMin then
        state.fpsMin = fps
    end

    local bins = state.fpsBins or {}
    state.fpsBins = bins
    local bucket = math.max(0, math.min(120, math.floor(fps + 0.5)))
    local key = bucket + 1
    bins[key] = (bins[key] or 0) + 1
end

function ConsoleMetrics:GetTraceOnePercentLow(state)
    local samples = tonumber(state and state.fpsSamples) or 0
    if samples <= 0 then
        return nil
    end

    local bins = state and state.fpsBins
    if type(bins) ~= "table" then
        return nil
    end

    local worstCount = math.max(1, math.floor(samples * 0.01 + 0.5))
    local remaining = worstCount
    local total = 0

    for bucket = 0, 120 do
        local count = tonumber(bins[bucket + 1]) or 0
        if count > 0 then
            local take = math.min(count, remaining)
            total = total + (bucket * take)
            remaining = remaining - take
            if remaining <= 0 then
                break
            end
        end
    end

    return total / worstCount
end

function ConsoleMetrics:TraceCombatEvent(nowMs, direction, result, abilityId, abilityName, sourceName, targetName, value, overflow, didDamage, didHeal, isCrit, isEffectStateChange)
    if not self.saved or not self.saved.ioTraceEnabled then
        return
    end

    local mode = self:NormalizeIoTraceMode(self.saved.ioTraceMode)
    if mode == "summary" then
        return
    end
    if mode == "in" and direction ~= "IN" then
        return
    end
    if mode == "out" and direction ~= "OUT" then
        return
    end

    local minValue = tonumber(self.saved.ioTraceMinValue) or 0
    if (tonumber(value) or 0) < minValue then
        return
    end

    local tags = {}
    if didDamage then tags[#tags + 1] = "dmg" end
    if didHeal then tags[#tags + 1] = "heal" end
    if isEffectStateChange then tags[#tags + 1] = "fx" end
    if isCrit then tags[#tags + 1] = "crit" end
    if #tags == 0 then tags[#tags + 1] = "evt" end
    self:RecordTraceFpsSample(self:EnsureIoTraceState(nowMs))

    self:TraceIoLine(
        nowMs,
        string.format(
            "TRACE %s [%s] fps=%s res=%s val=%s ovf=%s src=%s tgt=%s abil=%s[id:%d]",
            direction,
            table.concat(tags, ","),
            self:GetTraceFpsDisplay(),
            tostring(result),
            ShortNumber(value or 0),
            ShortNumber(overflow or 0),
            tostring(sourceName or "Unknown"),
            tostring(targetName or "Unknown"),
            tostring(abilityName or "Unknown Skill"),
            SafeAbilityId(abilityId)
        )
    )
end

function ConsoleMetrics:TraceResourceSample(nowMs, hpCurr, magCurr, stamCurr, ultCurr, pingMs, forceSample)
    if not self.saved or not self.saved.ioTraceEnabled then
        return
    end

    local state = self:EnsureIoTraceState(nowMs)
    state.resourceSamples = state.resourceSamples + 1
    self:RecordTraceFpsSample(state)

    local mode = self:NormalizeIoTraceMode(self.saved.ioTraceMode)
    if mode == "summary" then
        return
    end

    self:TraceIoLine(
        nowMs,
        string.format(
            "TRACE SAMPLE fps=%s hp=%s mag=%s stam=%s ult=%s ping=%s%s",
            self:GetTraceFpsDisplay(),
            hpCurr and NumberText(hpCurr) or "n/a",
            magCurr and NumberText(magCurr) or "n/a",
            stamCurr and NumberText(stamCurr) or "n/a",
            ultCurr and NumberText(ultCurr) or "n/a",
            pingMs and tostring(math.floor(pingMs + 0.5)) or "n/a",
            forceSample and " force" or ""
        )
    )
end

function ConsoleMetrics:EmitIoTraceHeartbeat(nowMs)
    if not self.saved or not self.saved.ioTraceEnabled then
        return
    end

    local state = self:EnsureIoTraceState(nowMs)
    self:FlushIoTraceBuffer(nowMs, false)
    state.updateTicks = state.updateTicks + 1
    self:RecordTraceFpsSample(state)

    local summarySeconds = tonumber(self.saved.ioTraceSummarySeconds) or 1
    summarySeconds = math.max(1, math.min(10, summarySeconds))
    if nowMs < (state.summaryStartMs + (summarySeconds * 1000)) then
        return
    end

    local elapsedMs = math.max(nowMs - state.summaryStartMs, 1)
    local elapsedSec = elapsedMs / 1000
    local eps = state.eventSeen / elapsedSec
    local avgFps = (state.fpsSamples or 0) > 0 and ((state.fpsTotal or 0) / state.fpsSamples) or nil
    local minFps = state.fpsMin
    local low1Fps = self:GetTraceOnePercentLow(state)
    self:TraceIoLine(
        nowMs,
        string.format(
            "TRACE SUMMARY %.1fs fps=%s avg=%s min=%s low1=%s ev=%d(%.1f/s) ok=%d in=%d out=%d oth=%d dmg=%d heal=%d fx=%d val=%s ovf=%s hit[min=%s max=%s n=%d] skip[nc=%d zero=%d thr=%d tflt=%d proc=%d samp=%d] samples=%d ticks=%d dropped=%d",
            elapsedSec,
            self:GetTraceFpsDisplay(),
            self:GetTraceFpsDisplayForValue(avgFps),
            self:GetTraceFpsDisplayForValue(minFps),
            self:GetTraceFpsDisplayForValue(low1Fps),
            state.eventSeen,
            eps,
            state.eventProcessed,
            state.eventIncoming,
            state.eventOutgoing,
            state.eventOther,
            state.eventDamage,
            state.eventHeal,
            state.eventEffect,
            NumberText(state.totalValue),
            NumberText(state.totalOverflow),
            NumberText(state.minHitValue or 0),
            NumberText(state.maxHitValue or 0),
            state.hitValueSamples,
            state.skippedNotCombat,
            state.skippedZero,
            state.skippedEffectThrottle,
            state.skippedTargetFilter,
            state.skippedProcessingFilter,
            state.skippedSampleByFocus,
            state.resourceSamples,
            state.updateTicks,
            state.lineWindowDropped
        )
    )

    state.summaryStartMs = nowMs
    state.eventSeen = 0
    state.eventProcessed = 0
    state.eventIncoming = 0
    state.eventOutgoing = 0
    state.eventOther = 0
    state.eventDamage = 0
    state.eventHeal = 0
    state.eventEffect = 0
    state.totalValue = 0
    state.totalOverflow = 0
    state.skippedNotCombat = 0
    state.skippedZero = 0
    state.skippedEffectThrottle = 0
    state.skippedTargetFilter = 0
    state.skippedProcessingFilter = 0
    state.skippedSampleByFocus = 0
    state.resourceSamples = 0
    state.updateTicks = 0
    state.fpsTotal = 0
    state.fpsSamples = 0
    state.fpsMin = nil
    state.fpsBins = {}
    self:FlushIoTraceBuffer(nowMs, true)
end

---------------------------------------------------------------------------
-- Player-owned heal procs
---------------------------------------------------------------------------
-- Some set/skill heals are attributed to other units by the game even though
-- the player owns them; this lets them count as outgoing healing.
local PLAYER_OWNED_HEAL_ALIASES = {
    "leeching strikes",
    "battalion defender",
    "malubeth",
    "scourge harvester",
}

function ConsoleMetrics:IsLikelyPlayerOwnedHealProc(abilityId, abilityName)
    local safeName = string.lower(tostring(abilityName or ""))
    if safeName == "" then
        return false
    end

    for i = 1, #PLAYER_OWNED_HEAL_ALIASES do
        if string.find(safeName, PLAYER_OWNED_HEAL_ALIASES[i], 1, true) ~= nil then
            return true
        end
    end

    local setMatch = self:MatchTrackedSet(abilityId, abilityName)
    return setMatch ~= nil and string.find(string.lower(setMatch.label or ""), "battalion", 1, true) ~= nil
end

---------------------------------------------------------------------------
-- Per-ability stat tracking
---------------------------------------------------------------------------
-- Every per-ability map (skills, DoTs, HoTs, incoming skills, set procs) uses
-- the same entry shape so the dialogs can render them with one code path.

local function SafeName(abilityName, fallback)
    if type(abilityName) == "string" and abilityName ~= "" then
        return abilityName
    end
    return fallback
end

local function AcquireStatEntry(map, key, name, abilityId, extraFields)
    local info = map[key]
    if not info then
        info = {
            abilityId = abilityId or 0,
            name = name,
            damage = 0,
            heal = 0,
            hits = 0,
            crits = 0,
            maxHit = 0,
            maxHeal = 0,
        }
        if extraFields then
            for k, v in pairs(extraFields) do
                info[k] = v
            end
        end
        map[key] = info
    end
    return info
end

local function AccumulateStat(info, damageValue, healValue, isCrit)
    damageValue = damageValue or 0
    healValue = healValue or 0
    info.damage = info.damage + damageValue
    info.heal = info.heal + healValue
    info.hits = info.hits + 1
    if isCrit then
        info.crits = info.crits + 1
    end
    if damageValue > (info.maxHit or 0) then
        info.maxHit = damageValue
    end
    if healValue > (info.maxHeal or 0) then
        info.maxHeal = healValue
    end
end

local function BackfillEntry(info, abilityId, sourceName, effectName)
    local safeId = SafeAbilityId(abilityId)
    if (not info.abilityId or info.abilityId == 0) and safeId > 0 then
        info.abilityId = safeId
    end
    if (not info.source or info.source == "Unknown") and sourceName and sourceName ~= "" then
        info.source = sourceName
    end
    if effectName and effectName ~= "" and (not info.effectName or info.effectName == "") then
        info.effectName = effectName
    end
end

function ConsoleMetrics:TrackSkill(abilityId, abilityName, damageValue, healValue, isCrit)
    local skillId = abilityId or 0
    local info = AcquireStatEntry(self.fight.skillMap, skillId, SafeName(abilityName, "Unknown Skill"), skillId)
    AccumulateStat(info, damageValue, healValue, isCrit)
end

function ConsoleMetrics:TrackDotTick(abilityId, abilityName, damageValue, isCrit)
    local skillId = abilityId or 0
    local info = AcquireStatEntry(self.fight.dotMap, skillId, SafeName(abilityName, "Unknown DoT"), skillId)
    AccumulateStat(info, damageValue, 0, isCrit)
end

function ConsoleMetrics:TrackHotTick(abilityId, abilityName, healValue, isCrit)
    local skillId = abilityId or 0
    local info = AcquireStatEntry(self.fight.hotMap, skillId, SafeName(abilityName, "Unknown HoT"), skillId)
    AccumulateStat(info, 0, healValue, isCrit)
end

-- sourceName must already be resolved through UnitName.
function ConsoleMetrics:TrackIncomingSkill(abilityId, abilityName, damageValue, isCrit, sourceName)
    if not self.fight or damageValue <= 0 then
        return
    end

    local skillId = abilityId or 0
    local info = AcquireStatEntry(self.fight.incomingSkillMap, skillId, SafeName(abilityName, "Unknown Enemy Skill"), skillId, { source = sourceName })
    AccumulateStat(info, damageValue, 0, isCrit)
    BackfillEntry(info, abilityId, sourceName)
end

function ConsoleMetrics:TrackIncomingSetDamage(abilityId, abilityName, damageValue, isCrit, sourceName)
    if not self.fight or damageValue <= 0 then
        return
    end

    local setMatch = self:MatchTrackedSet(abilityId, abilityName)
    if not setMatch then
        return
    end

    local key = string.lower(setMatch.label or "")
    local info = AcquireStatEntry(self.fight.incomingSetDamageMap, key, setMatch.label, SafeAbilityId(abilityId), {
        scene = setMatch.scene,
        effectName = abilityName,
        source = sourceName,
    })
    AccumulateStat(info, damageValue, 0, isCrit)
    BackfillEntry(info, abilityId, sourceName, abilityName)
end

function ConsoleMetrics:TrackIncomingLikelySetProc(abilityId, abilityName, damageValue, isCrit, sourceName)
    if not self.fight or damageValue <= 0 then
        return
    end

    if self:MatchTrackedSet(abilityId, abilityName) then
        return
    end

    local matched, reason, score = ClassifyLikelySetProc(abilityName)
    if not matched then
        return
    end

    local key = string.lower(abilityName or "unknown")
    local info = AcquireStatEntry(self.fight.incomingLikelySetProcMap, key, SafeName(abilityName, "Unknown Likely Set Proc"), SafeAbilityId(abilityId), {
        source = sourceName,
        heuristicReason = reason,
        heuristicScore = score,
    })
    AccumulateStat(info, damageValue, 0, isCrit)
    BackfillEntry(info, abilityId, sourceName)
    if (not info.heuristicReason or info.heuristicReason == "") and reason and reason ~= "" then
        info.heuristicReason = reason
    end
    if score and score > (info.heuristicScore or 0) then
        info.heuristicScore = score
    end
end

---------------------------------------------------------------------------
-- Targets, moments, effects, protection inference, resource sampling
---------------------------------------------------------------------------
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
        local setKey = string.lower(setMatch.label or "")
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
    local alpha = Clamp(tonumber(self.saved and self.saved.drSampleAlpha) or self.defaults.drSampleAlpha, 0.05, 0.85)
    if (info.samples or 0) <= 0 then
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

---------------------------------------------------------------------------
-- Fight lifecycle
---------------------------------------------------------------------------
-- Peak DPS/HPS are the highest running averages observed during the fight.
function ConsoleMetrics:UpdateFightPeaks(nowMs)
    local fight = self.fight
    if not fight then
        return
    end

    local duration = GetFightDurationSeconds(fight, nowMs or GetFrameTimeMilliseconds())
    if duration <= 0 then
        return
    end

    fight.peakDps = math.max(fight.peakDps or 0, (fight.totalDamage or 0) / duration)
    fight.peakHps = math.max(fight.peakHps or 0, (fight.totalHeal or 0) / duration)
end

function ConsoleMetrics:StartFight()
    if self.inCombat then
        return
    end

    local nowMs = GetFrameTimeMilliseconds()
    self.inCombat = true
    self.fight = NewFight(nowMs)
    self.fightSnapshotCache = nil
    self.lastEffectStateEventMs = 0
    self.lastTraceTargetMatchMs = nil
    self.lastProtectionUpdateMs = 0
    self.lastMetricsUpdateMs = 0

    -- Auto clear: jump the dialog back to the live view when a new fight begins.
    if not self.saved or self.saved.autoClearOnNextFight ~= false then
        self.viewFightIndex = 0
    end

    self:SampleFightResources(nowMs, true)
    self:DebugPrint(string.format("Combat started (trace mode: %s)", tostring(self.saved and self.saved.ioTraceMode or "summary")))
end

function ConsoleMetrics:StopFight()
    if not self.inCombat or not self.fight then
        return
    end

    local nowMs = GetFrameTimeMilliseconds()
    self:SampleFightResources(nowMs, true)
    self:UpdateProtectionInference(nowMs)
    self:UpdateFightPeaks(nowMs)
    self.inCombat = false
    self.fight.endMs = nowMs
    self.fight.snapshotRev = (self.fight.snapshotRev or 0) + 1

    local duration = GetFightDurationSeconds(self.fight, nowMs)
    local dps = duration > 0 and (self.fight.totalDamage / duration) or 0
    local hps = duration > 0 and (self.fight.totalHeal / duration) or 0
    self:DebugPrint(string.format("Fight ended: %.1fs, %s DPS, %s HPS", duration, ShortNumber(dps), ShortNumber(hps)))

    self:AddCurrentFightToHistory()
    if self:IsFightViewDialogShowing() then
        self:ArmDialogAutoHide()
        self:RefreshFightViewDialog()
        self.lastDialogRefreshKey = nil
    end
end

function ConsoleMetrics:OnCombatState(_, inCombat)
    if inCombat then
        self:StartFight()
    else
        self:StopFight()
    end
end

---------------------------------------------------------------------------
-- Combat event handler
---------------------------------------------------------------------------
function ConsoleMetrics:OnCombatEvent(
    _,
    result,
    _,
    abilityName,
    _,
    _,
    sourceName,
    sourceType,
    targetName,
    targetType,
    hitValue,
    _,
    _,
    _,
    _,
    _,
    abilityId,
    overflow
)
    local nowMs = GetFrameTimeMilliseconds()
    local traceState = nil
    if self.saved and self.saved.ioTraceEnabled then
        traceState = self:EnsureIoTraceState(nowMs)
        traceState.eventSeen = traceState.eventSeen + 1
    end

    local effectiveValue = hitValue or 0
    local overflowValue = overflow or 0
    -- Effect state transitions frequently carry zero hit values, so we must keep them for uptime tracking.
    local isEffectStateChange = IsEffectGainedResult(result) or IsEffectFadedResult(result)

    if not self.inCombat or not self.fight or ((effectiveValue <= 0 and overflowValue <= 0) and not isEffectStateChange) then
        if traceState then
            if not self.inCombat or not self.fight then
                traceState.skippedNotCombat = traceState.skippedNotCombat + 1
            else
                traceState.skippedZero = traceState.skippedZero + 1
            end
        end
        return
    end

    local didDamage = IsDamageResult(result)
    local didHeal = IsHealResult(result)


    -- Weapon swapping can produce bursts of effect-only events; cap processing frequency.
    if isEffectStateChange and not didDamage and not didHeal then
        local lastEffectEvent = self.lastEffectStateEventMs or 0
        if nowMs < (lastEffectEvent + EFFECT_STATE_EVENT_THROTTLE_MS) then
            if traceState then
                traceState.skippedEffectThrottle = traceState.skippedEffectThrottle + 1
            end
            return
        end
        self.lastEffectStateEventMs = nowMs
    end

    -- UnitName is O(1) via UNIT_NAME_CACHE; resolve upfront to avoid two closure allocations per event.
    local resolvedSourceName = UnitName(sourceName)
    local resolvedTargetName = UnitName(targetName)
    local traceTargetMatch = self:ShouldTraceTarget(resolvedSourceName, resolvedTargetName)

    if traceTargetMatch then
        self.lastTraceTargetMatchMs = nowMs
    elseif traceState then
        traceState.skippedTargetFilter = traceState.skippedTargetFilter + 1
    end

    if not traceTargetMatch and self:IsTraceFocusProcessingEnabled() then
        if traceState then
            traceState.skippedProcessingFilter = traceState.skippedProcessingFilter + 1
        end
        return
    end

    -- Mark event-driven state mutation for snapshot cache invalidation (only for events we keep).
    self.fight.snapshotRev = (self.fight.snapshotRev or 0) + 1

    local sourceIsPlayer = sourceType == COMBAT_UNIT_TYPE_PLAYER
        or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
        or resolvedSourceName == self.playerName
    local targetIsPlayer = targetType == COMBAT_UNIT_TYPE_PLAYER or resolvedTargetName == self.playerName

    local isCrit = IsCriticalResult(result)
    local safeAbilityName = (abilityName and abilityName ~= "") and abilityName or "Unknown Skill"
    local playerOwnedHealProc = didHeal and not sourceIsPlayer and self:IsLikelyPlayerOwnedHealProc(abilityId, safeAbilityName)
    local isOutgoingEvent = false
    local isIncomingEvent = false

    local totalCombatValue = effectiveValue + overflowValue
    if traceState and traceTargetMatch then
        traceState.eventProcessed = traceState.eventProcessed + 1
        if didDamage then
            traceState.eventDamage = traceState.eventDamage + 1
        end
        if didHeal then
            traceState.eventHeal = traceState.eventHeal + 1
        end
        if isEffectStateChange then
            traceState.eventEffect = traceState.eventEffect + 1
        end
        traceState.totalValue = traceState.totalValue + math.max(0, totalCombatValue)
        traceState.totalOverflow = traceState.totalOverflow + math.max(0, overflowValue)
        if (didDamage or didHeal) and effectiveValue > 0 then
            traceState.hitValueSamples = (traceState.hitValueSamples or 0) + 1
            if traceState.minHitValue == nil or effectiveValue < traceState.minHitValue then
                traceState.minHitValue = effectiveValue
            end
            if traceState.maxHitValue == nil or effectiveValue > traceState.maxHitValue then
                traceState.maxHitValue = effectiveValue
            end
        end
    end

    -- Accumulate every unique ability name->ID pair seen this session for /cm dumpsets discovery.
    local safeIdForLog = SafeAbilityId(abilityId)
    if safeIdForLog > 0 and safeAbilityName ~= "Unknown Skill" and not self.observedAbilityLog[safeIdForLog] then
        local maxObserved = tonumber(OBSERVED_ABILITY_LOG_MAX) or 2048
        local observedCount = tonumber(self.observedAbilityCount) or 0
        if observedCount < maxObserved then
            self.observedAbilityLog[safeIdForLog] = safeAbilityName
            self.observedAbilityCount = observedCount + 1
        end
    end

    -- Update effect trackers before damage/heal aggregation so live dialog refresh sees current uptime state.
    -- Guard: skip the method call entirely when neither side involves the player (common in PvP).
    if sourceIsPlayer or targetIsPlayer then
        self:TrackMajorMinorAndSets(
            nowMs,
            result,
            abilityId,
            safeAbilityName,
            sourceIsPlayer,
            targetIsPlayer,
            didDamage,
            didHeal,
            totalCombatValue
        )
    end

    if (sourceIsPlayer and (didDamage or didHeal)) or playerOwnedHealProc then
        isOutgoingEvent = true
        if traceState and traceTargetMatch then
            traceState.eventOutgoing = traceState.eventOutgoing + 1
        end
        if traceTargetMatch then
            self:TraceCombatEvent(
                nowMs,
                "OUT",
                result,
                abilityId,
                safeAbilityName,
                resolvedSourceName,
                resolvedTargetName,
                totalCombatValue,
                overflowValue,
                didDamage,
                didHeal,
                isCrit,
                isEffectStateChange
            )
        end

        local damageValue = didDamage and (effectiveValue + overflowValue) or 0
        local healValue = didHeal and effectiveValue or 0
        local overflowHealValue = didHeal and overflowValue or 0

        if didDamage and damageValue > 0 then
            local tracker = self.fight.damageWindowTracker
            if not tracker then
                tracker = NewThroughputWindowTracker(THROUGHPUT_WINDOW_INTERVAL_MS)
                self.fight.damageWindowTracker = tracker
            end
            AddThroughputWindowValueByTime(tracker, self.fight.startMs, nowMs, damageValue)
        end
        if didHeal and healValue > 0 then
            local tracker = self.fight.healWindowTracker
            if not tracker then
                tracker = NewThroughputWindowTracker(THROUGHPUT_WINDOW_INTERVAL_MS)
                self.fight.healWindowTracker = tracker
            end
            AddThroughputWindowValueByTime(tracker, self.fight.startMs, nowMs, healValue)
        end

        self.fight.totalDamage = self.fight.totalDamage + damageValue
        self.fight.totalOverflowDamage = self.fight.totalOverflowDamage + (didDamage and overflowValue or 0)
        self.fight.totalHeal = self.fight.totalHeal + healValue
        self.fight.totalOverflowHeal = self.fight.totalOverflowHeal + overflowHealValue
        self.fight.hits = self.fight.hits + 1
        if effectiveValue > 0 then
            if self.fight.minHitValue == nil or effectiveValue < self.fight.minHitValue then
                self.fight.minHitValue = effectiveValue
            end
            if self.fight.maxHitValue == nil or effectiveValue > self.fight.maxHitValue then
                self.fight.maxHitValue = effectiveValue
            end
        end
        if isCrit then
            self.fight.crits = self.fight.crits + 1
        end

        if didDamage and result == ACTION_RESULT_BLOCKED_DAMAGE then
            self.fight.totalBlockedDamage = self.fight.totalBlockedDamage + damageValue
        end

        if didDamage then
            if result == ACTION_RESULT_DAMAGE_SHIELDED then
                self.fight.totalShieldedDamage = self.fight.totalShieldedDamage + damageValue
            elseif overflowValue > 0 then
                self.fight.totalShieldedDamage = self.fight.totalShieldedDamage + overflowValue
            end
        end

        self:TrackSkill(abilityId, safeAbilityName, damageValue, healValue, isCrit)
        -- Track periodic ticks separately for per-ability DoT/HoT breakdown lists.
        if didDamage and (result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL) then
            self:TrackDotTick(abilityId, safeAbilityName, damageValue, isCrit)
        end
        if didHeal and (result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL) then
            self:TrackHotTick(abilityId, safeAbilityName, healValue, isCrit)
        end
        if didHeal then
            self:RecordTopHealingMoment(
                abilityId,
                safeAbilityName,
                resolvedTargetName,
                healValue,
                overflowHealValue,
                isCrit
            )
        end

        if didDamage then
            local targetInfo = self:AcquireTargetInfo(resolvedTargetName)
            targetInfo.damage = targetInfo.damage + damageValue
            targetInfo.effective = targetInfo.effective + effectiveValue
            targetInfo.overflow = targetInfo.overflow + overflowValue
            targetInfo.hits = targetInfo.hits + 1

            if result == ACTION_RESULT_BLOCKED_DAMAGE then
                targetInfo.blocked = targetInfo.blocked + damageValue
                self:RecordTopMitigationMoment(
                    "-",
                    resolvedTargetName,
                    "Outgoing blocked",
                    damageValue,
                    abilityId,
                    safeAbilityName
                )
            end

            if result == ACTION_RESULT_DAMAGE_SHIELDED then
                targetInfo.shielded = targetInfo.shielded + damageValue
                self:RecordTopMitigationMoment(
                    "-",
                    resolvedTargetName,
                    "Outgoing shielded",
                    damageValue,
                    abilityId,
                    safeAbilityName
                )
            elseif overflowValue > 0 then
                targetInfo.shielded = targetInfo.shielded + overflowValue
                self:RecordTopMitigationMoment(
                    "-",
                    resolvedTargetName,
                    "Outgoing overflow",
                    overflowValue,
                    abilityId,
                    safeAbilityName
                )
            end
        end
    end

    if targetIsPlayer and didDamage and not sourceIsPlayer then
        isIncomingEvent = true
        if traceState and traceTargetMatch then
            traceState.eventIncoming = traceState.eventIncoming + 1
        end
        if traceTargetMatch then
            self:TraceCombatEvent(
                nowMs,
                "IN",
                result,
                abilityId,
                safeAbilityName,
                resolvedSourceName,
                resolvedTargetName,
                totalCombatValue,
                overflowValue,
                didDamage,
                didHeal,
                isCrit,
                isEffectStateChange
            )
        end

        self.fight.totalTaken = self.fight.totalTaken + effectiveValue
        self.fight.totalIncomingOverflowDamage = self.fight.totalIncomingOverflowDamage + overflowValue

        local incomingDamageValue = effectiveValue + overflowValue
        self:TrackIncomingSkill(abilityId, safeAbilityName, incomingDamageValue, isCrit, resolvedSourceName)
        self:TrackIncomingSetDamage(abilityId, safeAbilityName, incomingDamageValue, isCrit, resolvedSourceName)
        self:TrackIncomingLikelySetProc(abilityId, safeAbilityName, incomingDamageValue, isCrit, resolvedSourceName)
        if result == ACTION_RESULT_BLOCKED_DAMAGE then
            self.fight.totalIncomingBlockedDamage = self.fight.totalIncomingBlockedDamage + incomingDamageValue
            self:RecordTopMitigationMoment(
                "+",
                resolvedSourceName,
                "Incoming blocked",
                incomingDamageValue,
                abilityId,
                safeAbilityName
            )
        end
        if result == ACTION_RESULT_DAMAGE_SHIELDED then
            self.fight.totalIncomingShieldedDamage = self.fight.totalIncomingShieldedDamage + incomingDamageValue
            self:RecordTopMitigationMoment(
                "+",
                resolvedSourceName,
                "Incoming shielded",
                incomingDamageValue,
                abilityId,
                safeAbilityName
            )
        elseif overflowValue > 0 then
            self.fight.totalIncomingShieldedDamage = self.fight.totalIncomingShieldedDamage + overflowValue
            self:RecordTopMitigationMoment(
                "+",
                resolvedSourceName,
                "Incoming overflow",
                overflowValue,
                abilityId,
                safeAbilityName
            )
        end
    end

    if traceState and traceTargetMatch and not isIncomingEvent and not isOutgoingEvent then
        traceState.eventOther = traceState.eventOther + 1
        self:TraceCombatEvent(
            nowMs,
            "OTHER",
            result,
            abilityId,
            safeAbilityName,
            resolvedSourceName,
            resolvedTargetName,
            totalCombatValue,
            overflowValue,
            didDamage,
            didHeal,
            isCrit,
            isEffectStateChange
        )
    end
end
