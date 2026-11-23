Verdant = Verdant or {}
local Verdant = Verdant
Verdant.Graph = {}
local M = Verdant.Graph

local api   = Verdant.zenimax.api
local zui   = Verdant.zenimax.ui
local zc    = Verdant.zenimax.constants
local Sound = Verdant.Sound
local Skin  = Verdant.Skin
local log   = Verdant.Log.for_module("graph")
local GetString          = api.GetString
local GetUIMousePosition = api.GetUIMousePosition
local math_floor         = math.floor
local string_format      = string.format
local TOPLEFT            = zc.TOPLEFT
local CENTER             = zc.CENTER
local GuiRoot            = zc.GuiRoot

local C_EHPS      = { r = 0.55, g = 0.92, b = 0.62, a = 0.90 }
local C_MPS       = { r = 0.95, g = 0.68, b = 0.83, a = 0.90 }
local C_LINE_EHPS = { r = 0.65, g = 1.00, b = 0.72, a = 1.00 }
local C_LINE_EMS  = { r = 1.00, g = 0.78, b = 0.90, a = 1.00 }
local C_MEDIAN    = { r = 0.52, g = 0.80, b = 0.88, a = 1.00 }

local C_CRIT      = { r = 1.00, g = 0.85, b = 0.40, a = 0.96 }
local C_OVERHEAL  = { r = 0.64, g = 0.66, b = 0.58, a = 0.82 }
local C_RMAG      = { r = 0.38, g = 0.62, b = 0.98, a = 0.90 }
local C_RSTA      = { r = 0.52, g = 0.86, b = 0.36, a = 0.90 }
local C_DMG_TEXT  = { r = 0.93, g = 0.44, b = 0.38, a = 0.95 }
local C_DMG       = { r = 0.90, g = 0.38, b = 0.32, a = 0.85 }
local C_DMG_LABEL = { r = 1.00, g = 0.84, b = 0.80, a = 0.95 }
local C_STOP      = { r = 0.96, g = 0.80, b = 0.34 }
local STATUS_ROW  = { LEFT = 350, RIGHT = 60 }
local C_FLUSH     = { r = 0.90, g = 0.40, b = 0.36 }
local Overlay = Verdant.ChartOverlay

local C_VIEWPORT  = Verdant.lib.themes.tint("viewport")

local TIME_STRIP_H = Verdant.ChartGrid.TIME_STRIP_H
local ULT_L = { PAD = 4, ROW_H = 5, GAP = 9, ICON = 14, AREA = 28, CHIP = 0 }
local C_ULT_READY = { r = 1.00, g = 0.90, b = 0.30 }
local function ult_inset()
  return (Verdant.Ultimate.has_data() and ULT_L.AREA or 0) + ULT_L.CHIP
end

local controls = {}
Verdant.ChartPools.bind({ controls = controls })
Verdant.ChartGrid.bind({ controls = controls })

local VIEWS = Verdant.Views.list
local VIEW  = Verdant.Views.index
local STATE = { view = VIEW.EMS, recording_start = 0 }

local hit_main = { cols = {}, n = 0 }
local skill_legend = { n = 0, x0 = {}, x1 = {}, y0 = {}, y1 = {}, key = {} }
local buff_hit = { n = 0, y0 = {}, y1 = {}, rec = {}, lane_x = 0, lane_w = 0, t0 = 0, span = 0 }
local buff_vis = {}
local C_BUFF_FALLBACK = { r = 0.60, g = 0.63, b = 0.66, a = 0.95 }
local BUFF_FOLD = { PCT = 0.90, H = 24, ICON = 18, GAP = 3, MIN = 2, n = 0, x0 = {}, x1 = {}, rec = {}, y0 = 0, y1 = 0, on = false, scroll = 0, max_scroll = 0 }
local BUFF_SELF = { n = 0, x0 = {}, x1 = {}, rec = {}, y0 = 0, y1 = 0, on = false }

local function buff_color(rec)
  local SC = Verdant.SkillColors
  local g = SC.user_group(rec.id) or rec.group
  if g and g ~= "other" then
    return SC.group_color(g)
  end
  return Verdant.BuffOrigin.color(rec.id, rec.name) or C_BUFF_FALLBACK
end

local C_DIM_BIAS = 0.05
local render_current_view

local HoverCard = Verdant.HoverCard

local release_all_pools = Verdant.ChartPools.release_all

