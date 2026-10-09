dofile("Uptime.lua")
dofile("StackUptime.lua")
dofile("LiveUptime.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
local LiveUptime = LiveBuffUptimeEngine
local fight = LiveUptime.New(0)
local tracker = { config = { unit = "group" }, state = { since = 0 } }
for id = 100, 1100 do LiveUptime.Touch(fight, id, 0, COMBAT_UNIT_TYPE_OTHER) end
local active, expected, ownExpected = {}, 0, 0
for id = 1, 12 do
    active[id] = id % 200 < 50 + id * 3
    LiveUptime.Touch(fight, id, 0, COMBAT_UNIT_TYPE_GROUP)
    if active[id] then LiveUptime.Effect(fight, tracker, 0, id, 61771, 1, true, id % 2 == 0) end
end
LiveUptime.Action(fight, "EVENT_HEAL_OUT", 0, 1, 1)
for tick = 1, 15000 do
    local time = tick / 10
    for id = 1, 12 do
        if active[id] then
            expected = expected + 0.1
            if id % 2 == 0 then ownExpected = ownExpected + 0.1 end
        end
        local gained = (tick + id) % 200 < 50 + id * 3
        if gained ~= active[id] then LiveUptime.Effect(fight, tracker, time, id, 61771, 1, gained, id % 2 == 0) end
        active[id] = gained
        LiveUptime.Action(fight, "EVENT_HEAL_OUT", time, 1, id)
    end
    if tick % 10 == 0 then
        local result = LiveUptime.Calculate(fight, tracker)
        assert(math.abs(result.covered - expected) < 0.00001)
        assert(math.abs(result.duration - time * 12) < 0.00001)
    end
end
tracker.config.buffSource = "own"
assert(math.abs(LiveUptime.Calculate(fight, tracker).covered - ownExpected) < 0.00001)
-- A fade delivered before its earlier gain must still close the eventual interval.
local late = { config = { unit = "group" }, state = { since = 0 } }
LiveUptime.Effect(fight, late, 10, 1, 61771, 8, false, true)
LiveUptime.Effect(fight, late, 5, 1, 61771, 8, true, true)
assert(LiveUptime.Calculate(fight, late).covered == 5)
print("Live-Uptime raid: 25 minutes, 12 members, 15000 ticks, 1001 irrelevant units, independent coverage oracle and late fade passed")
