-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0009-transporte-correo-multiparte-rpqp.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.MailTransport = {}
local MailTransport = Addon.MailTransport

local LISTENER_SEND_SUCCESS = "RPQuest_Mail_SendSuccess"
local LISTENER_SEND_FAILED = "RPQuest_Mail_SendFailed"
local LISTENER_OPEN_MAILBOX = "RPQuest_Mail_OpenMailbox"
local LISTENER_CLOSE_MAILBOX = "RPQuest_Mail_CloseMailbox"
local LISTENER_INBOX_UPDATE = "RPQuest_Mail_InboxUpdate"
local LISTENER_MAIL_READABLE = "RPQuest_Mail_Readable"
local LISTENER_MAIL_REMOVED = "RPQuest_Mail_Removed"

local DEFAULT_MAX_BODY_CHARS = 700
local MAX_MAIL_PARTS = 6
local PART_HEADER_RESERVE = 16
local QUEST_SUBJECT_PREFIX = "[RPQuest] "
local COMPLETION_SUBJECT_PREFIX = "[RPQuest:Done] "
local REJECTION_SUBJECT_PREFIX = "[RPQuest:Rejected] "
local ACCEPTANCE_SUBJECT_PREFIX = "[RPQuest:Accepted] "
local MAILBOX_OPEN_TIMEOUT_MS = 10000
local MAIL_SEND_TIMEOUT_MS = 15000

function MailTransport:Initialize()
    self._listeners = self._listeners or {}
    self._sendQueue = {}
    self._isSending = false
    self._isMailboxOpen = false
    self._waitingForMailboxOpen = false
    self._currentSendItem = nil
    self._sendGen = self._sendGen or 0
    self._sendTotal = 0
    self._sendDone = 0
    self._sendSuccessCount = 0
    self._sendFailCount = 0
    self._openedMailbox = false
    if Addon.MailInbox and Addon.MailInbox.Initialize then
        Addon.MailInbox:Initialize()
    end
    self._receivedMails = Addon.MailInbox and Addon.MailInbox._receivedMails or {}
    self._receivedById = Addon.MailInbox and Addon.MailInbox._receivedById or {}
    self._partGroups = Addon.MailInbox and Addon.MailInbox._partGroups or {}
    self._dismissedMailIds = Addon.MailInbox and Addon.MailInbox._dismissedMailIds or {}
    self._reportedErrorMailIds = Addon.MailInbox and Addon.MailInbox._reportedErrorMailIds or {}
    self._notifiedMailIds = Addon.MailInbox and Addon.MailInbox._notifiedMailIds or {}
    self._txSeq = self._txSeq or 0

    if not self._eventsRegistered then
        EVENT_MANAGER:RegisterForEvent(LISTENER_OPEN_MAILBOX, EVENT_MAIL_OPEN_MAILBOX, function()
            self:OnMailboxOpened()
        end)
        EVENT_MANAGER:RegisterForEvent(LISTENER_CLOSE_MAILBOX, EVENT_MAIL_CLOSE_MAILBOX, function()
            self:OnMailboxClosed()
        end)
        EVENT_MANAGER:RegisterForEvent(LISTENER_SEND_SUCCESS, EVENT_MAIL_SEND_SUCCESS, function(_, playerName)
            self:OnMailSendSuccess(playerName)
        end)
        EVENT_MANAGER:RegisterForEvent(LISTENER_SEND_FAILED, EVENT_MAIL_SEND_FAILED, function(_, reason)
            self:OnMailSendFailed(reason)
        end)
        EVENT_MANAGER:RegisterForEvent(LISTENER_INBOX_UPDATE, EVENT_MAIL_INBOX_UPDATE, function()
            self:ScanInbox()
        end)
        EVENT_MANAGER:RegisterForEvent(LISTENER_MAIL_READABLE, EVENT_MAIL_READABLE, function(_, mailId)
            self:OnMailReadable(mailId)
        end)
        EVENT_MANAGER:RegisterForEvent(LISTENER_MAIL_REMOVED, EVENT_MAIL_REMOVED, function(_, mailId)
            self:OnMailRemoved(mailId)
        end)
        self._eventsRegistered = true
    end

    if not self._repoListenerAdded and Addon.QuestRepository and Addon.QuestRepository.RegisterListener then
        Addon.QuestRepository:RegisterListener(function(evType, payload)
            if evType == "QUEST_COMPLETED" and type(payload) == "table" then
                if Addon.QuestRepository:GetSetting("autoSendCompletionMail")
                    and payload.role == Addon.Constants.QUEST_ROLE.RECEIVED
                    and not payload.completionReported then
                    local sender = self:NormalizeDisplayName(payload.senderDisplayName)
                    if sender ~= "" then
                        local ok, errKey = self:SendCompletionReport(payload)
                        if not ok and errKey then
                            self:NotifySendError(sender, errKey)
                        end
                    end
                end
            elseif evType == "QUEST_REJECTED" and type(payload) == "table" then
                if payload.role == Addon.Constants.QUEST_ROLE.RECEIVED then
                    local sender = self:NormalizeDisplayName(payload.senderDisplayName)
                    if sender ~= "" then
                        local ok, errKey = self:SendRejectionReport(payload)
                        if not ok and errKey then
                            self:NotifySendError(sender, errKey)
                        end
                    end
                end
            elseif evType == "QUEST_ACCEPTED" and type(payload) == "table" then
                if payload.role == Addon.Constants.QUEST_ROLE.RECEIVED then
                    local sender = self:NormalizeDisplayName(payload.senderDisplayName)
                    if sender ~= "" then
                        local ok, errKey = self:SendAcceptanceReport(payload)
                        if not ok and errKey then
                            self:NotifySendError(sender, errKey)
                        end
                    end
                end
            end
        end)
        self._repoListenerAdded = true
    end

    self.isInitialized = true
