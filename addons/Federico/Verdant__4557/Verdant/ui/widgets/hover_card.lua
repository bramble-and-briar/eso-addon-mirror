Verdant = Verdant or {}
local Verdant = Verdant

Verdant.HoverCard = {}
local M = Verdant.HoverCard

local api  = Verdant.zenimax.api
local zui  = Verdant.zenimax.ui
local zc   = Verdant.zenimax.constants
local zev  = Verdant.zenimax.events
local WINDOW_MANAGER    = zui.WINDOW_MANAGER
local math_floor        = math.floor
local log               = Verdant.Log.for_module("hover_card")
local TOPLEFT           = zc.TOPLEFT
local TOPRIGHT          = zc.TOPRIGHT
local BOTTOMLEFT        = zc.BOTTOMLEFT
local BOTTOMRIGHT       = zc.BOTTOMRIGHT
local GuiRoot           = zc.GuiRoot
local CT_TEXTURE        = zc.CT_TEXTURE
local CT_LABEL          = zc.CT_LABEL
local TEXT_ALIGN_LEFT   = zc.TEXT_ALIGN_LEFT
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local TEXT_ALIGN_RIGHT  = zc.TEXT_ALIGN_RIGHT
local TEXT_ALIGN_TOP    = zc.TEXT_ALIGN_TOP
local DT_HIGH           = zc.DT_HIGH
local DL_OVERLAY        = zc.DL_OVERLAY

local FILL_TEXTURE = Verdant.ChartPools.FILL_TEXTURE
local fmt_secs     = Verdant.Format.secs
local fade_in, fade_out = Verdant.Fader.show, Verdant.Fader.hide

local CARD_W, CARD_H = 210, 56
local CARD_ROW_H     = 16
local CARD_MAX_ROWS  = 13
local LIST_MAX_ROWS  = 7
local CARD_ROWS_Y0   = 54
local C_CARD_STAT   = { r = 0.87, g = 0.87, b = 0.83, a = 1.0 }
local C_CARD_NAME   = { r = 0.97, g = 0.95, b = 0.89, a = 1.0 }
local C_CARD_TIME   = { r = 0.70, g = 0.68, b = 0.62, a = 1.0 }

local controls, SCR, card_fader

function M.bind(shared)
  controls = shared.controls
  SCR = shared.SCR
end

function M.attach(fader)
  card_fader = fader
end

