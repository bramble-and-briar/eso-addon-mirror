local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U42"
Module.NAME = CA2.GenerateModuleName(42, 1478)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1478, -- Lucent Citadel
}

Module.STRINGS = {
	-- Extracted
	["8290981-0-121169"] = { default = "Orphic Shattered Shard^N", de = "orphische Splitterscherbe^f", es = "fragmento destrozado órfico^m", fr = "fragment brisé orphique^m", jp = "オーフィックの砕けた欠片^n", ru = "Таинственный осколочник^N", zh = "神秘破裂碎片" },
	["8290981-0-121484"] = { default = "Shardborn Lightweaver^f", de = "Scherbensaat-Lichtweberin^f", es = "tejedora de luz nacida de la esquirla^f", fr = "tisse-lumière Enfant du fragment^f", jp = "シャードボーン・ライトウィーバー^f", ru = "Ткачиха света из клана Детей Осколков^f", zh = "碎晶族织光者" },
	["8290981-0-121485"] = { default = "Gloomy Blackguard^f", de = "düstere Schwarzwache^f", es = "guardia negra lúgubre^f", fr = "garde-obscurité sinistre^m", jp = "薄暗いブラックガード^f", ru = "Сумрачный страж мрака^f", zh = "幽暗黑卫" },
	["8290981-0-121486"] = { default = "Mirrormoor Bone Flayer^n", de = "Spiegelmoor-Knochenschinder^m", es = "despellejador del Páramo Espejado^m", fr = "fouette-os de la Lande miroir^m", jp = "ミラームーアのボーンフレイヤー^n", ru = "Костяной живодер Зеркальной Пустоши^n", zh = "镜泽骷髅剥皮者" },
	["8290981-0-121487"] = { default = "Gloomy Infernium^n", de = "düsteres Infernium^n", es = "infernio lúgubre^m", fr = "Infernium sinistre^m", jp = "薄暗いインファーニウム^n", ru = "Сумрачный пламенник^n", zh = "幽暗死域魔虫" },
	["74865733-0-34170"] = { default = "Claim", de = "Übernehmen", es = "Reclamar", fr = "Récupérer", jp = "獲得", ru = "Взять", zh = "获取" },
	["87370069-0-34170"] = { default = "Arcane Knot", de = "arkaner Knoten^m", es = "nudo arcano^m", fr = "nœud arcanique^md", jp = "アルケインの結び目", ru = "Тайный узел", zh = "奥术结" },
	["254784612-0-28"] = { default = "IMMUNE", de = "IMMUN", es = "INMUNE", fr = "IMMUNITÉ", jp = "無効", ru = "НЕВОСПРИИМЧИВОСТЬ", zh = "免疫" },

	-- Custom (Alerts)
	majVuln = { default = LCA.GetAbilityName(LCA.IDS.MAJ_VULN), en = "Major Vuln" },
	newMirrors = { default = LCA.GetAbilityName(217589), de = "Neue Spiegel" },
	noCarrier = { default = "NO CARRIER", de = "KEIN TRÄGER", zh = "没有携带者" },
	toNext = { default = "to next", de = "bis zum Nächsten", zh = "轮到下一个" },

	-- Custom (Settings)
	mirrorLabels = { default = "Show Orphic mirror direction labels" },
	mirrorSpawns = { default = "Announce Orphic mirror spawns", de = "Meldung für neue Spiegel anzeigen", zh = "宣布第二个 BOSS 镜子生成" },
	extraAlerts = { default = "Enable additional alerts", de = "Zusätzliche Benachrichtigungen anzeigen", zh = "启用附加警报" },
	knotNumber = { default = "Show knot number", de = "Knotennummer anzeigen", zh = "显示奥术结编号" },
	cooldownPanel = { default = "Enable group-wide cooldown panel", de = "Panel zur Anzeige der Cooldowns aktivieren", zh = "启用全团冷却时间面板" },
	suicidePrevention = { default = "Enable Splintered Passage protection", de = "Suizid durch Knoten verhindern", zh = "启用残破通道保护" },
}

Module.DEFAULT_SETTINGS = {
	raidLeadMode = false,
	mirrorLabels = true,
	mirrorSpawns = true,
	whirlwind = false,
	burstNear = true,
	extraAlerts = true,
	knotNumber = true,
	cooldownPanel = true,
	colorPassage = 0xFF000099,
	colorOverloaded = 0x0099FF99,
	colorBoth = 0xFF00FF99,
	suicidePrevention = true,
}

local COLOR_L32 = 0xFFFF66FF
local COLOR_D32 = 0xCC3333FF

