-- Trader week: weekly totals per guild for the guild store and the guild bank, lined up
-- with the guild trader week (it starts when traders change hands on Tuesday).
--
--   Sales:    items sold in the guild store, what they sold for and the tax the guild earned.
--   Trader:   what the week's trader cost: bids placed the week before (they buy this week's
--             trader), minus bids refunded at the trader change, plus traders hired outright.
--   Bank:     gold and items members put in or took out.
--   Members:  per member, what they sold, the tax that made, and what they gave or took.
--
-- All data comes from LibHistoire through its own reader ("weekly"), so on first use it reads
-- the whole look-back period without replaying old events to the alert modules. Only the
-- weekly totals are saved, not the single events.

local GT = FurysGuildToolset
local U = GT.Util

local TraderWeek = GT:RegisterModule("trader", {})
TraderWeek.historyReader = "weekly"

local WEEK = 7 * 86400
-- Used only until the game reports the trader cycle (it reports 0 while the guild system is
-- down): a Tuesday 14:00 UTC trader change.
local KNOWN_FLIP = 1794924000

TraderWeek.defaults = {
    enabled = false,     -- every feature starts turned off on a new install (Albert, 1.3.0)
    keepWeeks = 12,
    weeks = {},          -- [guildId] = { [weekStart] = week totals }
    bankGold = {},       -- [guildId] = { amount =, ts = } last count, taken when that guild bank is opened
    flipAnchor = nil,    -- end of a trader week as reported by the game
    filter = { guildId = 0, view = "weeks" },                                        -- Trader tab
    memberFilter = { guildId = 0, weekOffset = 0, sort = "value", desc = true },      -- Member sales tab
}

local WEEK_FIELDS = { "sales", "qty", "value", "tax", "goldIn", "goldInN", "goldOut", "goldOutN", "bids", "refunds",
    "hires", "heraldry", "stacksIn", "qtyIn", "stacksOut", "qtyOut", "joined", "left", "kicked" }

function TraderWeek:Initialize(sv)
    self.sv = sv
    self:Prune()
    self:RegisterTab()
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_TraderWeek", EVENT_GUILD_BANK_ITEMS_READY, function() self:CountBankGold() end)
end

function TraderWeek:OnPlayerActivated()
    self:GetFlipAnchor()
    self:NoteTraders()
end

-- Week boundaries ------------------------------------------------------------------

function TraderWeek:GetFlipAnchor()
    local _, endTime = GetGuildKioskCycleTimes()
    if endTime ~= 0 then self.sv.flipAnchor = endTime end
    return self.sv.flipAnchor or KNOWN_FLIP
end

function TraderWeek:WeekStart(ts)
    local anchor = self:GetFlipAnchor()
    return anchor + math.floor((ts - anchor) / WEEK) * WEEK
end

function TraderWeek:CurrentWeekStart()
    return self:WeekStart(GetTimeStamp())
end

local function ShortDate(ts)
    return os.date("%b %d", ts)
end

function TraderWeek:WeekLabel(start)
    local current = self:CurrentWeekStart()
    local range = ShortDate(start) .. " - " .. ShortDate(start + WEEK)
    if start == current then return "This week (" .. range .. ")" end
    if start == current - WEEK then return "Last week (" .. range .. ")" end
    if start == current + WEEK then return "Next week (" .. range .. ")" end
    return range
end

-- Data -------------------------------------------------------------------------------

function TraderWeek:Prune()
    local cutoff = self:CurrentWeekStart() - (self.sv.keepWeeks - 1) * WEEK
    for _, weeks in pairs(self.sv.weeks) do
        for start in pairs(weeks) do
            if start < cutoff then weeks[start] = nil end
        end
    end
end

function TraderWeek:GetWeek(guildId, start, create)
    local weeks = self.sv.weeks[guildId]
    if not weeks then
        if not create then return nil end
        weeks = {}
        self.sv.weeks[guildId] = weeks
    end
    local w = weeks[start]
    if not w and create then
        w = { members = {}, bidList = {}, refundList = {}, hireList = {} }
        for _, field in ipairs(WEEK_FIELDS) do w[field] = 0 end
        weeks[start] = w
    end
    return w
end

local function Member(w, name)
    local m = w.members[name]
    if not m then
        m = { s = 0, v = 0, x = 0, gi = 0, go = 0, si = 0, qi = 0, so = 0, qo = 0 }
        w.members[name] = m
    end
    return m
end

function TraderWeek:GetHistoryCategories()
    if not self.sv.enabled then return {} end
    return { GUILD_HISTORY_EVENT_CATEGORY_TRADER, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY,
             GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM, GUILD_HISTORY_EVENT_CATEGORY_ROSTER }
end

