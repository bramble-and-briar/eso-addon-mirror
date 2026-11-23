Verdant = Verdant or {}
local Verdant = Verdant

Verdant.BuffsView = {}
local M = Verdant.BuffsView

local api = Verdant.zenimax.api
local zc  = Verdant.zenimax.constants
local GetGameTimeMilliseconds = api.GetGameTimeMilliseconds
local GetString               = api.GetString
local TOPLEFT = zc.TOPLEFT
local TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_LEFT, zc.TEXT_ALIGN_RIGHT, zc.TEXT_ALIGN_CENTER
local TEXT_WRAP_MODE_ELLIPSIS = zc.TEXT_WRAP_MODE_ELLIPSIS
local math_max, math_min, math_floor = math.max, math.min, math.floor
local string_format = string.format

local Grid = Verdant.ChartGrid
local TIME_STRIP_H, draw_grid, hide_grid = Grid.TIME_STRIP_H, Grid.draw, Grid.hide
local draw_markers = Verdant.ChartOverlay.markers
local text_width = Verdant.Format.text_width

local controls, STATE, ULT_L, BUFF_FOLD, BUFF_SELF, buff_hit, buff_vis, buff_color, buffs_unfolded, self_unfolded, C_DIM_BIAS

function M.bind(t)
  controls, STATE, ULT_L = t.controls, t.STATE, t.ULT_L
  BUFF_FOLD, BUFF_SELF, buff_hit, buff_vis = t.BUFF_FOLD, t.BUFF_SELF, t.buff_hit, t.buff_vis
  buff_color, buffs_unfolded, self_unfolded, C_DIM_BIAS = t.buff_color, t.buffs_unfolded, t.buffs_self_unfolded, t.C_DIM_BIAS
end

local BUFF_MAX_ROW_H = 32
local BUFF_GUTTER_W  = 214
local BUFF_ROW_GAP   = 4
local BUFF_MIN_ROW   = 10
local BUFF_PCT_W     = 38
local TWO_LINES_H    = 28
local SELF_TIDE_H    = 10
local EDGE_PX        = 2
local MIN_LEVEL_PX   = 2
local FILL_A, FILL_A_DIM, EDGE_A_DIM = 0.28, 0.08, 0.30
local GAP_MIN_MS, GAP_UPTIME, GAP_BAR_H = 2000, 0.5, 3
local CHIP_H, CHIP_GAP, CHIP_PAD = 20, 6, 4
local C_BUFF_NAME = { r = 0.86, g = 0.92, b = 0.88, a = 1.0 }
local C_BUFF_MORE = { r = 0.60, g = 0.66, b = 0.62, a = 0.90 }
local C_BUFF_PCT  = { r = 0.86, g = 0.92, b = 0.88, a = 1.0 }
local C_BUFF_SUB  = { r = 0.56, g = 0.64, b = 0.60, a = 1.0 }
local C_GAP       = { r = 0.95, g = 0.77, b = 0.35, a = 1.0 }
local C_BUFF_LANE = Verdant.lib.themes.tint("lane", 0.05)

local colmax = {}
local snap_sc, snap_bx, snap_by = 1, 0, 0

local function sx(v) return math_floor((snap_bx + v) * snap_sc + 0.5) / snap_sc - snap_bx end
local function sy(v) return math_floor((snap_by + v) * snap_sc + 0.5) / snap_sc - snap_by end

local function seg(canvas, x, y, w, h, r, g, b, a, level)
  local s = controls.pool_buff_seg:AcquireObject()
  s:ClearAnchors()
  s:SetAnchor(TOPLEFT, canvas, TOPLEFT, x, y)
  s:SetWidth(w)
  s:SetHeight(h)
  s:SetColor(r, g, b, a)
  s:SetDrawLevel(level)
  s:SetHidden(false)
  return s
end

local function label(canvas, text, x, y, w, h, align, col, a)
  local l = controls.pool_buff_lbl:AcquireObject()
  l:ClearAnchors()
  l:SetFont("ZoFontGameSmall")
  l:SetText(text)
  l:SetHorizontalAlignment(align)
  l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  l:SetMaxLineCount(1)
  l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  l:SetColor(col.r, col.g, col.b, a)
  l:SetDimensions(w, h)
  l:SetAnchor(TOPLEFT, canvas, TOPLEFT, x, y)
  l:SetHidden(false)
  return l
end

