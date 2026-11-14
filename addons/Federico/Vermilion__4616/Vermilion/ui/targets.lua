Vermilion = Vermilion or {}
Vermilion.TargetsView = {}
local M = Vermilion.TargetsView

local math_floor    = math.floor
local math_max      = math.max
local math_sqrt     = math.sqrt
local string_format = string.format
local table_sort    = table.sort

local MAX_ROW_H = 30
local MIN_ROW   = 10
local ROW_GAP   = 3
local GUTTER_W  = 150
local RIGHT_W   = 118
local VAL_W     = 46
local BAR_PAD   = 8
local C_NAME    = { r = 0.94, g = 0.88, b = 0.86, a = 1.0 }
local C_VAL     = { r = 0.87, g = 0.85, b = 0.83, a = 1.0 }
local C_MORE    = { r = 0.70, g = 0.64, b = 0.62, a = 0.90 }
local C_LANE    = { r = 1.00, g = 0.62, b = 0.58, a = 0.05 }
local C_ORCHID  = { r = 0.85, g = 0.40, b = 0.75 }
local C_HEAT    = { r = 0.98, g = 0.55, b = 0.20 }
local DIM       = 0.30
local Heat      = Vermilion.Heat
local UNIT_ENEMY_PLAYER = Vermilion.zenimax.constants.COMBAT_UNIT_TYPE_OTHER
local LUT_N     = Heat.N

local PCT_TEXT = {}
for i = 0, 100 do PCT_TEXT[i] = i .. "%" end

local ctx = nil
local by_id = {}
local by_name = {}
local seen = {}
local dom = {}
local focus = { on_top = 0, switches = 0, samples = 0 }
local order = { n = 0 }
local hit = { n = 0, y0 = {}, y1 = {}, lane = {}, lane_x = 0, lane_w = 0, t0 = 0, span = 0 }
local xs = {}
local totals = { damage = 0, cell_max = 0, t0 = 0, t_hi = 0 }
local hover_id = nil
local scroll = 0
local max_scroll = 0
local gen = 0
local done_gen, done_live = -1, true
local ROWS = { {}, {}, {}, {}, {}, {}, {}, {}, {} }
local str = nil

local function strings()
  if str then return str end
  str = {
    damage   = GetString(VERMILION_TARGETH_DAMAGE),
    absorbed = GetString(VERMILION_TARGETH_ABSORBED),
    share    = GetString(VERMILION_TARGETH_SHARE),
    scrolled = GetString(VERMILION_TARGETS_SCROLLED),
    shield   = GetString(VERMILION_REPORT_SHIELDED),
  }
  return str
end

local function by_total_desc(a, b) return a.total > b.total end

local base_of = {}

local function base_name(raw)
  local b = base_of[raw]
  if not b then
    b = raw:gsub("%^%a+$", "")
    base_of[raw] = b
  end
  return b
end

local function entry_in(list, id)
  for k = 1, (list and list.count or 0) do
    local e = list[k]
    if e.id == id then return e end
  end
  return nil
end

local function lane_share(list, rec)
  local sh, ab = 0, 0
  if rec.is_player then
    local e = entry_in(list, rec.id)
    if e then sh, ab = e.share or 0, e.abs or 0 end
  else
    for k = 1, (list and list.count or 0) do
      local e = list[k]
      if base_name(e.name or "") == rec.raw then sh = sh + (e.share or 0); ab = ab + (e.abs or 0) end
    end
  end
  return sh, ab
end

local function lane_label(rec)
  if rec.n > 1 then
    if rec.label_n ~= rec.n then
      rec.label_n = rec.n
      rec.label = string_format("%s  ×%d", rec.name, rec.n)
    end
    return rec.label
  end
  return rec.name ~= "" and rec.name or tostring(rec.id)
end

