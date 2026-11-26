-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0009-transporte-correo-multiparte-rpqp.md
-- Ref: docs/adr/0011-flujo-solo-correo-1-a-1-y-eliminacion-codigos-manuales.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.MailInbox = {}
local MailInbox = Addon.MailInbox

local MAX_MAIL_PARTS = 6
local QUEST_SUBJECT_PREFIX = "[RPQuest] "
local COMPLETION_SUBJECT_PREFIX = "[RPQuest:Done] "
local REJECTION_SUBJECT_PREFIX = "[RPQuest:Rejected] "
local ACCEPTANCE_SUBJECT_PREFIX = "[RPQuest:Accepted] "
local FAILURE_SUBJECT_PREFIX = "[RPQuest:Failed] "

function MailInbox:Initialize()
    self._receivedMails = {}
    self._receivedById = {}
    self._partGroups = {}
    self._dismissedMailIds = {}
    self._reportedErrorMailIds = {}
    self._notifiedMailIds = {}
    self.isInitialized = true
end

function MailInbox:ParseQuestMailBody(body)
    if type(body) ~= "string" or body == "" then
        return nil, ""
    end

    local sIdx, _, code = string.find(body, "(RPQ%d+:[^%s]+)")
    if not code then
        return nil, ""
    end

    local before = (sIdx > 1) and string.sub(body, 1, sIdx - 1) or ""
    local roleMessage = before:gsub("^%s+", ""):gsub("%s+$", "")
    return code, roleMessage
end

