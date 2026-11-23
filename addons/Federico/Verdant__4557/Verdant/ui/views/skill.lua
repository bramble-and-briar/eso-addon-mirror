Verdant = Verdant or {}
local Verdant = Verdant

Verdant.SkillView = {}
local M = Verdant.SkillView

local api = Verdant.zenimax.api
local zc = Verdant.zenimax.constants
local GetString = api.GetString
local TOPLEFT, BOTTOMLEFT = zc.TOPLEFT, zc.BOTTOMLEFT
local math_max, math_floor = math.max, math.floor
local string_format = string.format

local Grid = Verdant.ChartGrid
local TIME_STRIP_H, draw_grid, hide_grid = Grid.TIME_STRIP_H, Grid.draw, Grid.hide
local Columns = Verdant.ChartColumns
local dec_cols, decimate = Columns.cols, Columns.decimate
local dec_rect, axis_span = Columns.rect, Columns.axis_span
local view_last_t, view_start_ms, scale_top = Columns.view_last_t, Columns.view_start_ms, Columns.scale_top
local hit_begin, hit_col = Verdant.ChartHit.begin, Verdant.ChartHit.col
local draw_markers, draw_ult_band = Verdant.ChartOverlay.markers, Verdant.ChartOverlay.ult_band

local LAY = { LEGEND_H = 14, LEGEND_MIN_ROOM = 120, GAP = 6, MIN_PLOT = 24, SHIELD_SHARE = 0.30 }
local CHIP = { SWATCH = 8, SWATCH_Y = 3, PAD = 4, GAP = 12, TITLE_GAP = 10, MORE_W = 24, LEFT = 2 }
local C_TEXT = { r = 0.82, g = 0.85, b = 0.90, a = 0.92 }
local DIM_ALPHA = 0.35

local controls, STATE, hit_main, ult_inset, legend
local C_DIM_BIAS, C_HEAL_TITLE, C_SHIELD_TITLE

function M.bind(t)
  controls, STATE, hit_main, ult_inset, legend = t.controls, t.STATE, t.hit_main, t.ult_inset, t.skill_legend
  C_DIM_BIAS, C_HEAL_TITLE, C_SHIELD_TITLE = t.C_DIM_BIAS, t.C_HEAL_TITLE, t.C_SHIELD_TITLE
end

local function new_tally()
  return { n = 0, total = 0, key = {}, amt = {}, r = {}, g = {}, b = {}, at = {}, order = {} }
end
local heal_tally, shield_tally = new_tally(), new_tally()

local function tally_reset(t)
  for i = 1, t.n do t.at[t.key[i]] = nil end
  t.n, t.total = 0, 0
end

local function tally_add(t, groups, rate)
  for gi = 1, groups.count do
    local grp = groups[gi]
    local i = t.at[grp.key]
    if not i then
      i = t.n + 1
      t.n = i
      t.at[grp.key] = i
      t.key[i], t.amt[i], t.r[i], t.g[i], t.b[i] = grp.key, 0, grp.r, grp.g, grp.b
    end
    local amount = grp.share * rate
    t.amt[i] = t.amt[i] + amount
    t.total = t.total + amount
  end
end

local function tally_sort(t)
  local order, amt = t.order, t.amt
  for i = 1, t.n do order[i] = i end
  for i = 2, t.n do
    local v = order[i]
    local j = i - 1
    while j >= 1 and amt[order[j]] < amt[v] do
      order[j + 1] = order[j]
      j = j - 1
    end
    order[j + 1] = v
  end
end

local function share_text(share)
  local pct = math_floor(share * 100 + 0.5)
  if pct < 1 then return "<1%" end
  return pct .. "%"
end

local text_width = Verdant.Format.text_width

local function place_label(label, x, y, c, alpha)
  local w = text_width(label, label:GetText())
  label:ClearAnchors()
  label:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x, y)
  label:SetDimensions(w, LAY.LEGEND_H)
  label:SetColor(c.r, c.g, c.b, alpha)
  label:SetHidden(false)
  return w