local function icon(canvas, tex, x, y, size, a)
  local ic = controls.pool_buff_icon:AcquireObject()
  ic:ClearAnchors()
  ic:SetTexture(tex)
  ic:SetDimensions(size, size)
  ic:SetColor(1, 1, 1, a)
  ic:SetAnchor(TOPLEFT, canvas, TOPLEFT, x, y)
  ic:SetHidden(false)
  return ic
end

local function tide(canvas, rec, t0, t_hi, span, lane_x, lane_w, top, h, G, c, dim)
  local sc = snap_sc
  local x0 = sx(lane_x)
  local base = sy(top + h)
  local W = math_floor(lane_w * sc)
  if W < 1 or h < 2 then return end
  for p = 0, W - 1 do colmax[p] = 0 end
  local hp = math_floor(h * sc)
  local n = rec.n_steps
  for k = 1, n do
    local cnt = rec.step_c[k]
    if cnt > 0 then
      local st = rec.step_t[k]
      local en = (k < n) and rec.step_t[k + 1] or t_hi
      if en > t_hi then en = t_hi end
      if st < t0 then st = t0 end
      if en > st then
        local a = math_floor((st - t0) / span * W)
        local b = -math_floor(-((en - t0) / span * W))
        if b <= a then b = a + 1 end
        if b > W then b = W end
        local v = cnt / G
        if v > 1 then v = 1 end
        local lv = math_floor(v * hp + 0.5)
        if lv < MIN_LEVEL_PX then lv = MIN_LEVEL_PX end
        for p = a, b - 1 do
          if colmax[p] < lv then colmax[p] = lv end
        end
      end
    end
  end
  local inv = 1 / sc
  local edge = EDGE_PX * inv
  local fa = dim and FILL_A_DIM or FILL_A
  local ea = dim and EDGE_A_DIM or 1
  local cr, cg, cb = c.r, c.g, c.b
  local p, prev = 0, 0
  while p < W do
    local lv = colmax[p]
    local q = p + 1
    while q < W and colmax[q] == lv do q = q + 1 end
    local xa, xb = x0 + p * inv, x0 + q * inv
    if lv > 0 then
      local yt = base - lv * inv
      seg(canvas, xa, yt, xb - xa, lv * inv, cr, cg, cb, fa, 3)
      seg(canvas, xa, yt, xb - xa, edge, cr, cg, cb, ea, 5)
    end
    if lv ~= prev then
      local hi = (lv > prev) and lv or prev
      local lo = (lv > prev) and prev or lv
      local y_hi = base - hi * inv
      local y_lo = (lo > 0) and (base - lo * inv + edge) or base
      seg(canvas, xa, y_hi, edge, y_lo - y_hi, cr, cg, cb, ea, 5)
    end
    prev = lv
    p = q
  end
  if prev > 0 and x0 + W * inv < lane_x + lane_w then
    seg(canvas, x0 + W * inv, base - prev * inv, edge, prev * inv, cr, cg, cb, ea, 5)
  end
end

local function gap_marks(canvas, rec, t0, t_hi, span, lane_x, lane_w, y, base, dur)
  if dur <= 0 or rec.uptime_ms < GAP_UPTIME * dur then return end
  local g1, g1a, g2, g2a = 0, 0, 0, 0
  local up_end = nil
  local n = rec.n_steps
  for k = 1, n do
    if rec.step_c[k] > 0 then
      local st = rec.step_t[k]
      if up_end and st > up_end then
        local len = st - up_end
        if len > g1 then
          g2, g2a = g1, g1a
          g1, g1a = len, up_end
        elseif len > g2 then
          g2, g2a = len, up_end
        end
      end
      local en = (k < n) and rec.step_t[k + 1] or t_hi
      if not up_end or en > up_end then up_end = en end
    end
  end
  for i = 1, 2 do
    local len, a = g1, g1a
    if i == 2 then len, a = g2, g2a end
    if len >= GAP_MIN_MS then
      local xa = sx(lane_x + (a - t0) / span * lane_w)
      local xb = sx(lane_x + (a + len - t0) / span * lane_w)
      if xb - xa < 1 then xb = xa + 1 end
      seg(canvas, xa, base - GAP_BAR_H, xb - xa, GAP_BAR_H, C_GAP.r, C_GAP.g, C_GAP.b, 0.95, 6)
      local mid = (xa + xb) / 2
      label(canvas, string_format(GetString(VERDANT_BUFFS_GAP), len / 1000), mid - 24, y, 48, 12, TEXT_ALIGN_CENTER, C_GAP, 1)
    end
  end
end

local chip_name_w = {}

