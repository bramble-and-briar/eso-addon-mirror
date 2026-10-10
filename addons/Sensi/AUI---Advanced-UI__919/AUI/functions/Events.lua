local gApiVersion = GetAPIVersion()

local function OnActionLayerPopped(eventCode, layerIndex, activeLayerIndex)
	AUI.HideMouseMenu()
end

local function OnActionLayerPushed(eventCode, layerIndex, activeLayerIndex)
	AUI.HideMouseMenu()
end

local function OnPlayerActivated(_eventCode)
	if AUI.IsLoaded() then
		AUI.SendStartMessage()
		
		OnActionLayerPopped(0, 0, 0)
		
		if AUI.Minimap.IsEnabled() then
			AUI.Minimap.Theme.Load()	
			AUI.Minimap.Refresh()		
		end

		if AUI.UnitFrames.IsEnabled() then
			AUI.UnitFrames.OnPlayerActivated()
		end
		
		if AUI.Buffs.IsEnabled() then
			AUI.Buffs.OnPlayerActivated()
		end	

		if AUI.Combat.IsEnabled() then
			local powerValue, powerMax, powerEffectiveMax = GetUnitPower(AUI_PLAYER_UNIT_TAG, POWERTYPE_ULTIMATE)
			AUI.Combat.OnPowerUpdate(AUI_PLAYER_UNIT_TAG, 4, POWERTYPE_ULTIMATE, powerValue, powerMax, powerEffectiveMax)
		end
		
		if AUI.FrameMover.IsEnabled() then
			AUI.FrameMover.OnPlayerActivated()
		end	

		if AUI.Actionbar.IsEnabled() then
			AUI.Actionbar.OnPlayerActivated() 
		end		
	end	
end

local function OnPowerUpdate(_eventCode, _unitTag, _powerIndex, _powerType, _powerValue, _powerMax, _powerEffectiveMax)
	if _unitTag == nil or _powerType == nil then
		return
	end	
	
	if AUI.UnitFrames.IsEnabled() then
		AUI.UnitFrames.OnPowerUpdate(_unitTag, _powerIndex, _powerType, _powerValue, _powerMax, _powerEffectiveMax)
	end
	
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.OnPowerUpdate(_unitTag, _powerIndex, _powerType, _powerValue, _powerMax, _powerEffectiveMax)
	end			
	
	if AUI.Combat.IsEnabled() then
		AUI.Combat.OnPowerUpdate(_unitTag, _powerIndex, _powerType, _powerValue, _powerMax, _powerEffectiveMax)
	end		
end

local function OnUnitAttributeVisualAdded(_eventCode, _unitTag, _unitAttributeVisual, _statType, _attributeType, _powerType, _powerValue, _powerMax)
	if _unitTag == nil or _powerType == nil then
		return
	end

	if AUI.UnitFrames.IsEnabled() then
		if _unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then	
			_, _powerMax, _ = GetUnitPower(_unitTag, _powerType)	
		end

		AUI.UnitFrames.AddAttributeVisual(_unitTag, _unitAttributeVisual, _statType, _attributeType, _powerType, _powerValue, _powerMax, _powerMax, true)
	end
end

local function OnUnitAttributeVisualRemoved(_eventCode, _unitTag, _unitAttributeVisual, _statType, _attributeType, _powerType, _powerValue, _powerMax)
	if _unitTag == nil or _powerType == nil then
		return
	end

	if AUI.UnitFrames.IsEnabled() then
		if _unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then	
			_, _powerMax, _ = GetUnitPower(_unitTag, _powerType)
			_powerValue = 0		
		else
			_powerValue = 0
			_powerMax = 0
		end	
		
		AUI.UnitFrames.RemoveAttributeVisual(_unitTag, _unitAttributeVisual, _statType, _attributeType, _powerType, _powerValue, _powerMax, _powerMax, true)
	end
end

