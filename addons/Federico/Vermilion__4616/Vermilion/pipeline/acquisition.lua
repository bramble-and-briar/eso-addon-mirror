-- *pipeline/acquisition.lua

-- Stage 1 of the pipeline. Acquires VermilionEvents from the pool and
-- populates them from the raw ZOS combat-event tuple. No filtering (stage 2),
-- no state mutation (stage 3). A nil return means the pool was exhausted.
-- callers must bump engine.pool.exhausted.

Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Pipeline = Vermilion.Pipeline or {}
Vermilion.Pipeline.Acquisition = {}
local M = Vermilion.Pipeline.Acquisition

local AK = Vermilion.Constants.ABILITY_KIND
local KIND_DAMAGE_OUT = AK.DAMAGE_OUT
local KIND_SHIELD_OUT = AK.SHIELD_OUT

local GetGameTimeMilliseconds = Vermilion.zenimax.api.GetGameTimeMilliseconds

local function acquire()
  return Vermilion.Metrics.acquire_event()
end

function M.acquire_damage_out(t, hit, targetUnitId, targetType, abilityId, result, sourceUnitId, damageType, targetName, overflow)
  if (hit or 0) <= 0 then return nil end
  local ev = acquire()
  if not ev then return nil end
  ev.t              = t
  ev.kind           = KIND_DAMAGE_OUT
  ev.result         = result        or 0
  ev.amount         = hit
  ev.damage_type    = damageType    or 0
  ev.overflow       = overflow      or 0
  ev.target_unit_id = targetUnitId  or 0
  ev.target_type    = targetType    or 0
  ev.ability_id     = abilityId     or 0
  ev.source_unit_id = sourceUnitId  or 0
  ev.attack_id      = 0
  ev.attack_dtype   = 0
  ev.target_name    = targetName or ""
  return ev
end

function M.acquire_shield_out(t, hit, targetUnitId, targetType, abilityId, result, sourceUnitId, targetName)
  if (hit or 0) <= 0 then return nil end
  local ev = acquire()
  if not ev then return nil end
  ev.t              = t
  ev.kind           = KIND_SHIELD_OUT
  ev.result         = result        or 0
  ev.amount         = hit
  ev.damage_type    = 0
  ev.target_unit_id = targetUnitId  or 0
  ev.target_type    = targetType    or 0
  ev.ability_id     = abilityId     or 0
  ev.source_unit_id = sourceUnitId  or 0
  ev.attack_id      = 0
  ev.attack_dtype   = 0
  ev.target_name    = targetName or ""
  return ev
end

function M.now()
  return GetGameTimeMilliseconds()
end
