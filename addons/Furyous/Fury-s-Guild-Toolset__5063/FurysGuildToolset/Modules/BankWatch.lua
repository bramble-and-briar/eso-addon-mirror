-- Bank Watch: flags members who withdraw more than a set number of items (or gold) from
-- the guild bank within a rolling window, and offers warn / demote / kick by severity.
-- Deposits never count, so officers stocking the bank never trigger anything. A stack the
-- same member puts back whole (same item, same count) stops counting; a partly used one still counts.

local GT = FurysGuildToolset
local U = GT.Util
local A = GT.Actions

local BankWatch = GT:RegisterModule("bank", {})
BankWatch.rebuildsFromLog = true   -- Rescan rebuilds it from the History log (see History:PrepareBackfill)

local SEVERITY_NONE, SEVERITY_WARN, SEVERITY_DEMOTE, SEVERITY_KICK = 0, 1, 2, 3
local SEVERITY_LABEL = {
    [SEVERITY_NONE] = "|c5EE6A0OK|r",
    [SEVERITY_WARN] = "|cFFC857WARN|r",
    [SEVERITY_DEMOTE] = "|cFFA45CDEMOTE|r",
    [SEVERITY_KICK] = "|cFF6B86KICK|r",
}
local STATUS_LABEL = {
    open = "|cECEAF8new|r",
    warned = "|c5EE6A0warned|r",
    demoted = "|c5EE6A0demoted|r",
    kicked = "|c5EE6A0kicked|r",
    rankset = "|c5EE6A0rank set|r",
    blacklisted = "|c5EE6A0blacklisted|r",
    dismissed = "|c8A86B0dismissed|r",
    returned = "|c5EE6A0under limits after returns|r",
}
local KEEP_CLOSED_CASES_SECONDS = 30 * 86400

BankWatch.defaults = {
    enabled = false,                 -- every feature starts turned off on a new install (Albert, 1.3.0)
    countMode = "withdrawals",       -- "withdrawals": each stack taken counts as 1. "quantity": every item in the stack counts
    windowMode = "day",              -- "day": per calendar day, midnight to midnight on this PC's clock. "rolling": any windowHours
    windowHours = 24,
    warnAt = 0,                      -- 0 = off; new installs start with only the demote limit (Albert, 1.2.4)
    demoteAt = 50,
    kickAt = 0,                      -- 0 = off
    goldEnabled = false,             -- not used since 1.32.3: gold is watched when one of its limits is above 0
    goldWarnAt = 0,                  -- 0 = off, like the item limits (Albert, 1.32.3: all three start at 0)
    goldDemoteAt = 0,
    goldKickAt = 0,
    excludeNames = "",
    excludeRanks = "",
    excludeTopRanks = 2,             -- ranks 1..2 (Guild Master and the next rank) are ignored
    openWindowOnLogin = false,
    warnMethod = "whisper",
    warnText = "Hi <<1>>, on <<5>> you withdrew <<2>> from the <<3>> guild bank.\n\n<<6>>",
    demoteText = "Hi <<1>>, on <<5>> you withdrew <<2>> from the <<3>> guild bank.\n\n<<6>>\n\nYou have been demoted until you contact the Guild Leader or one of the officers to discuss this.",
    rulesText = "",                  -- bank rules for <<6>>; empty = use the Crier's "Guild Bank 101" message
    autoDemote = false,              -- opt-in: demote automatically at the demote threshold
    autoDemoteSince = 0,             -- only withdrawals after this time (set when auto-demote is turned on)
    autoDemoteMaxPerSession = 5,
    autoDemoteMail = false,          -- opt-in: send the demotion mail by itself after an auto-demote
    autoDemoteNote = false,          -- after an auto-demote, add the reason to their guild note (Albert asked, 0.4.28)
    demoteToRank = 0,                -- 0 = one step down, otherwise the rank number to set
    blacklistOnKick = false,
    ledger = {},                     -- [guildId][displayName] = { {id, ts, n, kind, link, qty, ret, retTs, retIds} }
    cases = {},
}

-- Settings each guild has its own copy of (see GT:GuildSettings). The rest are for all guilds.
BankWatch.guildKeys = { "countMode", "windowMode", "windowHours", "warnAt", "demoteAt", "kickAt", "goldEnabled",
    "goldWarnAt", "goldDemoteAt", "goldKickAt", "excludeNames", "excludeRanks", "excludeTopRanks", "warnMethod",
    "warnText", "demoteText", "rulesText", "autoDemote", "autoDemoteSince", "autoDemoteMail", "autoDemoteNote", "demoteToRank", "blacklistOnKick" }

-- This guild's bank alert settings.
function BankWatch:G(guildId)
    return GT:GuildSettings(self, guildId)
end

function BankWatch:Initialize(sv)
    self.sv = sv
    -- v0.2.2: count stacks by default (Albert: a stack of recipes counts as one).
    if (sv.settingsVersion or 1) < 2 then
        sv.countMode = "withdrawals"
        sv.settingsVersion = 2
    end
    -- v0.3.5: warning names the date of the withdrawals and adds the bank rules.
    if sv.settingsVersion < 3 then
        if sv.warnText == "Hi <<1>>, the <<3>> bank shows you withdrew <<2>> in the last <<4>> hours. Please return what you don't need or talk to an officer." then sv.warnText = BankWatch.defaults.warnText end
        sv.settingsVersion = 3
    end
    -- v0.3.6: blank lines between the offense and the bank rules.
    if sv.settingsVersion < 4 then
        if sv.warnText == "Hi <<1>>, on <<5>> you withdrew <<2>> from the <<3>> guild bank in less than a <<4>> hour period. <<6>>" then sv.warnText = BankWatch.defaults.warnText end
        sv.settingsVersion = 4
    end
    if sv.cases then
        for _, c in ipairs(sv.cases) do c.mailSending = nil end  -- a reload interrupts sending
    end
    -- v0.3.11: auto-demote is back (Albert asked). Only withdrawals from now on count.
    if sv.settingsVersion < 5 then
        sv.autoDemoteSince = GetTimeStamp()
        sv.settingsVersion = 5
    end
    -- v0.4.17: limits count per calendar day (Albert), and the mails name the day instead of the hours.
    if sv.settingsVersion < 6 then
        sv.windowMode = "day"
        if sv.warnText == "Hi <<1>>, on <<5>> you withdrew <<2>> from the <<3>> guild bank in less than a <<4>> hour period.\n\n<<6>>" then sv.warnText = BankWatch.defaults.warnText end
        if sv.demoteText == "Hi <<1>>, on <<5>> you withdrew <<2>> from the <<3>> guild bank in less than a <<4>> hour period.\n\n<<6>>\n\nYou have been demoted until you contact the Guild Leader or one of the officers to discuss this." then sv.demoteText = BankWatch.defaults.demoteText end
        sv.settingsVersion = 6
    end
    -- 1.32.3: gold has three sliders like the items, 0 = off, and the "Watch gold withdrawals
    -- too" box is gone. Where that box was off the gold limits become 0, so nothing starts
    -- being watched by itself; where it was on the numbers stay as they are.
    if sv.settingsVersion < 7 then
        for _, g in pairs(sv.guilds or {}) do
            local watched = g.goldEnabled
            if watched == nil then watched = sv.goldEnabled end
            if not watched then g.goldWarnAt, g.goldDemoteAt, g.goldKickAt = 0, 0, 0 end
        end
        if not sv.goldEnabled then sv.goldWarnAt, sv.goldDemoteAt, sv.goldKickAt = 0, 0, 0 end
        sv.settingsVersion = 7
    end
    self.autoDemotedThisSession = 0
    -- v0.2.3: the old auto settings had different names; clear them.
    for _, key in ipairs({ "autoEnabled", "autoSince", "autoRankName", "autoMail", "autoMailSubject", "autoMailText", "autoMaxPerSession" }) do
        sv[key] = nil
    end
    self.sessionStart = GetTimeStamp()
    self.caughtUp = {}
    self:Prune()
    self:RegisterTab()
