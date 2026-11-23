Verdant = Verdant or {}
local Verdant = Verdant

Verdant.LightMode = { active = false, hover = false }
local light = Verdant.LightMode

local zev = Verdant.zenimax.events
local zc  = Verdant.zenimax.constants
local GetUIMousePosition = Verdant.zenimax.api.GetUIMousePosition
local WINDOW_MANAGER     = Verdant.zenimax.ui.WINDOW_MANAGER
local FILL_TEXTURE       = Verdant.ChartPools.FILL_TEXTURE

local CORNER = { LEN = 16, W = 2 }
local C_CORNER = { r = 0.45, g = 1.00, b = 0.62, a = 0.95 }
local CORNERS = {
  { "TL", zc.TOPLEFT },
  { "TR", zc.TOPRIGHT },
  { "BL", zc.BOTTOMLEFT },
  { "BR", zc.BOTTOMRIGHT },
}

local controls

function light.bind(t)
  controls = t.controls
  light.alpha_pct, light.enabled = t.alpha_pct, t.enabled
end

function light.chrome(hidden)
  VerdantGraphWindowBg:SetHidden(hidden)
  VerdantGraphWindowChromeTop:SetHidden(hidden)
  VerdantGraphWindowChromeBottom:SetHidden(hidden)
  VerdantGraphWindowChromeLeft:SetHidden(hidden)
  VerdantGraphWindowChromeRight:SetHidden(hidden)
  VerdantGraphWindowBrandLogo:SetHidden(hidden)
  VerdantGraphWindowSettingsBtn:SetHidden(hidden)
  VerdantGraphWindowAboutBtn:SetHidden(hidden)
  VerdantGraphWindowCloseBtn:SetHidden(hidden)
  controls.btn_record:SetHidden(hidden)
  controls.btn_flush:SetHidden(hidden)
  controls.btn_lib:SetHidden(hidden)
  controls.btn_save:SetHidden(hidden)
end

function light.minimal(hidden)
  controls.btn_stop:SetHidden(hidden)
  controls.btn_prev_sess:SetHidden(hidden)
  controls.btn_next_sess:SetHidden(hidden)
  controls.btn_say:SetHidden(hidden)
  controls.btn_export:SetHidden(hidden)
  if controls.tabs then controls.tabs.strip:SetHidden(hidden) end
  controls.status:SetHidden(hidden)
end

local function strip(name, point, w, h)
  local win = controls.window
  local t = WINDOW_MANAGER:CreateControl(name, win, zc.CT_TEXTURE)
  t:SetTexture(FILL_TEXTURE)
  t:SetTextureCoords(0, 1, 0, 0.05)
  t:SetDimensions(w, h)
  t:SetAnchor(point, win, point, 0, 0)
  t:SetColor(C_CORNER.r, C_CORNER.g, C_CORNER.b, C_CORNER.a)
  t:SetDrawLevel(9)
  return t
end

function light.corners(hidden)
  local list = light.corner_ctls
  if not list then
    if hidden then return end
    list = {}
    for i = 1, #CORNERS do
      local key, point = CORNERS[i][1], CORNERS[i][2]
      list[#list + 1] = strip("VerdantGraphWindowCorner" .. key .. "H", point, CORNER.LEN, CORNER.W)
      list[#list + 1] = strip("VerdantGraphWindowCorner" .. key .. "V", point, CORNER.W, CORNER.LEN)
    end
    light.corner_ctls = list
  end
  for i = 1, #list do list[i]:SetHidden(hidden) end
end

function light.apply_hover(hover)
  light.hover = hover
  if hover then
    controls.window:SetAlpha(1)
    light.minimal(false)
    light.corners(false)
  else
    controls.window:SetAlpha(light.alpha_pct() / 100)
    light.minimal(true)
    light.corners(true)
  end
end

function light.poll()
  local mx, my = GetUIMousePosition()
  local w = controls.window
  local inside = mx >= w:GetLeft() and mx <= w:GetRight()
             and my >= w:GetTop() and my <= w:GetBottom()
  if inside ~= light.hover then light.apply_hover(inside) end
end

function light.enter()
  if light.active then return end
  light.active = true
  Verdant.Diagnostics.bump("graph.light.enter")
  light.chrome(true)
  light.apply_hover(false)
  zev.register_update("VerdantLightPoll", 150, light.poll)
end

function light.exit()
  if not light.active then return end
  light.active = false
  zev.unregister_update("VerdantLightPoll")
  controls.window:SetAlpha(1)
  light.chrome(false)
  light.minimal(false)
  light.corners(true)
end
