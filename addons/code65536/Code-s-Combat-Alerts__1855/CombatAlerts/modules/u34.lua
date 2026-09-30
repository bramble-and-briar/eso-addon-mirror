local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U34"
Module.NAME = CA2.GenerateModuleName(34, 1344)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1344, -- Dreadsail Reef
}

local ID_FDM = 166210
local ID_IDM = 166192
local ID_FWP = 168817
local ID_IWP = 168912

Module.STRINGS = {
	-- Extracted
	["8290981-0-107014"] = { default = "Reef Guardian^n", de = "Riffwächter^m", es = "guardián del arrecife^m", fr = "gardien du récif^m", jp = "サンゴのガーディアン^n", ru = "Страж Рифа^n", zh = "礁石守护者^n" },
	["8290981-0-107015"] = { default = "Tideborn Taleria^F", de = "Gezeitengeborene Taleria^F", es = "Taleria de la Marea^F", fr = "Taléria Née-des-Marées^F", jp = "タイドボーン・タレリア^F", ru = "Талерия Рожденная Приливом^F", zh = "泰德伯恩·塔勒里亚^F" },

	-- Alternative dome/weapon names (fallback to in-game name if not specified)
	[ID_FDM] = { en = "Fire Dome" },
	[ID_IDM] = { en = "Ice Dome" },
	[ID_FWP] = { en = "Axe", de = "Axt", es = "Hacha", fr = "Hache", ru = "Топор" },
	[ID_IWP] = { en = "Sword", de = "Schwert", es = "Espada", fr = "Épée", ru = "Меч" },

	-- Reef Guardian labels
	boss1 = { default = "L", zh = "大" },
	boss2 = { default = "M1", zh = "中1" },
	boss3 = { default = "S1", zh = "小1" },
	boss4 = { default = "S2", zh = "小2" },
	boss5 = { default = "M2", zh = "中2" },

	-- Custom (Alerts)
	teleportCounter = { default = "<<i:1>> Teleport Position" },
	bridgeStatusLabel = { default = "Channelers" },
	delugeSwim = { default = "Swim!" },

	-- Custom (Settings)
	statusPanel = { default = "Enable status panel" },
	portSounds = { default = "Sound chime for summoning each teleport location" },
	extraSounds = { default = "Additional audio cues" },
	clockLabels = { default = "Show clock numbers for Veteran Taleria" },
	bridgeExitMarkers = { default = "Mark exit points for active bridges" },
	showWaveAlert = { default = "Show timer for Crashing Wave targeting others" },
	showLure = { default = "Show timer for Lure of the Sea" },
	delugeBlame = { default = "List non-swimming players with Rapid Deluge" },
}

Module.DEFAULT_SETTINGS = {
	statusPanel = true,
	portSounds = false,
	extraSounds = true,
	clockLabels = true,
	bridgeExitMarkers = true,
	showWaveAlert = true,
	showLure = false,
	delugeBlame = false,
}

local COLOR_FIRE = 0xFF6600FF
local COLOR_ICE  = 0x66CCFFFF

local COLOR_F_WP = 0xFFCC00FF
local COLOR_I_WP = 0x3399FFFF

local COLOR_BR_Y = 0xFFFF00FF
local COLOR_BR_G = 0x00CC00FF
local COLOR_BR_P = 0xCC00CCFF

