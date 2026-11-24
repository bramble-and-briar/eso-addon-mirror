-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.WorldMapArea = {}
local WorldMapArea = Addon.WorldMapArea

local PIN_TYPE_STRING = Addon.Constants.UI.PIN_TYPE_STRING
local LOCATION_PIN_TYPE_STRING = Addon.Constants.UI.LOCATION_PIN_TYPE_STRING
local ZOOM_OUT_PIN_TYPE_STRING = Addon.Constants.UI.ZOOM_OUT_PIN_TYPE_STRING
local MAP_LISTENER_NAME = "RPQuest_WorldMapArea"
local DRAFT_PIN_TAG = "__RPQUEST_DRAFT__"

local function IsDraftPinTag(questId, draft)
    if questId == DRAFT_PIN_TAG then
        return true
    end
    if draft and draft.editingQuestId and questId == draft.editingQuestId then
        return true
    end
    return false
end

local function GetWorldMapPinManager()
    local fn = _G["ZO_WorldMap_GetPinManager"]
    if type(fn) == "function" then
        return fn()
    end
    return nil
end

local function IsMapSceneShowing()
    return SCENE_MANAGER:IsShowing("worldMap") or SCENE_MANAGER:IsShowing("gamepad_worldMap")
end

local function RegisterMapSceneCallbacks(self, scene)
    if not scene or not scene.RegisterCallback then
        return
    end
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
            if self._pinsDirty then
                self:RefreshPins()
            end
        elseif newState == SCENE_HIDDEN then
            self.previewQuestId = nil
        end
    end)
end

local function SetWorldMapToId(mapId)
    if not mapId or mapId <= 0 then
        return
    end
    WORLD_MAP_MANAGER:SetMapById(mapId)
end

local function OpenWorldMapScene()
    if IsMapSceneShowing() then
        return
    end
    if IsInGamepadPreferredMode() then
        SCENE_MANAGER:Push("gamepad_worldMap")
    else
        MAIN_MENU_KEYBOARD:ShowCategory(MENU_CATEGORY_MAP)
    end
end

