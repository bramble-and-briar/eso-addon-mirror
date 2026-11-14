Vermilion = Vermilion or {}
Vermilion.Graph = {}
local M = Vermilion.Graph

local api  = Vermilion.zenimax.api
local zc   = Vermilion.zenimax.constants
local GetString                  = api.GetString
local math_max                   = math.max
local string_format              = string.format

local log               = Vermilion.Log.for_module("graph")
local Sound             = Vermilion.Sound
local Format            = Vermilion.Format
local Pools             = Vermilion.ChartPools
local TOPLEFT           = zc.TOPLEFT
local TOPRIGHT          = zc.TOPRIGHT
local BOTTOMLEFT        = zc.BOTTOMLEFT
local BOTTOMRIGHT       = zc.BOTTOMRIGHT
local CENTER            = zc.CENTER
local GuiRoot           = zc.GuiRoot

local C_SHDPS     = { r = 0.85, g = 0.40, b = 0.75, a = 0.90 }
local C_LINE_EDPS = { r = 1.00, g = 0.42, b = 0.32, a = 1.00 }
local C_LINE_EOS  = { r = 1.00, g = 0.92, b = 0.96, a = 1.00 }

local C_NONCRIT   = { r = 0.55, g = 0.22, b = 0.18, a = 0.90 }
local C_CRIT      = { r = 1.00, g = 0.82, b = 0.28, a = 0.96 }

local C_VIEWPORT  = { r = 0.06, g = 0.05, b = 0.05 }

local STATUS_ROW   = { LEFT = 350, RIGHT = 60 }
local VIS = {
  ult       = { PAD = 4, ROW_H = 5, GAP = 9, ICON = 14, AREA = 28 },
  ready     = { r = 1.00, g = 0.90, b = 0.30 },
  shield    = { PAD = 3, ROW_H = 6, AREA = 12, on = false, max = 0, t0 = 0, span = 0, xl = 0, bw = 1 },
  res       = { PAD = 3, ROW_H = 7, GAP = 3, AREA = 23, on = false, t0 = 0, span = 0, xl = 0, bw = 1 },
  mag       = { r = 0.36, g = 0.56, b = 0.96 },
  sta       = { r = 0.46, g = 0.80, b = 0.36 },
  low       = { r = 0.95, g = 0.42, b = 0.34 },
  gold      = { r = 0.80, g = 0.68, b = 0.40 },
  corner_len = 16,
  corner_w   = 2,
  corners = {
    { "TL", TOPLEFT },
    { "TR", TOPRIGHT },
    { "BL", BOTTOMLEFT },
    { "BR", BOTTOMRIGHT },
  },
  shd = {},
  sample_shields = { count = 0 },
  sample_targets = { count = 0 },
  kill_icon = "EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds",
  kill_size = 14,
  kills_y = 0,
}
local RES = Vermilion.FilmBands.RES
local function ult_inset()
  local U = Vermilion.Ultimate
  return (U and U.has_data()) and VIS.ult.AREA or 0
end
function RES.inset()
  return VIS.res.on and VIS.res.AREA or 0
end
local function top_inset()
  return ult_inset() + (VIS.shield.on and VIS.shield.AREA or 0) + RES.inset()
end
function RES.present()
  local TB = Vermilion.TemporalBuffer
  for i = 1, TB.count() do
    local s = TB.at(i)
    if (s.mag or 0) > 0 or (s.sta or 0) > 0 then return true end
  end
  return false
end

local controls           = {}
local REC                = { start_ms = 0, last_elapsed = nil, every = 1, tick = 0, auto = false }
local CHIP               = { H = 0 }

local VIEWS       = Vermilion.Views.list
local VIEW_LABELS = {}
for v = 1, #VIEWS do VIEW_LABELS[v] = VIEWS[v].label end

local STATE = { view = 1, hover_key = nil }


