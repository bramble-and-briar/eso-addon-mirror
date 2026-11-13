local LCA = LibCombatAlerts

CombatAlerts = {
	name = "CombatAlerts",

	title = "Combat Alerts",
	version = LCA.FormatVersion(LCA.GetAddOnVersion("CombatAlerts")),

	slashCommand = "/cca",

	-- Default settings
	defaults = {
		panelLeft = 400,
		panelTop = 300,
		debugEnabled = false,
		debugLog = { },
		crushing = false,
		lokiStance = false,
		maxCastMS = 4000,
		projectileTimingAdjustment = 0.8,
		castAlertsEnabled = true,
		castAlertsSound = true,
		verboseCasts = false,
		crshift = true,
		extTDC = false,
		extMA = false,
	},

	pollingInterval = 100, -- 0.1 seconds
	castUpdateInterval = 50, -- 0.05 seconds, 20 FPS
	bannerUpdateInterval = 50, -- 0.05 seconds
	panelRows = 3,

	dodgeDuration = GetAbilityDuration(28549),
	dodgeText = "Dodge!",
	incomingText = GetString(SI_INTERFACE_OPTIONS_COMBAT_SCT_INCOMING_ENABLED),

	zoneId = 0,
	isVet = false,
	isDamage = false,
	isHealer = false,
	isTank = false,
	initialized = false,
	listening = false,
	continuousListen = false,
	units = { },
	bosses = { },

	divertNextEvent = nil,

	currentBoss = "",

	castAlerts = {
		nextId = 0,
		fillWidth = 200,
		bars = { },
		active = { },
		sources = { },
		polling = false,
	},

	activeBanners = { },

	guardUnit = nil,

	maelstrom = {
		lastObelisk = 0,
	},

	scalecaller = {
		blastAll = 0,
		blastId = 0,
	},

	fanglair = {
		tigerId = 0,
		nextGrip = 0,
	},

	cloudrest = {
		shadowRealm = false,
		executeStart = 0,
		banefulPrev = 0,
		banefulCast = 0,
		zmajaTaunt = 0,
		lastCharge = 0,
		flare = {
			previous = 0,
			stop = 0,
			units = { },
			preyed = { },
			switcher = "",
		},
	},

	frostvault = {
		effluviumEnd = 0,
		skeevCharged = 0,
		skeevMode = false,
	},

	sunspire = {
		lokiGrounded = false,
		tomb = 0, -- 0: inactive, 1: casting, 2: activating, 3: active, 4: between casts
		tombPrev = 0,
		tombNext = 0,
		tombId = 0,
		tombActive = 0,
		tombDeadline = 0,
		tombText = "",
		tombTextNext = "",
		atroNext = 0,
		breathPrev = 0,
		breathInitial = false,
		bottomActive = false,
		translation = 0, -- 1: initial 2s, 2: interrupt, 3: between casts
		translationNext = 0,
		translationDeadline = 0,
		lastFocusFire = 0,
		lastSoulTear = 0,
		battleFury = { },
	},

	fane = {
		geyserActive = false,
		geyserDuration = 22000,
		nextGeyserEnd = 0,
		lastGeyserEnd = 0,
		lastGeyserPlug = 0,
		direMawId = 0,
		spawns = { },
	},

	maarselok = {
		lastSeed = 0,
		wickedBonds = nil,
		shagraths = { },
	},

	stonethorn = {
		memoryGame = {
			enabled = false,
			idx = 1,
			ids = { 0, 0, 0, 0 },
			disembowel = 0,
		},
	},

	tide = {
		bombs = { },
		link1 = "",
	},
}

function CombatAlerts.OnAddOnLoaded( )
	CombatAlerts.vars = ZO_SavedVars:NewAccountWide("CombatAlertsSavedVariables", 1, nil, CombatAlerts.defaults, nil, "$InstallationWide")

	SLASH_COMMANDS[CombatAlerts.slashCommand] = CombatAlerts.HandleSlashCommand
end

local function UnpackRGBA( rgba )
	local a = rgba % 256
	rgba = (rgba - a) / 256
	local b = rgba % 256
	rgba = (rgba - b) / 256
	local g = rgba % 256
	rgba = (rgba - g) / 256
	local r = rgba % 256

	return r / 255, g / 255, b / 255, a / 255
end

