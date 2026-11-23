Verdant = Verdant or {}
local Verdant = Verdant
Verdant.ContribView = {}
local M = Verdant.ContribView

local math_floor    = math.floor
local string_format = string.format
local table_sort    = table.sort

local L = { HEADER_H = 20, ROW_H = 24, ROW_GAP = 2, ICON = 18, PAD = 4, TYPE_W = 54, VAL_W = 72, BAR_H = 5, NAME_H = 14 }
local C_HEAD   = { r = 0.60, g = 0.64, b = 0.61, a = 0.95 }
local C_NAME   = Verdant.lib.themes.tint("name", 1.0)
local C_VAL    = { r = 0.87, g = 0.87, b = 0.83, a = 1.0 }
local C_MORE   = { r = 0.70, g = 0.68, b = 0.62, a = 1.0 }
local C_TRACK  = { r = 1.0, g = 1.0, b = 1.0, a = 0.06 }
local C_HEAL   = { r = 0.55, g = 0.92, b = 0.62 }
local C_SHIELD = { r = 0.95, g = 0.68, b = 0.83 }
local CH_HEAL, CH_SHIELD = 0, 1

local ctx = nil
local acc_heal, acc_shield = {}, {}
local ids = { n = 0 }
local seen = {}
local entries = {}
local order = { n = 0 }
local hit = { n = 0, y0 = {}, y1 = {}, e = {} }
local totals = { heal = 0, shield = 0, span = 0, exact = false }
local more = { n = -1, text = "" }
local hover_row = nil
local scroll = 0
local max_scroll = 0
local C_BAND = Verdant.lib.themes.tint("band", 0.10)
local str = nil

local function strings()
  if str then return str end
  str = {
    contrib = GetString(VERDANT_CONTRIB_HEAD_CONTRIB),
    type    = GetString(VERDANT_CONTRIB_HEAD_TYPE),
    value   = GetString(VERDANT_CONTRIB_HEAD_VALUE),
    heal    = GetString(VERDANT_CONTRIB_TYPE_HEAL),
    shield  = GetString(VERDANT_CONTRIB_TYPE_SHIELD),
    more    = GetString(VERDANT_CONTRIB_MORE),
    scrolled = GetString(VERDANT_CONTRIB_SCROLLED),
    est     = GetString(VERDANT_CONTRIB_TIP_EST),
    whole   = GetString(VERDANT_CONTRIB_TIP_WHOLE),
    parts   = GetString(VERDANT_CONTRIB_PARTS),
  }
  return str
end

local function entry_for(id, ch)
  local key = id * 2 + ch
  local e = entries[key]
  if not e then
    local SC = Verdant.SkillColors
    e = { id = id, ch = ch, v = 0, disp = -1, text = "", r = 1, g = 1, b = 1,
          icon = SC.ability_icon(id), name = SC.ability_name(id), hov_pct = -1, hov_disp = -1, hov = "" }
    entries[key] = e
  end
  return e
end

local rows_heal, rows_shield = {}, {}
local gen = 0

local function row_for(e)
  local bucket = (e.ch == CH_HEAL) and rows_heal or rows_shield
  local r = bucket[e.name]
  if not r then
    r = { name = e.name, icon = e.icon, ch = e.ch, v = 0, n = 0, gen = -1, disp = -1, text = "",
          top = -1, top_id = 0,
          r = e.r, g = e.g, b = e.b, hov_pct = -1, hov_disp = -1, hov_n = -1, hov_exact = nil, hov = "" }
    bucket[e.name] = r
  end
  return r
end

local function by_value_desc(a, b)
  if a.v ~= b.v then return a.v > b.v end
  if a.name ~= b.name then return a.name < b.name end
  return a.ch < b.ch
end

local on = 0

local function add(e, v)
  local r = row_for(e)
  if r.gen ~= gen then
    r.gen = gen
    r.v = 0
    r.n = 0
    r.top = -1
    r.top_id = 0
    on = on + 1
    order[on] = r
  end
  if v > r.top or (v == r.top and e.id < r.top_id) then
    r.top, r.top_id = v, e.id
    r.icon = e.icon
    r.r, r.g, r.b = e.r, e.g, e.b
  end
  r.v = r.v + v
  r.n = r.n + 1
end

local function exact(by, ch)
  local SC = Verdant.SkillColors
  local sum = 0
  for id, v in pairs(by) do
    local e = entry_for(id, ch)
    local c = SC.group_color(SC.ability_group(id))
    e.r, e.g, e.b = c.r, c.g, c.b
    add(e, v)
    sum = sum + v
  end
  return sum
end


local function note(id)
  if seen[id] then return end
  seen[id] = true
  ids.n = ids.n + 1
  ids[ids.n] = id
  acc_heal[id] = 0
  acc_shield[id] = 0
end

local function finish()
  for k = on + 1, #order do order[k] = nil end
  order.n = on
  if on > 1 then table_sort(order, by_value_desc) end
end

