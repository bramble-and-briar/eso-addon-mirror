Vermilion = Vermilion or {}
Vermilion.FilmColumns = {}
local M = Vermilion.FilmColumns

local api = Vermilion.zenimax.api
local math_floor = math.floor
local math_ceil = math.ceil

local MIN_COL_PX = 6
local cols = { denom = 1, first = 1, last = 0 }
local canvas_ref = nil

M.cols = cols

function M.bind(canvas) canvas_ref = canvas end

function M.grid_geometry(cw, denom, sc, base)
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

local function live_samples()
  return math_floor(Vermilion.Constants.TEMPORAL.LIVE_WINDOW_S * 1000 / Vermilion.TemporalBuffer.period())
end

function M.decimate(cw)
  local TB = Vermilion.TemporalBuffer
  local W = Vermilion.FilmWindow
  local n = TB.count()
  local recording = TB.is_recording()
  local first, denom = W.range(n, TB.capacity(), recording, live_samples())
  local grid = cols.grid
  if grid == nil then grid = (Vermilion.Constants.PIXEL_GRID ~= false) end
  local sc = 1
  if grid then
    sc = api.GetUIGlobalScale and api.GetUIGlobalScale() or 1
    if not sc or sc <= 0 then sc = 1 end
  end
  local stride = nil
  local geo_denom = denom
  if W.is_zoomed() and not recording then
    stride = math_ceil(denom / max_columns(cw, sc))
    if stride < 1 then stride = 1 end
    first = 1 + math_floor((first - 1) / stride) * stride
    geo_denom = math_ceil(denom / stride)
  end
  local last = first + denom - 1
  if last > n then last = n end
  cols.denom, cols.first, cols.last = denom, first, last
  local num_cols
  if grid then
    local base = canvas_ref and canvas_ref:GetLeft() or 0
    local nc, P, x0, bw, base_p = M.grid_geometry(cw, geo_denom, sc, base)
    num_cols = nc
    cols.pitch, cols.x0, cols.scale, cols.base, cols.base_p, cols.bw = P, x0, sc, base, base_p, bw
  else
    local max_cols = math_floor(cw / MIN_COL_PX)
    if max_cols < 1 then max_cols = 1 end
    local per = math_ceil(geo_denom / max_cols)
    if per < 1 then per = 1 end
    num_cols = math_ceil(geo_denom / per)
    if num_cols < 1 then num_cols = 1 end
    cols.pitch, cols.bw = nil, nil
  end
  local offset = denom - last
  local stride_base = stride and math_floor((first - 1) / stride) or 0
  local m, cur_c = 0, -1
  local col
  for i = first, last do
    local s = TB.at(i)
    local c
    if stride then
      c = math_floor((i - 1) / stride) - stride_base
    else
      c = math_floor((offset + i - 1) * num_cols / denom)
    end
    local eos = s.eDPS + s.ShDPS
    if c ~= cur_c then
      m = m + 1
      col = cols[m]
      if not col then col = {}; cols[m] = col end
      col.c = c; col.t = s.t
      col.eos_peak = eos;    col.eDPS = s.eDPS; col.ShDPS = s.ShDPS
      col.eos_groups = s.eos_groups; col.eos_abilities = s.eos_abilities
      col.edps_peak = s.eDPS; col.noncrit = s.noncrit; col.crit = s.crit
      col.dtype_groups = s.dtype_groups; col.dtype_abilities = s.dtype_abilities
      col.shield_abilities = s.shield_abilities
      cur_c = c
    else
      if eos > col.eos_peak then
        col.eos_peak = eos; col.eDPS = s.eDPS; col.ShDPS = s.ShDPS
        col.eos_groups = s.eos_groups; col.eos_abilities = s.eos_abilities
        col.shield_abilities = s.shield_abilities
        col.dtype_groups = s.dtype_groups; col.dtype_abilities = s.dtype_abilities
      end
      if s.eDPS > col.edps_peak then
        col.edps_peak = s.eDPS; col.noncrit = s.noncrit; col.crit = s.crit
      end
      col.t = s.t
    end
  end
  local col_w = cols.pitch and (cols.pitch / cols.scale) or (cw / num_cols)
  local bar_gap = (col_w > 3) and 1 or 0
  return m, num_cols, col_w, bar_gap
end

function M.rect(c, num_cols, cw)
  local P = cols.pitch
  if P then
    local sc = cols.scale
    local left_p = cols.base_p + cols.x0 + c * P
    local left = left_p / sc - cols.base
    return left, left + P / sc
  end
  local left = math_floor(c * cw / num_cols + 0.5)
  local right = math_floor((c + 1) * cw / num_cols + 0.5)
  return left, right
end

function M.axis_span(span_ms)
  local visible = cols.last - cols.first + 1
  if visible < 2 then return span_ms end
  local TB = Vermilion.TemporalBuffer
  local view_span = TB.at(cols.last).t - TB.at(cols.first).t
  if visible == cols.denom then return view_span end
  return view_span * cols.denom / (visible - 1)
end

function M.view_last_t()
  return Vermilion.TemporalBuffer.at(cols.last).t
end

function M.view_start_ms()
  local TB = Vermilion.TemporalBuffer
  return TB.at(cols.first).t - TB.at(1).t
end

function M.window_extent(n)
  local TB = Vermilion.TemporalBuffer
  local max_eos, max_sh, t_first, t_last = 0, 0, 0, 0
  for i = 1, n do
    local s = TB.at(i)
    local eos = s.eDPS + s.ShDPS
    if eos > max_eos then max_eos = eos end
    if s.ShDPS > max_sh then max_sh = s.ShDPS end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end
  return max_eos, (t_last - t_first), max_sh
end

function M.visible_peak(with_shield)
  local TB = Vermilion.TemporalBuffer
  local top = 0
  for i = cols.first, cols.last do
    local s = TB.at(i)
    local v = with_shield and (s.eDPS + s.ShDPS) or s.eDPS
    if v > top then top = v end
  end
  return top
end

function M.samples_in(t0, span, n)
  local TB = Vermilion.TemporalBuffer
  local t1 = t0 + span
  local first, last = nil, 0
  for i = 1, n do
    local t = TB.at(i).t
    if t >= t0 then
      if t > t1 then break end
      if not first then first = i end
      last = i
    end
  end
  return first or 1, last
end
