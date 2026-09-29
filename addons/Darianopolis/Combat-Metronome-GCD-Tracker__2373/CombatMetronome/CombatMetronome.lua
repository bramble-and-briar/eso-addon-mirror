-- local Util = DAL:Use("DariansUtilities", 6)
-- CombatMetronome = DAL:Def("CombatMetronome", 4, 1, {
--     onLoad = function(self) self:Init() end,
-- })

local beta = false

CombatMetronome = {
    name = "CombatMetronome",
    version = {
		["patch"] = 1,
		["major"] = 7,
		["minor"] = 7,
	},
	API = GetAPIVersion(),
	beta = beta,
}

CombatMetronome.versionString = string.format("%s.%s.%s", CombatMetronome.version.patch, CombatMetronome.version.major, CombatMetronome.version.minor)
CombatMetronome.versionCheck = tonumber(string.format("%s%02d%02d", CombatMetronome.version.patch, CombatMetronome.version.major, CombatMetronome.version.minor))

local Util = DariansUtilities
Util.Ability = Util.Ability or {}
Util.Text = Util.Text or {}
Util.Stacks = Util.Stacks or {}
CombatMetronome.StackTracker = CombatMetronome.StackTracker or {}
local StackTracker = CombatMetronome.StackTracker
StackTracker.name = CombatMetronome.name.."StackTracker"
CombatMetronome.LATracker = CombatMetronome.LATracker or {}
local LATracker = CombatMetronome.LATracker
LATracker.name = CombatMetronome.name.."LightAttackTracker"

Util.onLoad(CombatMetronome, function(self) self:Init() end)

ZO_CreateStringId("SI_BINDING_NAME_COMBATMETRONOME_FORCE", "Force display")
ZO_CreateStringId("SI_BINDING_NAME_COMBATMETRONOME_TOGGLE_SOUND_CUES", "Toggle metronome sound cues")
ZO_CreateStringId("SI_BINDING_NAME_COMBATMETRONOME_TOGGLE_TICK", "Toggle 'tick'")
ZO_CreateStringId("SI_BINDING_NAME_COMBATMETRONOME_TOGGLE_TOCK", "Toggle 'tock'")

	-------------------------------------
	---- Initialize Combat Metronome ----
	-------------------------------------

function CombatMetronome:Init()

	self:CheckSavedVariables()
	
	self.SV = ZO_SavedVars:NewCharacterIdSettings("CombatMetronomeSavedVars", 2, nil, self.DEFAULT_SAVED_VARS)
	if self.SV.global then
		self.SV = ZO_SavedVars:NewAccountWide("CombatMetronomeSavedVars", 2, nil, self.DEFAULT_SAVED_VARS)
		self.SV.global = true
	end
	
	self.debug = LibChatMessage("|ce11212C|rombat |ce11212M|retronome", "|ce11212CM|r")
	self.debug:SetEnabled(true)
	
	self.msg = LibNotification
	
	if self.SV.automaticSVCleanup.enabled then
		self:AutomaticSVCleanup()
	end
		
	if LibSetDetection and LibSetDetection.RegisterEvent then
		self.LSD = LibSetDetection
	else
		self.SV.Resources.coralBahsei = false
	end
	
	self.currentCharacterName = Util.Text.CropZOSString(GetUnitName("player"), "name")
	self.currentlyEquippedAbilities = {}
	-- StackTracker.slottedSkills = {}
	-- CombatMetronome:BuildListOfCurrentlyEquippedAbilities()
		
	StackTracker.classId = GetUnitClassId("player")
	StackTracker.class = StackTracker.CLASS[StackTracker.classId]

    self.inCombat = IsUnitInCombat("player")
    self.currentEvent = nil
	self.gcdEvent = {finished = 0}
	
	-- self.currentEventIdentifier = 0
	-- self.lastEventIdentifier = 0
	-- self.identifiersToSkip = {}

    self.gcd = 1000

	self.Progressbar = {}
	self.Progressbar.activeMount = {}
	self.Progressbar.activeMount.name = Util.Text.CropZOSString(GetCollectibleNickname(GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT,GAMEPLAY_ACTOR_CATEGORY_PLAYER)), "collectible")
	self.Progressbar.activeMount.icon = GetCollectibleIcon(GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT,GAMEPLAY_ACTOR_CATEGORY_PLAYER))
	self.Progressbar.activeMount.action = ""
	self.Progressbar.itemUsed = nil
	self.Progressbar.collectibleInUse = nil
	self.Progressbar.synergy = {}
    self.Progressbar.UI = self:BuildUI()
	
	
	-- to prevent triggering on initial load
	self.Progressbar.soundTickPlayed = true
	self.Progressbar.soundTockPlayed = true
	self.lastAbilityFinished = 0
	self.abilityFinished = 0
	
	Util.Ability.Tracker.CombatMetronome = self
    Util.Ability.Tracker:Start()
	
	-----------------------
	---- Stack Tracker ----
	-----------------------
	
	StackTracker.availableSkills = {}
	StackTracker.AVAILABLE_TRACKING_IDS = {}
	StackTracker.slottedSkills = {}
	StackTracker:IsTrackingAvailable()
	
	StackTracker:MorphCheck()
	
	StackTracker.trackedIds = {}
	StackTracker.stacks = {}
	StackTracker.UI = {}
	
	------------------------------
	---- Light Attack Tracker ----
	------------------------------
	
	LATracker:BuildUI()
	LATracker.frame:SetUnlocked(CombatMetronome.SV.LATracker.isUnlocked)
	
	--------------
	-- Metadata --
	--------------
	
	self:BuildListOfCurrentlyEquippedAbilities()
    self:BuildMenu()
	self:RegisterMetadata()
	
	if self.versionCheck ~= self.SV.lastAddOnVersion then self.SV.showBetaMessage = true end
	self:CreateNotifications()
