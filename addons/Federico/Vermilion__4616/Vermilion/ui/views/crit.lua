Vermilion = Vermilion or {}
Vermilion.CritView = {}
local M = Vermilion.CritView

local BOTTOMLEFT = Vermilion.zenimax.constants.BOTTOMLEFT
local math_max, math_floor = math.max, math.floor

local Grid = Vermilion.ChartGrid
local hide_grid, draw_grid, TIME_STRIP_H = Grid.hide, Grid.draw, Grid.TIME_STRIP_H
local FC = Vermilion.FilmColumns
local dec_cols, decimate, dec_rect = FC.cols, FC.decimate, FC.rect
local axis_span = FC.axis_span
local FB = Vermilion.FilmBands
local draw_kills, draw_ult_band = FB.draw_kills, FB.draw_ult_band
local hit_begin, hit_col = Vermilion.ChartHit.begin, Vermilion.ChartHit.col

local controls, VIS, CHIP, top_inset, C_NONCRIT, C_CRIT

function M.bind(t)
  controls, VIS, CHIP, top_inset = t.controls, t.VIS, t.CHIP, t.top_inset
  C_NONCRIT, C_CRIT = t.C_NONCRIT, t.C_CRIT
end

local function edps_extent(n)
  local TB = Vermilion.TemporalBuffer
  local max_edps, max_sh, t_first, t_last = 0, 0, 0, 0
  for i = 1, n do
    local s = TB.at(i)
    if s.eDPS > max_edps then max_edps = s.eDPS end
    if s.ShDPS > max_sh then max_sh = s.ShDPS end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end
  return max_edps, (t_last - t_first), max_sh
end

local function render_by_crit()
  controls.pool_eos_segments:ReleaseAllObjects()
  controls.pool_edps:ReleaseAllObjects()
  controls.pool_shdps:ReleaseAllObjects()
  controls.pool_shield:ReleaseAllObjects()

  local n = Vermilion.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas = controls.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end
  local max_edps, span_ms, max_sh = edps_extent(n)
  if max_edps <= 0 then decimate(cw) hide_grid(controls.grid) return end
  VIS.shield.on, VIS.shield.max = true, max_sh
  local ch_plot = math_max(4, ch - TIME_STRIP_H - CHIP.H - top_inset())
  local m, num_cols, col_w, bar_gap = decimate(cw)
  max_edps = VIS.scale_top(max_edps, false)
  draw_grid(controls.grid, canvas, max_edps, axis_span(span_ms), nil, true, CHIP.H + top_inset())
  VIS.avg_line(false, max_edps, ch_plot)
  VIS.median_line(false, max_edps, ch_plot)
  local bwu = dec_cols.bw or math_max(1, math_floor(col_w) - bar_gap)
  local capture = not Vermilion.TemporalBuffer.is_recording()
  if capture then hit_begin(m) end

  for i = 1, m do
    local s = dec_cols[i]
    local left, right = dec_rect(s.c, num_cols, cw)
    local x         = left
    local bw        = bwu
    if capture then hit_col(i, left, right - left, s) end
    local noncrit_h = math_max(0, math_floor(ch_plot * (s.noncrit / max_edps) + 0.5))
    local crit_h    = math_max(0, math_floor(ch_plot * (s.crit    / max_edps) + 0.5))

    if noncrit_h > 0 then
      local tn = controls.pool_edps:AcquireObject()
      tn:ClearAnchors()
      tn:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -TIME_STRIP_H)
      tn:SetWidth(bw)
      tn:SetHeight(noncrit_h)
      tn:SetColor(C_NONCRIT.r, C_NONCRIT.g, C_NONCRIT.b, C_NONCRIT.a)
      tn:SetHidden(false)
    end

    if crit_h > 0 then
      local tc = controls.pool_shdps:AcquireObject()
      tc:ClearAnchors()
      tc:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(TIME_STRIP_H + noncrit_h))
      tc:SetWidth(bw)
      tc:SetHeight(crit_h)
      tc:SetColor(C_CRIT.r, C_CRIT.g, C_CRIT.b, C_CRIT.a)
      tc:SetHidden(false)
    end
  end

  draw_ult_band(span_ms, n)
  draw_kills(span_ms, n)
  FB.draw_dead(m, num_cols, cw, CHIP.H + top_inset(), ch - TIME_STRIP_H)
end

M.render = render_by_crit
