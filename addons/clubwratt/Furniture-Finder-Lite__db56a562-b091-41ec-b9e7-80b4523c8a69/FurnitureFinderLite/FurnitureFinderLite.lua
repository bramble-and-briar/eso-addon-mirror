-- FurnitureFinderLite.lua: root namespace, state, logging and the pcall wrappers.
-- First Lua file in the manifest so every later file can use these.
FurnitureFinderLite = {
    name = "FurnitureFinderLite",
    displayName = "Furniture Finder Lite",
    version = "1.0.1",
    savedVarsName = "FurnitureFinderLiteSavedVars",
    savedVarsVersion = 1,
    state = {
        savedVars = {
            -- Source lines in furnishing tooltips.
            enabled = true,
            -- Diagnostics to the LibConsoleLogger buffer (/ffl export ships it); /ffl debug
            -- switches them on.
            debug = false,
        },
    },
    diagnostics = {
        initialized = false,
        initErrors = {},
        errors = {},
        counters = {},
    },
}
local FFL = FurnitureFinderLite

local logger = nil

-- LibConsoleLogger is optional: without it (or with debug off) diagnostics are dropped.
local function GetLogger()
    if logger == nil then
        local lib = rawget(_G, "LibConsoleLogger")
        logger = lib and lib.For and lib:For(FFL.name) or false
    end
    return logger or nil
end

---@param fmt string
---@return string
local function Fmt(fmt, ...)
    if select("#", ...) == 0 then
        return tostring(fmt)
    end
    local ok, text = pcall(string.format, fmt, ...)
    return ok and text or tostring(fmt)
end
FFL.Fmt = Fmt

---The memory pool the console shares between all add-ons, as text for a diagnostic line.
---@return string
function FFL.MemText()
    local getUsed = rawget(_G, "GetTotalUserAddOnMemoryPoolUsageMB")
    local getCapacity = rawget(_G, "GetTotalUserAddOnMemoryPoolCapacityMB")
    local okUsed, used = pcall(getUsed or error)
    local okCapacity, capacity = pcall(getCapacity or error)
    return Fmt("add-on pool %s/%s MB", okUsed and tonumber(used) and string.format("%.2f", used) or "?", okCapacity and tostring(capacity) or "?")
end

-- Pool use before this add-on's data file has loaded (Main compares at the end of load).
FFL.diagnostics.memAtFileStart = FFL.MemText()

---User-facing chat line (command replies). Always shown.
---@param line string
function FFL.Chat(line)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(Fmt("[%s] %s", FFL.displayName, line))
    end
end

---Diagnostic line. Debug mode only: buffered for /ffl export.
function FFL.Log(fmt, ...)
    if FFL.state.savedVars.debug ~= true then
        return
    end
    local log = GetLogger()
    if log then
        log:Buffer(Fmt(fmt, ...))
    end
end

---Bump a named counter (dumped by /ffl status).
---@param key string
function FFL.Count(key)
    local counters = FFL.diagnostics.counters
    counters[key] = (counters[key] or 0) + 1
end

local function RecordError(label, err)
    local message = Fmt("%s: %s", label, tostring(err))
    local errors = FFL.diagnostics.errors
    if #errors < 30 then
        errors[#errors + 1] = message
    end
    FFL.Log("ERROR %s", message)
end

---Run fn under pcall; log and remember any error. Returns ok plus fn's results.
---@param label string
---@param fn function
function FFL.SafeCall(label, fn, ...)
    local results = { pcall(fn, ...) }
    if not results[1] then
        RecordError(label, results[2])
    end
    return unpack(results)
end

---Wrap a callback so an error in our code can never abort the game's own call chain (a throw
---inside a tooltip layout leaves the tooltip half built).
---@param label string
---@param fn function
---@return function
function FFL.Guard(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            RecordError(label, err)
        end
    end
end

---Ship the buffered log to the configured receiver.
function FFL.Export()
    local lib = rawget(_G, "LibConsoleLogger")
    if not (lib and lib.Export) then
        FFL.Chat("LibConsoleLogger not installed; nothing to export")
        return
    end
    local ok, reason = lib:Export()
    FFL.Chat(Fmt("export %s%s", ok and "started" or "FAILED", reason and (": " .. tostring(reason)) or ""))
end
