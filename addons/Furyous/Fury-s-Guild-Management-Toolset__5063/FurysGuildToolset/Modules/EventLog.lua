-- Event Log: keeps a searchable record of past guild events (bank items, bank gold and
-- roster changes) for every guild, shows them in a "History" tab with filters, and exports
-- them as tab-separated text for Excel, Google Sheets or Discord.
--
-- It sees everything LibHistoire has for each guild from the first-run look-back onward,
-- and keeps it for "keepDays" even after the game's own history window has moved on.

local GT = FurysGuildToolset
local U = GT.Util

local EventLog = GT:RegisterModule("log", {})

local MAX_ROWS_SHOWN = 2000

EventLog.defaults = {
    enabled = false,   -- every feature starts turned off on a new install (Albert, 1.3.0)
    keepDays = 90,
    maxEntries = 20000,
    returnHours = 72,   -- a deposit of the same item by the same member within this time counts as a return
    -- History tab filters, saved so they stay as you left them after a reload or relog.
    filter = { group = "all", rangeIndex = 2, guildId = 0, view = "events", search = "" },
    entries = {},   -- list of { g, id, ts, t, who, target, qty, link, amount, rank }
}

-- Event type codes -> label, group
local TYPES = {
    item_out   = { label = "Withdrew item",    group = "items" },
    item_in    = { label = "Deposited item",   group = "items" },
    gold_out   = { label = "Withdrew gold",    group = "gold" },
    gold_in    = { label = "Deposited gold",   group = "gold" },
    join       = { label = "Joined",           group = "roster" },
    leave      = { label = "Left",             group = "roster" },
    kick       = { label = "Kicked",           group = "roster" },
    invite     = { label = "Invited",          group = "roster" },
    promote    = { label = "Promoted",         group = "roster" },
    demote     = { label = "Demoted",          group = "roster" },
    app_ok     = { label = "Accepted application", group = "roster" },
    app_no     = { label = "Declined application", group = "roster" },
    bl_add     = { label = "Blacklisted",      group = "roster" },
    bl_remove  = { label = "Removed from blacklist", group = "roster" },
}

local GROUP_FILTERS = { "all", "items", "gold", "roster" }
local GROUP_LABEL = { all = "All events", items = "Bank items", gold = "Bank gold", roster = "Roster" }
local RANGES = { 1, 7, 30, 90 }
local VIEWS = { "events", "members" }

-- Event ids are only unique within one guild and history category, so the de-duplication key has both.
local function GroupOfType(t)
    if t == "item_in" or t == "item_out" then return "items" end
    if t == "gold_in" or t == "gold_out" then return "gold" end
    return "roster"
end

local function GroupOfCategory(category)
    if category == GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM then return "items" end
    if category == GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY then return "gold" end
    return "roster"
end

local function SeenKey(guildId, group, eventId)
    return tostring(guildId) .. ":" .. group .. ":" .. tostring(eventId)
end

-- Settings each guild has its own copy of (see GT:GuildSettings).
EventLog.guildKeys = { "returnHours" }

function EventLog:Initialize(sv)
    self.sv = sv
    self.filter = sv.filter
    self.filter.guildIndex = nil  -- pre-0.2.7 field; guilds are now remembered by id
    if self.filter.group == "returns" then self.filter.group = "items" end  -- 1.2.1: merged into Bank items
    -- v0.4.2: smaller cap so the saved variables file stays a reasonable size.
    if (sv.settingsVersion or 1) < 2 then
        if sv.maxEntries == 50000 then sv.maxEntries = EventLog.defaults.maxEntries end
        sv.settingsVersion = 2
    end
    self.seen = {}
    self:Prune()
    for _, e in ipairs(sv.entries) do
        self.seen[SeenKey(e.g, GroupOfType(e.t), e.id)] = true
        -- v0.3.2: entries logged before names were normalized lack the "@"
        if e.who and e.who ~= "" and e.who:sub(1, 1) ~= "@" then e.who = "@" .. e.who end
        if e.target and e.target ~= "" and e.target:sub(1, 1) ~= "@" then e.target = "@" .. e.target end
    end
    self:RegisterTab()
end

