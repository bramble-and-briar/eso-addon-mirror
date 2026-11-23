-- Gold Digger events. The game doesn't tell add-ons when a festival is on, so the player marks it.
-- Prices seen during an event are kept apart from normal prices.

local GP = ESOC_GoldDigger
local Events = {}
GP.Events = Events

local MAX_EVENT_SECONDS = 21 * 86400  -- ends a forgotten event by itself
local MAX_LOG = 40

Events.NAMES = {
    "New Life Festival", "Jester's Festival", "Anniversary Jubilee", "Midyear Mayhem",
    "Whitestrake's Mayhem", "Undaunted Celebration", "Witches Festival", "Other event",
}

local function log() return GP.sv.eventLog end

function Events.Current()
    local entries = log()
    local last = entries[#entries]
    if not last or last.to then return nil end
    if GetTimeStamp() - last.from > MAX_EVENT_SECONDS then
        last.to = last.from + MAX_EVENT_SECONDS
        return nil
    end
    return last
end

function Events.ActiveName()
    local current = Events.Current()
    return current and current.name or nil
end

function Events.Start(name)
    if Events.Current() then Events.End() end
    local entries = log()
    entries[#entries + 1] = { name = name, from = GetTimeStamp() }
    while #entries > MAX_LOG do table.remove(entries, 1) end
    GP.Interface.Refresh()
end

function Events.End()
    local current = Events.Current()
    if current then current.to = GetTimeStamp() end
    GP.Interface.Refresh()
end

-- While the events menu is parked nobody can switch an event off, and a running event stops
-- flips, selling and price filtering. So one left on is cancelled at load.
function Events.ClearParked()
    if GP.Interface.SHOW_EXTRAS then return false end
    local entries = log()
    local last = entries[#entries]
    if not last or last.to then return false end
    last.to = last.from
    return true
end

-- The event running at a past moment, used to label guild sales.
function Events.NameAt(time)
    local entries = log()
    for index = #entries, 1, -1 do
        local entry = entries[index]
        if time >= entry.from and time <= (entry.to or entry.from + MAX_EVENT_SECONDS) then return entry.name end
    end
    return nil
end
