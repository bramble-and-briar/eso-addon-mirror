-- Automatic actions: a record of everything the addon does by itself (auto-demote, the
-- automatic demotion mail, adding hoppers to the watchlist), with the reason behind each
-- one. Each action also shows a notice on screen and a breakdown in chat as it happens.
--
-- Nothing is assumed: a demotion is marked confirmed only when the server reports the new
-- rank (EVENT_GUILD_MEMBER_RANK_CHANGED, or the roster shows it), and a mail only when the
-- server answers EVENT_MAIL_SEND_SUCCESS (see Actions.SendMailNow).

local GT = FurysGuildToolset
local U = GT.Util

local AutoLog = GT:RegisterModule("auto", {})
GT.AutoLog = AutoLog

local MAX_ENTRIES = 500
local MAX_WITHDRAWALS_KEPT = 100     -- per demotion, in the saved log
local CHAT_WITHDRAWALS = 10          -- per demotion, in the chat breakdown
local RANK_CONFIRM_TIMEOUT_MS = 20000
local ALERT_MAX_LINES = 8            -- demotions listed in the alert window, newest first

AutoLog.defaults = {
    bigNotice = false,     -- large center-screen notice for demotions and mail results
    alertWindow = false,   -- alert window for auto-demotes that stays until you close it
    keepDays = 90,
    nextId = 1,
    entries = {},         -- newest last
}

function AutoLog:Initialize(sv)
    self.sv = sv
    self.pendingRank = {}   -- ["guildId:@name"] = entry waiting for the server
    -- A reload or logout stops anything that was still waiting.
    for _, e in ipairs(sv.entries) do
        if e.mail == "queued" then
            e.mail, e.mailReason = "failed", "interrupted by a reload or logout"
        end
    end
    self:Prune()
    self:RegisterTab()
    self.alertEntries = {}
    -- Registering with the scene manager makes Esc close the alert and shows the mouse cursor.
    SCENE_MANAGER:RegisterTopLevel(FurysGuildToolset_AutoAlert, false)
    FurysGuildToolset_AutoAlert:SetHandler("OnHide", function()
        ClearTooltip(InformationTooltip)
        self.alertEntries = {}
    end)
    EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_AutoRank", EVENT_GUILD_MEMBER_RANK_CHANGED, function(_, guildId, displayName)
        local entry = self.pendingRank[tostring(guildId) .. ":" .. tostring(displayName)]
        if entry then self:CheckRank(entry) end
    end)
end

function AutoLog:OnPlayerActivated()
    -- A demotion still waiting when you reloaded: read the roster now that it's loaded.
    for _, e in ipairs(self.sv.entries) do
        if e.rankState == "pending" then self:CheckRank(e, true) end
    end
    local n = self:CountNew()
    if n > 0 then
        U.Print("%d automatic %s you haven't reviewed. Type /gt auto.", n, n == 1 and "action" or "actions")
    end
end

function AutoLog:Prune()
    local cutoff = GetTimeStamp() - self.sv.keepDays * 86400
    local entries = self.sv.entries
    for i = #entries, 1, -1 do
        if entries[i].ts < cutoff then table.remove(entries, i) end
    end
    while #entries > MAX_ENTRIES do table.remove(entries, 1) end
end

function AutoLog:Add(entry)
    entry.id = self.sv.nextId
    self.sv.nextId = self.sv.nextId + 1
    entry.ts = entry.ts or GetTimeStamp()
    entry.new = true
    table.insert(self.sv.entries, entry)
    while #self.sv.entries > MAX_ENTRIES do table.remove(self.sv.entries, 1) end
    GT.Report:RefreshIfShown()
    return entry
end

function AutoLog:CountNew()
    local n = 0
    for _, e in ipairs(self.sv.entries) do
        if e.new then n = n + 1 end
    end
    return n
end

-- Notices -------------------------------------------------------------------