end

function BankWatch:GetHistoryCategories()
    if not self.sv.enabled then return {} end
    return { GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY }
end

-- The ledger only has to cover the counting window (Rescan rebuilds it from the History log),
-- so keep two windows' worth instead of a month.
function BankWatch:Prune()
    local cutoff = GetTimeStamp() - 2 * math.max(GT:MaxGuildSetting(self, "windowHours"), 24) * 3600
    for _, members in pairs(self.sv.ledger) do
        for name, entries in pairs(members) do
            for i = #entries, 1, -1 do
                if entries[i].ts < cutoff then table.remove(entries, i) end
            end
            if #entries == 0 then members[name] = nil end
        end
    end
    local closedCutoff = GetTimeStamp() - KEEP_CLOSED_CASES_SECONDS
    for i = #self.sv.cases, 1, -1 do
        local case = self.sv.cases[i]
        if case.status ~= "open" and (case.closedAt or case.lastTs) < closedCutoff then
            table.remove(self.sv.cases, i)
        end
    end
end

function BankWatch:GetThresholds(kind, guildId)
    local g = self:G(guildId)
    if kind == "gold" then return g.goldWarnAt, g.goldDemoteAt, g.goldKickAt end
    return g.warnAt, g.demoteAt, g.kickAt
end

function BankWatch:GetSeverity(kind, total, guildId)
    local warnAt, demoteAt, kickAt = self:GetThresholds(kind, guildId)
    if kickAt > 0 and total >= kickAt then return SEVERITY_KICK end
    if demoteAt > 0 and total >= demoteAt then return SEVERITY_DEMOTE end
    if warnAt > 0 and total >= warnAt then return SEVERITY_WARN end
    return SEVERITY_NONE
end

-- unit: "stacks" or "items" (what the total counted when the case was opened)
local function FormatAmount(kind, total, unit)
    if kind == "gold" then return U.FormatGold(total) end
    if unit == "stacks" then return zo_strformat("<<1>> <<1[stack/stacks]>>", total) end
    return zo_strformat("<<1>> <<1[item/items]>>", total)
end

local function ItemName(link)
    local name = GetItemLinkName(link)
    if not name or name == "" then return link end
    return zo_strformat("<<t:1>>", name)
end

