local Azurah		= _G['Azurah'] -- grab addon table from global
local LMP			= LibMediaProvider

-- UPVALUES --
local AZ_POWERTYPE_ULTIMATE		= COMBAT_MECHANIC_FLAGS_ULTIMATE
local AZ_ULTIMATE_SLOT			= 8
local GetSlotAbilityCost		= GetSlotAbilityCost
local GetUnitPower				= GetUnitPower
local math_min					= math.min
local math_max					= math.max
local strformat					= string.format

local overlayUltValue, overlayUltPercent
local FormatUlt, FormatUltPercent
local db

local GetActiveHotbarCategory		= GetActiveHotbarCategory

local function CheckAbilityCost(slot, power)
	return GetSlotAbilityCost(slot, power, GetActiveHotbarCategory())
end

local ultFuncs = {
	[1] = function(current) -- plain number
		return strformat('%d', current)
	end,
	[2] = function(current) -- value / ultimate cost
		local cost = CheckAbilityCost(AZ_ULTIMATE_SLOT, AZ_POWERTYPE_ULTIMATE)
		return strformat('%d / %d', current, cost)
	end,
	[3] = function(current) -- value / ultimate cost ("no overshoot")
		local cost = CheckAbilityCost(AZ_ULTIMATE_SLOT, AZ_POWERTYPE_ULTIMATE)
		return strformat('%d / %d', math_min(current, cost), cost)
	end
}

local ultPercentFuncs = {
	[1] = function(current, effMax) -- relative percent
		effMax = math_max(1, GetSlotAbilityCost(AZ_ULTIMATE_SLOT))
		current = ((db.ultPercentCap) and (current > effMax)) and effMax or current
		return strformat('%d%%', (current / effMax) * 100)
	end,
	[2] = function(current, effMax) -- total percent
		effMax = 500 -- ensure we don't do a divide by 0
		return strformat('%d%%', (current / effMax) * 100)
	end
}

local function OnPowerUpdate(_, unit, _, powerType, powerValue, powerMax, powerEffMax)
	if (unit ~= 'player') then return end -- only care about the player
	if (powerType ~= AZ_POWERTYPE_ULTIMATE) then return end -- only care about ultimate

	local effMax = math_max(1, CheckAbilityCost(AZ_ULTIMATE_SLOT, AZ_POWERTYPE_ULTIMATE))

	overlayUltValue:SetText(FormatUlt(powerValue))
	overlayUltPercent:SetText(FormatUltPercent(powerValue, effMax))

	local rV = ((db.ultVUseReadyColor) and (powerValue >= effMax)) and db.ultVReadyFontColour.r or db.ultValueFontColour.r
	local gV = ((db.ultVUseReadyColor) and (powerValue >= effMax)) and db.ultVReadyFontColour.g or db.ultValueFontColour.g
	local bV = ((db.ultVUseReadyColor) and (powerValue >= effMax)) and db.ultVReadyFontColour.b or db.ultValueFontColour.b
	local aV = ((db.ultVUseReadyColor) and (powerValue >= effMax)) and db.ultVReadyFontColour.a or db.ultValueFontColour.a
	overlayUltValue:SetColor(rV, gV, bV, aV)

	local rP = ((db.ultPUseReadyColor) and (powerValue >= effMax)) and db.ultPReadyFontColour.r or db.ultPercentFontColour.r
	local gP = ((db.ultPUseReadyColor) and (powerValue >= effMax)) and db.ultPReadyFontColour.g or db.ultPercentFontColour.g
	local bP = ((db.ultPUseReadyColor) and (powerValue >= effMax)) and db.ultPReadyFontColour.b or db.ultPercentFontColour.b
	local aP = ((db.ultPUseReadyColor) and (powerValue >= effMax)) and db.ultPReadyFontColour.a or db.ultPercentFontColour.a
	overlayUltPercent:SetColor(rP, gP, bP, aP)
end

