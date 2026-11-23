Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ChartHover = {}
local M = Verdant.ChartHover

local api = Verdant.zenimax.api
local zc  = Verdant.zenimax.constants
local zev = Verdant.zenimax.events
local GetString          = api.GetString
local GetUIMousePosition = api.GetUIMousePosition
local TOPLEFT, BOTTOMLEFT = zc.TOPLEFT, zc.BOTTOMLEFT
local math_floor    = math.floor
local string_format = string.format

local HoverCard = Verdant.HoverCard
local clear_card_rows, position_card = HoverCard.clear_rows, HoverCard.place
local size_card, card_donut, desc_height = HoverCard.size, HoverCard.donut, HoverCard.desc_height
local show_moment_card = HoverCard.show_moment
local DONUT_SHADES = HoverCard.DONUT_SHADES
local CARD_W, CARD_H = HoverCard.CARD_W, HoverCard.CARD_H
local CARD_ROW_H, CARD_MAX_ROWS, CARD_ROWS_Y0 = HoverCard.ROW_H, HoverCard.LIST_MAX_ROWS, HoverCard.ROWS_Y0
local C_CARD_STAT, C_CARD_TIME = HoverCard.C_STAT, HoverCard.C_TIME

local Format = Verdant.Format
local fmt_val, fmt_secs, hexc = Format.value, Format.secs, Format.hex
local fade_in, fade_out = Verdant.Fader.show, Verdant.Fader.hide

local STATE, VIEW, VIEWS, controls, SCR, ULT_L
local BUFF_FOLD, BUFF_SELF, buff_hit, hit_main
local C_EHPS, C_MPS, C_CRIT, C_OVERHEAL, C_DMG_TEXT
local C_RMAG, C_RSTA
local C_VIEWPORT, C_ULT_READY
local buff_color, render_current_view
local card_fader, crosshair_fader

function M.bind(t)
  STATE, VIEW, VIEWS = t.STATE, t.VIEW, t.VIEWS
  controls, SCR, ULT_L = t.controls, t.SCR, t.ULT_L
  BUFF_FOLD, BUFF_SELF, buff_hit = t.BUFF_FOLD, t.BUFF_SELF, t.buff_hit
  hit_main = t.hit_main
  C_EHPS, C_MPS, C_CRIT, C_OVERHEAL, C_DMG_TEXT = t.C_EHPS, t.C_MPS, t.C_CRIT, t.C_OVERHEAL, t.C_DMG_TEXT
  C_RMAG, C_RSTA = t.C_RMAG, t.C_RSTA
  C_VIEWPORT, C_ULT_READY = t.C_VIEWPORT, t.C_ULT_READY
  buff_color, render_current_view = t.buff_color, t.render
end

function M.attach(card, crosshair)
  card_fader, crosshair_fader = card, crosshair
end

local function buff_description(rec)
  local d = rec.desc
  if d and d ~= "" then return d end
  Verdant.Diagnostics.bump("buffs.desc_miss")
  return nil
end

local function hover_allowed()
  return not Verdant.TemporalBuffer.is_recording()
     and Verdant.TemporalBuffer.count() > 0
     and not controls.window:IsHidden()
end

local function stop_hover_poll() zev.unregister_update("VerdantHoverPoll") end

local function hide_hover_ui()
  fade_out(card_fader)
  fade_out(crosshair_fader)
end

