Verdant = Verdant or {}
local Verdant = Verdant
Verdant.TemporalBuffer = {}
local M = Verdant.TemporalBuffer

local math_floor = math.floor
local log        = Verdant.Log.for_module("temporal_buffer")

local state = {
  data      = {},
  capacity  = 0,
  base      = 0,
  write     = 1,
  count     = 0,
  recording = false,
  period    = 1000,
  forgot    = 0,
  totals    = nil,
  sums      = nil,
  whole     = nil,
  restores  = nil,
}

local run = { n = 0, active = 0, peak = 0, peak_t = 0 }

local RLOG_CAP = 8192
local rlog = { n = 0, t = {}, id = {}, mag = {}, who = {}, amt = {}, names = {}, index = {} }

local function clear_rlog()
  rlog.n = 0
  for i = #rlog.names, 1, -1 do
    rlog.index[rlog.names[i]] = nil
    rlog.names[i] = nil
  end
end

local function receiver(name)
  name = tostring(name or ""):gsub("%^.*$", "")
  local who = rlog.index[name]
  if not who then
    who = #rlog.names + 1
    rlog.names[who] = name
    rlog.index[name] = who
  end
  return who
end

local function log_restore(t, id, mag, name, amount)
  if rlog.n >= RLOG_CAP then return false end
  local n = rlog.n + 1
  rlog.n = n
  rlog.t[n], rlog.id[n], rlog.mag[n], rlog.who[n], rlog.amt[n] = t, id, mag, receiver(name), amount
  return true
end

function M.add_restore(t, id, mag, name, amount)
  if not state.recording then return false end
  if not log_restore(t, id, mag, name, amount) then
    Verdant.Diagnostics.bump("film.restore_log_full")
    return false
  end
  return true
end

function M.restore_log() return rlog end
M.RLOG_CAP = RLOG_CAP

function M.init(capacity)
  capacity       = math_floor(capacity)
  if capacity < 1 then capacity = 1 end
  state.capacity = capacity
  state.base     = capacity
  state.write    = 1
  state.count    = 0
  state.forgot   = 0
  state.data     = {}
  for i = 1, capacity do
    state.data[i] = { t = 0, eHPS = 0, MPS = 0, crit = 0, noncrit = 0, d = 0, o = 0, rm = 0, rs = 0,
                      mag = 0, sta = 0, mag_in = 0, mag_out = 0, sta_in = 0, sta_out = 0,
                      ehps_groups = { count = 0 }, mps_groups = { count = 0 },
                      ehps_abilities = { count = 0 }, mps_abilities = { count = 0 } }
  end
  log:info("init: capacity=", capacity)
end