local SCR = { donut_vals = {}, donut_cols = {} }
HoverCard.bind({ controls = controls, SCR = SCR })

local Columns = Verdant.ChartColumns
Columns.bind({ controls = controls })
local dec_cols = Columns.cols
local grid_geometry = Columns.geometry

local fade_in = Verdant.Fader.show

local Hover = Verdant.ChartHover
local stop_hover_poll, hide_hover_ui = Hover.stop_poll, Hover.hide_ui

local Chip = Verdant.SummaryChip
local report = { hot = 0, direct = 0 }

Verdant.ReportCard.bind({ controls = controls, report = report,
  C_EHPS = C_EHPS, C_OVERHEAL = C_OVERHEAL, C_MEDIAN = C_MEDIAN, C_RMAG = C_RMAG, C_RSTA = C_RSTA })

Hover.bind({
  STATE = STATE, VIEW = VIEW, VIEWS = VIEWS, controls = controls, SCR = SCR, ULT_L = ULT_L,
  BUFF_FOLD = BUFF_FOLD, BUFF_SELF = BUFF_SELF, buff_hit = buff_hit,
  hit_main = hit_main,
  C_EHPS = C_EHPS, C_MPS = C_MPS, C_CRIT = C_CRIT, C_OVERHEAL = C_OVERHEAL, C_DMG_TEXT = C_DMG_TEXT,
  C_RMAG = C_RMAG, C_RSTA = C_RSTA,
  C_VIEWPORT = C_VIEWPORT, C_ULT_READY = C_ULT_READY,
  buff_color = buff_color,
  render = function() return render_current_view() end,
})
local update_hover_gate = Hover.update_gate

local light = Verdant.LightMode
light.bind({
  controls = controls,
  alpha_pct = function()
    local sv = Verdant.SavedVars
    return (sv and sv.settings and sv.settings.light_alpha_pct) or 40
  end,
  enabled = function()
    local sv = Verdant.SavedVars
    return (sv and sv.settings and sv.settings.light_mode) == true
  end,
})

Overlay.bind({ controls = controls, ULT_L = ULT_L, C_ULT_READY = C_ULT_READY, C_VIEWPORT = C_VIEWPORT })

local VIEW_SHARED = {
  controls = controls, hit_main = hit_main, ult_inset = ult_inset,
  STATE = STATE, ULT_L = ULT_L, C_DIM_BIAS = C_DIM_BIAS, skill_legend = skill_legend,
  C_HEAL_TITLE = C_LINE_EHPS, C_SHIELD_TITLE = C_LINE_EMS,
  BUFF_FOLD = BUFF_FOLD, BUFF_SELF = BUFF_SELF, buff_hit = buff_hit, buff_vis = buff_vis, buff_color = buff_color,
  buffs_unfolded = function() return M.buffs_unfolded() end,
  buffs_self_unfolded = function() return M.buffs_self_unfolded() end,
  C_EHPS = C_EHPS, C_MPS = C_MPS, C_DMG = C_DMG, C_DMG_LABEL = C_DMG_LABEL,
  C_CRIT = C_CRIT, C_OVERHEAL = C_OVERHEAL,
  C_RMAG = C_RMAG, C_RSTA = C_RSTA,
}
Verdant.EmsView.bind(VIEW_SHARED)

Verdant.SkillView.bind(VIEW_SHARED)

Verdant.ResourcesView.bind(VIEW_SHARED)

Verdant.OverhealView.bind(VIEW_SHARED)
Verdant.RestoreView.bind(VIEW_SHARED)

Verdant.BuffsView.bind(VIEW_SHARED)

function render_current_view()
  if controls.pool_marker_icon then
    controls.pool_marker_icon:ReleaseAllObjects()
  end
  local view = VIEWS[STATE.view]
  local TB = Verdant.TemporalBuffer
  Verdant.FilmOverview.sync(view.bars == true and not TB.is_recording() and TB.count() >= 2,
    view.side and view.side(controls.viewport:GetWidth()) or 0)
  hit_main.n = 0
  Overlay.hide_lines()
  if controls.side_hit then controls.side_hit:SetHidden(true) end
  if controls.pool_section then controls.pool_section:ReleaseAllObjects() end
  if controls.pool_res_seg then
    controls.pool_res_seg:ReleaseAllObjects()
    controls.pool_res_lbl:ReleaseAllObjects()
    controls.pool_res_icon:ReleaseAllObjects()
  end
  view.render()
  Verdant.FilmOverview.draw()
