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
env.setCombat(false); env.setClock(1000)
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(name, time, ...)
    env.setClock(time)
    callbacks[_G["LIBCOMBAT_" .. name]](_G["LIBCOMBAT_" .. name], time * 1000 + 100000, ...)
end
local function raw(id, time, change, ending, tag)
    env.setClock(1000 + time)
    env.rawEvents[EVENT_EFFECT_CHANGED](nil, change, id, "", tag or "", 1003.054, ending and 1000 + ending or 0,
        1, "icon", 0, 2, 0, 0, "Gegner " .. id, id, 34384, 1)
end
send("EVENT_MESSAGES", 1000, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_DAMAGE_OUT", 1000, 1, 1, 99, 123, 100)
-- Replay both orderings from the screenshots, before the first confirming hit.
raw(18836, 3.054, 1, 8.053)
raw(18836, 3.054, 2, 0.053)
raw(71259, 3.054, 1, 0.053)
raw(71259, 3.054, 2, 8.053)
assert(not LiveBuffUptimeReports.IsEnemy(18836))
for _, id in ipairs({18836, 71259}) do
    LiveBuffUptimeReports.RecordDamage(1, 4, id, "Gegner " .. id, 100)
    raw(id, 6.893, 2, 11.892, id == 71259 and "reticleover" or "")
    raw(id, 11.139, 2, 16.138, id == 71259 and "reticleover" or "")
end
send("EVENT_DAMAGE_OUT", 1015.5, 1, 1, 71259, 123, 100)
raw(18836, 15.509, 3, nil)
raw(71259, 15.549, 3, nil, "reticleover")
-- A provisional ID that is never confirmed must not appear in the report.
raw(99999, 15.55, 1, 20.55)
env.setClock(1016)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 1100000, endtime = 1115500, playerid = 1, units = {}})
local debuff = assert(saved.lastUptimeReport.debuffs[1])
assert(#debuff.members == 2)
for _, member in ipairs(debuff.members) do
    assert(math.abs(member.covered - 12.446) < 0.000001,
        "First untagged effect must survive confirmation and a stale expiry update")
    assert(member.duration == 15.5)
end
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "80.3 %")
local from = #env.messages + 1
SLASH_COMMANDS["/lbu"]("debuffdebug 34384 18836")
local text = table.concat(env.messages, "\n", from)
assert(text:find("vorgemerkt", 1, true) and text:find("Ende nicht angegeben", 1, true))
assert(not text:find("Ende -", 1, true), "Zero fade timestamps must not be printed as negative durations")
print("First-hit order: exact screenshot replay, provisional native IDs, reversed stale/valid expiry events, later enemy confirmation and HUD/report agreement passed")
