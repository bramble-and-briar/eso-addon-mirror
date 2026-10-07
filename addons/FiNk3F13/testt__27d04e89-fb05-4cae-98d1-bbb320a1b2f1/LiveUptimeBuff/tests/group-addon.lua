local env = dofile("tests/addon.lua")
local people = {
    group1 = { name = "@me", dead = false, online = true, combat = true, zone = 1 },
    group2 = { name = "@other", dead = false, online = true, combat = true, zone = 1 },
}
people.player = people.group1
local function person(tag) return people[tag] end
function GetGroupSize() return 2 end
function GetGroupUnitTagByIndex(index) return "group" .. index end
function GetUnitDisplayName(tag) return person(tag).name end
function IsUnitOnline(tag) return person(tag).online end
function IsUnitDead(tag) return person(tag).dead end
function IsUnitDeadOrReincarnating(tag) return person(tag).dead end
function IsUnitInCombat(tag) return person(tag).combat end
function GetUnitZoneIndex(tag) return person(tag).zone end
function DoesUnitExist(tag) return people[tag] ~= nil end
EVENT_UNIT_DEATH_STATE_CHANGED, EVENT_GROUP_UPDATE = 18, 19
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
env.setClock(30)
env.setBuffs("group1", { { 123, 30, 40 } })
env.setBuffs("group2", {})
env.setBuffs("player", { { 123, 30, 40 } })
dofile("LiveUptimeBuff.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveUptimeBuff")
env.setting("Effekt-ID").setFunction("123")
env.setting("Einheit").setFunction(nil, nil, { data = "group" })
env.setting("Tracker hinzufuegen").clickHandler()
local window = env.controls.LiveUptimeBuffTracker1
env.setClock(32)
env.events.tick()
assert(window.labels[2].text == "50.0 %")
people.group1.dead, people.group1.combat = true, false
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "player", true)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
env.setBuffs("group2", { { 123, 32, 45 } })
env.events[EVENT_EFFECT_CHANGED](nil, nil, nil, nil, "group2")
env.setClock(34)
env.events.tick()
assert(window.labels[2].text == "66.7 %", "Other members must continue counting after player death")
assert(window.labels[1].text == "11.0", "Timer must follow a living member")
env.setting("Nur im Kampf anzeigen").setFunction(true)
assert(not window.hidden, "Group tracker must stay visible while survivors are in combat")
people.group1.dead, people.group1.combat = false, true
env.setBuffs("group1", {})
env.events[EVENT_UNIT_DEATH_STATE_CHANGED](nil, "player", false)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
env.setClock(36)
env.events.tick()
assert(window.labels[2].text == "60.0 %", "Resurrection must preserve the ongoing group fight")
people.group1.combat, people.group2.combat = false, false
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
env.setClock(40)
env.events.tick()
assert(window.labels[2].text == "60.0 %" and window.hidden)

-- Group effect events still work when a member's buff list is unavailable.
people.group2.combat = true
env.setClock(50)
env.setBuffs("group2", {})
env.events.tick()
env.events[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_GAINED, 4, "Effect", "group2", 50, 60, 1, "icon123.dds", nil, nil, nil, nil, nil, nil, 123)
env.setClock(52)
env.events.tick()
assert(window.labels[2].text == "50.0 %" and window.labels[1].text == "8.0")
env.events[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_FADED, 4, "Effect", "group2", 50, 60, 1, "icon123.dds", nil, nil, nil, nil, nil, nil, 123)
assert(window.labels[1].text == "--")
print("Group addon: death, survivors' casts, resurrection, visibility and event-only buff tracking passed")
