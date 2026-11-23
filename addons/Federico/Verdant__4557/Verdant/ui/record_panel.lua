Verdant = Verdant or {}
local Verdant = Verdant

Verdant.RecordPanel = {}
local M = Verdant.RecordPanel

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local zev = Verdant.zenimax.events
local GetString = api.GetString
local Sound = Verdant.Sound
local Skin  = Verdant.Skin
local Radio = Verdant.Radio

local PULSE, AWAY = "VerdantRecPulse", "Verdant_RecPanelAway"
local PULSE_MS, PULSE_PERIOD, PULSE_LOW = 50, 900, 0.72
local PANEL_DX, PANEL_DY = -72, 4
local ROW_TOP, ROW_GAP = 12, 28
local HEAD_X, HEAD_W, HEAD_H = 12, 54, 20
local FIRST_X, CELL_W = 70, 86
local REC_ICON = "|t16:16:Verdant/assets/rec.dds|t "

local controls
local rows
local pulsing, pulse_t = false, 0

function M.bind(c) controls = c end

local function pulse_stop()
  pulsing = false
  zev.unregister_update(PULSE)
  controls.btn_record:SetAlpha(1)
end

local function pulse_start()
  if pulsing then return end
  pulsing = true
  pulse_t = 0
  zev.register_update(PULSE, PULSE_MS, function()
    if not Verdant.TemporalBuffer.is_recording() or controls.window:IsHidden() then
      pulse_stop()
      return
    end
    pulse_t = pulse_t + PULSE_MS
    controls.btn_record:SetAlpha(PULSE_LOW + (1 - PULSE_LOW) * math.abs(math.cos(pulse_t / PULSE_PERIOD * math.pi)))
  end)
end

local function mode_tag(mode)
  if mode == "boss" then return GetString(VERDANT_REC_TAG_BOSS) end
  if mode == "combat" then return GetString(VERDANT_REC_TAG_COMBAT) end
  return GetString(VERDANT_REC_TAG_MANUAL)
end

local function refresh_rows()
  if not rows then return end
  local mode = Verdant.AutoRecord.get_mode()
  local by_hand = (mode == "off")
  local auto_stop = Verdant.AutoRecord.get_auto_stop()
  local autosave = Verdant.SessionStore.autosave_on()
  rows.StartOff.on, rows.StartAny.on, rows.StartBoss.on = by_hand, (mode == "combat"), (mode == "boss")
  rows.StopHand.enabled, rows.StopFight.enabled = by_hand, by_hand
  rows.StopHand.on  = by_hand and not auto_stop
  rows.StopFight.on = (not by_hand) or auto_stop
  rows.SaveHand.on, rows.SaveAuto.on = not autosave, autosave
  for _, r in pairs(rows) do Radio.paint(r) end
end

function M.refresh()
  local recording = Verdant.TemporalBuffer.is_recording()
  local mode = Verdant.AutoRecord.get_mode()
  controls.btn_record:SetText(REC_ICON .. GetString(recording and VERDANT_REC_RECORDING or VERDANT_GRAPH_RECORD))
  local tag = mode_tag(mode)
  if mode == "off" and Verdant.AutoRecord.get_auto_stop() then tag = tag .. " · " .. GetString(VERDANT_REC_TAG_AUTOSTOP) end
  if Verdant.SessionStore.autosave_on() then tag = tag .. " · " .. GetString(VERDANT_REC_TAG_AUTOSAVE) end
  controls.rec_mode:SetText(tag)
  refresh_rows()
  if recording and not controls.window:IsHidden() then
    pulse_start()
  elseif not recording then
    pulse_stop()
  end
end

function M.set_mode(mode)
  if not Verdant.AutoRecord.set_mode(mode) then return false end
  Sound.play("page")
  M.refresh()
  return true
end

function M.set_auto_stop(on)
  if Verdant.AutoRecord.get_auto_stop() == on then return end
  Verdant.AutoRecord.set_auto_stop(on)
  Sound.play(on and "on" or "off")
  M.refresh()
end

