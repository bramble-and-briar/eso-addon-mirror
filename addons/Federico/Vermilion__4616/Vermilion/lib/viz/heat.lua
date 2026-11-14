Vermilion = Vermilion or {}
local Vermilion = Vermilion
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.viz = Vermilion.lib.viz or {}

local HT = {}
Vermilion.lib.viz.heat = HT

local S = Vermilion.lib.viz.surface
local math_floor = math.floor

local CELLS_MAX = 40
local grid = {}
for i = 1, CELLS_MAX * CELLS_MAX do grid[i] = 0 end
local bins = {}
for i = 1, 128 do bins[i] = 0 end

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

function HT.grid(c, px0, py0, side, max, xs, ys, n, cells, col, opts)
  prof_enter("viz.heat")
  local before = c.drawn or 0
  if cells > CELLS_MAX then cells = CELLS_MAX end
  if max <= 0 then max = 1 end
  for i = 1, cells * cells do grid[i] = 0 end
  local top = 0
  for i = 1, n do
    local x, y = xs[i], ys[i]
    if x >= 0 and y >= 0 and x <= max and y <= max then
      local cx = math_floor(x / max * cells)
      local cy = math_floor(y / max * cells)
      if cx >= cells then cx = cells - 1 end
      if cy >= cells then cy = cells - 1 end
      local gi = cy * cells + cx + 1
      grid[gi] = grid[gi] + 1
      if grid[gi] > top then top = grid[gi] end
    end
  end
  local cell = side / cells
  local a_lo, a_hi = (opts and opts.alpha_lo) or 0.06, (opts and opts.alpha_hi) or 0.55
  if top > 0 then
    for cy = 0, cells - 1 do
      for cx = 0, cells - 1 do
        local v = grid[cy * cells + cx + 1]
        if v > 0 then
          local a = a_lo + (a_hi - a_lo) * (v / top)
          local x0 = px0 + math_floor(cx * cell + 0.5)
          local x1 = px0 + math_floor((cx + 1) * cell + 0.5)
          local y1 = py0 + side - math_floor(cy * cell + 0.5)
          local y0 = py0 + side - math_floor((cy + 1) * cell + 0.5)
          S.box(c, x0, x1, y0, y1 - y0, col, a, (opts and opts.level) or 2)
        end
      end
    end
  end
  bump("viz.heat.renders")
  bump("viz.heat.controls", (c.drawn or 0) - before)
  prof_exit("viz.heat")
  return top
end

function HT.marginal_v(c, x0, y0, w, h, ys, n, max, nbins, col, opts)
  prof_enter("viz.heat")
  local before = c.drawn or 0
  if nbins > 128 then nbins = 128 end
  if max <= 0 then max = 1 end
  for i = 1, nbins do bins[i] = 0 end
  local top = 0
  for i = 1, n do
    local y = ys[i]
    if y >= 0 and y <= max then
      local b = math_floor(y / max * nbins) + 1
      if b > nbins then b = nbins end
      bins[b] = bins[b] + 1
      if bins[b] > top then top = bins[b] end
    end
  end
  if top > 0 then
    local bh = h / nbins
    for b = 1, nbins do
      local v = bins[b]
      if v > 0 then
        local ww = math_floor(v / top * w + 0.5)
        if ww < 1 then ww = 1 end
        local by1 = y0 + h - math_floor((b - 1) * bh + 0.5)
        local by0 = y0 + h - math_floor(b * bh + 0.5)
        if by1 - by0 > 2 then by0 = by0 + 1 end
        S.box(c, x0 + w - ww, x0 + w, by0, by1 - by0, col, (opts and opts.alpha) or 0.7, (opts and opts.level) or 3)
      end
    end
  end
  bump("viz.heat.renders")
  bump("viz.heat.controls", (c.drawn or 0) - before)
  prof_exit("viz.heat")
  return top
end

function HT.marginal(c, x0, y0, w, h, xs, n, max, nbins, col, opts)
  prof_enter("viz.heat")
  local before = c.drawn or 0
  if nbins > 128 then nbins = 128 end
  if max <= 0 then max = 1 end
  for i = 1, nbins do bins[i] = 0 end
  local top = 0
  for i = 1, n do
    local x = xs[i]
    if x >= 0 and x <= max then
      local b = math_floor(x / max * nbins) + 1
      if b > nbins then b = nbins end
      bins[b] = bins[b] + 1
      if bins[b] > top then top = bins[b] end
    end
  end
  if top > 0 then
    local bw = w / nbins
    for b = 1, nbins do
      local v = bins[b]
      if v > 0 then
        local hh = math_floor(v / top * h + 0.5)
        if hh < 1 then hh = 1 end
        local bx0 = x0 + math_floor((b - 1) * bw + 0.5)
        local bx1 = x0 + math_floor(b * bw + 0.5)
        if bx1 - bx0 > 2 then bx1 = bx1 - 1 end
        S.box(c, bx0, bx1, y0 + h - hh, hh, col, (opts and opts.alpha) or 0.7, (opts and opts.level) or 3)
      end
    end
  end
  bump("viz.heat.renders")
  bump("viz.heat.controls", (c.drawn or 0) - before)
  prof_exit("viz.heat")
  return top
end
