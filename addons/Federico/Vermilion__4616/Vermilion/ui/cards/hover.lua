Vermilion = Vermilion or {}
Vermilion.ChartHover = {}
local M = Vermilion.ChartHover

local api = Vermilion.zenimax.api
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local GetString          = api.GetString
local GetUIMousePosition = api.GetUIMousePosition
local TOPLEFT, BOTTOMLEFT = zc.TOPLEFT, zc.BOTTOMLEFT
local math_floor    = math.floor
local string_format = string.format

local HC = Vermilion.HoverCard
local clear_card_rows, position_card = HC.clear_rows, HC.place
local fit_card_rows, swatch_solid, swatch_icon = HC.fit_rows, HC.swatch_solid, HC.swatch_icon
local show_moment_card = HC.show_moment
local CARD_W, CARD_H, CARD_ROW_H, CARD_ROWS_Y0 = HC.CARD_W, HC.CARD_H, HC.ROW_H, HC.ROWS_Y0
local C_CARD_STAT, C_CARD_TIME = HC.C_STAT, HC.C_TIME

local Format = Vermilion.Format
local fmt_val, fmt_secs, fmt_readout, hexc = Format.val, Format.secs, Format.readout, Format.hex
local fade_in, fade_out = Vermilion.Fader.show, Vermilion.Fader.hide
local RES = Vermilion.FilmBands.RES
local DamageTypeColors = Vermilion.DamageTypeColors

local STATE, controls, VIS, CHIP, hit, DTYPE_ICON, ult_inset
local VIEWS
local C_LINE_EDPS, C_SHDPS, C_CRIT, C_VIEWPORT
local render_current_view
local card_fader, crosshair_fader

function M.bind(t)
  STATE, controls, VIS, CHIP, hit = t.STATE, t.controls, t.VIS, t.CHIP, t.hit
  DTYPE_ICON, ult_inset = t.DTYPE_ICON, t.ult_inset
  VIEWS = t.VIEWS
  C_LINE_EDPS, C_SHDPS, C_CRIT, C_VIEWPORT = t.C_LINE_EDPS, t.C_SHDPS, t.C_CRIT, t.C_VIEWPORT
  render_current_view = t.render
end

function M.attach(card, crosshair) card_fader, crosshair_fader = card, crosshair end

local function hover_allowed()
  return not Vermilion.TemporalBuffer.is_recording()
     and Vermilion.TemporalBuffer.count() > 0
     and not controls.window:IsHidden()
end

local function hover_label(view, band)
  if view.by_type then
    return (DamageTypeColors and DamageTypeColors.name(band.key)) or "Damage"
  end
  local k = band.key
  if not k or k == "" then return "Skill" end
  if k == "other" then return "Other" end
  if k == "shield" then return GetString(VERMILION_REPORT_SHIELDED) end
  return (tostring(k):gsub("_", " "))
end

local function stop_hover_poll() zev.unregister_update("VermilionHoverPoll") end

local function hide_hover_ui()
  fade_out(card_fader)
  fade_out(crosshair_fader)
end

local function show_card(view, band, col, mx, my, elapsed_ms)
  local card = controls.card
  if not card then return end
  local total = band.eos or 0
  local ticon = view.by_type and DTYPE_ICON[band.key] or nil
  if ticon then swatch_icon(card, ticon) else swatch_solid(card, band.r, band.g, band.b) end
  card.name:SetColor(band.r, band.g, band.b, 1.0)
  card.name:SetText(hover_label(view, band))
  local pct = math_floor((band.share or 0) * 100 + 0.5)
  local val = (band.share or 0) * total
  card.stat:SetText(string_format(GetString(VERMILION_CARD_RATE), fmt_readout(val), pct))
  card.time:SetText("t  " .. fmt_secs(elapsed_ms or 0))

  clear_card_rows(card)
  local shown = 0
  local list = nil
  if col and view.abilities then list = col[view.abilities] end
  if list and (list.count or 0) > 0 then
    local SC = Vermilion.SkillColors
    local n  = list.count
    local matched = 0
    for a = 1, n do
      local ab = list[a]
      if ab and ab.key == band.key then matched = matched + 1 end
    end
    for a = 1, n do
      if shown >= HC.LIST_MAX_ROWS then break end
      local ab = list[a]
      if ab and ab.key == band.key then
        shown = shown + 1
        local row = card.rows[shown]
        if shown == HC.LIST_MAX_ROWS and matched > HC.LIST_MAX_ROWS then
          row.icon:SetHidden(true)
          row.name:SetText(string_format("+%d more", matched - (HC.LIST_MAX_ROWS - 1)))
          row.name:SetColor(C_CARD_TIME.r, C_CARD_TIME.g, C_CARD_TIME.b, 1.0)
          row.name:SetHidden(false)
          row.val:SetText("")
          row.val:SetHidden(false)
          break
        end
        if (ab.id or 0) > 0 then
          row.icon:SetTexture(SC.ability_icon(ab.id))
          row.name:SetText(SC.ability_name(ab.id))
        else
          row.icon:SetTexture(DTYPE_ICON[-1])
          row.name:SetText(GetString(VERMILION_REPORT_SHIELDED))
        end
        row.icon:SetHidden(false)
        row.name:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 1.0)
        row.name:SetHidden(false)
        local av = (ab.share or 0) * total
        local ap = math_floor((ab.share or 0) * 100 + 0.5)
        row.val:SetText(string_format("%s · %d%%", fmt_readout(av), ap))
        local vc = ((ab.id or 0) > 0) and C_LINE_EDPS or C_SHDPS
        row.val:SetColor(vc.r, vc.g, vc.b, 1.0)
        row.val:SetHidden(false)
      end
    end
  end
  fit_card_rows(card, shown, CARD_W)
  card.root:SetHeight((shown > 0) and (CARD_ROWS_Y0 + shown * CARD_ROW_H + 4) or CARD_H)

  position_card(mx, my)
