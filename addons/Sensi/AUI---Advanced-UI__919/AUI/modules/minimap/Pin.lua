local g_isInit = false
local g_activeGroupPins = {}
local g_worldEventUnitPins = {}
local g_objectiveMovingPins = {}
local g_imperialCityMapIndex = GetImperialCityMapIndex()
local g_cyrodilMapIndex = GetCyrodiilMapIndex()
local g_focusedAntiquityId = nil

local MIN_PIN_SIZE = 18
local MIN_PIN_SCALE = 0.6
local MAX_PIN_SCALE = 1
local DEFAULT_PIN_SIZE = 18

local g_mapPinManager = AUI.Minimap.GetPinManager()
local gApiVersion = GetAPIVersion()

AUI_Pin = ZO_MapPin:Subclass()

function AUI_Pin:ClearData()
    self:CleanUpDependencies()
    self.m_PinType = nil
    self.m_PinTag = nil
end


function AUI_Pin:BuildDependencies()
    if self:IsWorldEventPOIPin() then
        local zoneIndex = self:GetPOIZoneIndex()
        local poiIndex = self:GetPOIIndex()
        local associatedPOIPin = g_mapPinManager:FindPin("poi", zoneIndex, poiIndex)
        if associatedPOIPin then
            associatedPOIPin:SetScaleModifier(0.75)
        end
    end
end

function AUI_Pin:CleanUpDependencies()
    if self:IsWorldEventPOIPin() then
        local zoneIndex = self:GetPOIZoneIndex()
        local poiIndex = self:GetPOIIndex()
        local associatedPOIPin = g_mapPinManager:FindPin("poi", zoneIndex, poiIndex)
        if associatedPOIPin then
            associatedPOIPin:SetScaleModifier(1)
        end
    end
end

function AUI_Pin:CalculateAnchor()
	local point = CENTER
	local relToControl = AUI_MapContainer
	local rpoint = TOPLEFT
	local containerSize = AUI.Minimap.GetMapContainerSize()

	local offsetX = self.normalizedX * containerSize
	local offsetY = self.normalizedY * containerSize

	if AUI.Settings.Minimap.rotate then
		local headingCos, headingSin = AUI.Minimap.GetRotationData()

		local playerX, playerY = AUI.Minimap.GetPlayerPosition()
		local x = (offsetX - playerX)
		local y = (offsetY - playerY)
			
		if self.borderInformation then
			point = TOPLEFT
			rpoint = CENTER			
		else
			point = CENTER
			rpoint = CENTER			
		end	
		
		relToControl = AUI_Minimap_Map_Scroll
		
		offsetX = (headingCos * x) - (headingSin * y)
		offsetY = (headingSin * x) + (headingCos * y)			
	end	
	
	return point, relToControl, rpoint, offsetX, offsetY
end

function AUI_Pin:UpdateLocation()
	if not g_isInit then
		return
	end
	
    local pinControl = self:GetControl()
    if self.normalizedX and self.normalizedY then	
		local point, relToControl, rpoint, offsetX, offsetY = self:CalculateAnchor()
		
		pinControl:ClearAnchors()
		pinControl:SetAnchor(point, relToControl, rpoint, offsetX, offsetY)		
		
		if self.pinBlob then
			self.pinBlob:ClearAnchors()
			self.pinBlob:SetAnchor(point, relToControl, rpoint, offsetX, offsetY)
		end
		
		if self.polygonBlob then
			if AUI.Settings.Minimap.rotate and self.borderInformation then
				self.polygonBlob:ClearPoints()
			
				for i, point in ipairs(self.borderInformation.borderPoints) do		
					local headingCos, headingSin = AUI.Minimap.GetRotationData()				
					local ix = point.x -self.normalizedX
					local iy = point.y -self.normalizedY
					local rx = (headingCos * ix) - (headingSin * iy)
					local ry = (headingSin * ix) + (headingCos * iy)			

					self.polygonBlob:AddPoint(rx, ry)
				end			
			end
			
			self.polygonBlob:ClearAnchors()
			self.polygonBlob:SetAnchor(point, relToControl, rpoint, offsetX, offsetY)
		end			
    end
end

local function GetPinTextureData(self, textureData)
	if type(textureData) == "string" then
		return textureData
	elseif type(textureData) == "function" then
		return textureData(self)
	end
end

local function GetPinTextureColor(self, textureColor)
	if type(textureColor) == "function" then
		return textureColor(self)
	end
	return textureColor
end

local function IsPinAnimated(self, isAnimated)
	if type(isAnimated) == "boolean" then
		return isAnimated
	elseif type(isAnimated) == "function" then
		return isAnimated(self)
	end
end

function AUI_Pin:SetData(pinType, pinTag)
	self:ClearData()
	self.m_PinType = pinType
	self.m_PinTag = pinTag

	if self:IsQuest() then
		local questType = GetJournalQuestType(pinTag[1])
		local questRepeatType = GetJournalQuestRepeatType(pinTag[1]) 				
		self.m_AUIPinType = AUI.Minimap.Pin.GetQuestPinType(pinType, questType, questRepeatType)
	elseif self:IsGroup() then
		local groupTag = pinTag.groupTag
		if not groupTag then
			groupTag = pinTag
		end	
	
		self.m_AUIPinType = AUI.Minimap.Pin.GetGroupStatePinType(groupTag)
	else
		self.m_AUIPinType = pinType
	end

	if type(pinTag) == "string" and ZO_Group_IsGroupUnitTag(pinTag) then
		pinTag = "group"
	end

	self.labelControl:SetText("")

	local singlePinData = ZO_MapPin.PIN_DATA[self.m_AUIPinType]
	if singlePinData ~= nil then
		-- Set up texture
		local overlayTexture, pulseTexture, glowTexture = GetPinTextureData(self, singlePinData.texture)

		if overlayTexture ~= "" then
			self.backgroundControl:SetTexture(overlayTexture)
		end

		if pulseTexture then
			self:ResetAnimation(ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_ALLOW_PLAY, ZO_MapPin.ANIM_CONSTANTS.LONG_LOOP_COUNT, pulseTexture, overlayTexture, ZO_MapPin.DoFinalFadeInAfterPing)
		elseif glowTexture then
			self:ResetAnimation(ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_HIDE_CONTROL)
			self.highlightControl:SetHidden(false)
			self.highlightControl:SetAlpha(1)
			self.highlightControl:SetTexture(glowTexture)
		else
			self.highlightControl:SetHidden(true)
		end

		local level = singlePinData.level
		if type(level) == "function" then
			level = level(self)
		end

		local pinLevel = zo_max(level, 1)

		--if the pin doesn't have click behavior, push the mouse enable control down so it doesn't eat clicks
		if ZO_MapPin.PIN_CLICK_HANDLERS[MOUSE_BUTTON_INDEX_LEFT][self.m_PinType] or ZO_MapPin.PIN_CLICK_HANDLERS[MOUSE_BUTTON_INDEX_RIGHT][self.m_PinType] then
			self.m_Control:SetDrawLevel(pinLevel)
		else
			self.m_Control:SetDrawLevel(0)
		end

		self.backgroundControl:SetDrawLevel(pinLevel)
		self.highlightControl:SetDrawLevel(pinLevel - 1)
		self.labelControl:SetDrawLevel(pinLevel + 1)

		if IsPinAnimated(self, singlePinData.isAnimated) then
			self:PlayTextureAnimation(singlePinData.framesWide, singlePinData.framesHigh, singlePinData.framesPerSecond)
		end

		if singlePinData.tint then
			local tint = GetPinTextureColor(self, singlePinData.tint)
			if tint then
				self.backgroundControl:SetColor(tint:UnpackRGBA())
			end
		else
			self.backgroundControl:SetColor(1, 1, 1, 1)
		end
	end
	self:BuildDependencies()
