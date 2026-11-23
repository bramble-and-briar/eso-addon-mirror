Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ThemeGallery = {}
local M = Verdant.ThemeGallery

local Themes = Verdant.lib.themes

M.THEMES = Themes.list()
M.ROLES  = Themes.roles()
M.path   = Themes.path

M.toggle  = function() end
M.apply   = function() end
M.is_open = function() return false end
M.current = function() return nil end
M.skinned = function() return {} end

if not Verdant.Constants.DEBUG then return end

local zc    = Verdant.zenimax.constants
local zui   = Verdant.zenimax.ui
local Sound = Verdant.Sound
local WM    = zui.WINDOW_MANAGER
local TOPLEFT, CENTER = zc.TOPLEFT, zc.CENTER
local CT_LABEL, CT_TEXTURE, CT_BACKDROP, CT_BUTTON = zc.CT_LABEL, zc.CT_TEXTURE, zc.CT_BACKDROP, zc.CT_BUTTON
local CT_CONTROL = zc.CT_CONTROL
local GuiRoot = zc.GuiRoot
local TEX_MODE_WRAP = zc.TEX_MODE_WRAP
local TEX_BLEND_MODE_ALPHA = zc.TEX_BLEND_MODE_ALPHA

local W, H = 720, 580
local BODY_TOP, PICK_GAP = 40, 6
local SURFACE_PX, TONE, GAIN, ALPHA = 512, 0.76, 3, 0.97
local LEVEL = TONE / GAIN
local END_CAP, EDGE_SIZE = 9, 8
local TEXT = { 0.96, 0.93, 0.88 }
local DIM  = { 0.62, 0.64, 0.60 }

local win, theme_label
local theme = M.THEMES[1]
local skinned = {}
local count = 0

local function name()
  count = count + 1
  return "VerdantThemeGalleryPiece" .. count
end