end

function MailTransport:RegisterListener(fn)
    if type(fn) ~= "function" then return end
    self._listeners = self._listeners or {}
    table.insert(self._listeners, fn)
end

function MailTransport:NotifyListeners(eventType, payload)
    if not self._listeners then return end
    for _, fn in ipairs(self._listeners) do
        fn(eventType, payload)
    end
end

function MailTransport:GetMaxBodyLength()
    return (type(MAIL_MAX_BODY_CHARACTERS) == "number" and MAIL_MAX_BODY_CHARACTERS > 0)
        and MAIL_MAX_BODY_CHARACTERS
        or DEFAULT_MAX_BODY_CHARS
end

function MailTransport:GetMaxMailParts()
    return MAX_MAIL_PARTS
end

function MailTransport:GenerateTxId(seedText)
    self._txSeq = (self._txSeq or 0) + 1
    local hash = 0
    if Addon.ShareCodec and Addon.ShareCodec.ComputeCRC16 and type(seedText) == "string" then
        hash = Addon.ShareCodec:ComputeCRC16(seedText) or 0
    end
    local ts = GetTimeStamp() or 0
    local mixed = (hash + ts + self._txSeq * 7919) % 65536
    return string.format("%04X", mixed)
end

function MailTransport:ComposeQuestMailBody(roleMessage, questCode)
    local code = type(questCode) == "string" and questCode:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local msg = type(roleMessage) == "string" and roleMessage:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local body = (msg ~= "") and (msg .. "\n\n" .. code) or code
    local maxLen = self:GetMaxBodyLength()
    return body, #body, maxLen, (#body <= maxLen)
end

