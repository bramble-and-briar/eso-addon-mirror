local ADK = AntiDK2
local M   = {}
ADK.Combat.Events.MoltenWhip = M

local ID         = ADK.IDS.MOLTEN_WHIP
local MAX_STACKS = 3
local DECAY_MS   = 12000

-- Combat results that count as a Molten Whip interaction with the player.
local TRACKED_RESULTS = {
    [ACTION_RESULT_EFFECT_GAINED]   = true,
    [ACTION_RESULT_EFFECT_FADED]    = true,
    [ACTION_RESULT_DAMAGE]          = true,
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_BLOCKED]         = true,
    [ACTION_RESULT_BLOCKED_DAMAGE]  = true,
    [ACTION_RESULT_DODGED]          = true,
}

-- stacks[sourceName] = { count = N, decayHandle = handle }
local stacks = {}

local function Decay(name)
    if stacks[name] then
        stacks[name] = nil
        ADK.UI.MoltenStacks.Refresh(stacks)
    end
end

local function OnHit(sourceName, result)
    if result == ACTION_RESULT_EFFECT_FADED then
        -- Stacks faded (expired naturally or consumed by empowered whip)
        Decay(sourceName)
        return
    end

    if not stacks[sourceName] then
        stacks[sourceName] = { count = 0, decayHandle = nil }
    end
    local e = stacks[sourceName]

    if result == ACTION_RESULT_EFFECT_GAINED then
        -- Each EFFECT_GAINED = +1 stack (do not use hitValue, it is not the stack count)
        e.count = math.min(e.count + 1, MAX_STACKS)
    else
        -- Damage result: if stacks are at max, the empowered whip was used - consume
        if e.count >= MAX_STACKS then
            Decay(sourceName)
            return
        end
        -- Sub-max damage: just refresh (stacks unchanged until EFFECT_GAINED fires)
    end

    e.decayHandle = ADK.CancelTimer(e.decayHandle)
    if e.count > 0 then
        e.decayHandle = zo_callLater(function() Decay(sourceName) end, DECAY_MS)
    else
        stacks[sourceName] = nil
    end
    ADK.UI.MoltenStacks.Refresh(stacks)
end

function M.Register()
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_MoltenWhip", EVENT_COMBAT_EVENT,
        function(_, result, _, _, _, _, sourceName, _, targetName, _, _, _, _, _, _, _, abilityId)
            if not ADK.Get("trackMoltenWhip") then return end
            if abilityId ~= ID and abilityId ~= ADK.IDS.MOLTEN_ATTACK then return end
            if ADK.IsPlayer(sourceName)     then return end
            if not ADK.IsPlayer(targetName) then return end
            if not TRACKED_RESULTS[result]  then return end
            OnHit(sourceName, result)
        end
    )
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_MoltenDeath", EVENT_COMBAT_EVENT,
        function(_, result, _, _, _, _, _, _, targetName, _, _, _, _, _, _, _, _)
            if result ~= ACTION_RESULT_KILLED then return end
            if stacks[targetName] then Decay(targetName) end
        end
    )
end

function M.Unregister()
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_MoltenWhip",  EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_MoltenDeath", EVENT_COMBAT_EVENT)
end

function M.Reset()
    for _, e in pairs(stacks) do
        if e.decayHandle then zo_removeCallLater(e.decayHandle) end
    end
    stacks = {}
    ADK.UI.MoltenStacks.Refresh(stacks)
end
