Vermilion = Vermilion or {}
local Vermilion = Vermilion
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.viz = Vermilion.lib.viz or {}

local ST = {}
Vermilion.lib.viz.stems = ST

local S = Vermilion.lib.viz.surface
local math_floor = math.floor

local C_ZERO = { r = 1, g = 1, b = 1 }
local HEAD = 5
local HALF = 2

local function prof_enter(name)
  local P = Vermilion.Profiler
  if P and P.enter then P.enter(name) end
end

local function prof_exit(name)
  local P = Vermilion.Profiler
  if P and P.exit then P.exit(name) end
end

local function bump(key, n)
  local D = Vermilion.Diagnostics
  if D and D.bump then D.bump(key, n) end
end

local function y_of(v, y, h, vmin, vmax, range)
  if v < vmin then v = vmin elseif v > vmax then v = vmax end
  return y + h - math_floor((v - vmin) / range * h + 0.5)
end

function ST.plot(c, scale, y, h, xs, vs, n, vmin, vmax, band_lo, band_hi, col_up, col_dn, col_in, opts)
  prof_enter("viz.stems")
  local before = c.drawn or 0
  local range = vmax - vmin
  if range <= 0 then range = 1 end
  local x_lo, x_hi = scale.x0, scale.x0 + scale.w
  if band_hi > band_lo and col_in then
    local yb_hi, yb_lo = y_of(band_hi, y, h, vmin, vmax, range), y_of(band_lo, y, h, vmin, vmax, range)
    S.box(c, x_lo, x_hi, yb_hi, yb_lo - yb_hi, col_in, (opts and opts.band_alpha) or 0.14, 2)
  end
  local y0 = y_of(0, y, h, vmin, vmax, range)
  S.box(c, x_lo, x_hi, y0, 1, C_ZERO, 0.2, 3)
  local clamped = 0
  local t_hi = scale.t0 + scale.span
  for i = 1, n do
    local t, v = xs[i], vs[i]
    if t >= scale.t0 and t <= t_hi then
      local x = S.x_of(scale, t)
      local yv = y_of(v, y, h, vmin, vmax, range)
      local col = (v > band_hi) and col_up or (v < band_lo) and col_dn or col_in or col_up
      if yv < y0 then S.box(c, x, x + 1, yv, y0 - yv, col, 0.9, 4)
      elseif yv > y0 then S.box(c, x, x + 1, y0, yv - y0, col, 0.9, 4) end
      if v > vmax or v < vmin then
        clamped = clamped + 1
        S.frame(c, x - HALF, yv - HALF, x - HALF + HEAD, yv - HALF + HEAD, col, 1, 5)
      elseif v >= band_lo and v <= band_hi then
        S.disc(c, x, yv, HEAD + 2, col, 1, 5)
      else
        S.box(c, x - HALF, x - HALF + HEAD, yv - HALF, HEAD, col, 1, 5)
      end
    end
  end
  bump("viz.stems.renders")
  bump("viz.stems.controls", (c.drawn or 0) - before)
  prof_exit("viz.stems")
  return clamped
end
