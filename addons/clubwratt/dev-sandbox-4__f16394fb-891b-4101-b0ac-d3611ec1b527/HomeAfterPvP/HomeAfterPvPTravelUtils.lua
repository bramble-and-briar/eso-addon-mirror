-- HomeAfterPvPTravelUtils.lua: Pure decisions about where the player is and
-- whether an arrival calls for the trip home.

local HomeAfterPvPTravelUtils = {}

---@param facts HomeAfterPvPLocationFacts
---@return HomeAfterPvPLocation
function HomeAfterPvPTravelUtils.ClassifyLocation(facts)
    if facts.inBattleground or facts.inAvAWorld then
        return "pvp"
    end
    if facts.houseId ~= 0 then
        return "house"
    end
    if facts.inDungeon then
        return "dungeon"
    end
    return "world"
end

---One arrival, one verdict: a PvP world arms; the first landing outside one
---disarms, and calls for the trip home only when that landing is the main world.
---@param armed boolean
---@param location HomeAfterPvPLocation
---@return boolean armed
---@return boolean travelHome
function HomeAfterPvPTravelUtils.DecideArrival(armed, location)
    if location == "pvp" then
        return true, false
    end
    return false, armed and location == "world"
end

HomeAfterPvP.TravelUtils = HomeAfterPvPTravelUtils
