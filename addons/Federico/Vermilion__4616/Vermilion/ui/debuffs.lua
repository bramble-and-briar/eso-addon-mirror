Vermilion = Vermilion or {}
Vermilion.DebuffsView = {}
local M = Vermilion.DebuffsView

local math_floor    = math.floor
local math_max      = math.max
local string_format = string.format
local table_insert  = table.insert

local MAX_ROW_H = 26
local GUTTER_W  = 176
local ROW_GAP   = 3
local MIN_ROW   = 10
local PCT_W     = 34
local C_NAME    = { r = 0.94, g = 0.88, b = 0.86, a = 1.0 }
local C_MORE    = { r = 0.70, g = 0.64, b = 0.62, a = 0.90 }
local C_PCT     = { r = 0.76, g = 0.66, b = 0.64, a = 1.0 }
local C_LANE    = { r = 1.00, g = 0.62, b = 0.58, a = 0.05 }
local C_FALLBACK = { r = 0.66, g = 0.60, b = 0.60, a = 0.95 }
local DIM_BIAS  = 0.05

local FOLD = { PCT = 0.90, H = 24, ICON = 18, GAP = 3, MIN = 2, n = 0, x0 = {}, x1 = {}, rec = {}, y0 = 0, y1 = 0, on = false, scroll = 0, max_scroll = 0 }
local hit = { n = 0, y0 = {}, y1 = {}, rec = {}, lane_x = 0, lane_w = 0, t0 = 0, span = 0 }
local vis = {}
local hover_id = nil
local ctx = nil
local ROWS = { {}, {}, {}, {}, {}, {} }

local function color_of(rec)
  local SC = Vermilion.SkillColors
  if rec.group and rec.group ~= "other" then
    return SC.group_color(rec.group)
  end
  return (SC.buff_family_color and SC.buff_family_color(rec.name)) or C_FALLBACK
end

local function seg_alpha(conc, max_conc)
  if max_conc <= 1 then return 0.90 end
  return (conc / max_conc > 0.5) and 0.92 or 0.50
end

local function lane_seg(c, canvas, x0, x1, y, row_h, conc, rec, col, dim)
  local rim = c.rim:AcquireObject()
  rim:ClearAnchors()
  rim:SetAnchor(TOPLEFT, canvas, TOPLEFT, x0 - 1, y - 1)
  rim:SetWidth(math_max(1, x1 - x0) + 2)
  rim:SetHeight(row_h + 2)
  rim:SetColor(0, 0, 0, dim and 0.20 or 0.50)
  rim:SetHidden(false)
  local seg = c.seg:AcquireObject()
  seg:ClearAnchors()
  seg:SetAnchor(TOPLEFT, canvas, TOPLEFT, x0, y)
  seg:SetWidth(math_max(1, x1 - x0))
  seg:SetHeight(row_h)
  seg:SetDrawLevel(4)
  if dim then
    seg:SetColor(col.r * 0.30 + DIM_BIAS, col.g * 0.30 + DIM_BIAS, col.b * 0.30 + DIM_BIAS, 0.25)
  else
    seg:SetColor(col.r, col.g, col.b, seg_alpha(conc, rec.max_conc))
  end
  seg:SetHidden(false)
end

local function card_icon(id)
  local icon = Vermilion.SkillColors.ability_icon(id)
  if not icon or icon == "" or icon:find("icon_missing", 1, true) then return nil end
  return icon
end

function M.attach(t) ctx = t end

function M.unfolded()
  local sv = Vermilion.SavedVars
  return sv and sv.settings and sv.settings.debuffs_unfolded == true or false
end