end

function AUI_Pin:SetLocation(xLoc, yLoc, radius, borderInformation)
	if not g_isInit then
		return
	end

    local valid = xLoc and yLoc and ZO_WorldMap_IsNormalizedPointInsideMapBounds(xLoc, yLoc)

    local myControl = self:GetControl()
    myControl:SetHidden(not valid)

    self.normalizedX = xLoc
    self.normalizedY = yLoc
    self.radius = radius
    self.borderInformation = borderInformation

    if valid then
        if radius and radius > 0 then

            if not self:IsKeepOrDistrict() then
                if not self.pinBlob then
			
                    self.pinBlob, self.pinBlobKey = g_mapPinManager:AcquirePinBlob()
                end
                self.pinBlob:SetHidden(false)
            end
        elseif borderInformation then
            if not self.polygonBlob then
                self.polygonBlob, self.polygonBlobKey = g_mapPinManager:AcquirePinPolygonBlob()
            end
            self.polygonBlob:SetHidden(false)
            self.polygonBlob:ClearPoints()
            for i, point in ipairs(borderInformation.borderPoints) do
                self.polygonBlob:AddPoint(point.x, point.y)
            end
        end

        self.backgroundControl:SetHidden(not self:ShouldShowPin())

        self:UpdateLocation()
        self:UpdateSize()
    end
end

function AUI_Pin:UpdateSize()
	if not g_isInit then
		return
	end

	local singlePinData = ZO_MapPin.PIN_DATA[self.m_AUIPinType]
	if singlePinData ~= nil then
		local control = self:GetControl()
		local hasNonZeroRadius = self.radius and self.radius > 0
		local baseSize = singlePinData.size or DEFAULT_PIN_SIZE
		local containerSize = AUI.Minimap.GetMapContainerSize()

		if hasNonZeroRadius then
			local pinDiameter = self.radius * 2 * containerSize

			if singlePinData.minAreaSize and pinDiameter < singlePinData.minAreaSize then
				pinDiameter = singlePinData.minAreaSize
			end

			control:SetShapeType(SHAPE_CIRCLE)
			control:SetDimensions(pinDiameter, pinDiameter)

			if self.pinBlob then
				self:UpdateAreaPinTexture()
				self.pinBlob:SetDimensions(pinDiameter, pinDiameter)
				control:SetHitInsets(0, 0, 0, 0)
			end
		end

		if self.polygonBlob then
			local width = self.borderInformation.borderWidth * containerSize
			local height = self.borderInformation.borderHeight * containerSize
			self.polygonBlob:SetDimensions(width, height)

			local centerColor = self:GetCenterColor()
			local r, g, b = centerColor:UnpackRGB()
			local alpha = 0.39
			self.polygonBlob:SetCenterColor(r, g, b, alpha)

			local borderColor = self:GetBorderColor()
			self.polygonBlob:SetBorderColor(borderColor:UnpackRGBA())
		end

		if self:ShouldShowPin() then
			local minSize = singlePinData.minSize or MIN_PIN_SIZE
			local scale = zo_clamp(AUI.Minimap.GetCurrentZoomValue(), MIN_PIN_SCALE, MAX_PIN_SCALE)
			local size = zo_max(((baseSize * scale) / GetUICustomScale() / 1.2), minSize)

			if self.m_AUIPinType == MAP_PIN_TYPE_PLAYER and AUI.Settings.Minimap.player_pin_size then
				size = size * AUI.Settings.Minimap.player_pin_size
			elseif self:IsGroupLeader() and AUI.Settings.Minimap.groupLeader_pin_size then	
				size = size * AUI.Settings.Minimap.groupLeader_pin_size
			elseif self:IsGroup() and AUI.Settings.Minimap.group_pin_size then	
				size = size * AUI.Settings.Minimap.group_pin_size				
			elseif AUI.Settings.Minimap.pin_size then
				size = size * AUI.Settings.Minimap.pin_size
			end

			control:SetDimensions(size, size)

			local insetX = singlePinData.insetX or 0
			local insetY = singlePinData.insetY or 0
			insetX = insetX * (size / baseSize)
			insetY = insetY * (size / baseSize)

			control:SetHitInsets(insetX, insetY, -insetX, -insetY)
		end
	end
end

function AUI_Pin:IsGroupLeader()
    return ZO_MapPin.GROUP_LEADER_PIN_TYPES[self.m_AUIPinType]
end

function AUI_MapPin_RefreshSkyshardPins()
    g_mapPinManager:RemovePins("skyshard")
    local showAcquiredSkyshards = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_ACQUIRED_SKYSHARDS)
    local showObjectives = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES)
    if showAcquiredSkyshards or showObjectives then
        local zoneId = ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap()
        local numSkyshardsInZone = GetNumSkyshardsInZone(zoneId)
        for skyshardIndex = 1, numSkyshardsInZone do
            local skyshardId = GetZoneSkyshardId(zoneId, skyshardIndex)
            local normalizedX, normalizedY, isShownInCurrentMap = GetNormalizedPositionForSkyshardId(skyshardId)
            if isShownInCurrentMap and ZO_WorldMap_IsNormalizedPointInsideMapBounds(normalizedX, normalizedY) then
                local discoveryStatus = GetSkyshardDiscoveryStatus(skyshardId)
                local pinType = nil
                if discoveryStatus == SKYSHARD_DISCOVERY_STATUS_ACQUIRED and showAcquiredSkyshards then
                    pinType = MAP_PIN_TYPE_SKYSHARD_COMPLETE
                elseif discoveryStatus == SKYSHARD_DISCOVERY_STATUS_DISCOVERED and showObjectives then                    
                    local _, zoneCompletionType, activityId = GetTrackedZoneStoryActivityInfo()
                    local isSkyshardTracked = zoneCompletionType == ZONE_COMPLETION_TYPE_SKYSHARDS and activityId == skyshardId
                    if not isSkyshardTracked then
                        pinType = MAP_PIN_TYPE_SKYSHARD_SEEN
                    end
                end
                if pinType then
                    local skyshardTag = ZO_MapPin.CreateSkyshardPinTag(skyshardId)
                    g_mapPinManager:CreatePin(pinType, skyshardTag, normalizedX, normalizedY)
                end
            end
        end
    end
end