Module.DATA = {
	banners_begin = {
		[ID_FWP] = COLOR_F_WP, -- Incendiary Axe
		[ID_IWP] = COLOR_I_WP, -- Calamitous Sword
		[166928] = 0x66CCFFFF, -- Summon Behemoth
		[166929] = 0x9966FFFF, -- Summon Siren
	},
	targeted = 170523,
	cinderShot = 170409,
	marksman = {
		target = 170434,
		damage = 170438,
	},

	-- Boss 1
	multi = {
		[166745] = ID_IWP, -- Turlassil MultiLoc
		[166909] = ID_FWP, -- Lylanar MultiLoc
	},
	imminent = {
		[166522] = true, -- Imminent Blister
		[166527] = true, -- Imminent Chill
	},
	fragility = {
		[166525] = COLOR_F_WP, -- Blistering Fragility
		[166529] = COLOR_I_WP, -- Chilling Fragility
	},
	waves = {
		[169587] = COLOR_F_WP, -- Scalding Swell
		[169594] = COLOR_I_WP, -- Biting Billow
	},
	summon_atroEffect = {
		[168713] = COLOR_FIRE, -- Summon Iron Atronach
		[168722] = COLOR_ICE , -- Summon Frost Atronach
	},
	summon_atroBegin = {
		[167763] = COLOR_FIRE, -- Summon Iron Atronach
		[167900] = COLOR_ICE , -- Summon Frost Atronach
	},
	twinsColors = { COLOR_FIRE, COLOR_ICE },
	weaponColors = { COLOR_F_WP, COLOR_I_WP },
	dome = {
		[ID_FDM] = COLOR_FIRE * 2 + 0, -- Destructive Ember
		[ID_IDM] = COLOR_ICE  * 2 + 1, -- Piercing Hailstone
	},
	domeCooldown = {
		[166208] = 1, -- Destructive Ember
		[166194] = 2, -- Piercing Hailstone
	},
	rescueCast = {
		-- Index is reversed since it is of the dome holder who needs to conduct the rescue
		[167466] = 2, -- Charred Constriction
		[167545] = 1, -- Frigidarium
	},
	rescueEffect = {
		[167491] = true, -- Charred Constriction
		[167563] = true, -- Frigidarium
	},
	nextWeaponIds = {
		[ID_FWP] = ID_IWP, -- Incendiary Axe
		[ID_IWP] = ID_FWP, -- Calamitous Sword
	},
	brands = {
		[166358] = COLOR_FIRE, -- Firebrand
		[166445] = COLOR_ICE, -- Frostbrand
	},

	-- Boss 2
	reefTags = { "boss1", "boss2", "boss5", "boss3", "boss4" },
	replication = 163701,
	heartburn = 170481,
	heartburnResult = {
		[166031] = { color = 0x00FF00, text = GetString(SI_LCA_SUCCESS) }, -- Heartburn Vulnerability
		[166032] = { color = 0xFF0000, text = GetString(SI_LCA_FAIL) }, -- Heartburn Empowerment
	},

	-- Boss 3
	deluge = {
		start = 167124,
		icon = 174966,
		[SI_LCA_TARGET_YOU] = 0x3399FFFF,
		[SI_LCA_TARGET_OTHERS] = 0xBBDDFFFF,
		[174959] = true, -- Normal
		[174960] = true, -- Veteran
		[174961] = true, -- Hard Mode
		damage = {
			[174964] = true, -- Normal
			[174966] = true, -- Veteran
			[174969] = true, -- Hard Mode
		},
	},
	storm = {
		name = 174865,
		tracker = 174891,
		[175447] = 1,
		[174866] = -1,
	},
	bridge = {
		platform = 167704,
		stop = 169297,
		summons = {
			[166479] = 1, -- Summon Channelers (50%)
			[175279] = 2, -- Summon Channelers (35%)
			[175291] = 3, -- Summon Channelers (20%)
		},
		channelers = {
			[175134] = COLOR_BR_Y, -- Sweltering Heat
			[175132] = COLOR_BR_G, -- Nematocyst Cloud
			[175136] = COLOR_BR_P, -- Suffocating Waves
		},
		channels = {
			[165994] = COLOR_BR_Y, -- Sweltering Heat
			[166042] = COLOR_BR_G, -- Nematocyst Cloud
			[166044] = COLOR_BR_P, -- Suffocating Waves
		},
		locationsA = {	-- Allies
			[COLOR_BR_Y] = { 171930, 36126, 31714 },
			[COLOR_BR_G] = { 170016, 36126, 27519 },
			[COLOR_BR_P] = { 167440, 36126, 31439 },
		},
		locationsE = {	-- Enemies
			[COLOR_BR_Y] = { 171816, 36126, 31833 },
			[COLOR_BR_G] = { 170711, 36126, 27252 },
			[COLOR_BR_P] = { 166977, 36126, 31339 },
		},
	},
	maelstrom = 166292,
	wave = {
		start = 166353,
		target = 174943,
		damage = 174948,
	},
	lure = 163952,
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_BOSSES = true
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		[150308] = { -2, 2 }, -- Power Bash (Daihjara-la; same as Rockgrove's Havocrel Goliath)
		[159864] = { -2, 2 }, -- Monstrous Claw (Spirit Crab Broodmother)
		[163987] = { -2, 2 }, -- Coral Slam
		[166019] = { -2, 2 }, -- Crush
		[166020] = { -2, 2 }, -- Claw
		[166582] = { -2, 2 }, -- Monstrous Claw (Reef Guardian)
		[166586] = { -2, 2 }, -- Crackdown
		[167273] = { -2, 0, false, { 1, 0, 0.6, 0.8 }, offset = -875 }, -- Broiling Hew
		[167280] = { -2, 0, false, { 1, 0, 0.6, 0.8 }, offset = -875 }, -- Stinging Shear
		[169096] = { -2, 0, false, { 1, 0, 0.6, 0.8 }, offset = -1900 }, -- Concussive Blow
		[169253] = { -2, 0, false, { 1, 0, 0.6, 0.8 }, offset = -1900 }, -- Brutal Bash
		[169981] = { -2, 2 }, -- Whirling Dervish
		[169991] = { -2, 2 }, -- Wing Slice
		[170184] = { -2, 2 }, -- Uppercut
		[170188] = { -2, 1 }, -- Cascading Boot
		[170192] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Shield Slam
		[174607] = { -3, 2, true }, -- Taking Aim
	--	[164158] = { -2, 0 }, -- Crush
	--	[164160] = { -2, 0 }, -- Strike
	--	[164162] = { -2, 0 }, -- Hack
	--	[164164] = { -2, 0 }, -- Drowning Strike
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[163896] = { 1100, false }, -- Whirlpool
		[165987] = { 1100, true }, -- Acid Pool
		[168619] = { 600, true }, -- Frigid Blood
		[168625] = { 600, true }, -- Blazing Bead
		[175172] = { 1000, true }, -- Arcing Slash
	}

	self.vars = {
		twinsHM = false,
		twinsSplit = false,
		domeCooldown = { },
		domeHolder = { },
		rescueUnits = { },
		multi = {
			previous = 0,
			count = 0,
			id = -1,
		},
		nextWeaponId = nil,
		prevWeaponTime = { },
		numWeapons = { },
		guardians = {
			hearts = 0,
			units = { },
			statuses = { },
		},
		wave = {
			stop = 0,
			targeted = false,
		},
		deluge = {
			type = SI_LCA_TARGET_OTHERS,
			units = { },
			eruptionTime = 0,
		},
		bridge = {
			channels = { },
			units = { },
		},
		maelstrom = {
			prev = 0,
			duration = 0,
		},
		stormEnd = 0,
		stormIcon = "",
	}
	Vars = self.vars

	-- Boss 1 ------------------------------------------------------------------

	self.StartBoss1Panel = function( )
		if (self:GetSetting("statusPanel") and CA2.StatusGetOwnerId() ~= "u34b1") then
			local rowLabels = {
				[3] = GetString("SI_ATTRIBUTES", ATTRIBUTE_HEALTH),
				[4] = LCA.GetAbilityName(167637),
				[5] = GetString("SI_GAMEPADITEMCATEGORY", GAMEPAD_ITEM_CATEGORY_WEAPONS),
			}
			for abilityId, data in pairs(DATA.dome) do
				rowLabels[data % 2 + 1] = self:GetCustomizedAbilityName(abilityId)
			end
			CA2.StatusEnable({
				ownerId = "u34b1",
				rowLabels = rowLabels,
				pollingFunction = self.StatusPoll_B1,
				initFunction = self.StatusInit_B1,
			})
		end
	end

	self.StatusInit_B1 = function( )
		Vars.twinsHM = false
		Vars.twinsSplit = false
		ZO_ClearTable(Vars.domeCooldown)
		ZO_ClearTable(Vars.domeHolder)
		ZO_ClearTable(Vars.rescueUnits)
		ZO_ClearTable(Vars.numWeapons)
		for _, data in pairs(DATA.dome) do
			local r = data % 2 + 1
			CA2.StatusModifyCell(r, 0,
				"text", "",
				"color", 0xCC0000FF
			)
			CA2.StatusModifyCell(r, 1,
				"color", BitRShift(data, 1)
			)
			CA2.StatusModifyCell(r, 2,
				"text", "",
				"alignment", TEXT_ALIGN_RIGHT,
				"minWidth", "00×"
			)
		end
		CA2.StatusSetRowAlpha(4, 0)
		CA2.StatusSetRowAlpha(5, 0)
	end

	self.StatusPoll_B1 = function( )
		-- Dome cooldowns; general dome status is event-driven, not polled
		local currentTime = GetGameTimeMilliseconds()
		for r = 1, 2 do
			local remaining = (Vars.domeCooldown[r] or 0) - currentTime
			if (remaining > 0) then
				CA2.StatusSetCellText(r, 0, string.format("%s: %s", GetString(SI_ABILITY_TOOLTIP_COOLDOWN), LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT)))
			else
				CA2.StatusSetCellText(r, 0, "")
			end
		end

		-- Boss health
		local results = { }
		for i = 1, 2 do
			table.insert(results, string.format("|c%06X%d%%|r", LCA.RemoveAlpha(DATA.twinsColors[i]), zo_floor(LCA.GetUnitHealthPercent("boss" .. i))))
		end
		CA2.StatusSetCellText(3, 2, table.concat(results, " / "))

		-- Rescue
		if (next(Vars.rescueUnits)) then
			CA2.StatusSetCellText(4, 2, zo_strformat(SI_LCA_PLAYERS_COUNT, NonContiguousCount(Vars.rescueUnits)))
			CA2.StatusSetRowAlpha(4, 1)
		else
			CA2.StatusSetRowAlpha(4, 0)
		end

		-- Weapons
		if (Vars.twinsHM and Vars.twinsSplit) then
			ZO_ClearTable(results)
			for i = 1, 2 do
				local color = DATA.weaponColors[i]
				table.insert(results, string.format("|c%06X%d×|r", LCA.RemoveAlpha(color), Vars.numWeapons[color] or 0))
			end
			if (Vars.nextWeaponId) then
				local color = DATA.banners_begin[Vars.nextWeaponId]
				table.insert(results, string.format("%s: |c%06X%s|r", GetString(SI_SCREEN_NARRATION_DIRECTIONAL_INPUT_NEXT), LCA.RemoveAlpha(color), self:GetCustomizedAbilityName(Vars.nextWeaponId)))
				if (Vars.prevWeaponTime[Vars.nextWeaponId]) then
					local time = currentTime - Vars.prevWeaponTime[Vars.nextWeaponId]
					local thresholdStart, thresholdYellow, thresholdRed, color = 30000, 40000, 50000
					if (time >= thresholdYellow) then
						local ratio = 1 - zo_clamp((time - thresholdYellow) / (thresholdRed - thresholdYellow), 0, 1)
						color = LCA.PackRGBA(LCA.HSLToRGB(ratio / 6, 1, 0.5, 1))
					elseif (time >= thresholdStart) then
						color = 0xFFFFFFFF
					else
						color = 0xFFFFFF99
					end
					CA2.StatusModifyCell(5, 0, "text", zo_strformat(SI_LCA_TIME_SINCE_PREVIOUS, LCA.FormatTime(time, LCA.TIME_FORMAT_SHORT)), "color", color)
				else
					CA2.StatusSetCellText(5, 0, "")
				end
			end
			CA2.StatusSetCellText(5, 2, table.concat(results, " / "))
			CA2.StatusSetRowAlpha(5, 1)
		end
	end

	self.DomeEffect = function( _, changeType, _, _, unitTag, _, _, stackCount, _, _, _, _, _, _, _, abilityId )
		local r = DATA.dome[abilityId] % 2 + 1
		if (changeType ~= EFFECT_RESULT_FADED) then
			local name = GetUnitDisplayName(unitTag)
			if (name and name ~= "") then
				self.StartBoss1Panel()
				local thresholdStart, thresholdYellow, thresholdRed, color = 10, 20, 30
				if (stackCount >= thresholdYellow) then
					local ratio = 1 - zo_clamp((stackCount - thresholdYellow) / (thresholdRed - thresholdYellow), 0, 1)
					color = LCA.PackRGBA(LCA.HSLToRGB(ratio / 6, 1, 0.5, 1))
				elseif (stackCount >= thresholdStart) then
					color = 0xFFFFFFFF
				else
					color = 0xFFFFFF99
				end
				CA2.StatusModifyCell(r, 2,
					"text", string.format("%d×", stackCount),
					"color", color
				)
				CA2.StatusSetCellText(r, 3, name)
			end
			Vars.domeHolder[r] = unitTag
		else
			CA2.StatusSetCellText(r, 2, "")
			CA2.StatusSetCellText(r, 3, "")
			Vars.domeHolder[r] = nil
		end
	end

	-- Boss 2 ------------------------------------------------------------------

	self.StartBoss2Panel = function( )
		if (self:GetSetting("statusPanel") and CA2.StatusGetOwnerId() ~= "u34b2") then
			CA2.StatusEnable({
				ownerId = "u34b2",
				rowLabels = GetUnitName("boss1"),
				pollingFunction = self.StatusPoll_B2,
				initFunction = self.StatusInit_B2,
			})
		end
	end

	self.StatusInit_B2 = function( )
		Vars.guardians.hearts = 0
		ZO_ClearTable(Vars.guardians.units)
		ZO_ClearTable(Vars.guardians.statuses)
		CA2.StatusModifyCell(1, 2,
			"text", "",
			"alignment", TEXT_ALIGN_CENTER,
			"minWidth", "M2"
		)
		CA2.StatusModifyCell(1, 3,
			"text", "",
			"alignment", TEXT_ALIGN_RIGHT,
			"minWidth", "100%"
		)
	end

	local reefs -- Scratch table
	local defaultReefStatus = string.format("|c00FFFF%s|r", GetString(SI_LCA_ACTIVE))
	self.StatusPoll_B2 = function( )
		local currentTime = GetGameTimeMilliseconds()

		if (reefs) then
			for _, tbl in pairs(reefs) do
				ZO_ClearTable(tbl)
			end
		else
			reefs = { { }, { }, { }, hearts = { }, statuses = { } }
		end

		-- Heartburn status
		local hearts = reefs.hearts
		for unitId, heart in pairs(Vars.guardians.units) do
			local unitTag = LCA.IdentifyBossUnitId(unitId)
			if (unitTag) then
				local remaining = heart.stop - currentTime
				local ratio = zo_clamp(remaining / heart.duration, 0, 1)
				hearts[unitTag] = string.format(
					"|cFFFF00%s|r %d (|c%06X%s|r)",
					LCA.GetAbilityName(DATA.heartburn),
					heart.number,
					LCA.PackRGB(LCA.HSLToRGB(ratio / 3, 1, 0.5, 1)),
					LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT)
				)
			end
		end

		-- General status
		local statuses = reefs.statuses
		for unitId, status in pairs(Vars.guardians.statuses) do
			local unitTag = LCA.IdentifyBossUnitId(unitId)
			if (unitTag) then
				statuses[unitTag] = string.format(" (|c%06X%s|r)", status.color, status.text)
			end
		end

		-- Boss status
		local valid = false
		for _, unitTag in ipairs(DATA.reefTags) do
			local health = LCA.GetUnitHealthPercent(unitTag)
			if (health > 0) then
				valid = true
				table.insert(reefs[1], self:GetString(unitTag))
				table.insert(reefs[2], string.format("%d%%", zo_floor(health)))
				table.insert(reefs[3], string.format("%s%s", hearts[unitTag] or defaultReefStatus, statuses[unitTag] or ""))
			end
		end
		if (valid) then
			for i = 1, 3 do
				CA2.StatusSetCellText(1, i + 1, table.concat(reefs[i], "\n"))
			end
		else
			CA2.StatusDisable()
		end
	end

	-- Boss 3 ------------------------------------------------------------------

	self.StartBoss3Panel = function( )
		if (self:GetSetting("statusPanel") and CA2.StatusGetOwnerId() ~= "u34b3") then
			CA2.StatusEnable({
				ownerId = "u34b3",
				rowLabels = { LCA.GetAbilityName(DATA.maelstrom), LCA.GetAbilityName(DATA.storm.name), self:GetString("bridgeStatusLabel") },
				pollingFunction = self.StatusPoll_B3,
			})
		end
	end

	self.StatusPoll_B3 = function( )
		local currentTime = GetGameTimeMilliseconds()

		-- Maelstrom
		local time = currentTime - Vars.maelstrom.prev
		local remain = Vars.maelstrom.duration - time
		if (remain > -500) then
			CA2.StatusSetCellText(1, 2, zo_strformat(SI_LCA_TIME_REMAINING, LCA.FormatTime(remain, LCA.TIME_FORMAT_COUNTDOWN)))
			CA2.StatusSetRowColor(1, 0xFF6666FF)
		else
			CA2.StatusSetCellText(1, 2, zo_strformat(SI_LCA_TIME_SINCE_PREVIOUS, LCA.FormatTime(time, LCA.TIME_FORMAT_SHORT)))
			CA2.StatusSetRowColor(1, time <= 29000 and 0xFFFFFFFF or 0xFF9900FF)
		end

		-- Winter Storm
		time = Vars.stormEnd - currentTime
		if (time > 0) then
			CA2.StatusSetCellText(2, 2, string.format("%s  %s", LCA.FormatTime(time, LCA.TIME_FORMAT_COUNTDOWN), Vars.stormIcon))
			CA2.StatusSetRowAlpha(2, 1)
		else
			CA2.StatusSetRowAlpha(2, 0)
		end

		-- Summon Channelers
		local results = { }
		for i, channel in ipairs(Vars.bridge.channels) do
			if (channel.time) then
				local remaining = channel.time - currentTime
				if (channel.time == 0 or remaining > -2000) then
					table.insert(results, string.format("#%d: |c%06X%s|r%s", i, LCA.RemoveAlpha(channel.color), channel.name, channel.time > 0 and string.format(" (%s)", LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT)) or ""))
				end
			end
		end
		if (#results > 0) then
			CA2.StatusSetCellText(3, 2, table.concat(results, "\n"))
			CA2.StatusSetRowHidden(3, false)
		else
			CA2.StatusSetRowHidden(3, true)
		end
	end
end

function Module:PostLoad( )
	for abilityId in pairs(DATA.dome) do
		LCA.RegisterForFilteredEvent(Module.ID .. abilityId, EVENT_EFFECT_CHANGED,
			self.DomeEffect,
			REGISTER_FILTER_ABILITY_ID, abilityId,
			REGISTER_FILTER_UNIT_TAG_PREFIX, "group"
		)
	end
end

function Module:PreUnload( )
	for abilityId in pairs(DATA.dome) do
		EVENT_MANAGER:UnregisterForEvent(Module.ID .. abilityId, EVENT_EFFECT_CHANGED)
	end
	self:ToggleTaleriaClockLabels(false)
end

function Module:OnBossesChanged( )
	if (LCA.MatchStrings(GetUnitName("boss1"), self:GetString("8290981-0-107014")) and LCA.GetUnitHealthPercent("boss1") > 0) then
		self.StartBoss2Panel()
	end
	self:ToggleTaleriaClockLabels(LCA.isVet and self:GetSetting("clockLabels") and LCA.MatchStrings(GetUnitName("boss1"), self:GetString("8290981-0-107015")))
end

function Module:PreStartListening( )
	ZO_ClearTable(Vars.bridge.channels)
	ZO_ClearTable(Vars.bridge.units)
	Vars.bridge.order = nil
end

function Module:PostStopListening( )
	CA2.StatusDisable()
	self:ClearAllBridgeLocations()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- General
	if (result == ACTION_RESULT_BEGIN and DATA.banners_begin[abilityId]) then
		local color = DATA.banners_begin[abilityId]
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), color, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		if (DATA.nextWeaponIds[abilityId]) then
			Vars.nextWeaponId = DATA.nextWeaponIds[abilityId]
			Vars.prevWeaponTime[abilityId] = GetGameTimeMilliseconds()
			Vars.numWeapons[color] = (Vars.numWeapons[color] or 0) + 1
		end
	elseif (targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.targeted) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			CA2.ScreenBorderEnable(0xAA00FF77, hitValue, "u34target")
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 200, "DUEL_BOUNDARY_WARNING", 2, 150, "FRIEND_INVITE_RECEIVED", 2)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.ScreenBorderDisable("u34target")
		end
	elseif (result == ACTION_RESULT_BEGIN and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.cinderShot and hitValue > 2000) then
		CA1.Alert(nil, zo_strformat(SI_LCA_TARGET_YOU, LCA.GetAbilityName(abilityId)), 0xFF9900FF, nil, 1500)
		LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 3)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.marksman.target) then
		local id = CA1.AlertCast(DATA.marksman.damage, sourceName, 3000, { -3, 2, true })
		if (LCA.IsUnitIdValid(sourceUnitId)) then
			self.castSources[sourceUnitId] = id
		end

	-- Boss 1
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.multi[abilityId]) then
		-- Reset the counter
		local multi = Vars.multi
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - multi.previous > 10000) then
			multi.previous = currentTime
			multi.count = 0
			if (not Vars.twinsSplit and LCA.GetUnitHealthPercent("boss1") < 100 and LCA.GetUnitHealthPercent("boss2") < 100) then
				Vars.twinsSplit = true
				Vars.nextWeaponId = DATA.multi[abilityId]
				ZO_ClearTable(Vars.prevWeaponTime)
			end
		end
		multi.count = multi.count + 1
		local bannerText = zo_strformat(self:GetString("teleportCounter"), multi.count)
		if (multi.count == 1) then
			multi.id = CA1.StartBanner(nil, bannerText, 0xFF3333FF, nil, true, nil, true)
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 5)
			zo_callLater(function()
				CA1.DisableBanner(multi.id)
			end, 6500)
		else
			CA1.ModifyBanner(multi.id, nil, bannerText, 0xFF3333FF)
			if (self:GetSetting("portSounds")) then
				LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 2)
			end
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.imminent[abilityId]) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF00CCFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		elseif (LCA.DoesPlayerHaveTauntSlotted()) then
			local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
			CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xFF00CCFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		end
	elseif (targetType == COMBAT_UNIT_TYPE_PLAYER and DATA.fragility[abilityId]) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.currentFragility = DATA.fragility[abilityId]
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.currentFragility = nil
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.waves[abilityId]) then
		local alertLevel = 1 -- Default alert level
		local color = DATA.waves[abilityId]
		Vars.numWeapons[color] = zo_max((Vars.numWeapons[color] or 0) - 1, 0)
		if (Vars.currentFragility == color) then
			alertLevel = 2
		elseif (LCA.isTank) then
			alertLevel = 0 -- Suppress for tanks with no matching fragility
		end
		if (alertLevel > 0) then
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), color, nil, 2000)
			if (not self:GetSetting("extraSounds")) then
				LCA.PlaySounds("CHAMPION_POINTS_COMMITTED")
			elseif (alertLevel == 1) then
				LCA.PlaySounds("INSTANCE_SHUTDOWN", 4)
			else
				LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 3)
			end
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.summon_atroEffect[abilityId]) then
		Vars.twinsHM = true
		if (LCA.DoesPlayerHaveTauntSlotted()) then
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), DATA.summon_atroEffect[abilityId], SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.summon_atroBegin[abilityId] and LCA.DoesPlayerHaveTauntSlotted()) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), DATA.summon_atroBegin[abilityId], SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.brands[abilityId] and targetType == COMBAT_UNIT_TYPE_PLAYER and hitValue == 1) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (targetType == COMBAT_UNIT_TYPE_PLAYER and DATA.domeCooldown[abilityId]) then
		local index = DATA.domeCooldown[abilityId]
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.domeCooldown[index] = GetGameTimeMilliseconds() + hitValue
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.domeCooldown[index] = 0
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.rescueCast[abilityId]) then
		ZO_ClearTable(Vars.rescueUnits)
		local holderUnitTag = Vars.domeHolder[DATA.rescueCast[abilityId]]
		if (holderUnitTag and AreUnitsEqual(holderUnitTag, "player") and self:GetSetting("extraSounds")) then
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 3)
		end
	elseif (targetUnitId and DATA.rescueEffect[abilityId]) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.rescueUnits[targetUnitId] = true
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.rescueUnits[targetUnitId] = nil
		end

	-- Boss 2
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.replication) then
		self.StartBoss2Panel()
		if (LCA.IsUnitIdValid(targetUnitId)) then
			Vars.guardians.statuses[targetUnitId] = {
				color = 0xFF00FF,
				text = LCA.GetAbilityName(abilityId),
			}
			zo_callLater(function() Vars.guardians.statuses[targetUnitId] = nil end, hitValue)
		end
	elseif (abilityId == DATA.heartburn and LCA.IsUnitIdValid(targetUnitId)) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.guardians.hearts = Vars.guardians.hearts + 1
			Vars.guardians.units[targetUnitId] = {
				number = Vars.guardians.hearts,
				stop = GetGameTimeMilliseconds() + hitValue,
				duration = hitValue,
			}
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.guardians.units[targetUnitId] = nil
		end
	elseif (DATA.heartburnResult[abilityId] and LCA.IsUnitIdValid(targetUnitId)) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.guardians.statuses[targetUnitId] = DATA.heartburnResult[abilityId]
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.guardians.statuses[targetUnitId] = nil
		end

	-- Boss 3
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.wave.start) then
		Vars.wave.stop = GetGameTimeMilliseconds() + hitValue
		Vars.wave.targeted = false
		zo_callLater(function()
			if (self:GetSetting("showWaveAlert") or Vars.wave.targeted) then
				CA1.AlertCast(DATA.wave.damage, nil, Vars.wave.stop - GetGameTimeMilliseconds(), Vars.wave.targeted and { 750, 2 } or { 750, 0, false, { 0.8, 1, 1, 0.4 }, { 0.6, 1, 1, 0.6 } })
			end
		end, 300)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.wave.target and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		Vars.wave.targeted = true
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.lure and targetType == COMBAT_UNIT_TYPE_PLAYER and self:GetSetting("showLure")) then
		local id = CA1.AlertCast(abilityId, sourceName, hitValue, { 0, 0, true, { 1, 0, 1, 0.4 } })
		if (LCA.IsUnitIdValid(sourceUnitId)) then
			self.castSources[sourceUnitId] = id
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.deluge.start) then
		Vars.deluge.type = SI_LCA_TARGET_OTHERS
		ZO_ClearTable(Vars.deluge.units)
	elseif (result == ACTION_RESULT_DAMAGE and DATA.deluge.damage[abilityId] and self:GetSetting("delugeBlame")) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - Vars.deluge.eruptionTime > 1000) then
			Vars.deluge.eruptionTime = currentTime
			local landlubbers = { }
			for unitTag, swimming in pairs(Vars.deluge.units) do
				if (not swimming) then
					table.insert(landlubbers, GetUnitDisplayName(unitTag))
				end
			end
			if (#landlubbers > 0) then
				CA2.ChatMessage(string.format("%s: %s", LCA.GetAbilityName(abilityId), table.concat(landlubbers, ", ")))
			end
			EVENT_MANAGER:UnregisterForUpdate(self.ID)
		end
	elseif (targetUnitId and DATA.deluge[abilityId]) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			LCA.CoalescedDelayedCall("u34deluge", 10, function( )
				CA1.Alert(nil, zo_strformat(Vars.deluge.type, LCA.GetAbilityName(abilityId)), DATA.deluge[Vars.deluge.type], nil, hitValue)
				if (self:GetSetting("delugeBlame")) then
					Vars.deluge.pollingStop = GetGameTimeMilliseconds() + hitValue + 500
					EVENT_MANAGER:RegisterForUpdate(self.ID, 10, function( )
						if (GetGameTimeMilliseconds() >= Vars.deluge.pollingStop) then
							EVENT_MANAGER:UnregisterForUpdate(self.ID)
						else
							for unitTag in pairs(Vars.deluge.units) do
								Vars.deluge.units[unitTag] = IsUnitSwimming(unitTag)
							end
						end
					end)
				end
			end)

			if (self:GetSetting("delugeBlame")) then
				local unitTag = LCA.IdentifyGroupUnitId(targetUnitId)
				if (unitTag) then
					Vars.deluge.units[unitTag] = true
				end
			end

			if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
				Vars.deluge.type = SI_LCA_TARGET_YOU
				CA1.CastAlertsStart(DATA.deluge.icon, LCA.GetAbilityName(abilityId), hitValue, nil, { 0.3, 0.9, 1, 0.6 }, { 1750, self:GetString("delugeSwim"), 0, 0.5, 1, 1, SOUNDS.FRIEND_INVITE_RECEIVED })
				LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 3, 200, "DUEL_BOUNDARY_WARNING", 1, 150, "DUEL_BOUNDARY_WARNING", 2, 150, "DUEL_BOUNDARY_WARNING", 3)
			end
		end
	elseif (abilityId == DATA.storm.tracker) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.stormEnd = GetGameTimeMilliseconds() + hitValue
			Vars.stormIcon = ""
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.stormEnd = 0
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.storm[abilityId]) then
		local texture = LCA.GetTexture("arrow-rotate")
		local orientation = DATA.storm[abilityId]
		CA1.Alert(nil, string.format("%s  %s", LCA.GetAbilityName(abilityId), zo_iconFormatInheritColor(texture, 64, 64 * orientation)), 0x00CCCCFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		Vars.stormIcon = zo_iconFormatInheritColor(texture, 32, 32 * orientation)
	elseif (abilityId == DATA.maelstrom) then
		if (result == ACTION_RESULT_BEGIN and hitValue == 500) then
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCCCC66FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.maelstrom = {
				prev = GetGameTimeMilliseconds(),
				duration = hitValue,
			}
			self.StartBoss3Panel()
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.maelstrom.duration = 0
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.bridge.summons[abilityId] and hitValue > 1000 and LCA.isVet) then
		Vars.bridge.order = DATA.bridge.summons[abilityId]
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.bridge.channelers[abilityId] and hitValue == 1) then
		local message = LCA.GetAbilityName(DATA.bridge.platform)
		if (Vars.bridge.order) then
			message = string.format("%s #%d", message, Vars.bridge.order)
			Vars.bridge.order = nil
		end
		local color = DATA.bridge.channelers[abilityId]
		CA1.Alert(nil, message, color, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
		self:ToggleBridgeLocation(color, true)
	elseif (result == ACTION_RESULT_BEGIN and DATA.bridge.channels[abilityId] and LCA.IsUnitIdValid(targetUnitId)) then
		if (hitValue < 5000) then
			table.insert(Vars.bridge.channels, {
				name = LCA.GetAbilityName(abilityId),
				color = DATA.bridge.channels[abilityId],
				time = 0,
			})
			Vars.bridge.units[targetUnitId] = #Vars.bridge.channels
		elseif (Vars.bridge.units[targetUnitId]) then
			Vars.bridge.channels[Vars.bridge.units[targetUnitId]].time = GetGameTimeMilliseconds() + hitValue
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.bridge.stop and targetUnitId and Vars.bridge.units[targetUnitId]) then
		local bridgeChannel = Vars.bridge.channels[Vars.bridge.units[targetUnitId]]
		Vars.bridge.units[targetUnitId] = nil
		bridgeChannel.time = nil
		self:ToggleBridgeLocation(bridgeChannel.color, false)
	end