function M.render()
  local c = ctx
  if not c then return end
  c.seg:ReleaseAllObjects()
  c.rim:ReleaseAllObjects()
  c.icon:ReleaseAllObjects()
  c.lbl:ReleaseAllObjects()
  c.hit_reset()

  local BT    = Vermilion.DebuffTracker
  local n_all = BT.count()
  local n     = 0
  local recording = Vermilion.TemporalBuffer.is_recording()
  local unfolded = M.unfolded()
  local fold_dur = (not recording) and BT.fight_ms() or 0
  local always_n = 0
  FOLD.n = 0
  FOLD.on = false
  for i = 1, n_all do
    local rec = BT.get(i)
    if fold_dur > 0 and rec.uptime_ms / fold_dur >= FOLD.PCT then
      always_n = always_n + 1
      FOLD.rec[always_n] = rec
    else
      n = n + 1
      vis[n] = rec
    end
  end
  if always_n < FOLD.MIN then
    for k = always_n, 1, -1 do
      table_insert(vis, 1, FOLD.rec[k])
      n = n + 1
    end
    always_n = 0
  elseif unfolded then
    for k = always_n, 1, -1 do
      table_insert(vis, 1, FOLD.rec[k])
      n = n + 1
    end
  end
  for k = n + 1, #vis do vis[k] = nil end
  FOLD.n = always_n

  if n == 0 and always_n == 0 then
    c.no_data:SetHidden(false)
    c.hide_grid(c.grid)
    return
  end
  c.no_data:SetHidden(true)

  local canvas = c.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= GUTTER_W + 40 or ch <= 4 then return end

  local t0   = BT.session_start()
  local t_hi = recording and c.now() or BT.session_end()
  local span = t_hi - t0
  if span <= 0 then return end

  Vermilion.Diagnostics.bump("graph.view_debuffs.renders")
  c.draw_grid(c.grid, canvas, 0, span)

  local chip = c.layout.H or 0
  local strip_h = (always_n > 0) and (FOLD.H + ROW_GAP) or 0
  local top = chip + strip_h
  if always_n > 0 then
    FOLD.on = true
    FOLD.y0 = chip
    FOLD.y1 = chip + FOLD.H
    local band = c.seg:AcquireObject()
    band:ClearAnchors()
    band:SetAnchor(TOPLEFT, canvas, TOPLEFT, 0, chip)
    band:SetWidth(cw)
    band:SetHeight(FOLD.H)
    band:SetColor(C_LANE.r, C_LANE.g, C_LANE.b, unfolded and 0.03 or 0.08)
    band:SetHidden(false)
    local head = c.lbl:AcquireObject()
    head:ClearAnchors()
    head:SetText(string_format(GetString(unfolded and VERMILION_DEBUFFS_ALWAYS_OPEN or VERMILION_DEBUFFS_ALWAYS), always_n))
    head:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    head:SetColor(C_MORE.r, C_MORE.g, C_MORE.b, C_MORE.a)
    head:SetDimensions(GUTTER_W - 8, FOLD.H)
    head:SetAnchor(TOPLEFT, canvas, TOPLEFT, 6, chip)
    head:SetHidden(false)
    if not unfolded then
      local x = GUTTER_W
      local iy = chip + math_floor((FOLD.H - FOLD.ICON) / 2)
      for k = 1, always_n do
        if x + FOLD.ICON > cw then break end
        local rec = FOLD.rec[k]
        local ic = c.icon:AcquireObject()
        ic:ClearAnchors()
        ic:SetTexture(Vermilion.SkillColors.ability_icon(rec.id))
        ic:SetDimensions(FOLD.ICON, FOLD.ICON)
        ic:SetColor(1, 1, 1, (hover_id ~= nil and rec.id ~= hover_id) and 0.45 or 1)
        ic:SetAnchor(TOPLEFT, canvas, TOPLEFT, x, iy)
        ic:SetHidden(false)
        FOLD.x0[k] = x
        FOLD.x1[k] = x + FOLD.ICON
        x = x + FOLD.ICON + FOLD.GAP
      end
    end
  end
  if n == 0 then return end

  local ch_plot = math_max(4, ch - c.time_strip - top)
  local rows    = n
  local extra   = 0
  local row_h   = math_floor(ch_plot / rows) - ROW_GAP
  if row_h < MIN_ROW then
    rows  = math_max(1, math_floor(ch_plot / (MIN_ROW + ROW_GAP)) - 1)
    if rows > n then rows = n end
    extra = (n > rows) and 1 or 0
    row_h = math_floor(ch_plot / (rows + extra)) - ROW_GAP
    if row_h < 6 then return end
  elseif row_h > MAX_ROW_H then
    row_h = MAX_ROW_H
  end
  if n > rows then Vermilion.Diagnostics.bump("graph.view_debuffs.overflow") end
  local max_scroll = (n > rows) and (n - rows) or 0
  if FOLD.scroll > max_scroll then FOLD.scroll = max_scroll end
  if FOLD.scroll < 0 then FOLD.scroll = 0 end
  FOLD.max_scroll = max_scroll
  local off = FOLD.scroll

  local SC     = Vermilion.SkillColors
  local lane_x = GUTTER_W
  local lane_w = cw - GUTTER_W
  local isz    = (row_h < 20) and row_h or 20

  local capture = not recording
  hit.n = capture and rows or 0
  hit.lane_x = lane_x
  hit.lane_w = lane_w
  hit.t0     = t0
  hit.span   = span
  local hk = hover_id
  local dur = capture and BT.fight_ms() or 0

  for i = 1, rows do
    local rec = vis[i + off]
    local y   = top + (i - 1) * (row_h + ROW_GAP)
    local col = color_of(rec)
    local dim = (hk ~= nil and rec.id ~= hk)
    if capture then
      hit.y0[i]  = y
      hit.y1[i]  = y + row_h
      hit.rec[i] = rec
    end

    local lane = c.seg:AcquireObject()
    lane:ClearAnchors()
    lane:SetAnchor(TOPLEFT, canvas, TOPLEFT, lane_x, y)
    lane:SetWidth(lane_w)
    lane:SetHeight(row_h)
    lane:SetColor(C_LANE.r, C_LANE.g, C_LANE.b, C_LANE.a)
    lane:SetHidden(false)

    local icon = c.icon:AcquireObject()
    icon:ClearAnchors()
    icon:SetTexture(SC.ability_icon(rec.id))
    icon:SetDimensions(isz, isz)
    icon:SetColor(1, 1, 1, 1)
    icon:SetAnchor(TOPLEFT, canvas, TOPLEFT, 4, y + math_floor((row_h - isz) / 2))
    icon:SetHidden(false)

    local name_w = capture and (GUTTER_W - isz - PCT_W - 16) or (GUTTER_W - isz - 14)
    local lbl = c.lbl:AcquireObject()
    lbl:ClearAnchors()
    lbl:SetText(rec.name or tostring(rec.id))
    lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    lbl:SetMaxLineCount(1)
    lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if dim then
      lbl:SetColor(C_NAME.r * 0.45, C_NAME.g * 0.45, C_NAME.b * 0.45, 0.6)
    else
      lbl:SetColor(C_NAME.r, C_NAME.g, C_NAME.b, C_NAME.a)
    end
    local bar_room = capture and dur > 0 and row_h >= 18
    lbl:SetDimensions(name_w, bar_room and (row_h - 6) or row_h)
    lbl:SetAnchor(TOPLEFT, canvas, TOPLEFT, isz + 8, y)
    lbl:SetHidden(false)

    if bar_room then
      local frac = rec.uptime_ms / dur
      if frac > 1 then frac = 1 end
      local track = c.seg:AcquireObject()
      track:ClearAnchors()
      track:SetAnchor(TOPLEFT, canvas, TOPLEFT, isz + 8, y + row_h - 5)
      track:SetWidth(name_w)
      track:SetHeight(3)
      track:SetDrawLevel(3)
      track:SetColor(1, 1, 1, dim and 0.03 or 0.07)
      track:SetHidden(false)
      local fill = c.seg:AcquireObject()
      fill:ClearAnchors()
      fill:SetAnchor(TOPLEFT, canvas, TOPLEFT, isz + 8, y + row_h - 5)
      fill:SetWidth(math_max(1, math_floor(name_w * frac + 0.5)))
      fill:SetHeight(3)
      fill:SetDrawLevel(4)
      fill:SetColor(col.r, col.g, col.b, dim and 0.25 or 0.80)
      fill:SetHidden(false)
    end

    if capture and dur > 0 then
      local pct = c.lbl:AcquireObject()
      pct:ClearAnchors()
      pct:SetText(string_format("%d%%", math_floor(BT.uptime_of(rec) * 100 + 0.5)))
      pct:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
      if dim then
        pct:SetColor(C_PCT.r * 0.45, C_PCT.g * 0.45, C_PCT.b * 0.45, 0.6)
      else
        pct:SetColor(C_PCT.r, C_PCT.g, C_PCT.b, C_PCT.a)
      end
      pct:SetDimensions(PCT_W, row_h)
      pct:SetAnchor(TOPLEFT, canvas, TOPLEFT, GUTTER_W - PCT_W - 6, y)
      pct:SetHidden(false)
    end

    local n_steps = rec.n_steps
    local run_x0, run_x1, run_conc
    for k = 1, n_steps do
      local conc = rec.step_c[k]
      if conc > 0 then
        local st = rec.step_t[k]
        local en = (k < n_steps) and rec.step_t[k + 1] or t_hi
        if en > t_hi then en = t_hi end
        if en > st then
          local x0 = lane_x + math_floor((st - t0) / span * lane_w + 0.5)
          local x1 = lane_x + math_floor((en - t0) / span * lane_w + 0.5)
          if x1 <= x0 then x1 = x0 + 1 end
          if run_x0 and x0 <= run_x1 then
            if x1 > run_x1 then run_x1 = x1 end
            if conc > run_conc then run_conc = conc end
          else
            if run_x0 then lane_seg(c, canvas, run_x0, run_x1, y, row_h, run_conc, rec, col, dim) end
            run_x0, run_x1, run_conc = x0, x1, conc
          end
        end
      end
    end
    if run_x0 then lane_seg(c, canvas, run_x0, run_x1, y, row_h, run_conc, rec, col, dim) end
  end

  if n > rows then
    local more = c.lbl:AcquireObject()
    more:ClearAnchors()
    more:SetText(string_format(GetString(VERMILION_DEBUFFS_SCROLLED), off, n - rows - off))
    more:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    more:SetColor(C_MORE.r, C_MORE.g, C_MORE.b, C_MORE.a)
    more:SetDimensions(cw, row_h)
    more:SetAnchor(TOPLEFT, canvas, TOPLEFT, 0, top + rows * (row_h + ROW_GAP))
    more:SetHidden(false)
  end
