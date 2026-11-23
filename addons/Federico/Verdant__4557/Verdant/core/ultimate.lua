Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Ultimate = {}
local M = Verdant.Ultimate

local log = Verdant.Log.for_module("ultimate")

local STEP_QUANT_MS = 250
local STEP_CAP      = 4800
local USED_CAP      = 100
local ABIL_CAP      = 64
local BARS          = 2
local FULL_BAR      = 500

local recording = false
local t_start   = 0
local t_end     = 0
local cur_value = 0
local cur_max   = 500
local saw_power = false
local n_steps   = 0
local step_t    = {}
local step_v    = {}
local n_used    = 0
local used_t    = {}
local used_bar  = {}
local n_abil    = 0
local abil_t    = {}
local abil_bar  = {}
local abil_id   = {}
local abil_cost = {}
local bar_id    = { 0, 0 }
local bar_cost  = { 0, 0 }

local function bump(key) Verdant.Diagnostics.bump(key) end

local function now_ms()
  return Verdant.zenimax.api.GetGameTimeMilliseconds()
end

local function bar_category(b)
  local zc = Verdant.zenimax.constants
  if b == 2 then return zc.HOTBAR_CATEGORY_BACKUP end
  return zc.HOTBAR_CATEGORY_PRIMARY
end

local function active_bar()
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
  if api.GetActiveHotbarCategory and zc.HOTBAR_CATEGORY_BACKUP then
    if api.GetActiveHotbarCategory() == zc.HOTBAR_CATEGORY_BACKUP then return 2 end
  end
  return 1
end

local function push_step(t)
  if n_steps > 0 and (t - step_t[n_steps]) < STEP_QUANT_MS then
    step_v[n_steps] = cur_value
    return
  end
  if n_steps >= STEP_CAP then return end
  n_steps = n_steps + 1
  step_t[n_steps] = t
  step_v[n_steps] = cur_value
end

local function push_ability(t, b, id, cost)
  if n_abil >= ABIL_CAP then return end
  n_abil = n_abil + 1
  abil_t[n_abil]    = t
  abil_bar[n_abil]  = b
  abil_id[n_abil]   = id
  abil_cost[n_abil] = cost
end

function M.refresh_slots()
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
  if not (zc.ACTION_BAR_ULTIMATE_SLOT_INDEX and zc.COMBAT_MECHANIC_FLAGS_ULTIMATE) then return end
  local slot = zc.ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
  for b = 1, BARS do
    local cat  = bar_category(b)
    local id   = api.GetSlotBoundId and api.GetSlotBoundId(slot, cat) or 0
    local cost = api.GetSlotAbilityCost
                 and api.GetSlotAbilityCost(slot, zc.COMBAT_MECHANIC_FLAGS_ULTIMATE, cat) or 0
    id   = id   or 0
    cost = cost or 0
    if id > 0 and (id ~= bar_id[b] or cost ~= bar_cost[b]) then
      bar_id[b]   = id
      bar_cost[b] = cost
      bump("ult.slot_refresh")
      log:info("bar", b, "ultimate ->", id, "cost", cost)
      if recording then push_ability(now_ms(), b, id, cost) end
    end
  end
end

M.refresh_cost = M.refresh_slots

function M.on_power(value, powerMax, effectiveMax)
  bump("ult.power_updates")
  cur_value = value or 0
  if effectiveMax and effectiveMax > 0 then
    cur_max = effectiveMax
  elseif powerMax and powerMax > 0 then
    cur_max = powerMax
  end
  saw_power = true
  if recording then push_step(now_ms()) end
end

function M.on_used()
  bump("ult.used")
  if not recording or n_used >= USED_CAP then return end
  n_used = n_used + 1
  used_t[n_used]   = now_ms()
  used_bar[n_used] = active_bar()
end

function M.start_session(t)
  recording = true
  t_start   = t
  t_end     = 0
  n_steps   = 0
  n_used    = 0
  n_abil    = 0
  saw_power = false
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
  if api.GetUnitPower and zc.COMBAT_MECHANIC_FLAGS_ULTIMATE then
    local v = api.GetUnitPower("player", zc.COMBAT_MECHANIC_FLAGS_ULTIMATE)
    if v then cur_value = v end
  end
  bar_id[1], bar_id[2], bar_cost[1], bar_cost[2] = 0, 0, 0, 0
  M.refresh_slots()
  push_step(t)
end

function M.finalize(t)
  if not recording then return end
  recording = false
  t_end = t
  log:info("session finalize: steps=", n_steps, "used=", n_used, "abilities=", n_abil)
end

function M.reset()
  recording = false
  t_start   = 0
  t_end     = 0
  n_steps   = 0
  n_used    = 0
  n_abil    = 0
  saw_power = false
end

function M.steps()      return step_t, step_v, n_steps end
function M.used()       return used_t, used_bar, n_used end
function M.abilities()  return abil_t, abil_bar, abil_id, abil_cost, n_abil end
function M.has_data()   return saw_power and n_steps > 0 end
function M.cost(b)      return bar_cost[b or active_bar()] end
function M.bar_id(b)    return bar_id[b or active_bar()] end
function M.active_bar() return active_bar() end
function M.is_recording() return recording end

