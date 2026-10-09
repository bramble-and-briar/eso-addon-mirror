local env = dofile("tests/addon.lua")
env.setClock(30)
env.setCombat(false)
env.setBuffs("player", { { 46522, 20, 35 } })
local names = { "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "EVENT_DAMAGE_OUT", "EVENT_DAMAGE_SELF",
    "EVENT_HEAL_OUT", "EVENT_HEAL_SELF", "EVENT_EFFECTS_IN", "MESSAGE_COMBATSTART" }
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local callbacks = {}
LibCombat = { RegisterForCombatEvent = function(_, _, event, callback) callbacks[event] = callback end }
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
local function send(event, at, ...)
    env.setClock(at)
    local code = _G["LIBCOMBAT_" .. event]
    callbacks[code](code, at * 1000 + 100000, ...)
    env.events.tick()
end

dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(not callbacks[LIBCOMBAT_EVENT_HEAL_OUT] and not callbacks[LIBCOMBAT_EVENT_HEAL_SELF], "After-fight healing must not extend the clock")
env.setting("Effekt-ID").setFunction("61747")
env.setting("Tracker hinzufuegen").clickHandler()
local window = env.controls.LiveBuffUptimeTracker1
assert(window.labels[1].text == "5.0", "Alias snapshot did not match canonical effect ID")
send("EVENT_MESSAGES", 30, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_DAMAGE_OUT", 32)
send("EVENT_EFFECTS_IN", 33, 1, 61747, EFFECT_RESULT_GAINED, 0, 1, 0, 2)
send("EVENT_EFFECTS_IN", 34, 1, 61747, EFFECT_RESULT_UPDATED, 0, 1, 0, 2)
send("EVENT_DAMAGE_OUT", 34)
assert(window.labels[2].text == "100.0 %", "Live denominator must start with first action")
send("EVENT_EFFECTS_IN", 36, 1, 61747, EFFECT_RESULT_FADED, 0, 1, 0, 2)
assert(window.labels[2].text == "100.0 %", "Fade must not advance the damage clock")
send("EVENT_DAMAGE_OUT", 38)
env.setClock(38)
env.events.tick()
assert(window.labels[2].text == "66.7 %", "Event interval should be 4 of 6 seconds")
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
assert(window.labels[2].text == "66.7 %", "Raw combat end must not override LibCombat")
env.setClock(42)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, {
    starttime = 130000, endtime = 140000, activetime = 10, dpstime = 8,
})
assert(window.labels[2].text == "66.7 %", "Summary must use the same damage window as the live display")
env.setClock(45)
env.events.tick()
assert(window.labels[2].text == "66.7 %", "Final result should remain frozen")
send("EVENT_MESSAGES", 46, LIBCOMBAT_MESSAGE_COMBATSTART)
assert(window.labels[2].text == "0.0 %", "Next fight must clear prior intervals")
print("LibCombat: alias IDs, prebuffs, first-action timing, refresh, fade, clock conversion and final summary passed")
env.callbacks = callbacks
return env
