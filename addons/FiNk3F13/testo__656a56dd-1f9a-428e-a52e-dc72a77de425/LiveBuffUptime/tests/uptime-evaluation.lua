local reference = dofile("tests/live-uptime-reference.lua")
local Engine = LiveBuffUptimeEngine
local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. tostring(b)) end
local fight = Engine.New(0)
fight.starts, fight.ends = 0, 10
local tracker = { config = { unit = "group" }, state = { since = 0 } }
Engine.Touch(fight, 1, 0, COMBAT_UNIT_TYPE_PLAYER)
Engine.Effect(fight, tracker, 0, 1, 61771, 1, true, true)
Engine.Effect(fight, tracker, 10, 1, 61771, 1, false, true)
Engine.Touch(fight, 2, 0, COMBAT_UNIT_TYPE_PLAYER_PET)
Engine.Effect(fight, tracker, 0, 2, 61771, 1, true, true)
Engine.Touch(fight, 2, 10)
Engine.Touch(fight, 3, 0, COMBAT_UNIT_TYPE_GROUP)
Engine.Touch(fight, 3, 10)
near(Engine.Calculate(fight, tracker).duration, 10)
tracker.config.includePets = true
near(Engine.Calculate(fight, tracker).duration, 10)
assert(not fight.allies[2], "Pets must not enter the group candidate list")
Engine.Action(fight, "EVENT_HEAL_OUT", 10, 1, 3, 0, 500)
near(Engine.Calculate(fight, tracker).duration, 10)
tracker.config.includeOverheal = true
near(Engine.Calculate(fight, tracker).duration, 20)
tracker.config.view = "healingIn"
near(Engine.Calculate(fight, tracker).duration, 10)
Engine.Action(fight, "EVENT_HEAL_IN", 10, 3, 1, 100)
near(Engine.Calculate(fight, tracker).duration, 20)
-- Any observed effect makes the unit nonempty, even when not the tracked buff.
Engine.Remember(fight.units[3], 999, 4, true, false, 1)
tracker.config.view, tracker.config.includeOverheal = "healingOut", false
near(Engine.Calculate(fight, tracker).duration, 20)

-- Compare changing stacks and concurrent slots against the installed reference processor.
for iteration = 1, 50 do
    local expected, f = reference.oracle(), Engine.New(0)
    local t = { config = { unit = "group", uptimeMetric = "stacks" }, state = { since = 0 } }
    f.starts, f.ends = 0, 30
    Engine.Kind(f, 10, COMBAT_UNIT_TYPE_GROUP)
    local active, time = {}, 0
    for index = 1, 60 do
        time = time + 0.2
        local slot = ((index + iteration) % 3) + 1
        local change = not active[slot] and EFFECT_RESULT_GAINED or ((index + iteration) % 4 == 0 and EFFECT_RESULT_FADED or EFFECT_RESULT_UPDATED)
        local count = (index + iteration) % 5 + 1
        local own = slot ~= 2
        if change == EFFECT_RESULT_FADED then active[slot] = nil else active[slot] = count end
        reference.processor(expected, { 1, time * 1000, 10, 61771, change, 1, count,
            own and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_GROUP, slot })
        Engine.Effect(f, t, time, 10, 61771, slot, change ~= EFFECT_RESULT_FADED, own, count)
    end
    for slot, count in pairs(active) do
        reference.processor(expected, { 1, 25000, 10, 61771, EFFECT_RESULT_FADED, 1, count,
            slot ~= 2 and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_GROUP, slot })
        Engine.Effect(f, t, 25, 10, 61771, slot, false, slot ~= 2, count)
    end
    Engine.Touch(f, 10, 30)
    local instance = expected.calculated.units[10].buffs[61771].instances[61771]
    local all, own, max = 0, 0, 0
    for stacks, data in pairs(instance) do all, own, max = all + data.groupUptime, own + data.uptime, math.max(max, stacks) end
    near(Engine.Calculate(f, t).covered, all / max / 1000)
    t.config.buffSource = "own"
    near(Engine.Calculate(f, t).covered, all / max / 1000)
    near(LiveBuffUptimeStacks.Total(t.liveUptimeUnits[10].stackInstances, "own", 0, 30), own / max / 1000)
end
-- A simple 1 -> 4 stack example has 100% normal time, but 62.5% weighted time.
fight, tracker = Engine.New(0), { config = { unit = "group", uptimeMetric = "stacks" }, state = { since = 0 } }
fight.starts, fight.ends = 0, 10
Engine.Kind(fight, 10, COMBAT_UNIT_TYPE_GROUP)
Engine.Effect(fight, tracker, 0, 10, 61771, 1, true, true, 1)
Engine.Effect(fight, tracker, 5, 10, 61771, 1, true, true, 4)
Engine.Effect(fight, tracker, 10, 10, 61771, 1, false, true, 4)
local result = Engine.Calculate(fight, tracker, nil, nil, true)
near(result.percent, 62.5); near(result.normalCovered, 10)
dofile("Diagnostics.lua")
local lines = {}
local audit = LiveBuffUptimeDiagnostics.New(function(line) lines[#lines + 1] = line end)
LiveBuffUptimeDiagnostics.SetEnabled(audit, true)
LiveBuffUptimeDiagnostics.Queue(audit, { label = "Weighted test", starts = 0, ends = 10, group = true, weighted = true,
    percent = 62.5, duration = 10, members = result.members })
for index = 1, 20 do LiveBuffUptimeDiagnostics.Tick(audit) end
assert(string.find(lines[1], "OK intern", 1, true), lines[1])
print("Evaluation: pets, nonempty units, incoming/outgoing views, overheal, 50 reference stack comparisons and weighted audit passed")
