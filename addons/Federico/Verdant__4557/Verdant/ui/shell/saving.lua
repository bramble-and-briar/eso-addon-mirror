Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Saving = {}
local M = Verdant.Saving

local zev           = Verdant.zenimax.events
local GetString     = Verdant.zenimax.api.GetString
local string_format = string.format
local Sound         = Verdant.Sound
local fmt_secs      = Verdant.Format.secs
local log           = Verdant.Log.for_module("saving")

local controls, STATE, d
local refresh_button_colors

function M.bind(t)
  controls, STATE, d = t.controls, t.STATE, t.d
  refresh_button_colors = t.refresh
end

function M.save_available()
  local TB = Verdant.TemporalBuffer
  local n = TB.count()
  if TB.is_recording() or n == 0 or controls.save_locked then return false end
  if not Verdant.SessionStore.has_work() then return false end
  return not (controls.saved_start == STATE.recording_start and controls.saved_count == n)
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

function M.pulse_lib() M.pulse(controls.btn_lib, "VerdantLibPulse") end

function M.on_save_click()
  local TB = Verdant.TemporalBuffer
  if TB.is_recording() then
    Sound.play("deny")
    d("[V] " .. GetString(VERDANT_SAVE_BUSY))
    return false
  end
  if TB.count() == 0 then
    Sound.play("deny")
    d("[V] " .. GetString(VERDANT_SAVE_NOTHING))
    return false
  end
  if not controls.save_locked and not Verdant.SessionStore.has_work() then
    Sound.play("deny")
    d("[V] " .. GetString(VERDANT_SAVE_EMPTY))
    return false
  end
  Verdant.SessionStore.finish_autosave()
  if not M.save_available() then
    Sound.play("deny")
    d("[V] " .. GetString(VERDANT_SAVE_ALREADY))
    return false
  end
  log:info("manual save")
  Sound.play("confirm")
  Verdant.SessionStore.save_now()
  Verdant.Diagnostics.bump("library.manual_save")
  return true
end

function M.wire()
  controls.saving_frames = { "SAVING", "SAVING ·", "SAVING · ·", "SAVING · · ·" }
  Verdant.SessionStore.on_save_begin = function()
    controls.saving_t = 0
    controls.status:SetText(controls.saving_frames[1])
    controls.status:SetColor(0.65, 0.65, 0.65, 1)
    if controls.btn_save then controls.btn_save:SetAlpha(0.45) end
    zev.register_update("VerdantSavingSpin", 150, function()
      local t = controls.saving_t + 1
      controls.saving_t = t
      controls.status:SetText(controls.saving_frames[(t % 4) + 1])
    end)
  end
  Verdant.SessionStore.on_save_end = function(stored)
    zev.unregister_update("VerdantSavingSpin")
    if controls.btn_save then controls.btn_save:SetAlpha(1) end
    if not stored then
      controls.status:SetText(GetString(VERDANT_SAVE_STATUS_UNSAVED))
      controls.status:SetColor(0.93, 0.72, 0.36, 1)
    end
  end
  Verdant.SessionStore.on_skipped = function()
    d("[V] " .. GetString(VERDANT_LIB_SKIPPED))
  end
  Verdant.SessionStore.on_saved = function(session)
    d("[V] " .. string_format(GetString(VERDANT_LIB_SAVED),
      Verdant.SessionStore.title(session.head), fmt_secs(session.head.dur_ms or 0)))
    controls.saved_start, controls.saved_count = STATE.recording_start, Verdant.TemporalBuffer.count()
    controls.status:SetText(string_format(GetString(VERDANT_SAVE_STATUS), Verdant.SessionStore.title(session.head)))
    controls.status:SetColor(0.65, 0.65, 0.65, 1)
    if session.head.manual then Sound.play("save") end
    refresh_button_colors()
    M.pulse_lib()
    if Verdant.Library and Verdant.Library.on_session_saved then
      Verdant.Library.on_session_saved(session.head.manual == true)
    end
  end
end
