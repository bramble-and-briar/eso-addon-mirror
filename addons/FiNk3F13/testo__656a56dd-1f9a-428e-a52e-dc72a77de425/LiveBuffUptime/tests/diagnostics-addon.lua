local env = dofile("tests/libcombat.lua")
local lines = {}
function d(line) lines[#lines + 1] = line end
assert(env.setting("Uptime-Selbstpruefung").getFunction() == false)
SLASH_COMMANDS["/lbu"]("check on")
assert(env.setting("Uptime-Selbstpruefung").getFunction() == true)
env.setClock(50)
env.setBuffs("player", {})
env.callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 150000)
env.callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 150000, 1, 61747, EFFECT_RESULT_GAINED, 0, 1, 0, 1)
env.setClock(55)
env.callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 155000, 1, 61747, EFFECT_RESULT_FADED, 0, 1, 0, 1)
env.setClock(60)
env.callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 160000)
env.events.tick()
env.callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil, { starttime = 150000, endtime = 160000 })
for _ = 1, 20 do env.events.tick() end
local found = false
for _, line in ipairs(lines) do
    if line:find("OK intern 50.0%", 1, true) then found = true end
end
assert(found, "Library fight must submit its final tracker data")
local previous = #lines
SLASH_COMMANDS["/lbu"]("check last")
assert(#lines > previous)
SLASH_COMMANDS["/lbu"]("check off")
assert(env.setting("Uptime-Selbstpruefung").getFunction() == false)
print("Diagnostics addon: saved toggle, library finalization, deferred report, last report and disable passed")
