LiveBuffUptimeEngine = {}
local LiveUptime = LiveBuffUptimeEngine
local Meter = LiveBuffUptimeMeter
local Stacks = LiveBuffUptimeStacks

function LiveUptime.New(now)
    return { combatstart = now, units = {}, allies = {}, kinds = {}, running = true }
end

function LiveUptime.Kind(fight, id, kind)
    if not id or not kind then return end
    fight.kinds[id] = kind
    local unit = fight.units[id]
    if unit then
        unit.kind = kind
        fight.allies[id] = (kind == COMBAT_UNIT_TYPE_PLAYER or kind == COMBAT_UNIT_TYPE_GROUP
            or kind == COMBAT_UNIT_TYPE_PLAYER_PET) and unit or nil
    end
end

function LiveUptime.Touch(fight, id, time, kind)
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

function LiveUptime.Effect(fight, tracker, time, id, ability, slot, gained, own, stacks)
    local recipient = LiveUptime.Touch(fight, id, time)
    if not recipient then return end
    recipient.hasEffects = true
    tracker.liveUptimeUnits = tracker.liveUptimeUnits or {}
    local unit = tracker.liveUptimeUnits[id]
    if not unit then
        unit = { all = Meter.NewScope(), own = Meter.NewScope(), slots = {} }
        tracker.liveUptimeUnits[id] = unit
    end
    if Stacks then Stacks.Event(unit, ability, slot, time, gained, own, stacks) end
    -- Effect slots, not source IDs or ability aliases, identify simultaneous applications.
    local previous = unit.slots[slot]
    if gained then
        if previous and previous.ability ~= ability then
            Meter.ScopeEvent(unit.all, slot, time, false)
            Meter.ScopeEvent(unit.own, slot, time, false)
            previous = nil
        end
        unit.slots[slot] = previous or { ability = ability, own = own }
        Meter.ScopeEvent(unit.all, slot, time, true)
        if unit.slots[slot].own then Meter.ScopeEvent(unit.own, slot, time, true) end
    else
        unit.slots[slot] = nil
        Meter.ScopeEvent(unit.all, slot, time, false)
        Meter.ScopeEvent(unit.own, slot, time, false)
    end
end

function LiveUptime.Remember(unit, ability, slot, gained, own, stacks)
    unit.hasEffects = true
    unit.effects = unit.effects or {}
    if gained then
        unit.effects[slot] = unit.effects[slot] or { ability = ability, own = own }
        if unit.effects[slot].ability ~= ability then unit.effects[slot] = { ability = ability, own = own } end
        unit.effects[slot].stacks = stacks
    else
        unit.effects[slot] = nil
    end
end

function LiveUptime.Seed(fight, tracker, now, matches)
    tracker.liveUptimeUnits = {}
    if not fight or not fight.running then return end
    for id, unit in pairs(fight.units) do
        for slot, effect in pairs(unit.effects or {}) do
            if matches(tracker.config, effect.ability) then
                local data = tracker.liveUptimeUnits[id]
                if not data then
                    data = { all = Meter.NewScope(), own = Meter.NewScope(), slots = {} }
                    tracker.liveUptimeUnits[id] = data
                end
                data.slots[slot] = effect
                Meter.ScopeEvent(data.all, slot, now, true)
                if effect.own then Meter.ScopeEvent(data.own, slot, now, true) end
                if Stacks then Stacks.Event(data, effect.ability, slot, now, true, effect.own, effect.stacks) end
            end
        end
    end
end

function LiveUptime.Finish(fight, summary, convert)
    if summary.starttime and summary.endtime and summary.starttime > 0 and summary.endtime > 0 then
        fight.starts, fight.ends = convert(summary.starttime), convert(summary.endtime)
    end
    for id, unit in pairs(fight.units) do
        if summary.units then unit.offline = summary.units[id] == nil end
    end
    for id, data in pairs(summary.units or {}) do
        local unit = fight.units[id]
        if unit then
            unit.kind = data.unitType or data.unittype or unit.kind
            LiveUptime.Kind(fight, id, unit.kind)
            unit.offline = data.name == "Offline"
            unit.name = data.displayname or data.name
        end
    end
    fight.running = false
end

local function selected(config, id, unit, playerId, targetId)
    if unit.offline then return false end
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
        or unit.kind == COMBAT_UNIT_TYPE_GROUP or (config.includePets == true and unit.kind == COMBAT_UNIT_TYPE_PLAYER_PET)
end

function LiveUptime.Calculate(fight, tracker, playerId, targetId, report)
    local result = { covered = 0, normalCovered = 0, stackCovered = 0, duration = 0, percent = 0, members = {} }
    if not fight or not fight.starts or not fight.ends then return result end
    local first = math.max(fight.starts, tracker.state.since)
    local units = fight.allies
    if tracker.config.unit ~= "group" then
        local id = tracker.config.unit == "player" and playerId or targetId
        units = id and fight.units[id] and { [id] = fight.units[id] } or {}
    end
    for id, unit in pairs(units) do
        if selected(tracker.config, id, unit, playerId, targetId) then
            local starts, ends = math.max(first, unit.starts), math.min(fight.ends, unit.ends)
            if ends > starts then
                local data = tracker.liveUptimeUnits and tracker.liveUptimeUnits[id]
                local scope = data and (tracker.config.buffSource == "own" and data.own or data.all)
                local covered = scope and Meter.IntervalTotal(scope.intervals, starts, ends) or 0
                if scope and scope.starts then covered = covered + math.max(0, ends - math.max(starts, scope.starts)) end
                local normalCovered = covered
                local stackCovered = Stacks and Stacks.Total(data and data.stackInstances, tracker.config.buffSource, starts, ends) or covered
                if tracker.config.uptimeMetric == "stacks" then covered = stackCovered end
                result.normalCovered, result.stackCovered = result.normalCovered + normalCovered, result.stackCovered + stackCovered
                result.covered, result.duration = result.covered + covered, result.duration + ends - starts
                if report and #result.members < 48 then
                    result.members[#result.members + 1] = { id = id, name = unit.name, covered = covered, duration = ends - starts,
                        starts = starts, ends = ends, intervals = scope and scope.intervals or {},
                        open = scope and scope.starts, eligibility = { { starts, ends } } }
                    if tracker.config.uptimeMetric == "stacks" then
                        result.members[#result.members].weighted = data and data.stackInstances or {}
                        result.members[#result.members].source = tracker.config.buffSource
                    end
                elseif report then
                    result.truncated = true
                end
            end
        end
    end
    result.percent = result.duration > 0 and math.max(0, result.covered / result.duration * 100) or 0
    if tracker.config.uptimeMetric ~= "stacks" then result.percent = math.min(100, result.percent) end
    return result
end
