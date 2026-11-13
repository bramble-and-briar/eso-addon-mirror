local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U09"
Module.NAME = CA2.GenerateModuleName(9, 725)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	725, -- Maw of Lorkhaj
}

Module.STRINGS = {
	-- Custom
	moveAway = { default = "Move!" },
}

Module.DEFAULT_SETTINGS = {
	raidLeadMode = false,
}

local COLOR_L = 0xFFFF66FF
local COLOR_D = 0x0066EEFF

Module.DATA = {
	-- General
	shattered = 73250,
	eclipse = 73700,

	-- Boss 1
	curseProjectile = 57470,
	curseEffect = 57513,

	-- Boss 2
	boss2Start = 59444,
	aspects = {
		[59639] = { COLOR_D, false }, -- Shadow Aspect
		[59640] = { COLOR_L, false }, -- Lunar Aspect
		[59699] = { COLOR_D, true }, -- Conversion (L->D)
		[75460] = { COLOR_L, true }, -- Conversion (D->L)
	},
	boss2Colors = { COLOR_L, COLOR_D },

	-- Boss 3
	smash = 74670,
	weakened = 74672,
	threshing = 73741,
	darkness = 74035,
	unstable = 74488,
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		[73237] = { -3, 2, true }, -- Taking Aim
		[73249] = { -2, 1 }, -- Shattering Strike
		[75682] = { -2, 1 }, -- Deadly Claw
	}

	self.PURGEABLE_EFFECTS = {
		[73244] = 0, -- Ruthless Salvo Bleed
		[73807] = 0, -- Lunar Flare (Rage of S'Kinrai)
		[75738] = 0, -- Lunar Flare (S'kinrai)
		[78046] = 0, -- Ruthless Salvo Bleed
	}

	self.vars = {
		aspect = {
			id = 0,
			color = 0,
			name = "",
		},
		smashes = { },
	}
	Vars = self.vars

	self.StatusPoll_B2 = function( )
		local results = self:GetScratch()
		for i = 1, 2 do
			table.insert(results, string.format("|c%06X%d%%|r", LCA.RemoveAlpha(DATA.boss2Colors[i]), zo_floor(LCA.GetUnitHealthPercent("boss" .. i))))
		end
		CA2.StatusSetCellText(1, 2, table.concat(results, " / "))
		CA2.StatusModifyCell(2, 2, "text", Vars.aspect.name, "color", Vars.aspect.color)
	end

	self.StatusInit_B3 = function( )
		ZO_ClearTable(Vars.smashes)
	end

	self.StatusUpdate_B3 = function( )
		local units = self:GetScratch()
		for unitId, data in pairs(Vars.smashes) do
			local color = (data[1] > 1) and 0xFF9900 or 0xFFFFFF
			table.insert(units, { string.format("|c%06X%d – %s|r", color, data[1], select(2, LCA.IdentifyGroupUnitId(unitId, true))), data[2] })
		end
		table.sort(units, function(a, b) return a[2] > b[2] end)
		for i = 1, #units do
			units[i] = units[i][1]
		end
		CA2.StatusSetCellText(1, 2, table.concat(units, "\n"))
	end
end

function Module:PostStopListening( )
	CA2.StatusDisable()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- General
	if (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.shattered and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCCCCCCFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.eclipse and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)

	-- Boss 1
	elseif (result == ACTION_RESULT_EFFECT_GAINED and targetType == COMBAT_UNIT_TYPE_PLAYER and abilityId == DATA.curseProjectile and hitValue > 500) then
		CA1.AlertCast(DATA.curseEffect, nil, hitValue, { 0, 0, false, { 1, 0, 0.6, 0.8 } })
		local distance = CA2.FindClosestGroupMember()
		if (distance >= 0 and distance < 3.1) then
			LCA.PlaySounds("DUEL_START")
		end

	-- Boss 2
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.boss2Start) then
		CA2.StatusEnable({
			ownerId = "u9b2",
			rowLabels = { GetString("SI_ATTRIBUTES", ATTRIBUTE_HEALTH), GetString("SI_ENCHANTINGRUNECLASSIFICATION", ENCHANTING_RUNE_ASPECT) },
			pollingFunction = self.StatusPoll_B2,
		})
	elseif (DATA.aspects[abilityId] and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			local params = DATA.aspects[abilityId]
			Vars.aspect.id = abilityId
			Vars.aspect.color = params[1]
			Vars.aspect.name = LCA.GetAbilityName(abilityId)
			if (params[2]) then
				CA1.Alert(nil, Vars.aspect.name, Vars.aspect.color, SOUNDS.OBJECTIVE_DISCOVERED, hitValue)
			else
				LCA.PlaySounds("OBJECTIVE_DISCOVERED")
			end
		elseif (result == ACTION_RESULT_EFFECT_FADED and Vars.aspect.id == abilityId) then
			Vars.aspect.id = 0
			Vars.aspect.name = ""
		end

	-- Boss 3
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.threshing) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x00FFFFFF, nil, hitValue)
		LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 3, 250, "FRIEND_INVITE_RECEIVED", 4)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.darkness) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0x0066EEFF, SOUNDS.CHAMPION_POINTS_COMMITTED, hitValue)
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.unstable and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA1.CastAlertsStart(abilityId, LCA.GetAbilityName(abilityId), hitValue, nil, nil, { hitValue, self:GetString("moveAway"), 0, 0, 0.6, 0.5, nil })
		LCA.PlaySounds("DUEL_BOUNDARY_WARNING", 1, 200, "DUEL_BOUNDARY_WARNING", 2, 200, "DUEL_BOUNDARY_WARNING", 3, 200, "DUEL_BOUNDARY_WARNING", 4)
	elseif (abilityId == DATA.weakened and LCA.isVet and (LCA.DoesPlayerHaveTauntSlotted() or self:GetSetting("raidLeadMode"))) then
		CA2.StatusEnable({
			ownerId = "u9b3",
			rowLabels = LCA.GetAbilityName(DATA.smash),
			initFunction = self.StatusInit_B3,
		})
		if (result == ACTION_RESULT_EFFECT_GAINED) then
			Vars.smashes[targetUnitId] = { hitValue, GetGameTimeMilliseconds() }
			LCA.PlaySounds("CHAMPION_POINTS_COMMITTED", 2)
			self.StatusUpdate_B3()
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.smashes[targetUnitId] = nil
			self.StatusUpdate_B3()
		end
	end
end

function Module:GetSettingsControls( )
	return {
		--------------------
		{
			type = "checkbox",
			name = SI_CA_SETTINGS_MODULE_RAID_LEAD,
			tooltip = SI_CA_SETTINGS_MODULE_RAID_LEAD_TT,
			getFunc = function() return self:GetSetting("raidLeadMode") end,
			setFunc = function(enabled) self:SetSetting("raidLeadMode", enabled) end,
		},
	}
end

CA2.RegisterModule(Module)
