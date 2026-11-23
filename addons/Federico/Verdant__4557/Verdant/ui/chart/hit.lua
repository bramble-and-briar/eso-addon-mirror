Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ChartHit = {}
local M = Verdant.ChartHit

local view_start_ms = Verdant.ChartColumns.view_start_ms

local function hit_begin(H, n) H.n = n end

local function hit_col(H, i, x, bw, s)
  if i == 1 then H.t0 = s.t - view_start_ms() end
  local col = H.cols[i]
  if not col then col = { bands = {} }; H.cols[i] = col end
  col.x0 = x; col.x1 = x + bw; col.nb = 0; col.t = s.t
  col.ehps = s.e1; col.mps = s.m1; col.crit = s.crit; col.noncrit = s.noncrit
  col.d = s.d or 0; col.oh = s.oh or 0; col.eh = s.eHPS or 0
  col.rm = s.rm; col.rs = s.rs
  col.mag = s.mag; col.sta = s.sta; col.mag_in = s.mag_in; col.mag_out = s.mag_out; col.sta_in = s.sta_in; col.sta_out = s.sta_out
  col.ehps_abilities = s.ehps_abilities; col.mps_abilities = s.mps_abilities
  return col
end

M.begin = hit_begin
M.col   = hit_col
