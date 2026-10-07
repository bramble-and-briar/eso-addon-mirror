-- JumpToSearchFocusActions.lua: the R3 jump into the search header and the up/down return.
--
-- How the base game does it (zo_gamepadparametricscrolllistscreen.lua): the header is only
-- reachable by pressing up at list index 1 (UpdateDirectionalInput -> RequestEnterHeader).
-- RequestEnterHeader deactivates the current list WITHOUT touching its selection, and
-- RequestLeaveHeader reactivates it in place - so the game already remembers where you were.
-- All we add is a way in from anywhere (R3) and a way back from the header on "up".
--
--   R3 ──▶ CanJump? ──no──▶ return false (falls through to the screen's own R3 keybind)
--           │yes
--           ▼
--   screen:RequestEnterHeader()  (list deactivated in place, header highlighted)
--   optional: screen:SetTextSearchFocused(true)  (opens the text entry right away)
--
--   while the header is active after a jump (stock UpdateDirectionalInput, untouched):
--     down ──▶ RequestLeaveHeader()            ──▶ list resumes at the same entry
--     up   ──▶ list:MovePrevious() on the hidden list (index ~= 1)
--              └─ we override MovePrevious on that one list INSTANCE for the duration of the
--                 jump so it calls RequestLeaveHeader() instead; removed when the header
--                 deactivates, so normal scrolling never runs through addon code.
--
-- DO NOT wrap anything on the per-frame input path (movementController:CheckMovement,
-- UpdateDirectionalInput, DIRECTIONAL_INPUT). The game polls the d-pad with IsKeyDown, which
-- is PRIVATE; an addon frame anywhere on the call stack taints it and the game's own call
-- raises "Attempt to access a private function from insecure code" every frame (0.1.0 bug).

local ScreenUtils = JumpToSearch.ScreenUtils
local Log = JumpToSearch.LogUtils

local FocusActions = {}

local consumedDown = false

---@return JumpToSearchState
local function State()
    return JumpToSearch.state
end

---Remove the per-jump MovePrevious override and forget the jump.
local function ClearJump()
    local state = State()
    local list = state.jumpedList
    if list and state.jumpedListHadOverride then
        rawset(list, "MovePrevious", state.jumpedListOriginalMovePrevious)
    end
    state.jumpedScreen = nil
    state.jumpedList = nil
    state.jumpedIndex = nil
    state.jumpedListHadOverride = false
    state.jumpedListOriginalMovePrevious = nil
end

---While the header is active after a jump, "up" reaches list:MovePrevious on the deactivated
---list (stock UpdateDirectionalInput, index ~= 1). Leave the header instead, like "down".
---Installed on the list instance only; the class method is untouched.
---@param screen table
---@param target JumpToSearchScreenTarget
---@param list table
local function InstallMovePreviousOverride(screen, target, list)
    local state = State()
    -- rawget: only shadow an instance-level value, never the class method
    state.jumpedListOriginalMovePrevious = rawget(list, "MovePrevious")
    state.jumpedListHadOverride = true

    rawset(list, "MovePrevious", function(self, ...)
        if state.jumpedScreen == screen and screen.IsHeaderActive and screen:IsHeaderActive() then
            Log.Debug("%s: up in header -> return to list (index %s)", target.name, tostring(ScreenUtils.GetSelectedIndex(self)))
            state.counters.returns = state.counters.returns + 1
            screen:RequestLeaveHeader()
            return true
        end
        -- Not our situation (should not happen: the override is removed on header deactivate).
        local original = state.jumpedListOriginalMovePrevious or getmetatable(self).__index.MovePrevious
        return original(self, ...)
    end)
end

---Register once per screen: forget the jump whenever the header gives up focus
---(down, back button, scene hide, list refresh entering/leaving the header).
---@param screen table
---@param target JumpToSearchScreenTarget
local function EnsureHeaderHooks(screen, target)
    local state = State()
    if state.hookedScreens[screen] then
        return
    end

    local headerFocus = screen.headerFocus
    if headerFocus and headerFocus.RegisterCallback then
        headerFocus:RegisterCallback("FocusDeactivated", function()
            if state.jumpedScreen == screen then
                Log.Debug("%s: header deactivated; jump cleared", target.name)
                ClearJump()
            end
        end)
    end

    state.hookedScreens[screen] = true
end

---Enter the search header of the active screen from wherever the list selection is.
---@return boolean jumped
function FocusActions.TryJump()
    local state = State()
    local target = state.activeTarget
    if not target then
        return false
    end

    local screen = target.getScreen()
    local canJump, reason = ScreenUtils.CanJump(screen)
    if not canJump or not screen then
        Log.Debug("%s: no jump (%s)", target.name, reason)
        return false
    end

    local list = target.getList(screen)
    local index = ScreenUtils.GetSelectedIndex(list)

    EnsureHeaderHooks(screen, target)
    ClearJump()
    screen:RequestEnterHeader()
    if not screen:IsHeaderActive() then
        Log.Debug("%s: RequestEnterHeader refused (CanEnterHeader false)", target.name)
        return false
    end

    state.jumpedScreen = screen
    state.jumpedList = list
    state.jumpedIndex = index
    if list then
        InstallMovePreviousOverride(screen, target, list)
    end
    state.counters.jumps = state.counters.jumps + 1
    Log.Debug("%s: jumped to search from index %s of %s", target.name, tostring(index), tostring(ScreenUtils.GetNumItems(list)))

    if state.savedVars.openKeyboard then
        screen:SetTextSearchFocused(true)
    end
    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    return true
end

---Bindings.xml <Down>. Return true to consume R3, false to let the screen's own R3 keybind run.
---@return boolean
function FocusActions.OnJumpKeyDown()
    local state = State()
    if not state then
        return false
    end
    state.counters.keyDowns = state.counters.keyDowns + 1

    consumedDown = false
    if not state.savedVars.enabled then
        return false
    end

    consumedDown = FocusActions.TryJump()
    if not consumedDown then
        state.counters.fallthroughs = state.counters.fallthroughs + 1
    end
    return consumedDown
end

---Bindings.xml <Up>. Mirror the down decision so the game's R3 keybind sees a matched pair.
---@return boolean
function FocusActions.OnJumpKeyUp()
    local handled = consumedDown
    consumedDown = false
    return handled
end

---Called by Main on target scene state changes; owns our action layer's lifetime.
---@param target JumpToSearchScreenTarget
---@param newState string
function FocusActions.OnTargetSceneStateChanged(target, newState)
    local state = State()
    if newState == SCENE_SHOWN then
        -- Push at SHOWN, not SHOWING: the game's UI-shortcut action layer fragment (which owns
        -- the stock R3 handler) re-pushes itself while the scene is SHOWING, and whichever layer
        -- is pushed last gets the button first.
        state.activeTarget = target
        if not state.layerPushed then
            PushActionLayerByName(JumpToSearch.actionLayerName)
            state.layerPushed = true
            Log.Debug("%s shown; action layer pushed", target.name)
        end
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        if state.layerPushed then
            RemoveActionLayerByName(JumpToSearch.actionLayerName)
            state.layerPushed = false
            Log.Debug("%s hidden; action layer removed", target.name)
        end
        if state.activeTarget == target then
            state.activeTarget = nil
        end
        ClearJump()
    end
end

JumpToSearch.FocusActions = FocusActions
