Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.UptimeView = {}
local M = Vermilion.UptimeView

local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min
local string_format = string.format
local table_sort = table.sort

local RIGHT_W   = 176
local LANE_X    = 6
local GAP_X     = 12
local HDR_H     = 16
local SEC_GAP   = 6
local ROW_H     = 18
local ROW_GAP   = 3
local NAME_W    = 96
local PCT_W     = 40
local ICON      = 14
local LIST_ROW  = 28
local LIST_GAP  = 2
local VAL_W     = 52
local ERR_H     = 64
local ERR_LIMIT = 4
local TOL_S     = 0.5
local MIN_ROW_DUR = 2000
local COST_MIN_DUR = 6000
local STEADY_MIN = 3
local TOT_H = HDR_H + 2 * 14 + 8
local totals = { clip = 0, late = 0, late_n = 0, shown = false }
local C_DIM     = { r = 0.62, g = 0.58, b = 0.56 }
local C_TEXT    = { r = 0.94, g = 0.88, b = 0.86 }
local C_GOLD    = { r = 0.80, g = 0.68, b = 0.40 }
local C_OUT     = { r = 0.86, g = 0.28, b = 0.18 }
local C_IN      = { r = 0.46, g = 0.80, b = 0.35 }
local C_OTHER   = { r = 0.72, g = 0.66, b = 0.58 }
local C_MID     = { r = 1, g = 1, b = 1 }

local PCT_TEXT = {}
for i = 0, 100 do PCT_TEXT[i] = i .. "%" end

local ctx = nil
local scroll = { 0, 0, 0 }
local max_scroll = { 0, 0, 0 }
local SEC_ROWS, SEC_COST, SEC_REF = 1, 2, 3
local sec_rect = { { y0 = 0, y1 = 0 }, { y0 = 0, y1 = 0 }, { y0 = 0, y1 = 0 } }
local hover_key = nil
local lane = { x = 0, w = 0, y = 0, h = 0, t0 = 0, span = 0 }
local row_hit = { n = 0, x0 = {}, x1 = {}, y0 = {}, y1 = {}, key = {} }
local rows = {}
local order = { n = 0 }
local cost_order = { n = 0 }
local ROWS = { {}, {}, {}, {}, {}, {}, {} }
local str = nil
local cur_t0 = nil
local scale = { x0 = 0, w = 0, t0 = 0, span = 1 }
local gen = 0

local function strings()
  if str then return str end
  str = {
    cost      = GetString(VERMILION_UPTH_COST),
    refreshes = GetString(VERMILION_UPTH_REFRESHES),
    error     = GetString(VERMILION_UPTH_ERROR),
    uptime    = GetString(VERMILION_UPTH_UPTIME),
    apps      = GetString(VERMILION_UPTH_APPS),
    presses   = GetString(VERMILION_UPTH_PRESSES),
    early     = GetString(VERMILION_UPTH_EARLY),
    late      = GetString(VERMILION_UPTH_LATE),
    mean      = GetString(VERMILION_UPTH_MEAN),
    down      = GetString(VERMILION_UPTH_DOWN),
    lost      = GetString(VERMILION_UPTH_LOST),
    early_by  = GetString(VERMILION_UPT_EARLY_BY),
    late_by   = GetString(VERMILION_UPT_LATE_BY),
    on_time   = GetString(VERMILION_UPT_ON_TIME),
    stat      = GetString(VERMILION_UPT_CARD_STAT),
    sub_cost  = GetString(VERMILION_UPT_SUB_COST),
    sub_ref   = GetString(VERMILION_UPT_SUB_REF),
    axis_x    = GetString(VERMILION_UPT_AXIS_X),
    axis_y    = GetString(VERMILION_UPT_AXIS_Y),
    skill     = GetString(VERMILION_UPT_SKILL),
    other     = GetString(VERMILION_UPT_OTHER),
    more      = GetString(VERMILION_UPT_MORE),
    err_title = GetString(VERMILION_UPT_ERR_TITLE),
    on_time_l = GetString(VERMILION_UPT_ON_TIME_LABEL),
    steady    = GetString(VERMILION_UPTH_STEADY),
    totals    = GetString(VERMILION_UPTH_TOTALS),
    clipped   = GetString(VERMILION_UPT_CLIPPED),
    late_avg  = GetString(VERMILION_UPT_LATE_AVG),
  }
  return str
