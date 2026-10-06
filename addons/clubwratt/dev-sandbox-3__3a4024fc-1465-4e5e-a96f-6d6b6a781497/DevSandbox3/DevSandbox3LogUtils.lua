-- DevSandbox3LogUtils.lua: logging through LibConsoleLogger when present; a do-nothing shim otherwise
local LogUtils = {}

local function Noop() end
local logger = LibConsoleLogger and LibConsoleLogger.For and LibConsoleLogger:For("DevSandbox3") or { Log = Noop, Buffer = Noop }

function LogUtils.Log(fmt, ...)
    logger:Log(select("#", ...) > 0 and string.format(fmt, ...) or fmt)
end

---Verbose: chat when debug is on, buffer-only (for export) otherwise.
function LogUtils.Debug(fmt, ...)
    local s = DevSandbox3.state
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    if s and s.savedVars.settings.debug then logger:Log(msg) else logger:Buffer(msg) end
end

---Push everything buffered to the configured receiver (no-op without the library).
function LogUtils.Export()
    if not (LibConsoleLogger and LibConsoleLogger.Export) then d(string.format("[%s] LibConsoleLogger not loaded", DevSandbox3.displayName)); return end
    local ok, reason = LibConsoleLogger:Export()
    d(string.format("[%s] export %s%s", DevSandbox3.displayName, ok and "started" or "FAILED", reason and (": " .. reason) or ""))
end

DevSandbox3.LogUtils = LogUtils
