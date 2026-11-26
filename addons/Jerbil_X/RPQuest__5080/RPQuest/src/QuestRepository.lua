-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0013-protocolo-versionado-de-esquema-y-migraciones-de-misiones.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0012-savedvars-account-wide-y-migracion-por-personaje.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestRepository = {}
local QuestRepository = Addon.QuestRepository

function QuestRepository:NormalizeName(name)
    if type(name) ~= "string" or name == "" then return "" end
    local clean = zo_strformat("<<C:1>>", (name:gsub("%^%a+$", "")))
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

function QuestRepository:NormalizeAccountName(raw)
    if type(raw) ~= "string" then return "" end
    local clean = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" then return "" end
    if clean:sub(1, 1) ~= "@" then
        clean = "@" .. clean
    end
    return clean
end

function QuestRepository:NormalizeCharacterName(raw)
    if type(raw) ~= "string" then return "" end
    local clean = raw:gsub("%^%a+$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

function QuestRepository:GetPlayerCharacterName()
    return self:NormalizeCharacterName(GetUnitName("player"))
end

function QuestRepository:FormatTargetEntry(target)
    if type(target) ~= "table" or not target.name or target.name == "" then
        return ""
    end
    local req = math.max(1, math.floor(tonumber(target.requiredCount) or 1))
    if req > 1 then
        return string.format("%s x%d", target.name, req)
    end
    return target.name
end

function QuestRepository:FormatTargetsSummary(targets)
    if type(targets) ~= "table" or #targets == 0 then
        return ""
    end
    local parts = {}
    for _, t in ipairs(targets) do
        local formatted = self:FormatTargetEntry(t)
        if formatted ~= "" then
            table.insert(parts, formatted)
        end
    end
    return table.concat(parts, ", ")
end

local function AreAllTargetsCompleted(targets)
    if type(targets) ~= "table" or #targets == 0 then
        return false
    end
    for _, t in ipairs(targets) do
        if (t.currentCount or 0) < (t.requiredCount or 1) then
            return false
        end
    end
    return true
end

local function HasOptionalTargets(targets)
    if type(targets) ~= "table" then
        return false
    end
    for _, t in ipairs(targets) do
        if t.optional == true then
            return true
        end
    end
    return false
end

local function AreMandatoryTargetsCompleted(targets)
    if type(targets) ~= "table" then
        return true, false, false
    end
    local hasMandatory = false
    local anyOptionalDone = false
    for _, t in ipairs(targets) do
        local done = (t.currentCount or 0) >= (t.requiredCount or 1)
        if t.optional == true then
            if done then
                anyOptionalDone = true
            end
        else
            hasMandatory = true
            if not done then
                return false, true, anyOptionalDone
            end
        end
    end
    return true, hasMandatory, anyOptionalDone
end

local function AreAllDiscoveriesCompleted(discoveries)
    if type(discoveries) ~= "table" or #discoveries == 0 then
        return false
    end
    for _, d in ipairs(discoveries) do
        if not d.discovered then
            return false
        end
    end
    return true
end

function QuestRepository:AreAllObjectivesCompleted(targets, discoveries)
    local hasTargets = type(targets) == "table" and #targets > 0
    local hasDiscoveries = type(discoveries) == "table" and #discoveries > 0
    if not hasTargets and not hasDiscoveries then
        return false
    end
    if hasTargets and not AreAllTargetsCompleted(targets) then
        return false
    end
    if hasDiscoveries and not AreAllDiscoveriesCompleted(discoveries) then
        return false
    end
    return true
end

function QuestRepository:CanManuallyCompleteQuest(quest)
    if not quest or quest.completed or quest.failed or self:IsOfferedQuest(quest) then
        return false
    end
    if not HasOptionalTargets(quest.targets) then
        return false
    end
    if self:AreAllObjectivesCompleted(quest.targets, quest.discoveries) then
        return false
    end
    local hasDiscoveries = type(quest.discoveries) == "table" and #quest.discoveries > 0
    if hasDiscoveries and not AreAllDiscoveriesCompleted(quest.discoveries) then
        return false
    end
    local mandatoryDone, hasMandatory, anyOptionalDone = AreMandatoryTargetsCompleted(quest.targets)
    if not mandatoryDone then
        return false
    end
    if not hasMandatory and not hasDiscoveries and not anyOptionalDone then
        return false
    end
    return true
end

local VALID_LIFECYCLE = {
    draft = true,
    sent = true,
    received = true,
}

local VALID_RESOLUTION = {
    accepted = true,
    rejected = true,
    completed = true,
    failed = true,
}

local function FinalizeCompletedQuest(self, quest)
    quest.completed = true
    if self:GetQuestLifecycle(quest) == Addon.Constants.QUEST_LIFECYCLE.RECEIVED then
        quest.resolution = Addon.Constants.QUEST_RESOLUTION.COMPLETED
    end
    if self.savedVars.activeQuestId == quest.id then
        self.savedVars.activeQuestId = nil
    end
    self:InvalidateActiveTargetCache()
end

local function FinalizeFailedQuest(self, quest)
    quest.failed = true
    if self:GetQuestLifecycle(quest) == Addon.Constants.QUEST_LIFECYCLE.RECEIVED then
        quest.resolution = Addon.Constants.QUEST_RESOLUTION.FAILED
    end
    if self.savedVars and self.savedVars.activeQuestId == quest.id then
        self.savedVars.activeQuestId = nil
    end
    self:InvalidateActiveTargetCache()
    self:NotifyListeners("QUEST_FAILED", quest)
end

function QuestRepository:CompleteQuest(questId)
    local quest = self:GetQuestById(questId)
    if not self:CanManuallyCompleteQuest(quest) then
        return false, nil
    end
    FinalizeCompletedQuest(self, quest)
    self:NotifyListeners("QUEST_COMPLETED", quest)
    return true, quest
end

local function ResolveRecommendHideMapAreas(data)
    if type(data) ~= "table" then
        return true
    end
    if data.recommendHideMapAreas ~= nil then
        return data.recommendHideMapAreas == true
    end
    if data.hideMapArea ~= nil then
        return data.hideMapArea == true
    end
    return true
end

function QuestRepository:BuildQuestRecord(id, title, description, targets, data, role)
    local schemaVersion = (Addon.QuestMigration and Addon.QuestMigration:GetCurrentSchemaVersion()) or 1
    local roles = Addon.Constants.QUEST_ROLE
    local statuses = Addon.Constants.QUEST_STATUS
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    local resolutions = Addon.Constants.QUEST_RESOLUTION

    local resolvedRole = role or roles.RECEIVED
    local lifecycle
    local resolution

    if resolvedRole == roles.PREPARED or data.lifecycle == lifecycles.DRAFT or data.lifecycle == lifecycles.SENT then
        resolvedRole = roles.PREPARED
        local hasSent = data.lifecycle == lifecycles.SENT
            or (type(data.sentTo) == "string" and data.sentTo ~= "")
            or type(data.lastResult) == "table"
            or (type(data.deliveries) == "table" and #data.deliveries > 0)
        if hasSent then
            lifecycle = lifecycles.SENT
            resolution = VALID_RESOLUTION[data.resolution] and data.resolution or nil
        else
            lifecycle = lifecycles.DRAFT
            resolution = nil
        end
    else
        resolvedRole = roles.RECEIVED
        lifecycle = lifecycles.RECEIVED
        if data.status == statuses.OFFERED then
            resolution = nil
        elseif VALID_RESOLUTION[data.resolution] then
            resolution = data.resolution
        elseif data.failed == true then
            resolution = resolutions.FAILED
        elseif data.completed == true then
            resolution = resolutions.COMPLETED
        else
            resolution = resolutions.ACCEPTED
        end
    end

    return {
        id = id,
        schemaVersion = schemaVersion,
        title = title,
        description = description,
        clue = type(data.clue) == "string" and data.clue or "",
        completionMessage = data.completionMessage or "",
        targets = targets,
        discoveries = data.discoveries or {},
        dialogues = Addon.QuestDraftStore:CloneDialoguesList(data.dialogues, data.clue),
        completed = false,
        role = resolvedRole,
        lifecycle = lifecycle,
        resolution = resolution,
        mapId = data.mapId or 0,
        zoneId = data.zoneId or 0,
        mapName = data.mapName or "",
        targetX = data.targetX,
        targetY = data.targetY,
        worldX = data.worldX,
        worldY = data.worldY,
        worldZ = data.worldZ,
        recommendHideMapAreas = ResolveRecommendHideMapAreas(data),
        stealthMode = Addon.QuestDraftStore:NormalizeStealthMode(data.stealthMode, data.requireUndetected),
        icon = Addon.QuestDraftStore:NormalizeQuestIcon(data.icon),
        wasDetected = false,
        failed = false,
        senderDisplayName = type(data.senderDisplayName) == "string" and data.senderDisplayName or nil,
        senderCharacterName = (type(data.senderCharacterName) == "string" and data.senderCharacterName ~= "") and data.senderCharacterName or nil,
        recipientAccount = self:NormalizeAccountName(data.recipientAccount),
        recipientCharacterName = (type(data.recipientCharacterName) == "string" and data.recipientCharacterName ~= "") and data.recipientCharacterName or nil,
        sentTo = type(data.sentTo) == "string" and data.sentTo or nil,
        sentAt = data.sentAt,
        lastResult = type(data.lastResult) == "table" and data.lastResult or nil,
        status = data.status,
        sourceMailId = data.sourceMailId,
        completionReported = (data.completionReported == true),
        failureReported = (data.failureReported == true),
        deliveries = type(data.deliveries) == "table" and data.deliveries or {},
    }
end

function QuestRepository:GetDefaults()
    return {
        nextId = 1,
        activeQuestId = nil,
        quests = {},
        ingestedMailIds = {},
        migratedCharacterIds = {},
        draft = Addon.QuestDraftStore:CreateDefaultDraft(),
        settings = {
            autoDeleteMail = true,
            autoAcceptMail = false,
            autoSendCompletionMail = true,
            showSearchAreas = false,
            showLocationAreas = false,
            showDiscoveryAreas = false,
        },
        uiState = {
            lastSectionKey = nil,
            lastSelectedQuestId = nil,
        },
    }
end

function QuestRepository:MigrateCharacterSavedVars(rawRoot, displayName, savedVars, currentCharId)
    return Addon.QuestMigration:MigrateCharacterSavedVars(rawRoot, displayName, savedVars, currentCharId)
end

function QuestRepository:Initialize(savedVars)
    self.savedVars = savedVars or self:GetDefaults()
    self.savedVars.nextId = self.savedVars.nextId or 1
    self.savedVars.quests = self.savedVars.quests or {}
    self.savedVars.ingestedMailIds = self.savedVars.ingestedMailIds or {}
    if type(self.savedVars.settings) ~= "table" then
        self.savedVars.settings = {}
    end
    local defaultSettings = {
        autoDeleteMail = true,
        autoAcceptMail = false,
        autoSendCompletionMail = true,
        showSearchAreas = false,
        showLocationAreas = false,
        showDiscoveryAreas = false,
    }
    for k, v in pairs(defaultSettings) do
        if self.savedVars.settings[k] == nil then
            self.savedVars.settings[k] = v
        end
    end
    self.savedVars.draft = Addon.QuestDraftStore:EnsureDraft(self.savedVars.draft)
    self._questById = {}
    self._shareCodeCache = {}
    self._completionCodeCache = {}
    self._activeTargetCache = nil
    local roles = Addon.Constants.QUEST_ROLE
    if Addon.QuestMigration then
        Addon.QuestMigration:MigrateQuestList(self.savedVars.quests)
    end
    for _, q in ipairs(self.savedVars.quests) do
        q.targets = q.targets or {}
        if q.role ~= roles.PREPARED and q.role ~= roles.RECEIVED then
            q.role = roles.RECEIVED
        end
        if q.id then
            self._questById[q.id] = q
        end
    end
    if self.savedVars.activeQuestId then
        local active = self._questById[self.savedVars.activeQuestId]
        if not active or active.needsMigration then
            self.savedVars.activeQuestId = nil
        end
    end
    if type(self.savedVars.uiState) ~= "table" then
        self.savedVars.uiState = {}
    end
    if self.savedVars.uiState.lastSectionKey ~= nil and type(self.savedVars.uiState.lastSectionKey) ~= "string" then
        self.savedVars.uiState.lastSectionKey = nil
    end
    if self.savedVars.uiState.lastSelectedQuestId and not self._questById[self.savedVars.uiState.lastSelectedQuestId] then
        self.savedVars.uiState.lastSelectedQuestId = nil
    end
    self._listeners = self._listeners or {}
end

function QuestRepository:InvalidateActiveTargetCache()
    self._activeTargetCache = nil
end

function QuestRepository:RegisterListener(callback)
    self._listeners = self._listeners or {}
    table.insert(self._listeners, callback)
end

function QuestRepository:NotifyListeners(eventType, quest)
    if not self._listeners then return end
    for _, cb in ipairs(self._listeners) do
        cb(eventType, quest)
    end
end

function QuestRepository:ComputeOffsetCenter(targetX, targetY, radius, randomAngle01, randomDist01)
    return Addon.WorldMapArea:ComputeOffsetCenter(targetX, targetY, radius, randomAngle01, randomDist01)
end

local DRAFT_DELEGATES = {
    "GetDraft", "ResetDraft", "ClearDraftTargets", "AddDraftDiscoveryPoint",
    "ClearDraftDiscoveries", "UpdateDraftDiscoveryPoint", "RemoveDraftDiscoveryPoint",
    "AddDraftDialogue", "AddDraftDialogueFromLastNpc", "UpdateDraftDialogue",
    "RemoveDraftDialogue", "ClearDraftDialogues", "LoadQuestIntoDraft",
    "UpdateDraftFields", "SetDraftCapturedTarget", "SaveDraft",
    "CreateNewPreparedDraft", "CommitDraftChanges",
    "UpdateDraftTarget", "RemoveDraftTarget", "CaptureDraftTargetLocation", "ClearDraftTargetLocation",
}

for _, methodName in ipairs(DRAFT_DELEGATES) do
    QuestRepository[methodName] = function(self, ...)
        return Addon.QuestDraftStore[methodName](Addon.QuestDraftStore, self, ...)
    end
end

function QuestRepository:SetLastInteractedNpc(npcName, zoneId)
    local cleanName = self:NormalizeName(npcName)
    if cleanName == "" then
        return nil
    end
    self._lastInteractedNpc = {
        name = cleanName,
        zoneId = math.floor(tonumber(zoneId) or 0),
    }
    self:NotifyListeners("LAST_NPC_UPDATED", self._lastInteractedNpc)
    return self._lastInteractedNpc
end

function QuestRepository:GetLastInteractedNpc()
    return self._lastInteractedNpc
end

function QuestRepository:IsOfferedQuest(quest)
    if type(quest) ~= "table" then
        return false
    end
    return self:GetQuestLifecycle(quest) == Addon.Constants.QUEST_LIFECYCLE.RECEIVED
        and self:GetQuestResolution(quest) == nil
end

function QuestRepository:HasIngestedMail(mailKey)
    if type(mailKey) ~= "string" or mailKey == "" then
        return false
    end
    if self.savedVars and self.savedVars.ingestedMailIds and self.savedVars.ingestedMailIds[mailKey] then
        return true
    end
    for _, q in ipairs((self.savedVars and self.savedVars.quests) or {}) do
        if q.sourceMailId == mailKey then
            return true
        end
    end
    return false
end

function QuestRepository:FindAlreadyIngestedQuest(sourceMailId)
    if type(sourceMailId) ~= "string" or sourceMailId == "" then
        return false, nil
    end
    if not self:HasIngestedMail(sourceMailId) then
        return false, nil
    end
    for _, q in ipairs((self.savedVars and self.savedVars.quests) or {}) do
        if q.sourceMailId == sourceMailId then
            return true, q
        end
    end
    return true, nil
end

function QuestRepository:NormalizeImportedTargets(rawTargets, targetX, targetY)
    local importedTargets = {}
    local defaultRad = Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    for _, t in ipairs(rawTargets or {}) do
        local cleanTName = self:NormalizeName(t.name)
        if cleanTName ~= "" then
            local hasLoc = (t.worldX ~= nil and t.worldZ ~= nil)
            local tAreaRad = tonumber(t.areaRadius)
            table.insert(importedTargets, {
                name = cleanTName,
                currentCount = 0,
                requiredCount = math.max(1, math.floor(tonumber(t.requiredCount) or 1)),
                targetX = targetX,
                targetY = targetY,
                areaCenterX = tonumber(t.areaCenterX),
                areaCenterY = tonumber(t.areaCenterY),
                areaRadius = (tAreaRad and tAreaRad > 0) and tAreaRad or nil,
                zoneId = hasLoc and math.floor(tonumber(t.zoneId) or 0) or nil,
                worldX = hasLoc and tonumber(t.worldX) or nil,
                worldZ = hasLoc and tonumber(t.worldZ) or nil,
                radius = hasLoc and math.max(100, math.floor(tonumber(t.radius) or defaultRad)) or nil,
                locationRequired = (t.locationRequired == true),
                optional = (t.optional == true),
                customMessage = type(t.customMessage) == "string" and t.customMessage or "",
                customMessageInLocation = type(t.customMessageInLocation) == "string" and t.customMessageInLocation or "",
            })
        end
    end
    return importedTargets
end

function QuestRepository:ApplyImportedSenderMetadata(decoded, senderDisplayName, options)
    local cleanSender = self:NormalizeAccountName(senderDisplayName)
    if cleanSender ~= "" then
        decoded.senderDisplayName = cleanSender
    end
    local cleanSenderChar = self:NormalizeCharacterName(options.senderCharacterName)
    if cleanSenderChar ~= "" then
        decoded.senderCharacterName = cleanSenderChar
    elseif type(decoded.senderCharacterName) == "string" then
        decoded.senderCharacterName = self:NormalizeCharacterName(decoded.senderCharacterName)
    end
    if type(decoded.recipientCharacterName) == "string" then
        decoded.recipientCharacterName = self:NormalizeCharacterName(decoded.recipientCharacterName)
    end
    decoded.status = options.status or Addon.Constants.QUEST_STATUS.ACTIVE
    decoded.lifecycle = Addon.Constants.QUEST_LIFECYCLE.RECEIVED
    decoded.role = Addon.Constants.QUEST_ROLE.RECEIVED
    decoded.resolution = (decoded.status == Addon.Constants.QUEST_STATUS.OFFERED)
        and nil
        or Addon.Constants.QUEST_RESOLUTION.ACCEPTED
    decoded.sourceMailId = options.sourceMailId
end

function QuestRepository:FinalizeImportedQuest(importedQuest, options)
    table.insert(self.savedVars.quests, importedQuest)
    if self._questById then
        self._questById[importedQuest.id] = importedQuest
    end
    if type(options.sourceMailId) == "string" and options.sourceMailId ~= "" then
        self.savedVars.ingestedMailIds = self.savedVars.ingestedMailIds or {}
        self.savedVars.ingestedMailIds[options.sourceMailId] = true
    end

    if importedQuest.status == Addon.Constants.QUEST_STATUS.OFFERED then
        self:NotifyListeners("QUEST_OFFERED", importedQuest)
    else
        if options.setActive ~= false then
            self.savedVars.activeQuestId = importedQuest.id
            self:InvalidateActiveTargetCache()
        end
        self:NotifyListeners("QUEST_IMPORTED", importedQuest)
    end
end

function QuestRepository:ImportQuestFromCode(codeString, senderDisplayName, options)
    options = type(options) == "table" and options or {}
    local alreadyIngested, existingQuest = self:FindAlreadyIngestedQuest(options.sourceMailId)
    if alreadyIngested then
        return existingQuest, nil, true
    end

    local decoded, errKey = Addon.ShareCodec:DecodeQuest(codeString)
    if not decoded then
        return nil, Addon.Locale:Get(type(errKey) == "string" and errKey or "ERR_INVALID_CODE")
    end

    local newId = self.savedVars.nextId
    self.savedVars.nextId = newId + 1

    local cleanTitle = (decoded.title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanTitle == "" then
        cleanTitle = Addon.Locale:Get("DEFAULT_QUEST_TITLE", newId)
    end

    local importedTargets = self:NormalizeImportedTargets(decoded.targets, decoded.targetX, decoded.targetY)
    decoded.discoveries = Addon.QuestDraftStore:CloneDiscoveriesList(decoded.discoveries, false)
    decoded.dialogues = Addon.QuestDraftStore:CloneDialoguesList(decoded.dialogues, decoded.clue)
    self:ApplyImportedSenderMetadata(decoded, senderDisplayName, options)

    local importedQuest = self:BuildQuestRecord(
        newId,
        cleanTitle,
        decoded.description or "",
        importedTargets,
        decoded,
        Addon.Constants.QUEST_ROLE.RECEIVED
    )

    self:FinalizeImportedQuest(importedQuest, options)
    return importedQuest, nil, false
end

function QuestRepository:AcceptOfferedQuest(questId)
    local q = self:GetQuestById(questId)
    if not q or not self:IsOfferedQuest(q) then
        return false, nil
    end
    q.status = Addon.Constants.QUEST_STATUS.ACTIVE
    q.resolution = Addon.Constants.QUEST_RESOLUTION.ACCEPTED
    self:SetActiveQuest(q.id)
    self:NotifyListeners("QUEST_ACCEPTED", q)
    return true, q
end

function QuestRepository:RejectOfferedQuest(questId)
    local q = self:GetQuestById(questId)
    if not q or not self:IsOfferedQuest(q) then
        return false, nil
    end
    q.resolution = Addon.Constants.QUEST_RESOLUTION.REJECTED
    self:DeleteQuest(q.id)
    self:NotifyListeners("QUEST_REJECTED", q)
    return true, q
end

function QuestRepository:ExportQuestToCode(questId)
    local quest = self:GetQuestById(questId)
    if not quest then
        return nil
    end
    if self:IsPreparedQuest(quest) and (type(quest.senderCharacterName) ~= "string" or quest.senderCharacterName == "") then
        local playerChar = self:GetPlayerCharacterName()
        if playerChar ~= "" then
            quest.senderCharacterName = playerChar
        end
    end
    self._shareCodeCache = self._shareCodeCache or {}
    local cached = self._shareCodeCache[questId]
    if cached then
        return cached
    end
    local code, err = Addon.ShareCodec:EncodeQuest(quest)
    if code then
        self._shareCodeCache[questId] = code
    end
    return code, err
end

local function GetPlayerExportContext()
    local rawName = GetUnitName("player") or ""
    local charName = rawName ~= "" and zo_strformat("<<C:1>>", rawName) or rawName
    return charName, GetTimeStamp() or 0
end

function QuestRepository:ExportCompletionCode(questId)
    local quest = self:GetQuestById(questId)
    if not quest or not quest.completed then
        return nil, "Quest is not completed"
    end

    self._completionCodeCache = self._completionCodeCache or {}
    local cached = self._completionCodeCache[questId]
    if cached then
        return cached
    end

    local charName, ts = GetPlayerExportContext()
    local code, err = Addon.ShareCodec:EncodeCompletion(quest, charName, ts)
    if code then
        self._completionCodeCache[questId] = code
    end
    return code, err
end

function QuestRepository:ExportRejectionCode(quest)
    if type(quest) ~= "table" then
        return nil, "Invalid quest"
    end
    local charName, ts = GetPlayerExportContext()
    return Addon.ShareCodec:EncodeRejection(quest, charName, ts)
end

function QuestRepository:ExportAcceptanceCode(quest)
    if type(quest) ~= "table" then
        return nil, "Invalid quest"
    end
    local charName, ts = GetPlayerExportContext()
    return Addon.ShareCodec:EncodeAcceptance(quest, charName, ts)
end

function QuestRepository:ExportFailureCode(questOrId)
    local quest = type(questOrId) == "table" and questOrId or self:GetQuestById(questOrId)
    if type(quest) ~= "table" or not quest.failed then
        return nil, "Quest has not failed"
    end
    local charName, ts = GetPlayerExportContext()
    return Addon.ShareCodec:EncodeFailure(quest, charName, ts)
end

function QuestRepository:ValidateResultCode(questId, codeString)
    local quest = self:GetQuestById(questId)
    if not quest then
        return false, "VALIDATE_ERR_INVALID_CODE"
    end
    return Addon.ShareCodec:ValidateResultForQuest(quest, codeString)
end

function QuestRepository:RecordMailDelivery(questId, senderDisplayName, validationResult)
    local quest = self:GetQuestById(questId)
    if not quest or type(validationResult) ~= "table" then
        return nil
    end
    quest.deliveries = quest.deliveries or {}
    local status
    if validationResult.resultType == "accepted" or validationResult.accepted == true then
        status = "accepted"
    elseif validationResult.resultType == "failed" or validationResult.failed == true then
        status = "failed"
    elseif validationResult.resultType == "rejected" or validationResult.rejected == true or validationResult.completed == false then
        status = "rejected"
    else
        status = "completed"
    end
    local entry = {
        senderDisplayName = type(senderDisplayName) == "string" and senderDisplayName or "",
        characterName = validationResult.characterName or "",
        completedAt = tonumber(validationResult.completedAt) or 0,
        wasDetected = validationResult.wasDetected,
        optionalTargets = validationResult.optionalTargets,
        status = status,
    }
    -- Avoid duplicate entries for same characterName + completedAt + status
    for _, existing in ipairs(quest.deliveries) do
        if existing.characterName == entry.characterName
            and existing.completedAt == entry.completedAt
            and (existing.status or "completed") == status then
            return existing, false
        end
    end
    table.insert(quest.deliveries, entry)
    if self:IsPreparedQuest(quest) then
        quest.lifecycle = Addon.Constants.QUEST_LIFECYCLE.SENT
    end
    local prevResolution = quest.resolution or (type(quest.lastResult) == "table" and (quest.lastResult.status or "completed") or nil)
    local isTerminal = (prevResolution == "completed" or prevResolution == "rejected" or prevResolution == "failed")
    if not (status == "accepted" and isTerminal) then
        quest.lastResult = entry
        quest.resolution = status
    end
    self:NotifyListeners("DELIVERY_RECORDED", { quest = quest, delivery = entry })
    return entry, true
end

function QuestRepository:MarkPreparedQuestSent(questId, recipient)
    local quest = self:GetQuestById(questId)
    if not quest then return false end
    local cleanRecipient = self:NormalizeAccountName(recipient)
    if cleanRecipient == "" then return false end
    quest.lifecycle = Addon.Constants.QUEST_LIFECYCLE.SENT
    quest.role = Addon.Constants.QUEST_ROLE.PREPARED
    quest.sentTo = cleanRecipient
    if (quest.recipientAccount or "") == "" then
        quest.recipientAccount = cleanRecipient
    end
    quest.sentAt = GetTimeStamp()
    self:NotifyListeners("QUEST_SENT", quest)
    return true
end

function QuestRepository:GetQuestLifecycle(quest)
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    if type(quest) ~= "table" then
        return lifecycles.DRAFT
    end
    if VALID_LIFECYCLE[quest.lifecycle] then
        return quest.lifecycle
    end
    if quest.role == Addon.Constants.QUEST_ROLE.PREPARED then
        local hasSent = (type(quest.sentTo) == "string" and quest.sentTo ~= "")
            or type(quest.lastResult) == "table"
            or (type(quest.deliveries) == "table" and #quest.deliveries > 0)
        return hasSent and lifecycles.SENT or lifecycles.DRAFT
    end
    return lifecycles.RECEIVED
end

function QuestRepository:GetQuestResolution(quest)
    if type(quest) ~= "table" then
        return nil, nil
    end
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    local lifecycle = self:GetQuestLifecycle(quest)
    if lifecycle == lifecycles.DRAFT then
        return nil, nil
    elseif lifecycle == lifecycles.SENT then
        local res = VALID_RESOLUTION[quest.resolution] and quest.resolution or nil
        if res ~= nil then
            return res, quest.lastResult
        end
        return nil, { recipient = quest.sentTo, sentAt = quest.sentAt }
    else
        local res = VALID_RESOLUTION[quest.resolution] and quest.resolution or nil
        return res, nil
    end
end

function QuestRepository:MarkCompletionReported(questId)
    local quest = self:GetQuestById(questId)
    if not quest then return false end
    quest.completionReported = true
    self:NotifyListeners("COMPLETION_REPORTED", quest)
    return true
end

function QuestRepository:MarkFailureReported(questId)
    local quest = self:GetQuestById(questId)
    if not quest then return false end
    quest.failureReported = true
    self:NotifyListeners("FAILURE_REPORTED", quest)
    return true
end

function QuestRepository:GetSetting(key)
    if not self.savedVars or type(self.savedVars.settings) ~= "table" then
        return nil
    end
    return self.savedVars.settings[key]
end

function QuestRepository:SetSetting(key, value)
    if not self.savedVars then return end
    if type(self.savedVars.settings) ~= "table" then
        self.savedVars.settings = {}
    end
    self.savedVars.settings[key] = value
    self:NotifyListeners("SETTINGS_UPDATED", self.savedVars.settings)
end

function QuestRepository:GetJournalUiState()
    if not self.savedVars then
        return { lastSectionKey = nil, lastSelectedQuestId = nil }
    end
    if type(self.savedVars.uiState) ~= "table" then
        self.savedVars.uiState = { lastSectionKey = nil, lastSelectedQuestId = nil }
    end
    return self.savedVars.uiState
end

function QuestRepository:SetLastSectionKey(sectionKey)
    local uiState = self:GetJournalUiState()
    uiState.lastSectionKey = sectionKey
end

function QuestRepository:SetLastSelectedQuestId(questId)
    local uiState = self:GetJournalUiState()
    uiState.lastSelectedQuestId = questId
end

function QuestRepository:IsPreparedQuest(quest)
    if type(quest) ~= "table" then
        return false
    end
    local lifecycle = self:GetQuestLifecycle(quest)
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    return lifecycle == lifecycles.DRAFT or lifecycle == lifecycles.SENT or quest.role == Addon.Constants.QUEST_ROLE.PREPARED
end

function QuestRepository:GetAllQuests()
    if not self.savedVars then return {} end
    return self.savedVars.quests or {}
end

local function FilterQuests(self, predicate)
    local result = {}
    for _, q in ipairs(self:GetAllQuests()) do
        if predicate(q) then
            table.insert(result, q)
        end
    end
    return result
end

function QuestRepository:GetQuestsByRole(role)
    return FilterQuests(self, function(q) return q.role == role end)
end

function QuestRepository:GetCompletedQuests()
    return FilterQuests(self, function(q) return q.completed end)
end

function QuestRepository:GetQuestById(questId)
    if not questId then return nil end
    if self._questById and self._questById[questId] then
        return self._questById[questId]
    end
    for _, q in ipairs(self:GetAllQuests()) do
        if q.id == questId then
            if self._questById then
                self._questById[questId] = q
            end
            return q
        end
    end
    return nil
end

function QuestRepository:HasTargetLocation(target)
    return type(target) == "table" and target.worldX ~= nil and target.worldZ ~= nil
end

function QuestRepository:HasQuestTargetLocation(quest)
    if type(quest) ~= "table" or type(quest.targets) ~= "table" then
        return false
    end
    for _, target in ipairs(quest.targets) do
        if self:HasTargetLocation(target) then
            return true
        end
    end
    return false
end

function QuestRepository:HasQuestSearchAreas(quest)
    if type(quest) ~= "table" then
        return false
    end
    if type(quest.targets) == "table" then
        for _, target in ipairs(quest.targets) do
            if type(target) == "table" and target.areaCenterX and target.areaCenterY and target.areaRadius and target.areaRadius > 0 then
                return true
            end
        end
    end
    return quest.areaCenterX ~= nil and quest.areaCenterY ~= nil and quest.areaRadius ~= nil and quest.areaRadius > 0
end

function QuestRepository:HasQuestDiscoveryPoints(quest)
    return type(quest) == "table" and type(quest.discoveries) == "table" and #quest.discoveries > 0
end

function QuestRepository:SetQuestMapVisibility(questId, key, enabled)
    if key ~= "showSearchAreas" and key ~= "showLocationAreas" and key ~= "showDiscoveryAreas" then
        return false
    end
    local quest = self:GetQuestById(questId)
    if not quest then
        return false
    end
    quest[key] = (enabled == true)
    self:NotifyListeners("QUEST_MAP_VISIBILITY_CHANGED", quest)
    return true
end

function QuestRepository:IsPlayerInsideTargetLocation(target, playerZoneId, playerWorldX, playerWorldZ)
    return Addon.WorldMapArea:IsPlayerInsideTargetLocation(target, playerZoneId, playerWorldX, playerWorldZ)
end

function QuestRepository:GetActiveQuest()
    if not self.savedVars or not self.savedVars.activeQuestId then
        return nil
    end
    local q = self:GetQuestById(self.savedVars.activeQuestId)
    if q and not q.completed and not q.failed and not self:IsOfferedQuest(q) then
        return q
    end
    return nil
end

function QuestRepository:HasPlayableObjectives(quest)
    if type(quest) ~= "table" then
        return false
    end
    local hasTargets = type(quest.targets) == "table" and #quest.targets > 0
    local hasDiscoveries = type(quest.discoveries) == "table" and #quest.discoveries > 0
    return hasTargets or hasDiscoveries
end

function QuestRepository:HasMissingDiscoveryMessage(quest)
    if type(quest) ~= "table" or type(quest.discoveries) ~= "table" or #quest.discoveries == 0 then
        return false
    end
    for _, d in ipairs(quest.discoveries) do
        local msg = type(d) == "table" and type(d.message) == "string"
            and d.message:gsub("^%s+", ""):gsub("%s+$", "")
            or ""
        if msg == "" then
            return true
        end
    end
    return false
end

function QuestRepository:SetActiveQuest(questId)
    if questId == nil then
        self.savedVars.activeQuestId = nil
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("ACTIVE_QUEST_CHANGED", nil)
        return true
    end

    local q = self:GetQuestById(questId)
    if not q or q.completed or q.failed or q.needsMigration or self:IsOfferedQuest(q) then
        return false
    end
    if not self:HasPlayableObjectives(q) then
        return false, "ERR_MISSING_TARGET"
    end
    if self:HasMissingDiscoveryMessage(q) then
        return false, "ERR_DISCOVERY_MISSING_MSG"
    end

    self.savedVars.activeQuestId = q.id
    self:InvalidateActiveTargetCache()
    self:NotifyListeners("ACTIVE_QUEST_CHANGED", q)
    return true
end

function QuestRepository:ResetQuest(questId, options)
    local q = self:GetQuestById(questId)
    if not q then return false end

    local shouldActivate = not (type(options) == "table" and options.activate == false)
    if shouldActivate and not self:HasPlayableObjectives(q) then
        return false, "ERR_MISSING_TARGET"
    end
    if shouldActivate and self:HasMissingDiscoveryMessage(q) then
        return false, "ERR_DISCOVERY_MISSING_MSG"
    end

    for _, t in ipairs(q.targets or {}) do
        t.currentCount = 0
    end
    for _, d in ipairs(q.discoveries or {}) do
        d.discovered = false
    end
    q.completed = false
    q.failed = false
    q.wasDetected = false
    q.completionReported = false
    q.failureReported = false
    if self:GetQuestLifecycle(q) == Addon.Constants.QUEST_LIFECYCLE.RECEIVED and not self:IsOfferedQuest(q) then
        q.resolution = Addon.Constants.QUEST_RESOLUTION.ACCEPTED
    end
    if self._completionCodeCache then
        self._completionCodeCache[questId] = nil
    end

    local wasActive = (self.savedVars.activeQuestId == q.id)
    if shouldActivate then
        self.savedVars.activeQuestId = q.id
    elseif wasActive then
        self.savedVars.activeQuestId = nil
    end

    self:InvalidateActiveTargetCache()
    self:NotifyListeners("QUEST_RESET", q)
    if not shouldActivate and wasActive then
        self:NotifyListeners("ACTIVE_QUEST_CHANGED", nil)
    end
    return true
end

local function ClonePreparedQuestRecord(repo, source)
    local newId = repo.savedVars.nextId or 1
    repo.savedVars.nextId = newId + 1

    local clonedTargets = Addon.QuestDraftStore:CloneTargetsList(source.targets)
    for _, t in ipairs(clonedTargets) do
        t.currentCount = 0
    end

    local senderChar = (type(source.senderCharacterName) == "string" and source.senderCharacterName ~= "")
        and source.senderCharacterName
        or repo:GetPlayerCharacterName()

    local questData = {
        senderDisplayName = source.senderDisplayName,
        senderCharacterName = senderChar,
        recipientAccount = source.recipientAccount,
        recipientCharacterName = source.recipientCharacterName,
        clue = source.clue,
        completionMessage = source.completionMessage,
        discoveries = Addon.QuestDraftStore:CloneDiscoveriesList(source.discoveries, false),
        dialogues = Addon.QuestDraftStore:CloneDialoguesList(source.dialogues, source.clue),
        mapId = source.mapId,
        zoneId = source.zoneId,
        mapName = source.mapName,
        targetX = source.targetX,
        targetY = source.targetY,
        recommendHideMapAreas = (source.recommendHideMapAreas ~= false),
        stealthMode = Addon.QuestDraftStore:NormalizeStealthMode(source.stealthMode, source.requireUndetected),
        icon = Addon.QuestDraftStore:NormalizeQuestIcon(source.icon),
    }

    local newQuest = repo:BuildQuestRecord(
        newId,
        source.title or "",
        source.description or "",
        clonedTargets,
        questData,
        Addon.Constants.QUEST_ROLE.PREPARED
    )
    newQuest.createdAt = GetTimeStamp() or 0
    newQuest.lifecycle = Addon.Constants.QUEST_LIFECYCLE.DRAFT
    newQuest.resolution = nil
    newQuest.sentTo = nil
    newQuest.lastResult = nil
    newQuest.deliveries = {}
    newQuest.needsMigration = nil
    newQuest.migrationReason = nil

    table.insert(repo.savedVars.quests, newQuest)
    if repo._questById then
        repo._questById[newQuest.id] = newQuest
    end

    repo:NotifyListeners("QUEST_CREATED", newQuest)
    return newQuest
end

function QuestRepository:DuplicateQuest(questId)
    if not self.savedVars then return nil end
    local source = self:GetQuestById(questId)
    if not source then return nil end
    if not self:IsPreparedQuest(source) then
        return nil, Addon.Locale:Get("ERR_CANNOT_COPY_RECEIVED")
    end
    return ClonePreparedQuestRecord(self, source)
end

function QuestRepository:MigratePreparedQuest(questId)
    if not self.savedVars then return nil end
    local source = self:GetQuestById(questId)
    if not source then return nil end
    if not self:IsPreparedQuest(source) then
        return nil, Addon.Locale:Get("ERR_CANNOT_MIGRATE_RECEIVED")
    end
    return ClonePreparedQuestRecord(self, source)
end

function QuestRepository:DeleteQuest(questId)
    if not self.savedVars or not questId then return false end
    for i, q in ipairs(self.savedVars.quests) do
        if q.id == questId then
            local wasActive = (self.savedVars.activeQuestId == questId)
            table.remove(self.savedVars.quests, i)
            if self._questById then
                self._questById[questId] = nil
            end
            if self._shareCodeCache then
                self._shareCodeCache[questId] = nil
            end
            if self._completionCodeCache then
                self._completionCodeCache[questId] = nil
            end
            if self.savedVars.draft and self.savedVars.draft.editingQuestId == questId then
                self:ResetDraft()
            end
            if self.savedVars.uiState and self.savedVars.uiState.lastSelectedQuestId == questId then
                self.savedVars.uiState.lastSelectedQuestId = nil
            end
            if wasActive then
                self.savedVars.activeQuestId = nil
                self:InvalidateActiveTargetCache()
                for _, cand in ipairs(self.savedVars.quests) do
                    if not cand.completed then
                        self.savedVars.activeQuestId = cand.id
                        break
                    end
                end
            end
            self:NotifyListeners("QUEST_DELETED", q)
            return true
        end
    end
    return false
end

function QuestRepository:IsPlayerInsideQuestArea(quest, playerMapId, playerZoneId, playerX, playerY)
    return Addon.WorldMapArea:IsPlayerInsideQuestArea(quest, playerMapId, playerZoneId, playerX, playerY)
end

function QuestRepository:FindPendingTarget(rawTargetName)
    if type(rawTargetName) ~= "string" or rawTargetName == "" then
        return nil, nil
    end

    local activeQuest = self:GetActiveQuest()
    if not activeQuest or activeQuest.completed or activeQuest.failed or not activeQuest.targets or #activeQuest.targets == 0 then
        return nil, nil
    end

    local cleanKilled = self:NormalizeName(rawTargetName):lower()
    if cleanKilled == "" then
        return nil, nil
    end

    local cache = self._activeTargetCache
    if not cache or cache.questId ~= activeQuest.id then
        local byLowerName = {}
        for _, entry in ipairs(activeQuest.targets or {}) do
            local key = (entry.name or ""):lower()
            if key ~= "" and not byLowerName[key] then
                byLowerName[key] = entry
            end
        end
        cache = {
            questId = activeQuest.id,
            byLowerName = byLowerName,
        }
        self._activeTargetCache = cache
    end

    local matched = cache.byLowerName[cleanKilled]
    if matched and (matched.currentCount or 0) < (matched.requiredCount or 1) then
        return activeQuest, matched
    end

    return nil, nil
end

local function TrimText(val)
    if type(val) ~= "string" then
        return ""
    end
    return (val:gsub("^%s+", ""):gsub("%s+$", ""))
end

function QuestRepository:RecordTargetEliminated(rawTargetName, playerContext, preMatchedQuest, preMatchedTarget)
    local activeQuest, matchedTarget = preMatchedQuest, preMatchedTarget
    if not activeQuest or not matchedTarget then
        activeQuest, matchedTarget = self:FindPendingTarget(rawTargetName)
    end
    if not activeQuest or not matchedTarget then
        return false, nil, false, nil
    end

    local hasTargetLoc = self:HasTargetLocation(matchedTarget)
    local isLocRequired = hasTargetLoc and (matchedTarget.locationRequired == true)
    local customMsgToShow = nil
    local generalMsg = TrimText(matchedTarget.customMessage)

    if hasTargetLoc then
        local pZone = type(playerContext) == "table" and playerContext.worldZoneId or nil
        local pWX = type(playerContext) == "table" and playerContext.worldX or nil
        local pWZ = type(playerContext) == "table" and playerContext.worldZ or nil
        local inTargetLoc = self:IsPlayerInsideTargetLocation(matchedTarget, pZone, pWX, pWZ)
        if inTargetLoc then
            local inLocMsg = TrimText(matchedTarget.customMessageInLocation)
            if inLocMsg ~= "" then
                customMsgToShow = inLocMsg
            elseif generalMsg ~= "" then
                customMsgToShow = generalMsg
            end
        else
            if isLocRequired then
                FinalizeFailedQuest(self, activeQuest)
                return false, activeQuest, false, matchedTarget, true, (generalMsg ~= "" and generalMsg or nil)
            elseif generalMsg ~= "" then
                customMsgToShow = generalMsg
            end
        end
    elseif generalMsg ~= "" then
        customMsgToShow = generalMsg
    end

    matchedTarget.currentCount = math.min(matchedTarget.requiredCount or 1, (matchedTarget.currentCount or 0) + 1)

    if self:AreAllObjectivesCompleted(activeQuest.targets, activeQuest.discoveries) then
        FinalizeCompletedQuest(self, activeQuest)
        self:NotifyListeners("QUEST_COMPLETED", activeQuest)
    else
        self:NotifyListeners("QUEST_PROGRESS", activeQuest)
    end

    return true, activeQuest, activeQuest.completed, matchedTarget, false, customMsgToShow
end

function QuestRepository:HasPendingDiscoveries(quest)
    if not quest or quest.completed or quest.failed or type(quest.discoveries) ~= "table" then
        return false
    end
    for _, d in ipairs(quest.discoveries) do
        if not d.discovered then
            return true
        end
    end
    return false
end

function QuestRepository:MarkDiscoveryTriggered(questId, discoveryIndex)
    local quest = self:GetQuestById(questId)
    if not quest or quest.completed or quest.failed or type(quest.discoveries) ~= "table" then
        return false, nil, false, nil
    end
    local point = quest.discoveries[discoveryIndex]
    if not point or point.discovered then
        return false, nil, false, nil
    end

    point.discovered = true

    if self:AreAllObjectivesCompleted(quest.targets, quest.discoveries) then
        FinalizeCompletedQuest(self, quest)
        self:NotifyListeners("DISCOVERY_TRIGGERED", quest)
        self:NotifyListeners("QUEST_COMPLETED", quest)
    else
        self:NotifyListeners("DISCOVERY_TRIGGERED", quest)
    end

    return true, quest, quest.completed, point
end

function QuestRepository:RecordPlayerDetected(playerContext)
    local activeQuest = self:GetActiveQuest()
    local modes = Addon.Constants.STEALTH_MODE
    local stealthMode = activeQuest and activeQuest.stealthMode
    if not activeQuest or activeQuest.completed or activeQuest.failed or activeQuest.wasDetected then
        return false, nil, false
    end
    if stealthMode ~= modes.OPTIONAL and stealthMode ~= modes.REQUIRED then
        return false, nil, false
    end

    if type(playerContext) == "table" then
        local inArea = self:IsPlayerInsideQuestArea(
            activeQuest,
            playerContext.mapId,
            playerContext.zoneId,
            playerContext.x,
            playerContext.y
        )
        if not inArea then
            return false, nil, false
        end
    end

    activeQuest.wasDetected = true
    if stealthMode == modes.REQUIRED then
        FinalizeFailedQuest(self, activeQuest)
        return true, activeQuest, true
    end

    self:NotifyListeners("QUEST_DETECTED", activeQuest)
    return true, activeQuest, false
end

function QuestRepository:FindDialogueForActiveQuest(rawNpcName, zoneId)
    local activeQuest = self:GetActiveQuest()
    if not activeQuest or activeQuest.completed or activeQuest.failed then
        return nil
    end

    local questClue = type(activeQuest.clue) == "string" and activeQuest.clue:gsub("^%s+", ""):gsub("%s+$", "") or ""

    local dialogues = activeQuest.dialogues
    if type(dialogues) ~= "table" or #dialogues == 0 then
        return nil
    end

    local cleanNpc = self:NormalizeName(rawNpcName)
    if cleanNpc == "" then
        return nil
    end

    local lowerNpc = cleanNpc:lower()
    local z = math.floor(tonumber(zoneId) or 0)

    for _, entry in ipairs(dialogues) do
        if type(entry) == "table" and type(entry.npcName) == "string" and entry.npcName ~= "" then
            local entryName = self:NormalizeName(entry.npcName):lower()
            local entryZone = math.floor(tonumber(entry.zoneId) or 0)
            if entryName == lowerNpc and (entryZone == 0 or z == 0 or entryZone == z) then
                local entryClue = type(entry.clue) == "string" and entry.clue:gsub("^%s+", ""):gsub("%s+$", "") or ""
                local resolvedClue = (entryClue ~= "" and entryClue) or (entry.clue == nil and questClue) or ""
                if resolvedClue == "" then
                    return nil
                end
                return {
                    questId = activeQuest.id,
                    clue = resolvedClue,
                    npcName = entry.npcName,
                    zoneId = entryZone,
                    response = type(entry.response) == "string" and entry.response or "",
                }
            end
        end
    end

    return nil
end
