local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U30"
Module.NAME = CA2.GenerateModuleName(30, 1263)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1263, -- Rockgrove
}

Module.STRINGS = {
	-- Extracted
	["8290981-0-101465"] = { default = "Iron Atronach^n", de = "Eisenatronach^m", es = "atronach de hierro^m", fr = "atronach de fer^m", jp = "鉄の精霊^n", ru = "Железный атронах^n", zh = "铁侍灵" },
	["8290981-0-101466"] = { default = "Havocrel Goliath^m", de = "Chaosblute-Hüne^m", es = "havocrel goliat^m", fr = "goliath ravagerel^m", jp = "ハヴォクレルの巨人^m", ru = "Хаосид-исполин^m", zh = "浩劫盲侍巨人^m" },
	["8290981-0-102633"] = { default = "Fire Behemoth^m", de = "Feuerbehemoth^m", es = "behemot de fuego^m", fr = "bénémoth de feu^m", jp = "ファイア・ベヒーモス^m", ru = "Огненное чудовище^m", zh = "火焰巨兽^m" },

	-- Custom (Settings)
	eyeLeftRight = { default = "Show left/right arrows for initial Creeping Eye" },
	eyeArrow = { default = "Creeping Eye ground arrows" },
	fieryDetonation = { default = "Fiery Detonation timer" },
	fieryDetonation2 = { default = "On for non-healers" },
	volatileShellLabels = { default = "Position labels for Xalvakka's Volatile Shells" },
	volatileShellLabels1 = { default = "Directions" },
	volatileShellLabels2 = { default = "Letters" },
}

local DEFAULT_VOLATILE_SHELL_MODE = ZO_IsConsoleOrGameCoreUI() and 1 or 2

local ASTRAL_STATE_NONE = 0
local ASTRAL_STATE_CASTING = 1
local ASTRAL_STATE_SHIELDED = 2
local ASTRAL_STATE_SHIELDED_CASTING = 3

Module.DEFAULT_SETTINGS = {
	eyeLeftRight = false,
	eyeArrow = 0x99CCFF66,
	fieryDetonation = 2,
	volatileShellLabels = nil,
}

