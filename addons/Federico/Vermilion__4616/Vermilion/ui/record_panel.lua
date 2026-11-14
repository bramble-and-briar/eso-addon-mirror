Vermilion = Vermilion or {}
Vermilion.RecordPanel = {}
local M = Vermilion.RecordPanel

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local GetString = api.GetString
local Sound = Vermilion.Sound
local Radio = Vermilion.Radio
local WINDOW_MANAGER = zui.WINDOW_MANAGER
local CT_LABEL = zc.CT_LABEL
local TOPLEFT = zc.TOPLEFT
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER

local controls

function M.bind(c) controls = c end

local REC = { PULSE = "VermilionRecPulse" }

function REC.pulse_stop()
  zev.unregister_update(REC.PULSE)
  if controls.btn_record then controls.btn_record:SetAlpha(1) end
end

function REC.pulse_start()
  if controls.rec_pulsing then return end
  controls.rec_pulsing = true
  controls.rec_pulse_t = 0
  zev.register_update(REC.PULSE, 50, function()
    if not Vermilion.TemporalBuffer.is_recording() or controls.window:IsHidden() then
      controls.rec_pulsing = false
      REC.pulse_stop()
      return
    end
    local t = controls.rec_pulse_t + 50
    controls.rec_pulse_t = t
    controls.btn_record:SetAlpha(0.72 + 0.28 * math.abs(math.cos(t / 900 * math.pi)))
  end)
end

function REC.mode_tag(mode)
  if mode == "boss" then return GetString(VERMILION_REC_TAG_BOSS) end
  if mode == "combat" then return GetString(VERMILION_REC_TAG_COMBAT) end
  return GetString(VERMILION_REC_TAG_MANUAL)
end

function M.refresh_record_button()
  if not controls.btn_record then return end
  local recording = Vermilion.TemporalBuffer.is_recording()
  local mode = Vermilion.AutoRecord.get_mode()
  local word = recording and GetString(VERMILION_REC_RECORDING) or GetString(VERMILION_GRAPH_RECORD)
  controls.btn_record:SetText("|t16:16:Vermilion/assets/rec.dds|t " .. word)
  if controls.rec_mode then
    local tag = REC.mode_tag(mode)
    local extra = ""
    if mode == "off" and Vermilion.AutoRecord.get_auto_stop() then extra = extra .. " · " .. GetString(VERMILION_REC_TAG_AUTOSTOP) end
    local sv = Vermilion.SavedVars
    if sv and sv.settings and sv.settings.session_autosave then extra = extra .. " · " .. GetString(VERMILION_REC_TAG_AUTOSAVE) end
    controls.rec_mode:SetText(tag .. extra)
  end
  REC.refresh_panel()
  if recording and not controls.window:IsHidden() then
    REC.pulse_start()
  elseif not recording then
    controls.rec_pulsing = false
    REC.pulse_stop()
  end
end

function M.set_record_mode(mode)
  if not Vermilion.AutoRecord.set_mode(mode) then return false end
  Sound.play("page")
  M.refresh_record_button()
  return true
end

function M.toggle_auto_stop()
  local now = not Vermilion.AutoRecord.get_auto_stop()
  Vermilion.AutoRecord.set_auto_stop(now)
  Sound.play(now and "on" or "off")
  M.refresh_record_button()
  return now
end

function M.toggle_autosave()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not (sv.settings.session_autosave == true)
  sv.settings.session_autosave = now
  Sound.play(now and "on" or "off")
  M.refresh_record_button()
  return now
end

function REC.header(parent, y, text)
  local l = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
  l:SetFont("ZoFontGameSmall")
  l:SetAnchor(TOPLEFT, parent, TOPLEFT, 12, y)
  l:SetDimensions(54, 20)
  l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  l:SetColor(0.95, 0.42, 0.34, 0.9)
  l:SetText(text)
  return l
end

