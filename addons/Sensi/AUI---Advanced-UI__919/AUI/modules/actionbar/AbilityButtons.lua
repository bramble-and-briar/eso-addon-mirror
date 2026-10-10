AUI.Actionbar.AbilityButtons = {}

local gIsLoaded = false
local gIsPreviewShowed = false
local gHotBarCategory = nil
local gLastHotBarCategory = nil
local gAbilityButtonArray = {}
local gDefaultTimerSettingState = false
local gDefaultTimerBackbarSettingState = false
local gUltimateSlotId = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
local gAbilitySlotsStart = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local gAbilitySlotsEnd = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1
local gAbilitySlotDataArray = 
{
	[HOTBAR_CATEGORY_BACKUP] = {},
	[HOTBAR_CATEGORY_DAEDRIC_ARTIFACT] = {},
	[HOTBAR_CATEGORY_OVERLOAD] = {},
	[HOTBAR_CATEGORY_PRIMARY] = {},
	[HOTBAR_CATEGORY_TEMPORARY] = {},
	[HOTBAR_CATEGORY_WEREWOLF] = {},
	[HOTBAR_CATEGORY_COMPANION] = {}
}

local function UpdateSlot(_slotId)	
	gAbilitySlotDataArray[gHotBarCategory][_slotId].abilityId = GetSlotBoundId(_slotId)

	if gAbilitySlotDataArray[gHotBarCategory][_slotId].abilityId > 0 then
		gAbilitySlotDataArray[gHotBarCategory][_slotId].icon = GetAbilityIcon(gAbilitySlotDataArray[gHotBarCategory][_slotId].abilityId)
		gAbilitySlotDataArray[gHotBarCategory][_slotId].use = true			
	else
		gAbilitySlotDataArray[gHotBarCategory][_slotId].duration = 0
		gAbilitySlotDataArray[gHotBarCategory][_slotId].isActive = false
		gAbilitySlotDataArray[gHotBarCategory][_slotId].stackCount = 0
		gAbilitySlotDataArray[gHotBarCategory][_slotId].use = false		
	end				
end

local function UpdateSlots()
	for slotId, actionButton in pairs(gAbilityButtonArray) do
		UpdateSlot(slotId)
	end
end

local function ShowProcEffects(_procInfoData)
	local slotId = _procInfoData.slotId
	
	if gUltimateSlotId == slotId then
		return
	end
	
	local actionButton = ZO_ActionBar_GetButton(slotId)
	if actionButton and actionButton.procBurstTexture:IsHidden() then
		actionButton.procBurstTimeline:PlayFromStart()
		actionButton.procLoopTimeline:PlayFromStart()
		actionButton.procBurstTexture:SetHidden(false)
		actionButton.procLoopTexture:SetHidden(false)		
	end
end

local function HideAllProcEffects(_effectId, _effectName)	
	if gUltimateSlotId == _effectId then
		return
	end

	for slotId, actionButton in pairs(gAbilityButtonArray) do
		if gUltimateSlotId ~= slotId then
			actionButton.procBurstTimeline:Stop()
			actionButton.procLoopTimeline:Stop()
			actionButton.procBurstTexture:SetHidden(true)
			actionButton.procLoopTexture:SetHidden(true)
		end
	end
end

local function HideProcEffects(_procInfoData)
	local slotId = _procInfoData.slotId
	
	if gUltimateSlotId == _effectId then
		return
	end
	
	local actionButton = ZO_ActionBar_GetButton(slotId)
	if actionButton then
		actionButton.procBurstTimeline:Stop()
		actionButton.procLoopTimeline:Stop()
		actionButton.procBurstTexture:SetHidden(true)
		actionButton.procLoopTexture:SetHidden(true)					
	end
end

local function OnEffectChanged(_changeType, _effectName, _unitTag, _beginTime, _endTime, _stackCount, _effectId, _castByPlayer, _procInfoData)
	if not _castByPlayer or _procInfoData.slotId == gUltimateSlotId then
		return
	end

	if _procInfoData then
		if _procInfoData.isProc and _unitTag == AUI_PLAYER_UNIT_TAG then
			if _procInfoData.procType == 0 then
				ShowProcEffects(_procInfoData)
			else
				HideProcEffects(_procInfoData)			
			end
		end	
	end
end

local function UpdateAllEffects()
	HideAllProcEffects()
	
	 local numBuffs = GetNumBuffs(AUI_PLAYER_UNIT_TAG)
	 for i = 1, numBuffs do		
		local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo(AUI_PLAYER_UNIT_TAG, i)
		local procInfoData = AUI.Ability.GetProcInfo(EFFECT_RESULT_UPDATED, abilityId, stackCount, castByPlayer)		
		OnEffectChanged(EFFECT_RESULT_UPDATED, buffName, AUI_PLAYER_UNIT_TAG, timeStarted, timeEnding, stackCount, abilityId, castByPlayer, procInfoData)		
	 end
