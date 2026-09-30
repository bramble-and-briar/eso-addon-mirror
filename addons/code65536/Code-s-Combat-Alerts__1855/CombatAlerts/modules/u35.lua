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

Module.DATA = {
}
local DATA = Module.DATA
local Vars

function Module:Initialize( )
	self.MONITOR_UNIT_IDS = true

	self.TIMER_ALERTS_LEGACY = {
	}

	self.AOE_ALERTS = {
	}

	self.vars = {
	}
	Vars = self.vars
end

function Module:PostStopListening( )
	CA2.StatusDisable()
end

function Module:ProcessCombatEvents( result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow )
end

--CA2.RegisterModule(Module)
