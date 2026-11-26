-- Officer actions shared by every module. Nothing here runs without a click from the
-- player, and anything that changes the roster asks for confirmation first, except the
-- opt-in auto-demote and its mail (see below).
--
-- What the game allows an addon to do:
--   GuildDemote / GuildSetRank / GuildRemove / AddToGuildBlacklistByDisplayName are normal
--   (unprotected) API calls, gated only by your rank permissions. We still require a click
--   and a confirmation dialog so nothing happens by accident.
--   Chat: addons cannot send chat messages. We can only open the chat box with a whisper
--   pre-filled; you press Enter.
--   Mail: Warn and Demote open the compose window with recipient, subject and body filled
--   in; you press Send. The one exception is the opt-in "Send the demotion mail
--   automatically" setting: after an auto-demote it sends the mail in the background
--   (Actions.SendMailNow), which costs normal postage. Success is reported only when the
--   server confirms with EVENT_MAIL_SEND_SUCCESS. The kick and blacklist mails (opt-in,
--   per guild) are sent the same way, but only after you click Confirm in the kick window.
--   Auto-demote (also opt-in) is the one roster change made without a dialog.

local GT = FurysGuildToolset
local U = GT.Util
local Actions = {}
GT.Actions = Actions

local BLACKLIST_NOTE_MAX = 150

-- 1.31.3: the confirm pop-up is the shared one (UI/Theme.lua), the same in every Fury addon.
function Actions.Confirm(title, body, onConfirm)
    GT.Theme.Confirm(title, body, nil, onConfirm)
end

-- A small box that asks for a whole number (1 or more), then calls onNumber(n). Used for
-- adding and removing raffle tickets by hand (1.29.0). Confirm stays greyed out until
-- something is typed; Cancel changes nothing.
local NUMBER_DIALOG = "FURYSGUILDTOOLSET_NUMBER"
local numberDialogRegistered = false

local function NumberEntered(dialog)
    local n = tonumber(ZO_Dialogs_GetEditBoxText(dialog))
    if n and n >= 1 then dialog.data.onNumber(math.floor(n)) end
end

local function EnsureNumberDialog()
    if numberDialogRegistered then return end
    numberDialogRegistered = true
    ZO_Dialogs_RegisterCustomDialog(NUMBER_DIALOG, {
        title = { text = "<<1>>" },
        mainText = { text = "<<1>>" },
        editBox = { defaultText = "Type a number", maxInputCharacters = 5, textType = TEXT_TYPE_NUMERIC_UNSIGNED_INT },
        buttons = {
            { text = SI_DIALOG_CONFIRM, requiresTextInput = true, callback = NumberEntered },
            { text = SI_DIALOG_CANCEL },
        },
    })
end

function Actions.AskNumber(title, body, onNumber)
    EnsureNumberDialog()
    ZO_Dialogs_ShowDialog(NUMBER_DIALOG, { onNumber = onNumber }, {
        titleParams = { title },
        mainTextParams = { body },
    })
end

local function Need(guildId, permission, what)
    if U.HasPermission(guildId, permission) then return true end
    U.Print("Your rank in %s can't %s.", U.GuildName(guildId), what)
    return false
end

local function NeedMember(guildId, displayName)
    if U.IsMember(guildId, displayName) then return true end
    U.Print("%s is no longer in %s.", displayName, U.GuildName(guildId))
    return false
end

-- Fills the mail compose window. Works whether or not it's already open
-- (ComposeMailTo alone does nothing useful when the window is already showing).
local function FillMail(displayName, subject, body)
    MAIL_SEND.to:SetText(displayName)
    MAIL_SEND.subject:SetText(subject)
    MAIL_SEND.body:SetText(body)
end

