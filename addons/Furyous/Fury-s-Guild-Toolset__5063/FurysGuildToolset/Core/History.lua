-- Streams guild history to modules through LibHistoire 2.x.
--
-- Why LibHistoire: since Update 41 the game only keeps guild history the server has sent
-- on request, in chunks, with gaps. LibHistoire keeps a gap-free "managed range" per
-- guild and category, saves it between sessions and requests missing data in the
-- background. We only remember the last eventId we processed per guild/category, so each
-- login resumes exactly where the previous session stopped.

local GT = FurysGuildToolset
local History = {}
GT.History = History

local RETRY_MS = 60 * 1000      -- LibHistoire has no cache yet for some guild: try again later
local MAX_RETRIES = 10

History.processors = {}   -- list of processors we started
History.pending = {}      -- [stream] = number of guild processors still replaying backlog
History.caughtUp = {}     -- [stream] = true once every started reader for it is live
History.live = {}         -- ["guildId:stream"] = true once that reader has replayed its backlog

-- A "stream" is one category read by one reader. Most modules share the main reader, whose
-- stream is just the category number. A module with its own historyReader (the Trader week
-- totals) gets its own processors and its own saved position, so it can read the whole
-- look-back period on first use without replaying old events to the other modules.
local MAIN_READER = "main"
local function StreamKey(reader, category)
    if reader == MAIN_READER then return category end
    return reader .. ":" .. category
end

-- Copies only plain fields: LibHistoire event objects must not be stored.
local NAME_FIELDS = { "displayName", "actingDisplayName", "targetDisplayName", "sellerDisplayName", "buyerDisplayName" }

local function CopyEventInfo(event)
    local info = event:GetEventInfo()
    local copy = {}
    for k, v in pairs(info) do
        if type(v) ~= "table" then copy[k] = v end   -- plain values only; the event object must not be kept
    end
    -- Guild history gives account names without the leading "@", but every roster
    -- function (rank lookup, demote, kick, blacklist) needs it. Add it once here.
    for _, field in ipairs(NAME_FIELDS) do
        local name = copy[field]
        if name and name ~= "" and name:sub(1, 1) ~= "@" then copy[field] = "@" .. name end
    end
    return copy
end

History.CopyEventInfo = CopyEventInfo   -- 1.34.7: also used by Core/HoleFill.lua

-- 1.34.7: hands an event the hole filler fetched (info.backfilled = true) to the modules of the
-- main reader, the same way LibHistoire's events reach them. Saved reading positions don't
-- change, and modules see isLive = false.
function History:DeliverBackfilled(guildId, category, info)
    for _, module in ipairs((self.subscribers or {})[StreamKey(MAIN_READER, category)] or {}) do
        module:OnHistoryEvent(guildId, category, info, false)
    end
end