end

-- LOAD HOOK

-- EVENT_MANAGER:RegisterForEvent(CombatMetronome.name.."Load", EVENT_ADD_ON_LOADED, function(...)
--     if (CombatMetronome.loaded) then return end
--     CombatMetronome.loaded = true

--     CombatMetronome:Init()
-- end)

	-----------------------------
	---- Register/Unregister ----
	-----------------------------

function CombatMetronome:RegisterMetadata()
	-- EVENT_MANAGER:RegisterForEvent(
        -- self.name.."CurrentActionslotsOnHotbar",
        -- EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,
        -- function()
			-- CombatMetronome:BuildListOfCurrentlyEquippedAbilities()
			-- StackTracker.actionSlotCache = self.currentlyEquippedAbilities.data
			-- StackTracker:IsTrackingAvailable()
			-- if self.isRespec then
				-- StackTracker:MorphCheck()
				-- self.isRespec = false
			-- end
			-- for skill, _ in pairs(StackTracker.SKILL_ATTRIBUTES) do
				-- if CombatMetronome.SV.StackTracker[skill].tracked then
					-- if StackTracker.availableSkills[skill] and StackTracker:CheckIfSlotted(skill) then
					-- if StackTracker.availableSkills[skill] and StackTracker.slottedSkills[skill] then
						-- StackTracker:Register(skill)
					-- elseif not StackTracker:CheckIfSlotted(skill) and StackTracker:CheckIfRegistered(skill) then
					-- elseif not StackTracker.slottedSkills[skill] and StackTracker:CheckIfRegistered(skill) then
						-- StackTracker:Unregister(skill)
					-- end
				-- end
			-- end
        -- end
    -- )
	
	EVENT_MANAGER:RegisterForEvent(
        self.name.."ArmoryBuildRestore",
        EVENT_ARMORY_BUILD_RESTORE_RESPONSE,
        function(_, result, _)
			-- callLater needed, since the abilities are only updated after the event fired
			zo_callLater(function() StackTracker:AbilityUpdater() end, 10)
		end
    )
	
	EVENT_MANAGER:RegisterForEvent(
        self.name.."RespecResult",
        EVENT_SKILL_RESPEC_RESULT,
        function(_, result)
			-- if (result ~= RESPEC_RESULT_SUCCESS) then
				-- return
			-- end
			-- self.isRespec = true
			StackTracker:AbilityUpdater()
        end
    )
	
	EVENT_MANAGER:RegisterForEvent(
		self.name.."CharacterLoaded",
		EVENT_PLAYER_ACTIVATED,
		function(_,_)
			self.inPVPZone = self:IsInPvPZone()
			self:CMPVPSwitch()
			self:ResourcesPVPSwitch()
			self.LATracker:DisplayText()
			for skill, _ in pairs(CombatMetronome.StackTracker.SKILL_ATTRIBUTES) do	
				StackTracker:PVPSwitch(skill)
			end
			
			-- Get current stack count if you left an instance
			for skill, _ in pairs(StackTracker.availableSkills) do
				-- if StackTracker.availableSkills[skill] and StackTracker:CheckIfSlotted(skill) and CombatMetronome.SV.StackTracker[skill].tracked then
				if StackTracker.availableSkills[skill] and StackTracker.slottedSkills[skill] and CombatMetronome.SV.StackTracker[skill].tracked then
					StackTracker.stacks[skill] = StackTracker:GetCurrentStacks(skill)
					StackTracker:ChangeStackCount(skill, StackTracker.stacks[skill])
				end
			end
		end
	)
	
	-- EVENT_MANAGER:RegisterForEvent(
		-- self.name.."ModelRebuilt",
		-- EVENT_LOCAL_PLAYER_MODEL_REBUILT,
		-- function()
			-- Get current stack count if you left an instance
			-- for skill, _ in pairs(StackTracker.availableSkills) do
				-- if StackTracker.availableSkills[skill] and StackTracker:CheckIfSlotted(skill) and CombatMetronome.SV.StackTracker[skill].tracked then
				-- if StackTracker.availableSkills[skill] and StackTracker.slottedSkills[skill] and CombatMetronome.SV.StackTracker[skill].tracked then
					-- StackTracker.stacks[skill] = StackTracker:GetCurrentStacks(skill)
					-- StackTracker:ChangeStackCount(skill, StackTracker.stacks[skill])
				-- end
			-- end
		-- end
	-- )

    EVENT_MANAGER:RegisterForEvent(
        self.name.."CombatStateChange",
        EVENT_PLAYER_COMBAT_STATE,
        function(_, inCombat) 
            self.inCombat = inCombat == true
			LATracker:ManageLATracker(inCombat)
			if self.SV.StackTracker.onlyInCombat and not inCombat then
				for skill, _ in pairs(StackTracker.availableSkills) do
					StackTracker:HideTracker(skill, StackTracker.stacks[skill] == 0)
				end
			else
				for skill, _ in pairs(StackTracker.availableSkills) do
					StackTracker:HideTracker(skill, false)
				end
			end
        end
    )		