-- method: "whisper" or "mail"
function Actions.Warn(displayName, subject, body, method)
    if method == "mail" then
        local reportWasOpen = FurysGuildToolset_Report and not FurysGuildToolset_Report:IsHidden()
        if SCENE_MANAGER:IsShowing("mailSend") then
            FillMail(displayName, subject, body)
        else
            MAIL_SEND:ComposeMailTo(displayName, subject)
            SCENE_MANAGER:CallWhen("mailSend", SCENE_SHOWN, function()
                FillMail(displayName, subject, body)
                -- Opening the mail scene can close the report window; bring it back.
                if reportWasOpen and FurysGuildToolset_Report:IsHidden() then GT.Report:Show() end
            end)
        end
        U.Print("Mail to %s is ready. Review it and press Send.", displayName)
    else
        StartChatInput(body, CHAT_CHANNEL_WHISPER, displayName)
        U.Print("Whisper to %s is ready in the chat box. Press Enter to send.", displayName)
    end
end

-- targetRankIndex: nil or 0 demotes one step; otherwise sets that rank (larger = lower).
-- note: optional extra line for the confirm dialog (e.g. that a mail will open).
function Actions.Demote(guildId, displayName, targetRankIndex, onDone, note)
    if not NeedMember(guildId, displayName) then return end
    if not Need(guildId, GUILD_PERMISSION_DEMOTE, "demote members") then return end
    local currentRank = U.GetMemberRank(guildId, displayName)
    local numRanks = GetNumGuildRanks(guildId)
    local useSetRank = targetRankIndex and targetRankIndex > 0 and targetRankIndex <= numRanks
    if useSetRank and currentRank and currentRank >= targetRankIndex then
        U.Print("%s is already at or below %s.", displayName, GetFinalGuildRankName(guildId, targetRankIndex))
        return
    end
    local toText = useSetRank and GetFinalGuildRankName(guildId, targetRankIndex) or "one rank lower"
    Actions.Confirm("Demote member",
        zo_strformat("Demote <<1>> in <<2>> to <<3>>?", displayName, U.GuildName(guildId), toText) .. (note and ("\n\n" .. note) or ""),
        function()
            if useSetRank then
                GuildSetRank(guildId, displayName, targetRankIndex)
            else
                GuildDemote(guildId, displayName)
            end
            U.Print("Demoted %s in %s.", displayName, U.GuildName(guildId))
            if onDone then onDone() end
        end)
end

-- Background mail for the opt-in auto-demote and automatic welcome mails (Albert chose to
-- send these automatically). The game only sends mail while the mailbox is open, so we open
-- it quietly, send, and close it. Waits while you're in combat or using the mail window yourself.
--
-- 1.31.0 (Albert): other addons work the mailbox too (Writ Crafter loots hireling mails as soon
-- as a mailbox opens), and a send made while they take items can get no answer from the server.
-- So the queue waits until the mailbox is closed and no mail has moved for a few seconds,
-- waits again after the mailbox opens, closes it only when the others are done, and tries
-- each mail up to 3 times, a while apart, before it reports a failure.
-- onResult(true) on success, onResult(false, reason) on failure (after the last try).
local mailQueue, mailBusy = {}, false
local MAIL_TIMEOUT_MS = 15000
local MAIL_TRIES = 3
local MAIL_RETRY_MS = { 30000, 60000 }   -- wait before the 2nd and the 3rd try
local MAIL_QUIET_MS = 5000               -- no mail moved for this long = other addons are done
local MAIL_MAX_WAIT_MS = 120000          -- never wait longer than this for others
local MAIL_POLL_MS = 1000

local mailboxOpen = nil                  -- nil, "ours" or "other"
local ourOpenPending = nil               -- function to call when the mailbox we asked for opens
local lastMailActivity = 0

local function Now() return GetGameTimeMilliseconds() end
local function MailQuiet() return Now() - lastMailActivity >= MAIL_QUIET_MS end
local function MarkMailActivity() lastMailActivity = Now() end

-- Calls fn once no mail has moved for MAIL_QUIET_MS, or after maxMs at the latest.
local function WhenMailQuiet(fn, maxMs)
    local started = Now()
    local function check()
        if MailQuiet() or Now() - started >= maxMs then fn() else zo_callLater(check, MAIL_POLL_MS) end
    end
    check()
