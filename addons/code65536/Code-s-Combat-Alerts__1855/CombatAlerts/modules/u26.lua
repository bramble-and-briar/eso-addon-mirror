local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U26"
Module.NAME = CA2.GenerateModuleName(26, 1196)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1196, -- Kyne's Aegis
}

Module.STRINGS = {
	-- Extracted
	["8290981-0-94772"] = { default = "Captain Vrol^M", de = "Kapitän Vrol^M", es = "capitán Vrol^m", fr = "capitaine Vrol^md", jp = "ヴロル隊長^M", ru = "Капитан Врол^M", zh = "威若船长^M" },
	["8290981-0-94838"] = { default = "Crimson Knight^m", de = "Purpurritter^m", es = "caballero carmesí^m", fr = "chevalier écarlate^m", jp = "クリムゾンの騎士^m", ru = "Алый рыцарь^m", zh = "猩红骑士^m" },
	["8290981-0-94839"] = { default = "Bitter Knight^m", de = "Bitterritter^m", es = "caballero acre^m", fr = "chevalier amer^m", jp = "ビターナイト^m", ru = "Жестокий рыцарь^m", zh = "苦痛骑士^m" },
	["8290981-0-94840"] = { default = "Blood Knight^m", de = "Blutritter^m", es = "caballero sanguinario^m", fr = "chevalier de sang^m", jp = "血の騎士^m", ru = "Кровавый рыцарь^m", zh = "血骑士^m" },
	["8290981-0-96286"] = { default = "Gryphon", de = "Greif^m", es = "Grifo^m", fr = "griffon^m", jp = "グリフォン", ru = "Грифон", zh = "狮鹫" },
	["8290981-0-96308"] = { default = "Sea Adder^n", de = "Seenatter^f", es = "áspid marino^m", fr = "aspic marin^m", jp = "シー・アダー^n", ru = "Морской аспид^m", zh = "海蝰^n" },

	-- Custom (Alerts)
	position = { default = "Position" },

	-- Custom (Settings)
	telegraphSpear = { default = "Show telepgrah for Exploding Spear" },
	telegraphMeteor = { default = "Show telegraph for Meteor" },
	telegraphInstability = { default = "Improve telegraph for Instability" },
}

Module.DEFAULT_SETTINGS = {
	telegraphSpear = true,
	telegraphMeteor = true,
	telegraphInstability = true,
}