end

local function show_rec_card(c, rec, t_at, conc_at, mx, my)
  local BT  = Vermilion.DebuffTracker
  local col = color_of(rec)
  local pct = math_floor(BT.uptime_of(rec) * 100 + 0.5)
  local stat = string_format("%s %d%%  ·  %s", GetString(VERMILION_DEBUFFH_UPTIME), pct, c.fmt_secs(rec.uptime_ms))
  local time = string_format("t  %s  ·  %d %s", c.fmt_secs(t_at), conc_at, GetString(VERMILION_DEBUFFH_TARGETS_NOW))
  local rows = ROWS
  rows[1][1], rows[1][2] = GetString(VERMILION_DEBUFFH_TARGETS), tostring(rec.unique_units)
  rows[2][1], rows[2][2] = GetString(VERMILION_DEBUFFH_MAXC), tostring(rec.max_conc)
  rows[3][1], rows[3][2] = GetString(VERMILION_DEBUFFH_AVGC), string_format("%.1f", BT.avg_concurrency(rec))
  rows[4][1], rows[4][2] = GetString(VERMILION_DEBUFFH_APPS), tostring(rec.applications)
  rows[5][1], rows[5][2] = GetString(VERMILION_DEBUFFH_GAP), c.fmt_secs(rec.longest_gap_ms)
  local n_rows = 5
  local SC = Vermilion.SkillColors
  local fam = SC.buff_family and SC.buff_family(rec.name)
  if fam then
    n_rows = 6
    rows[6][1], rows[6][2] = GetString(VERMILION_DEBUFFH_FAMILY), GetString(rawget(_G, "VERMILION_BUFF_FAM_" .. fam:upper()))
  end
  local desc = rec.desc
  if desc == "" then
    Vermilion.Diagnostics.bump("debuffs.desc_miss")
    desc = nil
  end
  c.show_card(col, rec.name or tostring(rec.id), stat, time, rows, n_rows, desc, mx, my, card_icon(rec.id))