local function copy_groups(dst, src)
  local n = (src and (src.count or #src)) or 0
  for i = 1, n do
    local s = src[i]
    local d = dst[i]
    if d == nil then d = {}; dst[i] = d end
    d.r = s.r; d.g = s.g; d.b = s.b; d.a = s.a; d.share = s.share
    d.key = s.key
  end
  dst.count = n
end

local function copy_abilities(dst, src)
  local n = (src and (src.count or #src)) or 0
  for i = 1, n do
    local s = src[i]
    local d = dst[i]
    if d == nil then d = {}; dst[i] = d end
    d.id = s.id; d.share = s.share; d.key = s.key
    d.r = s.r; d.g = s.g; d.b = s.b; d.a = s.a
  end
  dst.count = n
end


function M.push(timestamp, eHPS, MPS, crit, noncrit, ehps_groups, mps_groups, ehps_abilities, mps_abilities, d_group, ohps, rm, rs)
  local ems = eHPS + MPS
  local weight = state.period
  run.n = run.n + weight
  if ems > 0 then run.active = run.active + weight end
  if ems > run.peak then run.peak, run.peak_t = ems, timestamp end
  local slot   = state.data[state.write]
  if state.count >= state.capacity then state.forgot = slot.t end
  slot.t       = timestamp
  slot.eHPS    = eHPS
  slot.MPS     = MPS
  slot.crit    = crit or 0
  slot.noncrit = noncrit or 0
  slot.d       = d_group or 0
  slot.o       = ohps or 0
  slot.rm      = rm or 0
  slot.rs      = rs or 0
  copy_groups(slot.ehps_groups, ehps_groups)
  copy_groups(slot.mps_groups,  mps_groups)
  copy_abilities(slot.ehps_abilities, ehps_abilities)
  copy_abilities(slot.mps_abilities,  mps_abilities)
  state.write = (state.write % state.capacity) + 1
  if state.count < state.capacity then
    state.count = state.count + 1
  end
end

function M.at(i)
  local n = state.count
  if i < 1 or i > n then return nil end
  local cap = state.capacity
  local oldest = (n >= cap) and state.write or 1
  return state.data[((oldest - 1 + i - 1) % cap) + 1]
end

function M.iterate(fn)
  local n   = state.count
  if n == 0 then return end
  local cap = state.capacity
  local oldest = (n >= cap) and state.write or 1
  for i = 1, n do
    local idx = ((oldest - 1 + i - 1) % cap) + 1
    fn(i, state.data[idx])
  end
end

local markers = { n = 0 }
local MARKER_CAP       = 80
local MARKER_GROUP_CAP = 60
local group_marker_n   = 0

function M.add_marker(t, is_death, who)
  if markers.n >= MARKER_CAP then return end
  if who then
    if group_marker_n >= MARKER_GROUP_CAP then return end
    group_marker_n = group_marker_n + 1
  end
  markers.n = markers.n + 1
  local m = markers[markers.n]
  if not m then m = {}; markers[markers.n] = m end
  m.t = t
  m.death = is_death and true or false
  m.who = who
end

function M.markers() return markers, markers.n end

local dead_starts, dead_ends = {}, {}

function M.dead_spans()
  local n, open = 0, false
  for i = 1, markers.n do
    local m = markers[i]
    if not m.who then
      if m.death then
        if not open then
          n = n + 1
          dead_starts[n], dead_ends[n] = m.t, 0
          open = true
        end
      elseif open then
        dead_ends[n] = m.t
        open = false
      end
    end
  end
  return dead_starts, n, dead_ends
end

function M.halve()
  local n = state.count
  if n < 2 then return false end
  if n >= state.capacity and state.write ~= 1 then return false end
  local data = state.data
  local off = n % 2
  local keep = (n - off) / 2
  if off == 1 then state.forgot = data[1].t end
  for k = 1, keep do
    local kept = data[off + 2 * k]
    local dropped = data[off + 2 * k - 1]
    kept.mag_in, kept.mag_out = kept.mag_in + dropped.mag_in, kept.mag_out + dropped.mag_out
    kept.sta_in, kept.sta_out = kept.sta_in + dropped.sta_in, kept.sta_out + dropped.sta_out
    data[off + 2 * k] = data[k]
    data[k] = kept
  end
  state.count = keep
  state.write = keep + 1
  state.period = state.period * 2
  return true
end

function M.period()       return state.period    end
function M.kept_from()    return state.forgot    end
function M.count()        return state.count     end
function M.capacity()     return state.capacity  end
function M.is_recording() return state.recording end

function M.start_recording(period_ms)
  if state.capacity > state.base then M.init(state.base) end
  state.period = period_ms or 1000
  state.recording = true
  log:info("start_recording")
  if Verdant.SessionStore then Verdant.SessionStore.on_session_start() end
  if Verdant.Logo and Verdant.Logo.set_recording then Verdant.Logo.set_recording(true) end
end

function M.stop_recording()
  state.recording = false
  log:info("stop_recording: count=", state.count, "/", state.capacity)
  if Verdant.Metrics then Verdant.Metrics.session_close() end
  if Verdant.Logo and Verdant.Logo.set_recording then Verdant.Logo.set_recording(false) end
end

local summary_scratch = {
  count = 0, dur_ms = 0, avg_ems = 0, peak_ems = 0, peak_t_off = 0,
  crit_pct = 0, active_pct = 0, total_heal = 0, total_shield = 0,
  total_overheal = 0, wasted_pct = 0, totals_from = "",
  integral_heal = 0, integral_shield = 0, integral_overheal = 0,
}

function M.set_totals(heal, shield, overheal)
  if heal == nil then
    state.totals = false
  else
    state.totals = { heal = heal or 0, shield = shield or 0, overheal = overheal or 0 }
  end
end

function M.summary()
  local s = summary_scratch
  s.count = state.count
  s.dur_ms = 0; s.avg_ems = 0; s.peak_ems = 0; s.peak_t_off = 0
  s.crit_pct = 0; s.active_pct = 0; s.total_heal = 0; s.total_shield = 0
  s.total_overheal = 0; s.wasted_pct = 0; s.totals_from = ""
  s.integral_heal = 0; s.integral_shield = 0; s.integral_overheal = 0
  if state.count == 0 then return s end

  local t0, t_prev = 0, 0
  local sum_ems, peak_ems, peak_t = 0, 0, 0
  local sum_crit, sum_noncrit = 0, 0
  local active_n = 0

  M.iterate(function(i, sample)
    local ems = sample.eHPS + sample.MPS
    sum_ems = sum_ems + ems
    if ems > peak_ems then peak_ems = ems; peak_t = sample.t end
    sum_crit    = sum_crit    + sample.crit
    sum_noncrit = sum_noncrit + sample.noncrit
    if ems > 0 then active_n = active_n + 1 end
    if i == 1 then t0 = sample.t end
    if i > 1 then
      local dt = (sample.t - t_prev) / 1000
      s.integral_heal     = s.integral_heal     + sample.eHPS * dt
      s.integral_shield   = s.integral_shield   + sample.MPS  * dt
      s.integral_overheal = s.integral_overheal + (sample.o or 0) * dt
    end
    t_prev = sample.t
  end)

  local saved = state.totals
  if saved then
    s.total_heal, s.total_shield, s.total_overheal = saved.heal, saved.shield, saved.overheal
    s.totals_from = "saved"
  elseif saved == nil and Verdant.Metrics and Verdant.Metrics.totals then
    s.total_heal, s.total_shield, s.total_overheal = Verdant.Metrics.totals()
    s.totals_from = "events"
  else
    s.total_heal, s.total_shield, s.total_overheal = s.integral_heal, s.integral_shield, s.integral_overheal
    s.totals_from = "integral"
  end

  s.dur_ms = t_prev - t0
  local whole = state.whole
  if whole then
    s.avg_ems, s.peak_ems, s.peak_t_off = whole.avg, whole.peak, whole.peak_at
    s.crit_pct, s.active_pct = whole.crit_pct, whole.active_pct
  elseif s.totals_from == "events" then
    local BT = Verdant.BuffTracker
    local began = BT.session_start()
    local length = (state.recording and t_prev or BT.session_end()) - began
    if length > 0 then s.avg_ems = (s.total_heal + s.total_shield) / (length / 1000) end
    s.peak_ems   = run.peak
    s.peak_t_off = (run.peak > 0) and (run.peak_t - began) or 0
    s.active_pct = run.active / run.n
    if s.total_heal > 0 then s.crit_pct = Verdant.Metrics.crit_total() / s.total_heal end
  else
    s.avg_ems    = sum_ems / state.count
    s.peak_ems   = peak_ems
    s.peak_t_off = (peak_ems > 0) and (peak_t - t0) or 0
    s.active_pct = active_n / state.count
    local heal_total = sum_crit + sum_noncrit
    if heal_total > 0 then s.crit_pct = sum_crit / heal_total end
  end
  local raw_total = s.total_heal + s.total_overheal
  if raw_total > 0 then s.wasted_pct = s.total_overheal / raw_total end
  return s
end

function M.ability_sums()
  local saved = state.sums
  if saved then return saved.heal, saved.shield end
  if saved == nil and state.count > 0 then return Verdant.Metrics.by_ability() end
  return nil
end

local NO_RESTORES = { mag = 0, sta = 0, mag_by = {}, sta_by = {} }

function M.restore_totals()
  local saved = state.restores
  if saved then return saved.mag, saved.sta end
  if saved == nil and state.count > 0 then return Verdant.Metrics.restore_totals() end
  return 0, 0
end

function M.restore_sums()
  local saved = state.restores
  if saved then return saved.mag_by, saved.sta_by end
  if saved == nil and state.count > 0 then return Verdant.Metrics.restore_by_ability() end
  return NO_RESTORES.mag_by, NO_RESTORES.sta_by
end

local EMPTY_SHARES = { count = 0 }

function M.load_session(samples, marker_list, totals, sums, whole, period_ms, restores)
  M.clear()
  state.period = period_ms or 1000
  state.sums = sums or false
  state.whole = whole
  state.restores = restores or NO_RESTORES
  local kept = restores and restores.log
  for i = 1, (kept and #kept or 0) do
    local e = kept[i]
    log_restore(e.t, e.id, e.ch == 0, restores.names and restores.names[e.who] or "", e.v)
  end
  if totals then
    M.set_totals(totals.heal, totals.shield, totals.overheal)
  else
    M.set_totals(nil)
  end
  if #samples > state.capacity then
    local base = state.base
    M.init(#samples)
    state.base = base
  end
  for i = 1, #samples do
    local s = samples[i]
    M.push(s.t, s.eHPS, s.MPS, s.crit, s.noncrit,
           s.eg or EMPTY_SHARES, s.mg or EMPTY_SHARES,
           s.ea or EMPTY_SHARES, s.ma or EMPTY_SHARES, s.d, s.o, s.rm, s.rs)
    local slot = M.at(M.count())
    slot.mag, slot.sta = s.mag or 0, s.sta or 0
    slot.mag_in, slot.mag_out = s.mag_in or 0, s.mag_out or 0
    slot.sta_in, slot.sta_out = s.sta_in or 0, s.sta_out or 0
  end
  for i = 1, #marker_list do
    local m = marker_list[i]
    M.add_marker(m.t, m.death, m.who)
  end
  state.recording = false
  log:info("session loaded: samples=", #samples, "markers=", #marker_list)
end

function M.clear()
  log:info("clear: discarding", state.count, "samples")
  state.write = 1
  state.count = 0
  state.forgot = 0
  state.totals = nil
  state.sums = nil
  state.whole = nil
  state.restores = nil
  clear_rlog()
  run.n, run.active, run.peak, run.peak_t = 0, 0, 0, 0
  markers.n = 0
  group_marker_n = 0
end
