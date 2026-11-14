--* pipeline/filter.lua

Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Pipeline = Vermilion.Pipeline or {}
Vermilion.Pipeline.Filter = {}
local M = Vermilion.Pipeline.Filter

local bump = Vermilion.Diagnostics.bump   -- no-op in release (DEBUG=false)
local KIND_DAMAGE_OUT = Vermilion.Constants.ABILITY_KIND.DAMAGE_OUT
local UNIT_SELF = Vermilion.zenimax.constants.COMBAT_UNIT_TYPE_PLAYER
local UNIT_PET = Vermilion.zenimax.constants.COMBAT_UNIT_TYPE_PLAYER_PET
local UNIT_GROUP = Vermilion.zenimax.constants.COMBAT_UNIT_TYPE_GROUP or 3
local dueling = false

function M.set_dueling(on) dueling = on and true or false end
function M.dueling() return dueling end

--* I left it this way for research purposes, 
--* the main filter right now is a simple source-attribution guard r <=> (k != K OR f(i) > 0).
--? In the future, we may want to add more complex filtering logic here, 
--? but idk ... for now this is sufficient to clean up our damage metrics in PvP without risking false positives on the eDPS side at least 
function M.allow(ev)
  if ev.kind == KIND_DAMAGE_OUT and (ev.source_unit_id or 0) <= 0 then
    bump("filter.dropped_env")
    return false
  end
  if ev.target_type == UNIT_SELF or ev.target_type == UNIT_PET then
    bump("filter.dropped_self")
    return false
  end
  if ev.target_type == UNIT_GROUP and not dueling then
    bump("filter.dropped_group")
    return false
  end
  return true
end