Module.DATA = {
	-- General
	extraAlertsTooltipIds = { 214237, 214254, 218283, 214678, 213685, 221945, 219165, 219179 },
	refresh = 222903,
	darkness = 214338,
	sunburst = {
		id = 214678,
		damage = 214684,
	},
	aoeCleave = {
		[219050] = true, -- Shield Throw (Jresazzel)
		[219165] = true, -- Piercing Beam
		[221945] = true, -- Shield Throw (Crystal Hollow Sentinel)
	},

	-- Boss 1
	boss1Abilities = {
		-- Abilities unique to the first boss for identification purposes
		[217907] = true, -- Swipe
		[217908] = true, -- Rend
		[217909] = true, -- Slash
		[217910] = true, -- Rend
		[222260] = true, -- Focused Ray
		[222277] = true, -- Twin Jab
		[222278] = true, -- Sting
	},
	boss1DimAlpha = { 0.4, 0.6 },
	boss1Reverse = { "dark", "light" },
	mirrorSide = {
		light = 219329,
		dark = 219330,
	},
	annihilation = {
		[214187] = "dark", -- Brilliant Annihilation
		[214203] = "light", -- Bleak Annihilation
		duration = 12000,
	},
	luster = {
		[214237] = COLOR_L32, -- Brilliant Lusterbeam
		[214254] = COLOR_D32, -- Bleak Lusterbeam
	},
	summons = {
		[218101] = {
			-- Mirrormoor Bone Flayer
			nameKey = "8290981-0-121486",
			side = "light",
			color = COLOR_L32,
			tank = false,
		},
		[218105] = {
			-- Gloomy Infernium
			nameKey = "8290981-0-121487",
			side = "dark",
			color = COLOR_D32,
			tank = false,
		},
		[218109] = {
			-- Gloomy Blackguard
			nameKey = "8290981-0-121485",
			side = "light",
			color = COLOR_L32,
			tank = true,
		},
		[218113] = {
			-- Shardborn Lightweaver
			nameKey = "8290981-0-121484",
			side = "dark",
			color = COLOR_D32,
			tank = true,
		},
	},
	shear = {
		[218274] = true,
		[222605] = true,
	},
	meteor = 218283,

	-- Miniboss
	radiance = {
		id = 214085,
		duration = 5000,
		interval = 30000, -- 30s from end to start
	},

	-- Boss 2
	boss2Spawned = false,
	breakout = 217841,
	fateSealer = 214136,
	immunity = {
		light = 219444,
		dark = 219447,
		[219444] = { 217842, COLOR_L32 },
		[219447] = { 217843, COLOR_D32 },
	},
	jump = {
		id = 214383,
		escape = {
			[217987] = -1, -- Defeated
			[219545] = -2, -- Execute
		},
		cooldown = 26000, -- 26s
	},
	mirrorSpawns = {
		id = 213921,
		offset = 1500, -- New mirror appears at 0s, gets initial color at 4s, so do the alert slightly before that
		data = {
			{ 91, SI_COMPASS_EAST_ABBREVIATION, SI_COMPASS_WEST_ABBREVIATION },
			{ 61, SI_COMPASS_NORTH_ABBREVIATION, SI_COMPASS_SOUTH_ABBREVIATION },
		},
	},
	shockwave = 213685,
	whirlwind = {
		id = 221882,
		name = 221885, -- cast ID is misspelled, so alert text should use damage ID
	},

	-- Boss 3
	javelin = 223546,
	stomp = 219797,
	burst = 219799,
	knot = {
		claim = 213410,
		carry = 213477,
		passage = {
			id = 222677,
			[222677] = true, -- Carrier
			[218492] = true, -- Bystanders
		},
	},
	conveyance = {
		[223028] = 1,
		[223029] = 2,
		cast = 223024,
	},
	barrage = {
		cast = 223198,
		damage = 223199,
		loc = 223204,
	},
	rain = {
		id = 222809,
		cover = 219014,
		interval = 26000, -- 26s from start to start / 20s from end to start
		initial = 10000, -- 10s
	},
	flux = {
		start = 214570,
		carry = 214597,
		overloaded = 214745,
		interval = 62500, -- 62.5s
		initial = 16500, -- 16.5s
		maxCarry = 15000, -- 15s
	},
	tempest = {
		start = 215107,
		interval = 32000, -- 32s
		initial = 28000, -- 28s
		active = 9500, -- 9.5s
	},
	xoryn = 219230,
	charge = 214542,
	chain = 219179,
	weakening = 222613,
}
local DATA = Module.DATA
local Vars

local Identifier = function(x) return Module.ID .. x end

