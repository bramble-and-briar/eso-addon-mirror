-- Update 51 / console compatibility: PowerType was migrated to CombatMechanicFlags.
-- Do not build tables with the legacy POWERTYPE_* globals at file-load time on console.
local POWER_MAGICKA = COMBAT_MECHANIC_FLAGS_MAGICKA or _G["POWERTYPE_MAGICKA"] or 1
local POWER_STAMINA = COMBAT_MECHANIC_FLAGS_STAMINA or _G["POWERTYPE_STAMINA"] or 4
local POWER_HEALTH  = COMBAT_MECHANIC_FLAGS_HEALTH  or _G["POWERTYPE_HEALTH"]  or 32

local addonDefaults = {
	unlocked = true,
	controlOffsetX = 0,
	controlOffsetY = 0,
	controlScale = 1,
	alwaysShown = false,
	powerType = POWER_STAMINA,
	controlWidth = 100,
	attachToDefaultBar = false,
	showFatigue = true,
	playSound = true,
	defaultTickAmountAbove = true,
	zeroRegenColor = {1, 0, 0, 1}, 
}

local colorTypes = {
	-- [POWER_STAMINA] = {0, 0.8, 0, 1},
	-- [POWER_STAMINA] = {0, 0.6, 0.4, 1},
	[POWER_STAMINA] = {0, 0.8, 0.52, 1},
	-- [POWER_MAGICKA] = {0.66, 0.66, 1, 1},
	[POWER_MAGICKA] = {0.32, 0.84, 1, 1},
	-- [POWER_HEALTH] = {1, 0.26, 0.26, 1},
	[POWER_HEALTH] = {0.85, 0.18, 0.18, 1},
}

local MiatsTickTracker = {}

local translateOffsetY = 1

function MiatsTickTracker:Initialize(control)
	self.updateName = 'MiatsTickTracker'
	self.version = '1.13-console.2'
	self.SV = ZO_SavedVars:NewAccountWide("MiatTickTrackerSettings", 1.00, "Settings", addonDefaults)
	
    self.control = control
	self.defaultStamBar = ZO_PlayerAttributeStamina
	self.defaultMagBar = ZO_PlayerAttributeMagicka
	self.defaultHpBar = ZO_PlayerAttributeHealth
	if self.SV.powerType == POWER_STAMINA then
		self.defaultBar = self.defaultStamBar
	elseif self.SV.powerType == POWER_MAGICKA then
		self.defaultBar = self.defaultMagBar
	elseif self.SV.powerType == POWER_HEALTH then
		self.defaultBar = self.defaultHpBar
	end
	self.defaultTick = MiatsDefaultTick
	-- self.arrow = self.defaultTick:GetNamedChild('Edge')
	self.arrow = MiatEdgeContainer
	self.arrowTexture1 = self.arrow:GetNamedChild('MiatEdge1')
	-- self.arrowTexture2 = self.arrow:GetNamedChild('MiatEdge2')
	-- self.arrowTexture3 = self.arrow:GetNamedChild('MiatEdge3')
	-- self.arrowTexture2:SetHidden(true)
	-- self.arrowTexture3:SetHidden(true)
	self.defaultTickLabel = MiatAmount
    self.container = control:GetNamedChild('Container')
    self.amountLabel = self.container:GetNamedChild('Amount')
    self.percentageLabel = self.container:GetNamedChild('Percentage')
    self.bar = self.container:GetNamedChild('Bar')
	self.fatigueCount = 0
	
	self:ManageUnlocked()
	self:InitializeGamepadMover()
	self:CreateAddonMenu()
end

function MiatsTickTracker:SetupEvents()
	EVENT_MANAGER:RegisterForUpdate('MiatsTickTracker', 10, function() self:OnTickUpdate(false) end)
	self.control:RegisterForEvent(EVENT_POWER_UPDATE, function(_, ...) self:OnPowerUpdate(...) end)
	self.control:RegisterForEvent(EVENT_COMBAT_EVENT, function(_, ...) self:OnCombatEvent(...) end)
	self.control:RegisterForEvent(EVENT_WEAPON_PAIR_LOCK_CHANGED, function(_, ...) self:OnWeaponPairLockChanged(...) end)
end

function MiatsTickTracker:UnregisterEvents()
	EVENT_MANAGER:UnregisterForUpdate('MiatsTickTracker')
	self.control:UnregisterForEvent(EVENT_POWER_UPDATE)
	self.control:UnregisterForEvent(EVENT_COMBAT_EVENT)
	self.control:UnregisterForEvent(EVENT_WEAPON_PAIR_LOCK_CHANGED)
end

function MiatsTickTracker:GetTranslateDistance()
	local distance = self.defaultBar:GetWidth() - self.arrow:GetWidth() - self.arrow.anchorOffsetX
	if self.SV.powerType == POWER_MAGICKA then
		distance = -distance
	end
	return distance