end

function M.hover(mx, my)
  local c = ctx
  if not c then return end
  local canvas = c.canvas
  local rel_x  = mx - canvas:GetLeft()
  local rel_y  = my - canvas:GetTop()
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  local inside = rel_x >= 0 and rel_x <= cw and rel_y >= 0 and rel_y <= ch

  local rec = nil
  if inside and FOLD.on and rel_y >= FOLD.y0 and rel_y <= FOLD.y1 then
    for k = 1, FOLD.n do
      if FOLD.x0[k] and rel_x >= FOLD.x0[k] and rel_x <= FOLD.x1[k] then
        rec = FOLD.rec[k]
        break
      end
    end
    local new = rec and rec.id or nil
    if new ~= hover_id then hover_id = new; c.rerender() end
    if rec then
      show_rec_card(c, rec, rec.uptime_ms, rec.max_conc or 0, mx, my)
    else
      c.hide_card()
    end
    return
  end
  if inside then
    for i = 1, hit.n do
      if rel_y >= hit.y0[i] and rel_y <= hit.y1[i] then
        rec = hit.rec[i]
        break
      end
    end
  end

  local new = rec and rec.id or nil
  if new ~= hover_id then hover_id = new; c.rerender() end

  if not rec or hit.span <= 0 then
    c.hide_card()
    return
  end

  local frac = (rel_x - hit.lane_x) / hit.lane_w
  if frac < 0 then frac = 0 end
  if frac > 1 then frac = 1 end
  local t_abs = hit.t0 + frac * hit.span
  local conc  = Vermilion.DebuffTracker.concurrency_at(rec, t_abs)
  c.crosshair(math_floor(rel_x))
  show_rec_card(c, rec, t_abs - hit.t0, conc, mx, my)
