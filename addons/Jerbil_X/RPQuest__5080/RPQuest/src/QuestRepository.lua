-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestRepository = {}
local QuestRepository = Addon.QuestRepository

local function Clamp(val, minVal, maxVal)
    if val < minVal then return minVal end
    if val > maxVal then return maxVal end
    return val
end

function QuestRepository:NormalizeName(name)
    if type(name) ~= "string" or name == "" then return "" end
    local clean = name:gsub("%^%a+$", "")
    if zo_strformat then
        clean = zo_strformat("<<C:1>>", clean)
    end
    clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
    return clean
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

local function AreAllObjectivesCompleted(targets, discoveries)
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

local function CreateDefaultDraft()
    return {
        editingQuestId = nil,
        title = "",
        description = "",
        clue = "",
        completionMessage = "",
        targets = {},
        discoveries = {},
        dialogues = {},
        discoveryRadius = Addon.Constants.DISCOVERY_RADIUS.MEDIUM,
        discoveryMessage = "",
        lastCapturedDisplay = nil,
        mapId = 0,
        zoneId = 0,
        mapName = "",
        targetX = nil,
        targetY = nil,
        areaCenterX = nil,
        areaCenterY = nil,
        areaRadius = Addon.Constants.AREA_RADIUS.MEDIUM,
        hideMapArea = false,
        requireUndetected = false,
    }
end

local function CloneDialoguesList(dialogues, fallbackClue)
    local out = {}
    if type(dialogues) ~= "table" then return out end
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    local fallback = type(fallbackClue) == "string" and fallbackClue or ""
    for _, d in ipairs(dialogues) do
        if #out >= maxNpcs then break end
        if type(d) == "table" and type(d.npcName) == "string" and d.npcName ~= "" then
            local cleanName = QuestRepository:NormalizeName(d.npcName)
            if cleanName ~= "" then
                table.insert(out, {
                    npcName = cleanName,
                    zoneId = math.floor(tonumber(d.zoneId) or 0),
                    clue = type(d.clue) == "string" and d.clue or fallback,
                    response = type(d.response) == "string" and d.response or "",
                })
            end
        end
    end
    return out
end

local function BuildQuestRecord(id, title, description, targets, data, role)
    return {
        id = id,
        title = title,
        description = description,
        clue = type(data.clue) == "string" and data.clue or "",
        completionMessage = data.completionMessage or "",
        targets = targets,
        discoveries = data.discoveries or {},
        dialogues = CloneDialoguesList(data.dialogues, data.clue),
        completed = false,
        role = role or Addon.Constants.QUEST_ROLE.RECEIVED,
        mapId = data.mapId or 0,
        zoneId = data.zoneId or 0,
        mapName = data.mapName or "",
        targetX = data.targetX,
        targetY = data.targetY,
        areaCenterX = data.areaCenterX,
        areaCenterY = data.areaCenterY,
        areaRadius = data.areaRadius,
        hideMapArea = data.hideMapArea and true or false,
        requireUndetected = data.requireUndetected and true or false,
        wasDetected = false,
        failed = false,
        senderDisplayName = type(data.senderDisplayName) == "string" and data.senderDisplayName or nil,
        completionReported = (data.completionReported == true),
        deliveries = type(data.deliveries) == "table" and data.deliveries or {},
    }
end

local function CloneDiscoveriesList(discoveries, preserveDiscovered)
    local out = {}
    if type(discoveries) ~= "table" then return out end
    local defaultRad = Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    for _, d in ipairs(discoveries) do
        if type(d) == "table" and d.worldX and d.worldZ then
            table.insert(out, {
                zoneId = math.floor(tonumber(d.zoneId) or 0),
                worldX = tonumber(d.worldX) or 0,
                worldY = tonumber(d.worldY) or 0,
                worldZ = tonumber(d.worldZ) or 0,
                mapId = math.floor(tonumber(d.mapId) or 0),
                x = tonumber(d.x),
                y = tonumber(d.y),
                radius = math.max(100, math.floor(tonumber(d.radius) or defaultRad)),
                message = type(d.message) == "string" and d.message or "",
                discovered = preserveDiscovered and (d.discovered == true) or false,
            })
        end
    end
    return out
end