end

local function draw_legend(t, title, title_c, y, cw)
  local hk = STATE.hover_key
  local head = controls.pool_legend_lbl:AcquireObject()
  head:SetText(GetString(title))
  local x = CHIP.LEFT + place_label(head, CHIP.LEFT, y, title_c, 0.80) + CHIP.TITLE_GAP
  for k = 1, t.n do
    local i = t.order[k]
    local key = t.key[i]
    local text = share_text(t.amt[i] / t.total)
    local label = controls.pool_legend_lbl:AcquireObject()
    label:SetText(text)
    local tw = text_width(label, text)
    local w = CHIP.SWATCH + CHIP.PAD + tw
    local reserve = (k < t.n) and CHIP.MORE_W or 0
    if x + w + reserve > cw then
      label:SetText(string_format("+%d", t.n - k + 1))
      place_label(label, x, y, C_TEXT, DIM_ALPHA + 0.25)
      return
    end
    local dim = hk ~= nil and hk ~= key
    local swatch = controls.pool_legend_sw:AcquireObject()
    swatch:ClearAnchors()
    swatch:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x, y + CHIP.SWATCH_Y)
    swatch:SetDimensions(CHIP.SWATCH, CHIP.SWATCH)
    swatch:SetColor(t.r[i], t.g[i], t.b[i], dim and DIM_ALPHA or 1)
    swatch:SetHidden(false)
    place_label(label, x + CHIP.SWATCH + CHIP.PAD, y, C_TEXT, dim and DIM_ALPHA or C_TEXT.a)
    local n = legend.n + 1
    legend.n = n
    legend.x0[n], legend.x1[n], legend.y0[n], legend.y1[n], legend.key[n] = x, x + w, y, y + LAY.LEGEND_H, key
    x = x + w + CHIP.GAP
  end
end

local function stack(col, x, bw, floor, plot_h, frac, groups, total, unit, hk)
  local col_h = math_max(0, math_floor(plot_h * frac + 0.5))
  local y_off = 0
  for gi = 1, groups.count do
    local grp   = groups[gi]
    local seg_h = math_max(1, math_floor(col_h * grp.share + 0.5))
    local t = controls.pool_skill:AcquireObject()
    t:ClearAnchors()
    t:SetAnchor(BOTTOMLEFT, controls.canvas, BOTTOMLEFT, x, -(floor + y_off))
    t:SetWidth(bw)
    t:SetHeight(seg_h)
    if hk ~= nil and grp.key ~= hk then
      t:SetColor(grp.r * 0.30 + C_DIM_BIAS, grp.g * 0.30 + C_DIM_BIAS, grp.b * 0.30 + C_DIM_BIAS, 0.28)
    else
      t:SetColor(grp.r, grp.g, grp.b, grp.a)
    end
    t:SetHidden(false)

    if col then
      local nb   = col.nb + 1
      local band = col.bands[nb]
      if not band then band = {}; col.bands[nb] = band end
      band.key   = grp.key
      band.lo    = floor + y_off
      band.hi    = floor + y_off + seg_h
      band.share = grp.share
      band.total = total
      band.unit  = unit
      band.r = grp.r; band.g = grp.g; band.b = grp.b
      col.nb = nb
    end

    y_off = y_off + seg_h
  end
end

local function ehps_of(s) return s.eHPS end
local function mps_of(s) return s.MPS end

