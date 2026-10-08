local env = dofile("tests/addon.lua")
EVENT_COMBAT_EVENT = 20
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 3
ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_DAMAGE, ACTION_RESULT_EFFECT_FADED = 100, 101, 102
function DoesUnitExist(tag) return tag == "player" or tag == "reticleover" end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
env.setClock(30)
env.setCombat(true)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
env.setBuffs("reticleover", { { 176815, 30, 37 } })
env.setting("Effekt-ID").setFunction("106754")
env.setting("Einheit").setFunction(nil, nil, { data = "reticleover" })
env.setting("Tracker hinzufuegen").clickHandler()
env.setting("Cooldown-Quelle").setFunction(nil, nil, { data = "archdruid" })
local window = env.controls.LiveBuffUptimeTracker1
local function proc(source, result)
    env.events[EVENT_COMBAT_EVENT](nil, result or ACTION_RESULT_DAMAGE, false, nil, nil, nil,
        "Caster", source, "Enemy", 4, nil, nil, nil, nil, nil, nil, 176813)
end
proc(COMBAT_UNIT_TYPE_GROUP)
env.setClock(37)
env.setBuffs("reticleover", {})
env.events.tick()
assert(window.labels[1].text == "--", "Another player's proc must not start your cooldown")
env.setClock(40)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
env.setBuffs("reticleover", { { 176815, 40, 47 } })
proc(COMBAT_UNIT_TYPE_PLAYER)
env.setClock(42)
proc(COMBAT_UNIT_TYPE_PLAYER)
env.setClock(47)
env.setBuffs("reticleover", {})
env.events.tick()
assert(window.labels[1].text == "8.0", "Repeated hits must not restart cooldown")
env.setClock(50)
env.events.tick()
assert(window.labels[2].text == "100.0 %")
env.setting("Cooldownzeit aus Uptime ausnehmen").setFunction(false)
assert(window.labels[2].text == "70.0 %")
env.setting("Cooldownzeit aus Uptime ausnehmen").setFunction(true)
env.setBuffs("reticleover", { { 122397, 50, 60 } })
env.events.tick()
assert(window.labels[1].text == "10.0", "Real debuff duration takes priority over set cooldown")
proc(COMBAT_UNIT_TYPE_PLAYER, ACTION_RESULT_EFFECT_FADED)
env.setClock(55)
env.setBuffs("reticleover", {})
env.events.tick()
assert(window.labels[1].text == "--")
env.setClock(57)
env.events.tick()
assert(tonumber(window.labels[2].text:match("[%d.]+")) < 100, "Delay after cooldown must lower eligible uptime")
local people = {
    player = { name = "Me", account = "@me" },
    group1 = { name = "Me", account = "@me" },
    group2 = { name = "Other", account = "@other" },
}
function GetGroupSize() return 2 end
function GetGroupUnitTagByIndex(index) return "group" .. index end
function GetUnitName(tag) return people[tag] and people[tag].name or "Enemy" end
function GetUnitDisplayName(tag) return people[tag] and people[tag].account or "" end
function IsUnitOnline() return true end
function GetUnitZoneIndex() return 1 end
function IsUnitInCombat() return true end
function DoesUnitExist(tag) return people[tag] ~= nil or tag == "reticleover" end
env.setClock(60)
env.setBuffs("group1", {})
env.setBuffs("group2", { { 137986, 60, 72 } })
env.setting("Effekt-ID").setFunction("93109")
env.setting("Einheit").setFunction(nil, nil, { data = "group" })
env.setting("Tracker hinzufuegen").clickHandler()
for _, descriptor in ipairs(env.panel.descriptors) do
    if descriptor.label == "Cooldown-Quelle" and #descriptor.items == 2 and descriptor.items[2].data == "roaring" then
        descriptor.setFunction(nil, nil, { data = "roaring" })
        break
    end
end
env.events[EVENT_COMBAT_EVENT](nil, ACTION_RESULT_EFFECT_GAINED, false, nil, nil, nil,
    "Healer", COMBAT_UNIT_TYPE_GROUP, "Other", COMBAT_UNIT_TYPE_GROUP, nil, nil, nil, nil, nil, nil, 135923)
