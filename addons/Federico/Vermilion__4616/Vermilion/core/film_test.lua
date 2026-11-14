Vermilion = Vermilion or {}
Vermilion.FilmTest = {}
local M = Vermilion.FilmTest

local function list(n, make)
  local t = { count = n }
  for i = 1, n do t[i] = make(i) end
  return t
end

local groups = list(8, function(i) return { r = 0.5, g = 0.5, b = 0.5, a = 1, share = 1 / 8, key = "k" .. i } end)
local abilities = list(14, function(i) return { id = 1000 + i, share = 1 / 14, key = "k" .. (i % 8 + 1), abs = 900, r = 0.5, g = 0.5, b = 0.5, a = 1 } end)
local dgroups = list(4, function(i) return { r = 0.5, g = 0.5, b = 0.5, a = 1, share = 0.25, key = i } end)
local dabilities = list(14, function(i) return { id = 1000 + i, share = 1 / 14, key = i % 4 + 1, abs = 900, r = 0.5, g = 0.5, b = 0.5, a = 1 } end)
local shields = list(2, function(i) return { id = 2000 + i, share = 0.5, key = "shield", abs = 100, r = 1, g = 1, b = 1, a = 1 } end)
local targets = list(2, function(i) return { id = i, name = "Target", ttype = 0, share = 0.5, abs = 900 } end)

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
  for _, st in pairs(session and session.streams or {}) do
    for _, c in ipairs(st.data or {}) do total = total + #c end
  end
  return total
end

function M.measure(minutes, clock)
  local TB, G, W, SS = Vermilion.TemporalBuffer, Vermilion.Graph, Vermilion.FilmWindow, Vermilion.SessionStore
  local n = minutes * 60
  local keep = TB.capacity()
  TB.init(1)
  local baseline = heap()
  TB.init(n)
  local empty = heap() - baseline
  TB.start_recording()
  local t0 = clock()
  for i = 1, n do
    TB.push(100000 + i * 1000, 20000 + (i * 7919) % 90000, (i * 104729) % 9000, 12000, 8000,
      groups, abilities, dgroups, dabilities, shields, targets)
  end
  local push_us = (clock() - t0) * 1000 / n
  local full = heap() - baseline
  local gc_ms = timed(clock, function() collectgarbage("collect") end, 5)
  W.reset()
  local live = timed(clock, G.rerender, 20)
  TB.stop_recording()
  W.reset()
  local stopped = timed(clock, G.rerender, 20)
  W.zoom(-1, 0.5, n)
  W.zoom(-1, 0.5, n)
  W.zoom(-1, 0.5, n)
  local zoom = timed(clock, function() W.pan(1, n); G.rerender() end, 20)
  W.reset()
  local session
  local capture = timed(clock, function() session = SS.capture() end, 1)
  local line = string.format("%d %d %.1f %.1f %.1f %.1f %.2f %.2f %.2f %.1f %.0f",
    minutes, n, empty / 1024, full / 1024, gc_ms, push_us, live, stopped, zoom, capture, bytes(session) / 1024)
  session = nil
  TB.init(keep)
  G.rerender()
  return line
end

function M.run(list_of_minutes, clock)
  local out = { M.HEADER }
  for i = 1, #list_of_minutes do out[#out + 1] = M.measure(list_of_minutes[i], clock) end
  return table.concat(out, string.char(10))
end