function CombatAlerts.HandleSlashCommand( command )
	command = string.lower(command)

	if (command == "move") then
		CombatAlerts.ToggleTestPanel(true)
	elseif (command == "crushing") then
		CombatAlerts.vars.crushing = not CombatAlerts.vars.crushing
		CHAT_ROUTER:AddSystemMessage(string.format(
			"[%s] %s: %s",
			CombatAlerts.title,
			CombatAlertsData.cloudrest.crushingName,
			GetString(CombatAlerts.vars.crushing and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
		))
	elseif (command == "casts") then
		CombatAlerts.vars.castAlertsEnabled = not CombatAlerts.vars.castAlertsEnabled
		CHAT_ROUTER:AddSystemMessage(string.format(
			"[%s] Cast Alerts: %s",
			CombatAlerts.title,
			GetString(CombatAlerts.vars.castAlertsEnabled and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
		))
	elseif (command == "castsounds") then
		CombatAlerts.vars.castAlertsSound = not CombatAlerts.vars.castAlertsSound
		CHAT_ROUTER:AddSystemMessage(string.format(
			"[%s] Cast Alert Sounds: %s",
			CombatAlerts.title,
			GetString(CombatAlerts.vars.castAlertsSound and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
		))
	elseif (command == "lokistance") then
		CombatAlerts.vars.lokiStance = not CombatAlerts.vars.lokiStance
		CHAT_ROUTER:AddSystemMessage(string.format(
			"[%s] Lokkestiiz Defensive Stance: %s",
			CombatAlerts.title,
			GetString(CombatAlerts.vars.lokiStance and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
		))
	elseif (command == "crshift") then
		CombatAlerts.vars.crshift = not CombatAlerts.vars.crshift
		CHAT_ROUTER:AddSystemMessage(string.format(
			"[%s] Cloudrest Shifting Shadows Cone: %s",
			CombatAlerts.title,
			GetString(CombatAlerts.vars.crshift and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
		))
	elseif (command == "vma") then
		CombatAlerts.vars.extMA = not CombatAlerts.vars.extMA
		CHAT_ROUTER:AddSystemMessage(string.format(
			"[%s] Maelstrom Extensions: %s",
			CombatAlerts.title,
			GetString(CombatAlerts.vars.extMA and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
		))
	elseif (command == "tdcext") then
		CombatAlerts.vars.extTDC = not CombatAlerts.vars.extTDC
		CHAT_ROUTER:AddSystemMessage(string.format(
			"[%s] Magma Incarnate Catastrophe: %s",
			CombatAlerts.title,
			GetString(CombatAlerts.vars.extTDC and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
		))
	else
		CHAT_ROUTER:AddSystemMessage(CombatAlerts.title)
		CHAT_ROUTER:AddSystemMessage("/cca move – Move status display")
		CHAT_ROUTER:AddSystemMessage("/cca casts – Enable/Disable Cast Alerts")
		CHAT_ROUTER:AddSystemMessage("/cca castsounds – Enable/Disable Cast Alert Sounds")
		CHAT_ROUTER:AddSystemMessage("/cca crushing – Toggle Crushing Darkness alert aura")
		CHAT_ROUTER:AddSystemMessage("/cca crshift – Toggle Shifting Shadows dodge timer")
		CHAT_ROUTER:AddSystemMessage("/cca vma – Toggle Maelstrom Arena extensions")
	end
end

function CombatAlerts.Initialize( )
	if (not CombatAlerts.initialized) then
		CombatAlerts.initialized = true
		CombatAlerts.InitializeUI()
	end
end

local isLegacyEnabled = false
function CombatAlerts.ToggleLegacy( enable )
	if (enable and not isLegacyEnabled) then
		isLegacyEnabled = true
		EVENT_MANAGER:RegisterForEvent(CombatAlerts.name, EVENT_PLAYER_ACTIVATED, CombatAlerts.PlayerActivated)
		CombatAlerts.PlayerActivated()
		EVENT_MANAGER:RegisterForEvent(CombatAlerts.name, EVENT_PLAYER_COMBAT_STATE, CombatAlerts.PlayerCombatState)
		if (IsUnitInCombat("player")) then
			CombatAlerts.PlayerCombatState(nil, true)
		end
	elseif (not enable and isLegacyEnabled) then
		isLegacyEnabled = false
		EVENT_MANAGER:UnregisterForEvent(CombatAlerts.name, EVENT_PLAYER_ACTIVATED)
		EVENT_MANAGER:UnregisterForEvent(CombatAlerts.name, EVENT_PLAYER_COMBAT_STATE)
		CombatAlerts.StopListening()
	end
end

function CombatAlerts.PlayerActivated( eventCode, initial )
	CombatAlerts.zoneId = LCA.GetZoneId()
	CombatAlerts.isVet = GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN

	if (CombatAlertsData.bossCheckZoneIds[CombatAlerts.zoneId]) then
		EVENT_MANAGER:RegisterForEvent(CombatAlerts.name, EVENT_BOSSES_CHANGED, CombatAlerts.BossesChanged)
		CombatAlerts.currentBoss = ""
		CombatAlerts.BossesChanged()
	else
		CombatAlerts.BossesChanged()
		EVENT_MANAGER:UnregisterForEvent(CombatAlerts.name, EVENT_BOSSES_CHANGED)
	end

	CombatAlerts.ThornMemoryGame(CombatAlerts.isVet and CombatAlerts.zoneId == CombatAlertsData.stonethorn.memoryGame.zoneId)
end

function CombatAlerts.PlayerCombatState( eventCode, inCombat )
	if (inCombat) then
		CombatAlerts.StartListening()
	else
		-- Avoid false positives of combat end, often caused by combat rezzes
		zo_callLater(function() if (not IsUnitInCombat("player")) then CombatAlerts.StopListening() end end, 3000)
	end
end

function CombatAlerts.StartListening( )
	if (not CombatAlerts.listening) then
		CombatAlerts.listening = true
		CombatAlerts.castAlerts.sources = { }
		CombatAlerts.sunspire.tombId = 0
		CombatAlerts.maarselok.wickedBonds = nil
		CombatAlerts.maarselok.shagraths = { }

		LCA.RegisterForFilteredEvent(CombatAlerts.name, EVENT_COMBAT_EVENT, CombatAlerts.CombatEvent, REGISTER_FILTER_IS_ERROR, false)

		if (CombatAlertsData.effectTrackingZoneIds[CombatAlerts.zoneId]) then
			CombatAlerts.units = { }
			CombatAlerts.bosses = { }
			EVENT_MANAGER:RegisterForEvent(CombatAlerts.name, EVENT_EFFECT_CHANGED, CombatAlerts.EffectChanged)
		end
	end

	CombatAlerts.isDamage = LCA.isDamage
	CombatAlerts.isHealer = LCA.isHealer
	CombatAlerts.isTank = LCA.isTank
end

function CombatAlerts.StopListening( )
	if (CombatAlerts.listening and not CombatAlerts.continuousListen) then
		CombatAlerts.listening = false
		EVENT_MANAGER:UnregisterForEvent(CombatAlerts.name, EVENT_COMBAT_EVENT)
		EVENT_MANAGER:UnregisterForEvent(CombatAlerts.name, EVENT_EFFECT_CHANGED)

		if (CombatAlerts.panel.autoHide) then
			CombatAlerts.TogglePanel(false, nil, true)
		end
		CombatAlerts.AlertBorder(false)
	end
end

function CombatAlerts.ToggleContinuousListen( enable )
	if (enable) then
		CombatAlerts.continuousListen = true
		CombatAlerts.StartListening()
	else
		CombatAlerts.continuousListen = false
		CombatAlerts.PlayerCombatState(nil, false)
	end
end

function CombatAlerts.CombatEvent( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
	if (CombatAlerts.divertNextEvent) then
		local fn = CombatAlerts.divertNextEvent
		CombatAlerts.divertNextEvent = nil
		if (fn(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)) then
			return
		end
	end


	-- Perfect Roll ------------------------------------------------------------

	if (result == ACTION_RESULT_BEGIN and targetType == COMBAT_UNIT_TYPE_PLAYER and CombatAlertsData.dodge.ids[abilityId]) then
		local options = CombatAlertsData.dodge.ids[abilityId]
		if (CombatAlerts.isVet or not options.vet) then
			local offset = options.offset or 0
			local id = CombatAlerts.AlertCast(abilityId, sourceName, hitValue + offset, options)
			if (options[3] and LCA.IsUnitIdValid(sourceUnitId)) then
				CombatAlerts.castAlerts.sources[sourceUnitId] = id
			end
			if (options.cutthroat) then
				CombatAlerts2.SetNightbladeCutthroatExclusion(GetGameTimeMilliseconds() + hitValue + offset)
			end
		end
	elseif (CombatAlertsData.dodge.interrupts[result] and CombatAlerts.castAlerts.sources[targetUnitId]) then
		CombatAlerts.CastAlertsStop(CombatAlerts.castAlerts.sources[targetUnitId])


	-- Guard Tracking ----------------------------------------------------------

	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.general.guard and sourceType == COMBAT_UNIT_TYPE_PLAYER) then
		CombatAlerts.guardUnit = targetUnitId
	elseif (result == ACTION_RESULT_EFFECT_FADED and abilityId == CombatAlertsData.general.guard and targetUnitId == CombatAlerts.guardUnit) then
		CombatAlerts.guardUnit = nil


	-- Misc --------------------------------------------------------------------
	elseif (result == ACTION_RESULT_BEGIN and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == CombatAlertsData.misc.shadowStrike.id and hitValue == CombatAlertsData.misc.shadowStrike.channel) then
		CombatAlerts.AlertCast(abilityId, sourceName, hitValue + CombatAlertsData.misc.shadowStrike.cast, { -2, 2 })

	-- Maelstrom Arena ---------------------------------------------------------

	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.maelstrom.webspinner and hitValue == 0) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC00FFFF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.maelstrom.ghost and hitValue == 0 and CombatAlerts.vars.extMA) then
		CombatAlerts.Alert(nil, "GHOST", 0xFFD700FF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.maelstrom.turretoccupied and hitValue == 0 and CombatAlerts.vars.extMA) then
		CombatAlerts.Alert(nil, "SENTRY", 0xCD7F32FF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.maelstrom.troll and CombatAlerts.vars.extMA) then
		CombatAlerts.Alert(nil, "TROLL", 0xFFFFFFFF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.maelstrom.enrage and CombatAlerts.vars.extMA) then
		CombatAlerts.Alert(nil, "ENRAGE", 0xC21E56FF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.maelstrom.hoarvor and CombatAlerts.vars.extMA) then
		CombatAlerts.Alert(nil, "HOARVOR", 0x006400FF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.maelstrom.artifacts and CombatAlerts.vars.extMA) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - CombatAlerts.maelstrom.lastObelisk >= 3000) then
			CombatAlerts.maelstrom.lastObelisk = currentTime
			CombatAlerts.Alert(nil, "OBELISK", 0xFFD700FF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)
		end


	-- Scalecaller Peak --------------------------------------------------------

	elseif (result == ACTION_RESULT_BEGIN and CombatAlertsData.scalecaller.blastIds[abilityId]) then
		if (GetGameTimeMilliseconds() - CombatAlerts.scalecaller.blastAll >= 2500) then
			CombatAlerts.scalecaller.blastId = abilityId
			CombatAlerts.divertNextEvent = CombatAlerts.ScalecallerBreathEvent
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.scalecaller.beamId and hitValue == 3000) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)


	-- Fang Lair ---------------------------------------------------------------

	elseif (abilityId == CombatAlertsData.fanglair.grip) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.fanglair.tigerId = targetUnitId
			CombatAlerts.FangLairResetTimer(CombatAlertsData.fanglair.interval)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.fanglair.tigerId = 0
		end
	elseif (abilityId == CombatAlertsData.fanglair.stare) then
		if (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.FangLairResetTimer(CombatAlertsData.fanglair.interval)
		elseif (result == ACTION_RESULT_EFFECT_GAINED and CombatAlerts.vars.debugEnabled) then
			CombatAlerts.Debug(string.format("Tiger Pounce: %dms deviation from expectation", GetGameTimeMilliseconds() - CombatAlerts.fanglair.nextGrip))
		end
	elseif (result == ACTION_RESULT_FEARED and abilityId == CombatAlertsData.fanglair.fear) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(CombatAlertsData.fanglair.grip), targetName, 0xFF00CCFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == CombatAlertsData.fanglair.dormant and targetUnitId == CombatAlerts.fanglair.tigerId) then
		CombatAlerts.FangLairResetTimer(hitValue)


	-- Cloudrest ---------------------------------------------------------------

	elseif (result == ACTION_RESULT_EFFECT_FADED and abilityId == CombatAlertsData.cloudrest.amulet) then
		CombatAlerts.cloudrest.executeStart = GetGameTimeMilliseconds()
		CombatAlerts.cloudrest.banefulPrev = CombatAlerts.cloudrest.executeStart
		CombatAlerts.TogglePanel(true, { CombatAlertsData.cloudrest.banefulName, CombatAlertsData.cloudrest.flareName }, true, true)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.cloudrest.baneful) then
		CombatAlerts.cloudrest.banefulPrev = GetGameTimeMilliseconds()
		CombatAlerts.cloudrest.banefulCast = hitValue
	elseif (result == ACTION_RESULT_BEGIN and CombatAlertsData.cloudrest.flare[abilityId]) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - CombatAlerts.cloudrest.flare.previous >= 1000) then
			CombatAlerts.cloudrest.flare.previous = currentTime
			CombatAlerts.cloudrest.flare.units[1] = targetUnitId
		else
			CombatAlerts.cloudrest.flare.stop = currentTime + CombatAlertsData.cloudrest.flareDuration
			CombatAlerts.cloudrest.flare.units[2] = targetUnitId

			CombatAlerts.cloudrest.flare.switcher = ""

			if ( CombatAlerts.units[CombatAlerts.cloudrest.flare.units[1]] and CombatAlerts.units[targetUnitId] and
			     CombatAlerts.GetDistance(CombatAlerts.units[CombatAlerts.cloudrest.flare.units[1]].tag, CombatAlerts.units[targetUnitId].tag) < 7 ) then
				local switcherUnitId = targetUnitId

				if (abilityId ~= CombatAlertsData.cloudrest.flare.execute or GetGroupMemberSelectedRole(CombatAlerts.units[targetUnitId].tag) == LFG_ROLE_HEAL) then
					switcherUnitId = CombatAlerts.cloudrest.flare.units[1]
				end

				CombatAlerts.cloudrest.flare.switcher = string.format(" (%s)", CombatAlerts.units[switcherUnitId].name)
			end
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.cloudrest.sparkles and GetGameTimeMilliseconds() <= CombatAlerts.cloudrest.zmajaTaunt) then
		zo_callLater(function() CombatAlerts.Alert(CombatAlerts.incomingText, "Sparkles", 0x66CCFFFF, SOUNDS.OBJECTIVE_DISCOVERED, 2000) end, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.cloudrest.beadCharge and not CombatAlerts.cloudrest.shadowRealm) then
		CombatAlerts.cloudrest.lastCharge = GetGameTimeMilliseconds()
		CombatAlerts.Alert(nil, "Malicious Sphere Charge", 0xFF0033FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.cloudrest.beadSpawn and not CombatAlerts.cloudrest.shadowRealm) then
		if (GetGameTimeMilliseconds() - CombatAlerts.cloudrest.lastCharge > 2000) then
			CombatAlerts.Alert(CombatAlerts.incomingText, CombatAlertsData.cloudrest.beadName, 0xFF0033FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.cloudrest.shiftShadows.start and CombatAlerts.vars.crshift) then
		local id = CombatAlerts.AlertCast(CombatAlertsData.cloudrest.shiftShadows.name, nil, hitValue, { 500, 0, false, { 0.7, 0.3, 1, 0.3 }, { 0.7, 0.3, 1, 0.7 } })
		if (LCA.IsUnitIdValid(targetUnitId)) then
			CombatAlerts.castAlerts.sources[targetUnitId] = id
		end
	elseif (result == ACTION_RESULT_STUNNED and abilityId == CombatAlertsData.cloudrest.shiftShadows.stop and CombatAlerts.castAlerts.sources[targetUnitId]) then
		CombatAlerts.CastAlertsStop(CombatAlerts.castAlerts.sources[targetUnitId])
	elseif (CombatAlerts.vars.crushing and result == ACTION_RESULT_EFFECT_GAINED and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == CombatAlertsData.cloudrest.crushing and GetGameTimeMilliseconds() > CombatAlerts.cloudrest.zmajaTaunt) then
		CombatAlerts.AlertBorder(true, 10000)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == CombatAlertsData.cloudrest.overload) then
		CombatAlerts.AlertBorder(true, hitValue, "blue")
	elseif (result == ACTION_RESULT_EFFECT_GAINED and targetType == COMBAT_UNIT_TYPE_PLAYER and CombatAlertsData.cloudrest.shadowRealm[abilityId]) then
		CombatAlerts.cloudrest.shadowRealm = true
		CombatAlerts.AlertBorder(false)
	elseif (result == ACTION_RESULT_EFFECT_FADED and targetType == COMBAT_UNIT_TYPE_PLAYER and CombatAlertsData.cloudrest.shadowRealm[abilityId]) then
		CombatAlerts.cloudrest.shadowRealm = false
	elseif (result == ACTION_RESULT_DIED and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CombatAlerts.AlertBorder(false)


	-- Frostvault --------------------------------------------------------------

	elseif (abilityId == CombatAlertsData.frostvault.effluvium) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			CombatAlerts.frostvault.effluviumEnd = GetGameTimeMilliseconds() + hitValue
			CombatAlerts.TogglePanel(true, LCA.GetAbilityName(abilityId), true, true)
			if (CombatAlerts.frostvault.skeevMode) then
				CombatAlerts.frostvault.skeevMode = false
				CombatAlerts.panel.label:SetText(LCA.GetAbilityName(abilityId))
			end
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.frostvault.effluviumEnd = GetGameTimeMilliseconds()
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and CombatAlertsData.frostvault.ignitionIds[abilityId]) then
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), LCA.GetAbilityName(CombatAlertsData.frostvault.embers), 0xFF6600FF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.frostvault.grind) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CombatAlerts.AlertCast(abilityId, sourceName, 2700, { 1200, 0, false, { 0.3, 0.9, 1, 0.6 }, { 0, 0.5, 1, 1 } })
		else
			local _, _, effectiveMax = GetUnitPower("boss1", COMBAT_MECHANIC_FLAGS_HEALTH)
			if (effectiveMax >= CombatAlertsData.frostvault.hardHealth) then
				CombatAlerts.AlertCast(CombatAlertsData.frostvault.whipping, nil, 1600, { 500, 2, false, { 0.3, 0.9, 1, 0.6 }, { 0, 0.5, 1, 1 } })
			end
		end
	elseif (not CombatAlerts.frostvault.skeevMode and result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.frostvault.skeevCharged) then
		CombatAlerts.frostvault.skeevMode = true
		CombatAlerts.frostvault.skeevCharged = GetGameTimeMilliseconds()
		CombatAlerts.panel.label:SetText(LCA.GetAbilityName(CombatAlertsData.frostvault.skeevWipe))
		CombatAlerts.panel.data:SetColor(1, 1, 1, 1)


	-- Depths of Malatar -------------------------------------------------------

	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.malatar.decrepify and not LCA.isTank) then
		CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId), 0xFFCC00FF, SOUNDS.OBJECTIVE_DISCOVERED, 2500)


	-- Sunspire -------------------------------------------------------

	elseif (CombatAlertsData.damageEvents[result] and targetType == COMBAT_UNIT_TYPE_PLAYER and CombatAlertsData.sunspire.standingInAoe[abilityId]) then
		local params = CombatAlertsData.sunspire.standingInAoe[abilityId]
		if (not (params[2] and LCA.isTank)) then
			CombatAlerts.AlertBorder(true, params[1])
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.sunspire.tomb) then
		local currentTime = GetGameTimeMilliseconds()
		local elapsed = currentTime - CombatAlerts.sunspire.tombPrev
		if ((elapsed >= 60000 and CombatAlerts.sunspire.tombId ~= 1) or elapsed >= 70000) then
			CombatAlerts.sunspire.tombId = 0
		end

		CombatAlerts.sunspire.tombText = string.format("%s #%d", LCA.GetAbilityName(abilityId), CombatAlerts.sunspire.tombId + 1)
		CombatAlerts.sunspire.tombId = (CombatAlerts.sunspire.tombId + 1) % 3
		CombatAlerts.sunspire.tombTextNext = string.format("%s #%d", LCA.GetAbilityName(abilityId), CombatAlerts.sunspire.tombId + 1)
		CombatAlerts.sunspire.lokiGrounded = true

		CombatAlerts.Alert(nil, CombatAlerts.sunspire.tombText, 0xFF00FFFF, SOUNDS.OBJECTIVE_DISCOVERED, 3000)
		CombatAlerts.panel.label:SetText(CombatAlerts.sunspire.tombText)

		CombatAlerts.sunspire.tombState = 1
		CombatAlerts.sunspire.tombPrev = currentTime
		CombatAlerts.sunspire.tombNext = currentTime + 23000
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.sunspire.negate) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0xFF00FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.sunspire.ignite) then
		CombatAlerts.Alert("Flame Atronach", LCA.GetAbilityName(abilityId), 0x0066FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.sunspire.geyser and not LCA.isTank) then
		if (GetGameTimeMilliseconds() < CombatAlerts.sunspire.lastFocusFire + 90000) then
			if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
				CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId), 0x0099CCFF, SOUNDS.DUEL_START, hitValue)
			elseif (CombatAlerts.DistanceCheck(targetUnitId, 2.7)) then
				CombatAlerts.Alert(CombatAlerts.units[targetUnitId].name, LCA.GetAbilityName(abilityId), 0x0099CCFF, SOUNDS.DUEL_START, hitValue)
			end
		end
	elseif (result == ACTION_RESULT_BEGIN and targetType ~= COMBAT_UNIT_TYPE_PLAYER and abilityId == CombatAlertsData.sunspire.glacialFist) then
		if (CombatAlerts.DistanceCheck(targetUnitId, 4)) then
			CombatAlerts.AlertCast(abilityId, nil, hitValue, { -2, 0, false, { 0.3, 0.9, 1, 0.6 }, { 0, 0.5, 1, 1 } })
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.sunspire.focusFire) then
		CombatAlerts.sunspire.lastFocusFire = GetGameTimeMilliseconds()
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == CombatAlertsData.sunspire.frostBolt and not LCA.isTank) then
		LCA.PlaySounds("DUEL_START")
	elseif (result == ACTION_RESULT_BEGIN and (targetType == COMBAT_UNIT_TYPE_PLAYER or LCA.isHealer) and CombatAlertsData.sunspire.breathIds[abilityId]) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - CombatAlerts.sunspire.breathPrev >= 6000) then
			CombatAlerts.sunspire.breathPrev = currentTime
			if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
				targetName = CombatAlerts.incomingText
				CombatAlerts.sunspire.breathInitial = true
			elseif (CombatAlerts.units[targetUnitId]) then
				targetName = CombatAlerts.units[targetUnitId].name
				CombatAlerts.sunspire.breathInitial = false
			end
			CombatAlerts.Alert(targetName, LCA.GetAbilityName(abilityId), 0xEECC00FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		elseif (CombatAlerts.sunspire.breathInitial) then
			CombatAlerts.sunspire.breathInitial = false
			CombatAlerts.AlertCast(abilityId, nil, hitValue, { -2, 0, false, { 1, 0, 0.6, 0.6 }, { 1, 0, 0.6, 1 } })
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.sunspire.soulTear) then
		CombatAlerts.sunspire.lastSoulTear = GetGameTimeMilliseconds()
		CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId) .. " — Heal!", 0x9933FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.sunspire.thrash) then
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), "Block or Dodge", 0xFF0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		CombatAlerts.AlertCast(abilityId, nil, hitValue, { -2, 0 })
	elseif (result == ACTION_RESULT_BEGIN and CombatAlertsData.sunspire.sweepingIds[abilityId] and hitValue < 2500) then
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), "Block — " .. CombatAlertsData.sunspire.sweepingIds[abilityId], 0xCC3300FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 3000)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == CombatAlertsData.sunspire.meteor) then
		CombatAlerts.Alert(nil, CombatAlertsData.sunspire.meteorName, 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		CombatAlerts.CastAlertsStart(CombatAlertsData.sunspire.meteorIcon, CombatAlertsData.sunspire.meteorName, hitValue, nil, nil, { hitValue, "Move!", 1, 0.4, 0, 0.5, nil })
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == CombatAlertsData.sunspire.battleFury) then
		CombatAlerts.sunspire.battleFury[targetUnitId] = GetGameTimeMilliseconds() + hitValue
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == CombatAlertsData.sunspire.chillingComet) then
		local currentTime = GetGameTimeMilliseconds()
		local enrageTime = CombatAlerts.sunspire.battleFury[sourceUnitId] or 0
		if (currentTime < enrageTime or currentTime < CombatAlerts.sunspire.lastSoulTear + 8000) then
			CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0x33CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2500)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.sunspire.summonFrost) then
		CombatAlerts.sunspire.atroNext = GetGameTimeMilliseconds() + 90000
	elseif (abilityId == CombatAlertsData.sunspire.icyPresence) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.sunspire.lokiGrounded = true
			CombatAlerts.sunspire.atroNext = 0
			CombatAlerts.sunspire.tombState = 0
			CombatAlerts.sunspire.tombActive = 0
			CombatAlerts.TogglePanel(true, { LCA.GetAbilityName(CombatAlertsData.sunspire.tomb), LCA.GetAbilityName(CombatAlertsData.sunspire.summonFrost) }, true, true)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.sunspire.lokiGrounded = false
		end
	elseif (abilityId == CombatAlertsData.sunspire.timeBreach and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.sunspire.bottomActive = true
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.sunspire.bottomActive = false
			CombatAlerts.TogglePanel(false, nil, true)
		end
	elseif (abilityId == CombatAlertsData.sunspire.translation) then
		if (result == ACTION_RESULT_BEGIN and hitValue == 2000) then
			CombatAlerts.sunspire.translation = 1
			CombatAlerts.TogglePanel(true, LCA.GetAbilityName(abilityId), true, true)
		elseif (result == ACTION_RESULT_BEGIN and hitValue == 5000) then
			CombatAlerts.sunspire.translation = 2
			CombatAlerts.sunspire.translationDeadline = GetGameTimeMilliseconds() + hitValue
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.sunspire.translation = 3
			CombatAlerts.sunspire.translationNext = GetGameTimeMilliseconds() + 20000
		end
	elseif (CombatAlerts.vars.lokiStance and CombatAlerts.zoneId == CombatAlertsData.sunspire.zone and abilityId == CombatAlertsData.sunspire.defensiveStance and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.AlertBorder(true)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.AlertBorder(false)
		end


	-- Moongrave Fane ----------------------------------------------------------

	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.fane.rockslide) then
		CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId), 0xEECC00FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (abilityId == CombatAlertsData.fane.geyser) then
		if (result == ACTION_RESULT_BEGIN) then
			if (hitValue <= 5000) then
				CombatAlerts.Alert(LCA.GetAbilityName(abilityId), "Stop Damage", 0xFF0000FF, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
				if (not CombatAlerts.panel.enabled) then
					CombatAlerts.fane.nextGeyserEnd = 0
					CombatAlerts.fane.lastGeyserEnd = 0
				end
				local currentTime = GetGameTimeMilliseconds()
			else
				CombatAlerts.fane.geyserActive = true
				CombatAlerts.fane.geyserDuration = hitValue
				CombatAlerts.fane.lastGeyserPlug = 0
				CombatAlerts.fane.nextGeyserEnd = GetGameTimeMilliseconds() + hitValue
				CombatAlerts.TogglePanel(true, { LCA.GetAbilityName(abilityId), LCA.GetAbilityName(CombatAlertsData.fane.geyserPlug) }, true, true)
			end
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.fane.geyserActive = false
			CombatAlerts.fane.lastGeyserEnd = GetGameTimeMilliseconds()
			CombatAlerts.Alert(LCA.GetAbilityName(abilityId), "Resume Damage", 0x00FF00FF, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.fane.geyserPlug and CombatAlerts.isVet) then
		local currentTime = GetGameTimeMilliseconds()
		CombatAlerts.AlertChat(string.format(
			"%s: %d%s",
			LCA.GetAbilityName(abilityId),
			hitValue,
			(hitValue > 1) and string.format(" (+%dms)", currentTime - CombatAlerts.fane.lastGeyserPlug) or ""
		))
		CombatAlerts.fane.lastGeyserPlug = currentTime
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.fane.shackles) then
		PlaySound(SOUNDS.CHAMPION_POINTS_COMMITTED)
	elseif (abilityId == CombatAlertsData.fane.drain and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.AlertBorder(true)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.AlertBorder(false)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.fane.wound and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CombatAlerts.AlertChat(LocalizeString("|c3399FF<<1>>|r applied |cCC0000<<t:2>>|r", sourceName, GetAbilityName(abilityId)))
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.fane.megabat) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0xCC0044FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.fane.spawn and hitValue == 1 and CombatAlerts.zoneId == CombatAlertsData.fane.zone and LCA.isTank) then
		if (string.find(string.lower(GetUnitName("boss1")), "grundwulf")) then
			local current, _, effectiveMax = GetUnitPower("boss1", COMBAT_MECHANIC_FLAGS_HEALTH)
			local health = current / effectiveMax
			if (health < 0.8) then
				CombatAlerts.fane.direMawId = targetUnitId
				CombatAlerts.fane.spawns[targetUnitId] = health
				local spawnDireMaw = function( )
					if (CombatAlerts.fane.spawns[CombatAlerts.fane.direMawId]) then
						CombatAlerts.Debug(string.format("Hollowfang Dire-Maw spawned at %.1f%%", CombatAlerts.fane.spawns[CombatAlerts.fane.direMawId] * 100))
						CombatAlerts.fane.spawns[CombatAlerts.fane.direMawId] = nil
						CombatAlerts.Alert(CombatAlerts.incomingText, "Hollowfang Dire-Maw", 0x0099CCFF, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
					end
				end
				zo_callLater(spawnDireMaw, 50)
			end
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and CombatAlertsData.fane.spawnFilters[abilityId] and LCA.isTank) then
		CombatAlerts.fane.spawns[targetUnitId] = nil


	-- Lair of Maarselok -------------------------------------------------------

	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.maarselok.unrelenting4) then
		CombatAlerts.AlertCast(abilityId, nil, hitValue, { 0, 0, false, { 1, 0, 0.6, 0.8 } })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.maarselok.unrelenting5) then
		CombatAlerts.AlertCast(abilityId, nil, 3100, { 700, 0, false, { 0.3, 0.9, 1, 0.3 }, { 0, 0.5, 1, 0.6 } })
	elseif (abilityId == CombatAlertsData.maarselok.bonds) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.maarselok.wickedBonds = CombatAlertsData.maarselok.bondsMax
			CombatAlerts.MaarselokEnablePanel(true)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.maarselok.wickedBonds = 0
			CombatAlerts.maarselok.nextBondage = GetGameTimeMilliseconds() + 25000
		elseif (result == ACTION_RESULT_DAMAGE_SHIELDED) then
			if (not CombatAlerts.maarselok.wickedBonds) then
				CombatAlerts.maarselok.wickedBonds = CombatAlertsData.maarselok.bondsMax
			end
			CombatAlerts.maarselok.wickedBonds = CombatAlerts.maarselok.wickedBonds - hitValue
			if (CombatAlerts.maarselok.wickedBonds < 0) then
				CombatAlerts.maarselok.wickedBonds = 0
			end
			CombatAlerts.MaarselokEnablePanel(true)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.maarselok.seed) then
		CombatAlerts.maarselok.lastSeed = GetGameTimeMilliseconds()
		CombatAlerts.MaarselokEnablePanel(false)
		CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId), 0x00FF00FF, SOUNDS.OBJECTIVE_DISCOVERED, 3000)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == CombatAlertsData.maarselok.sweepingBreath) then
		CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId), 0xCC3300FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 3000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.maarselok.headbutt) then
		CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId), 0xFF0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (abilityId == CombatAlertsData.maarselok.blaze and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.AlertBorder(true)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.AlertBorder(false)
		end
	elseif (abilityId == CombatAlertsData.maarselok.talons and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.AlertBorder(true)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.AlertBorder(false)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.maarselok.shagrath and CombatAlerts.isVet) then
		CombatAlerts.maarselok.shagraths[targetUnitId] = true
	elseif (result == ACTION_RESULT_DIED and CombatAlerts.maarselok.shagraths[targetUnitId] and abilityId == CombatAlertsData.maarselok.shagrathSpit and CombatAlerts.isVet) then
		CombatAlerts.AlertChat("|cCC0000Failed:|r |H0:achievement:2581:0:0|h|h")


	-- Unhallowed Grave --------------------------------------------------------

	elseif (abilityId == CombatAlertsData.uhg.ruin and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.AlertBorder(true)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.AlertBorder(false)
		end
	elseif (result == ACTION_RESULT_BEGIN and CombatAlertsData.uhg.soulShatterIds[abilityId]) then
		CombatAlerts.Alert(LCA.GetAbilityName(CombatAlertsData.uhg.soulShatter), "Shelter Behind Pillars", 0x3399CCFF, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.uhg.uppercut and targetType == COMBAT_UNIT_TYPE_PLAYER and string.find(string.lower(GetUnitName("boss1")), "kjalnar")) then
		CombatAlerts.AlertCast(abilityId, sourceName, hitValue, { -2, 2 })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.uhg.abyss) then
		CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId), 0x00CC00FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.uhg.confinement) then
		CombatAlerts.Alert(CombatAlerts.incomingText, LCA.GetAbilityName(abilityId), 0x3399CCFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.uhg.brimstone) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC3300FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		elseif (CombatAlerts.DistanceCheck(targetUnitId, 8)) then
			CombatAlerts.Alert(LCA.GetAbilityName(abilityId), CombatAlerts.units[targetUnitId].name, 0xCC3300FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.uhg.breath) then
		CombatAlerts.AlertCast(abilityId, nil, hitValue, { -2, 0, false, { 0.6, 0.8, 1, 0.4 }, { 0.6, 0.8, 1, 0.8 } })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.icereach.shockHeavy and targetType == COMBAT_UNIT_TYPE_PLAYER and hitValue > 1000) then
		CombatAlerts.AlertCast(abilityId, sourceName, hitValue, { -2, 2 })


	-- Stonethorn --------------------------------------------------------------

	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.stonethorn.annihilate) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.stonethorn.scatter and hitValue < 3000) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.stonethorn.dive) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xFFCC00FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_BEGIN and CombatAlertsData.stonethorn.charges[abilityId]) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC3399FF, LCA.isTank and SOUNDS.CHAMPION_POINTS_COMMITTED or SOUNDS.DUEL_START, 1500)
		elseif (CombatAlerts.DistanceCheck(targetUnitId, CombatAlertsData.stonethorn.charges[abilityId])) then
			CombatAlerts.Alert(LCA.GetAbilityName(abilityId), CombatAlerts.units[targetUnitId].name, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
		end
	elseif (abilityId == CombatAlertsData.stonethorn.chaurus and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CombatAlerts.AlertBorder(true)
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CombatAlerts.AlertBorder(false)
		end
	elseif (CombatAlertsData.damageEvents[result] and abilityId == CombatAlertsData.stonethorn.wwtaunt and sourceType == COMBAT_UNIT_TYPE_PLAYER) then
		CombatAlerts.stonethorn.huskId = targetUnitId
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.stonethorn.cannon and targetUnitId == CombatAlerts.stonethorn.huskId) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0x00CC00FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.stonethorn.mark) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.stonethorn.discharge) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.stonethorn.bottled) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0x3399CCFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)


	-- Ascending Tide ----------------------------------------------------------

	elseif (CombatAlertsData.damageEvents[result] and targetType == COMBAT_UNIT_TYPE_PLAYER and CombatAlertsData.at.standingInAoe[abilityId]) then
		local params = CombatAlertsData.at.standingInAoe[abilityId]
		if (not (params[2] and LCA.isTank)) then
			CombatAlerts.AlertBorder(true, params[1])
		end
	elseif (result == ACTION_RESULT_BEGIN and CombatAlertsData.at.fear[abilityId]) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC0000FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.at.bomb1) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		CombatAlerts.tide.bombs = { }
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == CombatAlertsData.at.bomb2) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		table.insert(CombatAlerts.tide.bombs, targetName)
		if (#CombatAlerts.tide.bombs > 1) then
			CombatAlerts.Alert(LCA.GetAbilityName(abilityId), table.concat(CombatAlerts.tide.bombs, " / "), 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
			CombatAlerts.tide.bombs = { }
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.at.kindred) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF3366FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.at.pursue) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.at.spout and hitValue < 1000) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.at.daggerstorm) then
		CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF6600FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and CombatAlertsData.at.links[abilityId]) then
		if (CombatAlerts.units[targetUnitId]) then
			targetName = CombatAlerts.units[targetUnitId].name
		end
		if (CombatAlertsData.at.links[abilityId] == 1) then
			CombatAlerts.tide.link1 = targetName
		else
			CombatAlerts.Alert(LCA.GetAbilityName(abilityId), string.format("%s / %s", CombatAlerts.tide.link1, targetName), 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
			CombatAlerts.tide.link1 = ""
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == CombatAlertsData.at.current and hitValue < 1500) then
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CombatAlerts.Alert(nil, LCA.GetAbilityName(abilityId), 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		elseif (LCA.isHealer) then
			if (CombatAlerts.units[targetUnitId]) then
				targetName = CombatAlerts.units[targetUnitId].name
			end
			CombatAlerts.Alert(LCA.GetAbilityName(abilityId), targetName, 0x66CCFFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED and CombatAlertsData.at.gryphons[abilityId]) then
		CombatAlerts.Alert(LCA.GetAbilityName(CombatAlertsData.at.gryphons.call), CombatAlertsData.at.gryphons[abilityId], 0xFF9900FF, SOUNDS.OBJECTIVE_DISCOVERED, 2000)
	end
end

function CombatAlerts.EffectChanged( eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType )
	CombatAlerts.IdentifyUnit(unitTag, unitName, unitId)



	-- Cloudrest ---------------------------------------------------------------

	if (abilityId == CombatAlertsData.cloudrest.preyed) then
		local unit = GetUnitDisplayName(unitTag)

		if (unit and not LCA.isDamage) then
			if (not CombatAlerts.panel.enabled) then
				CombatAlerts.cloudrest.preyed = { }
				CombatAlerts.TogglePanel(true, LCA.GetAbilityName(abilityId), false, true)
			end

			if (changeType ~= EFFECT_RESULT_FADED) then
				CombatAlerts.cloudrest.preyed[unit] = stackCount
				CombatAlerts.CloudrestPreyedUpdatePanel(true)
			else
				CombatAlerts.cloudrest.preyed[unit] = nil
				CombatAlerts.CloudrestPreyedUpdatePanel()
			end
		end
	elseif (abilityId == CombatAlertsData.general.taunt and unitTag == "boss1" and string.find(string.lower(GetUnitName(unitTag)), CombatAlertsData.cloudrest.zmaja)) then
		if (changeType == EFFECT_RESULT_GAINED) then
			CombatAlerts.cloudrest.zmajaTaunt = GetGameTimeMilliseconds() + GetAbilityDuration(abilityId)
		elseif (changeType == EFFECT_RESULT_FADED) then
			CombatAlerts.cloudrest.zmajaTaunt = 0
		end


	-- Sunspire -------------------------------------------------------

	elseif (abilityId == CombatAlertsData.sunspire.tombArming and changeType == EFFECT_RESULT_GAINED) then
		CombatAlerts.sunspire.tombState = 2
	elseif (abilityId == CombatAlertsData.sunspire.tombArmed) then
		if (changeType == EFFECT_RESULT_GAINED) then
			CombatAlerts.sunspire.tombActive = CombatAlerts.sunspire.tombActive + 1
			CombatAlerts.sunspire.tombState = 3
			CombatAlerts.panel.label:SetText(CombatAlerts.sunspire.tombText)

			local deadline = GetGameTimeMilliseconds() + GetAbilityDuration(abilityId)
			if (deadline - CombatAlerts.sunspire.tombDeadline > 1000) then
				CombatAlerts.sunspire.tombDeadline = deadline
			end
		elseif (changeType == EFFECT_RESULT_FADED) then
			CombatAlerts.sunspire.tombActive = CombatAlerts.sunspire.tombActive - 1
			if (CombatAlerts.sunspire.tombActive == 0) then
				CombatAlerts.sunspire.tombState = 4
				CombatAlerts.panel.label:SetText(CombatAlerts.sunspire.tombTextNext)
			end
		end
	end
end

function CombatAlerts.BossesChanged( eventCode )
	local bossName = string.lower(GetUnitName("boss1"))

	if (CombatAlerts.currentBoss ~= bossName) then
		CombatAlerts.currentBoss = bossName
	else
		return
	end

	if (CombatAlertsData.fanglair.names[bossName]) then
		CombatAlerts.FangLairToggleTimer(true)
	else
		CombatAlerts.FangLairToggleTimer(false)
	end
end

do
	local name = CombatAlerts.name .. "ThornMemoryGame"
	local mg, mgd

	local IsImbued = function( unitId )
		for i = 1, 4 do
			if (unitId == mg.ids[i]) then
				return(true)
			end
		end
		return(false)
	end

	local MemoryGameEvent = function( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
		if (result == ACTION_RESULT_EFFECT_GAINED and abilityId == mgd.imbued) then
			mg.ids[mg.idx] = targetUnitId
			mg.idx = (mg.idx % 4) + 1
		elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == mgd.gutted and IsImbued(targetUnitId) and GetGameTimeMilliseconds() > mg.disembowel) then
			CombatAlerts.AlertChat("[Memory Game] Imbued target gutted by |c00FF00player|r")
		elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == mgd.disembowel and IsImbued(targetUnitId)) then
			mg.disembowel = GetGameTimeMilliseconds() + 2500
			CombatAlerts.AlertChat("[Memory Game] Imbued target gutted by |cFF0000boss|r")
		end
	end

	function CombatAlerts.ThornMemoryGame( enable )
		mg = CombatAlerts.stonethorn.memoryGame
		mgd = CombatAlertsData.stonethorn.memoryGame
		if (enable and not mg.enabled) then
			mg.enabled = true
			EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, MemoryGameEvent)
			EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
		elseif (not enable and mg.enabled) then
			mg.enabled = false
			EVENT_MANAGER:UnregisterForEvent(name, EVENT_COMBAT_EVENT)
		end
	end
