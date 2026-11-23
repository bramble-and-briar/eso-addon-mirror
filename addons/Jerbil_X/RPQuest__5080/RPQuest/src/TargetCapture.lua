-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.TargetCapture = {}
local TargetCapture = Addon.TargetCapture

function TargetCapture:GetPlayerMapContext(forceSync, includeMapName)
    local mapSceneShowing = SCENE_MANAGER:IsShowing("worldMap")
    if forceSync or not mapSceneShowing then
        if not DoesCurrentMapMatchMapForPlayerLocation() then
            SetMapToPlayerLocation()
        end
    end

    local mapId = GetCurrentMapId() or 0
    local zoneIndex = GetUnitZoneIndex("player") or GetCurrentMapZoneIndex() or 0
    local zoneId = (zoneIndex and zoneIndex > 0 and GetZoneId(zoneIndex)) or 0
    local mapName = (includeMapName ~= false and GetMapName()) or ""
    local normX, normY = 0.5, 0.5
    local x, y = GetMapPlayerPosition("player")
    if x and y then
        normX = x
        normY = y
    end

    return {
        mapId = mapId,
        zoneId = zoneId,
        mapName = mapName,
        x = normX,
        y = normY,
    }
end

function TargetCapture:ValidateReticleTarget()
    if not DoesUnitExist("reticleover") then
        return false, Addon.Locale:Get("ALERT_NO_RETICLE_TARGET")
    end

    if IsUnitPlayer("reticleover") then
        return false, Addon.Locale:Get("ALERT_INVALID_TARGET_PLAYER")
    end

    if IsUnitDead("reticleover") then
        return false, Addon.Locale:Get("ALERT_INVALID_TARGET_DEAD")
    end

    local reaction = GetUnitReaction("reticleover")
    if reaction == UNIT_REACTION_PLAYER_ALLY
        or reaction == UNIT_REACTION_COMPANION
        or reaction == UNIT_REACTION_NPC_ALLY then
        return false, Addon.Locale:Get("ALERT_INVALID_TARGET_FRIENDLY")
    end
    if not IsUnitAttackable("reticleover") and reaction ~= UNIT_REACTION_HOSTILE then
        return false, Addon.Locale:Get("ALERT_INVALID_TARGET_FRIENDLY")
    end

    local rawName = GetUnitName("reticleover") or ""
    local cleanName = Addon.QuestRepository:NormalizeName(rawName)
    if cleanName == "" then
        return false, Addon.Locale:Get("ALERT_NO_RETICLE_TARGET")
    end

    return true, cleanName
end

function TargetCapture:CaptureFromReticle()
    local isValid, nameOrErr = self:ValidateReticleTarget()
    if not isValid then
        Addon.Announcements:ShowAlert(nameOrErr, true)
        return nil, nameOrErr
    end

    local ctx = self:GetPlayerMapContext(true)
    local draft = Addon.QuestRepository:SetDraftCapturedTarget({
        targetName = nameOrErr,
        mapId = ctx.mapId,
        zoneId = ctx.zoneId,
        mapName = ctx.mapName,
        targetX = ctx.x,
        targetY = ctx.y,
    })

    if draft then
        local locText = (draft.mapName ~= "" and draft.mapName) or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
        local displayTarget = draft.lastCapturedDisplay or (draft.targets and draft.targets[1] and draft.targets[1].name) or ""
        local msg = Addon.Locale:Get("ALERT_TARGET_CAPTURED", displayTarget, locText)
        Addon.Announcements:ShowAlert(msg, false)
    end

    return draft
end

function TargetCapture:CaptureDiscoveryPoint(customMessage, customRadius)
    local zoneId, worldX, worldY, worldZ = GetUnitWorldPosition("player")
    if not zoneId or zoneId == 0 or not worldX or not worldZ then
        local err = Addon.Locale:Get("ALERT_DISCOVERY_INVALID_POS")
        Addon.Announcements:ShowAlert(err, true)
        return nil, err
    end

    local ctx = self:GetPlayerMapContext(true)
    local draft = Addon.QuestRepository:GetDraft()
    local rawMsg = customMessage
    if type(rawMsg) ~= "string" or rawMsg == "" then
        rawMsg = draft.discoveryMessage or ""
    end
    local cleanMsg = rawMsg:gsub("^%s+", ""):gsub("%s+$", "")
    if cleanMsg == "" then
        local nextIdx = #(draft.discoveries or {}) + 1
        cleanMsg = Addon.Locale:Get("DEFAULT_DISCOVERY_MSG", nextIdx)
    end

    local radius = tonumber(customRadius) or draft.discoveryRadius or Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    local updatedDraft, count = Addon.QuestRepository:AddDraftDiscoveryPoint({
        zoneId = zoneId,
        worldX = worldX,
        worldY = worldY or 0,
        worldZ = worldZ,
        mapId = ctx.mapId,
        mapName = ctx.mapName,
        x = ctx.x,
        y = ctx.y,
        radius = radius,
        message = cleanMsg,
    })

    if updatedDraft then
        local locText = (ctx.mapName ~= "" and ctx.mapName) or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
        local radiusMeters = math.floor(radius / 100)
        local alertMsg = Addon.Locale:Get("ALERT_DISCOVERY_CAPTURED", count or 1, locText, radiusMeters)
        Addon.Announcements:ShowAlert(alertMsg, false)
    end

    return updatedDraft, count
end
