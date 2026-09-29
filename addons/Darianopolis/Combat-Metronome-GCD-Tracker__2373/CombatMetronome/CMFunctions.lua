local LAM = LibAddonMenu2
local Util = DariansUtilities
Util.Text = Util.Text or {}
Util.Stacks = Util.Stacks or {}
CombatMetronome.StackTracker = CombatMetronome.StackTracker or {}
local StackTracker = CombatMetronome.StackTracker

-- local GRACE_PERIOD = 500
	
	--------------------------
	---- Helper Functions ----
	--------------------------

function CombatMetronome:OnCDStop(reason)
	if CombatMetronome.SV.Progressbar.dontHide then
		if CombatMetronome.SV.Progressbar.makeItFancy then
			self:HideFancy(false)
		else
			self:HideFancy(true)
		end
	else
		self:HideFancy(true)
		self.Progressbar.bar:SetHidden(true)
	end
	self:HideLabels(true)
	self:ResetBarValues()
		
	if self.currentEvent then
		self:SetEventNil(reason)
	elseif reason == "" then
		self.abilityFinished = GetFrameTimeMilliseconds()
	else
		self:PrintDebug("cdStop", reason)
	end
end

function CombatMetronome:ResetBarValues()
	self.Progressbar.bar.segments[1].progress = 0
	self.Progressbar.bar.segments[2].progress = 0
	self.Progressbar.bar.backgroundTexture:SetWidth(0)
	
	self.Progressbar.bar:Update()
end

function CombatMetronome:HideBar(value)
	if CombatMetronome.SV.Progressbar.makeItFancy then
		self:HideFancy(value)
	else
		self:HideFancy(true)
	end
	self.Progressbar.bar:SetHidden(value)
end

function CombatMetronome:SetEventNil(reason)	
	if self.currentEvent then
		self.currentEvent = nil
		self.abilityFinished = GetFrameTimeMilliseconds()
		Util.Ability.Tracker:CancelCurrentEvent(string.format("CM: %s", reason))
		Util.Ability.Tracker.lastAbilityFinished = 0
	end
	
	self:ResetBarValues()
end

function CombatMetronome:HideLabels(value)
	self.Progressbar.spellLabel:SetHidden(value)
	self.Progressbar.timeLabel:SetHidden(value)
	self.Progressbar.spellIcon:SetHidden(value)
	self.Progressbar.spellIconBorder:SetHidden(value)
end

function CombatMetronome:HideFancy(value)
	self.Progressbar.bar.backgroundTexture:SetHidden(value)
	self.Progressbar.bar.borderL:SetHidden(value)
	self.Progressbar.bar.borderR:SetHidden(value)
end

	--------------------------------
	---- GCD Tracking specifics ----
	--------------------------------
	
function CombatMetronome:CreateMenuIconsPath(ControlName, panel)
	local number = 0
	for i, entry in ipairs(panel.controlsToRefresh) do
		if ControlName == entry.data.name then
			number = i
		end
	end
	return number
end

function CombatMetronome:GCDSpecifics(text, icon, gcdProgress, wasSynergy)
	if not (text and icon) or gcdProgress == 0 then return end
	if not wasSynergy and self.Progressbar.synergy.wasUsed then self.Progressbar.synergy.wasUsed = false end
	if CombatMetronome.SV.Progressbar.showSpell then
		self.Progressbar.spellLabel:SetHidden(false)
		self.Progressbar.spellIcon:SetHidden(false)
		self.Progressbar.spellIconBorder:SetHidden(false)
		self.Progressbar.spellIcon:SetTexture(icon)
		self.Progressbar.spellLabel:SetText(text)
	else
		self.Progressbar.spellLabel:SetHidden(true)
		self.Progressbar.spellIcon:SetHidden(true)
		self.Progressbar.spellIconBorder:SetHidden(true)
	end
	if CombatMetronome.SV.Progressbar.showTimeRemaining then
		self.Progressbar.timeLabel:SetHidden(false)
		self.Progressbar.timeLabel:SetText(string.format("%.1fs", gcdProgress))
	else
		self.Progressbar.timeLabel:SetHidden(true)
	end
end

