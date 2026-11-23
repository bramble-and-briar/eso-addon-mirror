Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Restores = {}
local M = Verdant.Restores

local log = Verdant.Log.for_module("restores")

local AMT_CAP = 65535
local LOOK_EVERY = 512
local MAG, STA = 1, 2

local recording = false
local n = 0
local look_at = LOOK_EVERY
local rest_t, rest_id, rest_pool, rest_amt = {}, {}, {}, {}
local regen = { 0, 0 }
local acc = {}

local function bump(key) Verdant.Diagnostics.bump(key) end

local function now_ms() return Verdant.zenimax.api.GetGameTimeMilliseconds() end

local function pool_of(powerType)
  local zc = Verdant.zenimax.constants
  if powerType == nil then return 0 end
  if powerType == zc.COMBAT_MECHANIC_FLAGS_MAGICKA then return MAG end
  if powerType == zc.COMBAT_MECHANIC_FLAGS_STAMINA then return STA end
  return 0
end

local function first_kept()
  local from = Verdant.TemporalBuffer.kept_from()
  local i = 1
  while i <= n and rest_t[i] < from do i = i + 1 end
  return i
end

local function let_go()
  local first = first_kept()
  if first > 1 then
    local held = n - first + 1
    for i = 1, held do
      local j = first + i - 1
      rest_t[i], rest_id[i], rest_pool[i], rest_amt[i] = rest_t[j], rest_id[j], rest_pool[j], rest_amt[j]
    end
    bump("restores.forgotten_with_the_film", n - held)
    n = held
  end
  look_at = n + LOOK_EVERY
end

function M.on_energize(abilityId, powerType, amount)
  bump("restores.energize")
  if not recording then return end
  local pool = pool_of(powerType)
  amount = amount or 0
  if pool == 0 or amount <= 0 then return end
  if amount > AMT_CAP then
    bump("restores.amount_clamped")
    amount = AMT_CAP
  end
  if n >= look_at then let_go() end
  n = n + 1
  rest_t[n], rest_id[n], rest_pool[n], rest_amt[n] = now_ms(), abilityId or 0, pool, amount
end

local function read_regen()
  local api, zc = Verdant.zenimax.api, Verdant.zenimax.constants
  regen[MAG], regen[STA] = 0, 0
  if not api.GetPlayerStat then return end
  local opt = zc.STAT_BONUS_OPTION_APPLY_BONUS
  if zc.STAT_MAGICKA_REGEN_COMBAT then regen[MAG] = api.GetPlayerStat(zc.STAT_MAGICKA_REGEN_COMBAT, opt) or 0 end
  if zc.STAT_STAMINA_REGEN_COMBAT then regen[STA] = api.GetPlayerStat(zc.STAT_STAMINA_REGEN_COMBAT, opt) or 0 end
end

function M.start_session()
  recording = true
  n = 0
  look_at = LOOK_EVERY
  read_regen()
end

function M.finalize()
  if not recording then return end
  recording = false
  log:info("session finalize: restores=", n, "regen", regen[MAG], regen[STA])
end

function M.reset()
  recording = false
  n = 0
  look_at = LOOK_EVERY
  regen[MAG], regen[STA] = 0, 0
end

function M.records() return rest_t, rest_id, rest_pool, rest_amt, n end
function M.count() return n end
function M.first() return first_kept() end
function M.regen(p) return regen[p] or 0 end
function M.is_recording() return recording end

function M.load_session(recs, regen_in)
  M.reset()
  recs = recs or {}
  for i = 1, #recs do
    local r = recs[i]
    rest_t[i]    = r.t or 0
    rest_id[i]   = r.id or 0
    rest_pool[i] = r.pool or 0
    rest_amt[i]  = r.amt or 0
  end
  n = #recs
  if regen_in then
    regen[MAG] = regen_in.mag or 0
    regen[STA] = regen_in.sta or 0
  end
  log:info("session loaded: restores=", n)
end

function M.top(t_lo, t_hi, pool)
  for k in pairs(acc) do acc[k] = nil end
  local best_id, best = 0, 0
  for i = 1, n do
    local t = rest_t[i]
    if t >= t_lo and t < t_hi and (pool == nil or rest_pool[i] == pool) then
      local id = rest_id[i]
      local v = (acc[id] or 0) + rest_amt[i]
      acc[id] = v
      if v > best then best, best_id = v, id end
    end
  end
  return best_id, best
end

function M.sum(pool)
  local total = 0
  for i = first_kept(), n do
    if pool == nil or rest_pool[i] == pool then total = total + rest_amt[i] end
  end
  return total
end

function M.init()
  local zev, zc = Verdant.zenimax.events, Verdant.zenimax.constants
  if not (zc.EVENT_COMBAT_EVENT and zc.ACTION_RESULT_POWER_ENERGIZE) then
    log:warn("no energize combat result on this client; restore tracker disabled")
    return
  end
  zev.register("Verdant_E_Energize", zc.EVENT_COMBAT_EVENT,
    function(_result, _err, _name, _g, _slot, _src, _st, _tgt, _tt, hitValue, powerType, _dt, _log, _suid, _tuid, abilityId)
      M.on_energize(abilityId, powerType, hitValue)
    end)
  zev.add_filter("Verdant_E_Energize", zc.EVENT_COMBAT_EVENT, zc.REGISTER_FILTER_COMBAT_RESULT, zc.ACTION_RESULT_POWER_ENERGIZE)
  zev.add_filter("Verdant_E_Energize", zc.EVENT_COMBAT_EVENT, zc.REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, zc.COMBAT_UNIT_TYPE_PLAYER)
  zev.add_filter("Verdant_E_Energize", zc.EVENT_COMBAT_EVENT, zc.REGISTER_FILTER_IS_ERROR, false)
  read_regen()
  log:info("init: regen", regen[MAG], regen[STA])
end
