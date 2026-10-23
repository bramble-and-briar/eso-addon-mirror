local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local nativeList = dofile("tests/helpers/report-console-ui.lua")(env)
local Reports = LiveBuffUptimeReports
local initial = #env.saved().uptimeHistory
assert(initial >= 1 and env.saved().uptimeHistory[1] == env.saved().lastUptimeReport)
local stamps = 0
function GetTimeStamp() stamps = stamps + 1; return 1000000 + stamps end
function GetTimeString() return "11:30:00" end
function GetDate() return 20261013 end
function GetUnitZone() return "Testgebiet" end
for index = 1, 303 do
    local time = 1000 + index * 100
    setup.begin(time)
    setup.raw(time, 2, 1, time + index % 40)
    setup.damage(time + 50)
    env.setClock(time + 51)
    setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
end
local history = env.saved().uptimeHistory
assert(#history == 300, "History must be bounded")
assert(history[1].buffs[1].covered == 23 and history[300].buffs[1].covered == 4)
assert(history[1].zone == "Testgebiet" and history[1].date == "20261013")
local bindings
KEYBIND_STRIP = { AddKeybindButtonGroup = function(_, group) bindings = group end, RemoveKeybindButtonGroup = function() end }
SLASH_COMMANDS["/lbu"]("uptime")
assert(#nativeList.entries == 1 and nativeList.entries[1].text == "Testgebiet")
Reports.ShowZone()
assert(env.controls.LiveBuffUptimeReportCovered1.text == "0,00 s" or env.controls.LiveBuffUptimeReportCovered1.text == "23,00 s")
assert(nativeList.entries[1].text == "Gegner unbekannt")
local newest = env.controls.LiveBuffUptimeReportTotal.text
nativeList:SetSelectedIndex(2)
assert(env.controls.LiveBuffUptimeReportTotal.text ~= newest, "Controller down must select an older fight")
Reports.SelectFight(300)
assert(nativeList.index == 300 and nativeList.entries[300].text == "Gegner unbekannt", "Older fights must remain selectable without invented names")
local selectedValue = env.controls.LiveBuffUptimeReportTotal.text
local time = 40000
setup.begin(time); setup.raw(time, 2, 1, time + 20); setup.damage(time + 50)
env.setClock(time + 51)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
assert(#history == 300 and env.controls.LiveBuffUptimeReportTotal.text ~= selectedValue, "Evicted selection must clamp safely")
Reports.SelectFight(10)
local selectedReport = history[10]
local selectedPercent = env.controls.LiveBuffUptimeReportTotal.text
time = 40100
setup.begin(time); setup.raw(time, 2, 1, time + 21); setup.damage(time + 50)
env.setClock(time + 51)
setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
assert(history[11] == selectedReport and env.controls.LiveBuffUptimeReportTotal.text == selectedPercent, "Incoming fights must preserve the fight being viewed")
Reports.Close()
local settings = { lastUptimeReport = history[1] }
Reports.Init(settings)
assert(#settings.uptimeHistory == 1 and settings.uptimeHistory[1] == settings.lastUptimeReport, "Legacy last-fight report must migrate")
local saved = env.saved()
Reports.Init(saved)
assert(#saved.uptimeHistory == 300)
print("Report history: 300-fight limit, newest-first order, metadata, controller navigation, paged selection, eviction, stable selection and legacy migration passed")