end

function M.rerender()
  if not controls.window:IsHidden() then render_current_view() end
end

Chip.bind({ controls = controls, STATE = STATE, ULT_L = ULT_L,
  C_LINE_EHPS = C_LINE_EHPS, C_LINE_EMS = C_LINE_EMS, C_CRIT = C_CRIT, C_OVERHEAL = C_OVERHEAL })
local update_summary_chip = Chip.update

local Saving = Verdant.Saving
M.save_available, M.pulse, M.pulse_lib = Saving.save_available, Saving.pulse, Saving.pulse_lib
M.on_save_click = Saving.on_save_click

function M.on_shown()
  if not controls.window or light.active then return end
  local f = controls.win_fader
  if not f then return end
  f.visible = false
  controls.window:SetAlpha(0)
  fade_in(f)
end

local function refresh_button_colors()
  local recording = Verdant.TemporalBuffer.is_recording()
  controls.btn_record:SetEnabled(true)
  M.refresh_record_button()
  controls.btn_stop:SetEnabled(recording)
  if controls.btn_save then controls.btn_save:SetEnabled(M.save_available()) end
  controls.btn_say:SetEnabled(M.fight_available())
  controls.btn_export:SetEnabled(M.fight_available())
  update_hover_gate()
  update_summary_chip()
end

Saving.bind({ controls = controls, STATE = STATE, d = d, refresh = refresh_button_colors })

local Tabs = Verdant.Tabs
local style_tabs, layout_tabs = Tabs.style, Tabs.layout

local function set_view(v)
  local view = VIEWS[v]
  STATE.view = v
  controls.view_label:SetText(view.label)
  style_tabs()
  STATE.hover_key = nil
  BUFF_FOLD.scroll = 0
  Verdant.ContribView.reset_scroll()
  Verdant.RestoreView.reset_scroll()
  Verdant.ResourcesView.reset_scroll()
  Verdant.ResourcesView.clear_hover()
  if controls.oh_legend then
    controls.oh_legend:SetHidden(not view.legend or Verdant.TemporalBuffer.count() == 0)
  end
  local empty_key = (Verdant.TemporalBuffer.count() == 0) and "VERDANT_GRAPH_NO_DATA" or (view.empty or "VERDANT_GRAPH_NO_DATA")
  controls.no_data:SetText(GetString(rawget(_G, empty_key)))

  if Verdant.TemporalBuffer.count() == 0 then
    controls.no_data:SetHidden(false)
    update_hover_gate()
    return
  end
  controls.no_data:SetHidden(true)

  render_current_view()
  update_hover_gate()
end

Tabs.bind({ controls = controls, STATE = STATE, set_view = set_view })

local Sampler = Verdant.Sampler
Sampler.bind({ controls = controls, STATE = STATE, render = function() return render_current_view() end })
Verdant.ChartDrag.bind({ controls = controls, STATE = STATE, render = function() return render_current_view() end })

local Recorder = Verdant.Recorder
Recorder.bind({
  controls = controls, STATE = STATE, report = report, d = d,
  saved = function() return Verdant.SavedVars end,
  refresh = refresh_button_colors,
  render = function() return render_current_view() end,
})
M.on_record_click, M.on_stop_click, M.on_flush_click = Recorder.on_record_click, Recorder.on_stop_click, Recorder.on_flush_click
M.load_session, M.toggle_record = Recorder.load_session, Recorder.toggle_record
M.on_record_main_click = Recorder.toggle_record
Verdant.Opened.bind({ controls = controls, load_session = function(sess) return M.load_session(sess) end })
M.step_session, M.loaded_session_index, M.refresh_loaded_status = Verdant.Opened.step, Verdant.Opened.index, Verdant.Opened.refresh_status

function M.fight_available()
  local TB = Verdant.TemporalBuffer
  return TB.count() > 0 and not TB.is_recording()
end

function M.fight_head()
  local sess = controls.loaded_sess
  if sess then return sess.head end
  return Verdant.SessionStore.recording_head()
end

function M.fight_name()
  local sess = controls.loaded_sess
  if sess then return Verdant.SessionStore.title(sess.head) end
  return Verdant.AutoRecord.session_boss() or Verdant.SessionStore.recording_zone()