end

local function WatchMailbox()
    local ns = "FurysGuildToolset_MailWatch"
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_MAIL_OPEN_MAILBOX, function()
        MarkMailActivity()
        if ourOpenPending then
            local fn = ourOpenPending
            ourOpenPending = nil
            mailboxOpen = "ours"
            fn()
        else
            mailboxOpen = "other"
        end
    end)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_MAIL_CLOSE_MAILBOX, function()
        mailboxOpen = nil
        MarkMailActivity()
    end)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_MAIL_INBOX_UPDATE, MarkMailActivity)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_MAIL_READABLE, MarkMailActivity)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_MAIL_REMOVED, MarkMailActivity)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, MarkMailActivity)
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS, MarkMailActivity)
end
WatchMailbox()

local MailPump
local pumpScheduled = false

-- One pending pump at a time, so waiting jobs don't start several polling loops.
local function SchedulePump(ms)
    if pumpScheduled then return end
    pumpScheduled = true
    zo_callLater(function() pumpScheduled = false; MailPump() end, ms)
end

local function Blocked()
    -- Opening the mailbox would pull you out of a guild bank, crafting station or dialogue,
    -- so wait until you're free.
    return IsUnitInCombat("player") or IsUnitDead("player") or IsInteracting()
        or SCENE_MANAGER:IsShowing("mailInbox") or SCENE_MANAGER:IsShowing("mailSend")
end

