
Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Pipeline = Verdant.Pipeline or {}
Verdant.Pipeline.Processing = {}
local M = Verdant.Pipeline.Processing

local AK = Verdant.Constants.ABILITY_KIND
local KIND_HEAL         = AK.HEAL
local KIND_OVERHEAL     = AK.OVERHEAL
local KIND_SHIELD       = AK.SHIELD
local KIND_DAMAGE_GROUP = AK.DAMAGE_GROUP
local KIND_RESTORE_MAG  = AK.RESTORE_MAG
local KIND_RESTORE_STA  = AK.RESTORE_STA

function M.process(ev)
  local k = ev.kind
  if k == KIND_HEAL then
    Verdant.Metrics.ingest_heal(ev)
    Verdant.Coverage.touch(ev.target_unit_id, ev.t)
  elseif k == KIND_OVERHEAL then
    Verdant.Metrics.ingest_overheal(ev)
  elseif k == KIND_SHIELD then
    Verdant.Metrics.ingest_shield(ev)
  elseif k == KIND_DAMAGE_GROUP then
    Verdant.Metrics.ingest_damage_group(ev)
  elseif k == KIND_RESTORE_MAG or k == KIND_RESTORE_STA then
    Verdant.Metrics.ingest_restore(ev)
  end
end