local function AUI_MapPin_CreateSinglePOIPin(zoneIndex, poiIndex)
    local xLoc, zLoc, poiPinType, icon, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered, isNearby = GetPOIMapInfo(zoneIndex, poiIndex)

    if isShownInCurrentMap and (isDiscovered or isNearby) then
        if ZO_MapPin.POI_PIN_TYPES[poiPinType] then
            local poiType = GetPOIType(zoneIndex, poiIndex)

            if poiPinType ~= MAP_PIN_TYPE_POI_SEEN then
                -- Seen Wayshines are POIs, discovered Wayshrines are handled by AddWayshrines()
                -- Request was made by design to have houses and dungeons behave like wayshrines.
                if poiType == POI_TYPE_WAYSHRINE or poiType == POI_TYPE_HOUSE or poiType == POI_TYPE_GROUP_DUNGEON then
                    return
                end
            end

            local tag = ZO_MapPin.CreatePOIPinTag(zoneIndex, poiIndex, icon, linkedCollectibleIsLocked)
            g_mapPinManager:CreatePin(poiPinType, tag, xLoc, zLoc)

            local worldEventInstanceId = GetPOIWorldEventInstanceId(zoneIndex, poiIndex)

            if worldEventInstanceId ~= 0 then
                local worldEventTag = ZO_MapPin.CreateWorldEventPOIPinTag(worldEventInstanceId, zoneIndex, poiIndex)
                -- TODO: May need to add handling for additional event states
                g_mapPinManager:CreatePin(MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE, worldEventTag, xLoc, zLoc)
            end
        end
    end
end

local function AUI_MapPin_RefreshSinglePOI(zoneIndex, poiIndex)
    g_mapPinManager:RemovePins("poi", zoneIndex, poiIndex)

    local worldEventInstanceId = GetPOIWorldEventInstanceId(zoneIndex, poiIndex)
    if worldEventInstanceId ~= 0 then
        g_mapPinManager:RemovePins("worldEventPOI", worldEventInstanceId)
    end

    if ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES) then
        AUI_MapPin_CreateSinglePOIPin(zoneIndex, poiIndex)
    end
end

local function AUI_MapPin_RefreshAllPOIs()
    g_mapPinManager:RemovePins("poi")
	g_mapPinManager:RemovePins("worldEventPOI")
    if ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES) then
        local zoneIndex = GetCurrentMapZoneIndex()
        for i = 1, GetNumPOIs(zoneIndex) do
            AUI_MapPin_CreateSinglePOIPin(zoneIndex, i)
        end
    end
end

local function AddWorldEvent(worldEventInstanceId)
	if ZO_WorldMap_DoesMapHideWorldEventPins() then
		return
	end

	local context = GetWorldEventLocationContext(worldEventInstanceId)

	if context == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
		local numUnits = GetNumWorldEventInstanceUnits(worldEventInstanceId)
		for i = 1, numUnits do
			local unitTag = GetWorldEventInstanceUnitTag(worldEventInstanceId, i)
			local pinType = GetWorldEventInstanceUnitPinType(worldEventInstanceId, unitTag)
			if pinType ~= MAP_PIN_TYPE_INVALID then
				local xLoc, yLoc, _, isInCurrentMap = GetMapPlayerPosition(unitTag)
				if isInCurrentMap then
					local tag = ZO_MapPin.CreateWorldEventUnitPinTag(worldEventInstanceId, unitTag)
					g_mapPinManager:CreatePin(pinType, tag, xLoc, yLoc)
				end
			end
		end
	elseif context == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
		local zoneIndex, poiIndex = GetWorldEventPOIInfo(worldEventInstanceId)
		local xLoc, zLoc,_,_, isShownInCurrentMap,_, isDiscovered, isNearby = GetPOIMapInfo(zoneIndex, poiIndex)

		if isShownInCurrentMap and (isDiscovered or isNearby) then
			AUI_MapPin_RefreshSinglePOI(zoneIndex, poiIndex)
		end
	end
end

AUI_KeepNetwork = ZO_KeepNetwork:Subclass()
	
function AUI_KeepNetwork:GetKeepNetworkOffset(linkX, linkY)
	local containerSize = AUI.Minimap.GetMapContainerSize()	
	local offsetX = linkX * containerSize
	local offsetY = linkY * containerSize		
	
	if AUI.Settings.Minimap.rotate then	
		local headingCos, headingSin = AUI.Minimap.GetRotationData()
		local playerX, playerY = AUI.Minimap.GetPlayerPosition()
		local x = (offsetX - playerX)
		local y = (offsetY - playerY)
			
		offsetX = (headingCos * x) - (headingSin * y)
		offsetY = (headingSin * x) + (headingCos * y)			
	end
	
	return offsetX, offsetY
end	

function AUI_KeepNetwork:UpdateLinkPostionsForNewMapSize()
	local links = self.linkPool:GetActiveObjects()
	for _, link in pairs(links) do
		local startX, startY = self:GetKeepNetworkOffset(link.startNX, link.startNY)
		local endX, endY = self:GetKeepNetworkOffset(link.endNX, link.endNY)

		link:ClearAnchors()
		
		if AUI.Settings.Minimap.rotate then
			link:SetAnchor(TOPLEFT, nil, CENTER, startX, startY)
			link:SetAnchor(BOTTOMRIGHT, nil, CENTER, endX, endY)
		else
			link:SetAnchor(TOPLEFT, nil, TOPLEFT, startX, startY)
			link:SetAnchor(BOTTOMRIGHT, nil, TOPLEFT, endX, endY)	
		end
	end
end

function AUI_KeepNetwork:UpdateAllLocations()
	self:UpdateLinkPostionsForNewMapSize()
end

local g_mapLocationManager = AUI_MapLocationPins_Manager:New(AUI_MapContainer)
local g_keepNetworkManager = AUI_KeepNetwork:New(AUI_MapContainer)	

local function AUI_MapPin_RefreshWorldEvent(worldEventInstanceId)
	g_mapPinManager:RemovePins("worldEventUnit", worldEventInstanceId)
	g_mapPinManager:RemovePins("worldEventPOI", worldEventInstanceId)

	AddWorldEvent(worldEventInstanceId)
end

local function GetNextWorldEventInstanceIdIter(state, var1)
	return GetNextWorldEventInstanceId(var1)
end

local function AUI_MapPin_RefreshWorldEvents()
	g_mapPinManager:RemovePins("worldEventUnit")
	g_mapPinManager:RemovePins("worldEventPOI")

	for worldEventInstanceId in GetNextWorldEventInstanceIdIter do
		AddWorldEvent(worldEventInstanceId)
	end
end
	
local ZONE_COMPLETION_TYPE_WITHOUT_PIN =
{
	[ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS] = true,
	[ZONE_COMPLETION_TYPE_SKYSHARDS] = true,
	[ZONE_COMPLETION_TYPE_FEATURED_ACHIEVEMENTS] = true,
}	
	
