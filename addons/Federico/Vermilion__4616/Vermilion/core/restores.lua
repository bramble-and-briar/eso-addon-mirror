Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Restores = {}
local M = Vermilion.Restores

local log = Vermilion.Log.for_module("restores")

local CAP = 4000
local AMT_CAP = 65535
local MAG, STA = 1, 2

local recording = false
local n = 0
local rest_t, rest_id, rest_pool, rest_amt = {}, {}, {}, {}
local regen = { 0, 0 }
local acc = {}

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function now_ms() return Vermilion.zenimax.api.GetGameTimeMilliseconds() end

local function pool_of(powerType)
  local zc = Vermilion.zenimax.constants
  if powerType == nil then return 0 end
  if powerType == zc.COMBAT_MECHANIC_FLAGS_MAGICKA or powerType == zc.POWERTYPE_MAGICKA then return MAG end
  if powerType == zc.COMBAT_MECHANIC_FLAGS_STAMINA or powerType == zc.POWERTYPE_STAMINA then return STA end
  return 0
end

function M.on_energize(abilityId, powerType, amount)
  bump("restores.energize")
  if not recording or n >= CAP then return end
  local pool = pool_of(powerType)
  amount = amount or 0
  if pool == 0 or amount <= 0 then return end
  if amount > AMT_CAP then amount = AMT_CAP end
  n = n + 1
  rest_t[n], rest_id[n], rest_pool[n], rest_amt[n] = now_ms(), abilityId or 0, pool, amount
end

local function read_regen()
  local api, zc = Vermilion.zenimax.api, Vermilion.zenimax.constants
  regen[MAG], regen[STA] = 0, 0
  if not api.GetPlayerStat then return end
  local opt = zc.STAT_BONUS_OPTION_APPLY_BONUS
  if zc.STAT_MAGICKA_REGEN_COMBAT then regen[MAG] = api.GetPlayerStat(zc.STAT_MAGICKA_REGEN_COMBAT, opt) or 0 end
  if zc.STAT_STAMINA_REGEN_COMBAT then regen[STA] = api.GetPlayerStat(zc.STAT_STAMINA_REGEN_COMBAT, opt) or 0 end
end

function M.start_session()
  recording = true
  n = 0
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
  regen[MAG], regen[STA] = 0, 0
end

function M.records() return rest_t, rest_id, rest_pool, rest_amt, n end
function M.count() return n end
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
  for i = 1, n do
    if pool == nil or rest_pool[i] == pool then total = total + rest_amt[i] end
  end
  return total
end

function M.report_lines()
  return {
    string.format("restores=%d recording=%s regen=%d/%d energize_events=%d", n, tostring(recording),
      regen[MAG], regen[STA], Vermilion.Diagnostics.get("restores.energize")),
  }
end

function M.init()
  local zev, zc = Vermilion.zenimax.events, Vermilion.zenimax.constants
  if not (zc.EVENT_COMBAT_EVENT and zc.ACTION_RESULT_POWER_ENERGIZE) then
    log:warn("no energize combat result on this client; restore tracker disabled")
    return
  end
  zev.register("Vermilion_E_Energize", zc.EVENT_COMBAT_EVENT,
    function(_result, _err, _name, _g, _slot, _src, _st, _tgt, _tt, hitValue, powerType, _dt, _log, _suid, _tuid, abilityId)
      M.on_energize(abilityId, powerType, hitValue)
    end)
  zev.add_filter("Vermilion_E_Energize", zc.EVENT_COMBAT_EVENT, zc.REGISTER_FILTER_COMBAT_RESULT, zc.ACTION_RESULT_POWER_ENERGIZE)
  zev.add_filter("Vermilion_E_Energize", zc.EVENT_COMBAT_EVENT, zc.REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, zc.COMBAT_UNIT_TYPE_PLAYER)
  zev.add_filter("Vermilion_E_Energize", zc.EVENT_COMBAT_EVENT, zc.REGISTER_FILTER_IS_ERROR, false)
  read_regen()
  log:info("init: regen", regen[MAG], regen[STA])
end
