-- TravelWheelReturnUtils.lua: Pure decisions about the trip made after an
-- instance: where the player stands, whether an arrival calls for the trip,
-- and where it goes.

local TravelWheelReturnUtils = {}

TravelWheelReturnUtils.MODE_OFF = "off"
TravelWheelReturnUtils.MODE_HOUSE = "house"

local INSTANCES = { battleground = true, campaign = true, dungeon = true }

-- A queue has no place to arrive at, so only these kinds can follow an instance.
local RETURN_KINDS = { house = true, node = true }

---@param facts TravelWheelLocationFacts
---@return TravelWheelLocation
function TravelWheelReturnUtils.ClassifyLocation(facts)
    if facts.inBattleground then
        return "battleground"
    end
    if facts.inAvAWorld then
        return "campaign"
    end
    if facts.houseId ~= 0 then
        return "house"
    end
    if facts.inGroupInstance then
        return "dungeon"
    end
    return "world"
end

---One arrival, one verdict: an instance arms; the first landing outside one
---disarms, and calls for the trip only when that landing is the main world
---(landing in a house means the player is home, or chose a house).
---@param armed boolean
---@param location TravelWheelLocation
---@return boolean armed
---@return boolean makeTrip
function TravelWheelReturnUtils.DecideArrival(armed, location)
    if INSTANCES[location] then
        return true, false
    end
    return false, armed and location == "world"
end

---Where the player stood before the instance, kept only for the places the
---game does not put him back in itself: a house, and a campaign left for a
---battleground or dungeon.
---@param location TravelWheelLocation Where the player has just arrived
---@param facts TravelWheelLocationFacts
---@param origin TravelWheelOrigin|nil
---@param lastPlace TravelWheelPlace|nil The arrival before this one
---@return TravelWheelOrigin|nil
function TravelWheelReturnUtils.NextOrigin(location, facts, origin, lastPlace)
    if location == "house" then
        return { kind = "house", houseId = facts.houseId, owner = facts.houseOwner }
    end
    if location == "world" then
        return nil
    end
    if location == "campaign" then
        -- Standing in the campaign, there is no campaign to go back to.
        if origin and origin.kind == "house" then
            return origin
        end
        return nil
    end
    -- A battleground or dungeon: entered from a campaign, that campaign is
    -- where the player was; entered from another one, nothing changes.
    if lastPlace and lastPlace.location == "campaign" and lastPlace.campaignId ~= 0 then
        return { kind = "campaign", campaignId = lastPlace.campaignId }
    end
    return origin
end

---@param destination TravelWheelDestination|nil
---@return boolean
function TravelWheelReturnUtils.CanFollowInstance(destination)
    return destination ~= nil and RETURN_KINDS[destination.kind] == true
end

---Where the trip after an instance goes, or nil for no trip. A campaign left
---for a battleground or dungeon comes first: its queue is joined again.
---@param mode string "off", "house" (the house the player left), or a destination id
---@param requeueCampaign boolean
---@param origin TravelWheelOrigin|nil
---@param destination TravelWheelDestination|nil The saved destination the mode names
---@return TravelWheelReturnTarget|nil
function TravelWheelReturnUtils.ResolveTarget(mode, requeueCampaign, origin, destination)
    if requeueCampaign and origin and origin.kind == "campaign" then
        return { kind = "campaign", campaignId = origin.campaignId, name = "the campaign you left", toHouse = false }
    end
    if mode == TravelWheelReturnUtils.MODE_OFF then
        return nil
    end
    if mode == TravelWheelReturnUtils.MODE_HOUSE then
        if origin and origin.kind == "house" then
            return { kind = "house", houseId = origin.houseId, owner = origin.owner, name = "the house you left", toHouse = true }
        end
        return nil
    end
    if TravelWheelReturnUtils.CanFollowInstance(destination) then
        return { kind = "destination", id = destination.id, name = destination.name, toHouse = destination.kind == "house" }
    end
    return nil
end

TravelWheel.ReturnUtils = TravelWheelReturnUtils