local function render_view2()
  controls.pool_skill:ReleaseAllObjects()
  controls.pool_dead:ReleaseAllObjects()
  controls.pool_legend_sw:ReleaseAllObjects()
  controls.pool_legend_lbl:ReleaseAllObjects()
  legend.n = 0

  local TB = Verdant.TemporalBuffer
  local n = TB.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid_ems)
    hide_grid(controls.grid_skill)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas = controls.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end

  local max_ehps, max_mps = 0, 0
  local t_first, t_last   = 0, 0
  for i = 1, n do
    local s = TB.at(i)
    if s.eHPS > max_ehps then max_ehps = s.eHPS end
    if s.MPS  > max_mps  then max_mps  = s.MPS  end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end

  local m, num_cols, col_w, bar_gap = decimate(cw, true)
  local has_shield = max_mps > 0
  max_ehps = scale_top(max_ehps, ehps_of)
  max_mps  = scale_top(max_mps, mps_of)
  t_last   = view_last_t()
  local span = axis_span(t_last - t_first)
  local t0x  = t_last - span

  local inset = ult_inset()
  local room  = ch - TIME_STRIP_H - inset
  local leg   = (room >= LAY.LEGEND_MIN_ROOM) and LAY.LEGEND_H or 0
  local top_h, bot_h = math_max(4, room - leg), 0
  if has_shield then
    local avail = room - 2 * leg - LAY.GAP
    local want  = math_max(LAY.MIN_PLOT, math_floor(avail * LAY.SHIELD_SHARE))
    if avail - want >= LAY.MIN_PLOT then
      bot_h = want
      top_h = avail - want
    end
  end
  local top_floor = (bot_h > 0) and (TIME_STRIP_H + bot_h + leg + LAY.GAP) or TIME_STRIP_H

  draw_grid(controls.grid_ems, canvas, max_ehps, span, true, inset + leg, view_start_ms(), top_floor)
  if bot_h > 0 then
    draw_grid(controls.grid_skill, canvas, max_mps, 0, nil, ch - TIME_STRIP_H - bot_h, nil, TIME_STRIP_H)
  else
    hide_grid(controls.grid_skill)
  end

  tally_reset(heal_tally)
  tally_reset(shield_tally)
  for i = dec_cols.first, dec_cols.last do
    local s = TB.at(i)
    tally_add(heal_tally, s.ehps_groups, s.eHPS)
    tally_add(shield_tally, s.mps_groups, s.MPS)
  end

  local bw = dec_cols.bw or math_max(1, math_floor(col_w) - bar_gap)
  local capture = not TB.is_recording()
  local hk = STATE.hover_key
  if capture then hit_begin(hit_main, m) end
  for i = 1, m do
    local s = dec_cols[i]
    local left, right = dec_rect(s.c, num_cols, cw)
    local col = capture and hit_col(hit_main, i, left, right - left, s) or nil
    if max_ehps > 0 then
      stack(col, left, bw, top_floor, top_h, s.eHPS / max_ehps, s.ehps_groups, s.eHPS, "HPS", hk)
    end
    if bot_h > 0 then
      stack(col, left, bw, TIME_STRIP_H, bot_h, s.MPS / max_mps, s.mps_groups, s.MPS, "MPS", hk)
    end
  end

  Verdant.FilmDead.draw_columns(controls.pool_dead, canvas, m, num_cols, cw, inset, ch - TIME_STRIP_H)
  if leg > 0 then
    tally_sort(heal_tally)
    draw_legend(heal_tally, VERDANT_SKILL_HEALING, C_HEAL_TITLE, inset, cw)
    if bot_h > 0 then
      tally_sort(shield_tally)
      draw_legend(shield_tally, VERDANT_SKILL_SHIELDS, C_SHIELD_TITLE, ch - TIME_STRIP_H - bot_h - leg, cw)
    end
  end
  draw_markers(controls.pool_marker_icon, canvas, t0x, span, 0, cw)
  draw_ult_band(controls.pool_ult, controls.pool_ult_icon, canvas, t0x, span, t_last)
end

function M.legend_at(rel_x, rel_y)
  for i = 1, legend.n do
    if rel_x >= legend.x0[i] and rel_x <= legend.x1[i] and rel_y >= legend.y0[i] and rel_y <= legend.y1[i] then
      return legend.key[i]
    end
  end
  return nil
end

M.LAY    = LAY
M.CHIP   = CHIP
M.render = render_view2
