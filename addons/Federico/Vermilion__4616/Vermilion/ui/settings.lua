Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Settings = {}
local M = Vermilion.Settings
local Sound = Vermilion.Sound

local api = Vermilion.zenimax.api
local zc  = Vermilion.zenimax.constants
local Scene = Vermilion.zenimax.scene
local GetString          = api.GetString
local d                  = d
local math_floor         = math.floor

local log         = Vermilion.Log.for_module("settings")
local TOPLEFT     = zc.TOPLEFT
local GuiRoot     = zc.GuiRoot

local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

local SAMPLE_1HZ, SAMPLE_2HZ, SAMPLE_SLOW = 1000, 500, 2000
local SAMPLE_DEFAULT = SAMPLE_1HZ

local VPALPHA_DEFAULT = 30
local LIGHTA_DEFAULT = 40

local sliders = {}

local controls           = {}
local current_sample     = SAMPLE_DEFAULT
local current_auto       = false
local current_vpalpha    = VPALPHA_DEFAULT
local current_lighta     = LIGHTA_DEFAULT

local function persist_temporal(key, val)
  local sv = Vermilion.SavedVars
  if sv then sv.temporal = sv.temporal or {} ; sv.temporal[key] = val end
end

local function persist_graph(key, val)
  local sv = Vermilion.SavedVars
  if sv then sv.graph = sv.graph or {} ; sv.graph[key] = val end
end

local function keeps_minutes(ms)
  return math_floor(Vermilion.Constants.TEMPORAL.CAPACITY * ms / 60000)
end

local function sample_label(ms, auto)
  if auto then return string.format(GetString(VERMILION_SETTINGS_SAMPLE_AUTO), keeps_minutes(SAMPLE_SLOW)) end
  if ms > SAMPLE_1HZ then
    return string.format(GetString(VERMILION_SETTINGS_SAMPLE_SLOW), math_floor(ms / 1000), keeps_minutes(ms))
  end
  return string.format(GetString(VERMILION_SETTINGS_SAMPLE), math_floor(1000 / ms), keeps_minutes(ms))
end

local function refresh_all_sliders()
  sliders.vpalpha.set(current_vpalpha)
  sliders.lighta.set(current_lighta)
end

local function background_label()
  return string.format(GetString(VERMILION_SETTINGS_BACKGROUND), Vermilion.Skin.background_name())
end

local background_list

function M.background_list()
  return background_list
end

local function close_background_list()
  if background_list then background_list.close() end
end

function M.on_background_click()
  if not background_list then
    local items = {}
    for i, b in ipairs(Vermilion.Skin.backgrounds()) do
      items[i] = { key = b.key, label = GetString(b.name) }
    end
    background_list = Vermilion.Dropdown.new({
      name = "VermilionSettingsPanelBackgroundList",
      parent = controls.window,
      button = controls.background_btn,
      items = items,
      selected = Vermilion.Skin.background,
      on_pick = function(key)
        Vermilion.SavedVars.settings.background = key
        Vermilion.Skin.set_background(key)
        controls.background_btn:SetText(background_label())
      end,
    })
  end
  background_list.toggle()
end

function M.refresh_unknown_count()
  local SC = Vermilion.SkillColors
  local n = (SC and SC.unknown_count and SC.unknown_count()) or 0
  local text = GetString(VERMILION_SETTINGS_UNKNOWN)
  if n > 0 then text = text .. " (" .. n .. ")" end
  controls.unknown_label:SetText(text)
  if n > 0 then
    controls.unknown_label:SetColor(0.93, 0.76, 0.38, 1)
  else
    controls.unknown_label:SetColor(0.62, 0.62, 0.62, 1)
  end
end

local dock

function M.is_detached() return Vermilion.Dock.is_detached(dock) end
function M.forget_dock() Vermilion.Dock.forget(dock) end

function M.refresh_dev_button()
  local b = VermilionSettingsPanelDevBtn
  controls.dev_btn = b
  b:SetText("DEV")
  b:SetHidden(not Vermilion.Constants.DEBUG)
end

function M.toggle()
  local win    = controls.window
  local hidden = win:IsHidden()
  close_background_list()
  if hidden then
    Vermilion.Dock.open(dock)
    Scene.show_top_level(win)
    win:BringWindowToTop()
    refresh_all_sliders()
    M.refresh_unknown_count()
    M.refresh_dev_button()
    Sound.play("open")
  else
    Scene.hide_top_level(win)
    Vermilion.About.hide()
    Sound.play("close")
  end