local function CloneTargetsList(targets, existingTargetsByName)
    local out = {}
    if type(targets) ~= "table" then return out end
    local defaultRad = Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    for _, t in ipairs(targets) do
        if type(t) == "table" and type(t.name) == "string" and t.name ~= "" then
            local req = math.max(1, math.floor(tonumber(t.requiredCount) or 1))
            local cur = math.max(0, math.floor(tonumber(t.currentCount) or 0))
            if existingTargetsByName and existingTargetsByName[t.name:lower()] ~= nil then
                cur = math.min(req, existingTargetsByName[t.name:lower()])
            end
            local hasLoc = (t.worldX ~= nil and t.worldZ ~= nil)
            table.insert(out, {
                name = t.name,
                currentCount = cur,
                requiredCount = req,
                targetX = t.targetX,
                targetY = t.targetY,
                zoneId = hasLoc and math.floor(tonumber(t.zoneId) or 0) or nil,
                worldX = hasLoc and tonumber(t.worldX) or nil,
                worldZ = hasLoc and tonumber(t.worldZ) or nil,
                radius = hasLoc and math.max(100, math.floor(tonumber(t.radius) or defaultRad)) or nil,
                locationRequired = (t.locationRequired == true),
                customMessage = type(t.customMessage) == "string" and t.customMessage or "",
            })
        end
    end
    return out
end

function QuestRepository:GetDefaults()
    return {
        nextId = 1,
        activeQuestId = nil,
        quests = {},
        draft = CreateDefaultDraft(),
        settings = {
            autoDeleteMail = true,
            autoAcceptMail = false,
            autoSendCompletionMail = false,
        },
    }
end

function QuestRepository:Initialize(savedVars)
    self.savedVars = savedVars or self:GetDefaults()
    self.savedVars.nextId = self.savedVars.nextId or 1
    self.savedVars.quests = self.savedVars.quests or {}
    if type(self.savedVars.settings) ~= "table" then
        self.savedVars.settings = { autoDeleteMail = true, autoAcceptMail = false, autoSendCompletionMail = false }
    else
        if self.savedVars.settings.autoDeleteMail == nil then
            self.savedVars.settings.autoDeleteMail = true
        end
        if self.savedVars.settings.autoAcceptMail == nil then
            self.savedVars.settings.autoAcceptMail = false
        end
        if self.savedVars.settings.autoSendCompletionMail == nil then
            self.savedVars.settings.autoSendCompletionMail = false
        end
    end
    if not self.savedVars.draft then
        self.savedVars.draft = CreateDefaultDraft()
    else
        self.savedVars.draft.targets = self.savedVars.draft.targets or {}
        self.savedVars.draft.discoveries = self.savedVars.draft.discoveries or {}
    end
    self._questById = {}
    self._shareCodeCache = {}
    self._completionCodeCache = {}
    self._activeTargetCache = nil
    local roles = Addon.Constants.QUEST_ROLE
    for _, q in ipairs(self.savedVars.quests) do
        q.targets = q.targets or {}
        if q.role ~= roles.PREPARED and q.role ~= roles.RECEIVED then
            q.role = roles.RECEIVED
        end
        if q.id then
            self._questById[q.id] = q
        end
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

-- Calcula un centro desplazado aleatorio para que (targetX, targetY) quede
-- garantizadamente dentro del círculo de radio `radius`, pero no en su centro exacto.
function QuestRepository:ComputeOffsetCenter(targetX, targetY, radius, randomAngle01, randomDist01)
    local r = tonumber(radius) or 0.075
    if r <= 0 then r = 0.075 end

    local tx = Clamp(tonumber(targetX) or 0.5, 0.01, 0.99)
    local ty = Clamp(tonumber(targetY) or 0.5, 0.01, 0.99)

    local minRatio = Addon.Constants.AREA_OFFSET.MIN_RATIO
    local maxRatio = Addon.Constants.AREA_OFFSET.MAX_RATIO

    local uAngle = (randomAngle01 ~= nil) and randomAngle01 or math.random()
    local uDist = (randomDist01 ~= nil) and randomDist01 or math.random()

    local angle = uAngle * 2 * math.pi
    local dist = (minRatio + (uDist * (maxRatio - minRatio))) * r

    local cx = tx + (dist * math.cos(angle))
    local cy = ty + (dist * math.sin(angle))

    local minBound = math.max(0.02, r * 0.5)
    local maxBound = math.min(0.98, 1.0 - (r * 0.5))

    cx = Clamp(cx, minBound, maxBound)
    cy = Clamp(cy, minBound, maxBound)

    -- Garantizar matemáticamente que la distancia entre (tx, ty) y (cx, cy) sea <= 0.80 * r
    local dx = tx - cx
    local dy = ty - cy
    local actualDist = math.sqrt((dx * dx) + (dy * dy))
    local maxAllowedDist = r * 0.80
    if actualDist > maxAllowedDist and actualDist > 0 then
        local scale = maxAllowedDist / actualDist
        cx = tx - (dx * scale)
        cy = ty - (dy * scale)
    end

    return cx, cy
end

function QuestRepository:GetDraft()
    if not self.savedVars then
        self:Initialize()
    end
    self.savedVars.draft.targets = self.savedVars.draft.targets or {}
    self.savedVars.draft.discoveries = self.savedVars.draft.discoveries or {}
    return self.savedVars.draft
end

