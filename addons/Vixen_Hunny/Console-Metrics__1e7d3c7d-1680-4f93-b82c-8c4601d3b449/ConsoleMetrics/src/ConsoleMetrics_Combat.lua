function ConsoleMetrics:GetFightDuration(nowMs)
    if not self.fight or not self.fight.startMs then
        return 0
    end

    local endMs = nowMs
    if self.fight.endMs then
        endMs = self.fight.endMs
    end

    return math.max((endMs - self.fight.startMs) / 1000, 0)
end

function ConsoleMetrics:ShouldPushCombatScrollLine(nowMs)
    if not self.inCombat then
        return true
    end

    local timestamp = nowMs or GetFrameTimeMilliseconds()
    local last = self.lastScrollLineAtMs or 0
    if timestamp < (last + COMBAT_SCROLL_EVENT_THROTTLE_MS) then
        return false
    end

    self.lastScrollLineAtMs = timestamp
    return true
end

function ConsoleMetrics:PushScrollLine(text, color)
    local list = self.scrollEntries
    list[#list + 1] = {
        text = text,
        color = color,
        timeMs = GetFrameTimeMilliseconds(),
    }

    local startIndex = tonumber(list._cmStart) or 1
    local scrollLimit = math.max(1, tonumber(self.saved and self.saved.scrollSize) or 8)
    local logicalCount = (#list - startIndex) + 1
    if logicalCount > scrollLimit then
        startIndex = startIndex + (logicalCount - scrollLimit)
    end
    list._cmStart = startIndex

    -- Compact infrequently to avoid per-event front shifts while keeping memory bounded.
    if startIndex > 64 then
        local dst = 1
        for i = startIndex, #list do
            list[dst] = list[i]
            dst = dst + 1
        end
        for i = dst, #list do
            list[i] = nil
        end
        list._cmStart = 1
    end

    -- Rendering is handled by the throttled OnUpdate refresh path.
    self.lastScrollUpdateMs = 0
end

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
        if type(GetUnitName) ~= "function" then
            return "", "reticle"
        end
        local reticleName = UnitName(GetUnitName("reticleover"))
        local normalized = self:NormalizeIoTraceName(reticleName)
        return normalized, "reticle"
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

function ConsoleMetrics:GetTraceFpsText()
    local getFramerate = type(_G) == "table" and _G.GetFramerate or nil
    if type(getFramerate) ~= "function" then
        return "n/a"
    end

    local fps = tonumber(getFramerate())
    if not fps then
        return "n/a"
    end

    return string.format("%.1f", fps)
end

function ConsoleMetrics:GetTraceFpsValue()
    local fpsText = self:GetTraceFpsText()
    return tonumber(fpsText)
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

local PLAYER_OWNED_HEAL_ALIASES = {
    "leeching strikes",
    "battalion defender",
    "malubeth",
    "scourge harvester",
}

function ConsoleMetrics:IsLikelyPlayerOwnedHealProc(abilityId, abilityName, resolvedSourceName)
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
    if setMatch and string.find(string.lower(setMatch.label or ""), "battalion", 1, true) ~= nil then
        return true
    end

    if resolvedSourceName and resolvedSourceName == self.playerName then
        return true
    end

    return false
end

function ConsoleMetrics:TrackSkill(abilityId, abilityName, damageValue, healValue, isCrit)
    local skillId = abilityId or 0
    local info = self.fight.skillMap[skillId]
    if not info then
        info = {
            abilityId = skillId,
            name = abilityName ~= "" and abilityName or "Unknown Skill",
            damage = 0,
            heal = 0,
            hits = 0,
            crits = 0,
            maxHit  = 0,
            maxHeal = 0,
        }
        self.fight.skillMap[skillId] = info
    end

    info.damage = info.damage + damageValue
    info.heal   = info.heal   + healValue
    info.hits   = info.hits   + 1
    if isCrit then
        info.crits = info.crits + 1
    end
    if damageValue > info.maxHit  then info.maxHit  = damageValue end
    if healValue   > info.maxHeal then info.maxHeal = healValue   end
    self.skillListDirty = true
end

function ConsoleMetrics:TrackDotTick(abilityId, abilityName, damageValue, isCrit)
    local skillId = abilityId or 0
    local info = self.fight.dotMap[skillId]
    if not info then
        info = {
            abilityId = skillId,
            name = (abilityName and abilityName ~= "") and abilityName or "Unknown DoT",
            damage = 0,
            heal = 0,
            hits = 0,
            crits = 0,
            maxHit = 0,
        }
        self.fight.dotMap[skillId] = info
    end
    info.damage = info.damage + damageValue
    info.hits = info.hits + 1
    if isCrit then
        info.crits = info.crits + 1
    end
    if damageValue > info.maxHit then info.maxHit = damageValue end
end

function ConsoleMetrics:TrackHotTick(abilityId, abilityName, healValue, isCrit)
    local skillId = abilityId or 0
    local info = self.fight.hotMap[skillId]
    if not info then
        info = {
            abilityId = skillId,
            name = (abilityName and abilityName ~= "") and abilityName or "Unknown HoT",
            damage = 0,
            heal = 0,
            hits = 0,
            crits = 0,
            maxHeal = 0,
        }
        self.fight.hotMap[skillId] = info
    end
    info.heal = info.heal + healValue
    info.hits = info.hits + 1
    if isCrit then
        info.crits = info.crits + 1
    end
    if healValue > info.maxHeal then info.maxHeal = healValue end
end

function ConsoleMetrics:TrackIncomingSkill(abilityId, abilityName, damageValue, isCrit, sourceName)
    if not self.fight or damageValue <= 0 then
        return
    end

    local skillId = abilityId or 0
    local info = self.fight.incomingSkillMap[skillId]
    if not info then
        info = {
            abilityId = skillId,
            name = (abilityName and abilityName ~= "") and abilityName or "Unknown Enemy Skill",
            damage = 0,
            heal = 0,
            hits = 0,
            crits = 0,
            source = UnitName(sourceName),
        }
        self.fight.incomingSkillMap[skillId] = info
    end

    info.damage = info.damage + damageValue
    info.hits = info.hits + 1
    if isCrit then
        info.crits = info.crits + 1
    end
    if not info.source or info.source == "Unknown" then
        info.source = UnitName(sourceName)
    end
end

function ConsoleMetrics:TrackIncomingSetDamage(abilityId, abilityName, damageValue, isCrit, sourceName)
    if not self.fight or damageValue <= 0 then
        return
    end

    local setMatch = self:MatchTrackedSet(abilityId, abilityName)
    if not setMatch then
        return
    end

    local key = string.lower(setMatch.label)
    local info = self.fight.incomingSetDamageMap[key]
    if not info then
        info = {
            abilityId = SafeAbilityId(abilityId),
            name = setMatch.label,
            damage = 0,
            heal = 0,
            hits = 0,
            crits = 0,
            scene = setMatch.scene,
            effectName = abilityName,
            source = UnitName(sourceName),
        }
        self.fight.incomingSetDamageMap[key] = info
    end

    info.damage = info.damage + damageValue
    info.hits = info.hits + 1
    if isCrit then
        info.crits = info.crits + 1
    end
    if (not info.abilityId or info.abilityId == 0) and SafeAbilityId(abilityId) > 0 then
        info.abilityId = SafeAbilityId(abilityId)
    end
    if (not info.effectName or info.effectName == "") and abilityName and abilityName ~= "" then
        info.effectName = abilityName
    end
    if not info.source or info.source == "Unknown" then
        info.source = UnitName(sourceName)
    end
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
    local info = self.fight.incomingLikelySetProcMap[key]
    if not info then
        info = {
            abilityId = SafeAbilityId(abilityId),
            name = (abilityName and abilityName ~= "") and abilityName or "Unknown Likely Set Proc",
            damage = 0,
            heal = 0,
            hits = 0,
            crits = 0,
            source = UnitName(sourceName),
            heuristicReason = reason,
            heuristicScore = score,
        }
        self.fight.incomingLikelySetProcMap[key] = info
    end

    info.damage = info.damage + damageValue
    info.hits = info.hits + 1
    if isCrit then
        info.crits = info.crits + 1
    end
    if (not info.abilityId or info.abilityId == 0) and SafeAbilityId(abilityId) > 0 then
        info.abilityId = SafeAbilityId(abilityId)
    end
    if not info.source or info.source == "Unknown" then
        info.source = UnitName(sourceName)
    end
    if (not info.heuristicReason or info.heuristicReason == "") and reason and reason ~= "" then
        info.heuristicReason = reason
    end
    if score and score > (info.heuristicScore or 0) then
        info.heuristicScore = score
    end
end

function ConsoleMetrics:StartFight()
    if self.inCombat then
        return
    end

    local nowMs = GetFrameTimeMilliseconds()
    self.inCombat = true
    self.hideAtMs = nil
    self.viewFightIndex = 0

    if self.saved.autoClearOnNextFight then
        self.scrollEntries = {}
    end

    self.fight = NewFight(nowMs)
    self.skillListDirty = true
    self.lastScrollLineAtMs = 0
    self.lastEffectStateEventMs = 0
    self.lastTraceTargetMatchMs = nil
    self:SampleFightResources(nowMs, true)
    self.lastDebugPrintAtMs = nil

    if self.ui.root then
        self.ui.root:SetHidden(true)
    end

    self:PushScrollLine("Combat started", COMBAT_TEXT_COLORS.start)
    d("ConsoleMetrics: Combat Started with " .. (self.saved and self.saved.ioTraceMode or "summary") .. " trace mode")
    self:UpdateMetrics()
end

function ConsoleMetrics:StopFight()
    if not self.inCombat or not self.fight then
        return
    end

    local nowMs = GetFrameTimeMilliseconds()
    self:SampleFightResources(nowMs, true)
    self:UpdateProtectionInference(nowMs)
    self.inCombat = false
    self.fight.endMs = nowMs
    self.hideAtMs = nowMs + POST_COMBAT_VISIBLE_MS

    local duration = self:GetFightDuration(nowMs)
    local dps = 0
    if duration > 0 then
        dps = self.fight.totalDamage / duration
    end

    self:PushScrollLine(
        string.format(
            "Fight: %ss, %s DPS, %s HPS",
            string.format("%.1f", duration),
            ShortNumber(dps),
            ShortNumber(duration > 0 and (self.fight.totalHeal / duration) or 0)
        ),
        COMBAT_TEXT_COLORS.summary
    )

    self:AddCurrentFightToHistory()
    if self:IsFightViewDialogShowing() then
        self:ArmDialogAutoHide()
        if self.ui.fightViewDialog then
            self:PopulateFightViewDialog(self.ui.fightViewDialog)
            self.lastDialogRefreshKey = nil
        end
    end
    self:UpdateMetrics()
end

function ConsoleMetrics:OnCombatState(_, inCombat)
    if inCombat then
        self:StartFight()
    else
        self:StopFight()
    end
end

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

    -- Mark event-driven state mutation for snapshot cache invalidation.
    self.fight.snapshotRev = (self.fight.snapshotRev or 0) + 1

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

    local sourceIsPlayer = sourceType == COMBAT_UNIT_TYPE_PLAYER
        or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
        or resolvedSourceName == self.playerName
    local targetIsPlayer = targetType == COMBAT_UNIT_TYPE_PLAYER or resolvedTargetName == self.playerName

    local isCrit = IsCriticalResult(result)
    local safeAbilityName = (abilityName and abilityName ~= "") and abilityName or "Unknown Skill"
    local playerOwnedHealProc = didHeal and not sourceIsPlayer and self:IsLikelyPlayerOwnedHealProc(abilityId, safeAbilityName, resolvedSourceName)
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
    local allowScrollLine = self:ShouldPushCombatScrollLine(nowMs)

    -- Accumulate every unique ability name -> ID pair seen this session for /cm dumpsets discovery.
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

        if didDamage then
            if allowScrollLine then
                local overflowText = overflowValue > 0 and string.format(" (+%s ovf)", ShortNumber(overflowValue)) or ""
                self:PushScrollLine(
                    string.format("%s%s  %s", ShortNumber(damageValue), overflowText, FormatAbilityIdentity(safeAbilityName, abilityId)),
                    isCrit and COMBAT_TEXT_COLORS.damageCrit or COMBAT_TEXT_COLORS.damage
                )
            end
        elseif didHeal then
            if allowScrollLine then
                local overflowText = overflowHealValue > 0 and string.format(" (+%s ovh)", ShortNumber(overflowHealValue)) or ""
                self:PushScrollLine(
                    string.format("+%s%s  %s", ShortNumber(healValue), overflowText, FormatAbilityIdentity(safeAbilityName, abilityId)),
                    isCrit and COMBAT_TEXT_COLORS.healCrit or COMBAT_TEXT_COLORS.heal
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
        self:TrackIncomingSkill(abilityId, safeAbilityName, incomingDamageValue, isCrit, sourceName)
        self:TrackIncomingSetDamage(abilityId, safeAbilityName, incomingDamageValue, isCrit, sourceName)
        self:TrackIncomingLikelySetProc(abilityId, safeAbilityName, incomingDamageValue, isCrit, sourceName)
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

        if allowScrollLine then
            local overflowText = overflowValue > 0 and string.format(" (+%s ovf)", ShortNumber(overflowValue)) or ""
            self:PushScrollLine(
                string.format("-%s%s  from %s via %s", ShortNumber(effectiveValue), overflowText, resolvedSourceName, FormatAbilityIdentity(safeAbilityName, abilityId)),
                COMBAT_TEXT_COLORS.taken
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

function ConsoleMetrics:RefreshScroll()
    if not self.ui.scrollLabels then
        return
    end

    local nowMs = GetFrameTimeMilliseconds()
    local list = self.scrollEntries or {}
    local startIndex = tonumber(list._cmStart) or 1

    for index, label in ipairs(self.ui.scrollLabels) do
        local sourceIndex = #list - index + 1
        local entry = sourceIndex >= startIndex and list[sourceIndex] or nil

        if entry then
            local age = (nowMs - entry.timeMs) / 1000
            local alpha = Clamp(1 - (age / 6), 0.25, 1)
            local cachedText = label._cmLastText
            if cachedText ~= entry.text then
                label:SetText(entry.text)
                label._cmLastText = entry.text
            end
            label:SetColor(entry.color[1], entry.color[2], entry.color[3], alpha)
            label:SetHidden(false)
        else
            label:SetHidden(true)
        end
    end
end

function ConsoleMetrics:UpdateTopSkills()
    if not self.ui.skillLabels or not self.fight then
        return
    end

    if self.skillListDirty or not self.lastSortedSkillList or #self.lastSortedSkillList == 0 then
        self.lastSortedSkillList = SortSkillEntries(self.fight.skillMap)
        self.skillListDirty = false
    end

    local skillList = self.lastSortedSkillList

    for i, label in ipairs(self.ui.skillLabels) do
        local info = skillList[i]
        if info then
            local critPct = 0
            if info.hits > 0 then
                critPct = (info.crits / info.hits) * 100
            end

            local nextText = string.format(
                "%d. %s [id:%d]  %s  (%.0f%%)",
                i,
                info.name,
                info.abilityId or 0,
                ShortNumber(info.damage),
                critPct
            )

            if label._cmLastText ~= nextText then
                label:SetText(nextText)
                label._cmLastText = nextText
            end
            label:SetHidden(false)
        else
            local emptyText = string.format("%d. -", i)
            if label._cmLastText ~= emptyText then
                label:SetText(emptyText)
                label._cmLastText = emptyText
            end
            label:SetHidden(false)
        end
    end
end

-- Metric-cache helpers (module-level so UpdateMetrics does not allocate closures per call).
local function SetTextIfChanged(metricCache, cacheKey, control, text)
    if metricCache[cacheKey] ~= text then
        control:SetText(text)
        metricCache[cacheKey] = text
    end
end

local function SetBarRangeIfChanged(metricCache, cacheKey, bar, minValue, maxValue)
    local cached = metricCache[cacheKey]
    if not cached or cached.min ~= minValue or cached.max ~= maxValue then
        bar:SetMinMax(minValue, maxValue)
        metricCache[cacheKey] = { min = minValue, max = maxValue }
    end
end

local function SetBarValueIfChanged(metricCache, cacheKey, bar, value, epsilon)
    local cached = metricCache[cacheKey]
    epsilon = epsilon or 0.1
    if cached == nil or math.abs(cached - value) >= epsilon then
        bar:SetValue(value)
        metricCache[cacheKey] = value
    end
end

function ConsoleMetrics:UpdateMetrics()
    if not self.fight then
        return
    end

    local nowMs = GetFrameTimeMilliseconds()
    local duration = self:GetFightDuration(nowMs)
    local dps = duration > 0 and (self.fight.totalDamage / duration) or 0
    local hps = duration > 0 and (self.fight.totalHeal / duration) or 0
    local critPct = self.fight.hits > 0 and (self.fight.crits / self.fight.hits) * 100 or 0

    self.fight.peakDps = math.max(self.fight.peakDps, dps)
    self.fight.peakHps = math.max(self.fight.peakHps, hps)

    if not self.ui.rows then
        return
    end

    local totalMax = math.max(self.fight.totalDamage, self.fight.totalHeal, self.fight.totalTaken, 1)
    local rateMax = math.max(dps, hps, 1)
    local metricCache = self.uiMetricCache or {}
    self.uiMetricCache = metricCache
    local rows = self.ui.rows

    SetTextIfChanged(metricCache, "durationText", self.ui.durationLabel, string.format("Encounter  %.1fs", duration))

    SetTextIfChanged(metricCache, "dpsText",    rows.dps.value,    ShortNumber(dps))
    SetTextIfChanged(metricCache, "hpsText",    rows.hps.value,    ShortNumber(hps))
    SetTextIfChanged(metricCache, "damageText", rows.damage.value, NumberText(self.fight.totalDamage))
    SetTextIfChanged(metricCache, "healText",   rows.heal.value,   NumberText(self.fight.totalHeal))
    SetTextIfChanged(metricCache, "takenText",  rows.taken.value,  NumberText(self.fight.totalTaken))
    SetTextIfChanged(metricCache, "critText",   rows.crit.value,   string.format("%.1f%%", critPct))

    SetBarRangeIfChanged(metricCache, "dpsRange",    rows.dps.bar,    0, rateMax)
    SetBarRangeIfChanged(metricCache, "hpsRange",    rows.hps.bar,    0, rateMax)
    SetBarRangeIfChanged(metricCache, "damageRange", rows.damage.bar, 0, totalMax)
    SetBarRangeIfChanged(metricCache, "healRange",   rows.heal.bar,   0, totalMax)
    SetBarRangeIfChanged(metricCache, "takenRange",  rows.taken.bar,  0, totalMax)
    SetBarRangeIfChanged(metricCache, "critRange",   rows.crit.bar,   0, 100)

    SetBarValueIfChanged(metricCache, "dpsValue",    rows.dps.bar,    dps, 0.05)
    SetBarValueIfChanged(metricCache, "hpsValue",    rows.hps.bar,    hps, 0.05)
    SetBarValueIfChanged(metricCache, "damageValue", rows.damage.bar, self.fight.totalDamage, 1)
    SetBarValueIfChanged(metricCache, "healValue",   rows.heal.bar,   self.fight.totalHeal, 1)
    SetBarValueIfChanged(metricCache, "takenValue",  rows.taken.bar,  self.fight.totalTaken, 1)
    SetBarValueIfChanged(metricCache, "critValue",   rows.crit.bar,   critPct, 0.05)

    self:UpdateTopSkills()
    self:UpdateTopHealing()
end

function ConsoleMetrics:UpdateTopHealing()
    if not self.ui.healLabels or not self.fight then
        return
    end

    local healList = self.fight.topHealingMoments or {}

    for i, label in ipairs(self.ui.healLabels) do
        local moment = healList[i]
        if moment then
            local nextText = string.format("%d. %s", i, moment.label)
            if label._cmLastText ~= nextText then
                label:SetText(nextText)
                label._cmLastText = nextText
            end
            label:SetHidden(false)
        else
            local emptyText = string.format("%d. -", i)
            if label._cmLastText ~= emptyText then
                label:SetText(emptyText)
                label._cmLastText = emptyText
            end
            label:SetHidden(false)
        end
    end
end