function TraderWeek:OnHistoryEvent(guildId, category, info)
    local start = self:WeekStart(info.timestampS)
    if start < self:CurrentWeekStart() - (self.sv.keepWeeks - 1) * WEEK then return end
    local t = info.eventType

    if category == GUILD_HISTORY_EVENT_CATEGORY_TRADER then
        if t ~= GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD then return end
        local w = self:GetWeek(guildId, start, true)
        w.sales = w.sales + 1
        w.qty = w.qty + info.quantity
        w.value = w.value + info.price
        w.tax = w.tax + info.tax
        local m = Member(w, info.sellerDisplayName)
        m.s, m.v, m.x = m.s + 1, m.v + info.price, m.x + info.tax

    elseif category == GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY then
        if info.currencyType ~= CURT_MONEY then return end
        -- A bid buys next week's trader, so it counts toward next week. Its refund (if the
        -- bid lost) arrives at the trader change, which is the start of that same week.
        local w = self:GetWeek(guildId, (t == GUILD_HISTORY_BANKED_CURRENCY_EVENT_KIOSK_BID) and (start + WEEK) or start, true)
        local amount = info.amount
        if t == GUILD_HISTORY_BANKED_CURRENCY_EVENT_DEPOSITED then
            w.goldIn, w.goldInN = w.goldIn + amount, w.goldInN + 1
            local m = Member(w, info.displayName)
            m.gi = m.gi + amount
        elseif t == GUILD_HISTORY_BANKED_CURRENCY_EVENT_WITHDRAWN then
            w.goldOut, w.goldOutN = w.goldOut + amount, w.goldOutN + 1
            local m = Member(w, info.displayName)
            m.go = m.go + amount
        elseif t == GUILD_HISTORY_BANKED_CURRENCY_EVENT_KIOSK_BID then
            w.bids = w.bids + amount
            table.insert(w.bidList, { k = info.kioskName, a = amount, who = info.displayName, ts = info.timestampS })
        elseif t == GUILD_HISTORY_BANKED_CURRENCY_EVENT_KIOSK_BID_REFUND then
            w.refunds = w.refunds + amount
            table.insert(w.refundList, { k = info.kioskName, a = amount, ts = info.timestampS })
        elseif t == GUILD_HISTORY_BANKED_CURRENCY_EVENT_KIOSK_PURCHASED then
            w.hires = w.hires + amount
            table.insert(w.hireList, { k = info.kioskName, a = amount, who = info.displayName, ts = info.timestampS })
        elseif t == GUILD_HISTORY_BANKED_CURRENCY_EVENT_HERALDRY_EDITED then
            w.heraldry = w.heraldry + amount
        end

    elseif category == GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM then
        local w = self:GetWeek(guildId, start, true)
        local m = Member(w, info.displayName)
        if t == GUILD_HISTORY_BANKED_ITEM_EVENT_REMOVED then
            w.stacksOut, w.qtyOut = w.stacksOut + 1, w.qtyOut + info.quantity
            m.so, m.qo = m.so + 1, m.qo + info.quantity
        else
            w.stacksIn, w.qtyIn = w.stacksIn + 1, w.qtyIn + info.quantity
            m.si, m.qi = m.si + 1, m.qi + info.quantity
        end

    elseif category == GUILD_HISTORY_EVENT_CATEGORY_ROSTER then
        local field = (t == GUILD_HISTORY_ROSTER_EVENT_JOIN and "joined") or (t == GUILD_HISTORY_ROSTER_EVENT_LEAVE and "left")
            or (t == GUILD_HISTORY_ROSTER_EVENT_KICKED and "kicked") or nil
        if not field then return end
        local w = self:GetWeek(guildId, start, true)
        w[field] = w[field] + 1
    end
    self.dirty = true
end

function TraderWeek:OnHistoryCaughtUp()
    if self.dirty then
        self.dirty = false
        GT.Report:RefreshIfShown()
    end
end

-- Remembers which trader each guild has this week (the game only tells us the current one).
function TraderWeek:NoteTraders()
    local start = self:CurrentWeekStart()
    for _, guildId in ipairs(U.GetGuildIds()) do
        local trader = GetGuildOwnedKioskInfo(guildId)
        if trader then
            self:GetWeek(guildId, start, true).trader = zo_strformat("<<1>>", trader)
        end
    end
end

-- The game only shows a guild bank's gold while that bank is open.
function TraderWeek:CountBankGold()
    local guildId = GetSelectedGuildBankId()
    if not guildId or guildId == 0 then return end
    local amount = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_GUILD_BANK)
    local now = GetTimeStamp()
    self.sv.bankGold[guildId] = { amount = amount, ts = now }
    local w = self:GetWeek(guildId, self:WeekStart(now), true)
    w.bankGold, w.bankGoldTs = amount, now
    GT.Report:RefreshIfShown()
end

local function KioskName(name)
    if not name or name == "" then return nil end
    return zo_strformat("<<1>>", name)
end