Module.DATA = {
	blitz = {
		[149414] = true,
		[157932] = true,
	},
	cinder = 152688,
	convoke = 150026,
	meteorSwarm = 155357,
	meteorCall = 152414,
	astral = {
		cast = 149089,
		shield = 157236,
	},
	deadeye = 152558,
	takingAim = 157243,
	rancidHammer = 149922,
	fieryDetonation = 157337,
	eye = {
		[153517] = { SI_LCA_CW, 1, "world-rotate-chevrons", "←" },
		[153518] = { SI_LCA_CCW, -1, "world-rotate-chevrons-ccw", "→" },
	},
	behemothSpawn = 10298, -- Unfortunately, this detects almost every enemy unit spawn, so filtering is needed
	behemothExclusions = {
		-- All the things that are not Fire Behemoth spawns
		[150030] = true, -- Summon Abomination
		[152568] = true, -- Summon Burning Specter
		[152809] = true, -- Relentless
		[152820] = true, -- Meteor Swarm
	},
	embrace = {
		[152654] = "k", -- Kiss of Death
		[158383] = "e", -- Embrace of Death
		nameId = 158383,
	},
	spawns = {
		[150760] = "8290981-0-101465", -- Iron Atronach
		[157467] = "8290981-0-101466", -- Havocrel Goliath
	},
	volatileShell = 149294,
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		[149531] = { -2, 2 }, -- Blistering Smash
		[149648] = { -2, 2 }, -- Ravenous Chomp
		[150065] = { -2, 2 }, -- Rend Flesh
		[150308] = { -2, 2 }, -- Power Bash
		[153181] = { -2, 2 }, -- Sunburst (Boss #1)
		[156982] = { -2, 2 }, -- Sunburst (Boss #2 and Trash)
		[156995] = { -2, 2 }, -- Monstrous Cleave
		[157265] = { -2, 2 }, -- Kiss of Poison
		[157471] = { -2, 2 }, -- Uppercut
		[149180] = { -2, 2 }, -- Scathing Evisceration (Hit #1)
		[153448] = { -2, 2 }, -- Scathing Evisceration (Hit #4)
		[153450] = { -2, 2 }, -- Scathing Evisceration (Hit #5)
		[157180] = { -3, 2, true }, -- Rockgrove -- Icy Salvo
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[150002] = { 1100, false }, -- Mouldering Taint
		[150137] = { 600, false }, -- Hot Spring
		[152556] = { 1100, false }, -- Noxious Pool
		[157308] = { 600, true }, -- Directed Volley
		[157859] = { 1000, false }, -- Noxious Puddle
	}

	self.vars = {
		astral = {
			bannerId = nil,
			state = ASTRAL_STATE_NONE,
			stateEnd = 0,
			count = 0,
		},
		coneCount = 0,
		bahsei = false,
		behemothExclusions = { },
		embrace = {
			prev = 0,
			k = { },
			e = { },
		},
	}
	Vars = self.vars

	self:HandleCompatibility()
	self:MigrateLegacyGroundArrowSettings() -- TODO: Remove in 2027

	self.BannerPoll_Astral = function( )
		local a = Vars.astral
		if (a.stateEnd < GetGameTimeMilliseconds()) then
			CA1.DisableBanner(a.bannerId)
			a.bannerId = nil
			a.state = ASTRAL_STATE_NONE
		end
		if (a.bannerId) then
			local statusText
			if (a.state == ASTRAL_STATE_SHIELDED) then
				statusText = string.format("%d×", a.count)
			elseif (a.state == ASTRAL_STATE_SHIELDED_CASTING) then
				statusText = string.format("%d× + %s", a.count, GetString(SI_LCA_CHANNELING))
			else
				statusText = GetString(SI_LCA_CHANNELING)
			end
			CA1.ModifyBanner(a.bannerId, nil, string.format("%s: %s", LCA.GetAbilityName(DATA.astral.shield), statusText), 0x00FFFFFF)
		end
	end
end

function Module:PreStartListening( )
	Vars.coneCount = 0
	Vars.bahsei = false
	ZO_ClearTable(Vars.behemothExclusions)
end

function Module:PostStopListening( )
	CA2.WorldCanvasClear()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	if (result == ACTION_RESULT_BEGIN and DATA.blitz[abilityId]) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.cinder) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CA1.Alert(nil, zo_strformat(SI_LCA_TARGET_YOU, LCA.GetAbilityName(abilityId)), 0xFF9900FF, nil, 2000)
			LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 3)
		end
		CA1.AlertCast(abilityId, nil, 2500, { -2, 0, true, { 1, 0.4, 0, 0.2 }, { 1, 0.4, 0, 0.6 } })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.deadeye) then
		if (LCA.DoesPlayerHaveSingleTargetPullSlotted()) then
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC0000FF, SOUNDS.OBJECTIVE_DISCOVERED, hitValue)
		end
		Vars.bahsei = true
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.convoke) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x00FFFFFF, SOUNDS.OBJECTIVE_DISCOVERED, hitValue)
		Vars.bahsei = true
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.rancidHammer and LCA.DoesPlayerHaveTauntSlotted()) then
		CA1.AlertCast(abilityId, nil, 2300, { -2, 2 })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.fieryDetonation) then
		local mode = self:GetSetting("fieryDetonation")
		if (mode == 1 or (mode == 2 and not LCA.isHealer)) then
			CA1.AlertCast(abilityId, nil, 2000, { -2, 0, true, { 1, 0.4, 0, 0.2 }, { 1, 0.4, 0, 0.6 } })
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.behemothSpawn and hitValue == 1 and Vars.bahsei and LCA.DoesPlayerHaveTauntSlotted() and LCA.GetUnitHealthPercent("boss1") < 51) then
		zo_callLater(function( )
			if (LCA.IsUnitIdValid(targetUnitId) and not Vars.behemothExclusions[targetUnitId]) then
				CA1.Alert(nil, zo_strformat(SI_UNIT_NAME, self:GetString("8290981-0-102633")), 0xCC0000FF, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
			end
		end, 100)
	elseif (targetUnitId and DATA.behemothExclusions[abilityId]) then
		Vars.behemothExclusions[targetUnitId] = true
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.meteorSwarm) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF9900FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 3000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.meteorCall) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF9900FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.astral.cast) then
		local a = Vars.astral
		a.stateEnd = GetGameTimeMilliseconds() + hitValue + 500
		if (a.state == ASTRAL_STATE_NONE) then
			a.state = ASTRAL_STATE_CASTING
			a.bannerId = CA1.AlertBannerEx(nil, nil, nil, nil, true, SOUNDS.CHAMPION_POINTS_COMMITTED, self.BannerPoll_Astral)
		elseif (a.state == ASTRAL_STATE_SHIELDED) then
			a.state = ASTRAL_STATE_SHIELDED_CASTING
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.astral.shield) then
		local a = Vars.astral
		if (a.state ~= ASTRAL_STATE_NONE) then
			if (a.state ~= ASTRAL_STATE_SHIELDED) then
				if (a.state ~= ASTRAL_STATE_SHIELDED_CASTING) then
					a.count = 0
				end
				a.state = ASTRAL_STATE_SHIELDED
				a.stateEnd = GetGameTimeMilliseconds() + 2000
				LCA.PlaySounds("RAID_TRIAL_FAILED") -- Or DEATH_RECAP_KILLING_BLOW_SHOWN?
			end
			a.count = a.count + 1
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.eye[abilityId]) then
		self:CreepingEye(unpack(DATA.eye[abilityId]))
	elseif (result == ACTION_RESULT_EFFECT_GAINED and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.takingAim) then
		local id = CA1.AlertCast(abilityId, sourceName, 3000, { -3, 2, true })
		if (LCA.IsUnitIdValid(sourceUnitId)) then
			self.castSources[sourceUnitId] = id
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.spawns[abilityId] and LCA.DoesPlayerHaveTauntSlotted()) then
		CA1.Alert(LCA.GetAbilityName(abilityId), zo_strformat(SI_UNIT_NAME, self:GetString(DATA.spawns[abilityId])), 0xFF0066FF, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
	elseif (abilityId == DATA.volatileShell) then
		if (result == ACTION_RESULT_BEGIN) then
			self:VolatileShellLabels()
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.WorldCanvasClear()
		end
	end
end

function Module:GetSettingsControls( )
	self:MigrateLegacyGroundArrowSettings() -- TODO: Remove in 2027
	return {
		--------------------
		{
			type = "checkbox",
			name = self:GetString("eyeLeftRight"),
			getFunc = function() return self:GetSetting("eyeLeftRight") end,
			setFunc = function(enabled) self:SetSetting("eyeLeftRight", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("eyeArrow"),
			getFunc = function() return self:GetSetting("eyeArrow") ~= 0 end,
			setFunc = function(enabled) self:SetSetting("eyeArrow", not enabled and 0 or nil) end,
		},
		--------------------
		{
			type = "colorpicker",
			getFunc = function() return LCA.UnpackRGBA(self:GetSetting("eyeArrow")) end,
			setFunc = function(...) self:SetSetting("eyeArrow", LCA.PackRGBA(...)) end,
			disabled = function() return self:GetSetting("eyeArrow") == 0 end,
		},
		--------------------
		{
			type = "dropdown",
			name = self:GetString("fieryDetonation"),
			choices = { GetString(SI_CHECK_BUTTON_OFF), GetString(SI_CHECK_BUTTON_ON), self:GetString("fieryDetonation2") },
			choicesValues = { 0, 1, 2 },
			getFunc = function() return self:GetSetting("fieryDetonation") end,
			setFunc = function(mode) self:SetSetting("fieryDetonation", mode) end,
		},
		--------------------
		{
			type = "dropdown",
			name = self:GetString("volatileShellLabels"),
			choices = { GetString(SI_CHECK_BUTTON_OFF), self:GetString("volatileShellLabels1"), self:GetString("volatileShellLabels2") },
			choicesValues = { 0, 1, 2 },
			getFunc = function() return self:GetVolatileShellMode() end,
			setFunc = function(mode) self:SetSetting("volatileShellLabels", mode) end,
		},
	}
end

function Module:HandleCompatibility( )
	-- Disable broken or incompatible parts from Qcell's addon
	if (QRH) then
		if (QRH.savedVariables) then
			QRH.savedVariables.showBahseiSlamForTanks = false
		end
		if (QRH.data) then
			QRH.data.soulweaver_shield = "off"
			QRH.data.soulweaver_remnant = "off"
		end
	end
end

-- TODO: Remove in 2027
function Module:MigrateLegacyGroundArrowSettings( )
	local color = self:GetSetting("groundArrow")
	if (color == false) then
		self:SetSetting("eyeArrow", 0)
	elseif (type(color) == "number") then
		self:SetSetting("eyeArrow", color)
	end
	self:SetSetting("groundArrow", nil)
end

function Module:CreepingEye( textId, orientation, groundTextureId, lrArrow )
	local duration = 5000
	Vars.coneCount = Vars.coneCount + 1

	CA1.Alert(nil, string.format("%s%s %s", (self:GetSetting("eyeLeftRight") and Vars.coneCount == 1) and string.format("%s ", lrArrow) or "", GetString(textId), zo_iconFormatInheritColor(LCA.GetTexture("arrow-rotate"), 96, 96 * orientation)), 0xFF0066FF, SOUNDS.CHAMPION_POINTS_COMMITTED, duration)

	local color = self:GetSetting("eyeArrow")

	if (color ~= 0) then
		CA2.WorldTexturePlace({
			pos = { 99900, 42750, 99650 },
			texture = groundTextureId,
			size = 3600,
			color = color,
			update = function( elementId, startTime )
				local elapsed = GetGameTimeMilliseconds() - startTime
				if (elapsed >= duration) then
					CA2.WorldElementRemove(elementId)
				else
					CA2.WorldTextureUpdate(elementId, "groundAngle", -orientation * (elapsed / duration) * ZO_TWO_PI / 3)
				end
				return true
			end,
			updateParam = GetGameTimeMilliseconds(),
		})
	end
end

function Module:GetVolatileShellMode( )
	local mode = self:GetSetting("volatileShellLabels")
	if (mode == true) then
		mode = DEFAULT_VOLATILE_SHELL_MODE
	elseif (mode == false) then
		mode = 0
	elseif (mode == nil) then
		if (ZO_IsConsoleOrGameCoreUI() or not QRH or not OSI) then
			self:SetSetting("volatileShellLabels", DEFAULT_VOLATILE_SHELL_MODE)
			return DEFAULT_VOLATILE_SHELL_MODE
		else
			return 0
		end
	end
	return mode
end

function Module:VolatileShellLabels( )
	local mode = self:GetVolatileShellMode()
	if (mode == 0) then return end

	local MID = 160000
	local THIRDS = ZO_TWO_PI / 3
	local FLOORS = {
		{	-- Second floor
			elevation = 34500,
			distance = 1600,
			offset = 0,
			textures = {
				{ "dir-n", "letter-b" },
				{ "dir-sw", "letter-c" },
				{ "dir-se", "letter-a" },
			},
		},
		{	-- Third floor
			elevation = 38500,
			distance = 2000,
			offset = ZO_TWO_PI / 8,
			textures = {
				{ "dir-nw", "letter-c" },
				{ "dir-s", "letter-b" },
				{ "dir-e", "letter-a" },
			},
		},
	}

	local elevP = select(3, GetUnitRawWorldPosition("player"))

	for _, floor in ipairs(FLOORS) do
		local elevF, distance, offset = floor.elevation, floor.distance, floor.offset
		if (zo_abs(elevF - elevP) < 400) then
			for i, texture in ipairs(floor.textures) do
				local angle = offset + THIRDS * (i - 1)
				CA2.WorldTexturePlace({
					pos = { MID - distance * math.sin(angle), elevF, MID - distance * math.cos(angle) },
					texture = "world-" .. texture[mode],
					size = 300,
					elevation = 750,
					playerFacing = true,
					disableDepthBuffers = true,
				})
			end
		end
	end
end

CA2.RegisterModule(Module)