local function OnUnitAttributeVisualUpdated(_eventCode, _unitTag, _unitAttributeVisual, _statType, _attributeType, _powerType, _oldPowerValue, _newPowerValue, _oldPowerMaxValue, _newPowerMaxValue)
	if _unitTag == nil or _powerType == nil then
		return
	end

	if AUI.UnitFrames.IsEnabled() then
		if _unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then	
			_, _newPowerMaxValue, _ = GetUnitPower(_unitTag, _powerType)
			
		end	

		AUI.UnitFrames.UpdateAttributeVisual(_unitTag, _unitAttributeVisual, _statType, _attributeType, _powerType, _newPowerValue, _newPowerMaxValue, _newPowerMaxValue, true)	
	end		
end

local function OnUnitDeathStateChanged(_eventCode, _unitTag, _isDead)
	if _unitTag ~= AUI_PLAYER_UNIT_TAG then
		if AUI.UnitFrames.IsEnabled() then
			AUI.UnitFrames.Update(_unitTag)
		end
	end
end

local function OnPlayerAlive(_eventCode)
	if AUI.UnitFrames.IsEnabled() then
		AUI.UnitFrames.Update(AUI_PLAYER_UNIT_TAG)
		
		if AUI.UnitFrames.Target.IsEnabled() then
			AUI.UnitFrames.Target.OnChanged()
		end
	end
end

local function OnPlayerDead(_eventCode)
	if AUI.UnitFrames.IsEnabled() then
		AUI.UnitFrames.Update(AUI_PLAYER_UNIT_TAG)
	end
end

local function OnUnitCreated(_eventCode, _unitTag)
	if AUI.UnitFrames.Group.IsEnabled() then
		zo_callLater(function()		
			AUI.UnitFrames.Group.UpdateUI()
		end, 200)
	end
end

local function OnUnitDestroyed(_eventCode, _unitTag)
	if AUI.UnitFrames.Group.IsEnabled() then
		zo_callLater(function()
			AUI.UnitFrames.Group.UpdateUI()
		end, 200)
	end
end

local function OnGroupMemberRoleChanged(_eventCode, _unitTag, _assignedRole)
	if AUI.UnitFrames.Group.IsEnabled() then
		AUI.UnitFrames.Group.UpdateUI()
	end
end

local function OnUnitFrameUpdate(_eventCode, _unitTag)
	if AUI.UnitFrames.Group.IsEnabled() then
		AUI.UnitFrames.Update(_unitTag)
	end
end

local function OnUnitLeaderUpdate(_eventCode, _unitTag)
	if AUI.UnitFrames.Group.IsEnabled() then
		AUI.UnitFrames.Group.UpdateUI()
	end	
end

local function OnGroupMemberConnectedStatus(_eventCode, _unitTag, _isOnline)
	if AUI.UnitFrames.Group.IsEnabled() then
		AUI.UnitFrames.Group.UpdateUI()
	end
end

local function OnGroupTypeChanged(_eventCode, _largeGroup)
	if AUI.UnitFrames.Group.IsEnabled() then
		AUI.UnitFrames.Group.UpdateUI()
	end
end

local function OnLevelUpdate(_eventCode, _unitTag, _level)
	if AUI.UnitFrames.IsEnabled() then
		AUI.UnitFrames.Update(_unitTag)
	end	
	
	if AUI.Combat.IsEnabled() then		
		AUI.Combat.OnLevelUpdate()			
	end		
end

local function OnGroupSupportRangeUpdate(_eventCode, _unitTag, _status)
	if AUI.UnitFrames.Group.IsEnabled() then
		AUI.UnitFrames.Update(_unitTag)
	end	
end

local function OnReticleTargetChanged(_eventCode)
	if AUI.UnitFrames.Target.IsEnabled() then
		AUI.UnitFrames.OnReticleTargetChanged()
	end
	
	if AUI.Buffs.IsEnabled() then
		AUI.Buffs.OnTargetChanged()
	end
end

local function OnCombatEvent(_eventCode, _result, _isError, _abilityName, _abilityGraphic, _abilityActionSlotType, _sourceName, _sourceType, _targetName, _targetType, _hitValue, _powerType, _damageType, _log, _sourceUnitId_, _targetUnitId_, _abilityId, _overflow)
	AUI.Combat.OnCombatEvent(_eventCode, _result, _isError, _abilityName, _abilityGraphic, _abilityActionSlotType, _sourceName, _sourceType, _targetName, _targetType, _hitValue, _powerType, _damageType, _log, _sourceUnitId_, _targetUnitId_, _abilityId, _overflow)	
