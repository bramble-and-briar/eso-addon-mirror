Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Settings = {}
local M = Verdant.Settings
local Sound  = Verdant.Sound
local Skin   = Verdant.Skin
local Themes = Verdant.lib.themes
local Slider = Verdant.Slider
local Dock   = Verdant.Dock

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local Scene = Verdant.zenimax.scene
local GetString     = api.GetString
local math_floor    = math.floor
local string_format = string.format

local log = Verdant.Log.for_module("settings")

local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

local ALPHA_STEPS  = Slider.range(0, 100, 1)
local LIGHTA_STEPS = Slider.range(10, 90, 1)

local SAMPLE_1HZ, SAMPLE_2HZ, SAMPLE_SLOW = 1000, 500, 2000
local CAPACITY = Verdant.Constants.TEMPORAL.CAPACITY

local DEFAULTS = { vpalpha = 30, lighta = 40 }

local function percent_text(v) return v .. "%" end

local controls = {}
local sliders  = {}
local current  = {}
local dock, theme_list

local function saved()
  return Verdant.SavedVars
end

local function keeps_seconds()
  return CAPACITY * (current.auto and SAMPLE_SLOW or current.sample) / 1000
end

local function sample_label()
  local minutes = math_floor(keeps_seconds() / 60)
  if current.auto then return string_format(GetString(VERDANT_SETTINGS_SAMPLE_AUTO), minutes) end
  if current.sample > SAMPLE_1HZ then
    return string_format(GetString(VERDANT_SETTINGS_SAMPLE_SLOW), math_floor(current.sample / 1000), minutes)
  end
  return string_format(GetString(VERDANT_SETTINGS_SAMPLE), math_floor(1000 / current.sample), minutes)
end

local function set_sampling(ms, auto)
  current.sample, current.auto = ms, auto
  local temporal = saved().temporal
  temporal.sample_rate_ms = ms
  temporal.sample_auto = auto or nil
  controls.sample_btn:SetText(sample_label())
  log:info("sample ->", ms, auto and "auto" or "")
end

function M.migrate_sampling(temporal)
  local ms = temporal.sample_rate_ms
  local had_window = temporal.time_window_s ~= nil
  temporal.time_window_s = nil
  if ms == nil or (had_window and ms == SAMPLE_1HZ) then
    temporal.sample_rate_ms, temporal.sample_auto = SAMPLE_1HZ, true
    return
  end
  if ms < SAMPLE_1HZ then ms = SAMPLE_2HZ elseif ms > SAMPLE_1HZ then ms = SAMPLE_SLOW end
  temporal.sample_rate_ms = ms
  if ms ~= SAMPLE_1HZ then temporal.sample_auto = nil end
end

local APPLY = {
  vpalpha = function(v)
    saved().temporal.viewport_alpha_pct = v
    Verdant.Graph.set_viewport_alpha(v / 100)
  end,
  lighta = function(v)
    saved().settings.light_alpha_pct = v
    Verdant.Graph.set_light_alpha(v / 100)
  end,
}

local function set_value(key, v)
  current[key] = v
  APPLY[key](v)
  log:info(key, "->", v)
end

local function refresh_all_sliders()
  for key, slider in pairs(sliders) do slider.set(current[key]) end
end

local function on_off(on, yes, no)
  return GetString(on and yes or no)
end

local function theme_label()
  return string_format(GetString(VERDANT_SETTINGS_THEME), Themes.name(Themes.current()))
end

local function close_theme_list()
  if theme_list then theme_list.close() end
end

function M.load_theme()
  Themes.use(saved().settings.theme)
  controls.theme_btn:SetText(theme_label())
end

function M.on_theme_click()
  if not theme_list then
    local items = {}
    for i, key in ipairs(Themes.list()) do
      items[i] = { key = key, label = Themes.name(key) }
    end
    theme_list = Verdant.Dropdown.new({
      name = "VerdantSettingsPanelThemeList",
      parent = controls.window,
      button = controls.theme_btn,
      items = items,
      selected = Themes.current,
      on_pick = function(key)
        saved().settings.theme = Themes.use(key)
        controls.theme_btn:SetText(theme_label())
      end,
    })
  end
  theme_list.toggle()
end

function M.refresh_unknown()
  local n = Verdant.SkillColors.unknown_count() + Verdant.BuffOrigin.unknown_count()
  local text = GetString(VERDANT_SETTINGS_UNKNOWN)
  if n > 0 then text = text .. " (" .. n .. ")" end
  controls.unknown_label:SetText(text)
  Skin.label(controls.unknown_label, (n > 0) and "metal" or "dim")
end

local function refresh_dev_button()
  local b = VerdantSettingsPanelDevBtn
  b:SetText("DEV")
  b:SetHidden(not Verdant.Constants.DEBUG)