function MailInbox:IsQuestMailSubject(subject)
    if type(subject) ~= "string" then return false end
    if string.sub(subject, 1, #COMPLETION_SUBJECT_PREFIX) == COMPLETION_SUBJECT_PREFIX then
        return false
    end
    if string.sub(subject, 1, #QUEST_SUBJECT_PREFIX) == QUEST_SUBJECT_PREFIX then
        return true
    end
    return string.match(subject, "^%[RPQuest %d+/%d+%] ") ~= nil
end

function MailInbox:ParseQuestPartMailBody(body)
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

function MailInbox:IsCompletionMailSubject(subject)
    if type(subject) ~= "string" then return false end
    return string.sub(subject, 1, #COMPLETION_SUBJECT_PREFIX) == COMPLETION_SUBJECT_PREFIX
        or string.sub(subject, 1, #REJECTION_SUBJECT_PREFIX) == REJECTION_SUBJECT_PREFIX
        or string.sub(subject, 1, #ACCEPTANCE_SUBJECT_PREFIX) == ACCEPTANCE_SUBJECT_PREFIX
        or string.sub(subject, 1, #FAILURE_SUBJECT_PREFIX) == FAILURE_SUBJECT_PREFIX
end

function MailInbox:ParseCompletionMailBody(body)
    if type(body) ~= "string" or body == "" then
        return nil
    end
    local _, _, code = string.find(body, "(RPQC1:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]:[^%s]+)")
    return code
end

function MailInbox:ProcessCompletionMail(mailId, senderDisplayName, _subject, body)
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
        local ok, res = Addon.QuestRepository:ValidateResultCode(q.id, rpqc1Code)
        if ok and type(res) == "table" then
            local _, isNew = Addon.QuestRepository:RecordMailDelivery(q.id, senderDisplayName, res)
            if isNew and Addon.Announcements and Addon.Announcements.ShowAlert then
                local who = (type(senderDisplayName) == "string" and senderDisplayName ~= "")
                    and senderDisplayName
                    or (res.characterName or "")
                local alertKey = "ALERT_MAIL_DELIVERY_VALIDATED"
                if res.resultType == "accepted" or res.accepted then
                    alertKey = "ALERT_MAIL_ACCEPTANCE_RECEIVED"
                elseif res.resultType == "failed" or res.failed then
                    alertKey = "ALERT_MAIL_FAILURE_RECEIVED"
                elseif res.resultType == "rejected" or res.rejected or res.completed == false then
                    alertKey = "ALERT_MAIL_REJECTION_RECEIVED"
                end
                Addon.Announcements:ShowAlert(Addon.Locale:Get(alertKey, who, q.title or ""), false)
            end
            if Addon.QuestRepository:GetSetting("autoDeleteMail") then
                DeleteMail(mailId)
            else
                self._dismissedMailIds[idKey] = true
            end
            return true
        end
    end
    return false
end

function MailInbox:IngestReceivedMail(mailId)
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

    local autoAccept = Addon.QuestRepository and Addon.QuestRepository:GetSetting("autoAcceptMail")
    local targetStatus = autoAccept and Addon.Constants.QUEST_STATUS.ACTIVE or Addon.Constants.QUEST_STATUS.OFFERED
    local imported, err, isDuplicate = Addon.QuestRepository:ImportQuestFromCode(entry.questCode, entry.senderDisplayName, {
        status = targetStatus,
        sourceMailId = entry.idKey,
        senderCharacterName = entry.senderCharacterName,
    })
    if not imported and not isDuplicate then
        table.insert(self._receivedMails, entry)
        self:RebuildReceivedIndex()
        return nil, err
    end

    self:DisposeEntryMails(entry)
    return imported, nil, entry, isDuplicate
end

function MailInbox:UpsertReceivedEntry(entry)
    local existingIdx = self._receivedById[entry.idKey]
    if existingIdx then
        self._receivedMails[existingIdx] = entry
    else
        table.insert(self._receivedMails, entry)
        self._receivedById[entry.idKey] = #self._receivedMails
    end

    if not entry.isIncomplete then
        self._notifiedMailIds = self._notifiedMailIds or {}
        if not self._notifiedMailIds[entry.idKey] then
            self._notifiedMailIds[entry.idKey] = true
            local imported, _, _, isDuplicate = self:IngestReceivedMail(entry.idKey)
            if imported and not isDuplicate and Addon.Announcements then
                if Addon.QuestRepository:GetSetting("autoAcceptMail") then
                    Addon.QuestRepository:NotifyListeners("QUEST_ACCEPTED", imported)
                    if Addon.Announcements.AnnounceQuestAccepted then
                        Addon.Announcements:AnnounceQuestAccepted(imported)
                    end
                else
                    if Addon.Announcements.AnnounceQuestReceived then
                        Addon.Announcements:AnnounceQuestReceived(imported)
                    end
                    if Addon.Announcements.ShowAlert then
                        local who = (type(entry.senderDisplayName) == "string" and entry.senderDisplayName ~= "")
                            and entry.senderDisplayName
                            or entry.senderCharacterName or ""
                        Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_MAIL_QUEST_OFFERED", imported.title or entry.title or "", who), false)
                    end
                end
            end
        end
    end
end

function MailInbox:GetOrCreatePartGroup(mailId, idKey, txId, part, total, chunk, senderDisplayName, senderCharacterName, subject, secsSinceReceived)
    local normSender = Addon.QuestRepository:NormalizeAccountName(senderDisplayName)
    self._partGroups = self._partGroups or {}
    local groupKey = string.format("part:%s:%s:%d", normSender:lower(), txId, total)
    local group = self._partGroups[groupKey]
    if not group then
        group = {
            groupKey = groupKey,
            txId = txId,
            total = total,
            senderDisplayName = normSender,
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
    return groupKey, group
end

function MailInbox:CountReceivedParts(group)
    local receivedCount = 0
    local allMailIds = {}
    for i = 1, group.total do
        if group.parts[i] ~= nil then
            receivedCount = receivedCount + 1
        end
        if group.mailIds[i] ~= nil then
            table.insert(allMailIds, group.mailIds[i])
        end
    end
    return receivedCount, allMailIds
end

function MailInbox:FinalizeCompletePartGroup(groupKey, group, allMailIds)
    local fullBody = table.concat(group.parts, "", 1, group.total)
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
        partsReceived = group.total,
        partsTotal = group.total,
        secsSinceReceived = group.secsSinceReceived,
    })
    return true
end

function MailInbox:UpsertPartMail(mailId, idKey, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
    local txId, part, total, chunk = self:ParseQuestPartMailBody(body)
    if not txId then
        return nil
    end

    local groupKey, group = self:GetOrCreatePartGroup(
        mailId, idKey, txId, part, total, chunk,
        senderDisplayName, senderCharacterName, subject, secsSinceReceived
    )
    local receivedCount, allMailIds = self:CountReceivedParts(group)

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

    return self:FinalizeCompletePartGroup(groupKey, group, allMailIds)
end

function MailInbox:UpsertReceivedMail(mailId, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
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
        senderDisplayName = Addon.QuestRepository:NormalizeAccountName(senderDisplayName),
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

function MailInbox:RebuildReceivedIndex()
    self._receivedById = {}
    for idx, entry in ipairs(self._receivedMails) do
        self._receivedById[entry.idKey] = idx
    end
end

function MailInbox:ReportDecodeError(errorKey, errKey, senderDisplayName)
    if not errKey then return end
    self._reportedErrorMailIds = self._reportedErrorMailIds or {}
    local key = tostring(errorKey)
    if self._reportedErrorMailIds[key] then return end
    self._reportedErrorMailIds[key] = true

    local msg = Addon.Locale:Get(errKey)
    if Addon.Announcements and Addon.Announcements.ShowAlert then
        Addon.Announcements:ShowAlert(msg, true)
    end
    if Addon.Announcements and Addon.Announcements.AnnounceMailDecodeError then
        Addon.Announcements:AnnounceMailDecodeError(msg, senderDisplayName)
    end
    if Addon.MailTransport and Addon.MailTransport.NotifyListeners then
        Addon.MailTransport:NotifyListeners("MAIL_DECODE_ERROR", {
            mailId = errorKey,
            errKey = errKey,
            message = msg,
            senderDisplayName = senderDisplayName,
        })
    end
end

function MailInbox:ProcessMailItem(mailId, senderDisplayName, senderCharacterName, subject, secsSinceReceived, allowRequestRead)
    local isQuest = self:IsQuestMailSubject(subject)
    local isCompletion = (not isQuest) and self:IsCompletionMailSubject(subject)
    if not (isQuest or isCompletion) then return end

    local body = ReadMail(mailId) or ""
    if type(body) == "string" and body ~= "" then
        if isQuest then
            local ok, errKey, errorKey = self:UpsertReceivedMail(mailId, senderDisplayName, senderCharacterName, subject, body, secsSinceReceived)
            if not ok and errKey then
                self:ReportDecodeError(errorKey or mailId, errKey, senderDisplayName)
                self:CleanupFailedQuestMail(mailId, errorKey)
            end
        else
            self:ProcessCompletionMail(mailId, senderDisplayName, subject, body)
        end
    elseif allowRequestRead then
        RequestReadMail(mailId)
    end
end

function MailInbox:ScanInbox(requestOpen)
    if requestOpen and Addon.MailTransport and Addon.MailTransport.EnsureMailboxOpen then
        Addon.MailTransport:EnsureMailboxOpen()
    end

    local mailId = GetNextMailId(nil)
    while mailId ~= nil do
        local nextMailId = GetNextMailId(mailId)
        local senderDisplayName, senderCharacterName, subject, _, _, _, _, _, _, _, _, _, secsSinceReceived = GetMailItemInfo(mailId)
        self:ProcessMailItem(mailId, senderDisplayName, senderCharacterName, subject, secsSinceReceived, true)
        mailId = nextMailId
    end

    return self._receivedMails
end

function MailInbox:OnMailReadable(mailId)
    if not mailId then return end
    local senderDisplayName, senderCharacterName, subject, _, _, _, _, _, _, _, _, _, secsSinceReceived = GetMailItemInfo(mailId)
    self:ProcessMailItem(mailId, senderDisplayName, senderCharacterName, subject, secsSinceReceived, false)
end

function MailInbox:OnMailRemoved(mailId)
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
        return
    end

    if self._partGroups then
        self:RemovePartFromGroup(idKey)
    end
end

function MailInbox:RemovePartFromGroup(idKey)
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
            return
        end
    end
end

function MailInbox:GetReceivedMailCount()
    return #(self._receivedMails or {})
end

function MailInbox:RemoveEntryById(mailId)
    local idKey = tostring(mailId)
    local idx = self._receivedById and self._receivedById[idKey]
    if not idx then return nil end
    local entry = table.remove(self._receivedMails, idx)
    self:RebuildReceivedIndex()
    return entry
end

function MailInbox:DisposeMailIds(ids)
    local shouldDelete = Addon.QuestRepository:GetSetting("autoDeleteMail")
    for _, mid in ipairs(ids) do
        if shouldDelete then
            DeleteMail(mid)
        else
            self._dismissedMailIds[tostring(mid)] = true
        end
    end
end

function MailInbox:CleanupFailedQuestMail(mailId, errorKey)
    local group = errorKey and self._partGroups and self._partGroups[errorKey]
    if group then
        local ids = {}
        for _, mid in pairs(group.mailIds or {}) do
            table.insert(ids, mid)
        end
        self:DisposeMailIds(ids)
        self._partGroups[errorKey] = nil
        self:RemoveEntryById(errorKey)
        return
    end
    self:DisposeMailIds({ mailId })
end

function MailInbox:DisposeEntryMails(entry)
    local ids = (type(entry.mailIds) == "table" and #entry.mailIds > 0) and entry.mailIds or { entry.mailId }
    self:DisposeMailIds(ids)
    if self._partGroups and entry.idKey then
        self._partGroups[entry.idKey] = nil
    end
end
