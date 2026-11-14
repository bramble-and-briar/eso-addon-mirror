Vermilion = Vermilion or {}
local Vermilion = Vermilion
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.viz = Vermilion.lib.viz or {}

local RC = {}
Vermilion.lib.viz.race = RC

local S = Vermilion.lib.viz.surface
local ALIGN_CENTER = Vermilion.zenimax.constants.TEXT_ALIGN_CENTER
local math_floor = math.floor

local C_GROUND = { r = 1, g = 1, b = 1 }
local LANE_H, RUN_H = 12, 6
local GROUND_A, PACE_A, MARK_A, RUN_A = 0.05, 0.30, 0.90, 0.95
local GRID_A, TEXT_A = 0.07, 0.45
local TEXT_W, TEXT_H = 40, 12
local STEPS = { 1, 2, 5, 10, 20, 25, 50, 100 }
local MAX_LINES = 5

local PCT = {}
for i = 0, 100 do PCT[i] = i .. "%" end

RC.LANE_H, RC.RUN_H = LANE_H, RUN_H

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

local function reach(share, top, w)
  if share <= 0 then return 0 end
  local px = math_floor(share / top * w + 0.5)
  if px < 1 then px = 1 end
  if px > w then px = w end
  return px
end

function RC.step(top)
  local pct = top * 100
  for i = 1, #STEPS do
    if pct / STEPS[i] <= MAX_LINES then return STEPS[i] end
  end
  return STEPS[#STEPS]
end

function RC.scale(c, x, y, w, h, top, col, text_y, text_lo, text_hi)
  if w < 2 or top <= 0 then return 0 end
  prof_enter("viz.race")
  local before = c.drawn or 0
  local pct = top * 100
  local step = RC.step(top)
  local lines = 0
  local p = step
  while p <= pct and p <= 100 do
    local gx = x + math_floor(p / pct * w + 0.5)
    S.box(c, gx, gx + 1, y, h, col, GRID_A, 2)
    lines = lines + 1
    if text_y then
      local half = TEXT_W / 2
      if gx - half >= (text_lo or gx - half) and gx + half <= (text_hi or gx + half) then
        S.label(c, PCT[p], gx - half, text_y, TEXT_W, TEXT_H, ALIGN_CENTER, col, TEXT_A)
      end
    end
    p = p + step
  end
  bump("viz.race.controls", (c.drawn or 0) - before)
  prof_exit("viz.race")
  return lines
end

function RC.row(c, x, y, w, h, pace, run, top, col_pace, col_run, col_lead, a)
  if w < 2 or top <= 0 then return x, x end
  prof_enter("viz.race")
  local before = c.drawn or 0
  local alpha = a or 1
  local ly = y + math_floor((h - LANE_H) / 2)
  local ry = y + math_floor((h - RUN_H) / 2)
  local px = reach(pace, top, w)
  local rx = reach(run, top, w)
  S.box(c, x, x + w, ly, LANE_H, C_GROUND, GROUND_A * alpha, 2)
  if px > 0 then
    S.box(c, x, x + px, ly, LANE_H, col_pace, PACE_A * alpha, 3)
    S.box(c, x + px - 1, x + px, ly - 1, LANE_H + 2, col_pace, MARK_A * alpha, 5)
  end
  if rx > 0 then
    local body = (rx < px) and rx or px
    if body > 0 then S.box(c, x, x + body, ry, RUN_H, col_run, RUN_A * alpha, 4) end
    if rx > body then S.box(c, x + body, x + rx, ry, RUN_H, col_lead, RUN_A * alpha, 4) end
  end
  bump("viz.race.renders")
  bump("viz.race.controls", (c.drawn or 0) - before)
  prof_exit("viz.race")
  return x + px, x + rx
end