end

function M.click(mx, my)
  local c = ctx
  if not c then return false end
  local canvas = c.canvas
  local rel_x = mx - canvas:GetLeft()
  local rel_y = my - canvas:GetTop()
  if FOLD.on and rel_y >= FOLD.y0 and rel_y <= FOLD.y1 and rel_x >= 0 then
    local sv = Vermilion.SavedVars
    if not sv then return false end
    sv.settings = sv.settings or {}
    sv.settings.debuffs_unfolded = not (sv.settings.debuffs_unfolded == true)
    hover_id = nil
    return true
  end
  return false
end

function M.scroll(dir)
  local next_off = FOLD.scroll + ((dir or 1) < 0 and -1 or 1)
  if next_off < 0 then next_off = 0 end
  if next_off > FOLD.max_scroll then next_off = FOLD.max_scroll end
  if next_off == FOLD.scroll then return false end
  FOLD.scroll = next_off
  hover_id = nil
  return true
end

function M.reset_scroll() FOLD.scroll = 0 end
function M.scroll_state() return FOLD.scroll, FOLD.max_scroll end
function M.hovered() return hover_id end
function M.clear_hover() hover_id = nil end
function M.click_sound() return M.unfolded() and "on" or "off" end
function M.fold_state() return FOLD.on, FOLD.n end
