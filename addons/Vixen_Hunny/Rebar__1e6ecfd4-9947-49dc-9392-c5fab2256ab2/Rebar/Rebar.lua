-- Rebar: core namespace, saved variables, events and slash commands.
-- Bars live in RebarBars.lua, the settings panel in RebarSettings.lua.

Rebar = {
  name = "Rebar",
  version = "7.0",
  svName = "RebarVars",
  svVersion = 2,       -- unchanged so existing profiles carry over
  configVersion = 3,   -- bump to run a migration in Rebar.MigrateSavedVars

  sv = nil,
  ui = nil,
  shield = 0,
  previewing = false,
  util = {},
}

local R = Rebar
local U = R.util

R.RESOURCES = { "health", "magicka", "stamina" }
R.RESOURCE_INFO = {
  health  = { power = COMBAT_MECHANIC_FLAGS_HEALTH,  title = "HEALTH",  label = "Health"  },
  magicka = { power = COMBAT_MECHANIC_FLAGS_MAGICKA, title = "MAGICKA", label = "Magicka" },
  stamina = { power = COMBAT_MECHANIC_FLAGS_STAMINA, title = "STAMINA", label = "Stamina" },
}

---------------------------------------------------------------------------
-- Defaults (key names kept from v6 so saved settings survive the upgrade)
---------------------------------------------------------------------------
R.default = {
  -- Position & layout
  offsetX = 0,
  offsetY = -120,
  movable = false,
  layoutPresetVersion = 0,
  barWidth = 230,
  barHeight = 18,

  healthOffsetX = 0,     healthOffsetY = -34,
  magickaOffsetX = -126, magickaOffsetY = 22,
  staminaOffsetX = 126,  staminaOffsetY = 22,

  healthScale = 1.00,  magickaScale = 1.00,  staminaScale = 1.00,
  healthAlpha = 1.00,  magickaAlpha = 1.00,  staminaAlpha = 1.00,

  healthColorR = 0.90,  healthColorG = 0.28,  healthColorB = 0.18,
  magickaColorR = 0.24, magickaColorG = 0.44, magickaColorB = 0.95,
  staminaColorR = 0.24, staminaColorG = 0.86, staminaColorB = 0.36,

  -- Appearance
  backgroundAlpha = 0.85,
  showGloss = true,
  mirrorMagicka = false,
  showThresholdMarker = true,

  -- Text
  fontSize = 13,
  fontFace = "bold",
  fontStyle = "soft-shadow-thin",
  textFormat = "cur_max",
  abbreviateNumbers = true,
  showBarLabels = false,
  showRegen = true,
  hideZeroRegen = true,

  -- Shield
  showShield = true,
  shieldColorR = 0.86, shieldColorG = 0.92, shieldColorB = 1.00,

  -- Alerts
  lowResourceThreshold = 0.30,
  lowResourcePulse = false,

  -- Visibility
  hideInMenus = true,
  fadeWhenIdle = false,
  idleAlpha = 0.35,

  -- Animation
  animateBars = true,
  animationGainSpeed = 17.00,
  animationLossSpeed = 20.00,
  damageTrail = true,
  damageTrailSpeed = 4.00,
  animateRestoreText = true,
  restoreAnimDuration = 0.55,
  restoreAnimScale = 0.18,
}

---------------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------------
function U.Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function U.Round(v)
  return math.floor(v + 0.5)
end

local function TrimDecimal(s)
  return (s:gsub("%.0([km])$", "%1"))
end

function U.FormatNumber(value, abbreviate)
  local absValue = math.abs(value)
  if abbreviate then
    if absValue >= 1000000 then return TrimDecimal(string.format("%.1fm", value / 1000000)) end
    if absValue >= 1000 then return TrimDecimal(string.format("%.1fk", value / 1000)) end
    return tostring(U.Round(value))
  end
  if ZO_CommaDelimitNumber then
    return ZO_CommaDelimitNumber(U.Round(value))
  end
  return tostring(U.Round(value))
end

function U.FormatSigned(value, abbreviate)
  local prefix = value >= 0 and "+" or "-"
  return prefix .. U.FormatNumber(math.abs(value), abbreviate)
end

-- Exponential approach: frame-rate independent smoothing toward target.
function U.Smooth(current, target, speed, dt)
  if current == nil then return target end
  if dt <= 0 then return current end
  local blend = 1 - math.exp(-U.Clamp(speed or 10, 0.01, 100) * dt)
  local value = current + (target - current) * blend
  if math.abs(target - value) < math.max(0.5, math.abs(target) * 0.0005) then
    return target
  end
  return value
end

