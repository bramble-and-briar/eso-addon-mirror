local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local function record(zone)
    return { zone = zone, started = 0, ended = 10, buffs = {
        { id = 61771, name = "Buff", unit = "player", percent = 50, covered = 5, duration = 10,
            members = {{name = "Spieler", covered = 5, duration = 10}} }
    } }
end
local a, b, c = record("Schnittermark"), record("Glattbachhaus"), record("Schnittermark")
local saved = { uptimeHistory = {a, b, c}, lastUptimeReport = a }
reports.Init(saved)
local bindings, definition, shown
KEYBIND_STRIP = { AddKeybindButtonGroup = function(_, group) bindings = group end,
    RemoveKeybindButtonGroup = function() end }
GAMEPAD_DIALOGS = { BASIC = 1 }
SI_DIALOG_CANCEL = "Abbrechen"
ZO_Dialogs_RegisterCustomDialog = function(_, dialog) definition = dialog end
ZO_Dialogs_ShowGamepadDialog = function(_, data) shown = {data = data} end
reports.Open()
assert(bindings[6].visible())
bindings[6].callback()
assert(#saved.uptimeHistory == 3 and #shown.data.records == 2)
assert(definition.title.text(shown) == "Gebiet loeschen?")
assert(definition.mainText.text(shown):find("Schnittermark (Datum unbekannt): 2", 1, true))
assert(not list.active and env.controls.LiveBuffUptimeReportWindow.hidden)
reports.SelectZone("name:Glattbachhaus")
reports.Back()
assert(shown.data.records[1] == a and not list.active)
definition.finishedCallback(shown)
assert(#saved.uptimeHistory == 3 and list.active, "Cancel must keep all records")
bindings[6].callback()
local new = record("Schnittermark")
reports.Save(new)
definition.buttons[1].callback(shown)
assert(#saved.uptimeHistory == 2 and saved.uptimeHistory[1] == new and saved.uptimeHistory[2] == b,
    "Delete only the confirmed area's snapshot, never another area or a newly arriving fight")
assert(saved.lastUptimeReport == new and not list.active)
definition.finishedCallback(shown)
assert(list.active and #list.entries == 2)
list:SetSelectedIndex(2)
bindings[6].callback()
assert(#shown.data.records == 1 and shown.data.records[1] == b)
definition.buttons[1].callback(shown)
definition.finishedCallback(shown)
assert(#saved.uptimeHistory == 1 and list.entries[1].zoneKey == "name:Schnittermark")
bindings[6].callback()
definition.buttons[1].callback(shown)
definition.finishedCallback(shown)
assert(#saved.uptimeHistory == 0 and saved.lastUptimeReport == nil and not bindings[6].visible())
reports.Close()
print("Zone deletion: R3, selected area/count, confirmation, locked navigation, cancellation, new records and last-report alias passed")
