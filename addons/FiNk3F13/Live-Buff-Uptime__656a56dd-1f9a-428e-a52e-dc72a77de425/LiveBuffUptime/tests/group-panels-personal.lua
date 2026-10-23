local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local saved = env.saved()
saved.trackers[1].unit = "player"
env.setClock(900); env.setCombat(false)
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
setup.begin(1000)
setup.raw(1000, 1, EFFECT_RESULT_GAINED, 1020)
setup.damage(1002)
local hud = env.controls.LiveBuffUptimeTracker1.labels[2]
local before = hud.text
env.setting("Gruppenpanel anzeigen").setFunction(true)
setup.raw(1002, 2, EFFECT_RESULT_GAINED, 1010)
env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel1Timer2.text == "8,0",
    "Group panels on personal trackers must receive group ESO timers too")
assert(saved.trackers[1].unit == "player" and hud.text == before)
IsUnitOnline = function(tag) return tag ~= "group3" end
IsUnitDead = function(tag) return tag == "group4" end
env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel1Timer3.text == "-")
assert(env.controls.LiveBuffUptimeGroupPanel1Timer4.text == "Tot")
-- Selecting another configured buff must not switch off the first panel.
env.setting("Effekt-ID").setFunction("61665")
env.setting("Tracker hinzufuegen").clickHandler()
local selector = env.setting("Panel-Tracker")
assert(#selector.items == 2)
selector.setFunction(nil, nil, selector.items[2])
assert(not env.setting("Gruppenpanel anzeigen").getFunction())
env.setting("Gruppenpanel anzeigen").setFunction(true)
local key = saved.trackers[2].key
assert(not env.controls.LiveBuffUptimeGroupPanel1.hidden)
assert(not env.controls["LiveBuffUptimeGroupPanel" .. key].hidden)
assert(saved.trackers[1].groupPanel.enabled and saved.trackers[2].groupPanel.enabled)
env.setting("Panelgroesse").setFunction(1.4)
assert(saved.trackers[1].groupPanel.scale == 1 and saved.trackers[2].groupPanel.scale == 1.4)
-- Hiding in menus must not delete the saved enablement or position.
SCENE_MANAGER.GetCurrentScene = function() return {GetName = function() return "settings" end} end
env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel1.hidden and env.controls["LiveBuffUptimeGroupPanel" .. key].hidden)
assert(saved.trackers[1].groupPanel.enabled)
SCENE_MANAGER.GetCurrentScene = function() return {GetName = function() return "hud" end} end
env.events.tick()
assert(not env.controls.LiveBuffUptimeGroupPanel1.hidden)
print("Personal tracker panels: independent group timers, unavailable/dead recipients, multiple selections, per-panel scale and menu visibility passed")
