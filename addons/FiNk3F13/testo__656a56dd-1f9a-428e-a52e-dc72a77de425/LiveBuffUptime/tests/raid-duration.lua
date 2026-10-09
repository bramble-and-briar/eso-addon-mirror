dofile("Uptime.lua")
dofile("GroupUptime.lua")
local Group = LiveBuffUptimeGroup
local group = Group.New(0)
local duration, covered, excluded = 0, 0, 0
local previous = {}
local started = os.clock()
for step = 0, 15000 do
    local now = step / 10
    local observations = {}
    for index = 1, 12 do
        local phase = (step + index * 7) % 100
        local starts = (step + index * 7 - phase) / 10 - index * 0.7
        local eligible = not (index == 1 and step >= 3000 and step < 3600)
            and not (index == 2 and step >= 6000 and step < 6200)
        local key = index == 3 and step >= 7500 and "replacement" or tostring(index)
        observations[index] = { key = key, eligible = eligible,
            effect = phase < 40 and { starts = starts, ends = starts + 4 } or nil,
            excluded = phase < 80 and { starts = starts, ends = starts + 8 } or nil }
        if step > 0 and step <= 14800 and previous[index].eligible then
            duration = duration + 0.1
            if previous[index].active then covered = covered + 0.1 end
            if previous[index].excluded and not previous[index].active then excluded = excluded + 0.1 end
        end
        previous[index] = { eligible = eligible, active = phase < 40, excluded = phase < 80 }
    end
    Group.Update(group, observations, now, true, { starts = 0, ends = math.min(now, 1480) })
    if duration > 0 then
        assert(math.abs(group.percent - covered / duration * 100) < 0.0001, "Raid coverage differs at step " .. step)
        assert(math.abs(group.adjustedPercent - covered / (duration - excluded) * 100) < 0.0001,
            "Recipient cooldown exclusion differs at step " .. step)
    end
end
print(string.format("Raid duration: 25 minutes, 12 members, 15000 ticks, death/return, replacement and frozen tail passed (%.3fs CPU in test runtime)", os.clock() - started))