end

local function kind(c, name) return c.kinds and c.kinds[name] or nil end

local function row_for(k)
  local r = rows[k]
  if not r then
    r = { k = k, t0 = {}, t1 = {}, idx = {}, mt0 = {}, mt1 = {}, n = 0, mn = 0, pt = {}, pe = {}, pc = {}, pn = 0,
          covered = 0, uptime = 0, dur = 0, dps = 0, cost = 0, down = 0, early = 0, late = 0, mean_e = 0, n_err = 0,
          first = 0, apps = 0, icon = nil, col = C_OTHER, name = "", slot = false, ult = false, id = 0, gen = -1, pct_text = "", cost_text = "", sub_text = "",
          iv_n = 0, iv_sum = 0, iv_sq = 0, steady = 0, sd = 0 }
    rows[k] = r
  end
  return r
end

local function by_t0(a, b) return cur_t0[a] < cur_t0[b] end

local function scan_bar_ids(nk, names)
  local api, zc = Vermilion.zenimax.api, Vermilion.zenimax.constants
  if not api.GetSlotBoundId then return end
  for _, cat in ipairs({ zc.HOTBAR_CATEGORY_PRIMARY, zc.HOTBAR_CATEGORY_BACKUP }) do
    for slot = 3, 8 do
      local id = api.GetSlotBoundId(slot, cat)
      if id and id > 0 then
        local nm = api.GetAbilityName(id)
        for k = 1, nk do
          if names[k] == nm and rows[k] then
            if rows[k].id == 0 then rows[k].id = id end
            if slot == 8 then rows[k].ult = true end
          end
        end
      end
    end
  end
end

local function scan_cast_ids(nk, names)
  local need = false
  for k = 1, nk do
    if rows[k].slot and rows[k].id == 0 then need = true break end
  end
  if not need then return end
  local _, cast_id, _, _, n = Vermilion.Casts.records()
  local tried = {}
  for i = 1, n do
    local id = cast_id[i]
    if id and id > 0 and not tried[id] then
      tried[id] = true
      local nm = Vermilion.zenimax.api.GetAbilityName(id)
      for k = 1, nk do
        if names[k] == nm and rows[k].slot and rows[k].id == 0 then rows[k].id = id end
      end
    end
  end
end

local function dress(r)
  if r.id > 0 and r.icon == nil then
    local SC = Vermilion.SkillColors
    local icon = SC.ability_icon(r.id) or ""
    r.icon = (icon ~= "" and not icon:lower():find("icon_missing", 1, true)) and icon or false
    r.col = r.slot and (SC.group_color(SC.group_of(r.id)) or C_OTHER) or C_OTHER
  elseif r.icon == nil then
    r.icon = false
    r.col = C_OTHER
  end
end

local function by_covered(a, b)
  local ra, rb = rows[a], rows[b]
  if ra.slot ~= rb.slot then return ra.slot end
  return ra.covered > rb.covered
end

local function by_cost(a, b) return rows[a].cost > rows[b].cost end

local function overlap(a, b, lo, hi)
  if lo then
    if a < lo then a = lo end
    if b > hi then b = hi end
  end
  return (b > a) and (b - a) or 0
end

