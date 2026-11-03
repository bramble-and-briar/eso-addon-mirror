local ADK = AntiDK2
local M   = {}
ADK.Combat.Events.PowerLash = M

-- 34117 = Flame Lash effect: enemy DK gains this when they have 5 Power Lash stacks ready
-- 20824 = Power Lash hit: each damage hit on player decrements their stack by 1
local ID_EFFECT   = ADK.IDS.POWER_LASH_EFFECT   -- 34117
local ID_HIT      = ADK.IDS.POWER_LASH           -- 20824
local DECAY_MS    = 15000

-- Combat results that count as a Power Lash swing at the player (hit or not).
local HIT_RESULTS = {
    [ACTION_RESULT_DAMAGE]          = true,
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_BLOCKED]         = true,
    [ACTION_RESULT_BLOCKED_DAMAGE]  = true,
    [ACTION_RESULT_DODGED]          = true,
    [ACTION_RESULT_MISS]            = true,
}

-- stacks[sourceName] = { count = N, decayHandle = handle }
local stacks = {}

local function Decay(name)
    if stacks[name] then
        stacks[name] = nil
        ADK.UI.PowerLashStacks.Refresh(stacks)
    end
end

local function SetCount(name, n)
    n = math.max(0, n)
    if n == 0 then
        if stacks[name] then ADK.CancelTimer(stacks[name].decayHandle) end
        stacks[name] = nil
    else
        if not stacks[name] then
            stacks[name] = { count = 0, decayHandle = nil }
        end
        local e = stacks[name]
        e.count = n
        e.decayHandle = ADK.CancelTimer(e.decayHandle)
        e.decayHandle = zo_callLater(function() Decay(name) end, DECAY_MS)
    end
    ADK.UI.PowerLashStacks.Refresh(stacks)
end

-- Enemy DK gained the Flame Lash empowerment: they now have stacks loaded
-- Enemy DK's Flame Lash expired naturally: reset to 0
local function OnEffectGained(sourceName, sourceType, hitValue, result)
    if result == ACTION_RESULT_EFFECT_FADED then
        SetCount(sourceName, 0)   -- effect expired, clear stacks
    else
        SetCount(sourceName, hitValue)  -- use hitValue as stack count from game
    end
end

-- Enemy hit us with Power Lash: consume 1 stack
local function OnHit(sourceName, sourceType, result)
    local e = stacks[sourceName]
    if not e then return end  -- no tracked stacks for this enemy, nothing to decrement
    SetCount(sourceName, e.count - 1)
end

function M.Register()
    -- Detect when enemy gains Flame Lash effect (ID_EFFECT = 34117)
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_PLEffect", EVENT_COMBAT_EVENT,
        function(_, result, _, _, _, _, sourceName, sourceType, _, _, hitValue, _, _, _, _, _, abilityId)
            if not ADK.Get("trackPowerLash")         then return end
            if abilityId ~= ID_EFFECT                then return end
            if result ~= ACTION_RESULT_EFFECT_GAINED and result ~= ACTION_RESULT_EFFECT_FADED then return end
            if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
            if ADK.IsPlayer(sourceName)              then return end
            OnEffectGained(sourceName, sourceType, hitValue, result)
        end
    )
    -- Detect Power Lash damage on player (each hit = -1 stack)
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_PowerLash", EVENT_COMBAT_EVENT,
        function(_, result, _, _, _, _, sourceName, sourceType, targetName, _, _, _, _, _, _, _, abilityId)
            if not ADK.Get("trackPowerLash") then return end
            if abilityId ~= ID_HIT           then return end
            if not HIT_RESULTS[result]       then return end
            if not ADK.IsPlayer(targetName)  then return end
            OnHit(sourceName, sourceType, result)
        end
    )
    -- Death cleanup
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_PLDeath", EVENT_COMBAT_EVENT,
        function(_, result, _, _, _, _, _, _, targetName, _, _, _, _, _, _, _, _)
            if result ~= ACTION_RESULT_KILLED then return end
            if stacks[targetName] then Decay(targetName) end
        end
    )
end

function M.Unregister()
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_PLEffect",   EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_PowerLash",  EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_PLDeath",    EVENT_COMBAT_EVENT)
end

function M.Reset()
    for _, e in pairs(stacks) do
        if e.decayHandle then zo_removeCallLater(e.decayHandle) end
    end
    stacks = {}
    ADK.UI.PowerLashStacks.Refresh(stacks)
end
