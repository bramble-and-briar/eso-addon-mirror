Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ResourcesView = {}
local M = Verdant.ResourcesView

local zc = Verdant.zenimax.constants
local api = Verdant.zenimax.api
local GetString = api.GetString
local TOPLEFT = zc.TOPLEFT
local TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_LEFT, zc.TEXT_ALIGN_RIGHT, zc.TEXT_ALIGN_CENTER
local TEXT_WRAP_MODE_ELLIPSIS = zc.TEXT_WRAP_MODE_ELLIPSIS
local math_floor    = math.floor
local math_max      = math.max
local math_min      = math.min
local math_ceil     = math.ceil
local string_format = string.format
local table_sort    = table.sort

local PICK_MAG, PICK_STA, PICK_BOTH = 1, 2, 3
local MAG, STA  = 1, 2
local PICK_H    = 20
local RIGHT_W   = 176
local ICON      = 18
local ROW_H     = 24
local ROW_GAP   = 2
local NAME_H    = 14
local BAR_H     = 5
local VAL_W     = 46
local HDR_H     = 16
local SEC_GAP   = 6
local LANE_X    = 6
local GAP_X     = 12
local LOW       = 0.30
local STARVE    = 0.15
local STARVE_MS = 2000
local TICK_H    = 3
local WINDOW_MS = 10000
local RATE_MS   = 5000
local SIGMA_BACK = 10
local C_DIM     = { r = 0.62, g = 0.66, b = 0.64 }
local C_TEXT    = { r = 0.88, g = 0.94, b = 0.90 }
local C_OUT     = { r = 0.86, g = 0.50, b = 0.44 }
local C_MID     = { r = 1.00, g = 1.00, b = 1.00 }
local C_WARN    = { r = 0.95, g = 0.80, b = 0.30 }
local C_LOW     = { r = 0.93, g = 0.36, b = 0.30 }
local C_SEP     = { r = 0.62, g = 0.80, b = 0.66 }
local C_LEAD    = { r = 1.00, g = 0.85, b = 0.40 }
local C_REGEN   = { r = 0.70, g = 0.66, b = 0.64 }
local C_TIME    = { r = 0.78, g = 0.80, b = 0.74 }
local ICON_POOL = { "EsoUI/Art/Champion/champion_points_magicka_icon.dds", "EsoUI/Art/Champion/champion_points_stamina_icon.dds" }
local TEX_SKULL = "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds"

local RACE_LANE_H, RACE_RUN_H = 12, 6
local RACE_GROUND_A, RACE_PACE_A, RACE_MARK_A, RACE_RUN_A = 0.05, 0.30, 0.90, 0.95
local RACE_GRID_A, RACE_TEXT_A = 0.07, 0.45
local RACE_TEXT_W, RACE_TEXT_H = 40, 12
local RACE_STEPS = { 1, 2, 5, 10, 20, 25, 50, 100 }
local RACE_MAX_LINES = 5

local PCT_TEXT = {}
for i = 0, 100 do PCT_TEXT[i] = i .. "%" end

local ctx = nil
local C_MAG, C_STA, C_CONTRIB
local pick = PICK_BOTH
local scroll = { 0, 0, 0 }
local max_scroll = { 0, 0, 0 }
local hover_row = nil
local RS = Verdant.ResourceSums
local st = RS.state(function(id, sec)
  return { id = id, sec = sec, name = nil, icon = nil, r = 0, g = 0, b = 0, n = 0, mag = 0, sta = 0, total = 0, gen = -1, disp = -1, text = "",
           con = 0, eff_disp = -1, eff_text = "", ret = 0 }
end)
local order, totals, race_order, contrib = st.order, st.totals, st.race, st.contrib
local sums = nil
local lane = { x = 0, w = 0, y = 0, h = 0, t0 = 0, span = 0, mid = 0 }
local pick_hit = { { x0 = 0, x1 = 0 }, { x0 = 0, x1 = 0 }, { x0 = 0, x1 = 0 }, y0 = 0, y1 = 0 }
local row_hit = { n = 0, x0 = {}, x1 = {}, y0 = {}, y1 = {}, rec = {}, sec = {} }
local sec_rect = { { y0 = 0, y1 = 0 }, { y0 = 0, y1 = 0 }, { y0 = 0, y1 = 0 } }
local ROWS = { {}, {}, {}, {}, {} }
local col_cache = {}
local rate_in, rate_out = {}, {}
local str = nil
local SEC_SPENT, SEC_REC, SEC_RACE = 1, 2, 3
local RIB_H     = 12
local RUG_H     = 26
local RACE_ROW  = 22
local RACE_PAD  = 4

local function strings()
  if str then return str end
  str = {
    pick      = { GetString(VERDANT_RES_PICK_MAG), GetString(VERDANT_RES_PICK_STA), GetString(VERDANT_RES_PICK_BOTH) },
    pools     = { GetString(VERDANT_RES_MAGICKA), GetString(VERDANT_RES_STAMINA) },
    spent     = GetString(VERDANT_RESH_SPENT),
    recovered = GetString(VERDANT_RESH_RECOVERED),
    recovery  = GetString(VERDANT_RESH_RECOVERY),
    rec_by    = GetString(VERDANT_RESH_RECOVERED_BY),
    regen     = GetString(VERDANT_RESH_REGEN),
    restores  = GetString(VERDANT_RESH_RESTORES),
    rec_total = GetString(VERDANT_RESH_REC_TOTAL),
    rec_share = GetString(VERDANT_RESH_REC_SHARE),
    casts     = GetString(VERDANT_RESH_CASTS),
    total     = GetString(VERDANT_RESH_TOTAL),
    share     = GetString(VERDANT_RESH_SHARE),
    pool      = GetString(VERDANT_RESH_POOL),
    top       = GetString(VERDANT_RESH_TOP),
    starved   = GetString(VERDANT_RESH_STARVED),
    more      = GetString(VERDANT_RESH_MORE),
    flows     = GetString(VERDANT_RES_CARD_FLOWS),
    sigma     = GetString(VERDANT_RES_CARD_SIGMA),
    lane_lv   = GetString(VERDANT_RESH_LANE_LEVEL),
    costcon   = GetString(VERDANT_RESH_COSTCONTRIB),
    best_return = GetString(VERDANT_RESH_BEST_RETURN),
    utility   = GetString(VERDANT_RESH_UTILITY),
    eff       = GetString(VERDANT_RESH_EFF),
    eff_none  = GetString(VERDANT_RESH_EFF_NONE),
    con_share = GetString(VERDANT_RESH_CONTRIB_SHARE),
    times     = GetString(VERDANT_RESH_TIMES),
    eff_dash  = GetString(VERDANT_RESH_EFF_DASH),
  }
  return str
