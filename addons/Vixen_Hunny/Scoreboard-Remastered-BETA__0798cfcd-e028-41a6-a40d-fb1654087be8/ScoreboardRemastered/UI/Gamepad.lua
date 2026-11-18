-- Console / gamepad support.
--
-- In gamepad mode (always on console, or "Gamepad mode" on PC) Scoreboard Remastered
-- is the same table as on PC, in its own scene, driven by the controller:
--   D-pad / left stick up-down      move the selected row (hold to repeat)
--   D-pad / left stick left-right   sort by the previous / next column
--   A (Xbox) / Cross (PlayStation)  show / hide details for the selected row
--   B / Circle                      close details, then close the table
--   X / Square                      flip the sort order
--   Y / Triangle                    kill feed (console list screen, UI/Console.lua)
--   LB / RB (L1 / R1)               previous / next saved match
--   LT / RT (L2 / R2)               page up / down
--   Left stick click (L3)           group by team on / off
--   Right stick click (R3)          battleground records (console list screen)
-- The kill feed, match summary and records use ESO's native gamepad list screens.
-- Setting "consoleLayout" = "list" uses the list screen for the scoreboard too.
-- While the native battleground scoreboard is open, "Open Remastered" (right stick
-- click by default) is added to its keybind strip.
local SBR = ScoreboardRemastered
local GP = { sceneName = "scoreboardRemasteredTable" }
SBR.Gamepad = GP

function SBR.IsGamepad()
    if type(IsConsoleUI) == "function" and IsConsoleUI() then return true end
    return type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode() == true
end

function SBR.IsConsole()
    return type(IsConsoleUI) == "function" and IsConsoleUI() == true
end

local OPEN_KEYS = {
    right_stick = { keybind = "UI_SHORTCUT_RIGHT_STICK", label = "Right stick click" },
    left_stick = { keybind = "UI_SHORTCUT_LEFT_STICK", label = "Left stick click" },
    quaternary = { keybind = "UI_SHORTCUT_QUATERNARY", label = "Quaternary button" },
}
GP.OPEN_KEYS = OPEN_KEYS

local function ListScreen() return SBR.Console and SBR.Console.scoreboard end

function GP:Init()
    if self.initialized then return end
    self.initialized = true
    -- switching between keyboard and gamepad mode on PC closes whichever view is open
    if EVENT_GAMEPAD_PREFERRED_MODE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(SBR.name .. "_GamepadMode", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
            if GP:IsShowing() then GP:Close() end
            SBR.Window:Hide(true)
            GP:RemoveOpenKeybind()
        end)
    end
end

-- The table scene, created on first use.
function GP:CreateTableScene()
    if self.scene or not (ZO_Scene and SCENE_MANAGER and KEYBIND_STRIP) then return self.scene end
    local W = SBR.Window
    W:Create()
    local scene = ZO_Scene:New(self.sceneName, SCENE_MANAGER)
    scene:AddFragment(ZO_SimpleSceneFragment:New(W.control))
    if FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW then
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    end
    for _, f in ipairs({ MINIMIZE_CHAT_FRAGMENT, GAMEPAD_MENU_SOUND_FRAGMENT }) do
        if f then scene:AddFragment(f) end
    end
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            GP:OnShowing()
        elseif newState == SCENE_HIDING then
            GP:OnHiding()
        end
    end)
    self.scene = scene
    if ZO_MovementController and MOVEMENT_CONTROLLER_DIRECTION_VERTICAL then
        self.vertical = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_VERTICAL)
        self.horizontal = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)
        -- right stick scrolls the details pane, with the same hold-to-repeat timing
        if ZO_DI_RIGHT_STICK then
            self.detailsScroll = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_VERTICAL, nil,
                function() return DIRECTIONAL_INPUT:GetY(ZO_DI_RIGHT_STICK) end)
        end
    end
    self:BuildKeybinds()
    return scene
end

local function UseList() return SBR.sv.consoleLayout == "list" end

function GP:IsShowing()
    if self.scene and self.scene:IsShowing() then return true end
    local s = ListScreen()
    return s ~= nil and s:IsShowingScene()
end

-- tab: nil / "players" opens the scoreboard (the table, or the list screen with
-- consoleLayout = "list"); "kills" | "match" open those tabs of the list screen.
function GP:Open(tab)
    self:Init()
    if (tab == nil or tab == "players") and not UseList() then
        if not self:CreateTableScene() then return end
        if not self.scene:IsShowing() then SCENE_MANAGER:Push(self.sceneName) end
        return
    end
    local s = ListScreen()
    if not s then return end
    -- opened on top of the table: keep its details for when B comes back
    if self.scene and self.scene:IsShowing() then self.coveredByChild = true end
    tab = tab or "players"
    if s.tab ~= tab then
        s.tab = tab
        local index = ({ players = 1, kills = 2, match = 3 })[tab]
        if index then ZO_GamepadGenericHeader_SetActiveTabIndex(s.header, index) end
    end
    s:Open()