end

function MiatsTickTracker:SetupControls()
	self.control:SetScale(self.SV.controlScale)
	self.container:SetWidth(self.SV.controlWidth/self.SV.controlScale)
	self.control:ClearAnchors()
	self.control:SetAnchor(CENTER, GuiRoot, CENTER, self.SV.controlOffsetX, self.SV.controlOffsetY)
	self.bar:SetDimensions((self.container:GetWidth()/self.SV.controlScale-4), (self.container:GetHeight()/self.SV.controlScale-2))
	local side
	local anchorOffsetX
	if self.SV.powerType == POWER_STAMINA then
		self.defaultBar = self.defaultStamBar
		self.arrowTexture1:SetTextureCoords(1, 0, 0, 1)
		-- self.arrowTexture2:SetTextureCoords(1, 0, 0, 1)
		-- self.arrowTexture3:SetTextureCoords(1, 0, 0, 1)
		side = LEFT
		anchorOffsetX = 0
	elseif self.SV.powerType == POWER_MAGICKA then
		self.defaultBar = self.defaultMagBar
		self.arrowTexture1:SetTextureCoords(0, 1, 0, 1)
		-- self.arrowTexture2:SetTextureCoords(0, 1, 0, 1)
		-- self.arrowTexture3:SetTextureCoords(0, 1, 0, 1)
		side = RIGHT
		anchorOffsetX = 5
	elseif self.SV.powerType == POWER_HEALTH then
		self.defaultBar = self.defaultHpBar
		self.arrowTexture1:SetTextureCoords(0, 1, 0, 1)
		-- self.arrowTexture2:SetTextureCoords(0, 1, 0, 1)
		-- self.arrowTexture3:SetTextureCoords(0, 1, 0, 1)
		side = LEFT
		anchorOffsetX = 0
	end

	self.defaultTickLabel:ClearAnchors()
	self.defaultTickLabel:SetParent(self.defaultBar)
	self.defaultTickLabel:SetAnchor(self.SV.defaultTickAmountAbove and BOTTOM or TOP, self.defaultBar, self.SV.defaultTickAmountAbove and TOP or BOTTOM, 0, self.SV.defaultTickAmountAbove and -25 or 5)
	self.defaultTickLabel:SetHidden(true)

	self.amountLabel:ClearAnchors()
	self.amountLabel:SetAnchor(self.SV.defaultTickAmountAbove and BOTTOM or TOP, self.container, self.SV.defaultTickAmountAbove and TOP or BOTTOM, -2, self.SV.defaultTickAmountAbove and -20 or 5)
	self.amountLabel:SetHidden(not self.SV.unlocked)
	
	if self.arrow.animDataTick and self.arrow.animDataTick:IsPlaying() then self.arrow.animDataTick:Stop() end
	local w,h = self.defaultBar:GetDimensions()
	-- self.arrow:SetHeight(0.8*h)
	self.arrow:SetParent(self.defaultBar)
	self.arrow:ClearAnchors()
	self.arrow:SetAnchor(side, self.defaultBar, side, anchorOffsetX, translateOffsetY)
	self.arrow.offsetX = w - self.arrow:GetWidth() - anchorOffsetX
	self.arrow.anchorOffsetX = anchorOffsetX
	if side == RIGHT then self.arrow.offsetX = - self.arrow.offsetX end
	self.arrow:SetHidden(true)
	
	ZO_StatusBar_SetGradientColor(self.defaultBar:GetNamedChild('Bar'), ZO_POWER_BAR_GRADIENT_COLORS[self.SV.powerType])

	if self.SV.showFatigue then
		self.control:UnregisterForEvent(EVENT_COMBAT_EVENT)
		self.control:RegisterForEvent(EVENT_COMBAT_EVENT, function(_, ...) self:OnCombatEvent(...) end)
	else
		self.control:UnregisterForEvent(EVENT_COMBAT_EVENT)
	end
end

function MiatsTickTracker:ManageUnlocked()
	if self.SV.unlocked then
		if GAME_MENU_SCENE then GAME_MENU_SCENE:AddFragment(TICK_TRACKER_FRAGMENT) end
		self:UnregisterEvents()
		if self.control.animDataTick and self.control.animDataTick:IsPlaying() then self.control.animDataTick:Stop() end
		if self.defaultBar.animDataTick and self.defaultBar.animDataTick:IsPlaying() then self.defaultBar.animDataTick:Stop() end
		self.control:SetMovable(true)
		self.control:SetHidden(false)
		self.percentageLabel:SetText('Unlocked!')
		self.amountLabel:SetText('+tick')
		self.amountLabel:SetHidden(false)
		self.amountLabel:SetColor(1,1,1,1)
		self.bar:SetCenterColor(0,0,0,1)
	else
		if GAME_MENU_SCENE then GAME_MENU_SCENE:RemoveFragment(TICK_TRACKER_FRAGMENT) end
		self:SetupEvents()
		self.control:SetMovable(false)
		self.control:SetHidden(not self.SV.alwaysShown)
		local barText = {
			[POWER_STAMINA] = 'Stamina',
			[POWER_MAGICKA] = 'Magicka',
			[POWER_HEALTH] = 'Health',
		}
		self.percentageLabel:SetText(barText[self.SV.powerType])
		self.bar:SetCenterColor(0,0,0,1)
		self.amountLabel:SetHidden(true)
	end
	self:SetupControls()
