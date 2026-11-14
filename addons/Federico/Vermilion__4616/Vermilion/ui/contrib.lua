Vermilion = Vermilion or {}
Vermilion.ContribView = {}
local M = Vermilion.ContribView

local math_floor    = math.floor
local string_format = string.format
local table_sort    = table.sort

local L = { HEADER_H = 20, ROW_H = 24, ROW_GAP = 2, ICON = 18, PAD = 4, RANK_W = 18, TYPE_W = 40, VAL_W = 72, BAR_H = 5, NAME_H = 14 }
local C_RANK  = { r = 0.62, g = 0.56, b = 0.55, a = 0.85 }
local RANK_TEXT = {}
for i = 1, 64 do RANK_TEXT[i] = tostring(i) end
local C_ZEBRA = { r = 1.0, g = 1.0, b = 1.0, a = 0.025 }
local C_HEAD   = { r = 0.64, g = 0.60, b = 0.60, a = 0.95 }
local C_NAME   = { r = 0.94, g = 0.88, b = 0.86, a = 1.0 }
local C_VAL    = { r = 0.87, g = 0.85, b = 0.83, a = 1.0 }
local C_MORE   = { r = 0.70, g = 0.64, b = 0.62, a = 1.0 }
local C_TRACK  = { r = 1.0, g = 1.0, b = 1.0, a = 0.06 }
local C_SHIELD = { r = 0.85, g = 0.40, b = 0.75 }
local C_BAND   = { r = 1.00, g = 0.62, b = 0.58, a = 0.10 }
local CH_SHIELD = -1

local ctx = nil
local acc = {}
local acc_abs = {}
local acc_dt = {}
local ids = { n = 0 }
local seen = {}
local entries = {}
local order = { n = 0 }
local hit = { n = 0, y0 = {}, y1 = {}, e = {} }
local totals = { damage = 0, shield = 0, span = 0 }
local more = { n = -1, text = "" }
local hover_row = nil
local scroll = 0
local max_scroll = 0
local str = nil

local function strings()
  if str then return str end
  str = {
    contrib  = GetString(VERMILION_CONTRIB_HEAD_CONTRIB),
    type     = GetString(VERMILION_CONTRIB_HEAD_TYPE),
    value    = GetString(VERMILION_CONTRIB_HEAD_VALUE),
    shield   = GetString(VERMILION_CONTRIB_TYPE_SHIELD),
    cracked  = GetString(VERMILION_REPORT_SHIELDED),
    absorbed = GetString(VERMILION_CONTRIB_ABSORBED),
    more     = GetString(VERMILION_CONTRIB_MORE),
    scrolled = GetString(VERMILION_CONTRIB_SCROLLED),
    est      = GetString(VERMILION_CONTRIB_TIP_EST),
    exact    = GetString(VERMILION_CONTRIB_TIP_EXACT),
    parts    = GetString(VERMILION_CONTRIB_PARTS),
  }
  return str
end

local function entry_for(id, ch)
  local key = id * 64 + (ch + 1)
  local e = entries[key]
  if not e then
    local SC = Vermilion.SkillColors
    local g = (id > 0) and SC.group_of(id) or "shield"
    local c = SC.group_color(g)
    e = { id = id, ch = ch, v = 0, r = c.r, g = c.g, b = c.b,
          icon = (id > 0) and SC.ability_icon(id) or ((ctx and ctx.type_icon) and ctx.type_icon(CH_SHIELD) or ""),
          name = (id > 0) and SC.ability_name(id) or strings().cracked }
    entries[key] = e
  end
  return e
end

local rows_by = {}
local gen = 0

