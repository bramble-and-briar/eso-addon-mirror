-- Console / gamepad support.
--
-- In gamepad mode (always on console, or "Gamepad mode" on PC) Scoreboard Remastered
-- is the same table as on PC, in its own scene, driven by the controller:
--   D-pad up / down                 move the selected row (hold to repeat)
--   D-pad left / right              sort by the previous / next column
--   A (Xbox) / Cross (PlayStation)  show / hide details for the selected row
--   B / Circle                      close details, then close the table
--   X / Square                      flip the sort order
--   Y / Triangle                    kill feed (console list screen, UI/Console.lua)
--   LB / RB (L1 / R1)               previous / next saved match
--   LT / RT (L2 / R2)               scroll the details when open, else page up / down
--   Left stick click (L3)           group by team on / off
--   Right stick click (R3)          battleground records (same PC-style window)
-- The D-pad is read through ESO's D-pad keybinds (UI_SHORTCUT_INPUT_*), not
-- DIRECTIONAL_INPUT, so no add-on code runs inside ESO's per-frame input loop.
-- The kill feed and match summary use ESO's native gamepad list screens.
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

-- keybind: the UI shortcut (our own screens, the inventory); scoreboardKeybind: the
-- matching action in the native scoreboard's "BattlegroundScoreboard" layer (Bindings.xml)
local OPEN_KEYS = {
    right_stick = { keybind = "UI_SHORTCUT_RIGHT_STICK", scoreboardKeybind = "SBR_SCOREBOARD_OPEN_RIGHT_STICK", label = "Right stick click" },
    left_stick = { keybind = "UI_SHORTCUT_LEFT_STICK", scoreboardKeybind = "SBR_SCOREBOARD_OPEN_LEFT_STICK", label = "Left stick click" },
    quaternary = { keybind = "UI_SHORTCUT_QUATERNARY", scoreboardKeybind = "SBR_SCOREBOARD_OPEN_QUATERNARY", label = "Quaternary button" },
}
GP.OPEN_KEYS = OPEN_KEYS

-- D-pad keybinds with hold-to-repeat, for a keybind group: handlers.up / down / left /
-- right are called once on press, then repeated while held (like ESO's lists).
local REPEAT_DELAY_MS, REPEAT_RATE_MS = 350, 75
local DPAD = { up = "UI_SHORTCUT_INPUT_UP", down = "UI_SHORTCUT_INPUT_DOWN",
               left = "UI_SHORTCUT_INPUT_LEFT", right = "UI_SHORTCUT_INPUT_RIGHT" }

local function StopRepeat()
    EVENT_MANAGER:UnregisterForUpdate(SBR.name .. "_DPadRepeat")
end

-- After a press: wait, then call fn repeatedly until StopRepeat (key up).
local function StartRepeat(fn)
    local ns = SBR.name .. "_DPadRepeat"
    EVENT_MANAGER:RegisterForUpdate(ns, REPEAT_DELAY_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(ns)
        EVENT_MANAGER:RegisterForUpdate(ns, REPEAT_RATE_MS, fn)
    end)
end

function GP.AddDPadKeybinds(group, handlers)
    for dir, keybind in pairs(DPAD) do
        local fn = handlers[dir]
        if fn then
            group[#group + 1] = {
                keybind = keybind,
                ethereal = true,
                handlesKeyUp = true,
                callback = function(up)
                    StopRepeat()
                    if up then return end
                    fn()
                    StartRepeat(fn)
                end,
            }
        end
    end
    return group
end
GP.StopDPadRepeat = StopRepeat
GP.StartDPadRepeat = StartRepeat

-- ListScreen(): the list screen, created if needed; ShownListScreen(): only if it exists
local function ListScreen() return SBR.Console and SBR.Console.scoreboard end
local function ShownListScreen() return SBR.Console and SBR.Console:Peek("scoreboard") end

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
    self:BuildKeybinds()
    return scene
end

local function UseList() return SBR.sv.consoleLayout == "list" end

function GP:IsShowing()
    if self.scene and self.scene:IsShowing() then return true end
    local s = ShownListScreen()
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
    local s = ShownListScreen()
    if s then s:Close() end
end

function GP:OnShowing()
    self.coveredByChild = false
    SBR.Window:OnGamepadShown()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
end

function GP:OnHiding()
    StopRepeat()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
    SBR.Window:OnGamepadHidden(self.coveredByChild)
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
            callback = function()
                if W.detailsOpen and W:CanScrollDetails() then W:ScrollDetails(-5) else W:MoveSelection(-(W.maxVisibleRows or 10)) end
            end,
        },
        {
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            ethereal = true,
            callback = function()
                if W.detailsOpen and W:CanScrollDetails() then W:ScrollDetails(5) else W:MoveSelection(W.maxVisibleRows or 10) end
            end,
        },
        {
            name = function() return SBR.sv.groupByTeam and "Ungroup" or "Group by team" end,
            keybind = "UI_SHORTCUT_LEFT_STICK",
            callback = function() W:ToggleGroupByTeam(); GP:UpdateKeybinds() end,
        },
        {
            name = "Report",
            keybind = "UI_SHORTCUT_QUATERNARY",
            visible = function() return W:CanOpenReport() end,
            callback = function()
                GP.coveredByChild = true
                W:OpenReport()
            end,
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
    GP.AddDPadKeybinds(self.keybinds, {
        up = function() W:MoveSelection(-1) end,
        down = function() W:MoveSelection(1) end,
        left = function() W:CycleSort(-1) end,
        right = function() W:CycleSort(1) end,
    })
end

function GP:UpdateKeybinds()
    if SBR.Replace and SBR.Replace:IsShowing() and not (self.scene and self.scene:IsShowing()) then
        SBR.Replace:UpdateKeybinds()
        return
    end
    if self.keybinds and self.scene and self.scene:IsShowing() then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds)
        return
    end
    local s = ShownListScreen()
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
            keybind = key.scoreboardKeybind,
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
ScoreboardRemastered.Mark("UI/Gamepad.lua")