end

function MiatsTickTracker:CreateAddonMenu()
	if self.menuCreated then return end
	local lam = LibAddonMenu2
	if not lam then return end
	self.menuCreated = true
	local panelData = {
		type = "panel",
		name = "Recovery Tick Tracker",
		displayName = "Recovery Tick Tracker",
		author = "MIAT, j.hhh",
		version = self.version,
		registerForRefresh = true,
		registerForDefaults = false,
	}
	
	local optionsPanel = lam:RegisterAddonPanel("MiatsTickTrackerPanel", panelData)
		
	local optionsData = {}
	
	
	table.insert(optionsData, {
		type = "header",
		name = "Tick Tracker Options",
	})
	table.insert(optionsData, {
		type = "checkbox",
		name = "Turn OFF when satisfied with tracker position",
		tooltip = "ON - icon can me moved on the screen by left clicking and dragging, OFF - icon is locked in place and can not be moved",
		default = addonDefaults.unlocked,
		-- disabled = function() return not self.SV.enabled end,
		getFunc = function() return self.SV.unlocked end,
		setFunc = function(newValue) self:SetMoveMode(newValue) end,
	})
	table.insert(optionsData, {
		type = "checkbox",
		name = "Apply the tracker to default bars",
		tooltip = "ON - the tracker is shown on the default resource bars instead of the separate frame, OFF - the tracker is shown only in its own frame",
		default = addonDefaults.attachToDefaultBar,
		-- disabled = function() return not self.SV.enabled end,
		getFunc = function() return self.SV.attachToDefaultBar end,
		setFunc = function(newValue) self.SV.attachToDefaultBar = newValue self:SetupControls() end,
	})
	table.insert(optionsData, {
		type = "dropdown",
		name = "Choose resource type to track:",
		tooltip = 'Default is "Stamina"',
		choices = {"Stamina", "Magicka", "Health"},
		getFunc = function() 
			if self.SV.powerType == POWER_STAMINA then 
				return "Stamina"
			elseif self.SV.powerType == POWER_MAGICKA then
				return "Magicka"				
			elseif self.SV.powerType == POWER_HEALTH then
				return "Health"
			end
		end,
		setFunc = function(newValue)
			if newValue == "Stamina" then 
				self.SV.powerType = POWER_STAMINA
			elseif newValue=="Magicka" then
				self.SV.powerType = POWER_MAGICKA
			elseif newValue=="Health" then
				self.SV.powerType = POWER_HEALTH
			end
			self:SetupControls()
		end,
		default = "Stamina",
		-- disabled = function() return not self.SV.enabled or not self.SV.showTargetNameFrame end,
	})	
	table.insert(optionsData, {
		type = "slider",
		name = "Set tracker Scale (%)",
		tooltip = "Tracker Scale goes from 50% to 200% of original scale",
		default = tonumber(string.format("%.0f", 100*addonDefaults.controlScale)),
		disabled = function() return self.SV.attachToDefaultBar and not self.SV.unlocked end,
		min     = 50,
        max     = 200,
        step    = 1,
		getFunc = function() return tonumber(string.format("%.0f", 100*self.SV.controlScale)) end,
		setFunc = function(newValue) self.SV.controlScale = newValue/100 self:SetupControls() end,
	})
	table.insert(optionsData, {
		type = "slider",
		name = "Set tracker bar width (%)",
		tooltip = "Tracker bar width goes from 50% to 400% of original width",
		default = tonumber(string.format("%.0f", addonDefaults.controlWidth)),
		disabled = function() return self.SV.attachToDefaultBar and not self.SV.unlocked end,
		min     = 50,
        max     = 400,
        step    = 1,
		getFunc = function() return tonumber(string.format("%.0f", self.SV.controlWidth)) end,
		setFunc = function(newValue) self.SV.controlWidth = newValue self:SetupControls() end,
	})
	table.insert(optionsData, {
		type = "colorpicker",
		name = "Pick color for zero regen",
		tooltip = "Pick color for zero regen (default - bright red)",
        default = ZO_ColorDef:New(unpack(addonDefaults.zeroRegenColor)),
        getFunc = function() return unpack(self.SV.zeroRegenColor) end,
		setFunc = function(r,g,b,a)
            self.SV.zeroRegenColor = {r,g,b,a}
        end,
	})	
	table.insert(optionsData, {
		type = "checkbox",
		name = "Play sound on resource ticks",
		tooltip = "ON - play the sound, OFF - don't play the sound",
		default = addonDefaults.playSound,
		-- disabled = function() return not self.SV.enabled end,
		getFunc = function() return self.SV.playSound end,
		setFunc = function(newValue) self.SV.playSound = newValue self:SetupControls() end,
	})		
	table.insert(optionsData, {
		type = "checkbox",
		name = "Show the tracker at all times",
		tooltip = "ON - the tracker will never disappear, OFF - the tracker will be hidden if stam is full",
		default = addonDefaults.alwaysShown,
		-- disabled = function() return self.SV.attachToDefaultBar and not self.SV.unlocked end,
		getFunc = function() return self.SV.alwaysShown end,
		setFunc = function(newValue) self.SV.alwaysShown = newValue self:SetupControls() end,
	})
	table.insert(optionsData, {
		type = "checkbox",
		name = "Show dodge fatigue on tracker bars",
		tooltip = "ON - the bars color will change proportional to the current dodge fatigue, OFF - the bars won't show dodge fatigue",
		default = addonDefaults.showFatigue,
		-- disabled = function() return not self.SV.enabled end,
		getFunc = function() return self.SV.showFatigue end,
		setFunc = function(newValue) self.SV.showFatigue = newValue self:SetupControls() end,
	})			
	table.insert(optionsData, {
		type = "checkbox",
		name = "Show the tick amount above the bars",
		tooltip = "ON - the tick amount will be shown ABOVE the bars, OFF - the tick amount will be shown BELOW the bars",
		default = addonDefaults.defaultTickAmountAbove,
		-- disabled = function() return self.SV.attachToDefaultBar and not self.SV.unlocked end,
		getFunc = function() return self.SV.defaultTickAmountAbove end,
		setFunc = function(newValue) self.SV.defaultTickAmountAbove = newValue self:SetupControls() end,
	})		
	
	lam:RegisterOptionControls("MiatsTickTrackerPanel", optionsData)	