local DT_ICON_DIR = "Vermilion/assets/dtype/"
local DTYPE_ICON = {}
local function map_icon(dt, file) if dt ~= nil then DTYPE_ICON[dt] = DT_ICON_DIR .. file end end
map_icon(zc.DAMAGE_TYPE_FIRE,     "fire.dds")
map_icon(zc.DAMAGE_TYPE_COLD,     "cold.dds")
map_icon(zc.DAMAGE_TYPE_SHOCK,    "shock.dds")
map_icon(zc.DAMAGE_TYPE_POISON,   "poison.dds")
map_icon(zc.DAMAGE_TYPE_DISEASE,  "disease.dds")
map_icon(zc.DAMAGE_TYPE_BLEED,    "bleed.dds")
map_icon(zc.DAMAGE_TYPE_PHYSICAL, "physical.dds")
map_icon(zc.DAMAGE_TYPE_MAGIC,    "magic.dds")
map_icon(zc.DAMAGE_TYPE_OBLIVION, "oblivion.dds")
map_icon(zc.DAMAGE_TYPE_EARTH,    "earth.dds")
map_icon(zc.DAMAGE_TYPE_DROWN,    "drown.dds")
map_icon(zc.DAMAGE_TYPE_GENERIC,  "generic.dds")
map_icon(zc.DAMAGE_TYPE_NONE,     "generic.dds")
DTYPE_ICON[-1] = "EsoUI/Art/Inventory/inventory_tabIcon_shield_up.dds"

local GetUIMousePosition = api.GetUIMousePosition
local hit = Vermilion.ChartHit.hit
local C_DIM_BIAS = 0.05
local render_current_view

local card_fader
local HC = Vermilion.HoverCard
local C_CARD_STAT = HC.C_STAT

local C_CROSSHAIR   = { r = 1.00, g = 0.38, b = 0.26, a = 0.85 }

local C_CRIT_BELOW = { r = 0.90, g = 0.32, b = 0.28, a = 1.0 }
M.KIND = { time = VIS.gold, damage = C_LINE_EDPS, shield = C_SHDPS, crit = C_CRIT, magicka = VIS.mag, stamina = VIS.sta, ultimate = VIS.ready, warn = C_CRIT_BELOW, neutral = C_CARD_STAT }

local fmt_secs = Format.secs

Pools.bind(controls)
local release_all_pools = Pools.release_all

local FC = Vermilion.FilmColumns
local dec_cols = FC.cols
local window_extent, grid_geometry = FC.window_extent, FC.grid_geometry

local make_fader, fade_in = Vermilion.Fader.new, Vermilion.Fader.show

local Hover = Vermilion.ChartHover
Hover.bind({
  STATE = STATE, controls = controls, VIS = VIS, CHIP = CHIP, hit = hit,
  DTYPE_ICON = DTYPE_ICON, ult_inset = ult_inset,
  VIEWS = VIEWS,
  C_LINE_EDPS = C_LINE_EDPS, C_SHDPS = C_SHDPS, C_CRIT = C_CRIT, C_VIEWPORT = C_VIEWPORT,
  render = function() render_current_view() end,
})
local stop_hover_poll, hide_hover_ui = Hover.stop_poll, Hover.hide_ui
local update_hover_gate = Hover.update_gate

local C_SUM = {
  AVG    = C_LINE_EOS,
  PEAK   = C_LINE_EDPS,
  CRIT   = C_CRIT,
  VAL    = { r = 0.95, g = 0.90, b = 0.90 },
  SHIELD = C_SHDPS,
  P90    = { r = 0.93, g = 0.76, b = 0.38 },
  MEDIAN = { r = 0.52, g = 0.80, b = 0.88 },
  P10    = { r = 0.66, g = 0.62, b = 0.86 },
}

local Report = Vermilion.ReportCard
Report.bind({
  controls = controls, VIS = VIS, DTYPE_ICON = DTYPE_ICON, C_SUM = C_SUM,
  C_LINE_EDPS = C_LINE_EDPS, C_LINE_EOS = C_LINE_EOS, C_SHDPS = C_SHDPS,
  C_CRIT = C_CRIT, C_CRIT_BELOW = C_CRIT_BELOW,
})

local Saving = Vermilion.Saving
M.export_summary, M.export_available, M.export_head = Saving.export_summary, Saving.export_available, Saving.export_head

local Chip = Vermilion.SummaryChip
Chip.bind({ controls = controls, CHIP = CHIP })
local update_summary_chip = Chip.update

local light = Vermilion.LightMode
light.bind({ controls = controls, VIS = VIS })

local FB = Vermilion.FilmBands
FB.bind({
  controls = controls, VIS = VIS, CHIP = CHIP, DTYPE_ICON = DTYPE_ICON,
  C_SHDPS = C_SHDPS, C_VIEWPORT = C_VIEWPORT, top_inset = top_inset, ult_inset = ult_inset,
})

