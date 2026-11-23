

Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Diagnostics = {}
local M = Verdant.Diagnostics

local NOOP = function() end
M.bump        = NOOP
M.get         = function() return 0 end
M.log_event   = NOOP
M.snapshot    = function() return {} end
M.print_diag  = function() d("[diag] disabled (DEBUG=false)") end
M.full_report = function() d("[report] disabled (DEBUG=false)") end
M.reset       = NOOP
M.init        = NOOP

if not Verdant.Constants.DEBUG then return end


local GetGameTimeMilliseconds = Verdant.zenimax.api.GetGameTimeMilliseconds
local d           = d
local pairs       = pairs
local tostring    = tostring
local math_min    = math.min
local table_sort  = table.sort


local EVENT_CAP   = 200
local TS_CAP      = 120
local TICK_MS     = 1000


local counters    = {}
local ev_buf      = {}
local ev_head     = 0
local ev_count    = 0
local ts_buf      = {}
local ts_head     = 0
local ts_count    = 0
local start_time  = 0

function M.bump(key, n)
  counters[key] = (counters[key] or 0) + (n or 1)
end

function M.get(key)
  return counters[key] or 0
end

function M.log_event(cat, payload)
  ev_head = (ev_head % EVENT_CAP) + 1
  ev_buf[ev_head] = { t = GetGameTimeMilliseconds(), cat = cat, p = payload }
  ev_count = ev_count + 1
end

local function ts_sample()
  local snap = {
    t      = GetGameTimeMilliseconds(),
    heals  = counters["engine.heal.accepted"]      or 0,
    shields= counters["engine.shield.accepted"]    or 0,
    dmg    = counters["engine.damage.accepted"]    or 0,
    grp_sz = Verdant.GroupSet and Verdant.GroupSet.size() or 0,
    metric = (function()
      if not Verdant.Metrics then return nil end
      local r = Verdant.Metrics.contribution(GetGameTimeMilliseconds())
      return { eHPS=r.eHPS, MPS=r.MPS, EMS=r.EMS }
    end)(),
  }
  ts_head = (ts_head % TS_CAP) + 1
  ts_buf[ts_head] = snap
  ts_count = ts_count + 1
end

function M.snapshot()
  local events = {}
  if ev_count <= EVENT_CAP then
    for i = 1, ev_count do events[i] = ev_buf[i] end
  else
    local n = 0
    for i = 1, EVENT_CAP do
      local idx = (ev_head - 1 + i) % EVENT_CAP + 1
      n = n + 1
      events[n] = ev_buf[idx]
    end
  end

  local ts = {}
  local ts_len = math.min(ts_count, TS_CAP)
  if ts_count <= TS_CAP then
    for i = 1, ts_count do ts[i] = ts_buf[i] end
  else
    local n = 0
    for i = 1, TS_CAP do
      local idx = (ts_head - 1 + i) % TS_CAP + 1
      n = n + 1
      ts[n] = ts_buf[idx]
    end
  end

  local group_snap    = Verdant.GroupSet     and Verdant.GroupSet.snapshot()     or {}
  local coverage_snap = Verdant.Coverage     and Verdant.Coverage.snapshot()     or {}
  local shield_snap   = Verdant.ShieldRegistry and Verdant.ShieldRegistry.snapshot() or {}
  local mode_snap     = Verdant.Mode         and Verdant.Mode.snapshot()         or {}

  return {
    start_time  = start_time,
    counters    = counters,
    events      = events,
    ev_total    = ev_count,
    timeseries  = ts,
    ts_total    = ts_count,
    group       = group_snap,
    coverage    = coverage_snap,
    shield_reg  = shield_snap,
    mode        = mode_snap,
  }
end