local groupWindow = env.controls.LiveBuffUptimeTracker2
env.setClock(72)
env.setBuffs("group2", {})
env.events.tick()
assert(groupWindow.labels[1].text == "10.0")
env.setClock(80)
env.events.tick()
assert(groupWindow.labels[2].text == "37.5 %", "Roaring cooldown exclusion must apply only to its recipient")
assert(groupWindow.labels[3].text == "0/2")
env.setClock(82)
env.events.tick()
assert(groupWindow.labels[1].text == "--")
COMBAT_UNIT_TYPE_PLAYER_PET = 2
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED = 1, 2
env.setting("Effekt-ID").setFunction("145977")
env.setting("Einheit").setFunction(nil, nil, { data = "reticleover" })
env.setting("Tracker hinzufuegen").clickHandler()
for _, descriptor in ipairs(env.panel.descriptors) do
    if descriptor.label == "Cooldown-Quelle" and descriptor.items[2].data == "nunatak" then
        descriptor.setFunction(nil, nil, { data = "nunatak" })
        break
    end
end
local nunatakWindow = env.controls.LiveBuffUptimeTracker3
local function nunatakProc(sourceName, sourceType)
    env.events[EVENT_COMBAT_EVENT](nil, ACTION_RESULT_DAMAGE, false, nil, nil, nil,
        sourceName, sourceType, "Enemy", 4, nil, nil, nil, nil, nil, nil, 167682)
end
nunatakProc("Pet", COMBAT_UNIT_TYPE_PLAYER_PET)
assert(nunatakWindow.labels[1].text == "15.0", "Nunatak must show cooldown before Brittle is applied")
assert(nunatakWindow.labels[1].color[1] == 1 and nunatakWindow.labels[1].color[2] == 0.75)
env.setClock(86)
env.setBuffs("reticleover", { { 167681, 86, 90 } })
nunatakProc("Me", 0)
env.events.tick()
assert(nunatakWindow.labels[1].text == "4.0", "Active Brittle must take priority over Nunatak cooldown")
assert(nunatakWindow.labels[1].color[1] == 0.65 and nunatakWindow.labels[1].color[2] == 1)
env.setClock(88)
env.setBuffs("reticleover", { { 167681, 86, 92 } })
env.events.tick()
assert(nunatakWindow.labels[1].text == "4.0", "Extended Brittle duration must remain visible during cooldown")
env.setClock(90)
env.setBuffs("reticleover", {})
env.events.tick()
assert(nunatakWindow.labels[1].text == "7.0", "Nunatak cooldown must survive owned-proc source types and repeated ticks")
assert(nunatakWindow.labels[1].color[1] == 1 and nunatakWindow.labels[1].color[2] == 0.75)
assert(nunatakWindow.labels[2].text == "100.0 %")
env.setClock(100)
env.events[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_GAINED, 1, "Nunatak", "reticleover", 100, 106, 1,
    "icon.dds", nil, nil, nil, nil, "Enemy", nil, 167682, COMBAT_UNIT_TYPE_PLAYER)
env.events.tick()
assert(nunatakWindow.labels[1].text == "15.0", "Nunatak effect notifications must also start its cooldown")
env.setClock(116)
nunatakProc("Other", COMBAT_UNIT_TYPE_GROUP)
env.events.tick()
assert(nunatakWindow.labels[1].text == "--", "Other players' Nunatak must not start a personal cooldown")
SLASH_COMMANDS["/lbu"]("debug")
nunatakProc("Me", 0)
assert(nunatakWindow.labels[1].text == "15.0")
SLASH_COMMANDS["/lbu"]("debug")
local removeNunatak
for _, descriptor in ipairs(env.panel.descriptors) do
    if descriptor.label == "Tracker entfernen" then removeNunatak = descriptor end
