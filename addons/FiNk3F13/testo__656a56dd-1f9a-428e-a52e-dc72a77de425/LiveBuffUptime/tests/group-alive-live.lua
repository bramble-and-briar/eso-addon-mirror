local env = dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 3, 4
COMBAT_UNIT_TYPE_NONE = 0
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
EVENT_UNIT_DEATH_STATE_CHANGED = 71
LIBCOMBAT_LOG_EVENT_COMBATSTATE, LIBCOMBAT_LOG_EVENT_DAMAGE, LIBCOMBAT_LOG_EVENT_HEAL, LIBCOMBAT_LOG_EVENT_EFFECT = 1, 2, 3, 4
LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_MESSAGE_COMBATSTART = 51, 1
local callbacks, dead = {}, {}
function GetGroupSize() return 12 end
function GetGroupUnitTagByIndex(index) return index == 1 and "player" or "group" .. index end
function GetUnitDisplayName(tag) return tag end
function DoesUnitExist(tag) return tag == "player" or tag:match("^group%d+$") ~= nil end
function IsUnitDead(tag) return dead[tag] or false end
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
local function id(tag) return tag == "player" and 1 or tonumber(tag:match("^group(%d+)$")) end
LibCombat2 = {
    RegisterForCombatEvent = function(_, event, callback) callbacks[event] = callback; return true end,
    GetPlayerUnitId = function() return 1 end,
    GetUnitIdByTag = id,
    GetUnitById = function(unitId) return { GetUnitType = function() return unitId == 1 and 1 or unitId <= 12 and 3 or 4 end } end,
}
for index = 2, 12 do env.setBuffs("group" .. index, {}) end
env.setBuffs("player", {}); env.setClock(100); env.setCombat(false)
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "group", scale = 1, x = 0, y = 0 } }
saved.checkUptime = false
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(event, time, ...)
    env.setClock(time); callbacks[event](event, GetGameTimeMilliseconds(), ...)
end
local function damage(time) send(2, time, 1, 1, 99, 123, 100, 1, 0) end
local function buff(time, unitId, change) send(4, time, unitId, 61771, change, 1, 1, 3, 1) end
local function percent(expected)
    env.events.tick()
    assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == expected,
        env.controls.LiveBuffUptimeTracker1.labels[2].text .. " ~= " .. expected)
end
send(1, 100, 1); damage(100)
for unitId = 1, 6 do buff(100, unitId, 1) end
damage(150); percent("50.0 %")
damage(200); percent("50.0 %")
env.setClock(201)
callbacks[51](51, { unitIds = { player = 1 }, units = { [1] = { unitType = 1 }, [99] = { unitType = 4 } } })
percent("50.0 %")
damage(220); percent("50.0 %")
assert(not saved.lastFights, "No report/check is required to display live group uptime")
send(1, 300, 1); damage(300); buff(300, 1, 1)
env.setClock(320); dead.player = true
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "player", true)
buff(330, 1, 1)
env.setClock(340); dead.player = false
env.setBuffs("player", { { 61771, 340, 400 } })
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "player", false)
damage(400)
-- 80 buff seconds / (80 own + 11*100 other alive seconds).
percent("6.8 %")
env.setClock(401)
callbacks[51](51, { unitIds = { player = 1 }, units = {} })
percent("6.8 %")
env.setBuffs("player", {})
send(1, 500, 1); damage(500); buff(500, 2, 1)
env.setClock(520); dead.group2 = true
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "group2", true)
buff(530, 2, 1)
env.setClock(540); dead.group2 = false
env.setBuffs("group2", { { 61771, 540, 600 } })
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "group2", false)
damage(600); percent("6.8 %")
local engine = LiveBuffUptimeEngine
local fight = engine.New(0)
local tracker = { config = { unit = "group" }, state = { since = 0 } }
for unitId = 1, 12 do
    engine.GroupMember(fight, tostring(unitId), unitId, 0, true)
    engine.Effect(fight, tracker, 0, unitId, 61771, 1, true, false, 1, 3)
    engine.Effect(fight, tracker, unitId == 1 and 80 or 40, unitId, 61771, 1, false, false, 1, 3)
end
engine.EncounterDamage(fight, 100)
local result = engine.Calculate(fight, tracker, 1)
assert(result.covered == 520 and result.duration == 1200)
assert(math.abs(result.percent - 43.3333333333) < 0.00001)
-- Snapshot and raw fade can arrive before the roster knows the numeric ID.
local snapshot, authoritative = { liveUptimeUnits = {} }, { liveUptimeUnits = {} }
engine.Effect(fight, snapshot, 0, "member", 61771, 1, true, false, 1, 3)
engine.Effect(fight, authoritative, 40, 22, 61771, 1, false, false, 1, 3)
local merged = engine.MergeUnits(snapshot.liveUptimeUnits.member, authoritative.liveUptimeUnits[22])
assert(LiveBuffUptimeMeter.IntervalTotal(merged.all.intervals, 0, 100) == 40 and not merged.all.starts)
-- A late join and an offline interval contribute only their eligible time.
local rosterFight = engine.New(0)
engine.GroupMember(rosterFight, "a", 1, 0, true)
engine.GroupMember(rosterFight, "a", 1, 20, false)
engine.GroupMember(rosterFight, "a", 1, 40, true)
engine.GroupMember(rosterFight, "b", 2, 50, true)
engine.EncounterDamage(rosterFight, 100)
local empty = engine.Calculate(rosterFight, { config = { unit = "group" }, state = { since = 0 } }, 1)
assert(empty.duration == 130 and empty.covered == 0)
print("Live group alive uptime: 12 recipients, never-buffed members, death/revival, summary omissions, frozen HUD, no reports and 43.3% oracle passed")
