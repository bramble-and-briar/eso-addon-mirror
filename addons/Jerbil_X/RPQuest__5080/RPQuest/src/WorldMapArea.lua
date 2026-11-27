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
local DISCOVERY_PIN_TYPE_STRING = Addon.Constants.UI.DISCOVERY_PIN_TYPE_STRING
local ZOOM_OUT_PIN_TYPE_STRING = Addon.Constants.UI.ZOOM_OUT_PIN_TYPE_STRING
local TARGET_PING_PIN_TYPE_STRING = Addon.Constants.UI.TARGET_PING_PIN_TYPE_STRING
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

local function SetWorldMapToId(mapId)
    if not mapId or mapId <= 0 then
        return
    end
    WORLD_MAP_MANAGER:SetMapById(mapId)
end

local function PanWorldMapToNormalizedPosition(x, y)
    local fn = _G["ZO_WorldMap_PanToNormalizedPosition"]
    if type(fn) == "function" then
        fn(x, y)
    end
end

local function ApplyPendingMapTarget(self)
    local pending = self._pendingMapTarget
    if not pending then
        return
    end
    self._pendingMapTarget = nil
    SetWorldMapToId(pending.mapId)
    if self._pinsDirty then
        self:RefreshPins()
    end
    if pending.panX and pending.panY then
        PanWorldMapToNormalizedPosition(pending.panX, pending.panY)
        local targetPanX, targetPanY = pending.panX, pending.panY
        zo_callLater(function()
            if IsMapSceneShowing() then
                PanWorldMapToNormalizedPosition(targetPanX, targetPanY)
            end
        end, 50)
    end
end

local function RegisterMapSceneCallbacks(self, scene)
    if not scene or not scene.RegisterCallback then
        return
    end
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWN then
            ApplyPendingMapTarget(self)
            if self._pinsDirty then
                self:RefreshPins()
            end
        elseif newState == SCENE_SHOWING then
            if self._pinsDirty then
                self:RefreshPins()
            end
        elseif newState == SCENE_HIDDEN then
            self._pendingMapTarget = nil
            self.previewQuestId = nil
            self:StopPulseAnimations()
            self:ClearTargetPing()
        end
    end)
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

local function IsEditModeQuest(quest)
    local draft = Addon.QuestRepository and Addon.QuestRepository:GetDraft()
    return draft ~= nil and quest == draft
end

local function IsActivelyTestingPreparedQuest(quest)
    if type(quest) ~= "table" or not Addon.QuestRepository then
        return false
    end
    if not Addon.QuestRepository:IsPreparedQuest(quest) then
        return false
    end
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    return activeQuest ~= nil and (activeQuest == quest or (quest.id ~= nil and activeQuest.id == quest.id))
end

