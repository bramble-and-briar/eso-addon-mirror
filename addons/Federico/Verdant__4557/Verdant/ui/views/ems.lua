Verdant = Verdant or {}
local Verdant = Verdant

Verdant.EmsView = {}
local M = Verdant.EmsView

local api = Verdant.zenimax.api
local zc = Verdant.zenimax.constants
local GetString = api.GetString
local TOPLEFT, BOTTOMLEFT = zc.TOPLEFT, zc.BOTTOMLEFT
local math_max, math_floor = math.max, math.floor
local string_format = string.format
local fmt_val = Verdant.Format.value

local Grid = Verdant.ChartGrid
local TIME_STRIP_H, draw_grid, hide_grid = Grid.TIME_STRIP_H, Grid.draw, Grid.hide
local Columns = Verdant.ChartColumns
local dec_cols, decimate = Columns.cols, Columns.decimate
local dec_rect, axis_span = Columns.rect, Columns.axis_span
local view_last_t, view_start_ms, scale_top = Columns.view_last_t, Columns.view_start_ms, Columns.scale_top
local hit_begin, hit_col = Verdant.ChartHit.begin, Verdant.ChartHit.col
local draw_markers, draw_ult_band = Verdant.ChartOverlay.markers, Verdant.ChartOverlay.ult_band
local level_lines = Verdant.ChartOverlay.level_lines

local LANE = { H = 24, GAP = 4, MIN_PLOT = 60, BASE_ALPHA = 0.35 }

local controls, hit_main, ult_inset
local C_EHPS, C_MPS, C_DMG, C_DMG_LABEL

function M.bind(t)
  controls, hit_main, ult_inset = t.controls, t.hit_main, t.ult_inset
  C_EHPS, C_MPS, C_DMG, C_DMG_LABEL = t.C_EHPS, t.C_MPS, t.C_DMG, t.C_DMG_LABEL
end

local function ems_of(s) return s.eHPS + s.MPS end
local function damage_of(s) return s.d or 0 end

local function render_view1()
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_dmg_fill:ReleaseAllObjects()
  controls.pool_dead:ReleaseAllObjects()
  controls.dmg_label:SetHidden(true)

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

  local room = ch - TIME_STRIP_H - ult_inset()

  local max_ems = 0
  local max_d   = 0
  local t_first, t_last = 0, 0
  for i = 1, n do
    local s = Verdant.TemporalBuffer.at(i)
    local ems = s.eHPS + s.MPS
    if ems > max_ems then max_ems = ems end
    if (s.d or 0) > max_d then max_d = s.d end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end
  if max_ems <= 0 then return end

  local m, num_cols, col_w, bar_gap = decimate(cw, true)
  max_ems = scale_top(max_ems, ems_of)
  max_d   = scale_top(max_d, damage_of)
  local lane = 0
  if max_d > 0 and room - LANE.H - LANE.GAP >= LANE.MIN_PLOT then lane = LANE.H + LANE.GAP end
  local ch_plot = math_max(4, room - lane)
  local lane_y  = TIME_STRIP_H + ch_plot + LANE.GAP
  t_last  = view_last_t()
  local span = axis_span(t_last - t_first)
  local t0x  = t_last - span
  draw_grid(controls.grid_ems, canvas, max_ems, span, true, ult_inset() + lane, view_start_ms())
  local bw = (dec_cols.bw or math_max(1, math_floor(col_w) - bar_gap))
  if lane > 0 then
    local base = controls.pool_dmg_fill:AcquireObject()
    base:ClearAnchors()
    base:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, 0, -(lane_y - 1))
    base:SetWidth(cw)
    base:SetHeight(1)
    base:SetColor(C_DMG.r, C_DMG.g, C_DMG.b, LANE.BASE_ALPHA)
    base:SetHidden(false)

    local label = controls.dmg_label
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, canvas, TOPLEFT, 2, ult_inset())
    label:SetColor(C_DMG_LABEL.r, C_DMG_LABEL.g, C_DMG_LABEL.b, C_DMG_LABEL.a)
    label:SetText(string_format(GetString(VERDANT_GRAPH_DMG_LANE), fmt_val(max_d)))
    label:SetHidden(false)
  end
  local capture = not Verdant.TemporalBuffer.is_recording()
  if capture then hit_begin(hit_main, m) end

  for i = 1, m do
    local s = dec_cols[i]
    local left, right = dec_rect(s.c, num_cols, cw)
    local x  = left
    if capture then hit_col(hit_main, i, left, right - left, s) end

    local ehps_h = math_max(0, math_floor(ch_plot * (s.e1 / max_ems) + 0.5))
    local mps_h  = math_max(0, math_floor(ch_plot * (s.m1 / max_ems) + 0.5))
    local d_h    = (lane > 0) and math_floor(LANE.H * (s.d / max_d) + 0.5) or 0

    if d_h > 0 then
      local df = controls.pool_dmg_fill:AcquireObject()
      df:ClearAnchors()
      df:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -lane_y)
      df:SetWidth(bw)
      df:SetHeight(d_h)
      df:SetColor(C_DMG.r, C_DMG.g, C_DMG.b, C_DMG.a)
      df:SetHidden(false)
    end

    if ehps_h > 0 then
      local te = controls.pool_ehps:AcquireObject()
      te:ClearAnchors()
      te:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -TIME_STRIP_H)
      te:SetWidth(bw)
      te:SetHeight(ehps_h)
      te:SetColor(C_EHPS.r, C_EHPS.g, C_EHPS.b, C_EHPS.a)
      te:SetHidden(false)
    end

    if mps_h > 0 then
      local tm = controls.pool_mps:AcquireObject()
      tm:ClearAnchors()
      tm:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(TIME_STRIP_H + ehps_h))
      tm:SetWidth(bw)
      tm:SetHeight(mps_h)
      tm:SetColor(C_MPS.r, C_MPS.g, C_MPS.b, C_MPS.a)
      tm:SetHidden(false)
    end
  end

  level_lines(max_ems, ch_plot)
  Verdant.FilmDead.draw_columns(controls.pool_dead, canvas, m, num_cols, cw, ult_inset(), ch - TIME_STRIP_H)
  draw_markers(controls.pool_marker_icon, canvas, t0x, span, 0, cw)
  draw_ult_band(controls.pool_ult, controls.pool_ult_icon, canvas, t0x, span, t_last)
end

M.LANE   = LANE
M.render = render_view1
