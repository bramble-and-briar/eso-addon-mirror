Vermilion = Vermilion or {}
Vermilion.Saving = {}
local M = Vermilion.Saving

local api = Vermilion.zenimax.api
local zev = Vermilion.zenimax.events
local GetString     = api.GetString
local string_format = string.format

local log             = Vermilion.Log.for_module("graph")
local Sound           = Vermilion.Sound
local fmt_secs        = Vermilion.Format.secs
local session_summary = Vermilion.ReportCard.summary

local controls, REC, d
local refresh_button_colors

function M.bind(t)
  controls, REC, d = t.controls, t.REC, t.d
  refresh_button_colors = t.refresh
end

function M.export_summary() return session_summary() end

function M.export_available()
  local TB = Vermilion.TemporalBuffer
  return not TB.is_recording() and TB.count() > 0
end

function M.export_head()
  if controls.loaded_head then return controls.loaded_head end
  local zone, group = Vermilion.SessionStore.start_meta()
  local boss, top = Vermilion.SessionStore.live_names()
  local class, bars = Vermilion.SessionStore.live_build()
  return {
    zone = zone, group_size = math.max(group or 0, api.GetGroupSize() or 0), ts = api.GetTimeStamp(),
    dur_ms = Vermilion.SessionStore.live_duration(), boss = boss, top = top, class = class, bars = bars,
  }
end

function M.save_available()
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if TB.is_recording() or n == 0 or controls.save_locked then return false end
  local damage, shield = Vermilion.Metrics.totals()
  if damage + shield <= 0 then return false end
  return not (controls.saved_start == REC.start_ms and controls.saved_count == n)
end

function M.pulse(btn, name)
  if not btn then return end
  controls.pulse_t = controls.pulse_t or {}
  controls.pulse_t[name] = 0
  zev.register_update(name, 16, function()
    local t = controls.pulse_t[name] + 16
    controls.pulse_t[name] = t
    if t >= 720 then
      btn:SetAlpha(1)
      zev.unregister_update(name)
      return
    end
    btn:SetAlpha(0.35 + 0.65 * math.abs(math.cos((t % 360) / 360 * math.pi)))
  end)
end

function M.pulse_lib() M.pulse(controls.btn_lib, "VermilionLibPulse") end

function M.on_save_click()
  local TB = Vermilion.TemporalBuffer
  if TB.is_recording() then
    Sound.play("deny")
    d("[Vm] " .. GetString(VERMILION_SAVE_BUSY))
    return false
  end
  if TB.count() == 0 then
    Sound.play("deny")
    d("[Vm] " .. GetString(VERMILION_SAVE_NOTHING))
    return false
  end
  Vermilion.SessionStore.finish_autosave()
  if not M.save_available() then
    Sound.play("deny")
    d("[Vm] " .. GetString(VERMILION_SAVE_ALREADY))
    return false
  end
  log:info("manual save")
  Sound.play("confirm")
  Vermilion.SessionStore.save_now()
  Vermilion.Diagnostics.bump("library.manual_save")
  return true
end

local function wire_save_hooks()
  local SS = Vermilion.SessionStore
  controls.saving_frames = { "SAVING", "SAVING ·", "SAVING · ·", "SAVING · · ·" }
  SS.on_save_begin = function()
    controls.saving_t = 0
    controls.status:SetText(controls.saving_frames[1])
    controls.status:SetColor(0.65, 0.65, 0.65, 1)
    if controls.btn_save then controls.btn_save:SetAlpha(0.45) end
    zev.register_update("VermilionSavingSpin", 150, function()
      local t = controls.saving_t + 1
      controls.saving_t = t
      controls.status:SetText(controls.saving_frames[(t % 4) + 1])
    end)
  end
  SS.on_save_end = function(stored)
    zev.unregister_update("VermilionSavingSpin")
    if controls.btn_save then controls.btn_save:SetAlpha(1) end
    if not stored then
      controls.status:SetText(GetString(VERMILION_SAVE_STATUS_UNSAVED))
      controls.status:SetColor(0.93, 0.72, 0.36, 1)
    end
  end
  SS.on_saved = function(session)
    d("[Vm] " .. string_format(GetString(VERMILION_LIB_SAVED),
      SS.title(session.head), fmt_secs(session.head.dur_ms or 0)))
    controls.saved_start, controls.saved_count = REC.start_ms, Vermilion.TemporalBuffer.count()
    controls.status:SetText(string_format(GetString(VERMILION_SAVE_STATUS), SS.title(session.head)))
    controls.status:SetColor(0.65, 0.65, 0.65, 1)
    if session.head.manual then Sound.play("save") end
    refresh_button_colors()
    M.pulse_lib()
    if Vermilion.Library and Vermilion.Library.on_session_saved then
      Vermilion.Library.on_session_saved(session.head.manual == true)
    end
  end
end

M.wire = wire_save_hooks