-- Returns a list of { reader =, category =, stream = } and the modules per stream.
local function CollectStreams()
    local wanted, subscribers = {}, {}
    for _, id in ipairs(GT.moduleOrder) do
        local module = GT.modules[id]
        if module.GetHistoryCategories then
            local reader = module.historyReader or MAIN_READER
            for _, category in ipairs(module:GetHistoryCategories() or {}) do
                local stream = StreamKey(reader, category)
                if not subscribers[stream] then
                    subscribers[stream] = {}
                    -- readAll: on first use, read everything LibHistoire has saved, not just the look-back period.
                    wanted[#wanted + 1] = { reader = reader, category = category, stream = stream, readAll = module.historyReadAll }
                end
                table.insert(subscribers[stream], module)
            end
        end
    end
    return wanted, subscribers
end

function History:FinishStream(stream, category)
    if self.caughtUp[stream] then return end
    self.caughtUp[stream] = true
    for _, module in ipairs(self.subscribers[stream] or {}) do
        if module.OnHistoryCaughtUp then module:OnHistoryCaughtUp(category) end
    end
    if self.backfill then self:MaybeFinishBackfill() end
end

-- One-time backfill (0.4.21). LibHistoire can add older history to its saved range after
-- our reader has already moved past that point (for example a guild whose history it was
-- still collecting on first run). Those events never reached the History log, so they
-- could never alert. The fix reads the look-back period again from LibHistoire's saved
-- history (no server requests), lets the History log add what it was missing, and then
-- rebuilds bank alerts and hoppers from the log, keeping what you already did with them.
-- If the game closes before it finishes, it simply runs again at the next login.
local BACKFILL_VERSION = 1

function History:PrepareBackfill()
    local sv = GT.sv
    if (sv.historyBackfill or 0) >= BACKFILL_VERSION then return end
    self.backfill = true
    self.oldCursors = {}
    -- Main-reader keys are LibHistoire's own; other readers' keys start with "<reader>:".
    for key, eventId in pairs(sv.historyCursor) do
        if not self:IsOtherReaderKey(key) then
            self.oldCursors[key] = eventId
            sv.historyCursor[key] = nil
        end
    end
    local log = GT:GetModule("log")
    self.logCountBefore = #log.entries
end

function History:IsOtherReaderKey(key)
    for _, id in ipairs(GT.moduleOrder) do
        local reader = GT.modules[id].historyReader
        if reader and key:sub(1, #reader + 1) == reader .. ":" then return true end
    end
    return false
end

function History:MaybeFinishBackfill()
    for _, def in ipairs(self.streams) do
        if def.reader == MAIN_READER and not self.caughtUp[def.stream] then return end
    end
    self.backfill = false
    GT.sv.historyBackfill = BACKFILL_VERSION
    local log = GT:GetModule("log")
    local added = #log.entries - (self.logCountBefore or #log.entries)
    GT.Util.Print("History check done: %d %s the addon had missed %s now in the History log.", added,
        added == 1 and "event" or "events", added == 1 and "is" or "are")
    GT:Rescan()
end

-- With a guildId: true once that guild's reader has replayed its backlog, so new matches
-- deserve a live alert. Without: true once every reader for the category is live.
-- A module with its own reader passes its reader name.
function History:IsCaughtUp(category, guildId, reader)
    local stream = StreamKey(reader or MAIN_READER, category)
    if guildId then return self.live[guildId .. ":" .. stream] == true end
    return self.caughtUp[stream] == true
end

function History:StartProcessor(lib, guildId, def)
    local category, stream = def.category, def.stream
    -- nil while LibHistoire has no cache for this guild and category yet (e.g. a guild
    -- you just joined). Try again later instead of leaving the guild without a reader.
    local processor = lib:CreateGuildHistoryProcessor(guildId, category, GT.name)
    if not processor then
        local retryKey = guildId .. ":" .. stream
        self.retries = self.retries or {}
        self.retries[retryKey] = (self.retries[retryKey] or 0) + 1
        if self.retries[retryKey] <= MAX_RETRIES then
            zo_callLater(function() self:StartProcessor(lib, guildId, def) end, RETRY_MS)
        end
        return false
    end

    local cursors = GT.sv.historyCursor
    -- The main reader keeps LibHistoire's key; other readers prefix it with their name.
    local key = processor:GetKey()
    if def.reader ~= MAIN_READER then key = def.reader .. ":" .. key end
    if cursors[key] then
        processor:SetAfterEventId(cursors[key])
    elseif not def.readAll then
        -- A reader with readAll sets no start, so LibHistoire starts at the oldest event it has.
        local lookback = (GT.sv.firstRunLookbackDays or 30) * 86400
        processor:SetAfterEventTime(GetTimeStamp() - lookback)
    end

    local isLive = false
    local subs = self.subscribers[stream]
    -- During the one-time backfill, events up to where this reader had already got are
    -- replayed. Modules that rebuild from the History log skip them; Rescan covers them.
    local oldCursor = self.backfill and def.reader == MAIN_READER and self.oldCursors[key] or nil

    local stats = { guildId = guildId, category = category, reader = def.reader, received = 0, oldest = nil, newest = nil, live = false, started = false }
    self.stats = self.stats or {}
    table.insert(self.stats, stats)

    local function HandleEvent(event)
        local info = CopyEventInfo(event)
        if info.isRedacted then return end   -- redacted events can lack a timestamp
        stats.received = stats.received + 1
        stats.oldest = math.min(stats.oldest or info.timestampS, info.timestampS)
        stats.newest = math.max(stats.newest or info.timestampS, info.timestampS)
        local replayed = oldCursor and info.eventId <= oldCursor
        for _, module in ipairs(subs) do
            if not (replayed and module.rebuildsFromLog) then
                module:OnHistoryEvent(guildId, category, info, isLive)
            end
        end
        if not cursors[key] or info.eventId > cursors[key] then
            cursors[key] = info.eventId
        end
    end

    -- Next events arrive in order; missed events are gaps LibHistoire filled in later.
    processor:SetNextEventCallback(HandleEvent)
    processor:SetMissedEventCallback(HandleEvent)
    processor:SetRegisteredForFutureEventsCallback(function()
        if isLive then return end
        isLive = true
        stats.live = true
        self.live[guildId .. ":" .. stream] = true
        self.pending[stream] = (self.pending[stream] or 1) - 1
        if self.pending[stream] <= 0 then self:FinishStream(stream, category) end
    end)

    stats.started = true
    if processor:Start() then
        self.pending[stream] = (self.pending[stream] or 0) + 1
        table.insert(self.processors, processor)
        return true
    end
    return false
end

function History:Start()
    local lib = LibHistoire   -- required by the manifest (DependsOn LibHistoire>=1112)

    local streams, subscribers = CollectStreams()
    self.subscribers = subscribers
    self.streams = streams
    if #streams == 0 then return end
    self:PrepareBackfill()

    lib:OnReady(function()
        if lib:IsGuildHistorySystemDisabled() then
            GT.Util.Print("Guild history is disabled by the game right now, so history checks are paused.")
            return
        end
        for _, guildId in ipairs(GT.Util.GetGuildIds()) do
            for _, def in ipairs(streams) do
                self:StartProcessor(lib, guildId, def)
            end
        end
        for _, def in ipairs(streams) do
            if (self.pending[def.stream] or 0) == 0 then self:FinishStream(def.stream, def.category) end
        end
        -- All server requests are LibHistoire's job: it requests missing history itself and
        -- delivers new events to our processors as they arrive. A category counts as caught
        -- up only when its readers really are live; there is no timeout.
        -- 1.34.7: the one exception is the hole filler (Core/HoleFill.lua), a fallback that
        -- only fetches windows LibHistoire skipped, and only while LibHistoire is idle.
        GT.HoleFill:Start()
    end)
end

-- /gt status ----------------------------------------------------------------

local CATEGORY_NAME = {}
local function CategoryName(category)
    if not next(CATEGORY_NAME) then
        CATEGORY_NAME[GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM] = "bank items"
        CATEGORY_NAME[GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY] = "bank gold"
        CATEGORY_NAME[GUILD_HISTORY_EVENT_CATEGORY_ROSTER] = "roster"
        CATEGORY_NAME[GUILD_HISTORY_EVENT_CATEGORY_TRADER] = "trader sales"
    end
    return CATEGORY_NAME[category] or tostring(category)
end

function History:PrintStatus()
    local U = GT.Util
    if not self.stats or #self.stats == 0 then
        U.Print("No history readers are running yet. LibHistoire may still be starting; try again in a minute.")
        return
    end
    U.Print("History this session (server requests are handled by LibHistoire; see its status window for download progress):")
    for _, guildId in ipairs(U.GetGuildIds()) do
        local parts = {}
        for _, stats in ipairs(self.stats) do
            if stats.guildId == guildId then
                local range = stats.oldest and string.format(" (%s to %s)", os.date("%m-%d", stats.oldest), os.date("%m-%d %H:%M", stats.newest)) or ""
                local label = CategoryName(stats.category)
                if stats.reader ~= MAIN_READER then label = stats.reader .. " " .. label end
                parts[#parts + 1] = string.format("%s %d%s%s", label, stats.received, range,
                    stats.live and "" or " |cFFC857still loading|r")
            end
        end
        U.Print("%s%s: %s", U.GuildName(guildId), GT:IsAlertGuild(guildId) and "" or " |cFF6B86(alerts off)|r",
            #parts > 0 and table.concat(parts, ", ") or "|cFF6B86no reader (LibHistoire has no cache for this guild)|r")
    end
end