end

function M.on_move_stop()
  if dock then Vermilion.Dock.released(dock) end
end

function M.on_unknown_click()
  close_background_list()
  controls.window:SetHidden(true)
  Vermilion.Assign.show()
end

function M.on_logo_click()
  local now = not Vermilion.Logo.is_enabled()
  Vermilion.Logo.set_enabled(now)
  Sound.play(now and "on" or "off")
  controls.logo_btn:SetText(now and GetString(VERMILION_SETTINGS_LOGO_ON)
                                 or GetString(VERMILION_SETTINGS_LOGO_OFF))
  if not now then d("[Vm] " .. GetString(VERMILION_LOGO_HINT)) end
end

function M.lamp_prefs()
  local sv = Vermilion.SavedVars
  local p = sv and sv.log_lamp
  if not p then return false end
  return p.enabled == true, p.x, p.y
end

function M.save_lamp(on, x, y)
  local sv = Vermilion.SavedVars
  if not sv then return end
  sv.log_lamp = sv.log_lamp or {}
  sv.log_lamp.enabled = on and true or false
  if x and y then sv.log_lamp.x, sv.log_lamp.y = x, y end
end

local function lamp_label(on)
  return on and GetString(VERMILION_SETTINGS_LAMP_ON) or GetString(VERMILION_SETTINGS_LAMP_OFF)
end

function M.on_lamp_click()
  local now = not Vermilion.LogLamp.is_enabled()
  Vermilion.LogLamp.set_enabled(now)
  Sound.play(now and "on" or "off")
  controls.lamp_btn:SetText(lamp_label(now))
end

function M.on_sample_click()
  if Vermilion.TemporalBuffer.is_recording() then
    Sound.play("deny")
    return
  end
  if current_auto then
    current_sample, current_auto = SAMPLE_1HZ, false
  elseif current_sample == SAMPLE_1HZ then
    current_sample = SAMPLE_2HZ
  elseif current_sample == SAMPLE_2HZ then
    current_sample = SAMPLE_SLOW
  else
    current_sample, current_auto = SAMPLE_1HZ, true
  end
  log:info("sample_rate ->", current_sample, "ms", current_auto and "auto" or "")
  persist_temporal("sample_rate_ms", current_sample)
  persist_temporal("sample_auto", current_auto or nil)
  controls.sample_btn:SetText(sample_label(current_sample, current_auto))
  Sound.play(current_auto and "off" or "on")
end

local function light_label(on)
  return on and GetString(VERMILION_SETTINGS_LIGHT_ON) or GetString(VERMILION_SETTINGS_LIGHT_OFF)
end

local function kills_label(on)
  return on and GetString(VERMILION_SETTINGS_KILLS_ON) or GetString(VERMILION_SETTINGS_KILLS_OFF)
end

function M.sample_ms() return current_sample end
function M.sample_auto() return current_auto end

function M.migrate_recording(temporal, settings)
  temporal.time_window_s = nil
  temporal.film_length_migrated = nil
  settings.profile = nil
  settings.user_profiles = nil
  local ms = temporal.sample_rate_ms
  if ms then
    if ms < SAMPLE_1HZ then ms = SAMPLE_2HZ elseif ms > SAMPLE_1HZ then ms = SAMPLE_SLOW end
    temporal.sample_rate_ms = ms
  end
  if ms == nil then
    temporal.sample_rate_ms, temporal.sample_auto = SAMPLE_1HZ, true
  elseif temporal.sample_auto ~= true or ms ~= SAMPLE_1HZ then
    temporal.sample_auto = nil
  end
end

function M.kill_markers()
  local sv = Vermilion.SavedVars
  return not (sv and sv.settings and sv.settings.kill_markers == false)
end

function M.on_kills_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not M.kill_markers()
  sv.settings.kill_markers = now
  controls.kills_btn:SetText(kills_label(now))
  Sound.play(now and "on" or "off")
  if Vermilion.Graph and Vermilion.Graph.rerender then Vermilion.Graph.rerender() end
end

