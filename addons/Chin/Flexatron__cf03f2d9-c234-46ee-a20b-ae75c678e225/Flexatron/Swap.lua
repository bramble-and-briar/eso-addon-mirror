-- Title changes: one at a time, each waiting for the server to confirm it.
local FT = Flexatron
local Swap = {}
FT.Swap = Swap

local CONFIRM_TIMEOUT_MS = 2000
local RECENT_MS = 5000

local pending     -- the change in flight: { index, fromIndex, onFinish, timeoutId }
local lastAsked   -- the last title Flexatron asked for
local recent = {} -- [index] = when Flexatron asked for that title, until the server confirms it

local function Finish(landed)
    local p = pending
    pending = nil
    zo_removeCallLater(p.timeoutId)
    if landed then
        recent[p.index] = nil -- confirmed: a later change to it isn't a late confirmation
    end
    if p.onFinish then
        p.onFinish(p.fromIndex, p.index, landed)
    end
end

local function OnTitleUpdate(_, unitTag)
    if unitTag == "player" and pending and GetCurrentTitleIndex() == pending.index then
        Finish(true)
    end
end

-- Forget the change in flight (the title stays wherever it got to).
function Swap.Stop()
    if pending then
        zo_removeCallLater(pending.timeoutId)
        pending = nil
    end
end

function Swap.IsRunning()
    return pending ~= nil
end

-- Change to this title. onFinish(fromIndex, toIndex, landed) runs once the server confirms it, or
-- after the timeout with landed false. Returns false if there was nothing to change.
function Swap.To(toIndex, onFinish)
    local fromIndex = GetCurrentTitleIndex()
    if not toIndex or toIndex == fromIndex then
        return false
    end
    Swap.Stop()
    lastAsked = toIndex
    recent[toIndex] = GetGameTimeMilliseconds()
    local p = { index = toIndex, fromIndex = fromIndex, onFinish = onFinish }
    p.timeoutId = zo_callLater(function()
        if pending == p then
            Finish(GetCurrentTitleIndex() == toIndex)
        end
    end, CONFIRM_TIMEOUT_MS)
    pending = p
    SelectTitle(toIndex)
    return true
end

-- True if this title is one Flexatron set itself: the last one it asked for, or one it asked for in
-- the last RECENT_MS that the server hasn't confirmed yet (a late answer to an earlier change).
-- Anything else is the player's choice.
function Swap.WasOurs(index)
    if index == lastAsked then
        return true
    end
    local at = recent[index]
    return at ~= nil and GetGameTimeMilliseconds() - at < RECENT_MS
end

function Swap.Init()
    local name = FT.name .. "Swap"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_TITLE_UPDATE, OnTitleUpdate)
    EVENT_MANAGER:AddFilterForEvent(name, EVENT_TITLE_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
end