end

function GP:Close()
    if self.scene and self.scene:IsShowing() then
        SCENE_MANAGER:HideCurrentScene() -- pops back to whatever opened it
        return
    end
    local s = ListScreen()
    if s then s:Close() end
end

function GP:OnShowing()
    self.coveredByChild = false
    SBR.Window:OnGamepadShown()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
    if DIRECTIONAL_INPUT then DIRECTIONAL_INPUT:Activate(self, SBR.Window.control) end
end

function GP:OnHiding()
    if DIRECTIONAL_INPUT then DIRECTIONAL_INPUT:Deactivate(self) end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
    SBR.Window:OnGamepadHidden(self.coveredByChild)
end

-- Called every frame by DIRECTIONAL_INPUT while the table is shown. The movement
-- controllers give ESO's own hold-to-repeat timing, as in every gamepad list.
function GP:UpdateDirectionalInput()
    if not self.vertical then return end
    local W = SBR.Window
    local v = self.vertical:CheckMovement()
    if v == MOVEMENT_CONTROLLER_MOVE_NEXT then W:MoveSelection(1)
    elseif v == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then W:MoveSelection(-1) end
    if self.detailsScroll then
        local r = self.detailsScroll:CheckMovement()
        if r == MOVEMENT_CONTROLLER_MOVE_NEXT then W:ScrollDetails(1)
        elseif r == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then W:ScrollDetails(-1) end
    end
    local h = self.horizontal:CheckMovement()
    if h == MOVEMENT_CONTROLLER_MOVE_NEXT then W:CycleSort(1)
    elseif h == MOVEMENT_CONTROLLER_MOVE_PREVIOUS then W:CycleSort(-1) end
end

function GP:BuildKeybinds()
    local W = SBR.Window
    self.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function() return W.detailsOpen and "Hide details" or "Details" end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function() W:ToggleDetails(); GP:UpdateKeybinds() end,
        },
        {
            name = "Back",
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                if W.detailsOpen then W:CloseDetails() else GP:Close() end
            end,
        },
        {
            name = function() return W.sort.desc and "Sort: high to low" or "Sort: low to high" end,
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function() W:ToggleSortOrder(); GP:UpdateKeybinds() end,
        },
        {
            name = "Kill feed",
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = function() GP:Open("kills") end,
        },
        {
            name = "Older",
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            callback = function() W:Step(-1); GP:UpdateKeybinds() end,
            visible = function() return #SBR.MatchLog:GetHistory() > 0 end,
        },
        {
            name = "Newer",
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            callback = function() W:Step(1); GP:UpdateKeybinds() end,
            visible = function() return W.viewIndex ~= nil end,
        },
        {
            keybind = "UI_SHORTCUT_LEFT_TRIGGER",
            ethereal = true,
            callback = function() W:MoveSelection(-(W.maxVisibleRows or 10)) end,
        },
        {
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            ethereal = true,
            callback = function() W:MoveSelection(W.maxVisibleRows or 10) end,
        },
        {
            name = function() return SBR.sv.groupByTeam and "Ungroup" or "Group by team" end,
            keybind = "UI_SHORTCUT_LEFT_STICK",
            callback = function() W:ToggleGroupByTeam(); GP:UpdateKeybinds() end,
        },
        {
            name = "Records",
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            callback = function()
                GP.coveredByChild = true
                SBR.MatchBrowser:Open()
            end,
        },
    }
end

function GP:UpdateKeybinds()
    if self.keybinds and self.scene and self.scene:IsShowing() then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
        return
    end
    local s = ListScreen()
    if s and s:IsShowingScene() then s:RefreshKeybinds() end
end

-- "Open Remastered" on the native battleground scoreboard's keybind strip.
function GP:AddOpenKeybind()
    if not KEYBIND_STRIP or self.openKeybindAdded then return end
    local key = OPEN_KEYS[SBR.sv.gamepadOpenKey] or OPEN_KEYS.right_stick
    self.openKeybind = {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        {
            name = "Open Remastered",
            keybind = key.keybind,
            callback = function() GP:Open() end,
        },
    }
    KEYBIND_STRIP:AddKeybindButtonGroup(self.openKeybind)
    self.openKeybindAdded = true
end

function GP:RemoveOpenKeybind()
    if self.openKeybindAdded and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.openKeybind)
    end
    self.openKeybindAdded = false
end
