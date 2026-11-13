local LCA = LibCombatAlerts
local CA1 = CombatAlerts
local CA2 = CombatAlerts2

CA_Module = ZO_Object:Subclass()
local CA_Module = CA_Module


--------------------------------------------------------------------------------
-- Members that must be overridden
--------------------------------------------------------------------------------

CA_Module.ID = "CA_Module"
CA_Module.NAME = "-"
CA_Module.AUTHOR = "-"
CA_Module.ZONES = { }


--------------------------------------------------------------------------------
-- Members that can be overridden as needed
--------------------------------------------------------------------------------

CA_Module.STRINGS = { }
CA_Module.DEFAULT_SETTINGS = { }
CA_Module.DATA = { }

CA_Module.ALWAYS_LISTENING = false

CA_Module.MONITOR_BOSSES = false
CA_Module.MONITOR_EFFECTS = false
CA_Module.MONITOR_UNIT_IDS = false

CA_Module.SMALL_GROUP_SIZE = false

CA_Module.TIMER_ALERTS_LEGACY = { }
CA_Module.AOE_ALERTS = { }
CA_Module.PURGEABLE_EFFECTS = { }

function CA_Module:Initialize( )
	-- Code here is run only once, right before the module is loaded for the very first time
end

function CA_Module:PostLoad( )
	-- Code here is run right after every time the module is loaded
end

function CA_Module:PreUnload( )
	-- Code here is run right before every time the module is unloaded
end

function CA_Module:OnBossesChanged( )
end

function CA_Module:PreStartListening( )
end

function CA_Module:PostStopListening( )
end

function CA_Module:ProcessCombatEvents( )
end

function CA_Module:OnEffectChanged( )
end

function CA_Module:GetSettingsControls( )
	return { }
end


--------------------------------------------------------------------------------
-- Members that probably should not be overridden
--------------------------------------------------------------------------------

CA_Module.loaded = false
CA_Module.initialized = false
CA_Module.listening = false
CA_Module.castSources = { }

function CA_Module:Load( )
	if (not self.loaded) then
		self.loaded = true

		if (not self.initialized) then
			self.initialized = true
			self:Initialize()
		end

		if (self.MONITOR_BOSSES) then
			EVENT_MANAGER:RegisterForEvent(self.ID, EVENT_BOSSES_CHANGED, function(_, ...) self:OnBossesChanged(...) end)
		end

		if (self.ALWAYS_LISTENING) then
			self:StartListening()
		else
			EVENT_MANAGER:RegisterForEvent(self.ID, EVENT_PLAYER_COMBAT_STATE, function(_, ...) self:OnPlayerCombatState(...) end)
			if (IsUnitInCombat("player")) then
				self:OnPlayerCombatState(true)
			end
		end

		self:PostLoad()

		if (self.MONITOR_BOSSES) then
			self:OnBossesChanged()
		end

		if (not CA2.sv.suppressModuleMessages) then
			CA2.ChatMessage(zo_strformat(SI_CA_MODULE_LOAD, self.NAME), true)
		end
	end
end

