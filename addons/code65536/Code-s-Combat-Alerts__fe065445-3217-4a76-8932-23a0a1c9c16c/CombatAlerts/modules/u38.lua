local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U38"
Module.NAME = CA2.GenerateModuleName(38, 1427)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1427, -- Sanity's Edge
}

Module.STRINGS = {
	-- Extracted
	["8290981-0-113567"] = { default = "Ascendant Gryphon^m", de = "emporstrebender Greif^m", es = "grifo ascendente^m", fr = "griffon ascendant^m", jp = "超越のグリフォン^m", ru = "Господствующий грифон^m", zh = "飞升狮鹫" },
	["8290981-0-113568"] = { default = "Ascendant Lion^m", de = "emporstrebender Löwe^m", es = "león ascendente^m", fr = "lion ascendant^m", jp = "超越のライオン^m", ru = "Господствующий лев^m", zh = "飞升雄狮" },
	["8290981-0-113569"] = { default = "Ascendant Wamasu^n", de = "emporstrebender Wamasu^m", es = "wamasu ascendente^m", fr = "wamasu ascendant^m", jp = "超越のワマス^n", ru = "Господствующий вамасу^n", zh = "飞升雷光蜥蜴" },

	-- Custom
	spawn = { default = "Control Avatar" },
}

