Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.AutoRecord = {}
local M = Vermilion.AutoRecord

local log = Vermilion.Log.for_module("auto_record")

local MODE_OFF    = "off"
local MODE_BOSS   = "boss"
local MODE_COMBAT = "combat"

local MODES = { MODE_OFF, MODE_BOSS, MODE_COMBAT }

local GRACE_MS  = 5000
local OPENING_MS = 1000
local TICK_MS   = 1000
local TICK_NAME = "VermilionAutoRecTick"
local HIST_CAP  = 12

local mode           = MODE_OFF
local in_combat      = false
local boss_present   = false
local boss_name      = nil
local auto_active    = false
local session_auto   = false
local grace_deadline = nil
local opening_since  = nil
local hist           = {}
local hist_n         = 0
local zone_id        = nil

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function now_ms()
  return Vermilion.zenimax.api.GetGameTimeMilliseconds()
end

local tick

local function push_hist(what)
  hist_n = hist_n + 1
  local slot = ((hist_n - 1) % HIST_CAP) + 1
  local rec = hist[slot]
  if not rec then rec = {}; hist[slot] = rec end
  rec.t = now_ms()
  rec.what = what
end

local function scan_bosses()
  local api = Vermilion.zenimax.api
  local zc  = Vermilion.zenimax.constants
  local found, name = false, nil
  for i = zc.BOSS_RANK_ITERATION_BEGIN, zc.BOSS_RANK_ITERATION_END do
    local tag = "boss" .. i
    if api.DoesUnitExist(tag) then
      found = true
      if name == nil then name = api.GetUnitName(tag) end
    end
  end
  return found, name
end

local function auto_stop_on()
  local sv = Vermilion.SavedVars
  return sv and sv.settings and sv.settings.auto_stop == true or false
end

local function stop_wanted()
  return auto_active or (auto_stop_on() and not in_combat)
end

local function sync_tick()
  local zev = Vermilion.zenimax.events
  if mode ~= MODE_OFF or auto_stop_on() then
    zev.register_update(TICK_NAME, TICK_MS, tick)
  else
    zev.unregister_update(TICK_NAME)
    grace_deadline = nil
  end
end

local function should_record()
  if mode == MODE_COMBAT then return in_combat end
  if mode == MODE_BOSS then return in_combat and boss_present end
  return false
end

local function try_start()
  local TB = Vermilion.TemporalBuffer
  if TB.is_recording() then
    bump("autorec.blocked_recording")
    return
  end
  if TB.count() > 0 and not session_auto then
    bump("autorec.blocked_manual_session")
    push_hist("blocked_manual_session")
    log:info("auto-start blocked: manual frozen session present")
    return
  end
  bump("autorec.start")
  push_hist(boss_present and ("start boss=" .. tostring(boss_name)) or "start combat")
  log:info("auto-start", boss_present and boss_name or "combat")
  if opening_since then Vermilion.Pipeline.flush_pending(now_ms(), true) end
  Vermilion.Graph.on_record_click()
  auto_active  = true
  session_auto = true
end

local function do_stop(reason)
  bump("autorec.stop_" .. reason)
  push_hist("stop " .. reason)
  log:info("auto-stop:", reason)
  auto_active    = false
  grace_deadline = nil
  Vermilion.Graph.on_stop_click()
end

local function evaluate()
  if mode == MODE_OFF and not auto_stop_on() then return end
  if should_record() or (in_combat and grace_deadline and not auto_active) then
    if grace_deadline then
      bump("autorec.grace_cancelled")
      push_hist("grace cancelled")
      grace_deadline = nil
    end
    if should_record() and not Vermilion.TemporalBuffer.is_recording() then
      try_start()
    end
  else
    if stop_wanted() and Vermilion.TemporalBuffer.is_recording() and grace_deadline == nil then
      grace_deadline = now_ms() + GRACE_MS
      push_hist("grace armed")
      bump("autorec.grace_armed")
    end
  end
end

function M.on_combat_state(inCombat)
  local was = in_combat
  in_combat = inCombat and true or false
  bump(in_combat and "autorec.combat_in" or "autorec.combat_out")
  if in_combat and not was then opening_since = now_ms() - OPENING_MS end
  evaluate()
  opening_since = nil
end

function M.opening_since() return opening_since end

local session_bosses = {}

local function note_session_bosses()
  local api = Vermilion.zenimax.api
  local zc  = Vermilion.zenimax.constants
  for i = zc.BOSS_RANK_ITERATION_BEGIN, zc.BOSS_RANK_ITERATION_END do
    local tag = "boss" .. i
    if api.DoesUnitExist(tag) then
      local name = api.GetUnitName(tag)
      if name and name ~= "" then session_bosses[name] = true end
    end
  end
end

function M.on_session_start()
  for k in pairs(session_bosses) do session_bosses[k] = nil end
  note_session_bosses()
end

function M.session_bosses() return session_bosses end

function M.on_bosses_changed()
  if Vermilion.TemporalBuffer.is_recording() then note_session_bosses() end
  local found, name = scan_bosses()
  bump("autorec.bosses_changed")
  if found ~= boss_present then
    bump(found and "autorec.boss_appeared" or "autorec.boss_cleared")
    push_hist(found and ("boss+ " .. tostring(name)) or "boss-")
    log:info("boss roster:", found and name or "(cleared)")
  end
  boss_present = found
  boss_name    = name
  evaluate()
end

