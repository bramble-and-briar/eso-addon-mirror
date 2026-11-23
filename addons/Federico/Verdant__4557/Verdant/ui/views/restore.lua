Verdant = Verdant or {}
local Verdant = Verdant

Verdant.RestoreView = {}
local M = Verdant.RestoreView

local zc = Verdant.zenimax.constants
local BOTTOMLEFT, TOPLEFT, TOPRIGHT = zc.BOTTOMLEFT, zc.TOPLEFT, zc.TOPRIGHT
local TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT = zc.TEXT_ALIGN_LEFT, zc.TEXT_ALIGN_RIGHT
local math_max, math_min, math_floor = math.max, math.min, math.floor
local string_format = string.format
local GetString = Verdant.zenimax.api.GetString
local fmt_val = Verdant.Format.value

local Grid = Verdant.ChartGrid
local TIME_STRIP_H, draw_grid, hide_grid = Grid.TIME_STRIP_H, Grid.draw, Grid.hide
local Columns = Verdant.ChartColumns
local dec_cols, decimate = Columns.cols, Columns.decimate
local dec_rect, axis_span = Columns.rect, Columns.axis_span
local view_last_t, view_start_ms, scale_top = Columns.view_last_t, Columns.view_start_ms, Columns.scale_top
local hit_begin, hit_col = Verdant.ChartHit.begin, Verdant.ChartHit.col
local draw_markers, draw_ult_band = Verdant.ChartOverlay.markers, Verdant.ChartOverlay.ult_band

local controls, hit_main, ult_inset
local C_RMAG, C_RSTA

function M.bind(t)
  controls, hit_main, ult_inset = t.controls, t.hit_main, t.ult_inset
  C_RMAG, C_RSTA = t.C_RMAG, t.C_RSTA
end

local function total_of(s) return s.rm + s.rs end

local function bar(pool, canvas, x, y, w, h, c)
  local b = pool:AcquireObject()
  b:ClearAnchors()
  b:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -y)
  b:SetWidth(w)
  b:SetHeight(h)
  b:SetColor(c.r, c.g, c.b, c.a)
  b:SetHidden(false)
end

local PANEL = { MIN_VIEW = 560, SHARE = 0.34, MAX_W = 230, GAP = 10, PAD = 6, TITLE_H = 16, ROW_H = 13, BAR_H = 3,
                ROW_STEP = 19, LIST_GAP = 8, VAL_W = 70, MORE_W = 70, ICON = 16, ICON_GAP = 4 }
local SEC_AB, SEC_PL = 1, 2
local scroll, max_scroll = { 0, 0 }, { 0, 0 }
local sec_top = { 0, 0 }
local C_TITLE = { r = 0.70, g = 0.72, b = 0.76, a = 0.80 }
local C_ROW   = { r = 0.82, g = 0.85, b = 0.90, a = 0.92 }
local C_DIM   = { r = 0.62, g = 0.64, b = 0.68, a = 0.85 }

function M.side(view_w)
  if view_w < PANEL.MIN_VIEW or Verdant.TemporalBuffer.restore_log().n == 0 then return 0 end
  return math_min(PANEL.MAX_W, math_floor(view_w * PANEL.SHARE))
end

local function new_list() return { n = 0, key = {}, mag = {}, sta = {}, order = {}, slot = {}, id = {} } end
local by_ab, by_pl = new_list(), new_list()

local function list_clear(l)
  for i = 1, l.n do l.slot[l.key[i]] = nil end
  l.n = 0
end

local function list_add(l, key, mag, amount, id)
  local i = l.slot[key]
  if not i then
    i = l.n + 1
    l.n = i
    l.key[i], l.mag[i], l.sta[i], l.id[i] = key, 0, 0, id
    l.slot[key] = i
  end
  if mag then l.mag[i] = l.mag[i] + amount else l.sta[i] = l.sta[i] + amount end
end

local function list_sort(l)
  local o = l.order
  for i = 1, l.n do o[i] = i end
  for i = 2, l.n do
    local v = o[i]
    local tv = l.mag[v] + l.sta[v]
    local j = i - 1
    while j >= 1 and (l.mag[o[j]] + l.sta[o[j]]) < tv do
      o[j + 1] = o[j]
      j = j - 1
    end
    o[j + 1] = v
  end
end

