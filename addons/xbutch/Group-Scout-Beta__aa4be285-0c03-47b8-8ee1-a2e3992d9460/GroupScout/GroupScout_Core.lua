GroupScout = GroupScout or {}
local Core = {}
GroupScout.Core = Core

function Core.Pack(values)
    local parts = {}
    for index, value in ipairs(values) do
        value = tostring(value)
        parts[index] = tostring(#value) .. ":" .. value
    end
    return table.concat(parts, "|")
end

function Core.ListingKey(listing)
    return Core.Pack({ listing.leader, listing.category, listing.primary,
        listing.secondary, listing.title })
end

function Core.NewTracker()
    return { seen = {}, initialized = false }
end

function Core.Observe(tracker, listings)
    local fresh = {}
    local baseline = not tracker.initialized
    for _, listing in ipairs(listings) do
        local key = Core.ListingKey(listing)
        if not tracker.seen[key] then
            tracker.seen[key] = true
            if not baseline then fresh[#fresh + 1] = listing end
        end
    end
    tracker.initialized = true
    return fresh, baseline
end

function Core.Delay(intervalMs, failures, random)
    local base = intervalMs * (2 ^ math.min(failures, 2))
    return base + random(0, math.floor(base / 5))
end
