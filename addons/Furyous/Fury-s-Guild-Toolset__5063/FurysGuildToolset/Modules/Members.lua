-- Members: a roster overview (rank, time in guild, time at rank, last online, guild note)
-- and an Inactive tab that flags members who have been offline too long.
--
-- API limits:
--   * The roster only gives "seconds since logoff" (GetGuildMemberInfo). That is when the
--     member last logged off, so "last online" is a date, not an exact login time.
--   * The game does not store when someone got their rank. We take it from roster history
--     (promotions, demotions and joins, through LibHistoire, all of it that LibHistoire has
--     saved, see Members.historyReadAll) and from what the History tab has
--     already logged. For anyone whose last rank change is older than that, the tab shows
--     "before <date>", the oldest roster event we have for that guild.
--   * The game does not store when someone joined either. Time in guild comes from the same
--     roster history (their latest join or accepted application), with the same "before <date>"
--     for anyone who joined before the oldest roster event we have.

local GT = FurysGuildToolset
local U = GT.Util
local A = GT.Actions

local Members = GT:RegisterModule("members", {})
-- Own LibHistoire reader (see Core/History.lua) that reads all the roster history LibHistoire
-- has saved, not just the look-back period, so join and rank dates go back as far as possible.
-- Only the latest join, rank change and promotion of current members are kept (rankInfo).
Members.historyReader = "members"
Members.historyReadAll = true

local DAY = 86400
local RULE_OFFICER, RULE_MEMBER, RULE_RECRUIT, RULE_OFF = "officer", "member", "recruit", "off"
local RULE_LABELS = { [RULE_OFFICER] = "Officer limit", [RULE_MEMBER] = "Member limit", [RULE_RECRUIT] = "Recruit limit", [RULE_OFF] = "Not checked" }
local RULE_BY_LABEL = { ["Officer limit"] = RULE_OFFICER, ["Member limit"] = RULE_MEMBER, ["Recruit limit"] = RULE_RECRUIT, ["Not checked"] = RULE_OFF }
-- Rank colors by rank number (1 = Guild Master). Ranks past the list reuse the last color.
local RANK_COLORS = { "D4AF37", "E06666", "C27BA0", "8E7CC3", "6FA8DC", "76A5AF", "93C47D", "B7B7B7", "999999", "888888" }

Members.defaults = {
    inactiveEnabled = false,   -- every feature starts turned off on a new install (Albert, 1.3.0)
    officerDays = 30,
    memberDays = 21,
    recruitDays = 14,
    alertOnLogin = false,
    -- Contact templates. <<1>> = @name, <<2>> = guild, <<3>> = days offline, <<4>> = their limit in days.
    contactSubject = "<<2>>",
    contactText = "Hi <<1>>, ",
    inactiveSubject = "We miss you in <<2>>",
    inactiveText = "Hi <<1>>, you haven't logged in to <<2>> for <<3>> days, and our limit for your rank is <<4>> days. If you'll be away for a while, let an officer know and we'll hold your spot. Otherwise you may be removed to make room for active players. Hope to see you soon!",
    removeNote = "Removed from the roster",
    -- Mails sent after a confirmed kick from the Inactive tab, or a blacklist (off until turned on).
    -- Kick: <<1>> = @name, <<2>> = guild, <<3>> = days offline, <<4>> = their limit in days.
    -- Blacklist: <<1>> = @name, <<2>> = guild, <<3>> = the reason (the blacklist note).
    kickMail = false,
    kickSubject = "Removed from <<2>> for inactivity",
    kickText = "Hi <<1>>,\n\nYou were removed from <<2>> because you hadn't logged in for <<3>> days, and our limit for your rank is <<4>> days. Nothing personal, we just keep spots open for active players.\n\nIf you come back to the game, you're welcome back! Mail or whisper an officer, or apply to <<2>> again.\n\nHope to see you soon!",
    blacklistMail = false,
    blacklistSubject = "<<2>> guild blacklist",
    blacklistText = "Hi <<1>>,\n\nYou have been added to the <<2>> guild blacklist for this reason:\n\n<<3>>\n\nThis means you can't rejoin or apply to <<2>>.",
    rankRules = {},   -- [guildId] = { [rankIndex] = "officer" | "member" | "recruit" | "off" }; missing = default
    dismissed = {},   -- ["guildId:@name"] = when they had last logged off at the time you dismissed them
    rankInfo = {},    -- [guildId] = { ["@name"] = { joined, changed, promoted } }
    oldest = {},      -- [guildId] = oldest roster event timestamp we have seen
    filter = { guildId = 0, sort = "name", groupRank = true, rank = "", hideOffline = false },                -- Members tab
    inactiveFilter = { sort = "offline", desc = true, groupRank = true, rank = "" },  -- Inactive tab
}

-- Settings each guild has its own copy of (see GT:GuildSettings). Per-rank rules are kept per guild in rankRules.
Members.guildKeys = { "inactiveEnabled", "officerDays", "memberDays", "recruitDays", "contactSubject", "contactText",
    "inactiveSubject", "inactiveText", "removeNote", "kickMail", "kickSubject", "kickText", "blacklistMail",
    "blacklistSubject", "blacklistText" }

function Members:G(guildId)
    return GT:GuildSettings(self, guildId)
end

