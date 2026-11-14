Vermilion = Vermilion or {}
Vermilion.Recorder = {}
local M = Vermilion.Recorder

local api = Vermilion.zenimax.api
local zev = Vermilion.zenimax.events
local GetGameTimeMilliseconds = api.GetGameTimeMilliseconds
local GetString               = api.GetString
local string_format           = string.format
local math_floor              = math.floor

local TICK_MS            = 1000
local log                = Vermilion.Log.for_module("graph")
local Sound              = Vermilion.Sound
local light              = Vermilion.LightMode
local RES                = Vermilion.FilmBands.RES
local release_all_pools  = Vermilion.ChartPools.release_all
local hide_grid          = Vermilion.ChartGrid.hide
local build_summary_text = Vermilion.ReportCard.text
local on_sample_update   = Vermilion.Sampler.tick

M.pulse                 = Vermilion.Saving.pulse
M.refresh_loaded_status = Vermilion.Opened.refresh_loaded_status

local STATE, controls, VIS, CHIP, REC, d, saved
local refresh_button_colors, render_current_view

function M.bind(t)
  STATE, controls, VIS, CHIP, REC = t.STATE, t.controls, t.VIS, t.CHIP, t.REC
  d, saved = t.d, t.saved
  refresh_button_colors, render_current_view = t.refresh, t.render
end

function M.on_record_click()
  if Vermilion.TemporalBuffer.is_recording() then return end
  Vermilion.Hitch.mark("start")
  Vermilion.Profiler.enter("graph.record_start")
  Vermilion.FilmWindow.reset()
  Vermilion.FilmOverview.sync(false)
  log:info("record click")
  Sound.play("record")
  if not Vermilion.AutoRecord.is_auto_active() then
    Vermilion.AutoRecord.notify_manual_record()
  end
  Vermilion.SessionStore.finish_autosave()
  controls.save_locked = false
  controls.loaded_sum = nil
  controls.loaded_head = nil
  Vermilion.Metrics.set_fight_ms(nil)
  controls.loaded_sess = nil
  controls.saved_start, controls.saved_count = nil, nil
  Vermilion.TemporalBuffer.clear()
  Vermilion.Metrics.session_mark(true)
  release_all_pools()
  hide_grid(controls.grid)
  VIS.hide_lines()
  controls.no_data:SetHidden(false)
  local sv       = saved()
  local temporal = sv and sv.temporal
  local rate     = (temporal and temporal.sample_rate_ms) or Vermilion.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT
  local interval = (rate > TICK_MS) and TICK_MS or rate
  REC.every = math_floor(rate / interval + 0.5)
  REC.tick  = 0
  REC.auto  = (temporal ~= nil and temporal.sample_auto == true and rate == TICK_MS)
  Vermilion.TemporalBuffer.start_recording(interval * REC.every)
  Vermilion.SessionStore.on_session_start()
  Vermilion.AutoRecord.on_session_start()
  Vermilion.Trace.on_record(saved())
  REC.start_ms = GetGameTimeMilliseconds()
  Vermilion.DebuffTracker.start_session(REC.start_ms)
  Vermilion.Ultimate.start_session(REC.start_ms)
  Vermilion.Resources.start_session()
  Vermilion.Casts.start_session()
  Vermilion.Uptime.start_session()
  Vermilion.Restores.start_session()
  VIS.res.on = false
  Vermilion.Kills.start_session()
  zev.register_update(Vermilion.Constants.TEMPORAL.UPDATE_NAME, interval, on_sample_update)
  CHIP.text = nil
  REC.last_elapsed = nil
  refresh_button_colors()
  controls.status:SetText("0:00")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)
  if light.enabled() then light.enter() end
  Vermilion.Metrics.adopt_opening(Vermilion.AutoRecord.opening_since(), Vermilion.Trace.on_adopted)
  Vermilion.Profiler.exit("graph.record_start")
end

function M.on_stop_click()
  if not Vermilion.TemporalBuffer.is_recording() then return end
  Vermilion.Hitch.mark("stop")
  Vermilion.Profiler.enter("graph.record_stop")
  log:info("stop click")
  Sound.play("stop")
  light.exit()
  Vermilion.AutoRecord.notify_manual_stop()
  Vermilion.TemporalBuffer.stop_recording()
  Vermilion.Pipeline.flush_pending(GetGameTimeMilliseconds(), true)
  Vermilion.Metrics.close_session()
  Vermilion.Trace.on_stop(saved())
  zev.unregister_update(Vermilion.Constants.TEMPORAL.UPDATE_NAME)
  Vermilion.DebuffTracker.finalize(GetGameTimeMilliseconds())
  Vermilion.Ultimate.finalize(GetGameTimeMilliseconds())
  Vermilion.Resources.finalize()
  Vermilion.Casts.finalize()
  Vermilion.Uptime.finalize()
  Vermilion.Restores.finalize()
  Vermilion.Kills.finalize()
  Vermilion.SessionStore.on_session_stop()
  CHIP.text = build_summary_text()
  if not Vermilion.SessionStore.autosave_pending() then
    controls.status:SetText(GetString(VERMILION_SAVE_STATUS_UNSAVED))
    controls.status:SetColor(0.93, 0.72, 0.36, 1)
    M.pulse(controls.btn_save, "VermilionSavePulse")
  end
  refresh_button_colors()
  render_current_view()
  Vermilion.Profiler.exit("graph.record_stop")
