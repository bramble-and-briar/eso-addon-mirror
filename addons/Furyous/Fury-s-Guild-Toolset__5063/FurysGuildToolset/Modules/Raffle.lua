-- Raffle: sells raffle tickets for gold deposited into a guild bank and/or mailed to you, then
-- draws the winners. The guild is optional, so groups that aren't guilds (housing, fashion)
-- can run a mail-only raffle.
--
-- Tickets: the amount alone decides (Albert, 1.6.1). Every gold deposit into the raffle guild's
-- bank, and every mail with gold attached (optionally only with a word in the subject), between
-- the start and the end of the sale buys amount / ticket price tickets, rounded down. The
-- remainder of each payment is dropped, not carried over, and plain donations buy tickets too.
-- Tickets per person stop at the optional cap. Unused gold is shown as "Not used".
-- Tickets can also be added or removed by hand (right-click a row, or /gt raffle add).
-- Gold mailed to you and then deposited by you counts once, for the sender (1.29.0, see Routing).
--
-- Several raffles at once (1.9.0): each raffle has its own settings, sale, draw and posts.
-- A payment that only one raffle could take counts for it as above. When two or more raffles
-- could take it (same guild bank, or both take mail, and both selling at that moment):
--   mail counts for the raffle whose subject keyword is in the mail's subject;
--   a bank deposit counts for the raffle whose ticket price it is an exact multiple of
--   (so give each raffle an odd price: 1,001g, 1,003g, ...).
-- Anything still unclear (no match, or several) goes to the Unassigned list instead of being
-- dropped; you right-click it there to count it for a raffle or ignore it. When a raffle's
-- winners are drawn, every payment it counted is locked to it, so later raffles can't move it.
--
-- Bank deposits come from LibHistoire through the raffle's own reader, so the first time the
-- raffle is turned on it reads the whole look-back period, and every deposit is kept for
-- 45 days. A raffle can start in the past and still count every deposit since its start.
-- Mail: the game only lists your mail while the mailbox is open, so every time you open it,
-- each mail with gold attached is recorded once (by mail id) with the time it arrived. The
-- draw waits until you have opened the mailbox after the sale ended.
--
-- The draw numbers the tickets 1..N (buyers in order of their first deposit), then picks a
-- random ticket for each prize. With one win per person, tickets of earlier winners are
-- skipped. Results are put in the guild chat box for you to press Enter; nothing is sent
-- automatically.

local GT = FurysGuildToolset
local U = GT.Util
local T = GT.Theme

local Raffle = GT:RegisterModule("raffle", {})
GT.Raffle = Raffle

Raffle.historyReader = "raffle"   -- own LibHistoire reader and saved position (see Core/History.lua)

local KEEP_DAYS = 45
local DRAW_DELAY_S = 60           -- wait this long after the sale ends for late history events
local MAX_CHAT = 350
local UPDATE_NAME = "FurysGuildToolset_Raffle"
local COLLIDE_TICKETS = 100       -- warn when two prices share a multiple at or below this many tickets

-- Which prize a draw result is for: its own slot, or the draw number for results from before 1.7.0.
local function Slot(res) return res.slot or res.n end

-- One raffle's settings and state. Each raffle in sv.raffles is a table like this.
local RAFFLE_DEFAULTS = {
    id = 0,             -- set when the raffle is made; never reused
    name = "",          -- optional; blank = its prize
    guildId = 0,        -- 0 = no guild (mail-only raffle)
    useBank = true,     -- guild bank gold deposits buy tickets
    useMail = false,    -- gold mailed to you buys tickets
    mailSubject = "",   -- keyword: a mail counts only if its subject contains this (blank = any gold mail)
    prize = "",
    price = 1000,
    winners = 1,
    maxTickets = 0,     -- 0 = no limit
    oneWin = true,
    startText = "",     -- "YYYY-MM-DD HH:MM" local time; blank = when you click Start sales now
    hours = 72,
    -- startedAt, endedAt: set by Start sales now / End sales now
    -- adjust = { [name] = tickets added (+) or removed (-) by hand }
    -- excluded = { [name] = true }: left out of the draw
    -- changes = { { ts =, who =, text = } }: every change made by hand
    -- draw = { ts =, total =, results = { { n =, ticket =, who =, from =, to =, tickets =, void =, slot = } } }
}
local RAFFLE_TABLES = { "adjust", "excluded", "changes" }

Raffle.defaults = {
    enabled = false,        -- every feature starts turned off on a new install (Albert, 1.3.0)
    buyNotice = false,      -- chat line when someone buys tickets
    deposits = {},          -- { g =, id =, ts =, who =, amt =, src = "mail" or nil, subj =, got = } bank deposits and gold mails, kept KEEP_DAYS
    raffles = {},           -- the raffles, each like RAFFLE_DEFAULTS (1.9.0; before that one sv.raffle)
    current = 0,            -- id of the raffle shown on the tab and in the settings
    nextId = 1,
    assign = {},            -- [payment key] = raffle id, or "ignore": decided by hand from the Unassigned list
    locked = {},            -- [payment key] = raffle id: counted by a raffle whose winners are drawn
    mailCheckedAt = 0,      -- last time the mailbox was read
    past = {},              -- finished raffles (last 20)
    show = false,           -- 1.34.0: draw show (countdown and winner reveal on screen)
    showCountdown = 5,      -- seconds of countdown before each winner
    showSpin = 4,           -- seconds of names spinning before each winner
    showSound = true,       -- sounds during the draw show
}

function Raffle.SeenKey(d)
    if d.src == "mail" then return "mail:" .. d.id end
    return d.g .. ":" .. tostring(d.id)
end

local function FillRaffle(r)
    -- 1.29.0: gold mailed to you and then deposited by you counts once (see Raffle:Routing).
    -- A raffle whose winners were drawn before 1.29.0 keeps the count it was drawn with.
    if r.passMail == nil then r.passMail = (r.draw == nil) end
    for key, value in pairs(RAFFLE_DEFAULTS) do
        if r[key] == nil then r[key] = value end
    end
    for _, key in ipairs(RAFFLE_TABLES) do
        if r[key] == nil then r[key] = {} end
    end
    return r
end

function Raffle:MakeRaffle(copyFrom)
    local sv = self.sv
    local r = { id = sv.nextId }
    sv.nextId = sv.nextId + 1
    if copyFrom then
        for _, key in ipairs({ "guildId", "useBank", "useMail", "price", "maxTickets", "oneWin", "hours" }) do r[key] = copyFrom[key] end
    end
    -- 1.20.0: new raffles number tickets in the order they were bought. Raffles made before
    -- have no numbering field. Since 1.20.1 every raffle keeps the numbers it has handed out (KeepNumbers).
    r.numbering = "time"
    r.hand = {}
    return FillRaffle(r)
end

function Raffle:Initialize(sv)
    self.sv = sv
    -- 1.6.1: the amount alone decides, so mails no longer need "raffle" in the subject (1.6.0's default).
    if (sv.settingsVersion or 1) < 2 and sv.raffle and sv.raffle.mailSubject == "raffle" then sv.raffle.mailSubject = "" end
    -- 1.9.0: one raffle (sv.raffle) became a list of raffles (sv.raffles).
    if sv.raffle then
        local r = sv.raffle
        sv.raffle = nil
        sv.mailCheckedAt = r.mailCheckedAt or 0
        r.mailCheckedAt = nil
        r.id = sv.nextId
        sv.nextId = sv.nextId + 1
        table.insert(sv.raffles, 1, r)
    end
    sv.settingsVersion = 3
    self.freeTop = {}
    for _, r in ipairs(sv.raffles) do
        local running = r.passMail == nil and r.issued ~= nil
        FillRaffle(r)
        -- A raffle that was already running when 1.29.0 arrived: see KeepNumbers.
        if running and r.passMail then self.freeTop[r.id] = true end
    end
    if #sv.raffles == 0 then sv.raffles[1] = self:MakeRaffle() end
    if not self:ById(sv.current) then sv.current = sv.raffles[1].id end

    self.seen = {}
    for _, d in ipairs(sv.deposits) do self.seen[Raffle.SeenKey(d)] = true end
    self.lastStatus = {}
    self.view = "raffle"   -- or "unassigned"
    self:Prune()
    self:RegisterTab()
    if sv.enabled then
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 1000, function() self:Tick() end)
        EVENT_MANAGER:RegisterForEvent(UPDATE_NAME, EVENT_MAIL_INBOX_UPDATE, function() self:ScanMail() end)
        EVENT_MANAGER:RegisterForEvent(UPDATE_NAME, EVENT_MAIL_OPEN_MAILBOX, function() self:ScanMail() end)
        EVENT_MANAGER:RegisterForEvent(UPDATE_NAME, EVENT_MAIL_READABLE, function(_, mailId) self:OnMailReadable(mailId) end)
        -- 1.6.2: also record a mail right before its gold is taken, so taking the gold always counts.
        ZO_PreHook("TakeMailAttachedMoney", function(mailId) self:BeforeTakeGold(mailId) end)
        ZO_PreHook("TakeMailAttachments", function(mailId) self:BeforeTakeGold(mailId) end)
    end
end

