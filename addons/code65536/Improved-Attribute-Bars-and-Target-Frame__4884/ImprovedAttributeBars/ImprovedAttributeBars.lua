local NAME = "ImprovedAttributeBars"


--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

local function FormatValues( current, maximum, shield, trauma, delimited )
	if (maximum and maximum > 0) then
		local percent = zo_floor(100 * current / maximum)
		if (delimited) then
			return zo_strformat("<<F:1>> / <<F:2>> (<<3>>%)", current, maximum, percent)
		elseif (shield or trauma) then
			return string.format(
				"%d%s%s / %d (%d%%)",
				current,
				(shield or 0) > 0 and string.format(" [+%d]", shield) or "",
				(trauma or 0) > 0 and string.format(" [-%d]", trauma) or "",
				maximum,
				percent
			)
		else
			return string.format("%d / %d (%d%%)", current, maximum, percent)
		end
	else
		return ""
	end
end

local function GetCurrentShieldAndTrauma( unitTag )
	local shield = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH)
	local trauma = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_TRAUMA, STAT_MITIGATION, ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH)
	return shield, trauma
end

local function RegisterShieldAndTraumaUpdate( unitTag, callback )
	local name = NAME .. unitTag
	-- Looping through EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED
	for eventCode = EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED do
		EVENT_MANAGER:RegisterForEvent(name, eventCode, callback)
		EVENT_MANAGER:AddFilterForEvent(name, eventCode, REGISTER_FILTER_UNIT_TAG, unitTag)
	end
end


--------------------------------------------------------------------------------
-- Attribute Bars
-- /ingame/playerattributebars/playerattributebars.lua
--------------------------------------------------------------------------------

local function RefreshAttributeBar( bar )
	local current, _, effectiveMax = GetUnitPower(bar:GetEffectiveUnitTag(), bar.powerType)
	bar:UpdateResourceNumbersLabel(current, effectiveMax)
end

local function HookAttributeBars( )
	local unitTag = "player"

	local hookFunc = function( self, current, maximum )
		if (self.control.resourceNumbersLabel) then
			self.control.resourceNumbersLabel:SetText(FormatValues(current, maximum, self.iabShield, self.iabTrauma))
		end
		return true
	end

	for _, bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
		if (bar:GetEffectiveUnitTag() == unitTag and (bar.powerType == COMBAT_MECHANIC_FLAGS_HEALTH or bar.powerType == COMBAT_MECHANIC_FLAGS_MAGICKA or bar.powerType == COMBAT_MECHANIC_FLAGS_STAMINA)) then
			ZO_PreHook(bar, "UpdateResourceNumbersLabel", hookFunc)

			if (bar.powerType == COMBAT_MECHANIC_FLAGS_HEALTH) then
				bar.iabShield, bar.iabTrauma = GetCurrentShieldAndTrauma(unitTag)
				RegisterShieldAndTraumaUpdate(unitTag, function( eventCode, _, unitAttributeVisual, _, _, _, value, newValue )
					if (unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING or unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA) then
						if (eventCode == EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED) then
							value = 0
						elseif (eventCode == EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED) then
							value = newValue
						end
						if (unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING) then
							bar.iabShield = value
						else
							bar.iabTrauma = value
						end
						RefreshAttributeBar(bar)
					end
				end)
			end

			RefreshAttributeBar(bar)
		end
	end
end


--------------------------------------------------------------------------------
-- Target Frame
-- /esoui/ingame/unitframes/unitframes.lua
-- /esoui/ingame/unitattributevisualizer/modules/powershield.lua
--------------------------------------------------------------------------------

local function GetShieldModule( frame )
	local visualizer = frame.attributeVisualizer
	for module in pairs(visualizer and visualizer.visualModules or { }) do
		if (module.layoutData == VISUALIZER_ANGLE_POWER_SHIELD_LAYOUT_DATA) then
			module.IAB_UpdateGradient = function( self, gradientOverride )
				if (self.layoutData.fakeHealthGradientOverride ~= gradientOverride) then
					self.layoutData.fakeHealthGradientOverride = gradientOverride
					local info = self.attributeInfo and self.attributeInfo[ATTRIBUTE_HEALTH]
					if (info and info.overlayControls) then
						local fakeHealthGradient = gradientOverride or ZO_POWER_BAR_GRADIENT_COLORS[COMBAT_MECHANIC_FLAGS_HEALTH]
						for _, overlay in ipairs(info.overlayControls) do
							ZO_StatusBar_SetGradientColor(overlay.fakeHealthBar, fakeHealthGradient)
						end
					end
				end
			end
			return module
		end
	end
