-- LibConsoleLoggerActions.lua: public API + logging behavior

LibConsoleLogger = LibConsoleLogger or {}

local Utils = LibConsoleLogger.Utils
local State = LibConsoleLogger.State

local function RefreshLogDialogIfVisible()
    local dialog = LibConsoleLogger and LibConsoleLogger.LogDialog
    if dialog and dialog.RefreshIfVisible then
        dialog:RefreshIfVisible()
    end
end

---@param source string|nil
---@param line string
---@return string
local function PrefixSource(source, line)
    if source and source ~= "" then
        return string.format("[%s] %s", source, line)
    end
    return line
end

---@param source string|nil
---@param line any
local function BufferLine(source, line)
    local webExport = LibConsoleLogger and LibConsoleLogger.WebExport
    if webExport and webExport.BufferD then
        webExport.BufferD(PrefixSource(source, Utils.NormalizeLine(line)))
    end
end

---@return boolean
local function IsChatMirrorActive()
    if not State.runtimeEnabled then
        return false
    end
    return LibConsoleLogger.IsChatEnabled and LibConsoleLogger:IsChatEnabled()
end

---Write one line to the user's chat log (console text chat / system messages).
---@param source string|nil
---@param line any
local function ChatLine(source, line)
    local message = PrefixSource(source, Utils.NormalizeLine(line))

    local chatRouter = rawget(_G, "CHAT_ROUTER")
    if chatRouter and chatRouter.AddSystemMessage then
        pcall(function() chatRouter:AddSystemMessage(message) end)
        return
    end

    -- PC dev builds: d() routes to chat.
    local dFn = rawget(_G, "d")
    if dFn then
        pcall(dFn, message)
    end
end

---Log one or more values into the export buffer and (when the chat mirror is on)
---the user's chat log. Tables expand recursively.
---@param source string|nil
local function EmitLog(source, ...)
    local chatActive = IsChatMirrorActive()

    ---@param line any
    local function EmitOne(line)
        BufferLine(source, line)
        if chatActive then
            ChatLine(source, line)
        end
    end

    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "table" then
            if Utils and Utils.WalkTableWithSink then
                Utils.WalkTableWithSink(function(line)
                    EmitOne(line)
                    return true
                end, value)
            end
        else
            EmitOne(tostring(value))
        end
    end
    RefreshLogDialogIfVisible()
end

---Buffer one or more values for later export (no chat output). Tables expand recursively.
---Buffering never requires a configured URL; only Export/Debug do.
---@param source string|nil
---@return boolean ok
---@return string|nil reason
local function BufferDeferred(source, ...)
    if not State.runtimeEnabled then
        return false, "disabled"
    end

    local webExport = LibConsoleLogger and LibConsoleLogger.WebExport
    if not (webExport and webExport.BufferD) then
        return false, "unsupported"
    end

    ---@param rawLine any
    ---@return boolean buffered
    local function BufferOne(rawLine)
        webExport.BufferD(PrefixSource(source, Utils.NormalizeLine(rawLine)))
        return true
    end

    local bufferedAny = false
    local n = select("#", ...)
    if n == 0 then
        bufferedAny = BufferOne("") or bufferedAny
    else
        for i = 1, n do
            local value = select(i, ...)
            if type(value) == "table" then
                bufferedAny = Utils.WalkTableWithSink(BufferOne, value) or bufferedAny
            else
                bufferedAny = BufferOne(value) or bufferedAny
            end
        end
    end

    if not bufferedAny then
        return false, "empty"
    end
    RefreshLogDialogIfVisible()
    return true, nil
end

