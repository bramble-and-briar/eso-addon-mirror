Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Resources = {}
local M = Vermilion.Resources

local log = Vermilion.Log.for_module("resources")

local MAG, STA = 1, 2
local FLOW_CAP = 65535
local LOW = 0.15
local GRACE_MS = 200
local DEATH_DROP = 0.1

local recording = false
local cur    = { 0, 0 }
local max    = { 1, 1 }
local gained = { 0, 0 }
local spent  = { 0, 0 }
local seen   = { false, false }
local saw_any = false
local dead = false
local grace = { 0, 0 }
local deaths_t = {}
local deaths_end = {}
local n_deaths = 0
local DEATH_CAP = 256
local tot_in, tot_out = { 0, 0 }, { 0, 0 }
local first_in = { 0, 0 }
local hit_in, hit_out = { 0, 0 }, { 0, 0 }
local first_hit_t, last_hit_t = nil, nil
local frame_t = nil
local frame_in = { 0, 0 }
local flow_now = { mag_in = 0, mag_out = 0, sta_in = 0, sta_out = 0, mag_low_ms = 0, sta_low_ms = 0 }
local low_ms = { 0, 0 }
local low_since = { false, false }
local low_first, low_last = { 0, 0 }, { 0, 0 }

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function now_ms() return Vermilion.zenimax.api.GetGameTimeMilliseconds() end

local function clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function low_total(p, t)
  local since = low_since[p]
  if since and t > since then return low_ms[p] + (t - since) end
  return low_ms[p]
end

local function mark_low(p, now)
  if not dead and seen[p] and cur[p] < max[p] * LOW then
    if not low_since[p] then low_since[p] = now end
  elseif low_since[p] then
    low_ms[p] = low_total(p, now)
    low_since[p] = false
  end
end

function M.on_power(p, value, powerMax, effectiveMax)
  bump("res.power_updates")
  value = value or 0
  local now = now_ms()
  if now ~= frame_t then
    frame_t = now
    frame_in[MAG], frame_in[STA] = tot_in[MAG], tot_in[STA]
  end
  local mx = max[p]
  if effectiveMax and effectiveMax > 0 then mx = effectiveMax
  elseif powerMax and powerMax > 0 then mx = powerMax end
  if dead then
    local api = Vermilion.zenimax.api
    if api.IsUnitDead and not api.IsUnitDead("player") then M.on_death(false) end
  end
  if seen[p] and not dead then
    local d = value - cur[p]
    if d < 0 then
      local cast = Vermilion.Casts.on_drop(p, -d, now)
      if value == 0 and not cast and -d >= mx * DEATH_DROP then
        grace[p] = now + GRACE_MS
      else
        spent[p] = spent[p] - d
        tot_out[p] = tot_out[p] - d
      end
    elseif d > 0 then
      Vermilion.Casts.on_gain(p, d, now)
      if now >= grace[p] then
        gained[p] = gained[p] + d
        tot_in[p] = tot_in[p] + d
      end
    end
    if now == last_hit_t then
      hit_in[p], hit_out[p] = tot_in[p], tot_out[p]
    end
  end
  cur[p] = value
  max[p] = mx
  seen[p] = true
  saw_any = true
  mark_low(p, now)
end

local function flow(v)
  if v > FLOW_CAP then return FLOW_CAP end
  return v
end

local function clear_flow()
  tot_in[MAG], tot_in[STA], tot_out[MAG], tot_out[STA] = 0, 0, 0, 0
  first_in[MAG], first_in[STA] = 0, 0
  hit_in[MAG], hit_in[STA], hit_out[MAG], hit_out[STA] = 0, 0, 0, 0
  first_hit_t, last_hit_t = nil, nil
  frame_t = nil
  frame_in[MAG], frame_in[STA] = 0, 0
end

function M.note_hit(t)
  if not recording then return end
  if not first_hit_t then
    first_hit_t = t
    if frame_t == t then
      first_in[MAG], first_in[STA] = frame_in[MAG], frame_in[STA]
    else
      first_in[MAG], first_in[STA] = tot_in[MAG], tot_in[STA]
    end
    low_first[MAG], low_first[STA] = low_total(MAG, t), low_total(STA, t)
  end
  last_hit_t = t
  low_last[MAG], low_last[STA] = low_total(MAG, t), low_total(STA, t)
  hit_in[MAG], hit_in[STA] = tot_in[MAG], tot_in[STA]
  hit_out[MAG], hit_out[STA] = tot_out[MAG], tot_out[STA]
end

local function live_flow()
  flow_now.mag_in = hit_in[MAG] - first_in[MAG]
  flow_now.sta_in = hit_in[STA] - first_in[STA]
  flow_now.mag_out = hit_out[MAG]
  flow_now.sta_out = hit_out[STA]
  flow_now.mag_low_ms = low_last[MAG] - low_first[MAG]
  flow_now.sta_low_ms = low_last[STA] - low_first[STA]
  return flow_now
end

function M.exact_flow()
  local Me = Vermilion.Metrics
  if Me.is_loaded() then
    local ex = Me.exact()
    return ex and ex.pool or nil
  end
  if not last_hit_t then return nil end
  return live_flow()
