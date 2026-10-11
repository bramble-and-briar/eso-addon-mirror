local env = dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
COMBAT_UNIT_TYPE_NONE = 0
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
LIBCOMBAT_LOG_EVENT_COMBATSTATE, LIBCOMBAT_LOG_EVENT_DAMAGE, LIBCOMBAT_LOG_EVENT_HEAL, LIBCOMBAT_LOG_EVENT_EFFECT = 1, 2, 3, 4
LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_MESSAGE_COMBATSTART = 51, 1
EVENT_UNIT_DEATH_STATE_CHANGED = 71
local callbacks, dead = {}, false
function IsConsoleUI() return true end
function IsUnitDead() return dead end
function GetGroupSize() return 0 end
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
LibCombat2 = {
    RegisterForCombatEvent = function(_, event, callback) callbacks[event] = callback; return true end,
    GetPlayerUnitId = function() return 1 end,
    GetUnitById = function(id) return { GetUnitType = function() return id == 1 and 1 or id == 10 and 3 or 4 end } end,
}
env.setClock(30); env.setCombat(false); env.setBuffs("player", {})
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "player", scale = 1, x = 0, y = 0 },
    { key = 2, id = 61771, unit = "player", personalTime = "combat", scale = 1, x = 0, y = 48 } }
saved.checkUptime = true
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(event, time, ...)
    env.setClock(time); callbacks[event](event, GetGameTimeMilliseconds(), ...)
end
local function damage(time, source) send(2, time, 1, source or 1, 99, 123, 500, 1, 0) end
local function buff(time, change) send(4, time, 1, 61771, change, 1, 1, 3, 1) end
local function finish(time)
    env.setClock(time)
    callbacks[51](51, { unitIds = { player = 1 }, units = { [1] = { unitType = 1 }, [99] = { unitType = 4 } } })
    for index = 1, 30 do env.events.tick() end
end
local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. tostring(b)) end
send(1, 30, 1); damage(32); buff(33, 1); buff(36, 3); damage(40, 10)
send(3, 45, 1, 1, 10, 123, 500, 1, 0)
finish(46)
local alive, cmx = saved.lastFights[1], saved.lastFights[2]
near(alive.covered, 3); near(alive.duration, 10); near(alive.percent, 30)
near(cmx.covered, 3); near(cmx.duration, 13); near(cmx.percent, 3 / 13 * 100)
assert(alive.personalTime == "alive" and cmx.personalTime == "combat")
assert(alive.fightStarts == 30 and alive.fightEnds == 40)

send(1, 100, 1); damage(100); buff(100, 1)
env.setClock(104); dead = true
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "player", true)
buff(105, 1)
env.setBuffs("player", { { 61771, 110, 125 } })
env.setClock(110); dead = false
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "player", false)
env.setBuffs("player", {})
damage(115); buff(119, 3); damage(120, 10); finish(121)
alive = saved.lastFights[3]
near(alive.covered, 13); near(alive.duration, 14); near(alive.percent, 13 / 14 * 100)
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "92.9 %")
for _, line in ipairs(saved.lastCheck.last) do assert(not line:find("WARN", 1, true), line) end

dead = true
send(1, 200, 1); damage(200); buff(201, 1); damage(210, 10); finish(211)
alive = saved.lastFights[5]
near(alive.covered, 0); near(alive.duration, 0); near(alive.percent, 0)
dead = false
send(1, 220, 1); damage(220); buff(222, 1); buff(226, 3); damage(230, 10); finish(231)
alive = saved.lastFights[7]
near(alive.covered, 4); near(alive.duration, 10); near(alive.percent, 40)
-- The independent audit must also intersect open/weighted intervals with alive windows.
local engine = LiveBuffUptimeEngine
local fight = engine.New(0)
fight.personalBasis = "alive"
local tracker = { config = { unit = "player", uptimeMetric = "stacks" }, state = { since = 0 } }
engine.Kind(fight, 1, 1)
engine.Action(fight, "EVENT_DAMAGE_OUT", 0, 1, 99, 100)
engine.Effect(fight, tracker, 0, 1, 61771, 1, true, false, 2, 3)
engine.PlayerAlive(fight, 5, false); engine.PlayerAlive(fight, 10, true)
engine.Action(fight, "EVENT_DAMAGE_OUT", 20, 1, 99, 100)
engine.Finish(fight, { starttime = 1, endtime = 20000, units = { [1] = { unitType = 1 } } }, function(ms) return ms / 1000 end)
local result = engine.Calculate(fight, tracker, 1, nil, true)
near(result.covered, 15); near(result.duration, 15); near(result.percent, 100)
local audit = LiveBuffUptimeDiagnostics.New(function() end)
LiveBuffUptimeDiagnostics.SetEnabled(audit, true)
LiveBuffUptimeDiagnostics.Queue(audit, { label = "Alive weighted", starts = result.starts, ends = result.ends,
    duration = result.duration, percent = result.percent, members = result.members, group = true, weighted = true })
for index = 1, 30 do LiveBuffUptimeDiagnostics.Tick(audit) end
assert(audit.last[1]:find("OK intern", 1, true), audit.last[1])
tracker.state.since = 12
result = engine.Calculate(fight, tracker, 1)
near(result.covered, 8); near(result.duration, 8)
print("BattleScrolls personal basis: combat start, group damage end, healing exclusion, death, revival snapshot, dead effects, audit and reset passed")