function CombatMetronome:SetIconsAndNamesNil()
	if self.currentEvent then return end
	
	self.Progressbar.activeMount.action = ""
	self.Progressbar.collectibleInUse = nil
	self.Progressbar.itemUsed = nil
	self.Progressbar.festivalGCD = nil
	-- self.itemCache = nil
	-- self.Progressbar.killingAction = nil
	self.Progressbar.breakingFree = nil
	self.Progressbar.synergy.wasUsed = false
	-- self.Progressbar.nonAbilityGCDRunning = false
	self.Progressbar.timeLabel:SetHidden(true)
	self.Progressbar.spellLabel:SetHidden(true)
	self.Progressbar.spellIcon:SetHidden(true)
	self.Progressbar.spellIconBorder:SetHidden(true)
	
	-- if self.currentEvent and self.currentEvent.start and self.currentEvent.ability and self.currentEvent.start + math.max(self.currentEvent.ability.delay, 1000) + GRACE_PERIOD < GetFrameTimeMilliseconds() then
		-- self.currentEvent = nil
	-- end
end

	-----------------------
	---- Combat Events ----
	-----------------------

function CombatMetronome:CheckForCombatEventsRegister()
	-- local ccTrackingActive = CombatMetronome:CheckForCCRegister()
	if CombatMetronome.SV.Progressbar.trackMounting or CombatMetronome.SV.Progressbar.trackSynergies or CombatMetronome.SV.Progressbar.trackBreakingFree then
		return true
	end
	return false
end

-- function CombatMetronome:HandleCombatEvents(...)
    -- local e = Util.CombatEvent:New(...)

    -- if e:IsPlayerTarget() and not e:IsError() then
        -- local r = e:GetResult()
        -- if r == ACTION_RESULT_KNOCKBACK
        -- or r == ACTION_RESULT_PACIFIED
        -- or r == ACTION_RESULT_STAGGERED
        -- or r == ACTION_RESULT_STUNNED
        -- or r == ACTION_RESULT_INTERRUPT then
            -- self.currentEvent = nil
            -- return
        -- end
    -- end
-- end

	-------------------------
	---- Ability Adjusts ----
	-------------------------
local ABILITY_ADJUST_PLACEHOLDER = "Add ability adjust"

