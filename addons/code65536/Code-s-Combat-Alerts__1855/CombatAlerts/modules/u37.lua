local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U37"
Module.NAME = CA2.GenerateModuleName(37, 1389, 1390)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1389, -- Bal Sunnar
	1390, -- Scrivener's Hall
}

Module.DATA = {
	banners = {
		[182334] = 0xFF6600FF, -- Rain of Fire
		[182355] = 0xFF0000FF, -- Ignite
		[182393] = 0xFFCC00FF, -- Immolation Trap
		[184441] = 0xCC33FFFF, -- Summon Entangler
		[182670] = 0x00CC00FF, -- Plague of Insects
		[177345] = 0x99FF99FF, -- Plague of Insects (Choking Pestilence)
	},

	-- Bal Sunnar
	manipulate = 182465,
	verge = {
		boss = 177646,
		shade = 177942,
		nameId = 177660,
	},
	darklight = {
		start = 177112,
		star = 177228,
		nameId = 177235,
	},
	summonNix = 177573,
	choking = 182495,

	-- Scrivener's Hall
	effusion = 182041,
	bash = 182014,
	slash = 181739,
	hellfire = 184602,
	parasite = 181185,
	parasiteSack = 181244,
	ironAtro = 183117,
	thirst = 182214,
	web = 179938,
	trapTrip = 183080,
	trapDamageId = 182393,
	meteor = {
		start = 185833,
		damage = 185834,
		timer = 3000,
	},
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		-- Bal Sunnar
		[146681] = { -2, 2 }, -- Crush
		[176988] = { -2, 2 }, -- Bisect (Boss)
		[176989] = { -2, 2 }, -- Bisect
		[179945] = { 0, 0, false, { 1, 0, 0.6, 0.8 } }, -- Plague Bomb
		[181469] = { -2, 2 }, -- Gore
		[182386] = { -2, 2 }, -- Interpose

		-- Scrivener's Hall
		[180921] = { -2, 2 }, -- Chaw
		[182139] = { -2, 2 }, -- Eviscerate
		[184768] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Mangle
		[184797] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Crypt Smash
		[184750] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Dual Strike
		[184810] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Crackdown
		[184816] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Chin Shatter
		[183089] = { -2, 2, offset = -1900 }, -- Brutal Bash
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[189528] = { 300, false }, -- Fold
		[189537] = { 300, false }, -- Fold
	}

	self.vars = {
		choking = 0,
		bash = 0,
		darklight = { },
		hellfire = { },
		meteor = {
			unitId = -1,
			alertId = -1,
		},
	}
	Vars = self.vars
end