function U.ColorHex(r, g, b)
  return string.format("%02x%02x%02x", U.Round(r * 255), U.Round(g * 255), U.Round(b * 255))
end

local FONT_FACES = {
  bold    = "$(BOLD_FONT)",
  medium  = "$(MEDIUM_FONT)",
  chat    = "$(CHAT_FONT)",
  gamepad = "$(GAMEPAD_BOLD_FONT)",
}

function U.Font(size, faceOverride)
  local sv = R.sv
  local face = FONT_FACES[faceOverride or sv.fontFace] or FONT_FACES.bold
  return string.format("%s|%d|%s", face, U.Clamp(U.Round(size), 8, 48), sv.fontStyle or "soft-shadow-thin")
end

function R.GetColor(key)
  local sv = R.sv
  return sv[key .. "ColorR"], sv[key .. "ColorG"], sv[key .. "ColorB"]
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
function R.MigrateSavedVars()
  local sv = R.sv

  -- v5 -> v6 layout reset (kept from the original addon)
  if (sv.layoutPresetVersion or 0) < 2 then
    for _, k in ipairs({ "barWidth", "barHeight", "healthOffsetX", "healthOffsetY",
                         "magickaOffsetX", "magickaOffsetY", "staminaOffsetX", "staminaOffsetY" }) do
      sv[k] = R.default[k]
    end
    sv.layoutPresetVersion = 2
  end

  -- v6 -> v7: drop settings that no longer do anything
  if (sv.configVersion or 0) < 3 then
    sv.fancyMode = nil
    sv.glowStrength = nil
    sv.animationSpeed = nil
    sv.configVersion = 3
  end
end

---------------------------------------------------------------------------
-- Layout presets (computed from current bar size so they always fit)
---------------------------------------------------------------------------
R.PRESETS = {
  pyramid = function(w, ph, gap)
    local dx, dy = (w + gap) / 2, (ph + gap) / 2
    return { health = { 0, -dy }, magicka = { -dx, dy }, stamina = { dx, dy } }
  end,
  stacked = function(w, ph, gap)
    local dy = ph + gap
    return { health = { 0, -dy }, magicka = { 0, 0 }, stamina = { 0, dy } }
  end,
  row = function(w, ph, gap)
    local dx = w + gap
    return { health = { 0, 0 }, magicka = { -dx, 0 }, stamina = { dx, 0 } }
  end,
}

function R.ApplyPreset(name)
  local build = R.PRESETS[name]
  if not build then return end
  local sv = R.sv
  local offsets = build(sv.barWidth, R.GetPanelHeight(), 6)
  for key, xy in pairs(offsets) do
    sv[key .. "OffsetX"] = U.Round(xy[1])
    sv[key .. "OffsetY"] = U.Round(xy[2])
  end
  R.Refresh()
end

---------------------------------------------------------------------------
-- Shield tracking
---------------------------------------------------------------------------
local function QueryShield()
  if not GetUnitAttributeVisualizerEffectInfo then return nil end
  local value = GetUnitAttributeVisualizerEffectInfo("player", ATTRIBUTE_VISUAL_POWER_SHIELDING,
    STAT_MITIGATION, ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH)
  return value
end

function R.OnAttributeVisual(evt, unitTag, visual, _, attributeType, _, value1, value2)
  if unitTag ~= "player" or visual ~= ATTRIBUTE_VISUAL_POWER_SHIELDING or attributeType ~= ATTRIBUTE_HEALTH then
    return
  end

  -- Prefer an authoritative query; fall back to accumulating event deltas.
  local queried = QueryShield()
  if queried then
    R.shield = queried
  elseif evt == EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED then
    R.shield = R.shield + ((value2 or 0) - (value1 or 0))
  elseif evt == EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED then
    R.shield = R.shield + (value1 or 0)
  elseif evt == EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED then
    R.shield = R.shield - (value1 or 0)
  end

  if R.shield < 0 then R.shield = 0 end
end

---------------------------------------------------------------------------
-- Stock UI suppression
---------------------------------------------------------------------------
function R.HideOriginalBars()
  if ZO_PlayerAttributeHealth then ZO_PlayerAttributeHealth:SetHidden(true) end
  if ZO_PlayerAttributeMagicka then ZO_PlayerAttributeMagicka:SetHidden(true) end
  if ZO_PlayerAttributeStamina then ZO_PlayerAttributeStamina:SetHidden(true) end
  if ZO_ActionBar1KeybindBG then ZO_ActionBar1KeybindBG:SetHidden(true) end
end

