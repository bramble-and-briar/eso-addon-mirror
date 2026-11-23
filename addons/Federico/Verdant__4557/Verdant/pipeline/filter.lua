
Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Pipeline = Verdant.Pipeline or {}
Verdant.Pipeline.Filter = {}
local M = Verdant.Pipeline.Filter

local AK = Verdant.Constants.ABILITY_KIND
local KIND_SHIELD       = AK.SHIELD
local KIND_DAMAGE_GROUP = AK.DAMAGE_GROUP

local function bump(key) Verdant.Diagnostics.bump(key) end

function M.allow(ev)
  local k = ev.kind
  if k == KIND_SHIELD then
    if not Verdant.ShieldRegistry.is_self_cast(ev.ability_id, ev.target_unit_id, ev.t) then
      bump("engine.shield.foreign")
      return false
    end
    return true
  elseif k == KIND_DAMAGE_GROUP then
    if not Verdant.GroupSet.contains(ev.target_unit_id) then
      bump("engine.damage.not_in_groupset")
      return false
    end
    return true
  end
  return true
end