end

local function AddActionBarButtonPreviewCooldown(_slotId, _category)
	UpdateSlot(_slotId)
	if gAbilitySlotDataArray[_category][_slotId] and gAbilitySlotDataArray[_category][_slotId].use then	
		local duration = GetAbilityDuration(gAbilitySlotDataArray[_category][_slotId].abilityId)
		if duration and duration > 0 then
			gAbilitySlotDataArray[_category][_slotId].duration = duration 
			gAbilitySlotDataArray[_category][_slotId].endTime = (GetFrameTimeMilliseconds() + duration) / 1000	
			gAbilitySlotDataArray[_category][_slotId].isActive = true	
		end		
	 end
end

local function OnUpdateActionButton(_slotId)
	local actionButton = gAbilityButtonArray[_slotId]

	if not actionButton then
		return
	end
	
	local slotData = gAbilitySlotDataArray[gHotBarCategory][_slotId]
	if slotData then
		if actionButton.aui_stackCountText and AUI.Settings.Actionbar.ability_cooldowns.Forground.show_remaining_time then
			local stackCount = slotData.stackCount
			if slotData.use and stackCount > 0 then
				actionButton.aui_stackCountText:SetText(stackCount)
				actionButton.aui_stackCountText:SetHidden(false)		
			else
				actionButton.aui_stackCountText:SetHidden(true)			
			end			
		end
	
		if slotData.isActive then				
			if AUI.Settings.Actionbar.ability_cooldowns.Forground.show_remaining_time then
				actionButton.cooldownText:SetHidden(false)
			end
			
			local remainTime = slotData.endTime - GetFrameTimeSeconds()
			if remainTime > 0 then 
				if remainTime <= ((slotData.duration / 1000) * AUI.Settings.Actionbar.ability_cooldowns.Forground.threshold_remaining_time_percent) / 100 then
					local color = AUI.Settings.Actionbar.ability_cooldowns.Forground.remaining_time_low_percent_color
					actionButton.cooldownText:SetColor(color.r, color.g, color.b, color.a)
					
					if actionButton.cooldownFrame then
						actionButton.cooldownFrame:SetFillColor(color.r, color.g, color.b, color.a)
					end				
				else
					local color = AUI.Settings.Actionbar.ability_cooldowns.Forground.remaining_time_percent_color
					actionButton.cooldownText:SetColor(color.r, color.g, color.b, color.a)	
					
					if actionButton.cooldownFrame then
						actionButton.cooldownFrame:SetFillColor(color.r, color.g, color.b, color.a) 
					end
				end	

				if AUI.Settings.Actionbar.ability_cooldowns.Forground.show_remaining_time then
					actionButton.cooldownText:SetText(AUI.Time.GetFormatedString(remainTime, AUI_TIME_FORMAT_SHORT))	
				end	
				
				if actionButton.cooldownFrame and AUI.Settings.Actionbar.ability_cooldowns.Forground.show_cooldown_frame then	
					actionButton.cooldownFrame:StartCooldown(remainTime * 1000, slotData.duration, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
				end		

				if _slotId == gUltimateSlotId then
					AUI.Actionbar.UltimateButtons.HidePercent()
				end					
			else
				if AUI.Settings.Actionbar.ability_cooldowns.Forground.show_remaining_time then
					actionButton.cooldownText:SetHidden(true)
				end		
				
				if actionButton.cooldownFrame and AUI.Settings.Actionbar.ability_cooldowns.Forground.show_cooldown_frame then
					actionButton.cooldownFrame:ResetCooldown() 			
				end	

				if _slotId == gUltimateSlotId then
					AUI.Actionbar.UltimateButtons.ShowPercent()
				end	

				slotData.isActive = false				
			end											
		else
			if AUI.Settings.Actionbar.ability_cooldowns.Forground.show_remaining_time then
				actionButton.cooldownText:SetHidden(true)			
			end
			
			if actionButton.cooldownFrame and AUI.Settings.Actionbar.ability_cooldowns.Forground.show_cooldown_frame then
				actionButton.cooldownFrame:ResetCooldown() 			
			end	

			if _slotId == gUltimateSlotId then
				AUI.Actionbar.UltimateButtons.ShowPercent()
			end			
		end	

		if not gLastHotBarCategory then
			return
		end

		local lastSlotData = gAbilitySlotDataArray[gLastHotBarCategory][_slotId]	
		if lastSlotData then
			if actionButton.swapInfoControl.aui_stackCountText and AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time then
				if lastSlotData.use and lastSlotData.stackCount > 0 then
					actionButton.swapInfoControl.aui_stackCountText:SetText(lastSlotData.stackCount)
					actionButton.swapInfoControl.aui_stackCountText:SetHidden(false)					
				else
					actionButton.swapInfoControl.aui_stackCountText:SetHidden(true)	
				end			
			end		
			
			if actionButton.swapInfoControl.icon:GetTextureFileName() ~= lastSlotData.icon then
				actionButton.swapInfoControl.icon:SetTexture(lastSlotData.icon)					
			end		
		
			if lastSlotData.isActive then		
				local remainTime = lastSlotData.endTime - GetFrameTimeSeconds()
				if remainTime > 0 then
					if gAbilitySlotDataArray[gHotBarCategory][_slotId].abilityId == gAbilitySlotDataArray[gLastHotBarCategory][_slotId].abilityId then
						if AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time then
							actionButton.swapInfoControl:SetHidden(true)
						end		
					else
						if remainTime <= ((lastSlotData.duration / 1000)* AUI.Settings.Actionbar.ability_cooldowns.Background.threshold_remaining_time_percent) / 100 then
							local color = AUI.Settings.Actionbar.ability_cooldowns.Background.remaining_time_low_percent_color
							actionButton.swapInfoControl.cooldownText:SetColor(color.r, color.g, color.b, color.a)
							
							if actionButton.swapInfoControl.cooldownFrame then
								actionButton.swapInfoControl.cooldownFrame:SetFillColor(color.r, color.g, color.b, color.a)
							end
							
							if actionButton.swapInfoControl.animation and AUI.Settings.Actionbar.ability_cooldowns.Background.show_animated_icons and not actionButton.swapInfoControl.animation:IsPlaying() then
								 actionButton.swapInfoControl.animation:PlayFromStart()
							end												
						else
							local color = AUI.Settings.Actionbar.ability_cooldowns.Background.remaining_time_percent_color
							actionButton.swapInfoControl.cooldownText:SetColor(color.r, color.g, color.b, color.a)	
							
							if actionButton.swapInfoControl.cooldownFrame then
								actionButton.swapInfoControl.cooldownFrame:SetFillColor(color.r, color.g, color.b, color.a)
							end
							
							if actionButton.swapInfoControl.animation and AUI.Settings.Actionbar.ability_cooldowns.Background.show_animated_icons then
								 if actionButton.swapInfoControl.animation:IsPlaying() then
									actionButton.swapInfoControl.animation:PlayInstantlyToStart()
									actionButton.swapInfoControl.animation:Stop()
								 end					
							end						
						end	

						if AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time then
							actionButton.swapInfoControl.cooldownText:SetText(AUI.Time.GetFormatedString(remainTime, AUI_TIME_FORMAT_SHORT))	
						end	
						
						if actionButton.swapInfoControl.cooldownFrame and AUI.Settings.Actionbar.ability_cooldowns.Background.show_cooldown_frame then							
							actionButton.swapInfoControl.cooldownFrame:StartCooldown(remainTime * 1000, slotData.duration, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
						end	

						if AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time then
							actionButton.swapInfoControl:SetHidden(false)				
						end							
					end				
				elseif lastSlotData.stackCount == 0 then
					if AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time then
						actionButton.swapInfoControl:SetHidden(true)			
					end
					
					if actionButton.swapInfoControl.cooldownFrame and AUI.Settings.Actionbar.ability_cooldowns.Background.show_cooldown_frame then
						actionButton.swapInfoControl.cooldownFrame:ResetCooldown() 			
					end
					
					lastSlotData.isActive = false				
				end					
			else
				if AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time then
					actionButton.swapInfoControl:SetHidden(true)			
				end
				
				if actionButton.swapInfoControl.cooldownFrame and AUI.Settings.Actionbar.ability_cooldowns.Background.show_cooldown_frame then
					actionButton.swapInfoControl.cooldownFrame:ResetCooldown() 			
				end			
			end					
		end
	end	
end			
	
local function CreateButtons()
	for slotId = gAbilitySlotsStart, gAbilitySlotsEnd do
		local buttonControl = ZO_ActionBar_GetButton(slotId)

		if not buttonControl.procBurstTexture then
			buttonControl.procBurstTexture = WINDOW_MANAGER:CreateControl("$(parent)Burst", buttonControl.slot, CT_TEXTURE)
			buttonControl.procBurstTexture:SetAnchor(TOPLEFT, buttonControl.slot, TOPLEFT, 2, 2)
			buttonControl.procBurstTexture:SetAnchor(BOTTOMRIGHT, buttonControl.slot, BOTTOMRIGHT, -2, -2)			
			buttonControl.procBurstTexture:SetTexture("EsoUI/Art/ActionBar/coolDown_completeEFX.dds")
			buttonControl.procBurstTexture:SetDrawTier(DT_HIGH)
		end
		
		if not buttonControl.procLoopTexture then
			buttonControl.procLoopTexture = WINDOW_MANAGER:CreateControl("$(parent)Loop", buttonControl.slot, CT_TEXTURE)
			buttonControl.procLoopTexture:SetAnchor(TOPLEFT, buttonControl.slot, TOPLEFT, 2, 2)
			buttonControl.procLoopTexture:SetAnchor(BOTTOMRIGHT, buttonControl.slot, BOTTOMRIGHT, -2, -2)
			buttonControl.procLoopTexture:SetTexture("EsoUI/Art/ActionBar/abilityHighlight_mage_med.dds") 
			buttonControl.procLoopTexture:SetDrawTier(DT_HIGH)	
		end
		
		if not buttonControl.procBurstTimeline then	
			buttonControl.procBurstTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("AbilityProcReadyBurst", buttonControl.procBurstTexture)	
		end
		
		if not buttonControl.procLoopTimeline then	
			buttonControl.procLoopTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("AbilityProcReadyLoop", buttonControl.procLoopTexture)				
		end
		
		buttonControl.procBurstTexture:SetHidden(true)
		buttonControl.procLoopTexture:SetHidden(true)

		buttonControl.animation = ANIMATION_MANAGER:CreateTimelineFromVirtual("AUI_Actionbar_Time_Low", GetControl(buttonControl.slot, "Icon"))

		if not buttonControl.cooldownText then
			buttonControl.cooldownText = CreateControlFromVirtual("AUI_ActionSlotPrimaryButtonCountText" .. slotId, buttonControl.slot, "AUI_Actionbar_Button_CountText")		
		end

		if not buttonControl.aui_stackCountText then
			buttonControl.aui_stackCountText = CreateControlFromVirtual("AUI_Actionbar_StackCountText" .. slotId, buttonControl.slot, "AUI_Actionbar_StackCountText")
		end

		if not buttonControl.cooldownFrame then
			buttonControl.cooldownFrame = CreateControlFromVirtual("AUI_Actionbar_Button_CooldownFrame" .. slotId, buttonControl.slot, "AUI_Actionbar_Button_CooldownFrame")
			buttonControl.cooldownFrame:StartCooldown(0, 0, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
		end

		if not buttonControl.swapInfoControl then
			buttonControl.swapInfoControl = CreateControlFromVirtual("AUI_Actionbar_Swap_Info" .. slotId, buttonControl.slot, "AUI_Actionbar_Swap_Info")	
			buttonControl.swapInfoControl.cooldownText = GetControl(buttonControl.swapInfoControl, "_CooldownText")
			buttonControl.swapInfoControl.aui_stackCountText = GetControl(buttonControl.swapInfoControl, "_StackCountText")
			buttonControl.swapInfoControl.icon = GetControl(buttonControl.swapInfoControl, "_Icon")
			buttonControl.swapInfoControl.cooldownFrame = GetControl(buttonControl.swapInfoControl, "_CooldownFrame")
			buttonControl.swapInfoControl.cooldownFrame:StartCooldown(0, 0, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)	
			buttonControl.swapInfoControl.isActive = false	
			buttonControl.swapInfoControl.animation = ANIMATION_MANAGER:CreateTimelineFromVirtual("AUI_Actionbar_Time_Low", GetControl(buttonControl.swapInfoControl, "_Icon"))

			EVENT_MANAGER:RegisterForUpdate("AUI_Actionbar_OnUpdateActionBarButtonCooldown" .. tostring(slotId), 40, function() OnUpdateActionButton(slotId) end)					
		end			

		local backdrop = GetControl(buttonControl.slot, "Backdrop")
		if backdrop then
			backdrop:SetDrawLevel(1)
			backdrop:SetDrawTier(DT_LOW) 
		end
		
		gAbilityButtonArray[slotId] = buttonControl
	end
end	

local function CreateUltimateButton()
	local buttonControl = ZO_ActionBar_GetButton(gUltimateSlotId)

	if not buttonControl.cooldownText then
		buttonControl.cooldownText = CreateControlFromVirtual("AUI_ActionSlotPrimaryButtonCountText" .. gUltimateSlotId, buttonControl.slot, "AUI_Actionbar_Button_CountText")		
	end

	if not buttonControl.swapInfoControl then
		buttonControl.swapInfoControl = CreateControlFromVirtual("AUI_Actionbar_Swap_Info" .. gUltimateSlotId, buttonControl.slot, "AUI_Actionbar_Swap_Info")	
		buttonControl.swapInfoControl.cooldownText = GetControl(buttonControl.swapInfoControl, "_CooldownText")
		buttonControl.swapInfoControl.icon = GetControl(buttonControl.swapInfoControl, "_Icon")
		buttonControl.swapInfoControl.isActive = false	

		EVENT_MANAGER:RegisterForUpdate("AUI_Actionbar_OnUpdateActionBarButtonCooldown" .. tostring(gUltimateSlotId), 40, function() OnUpdateActionButton(gUltimateSlotId) end)					
	end			

	gAbilityButtonArray[gUltimateSlotId] = buttonControl
end
	
local function CreateDataIfNotExists()
	for category, _ in pairs(gAbilitySlotDataArray) do
		for slotId, _ in pairs(gAbilityButtonArray) do
			if not gAbilitySlotDataArray[category][slotId] then	
				gAbilitySlotDataArray[category][slotId] = 
				{
					["isActive"] = false,
					["abilityId"] = 0,
					["endTime"] = 0,
					["duration"] = 0,
					["stackCount"] = 0,
					["icon"] = "",
					["use"] = false,
				}
			end	
		end
	end
end			
	
local function ResetAllCooldowns()
	for category, _ in pairs(gAbilitySlotDataArray) do
		for slotId, _ in pairs(gAbilityButtonArray) do
			if gAbilitySlotDataArray[category][slotId].isActive then
				gAbilitySlotDataArray[category][slotId].isActive = false
			end
		end
	end
end	
	
local function RefreshSlotCooldownStates()
	for slotId, _ in pairs(gAbilityButtonArray) do
		if gAbilitySlotDataArray[gHotBarCategory][slotId] and gAbilitySlotDataArray[gHotBarCategory][slotId].isActive then
			local remainTime = GetActionSlotEffectTimeRemaining(slotId, gHotBarCategory)
			if remainTime == 0 then
				gAbilitySlotDataArray[gHotBarCategory][slotId].isActive = false
				gAbilitySlotDataArray[gHotBarCategory][slotId].duration = 0
			end
		end
		if gLastHotBarCategory and gAbilitySlotDataArray[gLastHotBarCategory][slotId] and gAbilitySlotDataArray[gLastHotBarCategory][slotId].isActive then
			local remainTime = GetActionSlotEffectTimeRemaining(slotId, gLastHotBarCategory)
			if remainTime == 0 then
				gAbilitySlotDataArray[gLastHotBarCategory][slotId].isActive = false
				gAbilitySlotDataArray[gLastHotBarCategory][slotId].duration = 0
			end
		end
	end
end

local function OnUnitDeathStateChanged(_eventCode, _unitTag, _isDead)
	if _unitTag == AUI_PLAYER_UNIT_TAG then
		ResetAllCooldowns()
	elseif _isDead and string.find(_unitTag, "playerpet", 1, true) then
		RefreshSlotCooldownStates()
	end
end
	
function AUI.Actionbar.AbilityButtons.OnActionSlotsFullUpdate(_isHotbarSwap)
	if not gIsLoaded or not gDefaultTimerSettingState then
		return
	end

	if _isHotbarSwap and AUI.Settings.Actionbar.ability_cooldowns.Forground.show_cooldown_frame then
		zo_callLater(
		function() 
			for slotId, actionButton in pairs(gAbilityButtonArray) do
				if actionButton.cooldownFrame then
					actionButton.cooldownFrame:SetHidden(false)
				end
			end	
		end, 300)		
	end
end	

function AUI.Actionbar.AbilityButtons.OnSwapActionBar(activeHotbarCategory)
	if not gIsLoaded then
		return
	end

	if activeHotbarCategory ~= HOTBAR_CATEGORY_PRIMARY and activeHotbarCategory ~= HOTBAR_CATEGORY_BACKUP then
		return
	end

	gLastHotBarCategory = gHotBarCategory	
	gHotBarCategory = activeHotbarCategory

	if gIsPreviewShowed then
		AUI.Actionbar.AbilityButtons.UpdateUI()
	else
		if gDefaultTimerSettingState then
			UpdateSlots()
		end
		
		UpdateAllEffects()
	end	
	
	if AUI.Settings.Actionbar.ability_cooldowns.Forground.show_cooldown_frame then
		for slotId, actionButton in pairs(gAbilityButtonArray) do
			if actionButton.cooldownFrame then
				actionButton.cooldownFrame:SetHidden(true)
			end
		end
	end
end

function AUI.Actionbar.AbilityButtons.OnActionSlotEffectUpdated(_category, _slotId)
	if not gIsLoaded or not gAbilitySlotDataArray or not gDefaultTimerSettingState or not _category or not gAbilitySlotDataArray[_category] or not gAbilitySlotDataArray[_category][_slotId] or not gAbilitySlotDataArray[_category][_slotId].use then
		return
	end

	local remainTime = GetActionSlotEffectTimeRemaining(_slotId, _category)
	if remainTime >= 1500 then
		gAbilitySlotDataArray[_category][_slotId].duration = GetActionSlotEffectDuration(_slotId, _category)	
		gAbilitySlotDataArray[_category][_slotId].endTime = (GetFrameTimeMilliseconds() + remainTime) / 1000
		gAbilitySlotDataArray[_category][_slotId].isActive = true
	elseif remainTime == 0 then
		gAbilitySlotDataArray[_category][_slotId].isActive = false
		gAbilitySlotDataArray[_category][_slotId].duration = 0
	end	

	gAbilitySlotDataArray[_category][_slotId].stackCount = GetActionSlotEffectStackCount(_slotId, _category)
end

function AUI.Actionbar.AbilityButtons.OnActionSlotEffectsCleared()
	if not gIsLoaded or not gAbilitySlotDataArray or not gDefaultTimerSettingState then
		return
	end
	
	for slotId, actionButton in pairs(gAbilityButtonArray) do
		actionButton.aui_stackCountText:SetHidden(true)
		
		gAbilitySlotDataArray[gHotBarCategory][slotId].duration = 0		
		gAbilitySlotDataArray[gHotBarCategory][slotId].isActive = false
		gAbilitySlotDataArray[gHotBarCategory][slotId].use = false		
		gAbilitySlotDataArray[gHotBarCategory][slotId].stackCount = 0
		
		if gLastHotBarCategory then
			gAbilitySlotDataArray[gLastHotBarCategory][slotId].duration = 0
			gAbilitySlotDataArray[gLastHotBarCategory][slotId].isActive = false
			gAbilitySlotDataArray[gLastHotBarCategory][slotId].use = false	
			gAbilitySlotDataArray[gLastHotBarCategory][slotId].stackCount = 0
		end
	end
end

function AUI.Actionbar.AbilityButtons.OnEffectChanged(_changeType, _effectSlot, _effectName, _unitTag, _beginTime, _endTime, _stackCount, _iconName, _buffType, _effectType, _abilityType, _statusEffectType, _unitName, _unitId, _abilityId, _combatUnitType, _castByPlayer, _procInfoData)
	if not gIsLoaded then
		return
	end

	OnEffectChanged(_changeType, _effectName, _unitTag, _beginTime, _endTime, _stackCount, _abilityId, _castByPlayer, _procInfoData)
end

function AUI.Actionbar.AbilityButtons.OnInterfaceSettingChanged(settingSystemType, settingId)
	if not gIsLoaded then
		return
	end
	
	if settingId == UI_SETTING_SHOW_ACTION_BAR_TIMERS then
		gDefaultTimerSettingState = GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS)
	elseif settingId == UI_SETTING_SHOW_ACTION_BAR_BACK_ROW then 
		gDefaultTimerBackbarSettingState = GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_BACK_ROW)
	end
end

function AUI.Actionbar.AbilityButtons.OnPlayerActivated()
	if not gIsLoaded then
		return
	end
	
	AUI.Actionbar.AbilityButtons.UpdateGameSettings()
end

function AUI.Actionbar.AbilityButtons.Update()
	if not gIsLoaded then
		return
	end

	UpdateSlots()
	UpdateAllEffects()
end

function AUI.Actionbar.AbilityButtons.UpdateUI()
	if not gIsLoaded then
		return
	end
	
	for slotId = gAbilitySlotsStart, gUltimateSlotId do
		local buttonControl = gAbilityButtonArray[slotId]
		local slotName = GetSlotName(slotId)

		if not AUI.Settings.Actionbar.ability_cooldowns.Forground.show_remaining_time then
			buttonControl.cooldownText:SetHidden(true)
			buttonControl.timerText:SetDrawTier(DT_MEDIUM)
			buttonControl.stackCountText:SetDrawTier(DT_MEDIUM)
		else
			buttonControl.timerText:SetDrawTier(DT_LOW)
			buttonControl.stackCountText:SetDrawTier(DT_LOW)
		end

		local width, height = buttonControl.slot:GetDimensions()
		
		buttonControl.swapInfoControl:SetDimensions(width, height)	
		
		buttonControl.cooldownText:ClearAnchors()
		
		buttonControl.swapInfoControl:ClearAnchors()
		buttonControl.swapInfoControl.cooldownText:ClearAnchors()
		
		if buttonControl.aui_stackCountText then
			buttonControl.aui_stackCountText:ClearAnchors()
			buttonControl.swapInfoControl.aui_stackCountText:ClearAnchors()
			
			if not AUI.Settings.Actionbar.ability_cooldowns.Forground.show_remaining_time then
				buttonControl.aui_stackCountText:SetHidden(true)						
			end		
			
			if not AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time then
				buttonControl.swapInfoControl.aui_stackCountText:SetHidden(true)							
			end				
		end		
		
		if buttonControl.cooldownFrame then
			buttonControl.cooldownFrame:ClearAnchors()
			buttonControl.cooldownFrame:SetAnchor(TOPLEFT, buttonControl.slot, TOPLEFT, -1, -1)	
			buttonControl.cooldownFrame:SetDimensions(width + 2, height + 2)				
		end
		
		if slotId ~= gUltimateSlotId then
			buttonControl.slot:SetDrawTier(DT_MEDIUM)
			buttonControl.slot:SetDrawLayer(2)

			buttonControl.icon:SetDrawTier(DT_MEDIUM)	
			buttonControl.icon:SetDrawLayer(1)		

			local backdrop = GetControl(buttonControl.slot, "Backdrop")
			backdrop:SetDrawTier(DT_MEDIUM)			
		end
		
		if IsInGamepadPreferredMode() then	
			buttonControl.swapInfoControl:SetAnchor(TOPLEFT, buttonControl.slot, TOPLEFT, 0, -(height / 2) - 4)
			buttonControl.swapInfoControl.cooldownText:SetAnchor(TOP, buttonControl.swapInfoControl, TOP, 0, 10)
			buttonControl.swapInfoControl.cooldownText:SetFont("$(BOLD_FONT)|" .. 18 .. "|" .. "thick-outline")		
		else
			buttonControl.cooldownText:SetAnchor(CENTER, buttonControl.slot, CENTER, 0, 12)	
			buttonControl.cooldownText:SetFont("$(BOLD_FONT)|" .. 16 .. "|" .. "thick-outline")	

			buttonControl.swapInfoControl:SetAnchor(TOPLEFT, buttonControl.slot, TOPLEFT, 0, -(height / 2) - 6)
			buttonControl.swapInfoControl.cooldownText:SetAnchor(TOP, buttonControl.swapInfoControl, TOP, 0, 8)	
			buttonControl.swapInfoControl.cooldownText:SetFont("$(BOLD_FONT)|" .. 16 .. "|" .. "thick-outline")	
			
			if buttonControl.aui_stackCountText then
				buttonControl.aui_stackCountText:SetAnchor(TOPRIGHT, buttonControl.slot, TOPRIGHT, -3, 0)	
				buttonControl.aui_stackCountText:SetFont("$(BOLD_FONT)|" .. 14 .. "|" .. "thick-outline")

				local color = AUI.Settings.Actionbar.ability_cooldowns.Forground.stack_count_color			
				buttonControl.aui_stackCountText:SetColor(color.r, color.g, color.b, color.a)				
			
				buttonControl.swapInfoControl.aui_stackCountText:SetAnchor(TOPRIGHT, buttonControl.swapInfoControl, TOPRIGHT, -2, -2)	
				buttonControl.swapInfoControl.aui_stackCountText:SetFont("$(BOLD_FONT)|" .. 14 .. "|" .. "thick-outline")			
			
				local color = AUI.Settings.Actionbar.ability_cooldowns.Background.stack_count_color			
				buttonControl.swapInfoControl.aui_stackCountText:SetColor(color.r, color.g, color.b, color.a)
			end
		end		
		
		
		if buttonControl.swapInfoControl.cooldownFrame then
			buttonControl.swapInfoControl.cooldownFrame:ClearAnchors()
			buttonControl.swapInfoControl.cooldownFrame:SetAnchor(TOPLEFT, buttonControl.swapInfoControl, TOPLEFT, -1, -1)	
			buttonControl.swapInfoControl.cooldownFrame:SetDimensions(width + 2, height + 2)			
		end				
		
		if AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time then
			buttonControl.swapInfoControl.cooldownText:SetHidden(false)
		else
			buttonControl.swapInfoControl.cooldownText:SetHidden(true)
		end
		
		if gIsPreviewShowed then
			if gLastHotBarCategory then
				AddActionBarButtonPreviewCooldown(buttonControl.slot.slotNum, gLastHotBarCategory)
			end

			AddActionBarButtonPreviewCooldown(buttonControl.slot.slotNum, gHotBarCategory)
		end		
	end
	
	if not ZO_ActionBar1:IsHidden() then
		for slotId, actionButton in pairs(gAbilityButtonArray) do
			if actionButton.cooldownFrame then
				if AUI.Settings.Actionbar.ability_cooldowns.Forground.show_cooldown_frame then
					actionButton.cooldownFrame:SetHidden(false)
				else
					actionButton.cooldownFrame:SetHidden(true)
				end
			end
			
			if actionButton.swapInfoControl.cooldownFrame then
				if AUI.Settings.Actionbar.ability_cooldowns.Background.show_cooldown_frame then
					actionButton.swapInfoControl.cooldownFrame:SetHidden(false)
				else
					actionButton.swapInfoControl.cooldownFrame:SetHidden(true)
				end	
			end				
		end		
	end
	
	 AUI.Actionbar.AbilityButtons.Update(true)
end

function AUI.Actionbar.AbilityButtons.ShowPreview()
	if not gIsLoaded then
		return
	end

	gIsPreviewShowed = true

	AUI.Actionbar.AbilityButtons.UpdateUI()	
end

function AUI.Actionbar.AbilityButtons.HidePreview()
	if not gIsLoaded then
		return
	end

	gIsPreviewShowed = false
	
	for slotId, buttonControl in pairs(gAbilityButtonArray) do		
		gAbilitySlotDataArray[gHotBarCategory][slotId].isActive = false
		if gLastHotBarCategory then
			gAbilitySlotDataArray[gLastHotBarCategory][slotId].isActive = false
		end
	end	
	
	AUI.Actionbar.AbilityButtons.UpdateUI()	
end

function AUI.Actionbar.AbilityButtons.UpdateGameSettings()
	gDefaultTimerSettingState = GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS)
	gDefaultTimerBackbarSettingState = GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_BACK_ROW)
	
	if not gDefaultTimerSettingState and AUI.Settings.Actionbar.ability_cooldowns.Forground.show_remaining_time or not gDefaultTimerSettingState and AUI.Settings.Actionbar.ability_cooldowns.Forground.show_cooldown_frame then
		SetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS, "true")
	end
	
	if gDefaultTimerBackbarSettingState and AUI.Settings.Actionbar.ability_cooldowns.Background.show_remaining_time or gDefaultTimerBackbarSettingState and AUI.Settings.Actionbar.ability_cooldowns.Background.show_cooldown_frame then
		SetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_BACK_ROW, "false")
	end
