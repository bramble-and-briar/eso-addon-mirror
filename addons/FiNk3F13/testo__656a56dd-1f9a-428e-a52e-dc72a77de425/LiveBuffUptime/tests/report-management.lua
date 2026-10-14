local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local function record(name)
    return { zone = name, clock = "12:34:56", started = 0, ended = 10,
        buffs = { { id = 61771, name = "Buff", unit = "player", covered = 5, duration = 10, percent = 50,
            members = { { name = "Spieler", covered = 5, duration = 10 } } } } }
end
local first, second, third = record("Gebiet A"), record("Gebiet B"), record("Glattbachhaus^nd,in")
local saved = { uptimeHistory = { first, second, third }, lastUptimeReport = first }
reports.Init(saved)
function zo_strformat(format, text)
    assert(format == "<<C:1>>" or format == "<<1>>")
    return text:gsub("%^.*$", "")
end
local bindings
KEYBIND_STRIP = { AddKeybindButtonGroup = function(_, group) bindings = group end,
    RemoveKeybindButtonGroup = function() end }
GAMEPAD_DIALOGS = { BASIC = 1 }
SI_DIALOG_CANCEL = "Abbrechen"
local dialogs, shown = {}, nil
function ZO_Dialogs_RegisterCustomDialog(name, info) dialogs[name] = info end
function ZO_Dialogs_ShowGamepadDialog(name, data) shown = { name = name, data = data } end
reports.Open()
list:SetSelectedIndex(3)
assert(list.entries[3].text == "Glattbachhaus" and not env.controls.LiveBuffUptimeReportSubtitle.text:find("%^"))
reports.ShowBuffs()
assert(not bindings[6].visible(), "Delete action must be hidden inside the buff view")
bindings[6].callback()
assert(shown == nil and #saved.uptimeHistory == 3, "R3 must not open deletion from the buff view")
reports.Back()
assert(bindings[6].visible(), "Delete action must return in the fight list")
assert(list.index == 1 and list.entries[1].fightIndex == 3, "Returning from buffs must keep the chosen fight within its area")
reports.Close()
reports.Open()
assert(list.index == 3, "Reopening must not jump to the newest fight")
reports.Close()
reports.Save(record("Neuer Kampf"))
reports.Open()
assert(list.index == 4 and saved.uptimeHistory[4] == third, "New fights while closed must preserve the chosen report")
reports.ShowZone()
bindings[6].callback()
assert(#saved.uptimeHistory == 4 and shown.data.report == third, "R3 must only request confirmation")
local dialog = dialogs[shown.name]
assert(not list.active and env.controls.LiveBuffUptimeReportWindow.hidden and env.controls.LiveBuffUptimeReportDetails.hidden,
    "Confirmation must hide the underlying list/details and deactivate controller navigation")
reports.SelectFight(1)
reports.ChangeFight(1)
reports.ChangeBuff(1)
reports.ShowBuffs()
reports.Back()
assert(not list.active and env.controls.LiveBuffUptimeReportWindow.hidden, "Background actions must be blocked while confirming")
assert(dialog.mainText.text(shown):find("Glattbachhaus", 1, true))
assert(dialog.buttons[2].text == "Abbrechen")
dialog.finishedCallback(shown)
assert(#saved.uptimeHistory == 4 and list.index == 1 and list.entries[1].fightIndex == 4 and list.active,
    "Cancel must restore the exact selected fight without deleting anything")
assert(not env.controls.LiveBuffUptimeReportWindow.hidden and not env.controls.LiveBuffUptimeReportDetails.hidden)
bindings[6].callback()
assert(not list.active and shown.data.report == third)
-- A new fight arriving during confirmation must not change the deletion target.
reports.Save(record("Noch neuer"))
assert(#saved.uptimeHistory == 5)
dialog.buttons[1].callback(shown)
assert(#saved.uptimeHistory == 4 and saved.lastUptimeReport == saved.uptimeHistory[1])
assert(not list.active, "Background must stay inactive until the confirmation actually closes")
dialog.finishedCallback(shown)
assert(list.active and not env.controls.LiveBuffUptimeReportWindow.hidden)
for _, report in ipairs(saved.uptimeHistory) do assert(report ~= third) end
while #saved.uptimeHistory > 0 do reports.DeleteFight(saved.uptimeHistory[1]) end
assert(saved.lastUptimeReport == nil and not bindings[6].visible())
reports.Init(saved)
assert(#saved.uptimeHistory == 0, "Deleted reports must not be restored from the last-report alias")
reports.Close()
print("Report management: R3 confirmation, cancellation, identity-safe deletion, empty history, persistent focus and native name formatting passed")