function QuestRepository:ResetDraft()
    if not self.savedVars then
        self:Initialize()
    end
    self.savedVars.draft = CreateDefaultDraft()
    self:NotifyListeners("DRAFT_UPDATED", self.savedVars.draft)
    return self.savedVars.draft
end

function QuestRepository:ClearDraftTargets()
    local draft = self:GetDraft()
    draft.targets = {}
    draft.lastCapturedDisplay = nil
    draft.targetX = nil
    draft.targetY = nil
    draft.areaCenterX = nil
    draft.areaCenterY = nil
    if #draft.discoveries == 0 then
        draft.mapId = 0
        draft.zoneId = 0
        draft.mapName = ""
    end
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestRepository:AddDraftDiscoveryPoint(data)
    if type(data) ~= "table" or not data.worldX or not data.worldZ then
        return nil
    end
    local draft = self:GetDraft()
    draft.discoveries = draft.discoveries or {}
    local defaultRad = draft.discoveryRadius or Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    local point = {
        zoneId = math.floor(tonumber(data.zoneId) or 0),
        worldX = tonumber(data.worldX) or 0,
        worldY = tonumber(data.worldY) or 0,
        worldZ = tonumber(data.worldZ) or 0,
        mapId = math.floor(tonumber(data.mapId) or 0),
        x = tonumber(data.x),
        y = tonumber(data.y),
        radius = math.max(100, math.floor(tonumber(data.radius) or defaultRad)),
        message = type(data.message) == "string" and data.message or "",
        discovered = false,
    }
    table.insert(draft.discoveries, point)
    if (not draft.mapId or draft.mapId == 0) and point.mapId > 0 then
        draft.mapId = point.mapId
    end
    if (not draft.zoneId or draft.zoneId == 0) and point.zoneId > 0 then
        draft.zoneId = point.zoneId
    end
    if (not draft.mapName or draft.mapName == "") and type(data.mapName) == "string" and data.mapName ~= "" then
        draft.mapName = data.mapName
    end
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft, #draft.discoveries
end

function QuestRepository:ClearDraftDiscoveries()
    local draft = self:GetDraft()
    draft.discoveries = {}
    if #(draft.targets or {}) == 0 then
        draft.mapId = 0
        draft.zoneId = 0
        draft.mapName = ""
    end
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestRepository:UpdateDraftDiscoveryPoint(index, fields, silent)
    local draft = self:GetDraft()
    local point = draft.discoveries and draft.discoveries[index]
    if not point or type(fields) ~= "table" then
        return nil
    end
    if fields.message ~= nil then
        point.message = tostring(fields.message)
    end
    if fields.radius ~= nil then
        local r = tonumber(fields.radius)
        if r and r >= 100 then
            point.radius = math.floor(r)
        end
    end
    if not silent then
        self:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return point
end

function QuestRepository:RemoveDraftDiscoveryPoint(index)
    local draft = self:GetDraft()
    if not draft.discoveries or not draft.discoveries[index] then
        return nil
    end
    table.remove(draft.discoveries, index)
    if #draft.discoveries == 0 and #(draft.targets or {}) == 0 then
        draft.mapId = 0
        draft.zoneId = 0
        draft.mapName = ""
    end
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
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

function QuestRepository:AddDraftDialogue(npcName, zoneId, responseText, clueText)
    local draft = self:GetDraft()
    draft.dialogues = draft.dialogues or {}
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    if #draft.dialogues >= maxNpcs then
        return nil, Addon.Locale:Get("ALERT_DIALOGUE_LIMIT", maxNpcs)
    end

    local cleanName = self:NormalizeName(npcName)
    if cleanName == "" then
        return nil, Addon.Locale:Get("ALERT_DIALOGUE_NO_LAST_NPC")
    end

    local z = math.floor(tonumber(zoneId) or 0)
    local lowerName = cleanName:lower()
    for _, existing in ipairs(draft.dialogues) do
        if self:NormalizeName(existing.npcName):lower() == lowerName and ((existing.zoneId or 0) == z or z == 0 or (existing.zoneId or 0) == 0) then
            return nil, Addon.Locale:Get("ALERT_DIALOGUE_DUPLICATE")
        end
    end

    table.insert(draft.dialogues, {
        npcName = cleanName,
        zoneId = z,
        clue = type(clueText) == "string" and clueText or "",
        response = type(responseText) == "string" and responseText or "",
    })
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft, #draft.dialogues
end

function QuestRepository:AddDraftDialogueFromLastNpc(responseText, clueText)
    local lastNpc = self:GetLastInteractedNpc()
    if not lastNpc or not lastNpc.name or lastNpc.name == "" then
        return nil, Addon.Locale:Get("ALERT_DIALOGUE_NO_LAST_NPC")
    end
    return self:AddDraftDialogue(lastNpc.name, lastNpc.zoneId, responseText, clueText)
end

