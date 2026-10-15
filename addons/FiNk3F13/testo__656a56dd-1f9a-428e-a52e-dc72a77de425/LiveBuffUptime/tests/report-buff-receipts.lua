local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local reports = LiveBuffUptimeReports
local list = dofile("tests/helpers/report-console-ui.lua")(env)
KEYBIND_STRIP = { AddKeybindButtonGroup = function() end, RemoveKeybindButtonGroup = function() end }
setup.begin(1000)
setup.raw(1001, 1, EFFECT_RESULT_GAINED, 1010)
-- Duplicate delivery of the same gained event must not count twice.
env.setClock(1002)
env.rawEvents[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_GAINED, 1, "", "player", 1001, 1010,
    1, "icon", 0, 1, 0, 0, "player", 1, 61771, 3)
setup.raw(1003, 1, EFFECT_RESULT_UPDATED, 1010)
setup.raw(1005, 1, EFFECT_RESULT_UPDATED, 1015)
setup.raw(1006, 1, EFFECT_RESULT_UPDATED, 1015)
setup.raw(1010, 1, EFFECT_RESULT_FADED, 1010)
setup.raw(1011, 1, EFFECT_RESULT_GAINED, 1020)
setup.raw(1004, 2, EFFECT_RESULT_GAINED, 1020)
setup.damage(1020)
env.setClock(1021)
setup.callbacks[51](51, {unitIds = {player = 1}, units = {}})
local report = env.saved().lastUptimeReport
local member
for _, row in ipairs(report.buffs[1].members) do
    if row.id == 1 then member = row; assert(row.received == 2 and row.renewed == 1)
    elseif row.id == 2 then assert(row.received == 1 and row.renewed == 0)
    else assert(row.received == 0 and row.renewed == 0) end
end
assert(member)
local covered, percent = report.buffs[1].covered, report.buffs[1].percent
reports.Open(); reports.ShowZone(); reports.ShowBuffs()
local index
for i, row in ipairs(report.buffs[1].members) do if row == member then index = i end end
assert(env.controls["LiveBuffUptimeReportReceived" .. index].text == "2 / 1")
local icon = env.controls["LiveBuffUptimeReportBuffIcon" .. index]
local value = env.controls["LiveBuffUptimeReportReceived" .. index]
local uptime = env.controls["LiveBuffUptimeReportPercent" .. index]
assert(not icon.hidden and icon.x > uptime.x + uptime.width)
assert(icon.y == uptime.y + 10, "Buff icons must sit lower within their own player row")
local heading = env.controls.LiveBuffUptimeReportReceiptHeading
assert(heading.text == "Erhalten /\nErneuert" and heading.y + heading.height < env.controls.LiveBuffUptimeReportBuffIcon1.y)
assert(value.y >= icon.y + icon.height and value.x + value.width <= env.controls.LiveBuffUptimeReportDetails.width)
assert(value.y + value.height <= uptime.y + uptime.height, "The count must not spill into the next player row")
assert(env.controls.LiveBuffUptimeReportBuffIcon12 and not env.controls.LiveBuffUptimeReportBuffIcon13)
reports.ChangeCategory()
assert(icon.hidden and value.text == "", "Receipt icons must not leak into the enemy debuff view")
reports.ChangeCategory()
member.received = nil
reports.Refresh()
member.renewed = nil
reports.Refresh()
assert(value.text == "- / -", "Old reports without receipt counters must not invent zero counts")
setup.begin(1100)
setup.raw(1101, 1, EFFECT_RESULT_GAINED, 1110)
assert(report.buffs[1].covered == covered and report.buffs[1].percent == percent,
    "Receipt tracking must not mutate saved uptime data")
reports.Close()
print("Buff receipts: ESO hook, duplicate gains, renewals excluded, per-member counts, new fights, icon placement and old reports passed")