local function build(TB, t_hi)
  gen = gen + 1
  local lo, hi = Vermilion.Metrics.fight_bounds()
  local U = Vermilion.Uptime
  local names, slots, nk, ids = U.keys()
  for k = 1, nk do
    local r = row_for(k)
    r.n, r.mn, r.pn, r.covered, r.early, r.late, r.mean_e, r.n_err, r.first, r.apps, r.dur = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    r.iv_n, r.iv_sum, r.iv_sq, r.steady, r.sd, r.ult = 0, 0, 0, 0, 0, false
    if r.name ~= names[k] then r.id, r.icon, r.col = 0, nil, C_OTHER end
    r.name, r.slot, r.gen = names[k], slots[k] == true, gen
  end
  local sk, _, st0, st1, sn = U.spans()
  for i = 1, sn do
    local r = rows[sk[i]]
    if r then
      r.n = r.n + 1
      r.t0[r.n], r.t1[r.n] = st0[i], st1[i]
      r.dur = r.dur + (st1[i] - st0[i])
    end
  end
  local ok_, _, ot0, _, on = U.open_spans()
  for i = 1, on do
    local r = rows[ok_[i]]
    if r then
      r.n = r.n + 1
      r.t0[r.n], r.t1[r.n] = ot0[i], math_max(ot0[i], t_hi)
      r.dur = r.dur + (t_hi - ot0[i])
    end
  end
  local pk, _, pt, pe, pkind, pn = U.presses()
  for i = 1, pn do
    local r = rows[pk[i]]
    if r then
      r.pn = r.pn + 1
      r.pt[r.pn], r.pe[r.pn] = pt[i], pe[i]
      r.pc[r.pn] = (pe[i] > 0) and pe[i] or 0
      if pkind[i] ~= U.KIND_FRESH then
        r.n_err = r.n_err + 1
        r.mean_e = r.mean_e + pe[i]
        if pe[i] > 500 then r.early = r.early + 1 elseif pe[i] < -500 then r.late = r.late + 1 end
      end
    end
  end
  local dmg, _ = Vermilion.DamageNames.by_name(TB)
  scan_bar_ids(nk, names)
  scan_cast_ids(nk, names)
  for k = 1, nk do
    local r = rows[k]
    if r.id == 0 and ids and (ids[k] or 0) > 0 then r.id = ids[k] end
    r.apps = 0
    for i = 1, r.n do
      if not lo or overlap(r.t0[i], r.t1[i], lo, hi) > 0 then r.apps = r.apps + 1 end
    end
    if r.n > 0 then r.dur = r.dur / r.n end
    for i = 1, r.n do r.idx[i] = i end
    for i = r.n + 1, #r.idx do r.idx[i] = nil end
    cur_t0 = r.t0
    if r.n > 1 then table_sort(r.idx, by_t0) end
    local ma, mb = nil, nil
    r.mn = 0
    for j = 1, r.n do
      local i = r.idx[j]
      local a, b = r.t0[i], r.t1[i]
      if ma and a <= mb then
        if b > mb then mb = b end
      else
        if ma then r.mn = r.mn + 1; r.mt0[r.mn], r.mt1[r.mn] = ma, mb; r.covered = r.covered + overlap(ma, mb, lo, hi) end
        ma, mb = a, b
      end
    end
    if ma then r.mn = r.mn + 1; r.mt0[r.mn], r.mt1[r.mn] = ma, mb; r.covered = r.covered + overlap(ma, mb, lo, hi) end
    r.first = (r.mn > 0) and r.mt0[1] or t_hi
    local window = t_hi - r.first
    if lo then window = hi - math_max(lo, r.first) end
    local fight = Vermilion.Metrics.fight_ms()
    local over = (fight > 0) and fight or window
    r.uptime = (over > 0) and math_min(1, r.covered / over) or 0
    r.down = math_max(0, window - r.covered)
    local d = dmg[r.name] or 0
    r.dps = (r.covered > 0) and d / (r.covered / 1000) or 0
    r.cost = r.dps * (r.down / 1000)
    if r.n_err > 0 then r.mean_e = r.mean_e / r.n_err end
    dress(r)
  end
  order.n = 0
  cost_order.n = 0
  for k = 1, nk do
    local r = rows[k]
    if r.n > 0 and r.dur >= MIN_ROW_DUR then
      order.n = order.n + 1; order[order.n] = k
      if r.cost > 0 and r.slot and not r.ult and r.dur >= COST_MIN_DUR then cost_order.n = cost_order.n + 1; cost_order[cost_order.n] = k end
    end
  end
  for i = order.n + 1, #order do order[i] = nil end
  for i = cost_order.n + 1, #cost_order do cost_order[i] = nil end
  if order.n > 1 then table_sort(order, by_covered) end
  if cost_order.n > 1 then table_sort(cost_order, by_cost) end
