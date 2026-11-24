-- ErrorCatcherHookActions.lua: which add-on wraps which game function
--
-- ZO_PreHook and ZO_PostHook replace a game function with a wrapper built on the add-on's stack. This
-- follows each call to them (a SecurePostHook, so nothing of this add-on is on their stack) and reads the
-- add-on off the trace. It sees the hooks placed after this add-on loaded; the scan lists the wrapped
-- functions whoever placed them.
local HookActions = {}

local Log = ErrorCatcher.LogUtils
local GameUtils = ErrorCatcher.GameUtils
local TraceUtils = ErrorCatcher.TraceUtils
local HookUtils = ErrorCatcher.HookUtils

---@param target any A control
---@return string|nil
local function ControlName(target)
    local ok, name = pcall(function() return target:GetName() end)
    return ok and type(name) == "string" and name ~= "" and name or nil
end

---Name a record's table from the scan's map of game tables, and let go of the table.
---@param record ErrorCatcherHookRecord
local function Resolve(record)
    if record.target ~= nil then
        record.targetName = record.targetName or ErrorCatcher.state.tableNames[record.target]
        record.target = nil
    end
end

---@param kind string
---@param first any
---@param second any
local function OnHook(kind, first, second)
    local frames = TraceUtils.Foreign(TraceUtils.Frames(GameUtils.Traceback()), ErrorCatcher.name)
    local addon = TraceUtils.Addons(frames)[1]
    if not addon then
        return
    end
    local state = ErrorCatcher.state
    state.counters.hooks = state.counters.hooks + 1

    ---@type ErrorCatcherHookRecord
    local record = { addon = addon, kind = kind, fnName = tostring(second) }
    if HookUtils.IsHandlerKind(kind) then
        record.targetName = ControlName(first)
    else
        record.target, record.fnName = HookUtils.Target(first, second, _G)
        if record.target == _G then
            record.target, record.targetName = nil, "_G"
        end
    end

    if state.hooksSummarized then
        Resolve(record)
        local text = HookUtils.Describe(record)
        Log.Once("hook:" .. addon .. ":" .. text, "hook by %s: %s", addon, text)
    else
        state.hooks[#state.hooks + 1] = record
    end
end

---The hooks seen so far, named and grouped by add-on; later ones are written as they come.
---@return table<string, string[]> byAddon, string[] addons
function HookActions.Summarize()
    local state = ErrorCatcher.state
    for _, record in ipairs(state.hooks) do
        Resolve(record)
    end
    state.hooksSummarized = true
    return HookUtils.GroupByAddon(state.hooks)
end

---@return string[] installed Names of the hooks placed
function HookActions.Install()
    local installed = {}
    for _, kind in ipairs(HookUtils.KINDS) do
        local placed = GameUtils.SecureHook(_G, kind, kind, function(first, second)
            OnHook(kind, first, second)
        end)
        if placed then
            installed[#installed + 1] = kind
        end
    end
    return installed
end

ErrorCatcher.HookActions = HookActions
