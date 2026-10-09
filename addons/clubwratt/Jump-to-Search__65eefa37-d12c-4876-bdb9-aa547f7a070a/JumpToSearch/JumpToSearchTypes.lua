---@meta JumpToSearchTypes
-- JumpToSearchTypes.lua: Centralized type definitions for JumpToSearch

---@class JumpToSearchSavedVars
---@field enabled boolean Master toggle for the D-pad Right jump
---@field openKeyboard boolean Also open the text entry (virtual keyboard) on jump, not just highlight the header
---@field debug boolean Verbose logging to chat

---@class JumpToSearchScreenTarget
---@field name string Short label used in logs
---@field sceneName string Scene whose SHOWING/HIDDEN states gate the action layer
---@field getScreen fun(): table|nil Resolves the live screen object (global may not exist at load)
---@field getList fun(screen: table): table|nil Resolves the list the header hands focus back to

---@class JumpToSearchState
---@field savedVars JumpToSearchSavedVars
---@field layerPushed boolean Whether our action layer is currently on the stack
---@field activeTarget JumpToSearchScreenTarget|nil Target whose scene is showing
---@field jumpedScreen table|nil Screen whose header we entered via D-pad Right (nil once the header is left)
---@field jumpedList table|nil List that was active at jump time
---@field jumpedIndex integer|nil Selected index of jumpedList at jump time
---@field jumpedListHadOverride boolean Whether jumpedList currently carries our instance-level MovePrevious override
---@field jumpedListOriginalMovePrevious function|nil Instance-level MovePrevious that was shadowed (nil = class method)
---@field hookedScreens table<table, boolean> Screens whose headerFocus FocusDeactivated callback we registered
---@field counters JumpToSearchCounters

---@class JumpToSearchCounters
---@field keyDowns integer D-pad Right presses seen on our layer
---@field jumps integer Presses that entered the header
---@field fallthroughs integer Presses passed on to the game's own D-pad Right handler (if any)
---@field returns integer Times up/down returned focus to the list