function CombatMetronome:UpdateAdjustChoices()
	local names = self.menu.abilityAdjustChoices

	for k in pairs(names) do names[k] = nil end

	for id, adj in pairs(CombatMetronome.SV.Progressbar.abilityAdjusts) do
		local name = "|t20:20:"..GetAbilityIcon(id).."|t "..Util.Text.CropZOSString(GetAbilityName(id), "ability")
		names[#names + 1] = name
	end

    if #names == 0 then
        names[1] = ABILITY_ADJUST_PLACEHOLDER
        self.menu.curSkillName = ABILITY_ADJUST_PLACEHOLDER
        self.menu.curSkillId = -1
    else
        if not CombatMetronome.SV.Progressbar.abilityAdjusts[self.menu.curSkillId] then
            for id, _ in pairs(CombatMetronome.SV.Progressbar.abilityAdjusts) do
                self.menu.curSkillId = id
                self.menu.curSkillName = GetAbilityName(id)
                break
            end
        end
    end

	local panelControls = self.menu.panels.Progressbar.controlsToRefresh
	for i = 1, #panelControls do
		local control = panelControls[i]
		if (control.data and control.data.name == "Select skill adjust") then
			control:UpdateChoices()
			control:UpdateValue()
			break
		end
	end
end

function CombatMetronome:CreateAdjustList()
	local names = {}
	for id, adj in pairs(CombatMetronome.SV.Progressbar.abilityAdjusts) do
		local name = "|t20:20:"..GetAbilityIcon(id).."|t "..Util.Text.CropZOSString(GetAbilityName(id), "ability")
		names[#names + 1] = name
	end
	if #names == 0 then table.insert(names, ABILITY_ADJUST_PLACEHOLDER) end
	return names
end

function CombatMetronome:CropIconFromSkill(ability)
    local _, iconDivider = string.find(ability, "%|t ")
    
    if iconDivider then
        return string.sub(ability, iconDivider + 1, -1)
    else
        return ability
    end
end

function CombatMetronome:FindSkillInAdjustList(name)
	for i, entry in ipairs(self.menu.abilityAdjustChoices) do
		if self:CropIconFromSkill(entry) == name then return i end
	end
end

function CombatMetronome:IsSkillCurrentlyEquipped(id)
	for i, entry in ipairs(self.currentlyEquippedAbilities.data) do
		if id == entry.id then return i end
	end
	return false
end

function CombatMetronome:GetEquippedSkillData(selectedSkill)
	for i, entry in ipairs(self.currentlyEquippedAbilities.list) do
		if entry == selectedSkill then
		-- self.debug:Print("Returning selected skill data")
		-- d(self.currentlyEquippedAbilities.data[i])
		return self.currentlyEquippedAbilities.data[i] end
	end
end

function CombatMetronome:BuildListOfCurrentlyEquippedAbilities()
	self.Resources.executeAbilityThreshold = 0
	
	self.currentlyEquippedAbilities.data = Util.Stacks:StoreAbilitiesOnActionBar()
	
	-- clear current list
	if self.currentlyEquippedAbilities.list then
		for i in pairs(self.currentlyEquippedAbilities.list) do self.currentlyEquippedAbilities.list[i] = nil end
	end
	
	if not self.currentlyEquippedAbilities.list then self.currentlyEquippedAbilities.list = {} end
	
	local executeAbilityFound = false
	self.StackTracker.slottedSkills = {}
	for i, skill in ipairs(self.currentlyEquippedAbilities.data) do
		self.currentlyEquippedAbilities.list[i] = tostring("|t20:20:"..skill.icon.."|t "..skill.name)
		
		-- SLOTTED Skills check
		-- for skill in pairs(self.StackTracker.slottedSkills) do
			-- self.StackTracker.slottedSkills[skill] = nil
		-- end
		
		if self.StackTracker.AVAILABLE_TRACKING_IDS[skill.id] then
			self.StackTracker.slottedSkills[self.StackTracker.AVAILABLE_TRACKING_IDS[skill.id]] = true
		end
		
		if self.StackTracker.availableSkills.Crux and not self.StackTracker.slottedSkills.Crux then
			for _, data in ipairs(self.currentlyEquippedAbilities.data) do
				if self.StackTracker.ABILITIES_USING_OR_GENERATING_CRUX[data.id] then
					self.StackTracker.slottedSkills.Crux = true
					break
				end
				self.StackTracker.slottedSkills.Crux = false
			end
		end
		
		-- EXECUTE check
		if self.Resources.EXECUTE_ABILITIES[skill.id] then
			-- CombatMetronome.debug:Print("Execute ability found, adjusting execute threshold")
			self.Resources.executeAbilityThreshold = math.max(self.Resources.EXECUTE_ABILITIES[skill.id], self.Resources.executeAbilityThreshold)
		end
		
	end
	self:CalculateExecuteThreshold()
	
	-- refresh equipped ability list
	local panelOptions = {
		Progressbar = "Currently equipped abilities:",
		General = "Add ability ID to debug whitelist",
	}
	
	for panel, option in pairs(panelOptions) do
		if self.menu.panels and self.menu.panels[panel] then
			local panelControls = self.menu.panels[panel].controlsToRefresh
			for i = 1, #panelControls do
				local control = panelControls[i]
				if (control.data and control.data.name == option) then
					-- CombatMetronome.debug:Print("Updating currently equipped skills")
					-- self.currentlyEquippedAbilities = self:BuildListOfCurrentlyEquippedAbilities()
					control:UpdateChoices()
					control:UpdateValue()
					break
				end
			end
		end
	end
end

function CombatMetronome:CalculateExecuteThreshold()
	self.Resources.executeThreshold = math.max(CombatMetronome.SV.Resources.showHealth and CombatMetronome.SV.Resources.hpHighlightThreshold or 0, self.Resources.executeAbilityThreshold)
end

	-------------------------
	---- Ability Handler ----
	-------------------------
-- function CombatMetronome:QueueTick(sound, timer, identifier, hardForce)
	-- local sv = self.SV.Progressbar
	
	-- zo_callLater(function()
			-- if self.inCombat or sv.playSoundsOOC then
				-- if hardForce then
					-- for i = 1, math.min(sv.tickVolume, 30) do
						-- PlaySound(sound)
					-- end
				-- elseif not self.identifiersToSkip[identifier] and self.currentEvent and self.currentEventIdentifier == identifier then
					-- for i = 1, math.min(sv.tickVolume, 30) do
						-- PlaySound(sound)
					-- end
				-- else
					-- if not self.identifiersToSkip then self.identifiersToSkip = {} end
					-- self.identifiersToSkip[identifier] = true
				-- end
			-- end
		-- end,
		-- timer		
	-- )
-- end

-- function CombatMetronome:QueueTock(sound, timer, identifier, hardForce)
	-- local sv = self.SV.Progressbar
	
	-- zo_callLater(function()
			-- if self.inCombat or sv.playSoundsOOC then
				-- if hardForce then
					-- for i = 1, math.min(sv.tickVolume, 30) do
						-- PlaySound(sound)
					-- end
				-- elseif not self.identifiersToSkip[identifier] and self.currentEventIdentifier == identifier or (sv.soundTockOffset > 0 and self.lastEventIdentifier == identifier) or (sv.forceSoundTock and self.lastEventIdentifier == identifier) then
					-- for i = 1, math.min(sv.tickVolume, 30) do
						-- PlaySound(sound)
					-- end
				-- end
			-- end
			-- if not hardForce and self.identifiersToSkip[identifier] then
				-- self.identifiersToSkip[identifier] = nil
			-- end
		-- end,
		-- timer		
	-- )
-- end

function CombatMetronome:HandleAbilityUsed(event)
	local sv = CombatMetronome.SV.Progressbar

    if not (self.inCombat or sv.showOOC) then return
	elseif sv.stopHATracking and event.ability.heavy then return	
	end
	
	if event.ability then Util.Ability.Tracker:PrintDebugNotes("abilityUsed", event.ability.id, string.format("New event '%s' recieved in CombatMetronome. ID: %d", event.ability.name, event.ability.id)) end
	
    local ability = event.ability

    event.adjust = (sv.abilityAdjusts[ability.id] or 0)
                    + ((ability.instant and sv.gcdAdjust)
                    or (ability.heavy and sv.globalHeavyAdjust)
                    or sv.globalAbilityAdjust)

	self.currentEvent = event
	-- self.lastEventIdentifier = self.currentEventIdentifier
	-- self.currentEventIdentifier = self.currentEventIdentifier + 1
	
	Util.Ability.Tracker:PrintDebugNotes("currentEvent", ability.id, string.format("Current event is now '%s'", ability.name))

	-- queue tick and tock sounds 
	if (sv.soundTickEnabled or sv.soundTockEnabled) and not (event.ability.heavy and sv.noTickOnHeavy) and not (sv.noSoundOnLongAbilities and event.ability.delay > 1000) then
		-- local duration = ability.heavy and ability.delay or math.max(ability.delay, 1000)
		-- if sv.soundTickEnabled then
			-- local timer = ((sv.forceTickMSBeforeEnd and (duration - sv.forceTickTime)) or (sv.soundTickMidAbility and duration/2) or 0) + event.adjust + sv.soundTickOffset
			-- self:QueueTick(sv.soundTickEffect, timer, self.currentEventIdentifier, false) end
		-- if sv.soundTockEnabled then
			-- local timer = duration + event.adjust + sv.soundTockOffset
			-- self:QueueTock(sv.soundTockEffect, timer, self.currentEventIdentifier, false)
		-- end
		if sv.soundTickEnabled then self.Progressbar.soundTickPlayed = false end
		if sv.soundTockEnabled then self.Progressbar.soundTockPlayed = false end
	end
	
	self.lastAbilityFinished = self.abilityFinished
	self.abilityFinished = event.start + (ability.heavy and ability.delay or math.max(ability.delay, 1000))
    self.gcd = Util.Ability.Tracker.gcd
end

	-------------------------------------------
	---- Check if Stack Tracker is active ----
	-------------------------------------------
function StackTracker:MorphCheck()
	if StackTracker.availableSkills.FS and StackTracker.availableSkills.GF then
		-- CombatMetronome.debug:Print("Updating morphs for GF and FS")
		Util.Stacks.morphs.GF = Util.Stacks:CheckMorph("GF")
		Util.Stacks.morphs.FS = Util.Stacks:CheckMorph("FS")
	elseif StackTracker.availableSkills.FS then
		-- CombatMetronome.debug:Print("Updating morphs for FS")
		Util.Stacks.morphs.FS = Util.Stacks:CheckMorph("FS")
		if Util.Stacks.morphs.GF then Util.Stacks.morphs.GF = nil end
	elseif StackTracker.availableSkills.GF then
		-- CombatMetronome.debug:Print("Updating morphs for GF")
		Util.Stacks.morphs.GF = Util.Stacks:CheckMorph("GF")
		if Util.Stacks.morphs.FS then Util.Stacks.morphs.FS = nil end
	else
		-- CombatMetronome.debug:Print("Deleting morphs for GF and FS")
		if Util.Stacks.morphs.GF then Util.Stacks.morphs.GF = nil end
		if Util.Stacks.morphs.FS then Util.Stacks.morphs.FS = nil end
	end
end

function StackTracker:TrackerIsActive(skill)
	if skill then
		-- if self.availableSkills[skill] and self:CheckIfSlotted(skill) and CombatMetronome.SV.StackTracker[skill].tracked then
		if self.availableSkills[skill] and self.slottedSkills[skill] and CombatMetronome.SV.StackTracker[skill].tracked then
			return true
		end
		return false
	else
		for skill, _ in pairs(self.SKILL_ATTRIBUTES) do
			-- if self.availableSkills[skill] and self:CheckIfSlotted(skill) and CombatMetronome.SV.StackTracker[skill].tracked then
			if self.availableSkills[skill] and self.slottedSkills[skill] and CombatMetronome.SV.StackTracker[skill].tracked then
				return true
			end
		end
		return false
	end
end

		---------------------------------------
        ---- Store abilities on Actionbars ----
        ---------------------------------------

-- function CombatMetronome:StoreAbilitiesOnActionBar()
    -- local actionSlots = {}  -- Create a table to store action slots

    -- for j = 0, 1 do
        -- for i = 3, 8 do
            -- local actionSlot = {}  -- Create a new table for each action slot
			-- local slotType = GetSlotType(i, j)
            -- setmetatable(actionSlot, {__index = index})
            
            -- actionSlot.place = tostring(i .. j)
			-- if slotType == ACTION_TYPE_CRAFTED_ABILITY then
				-- actionSlot.id = GetAbilityIdForCraftedAbilityId(GetSlotBoundId(i, j))
			-- else
				-- actionSlot.id = GetSlotBoundId(i, j)
			-- end
            -- actionSlot.icon = GetAbilityIcon(actionSlot.id)
            -- actionSlot.name = Util.Text.CropZOSString(GetAbilityName(actionSlot.id), "ability")

            -- table.insert(actionSlots, actionSlot)  -- Add the current action slot to the table
        -- end
    -- end

    -- return actionSlots
-- end

		------------------------------------------------
        ---- Tracker check if abilities are slotted ----
        ------------------------------------------------

function StackTracker:CheckIfRegistered(skill)
	-- if skill == "FS" and self.hotbarUpdateRegistered then
		-- return true
	-- else
		for _, aName in pairs(self.trackedIds) do
			if skill == aName then
				return true
			end
		end
	-- end
	return false
end

function StackTracker:GetCurrentStacks(skill)
	local stacks
	-- if self:CheckIfSlotted(skill) then
	if self.slottedSkills[skill] then
		stacks = Util.Stacks:GetCurrentNumStacksOnPlayer(skill)
		return stacks
	end
	return 0
end

function StackTracker:IsTrackingAvailable()
	for skill, entry in pairs(self.SKILL_ATTRIBUTES) do
		for _, id in ipairs(entry.skillLineId) do
			local _,_,isAvailable,_,_,_ = GetSkillLineDynamicInfo(GetSkillLineIndicesFromSkillLineId(id))
			self.availableSkills[skill] = isAvailable
			if isAvailable then break end
		end
	end
		-- Build list of possibly trackable ids
	for i in pairs(self.AVAILABLE_TRACKING_IDS) do
		self.AVAILABLE_TRACKING_IDS[i] = nil
	end
	for skill in pairs(self.availableSkills) do
		if self.availableSkills[skill] then
			for id, ability in pairs(self.ALL_IDS) do
				if skill == ability then self.AVAILABLE_TRACKING_IDS[id] = skill end
			end
		end
	end		
end

function StackTracker:AbilityUpdater()
	StackTracker:IsTrackingAvailable()
	StackTracker:MorphCheck()
	CombatMetronome:BuildListOfCurrentlyEquippedAbilities()
	-- StackTracker.actionSlotCache = CombatMetronome.currentlyEquippedAbilities.data
	
	for skill, _ in pairs(StackTracker.SKILL_ATTRIBUTES) do
		if CombatMetronome.SV.StackTracker[skill].tracked then
			-- if StackTracker.availableSkills[skill] and StackTracker:CheckIfSlotted(skill) then
			if StackTracker.availableSkills[skill] and StackTracker.slottedSkills[skill] then
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("Trying to register "..skill) end
				StackTracker:Register(skill)
			-- elseif not StackTracker:CheckIfSlotted(skill) and StackTracker:CheckIfRegistered(skill) then
			elseif not StackTracker.slottedSkills[skill] and StackTracker:CheckIfRegistered(skill) then
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("Trying to unregister "..skill) end
				StackTracker:Unregister(skill)
			end
		end
	end
	-- CombatMetronome.debug:Print("Abilities updated at: "..GetFrameTimeMilliseconds())
end

function StackTracker:InitializeUI(skill)
	if not self.UI[skill] then
		self.UI[skill] = self:BuildUI(skill)
		-- self.UI[skill].indicator.ApplyDistance(CombatMetronome.SV.StackTracker[skill].indicatorSize/5, CombatMetronome.SV.StackTracker[skill].indicatorSize)
		self.UI[skill].indicator.ApplySize(CombatMetronome.SV.StackTracker[skill].indicatorSize)
		self.UI[skill].indicator.ApplyIcon()
		self.UI[skill].stacksWindow:SetMovable(CombatMetronome.SV.StackTracker.isUnlocked)
	end
	self:HandleUIVisibility(skill, "UI")
	self:UpdateTimers()
	if CombatMetronome.SV.StackTracker.isUnlocked then self:HandleUIVisibility(skill, "Sample") end
end

function StackTracker:HandleUIVisibility(skill, scene)
	if StackTracker.UI[skill] then
		StackTracker.UI[skill].FadeScenes(scene)
		-- if scene == "NoUI" or scene == "NoSample" then
			-- StackTracker.UI[skill].stacksWindow:SetHidden(true)
		-- elseif scene == "Sample" or scene == "UI" then
			-- StackTracker.UI[skill].stacksWindow:SetHidden(false)
		-- end
	end
end

function StackTracker:HideTracker(skill, value)
	if self.UI[skill] then
		self.UI[skill].Hide(value)
	end
	self:UpdateTimers()
end

		-------------------------------
        ---- PVP Check and Handler ----
        -------------------------------

function CombatMetronome:IsInPvPZone()
	if IsActiveWorldBattleground() or IsPlayerInAvAWorld() then
		self.inPVPZone = true
	else
		self.inPVPZone = false
	end
	-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print(self.inPVPZone) end
	return self.inPVPZone
end

function CombatMetronome:CMPVPSwitch()
	if not CombatMetronome.SV.Progressbar.hide then
		if CombatMetronome.SV.Progressbar.hideCMInPVP and self.inPVPZone then
			if self.cmRegistered then
				self:UnregisterCM()
				self:HideBar(true)
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("registered cm scenario 1") end
			elseif not self.cmRegistered then
				self:HideBar(true)
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("registered cm scenario 2") end
			end
		else 
			if not self.cmRegistered then
				self:RegisterCM()
				self:HideBar(not CombatMetronome.SV.Progressbar.dontHide)
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("registered cm scenario 3") end
			else
				self:HideBar(not CombatMetronome.SV.Progressbar.dontHide)
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("registered cm scenario 4") end
			end
		end
	end
end

function CombatMetronome:ResourcesPVPSwitch()
	-- local hideResources = false
	if CombatMetronome.SV.Resources.hideInPVP and self.inPVPZone then
		-- hideResources = true
		if self.rtRegistered then
			self:UnregisterResourceTracker()
			self.Resources.stamLabel:SetHidden(true)
            self.Resources.magLabel:SetHidden(true)
            self.Resources.hpLabel:SetHidden(true)    
            self.Resources.ultLabel:SetHidden(true)
		elseif not self.rtRegistered then
			self.Resources.stamLabel:SetHidden(true)
            self.Resources.magLabel:SetHidden(true)
            self.Resources.hpLabel:SetHidden(true)    
            self.Resources.ultLabel:SetHidden(true)
		end
	else
		if not self.rtRegistered then
			self:RegisterResourceTracker()
		end
		-- hideResources = false
	end
	-- return hideResources
end

function StackTracker:PVPSwitch(skill)
	if self:TrackerIsActive(skill) and self.UI[skill] then
		local registered = self:CheckIfRegistered(skill)
		if CombatMetronome.SV.StackTracker[skill].hideInPVP and CombatMetronome.inPVPZone then
			if registered then
				self:Unregister(skill)
				-- self.UI[skill].FadeScenes("NoUI")
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("registered tracker scenario 1") end
			else
				self.UI[skill].FadeScenes("NoUi")
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("registered tracker scenario 2") end
			end
		else
			if not registered then
				self:Register(skill)
				-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("registered tracker scenario 3") end
			end
		end
	elseif self:TrackerIsActive(skill) and not self.UI[skill] and not CombatMetronome.inPVPZone then
		-- self:InitializeUI(skill)
		self:Register(skill)
	end
end

		--------------
        ---- Menu ----
        --------------
		
local MENU_SOUND_CONTROLS = {
["Volume of 'tick' and 'tock'"] = true,
["Sound 'tick'"] = true,
["Sound 'tock'"] = true,
["Sound 'tick' effect"] = true,
["Sound 'tock' effect"] = true,
["Sound 'tick' offset"] = true,
["Sound 'tock' offset"] = true,
["Play 'tick' at the start of an ability"] = true,
["Don't play 'tick' on heavy attacks"] = true,
["Play sounds ooc"] = true,
}

function CombatMetronome:RefreshSoundControls()
	-- if not self.menu.soundControlsToRefresh then self.menu.soundControlsToRefresh = {} end
	-- if #self.menu.soundControlsToRefresh == 0 then
		-- if self.menu.panel then
			-- local num = 0
			-- for _,_ in pairs(MENU_SOUND_CONTROLS) do
				-- num = num + 1
			-- end
			-- local updateCount = 0
			-- local panelControls = self.menu.panel.controlsToRefresh
			-- for i, control in ipairs(panelControls) do
				-- if control.data and MENU_SOUND_CONTROLS[control.data.name] then
					-- if control.UpdateValue then control:UpdateValue() end
					-- if control.UpdateDisabled then control:UpdateDisabled() end
					-- updateCount = updateCount + 1
					-- self.menu.soundControlsToRefresh[updateCount] = i				
				-- end
				-- if updateCount == num then break end -- number of 
			-- end
		-- end
	-- else
		-- CombatMetronome.debug:Print("Second wind")
		-- for _, i in ipairs(self.menu.soundControlsToRefresh) do
			-- if self.menu.panel.controlsToRefresh[i].UpdateValue then self.menu.panel.controlsToRefresh[i]:UpdateValue() end
			-- if self.menu.panel.controlsToRefresh[i].UpdateDisabled then self.menu.panel.controlsToRefresh[i]:UpdateDisabled() end
		-- end
	-- end
	CombatMetronome.menu.panels.Progressbar:RefreshPanel()
end

		-----------------------------
        ---- CoralBahseiTracking ----
        -----------------------------

function CombatMetronome:UpdateCoralBahsei(setId, changeType, unitTag, localPlayer, activeType)
	if setId == 647 then
		self.Resources.coralActive = self.LSD.ConvertActiveType(activeType)
	elseif setId == 147 then
		self.Resources.mkActive = self.LSD.ConvertActiveType(activeType)
	elseif setId == 587 then
		self.Resources.bahseiActive = self.LSD.ConvertActiveType(activeType)
	elseif not setId then
		self.Resources.mkActive = self.LSD.ConvertActiveType(self.LSD.GetUnitSetActiveType("player", 147))
		self.Resources.coralActive = self.LSD.ConvertActiveType(self.LSD.GetUnitSetActiveType("player", 647))
		self.Resources.bahseiActive = self.LSD.ConvertActiveType(self.LSD.GetUnitSetActiveType("player", 587))
	end
	self.Progressbar.UI.Anchors()
end

		---------------
        ---- Debug ----
        ---------------
		
function CombatMetronome:SetAllDebugFalse()
	for entry, bool in pairs(CombatMetronome.SV.debug) do
		CombatMetronome.SV.debug[entry] = false
	end
	CombatMetronome.SV.debug.triggerTimer = 170
end

function CombatMetronome:AutomaticSVCleanup()
	local year, month, day = GetDateElementsFromTimestamp(GetTimeStamp())
	if CombatMetronome.SV.automaticSVCleanup.lastCleanup.year == year or (CombatMetronome.SV.automaticSVCleanup.lastCleanup.year == year - 1 and CombatMetronome.SV.automaticSVCleanup.lastCleanup.month < month) then
		CombatMetronome.debug:Print("No SV cleanup necessary. Last SV cleanup has taken place less than a year ago on "..CombatMetronome.SV.lastSVCleanup.lastCleanup.day.."-"..CombatMetronome.SV.lastSVCleanup.lastCleanup.month.."-"..CombatMetronome.SV.lastSVCleanup.lastCleanup.year)
	elseif CombatMetronome.SV.automaticSVCleanup.lastCleanup.year == 0 then
		CombatMetronome.debug:Print("No SV cleanup has taken place yet. Starting automatic cleanup.")
		self:CleanupSVEntries()
	elseif year > CombatMetronome.SV.automaticSVCleanup.lastCleanup.year and month >= CombatMetronome.SV.lastSVCleanup.lastCleanup.month then
		CombatMetronome.SV.lastSVCleanup = {["year"] = year, ["month"] = month, ["day"] = day}
		CombatMetronome.debug:Print("Last SV cleanup was about a year ago. Starting automatic cleanup.")
		self:CleanupSVEntries()
	end
end

function CombatMetronome:CleanupSVEntries()
	for _, vars in pairs(CombatMetronomeSavedVars.Default[GetDisplayName()]) do
		for section, subsection in pairs(vars) do
			local sectionNeedsClearing = true
			for entry, _ in pairs(CombatMetronome.DEFAULT_SAVED_VARS) do
				if entry == section then
					sectionNeedsClearing = false
					break
				end
			end
			if sectionNeedsClearing then
				vars[section] = nil
				CombatMetronome.debug:Print("saved vars cleanup - cleaning section: |c2a52be"..section.."|r")
			elseif type(subsection) == "table" then
				for name, _ in pairs(subsection) do
					local needsToBeCleaned = true
					for entry, _ in pairs(CombatMetronome.DEFAULT_SAVED_VARS[section]) do
						if name == entry then
							needsToBeCleaned = false
							break
						end
					end
					if needsToBeCleaned then
						subsection[name] = nil
						CombatMetronome.debug:Print("saved vars cleanup - cleaning option/table: |c2a52be"..section.."|r - |ce11212"..name.."|r")
					end
				end
			end
		end
	end
end

function CombatMetronome:PrintDebug(debugType, message)
	local debugs = CombatMetronome.SV.debug
							 -- spam prevent
    if debugs[debugType] and self.lastDebugMessage ~= message then
	
		self.lastDebugMessage = message
		local formatedMessage = tostring(message)
		
        if debugs.printTimestamps then
            local time = GetFrameTimeMilliseconds()
            formatedMessage = string.format("%d --> %s", time, message)
        end
        CombatMetronome.debug:Print(formatedMessage)
    end
end

	-----------------------
	---- Notifications ----
	-----------------------

local function RemoveNotification(provider, identifier)
	local notifications = provider.notifications
	for i = #notifications, 1, -1 do
		if notifications[i].heading == identifier then
			table.remove(notifications, i)
			provider:UpdateNotifications()
			break
		end
	end
end

local function BetaNotification(provider)
	local identifier = "CombatMetronome Beta User"
	local function accept()
		CombatMetronome.SV.showBetaMessage = false
		RemoveNotification(provider, identifier) 
	end

	local msg = {
	dataType = NOTIFICATIONS_REQUEST_DATA,
	secsSinceRequest = ZO_NormalizeSecondsSince(0),
	note = "If you encounter any unwanted 'features' pls report them in the ESOUI 'Comment' section (You can find the link in the menu metadata).\nAccepting this message will disable it.",
	message = "You are currently using CombatMetronome's beta version",
	heading = identifier,
	texture = "/esoui/art/miscellaneous/eso_icon_warning.dds",
	shortDisplayText = "CombatMetronome beta warning",
	controlsOwnSounds = false,
	keyboardAcceptCallback = accept,
    keyboardDeclineCallback = function() RemoveNotification(provider, identifier) end,
    gamepadAcceptCallback = accept,
    gamepadDeclineCallback = function() RemoveNotification(provider, identifier) end,
	data = {}, -- Place any custom data you want to store here
    }
	
	-- CombatMetronome.debug:Print("You're currently using CombatMetronome's beta version")
	
	return msg
end

local function NewVersionAlert(provider)
	local identifier = "CombatMetronome version update"
	local function decline()
		CombatMetronome.SV.lastAddOnVersion = CombatMetronome.versionCheck
		RemoveNotification(provider, identifier)
	end
	
	local msg = {
	dataType = NOTIFICATIONS_ALERT_DATA,
	secsSinceRequest = ZO_NormalizeSecondsSince(0),
	note = "Your new version is: "..CombatMetronome.versionCheck.."\nSometimes due to updates some values in your saved vars have been reset and you need to adjust your options. I apologize for the inconvenience.",
	message = "You are now using CombatMetronome version "..CombatMetronome.versionCheck.."\nCheck the changelog for new features. Dismiss to disable this message.",
	heading = identifier,
	texture = "/esoui/art/journal/u26_progress_digsite_checked_complete.dds",
	shortDisplayText = "CombatMetronome updated",
	controlsOwnSounds = false,
	keyboardAcceptCallback = function() RemoveNotification(provider, identifier) end,
	keyboardDeclineCallback = decline,
	gamepadAcceptCallback = function() RemoveNotification(provider, identifier) end,
	gamepadDeclineCallback = decline,
	data = {}, -- Place any custom data you want to store here
    }
	
	if CombatMetronome.versionString == "1.7.5" then
		msg.note = "Your new version is: "..CombatMetronome.versionCheck.."\nThe Tick/Tock volume settings have been changed. Please check the sound settings. I apologize for the inconvenience."
	end
	
	-- CombatMetronome.debug:Print("New Version was detected. Current version: "..tostring(CombatMetronome.versionCheck))
	
	return msg
end

function CombatMetronome:CreateNotifications()
	local provider = self.msg:CreateProvider()
	local msg
	
	if self.beta and self.SV.showBetaMessage then
		msg = BetaNotification(provider)
		table.insert(provider.notifications, msg)
	end
	
	if self.versionCheck ~= self.SV.lastAddOnVersion then
		msg = NewVersionAlert(provider)
		table.insert(provider.notifications, msg)
	end
	
	provider:UpdateNotifications()
end