end

function CombatAlerts.Poll( )
	if (CombatAlerts.zoneId == CombatAlertsData.fanglair.zone) then
		local time = CombatAlerts.fanglair.nextGrip - GetGameTimeMilliseconds()

		CombatAlerts.panel.data:SetText(CombatAlerts.FormatTime(time))

		if (time >= 5500 or not IsUnitInCombat("player")) then
			CombatAlerts.panel.data:SetColor(1, 1, 1, 1)
		elseif (time <= 0) then
			CombatAlerts.panel.data:SetColor(1, 0, 0, 1)
		else
			CombatAlerts.panel.data:SetColor(1, 0.5, 0, 1)
		end
	elseif (CombatAlerts.zoneId == CombatAlertsData.frostvault.zone) then
		if (CombatAlerts.frostvault.skeevMode) then
			CombatAlerts.panel.data:SetText(CombatAlerts.FormatTime(GetGameTimeMilliseconds() - CombatAlerts.frostvault.skeevCharged))
			return
		end

		local time = CombatAlerts.frostvault.effluviumEnd - GetGameTimeMilliseconds()

		if (time > 0) then
			CombatAlerts.panel.data:SetColor(1, 1, 1, 1)
		else
			time = time * -1
			if (time < 11500) then
				CombatAlerts.panel.data:SetColor(0, 1, 0, 1)
			else
				CombatAlerts.panel.data:SetColor(1, 0.5, 0, 1)
			end
		end

		CombatAlerts.panel.data:SetText(CombatAlerts.FormatTime(time, true))
	elseif (CombatAlerts.zoneId == CombatAlertsData.cloudrest.zone) then
		local currentTime = GetGameTimeMilliseconds()
		local time = currentTime - CombatAlerts.cloudrest.banefulPrev

		local timeText = CombatAlerts.FormatTime(time, true)
		if (time >= 21500 and currentTime <= CombatAlerts.cloudrest.flare.stop) then
			timeText = string.format("%s (%s)", timeText, CombatAlertsData.cloudrest.flareName)
		end

		CombatAlerts.panel.rows[1].data:SetText(timeText)

		if (CombatAlerts.cloudrest.executeStart ~= CombatAlerts.cloudrest.banefulPrev) then
			if (time < CombatAlerts.cloudrest.banefulCast) then
				CombatAlerts.panel.rows[1].data:SetText(CombatAlerts.incomingText)
				CombatAlerts.panel.SetRowColor(1, 1, 0, 0.5, 1)
			elseif (time < 17500) then
				CombatAlerts.panel.SetRowColor(1, 1, 1, 1, 1)
			elseif (time < 19500) then
				CombatAlerts.panel.SetRowColor(1, 0.25, 0.75, 1, 1)
			else
				CombatAlerts.panel.SetRowColor(1, 1, 0, 1, 1)
			end
		else
			if (time < 6500) then
				CombatAlerts.panel.SetRowColor(1, 1, 1, 1, 1)
			elseif (time < 8500) then
				CombatAlerts.panel.SetRowColor(1, 0.25, 0.75, 1, 1)
			else
				CombatAlerts.panel.SetRowColor(1, 1, 0, 1, 1)
			end
		end

		if (currentTime <= CombatAlerts.cloudrest.flare.stop and CombatAlerts.units[CombatAlerts.cloudrest.flare.units[1]] and CombatAlerts.units[CombatAlerts.cloudrest.flare.units[2]]) then
			local dist = CombatAlerts.GetDistance(CombatAlerts.units[CombatAlerts.cloudrest.flare.units[1]].tag, CombatAlerts.units[CombatAlerts.cloudrest.flare.units[2]].tag)

			CombatAlerts.panel.rows[2].data:SetText(string.format("%.1fm%s", dist, CombatAlerts.cloudrest.flare.switcher))

			if (dist < 6) then
				CombatAlerts.panel.SetRowColor(2, 1, 0, 0, 1)
			elseif (dist < 7) then
				CombatAlerts.panel.SetRowColor(2, 1, 0.5, 0, 1)
			elseif (dist < 7.5) then
				CombatAlerts.panel.SetRowColor(2, 1, 1, 0, 1)
			else
				CombatAlerts.panel.SetRowColor(2, 0, 1, 0, 1)
			end
		else
			CombatAlerts.panel.SetRowColor(2, 1, 1, 1, 0)
		end
	elseif (CombatAlerts.zoneId == CombatAlertsData.sunspire.zone) then
		local currentTime = GetGameTimeMilliseconds()
		local time

		if (CombatAlerts.sunspire.bottomActive) then
			if (CombatAlerts.sunspire.translation == 1) then
				CombatAlerts.panel.rows[1].data:SetText("Do not interrupt")
				CombatAlerts.panel.rows[1].data:SetColor(0, 0.75, 1, 1)
			elseif (CombatAlerts.sunspire.translation == 2) then
				time = CombatAlerts.sunspire.translationDeadline - currentTime
				CombatAlerts.panel.rows[1].data:SetText(CombatAlerts.FormatTime(time, false, true) .. " to interrupt")
				if (time < 2000) then
					CombatAlerts.panel.rows[1].data:SetColor(1, 0, 0, 1)
				else
					CombatAlerts.panel.rows[1].data:SetColor(1, 1, 0, 1)
				end
			elseif (CombatAlerts.sunspire.translation == 3) then
				time = CombatAlerts.sunspire.translationNext - currentTime
				CombatAlerts.panel.rows[1].data:SetText(CombatAlerts.FormatTime(time, true) .. " to pins")
				if (time < 3500) then
					CombatAlerts.panel.rows[1].data:SetColor(1, 0.5, 0, 1)
				else
					CombatAlerts.panel.rows[1].data:SetColor(1, 1, 1, 1)
				end
			end
		else
			if (CombatAlerts.sunspire.tombState == 0 or (CombatAlerts.sunspire.tombState == 4 and not CombatAlerts.sunspire.lokiGrounded)) then
				CombatAlerts.panel.SetRowColor(1, 1, 1, 1, 0)
			elseif (CombatAlerts.sunspire.tombState == 1) then
				CombatAlerts.panel.rows[1].data:SetText("Spawning")
				CombatAlerts.panel.SetRowColor(1, 1, 0, 1, 1)
			elseif (CombatAlerts.sunspire.tombState == 2) then
				CombatAlerts.panel.rows[1].data:SetText("Activating")
				CombatAlerts.panel.SetRowColor(1, 1, 0, 1, 1)
			elseif (CombatAlerts.sunspire.tombState == 3) then
				time = CombatAlerts.sunspire.tombDeadline - currentTime
				CombatAlerts.panel.rows[1].data:SetText(CombatAlerts.FormatTime(time, false, true) .. " to shatter")
				if (time < 3000) then
					CombatAlerts.panel.SetRowColor(1, 1, 0, 0, 1)
				else
					CombatAlerts.panel.SetRowColor(1, 0.25, 0.75, 1, 1)
				end
			elseif (CombatAlerts.sunspire.tombState == 4) then
				time = CombatAlerts.sunspire.tombNext - currentTime
				CombatAlerts.panel.rows[1].data:SetText(CombatAlerts.FormatTime(time, true) .. " to spawn")
				CombatAlerts.panel.SetRowColor(1, 0, 0.8, 0, 1)
			end

			if (not CombatAlerts.sunspire.lokiGrounded or CombatAlerts.sunspire.atroNext == 0) then
				CombatAlerts.panel.SetRowColor(2, 1, 1, 1, 0)
			else
				time = CombatAlerts.sunspire.atroNext - currentTime
				CombatAlerts.panel.rows[2].data:SetText(CombatAlerts.FormatTime(time))

				if (time < 10500) then
					CombatAlerts.panel.SetRowColor(2, 1, 0.5, 0, 1)
				else
					CombatAlerts.panel.SetRowColor(2, 1, 1, 1, 1)
				end
			end

		end
	elseif (CombatAlerts.zoneId == CombatAlertsData.fane.zone) then
		local currentTime = GetGameTimeMilliseconds()
		local time

		if (CombatAlerts.fane.geyserActive) then
			time = CombatAlerts.fane.nextGeyserEnd - currentTime
			CombatAlerts.panel.SetRowColor(1, 1, 0, 0, 1)
		else
			time = currentTime - CombatAlerts.fane.lastGeyserEnd
			CombatAlerts.panel.SetRowColor(1, 0, 1, 0, 1)
		end

		CombatAlerts.panel.rows[1].data:SetText(CombatAlerts.FormatTime(time, true))

		time = currentTime - CombatAlerts.fane.lastGeyserPlug

		if (time > CombatAlerts.fane.geyserDuration or not CombatAlerts.fane.geyserActive) then
			CombatAlerts.panel.SetRowColor(2, 1, 1, 1, 0)
		else
			if (time < 3000) then
				CombatAlerts.panel.SetRowColor(2, 0, 1, 1, 1)
			else
				CombatAlerts.panel.SetRowColor(2, 1, 1, 0, 1)
			end

			CombatAlerts.panel.rows[2].data:SetText(CombatAlerts.FormatTime(time, true, true))
		end
	elseif (CombatAlerts.zoneId == CombatAlertsData.maarselok.zone) then
		local currentTime = GetGameTimeMilliseconds()

		if (not CombatAlerts.maarselok.wickedBonds) then
			CombatAlerts.panel.SetRowColor(1, 1, 1, 1, 0)
		elseif (CombatAlerts.maarselok.wickedBonds == 0 and CombatAlerts.maarselok.nextBondage) then
			local time = CombatAlerts.maarselok.nextBondage - currentTime
			CombatAlerts.panel.rows[1].data:SetText("Free for " .. CombatAlerts.FormatTime(time, true))
			CombatAlerts.panel.SetRowColor(1, 0, 1, 0, 1)
		else
			CombatAlerts.panel.rows[1].data:SetText(string.format("%dk", (CombatAlerts.maarselok.wickedBonds + 500) / 1000))
			CombatAlerts.panel.SetRowColor(1, 1, 1, 1, 1)
		end

		if (CombatAlerts.maarselok.lastSeed == 0 or not CombatAlerts.maarselok.wickedBonds) then
			CombatAlerts.panel.SetRowColor(2, 1, 1, 1, 0)
		else
			local time = currentTime - CombatAlerts.maarselok.lastSeed
			CombatAlerts.panel.rows[2].data:SetText(CombatAlerts.FormatTime(time, true))
			if (time < 64500) then
				CombatAlerts.panel.SetRowColor(2, 1, 1, 1, 1)
			else
				CombatAlerts.panel.SetRowColor(2, 1, 1, 0, 1)
			end
		end
	end