end

function M.on_flush_click()
  Vermilion.FilmWindow.reset()
  Vermilion.FilmOverview.sync(false)
  Sound.play("discard")
  Vermilion.SessionStore.finish_autosave()
  light.exit()
  Vermilion.AutoRecord.notify_manual_stop()
  CHIP.text = nil
  REC.last_elapsed = nil
  if Vermilion.TemporalBuffer.is_recording() then
    zev.unregister_update(Vermilion.Constants.TEMPORAL.UPDATE_NAME)
    Vermilion.TemporalBuffer.stop_recording()
  end
  Vermilion.TemporalBuffer.clear()
  Vermilion.DebuffTracker.reset()
  Vermilion.Ultimate.reset()
  Vermilion.Resources.reset()
  Vermilion.Casts.reset()
  Vermilion.Uptime.reset()
  Vermilion.Restores.reset()
  VIS.res.on = false
  Vermilion.Kills.reset()
  controls.save_locked = false
  controls.loaded_sum = nil
  controls.loaded_head = nil
  Vermilion.Metrics.session_mark()
  controls.loaded_sess = nil
  controls.saved_start, controls.saved_count = nil, nil
  release_all_pools()
  hide_grid(controls.grid)
  VIS.hide_lines()
  refresh_button_colors()
  controls.status:SetText("")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)
  controls.no_data:SetHidden(false)
end

function M.on_record_main_click()
  M.toggle_record()
end

function M.toggle_record()
  if Vermilion.TemporalBuffer.is_recording() then
    M.on_stop_click()
  else
    M.on_record_click()
  end
end

local function corrupt(reason)
  d("[Vm] " .. string_format(GetString(VERMILION_LIB_CORRUPT), tostring(reason)))
  return false
end

function M.load_session(sess)
  Vermilion.FilmWindow.reset()
  if Vermilion.TemporalBuffer.is_recording() then
    d("[Vm] " .. GetString(VERMILION_LIB_BUSY))
    return false
  end
  Vermilion.SessionStore.finish_autosave()
  Vermilion.Hitch.mark("load")
  Vermilion.Profiler.enter("graph.session_load")
  local dec, err = Vermilion.SessionStore.decode(sess)
  if not dec then
    Vermilion.Profiler.exit("graph.session_load")
    return corrupt(err)
  end

  release_all_pools()
  hide_grid(controls.grid)
  Vermilion.TemporalBuffer.load_session(dec.series, sess.head.cfg and sess.head.cfg.sample_rate_ms)
  Vermilion.FilmOverview.forget()
  VIS.res.on = RES.present()
  Vermilion.DebuffTracker.load_session(sess.debuffs or {}, dec.steps or {}, 0, sess.head.dur_ms or 0)
  if dec.ult then
    Vermilion.Ultimate.load_session(dec.ult, dec.ultu or {}, dec.ulta or {})
  else
    Vermilion.Ultimate.reset()
  end
  if dec.casts then Vermilion.Casts.load_session(dec.casts) else Vermilion.Casts.reset() end
  if dec.spans then
    Vermilion.Uptime.load_session(dec.spans, dec.press or {}, sess.head.uptime)
  else
    Vermilion.Uptime.reset()
  end
  if dec.restores then Vermilion.Restores.load_session(dec.restores, sess.head.regen) else Vermilion.Restores.reset() end
  Vermilion.Resources.load_session(dec.deaths)
  if dec.kills then Vermilion.Kills.load_session(dec.kills, 0) else Vermilion.Kills.reset() end
  STATE.hover_key = nil
  controls.loaded_sess = sess
  M.refresh_loaded_status()
  controls.save_locked = true
  controls.loaded_sum = sess.head.sum
  Vermilion.Metrics.set_fight_ms((sess.head.sum and sess.head.sum.fight_ms) or sess.head.dur_ms or 0, sess.head.sum and sess.head.sum.fight_t0, sess.head.sum and sess.head.sum.exact)
  controls.loaded_head = sess.head
  Vermilion.DamageNames.invalidate()
  CHIP.text = build_summary_text()
  controls.no_data:SetHidden(true)
  Vermilion.Visibility.set("graph", true)
  refresh_button_colors()
  render_current_view()
  Vermilion.Diagnostics.bump("library.session_loaded")
  Vermilion.Profiler.exit("graph.session_load")
  return true
end