local function AUI_MapPin_RefreshSuggestionPins()
	g_mapPinManager:RemovePins("suggestion")

	isZoneStoryTracked = false
	
	if gApiVersion >= 101042 then
		isZoneStoryTracked = IsZoneStoryTracked()
	else
		isZoneStoryTracked = IsZoneStoryActivelyTracking()
	end
	
	if isZoneStoryTracked then
		local zoneId, zoneCompletionType, activityId = GetTrackedZoneStoryActivityInfo()
		if not ZONE_COMPLETION_TYPE_WITHOUT_PIN[zoneCompletionType] then
			local normalizedX, normalizedY, normalizedRadius, isShownInCurrentMap = GetNormalizedPositionForZoneStoryActivityId(zoneId, zoneCompletionType, activityId)
			if isShownInCurrentMap then
				if zoneCompletionType == ZONE_COMPLETION_TYPE_PRIORITY_QUESTS then
					if not ZO_WorldMap_DoesMapHideQuestPins() then
						local questOfferTag = ZO_MapPin.CreateZoneStoryTag(zoneId, zoneCompletionType, activityId)
						questOfferTag.isBreadcrumb = false -- TODO: Zone Stories: Hook up quest offer breadcrumbing
						g_mapPinManager:CreatePin(MAP_PIN_TYPE_TRACKED_QUEST_OFFER_ZONE_STORY, questOfferTag, normalizedX, normalizedY, normalizedRadius)
					end
				else
					-- Everything else is a POI
					local zoneIndex, poiIndex = GetPOIIndices(activityId)
					if zoneIndex == GetCurrentMapZoneIndex() then
						local DONT_ENFORCE_NEARBY = false
						local icon = GetPOIPinIcon(activityId, DONT_ENFORCE_NEARBY)
						local suggestedPOITag = ZO_MapPin.CreatePOIPinTag(zoneIndex, poiIndex, icon)
						g_mapPinManager:CreatePin(MAP_PIN_TYPE_POI_SUGGESTED, suggestedPOITag, normalizedX, normalizedY, normalizedRadius)
					end
				end
			end
		end
	end
end

local function AUI_MapPin_RefreshObjectives()
   g_mapPinManager:RemovePins("objective")
    ZO_ClearNumericallyIndexedTable(g_objectiveMovingPins)

    local mapFilterType = GetMapFilterType()
    if mapFilterType ~= MAP_FILTER_TYPE_AVA_CYRODIIL and mapFilterType ~= MAP_FILTER_TYPE_BATTLEGROUND then
        return
    end

    local numObjectives = GetNumObjectives()

    local worldMapAvAPinsShown = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_AVA_OBJECTIVES)

    for i = 1, numObjectives do
        local keepId, objectiveId, bgContext = GetObjectiveIdsForIndex(i)
        local isEnabled = IsObjectiveEnabled(keepId, objectiveId, bgContext)

        if isEnabled then
            local isVisible = IsObjectiveObjectVisible(keepId, objectiveId, bgContext)
            if ZO_WorldMap_IsObjectiveShown(keepId, objectiveId, bgContext) and IsLocalBattlegroundContext(bgContext) then
                --spawn locations
                local spawnPinType, spawnX, spawnY = GetObjectiveSpawnPinInfo(keepId, objectiveId, bgContext)
                if spawnPinType ~= MAP_PIN_TYPE_INVALID then
                    if worldMapAvAPinsShown then
                        if ZO_WorldMap_IsNormalizedPointInsideMapBounds(spawnX, spawnY) then
                            local spawnTag = ZO_MapPin.CreateObjectivePinTag(keepId, objectiveId, bgContext)
                            g_mapPinManager:CreatePin(spawnPinType, spawnTag, spawnX, spawnY)
                        end
                    end
                end

                --return locations
                local returnPinType, returnX, returnY, returnContinuousUpdate = GetObjectiveReturnPinInfo(keepId, objectiveId, bgContext)
                if returnPinType ~= MAP_PIN_TYPE_INVALID then
                    local returnTag = ZO_MapPin.CreateObjectivePinTag(keepId, objectiveId, bgContext)
                    local returnPin = g_mapPinManager:CreatePin(returnPinType, returnTag, returnX, returnY)

                    if returnContinuousUpdate then
                        table.insert(g_objectiveMovingPins, returnPin)
                    end
                end

                -- current locations
                local pinType, currentX, currentY, continuousUpdate = GetObjectivePinInfo(keepId, objectiveId, bgContext)
                if isVisible and pinType ~= MAP_PIN_TYPE_INVALID then
                    if worldMapAvAPinsShown then
                        if ZO_WorldMap_IsNormalizedPointInsideMapBounds(currentX, currentY) then
                            local objectiveTag = ZO_MapPin.CreateObjectivePinTag(keepId, objectiveId, bgContext)
                            local objectivePin = g_mapPinManager:CreatePin(pinType, objectiveTag, currentX, currentY)

                            if objectivePin then
                                local auraPinType = GetObjectiveAuraPinInfo(keepId, objectiveId, bgContext)
                                local auraPin
                                if auraPinType ~= MAP_PIN_TYPE_INVALID then
                                    local auraTag = ZO_MapPin.CreateObjectivePinTag(keepId, objectiveId, bgContext)
                                    auraPin = g_mapPinManager:CreatePin(auraPinType, auraTag, currentX, currentY)
                                    objectivePin:AddScaleChild(auraPin)
                                end

                                if continuousUpdate then
                                    table.insert(g_objectiveMovingPins, objectivePin)
                                    if auraPin then
                                        table.insert(g_objectiveMovingPins, auraPin)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function AUI_MapPin_RefreshKillLocations()
    g_mapPinManager:RemovePins("killLocation")
    RemoveMapPinsInRange(MAP_PIN_TYPE_TRI_BATTLE_SMALL, MAP_PIN_TYPE_EBONHEART_VS_DAGGERFALL_LARGE)

    --spawn locations
    for i = 1, GetNumKillLocations() do
        local pinType, normalizedX, normalizedY = GetKillLocationPinInfo(i)
        if pinType ~= MAP_PIN_TYPE_INVALID then
            if ZO_WorldMap_IsPinGroupShown(MAP_FILTER_KILL_LOCATIONS) then
                if ZO_WorldMap_IsNormalizedPointInsideMapBounds(normalizedX, normalizedY) then
                    g_mapPinManager:CreatePin(pinType, i, normalizedX, normalizedY)
                end
            end
        end
    end
end

local function AUI_MapPin_RefreshForwardCamps()
    g_mapPinManager:RemovePins("forwardCamp")

    if GetMapFilterType() ~= MAP_FILTER_TYPE_AVA_CYRODIIL then
        return
    end
    if not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_AVA_GRAVEYARDS) then return end

    for i = 1, GetNumForwardCamps(BGQUERY_LOCAL) do
        local pinType, normalizedX, normalizedY, normalizedRadius, useable = GetForwardCampPinInfo(BGQUERY_LOCAL, i)
        if ZO_WorldMap_IsNormalizedPointInsideMapBounds(normalizedX, normalizedY) then
            if not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_AVA_GRAVEYARD_AREAS) then
                normalizedRadius = 0
            end

            g_mapPinManager:CreatePin(pinType, ZO_MapPin.CreateForwardCampPinTag(i), normalizedX, normalizedY, normalizedRadius)
        end
    end
end

local function IsMapShowingBattlegroundContext(bgContext)
    return IsLocalBattlegroundContext(bgContext)
end

