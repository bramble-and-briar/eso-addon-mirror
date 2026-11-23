Verdant = Verdant or {}
local Verdant = Verdant
Verdant.Logo = {}
local M = Verdant.Logo

local api = Verdant.zenimax.api
local zc  = Verdant.zenimax.constants
local GetUIMousePosition = api.GetUIMousePosition
local math_abs           = math.abs
local TOPLEFT = zc.TOPLEFT
local CENTER  = zc.CENTER
local GuiRoot = zc.GuiRoot

-- Base-game animation globals (captured by value, like the zenimax wrappers).
local ANIMATION_MANAGER          = ANIMATION_MANAGER
local ANIMATION_ALPHA            = ANIMATION_ALPHA
local ANIMATION_PLAYBACK_PING_PONG = ANIMATION_PLAYBACK_PING_PONG
local LOOP_INDEFINITELY          = LOOP_INDEFINITELY
local TEX_BLEND_MODE_ADD         = TEX_BLEND_MODE_ADD

local log = Verdant.Log.for_module("logo")

local IDLE_ALPHA     = 0.40
local HOVER_ALPHA    = 1.00
local HOVER_SCALE    = 1.06
local DRAG_THRESHOLD = 5
local GLOW_MIN       = 0.45
local GLOW_MAX       = 1.00
local GLOW_PERIOD_MS = 650
local HEART_MIN      = 0.40
local HEART_MAX      = 0.90
local HEART_PERIOD_MS = 1100

-- ── state ───────────────────────────────────────────────────────────────────
local controls = {}
local enabled  = true
local allowed  = false
local recording = false
local hovering  = false
local down_x, down_y = 0, 0

local function heartbeat(on)
  local tl = controls.heart_timeline
  if not tl then return end
  if on then
    if not controls.heart_on then
      controls.heart_on = true
      tl:PlayFromStart()
    end
  elseif controls.heart_on then
    controls.heart_on = false
    tl:Stop()
    controls.icon:SetAlpha(IDLE_ALPHA)
  end
end

local function reset_hover()
  if controls.glow_timeline then controls.glow_timeline:Stop() end
  if controls.glow then controls.glow:SetHidden(true) end
  controls.icon:SetScale(1.0)
  controls.icon:SetAlpha(IDLE_ALPHA)
  heartbeat(recording and enabled and allowed and not hovering)
end

local function refresh()
  local show = enabled and allowed
  controls.window:SetHidden(not show)
  if not show then reset_hover() end
end

function M.sync(is_allowed)
  allowed = is_allowed
  if enabled and allowed then controls.icon:SetAlpha(IDLE_ALPHA) end
  refresh()
  heartbeat(recording and enabled and allowed and not hovering)
end

function M.set_recording(on)
  recording = on and true or false
  if not controls.icon then return end
  heartbeat(recording and enabled and allowed and not hovering)
end

function M.is_beating() return controls.heart_on == true end

function M.is_enabled() return enabled end

function M.set_enabled(e)
  enabled = e
  local sv = Verdant.SavedVars
  if sv then sv.logo = sv.logo or {}; sv.logo.enabled = e end
  log:info("enabled ->", e)
  refresh()
end

-- ── mouse ────────────────────────────────────────────────────────────────────
function M.on_enter()
  hovering = true
  heartbeat(false)
  controls.icon:SetAlpha(HOVER_ALPHA)
  controls.icon:SetScale(HOVER_SCALE)
  controls.glow:SetHidden(false)
  controls.glow_timeline:PlayFromStart()
end

function M.on_exit()
  hovering = false
  controls.icon:SetAlpha(IDLE_ALPHA)
  controls.icon:SetScale(1.0)
  controls.glow_timeline:Stop()
  controls.glow:SetHidden(true)
  heartbeat(recording and enabled and allowed)
end

function M.on_mouse_down()
  down_x, down_y = GetUIMousePosition()
end

function M.on_mouse_up(up_inside)
  if not up_inside then return end
  local x, y = GetUIMousePosition()
  if (math_abs(x - down_x) + math_abs(y - down_y)) > DRAG_THRESHOLD then
    return
  end
  Verdant.Graph.toggle()
end

function M.on_move_stop()
  local sv = Verdant.SavedVars
  if not sv or not controls.window then return end
  sv.logo = sv.logo or {}
  sv.logo.x = controls.window:GetLeft()
  sv.logo.y = controls.window:GetTop()
end

function M.init()
  controls.window = VerdantLogo
  controls.icon   = VerdantLogoIcon
  controls.glow   = VerdantLogoGlow
  controls.glow:SetBlendMode(TEX_BLEND_MODE_ADD)

  local tl = ANIMATION_MANAGER:CreateTimeline()
  local a  = tl:InsertAnimation(ANIMATION_ALPHA, controls.glow)
  a:SetAlphaValues(GLOW_MIN, GLOW_MAX)
  a:SetDuration(GLOW_PERIOD_MS)
  tl:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
  controls.glow_timeline = tl

  local ht = ANIMATION_MANAGER:CreateTimeline()
  local ha = ht:InsertAnimation(ANIMATION_ALPHA, controls.icon)
  ha:SetAlphaValues(HEART_MIN, HEART_MAX)
  ha:SetDuration(HEART_PERIOD_MS)
  ht:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
  controls.heart_timeline = ht

  local sv = Verdant.SavedVars
  sv.logo = sv.logo or {}
  if sv.logo.enabled == nil then sv.logo.enabled = true end
  enabled = sv.logo.enabled

  controls.window:ClearAnchors()
  if sv.logo.x and sv.logo.y then
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.logo.x, sv.logo.y)
  else
    controls.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  end

  controls.icon:SetAlpha(IDLE_ALPHA)
  controls.window:SetHidden(true)

  log:info("init: enabled=", enabled)
end
