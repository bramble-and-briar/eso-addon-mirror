local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U14"
Module.NAME = CA2.GenerateModuleName(14, 975)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	975, -- Halls of Fabrication
}

Module.STRINGS = {
	-- Custom
	stackTime = { default = "%d stacks (%s)" },
	shutdown = { default = "Upstairs" },
	spinner = { default = "Spinner Awaken" },
	steamer = { default = "Steamer Awaken" },
	swap = { default = "Taunt Swap" },
	feedback = { default = "Incoming <<1>> <<t:2>> from <<t:3>> in <<4>>ms" },
}

Module.DEFAULT_SETTINGS = {
	raidLeadMode = false,
}

Module.DATA = {
	-- Boss 1
	gore = 90854,

	-- Boss 2
	shutdown = 91141,
	simulacra = 90681,
	scalded = 90916,
	scaldedMax = 10,
	centurionShockTarget = 94782,
	centurionAwaken = 90887,
	boss2EndPortal = 94705,

	-- Boss 4
	limbs = 90265,
	swap = {
		[94736] = true, -- Overheating Aura
		[94757] = true, -- Overloading Aura
	},
	shockAura = 93767,
	shockFieldName = LCA.GetAbilityName(93765),
	overchargeHealth = 91004,
	overchargeTether = 91082,
	fireWhirl = 90293,
	fireWhirlEmpoweredText = zo_strformat("<<t:1>> (<<t:2>>: %d)", GetAbilityName(90293), GetAbilityName(91316)),

	-- Boss 5
	feedback = 91038,
	feedbackShield = 91031,
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_BOSSES = true

	self.TIMER_ALERTS_LEGACY = {
		[87735] = { -2, 2 }, -- Powered Realignment
		[89065] = { -2, 2 }, -- Clash (Veteran)
		[90264] = { -2, 2 }, -- Lightning Lunge
		[90629] = { -2, 2 }, -- Shocking Smash
		[90694] = { -2, 2 }, -- Invasive Cut
		[90889] = { -2, 2 }, -- Hammer
		[91736] = { -3, 2, true }, -- Taking Aim
		[91929] = { -2, 2 }, -- Clash (Normal)
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[90290] = { 400, false }, -- Residual Static
		[91104] = { 400, false }, -- Static Diffusion
		[90459] = { 1200, false }, -- Grasping Limbs
	}

	self.PURGEABLE_EFFECTS = {
		[87741] = 0, -- Shattered
		[90409] = 0, -- Melting Point
		[90698] = 0, -- Phlebotomize
		[90854] = 0, -- Gaping Wound
		[93669] = 0, -- Greater Defile
		[95230] = 0, -- Venom Injection
	}

	self.vars = {
		scalded = {
			stacks = 0,
			stop = 0,
		},
		shockTargets = { },
		limbs = 0,
		swap = {
			previous = 0,
			stop = 0,
		},
		overchargeHealth = { },
		overchargeTether = { },
		feedback = {
			shieldTime = 0,
			launchTime = 0,
			travelTime = 0,
			strength = 0,
			abilityId = 0,
			alert = false,
		},
	}
	Vars = self.vars

	self.StatusPoll_B1 = function( )
		local results = self:GetScratch()
		for i = 1, 2 do
			table.insert(results, string.format("%d%%", zo_floor(LCA.GetUnitHealthPercent("boss" .. i))))
		end
		CA2.StatusSetCellText(1, 2, table.concat(results, " / "))
	end

	self.StatusStart_B1 = function( )
		CA2.StatusEnable({
			ownerId = "u14b1",
			rowLabels = GetString("SI_ATTRIBUTES", ATTRIBUTE_HEALTH),
			pollingFunction = self.StatusPoll_B1,
		})
	end

	self.StatusInit_B2 = function( )
		Vars.shutdown = nil
		Vars.simulacra = nil
		Vars.scalded.stacks = 0
		Vars.scalded.stop = 0
	end

	self.StatusPoll_B2 = function( )
		local currentTime = GetGameTimeMilliseconds()

		if (Vars.shutdown) then
			CA2.StatusSetCellText(1, 2, LCA.FormatTime(currentTime - Vars.shutdown, LCA.TIME_FORMAT_SHORT))
		else
			CA2.StatusSetRowHidden(1, true)
		end

		if (Vars.simulacra) then
			local elapsed = currentTime - Vars.simulacra
			CA2.StatusModifyCell(2, 2,
				"text", zo_strformat(SI_LCA_TIME_SINCE_PREVIOUS, LCA.FormatTime(elapsed, LCA.TIME_FORMAT_SHORT)),
				"color", (elapsed >= 40000) and 0x33CCFFFF or 0xFFFFFFFF
			)
		else
			CA2.StatusSetRowHidden(2, true)
		end

		if (Vars.scalded.stacks > 0 and Vars.scalded.stop > 0) then
			local ratio = zo_clamp(1 - Vars.scalded.stacks / DATA.scaldedMax, 0, 1)
			CA2.StatusModifyCell(3, 2,
				"text", string.format(self:GetString("stackTime"), Vars.scalded.stacks, LCA.FormatTime(Vars.scalded.stop - currentTime, LCA.TIME_FORMAT_SHORT)),
				"color", LCA.PackRGBA(LCA.HSLToRGB(ratio / 3, 1, 0.5, 1))
			)
		else
			CA2.StatusSetRowHidden(3, true)
		end
	end

	self.StatusStart_B2 = function( )
		CA2.StatusEnable({
			ownerId = "u14b2",
			rowLabels = { self:GetString("shutdown"), LCA.GetAbilityName(DATA.simulacra), LCA.GetAbilityName(DATA.scalded) },
			pollingFunction = self.StatusPoll_B2,
			initFunction = self.StatusInit_B2,
		})
	end

	self.StatusInit_B4 = function( )
		Vars.limbs = 0
		Vars.swap.previous = GetGameTimeMilliseconds()
		ZO_ClearTable(Vars.overchargeHealth)
		ZO_ClearTable(Vars.overchargeTether)
		for i = 1, 3 do
			CA2.StatusModifyCell(i, 2,
				"alignment", TEXT_ALIGN_RIGHT,
				"minWidth", "00%"
			)
		end
	end

	self.StatusPoll_B4 = function( )
		local currentTime = GetGameTimeMilliseconds()

		for i = 1, 3 do
			local health = LCA.GetUnitHealthPercent("boss" .. i)

			local color = 0xFFFFFFFF
			if (health == 0) then
				color = 0x00FF00FF
			elseif ( (health >= 73 and health < 76) or
			         (health >= 43 and health < 46) or
			         (health >= 23 and health < 26) ) then
				color = 0xFFFF00FF
			elseif ( (health >= 70 and health < 73) or
			         (health >= 40 and health < 43) or
			         (health >= 20 and health < 23) ) then
				color = 0xCC0000FF
			end

			CA2.StatusModifyCell(i, 2,
				"text", string.format("%d%%", health),
				"color", color
			)
		end

		if (Vars.limbs > 0) then
			local elapsed = currentTime - Vars.limbs
			CA2.StatusModifyCell(4, 2,
				"text", zo_strformat(SI_LCA_TIME_SINCE_PREVIOUS, LCA.FormatTime(elapsed, LCA.TIME_FORMAT_SHORT)),
				"color", (elapsed >= 25000) and 0x33CCFFFF or 0xFFFFFFFF
			)
		else
			CA2.StatusSetCellText(4, 2, "")
		end

		if (LCA.isVet and (LCA.DoesPlayerHaveTauntSlotted() or self:GetSetting("raidLeadMode"))) then
			if (Vars.swap.stop > currentTime) then
				CA2.StatusModifyCell(5, 2,
					"text", zo_strformat(SI_LCA_TIME_REMAINING, LCA.FormatTime(Vars.swap.stop - currentTime, LCA.TIME_FORMAT_SHORT)),
					"color", 0xFF0000FF
				)
			else
				local elapsed = currentTime - Vars.swap.previous
				CA2.StatusModifyCell(5, 2,
					"text", zo_strformat(SI_LCA_TIME_SINCE_PREVIOUS, LCA.FormatTime(elapsed, LCA.TIME_FORMAT_SHORT)),
					"color", (elapsed >= 25000) and 0xFFCC00FF or 0xFFFFFFFF
				)
			end
		else
			CA2.StatusSetRowHidden(5, true)
		end
	end

	self.HandleFeedback = function( result, _, _, _, _, _, sourceType, _, targetType, hitValue, _, _, _, _, _, abilityId )
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.feedback and targetType == COMBAT_UNIT_TYPE_PLAYER) then
			Vars.feedback.launchTime = GetGameTimeMilliseconds()
			Vars.feedback.travelTime = hitValue
			if (Vars.feedback.launchTime - Vars.feedback.shieldTime < 100) then
				-- Shield event happened before launch event (unexpected)
				Vars.feedback.alert = true
			end
		elseif (result == ACTION_RESULT_DAMAGE_SHIELDED and abilityId == DATA.feedbackShield and sourceType == COMBAT_UNIT_TYPE_PLAYER) then
			Vars.feedback.strength = hitValue
			self.divertNextEvent = self.HandleFeedback
		elseif (LCA.DAMAGE_EVENTS[result] and hitValue == 0 and sourceType == COMBAT_UNIT_TYPE_PLAYER) then
			Vars.feedback.shieldTime = GetGameTimeMilliseconds()
			Vars.feedback.abilityId = abilityId
			if (Vars.feedback.shieldTime - Vars.feedback.launchTime < 100) then
				-- Shield event happened after launch event (expected)
				Vars.feedback.alert = true
			end
		end

		if (Vars.feedback.alert) then
			Vars.feedback.alert = false

			CA2.ChatMessage(zo_strformat(
				self:GetString("feedback"),
				Vars.feedback.strength,
				GetAbilityName(DATA.feedback),
				GetAbilityName(Vars.feedback.abilityId),
				Vars.feedback.travelTime)
			)

			if (Vars.feedback.strength >= 7500) then
				CA1.AlertCast(DATA.feedback, nil, Vars.feedback.travelTime, { 0, 0, false, { 0, 0.5, 1, 1 } })
				if (Vars.feedback.strength >= 12000) then
					LCA.PlaySounds("DUEL_START")
				end
			end

			Vars.feedback.launchTime = 0
			Vars.feedback.shieldTime = 0
		end

		return true
	end
