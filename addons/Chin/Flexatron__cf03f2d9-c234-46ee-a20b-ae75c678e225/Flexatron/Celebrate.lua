-- New-title celebration: when a title unlocks, wear it right away and show it off with the emote,
-- then keep it for a while. The new title also gets its switch in the settings list. EVENT_PLAYER_TITLES_UPDATE covers every
-- source of titles, achievements and PvP ranks alike.
local FT = Flexatron
local Celebrate = {}
FT.Celebrate = Celebrate

local RETRY_MS, TRIES = 500, 10
local MAX_AT_ONCE = 3 -- more than this at once is the title list loading, not new unlocks

local known  -- [title name] = true for the titles unlocked when we last looked
local queued -- the newest title, waiting for combat to end

local function Snapshot()
    local names = {}
    for i = 1, GetNumTitles() do
        names[GetTitle(i)] = true
    end
    return names
end

local function Show(name, tries)
    if not FT.sv.celebrate then
        return
    end
    if IsUnitInCombat("player") then
        queued = name
        return
    end
    local index = FT.Titles.IndexOf(name)
    if not index then
        -- a new title can take a moment to show up in the list
        if (tries or 0) < TRIES then
            zo_callLater(function() Show(name, (tries or 0) + 1) end, RETRY_MS)
        end
        return
    end
    FT.Rotation.Celebrate(index)
end

local function OnTitlesUpdate()
    local current = Snapshot()
    if known and next(known) ~= nil then
        local newest, count = nil, 0
        for i = 1, GetNumTitles() do
            local name = GetTitle(i)
            if not known[name] then
                newest = name -- several at once: the last one wins
                count = count + 1
            end
        end
        if newest and count <= MAX_AT_ONCE then
            Show(newest)
        end
    end
    known = current
end

local function OnPlayerActivated()
    if not known then
        known = Snapshot()
    end
end

local function OnCombatState(_, inCombat)
    if not inCombat and queued then
        local name = queued
        queued = nil
        Show(name)
    end
end

function Celebrate.Init()
    local name = FT.name .. "Celebrate"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_TITLES_UPDATE, OnTitlesUpdate)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
end
