local env = dofile("tests/addon.lua")
local names = { "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "MESSAGE_COMBATSTART", "EVENT_DAMAGE_OUT",
    "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT", "EVENT_HEAL_IN", "EVENT_HEAL_SELF",
    "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT", "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT" }
for index, name in ipairs(names) do _G["LIBCOMBAT_" .. name] = 100 + index end
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
function IsConsoleUI() return false end
function GetGameTimeMilliseconds() return GetFrameTimeSeconds() * 1000 + 100000 end
local callbacks = {}
LibCombat = {
    RegisterForCombatEvent = function(_, _, event, callback) callbacks[event] = callback end,
    GetPlayerUnitId = function() return 1 end,
    GetUnitType = function(id) return id == 1 and 1 or 4 end,
}
LibCombat2 = {
    RegisterForCombatEvent = function() error("PC must prefer LibCombat even if v2 is installed") end,
    GetPlayerUnitId = function() return 1 end,
    GetUnitById = function() error("PC must not use the console adapter") end,
}
env.setClock(30); env.setCombat(false); env.setBuffs("player", {})
local saved = env.saved()
saved.trackers = { { key = 1, id = 61771, unit = "player", personalTime = "auto", scale = 1, x = 0, y = 0 } }
saved.checkUptime = true
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function send(name, time, ...)
    env.setClock(time)
    local code = _G["LIBCOMBAT_" .. name]
    callbacks[code](code, GetGameTimeMilliseconds(), ...)
end
send("EVENT_MESSAGES", 30, LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_DAMAGE_OUT", 32, 1, 1, 99, 123, 500)
send("EVENT_EFFECTS_IN", 33, 1, 61771, 1, 1, 1, 3, 1)
send("EVENT_EFFECTS_IN", 36, 1, 61771, 3, 1, 1, 3, 1)
send("EVENT_DAMAGE_OUT", 40, 1, 1, 99, 123, 500)
env.setClock(41)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil, { starttime = 132000, endtime = 140000, activetime = 8,
    units = { [1] = { unitType = 1 }, [99] = { unitType = 4 } } })
for index = 1, 30 do env.events.tick() end
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "37.5 %")
assert(saved.lastFights[1].personalTime == "combat" and saved.lastFights[1].backend == "LibCombat")
print("PC backend: LibCombat preference with both libraries installed and automatic CMX personal denominator passed")
