Vermilion = Vermilion or {}
Vermilion.HoverCard = {}
local M = Vermilion.HoverCard

local api = Vermilion.zenimax.api
local zc = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local Fader = Vermilion.Fader
local fade_in, fade_out = Fader.show, Fader.hide
local math_floor = math.floor
local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local CT_TEXTURE, CT_LABEL = zc.CT_TEXTURE, zc.CT_LABEL
local TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT, GuiRoot = zc.TOPLEFT, zc.TOPRIGHT, zc.BOTTOMLEFT, zc.BOTTOMRIGHT, zc.GuiRoot
local TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT = zc.TEXT_ALIGN_LEFT, zc.TEXT_ALIGN_CENTER, zc.TEXT_ALIGN_RIGHT
local WINDOW_MANAGER = Vermilion.zenimax.ui.WINDOW_MANAGER
local log = Vermilion.Log.for_module("hover_card")

local CARD_W, CARD_H = 210, 56
local CARD_ROW_H     = 16
local CARD_MAX_ROWS  = 19
local LIST_MAX_ROWS  = 13
local CARD_ROWS_Y0   = 54
local C_CARD_BG     = { r = 0.10, g = 0.04, b = 0.05, a = 0.96 }
local C_CARD_ACCENT = { r = 0.88, g = 0.24, b = 0.18, a = 1.0 }
local C_CARD_STAT   = { r = 0.92, g = 0.84, b = 0.82, a = 1.0 }
local C_CARD_NAME   = { r = 1.00, g = 0.90, b = 0.88, a = 1.0 }
local C_CARD_TIME   = { r = 0.72, g = 0.64, b = 0.62, a = 1.0 }

M.CARD_W, M.CARD_H, M.ROW_H, M.MAX_ROWS, M.ROWS_Y0 = CARD_W, CARD_H, CARD_ROW_H, CARD_MAX_ROWS, CARD_ROWS_Y0
M.LIST_MAX_ROWS = LIST_MAX_ROWS
M.C_STAT, M.C_NAME, M.C_TIME = C_CARD_STAT, C_CARD_NAME, C_CARD_TIME

