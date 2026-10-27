-- PreviewAnywhere.lua: root namespace, logging, and the SafeCall wrapper.
-- First file in the manifest so every later file can use these.
PreviewAnywhere = {
    name = "PreviewAnywhere",
    displayName = "Preview Anywhere",
    version = "1.3.0",
    savedVarsName = "PreviewAnywhereSavedVars",
    savedVarsVersion = 3,
    state = {
        savedVars = {
            enabled = true,
            -- Give the inventory (and Better Character Overview's page in it) the vendor Buy tab's
            -- preview layout: piece right of the item tooltip, not behind it. /pva invframe toggles.
            inventoryFraming = true,
            -- Furnishing Vault lists grouped by furniture category (/pva vault on|off), with
            -- "Category - Subcategory" headers (/pva vault sub), optionally also in the regular bank
            -- and house banks (/pva vault everywhere).
            vaultCategories = true,
            vaultSubcategories = true,
            vaultEverywhere = false,
            -- Debug mode (/pva debug): diagnostic lines go to the LibConsoleLogger buffer (when the
            -- optional library is installed) and Lua errors are echoed to chat. Off by default:
            -- release builds stay silent apart from direct command replies.
            debug = false,
            -- With debug on, also echo every diagnostic line to chat.
            debugChat = false,
        },
    },
    diagnostics = {
        initialized = false,
        addonNames = {},
        initErrors = {},
        errors = {},
        counters = {},
    },
}

local PA = PreviewAnywhere

-- LibConsoleLogger is optional: without it (or with debug off) diagnostics are dropped.
local scopedLogger
local function GetLogger()
    if scopedLogger == nil then
        local lib = rawget(_G, "LibConsoleLogger")
        if lib and lib.For then
            scopedLogger = lib:For(PA.name)
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
PA.Fmt = Fmt

---@return boolean
function PA.IsDebug()
    return PA.state.savedVars.debug == true
end

---User-facing chat line (command replies). Always shown.
function PA.Chat(line)
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(Fmt("[%s] %s", PA.displayName, line))
    end
end

local function Buffer(line)
    local logger = GetLogger()
    if logger then
        logger:Buffer(line)
    end
end

---Diagnostic line. Debug mode only: buffered for /pva export, echoed to chat with debugChat.
function PA.Log(fmt, ...)
    if not PA.IsDebug() then
        return
    end
    local line = Fmt(fmt, ...)
    if PA.state.savedVars.debugChat then
        PA.Chat(line)
    end
    Buffer(line)
end

---Verbose diagnostic line; same gating as Log (kept separate so call sites document intent).
PA.Debug = PA.Log

---Delayed engine-state snapshot (debug only; the timer is not even scheduled otherwise).
---@param delayMs integer
---@param fmt string takes one %s: the preview state line
function PA.DebugLater(delayMs, fmt)
    if not PA.IsDebug() then
        return
    end
    zo_callLater(function() PA.Debug(fmt, PA.ProbeUtils.PreviewStateLine()) end, delayMs)
end

---Library state for /pva status.
---@return string
function PA.LoggerStateLine()
    local lib = rawget(_G, "LibConsoleLogger")
    if not lib then
        return "LibConsoleLogger: not loaded"
    end
    local okE, enabled = pcall(function() return lib:IsEnabled() end)
    local okU, url = pcall(function() return lib.WebExport and lib.WebExport.GetUrl and lib.WebExport.GetUrl() end)
    return Fmt("LibConsoleLogger: enabled=%s exportUrl=%s", okE and tostring(enabled) or "?", okU and tostring(url) or "?")
end

---Bump a named counter (dumped by /pva status).
---@param key string
function PA.Count(key)
    local counters = PA.diagnostics.counters
    counters[key] = (counters[key] or 0) + 1
end

---Run fn under pcall; log and remember any error. Returns ok plus fn's results.
---@param label string
---@param fn function
function PA.SafeCall(label, fn, ...)
    local results = { pcall(fn, ...) }
    if not results[1] then
        local err = Fmt("%s: %s", label, tostring(results[2]))
        table.insert(PA.diagnostics.errors, err)
        PA.Log("ERROR %s", err)
        if PA.IsDebug() then
            PA.Chat("ERROR " .. err)
        end
    end
    return unpack(results)
end

---Wrap a hook body so an error in our code can never abort the game's own call chain
---(0.2.2/0.2.3: a nil-index inside a post-hook on OnTargetChanged aborted the bank scene's
---hide sequence and left the vault UI stuck).
---@param label string
---@param fn function
---@return function
function PA.Guard(label, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            local msg = Fmt("%s: %s", label, tostring(err))
            table.insert(PA.diagnostics.errors, msg)
            PA.Log("ERROR %s", msg)
            if PA.IsDebug() then
                PA.Chat("ERROR " .. msg)
            end
        end
    end
end

---Post-hook that keeps the game's call secure. ZO_PostHook wraps the original in an addon
---closure, so every closure the original creates while running (e.g. the bank's slot-action
---callbacks) is born on an untrusted stack and later fails on protected calls such as
---PickupInventoryItem ("X does nothing in the bank", 0.2.4 log). SecurePostHook runs the
---original untouched and calls us afterwards.
---@param targetTable table
---@param functionName string
---@param hookFunction function
function PA.SecureHook(targetTable, functionName, hookFunction)
    if type(targetTable[functionName]) ~= "function" then
        table.insert(PA.diagnostics.initErrors, "hook target missing: " .. tostring(functionName))
        return false
    end
    if SecurePostHook then
        SecurePostHook(targetTable, functionName, hookFunction)
    else
        ZO_PostHook(targetTable, functionName, hookFunction)
    end
    return true
end

---Ship the buffered log to the configured receiver.
function PA.Export()
    local lib = rawget(_G, "LibConsoleLogger")
    if not (lib and lib.Export) then
        PA.Chat("LibConsoleLogger not installed; nothing to export")
        return
    end
    local ok, reason = lib:Export()
    PA.Chat(Fmt("export %s%s", ok and "started" or "FAILED", reason and (": " .. tostring(reason)) or ""))
end
