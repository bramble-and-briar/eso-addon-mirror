-- Rebar: LibAddonMenu settings panel.

local R = Rebar

local function Refresh()
  R.Refresh()
end

-- Builders keep each option to one line and wire get/set/default to a saved-var key.
local function Checkbox(key, name, tooltip, onChange)
  return {
    type = "checkbox", name = name, tooltip = tooltip,
    getFunc = function() return R.sv[key] end,
    setFunc = function(v) R.sv[key] = v; (onChange or Refresh)() end,
    default = R.default[key],
  }
end

local function Slider(key, name, min, max, step, tooltip, extra)
  local opt = {
    type = "slider", name = name, tooltip = tooltip,
    min = min, max = max, step = step,
    decimals = step < 1 and 2 or 0,
    getFunc = function() return R.sv[key] end,
    setFunc = function(v) R.sv[key] = v; Refresh() end,
    default = R.default[key],
  }
  for k, v in pairs(extra or {}) do opt[k] = v end
  return opt
end

local function Percent(key, name, min, max, tooltip)
  -- Stored as 0..1, shown as 0..100.
  return {
    type = "slider", name = name, tooltip = tooltip,
    min = min, max = max, step = 1,
    getFunc = function() return math.floor(R.sv[key] * 100 + 0.5) end,
    setFunc = function(v) R.sv[key] = v / 100; Refresh() end,
    default = math.floor(R.default[key] * 100 + 0.5),
  }
end

local function Dropdown(key, name, choices, values, tooltip)
  return {
    type = "dropdown", name = name, tooltip = tooltip,
    choices = choices, choicesValues = values,
    getFunc = function() return R.sv[key] end,
    setFunc = function(v) R.sv[key] = v; Refresh() end,
    default = R.default[key],
  }
end

local function Color(prefix, name, tooltip)
  local rk, gk, bk = prefix .. "ColorR", prefix .. "ColorG", prefix .. "ColorB"
  return {
    type = "colorpicker", name = name, tooltip = tooltip,
    getFunc = function() return R.sv[rk], R.sv[gk], R.sv[bk] end,
    setFunc = function(r, g, b) R.sv[rk], R.sv[gk], R.sv[bk] = r, g, b; Refresh() end,
    default = { r = R.default[rk], g = R.default[gk], b = R.default[bk] },
  }
end

local function Button(name, tooltip, func)
  return { type = "button", name = name, tooltip = tooltip, func = func, width = "half" }
end

local function ResourceSubmenu(key)
  local label = R.RESOURCE_INFO[key].label
  return {
    type = "submenu",
    name = label .. " Bar",
    controls = {
      Color(key, "Color"),
      Slider(key .. "OffsetX", "Offset X", -600, 600, 1, "Horizontal position relative to the group center."),
      Slider(key .. "OffsetY", "Offset Y", -400, 400, 1, "Vertical position relative to the group center."),
      Slider(key .. "Scale", "Scale", 0.50, 1.80, 0.01),
      Slider(key .. "Alpha", "Opacity", 0.20, 1.00, 0.01),
    },
  }
end

