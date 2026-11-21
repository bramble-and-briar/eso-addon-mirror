-- Members: a roster overview (rank, time at rank, last promotion, last online, guild note)
-- and an Inactive tab that flags members who have been offline too long.
--
-- API limits:
--   * The roster only gives "seconds since logoff" (GetGuildMemberInfo). That is when the
--     member last logged off, so "last online" is a date, not an exact login time.
--   * The game does not store when someone got their rank. We take it from roster history
--     (promotions, demotions and joins, through LibHistoire) and from what the History tab has
--     already logged. For anyone whose last rank change is older than that, the tab shows
--     "before <date>", the oldest roster event we have for that guild.

local GT = FuryGMT
local U = GT.Util
local A = GT.Actions

local Members = GT:RegisterModule("members", {})

local DAY = 86400
local RULE_OFFICER, RULE_MEMBER, RULE_RECRUIT, RULE_OFF = "officer", "member", "recruit", "off"
local RULE_LABELS = { [RULE_OFFICER] = "Officer limit", [RULE_MEMBER] = "Member limit", [RULE_RECRUIT] = "Recruit limit", [RULE_OFF] = "Not checked" }
local RULE_BY_LABEL = { ["Officer limit"] = RULE_OFFICER, ["Member limit"] = RULE_MEMBER, ["Recruit limit"] = RULE_RECRUIT, ["Not checked"] = RULE_OFF }
-- Rank colors by rank number (1 = Guild Master). Ranks past the list reuse the last color.
local RANK_COLORS = { "D4AF37", "E06666", "C27BA0", "8E7CC3", "6FA8DC", "76A5AF", "93C47D", "B7B7B7", "999999", "888888" }

Members.defaults = {
    inactiveEnabled = true,
    officerDays = 30,
    memberDays = 21,
    recruitDays = 14,
    alertOnLogin = true,
    -- Contact templates. <<1>> = @name, <<2>> = guild, <<3>> = days offline, <<4>> = their limit in days.
    contactSubject = "<<2>>",
    contactText = "Hi <<1>>, ",
    inactiveSubject = "We miss you in <<2>>",
    inactiveText = "Hi <<1>>, you haven't logged in to <<2>> for <<3>> days, and our limit for your rank is <<4>> days. If you'll be away for a while, let an officer know and we'll hold your spot. Otherwise you may be removed to make room for active players. Hope to see you soon!",
    removeNote = "Removed from the roster",
    rankRules = {},   -- [guildId] = { [rankIndex] = "officer" | "member" | "recruit" | "off" }; missing = default
    dismissed = {},   -- ["guildId:@name"] = when they had last logged off at the time you dismissed them
    rankInfo = {},    -- [guildId] = { ["@name"] = { joined, changed, promoted } }
    oldest = {},      -- [guildId] = oldest roster event timestamp we have seen
    filter = { guildId = 0, sort = "name", groupRank = true, rank = "", hideOffline = false },                -- Members tab
    inactiveFilter = { sort = "offline", desc = true, groupRank = true, rank = "" },  -- Inactive tab
}

-- Settings each guild has its own copy of (see GT:GuildSettings). Per-rank rules are kept per guild in rankRules.
Members.guildKeys = { "inactiveEnabled", "officerDays", "memberDays", "recruitDays", "contactSubject", "contactText",
    "inactiveSubject", "inactiveText", "removeNote" }

function Members:G(guildId)
    return GT:GuildSettings(self, guildId)
end

function Members:Initialize(sv)
    self.sv = sv
    -- Rank dates logged by the History tab before this module existed.
    local log = GT:GetModule("log")
    for _, e in ipairs(log.sv.entries) do
        if e.t == "join" then self:Apply(e.g, "join", e.who, e.ts)
        elseif e.t == "app_ok" then self:Apply(e.g, "join", e.target, e.ts)
        elseif e.t == "promote" or e.t == "demote" then self:Apply(e.g, e.t, e.target, e.ts)
        end
    end
    self:RegisterTabs()
    -- Kicking (or Set rank) only asks the server; the roster changes a moment later.
    -- Redraw when it does, so kicked members drop off Members and Inactive right away
    -- and the counts and open slots stay right. Joins and leaves by anyone else count too.
    local function RosterChanged() GT.Report:RefreshIfShown() end
    EVENT_MANAGER:RegisterForEvent("FuryGMTMembers", EVENT_GUILD_MEMBER_REMOVED, RosterChanged)
    EVENT_MANAGER:RegisterForEvent("FuryGMTMembers", EVENT_GUILD_MEMBER_ADDED, RosterChanged)
    EVENT_MANAGER:RegisterForEvent("FuryGMTMembers", EVENT_GUILD_MEMBER_RANK_CHANGED, RosterChanged)
