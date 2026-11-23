Verdant = Verdant or {}
local Verdant = Verdant

Verdant.FilmDead = {}
local M = Verdant.FilmDead

local zc = Verdant.zenimax.constants
local TOPLEFT = zc.TOPLEFT
local math_floor = math.floor

local C_DEAD = { r = 0.62, g = 0.62, b = 0.66, a = 0.17 }
local spans = Verdant.TemporalBuffer.dead_spans

local function box(pool, canvas, x0, x1, y0, y1)
  local b = pool:AcquireObject()
  b:ClearAnchors()
  b:SetAnchor(TOPLEFT, canvas, TOPLEFT, x0, y0)
  b:SetDimensions(x1 - x0, y1 - y0)
  b:SetColor(C_DEAD.r, C_DEAD.g, C_DEAD.b, C_DEAD.a)
  b:SetHidden(false)
end

function M.draw_columns(pool, canvas, m, num_cols, cw, y0, y1)
  local dts, dn, dte = spans()
  local Columns = Verdant.ChartColumns
  local dec, rect = Columns.cols, Columns.rect
  local d = 1
  local run_x0, run_x1
  for i = 1, m do
    local col = dec[i]
    local t = col.t
    while d <= dn and dte[d] > 0 and dte[d] < t do d = d + 1 end
    local left, right = rect(col.c, num_cols, cw)
    if d <= dn and t >= dts[d] then
      if not run_x0 then run_x0 = left end
      run_x1 = right
    elseif run_x0 then
      box(pool, canvas, run_x0, run_x1, y0, y1)
      run_x0 = nil
    end
  end
  if run_x0 then box(pool, canvas, run_x0, run_x1, y0, y1) end
end

function M.draw_span(pool, canvas, t0, span, x, w, y0, y1)
  local dts, dn, dte = spans()
  for i = 1, dn do
    local b = (dte[i] > 0) and dte[i] or (t0 + span)
    local x0 = x + math_floor((dts[i] - t0) / span * w + 0.5)
    local x1 = x + math_floor((b - t0) / span * w + 0.5)
    if x1 > x0 then box(pool, canvas, x0, x1, y0, y1) end
  end
end

M.spans = spans
