-- HomeAfterPvPState.lua: Pure data initialization
-- Creates the initial state structure (defaults).

local HomeAfterPvPState = {}

---@return HomeAfterPvPState
function HomeAfterPvPState.Create()
    return {
        savedVars = {
            enabled = true,
            fromScoreboard = true,
        },
        armed = false,
        pending = nil,
    }
end

HomeAfterPvP.State = HomeAfterPvPState