function QuestRepository:UpdateDraftDialogue(index, fields, silent)
    local draft = self:GetDraft()
    local entry = draft.dialogues and draft.dialogues[index]
    if not entry or type(fields) ~= "table" then
        return nil
    end
    if fields.clue ~= nil then
        entry.clue = tostring(fields.clue)
    end
    if fields.response ~= nil then
        entry.response = tostring(fields.response)
    end
    if not silent then
        self:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return entry
end

function QuestRepository:RemoveDraftDialogue(index)
    local draft = self:GetDraft()
    if not draft.dialogues or not draft.dialogues[index] then
        return nil
    end
    table.remove(draft.dialogues, index)
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestRepository:ClearDraftDialogues()
    local draft = self:GetDraft()
    draft.dialogues = {}
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestRepository:LoadQuestIntoDraft(questId)
    local quest = self:GetQuestById(questId)
    if not quest then return nil end
    if not self:IsPreparedQuest(quest) then
        return nil, Addon.Locale:Get("ERR_CANNOT_EDIT_RECEIVED")
    end

    self.savedVars.draft = {
        editingQuestId = quest.id,
        title = quest.title or "",
        description = quest.description or "",
        clue = quest.clue or "",
        completionMessage = quest.completionMessage or "",
        targets = CloneTargetsList(quest.targets),
        discoveries = CloneDiscoveriesList(quest.discoveries, false),
        dialogues = CloneDialoguesList(quest.dialogues, quest.clue),
        discoveryRadius = Addon.Constants.DISCOVERY_RADIUS.MEDIUM,
        discoveryMessage = "",
        lastCapturedDisplay = nil,
        mapId = quest.mapId or 0,
        zoneId = quest.zoneId or 0,
        mapName = quest.mapName or "",
        targetX = quest.targetX,
        targetY = quest.targetY,
        areaCenterX = quest.areaCenterX,
        areaCenterY = quest.areaCenterY,
        areaRadius = quest.areaRadius or 0.075,
        hideMapArea = quest.hideMapArea and true or false,
        requireUndetected = quest.requireUndetected and true or false,
    }
    self:NotifyListeners("DRAFT_UPDATED", self.savedVars.draft)
    return self.savedVars.draft
end

function QuestRepository:UpdateDraftFields(fields, silent)
    local draft = self:GetDraft()
    if type(fields) ~= "table" then return draft end

    if fields.title ~= nil then draft.title = tostring(fields.title) end
    if fields.description ~= nil then draft.description = tostring(fields.description) end
    if fields.clue ~= nil then draft.clue = tostring(fields.clue) end
    if fields.completionMessage ~= nil then draft.completionMessage = tostring(fields.completionMessage) end
    if fields.hideMapArea ~= nil then draft.hideMapArea = (fields.hideMapArea == true) end
    if fields.discoveryMessage ~= nil then draft.discoveryMessage = tostring(fields.discoveryMessage) end
    if fields.discoveryRadius ~= nil then
        local newDiscRadius = tonumber(fields.discoveryRadius)
        if newDiscRadius and newDiscRadius >= 100 then
            draft.discoveryRadius = math.floor(newDiscRadius)
        end
    end
    if fields.requireUndetected ~= nil then draft.requireUndetected = (fields.requireUndetected == true) end
    if fields.areaRadius ~= nil then
        local newRadius = tonumber(fields.areaRadius) or draft.areaRadius
        if newRadius > 0 then
            draft.areaRadius = newRadius
            if draft.targetX and draft.targetY then
                draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, draft.areaRadius)
            end
        end
    end
    if not silent then
        self:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return draft
end

function QuestRepository:SetDraftCapturedTarget(captureData)
    if type(captureData) ~= "table" then return nil end
    local cleanName = self:NormalizeName(captureData.targetName)
    if cleanName == "" then return nil end

    local draft = self:GetDraft()
    local newMapId = tonumber(captureData.mapId) or 0
    if draft.mapId and draft.mapId > 0 and newMapId > 0 and draft.mapId ~= newMapId then
        draft.targets = {}
    else
        draft.targets = draft.targets or {}
    end

    local tx = tonumber(captureData.targetX) or 0.5
    local ty = tonumber(captureData.targetY) or 0.5

    local matchedEntry = nil
    local cleanKey = cleanName:lower()
    for _, entry in ipairs(draft.targets) do
        if (entry.name or ""):lower() == cleanKey then
            matchedEntry = entry
            break
        end
    end

    if matchedEntry then
        matchedEntry.requiredCount = math.min(999, (tonumber(matchedEntry.requiredCount) or 1) + 1)
        matchedEntry.targetX = tx
        matchedEntry.targetY = ty
    else
        matchedEntry = {
            name = cleanName,
            currentCount = 0,
            requiredCount = 1,
            targetX = tx,
            targetY = ty,
        }
        table.insert(draft.targets, matchedEntry)
    end

    draft.lastCapturedDisplay = self:FormatTargetEntry(matchedEntry)
    draft.mapId = tonumber(captureData.mapId) or draft.mapId or 0
    draft.zoneId = tonumber(captureData.zoneId) or draft.zoneId or 0
    draft.mapName = tostring(captureData.mapName or draft.mapName or "")

    -- Calcular centroide de los objetivos capturados para situar el área de búsqueda
    local sumX, sumY, countCoords = 0, 0, 0
    for _, entry in ipairs(draft.targets) do
        if entry.targetX and entry.targetY then
            sumX = sumX + entry.targetX
            sumY = sumY + entry.targetY
            countCoords = countCoords + 1
        end
    end
    if countCoords > 0 then
        draft.targetX = sumX / countCoords
        draft.targetY = sumY / countCoords
    else
        draft.targetX = tx
        draft.targetY = ty
    end

    local radius = draft.areaRadius or Addon.Constants.AREA_RADIUS.MEDIUM
    draft.areaRadius = radius
    draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, radius)

    self:NotifyListeners("DRAFT_TARGET_CAPTURED", draft)
    return draft