end

local function OnEffectChanged(_eventCode, _changeType, _effectSlot, _effectName, _unitTag, _beginTime, _endTime, _stackCount, _iconName, _buffType, _effectType, _abilityType, _statusEffectType, _unitName, _unitId, _abilityId, _combatUnitType)
	local effectFilter = AUI.GetGlobalEffectFilter()
	if effectFilter[abilityId] then
		return
	end

	local castByPlayer = false
	if _combatUnitType == COMBAT_UNIT_TYPE_PLAYER or _combatUnitType == COMBAT_UNIT_TYPE_PLAYER_PET then
		castByPlayer = true
	end

	local procInfoData = AUI.Ability.GetProcInfo(_changeType, _abilityId, _stackCount, castByPlayer)
	
	if AUI.Combat.IsEnabled() then	
		AUI.Combat.OnEffectChanged(_changeType, _effectSlot, _effectName, _unitTag, _beginTime, _endTime, _stackCount, _iconName, _buffType, _effectType, _abilityType, _statusEffectType, _unitName, _unitId, _abilityId, _combatUnitType, procInfoData)	
	end	

	if AUI.Actionbar.IsEnabled() then	
		AUI.Actionbar.OnEffectChanged(_changeType, _effectSlot, _effectName, _unitTag, _beginTime, _endTime, _stackCount, _iconName, _buffType, _effectType, _abilityType, _statusEffectType, _unitName, _unitId, _abilityId, _combatUnitType, castByPlayer, procInfoData)	
	end	
	
	if AUI.Buffs.IsEnabled() then			
		AUI.Buffs.OnEffectChanged(_changeType, _effectSlot, _effectName, _unitTag, _beginTime, _endTime, _stackCount, _iconName, _buffType, _effectType, _abilityType, _statusEffectType, _unitName, _unitId, _abilityId, _combatUnitType)	
	end	
end

local function OnEffectsFullUpdate(eventCode)
	if AUI.Buffs.IsEnabled() then			
		AUI.Buffs.OnEffectChanged(AUI_PLAYER_UNIT_TAG)
		AUI.Buffs.OnEffectChanged(AUI_TARGET_UNIT_TAG)
	end		
end

local function OnPlayerCombatState(_eventCode, _inCombat)
	if AUI.Combat.IsEnabled() then			
		AUI.Combat.OnPlayerCombatState(_inCombat)	
	end	
	
	if _inCombat then		
		if AUI.Minimap.IsEnabled() and AUI.Settings.Minimap.enable then
			if AUI.Settings.Minimap.hide_in_combat then
				AUI.Minimap.Hide()
			end
		end		
	else		
		if AUI.Minimap.IsEnabled() and AUI.Settings.Minimap.hide_in_combat and AUI.Settings.Minimap.enable then
			if AUI.Settings.Minimap.hide_in_combat then
				AUI.Minimap.Show()
			end
		end
	end	
end

local function OnWerewolfStateChanged(eventCode, werewolf)
	if AUI.UnitFrames.IsEnabled() then
		AUI.UnitFrames.Update(AUI_PLAYER_UNIT_TAG)
	end	
end

local function OnAssistStateChanged(unassistedData, assistedData)	
	if AUI.Questtracker.IsEnabled() then
		AUI.Questtracker.Update()
	end			
end

local function OnQuestAdvanced(eventCode, journalIndex, questName, isPushed, isComplete, mainStepChanged)
	if AUI.Questtracker.IsEnabled() then
		AUI.Questtracker.Update()
	end		
end

local function OnQuestAdded(eventCode, journalIndex, questName, objectiveName)
	if AUI.Questtracker.IsEnabled() then
		AUI.Questtracker.Update()
	end		
end

local function OnQuestRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex)
	if AUI.Questtracker.IsEnabled() then
		AUI.Questtracker.Update()
	end		
end