local function HookStockBars()
  if not PLAYER_ATTRIBUTE_BARS then return end
  local function deferHide() zo_callLater(R.HideOriginalBars, 0) end
  if PLAYER_ATTRIBUTE_BARS.UpdateAnchors then
    ZO_PostHook(PLAYER_ATTRIBUTE_BARS, "UpdateAnchors", deferHide)
  end
  if PLAYER_ATTRIBUTE_BARS.OnUnitAttributesUpdated then
    ZO_PostHook(PLAYER_ATTRIBUTE_BARS, "OnUnitAttributesUpdated", deferHide)
  end

  -- Stop the stock bars from growing/shrinking with buffs.
  local viz = PLAYER_ATTRIBUTE_BARS.attributeVisualizer
  if viz and viz.visualModules then
    for _, module in pairs(viz.visualModules) do
      if module.expandedWidth then
        module.expandedWidth = module.normalWidth
        module.shrunkWidth = module.normalWidth
      end
    end
  end
end

local function RedirectArmorTextures()
  RedirectTexture("esoui/art/unitattributevisualizer/attributebar_dynamic_increasedarmor_frame.dds", "Rebar/Rebar.dds")
  RedirectTexture("esoui/art/unitattributevisualizer/attributebar_dynamic_increasedarmor_bg.dds", "Rebar/Rebar.dds")
  RedirectTexture("esoui/art/tooltips/munge_overlay.dds", "Rebar/Rebar.dds")
end

---------------------------------------------------------------------------
-- Visibility (HUD scenes, settings preview)
---------------------------------------------------------------------------
local HUD_SCENE_NAMES = { "hud", "hudui", "siegeBar", "siegeBarUI" }

function R.IsHudShowing()
  for _, name in ipairs(HUD_SCENE_NAMES) do
    if SCENE_MANAGER:IsShowing(name) then return true end
  end
  return false
end

function R.RefreshVisibility()
  if not R.ui then return end
  if R.previewing and not SCENE_MANAGER:IsShowing("gameMenuInGame") then
    R.previewing = false
  end
  local show = R.previewing or not R.sv.hideInMenus or R.IsHudShowing()
  R.ui.root:SetHidden(not show)
end

---------------------------------------------------------------------------
-- Lock / unlock
---------------------------------------------------------------------------
function R.SetUnlocked(unlocked)
  R.sv.movable = unlocked and true or false
  R.UpdateMoverState()
  if LibAddonMenu2 and R.lamPanel then
    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", R.lamPanel)
  end
end

local function Print(msg)
  if CHAT_ROUTER then
    CHAT_ROUTER:AddSystemMessage("|c66ccffRebar|r " .. msg)
  else
    d("Rebar: " .. msg)
  end
end

local function SlashCommand(arg)
  arg = zo_strlower(zo_strtrim(arg or ""))
  if arg == "lock" then
    R.SetUnlocked(false); Print("bars locked.")
  elseif arg == "unlock" then
    R.SetUnlocked(true); Print("bars unlocked - drag them, then /rebar lock.")
  elseif arg == "center" then
    R.sv.offsetX, R.sv.offsetY = 0, R.default.offsetY
    R.Refresh(); Print("position reset.")
  elseif R.PRESETS[arg] then
    R.ApplyPreset(arg); Print("applied " .. arg .. " layout.")
  elseif arg == "" and R.lamPanel then
    LibAddonMenu2:OpenToPanel(R.lamPanel)
  else
    Print("commands: /rebar [lock | unlock | center | pyramid | stacked | row]")
  end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function R.OnPlayerActivated()
  R.shield = QueryShield() or 0
  R.ResetAnimationState()
  R.HideOriginalBars()
  R.Refresh()
  R.RefreshVisibility()
end

function R.Initialize()
  R.sv = ZO_SavedVars:NewAccountWide(R.svName, R.svVersion, nil, R.default)
  R.MigrateSavedVars()

  RedirectArmorTextures()
  HookStockBars()

  local em = EVENT_MANAGER
  em:RegisterForEvent(R.name, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, R.OnAttributeVisual)
  em:RegisterForEvent(R.name, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, R.OnAttributeVisual)
  em:RegisterForEvent(R.name, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, R.OnAttributeVisual)
  em:RegisterForEvent(R.name, EVENT_PLAYER_ACTIVATED, R.OnPlayerActivated)

  R.CreateUI()
  R.Refresh()

  SCENE_MANAGER:RegisterCallback("SceneStateChanged", R.RefreshVisibility)

  R.CreateSettingsPanel()

  SLASH_COMMANDS["/rebar"] = SlashCommand
end

local function OnAddOnLoaded(_, name)
  if name ~= R.name then return end
  EVENT_MANAGER:UnregisterForEvent(R.name, EVENT_ADD_ON_LOADED)
  R.Initialize()
end

EVENT_MANAGER:RegisterForEvent(R.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
