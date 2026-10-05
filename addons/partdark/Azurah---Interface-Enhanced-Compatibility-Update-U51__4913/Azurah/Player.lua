local Azurah		= _G['Azurah'] -- grab addon table from global
local LMP			= LibMediaProvider

-- UPVALUES --
local AZ_POWERTYPE_HEALTH			= COMBAT_MECHANIC_FLAGS_HEALTH
local AZ_POWERTYPE_MAGICKA			= COMBAT_MECHANIC_FLAGS_MAGICKA
local AZ_POWERTYPE_STAMINA			= COMBAT_MECHANIC_FLAGS_STAMINA
local AZ_POWERTYPE_MOUNT_STAMINA	= COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA
local strformat						= string.format

local overlayHealth, overlayMagicka, overlayStamina
local FormatHealth,	FormatMagicka, FormatStamina
local origExpanded, origShrunk
local db

local function UpdateOverlay(powerType, powerValue, powerMax, powerEffMax)
	if (powerValue == nil) then
		powerValue, powerMax, powerEffMax = GetUnitPower('player', powerType)
	end

	if (powerType == AZ_POWERTYPE_HEALTH) then
		if (db.healthOverlayShield) then
			shield = GetUnitAttributeVisualizerEffectInfo('player', ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH,
				AZ_POWERTYPE_HEALTH)
		end

		overlayHealth:SetText(FormatHealth(powerValue, powerMax, powerEffMax, shield))
	elseif (powerType == AZ_POWERTYPE_MAGICKA) then
		overlayMagicka:SetText(FormatMagicka(powerValue, powerMax, powerEffMax))
	elseif (powerType == AZ_POWERTYPE_STAMINA) then
		overlayStamina:SetText(FormatStamina(powerValue, powerMax, powerEffMax))
	end
end

local function OnPowerUpdate(_, unit, _, powerType, powerValue, powerMax, powerEffMax)
	UpdateOverlay(powerType, powerValue, powerMax, powerEffMax)
end

local function OnShieldUpdate(_, unit, attributeVisual)
	if (unit ~= 'player') then return end -- only care about the player

	UpdateOverlay(AZ_POWERTYPE_HEALTH)
end

local function OnCombatChange()
	if (tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_RESOURCE_BARS)) == RESOURCE_BARS_SETTING_CHOICE_AUTOMATIC) then
		Azurah:UpdateAttributeFade(IsUnitInCombat('player'), false)
    end
end

function Azurah:ConfigureAttributeOverlays()
	if (db.healthOverlay > 1 or db.magickaOverlay > 1 or db.staminaOverlay > 1) then -- showing at least one overlay, enable tracking
		EVENT_MANAGER:RegisterForEvent(self.name .. 'Attributes', EVENT_POWER_UPDATE, OnPowerUpdate)
		EVENT_MANAGER:AddFilterForEvent(self.name .. 'Attributes',	EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, 'player')

		if (db.healthOverlay > 1 and db.healthOverlayShield) then
			EVENT_MANAGER:RegisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnShieldUpdate)
			EVENT_MANAGER:RegisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnShieldUpdate)
			EVENT_MANAGER:RegisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnShieldUpdate)
		else
			EVENT_MANAGER:UnregisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
			EVENT_MANAGER:UnregisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
			EVENT_MANAGER:UnregisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
		end
	else -- no overlays being shown, disable tracking
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Attributes', EVENT_POWER_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED)
		EVENT_MANAGER:UnregisterForEvent(self.name .. 'Attributes', EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED)
	end

	local fontStr

	-- configure health overlay
	if (db.healthOverlay > 1) then
		fontStr = strformat('%s|%d|%s', LMP:Fetch('font', db.healthFontFace), db.healthFontSize, db.healthFontOutline)

		overlayHealth:SetFont(fontStr)
		overlayHealth:SetColor(db.healthFontColour.r, db.healthFontColour.g, db.healthFontColour.b, db.healthFontColour.a)
		overlayHealth:SetHidden(false)

		FormatHealth = self.overlayFuncs[db.healthOverlay + ((db.healthOverlayFancy) and 10 or 0)]

		UpdateOverlay(AZ_POWERTYPE_HEALTH)
	else -- not showing
		overlayHealth:SetHidden(true)
	end

	-- configure magicka overlay
	if (db.magickaOverlay > 1) then
		fontStr = strformat('%s|%d|%s', LMP:Fetch('font', db.magickaFontFace), db.magickaFontSize, db.magickaFontOutline)

		overlayMagicka:SetFont(fontStr)
		overlayMagicka:SetColor(db.magickaFontColour.r, db.magickaFontColour.g, db.magickaFontColour.b, db.magickaFontColour.a)
		overlayMagicka:SetHidden(false)

		FormatMagicka = self.overlayFuncs[db.magickaOverlay + ((db.magickaOverlayFancy) and 10 or 0)]

		UpdateOverlay(AZ_POWERTYPE_MAGICKA)
	else -- not showing
		overlayMagicka:SetHidden(true)
	end

	-- configure stamina overlay
	if (db.staminaOverlay > 1) then
		fontStr = strformat('%s|%d|%s', LMP:Fetch('font', db.staminaFontFace), db.staminaFontSize, db.staminaFontOutline)

		overlayStamina:SetFont(fontStr)
		overlayStamina:SetColor(db.staminaFontColour.r, db.staminaFontColour.g, db.staminaFontColour.b, db.staminaFontColour.a)
		overlayStamina:SetHidden(false)

		FormatStamina = self.overlayFuncs[db.staminaOverlay + ((db.staminaOverlayFancy) and 10 or 0)]

		UpdateOverlay(AZ_POWERTYPE_STAMINA)
	else -- not showing
		overlayStamina:SetHidden(true)
	end
