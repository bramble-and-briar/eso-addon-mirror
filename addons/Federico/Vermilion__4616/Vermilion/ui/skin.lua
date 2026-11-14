Vermilion = Vermilion or {}
Vermilion.Skin = {}
local M = Vermilion.Skin

local GetString = Vermilion.zenimax.api.GetString

local BASE = "Vermilion/assets/skin/"
local END_CAP = 9
local EDGE_SIZE = 8
local SURFACE_PX = 512
local TONE = 0.76
local INSET = 2
local CHROME_TOP = 100
local CHROME_SIDE = 14
local ALPHA = 0.97
local GAIN = 3
local LEVEL = TONE / GAIN
local LIT = 1 / GAIN
local DEFAULT_BACKGROUND = "piano"
local BACKGROUNDS = {
  { key = "piano", name = VERMILION_BACKGROUND_PIANO },
  { key = "frosted", name = VERMILION_BACKGROUND_FROSTED },
  { key = "garnet", name = VERMILION_BACKGROUND_GARNET },
  { key = "goldstone", name = VERMILION_BACKGROUND_GOLDSTONE },
  { key = "crackle", name = VERMILION_BACKGROUND_CRACKLE },
  { key = "veins", name = VERMILION_BACKGROUND_VEINS },
}
local background = DEFAULT_BACKGROUND
local strips, panels = {}, {}
local lit

M.TAB_ON = BASE .. "tab_on.dds"
M.TAB_IDLE = BASE .. "tab_idle.dds"
M.TAB_OVER = BASE .. "tab_over.dds"
M.RADIO_ON = BASE .. "radio_on.dds"
M.RADIO_OFF = BASE .. "radio_off.dds"
M.CARET = BASE .. "caret.dds"
M.FRAME_EDGE = BASE .. "frame_edge.dds"
M.GOLD = { r = 0.77, g = 0.63, b = 0.36 }
M.TEXT = { r = 0.96, g = 0.91, b = 0.87 }

local PLAIN = {
  up = BASE .. "btn_up.dds", over = BASE .. "btn_over.dds",
  down = BASE .. "btn_down.dds", disabled = BASE .. "btn_disabled.dds",
}
local LACQUER = {
  up = BASE .. "lacq_up.dds", over = BASE .. "lacq_over.dds",
  down = BASE .. "lacq_down.dds", disabled = BASE .. "lacq_disabled.dds",
}
M.PLAIN, M.LACQUER = PLAIN, LACQUER
M.SUBTAB = BASE .. "subtab.dds"
M.CLOSE = { up = BASE .. "close_up.dds", over = BASE .. "close_over.dds", down = BASE .. "close_down.dds" }

function M.button(b, lacquer)
  if not b or not b.SetNormalTexture then return end
  local t = lacquer and LACQUER or PLAIN
  b:SetNormalTexture(t.up)
  b:SetMouseOverTexture(t.over)
  b:SetPressedTexture(t.down)
  b:SetDisabledTexture(t.disabled)
  if b.SetEndCapWidth then b:SetEndCapWidth(END_CAP) end
  if b.SetMouseOverBlendMode then b:SetMouseOverBlendMode(TEX_BLEND_MODE_ALPHA or 0) end
  if b.SetNormalFontColor then b:SetNormalFontColor(M.TEXT.r, M.TEXT.g, M.TEXT.b, 1) end
  if b.SetMouseOverFontColor then b:SetMouseOverFontColor(1, 1, 1, 1) end
  if b.SetPressedFontColor then b:SetPressedFontColor(M.TEXT.r, M.TEXT.g, M.TEXT.b, 1) end
end

function M.close(b)
  if not b or not b.SetNormalTexture then return end
  b:SetNormalTexture(M.CLOSE.up)
  b:SetMouseOverTexture(M.CLOSE.over)
  b:SetPressedTexture(M.CLOSE.down)
  if b.SetMouseOverBlendMode then b:SetMouseOverBlendMode(TEX_BLEND_MODE_ALPHA or 0) end
end

function M.icons(list)
  for i = 1, #list do
    local b = list[i]
    if b and b.SetMouseOverBlendMode then b:SetMouseOverBlendMode(TEX_BLEND_MODE_ALPHA or 0) end
  end
end

function M.buttons(list, lacquer)
  for i = 1, #list do M.button(list[i], lacquer) end
end

function M.background_path(key)
  return BASE .. "bg_" .. key .. ".dds"
end

function M.backgrounds()
  return BACKGROUNDS
end

function M.background()
  return background
end

function M.background_name(key)
  key = key or background
  for i = 1, #BACKGROUNDS do
    if BACKGROUNDS[i].key == key then return GetString(BACKGROUNDS[i].name) end
  end
  return key
end

function M.load_background(key)
  background = DEFAULT_BACKGROUND
  for i = 1, #BACKGROUNDS do
    if BACKGROUNDS[i].key == key then background = key end
  end
end

local function paint_strip(tex)
  tex:SetTexture(M.background_path(background))
  tex:SetColor(LEVEL, LEVEL, LEVEL, ALPHA)
end

local function paint_light()
  lit:SetVertexColors(VERTEX_POINTS_TOPLEFT, LIT, LIT, LIT, ALPHA)
  lit:SetVertexColors(VERTEX_POINTS_TOPRIGHT, LIT, LIT, LIT, ALPHA)
end

local function paint_panel(backdrop)
  if backdrop.SetCenterTexture then backdrop:SetCenterTexture(M.background_path(background), SURFACE_PX, TEX_MODE_WRAP) end
  if backdrop.SetCenterColor then backdrop:SetCenterColor(LEVEL, LEVEL, LEVEL, ALPHA) end
end

function M.set_background(key)
  M.load_background(key)
  for i = 1, #strips do paint_strip(strips[i]) end
  if lit then paint_light() end
  for i = 1, #panels do paint_panel(panels[i]) end
  if Vermilion.Graph and Vermilion.Graph.fit_chrome then Vermilion.Graph.fit_chrome() end
end

function M.frame(backdrop)
  if not backdrop or not backdrop.SetEdgeTexture then return end
  backdrop:SetEdgeTexture(M.FRAME_EDGE, 128, 16, EDGE_SIZE)
  if backdrop.SetEdgeColor then backdrop:SetEdgeColor(1, 1, 1, 1) end
end

function M.panel(backdrop)
  if not backdrop then return end
  M.frame(backdrop)
  panels[#panels + 1] = backdrop
  paint_panel(backdrop)
  if backdrop.SetInsets then backdrop:SetInsets(INSET, INSET, -INSET, -INSET) end
end

function M.viewport(backdrop)
  backdrop:SetEdgeTexture(BASE .. "viewport_edge.dds", 128, 16, EDGE_SIZE)
  backdrop:SetEdgeColor(1, 1, 1, 1)
  backdrop:SetInsets(2, 2, -2, -2)
end

function M.section(backdrop)
  if not backdrop or not backdrop.SetEdgeTexture then return end
  backdrop:SetEdgeTexture(BASE .. "panel_edge.dds", 128, 16, EDGE_SIZE)
  backdrop:SetEdgeColor(1, 1, 1, 1)
  backdrop:SetCenterTexture(BASE .. "panel_center.dds")
  backdrop:SetCenterColor(1, 1, 1, 1)
  if backdrop.SetInsets then backdrop:SetInsets(1, 1, -1, -1) end
end

function M.chrome(tex)
  if not tex then return end
  strips[#strips + 1] = tex
  paint_strip(tex)
end

function M.chrome_light(tex)
  lit = tex
  paint_light()
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
