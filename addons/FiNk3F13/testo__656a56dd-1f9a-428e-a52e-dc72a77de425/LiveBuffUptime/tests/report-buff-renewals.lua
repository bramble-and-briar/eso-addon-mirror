local env = dofile("tests/addon.lua")
local reports = LiveBuffUptimeReports
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local saved = {uptimeHistory = {}}
reports.Init(saved)
local tracker = { config = {id = 61771, unit = "player"}, displayPercent = 50,
    state = { since = 100, intervals = {{100, 105}} } }
reports.BeginEncounter(99, false, "player")
reports.RecordBuffReceipt(61771, "player", 1, 1, 99, 99, 110)
reports.BeginEncounter(100, true, "player")
reports.RecordBuffReceipt(61771, "player", 1, 2, 101, 101, 115)
reports.RecordBuffReceipt(61771, "player", 1, 2, 101, 102, 115)
reports.RecordBuffReceipt(61771, "player", 1, 2, 101, 103, 114)
reports.RecordBuffReceipt(61771, "player", 1, 2, 104, 104, 120)
reports.RecordBuffReceipt(61771, "player", 1, 3, 104, 105, 120)
reports.RecordBuffReceipt(61771, "player", 1, 2, 106, 106, 125)
reports.RecordBuffReceipt(61771, "player", 1, 2, 126, 126, 130)
reports.CaptureFallback({tracker}, 100, 110, 10, false, function() return "Buff" end, {}, function() return false end)
local report = saved.lastUptimeReport
assert(report.buffs[1].members[1].received == 0, "The precombat gain is not a new combat receipt")
assert(report.buffs[1].members[1].renewed == 2,
    "Only extensions while previously active count; duplicates, stack updates, fades and unknown state do not")
assert(report.buffs[1].percent == 50 and report.buffs[1].covered == 5 and report.buffs[1].duration == 10,
    "Renewal metadata must not affect any uptime inputs or outputs")
local file = assert(io.open("LiveBuffUptime.addon", "r"))
local manifest = file:read("*a"); file:close()
assert(manifest:find("## Version: 2.0.1", 1, true))
print("Renewals: active extensions, duplicate updates, prebuff, unknown/expired slots, report window and release version passed")
