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

local GT = FuryGMT
local U = GT.Util
local Actions = {}
GT.Actions = Actions

local CONFIRM_DIALOG = "FURYGMT_CONFIRM"
local BLACKLIST_NOTE_MAX = 150
local dialogRegistered = false

local function EnsureDialog()
    if dialogRegistered then return end
    dialogRegistered = true
    ZO_Dialogs_RegisterCustomDialog(CONFIRM_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "<<1>>" },
        mainText = { text = "<<1>>" },
        buttons = {
            { text = SI_DIALOG_CONFIRM, callback = function(dialog) dialog.data.onConfirm() end },
            { text = SI_DIALOG_CANCEL },
        },
    })
end

function Actions.Confirm(title, body, onConfirm)
    EnsureDialog()
    ZO_Dialogs_ShowDialog(CONFIRM_DIALOG, { onConfirm = onConfirm }, {
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
        local reportWasOpen = FuryGMTReport and not FuryGMTReport:IsHidden()
        if SCENE_MANAGER:IsShowing("mailSend") then
            FillMail(displayName, subject, body)
        else
            MAIL_SEND:ComposeMailTo(displayName, subject)
            SCENE_MANAGER:CallWhen("mailSend", SCENE_SHOWN, function()
                FillMail(displayName, subject, body)
                -- Opening the mail scene can close the report window; bring it back.
                if reportWasOpen and FuryGMTReport:IsHidden() then GT.Report:Show() end
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

-- Background mail for the opt-in auto-demote (Albert chose to send it automatically).
-- The game only sends mail while the mailbox is open, so we open it quietly, send,
-- and close it. Waits while you're in combat or using the mail window yourself.
-- onResult(true) on success, onResult(false, reason) on failure.
local mailQueue, mailBusy = {}, false
local MAIL_TIMEOUT_MS = 15000

local function MailPump()
    if mailBusy or #mailQueue == 0 then return end
    -- Opening the mailbox would pull you out of a guild bank, crafting station or dialogue,
    -- so wait until you're free.
    if IsUnitInCombat("player") or IsUnitDead("player") or IsInteracting()
        or SCENE_MANAGER:IsShowing("mailInbox") or SCENE_MANAGER:IsShowing("mailSend") then
        zo_callLater(MailPump, 5000)
        return
    end
    mailBusy = true
    local job = mailQueue[1]
    local token = {}
    job.token = token
    EVENT_MANAGER:RegisterForEvent("FuryGMTMail", EVENT_MAIL_OPEN_MAILBOX, function()
        EVENT_MANAGER:UnregisterForEvent("FuryGMTMail", EVENT_MAIL_OPEN_MAILBOX)
        SendMail(job.to, job.subject, job.body)
    end)
    local function Finish(ok, reason)
        if job.token ~= token then return end
        job.token = nil
        EVENT_MANAGER:UnregisterForEvent("FuryGMTMail", EVENT_MAIL_OPEN_MAILBOX)
        EVENT_MANAGER:UnregisterForEvent("FuryGMTMail", EVENT_MAIL_SEND_SUCCESS)
        EVENT_MANAGER:UnregisterForEvent("FuryGMTMail", EVENT_MAIL_SEND_FAILED)
        CloseMailbox()
        table.remove(mailQueue, 1)
        mailBusy = false
        if job.onResult then job.onResult(ok, reason) end
        zo_callLater(MailPump, 1500)
    end
    EVENT_MANAGER:RegisterForEvent("FuryGMTMail", EVENT_MAIL_SEND_SUCCESS, function() Finish(true) end)
    EVENT_MANAGER:RegisterForEvent("FuryGMTMail", EVENT_MAIL_SEND_FAILED, function(_, reason)
        Finish(false, GetString("SI_SENDMAILRESULT", reason) ~= "" and GetString("SI_SENDMAILRESULT", reason) or tostring(reason))
    end)
    zo_callLater(function() Finish(false, "timed out") end, MAIL_TIMEOUT_MS)
    RequestOpenMailbox()
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
    return zo_strtrim(FuryGMTRemoveDialogReasonBox:GetText())
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
    FuryGMTRemoveDialogMail:SetText(removeJob.sendMail and "Send mail: Yes" or "Send mail: No")
end

local function EnsureRemoveDialog()
    if removeDialogReady then return end
    removeDialogReady = true
    -- Registering with the scene manager makes Esc close the window and shows the mouse cursor.
    SCENE_MANAGER:RegisterTopLevel(FuryGMTRemoveDialog, false)
    FuryGMTRemoveDialog:SetHandler("OnHide", function() removeJob = nil; ClearTooltip(InformationTooltip) end)
    FuryGMTRemoveDialogReasonBox:SetMaxInputChars(BLACKLIST_NOTE_MAX)
    local R = GT.Report
    R.SetTip(FuryGMTRemoveDialogClose, "Cancel (Esc). Nothing is changed.")
    R.SetTip(FuryGMTRemoveDialogCancel, "Closes this window. Nothing is changed and no mail is sent.")
    R.SetTip(FuryGMTRemoveDialogConfirm, function()
        if not removeJob then return nil end
        local parts = {}
        if removeJob.kick then parts[#parts + 1] = "removes them from the guild" end
        if removeJob.blacklist then parts[#parts + 1] = "adds them to the guild blacklist with the reason above" end
        if removeJob.canMail and removeJob.sendMail then parts[#parts + 1] = "sends them the mail (hover Send mail to read it)" end
        return "Does it now: " .. table.concat(parts, ", then ") .. "."
    end)
    R.SetTip(FuryGMTRemoveDialogMail, MailTip)
    R.SetTip(FuryGMTRemoveDialogReasonBox, "What they did. It becomes their blacklist note (up to 150 characters) and the reason in the mail.")
end

local function LayoutRemoveDialog()
    local job = removeJob
    local c = FuryGMTRemoveDialog
    FuryGMTRemoveDialogReasonLabel:SetHidden(not job.blacklist)
    FuryGMTRemoveDialogReason:SetHidden(not job.blacklist)
    FuryGMTRemoveDialogMail:SetHidden(not job.canMail)
    local last = job.blacklist and FuryGMTRemoveDialogReason or FuryGMTRemoveDialogBody
    FuryGMTRemoveDialogMail:ClearAnchors()
    FuryGMTRemoveDialogMail:SetAnchor(TOPLEFT, last, BOTTOMLEFT, 0, 18)
    FuryGMTRemoveDialogCancel:ClearAnchors()
    FuryGMTRemoveDialogCancel:SetAnchor(TOPRIGHT, last, BOTTOMRIGHT, 0, 18)
    local height = 18 + FuryGMTRemoveDialogTitle:GetTextHeight() + 12 + FuryGMTRemoveDialogBody:GetTextHeight()
    if job.blacklist then
        height = height + 12 + FuryGMTRemoveDialogReasonLabel:GetTextHeight() + 4 + FuryGMTRemoveDialogReason:GetHeight()
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
    FuryGMTRemoveDialogTitle:SetText(title)
    FuryGMTRemoveDialogBody:SetText(body)
    FuryGMTRemoveDialogReasonBox:SetText(job.reason or "")
    SetMailButtonText()
    LayoutRemoveDialog()
    U.ShowOnTop(FuryGMTRemoveDialog)
end

function Actions.CloseRemoveDialog()
    SCENE_MANAGER:HideTopLevel(FuryGMTRemoveDialog)
end

function Actions.ToggleRemoveMail()
    if not removeJob then return end
    removeJob.sendMail = not removeJob.sendMail
    SetMailButtonText()
    GT.Report.ShowTip(FuryGMTRemoveDialogMail, MailTip())
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
