-- DLC Roulette. Copyright (c) 2026 -Chin. All rights reserved: no copying, sharing, changes or reuse.
-- Cooldown: a dungeon you have just been in is held back from the roulette for a while, so the same one
-- doesn't keep coming up. Normal and Veteran are kept apart, the clock is the real one, and the dungeon you
-- landed in is read from the game rather than guessed from a list.
local DR = DLCRoulette
local L = DR.L
local Cooldown = {}
DR.Cooldown = Cooldown

local NORMAL, VETERAN = "normal", "veteran"
local LISTENER = "DLCRouletteEntry"

local function Key(activityType)
    return activityType == LFG_ACTIVITY_MASTER_DUNGEON and VETERAN or NORMAL
end

local function List(activityType)
    return DR.cd[Key(activityType)]
end

-- Seconds, from the panel. 0 turns cooldowns off. Expiry is always measured against the setting as it is
-- now, so moving the slider applies to dungeons that are already stamped.
function Cooldown.Duration()
    return (DR.sv.cooldownHours or 12) * 3600
end

-- Seconds left, or 0. A stamp in the future (the system clock moved) counts as expired.
function Cooldown.Remaining(activityType, zoneId)
    local duration = Cooldown.Duration()
    if duration == 0 then
        return 0
    end
    local stamp = List(activityType)[zoneId]
    if not stamp then
        return 0
    end
    local now = GetTimeStamp()
    if stamp > now then
        return 0
    end
    local left = duration - (now - stamp)
    return left > 0 and left or 0
end

function Cooldown.IsOn(activityType, zoneId)
    return Cooldown.Remaining(activityType, zoneId) > 0
end

-- Going back into a dungeon that is still on cooldown leaves its stamp alone, so the hold doesn't creep
-- forward every time. An expired stamp is replaced.
function Cooldown.Mark(activityType, zoneId)
    if Cooldown.IsOn(activityType, zoneId) then
        return
    end
    List(activityType)[zoneId] = GetTimeStamp()
end

function Cooldown.Clear(activityType)
    DR.cd[Key(activityType)] = {}
end

function Cooldown.ClearAll()
    DR.cd[NORMAL] = {}
    DR.cd[VETERAN] = {}
end

-- Run once at load so the saved file doesn't collect stamps forever. Skipped while cooldowns are off,
-- because nothing has expired then and turning them back on should find the stamps still there.
function Cooldown.Prune()
    if Cooldown.Duration() == 0 then
        return
    end
    for _, activityType in ipairs({ LFG_ACTIVITY_DUNGEON, LFG_ACTIVITY_MASTER_DUNGEON }) do
        local list = List(activityType)
        for zoneId in pairs(list) do
            if not Cooldown.IsOn(activityType, zoneId) then
                list[zoneId] = nil
            end
        end
    end
end

-- { name, left } for every dungeon of one difficulty still on cooldown, the one coming back soonest first.
function Cooldown.Entries(activityType)
    local entries = {}
    for zoneId in pairs(List(activityType)) do
        local left = Cooldown.Remaining(activityType, zoneId)
        if left > 0 then
            entries[#entries + 1] = { name = ZO_CachedStrFormat(SI_ZONE_NAME, GetZoneNameById(zoneId)), left = left }
        end
    end
    table.sort(entries, function(a, b) return a.left < b.left end)
    return entries
end

-- One dungeon per line, name and time left, for the settings panel.
function Cooldown.Text(activityType)
    local entries = Cooldown.Entries(activityType)
    if #entries == 0 then
        return L.COOLDOWN_NONE
    end
    local lines = {}
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = entry.name .. "  " .. ZO_FormatTimeLargestTwo(entry.left, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL)
    end
    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------------------------------
-- Watching for the dungeon you land in.
--
-- Nothing is registered until a roulette button queues you, and nothing is re-registered on load: if the
-- game goes down before you get in, that run simply isn't marked. Three events, no polling and no timers.
------------------------------------------------------------------------------------------------------

local queuedAs = nil -- the difficulty the button queued, so entry goes on the right list
local sawGroup = false -- the group has started forming, so the queue ending is the hand-off, not a cancel

local function Stop()
    queuedAs = nil
    sawGroup = false
    EVENT_MANAGER:UnregisterForEvent(LISTENER, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(LISTENER, EVENT_ACTIVITY_FINDER_STATUS_UPDATE)
end

-- The game's own test for "still waiting": a ready check is still the queue, so it must not end the watch.
local function StillQueued()
    local status = GetActivityFinderStatus()
    return status == ACTIVITY_FINDER_STATUS_QUEUED or status == ACTIVITY_FINDER_STATUS_READY_CHECK
end

-- Every loading screen. The dungeon is read from the game, so there is no zone list to keep up to date and
-- being dropped into one already running reads exactly the same. A wayshrine or a house is none of these,
-- and the watch then carries on only while the queue is still live.
local function OnPlayerActivated()
    if not queuedAs then
        return
    end
    if IsInLFGGroup() then
        local activityId = GetCurrentLFGActivityId()
        if activityId > 0 then
            local zoneId = GetActivityZoneId(activityId)
            if zoneId and zoneId ~= 0 then
                Cooldown.Mark(queuedAs, zoneId)
                Stop()
                return
            end
        end
    end
    if not StillQueued() then
        Stop()
    end
end

-- Ends the watch early when the queue is cancelled, so it isn't left sitting until the next loading screen.
-- Once the group is forming, the queue ending means you are on your way in, so only the loading screen above
-- decides from then on.
local function OnStatusUpdate(_, status)
    if status == ACTIVITY_FINDER_STATUS_FORMING_GROUP or status == ACTIVITY_FINDER_STATUS_READY_CHECK then
        sawGroup = true
    elseif status == ACTIVITY_FINDER_STATUS_NONE and not sawGroup and not IsInLFGGroup() then
        Stop()
    end
end

function Cooldown.Listen(activityType)
    queuedAs = activityType
    sawGroup = false
    EVENT_MANAGER:RegisterForEvent(LISTENER, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(LISTENER, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, OnStatusUpdate)
end
