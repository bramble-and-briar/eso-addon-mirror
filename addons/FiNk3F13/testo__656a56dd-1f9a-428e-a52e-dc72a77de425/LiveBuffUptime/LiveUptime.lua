LiveBuffUptimeEngine = {}
local LiveUptime = LiveBuffUptimeEngine
local Meter = LiveBuffUptimeMeter
local Stacks = LiveBuffUptimeStacks

function LiveUptime.IsPet(kind)
    return kind ~= nil and ((COMBAT_UNIT_TYPE_PLAYER_PET ~= nil and kind == COMBAT_UNIT_TYPE_PLAYER_PET)
        or (COMBAT_UNIT_TYPE_GROUP_PET ~= nil and kind == COMBAT_UNIT_TYPE_GROUP_PET)
        or (COMBAT_UNIT_TYPE_PLAYER_COMPANION ~= nil and kind == COMBAT_UNIT_TYPE_PLAYER_COMPANION)
        or (COMBAT_UNIT_TYPE_GROUP_COMPANION ~= nil and kind == COMBAT_UNIT_TYPE_GROUP_COMPANION))
end

function LiveUptime.TypeName(kind)
    if LiveUptime.IsPet(kind) then return "Begleiter" end
    if kind ~= nil and kind == COMBAT_UNIT_TYPE_PLAYER then return "Spieler" end
    if kind ~= nil and kind == COMBAT_UNIT_TYPE_GROUP then return "Gruppenmitglied" end
    return kind == nil and "Unbekannt" or "Andere Einheit"
end

function LiveUptime.Note(fight, key)
    local data = fight and fight.diagnostics
    if data then data[key] = (data[key] or 0) + 1 end
end

function LiveUptime.New(now)
    return { combatstart = now, units = {}, allies = {}, kinds = {}, running = true,
        encounterEnds = now, aliveIntervals = {}, aliveSince = now }
end

function LiveUptime.EncounterDamage(fight, time)
    if fight and fight.running and time >= fight.combatstart then
        fight.encounterEnds = math.max(fight.encounterEnds, time)
    end
end

