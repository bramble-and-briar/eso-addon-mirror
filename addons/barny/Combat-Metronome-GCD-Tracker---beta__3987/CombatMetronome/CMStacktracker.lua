local Util = DariansUtilities
Util.Stacks = Util.Stacks or {}
CombatMetronome.StackTracker = CombatMetronome.StackTracker or {}
local StackTracker = CombatMetronome.StackTracker
local CM = CombatMetronome

	-------------------------------
	---- Stack Tracker Updater ----
	-------------------------------

local animStart = false
local trackerShouldBeVisible = false
local sampleAnimationStarted = false
local previousStack

function StackTracker:HandleEffectChanged(_,changeType, _, _, unitTag, beginTime, endTime, stackCount, _, _, _, _, _, uName, uId, aId, _)	
	if not self.trackedIds[aId] then return end
	
	local attributes = self.SKILL_ATTRIBUTES[self.trackedIds[aId]]
	local sv = CombatMetronome.SV.StackTracker[self.trackedIds[aId]]
	local needsTimer = (sv.showTimer or sv.showTimerBar)
	
	local iMax = attributes.iMax
	if self.trackedIds[aId] == "FI" then 
		stackCount = 1
	elseif self.trackedIds[aId] == "FS" and stackCount == 3 then
		stackCount = 0
	end
	-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("Found matching id, initiating stackCount change") end
	if changeType == EFFECT_RESULT_FADED then stackCount = 0 end
	self:ChangeStackCount(self.trackedIds[aId], stackCount)
	if needsTimer and (beginTime ~= endTime) and stackCount ~= 0 then
		if not self.timers then self.timers = {} end
		self.timers[self.trackedIds[aId]] = {
			["duration"] = endTime - beginTime,
			["endTime"] = endTime
		}
		if not self.timerUpdaterRegistered then
			self:RegisterTimerUpdater()
		end
	end
end

-- function StackTracker:HandleHotbarChangeRequested(_,aId,_,_)
	-- local morph = Util.Stacks.morphs.FS
	-- for i=2,3 do
		-- if self.SKILL_ATTRIBUTES.FS.id[morph].ability[i] then
			-- self:ChangeStackCount("FS", i-1)
			-- break
		-- end
	-- end
-- end

function StackTracker:ChangeStackCount(skill, stackCount)
	if not self.UI[skill] then
		if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("Tried to change "..skill.." stackCount without UI initialized") end
		return
	else
		self:HideTracker(skill, false)
	end
	local attributes = self.SKILL_ATTRIBUTES[skill]
	local sv = CombatMetronome.SV.StackTracker[skill]
	local oneOff = attributes.activation - 1
	local animStart = not self.UI[skill].indicator[attributes.activation].controls.highlightAnimation:IsControlHidden()
	previousStack = self.stacks[skill]
	self.stacks[skill] = stackCount
	
	
	for i=1,#self.UI[skill].indicator do 
		self.UI[skill].indicator[i].Deactivate()
		self.UI[skill].indicator[i].SetAnimationHidden(true)
	end
	if sv.hightlightOnFullStacks then											--Animation when stacks are full
		if stackCount >= attributes.activation and not animStart then
			for i=1,#self.UI[skill].indicator do
				self.UI[skill].indicator[i].Animate()
			end
			animStart = true
		elseif animStart == true and stackCount < attributes.activation then
			for i=1,#self.UI[skill].indicator do
				self.UI[skill].indicator[i].StopAnimation()
			end
			animStart = false
		end
	end
	for i=1,stackCount do
		self.UI[skill].indicator[i].Activate()
		if animStart then self.UI[skill].indicator[i].SetAnimationHidden(false) end
	end
	if sv.playSound then														--Sound cue when stacks are full
		if previousStack == oneOff and stackCount == attributes.activation then
			for i = 1, math.min(sv.volume, 30) do
				PlaySound(SOUNDS[sv.sound])
			end
		end
	end
	if not CombatMetronome.SV.StackTracker.isUnlocked and not CombatMetronome.inCombat and CombatMetronome.SV.StackTracker.onlyInCombat and stackCount == 0 then
		self:HideTracker(skill, true)
	end
