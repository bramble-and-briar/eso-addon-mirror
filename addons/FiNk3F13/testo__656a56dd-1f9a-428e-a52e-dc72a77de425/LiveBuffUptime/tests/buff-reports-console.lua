local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local nativeList = dofile("tests/helpers/report-console-ui.lua")(env)
local bindings
KEYBIND_STRIP = { AddKeybindButtonGroup = function(_, group) bindings = group end, RemoveKeybindButtonGroup = function() end }
SLASH_COMMANDS["/lbu"]("uptime")

assert(nativeList.active and #nativeList.entries == 1 and nativeList.entries[1].zoneKey,
    "Opening must group fights into the area list")
assert(bindings[6].visible(), "Areas must expose confirmed deletion of their saved fights")
bindings[5].callback()
assert(#nativeList.entries == #env.saved().uptimeHistory and nativeList.entries[1].fightIndex)
assert(nativeList.current and nativeList.scene.fragments[nativeList.headerFragment]
    and nativeList.scene.fragments[nativeList.listFragment], "Left title and fight list must belong to the visible scene")
assert(nativeList.entries[1].subtitle and nativeList.entries[1].icon)
local details = assert(env.controls.LiveBuffUptimeReportDetails)
assert(not details.hidden and details.x == 24 and details.anchorRelative == ZO_SharedGamepadNavQuadrant_2_Background,
    "Report details must be visible in screen space, not offset from the animated left quadrant")
assert(details.scale * 960 <= 840 - 48, "Table must fit the two right console quadrants")
assert(details.height * details.scale <= 850 - 24, "All twelve rows and the footer must fit vertically")
local lastRow = env.controls.LiveBuffUptimeReportPercent12
assert(not env.controls.LiveBuffUptimeReportPercent13, "All twelve members must fit on one page")
assert(env.controls.LiveBuffUptimeReportName1.height == 42)
assert(env.controls.LiveBuffUptimeReportRoleIcon1.height == 54)
local name = env.controls.LiveBuffUptimeReportName1
local death = env.controls.LiveBuffUptimeReportDeaths1
assert(name.y + name.height <= death.y and death.y + death.height <= env.controls.LiveBuffUptimeReportName2.y,
    "Larger names and death summaries must not overlap adjacent rows")
assert(death.x == name.x and death.width == name.width, "Deaths must stay under the player name")
assert(name.x + name.width < env.controls.LiveBuffUptimeReportCovered1.x, "Names must not collide with buff times")
assert(env.controls.LiveBuffUptimeReportPercent1.x + env.controls.LiveBuffUptimeReportPercent1.width <= details.width)
assert(lastRow.y + lastRow.height < env.controls.LiveBuffUptimeReportTotal.y, "Summary must not overlap the last player")
assert(env.controls.LiveBuffUptimeReportPercent1.parent == details)
assert(env.controls.LiveBuffUptimeReportPercent1.text:find("%%"), "Console report must show member uptime")
assert(env.controls.LiveBuffUptimeReportTotal.text:find("Gruppen%-Uptime"))
assert(not env.controls.LiveBuffUptimeReportClose)
assert(not env.controls.LiveBuffUptimeReportNext, "Mouse arrows must not exist")
assert(not env.controls.LiveBuffUptimeFightPrevious, "Native scrolling replaces custom fight buttons")
assert(#bindings == 6 and bindings[2].keybind == "UI_SHORTCUT_RIGHT_SHOULDER" and bindings[3].keybind == "UI_SHORTCUT_LEFT_SHOULDER")
assert(bindings[6].keybind == "UI_SHORTCUT_RIGHT_STICK")
nativeList:SetSelectedIndex(2)
assert(nativeList.index == 2, "Native selection callback must not recursively rebuild the list")
assert(env.controls.LiveBuffUptimeReportBuff.text ~= "")
assert(bindings[5].visible())
bindings[5].callback()
assert(nativeList.entries[1].buffIndex == 1 and not bindings[5].visible(), "Confirming a fight must open its left-side buff list")
nativeList:SetSelectedIndex(1)
assert(env.controls.LiveBuffUptimeReportPercent1.text:find("%%"))
bindings[1].callback()
assert(nativeList.entries[1].fightIndex == 1 and nativeList.active and not details.hidden,
    "Back from buffs must return to fight selection without closing the menu")
bindings[1].callback()
assert(nativeList.entries[1].zoneKey and nativeList.active, "Back from fights must return to areas")
bindings[1].callback()
assert(not nativeList.active and env.controls.LiveBuffUptimeReportWindow.hidden)
assert(details.hidden, "Closing the scene must also hide the independent details panel")
SLASH_COMMANDS["/lbu"]("uptime")
assert(nativeList.active)
assert(not details.hidden, "Reopening must restore report details")
LiveBuffUptimeReports.Close()
local file = assert(io.open("BuffReports.xml", "r"))
local xml = file:read("*a"); file:close()
assert(xml:find('<TopLevelControl name="LiveBuffUptimeReportScreenTemplate" inherits="ZO_Gamepad_ParametricList_Screen"', 1, true))
print("Console reports: PC gamepad detection, native template/list, icons, selection, hidden mouse controls, controller bindings, close and reopen passed")