local function row_for(e)
  local bucket = rows_by[e.ch]
  if not bucket then bucket = {}; rows_by[e.ch] = bucket end
  local r = bucket[e.name]
  if not r then
    local DTC = Vermilion.DamageTypeColors
    local tc = (e.ch == CH_SHIELD) and C_SHIELD or DTC.lookup(e.ch)
    r = { name = e.name, icon = e.icon, ch = e.ch, v = 0, abs = 0, n = 0, gen = -1, disp = -1, text = "",
          r = e.r, g = e.g, b = e.b, tr = tc.r, tg = tc.g, tb = tc.b,
          type = (e.ch == CH_SHIELD) and strings().shield or (DTC.name(e.ch) or "Damage"),
          hov_pct = -1, hov_disp = -1, hov_n = -1, hov_abs = -1, hov = "" }
    bucket[e.name] = r
  end
  return r
end

local function by_value_desc(a, b) return a.v > b.v end

local function note(id, dt)
  local key = id * 64 + (dt + 1)
  if seen[key] then return end
  seen[key] = true
  ids.n = ids.n + 1
  ids[ids.n] = key
  acc[key] = 0
  acc_abs[key] = 0
  acc_dt[key] = dt
end

local function aggregate()
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  for i = 1, ids.n do acc[ids[i]] = 0; acc_abs[ids[i]] = 0 end
  totals.damage, totals.shield = 0, 0
  local t0, t_prev = 0, 0
  local ex = Vermilion.Metrics.exact()
  if ex then
    if n > 0 then t0, t_prev = TB.at(1).t, TB.at(n).t end
    local abs = ex.skills_abs
    for key, v in pairs(ex.skills) do
      note(math_floor(key / 64), key % 64 - 1)
      local a = abs[key] or 0
      acc[key] = v
      acc_abs[key] = a
      totals.damage = totals.damage + v - a
      totals.shield = totals.shield + a
    end
  else
    for i = 1, n do
      local s = TB.at(i)
      if i == 1 then
        t0 = s.t
      else
        local dt = (s.t - t_prev) / 1000
        if dt > 0 then
          local dv = math_floor(s.eDPS * 10 + 0.5) / 10 * dt
          local sv = math_floor(s.ShDPS * 10 + 0.5) / 10 * dt
          totals.damage = totals.damage + dv
          totals.shield = totals.shield + sv
          local da = s.dtype_abilities
          local dn = da.count or 0
          local eos = dv + sv
          for k = 1, dn do
            local ab = da[k]
            local dtype = ab.key or 0
            note(ab.id, dtype)
            local key = ab.id * 64 + (dtype + 1)
            acc[key] = acc[key] + math_floor(ab.share * 1000 + 0.5) / 1000 * eos
            acc_abs[key] = acc_abs[key] + math_floor((ab.abs or 0) * 1000 + 0.5) / 1000 * eos
          end
        end
      end
      t_prev = s.t
    end
  end
  totals.span = t_prev - t0

  gen = gen + 1
  local on = 0
  for i = 1, ids.n do
    local key = ids[i]
    local v = acc[key]
    if v > 0 then
      local e = entry_for(math_floor(key / 64), acc_dt[key])
      local r = row_for(e)
      if r.gen ~= gen then
        r.gen = gen
        r.v = 0
        r.abs = 0
        r.n = 0
        on = on + 1
        order[on] = r
      end
      r.v = r.v + v
      r.abs = r.abs + acc_abs[key]
      r.n = r.n + 1
    end
  end
  for k = on + 1, #order do order[k] = nil end
  order.n = on
  if on > 1 then table_sort(order, by_value_desc) end
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
  local top = c.layout.H or 0
  if cw <= 200 or ch <= top + L.HEADER_H + L.ROW_H then return end
  Vermilion.Diagnostics.bump("graph.view_contrib.renders")

  local S = strings()
  local x_val  = cw - L.VAL_W
  local x_type = x_val - L.TYPE_W - L.PAD
  local x_icon = L.PAD + L.RANK_W
  local x_name = x_icon + L.ICON + 6
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
  if n > rows_avail then
    show = rows_avail - 1
    if show < 1 then show = 1 end
    max_scroll = n - show
  else
    max_scroll = 0
  end
  if scroll > max_scroll then scroll = max_scroll end
  if scroll < 0 then scroll = 0 end
  local rest = n - show - scroll
  local vmax = order[1].v
  local y = top + L.HEADER_H
  local hovered_seen = false

  for i = 1, show do
    local e = order[i + scroll]
    if i % 2 == 0 then
      local zebra = seg(c, 0, y - 1, cw, L.ROW_H + 2, C_ZEBRA.r, C_ZEBRA.g, C_ZEBRA.b, C_ZEBRA.a)
      zebra:SetDrawLevel(0)
    end
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
    ic:SetAnchor(TOPLEFT, canvas, TOPLEFT, x_icon, y + (L.ROW_H - L.ICON) / 2)
    ic:SetHidden(false)

    local rank = i + scroll
    label(c, RANK_TEXT[rank] or tostring(rank), 0, y, L.RANK_W, L.ROW_H, C_RANK, TEXT_ALIGN_RIGHT)

    label(c, e.name, x_name, y + 1, name_w, L.NAME_H, C_NAME, TEXT_ALIGN_LEFT)

    local ticon = c.type_icon and c.type_icon(e.ch) or nil
    if ticon then
      local ti = c.icon:AcquireObject()
      ti:ClearAnchors()
      ti:SetTexture(ticon)
      ti:SetDimensions(L.ICON, L.ICON)
      ti:SetColor(1, 1, 1, 1)
      ti:SetAnchor(TOPLEFT, canvas, TOPLEFT, x_type + 6, y + (L.ROW_H - L.ICON) / 2)
      ti:SetHidden(false)
    else
      local tl = label(c, e.type, x_type, y, L.TYPE_W, L.ROW_H, C_VAL, TEXT_ALIGN_LEFT)
      tl:SetColor(e.tr, e.tg, e.tb, 1)
    end

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
    if e.abs > 0 and e.v > 0 then
      local aw = math_floor(bw * e.abs / e.v + 0.5)
      if aw >= 1 and aw < bw then
        local tail = seg(c, x_name + bw - aw, by, aw, L.BAR_H, C_SHIELD.r, C_SHIELD.g, C_SHIELD.b, 0.92)
        tail:SetDrawLevel(5)
      end
    end

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
        local tot = totals.damage + totals.shield
        local pct = (tot > 0) and math_floor(e.v / tot * 100 + 0.5) or 0
        local abs_disp = math_floor(e.abs)
        if e.hov_pct ~= pct or e.hov_disp ~= e.disp or e.hov_n ~= e.n or e.hov_abs ~= abs_disp then
          e.hov_pct, e.hov_disp, e.hov_n, e.hov_abs = pct, e.disp, e.n, abs_disp
          e.hov = string_format("|c%02x%02x%02x%s|r  ·  %s  ·  %d%%%s  ·  %s%s",
            math_floor(e.tr * 255 + 0.5), math_floor(e.tg * 255 + 0.5), math_floor(e.tb * 255 + 0.5),
            e.type, e.text, pct,
            (abs_disp > 0 and e.ch ~= CH_SHIELD) and string_format("  ·  |c%02x%02x%02x%s %s|r",
              math_floor(C_SHIELD.r * 255 + 0.5), math_floor(C_SHIELD.g * 255 + 0.5), math_floor(C_SHIELD.b * 255 + 0.5),
              c.fmt_val(e.abs), S.absorbed) or "",
            Vermilion.Metrics.exact() and S.exact or S.est,
            (e.n > 1) and string_format(S.parts, e.n) or "")
        end
        c.show_card(e, e.name, e.hov, totals.span, mx, my, c.type_icon and c.type_icon(e.ch) or nil)
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
function M.clear_hover() hover_row = nil end

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
function M.compute()
  aggregate()
  return order, order.n, totals
end
function M.totals() return totals end
