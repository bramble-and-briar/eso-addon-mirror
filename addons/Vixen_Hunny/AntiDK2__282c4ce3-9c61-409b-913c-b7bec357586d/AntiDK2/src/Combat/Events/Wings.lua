local ADK = AntiDK2
local M   = {}
ADK.Combat.Events.Wings = M

local ID = ADK.IDS.WING_BUFFET

-- activeTargets[sourceName] = { count, decayHandle }
local activeTargets = {}

local function RemoveTarget(name)
    local e = activeTargets[name]
    if not e then return end
    ADK.CancelTimer(e.decayHandle)
    activeTargets[name] = nil
    ADK.UI.Wings.Refresh(activeTargets)
end

local function ScheduleDecay(name)
    local e = activeTargets[name]
    if not e then return end
    e.decayHandle = ADK.CancelTimer(e.decayHandle)
    e.decayHandle = zo_callLater(function()
        RemoveTarget(name)
    end, ADK.Get("wingsCombatTimeout") * 1000)
end

local function OnHit(sourceName, sourceType)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end
    if not activeTargets[sourceName] then
        activeTargets[sourceName] = { count = 0, decayHandle = nil, lastHitTime = 0 }
    end
    activeTargets[sourceName].count       = activeTargets[sourceName].count + 1
    activeTargets[sourceName].lastHitTime = GetFrameTimeMilliseconds()
    ScheduleDecay(sourceName)
    ADK.UI.Wings.Refresh(activeTargets)
end
local function OnFaded(sourceName, sourceType)
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    activeTargets[sourceName] = { count = 0, decayHandle = nil, lastHitTime = 0 }
    ADK.UI.Wings.Refresh(activeTargets)
end

-- Called by every other tracked-ability module when it fires on the player.
-- Adds/refreshes this enemy in activeTargets so the main panel shows them.
function M.TrackEnemy(sourceName, sourceType)
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if not activeTargets[sourceName] then
        activeTargets[sourceName] = { count = 0, decayHandle = nil, lastHitTime = 0 }
    end
    activeTargets[sourceName].lastHitTime = GetFrameTimeMilliseconds()
    ScheduleDecay(sourceName)
    ADK.UI.Wings.Refresh(activeTargets)
end

function M.Register()
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_Wings", EVENT_COMBAT_EVENT,
        function(_, result, _, _, _, _, sourceName, sourceType, targetName, _, _, _, _, _, _, _, abilityId)
            if not ADK.Get("trackWings") then return end
            if abilityId ~= ID           then return end
            if result ~= ACTION_RESULT_EFFECT_GAINED and result ~= ACTION_RESULT_EFFECT_FADED then return end
            -- The stagger effect is reported with the player as both source and target.
            if not ADK.IsPlayer(sourceName) then return end
            if not ADK.IsPlayer(targetName) then return end
            M.TrackEnemy(sourceName, sourceType)
            if result == ACTION_RESULT_EFFECT_FADED then
                OnFaded(sourceName, sourceType)
            else
                OnHit(sourceName, sourceType)
            end
        end
    )
    -- Detect when a tracked enemy dies
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_WingsDeath", EVENT_COMBAT_EVENT,
        function(_, result, _, _, _, _, _, _, targetName, _, _, _, _, _, _, _, _)
            if result ~= ACTION_RESULT_KILLED and result ~= ACTION_RESULT_DIED and result ~= ACTION_RESULT_DIED_XP and result ~= ACTION_RESULT_TARGET_DEAD then return end
            if activeTargets[targetName]      then RemoveTarget(targetName) end
        end
    )
end

function M.Unregister()
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_Wings",      EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_WingsDeath", EVENT_COMBAT_EVENT)
end

function M.Reset()
    for _, e in pairs(activeTargets) do
        if e.decayHandle then zo_removeCallLater(e.decayHandle) end
    end
    activeTargets = {}
    ADK.UI.Wings.Refresh(activeTargets)
end

function M.GetTargets()
    return activeTargets
end