function REC.build_panel()
  local panel = controls.rec_panel
  if not panel or controls.rec_rows then return end
  if panel.SetDrawTier then panel:SetDrawTier(DT_HIGH) end
  if panel.SetDrawLayer and DL_OVERLAY then panel:SetDrawLayer(DL_OVERLAY) end
  local R = {}
  controls.rec_rows = R
  local x0, cw = 70, 86
  REC.header(panel, 12, GetString(VERMILION_RECPANEL_START))
  R.start_off   = Radio.new(panel, x0,          12, cw, GetString(VERMILION_RECPANEL_BY_HAND),   function() M.set_record_mode("off") end)
  R.start_any   = Radio.new(panel, x0 + cw,     12, cw, GetString(VERMILION_RECPANEL_ANY_FIGHT), function() M.set_record_mode("combat") end)
  R.start_boss  = Radio.new(panel, x0 + 2 * cw, 12, cw, GetString(VERMILION_RECPANEL_BOSS),      function() M.set_record_mode("boss") end)
  REC.header(panel, 40, GetString(VERMILION_RECPANEL_STOP))
  R.stop_hand   = Radio.new(panel, x0,          40, cw,     GetString(VERMILION_RECPANEL_BY_HAND),   function() if Vermilion.AutoRecord.get_auto_stop() then M.toggle_auto_stop() end end)
  R.stop_fight  = Radio.new(panel, x0 + cw,     40, 2 * cw, GetString(VERMILION_RECPANEL_FIGHT_END), function() if not Vermilion.AutoRecord.get_auto_stop() then M.toggle_auto_stop() end end)
  REC.header(panel, 68, GetString(VERMILION_RECPANEL_SAVE))
  R.save_hand   = Radio.new(panel, x0,          68, cw,     GetString(VERMILION_RECPANEL_BY_HAND),   function() local sv = Vermilion.SavedVars if sv.settings and sv.settings.session_autosave then M.toggle_autosave() end end)
  R.save_auto   = Radio.new(panel, x0 + cw,     68, 2 * cw, GetString(VERMILION_RECPANEL_ON_STOP),   function() local sv = Vermilion.SavedVars if not (sv.settings and sv.settings.session_autosave) then M.toggle_autosave() end end)
end

function REC.refresh_panel()
  local R = controls.rec_rows
  if not R then return end
  local mode = Vermilion.AutoRecord.get_mode()
  local auto_stop = Vermilion.AutoRecord.get_auto_stop()
  local sv = Vermilion.SavedVars
  local autosave = sv and sv.settings and sv.settings.session_autosave == true
  R.start_off.on, R.start_any.on, R.start_boss.on = (mode == "off"), (mode == "combat"), (mode == "boss")
  local manual_start = (mode == "off")
  R.stop_hand.enabled, R.stop_fight.enabled = manual_start, manual_start
  R.stop_hand.on  = manual_start and not auto_stop
  R.stop_fight.on = (not manual_start) or auto_stop
  R.save_hand.on, R.save_auto.on = not autosave, autosave
  for _, key in ipairs({ "start_off", "start_any", "start_boss", "stop_hand", "stop_fight", "save_hand", "save_auto" }) do Radio.paint(R[key]) end
end

function REC.inside(c, x, y)
  if not c or c:IsHidden() then return false end
  return x >= c:GetLeft() and x <= c:GetRight() and y >= c:GetTop() and y <= c:GetBottom()
end

function REC.away()
  local x, y = api.GetUIMousePosition()
  if REC.inside(controls.rec_panel, x, y) or REC.inside(controls.btn_record_menu, x, y) then return end
  M.record_panel_close()
end

function M.record_panel_open() return controls.rec_panel ~= nil and not controls.rec_panel:IsHidden() end

function M.on_record_menu_click()
  if not controls.rec_panel then return end
  if M.record_panel_open() then
    M.record_panel_close()
    Sound.play("close")
    return
  end
  REC.build_panel()
  REC.refresh_panel()
  controls.rec_panel:SetHidden(false)
  if zc.EVENT_GLOBAL_MOUSE_UP then zev.register("Vermilion_RecPanelAway", zc.EVENT_GLOBAL_MOUSE_UP, REC.away) end
  Sound.play("page")
end

function M.record_panel_close()
  if controls.rec_panel and not controls.rec_panel:IsHidden() then
    controls.rec_panel:SetHidden(true)
    if zc.EVENT_GLOBAL_MOUSE_UP then zev.unregister("Vermilion_RecPanelAway", zc.EVENT_GLOBAL_MOUSE_UP) end
  end
end