local function rec_for(id, raw, ttype)
  local is_player = (ttype == UNIT_ENEMY_PLAYER)
  local rec
  if is_player then
    rec = by_id[id]
    if not rec then rec = { id = id, name = "", raw = nil, is_player = true, n = 1, ttype = 0, total = 0, abs = 0, gen = -1, disp = -1, text = "" }; by_id[id] = rec end
  else
    local base = base_name(raw)
    rec = by_name[base]
    if not rec then rec = { id = id, name = "", raw = nil, is_player = false, n = 0, ttype = 0, total = 0, abs = 0, gen = -1, disp = -1, text = "" }; by_name[base] = rec end
  end
  if rec.gen ~= gen then
    rec.gen = gen
    rec.total = 0
    rec.abs = 0
    rec.n = is_player and 1 or 0
    order.n = order.n + 1
    order[order.n] = rec
  end
  local plain = base_name(raw)
  if plain ~= rec.raw then
    rec.raw = plain
    rec.name = plain
  end
  if not is_player and seen[id] ~= gen then
    seen[id] = gen
    rec.n = rec.n + 1
    rec.id = id
  end
  rec.ttype = ttype or rec.ttype
  return rec
end

local function aggregate()
  local TB = Vermilion.TemporalBuffer
  local live = TB.is_recording()
  if not live and not done_live and TB.gen() == done_gen then return end
  done_gen, done_live = TB.gen(), live
  local n = TB.count()
  gen = gen + 1
  order.n = 0
  totals.damage = 0
  totals.cell_max = 0
  local prev_t = nil
  for i = 1, n do
    local s = TB.at(i)
    local eos = (s.eDPS or 0) + (s.ShDPS or 0)
    local dt = prev_t and (s.t - prev_t) / 1000 or 0
    local list = s.targets
    local best, best_v = nil, 0
    for k = 1, (list and list.count or 0) do
      local e = list[k]
      local rec = rec_for(e.id or 0, e.name or "", e.ttype)
      local v = (e.share or 0) * eos
      if dt > 0 then
        rec.total = rec.total + v * dt
        rec.abs = rec.abs + (e.abs or 0) * eos * dt
        totals.damage = totals.damage + v * dt
      end
      if v > best_v then best, best_v = rec, v end
    end
    dom[i] = best
    if i == 1 then totals.t0 = s.t end
    totals.t_hi = s.t
    prev_t = s.t
  end
  local ex = Vermilion.Metrics.exact()
  if ex and ex.targets then
    for r = 1, order.n do order[r].total = 0; order[r].abs = 0 end
    totals.damage = 0
    local names, types, abs = ex.target_names, ex.target_types, ex.targets_abs
    for id, amt in pairs(ex.targets) do
      local rec = rec_for(id, names[id] or "", types[id])
      rec.total = rec.total + amt
      rec.abs = rec.abs + (abs[id] or 0)
      totals.damage = totals.damage + amt
    end
  end
  for k = order.n + 1, #order do order[k] = nil end
  for k = n + 1, #dom do dom[k] = nil end
  if order.n > 1 then table_sort(order, by_total_desc) end
  totals.cell_max = 0
  totals.abs_max = 0
  for r = 1, order.n do
    local rec = order[r]
    if not rec.pv then rec.pv, rec.av = {}, {} end
  end
  for i = 1, n do
    local s = TB.at(i)
    local eos = (s.eDPS or 0) + (s.ShDPS or 0)
    for r = 1, order.n do
      local rec = order[r]
      local sh, ab = lane_share(s.targets, rec)
      local v = sh * eos
      rec.pv[i] = v
      if v > totals.cell_max then totals.cell_max = v end
      local w = ab * eos
      rec.av[i] = w
      if w > totals.abs_max then totals.abs_max = w end
    end
  end
  local top = order[1]
  local on_top, switches, counted, prev = 0, 0, 0, nil
  for i = 1, n do
    local d = dom[i]
    if d then
      counted = counted + 1
      if d == top then on_top = on_top + 1 end
      if prev and d ~= prev then switches = switches + 1 end
      prev = d
    end
  end
  focus.samples = counted
  focus.on_top = (counted > 0) and (on_top / counted) or 0
  focus.switches = switches
end

function M.focus()
  aggregate()
  return focus.on_top, focus.switches, order.n, focus.samples
end