function Module:Initialize( )
	self.MONITOR_BOSSES = true
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		[217971] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Heavy Strike
		[218274] = { -2, 2 }, -- Shear (Count Ryelaz)
		[222605] = { -2, 2 }, -- Shear (Baron Rize)
		[218672] = { -2, 2 }, -- Uppercut
		[218710] = { -2, 2 }, -- Butcher
		[218967] = { -2, 2 }, -- Uppercut
		[219030] = { -2, 2 }, -- Power Bash
		[219139] = { -2, 2 }, -- Smite
		[219420] = { 0, 0, false, { 1, 0, 0.6, 0.8 }, cutthroat = true }, -- Smite
		[219793] = { -2, 2 }, -- Crushing Shards
		[221863] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Heavy Attack
		[221881] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Frenzy
		[222271] = { 0, 0, false, { 1, 0, 0.6, 0.8 } }, -- Heavy Strike
		[222559] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Batter
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[214675] = { 700, false }, -- Radiance
		[219301] = { 900, false }, -- Radiance (Cavot Agnan)
		[213902] = { 1100, false }, -- Shard Volley
		[213907] = { 1100, false }, -- Shard Volley
		[213909] = { 1100, false }, -- Shard Volley
	}

	self.vars = {
		mirrorSide = {
			light = false,
			dark = false,
		},
		vuln = { },
		annihilation = { },
		lastSummon = 0,
		currentImmunity = nil,
		nextJump = -1,
		knot = {
			unitId = nil,
			carryEnd = 0,
			duration = 0,
			number = 1,
			lastDrop = 0,
			passage = { },
		},
		flux = {
			state = nil,
			next = 0,
			unitId = nil,
			carryStart = 0,
			carryEnd = 0,
			overloaded = { },
		},
		barrage = { },
		conveyance = { },
		platformHealth = nil,
		radianceNext = 0,
		radianceActive = 0,
		rainNext = 0,
		rainActive = 0,
		tempestNext = 0,
		tempestActive = 0,
		tempestStart = 0,
	}
	Vars = self.vars

	self.GroupPanelPoll = function( )
		local currentTime = GetGameTimeMilliseconds()
		local passage = Vars.knot.passage
		local overloaded = Vars.flux.overloaded

		for i = 1, GetGroupSize() do
			local unitTag = GetGroupUnitTagByIndex(i)
			local unitId = LCA.IdentifyGroupUnitTag(unitTag)

			if (unitId) then
				local color, hasPassage, hasOverloaded
				local timers = { }

				if (passage[unitId]) then
					local remaining = passage[unitId].stop - currentTime
					if (remaining > 0) then
						hasPassage = true
						table.insert(timers, LCA.FormatTime(remaining, LCA.TIME_FORMAT_COMPACT))
					end
				end

				if (overloaded[unitId]) then
					local remaining = overloaded[unitId] - currentTime
					if (remaining > 0) then
						hasOverloaded = true
						table.insert(timers, LCA.FormatTime(remaining, LCA.TIME_FORMAT_COMPACT))
					end
				end

				if (hasPassage and hasOverloaded) then
					color = self:GetSetting("colorBoth")
				elseif (hasPassage) then
					color = self:GetSetting("colorPassage")
				elseif (hasOverloaded) then
					color = self:GetSetting("colorOverloaded")
				end

				CA2.GroupPanelUpdate(unitTag, unitId, color, table.concat(timers, "/"))
			end
		end
	end

	self.StatusInit_B1 = function( )
		for i = 1, 2 do
			for j = 2, 3 do
				CA2.StatusModifyCell(i, j,
					"text", "",
					"color", (j == 2) and COLOR_L32 or COLOR_D32,
					"alignment", TEXT_ALIGN_RIGHT,
					"minWidth", "100%"
				)
			end
		end
		CA2.StatusSetRowAlpha(2, 0)
	end

	self.StatusPoll_B1 = function( )
		local currentTime = GetGameTimeMilliseconds()
		local showVuln = false
		for i = 1, 2 do
			local unitTag = "boss" .. i
			local remaining = (Vars.vuln[unitTag] or 0) - currentTime
			if (remaining > 0) then
				showVuln = true
			end
			local alpha = Vars.mirrorSide[DATA.boss1Reverse[i]] and DATA.boss1DimAlpha[i] or 1

			CA2.StatusModifyCell(1, i + 1,
				"text", string.format("%d%%", zo_floor(LCA.GetUnitHealthPercent(unitTag))),
				"alpha", alpha
			)

			CA2.StatusModifyCell(2, i + 1,
				"text", (remaining > 0) and LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT) or "",
				"alpha", alpha
			)
		end

		if (showVuln) then
			CA2.StatusSetRowAlpha(2, 1)
		end
	end

	self.StatusPoll_Mini = function( )
		local currentTime = GetGameTimeMilliseconds()

		if (currentTime > Vars.radianceActive) then
			local remaining = Vars.radianceNext - currentTime
			local ratio = zo_clamp(remaining / DATA.radiance.interval, 0, 1)
			CA2.StatusModifyCell(1, 2,
				"text", LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT),
				"color", LCA.PackRGBA(LCA.HSLToRGB(ratio / 3, 1, 0.5, 1))
			)
		else
			CA2.StatusModifyCell(1, 2,
				"text", string.format("%s [%s]", GetString(SI_LCA_ACTIVE), LCA.FormatTime(Vars.radianceActive - currentTime, LCA.TIME_FORMAT_SHORT)),
				"color", 0xFFFFFFFF
			)
		end
	end

	self.StatusInit_B2 = function( )
		Vars.boss2Spawned = true
		CA2.StatusSetCellText(1, 0, "")
	end

	self.StatusPoll_B2 = function( )
		if (Vars.currentImmunity) then
			local data = DATA.immunity[Vars.currentImmunity]
			CA2.StatusModifyCell(1, 2,
				"text", LCA.GetAbilityName(data[1]),
				"color", data[2]
			)
			local immune = GetUnitAttributeVisualizerEffectInfo("boss1", ATTRIBUTE_VISUAL_UNWAVERING_POWER, STAT_MITIGATION, ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH)
			if (immune and immune > 0) then
				CA2.StatusModifyCell(1, 0,
					"text", self:GetString("254784612-0-28"),
					"color", 0xFFCC00FF
				)
			else
				CA2.StatusSetCellText(1, 0, "")
			end
		end

		if (Vars.nextJump > 0) then
			local remaining = Vars.nextJump - GetGameTimeMilliseconds()
			local ratio = zo_clamp(remaining / DATA.jump.cooldown, 0, 1)
			CA2.StatusModifyCell(2, 2,
				"text", LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT),
				"color", LCA.PackRGBA(LCA.HSLToRGB(ratio / 3, 1, 0.5, 1))
			)
		elseif (Vars.nextJump == -1) then
			CA2.StatusSetCellText(2, 2, "")
		else
			CA2.StatusSetRowHidden(2, true)
		end
	end

	self.StatusInit_B3 = function( )
		for i = 1, 3 do
			CA2.StatusModifyCell(i, 2,
				"alignment", TEXT_ALIGN_RIGHT,
				"minWidth", "00s"
			)
			if (i < 3) then
				CA2.StatusSetCellText(i, 0, "")
			end
			if (i > 1) then
				CA2.StatusSetRowAlpha(i, 0)
			end
		end
	end

	self.StatusPoll_B3 = function( )
		local currentTime = GetGameTimeMilliseconds()

		if (Vars.knot.unitId) then
			local remaining = Vars.knot.carryEnd - currentTime
			local ratio = zo_clamp(remaining / Vars.knot.duration, 0, 1)
			local _, name = LCA.IdentifyGroupUnitId(Vars.knot.unitId, true)
			CA2.StatusModifyCell(1, 2,
				"text", LCA.FormatTime(remaining, LCA.TIME_FORMAT_SHORT),
				"color", LCA.PackRGBA(LCA.HSLToRGB(ratio / 3, 1, 0.5, 1))
			)
			CA2.StatusSetCellText(1, 3, name)
		else
			CA2.StatusModifyCell(1, 2,
				"text", string.format("%s [%s]", self:GetString("noCarrier"), LCA.FormatTime(currentTime - Vars.knot.lastDrop, LCA.TIME_FORMAT_SHORT)),
				"color", 0xFF0000FF
			)
			CA2.StatusSetCellText(1, 3, "")
		end

		local cdText = ""
		local passage = Vars.knot.passage
		if (passage.selfId and passage[passage.selfId]) then
			local cdRemaining = passage[passage.selfId].stop - currentTime
			if (cdRemaining > 0) then
				cdText = string.format("%s: %s", LCA.GetAbilityName(DATA.knot.passage.id), LCA.FormatTime(cdRemaining, LCA.TIME_FORMAT_LONG))
			end
		end
		CA2.StatusModifyCell(1, 0,
			"text", cdText,
			"color", 0xCC0000FF
		)

		if (Vars.flux.state) then
			if (Vars.flux.state == 1) then
				CA2.StatusSetCellText(2, 2, "")
				CA2.StatusSetCellText(2, 3, Vars.flux.targetName or "")
			elseif (Vars.flux.state == 2) then
				local carried = currentTime - Vars.flux.carryStart
				local ratio = zo_clamp(1 - carried / DATA.flux.maxCarry, 0, 1)
				CA2.StatusSetCellText(2, 2, LCA.FormatTime(Vars.flux.carryEnd - currentTime, LCA.TIME_FORMAT_SHORT))
				CA2.StatusSetCellText(2, 3, string.format("%s [|c%06X%s|r]", select(2, LCA.IdentifyGroupUnitId(Vars.flux.unitId, true)), LCA.PackRGB(LCA.HSLToRGB(ratio / 3, 1, 0.5)), LCA.FormatTime(carried, LCA.TIME_FORMAT_SHORT)))
			elseif (Vars.flux.state == 3) then
				CA2.StatusSetCellText(2, 2, LCA.FormatTime(Vars.flux.next - currentTime, LCA.TIME_FORMAT_SHORT))
				CA2.StatusSetCellText(2, 3, self:GetString("toNext"))
			end

			cdText = ""
			local overloaded = Vars.flux.overloaded
			if (overloaded.selfId and overloaded[overloaded.selfId]) then
				local cdRemaining = overloaded[overloaded.selfId] - currentTime
				if (cdRemaining > 0) then
					cdText = string.format("%s: %s", LCA.GetAbilityName(DATA.flux.overloaded), LCA.FormatTime(cdRemaining, LCA.TIME_FORMAT_LONG))
				end
			end
			CA2.StatusModifyCell(2, 0,
				"text", cdText,
				"color", 0xCC0000FF
			)

			if (currentTime > Vars.tempestActive) then
				CA2.StatusSetCellText(3, 2, LCA.FormatTime(Vars.tempestNext - currentTime, LCA.TIME_FORMAT_SHORT))
				CA2.StatusSetCellText(3, 3, self:GetString("toNext"))
			else
				local elapsed = currentTime - Vars.tempestStart
				CA2.StatusSetCellText(3, 2, string.format((elapsed < 6500) and "%s [%s]" or "%s [|c0099FF%s|r]", GetString(SI_LCA_ACTIVE), LCA.FormatTime(elapsed, LCA.TIME_FORMAT_SHORT)))
				CA2.StatusSetCellText(3, 3, "")
			end
		else
			-- Crystal health
			local alpha = 0
			if (not Vars.platformHealth and GetUnitName("boss2") ~= "") then
				Vars.platformHealth = select(2, GetUnitPower("boss2", COMBAT_MECHANIC_FLAGS_HEALTH))
			end
			if (Vars.platformHealth) then
				local results = { }
				for i = 1, 4 do
					local current, max, effectiveMax = GetUnitPower("boss" .. i, COMBAT_MECHANIC_FLAGS_HEALTH)
					if (max == Vars.platformHealth) then
						table.insert(results, string.format("%d%%", zo_floor(100 * current / effectiveMax)))
					end
				end
				if (#results > 0) then
					CA2.StatusSetCellText(2, 2, table.concat(results, " / "))
					alpha = 1
				end
			end
			CA2.StatusSetRowAlpha(2, alpha)

			-- Necrotic rain
			alpha = 1
			if (Vars.rainNext == 0) then
				alpha = 0
			elseif (currentTime > Vars.rainActive) then
				CA2.StatusSetCellText(3, 2, LCA.FormatTime(Vars.rainNext - currentTime, LCA.TIME_FORMAT_SHORT))
				CA2.StatusSetCellText(3, 3, self:GetString("toNext"))
			else
				CA2.StatusSetCellText(3, 2, string.format("%s [%s]", GetString(SI_LCA_ACTIVE), LCA.FormatTime(Vars.rainActive - currentTime, LCA.TIME_FORMAT_SHORT)))
				CA2.StatusSetCellText(3, 3, "")
			end
			CA2.StatusSetRowAlpha(3, alpha)
		end

		if (CA2.GroupPanelIsEnabled()) then
			self.GroupPanelPoll()
		end
	end

	self.BannerPoll_Annihilation = function( )
		local remaining = Vars.annihilation.castEnd - GetGameTimeMilliseconds()
		if (remaining < 0) then
			CA1.DisableBanner(Vars.annihilation.bannerId)
			Vars.annihilation.bannerId = nil
		end
		if (Vars.annihilation.bannerId) then
			CA1.ModifyBanner(Vars.annihilation.bannerId, nil, string.format("%s: %s", Vars.annihilation.name, LCA.FormatTime(remaining, LCA.TIME_FORMAT_COUNTDOWN)), 0xFF6633FF)
		end
	end

	self.BannerPoll_Conveyance = function( )
		if (Vars.conveyance.stop < GetGameTimeMilliseconds()) then
			CA1.DisableBanner(Vars.conveyance.bannerId)
			Vars.conveyance.bannerId = nil
		end
	end

	self.BannerPoll_Barrage = function( )
		local remaining = Vars.barrage.castEnd - GetGameTimeMilliseconds()
		local extraText
		if (Vars.barrage.targetName and remaining > -1500) then
			extraText = Vars.barrage.targetName
		elseif (remaining > -500) then
			extraText = LCA.FormatTime(remaining, LCA.TIME_FORMAT_COUNTDOWN)
		else
			CA1.DisableBanner(Vars.barrage.bannerId)
			Vars.barrage.bannerId = nil
		end
		if (Vars.barrage.bannerId) then
			CA1.ModifyBanner(Vars.barrage.bannerId, nil, string.format("%s: %s", LCA.GetAbilityName(DATA.barrage.damage), extraText), 0xCC33CCFF)
		end
	end

	self.OrbRefresh = function( )
		CA2.ScreenBorderEnable(0x99FFFFCC, 500, "u42refresh")
		LCA.PlaySounds("DUEL_FORFEIT")
	end

	self.MirrorSide = function( _, result, _, _, _, _, _, _, _, _, _, _, _, _, _, _, abilityId )
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			if (abilityId == DATA.mirrorSide.light) then
				Vars.mirrorSide.light = true
				Vars.mirrorSide.dark = false
			else
				Vars.mirrorSide.light = false
				Vars.mirrorSide.dark = true
			end
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			if (abilityId == DATA.mirrorSide.light) then
				Vars.mirrorSide.light = false
			else
				Vars.mirrorSide.dark = false
			end
		end
	end

	self.ColorImmunity = function( _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, abilityId )
		Vars.currentImmunity = abilityId
	end

	self.StartBoss2Panel = function( )
		-- There are multiple entry points for this panel:
		-- * Breakout event, but usable only once per instance
		-- * Check boss name at the start of combat, but should not be used prior to Breakout
		-- * Xoryn teleport, as a fail-safe if the others are missed for any reason
		CA2.StatusEnable({
			ownerId = "u42b2",
			rowLabels = { GetString(SI_LCA_BOSS), LCA.GetAbilityName(DATA.jump.id) },
			pollingFunction = self.StatusPoll_B2,
			initFunction = self.StatusInit_B2,
		})
	end

	self.HandleFluxStart = function( initial )
		if (not Vars.flux.state) then
			CA2.StatusSetCellText(2, 1, LCA.GetAbilityName(DATA.flux.start))
			CA2.StatusSetCellText(3, 1, LCA.GetAbilityName(DATA.tempest.start))
			CA2.StatusSetRowAlpha(2, 1)
			CA2.StatusSetRowAlpha(3, 1)
		end
		local currentTime = GetGameTimeMilliseconds()
		if (initial) then
			Vars.flux.state = 3
			Vars.flux.next = currentTime + DATA.flux.initial
			Vars.tempestNext = currentTime + DATA.tempest.initial
		else
			Vars.flux.state = 1
			Vars.flux.next = currentTime + DATA.flux.interval
		end
	end

	local shouldBlock = function( )
		local passage = Vars.knot.passage
		if (passage.selfId and passage[passage.selfId]) then
			return passage[passage.selfId].stop > GetGameTimeMilliseconds()
		end
	end

	self.ToggleSplinteredPassageBlock = function( enable )
		if (enable) then
			LCA.RegisterInteractionBlock(self.ID, self:GetString("74865733-0-34170"), self:GetString("87370069-0-34170"), shouldBlock)
		else
			LCA.RegisterInteractionBlock(self.ID)
		end
	end
end

function Module:PostLoad( )
	Vars.boss2Spawned = false

	-- Vulnerability can only be tracked via EVENT_EFFECT_CHANGED

	LCA.RegisterForFilteredEvent(Identifier("MAJ_VULN"), EVENT_EFFECT_CHANGED,
		function( _, changeType, _, _, unitTag, _, endTime )
			Vars.vuln[unitTag] = (changeType == EFFECT_RESULT_FADED) and 0 or zo_floor(endTime * 1000)
		end,
		REGISTER_FILTER_ABILITY_ID, LCA.IDS.MAJ_VULN,
		REGISTER_FILTER_UNIT_TAG_PREFIX, "boss"
	)

	-- Events that need to be tracked at all times, even out of combat

	LCA.RegisterForFilteredEvent(Identifier("ORB"), EVENT_COMBAT_EVENT,
		self.OrbRefresh,
		REGISTER_FILTER_ABILITY_ID, DATA.refresh,
		REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER
	)
	LCA.RegisterForFilteredEvent(Identifier("B1_L"), EVENT_COMBAT_EVENT,
		self.MirrorSide,
		REGISTER_FILTER_ABILITY_ID, DATA.mirrorSide.light,
		REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER
	)
	LCA.RegisterForFilteredEvent(Identifier("B1_D"), EVENT_COMBAT_EVENT,
		self.MirrorSide,
		REGISTER_FILTER_ABILITY_ID, DATA.mirrorSide.dark,
		REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER
	)
	LCA.RegisterForFilteredEvent(Identifier("B2_L"), EVENT_COMBAT_EVENT,
		self.ColorImmunity,
		REGISTER_FILTER_ABILITY_ID, DATA.immunity.light,
		REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED
	)
	LCA.RegisterForFilteredEvent(Identifier("B2_D"), EVENT_COMBAT_EVENT,
		self.ColorImmunity,
		REGISTER_FILTER_ABILITY_ID, DATA.immunity.dark,
		REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED
	)
	LCA.RegisterForFilteredEvent(Identifier("B2_START"), EVENT_COMBAT_EVENT,
		function( )
			self.StartBoss2Panel()
			self:StartListening()
		end,
		REGISTER_FILTER_ABILITY_ID, DATA.breakout,
		REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_BEGIN
	)
	LCA.RegisterForFilteredEvent(Identifier("B3_START"), EVENT_COMBAT_EVENT,
		function( )
			-- The cooldown panel intentionally has no other entry point because if
			-- this module is loaded mid-encounter, the knot state is incomplete and
			-- it's better to show no information than misleading information
			if (self:GetSetting("cooldownPanel") and LCA.isVet) then
				CA2.GroupPanelEnable({
					headerText = string.format("%s / %s", LCA.GetAbilityName(DATA.knot.passage.id), LCA.GetAbilityName(DATA.flux.overloaded)),
					statWidth = 48,
					useRange = false,
				})
			end
			if (self:GetSetting("suicidePrevention") and LCA.isVet) then
				self.ToggleSplinteredPassageBlock(true)
			end
			self:StartListening()
		end,
		REGISTER_FILTER_ABILITY_ID, DATA.knot.claim,
		REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION
	)
end

function Module:PreUnload( )
	EVENT_MANAGER:UnregisterForEvent(Identifier("MAJ_VULN"), EVENT_EFFECT_CHANGED)
	EVENT_MANAGER:UnregisterForEvent(Identifier("ORB"), EVENT_COMBAT_EVENT)
	EVENT_MANAGER:UnregisterForEvent(Identifier("B1_L"), EVENT_COMBAT_EVENT)
	EVENT_MANAGER:UnregisterForEvent(Identifier("B1_D"), EVENT_COMBAT_EVENT)
	EVENT_MANAGER:UnregisterForEvent(Identifier("B2_L"), EVENT_COMBAT_EVENT)
	EVENT_MANAGER:UnregisterForEvent(Identifier("B2_D"), EVENT_COMBAT_EVENT)
	EVENT_MANAGER:UnregisterForEvent(Identifier("B2_START"), EVENT_COMBAT_EVENT)
	EVENT_MANAGER:UnregisterForEvent(Identifier("B3_START"), EVENT_COMBAT_EVENT)
	self:ToggleOrphicDirectionLabels(false)
end

function Module:OnBossesChanged( )
	self:ToggleOrphicDirectionLabels(self:GetSetting("mirrorLabels") and LCA.MatchStrings(GetUnitName("boss1"), self:GetString("8290981-0-121169")))
end

function Module:PreStartListening( )
	Vars.nextJump = -1
	Vars.knot.number = 1
	ZO_ClearTable(Vars.knot.passage)
	ZO_ClearTable(Vars.flux.overloaded)
	Vars.flux.state = nil
	Vars.platformHealth = nil
	Vars.rainNext = 0
	if (Vars.boss2Spawned and LCA.MatchStrings(GetUnitName("boss1"), self:GetString("8290981-0-121169"))) then
		self.StartBoss2Panel()
	end
end

function Module:PostStopListening( )
	CA2.StatusDisable()
	CA2.GroupPanelDisable()
	self.ToggleSplinteredPassageBlock(false)
	if (Vars.callLaterId) then
		zo_removeCallLater(Vars.callLaterId)
		Vars.callLaterId = nil
	end
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- General
	if (result == ACTION_RESULT_EFFECT_GAINED_DURATION and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.darkness) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC3333FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.sunburst.id and targetType == COMBAT_UNIT_TYPE_PLAYER and self:GetSetting("extraAlerts")) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
		CA1.AlertCast(DATA.sunburst.damage, sourceName, hitValue + 800, { -3, 0, false, { 1, 0.4, 0, 0.5 } })
	elseif (result == ACTION_RESULT_BEGIN and DATA.aoeCleave[abilityId] and not LCA.isTank and self:GetSetting("extraAlerts")) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFFFFCCFF, nil, 2000)
		LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 2, 100, "DUEL_BOUNDARY_WARNING", 4)

	-- Boss 1
	elseif (result == ACTION_RESULT_BEGIN and DATA.boss1Abilities[abilityId] and GetUnitName("boss2") ~= "") then
		CA2.StatusEnable({
			ownerId = "u42b1",
			rowLabels = { GetString("SI_ATTRIBUTES", ATTRIBUTE_HEALTH), self:GetString("majVuln") },
			pollingFunction = self.StatusPoll_B1,
			initFunction = self.StatusInit_B1,
		})
	elseif (result == ACTION_RESULT_BEGIN and DATA.annihilation[abilityId]) then
		if (Vars.mirrorSide[DATA.annihilation[abilityId]]) then
			local currentTime = GetGameTimeMilliseconds()
			if (hitValue <= 2000) then
				-- Project full duration during initial windup
				Vars.annihilation.castEnd = currentTime + DATA.annihilation.duration
			else
				Vars.annihilation.castEnd = currentTime + hitValue
			end
			Vars.annihilation.name = LCA.GetAbilityName(abilityId)
			if (not Vars.annihilation.bannerId) then
				Vars.annihilation.bannerId = CA1.AlertBannerEx(nil, nil, nil, nil, true, SOUNDS.CHAMPION_POINTS_COMMITTED, self.BannerPoll_Annihilation)
			end
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and targetType == COMBAT_UNIT_TYPE_PLAYER and DATA.luster[abilityId] and not LCA.isTank and self:GetSetting("extraAlerts")) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), DATA.luster[abilityId], SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.summons[abilityId] and LCA.DoesPlayerHaveTauntOrPullSlotted()) then
		local currentTime = GetGameTimeMilliseconds()
		local data = DATA.summons[abilityId]
		if (Vars.mirrorSide[data.side] and data.tank == LCA.isTank and currentTime - Vars.lastSummon > 2000) then
			Vars.lastSummon = currentTime
			CA1.Alert(LCA.GetAbilityName(abilityId), zo_strformat(SI_UNIT_NAME, self:GetString(data.nameKey)), data.color, SOUNDS.CHAMPION_POINTS_COMMITTED, 2500)
		end
	elseif (LCA.isVet and result == ACTION_RESULT_BEGIN and DATA.shear[abilityId] and targetType ~= COMBAT_UNIT_TYPE_PLAYER and not LCA.isTank and self:GetSetting("extraAlerts")) then
		if (Vars.mirrorSide.light or CA2.StatusGetOwnerId() ~= "u42b1") then
			CA1.Alert(nil, LCA.GetAbilityName(DATA.meteor), 0x00FFFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end

	-- Miniboss
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.radiance.id) then
		Vars.radianceActive = GetGameTimeMilliseconds() + hitValue
		if (hitValue <= 2000) then
			-- Project full duration during initial windup
			Vars.radianceActive = Vars.radianceActive + DATA.radiance.duration
		end
		Vars.radianceNext = Vars.radianceActive + DATA.radiance.interval
		CA2.StatusEnable({
			ownerId = "u42mini",
			rowLabels = LCA.GetAbilityName(abilityId),
			pollingFunction = self.StatusPoll_Mini,
		})

	-- Boss 2
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.fateSealer and (targetType == COMBAT_UNIT_TYPE_PLAYER or LCA.DoesPlayerHaveTauntSlotted() or self:GetSetting("raidLeadMode"))) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF6633FF, nil, 2500)
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			-- Play a sound only for the MT
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 4)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.jump.id) then
		local unitTag, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId)
		if (unitTag) then
			Vars.nextJump = GetGameTimeMilliseconds() + DATA.jump.cooldown
			if (targetType == COMBAT_UNIT_TYPE_PLAYER or LCA.GetDistance("player", unitTag) < 6) then
				CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
			end
			self.StartBoss2Panel()
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.jump.escape[abilityId]) then
		-- Hide timer when Xoryn leaves
		Vars.nextJump = DATA.jump.escape[abilityId]
	elseif (LCA.isVet and result == ACTION_RESULT_EFFECT_FADED and abilityId == DATA.mirrorSpawns.id and self:GetSetting("mirrorSpawns")) then
		local health = LCA.GetUnitHealthPercent("boss1")
		for _, spawn in ipairs(DATA.mirrorSpawns.data) do
			if (spawn[1] > health and spawn[1] - health < 15) then
				Vars.callLaterId = zo_callLater(function( )
					CA1.Alert(nil, string.format("%s — %s & %s", self:GetString("newMirrors"), GetString(spawn[2]), GetString(spawn[3])), 0xFF00FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
				end, DATA.mirrorSpawns.offset)
			end
		end
	elseif (LCA.isVet and result == ACTION_RESULT_BEGIN and abilityId == DATA.shockwave and not LCA.isTank and self:GetSetting("extraAlerts")) then
		Vars.callLaterId = zo_callLater(function( )
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end, 1500)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.whirlwind.id and not LCA.isTank and self:GetSetting("whirlwind")) then
		CA1.Alert(nil, LCA.GetAbilityName(DATA.whirlwind.name), 0xFFFFCCFF, nil, 2000)
		LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 2, 100, "DUEL_BOUNDARY_WARNING", 4)

	-- Boss 3
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.javelin and targetType == COMBAT_UNIT_TYPE_PLAYER and not LCA.isTank) then
		LCA.PlaySounds("DUEL_START")
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.stomp) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CA1.AlertCast(DATA.burst, sourceName, hitValue, { -2, 2, false, { 0.3, 0.9, 1, 0.6 }, { 0, 0.5, 1, 1 } })
		elseif (self:GetSetting("burstNear")) then
			local unitTag, name = LCA.IdentifyGroupUnitId(targetUnitId)
			if (unitTag and LCA.GetDistance("player", unitTag) < 7) then
				CA1.AlertCast(DATA.burst, name, hitValue, { -2, 0, false, { 0.6, 0.8, 1, 0.4 }, { 0.6, 0.8, 1, 0.8 } })
			end
		end
	elseif (abilityId == DATA.knot.carry) then
		local knotName = LCA.GetAbilityName(DATA.knot.carry)
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.knot.unitId = targetUnitId
			Vars.knot.carryEnd = GetGameTimeMilliseconds() + hitValue
			Vars.knot.duration = hitValue
			CA2.StatusEnable({
				ownerId = "u42b3",
				rowLabels = { knotName, GetString("SI_ATTRIBUTES", ATTRIBUTE_HEALTH), LCA.GetAbilityName(DATA.rain.id) },
				pollingFunction = self.StatusPoll_B3,
				initFunction = self.StatusInit_B3,
			})
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.knot.unitId = nil
			Vars.knot.number = Vars.knot.number + 1
			Vars.knot.lastDrop = GetGameTimeMilliseconds()
		end
		if (result ~= ACTION_RESULT_EFFECT_GAINED) then
			if (self:GetSetting("knotNumber")) then
				CA2.StatusSetCellText(1, 1, string.format("%s #%d", knotName, Vars.knot.number))
			else
				CA2.StatusSetCellText(1, 1, knotName)
			end
		end
	elseif (DATA.knot.passage[abilityId]) then
		local passage = Vars.knot.passage
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			passage[targetUnitId] = {
				id = abilityId,
				stop = GetGameTimeMilliseconds() + hitValue,
			}
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			if (passage[targetUnitId] and passage[targetUnitId].id == abilityId) then
				passage[targetUnitId] = nil
			end
		end
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			passage.selfId = targetUnitId
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.conveyance.cast) then
		Vars.conveyance.stop = GetGameTimeMilliseconds() + hitValue + 500
		Vars.conveyance.bannerId = CA1.AlertBannerEx(GetString(SI_LCA_INCOMING), LCA.GetAbilityName(abilityId), 0xCC3399FF, nil, true, SOUNDS.CHAMPION_POINTS_COMMITTED, self.BannerPoll_Conveyance)
		Vars.conveyance.name1 = ""
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.conveyance[abilityId]) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		if (DATA.conveyance[abilityId] == 1) then
			Vars.conveyance.name1 = name
		elseif (Vars.conveyance.bannerId) then
			Vars.conveyance.stop = GetGameTimeMilliseconds() + 3500
			CA1.ModifyBanner(Vars.conveyance.bannerId, LCA.GetAbilityName(abilityId), string.format("%s / %s", Vars.conveyance.name1, name), 0xCC3399FF)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.barrage.cast) then
		Vars.barrage.castEnd = GetGameTimeMilliseconds() + hitValue
		Vars.barrage.targetName = nil
		Vars.barrage.bannerId = CA1.AlertBannerEx(nil, nil, nil, nil, true, SOUNDS.CHAMPION_POINTS_COMMITTED, self.BannerPoll_Barrage)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.barrage.loc) then
		Vars.barrage.targetName = select(2, LCA.IdentifyGroupUnitId(targetUnitId, true))
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 2, 150, "DUEL_BOUNDARY_WARNING", 4)
		end
	elseif (abilityId == DATA.rain.cover) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.rainNext = GetGameTimeMilliseconds() + DATA.rain.initial
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.rainNext = 0
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.rain.id and hitValue >= 1000) then
		local currentTime = GetGameTimeMilliseconds()
		Vars.rainNext = currentTime + DATA.rain.interval
		Vars.rainActive = currentTime + hitValue
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.xoryn) then
		self.HandleFluxStart(true)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.flux.start) then
		Vars.flux.targetName = select(2, LCA.IdentifyGroupUnitId(targetUnitId, true))
		CA1.Alert(LCA.GetAbilityName(abilityId), Vars.flux.targetName, 0x00CC99FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		self.HandleFluxStart()
	elseif (abilityId == DATA.flux.carry) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			local currentTime = GetGameTimeMilliseconds()
			Vars.flux.state = 2
			Vars.flux.unitId = targetUnitId
			Vars.flux.carryStart = currentTime
			Vars.flux.carryEnd = currentTime + hitValue
		elseif (result == ACTION_RESULT_EFFECT_FADED and Vars.flux.unitId == targetUnitId) then
			Vars.flux.state = 3
			Vars.flux.unitId = nil
		end
	elseif (abilityId == DATA.flux.overloaded) then
		local overloaded = Vars.flux.overloaded
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			overloaded[targetUnitId] = GetGameTimeMilliseconds() + hitValue
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			overloaded[targetUnitId] = nil
		end
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			overloaded.selfId = targetUnitId
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.tempest.start) then
		local currentTime = GetGameTimeMilliseconds()
		Vars.tempestNext = currentTime + DATA.tempest.interval
		Vars.tempestActive = currentTime + DATA.tempest.active
		Vars.tempestStart = currentTime
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.charge and hitValue > 1000 and targetType ~= COMBAT_UNIT_TYPE_PLAYER and not LCA.isTank and self:GetSetting("extraAlerts")) then
		Vars.callLaterId = zo_callLater(function( )
			CA1.Alert(nil, LCA.GetAbilityName(DATA.chain), 0x00FFFFFF, nil, 3250)
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 300, "DUEL_BOUNDARY_WARNING", 3)
		end, 2250)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.weakening and (targetType == COMBAT_UNIT_TYPE_PLAYER or LCA.DoesPlayerHaveTauntSlotted() or self:GetSetting("raidLeadMode"))) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	end