local function IsCreatorDiscoveryQuest(quest)
    if IsEditModeQuest(quest) then
        return true
    end
    if Addon.QuestRepository ~= nil and Addon.QuestRepository:IsPreparedQuest(quest) then
        return not IsActivelyTestingPreparedQuest(quest)
    end
    return false
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

    local function ResolvePinQuestAndTarget(pin)
        local tag = pin and ((pin.GetPinTypeAndTag and select(2, pin:GetPinTypeAndTag())) or pin.m_PinTag)
        local questId = type(tag) == "table" and tag.questId or tag
        local targetIndex = type(tag) == "table" and tag.targetIndex or nil
        local draft = Addon.QuestRepository:GetDraft()
        local targetQuest
        if IsDraftPinTag(questId, draft) then
            targetQuest = draft
        elseif questId then
            targetQuest = Addon.QuestRepository:GetQuestById(questId)
        end
        targetQuest = targetQuest or Addon.QuestRepository:GetActiveQuest()
        if not targetQuest then
            return nil, nil
        end
        local target = (targetIndex and targetQuest.targets and targetQuest.targets[targetIndex]) or nil
        return targetQuest, target, tag
    end

    local function AddTooltipHeader(tooltip, targetQuest)
        local fallbackId = (Addon.QuestRepository.savedVars and Addon.QuestRepository.savedVars.nextId) or 1
        local titleText = (targetQuest.title and targetQuest.title ~= "" and targetQuest.title)
            or Addon.Locale:Get("DEFAULT_QUEST_TITLE", fallbackId)
        local headerText = Addon.Locale:Get("MAP_TOOLTIP_HEADER", titleText)
        tooltip:AddLine(headerText, "ZoFontWinH4", 0.91, 0.83, 0.63)
    end

    local pinTooltipCreator = {
        creator = function(pin)
            local targetQuest, target = ResolvePinQuestAndTarget(pin)
            if not targetQuest then return end
            local tooltip = InformationTooltip
            if tooltip and tooltip.AddLine then
                AddTooltipHeader(tooltip, targetQuest)
                if target then
                    local objText = Addon.Locale:Get(
                        "MAP_TOOLTIP_OBJECTIVE",
                        target.name or "",
                        target.currentCount or 0,
                        target.requiredCount or 1
                    )
                    tooltip:AddLine(objText, "ZoFontGame", 1, 1, 1)
                else
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
            end
        end,
        tooltip = 1,
    }

    local locationPinTooltipCreator = {
        creator = function(pin)
            local targetQuest, target = ResolvePinQuestAndTarget(pin)
            if not targetQuest or not target then return end
            local tooltip = InformationTooltip
            if tooltip and tooltip.AddLine then
                AddTooltipHeader(tooltip, targetQuest)
                local reqLabel = target.locationRequired
                    and Addon.Locale:Get("MAP_TOOLTIP_LOC_REQUIRED")
                    or Addon.Locale:Get("MAP_TOOLTIP_LOC_OPTIONAL")
                local meters = math.floor(((tonumber(target.radius) or Addon.Constants.DISCOVERY_RADIUS.MEDIUM) / 100) + 0.5)
                local locText = Addon.Locale:Get("MAP_TOOLTIP_LOCATION", target.name or "", reqLabel, meters)
                tooltip:AddLine(locText, "ZoFontGame", 1, 1, 1)
            end
        end,
        tooltip = 1,
    }

    local discoveryPinTooltipCreator = {
        creator = function(pin)
            local targetQuest, _, tag = ResolvePinQuestAndTarget(pin)
            local discIndex = type(tag) == "table" and tag.discoveryIndex or nil
            local discovery = discIndex and targetQuest and targetQuest.discoveries and targetQuest.discoveries[discIndex]
            if not targetQuest or not discovery then return end
            local tooltip = InformationTooltip
            if tooltip and tooltip.AddLine then
                AddTooltipHeader(tooltip, targetQuest)
                if IsCreatorDiscoveryQuest(targetQuest) then
                    local msg = tostring(discovery.message or ""):gsub("[\r\n]+", " ")
                    if #msg > 60 then
                        msg = msg:sub(1, 57) .. "..."
                    end
                    local creatorText = Addon.Locale:Get("MAP_TOOLTIP_DISCOVERY_CREATOR", discIndex, msg)
                    tooltip:AddLine(creatorText, "ZoFontGame", 1, 1, 1)
                else
                    local playerText = Addon.Locale:Get("MAP_TOOLTIP_DISCOVERY_PLAYER", discIndex)
                    tooltip:AddLine(playerText, "ZoFontGame", 1, 1, 1)
                end
            end
        end,
        tooltip = 1,
    }

    local layoutCallback = function(pManager)
        self:OnLayoutPins(pManager)
    end

    local searchResizeCallback = function(pManager)
        self:OnResizeSearchPins(pManager)
    end

    pinManager:AddCustomPin(PIN_TYPE_STRING, layoutCallback, searchResizeCallback, pinLayoutData, pinTooltipCreator)
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

    local locationResizeCallback = function(pManager)
        self:OnResizeLocationPins(pManager)
    end

    pinManager:AddCustomPin(LOCATION_PIN_TYPE_STRING, locationLayoutCallback, locationResizeCallback, locationPinLayoutData, locationPinTooltipCreator)
    self.locationPinTypeId = _G[LOCATION_PIN_TYPE_STRING]

    if self.locationPinTypeId then
        pinManager:SetCustomPinEnabled(self.locationPinTypeId, true)
    end

    local discoveryPinLayoutData = {
        level = 117,
        size = 24,
        minAreaSize = 24,
        texture = "",
        showsPinAndArea = false,
    }

    local discoveryLayoutCallback = function(pManager)
        self:OnLayoutDiscoveryPins(pManager)
    end

    local discoveryResizeCallback = function(pManager)
        self:OnResizeDiscoveryPins(pManager)
    end

    pinManager:AddCustomPin(DISCOVERY_PIN_TYPE_STRING, discoveryLayoutCallback, discoveryResizeCallback, discoveryPinLayoutData, discoveryPinTooltipCreator)
    self.discoveryPinTypeId = _G[DISCOVERY_PIN_TYPE_STRING]

    if self.discoveryPinTypeId then
        pinManager:SetCustomPinEnabled(self.discoveryPinTypeId, true)
    end

    local zoomOutPinLayoutData = {
        level = 115,
        size = 32,
        minAreaSize = 48,
        texture = "",
        showsPinAndArea = false,
    }

    local zoomOutLayoutCallback = function(pManager)
        self:OnLayoutZoomOutPins(pManager)
    end

    local zoomOutResizeCallback = function(pManager)
        self:OnResizeZoomOutPins(pManager)
    end

    pinManager:AddCustomPin(ZOOM_OUT_PIN_TYPE_STRING, zoomOutLayoutCallback, zoomOutResizeCallback, zoomOutPinLayoutData, pinTooltipCreator)
    self.zoomOutPinTypeId = _G[ZOOM_OUT_PIN_TYPE_STRING]

    if self.zoomOutPinTypeId then
        pinManager:SetCustomPinEnabled(self.zoomOutPinTypeId, true)
        ZO_MapPin.ASSISTED_PIN_TYPES[self.zoomOutPinTypeId] = true
    end

    local targetPingPinLayoutData = {
        level = 120,
        minSize = 100,
        texture = Addon.Constants.UI.TARGET_PING_TEXTURE,
        isAnimated = true,
        framesWide = 32,
        framesHigh = 1,
        framesPerSecond = 32,
    }

    local targetPingLayoutCallback = function(pManager)
        self:OnLayoutTargetPingPins(pManager)
    end

    pinManager:AddCustomPin(TARGET_PING_PIN_TYPE_STRING, targetPingLayoutCallback, nil, targetPingPinLayoutData)
    self.targetPingPinTypeId = _G[TARGET_PING_PIN_TYPE_STRING]

    if self.targetPingPinTypeId then
        pinManager:SetCustomPinEnabled(self.targetPingPinTypeId, true)
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
        if eventType == "QUEST_PROGRESS" then
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