local function aggregate()
  local TB = Verdant.TemporalBuffer
  local n = TB.count()
  gen = gen + 1
  on = 0
  local heal_by, shield_by = TB.ability_sums()
  if heal_by then
    totals.exact = true
    totals.heal = exact(heal_by, CH_HEAL)
    totals.shield = exact(shield_by, CH_SHIELD)
    totals.span = Verdant.BuffTracker.session_end() - Verdant.BuffTracker.session_start()
    finish()
    return
  end
  totals.exact = false
  for i = 1, ids.n do
    local id = ids[i]
    acc_heal[id] = 0
    acc_shield[id] = 0
  end
  totals.heal, totals.shield = 0, 0
  local t0, t_prev = 0, 0
  for i = 1, n do
    local s = TB.at(i)
    if i == 1 then
      t0 = s.t
    else
      local dt = (s.t - t_prev) / 1000
      if dt > 0 then
        local hv = math_floor(s.eHPS * 10 + 0.5) / 10 * dt
        local sv = math_floor(s.MPS * 10 + 0.5) / 10 * dt
        totals.heal = totals.heal + hv
        totals.shield = totals.shield + sv
        local ea = s.ehps_abilities
        for k = 1, (ea.count or 0) do
          local ab = ea[k]
          local id = ab.id
          note(id)
          acc_heal[id] = acc_heal[id] + math_floor(ab.share * 1000 + 0.5) / 1000 * hv
          local e = entry_for(id, CH_HEAL)
          e.r, e.g, e.b = ab.r, ab.g, ab.b
        end
        local ma = s.mps_abilities
        for k = 1, (ma.count or 0) do
          local ab = ma[k]
          local id = ab.id
          note(id)
          acc_shield[id] = acc_shield[id] + math_floor(ab.share * 1000 + 0.5) / 1000 * sv
          local e = entry_for(id, CH_SHIELD)
          e.r, e.g, e.b = ab.r, ab.g, ab.b
        end
      end
    end
    t_prev = s.t
  end
  totals.span = t_prev - t0

  for i = 1, ids.n do
    local id = ids[i]
    local h = acc_heal[id]
    if h > 0 then add(entry_for(id, CH_HEAL), h) end
    local sh = acc_shield[id]
    if sh > 0 then add(entry_for(id, CH_SHIELD), sh) end
  end
  finish()
end

local function label(c, text, x, y, w, h, col, align)
  local l = c.lbl:AcquireObject()
  l:ClearAnchors()
  l:SetText(text)
  l:SetHorizontalAlignment(align)
  l:SetColor(col.r, col.g, col.b, col.a or 1)
  l:SetDimensions(w, h)
  l:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x, y)
  l:SetHidden(false)
  return l
end

local function seg(c, x, y, w, h, r, g, b, a)
  local s = c.seg:AcquireObject()
  s:ClearAnchors()
  s:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x, y)
  s:SetWidth(w)
  s:SetHeight(h)
  s:SetColor(r, g, b, a)
  s:SetHidden(false)
  return s
end

function M.attach(t) ctx = t end