local function RunJob(job)
    local token = {}
    job.token = token
    job.tries = (job.tries or 0) + 1
    local opened = false
    local function Finish(ok, reason)
        if job.token ~= token then return end
        job.token = nil
        ourOpenPending = nil
        EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_Mail", EVENT_MAIL_SEND_SUCCESS)
        EVENT_MANAGER:UnregisterForEvent("FurysGuildToolset_Mail", EVENT_MAIL_SEND_FAILED)
        -- Close the mailbox we opened, but only once other addons are done with it.
        WhenMailQuiet(function()
            if mailboxOpen == "ours" or (opened and mailboxOpen == nil) then CloseMailbox() end
            if mailboxOpen == "ours" then mailboxOpen = nil end
            table.remove(mailQueue, 1)
            if not ok and job.tries < MAIL_TRIES then
                local wait = MAIL_RETRY_MS[job.tries] or MAIL_RETRY_MS[#MAIL_RETRY_MS]
                U.Print("Mail to %s didn't go through (%s). Trying again in %d seconds (try %d of %d).",
                    job.to, reason or "unknown", wait / 1000, job.tries + 1, MAIL_TRIES)
                job.notBefore = Now() + wait
                mailQueue[#mailQueue + 1] = job
                mailBusy = false
                SchedulePump(1500)
                return
            end
            mailBusy = false
            if job.onResult then job.onResult(ok, reason) end
            SchedulePump(1500)
        end, 20000)
    end
    local function Send()
        if job.token ~= token then return end
        if not mailboxOpen then
            Finish(false, "another addon closed the mailbox")
            return
        end
        EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Mail", EVENT_MAIL_SEND_SUCCESS, function() Finish(true) end)
        EVENT_MANAGER:RegisterForEvent("FurysGuildToolset_Mail", EVENT_MAIL_SEND_FAILED, function(_, reason)
            Finish(false, GetString("SI_SENDMAILRESULT", reason) ~= "" and GetString("SI_SENDMAILRESULT", reason) or tostring(reason))
        end)
        zo_callLater(function() Finish(false, "timed out") end, MAIL_TIMEOUT_MS)
        SendMail(job.to, job.subject, job.body)
    end
    if mailboxOpen then
        -- Still open after the longest wait (another addon left it open): send through it.
        Send()
        return
    end
    ourOpenPending = function()
        opened = true
        -- Other addons start on the mailbox the moment it opens; let them finish first.
        zo_callLater(function() WhenMailQuiet(Send, 20000) end, 1500)
    end
    zo_callLater(function()
        if job.token == token and not opened then Finish(false, "the mailbox didn't open") end
    end, MAIL_TIMEOUT_MS + 25000)
    RequestOpenMailbox()
end

MailPump = function()
    if mailBusy or #mailQueue == 0 then return end
    if Blocked() then
        SchedulePump(5000)
        return
    end
    local job = mailQueue[1]
    if job.notBefore and Now() < job.notBefore then
        SchedulePump(job.notBefore - Now() + 100)
        return
    end
    -- Wait while another addon (or you) has the mailbox open or mail is still moving.
    job.waitStart = job.waitStart or Now()
    local waited = Now() - job.waitStart
    if waited < MAIL_MAX_WAIT_MS and (mailboxOpen or not MailQuiet()) then
        SchedulePump(MAIL_POLL_MS * 2)
        return
    end
    job.waitStart = nil
    mailBusy = true
    RunJob(job)
end

function Actions.SendMailNow(to, subject, body, onResult)
    mailQueue[#mailQueue + 1] = { to = to, subject = subject, body = body, onResult = onResult }
    MailPump()
end

-- Demotes without a dialog. Used only by the opt-in "Auto-demote" bank setting.
-- Refuses anyone at or above your own rank.
-- Returns true, newRankName, newRankIndex, oldRankName on success, or false, reason.
function Actions.DemoteNow(guildId, displayName, targetRankIndex)
    if not U.IsMember(guildId, displayName) then return false, "no longer in the guild" end
    if not U.HasPermission(guildId, GUILD_PERMISSION_DEMOTE) then return false, "your rank can't demote" end
    local currentRank = U.GetMemberRank(guildId, displayName)
    local myRank = U.GetMemberRank(guildId, GetDisplayName()) or 1
    if not currentRank or currentRank <= myRank then return false, "at or above your rank" end
    local numRanks = GetNumGuildRanks(guildId)
    if targetRankIndex and targetRankIndex > 0 and targetRankIndex <= numRanks then
        if currentRank >= targetRankIndex then return false, "already at or below that rank" end
        GuildSetRank(guildId, displayName, targetRankIndex)
        return true, GetFinalGuildRankName(guildId, targetRankIndex), targetRankIndex, GetFinalGuildRankName(guildId, currentRank)
    end
    if currentRank >= numRanks then return false, "already the lowest rank" end
    GuildDemote(guildId, displayName)
    return true, GetFinalGuildRankName(guildId, currentRank + 1), currentRank + 1, GetFinalGuildRankName(guildId, currentRank)
end

-- Shows a menu of ranks under the clicked button; picking one asks for confirmation.
-- Only ranks below your own are offered (the game won't let you set others).
function Actions.ChooseRank(owner, guildId, displayName, onDone, demoteNote)
    if not NeedMember(guildId, displayName) then return end
    local currentRank = U.GetMemberRank(guildId, displayName)
    local myRank = U.GetMemberRank(guildId, GetDisplayName()) or 1
    if currentRank and currentRank <= myRank then
        U.Print("%s is at or above your rank in %s.", displayName, U.GuildName(guildId))
        return
    end
    ClearMenu()
    for rankIndex = myRank + 1, GetNumGuildRanks(guildId) do
        local rankName = GetFinalGuildRankName(guildId, rankIndex)
        local label = rankName
        if rankIndex == currentRank then label = label .. " (current)" end
        if not DoesGuildRankHavePermission(guildId, rankIndex, GUILD_PERMISSION_BANK_WITHDRAW) then
            label = label .. " - no bank"
        end
        local index = rankIndex
        AddMenuItem(label, function()
            if index == currentRank then return end
            Actions.SetRank(guildId, displayName, index, onDone, demoteNote)
        end)
    end
    ShowMenu(owner)
end

-- demoteNote: extra confirm line shown only when this lowers the rank.
-- onDone(rankName, lowered)
function Actions.SetRank(guildId, displayName, rankIndex, onDone, demoteNote)
    if not NeedMember(guildId, displayName) then return end
    local currentRank = U.GetMemberRank(guildId, displayName)
    local promoting = currentRank and rankIndex < currentRank
    if promoting then
        if not Need(guildId, GUILD_PERMISSION_PROMOTE, "promote members") then return end
    elseif not Need(guildId, GUILD_PERMISSION_DEMOTE, "demote members") then
        return
    end
    local rankName = GetFinalGuildRankName(guildId, rankIndex)
    Actions.Confirm("Set guild rank",
        zo_strformat("Set <<1>>'s rank in <<2>> from <<3>> to <<4>>?", displayName, U.GuildName(guildId),
            currentRank and GetFinalGuildRankName(guildId, currentRank) or "?", rankName)
            .. ((demoteNote and not promoting) and ("\n\n" .. demoteNote) or ""),
        function()
            GuildSetRank(guildId, displayName, rankIndex)
            U.Print("Set %s to %s in %s.", displayName, rankName, U.GuildName(guildId))
            if onDone then onDone(rankName, not promoting) end
        end)
end

function Actions.Blacklist(guildId, displayName, note, silent)
    if not Need(guildId, GUILD_PERMISSION_MANAGE_BLACKLIST, "manage the blacklist") then return false end
    note = (note or ""):sub(1, BLACKLIST_NOTE_MAX)
    local result = AddToGuildBlacklistByDisplayName(guildId, displayName, note)
    if result == GUILD_BLACKLIST_RESPONSE_BLACKLIST_SUCCESSFULLY_ADDED then
        if not silent then U.Print("Blacklisted %s in %s.", displayName, U.GuildName(guildId)) end
        return true
    elseif result == GUILD_BLACKLIST_RESPONSE_ALREADY_BLACKLISTED then
        if not silent then U.Print("%s is already on the %s blacklist.", displayName, U.GuildName(guildId)) end
        return true
    end
    U.Print("Couldn't blacklist %s in %s: %s", displayName, U.GuildName(guildId),
        GetString("SI_GUILDBLACKLISTRESPONSE", result))
    return false
end

-- Adds a line to the end of a member's guild note (their existing note is kept).
-- Asks first and shows the line. Refuses when the note would go over the game's limit.
local GUILD_NOTE_MAX = 254

-- Adds one line to a member's guild note right away, with no dialog (used after an
-- auto-demote). Returns true, or false and the reason. A line already in the note is not
-- added twice, and a note that would go over the game's limit is left as it is.
function Actions.AppendNoteNow(guildId, displayName, line)
    if not U.HasPermission(guildId, GUILD_PERMISSION_NOTE_EDIT) then return false, "your rank can't edit member notes" end
    local index = GetGuildMemberIndexFromDisplayName(guildId, displayName)
    if not index then return false, "no longer in the guild" end
    local _, current = GetGuildMemberInfo(guildId, index)
    current = current or ""
    if current:find(line, 1, true) then return false, "the note already has this line" end
    local note = (current == "") and line or (current .. "\n" .. line)
    if #note > GUILD_NOTE_MAX then
        return false, string.format("their note has %d characters and the line needs %d more (limit %d)", #current, #note - #current, GUILD_NOTE_MAX)
    end
    SetGuildMemberNote(guildId, index, note)
    return true
end

function Actions.AppendNote(guildId, displayName, line, onDone)
    if not NeedMember(guildId, displayName) then return end
    if not Need(guildId, GUILD_PERMISSION_NOTE_EDIT, "edit member notes") then return end
    local memberIndex = GetGuildMemberIndexFromDisplayName(guildId, displayName)
    local _, oldNote = GetGuildMemberInfo(guildId, memberIndex)
    oldNote = oldNote or ""
    if oldNote:find(line, 1, true) then
        U.Print("%s's note in %s already has this line.", displayName, U.GuildName(guildId))
        return
    end
    local newNote = (oldNote == "") and line or (oldNote .. "\n" .. line)
    if #newNote > GUILD_NOTE_MAX then
        U.Print("%s's note in %s has %d characters and this line needs %d more; the game allows %d. Shorten their note first.",
            displayName, U.GuildName(guildId), #oldNote, #newNote - #oldNote, GUILD_NOTE_MAX)
        return
    end
    Actions.Confirm("Add to guild note", zo_strformat("Add this line to <<1>>'s note in <<2>>?", displayName, U.GuildName(guildId))
        .. "\n\n" .. line .. "\n\nTheir current note is kept.", function()
        -- Look the member up again: the roster can change while the dialog is open.
        local index = GetGuildMemberIndexFromDisplayName(guildId, displayName)
        if not index then U.Print("%s is no longer in %s.", displayName, U.GuildName(guildId)) return end
        local _, current = GetGuildMemberInfo(guildId, index)
        current = current or ""
        local note = (current == "") and line or (current .. "\n" .. line)
        if #note > GUILD_NOTE_MAX then
            U.Print("%s's note changed and the line no longer fits. Nothing was written.", displayName)
            return
        end
        SetGuildMemberNote(guildId, index, note)
        U.Print("Added to %s's note in %s: %s", displayName, U.GuildName(guildId), line)
        if onDone then onDone() end
    end)
end

-- Kick / blacklist window ---------------------------------------------------------
-- Kick, Kick and blacklist and Blacklist all go through one confirm window. When
-- blacklisting it has a reason box (prefilled, you can change it) that becomes the
-- blacklist note and the reason in the mail. A kick from the Inactive tab can mail the
-- member why and that they're welcome back; a blacklist can mail them the reason. Both
-- mails are off until you turn them on in the guild's settings, and the Mail button in the
-- window turns the mail on or off for that one person. The mail is sent after you click
-- Confirm, in the background (normal postage).

local MAIL_BODY_MAX = 700
local removeJob
local removeDialogReady = false

local function MemberTexts(guildId)
    return GT:GetModule("members"):G(guildId)
end

-- Blacklist notes made by this addon start with "FGMT: ". The mail drops that prefix.
local function MailReason(reason)
    local text = (reason or ""):gsub("^FGMT:%s*", "")
    text = zo_strtrim(text)
    return (text:gsub("^%l", string.upper))
end

-- Subject and body of the mail for this kick or blacklist, or nil when there is none.
function Actions.GetRemovalMail(job, reason)
    local g = MemberTexts(job.guildId)
    local guild = U.GuildName(job.guildId)
    local subject, body
    if job.blacklist then
        subject = zo_strformat(g.blacklistSubject, job.name, guild, MailReason(reason))
        body = zo_strformat(g.blacklistText, job.name, guild, MailReason(reason))
    elseif job.inactive then
        local days, limit = tostring(job.inactive.days), tostring(job.inactive.limitDays)
        subject = zo_strformat(g.kickSubject, job.name, guild, days, limit)
        body = zo_strformat(g.kickText, job.name, guild, days, limit)
    else
        return nil
    end
    return subject, body:sub(1, MAIL_BODY_MAX)
end

local function CurrentReason()
    if not removeJob or not removeJob.blacklist then return "" end
    return zo_strtrim(FurysGuildToolset_RemoveDialogReasonBox:GetText())
end

local function MailTip()
    local job = removeJob
    if not job then return nil end
    local subject, body = Actions.GetRemovalMail(job, CurrentReason())
    local lines = {
        job.sendMail and "This mail is sent after you click Confirm. Click to skip it for this one."
            or "No mail will be sent. Click to send this mail after you click Confirm.",
        "Change the text in settings: Rules for (guild), Mail when you kick or blacklist.",
        "",
        "To: " .. job.name,
        "Subject: " .. (subject or ""),
        "",
        body or "",
    }
    return table.concat(lines, "\n")
end

local function SetMailButtonText()
    FurysGuildToolset_RemoveDialogMail:SetText(removeJob.sendMail and "Send mail: Yes" or "Send mail: No")
end

local function EnsureRemoveDialog()
    if removeDialogReady then return end
    removeDialogReady = true
    -- Registering with the scene manager makes Esc close the window and shows the mouse cursor.
    SCENE_MANAGER:RegisterTopLevel(FurysGuildToolset_RemoveDialog, false)
    FurysGuildToolset_RemoveDialog:SetHandler("OnHide", function() removeJob = nil; ClearTooltip(InformationTooltip) end)
    FurysGuildToolset_RemoveDialogReasonBox:SetMaxInputChars(BLACKLIST_NOTE_MAX)
    local R = GT.Report
    R.SetTip(FurysGuildToolset_RemoveDialogClose, "Cancel (Esc). Nothing is changed.")
    R.SetTip(FurysGuildToolset_RemoveDialogCancel, "Closes this window. Nothing is changed and no mail is sent.")
    R.SetTip(FurysGuildToolset_RemoveDialogConfirm, function()
        if not removeJob then return nil end
        local parts = {}
        if removeJob.kick then parts[#parts + 1] = "removes them from the guild" end
        if removeJob.blacklist then parts[#parts + 1] = "adds them to the guild blacklist with the reason above" end
        if removeJob.canMail and removeJob.sendMail then parts[#parts + 1] = "sends them the mail (hover Send mail to read it)" end
        return "Does it now: " .. table.concat(parts, ", then ") .. "."
    end)
    R.SetTip(FurysGuildToolset_RemoveDialogMail, MailTip)
    R.SetTip(FurysGuildToolset_RemoveDialogReasonBox, "What they did. It becomes their blacklist note (up to 150 characters) and the reason in the mail.")
end

local function LayoutRemoveDialog()
    local job = removeJob
    local c = FurysGuildToolset_RemoveDialog
    FurysGuildToolset_RemoveDialogReasonLabel:SetHidden(not job.blacklist)
    FurysGuildToolset_RemoveDialogReason:SetHidden(not job.blacklist)
    FurysGuildToolset_RemoveDialogMail:SetHidden(not job.canMail)
    local last = job.blacklist and FurysGuildToolset_RemoveDialogReason or FurysGuildToolset_RemoveDialogBody
    FurysGuildToolset_RemoveDialogMail:ClearAnchors()
    FurysGuildToolset_RemoveDialogMail:SetAnchor(TOPLEFT, last, BOTTOMLEFT, 0, 18)
    FurysGuildToolset_RemoveDialogCancel:ClearAnchors()
    FurysGuildToolset_RemoveDialogCancel:SetAnchor(TOPRIGHT, last, BOTTOMRIGHT, 0, 18)
    local height = 18 + FurysGuildToolset_RemoveDialogTitle:GetTextHeight() + 12 + FurysGuildToolset_RemoveDialogBody:GetTextHeight()
    if job.blacklist then
        height = height + 12 + FurysGuildToolset_RemoveDialogReasonLabel:GetTextHeight() + 4 + FurysGuildToolset_RemoveDialogReason:GetHeight()
    end
    c:SetHeight(height + 18 + 30 + 22)
end

-- job = { guildId, name, kick = bool, blacklist = bool, reason = prefill text,
--         inactive = { days, limitDays } for a kick from the Inactive tab, onDone = fn }
function Actions.ConfirmRemove(job)
    if job.kick then
        if not NeedMember(job.guildId, job.name) then return end
        if not Need(job.guildId, GUILD_PERMISSION_REMOVE, "remove members") then return end
    end
    if job.blacklist and not Need(job.guildId, GUILD_PERMISSION_MANAGE_BLACKLIST, "manage the blacklist") then return end
    EnsureRemoveDialog()
    local g = MemberTexts(job.guildId)
    local guild = U.GuildName(job.guildId)
    job.canMail = job.blacklist or job.inactive ~= nil
    if job.blacklist then job.sendMail = g.blacklistMail
    elseif job.inactive then job.sendMail = g.kickMail
    else job.sendMail = false end
    removeJob = job

    local title, body
    if job.kick and job.blacklist then
        title = "Kick and blacklist"
        body = zo_strformat("Remove <<1>> from <<2>> and add them to the guild blacklist?", job.name, guild)
    elseif job.kick then
        title = job.inactive and "Kick for inactivity" or "Kick member"
        body = zo_strformat("Remove <<1>> from <<2>>?", job.name, guild)
        if job.inactive then
            body = body .. zo_strformat(" They have been offline <<1>> days and the limit for their rank is <<2>> days.",
                tostring(job.inactive.days), tostring(job.inactive.limitDays))
        end
    else
        title = "Blacklist"
        body = zo_strformat("Add <<1>> to the <<2>> blacklist?", job.name, guild)
    end
    if job.canMail then
        body = body .. "\n\n" .. (job.blacklist and "The mail tells them the reason. Hover Send mail to read it."
            or "The mail tells them why and that they're welcome back. Hover Send mail to read it.")
    end
    FurysGuildToolset_RemoveDialogTitle:SetText(title)
    FurysGuildToolset_RemoveDialogBody:SetText(body)
    FurysGuildToolset_RemoveDialogReasonBox:SetText(job.reason or "")
    SetMailButtonText()
    LayoutRemoveDialog()
    U.ShowOnTop(FurysGuildToolset_RemoveDialog)
end

function Actions.CloseRemoveDialog()
    SCENE_MANAGER:HideTopLevel(FurysGuildToolset_RemoveDialog)
end

function Actions.ToggleRemoveMail()
    if not removeJob then return end
    removeJob.sendMail = not removeJob.sendMail
    SetMailButtonText()
    GT.Report.ShowTip(FurysGuildToolset_RemoveDialogMail, MailTip())
end

function Actions.SendRemovalMail(job, reason)
    local subject, body = Actions.GetRemovalMail(job, reason)
    if not subject then return end
    U.Print("Mailing %s: %s", job.name, subject)
    Actions.SendMailNow(job.name, subject, body, function(ok, why)
        if ok then
            U.Print("Mail sent to %s.", job.name)
        else
            U.Print("Couldn't mail %s (%s). Mail them yourself if you still want to.", job.name, why or "unknown")
        end
    end)
end

function Actions.ConfirmRemoveDialog()
    local job = removeJob
    if not job then return end
    local reason = CurrentReason()
    if job.blacklist and job.sendMail and MailReason(reason) == "" then
        U.Print("Type the reason first. It goes in the blacklist note and the mail.")
        return
    end
    Actions.CloseRemoveDialog()
    if job.kick then
        if not NeedMember(job.guildId, job.name) then return end
        GuildRemove(job.guildId, job.name)
        U.Print("Removed %s from %s.", job.name, U.GuildName(job.guildId))
    end
    if job.blacklist and not Actions.Blacklist(job.guildId, job.name, reason) then
        if job.kick and job.onDone then job.onDone(reason) end
        return
    end
    if job.canMail and job.sendMail then Actions.SendRemovalMail(job, reason) end
    if job.onDone then job.onDone(reason) end
end

-- Kick (and blacklist). inactive = { days, limitDays } when kicking from the Inactive tab.
function Actions.Kick(guildId, displayName, alsoBlacklist, note, onDone, inactive)
    Actions.ConfirmRemove({ guildId = guildId, name = displayName, kick = true, blacklist = alsoBlacklist,
        reason = note, inactive = inactive, onDone = onDone })
end

-- Blacklist someone (they may have left already). onDone(reason) after it worked.
function Actions.ConfirmBlacklist(guildId, displayName, note, onDone)
    Actions.ConfirmRemove({ guildId = guildId, name = displayName, blacklist = true, reason = note, onDone = onDone })
end

-- Blacklist without the window, for "Blacklist all new" (that list was confirmed once).
-- Mails each person their reason when the guild's blacklist mail is on.
function Actions.BlacklistAndMail(guildId, displayName, note)
    if not Actions.Blacklist(guildId, displayName, note) then return false end
    if MemberTexts(guildId).blacklistMail and MailReason(note) ~= "" then
        Actions.SendRemovalMail({ guildId = guildId, name = displayName, blacklist = true }, note)
    end
    return true
end
