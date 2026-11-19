local appName = "wardTracker"

local debug = false
local isInCombat = false
local wardWarningPercentage = 0.50
local wardThreshold = 0
local shieldStr = 0
local totalOriginalShield = 0
local shieldActive = false
local changeGained = 1
local changeGone = 2
local changeUpdated = 3
local abilityTypeDamageShield = 15
local ward1 = false
local ward2 = false
local boundArmamentsID = 203447
local hasStacks = false

wardTracker = {}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

--check if LibNotify is available
local function isLibAvailable()
    if LibNotify and type(LibNotify.notifyForAddonPlease) == "function" then
        return true
    else 
		return false
    end
end

--whenever shield is added, updated, removed, this is for notification that a specific shield has ended
local function WardCheck(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

	if unitTag ~= "player" then return end
    if abilityType ~= abilityTypeDamageShield then return end

	local name = tostring(effectName)

	--if shield was added
	if changeType == changeGained then
		if name == "Hardened Ward" then
			ward1 = true
		elseif name == "Warding Contingency" then
			ward2 = true
		end
		if debug then printMessage("WardCheck, changeGained: " .. name) end

	--if shield was removed
	elseif changeType == changeGone then
		if name == "Hardened Ward" then
			ward1 = false
			zo_callLater(function()
				if not ward1 then if isLibAvailable() --[[and wardTracker.savedVariables.notify]] then LibNotify.notifyForAddonPlease(appName, abilityID, "Hardened Ward ended!!") end end
			end, 50)
		elseif name == "Warding Contingency" then
			ward2 = false
			zo_callLater(function()
				if not ward2 then if isLibAvailable() --[[and wardTracker.savedVariables.notify]] then LibNotify.notifyForAddonPlease(appName, abilityID, "Warding Contingency ended!!") end end
			end, 50)
		end
		if debug then printMessage("WardCheck, changeGone: " .. name) end

	--shield was updated
	elseif changeType == changeUpdated then
		if debug then printMessage("WardCheck, changeUpdated: " .. name) end
	end
end

--triggers whenever shield is added, updated, removed. Saves player's shield value whenever a shield is added or updated
local function OnAnyWardChange(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType, oldValue, newValue, oldMaxValue, newMaxValue, sequenceId)

	if unitTag ~= "player" then return end
	if unitAttributeVisual ~= 5 then return end

	--player receives first shield
	if eventCode == EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
		shieldStr = newValue or oldValue or 0
		totalOriginalShield = newMaxValue or shieldStr
		wardThreshold = totalOriginalShield * wardWarningPercentage
		wardTrackAddonTextIcon:SetText("")
		wardTrackAddonText:SetHidden(true)
	--player shield has been updated (damaged, refreshed, or 2nd shield added/removed)
	elseif eventCode == EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED then
		shieldActive = true
		shieldStr = newValue
		--a second shield was added (max increased)
		if newMaxValue > oldMaxValue then
			totalOriginalShield = totalOriginalShield + (newMaxValue - oldMaxValue)
			wardThreshold = totalOriginalShield * wardWarningPercentage
			wardTrackAddonTextIcon:SetText("")
			wardTrackAddonText:SetHidden(true)
		--one of multiple shields expired (max decreased, but shield still active)
		elseif newMaxValue < oldMaxValue then
			totalOriginalShield = math.max(newMaxValue, totalOriginalShield - (oldMaxValue - newMaxValue))
			wardThreshold = totalOriginalShield * wardWarningPercentage
		end
		--check if combined shield dropped below 50% of combined original values
		if shieldStr > 0 and wardThreshold >= shieldStr and isInCombat then
			PlaySound(SOUNDS.DUEL_START)
			wardTrackAddonTextIcon:SetText("Shield LOW Re-Cast!")
			wardTrackAddonText:SetHidden(false)
		end
	--player has lost all shields completely
	elseif eventCode == EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED then
		shieldActive = false
		shieldStr = 0
		totalOriginalShield = 0
		wardThreshold = 0
		if isInCombat then
			PlaySound(SOUNDS.DUEL_START)
			wardTrackAddonTextIcon:SetText("Shield DOWN Re-Cast!")
			wardTrackAddonText:SetHidden(false)
		end
	else
		return
	end
end

--whenever a stack of bound armaments is gained
local function boundNotify(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

	if unitTag ~= "player" then return end
    if abilityID ~= boundArmamentsID then return end

    if changeType == 2 then
		--clear message
		wardTrackAddonTextBound:SetHidden(true)
		hasStacks = false
    elseif changeType == 3 then
		--if stack is above 4 display message else clear
		if stackCount >= 4 then
			wardTrackAddonTextBound:SetHidden(false)
			hasStacks = true
		else
			wardTrackAddonTextBound:SetHidden(true)
			hasStacks = false
		end
    end
end

--when player is in and out of combat
local function OnPlayerCombatState(event, inCombat)
	if inCombat ~= isInCombat then
		isInCombat = inCombat
		--if player is not in combat hide text area
        if not inCombat then
            wardTrackAddonTextIcon:SetText("")
            wardTrackAddonText:SetHidden(true)
			wardTrackAddonTextBound:SetHidden(true)
        end
	end
end

--register for notifications about shields
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("hwtEvent", EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
	EVENT_MANAGER:RegisterForEvent("hwtEvent", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnAnyWardChange)
	EVENT_MANAGER:RegisterForEvent("hwtEvent", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnAnyWardChange)
	EVENT_MANAGER:RegisterForEvent("hwtEvent", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnAnyWardChange)
	EVENT_MANAGER:RegisterForEvent("hwtEvent", EVENT_EFFECT_CHANGED, WardCheck)
	EVENT_MANAGER:RegisterForEvent("baEvent", EVENT_EFFECT_CHANGED, boundNotify)
    EVENT_MANAGER:AddFilterForEvent("baEvent", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, boundArmamentsID)
end

--unregister for notifications about shields
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("hwtEvent", EVENT_PLAYER_COMBAT_STATE)
    EVENT_MANAGER:UnregisterForEvent("hwtEvent", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
	EVENT_MANAGER:UnregisterForEvent("hwtEvent", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
	EVENT_MANAGER:UnregisterForEvent("baEvent", EVENT_EFFECT_CHANGED)

end

--when UI opens
local function onMenuOpened()
	--hide text area
    wardTrackAddonText:SetHidden(true)
	wardTrackAddonTextBound:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	--if player has active shield and is in combat show text area when exiting menu otherwise leave hidden
	if shieldActive and isInCombat then
    	wardTrackAddonText:SetHidden(false)
	end
	if hasStacks and isInCombat then
		wardTrackAddonTextBound:SetHidden(false)
	end
end

--UI has been opened or closed
local function onSceneStateChange(scene, oldState, newState)
	local sceneName = SCENE_MANAGER:GetCurrentScene():GetName()
	if sceneName == "hud" then
		if  newState == SCENE_HIDING then onMenuOpened()
		elseif  newState == SCENE_HIDDEN then onMenuClosed()
		end
	end
end

--handle addon loaded callback
local function onAddOnLoadedWard(event, name)
    --if add-on loaded was not this add-on quit
    if name ~= appName then
        return
    end

    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 500)
		return
    elseif isLibAvailable() --[[ todo: and wardTracker.savedVariables.trackWard]] then
		--notify that add-on has been loaded
		zo_callLater(function() printMessage("add-on loaded") end, 500)
	end

    --setup text field area for bound armament and shield notifications
    wardTrackAddonText:SetMovable(true)
    wardTrackAddonTextIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_61)|soft-shadow-thick")
    wardTrackAddonTextIcon:SetText("")
    wardTrackAddonTextIcon:SetColor(255, 0, 0, 255)
    wardTrackAddonText:SetHidden(true)

	wardTrackAddonTextBound:SetMovable(true)
    wardTrackAddonTextBoundIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_61)|soft-shadow-thick")
    wardTrackAddonTextBoundIcon:SetText("Fire Armaments!!")
    wardTrackAddonTextBoundIcon:SetColor(255, 0, 0, 255)
    wardTrackAddonTextBound:SetHidden(true)

    --register for combat alerts
    registerAlerts()

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoadedWard)