local Overlay = Vermilion.ChartOverlay
Overlay.bind({ controls = controls, VIS = VIS })
VIS.scale_top, VIS.avg_line = Overlay.scale_top, Overlay.avg_line
VIS.hide_lines, VIS.median_line = Overlay.hide_lines, Overlay.median_line

local BARS = {
  STATE = STATE, controls = controls, VIS = VIS, CHIP = CHIP, top_inset = top_inset,
  C_DIM_BIAS = C_DIM_BIAS, C_NONCRIT = C_NONCRIT, C_CRIT = C_CRIT,
}
Vermilion.SkillView.bind(BARS)
Vermilion.TypeView.bind(BARS)
Vermilion.CritView.bind(BARS)

function render_current_view()
  Vermilion.Hitch.mark("render")
  Vermilion.Profiler.enter("graph.render")
  VIS.hide_lines()
  local view = VIEWS[STATE.view]
  local TB_film = Vermilion.TemporalBuffer
  Vermilion.FilmOverview.sync(view.bars and not TB_film.is_recording() and TB_film.count() >= 2)
  if view.bars then
    if controls.pool_viz_cd then controls.pool_viz_cd:ReleaseAllObjects() end
    if controls.pool_viz_line then controls.pool_viz_line:ReleaseAllObjects() end
    if controls.pool_c_seg then
      controls.pool_c_seg:ReleaseAllObjects()
      controls.pool_c_rim:ReleaseAllObjects()
      controls.pool_c_icon:ReleaseAllObjects()
      controls.pool_panel:ReleaseAllObjects()
      controls.pool_c_lbl:ReleaseAllObjects()
    end
    view.render()
    Vermilion.FilmOverview.draw()
  else
    release_all_pools()
    if view.bands then
      local _, _, max_sh = window_extent(Vermilion.TemporalBuffer.count())
      VIS.shield.on, VIS.shield.max = Vermilion.TemporalBuffer.count() > 0, max_sh
    end
    view.render()
  end
  Vermilion.Profiler.exit("graph.render")
end

M.save_available, M.pulse, M.pulse_lib = Saving.save_available, Saving.pulse, Saving.pulse_lib

function M.on_shown()
  if not controls.window or light.active then return end
  local f = controls.win_fader
  if not f then return end
  f.visible = false
  controls.window:SetAlpha(0)
  fade_in(f)
end

local RP = Vermilion.RecordPanel
M.refresh_record_button = RP.refresh_record_button
M.set_record_mode = RP.set_record_mode
M.toggle_auto_stop = RP.toggle_auto_stop
M.toggle_autosave = RP.toggle_autosave
M.record_panel_open = RP.record_panel_open
M.on_record_menu_click = RP.on_record_menu_click
M.record_panel_close = RP.record_panel_close

local function refresh_button_colors()
  local recording = Vermilion.TemporalBuffer.is_recording()
  controls.btn_record:SetEnabled(true)
  controls.btn_stop:SetEnabled(recording)
  M.refresh_record_button()
  if controls.btn_save then controls.btn_save:SetEnabled(M.save_available()) end
  if controls.btn_export then controls.btn_export:SetEnabled(M.export_available()) end
  if controls.btn_say then controls.btn_say:SetEnabled(M.export_available()) end
  update_hover_gate()
  update_summary_chip()
end
Saving.bind({
  controls = controls, REC = REC, refresh = refresh_button_colors,
  d = function(...) return d(...) end,
})

local function persist_view()
  local sv = Vermilion.SavedVars
  if sv then sv.graph = sv.graph or {} ; sv.graph.view_idx = STATE.view end
end

local Tabs = Vermilion.ViewTabs
local style_tabs, layout_tabs = Tabs.style, Tabs.layout

local function set_view(v)
  STATE.view = v
  controls.view_label:SetText(VIEW_LABELS[v])
  style_tabs()
  persist_view()
  STATE.hover_key = nil
  for i = 1, #VIEWS do
    local rows = VIEWS[i].rows
    if rows then
      rows.reset_scroll()
      rows.clear_hover()
    end
  end
  controls.no_data:SetText(GetString(VIEWS[v].empty or VERMILION_GRAPH_NO_DATA))
  controls.no_data:SetHidden(true)
  render_current_view()
  update_hover_gate()
