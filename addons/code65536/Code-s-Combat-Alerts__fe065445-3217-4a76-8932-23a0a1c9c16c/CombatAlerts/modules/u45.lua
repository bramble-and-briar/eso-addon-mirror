local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U45"
Module.NAME = CA2.GenerateModuleName(45, 1496, 1497)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1496, -- Exiled Redoubt
	1497, -- Lep Seclusa
}

Module.STRINGS = {
	-- Extracted
	["8290981-0-122913"] = { default = "Garvin the Tracker^M", de = "Garvin der Fährtenleser^M", es = "Garvin el Rastreador^M", fr = "Garvin le pisteur^M", jp = "追跡者ガーヴィン^M", ru = "Следопыт Гарвин^M", zh = "追踪者加文" },
	["8290981-0-122914"] = { default = "Noriwen^F", de = "Noriwen^F", es = "Noriwen^F", fr = "Noriwën^F", jp = "ノリウェン^F", ru = "Норивен^F", zh = "诺丽纹" },
}

local COLOR_HEAL_CHECK = 0xCCFF33FF

Module.DATA = {
	-- General
	banners = {
		[222696] = COLOR_HEAL_CHECK, -- Death Knell
		[224303] = 0x66CCFFFF, -- Frost Shield
		[226575] = COLOR_HEAL_CHECK, -- Wild Spores
	},
	targeted = {
		[222775] = 0xCC3399FF, -- Execute
		[224127] = COLOR_HEAL_CHECK, -- Blackspine Curse
	},

	-- Exiled Redoubt
	condemn = 222714,
	blackspine = 224129,
	stormBoltR = 224214,
	stormBoltM = 227574,

	-- Lep Seclusa
	tether = 225970,
	venomEruption = {
		id = 226181,
		duration = 7800, -- Only for speculatively determining the end during the initial pre-cast
		initial = 30000,
		interval = 80000,
	},
	spores = 226579,
	duneripperSpawn = 229154,
	vacate = 231754,
	spring = {
		id = 231804,
		triggers = { 71, 21 },
	},
	bombLine = {
		[224515] = true,
		[232982] = true,
	},
	molting = 228535,
	forbidden = 229247,
	fracture = 229633,
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		-- Exiled Redoubt
		[223993] = { -2, 2 }, -- Lightning Rod Slam
		[224412] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Coordinated Slash
		[228839] = { -2, 2 }, -- Soul Shatter
		[237292] = { -2, 2 }, -- Power Bash

		-- Lep Seclusa
		[224841] = { -2, 2 }, -- Brand
		[225137] = { -2, 2 }, -- Whirlwind
		[227840] = { -2, 2 }, -- Crushing Chomp
		[227841] = { -2, 2 }, -- Tail Swipe
		[228570] = { -3, 2 }, -- Incinerating Prance
		[229535] = { -2, 2 }, -- Pummel
		[235484] = { -2, 2 }, -- Smash
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[227627] = { 650, false }, -- Scorching Volley
		[229531] = { 650, false }, -- Ghostly Essence
	}

	self.SMALL_GROUP_SIZE = true
	self.PURGEABLE_EFFECTS = {
		[230914] = 0, -- Ignited
	}

	self.vars = {
		condemnEnd = 0,
		blackspine = {
			target = "",
			stop = 0,
		},
		venomEruption = {
			next = 0,
			prev = 0,
			stop = 0,
			count = 0,
		},
		sporesEnd = 0,
		springIdx = 1,
		achState = 0,
	}
	Vars = self.vars

	self.StatusPoll_EB1 = function( )
		local currentTime = GetGameTimeMilliseconds()

		if (Vars.condemnEnd > currentTime) then
			local remaining = Vars.condemnEnd - currentTime
			CA2.StatusModifyCell(1, 2,
				"text", LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT),
				"color", COLOR_HEAL_CHECK
			)
		else
			CA2.StatusSetRowHidden(1, true)
		end
	end

	self.StatusPoll_EB2 = function( )
		local currentTime = GetGameTimeMilliseconds()
		if (Vars.blackspine.stop > currentTime) then
			local remaining = Vars.blackspine.stop - currentTime
			CA2.StatusModifyCell(1, 2,
				"text", string.format("%s [%s]", Vars.blackspine.target, LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT)),
				"color", COLOR_HEAL_CHECK
			)
		else
			CA2.StatusSetRowHidden(1, true)
		end
	end

	self.StartLB1Panel = function( )
		CA2.StatusEnable({
			ownerId = "u45lb1",
			rowLabels = { LCA.GetAbilityName(DATA.venomEruption.id), LCA.GetAbilityName(DATA.spores) },
			pollingFunction = self.StatusPoll_LB1,
		})
	end

	self.StatusPoll_LB1 = function( )
		local currentTime = GetGameTimeMilliseconds()

		-- Venom Eruption
		local elapsed = ""
		if (Vars.venomEruption.stop > currentTime) then
			CA2.StatusModifyCell(1, 2,
				"text", string.format("%s [%s]", GetString(SI_LCA_ACTIVE), LCA.FormatTime(Vars.venomEruption.stop - currentTime, LCA.TIME_FORMAT_SHORT)),
				"color", 0x00CC00FF
			)
		else
			local remaining = Vars.venomEruption.next - currentTime
			local threshold = 15000
			CA2.StatusModifyCell(1, 2,
				"text", LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT),
				"color", (remaining >= threshold) and
					0xFFFFFF99 or
					LCA.PackRGBA(LCA.HSLToRGB(zo_clamp(remaining / threshold, 0, 1) / 6, 1, 0.5, 1))
			)
			if (Vars.venomEruption.prev > 0) then
				elapsed = zo_strformat(SI_LCA_TIME_SINCE_PREVIOUS, LCA.FormatTime(currentTime - Vars.venomEruption.prev, LCA.TIME_FORMAT_SHORT))
			end
		end
		CA2.StatusModifyCell(1, 0,
			"text", elapsed,
			"color", 0xCCCC99FF
		)

		-- Wild Spores
		if (Vars.sporesEnd > currentTime) then
			local remaining = Vars.sporesEnd - currentTime
			CA2.StatusModifyCell(2, 2,
				"text", LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT),
				"color", COLOR_HEAL_CHECK
			)
		else
			CA2.StatusSetRowHidden(2, true)
		end
	end

	self.StartLB2Panel = function( )
		CA2.StatusEnable({
			ownerId = "u45lb2",
			rowLabels = LCA.GetAbilityName(DATA.spring.id),
			pollingFunction = self.StatusPoll_LB2,
		})
	end

	self.StatusPoll_LB2 = function( )
		local health = LCA.GetUnitHealthPercent("boss1")

		-- Ensure we're looking at the correct trigger, if someone loaded in late
		while ((DATA.spring.triggers[Vars.springIdx] or -100) > health + 15) do
			Vars.springIdx = Vars.springIdx + 1
		end
		local trigger = DATA.spring.triggers[Vars.springIdx] or -100

		local remaining = zo_max(health - trigger, 0)
		local threshold = 10
		if (remaining < threshold) then
			CA2.StatusModifyCell(1, 2,
				"text", string.format("%.1f%%", remaining),
				"color", LCA.PackRGBA(LCA.HSLToRGB(zo_clamp(remaining / threshold, 0, 1) / 6, 1, 0.5, 1))
			)
		else
			CA2.StatusSetRowHidden(1, true)
		end
	end