local function build_diag_lines()
  local lines = {}
  lines[#lines+1] = "[diag] uptime=" .. (GetGameTimeMilliseconds() - start_time)
                    .. "ms  ev_total=" .. ev_count .. "  ts_samples=" .. ts_count
  lines[#lines+1] = "[diag] counters:"
  local keys = {}
  for k in pairs(counters) do keys[#keys+1] = k end
  table_sort(keys)
  for _, k in ipairs(keys) do
    lines[#lines+1] = "  " .. k .. " = " .. tostring(counters[k])
  end
  lines[#lines+1] = "[diag] last events (up to 10):"
  local n_show = math_min(ev_count, 10)
  local base   = math_min(ev_count, EVENT_CAP)
  for i = base - n_show + 1, base do
    local idx = (ev_head - base + i - 1 + EVENT_CAP) % EVENT_CAP + 1
    local e = ev_buf[idx]
    if e then
      lines[#lines+1] = "  t=" .. e.t .. " [" .. (e.cat or "?") .. "] " .. tostring(e.p)
    end
  end
  if Verdant.Mode then
    lines[#lines+1] = "[diag] mode=" .. tostring(Verdant.Mode.current())
  end
  if Verdant.GroupSet then
    lines[#lines+1] = "[diag] group_set.size=" .. Verdant.GroupSet.size()
  end
  if Verdant.Metrics and Verdant.Metrics.pool_capacity then
    lines[#lines+1] = "[diag] event_pool=" .. Verdant.Metrics.pool_in_use()
                      .. "/" .. Verdant.Metrics.pool_capacity()
  end
  if Verdant.Log and Verdant.Log.size then
    local cur, cap = Verdant.Log.size()
    lines[#lines+1] = "[diag] log_ring=" .. cur .. "/" .. cap
  end
  if Verdant.Validation and Verdant.Validation.run_all_checks then
    local v = Verdant.Validation.run_all_checks()
    lines[#lines+1] = "[diag] validation: failures=" .. v.failure_count
                      .. " pool_outstanding=" .. v.pool_outstanding
  end
  if Verdant.Profiler and Verdant.Profiler.report then
    local r, window_s = Verdant.Profiler.report()
    local stages = {}
    for k in pairs(r) do stages[#stages+1] = k end
    if #stages > 0 then
      lines[#lines+1] = "[diag] profiler window=" .. string.format("%.1fs", window_s)
                        .. " stages=" .. #stages .. " (use /verdant prof for detail)"
    end
  end
  return lines
end

function M.print_diag()
  local lines = build_diag_lines()
  if Verdant.Constants.DEBUG and Verdant.CopyBox then
    Verdant.CopyBox.show("Verdant /diag", table.concat(lines, "\n"))
  else
    for _, line in ipairs(lines) do d(line) end
  end
end


function M.full_report(include_gc)
  if not Verdant.Constants.DEBUG then
    d("[report] disabled (DEBUG=false)")
    return
  end
  local out = {}
  local function section(title, lines)
    out[#out+1] = ""
    out[#out+1] = "═══ " .. title .. " ═══"
    for _, l in ipairs(lines) do out[#out+1] = l end
  end
  out[#out+1] = "Verdant full report — uptime "
                .. (GetGameTimeMilliseconds() - start_time) .. "ms  build="
                .. tostring(Verdant.Constants.VERSION or "?")
  section("handler errors", Verdant.zenimax.events.error_lines())
  if Verdant.Settings and Verdant.Settings.report_lines then
    section("config", Verdant.Settings.report_lines())
  end
  if Verdant.TemporalBuffer and Verdant.TemporalBuffer.summary then
    local s = Verdant.TemporalBuffer.summary()
    if s.count > 0 then
      section("session summary", {
        string.format("samples=%d  duration=%.1fs  recording=%s",
          s.count, s.dur_ms / 1000, tostring(Verdant.TemporalBuffer.is_recording())),
        string.format("avg_ems=%.0f  peak_ems=%.0f  peak_at=%.1fs",
          s.avg_ems, s.peak_ems, s.peak_t_off / 1000),
        string.format("crit=%.0f%%  active=%.0f%%",
          s.crit_pct * 100, s.active_pct * 100),
        string.format("total_heal=%.0f  total_shield=%.0f",
          s.total_heal, s.total_shield),
      })
    end
  end
  if Verdant.BuffTracker and Verdant.BuffTracker.report_lines then
    section("buff tracker", Verdant.BuffTracker.report_lines())
  end
  if Verdant.AutoRecord and Verdant.AutoRecord.report_lines then
    section("auto record", Verdant.AutoRecord.report_lines())
  end
  if Verdant.Trace and Verdant.Trace.status_line then
    section("trace", { Verdant.Trace.status_line() })
  end
  if Verdant.SessionStore and Verdant.SessionStore.report_lines then
    section("session library", Verdant.SessionStore.report_lines())
    section("hitch", Verdant.Hitch.lines())
  end
  section("diagnostics", build_diag_lines())
  if Verdant.Profiler and Verdant.Profiler.report_lines then
    section("profiler",   Verdant.Profiler.report_lines())
  end
  if Verdant.Validation and Verdant.Validation.report_lines then
    section("validation", Verdant.Validation.report_lines())
  end
  if Verdant.SkillColors and Verdant.SkillColors.unknown_lines then
    section("unclassified abilities", Verdant.SkillColors.unknown_lines())
  end
  if Verdant.Log and Verdant.Log.recent_lines then
    section("log (last 20)", Verdant.Log.recent_lines(20))
  end
  if include_gc and M.gc_probe_lines then
    section("gcprobe  (WARNING: this CLEARED the recording buffer)", M.gc_probe_lines())
  end
  if Verdant.CopyBox and Verdant.CopyBox.show then
    Verdant.CopyBox.show("Verdant /report", table.concat(out, "\n"))
  else
    for _, l in ipairs(out) do d(l) end
  end
end

function M.reset()
  counters = {}
  ev_buf   = {}
  ev_head  = 0
  ev_count = 0
  ts_buf   = {}
  ts_head  = 0
  ts_count = 0
  start_time = GetGameTimeMilliseconds()
end

function M.init()
  start_time = GetGameTimeMilliseconds()
  Verdant.zenimax.events.register_update("Verdant_DiagTick", TICK_MS, ts_sample)
end

local gcprobe_eg = { count = 0 }
local gcprobe_mg = { count = 0 }
local gcprobe_sink

function M.gc_probe_lines(n)
  n = n or 1000
  local Metrics = Verdant.Metrics
  local TB      = Verdant.TemporalBuffer
  local now     = GetGameTimeMilliseconds()


  local lines = {}
  local function emit(s) lines[#lines + 1] = s; d("[gcprobe] " .. s) end

  local function measure(label, body)
    for _ = 1, 64 do body() end
    for _ = 1, 2 do collectgarbage("collect") end
    local before = collectgarbage("count")
    for _ = 1, n do body() end
    local after  = collectgarbage("count")
    local bytes  = (after - before) * 1024 / n
    emit(string.format("%-26s %9.2f bytes/sample", label, bytes))
    return bytes
  end

  emit(string.format("=== Verdant gcprobe  N=%d  (ZOS double-collect) ===", n))
  measure("control (1 table/iter)", function()
    gcprobe_sink = { r = 0, g = 0, b = 0, a = 0, share = 0 }
  end)
  local dp = measure("data path (M1)", function()
    local e     = Metrics.eHPS(now)
    local m     = Metrics.MPS(now)
    local c, nc = Metrics.eHPS_crit_split(now)
    Metrics.eHPS_by_group_into(gcprobe_eg, now)
    Metrics.MPS_by_group_into(gcprobe_mg, now)
    TB.push(now, e, m, c, nc, gcprobe_eg, gcprobe_mg)
  end)

  TB.clear()
  emit((dp < 1) and "VERDICT: data path ~0 -> ZERO-ALLOC CONFIRMED"
               or "VERDICT: data path NONZERO -> an alloc leaked, investigate")
  emit("(temporal buffer cleared)")
  return lines
end

function M.gc_probe(n)
  local lines = M.gc_probe_lines(n)
  if Verdant.CopyBox then
    Verdant.CopyBox.show("Verdant gcprobe", table.concat(lines, "\n"))
  end
end