local function avg_label(on)
  return on and GetString(VERMILION_SETTINGS_AVG_ON) or GetString(VERMILION_SETTINGS_AVG_OFF)
end

function M.average_line()
  local sv = Vermilion.SavedVars
  return (sv and sv.settings and sv.settings.average_line == true) or false
end

local function zoom_scale_label(on)
  return on and GetString(VERMILION_SETTINGS_ZOOM_VISIBLE) or GetString(VERMILION_SETTINGS_ZOOM_WHOLE)
end

function M.zoom_local_scale()
  local sv = Vermilion.SavedVars
  return not (sv and sv.settings and sv.settings.zoom_local_scale == false)
end

function M.on_zoom_scale_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not M.zoom_local_scale()
  sv.settings.zoom_local_scale = now
  controls.zoom_scale_btn:SetText(zoom_scale_label(now))
  Sound.play(now and "on" or "off")
  if Vermilion.Graph and Vermilion.Graph.rerender then Vermilion.Graph.rerender() end
end

local function median_label(on)
  return on and GetString(VERMILION_SETTINGS_MEDIAN_ON) or GetString(VERMILION_SETTINGS_MEDIAN_OFF)
end

function M.median_line()
  local sv = Vermilion.SavedVars
  return (sv and sv.settings and sv.settings.median_line == true) or false
end

function M.on_median_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not M.median_line()
  sv.settings.median_line = now
  controls.median_btn:SetText(median_label(now))
  Sound.play(now and "on" or "off")
  if Vermilion.Graph and Vermilion.Graph.rerender then Vermilion.Graph.rerender() end
end

function M.on_avg_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not M.average_line()
  sv.settings.average_line = now
  controls.avg_btn:SetText(avg_label(now))
  Sound.play(now and "on" or "off")
  if Vermilion.Graph and Vermilion.Graph.rerender then Vermilion.Graph.rerender() end
end

function M.light_alpha_pct()
  local sv = Vermilion.SavedVars
  return (sv and sv.settings and sv.settings.light_alpha_pct) or LIGHTA_DEFAULT
end

function M.light_mode()
  local sv = Vermilion.SavedVars
  return (sv and sv.settings and sv.settings.light_mode) == true
end

function M.on_light_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not (sv.settings.light_mode == true)
  sv.settings.light_mode = now
  Sound.play(now and "on" or "off")
  controls.light_btn:SetText(light_label(now))
  Vermilion.Graph.set_light_enabled(now)
end

local function sounds_on()
  local sv = Vermilion.SavedVars
  return not (sv and sv.settings and sv.settings.sounds == false)
end

local function sounds_label(on)
  return on and GetString(VERMILION_SETTINGS_SOUNDS_ON) or GetString(VERMILION_SETTINGS_SOUNDS_OFF)
end

function M.on_sounds_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not sounds_on()
  sv.settings.sounds = now
  controls.sounds_btn:SetText(sounds_label(now))
  if now then Sound.play("confirm") end
end

function M.on_reset_click()
  log:info("reset to defaults")
  Sound.play("confirm")
  current_sample     = SAMPLE_DEFAULT
  current_auto       = true
  current_vpalpha    = VPALPHA_DEFAULT
  persist_temporal("sample_rate_ms", current_sample)
  persist_temporal("sample_auto", true)
  persist_graph("viewport_alpha_pct", current_vpalpha)
  Vermilion.Graph.set_viewport_alpha(current_vpalpha / 100)
  controls.sample_btn:SetText(sample_label(current_sample, current_auto))
  local sv = Vermilion.SavedVars
  if sv and sv.settings then
    Vermilion.AutoRecord.set_mode("off")
    sv.settings.session_autosave = false
    Vermilion.AutoRecord.set_auto_stop(false)
    Vermilion.Graph.refresh_record_button()
    sv.settings.sounds = nil
    controls.sounds_btn:SetText(sounds_label(true))
    sv.settings.light_mode = false
    sv.settings.light_alpha_pct = nil
    controls.light_btn:SetText(light_label(false))
    sv.settings.kill_markers = nil
    controls.kills_btn:SetText(kills_label(true))
    sv.settings.average_line = nil
    controls.avg_btn:SetText(avg_label(false))
    sv.settings.median_line = nil
    sv.settings.zoom_local_scale = nil
    controls.zoom_scale_btn:SetText(zoom_scale_label(true))
    controls.median_btn:SetText(median_label(false))
    M.forget_dock()
    Vermilion.Library.forget_dock()
    sv.settings.background = nil
    Vermilion.Skin.set_background(nil)
    controls.background_btn:SetText(background_label())
    Vermilion.Graph.set_light_enabled(false)
  end
  current_lighta = LIGHTA_DEFAULT
  refresh_all_sliders()
  if Vermilion.Graph and Vermilion.Graph.rerender then Vermilion.Graph.rerender() end