end

function Module:GetCustomizedAbilityName( abilityId )
	return self:GetString(abilityId) or LCA.GetAbilityName(abilityId)
end

function Module:GetSettingsControls( )
	return {
		--------------------
		{
			type = "checkbox",
			name = self:GetString("statusPanel"),
			getFunc = function() return self:GetSetting("statusPanel") end,
			setFunc = function(enabled) self:SetSetting("statusPanel", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("portSounds"),
			getFunc = function() return self:GetSetting("portSounds") end,
			setFunc = function(enabled) self:SetSetting("portSounds", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("extraSounds"),
			getFunc = function() return self:GetSetting("extraSounds") end,
			setFunc = function(enabled) self:SetSetting("extraSounds", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("clockLabels"),
			getFunc = function() return self:GetSetting("clockLabels") end,
			setFunc = function( enabled )
				self:SetSetting("clockLabels", enabled)
				self:OnBossesChanged()
			end,
		},
		--------------------
		{
			type = "dropdown",
			name = self:GetString("bridgeExitMarkers"),
			choices = { GetString(SI_CHECK_BUTTON_OFF), GetString(SI_TARGETTYPE1), GetString(SI_TARGETTYPE0) },
			choicesValues = { false, true, 2 },
			getFunc = function() return self:GetSetting("bridgeExitMarkers") end,
			setFunc = function(mode) self:SetSetting("bridgeExitMarkers", mode) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("showWaveAlert"),
			getFunc = function() return self:GetSetting("showWaveAlert") end,
			setFunc = function(enabled) self:SetSetting("showWaveAlert", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("showLure"),
			getFunc = function() return self:GetSetting("showLure") end,
			setFunc = function(enabled) self:SetSetting("showLure", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("delugeBlame"),
			getFunc = function() return self:GetSetting("delugeBlame") end,
			setFunc = function(enabled) self:SetSetting("delugeBlame", enabled) end,
		},
	}
end

-- Taleria clock labels
do
	local active = false

	function Module:ToggleTaleriaClockLabels( enable )
		if (enable and not active) then
			active = true

			local X, Y, ELEVATION = 169780, 30040, 36126
			local HOUR_ANGLE = ZO_TWO_PI / 12
			local DISTANCE = 2100

			for i = 1, 12 do
				local angle = (9 - i) * HOUR_ANGLE
				CA2.WorldTexturePlace({
					pos = { X - DISTANCE * math.sin(angle), ELEVATION, Y - DISTANCE * math.cos(angle) },
					texture = "world-circle-bordered",
					size = 250,
					color = 0x33CCCC33,
					groundAngle = angle + ZO_PI,
					disableDepthBuffers = true,
					groundOverlay = {
						texture = "world-num-" .. i,
						size = 250,
						color = 0xFFFFFFCC,
					},
				})
			end
		elseif (not enable and active) then
			active = false
			CA2.WorldCanvasClear()
		end
	end
end

-- Taleria bridge locations, using its own separate canvas
do
	local Elements = { }
	local Canvas
	local function GetCanvas( )
		if (not Canvas) then
			Canvas = LCA.WorldDrawing:New()
		end
		return Canvas
	end

	function Module:ToggleBridgeLocation( color, enable )
		if (enable and not Elements[color]) then
			local mode = self:GetSetting("bridgeExitMarkers")
			local locations = DATA.bridge[mode == true and "locationsA" or "locationsE"]
			if (mode and locations[color]) then
				Elements[color] = GetCanvas():PlaceTexture({
					pos = locations[color],
					texture = "world-teardrop-down",
					size = 160,
					elevation = 90,
					color = BitAnd(color, 0xFFFFFF99),
					playerFacing = true,
				})
			end
		elseif (not enable and Elements[color]) then
			Canvas:RemoveElement(Elements[color])
			Elements[color] = nil
		end
	end

	function Module:ClearAllBridgeLocations( )
		if (Canvas) then -- No point in clearing a canvas if one hasn't been created
			Canvas:Clear()
			ZO_ClearTable(Elements)
		end
	end
end

CA2.RegisterModule(Module)
