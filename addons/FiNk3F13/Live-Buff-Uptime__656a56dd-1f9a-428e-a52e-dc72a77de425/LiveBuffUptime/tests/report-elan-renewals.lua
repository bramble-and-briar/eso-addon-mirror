local env = dofile("tests/addon.lua")
local reports = LiveBuffUptimeReports
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local saved = {uptimeHistory = {}}
reports.Init(saved)
local tracker = { config = {id = 61506, unit = "player"}, displayPercent = 50,
    state = {since = 100, intervals = {{100, 110}}} }
reports.BeginEncounter(100, true, "player")
local function event(slot, change, starts, time, ends)
    reports.RecordBuffReceipt(61506, "player", slot, change, starts, time, ends)
end
event(1, 1, 101, 101, 110)
event(1, 1, 102, 102, 112) -- Eight seconds remaining: recast reported as GAINED.
event(1, 1, 102, 102.01, 112) -- Same delivery repeated.
event(2, 1, 104, 104, 114) -- Another slot while the effect is already active.
event(1, 3, 102, 105, 112)
event(2, 3, 104, 105, 114)
event(2, 1, 105.02, 105.02, 115) -- Replacement, not natural expiry.
event(2, 3, 105.02, 115, 115)
event(2, 1, 115.02, 115.02, 125) -- Truly expired: a new receipt.
event(2, 2, 116, 116, 130)
event(2, 2, 116, 116.01, 130)
event(2, 1, 116, 116.02, 130) -- GAINED mirroring the same UPDATED application.
reports.CaptureFallback({tracker}, 100, 120, 20, false, function() return "Elan" end, {}, function() return false end)
local buff = saved.lastUptimeReport.buffs[1]
assert(buff.members[1].received == 2 and buff.members[1].renewed == 4,
    "Elan recasts must renew despite GAINED, changed slots or immediate replacement; duplicates must not count")
assert(buff.covered == 10 and buff.duration == 20 and buff.percent == 50,
    "Receipt classification must remain entirely separate from uptime math")
reports.BeginEncounter(200, true, "player")
event(1, 1, 201, 201, 210)
reports.CaptureFallback({tracker}, 200, 220, 20, false, function() return "Elan" end, {}, function() return false end)
local nextBuff = saved.lastUptimeReport.buffs[1]
assert(nextBuff.members[1].received == 1 and nextBuff.members[1].renewed == 0)
assert(buff.members[1].renewed == 4, "A new fight must not change old counters")
print("Elan renewals: GAINED recasts, changed slots, replacement bursts, true expiry, duplicate updates and independent uptime passed")
