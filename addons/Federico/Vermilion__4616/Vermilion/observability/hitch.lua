Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Hitch = {}
local M = Vermilion.Hitch

local NOOP = function() end
M.mark    = NOOP
M.observe = NOOP
M.reset   = NOOP
M.init    = NOOP
M.stats   = function() return 0, 0, 0 end
M.lines   = function() return { "[hitch] disabled (DEBUG=false)" } end

if not Vermilion.Constants.DEBUG then return end

local api            = Vermilion.zenimax.api
local zev            = Vermilion.zenimax.events
local log            = Vermilion.Log.for_module("hitch")
local string_format  = string.format
local table_concat   = table.concat
local math_floor     = math.floor
local collectgarbage = collectgarbage

local THRESHOLD_MS = 80
local LOADING_MS   = 4000
local KEEP         = 12
local UPDATE       = "VermilionHitch"
local WORK         = { "tick", "render", "start", "stop", "save", "load" }
local INDEX        = {}
for i = 1, #WORK do INDEX[WORK[i]] = i end

local last_frame, frames, n_hitch, worst_ms = 0, 0, 0, 0
local done = {}
for i = 1, #WORK do done[i] = false end
local ring = {}
for i = 1, KEEP do ring[i] = { t = 0, ms = 0, mask = 0, own = 0, top = "", heap = 0 } end
local ring_n, ring_w = 0, 0

local function describe(mask)
  if mask == 0 then return "idle" end
  local parts = {}
  local bit = 1
  for i = 1, #WORK do
    if mask % (bit * 2) >= bit then parts[#parts + 1] = WORK[i] end
    bit = bit * 2
  end
  return table_concat(parts, "+")
end

local function sentence(h)
  return string_format("%dms  vermilion: %s, %d ms of its own code%s  lua %d MB",
    h.ms, describe(h.mask), h.own, (h.own > 0 and h.top ~= "") and (" (" .. h.top .. ")") or "", h.heap)
end

function M.mark(what)
  local i = INDEX[what]
  if i then done[i] = true end
end

function M.observe(now)
  local own, top = Vermilion.Profiler.take_frame()
  local mask, bit = 0, 1
  for i = 1, #WORK do
    if done[i] then
      mask = mask + bit
      done[i] = false
    end
    bit = bit * 2
  end
  local before = last_frame
  last_frame = now
  if before <= 0 then return end
  local dt = now - before
  if dt >= LOADING_MS then return end
  frames = frames + 1
  if dt < THRESHOLD_MS then return end
  n_hitch = n_hitch + 1
  if dt > worst_ms then worst_ms = dt end
  ring_w = (ring_w % KEEP) + 1
  local h = ring[ring_w]
  h.t, h.ms, h.mask, h.own, h.top = now, dt, mask, own, top or ""
  h.heap = math_floor(collectgarbage("count") / 1024)
  if ring_n < KEEP then ring_n = ring_n + 1 end
  log:info("frame of", sentence(h))
end

local function on_frame()
  M.observe(api.GetGameTimeMilliseconds())
end

function M.lines()
  local out = {
    string_format("frames=%d hitches(>=%dms)=%d worst=%dms", frames, THRESHOLD_MS, n_hitch, worst_ms),
  }
  local now = api.GetGameTimeMilliseconds()
  for i = ring_n, 1, -1 do
    local h = ring[((ring_w - ring_n + i - 1) % KEEP) + 1]
    out[#out + 1] = string_format("  %6.1fs ago  %s", (now - h.t) / 1000, sentence(h))
  end
  return out
end

function M.stats()
  return frames, n_hitch, worst_ms
end

function M.reset()
  frames, n_hitch, worst_ms, ring_n, ring_w = 0, 0, 0, 0, 0
  last_frame = 0
  for i = 1, #WORK do done[i] = false end
end

function M.init()
  last_frame = 0
  zev.register_update(UPDATE, 0, on_frame)
end