end

function CombatAlerts.ToggleTestPanel( enable )
	if (CombatAlerts.panel.enabled) then return end

	if (enable) then
		CombatAlerts.panel.label:SetText(CombatAlerts.title)
		CombatAlerts.panel.data:SetText(CombatAlerts.version)
		CombatAlerts.panel.row:SetHidden(false)

		zo_callLater(function() CombatAlerts.ToggleTestPanel(false) end, 20000)
	end

	CombatAlerts.ToggleUIFragment(CombatAlerts.panel.fragment, enable)
end

function CombatAlerts.TogglePanel( enable, label, usePolling, autoHide, pollingFunction )
	CombatAlerts.panel.autoHide = autoHide

	if (enable and not CombatAlerts.panel.enabled) then
		CombatAlerts.panel.enabled = true

		if (type(label) == "table") then
			for i = 1, #label do
				CombatAlerts.panel.rows[i].label:SetText(label[i])
				CombatAlerts.panel.rows[i].data:SetText("")
				CombatAlerts.panel.rows[i]:SetHidden(false)
			end
		else
			CombatAlerts.panel.label:SetText(label)
			CombatAlerts.panel.data:SetText("")
			CombatAlerts.panel.row:SetHidden(false)
		end

		if (usePolling) then
			if (type(pollingFunction) ~= "function") then
				pollingFunction = CombatAlerts.Poll
			end
			EVENT_MANAGER:RegisterForUpdate(CombatAlerts.name, CombatAlerts.pollingInterval, pollingFunction)
			pollingFunction()
		end

		CombatAlerts.ToggleUIFragment(CombatAlerts.panel.fragment, true)
	elseif (not enable and CombatAlerts.panel.enabled) then
		CombatAlerts.panel.enabled = false
		CombatAlerts.panel.tag = nil

		if (usePolling) then
			EVENT_MANAGER:UnregisterForUpdate(CombatAlerts.name)
		end

		for i = 1, CombatAlerts.panelRows do
			CombatAlerts.panel.SetRowColor(i, 1, 1, 1, 1)
			CombatAlerts.panel.rows[i]:SetHidden(true)
		end

		CombatAlerts.ToggleUIFragment(CombatAlerts.panel.fragment, false)
	end