Module.DATA = {
	crashingWave = {
		cast = 134196,
		name = 134197,
	},
	meteor = {
		ids = {
			[134023] = 1, -- Vrol
			[140606] = 1, -- Yandir
			[140941] = 2, -- Falgravn non-HM
			[140944] = 2, -- Falgravn HM
		},
		params = {
			[1] = { -- Meteor
				id = 140606,
				colorSelf = 0xFF6600FF,
				colorOthers = 0xFFFF00FF,
				excludeTanks = false,
				telegraphSetting = "telegraphMeteor",
				telegraphClipping = false,
			},
			[2] = { -- Instability
				id = 140941,
				colorSelf = 0x3399FFFF,
				colorOthers = 0xBBDDFFFF,
				excludeTanks = true,
				telegraphSetting = "telegraphInstability",
				telegraphClipping = true,
			},
			[3] = { -- Instability Coincide
				id = 140941,
				colorSelf = 0xDD4400FF,
				colorOthers = 0xFF9933FF,
				excludeTanks = true,
				telegraphSetting = "telegraphInstability",
				telegraphClipping = true,
			},
		},
	},
	yandirAdds = {
		[136381] = "8290981-0-96286", -- Sudden Gust
		[136559] = "8290981-0-96308", -- Slam
	},
	totems = {
		[133045] = { 133264, 0xCC3300FF }, -- Dragon Totem
		[133510] = { 133511, 0x66CCFFFF }, -- Harpy Totem
		[133513] = { 133514, 0xDDCC66FF }, -- Gargoyle Totem
		[133515] = { 133516, 0x00CC00FF }, -- Chaurus Totem
	},
	knights = {
		[140183] = { "8290981-0-94839", 0xCC00FFFF }, -- Prison
		[140184] = { "8290981-0-94838", 0xFF9999FF, true }, -- Bloodlust
		[140185] = { "8290981-0-94840", 0xCC0000FF }, -- Fountains
		spawnText = LCA.GetAbilityName(136622),
	},
	spear = 133936,
	gust = 136381,
	chaurus = {
		spawn = 133516,
		projectile = 133559,
	},
	slam = 136559,
	hailShield = 133004,
	toxicTide = 132513,
	frigidFog = 133808,
	shockingHarpoon = 133913,
	fountain = 140294,
	frenzy = 136953,
	sanguineGrasp = 136965,
	sanguinePrison = 132473,
	proxLightning = 134880,
	callLightning = 133428,
	falgRoomCenter = { 79075, 21670, 56040 },
	falgFloor1End = 135271,
	apotheosis = 138196,
	hemorrhage = 132927,
	ichorEruption = 136482,
	ichorTimer = 136548,
	bloodCounter = 133334,
	lightningBolt = {
		[136808] = true, -- Storm
		[139945] = true, -- Half-Giant Storm Caller
	},
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		[132511] = { -3, 2 }, -- Toxic Tide
		[133685] = { -2, 2 }, -- Shield Bash
		[133756] = { -2, 2 }, -- Thunderous Bash
		[134050] = { -3, 2, false, { 1, 0, 0.6, 0.4 }, { 1, 0, 0.6, 0.8 } }, -- Wrath of Tides
		[135324] = { -2, 2 }, -- Butcher's Blade
		[135991] = { -2, 2 }, -- Toppling Blow
		[136591] = { -3, 2 }, -- Bile Spray
		[136817] = { -2, 2 }, -- Cross Swipe
		[136961] = { -2, 2 }, -- Uppercut
		[136976] = { -3, 2 }, -- Blood Cleave
		[140230] = { -2, 2 }, -- Heavy Strike
		[140231] = { -3, 2, true }, -- Javelin
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[133294] = { 350, true }, -- Pool of Ichor
		[141615] = { 600, false }, -- Corrupted Ichor
	}

	self.vars = {
		meteor = { },
		meteorUnits = { },
		ichor = {
			endTime = 0,
			counter = 0,
		},
		lastHarpoon = 0,
		chains = 0,
	}
	Vars = self.vars

	self.StatusStart_B2 = function( )
		Vars.lastHarpoon = GetGameTimeMilliseconds()
		CA2.StatusEnable({
			ownerId = "u26b2",
			rowLabels = LCA.GetAbilityName(DATA.shockingHarpoon),
			pollingFunction = self.StatusPoll_B2,
		})
	end

	self.StatusPoll_B2 = function( )
		local time = GetGameTimeMilliseconds() - Vars.lastHarpoon
		CA2.StatusModifyCell(1, 2,
			"text", zo_strformat(SI_LCA_TIME_SINCE_PREVIOUS, LCA.FormatTime(time, LCA.TIME_FORMAT_SHORT)),
			"color", time < 38000 and 0xFFFFFFFF or 0xFF9900FF
		)
	end

	self.StatusPoll_B3A = function( )
		CA2.StatusSetCellText(1, 2, Vars.chains)
		CA2.StatusSetCellText(2, 2, string.format("%.1fm", LCA.GetDistance("player", DATA.falgRoomCenter, false, false, true)))
	end

	self.StatusPoll_B3B = function( )
		local time = Vars.ichor.endTime - GetGameTimeMilliseconds()
		local color
		if (time < 3000 and Vars.ichor.counter > 1) then
			color = 0xFF0000FF
		elseif (Vars.ichor.counter > 0) then
			color = 0xFFFF00FF
		else
			color = 0xFFFFFFFF
		end
		CA2.StatusModifyCell(1, 2,
			"text", string.format("%s (%d)", LCA.FormatTime(time, LCA.TIME_FORMAT_COUNTDOWN), Vars.ichor.counter),
			"color", color
		)
	end

	self.MeteorPoll = function( )
		local currentTime = GetGameTimeMilliseconds()
		local nextHit = nil
		local nearby = 0
		local onSelf = false
		for unitId, hitTime in pairs(Vars.meteorUnits) do
			if (currentTime > hitTime + 100) then
				Vars.meteorUnits[unitId] = nil
			else
				if (not nextHit or nextHit > hitTime) then
					nextHit = hitTime
				end
				if (unitId == Vars.meteor.selfId) then
					onSelf = true
					nearby = nearby + 1
				elseif (LCA.IsUnitIdWithinDistance(unitId, 5.5)) then
					nearby = nearby + 1
				end
			end
		end

		if (nextHit) then
			local params = Vars.meteor.params

			local color = 0xDDFFDDFF
			if (nearby == 1) then
				color = 0xFFAADDFF
			elseif (nearby > 1) then
				color = 0xFF0000FF
			end

			CA1.ModifyBanner(
				Vars.meteor.bannerId,
				nil,
				zo_strformat(onSelf and SI_LCA_TARGET_YOU or SI_LCA_TARGET_OTHERS, LCA.GetAbilityName(params.id)),
				(onSelf) and params.colorSelf or params.colorOthers,
				1 - ((nextHit - currentTime) / Vars.meteor.duration),
				nearby,
				color,
				true
			)
		else
			CA1.DisableBanner(Vars.meteor.bannerId)
			ZO_ClearTable(Vars.meteor)
			ZO_ClearTable(Vars.meteorUnits)
		end
	end