function EventLog:Prune()
    local cutoff = GetTimeStamp() - self.sv.keepDays * 86400
    local kept = {}
    for _, e in ipairs(self.sv.entries) do
        if e.ts >= cutoff then kept[#kept + 1] = e end
    end
    local overflow = #kept - self.sv.maxEntries
    if overflow > 0 then
        table.sort(kept, function(a, b) return a.ts < b.ts end)
        local newest = {}
        for i = overflow + 1, #kept do newest[#newest + 1] = kept[i] end
        kept = newest
    end
    self.sv.entries = kept
    self.returns = nil
end

function EventLog:GetHistoryCategories()
    if not self.sv.enabled then return {} end
    return { GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY,
             GUILD_HISTORY_EVENT_CATEGORY_ROSTER }
end

local ROSTER_TYPES
local function RosterTypes()
    if not ROSTER_TYPES then
        ROSTER_TYPES = {
            [GUILD_HISTORY_ROSTER_EVENT_JOIN] = "join",
            [GUILD_HISTORY_ROSTER_EVENT_LEAVE] = "leave",
            [GUILD_HISTORY_ROSTER_EVENT_KICKED] = "kick",
            [GUILD_HISTORY_ROSTER_EVENT_INVITE] = "invite",
            [GUILD_HISTORY_ROSTER_EVENT_PROMOTE] = "promote",
            [GUILD_HISTORY_ROSTER_EVENT_DEMOTE] = "demote",
            [GUILD_HISTORY_ROSTER_EVENT_APPLICATION_ACCEPTED] = "app_ok",
            [GUILD_HISTORY_ROSTER_EVENT_APPLICATION_DECLINED] = "app_no",
            [GUILD_HISTORY_ROSTER_EVENT_ADDED_TO_BLACKLIST] = "bl_add",
            [GUILD_HISTORY_ROSTER_EVENT_REMOVED_FROM_BLACKLIST] = "bl_remove",
        }
    end
    return ROSTER_TYPES
end

function EventLog:OnHistoryEvent(guildId, category, info)
    local key = SeenKey(guildId, GroupOfCategory(category), info.eventId)
    if self.seen[key] then return end

    local e = { g = guildId, id = info.eventId, ts = info.timestampS }
    if category == GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM then
        e.t = (info.eventType == GUILD_HISTORY_BANKED_ITEM_EVENT_REMOVED) and "item_out" or "item_in"
        e.who, e.link, e.qty = info.displayName, info.itemLink, info.quantity
    elseif category == GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY then
        if info.currencyType ~= CURT_MONEY then return end
        if info.eventType == GUILD_HISTORY_BANKED_CURRENCY_EVENT_WITHDRAWN then
            e.t = "gold_out"
        elseif info.eventType == GUILD_HISTORY_BANKED_CURRENCY_EVENT_DEPOSITED then
            e.t = "gold_in"
        else
            return -- kiosk bids, heraldry: not member activity
        end
        e.who, e.amount = info.displayName, info.amount
    elseif category == GUILD_HISTORY_EVENT_CATEGORY_ROSTER then
        e.t = RosterTypes()[info.eventType]
        if not e.t then return end
        e.who, e.target, e.rank = info.actingDisplayName, info.targetDisplayName, info.rankName
        if e.target == "" then e.target = nil end
    else
        return
    end

    self.seen[key] = true
    table.insert(self.sv.entries, e)
    self.dirty = true
    self.returns = nil
end

-- Returns ---------------------------------------------------------------------

-- Matches each item withdrawal with later deposits of the same item (same item link) by the
-- same member within returnHours, oldest withdrawal first. A deposit can cover several
-- withdrawals, and several deposits can cover one withdrawal.
-- Result: byEntry[withdrawal] = { taken, returned, lastTs }, byEntry[deposit] = { returnQty },
-- byId["guildId:eventId"] = the withdrawal's record (for Bank alerts).
function EventLog:GetReturns()
    if self.returns then return self.returns end
    local groups = {}
    for _, e in ipairs(self.sv.entries) do
        if (e.t == "item_out" or e.t == "item_in") and e.who and e.link then
            local key = tostring(e.g) .. "\t" .. e.who .. "\t" .. e.link
            local list = groups[key]
            if not list then list = {}; groups[key] = list end
            list[#list + 1] = e
        end
    end
    local byEntry, byId = {}, {}
    for _, list in pairs(groups) do
        -- Oldest first; at the same second the withdrawal comes before the deposit.
        table.sort(list, function(a, b)
            if a.ts ~= b.ts then return a.ts < b.ts end
            if a.t ~= b.t then return a.t == "item_out" end
            return a.id < b.id
        end)
        local open = {}
        for _, e in ipairs(list) do
            if e.t == "item_out" then
                local r = { taken = e.qty or 1, returned = 0 }
                byEntry[e] = r
                byId[tostring(e.g) .. ":" .. tostring(e.id)] = r
                open[#open + 1] = { ts = e.ts, r = r }
            else
                local left = e.qty or 1
                for _, o in ipairs(open) do
                    if left == 0 then break end
                    local need = o.r.taken - o.r.returned
                    if need > 0 and e.ts - o.ts <= GT:GuildSettings(self, e.g).returnHours * 3600 then
                        local give = math.min(need, left)
                        o.r.returned = o.r.returned + give
                        o.r.lastTs = e.ts
                        left = left - give
                    end
                end
                local used = (e.qty or 1) - left
                if used > 0 then byEntry[e] = { returnQty = used } end
            end
        end
    end
    self.returns = { byEntry = byEntry, byId = byId }
    return self.returns
end

-- The return record for one item withdrawal (nil if it isn't in the log).
function EventLog:GetReturnById(guildId, eventId)
    return self:GetReturns().byId[tostring(guildId) .. ":" .. tostring(eventId)]
end

-- "whole", "partial" or "none" for a withdrawal's return record.
function EventLog.ReturnState(r)
    if not r or r.returned == 0 then return "none" end
    if r.returned >= r.taken then return "whole" end
    return "partial"
end

-- Short colored note for a withdrawal: "returned after 4m" or "returned 199 of 200".
-- With showNone, a withdrawal nothing came back for gets "not returned".
function EventLog.ReturnNote(r, takenTs, showNone)
    local state = EventLog.ReturnState(r)
    if state == "whole" then
        return string.format("|c5EE6A0returned after %s|r", U.FormatDuration(r.lastTs - takenTs))
    elseif state == "partial" then
        return string.format("|cFFC857returned %d of %d|r", r.returned, r.taken)
    elseif showNone then
        return "|cFF6B86not returned|r"
    end
    return nil
end

function EventLog:OnHistoryCaughtUp()
    if self.dirty then
        self.dirty = false
        GT.Report:RefreshIfShown()
    end
end

-- Formatting -----------------------------------------------------------------

local itemNameCache = {}
local function ItemName(link)
    if not link then return "" end
    local name = itemNameCache[link]
    if not name then
        name = GetItemLinkName(link)
        name = (name and name ~= "") and zo_strformat("<<t:1>>", name) or link
        itemNameCache[link] = name
    end
    return name
end

local function Describe(e, returns, showNone)
    local label = TYPES[e.t].label
    if e.t == "item_out" or e.t == "item_in" then
        local text = string.format("%s %s %dx %s", e.who, zo_strlower(label), e.qty or 1, ItemName(e.link))
        local r = returns and returns.byEntry[e]
        if e.t == "item_out" and (r or showNone) then
            local note = EventLog.ReturnNote(r, e.ts, showNone)
            if note then text = text .. "  " .. note end
        elseif r then
            text = text .. "  |cB4B0D8(return)|r"
        end
        return text
    elseif e.t == "gold_out" or e.t == "gold_in" then
        return string.format("%s %s %s", e.who, zo_strlower(label), U.FormatGold(e.amount))
    elseif e.t == "promote" or e.t == "demote" then
        return string.format("%s %s %s to %s", e.who, zo_strlower(label), e.target or "?", e.rank or "?")
    elseif e.target then
        return string.format("%s %s %s", e.who, zo_strlower(label), e.target)
    end
    return string.format("%s %s", e.who, zo_strlower(label))
end

-- Filtering ------------------------------------------------------------------

function EventLog:GetGuildFilter()
    local ids = U.GetGuildIds()
    local wanted = self.filter.guildId
    for _, guildId in ipairs(ids) do
        if guildId == wanted then return guildId end
    end
    return nil
end

function EventLog:GetFiltered()
    local f = self.filter
    local guildId = self:GetGuildFilter()
    local since = GetTimeStamp() - RANGES[f.rangeIndex] * 86400
    local tab = GT.Report:GetTab("log")
    local search = zo_strlower(zo_strtrim(tab and tab.searchText or ""))
    local list = {}
    for _, e in ipairs(self.sv.entries) do
        local wanted = TYPES[e.t] and (f.group == "all" or TYPES[e.t].group == f.group)
        if e.ts >= since and (not guildId or e.g == guildId) and wanted then
            if search == "" or zo_strlower(e.who or ""):find(search, 1, true)
                or zo_strlower(e.target or ""):find(search, 1, true)
                or (e.link and zo_strlower(ItemName(e.link)):find(search, 1, true)) then
                list[#list + 1] = e
            end
        end
    end
    table.sort(list, function(a, b)
        if a.ts ~= b.ts then return a.ts > b.ts end
        return a.id > b.id
    end)
    return list
end

-- Per-member totals for the "By member" view.
function EventLog:GetMemberTotals(list)
    local byKey, out = {}, {}
    local returns = self:GetReturns()
    for _, e in ipairs(list) do
        if e.who and e.who ~= "" then
            local key = tostring(e.g) .. e.who
            local m = byKey[key]
            if not m then
                m = { g = e.g, who = e.who, stacksOut = 0, itemsOut = 0, itemsIn = 0, goldOut = 0, goldIn = 0, roster = 0, last = 0,
                    returnedWhole = 0, returnedPart = 0 }
                byKey[key] = m
                out[#out + 1] = m
            end
            if e.t == "item_out" then
                m.itemsOut = m.itemsOut + (e.qty or 1)
                m.stacksOut = m.stacksOut + 1
                local state = EventLog.ReturnState(returns.byEntry[e])
                if state == "whole" then m.returnedWhole = m.returnedWhole + 1
                elseif state == "partial" then m.returnedPart = m.returnedPart + 1 end
            elseif e.t == "item_in" then m.itemsIn = m.itemsIn + (e.qty or 1)
            elseif e.t == "gold_out" then m.goldOut = m.goldOut + (e.amount or 0)
            elseif e.t == "gold_in" then m.goldIn = m.goldIn + (e.amount or 0)
            else m.roster = m.roster + 1 end
            m.last = math.max(m.last, e.ts)
        end
    end
    table.sort(out, function(a, b)
        if a.stacksOut ~= b.stacksOut then return a.stacksOut > b.stacksOut end
        return a.goldOut > b.goldOut
    end)
    return out
end

-- Export ---------------------------------------------------------------------

local function Clean(value)
    return (tostring(value or ""):gsub("[\t\n]", " "))
end

function EventLog:GetExportLines()
    local list = self:GetFiltered()
    local lines = {}
    if self.filter.view == "members" then
        lines[1] = "Guild\tMember\tStacks withdrawn\tStacks returned whole\tStacks returned partly\tItems withdrawn\tItems deposited\tGold withdrawn\tGold deposited\tRoster events\tLast activity"
        for _, m in ipairs(self:GetMemberTotals(list)) do
            lines[#lines + 1] = table.concat({ Clean(U.GuildName(m.g)), Clean(m.who), m.stacksOut, m.returnedWhole, m.returnedPart, m.itemsOut, m.itemsIn,
                m.goldOut, m.goldIn, m.roster, U.FormatDate(m.last) }, "\t")
        end
    else
        lines[1] = "Date\tGuild\tEvent\tMember\tTarget\tItem\tQuantity\tGold\tRank\tReturned\tReturned by"
        local returns = self:GetReturns()
        for _, e in ipairs(list) do
            local r, returned, returnedBy = returns.byEntry[e], "", ""
            if e.t == "item_out" then
                returned = r and r.returned or 0
                if r and r.lastTs then returnedBy = U.FormatDate(r.lastTs) end
            elseif r then
                returned = "put back " .. r.returnQty
            end
            lines[#lines + 1] = table.concat({ U.FormatDate(e.ts), Clean(U.GuildName(e.g)), TYPES[e.t].label,
                Clean(e.who), Clean(e.target), Clean(e.link and ItemName(e.link) or ""),
                e.qty or "", e.amount or "", Clean(e.rank), returned, returnedBy }, "\t")
        end
    end
    return lines
end

-- Report tab -----------------------------------------------------------------

local function Cycle(list, current)
    for i, v in ipairs(list) do
        if v == current then return list[(i % #list) + 1] end
    end
    return list[1]
end

function EventLog:FilterSummary()
    local guildId = self:GetGuildFilter()
    return string.format("%s, last %d %s, %s", GROUP_LABEL[self.filter.group], RANGES[self.filter.rangeIndex],
        RANGES[self.filter.rangeIndex] == 1 and "day" or "days", guildId and U.GuildName(guildId) or "all guilds")
end

function EventLog:TabRows()
    local list = self:GetFiltered()
    local rows = {}
    if self.filter.view == "members" then
        for _, m in ipairs(self:GetMemberTotals(list)) do
            if #rows >= MAX_ROWS_SHOWN then break end
            local back = ""
            if m.returnedWhole + m.returnedPart > 0 then
                back = string.format(" |c5EE6A0(%d put back)|r", m.returnedWhole + m.returnedPart)
            end
            rows[#rows + 1] = GT.Report.AddMenu({
                text = string.format("%s  |cB4B0D8%s|r  took %d stacks%s (%d items), gave %d items   gold out %s / in %s",
                    m.who, U.GuildName(m.g), m.stacksOut, back, m.itemsOut, m.itemsIn, U.FormatGold(m.goldOut), U.FormatGold(m.goldIn)),
                tooltip = string.format("Stacks put back whole: %d\nStacks put back partly used: %d\nRoster events: %d\nLast activity: %s",
                    m.returnedWhole, m.returnedPart, m.roster, U.FormatDate(m.last)),
            }, GT.Report.ContactItems(m.who))
        end
    else
        local returns = self:GetReturns()
        local showNone = self.filter.group == "items"
        for _, e in ipairs(list) do
            if #rows >= MAX_ROWS_SHOWN then break end
            local tooltip = string.format("%s\n%s\n%s", Describe(e), U.GuildName(e.g), U.FormatDate(e.ts))
            local r = returns.byEntry[e]
            if e.t == "item_out" then
                local state = EventLog.ReturnState(r)
                if state == "whole" then
                    tooltip = tooltip .. string.format("\n|c5EE6A0Put back whole (%d) by %s|r", r.returned, U.FormatDate(r.lastTs))
                elseif state == "partial" then
                    tooltip = tooltip .. string.format("\n|cFFC857Put back %d of %d by %s, %d used or kept|r", r.returned, r.taken,
                        U.FormatDate(r.lastTs), r.taken - r.returned)
                else
                    tooltip = tooltip .. string.format("\nNot put back within %dh", GT:GuildSettings(self, e.g).returnHours)
                end
            elseif r then
                tooltip = tooltip .. string.format("\nPut back %d of an earlier withdrawal", r.returnQty)
            end
            -- Right-click: whisper or mail whoever did it, and the member it was done to.
            local items = GT.Report.ContactItems(e.who)
            if e.target and e.target ~= e.who then
                for _, item in ipairs(GT.Report.ContactItems(e.target)) do items[#items + 1] = item end
            end
            rows[#rows + 1] = GT.Report.AddMenu({
                text = string.format("|cB4B0D8%s|r  %s  |cB4B0D8%s|r", U.FormatDate(e.ts), Describe(e, returns, showNone), U.GuildName(e.g)),
                tooltip = tooltip,
            }, items)
        end
    end
    return rows
end

function EventLog:TabSummary()
    local list = self:GetFiltered()
    local count = (self.filter.view == "members") and (#self:GetMemberTotals(list) .. " members") or (#list .. " events")
    if self.filter.group == "items" and self.filter.view ~= "members" then
        local returns, taken, whole, part = self:GetReturns(), 0, 0, 0
        for _, e in ipairs(list) do
            if e.t == "item_out" then
                taken = taken + 1
                local state = EventLog.ReturnState(returns.byEntry[e])
                if state == "whole" then whole = whole + 1 elseif state == "partial" then part = part + 1 end
            end
        end
        count = string.format("%s (%d stacks taken, %d returned whole, %d partly, %d not returned)", count, taken, whole, part, taken - whole - part)
    end
    return string.format("%s: %s. Use the buttons below to filter.", self:FilterSummary(), count)
end

function EventLog:RegisterTab()
    GT.Report:RegisterTab({
        id = "log",
            GetOffText = function() return GT:FeatureOffText(self.sv.enabled, "The history log") end,
        tip = "Bank item, bank gold and roster events for all your guilds.",
        title = "History",
        searchable = true,
        searchText = self.sv.filter.search or "",
        OnSearchChanged = function(text) self.sv.filter.search = text end,
        GetSummary = function() return self:TabSummary() end,
        GetRows = function() return self:TabRows() end,
        footer = function()
            local guildId = self:GetGuildFilter()
            return {
                { label = "Show: " .. GROUP_LABEL[self.filter.group], tip = "Click to switch between all events, bank items, bank gold and roster.\nBank items marks every withdrawal returned whole, returned partly or not returned, and counts them at the top.", fn = function()
                    self.filter.group = Cycle(GROUP_FILTERS, self.filter.group)
                    GT.Report:Refresh()
                end },
                { label = "Range: " .. RANGES[self.filter.rangeIndex] .. "d", tip = "How far back to look. Click to switch between 1, 7, 30 and 90 days.", fn = function()
                    self.filter.rangeIndex = (self.filter.rangeIndex % #RANGES) + 1
                    GT.Report:Refresh()
                end },
                { label = "Guild: " .. (guildId and U.GuildName(guildId) or "All guilds"), tip = "Pick which guild to show.", fn = function(button)
                    -- Drop-down list of guilds; the choice is remembered (sv.filter).
                    local current = self:GetGuildFilter()
                    ClearMenu()
                    local function Add(label, id)
                        AddMenuItem((id == (current or 0)) and ("|cA08CFF" .. label .. "|r") or label, function()
                            self.filter.guildId = id
                            GT.Report:Refresh()
                        end)
                    end
                    Add("All guilds", 0)
                    for _, id in ipairs(U.GetGuildIds()) do Add(U.GuildName(id), id) end
                    ShowMenu(button)
                end },
                { label = self.filter.view == "members" and "View: by member" or "View: events", tip = "Click to switch between single events and totals per member.", fn = function()
                    self.filter.view = Cycle(VIEWS, self.filter.view)
                    GT.Report:Refresh()
                end },
            }
        end,
        GetExportLines = function() return self:GetExportLines() end,
    })
end

-- Settings -------------------------------------------------------------------

function EventLog:BuildSettings(options)
    local sv, defaults = self.sv, self.defaults
    options[#options + 1] = { type = "submenu", name = "History log and export", controls = {
        { type = "checkbox", name = "Keep a history log", getFunc = function() return sv.enabled end,
          setFunc = function(v) sv.enabled = v end, default = defaults.enabled, requiresReload = true },
        { type = "slider", name = "Keep events for (days)", min = 7, max = 365, step = 1,
          getFunc = function() return sv.keepDays end, setFunc = function(v) sv.keepDays = v end, default = defaults.keepDays },
        { type = "description", text = "The log is also saved in SavedVariables/FurysGuildToolset.lua after you log out or /reloadui, if you want the raw data." },
    } }
end

-- One guild's return time, inside that guild's Rules submenu (next to its bank limits).
function EventLog:BuildGuildSettings(controls, guildId)
    local g = GT:GuildSettings(self, guildId)
    controls[#controls + 1] = { type = "header", name = "Bank: put back" }
    controls[#controls + 1] = { type = "slider", name = "Count a deposit as put back within (hours)", min = 1, max = 336, step = 1,
        tooltip = "When a member deposits the same item they withdrew within this time, the withdrawal is marked as put back, whole or partly used. Stacks put back whole don't count toward bank alert limits. After changing this, click Rescan with current settings.",
        getFunc = function() return g.returnHours end,
        setFunc = function(v) g.returnHours = v; self.returns = nil; GT.Report:RefreshIfShown() end,
        default = self.defaults.returnHours }
end