end

function MiatsTickTracker:MoveBy(dx, dy)
	if not self.SV.unlocked then return end
	self.SV.controlOffsetX = self.SV.controlOffsetX + dx
	self.SV.controlOffsetY = self.SV.controlOffsetY + dy
	self.control:ClearAnchors()
	self.control:SetAnchor(CENTER, GuiRoot, CENTER, self.SV.controlOffsetX, self.SV.controlOffsetY)
end

function MiatsTickTracker:SetMoveMode(enabled)
	self.SV.unlocked = enabled
	self:ManageUnlocked()
	if self.gamepadKeybinds then
		if enabled and not self.gamepadKeybindsActive then
			KEYBIND_STRIP:AddKeybindButtonGroup(self.gamepadKeybinds)
			self.gamepadKeybindsActive = true
		elseif not enabled and self.gamepadKeybindsActive then
			KEYBIND_STRIP:RemoveKeybindButtonGroup(self.gamepadKeybinds)
			self.gamepadKeybindsActive = false
		end
	end
end

function MiatsTickTracker:ToggleMoveMode()
	self:SetMoveMode(not self.SV.unlocked)
end

function MiatsTickTracker:InitializeGamepadMover()
	self.gamepadKeybinds = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		{ name = "Move up", keybind = "UI_SHORTCUT_INPUT_UP", callback = function() self:MoveBy(0, -5) end },
		{ name = "Move down", keybind = "UI_SHORTCUT_INPUT_DOWN", callback = function() self:MoveBy(0, 5) end },
		{ name = "Move left", keybind = "UI_SHORTCUT_INPUT_LEFT", callback = function() self:MoveBy(-5, 0) end },
		{ name = "Move right", keybind = "UI_SHORTCUT_INPUT_RIGHT", callback = function() self:MoveBy(5, 0) end },
		{ name = "Save position", keybind = "UI_SHORTCUT_PRIMARY", callback = function() self:SetMoveMode(false) end },
	}
	if self.SV.unlocked then
		KEYBIND_STRIP:AddKeybindButtonGroup(self.gamepadKeybinds)
		self.gamepadKeybindsActive = true
	end
end

function MIAT_TICK_TRACKER_TOGGLE_MOVE_MODE()
	MiatsTickTracker:ToggleMoveMode()
end

function MiatsTickTracker:SavePosition(control)
	local coordX, coordY = control:GetCenter()
	self.SV.controlOffsetX = coordX-(GuiRoot:GetWidth()/2)
	self.SV.controlOffsetY = coordY-(GuiRoot:GetHeight()/2)
	control:ClearAnchors()
	control:SetAnchor(CENTER, GuiRoot, CENTER, self.SV.controlOffsetX, self.SV.controlOffsetY)
end