-- Sorts out the bids placed for a week's trader. A bid that got a refund (same trader) lost;
-- the rest won, once the trader change has happened. Returns:
--   { bids = { { k, a, who, ts, result = "won" | "lost" | "pending" } }, all = total bid,
--     cost = what the trader really cost (winning bids + traders hired outright),
--     won = name of the trader won or hired, pending = true while bidding is still open }
function TraderWeek:GetTraderOutcome(start, w)
    local pending = start > self:CurrentWeekStart()
    local refunds = {}
    for _, r in ipairs(w.refundList) do refunds[#refunds + 1] = r end
    local out = { bids = {}, all = w.bids, cost = w.hires, pending = pending }
    for _, b in ipairs(w.bidList) do
        local result = pending and "pending" or "won"
        if not pending then
            for i, r in ipairs(refunds) do
                if KioskName(r.k) == KioskName(b.k) then
                    table.remove(refunds, i)
                    result = "lost"
                    break
                end
            end
        end
        if result == "won" then
            out.cost = out.cost + b.a
            out.won = out.won or KioskName(b.k)
        end
        out.bids[#out.bids + 1] = { k = b.k, a = b.a, who = b.who, ts = b.ts, result = result }
    end
    for _, h in ipairs(w.hireList) do out.won = out.won or KioskName(h.k) end
    out.won = out.won or w.trader
    -- No bid of ours recorded (placed before the addon could see it) but we know the trader.
    out.costKnown = pending or #w.bidList > 0 or #w.hireList > 0 or not out.won
    return out
end

-- Guild revenue for the week: sales tax plus the gold members deposited.
local function Revenue(w)
    return w.tax + w.goldIn
end

-- Gold that left the bank for this week: member withdrawals, the trader and heraldry.
local function GoldOut(w, o)
    return w.goldOut + o.cost + w.heraldry
end

-- Income (tax and deposits) minus costs (trader, withdrawals, heraldry) for the week.
local function NetGold(w, o)
    return w.goldIn + w.tax - GoldOut(w, o)
end

local function Sellers(w)
    local n = 0
    for _, m in pairs(w.members) do
        if m.s > 0 then n = n + 1 end
    end
    return n
end

local function KioskList(list)
    local parts = {}
    for _, e in ipairs(list) do
        parts[#parts + 1] = string.format("%s %s", (e.k and e.k ~= "") and zo_strformat("<<1>>", e.k) or "?", U.FormatGold(e.a))
    end
    return table.concat(parts, ", ")
end

-- Filters ----------------------------------------------------------------------------

function TraderWeek:GetGuildFilter(filter)
    local wanted = (filter or self.sv.filter).guildId
    for _, guildId in ipairs(U.GetGuildIds()) do
        if guildId == wanted then return guildId end
    end
    return nil
end

function TraderWeek:GetGuildsShown(filter)
    local guildId = self:GetGuildFilter(filter)
    if guildId then return { guildId } end
    return U.GetGuildIds()
end

-- Newest first. withNext adds next week, which only holds bids placed for it so far.
function TraderWeek:GetWeekStarts(withNext)
    local current = self:CurrentWeekStart()
    local list = {}
    if withNext then list[1] = current + WEEK end
    for i = 0, self.sv.keepWeeks - 1 do list[#list + 1] = current - i * WEEK end
    return list
end

-- Member sales week: nil means all stored weeks (weekOffset -1).
function TraderWeek:SelectedWeekStart()
    if self.sv.memberFilter.weekOffset < 0 then return nil end
    local offset = zo_clamp(self.sv.memberFilter.weekOffset, 0, self.sv.keepWeeks - 1)
    return self:CurrentWeekStart() - offset * WEEK
end

-- Start of the oldest stored week with any data, for the guilds shown on Member sales.
function TraderWeek:OldestWeekStart()
    local oldest
    for _, guildId in ipairs(self:GetGuildsShown(self.sv.memberFilter)) do
        for start in pairs(self.sv.weeks[guildId] or {}) do
            if not oldest or start < oldest then oldest = start end
        end
    end
    return oldest
end

-- "All weeks (since Oct 06)": everything the addon has stored, which is at most the
-- "Weeks to keep" setting and never earlier than the first-run look-back.
function TraderWeek:SelectedWeekLabel()
    local start = self:SelectedWeekStart()
    if start then return self:WeekLabel(start) end
    local oldest = self:OldestWeekStart()
    return oldest and ("All weeks (since " .. ShortDate(oldest) .. ")") or "All weeks"
end

-- Rows: weeks view -------------------------------------------------------------------

local WEEK_COLUMNS = {
    { title = "Week", width = 215, tip = "Trader weeks start when traders change hands on Tuesday." },
    { title = "Trader", width = 150, tip = "The trader you won or hired for this week." },
    { title = "Sales", width = 70, tip = "Items sold in the guild store." },
    { title = "Tax earned", width = 120, tip = "The guild's share of each sale, paid into the guild bank." },
    { title = "Gold in", width = 115, tip = "Gold members deposited. Counts as guild revenue along with the tax." },
    { title = "Trader cost", width = 120, tip = "What this week's trader really cost: the winning bid (bids that lost are refunded) plus any trader hired outright. Hover a week for every bid." },
    { title = "Revenue - cost", width = 130, tip = "Revenue (tax earned plus gold members deposited) minus the trader cost. Green when revenue paid for the trader, red when it didn't." },
    { title = "Gold out", width = 115, tip = "Everything that left the bank for this week: the trader cost, heraldry and gold members withdrew." },
}

local function GoldCell(amount)
    if amount == 0 then return "|c8A86B00|r" end
    return U.FormatGold(amount)
end

local function Percent(part, whole)
    if whole <= 0 then return nil end
    return math.floor(part * 100 / whole + 0.5)
end

-- Green when the tax covered the cost, red when it fell short.
local function BalanceCell(tax, cost)
    local diff = tax - cost
    if cost == 0 and tax == 0 then return "|c8A86B00|r" end
    local pct = Percent(tax, cost)
    local text = (diff >= 0 and "+" or "-") .. U.FormatGold(math.abs(diff)) .. (pct and string.format(" (%d%%)", pct) or "")
    return (diff >= 0 and "|c5EE6A0" or "|cFF6B86") .. text .. "|r"
end

local RESULT_LABEL = { won = "won", lost = "lost, refunded", pending = "bidding open" }

local function BidLines(o)
    local parts = {}
    for _, b in ipairs(o.bids) do
        parts[#parts + 1] = string.format("  %s %s (%s%s)", KioskName(b.k) or "?", U.FormatGold(b.a), RESULT_LABEL[b.result],
            (b.who and b.who ~= "") and (", " .. b.who) or "")
    end
    return parts
end

function TraderWeek:WeekTooltip(guildId, start, w, o, prev)
    local lines = { U.GuildName(guildId) .. ", " .. self:WeekLabel(start) }
    lines[#lines + 1] = "Trader: " .. (o.won or "unknown") .. (o.pending and " (bidding still open)" or "")
    lines[#lines + 1] = string.format("Sales: %d (%d items) by %d sellers, sold for %s, tax %s", w.sales, w.qty, Sellers(w),
        U.FormatGold(w.value), U.FormatGold(w.tax))
    if #o.bids > 0 then
        lines[#lines + 1] = string.format("Bids for this week's trader, %s in all:", U.FormatGold(o.all))
        for _, line in ipairs(BidLines(o)) do lines[#lines + 1] = line end
    end
    if #w.hireList > 0 then lines[#lines + 1] = "Hired outright: " .. KioskList(w.hireList) end
    if o.pending then
        lines[#lines + 1] = "Trader cost: known after the trader change"
    elseif o.costKnown then
        lines[#lines + 1] = string.format("Trader cost: %s. Revenue covered %s of it.", U.FormatGold(o.cost),
            Percent(Revenue(w), o.cost) and (Percent(Revenue(w), o.cost) .. "%") or "all")
    else
        lines[#lines + 1] = "Trader cost: unknown (the bid was placed before the addon could see it)"
    end
    lines[#lines + 1] = string.format("Revenue: %s (tax %s + member deposits %s)", U.FormatGold(Revenue(w)), U.FormatGold(w.tax),
        U.FormatGold(w.goldIn))
    if prev and not o.pending then
        local now, before = Revenue(w), Revenue(prev)
        local change = Percent(now - before, before)
        lines[#lines + 1] = string.format("Revenue vs the week before: %s%s", (now >= before) and "+" or "-",
            U.FormatGold(math.abs(now - before))) .. (change and string.format(" (%+d%%)", change) or "")
    end
    if w.heraldry > 0 then lines[#lines + 1] = "Heraldry: " .. U.FormatGold(w.heraldry) end
    lines[#lines + 1] = string.format("Gold: %s in (%d deposits), %s withdrawn by members (%d withdrawals)", U.FormatGold(w.goldIn), w.goldInN,
        U.FormatGold(w.goldOut), w.goldOutN)
    lines[#lines + 1] = string.format("Gold out in all (trader, heraldry, withdrawals): %s", U.FormatGold(GoldOut(w, o)))
    lines[#lines + 1] = string.format("Items: %d stacks in (%d items), %d stacks out (%d items)", w.stacksIn, w.qtyIn, w.stacksOut, w.qtyOut)
    lines[#lines + 1] = string.format("Net (tax and deposits minus gold out): %s", U.FormatGold(NetGold(w, o)))
    if w.bankGold then lines[#lines + 1] = string.format("Bank gold: %s (counted %s)", U.FormatGold(w.bankGold), U.FormatDate(w.bankGoldTs)) end
    lines[#lines + 1] = string.format("Roster: %d joined, %d left, %d kicked", w.joined, w.left, w.kicked)
    return table.concat(lines, "\n")
end

function TraderWeek:GetWeekRows()
    local rows = {}
    local guilds = self:GetGuildsShown()
    local showGuild = #guilds > 1
    for _, guildId in ipairs(guilds) do
        for _, start in ipairs(self:GetWeekStarts(true)) do
            local w = self:GetWeek(guildId, start)
            if w then
                local o = self:GetTraderOutcome(start, w)
                local label = self:WeekLabel(start)
                if showGuild then label = U.GuildName(guildId) .. ": " .. label end
                local costCell, balanceCell
                if o.pending then
                    costCell, balanceCell = "|cB4B0D8bidding|r", ""
                elseif not o.costKnown then
                    costCell, balanceCell = "|cB4B0D8?|r", ""
                else
                    costCell, balanceCell = GoldCell(o.cost), BalanceCell(Revenue(w), o.cost)
                end
                rows[#rows + 1] = {
                    cells = { label, o.won or "|cB4B0D8-|r", tostring(w.sales), GoldCell(w.tax), GoldCell(w.goldIn), costCell,
                              balanceCell, GoldCell(GoldOut(w, o)) },
                    tooltip = self:WeekTooltip(guildId, start, w, o, self:GetWeek(guildId, start - WEEK)),
                }
            end
        end
    end
    return rows
end

-- Rows: members view -----------------------------------------------------------------

local MEMBER_COLUMNS = {
    { title = "Member", width = 236, sort = "name" },
    { title = "Sales", width = 110, sort = "sales", tip = "Items this member sold in the guild store." },
    { title = "Sold for", width = 125, sort = "value", tip = "Total price of what they sold." },
    { title = "Tax made", width = 115, sort = "tax", tip = "Tax the guild earned from their sales." },
    { title = "Gold given", width = 120, sort = "goldIn", tip = "Gold they deposited in the guild bank." },
    { title = "Items given", width = 115, sort = "stacksIn", tip = "Stacks they deposited (items in the hover text)." },
    { title = "Gold taken", width = 115, sort = "goldOut", tip = "Gold they withdrew." },
    { title = "Items taken", width = 110, sort = "stacksOut", tip = "Stacks they withdrew." },
}

local SORT_VALUE = {
    sales = function(m) return m.s end,
    value = function(m) return m.v end,
    tax = function(m) return m.x end,
    goldIn = function(m) return m.gi end,
    stacksIn = function(m) return m.si end,
    goldOut = function(m) return m.go end,
    stacksOut = function(m) return m.so end,
}

local MEMBER_FIELDS = { "s", "v", "x", "gi", "go", "si", "qi", "so", "qo" }

function TraderWeek:GetMemberList()
    local start = self:SelectedWeekStart()
    local list = {}
    local guilds = self:GetGuildsShown(self.sv.memberFilter)
    for _, guildId in ipairs(guilds) do
        if start then
            local w = self:GetWeek(guildId, start)
            if w then
                for name, m in pairs(w.members) do
                    list[#list + 1] = { g = guildId, name = name, m = m }
                end
            end
        else
            -- All weeks: add up each member's totals over every stored week.
            local byName = {}
            for _, w in pairs(self.sv.weeks[guildId] or {}) do
                for name, m in pairs(w.members) do
                    local total = byName[name]
                    if not total then
                        total = {}
                        for _, field in ipairs(MEMBER_FIELDS) do total[field] = 0 end
                        byName[name] = total
                        list[#list + 1] = { g = guildId, name = name, m = total }
                    end
                    for _, field in ipairs(MEMBER_FIELDS) do total[field] = total[field] + m[field] end
                end
            end
        end
    end
    local f = self.sv.memberFilter
    local get = SORT_VALUE[f.sort]
    table.sort(list, function(a, b)
        if get then
            local va, vb = get(a.m), get(b.m)
            if va ~= vb then
                if f.desc then return va > vb end
                return va < vb
            end
        elseif a.name ~= b.name then
            if f.desc then return zo_strlower(a.name) > zo_strlower(b.name) end
            return zo_strlower(a.name) < zo_strlower(b.name)
        end
        if a.name ~= b.name then return a.name < b.name end
        return a.g < b.g
    end)
    return list, #guilds > 1
end

-- Sales rank by Sold for within each guild, counting only members who sold something.
local function RankSellers(list)
    local byGuild = {}
    for _, e in ipairs(list) do
        if e.m.v > 0 then
            local g = byGuild[e.g]
            if not g then g = {}; byGuild[e.g] = g end
            g[#g + 1] = e
        end
    end
    for _, g in pairs(byGuild) do
        table.sort(g, function(a, b) return a.m.v > b.m.v end)
        for i, e in ipairs(g) do
            e.rank = (i > 1 and g[i - 1].m.v == e.m.v) and g[i - 1].rank or i
            e.sellers = #g
        end
    end
end

-- Congratulations mail for a seller ------------------------------------------------

local function Ordinal(n)
    local tens = n % 100
    if tens >= 11 and tens <= 13 then return n .. "th" end
    local last = n % 10
    if last == 1 then return n .. "st" end
    if last == 2 then return n .. "nd" end
    if last == 3 then return n .. "rd" end
    return n .. "th"
end

-- "this week", "last week", "the week of Nov 10" or "of all time".
function TraderWeek:SelectedPeriodText()
    local offset = self.sv.memberFilter.weekOffset
    if offset < 0 then return "of all time" end
    if offset == 0 then return "this week" end
    if offset == 1 then return "last week" end
    return "the week of " .. ShortDate(self:SelectedWeekStart())
end

-- e: a Member sales entry with rank (by Sold for, within its guild) and sellers (how many sold).
-- The mail is only filled in; nothing is sent until you press Send.
function TraderWeek:CongratsMail(e)
    local m, rank, guild = e.m, e.rank, U.GuildName(e.g)
    local period = self:SelectedPeriodText()
    local place = rank == 1 and "top seller" or (Ordinal(rank) .. " best seller")
    local subject = rank == 1 and ("Congrats, our #1 seller " .. period .. "!")
        or ("Congrats, our #" .. rank .. " seller " .. period .. "!")
    local where = "our " .. place .. " " .. period .. " in " .. guild
        .. (e.sellers > 1 and (", out of " .. e.sellers .. " members who sold") or "")
    local opener
    if rank == 1 then
        opener = "Wow, what a run! You were " .. where .. "."
    elseif rank <= 3 then
        opener = "You made the podium! You were " .. where .. "."
    elseif rank <= 10 then
        opener = "Top ten! You were " .. where .. "."
    else
        opener = "You were " .. where .. ", and every one of those sales counts."
    end
    local body = string.format("Congratulations, %s!\n\n%s\n\nYou sold %s %s for %s, and that brought the guild %s in tax. That gold goes straight into keeping our trader up, so the whole guild wins with you.\n\nThank you for all the effort you put in. Members like you are what make %s great. Keep it up, we are cheering you on!\n\n%s",
        e.name, opener, ZO_CommaDelimitNumber(m.s), m.s == 1 and "listing" or "listings", U.FormatGold(m.v), U.FormatGold(m.x),
        guild, GetDisplayName())
    return subject, body
end

-- Guild chat shout-outs ------------------------------------------------------------
-- The addon can't send chat itself: it puts the text in the guild chat box and you press
-- Enter. A long top ten is split into parts; each part goes in the box after you send the one
-- before it.

local MAX_CHAT = 350
local CHAT_EVENT_NAME = "FurysGuildToolset_TraderWeekChat"

local function GuildChannel(guildId)
    for i = 1, GetNumGuilds() do
        if GetGuildId(i) == guildId then return _G["CHAT_CHANNEL_GUILD_" .. i] end
    end
end

function TraderWeek:NextChatPart()
    local post = self.chatPost
    local text = table.remove(post.parts, 1)
    if #post.parts == 0 then
        self.chatPost = nil
        EVENT_MANAGER:UnregisterForEvent(CHAT_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL)
    end
    StartChatInput(text, post.channel)
    if post.total > 1 then
        U.Print("Part %d of %d is in the guild chat box. Press Enter to send it%s.", post.total - #post.parts, post.total,
            #post.parts > 0 and ", and the next part follows" or "")
    else
        U.Print("Your post is in the guild chat box. Press Enter to send it.")
    end
end

function TraderWeek:PostToGuild(guildId, parts)
    if CHAT_SYSTEM:IsTextEntryOpen() then
        U.Print("You're typing in chat. Send or close that first, then try again.")
        return
    end
    self.chatPost = { channel = GuildChannel(guildId), parts = parts, total = #parts }
    EVENT_MANAGER:UnregisterForEvent(CHAT_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL)
    if #parts > 1 then
        local me = GetDisplayName()
        EVENT_MANAGER:RegisterForEvent(CHAT_EVENT_NAME, EVENT_CHAT_MESSAGE_CHANNEL,
            function(_, channelType, _, _, _, fromDisplayName)
                local post = self.chatPost
                if post and channelType == post.channel and fromDisplayName == me then
                    zo_callLater(function()
                        if self.chatPost == post and not CHAT_SYSTEM:IsTextEntryOpen() then self:NextChatPart() end
                    end, 300)
                end
            end)
    end
    self:NextChatPart()
end

function TraderWeek:ShoutOutText(e)
    local m = e.m
    local period = self:SelectedPeriodText()
    local place = e.rank == 1 and "our #1 seller" or ("our #" .. e.rank .. " seller")
    return string.format("Big shout-out to %s, %s %s with %s %s worth %s, bringing the guild %s in tax! Thank you for keeping our trader thriving!",
        e.name, place, period, ZO_CommaDelimitNumber(m.s), m.s == 1 and "sale" or "sales", U.FormatGold(m.v), U.FormatGold(m.x))
end

-- Top ten sellers of one guild for the selected week (or all weeks), split into chat-sized parts.
function TraderWeek:TopTenParts(guildId)
    local list = self:GetMemberList()
    RankSellers(list)
    local top = {}
    for _, e in ipairs(list) do
        if e.g == guildId and e.rank and e.rank <= 10 then top[#top + 1] = e end
    end
    if #top == 0 then return nil end
    table.sort(top, function(a, b) return a.m.v > b.m.v end)
    local entries = {}
    for _, e in ipairs(top) do
        entries[#entries + 1] = string.format("#%d %s %s", e.rank, e.name, U.FormatGold(e.m.v))
    end
    local header = "Top sellers " .. self:SelectedPeriodText() .. ": "
    local closing = " Congratulations, and thank you all for keeping our trader busy!"
    local parts, line = {}, header
    for i, entry in ipairs(entries) do
        local sep = (line == header or line == "") and "" or ", "
        if #line + #sep + #entry > MAX_CHAT then
            parts[#parts + 1] = line .. ","
            line, sep = "", ""
        end
        line = line .. sep .. entry
    end
    if #line + #closing <= MAX_CHAT then
        parts[#parts + 1] = line .. "." .. closing
    else
        parts[#parts + 1] = line .. "."
        parts[#parts + 1] = zo_strtrim(closing)
    end
    return parts
end

function TraderWeek:PostTopTen(guildId)
    local parts = self:TopTenParts(guildId)
    if not parts then
        U.Print("Nobody in %s sold anything %s.", U.GuildName(guildId), self:SelectedPeriodText())
        return
    end
    self:PostToGuild(guildId, parts)
end

-- Right-click menu on a member: start a whisper or a mail to them. A member who sold gets
-- a congratulations mail filled in. Nothing is sent until you press Enter or Send.
function TraderWeek:ContactMenu(control, e)
    ClearMenu()
    AddMenuItem("Whisper " .. e.name, function() GT.Actions.Warn(e.name, "", "", "whisper") end)
    AddMenuItem("Mail " .. e.name, function()
        if e.rank then
            local subject, body = self:CongratsMail(e)
            GT.Actions.Warn(e.name, subject, body, "mail")
        else
            GT.Actions.Warn(e.name, "", "", "mail")
        end
    end)
    AddMenuItem("Copy " .. e.name, function() GT.Report:ShowCopy(e.name) end)
    if e.rank then
        AddMenuItem("Shout out " .. e.name .. " in guild chat", function()
            self:PostToGuild(e.g, { self:ShoutOutText(e) })
        end)
    end
    ShowMenu(control)
end

function TraderWeek:GetMemberRows()
    local rows = {}
    local list, showGuild = self:GetMemberList()
    RankSellers(list)
    for _, e in ipairs(list) do
        local m = e.m
        rows[#rows + 1] = {
            cells = { showGuild and (e.name .. "  |cB4B0D8" .. U.GuildName(e.g) .. "|r") or e.name, tostring(m.s), GoldCell(m.v),
                      GoldCell(m.x), GoldCell(m.gi), tostring(m.si), GoldCell(m.go), tostring(m.so) },
            tooltip = string.format("%s, %s\nSold %d listings for %s (tax %s)\nGave %s and %d stacks (%d items)\nTook %s and %d stacks (%d items)\n|cB4B0D8%s|r",
                e.name, U.GuildName(e.g), m.s, U.FormatGold(m.v), U.FormatGold(m.x), U.FormatGold(m.gi), m.si, m.qi,
                U.FormatGold(m.go), m.so, m.qo,
                e.rank and ("Seller #" .. e.rank .. ". Right-click to whisper, mail " .. e.name .. " a congratulations note, or shout them out in guild chat.")
                    or ("Right-click to whisper or mail " .. e.name .. ".")),
            OnRightClick = function(control) self:ContactMenu(control, e) end,
        }
    end
    return rows
end

-- Rows: traders view -----------------------------------------------------------------
-- One row per trader you held, for as many weeks in a row as you held it, so you can see
-- whether the revenue at each trader (tax plus member deposits) paid for it, and compare one
-- trader with the next.

local TRADER_COLUMNS = {
    { title = "Trader", width = 200, tip = "The trader you won or hired." },
    { title = "Weeks", width = 175, tip = "The trader weeks you held it, in a row." },
    { title = "Cost", width = 120, tip = "What those weeks cost: the winning bids plus traders hired outright." },
    { title = "Revenue", width = 120, tip = "Sales tax plus gold members deposited in those weeks." },
    { title = "Revenue - cost", width = 140, tip = "Revenue minus cost, and how much of the cost the revenue covered." },
    { title = "Sales / week", width = 95, tip = "Average items sold per week." },
    { title = "Revenue / wk", width = 110, tip = "Average revenue (tax plus member deposits) per week." },
    { title = "vs before", width = 100, tip = "Revenue per week compared with the trader before it." },
}

function TraderWeek:GetStints(guildId)
    local stints = {}
    local starts = self:GetWeekStarts()
    for i = #starts, 1, -1 do   -- oldest first
        local start = starts[i]
        local w = self:GetWeek(guildId, start)
        if w then
            local o = self:GetTraderOutcome(start, w)
            local last = stints[#stints]
            local name = o.won or "No trader"
            if not last or last.name ~= name or last.last ~= start - WEEK then
                last = { g = guildId, name = name, first = start, last = start, weeks = 0, cost = 0, tax = 0, goldIn = 0, sales = 0, value = 0, costKnown = true }
                stints[#stints + 1] = last
            end
            last.last = start
            last.weeks = last.weeks + 1
            last.cost = last.cost + o.cost
            last.tax = last.tax + w.tax
            last.goldIn = last.goldIn + w.goldIn
            last.rev = last.tax + last.goldIn
            last.sales = last.sales + w.sales
            last.value = last.value + w.value
            if not o.costKnown then last.costKnown = false end
        end
    end
    for i, st in ipairs(stints) do st.prev = stints[i - 1] end
    return stints
end

function TraderWeek:GetTraderRows()
    local rows = {}
    local guilds = self:GetGuildsShown()
    local showGuild = #guilds > 1
    for _, guildId in ipairs(guilds) do
        local stints = self:GetStints(guildId)
        for i = #stints, 1, -1 do   -- newest first
            local st = stints[i]
            local perWeek = math.floor(st.rev / st.weeks)
            local vs = ""
            if st.prev then
                local prevPerWeek = st.prev.rev / st.prev.weeks
                local pct = Percent(perWeek - prevPerWeek, prevPerWeek)
                vs = pct and string.format("%s%+d%%|r", pct >= 0 and "|c5EE6A0" or "|cFF6B86", pct) or ""
            end
            local range = ShortDate(st.first) .. " - " .. ShortDate(st.last + WEEK)
            local tip = { string.format("%s, %s: %d %s", U.GuildName(guildId), st.name, st.weeks, st.weeks == 1 and "week" or "weeks"),
                string.format("Sold %d items for %s, tax %s", st.sales, U.FormatGold(st.value), U.FormatGold(st.tax)),
                string.format("Revenue %s (tax %s + member deposits %s)", U.FormatGold(st.rev), U.FormatGold(st.tax), U.FormatGold(st.goldIn)),
                st.costKnown and string.format("Cost %s", U.FormatGold(st.cost)) or "Cost: some weeks' bids were placed before the addon could see them" }
            if st.prev then
                tip[#tip + 1] = string.format("Before: %s, %s revenue per week over %d %s", st.prev.name,
                    U.FormatGold(math.floor(st.prev.rev / st.prev.weeks)), st.prev.weeks, st.prev.weeks == 1 and "week" or "weeks")
            end
            rows[#rows + 1] = {
                cells = { showGuild and (st.name .. "  |cB4B0D8" .. U.GuildName(guildId) .. "|r") or st.name,
                          string.format("%s (%d)", range, st.weeks), st.costKnown and GoldCell(st.cost) or "|cB4B0D8?|r",
                          GoldCell(st.rev), st.costKnown and BalanceCell(st.rev, st.cost) or "",
                          tostring(math.floor(st.sales / st.weeks)), GoldCell(perWeek), vs },
                tooltip = table.concat(tip, "\n"),
            }
        end
    end
    return rows
end

-- Summary ----------------------------------------------------------------------------

function TraderWeek:GetSummary()
    self:NoteTraders()
    local guildId = self:GetGuildFilter()
    local nextFlip = self:CurrentWeekStart() + WEEK
    local flip = string.format("Next trader change %s (in %s).", os.date("%a %b %d %H:%M", nextFlip), U.FormatDuration(nextFlip - GetTimeStamp()))
    if not guildId then
        return "All guilds. " .. flip .. " Pick a guild below to see its trader and bank gold."
    end
    local trader = GetGuildOwnedKioskInfo(guildId)
    local gold = self.sv.bankGold[guildId]
    local view = self.sv.filter.view == "traders" and " Each trader you held, and whether its revenue (tax plus member deposits) paid for it." or ""
    return string.format("%s: trader %s. Bank gold %s.%s %s", U.GuildName(guildId),
        trader and zo_strformat("<<1>>", trader) or "none this week",
        gold and string.format("%s (counted %s)", U.FormatGold(gold.amount), U.FormatAgo(gold.ts)) or "unknown until you open this guild bank",
        view, flip)
end

function TraderWeek:GetMemberSummary()
    local guildId = self:GetGuildFilter(self.sv.memberFilter)
    local list = self:GetMemberList()
    return string.format("%s, %s: %d %s sold, gave or took something. Click a column header to sort, right-click a member to whisper or mail them.",
        guildId and U.GuildName(guildId) or "All guilds", self:SelectedWeekLabel(), #list, #list == 1 and "member" or "members")
end

-- Export -----------------------------------------------------------------------------

local function Clean(value)
    return (tostring(value or ""):gsub("[\t\n]", " "))
end

function TraderWeek:GetMemberExportLines()
    local lines = {}
    do
        local start = self:SelectedWeekStart()
        local weekText = start and U.FormatDate(start) or self:SelectedWeekLabel()
        lines[1] = "Guild\tWeek start\tMember\tSales\tSold for\tTax made\tGold given\tStacks given\tItems given\tGold taken\tStacks taken\tItems taken"
        for _, e in ipairs(self:GetMemberList()) do
            local m = e.m
            lines[#lines + 1] = table.concat({ Clean(U.GuildName(e.g)), weekText, Clean(e.name), m.s, m.v, m.x,
                m.gi, m.si, m.qi, m.go, m.so, m.qo }, "\t")
        end
        return lines
    end
end

function TraderWeek:GetExportLines()
    local lines = {}
    if self.sv.filter.view == "traders" then
        lines[1] = "Guild\tTrader\tFirst week\tLast week ends\tWeeks\tCost\tCost complete\tSales\tSold for\tTax earned\tGold deposited\tRevenue (tax + deposits)\tRevenue minus cost\tRevenue covered %\tRevenue per week\tPrevious trader\tPrevious revenue per week"
        for _, guildId in ipairs(self:GetGuildsShown()) do
            for _, st in ipairs(self:GetStints(guildId)) do
                lines[#lines + 1] = table.concat({ Clean(U.GuildName(guildId)), Clean(st.name), U.FormatDate(st.first), U.FormatDate(st.last + WEEK),
                    st.weeks, st.cost, st.costKnown and "yes" or "no", st.sales, st.value, st.tax, st.goldIn, st.rev, st.rev - st.cost,
                    Percent(st.rev, st.cost) or "", math.floor(st.rev / st.weeks), st.prev and Clean(st.prev.name) or "",
                    st.prev and math.floor(st.prev.rev / st.prev.weeks) or "" }, "\t")
            end
        end
        return lines
    end
    lines[1] = table.concat({ "Guild", "Week start", "Week end", "Trader", "Sales", "Items sold", "Sellers", "Sold for", "Tax earned",
        "All bids for this week", "Bids refunded", "Hired outright", "Trader cost (winning bid + hires)", "Cost complete",
        "Revenue (tax + deposits)", "Revenue minus trader cost", "Revenue covered %", "Bid details", "Heraldry", "Gold deposited",
        "Deposits", "Gold withdrawn by members", "Withdrawals", "Gold out in all", "Net (income minus gold out)", "Bank gold counted", "Stacks deposited",
        "Items deposited", "Stacks withdrawn", "Items withdrawn", "Joined", "Left", "Kicked", "Top sellers" }, "\t")
    for _, guildId in ipairs(self:GetGuildsShown()) do
        for _, start in ipairs(self:GetWeekStarts(true)) do
            local w = self:GetWeek(guildId, start)
            if w then
                local sellers = {}
                for name, m in pairs(w.members) do
                    if m.s > 0 then sellers[#sellers + 1] = { name = name, v = m.v } end
                end
                table.sort(sellers, function(a, b) return a.v > b.v end)
                local top = {}
                for i = 1, math.min(5, #sellers) do top[i] = sellers[i].name .. " " .. sellers[i].v end
                local o = self:GetTraderOutcome(start, w)
                local bidDetails = {}
                for _, b in ipairs(o.bids) do
                    bidDetails[#bidDetails + 1] = string.format("%s %d %s", KioskName(b.k) or "?", b.a, RESULT_LABEL[b.result])
                end
                if #w.hireList > 0 then bidDetails[#bidDetails + 1] = "hired: " .. KioskList(w.hireList) end
                local known = o.costKnown and not o.pending
                lines[#lines + 1] = table.concat({ Clean(U.GuildName(guildId)), U.FormatDate(start), U.FormatDate(start + WEEK),
                    Clean(o.won), w.sales, w.qty, Sellers(w), w.value, w.tax, w.bids, w.refunds, w.hires, o.pending and "" or o.cost,
                    o.pending and "bidding open" or (o.costKnown and "yes" or "no"), Revenue(w), known and (Revenue(w) - o.cost) or "",
                    known and (Percent(Revenue(w), o.cost) or "") or "",
                    Clean(table.concat(bidDetails, "; ")), w.heraldry, w.goldIn, w.goldInN, w.goldOut, w.goldOutN, GoldOut(w, o), NetGold(w, o),
                    w.bankGold or "", w.stacksIn, w.qtyIn, w.stacksOut, w.qtyOut, w.joined, w.left, w.kicked,
                    Clean(table.concat(top, ", ")) }, "\t")
            end
        end
    end
    return lines
end

-- Tab ----------------------------------------------------------------------------------

local VIEW_NEXT = { weeks = "traders", traders = "weeks" }

-- Guild drop-down for a tab's footer; the choice is kept in that tab's filter.
local function GuildButton(self, f)
    local guildId = self:GetGuildFilter(f)
    return { label = "Guild: " .. (guildId and U.GuildName(guildId) or "All guilds"), tip = "Pick which guild to show.", fn = function(button)
        ClearMenu()
        local function Add(label, id)
            AddMenuItem((id == (guildId or 0)) and ("|cA08CFF" .. label .. "|r") or label, function()
                f.guildId = id
                GT.Report:Refresh()
            end)
        end
        Add("All guilds", 0)
        for _, id in ipairs(U.GetGuildIds()) do Add(U.GuildName(id), id) end
        ShowMenu(button)
    end }
end

function TraderWeek:TabRows()
    if self.sv.filter.view == "traders" then return self:GetTraderRows() end
    return self:GetWeekRows()
end

function TraderWeek:MemberTabSort(mf, key)
    if mf.sort == key then
        mf.desc = not mf.desc
    else
        mf.sort, mf.desc = key, key ~= "name"
    end
end

function TraderWeek:RegisterTab()
    local f = self.sv.filter
    if f.view ~= "traders" then f.view = "weeks" end   -- 0.4.14 and older also had a members view here
    f.weekOffset, f.sort, f.desc = nil, nil, nil
    GT.Report:RegisterTab({
        id = "trader",
            GetOffText = function() return GT:FeatureOffText(self.sv.enabled, "Trader and sales tracking") end,
        title = "Trader",
        about = {
            "Shows what each week's guild trader cost, every bid, and whether sales tax and member deposits paid for it.",
            "Totals are per trader week, from the guild history LibHistoire has saved. The first weeks fill in a little after you turn it on.",
        },
        emptyText = "No trader weeks yet. They fill in as guild history loads.",
        tip = "Trader management: what each week's trader cost, every bid, and whether revenue (tax plus member deposits) paid for it.",
        columns = function() return f.view == "traders" and TRADER_COLUMNS or WEEK_COLUMNS end,
        GetSummary = function() return self:GetSummary() end,
        GetRows = function() return self:TabRows() end,
        footer = function()
            return {
                GuildButton(self, f),
                { label = f.view == "traders" and "View: traders" or "View: weeks",
                  tip = "Click to switch between totals per trader week and each trader you held (did its revenue pay for it).", fn = function()
                    f.view = VIEW_NEXT[f.view] or "weeks"
                    GT.Report:Refresh()
                end },
            }
        end,
        GetExportLines = function() return self:GetExportLines() end,
    })

    local mf = self.sv.memberFilter
    GT.Report:RegisterTab({
        id = "sales",
        noMenuHint = true,
            GetOffText = function() return GT:FeatureOffText(self.sv.enabled, "Trader and sales tracking") end,
        title = "Member sales",
        about = {
            "Shows, for one trader week, what each member sold in the guild store, the tax that earned, and the gold and items they gave or took.",
            "Click a column header to sort. Right-click a member to whisper or mail them.",
        },
        emptyText = "No sales or bank activity for this week yet.",
        tip = "Per member for one trader week: what they sold in the guild store, the tax that earned, and the gold and items they gave or took. Right-click a member to whisper or mail them.",
        columns = MEMBER_COLUMNS,
        sortKey = function() return mf.sort, mf.desc end,
        OnSort = function(key) self:MemberTabSort(mf, key) end,
        GetSummary = function() return self:GetMemberSummary() end,
        GetRows = function() return self:GetMemberRows() end,
        footer = function()
            local selected = self:SelectedWeekStart()
            return {
                GuildButton(self, mf),
                { label = "Week: " .. (selected and ShortDate(selected) or "All"),
                  tip = function()
                      return string.format("Pick which trader week to show, or All weeks for each member's totals over everything stored. The addon keeps %d weeks (\"Weeks to keep\" in settings) and the first time it could only read back as far as the first-run look-back.", self.sv.keepWeeks)
                  end, fn = function(button)
                    ClearMenu()
                    local allLabel = self:SelectedWeekLabel()
                    if selected then
                        local oldest = self:OldestWeekStart()
                        allLabel = oldest and ("All weeks (since " .. ShortDate(oldest) .. ")") or "All weeks"
                    end
                    AddMenuItem(selected and allLabel or ("|cA08CFF" .. allLabel .. "|r"), function()
                        mf.weekOffset = -1
                        GT.Report:Refresh()
                    end)
                    for i, start in ipairs(self:GetWeekStarts()) do
                        local label = self:WeekLabel(start)
                        AddMenuItem((start == selected) and ("|cA08CFF" .. label .. "|r") or label, function()
                            mf.weekOffset = i - 1
                            GT.Report:Refresh()
                        end)
                    end
                    ShowMenu(button)
                end },
                { label = "Post top ten",
                  tip = function()
                      return "Put the top ten sellers " .. self:SelectedPeriodText() .. " (by Sold for) in the guild chat box, ready for you to press Enter. A long list is split into parts: each part follows after you send the one before. With more than one guild shown, pick the guild."
                  end, fn = function(button)
                    local guilds = self:GetGuildsShown(mf)
                    if #guilds == 1 then
                        self:PostTopTen(guilds[1])
                        return
                    end
                    ClearMenu()
                    for _, guildId in ipairs(guilds) do
                        AddMenuItem(U.GuildName(guildId), function() self:PostTopTen(guildId) end)
                    end
                    ShowMenu(button)
                end },
            }
        end,
        GetExportLines = function() return self:GetMemberExportLines() end,
    })
end

-- Settings -----------------------------------------------------------------------------

function TraderWeek:BuildSettings(options)
    local sv, defaults = self.sv, self.defaults
    options[#options + 1] = { type = "submenu", name = "Trader week totals", controls = {
        { type = "checkbox", name = "Keep weekly trader and bank totals", getFunc = function() return sv.enabled end,
          tooltip = "Guild store sales and tax, trader bids, and bank gold and item donations per trader week, for every guild.",
          setFunc = function(v) sv.enabled = v end, default = defaults.enabled, requiresReload = true },
        { type = "slider", name = "Weeks to keep", min = 4, max = 52, step = 1,
          tooltip = "How many trader weeks to keep, including this one. The first time, the addon can only read as far back as the first-run look-back setting.",
          getFunc = function() return sv.keepWeeks end, setFunc = function(v) sv.keepWeeks = v; self:Prune() end, default = defaults.keepWeeks },
    } }
end