local function cell(c, canvas, x0, x1, y, row_h, level, dim, sub)
  local seg = (sub and c.sub or c.seg):AcquireObject()
  seg:ClearAnchors()
  seg:SetAnchor(TOPLEFT, canvas, TOPLEFT, x0, y)
  seg:SetWidth(math_max(1, x1 - x0))
  seg:SetHeight(row_h)
  seg:SetDrawLevel(4)
  local col = sub and Heat.lut2(level) or Heat.lut(level)
  local a = Heat.alpha(level)
  if dim then
    seg:SetColor(col[1] * DIM, col[2] * DIM, col[3] * DIM, 0.35 * a)
  else
    seg:SetColor(col[1], col[2], col[3], a)
  end
  seg:SetHidden(false)
end

local function cached(arr, k, ns)
  if k < 1 or k > ns then return 0 end
  return arr[k]
end

local function lane_cells(c, canvas, vals, ns, vmax, y, h, dim, sub)
  local run_x0, run_x1, run_lv = nil, nil, -1
  local col_x0, col_x1, col_sum, col_n = nil, nil, 0, 0
  local v_prev, v_here, v_next = 0, cached(vals, 1, ns), cached(vals, 2, ns)
  for k = 1, ns + 1 do
    local x0, x1, v = nil, nil, 0
    if k <= ns then
      if v_here > 0 or v_prev > 0 or v_next > 0 then
        v = 0.25 * v_prev + 0.5 * v_here + 0.25 * v_next
        if v_here <= 0 then v = v * 0.5 end
      end
      x0, x1 = xs[k], xs[k + 1]
      if x1 <= x0 then x1 = x0 + 1 end
      v_prev, v_here, v_next = v_here, v_next, cached(vals, k + 2, ns)
    end
    if x0 ~= nil and x0 == col_x0 then
      col_sum = col_sum + v
      col_n = col_n + 1
      if x1 > col_x1 then col_x1 = x1 end
    else
      if col_x0 then
        local level = 0
        if vmax > 0 and col_sum > 0 then
          level = math_floor(math_sqrt(col_sum / col_n / vmax) * (LUT_N - 1) + 0.5)
          if level < 1 then level = 1 end
        end
        if level > 0 and run_x0 and level == run_lv then
          run_x1 = col_x1
        else
          if run_x0 then cell(c, canvas, run_x0, run_x1, y, h, run_lv, dim, sub) end
          if level > 0 then run_x0, run_x1, run_lv = col_x0, col_x1, level else run_x0 = nil end
        end
      end
      col_x0, col_x1, col_sum, col_n = x0, x1, v, 1
    end
  end
  if run_x0 then cell(c, canvas, run_x0, run_x1, y, h, run_lv, dim, sub) end
end

function M.attach(t) ctx = t end

