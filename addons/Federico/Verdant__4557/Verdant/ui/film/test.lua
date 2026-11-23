Verdant = Verdant or {}
local Verdant = Verdant

Verdant.FilmTest = {}
local M = Verdant.FilmTest

local string_format = string.format
local math_min = math.min

local GROUPS, ABILITIES = 6, 12

local function list(n, make)
  local t = { count = n }
  for i = 1, n do t[i] = make(i) end
  return t
end

local groups = list(GROUPS, function(i) return { r = 0.5, g = 0.5, b = 0.5, a = 1, share = 1 / GROUPS, key = "k" .. i } end)
local abilities = list(ABILITIES, function(i)
  return { id = 61000 + i, share = 1 / ABILITIES, key = "k" .. (i % GROUPS + 1), r = 0.5, g = 0.5, b = 0.5, a = 1 }
end)

M.HEADER = "minutes samples empty_mb full_mb full_gc_ms push_us live_ms stopped_ms zoom_ms capture_ms session_kb"

local function heap()
  collectgarbage("collect")
  collectgarbage("collect")
  return collectgarbage("count")
end

local function timed(clock, fn, reps)
  local t0 = clock()
  for _ = 1, reps do fn() end
  return (clock() - t0) / reps
end

local function bytes(session)
  local total = 0
  for _, stream in pairs(session.streams) do
    for _, chunk in ipairs(stream.data or {}) do total = total + #chunk end
  end
  return total
end

function M.measure(minutes, clock)
  local TB, G, W, SS = Verdant.TemporalBuffer, Verdant.Graph, Verdant.FilmWindow, Verdant.SessionStore
  local capacity = Verdant.Constants.TEMPORAL.CAPACITY
  local n = math_min(minutes * 60, capacity)
  TB.init(1)
  local baseline = heap()
  TB.init(capacity)
  local empty = heap() - baseline
  TB.start_recording(1000)
  local t0 = clock()
  for i = 1, n do
    TB.push(100000 + i * 1000, 20000 + (i * 7919) % 90000, (i * 104729) % 9000, 12000, 8000,
      groups, groups, abilities, abilities, (i * 31) % 5000, (i * 17) % 3000)
  end
  local push_us = (clock() - t0) * 1000 / n
  local full = heap() - baseline
  local gc_ms = timed(clock, function() collectgarbage("collect") end, 5)
  W.reset()
  local live = timed(clock, G.rerender, 20)
  TB.stop_recording()
  W.reset()
  local stopped = timed(clock, G.rerender, 20)
  W.drag_edge(-1, 3 / 8, n)
  W.drag_edge(1, 5 / 8, n)
  local zoom = timed(clock, function() W.pan(1, n); G.rerender() end, 20)
  W.reset()
  local session
  local capture = timed(clock, function() session = SS.capture() end, 1)
  return string_format("%d %d %.1f %.1f %.1f %.1f %.2f %.2f %.2f %.1f %.0f",
    minutes, n, empty / 1024, full / 1024, gc_ms, push_us, live, stopped, zoom, capture, bytes(session) / 1024)
end

function M.run(lengths, clock)
  local out = { M.HEADER }
  for i = 1, #lengths do out[#out + 1] = M.measure(lengths[i], clock) end
  Verdant.Graph.on_flush_click()
  return table.concat(out, "\n")
end
