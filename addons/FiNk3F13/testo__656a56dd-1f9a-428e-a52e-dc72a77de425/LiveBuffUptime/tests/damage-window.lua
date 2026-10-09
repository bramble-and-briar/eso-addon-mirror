local env = dofile("tests/addon.lua")
EVENT_COMBAT_EVENT = 20
ACTION_RESULT_DAMAGE, ACTION_RESULT_HEAL = 101, 102
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 3
local people = {
    player = { combat = false }, group1 = { combat = false }, group2 = { combat = false },
}
function DoesUnitExist(tag) return people[tag] ~= nil or tag == "reticleover" end
function GetGroupSize() return 2 end
function GetGroupUnitTagByIndex(index) return "group" .. index end
function GetUnitDisplayName(tag) return tag == "player" and "group1" or tag end
function IsUnitOnline() return true end
function GetUnitZoneIndex() return 1 end
function IsUnitInCombat(tag) return people[tag].combat end
env.setClock(90)
env.setBuffs("player", {})
env.setBuffs("reticleover", {})
env.setBuffs("group1", {})
env.setBuffs("group2", {})
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
for _, unit in ipairs({ "player", "reticleover", "group" }) do
    env.setting("Effekt-ID").setFunction("123")
    env.setting("Einheit").setFunction(nil, nil, { data = unit })
    env.setting("Tracker hinzufuegen").clickHandler()
end
local player = env.controls.LiveBuffUptimeTracker1
local target = env.controls.LiveBuffUptimeTracker2
local group = env.controls.LiveBuffUptimeTracker3
SLASH_COMMANDS["/lbu"]("check on")
local function activity(result, source, targetType)
    env.events.LiveBuffUptimeCombatTiming(nil, result or ACTION_RESULT_DAMAGE, false, nil, nil, nil,
        "Source", source or COMBAT_UNIT_TYPE_GROUP, "Target", targetType or 4, 100)
end
local function effects(starts, ends)
    for _, unit in ipairs({ "player", "reticleover", "group1" }) do
        env.setBuffs(unit, starts and { { 123, starts, ends } } or {})
    end
end
env.setClock(100)
for _, person in pairs(people) do person.combat = true end
effects(100, 105)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
activity()
env.events.tick()
env.setClock(105)
effects()
env.events.tick()
env.setClock(110)
activity()
env.events.tick()
assert(player.labels[2].text == "50.0 %")
assert(target.labels[2].text == "50.0 %")
assert(group.labels[2].text == "25.0 %")

-- Stale combat status and new effects must not extend the measured window.
env.setClock(115)
effects(115, 125)
env.events.tick()
env.setClock(120)
activity(ACTION_RESULT_HEAL)
activity(ACTION_RESULT_DAMAGE, COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP)
env.events.tick()
assert(player.labels[1].text == "5.0", "Buff countdown continues independently")
assert(player.labels[2].text == "50.0 %", "Player uptime freezes at last damage")
assert(target.labels[2].text == "50.0 %", "Target uptime freezes at last damage")
assert(group.labels[2].text == "25.0 %", "Group uptime freezes at last damage")
assert(#player.labels == 3, "No additional fight timer label")
env.setClock(125)
effects()
env.events.tick()
env.setClock(130)
activity(ACTION_RESULT_DAMAGE, 4, COMBAT_UNIT_TYPE_PLAYER)
env.events.tick()
assert(player.labels[2].text == "50.0 %", "Resumed combat includes gap and both buff intervals")
assert(target.labels[2].text == "50.0 %")
assert(group.labels[2].text == "25.0 %")
env.setClock(140)
for _, person in pairs(people) do person.combat = false end
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
env.events.tick()
env.setClock(150)
env.events.tick()
assert(player.labels[2].text == "50.0 %", "Late combat end does not change final result")
assert(group.labels[2].text == "25.0 %")

env.setClock(160)
for _ = 1, 20 do env.events.tick() end
local reports = 0
for _, message in ipairs(env.messages) do
    if message:find("Check: ID", 1, true) then
        reports = reports + 1
        assert(message:find("OK intern", 1, true), "Raw/player/target/group self-check returned a warning: " .. message)
    end
end
assert(reports == 3, "Raw combat end must submit player, target and group reports")
for _, person in pairs(people) do person.combat = true end
effects(160, 180)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
activity()
env.events.tick()
env.setClock(170)
activity()
env.events.tick()
assert(player.labels[2].text == "100.0 %", "Next fight resets personal measurements")
assert(group.labels[2].text == "50.0 %", "Next fight resets group measurements")
print("Damage window: stale combat, late buffs, healing, incoming/group damage, pause/resume, final freeze and reset passed")
