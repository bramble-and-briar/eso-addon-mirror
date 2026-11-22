-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0009-transporte-correo-multiparte-rpqp.md
-- Ref: docs/adr/0010-comparticion-grupo-y-objetivos-compartidos.md

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

local MAX_RECIPIENTS = 4
local DEFAULT_MAX_BODY_CHARS = 700
local MAX_MAIL_PARTS = 6
local PART_HEADER_RESERVE = 16
local QUEST_SUBJECT_PREFIX = "[RPQuest] "
local COMPLETION_SUBJECT_PREFIX = "[RPQuest:Done] "
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
    self._receivedMails = {}
    self._receivedById = {}
    self._partGroups = {}
    self._dismissedMailIds = {}
    self._reportedErrorMailIds = {}
    self._notifiedMailIds = {}
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
                    and type(payload.senderDisplayName) == "string"
                    and payload.senderDisplayName ~= ""
                    and not payload.completionReported then
                    self:SendCompletionReport(payload)
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
    local ts = GetTimeStamp and GetTimeStamp() or 0
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

function MailTransport:ParseRecipients(rawInput)
    if type(rawInput) ~= "string" then
        return {}, "ERR_MAIL_NO_RECIPIENTS"
    end

    local recipients = {}
    local seen = {}
    for token in string.gmatch(rawInput, "[^,;\r\n]+") do
        local clean = token:gsub("^%s+", ""):gsub("%s+$", "")
        if clean ~= "" then
            if clean:sub(1, 1) ~= "@" then
                clean = "@" .. clean
            end
            local key = clean:lower()
            if not seen[key] then
                seen[key] = true
                table.insert(recipients, clean)
            end
        end
    end

    if #recipients == 0 then
        return {}, "ERR_MAIL_NO_RECIPIENTS"
    end
    if #recipients > MAX_RECIPIENTS then
        return {}, "ERR_MAIL_TOO_MANY_RECIPIENTS"
    end
    return recipients, nil
end

function MailTransport:IsNativeMailboxOpen()
    if not SCENE_MANAGER or not SCENE_MANAGER.IsShowing then
        return false
    end
    return SCENE_MANAGER:IsShowing("mailInbox")
        or SCENE_MANAGER:IsShowing("mailSend")
        or false
end

function MailTransport:IsMailboxReady()
    return self._isMailboxOpen or self:IsNativeMailboxOpen()
end

function MailTransport:EnsureMailboxOpen()
    if not self:IsMailboxReady() and RequestOpenMailbox then
        RequestOpenMailbox()
        self._openedMailbox = true
    end
end

function MailTransport:CloseMailboxIfOwned()
    if self._openedMailbox and not self._isSending and not self:IsNativeMailboxOpen() and CloseMailbox then
        CloseMailbox()
        self._openedMailbox = false
        self._isMailboxOpen = false
    end
end

function MailTransport:ScheduleSendTimeout(delayMs, gen, doneCount)
    if not zo_callLater then return end
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