local function ShouldShowDiscoveryAreas(quest)
    if IsCreatorDiscoveryQuest(quest) then
        return true
    end
    if quest.showDiscoveryAreas ~= nil then
        return quest.showDiscoveryAreas == true
    end
    return Addon.QuestRepository and Addon.QuestRepository:GetSetting("showDiscoveryAreas") == true
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

local function IsDiscoveryVisibleOnMap(quest, index, discovery, isCreator)
    if type(discovery) ~= "table" then
        return false
    end
    if isCreator then
        return true
    end
    if discovery.discovered then
        return false
    end
    if quest.sequentialDiscoveries == true and index > 1 then
        local prev = quest.discoveries and quest.discoveries[index - 1]
        if not (prev and prev.discovered == true) then
            return false
        end
    end
    return true
end

function WorldMapArea:ShouldRenderDiscoveryAreasOnCurrentMap(quest)
    if not IsCurrentMapEligibleForQuestArea(quest) or not ShouldShowDiscoveryAreas(quest) then
        return false
    end

    if type(quest.discoveries) ~= "table" then
        return false
    end

    local isCreator = IsCreatorDiscoveryQuest(quest)
    local questZoneId = tonumber(quest.zoneId) or 0
    for i, d in ipairs(quest.discoveries) do
        if IsDiscoveryVisibleOnMap(quest, i, d, isCreator) then
            local hasWorld = d.worldX ~= nil and d.worldZ ~= nil and ((tonumber(d.zoneId) or questZoneId) > 0)
            local hasMapXY = d.x ~= nil and d.y ~= nil and d.x > 0 and d.x < 1 and d.y > 0 and d.y < 1
            if hasWorld or hasMapXY then
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
    if not ShouldShowSearchAreas(quest) and not ShouldShowLocationAreas(quest) and not ShouldShowDiscoveryAreas(quest) then
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
    local hasDraftTargets = draft and draft.targets and #draft.targets > 0
    local hasDraftDiscoveries = draft and draft.discoveries and #draft.discoveries > 0
    local draftReady = (hasDraftTargets or hasDraftDiscoveries)
        and (self:ShouldRenderOnCurrentMap(draft)
            or self:ShouldRenderLocationAreasOnCurrentMap(draft)
            or self:ShouldRenderDiscoveryAreasOnCurrentMap(draft))

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