function Members:Initialize(sv)
    self.sv = sv
    -- Rank dates logged by the History tab before this module existed.
    local log = GT:GetModule("log")
    for _, e in ipairs(log.entries) do
        if e.t == "join" then self:Apply(e.g, "join", e.who, e.ts)
        elseif e.t == "app_ok" then self:Apply(e.g, "join", e.target, e.ts)
        elseif e.t == "promote" or e.t == "demote" then self:Apply(e.g, e.t, e.target, e.ts)
        end
    end
    -- 1.26.4: the Last promoted column is gone (Time at rank shows the same); its sort falls back.
    if self.sv.filter.sort == "promoted" then self.sv.filter.sort = "atrank" end
    self:RegisterTabs()
    -- Kicking (or Set rank) only asks the server; the roster changes a moment later.
    -- Redraw when it does, so kicked members drop off Members and Inactive right away
    -- and the counts and open slots stay right. Joins and leaves by anyone else count too.
    local function RosterChanged() GT.Report:RefreshIfShown() end
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Members", EVENT_GUILD_MEMBER_REMOVED, RosterChanged)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Members", EVENT_GUILD_MEMBER_ADDED, RosterChanged)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Members", EVENT_GUILD_MEMBER_RANK_CHANGED, RosterChanged)
end

function Members:GetHistoryCategories()
    return { GUILD_HISTORY_EVENT_CATEGORY_ROSTER }
end

function Members:OnHistoryEvent(guildId, category, info, isLive)
    local t = info.eventType
    if t == GUILD_HISTORY_ROSTER_EVENT_JOIN then
        self:Apply(guildId, "join", info.actingDisplayName, info.timestampS)
    elseif t == GUILD_HISTORY_ROSTER_EVENT_APPLICATION_ACCEPTED then
        self:Apply(guildId, "join", info.targetDisplayName, info.timestampS)
    elseif t == GUILD_HISTORY_ROSTER_EVENT_PROMOTE then
        self:Apply(guildId, "promote", info.targetDisplayName, info.timestampS)
    elseif t == GUILD_HISTORY_ROSTER_EVENT_DEMOTE then
        self:Apply(guildId, "demote", info.targetDisplayName, info.timestampS)
    elseif t == GUILD_HISTORY_ROSTER_EVENT_LEAVE then
        self:Apply(guildId, "leave", info.actingDisplayName, info.timestampS)
    elseif t == GUILD_HISTORY_ROSTER_EVENT_KICKED then
        self:Apply(guildId, "leave", info.targetDisplayName, info.timestampS)
    else
        return
    end
    -- While the backlog is read (thousands of events the first time), redraw once at the end instead.
    if isLive then GT.Report:RefreshIfShown() end
end

function Members:OnHistoryCaughtUp()
    GT.Report:RefreshIfShown()
end

-- Events can arrive out of order (backlog, filled gaps), so keep the newest time of each kind.
function Members:Apply(guildId, kind, name, ts)
    if not name or name == "" or not ts then return end
    if not self.sv.oldest[guildId] or ts < self.sv.oldest[guildId] then self.sv.oldest[guildId] = ts end
    self.sv.rankInfo[guildId] = self.sv.rankInfo[guildId] or {}
    local members = self.sv.rankInfo[guildId]
    local rec = members[name]
    if kind == "leave" then
        if rec and ts >= (rec.changed or 0) then members[name] = nil end
        return
    end
    rec = rec or {}
    members[name] = rec
    if kind == "join" and ts > (rec.joined or 0) then rec.joined = ts end
    if ts > (rec.changed or 0) then rec.changed = ts end
    if kind == "promote" and ts > (rec.promoted or 0) then rec.promoted = ts end
end

function Members:OnPlayerActivated()
    -- Forget people who are no longer in the guild, so the saved data stays small.
    for guildId, members in pairs(self.sv.rankInfo) do
        if not U.IsPlayerInGuild(guildId) then
            self.sv.rankInfo[guildId] = nil
        else
            for name in pairs(members) do
                if not U.IsMember(guildId, name) then members[name] = nil end
            end
        end
    end
    -- The roster is loaded by now; give it a moment and report who is inactive.
    if self.sv.alertOnLogin then
        zo_callLater(function()
            local n = #self:GetInactive()
            if n > 0 then
                U.Alert(zo_strformat("<<1>> <<1[member has/members have]>> been offline longer than your limit. /gt inactive", n))
            end
        end, 5000)
    end
end

-- Roster ---------------------------------------------------------------------

-- Every member of a guild: { guildId, name, note, rankIndex, rankName, online, lastOnline, offlineSecs }
-- 1.27.0: read once per redraw of the window (the Members and Inactive tab buttons, the top
-- line and the rows all share it) instead of once for each of them.
function Members:GetRoster(guildId)
    return GT.Report:Cached("members:roster:" .. guildId, function() return self:ReadRoster(guildId) end)
end

function Members:ReadRoster(guildId)
    local list, now = {}, GetTimeStamp()
    for i = 1, GetNumGuildMembers(guildId) do
        local name, note, rankIndex, status, secsSinceLogoff = GetGuildMemberInfo(guildId, i)
        local online = status ~= PLAYER_STATUS_OFFLINE
        list[#list + 1] = {
            guildId = guildId, name = name, note = note, rankIndex = rankIndex,
            rankName = GetFinalGuildRankName(guildId, rankIndex),
            online = online, offlineSecs = online and 0 or secsSinceLogoff,
            lastOnline = online and now or (now - secsSinceLogoff),
        }
    end
    return list
end

function Members:GetRankInfo(guildId, name)
    local members = self.sv.rankInfo[guildId]
    return members and members[name]
end

local function FormatDay(ts)
    return os.date("%Y-%m-%d", ts)
end

-- "12.3d (since 2026-11-05)" or "before 2026-10-19" when we have no rank change for them.
function Members:DescribeRankTime(member)
    local rec = self:GetRankInfo(member.guildId, member.name)
    if rec and rec.changed then
        return U.FormatDuration(GetTimeStamp() - rec.changed) .. " (since " .. FormatDay(rec.changed) .. ")", rec.changed
    end
    local oldest = self.sv.oldest[member.guildId]
    return oldest and ("since before " .. FormatDay(oldest)) or "unknown", nil
end