end

function QuestRepository:SaveDraft(titleInput, descriptionInput, areaRadiusInput, completionMessageInput, requireUndetectedInput)
    local draft = self:GetDraft()

    if titleInput ~= nil then draft.title = tostring(titleInput) end
    if descriptionInput ~= nil then draft.description = tostring(descriptionInput) end
    if completionMessageInput ~= nil then draft.completionMessage = tostring(completionMessageInput) end
    if requireUndetectedInput ~= nil then draft.requireUndetected = (requireUndetectedInput == true) end
    if areaRadiusInput ~= nil and tonumber(areaRadiusInput) and tonumber(areaRadiusInput) > 0 then
        draft.areaRadius = tonumber(areaRadiusInput)
    end

    draft.targets = draft.targets or {}
    draft.discoveries = draft.discoveries or {}

    local hasTargets = #draft.targets > 0 and draft.targetX and draft.targetY
    local hasDiscoveries = #draft.discoveries > 0

    if not hasTargets and not hasDiscoveries then
        return nil, Addon.Locale:Get("ERR_MISSING_TARGET")
    end

    if hasTargets and (not draft.areaCenterX or not draft.areaCenterY) then
        draft.areaCenterX, draft.areaCenterY = self:ComputeOffsetCenter(draft.targetX, draft.targetY, draft.areaRadius)
    end

    local existing = draft.editingQuestId and self:GetQuestById(draft.editingQuestId) or nil
    local targetId = existing and existing.id or self.savedVars.nextId

    local cleanTitle = (draft.title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanTitle == "" then
        cleanTitle = Addon.Locale:Get("DEFAULT_QUEST_TITLE", targetId)
    end

    local cleanDesc = (draft.description or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cleanClue = (draft.clue or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cleanCompMsg = (draft.completionMessage or ""):gsub("^%s+", ""):gsub("%s+$", "")
    draft.clue = cleanClue
    draft.completionMessage = cleanCompMsg

    if existing then
        local prevProgress = {}
        for _, t in ipairs(existing.targets or {}) do
            prevProgress[t.name:lower()] = t.currentCount or 0
        end

        existing.title = cleanTitle
        existing.description = cleanDesc
        existing.clue = cleanClue
        existing.completionMessage = cleanCompMsg
        existing.targets = CloneTargetsList(draft.targets, prevProgress)
        existing.discoveries = CloneDiscoveriesList(draft.discoveries, false)
        existing.dialogues = CloneDialoguesList(draft.dialogues, cleanClue)
        existing.mapId = draft.mapId or 0
        existing.zoneId = draft.zoneId or 0
        existing.mapName = draft.mapName or ""
        existing.targetX = draft.targetX
        existing.targetY = draft.targetY
        existing.areaCenterX = draft.areaCenterX
        existing.areaCenterY = draft.areaCenterY
        existing.areaRadius = draft.areaRadius
        existing.hideMapArea = draft.hideMapArea and true or false
        local reqUndetected = draft.requireUndetected and true or false
        existing.requireUndetected = reqUndetected
        if not reqUndetected then
            existing.wasDetected = false
        end
        existing.failed = false
        existing.completed = AreAllObjectivesCompleted(existing.targets, existing.discoveries)

        if self._shareCodeCache then
            self._shareCodeCache[existing.id] = nil
        end
        if self._activeTargetCache and self._activeTargetCache.questId == existing.id then
            self:InvalidateActiveTargetCache()
        end

        self:ResetDraft()
        self:NotifyListeners("QUEST_UPDATED", existing)
        return existing
    end

    self.savedVars.nextId = targetId + 1

    local questData = {
        clue = cleanClue,
        completionMessage = draft.completionMessage,
        discoveries = CloneDiscoveriesList(draft.discoveries, false),
        dialogues = CloneDialoguesList(draft.dialogues),
        mapId = draft.mapId,
        zoneId = draft.zoneId,
        mapName = draft.mapName,
        targetX = draft.targetX,
        targetY = draft.targetY,
        areaCenterX = draft.areaCenterX,
        areaCenterY = draft.areaCenterY,
        areaRadius = draft.areaRadius,
        hideMapArea = draft.hideMapArea,
        requireUndetected = draft.requireUndetected,
    }

    local newQuest = BuildQuestRecord(
        targetId,
        cleanTitle,
        cleanDesc,
        CloneTargetsList(draft.targets),
        questData,
        Addon.Constants.QUEST_ROLE.PREPARED
    )

    table.insert(self.savedVars.quests, newQuest)
    if self._questById then
        self._questById[newQuest.id] = newQuest
    end

    self:ResetDraft()
    self:NotifyListeners("QUEST_CREATED", newQuest)
    return newQuest
end

function QuestRepository:ImportQuestFromCode(codeString, senderDisplayName)
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

    local importedTargets = {}
    for _, t in ipairs(decoded.targets or {}) do
        local cleanTName = self:NormalizeName(t.name)
        if cleanTName ~= "" then
            local hasLoc = (t.worldX ~= nil and t.worldZ ~= nil)
            local defaultRad = Addon.Constants.DISCOVERY_RADIUS.MEDIUM
            table.insert(importedTargets, {
                name = cleanTName,
                currentCount = 0,
                requiredCount = math.max(1, math.floor(tonumber(t.requiredCount) or 1)),
                targetX = decoded.targetX,
                targetY = decoded.targetY,
                zoneId = hasLoc and math.floor(tonumber(t.zoneId) or 0) or nil,
                worldX = hasLoc and tonumber(t.worldX) or nil,
                worldZ = hasLoc and tonumber(t.worldZ) or nil,
                radius = hasLoc and math.max(100, math.floor(tonumber(t.radius) or defaultRad)) or nil,
                locationRequired = (t.locationRequired == true),
                customMessage = type(t.customMessage) == "string" and t.customMessage or "",
            })
        end
    end

    decoded.discoveries = CloneDiscoveriesList(decoded.discoveries, false)
    decoded.dialogues = CloneDialoguesList(decoded.dialogues, decoded.clue)
    if type(senderDisplayName) == "string" and senderDisplayName ~= "" then
        decoded.senderDisplayName = senderDisplayName
    end

    local importedQuest = BuildQuestRecord(
        newId,
        cleanTitle,
        decoded.description or "",
        importedTargets,
        decoded,
        Addon.Constants.QUEST_ROLE.RECEIVED
    )

    table.insert(self.savedVars.quests, importedQuest)
    if self._questById then
        self._questById[importedQuest.id] = importedQuest
    end
    self.savedVars.activeQuestId = importedQuest.id
    self:InvalidateActiveTargetCache()

    self:NotifyListeners("QUEST_IMPORTED", importedQuest)
    return importedQuest
end

function QuestRepository:ExportQuestToCode(questId)
    local quest = self:GetQuestById(questId)
    if not quest then
        return nil
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

    local rawName = GetUnitName and GetUnitName("player") or ""
    local charName = rawName
    if zo_strformat and rawName ~= "" then
        charName = zo_strformat("<<C:1>>", rawName)
    end
    local ts = GetTimeStamp and GetTimeStamp() or 0

    local code, err = Addon.ShareCodec:EncodeCompletion(quest, charName, ts)
    if code then
        self._completionCodeCache[questId] = code
    end
    return code, err
end

function QuestRepository:ValidateCompletionCode(questId, codeString)
    local quest = self:GetQuestById(questId)
    if not quest then
        return false, "VALIDATE_ERR_INVALID_CODE"
    end
    return Addon.ShareCodec:ValidateCompletionForQuest(quest, codeString)
end

function QuestRepository:RecordMailDelivery(questId, senderDisplayName, validationResult)
    local quest = self:GetQuestById(questId)
    if not quest or type(validationResult) ~= "table" then
        return nil
    end
    quest.deliveries = quest.deliveries or {}
    local entry = {
        senderDisplayName = type(senderDisplayName) == "string" and senderDisplayName or "",
        characterName = validationResult.characterName or "",
        completedAt = tonumber(validationResult.completedAt) or 0,
        wasDetected = validationResult.wasDetected,
    }
    -- Avoid duplicate entries for same characterName + completedAt
    for _, existing in ipairs(quest.deliveries) do
        if existing.characterName == entry.characterName and existing.completedAt == entry.completedAt then
            return existing, false
        end
    end
    table.insert(quest.deliveries, entry)
    self:NotifyListeners("DELIVERY_RECORDED", { quest = quest, delivery = entry })
    return entry, true
end

function QuestRepository:MarkCompletionReported(questId)
    local quest = self:GetQuestById(questId)
    if not quest then return false end
    quest.completionReported = true
    self:NotifyListeners("COMPLETION_REPORTED", quest)
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

function QuestRepository:IsPreparedQuest(quest)
    return quest ~= nil and quest.role == Addon.Constants.QUEST_ROLE.PREPARED
end

function QuestRepository:GetAllQuests()
    if not self.savedVars then return {} end
    return self.savedVars.quests or {}
end

function QuestRepository:GetQuestsByRole(role)
    local result = {}
    for _, q in ipairs(self:GetAllQuests()) do
        if q.role == role then
            table.insert(result, q)
        end
    end
    return result
end

function QuestRepository:GetActiveAndAvailableQuests()
    local result = {}
    for _, q in ipairs(self:GetAllQuests()) do
        if not q.completed then
            table.insert(result, q)
        end
    end
    return result
end

function QuestRepository:GetCompletedQuests()
    local result = {}
    for _, q in ipairs(self:GetAllQuests()) do
        if q.completed then
            table.insert(result, q)
        end
    end
    return result
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

function QuestRepository:UpdateDraftTarget(index, fields, silent)
    local draft = self:GetDraft()
    local target = draft.targets and draft.targets[index]
    if not target or type(fields) ~= "table" then return nil end

    if fields.clearLocation then
        target.zoneId = nil
        target.worldX = nil
        target.worldZ = nil
        target.radius = nil
        target.locationRequired = false
    else
        if fields.zoneId ~= nil then target.zoneId = math.floor(tonumber(fields.zoneId) or 0) end
        if fields.worldX ~= nil then target.worldX = tonumber(fields.worldX) end
        if fields.worldZ ~= nil then target.worldZ = tonumber(fields.worldZ) end
        if fields.radius ~= nil then
            target.radius = math.max(100, math.floor(tonumber(fields.radius) or Addon.Constants.DISCOVERY_RADIUS.MEDIUM))
        end
        if fields.locationRequired ~= nil then
            target.locationRequired = (fields.locationRequired == true)
        end
    end

    if fields.customMessage ~= nil then
        target.customMessage = tostring(fields.customMessage)
    end

    if not silent then
        self:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return target
end

function QuestRepository:CaptureDraftTargetLocation(index, zoneId, worldX, worldZ, radius)
    if not worldX or not worldZ then return nil end
    local draft = self:GetDraft()
    local target = draft.targets and draft.targets[index]
    if not target then return nil end

    target.zoneId = math.floor(tonumber(zoneId) or 0)
    target.worldX = tonumber(worldX)
    target.worldZ = tonumber(worldZ)
    target.radius = math.max(100, math.floor(tonumber(radius) or target.radius or Addon.Constants.DISCOVERY_RADIUS.MEDIUM))
    self:NotifyListeners("DRAFT_UPDATED", draft)
    return target
end

function QuestRepository:ClearDraftTargetLocation(index)
    return self:UpdateDraftTarget(index, { clearLocation = true })
end

function QuestRepository:HasTargetLocation(target)
    return type(target) == "table" and target.worldX ~= nil and target.worldZ ~= nil
end

function QuestRepository:IsPlayerInsideTargetLocation(target, playerZoneId, playerWorldX, playerWorldZ)
    if not self:HasTargetLocation(target) then
        return true
    end
    if not playerWorldX or not playerWorldZ then
        return false
    end
    local targetZone = tonumber(target.zoneId) or 0
    local pZone = tonumber(playerZoneId) or 0
    if targetZone > 0 and pZone > 0 and targetZone ~= pZone then
        return false
    end
    local dx = playerWorldX - target.worldX
    local dz = playerWorldZ - target.worldZ
    local radius = tonumber(target.radius) or Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    return ((dx * dx) + (dz * dz)) <= (radius * radius)
end

function QuestRepository:GetActiveQuest()
    if not self.savedVars or not self.savedVars.activeQuestId then
        return nil
    end
    local q = self:GetQuestById(self.savedVars.activeQuestId)
    if q and not q.completed and not q.failed then
        return q
    end
    return nil
end

function QuestRepository:SetActiveQuest(questId)
    if questId == nil then
        self.savedVars.activeQuestId = nil
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("ACTIVE_QUEST_CHANGED", nil)
        return true
    end

    local q = self:GetQuestById(questId)
    if not q or q.completed or q.failed then
        return false
    end

    self.savedVars.activeQuestId = q.id
    self:InvalidateActiveTargetCache()
    self:NotifyListeners("ACTIVE_QUEST_CHANGED", q)
    return true
end

function QuestRepository:ResetQuest(questId)
    local q = self:GetQuestById(questId)
    if not q then return false end

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
    if self._completionCodeCache then
        self._completionCodeCache[questId] = nil
    end
    self.savedVars.activeQuestId = q.id
    self:InvalidateActiveTargetCache()
    self:NotifyListeners("QUEST_RESET", q)
    return true
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
    if not quest then return false end

    -- Si la misión tiene mapId o zoneId definidos (> 0), validar coincidencia de mapa o zona
    local mapMatches = true
    if (quest.mapId and quest.mapId > 0) and (playerMapId and playerMapId > 0) then
        mapMatches = (quest.mapId == playerMapId)
        if not mapMatches and (quest.zoneId and quest.zoneId > 0) and (playerZoneId and playerZoneId > 0) then
            mapMatches = (quest.zoneId == playerZoneId)
        end
    elseif (quest.zoneId and quest.zoneId > 0) and (playerZoneId and playerZoneId > 0) then
        mapMatches = (quest.zoneId == playerZoneId)
    end

    if not mapMatches then
        return false
    end

    -- Si tenemos coordenadas del jugador en el mismo mapa, verificar que esté dentro de un radio generoso del área de búsqueda
    if (quest.mapId and quest.mapId > 0 and playerMapId == quest.mapId) and playerX and playerY and quest.areaCenterX and quest.areaCenterY then
        local dx = playerX - quest.areaCenterX
        local dy = playerY - quest.areaCenterY
        local dist = math.sqrt((dx * dx) + (dy * dy))
        local toleranceRadius = (quest.areaRadius or 0.075) * 1.35
        return dist <= toleranceRadius
    end

    return true
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

function QuestRepository:RecordTargetEliminated(rawTargetName, playerContext, preMatchedQuest, preMatchedTarget)
    local activeQuest, matchedTarget = preMatchedQuest, preMatchedTarget
    if not activeQuest or not matchedTarget then
        activeQuest, matchedTarget = self:FindPendingTarget(rawTargetName)
    end
    if not activeQuest or not matchedTarget then
        return false, nil, false, nil
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
            return false, nil, false, nil
        end
    end

    local hasTargetLoc = self:HasTargetLocation(matchedTarget)
    local inTargetLoc = true
    if hasTargetLoc then
        local pZone = type(playerContext) == "table" and playerContext.worldZoneId or nil
        local pWX = type(playerContext) == "table" and playerContext.worldX or nil
        local pWZ = type(playerContext) == "table" and playerContext.worldZ or nil
        inTargetLoc = self:IsPlayerInsideTargetLocation(matchedTarget, pZone, pWX, pWZ)
    end

    if hasTargetLoc and matchedTarget.locationRequired and not inTargetLoc then
        activeQuest.failed = true
        if self.savedVars.activeQuestId == activeQuest.id then
            self.savedVars.activeQuestId = nil
        end
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("QUEST_FAILED", activeQuest)
        return false, activeQuest, false, matchedTarget, true, false
    end

    matchedTarget.currentCount = math.min(matchedTarget.requiredCount or 1, (matchedTarget.currentCount or 0) + 1)

    local customMsg = type(matchedTarget.customMessage) == "string"
        and matchedTarget.customMessage:gsub("^%s+", ""):gsub("%s+$", "")
        or ""
    local showCustomMessage = (customMsg ~= "") and (not hasTargetLoc or inTargetLoc)

    if AreAllObjectivesCompleted(activeQuest.targets, activeQuest.discoveries) then
        activeQuest.completed = true
        if self.savedVars.activeQuestId == activeQuest.id then
            self.savedVars.activeQuestId = nil
        end
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("QUEST_COMPLETED", activeQuest)
    else
        self:NotifyListeners("QUEST_PROGRESS", activeQuest)
    end

    return true, activeQuest, activeQuest.completed, matchedTarget, false, showCustomMessage
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

    if AreAllObjectivesCompleted(quest.targets, quest.discoveries) then
        quest.completed = true
        if self.savedVars.activeQuestId == quest.id then
            self.savedVars.activeQuestId = nil
        end
        self:InvalidateActiveTargetCache()
        self:NotifyListeners("DISCOVERY_TRIGGERED", quest)
        self:NotifyListeners("QUEST_COMPLETED", quest)
    else
        self:NotifyListeners("DISCOVERY_TRIGGERED", quest)
    end

    return true, quest, quest.completed, point
end

function QuestRepository:RecordPlayerDetected(playerContext)
    local activeQuest = self:GetActiveQuest()
    if not activeQuest or activeQuest.completed or activeQuest.failed or not activeQuest.requireUndetected or activeQuest.wasDetected then
        return false, nil
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
            return false, nil
        end
    end

    activeQuest.wasDetected = true
    self:NotifyListeners("QUEST_DETECTED", activeQuest)
    return true, activeQuest
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