local function build_hover_card()
  local WM   = WINDOW_MANAGER
  local root = WM:CreateControl("VerdantHoverCard", controls.window, zc.CT_CONTROL)
  root:SetDimensions(CARD_W, CARD_H)
  root:SetMouseEnabled(false)
  root:SetDrawLevel(20)
  root:SetAlpha(0)
  root:SetHidden(true)

  local frame = WM:CreateControl("VerdantHoverCardFrame", root, zc.CT_BACKDROP)
  frame:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
  frame:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 0, 0)
  Verdant.Skin.panel(frame)

  local swatch = WM:CreateControl("VerdantHoverCardSwatch", root, CT_TEXTURE)
  swatch:SetTexture(FILL_TEXTURE)
  swatch:SetTextureCoords(0, 1, 0, 0.05)
  swatch:SetDimensions(10, 10)
  swatch:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 9)

  local name = WM:CreateControl("VerdantHoverCardName", root, CT_LABEL)
  name:SetFont("ZoFontGameBold")
  name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  name:SetAnchor(TOPLEFT, root, TOPLEFT, 28, 6)
  name:SetDimensions(CARD_W - 36, 16)

  local stat = WM:CreateControl("VerdantHoverCardStat", root, CT_LABEL)
  stat:SetFont("ZoFontGameSmall")
  stat:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  stat:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  stat:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 1.0)
  stat:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 24)
  stat:SetDimensions(CARD_W - 20, 14)

  local time = WM:CreateControl("VerdantHoverCardTime", root, CT_LABEL)
  time:SetFont("ZoFontGameSmall")
  time:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  time:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  time:SetColor(C_CARD_TIME.r, C_CARD_TIME.g, C_CARD_TIME.b, 1.0)
  time:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 40)
  time:SetDimensions(CARD_W - 20, 12)

  local desc = WM:CreateControl("VerdantHoverCardDesc", root, CT_LABEL)
  desc:SetFont("ZoFontGameSmall")
  desc:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  desc:SetVerticalAlignment(TEXT_ALIGN_TOP)
  desc:SetMaxLineCount(0)
  desc:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 0.92)
  desc:SetHidden(true)

  local rows = {}
  for i = 1, CARD_MAX_ROWS do
    local y = CARD_ROWS_Y0 + (i - 1) * CARD_ROW_H

    local icon = WM:CreateControl("VerdantHoverCardIcon" .. i, root, CT_TEXTURE)
    icon:SetDimensions(13, 13)
    icon:SetAnchor(TOPLEFT, root, TOPLEFT, 12, y + 1)
    icon:SetHidden(true)

    local rn = WM:CreateControl("VerdantHoverCardRowName" .. i, root, CT_LABEL)
    rn:SetFont("ZoFontGameSmall")
    rn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    rn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    rn:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 1.0)
    rn:SetAnchor(TOPLEFT, root, TOPLEFT, 30, y)
    rn:SetDimensions(108, CARD_ROW_H)
    rn:SetHidden(true)

    local rv = WM:CreateControl("VerdantHoverCardRowVal" .. i, root, CT_LABEL)
    rv:SetFont("ZoFontGameSmall")
    rv:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    rv:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    rv:SetColor(C_CARD_TIME.r, C_CARD_TIME.g, C_CARD_TIME.b, 1.0)
    rv:SetAnchor(TOPRIGHT, root, TOPRIGHT, -8, y)
    rv:SetDimensions(60, CARD_ROW_H)
    rv:SetHidden(true)

    rows[i] = { icon = icon, name = rn, val = rv }
  end

  local pieces = { root, frame, swatch, name, stat, time, desc }
  for i = 1, #pieces do
    pieces[i]:SetDrawTier(DT_HIGH)
    pieces[i]:SetDrawLayer(DL_OVERLAY)
    if i > 2 then pieces[i]:SetDrawLevel(1) end
  end
  for i = 1, CARD_MAX_ROWS do
    local r = rows[i]
    r.icon:SetDrawTier(DT_HIGH); r.icon:SetDrawLayer(DL_OVERLAY); r.icon:SetDrawLevel(1)
    r.name:SetDrawTier(DT_HIGH); r.name:SetDrawLayer(DL_OVERLAY); r.name:SetDrawLevel(1)
    r.val:SetDrawTier(DT_HIGH);  r.val:SetDrawLayer(DL_OVERLAY); r.val:SetDrawLevel(1)
  end
  controls.card = { root = root, swatch = swatch, name = name, stat = stat, time = time, desc = desc, rows = rows }
end