end

function Azurah:ConfigureAttributeFade()
	for index, bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
		if (bar.unitTag == 'player' and (bar.powerType == AZ_POWERTYPE_HEALTH or bar.powerType == AZ_POWERTYPE_MAGICKA or bar.powerType == AZ_POWERTYPE_STAMINA)) then

			bar.timeline:GetAnimation():SetAlphaValues(db.fadeMinAlpha, db.fadeMaxAlpha)
			bar.timeline:PlayBackward()

			if (tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_RESOURCE_BARS)) == RESOURCE_BARS_SETTING_CHOICE_ALWAYS_SHOW) then
				bar.timeline:PlayForward()
			end
		else
			bar.timeline:GetAnimation():SetAlphaValues(0, db.fadeMaxAlpha)
			bar.timeline:PlayBackward()
		end
	end

	if (db.combatBars) then
		EVENT_MANAGER:RegisterForEvent(Azurah.name.."ATTRIBUTES", EVENT_PLAYER_COMBAT_STATE, OnCombatChange)
	else
		EVENT_MANAGER:UnregisterForEvent(Azurah.name.."ATTRIBUTES", EVENT_PLAYER_COMBAT_STATE)
	end

	self:UpdateAttributeFade(IsUnitInCombat('player'), true)
end

function Azurah:UpdateAttributeFade(combat, reset)
	if reset then
		PLAYER_ATTRIBUTE_BARS.forceShow = false

		for index, bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
			bar:SetForceVisible(false)
			bar.forcedVisibleReferences = 0
        end

        if shieldActive then
			ZO_PlayerAttributeHealth.playerAttributeBarObject:AddForcedVisibleReference()
		end
	end

	if ((db.combatBars or Azurah.db.globalOpacityOn) and PLAYER_ATTRIBUTE_BARS.forceShow ~= combat) then
        PLAYER_ATTRIBUTE_BARS.forceShow = combat

		for index, bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
            if combat then
                bar:AddForcedVisibleReference()
            else
                bar:RemoveForcedVisibleReference(true)
            end
        end
    end
end