---Export one or more values immediately (no chat output). Tables expand recursively.
---The export header carries the source, so lines are not prefixed here.
---@param source string|nil
---@return boolean ok
---@return string|nil reason
local function ExportImmediate(source, ...)
    if not State.runtimeEnabled then
        return false, "disabled"
    end

    local webExport = LibConsoleLogger and LibConsoleLogger.WebExport
    if not (webExport and webExport.ExportRaw and webExport.GetUrl) then
        return false, "unsupported"
    end
    if not (Utils and Utils.HasConfiguredUrl and Utils.HasConfiguredUrl(webExport)) then
        return false, "no-url"
    end

    local headerSource = Utils.Trim(source)
    if headerSource == "" then
        headerSource = LibConsoleLogger.name or "LibConsoleLogger"
    end

    local exportLines = {}

    ---@param rawLine any
    ---@return boolean accepted
    local function AddOne(rawLine)
        exportLines[#exportLines + 1] = Utils.NormalizeLine(rawLine)
        return true
    end

    local acceptedAny = false
    local n = select("#", ...)
    if n == 0 then
        acceptedAny = AddOne("") or acceptedAny
    else
        for i = 1, n do
            local value = select(i, ...)
            if type(value) == "table" then
                acceptedAny = Utils.WalkTableWithSink(AddOne, value) or acceptedAny
            else
                acceptedAny = AddOne(value) or acceptedAny
            end
        end
    end

    if not acceptedAny or #exportLines == 0 then
        return false, "empty"
    end

    local payload = table.concat(exportLines, "\n")
    return webExport.ExportRaw("debug", headerSource, payload, nil, false)
end

function LibConsoleLogger:IsEnabled()
    return State.runtimeEnabled == true
end

---Whether Log lines are mirrored to the user's chat log (in addition to the buffer).
---@return boolean
function LibConsoleLogger:IsChatEnabled()
    if LibConsoleLogger:_EnsureSavedVars() and LibConsoleLogger.savedVars ~= nil then
        return LibConsoleLogger.savedVars.chatEnabled ~= false
    end
    if LibConsoleLogger._pendingChatEnabled ~= nil then
        return LibConsoleLogger._pendingChatEnabled == true
    end
    return true
end

---@param enabled boolean
function LibConsoleLogger:SetChatEnabled(enabled)
    local flag = enabled == true
    if LibConsoleLogger:_EnsureSavedVars() and LibConsoleLogger.savedVars ~= nil then
        LibConsoleLogger.savedVars.chatEnabled = flag
    else
        LibConsoleLogger._pendingChatEnabled = flag
    end
end

---How many lines the buffer keeps (oldest evicted first). Persisted; default 4000.
---@return number
function LibConsoleLogger:GetMaxLines()
    local webExport = LibConsoleLogger.WebExport
    if webExport and webExport.GetMaxLines then
        return webExport.GetMaxLines()
    end
    return 4000
end

---Set the buffer line cap (clamped to the library's limits). Lowering it trims the buffer immediately.
---@param n number
---@return number applied
function LibConsoleLogger:SetMaxLines(n)
    local webExport = LibConsoleLogger.WebExport
    if webExport and webExport.SetMaxLines then
        return webExport.SetMaxLines(n)
    end
    return 4000
end

---Log one or more values (strings, numbers, tables). Tables are expanded recursively.
function LibConsoleLogger:Log(...)
    EmitLog(nil, ...)
end

-- Alias
LibConsoleLogger.L = LibConsoleLogger.Log

---Buffer one or more values for later export (no chat output). Tables are expanded recursively.
---@return boolean ok
---@return string|nil reason
function LibConsoleLogger:DebugDeferred(...)
    return BufferDeferred(nil, ...)
end

-- Aliases (buffer-only, no chat output)
LibConsoleLogger.Buffer = LibConsoleLogger.DebugDeferred
LibConsoleLogger.DD = LibConsoleLogger.DebugDeferred

---Debug one or more values and export immediately (no chat output). Tables are expanded recursively.
---@return boolean ok
---@return string|nil reason
function LibConsoleLogger:Debug(...)
    return ExportImmediate(nil, ...)
end

-- Aliases (immediate export, no chat output)
LibConsoleLogger.ExportNow = LibConsoleLogger.Debug
LibConsoleLogger.D = LibConsoleLogger.Debug

---Export buffered logs (no chat output).
---@return boolean ok
---@return string|nil reason
function LibConsoleLogger:Export()
    local webExport = LibConsoleLogger and LibConsoleLogger.WebExport
    if not (webExport and webExport.SubmitBuffered) then
        return false, "unsupported"
    end
    return webExport.SubmitBuffered(nil)
end

---Clear buffered logs (no chat output).
---@return boolean ok
---@return number cleared
function LibConsoleLogger:Clear()
    local webExport = LibConsoleLogger and LibConsoleLogger.WebExport
    if not (webExport and webExport.BufferClear) then
        return false, 0
    end
    local count = (webExport.BufferCount and webExport.BufferCount()) or 0
    webExport.BufferClear()
    RefreshLogDialogIfVisible()
    return true, count
end

-- Aliases
LibConsoleLogger.E = LibConsoleLogger.Export
LibConsoleLogger.C = LibConsoleLogger.Clear

-- ============================================================================
-- Scoped loggers: CL:For("MyAddon") tags every line/export with the source
-- ============================================================================

---@class LibConsoleLoggerScoped
---@field source string
local ScopedLogger = {}
ScopedLogger.__index = ScopedLogger

---Log one or more values, prefixed with "[source]". Tables are expanded recursively.
function ScopedLogger:Log(...)
    EmitLog(self.source, ...)
end

ScopedLogger.L = ScopedLogger.Log

---Buffer one or more values for later export, prefixed with "[source]".
---@return boolean ok
---@return string|nil reason
function ScopedLogger:DebugDeferred(...)
    return BufferDeferred(self.source, ...)
end

ScopedLogger.Buffer = ScopedLogger.DebugDeferred
ScopedLogger.DD = ScopedLogger.DebugDeferred

---Export one or more values immediately; the export header carries the source.
---@return boolean ok
---@return string|nil reason
function ScopedLogger:Debug(...)
    return ExportImmediate(self.source, ...)
end

ScopedLogger.ExportNow = ScopedLogger.Debug
ScopedLogger.D = ScopedLogger.Debug

---@return boolean ok
---@return string|nil reason
function ScopedLogger:Export()
    return LibConsoleLogger:Export()
end

ScopedLogger.E = ScopedLogger.Export

---@return boolean ok
---@return number cleared
function ScopedLogger:Clear()
    return LibConsoleLogger:Clear()
end

ScopedLogger.C = ScopedLogger.Clear

---@return boolean
function ScopedLogger:IsEnabled()
    return LibConsoleLogger:IsEnabled()
end

---@type table<string, LibConsoleLoggerScoped>
local scopedLoggers = {}

---Get a logger scoped to a source (usually your addon name). Cached per source.
---@param source string
---@return LibConsoleLoggerScoped
function LibConsoleLogger:For(source)
    local key = Utils.Trim(source)
    if key == "" then
        key = LibConsoleLogger.name or "LibConsoleLogger"
    end

    local scoped = scopedLoggers[key]
    if not scoped then
        scoped = setmetatable({ source = key }, ScopedLogger)
        scopedLoggers[key] = scoped
    end
    return scoped
end

-- ============================================================================
-- Enable/disable
-- ============================================================================

---@param enabled boolean
local function SetEnabledInternal(enabled)
    local flag = enabled == true

    if LibConsoleLogger:_EnsureSavedVars() and LibConsoleLogger.savedVars ~= nil then
        LibConsoleLogger.savedVars.enabled = flag
    else
        LibConsoleLogger._pendingEnabled = flag
    end

    if flag then
        State.runtimeEnabled = true
        if LibConsoleLogger.Settings and LibConsoleLogger.Settings.Initialize then
            LibConsoleLogger.Settings.Initialize()
        end
        return
    end

    -- Disable: clear in-memory state (no buffers, no timers, no events).
    State.runtimeEnabled = false

    local webExport = LibConsoleLogger.WebExport
    if webExport and webExport.Reset then
        webExport.Reset()
    end
    RefreshLogDialogIfVisible()
end

---@param enabled boolean
function LibConsoleLogger:SetEnabled(enabled)
    SetEnabledInternal(enabled == true)
end

function LibConsoleLogger:Enable()
    self:SetEnabled(true)
end

function LibConsoleLogger:Disable()
    self:SetEnabled(false)
end
