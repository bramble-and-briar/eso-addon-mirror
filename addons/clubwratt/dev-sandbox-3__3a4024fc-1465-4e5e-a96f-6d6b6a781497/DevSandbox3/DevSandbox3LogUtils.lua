-- DevSandbox3LogUtils.lua: logging through LibConsoleLogger when present; a do-nothing shim otherwise
local LogUtils = {}

local function Noop() end
local logger = LibConsoleLogger and LibConsoleLogger.For and LibConsoleLogger:For("DevSandbox3") or { Log = Noop, Buffer = Noop }

function LogUtils.Log(fmt, ...)
    logger:Log(select("#", ...) > 0 and string.format(fmt, ...) or fmt)
end

---Verbose: written (chat and the library's buffer) only while the LOGGING setting is on. Off, the default, writes
---nothing: the library's buffer is shared by every addon, and the 5 s summary line alone filled a third of it.
function LogUtils.Debug(fmt, ...)
    local s = DevSandbox3.state
    if not (s and s.savedVars.settings.debug) then return end
    logger:Log(select("#", ...) > 0 and string.format(fmt, ...) or fmt)
end

---Survey lines: into the library's buffer only, never chat, each with the game clock in seconds. Written while the
---SURVEY LOG setting is on, and only by events at a survey site (found, a spawn, a reset, left).
function LogUtils.Survey(fmt, ...)
    local s = DevSandbox3.state
    if not (s and s.savedVars.settings.surveyLog) then return end
    logger:Buffer(string.format("survey t=%.1f " .. fmt, GetFrameTimeMilliseconds() / 1000, ...))
end

---Push everything buffered to the configured receiver (no-op without the library).
function LogUtils.Export()
    if not (LibConsoleLogger and LibConsoleLogger.Export) then d(string.format("[%s] LibConsoleLogger not loaded", DevSandbox3.displayName)); return end
    local ok, reason = LibConsoleLogger:Export()
    d(string.format("[%s] export %s%s", DevSandbox3.displayName, ok and "started" or "FAILED", reason and (": " .. reason) or ""))
end

DevSandbox3.LogUtils = LogUtils