local function gather(t_from, t_to)
  list_clear(by_ab)
  list_clear(by_pl)
  local rl = Verdant.TemporalBuffer.restore_log()
  local SC = Verdant.SkillColors
  for i = 1, rl.n do
    local t = rl.t[i]
    if t >= t_to then break end
    if t >= t_from then
      list_add(by_ab, SC.ability_name(rl.id[i]), rl.mag[i], rl.amt[i], rl.id[i])
      list_add(by_pl, rl.names[rl.who[i]], rl.mag[i], rl.amt[i])
    end
  end
  list_sort(by_ab)
  list_sort(by_pl)
end

local function panel_label(x, y, w, h, text, c, align)
  local l = controls.pool_sustain_lbl:AcquireObject()
  l:ClearAnchors()
  l:SetAnchor(TOPLEFT, controls.canvas, TOPRIGHT, x, y)
  l:SetDimensions(w, h)
  l:SetHorizontalAlignment(align)
  l:SetText(text)
  l:SetColor(c.r, c.g, c.b, c.a)
  l:SetHidden(false)
end

local function panel_icon(x, y, id)
  local ic = controls.pool_sustain_icon:AcquireObject()
  ic:ClearAnchors()
  ic:SetAnchor(TOPLEFT, controls.canvas, TOPRIGHT, x, y)
  ic:SetDimensions(PANEL.ICON, PANEL.ICON)
  ic:SetTexture(Verdant.SkillColors.ability_icon(id))
  ic:SetColor(1, 1, 1, 1)
  ic:SetHidden(false)
end

local function panel_bar(x, y, w, c)
  if w <= 0 then return end
  local b = controls.pool_sustain_bar:AcquireObject()
  b:ClearAnchors()
  b:SetAnchor(TOPLEFT, controls.canvas, TOPRIGHT, x, y)
  b:SetDimensions(w, PANEL.BAR_H)
  b:SetColor(c.r, c.g, c.b, c.a)
  b:SetHidden(false)
end

local function section(rel, x0, y0, x1, y1, surface)
  local p = controls.pool_section:AcquireObject()
  p:ClearAnchors()
  p:SetCenterColor(1, 1, 1, surface)
  p:SetAnchor(TOPLEFT, controls.canvas, rel, x0, y0)
  p:SetDimensions(x1 - x0, y1 - y0)
  p:SetHidden(false)
end

local function draw_list(l, sec, title, y0, y1, w, icons)
  section(TOPRIGHT, PANEL.GAP, y0, PANEL.GAP + w, y1, 1)
  sec_top[sec] = y0
  local x = PANEL.GAP + PANEL.PAD
  local iw = w - 2 * PANEL.PAD
  local y = y0 + PANEL.PAD
  panel_label(x, y, iw, PANEL.TITLE_H, GetString(title), C_TITLE, TEXT_ALIGN_LEFT)
  y = y + PANEL.TITLE_H
  local room = math_floor((y1 - PANEL.PAD - y) / PANEL.ROW_STEP)
  if room < 0 then room = 0 end
  local show = math_min(room, l.n)
  max_scroll[sec] = l.n - show
  if scroll[sec] > max_scroll[sec] then scroll[sec] = max_scroll[sec] end
  local off = scroll[sec]
  local rest = l.n - show - off
  if rest > 0 then
    panel_label(x + iw - PANEL.MORE_W, y0 + PANEL.PAD, PANEL.MORE_W, PANEL.TITLE_H,
      string_format(GetString(VERDANT_SUSTAIN_MORE), rest), C_DIM, TEXT_ALIGN_RIGHT)
  end
  if show == 0 then return end
  local total = 0
  for i = 1, l.n do total = total + l.mag[i] + l.sta[i] end
  local top = l.mag[l.order[1]] + l.sta[l.order[1]]
  local indent = icons and (PANEL.ICON + PANEL.ICON_GAP) or 0
  local bw = iw - indent
  for k = 1, show do
    local i = l.order[k + off]
    local amount = l.mag[i] + l.sta[i]
    if icons then panel_icon(x, y + 1, l.id[i]) end
    panel_label(x + indent, y, iw - PANEL.VAL_W - indent, PANEL.ROW_H, l.key[i], C_ROW, TEXT_ALIGN_LEFT)
    panel_label(x + iw - PANEL.VAL_W, y, PANEL.VAL_W, PANEL.ROW_H,
      string_format(GetString(VERDANT_SUSTAIN_ROW), fmt_val(amount), math_floor(amount / total * 100 + 0.5)), C_DIM, TEXT_ALIGN_RIGHT)
    local mag_w = math_floor(bw * l.mag[i] / top + 0.5)
    local sta_w = math_floor(bw * amount / top + 0.5) - mag_w
    panel_bar(x + indent, y + PANEL.ROW_H + 1, mag_w, C_RMAG)
    panel_bar(x + indent + mag_w, y + PANEL.ROW_H + 1, sta_w, C_RSTA)
    y = y + PANEL.ROW_STEP
  end
