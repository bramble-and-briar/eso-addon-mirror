-- Main.lua: entry point; wires saved vars, slash command, and scene hooks
local Log = JumpToSearch.LogUtils
local ScreenUtils = JumpToSearch.ScreenUtils
local FocusActions = JumpToSearch.FocusActions

-- File scope so "/jts" answers even if Initialize fails part-way.
SLASH_COMMANDS["/jts"] = function(args)
    JumpToSearch.SlashCommandActions.HandleCommand(args)
end
SLASH_COMMANDS["/jumptosearch"] = SLASH_COMMANDS["/jts"]

---Subscribe to one target's scene, once.
---@param target JumpToSearchScreenTarget
---@return boolean hooked
local function HookTargetScene(target)
    if target.hooked then
        return true
    end
    local scene = SCENE_MANAGER:GetScene(target.sceneName)
    if not scene then
        Log.Debug("scene '%s' (%s) not registered; skipped", target.sceneName, target.name)
        return false
    end
    scene:RegisterCallback("StateChange", function(_oldState, newState)
        FocusActions.OnTargetSceneStateChanged(target, newState)
    end)
    target.hooked = true
    return true
end

---Subscribe to every target scene via the scene manager so we never need the screen
---globals at load time (some are created lazily by their XML OnInitialized).
local function HookTargetScenes()
    local hooked = 0
    for _, target in ipairs(ScreenUtils.TARGETS) do
        if HookTargetScene(target) then
            hooked = hooked + 1
        end
    end
    return hooked
end

---Public: let another add-on's gamepad screen take the jump. The screen has to be built on the
---stock search header (ZO_Gamepad_ParametricList_Screen:AddSearch) and its scene has to exist.
---Call it once the scene is created; calling before this add-on has loaded works too.
---@param name string short label for logs
---@param sceneName string
---@param getScreen fun(): table|nil
---@param getList (fun(screen: table): table|nil)|nil default: screen:GetCurrentList()
---@return boolean registered
function JumpToSearch.RegisterScreen(name, sceneName, getScreen, getList)
    local target = ScreenUtils.AddTarget(name, sceneName, getScreen, getList)
    if not target then
        return false
    end
    -- Before Initialize the target is hooked with the built-in ones.
    if JumpToSearch.state then
        if not HookTargetScene(target) then
            -- No scene to follow: leave no target behind, so the caller can register again later.
            for index, candidate in ipairs(ScreenUtils.TARGETS) do
                if candidate == target then
                    table.remove(ScreenUtils.TARGETS, index)
                    break
                end
            end
            return false
        end
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene and scene:GetState() == SCENE_SHOWN then
            FocusActions.OnTargetSceneStateChanged(target, SCENE_SHOWN)
        end
        Log.Debug("screen '%s' registered for scene '%s'", name, sceneName)
    end
    return true
end

local function Initialize()
    local State = JumpToSearch.State

    JumpToSearch.state = State.Create()
    JumpToSearch.state.savedVars = ZO_SavedVars:NewAccountWide(
        JumpToSearch.savedVarsName,
        JumpToSearch.savedVarsVersion,
        nil,
        JumpToSearch.state.savedVars
    )

    local hooked = HookTargetScenes()
    Log.Debug("Loaded v%s; hooked %d/%d scenes", JumpToSearch.version, hooked, #ScreenUtils.TARGETS)
end

EVENT_MANAGER:RegisterForEvent(JumpToSearch.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == JumpToSearch.name then
        EVENT_MANAGER:UnregisterForEvent(JumpToSearch.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)
