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

local CONTINUES = "(continues the line above) "

---A line as the lines the buffer keeps for it: itself when short, else cut into lines of at most
---Utils.MAX_SAVED_STRING_BYTES, the later ones under the same "[Name] " tag and marked, so that they stay in
---the line's scope and the whole can be joined again. The buffer lives in the saved variables, which cannot
---hold a longer string.
---@param line string
---@return string[]
function WebExport.SafeLines(line)
    local max = Utils.MAX_SAVED_STRING_BYTES
    if #line <= max then
        return { line }
    end
    local tag = string.match(line, "^(%[[^%]]+%] )") or ""
    local prefix = tag .. CONTINUES
    if #prefix >= max / 2 then
        prefix = CONTINUES
    end
    local first = Utils.Pieces(line, max)[1]
    local out = { first }
    for _, piece in ipairs(Utils.Pieces(string.sub(line, #first + 1), max - #prefix)) do
        out[#out + 1] = prefix .. piece
    end
    return out
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
        if type(line) == "string" then
            -- A line saved by a version that kept long ones is cut here, like a new one.
            for _, part in ipairs(WebExport.SafeLines(line)) do
                out[#out + 1] = part
            end
        end
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
    WebExport._AdoptSavedExports(keep)
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
    if #s > Utils.MAX_SAVED_STRING_BYTES then
        for _, part in ipairs(WebExport.SafeLines(s)) do
            WebExport.BufferD(part)
        end
        return
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
-- Past exports
--
-- An export takes its lines out of the buffer when it starts, and the library cannot tell whether a chunk
-- reached the receiver: it sees the browser open and close, nothing more. So the chunks of the last few
-- exports are kept, in the saved variables like the buffer, and any of them can be sent again: all of an
-- export, the chunks whose browser never opened, or one chunk. Each chunk goes out under a line naming its
-- export and its place in it, so the receiving end can see a gap or a repeat.
-- ============================================================================

local MAX_KEPT_EXPORTS = 5
-- Older exports are dropped past this many bytes of chunk text; the newest is kept whatever its size.
local MAX_KEPT_EXPORT_BYTES = 512 * 1024
-- Room left in every chunk for the line it is sent under (ChunkHeader).
local CHUNK_HEADER_RESERVE = 100

---@class LibConsoleLoggerExportRecord One export, as saved
---@field id number Counts up for the life of the saved variables
---@field at string Wall clock when it started
---@field scope string The scope it carried; "" for all scopes
---@field chunks string[][] The text of each chunk, without the line it is sent under, in pieces short enough to be saved
---@field opens number[] Times the browser opened for each chunk
---@field bytes number

-- Exports started before the saved variables load are held here and moved over when they do.
---@type { seq: number, list: LibConsoleLoggerExportRecord[] }
local memoryStore = { seq = 0, list = {} }

---@param record any
---@return boolean
local function IsExportRecord(record)
    if type(record) ~= "table" or type(record.id) ~= "number" or type(record.chunks) ~= "table" then
        return false
    end
    if #record.chunks == 0 or type(record.opens) ~= "table" then
        return false
    end
    for i = 1, #record.chunks do
        local pieces = record.chunks[i]
        if type(pieces) ~= "table" or #pieces == 0 or type(record.opens[i]) ~= "number" then
            return false
        end
        for p = 1, #pieces do
            if type(pieces[p]) ~= "string" or #pieces[p] > Utils.MAX_SAVED_STRING_BYTES then
                return false
            end
        end
    end
    return true
end

---The text of one chunk of a kept export.
---@param record LibConsoleLoggerExportRecord
---@param index number
---@return string
local function ChunkText(record, index)
    return table.concat(record.chunks[index])
end

---The table the kept exports live in: the saved variables' once they are loaded.
---@return { seq: number, list: LibConsoleLoggerExportRecord[] }
local function ExportStore()
    if not (EnsureSavedVars() and LibConsoleLogger.savedVars ~= nil) then
        return memoryStore
    end
    local sv = LibConsoleLogger.savedVars
    local store = sv.exports
    if type(store) ~= "table" or type(store.list) ~= "table" or type(store.seq) ~= "number" then
        store = { seq = 0, list = {} }
        sv.exports = store
    end
    return store
end

---Drop the oldest exports past the caps. The newest stays whatever its size.
---@param list LibConsoleLoggerExportRecord[]
local function TrimExports(list)
    local bytes = 0
    for i = 1, #list do
        bytes = bytes + (tonumber(list[i].bytes) or 0)
    end
    while #list > 1 and (#list > MAX_KEPT_EXPORTS or bytes > MAX_KEPT_EXPORT_BYTES) do
        bytes = bytes - (tonumber(list[1].bytes) or 0)
        table.remove(list, 1)
    end
end

---Read the kept exports back after a UI load: unreadable ones (older format, hand-edited) are dropped, and
---any started before the saved variables loaded are moved in. With keep == false (logging disabled) all go.
---@param keep boolean
function WebExport._AdoptSavedExports(keep)
    local store = ExportStore()
    if store == memoryStore then
        return
    end
    local kept = {}
    if keep then
        for i = 1, #store.list do
            local record = store.list[i]
            if IsExportRecord(record) then
                kept[#kept + 1] = record
                if record.id > store.seq then store.seq = record.id end
            end
        end
        for i = 1, #memoryStore.list do
            local record = memoryStore.list[i]
            store.seq = store.seq + 1
            record.id = store.seq
            kept[#kept + 1] = record
        end
        TrimExports(kept)
    end
    store.list = kept
    memoryStore = { seq = 0, list = {} }
end

---@param chunks string[]
---@param scope string|nil
---@return LibConsoleLoggerExportRecord
local function KeepExport(chunks, scope)
    local store = ExportStore()
    store.seq = store.seq + 1
    -- A chunk is some 6 KB of text and the saved variables hold no string of 2000 bytes: it is kept in pieces.
    local opens, bytes, kept = {}, 0, {}
    for i = 1, #chunks do
        opens[i] = 0
        bytes = bytes + #chunks[i]
        kept[i] = Utils.Pieces(chunks[i], Utils.MAX_SAVED_STRING_BYTES)
    end
    local record = {
        id = store.seq,
        at = Utils.WallClock(GetTimeStamp and GetTimeStamp() or 0),
        scope = type(scope) == "string" and scope or "",
        chunks = kept,
        opens = opens,
        bytes = bytes,
    }
    store.list[#store.list + 1] = record
    TrimExports(store.list)
    return record
end

---@param id number|nil nil for the newest
---@return LibConsoleLoggerExportRecord|nil
local function FindExport(id)
    local list = ExportStore().list
    if id == nil then
        return list[#list]
    end
    for i = #list, 1, -1 do
        if list[i].id == id then
            return list[i]
        end
    end
    return nil
end

---@param record LibConsoleLoggerExportRecord
---@return number opened Chunks whose browser opened at least once
local function OpenedCount(record)
    local opened = 0
    for i = 1, #record.chunks do
        if (record.opens[i] or 0) > 0 then
            opened = opened + 1
        end
    end
    return opened
end

---The line a chunk is sent under. A chunk that starts inside a line (one line longer than a chunk) says so,
---on a line of its own, so the two halves can be told and joined.
---@param record LibConsoleLoggerExportRecord
---@param index number
---@param again boolean
---@return string
local function ChunkHeader(record, index, again)
    local continues = index > 1 and string.sub(ChunkText(record, index - 1), -1) ~= "\n"
    return string.format("%s[%s] --- export %d chunk %d/%d%s%s ---\n",
        continues and "\n" or "",
        LibConsoleLogger.name, record.id, index, #record.chunks,
        again and ", sent again" or "",
        continues and ", continues the line above" or "")
end

---The kept exports, newest first.
---@return { id: number, at: string, scope: string, chunks: number, opened: number, opens: number[], bytes: number }[]
function WebExport.GetPastExports()
    local list = ExportStore().list
    local out = {}
    for i = #list, 1, -1 do
        local record = list[i]
        local opens = {}
        for c = 1, #record.chunks do
            opens[c] = record.opens[c] or 0
        end
        out[#out + 1] = {
            id = record.id,
            at = tostring(record.at or ""),
            scope = tostring(record.scope or ""),
            chunks = #record.chunks,
            opened = OpenedCount(record),
            opens = opens,
            bytes = tonumber(record.bytes) or 0,
        }
    end
    return out
end

---Forget the kept exports. The caller stops an export being sent first.
local function ClearPastExports()
    local store = ExportStore()
    store.list = {}
    memoryStore.list = {}
end

-- ============================================================================
-- Submit state (shared across all addons)
-- ============================================================================

---@class LibConsoleLoggerSubmitState The export being sent
---@field record LibConsoleLoggerExportRecord
---@field order number[] The chunks to send, by their index in the record
---@field position number Index into order of the chunk being sent
---@field again boolean A kept export being sent again
---@field baseUrl string
---@field awaitingOpen boolean
---@field awaitingClose boolean
---@field attempts number
---@field allowWhenDisabled boolean
---@field base64 table<number, string> Encoded chunks, by position
---@field openTimeoutCallLaterId number|nil
---@field scheduledAttemptCallLaterId number|nil

---@type LibConsoleLoggerSubmitState|nil
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

---Where the export being sent stands: "chunk 3/7", and for a kept export sent again which one it is.
---@param s LibConsoleLoggerSubmitState
---@return string
local function Progress(s)
    local index = s.order[s.position] or s.order[#s.order]
    if s.again then
        return string.format("chunk %d/%d of export %d, sent again (%d of %d)",
            index, #s.record.chunks, s.record.id, math.min(s.position, #s.order), #s.order)
    end
    return string.format("chunk %d/%d", index, #s.record.chunks)
end

---@param s LibConsoleLoggerSubmitState
---@return string
local function CompleteMessage(s)
    if s.again then
        return string.format("[LibConsoleLogger] Export %d sent again: %d chunks. A chunk that did not arrive can be sent again from the settings (Past exports)",
            s.record.id, #s.order)
    end
    return string.format("[LibConsoleLogger] Export complete: %d chunks sent (export %d; it can be sent again from the settings, Past exports)",
        #s.order, s.record.id)
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
        ReportStatusf("[LibConsoleLogger] No browser open within %ds; retrying %s",
            OPEN_TIMEOUT_MS / 1000, Progress(s))
        ScheduleAttempt(0)
        return
    end

    StopExport(string.format("[LibConsoleLogger] Export cancelled (browser did not open): %s. The chunks are kept: send them again from the settings (Past exports)",
        Progress(s)))
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

    -- The browser opening is all the library can see of a chunk's delivery; it is counted on the kept export.
    local index = s.order[s.position]
    if index then
        s.record.opens[index] = (s.record.opens[index] or 0) + 1
    end

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
    s.position = s.position + 1
    if s.position > #s.order then
        StopExport(CompleteMessage(s))
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

    if s.position > #s.order then
        StopExport(CompleteMessage(s))
        return
    end

    if not rawget(_G, "RequestOpenUnsafeURL") then
        StopExport("[LibConsoleLogger] Export cancelled (RequestOpenUnsafeURL unavailable)")
        return
    end

    local index = s.order[s.position]
    local b64 = s.base64[s.position]
    if not b64 then
        b64 = Base64Encode(ChunkHeader(s.record, index, s.again) .. ChunkText(s.record, index))
        s.base64[s.position] = b64
    end
    local url = s.baseUrl .. "?d=" .. b64
    if #url > MAX_URL_LEN then
        -- A kept chunk was cut to fit the export URL of its day; a longer URL since leaves it no room.
        StopExport(string.format("[LibConsoleLogger] Export cancelled: %s does not fit the export URL, which is longer than when it was exported",
            Progress(s)))
        return
    end

    s.attempts = (s.attempts or 0) + 1
    s.awaitingOpen = true
    s.awaitingClose = false

    ReportStatusf("[LibConsoleLogger] %s (attempt %d)", Progress(s), s.attempts)
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

---Start sending chunks of a kept export, one browser open/close cycle each.
---@param record LibConsoleLoggerExportRecord
---@param order number[] The chunks to send, by index
---@param again boolean
---@param baseUrl string
---@param allowWhenDisabled boolean|nil
---@return boolean ok
---@return string|nil reason
local function BeginSubmit(record, order, again, baseUrl, allowWhenDisabled)
    submitState = {
        record = record,
        order = order,
        position = 1,
        again = again,
        baseUrl = baseUrl,
        awaitingOpen = false,
        awaitingClose = false,
        attempts = 0,
        allowWhenDisabled = allowWhenDisabled == true,
        base64 = {},
        openTimeoutCallLaterId = nil,
        scheduledAttemptCallLaterId = nil,
    }

    if not EnsureBrowserEventsRegistered() then
        submitState = nil
        return false, "no-event-manager"
    end

    if again then
        ReportStatusf("[LibConsoleLogger] Sending %d chunks of export %d again (close browser after each)", #order, record.id)
    else
        ReportStatusf("[LibConsoleLogger] Exporting %d chunks (close browser after each; cancel via LibConsoleLogger.WebExport.CancelExport())",
            #order)
    end
    AttemptOpenCurrentChunk()
    return true, nil
end

---@param allText string
---@param cfg table|nil
---@param allowWhenDisabled boolean|nil
---@param scope string|nil The scope the text was taken from, for the kept export
---@return boolean ok
---@return string|nil reason
local function StartSubmit(allText, cfg, allowWhenDisabled, scope)
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
    -- Base64 expands by 4/3, so raw chars per chunk = (maxUrl - baseLen - 3) * 3/4, less the line the chunk
    -- is sent under (ChunkHeader)
    local maxUrlLen = MAX_URL_LEN
    local baseLen = #baseUrl + 3                         -- "?d="
    local maxB64Len = maxUrlLen - baseLen
    local maxRawLen = math.floor(maxB64Len * 3 / 4) - 10 - CHUNK_HEADER_RESERVE -- safety margin

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

    local order = {}
    for i = 1, #chunks do
        order[i] = i
    end
    return BeginSubmit(KeepExport(chunks, scope), order, false, baseUrl, allowWhenDisabled)
end

function WebExport.CancelExport()
    if not submitState then
        ReportStatus("[LibConsoleLogger] No export in progress")
        return
    end

    local s = submitState
    StopExport(string.format("[LibConsoleLogger] Export cancelled at %s. The chunks are kept: send them again from the settings (Past exports)",
        Progress(s)))
end

---Send a kept export again: all of it, the chunks whose browser never opened, or one chunk.
---@param id number|nil The export's id (WebExport.GetPastExports); nil for the newest
---@param which nil|"all"|"unopened"|number Which chunks; nil is all
---@param cfg table|nil
---@return boolean ok
---@return string|nil reason "disabled", "no-api", "busy", "unknown-export", "no-url" or "empty" (no such chunk, or none unopened)
function WebExport.Resend(id, which, cfg)
    if not IsRuntimeEnabled() then
        return false, "disabled"
    end
    if not rawget(_G, "RequestOpenUnsafeURL") then
        return false, "no-api"
    end
    if submitState then
        return false, "busy"
    end
    local record = FindExport(id)
    if not record then
        ReportStatus("[LibConsoleLogger] No such past export")
        return false, "unknown-export"
    end
    local baseUrl = GetBaseUrl(cfg)
    if not baseUrl or baseUrl == "" then
        return false, "no-url"
    end

    local order = {}
    if type(which) == "number" then
        local index = math.floor(which)
        if index >= 1 and index <= #record.chunks then
            order[1] = index
        end
    else
        for i = 1, #record.chunks do
            if which ~= "unopened" or (record.opens[i] or 0) == 0 then
                order[#order + 1] = i
            end
        end
    end
    if #order == 0 then
        ReportStatusf("[LibConsoleLogger] Nothing to send again from export %d", record.id)
        return false, "empty"
    end
    return BeginSubmit(record, order, true, baseUrl, false)
end

---Forget the kept exports; one being sent is cancelled.
function WebExport.ClearPastExports()
    if submitState ~= nil then
        StopExport("[LibConsoleLogger] Export cancelled (past exports cleared)")
    end
    ClearPastExports()
end

---Export the buffer, then empty it. With a scope, export the lines that show under it (WebExport.InScope) and
---take out only that scope's lines and the errors sent with them; the other scopes and the UI-load markers
---stay buffered. The chunks are kept as a past export (WebExport.Resend) in case one does not arrive.
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
    local ok, reason = StartSubmit(allText, cfg, false, scope)
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
    return StartSubmit(allText, cfg, allowWhenDisabled, source)
end

---Disable: the buffer, the kept exports and any export being sent all go.
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
    ClearPastExports()
    return true, nil
end