Module.DATA = {
	-- Boss 1
	b1hmHealth = 90000000,
	fireBomb = 183660,
	fireBombInterval = { 23000, 11000 },
	charge = {
		[191133] = 1,
		[200544] = 2,
	},
	shrapnel = {
		start = 184823,
		name = 199131,
		thresholds = { 81, 56, 26 },
		interval = 42000, -- 42s from end of previous to next; observations range from 42.6 to 44.6
	},
	frostBomb1 = 183768,
	frostBomb2 = 185392,

	-- Boss 2
	field = {
		cast = 186884,
		interval = 31500, -- 31.5s; observations range from 31.695 to 35.575
	},
	petrify = {
		effect = 185041,
		duration = 95000, -- 95s; observations range from 96.123 to 100.849
	},
	chain = {
		cast = 183858,
		interval = 20000, -- 20s; observations range from 19.412 to 22.509
		initial = 7000, -- 7s; observations range from 7.175 to 8.653
	},
	mantles = {
		[183640] = true, -- Mantle: Gryphon
		[184983] = true, -- Mantle: Lion
		[184984] = true, -- Mantle: Wamasu
	},
	spawn = {
		[198176] = "8290981-0-113567", -- Mantle: Gryphon
		[198177] = "8290981-0-113568", -- Mantle: Lion
		[198178] = "8290981-0-113569", -- Mantle: Wamasu
		interval = 30000, -- 30s; observations range from 30.031 to 31.718
		initialOffset = 2000, -- 2s
	},
	inferno = {
		cast = 186948,
		meteor = 198613,
		sunburst = 198619,
		interval = 21000, -- 21s; observations range from 20.425 to 23.626
		initialOffset = 2000, -- 2s
	},

	-- Boss 3
	boss3Abilities = {
		-- Abilities unique to the third boss for identification purposes
		[187246] = true, -- Phobic Bolts
		[187248] = true, -- Phobic Claws
	},
	phobia = 185117,
	sunburst = {
		id = 199344,
		damage = 199346,
	},
	poison = 184710,
	wrath = {
		[189163] = 1, -- Side Room
		[198759] = 0, -- Main Room
		damage = 189167,
		timing = 3200, -- 1100 cast (198759) + 1000 duration (198759) + 1100 duration (198763)
	},
	attuned = 187186,
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		[139581] = { -2, 0 }, -- Pummel
		[184633] = { -2, 2 }, -- Hamstrung Strike
		[184999] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Charged Headbutt
		[185071] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Vengeful Strike
		[186685] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Butcher
		[186898] = { -2, 2 }, -- Lightning Rod Slam
		[186937] = { -2, 2 }, -- Maul
		[186969] = { -2, 2 }, -- Double Strike
		[187059] = { -2, 2 }, -- Sunburst
		[187090] = { -2, 2 }, -- Spray
		[187091] = { -3, 2 }, -- Corrupt
		[187118] = { -2, 2 }, -- Defile
		[187427] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Bludgeon
		[187540] = { -3, 2, false }, -- Eagle Eye Shot
		[192651] = { -2, 2 }, -- Uppercut
		[199179] = { -2, 0, false, { 1, 0, 0.6, 0.8 }, offset = -1200 }, -- Raze
	}

	self.vars = {
		b1hm = false,
		frosts = { },
		lastBomb = 0,
		shrapnelIdx = 1,
		shrapnelEnd = 0,
		nextField = 0,
		chainNumber = 1,
		b2next = { },
		phobia = { },
		attuned = 0,
	}
	Vars = self.vars

	self.StatusInit_B1 = function( )
		Vars.b1hm = select(3, GetUnitPower("boss1", COMBAT_MECHANIC_FLAGS_HEALTH)) > DATA.b1hmHealth
		ZO_ClearTable(Vars.frosts)
		Vars.shrapnelIdx = 1
		if (not Vars.b1hm) then
			CA2.StatusSetRowHidden(2, true)
		end
	end

	self.StatusPoll_B1 = function( )
		local currentTime = GetGameTimeMilliseconds()
		local health = LCA.GetUnitHealthPercent("boss1")
		local execute = health - 26
		local remaining = Vars.lastBomb + DATA.fireBombInterval[execute >= 0 and 1 or 2] - currentTime
		local remaining2 = Vars.shrapnelEnd - currentTime
		if (remaining2 > remaining) then
			remaining = remaining2
		end
		local template = "%s"
		local overrideAlpha = false
		if (execute >= 0 and execute < 4) then
			if (execute < 2 and remaining <= 13500) then -- 1.5s more than the cooldown difference
				template = "%s |cFF00FF[%.1f%%]|r"
				overrideAlpha = true
			else
				template = "%s [%.1f%%]"
			end
		end
		CA2.StatusSetCellText(1, 2, string.format(template, LCA.FormatTime(remaining, LCA.TIME_FORMAT_COUNTDOWN), execute))
		local threshold = 5000
		if (remaining > threshold) then
			CA2.StatusSetRowColor(1, 0xFFFFFFFF)
			CA2.StatusSetRowAlpha(1, overrideAlpha and 1 or 0.5)
		else
			local ratio = zo_clamp(remaining / threshold, 0, 1)
			CA2.StatusSetRowColor(1, LCA.PackRGBA(LCA.HSLToRGB(ratio / 6, 1, 0.5, 1)))
			CA2.StatusSetRowAlpha(1, 1)
		end

		if (Vars.b1hm) then
			-- Ensure we're at the correct threshold, if someone loaded in late
			while (DATA.shrapnel.thresholds[Vars.shrapnelIdx + 1] or -1) > health do
				Vars.shrapnelIdx = Vars.shrapnelIdx + 1
			end

			local timeToNext = remaining2 + DATA.shrapnel.interval
			local threshold = DATA.shrapnel.thresholds[Vars.shrapnelIdx]
			local alpha = 1

			if (remaining2 > 0) then
				-- Active Shrapnel
				CA2.StatusSetCellText(2, 2, zo_strformat(SI_LCA_TIME_REMAINING, LCA.FormatTime(remaining2, LCA.TIME_FORMAT_COUNTDOWN)))
			elseif (threshold) then
				-- Pre-execute
				remaining = zo_max(health - threshold, 0)
				if (remaining > 5) then alpha = 0.5 end
				if (timeToNext <= 0) then
					CA2.StatusSetCellText(2, 2, string.format("%.1f%%", remaining))
				else
					CA2.StatusSetCellText(2, 2, string.format("%.1f%% / %s", remaining, LCA.FormatTime(timeToNext, LCA.TIME_FORMAT_SHORT)))
				end
			else
				-- Execute
				if (timeToNext > 7500) then alpha = 0.5 end
				CA2.StatusSetCellText(2, 2, LCA.FormatTime(timeToNext, LCA.TIME_FORMAT_SHORT))
			end
			CA2.StatusSetRowAlpha(2, alpha)
		end
	end

	self.StatusInit_B2 = function( )
		local currentTime = GetGameTimeMilliseconds()
		Vars.b2next.petrify = currentTime + DATA.petrify.duration
		Vars.b2next.inferno = currentTime + DATA.inferno.interval + DATA.inferno.initialOffset
		Vars.b2next.chain = currentTime + DATA.chain.initial
		Vars.b2next.spawn = currentTime + DATA.spawn.interval + DATA.spawn.initialOffset
		if (not LCA.DoesPlayerHaveTauntSlotted()) then
			CA2.StatusSetRowHidden(4, true)
		end
	end

	local setTime_B2 = function( row, time )
		CA2.StatusSetCellText(row, 2, LCA.FormatTime(time, LCA.TIME_FORMAT_SHORT))
		CA2.StatusSetRowAlpha(row, (time < 5500) and 1 or 0.5)
	end

	self.StatusPoll_B2 = function( )
		local currentTime = GetGameTimeMilliseconds()
		setTime_B2(1, Vars.b2next.petrify - currentTime)
		setTime_B2(2, Vars.b2next.inferno - currentTime)
		setTime_B2(3, Vars.b2next.chain - currentTime)
		if (LCA.DoesPlayerHaveTauntSlotted()) then
			setTime_B2(4, Vars.b2next.spawn - currentTime)
		end
	end

	self.GetChainLabel = function( )
		return string.format("%s #%d", LCA.GetAbilityName(DATA.chain.cast), Vars.chainNumber)
	end

	self.IsTwelvaneActive = function( )
		return GetUnitPower("boss2", COMBAT_MECHANIC_FLAGS_HEALTH) > 0x10000
	end

	self.StatusPoll_B2F = function( )
		if (self.IsTwelvaneActive()) then
			CA2.StatusSetCellText(1, 2, LCA.FormatTime(Vars.nextField - GetGameTimeMilliseconds(), LCA.TIME_FORMAT_SHORT))
		else
			CA2.StatusDisable()
		end
	end

	self.StatusInit_B3 = function( )
		Vars.phobia.previous = 0
		Vars.phobia.nextHealth = 91
	end

	self.StatusPoll_B3 = function( )
		local percent = LCA.GetUnitHealthPercent("boss1")

		-- Ensure we're at the correct threshold, if someone loaded in late
		while Vars.phobia.nextHealth - 20 > percent do
			Vars.phobia.nextHealth = Vars.phobia.nextHealth - 20
		end

		if (Vars.phobia.nextHealth > 30) then
			local threshold = 3
			local remaining = zo_max(percent - Vars.phobia.nextHealth, 0)
			CA2.StatusSetCellText(1, 2, string.format("%.1f%%", remaining))
			if (remaining > threshold) then
				CA2.StatusSetRowColor(1, 0xFFFFFFFF)
				CA2.StatusSetRowAlpha(1, 0.5)
			else
				local ratio = zo_clamp(remaining / threshold, 0, 1)
				CA2.StatusSetRowColor(1, LCA.PackRGBA(LCA.HSLToRGB(ratio / 6, 1, 0.5, 1)))
				CA2.StatusSetRowAlpha(1, 1)
			end
		elseif (Vars.phobia.nextHealth < 11) then
			local timing = 22600 -- 0.6s cast + 2s banishment channel + 20s cooldown
			local threshold = 5500
			local remaining = Vars.phobia.previous + timing - GetGameTimeMilliseconds()
			CA2.StatusSetCellText(1, 2, LCA.FormatTime(remaining, LCA.TIME_FORMAT_COUNTDOWN))
			if (remaining > threshold) then
				CA2.StatusSetRowColor(1, 0xFFFFFFFF)
				CA2.StatusSetRowAlpha(1, 0.5)
			else
				local ratio = zo_clamp(remaining / threshold, 0, 1)
				CA2.StatusSetRowColor(1, LCA.PackRGBA(LCA.HSLToRGB(ratio / 6, 1, 0.5, 1)))
				CA2.StatusSetRowAlpha(1, 1)
			end
		else
			CA2.StatusSetCellText(1, 2, "")
			CA2.StatusSetRowColor(1, 0xFFFFFFFF)
			CA2.StatusSetRowAlpha(1, 0.5)
		end
	end
