local env = dofile("tests/addon.lua")
assert(#env.saved().uptimeHistory > 0, "Raw ESO combat end must save a report without LibCombat")
assert(env.saved().uptimeHistory[1].fallback, "Fallback report must be identified")
local reports = LiveBuffUptimeReports
local saved = { uptimeHistory = {} }
reports.Init(saved)
local self = { config = { unit = "player", id = 1, key = 1 }, displayPercent = 80,
    state = { since = 0, intervals = { { 0, 8 } } } }
local group = { config = { unit = "group", id = 1, key = 2 }, displayPercent = 50,
    group = { firstDamageAt = 0, lastDamageAt = 10, members = {
        Alice = { meter = { intervals = { { 0, 10 } } }, eligibility = { intervals = { { 0, 10 } } } },
        Bob = { meter = { intervals = {} }, eligibility = { intervals = { { 0, 10 } } } },
    } } }
local function capture(first, last)
    reports.CaptureFallback({ self, group }, first, last, nil, false, function() return "Buff" end, {}, function() return false end)
end
capture(nil, nil)
assert(#saved.uptimeHistory == 0, "No fabricated report before combat activity")
capture(0, 10)
local report = saved.uptimeHistory[1]
assert(report.buffs[1].covered == 8 and report.buffs[1].duration == 10 and report.buffs[1].percent == 80)
assert(#report.buffs[2].members == 2 and report.buffs[2].covered == 10 and report.buffs[2].duration == 20)
assert(report.buffs[2].members[2].covered == 0 and report.buffs[2].percent == 50)
self.state.intervals[1][2] = 0
assert(report.buffs[1].covered == 8, "Finished report must not reference the next fight's meters")
local nativeList = dofile("tests/helpers/report-console-ui.lua")(env)
reports.Open()
assert(#nativeList.entries == 1 and env.controls.LiveBuffUptimeReportTotal.text == "Persoenliche Uptime  80,0 %")
reports.ChangeBuff(1)
assert(env.controls.LiveBuffUptimeReportTotal.text == "Gruppen-Uptime  50,0 %")
reports.Close()
LFG_ROLE_DPS = 1
group.config.groupRole = "damage"
group.group.members.Alice.role = LFG_ROLE_DPS
group.group.members.Bob.role = 2
group.displayPercent = 100
capture(0, 10)
local dd = saved.uptimeHistory[1].buffs[2]
assert(dd.groupRole == "damage" and #dd.members == 2 and dd.covered == 10 and dd.duration == 10)
assert(dd.members[1].counted and not dd.members[2].counted)
reports.Open()
reports.SelectFight(1)
reports.ChangeBuff(1)
assert(env.controls.LiveBuffUptimeReportTotal.text == "DD-Uptime  100,0 %", "DD fallback reports must preserve the filter")
assert(env.controls.LiveBuffUptimeReportName2.text == "Bob" and env.controls.LiveBuffUptimeReportPercent2.text == "-",
    "Excluded support must remain visible without being presented as a zero-uptime DD")
reports.Close()
print("Fallback reports: raw combat-end capture, no invented values, HUD percentages, zero recipients, immutable snapshots and console display passed")
