local ADK = AntiDK2
local M   = {}
ADK.Combat.Events.Fossilize = M

local ID   = ADK.IDS.FOSSILIZE
local NAME = "Fossilize"

function M.Register()
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_Fossilize", EVENT_COMBAT_EVENT,
        function(_, _, _, _, _, _, sourceName, _, targetName, _, _, _, _, _, _, _, abilityId)
            if not ADK.Get("trackFossilize") then return end
            if abilityId ~= ID               then return end
            -- Deliberately NOT filtered by source/target identity: Fossilize events
            -- have been observed with empty names, so only fully anonymous events
            -- are dropped. Tighten with ADK.IsPlayer() once the event shape is known.
            if sourceName == "" and targetName == "" then return end
            ADK.UI.Stuns.ShowAvoidWithRoll(NAME)
        end
    )
end
function M.Unregister()
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_Fossilize", EVENT_COMBAT_EVENT)
end
function M.Reset() end
