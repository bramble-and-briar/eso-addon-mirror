-- Replaces the native in-game battleground scoreboard with Scoreboard Remastered.
--
-- ESO's scoreboard toggle key shows one of two native scenes:
--   battleground_scoreboard_in_game     a HUD scene (you can still move and fight)
--   battleground_scoreboard_in_game_ui  the same in UI mode (cursor)
-- With sv.replaceNativeScoreboard on, the native board's fragment is taken out of
-- both scenes and our table is shown in its place, with its own keybind buttons.
-- The scenes themselves stay ESO's: the same key opens and closes them, the same
-- key layer ("BattlegroundScoreboard") stays active, nothing of ESO's is wrapped,
-- and no key layer is pushed (see UI/ScoreboardHook.lua for why that matters).
--
-- Buttons while the board is up (gamepad): only keys the native board already takes,
-- plus D-pad left / right and R3, so attacking, blocking and abilities keep working:
--   D-pad up / down     select (the native board's own previous / next player keys)
--   D-pad left / right  sort by the previous / next column
--   Player options key  show / hide details
--   R3                  full screen (kill feed, history, records: UI/Gamepad.lua)
--   Scoreboard key      close            Leave key   leave the battleground
-- On PC the mouse works in UI mode; the same previous / next keys move the selection.
-- The end-of-game scoreboard stays native (it has the round summary and queue
-- options); there the panel opens over it as before.
local SBR = ScoreboardRemastered
local R = { active = {}, installed = false }
SBR.Replace = R

local SCENE_NAMES = { "battleground_scoreboard_in_game", "battleground_scoreboard_in_game_ui" }
local IS_REPLACED_SCENE = { battleground_scoreboard_in_game = true, battleground_scoreboard_in_game_ui = true }

function R:IsEnabled()
    return SBR.sv.replaceNativeScoreboard ~= false
end

function R:IsReplacedScene(name)
    return IS_REPLACED_SCENE[name] == true and self:IsEnabled()
end

local function GetScene(name)
    return SCENE_MANAGER and SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(name) or nil
end

-- Take the native board out of (or put it back into) the two in-game scenes.
function R:Apply()
    local board = BATTLEGROUND_SCOREBOARD_FRAGMENT
    if not board then return end
    for _, name in ipairs(SCENE_NAMES) do
        local scene = GetScene(name)
        if scene and scene.HasFragment then
            local has = scene:HasFragment(board)
            if self:IsEnabled() and has then
                scene:RemoveFragment(board)
            elseif not self:IsEnabled() and not has then
                scene:AddFragment(board)
            end
        end
    end
end

function R:Install()
    if self.installed or not SCENE_MANAGER then return end
    local any = false
    for _, name in ipairs(SCENE_NAMES) do
        local scene = GetScene(name)
        if scene and scene.RegisterCallback then
            any = true
            scene:RegisterCallback("StateChange", function(_, newState) R:OnSceneState(name, newState) end)
        end
    end
    if not any then return end
    self.installed = true
    self:Apply()
end

function R:SetEnabled(on)
    SBR.sv.replaceNativeScoreboard = on
    self:Apply()
end

function R:IsShowing()
    return next(self.active) ~= nil
end

-- Our callbacks run after the native scene's own (registered first), so at SHOWING
-- the native buttons and the match-info side panel have just been added: swap them.
function R:OnSceneState(name, newState)
    if not self:IsEnabled() then return end
    if newState == SCENE_SHOWING then
        self.active[name] = true
        self:Show(GetScene(name))
    elseif newState == SCENE_HIDDEN then
        self.active[name] = nil
        if not self:IsShowing() then self:Hide() end
    end
end

local function NativeKeybindGroups()
    local native = ZO_BATTLEGROUND_SCOREBOARD_IN_GAME
    if not native then return {} end
    return { native.keybindStripDescriptor, native.listNavigationKeybindStripDescriptor }
end

function R:Show(scene)
    -- the match info side panel would sit under our details pane
    if scene and FRAGMENT_GROUP then
        for _, group in ipairs({ FRAGMENT_GROUP.BATTLEGROUND_MATCH_INFO_KEYBOARD_GROUP, FRAGMENT_GROUP.BATTLEGROUND_MATCH_INFO_GAMEPAD_GROUP }) do
            if group then scene:RemoveFragmentGroup(group) end
        end
    end
    for _, group in ipairs(NativeKeybindGroups()) do
        if group then KEYBIND_STRIP:RemoveKeybindButtonGroup(group) end
    end
    if not self.keybinds then self:BuildKeybinds() end
    if not self.keybindsAdded then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
        self.keybindsAdded = true
    end
    SBR.Window:ShowReplacement()
end

function R:Hide()
    SBR.Gamepad.StopDPadRepeat()
    if self.keybindsAdded then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
        self.keybindsAdded = false
    end
    SBR.Window:HideReplacement()
end

-- Same as the native close button.
function R:Close()
    if not self:IsShowing() then return end
    SCENE_MANAGER:RestoreHUDScene()
    SCENE_MANAGER:RestoreHUDUIScene()
end

function R:UpdateKeybinds()
    if self.keybindsAdded then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds) end