end

local function draw_panel(t_from, t_to, cw, ch)
  local side = M.side(controls.viewport:GetWidth())
  if side <= 0 then return end
  gather(t_from, t_to)
  local w = side - PANEL.GAP - 2
  local y_top, y_bot = ult_inset(), ch - TIME_STRIP_H
  local y_mid = y_top + math_floor((y_bot - y_top - PANEL.LIST_GAP) / 2)
  section(TOPLEFT, 0, y_top, cw, y_bot, 0)
  draw_list(by_ab, SEC_AB, VERDANT_SUSTAIN_BY_ABILITY, y_top, y_mid, w, true)
  draw_list(by_pl, SEC_PL, VERDANT_SUSTAIN_BY_PLAYER, y_mid + PANEL.LIST_GAP, y_bot, w)
  local hit = controls.side_hit
  hit:ClearAnchors()
  hit:SetAnchor(TOPLEFT, controls.canvas, TOPRIGHT, PANEL.GAP, y_top)
  hit:SetDimensions(w, y_bot - y_top)
  hit:SetHidden(false)
end

function M.scroll(dir, rel_y)
  local sec = (rel_y >= sec_top[SEC_PL]) and SEC_PL or SEC_AB
  local nxt = scroll[sec] + dir
  if nxt > max_scroll[sec] then nxt = max_scroll[sec] end
  if nxt < 0 then nxt = 0 end
  if nxt == scroll[sec] then return false end
  scroll[sec] = nxt
  return true
end

function M.reset_scroll() scroll[SEC_AB], scroll[SEC_PL] = 0, 0 end

M.PANEL = PANEL

local function render_view_restore()
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_dead:ReleaseAllObjects()
  controls.pool_sustain_lbl:ReleaseAllObjects()
  controls.pool_sustain_bar:ReleaseAllObjects()
  controls.pool_sustain_icon:ReleaseAllObjects()

  local TB = Verdant.TemporalBuffer
  local n = TB.count()
  local top, t_first = 0, 0
  for i = 1, n do
    local s = TB.at(i)
    local tot = s.rm + s.rs
    if tot > top then top = tot end
    if i == 1 then t_first = s.t end
  end
  controls.no_data:SetHidden(top > 0)
  if top <= 0 then
    hide_grid(controls.grid_ems)
    return
  end

  local canvas = controls.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end
  local ch_plot = math_max(4, ch - TIME_STRIP_H - ult_inset())

  local m, num_cols, col_w, bar_gap = decimate(cw, true)
  top = scale_top(top, total_of)
  local t_last = view_last_t()
  local span = axis_span(t_last - t_first)
  local t0x  = t_last - span
  draw_grid(controls.grid_ems, canvas, top, span, true, ult_inset(), view_start_ms())

  local bw = dec_cols.bw or math_max(1, math_floor(col_w) - bar_gap)
  local capture = not TB.is_recording()
  if capture then hit_begin(hit_main, m) end

  for i = 1, m do
    local s = dec_cols[i]
    local left, right = dec_rect(s.c, num_cols, cw)
    if capture then hit_col(hit_main, i, left, right - left, s) end
    local mag_h = math_floor(ch_plot * (s.rm / top) + 0.5)
    local sta_h = math_floor(ch_plot * (s.rs / top) + 0.5)
    if mag_h > 0 then bar(controls.pool_ehps, canvas, left, TIME_STRIP_H, bw, mag_h, C_RMAG) end
    if sta_h > 0 then bar(controls.pool_mps, canvas, left, TIME_STRIP_H + mag_h, bw, sta_h, C_RSTA) end
  end

  Verdant.FilmDead.draw_columns(controls.pool_dead, canvas, m, num_cols, cw, ult_inset(), ch - TIME_STRIP_H)
  draw_markers(controls.pool_marker_icon, canvas, t0x, span, 0, cw)
  draw_ult_band(controls.pool_ult, controls.pool_ult_icon, canvas, t0x, span, t_last)
  draw_panel(TB.at(dec_cols.first).t - TB.period(), TB.at(dec_cols.last).t, cw, ch)
end

M.render = render_view_restore
