local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local bindings
KEYBIND_STRIP = { AddKeybindButtonGroup = function(_, group) bindings = group end,
    RemoveKeybindButtonGroup = function() end }
COMBAT_UNIT_TYPE_PLAYER = COMBAT_UNIT_TYPE_PLAYER or 1
reports.BeginEncounter(100, true, "player")
reports.RecordDamage(COMBAT_UNIT_TYPE_PLAYER, 999, 900, "Boss", 100)
reports.RecordDebuff(39077, 900, "Boss", 1, 102, 105, true)
reports.RecordDebuff(39077, 900, "Boss", 2, 104, 108, true)
reports.RecordDebuff(39077, 900, "Boss", 1, 106, 105, false)
reports.RecordDebuff(39077, 901, "Nicht angegriffen", 1, 100, 110, true)
local tracker = { config = { id = 61771, unit = "group" }, displayPercent = 25,
    group = { members = {} } }
local enemyTracker = { config = { id = 39077, unit = "reticleover" } }
reports.CaptureFallback({tracker, enemyTracker}, 100, 110, 10, false, function() return "Buff" end, {}, function() return false end)
local report = env.saved().lastUptimeReport
assert(#report.debuffs == 1 and #report.debuffs[1].members == 1)
local debuff = report.debuffs[1]
assert(debuff.covered == 6 and debuff.duration == 10 and debuff.percent == 60,
    "Overlapping slots must be unioned and expired at ESO's end timestamp")
assert(report.buffs[1].percent == 25, "Debuff reports must not alter existing buff percentages")
reports.Open()
assert(not bindings[2].visible())
reports.ShowZone()
reports.ShowBuffs()
assert(bindings[2].visible() and bindings[3].visible())
assert(bindings[2].name() == "Debuff-Uptime")
assert(env.controls.LiveBuffUptimeReportPage.text == "Seite 1 / 2")
assert(bindings[4].keybind ~= "UI_SHORTCUT_SECONDARY", "X must no longer change statistic pages")
bindings[2].callback()
assert(env.controls.LiveBuffUptimeReportPage.text == "Seite 2 / 2")
assert(list.entries[1].text == debuff.name or list.entries[1].name == debuff.name)
assert(env.controls.LiveBuffUptimeReportTotal.text == "Debuff-Uptime  60,0 %")
assert(env.controls.LiveBuffUptimeReportName1.text == "Boss")
assert(env.controls.LiveBuffUptimeReportRoleIcon1.hidden)
assert(env.controls.LiveBuffUptimeReportRole1.text == "")
assert(env.controls.LiveBuffUptimeReportDeaths1.text == "")
bindings[3].callback()
assert(env.controls.LiveBuffUptimeReportPage.text == "Seite 1 / 2")
assert(env.controls.LiveBuffUptimeReportTotal.text == "Gruppen-Uptime  25,0 %")
-- Historical fights without recorded debuffs must show an empty page, not buff data.
report.debuffs = nil
bindings[2].callback()
assert(#list.entries == 0 and env.controls.LiveBuffUptimeReportName1.text == "")
assert(env.controls.LiveBuffUptimeReportBuff.text == "Keine aufgezeichneten Effekte")
reports.Close()
-- Pre-combat effects are clipped to this fight; renewals do not double-count.
reports.BeginEncounter(200, false, "player")
reports.RecordDebuff(39077, 900, "Boss", 1, 201, 208, true)
reports.BeginEncounter(203, true, "player")
reports.RecordDamage(COMBAT_UNIT_TYPE_PLAYER, 999, 900, "Boss", 100)
reports.RecordDebuff(39077, 900, "Boss", 1, 205, 210, true)
reports.CaptureFallback({tracker, enemyTracker}, 203, 213, 10, false, function() return "Buff" end, {}, function() return false end)
assert(env.saved().lastUptimeReport.debuffs[1].covered == 7)
assert(report.buffs[1].percent == 25, "The previous fight must stay frozen")
-- Exercise the addon's ESO hook: only a configured debuff on a hostile enemy enters the report.
BUFF_EFFECT_TYPE_DEBUFF, UNIT_REACTION_HOSTILE = 2, 3
GetUnitReaction = function(tag) return tag == "reticleover" and 3 or 1 end
local original = reports.RecordDebuff
local recorded = {}
reports.RecordDebuff = function(...) recorded[#recorded + 1] = {...}; return original(...) end
local function raw(tag, ability, effectType)
    env.setClock(300)
    env.rawEvents[EVENT_EFFECT_CHANGED](nil, EFFECT_RESULT_GAINED, 4, "", tag, 300, 310,
        1, "icon", 0, effectType, 0, 0, "Boss", 900, ability, 3)
end
raw("reticleover", 61771, 2)
raw("player", 61771, 2)
raw("reticleover", 61771, 1)
raw("reticleover", 999999, 2)
assert(#recorded == 1 and recorded[1][1] == 61771 and recorded[1][2] == 900)
reports.RecordDebuff = original
print("Debuff pages: independent enemy scopes, expiry, prebuffs, category shoulders, stick list, old reports and unchanged buff totals passed")
