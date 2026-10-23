local env = dofile("tests/addon.lua")
EVENT_COMBAT_EVENT, ACTION_RESULT_DAMAGE = 90, 10
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local saved = {nextKey = 2, trackers = {{key = 1, id = 61771, unit = "player", x = 0, y = 0, scale = 1}}}
ZO_SavedVars.NewAccountWide = function() return saved end
env.setCombat(false); env.setClock(90)
env.setBuffs("player", {}); env.setBuffs("reticleover", {})
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function hit(time)
    env.setClock(time)
    env.events.LiveBuffUptimeCombatTiming(nil, 10, false, "", "", 0, "Spieler", 1, "Gegner", 4, 100, 0, 0, false, 1, 99, 123)
end
local function effect(time, change)
    env.setClock(time)
    env.setBuffs("player", {{61771, time, time + 15}})
    env.events[EVENT_EFFECT_CHANGED](nil, change, 1, "", "player", time, time + 15, 1, "icon", 0, 1, 0, 0, "Spieler", 1, 61771, 1)
end
env.setClock(100); env.setCombat(true)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
hit(100)
effect(101, 1)
effect(103, 2)
hit(105)
effect(107, 2)
effect(109, 2)
env.setClock(110); env.setCombat(false)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
local report = assert(saved.lastUptimeReport)
local row = assert(report.buffs[1].members[1])
assert(row.received == 1, "Initial application must remain one receipt")
assert(row.renewed == 3, "Refreshes after the last hit must not disappear from statistics: " .. tostring(row.renewed))
assert(report.started == 100 and report.ended == 105, "Counter fix must not extend the damage window")
assert(math.abs(row.duration - 5) < 0.001 and math.abs(row.covered - 4) < 0.001, "Uptime durations must stay unchanged")
effect(112, 2)
assert(row.renewed == 3, "Out-of-combat effects must not mutate saved counters")
print("Native fallback: all in-combat renewals retained without extending uptime; saved counters frozen")
