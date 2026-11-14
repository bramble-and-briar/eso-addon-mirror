Vermilion = Vermilion or {}
local Vermilion = Vermilion
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.viz = Vermilion.lib.viz or {}

local RG = {}
Vermilion.lib.viz.ring = RG

local S = Vermilion.lib.viz.surface
local math_floor = math.floor
local math_cos = math.cos
local math_sin = math.sin
local TWO_PI = 2 * math.pi
local HALF_PI = math.pi / 2

local STEPS = 48

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

local function boxes(c, cx, cy, r, frac, col, thick, opts)
  local lit = math_floor(frac * STEPS + 0.5)
  local t = thick or 3
  local half = math_floor(t / 2)
  local dim = (opts and opts.dim_alpha) or 0.12
  for k = 0, STEPS - 1 do
    local ang = k / STEPS * TWO_PI - HALF_PI
    local x = cx + math_floor(math_cos(ang) * r + 0.5)
    local y = cy + math_floor(math_sin(ang) * r + 0.5)
    local a = (k < lit) and 0.95 or dim
    S.box(c, x - half, x - half + t, y - half, t, col, a, (opts and opts.level) or 4)
  end
  return lit
end

local function textured(c, cx, cy, r, frac, col, opts)
  local size = r * 2
  S.tex_ring(c, cx, cy, r, col, (opts and opts.dim_alpha) or 0.14, (opts and opts.level) or 4)
  local cd = c.cd:AcquireObject()
  if not cd then
    c.dropped = (c.dropped or 0) + 1
    bump("viz.ring.dropped")
    return 0
  end
  cd:ClearAnchors()
  cd:SetAnchor(CENTER, c.canvas, TOPLEFT, cx, cy)
  cd:SetDimensions(size, size)
  cd:SetTexture(c.ring_tex)
  cd:SetFillColor(col.r, col.g, col.b, (opts and opts.alpha) or 0.95)
  if cd.SetDrawLevel then cd:SetDrawLevel(((opts and opts.level) or 4) + 1) end
  cd:StartFixedCooldown(frac, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
  cd:SetHidden(false)
  c.drawn = (c.drawn or 0) + 1
  return math_floor(frac * STEPS + 0.5)
end

function RG.gauge(c, cx, cy, r, frac, col, thick, opts)
  prof_enter("viz.ring")
  local before = c.drawn or 0
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  local lit
  if c.cd and c.ring_tex and c.icon then
    lit = textured(c, cx, cy, r, frac, col, opts)
  else
    lit = boxes(c, cx, cy, r, frac, col, thick, opts)
  end
  bump("viz.ring.renders")
  bump("viz.ring.controls", (c.drawn or 0) - before)
  prof_exit("viz.ring")
  return lit
end
