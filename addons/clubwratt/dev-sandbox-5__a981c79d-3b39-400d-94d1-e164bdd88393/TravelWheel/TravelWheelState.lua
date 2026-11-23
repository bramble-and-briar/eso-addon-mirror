-- TravelWheelState.lua: Pure data initialization
-- Creates the initial state structure (defaults).

local TravelWheelState = {}

---@return TravelWheelState
function TravelWheelState.Create()
    return {
        savedVars = {
            destinations = {},
            nextId = 1,
            afterInstance = "off",
            fromScoreboard = true,
            requeueCampaign = true,
            accept = {
                campaign = 0,
                battleground = 9999,
                dungeon = -1,
            },
        },
        returnCampaigns = {},
        pendingAccepts = {},
        armed = false,
        origin = nil,
        lastPlace = nil,
        pendingReturn = nil,
    }
end

TravelWheel.State = TravelWheelState