local function AddKeep(keepId, bgContext)
    local historyPercent = ZO_WorldMap_GetHistoryPercentToUse()
    local pinType, locX, locY = GetHistoricalKeepPinInfo(keepId, bgContext, historyPercent)
    if pinType ~= MAP_PIN_TYPE_INVALID then
        local keepUnderAttack = GetHistoricalKeepUnderAttack(keepId, bgContext, historyPercent)
        local keepUnderAttackPinType = ZO_MapPin.GetUnderAttackPinForKeepPin(pinType)

        if ZO_WorldMap_IsNormalizedPointInsideMapBounds(locX, locY) then
            local keepType = GetKeepType(keepId)
            if ZO_WorldMap_IsPinGroupShown(MAP_FILTER_RESOURCE_KEEPS) or keepType ~= KEEPTYPE_RESOURCE then
                if keepType == KEEPTYPE_IMPERIAL_CITY_DISTRICT and GetCurrentMapIndex() ~= g_imperialCityMapIndex then
                    return
                end

                if IsMapShowingBattlegroundContext(bgContext) then
                    local underAttackPin = true
                    local notUnderAttackPin = false

                    local existingKeepPin = g_mapPinManager:FindPin("keep", keepId, notUnderAttackPin)
                    if not existingKeepPin then
                        local tag = ZO_MapPin.CreateKeepPinTag(keepId, bgContext, notUnderAttackPin)
                        g_mapPinManager:CreatePin(pinType, tag, locX, locY)

                        if keepUnderAttack then
                            tag = ZO_MapPin.CreateKeepPinTag(keepId, bgContext, underAttackPin)
                            g_mapPinManager:CreatePin(keepUnderAttackPinType, tag, locX, locY)
                        end
                    end
                end
            end
        end
    end
end

local function IsPresentlyShowingKeeps()
    return GetMapFilterType() == MAP_FILTER_TYPE_AVA_CYRODIIL or GetMapFilterType() == MAP_FILTER_TYPE_AVA_IMPERIAL
end

local function AUI_MapPin_RefreshKeepUnderAttack(keepId, bgContext)
    local UNDER_ATTACK_PIN = true
    local NOT_UNDER_ATTACK_PIN = false
    local existingKeepPin = g_mapPinManager:FindPin("keep", keepId, NOT_UNDER_ATTACK_PIN)
    if existingKeepPin then
        local historyPercent = ZO_WorldMap_GetHistoryPercentToUse()
        local keepUnderAttack = GetHistoricalKeepUnderAttack(keepId, bgContext, historyPercent)
        local existingUnderAttackKeepPin = g_mapPinManager:FindPin("keep", keepId, UNDER_ATTACK_PIN)
        local hasUnderAttackPin = existingUnderAttackKeepPin ~= nil
        if keepUnderAttack ~= hasUnderAttackPin then
            if keepUnderAttack then
                --Add under attack pin
                local pinType, locX, locY = GetHistoricalKeepPinInfo(keepId, bgContext, historyPercent)
                local keepUnderAttackPinType = ZO_MapPin.GetUnderAttackPinForKeepPin(pinType)
                local tag = ZO_MapPin.CreateKeepPinTag(keepId, bgContext, UNDER_ATTACK_PIN)
                g_mapPinManager:CreatePin(keepUnderAttackPinType, tag, locX, locY)
            else
                --Remove under attack pin
                g_mapPinManager:RemovePins("keep", keepId, UNDER_ATTACK_PIN)
            end
        end
    end
end

local function AUI_MapPin_RefreshKeep(keepId, bgContext)
	if not AUI.Minimap.IsLoaded() then
		return
	end	
		
    g_mapPinManager:RemovePins("keep", keepId)

    if IsPresentlyShowingKeeps() then
        AddKeep(keepId, bgContext)
    end	
end

local function AUI_MapPin_RefreshKeeps(keepId)
    g_mapPinManager:RemovePins("keep")

    if IsPresentlyShowingKeeps() then
        local numKeeps = GetNumKeeps()
        for i = 1, numKeeps do
            local keepId, bgContext = GetKeepKeysByIndex(i)
            AddKeep(keepId, bgContext)
        end
    end
end

local function IsShowingCosmicMap()
    return GetMapType() == MAPTYPE_COSMIC
end

local function AUI_MapPin_RefreshMapPings()
    g_mapPinManager:RemovePins("pings")

    if not IsShowingCosmicMap() then
        -- We don't want these manual player pings showing up on the Aurbis
        for i = 1, GROUP_SIZE_MAX do
            local unitTag = ZO_Group_GetUnitTagForGroupIndex(i)
            local x, y = GetMapPing(unitTag)

            if x ~= 0 and y ~= 0 then
                g_mapPinManager:CreatePin(MAP_PIN_TYPE_PING, unitTag, x, y)
            end
        end

        -- Add rally point
        local x, y = GetMapRallyPoint()
        if x ~= 0 and y ~= 0 then
            g_mapPinManager:CreatePin(MAP_PIN_TYPE_RALLY_POINT, "rally", x, y)
        end

        -- Add Player Waypoint
        x, y = GetMapPlayerWaypoint()
        if x ~= 0 and y ~= 0 then
            g_mapPinManager:CreatePin(MAP_PIN_TYPE_PLAYER_WAYPOINT , "waypoint", x, y)
        end

        -- Add Quest Ping
        if g_questPingData then
            local pins = {}
            g_mapPinManager:AddPinsToArray(pins, "quest", g_questPingData.questIndex)
            for _, pin in ipairs(pins) do
                if pin:DoesQuestDataMatchQuestPingData() then
                    local tag = ZO_MapPin.CreateQuestPinTag(g_questPingData.questIndex, g_questPingData.stepIndex, g_questPingData.conditionIndex)
                    local xLoc, yLoc = pin:GetNormalizedPosition()
                    g_mapPinManager:CreatePin(MAP_PIN_TYPE_QUEST_PING, tag, xLoc, yLoc)
                end
            end
        end
    end

    -- Add auto navigation target, and we do want this on the Aurbis
    if HasAutoMapNavigationTarget() then
        local normalizedX, normalizedY = GetAutoMapNavigationNormalizedPositionForCurrentMap()
        g_mapPinManager:CreatePin(MAP_PIN_TYPE_AUTO_MAP_NAVIGATION_PING, "pings", normalizedX, normalizedY)
    end
end

local function AUI_MapPin_RefreshWayshrines()
	g_mapPinManager:RemovePins("fastTravelWayshrine")

	-- Dungeons no longer show wayshrines of any kind (possibly pending some system rework)
	-- Design rule, don't show wayshrine pins on cosmic, even if they're in the map
	if IsShowingCosmicMap() or not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_WAYSHRINES) then
		return
	end

	local numFastTravelNodes = GetNumFastTravelNodes()
	for nodeIndex = 1, numFastTravelNodes do
		local known, name, normalizedX, normalizedY, icon, glowIcon, poiType, isLocatedInCurrentMap, linkedCollectibleIsLocked = GetFastTravelNodeInfo(nodeIndex)

		if known and isLocatedInCurrentMap and ZO_WorldMap_IsNormalizedPointInsideMapBounds(normalizedX, normalizedY) then
			local isCurrentLoc = g_fastTravelNodeIndex == nodeIndex

			if isCurrentLoc then
				glowIcon = nil
			end

			local tag = ZO_MapPin.CreateTravelNetworkPinTag(nodeIndex, icon, glowIcon, linkedCollectibleIsLocked)

			local pinType = isCurrentLoc and MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC or MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE

			g_mapPinManager:CreatePin(pinType, tag, normalizedX, normalizedY)
		end
	end
