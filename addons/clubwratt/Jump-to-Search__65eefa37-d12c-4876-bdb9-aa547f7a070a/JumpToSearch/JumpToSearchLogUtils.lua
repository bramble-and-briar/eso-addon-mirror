-- JumpToSearchLogUtils.lua: logging through LibConsoleLogger when present; chat router otherwise
local LogUtils = {}

local scopedLogger = nil

local function GetLogger()
    if scopedLogger == nil then
        if LibConsoleLogger and LibConsoleLogger.For then
            scopedLogger = LibConsoleLogger:For(JumpToSearch.name)
        else
            scopedLogger = false
        end
    end
    return scopedLogger or nil
end

---@param fmt string
---@param ... any
---@return string
local function Format(fmt, ...)
    if select("#", ...) > 0 then
        return string.format(fmt, ...)
    end
    return fmt
end

---Always-visible line (chat + export buffer).
---@param fmt string
---@param ... any
function LogUtils.Log(fmt, ...)
    local msg = Format(fmt, ...)
    local logger = GetLogger()
    if logger then
        logger:Log(msg)
    elseif CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", JumpToSearch.name, msg))
    end
end

---Verbose line: chat when debug is on, export buffer only otherwise.
---@param fmt string
---@param ... any
function LogUtils.Debug(fmt, ...)
    local state = JumpToSearch.state
    local debugOn = state and state.savedVars.debug
    local logger = GetLogger()
    if logger then
        if debugOn then
            logger:Log(Format(fmt, ...))
        else
            logger:Buffer(Format(fmt, ...))
        end
    elseif debugOn then
        LogUtils.Log(fmt, ...)
    end
end

---Push everything buffered to the configured LibConsoleLogger receiver.
function LogUtils.Export()
    if not (LibConsoleLogger and LibConsoleLogger.Export) then
        LogUtils.Log("LibConsoleLogger not loaded; nothing to export")
        return
    end
    local ok, reason = LibConsoleLogger:Export()
    LogUtils.Log("export %s%s", ok and "started" or "FAILED", reason and (": " .. tostring(reason)) or "")
end

JumpToSearch.LogUtils = LogUtils
