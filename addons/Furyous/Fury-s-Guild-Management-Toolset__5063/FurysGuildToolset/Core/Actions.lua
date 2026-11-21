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
--   server confirms with EVENT_MAIL_SEND_SUCCESS.
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
    if MAIL_SEND.to then MAIL_SEND.to:SetText(displayName) end
    if MAIL_SEND.subject then MAIL_SEND.subject:SetText(subject) end
    if MAIL_SEND.body then MAIL_SEND.body:SetText(body) end
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

function Actions.Kick(guildId, displayName, alsoBlacklist, note, onDone)
    if not NeedMember(guildId, displayName) then return end
    if not Need(guildId, GUILD_PERMISSION_REMOVE, "remove members") then return end
    if alsoBlacklist and not Need(guildId, GUILD_PERMISSION_MANAGE_BLACKLIST, "manage the blacklist") then return end
    local body = alsoBlacklist
        and zo_strformat("Remove <<1>> from <<2>> and add them to the guild blacklist?", displayName, U.GuildName(guildId))
        or zo_strformat("Remove <<1>> from <<2>>?", displayName, U.GuildName(guildId))
    Actions.Confirm(alsoBlacklist and "Kick and blacklist" or "Kick member", body, function()
        GuildRemove(guildId, displayName)
        U.Print("Removed %s from %s.", displayName, U.GuildName(guildId))
        if alsoBlacklist then Actions.Blacklist(guildId, displayName, note) end
        if onDone then onDone() end
    end)
end