end

function Module:PreStartListening( )
	if (LCA.MatchStrings(GetUnitName("boss1"), self:GetString("8290981-0-122913"))) then
		Vars.venomEruption.next = GetGameTimeMilliseconds() + DATA.venomEruption.initial
		Vars.venomEruption.prev = 0
		Vars.venomEruption.count = 0
		self.StartLB1Panel()
	elseif (LCA.MatchStrings(GetUnitName("boss1"), self:GetString("8290981-0-122914"))) then
		Vars.springIdx = 1
		self.StartLB2Panel()
	end
	Vars.achState = 0
end

function Module:PostStopListening( )
	CA2.StatusDisable()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- General
	if (result == ACTION_RESULT_BEGIN and DATA.banners[abilityId]) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), DATA.banners[abilityId], SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and DATA.targeted[abilityId]) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, DATA.targeted[abilityId], SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)

	-- Exiled Redoubt
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.condemn) then
		Vars.condemnEnd = GetGameTimeMilliseconds() + hitValue
		CA2.StatusEnable({
			ownerId = "u45eb1",
			rowLabels = LCA.GetAbilityName(abilityId),
			pollingFunction = self.StatusPoll_EB1,
		})
	elseif (abilityId == DATA.blackspine) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.blackspine.target = select(2, LCA.IdentifyGroupUnitId(targetUnitId, true))
			Vars.blackspine.stop = GetGameTimeMilliseconds() + hitValue
			CA2.StatusEnable({
				ownerId = "u45eb2",
				rowLabels = LCA.GetAbilityName(abilityId),
				pollingFunction = self.StatusPoll_EB2,
			})
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.blackspine.stop = 0
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.stormBoltR) then
		local unitTag, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId)
		if (unitTag) then
			if (targetType == COMBAT_UNIT_TYPE_PLAYER or LCA.GetDistance("player", unitTag) <= 10) then
				CA1.Alert(LCA.GetAbilityName(abilityId), name, 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
			end
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.stormBoltM) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)

	-- Lep Seclusa
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.tether) then
		local unitId, fallbackName
		if (sourceType == COMBAT_UNIT_TYPE_PLAYER) then
			unitId = targetUnitId
			fallbackName = targetName
		elseif (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			unitId = sourceUnitId
			fallbackName = sourceName
		end
		if (unitId) then
			local name = select(2, LCA.IdentifyGroupUnitId(unitId)) or zo_strformat(SI_PLAYER_NAME, fallbackName)
			CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.venomEruption.id) then
		local currentTime = GetGameTimeMilliseconds()
		if (hitValue < 1000) then
			Vars.venomEruption.count = Vars.venomEruption.count + 1
			CA1.Debug(string.format("%s #%d: %dms from expected", LCA.GetAbilityName(abilityId), Vars.venomEruption.count, currentTime - Vars.venomEruption.next))
			Vars.venomEruption.stop = currentTime + hitValue + DATA.venomEruption.duration
			Vars.venomEruption.next = currentTime + DATA.venomEruption.interval
			Vars.venomEruption.prev = currentTime
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x00CC00FF, nil, 2000)
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 4)
			self.StartLB1Panel()
		else
			Vars.venomEruption.stop = currentTime + hitValue
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.duneripperSpawn) then
		local health = LCA.GetUnitHealthPercent("boss1", true)
		if (health and health < 100) then -- Filter out the initial demonstration spawn
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.spores) then
		Vars.sporesEnd = GetGameTimeMilliseconds() + hitValue
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.vacate and LCA.isTank) then
		LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 300, "DUEL_BOUNDARY_WARNING", 3, 400, "DUEL_BOUNDARY_WARNING", 4)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.spring.id) then
		Vars.springIdx = Vars.springIdx + 1
	elseif (LCA.isVet and LCA.DAMAGE_EVENTS[result] and DATA.bombLine[abilityId]) then
		if (Vars.achState == 0 and not IsAchievementComplete(4138)) then
			CA2.ChatMessage(string.format("|cCC0000%s|r |H1:achievement:4138:0:0|h|h", zo_iconFormatInheritColor(LCA.GetTexture("misc-x"), "100%", "100%")), true)
		end
		Vars.achState = 1
	elseif (abilityId == DATA.molting and LCA.DAMAGE_EVENTS[result] and GetUnitName("boss1") ~= "") then
		if (Vars.achState == 0 and not IsAchievementComplete(4252)) then
			CA2.ChatMessage(string.format("|cCC0000%s|r |H1:achievement:4252:0:0|h|h", zo_iconFormatInheritColor(LCA.GetTexture("misc-x"), "100%", "100%")), true)
		end
		Vars.achState = 1
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.forbidden and hitValue < 1000 and not LCA.isTank) then
		LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 2, 750, "DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 4)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.fracture) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CA1.AlertCast(abilityId + 1, sourceName, hitValue, { 0, 0, false, { 1, 0, 0.6, 0.8 } })
		else
			local unitTag, name = LCA.IdentifyAllyUnitId(targetUnitId)
			if (unitTag and LCA.GetDistance("player", unitTag) <= 4) then
				CA1.Alert(LCA.GetAbilityName(abilityId), name, 0x00CC00FF, nil, 1500)
				LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 2, 150, "FRIEND_INVITE_RECEIVED", 4)
			end
		end
	end
end

CA2.RegisterModule(Module)