end

function Module:PostLoad( )
	EVENT_MANAGER:RegisterForEvent(self.ID, EVENT_RAID_TRIAL_STARTED, function() self:ToggleLeaperMonitor(not IsAchievementComplete(2816)) end)
	EVENT_MANAGER:RegisterForEvent(self.ID, EVENT_RAID_TRIAL_COMPLETE, function() self:ToggleLeaperMonitor(false) end)
end

function Module:PreUnload( )
	EVENT_MANAGER:UnregisterForEvent(self.ID, EVENT_RAID_TRIAL_STARTED)
	EVENT_MANAGER:UnregisterForEvent(self.ID, EVENT_RAID_TRIAL_COMPLETE)
	self:ToggleLeaperMonitor(false)
end

function Module:PreStartListening( )
	if (LCA.MatchStrings(GetUnitName("boss1"), self:GetString("8290981-0-94772"))) then
		self.StatusStart_B2()
	end
end

function Module:PostStopListening( )
	CA2.StatusDisable()
	CA2.WorldCanvasClear()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	if (result == ACTION_RESULT_BEGIN and abilityId == DATA.crashingWave.cast) then
		local id = CA1.AlertCast(DATA.crashingWave.name, nil, hitValue, { 650, 2, false, { 0.3, 0.9, 1, 0.6 }, { 0, 0.5, 1, 1 } })
		if (LCA.IsUnitIdValid(targetUnitId)) then
			self.castSources[targetUnitId] = id
		end
	elseif (abilityId == DATA.spear) then
		if (result == ACTION_RESULT_BEGIN) then
			Vars.spearTarget = targetUnitId
			if (targetType == COMBAT_UNIT_TYPE_PLAYER or LCA.IsUnitIdWithinDistance(targetUnitId, 4.2)) then
				CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
			end
		elseif (result == ACTION_RESULT_EFFECT_GAINED) then
			if (Vars.spearTarget and self:GetSetting("telegraphSpear")) then
				local unitTag = LCA.IdentifyGroupUnitId(Vars.spearTarget)
				if (unitTag) then
					local _, x, y, z = GetUnitRawWorldPosition(unitTag)
					CA2.WorldGrowingCircularTelegraph({ x, y, z }, 400, 2000, false)
				end
			end
			Vars.spearTarget = nil
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.hailShield) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xEEEEFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and DATA.yandirAdds[abilityId]) then
		CA1.Alert(zo_strformat(SI_UNIT_NAME, self:GetString(DATA.yandirAdds[abilityId])), string.format("%s — %s", LCA.GetAbilityName(abilityId), GetString(SI_LCA_BLOCK)), 0xFF99FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and DATA.totems[abilityId]) then
		local totem = DATA.totems[abilityId]
		CA1.Alert(LCA.GetAbilityName(abilityId), LCA.GetAbilityName(totem[1]), totem[2], SOUNDS.OBJECTIVE_DISCOVERED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.frigidFog) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x3399CCFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
		elseif (LCA.IsUnitIdWithinDistance(targetUnitId, 5.3)) then
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x3399CCFF, SOUNDS.DUEL_START, hitValue)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.shockingHarpoon) then
		self.StatusStart_B2()
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.fountain) then
		CA1.Alert(GetString(SI_LCA_INCOMING), LCA.GetAbilityName(abilityId), 0xCC0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.chaurus.spawn) then
		-- Projectile is usually launched 2s after spawn (in about 10% of cases, it's 3s)
		-- Projectile travel time ranges from 0.5 to 1.5s, so minimum hit time of 2.5s from spawn
		CA1.AlertCast(DATA.chaurus.projectile, nil, 2500, { 750, 0, false, { 0, 0.8, 0, 0.6 }, { 0, 0.6, 0, 1 } })
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.knights[abilityId] and hitValue == 1) then
		local knight = DATA.knights[abilityId]
		if (not knight[3] or LCA.isTank) then
			CA1.Alert(DATA.knights.spawnText, LocalizeString("<<C:1>> (<<t:1>>)", self:GetString(knight[1]), GetAbilityName(abilityId)), knight[2], SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.sanguinePrison) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC00FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.sanguineGrasp and hitValue > 4000) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.frenzy and not LCA.isTank) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC3366FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.callLightning and hitValue < 3000) then
		Vars.chains = 0
		CA2.StatusEnable({
			ownerId = "u26b3chain",
			rowLabels = { GetString(SI_GAMEPAD_PROMOTIONAL_EVENT_COMPLETED_NARRATION), self:GetString("position") },
			pollingFunction = self.StatusPoll_B3A,
		})
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.proxLightning) then
		CA2.ScreenBorderEnable(0x99FFFFCC, 1000, "u26chain")
		LCA.PlaySounds("DUEL_FORFEIT")
		Vars.chains = Vars.chains + 1
		if (Vars.chains == 4) then
			CA2.StatusDisable()
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.falgFloor1End) then
		CA2.StatusDisable()
	elseif (DATA.meteor.ids[abilityId] and targetUnitId) then
		local currentTime = GetGameTimeMilliseconds()
		if ((result == ACTION_RESULT_EFFECT_GAINED and hitValue > 1000) or result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			local hitTime = currentTime + hitValue
			local paramId = DATA.meteor.ids[abilityId]
			if (paramId == 2 and zo_abs(Vars.ichor.endTime - hitTime) < 1600) then
				paramId = 3
			end
			Vars.meteorUnits[targetUnitId] = hitTime
			if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
				Vars.meteor.selfId = targetUnitId
			end
			local params = DATA.meteor.params[paramId]
			Vars.meteor.params = params
			Vars.meteor.duration = hitValue
			if (not Vars.meteor.bannerId and not (params.excludeTanks and LCA.isTank and targetType ~= COMBAT_UNIT_TYPE_PLAYER)) then
				Vars.meteor.bannerId = CA1.AlertBannerEx(nil, nil, nil, params.id, false, SOUNDS.CHAMPION_POINTS_COMMITTED, self.MeteorPoll)
			end
			if (self:GetSetting(params.telegraphSetting)) then
				local unitTag = LCA.IdentifyGroupUnitId(targetUnitId)
				if (unitTag) then
					CA2.WorldGrowingCircularTelegraph(unitTag, 500, hitValue, false, params.telegraphClipping)
				end
			end
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			if (Vars.meteorUnits[targetUnitId] and Vars.meteorUnits[targetUnitId] - Vars.meteor.duration < currentTime - 10) then
				Vars.meteorUnits[targetUnitId] = nil
			end
		end
	elseif (abilityId == DATA.ichorTimer) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.ichor.endTime = GetGameTimeMilliseconds() + hitValue
			Vars.ichor.counter = 0
			CA2.StatusEnable({
				ownerId = "u26b3ichor",
				rowLabels = LCA.GetAbilityName(DATA.ichorEruption),
				pollingFunction = self.StatusPoll_B3B,
			})
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.StatusDisable()
		end
	elseif (abilityId == DATA.apotheosis) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			Vars.apotId = targetUnitId
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.apotId = nil
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.hemorrhage) then
		-- Change the color of existing Instability alert
		Vars.meteor.params = DATA.meteor.params[3]
		if (targetUnitId == Vars.apotId and not LCA.isTank) then
			CA1.Alert(nil, string.format("%s — %s", LCA.GetAbilityName(abilityId), GetString(SI_LCA_BLOCK)), 0xFF99FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.bloodCounter) then
		Vars.ichor.counter = hitValue
	elseif (abilityId == DATA.toxicTide and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CA2.ScreenBorderEnable(0xFFDD0066, nil, "u26purgeables")
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.ScreenBorderDisable("u26purgeables")
		end
	end
end

do
	local NAME = Module.ID .. "LeaperMonitor"
	local active = false

	function Module:ToggleLeaperMonitor( enable )
		if (enable and not active) then
			active = true
			LCA.RegisterForFilteredEvent(NAME, EVENT_COMBAT_EVENT,
				function( _, result, _, _, _, _, sourceName, _, _, _, _, _, _, _, _, _, abilityId )
					if (LCA.DAMAGE_EVENTS[result] and DATA.lightningBolt[abilityId]) then
						CA2.ChatMessage(LocalizeString("|cCC0000<<1>>|r |H1:achievement:2816:0:0|h|h (<<2>>)", zo_iconFormatInheritColor(LCA.GetTexture("misc-x"), "100%", "100%"), sourceName), true)
						self:ToggleLeaperMonitor(false)
					end
				end,
				REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER
			)
		elseif (not enable and active) then
			active = false
			EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_COMBAT_EVENT)
		end
	end
end

function Module:GetSettingsControls( )
	return {
		--------------------
		{
			type = "checkbox",
			name = self:GetString("telegraphSpear"),
			getFunc = function() return self:GetSetting("telegraphSpear") end,
			setFunc = function(enabled) self:SetSetting("telegraphSpear", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("telegraphMeteor"),
			getFunc = function() return self:GetSetting("telegraphMeteor") end,
			setFunc = function(enabled) self:SetSetting("telegraphMeteor", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("telegraphInstability"),
			getFunc = function() return self:GetSetting("telegraphInstability") end,
			setFunc = function(enabled) self:SetSetting("telegraphInstability", enabled) end,
		},
	}
end

CA2.RegisterModule(Module)
