-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.QuestDraftStore = {}
local QuestDraftStore = Addon.QuestDraftStore

function QuestDraftStore:NormalizeStealthMode(value, legacyBool)
    local modes = Addon.Constants and Addon.Constants.STEALTH_MODE
    local disabled = (modes and modes.DISABLED) or "disabled"
    local optional = (modes and modes.OPTIONAL) or "optional"
    local required = (modes and modes.REQUIRED) or "required"
    if value == disabled or value == optional or value == required then
        return value
    end
    if type(value) == "boolean" then
        return value and optional or disabled
    end
    if legacyBool == true then
        return optional
    end
    return disabled
end

function QuestDraftStore:CreateDefaultDraft()
    return {
        editingQuestId = nil,
        title = "",
        description = "",
        recipientAccount = "",
        recipientCharacterName = "",
        clue = "",
        completionMessage = "",
        targets = {},
        discoveries = {},
        dialogues = {},
        discoveryRadius = Addon.Constants.DISCOVERY_RADIUS.MEDIUM,
        discoveryMessage = "",
        lastCapturedDisplay = nil,
        mapId = 0,
        mapType = nil,
        zoneId = 0,
        mapName = "",
        targetX = nil,
        targetY = nil,
        areaCenterX = nil,
        areaCenterY = nil,
        areaRadius = Addon.Constants.AREA_RADIUS.MEDIUM,
        recommendHideMapAreas = true,
        stealthMode = Addon.Constants.STEALTH_MODE.DISABLED,
    }
end

function QuestDraftStore:EnsureDraft(draft)
    if not draft then
        return self:CreateDefaultDraft()
    end
    draft.targets = draft.targets or {}
    draft.discoveries = draft.discoveries or {}
    draft.dialogues = draft.dialogues or {}
    if draft.recommendHideMapAreas == nil then
        if draft.hideMapArea ~= nil then
            draft.recommendHideMapAreas = (draft.hideMapArea == true)
        else
            draft.recommendHideMapAreas = true
        end
    end
    draft.hideMapArea = nil
    draft.stealthMode = self:NormalizeStealthMode(draft.stealthMode, draft.requireUndetected)
    draft.requireUndetected = nil
    return draft
end

function QuestDraftStore:CloneDialoguesList(dialogues, fallbackClue)
    local out = {}
    if type(dialogues) ~= "table" then return out end
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    local fallback = type(fallbackClue) == "string" and fallbackClue or ""
    for _, d in ipairs(dialogues) do
        if #out >= maxNpcs then break end
        if type(d) == "table" and type(d.npcName) == "string" and d.npcName ~= "" then
            local cleanName = Addon.QuestRepository:NormalizeName(d.npcName)
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

function QuestDraftStore:CloneDiscoveriesList(discoveries, preserveDiscovered)
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

function QuestDraftStore:CloneTargetsList(targets, existingTargetsByName)
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
            local tAreaRad = tonumber(t.areaRadius)
            table.insert(out, {
                name = t.name,
                currentCount = cur,
                requiredCount = req,
                targetX = t.targetX,
                targetY = t.targetY,
                areaCenterX = tonumber(t.areaCenterX),
                areaCenterY = tonumber(t.areaCenterY),
                areaRadius = (tAreaRad and tAreaRad > 0) and tAreaRad or nil,
                zoneId = hasLoc and math.floor(tonumber(t.zoneId) or 0) or nil,
                worldX = hasLoc and tonumber(t.worldX) or nil,
                worldZ = hasLoc and tonumber(t.worldZ) or nil,
                radius = hasLoc and math.max(100, math.floor(tonumber(t.radius) or defaultRad)) or nil,
                locationRequired = hasLoc and (t.locationRequired == true) or false,
                optional = (t.optional == true),
                customMessage = type(t.customMessage) == "string" and t.customMessage or "",
                customMessageInLocation = type(t.customMessageInLocation) == "string" and t.customMessageInLocation or "",
                customMessageOutsideLocation = type(t.customMessageOutsideLocation) == "string" and t.customMessageOutsideLocation or "",
            })
        end
    end
    return out
end

function QuestDraftStore:GetDraft(repo)
    if not repo.savedVars then
        repo:Initialize()
    end
    repo.savedVars.draft = self:EnsureDraft(repo.savedVars.draft)
    return repo.savedVars.draft
