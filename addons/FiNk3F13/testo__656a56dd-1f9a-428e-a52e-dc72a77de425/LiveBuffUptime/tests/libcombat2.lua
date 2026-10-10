local env = dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
LIBCOMBAT_LOG_EVENT_COMBATSTATE, LIBCOMBAT_LOG_EVENT_DAMAGE, LIBCOMBAT_LOG_EVENT_HEAL, LIBCOMBAT_LOG_EVENT_EFFECT = 1, 2, 3, 4
LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_MESSAGE_COMBATSTART = 51, 1
-- Stale v1 globals must not override bridge event keys when both versions are loaded.
LIBCOMBAT_EVENT_MESSAGES, LIBCOMBAT_EVENT_DAMAGE_OUT = 999, 998
local callbacks, registrations = {}, 0
local kinds = { [1] = COMBAT_UNIT_TYPE_PLAYER, [10] = COMBAT_UNIT_TYPE_GROUP,
    [99] = COMBAT_UNIT_TYPE_OTHER, [20] = COMBAT_UNIT_TYPE_PLAYER_PET }
LibCombat = { RegisterForCombatEvent = function() error("v1 must not be registered when v2 is available") end }
LibCombat2 = {
    RegisterForCombatEvent = function(name, event, callback)
        assert(name == "LiveBuffUptime" and type(event) == "number" and type(callback) == "function", "v2 requires dot calls")
        assert(not callbacks[event], "Unified events must be registered only once")
        callbacks[event], registrations = callback, registrations + 1
        return true
    end,
    GetPlayerUnitId = function() return 1 end,
    GetUnitById = function(id) return { GetUnitType = function() return kinds[id] end } end,
}
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
env.setCombat(false); env.setClock(30)
env.setBuffs("player", {})
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "group", scale = 1, x = 0, y = 0 },
    { key = 2, id = 61771, unit = "player", scale = 1, x = 0, y = 48 } }
saved.checkUptime = true
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(registrations == 5)
local function send(event, time, ...)
    env.setClock(time)
    callbacks[event](event, time * 1000 + 100000, ...)
end
send(1, 30, LIBCOMBAT_MESSAGE_COMBATSTART)
send(4, 30, 1, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send(4, 30, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_GROUP, 1)
send(2, 32, 1, 1, 99, 123, 500, 1, 0)
COMBAT_UNIT_TYPE_NONE = 0
send(4, 33, 10, 61771, EFFECT_RESULT_UPDATED, 1, 1, COMBAT_UNIT_TYPE_NONE, 1)
send(4, 34, 99, 999, EFFECT_RESULT_GAINED, 1, 1, nil, 2)
send(4, 35, 1, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send(4, 36, 10, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_GROUP, 1)
send(3, 40, 1, 1, 10, 123, 500, 1, 0)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "63.6 %")
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "37.5 %")
send(2, 45, 1, 99, 1, 123, 500, 1, 0)
send(2, 46, 1, 10, 99, 123, 500, 1, 0)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "63.6 %", "Incoming/group damage must not extend own active clock")
env.setClock(60)
callbacks[51](51, { info = { combatStart = 130000, combatEnd = 160000 }, unitIds = { player = 1 },
    damageDone = { [1] = { startTime = 132000, endTime = 132000 } },
    healingDone = { [1] = { startTime = 140000, endTime = 140000 } },
    units = { [1] = { unitType = 1 }, [10] = { unitType = 3 }, [99] = { unitType = 4 } } })
for index = 1, 30 do env.events.tick() end
assert(saved.lastFights[1].combatDuration == 8 and saved.lastFights[1].duration == 11)
assert(saved.lastFights[2].percent == 37.5)
assert(#saved.lastCheck.last == 2)
send(2, 61, 1, 1, 99, 123, 500, 1, 0)
send(4, 61, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_GROUP, 1)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "63.6 %", "Late v2 events must not reopen the fight")
assert(saved.lastFights[1].diagnostics.lateActions == 1 and saved.lastFights[1].diagnostics.lateEffects == 1)
assert(saved.lastFights[1].freeze.checks == 1 and saved.lastFights[1].freeze.violations == 0)
assert(saved.lastFights[1].backend == "LibCombat2")
assert(#saved.lastFights[1].unknownEffects == 2 and saved.lastFights[1].diagnostics.unknownSourceEvents == 2)
assert(saved.lastFights[1].unknownEffects[1].trackedBuff and saved.lastFights[1].unknownEffects[1].recipientIncluded)
assert(not saved.lastFights[1].unknownEffects[2].trackedBuff and not saved.lastFights[1].unknownEffects[2].recipientIncluded)
assert(saved.lastFights[1].unknownEffects[1].recipient == 10 and saved.lastFights[1].unknownEffects[1].updated == 1)
send(1, 65, LIBCOMBAT_MESSAGE_COMBATSTART)
send(2, 65, 1, 1, 99, 123, 500, 1, 0)
send(3, 66, 1, 1, 10, 123, 500, 1, 0)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "0.0 %", "A genuine new v2 fight must start normally")
local statusFrom = #env.messages + 1
SLASH_COMMANDS["/lbu"]("status")
local statusText = table.concat(env.messages, "\n", statusFrom)
assert(statusText:find("5 Registrierungen, 0 abgelehnt", 1, true))
assert(statusText:find("Callback-Fehler 0", 1, true) and statusText:find("Spieler-ID 1", 1, true))
local getUnit = LibCombat2.GetUnitById
LibCombat2.GetUnitById = function() error("Test unit API failure") end
send(2, 67, 1, 1, 99, 123, 500, 1, 0)
LibCombat2.GetUnitById = getUnit
statusFrom = #env.messages + 1
SLASH_COMMANDS["/lbu"]("status")
statusText = table.concat(env.messages, "\n", statusFrom)
assert(statusText:find("Callback-Fehler 1", 1, true) and statusText:find("Test unit API failure", 1, true))
print("LibCombat2: dot registration, unified logs, v2 preference, PC-global isolation, units, own clock and v2 summary passed")
