local env = dofile("tests/addon.lua")
EVENT_COMBAT_EVENT, ACTION_RESULT_DAMAGE = 90, 10
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 3, 4
BUFF_EFFECT_TYPE_DEBUFF, UNIT_REACTION_HOSTILE = 2, 3
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local saved = {nextKey = 2, trackers = {{key = 1, id = 61771, unit = "player", x = 0, y = 0, scale = 1}}}
ZO_SavedVars.NewAccountWide = function() return saved end
DoesUnitExist = function(tag) return tag == "player" or tag == "reticleover" end
GetUnitName = function(tag) return tag == "reticleover" and "Gegner" or "Spieler" end
GetUnitReaction = function() return 3 end
env.setCombat(false); env.setClock(90)
env.setBuffs("player", {}); env.setBuffs("reticleover", {})
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local selection = env.setting("Einheit")
assert(#selection.items == 4)
local enemy = selection.items[4]
assert(enemy.data == "reticleover" and enemy.name == "Auf dem Gegner")
selection.setFunction(nil, nil, enemy)
env.setting("Effekt-ID").setFunction("39077")
env.setting("Tracker hinzufuegen").clickHandler()
local config = saved.trackers[2]
assert(config.unit == "reticleover" and config.groupRole == nil)
assert(LiveBuffUptimeGroupPanels.Config({config = config}).target == "enemies")
local function unitSetting()
    local found
    for _, descriptor in ipairs(env.panel.descriptors) do
        if descriptor.type == LibHarvensAddonSettings.ST_SECTION then
            found = descriptor.label and descriptor.label:find("(39077)", 1, true)
        elseif found and descriptor.label == "Einheit" then return descriptor end
    end
end
assert(unitSetting().getFunction() == "Auf dem Gegner")
local function hit(time)
    env.setClock(time)
    env.events.LiveBuffUptimeCombatTiming(nil, 10, false, "", "", 0, "Spieler", 1, "Gegner", 4, 100, 0, 0, false, 1, 99, 123)
end
env.setClock(100); env.setCombat(true)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
hit(100)
env.setClock(101); env.setBuffs("reticleover", {{39077, 101, 109}})
env.events[EVENT_EFFECT_CHANGED](nil, 1, 1, "", "reticleover", 101, 109, 1, "icon", 0, 2, 0, 0, "Gegner", 99, 39077, 1)
assert(env.controls.LiveBuffUptimeTracker2.labels[1].text == "8.0", "The enemy tracker must show the target's debuff timer")
hit(110)
env.setClock(111); env.setCombat(false)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
local report = assert(saved.lastUptimeReport)
assert(#report.debuffs == 1 and report.debuffs[1].id == 39077)
assert(report.debuffs[1].members[1].name == "Gegner" and report.debuffs[1].percent == 80)
unitSetting().setFunction(nil, nil, {data = "dds"})
assert(config.unit == "group" and config.groupRole == "damage")
unitSetting().setFunction(nil, nil, enemy)
assert(config.unit == "reticleover" and config.groupRole == nil)
assert(saved.trackers[1].unit == "player", "Changing the enemy tracker must not change other tracker scopes")
print("Enemy selection: four native options, new/existing trackers, HUD target timer, debuff report, default enemy panel and role-filter clearing passed")
