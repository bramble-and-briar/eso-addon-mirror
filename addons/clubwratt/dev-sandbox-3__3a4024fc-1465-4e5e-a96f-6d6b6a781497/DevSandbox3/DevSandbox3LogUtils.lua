-- DevSandbox3LogUtils.lua: Logging helper (LibConsoleLogger when present, chat otherwise)

local LogUtils = {}

---@param fmt string
---@param ... any
function LogUtils.Log(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    local line = string.format("[%s] %s", DevSandbox3.displayName, msg)
    if LibConsoleLogger and LibConsoleLogger.Log then
        LibConsoleLogger:Log(line)
    else
        d(line)
    end
end

---@param fmt string
---@param ... any
function LogUtils.Debug(fmt, ...)
    local state = DevSandbox3.state
    if state and state.savedVars and state.savedVars.debug then
        LogUtils.Log(fmt, ...)
    end
end

DevSandbox3.LogUtils = LogUtils