function MiatsTickTracker:OnMouseWheel(control, delta)
	if not self.SV.unlocked then return end
	
	local scale = self.SV.controlScale + delta*0.01
	if scale < 0.5 or scale > 2 then return end
	
	control:SetScale(scale)
	self.SV.controlScale = scale
end

function Miats_TickTracker_SavePosition(...)
	MiatsTickTracker:SavePosition(...)
end

function Miats_TickTracker_OnMouseWheel(...)
	MiatsTickTracker:OnMouseWheel(...)
end

function MiatsTickTracker:OnTickUpdate(fromPower)
	local currentTime = GetFrameTimeMilliseconds()
	
	local function ProcessBar(difference)
		local currentPower, maxPower = self:GetCurrentPower()
		local powerRegen = self:GetPowerRegen()
		local percentage = 100 * difference / 2000
		local control = self.container
		local bar = self.bar
		local label = self.percentageLabel
		local defaultBar = self.defaultBar:GetNamedChild('Bar')
		local stamBar = self.defaultStamBar:GetNamedChild('Bar')
		if not self.SV.attachToDefaultBar then
			bar:SetDimensions((control:GetWidth()/self.SV.controlScale-4)*percentage/100, (control:GetHeight()/self.SV.controlScale-2))
			label:SetText(tostring(math.floor(percentage))..'%')
		end
		
		-- self.arrowTexture1:SetColor(math.max(percentage/100, 0.75), math.max(percentage/100, 0.75), math.max(percentage/100, 0.75), 1)
		
		if powerRegen == 0 then
			if self.SV.attachToDefaultBar then
				defaultBar:SetColor(unpack(self.SV.zeroRegenColor))
			else
				bar:SetCenterColor(unpack(self.SV.zeroRegenColor))
			end
		elseif self.SV.showFatigue and (self.SV.powerType == POWER_STAMINA or self.SV.attachToDefaultBar) and self.fatigueCount > 0 then

			local fatigueColorsDefault = {
				[1] = {0.2, 0.68, 0.32, 1},
				[2] = {0.4, 0.76, 0.24, 1},
				[3] = {0.6, 0.84, 0.16, 1},
				[4] = {0.8, 0.92, 0.08, 1},
				[5] = {1, 1, 0, 1},
				[6] = {1, 0.8, 0.0, 1},
				[7] = {1, 0.6, 0.0, 1},
				[8] = {1, 0.4, 0.0, 1},
				[9] = {1, 0.2, 0.0, 1},
				[10] = {1, 0.0, 0.0, 1},
				[11] = {1, 0.0, 0.0, 1},
				[12] = {1, 0.0, 0.0, 1},
				[13] = {1, 0.0, 0.0, 1},
				[14] = {1, 0.0, 0.0, 1},
				[15] = {1, 0.0, 0.0, 1},
				[16] = {1, 0.0, 0.0, 1},
			}
			local fatigueColors = {
				[1] = {0.2, 0.84, 0.41, 1},
				[2] = {0.4, 0.88, 0.31, 1},
				[3] = {0.6, 0.92, 0.2, 1},
				[4] = {0.8, 0.96, 0.1, 1},
				[5] = {1, 1, 0.0, 1},
				[6] = {1, 0.8, 0.0, 1},
				[7] = {1, 0.6, 0.0, 1},
				[8] = {1, 0.4, 0.0, 1},
				[9] = {1, 0.2, 0.0, 1},
				[10] = {1, 0.0, 0.0, 1},
				[11] = {1, 0.0, 0.0, 1},
				[12] = {1, 0.0, 0.0, 1},
				[13] = {1, 0.0, 0.0, 1},
				[14] = {1, 0.0, 0.0, 1},
				[15] = {1, 0.0, 0.0, 1},
				[16] = {1, 0.0, 0.0, 1},
			}
			if self.SV.attachToDefaultBar then
				stamBar:SetColor(unpack(fatigueColorsDefault[self.fatigueCount]))
			else
				bar:SetCenterColor(unpack(fatigueColors[self.fatigueCount]))
			end
		else
			if self.SV.attachToDefaultBar then
				ZO_StatusBar_SetGradientColor(defaultBar, ZO_POWER_BAR_GRADIENT_COLORS[self.SV.powerType])
				if (self.SV.showFatigue and self.fatigueCount == 0) then
					ZO_StatusBar_SetGradientColor(stamBar, ZO_POWER_BAR_GRADIENT_COLORS[POWER_STAMINA])
				end	
			else
				bar:SetCenterColor(unpack(colorTypes[self.SV.powerType]))
			end
		end

		local isValidScene = SCENE_MANAGER:GetCurrentScene() == HUD_SCENE or SCENE_MANAGER:GetCurrentScene() == HUD_UI_SCENE or SCENE_MANAGER:GetCurrentScene() == LOOT_SCENE or (self.SV.unlocked and SCENE_MANAGER:GetCurrentScene() == GAME_MENU_SCENE)
		local shownForAnimation = self.control.animDataTick and self.control.animDataTick:IsPlaying()
		local hidingCondition = maxPower == currentPower
		local shouldHideControl = self.SV.attachToDefaultBar or not isValidScene or (not self.SV.alwaysShown and not shownForAnimation and hidingCondition)
		
		self.control:SetHidden(shouldHideControl)
		if self.SV.attachToDefaultBar and not self.SV.alwaysShown and hidingCondition then
			self.arrow:SetHidden(true)
		end
	end

	if self.trustedTickTime then
		local difference = currentTime - self.trustedTickTime
		ProcessBar(difference)
		if difference >= 2010 then
			self.trustedTickTime = currentTime
			self.wasTickTimeTrusted = false
			if self.SV.attachToDefaultBar then
				self.arrow.animDataTick = self:StartAnimation(self.arrow, 'arrow')
			end
		end
	end
