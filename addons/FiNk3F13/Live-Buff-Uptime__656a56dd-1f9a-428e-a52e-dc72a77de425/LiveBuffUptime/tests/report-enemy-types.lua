local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local bindings
KEYBIND_STRIP = {AddKeybindButtonGroup = function(_, group) bindings = group end, RemoveKeybindButtonGroup = function() end}
local effect = {id = 75753, name = "Alkosh", unit = "reticleover", members = {}, covered = 0, duration = 0}
local function add(id, name, covered, duration, boss)
    effect.members[#effect.members + 1] = {id = id, name = name, covered = covered, duration = duration, isBoss = boss}
    effect.covered, effect.duration = effect.covered + covered, effect.duration + duration
end
for kind = 1, 15 do
    for index = 1, kind == 1 and 25 or 2 do
        add(kind * 100 + index, string.format("Type%02d", kind), index == 1 and 1 or 9, index == 1 and 2 or 10)
    end
end
add(9001, "Raid Boss", 5, 10, true)
add(9002, "Raid Boss", 7, 10, true)
effect.percent = effect.covered / effect.duration * 100
local report = {zone = "Raid", started = 100, ended = 200, bossNames = {"Raid Boss"}, buffs = {}, debuffs = {effect}}
local groups = reports.EnemyGroups(report, effect)
assert(#groups == 17 and #effect.members == 55)
assert(groups[1].isBoss and groups[2].isBoss and groups[1].count == 1 and groups[2].count == 1,
    "Same-name bosses with different IDs must remain separate")
assert(groups[3].label == "Type01 x25" and #groups[3].members == 25)
assert(math.abs(groups[4].percent - 1000 / 12) < 0.000001, "Type uptime must be weighted by summed reference time, not average percentages")
local covered, duration = 0, 0
for _, group in ipairs(groups) do covered, duration = covered + group.covered, duration + group.duration end
assert(covered == effect.covered and duration == effect.duration, "Grouping must neither drop nor duplicate damage targets")
local legacy = reports.EnemyGroups({bossNames = {"Raid Boss"}}, {members = {
    {id = 1, name = "Raid Boss", covered = 1, duration = 2},
    {id = 2, name = "Raid Boss", covered = 1, duration = 2}}})
assert(#legacy == 2, "Historical boss names must work without new per-member flags")
reports.Init({uptimeHistory = {report}})
reports.Open(); reports.ShowZone(); reports.ShowBuffs(); reports.ChangeCategory()
assert(list.entries[1].text == "Alkosh")
assert(env.controls.LiveBuffUptimeReportName3.text == "Type01 x25")
assert(env.controls.LiveBuffUptimeReportSubtitle.text:find("55 Gegner | 17 Typen", 1, true))
assert(env.controls.LiveBuffUptimeReportTotal.text == "Debuff-Uptime  " .. string.format("%.1f", effect.percent):gsub("%.", ",") .. " %")
assert(bindings[4].visible() and bindings[5].visible() and bindings[5].name() == "Gegnertypen anzeigen")
reports.ChangePage()
assert(env.controls.LiveBuffUptimeReportName1.text == "Type11 x2", "Overview pages contain types, not raw targets")
bindings[5].callback()
assert(#list.entries == 17 and list.entries[1].text == "Raid Boss")
assert(not bindings[5].visible() and not bindings[6].visible() and not bindings[7].visible())
list:SetSelectedIndex(3)
assert(env.controls.LiveBuffUptimeReportName1.text == "Type01 #1")
assert(env.controls.LiveBuffUptimeReportCovered1.text == "1,00 s")
assert(bindings[4].visible())
reports.ChangePage()
assert(env.controls.LiveBuffUptimeReportName1.text == "Type01 #13" and list:GetSelectedIndex() == 3)
reports.ChangePage()
assert(env.controls.LiveBuffUptimeReportName1.text == "Type01 #25" and env.controls.LiveBuffUptimeReportName2.text == "")
reports.Back()
assert(#list.entries == 1 and env.controls.LiveBuffUptimeReportName1.text == "Type11 x2", "Back restores the overview page")
reports.ConfirmSelection()
assert(list:GetSelectedIndex() == 3 and env.controls.LiveBuffUptimeReportName1.text == "Type01 #25")
reports.ChangeCategory()
assert(#list.entries == 0, "Shoulder leaves detail mode and opens the independent buff category")
reports.ChangeCategory(); reports.ConfirmSelection()
assert(list:GetSelectedIndex() == 3 and env.controls.LiveBuffUptimeReportName1.text == "Type01 #25", "Category round trip restores type selection and detail page")
list:SetSelectedIndex(17)
assert(env.controls.LiveBuffUptimeReportName1.text == "Type15 #1", "All fifteen types remain reachable by stick")
assert(#effect.members == 55 and effect.members[1].name == "Type01" and effect.percent == covered / duration * 100,
    "Browsing must not mutate saved target rows or total uptime")
reports.Close()
print("Enemy types: weighted grouping, separate bosses, old data, 55 targets, 17 types, 12-row pagination and stable controller drill-down")