end

function QuestDraftStore:ResetDraft(repo)
    if not repo.savedVars then
        repo:Initialize()
    end
    repo.savedVars.draft = self:CreateDefaultDraft()
    repo:NotifyListeners("DRAFT_UPDATED", repo.savedVars.draft)
    return repo.savedVars.draft
end

function QuestDraftStore:ClearDraftTargets(repo)
    local draft = self:GetDraft(repo)
    draft.targets = {}
    draft.lastCapturedDisplay = nil
    draft.targetX = nil
    draft.targetY = nil
    draft.worldX = nil
    draft.worldY = nil
    draft.worldZ = nil
    draft.areaCenterX = nil
    draft.areaCenterY = nil
    if #draft.discoveries == 0 then
        draft.mapId = 0
        draft.zoneId = 0
        draft.mapName = ""
    end
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

local function RecalculateDraftTargetCentroid(draft)
    local sumX, sumY, countCoords = 0, 0, 0
    for _, entry in ipairs(draft.targets or {}) do
        if entry.targetX and entry.targetY then
            sumX = sumX + entry.targetX
            sumY = sumY + entry.targetY
            countCoords = countCoords + 1
        end
    end
    if countCoords > 0 then
        draft.targetX = sumX / countCoords
        draft.targetY = sumY / countCoords
        local firstTarget = draft.targets[1]
        draft.areaCenterX = firstTarget and firstTarget.areaCenterX or draft.areaCenterX
        draft.areaCenterY = firstTarget and firstTarget.areaCenterY or draft.areaCenterY
    else
        draft.targetX = nil
        draft.targetY = nil
        draft.worldX = nil
        draft.worldY = nil
        draft.worldZ = nil
        draft.areaCenterX = nil
        draft.areaCenterY = nil
    end
end

