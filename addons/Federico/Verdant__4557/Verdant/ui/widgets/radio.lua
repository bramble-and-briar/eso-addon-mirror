Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Radio = {}
local M = Verdant.Radio

local zui  = Verdant.zenimax.ui
local zc   = Verdant.zenimax.constants
local Skin = Verdant.Skin

local DOT, ROW_H, LABEL_X = 16, 20, 20
local OFF_ALPHA = 0.6

function M.paint(r)
  if r.enabled then
    Skin.texture(r.dot, r.on and "radio_on" or "radio_off")
    Skin.label(r.label, r.on and "text" or "dim")
  else
    Skin.texture(r.dot, r.on and "radio_on_disabled" or "radio_off_disabled")
    Skin.label(r.label, "dim", OFF_ALPHA)
  end
end

function M.new(name, parent, x, y, w, text, on_click)
  local WM = zui.WINDOW_MANAGER
  local r = { on = false, enabled = true }
  r.hit = WM:CreateControl(name, parent, zc.CT_CONTROL)
  r.hit:SetAnchor(zc.TOPLEFT, parent, zc.TOPLEFT, x, y)
  r.hit:SetDimensions(w, ROW_H)
  r.hit:SetMouseEnabled(true)
  r.dot = WM:CreateControl(name .. "Dot", r.hit, zc.CT_TEXTURE)
  r.dot:SetDimensions(DOT, DOT)
  r.dot:SetAnchor(zc.LEFT, r.hit, zc.LEFT, 0, 0)
  r.label = WM:CreateControl(name .. "Label", r.hit, zc.CT_LABEL)
  r.label:SetFont("ZoFontGameSmall")
  r.label:SetAnchor(zc.LEFT, r.hit, zc.LEFT, LABEL_X, 0)
  r.label:SetDimensions(w - LABEL_X, ROW_H)
  r.label:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  r.label:SetText(text)
  zui.handler(r.hit, "OnMouseUp", function(_, _, upInside)
    if upInside and r.enabled then on_click() end
  end)
  zui.handler(r.hit, "OnMouseEnter", function()
    if r.enabled and not r.on then Skin.texture(r.dot, "radio_on") end
  end)
  zui.handler(r.hit, "OnMouseExit", function() M.paint(r) end)
  M.paint(r)
  return r
end