end
Verdant.RecordPanel.bind(controls)
M.refresh_record_button, M.record_panel_open = Verdant.RecordPanel.refresh, Verdant.RecordPanel.is_open
M.on_record_menu_click, M.record_panel_close = Verdant.RecordPanel.on_menu_click, Verdant.RecordPanel.close

local ChartBuild = Verdant.ChartBuild
ChartBuild.bind({
  controls = controls, STATE = STATE, ULT_L = ULT_L, hit_main = hit_main,
  BUFF_FOLD = BUFF_FOLD, BUFF_SELF = BUFF_SELF, buff_hit = buff_hit, C_EHPS = C_EHPS, C_OVERHEAL = C_OVERHEAL, d = d,
  C_LINE_AVG = C_LINE_EHPS, C_MEDIAN = C_MEDIAN,
  toggle_buffs_fold = function() return M.toggle_buffs_fold() end,
  toggle_buffs_self = function() return M.toggle_buffs_self() end,
  render = function() return render_current_view() end,
})

function M.on_close_click()
  Sound.play("close")
  light.exit()
  Verdant.Visibility.set("graph", false)
  stop_hover_poll(); hide_hover_ui(); STATE.hover_key = nil
  release_all_pools()
end

function M.card_state()
  local f = controls.card_fader
  if not f then return "no card" end
  local root = f.control
  return string_format("hidden=%s alpha=%.2f flag=%s report=%s playing=%s over_chip=%s",
    tostring(root:IsHidden()), root:GetAlpha(), tostring(f.visible), tostring(f.report),
    tostring(f.anim:IsPlaying()), tostring(controls.summary ~= nil and api.MouseIsOver(controls.summary.hit)))
end

function M.on_title_double_click()
  local _, my = GetUIMousePosition()
  if my - controls.window:GetTop() > 30 then return end
  local C = Verdant.Constants
  local w, h = controls.window:GetDimensions()
  if w == C.GRAPH_DEFAULT_W and h == C.GRAPH_DEFAULT_H then return end
  Sound.play("click")
  controls.window:SetDimensions(C.GRAPH_DEFAULT_W, C.GRAPH_DEFAULT_H)
  M.on_resize_stop()
end

function M.fit_chrome()
  local w, h = controls.window:GetDimensions()
  Skin.fit_chrome(VerdantGraphWindowChromeTop, VerdantGraphWindowChromeBottom,
    VerdantGraphWindowChromeLeft, VerdantGraphWindowChromeRight, w, h)
  controls.status:SetDimensionConstraints(0, 0, w - STATUS_ROW.LEFT - STATUS_ROW.RIGHT, 0)
end

function M.on_resize_start()
  M.on_move_start()
  zui.handler(controls.window, "OnUpdate", M.fit_chrome)
end

function M.on_move_start()
  stop_hover_poll()
  hide_hover_ui()
  if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
end

function M.on_move_stop()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.temporal = sv.temporal or {}
  local x, y = controls.window:GetCenter()
  sv.temporal.graph_x = x
  sv.temporal.graph_y = y
end

function M.restore_place()
  local sv = Verdant.SavedVars
  sv.temporal = sv.temporal or {}
  if sv.temporal.graph_x then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.temporal.graph_x, sv.temporal.graph_y)
  end
  if sv.temporal.graph_w then
    controls.window:SetDimensions(math.max(sv.temporal.graph_w, Verdant.Constants.GRAPH_MIN_W),
      math.max(sv.temporal.graph_h, Verdant.Constants.GRAPH_MIN_H))
  end
end

function M.pixel_grid()
  local g = dec_cols.grid
  if g == nil then g = (Verdant.Constants.PIXEL_GRID ~= false) end
  return g
end

function M.set_pixel_grid(on)
  dec_cols.grid = on and true or false
  M.on_resize_stop()
end

function M.column_geometry(cw, denom, sc, base)
  return grid_geometry(cw, denom, sc or 1, base or 0)
end

function M.on_resize_stop()
  zui.handler(controls.window, "OnUpdate", nil)
  M.fit_chrome()
  local sv = Verdant.SavedVars
  if sv then
    sv.temporal = sv.temporal or {}
    local w, h = controls.window:GetDimensions()
    sv.temporal.graph_w = w
    sv.temporal.graph_h = h
  end
  layout_tabs()
  if not controls.window:IsHidden() then
    update_summary_chip()
    render_current_view()
  end
end