end

local function hit_add(x0, x1, y0, y1, k)
  local n = row_hit.n + 1
  row_hit.n = n
  row_hit.x0[n], row_hit.x1[n], row_hit.y0[n], row_hit.y1[n], row_hit.key[n] = x0, x1, y0, y1, k
end

local function err_text(c, S, r)
  if r.n_err == 0 then return S.on_time end
  local e = r.mean_e / 1000
  if e > TOL_S then return string_format(S.early_by, c.fmt_secs(r.mean_e)) end
  if e < -TOL_S then return string_format(S.late_by, c.fmt_secs(-r.mean_e)) end
  return S.on_time
end

local function draw_time(c, S, y)
  local SF = Vermilion.lib.viz.surface
  local h = c.time_strip - 2
  SF.label(c, "0s", scale.x0, y, 40, h, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  SF.label(c, c.fmt_secs(scale.span / 2), scale.x0 + math_floor(scale.w / 2) - 25, y, 50, h, TEXT_ALIGN_CENTER, C_DIM, 0.9)
  SF.label(c, c.fmt_secs(scale.span), scale.x0 + scale.w - 50, y, 50, h, TEXT_ALIGN_RIGHT, C_DIM, 0.9)
end

local function draw_rows(c, canvas, x, y, w, h, S)
  local SF, SP = Vermilion.lib.viz.surface, Vermilion.lib.viz.spans
  local n = order.n
  local slots = math_floor((h - 4) / (ROW_H + ROW_GAP))
  if slots < 0 then slots = 0 end
  if slots > n then slots = n end
  max_scroll[SEC_ROWS] = (n > slots) and (n - slots) or 0
  if scroll[SEC_ROWS] > max_scroll[SEC_ROWS] then scroll[SEC_ROWS] = max_scroll[SEC_ROWS] end
  local off = scroll[SEC_ROWS]
  local x_icon = x + 4
  local x_name = x_icon + ICON + 4
  scale.x0, scale.w = x_name + NAME_W + 6, w - (NAME_W + ICON + 14) - PCT_W - 8
  local ry = y + 2
  for i = 1, slots do
    local k = order[i + off]
    local r = rows[k]
    local dim = (hover_key ~= nil and k ~= hover_key)
    local a = dim and 0.45 or 1
    hit_add(x, x + w, ry, ry + ROW_H, k)
    if r.icon then SF.icon(c, r.icon, x_icon, ry + 2, ICON, a) end
    SF.label(c, r.name, x_name, ry, NAME_W, ROW_H, TEXT_ALIGN_LEFT, r.slot and C_TEXT or C_DIM, a)
    SP.row(c, scale, ry + 3, ROW_H - 6, r.col, r.mt0, r.mt1, r.mn, r.pt, r.pn, r.pc, nil)
    r.pct_text = PCT_TEXT[math_floor(r.uptime * 100 + 0.5)] or ""
    SF.label(c, r.pct_text, x + w - PCT_W - 4, ry, PCT_W, ROW_H, TEXT_ALIGN_RIGHT, (r.uptime >= 0.9) and C_IN or (r.uptime >= 0.7) and C_GOLD or C_OUT, a)
    ry = ry + ROW_H + ROW_GAP
  end
  local rest = n - slots - off
  if rest > 0 then SF.label(c, string_format(S.more, rest), x + w - 90, y + h - 14, 86, 12, TEXT_ALIGN_RIGHT, C_DIM, 0.8) end
  sec_rect[SEC_ROWS].y0, sec_rect[SEC_ROWS].y1 = y, y + h
  SF.frame(c, x, y, x + w, y + h, C_GOLD, 0.38, 6)
end

local function draw_errors(c, canvas, x, y, w, h, S)
  local SF, ST = Vermilion.lib.viz.surface, Vermilion.lib.viz.stems
  local k = hover_key or order[1]
  if not k then return end
  local r = rows[k]
  SF.label(c, S.error, x + 4, y, 120, HDR_H, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  SF.label(c, r.name, x + 110, y, 170, HDR_H, TEXT_ALIGN_LEFT, r.col, 0.95)
  SF.label(c, string_format(S.err_title, r.pn, r.early, r.late), x + 290, y, w - 440, HDR_H, TEXT_ALIGN_LEFT, C_DIM, 0.85)
  SF.label(c, err_text(c, S, r), x + w - 150, y, 146, HDR_H, TEXT_ALIGN_RIGHT, (r.mean_e > TOL_S * 1000) and C_GOLD or (r.mean_e < -TOL_S * 1000) and C_OUT or C_IN, 0.95)
  SF.box(c, x, x + w, y + HDR_H - 1, 1, C_GOLD, 0.25, 2)
  local ph = h - HDR_H - 6
  if ph < 20 then return end
  ST.plot(c, scale, y + HDR_H + 3, ph, r.pt, r.pe, r.pn, -ERR_LIMIT * 1000, ERR_LIMIT * 1000, -TOL_S * 1000, TOL_S * 1000, C_GOLD, C_OUT, C_IN, nil)
  SF.label(c, "+" .. ERR_LIMIT .. "s", scale.x0 + scale.w + 4, y + HDR_H + 2, 30, 12, TEXT_ALIGN_LEFT, C_GOLD, 0.8)
  SF.label(c, S.on_time_l, scale.x0 + scale.w + 4, y + HDR_H + 3 + math_floor(ph / 2) - 6, 60, 12, TEXT_ALIGN_LEFT, C_IN, 0.8)
  SF.label(c, "-" .. ERR_LIMIT .. "s", scale.x0 + scale.w + 4, y + h - 14, 30, 12, TEXT_ALIGN_LEFT, C_OUT, 0.8)
  SF.label(c, S.early, scale.x0 - 44, y + HDR_H + 2, 40, 12, TEXT_ALIGN_RIGHT, C_GOLD, 0.7)
  SF.label(c, S.late, scale.x0 - 44, y + h - 14, 40, 12, TEXT_ALIGN_RIGHT, C_OUT, 0.7)
  SF.frame(c, x, y, x + w, y + h, C_GOLD, 0.38, 6)
end

local function draw_list(c, canvas, x, y, w, sec, title, S, src, rows_max)
  local SF, RG = Vermilion.lib.viz.surface, Vermilion.lib.viz.ring
  local n = src.n
  SF.label(c, title, x + 4, y, w - 64, HDR_H, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  SF.box(c, x, y + HDR_H - 1, x + w, 1, C_GOLD, 0.25, 2)
  if rows_max > n then rows_max = n end
  max_scroll[sec] = (n > rows_max) and (n - rows_max) or 0
  if scroll[sec] > max_scroll[sec] then scroll[sec] = max_scroll[sec] end
  local off = scroll[sec]
  local rest = n - rows_max - off
  if rest > 0 then SF.label(c, string_format(S.more, rest), x + w - 74, y, 70, HDR_H, TEXT_ALIGN_RIGHT, C_DIM, 0.8) end
  local ry = y + HDR_H + 2
  local top = (n > 0) and rows[src[1]].cost or 0
  local x_name = x + 4 + ((sec ~= SEC_COST) and 24 or ICON) + 6
  local name_w = w - 4 - ((sec ~= SEC_COST) and 24 or ICON) - 6 - VAL_W - 6
  for i = 1, rows_max do
    local k = src[i + off]
    local r = rows[k]
    local dim = (hover_key ~= nil and k ~= hover_key)
    local a = dim and 0.45 or 1
    hit_add(x, x + w, ry, ry + LIST_ROW, k)
    if sec == SEC_COST then
      if r.icon then SF.icon(c, r.icon, x + 4, ry + math_floor((LIST_ROW - ICON) / 2), ICON, a) end
      SF.label(c, r.name, x_name, ry + 1, name_w, 14, TEXT_ALIGN_LEFT, C_TEXT, a)
      local by = ry + 17
      SF.box(c, x_name, x_name + name_w, by, 4, C_MID, dim and 0.03 or 0.06, 2)
      if top > 0 then
        local bw = math_floor(name_w * r.cost / top + 0.5)
        if bw < 1 then bw = 1 end
        SF.box(c, x_name, x_name + bw, by, 4, C_OUT, dim and 0.3 or 0.9, 3)
      end
      r.cost_text = "-" .. c.fmt_val(r.cost)
      r.sub_text = string_format(S.sub_cost, c.fmt_secs(r.down))
      SF.label(c, r.cost_text, x + w - VAL_W - 4, ry, VAL_W, 12, TEXT_ALIGN_RIGHT, C_OUT, a)
      SF.label(c, r.sub_text, x + w - VAL_W - 4, ry + 12, VAL_W, 12, TEXT_ALIGN_RIGHT, C_DIM, a * 0.85)
    else
      RG.gauge(c, x + 4 + 10, ry + math_floor(LIST_ROW / 2), 9, r.uptime, r.col, 3, nil)
      SF.label(c, r.name, x_name, ry + 1, name_w, 14, TEXT_ALIGN_LEFT, C_TEXT, a)
      r.sub_text = string_format(S.sub_ref, r.early, r.late)
      SF.label(c, r.sub_text, x_name, ry + 13, name_w, 11, TEXT_ALIGN_LEFT, C_DIM, a * 0.85)
      SF.label(c, PCT_TEXT[math_floor(r.uptime * 100 + 0.5)] or "", x + w - VAL_W - 4, ry, VAL_W, LIST_ROW, TEXT_ALIGN_RIGHT, (r.uptime >= 0.9) and C_IN or (r.uptime >= 0.7) and C_GOLD or C_OUT, a)
    end
    ry = ry + LIST_ROW + LIST_GAP
  end
  local y1 = ry + 2
  sec_rect[sec].y0, sec_rect[sec].y1 = y, y1
  SF.frame(c, x, y, x + w, y1, C_GOLD, 0.38, 6)
  return y1
end

local function draw_lists(c, canvas, cw, y, h, S)
  local x = cw - RIGHT_W
  local slots = math_floor((h - 2 * (HDR_H + 4) - SEC_GAP) / (LIST_ROW + LIST_GAP))
  if slots < 0 then slots = 0 end
  local na, nb = cost_order.n, order.n
  local rows_a = math_floor(slots / 2)
  if rows_a > na then rows_a = na end
  local rows_b = slots - rows_a
  if rows_b > nb then rows_b = nb end
  rows_a = slots - rows_b
  if rows_a > na then rows_a = na end
  local y1 = y
  if rows_a > 0 or na > 0 then
    y1 = draw_list(c, canvas, x, y, RIGHT_W, SEC_COST, S.cost, S, cost_order, rows_a) + SEC_GAP
  else
    sec_rect[SEC_COST].y0, sec_rect[SEC_COST].y1 = 0, 0
  end
  local y2 = draw_list(c, canvas, x, y1, RIGHT_W, SEC_REF, S.refreshes, S, order, rows_b) + SEC_GAP
  totals.clip, totals.late, totals.late_n, totals.shown = 0, 0, 0, false
  for oi = 1, order.n do
    local r = rows[order[oi]]
    if r.slot then
      for i = 1, r.pn do
        local e = r.pe[i]
        if e > TOL_S * 1000 then
          totals.clip = totals.clip + e
        elseif e < -TOL_S * 1000 then
          totals.late = totals.late - e
          totals.late_n = totals.late_n + 1
        end
      end
    end
  end
  if y2 + TOT_H > y + h then return end
  totals.shown = true
  local SF = Vermilion.lib.viz.surface
  SF.label(c, S.totals, x + 4, y2, RIGHT_W - 8, HDR_H, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  SF.box(c, x, x + RIGHT_W, y2 + HDR_H - 1, 1, C_GOLD, 0.25, 2)
  local ty = y2 + HDR_H + 3
  SF.label(c, S.clipped, x + 6, ty, RIGHT_W - VAL_W - 12, 14, TEXT_ALIGN_LEFT, C_TEXT, 0.9)
  SF.label(c, c.fmt_secs(totals.clip), x + RIGHT_W - VAL_W - 4, ty, VAL_W, 14, TEXT_ALIGN_RIGHT, (totals.clip > 0) and C_GOLD or C_IN, 1)
  SF.label(c, S.late_avg, x + 6, ty + 14, RIGHT_W - VAL_W - 12, 14, TEXT_ALIGN_LEFT, C_TEXT, 0.9)
  SF.label(c, c.fmt_secs((totals.late_n > 0) and totals.late / totals.late_n or 0), x + RIGHT_W - VAL_W - 4, ty + 14, VAL_W, 14, TEXT_ALIGN_RIGHT, (totals.late_n > 0) and C_OUT or C_IN, 1)
  SF.frame(c, x, y2, x + RIGHT_W, y2 + TOT_H, C_GOLD, 0.38, 6)
end

function M.totals() return totals end

local function compute_steady()
  local pk, pu, pt, _, _, pn = Vermilion.Uptime.presses()
  for i = 1, pn do
    local k = pk[i]
    local r = rows[k]
    if r and r.slot and r.n > 0 and r.dur >= MIN_ROW_DUR then
      local j = i - 1
      while j >= 1 and i - j <= 400 do
        if pk[j] == k and pu[j] == pu[i] then
          local iv = (pt[i] - pt[j]) / 1000
          r.iv_n = r.iv_n + 1
          r.iv_sum = r.iv_sum + iv
          r.iv_sq = r.iv_sq + iv * iv
          break
        end
        j = j - 1
      end
    end
  end
  for oi = 1, order.n do
    local r = rows[order[oi]]
    if r.slot and r.iv_n >= STEADY_MIN then
      local mean = r.iv_sum / r.iv_n
      local var = r.iv_sq / r.iv_n - mean * mean
      if var < 0 then var = 0 end
      r.sd = math.sqrt(var)
      local cv = (mean > 0) and r.sd / mean or 1
      r.steady = 1 - cv
      if r.steady < 0 then r.steady = 0 end
    end
  end
end

function M.attach(t)
  ctx = t
end

function M.render()
  local c = ctx
  if not c then return end
  c.seg:ReleaseAllObjects()
  c.lbl:ReleaseAllObjects()
  if c.icon then c.icon:ReleaseAllObjects() end
  if c.panels then c.panels:ReleaseAllObjects() end
  if c.line then c.line:ReleaseAllObjects() end
  if c.cd then c.cd:ReleaseAllObjects() end
  c.hit_reset()
  row_hit.n = 0
  lane.span = 0
  c.hide_grid(c.grid)
  Vermilion.lib.viz.surface.begin(c)
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if n == 0 then
    c.no_data:SetHidden(false)
    return
  end
  local recording = TB.is_recording()
  local t0 = TB.at(1).t
  local t_hi = recording and c.now() or TB.at(n).t
  local span = t_hi - t0
  if span <= 0 then span = 1 end
  build(TB, t_hi)
  if order.n == 0 then
    c.no_data:SetText(GetString(VERMILION_GRAPH_NO_UPTIME))
    c.no_data:SetHidden(false)
    return
  end
  c.no_data:SetHidden(true)
  Vermilion.Diagnostics.bump("graph.view_upt.renders")
  local canvas = c.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= RIGHT_W + 80 or ch <= 40 then return end
  local S = strings()
  local top = (c.layout.H or 0) + 2
  local y = top + 2
  local h = math_max(8, ch - c.time_strip - y - 2)
  local w = cw - RIGHT_W - LANE_X - GAP_X
  lane.x, lane.w, lane.y, lane.h, lane.t0, lane.span = LANE_X, w, y, h, t0, span
  scale.t0, scale.span = t0, span
  compute_steady()
  local h_err = math_min(ERR_H + HDR_H + 50, math_floor(h * 0.38))
  local h_rows = h - h_err - c.time_strip - 2
  draw_rows(c, canvas, LANE_X, y, w, h_rows, S)
  draw_time(c, S, y + h_rows + 1)
  draw_errors(c, canvas, LANE_X, y + h_rows + c.time_strip + 2, w, h_err, S)
  draw_lists(c, canvas, cw, y, h, S)
end

local function row_card(c, r, S, mx, my)
  local nr = 0
  nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.uptime, PCT_TEXT[math_floor(r.uptime * 100 + 0.5)] or "", (r.uptime >= 0.9) and C_IN or (r.uptime >= 0.7) and C_GOLD or C_OUT
  nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.apps, tostring(r.apps), kind(c, "neutral")
  nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.presses, string_format("%d  ·  %d %s  ·  %d %s", r.pn, r.early, S.early, r.late, S.late), kind(c, "neutral")
  nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.mean, err_text(c, S, r), (r.mean_e > TOL_S * 1000) and C_GOLD or (r.mean_e < -TOL_S * 1000) and C_OUT or C_IN
  nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.down, c.fmt_secs(r.down), kind(c, "time")
  if r.slot and r.iv_n >= STEADY_MIN then
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.steady, string_format("%s  ·  ±%s", PCT_TEXT[math_floor(r.steady * 100 + 0.5)] or "", c.fmt_secs(r.sd * 1000)), (r.steady >= 0.8) and C_IN or (r.steady >= 0.6) and C_GOLD or C_OUT
  end
  if M.priced(r) then
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.lost, "-" .. c.fmt_val(r.cost), C_OUT
  end
  c.show_card(r.col, r.name, r.slot and S.skill or S.other, "", ROWS, nr, nil, mx, my, r.icon or nil)
end

function M.hover(mx, my)
  local c = ctx
  if not c then return end
  local canvas = c.canvas
  local rel_x, rel_y = mx - canvas:GetLeft(), my - canvas:GetTop()
  local S = strings()
  local k = nil
  for i = 1, row_hit.n do
    if rel_x >= row_hit.x0[i] and rel_x <= row_hit.x1[i] and rel_y >= row_hit.y0[i] and rel_y <= row_hit.y1[i] then k = row_hit.key[i] break end
  end
  if k ~= hover_key then hover_key = k; c.rerender() end
  if k then
    row_card(c, rows[k], S, mx, my)
    return
  end
  c.hide_card()
end

function M.click() return false end

function M.scroll(dir)
  local c = ctx
  if not c then return false end
  local mx, my = GetUIMousePosition()
  local rel_x, rel_y = mx - c.canvas:GetLeft(), my - c.canvas:GetTop()
  local sec = nil
  if rel_x < c.canvas:GetWidth() - RIGHT_W then
    local rb = sec_rect[SEC_ROWS]
    if rb.y1 > rb.y0 and rel_y >= rb.y0 and rel_y <= rb.y1 then sec = SEC_ROWS end
  else
    for s = SEC_COST, SEC_REF do
      local rb = sec_rect[s]
      if rb.y1 > rb.y0 and rel_y >= rb.y0 and rel_y <= rb.y1 then sec = s end
    end
  end
  if not sec then return false end
  local next_off = scroll[sec] + ((dir or 1) < 0 and -1 or 1)
  if next_off < 0 then next_off = 0 end
  if next_off > max_scroll[sec] then next_off = max_scroll[sec] end
  if next_off == scroll[sec] then return false end
  scroll[sec] = next_off
  return true
end

function M.reset_scroll() scroll[1], scroll[2], scroll[3] = 0, 0, 0 end
function M.clear_hover() hover_key = nil end
function M.hovered() return hover_key end
function M.rows() return order, order.n, rows end
function M.priced(r)
  return r.cost > 0 and r.slot and not r.ult and r.dur >= COST_MIN_DUR
end

function M.compute()
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if n == 0 then return order, 0, rows end
  build(TB, TB.at(n).t)
  compute_steady()
  return order, order.n, rows
end
function M.costs() return cost_order, cost_order.n end
function M.lane() return lane end
function M.rects() return sec_rect end
