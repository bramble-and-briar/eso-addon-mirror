local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
function zo_strformat(_, name) return name:gsub("%^.*$", "") end
function GetUnitZone() return "Testverlies^nd,in" end
function GetUnitZoneIndex() return 10 end
function GetZoneId(index) return index == 10 and 100 or 200 end
function GetParentZoneId() return 200 end
function GetZoneIndex(id) return id == 200 and 20 or 10 end
function GetNumPOIs(index) return index == 20 and 1 or 0 end
function GetPOIInfo() return "Testverlies^nd,in" end
local poiReads = 0
function GetPOIMapInfo()
    poiReads = poiReads + 1
    return 0.4, 0.5, 1, "EsoUI/Art/MapPins/test_dungeon.dds"
end
local saved = { uptimeHistory = {} }
reports.Init(saved)
local record = { started = 0, ended = 10, buffs = { { id = 61771, name = "Buff", unit = "group",
    covered = 30, duration = 30, percent = 100, members = {
        { account = "PSN-DD", name = "Charakter DD", role = LFG_ROLE_DPS, covered = 10, duration = 10 },
        { account = "PSN-Tank", name = "Charakter Tank", role = LFG_ROLE_TANK, covered = 10, duration = 10 },
        { account = "PSN-Heiler", name = "Charakter Heiler", role = LFG_ROLE_HEAL, covered = 10, duration = 10 },
    } } } }
reports.Save(record)
assert(record.placeIcon == "EsoUI/Art/MapPins/test_dungeon.dds" and record.zoneId == 100)
reports.Open()
assert(list.entries[1].icon == record.placeIcon and list.entries[1].icon ~= GetAbilityIcon(61771))
assert(env.controls.LiveBuffUptimeReportRole1.text == "DD")
assert(env.controls.LiveBuffUptimeReportRole2.text == "Tank")
assert(env.controls.LiveBuffUptimeReportRole3.text == "Heiler")
assert(env.controls.LiveBuffUptimeReportRoleIcon1.texture == "EsoUI/Art/LFG/Gamepad/lfg_roleicon_dps.dds")
assert(env.controls.LiveBuffUptimeReportRoleIcon2.texture == "EsoUI/Art/LFG/Gamepad/lfg_roleicon_tank.dds")
assert(env.controls.LiveBuffUptimeReportRoleIcon3.texture == "EsoUI/Art/LFG/Gamepad/lfg_roleicon_healer.dds")
assert(not env.controls.LiveBuffUptimeReportRoleIcon1.hidden)
assert(env.controls.LiveBuffUptimeReportRoleIcon1.x + 32 < env.controls.LiveBuffUptimeReportName1.x)
assert(env.controls.LiveBuffUptimeReportName1.text == "PSN-DD" and not env.controls.LiveBuffUptimeReportCharacter1)
-- Changing the current role or map must not relabel an old fight.
function GetSelectedLFGRole() return LFG_ROLE_HEAL end
function GetUnitZone() return "Anderes Gebiet" end
reports.Refresh()
assert(env.controls.LiveBuffUptimeReportRole1.text == "DD" and list.entries[1].icon == record.placeIcon)
reports.Close()
local old = { started = 0, ended = 10, zone = "Altes Gebiet", buffs = record.buffs }
old.buffs[1].members[1].role = nil
reports.Init({ uptimeHistory = { old } })
reports.Open()
assert(list.entries[1].icon == "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_zoneStories.dds")
assert(env.controls.LiveBuffUptimeReportRole1.text == "-", "Old unknown roles must not be guessed from the player's current role")
assert(env.controls.LiveBuffUptimeReportRoleIcon1.hidden, "Unknown historical roles must not display a guessed icon")
reports.Close()
assert(poiReads == 1, "POI lookup belongs to capture, not each menu refresh")
print("Report roles/places: role labels, no character subline, POI icon, stored location, immutable roles and old-report fallback passed")