-- Large center-screen notice plus the usual corner alert.
function AutoLog:Notice(title, subtitle, sound)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, title)
    if not self.sv.bigNotice then return end
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound)
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
    params:SetText(title, subtitle)
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

local function Time(ts)
    return os.date("%H:%M", ts)
end

-- Alert window ----------------------------------------------------------------

-- Shows the alert window for an auto-demote, or adds it to the one already showing.
function AutoLog:ShowAlert(entry)
    table.insert(self.alertEntries, 1, entry)
    local n = #self.alertEntries
    FurysGuildToolset_AutoAlertTitle:SetText(n == 1 and zo_strformat("Auto-demoted <<1>>", entry.who)
        or string.format("%d members auto-demoted", n))
    local lines = {}
    for i = 1, math.min(n, ALERT_MAX_LINES) do
        local e = self.alertEntries[i]
        lines[#lines + 1] = zo_strformat("|cB4B0D8<<1>>|r  |cFFC857<<2>>|r: <<3>> to <<4>> in <<5>>. Took <<6>> (<<7>>).",
            Time(e.ts), e.who, e.fromRank or "?", e.toRank, e.guild, e.amount, e.rule)
    end
    if n > ALERT_MAX_LINES then
        lines[#lines + 1] = string.format("|cB4B0D8...and %d more. Open log shows them all.|r", n - ALERT_MAX_LINES)
    end
    FurysGuildToolset_AutoAlertBody:SetText(table.concat(lines, "\n"))
    FurysGuildToolset_AutoAlert:SetHeight(20 + FurysGuildToolset_AutoAlertTitle:GetTextHeight() + 14 + FurysGuildToolset_AutoAlertBody:GetTextHeight() + 18 + 30 + 20)
    PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
    U.ShowOnTop(FurysGuildToolset_AutoAlert)
end

function AutoLog:HideAlert()
    SCENE_MANAGER:HideTopLevel(FurysGuildToolset_AutoAlert)
end

function AutoLog:OpenLogFromAlert()
    self:HideAlert()
    GT.Report:Show("auto")
end

-- Auto-demote ---------------------------------------------------------------

-- info: guildId, name, fromRank, toRank, toRankIndex, kind, amount ("52 stacks"),
-- rule ("demote at 50 stacks in 24h"), windowHours, firstTs, lastTs,
-- withdrawals = { { ts =, text = "3x Dreugh Wax" }, ... } oldest first, mail = "queued" | "off"
function AutoLog:RecordDemotion(info)
    local list, more = {}, 0
    for i, w in ipairs(info.withdrawals) do
        if i <= MAX_WITHDRAWALS_KEPT then list[#list + 1] = { ts = w.ts, text = w.text } else more = more + 1 end
    end
    local entry = self:Add({
        kind = "demote", g = info.guildId, guild = U.GuildName(info.guildId), who = info.name,
        fromRank = info.fromRank, toRank = info.toRank, toRankIndex = info.toRankIndex,
        amount = info.amount, rule = info.rule, firstTs = info.firstTs, lastTs = info.lastTs,
        withdrawals = list, moreWithdrawals = more, rankState = "pending", mail = info.mail,
    })
    self.pendingRank[tostring(entry.g) .. ":" .. entry.who] = entry
    zo_callLater(function() self:CheckRank(entry, true) end, RANK_CONFIRM_TIMEOUT_MS)

    if self.sv.alertWindow then
        self:ShowAlert(entry)
    else
        self:Notice(zo_strformat("Auto-demoted <<1>>", entry.who),
            zo_strformat("<<1>> to <<2>> in <<3>>. Took <<4>>. /gt auto", entry.fromRank or "?", entry.toRank, entry.guild, entry.amount),
            SOUNDS.GENERAL_ALERT_ERROR)
    end
    U.Print("|cFFA45CAUTO-DEMOTED|r %s in %s: %s to %s.", entry.who, entry.guild, entry.fromRank or "?", entry.toRank)
    U.Print("  Why: took %s from the guild bank between %s and %s (rule: %s).",
        entry.amount, U.FormatDate(entry.firstTs), U.FormatDate(entry.lastTs), entry.rule)
    for i = 1, math.min(CHAT_WITHDRAWALS, #list) do
        U.Print("    %s  %s", Time(list[i].ts), list[i].text)
    end
    local hidden = #list + more - CHAT_WITHDRAWALS
    if hidden > 0 then U.Print("    ...and %d more. Full list: /gt auto, hover the row.", hidden) end
    if entry.mail == "queued" then
        U.Print("  Mail: the demotion mail will be sent automatically. You'll get a notice when the server confirms it.")
    else
        U.Print("  Mail: automatic mail is off. Right-click it on /gt auto or /gt bank and pick Send the demotion mail.")
    end
    return entry
end

-- Confirms the rank change from the roster. final = the timeout ran out.
function AutoLog:CheckRank(entry, final)
    if entry.rankState ~= "pending" then return end
    local rankIndex = U.GetMemberRank(entry.g, entry.who)
    local key = tostring(entry.g) .. ":" .. entry.who
    if rankIndex and entry.toRankIndex and rankIndex == entry.toRankIndex then
        entry.rankState = "confirmed"
        self.pendingRank[key] = nil
        U.Print("Rank change confirmed: %s is now %s in %s.", entry.who, entry.toRank, entry.guild)
    elseif final then
        entry.rankState = "unconfirmed"
        self.pendingRank[key] = nil
        local now = rankIndex and GetFinalGuildRankName(entry.g, rankIndex) or "not in the guild"
        self:Notice(zo_strformat("Demotion of <<1>> not confirmed", entry.who),
            zo_strformat("The roster shows <<1>> (expected <<2>>). Check the guild roster.", now, entry.toRank),
            SOUNDS.GENERAL_ALERT_ERROR)
        U.Print("|cFF6B86Demotion not confirmed|r: %s in %s shows as %s, expected %s.", entry.who, entry.guild, now, entry.toRank)
    end
    GT.Report:RefreshIfShown()
end

-- ok: server confirmed the mail. reason: why it failed.
function AutoLog:MailResult(entry, ok, reason)
    entry.mailTs = GetTimeStamp()
    if ok then
        entry.mail, entry.mailReason = "sent", nil
        self:Notice(zo_strformat("Demotion mail sent to <<1>>", entry.who), "Confirmed by the server.", nil)
        U.Print("|c5EE6A0Mail sent|r: the demotion mail to %s was delivered to the server at %s.", entry.who, Time(entry.mailTs))
    else
        entry.mail, entry.mailReason = "failed", reason or "unknown"
        self:Notice(zo_strformat("Demotion mail to <<1>> FAILED", entry.who),
            zo_strformat("<<1>>. Right-click it on /gt auto and pick Send the demotion mail.", entry.mailReason), SOUNDS.GENERAL_ALERT_ERROR)
        U.Print("|cFF6B86Mail failed|r: the demotion mail to %s was not sent (%s). Right-click it on /gt auto or /gt bank and pick Send the demotion mail.",
            entry.who, entry.mailReason)
    end
    GT.Report:RefreshIfShown()
end

-- Sent by hand from Send mail in the right-click menu (opens the compose window; you press Send).
function AutoLog:MailOpenedByHand(entry)
    entry.mail, entry.mailReason, entry.mailTs = "manual", nil, GetTimeStamp()
    GT.Report:RefreshIfShown()
end

-- An auto-demote that was due but didn't happen. Logged once per reason per alert.
function AutoLog:RecordSkipped(guildId, name, reason, amount, rule)
    self:Add({ kind = "skipped", g = guildId, guild = U.GuildName(guildId), who = name, reason = reason, amount = amount, rule = rule })
    U.Alert(zo_strformat("Didn't auto-demote <<1>> in <<2>>: <<3>>. They took <<4>> (rule: <<5>>).", name, U.GuildName(guildId), reason, amount, rule))
end

function AutoLog:RecordCapReached(limit)
    self:Add({ kind = "cap", reason = string.format("auto-demote limit of %d per session reached", limit) })
    self:Notice("Auto-demote limit reached", string.format("%d this session. The rest wait in /gt bank.", limit), SOUNDS.GENERAL_ALERT_ERROR)
end

-- Hopper added to the watchlist. notify = false while history is still catching up.
function AutoLog:RecordWatchlist(guildId, name, reason, notify)
    self:Add({ kind = "watchlist", g = guildId, guild = U.GuildName(guildId), who = name, reason = reason })
    if not notify then
        self.sv.entries[#self.sv.entries].new = nil
        return
    end
    U.Print("Added %s to your watchlist automatically: %s.", name, reason)
end

-- Report tab ------------------------------------------------------------------

local KIND_LABEL = {
    demote = "|cFFA45CAuto-demoted|r",
    skipped = "|cFFC857Not demoted|r",
    cap = "|cFFC857Limit reached|r",
    watchlist = "|cA08CFFWatchlisted|r",
}

local function RankStateText(e)
    if e.rankState == "confirmed" then return "|c5EE6A0rank confirmed|r" end
    if e.rankState == "unconfirmed" then return "|cFF6B86rank NOT confirmed|r" end
    return "|cB4B0D8waiting server|r"
end

local function MailText(e)
    if e.mail == "sent" then return "|c5EE6A0mail sent " .. Time(e.mailTs) .. "|r" end
    if e.mail == "failed" then return "|cFF6B86mail failed: " .. (e.mailReason or "?") .. "|r" end
    if e.mail == "queued" then return "|cB4B0D8mail sending...|r" end
    if e.mail == "manual" then return "|cB4B0D8mail opened by you " .. Time(e.mailTs) .. "|r" end
    return "|cFFC857auto mail off|r"
end

local function PlainMail(e)
    return (MailText(e):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function PlainRank(e)
    return (RankStateText(e):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function AutoLog:Describe(e)
    if e.kind == "demote" then
        return zo_strformat("<<1>> <<2>> from <<3>> to <<4>> in <<5>>, took <<6>>", KIND_LABEL.demote, e.who,
            e.fromRank or "?", e.toRank, e.guild, e.amount)
    elseif e.kind == "skipped" then
        return zo_strformat("<<1>> <<2>> in <<3>>: <<4>>", KIND_LABEL.skipped, e.who, e.guild, e.reason)
    elseif e.kind == "cap" then
        return KIND_LABEL.cap .. ": " .. e.reason
    end
    return zo_strformat("<<1>> <<2>> (<<3>>)", KIND_LABEL.watchlist, e.who, e.reason)
end

function AutoLog:GetTooltip(e)
    local lines = { U.FormatDate(e.ts) }
    if e.kind == "demote" then
        lines[#lines + 1] = zo_strformat("<<1>> in <<2>>: <<3>> to <<4>>", e.who, e.guild, e.fromRank or "?", e.toRank)
        lines[#lines + 1] = "Rule: " .. e.rule
        lines[#lines + 1] = string.format("Took %s between %s and %s:", e.amount, U.FormatDate(e.firstTs), U.FormatDate(e.lastTs))
        for i = 1, math.min(25, #e.withdrawals) do
            local w = e.withdrawals[i]
            lines[#lines + 1] = string.format("  %s  %s", os.date("%m-%d %H:%M", w.ts), w.text)
        end
        local hidden = #e.withdrawals + (e.moreWithdrawals or 0) - 25
        if hidden > 0 then lines[#lines + 1] = string.format("  ...and %d more (Export / copy shows all)", hidden) end
        lines[#lines + 1] = "Rank change: " .. PlainRank(e)
        lines[#lines + 1] = "Demotion mail: " .. PlainMail(e)
        if e.note == "added" then
            lines[#lines + 1] = "Guild note: added \"" .. (e.noteLine or "") .. "\""
        elseif e.note then
            lines[#lines + 1] = "Guild note: not added (" .. e.note .. ")"
        end
    elseif e.reason then
        if e.who then lines[#lines + 1] = zo_strformat("<<1>> in <<2>>", e.who, e.guild) end
        lines[#lines + 1] = "Why: " .. e.reason
        if e.amount then lines[#lines + 1] = string.format("Took %s (rule: %s)", e.amount, e.rule) end
    end
    return table.concat(lines, "\n")
end

local function FindBankCase(e)
    local bank = GT:GetModule("bank")
    for _, case in ipairs(bank.sv.cases) do
        if case.autoDemoted and case.guildId == e.g and case.name == e.who
            and (case.firstTs or case.lastTs) <= e.lastTs and case.lastTs >= e.lastTs then
            return bank, case
        end
    end
end

function AutoLog:GetRow(e)
    local text = string.format("|cB4B0D8%s|r  %s", U.FormatDate(e.ts), self:Describe(e))
    if e.kind == "demote" then text = text .. "  " .. RankStateText(e) .. ", " .. MailText(e) end
    if e.new then text = "|cECEAF8*|r " .. text end
    local actions = {}
    if e.kind == "demote" and e.mail ~= "sent" and e.mail ~= "queued" and U.IsMember(e.g, e.who) then
        local bank, case = FindBankCase(e)
        if case then
            actions[#actions + 1] = { label = "Send the demotion mail", tip = "Opens the demotion mail for you to review and send.", fn = function()
                case.mailPending = nil
                bank:MailDemotion(case)
                self:MailOpenedByHand(e)
            end }
        end
    end
    if e.new then
        actions[#actions + 1] = { label = "Mark reviewed", tip = "Marks this as reviewed so it no longer counts as new.", fn = function()
            e.new = nil
            GT.Report:RefreshIfShown()
        end }
    end
    actions[#actions + 1] = { label = "Remove from log", tip = "Deletes this entry from the log.", fn = function()
        for i, x in ipairs(self.sv.entries) do
            if x == e then table.remove(self.sv.entries, i) break end
        end
        GT.Report:RefreshIfShown()
    end }
    for _, item in ipairs(GT.Report.ContactItems(e.who)) do actions[#actions + 1] = item end
    return GT.Report.AddMenu({ text = text, tooltip = self:GetTooltip(e) }, actions)
end

function AutoLog:GetVisible()
    local list = {}
    for i = #self.sv.entries, 1, -1 do
        local e = self.sv.entries[i]
        if not e.g or GT:IsAlertGuild(e.g) then list[#list + 1] = e end
    end
    return list
end

function AutoLog:TabRows()
    local rows = {}
    for _, e in ipairs(self:GetVisible()) do rows[#rows + 1] = self:GetRow(e) end
    return rows
end

function AutoLog:TabExportLines()
    local lines = { "Time\tAction\tGuild\tMember\tFrom rank\tTo rank\tAmount\tRule\tRank change\tMail\tReason / withdrawals" }
    for _, e in ipairs(self:GetVisible()) do
        local detail = e.reason or ""
        if e.kind == "demote" then
            local w = {}
            for _, x in ipairs(e.withdrawals) do w[#w + 1] = os.date("%Y-%m-%d %H:%M", x.ts) .. " " .. x.text end
            if (e.moreWithdrawals or 0) > 0 then w[#w + 1] = string.format("...and %d more", e.moreWithdrawals) end
            detail = table.concat(w, "; ")
        end
        lines[#lines + 1] = (table.concat({ U.FormatDate(e.ts), e.kind, e.guild or "", e.who or "", e.fromRank or "", e.toRank or "",
            e.amount or "", e.rule or "", e.kind == "demote" and PlainRank(e) or "", e.kind == "demote" and PlainMail(e) or "",
            detail }, "\t"):gsub("\n", " "))
    end
    return lines
end

function AutoLog:TabSummary()
    return string.format("Automatic actions, newest first, kept %d days. Hover a row for the full reason.", self.sv.keepDays)
end

function AutoLog:RegisterTab()
    GT.Report:RegisterTab({
        id = "auto",
        tip = "Everything the addon did by itself: auto-demotes with the withdrawals behind them, whether the demotion mail was sent, and hoppers added to the watchlist.",
        title = function()
            local n = self:CountNew()
            return n > 0 and string.format("Auto (%d new)", n) or "Auto"
        end,
        about = {
            "Lists everything the addon did by itself, with the reason: auto-demotes, automatic demotion mails and hoppers added to the watchlist.",
            "It stays empty unless you turn on auto-demote or the automatic watchlist for a guild on the Guild rules settings page.",
        },
        emptyText = "Nothing has been done automatically.",
        GetSummary = function() return self:TabSummary() end,
        GetRows = function() return self:TabRows() end,
        GetExportLines = function() return self:TabExportLines() end,
        footer = {
            { label = "Mark all reviewed", tip = "Marks every entry as reviewed so none count as new.", fn = function()
                for _, e in ipairs(self.sv.entries) do e.new = nil end
                GT.Report:RefreshIfShown()
            end },
            { label = "Clear log", tip = "Deletes every entry in this log. Asks first.", fn = function()
                GT.Actions.Confirm("Clear log", "Delete every entry in the automatic actions log?", function()
                    self.sv.entries = {}
                    GT.Report:RefreshIfShown()
                end)
            end },
        },
    })
end

-- Settings ------------------------------------------------------------------

function AutoLog:TestAlert()
    self:ShowAlert({ ts = GetTimeStamp(), who = "@Example", fromRank = "Member", toRank = "Recruit",
        guild = "Test (nothing changed)", amount = "16 stacks", rule = "demote at 15 stacks per day" })
end

function AutoLog:BuildSettings(options)
    local sv, defaults = self.sv, self.defaults
    options[#options + 1] = { type = "submenu", name = "Automatic actions", controls = {
        { type = "description", text = "Every automatic action (auto-demote, the automatic demotion mail, hoppers added to the watchlist) is announced in chat with the reason and kept in the Auto tab (/gt auto). Whether each guild auto-demotes and sends the demotion mail is set under Rules for (guild) on the Guild rules page." },
        GT.Settings:RulesButton("Opens the Guild rules page, where auto-demote and the automatic demotion mail are turned on or off for each guild."),
        { type = "checkbox", name = "Alert window for auto-demotes",
          tooltip = "Opens a big alert window when someone is auto-demoted. It stays on screen until you close it with its Close button, the X or Esc. Several demotions in a row are listed in the same window. Off: a short notice that fades by itself instead.",
          getFunc = function() return sv.alertWindow end, setFunc = function(v) sv.alertWindow = v end, default = defaults.alertWindow },
        { type = "button", name = "Test the alert window", tooltip = "Shows the alert window with a made-up demotion so you can see it. Nothing is changed in any guild and nothing is logged.",
          func = function() self:TestAlert() end },
        { type = "checkbox", name = "Large on-screen notice",
          tooltip = "Shows a large notice in the middle of the screen when the demotion mail is sent or fails, and when a demotion can't be confirmed (and for auto-demotes when the alert window is off).",
          getFunc = function() return sv.bigNotice end, setFunc = function(v) sv.bigNotice = v end, default = defaults.bigNotice },
        { type = "slider", name = "Keep the log for (days)", min = 7, max = 365, step = 1,
          getFunc = function() return sv.keepDays end, setFunc = function(v) sv.keepDays = v end, default = defaults.keepDays },
    } }
end
