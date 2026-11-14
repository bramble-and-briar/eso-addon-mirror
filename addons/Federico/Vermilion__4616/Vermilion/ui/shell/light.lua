Vermilion = Vermilion or {}
Vermilion.LightMode = { active = false, hover = false }
local light = Vermilion.LightMode

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local WINDOW_MANAGER     = zui.WINDOW_MANAGER
local CT_TEXTURE         = zc.CT_TEXTURE
local GetUIMousePosition = api.GetUIMousePosition
local FILL_TEXTURE       = Vermilion.ChartPools.FILL_TEXTURE

local controls, VIS

function light.bind(t) controls, VIS = t.controls, t.VIS end
light.alpha_pct, light.enabled = Vermilion.Settings.light_alpha_pct, Vermilion.Settings.light_mode

function light.chrome(hidden)
  VermilionGraphWindowBg:SetHidden(hidden)
  VermilionGraphWindowChromeTop:SetHidden(hidden)
  VermilionGraphWindowChromeBottom:SetHidden(hidden)
  VermilionGraphWindowOrnamentTop:SetHidden(hidden)
  VermilionGraphWindowChromeLeft:SetHidden(hidden)
  VermilionGraphWindowChromeRight:SetHidden(hidden)
  VermilionGraphWindowBrandLogo:SetHidden(hidden)
  VermilionGraphWindowSettingsBtn:SetHidden(hidden)
  VermilionGraphWindowAboutBtn:SetHidden(hidden)
  VermilionGraphWindowCloseBtn:SetHidden(hidden)
  controls.btn_record:SetHidden(hidden)
  controls.btn_flush:SetHidden(hidden)
  controls.btn_lib:SetHidden(hidden)
  controls.btn_prev_sess:SetHidden(hidden)
  controls.btn_next_sess:SetHidden(hidden)
  controls.btn_save:SetHidden(hidden)
  controls.btn_export:SetHidden(hidden)
  controls.btn_say:SetHidden(hidden)
end

function light.minimal(hidden)
  controls.btn_stop:SetHidden(hidden)
  if controls.tabs then controls.tabs.strip:SetHidden(hidden) end
  controls.status:SetHidden(hidden)
end


function light.corners(hidden)
  local list = light.corner_ctls
  if not list then
    if hidden then return end
    list = {}
    local WM = WINDOW_MANAGER
    local win = controls.window
    for i = 1, #VIS.corners do
      local spec = VIS.corners[i]
      local point = spec[2]
      local h = WM:CreateControl("VermilionGraphWindowCorner" .. spec[1] .. "H", win, CT_TEXTURE)
      h:SetTexture(FILL_TEXTURE)
      h:SetTextureCoords(0, 1, 0, 0.05)
      h:SetDimensions(VIS.corner_len, VIS.corner_w)
      h:SetAnchor(point, win, point, 0, 0)
      h:SetColor(1.00, 0.45, 0.40, 0.95)
      h:SetDrawLevel(9)
      local v = WM:CreateControl("VermilionGraphWindowCorner" .. spec[1] .. "V", win, CT_TEXTURE)
      v:SetTexture(FILL_TEXTURE)
      v:SetTextureCoords(0, 1, 0, 0.05)
      v:SetDimensions(VIS.corner_w, VIS.corner_len)
      v:SetAnchor(point, win, point, 0, 0)
      v:SetColor(1.00, 0.45, 0.40, 0.95)
      v:SetDrawLevel(9)
      list[#list + 1] = h
      list[#list + 1] = v
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
  Vermilion.Diagnostics.bump("graph.light.enter")
  light.chrome(true)
  light.apply_hover(false)
  zev.register_update("VermilionLightPoll", 150, light.poll)
end

function light.exit()
  if not light.active then return end
  light.active = false
  zev.unregister_update("VermilionLightPoll")
  controls.window:SetAlpha(1)
  light.chrome(false)
  light.minimal(false)
  light.corners(true)
end
