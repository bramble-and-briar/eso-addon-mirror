local env = dofile("tests/addon.lua")
EVENT_COMBAT_EVENT = 20
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 3
ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_EFFECT_GAINED_DURATION = 100, 101
ACTION_RESULT_DAMAGE, ACTION_RESULT_EFFECT_FADED, ACTION_RESULT_POWER_ENERGIZE = 102, 103, 104
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED = 1, 2
local filters = {}
REGISTER_FILTER_ABILITY_ID = 99
function EVENT_MANAGER:AddFilterForEvent(_, _, _, id) filters[id] = true end
function DoesUnitExist(tag) return tag == "player" or tag == "reticleover" or tag == "group1" or tag == "group2" end
function GetUnitName(tag) return (tag == "player" or tag == "group1") and "Me" or "Other" end
function GetUnitDisplayName(tag) return (tag == "player" or tag == "group1") and "@me" or "@other" end
function GetGroupSize() return 2 end
function GetGroupUnitTagByIndex(index) return "group" .. index end
function IsUnitOnline() return true end
function GetUnitZoneIndex() return 1 end
function IsUnitInCombat() return true end
env.setBuffs("player", {})
env.setBuffs("reticleover", {})
env.setBuffs("group1", {})
env.setBuffs("group2", {})
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
for _, profile in ipairs(LiveBuffUptimeCooldowns.profiles) do
    for _, id in ipairs(profile.ids or {profile.id}) do assert(filters[id], "Missing filtered proc registration") end
end
env.setClock(100)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
local nextKey = 0
local function add(id, unit, profileKey)
    env.setting("Effekt-ID").setFunction(tostring(id))
    env.setting("Einheit").setFunction(nil, nil, { data = unit })
    env.setting("Tracker hinzufuegen").clickHandler()
    nextKey = nextKey + 1
    for _, setting in ipairs(env.panel.descriptors) do
        if setting.label == "Cooldown-Quelle" then
            for _, item in ipairs(setting.items) do
                if item.data == profileKey then
                    setting.setFunction(nil, nil, item)
                    return env.controls["LiveBuffUptimeTracker" .. nextKey]
                end
            end
        end
    end
    error("Missing profile " .. profileKey)
end
local function combatProc(id, source, targetName, targetType, result)
    env.events[EVENT_COMBAT_EVENT](nil, result or ACTION_RESULT_EFFECT_GAINED, false, nil, nil, nil,
        "Caster", source, targetName or "Enemy", targetType or 4, nil, nil, nil, nil, nil, nil, id)
end
local cases = {
    { "tremorscale", 80866, 80517, 10 },
    { "crimsonOath", 159288, 159291, 12 },
    { "martialKnowledge", 127070, 127070, 8 },
}
for index, case in ipairs(cases) do
    local at = 100 + index * 30
    env.setClock(at)
    local window = add(case[2], "reticleover", case[1])
    combatProc(case[3], COMBAT_UNIT_TYPE_GROUP)
    assert(window.labels[1].text == "--", "Foreign proc must not start own set cooldown")
    combatProc(case[3], COMBAT_UNIT_TYPE_PLAYER)
    assert(window.labels[1].text == string.format("%.1f", case[4]))
    env.setBuffs("reticleover", {{case[2], at, at + 5}})
    env.events.tick()
    assert(window.labels[1].text == "5.0" and window.labels[1].color[1] == 0.65)
    env.setClock(at + 5)
    env.setBuffs("reticleover", {})
    combatProc(case[3], COMBAT_UNIT_TYPE_PLAYER, nil, nil, ACTION_RESULT_EFFECT_FADED)
    env.events.tick()
    assert(window.labels[1].text == string.format("%.1f", case[4] - 5))
    assert(window.labels[1].color[1] == 1)
    env.setting("Tracker entfernen").clickHandler()
end
env.setClock(230)
local drake = add(150974, "group", "drakesRush")
combatProc(150974, COMBAT_UNIT_TYPE_GROUP)
assert(drake.labels[1].text == "--")
combatProc(150974, COMBAT_UNIT_TYPE_PLAYER)
assert(drake.labels[1].text == "18.0", "Own global cooldown must be visible on group tracker")
env.setBuffs("group1", {{150974, 230, 242}})
env.setBuffs("group2", {{61709, 230, 242}})
env.events.tick()
assert(drake.labels[3].text == "2/2", "Heroism aliases must match both group members")
env.setClock(242)
env.setBuffs("group1", {})
env.setBuffs("group2", {})
env.events.tick()
assert(drake.labels[1].text == "6.0")
assert(drake.labels[2].text == "100.0 %", "Own global cooldown exclusion must apply to both members")
env.setting("Tracker entfernen").clickHandler()
env.setClock(260)
local magma = add(61693, "player", "magmaIncarnate")
env.setBuffs("player", {{161527, 260, 270}})
env.events[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_GAINED, 1, "Resolve", "player", 260, 270, 1,
    "icon.dds", nil, nil, nil, nil, "Me", nil, 161527, COMBAT_UNIT_TYPE_PLAYER)
assert(magma.labels[1].text == "10.0", "Magma effect fallback and resolve alias must work")
env.setClock(270)
env.setBuffs("player", {})
env.events.tick()
assert(magma.labels[1].text == "5.0")
env.setting("Tracker entfernen").clickHandler()
local C = LiveBuffUptimeCooldowns
for _, unit in ipairs({"player", "group"}) do
    assert(C.Profile({unit = unit, cooldownProfile = "magmaIncarnate"}, 147417))
    assert(C.Profile({unit = unit, cooldownProfile = "crusader"}, 147417))
    assert(C.Profile({unit = unit, cooldownProfile = "imperium"}, 66887))
end
env.setClock(300)
local pillager = add(172055, "group", "pillager")
combatProc(172055, COMBAT_UNIT_TYPE_GROUP, "Other", COMBAT_UNIT_TYPE_GROUP, ACTION_RESULT_POWER_ENERGIZE)
assert(pillager.labels[1].text == "--", "Resource ticks must not start Pillager cooldown")
combatProc(172056, COMBAT_UNIT_TYPE_GROUP, "Other", COMBAT_UNIT_TYPE_GROUP)
env.setBuffs("group2", {{172055, 300, 310}})
env.events.tick()
assert(pillager.labels[1].text == "10.0" and pillager.labels[3].text == "1/2")
env.setClock(310)
env.setBuffs("group2", {})
env.events.tick()
assert(pillager.labels[1].text == "35.0")
env.setClock(320)
env.events.tick()
assert(pillager.labels[2].text == "33.3 %", "Only affected recipient cooldown must be excluded")
env.setting("Tracker entfernen").clickHandler()
env.setClock(360)
local symphony = add(117111, "player", "symphony")
env.events[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_GAINED, 1, "Favor", "player", 360, 366, 1,
    "icon.dds", nil, nil, nil, nil, "Me", nil, 117111, COMBAT_UNIT_TYPE_GROUP)
env.setClock(366)
env.events.tick()
assert(symphony.labels[1].text == "12.0", "Received Symphony proc must have independent recipient cooldown")
print("Support sets: filtered IDs, own vs foreign sources, effect fallback, aliases, global group cooldown and recipient exclusions passed")
