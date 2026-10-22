local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2
local Module = CA_Module:Subclass()

Module.ID = "CA_M_U46"
Module.NAME = CA2.GenerateModuleName(46, 1548)
Module.AUTHOR = "@code65536"
Module.ZONES = {
	1548, -- Ossein Cage
}

Module.STRINGS = {
	-- Custom (Settings)
	groupPanel = { default = "Enable group-wide Carrion/Blaze panel" },
	scalesChat = { default = "Reflective Scales chat messages" },
	scalesBorder = { default = "Reflective Scales screen border" },
	scalesNoTanks = { default = "Ignore Reflective Scales for tanks" },
}

Module.DEFAULT_SETTINGS = {
	groupPanel = true,
	scalesChat = true,
	scalesBorder = 0xFF990099,
	scalesNoTanks = false,
}

Module.DATA = {
	barrage = 238800,
	carrion = 240708,
	carrionB2 = 241089,
	carrionThreshold = {
		[240708] = 9,
		[241089] = 5,
	},
	etherealBurst = 236466,
	twinsHeavyProjectile = {
		[233750] = true, -- Jyn Incinerate PROJ
		[233756] = true, -- Skor Incinerate PROJ
	},
	stricken = 235594,
	blaze = 235356,
	scales = {
		[233320] = true, -- Myrinax
		[233328] = true, -- Valneer
	},
	scalesNameId = 233321,
	frenzy = {
		232722, -- 630 cast time, safe
		232725, -- 600 cast time, safe
		232726, -- 1500 cast time, usafe
		232723, -- 433 cast time, unsafe
	},
	seethingLeapCast = 245208,
	seethingLeapDamage = 245213,
}
local DATA = Module.DATA
local Vars

local Identifier = function(x) return Module.ID .. x end

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
		-- Cast time 3000, actual windup time 2567
		[233596] = { 0, 0, false, { 1, 0, 0.6, 0.8 }, offset = -433, cutthroat = true }, -- Spark Smash
		[233606] = { 0, 0, false, { 1, 0, 0.6, 0.8 }, offset = -433, cutthroat = true }, -- Blazing Smash
		[245149] = { -2, 2, offset = -433 }, -- Spark Smash (portal)
		[245157] = { -2, 2, offset = -433 }, -- Blazing Smash (portal)

		-- Cast time 3000, actual windup time 1650, projectile ranges from 100 to 700 (using 150)
		[233720] = { 0, 0, false, { 1, 0, 0.6, 0.8 }, offset = -1200, cutthroat = true }, -- Spark Surge Bolt
		[233751] = { 0, 0, false, { 1, 0, 0.6, 0.8 }, offset = -1200, cutthroat = true }, -- Forge Fire Bolt
		[245131] = { -3, 2, offset = -1200 }, -- Spark Surge Bolt (portal)
		[245140] = { -3, 2, offset = -1200 }, -- Forge Fire Bolt (portal)

		[235146] = { -2, 2, offset = 100 }, -- Shadow Strike
		[236458] = { -3, 2 }, -- Potent Ethereal Burst
		[236569] = { -2, 1, vet = true }, -- Spectral Revenge
		[238948] = { -2, 2 }, -- Necrotic Wave
		[240984] = { -2, 2 }, -- Heavy Strike
		[245273] = { -2, 1 }, -- Bone Saw
	}

	self.AOE_ALERTS = {
		-- { alert_duration, exclude_tanks }
		[232620] = { 400, false }, -- Ground Plague
	}

	self.vars = {
		lastBarrage = 0,
		scales = { },
		seethingLeapPrev = 0,
		seethingLeapId = 0,
	}
	Vars = self.vars

	-- Deconflict OCH timers
	zo_callLater(function( )
		if (CA2.IsModuleLoaded("OCH_U46")) then
			local ochTimers = CA2.GetModule("OCH_U46").TIMER_ALERTS_LEGACY
			if (ochTimers) then
				for abilityId in pairs(self.TIMER_ALERTS_LEGACY) do
					ochTimers[abilityId] = nil
				end
			end
		end
	end, 1000)

	self.CarrionUpdate = function( _, changeType, _, _, unitTag, _, endTime, stackCount, _, _, _, _, _, _, unitId, abilityId )
		if (self.panelMode ~= "carrion") then
			if (changeType == EFFECT_RESULT_GAINED) then
				self:TogglePanelMode("carrion")
			else
				return
			end
		end

		if (changeType == EFFECT_RESULT_FADED) then
			stackCount = 0
		end

		local max = DATA.carrionThreshold[abilityId]

		if (stackCount > 0) then
			local remaining = max - stackCount
			local ratio = zo_clamp(remaining / max, 0, 1)
			CA2.GroupPanelUpdate(unitTag, nil, LCA.PackRGBA(LCA.HSLToRGB(ratio / 3, 1, 0.5, 0.8)), stackCount)
		else
			-- Clear the cell
			CA2.GroupPanelUpdate(unitTag)
		end
	end

	self.BlazeUpdate = function( _, changeType, _, _, unitTag, _, endTime, stackCount, _, _, _, _, _, _, unitId, abilityId )
		if (self.panelMode ~= "blaze") then
			if (changeType == EFFECT_RESULT_GAINED) then
				self:TogglePanelMode("blaze")
			else
				return
			end
		end

		if (changeType == EFFECT_RESULT_GAINED) then
			CA2.GroupPanelUpdate(unitTag, nil, 0x3399FFFF)
		elseif (changeType == EFFECT_RESULT_FADED) then
			CA2.GroupPanelUpdate(unitTag)
		end
	end

	self.ScalesUpdate = function( _, result, _, _, _, _, _, _, _, _, hitValue, _, _, _, _, targetUnitId, abilityId )
		Vars.scales[targetUnitId] = (result ~= ACTION_RESULT_EFFECT_FADED) and true or nil
	end