end
Tabs.bind({
  STATE = STATE, controls = controls, VIEW_LABELS = VIEW_LABELS,
  release_all_pools = release_all_pools, set_view = set_view,
})

local Sampler = Vermilion.Sampler
Sampler.bind({ controls = controls, VIS = VIS, REC = REC, render = function() render_current_view() end })

function M.current_view() return STATE.view end

local Recorder = Vermilion.Recorder
Recorder.bind({
  STATE = STATE, controls = controls, VIS = VIS, CHIP = CHIP, REC = REC,
  refresh = refresh_button_colors, render = function() render_current_view() end,
  d = function(...) return d(...) end,
  saved = function() return Vermilion.SavedVars end,
})
M.on_record_click, M.on_stop_click, M.on_flush_click = Recorder.on_record_click, Recorder.on_stop_click, Recorder.on_flush_click

function M.on_close_click()
  Sound.play("close")
  M.record_panel_close()
  light.exit()
  Vermilion.Visibility.set("graph", false)
  stop_hover_poll(); hide_hover_ui(); STATE.hover_key = nil
  release_all_pools()
end

function M.on_move_stop()
  local sv = Vermilion.SavedVars
  if not sv then return end
  sv.graph = sv.graph or {}
  local x, y = controls.window:GetCenter()
  sv.graph.x = x
  sv.graph.y = y
end

function M.fit_chrome()
  local w, h = controls.window:GetDimensions()
  Vermilion.Skin.fit_chrome(VermilionGraphWindowChromeTop, VermilionGraphWindowChromeBottom,
    VermilionGraphWindowChromeLeft, VermilionGraphWindowChromeRight, w, h)
  controls.status:SetDimensionConstraints(0, 0, w - STATUS_ROW.LEFT - STATUS_ROW.RIGHT, 0)
end

function M.on_resize_start()
  M.on_move_start()
  controls.window:SetHandler("OnUpdate", M.fit_chrome)
end

function M.on_resize_stop()
  controls.window:SetHandler("OnUpdate", nil)
  M.fit_chrome()
  local sv = Vermilion.SavedVars
  if sv then
    sv.graph = sv.graph or {}
    local w, h = controls.window:GetDimensions()
    sv.graph.w = w
    sv.graph.h = h
  end
  layout_tabs()
  if not controls.window:IsHidden() then
    update_summary_chip()
    render_current_view()
  end
end

function M.card_state()
  local f = card_fader
  if not f then return "no card" end
  local root = f.control
  return string_format("hidden=%s alpha=%.2f flag=%s report=%s playing=%s over_chip=%s",
    tostring(root:IsHidden()), root:GetAlpha(), tostring(f.visible), tostring(f.report),
    tostring(f.anim:IsPlaying()), tostring(controls.summary ~= nil and api.MouseIsOver(controls.summary.hit)))
end

function M.rerender() render_current_view() end

function M.on_title_double_click()
  local _, my = GetUIMousePosition()
  if my - controls.window:GetTop() > 30 then return end
  local C = Vermilion.Constants
  local w, h = controls.window:GetDimensions()
  if w == C.GRAPH_DEFAULT_W and h == C.GRAPH_DEFAULT_H then return end
  Sound.play("click")
  controls.window:SetDimensions(C.GRAPH_DEFAULT_W, C.GRAPH_DEFAULT_H)
  M.on_resize_stop()
end

function M.on_move_start()
  stop_hover_poll()
  hide_hover_ui()
  if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
end

function M.pixel_grid()
  local g = dec_cols.grid
  if g == nil then g = (Vermilion.Constants.PIXEL_GRID ~= false) end
  return g
end

function M.set_pixel_grid(on)
  dec_cols.grid = on and true or false
  M.on_resize_stop()
end

function M.window_denom() return dec_cols.denom end
function M.column_pitch() return dec_cols.pitch end

function M.column_geometry(cw, denom, sc, base)
  return grid_geometry(cw, denom, sc or 1, base or 0)
end

function M.step_view(dir)
  if not controls.window or controls.window:IsHidden() then return false end
  if dir and dir < 0 then M.prev_view() else M.next_view() end
  return true
end

