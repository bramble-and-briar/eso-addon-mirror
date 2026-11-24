-- LibConsoleLoggerWebExport.lua: webview export (network transport) for LibConsoleLogger

LibConsoleLogger = LibConsoleLogger or {}

LibConsoleLogger.WebExport = LibConsoleLogger.WebExport or {}
local WebExport = LibConsoleLogger.WebExport

local Utils = LibConsoleLogger.Utils

local MAX_URL_LEN = 8191
local MAX_CAPTURE_BYTES = 1024 * 1024
-- Hard ceiling on buffered lines. The effective cap is the user's "Buffer size" setting
-- (LibConsoleLogger:GetMaxLines), clamped to [MIN_CAPTURE_LINES, MAX_CAPTURE_LINES]; a smaller cap keeps
-- a busy addon's export down to a few browser round trips (one chunk is ~6 KB / ~80 short lines).
local MAX_CAPTURE_LINES = 4000
local MIN_CAPTURE_LINES = 50
-- URL-safe base64 alphabet: '+' and '/' would be mangled by standard
-- query-string parsers ('+' decodes to a space), so use '-' and '_' instead.
local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local EMPTY_STRING_ARRAY = {}

-- Transport status is kept out of the export buffer so it never pollutes the
-- next export. The log dialog shows it as a separate footer line instead.
---@type string|nil
local lastStatus = nil

---@param message any
local function ReportStatus(message)
    lastStatus = tostring(message or "")

    -- On PC dev builds d() prints to chat; console surfaces the status via the log dialog.
    local dFn = rawget(_G, "d")
    if dFn then
        pcall(dFn, lastStatus)
    end

    local dialog = LibConsoleLogger.LogDialog
    if dialog and dialog.RefreshIfVisible then
        dialog:RefreshIfVisible()
    end
end

---@param formatString any
local function ReportStatusf(formatString, ...)
    if formatString == nil then
        ReportStatus("")
        return
    end

    local ok, formatted = pcall(string.format, tostring(formatString), ...)
    if ok then
        ReportStatus(formatted)
    else
        ReportStatus(tostring(formatString))
    end
end

---@return string|nil
function WebExport.GetLastStatus()
    return lastStatus
end

---@param s string
---@return string
local function EnsureTrailingNewline(s)
    s = tostring(s or "")
    if s == "" then
        return s
    end
    if string.sub(s, -1) ~= "\n" then
        return s .. "\n"
    end
    return s
end

---@return boolean
local function EnsureSavedVars()
    if LibConsoleLogger._EnsureSavedVars then
        return LibConsoleLogger:_EnsureSavedVars()
    end
    return false
end

-- NormalizeUrl (rather than Trim) is applied on read as well as on write, so
-- scheme-less values saved by older versions still export correctly.
---@param cfg table|nil
---@return string
local function GetBaseUrl(cfg)
    local url = cfg and cfg.url or nil
    if url ~= nil then
        url = Utils.NormalizeUrl(url)
        if url ~= "" then
            return url
        end
    end

    EnsureSavedVars()
    local sv = LibConsoleLogger.savedVars
    local saved = Utils.NormalizeUrl(sv and sv.url or nil)
    if saved ~= "" then
        return saved
    end

    return Utils.NormalizeUrl(LibConsoleLogger._pendingUrl)
end

---@return number
function WebExport.GetMaxUrlLength()
    return MAX_URL_LEN
end

---@param cfg table|nil
---@return string
function WebExport.GetUrl(cfg)
    return GetBaseUrl(cfg)
end

---@param url any
---@param cfg table|nil
---@return boolean ok
---@return string|nil reason
function WebExport.SetUrl(url, cfg)
    local normalized = Utils.NormalizeUrl(url)

    if cfg ~= nil then
        cfg.url = normalized
        return true, nil
    end

    if EnsureSavedVars() and LibConsoleLogger.savedVars ~= nil then
        LibConsoleLogger.savedVars.url = normalized
        return true, nil
    end

    LibConsoleLogger._pendingUrl = normalized
    return true, nil