function M.set_autosave(on)
  if Verdant.SessionStore.autosave_on() == on then return end
  Verdant.SessionStore.set_autosave(on)
  Sound.play(on and "on" or "off")
  M.refresh()
end

local function header(name, y, string_id)
  local l = zui.WINDOW_MANAGER:CreateControl("VerdantRecPanel" .. name, controls.rec_panel, zc.CT_LABEL)
  l:SetFont("ZoFontGameSmall")
  l:SetAnchor(zc.TOPLEFT, controls.rec_panel, zc.TOPLEFT, HEAD_X, y)
  l:SetDimensions(HEAD_W, HEAD_H)
  l:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  l:SetText(GetString(string_id))
  Skin.label(l, "metal", 0.9)
end

local function choice(name, row, cell, cells, string_id, on_click)
  rows[name] = Radio.new("VerdantRecPanel" .. name, controls.rec_panel, FIRST_X + cell * CELL_W, ROW_TOP + row * ROW_GAP,
    cells * CELL_W, GetString(string_id), on_click)
end

local function build()
  if rows then return end
  rows = {}
  header("HeadStart", ROW_TOP, VERDANT_RECPANEL_START)
  choice("StartOff",  0, 0, 1, VERDANT_RECPANEL_BY_HAND,   function() M.set_mode("off") end)
  choice("StartAny",  0, 1, 1, VERDANT_RECPANEL_ANY_FIGHT, function() M.set_mode("combat") end)
  choice("StartBoss", 0, 2, 1, VERDANT_RECPANEL_BOSS,      function() M.set_mode("boss") end)
  header("HeadStop", ROW_TOP + ROW_GAP, VERDANT_RECPANEL_STOP)
  choice("StopHand",  1, 0, 1, VERDANT_RECPANEL_BY_HAND,   function() M.set_auto_stop(false) end)
  choice("StopFight", 1, 1, 2, VERDANT_RECPANEL_FIGHT_END, function() M.set_auto_stop(true) end)
  header("HeadSave", ROW_TOP + 2 * ROW_GAP, VERDANT_RECPANEL_SAVE)
  choice("SaveHand",  2, 0, 1, VERDANT_RECPANEL_BY_HAND,   function() M.set_autosave(false) end)
  choice("SaveAuto",  2, 1, 2, VERDANT_RECPANEL_ON_STOP,   function() M.set_autosave(true) end)
end

local function inside(c, x, y)
  return x >= c:GetLeft() and x <= c:GetRight() and y >= c:GetTop() and y <= c:GetBottom()
end

function M.is_open()
  return controls.rec_panel ~= nil and not controls.rec_panel:IsHidden()
end

function M.close()
  if not M.is_open() then return end
  controls.rec_panel:SetHidden(true)
  zev.unregister(AWAY, zc.EVENT_GLOBAL_MOUSE_UP)
end

local function away()
  local x, y = api.GetUIMousePosition()
  if inside(controls.rec_panel, x, y) or inside(controls.btn_record_menu, x, y) then return end
  M.close()
end

function M.on_menu_click()
  if M.is_open() then
    M.close()
    Sound.play("close")
    return
  end
  build()
  refresh_rows()
  controls.rec_panel:SetHidden(false)
  zev.register(AWAY, zc.EVENT_GLOBAL_MOUSE_UP, away)
  Sound.play("page")
end

function M.attach()
  local panel = controls.rec_panel
  panel:SetAnchor(zc.TOPLEFT, controls.btn_record_menu, zc.BOTTOMLEFT, PANEL_DX, PANEL_DY)
  panel:SetDrawTier(zc.DT_HIGH)
  panel:SetDrawLayer(zc.DL_OVERLAY)
  Skin.panel(VerdantRecPanelBg)
  Skin.button(controls.btn_record_menu, true)
  Skin.glyph(controls.btn_record_menu, "caret", 14)
  Skin.label(controls.rec_mode, "dim")
  controls.rec_mode:SetWrapMode(zc.TEXT_WRAP_MODE_ELLIPSIS)
  controls.status:SetMaxLineCount(1)
  controls.status:SetWrapMode(zc.TEXT_WRAP_MODE_ELLIPSIS)
end
