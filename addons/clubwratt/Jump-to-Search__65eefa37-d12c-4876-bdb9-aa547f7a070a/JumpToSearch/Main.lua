-- Main.lua: entry point; wires saved vars, slash command, and scene hooks
local Log = JumpToSearch.LogUtils
local ScreenUtils = JumpToSearch.ScreenUtils
local FocusActions = JumpToSearch.FocusActions

-- File scope so "/jts" answers even if Initialize fails part-way.
SLASH_COMMANDS["/jts"] = function(args)
    JumpToSearch.SlashCommandActions.HandleCommand(args)
end
SLASH_COMMANDS["/jumptosearch"] = SLASH_COMMANDS["/jts"]

---Subscribe to every target scene via the scene manager so we never need the screen
---globals at load time (some are created lazily by their XML OnInitialized).
local function HookTargetScenes()
    local hooked = 0
    for _, target in ipairs(ScreenUtils.TARGETS) do
        local scene = SCENE_MANAGER:GetScene(target.sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(_oldState, newState)
                FocusActions.OnTargetSceneStateChanged(target, newState)
            end)
            hooked = hooked + 1
        else
            Log.Debug("scene '%s' (%s) not registered; skipped", target.sceneName, target.name)
        end
    end
    return hooked
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