function LiveUptime.PlayerAlive(fight, time, alive)
    if not fight or not fight.running then return false end
    time = math.max(fight.combatstart, time)
    if alive == (fight.aliveSince ~= nil) then return false end
    if alive then fight.aliveSince = time
    else
        fight.aliveIntervals[#fight.aliveIntervals + 1] = { fight.aliveSince, time }
        fight.aliveSince = nil
    end
    return true
end

function LiveUptime.PersonalBasis(fight, config)
    if config.personalTime == "unit" then return "unit" end
    return (config.personalTime ~= "auto" and config.personalTime) or (fight and fight.personalBasis) or "combat"
end

local function aliveDuration(fight, starts, ends)
    local total = 0
    for _, interval in ipairs(fight.aliveIntervals) do
        total = total + math.max(0, math.min(ends, interval[2]) - math.max(starts, interval[1]))
    end
    if fight.aliveSince then total = total + math.max(0, ends - math.max(starts, fight.aliveSince)) end
    return total
end

local function aliveWindows(fight, starts, ends)
    local windows = {}
    local function add(first, last)
        first, last = math.max(starts, first), math.min(ends, last)
        if last > first then windows[#windows + 1] = { first, last } end
    end
    for _, interval in ipairs(fight.aliveIntervals) do add(interval[1], interval[2]) end
    if fight.aliveSince then add(fight.aliveSince, ends) end
    return windows
end

function LiveUptime.GroupMember(fight, key, id, time, eligible, name)
    if not fight or not fight.running then return end
    fight.groupMembers = fight.groupMembers or {}
    local member = fight.groupMembers[key]
    if not member then
        member = { id = id, name = name, starts = time, ends = time, aliveIntervals = {} }
        fight.groupMembers[key] = member
    end
    member.id, member.name, member.ends = id or member.id, name or member.name, time
    if eligible ~= (member.aliveSince ~= nil) then
        if eligible then member.aliveSince = time
        else
            member.aliveIntervals[#member.aliveIntervals + 1] = { member.aliveSince, time }
            member.aliveSince = nil
        end
    end
    return member
end

-- A roster snapshot may precede the first authoritative unit-ID event.
function LiveUptime.MergeUnits(snapshot, events)
    if not snapshot then return events end
    if not events then return snapshot end
    local merged = { all = Meter.NewScope(), own = Meter.NewScope(), slots = {} }
    for _, source in ipairs({ snapshot, events }) do
        for _, scope in ipairs({ "all", "own" }) do
            for _, event in ipairs(source[scope].events) do
                Meter.ScopeEvent(merged[scope], event.slot, event.time, event.active)
            end
        end
        for ability, instance in pairs(source.stackInstances or {}) do
            for _, event in ipairs(instance.events) do
                Stacks.Event(merged, ability, event.slot, event.time, event.gained, event.own, event.stacks)
            end
        end
    end
    for slot in pairs(merged.all.slots) do merged.slots[slot] = events.slots[slot] or snapshot.slots[slot] end
    return merged
end

function LiveUptime.Kind(fight, id, kind)
    if not fight.running then LiveUptime.Note(fight, "blockedMutations"); return end
    if not id or not kind then return end
    fight.kinds[id] = kind
    local unit = fight.units[id]
    if unit then
        unit.kind = kind
        fight.allies[id] = (kind == COMBAT_UNIT_TYPE_PLAYER or kind == COMBAT_UNIT_TYPE_GROUP) and unit or nil
    end
end

function LiveUptime.Touch(fight, id, time, kind)
    if not fight.running then LiveUptime.Note(fight, "blockedMutations"); return end
    if not id or time < fight.combatstart - 0.5 then return end
    local unit = fight.units[id]
    if not unit then
        unit = { starts = time, ends = time }
        fight.units[id] = unit
    end
    unit.starts = math.min(unit.starts, time)
    unit.ends = math.max(unit.ends, time)
    unit.kind = kind or fight.kinds[id] or unit.kind
    LiveUptime.Kind(fight, id, unit.kind)
    return unit
end

function LiveUptime.Action(fight, event, time, source, target, value, overflow)
    if not fight.running then LiveUptime.Note(fight, "blockedMutations"); return end
    if string.find(event, "DAMAGE", 1, true) then LiveUptime.EncounterDamage(fight, time) end
    local outgoing = event == "EVENT_DAMAGE_OUT" or event == "EVENT_HEAL_OUT"
    if outgoing or event == "EVENT_HEAL_SELF" then
        fight.starts = math.min(fight.starts or time, time)
        fight.ends = math.max(fight.ends or time, time)
    end
    -- Outgoing events measure the recipient; incoming events measure the source.
    local function activity(id, category)
        local unit = LiveUptime.Touch(fight, id, time)
        if unit then
            unit.values = unit.values or {}
            local amount = math.max(0, value or 0)
            if category == "damageOut" or category == "damageIn" then amount = amount + math.max(0, overflow or 0) end
            unit.values[category] = (unit.values[category] or 0) + amount
            if category == "healingOut" then unit.overheal = (unit.overheal or 0) + math.max(0, overflow or 0) end
        end
    end
    local category = event == "EVENT_DAMAGE_OUT" and "damageOut"
        or (event == "EVENT_DAMAGE_IN" or event == "EVENT_DAMAGE_SELF") and "damageIn"
        or event == "EVENT_HEAL_OUT" and "healingOut" or "healingIn"
    activity(outgoing and target or source, category)
    if event == "EVENT_HEAL_SELF" then activity(target, "healingOut") end
end

function LiveUptime.Effect(fight, tracker, time, id, ability, slot, gained, own, stacks, sourceType, expires)
    local debug = LiveBuffUptimeBuffDebug
    local reason = LiveUptime.IsPet(sourceType) and "abgewiesen: Begleiterquelle" or nil
    local recipient = LiveUptime.Touch(fight, id, time)
    if not recipient then
        if debug and debug.active then debug.Processed(fight, tracker, time, id, ability, slot, false, "abgewiesen: Kampf geschlossen/keine Einheit") end
        return
    end
    recipient.hasEffects = true
    -- A rejected replacement must close an earlier eligible application in this slot.
    if LiveUptime.IsPet(sourceType) then gained, stacks = false, nil end
    tracker.liveUptimeUnits = tracker.liveUptimeUnits or {}
    local unit = tracker.liveUptimeUnits[id]
    if not unit then
        unit = { all = Meter.NewScope(), own = Meter.NewScope(), slots = {} }
        tracker.liveUptimeUnits[id] = unit
    end
    if Stacks then Stacks.Event(unit, ability, slot, time, gained, own, stacks) end
    -- Effect slots, not source IDs or ability aliases, identify simultaneous applications.
    local previous = unit.slots[slot]
    if previous and previous.expires and previous.expires <= time then
        Meter.ScopeEvent(unit.all, slot, previous.expires, false)
        Meter.ScopeEvent(unit.own, slot, previous.expires, false)
        if Stacks then Stacks.Event(unit, previous.ability, slot, previous.expires, false, previous.own) end
        unit.slots[slot], previous = nil, nil
    end
    if gained and expires and expires > 0 and expires <= time then
        gained, reason = false, "abgewiesen: bereits abgelaufen"
    end
    if gained then
        if previous and previous.ability ~= ability then
            Meter.ScopeEvent(unit.all, slot, time, false)
            Meter.ScopeEvent(unit.own, slot, time, false)
            previous = nil
        end
        unit.slots[slot] = previous or { ability = ability, own = own }
        if expires ~= nil then unit.slots[slot].expires = expires > 0 and expires or nil end
        local remembered = recipient.effects and recipient.effects[slot]
        if tracker.config and tracker.config.unit == "group" and expires ~= nil and remembered and remembered.ability == ability then
            remembered.groupExpires = expires > 0 and expires or nil
        end
        Meter.ScopeEvent(unit.all, slot, time, true)
        if unit.slots[slot].own then Meter.ScopeEvent(unit.own, slot, time, true) end
    else
        unit.slots[slot] = nil
        Meter.ScopeEvent(unit.all, slot, time, false)
        Meter.ScopeEvent(unit.own, slot, time, false)
    end
    if debug and debug.active then debug.Processed(fight, tracker, time, id, ability, slot, gained, reason) end
end

function LiveUptime.Expire(fight, tracker, time)
    if not fight or not fight.running or (tracker.config.unit ~= "group" and tracker.config.unit ~= "reticleover") then return end
    for id, unit in pairs(tracker.liveUptimeUnits or {}) do
        local expired
        for slot, effect in pairs(unit.slots) do
            if effect.expires and effect.expires <= time then
                expired = expired or {}
                expired[#expired + 1] = { slot = slot, ability = effect.ability, time = effect.expires }
            end
        end
        if expired then
            for _, effect in ipairs(expired) do
                LiveUptime.Effect(fight, tracker, effect.time, id, effect.ability, effect.slot, false, false, 1)
            end
        end
    end
end

function LiveUptime.Remember(unit, ability, slot, gained, own, stacks, sourceType)
    unit.hasEffects = true
    unit.effects = unit.effects or {}
    if gained and not LiveUptime.IsPet(sourceType) then
        unit.effects[slot] = unit.effects[slot] or { ability = ability, own = own }
        if unit.effects[slot].ability ~= ability then unit.effects[slot] = { ability = ability, own = own } end
        unit.effects[slot].stacks = stacks
    else
        unit.effects[slot] = nil
    end
end

function LiveUptime.Seed(fight, tracker, now, matches)
    if tracker.freezeCheck and tracker.freezeCheck.record.freeze.violations == 0 then
        tracker.freezeCheck.record.freeze.status = "beendet: Tracker geaendert"
    end
    tracker.freezeCheck = nil
    tracker.liveUptimeUnits = {}
    if not fight or not fight.running then return end
    for id, unit in pairs(fight.units) do
        for slot, effect in pairs(unit.effects or {}) do
            if matches(tracker.config, effect.ability)
                and not (tracker.config.unit == "group" and effect.groupExpires and effect.groupExpires <= now) then
                local data = tracker.liveUptimeUnits[id]
                if not data then
                    data = { all = Meter.NewScope(), own = Meter.NewScope(), slots = {} }
                    tracker.liveUptimeUnits[id] = data
                end
                data.slots[slot] = { ability = effect.ability, own = effect.own,
                    expires = tracker.config.unit == "group" and effect.groupExpires or nil }
                Meter.ScopeEvent(data.all, slot, now, true)
                if effect.own then Meter.ScopeEvent(data.own, slot, now, true) end
                if Stacks then Stacks.Event(data, effect.ability, slot, now, true, effect.own, effect.stacks) end
            end
        end
    end
end

function LiveUptime.Finish(fight, summary, convert)
    if not fight.running then LiveUptime.Note(fight, "blockedMutations"); return end
    if summary.starttime and summary.endtime and summary.starttime > 0 and summary.endtime > 0 then
        fight.starts, fight.ends = convert(summary.starttime), convert(summary.endtime)
    end
    fight.personalDuration = math.max(summary.activetime or 0, summary.dpstime or 0, summary.hpstime or 0,
        fight.starts and fight.ends and fight.ends - fight.starts or 0, 1)
    for id, unit in pairs(fight.units) do
        if summary.units then unit.offline = summary.units[id] == nil end
    end
    for id, data in pairs(summary.units or {}) do
        local unit = fight.units[id]
        if unit then
            unit.kind = data.unitType or data.unittype or unit.kind
            if LiveUptime.IsPet(unit.kind) then unit.player = false end
            LiveUptime.Kind(fight, id, unit.kind)
            unit.offline = data.name == "Offline"
            unit.name = data.displayname or data.name
        end
    end
    fight.running = false
end

local function selected(config, id, unit, playerId, targetId)
    if unit.offline or LiveUptime.IsPet(unit.kind) then return false end
    local category = config.view or (config.unit == "reticleover" and "damageOut" or "healingOut")
    local friendly = unit.player or unit.kind == COMBAT_UNIT_TYPE_PLAYER
        or unit.kind == COMBAT_UNIT_TYPE_GROUP or unit.kind == COMBAT_UNIT_TYPE_PLAYER_PET
    local damageView = category == "damageOut" or category == "damageIn"
    if damageView == (friendly and true or false) then return false end
    local relevant = unit.values and unit.values[category] or 0
    if category == "healingOut" and config.includeOverheal then relevant = relevant + (unit.overheal or 0) end
    if not unit.hasEffects and relevant <= 0 then return false end
    if config.unit == "player" then return id == playerId or unit.player end
    if config.unit == "reticleover" then return id == targetId end
    return unit.player or unit.kind == COMBAT_UNIT_TYPE_PLAYER
        or unit.kind == COMBAT_UNIT_TYPE_GROUP
end

function LiveUptime.Calculate(fight, tracker, playerId, targetId, report)
    local result = { covered = 0, normalCovered = 0, stackCovered = 0, duration = 0, percent = 0, members = {} }
    if not fight then return result end
    LiveUptime.Expire(fight, tracker, fight.encounterEnds)
    local basis = LiveUptime.PersonalBasis(fight, tracker.config)
    local groupAlive = tracker.config.unit == "group" and fight.groupMembers ~= nil
    local alive = tracker.config.unit == "player" and basis == "alive"
    local fightStarts, fightEnds = (alive or groupAlive) and fight.combatstart or fight.starts,
        (alive or groupAlive) and fight.encounterEnds or fight.ends
    if not fightStarts or not fightEnds then return result end
    result.starts, result.ends, result.personalTime = fightStarts, fightEnds, basis
    local first = math.max(fightStarts, tracker.state.since)
    local personal = tracker.config.unit == "player" and basis ~= "unit"
    if personal then
        result.duration = alive and aliveDuration(fight, first, fightEnds)
            or math.max(1, (fight.personalDuration or (fightEnds - fightStarts))
                - math.max(0, first - fightStarts))
    end
    local units = fight.allies
    if groupAlive then units = fight.groupMembers end
    if tracker.config.unit ~= "group" then
        local id = tracker.config.unit == "player" and playerId or targetId
        units = id and fight.units[id] and { [id] = fight.units[id] } or {}
    end
    for id, unit in pairs(units) do
        local dataId = groupAlive and (unit.id or id) or id
        if (not groupAlive or tracker.config.groupRole ~= "damage" or (LFG_ROLE_DPS ~= nil and unit.role == LFG_ROLE_DPS))
            and (groupAlive or (personal and not unit.offline and not LiveUptime.IsPet(unit.kind))
            or (not personal and selected(tracker.config, id, unit, playerId, targetId))) then
            local starts, ends = math.max(first, unit.starts), math.min(fightEnds, unit.ends)
            if groupAlive then ends = fightEnds end
            if personal then
                starts = first
                -- The personal panel uses the fight clock, not the unit-selection denominator.
                -- Open effects are finalized by CM at the unit's last recorded event.
                ends = (alive or fight.running) and fightEnds or math.min(fightEnds, unit.ends)
            end
            if ends > starts then
                local data = tracker.liveUptimeUnits and tracker.liveUptimeUnits[dataId]
                local scope = data and data.all
                local windows = (alive or groupAlive) and aliveWindows(groupAlive and unit or fight, starts, ends)
                    or { { starts, ends } }
                local memberDuration = groupAlive and aliveDuration(unit, starts, ends) or ends - starts
                local covered, stackCovered = 0, 0
                for _, window in ipairs(windows) do
                    local first, last = window[1], window[2]
                    local total = scope and Meter.IntervalTotal(scope.intervals, first, last) or 0
                    if scope and scope.starts then total = total + math.max(0, last - math.max(first, scope.starts)) end
                    covered = covered + total
                    stackCovered = stackCovered + (Stacks and Stacks.Total(data and data.stackInstances, "all", first, last) or total)
                end
                local normalCovered = covered
                if tracker.config.uptimeMetric == "stacks" then covered = stackCovered end
                result.normalCovered, result.stackCovered = result.normalCovered + normalCovered, result.stackCovered + stackCovered
                result.covered = result.covered + covered
                if not personal then result.duration = result.duration + memberDuration end
                if report and #result.members < 48 then
                    result.members[#result.members + 1] = { id = dataId, name = unit.name,
                        kind = groupAlive and COMBAT_UNIT_TYPE_GROUP or unit.kind, covered = covered,
                        observedStarts = unit.starts, observedEnds = unit.ends, normalCovered = normalCovered,
                        duration = personal and result.duration or memberDuration,
                        starts = starts, ends = ends, intervals = scope and scope.intervals or {},
                        open = scope and scope.starts, eligibility = windows, aliveWindows = (alive or groupAlive) and windows or nil }
                    if tracker.config.uptimeMetric == "stacks" then
                        result.members[#result.members].weighted = data and data.stackInstances or {}
                        result.members[#result.members].source = "all"
                    end
                elseif report then
                    result.truncated = true
                end
            end
        end
    end
    if personal and report and #result.members == 0 then
        result.members[1] = { id = playerId, kind = playerId and fight.units[playerId] and fight.units[playerId].kind,
            placeholder = true, covered = 0, duration = result.duration, intervals = {} }
    end
    if report then
        result.excluded, result.scanned = {}, 0
        local included = {}
        for _, member in ipairs(result.members) do if member.id then included[member.id] = true end end
        -- This bounded inspection is diagnostic only, never part of the denominator.
        for id, unit in pairs(fight.units) do
            if result.scanned >= 256 then result.exclusionsTruncated = true; break end
            result.scanned = result.scanned + 1
            if not included[id] and (LiveUptime.IsPet(unit.kind) or unit.kind == COMBAT_UNIT_TYPE_PLAYER
                or unit.kind == COMBAT_UNIT_TYPE_GROUP or (tracker.liveUptimeUnits and tracker.liveUptimeUnits[id])) then
                if #result.excluded >= 48 then result.exclusionsTruncated = true; break end
                local reason = LiveUptime.IsPet(unit.kind) and "Begleiter ausgeschlossen"
                    or unit.offline and "Offline/fehlt in Zusammenfassung"
                    or not selected(tracker.config, id, unit, playerId, targetId) and "Nicht in Auswahl/keine relevanten Daten"
                    or "Kein positives Zeitfenster"
                result.excluded[#result.excluded + 1] = { id = id, name = unit.name, kind = unit.kind, reason = reason,
                    observedStarts = unit.starts, observedEnds = unit.ends }
            end
        end
    end
    result.percent = result.duration > 0 and math.max(0, result.covered / result.duration * 100) or 0
    if tracker.config.uptimeMetric ~= "stacks" then result.percent = math.min(100, result.percent) end
    return result
end
