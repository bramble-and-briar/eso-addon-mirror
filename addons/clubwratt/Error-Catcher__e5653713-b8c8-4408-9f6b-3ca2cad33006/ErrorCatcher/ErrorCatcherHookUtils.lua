-- ErrorCatcherHookUtils.lua: wording one hook call (pure)
local HookUtils = {}

-- The game's own hook installers. Each builds a wrapper that runs the original inside it, so what the
-- original creates while wrapped is born on the wrapper's stack.
HookUtils.KINDS = { "ZO_PreHook", "ZO_PostHook", "ZO_PreHookHandler", "ZO_PostHookHandler" }

---@param kind string
---@return boolean
function HookUtils.IsHandlerKind(kind)
    return kind == "ZO_PreHookHandler" or kind == "ZO_PostHookHandler"
end

---The table and function a ZO_PreHook / ZO_PostHook call names: the table may be left out for a global.
---@param first any
---@param second any
---@param globals table
---@return table|nil target, string fnName
function HookUtils.Target(first, second, globals)
    if type(first) == "string" then
        return globals, first
    end
    return type(first) == "table" and first or nil, tostring(second)
end

---@param record ErrorCatcherHookRecord
---@return string
function HookUtils.Describe(record)
    if HookUtils.IsHandlerKind(record.kind) then
        return string.format("%s %s:%s", record.kind, record.targetName or "?", record.fnName)
    end
    if record.targetName == "_G" then
        return string.format("%s %s", record.kind, record.fnName)
    end
    return string.format("%s %s.%s", record.kind, record.targetName or "?", record.fnName)
end

---A function's name without its table: "ZO_Reticle:OnUpdate" and "RETICLE.OnUpdate" are both "OnUpdate".
---@param name string
---@return string
function HookUtils.BareName(name)
    return string.match(name, "([^:.]+)$") or name
end

---Wrapped functions with the add-ons seen hooking them: "ZO_Dialogs_ShowDialog (hook by LazyConfirm)".
---A function wrapped by an add-on that loaded before this one has no name to give.
---@param wrapped string[] Function names as a trace prints them
---@param hookersByFn table<string, string[]>
---@return string[]
function HookUtils.NameHookers(wrapped, hookersByFn)
    local named = {}
    for index, fn in ipairs(wrapped) do
        local hookers = hookersByFn[HookUtils.BareName(fn)]
        if hookers and #hookers > 0 then
            named[index] = string.format("%s (hook by %s)", fn, table.concat(hookers, ", "))
        else
            named[index] = fn
        end
    end
    return named
end

---@param records ErrorCatcherHookRecord[]
---@return table<string, string[]> byAddon, string[] addons Sorted add-on names
function HookUtils.GroupByAddon(records)
    local byAddon, addons = {}, {}
    for _, record in ipairs(records) do
        if not byAddon[record.addon] then
            byAddon[record.addon] = {}
            addons[#addons + 1] = record.addon
        end
        local hooks = byAddon[record.addon]
        hooks[#hooks + 1] = HookUtils.Describe(record)
    end
    table.sort(addons)
    return byAddon, addons
end

ErrorCatcher.HookUtils = HookUtils