end

function M.pick() return pick end

function M.set_pick(p)
  if p ~= PICK_MAG and p ~= PICK_STA and p ~= PICK_BOTH then p = PICK_BOTH end
  pick = p
  Verdant.Settings.save_res_pick(p)
end

local function pool_col(p) return (p == MAG) and C_MAG or C_STA end
local function wants(p) return pick == PICK_BOTH or (pick == PICK_MAG and p == MAG) or (pick == PICK_STA and p == STA) end

local function skill_col(id)
  local col = col_cache[id]
  if not col then
    local SC = Verdant.SkillColors
    col = SC.group_color(SC.group_of(id))
    col_cache[id] = col
  end
  return col
end


local function box(c, x0, x1, y, h, col, a, lvl)
  local seg = c.seg:AcquireObject()
  seg:ClearAnchors()
  seg:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x0, y)
  seg:SetWidth(math_max(1, x1 - x0))
  seg:SetHeight(math_max(1, h))
  seg:SetPixelRoundingEnabled(h <= 1 or x1 - x0 <= 1)
  seg:SetDrawLevel(lvl)
  seg:SetColor(col.r, col.g, col.b, a)
  seg:SetHidden(false)
  return seg
end

local function frame(c, x0, y0, x1, y1)
  c.panel(x0, y0, x1, y1)
end

local function label(c, text, x, y, w, h, align, col, a)
  local lbl = c.lbl:AcquireObject()
  lbl:ClearAnchors()
  lbl:SetText(text)
  lbl:SetHorizontalAlignment(align)
  lbl:SetMaxLineCount(1)
  lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  lbl:SetColor(col.r, col.g, col.b, a)
  lbl:SetDimensions(w, h)
  lbl:SetDrawLevel(7)
  lbl:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x, y)
  lbl:SetHidden(false)
  return lbl
end

local function icon(c, tex, x, y, size, a)
  local ic = c.icon:AcquireObject()
  ic:ClearAnchors()
  ic:SetTexture(tex)
  ic:SetDimensions(size, size)
  ic:SetColor(1, 1, 1, a)
  ic:SetDrawLevel(6)
  ic:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x, y)
  ic:SetHidden(false)
  return ic
end

local function x_of(t) return lane.x + math_floor((t - lane.t0) / lane.span * lane.w + 0.5) end

local function x_next(TB, k)
  local nx = TB.at(k + 1)
  if nx then return x_of(nx.t) end
  return lane.x + lane.w
end

local function level_of(s, p) return (p == MAG) and (s.mag or 0) or (s.sta or 0) end
local function in_of(s, p)    return (p == MAG) and (s.mag_in or 0) or (s.sta_in or 0) end
local function out_of(s, p)   return (p == MAG) and (s.mag_out or 0) or (s.sta_out or 0) end

local function state_of(level)
  if level <= 0 then return 0 end
  if level < STARVE then return 2 end
  if level < LOW then return 1 end
  return 0
end

local function state_col(p, st)
  if st == 2 then return C_LOW end
  if st == 1 then return C_WARN end
  return pool_col(p)
end

local function draw_levels(c, TB, n, p, y_base, H, up)
  local run_x0, run_x1, run_h, run_st = nil, nil, -1, 0
  for k = 1, n + 1 do
    local s = TB.at(k)
    local h, st, x0, x1 = 0, 0, 0, 0
    if s then
      local level = level_of(s, p)
      h = math_floor(level * H + 0.5)
      st = state_of(level)
      x0, x1 = x_of(s.t), x_next(TB, k)
      if x1 <= x0 then x1 = x0 + 1 end
    end
    if s and h > 0 and run_x0 and h == run_h and st == run_st and x0 <= run_x1 then
      run_x1 = x1
    else
      if run_x0 then
        box(c, run_x0, run_x1, up and (y_base - run_h) or y_base, run_h, state_col(p, run_st), 0.85, 3)
      end
      if s and h > 0 then run_x0, run_x1, run_h, run_st = x0, x1, h, st else run_x0 = nil end
    end
  end
end

local function draw_threshold(c, y_zero, H, up)
  local h15 = math_floor(H * STARVE + 0.5)
  local h30 = math_floor(H * LOW + 0.5)
  if h15 < 1 then return end
  box(c, lane.x, lane.x + lane.w, up and (y_zero - h15) or y_zero, h15, C_LOW, 0.07, 1)
  if h30 > h15 then box(c, lane.x, lane.x + lane.w, up and (y_zero - h30) or (y_zero + h15), h30 - h15, C_WARN, 0.05, 1) end
  box(c, lane.x, lane.x + lane.w, up and (y_zero - h15) or (y_zero + h15), 1, C_LOW, 0.35, 2)
  box(c, lane.x, lane.x + lane.w, up and (y_zero - h30) or (y_zero + h30), 1, C_WARN, 0.30, 2)
end

local function draw_starved(c, TB, n, p, y)
  local sx0, st0 = nil, 0
  for k = 1, n + 1 do
    local s = TB.at(k)
    local level = s and level_of(s, p) or 1
    if s and level < STARVE then
      if not sx0 then sx0, st0 = x_of(s.t), s.t end
    elseif sx0 then
      local t_end = s and s.t or (lane.t0 + lane.span)
      if t_end - st0 >= STARVE_MS then box(c, sx0, x_of(t_end), y, TICK_H, C_LOW, 1, 5) end
      sx0 = nil
    end
  end