end

local function AUI_MapPin_RefreshPlayer()
	g_mapPinManager.playerPin:SetData(MAP_PIN_TYPE_PLAYER, "player")
	g_mapPinManager.playerPin:UpdateSize()
end

function AUI_MapPin_RefreshCompanionPins()
    g_mapPinManager:RemovePins("companion")
    if ZO_WorldMap_IsPinGroupShown(MAP_FILTER_COMPANIONS) and HasActiveCompanion() and not ZO_WorldMap_DoesMapHideCompanionPins() then
        local x, y, _, isInCurrentMap = GetMapPlayerPosition("companion")
        if isInCurrentMap then
            local companionPin = g_mapPinManager:CreatePin(MAP_PIN_TYPE_ACTIVE_COMPANION, "companion")
            if companionPin then
                companionPin:SetLocation(x, y)
            end
        end
    end
end

local function AUI_MapPin_RefreshGroupPins()
    g_mapPinManager:RemovePins("group")
    ZO_ClearTable(g_activeGroupPins)

    if ZO_WorldMap_IsPinGroupShown(MAP_FILTER_GROUP_MEMBERS) and not IsShowingCosmicMap() then
        local isInDungeon = GetMapContentType() == MAP_CONTENT_DUNGEON
        local isInHouse = GetCurrentZoneHouseId() ~= 0
        for i = 1, GROUP_SIZE_MAX do
            local groupTag = ZO_Group_GetUnitTagForGroupIndex(i)
            local isBreadcrumbed = IsUnitWorldMapPositionBreadcrumbed(groupTag)
            if DoesUnitExist(groupTag) and not AreUnitsEqual("player", groupTag) and IsUnitOnline(groupTag) then
                local isGroupMemberHiddenByInstance = false
                -- If we're in an instance and it has its own map, it's going to be a dungeon map or house. Don't show on the map if we're on different instances/layers
                -- If it doesn't have its own map, we're okay to show the group member regardless of instance
                if DoesCurrentMapMatchMapForPlayerLocation() and IsGroupMemberInSameWorldAsPlayer(groupTag) and (isInDungeon or isInHouse) then
                    if not IsGroupMemberInSameInstanceAsPlayer(groupTag) then
                        -- We're in the same world as the group member, but a different instance
                        isGroupMemberHiddenByInstance = true
                    elseif not IsGroupMemberInSameLayerAsPlayer(groupTag) then
                        -- We're in the same instance as the group member, but a different layer
                        isGroupMemberHiddenByInstance = not isBreadcrumbed 
                    end
                end

                if not isGroupMemberHiddenByInstance then
                    local x, y, _, isInCurrentMap = GetMapPlayerPosition(groupTag)
                    if isInCurrentMap then
                        local isLeader = IsUnitGroupLeader(groupTag)
                        local tagData = groupTag
                        if isBreadcrumbed then
                            tagData =
                            {
                                groupTag = groupTag,
                                isBreadcrumb = true
                            }
                        end

                        local groupPin = g_mapPinManager:CreatePin(isLeader and MAP_PIN_TYPE_GROUP_LEADER or MAP_PIN_TYPE_GROUP, tagData)
                        if groupPin then
                            g_activeGroupPins[groupTag] = groupPin
                            groupPin:SetLocation(x, y)
                        end
                    end
                end
            end
        end
    end
end

local function AUI_MapPin_RefreshLocations()
	if not g_mapLocationManager then
		return
	end
	
	g_mapLocationManager:RefreshLocations()
end

local function AUI_MapPin_TryAddDigSiteToMap(digSiteId, isTracked)
    local centerX, centerZ, isShownInCurrentMap = GetDigSiteNormalizedCenterPosition(digSiteId)
    if isShownInCurrentMap then
        local points = {}

        local minX = 1.0
        local maxX = 0.0
        local minY = 1.0
        local maxY = 0.0

        local borderPoints = { GetDigSiteNormalizedBorderPoints(digSiteId) }
        for i = 1, #borderPoints, 2 do -- loop by 2 because we are getting x and z coordinates
            local x = borderPoints[i]
            local y = borderPoints[i + 1] -- UI is going to treat z as y

            minX = zo_min(x, minX)
            maxX = zo_max(x, maxX)

            minY = zo_min(y, minY)
            maxY = zo_max(y, maxY)

            local coordinates =
            {
                x = x,
                y = y,
            }
            table.insert(points, coordinates)
        end

        for index, coordinates in ipairs(points) do
            coordinates.x = zo_normalize(coordinates.x, minX, maxX)
            coordinates.y = zo_normalize(coordinates.y, minY, maxY)
        end

        local borderInformation =
        {
            borderPoints = points,
            borderWidth = maxX - minX,
            borderHeight = maxY - minY,
        }

        local pinType = isTracked and MAP_PIN_TYPE_TRACKED_ANTIQUITY_DIG_SITE or MAP_PIN_TYPE_ANTIQUITY_DIG_SITE


		local tag = ZO_MapPin.CreateAntiquityDigSitePinTag(digSiteId)
		local NO_RADIUS = 0
		g_mapPinManager:CreatePin(pinType, tag, centerX, centerZ, NO_RADIUS, borderInformation)
    end
end

local function AUI_MapPin_SetFocusedAntiquityId(antiquityId)
    g_focusedAntiquityId = antiquityId
end

local function AUI_MapPin_RefreshAntiquityDigSites()
    g_mapPinManager:RemovePins("antiquityDigSite")
    g_mapPinManager:RemovePins("pings", MAP_PIN_TYPE_ANTIQUITY_DIG_SITE_PING)
	
    if ZO_WorldMap_DoesMapHideQuestPins() or not ZO_WorldMap_IsPinGroupShown(MAP_FILTER_DIG_SITES) then
        return false
    end

    local numInProgressAntiquities = GetNumInProgressAntiquities()
    for antiquityIndex = 1, numInProgressAntiquities do
        if g_focusedAntiquityId == nil or GetInProgressAntiquityId(antiquityIndex) == g_focusedAntiquityId then
            local numDigSites = GetNumDigSitesForInProgressAntiquity(antiquityIndex)
            for digSiteIndex = 1, numDigSites do
                local digSiteId = GetInProgressAntiquityDigSiteId(antiquityIndex, digSiteIndex)
				AUI_MapPin_TryAddDigSiteToMap(digSiteId, IsDigSiteAssociatedWithTrackedAntiquity(digSiteId))
            end
        end
    end
end

local function AUI_MapPin_UpdateAllLocations()
	for _, tableData in pairs(g_mapPinManager.m_keyToPinMapping) do
		for _, pinKeys in pairs(tableData) do
			for _, pinKey in pairs(pinKeys) do
				local pin = g_mapPinManager:GetExistingObject(pinKey) 
				if pin then
					pin:UpdateLocation()				
				end
			end
		end
	end	

	g_keepNetworkManager:UpdateAllLocations()	
end

local function AUI_MapPin_RefreshKeepLinks()
	g_keepNetworkManager:RefreshLinks()	
	g_keepNetworkManager:UpdateAllLocations()
