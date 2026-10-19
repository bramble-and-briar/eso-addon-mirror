local env = dofile("tests/addon.lua")
local reports = LiveBuffUptimeReports
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local saved = {uptimeHistory = {}}
reports.Init(saved)
local tracker = {config = {id = 61506, unit = "player"}, displayPercent = 50,
    state = {since = 100, intervals = {{100, 110}}}}
local function event(slot, change, starts, time, ends)
    reports.RecordBuffReceipt(61506, "player", slot, change, starts, time, ends)
end
local function finish()
    reports.CaptureFallback({tracker}, 100, 120, 20, false, function() return "Elan" end, {}, function() return false end)
    return saved.lastUptimeReport.buffs[1]
end
reports.BeginEncounter(100, true, "player")
event(1, 1, 101, 101, 111)
event(2, 2, 103, 103, 113)
event(2, 2, 103, 103.01, 113) -- Duplicate update.
event(2, 1, 103, 103.02, 113) -- Mirrored gain for the same application.
event(3, 2, 105, 105, 115)
event(4, 2, 107, 107, 117)
event(5, 2, 107, 107.01, 117) -- New slot, but no extension: not another renewal.
local buff = finish()
assert(buff.members[1].received == 1 and buff.members[1].renewed == 3,
    "Four confirmed applications with changing slots must count as one receipt and three renewals")
assert(buff.covered == 10 and buff.duration == 20 and buff.percent == 50)
reports.BeginEncounter(200, true, "player")
event(1, 1, 201, 201, 211)
event(1, 2, 201, 202, 0) -- Missing expiry must not discard the known application.
event(1, 2, 201, 202.1, nil)
event(1, 2, 201, 202.2, 199) -- Stale expiry must not either.
event(1, 2, 203, 203, 213)
event(1, 2, 203, 204, 0)
event(1, 2, 205, 205, 215)
event(1, 2, 205, 206, 0)
event(1, 2, 207, 207, 217)
reports.CaptureFallback({tracker}, 200, 220, 20, false, function() return "Elan" end, {}, function() return false end)
local nextBuff = saved.lastUptimeReport.buffs[1]
assert(nextBuff.members[1].received == 1 and nextBuff.members[1].renewed == 3,
    "Missing expiry notifications between casts must not suppress later real renewals")
assert(buff.members[1].renewed == 3, "Later fights must not modify earlier counters")
print("Renewal counters: changing slots, duplicate notifications, missing/stale expiry, four applications and independent uptime passed")