end

local function HideTimers(skill)
	local ui = StackTracker.UI[skill].indicator
	
	if CombatMetronome.SV.StackTracker.isUnlocked then
		ui.timer:SetText("2.5")
		ui.timerBar:SetValue(0.5)
		ui.timerBarTimer:SetText("2.5")
		return
	end
	
	ui.timer:SetHidden(true)
	ui.timerBar:SetHidden(true)
	ui.timerBarBackdrop:SetHidden(true)
	ui.timerBarGloss:SetHidden(true)
	ui.timerBarTimer:SetHidden(true)
end

local function TimerSize(skill, multiplier, size)
	local ui = StackTracker.UI[skill].indicator
	ui.timer:SetDimensions(size*1.5*multiplier, size*multiplier)
	ui.timer:SetFont(Util.Text.getFontString(tostring("$(BOLD_FONT)"), size*multiplier, "outline"))
	-- ui.TimerBarAnchors()
end

function StackTracker:UpdateTimers()
	if not self.timers or (self.timers and not next(self.timers)) then
		for _, skill in pairs(self.trackedIds) do
			if self.UI[skill].indicator.timer then
				HideTimers(skill)
			end
		end
		return
	end
	
	local time = GetGameTimeSeconds()
	local shouldBeRegistered = false
	
	for skill, entry in pairs(self.timers) do
		local timeLeft = entry.endTime-time
		local needsTimer = (self.stacks[skill] ~= 0) and timeLeft > 0
		local sv = CombatMetronome.SV.StackTracker[skill]
		local ui = self.UI[skill].indicator
		
		local function CalculateTimer(timeleft)
			local str
			if timeLeft >= 10 then
				str = tostring(zo_round(timeLeft))
			else
				str = string.format("%.1f", timeLeft)
			end
			return str
		end
		
		if not needsTimer then
			self.timers[skill] = nil
			HideTimers(skill)
		else
			shouldBeRegistered = true
			
			local doReminder = (sv.remindersOnlyInCombat and CombatMetronome.inCombat) or not sv.remindersOnlyInCombat
			if sv.showTimer then
				ui.timer:SetHidden(false)
				ui.timer:SetText(CalculateTimer(timeLeft))
				
				if sv.animateTimer and doReminder and timeLeft <= sv.expirationTimer then
					local multiplier = (self.SKILL_ATTRIBUTES[skill].multiplier or 1)*(2+math.sin((timeLeft-sv.expirationTimer)*3*math.pi)/2)
					TimerSize(skill, multiplier, sv.indicatorSize)
				else
					TimerSize(skill, 1, sv.indicatorSize)
				end
			else
				ui.timer:SetHidden(true)
			end
			if sv.showTimerBar then
				ui.timerBar:SetHidden(false)
				ui.timerBarBackdrop:SetHidden(false)
				ui.timerBarGloss:SetHidden(false)
				ui.timerBar:SetValue(timeLeft/entry.duration)
				
				if not sv.showTimer then
					ui.timerBarTimer:SetHidden(false)
					ui.timerBarTimer:SetText(CalculateTimer(timeLeft))
				elseif sv.showTimer then
					ui.timerBarTimer:SetHidden(true)
				end
				
				if sv.soundReminder and doReminder and timeLeft <= sv.expirationTimer and not entry.soundPlayed then
					entry.soundPlayed = true
					for i = 1, math.min(sv.reminderVolume, 30) do
						PlaySound(sv.expirationSound)
					end
				end
			end
		end
	end
	
	if not shouldBeRegistered then self:UnregisterTimerUpdater() end
end

function StackTracker:RegisterTimerUpdater()	
	EVENT_MANAGER:RegisterForUpdate(
        self.name.."UpdateTimers",
        1000 / 60,
        function(...) self:UpdateTimers() end
    )
	self.timerUpdaterRegistered = true
end

function StackTracker:UnregisterTimerUpdater()
	if not self.timerUpdaterRegistered then return end
	
	EVENT_MANAGER:UnregisterForUpdate(
        self.name.."UpdateTimers")
	
	self.timerUpdaterRegistered = false
end