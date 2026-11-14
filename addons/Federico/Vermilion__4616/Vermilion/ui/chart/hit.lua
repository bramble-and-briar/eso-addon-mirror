Vermilion = Vermilion or {}
Vermilion.ChartHit = {}
local M = Vermilion.ChartHit

local hit = { cols = {}, n = 0 }

local function hit_begin(n) hit.n = n end

local function hit_col(i, x, bw, s)
  if i == 1 then hit.t0 = s.t end
  local col = hit.cols[i]
  if not col then col = { bands = {} }; hit.cols[i] = col end
  col.x0 = x; col.x1 = x + bw; col.nb = 0; col.t = s.t
  col.edps = s.eDPS; col.shdps = s.ShDPS; col.crit = s.crit; col.noncrit = s.noncrit
  col.eos_abilities = s.eos_abilities; col.dtype_abilities = s.dtype_abilities
  col.shield_abilities = s.shield_abilities
  return col
end

M.hit, M.begin, M.col = hit, hit_begin, hit_col
