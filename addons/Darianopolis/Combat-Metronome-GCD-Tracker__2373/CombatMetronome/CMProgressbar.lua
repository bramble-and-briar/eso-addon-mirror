local Util = DariansUtilities
Util.Ability = Util.Ability or {}
Util.Ability.Tracker = Util.Ability.Tracker or {}
local Tracker = Util.Ability.Tracker
Util.Text = Util.Text or {}
CombatMetronome.SV = CombatMetronome.SV or {}

local function AnchorSpellIcon(dynamic)
	if dynamic and not CombatMetronome.Progressbar.spellIconAnchoredDynamically then
		CombatMetronome.Progressbar.spellIcon:ClearAnchors()
		CombatMetronome.Progressbar.spellIcon:SetAnchor(RIGHT, CombatMetronome.Progressbar.bar.segments[2].bars[1], RIGHT, -(CombatMetronome.SV.Progressbar.height/10), 0)
		CombatMetronome.Progressbar.spellIconAnchoredDynamically = true
	elseif CombatMetronome.Progressbar.spellIconAnchoredDynamically and not dynamic then
		CombatMetronome.Progressbar.spellIcon:ClearAnchors()
		CombatMetronome.Progressbar.spellIcon:SetAnchor(RIGHT, CombatMetronome.Progressbar.frame, LEFT, -(CombatMetronome.SV.Progressbar.height/10), 0)
		CombatMetronome.Progressbar.spellIconAnchoredDynamically = false
	end
end

local function CreateDisplayName(name)
	local displayName
	CombatMetronome.Progressbar.spellLabel:SetText(name)
	local barSpace = CombatMetronome.SV.Progressbar.width - (CombatMetronome.SV.Progressbar.showTimeRemaining and 2.5*CombatMetronome.Progressbar.timeLabel:GetWidth() or 0)
	if CombatMetronome.Progressbar.spellLabel:GetWidth() > barSpace then
		for i = #name, 1, -1 do
			local shortName =  string.sub(name, 1, i):gsub("%s+$", "") .. ".."
			CombatMetronome.Progressbar.spellLabel:SetText(shortName)
			if CombatMetronome.Progressbar.spellLabel:GetWidth() <= barSpace then
				displayName = shortName
				break
			end
		end
	else
		displayName = name
	end
	
	return displayName
end

	--------------------------
	---- Cast Bar Updater ----
	--------------------------

