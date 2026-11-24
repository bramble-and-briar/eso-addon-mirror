-- ErrorCatcherGameUtils.lua: thin, guarded reads of the game API (no side effects)
local GameUtils = {}

---Whether IsTrustedFunction can be called. A private function raises an error pcall cannot catch when it
---is so much as named, so the name is asked about first.
---@return boolean
function GameUtils.DetectTrustApi()
    if type(IsPrivateFunction) == "function" and IsPrivateFunction("IsTrustedFunction") then
        return false
    end
    if type(IsProtectedFunction) == "function" and IsProtectedFunction("IsTrustedFunction") then
        return false
    end
    return type(IsTrustedFunction) == "function"
end

---@param fn function
---@return boolean|nil trusted nil when the game cannot be asked
function GameUtils.IsTrusted(fn)
    if not ErrorCatcher.state.trustApi then
        return nil
    end
    local ok, trusted = pcall(IsTrustedFunction, fn)
    if not ok then
        return nil
    end
    return trusted == true
end

---@return boolean
function GameUtils.HasTraceback()
    return type(debug) == "table" and type(debug.traceback) == "function"
end

---The stack at the call, as text; "" when the game offers no traceback.
---@return string
function GameUtils.Traceback()
    if not GameUtils.HasTraceback() then
        return ""
    end
    local ok, trace = pcall(debug.traceback)
    if ok and type(trace) == "string" then
        return trace
    end
    return ""
end

---@return string
function GameUtils.SceneName()
    if not (SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName) then
        return "?"
    end
    local ok, name = pcall(SCENE_MANAGER.GetCurrentSceneName, SCENE_MANAGER)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end
    return "?"
end

---Wrap a hook body so an error in it never reaches the game call it follows.
---@param label string
---@param fn function
---@return function
function GameUtils.Guard(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            ErrorCatcher.LogUtils.Once("guard:" .. label, "internal error in %s: %s", label, tostring(err))
        end
    end
end

---Follow a game function with a SecurePostHook: fn runs after it has returned, with its arguments, and
---leaves nothing of this add-on on its stack. Never ZO_PostHook, whose wrapper is the fault this add-on
---looks for.
---@param target any The table holding the function (a class, or _G)
---@param name string
---@param label string
---@param fn function
---@return boolean placed
function GameUtils.SecureHook(target, name, label, fn)
    if type(SecurePostHook) ~= "function" or type(target) ~= "table" or type(target[name]) ~= "function" then
        return false
    end
    return (pcall(SecurePostHook, target, name, GameUtils.Guard(label, fn)))
end

ErrorCatcher.GameUtils = GameUtils