function WorldMapArea:Initialize()
    if self.isInitialized then return end

    local pinManager = GetWorldMapPinManager()
    if not pinManager or not pinManager.AddCustomPin then
        return
    end

    local pinLayoutData = {
        level = 115,
        size = 32,
        minAreaSize = 48,
        texture = "",
        showsPinAndArea = false,
    }

    local pinTooltipCreator = {
        creator = function(pin)
            local questId = pin and pin.m_PinTag
            local draft = Addon.QuestRepository:GetDraft()
            local targetQuest
            if IsDraftPinTag(questId, draft) then
                targetQuest = draft
            elseif questId then
                targetQuest = Addon.QuestRepository:GetQuestById(questId)
            end
            targetQuest = targetQuest or Addon.QuestRepository:GetActiveQuest()
            if not targetQuest then return end
            local tooltip = InformationTooltip
            if tooltip and tooltip.AddLine then
                local fallbackId = (Addon.QuestRepository.savedVars and Addon.QuestRepository.savedVars.nextId) or 1
                local titleText = (targetQuest.title and targetQuest.title ~= "" and targetQuest.title)
                    or Addon.Locale:Get("DEFAULT_QUEST_TITLE", fallbackId)
                local headerText = Addon.Locale:Get("MAP_TOOLTIP_HEADER", titleText)
                tooltip:AddLine(headerText, "ZoFontWinH4", 0.91, 0.83, 0.63)
                local targets = targetQuest.targets or {}
                for _, t in ipairs(targets) do
                    local objText = Addon.Locale:Get(
                        "MAP_TOOLTIP_OBJECTIVE",
                        t.name or "",
                        t.currentCount or 0,
                        t.requiredCount or 1
                    )
                    tooltip:AddLine(objText, "ZoFontGame", 1, 1, 1)
                end
            end
        end,
        tooltip = 1,
    }

    local layoutCallback = function(pManager)
        self:OnLayoutPins(pManager)
    end

    pinManager:AddCustomPin(PIN_TYPE_STRING, layoutCallback, nil, pinLayoutData, pinTooltipCreator)
    self.pinTypeId = _G[PIN_TYPE_STRING]

    if self.pinTypeId then
        pinManager:SetCustomPinEnabled(self.pinTypeId, true)
        ZO_MapPin.ASSISTED_PIN_TYPES[self.pinTypeId] = true
    end

    local locationPinLayoutData = {
        level = 116,
        size = 24,
        minAreaSize = 24,
        texture = "",
        showsPinAndArea = false,
    }

    local locationLayoutCallback = function(pManager)
        self:OnLayoutLocationPins(pManager)
    end

    pinManager:AddCustomPin(LOCATION_PIN_TYPE_STRING, locationLayoutCallback, nil, locationPinLayoutData, pinTooltipCreator)
    self.locationPinTypeId = _G[LOCATION_PIN_TYPE_STRING]

    if self.locationPinTypeId then
        pinManager:SetCustomPinEnabled(self.locationPinTypeId, true)
    end

    local zoomOutPinLayoutData = {
        level = 115,
        size = 32,
        texture = Addon.Constants.UI.ICON_QUEST,
        showsPinAndArea = false,
    }

    local zoomOutLayoutCallback = function(pManager)
        self:OnLayoutZoomOutPins(pManager)
    end

    pinManager:AddCustomPin(ZOOM_OUT_PIN_TYPE_STRING, zoomOutLayoutCallback, nil, zoomOutPinLayoutData, pinTooltipCreator)
    self.zoomOutPinTypeId = _G[ZOOM_OUT_PIN_TYPE_STRING]

    if self.zoomOutPinTypeId then
        pinManager:SetCustomPinEnabled(self.zoomOutPinTypeId, true)
        ZO_MapPin.ASSISTED_PIN_TYPES[self.zoomOutPinTypeId] = true
    end

    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
        self:RequestRefreshPins()
    end)
    CALLBACK_MANAGER:RegisterCallback("OnWorldMapModeChanged", function()
        self:RequestRefreshPins()
    end)

    RegisterMapSceneCallbacks(self, WORLD_MAP_SCENE)
    RegisterMapSceneCallbacks(self, GAMEPAD_WORLD_MAP_SCENE)

    EVENT_MANAGER:RegisterForEvent(MAP_LISTENER_NAME, EVENT_PLAYER_ACTIVATED, function()
        self:RequestRefreshPins()
    end)
    EVENT_MANAGER:RegisterForEvent(MAP_LISTENER_NAME .. "_Zone", EVENT_ZONE_CHANGED, function()
        self:RequestRefreshPins()
    end)

    Addon.QuestRepository:RegisterListener(function(eventType)
        if eventType == "QUEST_PROGRESS" or eventType == "DISCOVERY_TRIGGERED" then
            return
        end
        if eventType == "ACTIVE_QUEST_CHANGED" or eventType == "QUEST_DELETED" then
            self.previewQuestId = nil
        end
        self:RequestRefreshPins()
    end)

    self.isInitialized = true
    self._pinsDirty = true
    self:RequestRefreshPins()
end

local function IsTargetPending(target)
    return type(target) == "table" and (target.currentCount or 0) < (target.requiredCount or 1)
end

local function ResolveQuestSearchArea(quest)
    if type(quest) ~= "table" then
        return nil, nil, nil
    end
    if type(quest.targets) == "table" then
        for _, t in ipairs(quest.targets) do
            if IsTargetPending(t) and t.areaCenterX and t.areaCenterY and t.areaRadius and t.areaRadius > 0 then
                return t.areaCenterX, t.areaCenterY, t.areaRadius
            end
        end
    end
    if quest.areaCenterX and quest.areaCenterY and quest.areaRadius and quest.areaRadius > 0 then
        return quest.areaCenterX, quest.areaCenterY, quest.areaRadius
    end
    return nil, nil, nil
end

local function IsEditModeQuest(quest)
    local draft = Addon.QuestRepository and Addon.QuestRepository:GetDraft()
    return draft ~= nil and quest == draft
end

