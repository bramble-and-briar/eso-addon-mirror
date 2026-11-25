SimpleDPS = {
	FORMAT_CHANGED = "SimpleDPS_Format_Change",
	BEHAVIOR_CHANGED = "SimpleDPS_Behavior_Change",
	
	RESET_IMMEDIATELY = 1,
	RESET_DEFERRED = 2,
	RESET_LAZY = 3,
	
	name = "SimpleDPS",
	
	inCombat = false,
	inDebug = false,

	Initialize = function (self)	
		self.config = ZO_SavedVars:NewAccountWide("SimpleDPSSavedVariables", 1, nil, {
			damageFormat = "DPS (Percentage)",
			resetBehavior = self.RESET_DEFERRED,
			showPreviousFight = true,
			autoHideEnabled = false,
			windowAlpha = 1,
			windowScale = 1,
			backgroundColor = "FF000000",
			staticTextColor = "FFFF0000",
			activeTextColor = "FFFFFFFF",
			inactiveTextColor = "FF00FF00"
		})
		
		self:SetAlpha()		
		self:RestorePosition()
		self:setFormatFunction()
		self.ConfigUI:setWindowScale(self.config.windowScale)
		self.ConfigUI:setStaticTextColor(self.config.staticTextColor)
		self.ConfigUI:setActiveTextColor(self.config.activeTextColor)
		self.ConfigUI:setInactiveTextColor(self.config.inactiveTextColor)
		
		if not self.config.showPreviousFight then
			self:hidePreviousFight()
		end
		
		self.combatLoopId = self.name .. "Recalculate"
		self.combatEventCallbackId = self.name .. "CombatEvent"
		self.resetCallbackId = self.name .. "ResetMeter"
		self.hudCallbackId = self.name .. "AddToHud"
	  
		if not self.config.autoHideEnabled then
			self:AddToHud()
		end
	  
		if IsUnitInCombat("player") then
			self:registerCombat()
		elseif self.config.autoHideEnabled then
			self:hideMeter()
		end
		
		EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(eventCode, playerInCombat) self:OnCombatStateChange(eventCode, playerInCombat) end)
		EVENT_MANAGER:RegisterForEvent(self.combatEventCallbackId, EVENT_COMBAT_EVENT, 
			function(
				eventCode, result, isError, abilityName, abilityGraphic, 
				abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, 
				powerType, damageType, logg, sourceUnitId, targetUnitId, abilityId, overflow
			) 
				
				self:OnCombatEvent(
					{
						eventCode=eventCode, 
						result=result, 
						isError=isError, 
						abilityName=abilityName, 
						abilityGraphic=abilityGraphic, 
						abilityActionSlotType=abilityActionSlotType, 
						sourceName=sourceName,
						sourceType=sourceType,
						targetName=targetName,
						targetType=targetType,
						hitValue=hitValue,
						powerType=powerType,
						damageType=damageType,
						logg=logg,
						sourceUnitId=sourceUnitId,
						targetUnitId=targetUnitId,
						abilityId=abilityId,
						overflow=overflow,
						inCombat=self.inCombat
					}
				)
				
			end
		)
		
		
		SLASH_COMMANDS["/simpledps"] = function() SimpleDPS.ConfigUI:openMenu() end
		
		if self.inDebug then
			self.fights = {}
		end
		
		self.registerMessage(self.name .. " Initialized")
	end,

	OnAddOnLoaded = function (self, event, addonName)
		if addonName == self.name then
			EVENT_MANAGER:UnregisterForEvent(self.name)
			self:Initialize()
		end
	end,
	
	AddToHud = function (self)
		self.registerMessage("Adding HUD fragment")
		if ZO_HUDFadeSceneFragment and HUD_SCENE and HUD_UI_SCENE then
			self.hudFragment = ZO_SimpleSceneFragment:New(SimpleDPSIndicator, nil, 0)
			HUD_SCENE:AddFragment(self.hudFragment)
			HUD_UI_SCENE:AddFragment(self.hudFragment)			
			EVENT_MANAGER:UnregisterForUpdate(self.hudCallbackId)
			self.registerMessage("HUD fragment added")
		else
			EVENT_MANAGER:RegisterForUpdate(self.hudCallbackId, 5000, function() self:AddToHud() end)
		end
	end,
	
	RemoveFromHud = function (self)
		self.registerMessage("Removing HUD fragment")
		if ZO_HUDFadeSceneFragment and HUD_SCENE and HUD_UI_SCENE then
			HUD_SCENE:RemoveFragment(self.hudFragment)
			HUD_UI_SCENE:RemoveFragment(self.hudFragment)		
			self.registerMessage("HUD fragment removed")
		end
	end,
	
	SetAlpha = function (self)
		SimpleDPSIndicator:SetAlpha(self.config.windowAlpha)
		self.ConfigUI:setBackgroundColor(self.config.backgroundColor)
	end,

	OnCombatStateChange = function (self, eventCode, playerInCombat)
		self.registerMessage(string.format("Combat state change: %s  %i", tostring(playerInCombat), eventCode))
		if playerInCombat == self.inCombat then
			return
		end
		
		if not playerInCombat then
			self.registerMessage("Leaving combat")
			self:unregisterCombat()
		else
			self.registerMessage("Entering combat")
			self:registerCombat()
		end
	end,

	OnCombatEvent = function (self, event)		
		if event.sourceType ~= 4 
			and (event.targetType == 0 or event.targetType == 4)
			and ((event.hitValue or 0) > 0) 
			and (
				event.result == ACTION_RESULT_DOT_TICK
				or event.result == ACTION_RESULT_DOT_TICK_CRITICAL
				or event.result == ACTION_RESULT_DAMAGE
				or event.result == ACTION_RESULT_DAMAGE_SHIELDED
				or event.result == ACTION_RESULT_BLOCKED_DAMAGE
				or event.result == ACTION_RESULT_CRITICAL_DAMAGE
				or event.result == ACTION_RESULT_PRECISE_DAMAGE
				or event.result == ACTION_RESULT_WRECKING_DAMAGE
			)
		then		
			if event.sourceType == 1 or event.sourceType == 2 then			
				if not self.inCombat then
					self.registerMessage("Filter matched, but not in Combat. Trying to register... " .. ((IsUnitInCombat("player") and "true") or "false"))
					self:registerCombat()
					
					if not self.inCombat then
						self.registerMessage("Attempt to register combat failed. Storing hit")
						self.storedHit = { hitValue = event.hitValue, timestamp = os.time() }
						return
					end					
				end
								
				if not self.currentFight.effectiveStart then self.currentFight.effectiveStart = GetGameTimeMilliseconds() end
				self.currentFight.damage = self.currentFight.damage + event.hitValue
				self.currentFight.effectiveFinish = GetGameTimeMilliseconds()
			elseif self.inCombat then
				self.currentFight.groupDamage = self.currentFight.groupDamage + event.hitValue	
			end
		elseif self.inCombat and not IsUnitInCombat("player") then
			self:synchronizeCombat()	
		end
	end,

	calculate = function (self, postmark)
		local currentFight = self.currentFight
		local duration = math.max(postmark - (currentFight.effectiveStart or currentFight.start), 1000)
		
		currentFight.dps = (currentFight.damage / duration) * 1000		
		return currentFight
	end,

	recalculate = function (self)
		self:displayDamage(self:calculate(GetGameTimeMilliseconds()))
		self:synchronizeCombat()
	end,

	calculateEnd = function (self)		
		self:calculate(self.currentFight.effectiveFinish or self.currentFight.finish)
		local damageString = self:generateDamageString(self.currentFight)
		SimpleDPSIndicatorDpsLabelValue:SetText(damageString)
	end,

	resetDpsMeter = function (self)
		SimpleDPSIndicatorDpsLabelValue:SetText("--")
		SimpleDPSIndicatorDpsLabelValue:SetColor(ZO_ColorDef.FromARGBHexadecimal(self.config.activeTextColor):UnpackRGBA())
		local previousDamageString = self:generateDamageString(self.previousFight)
		
		if previousDamageString then
			SimpleDPSIndicatorLastDpsLabelValue:SetText(previousDamageString)
		end
	end,
	
	synchronizeCombat = function (self)
		local actual = IsUnitInCombat("player")
		
		if actual ~= self.inCombat then
			self.registerMessage(string.format("Trying to synchronize combat: %s", tostring(actual)))
		
			if actual then
				self.registerMessage("Unsynchronized; Registering")
				self:registerCombat()
			else
				self.registerMessage("Unsynchronized; Unregistering")
				self:unregisterCombat()
			end
		end
	end,

	registerCombat = function (self)
		if self.inCombat then
			return self.registerMessage("Cannot register combat; Already in combat -- " .. tostring(self.inCombat))
		elseif not IsUnitInCombat("player") then
			return self.registerMessage("Cannot register combat; Player not in combat")
		end
		
		self.inCombat = true
		self.currentFight = {damage=0, groupDamage=0, dps=0}
		self.currentFight.start = GetGameTimeMilliseconds()
		self:resetDpsMeter()
		EVENT_MANAGER:RegisterForUpdate(self.combatLoopId, 1000, function() self:recalculate() end)		
		if self.config.autoHideEnabled then self:showMeter() end
		
		if self.storedHit and os.time() - self.storedHit.timestamp < 3 then
			self.registerMessage("Registering stored hit")
			self.currentFight.damage = self.currentFight.damage + self.storedHit.hitValue
		end
		
		if self.inDebug then
			self.fightId = os.date("%X")
			self.fights[self.fightId] = self.currentFight
			self.registerMessage("Combat registered: " .. self.fightId)
		end	
	end,

	unregisterCombat = function (self)
		if not self.inCombat then 
			return self.registerMessage("Cannot unregister combat! Already exited") 
		elseif IsUnitInCombat("player") then
			return self.registerMessage("Cannot unregister combat! Player still in combat")
		end
		
		self.inCombat = false
		EVENT_MANAGER:UnregisterForUpdate(self.combatLoopId)
		
		if self.currentFight then
			self.currentFight.finish = GetGameTimeMilliseconds()
			
			if self.currentFight.damage > 1 then 
				self.previousFight = self.currentFight 
				self:calculateEnd()
			end
			
			if self.inDebug then 
				self.registerMessage(string.format("Combat unregistered: %s . Length: %d s", self.fightId, (self.currentFight.finish - self.currentFight.start) / 1000))
				self.fightId = nil 
				self:printGroupComparison(self.currentFight) 
			end
			
			if self.config.resetBehavior == self.RESET_IMMEDIATELY or self.currentFight.damage < 2 then
				self:resetDpsMeter()
			else
				SimpleDPSIndicatorDpsLabelValue:SetColor(ZO_ColorDef.FromARGBHexadecimal(self.config.inactiveTextColor):UnpackRGBA())
			end
		end
		
		self.currentFight = nil
		
		EVENT_MANAGER:RegisterForUpdate(self.resetCallbackId, 10000, function() self:softReset() end)			
	end,
	
	softReset = function (self)
		if not self.inCombat then
			if self.config.autoHideEnabled then
				self:hideMeter()
			end
			
			if self.config.resetBehavior == self.RESET_DEFERRED then self:resetDpsMeter() end
		end
		
		EVENT_MANAGER:UnregisterForUpdate(self.resetCallbackId)
	end,

	registerMessage = function (...)
		if SimpleDPS.inDebug then
			d(...)
		end
	end,

	OnIndicatorMoveStop = function (self, control)
		self.config.left = SimpleDPSIndicator:GetLeft()
		self.config.top = SimpleDPSIndicator:GetTop()
	end,

	RestorePosition = function (self)
		local left = self.config.left
		local top = self.config.top
		
		if left and top then
			SimpleDPSIndicator:ClearAnchors()
			SimpleDPSIndicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
		end
	end,

	displayDamage = function (self, fight)	
		SimpleDPSIndicatorDpsLabelValue:SetText(
			self:generateDamageString(fight)
		)
	end,
	
	displayDpsString = function (self, str)
		SimpleDPSIndicatorDpsLabelValue:SetText(str)
	end,
	
	displayPreviousDps = function (self)
		if not self.previousFight then return end
		
		SimpleDPSIndicatorLastDpsLabelValue:SetText(self:generateDamageString(self.previousFight))
	end,

	generateDamageString = function (self, fight)
		if not fight then return end
		
		return self.formatFunction(fight)
	end,

	printGroupComparison = function (self, currentFight)
		local totalDamage = currentFight.damage + currentFight.groupDamage
		local playerPercentage = (currentFight.damage / totalDamage) * 100
		local groupPercentage = (currentFight.groupDamage / totalDamage) * 100
		
		self.registerMessage(string.format("Player : Group   %i : %i   %02.2f%% : %02.2f%%   (total: %s)", currentFight.damage, currentFight.groupDamage, playerPercentage, groupPercentage, self.damageFormat:unitize(totalDamage)))
		self.registerMessage(string.format("Fight length %i s. Group DPS: %s", (currentFight.finish - currentFight.start) / 1000, self.damageFormat:unitize(totalDamage / (currentFight.finish - currentFight.start))))
	end,
	
	showMeter = function (self)
		SimpleDPSIndicator:SetHidden(false)
		self:AddToHud()
	end,
	
	hideMeter = function( self)
		self:RemoveFromHud()
		SimpleDPSIndicator:SetHidden(true)		
	end,
	
	showPreviousFight = function (self)
		SimpleDPSIndicator:SetHeight(self.config.windowScale * 60)
		SimpleDPSIndicatorDps:ClearAnchors()		
		SimpleDPSIndicatorDps:SetAnchor(BOTTOM, SimpleDPSIndicator, CENTER)		
		SimpleDPSIndicatorLastDps:SetHidden(false)
	end,
	
	hidePreviousFight = function (self)
		SimpleDPSIndicator:SetHeight(self.config.windowScale * 35)
		SimpleDPSIndicatorLastDps:SetHidden(true)
		SimpleDPSIndicatorDps:ClearAnchors()		
		SimpleDPSIndicatorDps:SetAnchor(CENTER, SimpleDPSIndicator, CENTER)
	end,
	
	setWidth = function (self, scaleFactor)
		local scale = scaleFactor or self.config.windowScale
		local i = 1
		
		for s in string.gfind(self.config.damageFormat, " ") do
			i = i + 1
		end
		
		local damage = 67 * i
		local container = 71 + 2 + damage
		local parent = container + 18
		
		damage = scale * damage
		container = scale * container
		parent = scale * parent
		
		SimpleDPSIndicator:SetWidth(parent)
		SimpleDPSIndicatorDps:SetWidth(container)
		SimpleDPSIndicatorLastDps:SetWidth(container)
		SimpleDPSIndicatorDpsLabelValue:SetWidth(damage)
		SimpleDPSIndicatorLastDpsLabelValue:SetWidth(damage)
	end,
	
	setFormatFunction = function (self)
		self.formatFunction = self.damageFormat.FORMAT_DISPLAY_MAP[self.config.damageFormat]
	end,
	
	damageFormat = {
		FORMAT_DISPLAY_MAP = {
			["DPS"] = function(fight) return SimpleDPS.damageFormat:dps(fight) end,
			["Percentage"] = function(fight) return SimpleDPS.damageFormat:percentage(fight) end,
			["DPS (Percentage)"] = function(fight) return SimpleDPS.damageFormat:dpsPercentage(fight) end,
			["Percentage (DPS)"] = function(fight) return SimpleDPS.damageFormat:percentageDps(fight) end,
			["Total"] = function (fight) return SimpleDPS.damageFormat:total(fight) end,
			["Total (DPS)"] = function (fight) return SimpleDPS.damageFormat:totalDps(fight) end,
			["DPS (Total)"] = function (fight) return SimpleDPS.damageFormat:dpsTotal(fight) end,
			["Total (Percentage)"] = function (fight) return SimpleDPS.damageFormat:totalPercentage(fight) end,
			["Percentage (Total)"] = function (fight) return SimpleDPS.damageFormat:percentageTotal(fight) end,
			["Total (DPS) Percentage"] = function (fight) return SimpleDPS.damageFormat:totalDpsPercentage(fight) end,
			["Total (Percentage) DPS"] = function (fight) return SimpleDPS.damageFormat:totalPercentageDps(fight) end,
			["Percentage (DPS) Total"] = function (fight) return SimpleDPS.damageFormat:percentageDpsTotal(fight) end,
			["Percentage (Total) DPS"] = function (fight) return SimpleDPS.damageFormat:percentageTotalDps(fight) end,
			["DPS (Total) Percentage"] = function (fight) return SimpleDPS.damageFormat:dpsTotalPercentage(fight) end,
			["DPS (Percentage) Total"] = function (fight) return SimpleDPS.damageFormat:dpsPercentageTotal(fight) end,
		},
	
	
		DENOMINATOR_LABEL_TABLE = { "", "k", "m", "b" },
		DENOMINATOR_TABLE = { 1, 10^3, 10^6, 10^9 },
		
		dps = function (self, fight)
			return self:unitize(fight.dps)
		end,
		
		percentage = function (self, fight)
			return string.format("%d%%", (fight.damage / math.max(fight.damage + fight.groupDamage, 1)) * 100)
		end,
		
		total = function (self, fight)
			return self:unitize(fight.damage)
		end,
		
		unitize = function (self, raw)
			if not raw then return end
			
			local i = 1
			
			while i < 5 and raw > (self.DENOMINATOR_TABLE[i + 1] or 10^12) do
				i = i + 1
			end

			return string.format("%.2f %s", raw / self.DENOMINATOR_TABLE[i], self.DENOMINATOR_LABEL_TABLE[i]) 
		end,
		
		percentageDps = function (self, fight)
			return string.format("%s (%s)", self:percentage(fight), self:dps(fight))
		end,
		
		dpsPercentage = function (self, fight)
			return string.format("%s (%s)", self:dps(fight), self:percentage(fight))
		end,
		
		totalDps = function (self, fight)
			return string.format("%s (%s)", self:total(fight), self:dps(fight))
		end,
		
		dpsTotal = function (self, fight)
			return string.format("%s (%s)", self:dps(fight), self:total(fight))
		end,
		
		totalPercentage = function (self, fight)
			return string.format("%s (%s)", self:total(fight), self:percentage(fight))
		end,
		
		percentageTotal = function (self, fight)
			return string.format("%s (%s)", self:percentage(fight), self:total(fight))
		end,
		
		totalDpsPercentage = function (self, fight)
			return string.format("%s %s", self:totalDps(fight), self:percentage(fight))
		end,
		
		totalPercentageDps = function (self, fight)
			return string.format("%s %s", self:totalPercentage(fight), self:dps(fight))
		end,
		
		percentageDpsTotal = function (self, fight)
			return string.format("%s %s", self:percentageDps(fight), self:total(fight))
		end,
		
		percentageTotalDps = function (self, fight)
			return string.format("%s %s", self:percentageTotal(fight), self:dps(fight))
		end,
		
		dpsTotalPercentage = function (self, fight)
			return string.format("%s %s", self:dpsTotal(fight), self:percentage(fight))
		end,
		
		dpsPercentageTotal = function (self, fight)
			return string.format("%s %s", self:dpsPercentage(fight), self:total(fight))
		end,
	}
}

EVENT_MANAGER:RegisterForEvent(SimpleDPS.name, EVENT_ADD_ON_LOADED, function(event, addonName) SimpleDPS:OnAddOnLoaded(event, addonName) end)