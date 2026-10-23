local env = dofile("tests/libcombat.lua")
local saved = env.saved()
env.setClock(100)
env.setCombat(false)
env.setBuffs("player", { { 123, 100, 104.15 } })
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
function GetSelectedLFGRole() return LFG_ROLE_DPS end
function GetGroupSize() return 0 end
function IsUnitGrouped() return false end
saved.trackers = {
    { key = 1, id = 123, unit = "player", x = 0, y = 0, scale = 1 },
    { key = 2, id = 123, unit = "group", x = 0, y = 50, scale = 1 },
}
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
env.setCombat(true)
env.callbacks[LIBCOMBAT_EVENT_MESSAGES](nil, 200000, LIBCOMBAT_MESSAGE_COMBATSTART)
env.setClock(100.15)
env.callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 200150)
env.events.tick()
env.setClock(109.19)
env.callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 209190)
env.events.tick()
local self = env.controls.LiveBuffUptimeTracker1.labels[2]
local group = env.controls.LiveBuffUptimeTracker2.labels[2]
assert(self.text == "44.2 %" and group.text == self.text, "Solo group HUD must exclude the same pre-action 0.15 seconds as personal HUD: " .. self.text .. " / " .. group.text)
env.setCombat(false)
env.setClock(109.35)
function GetSelectedLFGRole() return LFG_ROLE_TANK end
env.callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil, { starttime = 200000, endtime = 209350 })
local report = saved.lastUptimeReport
local a, b = report.buffs[1], report.buffs[2]
assert(a.members[1].role == LFG_ROLE_DPS and b.members[1].role == LFG_ROLE_DPS,
    "Personal and group fallback reports must retain the role used at fight start")
assert(math.abs(a.duration - 9.04) < 0.000001 and math.abs(a.duration - b.duration) < 0.000001)
assert(math.abs(a.covered - 4) < 0.000001 and math.abs(a.covered - b.covered) < 0.000001)
assert(math.abs(a.percent - b.percent) < 0.000001, "Stored group and personal percentages must match their common window")
env.setClock(115)
env.events.tick()
assert(self.text == group.text and math.abs(report.buffs[2].duration - 9.04) < 0.000001, "Post-combat ticks must not extend the reference time")
print("Solo fallback: delayed first damage, shared HUD/report denominator, partial buff, delayed summary and frozen tail passed")
