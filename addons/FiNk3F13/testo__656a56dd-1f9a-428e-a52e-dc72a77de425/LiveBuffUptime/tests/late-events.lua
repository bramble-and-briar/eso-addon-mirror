dofile("Uptime.lua")
local Meter = LiveBuffUptimeMeter
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.000001, tostring(actual) .. " != " .. tostring(expected))
end

-- A fade arriving before its gain must correct the live value immediately.
local scope = Meter.NewScope()
Meter.ScopeEvent(scope, "a", 8, false)
Meter.ScopeEvent(scope, "a", 2, true)
near(Meter.ScopePercent(scope, 0, 10), 60)
assert(scope.count == 0)

-- Another source overlaps the same buff; the union, not the sum, is counted.
Meter.ScopeEvent(scope, "b", 9, false)
Meter.ScopeEvent(scope, "b", 4, true)
near(Meter.ScopePercent(scope, 0, 10), 70)
near(Meter.ScopePercent(scope, 3, 6), 100)
local rebuilt = Meter.RebuildScope(scope)
near(Meter.ScopePercent(rebuilt, 0, 10), 70)
assert(#rebuilt.events == 4, "Rebuild must retain history for further late events")
Meter.ScopeEvent(rebuilt, "c", 1, true)
Meter.ScopeEvent(rebuilt, "c", 3, false)
near(Meter.ScopePercent(rebuilt, 0, 10), 80)

-- End-before-start queries occur while the damage clock is frozen.
Meter.ScopeEvent(rebuilt, "d", 12, true)
near(Meter.ScopePercent(rebuilt, 0, 10), 80)
local excluded = Meter.New(0)
excluded.intervals = { { 0, 2 }, { 4, 5 }, { 9, 15 } }
near(Meter.ExcludedTotal(rebuilt.intervals, excluded, 0, 10), 2)
near(Meter.ScopePercentExcluding(rebuilt, excluded, 0, 10), 100)

-- Callback arrival order cannot change the interval union.
local events = {
    { "a", 1, true }, { "b", 2, true }, { "a", 4, false }, { "b", 6, false },
    { "a", 8, true }, { "a", 9, false },
}
local checked = 0
local function permutations(order, used)
    if #order == #events then
        local candidate = Meter.NewScope()
        for _, index in ipairs(order) do
            local event = events[index]
            Meter.ScopeEvent(candidate, event[1], event[2], event[3])
        end
        near(Meter.ScopePercent(candidate, 0, 10), 60)
        near(Meter.ScopePercent(Meter.RebuildScope(candidate), 0, 10), 60)
        checked = checked + 1
        return
    end
    for index = 1, #events do
        if not used[index] then
            order[#order + 1], used[index] = index, true
            permutations(order, used)
            order[#order], used[index] = nil, nil
        end
    end
end
permutations({}, {})
assert(checked == 720)
print("Late events: 720 arrival orders, overlapping sources, clipping and replay history passed")