local function show_card(band, col, unit, mx, my, elapsed_ms)
  local card = controls.card
  if not card then return end
  local total = band.total or 0
  card.swatch:SetColor(band.r, band.g, band.b, 1.0)
  card.name:SetColor(band.r, band.g, band.b, 1.0)
  card.name:SetText(Verdant.SkillColors.group_label(band.key))
  local pct = math_floor((band.share or 0) * 100 + 0.5)
  local val = (band.share or 0) * total
  card.stat:SetText(string_format("%s %s  ·  %d%%", fmt_val(val), unit, pct))
  card.time:SetText("t  " .. fmt_secs(elapsed_ms or 0))

  clear_card_rows(card)
  local shown = 0
  local list = nil
  if col then
    list = (unit == "MPS") and col.mps_abilities or col.ehps_abilities
  end
  if list and (list.count or 0) > 0 then
    local SC      = Verdant.SkillColors
    local n       = list.count
    local matched = 0
    for a = 1, n do
      local ab = list[a]
      if ab and ab.key == band.key then matched = matched + 1 end
    end
    for a = 1, n do
      if shown >= CARD_MAX_ROWS then break end
      local ab = list[a]
      if ab and ab.key == band.key then
        shown = shown + 1
        local row = card.rows[shown]
        if shown == CARD_MAX_ROWS and matched > CARD_MAX_ROWS then
          row.icon:SetHidden(true)
          row.name:SetText(string_format("+%d more", matched - (CARD_MAX_ROWS - 1)))
          row.name:SetColor(C_CARD_TIME.r, C_CARD_TIME.g, C_CARD_TIME.b, 1.0)
          row.name:SetHidden(false)
          row.val:SetText("")
          row.val:SetHidden(false)
          break
        end
        HoverCard.row_icon(row, SC.ability_icon(ab.id))
        row.name:SetText(SC.ability_name(ab.id))
        row.name:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 1.0)
        row.name:SetHidden(false)
        local av = (ab.share or 0) * total
        local ap = math_floor((ab.share or 0) * 100 + 0.5)
        row.val:SetText(string_format("%s · %d%%", fmt_val(av), ap))
        row.val:SetHidden(false)
      end
    end
  end
  local want = CARD_W
  for a = 1, shown do
    local name = card.rows[a].name
    local nw = Verdant.Format.text_width(name, name:GetText()) + 102
    if nw > want then want = nw end
  end
  if want > 300 then want = 300 end
  size_card(want)
  card.root:SetHeight((shown > 0) and (CARD_ROWS_Y0 + shown * CARD_ROW_H + 4) or CARD_H)

  local group_share = band.share or 0
  if list and shown > 0 and group_share > 0 then
    local dn = card_donut()
    local vals, cols = SCR.donut_vals, SCR.donut_cols
    for i = 1, #vals do vals[i] = nil end
    local k, acc = 0, 0
    for a = 1, list.count do
      local ab = list[a]
      if ab and ab.key == band.key and k < #DONUT_SHADES then
        k = k + 1
        vals[k] = ab.share or 0
        acc = acc + vals[k]
        local f = DONUT_SHADES[k]
        local c = cols[k]
        c.r, c.g, c.b = band.r * f, band.g * f, band.b * f
      end
    end
    local rest = group_share - acc
    if rest > 0.005 then
      k = k + 1
      vals[k] = rest
      local c = cols[k]
      c.r, c.g, c.b = 0.35, 0.35, 0.33
    end
    dn:set(vals, cols)
    dn:control():SetHidden(false)
    card.name:SetWidth(want - 36 - 52)
  end

  if band.key == "other" then
    local desc = card.desc
    local dy = (shown > 0) and (CARD_ROWS_Y0 + shown * CARD_ROW_H + 4) or (CARD_H - 4)
    desc:ClearAnchors()
    desc:SetAnchor(TOPLEFT, card.root, TOPLEFT, 12, dy)
    desc:SetWidth(want - 20)
    desc:SetHeight(400)
    desc:SetText(GetString(VERDANT_UNKNOWN_HINT))
    desc:SetHidden(false)
    local dh = desc_height(desc)
    desc:SetHeight(dh)
    card.root:SetHeight(dy + dh + 8)
  end

  position_card(mx, my)
end

local function hover_pick(H, rel_x, height_above)
  if H.n == 0 then return nil, nil end
  local col = nil
  for i = 1, H.n do
    local c = H.cols[i]
    if c and rel_x >= c.x0 and rel_x <= c.x1 then col = c; break end
  end
  if not col then return nil, nil end
  local band = nil
  for b = 1, col.nb do
    local bd = col.bands[b]
    if height_above >= bd.lo and height_above <= bd.hi then band = bd; break end
  end
  return band, col
end

local function probe(canvas, H, mx, my)
  local rel_x = mx - canvas:GetLeft()
  local above = canvas:GetBottom() - my
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if rel_x < 0 or rel_x > cw or above < 0 or above > ch then return false end
  local band, col = hover_pick(H, rel_x, above)
  return true, band, col
end

