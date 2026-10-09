dofile("Uptime.lua")
local Meter = LiveBuffUptimeMeter
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " != " .. tostring(expected))
end

-- A pre-existing buff starts counting at combat entry, not before it.
local state = Meter.New(10)
Meter.Observe(state, { starts = 5, ends = 15 }, 10, true, true)
Meter.Observe(state, { starts = 5, ends = 15 }, 12, true, true)
near(state.total, 2)
Meter.Observe(state, nil, 16, true, true)
near(state.total, 5)
near(Meter.Percent(state, 16), 100 * 5 / 6)

-- Overlapping applications and refreshes never add time twice.
state = Meter.New(0)
Meter.Observe(state, { starts = 0, ends = 5 }, 0, true, true)
Meter.Observe(state, { starts = 2, ends = 8 }, 3, true, true)
Meter.Observe(state, nil, 9, true, true)
near(state.total, 8)

-- A new application begins between samples, after an expired application.
state = Meter.New(0)
Meter.Observe(state, { starts = 0, ends = 1 }, 0, true, true)
Meter.Observe(state, { starts = 1.5, ends = 3 }, 2, true, true)
near(state.total, 1.5)

-- Target switches cannot backfill the new enemy's earlier effect time.
state = Meter.New(0)
Meter.Observe(state, nil, 2, true, true)
Meter.Advance(state, 3, true)
state.active = false
Meter.Observe(state, { starts = 0, ends = 10 }, 3, true, false)
Meter.Observe(state, { starts = 0, ends = 10 }, 4, true, true)
near(state.total, 1)
near(Meter.Percent(state, 4), 25)

-- Permanent effects and frozen out-of-combat totals.
state = Meter.New(0)
Meter.Observe(state, { starts = 0, ends = 0 }, 0, true, true)
Meter.Observe(state, { starts = 0, ends = 0 }, 5, true, true)
near(state.total, 5)
Meter.Observe(state, nil, 10, false, true)
near(state.total, 5)
near(Meter.Percent(state, 5), 100)
near(Meter.Percent(Meter.New(3), 3), 0)

state = Meter.New(0)
Meter.Observe(state, { starts = 0, ends = 1 }, 0, true, true)
Meter.Observe(state, { starts = 0, ends = 1 }, 0.5, true, true)
near(Meter.Percent(state, 0.5), 50)
near(Meter.Percent(state, 1, 0.25), 25)

local scope = Meter.NewScope()
Meter.ScopeEvent(scope, "a", 0, true)
Meter.ScopeEvent(scope, "b", 2, true)
Meter.ScopeEvent(scope, "a", 3, false)
near(Meter.ScopePercent(scope, 1, 4), 100)
Meter.ScopeEvent(scope, "b", 5, false)
near(Meter.ScopePercent(scope, 1, 6), 80)
near(Meter.ScopePercent(Meter.RebuildScope(scope), 0, 6, 10), 50)
local offBalance = Meter.New(0)
offBalance.intervals = { { 0, 7 }, { 22, 24 } }
local immunity = Meter.New(0)
immunity.intervals = { { 7, 22 } }
near(Meter.Percent(offBalance, 24), 37.5)
near(Meter.PercentExcluding(offBalance, immunity, 24), 100)
offBalance.intervals = { { 0, 7 }, { 25, 27 } }
near(Meter.PercentExcluding(offBalance, immunity, 27), 75)
near(Meter.PercentExcluding(offBalance, immunity, 27, 22), 40)
offBalance.intervals = { { 0, 7 } }
immunity.intervals = { { 0, 22 } }
near(Meter.PercentExcluding(offBalance, immunity, 22), 100)
near(Meter.PercentExcluding(Meter.New(0), immunity, 22), 0)
near(Meter.PercentExcluding(offBalance, immunity, 7, 0, 7), 100)

-- Cumulative interval queries must agree with a plain independently summed list.
state = Meter.New(0)
local plain = {}
for index = 0, 199 do
    local starts = index * 3
    Meter.Observe(state, { starts = starts, ends = starts + 1 }, starts, true, true)
    Meter.Observe(state, nil, starts + 2, true, true)
    plain[#plain + 1] = { starts, starts + 1 }
end
for index = 0, 1999 do
    local starts = (index * 17 % 650) - 25
    local ends = starts + (index * 23 % 200)
    near(Meter.IntervalTotal(state.intervals, starts, ends), Meter.IntervalTotal(plain, starts, ends))
end
near(state.total, 200)
print("Uptime: intervals, clipping, immunity exclusion, overlaps and delayed reapplication passed")
