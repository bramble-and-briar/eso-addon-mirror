AUI.WorldMap = {}

local function GetPinTextureColor(self, textureColor)
	if type(textureColor) == "function" then
		return textureColor(self)
	end
	
	return textureColor
end

local function SetData(_self, _pinType, _pinTag)
	local overrideTint = nil
	
	if _self:IsQuest() then
		local questType = GetJournalQuestType(_pinTag[1])
		local questRepeatType = GetJournalQuestRepeatType(_pinTag[1]) 				
		_self.m_AUIPinType = AUI.Minimap.Pin.GetQuestPinType(_pinType, questType, questRepeatType)
		overrideTint = GetPinTextureColor(_self, ZO_MapPin.PIN_DATA[_self.m_AUIPinType].tint)		
	elseif _self:IsGroup() then
		local groupTag = _pinTag.groupTag
		if not groupTag then
			groupTag = _pinTag
		end	
	
		_self.m_AUIPinType = AUI.Minimap.Pin.GetGroupStatePinType(groupTag)
		overrideTint = GetPinTextureColor(_self, ZO_MapPin.PIN_DATA[_self.m_AUIPinType].tint)
	else
		_self.m_AUIPinType = _pinType
	end
	
	if overrideTint then
		_self.backgroundControl:SetColor(overrideTint:UnpackRGBA())			
	end		
end

local function UpdateAreaPinTexture(_self)
	if _self:IsQuest() then		
		if _self.pinBlob then
			local questType = GetJournalQuestType(_self.m_PinTag[1])
			local questRepeatType = GetJournalQuestRepeatType(_self.m_PinTag[1]) 				
			local AUI_pinType = AUI.Minimap.Pin.GetQuestPinType(_self.m_PinType, questType, questRepeatType)
			local pinData = ZO_MapPin.PIN_DATA[AUI_pinType]	
			if pinData and pinData.tint then
				local tint = GetPinTextureColor(_self, pinData.tint)
				if tint then
					_self.pinBlob:SetColor(tint:UnpackRGBA())
				end
			end
		end
	end
end

function AUI.WorldMap.Init()
	AUI.PostHook(ZO_MapPin, "SetData", SetData)
	AUI.PostHook(ZO_MapPin, "UpdateAreaPinTexture", UpdateAreaPinTexture)

	
	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function(wasNavigateIn)
		if AUI.Minimap.IsLoaded() then
			if wasNavigateIn == nil then
				AUI.Minimap.Refresh()						
			end				
		end
	end)
	
	WORLD_MAP_SCENE:RegisterCallback("StateChange", 
	function(oldState, newState)
		if AUI.Minimap.IsLoaded() then
			if newState == SCENE_HIDING then	
				AUI.Minimap.Refresh()
			end
		end													
	end)
	
	GAMEPAD_WORLD_MAP_SCENE:RegisterCallback("StateChange", 
	function(oldState, newState)
		if AUI.Minimap.IsLoaded() then
			if newState == SCENE_HIDING then	
				AUI.Minimap.Refresh()
			end
		end													
	end)	
end	

local function ZO_WM_AddCustomPin(self, pinType, pinTypeAddCallback, pinTypeOnResizeCallback, pinLayoutData, pinTooltipCreator)
	local pinTypeId = _G[pinType]	
	local pinManager = AUI.Minimap.GetPinManager()
	if pinManager and pinTypeId then
		pinManager.m_keyToPinMapping[pinType] = {}
		pinManager.customPins[pinTypeId] = self.customPins[pinTypeId]
	end
end

local function ZO_WM_CreatePin(self, pinType, pinTag, xLoc, yLoc, radius, borderInformation)
	local pinManager = AUI.Minimap.GetPinManager()
	if pinManager and self.customPins[pinType] then					
		pinManager:CreatePin(pinType, pinTag, xLoc, yLoc, radius, borderInformation)
	end
end

local function ZO_WM_RemovePins(self, lookupType, majorIndex, keyIndex)
	local pinTypeId = _G[lookupType]
	local pinManager = AUI.Minimap.GetPinManager()
	if pinManager and pinManager.customPins[pinTypeId] then
		pinManager:RemovePins(lookupType, pinTypeId, keyIndex)
	end
end

AUI.PostHook(ZO_WorldMapPins, "AddCustomPin", ZO_WM_AddCustomPin)
AUI.PostHook(ZO_WorldMapPins, "CreatePin", ZO_WM_CreatePin)
AUI.PreHook(ZO_WorldMapPins, "RemovePins", ZO_WM_RemovePins)