end

function CombatMetronome:RegisterCM()
	EVENT_MANAGER:RegisterForUpdate(
        self.name.."Update",
        1000 / 60,
        function(...) CombatMetronome:Update() end
    )
    	
	self.cmRegistered = true
	
	if CombatMetronome.SV.Progressbar.trackGCD and (CombatMetronome.SV.Progressbar.trackCollectibles or (CombatMetronome.SV.Progressbar.showMountNick and CombatMetronome.SV.Progressbar.trackMounting)) then
		CombatMetronome:RegisterCollectiblesTracker()
	end
	
	if CombatMetronome.SV.Progressbar.trackGCD and CombatMetronome.SV.Progressbar.trackItems then
		CombatMetronome:RegisterItemsTracker()
	end
	
	if CombatMetronome.SV.Progressbar.trackGCD and CombatMetronome:CheckForCombatEventsRegister() then
		CombatMetronome:RegisterCombatEvents()
	end
	
	if CombatMetronome.SV.Progressbar.trackGCD and CombatMetronome.SV.Progressbar.trackSynergies then
		CombatMetronome:RegisterSynergyChanged()
	end
	-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("cm is registered") end
end

function CombatMetronome:RegisterCollectiblesTracker()
	EVENT_MANAGER:RegisterForEvent(
		self.name.."CollectibleUsed",
		EVENT_COLLECTIBLE_UPDATED,
		function(_, id)
			if CombatMetronome.SV.Progressbar.trackGCD then
				local name,_,icon,_,_,_,_,type,_ = GetCollectibleInfo(id)
				if type == COLLECTIBLE_CATEGORY_TYPE_ASSISTANT or type == COLLECTIBLE_CATEGORY_TYPE_COMPANION and self.gcdEvent.finished <= GetFrameTimeMilliseconds() then
					CombatMetronome:SetIconsAndNamesNil()
					self.Progressbar.collectibleInUse = {}
					self.Progressbar.collectibleInUse.name = Util.Text.CropZOSString(name, "collectible")
					self.Progressbar.collectibleInUse.icon = icon
				end
				if type == COLLECTIBLE_CATEGORY_TYPE_MOUNT then
					self.Progressbar.activeMount.name = Util.Text.CropZOSString(GetCollectibleNickname(id), "collectible")
					self.Progressbar.activeMount.icon = icon
					if CombatMetronome.menu.icons[2] then
						CombatMetronome.menu.icons[2]:SetTexture(icon)
					end
				end
			end
		end
	)
	
	self.collectiblesTrackerRegistered = true
