-- TravelWheelState.lua: Pure data initialization
-- Creates the initial state structure (defaults).

local TravelWheelState = {}

---@return TravelWheelState
function TravelWheelState.Create()
    return {
        savedVars = {
            destinations = {},
            nextId = 1,
            accept = {
                campaign = 0,
                battleground = 9999,
                dungeon = -1,
            },
        },
        pendingAccepts = {},
        unstuckAsked = false,
    }
end

TravelWheel.State = TravelWheelState
