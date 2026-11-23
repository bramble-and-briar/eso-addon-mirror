Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Recorder = {}
local M = Verdant.Recorder

local api = Verdant.zenimax.api
local zev = Verdant.zenimax.events
local GetGameTimeMilliseconds = api.GetGameTimeMilliseconds
local GetString               = api.GetString
local math_floor    = math.floor
local math_min      = math.min
local string_format = string.format

local TICK_MS            = 1000
local HEX_TAG, HEX_REC   = "A6FFB8", "F5CC57"
local log                = Verdant.Log.for_module("recorder")
local Sound              = Verdant.Sound
local light              = Verdant.LightMode
local release_all_pools  = Verdant.ChartPools.release_all
local hide_all_grids     = Verdant.ChartGrid.hide_all
local build_summary_text = Verdant.SummaryChip.build
local on_sample_update   = Verdant.Sampler.tick

M.pulse = Verdant.Saving.pulse

local controls, STATE, report, d, saved
local refresh_button_colors, render_current_view

function M.bind(t)
  controls, STATE, report = t.controls, t.STATE, t.report
  d, saved = t.d, t.saved
  refresh_button_colors, render_current_view = t.refresh, t.render
end

function M.say_recording()
  d(string_format("|c%s[Verdant]|r |c%s%s|r", HEX_TAG, HEX_REC, GetString(VERDANT_CHAT_RECORDING)))
end

Verdant.Visibility.on_set(function(key, visible)
  if key == "graph" and not visible and Verdant.TemporalBuffer.is_recording() then M.say_recording() end
end)

function M.on_record_click()
  if Verdant.TemporalBuffer.is_recording() then return end
  Verdant.FilmWindow.reset()
  Verdant.FilmOverview.sync(false)
  log:info("record click")
  Sound.play("record")
  if not Verdant.AutoRecord.is_auto_active() then
    Verdant.AutoRecord.notify_manual_record()
  end
  STATE.summary = nil
  Verdant.SessionStore.finish_autosave()
  controls.save_locked = false
  controls.loaded_sess = nil
  controls.saved_start, controls.saved_count = nil, nil
  Verdant.TemporalBuffer.clear()
  Verdant.Metrics.reset()
  Verdant.Metrics.session_mark()
  report.hot, report.direct = 0, 0
  release_all_pools()
  hide_all_grids()
  controls.no_data:SetHidden(false)
  local temporal = saved().temporal
  local rate     = temporal.sample_rate_ms or Verdant.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT
  local interval = math_min(rate, TICK_MS)
  local every    = math_floor(rate / interval + 0.5)
  Verdant.Sampler.begin(every, temporal.sample_auto == true and rate == TICK_MS)
  Verdant.TemporalBuffer.start_recording(interval * every)
  Verdant.Trace.on_record(saved())
  STATE.recording_start = GetGameTimeMilliseconds()
  Verdant.BuffTracker.start_session(STATE.recording_start)
  Verdant.Ultimate.start_session(STATE.recording_start)
  Verdant.Resources.start_session()
  Verdant.Casts.start_session()
  Verdant.Restores.start_session()
  Verdant.AutoRecord.on_session_start()
  zev.register_update(Verdant.Constants.TEMPORAL.UPDATE_NAME, interval, on_sample_update)
  refresh_button_colors()
  controls.status:SetText("0:00")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)
  if light.enabled() then light.enter() end
  if not Verdant.Visibility.get("graph") then M.say_recording() end
end