function Raffle:Prune()
    local sv = self.sv
    local cutoff = GetTimeStamp() - KEEP_DAYS * 86400
    for _, r in ipairs(sv.raffles) do
        local start = self:StartTime(r)
        if start and start < cutoff then cutoff = start end
    end
    local kept = {}
    for _, d in ipairs(sv.deposits) do
        if d.ts >= cutoff then kept[#kept + 1] = d else self.seen[Raffle.SeenKey(d)] = nil end
    end
    sv.deposits = kept
    for _, list in ipairs({ sv.assign, sv.locked }) do
        local gone = {}
        for key in pairs(list) do if not self.seen[key] then gone[#gone + 1] = key end end
        for _, key in ipairs(gone) do list[key] = nil end
    end
end

-- Raffles ---------------------------------------------------------------------------

function Raffle:ById(id)
    for _, r in ipairs(self.sv.raffles) do
        if r.id == id then return r end
    end
end

function Raffle:Cur()
    return self:ById(self.sv.current) or self.sv.raffles[1]
end

-- Ticket counts, routing and the Unassigned list are worked out again after any change.
function Raffle:Dirty()
    self.routing = nil
    self.tallies = nil
end

function Raffle:Multi()
    return #self.sv.raffles > 1
end

-- The raffle's name in your lists: the name you gave it, its prize, or "Raffle 3".
function Raffle:Name(r)
    local name = zo_strtrim(r.name or "")
    if name ~= "" then return name end
    local list = self:Prizes(r)
    if #list == 1 then return list[1] end
    if #list > 1 then return string.format("%s and %d more", list[1], #list - 1) end
    return "Raffle " .. r.id
end

-- "Raffle: " in chat lines, or "Raffle (name): " when several raffles exist.
function Raffle:Tag(r)
    if self:Multi() then return string.format("Raffle (%s)", self:Name(r)) end
    return "Raffle"
end

function Raffle:Show(r)
    self.sv.current = r.id
    self.view = "raffle"
    GT.Report:Show("raffle")
    GT.Report:RefreshIfShown()
end

-- History -------------------------------------------------------------------------

function Raffle:GetHistoryCategories()
    if not self.sv.enabled then return {} end
    return { GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY }
end

function Raffle:OnHistoryEvent(guildId, category, info, isLive)
    if info.currencyType ~= CURT_MONEY or info.eventType ~= GUILD_HISTORY_BANKED_CURRENCY_EVENT_DEPOSITED then return end
    local key = guildId .. ":" .. tostring(info.eventId)
    if self.seen[key] then return end
    self.seen[key] = true
    local d = { g = guildId, id = info.eventId, ts = info.timestampS, who = info.displayName, amt = info.amount }
    table.insert(self.sv.deposits, d)
    self:Dirty()
    if isLive then
        local r, why = self:Route(d)
        local passed = r and self:Routing().passed[d]
        if passed then
            U.Print("%s: %s of your %s deposit is ticket gold that was mailed to you, so that part buys you no tickets.", self:Tag(r),
                U.FormatGold(passed), U.FormatGold(d.amt))
        end
        if r and self.sv.buyNotice then
            local buyer = self:GetTally(r).byName[d.who]
            if buyer then
                U.Print("%s: %s deposited %s and now has %d %s.", self:Tag(r), d.who, U.FormatGold(d.amt), buyer.tickets,
                    buyer.tickets == 1 and "ticket" or "tickets")
            end
        elseif why then
            U.Print("Raffle: %s deposited %s, but it's unclear which raffle it's for (%s). See Unassigned payments on the Raffle tab.", d.who, U.FormatGold(d.amt), why)
        end
        GT.Report:RefreshIfShown()
    end
end

function Raffle:OnHistoryCaughtUp()
    self:Dirty()
    GT.Report:RefreshIfShown()
end

function Raffle:IsCaughtUp(r)
    if not r.useBank or r.guildId == 0 then return true end
    return GT.History:IsCaughtUp(GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY, r.guildId, self.historyReader)
end

-- Mail ----------------------------------------------------------------------------

-- Records one mail with gold attached, once (by mail id): not system mail, not returned, not
-- cash on delivery. money/cod come from the caller, because the inbox list and the opened mail
-- report them through different functions.
function Raffle:RecordMail(mailId, money, cod)
    local key = "mail:" .. Id64ToString(mailId)
    if self.seen[key] or (money or 0) <= 0 or (cod or 0) > 0 then return false end
    local sender, _, subject, _, _, fromSystem, fromCustomerService, returned, _, _, _, _, secsSinceReceived = GetMailItemInfo(mailId)
    if fromSystem or fromCustomerService or returned or not sender or sender == "" then return false end
    self.seen[key] = true
    -- ts: when it arrived (decides which raffle it is for). got: when it was first seen in your
    -- mailbox, the earliest you could have taken its gold (decides which of your deposits pass it on).
    local d = { g = 0, id = Id64ToString(mailId), src = "mail", ts = GetTimeStamp() - (secsSinceReceived or 0), got = GetTimeStamp(),
        who = U.NormalizeName(sender), amt = money, subj = subject }
    table.insert(self.sv.deposits, d)
    self:Dirty()
    local r, why = self:Route(d)
    if r then
        local buyer = self:GetTally(r).byName[d.who]
        U.Print("%s: counted %s mailed by %s. They now have %d %s.", self:Tag(r), U.FormatGold(d.amt), d.who, buyer.tickets, buyer.tickets == 1 and "ticket" or "tickets")
    elseif why then
        U.Print("Raffle: %s mailed %s, but it's unclear which raffle it's for (%s). See Unassigned payments on the Raffle tab.", d.who, U.FormatGold(d.amt), why)
    end
    GT.Report:RefreshIfShown()
    return true
end

-- The inbox list, each time the mailbox opens or changes.
function Raffle:ScanMail()
    local mailId = GetNextMailId(nil)
    while mailId do
        local _, _, _, _, _, _, _, _, _, attachedMoney, codAmount = GetMailItemInfo(mailId)
        self:RecordMail(mailId, attachedMoney, codAmount)
        mailId = GetNextMailId(mailId)
    end
    self.sv.mailCheckedAt = GetTimeStamp()
    if GT.Report.currentTab == "raffle" then GT.Report:RefreshIfShown() end
end

-- An opened mail: its attachment info is certain to be loaded now.
function Raffle:OnMailReadable(mailId)
    local _, money, cod = GetMailAttachmentInfo(mailId)
    self:RecordMail(mailId, money, cod)
    self.sv.mailCheckedAt = GetTimeStamp()
end

-- Last chance: right before the gold is taken out of a mail (Take, Take all, or another addon).
function Raffle:BeforeTakeGold(mailId)
    if not mailId then return end
    local _, money, cod = GetMailAttachmentInfo(mailId)
    self:RecordMail(mailId, money, cod)
end

-- Times ---------------------------------------------------------------------------

-- "2026-11-23 20:00" (or "2026-11-23 8:00 pm") in your local time -> timestamp, or nil.
function Raffle.ParseTime(text)
    text = zo_strtrim(text or "")
    local y, mo, d, h, mi = text:match("^(%d%d%d%d)%-(%d%d?)%-(%d%d?)%s+(%d%d?):(%d%d)")
    if not y then return nil end
    h = tonumber(h)
    local ampm = zo_strlower(text):match("([ap])%.?m%.?%s*$")
    if ampm == "p" and h < 12 then h = h + 12 elseif ampm == "a" and h == 12 then h = 0 end
    return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = h, min = tonumber(mi), sec = 0 })
end

function Raffle:StartTime(r)
    return Raffle.ParseTime(r.startText) or r.startedAt
end

function Raffle:EndTime(r)
    if r.endedAt then return r.endedAt end
    local start = self:StartTime(r)
    return start and (start + r.hours * 3600) or nil
end

-- "setup", "scheduled", "selling", "closed" or "drawn"
function Raffle:Status(r)
    if r.draw then return "drawn" end
    local start, finish = self:StartTime(r), self:EndTime(r)
    if not start then return "setup" end
    local now = GetTimeStamp()
    if now < start then return "scheduled" end
    if now < finish then return "selling" end
    return "closed"
end

local function NiceDate(ts)
    return os.date("%a %b %d, %I:%M %p", ts):gsub(" 0(%d)", " %1")
end

local function NiceLeft(seconds)
    seconds = math.max(0, seconds)
    local d, h, m = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
    if d > 0 then return string.format("%dd %dh", d, h) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

-- "1d 02:03:04", "2:03:04" or "3:04".
local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    local d, h, m, sec = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60), seconds % 60
    if d > 0 then return string.format("%dd %02d:%02d:%02d", d, h, m, sec) end
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%d:%02d", m, sec)
end

-- Short status for menus: "not started", "starts in 2h 10m", "ends in 1d 3h", "sales ended", "drawn".
function Raffle:StatusShort(r)
    local status = self:Status(r)
    local now = GetTimeStamp()
    if status == "setup" then return "not started" end
    if status == "scheduled" then return "starts in " .. NiceLeft(self:StartTime(r) - now) end
    if status == "selling" then return "ends in " .. NiceLeft(self:EndTime(r) - now) end
    if status == "closed" then return "sales ended, draw!" end
    return "winners drawn"
end

function Raffle:TabTitle()
    local r = self:Cur()
    local status = self:Status(r)
    if status == "selling" then
        local left = self:EndTime(r) - GetTimeStamp()
        return "Raffle " .. (left >= 86400 and NiceLeft(left) or Clock(left))
    end
    if status == "closed" then return "Raffle: draw!" end
    return "Raffle"
end

-- Every second while the feature is on: tells you when sales start and end, and keeps the
-- countdown on the Raffle tab button and the top line ticking without rebuilding the list.
function Raffle:Tick()
    local changed = false
    for _, r in ipairs(self.sv.raffles) do
        local status = self:Status(r)
        local last = self.lastStatus[r.id]
        if last and last ~= status then
            if status == "selling" then
                U.Print("%s ticket sales have started.", self:Tag(r))
            elseif status == "closed" then
                U.Alert(string.format("%s ticket sales have ended. Open /gt raffle and click Draw winners.", self:Tag(r)))
            end
            changed = true
        end
        self.lastStatus[r.id] = status
    end
    if changed then
        self:Dirty()
        GT.Report:RefreshIfShown()
        return
    end
    local Report = GT.Report
    if not Report.control or Report.control:IsHidden() then return end
    local r = self:Cur()
    local status = self:Status(r)
    if status ~= "selling" and status ~= "scheduled" then return end
    for i, tab in ipairs(Report.tabs) do
        if tab.id == "raffle" then Report.tabButtons[i]:SetText(self:TabTitle()) end
    end
    if Report.currentTab == "raffle" and self.view == "raffle" then
        local summary = self:TabSummary()
        if #self:GetTally(r).list > 0 then summary = summary .. "  " .. Report.MENU_HINT end
        Report.summary:SetText(summary)
    end
end

-- Which raffle a payment is for ------------------------------------------------------

local function Keyword(r)
    return zo_strlower(zo_strtrim(r.mailSubject or ""))
end

local function HasKeyword(r, subject)
    local word = Keyword(r)
    return word ~= "" and zo_strlower(subject or ""):find(word, 1, true) ~= nil
end