end

function Module:GetSettingsControls( )
	local extraAlertsTooltipNames = { }
	for _, abilityId in ipairs(DATA.extraAlertsTooltipIds) do
		table.insert(extraAlertsTooltipNames, LCA.GetAbilityName(abilityId))
	end

	local cooldownPanelDisabled = function() return not self:GetSetting("cooldownPanel") end

	return {
		--------------------
		{
			type = "checkbox",
			name = SI_CA_SETTINGS_MODULE_RAID_LEAD,
			tooltip = SI_CA_SETTINGS_MODULE_RAID_LEAD_TT,
			getFunc = function() return self:GetSetting("raidLeadMode") end,
			setFunc = function(enabled) self:SetSetting("raidLeadMode", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("mirrorLabels"),
			getFunc = function() return self:GetSetting("mirrorLabels") end,
			setFunc = function( enabled )
				self:SetSetting("mirrorLabels", enabled)
				self:OnBossesChanged()
			end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("mirrorSpawns"),
			getFunc = function() return self:GetSetting("mirrorSpawns") end,
			setFunc = function(enabled) self:SetSetting("mirrorSpawns", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = zo_strformat(SI_CA_SETTINGS_MODULE_ABILITY, LCA.GetAbilityName(DATA.whirlwind.name)),
			getFunc = function() return self:GetSetting("whirlwind") end,
			setFunc = function(enabled) self:SetSetting("whirlwind", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = zo_strformat(SI_CA_SETTINGS_MODULE_ABILITY_NEARBY, LCA.GetAbilityName(DATA.burst)),
			getFunc = function() return self:GetSetting("burstNear") end,
			setFunc = function(enabled) self:SetSetting("burstNear", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("extraAlerts"),
			tooltip = table.concat(extraAlertsTooltipNames, "\n"),
			getFunc = function() return self:GetSetting("extraAlerts") end,
			setFunc = function(enabled) self:SetSetting("extraAlerts", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("knotNumber"),
			getFunc = function() return self:GetSetting("knotNumber") end,
			setFunc = function(enabled) self:SetSetting("knotNumber", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("cooldownPanel"),
			getFunc = function() return self:GetSetting("cooldownPanel") end,
			setFunc = function(enabled) self:SetSetting("cooldownPanel", enabled) end,
		},
		--------------------
		{
			type = "colorpicker",
			name = string.format("|u40:0::%s|u", LCA.GetAbilityName(DATA.knot.passage.id)),
			getFunc = function() return LCA.UnpackRGBA(self:GetSetting("colorPassage")) end,
			setFunc = function(...) self:SetSetting("colorPassage", LCA.PackRGBA(...)) end,
			disabled = cooldownPanelDisabled,
		},
		--------------------
		{
			type = "colorpicker",
			name = string.format("|u40:0::%s|u", LCA.GetAbilityName(DATA.flux.overloaded)),
			getFunc = function() return LCA.UnpackRGBA(self:GetSetting("colorOverloaded")) end,
			setFunc = function(...) self:SetSetting("colorOverloaded", LCA.PackRGBA(...)) end,
			disabled = cooldownPanelDisabled,
		},
		--------------------
		{
			type = "colorpicker",
			name = string.format("|u40:0::%s & %s|u", LCA.GetAbilityName(DATA.knot.passage.id), LCA.GetAbilityName(DATA.flux.overloaded)),
			getFunc = function() return LCA.UnpackRGBA(self:GetSetting("colorBoth")) end,
			setFunc = function(...) self:SetSetting("colorBoth", LCA.PackRGBA(...)) end,
			disabled = cooldownPanelDisabled,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("suicidePrevention"),
			getFunc = function() return self:GetSetting("suicidePrevention") end,
			setFunc = function(enabled) self:SetSetting("suicidePrevention", enabled) end,
		},
	}
end

-- Orphic direction labels
do
	local colorLit = 0xCCFFFFFF
	local colorDim = 0xFFFFFF33
	local active = false

	local thresholds = {
		-- index % 4
		[1] = 61, -- 1=N, 5=S
		[3] = 91, -- 3=W, 7=E
	}

	local function updateDim( elementId, threshold )
		if (Vars.boss2Spawned and LCA.GetUnitHealthPercent("boss1") < threshold) then
			CA2.WorldTextureUpdate(elementId, "color", colorLit, "update", false)
			return true
		end
	end

	function Module:ToggleOrphicDirectionLabels( enable )
		if (enable and not active) then
			active = true

			local X, Y, ELEVATION = 149300, 87940, 22880 -- Coordinates of room center

			for i, dir in ipairs(LCA.DIRECTIONS) do
				local threshold = thresholds[i % 4]

				if (LCA.isVet or not threshold) then
					local key, angle = unpack(dir)

					CA2.WorldTexturePlace({
						pos = { X - 2600 * math.sin(angle), ELEVATION, Y - 2600 * math.cos(angle) },
						texture = "world-dir-" .. key,
						size = 200,
						elevation = 600,
						color = threshold and colorDim or colorLit,
						update = threshold and updateDim or nil,
						updateParam = threshold,
						playerFacing = true,
					})
				end
			end
		elseif (not enable and active) then
			active = false
			CA2.WorldCanvasClear()
		end
	end
end

CA2.RegisterModule(Module)