end

function M.flow_copy()
  if not last_hit_t then return nil end
  local f = live_flow()
  return { mag_in = f.mag_in, mag_out = f.mag_out, sta_in = f.sta_in, sta_out = f.sta_out,
           mag_low_ms = f.mag_low_ms, sta_low_ms = f.sta_low_ms }
end

function M.sample_into(slot)
  if not slot then return end
  Vermilion.Casts.settle(now_ms())
  slot.mag     = seen[MAG] and clamp01(cur[MAG] / max[MAG]) or 0
  slot.sta     = seen[STA] and clamp01(cur[STA] / max[STA]) or 0
  slot.mag_in  = flow(gained[MAG])
  slot.mag_out = flow(spent[MAG])
  slot.sta_in  = flow(gained[STA])
  slot.sta_out = flow(spent[STA])
  gained[MAG], gained[STA], spent[MAG], spent[STA] = 0, 0, 0, 0
end

function M.on_death(is_dead)
  if is_dead then
    if dead then return end
    dead = true
    if recording and n_deaths < DEATH_CAP then
      n_deaths = n_deaths + 1
      deaths_t[n_deaths] = now_ms()
      deaths_end[n_deaths] = 0
    end
  elseif dead then
    dead = false
    if n_deaths > 0 and deaths_end[n_deaths] == 0 then deaths_end[n_deaths] = now_ms() end
    local until_ms = now_ms() + GRACE_MS
    grace[MAG], grace[STA] = until_ms, until_ms
  else
    return
  end
  local t = now_ms()
  mark_low(MAG, t)
  mark_low(STA, t)
end

function M.deaths() return deaths_t, n_deaths, deaths_end end

function M.dead_ms(lo, hi)
  local total, count = 0, 0
  for i = 1, n_deaths do
    local a, b = deaths_t[i], deaths_end[i]
    if b == 0 then b = hi end
    if a < lo then a = lo end
    if b > hi then b = hi end
    if b > a then
      total = total + (b - a)
      count = count + 1
    end
  end
  return total, count
end
function M.is_dead() return dead end

function M.load_session(recs)
  recs = recs or {}
  for i = 1, #recs do
    deaths_t[i] = recs[i].t or 0
    deaths_end[i] = recs[i].e or deaths_t[i]
  end
  n_deaths = #recs
end

local function seed(p, ptype)
  local api = Vermilion.zenimax.api
  if not (api.GetUnitPower and ptype) then return end
  local v, mx, emx = api.GetUnitPower("player", ptype)
  if v and v > 0 then
    cur[p] = v
    if emx and emx > 0 then max[p] = emx elseif mx and mx > 0 then max[p] = mx end
    seen[p] = true
    saw_any = true
  end
end

function M.start_session()
  recording = true
  saw_any = false
  n_deaths = 0
  grace[MAG], grace[STA] = 0, 0
  seen[MAG], seen[STA] = false, false
  gained[MAG], gained[STA], spent[MAG], spent[STA] = 0, 0, 0, 0
  clear_flow()
  local zc = Vermilion.zenimax.constants
  seed(MAG, zc.POWERTYPE_MAGICKA)
  seed(STA, zc.POWERTYPE_STAMINA)
  local t = now_ms()
  mark_low(MAG, t)
  mark_low(STA, t)
end

function M.finalize()
  if not recording then return end
  recording = false
  log:info("session finalize: magicka", seen[MAG] and cur[MAG] or "-", "stamina", seen[STA] and cur[STA] or "-")
end

function M.reset()
  recording = false
  saw_any = false
  n_deaths = 0
  grace[MAG], grace[STA] = 0, 0
  seen[MAG], seen[STA] = false, false
  gained[MAG], gained[STA], spent[MAG], spent[STA] = 0, 0, 0, 0
  clear_flow()
end

function M.saw() return saw_any end
function M.is_recording() return recording end
function M.level(p) return seen[p] and clamp01(cur[p] / max[p]) or 0 end
function M.low() return LOW end

local sum_scratch = {
  has = false, n = 0,
  mag_in = 0, mag_out = 0, mag_sigma = 0, mag_low = 0, mag_low_pct = 0,
  sta_in = 0, sta_out = 0, sta_sigma = 0, sta_low = 0, sta_low_pct = 0,
  damage = 0, eff = 0,
}