function CombatMetronome:Update()

	local latency, cdTimer
	local sv = CombatMetronome.SV.Progressbar
	local progressbar = CombatMetronome.Progressbar

	------------------------
	---- Sample Section ----
	------------------------

	if progressbar.showSample then
		progressbar.bar.segments[2].progress = 0.7
		progressbar.bar.backgroundTexture:SetWidth(0.7*sv.width)
		if sv.dontShowPing then
			progressbar.bar.segments[1].progress = 0
		else
			progressbar.bar.segments[1].progress = 0.071
		end
		if sv.showSpell then
			progressbar.spellLabel:SetText("Generic sample text")
			progressbar.spellIcon:SetTexture("/esoui/art/icons/ability_dualwield_002_b.dds")
		end
		if sv.showTimeRemaining then
			progressbar.timeLabel:SetText("7.8s")
		end
		if sv.changeOnChanneled then
			progressbar.bar.segments[2].color = sv.channelColor
		else
			progressbar.bar.segments[2].color = sv.progressColor
		end
		progressbar.bar:Update()
		progressbar.UI.HiddenStates()
	else
	
	-------------------------
	---- Actual Updating ----
	-------------------------
	
		-- reset channeled color --
		if not (self.currentEvent and self.currentEvent.ability and ((not self.currentEvent.ability.instant and self.currentEvent.ability.delay <= 1000) or self.currentEvent.ability.delay > 1000)) and progressbar.bar.segments[2].color ~= sv.progressColor then
			progressbar.bar.segments[2].color = sv.progressColor
		elseif not self.currentEvent and progressbar.bar.segments[2].color ~= sv.progressColor then
			progressbar.bar.segments[2].color = sv.progressColor
		end
		
		if sv.dontShowPing then
			latency = 0
		else
			latency = math.min(GetLatency(), sv.maxLatency)
		end
		
		local time = GetFrameTimeMilliseconds()
		
		-- this is important for GCD Tracking
		local gcdProgress, slotRemaining, slotDuration = Tracker:GCDCheck()
		
			---------------------
			---- GCD Tracker ----
			---------------------
		if not self.currentEvent and not progressbar.soundTickPlayed then
			-- if force tick needed then play 'tick'
			if sv.forceSoundTock and (self.inCombat or (sv.showOOC and sv.playSoundsOOC)) and
			(
			-- tick at start of the ability
			(not sv.soundTickMidAbility and not sv.forceTickMSBeforeEnd and slotRemaining >= slotDuration - sv.soundTickOffset) or
			-- tick at set amount of ms left of an ability
			(sv.forceTickMSBeforeEnd and slotRemaining >= sv.forceTickTime - sv.soundTickOffset) or
			-- tick mid ability
			(sv.soundTickMidAbility and not sv.forceTickMSBeforeEnd and slotRemaining >= 500 - sv.soundTickOffset)
			) then
				self:PrintDebug("tickTock", "forced 'tick'")
				for i = 1, math.min(sv.tickVolume, 30) do
					PlaySound(sv.soundTickEffect)
				end
			end
			
			-- reset soundTickPlayed regardles of being played. if it didn't have to be forced to be played, you don't need to play it regularly.
			progressbar.soundTickPlayed = true
		end
		
		-- if not progressbar.soundTockPlayed then
			-- local timeToPlayTock = (self.abilityFinished or 0) + sv.soundTockOffset
			-- local timeToForceTock = (self.lastAbilityFinished or 0) + sv.soundTockOffset
			-- local needToForce = sv.forceSoundTock and self.currentEvent and time >= timeToForceTock and timeToForceTock >= self.currentEvent.start
			
			-- if time >= timeToPlayTock then
				-- self:PrintDebug("tickTock", "time to 'tock'")
				-- if (self.inCombat or (sv.showOOC and sv.playSoundsOOC)) then --and time > start + (length / 2) - sv.soundTockOffset then
					-- if not self.currentEvent and (slotRemaining == 0 or (sv.soundTockOffset < 0 and slotRemaining >= -sv.soundTockOffset)) or needToForce then
					
						-- if needToForce then		-- kill self.lastAbilityFinished so the statement will not be true in the future
							-- self:PrintDebug("tickTock", "forced 'tock'")
							-- self.lastAbilityFinished = self.abilityFinished
						-- else
							-- self:PrintDebug("tickTock", "normal 'tock'")
							-- progressbar.soundTockPlayed = true
						-- end
						
						-- for i = 1, math.min(sv.tickVolume, 30) do
							-- PlaySound(sv.soundTockEffect)
						-- end
					-- elseif not sv.forceSoundTock then
						-- self:PrintDebug("tickTock", "no need to force 'tock', clear queue")
						-- progressbar.soundTockPlayed = true
					-- end
				-- else
					-- self:PrintDebug("tickTock", "cleared 'tock' queue. time to 'tock' is over but you're not in combat")
					-- progressbar.soundTockPlayed = true
				-- end
			-- end
		-- end
		
		if not progressbar.soundTockPlayed and not self.currentEvent and time >= self.abilityFinished + sv.soundTockOffset and (self.inCombat or (sv.showOOC and sv.playSoundsOOC))
		   and ((slotRemaining == 0) or (sv.soundTockOffset < 0 and slotRemaining >= -sv.soundTockOffset)) then
			
			progressbar.soundTockPlayed = true
			
			self:PrintDebug("tickTock", "normal 'tock'")
			for i = 1, math.min(sv.tickVolume, 30) do
				PlaySound(sv.soundTockEffect)
			end
		end
		
		if sv.trackGCD and not self.currentEvent then
			
			--reset spellIcon anchor
			if progressbar.spellIconAnchoredDynamically then
				AnchorSpellIcon(false)
			end
			
			progressbar.bar.background:SetWidth(sv.width)
			progressbar.bar.borderL:SetWidth(sv.width/2)
			progressbar.bar.borderR:SetWidth(sv.width/2)
			
			progressbar.bar.segments[1].progress = (sv.showPingOnGCD and latency/1000) or 0
			progressbar.bar.segments[2].progress = gcdProgress
			
			-- local gcdEvent = self.gcdEvent
			if self.gcdEvent.finished <= time then
				self.gcdEvent = {finished = 0}
				if Tracker.rollDodgeFinished >= time and sv.trackRolldodge then
					self.gcdEvent.displayName = CreateDisplayName(Util.Text.CropZOSString(GetAbilityName(28549), "ability"))
					self.gcdEvent.icon = "/esoui/art/icons/ability_rogue_035.dds"
					self.gcdEvent.clearSynergy = false
					self.gcdEvent.finished = time + slotRemaining
				elseif progressbar.activeMount.action ~= "" and sv.trackMounting then
					if sv.showMountNick then
						self.gcdEvent.displayName = CreateDisplayName(string.format("%s (%s)",progressbar.activeMount.action,progressbar.activeMount.name))
					else
						self.gcdEvent.displayName = CreateDisplayName(progressbar.activeMount.action)
					end
					self.gcdEvent.icon = progressbar.activeMount.icon
					self.gcdEvent.clearSynergy = false
					self.gcdEvent.finished = time + slotRemaining
				elseif progressbar.collectibleInUse and sv.trackCollectibles then
					self.gcdEvent.displayName = CreateDisplayName(progressbar.collectibleInUse.name)
					self.gcdEvent.icon = progressbar.collectibleInUse.icon
					self.gcdEvent.clearSynergy = false
					self.gcdEvent.finished = time + slotRemaining
				elseif progressbar.synergy and sv.trackSynergies and progressbar.synergy.wasUsed then
					self.gcdEvent.displayName = CreateDisplayName(progressbar.synergy.name)
					self.gcdEvent.icon = progressbar.synergy.icon
					self.gcdEvent.clearSynergy = true
					self.gcdEvent.finished = time + slotRemaining
				elseif progressbar.itemUsed and sv.trackItems then
					self.gcdEvent.displayName = CreateDisplayName(progressbar.itemUsed.name)
					self.gcdEvent.icon = progressbar.itemUsed.icon
					self.gcdEvent.clearSynergy = false
					self.gcdEvent.finished = time + slotRemaining
				elseif progressbar.breakingFree and sv.trackBreakingFree then
					self.gcdEvent.displayName = CreateDisplayName(progressbar.breakingFree.name)
					self.gcdEvent.icon = progressbar.breakingFree.icon
					self.gcdEvent.clearSynergy = false
					self.gcdEvent.finished = time + slotRemaining
				elseif progressbar.festivalGCD then
					self.gcdEvent.displayName = CreateDisplayName(self.FESTIVAL_IDS[progressbar.festivalGCD].name)
					self.gcdEvent.icon = self.FESTIVAL_IDS[progressbar.festivalGCD].icon
					self.gcdEvent.clearSynergy = false
					self.gcdEvent.finished = time + slotRemaining
				end
				self:SetIconsAndNamesNil()
			end
			
			if self.gcdEvent.displayName then self:GCDSpecifics(self.gcdEvent.displayName, self.gcdEvent.icon, gcdProgress, self.gcdEvent.clearSynergy) end
			
			if slotRemaining <= 0 then
				self:OnCDStop("Reset non ability stuff")
				self.gcdEvent = {finished = 0}
			else
				self:HideBar(false)
				progressbar.bar.backgroundTexture:SetWidth(gcdProgress*sv.width)
			end
			progressbar.bar:Update()
		elseif self.currentEvent then
			-- self.debug:Print(self.currentEvent.ability.name)
			-- if CombatMetronome.SV.debug.triggers then CombatMetronome.debug:Print(remaining) end
			if slotRemaining <= 0 and self.currentEvent.ability.delay <= 1000 and not self.currentEvent.ability.channeled and not self.currentEvent.ability.heavy then
				self:OnCDStop("GCD over")
				return
			end
			local ability = self.currentEvent.ability
			
			if not ability.name or ability.name == "" then
				self:OnCDStop("No ability name")
				return
			end
			
			local start = self.currentEvent.start
			if time - start < 0 then
				cdTimer = 0
			else
				cdTimer = time - start
			end
			
			local duration = (ability.heavy and ability.delay or math.max(self.gcd or 1000, ability.delay)) + (self.currentEvent.adjust or 0)
			-- local timeRemaining = ((start + duration + latency) - time) / 1000 or ((start + channelTime + latency) - time) < 0 and 0
			local timeRemaining = (duration - cdTimer) / 1000
			local castProgress = timeRemaining/(duration/1000)
			
			if timeRemaining < 0 then
				self:OnCDStop("Time remaining < 0")
				return
			end
			
			local dynamicProgress = sv.expandDynamically and sv.dynamicExpansionMultiplyer*duration/10000 > 1 and duration <= 6000
			-- local multiplyerCheck = sv.dynamicExpansionMultiplyer*math.max(duration, timeRemaining*1000)/10000 > 1
						
			-- local playerDidBlock = (self.lastBlockStatus == false) and IsBlockActive()
			-- if playerDidBlock and self.SV.debug.enabled then CombatMetronome.debug:Print("Player blocked") end
			
			if ability.heavy then
				-- if dynamicProgress and ability.channelTime > 1500 then dynamicProgress = false end
				if not sv.displayPingOnHeavy then
					-- duration = duration + latency
				-- else
					latency = 0
				end
			end
			----------------------
			---- Progress Bar ----
			----------------------
			if time > self.currentEvent.ending and slotRemaining == 0 then
				self:OnCDStop("Event seems to be over")
				return
			else
				-- local length = duration - latency
				
				-- Sound contributed to by Seltiix --
				if not progressbar.soundTickPlayed then
					if (
						-- tick at start of the ability
						(not sv.soundTickMidAbility and not sv.forceTickMSBeforeEnd and time >= start + sv.soundTickOffset) or
						-- tick at set amount of ms left of an ability
						(sv.forceTickMSBeforeEnd and timeRemaining*1000 <= sv.forceTickTime) or
						-- tick mid ability
						(sv.soundTickMidAbility and not sv.forceTickMSBeforeEnd and time >= start + duration/2 + sv.soundTickOffset)
					) then
					
						progressbar.soundTickPlayed = true
						
						if self.inCombat or (sv.showOOC and sv.playSoundsOOC) then
							self:PrintDebug("tickTock", string.format("normal 'tick' for '%s'", ability.name))
							for i = 1, math.min(sv.tickVolume, 30) do
								PlaySound(sv.soundTickEffect)
							end
						end
					end
				end
				if not progressbar.soundTockPlayed then
					local isSameEvent = sv.soundTockOffset < 0
					local tockTimer = isSameEvent and (self.currentEvent.ending + sv.soundTockOffset) or (sv.forceSoundTock and (self.lastAbilityFinished + sv.soundTockOffset) or 0)
						-- forced 'tock' during next ability								normal 'tock' during same ability
					if (sv.forceSoundTock and tockTimer >= start and time >= tockTimer) or (not sv.forceSoundTock and isSameEvent and time >= tockTimer) then
						if (self.inCombat or (sv.showOOC and sv.playSoundsOOC)) then
							for i = 1, math.min(sv.tickVolume, 30) do
								PlaySound(sv.soundTockEffect)
							end
						end
						
						if isSameEvent then
							self:PrintDebug("tickTock", string.format("normal 'tock' for '%s'", ability.name))
							progressbar.soundTockPlayed = true
						elseif sv.forceSoundTock then
							self:PrintDebug("tickTock", "force 'tock' during next ability")
							self.lastAbilityFinished = self.abilityFinished		-- kill lastAbilityFinished to not let the statement be true again all the time
						end
					end
				end
			------------------------------------------------
			---- Switching Color on channeled abilities ----
			------------------------------------------------
				if sv.changeOnChanneled then
					if (not ability.instant and ability.delay <= 1000) or ability.delay > 1000 then
						local castIsFinished = ((ability.delay <= 1000) and (timeRemaining*1000 <= 1000 - ability.delay)) or (timeRemaining <= 0)
						if not castIsFinished and progressbar.bar.segments[2].color == sv.progressColor then
							progressbar.bar.segments[2].color = sv.channelColor
						elseif not ability.heavy and castIsFinished  and progressbar.bar.segments[2].color == sv.channelColor then
							progressbar.bar.segments[2].color = sv.progressColor
						end
					else
						if progressbar.bar.segments[2].color == sv.channelColor then
							progressbar.bar.segments[2].color = sv.progressColor
						end
					end
				end
				if cdTimer >= (duration+latency) then
					self:OnCDStop("cdTimer seems to be over")
				else
					self:HideBar(false)
				end
				
				if dynamicProgress then
					local multiplyer = sv.dynamicExpansionMultiplyer*duration/10000
					local isDynamic = castProgress*multiplyer > 1
					local dynamicBarWidth = isDynamic and sv.width*castProgress*multiplyer or sv.width
					progressbar.bar.segments[2].progress = isDynamic and 1 or castProgress*multiplyer
					progressbar.bar.segments[1].progress = isDynamic and multiplyer*latency / (1000*timeRemaining) or sv.dynamicExpansionMultiplyer*latency/duration
					progressbar.bar.background:SetWidth(dynamicBarWidth)
					progressbar.bar.backgroundTexture:SetWidth(sv.width*castProgress*multiplyer)
					progressbar.bar.borderL:SetWidth(dynamicBarWidth/2)
					progressbar.bar.borderR:SetWidth(dynamicBarWidth/2)
					local dynamicAnchor = sv.barAlign == "Center" and sv.moveIconDynamically and isDynamic
					AnchorSpellIcon(dynamicAnchor)
				else
					progressbar.bar.background:SetWidth(sv.width)
					progressbar.bar.segments[2].progress = castProgress
					progressbar.bar.segments[1].progress = latency / duration
					progressbar.bar.backgroundTexture:SetWidth(castProgress*sv.width)
					progressbar.bar.borderL:SetWidth(sv.width/2)
					progressbar.bar.borderR:SetWidth(sv.width/2)
					AnchorSpellIcon(false)
				end
				progressbar.bar:Update()
			end
			------------------------------
			---- Spell Label and Icon ----
			------------------------------	
			
			--Remaining time on Castbar by barny
			if sv.showTimeRemaining and ((ability.delay > 0 and timeRemaining >= 0) or sv.alwaysShowTimeRemaining) and (not ability.heavy or ability.heavy and sv.showHeavyDetails) then
				progressbar.timeLabel:SetText(string.format("%.1fs", timeRemaining))
				progressbar.timeLabel:SetHidden(false)
			else
				progressbar.timeLabel:SetHidden(true)
			end
			
			--Spell Label on Castbar by barny
			if sv.showSpell and ((ability.delay > 0 and timeRemaining >= 0) or sv.alwaysShowSpell) and (not ability.heavy or ability.heavy and sv.showHeavyDetails) then
				if not ability.displayName then
					ability.displayName = CreateDisplayName(ability.name)
				end
				progressbar.spellLabel:SetText(ability.displayName)
				progressbar.spellLabel:SetHidden(false)
				
			--Spell Icon next to Castbar
				progressbar.spellIcon:SetTexture(ability.icon)
				progressbar.spellIcon:SetHidden(false)
				progressbar.spellIconBorder:SetHidden(false)
			else
				progressbar.spellLabel:SetHidden(true)
				progressbar.spellIcon:SetHidden(true)
				progressbar.spellIconBorder:SetHidden(true)
			end
		else
			self:OnCDStop("End of update cycle")
			progressbar.bar:Update()
		end
	end
end