-- Midnight (on this PC's clock) at the start of the day that holds ts.
local function DayStart(ts)
    local t = os.date("*t", ts)
    return ts - (t.hour * 3600 + t.min * 60 + t.sec)
end

-- Whether a withdrawal at ts counts together with one at endTs: the same calendar day up to
-- endTs, or (rolling mode) within windowHours before endTs.
function BankWatch:InPeriod(ts, endTs, guildId)
    if ts > endTs then return false end
    local g = self:G(guildId)
    if g.windowMode == "day" then return ts >= DayStart(endTs) end
    return ts > endTs - g.windowHours * 3600
end

-- "per day" or "in 24h", for alerts, rules and the status line.
function BankWatch:PeriodLabel(guildId)
    local g = self:G(guildId)
    if g.windowMode == "day" then return "per day" end
    return string.format("in %dh", g.windowHours)
end

function BankWatch:FindCase(guildId, name, kind, ts)
    local g = self:G(guildId)
    local day = g.windowMode == "day"
    local window = g.windowHours * 3600
    for _, case in ipairs(self.sv.cases) do
        if case.guildId == guildId and case.name == name and case.kind == kind then
            if day then
                if DayStart(ts) == DayStart(case.lastTs) then return case end
            elseif ts - case.lastTs <= window and ts >= case.firstTs - window then
                return case
            end
        end
    end
end

function BankWatch:OnHistoryEvent(guildId, category, info, isLive)
    local sv = self.sv
    if not sv.enabled or not GT:IsAlertGuild(guildId) then return end
    local g = self:G(guildId)

    local name, kind, amount, link, qty
    if category == GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM then
        if info.eventType == GUILD_HISTORY_BANKED_ITEM_EVENT_ADDED then
            self:OnItemDeposit(guildId, info)
            return
        end
        if info.eventType ~= GUILD_HISTORY_BANKED_ITEM_EVENT_REMOVED then return end
        name, kind, link, qty = info.displayName, "items", info.itemLink, info.quantity or 1
        amount = (g.countMode == "withdrawals") and 1 or qty
    elseif category == GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY then
        if g.goldWarnAt <= 0 and g.goldDemoteAt <= 0 and g.goldKickAt <= 0 then return end   -- gold not watched
        if info.eventType ~= GUILD_HISTORY_BANKED_CURRENCY_EVENT_WITHDRAWN then return end
        if info.currencyType ~= CURT_MONEY then return end
        name, kind, amount = info.displayName, "gold", info.amount or 0
    else
        return
    end
    if not name or name == "" then return end
    if U.IsExcluded(guildId, name, g) then return end

    sv.ledger[guildId] = sv.ledger[guildId] or {}
    local entries = sv.ledger[guildId][name] or {}
    sv.ledger[guildId][name] = entries
    for _, entry in ipairs(entries) do
        -- Event ids are only unique within one history category, so item and gold ids can match.
        if entry.id == info.eventId and entry.kind == kind then return end -- already counted
    end
    local ts = info.timestampS
    table.insert(entries, { id = info.eventId, ts = ts, n = amount, kind = kind, link = link, qty = qty })

    -- Total for this person over the day (or window) ending at this withdrawal.
    local total = self:WindowTotal(entries, kind, ts, guildId)
    local inWindow = {}
    for _, entry in ipairs(entries) do
        if entry.kind == kind and self:InPeriod(entry.ts, ts, guildId) then
            inWindow[#inWindow + 1] = entry
        end
    end

    local severity = self:GetSeverity(kind, total, guildId)
    if severity == SEVERITY_NONE then return end

    local alert = (isLive or GT.History:IsCaughtUp(category, guildId)) and not self.rebuilding
    local case = self:FindCase(guildId, name, kind, ts)
    if case then
        case.total = math.max(case.total, total)
        case.lastTs = math.max(case.lastTs, ts)
        if link then case.items[link] = (case.items[link] or 0) + qty end
        if severity > case.severity then
            case.severity = severity
            case.seen = nil   -- it got worse, so it is new again
            if case.status ~= "open" then
                case.status = "open"
                case.escalated = true
            end
            if alert then self:AlertCase(case, true) end
        end
    else
        local rankIndex, rankName = U.GetMemberRank(guildId, name)
        case = {
            guildId = guildId,
            guildName = U.GuildName(guildId),
            name = name,
            kind = kind,
            unit = (kind == "items" and g.countMode == "withdrawals") and "stacks" or "items",
            total = total,
            firstTs = inWindow[1] and inWindow[1].ts or ts,
            lastTs = ts,
            severity = severity,
            status = "open",
            createdAt = GetTimeStamp(),
            rankName = rankIndex and rankName or nil,
            items = {},
        }
        for _, entry in ipairs(inWindow) do
            if entry.link then case.items[entry.link] = (case.items[entry.link] or 0) + (entry.qty or 1) end
        end
        table.insert(sv.cases, case)
        if alert then self:AlertCase(case, false) end
    end
    -- 1.34.7: events the hole filler fetched late (info.backfilled) alert, but never auto-demote or mail (Albert).
    if alert and not info.backfilled then self:MaybeAutoDemote(case) end
    GT.Report:RefreshIfShown()
end

-- A withdrawal put back whole no longer counts toward the limits.
local function Counts(entry)
    return not (entry.ret and entry.ret >= (entry.qty or 1))
end

-- What counts toward the limits for one member over the day (or window) ending at endTs.
function BankWatch:WindowTotal(entries, kind, endTs, guildId)
    local stacks = self:G(guildId).countMode == "withdrawals"
    local total = 0
    for _, entry in ipairs(entries) do
        if entry.kind == kind and self:InPeriod(entry.ts, endTs, guildId) and Counts(entry) then
            -- Recomputed from the stored stack size so switching "Count by" applies to past withdrawals too.
            if kind == "items" then
                total = total + (stacks and 1 or (entry.qty or entry.n))
            else
                total = total + entry.n
            end
        end
    end
    return total
end

-- A deposit of the same item (same item link) by the same member, within the History log's
-- return time, is matched to their earliest withdrawals of it that aren't put back yet.
function BankWatch:OnItemDeposit(guildId, info)
    local link, ts = info.itemLink, info.timestampS
    local entries = self.sv.ledger[guildId] and self.sv.ledger[guildId][info.displayName]
    if not entries or not link then return end
    for _, entry in ipairs(entries) do
        if entry.retIds and entry.retIds[info.eventId] then return end -- already matched
    end
    local maxAge = GT:GuildSettings(GT:GetModule("log"), guildId).returnHours * 3600
    local list = {}
    for _, entry in ipairs(entries) do
        if entry.kind == "items" and entry.link == link and entry.ts <= ts and ts - entry.ts <= maxAge
            and (entry.ret or 0) < (entry.qty or 1) then
            list[#list + 1] = entry
        end
    end
    if #list == 0 then return end
    table.sort(list, function(a, b) if a.ts ~= b.ts then return a.ts < b.ts end return a.id < b.id end)
    local left = info.quantity or 1
    for _, entry in ipairs(list) do
        if left == 0 then break end
        local give = math.min((entry.qty or 1) - (entry.ret or 0), left)
        entry.ret = (entry.ret or 0) + give
        entry.retTs = ts
        entry.retIds = entry.retIds or {}
        entry.retIds[info.eventId] = give
        left = left - give
    end
    for _, case in ipairs(self.sv.cases) do
        if case.guildId == guildId and case.name == info.displayName and case.kind == "items" then
            self:RecountCase(case, entries)
        end
    end
    GT.Report:RefreshIfShown()
end

-- After a stack is put back whole: the case total drops, and so can its severity.
-- An open case that falls below every limit is closed as "put back". Something already
-- done (warned, demoted...) stays as it was; an auto-demote can't be undone by a return.
function BankWatch:RecountCase(case, entries)
    local total = 0
    for _, entry in ipairs(entries) do
        if entry.kind == case.kind and entry.ts >= case.firstTs and entry.ts <= case.lastTs and Counts(entry) then
            total = math.max(total, self:WindowTotal(entries, case.kind, entry.ts, case.guildId))
        end
    end
    case.total = total
    local severity = self:GetSeverity(case.kind, total, case.guildId)
    if severity < case.severity then
        case.severity = severity
        if severity == SEVERITY_NONE and case.status == "open" then
            case.status = "returned"
            case.closedAt = GetTimeStamp()
            case.escalated = nil
        end
    end
end

-- Recomputes every bank alert from the History log with the current settings.
-- Used by /gt reset and the Rescan button, and needs no reload.
function BankWatch:RebuildFromLog(entries)
    local list = {}
    for _, e in ipairs(entries) do
        if e.t == "item_out" or e.t == "item_in" or e.t == "gold_out" then list[#list + 1] = e end
    end
    -- Oldest first; at the same second a withdrawal comes before a deposit (it can be put back).
    table.sort(list, function(a, b)
        if a.ts ~= b.ts then return a.ts < b.ts end
        if (a.t == "item_in") ~= (b.t == "item_in") then return b.t == "item_in" end
        return a.id < b.id
    end)
    local oldCases = self.sv.cases
    self.sv.cases, self.sv.ledger = {}, {}
    self.rebuilding = true
    for _, e in ipairs(list) do
        if e.t == "item_out" or e.t == "item_in" then
            self:OnHistoryEvent(e.g, GUILD_HISTORY_EVENT_CATEGORY_BANKED_ITEM, { eventId = e.id, timestampS = e.ts,
                eventType = (e.t == "item_out") and GUILD_HISTORY_BANKED_ITEM_EVENT_REMOVED or GUILD_HISTORY_BANKED_ITEM_EVENT_ADDED,
                displayName = e.who, itemLink = e.link, quantity = e.qty }, false)
        else
            self:OnHistoryEvent(e.g, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY, { eventId = e.id, timestampS = e.ts,
                eventType = GUILD_HISTORY_BANKED_CURRENCY_EVENT_WITHDRAWN, displayName = e.who, currencyType = CURT_MONEY,
                amount = e.amount }, false)
        end
    end
    self.rebuilding = false
    self:RestoreActions(oldCases)
    return self:CountOpen()
end

-- After a rescan, put back what you already did (warned, demoted, set rank, dismissed...)
-- on the alert covering the same member, guild and withdrawals.
function BankWatch:RestoreActions(oldCases)
    for _, case in ipairs(self.sv.cases) do
        -- Keep "seen" for an alert you already looked at, unless it is now worse than when you saw it.
        for _, old in ipairs(oldCases or {}) do
            if old.seen and old.guildId == case.guildId and old.name == case.name and old.kind == case.kind
                and old.severity >= case.severity and (old.firstTs or old.lastTs) <= case.lastTs and old.lastTs >= (case.firstTs or case.lastTs) then
                case.seen = true
                break
            end
        end
        for _, old in ipairs(oldCases or {}) do
            -- "put back" is worked out again from the deposits, so it isn't carried over.
            if old.status ~= "open" and old.status ~= "returned" and old.guildId == case.guildId and old.name == case.name and old.kind == case.kind
                and (old.firstTs or old.lastTs) <= case.lastTs and old.lastTs >= (case.firstTs or case.lastTs) then
                case.status, case.closedAt, case.rankSetTo = old.status, old.closedAt, old.rankSetTo
                case.autoDemoted, case.mailPending, case.mailSentAt = old.autoDemoted, old.mailPending, old.mailSentAt
                break
            end
        end
    end
end

function BankWatch:AlertCase(case, escalated)
    U.Alert(zo_strformat("<<1>> <<2>> withdrew <<3>> from <<4>> <<5>>. /gt bank to review.",
        escalated and "Escalated:" or "Bank alert:", case.name, FormatAmount(case.kind, case.total, case.unit),
        case.guildName, self:PeriodText(case)))
end

function BankWatch:OnHistoryCaughtUp(category)
    self.caughtUp[category] = true
    for _, wanted in ipairs(self:GetHistoryCategories()) do
        if not self.caughtUp[wanted] then return end
    end
    self:ShowLoginSummary()
end

-- Opt-in automatic demotion when an alert reaches the demote threshold.
-- Safeguards: only withdrawals after auto-demote was turned on, never anyone at or
-- above your rank, excluded names/ranks never get an alert in the first place, and
-- at most autoDemoteMaxPerSession per session. Every outcome (done, skipped, limit
-- reached) is announced and kept in the Auto tab with the withdrawals behind it.
function BankWatch:DemoteRule(case)
    local _, demoteAt = self:GetThresholds(case.kind, case.guildId)
    return zo_strformat("demote at <<1>> <<2>>", FormatAmount(case.kind, demoteAt, case.unit), self:PeriodLabel(case.guildId))
end

-- The withdrawals counted in the case total (same window as OnHistoryEvent), oldest first.
function BankWatch:GetCaseWithdrawals(case)
    local entries = self.sv.ledger[case.guildId] and self.sv.ledger[case.guildId][case.name] or {}
    local list = {}
    for _, entry in ipairs(entries) do
        if entry.kind == case.kind and self:InPeriod(entry.ts, case.lastTs, case.guildId) then
            local text
            if case.kind == "gold" then
                text = U.FormatGold(entry.n)
            else
                text = string.format("%dx %s", entry.qty or 1, entry.link and ItemName(entry.link) or "item")
            end
            list[#list + 1] = { ts = entry.ts, text = text }
        end
    end
    table.sort(list, function(a, b) return a.ts < b.ts end)
    return list
end

-- Which of the case's item withdrawals were put back by the same member (see OnItemDeposit).
-- Stacks put back whole don't count toward the total; partly used ones do.
-- Also counts what was taken (stacks and items). The ledger only keeps two days, so the
-- counts are saved on the case and used once its withdrawals have left the ledger.
function BankWatch:GetCaseReturns(case)
    local out = { whole = 0, partial = 0, lines = {}, stacks = 0, items = 0 }
    if case.kind ~= "items" then return out end
    local entries = self.sv.ledger[case.guildId] and self.sv.ledger[case.guildId][case.name] or {}
    for _, entry in ipairs(entries) do
        local inCase = entry.kind == "items" and entry.ts <= case.lastTs
            and (entry.ts >= case.firstTs or self:InPeriod(entry.ts, case.firstTs, case.guildId))
        if inCase then
            out.stacks = out.stacks + 1
            out.items = out.items + (entry.qty or 1)
        end
        if inCase and (entry.ret or 0) > 0 then
            local taken, name = entry.qty or 1, entry.link and ItemName(entry.link) or "item"
            if entry.ret >= taken then
                out.whole = out.whole + 1
                out.lines[#out.lines + 1] = string.format("|c5EE6A0%dx %s put back whole after %s|r", taken, name, U.FormatDuration(entry.retTs - entry.ts))
            else
                out.partial = out.partial + 1
                out.lines[#out.lines + 1] = string.format("|cFFC857%d of %dx %s put back, %d used or kept|r", entry.ret, taken, name, taken - entry.ret)
            end
        end
    end
    if out.stacks > 0 then
        case.taken = { stacks = out.stacks, items = out.items, whole = out.whole, partial = out.partial }
    elseif case.taken then
        out.stacks, out.items, out.whole, out.partial = case.taken.stacks, case.taken.items, case.taken.whole, case.taken.partial
    else
        -- Flagged before 0.4.20 and no longer in the ledger: items from the case's own list.
        for _, count in pairs(case.items or {}) do out.items = out.items + count end
        out.stacks = (case.unit == "stacks") and case.total or nil
    end
    return out
end

function BankWatch:MaybeAutoDemote(case)
    local sv, g = self.sv, self:G(case.guildId)
    if not g.autoDemote or self.rebuilding then return end
    if case.status ~= "open" or case.severity < SEVERITY_DEMOTE then return end
    -- Already auto-demoted for these withdrawals: an escalation to kick waits for your click.
    if case.autoDemoted then return end
    if case.lastTs < (g.autoDemoteSince or 0) then return end
    local log = GT.AutoLog
    if (self.autoDemotedThisSession or 0) >= (sv.autoDemoteMaxPerSession or 5) then
        if not self.capWarned then
            self.capWarned = true
            log:RecordCapReached(sv.autoDemoteMaxPerSession or 5)
        end
        return
    end
    local ok, result, newRankIndex, oldRankName = A.DemoteNow(case.guildId, case.name, g.demoteToRank)
    if not ok then
        if case.autoSkipReason ~= result then
            case.autoSkipReason = result
            log:RecordSkipped(case.guildId, case.name, result, FormatAmount(case.kind, case.total, case.unit), self:DemoteRule(case))
        end
        return
    end
    self.autoDemotedThisSession = (self.autoDemotedThisSession or 0) + 1
    case.rankSetTo, case.autoDemoted, case.mailPending = result, true, true
    self:CloseCase(case, "demoted")
    local entry = log:RecordDemotion({
        guildId = case.guildId, name = case.name, fromRank = oldRankName, toRank = result, toRankIndex = newRankIndex,
        amount = FormatAmount(case.kind, case.total, case.unit), rule = self:DemoteRule(case),
        firstTs = case.firstTs, lastTs = case.lastTs, withdrawals = self:GetCaseWithdrawals(case),
        mail = g.autoDemoteMail and "queued" or "off",
    })
    if g.autoDemoteNote then self:AutoNote(case, entry) end
    if g.autoDemoteMail then self:AutoSendDemotionMail(case, entry) end
end

-- After an auto-demote: why, as one line at the end of their guild note (same line as the
-- Note button). Whether it was added is shown in chat and kept in the Auto tab.
function BankWatch:AutoNote(case, entry)
    local line = self:GetNoteLine(case)
    local ok, reason = A.AppendNoteNow(case.guildId, case.name, line)
    entry.note = ok and "added" or reason
    entry.noteLine = line
    if ok then
        case.notedAt = GetTimeStamp()
        U.Print("  Guild note: added \"%s\"", line)
    else
        U.Print("  Guild note: not added (%s). The Note button on /gt bank tries again.", reason)
    end
end

-- Sends the demotion mail without opening the mail window. Sent/failed is reported only
-- from the server's answer. If it fails, the alert keeps its Send mail button.
function BankWatch:AutoSendDemotionMail(case, entry)
    case.mailSending = true
    A.SendMailNow(case.name, "Guild bank: demoted", self:BuildMessage(case, self:G(case.guildId).demoteText), function(ok, reason)
        case.mailSending = nil
        if ok then
            case.mailPending = nil
            case.mailSentAt = GetTimeStamp()
        end
        GT.AutoLog:MailResult(entry, ok, reason)
        GT.Report:RefreshIfShown()
    end)
end

function BankWatch:ShowLoginSummary()
    for _, case in ipairs(self.sv.cases) do
        if case.status == "open" and case.createdAt >= self.sessionStart then self:MaybeAutoDemote(case) end
    end
    local newCases, openCases = {}, 0
    for _, case in ipairs(self.sv.cases) do
        if case.status == "open" and GT:IsAlertGuild(case.guildId) then
            openCases = openCases + 1
            if case.createdAt >= self.sessionStart or case.escalated then
                newCases[#newCases + 1] = case
            end
        end
    end
    if openCases == 0 then return end

    table.sort(newCases, function(a, b) return a.severity > b.severity end)
    if #newCases > 0 then
        U.Alert(zo_strformat("Guild bank: <<1>> new <<1[alert/alerts]>> since your last login.", #newCases))
        for i = 1, math.min(5, #newCases) do
            local case = newCases[i]
            U.Print("%s %s took %s from %s", SEVERITY_LABEL[case.severity], case.name,
                FormatAmount(case.kind, case.total, case.unit), case.guildName)
        end
        if #newCases > 5 then U.Print("...and %d more. Type /gt bank to see them all.", #newCases - 5) end
        if self.sv.openWindowOnLogin then GT.Report:Show("bank") end
    else
        U.Print("Guild bank: %d open %s waiting for review. Type /gt bank.", openCases, openCases == 1 and "alert" or "alerts")
    end
end

-- /gt status: shows the biggest withdrawers so it's clear why something did or didn't alert.

function BankWatch:PrintStatus()
    local log = GT:GetModule("log")
    local entries = log and log.entries or {}
    U.Print("Bank alerts (each guild has its own limits):")

    -- Item withdrawals per guild and member, oldest first.
    local byMember = {}
    local totalWithdrawals = {}
    for _, e in ipairs(entries) do
        if e.t == "item_out" and e.who then
            local key = tostring(e.g) .. "\t" .. e.who
            byMember[key] = byMember[key] or { g = e.g, who = e.who, list = {} }
            table.insert(byMember[key].list, e)
            totalWithdrawals[e.g] = (totalWithdrawals[e.g] or 0) + 1
        end
    end

    local best = {}  -- [guildId] = list of { who, peak }
    for _, m in pairs(byMember) do
        table.sort(m.list, function(a, b) return a.ts < b.ts end)
        local stacks = self:G(m.g).countMode == "withdrawals"
        local peak, sum, first = 0, 0, 1
        for i, e in ipairs(m.list) do
            sum = sum + (stacks and 1 or (e.qty or 1))
            while not self:InPeriod(m.list[first].ts, e.ts, m.g) do
                sum = sum - (stacks and 1 or (m.list[first].qty or 1))
                first = first + 1
            end
            peak = math.max(peak, sum)
        end
        best[m.g] = best[m.g] or {}
        table.insert(best[m.g], { who = m.who, peak = peak })
    end

    for _, guildId in ipairs(U.GetGuildIds()) do
        local list = best[guildId] or {}
        table.sort(list, function(a, b) return a.peak > b.peak end)
        local g = self:G(guildId)
        local top = {}
        for i = 1, math.min(3, #list) do
            local excluded = U.IsExcluded(guildId, list[i].who, g)
            top[#top + 1] = string.format("%s %d%s", list[i].who, list[i].peak, excluded and " (ignored)" or "")
        end
        if GT:IsAlertGuild(guildId) then
            U.Print("  %s: %s, ignoring top %d ranks%s.", U.GuildName(guildId), self:DescribeLimits(guildId), g.excludeTopRanks,
                (g.excludeRanks ~= "" or g.excludeNames ~= "") and " plus your name/rank lists" or "")
        else
            U.Print("  %s: alerts off.", U.GuildName(guildId))
        end
        U.Print("    %d withdrawals logged. Most %s: %s", totalWithdrawals[guildId] or 0,
            self:PeriodLabel(guildId), #top > 0 and table.concat(top, ", ") or "none")
    end
end

-- Actions -------------------------------------------------------------------

function BankWatch:CloseCase(case, status)
    case.status = status
    case.closedAt = GetTimeStamp()
    case.escalated = nil
    GT.Report:RefreshIfShown()
end

-- Bank rules for the warning: the setting if filled in, otherwise the Crier message
-- that holds the bank rules ("Guild Bank 101..."), otherwise nothing.
function BankWatch:GetBankRules(guildId)
    local rulesText = self:G(guildId).rulesText
    if rulesText and zo_strtrim(rulesText) ~= "" then return zo_strtrim(rulesText) end
    local crier = GT.Crier
    local msgs = (crier.sv and crier.sv.messages) or GT.CrierMessages
    for _, m in ipairs(msgs) do
        if m.text:find("Bank 101", 1, true) then return m.text end
    end
    for _, m in ipairs(msgs) do
        if m.text:lower():find("bank", 1, true) and m.text:lower():find("take", 1, true) then return m.text end
    end
    return ""
end

-- "November 15" (or "November 14-15" when the withdrawals span two days).
local function OffenseDate(case)
    local function Day(ts) return (os.date("%B %d", ts):gsub(" 0", " ")) end
    local first, last = Day(case.firstTs or case.lastTs), Day(case.lastTs)
    if first == last then return last end
    if os.date("%B", case.firstTs) == os.date("%B", case.lastTs) then
        return first .. "-" .. tonumber(os.date("%d", case.lastTs))
    end
    return first .. " - " .. last
end

-- "on November 15" per day, or "in 24h" for a rolling window.
function BankWatch:PeriodText(case)
    local g = self:G(case.guildId)
    if g.windowMode == "day" then return "on " .. OffenseDate(case) end
    return string.format("in %dh", g.windowHours)
end

local MAIL_MAX = 700  -- ESO's mail body limit

-- Fills a warning/demotion template for a case.
function BankWatch:BuildMessage(case, template)
    -- string.gsub instead of zo_strformat so the rules text is inserted exactly as written.
    local values = { case.name, FormatAmount(case.kind, case.total, case.unit), case.guildName,
        tostring(self:G(case.guildId).windowHours), OffenseDate(case), self:GetBankRules(case.guildId) }
    local body = template:gsub("<<(%d)>>", function(n) return values[tonumber(n)] or "" end)
    body = zo_strtrim(body)
    if #body > MAIL_MAX then
        U.Print("Note: this message is %d characters; ESO mail holds %d, so shorten the text in settings.", #body, MAIL_MAX)
    end
    return body
end

local DEMOTE_MAIL_NOTE = "A mail explaining why will open for you to review and send."

-- After a confirmed demotion, open the demotion mail (you press Send).
function BankWatch:MailDemotion(case)
    A.Warn(case.name, "Guild bank: demoted", self:BuildMessage(case, self:G(case.guildId).demoteText), "mail")
end

-- method: "whisper" or "mail"; nil uses the "Warn by" setting.
function BankWatch:WarnCase(case, method)
    local g = self:G(case.guildId)
    local body = self:BuildMessage(case, g.warnText)
    A.Warn(case.name, "Guild bank withdrawals", body, method or g.warnMethod)
    self:CloseCase(case, "warned")
end

function BankWatch:BlacklistNote(case)
    return zo_strformat("FGMT: took <<1>> from the bank on <<2>>", FormatAmount(case.kind, case.total, case.unit), U.FormatDate(case.lastTs))
end

-- One short line for the member's guild note, for example
-- "Bank Nov 18: took 41 stacks (157 items), back 0 whole/0 partly. Demoted."
local NOTE_STATUS = { warned = "Warned", demoted = "Demoted", rankset = "Rank changed", kicked = "Kicked",
    blacklisted = "Blacklisted", returned = "Under limits after returns" }
function BankWatch:GetNoteLine(case)
    local day = (os.date("%b %d", case.lastTs):gsub(" 0", " "))
    local text
    if case.kind == "gold" then
        text = string.format("Bank %s: took %s gold", day, ZO_CommaDelimitNumber(case.total))
    else
        local r = self:GetCaseReturns(case)
        local taken = r.stacks and string.format("%d stacks (%d items)", r.stacks, r.items) or string.format("%d items", r.items)
        text = string.format("Bank %s: took %s, put back %d whole/%d partly", day, taken, r.whole, r.partial)
    end
    local status = NOTE_STATUS[case.status]
    if case.status == "demoted" and case.autoDemoted then
        local _, demoteAt = self:GetThresholds(case.kind, case.guildId)
        status = string.format("Auto-demoted (limit %s %s)", case.kind == "gold" and ZO_CommaDelimitNumber(demoteAt) .. " gold" or tostring(demoteAt),
            self:PeriodLabel(case.guildId))
    end
    return text .. (status and (". " .. status .. ".") or ".")
end

function BankWatch:GetCaseRow(case)
    local g = self:G(case.guildId)
    local stillMember = U.IsPlayerInGuild(case.guildId) and U.IsMember(case.guildId, case.name)
    -- One summary line: who, where, how much was taken, how much came back. The item list is in
    -- the hover and the export.
    local returns = self:GetCaseReturns(case)
    local taken
    if case.kind == "gold" then
        taken = "took |cECEAF8" .. U.FormatGold(case.total) .. "|r"
    elseif returns.stacks then
        taken = zo_strformat("took |cECEAF8<<1>> <<1[stack/stacks]>>|r (<<2>> <<2[item/items]>>)", returns.stacks, returns.items)
        local back = string.format("put back: |c5EE6A0%d whole|r, |cFFC857%d partly|r", returns.whole, returns.partial)
        taken = taken .. "  " .. back
        if case.unit == "stacks" and case.total ~= returns.stacks then
            taken = taken .. string.format("  |cB4B0D8(counted %d)|r", case.total)
        end
    else
        taken = string.format("took |cECEAF8%d items|r  put back: |c5EE6A0%d whole|r, |cFFC857%d partly|r", returns.items, returns.whole, returns.partial)
    end
    local text = string.format("%s %s  |cB4B0D8%s|r  %s  |cB4B0D8%s|r", SEVERITY_LABEL[case.severity], case.name, case.guildName, taken, U.FormatAgo(case.lastTs))
    if not stillMember then text = text .. " |cFF6B86(left)|r" end
    -- 1.26.5 (Albert): the tab title counts "new" alerts (still open), so mark which ones they are.
    -- New = open and not looked at yet. Leaving the tab (or closing the window) marks them seen.
    if self:IsNew(case) then text = "|c5EB8FFNEW|r  " .. text end
    if case.status == "rankset" and case.rankSetTo then
        text = text .. "  |c5EE6A0set to " .. case.rankSetTo .. "|r"
    elseif case.status == "demoted" and case.autoDemoted then
        text = text .. "  |c5EE6A0auto-demoted to " .. (case.rankSetTo or "?") .. "|r"
        if case.mailSending then text = text .. " |cB4B0D8(sending mail...)|r"
        elseif case.mailPending then text = text .. " |cFFC857(mail not sent)|r"
        elseif case.mailSentAt then text = text .. " |cB4B0D8(mail sent)|r" end
    elseif case.status ~= "open" then
        text = text .. "  " .. (STATUS_LABEL[case.status] or case.status)
    end

    local lines = {
        zo_strformat("<<1>> in <<2>>", case.name, case.guildName),
        "Rank when flagged: " .. (case.rankName or "unknown"),
        string.format("From %s to %s", U.FormatDate(case.firstTs), U.FormatDate(case.lastTs)),
    }
    if case.kind == "items" then
        local items = {}
        for link, count in pairs(case.items) do items[#items + 1] = { link = link, count = count } end
        table.sort(items, function(a, b) return a.count > b.count end)
        for i = 1, math.min(12, #items) do
            lines[#lines + 1] = string.format("%dx %s", items[i].count, ItemName(items[i].link))
        end
        if #items > 12 then lines[#lines + 1] = string.format("...and %d more kinds", #items - 12) end
        lines[#lines + 1] = string.format("Counted toward your limits: %s", FormatAmount(case.kind, case.total, case.unit))
        if returns.whole + returns.partial > 0 then
            lines[#lines + 1] = string.format("Put back: %d whole (not counted), %d partly used (still counted)", returns.whole, returns.partial)
            for i = 1, math.min(10, #returns.lines) do lines[#lines + 1] = returns.lines[i] end
            if #returns.lines > 10 then lines[#lines + 1] = string.format("...and %d more", #returns.lines - 10) end
        end
    end

    return GT.Report.AddMenu({ text = text, tooltip = table.concat(lines, "\n") }, self:CaseItems(case))
end

function BankWatch:KickCase(case, alsoBlacklist)
    A.Kick(case.guildId, case.name, alsoBlacklist, self:BlacklistNote(case), function() self:CloseCase(case, "kicked") end)
end

function BankWatch:BlacklistCase(case)
    A.ConfirmBlacklist(case.guildId, case.name, self:BlacklistNote(case), function() self:CloseCase(case, "blacklisted") end)
end

-- Everything you can do about a bank alert, for its right-click menu (Whisper first).
-- Nothing that changes the guild runs without its confirm window, and nothing is sent
-- until you press Enter or Send.
function BankWatch:CaseItems(case)
    local g = self:G(case.guildId)
    local stillMember = U.IsPlayerInGuild(case.guildId) and U.IsMember(case.guildId, case.name)
    local handled = case.status == "kicked" or case.status == "blacklisted"
    local items = GT.Report.ContactItems(case.name)
    local function Add(item) items[#items + 1] = item end
    if stillMember and not handled then
        if case.mailPending then
            Add({ label = "Send the demotion mail", fn = function()
                case.mailPending = nil
                self:MailDemotion(case)
                GT.Report:RefreshIfShown()
            end })
        end
        -- Both ways to warn; the one picked under "Warn by" in settings comes first.
        for _, method in ipairs(g.warnMethod == "mail" and { "mail", "whisper" } or { "whisper", "mail" }) do
            Add({ label = "Warn by " .. method, fn = function() self:WarnCase(case, method) end })
        end
        Add({ label = "Demote (asks first)", fn = function()
            A.Demote(case.guildId, case.name, g.demoteToRank, function()
                self:CloseCase(case, "demoted")
                self:MailDemotion(case)
            end, DEMOTE_MAIL_NOTE)
        end })
        Add({ label = "Set rank...", opensMenu = true, fn = function(control)
            A.ChooseRank(control, case.guildId, case.name, function(rankName, lowered)
                case.rankSetTo = rankName
                self:CloseCase(case, "rankset")
                if lowered then self:MailDemotion(case) end
            end, DEMOTE_MAIL_NOTE)
        end })
        Add({ label = (case.notedAt and "Add to guild note again" or "Add to guild note") .. " (asks first)", fn = function()
            A.AppendNote(case.guildId, case.name, self:GetNoteLine(case), function()
                case.notedAt = GetTimeStamp()
                GT.Report:RefreshIfShown()
            end)
        end })
        Add({ label = "Kick (asks first)", fn = function() self:KickCase(case, false) end })
        Add({ label = "Kick and blacklist (asks first)", fn = function() self:KickCase(case, true) end })
    elseif not handled then
        Add({ label = "Blacklist (asks first)", fn = function() self:BlacklistCase(case) end })
    end
    if self:IsNew(case) then
        Add({ label = "Mark seen", fn = function() case.seen = true; GT.Report:RefreshIfShown() end })
    end
    if case.status == "open" then
        Add({ label = "Dismiss alert", fn = function() self:CloseCase(case, "dismissed") end })
    else
        Add({ label = "Remove from list", fn = function()
            for i, c in ipairs(self.sv.cases) do
                if c == case then table.remove(self.sv.cases, i) break end
            end
            GT.Report:RefreshIfShown()
        end })
    end
    return items
end

-- "stacks per day: warn 6, demote 15, kick off" for one guild.
function BankWatch:DescribeLimits(guildId)
    local g = self:G(guildId)
    local function At(n) return n > 0 and tostring(n) or "off" end
    return string.format("%s %s: warn %s, demote %s, kick %s", g.countMode == "withdrawals" and "stacks" or "items",
        self:PeriodLabel(guildId), At(g.warnAt), At(g.demoteAt), At(g.kickAt))
end

function BankWatch:GetVisibleCases()
    local list = {}
    for _, case in ipairs(self.sv.cases) do
        -- 1.26.7 (Albert): alerts that cleared themselves (everything put back whole, e.g. a restack)
        -- aren't shown; they come back if the member takes more and goes over a limit again.
        if case.status ~= "dismissed" and case.status ~= "returned" and GT:IsAlertGuild(case.guildId) then list[#list + 1] = case end
    end
    -- Newest first, and a row keeps its place when you warn/demote it
    -- (it used to jump to the bottom, which looked like it disappeared).
    table.sort(list, function(a, b)
        if a.lastTs ~= b.lastTs then return a.lastTs > b.lastTs end
        return (a.firstTs or 0) > (b.firstTs or 0)
    end)
    return list
end

-- An open alert you haven't looked at yet (1.26.6, Albert: seeing it is enough, no need to dismiss).
function BankWatch:IsNew(case)
    return case.status == "open" and not case.seen
end

function BankWatch:CountNew()
    local n = 0
    for _, case in ipairs(self.sv.cases) do
        if self:IsNew(case) and GT:IsAlertGuild(case.guildId) then n = n + 1 end
    end
    return n
end

-- Called when you leave the Bank alerts tab or close the window: what you saw is no longer new.
function BankWatch:MarkShownSeen()
    for _, case in ipairs(self:GetVisibleCases()) do case.seen = true end
end

function BankWatch:CountOpen()
    local n = 0
    for _, case in ipairs(self.sv.cases) do
        if case.status == "open" and GT:IsAlertGuild(case.guildId) then n = n + 1 end
    end
    return n
end

function BankWatch:TabRows()
    local rows = {}
    for _, case in ipairs(self:GetVisibleCases()) do rows[#rows + 1] = self:GetCaseRow(case) end
    return rows
end

function BankWatch:TabExportLines()
    local lines = { "Severity\tStatus\tGuild\tMember\tRank when flagged\tType\tAmount counted\tStacks taken\tItems taken\tPut back whole\tPut back partly\tFirst\tLast\tItems" }
    local names = { [SEVERITY_WARN] = "Warn", [SEVERITY_DEMOTE] = "Demote", [SEVERITY_KICK] = "Kick" }
    for _, case in ipairs(self:GetVisibleCases()) do
        local returns = self:GetCaseReturns(case)
        local items = {}
        for link, count in pairs(case.items or {}) do items[#items + 1] = count .. "x " .. ItemName(link) end
        lines[#lines + 1] = table.concat({ names[case.severity] or "", case.status, case.guildName, case.name,
            case.rankName or "", case.kind, case.total, returns.stacks or "", returns.items, returns.whole, returns.partial,
            U.FormatDate(case.firstTs), U.FormatDate(case.lastTs), (table.concat(items, ", "):gsub("[\t\n]", " ")) }, "\t")
    end
    return lines
end

function BankWatch:TabSummary()
    local parts = {}
    for _, guildId in ipairs(U.GetGuildIds()) do
        if GT:IsAlertGuild(guildId) then parts[#parts + 1] = U.GuildName(guildId) .. ": " .. self:DescribeLimits(guildId) end
    end
    if #parts == 0 then return "" end   -- the tab says so itself (GT:FeatureOffText)
    return table.concat(parts, ".  ") .. ".  Stacks put back whole don't count. |c5EB8FFNEW|r = not seen yet. Hover a row for details."
end

function BankWatch:RegisterTab()
    GT.Report:RegisterTab({
        id = "bank",
            GetOffText = function() return GT:FeatureOffText(self.sv.enabled, "Bank alerts", true) end,
        tip = "People who took more from the guild bank than your limits allow.",
        title = function() return string.format("Bank alerts (%d new)", self:CountNew()) end,
        about = {
            "Lists members who took more from a guild bank in one day than your limits allow.",
            "Right-click an alert to warn, demote or kick the member, or to dismiss it. Each one asks first; nothing is automatic unless you turn on auto-demote.",
            "Stacks a member puts back whole don't count. Limits and who to ignore are set for each guild on the Guild rules settings page.",
        },
        emptyText = "No one is over your limits.",
        OnLeave = function() self:MarkShownSeen() end,
        GetSummary = function() return self:TabSummary() end,
        GetRows = function() return self:TabRows() end,
        GetExportLines = function() return self:TabExportLines() end,
        footer = {
            { label = "Rescan with settings", tip = "Checks the bank history again with your current limits.", fn = function() GT:Rescan() end },
            { label = "Mark all seen", tip = "Takes the NEW tag off every alert without dismissing it. Leaving this tab or closing the window does the same.", fn = function()
                self:MarkShownSeen()
                GT.Report:RefreshIfShown()
            end },
            { label = "Dismiss all open", tip = "Hides every alert you haven't dealt with yet (warned, demoted, kicked or dismissed). Asks first.", fn = function()
                A.Confirm("Dismiss alerts", "Dismiss every bank alert you haven't dealt with yet?", function()
                    for _, case in ipairs(self.sv.cases) do
                        if case.status == "open" then self:CloseCase(case, "dismissed") end
                    end
                end)
            end },
            { label = "Clear handled", tip = "Deletes alerts that are no longer new: warned, demoted, kicked or dismissed.", fn = function()
                for i = #self.sv.cases, 1, -1 do
                    if self.sv.cases[i].status ~= "open" then table.remove(self.sv.cases, i) end
                end
                GT.Report:RefreshIfShown()
            end },
        },
    })
end

-- Settings ------------------------------------------------------------------

-- Settings for all guilds.
function BankWatch:BuildSettings(options)
    local sv, defaults = self.sv, self.defaults
    local controls = {
        { type = "checkbox", name = "Enable bank alerts", getFunc = function() return sv.enabled end,
          setFunc = function(v) sv.enabled = v end, default = defaults.enabled, requiresReload = true },
        { type = "description", text = "Limits, who to ignore, mail texts and auto-demote are set for each guild under Rules for (guild) on the Guild rules page." },
        GT.Settings:RulesButton("Opens the Guild rules page, where each guild's bank limits, ignored ranks and names, warning and demotion mails, and auto-demote are set."),
        { type = "slider", name = "Auto-demote at most per session (all guilds)", min = 1, max = 20, step = 1,
          tooltip = "A safety cap for auto-demote, counted over all your guilds together.",
          getFunc = function() return sv.autoDemoteMaxPerSession end, setFunc = function(v) sv.autoDemoteMaxPerSession = v end,
          default = defaults.autoDemoteMaxPerSession },
        { type = "checkbox", name = "Open the report at login when there are new alerts",
          getFunc = function() return sv.openWindowOnLogin end, setFunc = function(v) sv.openWindowOnLogin = v end,
          default = defaults.openWindowOnLogin },
    }
    options[#options + 1] = { type = "submenu", name = "Guild bank alerts", controls = controls }
end

-- One guild's bank alert settings, inside that guild's Rules submenu.
function BankWatch:BuildGuildSettings(controls, guildId)
    local defaults = self.defaults
    local g = self:G(guildId)
    local rankChoices, rankValues = { "One rank down" }, { 0 }
    for rankIndex = 1, GetNumGuildRanks(guildId) do
        rankChoices[#rankChoices + 1] = string.format("%d %s", rankIndex, GetFinalGuildRankName(guildId, rankIndex))
        rankValues[#rankValues + 1] = rankIndex
    end
    local list = {
        { type = "header", name = "Bank limits" },
        { type = "dropdown", name = "Count by",
          tooltip = "Stacks: taking a stack of 200 recipes counts as 1. Item quantity: it counts as 200. Either way, a stack the member puts back whole doesn't count; a partly used one does.",
          choices = { "Item quantity", "Stacks (each withdrawal = 1)" }, choicesValues = { "quantity", "withdrawals" },
          getFunc = function() return g.countMode end, setFunc = function(v) g.countMode = v end, default = defaults.countMode },
        { type = "dropdown", name = "Count per",
          tooltip = "Calendar day: everything taken from midnight to midnight (your PC's clock) counts together, so 5 stacks Saturday night and 5 Sunday morning are 5 each day. Rolling window: everything within the hours below counts together. Click Rescan alerts after changing it.",
          choices = { "Calendar day", "Rolling window (hours)" }, choicesValues = { "day", "rolling" },
          getFunc = function() return g.windowMode end, setFunc = function(v) g.windowMode = v end, default = defaults.windowMode },
        { type = "slider", name = "Rolling window (hours)", min = 1, max = 168, step = 1,
          getFunc = function() return g.windowHours end, setFunc = function(v) g.windowHours = v end, default = defaults.windowHours,
          disabled = function() return g.windowMode == "day" end },
        { type = "slider", name = "Items: warn at (0 = never)", tooltip = "Stacks (or items, see Count by) a member takes from the guild bank, per day or rolling window, at which you get a warning alert. 0 = never.", min = 0, max = 1000, step = 1,
          getFunc = function() return g.warnAt end, setFunc = function(v) g.warnAt = v end, default = defaults.warnAt },
        { type = "slider", name = "Items: demote at (0 = never)", tooltip = "Stacks (or items, see Count by) a member takes from the guild bank, per day or rolling window, at which the member is flagged for a demotion. 0 = never.", min = 0, max = 2000, step = 1,
          getFunc = function() return g.demoteAt end, setFunc = function(v) g.demoteAt = v end, default = defaults.demoteAt },
        { type = "slider", name = "Items: kick at (0 = never)", tooltip = "Stacks (or items, see Count by) a member takes from the guild bank, per day or rolling window, at which the member is flagged for a kick. 0 = never.", min = 0, max = 5000, step = 1,
          getFunc = function() return g.kickAt end, setFunc = function(v) g.kickAt = v end, default = defaults.kickAt },
        { type = "slider", name = "Gold: warn at (0 = never)", min = 0, max = 1000000, step = 1000, clampInput = false,
          tooltip = "Gold a member takes from the guild bank, counted per day or rolling window like the items. 0 = never. You can also type a number in the box. All three gold limits at 0 = gold is not watched.",
          getFunc = function() return g.goldWarnAt end, setFunc = function(v) g.goldWarnAt = v end, default = defaults.goldWarnAt },
        { type = "slider", name = "Gold: demote at (0 = never)", min = 0, max = 5000000, step = 1000, clampInput = false,
          tooltip = "Gold taken from the guild bank at which the member is flagged for a demotion. 0 = never. You can also type a number in the box.",
          getFunc = function() return g.goldDemoteAt end, setFunc = function(v) g.goldDemoteAt = v end, default = defaults.goldDemoteAt },
        { type = "slider", name = "Gold: kick at (0 = never)", min = 0, max = 10000000, step = 1000, clampInput = false,
          tooltip = "Gold taken from the guild bank at which the member is flagged for a kick. 0 = never. You can also type a number in the box.",
          getFunc = function() return g.goldKickAt end, setFunc = function(v) g.goldKickAt = v end, default = defaults.goldKickAt },
        { type = "header", name = "Bank: who to ignore" },
        { type = "slider", name = "Ignore the top N ranks", min = 0, max = 10, step = 1,
          tooltip = "Rank 1 is the Guild Master. 2 ignores the Guild Master and the rank below. See the rank list below.",
          getFunc = function() return g.excludeTopRanks end, setFunc = function(v) g.excludeTopRanks = v end, default = defaults.excludeTopRanks },
        { type = "editbox", name = "Ignore these rank names", tooltip = "Comma separated, for example: Officer, Banker",
          isMultiline = false, getFunc = function() return g.excludeRanks end, setFunc = function(v) g.excludeRanks = v end },
        { type = "editbox", name = "Ignore these @names", tooltip = "Comma or line separated, for example: @Banker1, @Crafter2",
          isMultiline = true, getFunc = function() return g.excludeNames end, setFunc = function(v) g.excludeNames = v end },
        { type = "description", text = GT.Settings:DescribeGuildRanks(guildId) },
        { type = "header", name = "Bank: actions and mail" },
        { type = "dropdown", name = "Warn by", tooltip = "The right-click menu on a bank alert offers both ways to warn. This one is listed first.", choices = { "Whisper (you press Enter)", "Mail (you press Send)" },
          choicesValues = { "whisper", "mail" }, getFunc = function() return g.warnMethod end,
          setFunc = function(v) g.warnMethod = v end, default = defaults.warnMethod },
        { type = "editbox", name = "Warning text", isMultiline = true,
          tooltip = "<<1>> name, <<2>> amount, <<3>> guild, <<4>> hours of the rolling window, <<5>> date of the withdrawals, <<6>> bank rules",
          getFunc = function() return g.warnText end, setFunc = function(v) g.warnText = v end, default = defaults.warnText },
        { type = "editbox", name = "Demotion mail", isMultiline = true,
          tooltip = "Opens after you confirm Demote, or Set rank to a lower rank. Same placeholders as the warning.",
          getFunc = function() return g.demoteText end, setFunc = function(v) g.demoteText = v end, default = defaults.demoteText },
        { type = "editbox", name = "Bank rules (for <<6>>)", isMultiline = true,
          tooltip = "Leave empty to use your Crier's \"Guild Bank 101\" message, so the warning always matches what the Crier posts.",
          getFunc = function() return g.rulesText end, setFunc = function(v) g.rulesText = v end, default = defaults.rulesText },
        { type = "dropdown", name = "Demote to", choices = rankChoices, choicesValues = rankValues,
          tooltip = "The rank Demote (and auto-demote) sets. One rank down moves them one step below their current rank.",
          getFunc = function() return g.demoteToRank end, setFunc = function(v) g.demoteToRank = v end, default = defaults.demoteToRank },
        { type = "checkbox", name = "Auto-demote at the demote threshold",
          tooltip = "Demotes automatically (no dialog) when someone in this guild reaches the demote threshold. Only withdrawals made after you turn this on count, never anyone at or above your rank, and never ignored names or ranks. Off by default. The demotion mail is only sent automatically if you also turn on 'Send the demotion mail automatically'; otherwise the alert gets a Send mail button. Kick and blacklist always need your click.",
          getFunc = function() return g.autoDemote end,
          setFunc = function(v) g.autoDemote = v; if v then g.autoDemoteSince = GetTimeStamp() end end, default = defaults.autoDemote },
        { type = "checkbox", name = "Send the demotion mail automatically",
          tooltip = "After an auto-demote, the demotion mail is sent without opening the mail window (waits until you're out of combat). If it fails, the alert gets a Send mail button.",
          getFunc = function() return g.autoDemoteMail end, setFunc = function(v) g.autoDemoteMail = v end,
          default = defaults.autoDemoteMail, disabled = function() return not g.autoDemote end },
        { type = "checkbox", name = "Note the reason in their guild note",
          tooltip = "After an auto-demote, adds one line to the end of their guild note, for example \"Bank Nov 18: took 41 stacks (157 items), put back 0 whole/0 partly. Auto-demoted (limit 15 per day).\" Their note is kept. Skipped if the line is already there or the note would go over the game's 254 characters. Needs the note-editing permission for your rank.",
          getFunc = function() return g.autoDemoteNote end, setFunc = function(v) g.autoDemoteNote = v end,
          default = defaults.autoDemoteNote, disabled = function() return not g.autoDemote end },
    }
    for _, control in ipairs(list) do controls[#controls + 1] = control end
end