function M.render()
  local c = ctx
  if not c then return end
  c.seg:ReleaseAllObjects()
  c.sub:ReleaseAllObjects()
  c.rim:ReleaseAllObjects()
  c.lbl:ReleaseAllObjects()
  c.hit_reset()
  hit.n = 0
  aggregate()
  local n = order.n
  if n == 0 then
    c.no_data:SetHidden(false)
    c.hide_grid(c.grid)
    return
  end
  c.no_data:SetHidden(true)

  local canvas = c.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= GUTTER_W + RIGHT_W + 40 or ch <= 4 then return end
  local TB = Vermilion.TemporalBuffer
  local recording = TB.is_recording()
  local t0   = totals.t0
  local t_hi = recording and c.now() or totals.t_hi
  local span = t_hi - t0
  if span <= 0 then span = 1 end
  Vermilion.Diagnostics.bump("graph.view_targets.renders")
  c.draw_grid(c.grid, canvas, 0, span)

  local top = (c.layout.H or 0) + (c.ult_inset and c.ult_inset() or 0)
  local ch_plot = math_max(4, ch - c.time_strip - top)
  local rows  = n
  local extra = 0
  local row_h = math_floor(ch_plot / rows) - ROW_GAP
  if row_h < MIN_ROW then
    rows = math_max(1, math_floor(ch_plot / (MIN_ROW + ROW_GAP)) - 1)
    if rows > n then rows = n end
    extra = (n > rows) and 1 or 0
    row_h = math_floor(ch_plot / (rows + extra)) - ROW_GAP
    if row_h < 6 then return end
  elseif row_h > MAX_ROW_H then
    row_h = MAX_ROW_H
  end
  max_scroll = (n > rows) and (n - rows) or 0
  if scroll > max_scroll then scroll = max_scroll end
  if scroll < 0 then scroll = 0 end
  local off = scroll

  local lane_x = GUTTER_W
  local lane_w = cw - GUTTER_W - RIGHT_W
  local bar_x  = lane_x + lane_w + BAR_PAD
  local bar_max = RIGHT_W - BAR_PAD * 2 - VAL_W
  local top_total = order[1].total
  local capture = not recording
  hit.n = capture and rows or 0
  hit.lane_x, hit.lane_w, hit.t0, hit.span = lane_x, lane_w, t0, span
  local hk = hover_id
  local ns = TB.count()
  local cell_max = totals.cell_max
  local abs_max = totals.abs_max or 0
  local sub_h = (abs_max > 0) and math_max(2, math_floor(row_h * 0.22)) or 0
  local main_h = row_h - ((sub_h > 0) and (sub_h + 1) or 0)
  for k = 1, ns do
    xs[k] = lane_x + math_floor((TB.at(k).t - t0) / span * lane_w + 0.5)
  end
  xs[ns + 1] = lane_x + lane_w

  for i = 1, rows do
    local rec = order[i + off]
    local y = top + (i - 1) * (row_h + ROW_GAP)
    local dim = (hk ~= nil and rec ~= hk)
    if capture then
      hit.y0[i] = y
      hit.y1[i] = y + row_h
      hit.lane[i] = rec
    end

    local lane = c.seg:AcquireObject()
    lane:ClearAnchors()
    lane:SetAnchor(TOPLEFT, canvas, TOPLEFT, lane_x, y)
    lane:SetWidth(lane_w)
    lane:SetHeight(row_h)
    lane:SetColor(C_LANE.r, C_LANE.g, C_LANE.b, C_LANE.a)
    lane:SetHidden(false)

    local lbl = c.lbl:AcquireObject()
    lbl:ClearAnchors()
    lbl:SetText(lane_label(rec))
    lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    lbl:SetMaxLineCount(1)
    lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if dim then
      lbl:SetColor(C_NAME.r * 0.45, C_NAME.g * 0.45, C_NAME.b * 0.45, 0.6)
    else
      lbl:SetColor(C_NAME.r, C_NAME.g, C_NAME.b, C_NAME.a)
    end
    lbl:SetDimensions(GUTTER_W - 12, row_h)
    lbl:SetAnchor(TOPLEFT, canvas, TOPLEFT, 6, y)
    lbl:SetHidden(false)

    if top_total > 0 then
      local bh = math_max(4, math_floor(row_h * 0.5))
      local by = y + math_floor((row_h - bh) / 2)
      local track = c.seg:AcquireObject()
      track:ClearAnchors()
      track:SetAnchor(TOPLEFT, canvas, TOPLEFT, bar_x, by)
      track:SetWidth(bar_max)
      track:SetHeight(bh)
      track:SetDrawLevel(3)
      track:SetColor(1, 1, 1, dim and 0.03 or 0.06)
      track:SetHidden(false)
      local bw = math_max(1, math_floor(bar_max * rec.total / top_total + 0.5))
      local rim = c.rim:AcquireObject()
      rim:ClearAnchors()
      rim:SetAnchor(TOPLEFT, canvas, TOPLEFT, bar_x - 1, by - 1)
      rim:SetWidth(bw + 2)
      rim:SetHeight(bh + 2)
      rim:SetColor(0, 0, 0, dim and 0.20 or 0.50)
      rim:SetHidden(false)
      local fill = c.seg:AcquireObject()
      fill:ClearAnchors()
      fill:SetAnchor(TOPLEFT, canvas, TOPLEFT, bar_x, by)
      fill:SetWidth(bw)
      fill:SetHeight(bh)
      fill:SetDrawLevel(4)
      fill:SetColor(C_HEAT.r, C_HEAT.g, C_HEAT.b, dim and 0.25 or 0.90)
      fill:SetHidden(false)
      if rec.abs > 0 and rec.total > 0 then
        local aw = math_floor(bw * rec.abs / rec.total + 0.5)
        if aw >= 1 and aw < bw then
          local tail = c.seg:AcquireObject()
          tail:ClearAnchors()
          tail:SetAnchor(TOPLEFT, canvas, TOPLEFT, bar_x + bw - aw, by)
          tail:SetWidth(aw)
          tail:SetHeight(bh)
          tail:SetDrawLevel(5)
          tail:SetColor(C_ORCHID.r, C_ORCHID.g, C_ORCHID.b, dim and 0.25 or 0.92)
          tail:SetHidden(false)
        end
      end
    end

    local disp = math_floor(rec.total)
    if rec.disp ~= disp then
      rec.disp = disp
      rec.text = c.fmt_val(rec.total)
    end
    local val = c.lbl:AcquireObject()
    val:ClearAnchors()
    val:SetText(rec.text)
    val:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    val:SetMaxLineCount(1)
    if dim then
      val:SetColor(C_VAL.r * 0.45, C_VAL.g * 0.45, C_VAL.b * 0.45, 0.6)
    else
      val:SetColor(C_VAL.r, C_VAL.g, C_VAL.b, C_VAL.a)
    end
    val:SetDimensions(VAL_W, row_h)
    val:SetAnchor(TOPLEFT, canvas, TOPLEFT, cw - VAL_W - BAR_PAD, y)
    val:SetHidden(false)

    lane_cells(c, canvas, rec.pv, ns, cell_max, y, main_h, dim, false)
    if sub_h > 0 then
      lane_cells(c, canvas, rec.av, ns, abs_max, y + row_h - sub_h, sub_h, dim, true)
    end
  end

  if c.ult_band then c.ult_band(t0, span, lane_x, lane_w, totals.t_hi) end
  if c.kill_pool then
    local pool = c.kill_pool()
    pool:ReleaseAllObjects()
    local K = c.kills and c.kills()
    local nk = K and K.count() or 0
    for i = 1, nk do
      local kt, kuid, kname = K.get(i)
      local row_i = nil
      for r = 1, rows do
        local rec = order[r + off]
        if (rec.is_player and rec.id == kuid) or (not rec.is_player and rec.raw == base_name(kname or "")) then row_i = r break end
      end
      if row_i and kt >= t0 and kt <= t_hi then
        local sz = (row_h < 16) and row_h or 16
        local x = lane_x + math_floor((kt - t0) / span * lane_w + 0.5)
        local y = top + (row_i - 1) * (row_h + ROW_GAP) + math_floor((row_h - sz) / 2)
        local icon = pool:AcquireObject()
        icon:ClearAnchors()
        icon:SetTexture(c.kill_icon)
        icon:SetDimensions(sz, sz)
        icon:SetColor(1, 0.92, 0.88, 0.95)
        icon:SetAnchor(TOPLEFT, canvas, TOPLEFT, x - math_floor(sz / 2), y)
        icon:SetHidden(false)
      end
    end
  end

  if n > rows then
    local more = c.lbl:AcquireObject()
    more:ClearAnchors()
    more:SetText(string_format(strings().scrolled, off, n - rows - off))
    more:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    more:SetColor(C_MORE.r, C_MORE.g, C_MORE.b, C_MORE.a)
    more:SetDimensions(cw, row_h)
    more:SetAnchor(TOPLEFT, canvas, TOPLEFT, 6, top + rows * (row_h + ROW_GAP))
    more:SetHidden(false)
  end