function R.CreateSettingsPanel()
  local LAM = LibAddonMenu2
  if not LAM then return end

  local panelData = {
    type = "panel",
    name = "Rebar",
    displayName = "|c66ccffRebar|r  Attribute Bars",
    author = "|cff9beaVixen Hunny|r",
    version = R.version,
    slashCommand = nil, -- /rebar is handled in Rebar.lua
    registerForRefresh = true,
    registerForDefaults = true,
  }

  local options = {
    {
      type = "description",
      text = "Bars stay visible while this panel is open so you can preview changes.\n"
          .. "|c999999/rebar  ·  /rebar lock  ·  /rebar unlock  ·  /rebar pyramid | stacked | row|r",
    },

    -- Position & layout --------------------------------------------------
    { type = "header", name = "Position & Layout" },
    Checkbox("movable", "Unlock (drag to move)", "Shows a blue frame you can drag. Lock again when you're done.", function()
      R.UpdateMoverState()
    end),
    Slider("offsetX", "Group X", -3000, 3000, 2),
    Slider("offsetY", "Group Y", -3000, 3000, 2),
    Slider("barWidth", "Bar Width", 120, 560, 2),
    Slider("barHeight", "Bar Height", 8, 48, 1),
    Button("Pyramid", "Health on top, magicka and stamina below.", function() R.ApplyPreset("pyramid") end),
    Button("Stacked", "All three bars in a vertical column.", function() R.ApplyPreset("stacked") end),
    Button("Row", "Magicka, health, stamina side by side.", function() R.ApplyPreset("row") end),
    Button("Center on Screen", "Reset the group position.", function()
      R.sv.offsetX, R.sv.offsetY = 0, R.default.offsetY
      Refresh()
    end),

    -- Appearance ---------------------------------------------------------
    { type = "header", name = "Appearance" },
    Percent("backgroundAlpha", "Background Opacity", 0, 100),
    Checkbox("showGloss", "Gloss Highlight", "Soft highlight across the top half of each bar."),
    Checkbox("mirrorMagicka", "Mirror Magicka Bar", "Magicka fills right-to-left, so it drains toward the center in a pyramid layout."),
    Checkbox("showThresholdMarker", "Low-Resource Marker", "Thin tick showing where the low-resource warning kicks in."),

    -- Text ----------------------------------------------------------------
    { type = "header", name = "Text" },
    Dropdown("textFormat", "Value Format",
      { "Current / Max", "Current / Max  Percent", "Current  Percent", "Current", "Percent", "Hidden" },
      { "cur_max", "cur_max_pct", "cur_pct", "cur", "pct", "none" }),
    Checkbox("abbreviateNumbers", "Abbreviate Numbers", "24.5k instead of 24,512."),
    Dropdown("fontFace", "Font", { "Bold", "Medium", "Chat", "Gamepad" }, { "bold", "medium", "chat", "gamepad" }),
    Dropdown("fontStyle", "Font Effect",
      { "Thin Shadow", "Thick Shadow", "Outline", "Thick Outline" },
      { "soft-shadow-thin", "soft-shadow-thick", "outline", "thick-outline" }),
    Slider("fontSize", "Font Size", 8, 32, 1),
    Checkbox("showBarLabels", "Show Bar Titles", "HEALTH / MAGICKA / STAMINA on the left of each bar."),
    Checkbox("showRegen", "Show Restore Rate", "Net change per second above each bar."),
    Checkbox("hideZeroRegen", "Hide Restore Rate at 0", "Only show the rate while it's changing.",
      function() Refresh() end),

    -- Shield & alerts ---------------------------------------------------
    { type = "header", name = "Shield & Alerts" },
    Checkbox("showShield", "Show Damage Shield", "Shield strip on the health bar plus its value in the text."),
    Color("shield", "Shield Color"),
    Percent("lowResourceThreshold", "Low-Resource Threshold (%)", 5, 60),
    Checkbox("lowResourcePulse", "Pulse When Low", "Bar border pulses instead of glowing steadily."),

    -- Visibility ------------------------------------------------------
    { type = "header", name = "Visibility" },
    Checkbox("hideInMenus", "Hide in Menus", "Only show bars on the HUD, like the default UI."),
    Checkbox("fadeWhenIdle", "Fade When Idle", "Fade out when out of combat with all resources full."),
    Percent("idleAlpha", "Idle Opacity", 0, 100),

    -- Animation -------------------------------------------------------
    {
      type = "submenu",
      name = "Animation",
      controls = {
        Checkbox("animateBars", "Smooth Bar Movement"),
        Slider("animationGainSpeed", "Gain Speed", 2, 30, 0.1, "Higher is snappier."),
        Slider("animationLossSpeed", "Loss Speed", 2, 30, 0.1, "Higher is snappier."),
        Checkbox("damageTrail", "Damage Trail", "A lighter bar lingers behind losses."),
        Slider("damageTrailSpeed", "Trail Speed", 1, 12, 0.1),
        Checkbox("animateRestoreText", "Animate Restore Rate"),
        Slider("restoreAnimDuration", "Restore Pop Duration", 0.10, 1.20, 0.01),
        Slider("restoreAnimScale", "Restore Pop Size", 0.00, 0.60, 0.01),
      },
    },

    -- Per-resource ------------------------------------------------------
    { type = "header", name = "Individual Bars" },
    ResourceSubmenu("health"),
    ResourceSubmenu("magicka"),
    ResourceSubmenu("stamina"),
  }

  R.lamPanel = LAM:RegisterAddonPanel("RebarMenu", panelData)
  LAM:RegisterOptionControls("RebarMenu", options)

  -- Keep the bars visible as a live preview while our panel is open.
  CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
    if panel == R.lamPanel then
      R.previewing = true
      R.RefreshVisibility()
    end
  end)
  CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
    if panel == R.lamPanel then
      R.previewing = false
      R.RefreshVisibility()
    end
  end)
end