end

function Members:GetHistoryCategories()
    return { GUILD_HISTORY_EVENT_CATEGORY_ROSTER }
end

function Members:OnHistoryEvent(guildId, category, info)
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
function Members:GetRoster(guildId)
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

function Members:DescribePromoted(member)
    local rec = self:GetRankInfo(member.guildId, member.name)
    if rec and rec.promoted then return FormatDay(rec.promoted), rec.promoted end
    local oldest = self.sv.oldest[member.guildId]
    return oldest and ("none since " .. FormatDay(oldest)) or "unknown", nil
end

function Members:DescribeOnline(member)
    if member.online then return "|c9FD49Fonline now|r" end
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
    local function Value(m)
        if sort == "rank" then return m.rankIndex end
        if sort == "atrank" then local rec = self:GetRankInfo(m.guildId, m.name); return (rec and rec.changed) and (now - rec.changed) or -1 end
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
                AddMenuItem((value == (filter.rank or "")) and ("|cD4AF37" .. label .. "|r") or label, function()
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
        filter.desc = (key == "atrank" or key == "offline" or key == "lastonline")
    end
end

-- Rank filter, Online only toggle and the search box.
function Members:MemberMatches(m, search)
    return self:RankMatches(self.sv.filter, m) and (m.online or not self.sv.filter.hideOffline) and (search == "" or zo_strlower(m.name):find(search, 1, true)
        or zo_strlower(m.note or ""):find(search, 1, true) or zo_strlower(m.rankName or ""):find(search, 1, true))
end

-- Returns the members the tab shows, sorted, plus how many members the picked guild(s) have in all.
function Members:GetVisibleMembers(searchText)
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
        { title = "Time at rank", width = 140, sort = "atrank", tip = "How long they have held their current rank, from roster history." },
        { title = "Last promoted", width = 105, sort = "promoted", tip = "Their last promotion seen in roster history." },
        { title = "Last online", width = 150, sort = "offline" },
    }
    if not self:GetGuildFilter() then columns[#columns + 1] = { title = "Guild", width = 110, sort = "guild" } end
    local used = 0
    for _, c in ipairs(columns) do used = used + c.width + 8 end
    -- 3 buttons (Contact, Set rank, Remove) take about 265 px on the right.
    columns[#columns + 1] = { title = "Note", width = math.max(80, 1140 - 265 - used), sort = "note" }
    return columns
end

function Members:GetMemberRow(m)
    local rec = self:GetRankInfo(m.guildId, m.name)
    local oldest = self.sv.oldest[m.guildId]
    local held
    if rec and rec.changed then
        held = U.FormatDuration(GetTimeStamp() - rec.changed) .. "  |cAAAAAA" .. FormatDay(rec.changed) .. "|r"
    else
        held = "|cAAAAAA" .. (oldest and ("before " .. FormatDay(oldest)) or "unknown") .. "|r"
    end
    local promoted = (rec and rec.promoted) and FormatDay(rec.promoted) or "|cAAAAAA-|r"
    local online = m.online and "|c9FD49Fonline now|r"
        or (U.FormatDuration(m.offlineSecs) .. " ago  |cAAAAAA" .. FormatDay(m.lastOnline) .. "|r")
    local cells = {
        m.name,
        "|c" .. self:GetRankColor(m.rankIndex) .. m.rankName .. "|r",
        held,
        promoted,
        online,
    }
    if not self:GetGuildFilter() then cells[#cells + 1] = "|cAAAAAA" .. U.GuildName(m.guildId) .. "|r" end
    cells[#cells + 1] = "|cCCCCCC" .. OneLine(m.note) .. "|r"
    local tooltip = table.concat({
        m.name .. " - " .. U.GuildName(m.guildId),
        "Rank: " .. m.rankName .. ", held " .. self:DescribeRankTime(m),
        "Last promoted: " .. self:DescribePromoted(m),
        "Last online: " .. (m.online and "online now" or self:DescribeOnline(m)),
        "Note: " .. (m.note ~= "" and m.note or "(none)"),
    }, "\n")
    local actions = (m.name ~= GetDisplayName()) and self:GetManageActions(m, false) or nil
    return { cells = cells, tooltip = tooltip, actions = actions }
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
function Members:GetVisibleInactive()
    local list = {}
    for _, m in ipairs(self:GetInactive()) do
        if self:RankMatches(self.sv.inactiveFilter, m) then list[#list + 1] = m end
    end
    self:SortList(list, self.sv.inactiveFilter, true)
    return list
end

function Members:GetInactiveColumns()
    -- About 350 px on the right stay free for the four buttons.
    return {
        { title = "Member", width = 160, sort = "name" },
        { title = "Rank", width = 115, sort = "rank" },
        { title = "Guild", width = 115, sort = "guild" },
        { title = "Offline", width = 70, sort = "offline", tip = "How long they have been offline." },
        { title = "Last online", width = 95, sort = "lastonline" },
        { title = "Limit", width = 45, sort = "limit", tip = "The inactivity limit for their rank, in days." },
        { title = "Note", width = 125, sort = "note" },
    }
end

function Members:Dismiss(m)
    self.sv.dismissed[DismissKey(m.guildId, m.name)] = m.lastOnline
    GT.Report:RefreshIfShown()
end

-- Buttons shared by the Members and Inactive rows. Every change still asks for confirmation.
function Members:Contact(button, m, inactive)
    local days = tostring(math.floor(m.offlineSecs / DAY))
    local g = self:G(m.guildId)
    local subjectTemplate = inactive and g.inactiveSubject or g.contactSubject
    local textTemplate = inactive and g.inactiveText or g.contactText
    local subject = zo_strformat(subjectTemplate, m.name, U.GuildName(m.guildId), days, m.limitDays or "")
    local text = zo_strformat(textTemplate, m.name, U.GuildName(m.guildId), days, m.limitDays or "")
    ClearMenu()
    AddMenuItem("Whisper", function() A.Warn(m.name, subject, text, "whisper") end)
    AddMenuItem("Mail", function() A.Warn(m.name, subject, text, "mail") end)
    ShowMenu(button)
end

function Members:Remove(button, m)
    local done = function() GT.Report:RefreshIfShown() end
    ClearMenu()
    AddMenuItem("Kick", function() A.Kick(m.guildId, m.name, false, nil, done) end)
    AddMenuItem("Kick and blacklist", function() A.Kick(m.guildId, m.name, true, self:G(m.guildId).removeNote, done) end)
    ShowMenu(button)
end

function Members:GetManageActions(m, inactive)
    return {
        { label = "Contact", tip = "Whisper or mail them, using the texts from settings.", fn = function(button) self:Contact(button, m, inactive) end },
        { label = "Set rank", tip = "Pick a new rank for them. Asks first.", fn = function(button)
            A.ChooseRank(button, m.guildId, m.name, function() GT.Report:RefreshIfShown() end)
        end },
        { label = "Remove", tip = "Kick, or kick and blacklist. Asks first.", fn = function(button) self:Remove(button, m) end },
    }
end

function Members:GetInactiveRow(m)
    local cells = {
        m.name,
        "|c" .. self:GetRankColor(m.rankIndex) .. m.rankName .. "|r",
        "|cAAAAAA" .. U.GuildName(m.guildId) .. "|r",
        "|cFF9933" .. U.FormatDuration(m.offlineSecs) .. "|r",
        FormatDay(m.lastOnline),
        m.limitDays .. "d",
        "|cCCCCCC" .. OneLine(m.note) .. "|r",
    }
    local tooltip = table.concat({
        m.name .. " - " .. U.GuildName(m.guildId),
        "Rank: " .. m.rankName .. ", held " .. self:DescribeRankTime(m),
        "Last online: " .. FormatDay(m.lastOnline),
        "Note: " .. (m.note ~= "" and m.note or "(none)"),
        "Dismiss hides them until they log in and go over the limit again.",
    }, "\n")
    local actions = self:GetManageActions(m, true)
    actions[#actions + 1] = { label = "Dismiss", tip = "Hides them until they log in and go over the limit again.", fn = function() self:Dismiss(m) end }
    return { cells = cells, tooltip = tooltip, actions = actions }
end

-- Tabs -----------------------------------------------------------------------

function Members:RegisterTabs()
    local membersTab
    membersTab = {
        id = "members",
        title = function() return self:GetMembersTitle(membersTab.searchText) end,
        tip = "Everyone in your guilds: rank, time at rank, last promotion, last online and note.",
        searchable = true,
        columns = function() return self:GetColumns() end,
        sortKey = function() return self.sv.filter.sort, self.sv.filter.desc end,
        OnSort = function(key) self:OnSortClicked(self.sv.filter, key) end,
        GetSummary = function()
            local guildId = self:GetGuildFilter()
            return string.format("%s: %d members. Click a column header to sort. Rank dates come from roster history; hover a row for the full note.",
                guildId and U.GuildName(guildId) or "All guilds", #self:GetVisibleMembers(membersTab.searchText))
        end,
        GetRows = function()
            local rows = {}
            for _, m in ipairs(self:GetVisibleMembers(membersTab.searchText)) do rows[#rows + 1] = self:GetMemberRow(m) end
            return rows
        end,
        GetExportLines = function()
            local lines = { "Guild\tMember\tRank\tAt rank since\tDays at rank\tLast promoted\tLast online\tDays offline\tNote" }
            local now = GetTimeStamp()
            for _, m in ipairs(self:GetVisibleMembers(membersTab.searchText)) do
                local rec = self:GetRankInfo(m.guildId, m.name)
                local oldest = self.sv.oldest[m.guildId]
                local since = (rec and rec.changed) and FormatDay(rec.changed) or (oldest and ("before " .. FormatDay(oldest)) or "")
                local daysAt = (rec and rec.changed) and string.format("%.1f", (now - rec.changed) / DAY) or ""
                local promoted = (rec and rec.promoted) and FormatDay(rec.promoted) or ""
                lines[#lines + 1] = table.concat({ U.GuildName(m.guildId), m.name, m.rankName, since, daysAt, promoted,
                    m.online and "online" or FormatDay(m.lastOnline), string.format("%.1f", m.offlineSecs / DAY), OneLine(m.note) }, "\t")
            end
            return lines
        end,
        footer = function()
            local guildId = self:GetGuildFilter()
            local footer = {
                { label = "Guild: " .. (guildId and U.GuildName(guildId) or "All guilds"), tip = "Pick which guild to show.", fn = function(button)
                    ClearMenu()
                    local function Add(label, id)
                        AddMenuItem((id == (guildId or 0)) and ("|cD4AF37" .. label .. "|r") or label, function()
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
            return footer
        end,
    }
    GT.Report:RegisterTab(membersTab)

    GT.Report:RegisterTab({
        id = "inactive",
        tip = "Members who have been offline longer than the limit for their rank, and how many guild slots are open. Limits and ranks are in /gtsettings.",
        title = function() return string.format("Inactive (%d)", #self:GetInactive()) end,
        columns = function() return self:GetInactiveColumns() end,
        sortKey = function() return self.sv.inactiveFilter.sort, self.sv.inactiveFilter.desc end,
        OnSort = function(key) self:OnSortClicked(self.sv.inactiveFilter, key) end,
        GetSummary = function()
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
            return string.format("%s  Limits: %s.", self:GetSlotSummary(), table.concat(parts, "; "))
        end,
        GetRows = function()
            local rows = {}
            for _, m in ipairs(self:GetVisibleInactive()) do rows[#rows + 1] = self:GetInactiveRow(m) end
            return rows
        end,
        GetExportLines = function()
            local lines = { "Guild\tMember\tRank\tLast online\tDays offline\tLimit (days)\tNote" }
            for _, m in ipairs(self:GetVisibleInactive()) do
                lines[#lines + 1] = table.concat({ U.GuildName(m.guildId), m.name, m.rankName, FormatDay(m.lastOnline),
                    string.format("%.1f", m.offlineSecs / DAY), m.limitDays, OneLine(m.note) }, "\t")
            end
            return lines
        end,
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
        { type = "description", text = "Inactivity limits, the limit for each rank and the contact texts are set for each guild under Rules for (guild) below." },
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
        { type = "editbox", name = "Blacklist note (Kick and blacklist)", getFunc = function() return g.removeNote end,
          setFunc = function(v) g.removeNote = v end, default = defaults.removeNote },
    }
    for _, control in ipairs(list) do controls[#controls + 1] = control end
    for _, control in ipairs(texts) do controls[#controls + 1] = control end
end
