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