local function chip_strip(canvas, tab, recs, n, y, cw, head_text, chips, capture, dur, hk)
  tab.on = true
  tab.y0, tab.y1 = y, y + BUFF_FOLD.H
  seg(canvas, 0, y, cw, BUFF_FOLD.H, C_BUFF_LANE.r, C_BUFF_LANE.g, C_BUFF_LANE.b, chips and 0.08 or 0.03, 2)
  local head = label(canvas, head_text, 6, y, BUFF_GUTTER_W - 8, BUFF_FOLD.H, TEXT_ALIGN_LEFT, C_BUFF_MORE, C_BUFF_MORE.a)
  for k = 1, #tab.x0 do tab.x0[k], tab.x1[k] = nil, nil end
  if not chips then return end
  local SC = Verdant.SkillColors
  local with_pct = capture and dur > 0
  local pct_w = with_pct and 34 or 0
  local tail = with_pct and (CHIP_PAD + pct_w) or 0
  local base_w = CHIP_PAD + BUFF_FOLD.ICON + CHIP_PAD + tail + CHIP_PAD
  local full = 0
  for k = 1, n do
    local rec = recs[k]
    local w = text_width(head, rec.name or tostring(rec.id))
    if w > 150 then w = 150 end
    chip_name_w[k] = w
    full = full + base_w + w + CHIP_PAD + CHIP_GAP
  end
  local named = (BUFF_GUTTER_W + full - CHIP_GAP) <= cw
  local x = BUFF_GUTTER_W
  local cy = y + math_floor((BUFF_FOLD.H - CHIP_H) / 2)
  local iy = y + math_floor((BUFF_FOLD.H - BUFF_FOLD.ICON) / 2)
  for k = 1, n do
    local rec = recs[k]
    local c = buff_color(rec)
    local dim = hk ~= nil and rec.id ~= hk
    local a = dim and 0.45 or 1
    local name_w = named and chip_name_w[k] or 0
    local w = base_w + (named and (name_w + CHIP_PAD) or 0)
    if x + w > cw then
      label(canvas, string_format("+%d", n - k + 1), x, cy, 40, CHIP_H, TEXT_ALIGN_LEFT, C_BUFF_MORE, C_BUFF_MORE.a)
      break
    end
    seg(canvas, x, cy, w, CHIP_H, c.r, c.g, c.b, dim and 0.05 or 0.14, 3)
    icon(canvas, SC.ability_icon(rec.id), x + CHIP_PAD, iy, BUFF_FOLD.ICON, a)
    if named then
      label(canvas, rec.name or tostring(rec.id), x + CHIP_PAD * 2 + BUFF_FOLD.ICON, cy, name_w, CHIP_H, TEXT_ALIGN_LEFT, C_BUFF_NAME, a)
    end
    if with_pct then
      label(canvas, string_format("%d%%", math_floor(rec.uptime_ms / dur * 100 + 0.5)),
        x + w - CHIP_PAD - pct_w, cy, pct_w, CHIP_H, TEXT_ALIGN_RIGHT, c, a)
    end
    tab.rec[k] = rec
    tab.x0[k], tab.x1[k] = x, x + w
    x = x + w + CHIP_GAP
  end
end

local function gutter(canvas, rec, y, row_h, c, dim, capture, dur, G, isz)
  local SC = Verdant.SkillColors
  local armed = Verdant.BuffWatch.thr(rec.name) ~= nil
  local hk = STATE.hover_key
  if armed or rec.id == hk then
    local star = icon(canvas, "EsoUI/Art/Collections/Favorite_StarOnly.dds", 1, y + math_floor((row_h - 13) / 2), 13, 1)
    if armed then
      star:SetColor(1.00, 0.85, 0.40, 0.95)
    else
      star:SetColor(0.80, 0.85, 0.80, 0.55)
    end
  end
  icon(canvas, SC.ability_icon(rec.id), 16, y + math_floor((row_h - isz) / 2), isz, 1)
  local name_x = 16 + isz + 6
  local name_w = BUFF_GUTTER_W - name_x - (capture and (BUFF_PCT_W + 8) or 6)
  local a = dim and 0.6 or 1
  local k = dim and 0.45 or 1
  local name_col = C_BUFF_NAME
  local two = capture and dur > 0 and row_h >= TWO_LINES_H and not rec.only_self
  local lbl = label(canvas, rec.name or tostring(rec.id), name_x, two and (y + 1) or y, name_w, two and 15 or row_h, TEXT_ALIGN_LEFT, name_col, a)
  if dim then lbl:SetColor(name_col.r * k, name_col.g * k, name_col.b * k, a) end
  if two then
    local avg = Verdant.BuffTracker.avg_concurrency(rec)
    label(canvas, string_format(GetString(VERDANT_BUFFS_REACH), avg, G, rec.unique_units or 0),
      name_x, y + 15, name_w, 13, TEXT_ALIGN_LEFT, C_BUFF_SUB, dim and 0.5 or 1)
  end
  if capture and dur > 0 then
    local pct = label(canvas, string_format("%d%%", math_floor(rec.uptime_ms / dur * 100 + 0.5)),
      BUFF_GUTTER_W - BUFF_PCT_W - 6, y, BUFF_PCT_W, row_h, TEXT_ALIGN_RIGHT, C_BUFF_PCT, a)
    if dim then pct:SetColor(C_BUFF_PCT.r * k, C_BUFF_PCT.g * k, C_BUFF_PCT.b * k, a) end
  end