local function OnWeaponPairChanged()
	local current = GetUnitPower('player', AZ_POWERTYPE_ULTIMATE)
	local effMax = math_max(1, CheckAbilityCost(AZ_ULTIMATE_SLOT, AZ_POWERTYPE_ULTIMATE))

	overlayUltValue:SetText(FormatUlt(current))
	overlayUltPercent:SetText(FormatUltPercent(current, effMax))

	local rV = ((db.ultVUseReadyColor) and (current >= effMax)) and db.ultVReadyFontColour.r or db.ultValueFontColour.r
	local gV = ((db.ultVUseReadyColor) and (current >= effMax)) and db.ultVReadyFontColour.g or db.ultValueFontColour.g
	local bV = ((db.ultVUseReadyColor) and (current >= effMax)) and db.ultVReadyFontColour.b or db.ultValueFontColour.b
	local aV = ((db.ultVUseReadyColor) and (current >= effMax)) and db.ultVReadyFontColour.a or db.ultValueFontColour.a
	overlayUltValue:SetColor(rV, gV, bV, aV)

	local rP = ((db.ultPUseReadyColor) and (current >= effMax)) and db.ultPReadyFontColour.r or db.ultPercentFontColour.r
	local gP = ((db.ultPUseReadyColor) and (current >= effMax)) and db.ultPReadyFontColour.g or db.ultPercentFontColour.g
	local bP = ((db.ultPUseReadyColor) and (current >= effMax)) and db.ultPReadyFontColour.b or db.ultPercentFontColour.b
	local aP = ((db.ultPUseReadyColor) and (current >= effMax)) and db.ultPReadyFontColour.a or db.ultPercentFontColour.a
	overlayUltPercent:SetColor(rP, gP, bP, aP)
end

local function OnUltimateSlotUpdated(_, actionSlotIndex)
	if actionSlotIndex ~= AZ_ULTIMATE_SLOT then return end
	OnWeaponPairChanged()
end

function Azurah:ConfigureUltimateOverlays()
	if (db.ultValueShow or db.ultPercentShow) then -- showing overlay, enable tracking\
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Ultimate', EVENT_POWER_UPDATE, 					OnPowerUpdate)
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Ultimate', EVENT_ACTIVE_WEAPON_PAIR_CHANGED,		OnWeaponPairChanged)
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Ultimate', EVENT_ACTION_SLOT_UPDATED,				OnUltimateSlotUpdated)
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Ultimate', EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,	OnWeaponPairChanged)

	else -- no overlay being shown, disable tracking
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Ultimate', EVENT_POWER_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Ultimate', EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Ultimate', EVENT_ACTION_SLOT_UPDATED)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Ultimate', EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED)
	end

	local fontStr, value, max, maxEff
	local current = GetUnitPower('player', AZ_POWERTYPE_ULTIMATE)
	local effMax = math_max(1, CheckAbilityCost(AZ_ULTIMATE_SLOT, AZ_POWERTYPE_ULTIMATE))

	if (db.ultValueShow) then
		fontStr = strformat('%s|%d|%s', LMP:Fetch('font', db.ultValueFontFace), db.ultValueFontSize, db.ultValueFontOutline)

		overlayUltValue:SetFont(fontStr)
		local rV = ((db.ultVUseReadyColor) and (current >= effMax)) and db.ultVReadyFontColour.r or db.ultValueFontColour.r
		local gV = ((db.ultVUseReadyColor) and (current >= effMax)) and db.ultVReadyFontColour.g or db.ultValueFontColour.g
		local bV = ((db.ultVUseReadyColor) and (current >= effMax)) and db.ultVReadyFontColour.b or db.ultValueFontColour.b
		local aV = ((db.ultVUseReadyColor) and (current >= effMax)) and db.ultVReadyFontColour.a or db.ultValueFontColour.a
		overlayUltValue:SetColor(rV, gV, bV, aV)
		overlayUltValue:ClearAnchors()
		overlayUltValue:SetAnchor(BOTTOM, ActionButton8, TOP, -1 + db.ultValueXoffset, 0 + db.ultValueYoffset)
		overlayUltValue:SetHidden(false)

		FormatUlt = ultFuncs[db.ultValueShowCost and 2 or 1]

		overlayUltValue:SetText(FormatUlt(GetUnitPower('player', AZ_POWERTYPE_ULTIMATE)))
	else
		overlayUltValue:SetHidden(true)
	end

	if (db.ultPercentShow) then
		fontStr = strformat('%s|%d|%s', LMP:Fetch('font', db.ultPercentFontFace), db.ultPercentFontSize, db.ultPercentFontOutline)

		overlayUltPercent:SetFont(fontStr)
		local rP = ((db.ultPUseReadyColor) and (current >= effMax)) and db.ultPReadyFontColour.r or db.ultPercentFontColour.r
		local gP = ((db.ultPUseReadyColor) and (current >= effMax)) and db.ultPReadyFontColour.g or db.ultPercentFontColour.g
		local bP = ((db.ultPUseReadyColor) and (current >= effMax)) and db.ultPReadyFontColour.b or db.ultPercentFontColour.b
		local aP = ((db.ultPUseReadyColor) and (current >= effMax)) and db.ultPReadyFontColour.a or db.ultPercentFontColour.a
		overlayUltPercent:SetColor(rP, gP, bP, aP)
		overlayUltPercent:ClearAnchors()
		overlayUltPercent:SetAnchor(BOTTOM, ActionButton8, BOTTOM, 0 + db.ultPercentXoffset, -2 + db.ultPercentYoffset)
		overlayUltPercent:SetHidden(false)

		FormatUltPercent = ultPercentFuncs[(db.ultPercentRelative) and 1 or 2]

		overlayUltPercent:SetText(FormatUltPercent(current, effMax))
	else
		overlayUltPercent:SetHidden(true)
	end