function CA_Module:Unload( )
	if (self.loaded) then
		self.loaded = false

		self:PreUnload()
		self:StopListening()
		EVENT_MANAGER:UnregisterForEvent(self.ID, EVENT_BOSSES_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(self.ID, EVENT_PLAYER_COMBAT_STATE)

		if (not CA2.sv.suppressModuleMessages) then
			CA2.ChatMessage(zo_strformat(SI_CA_MODULE_UNLOAD, self.NAME), true)
		end
	end
end

function CA_Module:IsLoaded( )
	return self.loaded
end

function CA_Module:StartListening( )
	self:PurgeDelayedStops()
	if (not self.listening) then
		self.listening = true
		self:PreStartListening()
		LCA.RegisterForFilteredEvent(self.ID, EVENT_COMBAT_EVENT, function(_, ...) self:OnCombatEvent(...) end, REGISTER_FILTER_IS_ERROR, false)
		if (self.MONITOR_EFFECTS) then
			EVENT_MANAGER:RegisterForEvent(self.ID, EVENT_EFFECT_CHANGED, function(_, ...) self:OnEffectChanged(...) end)
		end
		if (self.MONITOR_UNIT_IDS) then
			LCA.ToggleUnitIdTracking(self.ID, true)
		end
		if (next(self.PURGEABLE_EFFECTS)) then
			CA2.TogglePurgeTracker(self.ID, self.PURGEABLE_EFFECTS, self.SMALL_GROUP_SIZE)
		end
		ZO_ClearTable(self.castSources)
	end
end

function CA_Module:StopListening( )
	self:PurgeDelayedStops()
	if (self.listening) then
		self.listening = false
		EVENT_MANAGER:UnregisterForEvent(self.ID, EVENT_COMBAT_EVENT)
		EVENT_MANAGER:UnregisterForEvent(self.ID, EVENT_EFFECT_CHANGED)
		LCA.ToggleUnitIdTracking(self.ID, false)
		CA2.TogglePurgeTracker(self.ID)
		self:PostStopListening()
	end
end

function CA_Module:PurgeDelayedStops( )
	if (self.delayedStopId) then
		zo_removeCallLater(self.delayedStopId)
		self.delayedStopId = nil
	end
end

function CA_Module:OnPlayerCombatState( inCombat )
	if (inCombat) then
		self:StartListening()
	else
		-- Avoid false positives of combat end, often caused by combat rezzes
		self:PurgeDelayedStops()
		self.delayedStopId = zo_callLater(function( )
			self.delayedStopId = nil
			if (not IsUnitInCombat("player")) then
				self:StopListening()
			end
		end, 3000)
	end
end

function CA_Module:OnCombatEvent( ... )
	if (self.divertNextEvent) then
		local fn = self.divertNextEvent
		self.divertNextEvent = nil
		if (fn(...)) then
			return
		end
	end

	if (self:ProcessStandardAlerts(...)) then
		self:ProcessCombatEvents(...)

		if (self.divertCurrentEvent) then
			local fn = self.divertCurrentEvent
			self.divertCurrentEvent = nil
			fn(...)
		end
	end
end

function CA_Module:ProcessStandardAlerts( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
	if (targetType == COMBAT_UNIT_TYPE_PLAYER and result == ACTION_RESULT_BEGIN and self.TIMER_ALERTS_LEGACY[abilityId]) then
		local options = self.TIMER_ALERTS_LEGACY[abilityId]
		if ((not options.vet or LCA.isVet) and (not options.extCheck or options.extCheck())) then
			local offset = options.offset or 0
			local id = CA1.AlertCast(abilityId, sourceName, hitValue + offset, options)
			if (options[3] and LCA.IsUnitIdValid(sourceUnitId)) then
				self.castSources[sourceUnitId] = id
			end
			if (options.cutthroat) then
				CA2.SetNightbladeCutthroatExclusion(GetGameTimeMilliseconds() + hitValue + offset)
			end
		end
	elseif (LCA.INTERRUPT_EVENTS[result] and self.castSources[targetUnitId]) then
		CA1.CastAlertsStop(self.castSources[targetUnitId])
	elseif (targetType == COMBAT_UNIT_TYPE_PLAYER and LCA.DAMAGE_EVENTS[result] and self.AOE_ALERTS[abilityId]) then
		local params = self.AOE_ALERTS[abilityId]
		if (not (params[2] and LCA.isTank)) then
			CA2.ScreenBorderEnable(0x00990099, params[1], "CA_AOE_ALERT")
		end
	else
		return true
	end

	return false
end

function CA_Module:GetString( key )
	return LCA.GetLocalizedData(self.STRINGS[key])
end

function CA_Module:GetScratch( )
	self._scratch = LCA.PrepareScratchTable(self._scratch)
	return self._scratch
end

function CA_Module:GetSettings( )
	if (type(self.currentSettings) ~= "table") then
		if (type(CombatAlertsModules) ~= "table") then
			CombatAlertsModules = { }
		end
		if (type(CombatAlertsModules[self.ID]) ~= "table") then
			CombatAlertsModules[self.ID] = { }
		end
		self.currentSettings = CombatAlertsModules[self.ID]
	end
	return self.currentSettings
end

function CA_Module:GetSetting( id )
	local result = self:GetSettings()[id]
	if (result ~= nil) then
		return result
	else
		return self.DEFAULT_SETTINGS[id]
	end
end

function CA_Module:SetSetting( id, value )
	self:GetSettings()[id] = value
end

function CA_Module:GetDebugData( )
	return self.vars, self.DATA
end
