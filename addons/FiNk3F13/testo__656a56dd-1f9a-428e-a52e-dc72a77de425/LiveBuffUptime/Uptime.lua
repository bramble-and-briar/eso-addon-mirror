LiveBuffUptimeMeter = {}
local Meter = LiveBuffUptimeMeter

function Meter.New(now)
    return { since = now, sampledAt = now, active = false, expires = 0, total = 0, intervals = {} }
end

local function record(state, starts, ends)
    if ends <= starts then return end
    local previous = state.intervals[#state.intervals]
    if previous and starts <= previous[2] then
        state.total = state.total + math.max(0, ends - previous[2])
        previous[2] = math.max(previous[2], ends)
        previous[3] = state.total
    else
        state.total = state.total + ends - starts
        state.intervals[#state.intervals + 1] = { starts, ends, state.total }
    end
end

function Meter.Advance(state, now, counting)
    if counting and state.active then
        local stop = state.expires == 0 and now or math.min(now, state.expires)
        record(state, state.sampledAt, stop)
    end
    state.sampledAt = now
end

function Meter.Observe(state, effect, now, counting, allowBackfill)
    local previousSample = state.sampledAt
    local coveredUntil = previousSample
    if state.active then
        coveredUntil = state.expires == 0 and now or math.max(previousSample, math.min(now, state.expires))
    end
    Meter.Advance(state, now, counting)
    state.active = effect ~= nil
    state.expires = effect and effect.ends or 0
    -- An event may arrive between UI ticks; include its actual start time.
    if counting and effect and allowBackfill then
        local start = math.max(state.since, coveredUntil, effect.starts or now)
        record(state, start, now)
    end
end

function Meter.IntervalTotal(intervals, starts, ends)
    if ends <= starts then return 0 end
    if #intervals > 0 and intervals[#intervals][3] then
        -- Recorded intervals carry cumulative totals; two searches avoid rescanning a long fight.
        local function coveredUntil(time)
            local low, high, found = 1, #intervals, 0
            while low <= high do
                local index = math.floor((low + high) / 2)
                if intervals[index][1] < time then
                    found, low = index, index + 1
                else
                    high = index - 1
                end
            end
            if found == 0 then return 0 end
            local interval = intervals[found]
            local previous = found > 1 and intervals[found - 1][3] or 0
            return previous + math.max(0, math.min(time, interval[2]) - interval[1])
        end
        return math.max(0, coveredUntil(ends) - coveredUntil(starts))
    end
    local total = 0
    for _, interval in ipairs(intervals) do
        total = total + math.max(0, math.min(ends, interval[2]) - math.max(starts, interval[1]))
    end
    return total
end

function Meter.Percent(state, now, starts, duration)
    starts = math.max(state.since, starts or state.since)
    duration = duration or math.max(1, now - starts)
    if duration <= 0 then return 0 end
    return math.min(100, math.max(0, Meter.IntervalTotal(state.intervals, starts, now) / duration * 100))
end

function Meter.ExcludedTotal(intervals, excluded, starts, now)
    local excludedTime = 0
    local activeIndex = 1
    for _, interval in ipairs(excluded.intervals) do
        local first, last = math.max(starts, interval[1]), math.min(now, interval[2])
        if last > first then
            -- Active effect time remains eligible even if immunity overlaps it.
            while intervals[activeIndex] and intervals[activeIndex][2] <= first do
                activeIndex = activeIndex + 1
            end
            local overlap, index = 0, activeIndex
            while intervals[index] and intervals[index][1] < last do
                local interval = intervals[index]
                overlap = overlap + math.max(0, math.min(last, interval[2]) - math.max(first, interval[1]))
                index = index + 1
            end
            excludedTime = excludedTime + last - first - overlap
        end
    end
    return excludedTime
end

function Meter.PercentExcluding(state, excluded, now, starts, duration)
    starts = math.max(state.since, starts or state.since)
    local eligibleTime = math.max(1, (duration or (now - starts)) - Meter.ExcludedTotal(state.intervals, excluded, starts, now))
    return Meter.Percent(state, now, starts, eligibleTime)
end

function Meter.NewScope()
    return { slots = {}, count = 0, intervals = {}, events = {} }
end

function Meter.ScopeEvent(scope, slot, time, active, replay)
    if not replay then
        scope.events[#scope.events + 1] = { slot = slot, time = time, active = active, seq = #scope.events + 1 }
        if scope.lastEventTime and time < scope.lastEventTime then
            -- Late callbacks must correct live values as well as the final result.
            local rebuilt = Meter.RebuildScope(scope)
            scope.slots, scope.count, scope.starts = rebuilt.slots, rebuilt.count, rebuilt.starts
            scope.intervals, scope.lastEventTime = rebuilt.intervals, rebuilt.lastEventTime
            return
        end
    end
    scope.lastEventTime = math.max(scope.lastEventTime or time, time)
    if active and not scope.slots[slot] then
        if scope.count == 0 then scope.starts = time end
        scope.slots[slot] = true
        scope.count = scope.count + 1
    elseif not active and scope.slots[slot] then
        scope.slots[slot] = nil
        scope.count = scope.count - 1
        if scope.count == 0 then
            if time > scope.starts then
                local previous = scope.intervals[#scope.intervals]
                local total = (previous and previous[3] or 0) + time - scope.starts
                scope.intervals[#scope.intervals + 1] = { scope.starts, time, total }
            end
            scope.starts = nil
        end
    end
end

function Meter.ScopePercent(scope, starts, ends, duration)
    local total = Meter.IntervalTotal(scope.intervals, starts, ends)
    if scope.starts then total = total + math.max(0, ends - math.max(starts, scope.starts)) end
    return math.min(100, math.max(0, total / math.max(1, duration or (ends - starts)) * 100))
end

function Meter.ScopePercentExcluding(scope, excluded, starts, ends, duration)
    local intervals = {}
    for _, interval in ipairs(scope.intervals) do intervals[#intervals + 1] = interval end
    if scope.starts then intervals[#intervals + 1] = { scope.starts, ends } end
    local denominator = math.max(1, (duration or (ends - starts)) - Meter.ExcludedTotal(intervals, excluded, starts, ends))
    return math.min(100, math.max(0, Meter.IntervalTotal(intervals, starts, ends) / denominator * 100))
end

function Meter.RebuildScope(scope)
    local rebuilt = Meter.NewScope()
    table.sort(scope.events, function(a, b)
        if a.time == b.time then return a.seq < b.seq end
        return a.time < b.time
    end)
    for _, event in ipairs(scope.events) do
        Meter.ScopeEvent(rebuilt, event.slot, event.time, event.active, true)
    end
    rebuilt.events = scope.events
    return rebuilt
end
