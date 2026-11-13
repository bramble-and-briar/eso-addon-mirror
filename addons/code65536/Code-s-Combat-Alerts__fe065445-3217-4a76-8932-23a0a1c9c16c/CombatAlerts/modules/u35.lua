local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U35"
Module.NAME = CA2.GenerateModuleName(35, 1360, 1361)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1360, -- Earthen Root Enclave
	1361, -- Graven Deep
}

Module.STRINGS = {
	-- Custom (Alerts)
	orbs = { default = "Sea Orbs" },
	turn = { default = "Turn Away!" },
}

Module.DATA = {
	-- Graven Deep
	fear = 172543,
	fearDamage = 174228,
	barrage = 176182,
	soulSplit = {
		[173970] = 1,
		[173972] = 2,
		hmHealth = 10000000,
	},
	orbs = {
		[172618] = { ACTION_RESULT_EFFECT_GAINED, 15500 }, -- Damage Shield
		[172650] = { ACTION_RESULT_EFFECT_GAINED,  5500 }, -- Slow FX
		[178599] = { ACTION_RESULT_EFFECT_GAINED, 99999 }, -- Impact FX
		[178612] = { ACTION_RESULT_EFFECT_FADED , 12500 }, -- Climbing FX
		afterlife = 172552,
	},

	-- Earthen Root Enclave
	banners = {
		[170362] = 0x66CCFFFF, -- Shockwave Bash
		[172484] = 0xFFCC33FF, -- Earthquake Stomp
		[170823] = 0x66CCFFFF, -- Lightning Pillar (Human)
		[179139] = 0x66CCFFFF, -- Lightning Pillar (Bear)
	},
	slashStart = 178969,
	slashDamage = 174455,
	sunbolt = 171580,
	crumble = 172402,
	rubble = 175097,
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		-- Graven Deep
		[112995] = { -2, 0 }, -- Hammer
		[168375] = { -2, 0 }, -- Lacerate
		[171986] = { -2, 0 }, -- Bristlebombard
		[175763] = { -2, 2 }, -- Feint Stab
		[171112] = { -2, 2 }, -- Clash of Bones
		[178900] = { -2, 2 }, -- Clash of Bones
		[175964] = { -2, 2 }, -- Soul Bash
		[172217] = { -2, 2 }, -- Necrotic Wave

		-- Earthen Root Enclave
		[171918] = { -2, 2 }, -- Crackdown
		[172130] = { -2, 2 }, -- Knuckle Duster
		[172147] = { -2, 0, false, { 1, 0, 0.6, 0.8 } }, -- Chin Shatter
		[172759] = { -2, 2 }, -- Ruin
		[172790] = { -2, 2 }, -- Mince
		[172983] = { -2, 2 }, -- Hammerfall
	}

	self.AOE_ALERTS = {
		[171400] = { 1200, false }, -- Corrupted Pulp
		[172166] = { 400, false }, -- Necrotic Wake
	}

	self.SMALL_GROUP_SIZE = true
	self.PURGEABLE_EFFECTS = {
		[173406] = 0, -- Crippling Grasp
		[179212] = 0, -- Crippling Grasp
	}

	self.vars = {
		soul1 = "",
		orbIds = { },
		orbTimes = { },
		orbCooldown = 0,
		rubbleHit = 0,
	}
	Vars = self.vars

	self.ClearOrbs = function( )
		ZO_ClearTable(Vars.orbIds)
		ZO_ClearTable(Vars.orbTimes)
	end

	self.StatusPoll_Orbs = function( )
		local currentTime = GetGameTimeMilliseconds()
		local lines = self:GetScratch()
		for i, id in ipairs(Vars.orbIds) do
			local remaining = Vars.orbTimes[id] - currentTime
			local ratio = zo_clamp(remaining / 12500, 0, 1)
			table.insert(lines, string.format(
				"|c%06X#%d: %s|r",
				LCA.PackRGB(LCA.HSLToRGB(ratio / 3, 1, 0.5)),
				i,
				(remaining < 20000) and LCA.FormatTime(remaining, LCA.TIME_FORMAT_COUNTDOWN) or "OK"
			))
		end
		CA2.StatusSetCellText(1, 2, table.concat(lines, "\n"))
	end