end

local function build_rates(TB, n, p)
  local lo, sin, sout, top = 1, 0, 0, 0
  for k = 1, n do
    local s = TB.at(k)
    sin, sout = sin + in_of(s, p), sout + out_of(s, p)
    while lo < k and TB.at(lo).t <= s.t - RATE_MS do
      local d = TB.at(lo)
      sin, sout = sin - in_of(d, p), sout - out_of(d, p)
      lo = lo + 1
    end
    local span = s.t - TB.at(lo).t + 1000
    if span > RATE_MS then span = RATE_MS end
    rate_in[k], rate_out[k] = sin * 1000 / span, sout * 1000 / span
    if rate_in[k] > top then top = rate_in[k] end
    if rate_out[k] > top then top = rate_out[k] end
  end
  return top
end

local function draw_ribbon(c, TB, n, p, y, h)
  local top = build_rates(TB, n, p)
  if top <= 0 then return end
  local pc = pool_col(p)
  local gx0, gx1, gcol, ga = nil, 0, nil, 0
  for k = 1, n + 1 do
    local s = TB.at(k)
    local col, a, x0, x1 = nil, 0, 0, 0
    if s and k <= n then
      local d = rate_in[k] - rate_out[k]
      local mag = (d < 0 and -d or d) / top
      if level_of(s, p) <= 0 then col, a = C_REGEN, 0.25
      elseif d < 0 then col, a = C_OUT, 0.15 + 0.75 * mag
      elseif d > 0 then col, a = pc, 0.15 + 0.75 * mag end
      a = math_floor(a * 20 + 0.5) / 20
      x0, x1 = x_of(s.t), x_next(TB, k)
      if x1 <= x0 then x1 = x0 + 1 end
    end
    if s and k <= n and gx0 and col == gcol and a == ga and x0 <= gx1 then
      gx1 = x1
    else
      if gx0 and gcol then box(c, gx0, gx1, y, h, gcol, ga, 2) end
      if s and k <= n then gx0, gx1, gcol, ga = x0, x1, col, a else gx0 = nil end
    end
  end
end

local function draw_rug(c, p, y, h)
  local base = y + math_floor(h * 0.6)
  local room = math_floor(h * 0.4) - 1
  local t_end = lane.t0 + lane.span
  local ct, cid, cpool, ccost, cn = Verdant.Casts.records()
  local c0 = Verdant.Casts.first()
  local maxc = 0
  for i = c0, cn do
    if cpool[i] == p and ccost[i] > maxc then maxc = ccost[i] end
  end
  if maxc > 0 then
    local last_x, last_h = -1, 0
    for i = c0, cn do
      local t = ct[i]
      if cpool[i] == p and ccost[i] > 0 and t >= lane.t0 and t <= t_end then
        local x = x_of(t)
        local hh = 3 + math_floor((room - 3) * ccost[i] / maxc + 0.5)
        if x ~= last_x or hh > last_h then
          box(c, x, x + 1, base, hh, skill_col(cid[i]), 0.95, 3)
          last_x, last_h = x, hh
        end
      end
    end
  end
  local rt, _, rpool, ramt, rn = Verdant.Restores.records()
  local r0 = Verdant.Restores.first()
  local maxr = 0
  for i = r0, rn do
    if rpool[i] == p and ramt[i] > maxr then maxr = ramt[i] end
  end
  if maxr > 0 then
    local up = base - y - 1
    local pc = pool_col(p)
    local last_x, last_h = -1, 0
    for i = r0, rn do
      local t = rt[i]
      if rpool[i] == p and ramt[i] > 0 and t >= lane.t0 and t <= t_end then
        local x = x_of(t)
        local hh = 3 + math_floor((up - 3) * ramt[i] / maxr + 0.5)
        if x ~= last_x or hh > last_h then
          box(c, x, x + 1, base - hh, hh, pc, 0.95, 3)
          last_x, last_h = x, hh
        end
      end
    end
  end
  box(c, lane.x, lane.x + lane.w, base, 1, C_MID, 0.18, 4)
end

local function draw_deaths(c)
  local starts, dn = Verdant.TemporalBuffer.dead_spans()
  for i = 1, dn do
    local t = starts[i]
    if t >= lane.t0 and t <= lane.t0 + lane.span then
      local ic = icon(c, TEX_SKULL, x_of(t) - 7, lane.mid - 7, 14, 0.95)
      ic:SetColor(1, 0.92, 0.88, 0.95)
      ic:SetDrawLevel(7)
    end
  end
end

local function lane_tag(c, text, y)
  label(c, text, lane.x + 4, y, 90, 12, TEXT_ALIGN_LEFT, C_DIM, 0.75)
end

local function draw_mirrored(c, TB, n, S)
  local half = math_floor(lane.h / 2) - TICK_H - 2
  if half < 4 then return end
  lane.mid = lane.y + math_floor(lane.h / 2)
  frame(c, lane.x, lane.y, lane.x + lane.w, lane.mid)
  frame(c, lane.x, lane.mid, lane.x + lane.w, lane.y + lane.h)
  draw_threshold(c, lane.mid - 1, half, true)
  draw_threshold(c, lane.mid + 1, half, false)
  draw_levels(c, TB, n, MAG, lane.mid - 1, half, true)
  draw_levels(c, TB, n, STA, lane.mid + 1, half, false)
  draw_starved(c, TB, n, MAG, lane.y + 1)
  draw_starved(c, TB, n, STA, lane.y + lane.h - TICK_H - 1)
  lane_tag(c, S.pick[PICK_MAG], lane.y + TICK_H + 2)
  lane_tag(c, S.pick[PICK_STA], lane.y + lane.h - TICK_H - 14)
end