end

function M.toggle()
  local win = controls.window
  close_theme_list()
  if win:IsHidden() then
    Dock.open(dock)
    Scene.show_top_level(win)
    win:BringWindowToTop()
    M.refresh_unknown()
    refresh_dev_button()
    Sound.play("open")
  else
    Scene.hide_top_level(win)
    Sound.play("close")
  end
end

function M.on_move_stop()
  Dock.released(dock)
end

function M.library_place()
  local s = saved().settings
  s.library_dock = s.library_dock or {}
  return s.library_dock
end

function M.on_sample_click()
  if Verdant.TemporalBuffer.is_recording() then
    Sound.play("deny")
    return
  end
  if current.auto then
    set_sampling(SAMPLE_1HZ, false)
  elseif current.sample == SAMPLE_1HZ then
    set_sampling(SAMPLE_2HZ, false)
  elseif current.sample == SAMPLE_2HZ then
    set_sampling(SAMPLE_SLOW, false)
  else
    set_sampling(SAMPLE_1HZ, true)
  end
  Sound.play(current.auto and "off" or "on")
end

function M.on_unknown_click()
  close_theme_list()
  Verdant.Assign.show()
end

function M.on_logo_click()
  local now = not Verdant.Logo.is_enabled()
  Verdant.Logo.set_enabled(now)
  Sound.play(now and "on" or "off")
  controls.logo_btn:SetText(on_off(now, VERDANT_SETTINGS_LOGO_ON, VERDANT_SETTINGS_LOGO_OFF))
  if not now then d("[V] " .. GetString(VERDANT_LOGO_HINT)) end
end

function M.res_pick()
  local sv = saved()
  return sv and sv.settings and sv.settings.res_pick or nil
end

function M.save_res_pick(p)
  local sv = saved()
  if not sv then return end
  sv.settings = sv.settings or {}
  sv.settings.res_pick = p
end

function M.lamp_prefs()
  local sv = saved()
  local p = sv and sv.log_lamp
  if not p then return false end
  return p.enabled == true, p.x, p.y
end

function M.save_lamp(on, x, y)
  local sv = saved()
  if not sv then return end
  sv.log_lamp = sv.log_lamp or {}
  sv.log_lamp.enabled = on and true or false
  if x and y then sv.log_lamp.x, sv.log_lamp.y = x, y end
end

function M.on_lamp_click()
  local now = not Verdant.LogLamp.is_enabled()
  Verdant.LogLamp.set_enabled(now)
  Sound.play(now and "on" or "off")
  controls.lamp_btn:SetText(on_off(now, VERDANT_SETTINGS_LAMP_ON, VERDANT_SETTINGS_LAMP_OFF))
end

local function sounds_on()
  return saved().settings.sounds ~= false
end

function M.on_sounds_click()
  local now = not sounds_on()
  saved().settings.sounds = now
  controls.sounds_btn:SetText(on_off(now, VERDANT_SETTINGS_SOUNDS_ON, VERDANT_SETTINGS_SOUNDS_OFF))
  if now then Sound.play("confirm") end
end

function M.on_light_click()
  local now = not (saved().settings.light_mode == true)
  saved().settings.light_mode = now
  Sound.play(now and "on" or "off")
  controls.light_btn:SetText(on_off(now, VERDANT_SETTINGS_LIGHT_ON, VERDANT_SETTINGS_LIGHT_OFF))
  Verdant.Graph.set_light_enabled(now)
end

function M.zoom_local_scale()
  return saved().settings.zoom_local_scale ~= false
end

function M.on_zoom_scale_click()
  local now = not M.zoom_local_scale()
  saved().settings.zoom_local_scale = now
  Sound.play(now and "on" or "off")
  controls.zoom_scale_btn:SetText(on_off(now, VERDANT_SETTINGS_ZOOM_VISIBLE, VERDANT_SETTINGS_ZOOM_WHOLE))
  Verdant.Graph.rerender()
end

function M.average_line()
  return saved().settings.average_line == true
end

function M.median_line()
  return saved().settings.median_line == true
end

function M.on_avg_click()
  local now = not M.average_line()
  saved().settings.average_line = now
  Sound.play(now and "on" or "off")
  controls.avg_btn:SetText(on_off(now, VERDANT_SETTINGS_AVG_ON, VERDANT_SETTINGS_AVG_OFF))
  Verdant.Graph.rerender()
end

function M.on_median_click()
  local now = not M.median_line()
  saved().settings.median_line = now
  Sound.play(now and "on" or "off")
  controls.median_btn:SetText(on_off(now, VERDANT_SETTINGS_MEDIAN_ON, VERDANT_SETTINGS_MEDIAN_OFF))
  Verdant.Graph.rerender()