local function HashString(str, seed)
    local h = seed or 5381
    for i = 1, #str do
        h = ((h * 33) + string.byte(str, i)) % 2147483647
    end
    return h
end

local function ComputeZoomOutSeed(quest)
    local idPart = tostring((quest and (quest.id or quest.editingQuestId)) or "")
    local titlePart = tostring((quest and quest.title) or "")
    local mapPart = tostring((quest and quest.mapId) or 0)
    local zonePart = tostring((quest and quest.zoneId) or 0)
    local key = idPart .. ":" .. titlePart .. ":" .. mapPart .. ":" .. zonePart
    local uAngle = (HashString(key, 5381) % 10000) / 10000
    local uDist = (HashString(key, 31337) % 10000) / 10000
    return uAngle, uDist
end

local function ApplyPinBlobColor(pin, color)
    if pin and pin.pinBlob and pin.pinBlob.SetColor and color then
        pin.pinBlob:SetColor(color.r, color.g, color.b, color.a)
    end
end

function WorldMapArea:StopPulseAnimations(kindFilter)
    local active = self._activePulseAnimations
    if not active then
        return
    end
    for i = #active, 1, -1 do
        local entry = active[i]
        if not kindFilter or entry.kind == kindFilter then
            table.remove(active, i)
            entry.stopped = true
            if entry.timeline and entry.timeline.Stop then
                entry.timeline:Stop()
            end
            if entry.anim and entry.anim.SetAnimatedControl then
                entry.anim:SetAnimatedControl(nil)
            end
            if entry.blob and entry.blob.SetAlpha then
                entry.blob:SetAlpha(1)
            end
        end
    end
end

function WorldMapArea:StartPulseAnimation(pin, kind)
    if not pin or not pin.pinBlob then
        return
    end
    if not ANIMATION_MANAGER or not ANIMATION_MANAGER.CreateTimeline then
        return
    end

    local blob = pin.pinBlob
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    if not timeline or not timeline.InsertAnimation then
        return
    end

    local anim = timeline:InsertAnimation(ANIMATION_ALPHA, blob, 0)
    if not anim then
        return
    end

    if anim.SetAlphaValues then
        anim:SetAlphaValues(1.0, 0.35)
    end
    if anim.SetDuration then
        anim:SetDuration(450)
    end
    if timeline.SetPlaybackType then
        timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, 4)
    end

    self._activePulseAnimations = self._activePulseAnimations or {}
    local entry = {
        timeline = timeline,
        anim = anim,
        blob = blob,
        kind = kind,
        stopped = false,
    }
    table.insert(self._activePulseAnimations, entry)

    if timeline.SetHandler then
        timeline:SetHandler("OnStop", function()
            if entry.stopped then
                return
            end
            entry.stopped = true
            local list = self._activePulseAnimations
            if list then
                for i = #list, 1, -1 do
                    if list[i] == entry then
                        table.remove(list, i)
                        break
                    end
                end
            end
            if anim.SetAnimatedControl then
                anim:SetAnimatedControl(nil)
            end
            if blob.SetAlpha then
                blob:SetAlpha(1)
            end
        end)
    end

    if timeline.PlayFromStart then
        timeline:PlayFromStart()
    end
end