local function current_zone()
  local api = Vermilion.zenimax.api
  if not api.GetZoneId or not api.GetUnitZoneIndex then return nil end
  local idx = api.GetUnitZoneIndex("player")
  if not idx then return nil end
  local z = api.GetZoneId(idx)
  if not z or z <= 0 then return nil end
  return z
end

function M.on_zone_changed()
  local z = current_zone()
  local same = z ~= nil and z == zone_id
  zone_id = z
  if same then
    bump("autorec.same_zone")
    push_hist("activated in the same zone")
    if mode == MODE_OFF and not auto_stop_on() then return end
    in_combat = Vermilion.zenimax.api.IsUnitInCombat("player") and true or false
    boss_present, boss_name = scan_bosses()
    evaluate()
    return
  end
  if auto_active and Vermilion.TemporalBuffer.is_recording() then
    do_stop("zone")
  end
  in_combat    = false
  boss_present = false
  boss_name    = nil
  grace_deadline = nil
end

function tick()
  if mode == MODE_OFF and not auto_stop_on() then return end
  local api = Vermilion.zenimax.api
  local live = api.IsUnitInCombat("player") and true or false
  if live ~= in_combat then
    bump("autorec.combat_poll_fix")
    in_combat = live
    evaluate()
  end
  if grace_deadline and now_ms() >= grace_deadline then
    if stop_wanted() and Vermilion.TemporalBuffer.is_recording() then
      do_stop(auto_active and "grace" or "combat_end")
    else
      grace_deadline = nil
    end
  end
end

function M.notify_manual_record()
  auto_active    = false
  session_auto   = false
  grace_deadline = nil
end

function M.notify_manual_stop()
  if auto_active then
    bump("autorec.manual_stop_override")
    push_hist("manual stop")
  end
  auto_active    = false
  grace_deadline = nil
end

function M.is_auto_session() return session_auto end
function M.is_auto_active()  return auto_active end
function M.get_mode()        return mode end
function M.modes()           return MODES end

function M.set_mode(m)
  local valid = false
  for i = 1, #MODES do
    if MODES[i] == m then valid = true break end
  end
  if not valid then return false end
  if m == mode then return true end
  log:info("mode:", mode, "->", m)
  push_hist("mode " .. m)
  mode = m
  Vermilion.Metrics.hold_opening(mode ~= MODE_OFF)
  if mode == MODE_OFF then
    if auto_active and Vermilion.TemporalBuffer.is_recording() then
      do_stop("disabled")
    end
    grace_deadline = nil
    sync_tick()
  else
    sync_tick()
    local found, name = scan_bosses()
    boss_present = found
    boss_name    = name
    in_combat    = Vermilion.zenimax.api.IsUnitInCombat("player") and true or false
    evaluate()
  end
  local sv = Vermilion.SavedVars
  if sv then
    sv.settings = sv.settings or {}
    sv.settings.auto_record = mode
  end
  return true
end

function M.set_auto_stop(on)
  local sv = Vermilion.SavedVars
  if not sv then return false end
  sv.settings = sv.settings or {}
  on = on and true or false
  if sv.settings.auto_stop == on then return true end
  sv.settings.auto_stop = on
  log:info("auto_stop:", on)
  push_hist(on and "auto_stop on" or "auto_stop off")
  if on then
    in_combat = Vermilion.zenimax.api.IsUnitInCombat("player") and true or false
  end
  sync_tick()
  if on then evaluate() end
  return true
end

function M.get_auto_stop() return auto_stop_on() end

function M.report_lines()
  local lines = {}
  lines[#lines + 1] = string.format(
    "mode=%s  auto_stop=%s  state=%s  in_combat=%s  boss=%s  grace=%s",
    mode, tostring(auto_stop_on()),
    auto_active and (grace_deadline and "GRACE" or "RECORDING") or "IDLE",
    tostring(in_combat),
    boss_present and tostring(boss_name) or "none",
    grace_deadline and string.format("%.1fs", (grace_deadline - now_ms()) / 1000) or "-")
  local n_show = (hist_n < HIST_CAP) and hist_n or HIST_CAP
  for i = hist_n - n_show + 1, hist_n do
    local rec = hist[((i - 1) % HIST_CAP) + 1]
    lines[#lines + 1] = string.format("t=%d  %s", rec.t, rec.what)
  end
  if hist_n == 0 then lines[#lines + 1] = "(no transitions yet)" end
  return lines
end

function M.snapshot()
  return {
    mode = mode, in_combat = in_combat, boss_present = boss_present,
    boss_name = boss_name, auto_active = auto_active,
    session_auto = session_auto, grace_deadline = grace_deadline,
    transitions = hist_n,
  }
end

function M.init()
  local sv = Vermilion.SavedVars
  local zev = Vermilion.zenimax.events
  local zc  = Vermilion.zenimax.constants

  zev.register("Vermilion_AR_Combat", zc.EVENT_PLAYER_COMBAT_STATE, function(inCombat)
    M.on_combat_state(inCombat)
  end)
  zev.register("Vermilion_AR_Bosses", zc.EVENT_BOSSES_CHANGED, M.on_bosses_changed)
  zev.register("Vermilion_AR_Zone", zc.EVENT_PLAYER_ACTIVATED, M.on_zone_changed)
  zone_id = current_zone()

  local saved = sv and sv.settings and sv.settings.auto_record or MODE_OFF
  mode = MODE_OFF
  M.set_mode(saved)
  sync_tick()
  log:info("init: mode=", mode)
end