function QuestDraftStore:RemoveDraftTarget(repo, index)
    local draft = self:GetDraft(repo)
    if not draft.targets or not draft.targets[index] then
        return nil
    end
    table.remove(draft.targets, index)
    if #draft.targets == 0 then
        draft.lastCapturedDisplay = nil
        RecalculateDraftTargetCentroid(draft)
        if #(draft.discoveries or {}) == 0 then
            draft.mapId = 0
            draft.zoneId = 0
            draft.mapName = ""
        end
    else
        draft.lastCapturedDisplay = repo:FormatTargetEntry(draft.targets[#draft.targets])
        RecalculateDraftTargetCentroid(draft)
    end
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestDraftStore:AddDraftDiscoveryPoint(repo, data)
    if type(data) ~= "table" or not data.worldX or not data.worldZ then
        return nil
    end
    local draft = self:GetDraft(repo)
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
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return draft, #draft.discoveries
end

function QuestDraftStore:ClearDraftDiscoveries(repo)
    local draft = self:GetDraft(repo)
    draft.discoveries = {}
    if #(draft.targets or {}) == 0 then
        draft.mapId = 0
        draft.zoneId = 0
        draft.mapName = ""
    end
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestDraftStore:UpdateDraftDiscoveryPoint(repo, index, fields, silent)
    local draft = self:GetDraft(repo)
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
        repo:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return point
end

function QuestDraftStore:RemoveDraftDiscoveryPoint(repo, index)
    local draft = self:GetDraft(repo)
    if not draft.discoveries or not draft.discoveries[index] then
        return nil
    end
    table.remove(draft.discoveries, index)
    if #draft.discoveries == 0 and #(draft.targets or {}) == 0 then
        draft.mapId = 0
        draft.zoneId = 0
        draft.mapName = ""
    end
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestDraftStore:AddDraftDialogue(repo, npcName, zoneId, responseText, clueText)
    local draft = self:GetDraft(repo)
    draft.dialogues = draft.dialogues or {}
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    if #draft.dialogues >= maxNpcs then
        return nil, Addon.Locale:Get("ALERT_DIALOGUE_LIMIT", maxNpcs)
    end

    local cleanName = repo:NormalizeName(npcName)
    if cleanName == "" then
        return nil, Addon.Locale:Get("ALERT_DIALOGUE_NO_LAST_NPC")
    end

    local z = math.floor(tonumber(zoneId) or 0)
    local lowerName = cleanName:lower()
    for _, existing in ipairs(draft.dialogues) do
        if repo:NormalizeName(existing.npcName):lower() == lowerName and ((existing.zoneId or 0) == z or z == 0 or (existing.zoneId or 0) == 0) then
            return nil, Addon.Locale:Get("ALERT_DIALOGUE_DUPLICATE")
        end
    end

    table.insert(draft.dialogues, {
        npcName = cleanName,
        zoneId = z,
        clue = type(clueText) == "string" and clueText or "",
        response = type(responseText) == "string" and responseText or "",
    })
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return draft, #draft.dialogues
end

function QuestDraftStore:AddDraftDialogueFromLastNpc(repo, responseText, clueText)
    local lastNpc = repo:GetLastInteractedNpc()
    if not lastNpc or not lastNpc.name or lastNpc.name == "" then
        return nil, Addon.Locale:Get("ALERT_DIALOGUE_NO_LAST_NPC")
    end
    return self:AddDraftDialogue(repo, lastNpc.name, lastNpc.zoneId, responseText, clueText)
end

function QuestDraftStore:UpdateDraftDialogue(repo, index, fields, silent)
    local draft = self:GetDraft(repo)
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
        repo:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return entry
end

function QuestDraftStore:RemoveDraftDialogue(repo, index)
    local draft = self:GetDraft(repo)
    if not draft.dialogues or not draft.dialogues[index] then
        return nil
    end
    table.remove(draft.dialogues, index)
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestDraftStore:ClearDraftDialogues(repo)
    local draft = self:GetDraft(repo)
    draft.dialogues = {}
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return draft
end

function QuestDraftStore:LoadQuestIntoDraft(repo, questId)
    local quest = repo:GetQuestById(questId)
    if not quest then return nil end
    if not repo:IsPreparedQuest(quest) then
        return nil, Addon.Locale:Get("ERR_CANNOT_EDIT_RECEIVED")
    end
    if quest.needsMigration then
        return nil, Addon.Locale:Get("ERR_QUEST_NEEDS_MIGRATION")
    end

    repo.savedVars.draft = {
        editingQuestId = quest.id,
        title = quest.title or "",
        description = quest.description or "",
        recipientAccount = quest.recipientAccount or "",
        recipientCharacterName = quest.recipientCharacterName or "",
        clue = quest.clue or "",
        completionMessage = quest.completionMessage or "",
        targets = self:CloneTargetsList(quest.targets),
        discoveries = self:CloneDiscoveriesList(quest.discoveries, false),
        dialogues = self:CloneDialoguesList(quest.dialogues, quest.clue),
        discoveryRadius = Addon.Constants.DISCOVERY_RADIUS.MEDIUM,
        discoveryMessage = "",
        lastCapturedDisplay = nil,
        mapId = quest.mapId or 0,
        zoneId = quest.zoneId or 0,
        mapName = quest.mapName or "",
        targetX = quest.targetX,
        targetY = quest.targetY,
        worldX = quest.worldX,
        worldY = quest.worldY,
        worldZ = quest.worldZ,
        areaCenterX = (quest.targets and quest.targets[1] and quest.targets[1].areaCenterX) or quest.areaCenterX,
        areaCenterY = (quest.targets and quest.targets[1] and quest.targets[1].areaCenterY) or quest.areaCenterY,
        areaRadius = (quest.targets and quest.targets[1] and quest.targets[1].areaRadius) or quest.areaRadius or Addon.Constants.AREA_RADIUS.MEDIUM,
        recommendHideMapAreas = (quest.recommendHideMapAreas ~= nil) and (quest.recommendHideMapAreas == true) or (quest.hideMapArea == true),
        stealthMode = self:NormalizeStealthMode(quest.stealthMode, quest.requireUndetected),
    }
    repo:NotifyListeners("DRAFT_UPDATED", repo.savedVars.draft)
    return repo.savedVars.draft
end

function QuestDraftStore:UpdateDraftFields(repo, fields, silent)
    local draft = self:GetDraft(repo)
    if type(fields) ~= "table" then return draft end

    if fields.title ~= nil then draft.title = tostring(fields.title) end
    if fields.description ~= nil then draft.description = tostring(fields.description) end
    if fields.recipientAccount ~= nil then draft.recipientAccount = tostring(fields.recipientAccount) end
    if fields.recipientCharacterName ~= nil then draft.recipientCharacterName = tostring(fields.recipientCharacterName) end
    if fields.clue ~= nil then draft.clue = tostring(fields.clue) end
    if fields.completionMessage ~= nil then draft.completionMessage = tostring(fields.completionMessage) end
    if fields.recommendHideMapAreas ~= nil then
        draft.recommendHideMapAreas = (fields.recommendHideMapAreas == true)
    elseif fields.hideMapArea ~= nil then
        draft.recommendHideMapAreas = (fields.hideMapArea == true)
    end
    if fields.discoveryMessage ~= nil then draft.discoveryMessage = tostring(fields.discoveryMessage) end
    if fields.discoveryRadius ~= nil then
        local newDiscRadius = tonumber(fields.discoveryRadius)
        if newDiscRadius and newDiscRadius >= 100 then
            draft.discoveryRadius = math.floor(newDiscRadius)
        end
    end
    if fields.stealthMode ~= nil then
        draft.stealthMode = self:NormalizeStealthMode(fields.stealthMode)
    elseif fields.requireUndetected ~= nil then
        draft.stealthMode = self:NormalizeStealthMode(fields.requireUndetected)
    end
    if fields.areaRadius ~= nil then
        local newRadius = tonumber(fields.areaRadius) or draft.areaRadius
        if newRadius > 0 then
            draft.areaRadius = newRadius
            local effectiveRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(newRadius, draft.mapType)
            for _, t in ipairs(draft.targets or {}) do
                t.areaRadius = newRadius
                if t.targetX and t.targetY then
                    t.areaCenterX, t.areaCenterY = repo:ComputeOffsetCenter(t.targetX, t.targetY, effectiveRadius)
                end
            end
            if draft.targetX and draft.targetY then
                draft.areaCenterX, draft.areaCenterY = repo:ComputeOffsetCenter(draft.targetX, draft.targetY, effectiveRadius)
            end
        end
    end
    if not silent then
        repo:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return draft
end

function QuestDraftStore:SetDraftCapturedTarget(repo, captureData)
    if type(captureData) ~= "table" then return nil end
    local cleanName = repo:NormalizeName(captureData.targetName)
    if cleanName == "" then return nil end

    local draft = self:GetDraft(repo)
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

    local radius = (matchedEntry and matchedEntry.areaRadius) or draft.areaRadius or Addon.Constants.AREA_RADIUS.MEDIUM
    local effectiveTargetRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(radius, captureData.mapType or draft.mapType)
    local tAreaCenterX, tAreaCenterY = repo:ComputeOffsetCenter(tx, ty, effectiveTargetRadius)

    if matchedEntry then
        matchedEntry.requiredCount = math.min(999, (tonumber(matchedEntry.requiredCount) or 1) + 1)
        matchedEntry.targetX = tx
        matchedEntry.targetY = ty
        matchedEntry.areaRadius = radius
        matchedEntry.areaCenterX = tAreaCenterX
        matchedEntry.areaCenterY = tAreaCenterY
    else
        matchedEntry = {
            name = cleanName,
            currentCount = 0,
            requiredCount = 1,
            targetX = tx,
            targetY = ty,
            areaCenterX = tAreaCenterX,
            areaCenterY = tAreaCenterY,
            areaRadius = radius,
            optional = false,
            customMessage = "",
            customMessageInLocation = "",
            customMessageOutsideLocation = "",
        }
        table.insert(draft.targets, matchedEntry)
    end

    draft.lastCapturedDisplay = repo:FormatTargetEntry(matchedEntry)
    draft.mapId = tonumber(captureData.mapId) or draft.mapId or 0
    draft.mapType = captureData.mapType or draft.mapType
    draft.zoneId = tonumber(captureData.zoneId) or draft.zoneId or 0
    draft.mapName = tostring(captureData.mapName or draft.mapName or "")
    if captureData.worldX ~= nil and captureData.worldZ ~= nil then
        draft.worldX = tonumber(captureData.worldX)
        draft.worldY = tonumber(captureData.worldY) or 0
        draft.worldZ = tonumber(captureData.worldZ)
    end

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

    local questRadius = draft.areaRadius or Addon.Constants.AREA_RADIUS.MEDIUM
    draft.areaRadius = questRadius
    local effectiveRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(questRadius, draft.mapType)
    draft.areaCenterX, draft.areaCenterY = repo:ComputeOffsetCenter(draft.targetX, draft.targetY, effectiveRadius)

    repo:NotifyListeners("DRAFT_TARGET_CAPTURED", draft)
    return draft
end

function QuestDraftStore:UpdateDraftTarget(repo, index, fields, silent)
    local draft = self:GetDraft(repo)
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

    if fields.optional ~= nil then
        target.optional = (fields.optional == true)
    end

    if fields.customMessage ~= nil then
        target.customMessage = tostring(fields.customMessage)
    end
    if fields.customMessageInLocation ~= nil then
        target.customMessageInLocation = tostring(fields.customMessageInLocation)
    end
    if fields.customMessageOutsideLocation ~= nil then
        target.customMessageOutsideLocation = tostring(fields.customMessageOutsideLocation)
    end
    if fields.areaRadius ~= nil then
        local newAreaRad = tonumber(fields.areaRadius)
        if newAreaRad and newAreaRad > 0 then
            target.areaRadius = newAreaRad
            if target.targetX and target.targetY then
                local effectiveRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(newAreaRad, draft.mapType)
                target.areaCenterX, target.areaCenterY = repo:ComputeOffsetCenter(target.targetX, target.targetY, effectiveRadius)
            end
        end
    end
    if fields.areaCenterX ~= nil then
        target.areaCenterX = tonumber(fields.areaCenterX)
    end
    if fields.areaCenterY ~= nil then
        target.areaCenterY = tonumber(fields.areaCenterY)
    end

    if not silent then
        repo:NotifyListeners("DRAFT_UPDATED", draft)
    end
    return target
end

function QuestDraftStore:CaptureDraftTargetLocation(repo, index, zoneId, worldX, worldZ, radius)
    if not worldX or not worldZ then return nil end
    local draft = self:GetDraft(repo)
    local target = draft.targets and draft.targets[index]
    if not target then return nil end

    target.zoneId = math.floor(tonumber(zoneId) or 0)
    target.worldX = tonumber(worldX)
    target.worldZ = tonumber(worldZ)
    target.radius = math.max(100, math.floor(tonumber(radius) or target.radius or Addon.Constants.DISCOVERY_RADIUS.MEDIUM))
    repo:NotifyListeners("DRAFT_UPDATED", draft)
    return target
end

function QuestDraftStore:ClearDraftTargetLocation(repo, index)
    return self:UpdateDraftTarget(repo, index, { clearLocation = true })
end

local function BuildNormalizedDraftFields(repo, draft, fallbackTitle)
    local cleanTitle = (draft.title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanTitle == "" then
        cleanTitle = fallbackTitle
    end

    local fields = {
        title = cleanTitle,
        description = (draft.description or ""):gsub("^%s+", ""):gsub("%s+$", ""),
        clue = (draft.clue or ""):gsub("^%s+", ""):gsub("%s+$", ""),
        completionMessage = (draft.completionMessage or ""):gsub("^%s+", ""):gsub("%s+$", ""),
        recipientAccount = repo:NormalizeAccountName(draft.recipientAccount),
        recipientCharacterName = repo:NormalizeCharacterName(draft.recipientCharacterName),
    }
    draft.clue = fields.clue
    draft.completionMessage = fields.completionMessage
    draft.recipientAccount = fields.recipientAccount
    draft.recipientCharacterName = fields.recipientCharacterName
    return fields
end

local function ApplyDraftFieldsToQuest(store, repo, existing, draft, fields)
    local prevProgress = {}
    for _, t in ipairs(existing.targets or {}) do
        prevProgress[t.name:lower()] = t.currentCount or 0
    end

    existing.title = fields.title
    existing.description = fields.description
    existing.recipientAccount = fields.recipientAccount
    existing.recipientCharacterName = (fields.recipientCharacterName ~= "") and fields.recipientCharacterName or nil
    if type(existing.senderCharacterName) ~= "string" or existing.senderCharacterName == "" then
        existing.senderCharacterName = repo:GetPlayerCharacterName()
    end
    if existing.sentTo and existing.sentTo:lower() ~= fields.recipientAccount:lower() then
        existing.sentTo = nil
        existing.sentAt = nil
        existing.lastResult = nil
        existing.deliveries = {}
    end
    existing.clue = fields.clue
    existing.completionMessage = fields.completionMessage
    existing.targets = store:CloneTargetsList(draft.targets, prevProgress)
    existing.discoveries = store:CloneDiscoveriesList(draft.discoveries, false)
    existing.dialogues = store:CloneDialoguesList(draft.dialogues, fields.clue)
    existing.mapId = draft.mapId or 0
    existing.zoneId = draft.zoneId or 0
    existing.mapName = draft.mapName or ""
    existing.targetX = draft.targetX
    existing.targetY = draft.targetY
    existing.worldX = draft.worldX
    existing.worldY = draft.worldY
    existing.worldZ = draft.worldZ
    existing.areaCenterX = nil
    existing.areaCenterY = nil
    existing.areaRadius = nil
    existing.hideMapArea = nil
    existing.recommendHideMapAreas = (draft.recommendHideMapAreas ~= false)
    local stealthMode = store:NormalizeStealthMode(draft.stealthMode)
    existing.stealthMode = stealthMode
    existing.requireUndetected = nil
    if stealthMode == Addon.Constants.STEALTH_MODE.DISABLED then
        existing.wasDetected = false
    end
    existing.failed = false
    existing.completed = repo:AreAllObjectivesCompleted(existing.targets, existing.discoveries)

    if repo._shareCodeCache then
        repo._shareCodeCache[existing.id] = nil
    end
    if repo._activeTargetCache and repo._activeTargetCache.questId == existing.id then
        repo:InvalidateActiveTargetCache()
    end
end

local function ApplyDraftToExistingQuest(store, repo, existing, draft, fields)
    ApplyDraftFieldsToQuest(store, repo, existing, draft, fields)
    store:ResetDraft(repo)
    repo:NotifyListeners("QUEST_UPDATED", existing)
    return existing
end

function QuestDraftStore:CreateNewPreparedDraft(repo)
    if not repo.savedVars then
        repo:Initialize()
    end
    local targetId = repo.savedVars.nextId
    repo.savedVars.nextId = targetId + 1

    local title = Addon.Locale:Get("DEFAULT_NEW_QUEST_TITLE")
    local newQuest = repo:BuildQuestRecord(
        targetId,
        title,
        "",
        {},
        { senderCharacterName = repo:GetPlayerCharacterName() },
        Addon.Constants.QUEST_ROLE.PREPARED
    )

    table.insert(repo.savedVars.quests, newQuest)
    if repo._questById then
        repo._questById[newQuest.id] = newQuest
    end

    self:LoadQuestIntoDraft(repo, newQuest.id)
    repo:NotifyListeners("QUEST_DRAFT_CREATED", newQuest)
    return newQuest
end

function QuestDraftStore:CommitDraftChanges(repo)
    local draft = self:GetDraft(repo)
    local existing = draft.editingQuestId and repo:GetQuestById(draft.editingQuestId) or nil
    if not existing or not repo:IsPreparedQuest(existing) then
        return nil
    end

    draft.targets = draft.targets or {}
    draft.discoveries = draft.discoveries or {}
    if #draft.targets > 0 and draft.targetX and draft.targetY and (not draft.areaCenterX or not draft.areaCenterY) then
        local effectiveRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(draft.areaRadius, draft.mapType)
        draft.areaCenterX, draft.areaCenterY = repo:ComputeOffsetCenter(draft.targetX, draft.targetY, effectiveRadius)
    end

    local fallbackTitle = Addon.Locale:Get("DEFAULT_NEW_QUEST_TITLE")
    local fields = BuildNormalizedDraftFields(repo, draft, fallbackTitle)
    ApplyDraftFieldsToQuest(self, repo, existing, draft, fields)
    return existing
end

local function CreateQuestFromDraft(store, repo, targetId, draft, fields)
    repo.savedVars.nextId = targetId + 1

    local questData = {
        senderCharacterName = repo:GetPlayerCharacterName(),
        recipientAccount = fields.recipientAccount,
        recipientCharacterName = fields.recipientCharacterName,
        clue = fields.clue,
        completionMessage = draft.completionMessage,
        discoveries = store:CloneDiscoveriesList(draft.discoveries, false),
        dialogues = store:CloneDialoguesList(draft.dialogues),
        mapId = draft.mapId,
        zoneId = draft.zoneId,
        mapName = draft.mapName,
        targetX = draft.targetX,
        targetY = draft.targetY,
        worldX = draft.worldX,
        worldY = draft.worldY,
        worldZ = draft.worldZ,
        recommendHideMapAreas = (draft.recommendHideMapAreas ~= false),
        stealthMode = store:NormalizeStealthMode(draft.stealthMode),
    }

    local newQuest = repo:BuildQuestRecord(
        targetId,
        fields.title,
        fields.description,
        store:CloneTargetsList(draft.targets),
        questData,
        Addon.Constants.QUEST_ROLE.PREPARED
    )

    table.insert(repo.savedVars.quests, newQuest)
    if repo._questById then
        repo._questById[newQuest.id] = newQuest
    end

    store:ResetDraft(repo)
    repo:NotifyListeners("QUEST_CREATED", newQuest)
    return newQuest
end

function QuestDraftStore:SaveDraft(repo, titleInput, descriptionInput, areaRadiusInput, completionMessageInput, stealthModeInput, recipientAccountInput, recipientCharacterNameInput)
    local draft = self:GetDraft(repo)

    if titleInput ~= nil then draft.title = tostring(titleInput) end
    if descriptionInput ~= nil then draft.description = tostring(descriptionInput) end
    if recipientAccountInput ~= nil then draft.recipientAccount = tostring(recipientAccountInput) end
    if recipientCharacterNameInput ~= nil then draft.recipientCharacterName = tostring(recipientCharacterNameInput) end
    if completionMessageInput ~= nil then draft.completionMessage = tostring(completionMessageInput) end
    if stealthModeInput ~= nil then draft.stealthMode = self:NormalizeStealthMode(stealthModeInput) end
    if areaRadiusInput ~= nil and tonumber(areaRadiusInput) and tonumber(areaRadiusInput) > 0 then
        local newRad = tonumber(areaRadiusInput)
        draft.areaRadius = newRad
        local effectiveRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(newRad, draft.mapType)
        for _, t in ipairs(draft.targets or {}) do
            t.areaRadius = newRad
            if t.targetX and t.targetY then
                t.areaCenterX, t.areaCenterY = repo:ComputeOffsetCenter(t.targetX, t.targetY, effectiveRadius)
            end
        end
    end

    draft.targets = draft.targets or {}
    draft.discoveries = draft.discoveries or {}

    local defaultAreaRad = draft.areaRadius or Addon.Constants.AREA_RADIUS.MEDIUM
    for _, t in ipairs(draft.targets) do
        if not t.areaRadius or t.areaRadius <= 0 then
            t.areaRadius = defaultAreaRad
        end
        if t.targetX and t.targetY and (not t.areaCenterX or not t.areaCenterY) then
            local effectiveRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(t.areaRadius, draft.mapType)
            t.areaCenterX, t.areaCenterY = repo:ComputeOffsetCenter(t.targetX, t.targetY, effectiveRadius)
        end
    end

    local hasTargets = #draft.targets > 0 and draft.targetX and draft.targetY

    if hasTargets and (not draft.areaCenterX or not draft.areaCenterY) then
        local effectiveRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(draft.areaRadius, draft.mapType)
        draft.areaCenterX, draft.areaCenterY = repo:ComputeOffsetCenter(draft.targetX, draft.targetY, effectiveRadius)
    end

    local existing = draft.editingQuestId and repo:GetQuestById(draft.editingQuestId) or nil
    local targetId = existing and existing.id or repo.savedVars.nextId
    local fields = BuildNormalizedDraftFields(repo, draft, Addon.Locale:Get("DEFAULT_QUEST_TITLE", targetId))

    if existing then
        return ApplyDraftToExistingQuest(self, repo, existing, draft, fields)
    end

    return CreateQuestFromDraft(self, repo, targetId, draft, fields)
end
