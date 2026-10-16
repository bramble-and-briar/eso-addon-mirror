local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local ownRole = LFG_ROLE_DPS
GetSelectedLFGRole = function() return ownRole end
GetGroupMemberSelectedRole = function(tag)
    local id = tag == "player" and 1 or tonumber(tag:match("%d+"))
    return id and (id <= 8 and LFG_ROLE_DPS or id <= 10 and LFG_ROLE_TANK or LFG_ROLE_HEAL)
end
local saved = env.saved()
saved.trackers = {
    {key = 1, id = 61771, unit = "group", x = 0, y = 0, scale = 1},
    {key = 2, id = 61771, unit = "group", groupRole = "damage", x = 0, y = 50, scale = 1},
}
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
setup.begin(1000)
setup.raw(1000, 2, EFFECT_RESULT_GAINED, 1020)
setup.damage(1005)
local first = env.controls.LiveBuffUptimeTracker1.labels[2].text
local second = env.controls.LiveBuffUptimeTracker2.labels[2].text
env.setting("Gruppenpanel anzeigen").setFunction(true)
local selector = env.setting("Panel-Tracker")
selector.setFunction(nil, nil, selector.items[2])
env.setting("Gruppenpanel anzeigen").setFunction(true)
assert(not env.controls.LiveBuffUptimeGroupPanel1Name12.hidden, "The unfiltered group panel must keep all roles")
for index = 1, 8 do
    assert(not env.controls["LiveBuffUptimeGroupPanel2Name" .. index].hidden)
end
assert(env.controls.LiveBuffUptimeGroupPanel2Name9.hidden)
assert(env.controls.LiveBuffUptimeGroupPanel2Name1.text == "player")
assert(env.controls.LiveBuffUptimeGroupPanel2Name8.text == "group8")
assert(env.controls.LiveBuffUptimeGroupPanel2Timer3.text == "-", "DDs without a buff must remain visible")
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == first and env.controls.LiveBuffUptimeTracker2.labels[2].text == second,
    "Filtering panel rows must not change uptime values")
ownRole = LFG_ROLE_HEAL
env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel2Name1.text == "group2" and env.controls.LiveBuffUptimeGroupPanel2Name8.hidden,
    "The player's current selected healer role must not appear in a DD-only panel")
GetGroupMemberSelectedRole = function() return nil end
env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel2Name1.hidden, "Unknown roles must not be assumed to be DDs")
assert(not env.controls.LiveBuffUptimeGroupPanel1Name12.hidden)
print("Panel roles: DD-only compact rows, all-role panel, missing buffs, current own role, unknown roles and unchanged uptime passed")