end

function CombatAlerts.CloudrestPreyedUpdatePanel( )
	local units = { }
	local status = ""

	for unit in pairs(CombatAlerts.cloudrest.preyed) do table.insert(units, unit) end
	table.sort(units)
	for i, unit in ipairs(units) do
		local color = (CombatAlerts.cloudrest.preyed[unit] > 6) and "FF9900" or "FFFFFF"
		status = status .. string.format("|c%s%d – %s|r\n", color, CombatAlerts.cloudrest.preyed[unit], unit)
	end

	CombatAlerts.panel.data:SetText(status)
end

function CombatAlerts.FangLairToggleTimer( enable )
	CombatAlerts.fanglair.nextGrip = 0
	CombatAlerts.ToggleContinuousListen(enable)
	CombatAlerts.TogglePanel(enable, LCA.GetAbilityName(CombatAlertsData.fanglair.grip), true)
end

function CombatAlerts.FangLairResetTimer( interval )
	local nextGrip = GetGameTimeMilliseconds() + interval
	if (CombatAlerts.fanglair.nextGrip < nextGrip) then
		CombatAlerts.fanglair.nextGrip = nextGrip
	end
end

function CombatAlerts.MaarselokEnablePanel( resetSeed )
	if (not CombatAlerts.panel.enabled) then
		if (resetSeed) then CombatAlerts.maarselok.lastSeed = 0 end
		CombatAlerts.TogglePanel(true, { LCA.GetAbilityName(CombatAlertsData.maarselok.bonds), LCA.GetAbilityName(CombatAlertsData.maarselok.seed) }, true, true)
	end
