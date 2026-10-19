local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local function record(date)
    return {zone = "Raid", zoneId = 123, date = date, started = 0, ended = 10,
        buffs = {{id = 61771, name = "Buff", unit = "player", covered = 5, duration = 10, percent = 50, members = {}}}}
end
local saved = {uptimeHistory = {}}
for index = 1, 30 do saved.uptimeHistory[index] = record("20261018") end
local otherDay = record("20261017")
saved.uptimeHistory[31] = otherDay
reports.Init(saved)
local bindings
KEYBIND_STRIP = {AddKeybindButtonGroup = function(_, group) bindings = group end, RemoveKeybindButtonGroup = function() end}
reports.Open()
assert(#list.entries == 2 and list.index == 1)
assert(list.entries[1].subtitle:find("30 Kaempfe", 1, true))
assert(bindings[7].visible() and bindings[7].name() == "Sperren")
bindings[7].callback()
for index = 1, 30 do assert(saved.uptimeHistory[index].locked) end
assert(not otherDay.locked, "Area locking must not affect another day of the same raid")
assert(list.index == 1 and list.entries[1].locked)
assert(list.entries[1].text:find("locked_up.dds|t", 1, true), "A locked entry must show a lock icon after its name")
assert(list.entries[1].text:find("Raid", 1, true) == 1)
assert(bindings[7].name() == "Entsperren" and not bindings[6].enabled())
reports.ShowZone()
assert(list.entries[1].text:find("locked_up.dds|t", 1, true), "Individual fights must use the same lock marker")
list:SetSelectedIndex(12)
bindings[7].callback()
assert(not saved.uptimeHistory[12].locked and saved.uptimeHistory[11].locked)
reports.Back()
assert(not list.entries[1].locked and not list.entries[1].text:find("locked_up.dds|t", 1, true))
assert(list.entries[1].subtitle:find("29 gesperrt", 1, true) and bindings[7].name() == "Sperren")
bindings[7].callback()
assert(saved.uptimeHistory[12].locked and list.entries[1].locked)
reports.Close()
reports.Init(saved)
reports.Open()
assert(list.entries[1].locked and list.entries[1].text:find("locked_up.dds|t", 1, true))
bindings[7].callback()
for index = 1, 30 do assert(not saved.uptimeHistory[index].locked) end
assert(not otherDay.locked and bindings[6].enabled())
list:SetSelectedIndex(2)
bindings[7].callback()
assert(otherDay.locked and list.index == 2 and list.entries[2].locked)
for index = 1, 30 do assert(not saved.uptimeHistory[index].locked) end
reports.Close()
print("Zone locks: first-page controller action, 30-fight batch, day isolation, shared lock icon, partial states, stable selection and persistence passed")
