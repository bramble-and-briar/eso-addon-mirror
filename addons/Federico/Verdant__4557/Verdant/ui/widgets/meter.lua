Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Meter = {}
local M = Verdant.Meter

local zui  = Verdant.zenimax.ui
local zc   = Verdant.zenimax.constants
local Skin = Verdant.Skin

local BAR_Y, GROOVE_H, FILL_H, INSET = 16, 10, 6, 2
local TITLE_SHARE = 0.55

local function label(name, parent, align, role)
  local l = zui.WINDOW_MANAGER:CreateControl(name, parent, zc.CT_LABEL)
  l:SetFont("ZoFontGameSmall")
  l:SetHorizontalAlignment(align)
  l:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  Skin.label(l, role)
  return l
end

function M.new(name, parent, x, y, w)
  local WM = zui.WINDOW_MANAGER
  local title = label(name .. "Title", parent, zc.TEXT_ALIGN_LEFT, "dim")
  title:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x, y)
  title:SetDimensions(w * TITLE_SHARE, 14)
  local value = label(name .. "Value", parent, zc.TEXT_ALIGN_RIGHT, "text")
  value:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x + w * TITLE_SHARE, y)
  value:SetDimensions(w * (1 - TITLE_SHARE), 14)
  local groove = WM:CreateControl(name .. "Groove", parent, zc.CT_TEXTURE)
  Skin.texture(groove, "slider_groove")
  groove:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x, y + BAR_Y)
  groove:SetDimensions(w, GROOVE_H)
  groove:SetDrawLevel(1)
  local fill = WM:CreateControl(name .. "Fill", parent, zc.CT_TEXTURE)
  Skin.texture(fill, "slider_fill")
  fill:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x + INSET, y + BAR_Y + INSET)
  fill:SetHeight(FILL_H)
  fill:SetDrawLevel(2)

  local self = {}
  function self.set(text, value_text, share)
    if share < 0 then share = 0 elseif share > 1 then share = 1 end
    title:SetText(text)
    value:SetText(value_text)
    fill:SetWidth((w - 2 * INSET) * share)
    fill:SetTextureCoords(0, share, 0, 1)
    fill:SetHidden(share <= 0)
  end
  return self
end
