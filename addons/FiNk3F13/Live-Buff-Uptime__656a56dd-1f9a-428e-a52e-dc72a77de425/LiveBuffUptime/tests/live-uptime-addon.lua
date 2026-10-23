local env = dofile("tests/addon.lua")
local names = { "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "MESSAGE_COMBATSTART", "EVENT_DAMAGE_OUT",
    "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT", "EVENT_HEAL_IN", "EVENT_HEAL_SELF",
    "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT", "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT" }
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local callbacks = {}
LibCombat = { RegisterForCombatEvent = function(_, _, event, callback) callbacks[event] = callback end }
function GetGroupSize() return 2 end
function GetGroupUnitTagByIndex(index) return index == 1 and "player" or "group2" end
local exists = DoesUnitExist
function DoesUnitExist(tag) return tag == "group2" or exists(tag) end
function GetUnitDisplayName(tag) return tag end
function LibCombat.GetUnitIdByTag(tag) return tag == "player" and 1 or tag == "group2" and 10 end
env.setBuffs("group2", {})
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
env.setCombat(false); env.setClock(30)
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "group", x = 0, y = 0, scale = 1, includePets = true, buffSource = "own" },
    { key = 2, id = 61771, unit = "player", x = 0, y = 48, scale = 1 } }
ZO_SavedVars.NewAccountWide = function() return saved end
local captured = dofile("tests/support/capture.lua")()
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(name, time, ...)
    env.setClock(time)
    callbacks[_G["LIBCOMBAT_" .. name]](_G["LIBCOMBAT_" .. name], time * 1000 + 100000, ...)
end
send("EVENT_MESSAGES", 30, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_EFFECTS_IN", 30, 1, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_GROUPEFFECTS_IN", 30, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, nil, 1)
send("EVENT_GROUPEFFECTS_IN", 31, 10, 999, EFFECT_RESULT_GAINED, 1, 1, nil, 2)
send("EVENT_DAMAGE_OUT", 32, 1, 1, 99, 123, 500)
send("EVENT_EFFECTS_IN", 35, 1, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_GROUPEFFECTS_IN", 36, 10, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_GROUP, 1)
send("EVENT_HEAL_OUT", 40, 1, 1, 10, 123, 500)
env.events.tick()
local group, player = env.controls.LiveBuffUptimeTracker1, env.controls.LiveBuffUptimeTracker2
assert(group.labels[2].text == "100.0 %", group.labels[2].text)
assert(player.labels[2].text == "37.5 %", player.labels[2].text)
local prior = group.labels[2].text
send("EVENT_DAMAGE_IN", 45, 1, 99, 1, 123, 500)
env.events.tick()
assert(group.labels[2].text == "36.7 %", "Incoming damage extends group encounter time")
env.setClock(46)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 132000, endtime = 140000, units = {
        [1] = { unitType = COMBAT_UNIT_TYPE_PLAYER }, [10] = { unitType = COMBAT_UNIT_TYPE_GROUP },
        [99] = { unitType = COMBAT_UNIT_TYPE_OTHER },
    },
})
assert(group.labels[2].text == "36.7 %")
assert(player.labels[2].text == "37.5 %")
for index = 1, 30 do env.events.tick() end
assert(captured[1].duration == 30 and captured[1].covered == 11)
assert(saved.trackers[1].buffSource == nil, "Legacy source setting must be cleared")
-- Reload never resumes the previous fight's clock.
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "0.0 %")
-- Disabled trackers restart from enable time, even if the buff was gained while disabled.
env.setting("Buff aktiv").setFunction(false)
send("EVENT_MESSAGES", 50, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_GROUPEFFECTS_IN", 50, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_HEAL_OUT", 50, 1, 1, 10, 123, 500)
local calculations, scans = 0, 0
local calculate, getNum = LiveBuffUptimeEngine.Calculate, GetNumBuffs
LiveBuffUptimeEngine.Calculate = function(...) calculations = calculations + 1; return calculate(...) end
GetNumBuffs = function(...) scans = scans + 1; return getNum(...) end
for index = 1, 2000 do
    send("EVENT_GROUPEFFECTS_IN", 51, 10, 61771, EFFECT_RESULT_UPDATED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
end
assert(calculations == 0 and scans == 0, "Event bursts must not rescan or recalculate the UI")
send("EVENT_GROUPEFFECTS_IN", 51, 10, 61771, EFFECT_RESULT_GAINED, 1, 99, COMBAT_UNIT_TYPE_PLAYER_PET, 99)
env.setClock(52)
env.setting("Buff aktiv").setFunction(true)
send("EVENT_DAMAGE_OUT", 54, 1, 1, 99, 123, 500)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "50.0 %", "Unbuffed player remains in the denominator: " .. env.controls.LiveBuffUptimeTracker1.labels[2].text)
LiveBuffUptimeEngine.Calculate, GetNumBuffs = calculate, getNum
send("EVENT_GROUPEFFECTS_IN", 55, 10, 61771, EFFECT_RESULT_UPDATED, 1, 4, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_DAMAGE_OUT", 56, 1, 1, 99, 123, 500)
-- Weighted diagnostics remain testable internally, but are no longer a UI option.
saved.trackers[1].uptimeMetric = "stacks"
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "21.9 %")
for _, descriptor in ipairs(env.panel.descriptors) do
    assert(descriptor.label ~= "Begleiter in Gruppenmessung", "Pet option must be removed")
    assert(descriptor.label ~= "Buff-Quelle", "Source option must be removed")
end
assert(saved.trackers[1].includePets == nil, "Legacy pet setting must be cleared")
env.setClock(58)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 150000, endtime = 156000, units = { [10] = { unitType = COMBAT_UNIT_TYPE_GROUP, name = "Raid member" } },
})
for index = 1, 30 do env.events.tick() end
local record = captured[#captured - 1]
assert(record.normalCovered == 4 and record.stackCovered == 1.75)
local final = env.controls.LiveBuffUptimeTracker1.labels[2].text
send("EVENT_DAMAGE_OUT", 60, 1, 1, 99, 123, 500)
send("EVENT_GROUPEFFECTS_IN", 60, 10, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_GROUP, 99)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == final, "Late events must not reopen the completed fight")
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
print("Live-Uptime addon: group and personal windows, healing, incoming damage, finalization, fixed sources, pet exclusion and reload reset passed")