function Azurah:ConfigureAttributeFade_Old()
	local minH, minM, minS, maxH, maxM, maxS
	local curH, curM, curS, curMS, emaxH, emaxM, emaxS, emaxS, emaxMS

	local inCombat		= IsUnitInCombat('player') and true or false

	curH, _, emaxH		= GetUnitPower("player", AZ_POWERTYPE_HEALTH)
	curM, _, emaxM		= GetUnitPower("player", AZ_POWERTYPE_MAGICKA)
	curS, _, emaxS		= GetUnitPower("player", AZ_POWERTYPE_STAMINA)
	curMS, _, emaxMS	= GetUnitPower("player", AZ_POWERTYPE_MOUNT_STAMINA)

	if (db.combatBars and inCombat) then
		minH = db.fadeMaxAlpha
		maxH = db.fadeMaxAlpha
		minM = db.fadeMaxAlpha
		maxM = db.fadeMaxAlpha
		minS = db.fadeMaxAlpha
		maxS = db.fadeMaxAlpha
	else
		minH = db.fadeMinAlpha
		maxH = db.fadeMaxAlpha

		if IsWerewolf('player') then -- alsays show magicka bar when in werewolf form
			minM = db.fadeMaxAlpha
			maxM = db.fadeMaxAlpha
		else
			minM = db.fadeMinAlpha
			maxM = db.fadeMaxAlpha
		end

		if IsMounted() then -- always show stamina bar when mounted
			minS = db.fadeMaxAlpha
			maxS = db.fadeMaxAlpha
		else
			minS = db.fadeMinAlpha
			maxS = db.fadeMaxAlpha
		end
	end

	ZO_PlayerAttributeHealth.playerAttributeBarObject.timeline:GetAnimation():SetAlphaValues(minH, maxH)
	ZO_PlayerAttributeStamina.playerAttributeBarObject.timeline:GetAnimation():SetAlphaValues(minM, maxM)
	ZO_PlayerAttributeMagicka.playerAttributeBarObject.timeline:GetAnimation():SetAlphaValues(minS, maxS)

	ZO_PlayerAttributeMountStamina.playerAttributeBarObject.timeline:GetAnimation():SetAlphaValues(0, maxS)
	ZO_PlayerAttributeWerewolf.playerAttributeBarObject.timeline:GetAnimation():SetAlphaValues(0, maxM)
	ZO_PlayerAttributeSiegeHealth.playerAttributeBarObject.timeline:GetAnimation():SetAlphaValues(0, maxH)

	if (curH >= emaxH) then
		ZO_PlayerAttributeHealth:SetAlpha(minH)
	end
	if (curM >= emaxM) then
		ZO_PlayerAttributeMagicka:SetAlpha(minM)
	end
	if (curS >= emaxS and curMS >= emaxMS) then
		ZO_PlayerAttributeStamina:SetAlpha(minS)
	end
end

function Azurah:ConfigureAttributeSizeLock()
	local primaryStats = {
		{statType = STAT_HEALTH_MAX, attributeType = ATTRIBUTE_HEALTH, powerType = AZ_POWERTYPE_HEALTH},
		{statType = STAT_MAGICKA_MAX, attributeType = ATTRIBUTE_MAGICKA, powerType = AZ_POWERTYPE_MAGICKA},
		{statType = STAT_STAMINA_MAX, attributeType = ATTRIBUTE_STAMINA, powerType = AZ_POWERTYPE_STAMINA}
	}

	for index, visualizer in pairs(PLAYER_ATTRIBUTE_BARS.attributeVisualizer.visualModules) do
		if visualizer:IsUnitVisualRelevant(ATTRIBUTE_VISUAL_INCREASED_MAX_POWER, STAT_HEALTH_MAX) then	-- this is the size changer
			if (not origExpanded) then -- haven't noted down defaults yet
				origExpanded = visualizer.expandedWidth
				origShrunk = visualizer.shrunkWidth
			end

			if (db.lockSize) then -- locking attribute size
				visualizer.expandedWidth = visualizer.normalWidth
				visualizer.shrunkWidth = visualizer.normalWidth

				-- Update the size
				for index, stat in pairs(primaryStats) do
					visualizer.barInfo[stat.statType].value = 0
					visualizer:OnValueChanged(visualizer.barControls[stat.statType], visualizer.barInfo[stat.statType], stat.statType, true)
				end
			elseif visualizer.expandedWidth ~= origExpanded or visualizer.shrunkWidth ~= origShrunk then
				visualizer.expandedWidth = origExpanded
				visualizer.shrunkWidth = origShrunk

				-- Update the size
				for index, stat in pairs(primaryStats) do
					local buff = GetUnitAttributeVisualizerEffectInfo("player", ATTRIBUTE_VISUAL_INCREASED_MAX_POWER, stat.statType,
						stat.attributeType, stat.powerType)

					visualizer.barInfo[stat.statType].value = buff or 0
					visualizer:OnValueChanged(visualizer.barControls[stat.statType], visualizer.barInfo[stat.statType], stat.statType, true)
				end
			end
		end
	end
end


-- ------------------------
-- INITIALIZATION
-- ------------------------
function Azurah:InitializePlayer()
	db = self.db.attributes

	-- create overlays
	overlayHealth	= self:CreateOverlay(ZO_PlayerAttributeHealth, CENTER, CENTER, 0, 0)
	overlayMagicka	= self:CreateOverlay(ZO_PlayerAttributeMagicka, CENTER, CENTER, 0, 0)
	overlayStamina	= self:CreateOverlay(ZO_PlayerAttributeStamina, CENTER, CENTER, 0, 0)

	-- set 'dummy' display functions
	FormatHealth	= self.overlayFuncs[1]
	FormatMagicka	= self.overlayFuncs[1]
	FormatStamina	= self.overlayFuncs[1]

	self:ConfigureAttributeOverlays()
	self:ConfigureAttributeFade()
	self:ConfigureAttributeSizeLock()
end