function MailTransport:BuildQuestMailPackets(roleMessage, questCode, title)
    local fullBody, len, maxLen, fitsSingle = self:ComposeQuestMailBody(roleMessage, questCode)
    local cleanTitle = (type(title) == "string" and title ~= "") and title or "RPQuest"

    if fitsSingle then
        return {
            packets = {
                {
                    subject = QUEST_SUBJECT_PREFIX .. cleanTitle,
                    body = fullBody,
                },
            },
            totalLen = len,
            maxLen = maxLen,
            partCount = 1,
            maxParts = MAX_MAIL_PARTS,
            maxTotalChars = maxLen,
            fits = true,
        }
    end

    local chunkSize = math.max(1, maxLen - PART_HEADER_RESERVE)
    local totalParts = math.ceil(len / chunkSize)
    local maxTotalChars = chunkSize * MAX_MAIL_PARTS

    if totalParts > MAX_MAIL_PARTS then
        return {
            packets = {},
            totalLen = len,
            maxLen = maxLen,
            partCount = totalParts,
            maxParts = MAX_MAIL_PARTS,
            maxTotalChars = maxTotalChars,
            fits = false,
        }
    end

    local txId = self:GenerateTxId(fullBody)
    local packets = {}
    for i = 1, totalParts do
        local startIdx = (i - 1) * chunkSize + 1
        local endIdx = math.min(len, i * chunkSize)
        local chunk = string.sub(fullBody, startIdx, endIdx)
        table.insert(packets, {
            subject = string.format("[RPQuest %d/%d] %s", i, totalParts, cleanTitle),
            body = string.format("RPQP:%s:%d/%d\n%s", txId, i, totalParts, chunk),
        })
    end

    return {
        packets = packets,
        totalLen = len,
        maxLen = maxLen,
        partCount = totalParts,
        maxParts = MAX_MAIL_PARTS,
        maxTotalChars = maxTotalChars,
        fits = true,
    }
end

function MailTransport:NormalizeDisplayName(rawName)
    return Addon.QuestRepository:NormalizeAccountName(rawName)
end

function MailTransport:IsSelfRecipient(recipient)
    local normRecipient = self:NormalizeDisplayName(recipient)
    if normRecipient == "" then
        return false
    end
    local selfName = self:NormalizeDisplayName(GetDisplayName())
    return selfName ~= "" and normRecipient:lower() == selfName:lower()
end

function MailTransport:ParseRecipients(rawInput)
    if type(rawInput) ~= "string" then
        return {}, "ERR_MAIL_NO_RECIPIENTS"
    end

    local first, firstKey
    for token in string.gmatch(rawInput, "[^,;\r\n]+") do
        local clean = self:NormalizeDisplayName(token)
        if clean ~= "" then
            local key = clean:lower()
            if not first then
                first = clean
                firstKey = key
            elseif key ~= firstKey then
                return {}, "ERR_MAIL_TOO_MANY_RECIPIENTS"
            end
        end
    end

    if not first then
        return {}, "ERR_MAIL_NO_RECIPIENTS"
    end
    return { first }, nil
end

function MailTransport:IsNativeMailboxOpen()
    return SCENE_MANAGER:IsShowing("mailInbox")
        or SCENE_MANAGER:IsShowing("mailSend")
        or false
end

function MailTransport:IsMailboxReady()
    return self._isMailboxOpen or self:IsNativeMailboxOpen()
end

function MailTransport:EnsureMailboxOpen(forceRequest)
    if forceRequest or not self:IsMailboxReady() then
        RequestOpenMailbox()
        self._openedMailbox = true
    end
end

function MailTransport:CloseMailboxIfOwned()
    if self._openedMailbox and not self._isSending and not self:IsNativeMailboxOpen() then
        CloseMailbox()
        self._openedMailbox = false
        self._isMailboxOpen = false
    end
end

function MailTransport:ScheduleSendTimeout(delayMs, gen, doneCount)
    zo_callLater(function()
        if not self._isSending then return end
        if self._sendGen ~= gen or self._sendDone ~= doneCount then return end
        if self._waitingForMailboxOpen then
            self:AbortSendQueue("MAILBOX_OPEN_TIMEOUT")
        else
            self:OnMailSendFailed("TIMEOUT")
        end
    end, delayMs)
end

