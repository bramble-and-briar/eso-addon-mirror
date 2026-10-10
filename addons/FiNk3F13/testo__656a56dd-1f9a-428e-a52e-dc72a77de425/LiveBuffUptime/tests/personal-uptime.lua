local reference = dofile("tests/live-uptime-reference.lua")
local Engine = LiveBuffUptimeEngine
local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. tostring(b)) end
local fight = Engine.New(0)
local tracker = { config = { unit = "player" }, state = { since = 0 } }
Engine.Kind(fight, 10, COMBAT_UNIT_TYPE_PLAYER)
Engine.Action(fight, "EVENT_DAMAGE_OUT", 2, 10, 99, 100)
Engine.Effect(fight, tracker, 2, 10, 61771, 1, true, true, 1)
Engine.Effect(fight, tracker, 5, 10, 61771, 1, false, true, 1)
Engine.Action(fight, "EVENT_DAMAGE_OUT", 10, 10, 99, 100)
local result = Engine.Calculate(fight, tracker, 10)
near(result.covered, 3); near(result.duration, 8); near(result.percent, 37.5)
tracker.config.personalTime = "unit"
near(Engine.Calculate(fight, tracker, 10).percent, 100)
tracker.config.personalTime = nil

-- Compare the buff seconds against the reference processor and the denominator
-- against the actual installed UI's personal-panel fallback formula.
local expected = reference.oracle()
expected.starttime, expected.endtime = 2000, 10000
reference.processor(expected, { 1, 2000, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1 })
reference.processor(expected, { 1, 5000, 10, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1 })
local file = assert(io.open("../CombatMetrics/CombatMetricsUI.lua", "r"))
local source = file:read("*a"); file:close()
local maximum = assert(source:match("local maxtime = ([^\r\n]+)"))
local denominator = assert(source:match("local totalUnitTime = ([^\r\n]+)"))
local referenceDuration = assert(loadstring("return function(fightData, buffData) local zo_max = math.max; local maxtime = "
    .. maximum .. "; return " .. denominator .. " end"))()
local summary = { starttime = 2000, endtime = 10000, activetime = 8, dpstime = 8, hpstime = 0,
    units = { [10] = { unitType = COMBAT_UNIT_TYPE_PLAYER }, [99] = { unitType = COMBAT_UNIT_TYPE_OTHER } } }
Engine.Finish(fight, summary, function(ms) return ms / 1000 end)
result = Engine.Calculate(fight, tracker, 10, nil, true)
near(result.percent, expected.calculated.units[10].buffs[61771].groupUptime / referenceDuration(summary, {}) * 100)
near(result.duration, 8)
dofile("Diagnostics.lua")
local audit = LiveBuffUptimeDiagnostics.New(function() end)
LiveBuffUptimeDiagnostics.SetEnabled(audit, true)
LiveBuffUptimeDiagnostics.Queue(audit, { label = "Personal", starts = 2, ends = 10, duration = 8,
    group = true, percent = result.percent, members = result.members })
for index = 1, 20 do LiveBuffUptimeDiagnostics.Tick(audit) end
assert(string.find(audit.last[1], "OK intern", 1, true), audit.last[1])

-- An active buff keeps accumulating live even without further buff events.
fight, tracker = Engine.New(0), { config = { unit = "player" }, state = { since = 0 } }
Engine.Kind(fight, 10, COMBAT_UNIT_TYPE_PLAYER)
Engine.Effect(fight, tracker, 2, 10, 61771, 1, true, true, 1)
Engine.Action(fight, "EVENT_DAMAGE_OUT", 2, 10, 99, 100)
Engine.Action(fight, "EVENT_DAMAGE_OUT", 12, 10, 99, 100)
near(Engine.Calculate(fight, tracker, 10).percent, 100)
-- No buff and no player effect identity must still retain the fight denominator.
tracker.liveUptimeUnits = {}
near(Engine.Calculate(fight, tracker, nil, nil, true).duration, 10)
near(Engine.Calculate(fight, tracker, nil).percent, 0)
-- Respect the personal UI's minimum one-second denominator for short fights.
fight, tracker = Engine.New(0), { config = { unit = "player" }, state = { since = 0 } }
Engine.Kind(fight, 10, COMBAT_UNIT_TYPE_PLAYER)
Engine.Action(fight, "EVENT_DAMAGE_OUT", 0, 10, 99, 100)
Engine.Effect(fight, tracker, 0, 10, 61771, 1, true, true, 1)
Engine.Effect(fight, tracker, 0.5, 10, 61771, 1, false, true, 1)
Engine.Action(fight, "EVENT_DAMAGE_OUT", 0.5, 10, 99, 100)
near(Engine.Calculate(fight, tracker, 10).percent, 50)
print("Personal uptime: early fade, continued damage, personal vs selected-unit denominator, installed reference UI, active buffs, zero buffs and short fights passed")
