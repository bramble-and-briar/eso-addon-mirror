AUI_MapPin = ZO_WorldMapPins:Subclass()

function AUI_MapPin:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function AUI_MapPin:Initialize(parentControl)
    local function CreatePin(pool)
        return AUI_Pin:New(parentControl)
    end

    local function ResetPin(pin)	
		pin:ClearData()

		pin:SetHidden(true)

		pin:ClearScaleChildren()
		pin:ResetAnimation(ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_HIDE_CONTROL)
		pin:ResetScale()
		pin:SetRotation(0)

		local control = pin:GetControl()
		control:SetAlpha(1)
		control:SetHidden(true)
	 
		-- Remove area blob from pin, put it back in its own pool.
		if pin.pinBlobKey then
			AUI.Minimap.GetPinManager():ReleasePinBlob(pin.pinBlobKey)
			pin.pinBlobKey = nil
			pin.pinBlob = nil
		end

		if pin.polygonBlob then
			AUI.Minimap.GetPinManager():ReleasePinPolygonBlob(pin.polygonBlobKey)
			pin.polygonBlobKey = nil
			pin.polygonBlob = nil
		end
    end

    ZO_ObjectPool.Initialize(self, CreatePin, ResetPin)

    self.m_keyToPinMapping =
    {
        ["poi"] = {},
        ["loc"] = {},
        ["quest"] = {},
        ["objective"] = {},
        ["keep"] = {},
        ["pings"] = {},
        ["killLocation"] = {},
        ["fastTravelKeep"] = {},
        ["fastTravelWayshrine"] = {},
        ["forwardCamp"] = {},
        ["AvARespawn"] = {},
        ["group"] = {},
        ["restrictedLink"] = {},
        ["suggestion"] = {},
        ["worldEventUnit"] = {},
		["worldEventPOI"] = {},
        ["antiquityDigSite"] = {},
		["companion"] = {},
		["skyshard"] = {}
    }

	self.nextCustomPinType = MAP_PIN_TYPE_INVALID
    self.customPins = {}

    local function CreateBlobControl(pool)
        return ZO_ObjectPool_CreateNamedControl("AUI_QuestPinBlob", "ZO_PinBlob", pool, parentControl)
    end

    local function ResetBlobControl(blobControl)
        ZO_ObjectPool_DefaultResetControl(blobControl)
        blobControl:SetAlpha(1)
    end

	self.pinBlobPool = ZO_ObjectPool:New(CreateBlobControl, ResetBlobControl)
	
    local function CreatePolygonBlobControl(pool)
        local polygonBlob = ZO_ObjectPool_CreateNamedControl("AUI_PinPolygonBlob", "ZO_PinPolygonBlob", pool, parentControl)
        return polygonBlob
    end

    local function ResetPolygonBlobControl(polygonControl)
        ZO_ObjectPool_DefaultResetControl(polygonControl)
        polygonControl:SetAlpha(1)
    end	
	
	self.pinPolygonBlobPool = ZO_ObjectPool:New(CreatePolygonBlobControl, ResetPolygonBlobControl)
	self.pinFadeInAnimationPool = ZO_AnimationPool:New("AUI_WorldMapPinFadeIn")
	
    local function OnAnimationTimelineStopped(timeline)
        self.pinFadeInAnimationPool:ReleaseObject(timeline.key)
    end

    local function SetupTimeline(timeline)
        timeline:SetHandler("OnStop", OnAnimationTimelineStopped)
    end	
	
    self.pinFadeInAnimationPool:SetCustomFactoryBehavior(SetupTimeline)

    local function ResetTimeline(animationTimeline)
        local pinAnimation = animationTimeline:GetAnimation(1)
        pinAnimation:SetAnimatedControl(nil)

        local areaAnimation = animationTimeline:GetAnimation(2)
        areaAnimation:SetAnimatedControl(nil)
    end

    self.pinFadeInAnimationPool:SetCustomResetBehavior(ResetTimeline)
	
	WORLD_MAP_QUEST_BREADCRUMBS:RegisterCallback("QuestAvailable", function(...) self:OnQuestAvailable(...) end)
	WORLD_MAP_QUEST_BREADCRUMBS:RegisterCallback("QuestRemoved", function(...) self:OnQuestRemoved(...) end)
end

