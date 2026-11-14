Vermilion = Vermilion or {}
local Vermilion = Vermilion
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.viz = Vermilion.lib.viz or {}

local SP = {}
Vermilion.lib.viz.spans = SP

local S = Vermilion.lib.viz.surface
local math_max = math.max
local math_min = math.min

local C_GROUND = { r = 0.86, g = 0.28, b = 0.18 }
local C_PRESS  = { r = 0.94, g = 0.88, b = 0.86 }
local C_CLIP   = { r = 0.80, g = 0.68, b = 0.40 }
local STIPPLE_ON, STIPPLE_PERIOD = 2, 4

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

function SP.row(c, scale, y, h, col, t0, t1, n, press, pn, clip, opts)
  prof_enter("viz.spans")
  local before = c.drawn or 0
  local x_lo, x_hi = scale.x0, scale.x0 + scale.w
  local t_lo, t_hi = scale.t0, scale.t0 + scale.span
  local ground = (opts and opts.ground) or C_GROUND
  S.box(c, x_lo, x_hi, y, h, ground, (opts and opts.ground_alpha) or 0.18, 2)
  local covered = 0
  local run_a, run_b = nil, nil
  for i = 1, n do
    local a, b = t0[i], t1[i]
    if b > t_lo and a < t_hi then
      if a < t_lo then a = t_lo end
      if b > t_hi then b = t_hi end
      if run_a and a <= run_b then
        if b > run_b then run_b = b end
      else
        if run_a then
          covered = covered + (run_b - run_a)
          local xa, xb = S.x_of(scale, run_a), S.x_of(scale, run_b)
          S.box(c, xa, math_max(xb, xa + 1), y, h, col, (opts and opts.alpha) or 0.85, 3)
        end
        run_a, run_b = a, b
      end
    end
  end
  if run_a then
    covered = covered + (run_b - run_a)
    local xa, xb = S.x_of(scale, run_a), S.x_of(scale, run_b)
    S.box(c, xa, math_max(xb, xa + 1), y, h, col, (opts and opts.alpha) or 0.85, 3)
  end
  if press then
    for i = 1, pn do
      local t = press[i]
      if t >= t_lo and t <= t_hi then
        local x = S.x_of(scale, t)
        local cl = clip and clip[i] or 0
        if cl > 0 then
          local xc = S.x_of(scale, math_max(t_lo, t - cl))
          local xs = xc
          while xs < x do
            S.box(c, xs, math_min(x, xs + STIPPLE_ON), y, h, C_CLIP, 0.8, 4)
            xs = xs + STIPPLE_PERIOD
          end
        end
        S.box(c, x, x + 1, y - 2, h + 4, C_PRESS, 0.9, 5)
      end
    end
  end
  bump("viz.spans.renders")
  bump("viz.spans.controls", (c.drawn or 0) - before)
  prof_exit("viz.spans")
  if scale.span > 0 then return covered / scale.span end
  return 0
end