local function OnQuestListUpdated(eventCode)
	if AUI.Questtracker.IsEnabled() then
		AUI.Questtracker.Update()
	end		
end

local function OnQuestConditionCounterChanged(eventCode, journalIndex, questName, conditionText, conditionType, currConditionVal, newConditionVal, conditionMax, isFailCondition, stepOverrideText, isPushed, isComplete, isConditionComplete, isStepHidden)
	if AUI.Questtracker.IsEnabled() then
		AUI.Questtracker.Update()
	end		
end

local function OnQuestTimerUpdated(eventCode, journalIndex)
	if AUI.Questtracker.IsEnabled() then
		AUI.Questtracker.UpdateQuestTimer(journalIndex)
	end		
end

local function OnActionUpdateCooldowns(eventCode) 
	if AUI.Combat.IsEnabled() then
		AUI.Combat.OnActionUpdateCooldowns()
	end	
	
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.OnActionUpdateCooldowns()
	end	
end

local function OnAllHotbarsUpdated(eventCode)
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.OnAllHotbarsUpdated()
	end
end

local function OnActionSlotUpdate(eventCode, actionSlotIndex)
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.OnActionSlotUpdate(actionSlotIndex)
	end
end

local function OnActionSlotEffectUpdated(eventCode, hotbarCategory, actionSlotIndex)
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.OnActionSlotEffectUpdated(hotbarCategory, actionSlotIndex)
	end
end

local function OnActionSlotsFullUpdate(eventCode, isHotbarSwap)
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.OnActionSlotsFullUpdate(isHotbarSwap)
	end
end

local function OnActionSlotsActiveUpdated(eventCode, didActiveHotbarChange, shouldUpdateAbilityAssignments, activeHotbarCategory)
	if AUI.Actionbar.IsEnabled() then
		if didActiveHotbarChange then
			AUI.Actionbar.OnSwapActionBar(activeHotbarCategory)
		end
	end
end

local function OnCompanionStateChanged(eventCode, newState, oldState)
	if newState == COMPANION_STATE_ACTIVE or newState == COMPANION_STATE_INACTIVE then
		AUI.Actionbar.UpdateUI()
		AUI.UnitFrames.UpdateUI()
	end
end

local function OnBeginSiegeControl(eventCode) 
	AUI.UnitFrames.UpdateSingleBar(AUI_CONTROLED_SIEGE_UNIT_TAG, POWERTYPE_HEALTH)
end

local function OnEndSiegeControl(eventCode) 
	AUI.UnitFrames.UpdateSingleBar(AUI_CONTROLED_SIEGE_UNIT_TAG, POWERTYPE_HEALTH)
end

local function OnLeaveRamEscort(eventCode) 
	AUI.UnitFrames.UpdateSingleBar(AUI_CONTROLED_SIEGE_UNIT_TAG, POWERTYPE_HEALTH)
end

local function OnBossesChanged(eventCode)
	AUI.UnitFrames.Boss.OnChanged()
end

local function OnExperienceUpdate(eventCode, unitTag, currentExp, maxExp, reason)
	if reason ~= CURRENCY_CHANGE_REASON_PLAYER_INIT then
		if AUI.Combat.IsEnabled() then
			if unitTag == AUI_PLAYER_UNIT_TAG then
				AUI.Combat.OnExperienceUpdate(unitTag, currentExp, maxExp, reason)
			end
		end
	end
end

local function OnAlliancePointUpdate(eventCode, alliancePoints, playSound, difference)
	AUI.Combat.OnAlliancePointUpdate(alliancePoints, difference)
end

local function OnInventoryItemUsed(eventCode, itemSoundCategory)
	if AUI.Combat.IsEnabled() then
		AUI.Combat.OnInventoryItemUsed(itemSoundCategory)
	end	
end

local function OnInventorySingleSlotUpdate(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason)
	if AUI.Combat.WeaponChargeWarner.IsEnabled() and bagId == BAG_WORN and inventoryUpdateReason == INVENTORY_UPDATE_REASON_ITEM_CHARGE then
		AUI.Combat.WeaponChargeWarner.UpdateAll()
	end	

	if AUI.Combat.IsEnabled() and bagId == BAG_BACKPACK and inventoryUpdateReason == INVENTORY_UPDATE_REASON_DEFAULT then
		AUI.Actionbar.OnActionSlotsFullUpdate(false)	
	end