function Module:PostStopListening( )
	CA2.StatusDisable()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	if (result == ACTION_RESULT_BEGIN and DATA.banners[abilityId]) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), DATA.banners[abilityId], nil, 1500)

	-- Bal Sunnar
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.manipulate and hitValue < 2000) then
		CA1.Alert(GetString(SI_LCA_INCOMING), LCA.GetAbilityName(abilityId), 0xFFCC33FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.verge.boss) then
		local sound = SOUNDS.DUEL_START
		local unitTag, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId)
		if (LCA.isTank) then sound = nil end
		if (targetType == COMBAT_UNIT_TYPE_PLAYER) then
			CA1.Alert(nil, zo_strformat(SI_LCA_TARGET_YOU, LCA.GetAbilityName(DATA.verge.nameId)), 0xCC3399FF, sound, 1000)
		elseif (unitTag and LCA.GetDistance("player", unitTag) <= 5) then
			CA1.Alert(nil, zo_strformat(SI_LCA_TARGET_OTHERS, LCA.GetAbilityName(DATA.verge.nameId)), 0xCC3399FF, sound, 1000)
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.verge.shade) then
		CA1.Alert(nil, zo_strformat(SI_LCA_TARGET_BOSS, LCA.GetAbilityName(DATA.verge.nameId)), 0xCC3399FF, nil, 1000)
		LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 1, 100, "DUEL_BOUNDARY_WARNING", 2)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.summonNix and LCA.DoesPlayerHaveTauntSlotted()) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF9900FF, nil, 2000)
	elseif (abilityId == DATA.choking) then
		Vars.choking = GetGameTimeMilliseconds() + hitValue
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			CA2.StatusEnable({
				ownerId = "u37cp",
				rowLabels = LCA.GetAbilityName(abilityId),
				pollingFunction = function() CA2.StatusSetCellText(1, 2, LCA.FormatTime(Vars.choking - GetGameTimeMilliseconds(), LCA.TIME_FORMAT_SHORT)) end,
			})
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.StatusDisable()
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.darklight.start and hitValue < 2000) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCCFF33FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
		ZO_ClearTable(Vars.darklight)
		CA2.StatusEnable({
			ownerId = "u37dl",
			rowLabels = LCA.GetAbilityName(DATA.darklight.nameId),
		})
	elseif (abilityId == DATA.darklight.star) then
		if ((result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_FADED) and LCA.IsUnitIdValid(targetUnitId)) then
			if (result == ACTION_RESULT_EFFECT_GAINED) then
				Vars.darklight[targetUnitId] = true
			elseif (result == ACTION_RESULT_EFFECT_FADED) then
				Vars.darklight[targetUnitId] = nil
			end
			local count = NonContiguousCount(Vars.darklight)
			CA2.StatusModifyCell(1, 2,
				"text", zo_strformat("<<1>> <<z:2>>", count, GetString(SI_LCA_ACTIVE)),
				"color", count == 0 and 0xFFFFFFFF or 0xFF0000FF
			)
		end

	-- Scrivener's Hall
	elseif (abilityId == DATA.hellfire) then
		if ((result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_FADED) and LCA.IsUnitIdValid(targetUnitId)) then
			CA2.StatusEnable({
				ownerId = "u37hf",
				rowLabels = LCA.GetAbilityName(abilityId),
				initFunction = function() ZO_ClearTable(Vars.hellfire) end,
			})
			if (result == ACTION_RESULT_EFFECT_GAINED) then
				Vars.hellfire[targetUnitId] = true
			elseif (result == ACTION_RESULT_EFFECT_FADED) then
				Vars.hellfire[targetUnitId] = nil
			end
			CA2.StatusSetCellText(1, 2, zo_strformat("<<1>> <<z:2>>", NonContiguousCount(Vars.hellfire), GetString(SI_LCA_ACTIVE)))
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.effusion and targetType == COMBAT_UNIT_TYPE_PLAYER and hitValue > 1500) then
		CA1.AlertCast(abilityId, sourceName, hitValue, { -3, 2 })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.bash and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		Vars.bash = GetGameTimeMilliseconds() + hitValue + 200
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.slash and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA1.AlertCast(abilityId, sourceName, hitValue, (GetGameTimeMilliseconds() > Vars.bash) and { -2, 2 } or { 0, 0, false, { 1, 0, 0.6, 0.8 } })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.parasite) then
		CA1.AlertCast(DATA.parasiteSack, nil, 1700, { 400, 0, false, { 0.8, 0, 0, 0.6 } })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.ironAtro and LCA.DoesPlayerHaveTauntSlotted()) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xFF9900FF, nil, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.thirst and LCA.DoesPlayerHaveTauntSlotted()) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC0000FF, nil, 1500)
		LCA.PlaySounds("FRIEND_INVITE_RECEIVED", 1, 100, "DUEL_BOUNDARY_WARNING", 2)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.web and hitValue < 2000) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_EFFECT_GAINED and abilityId == DATA.trapTrip) then
		local _, name = LCA.IdentifyGroupUnitId(targetUnitId, true)
		CA1.AlertChat(string.format("[%s] %s: %s", LCA.GetAbilityName(DATA.trapDamageId), LCA.GetAbilityName(abilityId), name))
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.meteor.start) then
		local id = CA1.CastAlertsStart(DATA.meteor.damage, LCA.GetAbilityName(DATA.meteor.damage), hitValue, DATA.meteor.timer, nil, { hitValue, GetString(SI_LCA_BLOCK), 1, 0.4, 0, 0.5, nil })
		if (LCA.IsUnitIdValid(targetUnitId)) then
			Vars.meteor = { unitId = targetUnitId, alertId = id }
		else
			Vars.meteor = { unitId = -1, alertId = -1 }
		end
	elseif (result == ACTION_RESULT_DIED and targetUnitId == Vars.meteor.unitId) then
		CA1.CastAlertsStop(Vars.meteor.alertId)
		Vars.meteor = { unitId = -1, alertId = -1 }
	end
end

CA2.RegisterModule(Module)
