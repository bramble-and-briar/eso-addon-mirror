-- Hopper Watch: reports people who join a guild and leave again within X hours (usually
-- looking for an open bank), lets you blacklist them, and keeps an account-wide watchlist
-- that warns you when a known hopper joins any of your other guilds.

local GT = FuryGMT
local U = GT.Util
local A = GT.Actions

local HopperWatch = GT:RegisterModule("hoppers", {})
HopperWatch.rebuildsFromLog = true   -- Rescan rebuilds it from the History log (see History:PrepareBackfill)

local KEEP_JOINS_SECONDS = 30 * 86400
local KEEP_RECORDS_SECONDS = 60 * 86400

HopperWatch.defaults = {
    enabled = false,   -- every feature starts off on a new install (Albert, 1.3.0)
    maxHours = 48,
    countKicks = false,
    autoWatchlist = false,
    alertOnWatchlistJoin = false,
    openWindowOnLogin = false,
    blacklistNote = "Bank hopper: joined and left within <<1>>",
    joins = {},        -- [guildId][displayName] = join timestamp
    records = {},      -- list of { id, guildId, guildName, name, joinTs, leaveTs, kicked, status }
    watchlist = {},    -- [lowercase displayName] = { name, reason, ts }
}

-- Settings each guild has its own copy of (see GT:GuildSettings).
HopperWatch.guildKeys = { "maxHours", "countKicks", "autoWatchlist", "alertOnWatchlistJoin", "blacklistNote" }

function HopperWatch:G(guildId)
    return GT:GuildSettings(self, guildId)
end

function HopperWatch:Initialize(sv)
    self.sv = sv
    sv.autoBlacklist = nil -- v0.2.3: removed, report only
    self.sessionStart = GetTimeStamp()
    self.returnedWhileAway = {}
    self:Prune()
    self:RegisterTabs()

    self:UpdateEventRegistration()
end

-- The watchlist join alert only listens while the hopper report is turned on.
function HopperWatch:UpdateEventRegistration()
    if self.sv.enabled then
        EVENT_MANAGER:RegisterForEvent("FuryGMTHopper", EVENT_GUILD_MEMBER_ADDED, function(_, guildId, displayName)
            self:OnMemberAdded(guildId, displayName)
        end)
    else
        EVENT_MANAGER:UnregisterForEvent("FuryGMTHopper", EVENT_GUILD_MEMBER_ADDED)
    end
end

function HopperWatch:GetHistoryCategories()
    if not self.sv.enabled then return {} end
    return { GUILD_HISTORY_EVENT_CATEGORY_ROSTER }
end

function HopperWatch:Prune()
    local now = GetTimeStamp()
    local maxHours = GT:MaxGuildSetting(self, "maxHours")
    for _, members in pairs(self.sv.joins) do
        for name, ts in pairs(members) do
            -- A join only matters until the "leave within" limit has passed.
            if now - ts > math.min(KEEP_JOINS_SECONDS, maxHours * 3600 + 86400) then members[name] = nil end
        end
    end
    for i = #self.sv.records, 1, -1 do
        if now - self.sv.records[i].leaveTs > KEEP_RECORDS_SECONDS then table.remove(self.sv.records, i) end
    end
end

-- Watchlist ------------------------------------------------------------------

function HopperWatch:GetWatch(name)
    return self.sv.watchlist[zo_strlower(name)]
end

function HopperWatch:AddWatch(name, reason)
    self.sv.watchlist[zo_strlower(name)] = { name = name, reason = reason, ts = GetTimeStamp() }
    GT.Report:RefreshIfShown()
end

function HopperWatch:RemoveWatch(name)
    self.sv.watchlist[zo_strlower(name)] = nil
    GT.Report:RefreshIfShown()
end

function HopperWatch:OnMemberAdded(guildId, displayName)
    if not GT:IsAlertGuild(guildId) or not self:G(guildId).alertOnWatchlistJoin then return end
    local watch = self:GetWatch(displayName)
    if watch then
        U.Alert(zo_strformat("Watchlist: <<1>> just joined <<2>>. Note: <<3>>", displayName, U.GuildName(guildId), watch.reason))
    end
end

-- History -------------------------------------------------------------------