end

function CombatMetronome:RegisterItemsTracker()
	EVENT_MANAGER:RegisterForEvent(
		self.name.."InventoryItemUsed",
		EVENT_INVENTORY_ITEM_USED,
		function()
			if CombatMetronome.SV.Progressbar.trackGCD and self.gcdEvent.finished <= GetFrameTimeMilliseconds() then
				local bagSize = GetBagSize(1)
				CombatMetronome:SetIconsAndNamesNil()
				self.itemCache = {}
				self.itemCache.name = {}
				self.itemCache.icon = {}
				for i = 1, bagSize do
					self.itemCache.name[i] = Util.Text.CropZOSString(GetItemName(1, i), "item")
					self.itemCache.icon[i] = GetItemInfo(1, i)
				end
			end
		end
	)

	EVENT_MANAGER:RegisterForEvent(
		self.name.."InventoryItemInfo",
		EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
		function(_, bagId, slotId, _, _, _, stackCountChange, _, _, _, _)
			if CombatMetronome.SV.Progressbar.trackGCD and self.gcdEvent.finished <= GetFrameTimeMilliseconds() then
				if not self.Progressbar.synergy.wasUsed and stackCountChange == -1 and self.itemCache then
					CombatMetronome:SetIconsAndNamesNil()
					self.Progressbar.itemUsed = {
						["name"] = self.itemCache.name[slotId],
						["icon"] = self.itemCache.icon[slotId]
					}
					self.itemCache = nil
					-- zo_callLater(function()
						-- if self.Progressbar.itemUsed then
							-- self.Progressbar.itemUsed = nil
							-- self.itemCache = nil
						-- end
					-- end,
					-- 950)
				end
			end
		end
	)
	
	self.itemTrackerRegistered = true
end