end

function CombatAlerts.ScalecallerBreathEvent( eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId )
	if (result == ACTION_RESULT_BEGIN and CombatAlertsData.scalecaller.blastIds[abilityId]) then
		CombatAlerts.scalecaller.blastAll = GetGameTimeMilliseconds()
	else
		CombatAlerts.Alert(LCA.GetAbilityName(CombatAlerts.scalecaller.blastId), CombatAlertsData.scalecaller.blastIds[CombatAlerts.scalecaller.blastId], 0x00CC00FF, SOUNDS.DUEL_START, 2000)
	end

	return(true)
end

CombatAlerts.ToggleUIFragment = LCA.ToggleUIFragment

function CombatAlerts.IdentifyUnit( unitTag, unitName, unitId )
	if (not CombatAlerts.units[unitId] and zo_strsub(unitTag, 1, 5) == "group") then
		CombatAlerts.units[unitId] = {
			tag = unitTag,
			name = GetUnitDisplayName(unitTag) or unitName,
		}
	elseif (not CombatAlerts.bosses[unitId] and zo_strsub(unitTag, 1, 4) == "boss") then
		CombatAlerts.bosses[unitId] = unitTag
	end
end

function CombatAlerts.FormatTime( ms, useShort, useCountdown )
	local format = LCA.TIME_FORMAT_LONG
	if (useShort) then format = LCA.TIME_FORMAT_SHORT end
	if (useCountdown) then format = LCA.TIME_FORMAT_COUNTDOWN end
	return LCA.FormatTime(ms, format)