end

local function hover_pick(rel_x, height_above)
  if hit.n == 0 then return nil, nil end
  local col = nil
  for i = 1, hit.n do
    local c = hit.cols[i]
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

local function hover_bars(view, mx, my)
  local canvas = controls.canvas
  local rel_x  = mx - canvas:GetLeft()
  local above  = canvas:GetBottom() - my
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()

  local band, col = nil, nil
  if rel_x >= 0 and rel_x <= cw and above >= 0 and above <= ch then
    band, col = hover_pick(rel_x, above)
  end

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

  local elapsed = (col.t and hit.t0) and (col.t - hit.t0) or 0
  local tot = view.crit_moment and ((col.crit or 0) + (col.noncrit or 0)) or 0
  if band then
    show_card(view, band, col, mx, my, elapsed)
  elseif tot > 0 then
    show_moment_card(C_CRIT, "Crit",
      string_format(GetString(VERMILION_CRIT_MOMENT), hexc(C_CRIT), math_floor((col.crit or 0) / tot * 100 + 0.5), fmt_readout(tot)),
      elapsed, mx, my)
  else
    fade_out(card_fader)
  end
end

local function hover_poll()
  if not hover_allowed() then
    if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
    hide_hover_ui()
    return
  end
  local view = VIEWS[STATE.view]
  local canvas = controls.canvas
  local mx, my = GetUIMousePosition()
  local U = Vermilion.Ultimate
  if view.bands and U and U.has_data() and VIS.ult.span and VIS.ult.span > 0 then
    local rel_x = mx - canvas:GetLeft()
    local cw = canvas:GetWidth()
    local rel_y = my - canvas:GetTop() - CHIP.H
    if rel_x >= 0 and rel_x <= cw and rel_y >= 0 and rel_y < VIS.ult.AREA then
      local b = (rel_y < VIS.ult.PAD + VIS.ult.ROW_H + VIS.ult.GAP / 2) and 1 or 2
      local t = VIS.ult.t0 + (rel_x - VIS.ult.xl) / VIS.ult.bw * VIS.ult.span
      if t < VIS.ult.t0 then t = VIS.ult.t0 end
      if t > VIS.ult.t0 + VIS.ult.span then t = VIS.ult.t0 + VIS.ult.span end
      local id = U.id_at(b, t)
      if id == 0 then b = 1; id = U.id_at(1, t) end
      if id > 0 then
        local pct = U.pct_at(t, b)
        local ready = pct >= 1
        local stat = ready and ("|c" .. hexc(VIS.ready) .. GetString(VERMILION_ULT_CARD_READY) .. "|r")
                     or string_format(GetString(VERMILION_ULT_CARD_CHARGED), math_floor(pct * 100 + 0.5))
        if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
        show_moment_card(ready and VIS.ready or C_VIEWPORT, Vermilion.SkillColors.ability_name(id), stat,
          (hit.t0 and (t - hit.t0)) or 0, mx, my)
        return
      end
    end
  end

  if view.bands and VIS.res.on and VIS.res.span > 0 and VIS.res.bw > 0
     and Vermilion.TemporalBuffer.count() > 0 then
    local R = VIS.res
    local rel_x = mx - canvas:GetLeft()
    local rel_y = my - canvas:GetTop() - RES.y0()
    if rel_x >= 0 and rel_x <= canvas:GetWidth() and rel_y >= 0 and rel_y < R.AREA then
      local p = (rel_y < R.PAD + R.ROW_H + R.GAP / 2) and 1 or 2
      local t = R.t0 + (rel_x - R.xl) / R.bw * R.span
      local TB = Vermilion.TemporalBuffer
      local lo, hi = 1, TB.count()
      while lo < hi do
        local mid = math_floor((lo + hi + 1) / 2)
        if TB.at(mid).t <= t then lo = mid else hi = mid - 1 end
      end
      local s = TB.at(lo)
      local level = (p == 1) and (s.mag or 0) or (s.sta or 0)
      local gin = (p == 1) and (s.mag_in or 0) or (s.sta_in or 0)
      local gout = (p == 1) and (s.mag_out or 0) or (s.sta_out or 0)
      local sigma = Vermilion.Resources.window_sigma(TB, lo, 10, p)
      local name = (p == 1) and GetString(VERMILION_RES_MAGICKA) or GetString(VERMILION_RES_STAMINA)
      local col = (level > 0 and level < 0.30) and VIS.low or ((p == 1) and VIS.mag or VIS.sta)
      local stat = string_format(GetString(VERMILION_RES_CARD_FLOWS), fmt_val(gin), fmt_val(gout))
      if sigma then stat = stat .. string_format(GetString(VERMILION_RES_CARD_SIGMA), sigma) end
      if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
      show_moment_card(col, string_format("%s  %d%%", name, math_floor(level * 100 + 0.5)), stat,
        (hit.t0 and (s.t - hit.t0)) or 0, mx, my)
      return
    end
  end

  if view.bands and VIS.shield.on and VIS.shield.span > 0 and VIS.shield.bw > 0 and VIS.shield.max > 0
     and Vermilion.TemporalBuffer.count() > 0 then
    local S = VIS.shield
    local rel_x = mx - canvas:GetLeft()
    local rel_y = my - canvas:GetTop() - CHIP.H - ult_inset()
    if rel_x >= 0 and rel_x <= canvas:GetWidth() and rel_y >= 0 and rel_y < S.AREA then
      local t = S.t0 + (rel_x - S.xl) / S.bw * S.span
      local TB = Vermilion.TemporalBuffer
      local lo, hi = 1, TB.count()
      while lo < hi do
        local mid = math_floor((lo + hi + 1) / 2)
        if TB.at(mid).t <= t then lo = mid else hi = mid - 1 end
      end
      local s = TB.at(lo)
      if s and (s.ShDPS or 0) > 0 then
        local sh = s.ShDPS or 0
        local eos = (s.eDPS or 0) + sh
        if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
        show_moment_card(C_SHDPS, GetString(VERMILION_REPORT_SHIELDED),
          string_format("|c%s%s DPS|r  ·  %d%%", hexc(C_SHDPS), fmt_readout(sh), (eos > 0) and math_floor(sh / eos * 100 + 0.5) or 0),
          s.t - S.t0, mx, my, DTYPE_ICON[-1])
        return
      end
    end
  end
  local K = Vermilion.Kills
  if view.bars and K and K.count() > 0 and VIS.kills_span and VIS.kills_span > 0
     and (not Vermilion.Settings.kill_markers or Vermilion.Settings.kill_markers()) then
    local rel_x = mx - canvas:GetLeft()
    local rel_y = my - canvas:GetTop()
    if rel_y >= VIS.kills_y and rel_y <= VIS.kills_y + VIS.kill_size then
      for i = 1, K.count() do
        local kt, _, kname, kaid = K.get(i)
        local x = VIS.kills_xl + (kt - VIS.kills_t0) / VIS.kills_span * VIS.kills_bw
        if math.abs(rel_x - x) <= VIS.kill_size / 2 + 1 then
          if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
          show_moment_card(C_CRIT, (tostring(kname):gsub("%^%a+$", "")),
            string_format(GetString(VERMILION_KILL_CARD), Vermilion.SkillColors.ability_name(kaid)),
            (hit.t0 and (kt - hit.t0)) or 0, mx, my, VIS.kill_icon)
          return
        end
      end
    end
  end
  if view.rows then
    view.rows.hover(mx, my)
  else
    hover_bars(view, mx, my)
  end
end

local function update_hover_gate()
  local on = hover_allowed()
  if controls.hit then
    controls.hit:SetMouseEnabled(on)
    controls.hit:SetHidden(not on)
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