function WorldMapArea:OnLayoutPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.pinTypeId then return end

    self:StopPulseAnimations("search")

    local targetQuest, questTag = self:ResolveTargetQuest()
    if not self:ShouldRenderOnCurrentMap(targetQuest) then
        return
    end

    local color = Addon.Constants.UI.SEARCH_AREA_COLOR
    local createdAny = false
    for i, t in ipairs(targetQuest.targets or {}) do
        if IsTargetPending(t) and t.areaCenterX and t.areaCenterY and t.areaRadius and t.areaRadius > 0 then
            local effectiveRadius = self:GetEffectiveAreaRadius(t.areaRadius)
            local pinTag = { questId = questTag, targetIndex = i, kind = "search" }
            local pin = pManager:CreatePin(
                self.pinTypeId,
                pinTag,
                t.areaCenterX,
                t.areaCenterY,
                effectiveRadius
            )
            ApplyPinBlobColor(pin, color)
            self:StartPulseAnimation(pin, "search")
            createdAny = true
        end
    end
    if not createdAny then
        local areaCX, areaCY, areaRad = ResolveQuestSearchArea(targetQuest)
        if areaCX and areaCY and areaRad then
            local effectiveRadius = self:GetEffectiveAreaRadius(areaRad)
            local pinTag = { questId = questTag, kind = "search" }
            local pin = pManager:CreatePin(
                self.pinTypeId,
                pinTag,
                areaCX,
                areaCY,
                effectiveRadius
            )
            ApplyPinBlobColor(pin, color)
            self:StartPulseAnimation(pin, "search")
        end
    end
end

local function ProjectWorldAreaToCurrentMap(quest, item)
    if type(item) ~= "table" or item.worldX == nil or item.worldZ == nil then
        return nil, nil, nil
    end

    local zoneId = tonumber(item.zoneId) or (quest and tonumber(quest.zoneId)) or 0
    if zoneId <= 0 then
        return nil, nil, nil
    end

    local worldX = tonumber(item.worldX)
    local worldY = tonumber(item.worldY) or 0
    local worldZ = tonumber(item.worldZ)
    if not worldX or not worldZ then
        return nil, nil, nil
    end

    local normX, normY = GetNormalizedWorldPosition(zoneId, worldX, worldY, worldZ)
    if not normX or not normY or normX <= 0 or normX >= 1 or normY <= 0 or normY >= 1 then
        return nil, nil, nil
    end

    local worldRadius = tonumber(item.radius) or Addon.Constants.DISCOVERY_RADIUS.MEDIUM
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

function WorldMapArea:ProjectTargetLocationToCurrentMap(quest, target)
    return ProjectWorldAreaToCurrentMap(quest, target)
end

function WorldMapArea:ProjectDiscoveryToCurrentMap(quest, discovery)
    local normX, normY, normRadius = ProjectWorldAreaToCurrentMap(quest, discovery)
    if normX and normY and normRadius then
        return normX, normY, normRadius
    end
    if type(discovery) == "table" and discovery.x and discovery.y and discovery.x > 0 and discovery.x < 1 and discovery.y > 0 and discovery.y < 1 then
        local worldRadius = tonumber(discovery.radius) or Addon.Constants.DISCOVERY_RADIUS.MEDIUM
        local fallbackRadius = math.max(0.008, worldRadius / 100000)
        return discovery.x, discovery.y, fallbackRadius
    end
    return nil, nil, nil
end

function WorldMapArea:OnLayoutLocationPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.locationPinTypeId then return end

    local targetQuest, questTag = self:ResolveTargetQuest()
    if not self:ShouldRenderLocationAreasOnCurrentMap(targetQuest) then
        return
    end

    local color = Addon.Constants.UI.LOCATION_AREA_COLOR
    for i, t in ipairs(targetQuest.targets or {}) do
        if IsTargetPending(t) then
            local locX, locY, locRadius = self:ProjectTargetLocationToCurrentMap(targetQuest, t)
            if locX and locY and locRadius and locRadius > 0 then
                local pinTag = { questId = questTag, targetIndex = i, kind = "location" }
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

