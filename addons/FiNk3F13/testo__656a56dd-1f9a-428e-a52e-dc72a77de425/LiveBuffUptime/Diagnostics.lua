LiveBuffUptimeDiagnostics = {}
local Audit = LiveBuffUptimeDiagnostics
local MAX_JOBS, MAX_OPERATIONS, SLICE = 12, 16384, 128
local MAX_UNKNOWN = 24

function Audit.RecordUnknown(fight, time, ability, recipient, change, kind)
    local data = fight and fight.diagnostics
    if not data then return end
    data.unknownSourceEvents = (data.unknownSourceEvents or 0) + 1
    data.unknownEffects = data.unknownEffects or {}
    fight.unknownEffectIndex = fight.unknownEffectIndex or {}
    local key = tostring(ability) .. ":" .. tostring(recipient)
    local entry = fight.unknownEffectIndex[key]
    if not entry then
        if #data.unknownEffects >= MAX_UNKNOWN then
            data.unknownDetailsDropped = (data.unknownDetailsDropped or 0) + 1
            return
        end
        entry = { id = ability, recipient = recipient, kind = kind, first = time, last = time,
            count = 0, gained = 0, updated = 0, faded = 0 }
        data.unknownEffects[#data.unknownEffects + 1] = entry
        fight.unknownEffectIndex[key] = entry
    end
    entry.count = entry.count + 1
    entry.first, entry.last = math.min(entry.first, time), math.max(entry.last, time)
    entry.kind = kind or entry.kind
    local field = change == EFFECT_RESULT_GAINED and "gained" or change == EFFECT_RESULT_UPDATED and "updated" or "faded"
    entry[field] = entry[field] + 1
end

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function inspect(job)
    local operations, slice, warnings = 0, 0, {}
    local function warn(message)
        if #warnings < 4 then warnings[#warnings + 1] = message end
    end
    if job.truncated then warn("Mitglieder-Prueflimit erreicht; Ergebnis unvollstaendig") end
    if job.incomplete then warn("Diagnose nicht ab Messbeginn aktiv") end
    local function charge()
        operations, slice = operations + 1, slice + 1
        if operations > MAX_OPERATIONS then error("Prueflimit erreicht; Ergebnis unvollstaendig", 0) end
        if slice >= SLICE then slice = 0; coroutine.yield() end
    end
    if not finite(job.starts) or not finite(job.ends) or job.ends < job.starts then
        return "WARN: ungueltiges Kampfzeitfenster"
    end
    local function sum(intervals, starts, ends)
        starts, ends = starts or job.starts, ends or job.ends
        local total, full, previousEnd, clipped = 0, 0, nil, {}
        for _, interval in ipairs(intervals or {}) do
            charge()
            local first, last = interval[1], interval[2]
            if not finite(first) or not finite(last) or last < first then
                warn("ungueltiger Zeitabschnitt")
            else
                if previousEnd and first < previousEnd then warn("ueberlappende Zeitabschnitte") end
                previousEnd = last
                full = full + last - first
                if interval[3] and (not finite(interval[3]) or math.abs(interval[3] - full) > 0.001) then
                    warn("abweichende Zwischensumme")
                end
                first, last = math.max(starts, first), math.min(ends, last)
                if last > first then
                    total = total + last - first
                    clipped[#clipped + 1] = { first, last }
                end
            end
        end
        return total, clipped
    end
    local function member(data)
        local starts, ends = data.starts or job.starts, data.ends or job.ends
        if job.selection and data.placeholder then warn("Spieler nicht beobachtet; keine Einheitentyp-Pruefung") end
        if job.selection and not data.placeholder then
            if not finite(starts) or not finite(ends) or ends < starts then
                warn("ungueltige Einheitenzeit")
                starts, ends = job.starts, job.starts
            elseif starts < job.starts - 0.001 or ends > job.ends + 0.001 then
                warn("Einheitenzeit ausserhalb Kampf")
            end
            if LiveBuffUptimeEngine and LiveBuffUptimeEngine.IsPet(data.kind) then warn("Begleiter mitgezaehlt") end
            if job.selection == "group" and data.kind ~= COMBAT_UNIT_TYPE_PLAYER and data.kind ~= COMBAT_UNIT_TYPE_GROUP then
                warn("Nicht-Spieler in Gruppenmessung")
            elseif data.kind == nil then warn("Einheitentyp unbekannt") end
        end
        local covered, active = sum(data.intervals, starts, ends)
        if data.open then
            if not finite(data.open) then warn("ungueltiger offener Buff") else
                local first = math.max(starts, data.open)
                if ends > first then
                    covered = covered + ends - first
                    active[#active + 1] = { first, ends }
                end
            end
        end
        if data.weighted then
            covered = 0
            for _, instance in pairs(data.weighted) do
                charge()
                local weighted = data.source == "own" and instance.own or instance.all
                local total, prefix = 0, 0
                for _, interval in ipairs(weighted.intervals) do
                    charge()
                    if not finite(interval[4]) or interval[4] < 0 then warn("ungueltiger Stapelwert") else
                        prefix = prefix + (interval[2] - interval[1]) * interval[4]
                        if math.abs(interval[3] - prefix) > 0.001 then warn("abweichende Stapel-Zwischensumme") end
                        total = total + math.max(0, math.min(ends, interval[2]) - math.max(starts, interval[1])) * interval[4]
                    end
                end
                if weighted.starts then total = total + math.max(0, ends - math.max(starts, weighted.starts)) * weighted.weight end
                if instance.maxStacks > 0 then covered = covered + total / instance.maxStacks end
            end
        end
        local duration = data.duration or (data.eligibility and sum(data.eligibility, starts, ends) or job.duration)
        local excluded = 0
        if data.excluded then
            local blocked, intervals = sum(data.excluded, starts, ends)
            local overlap, a, b = 0, 1, 1
            while active[a] and intervals[b] do
                charge()
                local effect, cooldown = active[a], intervals[b]
                overlap = overlap + math.max(0, math.min(effect[2], cooldown[2]) - math.max(effect[1], cooldown[1]))
                if effect[2] <= cooldown[2] then a = a + 1 else b = b + 1 end
            end
            excluded = blocked - overlap
        end
        if not finite(duration) or duration < 0 then warn("ungueltige Kampfzeit"); duration = 0 end
        if not job.weighted and covered > duration + 0.001 then warn("Buffzeit groesser als Kampfzeit") end
        if data.normalCovered and data.normalCovered > duration + 0.001 then warn("Normale Buffzeit groesser als Bezugszeit") end
        if excluded < -0.001 or excluded > duration + 0.001 then warn("ungueltiger Zeitabzug") end
        return covered, duration, excluded
    end
    local covered, duration, excluded = 0, 0, 0
    for _, data in ipairs(job.members) do
        charge()
        local active, eligible, blocked = member(data)
        covered, duration, excluded = covered + active, duration + eligible, excluded + blocked
    end
    local denominator = job.group and math.max(0, duration - excluded) or math.max(1, duration - excluded)
    local percent = denominator > 0 and covered / denominator * 100 or 0
    local comparedPercent = job.weighted and math.max(0, percent) or math.min(100, math.max(0, percent))
    if not finite(job.percent) or math.abs(comparedPercent - job.percent) > 0.11 then
        warn("Anzeige und Nachrechnung weichen ab")
    end
    return string.format("%s %.1f%% (Buff %.2fs / Zeit %.2fs / Abzug %.2fs)%s",
        #warnings == 0 and "OK intern" or "WARN", percent, covered, duration, excluded,
        #warnings > 0 and " | " .. table.concat(warnings, "; ") or "")
end

local freezeFields = { "unit", "view", "personalTime", "uptimeMetric", "includeOverheal", "enabled" }

function Audit.Freeze(tracker, fight, record, now, playerId, targetId)
    local config = {}
    for _, field in ipairs(freezeFields) do config[field] = tracker.config[field] end
    record.freeze = { status = "wartet", checks = 0, violations = 0 }
    tracker.freezeCheck = { fight = fight, record = record, config = config, nextAt = now + 1,
        since = tracker.state.since, playerId = playerId, targetId = targetId,
        starts = fight.starts, ends = fight.ends }
end

function Audit.CheckFrozen(audit, tracker, fight, result, now, playerId, targetId)
    local check = tracker.freezeCheck
    if not audit.enabled or not check or check.fight ~= fight or now < check.nextAt then return end
    check.nextAt = now + 1
    local changed = check.since ~= tracker.state.since or check.playerId ~= playerId
        or (tracker.config.unit == "reticleover" and check.targetId ~= targetId)
    for _, field in ipairs(freezeFields) do changed = changed or check.config[field] ~= tracker.config[field] end
    if changed then
        check.record.freeze.status = "beendet: Auswahl geaendert"
        tracker.freezeCheck = nil
        return
    end
    local state, record = check.record.freeze, check.record
    state.checks = state.checks + 1
    if fight.running or fight.starts ~= check.starts or fight.ends ~= check.ends
        or not finite(result.covered) or not finite(result.duration) or not finite(result.percent)
        or math.abs(result.covered - record.covered) > 0.001
        or math.abs(result.duration - record.duration) > 0.001 or math.abs(result.percent - record.percent) > 0.001 then
        state.violations = state.violations + 1
        state.status = "WARN: Endwerte veraendert"
        if state.violations == 1 then
            pcall(audit.output, "LiveBuffUptime Check: WARN Endwerte nach Kampfabschluss veraendert (ID " .. record.id .. ").")
        end
    elseif state.violations == 0 then state.status = "OK unveraendert" end
end

function Audit.New(output)
    return { enabled = false, jobs = {}, last = {}, output = output, samples = 0, totalMS = 0, maxMS = 0, slow = 0, dropped = 0 }
end

function Audit.SetEnabled(audit, enabled)
    audit.enabled = enabled and true or false
    audit.jobs, audit.last = {}, {}
    audit.samples, audit.totalMS, audit.maxMS, audit.slow, audit.dropped = 0, 0, 0, 0, 0
end

function Audit.Queue(audit, job)
    if not audit.enabled then return end
    if #audit.jobs >= MAX_JOBS then audit.dropped = audit.dropped + 1; return end
    audit.jobs[#audit.jobs + 1] = { label = job.label, worker = coroutine.create(function() return inspect(job) end) }
end

function Audit.RecordTime(audit, elapsed)
    if not audit.enabled or not finite(elapsed) or elapsed < 0 then return end
    audit.samples = audit.samples + 1
    audit.totalMS = audit.totalMS + elapsed
    audit.maxMS = math.max(audit.maxMS, elapsed)
    if elapsed >= 5 then audit.slow = audit.slow + 1 end
end

local function emit(audit, line)
    -- A broken chat/output hook must not affect the combat addon.
    pcall(audit.output, "LiveBuffUptime Check: " .. line)
end

function Audit.Tick(audit)
    if not audit.enabled or not audit.jobs[1] then return end
    local job = audit.jobs[1]
    local ok, result = coroutine.resume(job.worker)
    if not ok or coroutine.status(job.worker) == "dead" then
        table.remove(audit.jobs, 1)
        local line = tostring(job.label or "Tracker") .. ": " .. (ok and tostring(result) or "WARN: " .. tostring(result))
        if #audit.last >= MAX_JOBS then table.remove(audit.last, 1) end
        audit.last[#audit.last + 1] = line
        if audit.persist then pcall(audit.persist, audit) end
        emit(audit, line)
        if #audit.jobs == 0 then
            emit(audit, string.format("UI-Rechenzeit max %.2fms / Mittel %.2fms (%d Messungen, %d ab 5ms); %d Pruefungen ausgelassen. OK prueft nur interne Konsistenz.",
                audit.maxMS, audit.samples > 0 and audit.totalMS / audit.samples or 0, audit.samples, audit.slow, audit.dropped))
        end
    end
end

function Audit.Restore(audit, saved, persist)
    audit.persist = persist
    if type(saved) ~= "table" then return end
    for _, line in ipairs(saved.last or {}) do
        if type(line) == "string" and #audit.last < MAX_JOBS then audit.last[#audit.last + 1] = line end
    end
    for _, key in ipairs({ "samples", "totalMS", "maxMS", "slow", "dropped" }) do
        if finite(saved[key]) and saved[key] >= 0 then audit[key] = saved[key] end
    end
end

function Audit.ShowLast(audit)
    if #audit.jobs > 0 then emit(audit, tostring(#audit.jobs) .. " Pruefungen werden noch bearbeitet.") end
    if #audit.last == 0 then emit(audit, "Noch kein Ergebnis; Pruefung aktivieren und einen Kampf abschliessen.") end
    for _, line in ipairs(audit.last) do emit(audit, line) end
end
