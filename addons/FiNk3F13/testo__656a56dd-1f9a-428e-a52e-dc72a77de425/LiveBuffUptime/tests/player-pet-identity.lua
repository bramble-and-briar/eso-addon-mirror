local env = dofile("tests/addon.lua")
local names = { "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "MESSAGE_COMBATSTART", "EVENT_DAMAGE_OUT",
    "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT", "EVENT_HEAL_IN", "EVENT_HEAL_SELF",
    "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT", "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT" }
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local callbacks = {}
LibCombat = { RegisterForCombatEvent = function(_, _, event, callback) callbacks[event] = callback end }
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
env.setCombat(false); env.setClock(30)
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "player", scale = 1, x = 0, y = 0 },
    { key = 2, id = 61771, unit = "group", scale = 1, x = 0, y = 48 } }
saved.checkUptime = true
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(name, time, ...)
    env.setClock(time)
    callbacks[_G["LIBCOMBAT_" .. name]](_G["LIBCOMBAT_" .. name], time * 1000 + 100000, ...)
end
send("EVENT_MESSAGES", 30, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_EFFECTS_IN", 30, 1, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_DAMAGE_OUT", 32, 1, 1, 99, 123, 500)
-- v1 uses EFFECTS_IN for playerpet recipients too, even when source is the player.
send("EVENT_EFFECTS_IN", 33, 20, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_EFFECTS_IN", 34, 21, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_EFFECTS_IN", 36, 1, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_DAMAGE_SELF", 38, 1, 1, 20, 123, 10)
send("EVENT_HEAL_OUT", 40, 1, 1, 1, 123, 100)
env.events.tick()
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "50.0 %", "Pet effects/SELF target must not replace player identity")
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, { starttime = 132000, endtime = 140000,
    playerid = 1, units = { [1] = { unitType = 1, name = "Player" }, [20] = { unitType = 2, name = "Bear" },
        [21] = { unitType = 2, name = "Blastbones" }, [99] = { unitType = 4 } } })
for index = 1, 30 do env.events.tick() end
assert(saved.lastFights[1].percent == 50 and saved.lastFights[1].members[1].id == 1)
assert(saved.lastFights[2].percent == 50 and #saved.lastFights[2].members == 1)
local pets = 0
for _, unit in ipairs(saved.lastFights[2].excluded) do
    if unit.id == 20 or unit.id == 21 then
        assert(unit.kind == 2 and unit.reason == "Begleiter ausgeschlossen")
        pets = pets + 1
    end
end
assert(pets == 2)
-- When the first inferred ID was a pet, summary.playerid must repair the identity.
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
send("EVENT_MESSAGES", 50, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_EFFECTS_IN", 50, 20, 999, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_EFFECTS_IN", 50, 1, 61771, EFFECT_RESULT_GAINED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_DAMAGE_OUT", 52, 1, 1, 99, 123, 500)
send("EVENT_EFFECTS_IN", 56, 1, 61771, EFFECT_RESULT_FADED, 1, 1, COMBAT_UNIT_TYPE_PLAYER, 1)
send("EVENT_HEAL_OUT", 60, 1, 1, 1, 123, 100)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](LIBCOMBAT_EVENT_FIGHTSUMMARY, { starttime = 152000, endtime = 160000,
    playerid = 1, units = { [1] = { unitType = 1, name = "Player" }, [20] = { unitType = 2, name = "Bear" }, [99] = { unitType = 4 } } })
assert(saved.lastFights[#saved.lastFights - 1].members[1].id == 1)
assert(saved.lastFights[#saved.lastFights - 1].percent == 50)
print("Player/pet identity: v1 EFFECTS_IN pet tags, SELF targets, summary player ID, pet types and group exclusion passed")
