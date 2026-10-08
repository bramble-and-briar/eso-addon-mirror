local env = dofile("tests/libcombat.lua")
local people = {
    group1 = { name = "@me", dead = false, combat = true },
    group2 = { name = "@other", dead = false, combat = true },
}
people.player = people.group1
EVENT_UNIT_DEATH_STATE_CHANGED = 18
function GetGroupSize() return 2 end
function GetGroupUnitTagByIndex(index) return "group" .. index end
function GetUnitDisplayName(tag) return people[tag].name end
function IsUnitOnline() return true end
function IsUnitDead(tag) return people[tag].dead end
function IsUnitDeadOrReincarnating(tag) return people[tag].dead end
function IsUnitInCombat(tag) return people[tag].combat end
function DoesUnitExist(tag) return people[tag] ~= nil end
env.setClock(60)
env.setBuffs("group1", {})
env.setBuffs("player", {})
env.setBuffs("group2", { { 123, 60, 75 } })
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
env.setting("Effekt-ID").setFunction("123")
env.setting("Einheit").setFunction(nil, nil, { data = "group" })
env.setting("Tracker hinzufuegen").clickHandler()
local window = env.controls.LiveBuffUptimeTracker1
env.setClock(62)
env.events.tick()
assert(window.labels[2].text == "50.0 %")
people.group1.dead, people.group1.combat = true, false
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "player", true)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
env.setClock(64)
env.events.tick()
assert(window.labels[2].text == "66.7 %")
env.callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil, { starttime = 160000, endtime = 162000, activetime = 2 })
env.setClock(66)
env.events.tick()
assert(window.labels[2].text == "75.0 %", "Personal library summary must not end surviving members' tracking")
people.group1.dead, people.group1.combat = false, true
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "player", false)
env.callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 166000)
env.setClock(68)
env.events.tick()
assert(window.labels[2].text == "66.7 %", "New personal library fight must preserve the group fight")
print("Group LibCombat: continued group measurement after personal summary and resurrection passed")