function M.toggle_buffs_fold()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.settings = sv.settings or {}
  sv.settings.buffs_unfolded = not (sv.settings.buffs_unfolded == true)
  Sound.play(sv.settings.buffs_unfolded and "on" or "off")
  hide_hover_ui(); STATE.hover_key = nil
  release_all_pools()
  render_current_view()
end

function M.buffs_unfolded()
  local sv = Verdant.SavedVars
  return sv and sv.settings and sv.settings.buffs_unfolded == true or false
end

function M.toggle_buffs_self()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.settings = sv.settings or {}
  sv.settings.buffs_self_unfolded = not (sv.settings.buffs_self_unfolded == true)
  Sound.play(sv.settings.buffs_self_unfolded and "on" or "off")
  hide_hover_ui(); STATE.hover_key = nil
  release_all_pools()
  render_current_view()
end

function M.buffs_self_unfolded()
  local sv = Verdant.SavedVars
  return sv and sv.settings and sv.settings.buffs_self_unfolded == true or false
end

function M.step_view(dir)
  if not controls.window or controls.window:IsHidden() then return false end
  Sound.play("page")
  if dir and dir < 0 then M.prev_view() else M.next_view() end
  return true
end

function M.prev_view()
  local v = STATE.view - 1
  if v < 1 then v = #VIEWS end
  release_all_pools()
  set_view(v)
end

function M.next_view()
  local v = STATE.view + 1
  if v > #VIEWS then v = 1 end
  release_all_pools()
  set_view(v)
end

function M.set_viewport_alpha(a)
  VerdantGraphWindowViewportBg:SetCenterColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, a)
end

function M.set_light_enabled(on)
  if not on then
    light.exit()
  elseif Verdant.TemporalBuffer.is_recording() and not controls.window:IsHidden() then
    light.enter()
  end
end

function M.set_light_alpha(a)
  if light.active and not light.hover then
    controls.window:SetAlpha(a)
  end
end

function M.is_light_active() return light.active end

function M.on_welcome_ok()
  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  sv.settings.welcomed = true
  Sound.play("confirm")
  if controls.welcome then controls.welcome:SetHidden(true) end
end

function M.toggle()
  local now_visible = not Verdant.Visibility.get("graph")
  log:info("toggle ->", now_visible and "show" or "hide")
  Verdant.Visibility.set("graph", now_visible)
  Sound.play(now_visible and "open" or "close")
  if now_visible then
    local sv = Verdant.SavedVars
    if controls.welcome and not (sv.settings and sv.settings.welcomed) then
      controls.welcome:SetHidden(false)
    end
    render_current_view()
    update_hover_gate()
    if Verdant.TemporalBuffer.is_recording() and light.enabled() then light.enter() end
  else
    stop_hover_poll(); hide_hover_ui(); STATE.hover_key = nil
    release_all_pools()
  end
end