function M.on_stop_click()
  if not Verdant.TemporalBuffer.is_recording() then return end
  log:info("stop click")
  Verdant.Hitch.mark("stop")
  Sound.play("stop")
  light.exit()
  Verdant.AutoRecord.notify_manual_stop()
  Verdant.AutoRecord.on_session_stop()
  Verdant.TemporalBuffer.stop_recording()
  Verdant.Trace.on_stop(saved())
  zev.unregister_update(Verdant.Constants.TEMPORAL.UPDATE_NAME)
  Verdant.BuffTracker.finalize(GetGameTimeMilliseconds())
  Verdant.Ultimate.finalize(GetGameTimeMilliseconds())
  Verdant.Resources.finalize()
  Verdant.Casts.finalize()
  Verdant.Restores.finalize()
  Verdant.SessionStore.on_session_stop()
  if not Verdant.SessionStore.has_work() then
    controls.status:SetText(GetString(VERDANT_SAVE_STATUS_EMPTY))
    controls.status:SetColor(0.65, 0.65, 0.65, 1)
  elseif not Verdant.SessionStore.autosave_pending() then
    controls.status:SetText(GetString(VERDANT_SAVE_STATUS_UNSAVED))
    controls.status:SetColor(0.93, 0.72, 0.36, 1)
    M.pulse(controls.btn_save, "VerdantSavePulse")
  end
  report.hot, report.direct = Verdant.Metrics.overheal_split()
  STATE.summary = build_summary_text()
  local s = Verdant.TemporalBuffer.summary()
  Verdant.Diagnostics.bump("graph.summary.computed")
  log:info("session summary: samples=", s.count, "dur_ms=", s.dur_ms,
           "avg_ems=", math_floor(s.avg_ems), "peak_ems=", math_floor(s.peak_ems),
           "wasted_pct=", math_floor(s.wasted_pct * 100 + 0.5),
           "crit_pct=", math_floor(s.crit_pct * 100 + 0.5))
  refresh_button_colors()
  render_current_view()
end

function M.load_session(sess)
  if Verdant.TemporalBuffer.is_recording() then
    d("[V] " .. GetString(VERDANT_LIB_BUSY))
    return false
  end
  Verdant.SessionStore.finish_autosave()
  local data, why = Verdant.SessionStore.decode(sess)
  if not data then
    d("[V] " .. string_format(GetString(VERDANT_LIB_CORRUPT), why))
    return false
  end

  release_all_pools()
  hide_all_grids()

  Verdant.FilmWindow.reset()
  Verdant.TemporalBuffer.load_session(data.series, data.markers, data.totals, data.sums, data.whole,
    sess.head.cfg and sess.head.cfg.sample_rate_ms, data.restores)
  Verdant.FilmOverview.forget()
  Verdant.BuffTracker.load_session(sess.buffs or {}, data.steps, 0, sess.head.dur_ms or 0)
  if data.ult then
    Verdant.Ultimate.load_session(data.ult.steps, data.ult.used, data.ult.abilities, sess.head.dur_ms)
  else
    Verdant.Ultimate.reset()
  end
  if data.casts then Verdant.Casts.load_session(data.casts) else Verdant.Casts.reset() end
  if data.regained then Verdant.Restores.load_session(data.regained, sess.head.regen) else Verdant.Restores.reset() end

  STATE.summary = build_summary_text()
  local hs = sess.head.sum or {}
  report.hot, report.direct = hs.oh_hot or 0, hs.oh_direct or 0
  controls.loaded_sess = sess
  Verdant.Opened.refresh_status()
  controls.save_locked = true
  Verdant.Visibility.set("graph", true)
  refresh_button_colors()
  render_current_view()
  Verdant.Diagnostics.bump("library.session_loaded")
  return true
end

function M.on_flush_click()
  Verdant.FilmWindow.reset()
  Verdant.FilmOverview.sync(false)
  Sound.play("discard")
  Verdant.SessionStore.finish_autosave()
  light.exit()
  if Verdant.TemporalBuffer.is_recording() then
    Verdant.AutoRecord.notify_discard()
    zev.unregister_update(Verdant.Constants.TEMPORAL.UPDATE_NAME)
    Verdant.TemporalBuffer.stop_recording()
  end
  Verdant.BuffTracker.reset()
  Verdant.Ultimate.reset()
  Verdant.Resources.reset()
  Verdant.Casts.reset()
  Verdant.Restores.reset()
  STATE.summary = nil
  Verdant.TemporalBuffer.clear()
  controls.save_locked = false
  controls.loaded_sess = nil
  controls.saved_start, controls.saved_count = nil, nil
  release_all_pools()
  hide_all_grids()
  refresh_button_colors()
  controls.status:SetText("")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)
  controls.no_data:SetText(GetString(VERDANT_GRAPH_NO_DATA))
  controls.no_data:SetHidden(false)
end

function M.toggle_record()
  if Verdant.TemporalBuffer.is_recording() then
    M.on_stop_click()
  else
    M.on_record_click()
  end
end
