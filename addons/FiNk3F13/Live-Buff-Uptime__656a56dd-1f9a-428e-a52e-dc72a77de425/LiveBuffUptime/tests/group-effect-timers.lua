local env = dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER, COMBAT_UNIT_TYPE_NONE = 1, 3, 4, 0
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
ACTION_RESULT_DAMAGE, ACTION_RESULT_EFFECT_GAINED_DURATION, ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_EFFECT_FADED = 10, 11, 12, 13
EVENT_COMBAT_EVENT = 90
LIBCOMBAT_LOG_EVENT_COMBATSTATE, LIBCOMBAT_LOG_EVENT_DAMAGE, LIBCOMBAT_LOG_EVENT_HEAL, LIBCOMBAT_LOG_EVENT_EFFECT = 1, 2, 3, 4
LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_MESSAGE_COMBATSTART = 51, 1
local callbacks = {}
function GetGroupSize() return 12 end
function GetGroupUnitTagByIndex(index) return index == 1 and "player" or "group" .. index end
function GetUnitDisplayName(tag) return tag end
function DoesUnitExist(tag) return tag == "player" or tag:match("^group%d+$") ~= nil end
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
local function unitId(tag) return tag == "player" and 1 or tonumber(tag:match("^group(%d+)$")) end
LibCombat2 = {
    RegisterForCombatEvent = function(_, event, callback) callbacks[event] = callback; return true end,
    GetPlayerUnitId = function() return 1 end,
    GetUnitIdByTag = unitId,
    GetUnitById = function(id) return { GetUnitType = function() return id == 1 and 1 or id <= 12 and 3 or 4 end } end,
}
for index = 2, 12 do env.setBuffs("group" .. index, {}) end
env.setBuffs("player", {}); env.setClock(100); env.setCombat(false)
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "group", scale = 1, x = 0, y = 0 } }
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function begin(time)
    env.setClock(time)
    callbacks[1](1, GetGameTimeMilliseconds(), 1)
    callbacks[2](2, GetGameTimeMilliseconds(), 1, 1, 99, 123, 100, 1, 0)
end
local function damage(time)
    env.setClock(time)
    callbacks[2](2, GetGameTimeMilliseconds(), 1, 1, 99, 123, 100, 1, 0)
    env.events.tick()
end
local function raw(time, id, change, ends, slot)
    env.setClock(time)
    local tag = id == 1 and "player" or "group" .. id
    env.rawEvents[EVENT_EFFECT_CHANGED](nil, change, slot or 1, "", tag, time, ends, 1, "icon", 0, 1, 0, 0, tag, id, 61771, 3)
end
local function combat(time, result, id, duration)
    env.setClock(time)
    env.events.LiveBuffUptimeCombatTiming(nil, result, false, "", "", 0, "source", 3, "target", 3, duration, 0, 0, false, 2, id, 61771)
end
local function percent(text)
    assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == text,
        env.controls.LiveBuffUptimeTracker1.labels[2].text .. " ~= " .. text)
end
begin(100)
for id = 1, 12 do raw(100, id, 1, id <= 6 and 110 or 120) end
damage(120); percent("75.0 %") -- 180 buff seconds / 240 alive seconds, without fades.
begin(200)
raw(200, 2, 1, 210)
raw(205, 2, 2, 225)
damage(230); percent("6.9 %") -- 25 / 360, refresh extends the known expiry.
begin(300)
raw(300, 2, 1, 310, 1)
raw(305, 2, 1, 320, 2)
raw(307, 2, 3, 310, 1)
damage(330); percent("5.6 %") -- Union is 20 seconds, not summed slots.
begin(400)
combat(400, 11, 2, 10000)
combat(405, 12, 2, 1)
combat(405, 11, 99, 100000) -- Non-roster recipients must not enter the group average.
damage(420); percent("6.2 %") -- 15 / 240, combat-only refresh (display precision).
begin(500)
combat(500, 11, 2, 100000)
raw(505, 2, 1, 510)
combat(507, 11, 2, 100000) -- Standard timer takes precedence.
damage(520); percent("4.2 %")
env.setClock(521)
callbacks[51](51, { unitIds = { player = 1 }, units = {} })
raw(522, 2, 1, 600)
damage(525); percent("4.2 %") -- Final result is frozen.
print("Group timers: all 12 recipients, missing fades, refresh, overlap, combat durations, stranger rejection, standard precedence and final freeze passed")
return { env = env, begin = begin, raw = raw, damage = damage, callbacks = callbacks }
