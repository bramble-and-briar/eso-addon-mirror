-- ErrorCatcherButtonActions.lua: the moment a button is added whose callback the game does not trust
--
-- A button's callback built while add-on code is on the stack is untrusted for good: pressing it raises
-- "private function ... from insecure code" wherever it ends in a private call (withdraw, deposit, ready
-- check), and the error names the button, not the add-on. Gamepad dialogs build their button objects the
-- first time a dialog of that size shows and add them to the strip in the same call, so the stack at that
-- moment still holds whoever caused it. Every hook here is a SecurePostHook: it runs after the game's
-- function has returned and leaves nothing of this add-on on its stack.
local ButtonActions = {}

local Log = ErrorCatcher.LogUtils
local GameUtils = ErrorCatcher.GameUtils
local TraceUtils = ErrorCatcher.TraceUtils
local ButtonUtils = ErrorCatcher.ButtonUtils
local HookUtils = ErrorCatcher.HookUtils

local MAX_CHAIN_FRAMES = 14

---@return ErrorCatcherFrame[] frames The stack without this add-on's own frames
local function StackHere()
    return TraceUtils.Foreign(TraceUtils.Frames(GameUtils.Traceback()), ErrorCatcher.name)
end

---@param descriptor table
---@param index number
local function CheckDescriptor(descriptor, index)
    local callback = descriptor.callback
    if type(callback) ~= "function" then
        return
    end
    local state = ErrorCatcher.state
    if state.checkedCallbacks[callback] then
        return
    end
    state.checkedCallbacks[callback] = true

    local trusted = GameUtils.IsTrusted(callback)
    if trusted == nil then
        return
    end
    local dialogName = ButtonUtils.DialogName(descriptor)
    if trusted then
        if dialogName and not state.poolConfirmed then
            state.poolConfirmed = true
            Log.Line("dialog buttons built trusted (first seen on dialog %s)", dialogName)
        end
        return
    end

    state.counters.untrustedButtons = state.counters.untrustedButtons + 1
    local label = ButtonUtils.Label(descriptor, index, GameUtils.SceneName(), dialogName)
    if Log.Seen(label) then
        return
    end
    -- A dialog's buttons are built frames after the dialog was asked for, on a stack that no longer holds
    -- who asked: what the asking went through is the cause, so it is said first.
    local shown = state.lastDialogShow
    if dialogName and shown and shown.name == dialogName then
        Log.Once(label, "UNTRUSTED %s | when its dialog was asked for: %s | when it was built: %s",
            label, shown.summary, TraceUtils.Summary(StackHere(), MAX_CHAIN_FRAMES))
        return
    end
    Log.Once(label, "UNTRUSTED %s | %s", label, TraceUtils.Summary(StackHere(), MAX_CHAIN_FRAMES))
end

---After ZO_KeybindStrip:AddKeybindButtonGroup.
---@param _strip table
---@param group any
function ButtonActions.OnGroupAdded(_strip, group)
    if type(group) ~= "table" then
        return
    end
    for index, descriptor in ipairs(group) do
        if type(descriptor) == "table" then
            CheckDescriptor(descriptor, index)
        end
    end
end

---After ZO_Dialogs_ShowDialog, which every dialog goes through: who asked for it.
---@param name any
---@param _data any
---@param _textParams any
---@param isGamepad any
function ButtonActions.OnDialogShow(name, _data, _textParams, isGamepad)
    local state = ErrorCatcher.state
    state.counters.dialogs = state.counters.dialogs + 1
    local frames = StackHere()
    -- The trace holds the wrappers placed after this add-on's own hook; one placed before sits inside it and
    -- is known only from the trust read at file scope.
    local summary = string.format("addons on stack: %s | wrapped by a hook: %s%s",
        TraceUtils.ListOrNone(TraceUtils.Addons(frames)),
        TraceUtils.ListOrNone(HookUtils.NameHookers(TraceUtils.Wrapped(frames), state.hookersByFn)),
        state.wrappedBeforeLoad.ZO_Dialogs_ShowDialog and " | also wrapped before this add-on loaded (by one of the add-ons the scan lists as loaded before)" or "")
    state.lastDialogShow = { name = tostring(name), summary = summary }
    local key = string.format("dialog %s%s | %s", tostring(name), isGamepad and " (gamepad)" or "", summary)
    if Log.Seen(key) then
        return
    end
    Log.Once(key, "%s | frames: %s", key, #frames > 0 and TraceUtils.Chain(frames, MAX_CHAIN_FRAMES) or "no stack reported")
end

---After ZO_SceneManager_Leader:Show, which Push goes through too. A game screen builds its buttons the first
---time its scene shows, so a scene first shown from add-on code has untrusted buttons until the UI reloads.
---Only a show with an add-on or a hook wrapper on the stack is written.
---@param _manager table
---@param sceneName any
function ButtonActions.OnSceneShow(_manager, sceneName)
    local frames = StackHere()
    local addons, wrapped = TraceUtils.Addons(frames), TraceUtils.Wrapped(frames)
    if #addons == 0 and #wrapped == 0 then
        return
    end
    local key = string.format("scene %s shown from add-on code | addons on stack: %s | wrapped by a hook: %s",
        tostring(sceneName), TraceUtils.ListOrNone(addons), TraceUtils.ListOrNone(wrapped))
    if Log.Seen(key) then
        return
    end
    Log.Once(key, "%s | frames: %s", key, TraceUtils.Chain(frames, MAX_CHAIN_FRAMES))
end

---@return string[] installed Names of the hooks placed
function ButtonActions.Install()
    local installed = {}
    if GameUtils.SecureHook(ZO_KeybindStrip, "AddKeybindButtonGroup", "OnGroupAdded", ButtonActions.OnGroupAdded) then
        installed[#installed + 1] = "ZO_KeybindStrip.AddKeybindButtonGroup"
    end
    if GameUtils.SecureHook(_G, "ZO_Dialogs_ShowDialog", "OnDialogShow", ButtonActions.OnDialogShow) then
        installed[#installed + 1] = "ZO_Dialogs_ShowDialog"
    end
    if GameUtils.SecureHook(ZO_SceneManager_Leader, "Show", "OnSceneShow", ButtonActions.OnSceneShow) then
        installed[#installed + 1] = "ZO_SceneManager_Leader.Show"
    end
    return installed
end

ErrorCatcher.ButtonActions = ButtonActions