end

function Module:PostStopListening( )
	CA2.StatusDisable()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- Boss 1
	if (result == ACTION_RESULT_BEGIN and abilityId == DATA.fireBomb) then
		Vars.lastBomb = GetGameTimeMilliseconds()
		CA2.StatusEnable({
			ownerId = "u38b1",
			rowLabels = { LCA.GetAbilityName(abilityId), LCA.GetAbilityName(DATA.shrapnel.name) },
			pollingFunction = self.StatusPoll_B1,
			initFunction = self.StatusInit_B1,
		})
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_BEGIN and DATA.charge[abilityId]) then
		if (DATA.charge[abilityId] == 1 and GetUnitName("boss1") ~= "") then
			local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
			CA1.Alert(nil, string.format("%s (%s)", LCA.GetAbilityName(abilityId), name), 0xFF00FFFF, nil, 1500)
		else
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF00FFFF, nil, 1500)
		end
		LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 1, 150, "DUEL_BOUNDARY_WARNING", 2, 250, "FRIEND_INVITE_RECEIVED", 3)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.shrapnel.start and hitValue < 2000) then
		CA1.Alert(nil, LCA.GetAbilityName(DATA.shrapnel.name), 0xFFFFFFFF, nil, 1500)
		LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 1, 150, "DUEL_BOUNDARY_WARNING", 2, 150, "DUEL_BOUNDARY_WARNING", 3, 150, "DUEL_BOUNDARY_WARNING", 4)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.shrapnel.start) then
		Vars.shrapnelIdx = Vars.shrapnelIdx + 1
		Vars.shrapnelEnd = GetGameTimeMilliseconds() + hitValue
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.frostBomb1) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0x66CCFFFF, nil, 2500)
	elseif (abilityId == DATA.frostBomb2) then
		if (result == ACTION_RESULT_BEGIN) then
			ZO_ClearTable(Vars.frosts)
		elseif (result == ACTION_RESULT_EFFECT_GAINED) then
			local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
			table.insert(Vars.frosts, name)
			if (#Vars.frosts > 1) then
				CA1.Alert(LCA.GetAbilityName(abilityId), table.concat(Vars.frosts, " / "), 0x66CCFFFF, nil, 2500)
				ZO_ClearTable(Vars.frosts)
			end
		end

	-- Boss 2
	elseif (abilityId == DATA.petrify.effect) then
		if (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.StatusEnable({
				ownerId = "u38b2",
				rowLabels = { LCA.GetAbilityName(abilityId), LCA.GetAbilityName(DATA.inferno.cast), self.GetChainLabel(), self:GetString("spawn") },
				pollingFunction = self.StatusPoll_B2,
				initFunction = self.StatusInit_B2,
			})
		elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			CA2.StatusDisable()
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.field.cast and self.IsTwelvaneActive()) then
		Vars.nextField = GetGameTimeMilliseconds() + DATA.field.interval
		CA2.StatusEnable({
			ownerId = "u38b2f",
			rowLabels = LCA.GetAbilityName(abilityId),
			pollingFunction = self.StatusPoll_B2F,
		})
		Vars.chainNumber = 1
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.chain.cast) then
		Vars.b2next.chain = GetGameTimeMilliseconds() + DATA.chain.interval
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0x66CCFFFF, nil, 1500)
		Vars.chainNumber = Vars.chainNumber + 1
		CA2.StatusSetCellText(3, 1, self.GetChainLabel())
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.mantles[abilityId] and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x00CC99FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2500)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.inferno.cast and hitValue < 2000) then
		Vars.b2next.inferno = GetGameTimeMilliseconds() + DATA.inferno.interval
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF6600FF, nil, 1500)
		LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 1, 150, "FRIEND_INVITE_RECEIVED", 1, 150, "DUEL_BOUNDARY_WARNING", 3)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.inferno.meteor and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA1.AlertCast(DATA.inferno.sunburst, sourceName, hitValue, { -3, 0, false, { 1, 0.4, 0, 0.5 } })
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and DATA.spawn[abilityId]) then
		Vars.b2next.spawn = GetGameTimeMilliseconds() + DATA.spawn.interval
		if (LCA.DoesPlayerHaveTauntSlotted()) then
			CA1.Alert(nil, zo_strformat(SI_UNIT_NAME, self:GetString(DATA.spawn[abilityId])), 0xCC00FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end

	-- Boss 3
	elseif (abilityId == DATA.attuned and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			Vars.attuned = 1
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.attuned = 0
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.poison and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x00CC00FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.sunburst.id and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
		CA1.AlertCast(DATA.sunburst.damage, sourceName, hitValue + 800, { -3, 0, false, { 1, 0.4, 0, 0.5 } })
	elseif (result == ACTION_RESULT_BEGIN and DATA.wrath[abilityId]) then
		if (DATA.wrath[abilityId] == Vars.attuned) then
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
			CA1.AlertCast(DATA.wrath.damage, nil, DATA.wrath.timing, { -3, 0, false, { 0.8, 0, 0, 0.6 } })
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.boss3Abilities[abilityId]) then
		if (CA2.StatusGetOwnerId() ~= "u38b3" and LCA.DoesPlayerHaveTauntSlotted()) then
			CA2.StatusEnable({
				ownerId = "u38b3",
				rowLabels = LCA.GetAbilityName(DATA.phobia),
				pollingFunction = self.StatusPoll_B3,
				initFunction = self.StatusInit_B3,
			})
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.phobia) then
		if (CA2.StatusGetOwnerId() == "u38b3") then
			Vars.phobia.previous = GetGameTimeMilliseconds()
			Vars.phobia.nextHealth = Vars.phobia.nextHealth - 20
		end
		if (targetType == COMBAT_UNIT_TYPE_PLAYER or LCA.DoesPlayerHaveTauntSlotted()) then
			local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
			CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
		end
	end
end

CA2.RegisterModule(Module)