end

local function OnTelVarStoneUpdate(eventCode, newTelvarStones, oldTelvarStones, reason)
	if reason ~= CURRENCY_CHANGE_REASON_PLAYER_INIT then
		AUI.Combat.OnTelVarStoneUpdate(newTelvarStones, oldTelvarStones)
	end
end

local function OnScreenResized(eventCode, x, y, guiName)
	if AUI.UnitFrames.IsEnabled() then
		AUI.UnitFrames.UpdateUI()
	end

	if AUI.FrameMover.IsEnabled() then
		AUI.FrameMover.UpdateAll() 
	end			
end

local function OnGamepadPreferredModeChanged(eventCode, gamepadPreferred)
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.OnGamepadPreferredModeChanged(gamepadPreferred)
	end	
	
	if AUI.FrameMover.IsEnabled() then
		AUI.FrameMover.OnGamepadPreferredModeChanged(gamepadPreferred)
	end

	if AUI.Buffs.IsEnabled() then
		AUI.Buffs.OnGamepadPreferredModeChanged(gamepadPreferred)
	end		
end

local function OnInterfaceSettingChanged(eventCode, settingSystemType, settingId)
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.OnInterfaceSettingChanged(settingSystemType, settingId)
	end		
end

function AUI.LoadEvents()
	--Abilities, Attributes, and XP 
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_POWER_UPDATE", EVENT_POWER_UPDATE, OnPowerUpdate)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_LEVEL_UPDATE", EVENT_LEVEL_UPDATE, OnLevelUpdate)	
	
	--Life and Death
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_UNIT_DEATH_STATE_CHANGED", EVENT_UNIT_DEATH_STATE_CHANGED, OnUnitDeathStateChanged)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_PLAYER_ALIVE", EVENT_PLAYER_ALIVE, OnPlayerAlive)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_PLAYER_DEAD ", EVENT_PLAYER_DEAD , OnPlayerDead)	
	
	--UI 	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_RETICLE_TARGET_CHANGED", EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)					
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_SCREEN_RESIZED", EVENT_SCREEN_RESIZED, OnScreenResized)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTION_LAYER_POPPED", EVENT_ACTION_LAYER_POPPED, OnActionLayerPopped)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTION_LAYER_PUSHED", EVENT_ACTION_LAYER_PUSHED, OnActionLayerPushed)	
 	 
	--Groups 
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_LEADER_UPDATE", EVENT_LEADER_UPDATE, OnUnitLeaderUpdate)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_GROUP_MEMBER_CONNECTED_STATUS", EVENT_GROUP_MEMBER_CONNECTED_STATUS, OnGroupMemberConnectedStatus)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_GROUP_TYPE_CHANGED", EVENT_GROUP_TYPE_CHANGED, OnGroupTypeChanged)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_GROUP_SUPPORT_RANGE_UPDATE", EVENT_GROUP_SUPPORT_RANGE_UPDATE, OnGroupSupportRangeUpdate)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_UNIT_CREATED", EVENT_UNIT_CREATED, OnUnitCreated)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_UNIT_DESTROYED", EVENT_UNIT_DESTROYED, OnUnitDestroyed)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_UNIT_FRAME_UPDATE", EVENT_UNIT_FRAME_UPDATE, OnUnitFrameUpdate)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_GROUP_MEMBER_ROLE_CHANGED", EVENT_GROUP_MEMBER_ROLE_CHANGED, OnGroupMemberRoleChanged)	
		
	--Combat 
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnUnitAttributeVisualAdded)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnUnitAttributeVisualRemoved)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnUnitAttributeVisualUpdated)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_COMBAT_EVENT", EVENT_COMBAT_EVENT, OnCombatEvent)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_PLAYER_COMBAT_STATE", EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)			
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_BOSSES_CHANGED", EVENT_BOSSES_CHANGED, OnBossesChanged)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_EFFECT_CHANGED", EVENT_EFFECT_CHANGED, OnEffectChanged)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_EFFECTS_FULL_UPDATE", EVENT_EFFECTS_FULL_UPDATE, OnEffectsFullUpdate)
    EVENT_MANAGER:RegisterForEvent("AUI_EVENT_WEREWOLF_STATE_CHANGED", EVENT_WEREWOLF_STATE_CHANGED, OnWerewolfStateChanged)
  
	--Experience
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_EXPERIENCE_UPDATE", EVENT_EXPERIENCE_UPDATE, OnExperienceUpdate)
	
	--Inventory and Money 
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ALLIANCE_POINT_UPDATE", EVENT_ALLIANCE_POINT_UPDATE, OnAlliancePointUpdate)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_INVENTORY_ITEM_USED", EVENT_INVENTORY_ITEM_USED, OnInventoryItemUsed)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_INVENTORY_SINGLE_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySingleSlotUpdate)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_TELVAR_STONE_UPDATE", EVENT_TELVAR_STONE_UPDATE, OnTelVarStoneUpdate)
	
	--Action Bar 
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTION_UPDATE_COOLDOWNS", EVENT_ACTION_UPDATE_COOLDOWNS, OnActionUpdateCooldowns)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnActionSlotsActiveUpdated)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnAllHotbarsUpdated)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTION_SLOT_UPDATED", EVENT_ACTION_SLOT_UPDATED, OnActionSlotUpdate)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTION_SLOT_EFFECT_UPDATE", EVENT_ACTION_SLOT_EFFECT_UPDATE, OnActionSlotEffectUpdated)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTION_SLOTS_FULL_UPDATE", EVENT_ACTION_SLOTS_FULL_UPDATE, OnActionSlotsFullUpdate)	
		
	if (gApiVersion >= 101034) then
		EVENT_MANAGER:RegisterForEvent("AUI_EVENT_CURSOR_PICKUP", EVENT_CURSOR_PICKUP, function() zo_callLater(function() OnActionSlotsFullUpdate() end, 200) end)	
		EVENT_MANAGER:RegisterForEvent("AUI_EVENT_CURSOR_DROPPED", EVENT_CURSOR_DROPPED, function() zo_callLater(function() OnActionSlotsFullUpdate() end, 200) end)		
	end	
		
	-- Companion
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ACTIVE_COMPANION_STATE_CHANGED", EVENT_ACTIVE_COMPANION_STATE_CHANGED, OnCompanionStateChanged)	
		
	--Quests
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_QUEST_ADDED", EVENT_QUEST_ADDED, OnQuestAdded)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_QUEST_REMOVED", EVENT_QUEST_REMOVED, OnQuestRemoved)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_QUEST_LIST_UPDATED", EVENT_QUEST_LIST_UPDATED, OnQuestListUpdated)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_QUEST_CONDITION_COUNTER_CHANGED", EVENT_QUEST_CONDITION_COUNTER_CHANGED, OnQuestConditionCounterChanged)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_QUEST_ADVANCED", EVENT_QUEST_ADVANCED, OnQuestAdvanced)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_QUEST_TIMER_UPDATED", EVENT_QUEST_TIMER_UPDATED, OnQuestTimerUpdated)		
	
	--Siege Weapons 
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_BEGIN_SIEGE_CONTROL", EVENT_BEGIN_SIEGE_CONTROL, OnBeginSiegeControl)	
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_END_SIEGE_CONTROL", EVENT_END_SIEGE_CONTROL, OnEndSiegeControl)
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_LEAVE_RAM_ESCORT", EVENT_LEAVE_RAM_ESCORT, OnLeaveRamEscort)	
	
	--UI Gamepad 
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_GAMEPAD_PREFERRED_MODE_CHANGED", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnGamepadPreferredModeChanged)
	
	--Callbacks
	FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerAssistStateChanged", OnAssistStateChanged)	
	
	--Interface
	EVENT_MANAGER:RegisterForEvent("AUI_EVENT_INTERFACE_SETTING_CHANGED", EVENT_INTERFACE_SETTING_CHANGED, OnInterfaceSettingChanged)
end