-- Raffles selling when the payment arrived that take this kind of payment.
function Raffle:Candidates(d)
    local list = {}
    if not d.who or d.who == "" then return list end
    for _, r in ipairs(self.sv.raffles) do
        local start, finish = self:StartTime(r), self:EndTime(r)
        if start and d.ts >= start and d.ts < finish then
            if d.src == "mail" then
                if r.useMail then list[#list + 1] = r end
            elseif r.useBank and r.guildId ~= 0 and d.g == r.guildId then
                list[#list + 1] = r
            end
        end
    end
    return list
end

local function NameList(self, list)
    local names = {}
    for _, r in ipairs(list) do names[#names + 1] = self:Name(r) end
    return table.concat(names, " and ")
end

-- The raffle a payment counts for, or nil. The second result says why it's unclear, when it
-- is (it then belongs on the Unassigned list); the third is "hand", "locked" or "ignored"
-- when the choice was made by hand or by a draw.
function Raffle:Route(d)
    local key = Raffle.SeenKey(d)
    local hand = self.sv.assign[key]
    if hand == "ignore" then return nil, nil, "ignored" end
    if hand then return self:ById(hand), nil, "hand" end   -- nil: its raffle was put away
    local locked = self.sv.locked[key]
    if locked then return self:ById(locked), nil, "locked" end
    local candidates = self:Candidates(d)
    if #candidates == 0 then return nil end
    if #candidates == 1 then
        -- Only one raffle could take it: as before 1.9.0, any amount counts, and a mail counts
        -- when the subject has the raffle's keyword (or it has none).
        local r = candidates[1]
        if d.src == "mail" and Keyword(r) ~= "" and not HasKeyword(r, d.subj) then return nil end
        return r
    end
    local hits = {}
    for _, r in ipairs(candidates) do
        if d.src == "mail" then
            if HasKeyword(r, d.subj) then hits[#hits + 1] = r end
        elseif d.amt % math.max(1, r.price) == 0 then
            hits[#hits + 1] = r
        end
    end
    if #hits == 1 then return hits[1] end
    if d.src == "mail" then
        if #hits == 0 then return nil, "no raffle's keyword is in the subject" end
        return nil, "the subject has the keywords of " .. NameList(self, hits)
    end
    if #hits == 0 then return nil, "not a multiple of any raffle's ticket price" end
    return nil, "a multiple of the prices of " .. NameList(self, hits)
end

local function FlowOrder(a, b)
    if a.at ~= b.at then return a.at < b.at end
    if a.mail ~= b.mail then return a.mail end   -- at the same second the mail comes first
    return a.i < b.i
end

-- Every payment, routed once: { byRaffle = { [id] = { d, ... } }, unclear = { { d =, why =, candidates =, how =, r = } },
-- passed = { [d] = gold of this deposit that buys no tickets }, owed = mailed gold you still hold }
-- unclear holds the payments still to decide and those decided by hand (to undo).
--
-- 1.29.0 (Albert): gold mailed to you for tickets is the sender's payment. When you then put
-- that gold in the guild bank, your deposit is the same gold again, so it buys you no tickets
-- until every mailed gold piece is passed on. In time order: each counted mail adds to what
-- you hold, and each counted bank deposit of yours first pays that off (passed[d]); only the
-- rest of the deposit is yours. 100,000g mailed, then 101,000g deposited = 1,000g for you.
function Raffle:Routing()
    if self.routing then return self.routing end
    local byRaffle, unclear, open = {}, {}, 0
    local me = zo_strlower(GetDisplayName())
    local flow = {}
    for i, d in ipairs(self.sv.deposits) do
        local r, why, how = self:Route(d)
        if r then
            byRaffle[r.id] = byRaffle[r.id] or {}
            table.insert(byRaffle[r.id], d)
            if r.passMail then
                if d.src == "mail" then flow[#flow + 1] = { d = d, at = d.got or d.ts, mail = true, i = i }
                elseif zo_strlower(d.who) == me then flow[#flow + 1] = { d = d, at = d.ts, mail = false, i = i } end
            end
        end
        if why then open = open + 1 end
        if why or how == "hand" or how == "ignored" then
            unclear[#unclear + 1] = { d = d, why = why, how = how, r = r, candidates = self:Candidates(d) }
        end
    end
    table.sort(flow, FlowOrder)
    local passed, owed = {}, 0
    for _, f in ipairs(flow) do
        if f.mail then
            owed = owed + f.d.amt
        elseif owed > 0 then
            local part = math.min(owed, f.d.amt)
            passed[f.d] = part
            owed = owed - part
        end
    end
    self.routing = { byRaffle = byRaffle, unclear = unclear, open = open, passed = passed, owed = owed }
    return self.routing
end

-- The gold of a payment that buys tickets: all of it, except the part of your own bank deposit
-- that only passes mailed ticket gold on to the bank.
function Raffle:Counted(d)
    return d.amt - (self:Routing().passed[d] or 0)
end

-- Payments still on the Unassigned list that this raffle (or any raffle, without r) could take.
function Raffle:OpenUnclear(r)
    local count = 0
    for _, u in ipairs(self:Routing().unclear) do
        if u.why then
            if not r then count = count + 1
            else
                for _, c in ipairs(u.candidates) do if c == r then count = count + 1; break end end
            end
        end
    end
    return count
end

function Raffle:Assign(d, value)
    self.sv.assign[Raffle.SeenKey(d)] = value
    self:Dirty()
    GT.Report:RefreshIfShown()
end

-- Warnings when raffles selling at the same time can't tell their payments apart.
function Raffle:Overlaps(a, b)
    local sa, sb = self:StartTime(a), self:StartTime(b)
    if not sa or not sb or a.draw or b.draw then return false end
    return sa < self:EndTime(b) and sb < self:EndTime(a)
end

local function Gcd(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a
end

function Raffle:Warnings(r)
    local list = {}
    for _, o in ipairs(self.sv.raffles) do
        if o ~= r and self:Overlaps(r, o) then
            if r.useBank and o.useBank and r.guildId ~= 0 and r.guildId == o.guildId then
                if r.price == o.price then
                    list[#list + 1] = string.format("%s has the same ticket price, so bank deposits go to Unassigned. Give each raffle its own odd price (1,001g, 1,003g).", self:Name(o))
                else
                    local both = math.floor(r.price / Gcd(r.price, o.price)) * o.price
                    if both / math.max(r.price, o.price) <= COLLIDE_TICKETS then
                        list[#list + 1] = string.format("A deposit of %s fits the prices of both this raffle and %s, so it would go to Unassigned. Odd prices close together (1,001g, 1,003g) avoid this.", U.FormatGold(both), self:Name(o))
                    end
                end
            end
            if r.useMail and o.useMail then
                local a, b = Keyword(r), Keyword(o)
                if a == "" then
                    list[#list + 1] = string.format("%s also takes mail, so this raffle needs a mail subject keyword.", self:Name(o))
                elseif b ~= "" and (a:find(b, 1, true) or b:find(a, 1, true)) then
                    list[#list + 1] = string.format("The keywords \"%s\" and \"%s\" (%s) overlap, so mails with the longer one go to Unassigned.", r.mailSubject, o.mailSubject, self:Name(o))
                end
            end
        end
    end
    return list
end

function Raffle:PrintWarnings(r)
    for _, text in ipairs(self:Warnings(r)) do U.Print("%s: %s", self:Tag(r), text) end
end

-- Another raffle selling at the same time takes this kind of payment too.
function Raffle:Shares(r, mail)
    for _, o in ipairs(self.sv.raffles) do
        if o ~= r and self:Overlaps(r, o) then
            if mail and r.useMail and o.useMail then return true end
            if not mail and r.useBank and o.useBank and r.guildId ~= 0 and r.guildId == o.guildId then return true end
        end
    end
    return false
end

-- Tickets -------------------------------------------------------------------------

-- At least one way to buy tickets is set up.
function Raffle:HasSource(r)
    return r.useMail or (r.useBank and r.guildId ~= 0)
end

-- Buyers in ticket-number order (first deposit first), with ticket ranges.
-- Result: { list = { buyer, ... }, byName = { [name] = buyer }, total =, gold =, passed = }
-- buyer = { who, gold, paid, deposits, first, last, bought, adjust, tickets, refund, from, to, excluded, passed }
function Raffle:GetTally(r)
    self.tallies = self.tallies or {}
    if self.tallies[r.id] then return self.tallies[r.id] end
    local byName, list = {}, {}
    local function Buyer(who, ts)
        local b = byName[who]
        if not b then
            b = { who = who, gold = 0, paid = 0, deposits = 0, mails = 0, first = ts, last = 0 }
            byName[who] = b
            list[#list + 1] = b
        end
        return b
    end
    local price = math.max(1, r.price)
    local passed = 0
    for _, d in ipairs(self:Routing().byRaffle[r.id] or {}) do
        local amt = self:Counted(d)
        passed = passed + d.amt - amt
        -- A deposit of yours that only passes mailed gold on doesn't make you a buyer.
        if amt > 0 then
            local b = Buyer(d.who, d.ts)
            b.gold = b.gold + amt
            b.paid = b.paid + math.floor(amt / price)   -- each payment on its own; the remainder is dropped
            if d.src == "mail" then b.mails = b.mails + 1 else b.deposits = b.deposits + 1 end
            b.first = math.min(b.first, d.ts)
            b.last = math.max(b.last, d.ts)
        end
    end
    self:MergeNameCase(r, byName)
    for who in pairs(r.adjust) do Buyer(who, math.huge) end
    for who in pairs(r.excluded) do Buyer(who, math.huge) end
    table.sort(list, function(a, b)
        if a.first ~= b.first then return a.first < b.first end
        return a.who < b.who
    end)
    local total, gold = 0, 0
    for _, b in ipairs(list) do
        local bought = b.paid
        local paidFor = bought
        if r.maxTickets > 0 and bought > r.maxTickets then bought = r.maxTickets end
        b.bought = bought
        b.refund = b.gold - bought * price
        b.overCap = paidFor - bought
        b.adjust = r.adjust[b.who] or 0
        b.excluded = r.excluded[b.who] == true
        b.tickets = b.excluded and 0 or math.max(0, bought + b.adjust)
        b.ranges = {}
        if r.numbering ~= "time" and b.tickets > 0 then
            b.from, b.to = total + 1, total + b.tickets
            b.ranges[1] = { b.from, b.to }
            total = total + b.tickets
        end
        gold = gold + b.gold
    end
    if r.numbering == "time" then total = self:NumberByTime(r, byName, price) end
    total = self:KeepNumbers(r, list, byName, price)
    local tally = { list = list, byName = byName, total = total, gold = gold, passed = passed }
    self.tallies[r.id] = tally
    return tally
end

-- Numbering by time (1.20.0, new raffles): every payment's tickets, and every ticket added by
-- hand, get the next numbers at the time they came in, so someone who buys again later gets
-- numbers spread through the list. Tickets over the per-person cap are dropped from the later
-- payments, tickets removed by hand come off the person's latest tickets, and someone left out
-- of the draw gets no numbers. Returns the total number of tickets.
function Raffle:NumberByTime(r, byName, price)
    local real = {}
    for who in pairs(byName) do real[zo_strlower(who)] = who end
    local function Real(who) return real[zo_strlower(who)] or who end
    local blocks, bought, removed, logged = {}, {}, {}, {}
    for _, d in ipairs(self:Routing().byRaffle[r.id] or {}) do
        local n = math.floor(self:Counted(d) / price)
        if r.maxTickets > 0 then n = math.max(0, math.min(n, r.maxTickets - (bought[d.who] or 0))) end
        bought[d.who] = (bought[d.who] or 0) + n
        blocks[#blocks + 1] = { ts = d.ts, who = d.who, n = n }
    end
    for _, e in ipairs(r.hand or {}) do
        local who = Real(e.who)
        logged[who] = (logged[who] or 0) + e.n
        if e.n > 0 then blocks[#blocks + 1] = { ts = e.ts, who = who, n = e.n }
        else removed[who] = (removed[who] or 0) - e.n end
    end
    -- Hand changes made before they were timed (or merged from another spelling): the rest
    -- goes last, or comes off the latest tickets.
    for who, b in pairs(byName) do
        local rest = b.adjust - (logged[who] or 0)
        if rest > 0 then blocks[#blocks + 1] = { ts = math.huge, who = who, n = rest }
        elseif rest < 0 then removed[who] = (removed[who] or 0) - rest end
    end
    for i, block in ipairs(blocks) do block.i = i end
    table.sort(blocks, function(a, b)
        if a.ts ~= b.ts then return a.ts < b.ts end
        return a.i < b.i
    end)
    for i = #blocks, 1, -1 do
        local block = blocks[i]
        local take = math.min(removed[block.who] or 0, block.n)
        if take > 0 then
            block.n = block.n - take
            removed[block.who] = removed[block.who] - take
        end
    end
    local total = 0
    for _, block in ipairs(blocks) do
        local b = byName[block.who]
        if b and block.n > 0 and not b.excluded then
            local last = b.ranges[#b.ranges]
            if last and last[2] == total then last[2] = total + block.n   -- right after their previous tickets
            else b.ranges[#b.ranges + 1] = { total + 1, total + block.n } end
            total = total + block.n
        end
    end
    for _, b in pairs(byName) do
        local count = 0
        for _, range in ipairs(b.ranges) do count = count + range[2] - range[1] + 1 end
        b.tickets = count
        if count > 0 then b.from, b.to = b.ranges[1][1], b.ranges[#b.ranges][2] end
    end
    return total
end

-- 1.20.1: ticket numbers never move. Every number handed out is saved in r.issued (blocks of
-- { who, from, to }), and only new tickets get new numbers, always after the highest number so
-- far. Tickets taken away come off the person's highest numbers and those numbers are not used
-- again. The first time a raffle is seen, the numbers it shows right then are saved as they are.
-- Returns the number of tickets in the draw.
function Raffle:KeepNumbers(r, list, byName, price)
    if not r.issued then
        r.issued = {}
        for _, b in ipairs(list) do
            for _, range in ipairs(b.ranges) do r.issued[#r.issued + 1] = { who = b.who, from = range[1], to = range[2] } end
        end
        table.sort(r.issued, function(a, b) return a.from < b.from end)
    end
    -- What each person holds now, by lowercase name.
    local held, nextNo = {}, 1
    for _, block in ipairs(r.issued) do
        local key = zo_strlower(block.who)
        held[key] = held[key] or {}
        table.insert(held[key], block)
        nextNo = math.max(nextNo, block.to + 1)
    end
    r.nextTicket = math.max(r.nextTicket or 1, nextNo)
    local function Count(blocks)
        local n = 0
        for _, block in ipairs(blocks or {}) do n = n + block.to - block.from + 1 end
        return n
    end
    -- Take away tickets someone no longer has, from their highest numbers.
    local wanted = {}
    for _, b in ipairs(list) do wanted[zo_strlower(b.who)] = b.tickets end
    local lowestTaken, highestTaken
    for key, blocks in pairs(held) do
        local extra = Count(blocks) - (wanted[key] or 0)
        for i = #blocks, 1, -1 do
            if extra <= 0 then break end
            local block = blocks[i]
            local take = math.min(extra, block.to - block.from + 1)
            highestTaken = math.max(highestTaken or 0, block.to)
            block.to = block.to - take
            lowestTaken = math.min(lowestTaken or block.to + 1, block.to + 1)
            extra = extra - take
        end
    end
    for i = #r.issued, 1, -1 do
        if r.issued[i].to < r.issued[i].from then table.remove(r.issued, i) end
    end
    -- 1.29.0, once for a raffle that was already running: tickets your own deposits of mailed
    -- gold had been given come off here. When they were the last numbers handed out, those
    -- numbers are free again, so the list gets no hole.
    if self.freeTop[r.id] then
        self.freeTop[r.id] = nil
        local top = 0
        for _, block in ipairs(r.issued) do top = math.max(top, block.to) end
        if lowestTaken and lowestTaken > top and highestTaken == r.nextTicket - 1 then r.nextTicket = lowestTaken end
    end
    -- New tickets go after every number handed out so far, oldest payment first.
    local new = {}
    for _, b in ipairs(list) do
        local n = b.tickets - Count(held[zo_strlower(b.who)])
        if n > 0 then new[#new + 1] = { b = b, n = n } end
    end
    table.sort(new, function(x, y)
        local a, b = x.b.last > 0 and x.b.last or math.huge, y.b.last > 0 and y.b.last or math.huge
        if a ~= b then return a < b end
        return x.b.who < y.b.who
    end)
    for _, item in ipairs(new) do
        local block = { who = item.b.who, from = r.nextTicket, to = r.nextTicket + item.n - 1 }
        r.issued[#r.issued + 1] = block
        r.nextTicket = block.to + 1
    end
    -- Hand each buyer their numbers.
    local total = 0
    for _, b in ipairs(list) do b.ranges = {}; b.from, b.to = nil, nil end
    local byKey = {}
    for _, b in ipairs(list) do byKey[zo_strlower(b.who)] = b end
    for _, block in ipairs(r.issued) do
        local b = byKey[zo_strlower(block.who)]
        if b then
            local last = b.ranges[#b.ranges]
            if last and last[2] + 1 == block.from then last[2] = block.to
            else b.ranges[#b.ranges + 1] = { block.from, block.to } end
            total = total + block.to - block.from + 1
        end
    end
    for _, b in ipairs(list) do
        if b.ranges[1] then b.from, b.to = b.ranges[1][1], b.ranges[#b.ranges][2] end
    end
    return total
end

-- "#4", "#4-8" or "#4-6, #11, #20-21": a buyer's ticket numbers.
function Raffle.NumbersText(ranges)
    local parts = {}
    for _, range in ipairs(ranges) do
        parts[#parts + 1] = range[1] == range[2] and ("#" .. range[1]) or string.format("#%d-%d", range[1], range[2])
    end
    return table.concat(parts, ", ")
end

-- A draw result's holder's tickets, for posts: "4-8" or "#4-6, #11" (numbered by time).
local function HeldText(res)
    if res.numbers then return res.numbers end
    if res.from == res.to then return tostring(res.from) end
    return string.format("%d-%d", res.from, res.to)
end

-- 1.6.4: a name typed in the wrong case (@marthowolf for @MarthOWolf) made a second buyer.
-- Hand changes saved under another spelling of a buyer's name move to the buyer's real
-- spelling. If both spellings had tickets added, the wrong-case one is dropped as a repeat.
function Raffle:MergeNameCase(r, byName)
    local real = {}
    for who in pairs(byName) do real[zo_strlower(who)] = who end
    for _, list in ipairs({ r.adjust, r.excluded }) do
        local moves = {}
        for who, value in pairs(list) do
            local right = real[zo_strlower(who)]
            if right and right ~= who then moves[#moves + 1] = { who, right, value } end
        end
        for _, move in ipairs(moves) do
            local who, right, value = move[1], move[2], move[3]
            list[who] = nil
            local dropped = list == r.adjust and list[right] ~= nil
            if not dropped then list[right] = value end
            for _, c in ipairs(r.changes) do if c.who == who then c.who = right end end
            table.insert(r.changes, { ts = GetTimeStamp(), who = right, text = dropped
                and string.format("hand change under %s (%+d) dropped as a repeat of this one", who, value)
                or string.format("hand change typed as %s moved here", who) })
        end
    end
end

-- The real spelling of a typed name: a buyer, a member of any of your guilds, or a friend.
-- Returns the name, or nil plus up to 5 close matches.
function Raffle:FindAccount(r, typed)
    local want = zo_strlower(U.NormalizeName(typed))
    local close, seen = {}, {}
    local function Check(name)
        if not name or name == "" then return nil end
        local low = zo_strlower(name)
        if low == want then return name end
        if not seen[low] and #close < 5 and (low:find(want:sub(2), 1, true) or want:find(low:sub(2), 1, true)) then
            seen[low] = true
            close[#close + 1] = name
        end
    end
    for _, b in ipairs(self:GetTally(r).list) do
        local hit = Check(b.who)
        if hit then return hit end
    end
    for _, guildId in ipairs(U.GetGuildIds()) do
        for i = 1, GetNumGuildMembers(guildId) do
            local hit = Check((GetGuildMemberInfo(guildId, i)))
            if hit then return hit end
        end
    end
    for i = 1, GetNumFriends() do
        local hit = Check((GetFriendInfo(i)))
        if hit then return hit end
    end
    return nil, close
end

function Raffle:Change(r, who, text)
    table.insert(r.changes, { ts = GetTimeStamp(), who = who, text = text })
    self:Dirty()
    GT.Report:RefreshIfShown()
end

function Raffle:CanChangeTickets(r)
    if r.draw then
        U.Print("The winners of %s are already drawn, so tickets can't change. Start a new raffle first.", self:Name(r))
        return false
    end
    return true
end

function Raffle:AddTickets(r, who, n, why)
    if not self:CanChangeTickets(r) then return end
    local new = (r.adjust[who] or 0) + n
    r.adjust[who] = new ~= 0 and new or nil
    if r.hand then table.insert(r.hand, { ts = GetTimeStamp(), who = who, n = n }) end   -- when, for numbering by time
    local text = string.format("%s %d %s by hand", n > 0 and "added" or "removed", math.abs(n), math.abs(n) == 1 and "ticket" or "tickets")
    if why and why ~= "" then text = text .. ": " .. why end
    self:Change(r, who, text)
    U.Print("%s: %s %s.", self:Tag(r), who, text)
end

-- Asks how many tickets to add or remove by hand, then does it. Removing never takes more
-- than the person has.
function Raffle:AskTickets(r, who, add, why)
    if not self:CanChangeTickets(r) then return end
    local buyer = self:GetTally(r).byName[who]
    local has = buyer and buyer.tickets or 0
    local now = string.format("%s has %d %s now.", who, has, has == 1 and "ticket" or "tickets")
    if add then
        GT.Actions.AskNumber("Add raffle tickets", string.format("How many tickets do you want to add for %s?\n\n%s", who, now), function(n)
            self:AddTickets(r, who, n, why)
        end)
    else
        GT.Actions.AskNumber("Remove raffle tickets", string.format("How many tickets do you want to remove from %s?\n\n%s Their highest numbers come off, and those numbers are not used again.", who, now), function(n)
            local current = self:GetTally(r).byName[who]
            local most = current and current.tickets or 0
            if most == 0 then return end
            self:AddTickets(r, who, -math.min(n, most))
        end)
    end
end

function Raffle:SetExcluded(r, who, on)
    if not self:CanChangeTickets(r) then return end
    r.excluded[who] = on or nil
    self:Change(r, who, on and "left out of the draw" or "put back in the draw")
end

function Raffle:ResetHand(r, who)
    if not self:CanChangeTickets(r) then return end
    r.adjust[who], r.excluded[who] = nil, nil
    self:Change(r, who, "hand changes undone")
end

-- Sales ---------------------------------------------------------------------------

function Raffle:StartNow(r)
    if not self:HasSource(r) then
        U.Print("Choose how tickets are bought in the raffle settings first: pick a guild for bank deposits, or turn on mailed gold.")
        return
    end
    r.startText = ""
    r.startedAt = GetTimeStamp()
    r.endedAt = nil
    self:Dirty()
    U.Print("%s ticket sales started. They end %s.", self:Tag(r), NiceDate(self:EndTime(r)))
    self:PrintWarnings(r)
    GT.Report:RefreshIfShown()
end

function Raffle:EndNow(r)
    GT.Actions.Confirm("End ticket sales", zo_strformat("End ticket sales for <<1>> now? Payments after this moment won't buy tickets.", self:Name(r)), function()
        r.endedAt = GetTimeStamp()
        self:Dirty()
        U.Print("%s ticket sales ended. Click Draw winners in a minute, once the last deposits have arrived.", self:Tag(r))
        GT.Report:RefreshIfShown()
    end)
end

-- Puts a raffle on the past list. Its payments stay with it (they are locked once drawn).
function Raffle:Archive(r)
    local tally = self:GetTally(r)
    table.insert(self.sv.past, 1, { id = r.id, name = self:Name(r), guildId = r.guildId, prize = r.prize, price = r.price, start = self:StartTime(r), finish = self:EndTime(r),
        tickets = tally.total, gold = tally.gold, buyers = #tally.list, draw = r.draw, changes = r.changes })
    while #self.sv.past > 20 do table.remove(self.sv.past) end
    -- Its payments stay with it, so no raffle that comes later counts them again.
    for _, d in ipairs(self:Routing().byRaffle[r.id] or {}) do
        local key = Raffle.SeenKey(d)
        if not self.sv.assign[key] then self.sv.locked[key] = r.id end
    end
end

-- Puts this raffle away and sets up a new one in its place with the same settings, then opens
-- the raffle settings (Albert, 1.8.1).
function Raffle:NewRaffle(r)
    GT.Actions.Confirm("New raffle", zo_strformat("Put <<1>> away and set up a new raffle in its place? Its results are kept, and its settings (guild, price, winners, length) stay for the new raffle.", self:Name(r)), function()
        self:Archive(r)
        local fresh = self:MakeRaffle(r)
        fresh.mailSubject = r.mailSubject
        for i, o in ipairs(self.sv.raffles) do
            if o == r then self.sv.raffles[i] = fresh end
        end
        self.sv.current = fresh.id
        self.view = "raffle"
        self:Dirty()
        U.Print("Ready for a new raffle. Set it up here, then click Start sales now on the Raffle tab.")
        GT.Report:RefreshIfShown()
        self:OpenSettings()
    end)
end

-- A ticket price no raffle has yet, close to this one: 1,000 -> 1,001, 1,003, ...
function Raffle:FreePrice(base)
    local price = base % 2 == 0 and base + 1 or base + 2
    local function Taken(p)
        for _, o in ipairs(self.sv.raffles) do
            if o.price == p then return true end
            local both = math.floor(p / Gcd(p, o.price)) * o.price
            if both / math.max(p, o.price) <= COLLIDE_TICKETS then return true end
        end
        return false
    end
    while Taken(price) do price = price + 2 end
    return price
end

-- A second (third, ...) raffle that sells at the same time as the others (1.9.0).
function Raffle:AddRaffle()
    local from = self:Cur()
    local r = self:MakeRaffle(from)
    r.price = self:FreePrice(from.price)
    table.insert(self.sv.raffles, r)
    self.sv.current = r.id
    self.view = "raffle"
    self:Dirty()
    U.Print("New raffle added (%s a ticket, so bank deposits can tell the raffles apart). Give it its prizes, and a mail subject keyword if it takes mail, then click Start sales now.", U.FormatGold(r.price))
    GT.Report:RefreshIfShown()
    self:OpenSettings()
end

function Raffle:DeleteRaffle(r)
    GT.Actions.Confirm("Delete raffle", zo_strformat("Delete <<1>>? It hasn't started, so nothing is lost but its settings.", self:Name(r)), function()
        for i, o in ipairs(self.sv.raffles) do
            if o == r then table.remove(self.sv.raffles, i); break end
        end
        for key, id in pairs(self.sv.assign) do
            if id == r.id then self.sv.assign[key] = nil end
        end
        self.sv.current = self.sv.raffles[1].id
        self:Dirty()
        GT.Report:RefreshIfShown()
    end)
end

-- Draw ----------------------------------------------------------------------------

-- now: End and draw now skips the wait for late deposits and the mailbox check.
function Raffle:CanDraw(r, now)
    local status = self:Status(r)
    if status ~= "closed" then return false, "Ticket sales haven't ended yet." end
    if not now and r.useBank and r.guildId ~= 0 and GetTimeStamp() < self:EndTime(r) + DRAW_DELAY_S then return false, "Wait a minute after sales end, so the last deposits can arrive." end
    if not now and r.useMail and self.sv.mailCheckedAt < self:EndTime(r) then return false, "Open your mailbox once first, so gold mailed before the end counts." end
    if not self:IsCaughtUp(r) then return false, "The bank history is still loading (LibHistoire). Try again in a moment." end
    local open = self:OpenUnclear(r)
    if open > 0 then
        return false, string.format("%d unassigned %s might be for this raffle. Count or ignore %s first: New / other raffles > Unassigned payments.",
            open, open == 1 and "payment" or "payments", open == 1 and "it" or "them")
    end
    if self:GetTally(r).total == 0 then return false, "Nobody has any tickets." end
    return true
end

-- Picks one ticket among the tickets that may still win. Returns the result or nil.
function Raffle:DrawOne(r, tally, results)
    local won, voided, usedTickets = {}, {}, {}
    for _, res in ipairs(results) do
        if res.void then voided[res.who] = true else won[res.who] = true end
        usedTickets[res.ticket] = true
    end
    -- Eligible tickets: every ticket not drawn before; with one win per person, none of a
    -- winner's; never those of someone whose win was voided (they couldn't take the prize).
    local pool = {}
    local poolSize = 0
    for _, b in ipairs(tally.list) do
        if b.tickets > 0 and not voided[b.who] and not (r.oneWin and won[b.who]) then
            for _, range in ipairs(b.ranges) do
                for t = range[1], range[2] do
                    if not usedTickets[t] then
                        poolSize = poolSize + 1
                        pool[poolSize] = t
                    end
                end
            end
        end
    end
    if poolSize == 0 then return nil end
    local ticket = pool[math.random(poolSize)]
    for _, b in ipairs(tally.list) do
        for _, range in ipairs(b.ranges) do
            if ticket >= range[1] and ticket <= range[2] then
                local res = { n = #results + 1, ticket = ticket, who = b.who, from = b.from, to = b.to, tickets = b.tickets, pool = poolSize, slot = #results + 1 }
                if #b.ranges > 1 then res.numbers = Raffle.NumbersText(b.ranges) end
                results[#results + 1] = res
                return res
            end
        end
    end
end

-- Ends sales this second and draws at once (Albert, 1.6.3). Asks first.
function Raffle:EndAndDraw(r)
    local why
    if not self:IsCaughtUp(r) then why = "The bank history is still loading (LibHistoire). Try again in a moment." end
    if self:GetTally(r).total == 0 then why = "Nobody has any tickets yet." end
    if why then U.Print(why); return end
    GT.Actions.Confirm("End raffle and draw winners", zo_strformat("End ticket sales for <<1>> now and draw the winners right away?\n\nOnly tickets counted so far are in the draw: a deposit made in the last few seconds, or a mail you haven't opened yet, won't count. The draw can't be redone.", self:Name(r)), function()
        r.endedAt = GetTimeStamp() - 1
        self:Dirty()
        self.lastStatus[r.id] = "closed"
        self:Draw(r, true)
    end)
end

function Raffle:Draw(r, now)
    local ok, why = self:CanDraw(r, now)
    if not ok then U.Print(why); return end
    local tally = self:GetTally(r)
    local draw = { ts = GetTimeStamp(), total = tally.total, results = {} }
    for _ = 1, r.winners do
        if not self:DrawOne(r, tally, draw.results) then break end
    end
    r.draw = draw
    -- Every payment this raffle counted stays with it, whatever raffles come later.
    for _, d in ipairs(self:Routing().byRaffle[r.id] or {}) do
        local key = Raffle.SeenKey(d)
        if not self.sv.assign[key] then self.sv.locked[key] = r.id end
    end
    self:Dirty()
    local function After()
        if #draw.results < r.winners then
            U.Print("Only %d %s could be drawn: there aren't enough buyers.", #draw.results, #draw.results == 1 and "winner" or "winners")
        end
        U.Print("To announce the winners, click Winners to guild chat or Winners for Discord at the bottom of the Raffle tab.")
    end
    -- 1.34.0: with the draw show on, each winner is printed as the show reveals them.
    -- The report window hides during the show, so its list doesn't give the winners away
    -- on stream, and comes back on the Raffle tab when the show ends.
    if self.sv.show and #draw.results > 0 then
        GT.Report:Hide()
        self:StartShow(r, draw.results, { print = true, after = function() After(); self:Show(r) end })
    else
        for _, res in ipairs(draw.results) do self:PrintResult(r, res) end
        After()
        self:Show(r)
    end
end

function Raffle:PrintResult(r, res)
    if res.replaces then
        U.Print("%s draw %d (replaces %s): ticket #%d of %d, %s (tickets %s)%s.", self:Tag(r), res.n, res.replaces, res.ticket, r.draw.total, res.who, HeldText(res), self:ForPrize(r, res))
    else
        U.Print("%s draw %d: ticket #%d of %d, %s (tickets %s)%s.", self:Tag(r), res.n, res.ticket, r.draw.total, res.who, HeldText(res), self:ForPrize(r, res))
    end
end

-- A winner who can't take the prize: their win is voided and another ticket is drawn.
function Raffle:Redraw(r, who)
    GT.Actions.Confirm("Draw a replacement", zo_strformat("Void <<1>>'s win and draw a replacement winner?", who), function()
        local draw = r.draw
        local voided
        for _, res in ipairs(draw.results) do
            if res.who == who and not res.void then res.void = true; voided = res; break end
        end
        if not voided then return end
        local res = self:DrawOne(r, self:GetTally(r), draw.results)
        if res then
            res.replaces = who
            res.slot = Slot(voided)
            if self.sv.show then
                GT.Report:Hide()
                self:StartShow(r, { res }, { print = true, after = function() self:Show(r) end })
            else
                self:PrintResult(r, res)
            end
        else
            U.Print("No tickets are left to draw a replacement from.")
        end
        GT.Report:RefreshIfShown()
    end)
end

-- " for (prize)" when the prizes differ per winner, else "".
function Raffle:ForPrize(r, res)
    if #self:Prizes(r) < 2 then return "" end
    local prize = self:PrizeFor(r, Slot(res))
    return prize and (" for " .. prize) or ""
end

function Raffle:WinsOf(r, who)
    local wins = {}
    for _, res in ipairs(r.draw and r.draw.results or {}) do
        if res.who == who then wins[#wins + 1] = res end
    end
    return wins
end

-- Draw show (1.34.0) ----------------------------------------------------------------
-- Only shows results that are already drawn and saved: closing the window, a reload or a
-- crash in the middle changes nothing about who won. One winner at a time: countdown, the
-- buyers' names spinning and slowing down, then the winner. Next winner waits for your click.
local SHOW_NAME = "FurysGuildToolset_RaffleShow"
local SHOW_TICK_MS = 40

function Raffle:ShowControls()
    local win = FurysGuildToolset_RaffleShow
    return win, win:GetNamedChild("Title"), win:GetNamedChild("Prize"), win:GetNamedChild("Big"),
        win:GetNamedChild("Sub"), win:GetNamedChild("Next"), win:GetNamedChild("Done")
end

local function ShowSound(self, sound)
    if self.sv.showSound then PlaySound(sound) end
end

-- results: the results to reveal, in order. opts.print: print each winner in chat when shown;
-- opts.after: called once the show ends (or is closed).
function Raffle:StartShow(r, results, opts)
    local names = {}
    for _, b in ipairs(self:GetTally(r).list) do
        if b.tickets > 0 then names[#names + 1] = b.who end
    end
    if #names == 0 then
        for _, res in ipairs(results) do names[#names + 1] = res.who end
    end
    if self.showState then self:ShowClosed() end
    self.showState = { r = r, list = results, i = 0, names = names, print = opts and opts.print, after = opts and opts.after }
    local win, title = self:ShowControls()
    title:SetText(self:Name(r))
    U.ShowOnTop(win)
    self:ShowNext()
end

function Raffle:ReplayShow(r)
    local list = {}
    for _, res in ipairs(r.draw and r.draw.results or {}) do
        if not res.void then list[#list + 1] = res end
    end
    if #list == 0 then U.Print("This raffle has no winners to show."); return end
    table.sort(list, function(a, b) return Slot(a) < Slot(b) end)
    self:StartShow(r, list)
end

function Raffle:ShowNext()
    local st = self.showState
    if not st then return end
    st.i = st.i + 1
    local res = st.list[st.i]
    if not res then self:HideShow(); return end
    local _, _, prizeLabel, big, sub, nextButton, doneButton = self:ShowControls()
    nextButton:SetHidden(true)
    doneButton:SetHidden(true)
    local prize = self:PrizeFor(st.r, Slot(res))
    local count = #st.list > 1 and string.format("Winner %d of %d", st.i, #st.list) or "The winner"
    if res.replaces then count = "Replacement winner" end
    prizeLabel:SetText(prize and prize ~= "" and (count .. ": " .. prize) or count)
    big:SetColor(T.GOLD:UnpackRGBA())
    big:SetText("")
    sub:SetText(string.format("%d tickets in the draw", st.r.draw and st.r.draw.total or 0))
    st.res = res
    st.phase = "count"
    st.start = GetGameTimeMilliseconds()
    st.shown = nil
    EVENT_MANAGER:RegisterForUpdate(SHOW_NAME, SHOW_TICK_MS, function() self:ShowTick() end)
    self:ShowTick()
end

function Raffle:ShowTick()
    local st = self.showState
    if not st then self:StopShowTimer(); return end
    local _, _, _, big, sub = self:ShowControls()
    local now = GetGameTimeMilliseconds()
    if st.phase == "count" then
        local left = self.sv.showCountdown - math.floor((now - st.start) / 1000)
        if left > 0 then
            if st.shown ~= left then
                st.shown = left
                big:SetColor(T.VIOLET:UnpackRGBA())
                big:SetText(tostring(left))
                ShowSound(self, SOUNDS.DEFAULT_CLICK)
            end
            return
        end
        st.phase, st.spinStart, st.nextFlip = "spin", now, now
        big:SetColor(T.TEXT:UnpackRGBA())
    end
    if st.phase == "spin" then
        local spinMs = self.sv.showSpin * 1000
        local done = (now - st.spinStart) / spinMs
        if done >= 1 then
            self:Reveal()
            return
        end
        if now >= st.nextFlip then
            local total = st.r.draw and st.r.draw.total or 1
            big:SetText(st.names[math.random(#st.names)])
            sub:SetText(string.format("Ticket #%d", math.random(math.max(total, 1))))
            ShowSound(self, SOUNDS.DEFAULT_CLICK)
            -- Starts fast and slows down toward the end.
            st.nextFlip = now + 60 + math.floor(done * done * 450)
        end
    end
end

function Raffle:Reveal()
    local st = self.showState
    self:StopShowTimer()
    local res = st.res
    st.phase = "shown"
    st.revealed = st.i
    local _, _, _, big, sub, nextButton, doneButton = self:ShowControls()
    big:SetColor(T.GOLD:UnpackRGBA())
    big:SetText(res.who)
    sub:SetText(string.format("Ticket #%d of %d  |cB4B0D8(held tickets %s)|r", res.ticket, st.r.draw and st.r.draw.total or 0, HeldText(res)))
    ShowSound(self, SOUNDS.LEVEL_UP)
    if st.print then self:PrintResult(st.r, res) end
    nextButton:SetHidden(st.i >= #st.list)
    doneButton:SetHidden(false)
end

function Raffle:StopShowTimer()
    EVENT_MANAGER:UnregisterForUpdate(SHOW_NAME)
end

function Raffle:HideShow()
    SCENE_MANAGER:HideTopLevel(FurysGuildToolset_RaffleShow)
    self:ShowClosed()   -- the window's OnHide calls it too; it only runs once
end

-- The window closed (button, X or Esc): winners not revealed yet go to chat, so nothing is lost.
function Raffle:ShowClosed()
    self:StopShowTimer()
    local st = self.showState
    if not st then return end
    self.showState = nil
    if st.print then
        for i = (st.revealed or 0) + 1, #st.list do self:PrintResult(st.r, st.list[i]) end
    end
    if st.after then st.after() end
end

-- Guild chat ----------------------------------------------------------------------
-- The addon can't send chat: each part goes in the guild chat box and you press Enter.

local function SplitParts(header, entries, closing)
    local parts, line = {}, header
    for _, entry in ipairs(entries) do
        local sep = (line == "") and "" or " "
        if #line + #sep + #entry > MAX_CHAT then
            if line ~= "" then parts[#parts + 1] = line end
            line, sep = "", ""
        end
        line = line .. sep .. entry
    end
    if closing then
        if #line + #closing + 1 <= MAX_CHAT then line = line .. " " .. closing
        else parts[#parts + 1] = line; line = closing end
    end
    parts[#parts + 1] = line
    return parts
end

-- Prizes: one per line or separated by ";" (1.7.0). The first goes to the winner of draw 1,
-- and so on. A single prize is everyone's prize.
function Raffle:Prizes(r)
    local list = {}
    for raw in string.gmatch(r.prize or "", "[^;\n]+") do
        local prize = zo_strtrim(raw)
        if prize ~= "" then list[#list + 1] = prize end
    end
    return list
end

function Raffle:PrizeFor(r, slot)
    local list = self:Prizes(r)
    if #list == 1 then return list[1] end
    return list[slot]
end

-- The raffle's name in posts: its prize, "4 prizes", or "the raffle".
function Raffle:PrizeText(r)
    local list = self:Prizes(r)
    if #list == 1 then return list[1] end
    if #list > 1 then return string.format("%d prizes", #list) end
    return "the raffle"
end

-- "1) A, 2) B" for posts.
function Raffle:PrizeListText(r)
    local list, parts = self:Prizes(r), {}
    for i, prize in ipairs(list) do parts[#parts + 1] = string.format("%d) %s", i, prize) end
    return table.concat(parts, ", ")
end

function Raffle:SetPrizes(r, text)
    self:SetValue(r, "prize", zo_strtrim(text or ""))
    local count = #self:Prizes(r)
    if count > 1 and count ~= r.winners then
        r.winners = math.min(20, count)
        U.Print("%s: %d prizes listed, so the number of winners is now %d.", self:Tag(r), count, r.winners)
    end
end

-- How to buy, for posts. With another raffle selling at the same time, says exactly what makes
-- a payment count for this one.
function Raffle:Ways(r)
    local ways = {}
    if r.useBank and r.guildId ~= 0 then
        ways[#ways + 1] = string.format("deposit %sgold into the %s guild bank", self:Shares(r, false) and "an exact multiple of the ticket price in " or "", U.GuildName(r.guildId))
    end
    if r.useMail then
        local word = zo_strtrim(r.mailSubject or "")
        ways[#ways + 1] = string.format("mail gold to %s%s", GetDisplayName(), word ~= "" and string.format(" with \"%s\" in the subject", word) or "")
    end
    return ways
end

function Raffle:Rules(r)
    local rules = string.format("%d %s%s.", r.winners, r.winners == 1 and "winner" or "winners", (r.oneWin and r.winners > 1) and ", one win per person" or "")
    if r.maxTickets > 0 then rules = rules .. string.format(" Up to %d tickets each.", r.maxTickets) end
    return rules
end

function Raffle:AnnounceParts(r)
    local start, finish = self:StartTime(r), self:EndTime(r)
    local now = GetTimeStamp()
    local when
    if now < start then
        when = string.format("Sales open in %s and run for %s.", NiceLeft(start - now), NiceLeft(finish - start))
    else
        when = string.format("Sales end in %s.", NiceLeft(finish - now))
    end
    local prizes = #self:Prizes(r) > 1 and ("! Prizes: " .. self:PrizeListText(r) .. ".") or (" for " .. self:PrizeText(r) .. "!")
    -- 1.30.1 (Albert): short wording, so the announcement with its totals fits one chat message.
    -- Each sentence is its own entry: if long prizes push it over, it splits between sentences.
    local entries = {
        "RAFFLE" .. prizes,
        string.format("Tickets are %s each: %s, in multiples of %s.", U.FormatGold(r.price), table.concat(self:Ways(r), " or "), U.FormatGold(r.price)),
        when,
        self:Rules(r),
    }
    -- 1.30.0 (Albert): the running totals go out with the announcement.
    if self:GetTally(r).total > 0 then entries[#entries + 1] = "So far: " .. self:TotalsText(r) .. "." end
    return SplitParts("", entries, "Good luck!")
end

function Raffle:Buyers(r)
    local buyers = 0
    for _, b in ipairs(self:GetTally(r).list) do if b.tickets > 0 then buyers = buyers + 1 end end
    return buyers
end

-- The running totals (1.30.0): "705 tickets, 14 buyers, 680,000g". Tickets are
-- those in the draw (bought or given by hand), buyers are the people holding at least one, and
-- the gold is everything paid for this raffle. After the draw, tickets is the number drawn from.
function Raffle:TotalsText(r)
    local tally = self:GetTally(r)
    local tickets = r.draw and r.draw.total or tally.total
    local buyers = self:Buyers(r)
    return string.format("%s %s, %s %s, %s", ZO_CommaDelimitNumber(tickets), tickets == 1 and "ticket" or "tickets",
        ZO_CommaDelimitNumber(buyers), buyers == 1 and "buyer" or "buyers", U.FormatGold(tally.gold))
end

function Raffle:ResultParts(r)
    local draw = r.draw
    local header = string.format("Raffle draw for %s: %s.", self:PrizeText(r), self:TotalsText(r))
    local entries = {}
    for _, res in ipairs(draw.results) do
        if res.void then
            entries[#entries + 1] = string.format("Draw %d: %s (could not take the prize).", res.n, res.who)
        else
            entries[#entries + 1] = string.format("Draw %d: ticket #%d goes to %s (tickets %s)%s%s.", res.n, res.ticket, res.who, HeldText(res),
                self:ForPrize(r, res), res.replaces and (", replacing " .. res.replaces) or "")
        end
    end
    return SplitParts(header, entries, "Congratulations, and thanks to everyone who bought tickets!")
end

-- Discord ---------------------------------------------------------------------------
-- The same posts as several lines with Discord's **bold**, shown in the copy window.

function Raffle:ShowCopy(text, what)
    local Report = GT.Report
    Report.exportParts = { text }
    Report.exportTitles = nil
    Report.exportIndex = 1
    U.ShowOnTop(FurysGuildToolset_Export)
    Report:ShowExportPart(0)
    U.Print("%s is in the copy window. Click Select all, press Ctrl+C, and paste it into Discord.", what)
end

function Raffle:DiscordAnnounce(r)
    local lines = { string.format("**RAFFLE: %s**", self:PrizeText(r)) }
    local list = self:Prizes(r)
    if #list > 1 then
        lines[#lines + 1] = "Prizes:"
        for i, prize in ipairs(list) do lines[#lines + 1] = string.format("%d. %s", i, prize) end
    end
    lines[#lines + 1] = string.format("Tickets: **%s** each. To buy, %s. Every %s in one deposit or mail is one ticket, so send a multiple of it.",
        U.FormatGold(r.price), table.concat(self:Ways(r), " or "), U.FormatGold(r.price))
    -- Discord shows <t:...> timestamps in each reader's own time zone.
    local finish = self:EndTime(r)
    if GetTimeStamp() < self:StartTime(r) then
        lines[#lines + 1] = string.format("Sales open <t:%d:F> and end <t:%d:F>.", self:StartTime(r), finish)
    else
        lines[#lines + 1] = string.format("Sales end <t:%d:F> (<t:%d:R>).", finish, finish)
    end
    lines[#lines + 1] = self:Rules(r) .. " Good luck!"
    -- 1.20.0: who has tickets so far, so buyers can see theirs were counted.
    local tally = self:GetTally(r)
    if tally.total > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("**So far: %s**", self:TotalsText(r))
        for _, b in ipairs(tally.list) do
            if b.tickets > 0 then
                lines[#lines + 1] = string.format("%s: %d (%s)", b.who, b.tickets, Raffle.NumbersText(b.ranges))
            end
        end
    end
    return table.concat(lines, "\n")
end

function Raffle:DiscordResults(r)
    local draw = r.draw
    local lines = { string.format("**Raffle results: %s**", self:PrizeText(r)), self:TotalsText(r) .. ".", "" }
    for _, res in ipairs(draw.results) do
        local prize = self:PrizeFor(r, Slot(res))
        if res.void then
            lines[#lines + 1] = string.format("~~Draw %d: %s~~ (could not take the prize)", res.n, res.who)
        else
            lines[#lines + 1] = string.format("Draw %d: **%s**%s, ticket #%d (held tickets %s)%s", res.n, res.who,
                (#self:Prizes(r) > 1 and prize) and (" wins **" .. prize .. "**") or "", res.ticket, HeldText(res),
                res.replaces and (", replacing " .. res.replaces) or "")
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Congratulations, and thanks to everyone who bought tickets!"
    return table.concat(lines, "\n")
end

function Raffle:Discord(r)
    local status = self:Status(r)
    if status == "drawn" then
        self:ShowCopy(self:DiscordResults(r), "The winners post")
    elseif self:HasSource(r) and (status == "selling" or status == "scheduled") then
        self:ShowCopy(self:DiscordAnnounce(r), "The raffle announcement")
    end
end

-- With a guild: into that guild's chat box. Without one: in the copy window, to paste anywhere
-- (Discord, a group chat).
function Raffle:Post(r, parts)
    local guildId = r.guildId
    if guildId ~= 0 and U.IsPlayerInGuild(guildId) then
        GT:GetModule("trader"):PostToGuild(guildId, parts)
        return
    end
    local Report = GT.Report
    Report.exportParts = { table.concat(parts, "\n") }
    Report.exportTitles = nil
    Report.exportIndex = 1
    U.ShowOnTop(FurysGuildToolset_Export)
    Report:ShowExportPart(0)
    U.Print("No raffle guild is set, so the text is in the copy window. Click Copy, then paste it where your group chats.")
end

function Raffle:Announce(r)
    local status = self:Status(r)
    if status ~= "scheduled" and status ~= "selling" then
        U.Print("Start ticket sales first (or set a start time in the raffle settings).")
        return
    end
    if not self:HasSource(r) then
        U.Print("Choose how tickets are bought in the raffle settings first.")
        return
    end
    self:Post(r, self:AnnounceParts(r))
end

function Raffle:PostResults(r)
    self:Post(r, self:ResultParts(r))
end

-- Report tab ----------------------------------------------------------------------

local STATUS_TEXT = {
    setup = "|cB4B0D8Not started.|r Set it up with Raffle settings, then click Start sales now.",
    scheduled = "|cFFC857Sales start in %s|r (%s).",
    selling = "|cF2C94CSales end in %s|r (%s).",
    closed = "|cFFA45CSales ended %s.|r",
    drawn = "|c5EE6A0Winners drawn %s.|r",
}

function Raffle:TabSummary()
    if self.view == "unassigned" then return self:UnassignedSummary() end
    local r = self:Cur()
    local status = self:Status(r)
    local now = GetTimeStamp()
    local head
    if status == "setup" then head = STATUS_TEXT.setup
    elseif status == "scheduled" then head = string.format(STATUS_TEXT.scheduled, Clock(self:StartTime(r) - now), NiceDate(self:StartTime(r)))
    elseif status == "selling" then head = string.format(STATUS_TEXT.selling, Clock(self:EndTime(r) - now), NiceDate(self:EndTime(r)))
    elseif status == "closed" then head = string.format(STATUS_TEXT.closed, NiceDate(self:EndTime(r)))
    else head = string.format(STATUS_TEXT.drawn, NiceDate(r.draw.ts)) end
    if self:Multi() then head = string.format("|cECEAF8%s|r (%d raffles): %s", self:Name(r), #self.sv.raffles, head) end
    local open = self:OpenUnclear()
    local extra = open > 0 and string.format("  |cFFA45C%d unassigned %s: New / other raffles > Unassigned payments.|r", open, open == 1 and "payment" or "payments") or ""
    if not self:HasSource(r) then return head .. extra end
    local tally = self:GetTally(r)
    local loading = self:IsCaughtUp(r) and "" or "  |cFFC857Bank history still loading.|r"
    local where = {}
    if r.useBank and r.guildId ~= 0 then where[#where + 1] = U.GuildName(r.guildId) .. " bank" end
    if r.useMail then where[#where + 1] = "mail" .. (Keyword(r) ~= "" and string.format(" (\"%s\")", r.mailSubject) or "") end
    local warnings = ""
    for _, text in ipairs(self:Warnings(r)) do warnings = warnings .. "  |cFFA45C" .. text .. "|r" end
    -- 1.29.0: mailed ticket gold you passed on to the bank, and what you still hold.
    local owed = r.passMail and self:Routing().owed or 0
    if tally.passed > 0 then extra = extra .. string.format("  |cB4B0D8Mailed gold you put in the bank: %s (counts for the senders, not you).|r", U.FormatGold(tally.passed)) end
    if owed > 0 then extra = extra .. string.format("  |cFFC857Mailed gold you still hold: %s. Your next bank deposits pass it on before they buy you tickets.|r", U.FormatGold(owed)) end
    -- 1.30.0 (Albert): the running totals come first, right after the countdown.
    local sold = ""
    if status == "selling" then sold = string.format("  |cECEAF8Sold so far: %s.|r", self:TotalsText(r))
    elseif status == "closed" or status == "drawn" then sold = string.format("  |cECEAF8Sold: %s.|r", self:TotalsText(r)) end
    return string.format("%s%s  %s: %s, %s a ticket, %d %s%s.%s", head, sold,
        table.concat(where, " + "), self:PrizeText(r),
        U.FormatGold(r.price), r.winners, r.winners == 1 and "winner" or "winners", (r.oneWin and r.winners > 1) and " (one each)" or "",
        loading) .. self:PrizeWarning(r) .. warnings .. extra
end

-- A warning on the top line when several prizes are listed but the number of winners differs.
function Raffle:PrizeWarning(r)
    local count = #self:Prizes(r)
    if count < 2 or count == r.winners then return "" end
    return string.format("  |cFFA45C%d prizes listed for %d winners.|r", count, r.winners)
end

function Raffle:ResultText(r, b)
    local parts = {}
    for _, res in ipairs(self:WinsOf(r, b.who)) do
        local prize = #self:Prizes(r) > 1 and self:PrizeFor(r, Slot(res))
        parts[#parts + 1] = res.void and string.format("|c8A86B0draw %d void|r", res.n)
            or (prize and string.format("|cF2C94CWON %s|r", prize) or string.format("|cF2C94CWON draw %d|r", res.n))
    end
    if #parts > 0 then return table.concat(parts, ", ") end
    if b.excluded then return "|cFF6B86left out|r" end
    return ""
end

function Raffle:RowTooltip(r, b)
    local lines = { b.who }
    if #b.ranges > 0 then lines[#lines + 1] = "Tickets " .. Raffle.NumbersText(b.ranges) end
    lines[#lines + 1] = string.format("Paid %s: %d bank %s, %d %s.", U.FormatGold(b.gold), b.deposits, b.deposits == 1 and "deposit" or "deposits",
        b.mails, b.mails == 1 and "mail" or "mails")
    if b.overCap > 0 then lines[#lines + 1] = string.format("%d tickets over the cap of %d.", b.overCap, r.maxTickets) end
    if b.refund > 0 then lines[#lines + 1] = string.format("Not used: %s (each payment's remainder below the ticket price%s).", U.FormatGold(b.refund), b.overCap > 0 and ", and gold over the limit" or "") end
    if zo_strlower(b.who) == zo_strlower(GetDisplayName()) then
        local tally, owed = self:GetTally(r), self:Routing().owed
        if tally.passed > 0 then lines[#lines + 1] = string.format("%s of your bank deposits was ticket gold mailed to you. It counts for the senders, not for you.", U.FormatGold(tally.passed)) end
        if owed > 0 then lines[#lines + 1] = string.format("You still hold %s of mailed ticket gold. Your next deposits pass it on first.", U.FormatGold(owed)) end
    end
    for _, c in ipairs(r.changes) do
        if c.who == b.who then lines[#lines + 1] = string.format("%s: %s", U.FormatDate(c.ts), c.text) end
    end
    for _, res in ipairs(self:WinsOf(r, b.who)) do
        lines[#lines + 1] = string.format("Draw %d: ticket #%d of %d%s%s.", res.n, res.ticket, r.draw.total, self:ForPrize(r, res), res.void and " (voided)" or "")
    end
    return table.concat(lines, "\n")
end

function Raffle:RowMenu(r, b)
    local items = GT.Report.ContactItems(b.who)
    for _, res in ipairs(self:WinsOf(r, b.who)) do
        if not res.void then
            items[#items + 1] = { label = "Mail prize to " .. b.who, fn = function() self:MailWinner(r, res) end }
            items[#items + 1] = { label = "Void win, draw a replacement", fn = function() self:Redraw(r, b.who) end }
            break
        end
    end
    if not r.draw then
        -- 1.29.0 (Albert): a box to type the amount, instead of Add 1 / Add 5 / Remove 1.
        items[#items + 1] = { label = "Add tickets...", fn = function() self:AskTickets(r, b.who, true) end }
        if b.tickets > 0 then items[#items + 1] = { label = "Remove tickets...", fn = function() self:AskTickets(r, b.who, false) end } end
        items[#items + 1] = { label = b.excluded and "Put back in the draw" or "Leave out of the draw", fn = function() self:SetExcluded(r, b.who, not b.excluded) end }
        if b.adjust ~= 0 or b.excluded then items[#items + 1] = { label = "Undo hand changes", fn = function() self:ResetHand(r, b.who) end } end
    end
    return items
end

function Raffle:MailWinner(r, res)
    local prize = self:PrizeFor(r, Slot(res)) or self:PrizeText(r)
    local body = string.format("Congratulations! Your ticket #%d won draw %d of the raffle. Your prize: %s.\n\nYour code: ", res.ticket, res.n, prize)
    GT.Actions.Warn(res.who, "You won the raffle!", body, "mail")
end

Raffle.columns = {
    { title = "Buyer", width = 190, tip = "Who deposited or mailed gold during the sale, or got tickets by hand. In order of their first payment." },
    { title = "Tickets", width = 80, tip = "Tickets in the draw: gold / ticket price (up to the cap), plus or minus changes made by hand." },
    { title = "Numbers", width = 160, tip = "This buyer's ticket numbers. The draw picks a random number. New raffles (1.20.0) number tickets in the order they were bought, so someone who buys again later gets later numbers; hover a row for all of them." },
    { title = "Gold", width = 120, tip = "Gold deposited or mailed during the sale. Gold mailed to you that you then put in the guild bank counts once, for whoever mailed it." },
    { title = "Not used", width = 110, tip = "Gold that didn't buy a ticket: each payment's remainder below the ticket price (dropped, not carried over), and gold over the per-person limit." },
    { title = "Chance", width = 80, tip = "Share of all tickets." },
    { title = "Last payment", width = 130 },
    { title = "Result", width = 150, tip = "Who won which prize." },
}

Raffle.unassignedColumns = {
    { title = "Paid by", width = 190, tip = "Who deposited or mailed the gold." },
    { title = "Gold", width = 100 },
    { title = "How", width = 160, tip = "The guild bank it went into, or mail." },
    { title = "When", width = 150 },
    { title = "Mail subject", width = 170 },
    { title = "Why it's here", width = 250, tip = "Why it couldn't be counted for one raffle, or what you decided." },
}

function Raffle:TabRows()
    if self.view == "unassigned" then return self:UnassignedRows() end
    local r = self:Cur()
    if not self:HasSource(r) then return {} end
    local tally = self:GetTally(r)
    local rows = {}
    for _, b in ipairs(tally.list) do
        local adjust = b.adjust ~= 0 and string.format(" |cB4B0D8(%+d)|r", b.adjust) or ""
        local row = {
            cells = {
                b.who,
                tostring(b.tickets) .. adjust,
                Raffle.NumbersText(b.ranges),
                b.gold > 0 and U.FormatGold(b.gold) or "",
                b.refund > 0 and U.FormatGold(b.refund) or "",
                tally.total > 0 and string.format("%.1f%%", b.tickets * 100 / tally.total) or "",
                b.last > 0 and U.FormatDate(b.last) or "",
                self:ResultText(r, b),
            },
            tooltip = self:RowTooltip(r, b),
        }
        rows[#rows + 1] = GT.Report.AddMenu(row, self:RowMenu(r, b))
    end
    return rows
end

-- Unassigned payments ----------------------------------------------------------------

function Raffle:UnassignedSummary()
    local open = self:OpenUnclear()
    local head = "|cECEAF8Unassigned payments|r: gold that more than one raffle could take, and it's unclear which."
    if open == 0 then return head .. "  |c5EE6A0Nothing left to decide.|r" end
    return string.format("%s  |cFFA45C%d to decide.|r Right-click one to count it for a raffle or ignore it.", head, open)
end

local function PaymentWhere(d)
    if d.src == "mail" then return "mail" end
    return U.GuildName(d.g) .. " bank"
end

function Raffle:UnassignedState(u)
    if u.how == "ignored" then return "|c8A86B0ignored by you|r" end
    if u.how == "hand" then
        return u.r and string.format("|c5EE6A0counted for %s by you|r", self:Name(u.r)) or "|c8A86B0counted for a raffle you put away|r"
    end
    return "|cFFA45C" .. u.why .. "|r"
end

function Raffle:UnassignedMenu(u)
    local d = u.d
    local items = GT.Report.ContactItems(d.who)
    if u.how == "hand" and (not u.r or u.r.draw) then return items end   -- that raffle is drawn or put away: keep it
    for _, r in ipairs(u.candidates) do
        if not r.draw and u.r ~= r then
            local n = math.floor(d.amt / math.max(1, r.price))
            items[#items + 1] = { label = string.format("Count for %s (%d %s)", self:Name(r), n, n == 1 and "ticket" or "tickets"),
                fn = function() self:Assign(d, r.id) end }
        end
    end
    if u.how ~= "ignored" then
        items[#items + 1] = { label = "Ignore (not a raffle payment)", fn = function() self:Assign(d, "ignore") end }
    end
    if u.how then
        items[#items + 1] = { label = "Undo: decide again", fn = function() self:Assign(d, nil) end }
    end
    return items
end

function Raffle:UnassignedRows()
    local rows = {}
    local list = {}
    for _, u in ipairs(self:Routing().unclear) do list[#list + 1] = u end
    -- Still to decide first, newest first.
    table.sort(list, function(a, b)
        if (a.why ~= nil) ~= (b.why ~= nil) then return a.why ~= nil end
        return a.d.ts > b.d.ts
    end)
    for _, u in ipairs(list) do
        local d = u.d
        local names = {}
        for _, r in ipairs(u.candidates) do
            names[#names + 1] = string.format("%s (%s a ticket%s)", self:Name(r), U.FormatGold(r.price), Keyword(r) ~= "" and string.format(", keyword \"%s\"", r.mailSubject) or "")
        end
        local row = {
            cells = { d.who, U.FormatGold(d.amt), PaymentWhere(d), U.FormatDate(d.ts), d.subj or "", self:UnassignedState(u) },
            tooltip = string.format("%s paid %s by %s on %s.\nRaffles selling then: %s.", d.who, U.FormatGold(d.amt), PaymentWhere(d), U.FormatDate(d.ts),
                #names > 0 and table.concat(names, "; ") or "none"),
        }
        rows[#rows + 1] = GT.Report.AddMenu(row, self:UnassignedMenu(u))
    end
    return rows
end

function Raffle:TabExportLines()
    if self.view == "unassigned" then
        local lines = { "Paid by\tGold\tHow\tWhen\tMail subject\tWhy" }
        for _, u in ipairs(self:Routing().unclear) do
            local d = u.d
            lines[#lines + 1] = table.concat({ d.who, d.amt, PaymentWhere(d), U.FormatDate(d.ts), d.subj or "",
                u.why or (u.how == "ignored" and "ignored" or ("counted for " .. (u.r and self:Name(u.r) or "a past raffle"))) }, "\t")
        end
        return lines
    end
    local r = self:Cur()
    local tally = self:GetTally(r)
    local lines = { "Buyer\tTickets\tTicket numbers\tGold\tNot used\tBank deposits\tMails\tHand changes\tLeft out\tResult" }
    for _, b in ipairs(tally.list) do
        local results = {}
        for _, res in ipairs(self:WinsOf(r, b.who)) do results[#results + 1] = string.format("draw %d ticket %d%s", res.n, res.ticket, res.void and " void" or "") end
        lines[#lines + 1] = table.concat({ b.who, b.tickets, Raffle.NumbersText(b.ranges), b.gold, b.refund, b.deposits, b.mails, b.adjust,
            b.excluded and "yes" or "", table.concat(results, "; ") }, "\t")
    end
    if r.draw then
        lines[#lines + 1] = ""
        for _, part in ipairs(self:ResultParts(r)) do lines[#lines + 1] = part end
    end
    return lines
end

-- Members tab (1.19.0): give a member raffle tickets as a gift from you, for example a helper.
-- Logged like any hand change ("gift from @you"), so it shows in the buyer's hover text.
function Raffle:GiftRaffles()
    if not self.sv.enabled then return {} end
    local list = {}
    for _, r in ipairs(self.sv.raffles) do
        if not r.draw then list[#list + 1] = r end
    end
    return list
end

function Raffle:GiftMenu(control, who)
    local list = self:GiftRaffles()
    local why = "gift from " .. GetDisplayName()
    ClearMenu()
    for _, r in ipairs(list) do
        local prefix = #list > 1 and (self:Name(r) .. ": ") or ""
        for _, n in ipairs({ 1, 2, 5, 10 }) do
            AddMenuItem(string.format("%sGive %d %s", prefix, n, n == 1 and "ticket" or "tickets"), function() self:AddTickets(r, who, n, why) end)
        end
        AddMenuItem(prefix .. "Give another amount...", function() self:AskTickets(r, who, true, why) end)
    end
    ShowMenu(control)
end

-- The "New / other raffles" button: switch raffles, the Unassigned list, new raffles.
function Raffle:RafflesMenu(control)
    local r = self:Cur()
    ClearMenu()
    if self:Multi() then
        for _, o in ipairs(self.sv.raffles) do
            local mark = (o == r and self.view == "raffle") and "> " or ""
            AddMenuItem(string.format("%sShow %s (%s)", mark, self:Name(o), self:StatusShort(o)), function() self:Show(o) end)
        end
    end
    local open = self:OpenUnclear()
    if self:Multi() or #self:Routing().unclear > 0 then
        AddMenuItem(string.format("%sUnassigned payments (%d to decide)", self.view == "unassigned" and "> " or "", open), function()
            self.view = "unassigned"
            GT.Report:RefreshIfShown()
        end)
    end
    if self:Status(r) ~= "setup" then
        AddMenuItem(string.format("New raffle: put %s away and set up the next one", self:Name(r)), function() self:NewRaffle(r) end)
    end
    AddMenuItem("Add another raffle to sell at the same time", function() self:AddRaffle() end)
    if self:Multi() and self:Status(r) == "setup" then
        AddMenuItem(string.format("Delete %s (not started)", self:Name(r)), function() self:DeleteRaffle(r) end)
    end
    AddMenuItem("Raffle settings", function() self:OpenSettings() end)
    ShowMenu(control)
end

function Raffle:TabFooter()
    local menu = { label = "New / other raffles", tip = "New raffle (puts this one away and opens the raffle settings), another raffle to sell at the same time, switching between raffles, and Unassigned payments.",
        fn = function(control) self:RafflesMenu(control) end }
    if self.view == "unassigned" then
        return { { label = "Back to raffle", tip = "Shows the raffle again.", fn = function() self:Show(self:Cur()) end }, menu }
    end
    local r = self:Cur()
    local status = self:Status(r)
    local footer = {}
    if status == "setup" then
        footer[#footer + 1] = { label = "Raffle settings", tip = "Opens the raffle setup: guild, prizes, ticket price, winners, start and length.", fn = function() self:OpenSettings() end }
        footer[#footer + 1] = { label = "Start sales now", tip = "Starts ticket sales now. They run for the length set in the raffle settings.", fn = function() self:StartNow(r) end }
    elseif status == "selling" then
        footer[#footer + 1] = { label = "End sales now", tip = "Ends ticket sales early, so you can draw a minute later. Asks first.", fn = function() self:EndNow(r) end }
        footer[#footer + 1] = { label = "End and draw now", tip = "Ends ticket sales and draws the winners right away, with the tickets counted so far. Asks first. The draw can't be redone.", fn = function() self:EndAndDraw(r) end }
    end
    if status == "scheduled" or status == "selling" then
        footer[#footer + 1] = { label = "Announce in guild", tip = "Puts a raffle announcement (prizes, price, how to buy, time left) in the guild chat box for you to press Enter. Without a raffle guild, shows it to copy.", fn = function() self:Announce(r) end }
        footer[#footer + 1] = { label = "Text for Discord", tip = "Shows the raffle announcement as text to copy and paste into Discord.", fn = function() self:Discord(r) end }
    end
    if status == "closed" then
        footer[#footer + 1] = { label = "Draw winners", tip = function() local ok, why = self:CanDraw(r); return ok and "Draws the winners now. Each draw picks a random ticket. This can't be redone." or why end, fn = function() self:Draw(r) end }
    end
    if status == "drawn" then
        footer[#footer + 1] = { label = "Winners to guild chat", tip = "Puts the winners (and their prizes) in the guild chat box, one part at a time, for you to press Enter. Without a raffle guild, shows them to copy.", fn = function() self:PostResults(r) end }
        footer[#footer + 1] = { label = "Winners for Discord", tip = "Shows the winners and their prizes as text to copy and paste into Discord.", fn = function() self:Discord(r) end }
        if self.sv.show then
            footer[#footer + 1] = { label = "Replay draw show", tip = "Plays the draw show again with the same winners (nothing is drawn again), for example on stream.",
                fn = function() self:ReplayShow(r) end }
        end
    end
    footer[#footer + 1] = menu
    return footer
end

function Raffle:RegisterTab()
    GT.Report:RegisterTab({
        id = "raffle",
        title = function() return self:TabTitle() end,
        tip = "Raffle tickets bought with gold deposited into a guild bank or mailed to you, and the winners draw.",
        GetOffText = function() return GT:FeatureOffText(self.sv.enabled, "The raffle") end,
        about = {
            "Runs a guild raffle: members buy tickets with gold put in a guild bank or mailed to you, and you draw the winners.",
            "Set the prize, the ticket price and the sale times on the Raffle settings page. Ticket buyers are listed here as their gold arrives.",
        },
        emptyText = "No tickets yet.",
        GetSummary = function() return self:TabSummary() end,
        GetRows = function() return self:TabRows() end,
        columns = function() return self.view == "unassigned" and Raffle.unassignedColumns or Raffle.columns end,
        footer = function() return self:TabFooter() end,
        GetExportLines = function() return self:TabExportLines() end,
    })
end

-- /gt raffle add @name 3 [reason], /gt raffle remove @name 3 [reason] -----------------
-- They change tickets in the raffle shown on the Raffle tab.

function Raffle:Slash(args)
    local verb, rest = args:match("^(%S+)%s*(.*)$")
    verb = verb and zo_strlower(verb) or ""
    if verb == "add" or verb == "remove" then
        local name, count, why = rest:match("^(%S+)%s+(%d+)%s*(.*)$")
        if not name then
            U.Print("Usage: /gt raffle %s @name 3 (optional reason)", verb)
            return
        end
        if not self.sv.enabled then U.Print("The raffle is turned off. Turn it on in the raffle settings."); return end
        local r = self:Cur()
        local n = tonumber(count)
        if verb == "remove" then n = -n end
        local found, close = self:FindAccount(r, name)
        if found then
            self:AddTickets(r, found, n, why)
            return
        end
        local typed = U.NormalizeName(name)
        local hint = #close > 0 and ("\n\nDid you mean: " .. table.concat(close, ", ") .. "?") or ""
        U.Print("%s isn't a raffle buyer, a member of your guilds or a friend.%s", typed, #close > 0 and (" Did you mean: " .. table.concat(close, ", ") .. "?") or "")
        GT.Actions.Confirm("Unknown account", string.format("%s isn't a raffle buyer, a member of any of your guilds or on your friends list. Check the spelling.%s\n\nAdd the tickets to %s anyway?", typed, hint, typed), function()
            self:AddTickets(r, typed, n, why)
        end)
    else
        GT.Report:Show("raffle")
    end
end

-- Settings ------------------------------------------------------------------------

function Raffle:GuildChoices()
    local names, ids = { "(no guild)" }, { 0 }
    for _, guildId in ipairs(U.GetGuildIds()) do
        names[#names + 1] = U.GuildName(guildId)
        ids[#ids + 1] = guildId
    end
    return names, ids
end

function Raffle:Started(r)
    local start = self:StartTime(r)
    return start ~= nil and GetTimeStamp() >= start
end

function Raffle:SetValue(r, key, value)
    r[key] = value
    self:Dirty()
    GT.Report:RefreshIfShown()
end

function Raffle:SetStartText(r, text)
    text = zo_strtrim(text or "")
    if text ~= "" and not Raffle.ParseTime(text) then
        U.Print("Type the start as YYYY-MM-DD HH:MM in your local time, for example 2026-11-23 20:00.")
        return
    end
    r.startedAt = nil
    r.endedAt = nil
    self:SetValue(r, "startText", text)
end

function Raffle:SetPrice(r, text)
    local price = tonumber((tostring(text or ""):gsub("[,%.%s]", "")))
    if not price or price < 1 or price > 10000000 or price ~= math.floor(price) then
        U.Print("Type the ticket price as a whole number of gold, for example 1000 or 1001.")
        return
    end
    self:SetValue(r, "price", price)
    self:PrintWarnings(r)
end

-- The raffle settings have a page of their own, "Fury's Guild Toolset - Raffle" (1.8.1),
-- which New raffle and Raffle settings open. Since 1.10.0 the main page only points to it.
function Raffle:BuildSettings(options)
    self.panel = GT.Settings:AddPage("Raffle", "Raffle", self:SettingsControls(), false)
    GT.Settings:AddPointer(options, "Raffle", "Turning the raffle on, prizes, ticket price, sale times and running several raffles are on their own page: \"Fury's Guild Toolset - Raffle\" in the Add-Ons list. The Raffle settings button on the Raffle tab (/gt raffle) opens it too.",
        function() self:OpenSettings() end)
end

function Raffle:OpenSettings()
    LibAddonMenu2:OpenToPanel(self.panel)
end

-- Every control works on the raffle shown on the Raffle tab (1.9.0).
function Raffle:SettingsControls()
    local sv = self.sv
    local function R() return self:Cur() end
    local function Locked() return R().draw ~= nil end
    local function SalesLocked() return R().draw ~= nil or self:Started(R()) end
    local names, ids = self:GuildChoices()
    return {
        { type = "description", text = "Sell raffle tickets for gold deposited into a guild bank or mailed to you, then draw the winners in the Raffle tab (/gt raffle). Changes here apply to the raffle shown on the Raffle tab until its winners are drawn. To run several raffles at once, use New / other raffles on the Raffle tab." },
        { type = "checkbox", name = "Turn on the raffle", tooltip = "Reads guild bank gold deposits (through LibHistoire) and gold mails when you open your mailbox, and shows the Raffle tab.",
          getFunc = function() return sv.enabled end, setFunc = function(v) sv.enabled = v end, default = false, requiresReload = true },
        { type = "checkbox", name = "Chat line when someone buys tickets", tooltip = "Prints a line in your chat when a bank deposit during the sale buys tickets. Counted mails always get a line, since you are at your mailbox then. Only you see it.",
          getFunc = function() return sv.buyNotice end, setFunc = function(v) sv.buyNotice = v end, default = false },
        { type = "checkbox", name = "Draw show", tooltip = "When you draw the winners, a window counts down, spins through the buyers' names and reveals each winner with a sound, one winner at a time. Great on stream. The winners are drawn the moment you click Draw winners, as before; the show only reveals them. Replay it with Replay draw show on the Raffle tab.",
          getFunc = function() return sv.show end, setFunc = function(v) sv.show = v end, default = false },
        { type = "slider", name = "Draw show: countdown (seconds)", min = 0, max = 10, step = 1, tooltip = "Countdown before each winner. 0 = no countdown.",
          getFunc = function() return sv.showCountdown end, setFunc = function(v) sv.showCountdown = v end, default = 5, disabled = function() return not sv.show end },
        { type = "slider", name = "Draw show: spinning names (seconds)", min = 1, max = 10, step = 1, tooltip = "How long the buyers' names spin, slowing down, before the winner shows.",
          getFunc = function() return sv.showSpin end, setFunc = function(v) sv.showSpin = v end, default = 4, disabled = function() return not sv.show end },
        { type = "checkbox", name = "Draw show: sounds", tooltip = "A tick for each second of the countdown, clicks while the names spin and a fanfare for the winner.",
          getFunc = function() return sv.showSound end, setFunc = function(v) sv.showSound = v end, default = true, disabled = function() return not sv.show end },
        { type = "description", title = "Setting up", text = function()
            local r = R()
            return string.format("%s (%s)%s", self:Name(r), self:StatusShort(r), self:Multi() and string.format(", raffle %d of %d. Switch with New / other raffles on the Raffle tab.", self:IndexOf(r), #sv.raffles) or "")
          end },
        { type = "editbox", name = "Raffle name (optional)", tooltip = "Shown in your lists and chat lines when you run several raffles. Empty: its prize is its name.",
          getFunc = function() return R().name end, setFunc = function(v) self:SetValue(R(), "name", zo_strtrim(v or "")) end },
        { type = "dropdown", name = "Raffle guild", choices = names, choicesValues = ids, tooltip = "The guild whose bank deposits buy tickets, and whose chat gets the announcement and results. Pick (no guild) for a mail-only raffle; posts then show as text to copy. Locked once sales start.",
          getFunc = function() return R().guildId end, setFunc = function(v) self:SetValue(R(), "guildId", v) end, disabled = SalesLocked },
        { type = "checkbox", name = "Guild bank deposits buy tickets", tooltip = "Gold deposited into the raffle guild's bank during the sale buys tickets. Locked once sales start.",
          getFunc = function() return R().useBank end, setFunc = function(v) self:SetValue(R(), "useBank", v) end, disabled = SalesLocked },
        { type = "checkbox", name = "Mailed gold buys tickets", tooltip = "Gold mailed to you during the sale buys tickets. The addon can only see mail while your mailbox is open: open it before you take the gold out of raffle mails, and once after sales end. Locked once sales start.",
          getFunc = function() return R().useMail end, setFunc = function(v) self:SetValue(R(), "useMail", v) end, disabled = SalesLocked },
        { type = "editbox", name = "Mail subject keyword", tooltip = "Empty (the default): every mail with gold buys tickets, like every bank deposit. Type a word to count only mails whose subject contains it. When two raffles take mail at the same time, each needs its own keyword; mails without one go to Unassigned payments.",
          getFunc = function() return R().mailSubject end, setFunc = function(v) self:SetValue(R(), "mailSubject", zo_strtrim(v or "")); self:PrintWarnings(R()) end, disabled = Locked },
        { type = "editbox", name = "Prizes (one per line, or separate with ;)", isMultiline = true, tooltip = "One prize per winner, in order: the first goes to the winner of draw 1, the second to draw 2, and so on. Listing several sets the number of winners to match. For one prize everyone wins, type it once.",
          getFunc = function() return R().prize end, setFunc = function(v) self:SetPrizes(R(), v) end, disabled = Locked },
        { type = "editbox", name = "Ticket price (gold)", tooltip = "Gold per ticket, any whole number. When two raffles take deposits into the same guild bank at the same time, a deposit counts for the raffle whose price it is an exact multiple of, so give each its own odd price (1,001, 1,003, ...). Locked once sales start.",
          getFunc = function() return tostring(R().price) end, setFunc = function(v) self:SetPrice(R(), v) end, disabled = SalesLocked },
        { type = "slider", name = "Number of winners", min = 1, max = 20, step = 1, tooltip = "How many tickets to draw, one per prize.",
          getFunc = function() return R().winners end, setFunc = function(v) self:SetValue(R(), "winners", v) end, disabled = Locked },
        { type = "checkbox", name = "One win per person", tooltip = "On: once someone wins, their other tickets are skipped. Off: someone with many tickets can win more than once.",
          getFunc = function() return R().oneWin end, setFunc = function(v) self:SetValue(R(), "oneWin", v) end, disabled = Locked },
        { type = "slider", name = "Most tickets per person (0 = no limit)", min = 0, max = 1000, step = 1, tooltip = "Gold over the limit shows as Not used.",
          getFunc = function() return R().maxTickets end, setFunc = function(v) self:SetValue(R(), "maxTickets", v) end, disabled = Locked },
        { type = "editbox", name = "Start (YYYY-MM-DD HH:MM)", tooltip = "When sales start, in your local time, for example 2026-11-23 20:00 (8:00 pm works too). Leave it empty and click Start sales now in the Raffle tab instead. A start in the past counts deposits since then.",
          getFunc = function() return R().startText end, setFunc = function(v) self:SetStartText(R(), v) end, disabled = Locked },
        { type = "slider", name = "Sale length (hours)", min = 1, max = 336, step = 1, tooltip = "How long ticket sales run from the start. You can make it longer or shorter while sales run.",
          getFunc = function() return R().hours end, setFunc = function(v) R().endedAt = nil; self:SetValue(R(), "hours", v) end, disabled = Locked },
    }
end

function Raffle:IndexOf(r)
    for i, o in ipairs(self.sv.raffles) do if o == r then return i end end
    return 0
end
