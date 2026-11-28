-- 1.34.7: a fallback for when LibHistoire leaves a hole in the bank history.
--
-- The Toolset gets all guild history through LibHistoire, as ESOUI asks of guild history
-- addons, and this file does not change that. But LibHistoire 2.8.0 often throws away its
-- saved range at login ("Data was removed from managed range", then "Resetting cache") and
-- starts again from the present. Events between where the Toolset stopped and where the new
-- range starts are then never handed to any addon, which leaves hours or days missing from the
-- History log and from bank alerts.
--
-- So, only when that has happened, this file picks up the slack:
--   1. It looks for holes in the History log: bank item silences far longer than usual for
--      that guild (in the guilds you get alerts from, the last 30 days).
--   2. It waits until LibHistoire has nothing left to download (every category linked and
--      nothing processing), so it never competes with LibHistoire's own requests.
--   3. It asks the game's server for that one time window, one window at a time, a few
--      minutes apart, a few per session.
--   4. It adds only events the History log doesn't already have. They go to the History log
--      and bank alerts but are marked backfilled, so they never trigger auto-demote or a mail.
-- Every hole it checks is recorded in sv.holeLog (/gt holes shows it, with Export / Copy).
-- It starts turned off; "Fill holes LibHistoire leaves" in the History log settings turns it on.

local GT = FurysGuildToolset
local U = GT.Util
local HoleFill = {}
GT.HoleFill = HoleFill

-- The numbers a user can change (History log and export settings). Each has a default, the
-- value used until 1.34.7 made them settings, and limits the slider keeps it within.
HoleFill.SETTINGS = {
    { key = "holeFillStartMinutes", name = "Start looking after login (minutes)", default = 2, min = 1, max = 30,
      tooltip = "How long after login the Toolset waits before it first looks for holes. A longer wait leaves LibHistoire more time to catch up by itself. A change counts from your next login or /reloadui." },
    { key = "holeFillMinGapHours", name = "Shortest silence that counts as a hole (hours)", default = 12, min = 4, max = 72,
      tooltip = "A stretch with no bank item events is only treated as a hole when it lasts at least this long, and is also far longer than usual for that guild (long enough to hold about 60 of its usual events). Lower finds shorter holes but also asks the server about quiet nights. Higher asks less." },
    { key = "holeFillLookBackDays", name = "Look for holes in the last (days)", default = 30, min = 7, max = 90,
      tooltip = "How far back in the History log the Toolset looks for holes. The server may no longer have events that are very old, so a hole from long ago can come back empty." },
    { key = "holeFillPauseMinutes", name = "Wait between two requests (minutes)", default = 4, min = 2, max = 30,
      tooltip = "After one hole has been asked for, the Toolset waits this long before it asks for the next one. Longer is gentler on the server, shorter fills several holes sooner." },
    { key = "holeFillMaxPerSession", name = "Most holes asked for per session", default = 6, min = 1, max = 20,
      tooltip = "The Toolset stops asking after this many holes until your next login or /reloadui. Holes it didn't get to are tried next time." },
    { key = "holeFillStuckMinutes", name = "Treat LibHistoire as stuck after (minutes)", default = 15, min = 5, max = 60,
      tooltip = "The Toolset only asks while LibHistoire has nothing left to download. If a category stays unlinked with no change for this long, LibHistoire is stuck rather than busy, and the Toolset goes ahead. Shorter fills holes sooner, longer gives LibHistoire more time." },
}
local SETTING = {}
for _, def in ipairs(HoleFill.SETTINGS) do SETTING[def.key] = def end

