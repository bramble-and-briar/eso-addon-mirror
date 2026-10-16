local env = dofile("tests/addon.lua")
local names = {"EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "MESSAGE_COMBATSTART", "EVENT_DAMAGE_OUT",
    "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT", "EVENT_HEAL_IN", "EVENT_HEAL_SELF",
    "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT", "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT"}
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
BUFF_EFFECT_TYPE_DEBUFF, UNIT_REACTION_HOSTILE = 2, 3
local callbacks = {}
LibCombat = {RegisterForCombatEvent = function(_, _, event, callback) callbacks[event] = callback end}
GetUnitReaction = function() return 3 end
DoesUnitExist = function(tag) return tag == "player" or tag == "reticleover" end
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
local saved = env.saved()
saved.trackers = {{key = 1, id = 34384, unit = "reticleover", scale = 1, x = 0, y = 0}}
ZO_SavedVars.NewAccountWide = function() return saved end
env.setCombat(false); env.setClock(100)
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(name, time, ...)
    env.setClock(time)
    callbacks[_G["LIBCOMBAT_" .. name]](_G["LIBCOMBAT_" .. name], time * 1000 + 100000, ...)
end
send("EVENT_MESSAGES", 100, LIBCOMBAT_MESSAGE_COMBATSTART)
-- Sixth recipient is never targeted; its library effect precedes our first damage notification.
send("EVENT_EFFECTS_OUT", 100, 106, 34384, 1, 2, 1, 1, 1)
for id = 101, 106 do
    LiveBuffUptimeReports.RecordDamage(1, 4, id, "Gegner " .. id, 100)
    send("EVENT_DAMAGE_OUT", 100, 1, 1, id, 123, 100)
end
for id = 101, 105 do
    env.rawEvents[EVENT_EFFECT_CHANGED](nil, 1, 1, "", id == 101 and "reticleover" or "", 100, 105,
        1, "icon", 0, 2, 0, 0, "Gegner " .. id, id, 34384, 1)
end
-- Duplicate notification without expiry must not erase a known native expiry.
send("EVENT_EFFECTS_OUT", 101, 102, 34384, 2, 2, 1, 1, 1)
send("EVENT_EFFECTS_OUT", 105, 106, 34384, 3, 2, 1, 1, 1)
-- Neither unconfirmed targets nor incoming debuffs on allies enter enemy reports.
send("EVENT_EFFECTS_OUT", 105, 999, 34384, 1, 2, 1, 1, 1)
send("EVENT_EFFECTS_IN", 105, 1, 34384, 1, 2, 1, 4, 1)
send("EVENT_DAMAGE_OUT", 110, 1, 1, 101, 123, 100)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "50.0 %")
env.setClock(111)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 200000, endtime = 210000, playerid = 1, units = {}})
local report = assert(saved.lastUptimeReport)
local debuff = assert(report.debuffs[1])
assert(#debuff.members == 6 and debuff.covered == 30 and debuff.duration == 60 and debuff.percent == 50)
for _, member in ipairs(debuff.members) do
    assert(member.covered == 5 and member.duration == 10, "Every confirmed recipient must have its own five-second interval")
end
local from = #env.messages + 1
SLASH_COMMANDS["/lbu"]("debuffdebug 34384")
local debugText = table.concat(env.messages, "\n", from)
assert(debugText:find("6 Gegner", 1, true))
assert(debugText:find("[106] Gegner 106: LibCombat 1/0/1", 1, true), "Library-only recipient must retain its own source counters")
from = #env.messages + 1
SLASH_COMMANDS["/lbu"]("debuffdebug 34384 106")
assert(table.concat(env.messages, "\n", from):find("+5.000s LibCombat beendet", 1, true))
assert(saved.lastUptimeReport == report and report.debuffs[1].percent == 50, "Diagnostic queries must not change saved or HUD calculations")
-- Different recipients must keep individual results, not inherit the all-enemy average.
send("EVENT_MESSAGES", 200, LIBCOMBAT_MESSAGE_COMBATSTART)
for id = 101, 106 do
    LiveBuffUptimeReports.RecordDamage(1, 4, id, "Gegner " .. id, 100)
    send("EVENT_DAMAGE_OUT", 200, 1, 1, id, 123, 100)
    env.rawEvents[EVENT_EFFECT_CHANGED](nil, 1, 1, "", "reticleover", 200, 200 + id - 100,
        1, "icon", 0, 2, 0, 0, "Gegner " .. id, id, 34384, 1)
end
send("EVENT_DAMAGE_OUT", 210, 1, 1, 106, 123, 100)
env.events.tick()
env.setClock(211)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 300000, endtime = 310000, playerid = 1, units = {}})
local finalReport = saved.lastUptimeReport
assert(finalReport.debuffs[1].percent == 35, "Aggregate still measures all six enemy scopes")
local hud = env.controls.LiveBuffUptimeTracker1
assert(hud.labels[2].text == "60.0 %", "HUD final value must equal the selected enemy's report row, not the aggregate")
-- Late reticle messages and rebuilding the live cache must not overwrite a saved final result.
env.rawEvents[EVENT_EFFECT_CHANGED](nil, 1, 1, "", "reticleover", 211, 220,
    1, "icon", 0, 2, 0, 0, "Anderer Gegner", 999, 34384, 1)
env.events[EVENT_RETICLE_TARGET_CHANGED]()
LiveBuffUptimeReports.BeginEncounter(212, false, "player")
env.events.tick()
assert(hud.labels[2].text == "60.0 %" and finalReport.debuffs[1].percent == 35,
    "Final HUD and immutable report must survive target changes and live-cache replacement")
send("EVENT_MESSAGES", 220, LIBCOMBAT_MESSAGE_COMBATSTART)
env.events.tick()
assert(hud.labels[2].text == "0.0 %", "A new combat must clear the frozen enemy result")
print("Six enemy recipients: untargeted native tags, library-only sixth target, preserved expiry, no duplication and ally/unknown exclusion passed")