end

local function sample_at(t_abs)
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  local best = nil
  for i = 1, n do
    local s = TB.at(i)
    if s.t <= t_abs then best = s else break end
  end
  return best or TB.at(1)
end

function M.hover(mx, my)
  local c = ctx
  if not c then return end
  local canvas = c.canvas
  local rel_x = mx - canvas:GetLeft()
  local rel_y = my - canvas:GetTop()
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  local inside = rel_x >= 0 and rel_x <= cw and rel_y >= 0 and rel_y <= ch
  local rec = nil
  if inside then
    for i = 1, hit.n do
      if rel_y >= hit.y0[i] and rel_y <= hit.y1[i] then rec = hit.lane[i] break end
    end
  end
  local new = rec or nil
  if new ~= hover_id then hover_id = new; c.rerender() end
  if not rec or hit.span <= 0 then
    c.hide_card()
    return
  end
  local frac = (rel_x - hit.lane_x) / hit.lane_w
  if frac < 0 then frac = 0 end
  if frac > 1 then frac = 1 end
  local t_abs = hit.t0 + frac * hit.span
  local s = sample_at(t_abs)
  local eos = s and ((s.eDPS or 0) + (s.ShDPS or 0)) or 0
  local sh, ab = 0, 0
  if s then sh, ab = lane_share(s.targets, rec) end
  local v = sh * eos
  local av = ab * eos
  local S = strings()
  local stat
  if av > 0 then
    stat = string_format("%s DPS  ·  |c%02x%02x%02x%s %s|r", c.fmt_val(v),
      math_floor(C_ORCHID.r * 255 + 0.5), math_floor(C_ORCHID.g * 255 + 0.5), math_floor(C_ORCHID.b * 255 + 0.5),
      c.fmt_val(av), S.absorbed)
  else
    stat = string_format("%s DPS", c.fmt_val(v))
  end
  local n_rows = 0
  n_rows = n_rows + 1
  ROWS[n_rows][1], ROWS[n_rows][2] = S.damage, c.fmt_val(rec.total)
  ROWS[n_rows][3] = c.kinds and c.kinds.damage
  if rec.abs > 0 then
    n_rows = n_rows + 1
    ROWS[n_rows][1] = S.absorbed
    ROWS[n_rows][2] = string_format("%s  ·  %s", c.fmt_val(rec.abs), PCT_TEXT[math_floor(rec.abs / math_max(rec.total, 1) * 100 + 0.5)] or "")
    ROWS[n_rows][3] = c.kinds and c.kinds.shield
  end
  n_rows = n_rows + 1
  ROWS[n_rows][1] = S.share
  ROWS[n_rows][2] = PCT_TEXT[math_floor(rec.total / math_max(totals.damage, 1) * 100 + 0.5)] or ""
  ROWS[n_rows][3] = c.kinds and c.kinds.neutral
  if av > 0 and s and s.shield_abilities and (s.shield_abilities.count or 0) > 0 then
    local SC = Vermilion.SkillColors
    local sa = s.shield_abilities
    for k = 1, sa.count do
      if n_rows >= #ROWS then break end
      n_rows = n_rows + 1
      ROWS[n_rows][1] = S.shield
      ROWS[n_rows][2] = SC.ability_name(sa[k].id)
      ROWS[n_rows][3] = c.kinds and c.kinds.shield
    end
  end
  c.crosshair(math_floor(rel_x))
  local col = (av > 0) and C_ORCHID or C_HEAT
  c.show_card(col, lane_label(rec), stat,
    "t  " .. c.fmt_secs(t_abs - hit.t0), ROWS, n_rows, nil, mx, my)
end

function M.scroll(dir)
  local next_off = scroll + ((dir or 1) < 0 and -1 or 1)
  if next_off < 0 then next_off = 0 end
  if next_off > max_scroll then next_off = max_scroll end
  if next_off == scroll then return false end
  scroll = next_off
  return true
end

function M.reset_scroll() scroll = 0 end
function M.scroll_state() return scroll, max_scroll end
function M.hovered() return hover_id end
function M.clear_hover() hover_id = nil end
function M.rows() return order, order.n end
function M.compute()
  aggregate()
  return order, order.n, totals
end
function M.totals() return totals end
function M.lut(i) return Heat.lut(i) end