end

function Module:PostLoad( )
	self:TogglePanelMode("carrion")
	LCA.RegisterForFilteredEvent(Identifier("CARRION"), EVENT_EFFECT_CHANGED,
		self.CarrionUpdate,
		REGISTER_FILTER_ABILITY_ID, DATA.carrion,
		REGISTER_FILTER_UNIT_TAG_PREFIX, "group"
	)
	LCA.RegisterForFilteredEvent(Identifier("CARRION_B2"), EVENT_EFFECT_CHANGED,
		self.CarrionUpdate,
		REGISTER_FILTER_ABILITY_ID, DATA.carrionB2,
		REGISTER_FILTER_UNIT_TAG_PREFIX, "group"
	)
	LCA.RegisterForFilteredEvent(Identifier("BLAZE"), EVENT_EFFECT_CHANGED,
		self.BlazeUpdate,
		REGISTER_FILTER_ABILITY_ID, DATA.blaze,
		REGISTER_FILTER_UNIT_TAG_PREFIX, "group"
	)
	for abilityId in pairs(DATA.scales) do
		LCA.RegisterForFilteredEvent(Identifier(abilityId), EVENT_COMBAT_EVENT, self.ScalesUpdate, REGISTER_FILTER_ABILITY_ID, abilityId)
	end
end

function Module:PreUnload( )
	EVENT_MANAGER:UnregisterForEvent(Identifier("CARRION"), EVENT_EFFECT_CHANGED)
	EVENT_MANAGER:UnregisterForEvent(Identifier("CARRION_B2"), EVENT_EFFECT_CHANGED)
	EVENT_MANAGER:UnregisterForEvent(Identifier("BLAZE"), EVENT_EFFECT_CHANGED)
	for abilityId in pairs(DATA.scales) do
		EVENT_MANAGER:UnregisterForEvent(Identifier(abilityId), EVENT_COMBAT_EVENT)
	end
	CA2.GroupPanelDisable()
end

function Module:PreStartListening( )
end