function MailTransport:FormatSendFailureMessage(to, reason)
    local detail
    if reason == MAIL_SEND_RESULT_CANT_SEND_TO_SELF or reason == "ERR_MAIL_SELF_RECIPIENT" then
        detail = Addon.Locale:Get("ERR_MAIL_SELF_RECIPIENT")
    elseif reason == "MAILBOX_OPEN_TIMEOUT" then
        detail = Addon.Locale:Get("ERR_MAIL_MAILBOX_TIMEOUT")
    elseif reason == "MAILBOX_CLOSED" then
        detail = Addon.Locale:Get("ERR_MAIL_MAILBOX_CLOSED")
    elseif reason == "TIMEOUT" then
        detail = Addon.Locale:Get("ERR_MAIL_SEND_TIMEOUT")
    elseif type(reason) == "number" then
        local esoMsg = GetString("SI_SENDMAILRESULT", reason)
        detail = (type(esoMsg) == "string" and esoMsg ~= "") and esoMsg or ("Error " .. tostring(reason))
    elseif type(reason) == "string" and reason ~= "" then
        detail = Addon.Locale:Get(reason)
    else
        detail = Addon.Locale:Get("ERR_MAIL_API_UNAVAILABLE")
    end
    local target = (type(to) == "string" and to ~= "") and to or "?"
    return Addon.Locale:Get("ALERT_MAIL_SEND_FAILED", target, detail)
end

function MailTransport:NotifySendError(to, reason)
    if reason == MAIL_SEND_RESULT_CANCELED then
        return
    end
    local message = self:FormatSendFailureMessage(to, reason)
    if Addon.Announcements and Addon.Announcements.ShowAlert then
        Addon.Announcements:ShowAlert(message, true)
    end
    self:NotifyListeners("MAIL_SEND_ERROR", {
        to = to,
        reason = reason,
        message = message,
    })
end

function MailTransport:StartSendQueue(forceWaitForOpen)
    self._sendGen = (self._sendGen or 0) + 1
    if not forceWaitForOpen and self:IsMailboxReady() then
        self._waitingForMailboxOpen = false
        self:DispatchNextQueuedMail()
        return
    end
    self._waitingForMailboxOpen = true
    local firstItem = self._sendQueue[1]
    if firstItem then
        self._currentSendTarget = firstItem.to
        self:NotifyListeners("MAIL_SEND_PROGRESS", {
            current = self._sendDone + 1,
            total = self._sendTotal,
            to = firstItem.to,
        })
    end
    self:ScheduleSendTimeout(MAILBOX_OPEN_TIMEOUT_MS, self._sendGen, self._sendDone)
    self:EnsureMailboxOpen(forceWaitForOpen)
end

function MailTransport:OnMailboxOpened()
    self._isMailboxOpen = true
    if self._isSending and self._waitingForMailboxOpen then
        self._waitingForMailboxOpen = false
        self:DispatchNextQueuedMail()
    end
end

function MailTransport:OnMailboxClosed()
    self._isMailboxOpen = false
    self._openedMailbox = false
    if self._isSending then
        self:AbortSendQueue("MAILBOX_CLOSED")
    end
end

function MailTransport:AbortSendQueue(reason)
    if not self._isSending then return end
    local remaining = #self._sendQueue + (self._currentSendItem and 1 or 0)
    if remaining > 0 then
        self._sendFailCount = self._sendFailCount + remaining
        self._sendDone = self._sendDone + remaining
    end
    local target = (self._currentSendItem and self._currentSendItem.to) or self._currentSendTarget
    self._sendQueue = {}
    self._currentSendItem = nil
    self._currentSendTarget = nil
    self._waitingForMailboxOpen = false
    self._isSending = false
    self._sendGen = (self._sendGen or 0) + 1
    self:NotifySendError(target, reason)
    self:NotifyListeners("MAIL_SEND_COMPLETE", {
        total = self._sendTotal,
        sent = self._sendSuccessCount,
        failed = self._sendFailCount,
    })
end

