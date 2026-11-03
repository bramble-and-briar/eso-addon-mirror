local ADK = AntiDK2
local M   = {}
ADK.Combat.Events.ShatteringRocks = M

local ID   = ADK.IDS.SHATTERING_ROCKS
local NAME = "Shattering Rocks"

function M.Register()
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_ShatteringRocks", EVENT_COMBAT_EVENT,
        function(_, _, _, _, _, _, sourceName, sourceType, targetName, _, _, _, _, _, _, _, abilityId)
            if not ADK.Get("trackShatteringRocks")   then return end
            if abilityId ~= ID                       then return end
            if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end
            if ADK.IsPlayer(sourceName)              then return end
            if not ADK.IsPlayer(targetName)          then return end
            ADK.UI.Stuns.ShowAvoidWithRoll(NAME)
        end
    )
end
function M.Unregister()
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_ShatteringRocks", EVENT_COMBAT_EVENT)
end
function M.Reset() end
