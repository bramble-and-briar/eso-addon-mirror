Verdant = Verdant or {}
local Verdant = Verdant

Verdant.OverhealView = {}
local M = Verdant.OverhealView

local zc = Verdant.zenimax.constants
local TOPRIGHT, BOTTOMLEFT = zc.TOPRIGHT, zc.BOTTOMLEFT
local math_max, math_floor = math.max, math.floor

local Grid = Verdant.ChartGrid
local TIME_STRIP_H, draw_grid, hide_grid = Grid.TIME_STRIP_H, Grid.draw, Grid.hide
local Columns = Verdant.ChartColumns
local dec_cols, decimate = Columns.cols, Columns.decimate
local dec_rect, axis_span = Columns.rect, Columns.axis_span
local view_last_t, view_start_ms, scale_top = Columns.view_last_t, Columns.view_start_ms, Columns.scale_top
local hit_begin, hit_col = Verdant.ChartHit.begin, Verdant.ChartHit.col
local draw_markers, draw_ult_band = Verdant.ChartOverlay.markers, Verdant.ChartOverlay.ult_band

local controls, hit_main, ult_inset
local C_EHPS, C_OVERHEAL

function M.bind(t)
  controls, hit_main, ult_inset = t.controls, t.hit_main, t.ult_inset
  C_EHPS, C_OVERHEAL = t.C_EHPS, t.C_OVERHEAL
end

local function total_of(s) return s.eHPS + (s.o or 0) end

local function render_view_oh()
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_dead:ReleaseAllObjects()

  local n = Verdant.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid_ems)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas  = controls.canvas
  local cw      = canvas:GetWidth()
  local ch      = canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end
  local ch_plot = math_max(4, ch - TIME_STRIP_H - ult_inset())

  local max_tot = 0
  local t_first, t_last = 0, 0
  for i = 1, n do
    local s = Verdant.TemporalBuffer.at(i)
    local tot = s.eHPS + (s.o or 0)
    if tot > max_tot then max_tot = tot end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end
  if max_tot <= 0 then
    hide_grid(controls.grid_ems)
    return
  end

  local m, num_cols, col_w, bar_gap = decimate(cw, true)
  max_tot = scale_top(max_tot, total_of)
  t_last  = view_last_t()
  local span = axis_span(t_last - t_first)
  local t0x  = t_last - span
  draw_grid(controls.grid_ems, canvas, max_tot, span, true, ult_inset(), view_start_ms())
  if controls.oh_legend then
    controls.oh_legend:ClearAnchors()
    controls.oh_legend:SetAnchor(TOPRIGHT, canvas, TOPRIGHT, -2, 2 + ult_inset())
    controls.oh_legend:SetHidden(false)
  end

  local bw = (dec_cols.bw or math_max(1, math_floor(col_w) - bar_gap))
  local capture = not Verdant.TemporalBuffer.is_recording()
  if capture then hit_begin(hit_main, m) end

  for i = 1, m do
    local s = dec_cols[i]
    local left, right = dec_rect(s.c, num_cols, cw)
    local x  = left
    if capture then hit_col(hit_main, i, left, right - left, s) end
    local eff_h = math_max(0, math_floor(ch_plot * (s.eHPS / max_tot) + 0.5))
    local oh_h  = math_max(0, math_floor(ch_plot * ((s.oh or 0) / max_tot) + 0.5))

    if eff_h > 0 then
      local te = controls.pool_ehps:AcquireObject()
      te:ClearAnchors()
      te:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -TIME_STRIP_H)
      te:SetWidth(bw)
      te:SetHeight(eff_h)
      te:SetColor(C_EHPS.r, C_EHPS.g, C_EHPS.b, C_EHPS.a)
      te:SetHidden(false)
    end

    if oh_h > 0 then
      local to = controls.pool_mps:AcquireObject()
      to:ClearAnchors()
      to:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(TIME_STRIP_H + eff_h))
      to:SetWidth(bw)
      to:SetHeight(oh_h)
      to:SetColor(C_OVERHEAL.r, C_OVERHEAL.g, C_OVERHEAL.b, C_OVERHEAL.a)
      to:SetHidden(false)
    end
  end

  Verdant.FilmDead.draw_columns(controls.pool_dead, canvas, m, num_cols, cw, ult_inset(), ch - TIME_STRIP_H)
  draw_markers(controls.pool_marker_icon, canvas, t0x, span, 0, cw)
  draw_ult_band(controls.pool_ult, controls.pool_ult_icon, canvas, t0x, span, t_last)
end

M.render = render_view_oh
