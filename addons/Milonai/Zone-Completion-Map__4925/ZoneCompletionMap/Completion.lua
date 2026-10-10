ZoneCompletionMap = ZoneCompletionMap or {}

local Completion = {}
ZoneCompletionMap.Completion = Completion

-- A zone is complete when every enabled completion type that has at least one
-- activity in the zone is fully done. Returns nil when no enabled type has any
-- activity in the zone, so callers can tell "nothing to track" from "incomplete".
function Completion.IsZoneComplete(zoneId, isTypeEnabled, api)
    local counted = false
    for _, completionType in ipairs(api.types) do
        if isTypeEnabled(completionType) then
            local total = api.getTotal(zoneId, completionType) or 0
            if total > 0 then
                if not api.isComplete(zoneId, completionType) then
                    return false
                end
                counted = true
            end
        end
    end
    if not counted then
        return nil
    end
    return true
end

function Completion.DefaultApi()
    return {
        types = ZO_ZONE_STORY_ACTIVITY_COMPLETION_TYPES_SORTED_LIST,
        getTotal = function(zoneId, completionType)
            return GetNumZoneActivitiesForZoneCompletionTypeAndIndex(zoneId, completionType, nil)
        end,
        -- Same check the Zone Guide uses; handles indexed types and branching activities.
        isComplete = function(zoneId, completionType)
            return AreAllZoneStoryActivitiesCompleteForZoneCompletionTypeAndIndex(zoneId, completionType, nil)
        end,
    }
end