local function desc_height(desc)
  local w = desc:GetWidth()
  if not w or w < 40 then w = CARD_W - 20 end
  local text = desc:GetText() or ""
  local lines = math_floor((#text * 6.4) / w) + 1
  local est = lines * 14 + 2
  local dh = desc:GetTextHeight() or 0
  if dh < est then dh = est end
  if dh < 12 then dh = 12 end
  return dh
end

local function clear_card_rows(card)
  local rows = card.rows
  if not rows then return end
  for i = 1, CARD_MAX_ROWS do
    local r = rows[i]
    r.icon:SetHidden(true); r.name:SetHidden(true); r.val:SetHidden(true)
    r.val:SetColor(C_CARD_TIME.r, C_CARD_TIME.g, C_CARD_TIME.b, 1.0)
  end
  if card.desc then card.desc:SetHidden(true) end
  if controls.card_donut then controls.card_donut:control():SetHidden(true) end
end

local function card_guard()
  local f = card_fader
  local root = f.control
  if root:IsHidden() then
    zev.unregister_update("VerdantCardGuard")
    return
  end
  if f.visible then
    if f.report and not api.MouseIsOver(controls.summary.hit) then fade_out(f) end
    return
  end
  if f.anim:IsPlaying() then return end
  log:info("card guard forced a hide: alpha=", root:GetAlpha(), "report=", tostring(f.report))
  root:SetAlpha(0)
  root:SetHidden(true)
  zev.unregister_update("VerdantCardGuard")
end

local function position_card(mx, my)
  local card = controls.card
  local sw, sh = GuiRoot:GetDimensions()
  local w = card.root:GetWidth()
  local h = card.root:GetHeight()
  local x = mx + 16
  local y = my + 18
  if x + w > sw - 4 then x = mx - w - 16 end
  if x < 4 then x = 4 end
  if y + h > sh - 4 then y = my - h - 18 end
  if y < 4 then y = 4 end
  card.root:ClearAnchors()
  card.root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
  card_fader.report = false
  fade_in(card_fader)
  zev.register_update("VerdantCardGuard", 100, card_guard)
end

local function size_card(w)
  local card = controls.card
  card.root:SetWidth(w)
  card.name:SetWidth(w - 36)
  card.stat:SetWidth(w - 20)
  card.time:SetWidth(w - 20)
  for i = 1, CARD_MAX_ROWS do
    card.rows[i].name:SetWidth(w - 102)
  end
end

local DONUT_SHADES = { 1.00, 0.82, 0.66, 0.52, 0.40, 0.30 }

local function row_swatch(row, c)
  local icon = row.icon
  icon:SetTexture(FILL_TEXTURE)
  icon:SetTextureCoords(0, 1, 0, 0.05)
  icon:SetColor(c.r, c.g, c.b, 1)
  icon:SetHidden(false)
end

local function row_icon(row, path)
  local icon = row.icon
  icon:SetTexture(path)
  icon:SetTextureCoords(0, 1, 0, 1)
  icon:SetColor(1, 1, 1, 1)
  icon:SetHidden(false)
end

local function card_donut()
  local card = controls.card
  if not controls.card_donut then
    local Donut = Verdant.lib.plot.Donut
    controls.card_donut = Donut.new("VerdantReportDonut", card.root, 44, { mode = "stack", tier = DT_HIGH, layer = DL_OVERLAY })
    controls.card_donut:control():SetAnchor(TOPRIGHT, card.root, TOPRIGHT, -10, 8)
    controls.card_donut:control():SetDrawLevel(21)
    for i = 1, #DONUT_SHADES + 1 do
      SCR.donut_cols[i] = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
    end
  end
  return controls.card_donut
end

local function show_moment_card(swatch_c, name_text, stat_text, elapsed_ms, mx, my)
  local card = controls.card
  if not card then return end
  size_card(CARD_W)
  card.swatch:SetColor(swatch_c.r, swatch_c.g, swatch_c.b, 1.0)
  card.name:SetColor(C_CARD_NAME.r, C_CARD_NAME.g, C_CARD_NAME.b, 1.0)
  card.name:SetText(name_text)
  card.stat:SetText(stat_text)
  card.time:SetText("t  " .. fmt_secs(elapsed_ms or 0))
  clear_card_rows(card)
  card.root:SetHeight(CARD_H)
  position_card(mx, my)
end

local function show_rows_card(swatch_c, name_text, stat_text, time_text, rows, n_rows, mx, my)
  local card = controls.card
  if not card then return end
  card.swatch:SetColor(swatch_c.r, swatch_c.g, swatch_c.b, 1.0)
  card.name:SetColor(swatch_c.r, swatch_c.g, swatch_c.b, 1.0)
  card.name:SetText(name_text)
  card.stat:SetText(stat_text)
  card.time:SetText(time_text)
  clear_card_rows(card)
  local n = (n_rows < CARD_MAX_ROWS) and n_rows or CARD_MAX_ROWS
  local want = CARD_W
  for i = 1, n do
    local row = card.rows[i]
    row.icon:SetHidden(true)
    row.name:SetText(rows[i][1])
    row.name:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 1.0)
    row.name:SetHidden(false)
    row.val:SetText(rows[i][2])
    local vc = rows[i][3] or C_CARD_TIME
    row.val:SetColor(vc.r, vc.g, vc.b, 1.0)
    row.val:SetHidden(false)
    local nw = Verdant.Format.text_width(row.name, rows[i][1]) + Verdant.Format.text_width(row.val, rows[i][2]) + 48
    if nw > want then want = nw end
  end
  if want > 320 then want = 320 end
  size_card(want)
  card.root:SetHeight((n > 0) and (CARD_ROWS_Y0 + n * CARD_ROW_H + 4) or CARD_H)
  position_card(mx, my)
end

M.CARD_W, M.CARD_H = CARD_W, CARD_H
M.ROW_H, M.MAX_ROWS, M.ROWS_Y0 = CARD_ROW_H, CARD_MAX_ROWS, CARD_ROWS_Y0
M.LIST_MAX_ROWS = LIST_MAX_ROWS
M.C_STAT, M.C_NAME, M.C_TIME = C_CARD_STAT, C_CARD_NAME, C_CARD_TIME
M.DONUT_SHADES = DONUT_SHADES
M.build       = build_hover_card
M.clear_rows  = clear_card_rows
M.desc_height = desc_height
M.place       = position_card
M.size        = size_card
M.donut       = card_donut
M.row_swatch  = row_swatch
M.row_icon    = row_icon
M.show_moment = show_moment_card
M.show_rows   = show_rows_card
