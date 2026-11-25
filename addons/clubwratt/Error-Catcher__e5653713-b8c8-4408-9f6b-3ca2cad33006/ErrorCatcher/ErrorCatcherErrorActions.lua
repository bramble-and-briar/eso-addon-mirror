-- ErrorCatcherErrorActions.lua: each distinct Lua error as one line naming the frames
--
-- LibConsoleLogger records the error text itself, cut at 1000 characters, which the locals of the first
-- frames use up. This adds the whole depth of the trace on one line and, for a refused private call, the
-- frame the game's count lands on.
local ErrorActions = {}

local Log = ErrorCatcher.LogUtils
local ErrorUtils = ErrorCatcher.ErrorUtils

local EVENT_NAMESPACE = ErrorCatcher.name .. "_Errors"

local handling = false

---@param fn string A function's name as a trace prints it
---@return string[]|nil addons Those seen hooking it
local function HookersOf(fn)
    return ErrorCatcher.state.hookersByFn[ErrorCatcher.HookUtils.BareName(fn)]
end

---@param errorText any
local function Handle(errorText)
    local line = ErrorUtils.Describe(errorText, HookersOf)
    if not line then
        -- Text without a trace is a notice; the low memory warning is worth a memory reading.
        ErrorCatcher.MemoryActions.OnNotice(errorText)
        return
    end
    ErrorCatcher.state.counters.errors = ErrorCatcher.state.counters.errors + 1
    Log.Once(line, "%s", line)
end

---The handler of EVENT_LUA_ERROR. It never raises: an error in it would come straight back as an event.
---@param errorText any
function ErrorActions.OnLuaError(errorText)
    if handling then
        return
    end
    handling = true
    pcall(Handle, errorText)
    handling = false
end

function ErrorActions.Register()
    if EVENT_MANAGER and EVENT_LUA_ERROR then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_LUA_ERROR, function(_eventId, errorText)
            ErrorActions.OnLuaError(errorText)
        end)
    end
end

ErrorCatcher.ErrorActions = ErrorActions
