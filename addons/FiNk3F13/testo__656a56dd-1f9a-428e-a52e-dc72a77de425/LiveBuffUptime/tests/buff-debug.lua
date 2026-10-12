local env = dofile("tests/libcombat.lua")
local names = { "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "MESSAGE_COMBATSTART", "EVENT_DAMAGE_OUT",
    "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT", "EVENT_HEAL_IN", "EVENT_HEAL_SELF",
    "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT", "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT" }
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP = 1, 2, 3
local saved = env.saved()
ZO_SavedVars.NewAccountWide = function() return saved end
env.callbacks = {}
LibCombat.RegisterForCombatEvent = function(_, _, event, callback) env.callbacks[event] = callback end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local Debug = LiveBuffUptimeBuffDebug
assert(Debug and not Debug.active)
env.setClock(100)
env.setBuffs("player", { { 46522, 100, 120 } })
SLASH_COMMANDS["/lbu"]("buffdebug start 61747")
assert(Debug.active)
assert(env.messages[#env.messages]:find("Start-Snapshot", 1, true), "Existing aliased buff must appear in the snapshot")
env.callbacks[LIBCOMBAT_EVENT_MESSAGES](nil, 200000, LIBCOMBAT_MESSAGE_COMBATSTART)
local function raw(tag, ability, change)
    env.rawEvents[EVENT_EFFECT_CHANGED](nil, change, 2, "", tag, 100, 120, 1, "icon", 0, 1, 0, 0, "Name", 1, ability, 0)
end
local from = #env.messages
raw("player", 46522, EFFECT_RESULT_GAINED)
assert(env.messages[#env.messages]:find("ESO", 1, true) and env.messages[#env.messages]:find("erhalten", 1, true))
env.callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 200000, 1, 61747, EFFECT_RESULT_GAINED, 0, 1, 0, 2)
assert(env.messages[#env.messages]:find("aktiv verarbeitet", 1, true), table.concat(env.messages, "\n", from + 1))
local quiet = #env.messages
raw("group2", 46522, EFFECT_RESULT_GAINED)
raw("player", 999999, EFFECT_RESULT_GAINED)
assert(#env.messages == quiet, "Other members and unrelated effects must not be printed")
env.setting("Effekt-ID").setFunction("61747")
env.setting("Einheit").setFunction(nil, nil, { data = "group" })
env.setting("Tracker hinzufuegen").clickHandler()
quiet = #env.messages
env.callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 200000, 1, 61747, EFFECT_RESULT_GAINED, 0, 1, 0, 2)
assert(table.concat(env.messages, "\n", quiet + 1):find("(group)", 1, true), "Self contribution in a group tracker must be logged")
env.callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 200000, 1, 61747, EFFECT_RESULT_GAINED, 0, 1, COMBAT_UNIT_TYPE_PLAYER_PET, 2)
assert(env.messages[#env.messages]:find("abgewiesen: Begleiterquelle", 1, true))
raw("player", 46522, EFFECT_RESULT_UPDATED)
raw("player", 46522, EFFECT_RESULT_FADED)
env.callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 201000, 1, 61747, EFFECT_RESULT_FADED, 0, 1, 0, 2)
assert(env.messages[#env.messages]:find("Ende verarbeitet", 1, true))
for index = 1, 150 do raw("player", 46522, EFFECT_RESULT_UPDATED) end
assert(#env.messages - from <= 121, "Live output must be bounded")
SLASH_COMMANDS["/lbu"]("buffdebug stop")
assert(not Debug.active)
local report = table.concat(env.messages, "\n", #env.messages - 13)
assert(report:find("erhalten 1 / erneuert 151 / beendet 1", 1, true), "Counters must continue past the output cap")
quiet = #env.messages
raw("player", 46522, EFFECT_RESULT_GAINED)
env.callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 202000, 1, 61747, EFFECT_RESULT_GAINED, 0, 1, 0, 2)
assert(#env.messages == quiet, "Stopping must disable raw and engine logging")
SLASH_COMMANDS["/lbu"]("buffdebug start")
assert(Debug.active, "Default start must select an active player/group tracker")
SLASH_COMMANDS["/lbu"]("buffdebug stop")
print("Buff debug: opt-in, snapshot aliases, ESO inputs, engine processing, self filter, bounded output, counters, stop and default selection passed")