end

CombatAlerts.GetDistance = LCA.GetDistance

function CombatAlerts.DistanceCheck( unitId, distance )
	if (unitId and CombatAlerts.units[unitId]) then
		local unitTag = CombatAlerts.units[unitId].tag
		if (IsUnitInGroupSupportRange(unitTag)) then
			local _, x1, _, z1 = GetUnitWorldPosition("player")
			local _, x2, _, z2 = GetUnitWorldPosition(unitTag)
			return(zo_sqrt((x1 - x2)^2 + (z1 - z2)^2) <= distance * 100)
		end
	end
	return(false)
end

function CombatAlerts.GetClosestGroupMember( )
	local player = GetUnitDisplayName("player")
	local resultDistance = -1
	local resultUnit = ""

	for i = 1, GetGroupSize() do
		local unitTag = GetGroupUnitTagByIndex(i)
		if (GetUnitDisplayName(unitTag) ~= player) then
			local distance = CombatAlerts.GetDistance("player", unitTag, false, true)
			if (distance >= 0 and (distance < resultDistance or resultDistance == -1)) then
				resultDistance = distance
				resultUnit = unitTag
			end
		end
	end

	return resultDistance, resultUnit
end

function CombatAlerts.CastAlertsStart( abilityIconId, caption, duration, durationMax, color, action )
	local currentTime = GetGameTimeMilliseconds()
	local id = CombatAlerts.castAlerts.nextId
	CombatAlerts.castAlerts.nextId = CombatAlerts.castAlerts.nextId + 1

	for i = 1, #CombatAlerts.castAlerts.bars do
		local bar = CombatAlerts.castAlerts.bars[i]

		if (not bar.id) then
			CombatAlerts.castAlerts.active[id] = i

			bar.id = id
			bar.delayed = durationMax and duration > durationMax
			bar.duration = (bar.delayed) and durationMax or duration
			bar.endTime = currentTime + duration

			if (action) then
	 			bar.action.time = action[1]
				bar.action.text = action[2]
				bar.action.r = action[3]
				bar.action.g = action[4]
				bar.action.b = action[5]
				bar.action.a = action[6]
				bar.action.sound = action[7]
			else
	 			bar.action.time = 0
	 		end

			if (not color) then color = { 1, 0, 0, 0.5 } end

			bar.ui.caption:SetText(caption)
			bar.ui.icon:SetTexture(GetAbilityIcon(abilityIconId))
			bar.ui.fill:SetCenterColor(color[1], color[2], color[3], color[4])
			bar.ui.fill:SetWidth(0)
			bar.ui.timer:SetText("")
			bar.ui.action:SetText("")

			if (bar.action.time > 0 and bar.action.time < bar.duration) then
				bar.ui.marker:SetAnchor(LEFT, bar.ui.fill, LEFT, CombatAlerts.castAlerts.fillWidth * (1 - bar.action.time / bar.duration), 0)
				bar.ui.marker:SetCenterColor(bar.action.r, bar.action.g, bar.action.b, bar.action.a)
				bar.ui.marker:SetHidden(false)
			else
				bar.ui.marker:SetHidden(true)
			end

			if (not bar.delayed) then
				bar.ui.control:SetAlpha(1)
			end
			CombatAlerts.CastAlertsCheck()
			CombatAlerts.CastAlertsUpdate()

			return(id)
		end
	end

	return(nil)
end

function CombatAlerts.CastAlertsStop( id )
	local index = id and CombatAlerts.castAlerts.active[id]
	if (index) then
		CombatAlerts.castAlerts.active[id] = nil
		CombatAlerts.castAlerts.bars[index].id = nil
		CombatAlerts.castAlerts.bars[index].ui.control:SetAlpha(0)
		CombatAlerts.CastAlertsCheck()
	end
end

function CombatAlerts.CastAlertsUpdate( )
	local currentTime = GetGameTimeMilliseconds()

	for i = 1, #CombatAlerts.castAlerts.bars do
		local bar = CombatAlerts.castAlerts.bars[i]

		if (bar.id) then
			local shouldUpdate = true
			local time = bar.endTime - currentTime

			if (time < -100) then
				CombatAlerts.CastAlertsStop(bar.id)
				shouldUpdate = false
			elseif (time < 0) then
				time = 0
			end

			if (bar.delayed) then
				if (time < bar.duration) then
					bar.delayed = false
					bar.ui.control:SetAlpha(1)
				else
					shouldUpdate = false
				end
			end

			if (shouldUpdate) then
				bar.ui.fill:SetWidth(CombatAlerts.castAlerts.fillWidth * (bar.duration - time) / bar.duration)
				bar.ui.timer:SetText(string.format("%.1fs", time / 1000))

				if (bar.action.time > 0 and time <= bar.action.time) then
					bar.action.time = 0
					bar.ui.marker:SetHidden(true)

					if (bar.action.text) then
						bar.ui.action:SetText(bar.action.text)
					end

					bar.ui.fill:SetCenterColor(bar.action.r, bar.action.g, bar.action.b, bar.action.a)

					if (bar.action.sound) then
						PlaySound(bar.action.sound)
					end
				end
			end
		end
	end
end

function CombatAlerts.CastAlertsCheck( )
	local count = 0

	for i = 1, #CombatAlerts.castAlerts.bars do
		if (CombatAlerts.castAlerts.bars[i].id) then
			count = count + 1
		end
	end

	if (count >= 1 and not CombatAlerts.castAlerts.polling) then
		CombatAlerts.castAlerts.polling = true
		EVENT_MANAGER:RegisterForUpdate(CombatAlerts.name .. "CastAlertsUpdate", CombatAlerts.castUpdateInterval, CombatAlerts.CastAlertsUpdate)
	elseif (count == 0 and CombatAlerts.castAlerts.polling) then
		CombatAlerts.castAlerts.polling = false
		EVENT_MANAGER:UnregisterForUpdate(CombatAlerts.name .. "CastAlertsUpdate")
	end
end

