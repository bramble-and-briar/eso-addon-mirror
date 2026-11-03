local ADK = AntiDK2
local M   = {}
ADK.Combat.Events.Corrosive = M

local ID = ADK.IDS.CORROSIVE_ARMOR

-- per-second window state
local hitsThisWindow = 0
local windowHandle   = nil

-- in-range duration state
local inRange        = false
local rangeStart     = 0
local tickHandle     = nil

local function FormatElapsed()
    local elapsed = math.floor((GetFrameTimeMilliseconds() - rangeStart) / 1000)
    return string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60)
end

local function StartDurationTick()
    if tickHandle then return end
    tickHandle = zo_callLater(function()
        tickHandle = nil
        if inRange then
            ADK.UI.Corrosive.UpdateTimer(FormatElapsed())
            StartDurationTick()
        end
    end, 1000)
end

local function OnHit(result)
    hitsThisWindow = hitsThisWindow + 1
    local isCrit = (result == ACTION_RESULT_DOT_TICK_CRITICAL)
    if not inRange then
        inRange    = true
        rangeStart = GetFrameTimeMilliseconds()
        StartDurationTick()
    end
    ADK.UI.Corrosive.Show(hitsThisWindow, isCrit)
    windowHandle = ADK.CancelTimer(windowHandle)
    windowHandle = zo_callLater(function()
        windowHandle   = nil
        hitsThisWindow = 0
    end, 1000)
end

local function StopTracking()
    inRange        = false
    hitsThisWindow = 0
    tickHandle     = ADK.CancelTimer(tickHandle)
    windowHandle   = ADK.CancelTimer(windowHandle)
    ADK.UI.Corrosive.Hide()
end

function M.Register()
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_Corrosive", EVENT_COMBAT_EVENT,
        function(_, result, _, _, _, _, sourceName, _, targetName, _, _, _, _, _, _, _, abilityId)
            if not ADK.Get("trackCorrosive") then return end
            if abilityId ~= ID               then return end
            if ADK.IsPlayer(sourceName)      then return end   -- our own Corrosive Armor
            if not ADK.IsPlayer(targetName)  then return end   -- not ticking on us
            if result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL then
                OnHit(result)
            end
        end
    )
end

function M.Unregister()
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_Corrosive", EVENT_COMBAT_EVENT)
end

function M.Reset()
    StopTracking()
end