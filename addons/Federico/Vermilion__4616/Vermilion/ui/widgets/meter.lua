Vermilion = Vermilion or {}
Vermilion.Meter = {}
local M = Vermilion.Meter

local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants

local BASE = "Vermilion/assets/skin/"
local BAR_Y, GROOVE_H, FILL_H, INSET = 16, 10, 6, 2
M.HEIGHT = 30

local function label(name, parent, align)
  local l = zui.WINDOW_MANAGER:CreateControl(name, parent, zc.CT_LABEL)
  l:SetFont("ZoFontGameSmall")
  l:SetHorizontalAlignment(align)
  l:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  return l
end

function M.new(name, parent, x, y, w)
  local WM = zui.WINDOW_MANAGER
  local title = label(name .. "Title", parent, zc.TEXT_ALIGN_LEFT)
  title:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x, y)
  title:SetDimensions(w * 0.55, 14)
  title:SetColor(0.75, 0.75, 0.75, 1)
  local value = label(name .. "Value", parent, zc.TEXT_ALIGN_RIGHT)
  value:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x + w * 0.55, y)
  value:SetDimensions(w * 0.45, 14)
  value:SetColor(0.95, 0.80, 0.20, 1)
  local groove = WM:CreateControl(name .. "Groove", parent, zc.CT_TEXTURE)
  groove:SetTexture(BASE .. "slider_groove.dds")
  groove:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x, y + BAR_Y)
  groove:SetDimensions(w, GROOVE_H)
  groove:SetDrawLevel(1)
  local fill = WM:CreateControl(name .. "Fill", parent, zc.CT_TEXTURE)
  fill:SetTexture(BASE .. "slider_fill.dds")
  fill:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x + INSET, y + BAR_Y + INSET)
  fill:SetHeight(FILL_H)
  fill:SetDrawLevel(2)

  local self = {}
  function self.set(text, value_text, pct)
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    title:SetText(text)
    value:SetText(value_text)
    fill:SetWidth((w - 2 * INSET) * pct)
    fill:SetTextureCoords(0, pct, 0, 1)
    fill:SetHidden(pct <= 0)
  end
  return self
end