function HopperWatch:RecordJoin(guildId, name, ts, isLive)
    local joins = self.sv.joins
    joins[guildId] = joins[guildId] or {}
    if (joins[guildId][name] or 0) < ts then joins[guildId][name] = ts end
    -- Live joins are announced by EVENT_GUILD_MEMBER_ADDED; collect the ones we missed while offline.
    if not isLive and not GT.History:IsCaughtUp(GUILD_HISTORY_EVENT_CATEGORY_ROSTER, guildId) and self:GetWatch(name) then
        self.returnedWhileAway[#self.returnedWhileAway + 1] = { guildId = guildId, name = name }
    end
end

function HopperWatch:RecordLeave(guildId, name, ts, eventId, kicked)
    local joins = self.sv.joins[guildId]
    local joinTs = joins and joins[name]
    if joins then joins[name] = nil end
    if not joinTs or ts < joinTs then return end
    local g = self:G(guildId)
    if kicked and not g.countKicks then return end
    if ts - joinTs > g.maxHours * 3600 then return end

    local id = tostring(guildId) .. ":" .. tostring(eventId)
    for _, record in ipairs(self.sv.records) do
        if record.id == id then return end
    end
    local record = {
        id = id, guildId = guildId, guildName = U.GuildName(guildId), name = name,
        joinTs = joinTs, leaveTs = ts, kicked = kicked, status = "open", createdAt = GetTimeStamp(),
    }
    table.insert(self.sv.records, record)

    local stay = U.FormatDuration(ts - joinTs)
    local live = GT.History:IsCaughtUp(GUILD_HISTORY_EVENT_CATEGORY_ROSTER, guildId) and not self.rebuilding
    if live then
        U.Alert(zo_strformat("Hopper: <<1>> left <<2>> <<3>> after joining.", name, record.guildName, stay))
    end
    if g.autoWatchlist and not self:GetWatch(name) then
        local reason = zo_strformat("left <<1>> after <<2>> (<<3>>)", record.guildName, stay, os.date("%Y-%m-%d", ts))
        self:AddWatch(name, reason)
        GT.AutoLog:RecordWatchlist(guildId, name, zo_strformat("joined <<1>>, left <<2>> later on <<3>> (limit <<4>>h)",
            U.FormatDate(joinTs), stay, U.FormatDate(ts), g.maxHours), live)
    end
    GT.Report:RefreshIfShown()
end

function HopperWatch:OnHistoryEvent(guildId, category, info, isLive)
    if not self.sv.enabled or not GT:IsAlertGuild(guildId) then return end
    local t = info.eventType
    if t == GUILD_HISTORY_ROSTER_EVENT_JOIN then
        self:RecordJoin(guildId, info.actingDisplayName, info.timestampS, isLive)
    elseif t == GUILD_HISTORY_ROSTER_EVENT_APPLICATION_ACCEPTED then
        self:RecordJoin(guildId, info.targetDisplayName, info.timestampS, isLive)
    elseif t == GUILD_HISTORY_ROSTER_EVENT_LEAVE then
        self:RecordLeave(guildId, info.actingDisplayName, info.timestampS, info.eventId, false)
    elseif t == GUILD_HISTORY_ROSTER_EVENT_KICKED then
        self:RecordLeave(guildId, info.targetDisplayName, info.timestampS, info.eventId, true)
    end
end

function HopperWatch:OnHistoryCaughtUp()
    local fresh = 0
    for _, record in ipairs(self.sv.records) do
        if record.status == "open" and record.createdAt >= self.sessionStart and GT:IsAlertGuild(record.guildId) then fresh = fresh + 1 end
    end
    if fresh > 0 then
        U.Alert(zo_strformat("<<1>> <<1[person/people]>> joined and left again quickly since your last login. /gt hoppers", fresh))
        if self.sv.openWindowOnLogin and FuryGMTReport:IsHidden() then GT.Report:Show("hoppers") end
    end
    for _, seen in ipairs(self.returnedWhileAway) do
        if U.IsMember(seen.guildId, seen.name) and GT:IsAlertGuild(seen.guildId) then
            U.Alert(zo_strformat("Watchlist: <<1>> joined <<2>> while you were offline.", seen.name, U.GuildName(seen.guildId)))
        end
    end
    self.returnedWhileAway = {}
end

-- Recomputes the hopper report from the History log (used by /gt reset).
function HopperWatch:RebuildFromLog(entries)
    local list = {}
    for _, e in ipairs(entries) do
        if e.t == "join" or e.t == "app_ok" or e.t == "leave" or e.t == "kick" then list[#list + 1] = e end
    end
    table.sort(list, function(a, b) if a.ts ~= b.ts then return a.ts < b.ts end return a.id < b.id end)
    self.sv.records, self.sv.joins = {}, {}
    self.rebuilding = true
    for _, e in ipairs(list) do
        if self.sv.enabled and GT:IsAlertGuild(e.g) then
            if e.t == "join" then self:RecordJoin(e.g, e.who, e.ts, true)
            elseif e.t == "app_ok" then self:RecordJoin(e.g, e.target, e.ts, true)
            elseif e.t == "leave" then self:RecordLeave(e.g, e.who, e.ts, e.id, false)
            elseif e.t == "kick" then self:RecordLeave(e.g, e.target, e.ts, e.id, true) end
        end
    end
    self.rebuilding = false
    return self:CountOpen()
end

-- Blacklist helpers ----------------------------------------------------------

function HopperWatch:BlacklistNote(record)
    return zo_strformat(self:G(record.guildId).blacklistNote, U.FormatDuration(record.leaveTs - record.joinTs))
end

function HopperWatch:IsOnGuildBlacklist(guildId, name)
    local lower = zo_strlower(name)
    for i = 1, GetNumGuildBlacklistEntries(guildId) do
        local accountName = GetGuildBlacklistInfoAt(guildId, i)
        if accountName and zo_strlower(accountName) == lower then return true end
    end
    return false
end

function HopperWatch:MarkBlacklisted(record)
    record.status = "blacklisted"
    GT.Report:RefreshIfShown()
end

-- Used by "Blacklist all new" (confirmed once for the whole list). Mails each person
-- the reason when that guild's blacklist mail is on.
function HopperWatch:BlacklistRecord(record)
    if A.BlacklistAndMail(record.guildId, record.name, self:BlacklistNote(record)) then self:MarkBlacklisted(record) end
end

-- Report tabs ---------------------------------------------------------------

function HopperWatch:CountOpen()
    local n = 0
    for _, record in ipairs(self.sv.records) do
        if record.status == "open" and GT:IsAlertGuild(record.guildId) then n = n + 1 end
    end
    return n
end

function HopperWatch:GetRecordRow(record)
    local stay = U.FormatDuration(record.leaveTs - record.joinTs)
    local inGuild = U.IsPlayerInGuild(record.guildId)
    if record.status == "open" and inGuild and self:IsOnGuildBlacklist(record.guildId, record.name) then
        record.status = "blacklisted"
    end
    local text = zo_strformat("<<1>> <<2>> <<3>> after <<4>>, <<5>>", record.name,
        record.kicked and "was kicked from" or "left", record.guildName, stay, U.FormatAgo(record.leaveTs))
    if record.status == "blacklisted" then text = text .. "  |c9FD49Fblacklisted|r" end
    if record.status == "dismissed" then text = text .. "  |c888888dismissed|r" end

    local actions = {}
    if record.status ~= "blacklisted" and inGuild then
        actions[#actions + 1] = { label = "Blacklist (asks first)", tip = "Adds them to that guild's blacklist. Asks first, and can mail them the reason.", fn = function()
            A.ConfirmBlacklist(record.guildId, record.name, self:BlacklistNote(record), function() self:MarkBlacklisted(record) end)
        end }
    end
    if self:GetWatch(record.name) then
        actions[#actions + 1] = { label = "Unwatch", tip = "Takes them off your watchlist.", fn = function() self:RemoveWatch(record.name) end }
    else
        actions[#actions + 1] = { label = "Watch", tip = "Adds them to your watchlist, so you get an alert if they join any of your guilds.", fn = function()
            self:AddWatch(record.name, zo_strformat("left <<1>> after <<2>>", record.guildName, stay))
        end }
    end
    if record.status == "open" then
        actions[#actions + 1] = { label = "Dismiss", tip = "Hides this entry.", fn = function()
            record.status = "dismissed"
            GT.Report:RefreshIfShown()
        end }
    end
    for _, item in ipairs(GT.Report.ContactItems(record.name)) do actions[#actions + 1] = item end
    return GT.Report.AddMenu({
        text = text,
        tooltip = string.format("%s\nJoined %s\nLeft %s", record.name, U.FormatDate(record.joinTs), U.FormatDate(record.leaveTs)),
    }, actions)
end

function HopperWatch:GetVisibleRecords()
    local list = {}
    for _, record in ipairs(self.sv.records) do
        if GT:IsAlertGuild(record.guildId) then list[#list + 1] = record end
    end
    table.sort(list, function(a, b) return a.leaveTs > b.leaveTs end)
    return list
end

function HopperWatch:GetSortedWatchlist()
    local list = {}
    for _, entry in pairs(self.sv.watchlist) do list[#list + 1] = entry end
    table.sort(list, function(a, b) return a.ts > b.ts end)
    return list
end

function HopperWatch:HoppersTabRows()
    local rows = {}
    for _, record in ipairs(self:GetVisibleRecords()) do rows[#rows + 1] = self:GetRecordRow(record) end
    return rows
end

function HopperWatch:HoppersTabExportLines()
    local lines = { "Guild\tMember\tJoined\tLeft\tHours in guild\tHow\tStatus" }
    for _, r in ipairs(self:GetVisibleRecords()) do
        lines[#lines + 1] = table.concat({ r.guildName, r.name, U.FormatDate(r.joinTs), U.FormatDate(r.leaveTs),
            string.format("%.1f", (r.leaveTs - r.joinTs) / 3600), r.kicked and "kicked" or "left", r.status }, "\t")
    end
    return lines
end

function HopperWatch:WatchlistTabExportLines()
    local lines = { "Member\tReason\tAdded" }
    for _, entry in ipairs(self:GetSortedWatchlist()) do
        lines[#lines + 1] = table.concat({ entry.name, ((entry.reason or ""):gsub("[\t\n]", " ")), U.FormatDate(entry.ts) }, "\t")
    end
    return lines
end

function HopperWatch:WatchlistTabRows()
    local rows = {}
    for _, entry in ipairs(self:GetSortedWatchlist()) do
        local actions = {}
        for _, guildId in ipairs(U.GetGuildIds()) do
            if U.IsMember(guildId, entry.name) then
                local gid = guildId
                actions[#actions + 1] = { label = "Kick and blacklist (asks first)", tip = "Kicks them and adds them to the guild blacklist. Asks first, and can mail them the reason.", fn = function()
                    A.Kick(gid, entry.name, true, "Watchlist: " .. (entry.reason or ""))
                end }
                break
            end
        end
        actions[#actions + 1] = { label = "Remove from watchlist", tip = "Takes them off your watchlist.", fn = function() self:RemoveWatch(entry.name) end }
        for _, item in ipairs(GT.Report.ContactItems(entry.name)) do actions[#actions + 1] = item end
        rows[#rows + 1] = GT.Report.AddMenu({
            text = zo_strformat("<<1>>  |cAAAAAA<<2>>|r", entry.name, entry.reason or ""),
            tooltip = "Added " .. U.FormatDate(entry.ts),
        }, actions)
    end
    return rows
end

function HopperWatch:HoppersTabSummary()
    local parts = {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) then parts[#parts + 1] = string.format("%s %dh", U.GuildName(guildId), self:G(guildId).maxHours) end
    end
    return string.format("People who left soon after joining, last 60 days. Limit: %s.", table.concat(parts, ", "))
end

function HopperWatch:WatchlistTabSummary()
    return "Account-wide. You get an alert when anyone here joins one of your guilds."
end

function HopperWatch:RegisterTabs()
    GT.Report:RegisterTab({
        id = "hoppers",
            GetOffText = function() return GT:FeatureOffText(self.sv.enabled, "The hopper report", true) end,
        tip = "People who joined and left quickly, often to empty the bank.",
        title = function() return string.format("Bank hoppers (%d)", self:CountOpen()) end,
        GetSummary = function() return self:HoppersTabSummary() end,
        GetRows = function() return self:HoppersTabRows() end,
        GetExportLines = function() return self:HoppersTabExportLines() end,
        footer = {
            { label = "Blacklist all new", tip = "Blacklists everyone new on this list. Asks first.", fn = function()
                local targets = {}
                for _, record in ipairs(self.sv.records) do
                    if record.status == "open" and U.IsPlayerInGuild(record.guildId) then targets[#targets + 1] = record end
                end
                if #targets == 0 then return end
                A.Confirm("Blacklist hoppers", zo_strformat("Add <<1>> <<1[person/people]>> to your guild blacklists?", #targets)
                    .. "\n\nIn guilds where Mail members you blacklist is on, each of them is mailed the reason.", function()
                    for _, record in ipairs(targets) do self:BlacklistRecord(record) end
                end)
            end },
            { label = "Clear dismissed", tip = "Deletes the entries you dismissed.", fn = function()
                for i = #self.sv.records, 1, -1 do
                    if self.sv.records[i].status == "dismissed" then table.remove(self.sv.records, i) end
                end
                GT.Report:RefreshIfShown()
            end },
        },
    })

    GT.Report:RegisterTab({
        id = "watchlist",
        tip = "Known hoppers. You get an alert when one joins any of your guilds.",
        title = function() return string.format("Watchlist (%d)", U.Count(self.sv.watchlist)) end,
        GetSummary = function() return self:WatchlistTabSummary() end,
        GetExportLines = function() return self:WatchlistTabExportLines() end,
        GetRows = function() return self:WatchlistTabRows() end,
    })
end

-- Settings ------------------------------------------------------------------

function HopperWatch:BuildSettings(options)
    local sv, defaults = self.sv, self.defaults
    local controls = {
        { type = "checkbox", name = "Enable hopper report", getFunc = function() return sv.enabled end,
          setFunc = function(v) sv.enabled = v; self:UpdateEventRegistration() end, default = defaults.enabled, requiresReload = true },
        { type = "description", text = "How soon a leave counts, kicks, the watchlist and the blacklist note are set for each guild under Rules for (guild) on the Guild rules page. The watchlist itself is shared by all your guilds." },
        GT.Settings:RulesButton("Opens the Guild rules page, where each guild's hopper settings are set: how soon a leave counts, kicks, the watchlist and the blacklist note."),
        { type = "checkbox", name = "Open the report at login when there are new hoppers",
          getFunc = function() return sv.openWindowOnLogin end, setFunc = function(v) sv.openWindowOnLogin = v end,
          default = defaults.openWindowOnLogin },
    }
    options[#options + 1] = { type = "submenu", name = "Bank hoppers and watchlist", controls = controls }
end

-- One guild's hopper settings, inside that guild's Rules submenu.
function HopperWatch:BuildGuildSettings(controls, guildId)
    local defaults = self.defaults
    local g = self:G(guildId)
    local list = {
        { type = "header", name = "Bank hoppers and watchlist" },
        { type = "slider", name = "Flag if they leave within (hours)", min = 1, max = 336, step = 1,
          getFunc = function() return g.maxHours end, setFunc = function(v) g.maxHours = v end, default = defaults.maxHours },
        { type = "checkbox", name = "Also list people who were kicked", getFunc = function() return g.countKicks end,
          setFunc = function(v) g.countKicks = v end, default = defaults.countKicks },
        { type = "checkbox", name = "Add hoppers to the watchlist automatically", getFunc = function() return g.autoWatchlist end,
          setFunc = function(v) g.autoWatchlist = v end, default = defaults.autoWatchlist },
        { type = "editbox", name = "Blacklist note", tooltip = "<<1>> is how long they stayed.",
          getFunc = function() return g.blacklistNote end, setFunc = function(v) g.blacklistNote = v end, default = defaults.blacklistNote },
        { type = "checkbox", name = "Alert when a watchlisted person joins", getFunc = function() return g.alertOnWatchlistJoin end,
          setFunc = function(v) g.alertOnWatchlistJoin = v end, default = defaults.alertOnWatchlistJoin },
    }
    for _, control in ipairs(list) do controls[#controls + 1] = control end
end
