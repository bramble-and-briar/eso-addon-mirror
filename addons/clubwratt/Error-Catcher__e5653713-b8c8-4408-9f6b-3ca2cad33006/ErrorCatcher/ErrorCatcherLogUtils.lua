-- ErrorCatcherLogUtils.lua: every line goes to LibConsoleLogger's buffer under the "ErrorCatcher" scope
--
-- Lines are buffered only, never mirrored to chat: this add-on writes while the player is in a menu.
local LogUtils = {}

-- Distinct once-lines kept per UI load; past it one notice is written and the rest are dropped.
local MAX_ONCE_LINES = 300
-- Lines held back until the library has loaded. This add-on loads ahead of it (the library names it as an
-- optional dependency, so that it sees as much of the load as it can), and the library drops what it is
-- handed before its own load event, when it reads its saved "enabled" switch.
local MAX_HELD_LINES = 400

---@type string[]|nil nil once flushed
local held = {}

local scopedLogger = nil

local function GetLogger()
    if scopedLogger == nil and LibConsoleLogger and LibConsoleLogger.For then
        scopedLogger = LibConsoleLogger:For(ErrorCatcher.name)
    end
    return scopedLogger
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

---Buffer one line.
---@param fmt string
---@param ... any
function LogUtils.Line(fmt, ...)
    if held then
        if #held < MAX_HELD_LINES then
            held[#held + 1] = Format(fmt, ...)
        end
        return
    end
    local logger = GetLogger()
    if logger then
        logger:Buffer(Format(fmt, ...))
    end
end

---Write the lines held back since file scope; from here on a line is buffered as it comes. Without the
---library they are dropped.
function LogUtils.Flush()
    local lines = held
    held = nil
    for _, line in ipairs(lines or {}) do
        LogUtils.Line("%s", line)
    end
end

---Whether the library's own load event has run (it says so from 0.7.1).
---@return boolean
function LogUtils.LibraryLoaded()
    return type(LibConsoleLogger) == "table" and LibConsoleLogger.loaded == true
end

---Write the held lines once the library has loaded. Asked at every load event, since this add-on's handler
---of the library's own load event runs ahead of the library's.
function LogUtils.TryFlush()
    if held and LogUtils.LibraryLoaded() then
        LogUtils.Flush()
    end
end

---A line the player asked for (a slash command): chat and buffer.
---@param fmt string
---@param ... any
function LogUtils.Chat(fmt, ...)
    local logger = GetLogger()
    if logger then
        logger:Log(Format(fmt, ...))
    end
end

---@param key string
---@return boolean seen The key was already written this UI load
function LogUtils.Seen(key)
    return ErrorCatcher.state.loggedKeys[key] == true
end

---Buffer a line the first time its key comes up in a UI load.
---@param key string
---@param fmt string
---@param ... any
---@return boolean written
function LogUtils.Once(key, fmt, ...)
    local state = ErrorCatcher.state
    if state.loggedKeys[key] then
        return false
    end
    if state.loggedCount >= MAX_ONCE_LINES then
        -- Past the cap no key is kept either, so the set stays bounded.
        if state.loggedCount == MAX_ONCE_LINES then
            state.loggedCount = state.loggedCount + 1
            LogUtils.Line("%d distinct lines written this UI load; further ones are dropped", MAX_ONCE_LINES)
        end
        return false
    end
    state.loggedKeys[key] = true
    state.loggedCount = state.loggedCount + 1
    LogUtils.Line(fmt, ...)
    return true
end

---Push the buffered log to the LibConsoleLogger receiver.
function LogUtils.Export()
    if not (LibConsoleLogger and LibConsoleLogger.Export) then
        return
    end
    local ok, reason = LibConsoleLogger:Export()
    LogUtils.Chat("export %s%s", ok and "started" or "FAILED", reason and (": " .. tostring(reason)) or "")
end

ErrorCatcher.LogUtils = LogUtils
