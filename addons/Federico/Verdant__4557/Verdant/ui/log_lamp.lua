Verdant = Verdant or {}
local Verdant = Verdant
Verdant.LogLamp = {}
local M = Verdant.LogLamp

local api    = Verdant.zenimax.api
local zc     = Verdant.zenimax.constants
local zev    = Verdant.zenimax.events
local Sound  = Verdant.Sound
local Themes = Verdant.lib.themes
local GetUIMousePosition = api.GetUIMousePosition
local math_abs = math.abs
local TOPLEFT, CENTER, GuiRoot = zc.TOPLEFT, zc.CENTER, zc.GuiRoot

local POLL_NAME      = "VerdantLogLampPoll"
local POLL_MS        = 1000
local DRAG_THRESHOLD = 5
local REST_ALPHA     = 0.6

local controls = {}
local enabled, in_hud, polling, hovering = false, true, false, false
local lit = nil
local down_x, down_y = 0, 0
local halo = Themes.tint("crosshair", 1)

local function available()
  return api.SetEncounterLogEnabled ~= nil and api.IsEncounterLogEnabled ~= nil
end

local function paint()
  controls.icon:SetTexture(Themes.texture(lit and "lamp_on" or "lamp_off"))
  controls.glow:SetColor(halo.r, halo.g, halo.b, 1)
end

local function show_state()
  local on = api.IsEncounterLogEnabled() == true
  if on ~= lit then
    lit = on
    paint()
    controls.glow:SetHidden(not on)
  end
  controls.icon:SetAlpha((on or hovering) and 1 or REST_ALPHA)
end

local function refresh()
  local show = enabled and in_hud and available()
  controls.window:SetHidden(not show)
  if show then
    show_state()
    if not polling then
      polling = true
      zev.register_update(POLL_NAME, POLL_MS, show_state)
    end
  elseif polling then
    polling = false
    zev.unregister_update(POLL_NAME)
  end
end

function M.sync(hud)
  in_hud = hud
  refresh()
end

function M.is_enabled() return enabled end
function M.is_lit() return lit == true end

function M.set_enabled(on)
  enabled = on and true or false
  Verdant.Settings.save_lamp(enabled)
  refresh()
end

function M.toggle()
  if not available() then return false end
  local on = api.IsEncounterLogEnabled() ~= true
  api.SetEncounterLogEnabled(on)
  Sound.play(on and "on" or "off")
  show_state()
  return true
end

function M.on_enter()
  hovering = true
  controls.icon:SetAlpha(1)
end

function M.on_exit()
  hovering = false
  controls.icon:SetAlpha(lit and 1 or REST_ALPHA)
end

function M.on_mouse_down()
  down_x, down_y = GetUIMousePosition()
end

function M.on_mouse_up(up_inside)
  if not up_inside then return end
  local x, y = GetUIMousePosition()
  if (math_abs(x - down_x) + math_abs(y - down_y)) > DRAG_THRESHOLD then return end
  M.toggle()
end

function M.on_move_stop()
  Verdant.Settings.save_lamp(enabled, controls.window:GetLeft(), controls.window:GetTop())
end

function M.restore()
  local on, x, y = Verdant.Settings.lamp_prefs()
  enabled = on
  controls.window:ClearAnchors()
  if x and y then
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
  else
    controls.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 72)
  end
  refresh()
end

function M.init()
  controls.window = VerdantLogLamp
  controls.icon   = VerdantLogLampIcon
  controls.glow   = VerdantLogLampGlow
  controls.glow:SetBlendMode(zc.TEX_BLEND_MODE_ADD)
  paint()
  Themes.on_change(paint)
  M.restore()
  Verdant.Visibility.watch_hud(M.sync)
end