end

function MiatsTickTracker:GetCurrentPower()
	return GetUnitPower('player', self.SV.powerType)
end

function MiatsTickTracker:OnCombatEvent(result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, combat_log, sourceUnitId, targetUnitId, abilityId)
	if targetType == 1 and abilityId == 69143 then
		if result == 2245 then
			self.fatigueCount = self.fatigueCount + 1
		elseif result == 2250 then
			self.fatigueCount = 0
		end
	end
end

function MiatsTickTracker:OnWeaponPairLockChanged(locked)
	self.weaponPairLocked = locked
end

function MiatsTickTracker:OnPowerUpdate(unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)

	local function ApplyTick(powerDelta)
		self.control.animDataTick = self:StartAnimation(self.control, 'tick')
		if self.SV.attachToDefaultBar then
			self.defaultBar.animDataTick = self:StartAnimation(self.defaultBar, 'tick')
			self.arrow.animDataTick = self:StartAnimation(self.arrow, 'arrow')
		end
		if self.SV.playSound then
			PlaySound(SOUNDS.COUNTDOWN_TICK)
			PlaySound(SOUNDS.COUNTDOWN_TICK)
		end
		self.amountLabel:SetText("+"..tostring(powerDelta))
		self.amountLabel:SetColor(unpack(colorTypes[self.SV.powerType]))
		self.amountLabel:SetHidden(false)
		if self.SV.attachToDefaultBar then
			self.defaultTickLabel:SetText("+"..tostring(powerDelta))
			self.defaultTickLabel:SetColor(unpack(colorTypes[self.SV.powerType]))
			self.defaultTickLabel:SetHidden(false)
		end
		zo_callLater(function() 
			self.amountLabel:SetHidden(true) 
			self.defaultTickLabel:SetHidden(true) 
		end, 1500)
	end
	-- d(self.weaponPairLocked)
	if unitTag == 'player' and powerType == self.SV.powerType then
		local currentTime = GetFrameTimeMilliseconds()
		local currentPower = self:GetCurrentPower()
		if self.previousPower then
			local powerDelta = powerValue - self.previousPower
			if powerDelta > 0 and powerDelta == self:GetPowerRegen() then
				-- if self.weaponPairLocked and not self.ignoreFirstLockedTick and self.trustedTickTime and (currentTime - self.trustedTickTime) < 1950 then
					-- self.ignoreFirstLockedTick = true
					-- self.previousPower = currentPower
					-- return
				-- end
				-- self.ignoreFirstLockedTick = nil
				local validSecondDeltaTick
				if self.trustedTickTime then
					local timeDelta = currentTime - self.trustedTickTime
					if self.partialTimeDelta then
						local savedTimeDelta
						savedTimeDelta = currentTime - self.partialTimeDelta.currentTime
						local deltaSum = self.partialTimeDelta.timeDelta + savedTimeDelta
						validSecondDeltaTick = (deltaSum > 1900) and (deltaSum < 2100)
						self.partialTimeDelta = nil
					end
					
					if self.wasTickTimeTrusted and timeDelta < 1750 and not validSecondDeltaTick then 
						self.previousPower = currentPower 
						if validSecondDeltaTick == nil then
							self.partialTimeDelta = {timeDelta = timeDelta, currentTime = currentTime}
						end
						return 
					end
				end
				
				-- if validSecondDeltaTick then d('valid second tick!') end
				
				-- if self.weaponPairLocked and self.trustedTickTime and ((currentTime - self.trustedTickTime) < 1800) then return end
				self.trustedTickTime = currentTime
				self.wasTickTimeTrusted = true
				if not ((self.SV.attachToDefaultBar and self.defaultBar.animDataTick and self.defaultBar.animDataTick:IsPlaying()) or (not self.SV.attachToDefaultBar and self.control.animDataTick and self.control.animDataTick:IsPlaying())) then
					ApplyTick(powerDelta)
					self:OnTickUpdate(true)
				end
			end
		end
		self.previousPower = currentPower
	end
end