local function ShouldShowSearchAreas(quest)
    if IsEditModeQuest(quest) then
        return true
    end
    if quest.showSearchAreas ~= nil then
        return quest.showSearchAreas == true
    end
    return Addon.QuestRepository and Addon.QuestRepository:GetSetting("showSearchAreas") == true
end

local function ShouldShowLocationAreas(quest)
    if IsEditModeQuest(quest) then
        return true
    end
    if quest.showLocationAreas ~= nil then
        return quest.showLocationAreas == true
    end
    return Addon.QuestRepository and Addon.QuestRepository:GetSetting("showLocationAreas") == true
end

local function IsCurrentMapEligibleForQuestArea(quest)
    if not quest or quest.completed or quest.failed then
        return false
    end

    if not quest.mapId or quest.mapId <= 0 then
        return false
    end

    if ZO_WorldMapPins_Manager.IsCurrentMapGlobal() then
        return false
    end

    local mapType = GetMapType()
    if mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC then
        return false
    end

    local currentMapId = GetCurrentMapId()
    if not currentMapId or currentMapId ~= quest.mapId then
        return false
    end

    return true
end

function WorldMapArea:ShouldRenderOnCurrentMap(quest)
    if not IsCurrentMapEligibleForQuestArea(quest) or not ShouldShowSearchAreas(quest) then
        return false
    end

    local areaCX, areaCY, areaRad = ResolveQuestSearchArea(quest)
    if not areaCX or not areaCY or not areaRad or areaRad <= 0 then
        return false
    end

    return true
end

function WorldMapArea:ShouldRenderLocationAreasOnCurrentMap(quest)
    if not IsCurrentMapEligibleForQuestArea(quest) or not ShouldShowLocationAreas(quest) then
        return false
    end

    if type(quest.targets) ~= "table" then
        return false
    end

    local questZoneId = tonumber(quest.zoneId) or 0
    for _, t in ipairs(quest.targets) do
        if IsTargetPending(t) and t.worldX ~= nil and t.worldZ ~= nil then
            local tz = tonumber(t.zoneId) or questZoneId
            if tz > 0 then
                return true
            end
        end
    end

    return false
end

local function ResolveQuestWorldPosition(quest)
    if type(quest) ~= "table" then
        return nil
    end

    local questZoneId = tonumber(quest.zoneId) or 0
    if questZoneId > 0 and quest.worldX ~= nil and quest.worldZ ~= nil then
        return questZoneId, quest.worldX, quest.worldY or 0, quest.worldZ
    end

    if type(quest.targets) == "table" then
        for _, t in ipairs(quest.targets) do
            if type(t) == "table" and t.worldX ~= nil and t.worldZ ~= nil then
                local tz = tonumber(t.zoneId) or questZoneId
                if tz > 0 then
                    return tz, t.worldX, t.worldY or 0, t.worldZ
                end
            end
        end
    end

    if type(quest.discoveries) == "table" then
        for _, d in ipairs(quest.discoveries) do
            if type(d) == "table" and d.worldX ~= nil and d.worldZ ~= nil then
                local dz = tonumber(d.zoneId) or questZoneId
                if dz > 0 then
                    return dz, d.worldX, d.worldY or 0, d.worldZ
                end
            end
        end
    end

    return nil
end

function WorldMapArea:ShouldRenderZoomOutOnCurrentMap(quest)
    if not quest or quest.completed or quest.failed then
        return false
    end
    if not ShouldShowSearchAreas(quest) and not ShouldShowLocationAreas(quest) then
        return false
    end

    if not quest.mapId or quest.mapId <= 0 then
        return false
    end

    if GetMapType() == MAPTYPE_COSMIC then
        return false
    end

    local currentMapId = GetCurrentMapId()
    if not currentMapId or currentMapId == quest.mapId then
        return false
    end

    return true
end

function WorldMapArea:ProjectQuestToCurrentMap(quest)
    local zoneId, worldX, worldY, worldZ = ResolveQuestWorldPosition(quest)
    if not zoneId or not worldX or not worldZ then
        return nil, nil
    end

    local projX, projY = GetNormalizedWorldPosition(zoneId, worldX, worldY, worldZ)
    if not projX or not projY or projX <= 0 or projX >= 1 or projY <= 0 or projY >= 1 then
        return nil, nil
    end

    return projX, projY