end

function M.snapshot()
  local capacity = Vermilion.Constants.TEMPORAL.CAPACITY
  return {
    sample_rate_ms      = current_sample,
    sample_auto         = current_auto,
    time_window_s       = math_floor(capacity * (current_auto and SAMPLE_SLOW or current_sample) / 1000),
    viewport_alpha_pct  = current_vpalpha,
    temporal_capacity   = capacity,
  }
end

function M.report_lines()
  local s = M.snapshot()
  return {
    string.format("[config] graph: sample=%dms%s keeps=%ds capacity=%d",
      s.sample_rate_ms, s.sample_auto and " auto" or "", s.time_window_s, s.temporal_capacity),
    string.format("[config] viewport_alpha=%d%%", s.viewport_alpha_pct),
  }
end

function M.init()
  Vermilion.Skin.panel(VermilionSettingsPanelBg)
  Vermilion.Skin.buttons({
    VermilionSettingsPanelSampleBtn, VermilionSettingsPanelLogoBtn,
    VermilionSettingsPanelSoundsBtn, VermilionSettingsPanelLightBtn, VermilionSettingsPanelKillsBtn,
    VermilionSettingsPanelAvgBtn, VermilionSettingsPanelMedianBtn, VermilionSettingsPanelZoomScaleBtn,
    VermilionSettingsPanelBackgroundBtn, VermilionSettingsPanelResetBtn, VermilionSettingsPanelLampBtn,
  })
  Vermilion.Skin.close(VermilionSettingsPanelCloseBtn)
  local sv = Vermilion.SavedVars
  sv.temporal = sv.temporal or {}
  sv.settings = sv.settings or {}
  sv.graph    = sv.graph    or {}

  M.migrate_recording(sv.temporal, sv.settings)
  current_sample     = sv.temporal.sample_rate_ms or SAMPLE_DEFAULT
  current_auto       = sv.temporal.sample_auto == true
  current_vpalpha    = sv.graph.viewport_alpha_pct or VPALPHA_DEFAULT

  Vermilion.TemporalBuffer.init(Vermilion.Constants.TEMPORAL.CAPACITY)

  controls.window         = VermilionSettingsPanel
  controls.window:SetHidden(true)
  Scene.register_top_level(controls.window)
  controls.sample_btn     = VermilionSettingsPanelSampleBtn
  controls.title_vpalpha  = VermilionSettingsPanelVPAlphaTitle
  controls.label_vpalpha  = VermilionSettingsPanelVPAlphaLabel
  controls.track_vpalpha  = VermilionSettingsPanelSliderTrackVPAlpha
  controls.reset_btn      = VermilionSettingsPanelResetBtn
  controls.unknown_btn    = VermilionSettingsPanelUnknownBtn
  controls.unknown_label  = VermilionSettingsPanelUnknownLabel
  controls.logo_btn       = VermilionSettingsPanelLogoBtn
  controls.lamp_btn       = VermilionSettingsPanelLampBtn
  controls.sounds_btn     = VermilionSettingsPanelSoundsBtn
  controls.light_btn      = VermilionSettingsPanelLightBtn
  controls.kills_btn      = VermilionSettingsPanelKillsBtn
  controls.avg_btn        = VermilionSettingsPanelAvgBtn
  controls.median_btn     = VermilionSettingsPanelMedianBtn
  controls.zoom_scale_btn = VermilionSettingsPanelZoomScaleBtn
  controls.title_lighta   = VermilionSettingsPanelLightAlphaTitle
  controls.label_lighta   = VermilionSettingsPanelLightAlphaLabel
  controls.track_lighta   = VermilionSettingsPanelSliderTrackLightAlpha
  controls.background_btn = VermilionSettingsPanelBackgroundBtn
  controls.background_btn:SetText(background_label())

  VermilionSettingsPanelVersionLabel:SetText("v" .. Vermilion.Constants.VERSION .. (Vermilion.Constants.DEBUG and ("  " .. GetString(VERMILION_DEBUG_TAG)) or ""))
  VermilionSettingsPanelVersionLabel:SetColor(0.55, 0.46, 0.45, 0.9)
  M.refresh_dev_button()
  controls.reset_btn:SetText(GetString(VERMILION_SETTINGS_RESET))
  controls.sample_btn:SetText(sample_label(current_sample, current_auto))
  M.refresh_unknown_count()

  local SEC = {
    { VermilionSettingsPanelSecGraph,     VermilionSettingsPanelSepGraph,     VERMILION_SETTINGS_SEC_GRAPH },
    { VermilionSettingsPanelSecGeneral,   VermilionSettingsPanelSepGeneral,   VERMILION_SETTINGS_SEC_GENERAL },
  }
  for _, sec in ipairs(SEC) do
    sec[1]:SetText(GetString(sec[3]))
    sec[1]:SetColor(0.95, 0.42, 0.34, 0.90)
    sec[2]:SetTexture(FILL_TEXTURE)
    sec[2]:SetTextureCoords(0, 1, 0, 0.05)
    sec[2]:SetColor(0.95, 0.42, 0.34, 0.22)
  end
  VermilionSettingsPanelSepColumns:SetTexture(FILL_TEXTURE)
  VermilionSettingsPanelSepColumns:SetTextureCoords(0, 0.05, 0, 1)
  VermilionSettingsPanelSepColumns:SetColor(0.95, 0.42, 0.34, 0.12)

  controls.logo_btn:SetText(Vermilion.Logo.is_enabled()
    and GetString(VERMILION_SETTINGS_LOGO_ON) or GetString(VERMILION_SETTINGS_LOGO_OFF))
  controls.lamp_btn:SetText(lamp_label(Vermilion.LogLamp.is_enabled()))
  controls.sounds_btn:SetText(sounds_label(sounds_on()))
  controls.light_btn:SetText(light_label(sv.settings.light_mode == true))
  controls.kills_btn:SetText(kills_label(M.kill_markers()))
  controls.avg_btn:SetText(avg_label(M.average_line()))
  controls.median_btn:SetText(median_label(M.median_line()))
  controls.zoom_scale_btn:SetText(zoom_scale_label(M.zoom_local_scale()))
  current_lighta = sv.settings.light_alpha_pct or LIGHTA_DEFAULT

  for _, k in ipairs({ "vpalpha", "lighta" }) do
    controls["title_" .. k]:SetColor(0.75, 0.75, 0.75, 1)
    controls["label_" .. k]:SetColor(0.95, 0.80, 0.20, 1)
  end
  controls.title_vpalpha:SetText(GetString(VERMILION_SETTING_VIEWPORT_ALPHA))
  controls.title_lighta:SetText(GetString(VERMILION_SETTING_LIGHT_ALPHA))

  local Slider = Vermilion.Slider
  sliders.vpalpha = Slider.new({
    name = "VermilionSettingsVPAlpha", track = controls.track_vpalpha, label = controls.label_vpalpha,
    min = 0, max = 100, value = current_vpalpha,
    on_change = function(v)
      current_vpalpha = v
      persist_graph("viewport_alpha_pct", v)
      Vermilion.Graph.set_viewport_alpha(v / 100)
    end,
  })
  sliders.lighta = Slider.new({
    name = "VermilionSettingsLightA", track = controls.track_lighta, label = controls.label_lighta,
    min = 10, max = 90, value = current_lighta,
    on_change = function(v)
      current_lighta = v
      local s = Vermilion.SavedVars
      s.settings = s.settings or {}
      s.settings.light_alpha_pct = v
      Vermilion.Graph.set_light_alpha(v / 100)
    end,
  })

  controls.window:ClearAnchors()
  if sv.settings.detached and sv.settings.x and sv.settings.y then
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.settings.x, sv.settings.y)
  else
    controls.window:SetAnchor(zc.CENTER, GuiRoot, zc.CENTER, 0, 0)
  end
  dock = Vermilion.Dock.new(controls.window, VermilionGraphWindow, sv.settings, { "right", "left" })

  for _, line in ipairs(M.report_lines()) do log:info(line) end
end