function MiatsTickTracker:ProcessPower()
	local function ApplyTick(powerDelta)
		self.control.animDataTick = self:StartAnimation(self.control, 'tick')
		if self.SV.attachToDefaultBar then
			self.defaultBar.animDataTick = self:StartAnimation(self.defaultBar, 'tick')
			self.arrow.animDataTick = self:StartAnimation(self.arrow, 'arrow')
		end
		if self.SV.playSound then
			PlaySound(SOUNDS.COUNTDOWN_TICK)
			PlaySound(SOUNDS.COUNTDOWN_TICK)
		end
		self.amountLabel:SetText("+"..tostring(powerDelta))
		self.amountLabel:SetColor(unpack(colorTypes[self.SV.powerType]))
		self.amountLabel:SetHidden(false)
		if self.SV.attachToDefaultBar then
			self.defaultTickLabel:SetText("+"..tostring(powerDelta))
			self.defaultTickLabel:SetColor(unpack(colorTypes[self.SV.powerType]))
			self.defaultTickLabel:SetHidden(false)
		end
		zo_callLater(function() 
			self.amountLabel:SetHidden(true) 
			self.defaultTickLabel:SetHidden(true) 
		end, 1500)
	end
	
	if not self.weaponPairLocked then
	
		local currentPower = self:GetCurrentPower()
		-- local wasTakeback
		if self.previousPower then
			local currentTime = GetFrameTimeMilliseconds()
			local powerDelta = currentPower - self.previousPower
			
			if powerDelta<0 and self:GetPowerRegen() == -powerDelta then
				d('takeback power: '..tostring(powerDelta))
				-- wasTakeback = true
			end
			
			if powerDelta > 0 and powerDelta == self:GetPowerRegen() then
				-- if self.trustedTickTime and self.wasTickTimeTrusted and ((currentTime - self.trustedTickTime) < 100) then self.previousPower = currentPower return end
				
				-- d('*****************')
				-- d(powerDelta)
				-- d(self.previousPower)
				-- d(currentPower)
				-- if self.trustedTickTime then
					-- d(currentTime - self.trustedTickTime)
				-- end
				-- d('*****************')
				
				
				self.trustedTickTime = currentTime
				self.wasTickTimeTrusted = true
				ApplyTick(powerDelta)

				
			end
		end
		-- if not wasTakeback then
			self.previousPower = currentPower
		-- end
	end
end

function MiatsTickTracker:GetPowerRegen()
	local statTypeCombat, statTypeIdle
	
	if self.SV.powerType == POWER_STAMINA then
		statTypeCombat = STAT_STAMINA_REGEN_COMBAT
		statTypeIdle = STAT_STAMINA_REGEN_IDLE
	elseif self.SV.powerType == POWER_MAGICKA then
		statTypeCombat = STAT_MAGICKA_REGEN_COMBAT
		statTypeIdle = STAT_MAGICKA_REGEN_IDLE	
	elseif self.SV.powerType == POWER_HEALTH then
		statTypeCombat = STAT_HEALTH_REGEN_COMBAT
		statTypeIdle = STAT_HEALTH_REGEN_IDLE	
	end
	
	if IsUnitInCombat('player') then
		return GetPlayerStat(statTypeCombat, STAT_BONUS_OPTION_APPLY_BONUS)
	else
		return GetPlayerStat(statTypeIdle, STAT_BONUS_OPTION_APPLY_BONUS)
	end
end

function MiatsTickTracker:InsertAnimationType(animHandler, animType, control, animDuration, animDelay, animEasing, ...)
	if not animHandler then return end
	if animType==ANIMATION_SCALE then
		local animationScale, startScale, endScale = animHandler:InsertAnimation(ANIMATION_SCALE, control, animDelay), ...
		animationScale:SetScaleValues(startScale, endScale)
		animationScale:SetDuration(animDuration)
		animationScale:SetEasingFunction(animEasing)  
	elseif animType==ANIMATION_ALPHA then
		local animationAlpha, startAlpha, endAlpha = animHandler:InsertAnimation(ANIMATION_ALPHA, control, animDelay), ...
		animationAlpha:SetAlphaValues(startAlpha, endAlpha)
		animationAlpha:SetDuration(animDuration)
		animationAlpha:SetEasingFunction(animEasing) 	
	elseif animType==ANIMATION_TRANSLATE then
		local animationTranslate, startX, startY, offsetX, offsetY = animHandler:InsertAnimation(ANIMATION_TRANSLATE, control, animDelay), ...
   		animationTranslate:SetTranslateOffsets(startX, startY, offsetX, offsetY)
		animationTranslate:SetDuration(animDuration)
		animationTranslate:SetEasingFunction(animEasing)
	elseif animType==ANIMATION_ROTATE3D then
		local animationRotate3D, startPitchRadians, startYawRadians, startRollRadians, endPitchRadians, endYawRadians, endRollRadians = animHandler:InsertAnimation(ANIMATION_ROTATE3D, control, animDelay), ...
		animationRotate3D:SetRotationValues(startPitchRadians, startYawRadians, startRollRadians, endPitchRadians, endYawRadians, endRollRadians)
		animationRotate3D:SetDuration(animDuration)
		animationRotate3D:SetEasingFunction(animEasing)
	elseif animType==ANIMATION_COLOR then
		local animationColor, startPitchRadians, startYawRadians, startRollRadians, endPitchRadians, endYawRadians, endRollRadians = animHandler:InsertAnimation(ANIMATION_COLOR, control, animDelay), ...
		animationRotate3D:SetRotationValues(startPitchRadians, startYawRadians, startRollRadians, endPitchRadians, endYawRadians, endRollRadians)
		animationRotate3D:SetDuration(animDuration)
		animationRotate3D:SetEasingFunction(animEasing)
	end