end

function Azurah:ConfigureActionBarElements()
	ZO_ActionBar1WeaponSwap:SetAlpha(db.hideWeaponSwap and 0 or 1)
	ZO_ActionBar1WeaponSwapLock:SetAlpha(db.hideWeaponSwap and 0 or 1)
	ZO_ActionBar1KeybindBG:SetAlpha(db.hideBindBG and 0 or 1)

	for x = 3, 8 do
		local button = _G['ActionButton' .. x .. 'ButtonText']
		if button ~= nil then
			button:SetAlpha(db.hideBindText and 0 or 1)
			button:SetHidden(db.hideBindText)
		end
	end
	_G['QuickslotButtonButtonText']:SetAlpha(db.hideBindText and 0 or 1)
	_G['QuickslotButtonButtonText']:SetHidden(db.hideBindText)
	_G['CompanionUltimateButtonButtonText']:SetAlpha(db.hideBindText and 0 or 1)
	_G['CompanionUltimateButtonButtonText']:SetHidden(db.hideBindText)

	if (IsInGamepadPreferredMode()) then
		-- special case for hiding companion ultimate button text (Phinix)
		_G['CompanionUltimateButtonLeftKeybind']:SetAlpha(0)
		_G['CompanionUltimateButtonLeftKeybind']:SetHidden(true)
		_G['CompanionUltimateButtonRightKeybind']:SetAlpha(0)
		_G['CompanionUltimateButtonRightKeybind']:SetHidden(true)
		-- special case for hiding ultimate button text (Phinix)
		_G['ActionButton8LeftKeybind']:SetAlpha(0)
		_G['ActionButton8LeftKeybind']:SetHidden(true)
		_G['ActionButton8RightKeybind']:SetAlpha(0)
		_G['ActionButton8RightKeybind']:SetHidden(true)
	end
end

-- ------------------------
-- INITIALIZATION
-- ------------------------
function Azurah:InitializeActionBar()
	db = self.db.actionBar

	-- create overlays
	overlayUltValue		= self:CreateOverlay(ActionButton8, BOTTOM, TOP, -1 + db.ultValueXoffset, 0 + db.ultValueYoffset)
	overlayUltPercent	= self:CreateOverlay(ActionButton8, BOTTOM, BOTTOM, 0 + db.ultPercentXoffset, -2 + db.ultPercentYoffset)

	-- set 'dummy' display function
	FormatUlt			= ultFuncs[1]
	FormatUltPercent	= ultPercentFuncs[2]

	-- Fix for scaling issue
	ActionButton8Decoration:SetAnchor(CENTER, ActionButton8, CENTER, 0, 0)
	
	self:ConfigureActionBarElements()
	self:ConfigureUltimateOverlays()
end
