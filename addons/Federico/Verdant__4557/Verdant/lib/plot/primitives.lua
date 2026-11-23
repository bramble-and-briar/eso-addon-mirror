
Verdant = Verdant or {}
local Verdant = Verdant
Verdant.lib = Verdant.lib or {}
Verdant.lib.plot = Verdant.lib.plot or {}

local M = {}
Verdant.lib.plot.Primitives = M

local zc = Verdant.zenimax.constants
local TOPLEFT     = zc.TOPLEFT
local BOTTOMLEFT  = zc.BOTTOMLEFT
local BOTTOMRIGHT = zc.BOTTOMRIGHT

function M.draw_rect(ctrl, parent, x, y, w, h, color)
  ctrl:ClearAnchors()
  ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
  ctrl:SetDimensions(w, h)
  ctrl:SetHidden(false)
  if color then
    ctrl:SetColor(color[1], color[2], color[3], color[4])
  end
end

function M.draw_bar_from_bottom(ctrl, parent, x, height, width, color)
  ctrl:ClearAnchors()
  ctrl:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, x, 0)
  ctrl:SetDimensions(width, height)
  ctrl:SetHidden(false)
  if color then
    ctrl:SetColor(color[1], color[2], color[3], color[4])
  end
end

function M.draw_segment(ctrl, parent, x1, y1, x2, y2, color)
  ctrl:ClearAnchors()
  ctrl:SetAnchor(BOTTOMLEFT,  parent, BOTTOMLEFT, x1, -y1)
  ctrl:SetAnchor(BOTTOMRIGHT, parent, BOTTOMLEFT, x2, -y2)
  ctrl:SetHidden(false)
  if color then
    ctrl:SetColor(color[1], color[2], color[3], color[4])
  end
end

function M.clear(ctrl)
  ctrl:ClearAnchors()
  ctrl:SetHidden(true)
end