local Opened = Vermilion.Opened
Opened.bind({ controls = controls, load_session = function(sess) return M.load_session(sess) end })
M.step_session, M.loaded_session_index, M.refresh_loaded_status = Opened.step_session, Opened.loaded_session_index, Opened.refresh_loaded_status

function M.set_light_enabled(on)
  if not on then
    light.exit()
  elseif Vermilion.TemporalBuffer.is_recording() and not controls.window:IsHidden() then
    light.enter()
  end
end

function M.set_light_alpha(a)
  if light.active and not light.hover then
    controls.window:SetAlpha(a)
  end
end

function M.is_light_active() return light.active end

function M.prev_view()
  local v = STATE.view - 1
  if v < 1 then v = #VIEWS end
  Sound.play("page")
  release_all_pools()
  set_view(v)
end

function M.saved_view(idx)
  return VIEW_LABELS[idx] and idx or nil
end

function M.next_view()
  local v = STATE.view + 1
  if v > #VIEWS then v = 1 end
  Sound.play("page")
  release_all_pools()
  set_view(v)
end

function M.set_viewport_alpha(a)
  VermilionGraphWindowViewportBg:SetCenterColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, a)
end


function M.toggle()
  local now_visible = not Vermilion.Visibility.get("graph")
  log:info("toggle ->", now_visible and "show" or "hide")
  Vermilion.Visibility.set("graph", now_visible)
  Sound.play(now_visible and "open" or "close")
  if now_visible then
    render_current_view()
    update_hover_gate()
    if Vermilion.TemporalBuffer.is_recording() and light.enabled() then light.enter() end
  else
    light.exit()
    stop_hover_poll(); hide_hover_ui(); STATE.hover_key = nil
    release_all_pools()
  end
end


M.on_save_click = Saving.on_save_click

M.on_record_main_click, M.toggle_record, M.load_session = Recorder.on_record_main_click, Recorder.toggle_record, Recorder.load_session

local wire_save_hooks = Saving.wire

Vermilion.ChartDrag.bind({ STATE = STATE, controls = controls, render = function() render_current_view() end })

local ChartBuild = Vermilion.ChartBuild
ChartBuild.bind({
  STATE = STATE, controls = controls, VIS = VIS, CHIP = CHIP, DTYPE_ICON = DTYPE_ICON,
  top_inset = top_inset,
  C_LINE_EOS = C_LINE_EOS, C_CROSSHAIR = C_CROSSHAIR, C_SUM = C_SUM,
  KIND = M.KIND, render = function() render_current_view() end,
})

