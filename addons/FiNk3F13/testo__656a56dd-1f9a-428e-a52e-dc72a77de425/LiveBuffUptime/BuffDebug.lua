local Debug = { active = false }
LiveBuffUptimeBuffDebug = Debug
local state
local function advance(now)
    if not state then return end
    now = math.max(state.lastTime, now)
    while state.lastTime < now do
        local boundary, active = now, false
        for slot, effect in pairs(state.slots) do
            if effect.ends and effect.ends <= state.lastTime then
                state.slots[slot] = nil
            else
                active = true
                if effect.ends then boundary = math.min(boundary, effect.ends) end
            end
        end
        if active then
            state.covered = state.covered + boundary - state.lastTime
            local last = state.intervals[#state.intervals]
            if last and last[2] == state.lastTime then last[2] = boundary
            else state.intervals[#state.intervals + 1] = { state.lastTime, boundary } end
        end
        state.lastTime = boundary
    end
    for slot, effect in pairs(state.slots) do
        if effect.ends and effect.ends <= now then state.slots[slot] = nil end
    end
end
local function emit(text)
    state.total = state.total + 1
    if #state.lines == 100 then table.remove(state.lines, 1) end
    state.lines[#state.lines + 1] = text
    if state.quiet then return end
    if state.total <= 120 then
        d("LBU Buff-Debug: " .. text)
    elseif state.total == 121 then
        d("LBU Buff-Debug: Live-Ausgabe begrenzt. Zaehler laufen weiter; /lbu buffdebug report.")
    end
end

function Debug.Start(id, matches, isPlayer, quiet, groupProvider)
    state = { id = id, matches = matches, isPlayer = isPlayer, started = GetFrameTimeSeconds(),
        lines = {}, total = 0, gained = 0, refreshed = 0, faded = 0, applied = 0, ended = 0, rejected = 0,
        quiet = quiet, slots = {}, covered = 0, lastTime = GetFrameTimeSeconds(), snapshots = 0,
        groupProvider = groupProvider, groupCounts = {}, intervals = {}, phase = "waiting" }
    Debug.active = true
    d("LBU Buff-Debug: zeichnet ID " .. id .. (groupProvider and " fuer die Gruppe" or " auf dir")
        .. " auf. Wartet auf Kampf; automatischer Reset je Kampfbeginn. Abfragen: /lbu buffdebug "
        .. (groupProvider and "group " or "") .. id)
end

function Debug.BeginFight(time)
    if not Debug.active or not state then return end
    local previous = state
    local now = time or GetFrameTimeSeconds()
    state = { id = previous.id, matches = previous.matches, isPlayer = previous.isPlayer,
        quiet = previous.quiet, groupProvider = previous.groupProvider, started = now, lastTime = now,
        lines = {}, total = 0, gained = 0, refreshed = 0, faded = 0, applied = 0, ended = 0, rejected = 0,
        slots = {}, covered = 0, snapshots = 0, groupCounts = {}, intervals = {}, phase = "running" }
end

function Debug.EndFight(time)
    if not Debug.active or not state or state.phase ~= "running" then return end
    state.stopped = math.max(state.started, time or GetFrameTimeSeconds())
    advance(state.stopped)
    state.covered = 0
    for _, interval in ipairs(state.intervals) do
        state.covered = state.covered + math.max(0, math.min(interval[2], state.stopped) - interval[1])
    end
    if state.groupProvider then state.groupFrozen = state.groupProvider() end
    state.phase = "finished"
end

function Debug.IsRecording(id, group) return Debug.active and state and state.id == id and (state.groupProvider ~= nil) == (group == true) end
function Debug.IsGroup() return Debug.active and state and state.groupProvider ~= nil end

function Debug.Raw(ability, change, slot, starts, ends, unitId, combat, trackerCount, memberKey, name)
    if not Debug.active or state.phase ~= "running" or not state.matches(ability) then return end
    local action = "andere Meldung"
    if change == EFFECT_RESULT_GAINED then action = "erhalten"; state.gained = state.gained + 1
    elseif change == EFFECT_RESULT_UPDATED then action = "erneuert"; state.refreshed = state.refreshed + 1
    elseif change == EFFECT_RESULT_FADED then action = "beendet"; state.faded = state.faded + 1 end
    local now = GetFrameTimeSeconds()
    if state.groupProvider then
        local key = memberKey or tostring(unitId)
        local counts = state.groupCounts[key] or { gained = 0, refreshed = 0, faded = 0 }
        state.groupCounts[key] = counts
        if change == EFFECT_RESULT_GAINED then counts.gained = counts.gained + 1
        elseif change == EFFECT_RESULT_UPDATED then counts.refreshed = counts.refreshed + 1
        elseif change == EFFECT_RESULT_FADED then counts.faded = counts.faded + 1 end
        emit(string.format("ESO +%.2fs: %s | %s | ID %d | Slot %s", now - state.started,
            name or key, action, ability, tostring(slot)))
        return
    end
    advance(now)
    local key = slot or ("ability:" .. ability)
    if change == EFFECT_RESULT_FADED then state.slots[key] = nil
    elseif change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
        state.slots[key] = (not ends or ends <= 0 or ends > now) and { ends = ends and ends > 0 and ends or nil } or nil
    end
    local remaining = ends and ends > 0 and string.format("%.2fs", math.max(0, ends - now)) or "ohne Ablaufzeit"
    emit(string.format("ESO +%.2fs: %s | ID %d | Slot %s | Einheit %s | Rest %s | Kampf %s | passende Tracker %d",
        now - state.started, action, ability, tostring(slot), tostring(unitId), remaining, combat and "ja" or "nein", trackerCount))
end

function Debug.Processed(fight, tracker, time, unitId, ability, slot, active, reason)
    if not Debug.active or state.phase ~= "running" or not state.matches(ability) or not state.isPlayer(fight, unitId) then return end
    if state.groupProvider and (not tracker.config or tracker.config.unit ~= "group") then return end
    if reason then state.rejected = state.rejected + 1
    elseif active then state.applied = state.applied + 1
    else state.ended = state.ended + 1 end
    emit(string.format("Addon +%.2fs: %s | ID %d | Slot %s | Tracker %s (%s)",
        time - state.started, reason or (active and "aktiv verarbeitet" or "Ende verarbeitet"), ability,
        tostring(slot), tostring(tracker.config and tracker.config.key or "?"),
        tracker.config and tracker.config.unit or "?"))
end

function Debug.Snapshot(ability, ends, slot)
    if Debug.active and state.matches(ability) then
        local now = GetFrameTimeSeconds()
        advance(now)
        if state.phase == "running" and (not ends or ends <= 0 or ends > now) then
            state.slots[slot or ("ability:" .. ability)] = { ends = ends and ends > 0 and ends or nil }
            state.snapshots = state.snapshots + 1
        end
        emit(string.format("Start-Snapshot: ID %d aktuell auf dir | Rest %s", ability,
            ends and ends > 0 and string.format("%.2fs", math.max(0, ends - GetFrameTimeSeconds())) or "ohne Ablaufzeit"))
    end
end

local function groupReport()
    local report, reason = state.groupFrozen
    if not report and state.groupProvider then report, reason = state.groupProvider() end
    if not report then d("LBU Gruppen-Debug: " .. (reason or "Noch keine Kampfwerte vorhanden.")); return end
    local covered, duration = 0, 0
    d(string.format("LBU Gruppen-Debug ID %d: %d Mitglieder | %s | ESO-Zaehler dieses Kampfs", state.id, #report.members,
        state.phase == "finished" and "Kampf abgeschlossen" or "Kampf laeuft"))
    for _, member in ipairs(report.members) do
        local counts = state.groupCounts[member.key] or { gained = 0, refreshed = 0, faded = 0 }
        covered, duration = covered + member.covered, duration + member.duration
        d(string.format("%s: Buff %.2fs / Lebendzeit %.2fs = %.2f%% | ESO erhalten %d / erneuert %d / beendet %d",
            member.name, member.covered, member.duration, member.duration > 0 and member.covered / member.duration * 100 or 0,
            counts.gained, counts.refreshed, counts.faded))
    end
    local percent = duration > 0 and covered / duration * 100 or 0
    d(string.format("SUMME: %.2fs / %.2fs = %.4f%% | HUD %.4f%% | Differenz %.6f Prozentpunkte",
        covered, duration, percent, report.hud, math.abs(percent - report.hud)))
    if state.started > report.starts then d("Hinweis: Debug nach Kampfbeginn gestartet; ESO-Zaehler enthalten nicht den ganzen Kampf.") end
    d("Zeitunion aus erfassten Intervallen separat nachgerechnet; gleiche Eingangsdaten, kein Beweis vollstaendiger ESO-Meldungen.")
    d("Erhalten/erneuert/beendet zaehlen ESO-Meldungen, keine Skill-Casts. Naechster Kampfbeginn setzt automatisch zurueck.")
end

function Debug.Report(compact)
    if not state then d("LBU Buff-Debug: Zuerst /lbu buffdebug start ID ausfuehren."); return end
    if state.phase == "waiting" then d("LBU Buff-Debug: eingeschaltet; wartet auf den naechsten Kampfbeginn."); return end
    if state.groupProvider then groupReport(); return end
    if state.phase == "running" then advance(state.stopped or GetFrameTimeSeconds()) end
    d(string.format("LBU Buff-Debug ID %d: Buffzeit %.2fs seit Messbeginn | erhalten %d / erneuert %d | jetzt %s | beim Start aktive Slots %d",
        state.id, state.covered, state.gained, state.refreshed, next(state.slots) and "aktiv" or "inaktiv", state.snapshots))
    if compact then
        d(string.format("ESO beendet %d | Addon aktiv %d / Ende %d / abgewiesen %d | Aufzeichnung %s. Buffzeit aus ESO-Meldungen, Ueberlappungen nur einmal.",
            state.faded, state.applied, state.ended, state.rejected,
            Debug.active and (state.phase == "finished" and "Kampf abgeschlossen; naechster Kampf setzt zurueck" or "Kampf laeuft") or "gestoppt"))
        return
    end
    d(string.format("LBU Buff-Debug ID %d: %s | ESO erhalten %d / erneuert %d / beendet %d | Addon aktiv %d / Ende %d / abgewiesen %d",
        state.id, Debug.active and "laeuft" or "gestoppt", state.gained, state.refreshed, state.faded,
        state.applied, state.ended, state.rejected))
    for index = math.max(1, #state.lines - 11), #state.lines do d(state.lines[index]) end
    d("ESO- und Addon-Zaehler sind nicht 1:1: Bibliotheksmeldungen, Snapshots, mehrere Tracker und automatische Ablaufzeiten. Fehlende ESO-Meldungen sind damit nicht beweisbar.")
end

function Debug.Stop()
    if state and Debug.active and state.phase == "running" then
        if state.groupProvider then state.groupFrozen = state.groupProvider() end
        state.stopped = GetFrameTimeSeconds()
        advance(state.stopped)
    end
    Debug.active = false
    Debug.Report(state and state.quiet)
end