end

-- ============================================================================
-- Shared buffer (compat with SmartTrader's LogExport module)
-- ============================================================================

-- Ring buffer: lines live at indices head..tail (monotonically increasing); eviction is O(1) - no table.remove(1).
-- Bounded by bytes (MAX_CAPTURE_BYTES) AND lines (MAX_CAPTURE_LINES): short lines would otherwise reach thousands of
-- entries before the byte cap, and every eviction used to shift the whole array.
-- The ring is a plain in-memory table until the saved variables load; WebExport.AdoptSavedBuffer then makes it
-- the saved table itself, so the game writes the log out with the settings (every loading screen, /reloadui,
-- logout) and the next UI load reads it back. Every change below is made in place for that reason.
---@type { lines: string[]|nil, head: number, tail: number, bytes: number }
local ring = { lines = nil, head = 1, tail = 0, bytes = 0 }

local function ClearExportBuffer()
    ring.lines = nil
    ring.bytes = 0
    ring.head, ring.tail = 1, 0
end

---@return number
function WebExport.GetMaxLinesCeiling()
    return MAX_CAPTURE_LINES
end

---@return number
function WebExport.GetMinLines()
    return MIN_CAPTURE_LINES
end

---Effective line cap: the persisted setting (or the pending value before SavedVars load), clamped.
---@return number
function WebExport.GetMaxLines()
    local n
    if EnsureSavedVars() and LibConsoleLogger.savedVars ~= nil then
        n = LibConsoleLogger.savedVars.maxLines
    end
    if n == nil then
        n = LibConsoleLogger._pendingMaxLines
    end
    n = tonumber(n) or MAX_CAPTURE_LINES
    n = math.floor(n)
    if n < MIN_CAPTURE_LINES then n = MIN_CAPTURE_LINES end
    if n > MAX_CAPTURE_LINES then n = MAX_CAPTURE_LINES end
    return n
end

-- Drop oldest lines until within both caps (O(1) each).
---@param maxLines number
local function TrimExportBuffer(maxLines)
    while ring.head <= ring.tail and (ring.bytes > MAX_CAPTURE_BYTES or (ring.tail - ring.head + 1) > maxLines) do
        local removed = ring.lines[ring.head]
        ring.lines[ring.head] = nil
        ring.head = ring.head + 1
        ring.bytes = ring.bytes - (#removed + 1)
    end
    if ring.head > ring.tail then
        ClearExportBuffer()
    end
end

---Set the line cap (persisted). Lowering it trims the buffer right away.
---@param n number
---@return number applied
function WebExport.SetMaxLines(n)
    n = math.floor(tonumber(n) or MAX_CAPTURE_LINES)
    if n < MIN_CAPTURE_LINES then n = MIN_CAPTURE_LINES end
    if n > MAX_CAPTURE_LINES then n = MAX_CAPTURE_LINES end
    if EnsureSavedVars() and LibConsoleLogger.savedVars ~= nil then
        LibConsoleLogger.savedVars.maxLines = n
    else
        LibConsoleLogger._pendingMaxLines = n
    end
    if ring.lines ~= nil then
        TrimExportBuffer(n)
    end
    return n
end

---@return boolean
local function IsRuntimeEnabled()
    return LibConsoleLogger.IsEnabled and LibConsoleLogger:IsEnabled()
end

---The strings a saved ring holds, oldest first; an unreadable one (older format, hand-edited) reads as empty.
---@param saved any
---@return string[]
local function SavedLines(saved)
    local out = {}
    if type(saved) ~= "table" or type(saved.lines) ~= "table" then return out end
    local head, tail = tonumber(saved.head), tonumber(saved.tail)
    if head == nil or tail == nil or tail - head >= MAX_CAPTURE_LINES * 5 then return out end
    for i = head, tail do
        local line = saved.lines[i]
        if type(line) == "string" then out[#out + 1] = line end
    end
    return out
end

---Make the saved variables hold the ring: the lines saved by the previous UI load come first, then any
---buffered in memory since this one started. Called once the saved variables are loaded (Main.lua).
---With keep == false (logging disabled) the saved lines are dropped instead.
---@param keep boolean
---@return number kept lines carried over from before this UI load
function WebExport.AdoptSavedBuffer(keep)
    if not (EnsureSavedVars() and LibConsoleLogger.savedVars ~= nil) then
        return 0
    end
    local sv = LibConsoleLogger.savedVars
    local lines = keep and SavedLines(sv.log) or {}
    local kept = #lines
    for i = ring.head, ring.tail do
        lines[#lines + 1] = ring.lines[i]
    end
    local bytes = 0
    for i = 1, #lines do
        bytes = bytes + #lines[i] + 1
    end

    local adopted = { lines = (#lines > 0) and lines or nil, head = 1, tail = #lines, bytes = bytes }
    sv.log = adopted
    ring = adopted
    if ring.lines ~= nil then
        local before = ring.tail - ring.head + 1
        TrimExportBuffer(WebExport.GetMaxLines())
        local trimmed = before - WebExport.BufferCount()
        kept = (trimmed < kept) and (kept - trimmed) or 0
    end
    return kept
end

-- Buffer functions
function WebExport.BufferClear()
    ClearExportBuffer()
end

---@param line string
function WebExport.BufferD(line)
    if not IsRuntimeEnabled() then
        return
    end

    local s = tostring(line or "")
    if s == "" then
        s = "[Empty String]"
    end

    -- Keep the buffer bounded (approx by UTF-8 byte length).
    -- We count 1 extra byte per line to approximate the newline used during concatenation.
    local maxBytes = MAX_CAPTURE_BYTES
    if maxBytes <= 1 then
        return
    end
    local maxLineLen = maxBytes - 1
    if #s > maxLineLen then
        s = s:sub(1, maxLineLen)
    end

    if ring.lines == nil then
        ring.lines = {}
        ring.bytes = 0
        ring.head, ring.tail = 1, 0
    end

    ring.tail = ring.tail + 1
    ring.lines[ring.tail] = s
    ring.bytes = ring.bytes + #s + 1

    TrimExportBuffer(WebExport.GetMaxLines())
    if ring.lines == nil then
        return
    end

    -- Renumber occasionally so indices never grow without bound (cheap: at most once per MAX_CAPTURE_LINES appends).
    if ring.head > MAX_CAPTURE_LINES * 4 then
        local compact, n = {}, 0
        for i = ring.head, ring.tail do n = n + 1; compact[n] = ring.lines[i] end
        ring.lines, ring.head, ring.tail = compact, 1, n
    end
end

---@return number
function WebExport.BufferCount()
    if ring.lines == nil then
        return 0
    end
    return ring.tail - ring.head + 1
end

-- ============================================================================
-- Scopes
--
-- A line's scope is its leading "[Name] " tag: the one LibConsoleLogger:For("Name") puts on every line it logs,
-- and the one this library puts on its own lines (the UI-load markers). The tag is read off the line itself, so
-- it holds for lines saved by an earlier UI load and for an addon that writes the tag by hand.
-- ============================================================================

---@param line string
---@return string|nil scope
function WebExport.ScopeOf(line)
    return string.match(line, "^%[([^%]]+)%] ")
end

---Whether a line shows under a scope: every line under "" (all scopes), else that scope's lines, the
---library's own (the UI-load markers are the only clock a log has) and, with includeErrors, the game's errors.
---@param line string
---@param scope string|nil
---@param includeErrors boolean|nil
---@return boolean
function WebExport.InScope(line, scope, includeErrors)
    if scope == nil or scope == "" then
        return true
    end
    local lineScope = WebExport.ScopeOf(line)
    return lineScope == scope
        or lineScope == LibConsoleLogger.name
        or (includeErrors == true and lineScope == LibConsoleLogger.errorsScope)
end

---The buffered lines, oldest first; with a scope, only the lines that show under it (WebExport.InScope).
---@param scope string|nil
---@param includeErrors boolean|nil
---@return string[]
function WebExport.BufferGetLines(scope, includeErrors)
    if ring.lines == nil or ring.head > ring.tail then
        return EMPTY_STRING_ARRAY
    end

    local copy, n = {}, 0
    for i = ring.head, ring.tail do
        local line = ring.lines[i]
        if WebExport.InScope(line, scope, includeErrors) then
            n = n + 1
            copy[n] = line
        end
    end
    return copy
end

---How many buffered lines each scope holds.
---@return table<string, number>
function WebExport.BufferScopes()
    local counts = {}
    if ring.lines == nil then
        return counts
    end
    for i = ring.head, ring.tail do
        local scope = WebExport.ScopeOf(ring.lines[i])
        if scope then
            counts[scope] = (counts[scope] or 0) + 1
        end
    end
    return counts
end

-- Take one scope's lines (and the errors, when they went out with it) out of the buffer, in place: the ring is
-- the saved table (see above).
---@param scope string
---@param includeErrors boolean
local function RemoveScopeLines(scope, includeErrors)
    if ring.lines == nil then
        return
    end
    local kept, n, bytes = {}, 0, 0
    for i = ring.head, ring.tail do
        local line = ring.lines[i]
        local lineScope = WebExport.ScopeOf(line)
        local sent = lineScope == scope or (includeErrors and lineScope == LibConsoleLogger.errorsScope)
        if not sent then
            n = n + 1
            kept[n] = line
            bytes = bytes + #line + 1
        end
    end
    if n == 0 then
        ClearExportBuffer()
        return
    end
    ring.lines, ring.head, ring.tail, ring.bytes = kept, 1, n, bytes
end

-- ============================================================================
-- Submit state (shared across all addons)
-- ============================================================================

local submitState = nil
local EXPORT_EVENT_NAMESPACE = "LibConsoleLogger_WebExport"
local OPEN_TIMEOUT_MS = 10000
local MAX_OPEN_ATTEMPTS = 2
local NEXT_CHUNK_DELAY_MS = 25
local browserEventsRegistered = false

local function UnregisterBrowserEvents()
    if not browserEventsRegistered then return end
    if not EVENT_MANAGER then return end
    EVENT_MANAGER:UnregisterForEvent(EXPORT_EVENT_NAMESPACE, EVENT_WEB_BROWSER_OPENED)
    EVENT_MANAGER:UnregisterForEvent(EXPORT_EVENT_NAMESPACE, EVENT_WEB_BROWSER_CLOSED)
    browserEventsRegistered = false
end

local function StopExport(message)
    local s = submitState
    if s and s.openTimeoutCallLaterId then
        zo_removeCallLater(s.openTimeoutCallLaterId)
        s.openTimeoutCallLaterId = nil
    end
    if s and s.scheduledAttemptCallLaterId then
        zo_removeCallLater(s.scheduledAttemptCallLaterId)
        s.scheduledAttemptCallLaterId = nil
    end
    submitState = nil
    UnregisterBrowserEvents()
    if message ~= nil then
        ReportStatus(message)
    end
end

local AttemptOpenCurrentChunk -- forward decl
local ScheduleAttempt         -- forward decl

local function OnScheduledAttempt(callLaterId)
    local s = submitState
    if not s then return end
    if s.scheduledAttemptCallLaterId ~= callLaterId then return end

    s.scheduledAttemptCallLaterId = nil
    AttemptOpenCurrentChunk()
end

ScheduleAttempt = function(delayMs)
    local s = submitState
    if not s then return end

    if s.scheduledAttemptCallLaterId then
        zo_removeCallLater(s.scheduledAttemptCallLaterId)
        s.scheduledAttemptCallLaterId = nil
    end

    s.scheduledAttemptCallLaterId = zo_callLater(OnScheduledAttempt, delayMs or 0)
end

local function OnOpenTimeout(callLaterId)
    local s = submitState
    if not s then return end
    if s.openTimeoutCallLaterId ~= callLaterId then return end

    s.openTimeoutCallLaterId = nil
    if not s.awaitingOpen then return end

    if (s.attempts or 0) < MAX_OPEN_ATTEMPTS then
        -- This attempt timed out; ignore any late EVENT_WEB_BROWSER_OPENED and retry.
        s.awaitingOpen = false
        ReportStatusf("[LibConsoleLogger] No browser open within %ds; retrying chunk %d/%d",
            OPEN_TIMEOUT_MS / 1000, s.currentIndex, s.totalChunks)
        ScheduleAttempt(0)
        return
    end

    StopExport(string.format("[LibConsoleLogger] Export cancelled (browser did not open): chunk %d/%d",
        s.currentIndex, s.totalChunks))
end

local function OnWebBrowserOpened(_eventId)
    local s = submitState
    if not s then return end
    if s.awaitingClose then return end

    -- Treat as success if we were awaiting open, OR if a timeout scheduled a retry but the browser opened late.
    local shouldHandle = (s.awaitingOpen == true) or (s.scheduledAttemptCallLaterId ~= nil and (s.attempts or 0) > 0)
    if not shouldHandle then
        return
    end

    s.awaitingOpen = false
    s.awaitingClose = true
    s.attempts = 0

    if s.scheduledAttemptCallLaterId then
        zo_removeCallLater(s.scheduledAttemptCallLaterId)
        s.scheduledAttemptCallLaterId = nil
    end

    if s.openTimeoutCallLaterId then
        zo_removeCallLater(s.openTimeoutCallLaterId)
        s.openTimeoutCallLaterId = nil
    end
end

local function OnWebBrowserClosed(_eventId)
    local s = submitState
    if not s or not s.awaitingClose then return end

    s.awaitingClose = false

    -- Advance only after the user closes the browser (one chunk per open/close cycle).
    s.currentIndex = s.currentIndex + 1
    if s.currentIndex > s.totalChunks then
        StopExport(string.format("[LibConsoleLogger] Export complete: %d chunks sent", s.totalChunks))
        return
    end

    ScheduleAttempt(NEXT_CHUNK_DELAY_MS)
end

local function EnsureBrowserEventsRegistered()
    if browserEventsRegistered then return true end
    if not EVENT_MANAGER then return false end

    EVENT_MANAGER:RegisterForEvent(EXPORT_EVENT_NAMESPACE, EVENT_WEB_BROWSER_OPENED, OnWebBrowserOpened)
    EVENT_MANAGER:RegisterForEvent(EXPORT_EVENT_NAMESPACE, EVENT_WEB_BROWSER_CLOSED, OnWebBrowserClosed)
    browserEventsRegistered = true
    return true
end

---@param url string
---@return boolean ok
local function TryOpenUnsafeUrl(url)
    local requestFn = rawget(_G, "RequestOpenUnsafeURL")
    if not requestFn then
        return false
    end

    -- RequestOpenUnsafeURL may or may not be protected depending on platform/build.
    -- Prefer the ESO idiom used by other addons:
    --   IsProtectedFunction(...) and CallSecureProtected(...) or UnprotectedCall(...)
    -- Also: CallSecureProtected returns a boolean; we must honor that return value.
    local isProtected = false
    local isProtectedFn = rawget(_G, "IsProtectedFunction")
    if isProtectedFn then
        local ok, protected = pcall(isProtectedFn, "RequestOpenUnsafeURL")
        isProtected = ok and protected == true
    end

    local secureFn = rawget(_G, "CallSecureProtected")
    if isProtected and secureFn then
        local ok, secureOk = pcall(secureFn, "RequestOpenUnsafeURL", url)
        if ok and secureOk == true then
            return true
        end

        -- Fallback: if protection detection is wrong/missing, a direct call may still work.
        local directOk = pcall(requestFn, url)
        return directOk
    end

    local ok = pcall(requestFn, url)
    return ok
end

-- Base64 encode
---@param data string
---@return string
local function Base64Encode(data)
    local result = {}
    local len = #data
    local i = 1
    while i <= len do
        local b1 = data:byte(i) or 0
        local b2 = data:byte(i + 1) or 0
        local b3 = data:byte(i + 2) or 0

        local n = b1 * 65536 + b2 * 256 + b3

        result[#result + 1] = BASE64_CHARS:sub(math.floor(n / 262144) + 1, math.floor(n / 262144) + 1)
        result[#result + 1] = BASE64_CHARS:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        result[#result + 1] = BASE64_CHARS:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
        result[#result + 1] = BASE64_CHARS:sub(n % 64 + 1, n % 64 + 1)

        i = i + 3
    end

    -- Padding
    local padding = (3 - len % 3) % 3
    for p = 1, padding do
        result[#result - p + 1] = "="
    end

    return table.concat(result)
end

AttemptOpenCurrentChunk = function()
    local s = submitState
    if not s then return end

    if not IsRuntimeEnabled() and not s.allowWhenDisabled then
        StopExport("[LibConsoleLogger] Export cancelled (disabled)")
        return
    end

    -- Strict serialization: do not attempt another chunk while waiting for open or close.
    if s.awaitingOpen or s.awaitingClose then
        return
    end

    if s.currentIndex > s.totalChunks then
        StopExport(string.format("[LibConsoleLogger] Export complete: %d chunks sent", s.totalChunks))
        return
    end

    if not rawget(_G, "RequestOpenUnsafeURL") then
        StopExport("[LibConsoleLogger] Export cancelled (RequestOpenUnsafeURL unavailable)")
        return
    end

    s.attempts = (s.attempts or 0) + 1
    s.awaitingOpen = true
    s.awaitingClose = false

    local chunk = s.chunks[s.currentIndex]
    local b64 = s.base64Chunks[s.currentIndex]
    if not b64 then
        b64 = Base64Encode(chunk)
        s.base64Chunks[s.currentIndex] = b64
    end
    local url = s.baseUrl .. "?d=" .. b64

    ReportStatusf("[LibConsoleLogger] Chunk %d/%d (attempt %d)", s.currentIndex, s.totalChunks, s.attempts)
    if not TryOpenUnsafeUrl(url) then
        StopExport("[LibConsoleLogger] Export cancelled (failed to open URL)")
        return
    end

    if s.openTimeoutCallLaterId then
        zo_removeCallLater(s.openTimeoutCallLaterId)
        s.openTimeoutCallLaterId = nil
    end
    s.openTimeoutCallLaterId = zo_callLater(OnOpenTimeout, OPEN_TIMEOUT_MS)
end

---@param allText string
---@param cfg table|nil
---@param allowWhenDisabled boolean|nil
---@return boolean ok
---@return string|nil reason
local function StartSubmit(allText, cfg, allowWhenDisabled)
    if not IsRuntimeEnabled() and not allowWhenDisabled then
        return false, "disabled"
    end
    if not rawget(_G, "RequestOpenUnsafeURL") then
        return false, "no-api"
    end
    if not allText or allText == "" then
        return false, "empty"
    end
    if submitState then
        return false, "busy"
    end

    local baseUrl = GetBaseUrl(cfg)
    if not baseUrl or baseUrl == "" then
        return false, "no-url"
    end

    allText = EnsureTrailingNewline(allText)

    -- Calculate how much raw text fits per chunk
    -- URL format: baseUrl?d=<base64>
    -- Base64 expands by 4/3, so raw chars per chunk = (maxUrl - baseLen - 3) * 3/4
    local maxUrlLen = MAX_URL_LEN
    local baseLen = #baseUrl + 3                         -- "?d="
    local maxB64Len = maxUrlLen - baseLen
    local maxRawLen = math.floor(maxB64Len * 3 / 4) - 10 -- safety margin

    if maxRawLen <= 0 then
        return false, "url-too-long"
    end

    -- Split into chunks (prefer newline boundaries)
    local chunks = {}
    local pos = 1
    while pos <= #allText do
        local maxEnd = math.min(#allText, pos + maxRawLen - 1)
        local endPos = maxEnd

        local window = allText:sub(pos, maxEnd)
        local lastNl = nil
        local searchFrom = 1
        while true do
            local found = string.find(window, "\n", searchFrom, true)
            if not found then
                break
            end
            lastNl = found
            searchFrom = found + 1
        end
        if lastNl and lastNl > 1 then
            endPos = pos + lastNl - 1
        end

        local chunk = allText:sub(pos, endPos)
        chunks[#chunks + 1] = chunk
        pos = endPos + 1
    end

    if #chunks == 0 then
        return false, "no-chunks"
    end

    submitState = {
        chunks = chunks,
        base64Chunks = {},
        currentIndex = 1,
        totalChunks = #chunks,
        baseUrl = baseUrl,
        awaitingOpen = false,
        awaitingClose = false,
        attempts = 0,
        allowWhenDisabled = allowWhenDisabled == true,
        openTimeoutCallLaterId = nil,
        scheduledAttemptCallLaterId = nil,
    }

    if not EnsureBrowserEventsRegistered() then
        submitState = nil
        return false, "no-event-manager"
    end

    ReportStatusf("[LibConsoleLogger] Exporting %d chunks (close browser after each; cancel via LibConsoleLogger.WebExport.CancelExport())",
        #chunks)
    AttemptOpenCurrentChunk()
    return true, nil
end

function WebExport.CancelExport()
    if not submitState then
        ReportStatus("[LibConsoleLogger] No export in progress")
        return
    end

    local s = submitState
    StopExport(string.format("[LibConsoleLogger] Export cancelled at chunk %d/%d", s.currentIndex, s.totalChunks))
end

---Export the buffer, then empty it. With a scope, export the lines that show under it (WebExport.InScope) and
---take out only that scope's lines and the errors sent with them; the other scopes and the UI-load markers
---stay buffered.
---@param cfg table|nil
---@param scope string|nil
---@param includeErrors boolean|nil
---@return boolean ok
---@return string|nil reason
function WebExport.SubmitBuffered(cfg, scope, includeErrors)
    if not IsRuntimeEnabled() then
        return false, "disabled"
    end

    if WebExport.BufferCount() == 0 then
        return false, "empty"
    end

    local scoped = scope ~= nil and scope ~= ""
    includeErrors = includeErrors == true
    if scoped then
        local counts = WebExport.BufferScopes()
        if not (counts[scope] or (includeErrors and counts[LibConsoleLogger.errorsScope])) then
            ReportStatusf("[LibConsoleLogger] Nothing buffered for scope %s", scope)
            return false, "empty"
        end
    end

    local lines = WebExport.BufferGetLines(scope, includeErrors)
    if #lines == 0 then
        return false, "empty"
    end

    -- Always end with a newline so repeated exports don't run together in receivers.
    local allText = EnsureTrailingNewline(table.concat(lines, "\n"))
    local ok, reason = StartSubmit(allText, cfg, false)
    if ok then
        if scoped then
            RemoveScopeLines(scope, includeErrors)
        else
            WebExport.BufferClear()
        end
        return true, nil
    end
    return false, reason
end

--- Export raw text (adds a small metadata header).
---@param exportType string
---@param source string
---@param rawText string
---@param cfg table|nil
---@param allowWhenDisabled boolean|nil
---@return boolean ok
---@return string|nil reason
function WebExport.ExportRaw(exportType, source, rawText, cfg, allowWhenDisabled)
    if not IsRuntimeEnabled() and not allowWhenDisabled then
        return false, "disabled"
    end
    if not rawText or rawText == "" then
        return false, "empty"
    end

    local header = string.format("type:%s|source:%s|time:%d\n",
        tostring(exportType or ""),
        tostring(source or ""),
        (GetTimeStamp and GetTimeStamp()) or 0)
    local allText = header .. tostring(rawText)
    allText = EnsureTrailingNewline(allText)
    return StartSubmit(allText, cfg, allowWhenDisabled)
end

---@return boolean ok
---@return string|nil reason
function WebExport.Reset()
    ClearExportBuffer()
    lastStatus = nil
    if submitState ~= nil then
        StopExport(nil)
    else
        UnregisterBrowserEvents()
    end
    return true, nil
end