end

local function group_size(n_all)
  local BT = Verdant.BuffTracker
  local sess = controls.loaded_sess
  local g = (sess and sess.head and sess.head.group_size) or (api.GetGroupSize and api.GetGroupSize()) or 0
  for i = 1, n_all do
    local m = BT.get(i).max_conc or 0
    if m > g then g = m end
  end
  if g < 1 then g = 1 end
  return g
end

local function render_view4()
  controls.pool_buff_seg:ReleaseAllObjects()
  controls.pool_buff_rim:ReleaseAllObjects()
  controls.pool_buff_icon:ReleaseAllObjects()
  controls.pool_buff_lbl:ReleaseAllObjects()
  controls.pool_dead:ReleaseAllObjects()

  local BT    = Verdant.BuffTracker
  local n_all = BT.count()
  local vis   = buff_vis
  local recording = Verdant.TemporalBuffer.is_recording()
  local unfolded = buffs_unfolded()
  local self_open = self_unfolded()
  local fold_dur = (not recording) and (BT.session_end() - BT.session_start()) or 0
  local always_n, self_n, group_n = 0, 0, 0
  BUFF_FOLD.n, BUFF_FOLD.on = 0, false
  BUFF_SELF.n, BUFF_SELF.on = 0, false
  local always_c = 0
  if fold_dur > 0 then
    for i = 1, n_all do
      local rec = BT.get(i)
      if BT.shown(rec)
        and rec.uptime_ms / fold_dur >= BUFF_FOLD.PCT then always_c = always_c + 1 end
    end
  end
  local folding = always_c >= BUFF_FOLD.MIN
  for i = 1, n_all do
    local rec = BT.get(i)
    if BT.shown(rec) then
      if folding and rec.uptime_ms / fold_dur >= BUFF_FOLD.PCT then
        always_n = always_n + 1
        BUFF_FOLD.rec[always_n] = rec
      elseif rec.only_self and fold_dur > 0 then
        self_n = self_n + 1
        BUFF_SELF.rec[self_n] = rec
      else
        group_n = group_n + 1
        vis[group_n] = rec
      end
    end
  end
  if unfolded then
    for k = always_n, 1, -1 do
      table.insert(vis, 1, BUFF_FOLD.rec[k])
      group_n = group_n + 1
    end
  end
  local n = group_n
  if self_open then
    for k = 1, self_n do
      n = n + 1
      vis[n] = BUFF_SELF.rec[k]
    end
  end
  BUFF_FOLD.n = always_n
  BUFF_SELF.n = self_n

  if n == 0 and always_n == 0 and self_n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid_ems)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas = controls.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= BUFF_GUTTER_W + 40 or ch <= 4 then return end

  local t0   = BT.session_start()
  local t_hi = recording and GetGameTimeMilliseconds() or BT.session_end()
  local span = t_hi - t0
  if span <= 0 then return end

  snap_sc = api.GetUIGlobalScale and api.GetUIGlobalScale() or 1
  if not snap_sc or snap_sc <= 0 then snap_sc = 1 end
  snap_bx, snap_by = canvas:GetLeft() or 0, canvas:GetTop() or 0

  Verdant.Diagnostics.bump("graph.view_buffs.renders")
  draw_grid(controls.grid_ems, canvas, 0, span)

  local capture = not recording
  local dur = capture and (BT.session_end() - BT.session_start()) or 0
  local hk = STATE.hover_key

  local top = ULT_L.CHIP
  if always_n > 0 then
    chip_strip(canvas, BUFF_FOLD, BUFF_FOLD.rec, always_n, top,
      cw, string_format(GetString(unfolded and VERDANT_BUFFS_ALWAYS_OPEN or VERDANT_BUFFS_ALWAYS), always_n),
      not unfolded, capture, dur, hk)
    top = top + BUFF_FOLD.H + BUFF_ROW_GAP
  end
  local bottom = ch - TIME_STRIP_H
  if self_n > 0 then
    local sy0 = bottom - BUFF_FOLD.H
    chip_strip(canvas, BUFF_SELF, BUFF_SELF.rec, self_n, sy0,
      cw, string_format(GetString(self_open and VERDANT_BUFFS_SELF_OPEN or VERDANT_BUFFS_SELF), self_n),
      not self_open, capture, dur, hk)
    bottom = sy0 - BUFF_ROW_GAP
  end

  local lane_x = BUFF_GUTTER_W
  local lane_w = cw - BUFF_GUTTER_W
  buff_hit.n = 0
  buff_hit.lane_x, buff_hit.lane_w, buff_hit.t0, buff_hit.span = lane_x, lane_w, t0, span
  if n == 0 then
    Verdant.FilmDead.draw_span(controls.pool_dead, canvas, t0, span, lane_x, lane_w, top, bottom)
    draw_markers(controls.pool_marker_icon, canvas, t0, span, lane_x, lane_w)
    return
  end

  local ch_plot = math_max(4, bottom - top)
  local rows    = n
  local extra   = 0
  local row_h   = math_floor(ch_plot / rows) - BUFF_ROW_GAP
  if row_h < BUFF_MIN_ROW then
    rows  = math_max(1, math_floor(ch_plot / (BUFF_MIN_ROW + BUFF_ROW_GAP)) - 1)
    if rows > n then rows = n end
    extra = (n > rows) and 1 or 0
    row_h = math_floor(ch_plot / (rows + extra)) - BUFF_ROW_GAP
    if row_h < 6 then return end
  elseif row_h > BUFF_MAX_ROW_H then
    row_h = BUFF_MAX_ROW_H
  end
  if n > rows then Verdant.Diagnostics.bump("graph.view_buffs.overflow") end
  local max_scroll = (n > rows) and (n - rows) or 0
  if BUFF_FOLD.scroll > max_scroll then BUFF_FOLD.scroll = max_scroll end
  if BUFF_FOLD.scroll < 0 then BUFF_FOLD.scroll = 0 end
  BUFF_FOLD.max_scroll = max_scroll
  local off = BUFF_FOLD.scroll

  local isz = (row_h < 18) and row_h or 18
  local G = group_size(n_all)

  buff_hit.n = rows
  for i = 1, rows do
    local rec = vis[i + off]
    local y   = top + (i - 1) * (row_h + BUFF_ROW_GAP)
    local c   = buff_color(rec)
    local dim = (hk ~= nil and rec.id ~= hk)
    buff_hit.y0[i]  = y
    buff_hit.y1[i]  = y + row_h
    buff_hit.rec[i] = rec

    seg(canvas, lane_x, y, lane_w, row_h, C_BUFF_LANE.r, C_BUFF_LANE.g, C_BUFF_LANE.b, C_BUFF_LANE.a, 1)
    gutter(canvas, rec, y, row_h, c, dim, capture, dur, G, isz)
    if rec.only_self then
      local h = math_min(SELF_TIDE_H, row_h - 4)
      tide(canvas, rec, t0, t_hi, span, lane_x, lane_w, y + math_floor((row_h - h) / 2), h, 1, c, dim)
    else
      local h = row_h - 5
      tide(canvas, rec, t0, t_hi, span, lane_x, lane_w, y + 3, h, G, c, dim)
      if capture then gap_marks(canvas, rec, t0, t_hi, span, lane_x, lane_w, y + 1, sy(y + 3 + h), dur) end
    end
  end

  Verdant.FilmDead.draw_span(controls.pool_dead, canvas, t0, span, lane_x, lane_w, top, bottom)
  draw_markers(controls.pool_marker_icon, canvas, t0, span, lane_x, lane_w)

  if n > rows then
    label(canvas, string_format(GetString(VERDANT_BUFFS_SCROLLED), off, n - rows - off),
      0, top + rows * (row_h + BUFF_ROW_GAP), cw, row_h, TEXT_ALIGN_LEFT, C_BUFF_MORE, C_BUFF_MORE.a)
  end
end

M.GUTTER_W = BUFF_GUTTER_W
M.render   = render_view4
