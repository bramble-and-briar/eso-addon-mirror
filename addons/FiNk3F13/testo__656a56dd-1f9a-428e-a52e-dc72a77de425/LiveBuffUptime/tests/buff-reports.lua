local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local nativeList = dofile("tests/helpers/report-console-ui.lua")(env)
local old = assert(env.saved().lastUptimeReport)
assert(#old.buffs == 1 and #old.buffs[1].members == 12)
local before = old.buffs[1].covered
setup.begin(1000)
assert(env.saved().lastUptimeReport == old, "Last report must remain during the next fight")
for id = 1, 6 do setup.raw(1000, id, 1, 1020) end
setup.damage(1100)
env.setClock(1101)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
local report = env.saved().lastUptimeReport
assert(report ~= old and old.buffs[1].covered == before, "Stored reports must not reference mutable fight data")
assert(report.buffs[1].covered == 120 and report.buffs[1].duration == 1200 and report.buffs[1].percent == 10)
local zero = 0
for _, member in ipairs(report.buffs[1].members) do
    assert(member.duration == 100)
    if member.covered == 0 then zero = zero + 1 end
end
assert(zero == 6, "Never-buffed members must appear in the report")
local bindings, removed
KEYBIND_STRIP = {
    AddKeybindButtonGroup = function(_, group) bindings = group end,
    RemoveKeybindButtonGroup = function(_, group) assert(group == bindings); removed = true end,
}
env.setting("Kampfstatistiken").clickHandler()
local window = env.controls.LiveBuffUptimeReportWindow
assert(window and not window.hidden)
assert(env.controls.LiveBuffUptimeReportTotal.text == "Gruppen-Uptime  10,0 %")
assert(env.controls.LiveBuffUptimeReportCovered1.text:find(",", 1, true))
assert(env.controls.LiveBuffUptimeReportPercent1.text:find(",", 1, true))
assert(env.controls.LiveBuffUptimeReportName1.text ~= "")
assert(bindings[1].keybind == "UI_SHORTCUT_NEGATIVE")
bindings[1].callback()
assert(window.hidden and removed, "Controller close must remove report keybinds")
-- Account names and paging are rendered from a saved snapshot, not live group APIs.
local buff = report.buffs[1]
buff.members[1].account = "PSN-Testname"
for index = 13, 24 do buff.members[index] = { name = "Spieler " .. index, covered = 0, duration = 100 } end
SLASH_COMMANDS["/lbu"]("uptime")
assert(env.controls.LiveBuffUptimeReportName1.text == "PSN-Testname")
buff.members[1].name = "@psn-testname"
LiveBuffUptimeReports.Refresh()
assert(not env.controls.LiveBuffUptimeReportCharacter1, "Character-name subline must not be created")
assert(env.controls.LiveBuffUptimeReportName1.height == 42, "Name and death summary must have separate lines")
buff.members[1].name = "Charaktername"
LiveBuffUptimeReports.Refresh()
assert(not env.controls.LiveBuffUptimeReportCharacter1 and env.controls.LiveBuffUptimeReportName1.text == "PSN-Testname")
assert(env.controls.LiveBuffUptimeReportName1.height == 42)
LiveBuffUptimeReports.ChangePage()
assert(env.controls.LiveBuffUptimeReportName1.text == "Spieler 13")
report.buffs[2] = { id = 123, name = "Eigener Buff", unit = "player", basis = "alive", covered = 20, duration = 100, percent = 20,
    members = { { name = "Eigener Spieler", covered = 20, duration = 100 } } }
LiveBuffUptimeReports.ShowZone()
LiveBuffUptimeReports.ShowBuffs()
LiveBuffUptimeReports.Refresh()
nativeList:SetSelectedIndex(2)
assert(env.controls.LiveBuffUptimeReportTotal.text == "Persoenliche Uptime  20,0 %")
report.buffs[2].percent = 78.23
report.buffs[2].members[1].covered = 78.23
LiveBuffUptimeReports.Refresh()
assert(env.controls.LiveBuffUptimeReportTotal.text == "Persoenliche Uptime  78,2 %")
assert(env.controls.LiveBuffUptimeReportPercent1.text == "78,2 %")
assert(report.buffs[2].percent == 78.23, "Display precision must not alter stored values")
assert(env.controls.LiveBuffUptimeReportName1.text == "Eigener Spieler")
LiveBuffUptimeReports.Close()
local saved = env.saved()
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(env.saved().lastUptimeReport == report, "Reload must preserve the saved last fight")
env.saved().lastUptimeReport = nil
env.saved().uptimeHistory = {}
LiveBuffUptimeReports.Open()
assert(env.controls.LiveBuffUptimeReportBuff.text == "Noch kein abgeschlossener Kampf")
assert(env.controls.LiveBuffUptimeReportName1.text == "")
LiveBuffUptimeReports.Close()
print("Buff reports: fight-end capture, 12 members including zero coverage, snapshot isolation, account names, controller bindings, paging, selection, reload and empty state passed")