local C_GOLD = { r = 0.80, g = 0.68, b = 0.40 }
local the_card, card_fader, report_anchor, fmt_secs
function M.build(parent, report_control, format_secs)
  local WM   = WINDOW_MANAGER
  local root = WM:CreateControl("VermilionHoverCard", parent, zc.CT_CONTROL)
  root:SetDimensions(CARD_W, CARD_H)
  root:SetMouseEnabled(false)
  root:SetDrawLevel(20)
  root:SetAlpha(0)
  root:SetHidden(true)

  local bg = WM:CreateControl("VermilionHoverCardBg", root, CT_TEXTURE)
  bg:SetTexture(FILL_TEXTURE)
  bg:SetTextureCoords(0, 1, 0, 0.05)
  bg:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
  bg:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 0, 0)
  bg:SetColor(C_CARD_BG.r, C_CARD_BG.g, C_CARD_BG.b, C_CARD_BG.a)

  local accent = WM:CreateControl("VermilionHoverCardAccent", root, CT_TEXTURE)
  accent:SetTexture(FILL_TEXTURE)
  accent:SetTextureCoords(0, 0.05, 0, 1)
  accent:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
  accent:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 0, 0)
  accent:SetWidth(3)
  accent:SetColor(C_CARD_ACCENT.r, C_CARD_ACCENT.g, C_CARD_ACCENT.b, 1.0)

  for _, e in ipairs({ { "T", TOPLEFT, TOPRIGHT, true }, { "B", BOTTOMLEFT, BOTTOMRIGHT, true }, { "L", TOPLEFT, BOTTOMLEFT, false }, { "R", TOPRIGHT, BOTTOMRIGHT, false } }) do
    local edge = WM:CreateControl("VermilionHoverCardEdge" .. e[1], root, CT_TEXTURE)
    edge:SetTexture(FILL_TEXTURE)
    edge:SetTextureCoords(0, 1, 0, 0.05)
    edge:SetAnchor(e[2], root, e[2], 0, 0)
    edge:SetAnchor(e[3], root, e[3], 0, 0)
    if e[4] then edge:SetHeight(1) else edge:SetWidth(1) end
    edge:SetColor(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.45)
    edge:SetDrawLevel(2)
  end

  local swatch = WM:CreateControl("VermilionHoverCardSwatch", root, CT_TEXTURE)
  swatch:SetTexture(FILL_TEXTURE)
  swatch:SetTextureCoords(0, 1, 0, 0.05)
  swatch:SetDimensions(14, 14)
  swatch:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 7)

  local name = WM:CreateControl("VermilionHoverCardName", root, CT_LABEL)
  name:SetFont("ZoFontGameBold")
  name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  name:SetAnchor(TOPLEFT, root, TOPLEFT, 28, 6)
  name:SetDimensions(CARD_W - 36, 16)

  local stat = WM:CreateControl("VermilionHoverCardStat", root, CT_LABEL)
  stat:SetFont("ZoFontGameSmall")
  stat:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  stat:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  stat:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 1.0)
  stat:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 24)
  stat:SetDimensions(CARD_W - 20, 14)

  local time = WM:CreateControl("VermilionHoverCardTime", root, CT_LABEL)
  time:SetFont("ZoFontGameSmall")
  time:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  time:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  time:SetColor(C_GOLD.r, C_GOLD.g, C_GOLD.b, 1.0)
  time:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 40)
  time:SetDimensions(CARD_W - 20, 12)

  local desc = WM:CreateControl("VermilionHoverCardDesc", root, CT_LABEL)
  desc:SetFont("ZoFontGameSmall")
  desc:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  desc:SetVerticalAlignment(zc.TEXT_ALIGN_TOP)
  desc:SetMaxLineCount(0)
  desc:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 0.92)
  desc:SetHidden(true)

  local rows = {}
  for i = 1, CARD_MAX_ROWS do
    local y = CARD_ROWS_Y0 + (i - 1) * CARD_ROW_H

    local icon = WM:CreateControl("VermilionHoverCardIcon" .. i, root, CT_TEXTURE)
    icon:SetDimensions(13, 13)
    icon:SetAnchor(TOPLEFT, root, TOPLEFT, 12, y + 1)
    icon:SetHidden(true)

    local rn = WM:CreateControl("VermilionHoverCardRowName" .. i, root, CT_LABEL)
    rn:SetFont("ZoFontGameSmall")
    rn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    rn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    rn:SetColor(C_CARD_STAT.r, C_CARD_STAT.g, C_CARD_STAT.b, 1.0)
    rn:SetAnchor(TOPLEFT, root, TOPLEFT, 30, y)
    rn:SetDimensions(108, CARD_ROW_H)
    rn:SetHidden(true)

    local rv = WM:CreateControl("VermilionHoverCardRowVal" .. i, root, CT_LABEL)
    rv:SetFont("ZoFontGameSmall")
    rv:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    rv:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    rv:SetColor(C_CARD_TIME.r, C_CARD_TIME.g, C_CARD_TIME.b, 1.0)
    rv:SetAnchor(TOPRIGHT, root, TOPRIGHT, -8, y)
    rv:SetDimensions(64, CARD_ROW_H)
    rv:SetHidden(true)

    rows[i] = { icon = icon, name = rn, val = rv }
  end

  the_card = { root = root, swatch = swatch, name = name, stat = stat, time = time, rows = rows, desc = desc }
  card_fader = Fader.new(root)
  root:SetDrawTier(DT_HIGH)
  report_anchor = report_control
  fmt_secs = format_secs
  return the_card
end

function M.clear_rows(card)
  local rows = card.rows
  if not rows then return end
  for i = 1, CARD_MAX_ROWS do
    local r = rows[i]
    r.icon:SetHidden(true); r.name:SetHidden(true); r.val:SetHidden(true)
    r.val:SetColor(C_CARD_TIME.r, C_CARD_TIME.g, C_CARD_TIME.b, 1.0)
  end
  if card.desc then card.desc:SetHidden(true) end
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

local function card_guard()
  local f = card_fader
  local root = f.control
  if root:IsHidden() then
    zev.unregister_update("VermilionCardGuard")
    return
  end
  if f.visible then
    if f.report and not api.MouseIsOver(report_anchor) then fade_out(f) end
    return
  end
  if f.anim:IsPlaying() then return end
  log:info("card guard forced a hide: alpha=", root:GetAlpha(), "report=", tostring(f.report))
  root:SetAlpha(0)
  root:SetHidden(true)
  zev.unregister_update("VermilionCardGuard")
end

function M.place(mx, my)
  local card = the_card
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
  zev.register_update("VermilionCardGuard", 100, card_guard)
end

local CARD_MAX_W = 360

function M.size(w)
  local card = the_card
  if card.width == w then return end
  card.width = w
  card.root:SetWidth(w)
  card.time:SetWidth(w - 20)
  for i = 1, CARD_MAX_ROWS do
    card.rows[i].name:SetWidth(w - 102)
  end
end

