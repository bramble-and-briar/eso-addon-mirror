local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U47"
Module.NAME = CA2.GenerateModuleName(47, 1551, 1552)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1551, -- Naj-Caldeesh
	1552, -- Black Gem Foundry
}

Module.STRINGS = {
	-- Extracted
	["8290981-0-128153"] = { default = "Withering Refracted Soul^n", de = "welkende gebrochene Seele^mf", es = "alma refractada marchitante^fm", fr = "âme réfractée flétrissante^f", jp = "のたうつ屈折した魂^m", ru = "Иссушающая преломленная душа^F", zh = "凋零的折射灵魂" },
	["8290981-0-128154"] = { default = "Crushing Refracted Soul^n", de = "zerschlagende gebrochene Seele^mf", es = "alma refractada aplastante^fm", fr = "âme réfractée écrasante^f", jp = "叩き潰す屈折した魂^m", ru = "Ужасная преломленная душа^F", zh = "粉碎的折射灵魂" },

	-- Custom (Settings)
	splinters = { default = "Track <<1>>" },
	directions = { default = "Direction markers" },
}

Module.DEFAULT_SETTINGS = {
	splinters = true,
	directions = true,
	directionsColorBG = 0x3366CC66,
	directionsColorFG = 0xFFFFFFFF,
}

local SPLINTER_COLOR_TEXT = 0x9900CCFF
local SPLINTER_COLOR_BRDR = 0x9900CC66
local SPLINTER_COLOR_PANE = 0x9900CC99
local SPLINTER_BORDER_ID = "u47splinters"

Module.DATA = {
	-- General
	banners = {
		[240426] = SPLINTER_COLOR_TEXT, -- Seismic Splinters
		[241847] = 0xFF6600FF, -- Heat Center
	},

	-- Naj-Caldeesh
	possession = 243858,
	dirge = 242430,
	smash = 243328,
	vileMaw = 250032,
	viscera = 250096,

	-- Black Gem Foundry
	chargedLightning = {
		[244451] = true, -- Base pop
		[240665] = true, -- Boss 1
		nameId = 240670,
	},
	debris = {
		[240206] = true, -- Plummeting Debris
		--[240440] = true, -- Splintering Debris
	},
	splinterRemoval = {
		[240233] = true, -- Rupture Leap
		[240469] = true, -- Leveling Charge
		[240529] = true, -- Galvanizing Blow
	},
	splinters = 240433,
	soulFocus = 240363,
	vykandHmHealth = 20000000,
	roar = 241728,
	bombard = {
		effectId = 241685,
		damageId = 241689,
		threshold = 2,
	},
	refracted = {
		[241692] = { "8290981-0-128153", 0xFFFFCCFF },
		[241693] = { "8290981-0-128154", 0xFF6666FF },
	},
	enervation = {
		-- Using projectile event for both targets for consistency, and because cast event for the first target is just way too early
		[247137] = "enervI", -- First target, intercardinals
		[247139] = "enervC", -- Second target, cardinals
		effectId = 241764,
	},
	vision = {
		[241221] = 1, -- Ominous Vision
		[241326] = 2, -- Annihilation
		[241327] = 2, -- Annihilation
		[241328] = 2, -- Annihilation
		[241329] = 2, -- Annihilation
	},
	vykandHeavy = {
		[241854] = true, -- Soulbinding Slam
		[241863] = true, -- Soul Cascade
		slagId = 241856,
	},
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		-- Naj-Caldeesh
		[ 29378] = { -2, 2, extCheck = function() return LCA.GetZoneId() == 1551 end }, -- Uppercut (Wuj-Laxul Ravager)
		[242625] = { -2, 2 }, -- Offended Uppercut (Poxito)
		[242065] = { -2, 2 }, -- Low Slash (Voskrona Stonehulk Poxito)
		[242080] = { -2, 2 }, -- Heaving Attack (Voskrona Guardian)
		[242442] = { -2, 2 }, -- Sacrifice (Skeletal Executioner)
		[243328] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Focused Smash (Bar-Sakka)

		-- Black Gem Foundry
		[240097] = { 0, 0, false, { 1, 0, 0.6, 0.8 } }, -- Lapidating Bash (Black Gem Monstrosity)
		[240592] = { -2, 2 }, -- Savage Strike (Quarrymaster Saldezaar)
		[243378] = { -2, 2 }, -- Heavy Strike (Soulbinder Scythe Knight Tyrant)
		[243383] = { -3, 2, true }, -- True Shot (Soulbinder Acid Archer Tyrant)
		[243954] = { -2, 2 }, -- Uppercut (Crushing Refracted Soul)
		[244440] = { -2, 2 }, -- Monstrous Cleave (Kozell, Quarry Overseer)
		[248404] = { -2, 2, offset = -433 }, -- Staff Smash (Gemcarver Hynax)
		[248922] = { 0, 0, false, { 1, 0, 0.6, 0.8 } }, -- Shadow Slice (Misura, Assistant to the High Soulbinder)
		[249402] = { -2, 2 }, -- Spider Slash (Prospector Lyrakta)
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[240739] = { 1100, true }, -- Sentinel Tethers
		[240405] = { 600, false }, -- Blighted Periphery
		[241742] = { 600, false }, -- Lava
		[242356] = { 600, false }, -- Lava
		[243824] = { 600, false }, -- Refracted Soul Corrosion
		[250195] = { 1100, true }, -- Soul Storm
	}

	self.SMALL_GROUP_SIZE = true
	self.PURGEABLE_EFFECTS = {
		[250032] = 0, -- Vile Maw
	}

	self.vars = {
		lastDirge = 0,
		achState = 0,
		splinters = { },
		splintersEnd = 0,
		vykandHm = false,
		bombard = {
			prev = 0,
			count = 0,
		},
		enervationGroup = "enervI",
	}
	Vars = self.vars