function M.summary(TB)
  local r = sum_scratch
  r.has, r.n = false, 0
  r.mag_in, r.mag_out, r.mag_sigma, r.mag_low, r.mag_low_pct = 0, 0, 0, 0, 0
  r.sta_in, r.sta_out, r.sta_sigma, r.sta_low, r.sta_low_pct = 0, 0, 0, 0, 0
  r.damage, r.eff = 0, 0
  local n = TB.count()
  local prev_t = nil
  local lo, hi = Vermilion.Metrics.fight_bounds()
  local inside, mag_zero, sta_zero, mag_known, sta_known = 0, 0, 0, false, false
  local di = 1
  for i = 1, n do
    local s = TB.at(i)
    if prev_t then r.damage = r.damage + ((s.eDPS or 0) + (s.ShDPS or 0)) * (s.t - prev_t) / 1000 end
    prev_t = s.t
    local m, st = s.mag or 0, s.sta or 0
    if m > 0 or st > 0 then r.has = true end
    r.mag_in  = r.mag_in  + (s.mag_in  or 0)
    r.mag_out = r.mag_out + (s.mag_out or 0)
    r.sta_in  = r.sta_in  + (s.sta_in  or 0)
    r.sta_out = r.sta_out + (s.sta_out or 0)
    if m > 0 then mag_known = true end
    if st > 0 then sta_known = true end
    while di <= n_deaths and deaths_end[di] > 0 and deaths_end[di] < s.t do di = di + 1 end
    local is_dead = di <= n_deaths and s.t >= deaths_t[di]
    if (not lo or (s.t >= lo and s.t <= hi)) and not is_dead then
      inside = inside + 1
      if m == 0 then mag_zero = mag_zero + 1 elseif m < LOW then r.mag_low = r.mag_low + 1 end
      if st == 0 then sta_zero = sta_zero + 1 elseif st < LOW then r.sta_low = r.sta_low + 1 end
    end
  end
  r.n = n
  r.damage = Vermilion.Metrics.output_total() or r.damage
  local flow = M.exact_flow()
  if flow then
    r.mag_in, r.mag_out = flow.mag_in, flow.mag_out
    r.sta_in, r.sta_out = flow.sta_in, flow.sta_out
  end
  if mag_known then r.mag_low = r.mag_low + mag_zero end
  if sta_known then r.sta_low = r.sta_low + sta_zero end
  if flow and flow.mag_low_ms and lo then
    local alive = (hi - lo) - M.dead_ms(lo, hi)
    if alive > 0 then
      r.mag_low_pct = flow.mag_low_ms / alive
      r.sta_low_pct = flow.sta_low_ms / alive
    end
  elseif inside > 0 then
    r.mag_low_pct = r.mag_low / inside
    r.sta_low_pct = r.sta_low / inside
  end
  if r.mag_out > 0 then r.mag_sigma = r.mag_in / r.mag_out end
  if r.sta_out > 0 then r.sta_sigma = r.sta_in / r.sta_out end
  local out = r.mag_out + r.sta_out
  if out > 0 then r.eff = r.damage / out * 1000 end
  return r
end

function M.window_sigma(TB, idx, back, p)
  local lo = idx - back + 1
  if lo < 1 then lo = 1 end
  local gin, gout = 0, 0
  for i = lo, idx do
    local s = TB.at(i)
    if p == MAG then gin = gin + (s.mag_in or 0); gout = gout + (s.mag_out or 0)
    else gin = gin + (s.sta_in or 0); gout = gout + (s.sta_out or 0) end
  end
  if gout <= 0 then return nil, gin, gout end
  return gin / gout, gin, gout
end

function M.report_lines()
  return {
    string.format("magicka %d/%d (%s)  stamina %d/%d (%s)  updates=%d",
      cur[MAG], max[MAG], seen[MAG] and "seen" or "unseen",
      cur[STA], max[STA], seen[STA] and "seen" or "unseen",
      Vermilion.Diagnostics.get("res.power_updates")),
  }
end

local function register(name, p, ptype)
  local zev = Vermilion.zenimax.events
  local zc  = Vermilion.zenimax.constants
  zev.register(name, zc.EVENT_POWER_UPDATE,
    function(_unitTag, _idx, _ptype, value, powerMax, effectiveMax)
      M.on_power(p, value, powerMax, effectiveMax)
    end)
  zev.add_filter(name, zc.EVENT_POWER_UPDATE, zc.REGISTER_FILTER_POWER_TYPE, ptype)
  zev.add_filter(name, zc.EVENT_POWER_UPDATE, zc.REGISTER_FILTER_UNIT_TAG, "player")
end

function M.init()
  local zc = Vermilion.zenimax.constants
  if zc.POWERTYPE_MAGICKA == nil or zc.POWERTYPE_STAMINA == nil then
    log:warn("no magicka or stamina power type on this client; tracker disabled")
    return
  end
  register("Vermilion_E_ResMag", MAG, zc.POWERTYPE_MAGICKA)
  register("Vermilion_E_ResSta", STA, zc.POWERTYPE_STAMINA)
  if zc.EVENT_UNIT_DEATH_STATE_CHANGED then
    local zev = Vermilion.zenimax.events
    zev.register("Vermilion_E_ResDeath", zc.EVENT_UNIT_DEATH_STATE_CHANGED, function(unitTag, isDead)
      if unitTag == "player" then M.on_death(isDead == true) end
    end)
    zev.add_filter("Vermilion_E_ResDeath", zc.EVENT_UNIT_DEATH_STATE_CHANGED, zc.REGISTER_FILTER_UNIT_TAG, "player")
  end
  seed(MAG, zc.POWERTYPE_MAGICKA)
  seed(STA, zc.POWERTYPE_STAMINA)
  log:info("init: magicka", cur[MAG], "/", max[MAG], "stamina", cur[STA], "/", max[STA])
end