end

function WorldMapArea:ResolveTargetQuest()
    local draft = Addon.QuestRepository:GetDraft()
    local draftReady = draft and draft.targets and #draft.targets > 0
        and (self:ShouldRenderOnCurrentMap(draft) or self:ShouldRenderLocationAreasOnCurrentMap(draft))

    if self.previewQuestId then
        if IsDraftPinTag(self.previewQuestId, draft) and draftReady then
            return draft, draft.editingQuestId or DRAFT_PIN_TAG
        end
        local previewQuest = Addon.QuestRepository:GetQuestById(self.previewQuestId)
        if previewQuest then
            return previewQuest, previewQuest.id
        end
    end

    if draftReady then
        return draft, draft.editingQuestId or DRAFT_PIN_TAG
    end

    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    if activeQuest then
        return activeQuest, activeQuest.id
    end
    return nil, nil
end

function WorldMapArea:IsSubzoneMap(mapType)
    local resolvedType = mapType
    if resolvedType == nil then
        resolvedType = GetMapType()
    end
    return resolvedType == MAPTYPE_SUBZONE
end

function WorldMapArea:GetEffectiveAreaRadius(baseRadius, mapType)
    local radius = tonumber(baseRadius) or Addon.Constants.AREA_RADIUS.MEDIUM
    if radius <= 0 then
        radius = Addon.Constants.AREA_RADIUS.MEDIUM
    end
    if self:IsSubzoneMap(mapType) then
        return radius * Addon.Constants.AREA_SUBZONE_MULTIPLIER
    end
    return radius
end

function WorldMapArea:OnLayoutPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.pinTypeId then return end

    local targetQuest, pinTag = self:ResolveTargetQuest()
    if not self:ShouldRenderOnCurrentMap(targetQuest) then
        return
    end

    local createdAny = false
    for _, t in ipairs(targetQuest.targets or {}) do
        if IsTargetPending(t) and t.areaCenterX and t.areaCenterY and t.areaRadius and t.areaRadius > 0 then
            local effectiveRadius = self:GetEffectiveAreaRadius(t.areaRadius)
            pManager:CreatePin(
                self.pinTypeId,
                pinTag,
                t.areaCenterX,
                t.areaCenterY,
                effectiveRadius
            )
            createdAny = true
        end
    end
    if not createdAny then
        local areaCX, areaCY, areaRad = ResolveQuestSearchArea(targetQuest)
        if areaCX and areaCY and areaRad then
            local effectiveRadius = self:GetEffectiveAreaRadius(areaRad)
            pManager:CreatePin(
                self.pinTypeId,
                pinTag,
                areaCX,
                areaCY,
                effectiveRadius
            )
        end
    end
end

function WorldMapArea:ProjectTargetLocationToCurrentMap(quest, target)
    if type(target) ~= "table" or target.worldX == nil or target.worldZ == nil then
        return nil, nil, nil
    end

    local zoneId = tonumber(target.zoneId) or (quest and tonumber(quest.zoneId)) or 0
    if zoneId <= 0 then
        return nil, nil, nil
    end

    local worldX = tonumber(target.worldX)
    local worldY = tonumber(target.worldY) or 0
    local worldZ = tonumber(target.worldZ)
    if not worldX or not worldZ then
        return nil, nil, nil
    end

    local normX, normY = GetNormalizedWorldPosition(zoneId, worldX, worldY, worldZ)
    if not normX or not normY or normX <= 0 or normX >= 1 or normY <= 0 or normY >= 1 then
        return nil, nil, nil
    end

    local worldRadius = tonumber(target.radius) or Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    if worldRadius <= 0 then
        worldRadius = Addon.Constants.DISCOVERY_RADIUS.MEDIUM
    end

    local edgeX, edgeY = GetNormalizedWorldPosition(zoneId, worldX + worldRadius, worldY, worldZ)
    local normRadius
    if edgeX and edgeY then
        local dx = edgeX - normX
        local dy = edgeY - normY
        normRadius = math.sqrt((dx * dx) + (dy * dy))
    end

    if not normRadius or normRadius <= 0 then
        normRadius = 0.015
    end

    return normX, normY, normRadius
