local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U28"
Module.NAME = CA2.GenerateModuleName(28, 1227)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1227, -- Vateshran Hollows
}

Module.DATA = {
	brimstoneFortification = 143099,
	woundingPortal = 145347,
	remnants = {
		[146631] = true, -- Fortitude Remnant
		[146635] = true, -- Endurance Remnant
		[146637] = true, -- Mysticism Remnant
	},
	mephiticWave = 143176,
	empower = {
		[142928] = 0xFF6600FF,
		[142935] = 0x66CCFFFF,
	},
	channel = {
		[141335] = 0xFF00FFFF, -- Channeled Energy
		[142908] = 0xFF9900FF, -- Channeling
	},
	sentinelSpawn = 145722,
	watcherSpawn = 145733,
	flameSpout = {
		[142731] = 1,
		[142904] = -1,
	},
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_BOSSES = true

	self.TIMER_ALERTS_LEGACY = {
		[141622] = { -2, 2 }, -- Clobber
		[143094] = { -2, 0 }, -- Crushing Limbs
		[143113] = { -2, 0 }, -- Earthen Blast
		[143168] = { -3, 0 }, -- Fetid Globule
		[144949] = { -2, 0 }, -- Uppercut
	}

	self.vars = {
		traverse = { },
		traverseRowsUsed = 0,
		remnantPrev = 0,
		empower = { },
		channelPrev = 0,
		watcherCount = 0,
	}
	Vars = self.vars

	self.OutOfCombatEffect = function( _, changeType, _, _, _, beginTime, endTime, stackCount, _, _, _, _, _, _, _, abilityId )
		if (abilityId == DATA.brimstoneFortification or LCA.GetAbilityName(abilityId) == LCA.GetAbilityName(DATA.woundingPortal)) then
			if (changeType ~= EFFECT_RESULT_FADED and endTime - beginTime > 1) then
				Vars.traverse[abilityId] = zo_floor(endTime * 1000)
				CA2.StatusEnable({
					ownerId = "u28traverse",
					pollingFunction = self.StatusPoll_Traverse,
				})
			else
				Vars.traverse[abilityId] = nil
			end
		elseif (DATA.remnants[abilityId] and changeType ~= EFFECT_RESULT_FADED) then
			local currentTime = GetGameTimeMilliseconds()
			if (Vars.remnantPrev < currentTime - 500) then
				Vars.remnantPrev = currentTime
				CA2.ChatMessage(string.format("%s #%d", LCA.GetAbilityName(abilityId), stackCount))
			end
		end
	end

	self.StatusPoll_Traverse = function( )
		local currentTime = GetGameTimeMilliseconds()

		-- rowsUsed should in theory never exceed 1, but let's handle it properly anyway just in case
		local rowsUsed = 0

		for _, abilityId in ipairs(LCA.GetSortedKeys(Vars.traverse)) do
			local remaining = Vars.traverse[abilityId] - currentTime
			if (remaining > -500) then
				rowsUsed = rowsUsed + 1
				local ratio = zo_clamp(remaining / 10000, 0, 1)
				CA2.StatusSetCellText(rowsUsed, 1, LCA.GetAbilityName(abilityId))
				CA2.StatusModifyCell(rowsUsed, 2,
					"text", LCA.FormatTime(remaining, LCA.TIME_FORMAT_COUNTDOWN),
					"color", LCA.PackRGBA(LCA.HSLToRGB(ratio / 3, 1, 0.5, 1))
				)
			else
				Vars.traverse[abilityId] = nil
			end
		end

		if (rowsUsed == 0) then
			CA2.StatusDisable()
		elseif (Vars.traverseRowsUsed < rowsUsed) then
			Vars.traverseRowsUsed = rowsUsed
		else
			for i = rowsUsed + 1, Vars.traverseRowsUsed do
				CA2.StatusSetRowHidden(i, true)
			end
		end
	end

	self.StatusPoll_MultiBoss = function( )
		local results = self:GetScratch()
		for i = 1, 2 do
			table.insert(results, string.format("%d%%", zo_floor(LCA.GetUnitHealthPercent("boss" .. i))))
		end
		CA2.StatusSetCellText(1, 2, table.concat(results, " / "))
	end

	self.StatusPoll_Mino = function( )
		if (Vars.empower.stop) then
			CA2.StatusSetCellText(1, 2, LCA.FormatTime(Vars.empower.stop - GetGameTimeMilliseconds(), LCA.TIME_FORMAT_SHORT))
			CA2.StatusSetRowColor(1, Vars.empower.color)
		else
			CA2.StatusSetRowHidden(1, true)
		end
	end
end

function Module:OnBossesChanged( )
	if (GetUnitName("boss2") ~= "") then
		CA2.StatusEnable({
			ownerId = "u28multi",
			rowLabels = GetString("SI_ATTRIBUTES", ATTRIBUTE_HEALTH),
			pollingFunction = self.StatusPoll_MultiBoss,
		})
	end
end

function Module:PostLoad( )
	LCA.RegisterForFilteredEvent("CA_M_U28_EFFECTS", EVENT_EFFECT_CHANGED, self.OutOfCombatEffect, REGISTER_FILTER_UNIT_TAG, "player")
end

function Module:PreUnload( )
	EVENT_MANAGER:UnregisterForEvent("CA_M_U28_EFFECTS", EVENT_EFFECT_CHANGED)
end

function Module:PreStartListening( )
	Vars.watcherCount = 0
end

function Module:PostStopListening( )
	if (CA2.StatusGetOwnerId() ~= "u28traverse") then
		CA2.StatusDisable()
	end
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	if (result == ACTION_RESULT_BEGIN and abilityId == DATA.mephiticWave) then
		CA1.AlertCast(abilityId, sourceName, hitValue, { -3, 0, false, { 0.3, 0.9, 1, 0.6 }, { 0, 0.5, 1, 1 } })
	elseif (DATA.empower[abilityId]) then
		if (result == ACTION_RESULT_EFFECT_GAINED_DURATION) then
			Vars.empower.stop = GetGameTimeMilliseconds() + hitValue
			Vars.empower.color = DATA.empower[abilityId]
			CA2.StatusEnable({
				ownerId = "u28mino",
				rowLabels = LCA.GetAbilityName(abilityId),
				pollingFunction = self.StatusPoll_Mino,
			})
		elseif (result == ACTION_RESULT_EFFECT_FADED) then
			Vars.empower.stop = nil
		end
	elseif (result == ACTION_RESULT_BEGIN and DATA.channel[abilityId]) then
		local currentTime = GetGameTimeMilliseconds()
		if (Vars.channelPrev < currentTime - 5000) then
			Vars.channelPrev = currentTime
			CA1.Alert(nil, LCA.GetAbilityName(abilityId), DATA.channel[abilityId], SOUNDS.CHAMPION_POINTS_COMMITTED, 1500)
		end
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.sentinelSpawn) then
		CA1.Alert(nil, LCA.GetAbilityName(abilityId), 0xCC00FFFF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.watcherSpawn) then
		Vars.watcherCount = Vars.watcherCount + 1
		CA2.ChatMessage(string.format("%s #%d", LCA.GetAbilityName(abilityId), Vars.watcherCount))
	elseif (result == ACTION_RESULT_EFFECT_GAINED and DATA.flameSpout[abilityId]) then
		CA1.Alert(nil, zo_iconFormatInheritColor(LCA.GetTexture("arrow-rotate"), 96, 96 * DATA.flameSpout[abilityId]), 0xCCFFFFFF, nil, 1000)
	end
end

CA2.RegisterModule(Module)
