local ADK = AntiDK2
local M   = {}
ADK.Combat.Events.DragonknightStandard = M

local ID   = ADK.IDS.SHIFTING_STANDARD
local NAME = "Shifting Standard"

function M.Register()
    EVENT_MANAGER:RegisterForEvent(
        ADK.name .. "_Standard", EVENT_COMBAT_EVENT,
        function(_, _, _, _, _, _, _, sourceType, targetName, _, _, _, _, _, _, _, abilityId)
            if not ADK.Get("trackShiftingStandard")  then return end
            if abilityId ~= ID                       then return end
            if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end
            if not ADK.IsPlayer(targetName)          then return end
            ADK.UI.Stuns.ShowAvoid(NAME)
        end
    )
end
function M.Unregister()
    EVENT_MANAGER:UnregisterForEvent(ADK.name .. "_Standard", EVENT_COMBAT_EVENT)
end
function M.Reset() end