-- The saved value, kept within its limits (a hand-edited saved file can't make it ask faster).
local function Setting(key)
    local def = SETTING[key]
    local value = tonumber(GT.sv[key]) or def.default
    return zo_clamp(value, def.min, def.max)
end
HoleFill.Setting = Setting

local MIN_EVENTS = 60            -- fewer bank item events than this in the look-back time: too quiet to judge
local MIN_EXPECTED = 60          -- a hole is a silence long enough to hold this many usual events
local CHECK_MS = 60 * 1000       -- how often to look whether LibHistoire is idle
local POLL_MS = 5 * 1000         -- how often to look whether the server has answered
local MAX_SENDS = 12             -- "more events" asks per window before giving up for this session
local SEND_EVERY_POLLS = 6       -- ask again every 30 seconds while the window isn't complete
local MAX_ATTEMPTS = 3           -- sessions a window is tried in before it is given up
local LOG_KEEP_DAYS = 120
local CATEGORIES = { GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM }

local CATEGORY_NAME = {}
local function CategoryName(category)
    if not next(CATEGORY_NAME) then
        CATEGORY_NAME[GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM] = "bank items"
        CATEGORY_NAME[GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY] = "bank gold"
        CATEGORY_NAME[GUILD_HISTORY_EVENT_CATEGORY_ROSTER] = "roster"
        CATEGORY_NAME[GUILD_HISTORY_EVENT_CATEGORY_TRADER] = "trader"
    end
    return CATEGORY_NAME[category] or tostring(category)
end

local function IsItemType(t) return t == "item_in" or t == "item_out" end

local function WindowKey(guildId, category, fromTs, toTs)
    return string.format("%d:%d:%d:%d", guildId, category, fromTs, toTs)
end

function HoleFill:Initialize()
    local sv = GT.sv
    -- sv.holeLog: list of { g, cat, from, to, found, expected, status, added, tries, checked }
    local cutoff = GetTimeStamp() - LOG_KEEP_DAYS * 86400
    local kept = {}
    for _, h in ipairs(sv.holeLog) do
        if (h.found or 0) >= cutoff then kept[#kept + 1] = h end
    end
    sv.holeLog = kept
    for _, h in ipairs(kept) do
        if h.status == "asking" then h.status = "timeout" end   -- the game closed while it was being fetched
        -- Holes checked by an early 1.34.7 test build didn't record how many events the game
        -- had, so "nothing missing" and "server sent nothing" can't be told apart: check once more.
        if h.status == "empty" and h.inGame == nil and (h.tries or 0) < MAX_ATTEMPTS then h.status = "found" end
    end
    self.sentThisSession = 0
    self.triedThisSession = {}
end

function HoleFill:IsOn()
    return GT.sv.holeFill == true
end

function HoleFill:FindRecord(guildId, category, fromTs, toTs)
    local key = WindowKey(guildId, category, fromTs, toTs)
    for _, h in ipairs(GT.sv.holeLog) do
        if WindowKey(h.g, h.cat, h.from, h.to) == key then return h end
    end
end

-- Silences in the History log that are far longer than usual for that guild. The window runs
-- from the last event before the silence to the first event after it.
function HoleFill:FindHoles()
    local log = GT:GetModule("log")
    if not log or not log.sv or not log.sv.enabled or not log.entries then return {} end
    local now = GetTimeStamp()
    local since = now - Setting("holeFillLookBackDays") * 86400
    local byGuild = {}
    for _, e in ipairs(log.entries) do
        if e.ts >= since and IsItemType(e.t) and GT:IsAlertGuild(e.g) then
            byGuild[e.g] = byGuild[e.g] or {}
            table.insert(byGuild[e.g], e.ts)
        end
    end
    local holes = {}
    for guildId, times in pairs(byGuild) do
        if #times >= MIN_EVENTS then
            table.sort(times)
            local usualGap = (times[#times] - times[1]) / (#times - 1)
            local minGap = math.max(Setting("holeFillMinGapHours") * 3600, usualGap * MIN_EXPECTED)
            for i = 1, #times - 1 do
                local fromTs, toTs = times[i], times[i + 1]
                if toTs - fromTs >= minGap then
                    holes[#holes + 1] = { g = guildId, cat = GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM, from = fromTs, to = toTs,
                        expected = math.floor((toTs - fromTs) / usualGap) }
                end
            end
        end
    end
    table.sort(holes, function(a, b) return a.to > b.to end)   -- newest first
    return holes
end

local WATCHED = { GUILD_HISTORY_EVENT_CATEGORY_ROSTER, GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM,
    GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY, GUILD_HISTORY_EVENT_CATEGORY_TRADER }

-- True while LibHistoire has nothing to download or process for any of your guilds, or when
-- what is left is stuck rather than busy.
--
-- 1.34.7: each busy category is tracked on its own. A category counts as finished only once it
-- has stayed off the busy list for BUSY_GRACE_MS (a stuck category can flip between
-- "processing" and "unlinked" every minute, which used to restart the stuck timer for ever).
-- LibHistoire is stuck when every busy category has been busy for the "stuck after" time and no
-- category has finished in that time either. While it is relinking (one category finishing
-- every few minutes) it is busy, and the Toolset waits.
local BUSY_GRACE_MS = 5 * 60 * 1000

function HoleFill:IsLibHistoireIdle()
    local lib = LibHistoire
    local now = GetGameTimeMilliseconds()
    self.busySince = self.busySince or {}
    self.busyLastSeen = self.busyLastSeen or {}
    self.lastProgress = self.lastProgress or now
    for _, guildId in ipairs(U.GetGuildIds()) do
        for _, category in ipairs(WATCHED) do
            if lib:IsCategoryAutoRequesting(guildId, category)
                and (lib:IsCategoryProcessing(guildId, category) or lib:IsCategoryLinked(guildId, category) == false) then
                local key = guildId .. ":" .. category
                self.busySince[key] = self.busySince[key] or now
                self.busyLastSeen[key] = now
            end
        end
    end
    local stuckMs = Setting("holeFillStuckMinutes") * 60 * 1000
    local busy, allStuck, names = 0, true, {}
    for key, seen in pairs(self.busyLastSeen) do
        if now - seen >= BUSY_GRACE_MS then
            self.busyLastSeen[key] = nil
            self.busySince[key] = nil
            self.lastProgress = now
        else
            busy = busy + 1
            if now - self.busySince[key] < stuckMs then allStuck = false end
            local guildId, category = key:match("^(%d+):(%d+)$")
            names[#names + 1] = U.GuildName(tonumber(guildId)) .. " " .. CategoryName(tonumber(category))
        end
    end
    table.sort(names)
    self.libBusyCount = busy
    self.libBusyNames = table.concat(names, ", ")
    if busy == 0 then return true end
    return allStuck and now - self.lastProgress >= stuckMs
end

function HoleFill:Start()
    if not self:IsOn() or self.started then return end
    self.started = true
    self:Later(Setting("holeFillStartMinutes") * 60 * 1000)
end

-- Every next step goes through here, so /gt holes can say exactly when it comes.
function HoleFill:Later(ms)
    self.nextCheckAt = GetGameTimeMilliseconds() + ms
    zo_callLater(function() self:Check() end, ms)
end

-- 1.34.7: if the next step is long overdue (something broke the chain), start it again.
-- Called from /gt holes. Returns true when it had to.
function HoleFill:Revive()
    if not self:IsOn() or not self.started or self.stopped then return false end
    local now = GetGameTimeMilliseconds()
    if self.busy then
        -- A fetch gives up by itself after MAX_SENDS asks; far past that, it is lost.
        if now - (self.fetchStartedAt or now) < (MAX_SENDS * SEND_EVERY_POLLS * POLL_MS) + 120 * 1000 then return false end
        self.busy = false
        if self.fetching then self.fetching.status = "timeout" end
    elseif self.nextCheckAt and now < self.nextCheckAt + 30 * 1000 then
        return false
    end
    self:Later(1000)
    return true
end

local function Countdown(ms)
    local seconds = math.max(0, math.ceil(ms / 1000))
    if seconds >= 60 then return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60) end
    return string.format("%ds", seconds)
end

-- One step: find the next hole worth asking about and ask, if LibHistoire is idle.
function HoleFill:Check()
    if not self:IsOn() or self.busy then return end
    self.checked = true
    self.nextCheckAt = nil
    self.stopped = false
    if self.sentThisSession >= Setting("holeFillMaxPerSession") then
        self.waiting = "done for this session (most holes per session reached)"
        self.stopped = true
        return
    end
    local holes = self:RecordHoles()
    if not self:IsLibHistoireIdle() then
        self.waiting = string.format("waiting for LibHistoire to finish downloading (%d %s busy: %s). If nothing changes for %d minutes, it counts as stuck and the Toolset goes ahead",
            self.libBusyCount or 0, self.libBusyCount == 1 and "category" or "categories", self.libBusyNames or "", Setting("holeFillStuckMinutes"))
        return self:Later(CHECK_MS)
    end
    -- 1.34.7: only that guild's reader has to be caught up. Waiting for every guild let one
    -- guild LibHistoire is stuck on block holes in all the others.
    local waitingForReader = false
    for _, hole in ipairs(holes) do
        local record = hole.record
        -- A window the server didn't answer is tried again next session, not straight away.
        if (record.status == "found" or record.status == "timeout") and record.tries < MAX_ATTEMPTS and not self.triedThisSession[record] then
            if GT.History:IsCaughtUp(hole.cat, hole.g) then
                self.waiting = nil
                self.triedThisSession[record] = true
                self:Fetch(record)
                return
            end
            waitingForReader = true
        end
    end
    if waitingForReader then
        self.waiting = "waiting for the Toolset to finish reading that guild's history"
        return self:Later(CHECK_MS)
    end
    self.waiting = "nothing left to fetch"
    self.stopped = true
end

-- Puts every hole found now in the hole log (status "found" until it is fetched) and returns
-- the holes, each with its record.
function HoleFill:RecordHoles()
    local holes = self:FindHoles()
    for _, hole in ipairs(holes) do
        local record = self:FindRecord(hole.g, hole.cat, hole.from, hole.to)
        if not record then
            record = { g = hole.g, cat = hole.cat, from = hole.from, to = hole.to, found = GetTimeStamp(),
                expected = hole.expected, status = "found", added = 0, tries = 0 }
            table.insert(GT.sv.holeLog, record)
        end
        hole.record = record
        record.current = true
    end
    -- A hole found earlier that isn't a hole any more (LibHistoire or a fetch delivered events
    -- into it, or it is now older than the look-back time) is marked, so it isn't left as
    -- "not fetched yet" for ever.
    for _, record in ipairs(GT.sv.holeLog) do
        if record.status == "found" and not record.current then record.status = "gone" end
        record.current = nil
    end
    return holes
end

-- One line on what the hole filler is doing right now, for /gt holes.
function HoleFill:StateText()
    if not self:IsOn() then return "Fill holes LibHistoire leaves is turned off (/gtsettings > History log and export)." end
    if self.busy then return "Fetching a hole from the server now." end
    if not self.checked then
        return string.format("It starts looking %d %s after login.", Setting("holeFillStartMinutes"),
            Setting("holeFillStartMinutes") == 1 and "minute" or "minutes")
    end
    local text = self.waiting or "waiting before the next request"
    if self.nextCheckAt then
        text = text .. ". Next check in " .. Countdown(self.nextCheckAt - GetGameTimeMilliseconds())
    end
    return "Right now: " .. text .. "."
end

-- Asks the server for one window and waits for the answer.
function HoleFill:Fetch(record)
    self.busy = true
    self.fetching = record
    self.fetchStartedAt = GetGameTimeMilliseconds()
    self.sentThisSession = self.sentThisSession + 1
    record.tries = record.tries + 1
    record.status = "asking"
    local request = ZO_GuildHistoryRequest:New(record.g, record.cat, record.to, record.from)
    local polls, sends = 0, 1
    request:RequestMoreEvents()

    local function Poll()
        polls = polls + 1
        if request:IsComplete() then
            self:Finish(record, request, "done")
            return
        end
        if not request:IsValid() then
            self:Finish(record, request, "timeout")
            return
        end
        if polls % SEND_EVERY_POLLS == 0 then
            if sends >= MAX_SENDS then
                self:Finish(record, request, "timeout")
                return
            end
            sends = sends + 1
            request:RequestMoreEvents()
        end
        zo_callLater(Poll, POLL_MS)
    end
    zo_callLater(Poll, POLL_MS)
end

function HoleFill:Finish(record, request, outcome)
    DestroyGuildHistoryRequest(request:GetRequestId())
    local added = 0
    if outcome == "done" then
        added = self:AddWindow(record)
        record.added = (record.added or 0) + added
        record.status = record.added > 0 and "filled" or "empty"
        record.checked = GetTimeStamp()
    else
        record.status = "timeout"
    end
    self.busy = false
    self.fetching = nil
    self.waiting = "waiting between two requests"
    -- The next step is scheduled before anything else, so nothing below can stop the chain.
    self:Later(Setting("holeFillPauseMinutes") * 60 * 1000)
    if added > 0 then
        U.Print("LibHistoire had left a hole in %s %s (%s to %s). The Toolset fetched it and added %d %s to the History log. Bank alerts were checked; nothing automatic (demote, mail) runs for them. /gt holes lists every hole found.",
            U.GuildName(record.g), CategoryName(record.cat), U.FormatDate(record.from), U.FormatDate(record.to), added, added == 1 and "event" or "events")
        GT.Report:RefreshIfShown()
    end
end

-- Reads the window from the game's history and hands every event the History log doesn't
-- have yet to the modules, marked backfilled. Returns how many were new.
function HoleFill:AddWindow(record)
    local guildData = GUILD_HISTORY_MANAGER:GetGuildData(record.g)
    if not guildData then return 0 end
    local categoryData = guildData:GetEventCategoryData(record.cat)
    if not categoryData then return 0 end
    local events = categoryData:GetEventsInTimeRange(record.to, record.from) or {}
    record.inGame = #events   -- how many events the game had for the window, new or not
    local infos = {}
    for _, event in ipairs(events) do
        infos[#infos + 1] = GT.History.CopyEventInfo(event)   -- plain copies; the event objects are not kept
    end
    table.sort(infos, function(a, b) return a.eventId < b.eventId end)
    local log = GT:GetModule("log")
    local added = 0
    for _, info in ipairs(infos) do
        if not info.isRedacted and not log:HasEvent(record.g, record.cat, info.eventId) then
            info.backfilled = true
            GT.History:DeliverBackfilled(record.g, record.cat, info)
            added = added + 1
        end
    end
    return added
end

-- /gt holes ---------------------------------------------------------------------

local STATUS_TEXT = {
    found = "found, not fetched yet",
    asking = "being fetched",
    timeout = "server didn't answer, will retry",
    filled = "filled",
    empty = "checked, nothing was missing",
    gone = "not a hole any more (events arrived, or older than the look-back time)",
}

function HoleFill:ShowLog()
    -- 1.34.7: holes are listed as soon as they are found, not only once a fetch has started.
    if self:IsOn() then self:RecordHoles() end
    if self:Revive() then U.Print("The hole filler had stopped moving; it starts again in a second.") end
    local holes = GT.sv.holeLog or {}
    if #holes == 0 then
        U.Print("No holes in the bank history found (guilds you get alerts from, last %d days). %s", Setting("holeFillLookBackDays"), self:StateText())
        return
    end
    local rows = { { "Found", "Guild", "History", "Hole from", "Hole to", "Hours", "Events the game had", "Events added", "Tries", "Status" } }
    local filled, events, quiet, waiting, failed = 0, 0, 0, 0, 0
    for i = #holes, 1, -1 do
        local h = holes[i]
        rows[#rows + 1] = { U.FormatDate(h.found), U.GuildName(h.g), CategoryName(h.cat), U.FormatDate(h.from), U.FormatDate(h.to),
            string.format("%.1f", (h.to - h.from) / 3600), h.inGame and tostring(h.inGame) or "", tostring(h.added or 0),
            tostring(h.tries or 0), (h.status == "empty" and h.inGame == 0) and "server sent nothing for that time" or STATUS_TEXT[h.status] or h.status }
        if h.status == "filled" then
            filled = filled + 1
            events = events + (h.added or 0)
        elseif h.status == "empty" or h.status == "gone" then
            quiet = quiet + 1
        elseif (h.tries or 0) >= MAX_ATTEMPTS then
            failed = failed + 1
        else
            waiting = waiting + 1
        end
    end
    U.Print("%d %s found: %d filled with %d missing %s, %d checked and nothing was missing, %d not fetched yet, %d given up (server never answered). %s The full list is in the copy window.",
        #holes, #holes == 1 and "hole" or "holes", filled, events, events == 1 and "event" or "events", quiet, waiting, failed, self:StateText())
    GT.Report:ShowExport(rows)
    GT.Report.exportTitle = "Holes LibHistoire left"
    GT.Report:ShowExportPart(0)
end
