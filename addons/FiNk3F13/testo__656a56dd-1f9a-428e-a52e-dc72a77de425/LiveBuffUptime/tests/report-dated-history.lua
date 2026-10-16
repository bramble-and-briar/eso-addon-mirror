local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local saved = {uptimeHistory = {}}
reports.Init(saved)
local function record(date, time)
    return {zone = "Test-Raid", zoneId = 123, date = date, clock = time,
        started = 0, ended = 10, buffs = {{id = 61771, name = "Buff", unit = "player",
            covered = 5, duration = 10, percent = 50,
            members = {{name = "Spieler", covered = 5, duration = 10}}}}}
end
local old = record("20261013", "20:00:00")
reports.Save(old)
for index = 1, 50 do reports.Save(record("20261014", "21:00:00")) end
assert(#saved.uptimeHistory == 51 and saved.uptimeHistory[51] == old,
    "A 50-fight raid must retain its first fight and earlier days")
local bindings, definition, shown
KEYBIND_STRIP = {AddKeybindButtonGroup = function(_, group) bindings = group end,
    RemoveKeybindButtonGroup = function() end}
GAMEPAD_DIALOGS, SI_DIALOG_CANCEL = {BASIC = 1}, "Abbrechen"
ZO_Dialogs_RegisterCustomDialog = function(_, dialog) definition = dialog end
ZO_Dialogs_ShowGamepadDialog = function(_, data) shown = {data = data} end
reports.Open()
assert(#list.entries == 2 and list.entries[1].text == "Test-Raid" and list.entries[2].text == "Test-Raid")
assert(list.entries[1].subtitle == "14.10.2026 | 50 Kaempfe")
assert(list.entries[2].subtitle == "13.10.2026 | 1 Kampf")
reports.ShowZone()
assert(#list.entries == 50 and list.entries[1].subtitle:find("14.10.2026  21:00:00", 1, true))
reports.Back()
bindings[6].callback()
assert(#shown.data.records == 50 and definition.mainText.text(shown):find("14.10.2026", 1, true))
definition.buttons[1].callback(shown)
definition.finishedCallback(shown)
assert(#saved.uptimeHistory == 1 and saved.uptimeHistory[1] == old,
    "Deleting a dated raid list must preserve the same raid on another day")
assert(list.entries[1].subtitle == "13.10.2026 | 1 Kampf")
reports.Close()
reports.Init(saved)
assert(saved.uptimeHistory[1].date == "20261013", "Reload must retain the original date")
print("Dated history: 50-fight raid retention, same-area day separation, dates/times, scoped confirmation/deletion and reload passed")