function MailTransport:SendQuestToRecipients(quest, rawRecipients, roleMessage)
    if type(quest) ~= "table" then
        return false, "ERR_INVALID_CODE"
    end
    if self._isSending then
        return false, "ERR_MAIL_SEND_IN_PROGRESS"
    end
    if not Addon.QuestRepository:HasPlayableObjectives(quest) then
        return false, "ERR_MISSING_TARGET"
    end

    local recipients, recErr = self:ParseRecipients(rawRecipients)
    if recErr then
        return false, recErr
    end
    if self:IsSelfRecipient(recipients[1]) then
        return false, "ERR_MAIL_SELF_RECIPIENT"
    end

    if type(quest.senderCharacterName) ~= "string" or quest.senderCharacterName == "" then
        local playerChar = Addon.QuestRepository:GetPlayerCharacterName()
        if playerChar ~= "" then
            quest.senderCharacterName = playerChar
            if Addon.QuestRepository._shareCodeCache then
                Addon.QuestRepository._shareCodeCache[quest.id] = nil
            end
        end
    end

    local questCode, exportErr = Addon.QuestRepository:ExportQuestToCode(quest.id)
    if not questCode or questCode == "" then
        return false, exportErr or "ERR_INVALID_CODE"
    end

    local plan = self:BuildQuestMailPackets(roleMessage, questCode, quest.title)
    if not plan.fits then
        return false, "ERR_MAIL_BODY_TOO_LONG", plan.totalLen, plan.maxTotalChars
    end

    self._sendQueue = {}
    for _, to in ipairs(recipients) do
        local numPackets = #plan.packets
        for idx, pkt in ipairs(plan.packets) do
            table.insert(self._sendQueue, {
                to = to,
                subject = pkt.subject,
                body = pkt.body,
                sentQuestId = (idx == numPackets) and quest.id or nil,
            })
        end
    end

    self._isSending = true
    self._currentSendItem = nil
    self._sendTotal = #self._sendQueue
    self._sendDone = 0
    self._sendSuccessCount = 0
    self._sendFailCount = 0

    self:StartSendQueue()
    return true, nil, plan.totalLen, plan.maxTotalChars
end

function MailTransport:DispatchNextQueuedMail()
    if not self._isSending then return end

    local nextItem = table.remove(self._sendQueue, 1)
    if not nextItem then
        self._isSending = false
        self._currentSendItem = nil
        self._currentSendTarget = nil
        self._waitingForMailboxOpen = false
        local summary = {
            total = self._sendTotal,
            sent = self._sendSuccessCount,
            failed = self._sendFailCount,
        }
        self:CloseMailboxIfOwned()
        self:NotifyListeners("MAIL_SEND_COMPLETE", summary)
        return
    end

    self._currentSendItem = nextItem
    self._currentSendTarget = nextItem.to
    self:NotifyListeners("MAIL_SEND_PROGRESS", {
        current = self._sendDone + 1,
        total = self._sendTotal,
        to = nextItem.to,
    })
    self:ScheduleSendTimeout(MAIL_SEND_TIMEOUT_MS, self._sendGen, self._sendDone)
    SendMail(nextItem.to, nextItem.subject, nextItem.body)
end

function MailTransport:EnqueueResultMail(quest, subjectPrefix, code, resultType)
    local recipient = self:NormalizeDisplayName(quest.senderDisplayName)
    if recipient == "" then
        return false, "ERR_MAIL_NO_RECIPIENTS"
    end
    if self:IsSelfRecipient(recipient) then
        return false, "ERR_MAIL_SELF_RECIPIENT"
    end

    local kind = resultType
    if type(resultType) == "boolean" then
        kind = resultType and "rejected" or "completed"
    end

    local item = {
        to = recipient,
        subject = subjectPrefix .. (quest.title or "RPQuest"),
        body = code,
        completionQuestId = (kind == "completed") and quest.id or nil,
        rejectionQuestId = (kind == "rejected") and quest.id or nil,
        acceptanceQuestId = (kind == "accepted") and quest.id or nil,
    }

    if self._isSending then
        table.insert(self._sendQueue, item)
        self._sendTotal = self._sendTotal + 1
        return true
    end

    self._sendQueue = { item }
    self._isSending = true
    self._currentSendItem = nil
    self._sendTotal = 1
    self._sendDone = 0
    self._sendSuccessCount = 0
    self._sendFailCount = 0

    self:StartSendQueue()
    return true
end

function MailTransport:SendCompletionReport(quest)
    if type(quest) ~= "table" or not quest.completed then
        return false, "ERR_INVALID_CODE"
    end
    local rpqc1Code, err = Addon.QuestRepository:ExportCompletionCode(quest.id)
    if not rpqc1Code or rpqc1Code == "" then
        return false, err or "ERR_INVALID_CODE"
    end
    return self:EnqueueResultMail(quest, COMPLETION_SUBJECT_PREFIX, rpqc1Code, "completed")
