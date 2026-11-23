Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Skin = {}
local M = Verdant.Skin

local Themes = Verdant.lib.themes
local zc     = Verdant.zenimax.constants

local END_CAP     = 9
local EDGE_W      = 128
local EDGE_H      = 16
local EDGE_SIZE   = 8
local SURFACE_PX  = 512
local TONE        = 0.76
local GAIN        = 3
local LEVEL       = TONE / GAIN
local LIT         = 1 / GAIN
local ALPHA       = 0.97
local INSET       = 2
local CHROME_TOP  = 100
local CHROME_SIDE = 14
local HOVER_LIFT  = 0.12
local FIELD_DIM   = 0.75
local PRESS_DIM   = 0.85

local pieces = {}
local slot = {}

local function remember(control, part, paint)
  local parts = slot[control]
  if not parts then
    parts = {}
    slot[control] = parts
  end
  local i = parts[part]
  if not i then
    i = #pieces + 1
    parts[part] = i
  end
  pieces[i] = paint
  paint()
end

Themes.on_change(function()
  for i = 1, #pieces do pieces[i]() end
end)

function M.count()
  return #pieces
end

local function states(b, name)
  b:SetNormalTexture(Themes.texture(name .. "_up"))
  b:SetMouseOverTexture(Themes.texture(name .. "_over"))
  b:SetPressedTexture(Themes.texture(name .. "_down"))
  local off = Themes.texture(name .. "_disabled")
  if off then b:SetDisabledTexture(off) end
  b:SetMouseOverBlendMode(zc.TEX_BLEND_MODE_ALPHA)
end

function M.button(b, lacquer, tint)
  if not b then return end
  remember(b, "button", function()
    states(b, lacquer and "lacq" or "btn")
    b:SetEndCapWidth(END_CAP)
    local c = tint or Themes.color(lacquer and "ink" or "text")
    b:SetNormalFontColor(c.r, c.g, c.b, 1)
    if tint then
      b:SetMouseOverFontColor(math.min(1, c.r + HOVER_LIFT), math.min(1, c.g + HOVER_LIFT), math.min(1, c.b + HOVER_LIFT), 1)
      b:SetPressedFontColor(c.r * PRESS_DIM, c.g * PRESS_DIM, c.b * PRESS_DIM, 1)
    elseif lacquer and Themes.color("ink") ~= Themes.color("text") then
      b:SetMouseOverFontColor(c.r, c.g, c.b, 1)
      b:SetPressedFontColor(c.r, c.g, c.b, 1)
    else
      b:SetMouseOverFontColor(1, 1, 1, 1)
      b:SetPressedFontColor(c.r, c.g, c.b, 1)
    end
  end)
end

function M.close(b)
  if not b then return end
  remember(b, "button", function() states(b, "close") end)
end

function M.icon(b, name)
  if not b then return end
  remember(b, "button", function() states(b, name) end)
end

function M.tab(band, state)
  if not band then return end
  remember(band, "tab", function() band:SetNormalTexture(Themes.texture("tab_" .. state)) end)
end

local function edge(backdrop, role)
  backdrop:SetEdgeTexture(Themes.texture(role), EDGE_W, EDGE_H, EDGE_SIZE)
  backdrop:SetEdgeColor(1, 1, 1, 1)
end

function M.frame(backdrop)
  if not backdrop then return end
  remember(backdrop, "backdrop", function() edge(backdrop, "frame_edge") end)
end

function M.field(backdrop, lit)
  remember(backdrop, "backdrop", function()
    edge(backdrop, "frame_edge")
    backdrop:SetEdgeColor(1, 1, 1, lit and 1 or FIELD_DIM)
  end)
end

function M.panel(backdrop)
  if not backdrop then return end
  remember(backdrop, "backdrop", function()
    edge(backdrop, "frame_edge")
    backdrop:SetCenterTexture(Themes.texture("background"), SURFACE_PX, zc.TEX_MODE_WRAP)
    backdrop:SetCenterColor(LEVEL, LEVEL, LEVEL, ALPHA)
    backdrop:SetInsets(INSET, INSET, -INSET, -INSET)
  end)
end

function M.viewport(backdrop)
  if not backdrop then return end
  remember(backdrop, "backdrop", function()
    edge(backdrop, "viewport_edge")
    backdrop:SetInsets(INSET, INSET, -INSET, -INSET)
  end)
end

function M.section(backdrop)
  if not backdrop then return end
  remember(backdrop, "backdrop", function()
    edge(backdrop, "panel_edge")
    backdrop:SetCenterTexture(Themes.texture("panel_center"))
    backdrop:SetCenterColor(1, 1, 1, 1)
    backdrop:SetInsets(1, 1, -1, -1)
  end)
end

function M.chrome(tex)
  if not tex then return end
  remember(tex, "strip", function()
    tex:SetTexture(Themes.texture("background"))
    tex:SetColor(LEVEL, LEVEL, LEVEL, ALPHA)
  end)
end

function M.chrome_light(tex)
  if not tex then return end
  remember(tex, "light", function()
    tex:SetVertexColors(zc.VERTEX_POINTS_TOPLEFT, LIT, LIT, LIT, ALPHA)
    tex:SetVertexColors(zc.VERTEX_POINTS_TOPRIGHT, LIT, LIT, LIT, ALPHA)
  end)
end

function M.texture(tex, role)
  if not tex then return end
  remember(tex, "texture", function() tex:SetTexture(Themes.texture(role)) end)
end

function M.glyph(b, role, size)
  if not b then return end
  remember(b, "glyph", function() b:SetText("|t" .. size .. ":" .. size .. ":" .. Themes.texture(role) .. "|t") end)
end

function M.buttons(list, lacquer)
  for i = 1, #list do M.button(list[i], lacquer) end
end

function M.label(l, name, alpha)
  if not l then return end
  remember(l, "label", function()
    local c = Themes.color(name)
    l:SetColor(c.r, c.g, c.b, alpha or 1)
  end)
end

local function slice(tex, x0, x1, y0, y1)
  tex:SetTextureCoords(x0 / SURFACE_PX, x1 / SURFACE_PX, y0 / SURFACE_PX, y1 / SURFACE_PX)
end

function M.fit_chrome(top, bottom, left, right, w, h)
  slice(top, INSET, w - INSET, INSET, CHROME_TOP)
  slice(bottom, INSET, w - INSET, h - CHROME_SIDE, h - INSET)
  slice(left, INSET, CHROME_SIDE, CHROME_TOP, h - CHROME_SIDE)
  slice(right, w - CHROME_SIDE, w - INSET, CHROME_TOP, h - CHROME_SIDE)
end