function M.load_session(steps, used, abilities, dur_ms)
  M.reset()
  t_end = dur_ms or 0
  for i = 1, #steps do
    local r = steps[i]
    step_t[i] = r.t
    step_v[i] = r.v or math.floor((r.p or 0) * 500 + 0.5)
  end
  n_steps = #steps
  used = used or {}
  for i = 1, #used do
    used_t[i]   = used[i].t
    used_bar[i] = used[i].bar or 1
  end
  n_used = #used
  abilities = abilities or {}
  for i = 1, #abilities do
    local r = abilities[i]
    abil_t[i]    = r.t
    abil_bar[i]  = r.bar or 1
    abil_id[i]   = r.id or 0
    abil_cost[i] = r.cost or 0
  end
  n_abil = #abilities
  saw_power = n_steps > 0
  log:info("session loaded: steps=", n_steps, "used=", n_used, "abilities=", n_abil)
end

function M.value_at(t)
  if n_steps == 0 then return 0 end
  if t < step_t[1] then return step_v[1] end
  local lo, hi = 1, n_steps
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if step_t[mid] <= t then lo = mid else hi = mid - 1 end
  end
  return step_v[lo]
end

function M.cost_at(b, t)
  local c = 0
  for i = 1, n_abil do
    if abil_bar[i] == b and abil_t[i] <= t then c = abil_cost[i] end
  end
  if c <= 0 then c = FULL_BAR end
  return c
end

function M.id_at(b, t)
  local id = 0
  for i = 1, n_abil do
    if abil_bar[i] == b and abil_t[i] <= t then id = abil_id[i] end
  end
  return id
end

function M.pct_at(t, b)
  local p = M.value_at(t) / M.cost_at(b or 1, t)
  if p > 1 then p = 1 end
  if p < 0 then p = 0 end
  return p
end

local sum_scratch = { ready_ms = 0, dur_ms = 0, ready_pct = 0, casts = 0, mean_gap_ms = 0 }

function M.summary()
  local r = sum_scratch
  r.ready_ms, r.dur_ms, r.ready_pct, r.casts, r.mean_gap_ms = 0, 0, 0, n_used, 0
  if n_steps == 0 then return r end
  local t_lo = (t_start > 0) and t_start or step_t[1]
  local t_hi = (t_end > 0) and t_end or step_t[n_steps]
  if n_used > 0 and used_t[n_used] > t_hi then t_hi = used_t[n_used] end
  if t_hi <= t_lo then return r end
  r.dur_ms = t_hi - t_lo
  local ready = 0
  for i = 1, n_steps do
    local t0 = step_t[i]
    local t1 = (i < n_steps) and step_t[i + 1] or t_hi
    if t1 > t0 then
      local c = M.cost_at(1, t0)
      if n_abil > 0 then
        local c2 = M.cost_at(2, t0)
        if c2 > 0 and c2 < c then c = c2 end
      end
      if step_v[i] >= c then ready = ready + (t1 - t0) end
    end
  end
  r.ready_ms  = ready
  r.ready_pct = ready / r.dur_ms
  if n_used > 1 then
    r.mean_gap_ms = (used_t[n_used] - used_t[1]) / (n_used - 1)
  end
  return r
end

function M.snapshot()
  local a = active_bar()
  return {
    recording = recording, cost = bar_cost[a], value = cur_value, max = cur_max,
    steps = n_steps, used = n_used, abilities = n_abil, ability = bar_id[a],
    bars = { bar_id[1], bar_id[2] }, costs = { bar_cost[1], bar_cost[2] },
    t_start = t_start, t_end = t_end,
  }
end

function M.report_lines()
  local dur_s = 0
  if t_start > 0 then
    local t_hi = (t_end > 0) and t_end or now_ms()
    dur_s = (t_hi - t_start) / 1000
  end
  local rate = (dur_s > 0) and (Verdant.Diagnostics.get("ult.power_updates") / dur_s) or 0
  return {
    string.format("bars=%d/%d costs=%d/%d value=%d steps=%d used=%d abilities=%d power_rate=%.1f/s",
      bar_id[1], bar_id[2], bar_cost[1], bar_cost[2], cur_value, n_steps, n_used, n_abil, rate),
  }
end

function M.init()
  local zev = Verdant.zenimax.events
  local zc  = Verdant.zenimax.constants
  if not zc.COMBAT_MECHANIC_FLAGS_ULTIMATE then
    log:warn("no ultimate power type on this client; tracker disabled")
    return
  end
  zev.register("Verdant_E_UltPower", zc.EVENT_POWER_UPDATE,
    function(_unitTag, _idx, _ptype, value, powerMax, effectiveMax)
      M.on_power(value, powerMax, effectiveMax)
    end)
  zev.add_filter("Verdant_E_UltPower", zc.EVENT_POWER_UPDATE,
    zc.REGISTER_FILTER_POWER_TYPE, zc.COMBAT_MECHANIC_FLAGS_ULTIMATE)
  zev.add_filter("Verdant_E_UltPower", zc.EVENT_POWER_UPDATE,
    zc.REGISTER_FILTER_UNIT_TAG, "player")

  zev.register("Verdant_E_UltUsed", zc.EVENT_ACTION_SLOT_ABILITY_USED,
    function(actionSlotIndex)
      if zc.ACTION_BAR_ULTIMATE_SLOT_INDEX
         and actionSlotIndex == zc.ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 then
        M.on_used()
      end
    end)

  zev.register("Verdant_E_UltBars", zc.EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
    function() M.refresh_slots() end)

  M.refresh_slots()
  log:info("init: bars=", bar_id[1], bar_id[2], "costs=", bar_cost[1], bar_cost[2])
end