end

function MailTransport:SendRejectionReport(quest)
    if type(quest) ~= "table" then
        return false, "ERR_INVALID_CODE"
    end
    local rpqc1Code, err = Addon.QuestRepository:ExportRejectionCode(quest)
    if not rpqc1Code or rpqc1Code == "" then
        return false, err or "ERR_INVALID_CODE"
    end
    return self:EnqueueResultMail(quest, REJECTION_SUBJECT_PREFIX, rpqc1Code, "rejected")
end

function MailTransport:SendAcceptanceReport(quest)
    if type(quest) ~= "table" then
        return false, "ERR_INVALID_CODE"
    end
    local rpqc1Code, err = Addon.QuestRepository:ExportAcceptanceCode(quest)
    if not rpqc1Code or rpqc1Code == "" then
        return false, err or "ERR_INVALID_CODE"
    end
    return self:EnqueueResultMail(quest, ACCEPTANCE_SUBJECT_PREFIX, rpqc1Code, "accepted")
end

function MailTransport:OnMailSendSuccess(_playerName)
    if not self._isSending then return end
    if self._currentSendItem and self._currentSendItem.completionQuestId then
        Addon.QuestRepository:MarkCompletionReported(self._currentSendItem.completionQuestId)
        self:NotifyListeners("MAIL_COMPLETION_SENT", {
            questId = self._currentSendItem.completionQuestId,
            to = self._currentSendItem.to,
        })
    elseif self._currentSendItem and self._currentSendItem.sentQuestId then
        Addon.QuestRepository:MarkPreparedQuestSent(self._currentSendItem.sentQuestId, self._currentSendItem.to)
    end
    self._currentSendItem = nil
    self._sendDone = self._sendDone + 1
    self._sendSuccessCount = self._sendSuccessCount + 1
    self:DispatchNextQueuedMail()
end

function MailTransport:OnMailSendFailed(reason)
    if not self._isSending then return end
    if reason == MAIL_SEND_RESULT_MAILBOX_NOT_OPEN and self._currentSendItem and not self._currentSendItem._retriedMailbox then
        self._currentSendItem._retriedMailbox = true
        table.insert(self._sendQueue, 1, self._currentSendItem)
        self._currentSendItem = nil
        self._isMailboxOpen = false
        self:StartSendQueue(true)
        return
    end
    local target = (self._currentSendItem and self._currentSendItem.to) or self._currentSendTarget
    self._currentSendItem = nil
    self._sendDone = self._sendDone + 1
    self._sendFailCount = self._sendFailCount + 1
    self:NotifySendError(target, reason)
    self:DispatchNextQueuedMail()
end

function MailTransport:ParseQuestMailBody(body)
    return Addon.MailInbox:ParseQuestMailBody(body)
end

function MailTransport:IsQuestMailSubject(subject)
    return Addon.MailInbox:IsQuestMailSubject(subject)
end

function MailTransport:ParseQuestPartMailBody(body)
    return Addon.MailInbox:ParseQuestPartMailBody(body)
end

function MailTransport:IsCompletionMailSubject(subject)
    return Addon.MailInbox:IsCompletionMailSubject(subject)
end

function MailTransport:ParseCompletionMailBody(body)
    return Addon.MailInbox:ParseCompletionMailBody(body)
end

function MailTransport:ProcessCompletionMail(mailId, senderDisplayName, subject, body)
    return Addon.MailInbox:ProcessCompletionMail(mailId, senderDisplayName, subject, body)
end

function MailTransport:IngestReceivedMail(mailId)
    return Addon.MailInbox:IngestReceivedMail(mailId)
end

function MailTransport:ScanInbox(requestOpen)
    return Addon.MailInbox:ScanInbox(requestOpen)
end

function MailTransport:OnMailReadable(mailId)
    return Addon.MailInbox:OnMailReadable(mailId)
end

function MailTransport:OnMailRemoved(mailId)
    return Addon.MailInbox:OnMailRemoved(mailId)
end

function MailTransport:GetReceivedMailCount()
    return Addon.MailInbox:GetReceivedMailCount()
end
