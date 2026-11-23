Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Resources = {}
local M = Verdant.Resources

local log = Verdant.Log.for_module("resources")

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

local function now_ms() return Verdant.zenimax.api.GetGameTimeMilliseconds() end

local function clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function flow(v)
  if v > FLOW_CAP then return FLOW_CAP end
  return v
end

function M.on_power(p, value, powerMax, effectiveMax)
  Verdant.Diagnostics.bump("res.power_updates")
  value = value or 0
  local now = now_ms()
  local mx = max[p]
  if effectiveMax and effectiveMax > 0 then mx = effectiveMax
  elseif powerMax and powerMax > 0 then mx = powerMax end
  if dead then
    local api = Verdant.zenimax.api
    if api.IsUnitDead and not api.IsUnitDead("player") then M.on_death(false) end
  end
  if seen[p] and not dead then
    local d = value - cur[p]
    if d < 0 then
      local cast = Verdant.Casts.on_drop(p, -d, now)
      if value == 0 and not cast and -d >= mx * DEATH_DROP then
        grace[p] = now + GRACE_MS
      else
        spent[p] = spent[p] - d
      end
    elseif d > 0 then
      Verdant.Casts.on_gain(p, d, now)
      if now >= grace[p] then gained[p] = gained[p] + d end
    end
  end
  cur[p] = value
  max[p] = mx
  seen[p] = true
  saw_any = true
end

function M.sample_into(slot)
  if not slot then return end
  Verdant.Casts.settle(now_ms())
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
    dead = true
  elseif dead then
    dead = false
    local until_ms = now_ms() + GRACE_MS
    grace[MAG], grace[STA] = until_ms, until_ms
  end
end

function M.is_dead() return dead end

local function seed(p, ptype)
  local api = Verdant.zenimax.api
  if not (api.GetUnitPower and ptype) then return end
  local v, mx, emx = api.GetUnitPower("player", ptype)
  if v and v > 0 then
    cur[p] = v
    if emx and emx > 0 then max[p] = emx elseif mx and mx > 0 then max[p] = mx end
    seen[p] = true
    saw_any = true
  end
end

local function clear()
  saw_any = false
  grace[MAG], grace[STA] = 0, 0
  seen[MAG], seen[STA] = false, false
  gained[MAG], gained[STA], spent[MAG], spent[STA] = 0, 0, 0, 0
end

function M.start_session()
  recording = true
  clear()
  local zc = Verdant.zenimax.constants
  seed(MAG, zc.COMBAT_MECHANIC_FLAGS_MAGICKA)
  seed(STA, zc.COMBAT_MECHANIC_FLAGS_STAMINA)
end

function M.finalize()
  if not recording then return end
  recording = false
  log:info("session finalize: magicka", seen[MAG] and cur[MAG] or "-", "stamina", seen[STA] and cur[STA] or "-")
end

function M.reset()
  recording = false
  clear()
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

function M.saw() return saw_any end
function M.is_recording() return recording end
function M.level(p) return seen[p] and clamp01(cur[p] / max[p]) or 0 end
function M.low() return LOW end

local sum_scratch = {
  has = false, n = 0,
  mag_in = 0, mag_out = 0, mag_sigma = 0, mag_low_pct = 0,
  sta_in = 0, sta_out = 0, sta_sigma = 0, sta_low_pct = 0,
}

function M.summary(TB)
  local r = sum_scratch
  r.has, r.n = false, 0
  r.mag_in, r.mag_out, r.mag_sigma, r.mag_low_pct = 0, 0, 0, 0
  r.sta_in, r.sta_out, r.sta_sigma, r.sta_low_pct = 0, 0, 0, 0
  local n = TB.count()
  local starts, spans, ends = TB.dead_spans()
  local d, alive, mag_low, sta_low = 1, 0, 0, 0
  for i = 1, n do
    local s = TB.at(i)
    local m, st = s.mag or 0, s.sta or 0
    if m > 0 or st > 0 then r.has = true end
    r.mag_in  = r.mag_in  + (s.mag_in  or 0)
    r.mag_out = r.mag_out + (s.mag_out or 0)
    r.sta_in  = r.sta_in  + (s.sta_in  or 0)
    r.sta_out = r.sta_out + (s.sta_out or 0)
    while d <= spans and ends[d] > 0 and ends[d] < s.t do d = d + 1 end
    if not (d <= spans and s.t >= starts[d]) then
      alive = alive + 1
      if m < LOW then mag_low = mag_low + 1 end
      if st < LOW then sta_low = sta_low + 1 end
    end
  end
  r.n = n
  if r.has and alive > 0 then
    r.mag_low_pct = mag_low / alive
    r.sta_low_pct = sta_low / alive
  end
  if r.mag_out > 0 then r.mag_sigma = r.mag_in / r.mag_out end
  if r.sta_out > 0 then r.sta_sigma = r.sta_in / r.sta_out end
  return r
end

function M.report_lines()
  return {
    string.format("magicka %d/%d (%s)  stamina %d/%d (%s)  updates=%d",
      cur[MAG], max[MAG], seen[MAG] and "seen" or "unseen",
      cur[STA], max[STA], seen[STA] and "seen" or "unseen",
      Verdant.Diagnostics.get("res.power_updates")),
  }
end

local function register(name, p, ptype)
  local zev = Verdant.zenimax.events
  local zc  = Verdant.zenimax.constants
  zev.register(name, zc.EVENT_POWER_UPDATE,
    function(_unitTag, _idx, _ptype, value, powerMax, effectiveMax)
      M.on_power(p, value, powerMax, effectiveMax)
    end)
  zev.add_filter(name, zc.EVENT_POWER_UPDATE, zc.REGISTER_FILTER_POWER_TYPE, ptype)
  zev.add_filter(name, zc.EVENT_POWER_UPDATE, zc.REGISTER_FILTER_UNIT_TAG, "player")
end

function M.init()
  local zc = Verdant.zenimax.constants
  if zc.COMBAT_MECHANIC_FLAGS_MAGICKA == nil or zc.COMBAT_MECHANIC_FLAGS_STAMINA == nil then
    log:warn("no magicka or stamina power type on this client; tracker disabled")
    return
  end
  register("Verdant_E_ResMag", MAG, zc.COMBAT_MECHANIC_FLAGS_MAGICKA)
  register("Verdant_E_ResSta", STA, zc.COMBAT_MECHANIC_FLAGS_STAMINA)
  local zev = Verdant.zenimax.events
  zev.register("Verdant_E_ResDeath", zc.EVENT_UNIT_DEATH_STATE_CHANGED, function(unitTag, isDead)
    if unitTag == "player" then M.on_death(isDead == true) end
  end)
  zev.add_filter("Verdant_E_ResDeath", zc.EVENT_UNIT_DEATH_STATE_CHANGED, zc.REGISTER_FILTER_UNIT_TAG, "player")
  seed(MAG, zc.COMBAT_MECHANIC_FLAGS_MAGICKA)
  seed(STA, zc.COMBAT_MECHANIC_FLAGS_STAMINA)
  log:info("init: magicka", cur[MAG], "/", max[MAG], "stamina", cur[STA], "/", max[STA])
end