end

function WorldMapArea:OnLayoutLocationPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.locationPinTypeId then return end

    local targetQuest, pinTag = self:ResolveTargetQuest()
    if not self:ShouldRenderLocationAreasOnCurrentMap(targetQuest) then
        return
    end

    local color = Addon.Constants.UI.LOCATION_AREA_COLOR
    for _, t in ipairs(targetQuest.targets or {}) do
        if IsTargetPending(t) then
            local locX, locY, locRadius = self:ProjectTargetLocationToCurrentMap(targetQuest, t)
            if locX and locY and locRadius and locRadius > 0 then
                local pin = pManager:CreatePin(
                    self.locationPinTypeId,
                    pinTag,
                    locX,
                    locY,
                    locRadius
                )
                if pin and pin.pinBlob and pin.pinBlob.SetColor then
                    pin.pinBlob:SetColor(color.r, color.g, color.b, color.a)
                end
            end
        end
    end
end

function WorldMapArea:OnLayoutZoomOutPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.zoomOutPinTypeId then return end

    local targetQuest, pinTag = self:ResolveTargetQuest()
    if not self:ShouldRenderZoomOutOnCurrentMap(targetQuest) then
        return
    end

    local projX, projY = self:ProjectQuestToCurrentMap(targetQuest)
    if not projX or not projY then
        return
    end

    local pin = pManager:CreatePin(self.zoomOutPinTypeId, pinTag, projX, projY)
    if pin then
        pin:PingMapPin(ZO_MapPin.PulseAnimation)
    end
end

function WorldMapArea:RequestRefreshPins()
    if not IsMapSceneShowing() then
        self._pinsDirty = true
        return
    end
    self:RefreshPins()
end

function WorldMapArea:RefreshPins()
    local pinManager = GetWorldMapPinManager()
    if not pinManager or not pinManager.RefreshCustomPins then
        return
    end
    self._pinsDirty = false
    if self.pinTypeId or self.locationPinTypeId or self.zoomOutPinTypeId then
        if self.pinTypeId then
            pinManager:RefreshCustomPins(self.pinTypeId)
        end
        if self.locationPinTypeId then
            pinManager:RefreshCustomPins(self.locationPinTypeId)
        end
        if self.zoomOutPinTypeId then
            pinManager:RefreshCustomPins(self.zoomOutPinTypeId)
        end
    else
        pinManager:RefreshCustomPins()
    end
end

local function PanWorldMapToNormalizedPosition(x, y)
    local fn = _G["ZO_WorldMap_PanToNormalizedPosition"]
    if type(fn) == "function" then
        fn(x, y)
    end
end

local function ResolveQuestMapTarget(quest)
    if type(quest) ~= "table" then
        return 0, nil, nil
    end

    local mapId = tonumber(quest.mapId) or 0
    local areaCX, areaCY = ResolveQuestSearchArea(quest)
    local panX = areaCX or quest.targetX
    local panY = areaCY or quest.targetY

    if (mapId <= 0 or not panX or not panY) and type(quest.targets) == "table" then
        for _, t in ipairs(quest.targets) do
            if type(t) == "table" then
                if mapId <= 0 and (tonumber(t.mapId) or 0) > 0 then
                    mapId = tonumber(t.mapId)
                end
                if (not panX or not panY) and (t.areaCenterX and t.areaCenterY) then
                    panX, panY = t.areaCenterX, t.areaCenterY
                elseif (not panX or not panY) and t.targetX and t.targetY then
                    panX, panY = t.targetX, t.targetY
                end
            end
        end
    end

    if (mapId <= 0 or not panX or not panY) and type(quest.discoveries) == "table" then
        for _, d in ipairs(quest.discoveries) do
            if type(d) == "table" then
                if mapId <= 0 and (tonumber(d.mapId) or 0) > 0 then
                    mapId = tonumber(d.mapId)
                end
                if (not panX or not panY) and d.x and d.y then
                    panX, panY = d.x, d.y
                end
            end
        end
    end

    return mapId, panX, panY
