-- Decides what drives the title and when it changes: the zone plan (best title for this content,
-- or the rotation), the player's own picks (manual override), combat, and the new-title
-- celebration.
local FT = Flexatron
local Titles, Swap, Zones = FT.Titles, FT.Swap, FT.Zones
local L = FT.L
local Rotation = {}
FT.Rotation = Rotation

local SETTLE_MS = 2000 -- after a loading screen, before the first change
local GRACE_MS = 4000  -- after a loading screen the game may re-send the title: not a manual pick
local BUSY_RETRY_MS = 1000
local CELEBRATE_MS = 5 * 60000 -- how long a new title stays on

local timer              -- the next rotation step
local timerDue           -- when it's due
local plan               -- the zone plan being followed
local paused = false     -- the player picked a title themselves
local celebrating        -- { index, timer, endsAt } while a new title is on show
local activatedAt        -- nil until the character is in the world

local function StopTimer()
    if timer then
        zo_removeCallLater(timer)
        timer = nil
    end
    timerDue = nil
end

local function Blocked()
    return paused or celebrating ~= nil
end

-- When a new title lands: the emote.
local function Landed(celebration)
    FT.Emote.Play(celebration)
end

local Step

local function Schedule(ms)
    StopTimer()
    timerDue = GetGameTimeMilliseconds() + ms
    timer = zo_callLater(function()
        timer, timerDue = nil, nil
        Step()
    end, ms)
end

-- The list's titles the player still has, as indexes, in list order.
local function Indexes(names)
    local list = {}
    for _, name in ipairs(names) do
        local index = Titles.IndexOf(name)
        if index then
            list[#list + 1] = index
        end
    end
    return list
end

-- The title after `current` in the list (the first one if current isn't in it).
local function NextIn(list, current)
    for i, index in ipairs(list) do
        if index == current then
            return list[i % #list + 1]
        end
    end
    return list[1]
end

-- One step of the plan: show the held title, or move to the next title in the rotation.
Step = function()
    if Blocked() or not plan or IsUnitInCombat("player") then
        return -- combat ending, a zone change or a settings change starts it again
    end
    if Swap.IsRunning() then
        return Schedule(BUSY_RETRY_MS)
    end
    local current = GetCurrentTitleIndex()
    if plan.kind == "hold" then
        Swap.To(plan.index, function(_, _, landed)
            if landed then
                Landed()
            end
        end)
        return
    end
    local nextIndex = NextIn(Indexes(plan.names), current)
    if not nextIndex or nextIndex == current then
        return -- nothing unlocked in the list, or a one-title list that's already showing
    end
    local currentPlan = plan
    Swap.To(nextIndex, function(_, _, landed)
        if landed then
            Landed()
        end
        if plan == currentPlan and not Blocked() then
            Schedule(FT.sv.holdTime * 1000)
        end
    end)
end

-- Work out the plan for where the player is and start it, after delayMs. A zone change also ends
-- a pause.
function Rotation.Evaluate(zoneChanged, delayMs)
    if zoneChanged then
        paused = false
    end
    StopTimer()
    plan = nil
    if Blocked() then
        return
    end
    plan = Zones.Plan()
    if plan then
        Schedule(zoneChanged and SETTLE_MS or delayMs or 0)
    end
end

local function EndCelebration(resume)
    if not celebrating then
        return
    end
    if celebrating.timer then
        zo_removeCallLater(celebrating.timer)
    end
    celebrating = nil
    if resume then
        Rotation.Evaluate(false)
    end
end

-- Show a newly unlocked title for a few minutes, then hand back to the zone plan.
function Rotation.Celebrate(index)
    if not index then
        return
    end
    StopTimer()
    EndCelebration(false)
    celebrating = { index = index, endsAt = GetGameTimeMilliseconds() + CELEBRATE_MS }
    local changing = Swap.To(index, function(_, _, landed)
        if landed then
            Landed(true)
        end
    end)
    if not changing then
        Landed(true) -- already wearing it: just the emote
    end
    celebrating.timer = zo_callLater(function()
        if celebrating then
            celebrating.timer = nil
        end
        EndCelebration(true)
    end, CELEBRATE_MS)
end

-- The player picked a title themselves: pause until the next zone change.
local function OnTitleUpdate(_, unitTag)
    if unitTag ~= "player" or paused or Swap.IsRunning() then
        return
    end
    if not activatedAt or GetGameTimeMilliseconds() - activatedAt < GRACE_MS then
        return -- still loading in: the game re-sends the title, nobody picked it
    end
    if Swap.WasOurs(GetCurrentTitleIndex()) then
        return
    end
    paused = true
    StopTimer()
    EndCelebration(false)
    CHAT_ROUTER:AddSystemMessage(L.PAUSED)
end

local function OnCombatState(_, inCombat)
    if not inCombat and plan and plan.kind == "rotate" and not Blocked() and not timer and not Swap.IsRunning() then
        Schedule(FT.sv.holdTime * 1000)
    end
end

local function OnPlayerActivated()
    activatedAt = GetGameTimeMilliseconds()
    Rotation.Evaluate(true)
end

-- Start again after a settings change, ending a pause. delayMs lets several quick changes (like
-- switching titles on and off) settle before the title changes.
function Rotation.Resume(delayMs)
    paused = false
    Rotation.Evaluate(false, delayMs)
end

function Rotation.IsPaused()
    return paused
end

-- What drives the title right now, for the live preview in settings. kind is "new" (a new title on
-- show), "paused", "best" (the best title for this trial, dungeon or arena), "rotating", "off" or
-- "empty" (nothing switched on). Rotating also gives nextIndex and nextInMs.
function Rotation.Status()
    local now = GetGameTimeMilliseconds()
    local status = { swapping = Swap.IsRunning(), combat = IsUnitInCombat("player") }
    if celebrating then
        status.kind = "new"
        status.endsInMs = math.max(0, celebrating.endsAt - now)
    elseif paused then
        status.kind = "paused"
    elseif plan and plan.kind == "hold" then
        status.kind = "best"
    elseif plan then
        status.kind = "rotating"
        status.nextIndex = NextIn(Indexes(plan.names), GetCurrentTitleIndex())
        status.nextInMs = timerDue and math.max(0, timerDue - now)
    else
        status.kind = FT.sv.rotate and "empty" or "off"
    end
    return status
end

-- Whether the rotation changes titles by itself: it's rotating through more than one title.
function Rotation.IsChangingTitles()
    local status = Rotation.Status()
    return status.kind == "rotating" and status.nextIndex ~= nil and status.nextIndex ~= GetCurrentTitleIndex()
end

function Rotation.Init()
    local name = FT.name .. "Rotation"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_TITLE_UPDATE, OnTitleUpdate)
    EVENT_MANAGER:AddFilterForEvent(name, EVENT_TITLE_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
end