end

local function HookTargetFrame( )
	local unitTag = "reticleover"

	local targetFrame = UNIT_FRAMES:GetFrame(unitTag)

	-- Health Bar --------------------------------------------------------------
	local bar = targetFrame and targetFrame.healthBar
	local numbersLabel = bar and bar.resourceNumbersLabel

	if (numbersLabel) then
		numbersLabel:SetDrawTier(DT_HIGH)
		numbersLabel:SetDrawLayer(DL_OVERLAY)
		numbersLabel:SetDrawLevel(10)

		ZO_PreHook(bar, "UpdateText", function( self )
			numbersLabel:SetText(FormatValues(self.currentValue, self.maxValue, GetCurrentShieldAndTrauma(unitTag)))
			return true
		end)

		RegisterShieldAndTraumaUpdate(unitTag, function( _, _, unitAttributeVisual )
			if (unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING or unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA) then
				bar:UpdateText()
			end
		end)

		bar:UpdateText()

		local GetGradient = function( reactionColorType )
			local r, g, b, a = GetInterfaceColor(INTERFACE_COLOR_TYPE_UNIT_REACTION_COLOR, reactionColorType)
			return { ZO_ColorDef:New(r * 0.6, g * 0.6, b * 0.6, a), ZO_ColorDef:New(r, g, b, a) }
		end

		local reactionOverrides = {
			[UNIT_REACTION_HOSTILE] = GetGradient(UNIT_REACTION_COLOR_HOSTILE),
			[UNIT_REACTION_NEUTRAL] = GetGradient(UNIT_REACTION_COLOR_NEUTRAL),
			[UNIT_REACTION_FRIENDLY] = GetGradient(UNIT_REACTION_COLOR_FRIENDLY),
			[UNIT_REACTION_PLAYER_ALLY] = GetGradient(UNIT_REACTION_COLOR_PLAYER_ALLY),
			[UNIT_REACTION_NPC_ALLY] = GetGradient(UNIT_REACTION_COLOR_NPC_ALLY),
			[UNIT_REACTION_COMPANION] = GetGradient(UNIT_REACTION_COLOR_COMPANION),
		}

		local shieldModule = GetShieldModule(targetFrame)

		SecurePostHook(targetFrame, "UpdateUnitReaction", function( self )
			local override = reactionOverrides[GetUnitReaction(unitTag)]
			if (bar.barType) then
				bar:SetColor(bar.barType, override)
			end
			if (shieldModule) then
				shieldModule:IAB_UpdateGradient(override)
			end
		end)

		targetFrame:UpdateUnitReaction()
	end

	-- Class Icon --------------------------------------------------------------
	local rankIcon = targetFrame and targetFrame.rankIcon

	if (rankIcon) then
		classIcon = WINDOW_MANAGER:CreateControl(nil, targetFrame.frame, CT_TEXTURE)
		classIcon:SetAnchor(LEFT, rankIcon, RIGHT)

		SecurePostHook(targetFrame, "UpdateRank", function( self )
			local classId = GetUnitClassId(unitTag)
			if (classId > 0) then
				local gp = IsInGamepadPreferredMode()
				local width, height = rankIcon:GetDimensions()
				local scale = gp and 0.75 or 0.85
				local iconKB, iconGP = select(7, GetClassInfo(GetClassIndexById(classId)))
				classIcon:SetDimensions(width * scale, height * scale)
				classIcon:SetTexture(gp and iconGP or iconKB)
				classIcon:SetHidden(false)
			else
				classIcon:SetHidden(true)
			end
		end)
	end
end


--------------------------------------------------------------------------------
-- Boss Bar
-- /esoui/ingame/unitframes/bossbar.lua
--------------------------------------------------------------------------------

local function HookBossBar( )
	SecurePostHook(BOSS_BAR, "RefreshBossHealthBar", function( self )
		local totalHealth = 0
		local totalMaxHealth = 0
		for _, bossEntry in pairs(self.bossHealthValues) do
			totalHealth = totalHealth + bossEntry.health
			totalMaxHealth = totalMaxHealth + bossEntry.maxHealth
		end
		self.healthText:SetText(FormatValues(totalHealth, totalMaxHealth, nil, nil, true))
	end)
	BOSS_BAR:RefreshBossHealthBar()
end


--------------------------------------------------------------------------------
-- Bootstrap
--------------------------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function( )
	HookAttributeBars()
	HookTargetFrame()
	HookBossBar()
end, true)