end
removeNunatak.clickHandler()
env.setClock(135)
env.setBuffs("reticleover", { { 167681, 135, 139 } })
env.setting("Effekt-ID").setFunction("172992")
env.setting("Tracker hinzufuegen").clickHandler()
local specialWindow = env.controls.LiveBuffUptimeTracker4
env.events[EVENT_COMBAT_EVENT](nil, ACTION_RESULT_DAMAGE, false, nil, nil, nil,
    "Me", COMBAT_UNIT_TYPE_PLAYER, "Enemy", 4, nil, nil, nil, nil, nil, nil, 172992)
assert(specialWindow.labels[1].text == "4.0", "Stack combat events must not start Nunatak cooldown")
env.events[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_GAINED, 1, "Nunatak (4)", "reticleover", 135, 140, 4,
    "icon.dds", nil, nil, nil, nil, "Enemy", nil, 172992, COMBAT_UNIT_TYPE_PLAYER)
assert(specialWindow.labels[1].text == "4.0", "Stack effect events must not start Nunatak cooldown")
env.events[EVENT_COMBAT_EVENT](nil, ACTION_RESULT_DAMAGE, false, nil, nil, nil,
    "Me", COMBAT_UNIT_TYPE_PLAYER, "Enemy", 4, nil, nil, nil, nil, nil, nil, 167682)
assert(specialWindow.labels[1].text == "4.0", "Legacy tracker must also prioritize active Brittle")
env.setClock(137)
env.events.tick()
assert(specialWindow.labels[1].text == "2.0")
env.setClock(139)
env.setBuffs("reticleover", {})
env.events.tick()
assert(specialWindow.labels[1].text == "11.0", "Legacy stack-ID tracker must use the real Nunatak proc")
assert(specialWindow.labels[2].text == "100.0 %", "172992 tracker uptime must measure Brittle rather than the proc")
env.setClock(150)
env.events.tick()
assert(specialWindow.labels[1].text == "--")
env.setBuffs("reticleover", { { 172992, 150, 155 } })
env.events[EVENT_COMBAT_EVENT](nil, ACTION_RESULT_EFFECT_GAINED, false, nil, nil, nil,
    "Me", COMBAT_UNIT_TYPE_PLAYER, "Enemy", 4, nil, nil, nil, nil, nil, nil, 172992)
env.events[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_UPDATED, 1, "Nunatak (4)", "reticleover", 150, 155, 4,
    "icon.dds", nil, nil, nil, nil, "Enemy", nil, 172992, COMBAT_UNIT_TYPE_PLAYER)
env.setClock(151)
env.events.tick()
assert(specialWindow.labels[1].text == "--", "Stacks must not restart an expired cooldown")
assert(specialWindow.labels[2].text == "80.0 %", "Stack duration must not count as Major Brittle uptime")
ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL = 110, 111
local function nunatakTick(source, result, isError)
    env.events[EVENT_COMBAT_EVENT](nil, result, isError or false, nil, nil, nil,
        "Caster", source, "Enemy", 4, nil, nil, nil, nil, nil, nil, 167682)
end
nunatakTick(COMBAT_UNIT_TYPE_GROUP, ACTION_RESULT_DOT_TICK)
nunatakTick(COMBAT_UNIT_TYPE_PLAYER, ACTION_RESULT_DOT_TICK, true)
assert(specialWindow.labels[1].text == "--", "Foreign or erroneous periodic events must not start cooldown")
nunatakTick(COMBAT_UNIT_TYPE_PLAYER, ACTION_RESULT_DOT_TICK)
assert(specialWindow.labels[1].text == "15.0", "Own Nunatak periodic damage must start cooldown")
env.setClock(153)
nunatakTick(COMBAT_UNIT_TYPE_PLAYER, ACTION_RESULT_DOT_TICK_CRITICAL)
env.events.tick()
assert(specialWindow.labels[1].text == "13.0", "Critical follow-up ticks must not restart cooldown")
env.setClock(167)
nunatakTick(COMBAT_UNIT_TYPE_PLAYER, ACTION_RESULT_DOT_TICK_CRITICAL)
assert(specialWindow.labels[1].text == "15.0", "Own critical periodic damage must also start cooldown")
print("Cooldown addon: source filtering, Roaring recipients, separated Nunatak proc/stacks/debuff, effect events and debug passed")