end

function AUI.Actionbar.AbilityButtons.Load()
	if gIsLoaded then
		return
	end
	
	gIsLoaded = true
	
	CreateButtons()
	CreateUltimateButton()
	CreateDataIfNotExists()	
	
	gHotBarCategory = GetActiveHotbarCategory() 		
	gLastHotBarCategory = nil

	for slotId, actionButton in pairs(gAbilityButtonArray) do
		if actionButton.cooldownFrame then
			actionButton.cooldownFrame:SetHidden(true)
		end
		
		if actionButton.swapInfoControl.cooldownFrame then
			actionButton.swapInfoControl.cooldownFrame:SetHidden(true)
		end
	end
	
	ACTION_BAR_FRAGMENT:RegisterCallback("StateChange", 
	function(oldState, newState)
		if newState == SCENE_SHOWN then	
			for slotId, actionButton in pairs(gAbilityButtonArray) do
				if actionButton.cooldownFrame then
					if AUI.Settings.Actionbar.ability_cooldowns.Forground.show_cooldown_frame then
						actionButton.cooldownFrame:SetHidden(false)
					else
						actionButton.cooldownFrame:SetHidden(true)
					end
				end
				
				if actionButton.swapInfoControl.cooldownFrame then
					if AUI.Settings.Actionbar.ability_cooldowns.Background.show_cooldown_frame then
						actionButton.swapInfoControl.cooldownFrame:SetHidden(false)
					else
						actionButton.swapInfoControl.cooldownFrame:SetHidden(true)
					end
				end
			end		
		elseif newState == SCENE_HIDING then	
			for slotId, actionButton in pairs(gAbilityButtonArray) do	
				if actionButton.cooldownFrame then
					actionButton.cooldownFrame:SetHidden(true)
				end
				
				if actionButton.swapInfoControl.cooldownFrame then
					actionButton.swapInfoControl.cooldownFrame:SetHidden(true)
				end
			end		
		end												
	end)

	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_AB_BUTTONS_UNIT_DEATH_STATE_CHANGED", EVENT_UNIT_DEATH_STATE_CHANGED, OnUnitDeathStateChanged)		
end