-- "120.4d (since 2026-07-28)" or "since before 2026-10-19" when we never saw them join.
function Members:DescribeJoined(member)
    local rec = self:GetRankInfo(member.guildId, member.name)
    if rec and rec.joined then
        return U.FormatDuration(GetTimeStamp() - rec.joined) .. " (since " .. FormatDay(rec.joined) .. ")", rec.joined
    end
    local oldest = self.sv.oldest[member.guildId]
    return oldest and ("since before " .. FormatDay(oldest)) or "unknown", nil
end

function Members:DescribePromoted(member)
    local rec = self:GetRankInfo(member.guildId, member.name)
    if rec and rec.promoted then return FormatDay(rec.promoted), rec.promoted end
    local oldest = self.sv.oldest[member.guildId]
    return oldest and ("none since " .. FormatDay(oldest)) or "unknown", nil
end

function Members:DescribeOnline(member)
    if member.online then return "|c5EE6A0online now|r" end
    return FormatDay(member.lastOnline) .. " (" .. U.FormatDuration(member.offlineSecs) .. " ago)"
end

function Members:GetGuildFilter()
    local wanted = self.sv.filter.guildId
    for _, guildId in ipairs(U.GetGuildIds()) do
        if guildId == wanted then return guildId end
    end
    return nil
end

-- Sorting and rank filter, shared by the Members and Inactive tabs.
-- filter.sort = column key, filter.desc = reversed, filter.groupRank = keep each rank together
-- (highest rank first) and sort inside it, filter.rank = "" for all ranks or one rank name.
function Members:SortList(list, filter, multiGuild)
    local sort, desc = filter.sort, filter.desc
    local now = GetTimeStamp()
    -- Someone with no join or rank change in history has had it longer than anyone we do know about,
    -- so they sort as just past the oldest roster event of their guild.
    local function Since(m, ts)
        if ts then return now - ts end
        local oldest = self.sv.oldest[m.guildId]
        return oldest and (now - oldest + 1) or -1
    end
    local function Value(m)
        if sort == "rank" then return m.rankIndex end
        if sort == "atrank" then local rec = self:GetRankInfo(m.guildId, m.name); return Since(m, rec and rec.changed) end
        if sort == "inguild" then local rec = self:GetRankInfo(m.guildId, m.name); return Since(m, rec and rec.joined) end
        if sort == "promoted" then local rec = self:GetRankInfo(m.guildId, m.name); return rec and rec.promoted or 0 end
        if sort == "offline" or sort == "lastonline" then return m.offlineSecs end
        if sort == "limit" then return m.limitDays or 0 end
        if sort == "guild" then return zo_strlower(U.GuildName(m.guildId)) end
        if sort == "note" then return zo_strlower(m.note or "") end
        return zo_strlower(m.name)
    end
    for _, m in ipairs(list) do m.sortValue = Value(m) end
    table.sort(list, function(a, b)
        if filter.groupRank then
            if multiGuild and a.guildId ~= b.guildId then return U.GuildName(a.guildId) < U.GuildName(b.guildId) end
            if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
        end
        local va, vb = a.sortValue, b.sortValue
        if va ~= vb then
            if desc then return va > vb end
            return va < vb
        end
        return zo_strlower(a.name) < zo_strlower(b.name)
    end)
end

function Members:RankMatches(filter, m)
    return (filter.rank or "") == "" or zo_strlower(m.rankName or "") == zo_strlower(filter.rank)
end