function Module:PostStopListening( )
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	-- Mini Boss 1
	if (result == ACTION_RESULT_BEGIN and abilityId == DATA.barrage) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - Vars.lastBarrage > hitValue) then
			Vars.lastBarrage = currentTime
			CA1.AlertCast(abilityId, nil, hitValue, { -3, 0, false, { 0.7, 0.3, 1, 0.3 }, { 0.7, 0.3, 1, 0.7 } })
		end

	-- Boss 1
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.etherealBurst and targetType == COMBAT_UNIT_TYPE_PLAYER and not LCA.isTank) then
		CA1.AlertCast(abilityId, sourceName, 800, { 800, 1 })

	-- Boss 2
	elseif (result == ACTION_RESULT_EFFECT_GAINED and targetType == COMBAT_UNIT_TYPE_PLAYER and hitValue > 100 and DATA.twinsHeavyProjectile[abilityId]) then
		CA2.UpdateNightbladeCutthroatExclusionStopTime(GetGameTimeMilliseconds() + hitValue + 100)
	elseif (sourceType == COMBAT_UNIT_TYPE_PLAYER and hitValue == 1 and LCA.DAMAGE_EVENTS[result] and Vars.scales[targetUnitId] and not (LCA.isTank and self:GetSetting("scalesNoTanks"))) then
		if (self:GetSetting("scalesChat")) then
			CA2.ChatMessage(string.format("[%s] %s", LCA.GetAbilityName(DATA.scalesNameId), LCA.GetAbilityName(abilityId)))
		end
		self:ShowScalesBorder()

	-- Boss 3
	elseif (result == ACTION_RESULT_EFFECT_GAINED_DURATION and abilityId == DATA.stricken and (targetType == COMBAT_UNIT_TYPE_PLAYER or LCA.DoesPlayerHaveTauntSlotted())) then
		local _, name = LCA.IdentifyGroupUnitIdWithRole(targetUnitId, true)
		CA1.Alert(LCA.GetAbilityName(abilityId), name, 0xCC3399FF, SOUNDS.CHAMPION_POINTS_COMMITTED, 2000)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.frenzy[3] and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA2.SetNightbladeCutthroatExclusion(GetGameTimeMilliseconds() + hitValue)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.frenzy[4] and targetType == COMBAT_UNIT_TYPE_PLAYER) then
		CA2.UpdateNightbladeCutthroatExclusionStopTime(GetGameTimeMilliseconds() + hitValue + 100)
	elseif (result == ACTION_RESULT_BEGIN and abilityId == DATA.seethingLeapCast and not CA2.IsModuleLoaded("OCH_U46")) then
		local currentTime = GetGameTimeMilliseconds()
		if (currentTime - Vars.seethingLeapPrev > 4000) then
			-- TODO: In the future after migrating to the new timer widget, instead of discarding second cast, use it to fine-tune the duration from the first cast's timer
			Vars.seethingLeapPrev = currentTime
			Vars.seethingLeapId = CA1.AlertCast(DATA.seethingLeapDamage, nil, hitValue * 2, { -2, 1 })
		end
	end
end

function Module:GetSettingsControls( )
	return {
		--------------------
		{
			type = "checkbox",
			name = self:GetString("groupPanel"),
			getFunc = function() return self:GetSetting("groupPanel") end,
			setFunc = function( enabled )
				self:SetSetting("groupPanel", enabled)
				self:TogglePanelMode("carrion")
			end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("scalesChat"),
			getFunc = function() return self:GetSetting("scalesChat") end,
			setFunc = function(enabled) self:SetSetting("scalesChat", enabled) end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("scalesBorder"),
			getFunc = function() return self:GetSetting("scalesBorder") ~= 0 end,
			setFunc = function( enabled )
				self:SetSetting("scalesBorder", not enabled and 0 or nil)
				self:ShowScalesBorder()
			end,
		},
		--------------------
		{
			type = "colorpicker",
			getFunc = function() return LCA.UnpackRGBA(self:GetSetting("scalesBorder")) end,
			setFunc = function( ... )
				self:SetSetting("scalesBorder", LCA.PackRGBA(...))
				self:ShowScalesBorder()
			end,
			disabled = function() return self:GetSetting("scalesBorder") == 0 end,
		},
		--------------------
		{
			type = "checkbox",
			name = self:GetString("scalesNoTanks"),
			getFunc = function() return self:GetSetting("scalesNoTanks") end,
			setFunc = function(enabled) self:SetSetting("scalesNoTanks", enabled) end,
		},
	}
end

function Module:TogglePanelMode( mode )
	self.panelMode = mode
	if (CA2.GroupPanelIsEnabled()) then
		CA2.GroupPanelDisable()
	end
	if (self:GetSetting("groupPanel")) then
		CA2.GroupPanelEnable({
			headerText = LCA.GetAbilityName(DATA[mode]),
			statWidth = 48,
			colorStat = 0x66CCFFFF,
			useUnitId = false,
			useRange = false,
		})
	end
end

function Module:ShowScalesBorder( )
	local color = self:GetSetting("scalesBorder")
	if (color ~= 0) then
		CA2.ScreenBorderEnable(color, 1100, "CA_M_U46_SCALES")
	end
end

CA2.RegisterModule(Module)