function AUI_MapPin:CreatePin(pinType, pinTag, xLoc, yLoc, radius, borderInformation)
    local pin, pinKey = self:AcquireObject()
    pin:SetData(pinType, pinTag)
    pin:SetLocation(xLoc, yLoc, radius, borderInformation)
	
    if pinType == MAP_PIN_TYPE_PLAYER then
        pin:PingMapPin(ZO_MapPin.PulseAnimation)
        self.playerPin = pin
    end	
	
    if not pin:ValidatePvPPinAllowed() then
        self:ReleaseObject(pinKey)
        return
    end

    if pin:IsPOI() then
        self:MapPinLookupToPinKey("poi", pin:GetPOIZoneIndex(), pin:GetPOIIndex(), pinKey)
    elseif pin:IsLocation() then
        self:MapPinLookupToPinKey("loc", pin:GetLocationIndex(), pin:GetLocationIndex(), pinKey)
    elseif pin:IsQuest() then
        self:MapPinLookupToPinKey("quest", pin:GetQuestIndex(), pinTag, pinKey)
    elseif pin:IsObjective() then
        self:MapPinLookupToPinKey("objective", pin:GetObjectiveKeepId(), pinTag, pinKey)
    elseif pin:IsKeepOrDistrict() then
        self:MapPinLookupToPinKey("keep", pin:GetKeepId(), pin:IsUnderAttackPin(), pinKey)
    elseif pin:IsMapPing() then
        self:MapPinLookupToPinKey("pings", pinType, pinTag, pinKey)
    elseif pin:IsKillLocation() then
        self:MapPinLookupToPinKey("killLocation", pinType, pinTag, pinKey)
    elseif pin:IsFastTravelKeep() then
        self:MapPinLookupToPinKey("fastTravelKeep", pin:GetFastTravelKeepId(), pin:GetFastTravelKeepId(), pinKey)
    elseif pin:IsFastTravelWayShrine() then
        self:MapPinLookupToPinKey("fastTravelWayshrine", pinType, pinTag, pinKey)
    elseif pin:IsForwardCamp() then
        self:MapPinLookupToPinKey("forwardCamp", pinType, pinTag, pinKey)
    elseif pin:IsAvARespawn() then
        self:MapPinLookupToPinKey("AvARespawn", pinType, pinTag, pinKey)
    elseif pin:IsGroup() then
        self:MapPinLookupToPinKey("group", pinType, pinTag, pinKey)
    elseif pin:IsRestrictedLink() then
        self:MapPinLookupToPinKey("restrictedLink", pinType, pinTag, pinKey)
    elseif pin:IsSuggestion() then
        self:MapPinLookupToPinKey("suggestion", pinType, pinTag, pinKey)
    elseif pin:IsWorldEventUnitPin() then
        self:MapPinLookupToPinKey("worldEventUnit", pin:GetWorldEventInstanceId(), pin:GetUnitTag(), pinKey)
    elseif pin:IsWorldEventPOIPin() then
        self:MapPinLookupToPinKey("worldEventPOI", pin:GetWorldEventInstanceId(), pinTag, pinKey)		
    elseif pin:IsAntiquityDigSitePin() then
        self:MapPinLookupToPinKey("antiquityDigSite", pinType, pinTag, pinKey)
    elseif pin:IsCompanion() then
        self:MapPinLookupToPinKey("companion", pinType, pinTag, pinKey)	
    elseif pin:IsSkyshard() then
        self:MapPinLookupToPinKey("skyshard", pinType, pinTag, pinKey)		
    else
        local customPinData = self.customPins[pinType]
        if customPinData then
            self:MapPinLookupToPinKey(customPinData.pinTypeString, pinType, pinTag, pinKey)
        end
    end

    return pin, pinKey
end

function AUI_MapPin:Reset()
    self:ClearData()

    self:SetHidden(true)

    self:ClearScaleChildren()
    self:ResetAnimation(ZO_MapPin.ANIM_CONSTANTS.RESET_ANIM_HIDE_CONTROL)
    self:ResetScale()
    self:SetRotation(0)

    local control = self:GetControl()
    control:SetAlpha(1)

    -- Remove area blob from pin, put it back in its own pool.
    if self.pinBlobKey then
        AUI.Minimap.GetPinManager():ReleasePinBlob(self.pinBlobKey)
        self.pinBlobKey = nil
        self.pinBlob = nil
    end

    if self.polygonBlob then
        AUI.Minimap.GetPinManager():ReleasePinPolygonBlob(self.polygonBlobKey)
        self.polygonBlobKey = nil
        self.polygonBlob = nil
    end
