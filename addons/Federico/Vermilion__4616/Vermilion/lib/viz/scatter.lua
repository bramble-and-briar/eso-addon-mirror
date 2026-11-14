Vermilion = Vermilion or {}
local Vermilion = Vermilion
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.viz = Vermilion.lib.viz or {}

local SC = {}
Vermilion.lib.viz.scatter = SC

local S = Vermilion.lib.viz.surface
local math_floor = math.floor
local math_cos = math.cos
local math_sin = math.sin
local TWO_PI = 2 * math.pi

local C_AXIS = { r = 1, g = 1, b = 1 }
local DOT = 5
local RING_STEPS = 24
local RING_DOT = 2

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

local function px(px0, side, max, v)
  if v < 0 then v = 0 elseif v > max then v = max end
  return px0 + math_floor(v / max * side + 0.5)
end

local function py(py0, side, max, v)
  if v < 0 then v = 0 elseif v > max then v = max end
  return py0 + side - math_floor(v / max * side + 0.5)
end

function SC.point(px0, py0, side, max, x, y)
  return px(px0, side, max, x), py(py0, side, max, y)
end

function SC.ring(c, cx, cy, r, col, a, lvl)
  for k = 0, RING_STEPS - 1 do
    local ang = k / RING_STEPS * TWO_PI
    local x = cx + math_floor(math_cos(ang) * r + 0.5)
    local y = cy + math_floor(math_sin(ang) * r + 0.5)
    S.box(c, x - 1, x - 1 + RING_DOT, y - 1, RING_DOT, col, a, lvl or 4)
  end
end

function SC.plot(c, px0, py0, side, max, xs, ys, n, col, opts)
  prof_enter("viz.scatter")
  local before = c.drawn or 0
  if max <= 0 then max = 1 end
  S.frame(c, px0, py0, px0 + side, py0 + side, C_AXIS, (opts and opts.axis_alpha) or 0.15, 2)
  if opts and opts.diagonal then
    S.line(c, px0, py0 + side, px0 + side, py0, C_AXIS, 0.2, 1, 3)
  end
  if opts and opts.rings then
    local rx, ry, rr, rn = opts.rings.x, opts.rings.y, opts.rings.r, opts.rings.n
    local rcol = opts.rings.col or col
    local rcols = opts.rings.cols
    for i = 1, rn do
      local cxp, cyp, rp = px(px0, side, max, rx[i]), py(py0, side, max, ry[i]), math_floor(rr[i] / max * side + 0.5)
      if not S.tex_ring(c, cxp, cyp, rp, (rcols and rcols[i]) or rcol, (opts.rings.alpha) or 0.7, 4) then
        SC.ring(c, cxp, cyp, rp, (rcols and rcols[i]) or rcol, (opts.rings.alpha) or 0.7, 4)
      end
    end
  end
  local outside = 0
  local cols = opts and opts.cols
  for i = 1, n do
    local x, y = xs[i], ys[i]
    if x > max or y > max then outside = outside + 1 end
    local sx, sy = px(px0, side, max, x), py(py0, side, max, y)
    S.disc(c, sx, sy, (opts and opts.dot) or DOT, (cols and cols[i]) or col, (opts and opts.alpha) or 0.85, 5)
  end
  bump("viz.scatter.renders")
  bump("viz.scatter.controls", (c.drawn or 0) - before)
  prof_exit("viz.scatter")
  return outside
end
