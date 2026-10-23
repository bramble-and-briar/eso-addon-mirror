LiveBuffUptimeStacks = {}
local Stacks = LiveBuffUptimeStacks

local function state()
    return { intervals = {}, total = 0, weight = 0 }
end

local function change(data, time, weight)
    if data.starts and time > data.starts and data.weight > 0 then
        data.total = data.total + (time - data.starts) * data.weight
        data.intervals[#data.intervals + 1] = { data.starts, time, data.total, data.weight }
    end
    data.starts, data.weight = time, weight
end

local function apply(instance, event)
    local previous = instance.slots[event.slot]
    local count = event.gained and event.stacks or 0
    local own = previous and previous.own or (not previous and event.own)
    local allWeight = instance.all.weight - (previous and previous.stacks or 0) + count
    local ownWeight = instance.own.weight - (previous and previous.own and previous.stacks or 0) + (own and count or 0)
    if allWeight ~= instance.all.weight then change(instance.all, event.time, allWeight) end
    if ownWeight ~= instance.own.weight then change(instance.own, event.time, ownWeight) end
    instance.slots[event.slot] = event.gained and { stacks = count, own = own } or nil
    instance.maxStacks = math.max(instance.maxStacks, event.stacks)
    instance.lastTime = event.time
end

function Stacks.Event(data, ability, slot, time, gained, own, count)
    count = tonumber(count) or 1
    if count ~= count or count == math.huge or count == -math.huge then count = 1 end
    count = math.max(ability == 126597 and 0 or 1, math.floor(count))
    data.stackInstances = data.stackInstances or {}
    local instance = data.stackInstances[ability]
    if not instance then
        instance = { all = state(), own = state(), slots = {}, maxStacks = 0, events = {} }
        data.stackInstances[ability] = instance
    end
    local event = { slot = slot, time = time, gained = gained, own = own, stacks = count, seq = #instance.events + 1 }
    instance.events[#instance.events + 1] = event
    if instance.lastTime and time < instance.lastTime then
        table.sort(instance.events, function(a, b) return a.time == b.time and a.seq < b.seq or a.time < b.time end)
        instance.all, instance.own, instance.slots, instance.maxStacks = state(), state(), {}, 0
        for _, item in ipairs(instance.events) do apply(instance, item) end
    else
        apply(instance, event)
    end
end

local function untilTime(data, time)
    local low, high, found = 1, #data.intervals, 0
    while low <= high do
        local index = math.floor((low + high) / 2)
        if data.intervals[index][1] < time then found, low = index, index + 1 else high = index - 1 end
    end
    local total = 0
    if found > 0 then
        local interval = data.intervals[found]
        total = (found > 1 and data.intervals[found - 1][3] or 0)
            + math.max(0, math.min(time, interval[2]) - interval[1]) * interval[4]
    end
    if data.starts and time > data.starts then total = total + (time - data.starts) * data.weight end
    return total
end

function Stacks.Total(instances, source, starts, ends)
    if ends <= starts then return 0 end
    local total = 0
    for _, instance in pairs(instances or {}) do
        if instance.maxStacks > 0 then
            local data = source == "own" and instance.own or instance.all
            total = total + math.max(0, untilTime(data, ends) - untilTime(data, starts)) / instance.maxStacks
        end
    end
    return total
end
