-- FurnishingCatalog.lua: root namespace, state, logging and the pcall wrappers.
-- First Lua file in the manifest so every later file can use these.
FurnishingCatalog = {
    name = "FurnishingCatalog",
    displayName = "Furnishing Catalog",
    version = "1.8.0",
    savedVarsName = "FurnishingCatalogSavedVars",
    savedVarsVersion = 2,
    state = {
        savedVars = {
            -- Diagnostics to the LibConsoleLogger buffer (/furn export ships it); /furn debug
            -- switches them on.
            debug = false,
            -- With debug on, also echo every diagnostic line to chat (/furn chat).
            debugChat = false,
            -- How the item list is sectioned (FurnishingCatalog.BrowseUtils.GROUP_MODES).
            groupMode = "name",
            -- The tooltip beside the list shows the furnishing's plan where it has one (right
            -- stick click switches to the furnishing's own tooltip).
            showPlan = true,
            -- The catalog, kept across sessions (see FurnishingCatalogTypes.lua).
            ---@type FurnishingCatalogCache|nil
            catalog = nil,
            -- A full scan (/furn scan) that is not finished yet.
            ---@type FurnishingCatalogScanProgress|nil
            scanProgress = nil,
            -- Present only while a pass is being stepped (ScanActions): found at load, it means
            -- the UI was torn down mid-pass.
            scanMarker = nil,
            -- The shopping lists (ShoppingUtils); created with the default list on first use.
            ---@type FurnishingCatalogShoppingStore|nil
            shopping = nil,
        },
    },
    diagnostics = {
        initialized = false,
        initErrors = {},
        errors = {},
        counters = {},
    },
}

local FC = FurnishingCatalog

-- LibConsoleLogger is optional: without it (or with debug off) diagnostics are dropped.
local scopedLogger
local function GetLogger()
    if scopedLogger == nil then
        local lib = rawget(_G, "LibConsoleLogger")
        if lib and lib.For then
            scopedLogger = lib:For(FC.name)
        else
            scopedLogger = false
        end
    end
    return scopedLogger or nil
end

---string.format that never throws: falls back to joining the arguments with spaces.
---@param fmt string
---@return string
local function Fmt(fmt, ...)
    local n = select("#", ...)
    if n == 0 then
        return tostring(fmt)
    end
    local ok, s = pcall(string.format, fmt, ...)
    if ok then
        return s
    end
    local parts = { tostring(fmt) }
    for i = 1, n do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end
FC.Fmt = Fmt

---Call a global game function by name and return its first result as text ("n/a" where the
---client has no such function, "error" where it throws). For diagnostic lines only.
---@param name string
---@return string
function FC.CallText(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then
        return "n/a"
    end
    local ok, result = pcall(fn, ...)
    if not ok then
        return "error"
    end
    return tostring(result)
end

---The memory pool the console shares between all add-ons, in MB (nil where the client has none).
---@return number|nil used
---@return number|nil capacity
function FC.PoolMb()
    local getUsed = rawget(_G, "GetTotalUserAddOnMemoryPoolUsageMB")
    local getCapacity = rawget(_G, "GetTotalUserAddOnMemoryPoolCapacityMB")
    if type(getUsed) ~= "function" then
        return nil, nil
    end
    local okUsed, used = pcall(getUsed)
    local okCapacity, capacity = pcall(getCapacity or tostring)
    return okUsed and tonumber(used) or nil, okCapacity and tonumber(capacity) or nil
end

---Memory figures for a diagnostic line: the add-on pool (all add-ons together; the game warns
---at 70% of it) and the whole Lua heap (base UI included).
---@return string
function FC.MemText()
    local used, capacity = FC.PoolMb()
    local okLua, luaKb = pcall(collectgarbage, "count")
    return Fmt("add-on pool %s/%s MB, Lua heap %s MB", used and string.format("%.2f", used) or "?", capacity and tostring(capacity) or "?",
        okLua and string.format("%.1f", luaKb / 1024) or "?")
end

-- Pool use before any of this add-on's files has built anything (Main compares at the end of load).
FC.diagnostics.poolAtFileStart = FC.PoolMb()

---@return boolean
function FC.IsDebug()
    return FC.state.savedVars.debug == true
end

---User-facing chat line (command replies). Always shown.
---@param line string
function FC.Chat(line)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(Fmt("[%s] %s", FC.displayName, line))
    end
end

---Diagnostic line. Debug mode only: buffered for /furn export, echoed to chat with debugChat.
function FC.Log(fmt, ...)
    if not FC.IsDebug() then
        return
    end
    local line = Fmt(fmt, ...)
    if FC.state.savedVars.debugChat then
        FC.Chat(line)
    end
    local logger = GetLogger()
    if logger then
        logger:Buffer(line)
    end
end

---Bump a named counter (dumped by /furn status).
---@param key string
---@param by integer|nil
function FC.Count(key, by)
    local counters = FC.diagnostics.counters
    counters[key] = (counters[key] or 0) + (by or 1)
end

local function RecordError(label, err)
    local msg = Fmt("%s: %s", label, tostring(err))
    local errors = FC.diagnostics.errors
    if #errors < 30 then
        errors[#errors + 1] = msg
    end
    FC.Log("ERROR %s", msg)
end

---Run fn under pcall; log and remember any error. Returns ok plus fn's results.
---@param label string
---@param fn function
function FC.SafeCall(label, fn, ...)
    local results = { pcall(fn, ...) }
    if not results[1] then
        RecordError(label, results[2])
    end
    return unpack(results)
end

---Wrap a callback so an error in our code can never abort the game's own call chain
---(a throw inside a scene or list callback leaves the scene stuck and the keybinds dead).
---@param label string
---@param fn function
---@return function
function FC.Guard(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            RecordError(label, err)
        end
    end
end

---Library state for /furn status.
---@return string
function FC.LoggerStateLine()
    local lib = rawget(_G, "LibConsoleLogger")
    if not lib then
        return "LibConsoleLogger: not loaded"
    end
    local okE, enabled = pcall(function() return lib:IsEnabled() end)
    local okU, url = pcall(function() return lib.WebExport and lib.WebExport.GetUrl and lib.WebExport.GetUrl() end)
    return Fmt("LibConsoleLogger: enabled=%s exportUrl=%s", okE and tostring(enabled) or "?", okU and tostring(url) or "?")
end

---Ship the buffered log to the configured receiver.
function FC.Export()
    local lib = rawget(_G, "LibConsoleLogger")
    if not (lib and lib.Export) then
        FC.Chat("LibConsoleLogger not installed; nothing to export")
        return
    end
    local ok, reason = lib:Export()
    FC.Chat(Fmt("export %s%s", ok and "started" or "FAILED", reason and (": " .. tostring(reason)) or ""))
end