local function ApplyPinBlobColorOnResize(pinManager, pinTypeId, color)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not pinTypeId or not pManager.GetActiveObjects then
        return
    end

    for _, pin in pairs(pManager:GetActiveObjects()) do
        if pin and pin.GetPinType and pin:GetPinType() == pinTypeId and pin.pinBlob and pin.pinBlob.SetColor then
            pin.pinBlob:SetColor(color.r, color.g, color.b, color.a)
        end
    end
end

function WorldMapArea:OnResizeSearchPins(pinManager)
    ApplyPinBlobColorOnResize(pinManager, self.pinTypeId, Addon.Constants.UI.SEARCH_AREA_COLOR)
end

function WorldMapArea:OnResizeLocationPins(pinManager)
    ApplyPinBlobColorOnResize(pinManager, self.locationPinTypeId, Addon.Constants.UI.LOCATION_AREA_COLOR)
end

function WorldMapArea:OnLayoutDiscoveryPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.discoveryPinTypeId then return end

    local targetQuest, questTag = self:ResolveTargetQuest()
    if not self:ShouldRenderDiscoveryAreasOnCurrentMap(targetQuest) then
        return
    end

    local isCreator = IsCreatorDiscoveryQuest(targetQuest)
    local color = Addon.Constants.UI.DISCOVERY_AREA_COLOR
    for i, d in ipairs(targetQuest.discoveries or {}) do
        if IsDiscoveryVisibleOnMap(targetQuest, i, d, isCreator) then
            local discX, discY, discRadius = self:ProjectDiscoveryToCurrentMap(targetQuest, d)
            if discX and discY and discRadius and discRadius > 0 then
                local pinTag = { questId = questTag, discoveryIndex = i, kind = "discovery" }
                local pin = pManager:CreatePin(
                    self.discoveryPinTypeId,
                    pinTag,
                    discX,
                    discY,
                    discRadius
                )
                if pin and pin.pinBlob and pin.pinBlob.SetColor then
                    pin.pinBlob:SetColor(color.r, color.g, color.b, color.a)
                end
            end
        end
    end
end

function WorldMapArea:OnResizeDiscoveryPins(pinManager)
    ApplyPinBlobColorOnResize(pinManager, self.discoveryPinTypeId, Addon.Constants.UI.DISCOVERY_AREA_COLOR)
end

function WorldMapArea:OnLayoutZoomOutPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.zoomOutPinTypeId then return end

    self:StopPulseAnimations("zoom")

    local targetQuest, questTag = self:ResolveTargetQuest()
    if not self:ShouldRenderZoomOutOnCurrentMap(targetQuest) then
        return
    end

    local projX, projY = self:ProjectQuestToCurrentMap(targetQuest)
    if not projX or not projY then
        return
    end

    local zoomOutRadius = Addon.Constants.AREA_RADIUS.MEDIUM
    local uAngle, uDist = ComputeZoomOutSeed(targetQuest)
    local offsetX, offsetY = self:ComputeOffsetCenter(projX, projY, zoomOutRadius, uAngle, uDist)

    local pinTag = { questId = questTag, kind = "zoom" }
    local pin = pManager:CreatePin(self.zoomOutPinTypeId, pinTag, offsetX, offsetY, zoomOutRadius)
    ApplyPinBlobColor(pin, Addon.Constants.UI.SEARCH_AREA_COLOR)
    self:StartPulseAnimation(pin, "zoom")
end

function WorldMapArea:OnResizeZoomOutPins(pinManager)
    ApplyPinBlobColorOnResize(pinManager, self.zoomOutPinTypeId, Addon.Constants.UI.SEARCH_AREA_COLOR)
end

function WorldMapArea:OnLayoutTargetPingPins(pinManager)
    local pManager = pinManager or GetWorldMapPinManager()
    if not pManager or not self.targetPingPinTypeId then
        return
    end

    local ping = self._activeTargetPing
    if not ping or not ping.x or not ping.y then
        return
    end

    if ZO_WorldMapPins_Manager.IsCurrentMapGlobal() then
        return
    end

    local mapType = GetMapType()
    if mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC then
        return
    end

    local currentMapId = GetCurrentMapId()
    if ping.mapId and ping.mapId > 0 and currentMapId and currentMapId > 0 and currentMapId ~= ping.mapId then
        return
    end

    local pinTag = {
        questId = ping.questId,
        targetIndex = ping.targetIndex,
        kind = "targetPing",
    }
    pManager:CreatePin(self.targetPingPinTypeId, pinTag, ping.x, ping.y)