local function skin(control, method, role, a, b, c)
  skinned[#skinned + 1] = { control = control, method = method, role = role, a = a, b = b, c = c }
end

local function label(parent, text, x, y, color, font)
  local l = WM:CreateControl(name(), parent, CT_LABEL)
  l:SetFont(font or "ZoFontGameSmall")
  l:SetText(text)
  l:SetColor(color[1], color[2], color[3], 1)
  l:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
  return l
end

local function tex(parent, role, x, y, w, h)
  local t = WM:CreateControl(name(), parent, CT_TEXTURE)
  t:SetDimensions(w, h)
  t:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
  skin(t, "SetTexture", role)
  return t
end

local function button(parent, kind, states, x, y, w, h, text, on_click)
  local b = WM:CreateControl(name(), parent, CT_BUTTON)
  b:SetDimensions(w, h)
  b:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
  if text then b:SetEndCapWidth(END_CAP) end
  if b.SetMouseOverBlendMode then b:SetMouseOverBlendMode(TEX_BLEND_MODE_ALPHA) end
  skin(b, "SetNormalTexture", kind .. "_up")
  skin(b, "SetMouseOverTexture", kind .. "_over")
  skin(b, "SetPressedTexture", kind .. "_down")
  if states == 4 then skin(b, "SetDisabledTexture", kind .. "_disabled") end
  zui.handler(b, "OnClicked", on_click or function() Sound.play("click") end)
  if text then
    local l = WM:CreateControl(name(), b, CT_LABEL)
    l:SetFont("ZoFontGame")
    l:SetText(text)
    l:SetColor(TEXT[1], TEXT[2], TEXT[3], 1)
    l:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.caption = l
  end
  return b
end

local function build()
  win = WM:CreateTopLevelWindow("VerdantThemeGallery")
  win:SetDimensions(W, H)
  win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  win:SetMovable(true)
  win:SetMouseEnabled(true)
  win:SetClampedToScreen(true)

  local bg = WM:CreateControl("VerdantThemeGalleryBg", win, CT_BACKDROP)
  bg:SetAnchorFill(win)
  bg:SetCenterColor(LEVEL, LEVEL, LEVEL, ALPHA)
  bg:SetEdgeColor(1, 1, 1, 1)
  bg:SetInsets(2, 2, -2, -2)
  skin(bg, "SetCenterTexture", "background", SURFACE_PX, TEX_MODE_WRAP)
  skin(bg, "SetEdgeTexture", "frame_edge", 128, 16, EDGE_SIZE)

  label(win, "Verdant themes", 18, 14, TEXT, "ZoFontWinH4")
  theme_label = label(win, theme, 170, 18, DIM, "ZoFontGame")
  local step = (W - 36 + PICK_GAP) / #M.THEMES
  for i = 1, #M.THEMES do
    local key = M.THEMES[i]
    button(win, "lacq", 4, 18 + (i - 1) * step, 46, step - PICK_GAP, 28, key, function()
      Sound.play("click")
      M.apply(key)
    end)
  end

  local body = WM:CreateControl(name(), win, CT_CONTROL)
  body:SetDimensions(W, H - BODY_TOP)
  body:SetAnchor(TOPLEFT, win, TOPLEFT, 0, BODY_TOP)

  label(body, "Buttons, plain and theme", 18, 58, DIM)
  local words = { "Record", "Stop", "Save", "Disabled" }
  for i = 1, 4 do
    local b = button(body, "btn", 4, 18 + (i - 1) * 104, 78, 96, 28, words[i])
    local c = button(body, "lacq", 4, 18 + (i - 1) * 104, 112, 96, 28, words[i])
    if i == 4 then
      b:SetEnabled(false)
      c:SetEnabled(false)
    end
  end

  label(body, "Tabs", 18, 152, DIM)
  local tabs = { { "tab_on", "SKILL" }, { "tab_idle", "EMS" }, { "tab_over", "CRIT" }, { "subtab", "Magicka" } }
  for i = 1, #tabs do
    local t = tex(body, tabs[i][1], 18 + (i - 1) * 110, 172, 104, 30)
    local l = label(body, tabs[i][2], 0, 0, i == 1 and TEXT or DIM, "ZoFontGame")
    l:ClearAnchors()
    l:SetAnchor(CENTER, t, CENTER, 0, 1)
  end

  label(body, "Icons with their states, hover and press them", 18, 216, DIM)
  local icons = { { "export", 4 }, { "save", 4 }, { "say", 4 }, { "lib", 3 }, { "bucket", 3 }, { "close", 3 },
                  { "arrow_left", 3 }, { "arrow_right", 3 }, { "arrow_up", 3 }, { "arrow_down", 3 } }
  for i = 1, #icons do
    button(body, icons[i][1], icons[i][2], 18 + (i - 1) * 44, 236, 36, 36)
  end
  local export_off = button(body, "export", 4, 18 + #icons * 44, 236, 36, 36)
  export_off:SetEnabled(false)
  local save_off = button(body, "save", 4, 18 + (#icons + 1) * 44, 236, 36, 36)
  save_off:SetEnabled(false)
  local say_off = button(body, "say", 4, 18 + (#icons + 2) * 44, 236, 36, 36)
  say_off:SetEnabled(false)

  local still = { "lock_closed", "lock_open", "lamp_on", "lamp_off", "help", "delete", "caret",
                  "radio_on", "radio_off", "radio_on_disabled", "radio_off_disabled" }
  for i = 1, #still do
    tex(body, still[i], 18 + (i - 1) * 44, 284, 32, 32)
  end

  label(body, "Slider and scroll bar", 18, 330, DIM)
  tex(body, "slider_groove", 18, 352, 256, 16)
  local fill = tex(body, "slider_fill", 18, 352, 160, 16)
  fill:SetTextureCoords(0, 160 / 256, 0, 1)
  tex(body, "slider_thumb", 18 + 160 - 16, 344, 32, 32)
  tex(body, "scroll_track", W - 40, 236, 16, 128)
  local thumb = tex(body, "scroll_thumb", W - 40, 250, 16, 56)
  thumb:SetTextureCoords(0, 1, 0, 56 / 128)

  label(body, "Panel and chart frame", 18, 386, DIM)
  local panel = WM:CreateControl(name(), body, CT_BACKDROP)
  panel:SetDimensions(330, 100)
  panel:SetAnchor(TOPLEFT, body, TOPLEFT, 18, 406)
  panel:SetEdgeColor(1, 1, 1, 1)
  panel:SetCenterColor(1, 1, 1, 1)
  panel:SetInsets(1, 1, -1, -1)
  skin(panel, "SetEdgeTexture", "panel_edge", 128, 16, EDGE_SIZE)
  skin(panel, "SetCenterTexture", "panel_center")
  label(panel, "A section panel", 12, 10, TEXT, "ZoFontGame")

  local chart = WM:CreateControl(name(), body, CT_BACKDROP)
  chart:SetDimensions(330, 100)
  chart:SetAnchor(TOPLEFT, body, TOPLEFT, 366, 406)
  chart:SetEdgeColor(1, 1, 1, 1)
  chart:SetCenterColor(0.03, 0.04, 0.035, 0.92)
  chart:SetInsets(2, 2, -2, -2)
  skin(chart, "SetEdgeTexture", "viewport_edge", 128, 16, EDGE_SIZE)
  label(chart, "The chart area", 12, 10, DIM, "ZoFontGame")

  label(body, "Sample only: nothing here is wired to the add-on.", 18, H - BODY_TOP - 26, DIM)
end

function M.apply(key)
  theme = key
  for i = 1, #skinned do
    local s = skinned[i]
    local path = M.path(key, s.role)
    if s.c ~= nil then
      s.control[s.method](s.control, path, s.a, s.b, s.c)
    elseif s.b ~= nil then
      s.control[s.method](s.control, path, s.a, s.b)
    else
      s.control[s.method](s.control, path)
    end
  end
  if theme_label then theme_label:SetText(key) end
end

function M.toggle()
  if not win then
    build()
    M.apply(theme)
  else
    win:SetHidden(not win:IsHidden())
  end
  Sound.play(win:IsHidden() and "close" or "open")
end

function M.is_open() return win ~= nil and not win:IsHidden() end
function M.current() return theme end
function M.skinned() return skinned end