end

function Module:PreStartListening( )
	Vars.achState = 0
	Vars.vykandHm = select(3, GetUnitPower("boss1", COMBAT_MECHANIC_FLAGS_HEALTH)) > DATA.vykandHmHealth
end

function Module:PostStopListening( )
	CA2.StatusDisable()
	CA2.GroupPanelDisable()
	CA2.ScreenBorderDisable()
	CA2.WorldCanvasClear()
	if (Vars.callLaterId) then
		zo_removeCallLater(Vars.callLaterId)
		Vars.callLaterId = nil
	end
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- General
	if (result == ACTION_RESULT_BEGIN and DATA.banners[abilityId]) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), DATA.banners[abilityId], SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)

	-- Naj-Caldeesh
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.dirge) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - Vars.lastDirge > 2000) then
			Vars.lastDirge = currentTime
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x9900CCFF, nil, 2000)
			LCA.PlaySounds("CHAMPION_POINTS_COMMITTED", 1, 500, "DUEL_BOUNDARY_WARNING", 3)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.smash and targetType ~= COMBAT_UNIT_TYPE_PLAYER and LCA.isVet) then
		CA1.AlertCast(DATA.viscera, sourceName, 1700, { 800, 0, false, { 0.7, 0.3, 1, 0.4 }, { 0.7, 0.3, 1, 1 } })
	elseif (abilityId == DATA.vileMaw and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		local id = "u47maw"
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CA2.ScreenBorderEnable(0xFFDD0066, nil, id)
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 1)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.ScreenBorderDisable(id)
		end
	elseif (LCA.isVet and result == ACTION_RESULT_BEGIN and abilityId == DATA.possession and GetUnitName("boss1") ~= "") then
		if (Vars.achState == 0 and not IsAchievementComplete(4319)) then
			CA2.ChatMessage(string.format("|cCC0000%s|r |H1:achievement:4319:0:0|h|h", zo_iconFormatInheritColor(LCA.GetTexture("misc-x"), "100%", "100%")), true)
		end
		Vars.achState = 1

	-- Black Gem Foundry
	elseif (result == ACTION_RESULT_BEGIN and DATA.chargedLightning[abilityId] and hitValue > 1000 and not LCA.isTank) then
		Vars.callLaterId = zo_callLater(function( )
			CA1.Alert(nil, LCA.GetAbilityName(DATA.chargedLightning.nameId), 0x00FFFFFF, nil, 2000)
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 300, "DUEL_BOUNDARY_WARNING", 3)
		end, 2000)
	elseif (LCA.isVet and LCA.DAMAGE_EVENTS[result] and DATA.debris[abilityId]) then
		if (Vars.achState == 0 and not IsAchievementComplete(4341)) then
			CA2.ChatMessage(string.format("|cCC0000%s|r |H1:achievement:4341:0:0|h|h", zo_iconFormatInheritColor(LCA.GetTexture("misc-x"), "100%", "100%")), true)
		end
		Vars.achState = 1
	elseif (LCA.isVet and abilityId == DATA.splinters and self:GetSetting("splinters")) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			if (not CA2.GroupPanelIsEnabled()) then
				ZO_ClearTable(Vars.splinters)
				CA2.GroupPanelEnable({
					headerText = LCA.GetAbilityName(abilityId),
					columns = 1,
					useUnitId = true,
					useRange = false,
				})
			end
			if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
				Vars.splintersEnd = GetGameTimeMilliseconds() + hitValue
				CA2.ScreenBorderEnable(SPLINTER_COLOR_BRDR, hitValue, SPLINTER_BORDER_ID)
			end
			Vars.splinters[targetUnitId] = 0
			CA2.GroupPanelUpdate(nil, targetUnitId, SPLINTER_COLOR_PANE)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
				Vars.splintersEnd = 0
				CA2.ScreenBorderDisable(SPLINTER_BORDER_ID)
			end
			Vars.splinters[targetUnitId] = nil
			CA2.GroupPanelUpdate(nil, targetUnitId)
		elseif (result == ACTION_RESULT_DOT_TICK and Vars.splinters[targetUnitId]) then
			Vars.splinters[targetUnitId] = Vars.splinters[targetUnitId] + 1
			CA2.GroupPanelUpdate(nil, targetUnitId, SPLINTER_COLOR_PANE, Vars.splinters[targetUnitId])
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.splinterRemoval[abilityId] and GetGameTimeMilliseconds() < Vars.splintersEnd) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), SPLINTER_COLOR_TEXT, nil, 1500)
		LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 2, 150, "FRIEND_INVITE_RECEIVED", 3)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.soulFocus and hitValue <= 3000) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC3399FF, nil, hitValue)
		if (LCA.isTank or targetType == COMBAT_UNIT_TYPE_PLAYER) then
			LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 3, 750, "DUEL_BOUNDARY_WARNING", 4)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.bombard.effectId) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - Vars.bombard.prev > 5000) then
			Vars.bombard.prev = currentTime
			Vars.bombard.count = 0
		end
		Vars.bombard.count = Vars.bombard.count + 1
		if (Vars.bombard.count == DATA.bombard.threshold) then
			CA1.Alert(GetString(SI_LCA_INCOMING), LCA.GetAbilityName(DATA.bombard.damageId), 0x00CC00FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.refracted[abilityId] and hitValue > 1000 and LCA.DoesPlayerHaveTauntSlotted()) then
		local stringId, color = unpack(DATA.refracted[abilityId])
		CA1.Alert(nil, zo_strformat(SI_UNIT_NAME, self:GetString(stringId)), color, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.roar and hitValue == 2000) then
		CA1.Alert(LCA.GetAbilityName(abilityId), GetString(SI_LCA_INTERRUPT), 0xCC0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and DATA.vykandHeavy[abilityId]) then
		local options, offset
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			options = { 600, 2 }
			offset = 0
		elseif (LCA.isVet) then
			options = { 800, Vars.vykandHm and 1 or 0, false, { 0.7, 0.3, 1, 0.4 }, { 0.7, 0.3, 1, 1 } }
			offset = 1000
			abilityId = DATA.vykandHeavy.slagId
		end
		if (options and offset) then
			CA1.AlertCast(abilityId, sourceName, hitValue + offset, options)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.enervation[abilityId] and hitValue == 1) then
		Vars.enervationGroup = DATA.enervation[abilityId]
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(DATA.enervation.effectId), name, 0xCCFF33FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (abilityId == DATA.enervation.effectId) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			self:ShowMarkerGroup(Vars.enervationGroup)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.WorldCanvasClear()
		end
	elseif (DATA.vision[abilityId]) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			self:ShowMarkerGroup("annih")
			if (DATA.vision[abilityId] > 1) then
				CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCCCCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
			end
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.WorldCanvasClear()
		end
	end