function CombatMetronome:RegisterCombatEvents()
	EVENT_MANAGER:RegisterForEvent(
		self.name.."CombatEvents",
		EVENT_COMBAT_EVENT,
--	------------------------------
--  ---- Handle Combat Events ----
--	------------------------------
		function (_,   res,  err, aName, aGraphic, aSlotType, sName, sType, tName, 
				tType, hVal, pType, dType, _, 		sUId, 	 tUId,  aId,   _     )
			if CombatMetronome.SV.Progressbar.trackGCD and self.gcdEvent.finished <= GetFrameTimeMilliseconds() then
				aName = Util.Text.CropZOSString(aName, "ability")
				if aId == 16565 then
					-- Util.Ability.Tracker:CancelCurrentEvent("Break free detected")
					CombatMetronome:SetIconsAndNamesNil()
					self.Progressbar.breakingFree = {}
					self.Progressbar.breakingFree.name = aName
					self.Progressbar.breakingFree.icon = "/esoui/art/icons/ability_rogue_050.dds"
				elseif not self.Progressbar.synergy.wasUsed and self.Progressbar.synergy.name == Util.Text.CropZOSString(aName, "synergy") then
					self.Progressbar.synergy.wasUsed = true
				-- none of these should be shown during combat, or during an active event
				elseif self.currentEvent or self.inCombat then return
				-- elseif IsMounted() and aId == 36432 then
				elseif res == ACTION_RESULT_EFFECT_GAINED and aId == 36432 then
					CombatMetronome:SetIconsAndNamesNil()
					self.Progressbar.activeMount.action = aName
				-- elseif not IsMounted() and aId == 36010 then
				elseif res == ACTION_RESULT_BEGIN and aId == 37059 then
					CombatMetronome:SetIconsAndNamesNil()
					self.Progressbar.activeMount.action = aName
				-- elseif res == ACTION_RESULT_BAD_TARGET and err and aId == 37059 then
					-- CombatMetronome:SetIconsAndNamesNil()
					-- self.Progressbar.activeMount.action = aName
				elseif CombatMetronome.FESTIVAL_IDS[aId] then
					CombatMetronome:SetIconsAndNamesNil()
					self.Progressbar.festivalGCD = aId
				end
			end
		end
	)
	EVENT_MANAGER:AddFilterForEvent(
		self.name.."CombatEvents",
		EVENT_COMBAT_EVENT,
		REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,
		COMBAT_UNIT_TYPE_PLAYER
	)
	
	self.combatEventsRegistered = true
end

function CombatMetronome:RegisterSynergyChanged()
	EVENT_MANAGER:RegisterForEvent(
		self.name.."SynergyChanged",
		EVENT_SYNERGY_ABILITY_CHANGED,
		function()
			if CombatMetronome.SV.Progressbar.trackGCD and self.gcdEvent.finished <= GetFrameTimeMilliseconds() then
				local hasSynergy, name, icon, _, _ = GetCurrentSynergyInfo()
				if hasSynergy then
					-- if CombatMetronome.SV.debug.enabled then self.debug:Print("Found synergy: "..Util.Text.CropZOSString(name, "synergy")) end
					self.Progressbar.synergy.name = Util.Text.CropZOSString(name, "synergy")
					self.Progressbar.synergy.icon = icon
				-- else
					-- self.Progressbar.synergy = nil
					-- if CombatMetronome.SV.debug.enabled then self.debug:Print("Synergy deleted") end
				end
			end
		end
	)
end

function CombatMetronome:RegisterResourceTracker()
    EVENT_MANAGER:RegisterForUpdate(
        self.name.."UpdateLabels",
        1000 / 60,
        function(...) self:UpdateLabels() end
    )
	
	if CombatMetronome.SV.Resources.coralBahsei and self.LSD then
		CombatMetronome:RegisterCoralBahsei()
	end
	
	self.rtRegistered = true
end

function CombatMetronome:RegisterCoralBahsei()
	local setIds = {647,587,147}
	CombatMetronome.LSD.RegisterEvent(
		LSD_EVENT_SET_CHANGE,
		CombatMetronome.name.."CoralBahseiActive",
		function(...)
			CombatMetronome:UpdateCoralBahsei(...)
		end,
		LSD_UNIT_TYPE_PLAYER,
		setIds
	)
	-- CombatMetronome.debug:Print("Coral/Bahsei active status registered")
	CombatMetronome:UpdateCoralBahsei()
	self.coralBahseiRegistered = true
end

function StackTracker:Register(skill)
	
	if self:CheckIfRegistered(skill) then
		return
	end
	
	local aId
			
	if type(self.SKILL_ATTRIBUTES[skill].id) == "number" then
		aId = self.SKILL_ATTRIBUTES[skill].id
	elseif self.SKILL_ATTRIBUTES[skill].id.buff then
		aId = self.SKILL_ATTRIBUTES[skill].id.buff
	elseif skill == "GF" or skill == "FS" then
		aId = self.SKILL_ATTRIBUTES[skill].id[Util.Stacks.morphs[skill]].buff
	end
	self.trackedIds[aId] = skill
	
	local eventName = self.name..skill.."Stacks"
	
	self:RegisterEffectChanged(eventName, aId)  -- Register Skill
	
	self.stacks[skill] = self:GetCurrentStacks(skill)
	self:InitializeUI(skill)
	
	StackTracker:ChangeStackCount(skill, self.stacks[skill])
	-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print(skill.." tracker is registered") end