end

function WorldMapArea:RefreshTargetPingPins()
    local pinManager = GetWorldMapPinManager()
    if not pinManager or not pinManager.RefreshCustomPins then
        return
    end
    if self.targetPingPinTypeId then
        pinManager:RefreshCustomPins(self.targetPingPinTypeId)
    end
end

function WorldMapArea:ClearTargetPing(skipRefresh)
    self._targetPingToken = (self._targetPingToken or 0) + 1
    local hadPing = self._activeTargetPing ~= nil
    self._activeTargetPing = nil
    if hadPing and not skipRefresh then
        self:RefreshTargetPingPins()
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
    self:StopPulseAnimations()
    if self.pinTypeId or self.locationPinTypeId or self.discoveryPinTypeId or self.zoomOutPinTypeId or self.targetPingPinTypeId then
        if self.pinTypeId then
            pinManager:RefreshCustomPins(self.pinTypeId)
        end
        if self.locationPinTypeId then
            pinManager:RefreshCustomPins(self.locationPinTypeId)
        end
        if self.discoveryPinTypeId then
            pinManager:RefreshCustomPins(self.discoveryPinTypeId)
        end
        if self.zoomOutPinTypeId then
            pinManager:RefreshCustomPins(self.zoomOutPinTypeId)
        end
        if self.targetPingPinTypeId then
            pinManager:RefreshCustomPins(self.targetPingPinTypeId)
        end
    else
        pinManager:RefreshCustomPins()
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

    if mapId > 0 then
        return true
    end

    return false
end

local function ResolveSelectedTargetMapPosition(self, quest, targetIndex)
    if type(quest) ~= "table" or type(targetIndex) ~= "number" or type(quest.targets) ~= "table" then
        return nil, nil, nil
    end

    local target = quest.targets[targetIndex]
    if type(target) ~= "table" then
        return nil, nil, nil
    end

    local mapId = tonumber(target.mapId) or tonumber(quest.mapId) or 0
    if mapId <= 0 then
        return nil, nil, nil
    end

    if target.areaCenterX and target.areaCenterY then
        return mapId, target.areaCenterX, target.areaCenterY
    end

    if target.worldX ~= nil and target.worldZ ~= nil then
        SetWorldMapToId(mapId)
        local locX, locY = self:ProjectTargetLocationToCurrentMap(quest, target)
        if locX and locY then
            return mapId, locX, locY
        end
    end

    return nil, nil, nil
end

function WorldMapArea:ShowQuestOnMap(quest, targetIndex)
    local targetQuest = quest or Addon.QuestRepository:GetActiveQuest()
    if not targetQuest then return false end

    local mapId, panX, panY = ResolveSelectedTargetMapPosition(self, targetQuest, targetIndex)
    local hasSelectedTargetPing = (mapId ~= nil and panX ~= nil and panY ~= nil)
    if not hasSelectedTargetPing then
        mapId, panX, panY = ResolveQuestMapTarget(targetQuest)
    end
    if not mapId or mapId <= 0 then return false end

    self.previewQuestId = targetQuest.id or targetQuest.editingQuestId or DRAFT_PIN_TAG
    self._pinsDirty = true

    self:ClearTargetPing(true)
    if hasSelectedTargetPing then
        local token = self._targetPingToken
        self._activeTargetPing = {
            mapId = mapId,
            x = panX,
            y = panY,
            questId = self.previewQuestId,
            targetIndex = targetIndex,
        }
        local durationMs = Addon.Constants.UI.TARGET_PING_DURATION_MS or 4500
        zo_callLater(function()
            if self._targetPingToken == token then
                self:ClearTargetPing()
            end
        end, durationMs)
    end

    local wasShowing = IsMapSceneShowing()
    if not wasShowing then
        self._pendingMapTarget = {
            mapId = mapId,
            panX = panX,
            panY = panY,
        }
    else
        self._pendingMapTarget = nil
    end

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