function M.render()
  local c = ctx
  if not c then return end
  c.seg:ReleaseAllObjects()
  if c.rim then c.rim:ReleaseAllObjects() end
  c.icon:ReleaseAllObjects()
  c.lbl:ReleaseAllObjects()
  c.hide_grid(c.grid)
  c.hit_reset()
  hit.n = 0
  aggregate()
  if order.n == 0 then
    c.no_data:SetHidden(false)
    return
  end
  c.no_data:SetHidden(true)

  local canvas = c.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  local top = c.layout.CHIP or 0
  if cw <= 200 or ch <= top + L.HEADER_H + L.ROW_H then return end
  Verdant.Diagnostics.bump("graph.view_contrib.renders")

  local S = strings()
  local x_val  = cw - L.VAL_W
  local x_type = x_val - L.TYPE_W - L.PAD
  local x_name = L.PAD + L.ICON + 6
  local name_w = x_type - x_name - 8
  label(c, S.contrib, L.PAD, top, x_type - L.PAD, L.HEADER_H, C_HEAD, TEXT_ALIGN_LEFT)
  label(c, S.type, x_type, top, L.TYPE_W, L.HEADER_H, C_HEAD, TEXT_ALIGN_LEFT)
  label(c, S.value, x_val, top, L.VAL_W - L.PAD, L.HEADER_H, C_HEAD, TEXT_ALIGN_RIGHT)
  seg(c, L.PAD, top + L.HEADER_H - 2, cw - 2 * L.PAD, 1, 1, 1, 1, 0.08)

  local step = L.ROW_H + L.ROW_GAP
  local rows_avail = math_floor((ch - top - L.HEADER_H) / step)
  if rows_avail < 1 then return end
  local n = order.n
  local show = n
  local rest = 0
  if n > rows_avail then
    show = rows_avail - 1
    if show < 1 then show = 1 end
    max_scroll = n - show
  else
    max_scroll = 0
  end
  if scroll > max_scroll then scroll = max_scroll end
  if scroll < 0 then scroll = 0 end
  rest = n - show - scroll
  local vmax = order[1].v
  local y = top + L.HEADER_H
  local hovered_seen = false

  for i = 1, show do
    local e = order[i + scroll]
    if e == hover_row then
      hovered_seen = true
      local band = seg(c, 0, y - 1, cw, L.ROW_H + 2, C_BAND.r, C_BAND.g, C_BAND.b, C_BAND.a)
      band:SetDrawLevel(1)
    end
    local ic = c.icon:AcquireObject()
    ic:ClearAnchors()
    ic:SetTexture(e.icon)
    ic:SetColor(1, 1, 1, 1)
    ic:SetDimensions(L.ICON, L.ICON)
    ic:SetAnchor(TOPLEFT, canvas, TOPLEFT, L.PAD, y + (L.ROW_H - L.ICON) / 2)
    ic:SetHidden(false)

    label(c, e.name, x_name, y + 1, name_w, L.NAME_H, C_NAME, TEXT_ALIGN_LEFT)

    local heal = (e.ch == CH_HEAL)
    local tc = heal and C_HEAL or C_SHIELD
    label(c, heal and S.heal or S.shield, x_type, y, L.TYPE_W, L.ROW_H, tc, TEXT_ALIGN_LEFT)

    local disp = math_floor(e.v)
    if e.disp ~= disp then
      e.disp = disp
      e.text = c.fmt_val(e.v)
    end
    label(c, e.text, x_val, y, L.VAL_W - L.PAD, L.ROW_H, C_VAL, TEXT_ALIGN_RIGHT)

    local by = y + L.NAME_H + 3
    local track = seg(c, x_name, by, name_w, L.BAR_H, C_TRACK.r, C_TRACK.g, C_TRACK.b, C_TRACK.a)
    track:SetDrawLevel(2)
    local bw = math_floor(name_w * e.v / vmax + 0.5)
    if bw < 1 then bw = 1 end
    if c.rim then
      local rim = c.rim:AcquireObject()
      rim:ClearAnchors()
      rim:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x_name - 1, by - 1)
      rim:SetWidth(bw + 2)
      rim:SetHeight(L.BAR_H + 2)
      rim:SetColor(0, 0, 0, 0.50)
      rim:SetHidden(false)
    end
    local fill = seg(c, x_name, by, bw, L.BAR_H, e.r, e.g, e.b, 0.92)
    fill:SetDrawLevel(4)

    hit.n = hit.n + 1
    hit.y0[hit.n] = y
    hit.y1[hit.n] = y + L.ROW_H
    hit.e[hit.n] = e
    y = y + step
  end

  if not hovered_seen then hover_row = nil end
  if rest > 0 or scroll > 0 then
    local key = scroll * 100000 + rest
    if more.n ~= key then
      more.n = key
      more.text = (scroll > 0) and string_format(S.scrolled, scroll, rest) or string_format(S.more, rest)
    end
    label(c, more.text, x_name, y, name_w, L.ROW_H, C_MORE, TEXT_ALIGN_LEFT)
  end
end

function M.hover(mx, my)
  local c = ctx
  if not c then return end
  local canvas = c.canvas
  local rel_x = mx - canvas:GetLeft()
  local rel_y = my - canvas:GetTop()
  if rel_x >= 0 and rel_x <= canvas:GetWidth() then
    for i = 1, hit.n do
      if rel_y >= hit.y0[i] and rel_y <= hit.y1[i] then
        local e = hit.e[i]
        if hover_row ~= e then
          hover_row = e
          if c.rerender then c.rerender() end
        end
        local S = strings()
        local heal = (e.ch == CH_HEAL)
        local tot = heal and totals.heal or totals.shield
        local pct = (tot > 0) and math_floor(e.v / tot * 100 + 0.5) or 0
        if e.hov_pct ~= pct or e.hov_disp ~= e.disp or e.hov_n ~= e.n or e.hov_exact ~= totals.exact then
          e.hov_pct, e.hov_disp, e.hov_n, e.hov_exact = pct, e.disp, e.n, totals.exact
          local tc = heal and C_HEAL or C_SHIELD
          e.hov = string_format("|c%s%s %s|r  ·  %d%%  ·  %s%s",
            c.hexc(tc), e.text, heal and S.heal or S.shield, pct, totals.exact and S.whole or S.est,
            (e.n > 1) and string_format(S.parts, e.n) or "")
        end
        c.show_card(e, e.name, e.hov, totals.span, mx, my)
        return
      end
    end
  end
  if hover_row ~= nil then
    hover_row = nil
    if c.rerender then c.rerender() end
  end
  c.hide_card()
end

function M.hovered() return hover_row end

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

function M.rows() return order, order.n end
M.KIND_HEAL, M.KIND_SHIELD = CH_HEAL, CH_SHIELD

function M.compute()
  aggregate()
  return order, order.n, totals
end
function M.totals() return totals end