local function show_buff_card(rec, t_at, conc_at, mx, my)
  local card = controls.card
  if not card then return end
  size_card(CARD_W)
  local BT  = Verdant.BuffTracker
  local c   = buff_color(rec)
  local dur = BT.session_end() - BT.session_start()
  local pct = (dur > 0) and math_floor(rec.uptime_ms / dur * 100 + 0.5) or 0

  card.swatch:SetColor(c.r, c.g, c.b, 1.0)
  card.name:SetColor(c.r, c.g, c.b, 1.0)
  card.name:SetText(rec.name or tostring(rec.id))
  card.stat:SetText(string_format("%s %d%%  ·  %s", GetString(VERDANT_BUFFH_UPTIME), pct, fmt_secs(rec.uptime_ms)))
  card.time:SetText(string_format("t  %s  ·  %d %s", fmt_secs(t_at), conc_at, GetString(VERDANT_BUFFH_HOLDERS)))

  clear_card_rows(card)
  local SC = Verdant.SkillColors
  local mine = SC.user_group(rec.id)
  local origin = (mine and SC.group_label(mine)) or Verdant.BuffOrigin.label(rec.id, rec.name)
  local grey = Verdant.BuffOrigin.is_grey(rec.id, rec.name, rec.group)
  local rows = {
    { GetString(VERDANT_BUFFH_PLAYERS), tostring(rec.unique_units) },
    { GetString(VERDANT_BUFFH_MAXC),    tostring(rec.max_conc) },
    { GetString(VERDANT_BUFFH_AVGC),    string_format("%.1f", BT.avg_concurrency(rec)) },
    { GetString(VERDANT_BUFFH_APPS),    tostring(rec.applications) },
    { GetString(VERDANT_BUFFH_GAP),     fmt_secs(rec.longest_gap_ms) },
  }
  if origin then
    rows[#rows + 1] = { GetString(VERDANT_BUFFH_FAMILY), origin }
  end
  for i = 1, #rows do
    local row = card.rows[i]
    row.icon:SetHidden(true)
    row.name:SetText(rows[i][1])
    row.name:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 1.0)
    row.name:SetHidden(false)
    row.val:SetText(rows[i][2])
    row.val:SetHidden(false)
  end
  local h = CARD_ROWS_Y0 + #rows * CARD_ROW_H + 4
  local d = buff_description(rec)
  if not d and rec.group == "item" then
    d = GetString(VERDANT_BUFFH_SET_NO_TOOLTIP)
  end
  if grey then
    d = (d and (d .. "\n\n") or "") .. GetString(VERDANT_BUFFH_UNKNOWN_HINT)
  end
  if d then
    local desc = card.desc
    desc:ClearAnchors()
    desc:SetAnchor(TOPLEFT, card.root, TOPLEFT, 12, h + 2)
    desc:SetWidth(CARD_W - 20)
    desc:SetHeight(400)
    desc:SetText(d)
    desc:SetHidden(false)
    local dh = desc_height(desc)
    desc:SetHeight(dh)
    h = h + dh + 10
  end
  card.root:SetHeight(h)
  position_card(mx, my)
end

local function buff_hover_poll(mx, my)
  local canvas = controls.canvas
  local rel_x  = mx - canvas:GetLeft()
  local rel_y  = my - canvas:GetTop()
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  local inside = rel_x >= 0 and rel_x <= cw and rel_y >= 0 and rel_y <= ch

  local rec = nil
  local strip = nil
  if inside and BUFF_FOLD.on and rel_y >= BUFF_FOLD.y0 and rel_y <= BUFF_FOLD.y1 then strip = BUFF_FOLD end
  if inside and BUFF_SELF.on and rel_y >= BUFF_SELF.y0 and rel_y <= BUFF_SELF.y1 then strip = BUFF_SELF end
  if strip then
    for k = 1, strip.n do
      if strip.x0[k] and rel_x >= strip.x0[k] and rel_x <= strip.x1[k] then
        rec = strip.rec[k]
        break
      end
    end
    local new = rec and rec.id or nil
    if new ~= STATE.hover_key then STATE.hover_key = new; render_current_view() end
    if rec then
      show_buff_card(rec, rec.uptime_ms, rec.max_conc or 0, mx, my)
    else
      hide_hover_ui()
    end
    return
  end
  if inside then
    for i = 1, buff_hit.n do
      if rel_y >= buff_hit.y0[i] and rel_y <= buff_hit.y1[i] then
        rec = buff_hit.rec[i]
        break
      end
    end
  end

  local new = rec and rec.id or nil
  if new ~= STATE.hover_key then STATE.hover_key = new; render_current_view() end

  if not rec or buff_hit.span <= 0 then
    hide_hover_ui()
    return
  end

  local frac = (rel_x - buff_hit.lane_x) / buff_hit.lane_w
  if frac < 0 then frac = 0 end
  if frac > 1 then frac = 1 end
  local t_abs = buff_hit.t0 + frac * buff_hit.span
  local conc  = Verdant.BuffTracker.concurrency_at(rec, t_abs)

  if controls.crosshair then
    local cx = math_floor(rel_x)
    controls.crosshair:ClearAnchors()
    controls.crosshair:SetAnchor(TOPLEFT,    canvas, TOPLEFT,    cx, 0)
    controls.crosshair:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, cx, 0)
    fade_in(crosshair_fader)
  end

  show_buff_card(rec, t_abs - buff_hit.t0, conc, mx, my)
end