end

function WorldMapArea:HasMapLocation(quest)
    if type(quest) ~= "table" then
        return false
    end

    local mapId, panX, panY = ResolveQuestMapTarget(quest)
    if mapId > 0 and panX and panY then
        return true
    end

    if mapId > 0 and type(quest.discoveries) == "table" then
        for _, d in ipairs(quest.discoveries) do
            if type(d) == "table" and ((d.x and d.y) or (d.worldX and d.worldZ)) then
                return true
            end
        end
    end

    return false
end

function WorldMapArea:ShowQuestOnMap(quest)
    local targetQuest = quest or Addon.QuestRepository:GetActiveQuest()
    if not targetQuest then return false end

    local mapId, panX, panY = ResolveQuestMapTarget(targetQuest)
    if mapId <= 0 then return false end

    self.previewQuestId = targetQuest.id or targetQuest.editingQuestId or DRAFT_PIN_TAG
    self._pinsDirty = true

    SetWorldMapToId(mapId)
    OpenWorldMapScene()
    if self._pinsDirty then
        self:RefreshPins()
    end

    if panX and panY then
        PanWorldMapToNormalizedPosition(panX, panY)
        zo_callLater(function()
            if IsMapSceneShowing() then
                PanWorldMapToNormalizedPosition(panX, panY)
            end
        end, 50)
    end

    return true
end

local function Clamp(val, minVal, maxVal)
    if val < minVal then return minVal end
    if val > maxVal then return maxVal end
    return val
end

-- Calcula un centro desplazado aleatorio para que (targetX, targetY) quede
-- garantizadamente dentro del círculo de radio `radius`, pero no en su centro exacto.
function WorldMapArea:ComputeOffsetCenter(targetX, targetY, radius, randomAngle01, randomDist01)
    local r = tonumber(radius) or Addon.Constants.AREA_RADIUS.MEDIUM
    if r <= 0 then r = Addon.Constants.AREA_RADIUS.MEDIUM end

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
    if minBound > maxBound then
        minBound = 0.5
        maxBound = 0.5
    end

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

function WorldMapArea:IsPlayerInsideTargetLocation(target, playerZoneId, playerWorldX, playerWorldZ)
    if type(target) ~= "table" or target.worldX == nil or target.worldZ == nil then
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

function WorldMapArea:IsPlayerInsideQuestArea(quest, playerMapId, playerZoneId, playerX, playerY)
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

    -- Si tenemos coordenadas del jugador en el mismo mapa, verificar que esté dentro de un radio generoso de algún área de búsqueda pendiente
    if (quest.mapId and quest.mapId > 0 and playerMapId == quest.mapId) and playerX and playerY then
        local checkedAnyTargetArea = false
        if type(quest.targets) == "table" then
            for _, t in ipairs(quest.targets) do
                if IsTargetPending(t) and t.areaCenterX and t.areaCenterY and t.areaRadius and t.areaRadius > 0 then
                    checkedAnyTargetArea = true
                    local dx = playerX - t.areaCenterX
                    local dy = playerY - t.areaCenterY
                    local dist = math.sqrt((dx * dx) + (dy * dy))
                    local toleranceRadius = self:GetEffectiveAreaRadius(t.areaRadius) * 1.35
                    if dist <= toleranceRadius then
                        return true
                    end
                end
            end
        end
        if checkedAnyTargetArea then
            return false
        end
        local areaCX, areaCY, areaRad = ResolveQuestSearchArea(quest)
        if areaCX and areaCY and areaRad then
            local dx = playerX - areaCX
            local dy = playerY - areaCY
            local dist = math.sqrt((dx * dx) + (dy * dy))
            local toleranceRadius = self:GetEffectiveAreaRadius(areaRad) * 1.35
            return dist <= toleranceRadius
        end
    end

    return true
end