end

function Module:PostStopListening( )
	CA2.StatusDisable()
	if (Vars.callLaterId) then
		zo_removeCallLater(Vars.callLaterId)
		Vars.callLaterId = nil
	end
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- Graven Deep
	if (result == ACTION_RESULT_BEGIN and abilityId == DATA.fear) then
		local name = LCA.GetAbilityName(abilityId)
		CA1.Alert(nil, name, 0xFF3366FF, SOUNDS.DUEL_START, 2000)
		CA1.CastAlertsStart(DATA.fearDamage, name, hitValue, nil, nil, { hitValue, self:GetString("turn"), 1, 0.2, 0.4, 0.5, nil })
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.barrage) then
		local id = CA1.AlertCast(abilityId, nil, hitValue, { -3, 0, false, { 0.7, 0.3, 1, 0.3 }, { 0.7, 0.3, 1, 0.7 } })
		if (LCA.IsUnitIdValid(targetUnitId)) then
			self.castSources[targetUnitId] = id
		end
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and DATA.soulSplit[abilityId]) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		if (DATA.soulSplit[abilityId] == 1) then
			if (select(3, GetUnitPower("boss1", COMBAT_MECHANIC_FLAGS_HEALTH)) < DATA.soulSplit.hmHealth) then
				CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
			else
				Vars.soul1 = name
			end
		else
			CA1.Alert(LCA.GetAbilityName(abilityId), string.format("%s / %s", Vars.soul1, name), 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
			Vars.soul1 = ""
		end
	elseif (DATA.orbs[abilityId] and LCA.IsUnitIdValid(targetUnitId)) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime > Vars.orbCooldown) then
			CA2.StatusEnable({
				ownerId = "u35orbs",
				rowLabels = self:GetString("orbs"),
				pollingFunction = self.StatusPoll_Orbs,
				initFunction = self.ClearOrbs,
			})
			local params = DATA.orbs[abilityId]
			if (result == params[1]) then
				if (not Vars.orbTimes[targetUnitId]) then
					table.insert(Vars.orbIds, targetUnitId)
				end
				Vars.orbTimes[targetUnitId] = currentTime + params[2]
			end
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.orbs.afterlife) then
		self.ClearOrbs()
		Vars.orbCooldown = GetGameTimeMilliseconds() + 10000
	elseif (self.PURGEABLE_EFFECTS[abilityId] and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			CA2.ScreenBorderEnable(0xFFDD0066, nil, "u35purgeables")
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			CA2.ScreenBorderDisable("u35purgeables")
		end

	-- Earthen Root Enclave
	elseif (result == ACTION_RESULT_BEGIN and DATA.banners[abilityId]) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), DATA.banners[abilityId], SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.slashStart) then
		CA1.AlertCast(DATA.slashDamage, nil, hitValue, { -3, 2 })
	elseif (result == ACTION_RESULT_EFFECT_GAINED and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.sunbolt and hitValue > 1000) then
		local adjustedTime = hitValue - 500
		CA1.AlertCast(abilityId, nil, adjustedTime, { adjustedTime, 0, false, { 0, 0.8, 0, 0.3 }, { 0, 0.8, 0, 0.6 } })
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.crumble) then
		local currentTime = GetGameTimeMilliseconds()
		if (Vars.rubbleHit < currentTime) then
			Vars.rubbleHit = currentTime + hitValue + 600
			Vars.callLaterId = zo_callLater(function( )
				CA1.AlertCast(DATA.rubble, nil, Vars.rubbleHit - GetGameTimeMilliseconds(), { -2, 2 })
			end, hitValue - 1100)
		end
	end
end

CA2.RegisterModule(Module)
