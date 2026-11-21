-- FiNk3--F13-- | Pure timer logic; no combat participation or damage requirement.
FiNk3WBTCore = {}
local C = FiNk3WBTCore

function C.New(seconds)
    return { seconds = seconds or 306, timers = {}, encounter = nil }
end

function C.Key(zone, poi)
    return tostring(zone) .. ":" .. tostring(poi)
end

function C.Reset(state)
    -- Explicit manual reset. Teleporting only clears the current encounter.
    state.timers = {}
    state.encounter = nil
end

function C.Observe(state, key, tag, name, dead, now)
    if not key or not tag or not name or name == "" then return end
    if not state.encounter or state.encounter.key ~= key then
        state.encounter = { key = key, units = {}, started = false }
    end
    local encounter = state.encounter
    local identity = tag .. ":" .. name
    local previous = encounter.units[identity]
    if not dead then
        -- Death/combat callbacks can arrive before the next unit-state update.
        -- Do not let a stale alive reading immediately cancel a confirmed death.
        if previous and previous.dead and now - previous.diedAt < 2 then return end
        if encounter.started then
            encounter.units = {}
            encounter.started = false
        end
        encounter.units[identity] = { aliveSeen = true, dead = false }
        state.timers[key] = nil
    elseif previous and previous.aliveSeen then
        previous.dead = true
        previous.diedAt = previous.diedAt or now
    end
    -- A corpse first seen after arrival is deliberately insufficient.
end

function C.Finish(state)
    local encounter = state.encounter
    if not encounter or encounter.started then return end
    local count, lastDeath = 0, 0
    for _, unit in pairs(encounter.units) do
        count = count + 1
        if not unit.dead then return end
        lastDeath = math.max(lastDeath, unit.diedAt)
    end
    if count > 0 then
        state.timers[encounter.key] = lastDeath + state.seconds
        encounter.started = true
    end
end

function C.Text(state, key, now)
    local deadline = state.timers[key]
    if not deadline then return "Zeit unbekannt", 0.8, 0.8, 0.8 end
    local remaining = math.ceil(deadline - now)
    if remaining <= 0 then return "Spawn erwartet?", 0.9, 0.8, 0.4 end
    return string.format("%d:%02d", math.floor(remaining / 60), remaining % 60), 1, 0.8, 0.25
end
