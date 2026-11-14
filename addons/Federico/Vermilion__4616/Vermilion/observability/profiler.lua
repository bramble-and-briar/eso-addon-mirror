Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Profiler = {}
local M = Vermilion.Profiler

local NOOP = function() end
M.enter        = NOOP
M.exit         = NOOP
M.span         = function(_name, fn, ...) return fn(...) end
M.report       = function() return {}, 0 end
M.report_lines = function() return { "[prof] disabled (DEBUG=false)" } end
M.dump_to_chat = function() d("[prof] disabled (DEBUG=false)") end
M.reset        = NOOP
M.take_frame   = function() return 0, nil end

if not Vermilion.Constants.DEBUG then return end

--!! You shall not passs!!

local now_ms = Vermilion.zenimax.api.GetGameTimeMilliseconds

-- histograms
local BUCKET_BOUNDS = { 0, 1, 2, 4, 8, 16, 32, 64, 128, 256 }
local BUCKET_COUNT  = #BUCKET_BOUNDS

local function new_histogram()
  local h = { count = 0, total = 0, max = 0, buckets = {} }
  for i = 1, BUCKET_COUNT do h.buckets[i] = 0 end
  return h
end

local function bucket_for(ms)
  for i = BUCKET_COUNT, 1, -1 do
    if ms >= BUCKET_BOUNDS[i] then return i end
  end
  return 1
end

local function percentile(h, p)
  if h.count == 0 then return 0 end
  local target = h.count * p
  local cum = 0
  for i = 1, BUCKET_COUNT do
    cum = cum + h.buckets[i]
    if cum >= target then return BUCKET_BOUNDS[i] end
  end
  return BUCKET_BOUNDS[BUCKET_COUNT]
end

-- state
local stages       = {}
local enter_stack  = {}
local stack_top    = 0
local started_at   = now_ms()
local frame_ms, frame_top, frame_top_ms = 0, nil, 0

--  the real thing (replace stubs at the bottom)
function M.enter(name)
  stack_top = stack_top + 1
  local frame = enter_stack[stack_top]
  if not frame then
    frame = {}
    enter_stack[stack_top] = frame
  end
  frame.name = name
  frame.t0   = now_ms()
end

function M.exit(name)
  if stack_top == 0 then
    if Vermilion.Log and Vermilion.Log.write then
      Vermilion.Log.write("error", "profiler.unbalanced", { exit = name, stack_top = 0 })
    end
    return
  end
  local frame = enter_stack[stack_top]
  if frame.name ~= name then
    if Vermilion.Log and Vermilion.Log.write then
      Vermilion.Log.write("error", "profiler.unbalanced",
        { expected = frame.name, got = name })
    end
    stack_top = stack_top - 1
    return
  end
  local dt = now_ms() - frame.t0
  stack_top = stack_top - 1
  if stack_top == 0 then
    frame_ms = frame_ms + dt
    if frame_top == nil or dt > frame_top_ms then frame_top, frame_top_ms = name, dt end
  end

  local h = stages[name]
  if not h then h = new_histogram(); stages[name] = h end
  h.count = h.count + 1
  h.total = h.total + dt
  if dt > h.max then h.max = dt end
  h.buckets[bucket_for(dt)] = h.buckets[bucket_for(dt)] + 1

  local budgets = Vermilion.Constants.PROFILER_BUDGETS_MS
  local budget  = budgets and budgets[name]
  if budget and dt > budget and Vermilion.Log and Vermilion.Log.write then
    Vermilion.Log.write("warn", "profiler.budget_exceeded",
      { stage = name, dt_ms = dt, budget_ms = budget })
  end
end

function M.span(name, fn, ...)
  M.enter(name)
  local ok, ret = pcall(fn, ...)
  M.exit(name)
  if not ok then error(ret) end
  return ret
end

function M.reset()
  stages = {}
  stack_top = 0
  started_at = now_ms()
  frame_ms, frame_top, frame_top_ms = 0, nil, 0
end

function M.take_frame()
  local ms, top = frame_ms, frame_top
  frame_ms, frame_top, frame_top_ms = 0, nil, 0
  return ms, top
end

function M.report()
  local r = {}
  for name, h in pairs(stages) do
    r[name] = {
      count    = h.count,
      total_ms = h.total,
      avg_ms   = h.count > 0 and (h.total / h.count) or 0,
      max_ms   = h.max,
      p50      = percentile(h, 0.50),
      p95      = percentile(h, 0.95),
      p99      = percentile(h, 0.99),
    }
  end
  return r, (now_ms() - started_at) / 1000
end

function M.report_lines()
  local r, window_s = M.report()
  local lines = { string.format("[prof] window: %.1f sec", window_s) }
  local names = {}
  for k in pairs(r) do names[#names+1] = k end
  table.sort(names, function(a, b) return r[a].total_ms > r[b].total_ms end)
  for _, name in ipairs(names) do
    local s = r[name]
    lines[#lines+1] = string.format("  %s  count=%d p50=%d p95=%d p99=%d max=%d total=%d",
      name, s.count, s.p50, s.p95, s.p99, s.max_ms, s.total_ms)
  end
  return lines
end

function M.dump_to_chat()
  local lines = M.report_lines()
  for _, l in ipairs(lines) do d(l) end
  if Vermilion.CopyBox and Vermilion.CopyBox.show then
    Vermilion.CopyBox.show("Vermilion /prof", table.concat(lines, "\n"))
  end
end
