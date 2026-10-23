local env = dofile("tests/addon.lua")
local reports = LiveBuffUptimeReports
local saved = {uptimeHistory = {}}
reports.Init(saved)
COMBAT_UNIT_TYPE_PLAYER = 1
reports.BeginEncounter(100, true, "player")
reports.RecordDamage(1, 4, 99, "Uebungsskelett", 100)
reports.RecordDebuff(34384, 99, "Uebungsskelett", 1, 102, 107, true)
reports.RecordDebuff(34384, 99, "Uebungsskelett", 2, 104, 110, true)
local live = assert(reports.DebuffResult(34384, 99, 100, 106))
assert(live.covered == 4 and live.duration == 6)
local final = assert(reports.DebuffResult(34384, 99, 100, 112))
assert(final.covered == 8 and final.duration == 12)
assert(reports.DebuffResult(34384, 100, 100, 112) == nil, "Never substitute another enemy with the same buff")
local enemy = {config = {id = 34384, unit = "reticleover"}}
reports.CaptureFallback({enemy}, 100, 112, 12, false, function() return "Morag Tong" end, {}, function() return false end)
local debuff = assert(saved.lastUptimeReport.debuffs[1])
assert(debuff.covered == final.covered and debuff.duration == final.duration and debuff.percent == final.percent,
    "HUD and report must share the same slot union, expiry, numerator and denominator")
local repeatRead = reports.DebuffResult(34384, 99, 100, 112)
assert(repeatRead.covered == 8 and repeatRead.percent == final.percent, "Repeated HUD reads must not duplicate closed intervals")
reports.BeginEncounter(200, true, "player")
assert(reports.DebuffResult(34384, 99, 200, 202) == nil, "The new fight must not inherit expired enemy data")
print("Shared debuff window: overlapping slots, finite expiry, exact HUD/report agreement, target isolation and next-fight reset passed")