-- Rank names across the guilds shown, highest rank first, for the rank filter menu.
function Members:GetRankNames(guildId)
    local names, seen = {}, {}
    local ids = guildId and { guildId } or U.GetGuildIds()
    local maxRanks = 0
    for _, id in ipairs(ids) do maxRanks = math.max(maxRanks, GetNumGuildRanks(id)) end
    for rankIndex = 1, maxRanks do
        for _, id in ipairs(ids) do
            if rankIndex <= GetNumGuildRanks(id) then
                local name = GetFinalGuildRankName(id, rankIndex)
                if not seen[zo_strlower(name)] then
                    seen[zo_strlower(name)] = true
                    names[#names + 1] = name
                end
            end
        end
    end
    return names
end

-- Footer buttons for the rank filter and the "group by rank" toggle.
function Members:GetRankFooter(filter, guildId)
    return {
        { label = "Rank: " .. ((filter.rank or "") == "" and "All" or filter.rank), tip = "Show only one rank.", fn = function(button)
            ClearMenu()
            local function Add(label, value)
                AddMenuItem((value == (filter.rank or "")) and ("|cA08CFF" .. label .. "|r") or label, function()
                    filter.rank = value
                    GT.Report:Refresh()
                end)
            end
            Add("All ranks", "")
            for _, name in ipairs(self:GetRankNames(guildId)) do Add(name, name) end
            ShowMenu(button)
        end },
        { label = filter.groupRank and "Grouped by rank" or "Not grouped", tip = "Click to switch between grouping by rank (sorted within each rank) and one list.", fn = function()
            filter.groupRank = not filter.groupRank
            GT.Report:Refresh()
        end },
    }
end

-- Header click: sort by that column, click again to reverse. Durations start longest first.
function Members:OnSortClicked(filter, key)
    if filter.sort == key then
        filter.desc = not filter.desc
    else
        filter.sort = key
        filter.desc = (key == "inguild" or key == "atrank" or key == "offline" or key == "lastonline")
    end
end

-- Rank filter, Online only toggle and the search box.
function Members:MemberMatches(m, search)
    return self:RankMatches(self.sv.filter, m) and (m.online or not self.sv.filter.hideOffline) and (search == "" or zo_strlower(m.name):find(search, 1, true)
        or zo_strlower(m.note or ""):find(search, 1, true) or zo_strlower(m.rankName or ""):find(search, 1, true))
end

-- Returns the members the tab shows, sorted, plus how many members the picked guild(s) have in all.
function Members:GetVisibleMembers(searchText)
    local found = GT.Report:Cached("members:visible:" .. (searchText or ""), function()
        local list, total = self:BuildVisibleMembers(searchText)
        return { list = list, total = total }
    end)
    return found.list, found.total
end

function Members:BuildVisibleMembers(searchText)
    local guildId = self:GetGuildFilter()
    local list, total = {}, 0
    local search = zo_strlower(searchText or "")
    for _, id in ipairs(U.GetGuildIds()) do
        if not guildId or id == guildId then
            for _, m in ipairs(self:GetRoster(id)) do
                total = total + 1
                if self:MemberMatches(m, search) then
                    local rec = self:GetRankInfo(id, m.name)
                    m.changed = rec and rec.changed
                    list[#list + 1] = m
                end
            end
        end
    end
    self:SortList(list, self.sv.filter, not guildId)
    return list, total
end

-- Tab title: "Members (40)", or "Members (12/40)" while a filter or search hides some.
function Members:GetMembersTitle(searchText)
    local guildId = self:GetGuildFilter()
    local shown, total = 0, 0
    local search = zo_strlower(searchText or "")
    for _, id in ipairs(U.GetGuildIds()) do
        if not guildId or id == guildId then
            for _, m in ipairs(self:GetRoster(id)) do
                total = total + 1
                if self:MemberMatches(m, search) then shown = shown + 1 end
            end
        end
    end
    if shown == total then return string.format("Members (%d)", total) end
    return string.format("Members (%d/%d)", shown, total)
end

local function OneLine(text)
    return (tostring(text or ""):gsub("[\r\n\t]+", " "))
end

function Members:GetRankColor(rankIndex)
    return RANK_COLORS[math.min(rankIndex, #RANK_COLORS)]
end

-- Column layout of the Members tab; the Guild column only shows with "All guilds".
function Members:GetColumns()
    local columns = {
        { title = "Member", width = 160, sort = "name" },
        { title = "Rank", width = 120, sort = "rank" },
        { title = "Time in guild", width = 150, sort = "inguild", tip = "How long they have been in the guild, from their latest join in roster history. \"before <date>\" means they joined before the oldest roster history you have." },
        { title = "Time at rank", width = 150, sort = "atrank", tip = "How long they have held their current rank, from roster history. \"before <date>\" means their rank has not changed since the oldest roster history you have." },
        { title = "Last online", width = 145, sort = "offline" },
    }
    if not self:GetGuildFilter() then columns[#columns + 1] = { title = "Guild", width = 110, sort = "guild" } end
    local used = 0
    for _, c in ipairs(columns) do used = used + c.width + 8 end
    -- No row buttons (everything is in the right-click menu), so the note gets the rest of the row.
    columns[#columns + 1] = { title = "Note", width = math.max(80, 1140 - used), sort = "note" }
    return columns
end

function Members:GetMemberRow(m)
    local rec = self:GetRankInfo(m.guildId, m.name)
    local oldest = self.sv.oldest[m.guildId]
    local inGuild
    if rec and rec.joined then
        inGuild = U.FormatDuration(GetTimeStamp() - rec.joined) .. "  |cB4B0D8" .. FormatDay(rec.joined) .. "|r"
    else
        inGuild = "|cB4B0D8" .. (oldest and ("before " .. FormatDay(oldest)) or "unknown") .. "|r"
    end
    local held
    if rec and rec.changed then
        held = U.FormatDuration(GetTimeStamp() - rec.changed) .. "  |cB4B0D8" .. FormatDay(rec.changed) .. "|r"
    else
        held = "|cB4B0D8" .. (oldest and ("before " .. FormatDay(oldest)) or "unknown") .. "|r"
    end
    local online = m.online and "|c5EE6A0online now|r"
        or (U.FormatDuration(m.offlineSecs) .. " ago  |cB4B0D8" .. FormatDay(m.lastOnline) .. "|r")
    local cells = {
        m.name,
        "|c" .. self:GetRankColor(m.rankIndex) .. m.rankName .. "|r",
        inGuild,
        held,
        online,
    }
    if not self:GetGuildFilter() then cells[#cells + 1] = "|cB4B0D8" .. U.GuildName(m.guildId) .. "|r" end
    cells[#cells + 1] = "|cB4B0D8" .. OneLine(m.note) .. "|r"
    local tooltip = table.concat({
        m.name .. " - " .. U.GuildName(m.guildId),
        "In guild: " .. self:DescribeJoined(m),
        "Rank: " .. m.rankName .. ", held " .. self:DescribeRankTime(m),
        "Last promoted: " .. self:DescribePromoted(m),
        "Last online: " .. (m.online and "online now" or self:DescribeOnline(m)),
        "Note: " .. (m.note ~= "" and m.note or "(none)"),
    }, "\n")
    -- Offline members are drawn a bit faded so the ones online now stand out.
    local row = { cells = cells, tooltip = tooltip, faded = not m.online }
    if m.name == GetDisplayName() then return row end
    return GT.Report.AddMenu(row, self:MemberItems(m, false))
end

-- Inactive -------------------------------------------------------------------

-- Default rule for a rank: the Guild Master isn't checked; ranks named "officer" (or rank 2 if
-- none is) use the officer limit; ranks named "recruit" (or the lowest rank if none is) use the
-- recruit limit; everyone else the member limit.
function Members:GetDefaultRule(guildId, rankIndex)
    if rankIndex == 1 then return RULE_OFF end
    local numRanks = GetNumGuildRanks(guildId)
    local anyRecruit, anyOfficer = false, false
    for i = 1, numRanks do
        local n = zo_strlower(GetFinalGuildRankName(guildId, i))
        if n:find("recruit", 1, true) then anyRecruit = true end
        if n:find("officer", 1, true) then anyOfficer = true end
    end
    local name = zo_strlower(GetFinalGuildRankName(guildId, rankIndex))
    if (anyOfficer and name:find("officer", 1, true)) or (not anyOfficer and rankIndex == 2 and numRanks > 2) then
        return RULE_OFFICER
    end
    if (anyRecruit and name:find("recruit", 1, true)) or (not anyRecruit and rankIndex == numRanks) then
        return RULE_RECRUIT
    end
    return RULE_MEMBER
end

function Members:GetRule(guildId, rankIndex)
    local rules = self.sv.rankRules[guildId]
    return (rules and rules[rankIndex]) or self:GetDefaultRule(guildId, rankIndex)
end

function Members:SetRule(guildId, rankIndex, rule)
    self.sv.rankRules[guildId] = self.sv.rankRules[guildId] or {}
    self.sv.rankRules[guildId][rankIndex] = rule
end

function Members:GetLimitDays(rule, guildId)
    local g = self:G(guildId)
    if rule == RULE_OFFICER then return g.officerDays end
    if rule == RULE_RECRUIT then return g.recruitDays end
    if rule == RULE_MEMBER then return g.memberDays end
    return nil
end

local function DismissKey(guildId, name)
    return tostring(guildId) .. ":" .. name
end

-- Members over their limit, in the guilds you get alerts from. A dismissed member comes back
-- once they have logged in again and gone over the limit again.
-- ESO guilds hold at most 500 members.
local GUILD_MAX_MEMBERS = 500

-- "Thieves Bane 487/500 (13 open)" for each guild the Inactive tab checks.
function Members:GetSlotSummary()
    local parts = {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) then
            local used = GetNumGuildMembers(guildId)
            local open = GUILD_MAX_MEMBERS - used
            local color = open <= 10 and "FF6666" or "9FD49F"
            parts[#parts + 1] = string.format("%s %d/%d (|c%s%d open|r)", U.GuildName(guildId), used, GUILD_MAX_MEMBERS, color, open)
        end
    end
    return "Slots: " .. table.concat(parts, ", ") .. "."
end

function Members:GetInactive()
    return GT.Report:Cached("members:inactive", function() return self:BuildInactive() end)
end

function Members:BuildInactive()
    local list = {}
    local me = GetDisplayName()
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) and self:G(guildId).inactiveEnabled then
            for _, m in ipairs(self:GetRoster(guildId)) do
                local days = self:GetLimitDays(self:GetRule(guildId, m.rankIndex), guildId)
                if days and m.name ~= me and not m.online and m.offlineSecs > days * DAY then
                    local dismissedAt = self.sv.dismissed[DismissKey(guildId, m.name)]
                    if not dismissedAt or m.lastOnline > dismissedAt + 3600 then
                        m.limitDays = days
                        list[#list + 1] = m
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.offlineSecs ~= b.offlineSecs then return a.offlineSecs > b.offlineSecs end
        return a.name < b.name
    end)
    return list
end

-- What the Inactive tab shows: rank filter, then sorted (grouped by rank if chosen).
-- True when at least one ticked guild has inactivity alerts on.
function Members:AnyInactiveOn()
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) and self:G(guildId).inactiveEnabled then return true end
    end
    return false
end

function Members:GetVisibleInactive()
    local list = {}
    for _, m in ipairs(self:GetInactive()) do
        if self:RankMatches(self.sv.inactiveFilter, m) then list[#list + 1] = m end
    end
    self:SortList(list, self.sv.inactiveFilter, true)
    return list
end

function Members:GetInactiveColumns()
    return {
        { title = "Member", width = 160, sort = "name" },
        { title = "Rank", width = 115, sort = "rank" },
        { title = "Guild", width = 115, sort = "guild" },
        { title = "Offline", width = 70, sort = "offline", tip = "How long they have been offline." },
        { title = "Last online", width = 95, sort = "lastonline" },
        { title = "Limit", width = 45, sort = "limit", tip = "The inactivity limit for their rank, in days." },
        { title = "In guild", width = 150, sort = "inguild", tip = "How long they have been in the guild, from their latest join in roster history. \"before <date>\" means they joined before the oldest roster history you have." },
        { title = "Note", width = 312, sort = "note" },
    }
end

function Members:Dismiss(m)
    self.sv.dismissed[DismissKey(m.guildId, m.name)] = m.lastOnline
    GT.Report:RefreshIfShown()
end

-- Menu items shared by the Members and Inactive rows. Every change still asks for confirmation.
-- inactive: Inactive tab (they're offline, so no whisper; Kick counts as a kick for inactivity
-- and can send the "welcome back" mail).
function Members:MemberItems(m, inactive)
    local g = self:G(m.guildId)
    local days = tostring(math.floor(m.offlineSecs / DAY))
    local subject = zo_strformat(inactive and g.inactiveSubject or g.contactSubject, m.name, U.GuildName(m.guildId), days, m.limitDays or "")
    local text = zo_strformat(inactive and g.inactiveText or g.contactText, m.name, U.GuildName(m.guildId), days, m.limitDays or "")
    local done = function() GT.Report:RefreshIfShown() end
    local items = {}
    local function Add(item) items[#items + 1] = item end
    if inactive then
        Add({ label = "Mail the \"we miss you\" text", fn = function() A.Warn(m.name, subject, text, "mail") end })
        Add({ label = "Mail " .. m.name, fn = function() A.Warn(m.name, "", "", "mail") end })
        Add(GT.Report.CopyItem(m.name))
        Add(GT.Report.TravelItem(m.name))
        Add(GT.Report.HouseItem(m.name))
    else
        for _, item in ipairs(GT.Report.ContactItems(m.name)) do Add(item) end
        Add({ label = "Whisper the contact text", fn = function() A.Warn(m.name, subject, text, "whisper") end })
        Add({ label = "Mail the contact text", fn = function() A.Warn(m.name, subject, text, "mail") end })
        if #GT.Raffle:GiftRaffles() > 0 then
            Add({ label = "Give raffle tickets...", opensMenu = true, fn = function(control) GT.Raffle:GiftMenu(control, m.name) end })
        end
    end
    Add({ label = "Set rank...", opensMenu = true, fn = function(control) A.ChooseRank(control, m.guildId, m.name, done) end })
    Add({ label = "Kick (asks first)", fn = function()
        A.Kick(m.guildId, m.name, false, nil, done, inactive and { days = math.floor(m.offlineSecs / DAY), limitDays = m.limitDays } or nil)
    end })
    Add({ label = "Kick and blacklist (asks first)", fn = function() A.Kick(m.guildId, m.name, true, g.removeNote, done) end })
    if inactive then
        Add({ label = "Dismiss (until they log in and go over again)", fn = function() self:Dismiss(m) end })
    end
    return items
end

-- Short "In guild" cell for the Inactive tab: "120.4d", or "before 2026-10-19" in grey.
function Members:InGuildCell(m)
    local rec = self:GetRankInfo(m.guildId, m.name)
    if rec and rec.joined then return U.FormatDuration(GetTimeStamp() - rec.joined) end
    local oldest = self.sv.oldest[m.guildId]
    return "|cB4B0D8" .. (oldest and ("before " .. FormatDay(oldest)) or "unknown") .. "|r"
end

function Members:GetInactiveRow(m)
    local cells = {
        m.name,
        "|c" .. self:GetRankColor(m.rankIndex) .. m.rankName .. "|r",
        "|cB4B0D8" .. U.GuildName(m.guildId) .. "|r",
        "|cFFA45C" .. U.FormatDuration(m.offlineSecs) .. "|r",
        FormatDay(m.lastOnline),
        m.limitDays .. "d",
        self:InGuildCell(m),
        "|cB4B0D8" .. OneLine(m.note) .. "|r",
    }
    local tooltip = table.concat({
        m.name .. " - " .. U.GuildName(m.guildId),
        "In guild: " .. self:DescribeJoined(m),
        "Rank: " .. m.rankName .. ", held " .. self:DescribeRankTime(m),
        "Last online: " .. FormatDay(m.lastOnline),
        "Note: " .. (m.note ~= "" and m.note or "(none)"),
    }, "\n")
    return GT.Report.AddMenu({ cells = cells, tooltip = tooltip }, self:MemberItems(m, true))
end

-- Tabs -----------------------------------------------------------------------

function Members:MembersTabRows(tab)
    local rows = {}
    for _, m in ipairs(self:GetVisibleMembers(tab.searchText)) do rows[#rows + 1] = self:GetMemberRow(m) end
    return rows
end

function Members:MembersTabExportLines(tab)
    local lines = { "Guild\tMember\tRank\tIn guild since\tDays in guild\tAt rank since\tDays at rank\tLast promoted\tLast online\tDays offline\tNote" }
    local now = GetTimeStamp()
    for _, m in ipairs(self:GetVisibleMembers(tab.searchText)) do
        local rec = self:GetRankInfo(m.guildId, m.name)
        local oldest = self.sv.oldest[m.guildId]
        local since = (rec and rec.changed) and FormatDay(rec.changed) or (oldest and ("before " .. FormatDay(oldest)) or "")
        local daysAt = (rec and rec.changed) and string.format("%.1f", (now - rec.changed) / DAY) or ""
        local joined = (rec and rec.joined) and FormatDay(rec.joined) or (oldest and ("before " .. FormatDay(oldest)) or "")
        local daysIn = (rec and rec.joined) and string.format("%.1f", (now - rec.joined) / DAY) or ""
        local promoted = (rec and rec.promoted) and FormatDay(rec.promoted) or ""
        lines[#lines + 1] = table.concat({ U.GuildName(m.guildId), m.name, m.rankName, joined, daysIn, since, daysAt, promoted,
            m.online and "online" or FormatDay(m.lastOnline), string.format("%.1f", m.offlineSecs / DAY), OneLine(m.note) }, "\t")
    end
    return lines
end

function Members:InactiveTabRows()
    local rows = {}
    for _, m in ipairs(self:GetVisibleInactive()) do rows[#rows + 1] = self:GetInactiveRow(m) end
    return rows
end

function Members:InactiveTabExportLines()
    local lines = { "Guild\tMember\tRank\tLast online\tDays offline\tLimit (days)\tIn guild since\tDays in guild\tNote" }
    local now = GetTimeStamp()
    for _, m in ipairs(self:GetVisibleInactive()) do
        local rec = self:GetRankInfo(m.guildId, m.name)
        local oldest = self.sv.oldest[m.guildId]
        local joined = (rec and rec.joined) and FormatDay(rec.joined) or (oldest and ("before " .. FormatDay(oldest)) or "")
        local daysIn = (rec and rec.joined) and string.format("%.1f", (now - rec.joined) / DAY) or ""
        lines[#lines + 1] = table.concat({ U.GuildName(m.guildId), m.name, m.rankName, FormatDay(m.lastOnline),
            string.format("%.1f", m.offlineSecs / DAY), m.limitDays, joined, daysIn, OneLine(m.note) }, "\t")
    end
    return lines
end

function Members:MembersTabSummary(membersTab)
    local guildId = self:GetGuildFilter()
    return string.format("%s: %d members. Click a column header to sort. Join and rank dates come from roster history; hover a row for the full note.",
        guildId and U.GuildName(guildId) or "All guilds", #self:GetVisibleMembers(membersTab.searchText))
end

function Members:InactiveTabSummary()
    local parts = {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) then
            local g = self:G(guildId)
            if g.inactiveEnabled then
                parts[#parts + 1] = string.format("%s: officers %dd, members %dd, recruits %dd", U.GuildName(guildId),
                    g.officerDays, g.memberDays, g.recruitDays)
            else
                parts[#parts + 1] = U.GuildName(guildId) .. ": off"
            end
        end
    end
    if #parts == 0 then return "" end   -- no guild ticked: the tab says so itself
    return string.format("%s  Limits: %s.", self:GetSlotSummary(), table.concat(parts, "; "))
end

function Members:RegisterTabs()
    local membersTab
    membersTab = {
        id = "members",
        title = function() return self:GetMembersTitle(membersTab.searchText) end,
        tip = "Everyone in your guilds: rank, time in guild, time at rank, last online and note. Hover a row for their last promotion.",
        searchable = true,
        emptyText = "No members match. Clear the search, the rank filter or Online only.",
        columns = function() return self:GetColumns() end,
        sortKey = function() return self.sv.filter.sort, self.sv.filter.desc end,
        OnSort = function(key) self:OnSortClicked(self.sv.filter, key) end,
        GetSummary = function() return self:MembersTabSummary(membersTab) end,
        GetRows = function() return self:MembersTabRows(membersTab) end,
        GetExportLines = function() return self:MembersTabExportLines(membersTab) end,
        footer = function()
            local guildId = self:GetGuildFilter()
            local footer = {
                { label = "Guild: " .. (guildId and U.GuildName(guildId) or "All guilds"), tip = "Pick which guild to show.", fn = function(button)
                    ClearMenu()
                    local function Add(label, id)
                        AddMenuItem((id == (guildId or 0)) and ("|cA08CFF" .. label .. "|r") or label, function()
                            self.sv.filter.guildId = id
                            GT.Report:Refresh()
                        end)
                    end
                    Add("All guilds", 0)
                    for _, id in ipairs(U.GetGuildIds()) do Add(U.GuildName(id), id) end
                    ShowMenu(button)
                end },
            }
            for _, b in ipairs(self:GetRankFooter(self.sv.filter, guildId)) do footer[#footer + 1] = b end
            footer[#footer + 1] = { label = self.sv.filter.hideOffline and "Online only" or "Online + offline",
                tip = "Click to switch between everyone and only members who are online now.", fn = function()
                self.sv.filter.hideOffline = not self.sv.filter.hideOffline
                GT.Report:Refresh()
            end }
            -- 1.34.0: waiting anniversary congratulations (Modules/Milestones.lua).
            local congrats = GT.Milestones:FooterButton()
            if congrats then table.insert(footer, 1, congrats) end
            return footer
        end,
    }
    GT.Report:RegisterTab(membersTab)

    GT.Report:RegisterTab({
        id = "inactive",
            GetOffText = function() return GT:FeatureOffText(self:AnyInactiveOn(), "Inactivity alerts (in Rules for each guild)", true) end,
        tip = "Members who have been offline longer than the limit for their rank, and how many guild slots are open. Limits and ranks are on the Guild rules settings page (/gtsettings > Open Guild rules settings).",
        title = function() return string.format("Inactive (%d)", #self:GetInactive()) end,
        about = {
            "Lists members who have been offline longer than the limit for their rank, so you can free up slots.",
            "Right-click a member to mail them a \"we miss you\" text, set their rank, kick them or dismiss them. Every change asks first.",
            "Limits (30 days for officers, 21 for members and 14 for recruits to start) are set for each guild on the Guild rules settings page.",
        },
        emptyText = "No one is over their limit.",
        columns = function() return self:GetInactiveColumns() end,
        sortKey = function() return self.sv.inactiveFilter.sort, self.sv.inactiveFilter.desc end,
        OnSort = function(key) self:OnSortClicked(self.sv.inactiveFilter, key) end,
        GetSummary = function() return self:InactiveTabSummary() end,
        GetRows = function() return self:InactiveTabRows() end,
        GetExportLines = function() return self:InactiveTabExportLines() end,
        footer = function()
            local footer = self:GetRankFooter(self.sv.inactiveFilter, nil)
            footer[#footer + 1] = { label = "Dismiss shown", tip = "Hides everyone listed until they log in again. Asks first.", fn = function()
                local list = self:GetVisibleInactive()
                if #list == 0 then return end
                A.Confirm("Dismiss inactive", zo_strformat("Hide the <<1>> <<1[member/members]>> shown until they log in again?", #list), function()
                    for _, m in ipairs(list) do self.sv.dismissed[DismissKey(m.guildId, m.name)] = m.lastOnline end
                    GT.Report:RefreshIfShown()
                end)
            end }
            footer[#footer + 1] = { label = "Show dismissed again", tip = "Brings back everyone you dismissed.", fn = function()
                self.sv.dismissed = {}
                GT.Report:RefreshIfShown()
            end }
            return footer
        end,
    })
end

-- Settings -------------------------------------------------------------------

function Members:BuildSettings(options)
    local sv, defaults = self.sv, self.defaults
    local controls = {
        { type = "checkbox", name = "Alert at login", tooltip = "Tell me at login how many members are over their limit.",
          getFunc = function() return sv.alertOnLogin end, setFunc = function(v) sv.alertOnLogin = v end, default = defaults.alertOnLogin },
        { type = "description", text = "Inactivity limits, the limit for each rank and the contact texts are set for each guild under Rules for (guild) on the Guild rules page." },
        GT.Settings:RulesButton("Opens the Guild rules page, where each guild's inactivity limits, the limit for each rank, and the \"we miss you\", kick and blacklist mails are set."),
    }
    options[#options + 1] = { type = "submenu", name = "Members and inactivity", controls = controls }
end

-- One guild's inactivity settings and rank rules, inside that guild's Rules submenu.
function Members:BuildGuildSettings(controls, guildId)
    local defaults = self.defaults
    local g = self:G(guildId)
    local function Refresh() GT.Report:RefreshIfShown() end
    local list = {
        { type = "header", name = "Inactive members" },
        { type = "checkbox", name = "Inactivity alerts", getFunc = function() return g.inactiveEnabled end,
          setFunc = function(v) g.inactiveEnabled = v; Refresh() end, default = defaults.inactiveEnabled },
        { type = "slider", name = "Officer limit (days offline)", min = 1, max = 180, step = 1,
          getFunc = function() return g.officerDays end, setFunc = function(v) g.officerDays = v; Refresh() end, default = defaults.officerDays,
          disabled = function() return not g.inactiveEnabled end },
        { type = "slider", name = "Member limit (days offline)", min = 1, max = 180, step = 1,
          getFunc = function() return g.memberDays end, setFunc = function(v) g.memberDays = v; Refresh() end, default = defaults.memberDays,
          disabled = function() return not g.inactiveEnabled end },
        { type = "slider", name = "Recruit limit (days offline)", min = 1, max = 180, step = 1,
          getFunc = function() return g.recruitDays end, setFunc = function(v) g.recruitDays = v; Refresh() end, default = defaults.recruitDays,
          disabled = function() return not g.inactiveEnabled end },
        { type = "description", text = "For each rank, choose which limit applies, or Not checked." },
    }
    local choices = { RULE_LABELS[RULE_OFFICER], RULE_LABELS[RULE_MEMBER], RULE_LABELS[RULE_RECRUIT], RULE_LABELS[RULE_OFF] }
    for rankIndex = 1, GetNumGuildRanks(guildId) do
        local r = rankIndex
        list[#list + 1] = {
            type = "dropdown", name = string.format("%d %s", r, GetFinalGuildRankName(guildId, r)), choices = choices,
            getFunc = function() return RULE_LABELS[self:GetRule(guildId, r)] end,
            setFunc = function(v) self:SetRule(guildId, r, RULE_BY_LABEL[v]); Refresh() end,
            default = RULE_LABELS[self:GetDefaultRule(guildId, r)],
            disabled = function() return not g.inactiveEnabled end,
        }
    end
    local texts = {
        { type = "header", name = "Contact texts" },
        { type = "description", text = "<<1>> = @name, <<2>> = guild, <<3>> = days offline, <<4>> = their limit in days. Nothing is sent until you press Enter or Send." },
        { type = "editbox", name = "Members tab: subject", getFunc = function() return g.contactSubject end,
          setFunc = function(v) g.contactSubject = v end, default = defaults.contactSubject },
        { type = "editbox", name = "Members tab: message", isMultiline = true, getFunc = function() return g.contactText end,
          setFunc = function(v) g.contactText = v end, default = defaults.contactText },
        { type = "editbox", name = "Inactive tab: subject", getFunc = function() return g.inactiveSubject end,
          setFunc = function(v) g.inactiveSubject = v end, default = defaults.inactiveSubject },
        { type = "editbox", name = "Inactive tab: message", isMultiline = true, getFunc = function() return g.inactiveText end,
          setFunc = function(v) g.inactiveText = v end, default = defaults.inactiveText },
        { type = "editbox", name = "Blacklist reason (Kick and blacklist)", tooltip = "Filled into the reason box when you click Kick and blacklist on the Members or Inactive tab. You can change it there before confirming.",
          getFunc = function() return g.removeNote end, setFunc = function(v) g.removeNote = v end, default = defaults.removeNote },
        { type = "header", name = "Mail when you kick or blacklist" },
        { type = "description", text = "Sent in the background after you click Confirm in the kick window (normal postage). The window has a Send mail button to skip it for one person, and hovering it shows the mail." },
        { type = "checkbox", name = "Mail members kicked for inactivity", tooltip = "Kick on the Inactive tab mails them why they were removed and that they're welcome back.",
          getFunc = function() return g.kickMail end, setFunc = function(v) g.kickMail = v end, default = defaults.kickMail },
        { type = "description", text = "<<1>> = @name, <<2>> = guild, <<3>> = days offline, <<4>> = their limit in days." },
        { type = "editbox", name = "Inactivity kick: subject", getFunc = function() return g.kickSubject end,
          setFunc = function(v) g.kickSubject = v end, default = defaults.kickSubject, disabled = function() return not g.kickMail end },
        { type = "editbox", name = "Inactivity kick: message", isMultiline = true, getFunc = function() return g.kickText end,
          setFunc = function(v) g.kickText = v end, default = defaults.kickText, disabled = function() return not g.kickMail end },
        { type = "checkbox", name = "Mail members you blacklist", tooltip = "Kick and blacklist, or Blacklist, mails them the reason you typed. Works from every tab (Members, Inactive, Bank, Hoppers, Watchlist).",
          getFunc = function() return g.blacklistMail end, setFunc = function(v) g.blacklistMail = v end, default = defaults.blacklistMail },
        { type = "description", text = "<<1>> = @name, <<2>> = guild, <<3>> = the reason." },
        { type = "editbox", name = "Blacklist: subject", getFunc = function() return g.blacklistSubject end,
          setFunc = function(v) g.blacklistSubject = v end, default = defaults.blacklistSubject, disabled = function() return not g.blacklistMail end },
        { type = "editbox", name = "Blacklist: message", isMultiline = true, getFunc = function() return g.blacklistText end,
          setFunc = function(v) g.blacklistText = v end, default = defaults.blacklistText, disabled = function() return not g.blacklistMail end },
    }
    for _, control in ipairs(list) do controls[#controls + 1] = control end
    for _, control in ipairs(texts) do controls[#controls + 1] = control end
end