local function hover_poll()
  if not hover_allowed() then
    if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
    hide_hover_ui()
    return
  end
  local mx, my = GetUIMousePosition()
  if STATE.view == VIEW.BUFFS then
    buff_hover_poll(mx, my)
    return
  end
  if STATE.view == VIEW.RESOURCES then
    Verdant.ResourcesView.hover(mx, my)
    return
  end
  if STATE.view ~= VIEW.CONTRIB and Verdant.Ultimate.has_data() then
    local canvas = controls.canvas
    local g_t0, g_span, g_xl, g_bw = ULT_L.t0, ULT_L.span, ULT_L.xl, ULT_L.bw
    local rel_x  = mx - canvas:GetLeft()
    local rel_y  = my - canvas:GetTop() - ULT_L.CHIP
    if g_span and g_span > 0 and rel_x >= 0 and rel_x <= canvas:GetWidth() and rel_y >= 0 and rel_y < ULT_L.AREA then
      local U = Verdant.Ultimate
      local b = (rel_y < ULT_L.PAD + ULT_L.ROW_H + ULT_L.GAP / 2) and 1 or 2
      local t = g_t0 + (rel_x - g_xl) / g_bw * g_span
      if t < g_t0 then t = g_t0 end
      if t > g_t0 + g_span then t = g_t0 + g_span end
      local id = U.id_at(b, t)
      if id == 0 then b = 1; id = U.id_at(1, t) end
      if id > 0 then
        local pct = U.pct_at(t, b)
        local ready = pct >= 1
        local stat = ready and ("|c" .. hexc(C_ULT_READY) .. GetString(VERDANT_ULT_CARD_READY) .. "|r")
                     or string_format(GetString(VERDANT_ULT_CARD_CHARGED), math_floor(pct * 100 + 0.5))
        show_moment_card(ready and C_ULT_READY or C_VIEWPORT,
          Verdant.SkillColors.ability_name(id), stat,
          t - Verdant.BuffTracker.session_start(), mx, my)
        return
      end
    end
  end
  if STATE.view == VIEW.CONTRIB then
    Verdant.ContribView.hover(mx, my)
    return
  end
  local canvas, H = controls.canvas, hit_main
  if STATE.view == VIEW.SKILL then
    local key = Verdant.SkillView.legend_at(mx - canvas:GetLeft(), my - canvas:GetTop())
    if key then
      if key ~= STATE.hover_key then STATE.hover_key = key; render_current_view() end
      hide_hover_ui()
      return
    end
  end
  local _, band, col = probe(canvas, hit_main, mx, my)
  local unit = band and band.unit

  local new = band and band.key or nil
  if new ~= STATE.hover_key then STATE.hover_key = new; render_current_view() end

  if not col then hide_hover_ui(); return end

  if controls.crosshair then
    local cx = math_floor((col.x0 + col.x1) * 0.5)
    controls.crosshair:ClearAnchors()
    controls.crosshair:SetAnchor(TOPLEFT,    canvas, TOPLEFT,    cx, 0)
    controls.crosshair:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, cx, 0)
    fade_in(crosshair_fader)
  end

  local elapsed = (col.t and H.t0) and (col.t - H.t0) or 0
  if band then
    show_card(band, col, unit, mx, my, elapsed)
  elseif STATE.view == VIEW.EMS then
    local dmg_part = ""
    if (col.d or 0) > 0 then
      dmg_part = string_format("  ·  |c%s%s dmg|r", hexc(C_DMG_TEXT), fmt_val(col.d))
    end
    show_moment_card(C_EHPS, "Healing",
      string_format("|c%s%s HPS|r  ·  |c%s%s MPS|r%s",
        hexc(C_EHPS), fmt_val(col.ehps or 0), hexc(C_MPS), fmt_val(col.mps or 0), dmg_part),
      elapsed, mx, my)
  elseif STATE.view == VIEW.SUSTAIN then
    show_moment_card(C_RMAG, GetString(VERDANT_RESTORE_CARD),
      string_format(GetString(VERDANT_RESTORE_CARD_STAT), hexc(C_RMAG), fmt_val(col.rm), hexc(C_RSTA), fmt_val(col.rs)),
      elapsed, mx, my)
  elseif STATE.view == VIEW.OVERHEAL then
    local tot = (col.eh or 0) + (col.oh or 0)
    local op  = (tot > 0) and math_floor((col.oh or 0) / tot * 100 + 0.5) or 0
    show_moment_card(C_OVERHEAL, "Overheal",
      string_format(GetString(VERDANT_OHEAL_CARD_STAT), hexc(C_OVERHEAL), op, fmt_val(col.eh or 0)),
      elapsed, mx, my)
  else
    fade_out(card_fader)
  end
end

local function update_hover_gate()
  local on = hover_allowed()
  if controls.hit_main then
    controls.hit_main:SetMouseEnabled(on)
    controls.hit_main:SetHidden(not on)
  end
  if not on then
    stop_hover_poll()
    hide_hover_ui()
    if STATE.hover_key ~= nil then
      STATE.hover_key = nil
      if not controls.window:IsHidden() then render_current_view() end
    end
  end
end

M.allowed, M.stop_poll, M.hide_ui = hover_allowed, stop_hover_poll, hide_hover_ui
M.poll, M.update_gate = hover_poll, update_hover_gate