local function measure_row(row)
  local name_text, val_text = row.name:GetText(), row.val:GetText()
  if row.name_text ~= name_text then
    row.name_text = name_text
    row.name:SetWidth(CARD_MAX_W)
    row.name_w = row.name:GetTextWidth()
  end
  if row.val_text ~= val_text then
    row.val_text = val_text
    row.val:SetWidth(CARD_MAX_W)
    row.val_w = row.val:GetTextWidth()
  end
end

function M.fit_rows(card, n, base_w)
  local w = base_w
  for i = 1, n do
    local row = card.rows[i]
    measure_row(row)
    local vw = row.val_w + 6
    if vw < 40 then vw = 40 end
    local need = 30 + row.name_w + 12 + vw + 8
    if need > w then w = need end
  end
  if w > CARD_MAX_W then w = CARD_MAX_W end
  M.size(w)
  for i = 1, n do
    local row = card.rows[i]
    local vw = row.val_w + 6
    if vw < 40 then vw = 40 end
    local max_v = w - 30 - 8 - 40
    if vw > max_v then vw = max_v end
    row.val:SetWidth(vw)
    row.name:SetWidth(w - 30 - 8 - vw - 6)
  end
end

local function card_layout(card, iconMode)
  if card.iconMode == iconMode then return end
  card.iconMode = iconMode
  local s = iconMode and 28 or 14
  local textX = iconMode and 46 or 28
  card.swatch:SetDimensions(s, s)
  card.swatch:ClearAnchors()
  card.swatch:SetAnchor(TOPLEFT, card.root, TOPLEFT, iconMode and 10 or 12, iconMode and 6 or 7)
  card.name:ClearAnchors()
  card.name:SetAnchor(TOPLEFT, card.root, TOPLEFT, textX, 6)
  card.name:SetDimensions(CARD_W - textX - 8, 16)
  card.stat:ClearAnchors()
  card.stat:SetAnchor(TOPLEFT, card.root, TOPLEFT, iconMode and textX or 12, 24)
  card.stat:SetDimensions(CARD_W - (iconMode and textX or 12) - 8, 14)
end

function M.swatch_solid(card, r, g, b)
  card_layout(card, false)
  card.swatch:SetTexture(FILL_TEXTURE)
  card.swatch:SetTextureCoords(0, 1, 0, 0.05)
  card.swatch:SetColor(r, g, b, 1.0)
end

function M.swatch_icon(card, path)
  card_layout(card, true)
  card.swatch:SetTexture(path)
  card.swatch:SetTextureCoords(0, 1, 0, 1)
  card.swatch:SetColor(1, 1, 1, 1)
end

function M.show_moment(swatch_c, name_text, stat_text, elapsed_ms, mx, my, icon_path)
  local card = the_card
  if not card then return end
  M.size(CARD_W)
  if icon_path then
    M.swatch_icon(card, icon_path)
  else
    M.swatch_solid(card, swatch_c.r, swatch_c.g, swatch_c.b)
  end
  card.name:SetColor(C_CARD_NAME.r, C_CARD_NAME.g, C_CARD_NAME.b, 1.0)
  card.name:SetText(name_text)
  card.stat:SetText(stat_text)
  card.time:SetText("t  " .. fmt_secs(elapsed_ms or 0))
  M.clear_rows(card)
  card.root:SetHeight(CARD_H)
  M.place(mx, my)
end

function M.show_rows(color, name_text, stat_text, time_text, rows, n_rows, desc_text, mx, my, icon_path)
  local card = the_card
  if not card then return end
  if icon_path then
    M.swatch_icon(card, icon_path)
  else
    M.swatch_solid(card, color.r, color.g, color.b)
  end
  card.name:SetColor(color.r, color.g, color.b, 1.0)
  card.name:SetText(name_text)
  card.stat:SetText(stat_text)
  card.time:SetText(time_text)
  M.clear_rows(card)
  local n = (n_rows < CARD_MAX_ROWS) and n_rows or CARD_MAX_ROWS
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
  end
  M.fit_rows(card, n, CARD_W)
  local h = CARD_ROWS_Y0 + n * CARD_ROW_H + 4
  if desc_text and desc_text ~= "" then
    local desc = card.desc
    desc:ClearAnchors()
    desc:SetAnchor(TOPLEFT, card.root, TOPLEFT, 12, h + 2)
    desc:SetWidth(card.width - 20)
    desc:SetHeight(400)
    desc:SetText(desc_text)
    desc:SetHidden(false)
    local dh = desc_height(desc)
    desc:SetHeight(dh)
    h = h + dh + 10
  end
  card.root:SetHeight(h)
  M.place(mx, my)
end
function M.fader() return card_fader end
function M.card() return the_card end
