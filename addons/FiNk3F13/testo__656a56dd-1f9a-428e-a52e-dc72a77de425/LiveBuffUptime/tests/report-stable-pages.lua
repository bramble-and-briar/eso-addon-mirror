local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local clears, snaps = 0, 0
local clear = list.Clear
function list:Clear() clears = clears + 1; clear(self) end
function list:SetSelectedIndexWithoutAnimation(index, allowDisabled)
    assert(allowDisabled)
    snaps = snaps + 1
    self:SetSelectedIndex(index)
end
local function record(zone)
    local report = {zone = zone, started = 0, ended = 10, buffs = {}, debuffs = {}}
    for index = 1, 10 do
        for _, category in ipairs({"buffs", "debuffs"}) do
            report[category][index] = {id = index, name = category .. index, unit = "player",
                covered = 5, duration = 10, percent = 50, members = {}}
            for member = 1, 24 do
                report[category][index].members[member] = {name = tostring(member), covered = 5, duration = 10}
            end
        end
    end
    return report
end
local first, second = record("Gebiet A"), record("Gebiet B")
reports.Init({uptimeHistory = {first, second}, lastUptimeReport = first})
reports.Open()
local initial = clears
list:SetSelectedIndex(2)
assert(clears == initial and list.index == 2, "Selecting another area must not rebuild the area list")
reports.ShowZone()
reports.ShowBuffs()
list:SetSelectedIndex(5)
local before = clears
reports.ChangePage()
assert(clears == before and env.controls.LiveBuffUptimeReportName1.text == "13",
    "Changing the player page must not rebuild or scroll the effect list")
reports.ChangeCategory()
list:SetSelectedIndex(7)
reports.ChangeCategory()
assert(list.index == 5 and env.controls.LiveBuffUptimeReportName1.text == "13",
    "Returning to buffs must restore both the selected effect and player page")
reports.ChangeCategory()
assert(list.index == 7, "Debuffs must retain their own selection")
reports.Back()
reports.ShowBuffs()
assert(list.index == 7, "Returning from the fight list must preserve the effect selection")
before = clears
reports.Refresh()
assert(clears == before, "A details refresh must not recreate the left list")
assert(snaps > 0, "List rebuilds must restore selection without animated scrolling")
reports.Close()
print("Stable pages: no area-selection rebuild, independent buff/debuff selection, player-page retention, back navigation and unanimated restoration passed")
