-- Pure data model. No ESO API calls: also exercised by the standalone tests.
AddKillCounter = AddKillCounter or {}
local C = {}
AddKillCounter.Core = C

function C.NewStats()
    return {total = 0, days = {}}
end

-- Drop legacy detail records without changing accumulated totals.
function C.RemoveDetails(stats)
    stats.log = nil
    stats.enemies = nil
    for _, day in pairs(stats.days) do day.enemies = nil end
end

function C.Record(stats, dayKey, time)
    stats.total = stats.total + 1
    local day = stats.days[dayKey]
    if not day then
        day = {total = 0, firstTime = time, lastTime = time}
        stats.days[dayKey] = day
    end
    day.total = day.total + 1
    day.lastTime = time
end

function C.GetDays(stats)
    local days = {}
    for day in pairs(stats.days) do days[#days + 1] = day end
    table.sort(days, function(a, b) return a > b end)
    return days
end

function C.DeleteDay(stats, day)
    if not stats.days[day] then return false end
    stats.days[day] = nil
    return true
end

-- Runtime identity state is deliberately NOT saved between sessions/zones.
function C.NewTracker()
    return {seen = {}, dead = {}, nextSweep = 0, unknown = 0}
end

function C.Sweep(tracker, now)
    if now < tracker.nextSweep then return end
    tracker.nextSweep = now + 10
    for id, row in pairs(tracker.seen) do
        if now - row.at > 120 then tracker.seen[id] = nil end
    end
    for id, at in pairs(tracker.dead) do
        if now - at > 120 then tracker.dead[id] = nil end
    end
end

-- Only a damaging hit on a known unit provides a reliable fallback name.
function C.Observe(tracker, id, name, now)
    if not id or id == 0 or not name or name == "" then return end
    tracker.seen[id] = {name = name, at = now}
end

function C.ResolveDeath(tracker, id, name, now)
    C.Sweep(tracker, now)
    -- Without an identity there is no safe way to deduplicate the two death events.
    if not id or id == 0 then
        tracker.unknown = tracker.unknown + 1
        return nil
    end
    if tracker.dead[id] then return nil end
    local seen = tracker.seen[id]
    if (not name or name == "") and seen and now - seen.at <= 120 then name = seen.name end
    if not name or name == "" then
        tracker.unknown = tracker.unknown + 1
        return nil
    end
    tracker.dead[id] = now
    tracker.seen[id] = nil
    return name
end

function C.FormatDate(day)
    return string.format("%s.%s.%s", day:sub(7, 8), day:sub(5, 6), day:sub(1, 4))
end
