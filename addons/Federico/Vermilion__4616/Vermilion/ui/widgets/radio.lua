Vermilion = Vermilion or {}
Vermilion.Radio = {}
local M = Vermilion.Radio

local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants

local T = { on = Vermilion.Skin.RADIO_ON, off = Vermilion.Skin.RADIO_OFF, hot = Vermilion.Skin.RADIO_ON,
            on_dis = "Vermilion/assets/skin/radio_on_disabled.dds", off_dis = "Vermilion/assets/skin/radio_off_disabled.dds" }

function M.paint(r)
  if r.enabled then
    r.dot:SetTexture(r.on and T.on or T.off)
    r.label:SetColor(r.on and 0.95 or 0.72, r.on and 0.95 or 0.72, r.on and 0.95 or 0.72, 1)
  else
    r.dot:SetTexture(r.on and T.on_dis or T.off_dis)
    r.label:SetColor(0.45, 0.45, 0.45, 1)
  end
end

function M.new(parent, x, y, w, text, on_click)
  local WM = zui.WINDOW_MANAGER
  local r = {}
  r.hit = WM:CreateControl(nil, parent, zc.CT_CONTROL)
  r.hit:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x, y)
  r.hit:SetDimensions(w, 20)
  r.hit:SetMouseEnabled(true)
  r.dot = WM:CreateControl(nil, r.hit, zc.CT_TEXTURE)
  r.dot:SetDimensions(16, 16)
  r.dot:SetAnchor(zc.LEFT, r.hit, zc.LEFT, 0, 0)
  r.dot:SetTexture(T.off)
  r.label = WM:CreateControl(nil, r.hit, zc.CT_LABEL)
  r.label:SetFont("ZoFontGameSmall")
  r.label:SetAnchor(zc.LEFT, r.hit, zc.LEFT, 20, 0)
  r.label:SetDimensions(w - 20, 20)
  r.label:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  r.label:SetText(text)
  r.on, r.enabled = false, true
  r.hit:SetHandler("OnMouseUp", function(_, _, upInside)
    if upInside and r.enabled then on_click() end
  end)
  r.hit:SetHandler("OnMouseEnter", function()
    if r.enabled and not r.on then r.dot:SetTexture(T.hot) end
  end)
  r.hit:SetHandler("OnMouseExit", function() M.paint(r) end)
  return r
end