function MailTransport:StartSendQueue()
    self._sendGen = (self._sendGen or 0) + 1
    if self:IsMailboxReady() then
        self._waitingForMailboxOpen = false
        self:DispatchNextQueuedMail()
        return
    end
    self._waitingForMailboxOpen = true
    local firstItem = self._sendQueue[1]
    if firstItem then
        self:NotifyListeners("MAIL_SEND_PROGRESS", {
            current = 1,
            total = self._sendTotal,
            to = firstItem.to,
        })
    end
    self:EnsureMailboxOpen()
    self:ScheduleSendTimeout(MAILBOX_OPEN_TIMEOUT_MS, self._sendGen, self._sendDone)
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
    self._sendQueue = {}
    self._currentSendItem = nil
    self._waitingForMailboxOpen = false
    self._isSending = false
    self._sendGen = (self._sendGen or 0) + 1
    self:NotifyListeners("MAIL_SEND_ERROR", {
        to = self._currentSendTarget,
        reason = reason,
    })
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

    local recipients, recErr = self:ParseRecipients(rawRecipients)
    if recErr then
        return false, recErr
    end

    local questCode = Addon.QuestRepository:ExportQuestToCode(quest.id)
    if not questCode or questCode == "" then
        return false, "ERR_INVALID_CODE"
    end

    local plan = self:BuildQuestMailPackets(roleMessage, questCode, quest.title)
    if not plan.fits then
        return false, "ERR_MAIL_BODY_TOO_LONG", plan.totalLen, plan.maxTotalChars
    end

    if not SendMail or (not self:IsMailboxReady() and not RequestOpenMailbox) then
        return false, "ERR_MAIL_API_UNAVAILABLE"
    end

    self._sendQueue = {}
    for _, to in ipairs(recipients) do
        for _, pkt in ipairs(plan.packets) do
            table.insert(self._sendQueue, {
                to = to,
                subject = pkt.subject,
                body = pkt.body,
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

function MailTransport:SendCompletionReport(quest)
    if type(quest) ~= "table" or not quest.completed then
        return false, "ERR_INVALID_CODE"
    end
    local recipient = type(quest.senderDisplayName) == "string"
        and quest.senderDisplayName:gsub("^%s+", ""):gsub("%s+$", "")
        or ""
    if recipient == "" then
        return false, "ERR_MAIL_NO_RECIPIENTS"
    end
    if not SendMail or (not self:IsMailboxReady() and not RequestOpenMailbox) then
        return false, "ERR_MAIL_API_UNAVAILABLE"
    end

    local rpqc1Code, err = Addon.QuestRepository:ExportCompletionCode(quest.id)
    if not rpqc1Code or rpqc1Code == "" then
        return false, err or "ERR_INVALID_CODE"
    end

    local subject = COMPLETION_SUBJECT_PREFIX .. (quest.title or "RPQuest")
    local item = {
        to = recipient,
        subject = subject,
        body = rpqc1Code,
        completionQuestId = quest.id,
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

function MailTransport:OnMailSendSuccess(playerName)
    if not self._isSending then return end
    if self._currentSendItem and self._currentSendItem.completionQuestId then
        Addon.QuestRepository:MarkCompletionReported(self._currentSendItem.completionQuestId)
        self:NotifyListeners("MAIL_COMPLETION_SENT", {
            questId = self._currentSendItem.completionQuestId,
            to = self._currentSendItem.to,
        })
    end
    self._currentSendItem = nil
    self._sendDone = self._sendDone + 1
    self._sendSuccessCount = self._sendSuccessCount + 1
    self:DispatchNextQueuedMail()
end

function MailTransport:OnMailSendFailed(reason)
    if not self._isSending then return end
    self._currentSendItem = nil
    self._sendDone = self._sendDone + 1
    self._sendFailCount = self._sendFailCount + 1
    self:NotifyListeners("MAIL_SEND_ERROR", {
        to = self._currentSendTarget,
        reason = reason,
    })
    self:DispatchNextQueuedMail()
end

function MailTransport:ParseQuestMailBody(body)
    if type(body) ~= "string" or body == "" then
        return nil, ""
    end

    local sIdx, eIdx, code = string.find(body, "(RPQ%d+:[^%s]+)")
    if not code then
        return nil, ""
    end

    local before = (sIdx > 1) and string.sub(body, 1, sIdx - 1) or ""
    local roleMessage = before:gsub("^%s+", ""):gsub("%s+$", "")
    return code, roleMessage
end

function MailTransport:IsQuestMailSubject(subject)
    if type(subject) ~= "string" then return false end
    if string.sub(subject, 1, #COMPLETION_SUBJECT_PREFIX) == COMPLETION_SUBJECT_PREFIX then
        return false
    end
    if string.sub(subject, 1, #QUEST_SUBJECT_PREFIX) == QUEST_SUBJECT_PREFIX then
        return true
    end
    return string.match(subject, "^%[RPQuest %d+/%d+%] ") ~= nil
end

function MailTransport:ParseQuestPartMailBody(body)
    if type(body) ~= "string" or body == "" then
        return nil
    end
    local txId, partStr, totalStr, chunk = string.match(body, "^RPQP:([0-9A-Fa-f]+):(%d+)/(%d+)\n(.*)$")
    if not txId then
        return nil
    end
    local part = tonumber(partStr)
    local total = tonumber(totalStr)
    if not part or not total or part < 1 or total < 2 or part > total or total > (MAX_MAIL_PARTS * 2) then
        return nil
    end
    return txId:upper(), part, total, chunk
end

function MailTransport:IsCompletionMailSubject(subject)
    if type(subject) ~= "string" then return false end
    return string.sub(subject, 1, #COMPLETION_SUBJECT_PREFIX) == COMPLETION_SUBJECT_PREFIX
end

function MailTransport:ParseCompletionMailBody(body)
    if type(body) ~= "string" or body == "" then
        return nil
    end
    local _, _, code = string.find(body, "(RPQC1:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]:[^%s]+)")
    return code
end

function MailTransport:ProcessCompletionMail(mailId, senderDisplayName, subject, body)
    local idKey = tostring(mailId)
    if self._dismissedMailIds and self._dismissedMailIds[idKey] then
        return false
    end

    local rpqc1Code = self:ParseCompletionMailBody(body)
    if not rpqc1Code then
        return false
    end

    local preparedQuests = Addon.QuestRepository:GetQuestsByRole(Addon.Constants.QUEST_ROLE.PREPARED)
    for _, q in ipairs(preparedQuests) do
        local ok, res = Addon.QuestRepository:ValidateCompletionCode(q.id, rpqc1Code)
        if ok and type(res) == "table" then
            local _, isNew = Addon.QuestRepository:RecordMailDelivery(q.id, senderDisplayName, res)
            if isNew and Addon.Announcements and Addon.Announcements.ShowAlert then
                local who = (type(senderDisplayName) == "string" and senderDisplayName ~= "")
                    and senderDisplayName
                    or (res.characterName or "")
                Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_MAIL_DELIVERY_VALIDATED", who, q.title or ""), false)
            end
            if Addon.QuestRepository:GetSetting("autoDeleteMail") and DeleteMail then
                DeleteMail(mailId)
            else
                self._dismissedMailIds[idKey] = true
            end
            return true
        end
    end
    return false
end

function MailTransport:UpsertReceivedEntry(entry)
    local existingIdx = self._receivedById[entry.idKey]
    if existingIdx then
        self._receivedMails[existingIdx] = entry
    else
        table.insert(self._receivedMails, entry)
        self._receivedById[entry.idKey] = #self._receivedMails
    end
    self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)

    if not entry.isIncomplete then
        self._notifiedMailIds = self._notifiedMailIds or {}
        if not self._notifiedMailIds[entry.idKey] then
            self._notifiedMailIds[entry.idKey] = true
            if Addon.QuestRepository and Addon.QuestRepository:GetSetting("autoAcceptMail") then
                local imported = self:AcceptReceivedMail(entry.idKey)
                if imported and Addon.Announcements and Addon.Announcements.AnnounceQuestAccepted then
                    Addon.Announcements:AnnounceQuestAccepted(imported)
                end
            elseif Addon.Announcements and Addon.Announcements.ShowAlert then
                local who = (type(entry.senderDisplayName) == "string" and entry.senderDisplayName ~= "")
                    and entry.senderDisplayName
                    or entry.senderCharacterName or ""
                Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_MAIL_QUEST_RECEIVED", entry.title or "", who), false)
            end
        end
    end
end

function MailTransport:UpsertPartMail(mailId, idKey, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
    local txId, part, total, chunk = self:ParseQuestPartMailBody(body)
    if not txId then
        return nil
    end

    self._partGroups = self._partGroups or {}
    local groupKey = string.format("part:%s:%s:%d", (senderDisplayName or ""):lower(), txId, total)
    local group = self._partGroups[groupKey]
    if not group then
        group = {
            groupKey = groupKey,
            txId = txId,
            total = total,
            senderDisplayName = senderDisplayName or "",
            senderCharacterName = senderCharacterName or "",
            subject = subject or "",
            parts = {},
            mailIds = {},
            mailIdByKey = {},
            secsSinceReceived = secsSinceReceived or 0,
        }
        self._partGroups[groupKey] = group
    end

    group.parts[part] = chunk
    group.mailIds[part] = mailId
    group.mailIdByKey[idKey] = part
    if type(secsSinceReceived) == "number" then
        group.secsSinceReceived = math.min(group.secsSinceReceived, secsSinceReceived)
    end

    local receivedCount = 0
    local allMailIds = {}
    for i = 1, total do
        if group.parts[i] ~= nil then
            receivedCount = receivedCount + 1
        end
        if group.mailIds[i] ~= nil then
            table.insert(allMailIds, group.mailIds[i])
        end
    end

    if receivedCount < total then
        local cleanTitle = (subject or ""):gsub("^%[RPQuest %d+/%d+%]%s*", "")
        self:UpsertReceivedEntry({
            mailId = groupKey,
            idKey = groupKey,
            mailIds = allMailIds,
            senderDisplayName = group.senderDisplayName,
            senderCharacterName = group.senderCharacterName,
            subject = group.subject,
            title = cleanTitle,
            roleMessage = "",
            isIncomplete = true,
            partsReceived = receivedCount,
            partsTotal = total,
            secsSinceReceived = group.secsSinceReceived,
        })
        return true
    end

    local fullBody = table.concat(group.parts, "", 1, total)
    local code, roleMessage = self:ParseQuestMailBody(fullBody)
    if not code then
        return false, "ERR_IMPORT_INVALID_FORMAT", groupKey
    end

    local decoded, errKey = Addon.ShareCodec:DecodeQuest(code)
    if not decoded then
        return false, errKey, groupKey
    end

    self:UpsertReceivedEntry({
        mailId = groupKey,
        idKey = groupKey,
        mailIds = allMailIds,
        senderDisplayName = group.senderDisplayName,
        senderCharacterName = group.senderCharacterName,
        subject = group.subject,
        title = decoded.title or "",
        roleMessage = roleMessage,
        questCode = code,
        decodedQuest = decoded,
        isIncomplete = false,
        partsReceived = total,
        partsTotal = total,
        secsSinceReceived = group.secsSinceReceived,
    })
    return true
end

function MailTransport:UpsertReceivedMail(mailId, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
    local idKey = tostring(mailId)
    if self._dismissedMailIds and self._dismissedMailIds[idKey] then
        return false
    end

    local partResult, partErr, partErrorKey = self:UpsertPartMail(mailId, idKey, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
    if partResult ~= nil then
        return partResult, partErr, partErrorKey
    end

    local code, roleMessage = self:ParseQuestMailBody(body)
    if not code then
        return false, "ERR_IMPORT_INVALID_FORMAT", idKey
    end

    local decoded, errKey = Addon.ShareCodec:DecodeQuest(code)
    if not decoded then
        return false, errKey, idKey
    end

    self:UpsertReceivedEntry({
        mailId = mailId,
        idKey = idKey,
        mailIds = { mailId },
        senderDisplayName = senderDisplayName or "",
        senderCharacterName = senderCharacterName or "",
        subject = subject or "",
        title = decoded.title or "",
        roleMessage = roleMessage,
        questCode = code,
        decodedQuest = decoded,
        isIncomplete = false,
        partsReceived = 1,
        partsTotal = 1,
        secsSinceReceived = secsSinceReceived or 0,
    })
    return true
end

function MailTransport:RebuildReceivedIndex()
    self._receivedById = {}
    for idx, entry in ipairs(self._receivedMails) do
        self._receivedById[entry.idKey] = idx
    end
end

function MailTransport:ReportDecodeError(errorKey, errKey, senderDisplayName)
    if not errKey then return end
    self._reportedErrorMailIds = self._reportedErrorMailIds or {}
    local key = tostring(errorKey)
    if self._reportedErrorMailIds[key] then return end
    self._reportedErrorMailIds[key] = true

    local msg = Addon.Locale:Get(errKey)
    if Addon.Announcements and Addon.Announcements.ShowAlert then
        Addon.Announcements:ShowAlert(msg, true)
    end
    self:NotifyListeners("MAIL_DECODE_ERROR", {
        mailId = errorKey,
        errKey = errKey,
        message = msg,
        senderDisplayName = senderDisplayName,
    })
end

function MailTransport:ProcessMailItem(mailId, senderDisplayName, senderCharacterName, subject, secsSinceReceived, allowRequestRead)
    local isQuest = self:IsQuestMailSubject(subject)
    local isCompletion = (not isQuest) and self:IsCompletionMailSubject(subject)
    if not (isQuest or isCompletion) then return end

    local body = ReadMail and ReadMail(mailId) or ""
    if type(body) == "string" and body ~= "" then
        if isQuest then
            local ok, errKey, errorKey = self:UpsertReceivedMail(mailId, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
            if not ok and errKey then
                self:ReportDecodeError(errorKey or mailId, errKey, senderDisplayName)
            end
        else
            self:ProcessCompletionMail(mailId, senderDisplayName, subject, body)
        end
    elseif allowRequestRead and RequestReadMail then
        RequestReadMail(mailId)
    end
end

function MailTransport:ScanInbox(requestOpen)
    if requestOpen then
        self:EnsureMailboxOpen()
    end
    if not GetNextMailId or not GetMailItemInfo then
        return self._receivedMails
    end

    local mailId = GetNextMailId(nil)
    while mailId ~= nil do
        local senderDisplayName, senderCharacterName, subject, _, _, _, _, _, _, _, _, _, secsSinceReceived = GetMailItemInfo(mailId)
        self:ProcessMailItem(mailId, senderDisplayName, senderCharacterName, subject, secsSinceReceived, true)
        mailId = GetNextMailId(mailId)
    end

    return self._receivedMails
end

function MailTransport:OnMailReadable(mailId)
    if not mailId or not GetMailItemInfo or not ReadMail then return end
    local senderDisplayName, senderCharacterName, subject, _, _, _, _, _, _, _, _, _, secsSinceReceived = GetMailItemInfo(mailId)
    self:ProcessMailItem(mailId, senderDisplayName, senderCharacterName, subject, secsSinceReceived, false)
end

function MailTransport:OnMailRemoved(mailId)
    if not mailId then return end
    local idKey = tostring(mailId)
    if self._reportedErrorMailIds then
        self._reportedErrorMailIds[idKey] = nil
    end
    if self._notifiedMailIds then
        self._notifiedMailIds[idKey] = nil
    end
    local idx = self._receivedById and self._receivedById[idKey]
    if idx then
        table.remove(self._receivedMails, idx)
        self:RebuildReceivedIndex()
        self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)
        return
    end

    if self._partGroups then
        for groupKey, group in pairs(self._partGroups) do
            local part = group.mailIdByKey and group.mailIdByKey[idKey]
            if part then
                group.parts[part] = nil
                group.mailIds[part] = nil
                group.mailIdByKey[idKey] = nil
                local remaining = 0
                for i = 1, group.total do
                    if group.parts[i] ~= nil then
                        remaining = remaining + 1
                    end
                end
                if remaining == 0 then
                    self._partGroups[groupKey] = nil
                    if self._reportedErrorMailIds then
                        self._reportedErrorMailIds[groupKey] = nil
                    end
                    if self._notifiedMailIds then
                        self._notifiedMailIds[groupKey] = nil
                    end
                    self:RemoveEntryById(groupKey)
                else
                    local existingIdx = self._receivedById and self._receivedById[groupKey]
                    if existingIdx and self._receivedMails[existingIdx] then
                        local e = self._receivedMails[existingIdx]
                        e.isIncomplete = true
                        e.partsReceived = remaining
                        e.questCode = nil
                        e.decodedQuest = nil
                    end
                end
                self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)
                return
            end
        end
    end
end

function MailTransport:GetReceivedMails()
    return self._receivedMails or {}
end

function MailTransport:GetReceivedMailCount()
    return #(self._receivedMails or {})
end

function MailTransport:RemoveEntryById(mailId)
    local idKey = tostring(mailId)
    local idx = self._receivedById and self._receivedById[idKey]
    if not idx then return nil end
    local entry = table.remove(self._receivedMails, idx)
    self:RebuildReceivedIndex()
    return entry
end

function MailTransport:DisposeEntryMails(entry)
    local ids = (type(entry.mailIds) == "table" and #entry.mailIds > 0) and entry.mailIds or { entry.mailId }
    local shouldDelete = Addon.QuestRepository:GetSetting("autoDeleteMail") and DeleteMail
    for _, mid in ipairs(ids) do
        if shouldDelete then
            DeleteMail(mid)
        else
            self._dismissedMailIds[tostring(mid)] = true
        end
    end
    if self._partGroups and entry.idKey then
        self._partGroups[entry.idKey] = nil
    end
end

function MailTransport:AcceptReceivedMail(mailId)
    local idKey = tostring(mailId)
    local idx = self._receivedById and self._receivedById[idKey]
    local existing = idx and self._receivedMails[idx]
    if existing and existing.isIncomplete then
        return nil, "ERR_MAIL_INCOMPLETE"
    end

    local entry = self:RemoveEntryById(mailId)
    if not entry then
        return nil, "ERR_INVALID_CODE"
    end

    local imported, err = Addon.QuestRepository:ImportQuestFromCode(entry.questCode, entry.senderDisplayName)
    if not imported then
        table.insert(self._receivedMails, entry)
        self:RebuildReceivedIndex()
        return nil, err
    end

    self:DisposeEntryMails(entry)
    self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)
    return imported, nil, entry
end

function MailTransport:RejectReceivedMail(mailId)
    local entry = self:RemoveEntryById(mailId)
    if not entry then
        return false
    end

    self:DisposeEntryMails(entry)
    self:NotifyListeners("MAIL_INBOX_UPDATED", self._receivedMails)
    return true
end

function MailTransport:GetGroupMemberDisplayNames()
    local names = {}
    if not IsUnitGrouped or not IsUnitGrouped("player") or not GetGroupSize or not GetGroupUnitTagByIndex or not GetUnitDisplayName then
        return names
    end
    local seen = {}
    local playerName = GetDisplayName and GetDisplayName() or nil
    local groupSize = GetGroupSize() or 0
    for i = 1, groupSize do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag and unitTag ~= "player" and not (AreUnitsEqual and AreUnitsEqual(unitTag, "player")) then
            local displayName = GetUnitDisplayName(unitTag)
            if type(displayName) == "string" and displayName ~= "" and displayName ~= playerName then
                local key = displayName:lower()
                if not seen[key] then
                    seen[key] = true
                    table.insert(names, displayName)
                end
            end
        end
    end
    return names
end

function MailTransport:ShareQuestWithGroup(quest)
    if type(quest) ~= "table" then
        return false, "ERR_INVALID_CODE", 0
    end
    local members = self:GetGroupMemberDisplayNames()
    if #members == 0 then
        return false, "ERR_SHARE_NO_GROUP_MEMBERS", 0
    end
    local rawRecipients = table.concat(members, ", ")
    local ok, errKey = self:SendQuestToRecipients(quest, rawRecipients, "")
    return ok, errKey, #members
end
