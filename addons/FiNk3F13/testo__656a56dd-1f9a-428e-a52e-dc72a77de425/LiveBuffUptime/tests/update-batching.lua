local env = dofile("tests/addon.lua")
EVENT_COMBAT_EVENT, ACTION_RESULT_DAMAGE = 20, 101
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 3
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local names = { "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "EVENT_DAMAGE_OUT", "EVENT_DAMAGE_SELF",
    "EVENT_EFFECTS_IN", "MESSAGE_COMBATSTART" }
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
local callbacks = {}
LibCombat = { RegisterForCombatEvent = function(_, _, event, callback) callbacks[event] = callback end }
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
env.setClock(40)
env.setCombat(false)
env.setBuffs("player", {})
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
for _, config in ipairs({ { 61747, "player" }, { 123, "group" } }) do
    env.setting("Effekt-ID").setFunction(tostring(config[1]))
    env.setting("Einheit").setFunction(nil, nil, { data = config[2] })
    env.setting("Tracker hinzufuegen").clickHandler()
end
env.setClock(42)
env.setCombat(true)
callbacks[LIBCOMBAT_EVENT_MESSAGES](nil, 142000, LIBCOMBAT_MESSAGE_COMBATSTART)
callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 142000)
callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 142000, 1, 61747, EFFECT_RESULT_GAINED, 0, 1, 0, 1)
env.events.LiveBuffUptimeCombatTiming(nil, ACTION_RESULT_DAMAGE, false, nil, nil, nil, nil, 1, nil, 4, 100)

local calculations, groupCalculations, samples, writes, reads = 0, 0, 0, 0, 0
local Meter, Group = LiveBuffUptimeMeter, LiveBuffUptimeGroup
local percent, groupUpdate, getBuffs = Meter.ScopePercent, Group.Update, GetNumBuffs
Meter.ScopePercent = function(...)
    calculations = calculations + 1
    return percent(...)
end
Group.Update = function(group, observations, now, combat, window, sampleOnly)
    if sampleOnly then samples = samples + 1 else groupCalculations = groupCalculations + 1 end
    return groupUpdate(group, observations, now, combat, window, sampleOnly)
end
GetNumBuffs = function(...)
    reads = reads + 1
    return getBuffs(...)
end
for index = 1, 2 do
    local label = env.controls["LiveBuffUptimeTracker" .. index].labels[2]
    label.SetText = function(self, value) self.text = value; writes = writes + 1 end
end

for index = 1, 1000 do
    local now = 42 + index / 10000
    env.setClock(now)
    callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, now * 1000 + 100000)
    callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, (42 + index / 40000) * 1000 + 100000,
        1, 61747, EFFECT_RESULT_UPDATED, 0, 1, 0, 1)
end
assert(calculations == 0 and groupCalculations == 0 and writes == 0 and reads == 0,
    "2000 library callbacks must not recompute, render or rescan buff lists")
callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 142050, 1, 61747, EFFECT_RESULT_FADED, 0, 1, 0, 1)

-- An effect entirely between UI ticks must still contribute its full 60 ms.
env.setClock(42.02)
env.rawEvents[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_GAINED, 1, "Effect", "player", 42.02, 42.08,
    1, "icon.dds", nil, nil, nil, nil, nil, nil, 123)
env.setClock(42.08)
env.rawEvents[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_FADED, 1, "Effect", "player", 42.02, 42.08,
    1, "icon.dds", nil, nil, nil, nil, nil, nil, 123)
env.setClock(42.1)
env.events.LiveBuffUptimeCombatTiming(nil, ACTION_RESULT_DAMAGE, false, nil, nil, nil, nil, 1, nil, 4, 100)
assert(samples == 2 and calculations == 0 and groupCalculations == 0 and writes == 0,
    "Raw effect events must sample immediately without computing percentages")
env.events.tick()
assert(calculations == 1 and groupCalculations == 1 and writes == 2,
    "One scheduled tick must compute each tracker once")
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "5.0 %", "Late fade interval was lost")
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "60.0 %", "Between-tick group buff was lost")

-- Finalization must flush pending measurements without waiting for another tick.
env.setClock(44)
callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 144000)
assert(calculations == 1 and writes == 2)
env.setClock(45)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil, { starttime = 142000, endtime = 145000, activetime = 3 })
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "2.5 %", "Finalization must flush the pending damage window")
print("Update batching: 2000 library events, no repeated scans/rendering, 60ms group effect and immediate final flush passed")
