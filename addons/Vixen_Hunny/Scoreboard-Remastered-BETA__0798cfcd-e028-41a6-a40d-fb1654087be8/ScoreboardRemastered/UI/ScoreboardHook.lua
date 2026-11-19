-- Hooks the native battleground scoreboard: our panel opens/closes with it and
-- anchors next to it.
--
-- Only scene / fragment state callbacks are used. Nothing of ESO's is wrapped or
-- replaced (no ZO_PostHook / ZO_PreHook) and no key layer is pushed: either would
-- put add-on code into the scoreboard's own input handling (D-pad player selection,
-- player options), which then fails with an "insecure code" error. Data comes from
-- EVENT_BATTLEGROUND_SCOREBOARD_UPDATED. `/sbr hooks` lists what was found.
local SBR = ScoreboardRemastered
local Hook = { fragments = {}, scenes = {}, visible = {} }
SBR.Hook = Hook

local FRAGMENT_NAMES = {
    "BATTLEGROUND_SCOREBOARD_FRAGMENT",
    "KEYBOARD_BATTLEGROUND_SCOREBOARD_FRAGMENT",
    "BATTLEGROUND_SCOREBOARD_KEYBOARD_FRAGMENT",
    "BATTLEGROUND_SCOREBOARD_END_OF_GAME_FRAGMENT",
    "GAMEPAD_BATTLEGROUND_SCOREBOARD_FRAGMENT",
}
local CONTROL_NAMES = {
    "ZO_BattlegroundScoreboardTopLevel",
    "ZO_BattlegroundScoreboard_KeyboardTopLevel",
    "ZO_Battleground_Scoreboard_KeyboardTopLevel",
    "ZO_BattlegroundScoreboardEndOfGameTopLevel",
}

local SHOWN = { [SCENE_SHOWN or "shown"] = true, [SCENE_FRAGMENT_SHOWN or "shown"] = true }
local HIDDEN = { [SCENE_HIDDEN or "hidden"] = true, [SCENE_FRAGMENT_HIDDEN or "hidden"] = true,
                 [SCENE_HIDING or "hiding"] = true, [SCENE_FRAGMENT_HIDING or "hiding"] = true }

local function IsScoreboardName(name)
    local n = name:lower()
    return n:find("battleground", 1, true) and n:find("scoreboard", 1, true)
end

function Hook:OnVisibility(id, control, newState)
    -- the in-game board's scenes are handled by UI/Replace.lua while it replaces them
    local sceneName = id:match("^scene:(.+)$")
    if sceneName and SBR.Replace and SBR.Replace:IsReplacedScene(sceneName) then
        if SHOWN[newState] then SBR.MatchLog:RequestSnapshot() end
        return
    end
    if SHOWN[newState] then
        self.visible[id] = control or true
        if control then self.anchorControl = control end
        SBR.Debug("native scoreboard shown (%s)", id)
        SBR.MatchLog:RequestSnapshot()
        if SBR.IsGamepad() then
            -- no cursor: offer a button on the native scoreboard's keybind strip instead.
            -- Its key is an action in the scoreboard's own "BattlegroundScoreboard"
            -- layer (Bindings.xml), so no layer has to be pushed.
            SBR.Gamepad:AddOpenKeybind()
        else
            SBR.Window:OnNativeShown()
        end
    elseif HIDDEN[newState] then
        self.visible[id] = nil
        if next(self.visible) == nil then
            SBR.Debug("native scoreboard hidden (%s)", id)
            SBR.Gamepad:RemoveOpenKeybind()
            if not SBR.IsGamepad() then SBR.Window:OnNativeHidden() end
        end
    end
end

function Hook:IsNativeVisible()
    return next(self.visible) ~= nil
end

-- The native top level (ZO_BattlegroundScoreboardTopLevel) fills the whole screen;
-- the visible board is its "Backgrounds" child (about 1300 x 900, centred), so
-- relative placement uses that.
function Hook:GetAnchorControl()
    local board = _G.ZO_BattlegroundScoreboardTopLevelBackgrounds
    if board and not board:IsHidden() and self:IsNativeVisible() then return board end
    if self.anchorControl and not self.anchorControl:IsHidden() then return self.anchorControl end
    for _, name in ipairs(CONTROL_NAMES) do
        local c = _G[name]
        if type(c) == "userdata" and not c:IsHidden() then return c end
    end
    return nil
end

function Hook:HookFragment(name, fragment)
    if type(fragment) ~= "table" or type(fragment.RegisterCallback) ~= "function" or self.fragments[name] then return end
    self.fragments[name] = fragment
    local control = fragment.control or (fragment.GetControl and SBR.SafeCall(fragment.GetControl, fragment))
    fragment:RegisterCallback("StateChange", function(_, newState)
        Hook:OnVisibility("fragment:" .. name, control, newState)
    end)
end

function Hook:HookScene(name, scene)
    if type(scene) ~= "table" or type(scene.RegisterCallback) ~= "function" or self.scenes[name] then return end
    self.scenes[name] = scene
    scene:RegisterCallback("StateChange", function(_, newState)
        Hook:OnVisibility("scene:" .. name, nil, newState)
    end)
end

function Hook:Install()
    -- every loading screen calls this; after the first complete pass there is
    -- nothing new to find
    if self.installed then return end
    for _, n in ipairs(FRAGMENT_NAMES) do self:HookFragment(n, _G[n]) end

    -- Known names only (from the ESO UI source, API 101051). Scanning _G for others
    -- walked tens of thousands of globals and cost a large frame spike on load.
    if SCENE_MANAGER and type(SCENE_MANAGER.scenes) == "table" then
        for name, scene in pairs(SCENE_MANAGER.scenes) do
            if type(name) == "string" and IsScoreboardName(name) then self:HookScene(name, scene) end
        end
        self.installed = next(self.fragments) ~= nil or next(self.scenes) ~= nil
    end
end

function Hook:Report()
    local function keys(t)
        local list = {}
        for k, v in pairs(t) do
            list[#list + 1] = type(v) == "table" and #v > 0 and (k .. "(" .. table.concat(v, ",") .. ")") or k
        end
        table.sort(list)
        return #list > 0 and table.concat(list, ", ") or "none"
    end
    SBR.Print("fragments: %s", keys(self.fragments))
    SBR.Print("scenes: %s", keys(self.scenes))
    local a = self:GetAnchorControl()
    SBR.Print("anchor control: %s", a and a:GetName() or "none (native scoreboard not open)")
end
ScoreboardRemastered.Mark("UI/ScoreboardHook.lua")
