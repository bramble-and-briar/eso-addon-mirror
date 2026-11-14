Vermilion = Vermilion or {}
Vermilion.TypeView = {}
local M = Vermilion.TypeView

local BOTTOMLEFT = Vermilion.zenimax.constants.BOTTOMLEFT
local math_max, math_floor = math.max, math.floor

local Grid = Vermilion.ChartGrid
local hide_grid, draw_grid, TIME_STRIP_H = Grid.hide, Grid.draw, Grid.TIME_STRIP_H
local FC = Vermilion.FilmColumns
local dec_cols, decimate, dec_rect = FC.cols, FC.decimate, FC.rect
local axis_span, window_extent = FC.axis_span, FC.window_extent
local FB = Vermilion.FilmBands
local draw_kills, draw_ult_band = FB.draw_kills, FB.draw_ult_band
local hit_begin, hit_col = Vermilion.ChartHit.begin, Vermilion.ChartHit.col

local STATE, controls, VIS, CHIP, top_inset, C_DIM_BIAS

function M.bind(t)
  STATE, controls, VIS, CHIP, top_inset = t.STATE, t.controls, t.VIS, t.CHIP, t.top_inset
  C_DIM_BIAS = t.C_DIM_BIAS
end

local function render_by_type()
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
  local max_edps, span_ms, max_sh = window_extent(n)
  if max_edps <= 0 then decimate(cw) hide_grid(controls.grid) return end
  VIS.shield.on, VIS.shield.max = true, max_sh
  local ch_plot = math_max(4, ch - TIME_STRIP_H - CHIP.H - top_inset())
  local m, num_cols, col_w, bar_gap = decimate(cw)
  max_edps = VIS.scale_top(max_edps, true)
  draw_grid(controls.grid, canvas, max_edps, axis_span(span_ms), nil, true, CHIP.H + top_inset())
  VIS.avg_line(true, max_edps, ch_plot)
  VIS.median_line(true, max_edps, ch_plot)
  local bwu = dec_cols.bw or math_max(1, math_floor(col_w) - bar_gap)
  local capture = not Vermilion.TemporalBuffer.is_recording()
  local hk = STATE.hover_key
  if capture then hit_begin(m) end

  for i = 1, m do
    local s = dec_cols[i]
    local left, right = dec_rect(s.c, num_cols, cw)
    local x    = left
    local bw   = bwu
    local edps = s.eos_peak or 0
    local col_h = math_max(0, math_floor(ch_plot * (edps / max_edps) + 0.5))

    local col = capture and hit_col(i, left, right - left, s) or nil

    local y_off  = 0
    local groups = s.dtype_groups
    for g = 1, (groups and groups.count or 0) do
      local grp   = groups[g]
      local seg_h = math_max(1, math_floor(col_h * grp.share + 0.5))
      local t = controls.pool_eos_segments:AcquireObject()
      t:ClearAnchors()
      t:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(y_off + TIME_STRIP_H))
      t:SetWidth(bw)
      t:SetHeight(seg_h)
      if hk ~= nil and grp.key ~= hk then
        t:SetColor(grp.r * 0.30 + C_DIM_BIAS, grp.g * 0.30 + C_DIM_BIAS,
                   grp.b * 0.30 + C_DIM_BIAS, 0.28)
      else
        t:SetColor(grp.r, grp.g, grp.b, grp.a)
      end
      t:SetHidden(false)

      if capture then
        local nb   = col.nb + 1
        local band = col.bands[nb]
        if not band then band = {}; col.bands[nb] = band end
        band.key   = grp.key
        band.lo    = TIME_STRIP_H + y_off
        band.hi    = TIME_STRIP_H + y_off + seg_h
        band.share = grp.share
        band.eos   = edps
        band.r = grp.r; band.g = grp.g; band.b = grp.b
        col.nb = nb
      end

      y_off = y_off + seg_h
    end
  end

  draw_ult_band(span_ms, n)
  draw_kills(span_ms, n)
  FB.draw_dead(m, num_cols, cw, CHIP.H + top_inset(), ch - TIME_STRIP_H)
end

M.render = render_by_type