local function eff(rec, S)
  local ratio = (rec.total > 0) and (rec.con / rec.total) or 0
  if rec.eff_disp ~= ratio then
    rec.eff_disp = ratio
    rec.eff_text = (ratio > 0) and string_format("%s%.1f", S.times, ratio) or S.eff_dash
  end
  return ratio
end

local function dress(rec, S)
  if rec.name then return end
  if rec.id > 0 then
    local SC = Verdant.SkillColors
    rec.name = SC.ability_name(rec.id)
    local ic = SC.ability_icon(rec.id) or ""
    rec.icon = (ic ~= "" and not ic:lower():find("icon_missing", 1, true)) and ic or nil
    local col = (rec.sec == SEC_REC) and SC.group_color(SC.group_of_quiet(rec.id)) or skill_col(rec.id)
    rec.r, rec.g, rec.b = col.r, col.g, col.b
  else
    rec.name = S.recovery
    rec.icon = nil
    rec.r, rec.g, rec.b = C_REGEN.r, C_REGEN.g, C_REGEN.b
  end
end

local function draw_single(c, TB, n, p, S)
  local annot = RIB_H + RUG_H + 4
  local h_lv = lane.h - annot
  if h_lv < 30 then annot, h_lv = 0, lane.h end
  local y_lv = lane.y
  lane.mid = y_lv + math_floor(h_lv / 2)
  frame(c, lane.x, y_lv, lane.x + lane.w, lane.y + lane.h)
  local H = h_lv - TICK_H - 3
  draw_threshold(c, y_lv + h_lv - 1, H, true)
  draw_levels(c, TB, n, p, y_lv + h_lv - 1, H, true)
  draw_starved(c, TB, n, p, y_lv + 1)
  if annot > 0 then
    local y_rib = y_lv + h_lv + 2
    draw_ribbon(c, TB, n, p, y_rib, RIB_H)
    draw_rug(c, p, y_rib + RIB_H + 2, RUG_H)
  end
  lane_tag(c, S.lane_lv, y_lv + TICK_H + 2)
end

local function race_step(top)
  local pct = top * 100
  for i = 1, #RACE_STEPS do
    if pct / RACE_STEPS[i] <= RACE_MAX_LINES then return RACE_STEPS[i] end
  end
  return RACE_STEPS[#RACE_STEPS]
end

local function race_scale(c, x, y, w, h, top, text_y, text_lo, text_hi)
  if w < 2 or top <= 0 then return end
  local pct = top * 100
  local step = race_step(top)
  local p = step
  while p <= pct and p <= 100 do
    local gx = x + math_floor(p / pct * w + 0.5)
    box(c, gx, gx + 1, y, h, C_MID, RACE_GRID_A, 2)
    local half = RACE_TEXT_W / 2
    if gx - half >= text_lo and gx + half <= text_hi then
      label(c, PCT_TEXT[p], gx - half, text_y, RACE_TEXT_W, RACE_TEXT_H, TEXT_ALIGN_CENTER, C_MID, RACE_TEXT_A)
    end
    p = p + step
  end
end

local function reach(share, top, w)
  if share <= 0 then return 0 end
  local px = math_floor(share / top * w + 0.5)
  if px < 1 then px = 1 end
  if px > w then px = w end
  return px
end

local function race_row(c, x, y, w, h, pace, run, top, col_pace, a)
  if w < 2 or top <= 0 then return x end
  local ly = y + math_floor((h - RACE_LANE_H) / 2)
  local ry = y + math_floor((h - RACE_RUN_H) / 2)
  local px = reach(pace, top, w)
  local rx = reach(run, top, w)
  box(c, x, x + w, ly, RACE_LANE_H, C_MID, RACE_GROUND_A * a, 2)
  if px > 0 then
    box(c, x, x + px, ly, RACE_LANE_H, col_pace, RACE_PACE_A * a, 3)
    box(c, x + px - 1, x + px, ly - 1, RACE_LANE_H + 2, col_pace, RACE_MARK_A * a, 5)
  end
  if rx > 0 then
    local body = (rx < px) and rx or px
    if body > 0 then box(c, x, x + body, ry, RACE_RUN_H, C_CONTRIB, RACE_RUN_A * a, 4) end
    if rx > body then box(c, x + body, x + rx, ry, RACE_RUN_H, C_LEAD, RACE_RUN_A * a, 4) end
  end
  return x + px
end

local function draw_race(c, x, y, w, h, S)
  local o, n = race_order, race_order.n
  label(c, S.costcon, x + 4, y, w - 80, HDR_H, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  box(c, x, x + w, y + HDR_H - 1, 1, C_SEP, 0.25, 2)
  local rows = math_floor((h - HDR_H - 4 - RACE_PAD) / RACE_ROW)
  if rows > n then rows = n end
  if rows < 0 then rows = 0 end
  max_scroll[SEC_RACE] = (n > rows) and (n - rows) or 0
  if scroll[SEC_RACE] > max_scroll[SEC_RACE] then scroll[SEC_RACE] = max_scroll[SEC_RACE] end
  local off = scroll[SEC_RACE]
  local rest = n - rows - off
  if rest > 0 then label(c, string_format(S.more, rest), x + w - 74, y, 70, HDR_H, TEXT_ALIGN_RIGHT, C_DIM, 0.8) end
  local name_w = math_min(150, math_floor(w * 0.26))
  local x_icon = x + 4
  local x_name = x_icon + ICON + 6
  local tx = x_name + name_w + 8
  local vx = x + w - VAL_W - 4
  local tw = vx - tx - 10
  local mx = 0
  for i = 1, n do
    local rec = o[i]
    local sp = (totals.spend > 0) and rec.total / totals.spend or 0
    local cs = (contrib.total > 0) and rec.con / contrib.total or 0
    if sp > mx then mx = sp end
    if cs > mx then mx = cs end
  end
  mx = mx * 1.08
  local ry = y + HDR_H + 4
  if rows > 0 then
    race_scale(c, tx, ry, tw, rows * RACE_ROW, mx, y + 2, tx + 10, (rest > 0) and (x + w - 78) or (x + w - 4))
  end
  for i = 1, rows do
    local rec = o[i + off]
    dress(rec, S)
    local k = row_hit.n + 1
    row_hit.n = k
    row_hit.x0[k], row_hit.x1[k], row_hit.y0[k], row_hit.y1[k], row_hit.rec[k], row_hit.sec[k] = x, x + w, ry, ry + RACE_ROW, rec, SEC_RACE
    local dim = (hover_row ~= nil and rec ~= hover_row)
    local a = dim and 0.45 or 1
    local p = (rec.mag >= rec.sta) and MAG or STA
    icon(c, rec.icon or ICON_POOL[p], x_icon, ry + math_floor((RACE_ROW - ICON) / 2), ICON, a)
    label(c, rec.name, x_name, ry, name_w, RACE_ROW, TEXT_ALIGN_LEFT, C_TEXT, a)
    local sp = (totals.spend > 0) and rec.total / totals.spend or 0
    local cs = (contrib.total > 0 and rec.con > 0) and rec.con / contrib.total or 0
    local x_pace = race_row(c, tx, ry, tw, RACE_ROW, sp, cs, mx, pool_col(p), a)
    if rec.con > 0 then
      eff(rec, S)
      label(c, rec.eff_text, vx, ry, VAL_W, RACE_ROW, TEXT_ALIGN_RIGHT, C_CONTRIB, a)
    else
      label(c, S.utility, x_pace + 8, ry, 60, RACE_ROW, TEXT_ALIGN_LEFT, C_DIM, a * 0.9)
      label(c, S.eff_dash, vx, ry, VAL_W, RACE_ROW, TEXT_ALIGN_RIGHT, C_DIM, a)
    end
    ry = ry + RACE_ROW
  end
  sec_rect[SEC_RACE].y0, sec_rect[SEC_RACE].y1 = y, y + h
  frame(c, x, y, x + w, y + h)
end

local function draw_picker(c, top, S)
  local x = LANE_X + 2
  pick_hit.y0, pick_hit.y1 = top, top + PICK_H
  local pill_tex = Verdant.lib.themes.texture("subtab")
  for i = 1, 3 do
    local on = (pick == i)
    local col = (i == PICK_MAG) and C_MAG or (i == PICK_STA) and C_STA or C_TEXT
    local lbl = c.lbl:AcquireObject()
    local w = Verdant.Format.text_width(lbl, S.pick[i]) + 18
    local pill = c.icon:AcquireObject()
    pill:ClearAnchors()
    pill:SetTexture(pill_tex)
    pill:SetDimensions(w, PICK_H)
    pill:SetDrawLevel(4)
    pill:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x, top)
    if on then pill:SetColor(col.r, col.g, col.b, 1) else pill:SetColor(C_DIM.r, C_DIM.g, C_DIM.b, 0.55) end
    pill:SetHidden(false)
    lbl:ClearAnchors()
    lbl:SetText(S.pick[i])
    lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    lbl:SetMaxLineCount(1)
    lbl:SetDimensions(w, PICK_H)
    lbl:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x, top)
    lbl:SetDrawLevel(5)
    if on then lbl:SetColor(1, 1, 1, 1) else lbl:SetColor(C_TEXT.r, C_TEXT.g, C_TEXT.b, 0.85) end
    lbl:SetHidden(false)
    pick_hit[i].x0, pick_hit[i].x1 = x, x + w
    x = x + w + 4
  end