end

function StackTracker:RegisterEffectChanged(name, aId)
	EVENT_MANAGER:RegisterForEvent(
		name,
		EVENT_EFFECT_CHANGED,
		function(...) self:HandleEffectChanged(...) end
	)
	EVENT_MANAGER:AddFilterForEvent(
		name,
		EVENT_EFFECT_CHANGED,
		REGISTER_FILTER_ABILITY_ID,
		aId
	)
	EVENT_MANAGER:AddFilterForEvent(
		name,
		EVENT_EFFECT_CHANGED,
		REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE ,
		COMBAT_UNIT_TYPE_PLAYER
	)
end

function CombatMetronome:UnregisterCM()
	EVENT_MANAGER:UnregisterForUpdate(
        self.name.."Update")
		
	-- EVENT_MANAGER:UnregisterForEvent(
        -- self.name.."SlotUsed")
	
	self.cmRegistered = false
	-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print("cm is unregistered") end
		
	if self.collectiblesTrackerRegistered then
		CombatMetronome:UnregisterCollectiblesTracker()
	end
	
	if self.itemsTrackerRegistered then
		CombatMetronome:UnregisterItemsTracker()
	end
	
	if self.combatEventsRegistered and not self:CheckForCombatEventsRegister() then
		CombatMetronome:UnregisterCombatEvents()
	end
	
	if self.synergyChangedRegistered then
		CombatMetronome:UnregisterSynergyChanged()
	end
end

function CombatMetronome:UnregisterResourceTracker()
	EVENT_MANAGER:UnregisterForUpdate(
        self.name.."UpdateLabels")
		
	self.rtRegistered = false
end

function CombatMetronome:UnregisterCoralBahsei()
	local setIds = {647,587}
	CombatMetronome.LSD.UnregisterEvent(
		LSD_EVENT_SET_CHANGE,
		CombatMetronome.name.."CoralBahseiActive",
		LSD_UNIT_TYPE_PLAYER,
		setIds
	)
	-- CombatMetronome.debug:Print("Coral/Bahsei active status unregistered")
	self.coralBahseiRegistered = false
end

function StackTracker:Unregister(skill)

	if not self:CheckIfRegistered(skill) then
		return
	end
	
	for id, ability in pairs(self.trackedIds) do
		if (ability == skill) then
			self.trackedIds[id] = nil
			-- unregisteredAbility = true
			break
		end
	end

	EVENT_MANAGER:UnregisterForEvent(
		self.name..skill.."Stacks")

	self.stacks[skill] = nil
	self:HandleUIVisibility(skill, "NoUI")
	self:HandleUIVisibility(skill, "NoSample")
	-- if CombatMetronome.SV.debug.enabled then CombatMetronome.debug:Print(skill.." tracker is unregistered") end
end

function CombatMetronome:UnregisterCollectiblesTracker()
	EVENT_MANAGER:UnregisterForEvent(
		self.name.."CollectibleUsed")
		
	self.collectiblesTrackerRegistered = false
end

function CombatMetronome:UnregisterItemsTracker()
	EVENT_MANAGER:UnregisterForEvent(
		self.name.."InventoryItemUsed")
	
	EVENT_MANAGER:UnregisterForEvent(
		self.name.."InventoryItemInfo")
		
	self.itemsTrackerRegistered = false
end

function CombatMetronome:UnregisterCombatEvents()
	EVENT_MANAGER:UnregisterForEvent(
		self.name.."CombatEvents")
		
	self.combatEventsRegistered = false
end

function CombatMetronome:UnregisterCombatEvents()
	EVENT_MANAGER:UnregisterForEvent(
		self.name.."SynergyChanged")
		
	self.synergyChangedRegistered = false
end