end

function Module:OnBossesChanged( )
	if (GetUnitName("boss3") ~= "") then
		-- Triplets initialization is handled by the start of combat
	elseif (GetUnitName("boss2") ~= "") then
		self.StatusStart_B1()
	elseif (GetUnitName("boss1") == "") then
		-- Workaround for stuck-in-combat issues
		self:StopListening()
	end
end

function Module:PreStartListening( )
	if (GetUnitName("boss3") ~= "") then
		CA2.StatusEnable({
			ownerId = "u14b4",
			rowLabels = { GetUnitName("boss1"), GetUnitName("boss2"), GetUnitName("boss3"), LCA.GetAbilityName(DATA.limbs), self:GetString("swap") },
			pollingFunction = self.StatusPoll_B4,
			initFunction = self.StatusInit_B4,
		})
	elseif (GetUnitName("boss2") ~= "") then
		self.StatusStart_B1()
	end
end

function Module:PostStopListening( )
	CA2.StatusDisable()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- Boss 1
	if (abilityId == DATA.gore and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CA2.ScreenBorderEnable(0xFFDD0066, nil, "u14gore")
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.ScreenBorderDisable("u14gore")
		end

	-- Boss 2
	elseif (abilityId == DATA.shutdown) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			self.StatusStart_B2()
			Vars.shutdown = GetGameTimeMilliseconds()
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.shutdown = nil
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.simulacra) then
		self.StatusStart_B2()
		Vars.simulacra = GetGameTimeMilliseconds()
	elseif (abilityId == DATA.scalded and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		self.StatusStart_B2()
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			Vars.scalded.stacks = hitValue
			if (Vars.scalded.duration) then
				Vars.scalded.stop = GetGameTimeMilliseconds() + Vars.scalded.duration
			end
		elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.scalded.duration = hitValue
			Vars.scalded.stop = GetGameTimeMilliseconds() + hitValue
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.scalded.stacks = 0
			Vars.scalded.stop = 0
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.centurionShockTarget) then
		Vars.shockTargets[targetUnitId] = GetGameTimeMilliseconds()
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.centurionAwaken) then
		if (Vars.shockTargets[targetUnitId] and GetGameTimeMilliseconds() - Vars.shockTargets[targetUnitId] <= 4000) then
			Vars.shockTargets[targetUnitId] = nil
			CA1.Alert(nil, self:GetString("spinner"), 0x66CCFFFF, SOUNDS.OBJECTIVE_DISCOVERED, hitValue)
		elseif (LCA.isTank or self:GetSetting("raidLeadMode")) then
			CA1.Alert(nil, self:GetString("steamer"), 0xFF6600FF, SOUNDS.OBJECTIVE_DISCOVERED, hitValue)
		end
	elseif (abilityId == DATA.boss2EndPortal and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		-- Workaround to clear the status panel if the group is stuck in combat
		CA2.StatusDisable()

	-- Boss 4
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.limbs) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - Vars.limbs > 10000) then
			Vars.limbs = currentTime
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and DATA.swap[abilityId]) then
		local currentTime = GetGameTimeMilliseconds()
		Vars.swap.previous = currentTime
		Vars.swap.stop = currentTime + hitValue
	elseif (result == ACTION_RESULT_EFFECT_GAINED and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.shockAura and hitValue == 1) then
		CA1.Alert(nil, DATA.shockFieldName, 0x66CCFFFF, SOUNDS.DUEL_START, 1500)
	elseif (abilityId == DATA.overchargeHealth) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			Vars.overchargeHealth[targetUnitId] = hitValue
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.overchargeHealth[targetUnitId] = nil
		end
	elseif (abilityId == DATA.overchargeTether) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			Vars.overchargeTether[targetUnitId] = hitValue
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.overchargeTether[targetUnitId] = nil
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.fireWhirl) then
		local stacks = (Vars.overchargeHealth[targetUnitId] or 0) + (Vars.overchargeTether[targetUnitId] or 0)
		if (stacks > 0) then
			CA1.Alert(nil, string.format(DATA.fireWhirlEmpoweredText, stacks), 0xFF6600FF, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
		end

	-- Boss 5
	elseif (abilityId == DATA.feedback or abilityId == DATA.feedbackShield) then
		self.divertCurrentEvent = self.HandleFeedback
	end
end

function Module:GetSettingsControls( )
	return {
		--------------------
		{
			type = "checkbox",
			name = SI_CA_SETTINGS_MODULE_RAID_LEAD,
			tooltip = SI_CA_SETTINGS_MODULE_RAID_LEAD_TT,
			getFunc = function() return self:GetSetting("raidLeadMode") end,
			setFunc = function(enabled) self:SetSetting("raidLeadMode", enabled) end,
		},
	}
end

CA2.RegisterModule(Module)