end

function Module:GetSettingsControls( )
	local markersDisabled = function() return not self:GetSetting("directions") end

	return {
		--------------------
		{
			type = "checkbox",
			name = zo_strformat(self:GetString("splinters"), LCA.GetAbilityName(DATA.splinters)),
			getFunc = function() return self:GetSetting("splinters") end,
			setFunc = function(enabled) self:SetSetting("splinters", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("directions"),
			getFunc = function() return self:GetSetting("directions") end,
			setFunc = function( enabled )
				self:SetSetting("directions", enabled)
				if (not enabled) then
					CA2.WorldCanvasClear()
				end
			end,
		},
		--------------------
		{
			type = "colorpicker",
			name = LCA.IndentedKeyboardText(GetString(SI_LCA_COLOR_BG)),
			getFunc = function() return LCA.UnpackRGBA(self:GetSetting("directionsColorBG")) end,
			setFunc = function( ... )
				self:SetSetting("directionsColorBG", LCA.PackRGBA(...))
				if (self.markers) then
					self:InitializeMarkers()
				end
			end,
			disabled = markersDisabled,
		},
		--------------------
		{
			type = "colorpicker",
			name = LCA.IndentedKeyboardText(GetString(SI_LCA_COLOR_FG)),
			getFunc = function() return LCA.UnpackRGBA(self:GetSetting("directionsColorFG")) end,
			setFunc = function( ... )
				self:SetSetting("directionsColorFG", LCA.PackRGBA(...))
				if (self.markers) then
					self:InitializeMarkers()
				end
			end,
			disabled = markersDisabled,
		},
	}
end

function Module:InitializeMarkers( )
	local W, E, N, S, ELEVATION = 43776, 45836, 92912, 94856, 36950 -- Coordinates measured from the four inner corners

	local POSITIONS = {
		{ (W+E)/2, N },
		{ W, N },
		{ W, (N+S)/2 },
		{ W, S },
		{ (W+E)/2, S },
		{ E, S },
		{ E, (N+S)/2 },
		{ E, N },
	}

	self.markers = {
		annih = { },
		enervC = { },
		enervI = { },
	}

	for i, dir in ipairs(LCA.DIRECTIONS) do
		local key, angle, x, y = unpack(dir)
		local textureId = "world-dir-" .. key
		local pos = POSITIONS[i]
		self.markers["annih"][key] = {
			pos = { pos[1] + 400 * x, ELEVATION, pos[2] + 400 * y },
			texture = "world-pointer",
			size = 400,
			color = self:GetSetting("directionsColorBG"),
			groundOverlay = {
				texture = textureId,
				size = 190,
				offsetV = 50,
				color = self:GetSetting("directionsColorFG"),
			},
			groundAngle = angle,
		}
		self.markers[(i % 2 == 1) and "enervC" or "enervI"][key] = {
			pos = { pos[1] + 100 * x, ELEVATION, pos[2] + 100 * y },
			texture = textureId,
			size = 200,
			elevation = 350,
			color = self:GetSetting("directionsColorFG"),
			playerFacing = true,
		}
	end
end

function Module:ShowMarkerGroup( groupName )
	if (not self:GetSetting("directions")) then return end

	if (not self.markers) then
		self:InitializeMarkers()
	end

	CA2.WorldCanvasClear()
	for _, marker in pairs(self.markers[groupName]) do
		CA2.WorldTexturePlace(marker)
	end
end

CA2.RegisterModule(Module)
