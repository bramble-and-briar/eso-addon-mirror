-- TravelWheelTravelUtils.lua: Pure decisions about a wayshrine trip.

local TravelWheelTravelUtils = {}

---Why a wayshrine trip cannot be made, or nil when it can.
---@param facts TravelWheelNodeFacts
---@return string|nil reason
function TravelWheelTravelUtils.NodeBlock(facts)
    if facts.dead then
        return "you are dead"
    end
    if not facts.canLeave then
        return "you cannot travel from here"
    end
    if not facts.known then
        return "not discovered on this character"
    end
    if facts.cost > facts.gold then
        return string.format("the trip costs %d gold and you carry %d", facts.cost, facts.gold)
    end
    return nil
end

TravelWheel.TravelUtils = TravelWheelTravelUtils