function CombatAlerts.InitializeUI( )
	CombatAlertsNotifications:ClearAnchors()
	CombatAlertsNotifications:SetAnchor(BOTTOM, GuiRoot, CENTER, 0, -100)
	CombatAlertsNotifications:SetHidden(false)

	CombatAlerts.banners = { }

	for i = 1, 2 do
		local control = CombatAlertsNotifications:GetNamedChild("Banner" .. i)
		local radial = control:GetNamedChild("Radial")
		table.insert(CombatAlerts.banners, {
			name = CombatAlerts.name .. "Banner" .. i,
			active = false,
			locked = false,
			control = control,
			minor = control:GetNamedChild("Minor"),
			major = control:GetNamedChild("Major"),
			radial = {
				control = radial,
				border = radial:GetNamedChild("Border"),
				icon = radial:GetNamedChild("Icon"),
				label = radial:GetNamedChild("Label"),
			},
		})
		control:SetAlpha(0)
	end

	for i = 1, 3 do
		local control = CombatAlertsNotifications:GetNamedChild("Cast" .. i)
		table.insert(CombatAlerts.castAlerts.bars, {
			id = nil,
			ui = {
				control = control,
				caption = control:GetNamedChild("Caption"),
				icon = control:GetNamedChild("Icon"),
				fill = control:GetNamedChild("Fill"),
				marker = control:GetNamedChild("Marker"),
				timer = control:GetNamedChild("Timer"),
				action = control:GetNamedChild("Action"),
			},
			delayed = false,
			duration = 0,
			endTime = 0,
			action = {
				time = 0,
				text = "",
				r = 0,
				g = 0,
				b = 0,
				a = 0,
				sound = nil,
			},
		})
		control:SetAlpha(0)
	end

	CombatAlerts.panel = {
		enabled = false,
		autoHide = false,
		rows = { },
		fragment = ZO_SimpleSceneFragment:New(CombatAlertsPanel),
		handler = LCA.MoveableControl:New(CombatAlertsPanel),

		SetRowColor = function( i, r, g, b, a )
			CombatAlerts.panel.rows[i].label:SetColor(r, g, b, a)
			CombatAlerts.panel.rows[i].data:SetColor(r, g, b, a)
		end,
	}

	local CA2 = CombatAlerts2
	CombatAlerts.panel.handler:UpdatePosition(CA2.sv.statusPanel or LCA.StatusPanel:GetDefaultPosition())
	CombatAlerts.panel.handler:RegisterCallback("CCA_LEGACY_PANEL", LCA.EVENT_CONTROL_MOVE_STOP, function( newPos )
		CA2.sv.statusPanel = newPos
	end)

	for i = 1, CombatAlerts.panelRows do
		CombatAlerts.panel.rows[i] = CombatAlertsPanel:GetNamedChild("Row" .. i)
		CombatAlerts.panel.rows[i].label = CombatAlerts.panel.rows[i]:GetNamedChild("Label")
		CombatAlerts.panel.rows[i].data = CombatAlerts.panel.rows[i]:GetNamedChild("Data")
	end

	-- Shortcuts for single-row usage
	CombatAlerts.panel.row = CombatAlerts.panel.rows[1]
	CombatAlerts.panel.label = CombatAlerts.panel.row.label
	CombatAlerts.panel.data = CombatAlerts.panel.row.data
end

function CombatAlerts.StartBanner( textMinor, textMajor, color, icon, show, sound, lock )
	local id = (CombatAlerts.banners[1].active and not CombatAlerts.banners[2].active) and 2 or 1
	if (CombatAlerts.banners[id].locked) then
		id = (id == 1) and 2 or 1
	end

	CombatAlerts.banners[id].active = true
	CombatAlerts.ModifyBanner(id, textMinor, textMajor, color)

	if (icon) then
		if (type(icon) == "number") then
			icon = GetAbilityIcon(icon)
		end
		CombatAlerts.banners[id].radial.border:StartFixedCooldown(0, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
		CombatAlerts.banners[id].radial.icon:SetTexture(icon)
		CombatAlerts.banners[id].radial.label:SetText("")
		CombatAlerts.banners[id].radial.control:SetHidden(false)
	else
		CombatAlerts.banners[id].radial.control:SetHidden(true)
	end

	if (show) then
		CombatAlerts.banners[id].control:SetAlpha(1)
	end

	if (sound) then
		PlaySound(sound)
	end

	if (lock == true) then
		CombatAlerts.banners[id].locked = true
	else
		CombatAlerts.banners[id].locked = false
	end

	return(id)
end

function CombatAlerts.ModifyBanner( id, textMinor, textMajor, color, radialPercent, radialText, radialColor, show )
	if (not textMinor or textMinor == "") then textMinor = " " end
	if (not textMajor or textMajor == "") then textMajor = " " end
	if (not color) then color = 0xFFFFFFFF end

	CombatAlerts.banners[id].minor:SetText(textMinor)
	CombatAlerts.banners[id].major:SetText(textMajor)
	CombatAlerts.banners[id].major:SetColor(UnpackRGBA(color))

	if (radialPercent) then
		CombatAlerts.banners[id].radial.border:StartFixedCooldown(radialPercent, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
	end

	if (radialText) then
		CombatAlerts.banners[id].radial.label:SetText(radialText)
	end

	if (radialColor) then
		CombatAlerts.banners[id].radial.border:SetFillColor(UnpackRGBA(radialColor))
		CombatAlerts.banners[id].radial.label:SetColor(UnpackRGBA(radialColor))
	end

	if (show == true) then
		CombatAlerts.banners[id].control:SetAlpha(1)
	elseif (show == false) then
		CombatAlerts.banners[id].control:SetAlpha(0)
	end
end

function CombatAlerts.DisableBanner( id )
	EVENT_MANAGER:UnregisterForUpdate(CombatAlerts.banners[id].name)
	CombatAlerts.banners[id].active = false
	CombatAlerts.banners[id].locked = false
	CombatAlerts.banners[id].radial.control:SetHidden(true)
	CombatAlerts.banners[id].control:SetAlpha(0)
end

function CombatAlerts.Alert( textMinor, textMajor, color, sound, duration )
	if (not duration) then duration = 2000 end

	local id = CombatAlerts.StartBanner(textMinor, textMajor, color, nil, true, sound)

	EVENT_MANAGER:UnregisterForUpdate(CombatAlerts.banners[id].name)
	EVENT_MANAGER:RegisterForUpdate(
		CombatAlerts.banners[id].name,
		duration,
		function( )
			CombatAlerts.DisableBanner(id)
		end
	)

	return(id)
end

function CombatAlerts.AlertBannerEx( textMinor, textMajor, color, icon, show, sound, callback )
	local id = CombatAlerts.StartBanner(textMinor, textMajor, color, icon, show, sound, true)

	EVENT_MANAGER:UnregisterForUpdate(CombatAlerts.banners[id].name)
	EVENT_MANAGER:RegisterForUpdate(CombatAlerts.banners[id].name, CombatAlerts.bannerUpdateInterval, callback)

	return(id)
end

function CombatAlerts.AlertCast( abilityId, sourceName, duration, options )
	if (not CombatAlerts.vars.castAlertsEnabled) then
		return(nil)
	end

	if (not options) then
		options = { 0, 0, false, nil, nil }
	end

	local caption, time, text, r, g, b, a, sound

	if (sourceName and sourceName ~= "") then
		caption = LocalizeString("<<t:1>> (<<2>>)", GetAbilityName(abilityId), sourceName)
	else
		caption = LocalizeString("<<t:1>>", GetAbilityName(abilityId))
	end

	if (options[1] == -1) then
		local _, maxRange = GetAbilityRange(abilityId)
		options[1] = (maxRange <= 700) and -2 or -3
	end

	if (options[1] > 0) then
		time = options[1]
	elseif (options[1] == -2) then
		time = CombatAlerts.dodgeDuration
	elseif (options[1] == -3) then
		time = CombatAlerts.dodgeDuration * CombatAlerts.vars.projectileTimingAdjustment
	else
		time = 0
	end

	text = nil
	sound = nil

	if (options[2] == 1 or (options[2] == 2 and not LCA.isTank)) then
		text = CombatAlerts.dodgeText
		if (CombatAlerts.vars.castAlertsSound) then
			sound = SOUNDS.DUEL_START
		end
	end

	local color = (options[4]) and options[4] or { 1, 0.7, 0, 0.5 }

	if (options[5]) then
		r = options[5][1]
		g = options[5][2]
		b = options[5][3]
		a = options[5][4]
	elseif (options[4]) then
		r = options[4][1]
		g = options[4][2]
		b = options[4][3]
		a = options[4][4]
	else
		r = 0.8
		g = 0
		b = 0
		a = 0.9
	end

	return CombatAlerts.CastAlertsStart(abilityId, caption, duration, CombatAlerts.vars.maxCastMS, color, { time, text, r, g, b, a, sound })
end

do
	local Border
	local function GetBorder( )
		if (not Border) then
			Border = LCA.ScreenBorder:New()
		end
		return Border
	end

	function CombatAlerts.ScreenBorderEnable( color, duration, borderIdOverride )
		return GetBorder():Enable(color, duration, borderIdOverride)
	end

	function CombatAlerts.ScreenBorderDisable( borderId )
		GetBorder():Disable(borderId)
	end

	-- Legacy compatibility
	function CombatAlerts.AlertBorder( enable, duration, color )
		local colors = {
			["green"] = 0x00AA0088,
			["blue"] = 0x22AAFF99,
			["violet"] = 0xAA00FF77,
		}

		if (type(color) ~= "string" or not colors[color]) then
			color = "green"
		end
		local id = "LegacyAlertBorder_" .. color

		if (enable) then
			GetBorder():Enable(colors[color], duration, id)
		else
			GetBorder():Disable(id)
		end
	end
end

function CombatAlerts.AlertSound( soundId, delayForNext, ... )
	PlaySound(SOUNDS[soundId])
	if (type(delayForNext) == "number") then
		local args = { ... }
		if (#args > 0) then
			zo_callLater(function() CombatAlerts.AlertSound(unpack(args)) end, delayForNext)
		end
	end
end

function CombatAlerts.AlertChat( message )
	CHAT_ROUTER:AddSystemMessage(os.date("[%H:%M:%S] ", GetTimeStamp()) .. message)
end

CombatAlerts.ConsolidatedCall = LCA.CoalescedDelayedCall

function CombatAlerts.Debug( message )
	if (CombatAlerts.vars.debugEnabled) then
		CHAT_ROUTER:AddSystemMessage(message)
		table.insert(CombatAlerts.vars.debugLog, string.format("[%d / %d / %s] %s", GetTimeStamp(), GetGameTimeMilliseconds(), LocalizeString("<<C:1>>", GetZoneNameByIndex(GetUnitZoneIndex("player"))), message))
	end
end

--EVENT_MANAGER:RegisterForEvent(CombatAlerts.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
