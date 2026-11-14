
Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Diagnostics = {}
local M = Vermilion.Diagnostics

local NOOP = function() end
M.bump        = NOOP
M.get         = function() return 0 end
M.log_event   = NOOP
M.snapshot    = function() return {} end
M.print_diag  = function() d("[diag] disabled (DEBUG=false)") end
M.full_report = function() d("[report] disabled (DEBUG=false)") end
M.reset       = NOOP
M.init        = NOOP

if not Vermilion.Constants.DEBUG then return end

-- ── below this line only parses / runs when DEBUG=true
--! "You shall not pass!!!"

local GetGameTimeMilliseconds = Vermilion.zenimax.api.GetGameTimeMilliseconds
local d           = d
local pairs       = pairs
local tostring    = tostring
local math_min    = math.min
local table_sort  = table.sort

-- ── config
local EVENT_CAP   = 200
local TS_CAP      = 120
local TICK_MS     = 1000

-- ── state
local counters    = {}
local ev_buf      = {}
local ev_head     = 0
local ev_count    = 0
local ts_buf      = {}
local ts_head     = 0
local ts_count    = 0
local start_time  = 0

-- ── counters
function M.bump(key, n)
  counters[key] = (counters[key] or 0) + (n or 1)
end

function M.get(key)
  return counters[key] or 0
end

-- ── event log
function M.log_event(cat, payload)
  ev_head = (ev_head % EVENT_CAP) + 1
  ev_buf[ev_head] = { t = GetGameTimeMilliseconds(), cat = cat, p = payload }
  ev_count = ev_count + 1
end

