Vermilion = Vermilion or {}
Vermilion.TemporalBuffer = {}
local M = Vermilion.TemporalBuffer

local math_floor = math.floor
local log        = Vermilion.Log.for_module("temporal_buffer")

--* state
local state = {
  data      = {},
  capacity  = 0,
  base      = 0,
  write     = 1,
  count     = 0,
  recording = false,
  period    = 1000,
  gen       = 0,
}

--* public API ────────────────────────────────────────────────────────────────
function M.init(capacity)
  capacity       = math_floor(capacity)
  if capacity < 1 then capacity = 1 end
  state.capacity = capacity
  state.base     = capacity
  state.write    = 1
  state.count    = 0
  state.gen      = state.gen + 1
  state.data     = {}
  for i = 1, capacity do
    state.data[i] = {
      t = 0, eDPS = 0, ShDPS = 0, crit = 0, noncrit = 0,
      mag = 0, sta = 0, mag_in = 0, mag_out = 0, sta_in = 0, sta_out = 0,
      eos_groups     = { count = 0 },
      eos_abilities  = { count = 0 },
      dtype_groups   = { count = 0 },
      dtype_abilities = { count = 0 },
      shield_abilities = { count = 0 },
      targets = { count = 0 },
    }
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
    d.id = s.id; d.share = s.share; d.key = s.key; d.abs = s.abs or 0
    d.r = s.r; d.g = s.g; d.b = s.b; d.a = s.a
  end
  dst.count = n
end

local function copy_targets(dst, src)
  local n = (src and (src.count or #src)) or 0
  for i = 1, n do
    local s = src[i]
    local d = dst[i]
    if d == nil then d = {}; dst[i] = d end
    d.id = s.id; d.name = s.name; d.ttype = s.ttype; d.share = s.share; d.abs = s.abs or 0
  end
  dst.count = n
end

function M.push(timestamp, eDPS, ShDPS, crit, noncrit,
                src_groups, eos_abilities, dtype_groups, dtype_abilities, shield_abilities, targets)
  local slot   = state.data[state.write]
  slot.t       = timestamp
  slot.eDPS    = eDPS
  slot.ShDPS   = ShDPS
  slot.crit    = crit or 0
  slot.noncrit = noncrit or 0

  copy_groups(slot.eos_groups,       src_groups)
  copy_abilities(slot.eos_abilities, eos_abilities)
  copy_groups(slot.dtype_groups,     dtype_groups)
  copy_abilities(slot.dtype_abilities, dtype_abilities)
  copy_abilities(slot.shield_abilities, shield_abilities)
  copy_targets(slot.targets, targets)

  state.write = (state.write % state.capacity) + 1
  if state.count < state.capacity then
    state.count = state.count + 1
  end
  state.gen = state.gen + 1
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

function M.at(i)
  local n = state.count
  if i < 1 or i > n then return nil end
  local cap = state.capacity
  local oldest = (n >= cap) and state.write or 1
  return state.data[((oldest - 1 + i - 1) % cap) + 1]
end

function M.halve()
  local n = state.count
  if n < 2 then return false end
  if n >= state.capacity and state.write ~= 1 then return false end
  local data = state.data
  local off = n % 2
  local keep = (n - off) / 2
  for k = 1, keep do
    local dropped, kept = data[off + 2 * k - 1], data[off + 2 * k]
    kept.mag_in  = kept.mag_in  + dropped.mag_in
    kept.mag_out = kept.mag_out + dropped.mag_out
    kept.sta_in  = kept.sta_in  + dropped.sta_in
    kept.sta_out = kept.sta_out + dropped.sta_out
    data[off + 2 * k] = data[k]
    data[k] = kept
  end
  state.count = keep
  state.write = keep + 1
  state.period = state.period * 2
  state.gen = state.gen + 1
  return true
end

function M.period()       return state.period    end
function M.gen()          return state.gen       end
function M.count()        return state.count     end
function M.capacity()     return state.capacity  end
function M.is_recording() return state.recording end

function M.start_recording(period_ms)
  if state.capacity > state.base then M.init(state.base) end
  state.period = period_ms or 1000
  state.recording = true
  if Vermilion.Logo and Vermilion.Logo.set_recording then Vermilion.Logo.set_recording(true) end
  log:info("start_recording")
end

function M.stop_recording()
  state.recording = false
  if Vermilion.Logo and Vermilion.Logo.set_recording then Vermilion.Logo.set_recording(false) end
  log:info("stop_recording: count=", state.count, "/", state.capacity)
end

local EMPTY_SHARES = { count = 0 }

function M.load_session(samples, period_ms)
  M.clear()
  state.period = period_ms or 1000
  if #samples > state.capacity then
    local base = state.base
    M.init(#samples)
    state.base = base
  end
  for i = 1, #samples do
    local s = samples[i]
    M.push(s.t, s.eDPS, s.ShDPS, s.crit, s.noncrit,
           s.eg or EMPTY_SHARES, s.ea or EMPTY_SHARES,
           s.dg or EMPTY_SHARES, s.da or EMPTY_SHARES, s.sa or EMPTY_SHARES, s.tg or EMPTY_SHARES)
    local slot = M.at(M.count())
    slot.mag, slot.sta = s.mag or 0, s.sta or 0
    slot.mag_in, slot.mag_out = s.mag_in or 0, s.mag_out or 0
    slot.sta_in, slot.sta_out = s.sta_in or 0, s.sta_out or 0
  end
  state.recording = false
  log:info("session loaded: samples=", #samples)
end

function M.clear()
  log:info("clear: discarding", state.count, "samples")
  state.write = 1
  state.count = 0
  state.gen = state.gen + 1
end