end

function M.group_deaths()
  return saved().settings.group_death_markers == true
end

function M.on_gdm_click()
  local now = not M.group_deaths()
  saved().settings.group_death_markers = now
  Sound.play(now and "on" or "off")
  controls.gdm_btn:SetText(on_off(now, VERDANT_SETTINGS_GDM_ON, VERDANT_SETTINGS_GDM_OFF))
  Verdant.Graph.rerender()
end

function M.on_reset_click()
  log:info("reset to defaults")
  Sound.play("confirm")
  close_theme_list()
  for key, v in pairs(DEFAULTS) do set_value(key, v) end
  set_sampling(SAMPLE_1HZ, true)
  local s = saved().settings
  s.light_alpha_pct = nil
  Verdant.AutoRecord.set_mode("off")
  Verdant.AutoRecord.set_auto_stop(false)
  s.session_autosave = false
  Verdant.Graph.refresh_record_button()
  s.sounds = nil
  controls.sounds_btn:SetText(on_off(true, VERDANT_SETTINGS_SOUNDS_ON, VERDANT_SETTINGS_SOUNDS_OFF))
  s.light_mode = false
  controls.light_btn:SetText(on_off(false, VERDANT_SETTINGS_LIGHT_ON, VERDANT_SETTINGS_LIGHT_OFF))
  Verdant.Graph.set_light_enabled(false)
  s.group_death_markers = false
  controls.gdm_btn:SetText(on_off(false, VERDANT_SETTINGS_GDM_ON, VERDANT_SETTINGS_GDM_OFF))
  s.theme = nil
  M.load_theme()
  s.zoom_local_scale = nil
  controls.zoom_scale_btn:SetText(on_off(true, VERDANT_SETTINGS_ZOOM_VISIBLE, VERDANT_SETTINGS_ZOOM_WHOLE))
  s.average_line, s.median_line = nil, nil
  controls.avg_btn:SetText(on_off(false, VERDANT_SETTINGS_AVG_ON, VERDANT_SETTINGS_AVG_OFF))
  controls.median_btn:SetText(on_off(false, VERDANT_SETTINGS_MEDIAN_ON, VERDANT_SETTINGS_MEDIAN_OFF))
  Dock.forget(dock)
  Verdant.Library.forget_dock()
  refresh_all_sliders()
  Verdant.Graph.rerender()
end

function M.snapshot()
  return {
    window_ms          = Verdant.Constants.METRICS.WINDOW_MS,
    sample_rate_ms     = current.sample,
    sample_auto        = current.auto,
    keeps_s            = keeps_seconds(),
    viewport_alpha_pct = current.vpalpha,
    temporal_capacity  = CAPACITY,
  }
end

function M.report_lines()
  local s = M.snapshot()
  return {
    string_format("[config] graph: sample=%dms%s keeps=%ds capacity=%d window=%dms",
      s.sample_rate_ms, s.sample_auto and " auto" or "", s.keeps_s, s.temporal_capacity, s.window_ms),
    string_format("[config] viewport_alpha=%d%%", s.viewport_alpha_pct),
  }
end

local SLIDERS = {
  { key = "vpalpha", piece = "VPAlpha",    steps = ALPHA_STEPS,   text = percent_text, title = "VERDANT_SETTING_VIEWPORT_ALPHA" },
  { key = "lighta",  piece = "LightAlpha", steps = LIGHTA_STEPS,  text = percent_text, title = "VERDANT_SETTING_LIGHT_ALPHA" },
}

local SECTIONS = {
  { "Graph",   "VERDANT_SETTINGS_SEC_GRAPH" },
  { "General", "VERDANT_SETTINGS_SEC_GENERAL" },
}

local function piece(name)
  return _G["VerdantSettingsPanel" .. name]
end

local function build_sliders()
  for _, row in ipairs(SLIDERS) do
    local title, label = piece(row.piece .. "Title"), piece(row.piece .. "Label")
    title:SetText(GetString(_G[row.title]))
    Skin.label(title, "dim")
    Skin.label(label, "metal")
    local key = row.key
    sliders[key] = Slider.new({
      name = "VerdantSettings" .. row.piece, track = piece("SliderTrack" .. row.piece), label = label,
      steps = row.steps, value = current[key], text = row.text,
      on_change = function(v) set_value(key, v) end,
    })
    current[key] = sliders[key].get()
  end
end