end

local function draw_time(c)
  local y = lane.y + lane.h + 1
  local h = c.time_strip - 2
  label(c, "0s", lane.x, y, 40, h, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  label(c, c.fmt_secs(lane.span / 2), lane.x + math_floor(lane.w / 2) - 25, y, 50, h, TEXT_ALIGN_CENTER, C_DIM, 0.9)
  label(c, c.fmt_secs(lane.span), lane.x + lane.w - 50, y, 50, h, TEXT_ALIGN_RIGHT, C_DIM, 0.9)
end

local function section_h(rows)
  return HDR_H + 4 + rows * (ROW_H + ROW_GAP)
end

local function draw_section(c, x, y, sec, rows, title, S, y_end)
  local o = order[sec]
  local n = o.n
  local off = scroll[sec]
  local rest = n - rows - off
  label(c, title, x + 4, y, RIGHT_W - 64, HDR_H, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  if rest > 0 then label(c, string_format(S.more, rest), x + RIGHT_W - 74, y, 70, HDR_H, TEXT_ALIGN_RIGHT, C_DIM, 0.8) end
  box(c, x, x + RIGHT_W, y + HDR_H - 1, 1, C_SEP, 0.25, 2)
  local ry = y + HDR_H + 2
  local top_total = (n > 0) and o[1].total or 0
  local x_icon = x + 4
  local x_name = x_icon + ICON + 6
  local name_w = RIGHT_W - 4 - ICON - 6 - VAL_W - 6
  for i = 1, rows do
    local rec = o[i + off]
    dress(rec, S)
    local k = row_hit.n + 1
    row_hit.n = k
    row_hit.x0[k], row_hit.x1[k], row_hit.y0[k], row_hit.y1[k], row_hit.rec[k], row_hit.sec[k] = x, x + RIGHT_W, ry, ry + ROW_H, rec, sec
    local dim = (hover_row ~= nil and rec ~= hover_row)
    local a = dim and 0.45 or 1
    local p = (rec.mag >= rec.sta) and MAG or STA
    icon(c, rec.icon or ICON_POOL[p], x_icon, ry + math_floor((ROW_H - ICON) / 2), ICON, a)
    label(c, rec.name, x_name, ry + 1, name_w, NAME_H, TEXT_ALIGN_LEFT, C_TEXT, a)
    local by = ry + NAME_H + 3
    box(c, x_name, x_name + name_w, by, BAR_H, C_MID, dim and 0.03 or 0.06, 2)
    if top_total > 0 then
      if sec == SEC_SPENT then
        local bw = math_floor(name_w * rec.total / top_total + 0.5)
        if bw < 1 then bw = 1 end
        box(c, x_name, x_name + bw, by, BAR_H, rec, dim and 0.3 or 0.92, 3)
      else
        local wm = math_floor(name_w * rec.mag / top_total + 0.5)
        local ws = math_floor(name_w * rec.sta / top_total + 0.5)
        if wm > 0 then box(c, x_name, x_name + wm, by, BAR_H, C_MAG, dim and 0.3 or 0.92, 3) end
        if ws > 0 then box(c, x_name + wm, x_name + wm + ws, by, BAR_H, C_STA, dim and 0.3 or 0.92, 3) end
      end
    end
    if rec.disp ~= rec.total then
      rec.disp = rec.total
      rec.text = c.fmt_val(rec.total)
    end
    if sec == SEC_SPENT then
      local ratio = eff(rec, S)
      label(c, rec.text, x + RIGHT_W - VAL_W - 4, ry, VAL_W, 12, TEXT_ALIGN_RIGHT, pool_col(p), a)
      label(c, rec.eff_text, x + RIGHT_W - VAL_W - 4, ry + 12, VAL_W, 12, TEXT_ALIGN_RIGHT, (ratio > 0) and C_CONTRIB or C_DIM, a * 0.85)
    else
      label(c, rec.text, x + RIGHT_W - VAL_W - 4, ry, VAL_W, ROW_H, TEXT_ALIGN_RIGHT, pool_col(p), a)
    end
    ry = ry + ROW_H + ROW_GAP
  end
  local y1 = ry + 2
  if y_end and y_end > y1 then y1 = y_end end
  sec_rect[sec].y0, sec_rect[sec].y1 = y, y1
  frame(c, x, y, x + RIGHT_W, y1)
  return y1
end

local RET_ROW = 16
local RET_ROWS = 4
local RET_MIN_CASTS = 3
local RET_MIN_SHARE = 0.02
local ret_order = { n = 0 }
local ret_totals = {}

function M.return_score(con, spent, k, pool)
  return (con + k * pool) / (spent + k)
end

local function by_return(a, b)
  if a.ret == b.ret then return a.total > b.total end
  return a.ret > b.ret
end

local function build_returns()
  local o = order[SEC_SPENT]
  local sum_c, sum_s = 0, 0
  for i = 1, o.n do
    sum_c = sum_c + o[i].con
    sum_s = sum_s + o[i].total
    ret_totals[i] = o[i].total
  end
  for i = o.n + 1, #ret_totals do ret_totals[i] = nil end
  ret_order.n = 0
  if o.n == 0 or sum_s <= 0 then return end
  table_sort(ret_totals)
  local k = ret_totals[math_ceil(o.n / 2)]
  if k < 1 then k = 1 end
  local pool = sum_c / sum_s
  for i = 1, o.n do
    local rec = o[i]
    if rec.con > 0 and (rec.n >= RET_MIN_CASTS or rec.total >= RET_MIN_SHARE * sum_s) then
      rec.ret = M.return_score(rec.con, rec.total, k, pool)
      ret_order.n = ret_order.n + 1
      ret_order[ret_order.n] = rec
    end
  end
  for i = ret_order.n + 1, #ret_order do ret_order[i] = nil end
  if ret_order.n > 1 then table_sort(ret_order, by_return) end
end

function M.returns() return ret_order end

local function draw_returns(c, x, y, S)
  local rows = math_min(RET_ROWS, ret_order.n)
  if rows == 0 then return end
  label(c, S.best_return, x + 4, y, RIGHT_W - 8, HDR_H, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  box(c, x, x + RIGHT_W, y + HDR_H - 1, 1, C_SEP, 0.25, 2)
  local ry = y + HDR_H + 2
  for i = 1, rows do
    local rec = ret_order[i]
    dress(rec, S)
    local k = row_hit.n + 1
    row_hit.n = k
    row_hit.x0[k], row_hit.x1[k], row_hit.y0[k], row_hit.y1[k], row_hit.rec[k], row_hit.sec[k] = x, x + RIGHT_W, ry, ry + RET_ROW, rec, SEC_SPENT
    local a = (hover_row ~= nil and rec ~= hover_row) and 0.45 or 1
    icon(c, rec.icon or ICON_POOL[(rec.mag >= rec.sta) and MAG or STA], x + 4, ry + 1, RET_ROW - 2, a)
    label(c, rec.name, x + RET_ROW + 8, ry + 1, RIGHT_W - RET_ROW - VAL_W - 14, RET_ROW - 2, TEXT_ALIGN_LEFT, C_TEXT, a)
    label(c, string_format("%s%.1f", S.times, rec.con / rec.total), x + RIGHT_W - VAL_W - 4, ry + 1, VAL_W, RET_ROW - 2, TEXT_ALIGN_RIGHT, C_CONTRIB, a)
    ry = ry + RET_ROW
  end
  frame(c, x, y, x + RIGHT_W, ry + 2)
end

local function draw_lists(c, cw, y, h, S)
  build_returns()
  local ret_h = HDR_H + 4 + math_min(RET_ROWS, ret_order.n) * RET_ROW + SEC_GAP
  if ret_order.n == 0 then ret_h = 0 end
  local full_h = h
  if math_floor((h - ret_h - 2 * (HDR_H + 4) - SEC_GAP) / (ROW_H + ROW_GAP)) >= 4 then h = h - ret_h else ret_h = 0 end
  local x = cw - RIGHT_W
  local na, nb = order[SEC_SPENT].n, order[SEC_REC].n
  local slots = math_floor((h - 2 * (HDR_H + 4) - SEC_GAP) / (ROW_H + ROW_GAP))
  if slots < 0 then slots = 0 end
  local rows_a = math_ceil(slots / 2)
  if rows_a > na then rows_a = na end
  local rows_b = slots - rows_a
  if rows_b > nb then rows_b = nb end
  rows_a = slots - rows_b
  if rows_a > na then rows_a = na end
  max_scroll[SEC_SPENT] = (na > rows_a) and (na - rows_a) or 0
  max_scroll[SEC_REC]   = (nb > rows_b) and (nb - rows_b) or 0
  for s = 1, 2 do
    if scroll[s] > max_scroll[s] then scroll[s] = max_scroll[s] end
    if scroll[s] < 0 then scroll[s] = 0 end
  end
  local bottom = y + full_h
  local natural = y + section_h(rows_a) + ((nb > 0) and (SEC_GAP + section_h(rows_b)) or 0)
  local ret_box = HDR_H + 4 + math_min(RET_ROWS, ret_order.n) * RET_ROW
  local show_ret = ret_order.n > 0 and natural + SEC_GAP + ret_box <= bottom
  local list_end = show_ret and (bottom - ret_box - SEC_GAP) or bottom
  local y1 = draw_section(c, x, y, SEC_SPENT, rows_a, S.spent, S, (nb == 0) and list_end or nil)
  if nb > 0 then
    draw_section(c, x, y1 + SEC_GAP, SEC_REC, rows_b, S.recovered, S, list_end)
  else
    sec_rect[SEC_REC].y0, sec_rect[SEC_REC].y1 = 0, 0
  end
  if show_ret then draw_returns(c, x, bottom - ret_box, S) end
end

function M.bind(t)
  C_MAG, C_STA = t.C_RMAG, t.C_RSTA
  C_CONTRIB = t.C_EHPS
end

function M.attach(t)
  ctx = t
end

function M.load_pick()
  local p = Verdant.Settings.res_pick()
  if p then M.set_pick(p) end
end

function M.render()
  local c = ctx
  if not c then return end
  c.seg:ReleaseAllObjects()
  c.lbl:ReleaseAllObjects()
  c.icon:ReleaseAllObjects()
  c.hit_reset()
  row_hit.n = 0
  lane.span = 0
  c.hide_grid(c.grid)
  local TB = Verdant.TemporalBuffer
  local n = TB.count()
  if n == 0 then
    c.no_data:SetHidden(false)
    return
  end
  sums = Verdant.Resources.summary(TB)
  if not sums.has then
    c.no_data:SetText(GetString(VERDANT_GRAPH_NO_RES))
    c.no_data:SetHidden(false)
    return
  end
  c.no_data:SetHidden(true)
  RS.aggregate(st, wants(MAG), wants(STA), sums)
  local canvas = c.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= RIGHT_W + 80 or ch <= 40 then return end
  local recording = TB.is_recording()
  local t0 = TB.at(1).t
  local t_hi = recording and c.now() or TB.at(n).t
  local span = t_hi - t0
  if span <= 0 then span = 1 end
  Verdant.Diagnostics.bump("graph.view_res.renders")
  local S = strings()
  local top = c.top() + 2
  draw_picker(c, top, S)
  local y = top + PICK_H + 6
  local h = math_max(8, ch - c.time_strip - y - 2)
  local h_block = math_floor(h * 0.55)
  local h_race = h - h_block - c.time_strip - 2
  if h_race < 70 then h_block, h_race = h, 0 end
  lane.x, lane.w, lane.y, lane.h, lane.t0, lane.span = LANE_X, cw - RIGHT_W - LANE_X - GAP_X, y, h_block, t0, span
  lane.mid = y + math_floor(h_block / 2)
  if pick == PICK_BOTH then
    draw_mirrored(c, TB, n, S)
  else
    draw_single(c, TB, n, (pick == PICK_MAG) and MAG or STA, S)
  end
  draw_time(c)
  draw_deaths(c)
  if h_race > 0 then
    draw_race(c, LANE_X, y + h_block + c.time_strip + 2, lane.w, h_race, S)
  else
    sec_rect[SEC_RACE].y0, sec_rect[SEC_RACE].y1 = 0, 0
  end
  draw_lists(c, cw, y, h, S)
end

local function sample_index_at(TB, t)
  local lo, hi = 1, TB.count()
  while lo < hi do
    local mid = math_floor((lo + hi + 1) / 2)
    if TB.at(mid).t <= t then lo = mid else hi = mid - 1 end
  end
  return lo
end

local function starved_span(TB, k, p)
  local s = TB.at(k)
  if not s then return 0 end
  if not (level_of(s, p) < STARVE) then return 0 end
  local i = k
  while i > 1 do
    if level_of(TB.at(i - 1), p) < STARVE then i = i - 1 else break end
  end
  local j = k
  local n = TB.count()
  while j < n do
    if level_of(TB.at(j + 1), p) < STARVE then j = j + 1 else break end
  end
  local t_end = TB.at(j + 1) and TB.at(j + 1).t or TB.at(j).t
  return t_end - TB.at(i).t
end

local function row_card(c, rec, sec, S, mx, my)
  local p = (rec.mag >= rec.sta) and MAG or STA
  local pc = pool_col(p)
  local nr = 0
  local stat
  if sec == SEC_SPENT or sec == SEC_RACE then
    stat = string_format(S.casts, rec.n, c.fmt_val(rec.total / math_max(rec.n, 1)))
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.total, c.fmt_val(rec.total), pc
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.share, PCT_TEXT[math_floor(rec.total / math_max(totals.spend, 1) * 100 + 0.5)] or "", C_TIME
    if rec.con > 0 then
      eff(rec, S)
      nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.eff, rec.eff_text, C_CONTRIB
      nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.con_share, PCT_TEXT[math_floor(rec.con / math_max(contrib.total, 1) * 100 + 0.5)] or "", C_TIME
    else
      nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.eff, S.eff_none, C_TIME
    end
  else
    if rec.id == 0 then
      local rg = Verdant.Restores.regen(p)
      stat = (rg > 0) and string_format(S.regen, c.fmt_val(rg)) or S.recovery
    else
      stat = string_format(S.restores, rec.n, c.fmt_val(rec.total / math_max(rec.n, 1)))
    end
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.rec_total, c.fmt_val(rec.total), pc
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.rec_share, PCT_TEXT[math_floor(rec.total / math_max(totals.regained, 1) * 100 + 0.5)] or "", C_TIME
  end
  nr = nr + 1; ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.pool, (rec.mag > 0 and rec.sta > 0) and S.pick[PICK_BOTH] or S.pools[p], pc
  c.show_card(rec, rec.name or "", stat, "", ROWS, nr, mx, my)
end

function M.hover(mx, my)
  local c = ctx
  if not c then return end
  local canvas = c.canvas
  local rel_x, rel_y = mx - canvas:GetLeft(), my - canvas:GetTop()
  local S = strings()
  local rec, sec = nil, nil
  for i = 1, row_hit.n do
    if rel_x >= row_hit.x0[i] and rel_x <= row_hit.x1[i] and rel_y >= row_hit.y0[i] and rel_y <= row_hit.y1[i] then rec, sec = row_hit.rec[i], row_hit.sec[i] break end
  end
  if rec ~= hover_row then hover_row = rec; c.rerender() end
  if rec then
    row_card(c, rec, sec, S, mx, my)
    return
  end
  if lane.span <= 0 or rel_x < lane.x or rel_x > lane.x + lane.w or rel_y < lane.y or rel_y > lane.y + lane.h then
    c.hide_card()
    return
  end
  local p = (pick == PICK_MAG) and MAG or (pick == PICK_STA) and STA or ((rel_y < lane.mid) and MAG or STA)
  local pc = pool_col(p)
  local t = lane.t0 + (rel_x - lane.x) / lane.w * lane.span
  local TB = Verdant.TemporalBuffer
  local k = sample_index_at(TB, t)
  local s = TB.at(k)
  if not s then c.hide_card() return end
  local prv = (k > 1) and TB.at(k - 1) or nil
  local t_lo = prv and prv.t or -1
  local level = level_of(s, p)
  local sigma = Verdant.Resources.window_sigma(TB, k, SIGMA_BACK, p)
  local stat = string_format(S.flows, c.fmt_val(in_of(s, p)), c.fmt_val(out_of(s, p)))
  if sigma then stat = stat .. string_format(S.sigma, sigma) end
  local nr = 0
  local SC = Verdant.SkillColors
  local top_id, top_cost = Verdant.Casts.spend_top(s.t - WINDOW_MS, s.t, p)
  if top_id > 0 then
    nr = nr + 1
    ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.top, string_format("%s  ·  %s", SC.ability_name(top_id), c.fmt_val(top_cost)), pc
  end
  local R = Verdant.Restores
  local rid, ramt = R.top(t_lo, s.t, p)
  if rid > 0 then
    nr = nr + 1
    ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.rec_by, string_format("%s  ·  %s", SC.ability_name(rid), c.fmt_val(ramt)), pc
  end
  local rg = R.regen(p)
  if rg > 0 then
    nr = nr + 1
    ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.recovery, string_format(S.regen, c.fmt_val(rg)), pc
  end
  local starved_ms = starved_span(TB, k, p)
  if starved_ms >= STARVE_MS and nr < #ROWS then
    nr = nr + 1
    ROWS[nr][1], ROWS[nr][2], ROWS[nr][3] = S.starved, c.fmt_secs(starved_ms), C_TIME
  end
  c.crosshair(math_floor(rel_x))
  local col = state_col(p, state_of(level))
  c.show_card(col, string_format("%s  %d%%", S.pools[p], math_floor(level * 100 + 0.5)), stat,
    "t  " .. c.fmt_secs(s.t - lane.t0), ROWS, nr, mx, my)
end

function M.click(mx, my)
  local c = ctx
  if not c then return false end
  local rel_x, rel_y = mx - c.canvas:GetLeft(), my - c.canvas:GetTop()
  if rel_y < pick_hit.y0 or rel_y > pick_hit.y1 then return false end
  for i = 1, 3 do
    if rel_x >= pick_hit[i].x0 and rel_x <= pick_hit[i].x1 then
      if pick == i then return false end
      M.set_pick(i)
      scroll[SEC_SPENT], scroll[SEC_REC], scroll[SEC_RACE] = 0, 0, 0
      hover_row = nil
      return true
    end
  end
  return false
end

function M.scroll(dir)
  local c = ctx
  local sec = SEC_SPENT
  if c then
    local mx, my = api.GetUIMousePosition()
    local rel_x, rel_y = mx - c.canvas:GetLeft(), my - c.canvas:GetTop()
    local rb = sec_rect[SEC_REC]
    local db = sec_rect[SEC_RACE]
    if rel_x < c.canvas:GetWidth() - RIGHT_W then
      if db.y1 > db.y0 and rel_y >= db.y0 and rel_y <= db.y1 then sec = SEC_RACE else return false end
    elseif rb.y1 > rb.y0 and rel_y >= rb.y0 and rel_y <= rb.y1 then sec = SEC_REC end
  end
  local next_off = scroll[sec] + ((dir or 1) < 0 and -1 or 1)
  if next_off < 0 then next_off = 0 end
  if next_off > max_scroll[sec] then next_off = max_scroll[sec] end
  if next_off == scroll[sec] then return false end
  scroll[sec] = next_off
  return true
end

function M.reset_scroll() scroll[SEC_SPENT], scroll[SEC_REC], scroll[SEC_RACE] = 0, 0, 0 end
function M.scroll_state(sec) return scroll[sec or SEC_SPENT], max_scroll[sec or SEC_SPENT] end
function M.hovered() return hover_row end
function M.clear_hover() hover_row = nil end
function M.rows() return order[SEC_SPENT], order[SEC_SPENT].n end
function M.recovered() return order[SEC_REC], order[SEC_REC].n end
function M.totals() return totals end
function M.lane() return lane end
function M.race() return race_order, race_order.n, sec_rect[SEC_RACE], contrib.total end