end



function MiatsTickTracker:StartAnimation(control, animationType, targetParameter)
	if self.control.animDataTick then self.control.animDataTick:Stop() end
	
	local _, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor()

	control:ClearAnchors()
	control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
	local scale
	if animationType == 'tick' then
		scale = control:GetScale()
		control:SetScale(scale)
	end
	if animationType == 'arrow' then
		local currentPower, maxPower = self:GetCurrentPower()
		control:SetHidden(not self.SV.attachToDefaultBar or (not self.SV.alwaysShown and (currentPower == maxPower)))

		-- if self.SV.powerType == POWER_STAMINA then
			-- self.arrowTexture1:SetTextureCoords(1, 0, 0, 1)
			-- self.arrowTexture2:SetTextureCoords(1, 0, 0, 1)
			-- self.arrowTexture3:SetTextureCoords(1, 0, 0, 1)
		-- else
		if self.SV.powerType == POWER_HEALTH then
			self.arrowTexture1:SetTextureCoords(0, 1, 0, 1)
		end
			-- self.arrowTexture2:SetTextureCoords(0, 1, 0, 1)
			-- self.arrowTexture3:SetTextureCoords(0, 1, 0, 1)
		-- end
	end
	
    local timeline = ANIMATION_MANAGER:CreateTimeline()
		
	if animationType == 'tick' then
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 100,   0, 						ZO_EaseOutQuadratic,   	scale, 				1.4*scale)
		self:InsertAnimationType(timeline, ANIMATION_SCALE, control, 100, 	150, 					ZO_EaseInQuadratic, 	1.4*scale,   			scale)
	elseif animationType == 'arrow' then
		-- self:InsertAnimationType(timeline, ANIMATION_TRANSLATE, control, 2010,   0, ZO_LinearEase,  0, 2, control.offsetX, 2)
		self:InsertAnimationType(timeline, ANIMATION_TRANSLATE, control, 2010,   0, ZO_LinearEase,  0, translateOffsetY, self:GetTranslateDistance(), translateOffsetY)
	end

	if animationType == 'arrow' and self.SV.powerType == POWER_HEALTH then
		timeline:InsertCallback(function()
			self.arrowTexture1:SetTextureCoords(1, 0, 0, 1)
			-- d('flip')
			-- self.arrowTexture2:SetTextureCoords(1, 0, 0, 1)
			-- self.arrowTexture3:SetTextureCoords(1, 0, 0, 1)
		end, 0.5*timeline:GetDuration())
	end

    timeline:SetHandler('OnStop', function()
		control:ClearAnchors()
		control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
		if animationType == 'tick' then
			control:SetScale(scale)
		end
		-- if animationType == 'arrow' then
			-- control:SetHidden(true)
		-- end
	end)
	
    timeline:PlayFromStart()
	return timeline
end



EVENT_MANAGER:RegisterForEvent('MiatsTickTracker', EVENT_ADD_ON_LOADED, function(_, addonName) 
	if addonName == 'MiatsTickTracker' then
		EVENT_MANAGER:UnregisterForEvent('MiatsTickTracker', EVENT_ADD_ON_LOADED)
		TICK_TRACKER_FRAGMENT = ZO_FadeSceneFragment:New(MiatsTickTrackerFrame, nil, 0)
		-- MiatsTickTracker:Initialize(MiatsTickTrackerFrame)
		-- HUD_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
		-- HUD_UI_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
		-- LOOT_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
		EVENT_MANAGER:RegisterForEvent('MiatsTickTracker', EVENT_PLAYER_ACTIVATED, function() 
			MiatsTickTracker:Initialize(MiatsTickTrackerFrame)
			HUD_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
			HUD_UI_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
			LOOT_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
			-- if not MiatsTickTracker.SV.unlocked then MiatsTickTracker.control:SetHidden(true) end
		end)
		EVENT_MANAGER:UnregisterForEvent('MiatsTickTracker', EVENT_ADD_ON_LOADED)
	end
end)