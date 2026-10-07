-- JumpToSearchState.lua: Pure data initialization
-- Creates the initial state structure (defaults).

local JumpToSearchState = {}

function JumpToSearchState.Create()
    ---@type JumpToSearchState
    return {
        savedVars = {
            enabled = true,
            openKeyboard = true,
            debug = false,
        },
        layerPushed = false,
        activeTarget = nil,
        jumpedScreen = nil,
        jumpedList = nil,
        jumpedIndex = nil,
        jumpedListHadOverride = false,
        jumpedListOriginalMovePrevious = nil,
        hookedScreens = {},
        counters = {
            keyDowns = 0,
            jumps = 0,
            fallthroughs = 0,
            returns = 0,
        },
    }
end

JumpToSearch.State = JumpToSearchState
