Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ChartColumns = {}
local M = Verdant.ChartColumns

local api        = Verdant.zenimax.api
local math_floor = math.floor
local math_ceil  = math.ceil

local controls

function M.bind(shared)
  controls = shared.controls
end

local MIN_COL_PX = 6
local dec_cols   = { denom = 1, first = 1, last = 0 }

local function grid_geometry(cw, denom, sc, base)
  local cw_p = math_floor(cw * sc)
  local minp = math_floor(MIN_COL_PX * sc + 0.5)
  if minp < 2 then minp = 2 end
  local n = math_floor(cw_p / minp)
  if n < 1 then n = 1 end
  if n > denom then n = denom end
  local P = math_floor(cw_p / n)
  if P < 1 then P = 1 end
  local x0 = cw_p - n * P
  local gap = (P > 3) and 1 or 0
  return n, P, x0, (P - gap) / sc, math_floor(base * sc + 0.5)
end

local function max_columns(cw, sc)
  local minp = math_floor(MIN_COL_PX * sc + 0.5)
  if minp < 2 then minp = 2 end
  local k = math_floor(math_floor(cw * sc) / minp)
  if k < 1 then k = 1 end
  return k
end

local function decimate(cw, zoomable)
  local TB        = Verdant.TemporalBuffer
  local W         = Verdant.FilmWindow
  local n         = TB.count()
  local recording = TB.is_recording()
  local live      = math_floor(Verdant.Constants.TEMPORAL.LIVE_WINDOW_S * 1000 / TB.period())
  local first, denom = W.range(n, recording, live, zoomable)
  local grid = dec_cols.grid
  if grid == nil then grid = (Verdant.Constants.PIXEL_GRID ~= false) end
  local sc = 1
  if grid then
    sc = api.GetUIGlobalScale and api.GetUIGlobalScale() or 1
    if not sc or sc <= 0 then sc = 1 end
  end
  local zoomed = (zoomable and W.is_zoomed()) or false
  local stride, geo_denom = nil, denom
  if zoomed then
    stride = math_ceil(denom / max_columns(cw, sc))
    first = 1 + math_floor((first - 1) / stride) * stride
    geo_denom = math_ceil(denom / stride)
  end
  local last = first + denom - 1
  if last > n then last = n end
  dec_cols.denom, dec_cols.first, dec_cols.last, dec_cols.zoomed = denom, first, last, zoomed
  local num_cols
  if grid then
    local base = controls.canvas and controls.canvas:GetLeft() or 0
    local n, P, x0, bw, base_p = grid_geometry(cw, geo_denom, sc, base)
    num_cols = n
    dec_cols.pitch  = P
    dec_cols.x0     = x0
    dec_cols.scale  = sc
    dec_cols.base   = base
    dec_cols.base_p = base_p
    dec_cols.bw     = bw
  else
    local max_cols = math_floor(cw / MIN_COL_PX)
    if max_cols < 1 then max_cols = 1 end
    local per = math_ceil(geo_denom / max_cols)
    if per < 1 then per = 1 end
    num_cols = math_ceil(geo_denom / per)
    if num_cols < 1 then num_cols = 1 end
    dec_cols.pitch = nil
    dec_cols.bw    = nil
  end
  local offset      = denom - last
  local stride_base = stride and math_floor((first - 1) / stride) or 0
  local m, cur_c    = 0, -1
  local col
  for i = first, last do
    local s = TB.at(i)
    local c
    if stride then
      c = math_floor((i - 1) / stride) - stride_base
    else
      c = math_floor((offset + i - 1) * num_cols / denom)
    end
    local ems = s.eHPS + s.MPS
    if c ~= cur_c then
      m = m + 1
      col = dec_cols[m]
      if not col then col = {}; dec_cols[m] = col end
      col.c = c; col.t = s.t
      col.ems_peak = ems; col.e1 = s.eHPS; col.m1 = s.MPS
      col.eHPS = s.eHPS; col.ehps_groups = s.ehps_groups; col.ehps_abilities = s.ehps_abilities
      col.noncrit = s.noncrit; col.crit = s.crit; col.oh = s.o or 0
      col.MPS = s.MPS; col.mps_groups = s.mps_groups; col.mps_abilities = s.mps_abilities
      col.d = s.d or 0
      col.rm, col.rs = s.rm, s.rs
      col.mag, col.sta = s.mag, s.sta
      col.mag_in, col.mag_out, col.sta_in, col.sta_out = s.mag_in, s.mag_out, s.sta_in, s.sta_out
      cur_c = c
    else
      if ems > col.ems_peak then col.ems_peak = ems; col.e1 = s.eHPS; col.m1 = s.MPS end
      if s.eHPS > col.eHPS then
        col.eHPS = s.eHPS; col.ehps_groups = s.ehps_groups; col.ehps_abilities = s.ehps_abilities
        col.noncrit = s.noncrit; col.crit = s.crit; col.oh = s.o or 0
      end
      if s.MPS > col.MPS then col.MPS = s.MPS; col.mps_groups = s.mps_groups; col.mps_abilities = s.mps_abilities end
      if (s.d or 0) > col.d then col.d = s.d end
      if s.rm + s.rs > col.rm + col.rs then col.rm, col.rs = s.rm, s.rs end
      if s.mag < col.mag then col.mag = s.mag end
      if s.sta < col.sta then col.sta = s.sta end
      col.mag_in, col.mag_out = col.mag_in + s.mag_in, col.mag_out + s.mag_out
      col.sta_in, col.sta_out = col.sta_in + s.sta_in, col.sta_out + s.sta_out
      col.t = s.t
    end
  end
  local col_w   = dec_cols.pitch and (dec_cols.pitch / dec_cols.scale) or (cw / num_cols)
  local bar_gap = (col_w > 3) and 1 or 0
  return m, num_cols, col_w, bar_gap
end

local function dec_rect(c, num_cols, cw)
  local P = dec_cols.pitch
  if P then
    local sc     = dec_cols.scale
    local left_p = dec_cols.base_p + dec_cols.x0 + c * P
    local left   = left_p / sc - dec_cols.base
    return left, left + P / sc
  end
  local left  = math_floor(c       * cw / num_cols + 0.5)
  local right = math_floor((c + 1) * cw / num_cols + 0.5)
  return left, right
end

local function axis_span(span_ms)
  local visible = dec_cols.last - dec_cols.first + 1
  if visible < 2 then return span_ms end
  local TB = Verdant.TemporalBuffer
  local view_span = TB.at(dec_cols.last).t - TB.at(dec_cols.first).t
  if visible == dec_cols.denom then return view_span end
  return view_span * dec_cols.denom / (visible - 1)
end

local function view_last_t()
  return Verdant.TemporalBuffer.at(dec_cols.last).t
end

local function view_start_ms()
  if not dec_cols.zoomed then return 0 end
  local TB = Verdant.TemporalBuffer
  return TB.at(dec_cols.first).t - TB.at(1).t
end

local function scale_top(whole, value)
  if not dec_cols.zoomed or not Verdant.Settings.zoom_local_scale() then return whole end
  local TB, top = Verdant.TemporalBuffer, 0
  for i = dec_cols.first, dec_cols.last do
    local v = value(TB.at(i))
    if v > top then top = v end
  end
  return (top > 0) and top or whole
end

M.MIN_COL_PX = MIN_COL_PX
M.view_last_t, M.view_start_ms, M.scale_top = view_last_t, view_start_ms, scale_top
M.cols       = dec_cols
M.geometry   = grid_geometry
M.decimate   = decimate
M.rect       = dec_rect
M.axis_span  = axis_span