local function build_sections()
  for _, sec in ipairs(SECTIONS) do
    local label, sep = piece("Sec" .. sec[1]), piece("Sep" .. sec[1])
    label:SetText(GetString(_G[sec[2]]))
    Skin.label(label, "metal", 0.90)
    sep:SetTexture(FILL_TEXTURE)
    sep:SetTextureCoords(0, 1, 0, 0.05)
    Skin.label(sep, "metal", 0.22)
  end
  local columns = piece("SepColumns")
  columns:SetTexture(FILL_TEXTURE)
  columns:SetTextureCoords(0, 1, 0, 0.05)
  Skin.label(columns, "metal", 0.12)
end

function M.init()
  local sv = saved()
  sv.bar      = nil
  sv.tribar   = nil
  sv.temporal = sv.temporal or {}
  sv.settings = sv.settings or {}
  sv.settings.profile = nil
  sv.settings.shield_down = nil
  sv.settings.user_profiles = nil

  M.migrate_sampling(sv.temporal)
  current.sample  = sv.temporal.sample_rate_ms
  current.auto    = sv.temporal.sample_auto == true
  current.vpalpha = sv.temporal.viewport_alpha_pct or DEFAULTS.vpalpha
  current.lighta  = sv.settings.light_alpha_pct    or DEFAULTS.lighta

  controls.window        = VerdantSettingsPanel
  Scene.register_top_level(controls.window)
  controls.sample_btn    = piece("SampleBtn")
  controls.zoom_scale_btn = piece("ZoomScaleBtn")
  controls.avg_btn       = piece("AvgBtn")
  controls.median_btn    = piece("MedianBtn")
  controls.unknown_btn   = piece("UnknownBtn")
  controls.unknown_label = piece("UnknownLabel")
  controls.logo_btn      = piece("LogoBtn")
  controls.sounds_btn    = piece("SoundsBtn")
  controls.light_btn     = piece("LightBtn")
  controls.gdm_btn       = piece("GdmBtn")
  controls.theme_btn     = piece("ThemeBtn")
  controls.lamp_btn      = piece("LampBtn")
  controls.reset_btn     = piece("ResetBtn")

  Skin.panel(piece("Bg"))
  Skin.close(piece("CloseBtn"))
  Skin.icon(controls.unknown_btn, "bucket")
  Verdant.BuffCatalog.on_done(function()
    if not controls.window:IsHidden() then M.refresh_unknown() end
  end)
  Skin.texture(piece("ThemeCaret"), "caret")
  Skin.buttons({
    controls.logo_btn, controls.sounds_btn, controls.light_btn,
    controls.gdm_btn, controls.theme_btn, controls.reset_btn, controls.sample_btn, controls.zoom_scale_btn,
    controls.avg_btn, controls.median_btn, controls.lamp_btn, piece("DevBtn"),
  })

  build_sections()
  build_sliders()
  Verdant.TemporalBuffer.init(CAPACITY)
  controls.sample_btn:SetText(sample_label())

  local version = piece("VersionLabel")
  version:SetText("v" .. Verdant.Constants.VERSION)
  Skin.label(version, "dim", 0.9)
  M.load_theme()
  Verdant.ResourcesView.load_pick()
  controls.reset_btn:SetText(GetString(VERDANT_SETTINGS_RESET))
  controls.logo_btn:SetText(on_off(Verdant.Logo.is_enabled(), VERDANT_SETTINGS_LOGO_ON, VERDANT_SETTINGS_LOGO_OFF))
  controls.sounds_btn:SetText(on_off(sounds_on(), VERDANT_SETTINGS_SOUNDS_ON, VERDANT_SETTINGS_SOUNDS_OFF))
  controls.light_btn:SetText(on_off(sv.settings.light_mode == true, VERDANT_SETTINGS_LIGHT_ON, VERDANT_SETTINGS_LIGHT_OFF))
  controls.gdm_btn:SetText(on_off(sv.settings.group_death_markers == true, VERDANT_SETTINGS_GDM_ON, VERDANT_SETTINGS_GDM_OFF))
  controls.zoom_scale_btn:SetText(on_off(M.zoom_local_scale(), VERDANT_SETTINGS_ZOOM_VISIBLE, VERDANT_SETTINGS_ZOOM_WHOLE))
  controls.avg_btn:SetText(on_off(M.average_line(), VERDANT_SETTINGS_AVG_ON, VERDANT_SETTINGS_AVG_OFF))
  controls.median_btn:SetText(on_off(M.median_line(), VERDANT_SETTINGS_MEDIAN_ON, VERDANT_SETTINGS_MEDIAN_OFF))
  controls.lamp_btn:SetText(on_off(Verdant.LogLamp.is_enabled(), VERDANT_SETTINGS_LAMP_ON, VERDANT_SETTINGS_LAMP_OFF))

  dock = Dock.new(controls.window, VerdantGraphWindow, sv.settings, { "right", "left" })

  for _, line in ipairs(M.report_lines()) do log:info(line) end
end