-- ── timeseries
local function ts_sample()
  local now = GetGameTimeMilliseconds()
  local snap = {
    t       = now,
    damage  = counters["engine.damage.accepted"] or 0,
    shield  = counters["engine.shield.accepted"] or 0,
    metric  = (function()
      if not Vermilion.Metrics or not Vermilion.Metrics.eDPS then return nil end
      local ok, edps = pcall(Vermilion.Metrics.eDPS, now)
      if not ok then return nil end
      local _, shdps = pcall(Vermilion.Metrics.ShDPS, now)
      edps  = edps  or 0
      shdps = shdps or 0
      return { eDPS = edps, ShDPS = shdps, EOS = edps + shdps }
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

  local mode_snap    = Vermilion.Mode    and Vermilion.Mode.snapshot()          or {}
  local metrics_snap = (Vermilion.Metrics and Vermilion.Metrics.size_snapshot)
                       and Vermilion.Metrics.size_snapshot() or {}

  return {
    start_time  = start_time,
    counters    = counters,
    events      = events,
    ev_total    = ev_count,
    timeseries  = ts,
    ts_total    = ts_count,
    mode        = mode_snap,
    metrics     = metrics_snap,
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
  if Vermilion.Mode then
    lines[#lines+1] = "[diag] mode=" .. tostring(Vermilion.Mode.current())
  end
  if Vermilion.Metrics and Vermilion.Metrics.pool_capacity then
    lines[#lines+1] = "[diag] event_pool=" .. Vermilion.Metrics.pool_in_use()
                      .. "/" .. Vermilion.Metrics.pool_capacity()
  end
  if Vermilion.Log and Vermilion.Log.size then
    local cur, cap = Vermilion.Log.size()
    lines[#lines+1] = "[diag] log_ring=" .. cur .. "/" .. cap
  end
  if Vermilion.Validation and Vermilion.Validation.run_all_checks then
    local v = Vermilion.Validation.run_all_checks()
    lines[#lines+1] = "[diag] validation: failures=" .. v.failure_count
                      .. " pool_outstanding=" .. v.pool_outstanding
  end
  if Vermilion.Profiler and Vermilion.Profiler.report then
    local r, window_s = Vermilion.Profiler.report()
    local stages = {}
    for k in pairs(r) do stages[#stages+1] = k end
    if #stages > 0 then
      lines[#lines+1] = "[diag] profiler window=" .. string.format("%.1fs", window_s)
                        .. " stages=" .. #stages .. " (use /Vermilion prof for detail)"
    end
  end
  return lines
end

function M.print_diag()
  local lines = build_diag_lines()
  if Vermilion.Constants.DEBUG and Vermilion.CopyBox then
    Vermilion.CopyBox.show("Vermilion /diag", table.concat(lines, "\n"))
  else
    for _, line in ipairs(lines) do d(line) end
  end
end


function M.full_report(include_gc)
  if not Vermilion.Constants.DEBUG then
    d("[report] disabled (DEBUG=false)")
    return
  end
  local out = {}
  local function section(title, lines)
    out[#out+1] = ""
    out[#out+1] = "═══ " .. title .. " ═══"
    for _, l in ipairs(lines) do out[#out+1] = l end
  end
  out[#out+1] = "Vermilion full report — uptime "
                .. (GetGameTimeMilliseconds() - start_time) .. "ms"
  if Vermilion.Settings and Vermilion.Settings.report_lines then
    section("config", Vermilion.Settings.report_lines())
  end
  section("diagnostics", build_diag_lines())
  if Vermilion.Profiler and Vermilion.Profiler.report_lines then
    section("profiler",   Vermilion.Profiler.report_lines())
  end
  section("hitch", Vermilion.Hitch.lines())
  if Vermilion.Validation and Vermilion.Validation.report_lines then
    section("validation", Vermilion.Validation.report_lines())
  end
  if Vermilion.SkillColors and Vermilion.SkillColors.unknown_lines then
    section("unclassified abilities", Vermilion.SkillColors.unknown_lines())
  end
  if Vermilion.Probe and Vermilion.Probe.suspects_report then
    section("source audit", { Vermilion.Probe.suspects_report() })
  end
  if Vermilion.DebuffTracker and Vermilion.DebuffTracker.report_lines then
    section("debuff tracker", Vermilion.DebuffTracker.report_lines())
  end
  if Vermilion.AutoRecord and Vermilion.AutoRecord.report_lines then
    section("auto record", Vermilion.AutoRecord.report_lines())
  end
  if Vermilion.Trace and Vermilion.Trace.status_line then
    section("trace", { Vermilion.Trace.status_line() })
  end
  if Vermilion.Log and Vermilion.Log.recent_lines then
    section("log (last 20)", Vermilion.Log.recent_lines(20))
  end
  if include_gc and M.gc_probe_lines then
    section("gcprobe  (WARNING: this CLEARED the recording buffer)", M.gc_probe_lines())
  end
  if Vermilion.CopyBox and Vermilion.CopyBox.show then
    Vermilion.CopyBox.show("Vermilion /report", table.concat(out, "\n"))
  else
    for _, l in ipairs(out) do d(l) end
  end
end

-- ── reset
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

-- ── init
function M.init()
  start_time = GetGameTimeMilliseconds()
  Vermilion.zenimax.events.register_update("Vermilion_DiagTick", TICK_MS, ts_sample)
end

local gcprobe_scratch = { count = 0 }
local gcprobe_sink

function M.gc_probe_lines(n)
  n = n or 1000
  local Metrics = Vermilion.Metrics
  local TB      = Vermilion.TemporalBuffer
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

  emit(string.format("=== Vermilion gcprobe  N=%d  (ZOS double-collect) ===", n))
  measure("control (1 table/iter)", function()
    gcprobe_sink = { r = 0, g = 0, b = 0, a = 0, share = 0 }
  end)
  local dp = measure("data path (M1)", function()
    local e  = Metrics.eDPS(now)
    local s  = Metrics.ShDPS(now)
    local c, nc = Metrics.crit_split(now)
    Metrics.eos_groups_into(gcprobe_scratch, now)
    TB.push(now, e, s, c, nc, gcprobe_scratch)
  end)

  TB.clear()
  emit(dp < 1 and "VERDICT: data path ~0 -> ZERO-ALLOC CONFIRMED"
               or "VERDICT: data path NONZERO -> an alloc leaked, investigate")
  emit("(temporal buffer cleared)")
  return lines
end

function M.gc_probe(n)
  local lines = M.gc_probe_lines(n)
  if Vermilion.CopyBox then
    Vermilion.CopyBox.show("Vermilion gcprobe", table.concat(lines, "\n"))
  end
end
