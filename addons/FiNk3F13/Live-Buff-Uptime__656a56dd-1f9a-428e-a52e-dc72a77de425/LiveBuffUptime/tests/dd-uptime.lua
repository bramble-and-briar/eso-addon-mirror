local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
function GetGroupMemberSelectedRole(tag)
    local id = tag == "player" and 1 or tonumber(tag:match("%d+"))
    return id and (id <= 8 and LFG_ROLE_DPS or id <= 10 and LFG_ROLE_TANK or LFG_ROLE_HEAL)
end
function GetSelectedLFGRole() return LFG_ROLE_DPS end
local saved = env.saved()
saved.trackers = {
    { key = 1, id = 61771, unit = "group", x = 0, y = 0, scale = 1 },
    { key = 2, id = 61771, unit = "group", groupRole = "damage", x = 0, y = 50, scale = 1 },
}
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local ddLabel, groupLabel = false, false
for _, descriptor in ipairs(env.panel.descriptors) do
    if descriptor.label and descriptor.label:find("(61771)", 1, true) then
        ddLabel = ddLabel or descriptor.label:find("Nur DDs", 1, true) ~= nil
        groupLabel = groupLabel or descriptor.label:find("Auf der Gruppe", 1, true) ~= nil
    end
end
assert(ddLabel and groupLabel, "Settings tracker names must distinguish DD filtering from the entire group")
setup.begin(1000)
for id = 1, 8 do setup.raw(1000, id, 1, 1100) end
setup.damage(1100)
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == "66.7 %")
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "100.0 %")
env.setClock(1101)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
local report = saved.lastUptimeReport
assert(#report.buffs[1].members == 12 and #report.buffs[2].members == 12)
local counted = 0
for _, member in ipairs(report.buffs[2].members) do if member.counted then counted = counted + 1 end end
assert(counted == 8, "All twelve members must be displayed but only eight DDs counted")
assert(report.buffs[2].groupRole == "damage" and report.buffs[2].percent == 100)
for _, member in ipairs(report.buffs[2].members) do
    if member.counted then assert(member.role == LFG_ROLE_DPS, "Counted members must retain the DD combat role") end
end
setup.begin(1200)
for id = 1, 4 do setup.raw(1200, id, 1, 1300) end
for id = 9, 12 do setup.raw(1200, id, 1, 1300) end
setup.damage(1300)
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "50.0 %", "Four DDs without buff must stay in the denominator; supports must not enter")
env.setClock(1301)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
report = saved.lastUptimeReport
assert(#report.buffs[2].members == 12 and report.buffs[2].covered == 400 and report.buffs[2].duration == 800)
local dropdown = env.setting("Einheit")
assert(#dropdown.items == 4 and dropdown.items[4].data == "reticleover")
-- No role data is not proof that a member is a damage dealer.
function GetGroupMemberSelectedRole() return nil end
setup.begin(1400)
setup.raw(1400, 2, 1, 1500)
setup.damage(1500)
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "0.0 %")
env.setClock(1501)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
-- The self tag does not always provide a role via the group API, even when grouped.
function GetGroupMemberSelectedRole() return 0 end
function GetSelectedLFGRole() return LFG_ROLE_DPS end
setup.begin(1600)
setup.raw(1600, 1, 1, 1700)
setup.damage(1700)
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "100.0 %", "Own DD role must come from GetSelectedLFGRole, not the group self-tag")
env.setClock(1701)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
assert(#saved.lastUptimeReport.buffs[2].members == 12 and saved.lastUptimeReport.buffs[2].percent == 100)
-- A reported group size must not prevent the solo player from entering the roster.
function IsUnitGrouped() return false end
function GetGroupUnitTagByIndex() return nil end
setup.begin(1800)
setup.raw(1800, 1, 1, 1900)
setup.damage(1900)
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "100.0 %", "Solo DD must be included even if group-size API is nonzero")
env.setClock(1901)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
function GetSelectedLFGRole() return LFG_ROLE_HEAL end
setup.begin(2000)
setup.raw(2000, 1, 1, 2100)
setup.damage(2100)
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "0.0 %")
env.setClock(2101)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
function GetSelectedLFGRole() return LFG_ROLE_DPS end
setup.begin(2200)
setup.raw(2200, 1, 1, 2300)
setup.damage(2300)
assert(env.controls.LiveBuffUptimeTracker2.labels[2].text == "100.0 %", "Next fight after healer-to-DD switch must count the player")
print("DD uptime: 12-member group vs 8 DDs, selected role detection, zero-buff DDs, excluded supports, report membership and unknown roles passed")