end

function AUI_MapPin:RemovePins(lookupType, majorIndex, keyIndex)
    local lookupTable = self.m_keyToPinMapping[lookupType]

	if not lookupTable then
		return
	end

    if majorIndex then
        local keys = lookupTable[majorIndex]
        if keys then
            if keyIndex then
                 --Remove a specific pin
                local pinKey = keys[keyIndex]
                if pinKey then
                    self:ReleaseObject(pinKey)
                    keys[keyIndex] = nil
                end
            else
                --Remove all pins in the major index
                for _, pinKey in pairs(keys) do
                    self:ReleaseObject(pinKey)
                end

                self.m_keyToPinMapping[lookupType][majorIndex] = {}
            end
        end
    else
        --Remove all pins of the lookup type
        for _, keys in pairs(lookupTable) do
            for _, pinKey in pairs(keys) do
                self:ReleaseObject(pinKey)
            end
        end

        self.m_keyToPinMapping[lookupType] = {}
    end
end

function AUI_MapPin:SetLocation(xLoc, yLoc, radius, borderInformation)
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
                    self.pinBlob, self.pinBlobKey = AUI.Minimap.GetPinManager():AcquirePinBlob()
                end
                self.pinBlob:SetHidden(false)
            end
        elseif borderInformation then
            if not self.polygonBlob then
                self.polygonBlob, self.polygonBlobKey = AUI.Minimap.GetPinManager():AcquirePinPolygonBlob()
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

function AUI_MapPin:RefreshCustomPins(optionalPinType)
    for pinTypeId, pinData in pairs(self.customPins) do
        if optionalPinType == nil or optionalPinType == pinTypeId then
            self:RemovePins(pinData.pinTypeString)

            if pinData.enabled then
                pinData.layoutCallback(self)
            end
        end
    end
end

local g_mapPinManager = AUI_MapPin:New(AUI_MapContainer)

function AUI.Minimap.GetPinManager()
	return g_mapPinManager
end

-----------------------
-- Locations Manager --
-----------------------

-- Set up the place names text that appears on the map...
AUI_MapLocationPins_Manager = ZO_ControlPool:Subclass()

function AUI_MapLocationPins_Manager:Initialize(container)
    ZO_ControlPool.Initialize(self, "AUI_MapLocation", container, "Landmark")

    self.m_minFontSize = 17
    self.m_maxFontSize = 32
    self.m_cachedFontStrings = {}

    self:SetFontScale(1)
end

function AUI_MapLocationPins_Manager:SetFontScale(scale)
    if scale ~= self.m_fontScale then
        self.m_fontScale = scale
        self.m_cachedFontStrings = {}
    end
end

function AUI_MapLocationPins_Manager:GetFontString(size)
    -- apply scale to the (unscaled) input size, clamp it, and arive at final font string.
    -- unscale by global ui scale because we want the font to get a little bigger at smaller ui scales to approximately cover the same map area...
    local fontString = self.m_cachedFontStrings[size]
    if not fontString then
        fontString = string.format("$(BOLD_FONT)|%d|soft-shadow-thin", zo_round(size / GetUIGlobalScale()))
        self.m_cachedFontStrings[size] = fontString
    end

    return fontString
end

function AUI_MapLocationPins_Manager:AddLocation(locationIndex)
    if IsMapLocationVisible(locationIndex) then
        local icon, x, y = GetMapLocationIcon(locationIndex)

        if icon ~= "" and ZO_WorldMap_IsNormalizedPointInsideMapBounds(x, y) then
            local tag = ZO_MapPin.CreateLocationPinTag(locationIndex, icon)
			g_mapPinManager:CreatePin(MAP_PIN_TYPE_LOCATION, tag, x, y)
        end
    end
end

function AUI_MapLocationPins_Manager:RefreshLocations()
    self:ReleaseAllObjects()
	g_mapPinManager:RemovePins("loc")

    for i = 1, GetNumMapLocations() do
        self:AddLocation(i)
    end
end