end

local function AUI_MapPin_RefreshQuests()
	WORLD_MAP_QUEST_BREADCRUMBS:RefreshAllQuests()
end

local EVENT_HANDLERS =
{
	[EVENT_NON_COMBAT_BONUS_CHANGED] = function()
		AUI_MapPin_RefreshLocations()
	end,
		
	[EVENT_POI_UPDATED] = function(eventCode, zoneIndex, poiIndex)
		AUI_MapPin_RefreshSinglePOI(zoneIndex, poiIndex)
		AUI_MapPin_RefreshLocations()
	end,
	
	[EVENT_UNIT_CREATED] = function(eventCode, unitTag)
		local inGroup = ZO_Group_IsGroupUnitTag(unitTag)
		if inGroup and not AreUnitsEqual("player", unitTag) then
			AUI_MapPin_RefreshGroupPins()
		end
	end,

	[EVENT_UNIT_DESTROYED] = function(eventCode, unitTag)
		local inGroup = ZO_Group_IsGroupUnitTag(unitTag)
		if inGroup and not AreUnitsEqual("player", unitTag) then
			AUI_MapPin_RefreshGroupPins()
		end
	end,	
	
	[EVENT_MAP_PING] = function(eventCode, pingEventType, pingType, pingTag, x, y, isPingOwner)
		if not g_mapPinManager then
			return
		end	
	
		if pingEventType == PING_EVENT_ADDED then
			g_mapPinManager:RemovePins("pings", pingType, pingTag)
			g_mapPinManager:CreatePin(pingType, pingTag, x, y)
		elseif pingEventType == PING_EVENT_REMOVED then
			g_mapPinManager:RemovePins("pings", pingType, pingTag)
		end		
			
	end,
	
	[EVENT_GROUP_MEMBER_LEFT] = function(evt, characterName, reason, wasLocalPlayer, amLeader)
		if wasLocalPlayer then
			AUI_MapPin_RefreshGroupPins()
		end
	end,	
	
	[EVENT_GROUP_UPDATE] = function(eventCode)
		AUI_MapPin_RefreshGroupPins()
	end,	
	
	[EVENT_GROUP_MEMBER_CONNECTED_STATUS] = function()
		AUI_MapPin_RefreshGroupPins()
	end,	
	
	[EVENT_COMPANION_ACTIVATED] = function()
		AUI_MapPin_RefreshCompanionPins()
	end,	
	
	[EVENT_COMPANION_DEACTIVATED] = function()
		AUI_MapPin_RefreshCompanionPins()
	end,	
	
	[EVENT_SCREEN_RESIZED] = function()
		AUI.Minimap.Pin.RefreshPins()
	end,	
	
	[EVENT_OBJECTIVES_UPDATED] = AUI_MapPin_RefreshObjectives,
	[EVENT_OBJECTIVE_CONTROL_STATE] = AUI_MapPin_RefreshObjectives,
	
	[EVENT_KEEP_ALLIANCE_OWNER_CHANGED] = function(_, keepId, bgContext)
		AUI_MapPin_RefreshKeep(keepId, bgContext)
    end,	
	
    [EVENT_KEEP_UNDER_ATTACK_CHANGED] = function(_, keepId, bgContext)
		AUI_MapPin_RefreshKeepUnderAttack(keepId, bgContext)
    end,	
    [EVENT_KEEP_IS_PASSABLE_CHANGED] = function(_, keepId, bgContext)
         AUI_MapPin_RefreshKeep(keepId, bgContext)
     end,
    [EVENT_KEEP_PIECE_DIRECTIONAL_ACCESS_CHANGED] = function(_, keepId, bgContext)
        AUI_MapPin_RefreshKeep(keepId, bgContext)
    end,
    [EVENT_KEEP_GATE_STATE_CHANGED] = AUI_MapPin_RefreshKeep(keepId, BGQUERY_LOCAL),
	
    [EVENT_KEEP_INITIALIZED] = function(_, keepId, bgContext)
        AUI_MapPin_RefreshKeep(keepId, bgContext)
    end,

    [EVENT_KEEPS_INITIALIZED] = AUI_MapPin_RefreshKeeps,	
		
	[EVENT_KILL_LOCATIONS_UPDATED] = AUI_MapPin_RefreshKillLocations,
	
    [EVENT_FORWARD_CAMPS_UPDATED] = function()
		AUI_MapPin_RefreshForwardCamps()
	end,	
	
	[EVENT_FAST_TRAVEL_KEEP_NETWORK_UPDATED] = function() AUI_MapPin_RefreshKeepLinks() end,
	
	[EVENT_START_FAST_TRAVEL_KEEP_INTERACTION] = function(eventCode, keepId)
		g_keepNetworkManager:SetOpenNetwork(keepId)
	end,	
	
	[EVENT_END_FAST_TRAVEL_KEEP_INTERACTION] = function()
		g_keepNetworkManager:ClearOpenNetwork()
	end,	
	
	[EVENT_ZONE_CHANGED] = function(eventId, zoneName, subzoneName)
		if WORLD_MAP_MANAGER:IsInMode(MAP_MODE_AVA_KEEP_RECALL) and subzoneName ~= "" then
			AUI_MapPin_RefreshKeepLinks()
		end
	end,	
	
	[EVENT_PLAYER_COMBAT_STATE] = function()
		if WORLD_MAP_MANAGER:IsInMode(MAP_MODE_AVA_KEEP_RECALL) then
			AUI_MapPin_RefreshKeepLinks()
		end
	end,
	[EVENT_PLAYER_DEAD] = function()
		if WORLD_MAP_MANAGER:IsInMode(MAP_MODE_AVA_KEEP_RECALL) then
			AUI_MapPin_RefreshKeepLinks()
		end
	end,		
	
	[EVENT_LEADER_UPDATE] = function(eventCode)
		AUI_MapPin_RefreshGroupPins()
	end,				

	[EVENT_FAST_TRAVEL_NETWORK_UPDATED] = AUI_MapPin_RefreshWayshrines,

	[EVENT_PLAYER_ACTIVATED] = function()
		AUI_MapPin_RefreshGroupPins()
	end,
	
	[EVENT_WORLD_EVENTS_INITIALIZED] = function()
		AUI_MapPin_RefreshWorldEvents()
	end,

	[EVENT_WORLD_EVENT_ACTIVATED] = function(_, worldEventInstanceId)
		AUI_MapPin_RefreshWorldEvent(worldEventInstanceId)
	end,

	[EVENT_WORLD_EVENT_DEACTIVATED] = function(_, worldEventInstanceId)
		AUI_MapPin_RefreshWorldEvent(worldEventInstanceId)
	end,

	[EVENT_WORLD_EVENT_UNIT_CREATED] = function(_, worldEventInstanceId)
		AUI_MapPin_RefreshWorldEvent(worldEventInstanceId)
	end,

	[EVENT_WORLD_EVENT_UNIT_DESTROYED] = function(_, worldEventInstanceId)
		AUI_MapPin_RefreshWorldEvent(worldEventInstanceId)
	end,

	[EVENT_WORLD_EVENT_UNIT_CHANGED_PIN_TYPE] = function(_, worldEventInstanceId)
		AUI_MapPin_RefreshWorldEvent(worldEventInstanceId)
	end,
		
	[EVENT_REVEAL_ANTIQUITY_DIG_SITES_ON_MAP] = function(_, antiquityId)
		AUI_MapPin_SetFocusedAntiquityId(antiquityId)
	end,

	[EVENT_ANTIQUITY_DIGGING_GAME_OVER] = function(_, antiquityId)
		AUI_MapPin_RefreshAntiquityDigSites()
	end,

	[EVENT_ANTIQUITY_DIG_SITES_UPDATED] = function(_, antiquityId)
		AUI_MapPin_RefreshAntiquityDigSites()
	end,
	
	[EVENT_GROUP_MEMBER_SUBZONE_CHANGED] = function()
		AUI_MapPin_RefreshGroupPins()
	end,	
	
	[EVENT_ZONE_STORY_ACTIVITY_TRACKED] = function()
		AUI_MapPin_RefreshSkyshardPins()
	end,

	[EVENT_ZONE_STORY_ACTIVITY_UNTRACKED] = function()
		AUI_MapPin_RefreshSkyshardPins()
	end,	
	
	[EVENT_SKYSHARDS_UPDATED] = function()
		AUI_MapPin_RefreshSkyshardPins()
	end,		
}