end

local function Repeating(fn)
    -- hold-to-repeat on a keybind that sends key ups
    return function(up)
        SBR.Gamepad.StopDPadRepeat()
        if up then return end
        fn()
        SBR.Gamepad.StartDPadRepeat(fn)
    end
end

function R:BuildKeybinds()
    local W = SBR.Window
    local gamepad = function() return SBR.IsGamepad() end
    self.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_BATTLEGROUND_SCOREBOARD_CLOSE),
            keybind = "HIDE_BATTLEGROUND_SCOREBOARD",
            callback = function() R:Close() end,
        },
        {
            name = GetString(SI_BATTLEGROUND_SCOREBOARD_LEAVE_BATTLEGROUND),
            keybind = "LEAVE_BATTLEGROUND",
            callback = function()
                if SOUNDS and SOUNDS.BATTLEGROUND_LEAVE_MATCH then PlaySound(SOUNDS.BATTLEGROUND_LEAVE_MATCH) end
                ZO_Dialogs_ShowPlatformDialog("CONFIRM_LEAVE_BATTLEGROUND")
            end,
        },
        {
            name = function() return W.detailsOpen and "Hide details" or "Details" end,
            keybind = "BATTLEGROUND_SCOREBOARD_PLAYER_OPTIONS",
            callback = function() W:ToggleDetails(); R:UpdateKeybinds() end,
            visible = gamepad,
        },
        {
            keybind = "BATTLEGROUND_SCOREBOARD_PREVIOUS",
            ethereal = true,
            handlesKeyUp = true,
            callback = Repeating(function() W:MoveSelection(-1) end),
        },
        {
            keybind = "BATTLEGROUND_SCOREBOARD_NEXT",
            ethereal = true,
            handlesKeyUp = true,
            callback = Repeating(function() W:MoveSelection(1) end),
        },
        {
            keybind = "SBR_SCOREBOARD_SORT_PREVIOUS",
            ethereal = true,
            handlesKeyUp = true,
            callback = Repeating(function() W:CycleSort(-1) end),
            enabled = gamepad,
        },
        {
            keybind = "SBR_SCOREBOARD_SORT_NEXT",
            ethereal = true,
            handlesKeyUp = true,
            callback = Repeating(function() W:CycleSort(1) end),
            enabled = gamepad,
        },
        {
            name = "Full screen",
            keybind = "SBR_SCOREBOARD_OPEN_RIGHT_STICK",
            callback = function() SBR.Gamepad:Open() end,
            visible = gamepad,
        },
    }
end
ScoreboardRemastered.Mark("UI/Replace.lua")