function M.init()
  controls.window        = VerdantGraphWindow
  controls.btn_record    = VerdantGraphWindowRecordBtn
  controls.btn_record_menu = VerdantGraphWindowRecordMenuBtn
  controls.rec_mode      = VerdantGraphWindowRecModeLabel
  controls.rec_panel     = VerdantRecPanel
  controls.btn_prev_sess = VerdantGraphWindowPrevSessBtn
  controls.btn_next_sess = VerdantGraphWindowNextSessBtn
  controls.btn_say       = VerdantGraphWindowSayBtn
  controls.btn_export    = VerdantGraphWindowExportBtn
  controls.btn_stop      = VerdantGraphWindowStopBtn
  controls.btn_flush     = VerdantGraphWindowFlushBtn
  controls.btn_lib       = VerdantGraphWindowLibBtn
  controls.btn_save      = VerdantGraphWindowSaveBtn
  controls.status        = VerdantGraphWindowStatusLabel
  controls.btn_prev_view = VerdantGraphWindowPrevViewBtn
  controls.view_label    = VerdantGraphWindowViewLabel
  controls.btn_next_view = VerdantGraphWindowNextViewBtn
  controls.viewport      = VerdantGraphWindowViewport
  controls.canvas        = VerdantGraphWindowViewportCanvas
  controls.no_data       = VerdantGraphWindowViewportNoDataLabel

  M.restore_place()

  controls.window:SetDimensionConstraints(Verdant.Constants.GRAPH_MIN_W, Verdant.Constants.GRAPH_MIN_H,
    Verdant.Constants.GRAPH_MAX_W, Verdant.Constants.GRAPH_MAX_H)

  VerdantGraphWindowBg:SetCenterColor(0, 0, 0, 0)
  Skin.chrome(VerdantGraphWindowChromeTop)
  Skin.chrome(VerdantGraphWindowChromeBottom)
  Skin.chrome(VerdantGraphWindowChromeLeft)
  Skin.chrome(VerdantGraphWindowChromeRight)
  Skin.chrome_light(VerdantGraphWindowChromeTop)
  Skin.frame(VerdantGraphWindowBg)
  VerdantGraphWindowBg:SetDrawLevel(2)
  M.fit_chrome()
  Skin.viewport(VerdantGraphWindowViewportBg)

  local function paint_viewport()
    local sv_a = (Verdant.SavedVars and Verdant.SavedVars.temporal
                  and Verdant.SavedVars.temporal.viewport_alpha_pct) or 30
    VerdantGraphWindowViewportBg:SetCenterColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, sv_a / 100)
  end
  paint_viewport()
  Verdant.BuffCatalog.on_done(M.rerender)
  Verdant.lib.themes.on_change(function()
    paint_viewport()
    if controls.crosshair then controls.crosshair:SetColor(controls.crosshair_c.r, controls.crosshair_c.g, controls.crosshair_c.b, controls.crosshair_c.a) end
    if not controls.window:IsHidden() then render_current_view() end
  end)

  ChartBuild.pools()


  controls.view_label:SetMouseEnabled(true)
  zui.handler(controls.view_label, "OnMouseUp", function(_, button, upInside)
    if upInside == false then return end
    Sound.play("page")
    if button == zc.MOUSE_BUTTON_INDEX_RIGHT then M.prev_view() else M.next_view() end
  end)

  Tabs.build()

  Saving.wire()

  controls.welcome = VerdantGraphWindowWelcome
  Skin.panel(VerdantGraphWindowWelcomeBg)
  Skin.button(VerdantGraphWindowWelcomeOkBtn, true)
  VerdantGraphWindowWelcomeTitle:SetText(GetString(VERDANT_WELCOME_TITLE))
  VerdantGraphWindowWelcomeTitle:SetColor(0.46, 0.86, 0.58, 1)
  VerdantGraphWindowWelcomeBody:SetText(GetString(VERDANT_WELCOME_BODY))
  VerdantGraphWindowWelcomeBody:SetColor(0.88, 0.92, 0.88, 1)
  VerdantGraphWindowWelcomeOkBtn:SetText(GetString(VERDANT_WELCOME_OK))
  controls.welcome:SetDrawLevel(30)

  controls.btn_stop:SetText("|t9:9:Verdant/assets/stop.dds|t " .. GetString(VERDANT_GRAPH_STOP))
  controls.btn_flush:SetText(GetString(VERDANT_GRAPH_FLUSH))

  Skin.button(controls.btn_record, true)
  Verdant.RecordPanel.attach()
  Skin.button(controls.btn_stop, false, C_STOP)
  Skin.button(controls.btn_flush, false, C_FLUSH)
  Skin.button(VerdantGraphWindowSettingsBtn)
  Skin.button(VerdantGraphWindowAboutBtn)
  Skin.close(VerdantGraphWindowCloseBtn)
  Skin.icon(controls.btn_lib, "lib")
  Skin.icon(controls.btn_save, "save")
  Skin.icon(controls.btn_prev_sess, "arrow_left")
  Skin.icon(controls.btn_next_sess, "arrow_right")
  Skin.icon(controls.btn_say, "say")
  Skin.icon(controls.btn_export, "export")
  VerdantGraphWindowSettingsBtn:SetText(GetString(VERDANT_GRAPH_SETTINGS))
  VerdantGraphWindowAboutBtn:SetText(GetString(VERDANT_ABOUT_TITLE))

  controls.status:SetText("")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)

  controls.no_data:SetText(GetString(VERDANT_GRAPH_NO_DATA))
  controls.no_data:SetColor(0.45, 0.45, 0.45, 1)
  controls.no_data:SetHidden(false)

  controls.view_label:SetText(VIEWS[STATE.view].label)
  controls.view_label:SetColor(0.75, 0.75, 0.75, 1)

  Chip.create()

  ChartBuild.layers()

  refresh_button_colors()
end