local UpdateMovingPins
do
    local g_worldEventUnitPins = {}
    
    function UpdateMovingPins()
		for groupTag, groupPin in pairs(g_activeGroupPins) do
			local x, y = GetMapPlayerPosition(groupTag)
			local pinType = AUI.Minimap.Pin.GetGroupStatePinType(groupTag)	
			
			if pinType ~= groupPin.m_AUIPinType then	
				groupPin:SetData(pinType, groupTag)
			end
			
			groupPin:SetLocation(x, y)
		end
		
		local companionPin = g_mapPinManager:FindPin("companion")
		if companionPin then
			local xLoc, yLoc = GetMapPlayerPosition(companionPin:GetUnitTag())
			companionPin:SetLocation(xLoc, yLoc)
		end
		
		for _, pin in ipairs(g_objectiveMovingPins) do
			local pinKey = g_objectiveMovingPins[i]
			local pin = g_mapPinManager:GetExistingObject(pinKey)
			if pin then
				local pinType, currentX, currentY = GetAvAObjectivePinInfo(pin:GetAvAObjectiveKeepId(), pin:GetAvAObjectiveObjectiveId(), pin:GetBattlegroundContext())
				pin:SetLocation(currentX, currentY)
			end
		end
		
		g_mapPinManager:AddPinsToArray(g_worldEventUnitPins, "worldEventUnit")	
		for _, pin in ipairs(g_worldEventUnitPins) do
			local xLoc, yLoc = GetMapPlayerPosition(pin:GetUnitTag())
			pin:SetLocation(xLoc, yLoc)
		end
		
		ZO_ClearNumericallyIndexedTable(g_worldEventUnitPins)	
    end
end

function AUI.Minimap.Pin.Load()
	if not g_isInit then	
		AUI.Minimap.Pin.SetPinData()
	
		g_mapPinManager:CreatePin(MAP_PIN_TYPE_PLAYER, "player")	
	
		for event, handler in pairs(EVENT_HANDLERS) do
			EVENT_MANAGER:RegisterForEvent("AUI_MapPin", event, handler)
		end
		
		FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerAssistStateChanged", function(unassistedData, assistedData)
			AUI_MapPin_RefreshQuests()
		end)
		
		EVENT_MANAGER:RegisterForUpdate("AUI_OnUpdateMovingPins", 50, UpdateMovingPins)
		
		g_isInit = true
	end
end

function AUI.Minimap.Pin.Unload()
	if g_mapLocationManager then
		g_mapLocationManager:ReleaseAllObjects()
	end
	
	if g_mapPinManager then
		for _, tableData in pairs(g_mapPinManager.m_keyToPinMapping) do
			for _, pinKeys in pairs(tableData) do
				for _, pinKey in pairs(pinKeys) do
					if pinKey then
						g_mapPinManager:ReleaseObject(pinKey)
					end	
				end
			end
		end	
	end
	
	g_mapPinManager = nil
	g_mapLocationManager = nil
	g_keepNetworkManager = nil
end

function AUI.Minimap.Pin.UpdateAllLocations()
	if not g_mapPinManager or not g_keepNetworkManager or not g_mapLocationManager then
		return
	end

	AUI_MapPin_UpdateAllLocations()
end

function AUI.Minimap.Pin.UpdateAllLocationsAndSizes()
	if not g_mapPinManager or not g_keepNetworkManager or not g_mapLocationManager then
		return
	end

	for _, tableData in pairs(g_mapPinManager.m_keyToPinMapping) do
		for _, pinKeys in pairs(tableData) do
			for _, pinKey in pairs(pinKeys) do
				local pin = g_mapPinManager:GetExistingObject(pinKey) 
				if pin then
					pin:UpdateLocation()		
					pin:UpdateSize()					
				end
			end
		end
	end	

	g_keepNetworkManager:UpdateAllLocations()
end

function AUI.Minimap.Pin.RefreshGroupPins()
	if not g_mapPinManager or not g_keepNetworkManager or not g_mapLocationManager then
		return
	end

	AUI_MapPin_RefreshGroupPins()
end

function AUI.Minimap.Pin.RefreshPlayer()
	if not g_mapPinManager or not g_keepNetworkManager or not g_mapLocationManager then
		return
	end
	
	AUI_MapPin_RefreshPlayer()
end

function AUI.Minimap.Pin.RefreshPins()
	if not g_mapPinManager or not g_keepNetworkManager or not g_mapLocationManager then
		return
	end
	
	AUI_MapPin_RefreshPlayer()
	AUI_MapPin_RefreshAllPOIs()
	AUI_MapPin_RefreshKillLocations()
	AUI_MapPin_RefreshWayshrines()	
	AUI_MapPin_RefreshLocations()
	AUI_MapPin_RefreshGroupPins()
	AUI_MapPin_RefreshForwardCamps()
	AUI_MapPin_RefreshObjectives()
	AUI_MapPin_RefreshSuggestionPins()
	AUI_MapPin_RefreshKeeps()
	AUI_MapPin_RefreshKeepLinks()	
	AUI_MapPin_RefreshWorldEvents()	
	AUI_MapPin_RefreshQuests()
	AUI_MapPin_RefreshMapPings()
	AUI_MapPin_RefreshAntiquityDigSites()
	AUI_MapPin_RefreshCompanionPins()
	AUI_MapPin_RefreshSkyshardPins()
	
	AUI.Minimap.Pin.UpdateAllLocationsAndSizes()
	
	WORLD_MAP_QUEST_BREADCRUMBS:RefreshAllQuests()
end

function AUI.Minimap.Pin.GetPlayerPin()
	if not g_mapPinManager or not g_keepNetworkManager or not g_mapLocationManager then
		return
	end

    return g_mapPinManager.playerPin
end

--removed (bring it back for HarvestMap support)
function AUI.Minimap.Pin.UpdatePinLocations()
	AUI.Minimap.Pin.UpdateAllLocations()
end