function M.init()
  controls.window        = VermilionGraphWindow
  controls.btn_record    = VermilionGraphWindowRecordBtn
  controls.btn_record_menu = VermilionGraphWindowRecordMenuBtn
  controls.rec_mode      = VermilionGraphWindowRecModeLabel
  controls.rec_panel     = VermilionRecPanel
  RP.bind(controls)
  controls.btn_stop      = VermilionGraphWindowStopBtn
  controls.btn_flush     = VermilionGraphWindowFlushBtn
  controls.btn_lib       = VermilionGraphWindowLibBtn
  controls.btn_prev_sess = VermilionGraphWindowPrevSessBtn
  controls.btn_next_sess = VermilionGraphWindowNextSessBtn
  controls.btn_save      = VermilionGraphWindowSaveBtn
  controls.btn_export    = VermilionGraphWindowExportBtn
  controls.btn_say       = VermilionGraphWindowSayBtn
  controls.status        = VermilionGraphWindowStatusLabel
  controls.btn_prev_view = VermilionGraphWindowPrevViewBtn
  controls.view_label    = VermilionGraphWindowViewLabel
  controls.btn_next_view = VermilionGraphWindowNextViewBtn
  controls.viewport      = VermilionGraphWindowViewport
  controls.canvas        = VermilionGraphWindowViewportCanvas
  FC.bind(controls.canvas)
  controls.no_data       = VermilionGraphWindowViewportNoDataLabel

  local sv = Vermilion.SavedVars
  sv.graph = sv.graph or {}
  STATE.view = M.saved_view(sv.graph.view_idx) or STATE.view
  if sv.graph.x then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.graph.x, sv.graph.y)
  end
  local C = Vermilion.Constants
  if sv.graph.w then
    controls.window:SetDimensions(math_max(sv.graph.w, C.GRAPH_MIN_W), math_max(sv.graph.h, C.GRAPH_MIN_H))
  end
  controls.window:SetDimensionConstraints(C.GRAPH_MIN_W, C.GRAPH_MIN_H, 1000, 700)

  VermilionGraphWindowBg:SetCenterColor(0, 0, 0, 0)
  local Skin = Vermilion.Skin
  Skin.chrome(VermilionGraphWindowChromeTop)
  Skin.chrome(VermilionGraphWindowChromeBottom)
  Skin.chrome(VermilionGraphWindowChromeLeft)
  Skin.chrome(VermilionGraphWindowChromeRight)
  Skin.chrome_light(VermilionGraphWindowChromeTop)
  Skin.frame(VermilionGraphWindowBg)
  VermilionGraphWindowBg:SetDrawLevel(2)
  M.fit_chrome()
  Skin.viewport(VermilionGraphWindowViewportBg)
  local sv_a = (sv.graph and sv.graph.viewport_alpha_pct) or 30
  VermilionGraphWindowViewportBg:SetCenterColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, sv_a / 100)

  ChartBuild.pools()

  controls.btn_record:SetText("|t16:16:Vermilion/assets/rec.dds|t " .. GetString(VERMILION_GRAPH_RECORD))
  controls.btn_record_menu:SetText("|t14:14:" .. Vermilion.Skin.CARET .. "|t")
  controls.rec_panel:ClearAnchors()
  controls.rec_panel:SetAnchor(TOPLEFT, controls.btn_record_menu, BOTTOMLEFT, -72, 4)
  controls.rec_panel:SetHidden(true)
  controls.status:SetMaxLineCount(1)
  controls.status:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  controls.rec_mode:SetColor(0.62, 0.62, 0.62, 1)
  if controls.rec_mode.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then controls.rec_mode:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
  controls.btn_stop:SetText("|t9:9:Vermilion/assets/stop.dds|t " .. GetString(VERMILION_GRAPH_STOP))
  controls.btn_flush:SetText(GetString(VERMILION_GRAPH_FLUSH))

  local function tint_btn(btn, r, g, b)
    btn:SetNormalFontColor(r, g, b, 1)
    btn:SetMouseOverFontColor(math.min(1, r + 0.12), math.min(1, g + 0.12), math.min(1, b + 0.12), 1)
    btn:SetPressedFontColor(r * 0.85, g * 0.85, b * 0.85, 1)
  end
  Vermilion.Skin.button(controls.btn_record, true)
  Vermilion.Skin.button(controls.btn_record_menu, true)
  Vermilion.Skin.button(controls.btn_stop)
  Vermilion.Skin.button(controls.btn_flush)
  Vermilion.Skin.button(VermilionGraphWindowSettingsBtn)
  Vermilion.Skin.close(VermilionGraphWindowCloseBtn)
  Vermilion.Skin.icons({ controls.btn_lib, controls.btn_save, controls.btn_export, controls.btn_say, controls.btn_prev_sess, controls.btn_next_sess })
  VermilionGraphWindowSettingsBtn:SetText(GetString(VERMILION_GRAPH_SETTINGS))
  VermilionGraphWindowAboutBtn:SetText(GetString(VERMILION_ABOUT_TITLE))
  Vermilion.Skin.button(VermilionGraphWindowAboutBtn)
  tint_btn(controls.btn_stop,   0.96, 0.80, 0.34)
  tint_btn(controls.btn_flush,  0.92, 0.46, 0.40)
  wire_save_hooks()
  M.refresh_record_button()

  Tabs.build(VermilionGraphWindowTabs)

  Chip.build()
  controls.status:SetText("")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)
  controls.no_data:SetText(GetString(VERMILION_GRAPH_NO_DATA))
  controls.no_data:SetColor(0.45, 0.45, 0.45, 1)
  controls.no_data:SetHidden(false)
  controls.view_label:SetText(VIEW_LABELS[STATE.view])
  controls.view_label:SetColor(0.75, 0.75, 0.75, 1)



  controls.card = HC.build(controls.window, controls.summary.hit, fmt_secs)
  card_fader = HC.fader()
  Report.attach(card_fader)
  Chip.attach(card_fader)
  controls.win_fader = make_fader(controls.window)
  controls.win_fader.visible = true

  ChartBuild.attach(card_fader)
  ChartBuild.layers()

  refresh_button_colors()
end
