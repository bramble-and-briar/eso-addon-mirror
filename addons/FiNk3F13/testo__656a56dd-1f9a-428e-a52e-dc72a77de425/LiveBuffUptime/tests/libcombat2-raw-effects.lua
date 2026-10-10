local env = dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
COMBAT_UNIT_TYPE_NONE = 0
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
LIBCOMBAT_LOG_EVENT_COMBATSTATE, LIBCOMBAT_LOG_EVENT_DAMAGE, LIBCOMBAT_LOG_EVENT_HEAL, LIBCOMBAT_LOG_EVENT_EFFECT = 1, 2, 3, 4
LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_MESSAGE_COMBATSTART = 51, 1
local callbacks = {}
LibCombat2 = {
    RegisterForCombatEvent = function(_, event, callback) callbacks[event] = callback; return true end,
    GetPlayerUnitId = function() return 1 end,
    GetUnitById = function(id)
        return { GetUnitType = function() return id == 1 and 1 or id == 99 and 4 or nil end }
    end,
}
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
env.setCombat(false); env.setClock(30)
env.setBuffs("player", {})
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "group", view = "healingIn", scale = 1, x = 0, y = 0 },
    { key = 2, id = 39077, unit = "reticleover", view = "damageOut", scale = 1, x = 0, y = 48 } }
saved.checkUptime = true
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(event, time, ...)
    env.setClock(time)
    callbacks[event](event, GetGameTimeMilliseconds(), ...)
end
local function raw(time, tag, unit, ability, change, source)
    env.setClock(time)
    env.rawEvents[EVENT_EFFECT_CHANGED](EVENT_EFFECT_CHANGED, change, 1, "buff", tag,
        time, time + 15, 1, "icon", nil, 1, nil, nil, tag, unit, ability, source or 1)
end
send(1, 30, 1)
send(2, 30, 1, 1, 99, 123, 500, 1, 0)
raw(30, "group1", 10, 61771, 1)
raw(30, "playerpet1", 20, 61771, 1)
raw(30, "reticleover", 99, 39077, 1)
raw(35, "group1", 10, 61771, 3)
raw(35, "playerpet1", 20, 61771, 3)
raw(35, "reticleover", 99, 39077, 3)
send(2, 40, 1, 1, 99, 123, 500, 1, 0)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "100.0 %")
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "50.0 %")
env.setClock(41)
callbacks[51](51, { unitIds = { player = 1 }, units = { [1] = { unitType = 1 }, [99] = { unitType = 4 } } })
for index = 1, 30 do env.events.tick() end
assert(saved.lastFights[1].percent == 100 and #saved.lastFights[1].members == 1,
    "Raw-observed group players missing from v2 summary must remain included; pets must not")
assert(saved.lastFights[2].percent == 50)
local from = #env.messages + 1
SLASH_COMMANDS["/lbu"]("status")
local status = table.concat(env.messages, "\n", from)
assert(status:find("Effekte 0", 1, true) and status:find("Direkte ESO-Effekte 6", 1, true), status)
raw(42, "group1", 10, 61771, 1)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "100.0 %", "Raw events must not reopen a finished fight")

-- When both paths work, the same notifications must be forwarded once.
send(1, 50, 1)
send(2, 50, 1, 1, 99, 123, 500, 1, 0)
send(4, 50, 1, 61771, 1, 1, 1, 1, 1)
raw(50, "player", 1, 61771, 1)
raw(55, "player", 1, 61771, 3)
send(4, 55, 1, 61771, 3, 1, 1, 1, 1)
send(2, 60, 1, 1, 99, 123, 500, 1, 0)
env.setClock(61)
callbacks[51](51, { unitIds = { player = 1 }, units = { [1] = { unitType = 1 }, [99] = { unitType = 4 } } })
for index = 1, 30 do env.events.tick() end
assert(saved.lastFights[3].percent == 100 and saved.lastFights[3].diagnostics.effectEvents == 2)
from = #env.messages + 1
SLASH_COMMANDS["/lbu"]("status")
assert(table.concat(env.messages, "\n", from):find("Doppelmeldungen ignoriert 2", 1, true))
-- Already active buffs are seeded once at combat start, including group/target.
env.setBuffs("player", {})
env.setBuffs("group1", { { 61771, 69, 90 } })
env.setBuffs("reticleover", { { 39077, 69, 90 } })
function GetGroupSize() return 1 end
LibCombat2.GetUnitIdByTag = function(tag) return tag == "group1" and 10 or tag == "reticleover" and 99 end
local bridge = LiveBuffUptimeCombatBridge.Create(LibCombat2)
local seeded, summary = {}, nil
bridge:RegisterForCombatEvent("test", bridge.EVENT_MESSAGES, function() end)
bridge:RegisterForCombatEvent("test", bridge.EVENT_GROUPEFFECTS_IN, function(_, _, id, ability) seeded[id] = ability end)
bridge:RegisterForCombatEvent("test", bridge.EVENT_EFFECTS_OUT, function(_, _, id, ability) seeded[id] = ability end)
bridge:RegisterForCombatEvent("test", bridge.EVENT_FIGHTSUMMARY, function(_, result) summary = result end)
send(1, 70, 1)
assert(seeded[10] == 61771 and seeded[99] == 39077 and bridge.GetTargetUnitId() == 99)
for id = 1000, 1300 do bridge.RawEffect(171000, id, 61771, 1, 1, 1, 1, 1, COMBAT_UNIT_TYPE_GROUP) end
assert(bridge.GetStatus().rawUnitsOmitted > 0, "Raw unit metadata must be bounded")
callbacks[51](51, { units = {} })
local count = 0
for _ in pairs(summary.units) do count = count + 1 end
assert(count <= 256)
send(1, 75, 1)
assert(bridge.GetUnitType(1000) == nil, "Raw unit cache must reset for each fight")
print("LibCombat2 raw effects: silent library, group/target uptime, missing summary units, pets, closure and deduplication passed")
