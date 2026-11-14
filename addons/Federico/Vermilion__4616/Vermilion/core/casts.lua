Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Casts = {}
local M = Vermilion.Casts

local log = Vermilion.Log.for_module("casts")

local CAP = 4000
local COST_CAP = 65535
local MAG, STA = 1, 2
local PEND_CAP = 8
local PRESS_WINDOW_MS = 1500
local TICK_WINDOW_MS = 1500
local COST_TOLERANCE = 0.15
local BATCH_SLACK = 800
local MIN_SHARE = 0.4
local HOLD_MS = 50
local BLOCK_MS = 20

local recording = false
local n = 0
local cast_t, cast_id, cast_pool, cast_cost, cast_tick = {}, {}, {}, {}, {}
local pend = {
  [MAG] = { n = 0, t = {}, id = {}, cost = {}, chan = {}, last_id = 0, last_cost = 0, last_t = 0, last_start = 0, last_chan = 0 },
  [STA] = { n = 0, t = {}, id = {}, cost = {}, chan = {}, last_id = 0, last_cost = 0, last_t = 0, last_start = 0, last_chan = 0 },
}
local acc = {}
local held = {
  [MAG] = { on = false, t = 0, amt = 0, gain = 0, blocked = false, sid = 0 },
  [STA] = { on = false, t = 0, amt = 0, gain = 0, blocked = false, sid = 0 },
}
local block_t = nil

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function now_ms() return Vermilion.zenimax.api.GetGameTimeMilliseconds() end

local function has_flag(mask, flag)
  if not mask or not flag or flag <= 0 then return false end
  return math.floor(mask / flag) % 2 == 1
end

local function mechanic_cost(api, zc, slot, cat, id, flag)
  local cost = api.GetAbilityCost and api.GetAbilityCost(id, flag, nil, "player")
  if (not cost or cost <= 0) and api.GetSlotAbilityCost then cost = api.GetSlotAbilityCost(slot, flag, cat) end
  return cost or 0
end

local function slot_ability(api, zc, slot, cat)
  local id = api.GetSlotBoundId(slot, cat) or 0
  if id <= 0 then return 0, false end
  if api.GetSlotType and api.GetAbilityIdForCraftedAbilityId and zc.ACTION_TYPE_CRAFTED_ABILITY
     and api.GetSlotType(slot, cat) == zc.ACTION_TYPE_CRAFTED_ABILITY then
    local real = api.GetAbilityIdForCraftedAbilityId(id)
    if real and real > 0 then return real, true end
  end
  return id, false
end

local function slot_cost(api, zc, slot, cat, id)
  local magf, staf = zc.COMBAT_MECHANIC_FLAGS_MAGICKA, zc.COMBAT_MECHANIC_FLAGS_STAMINA
  if api.GetAbilityBaseCostInfo then
    local base, flags = api.GetAbilityBaseCostInfo(id, nil, "player")
    if flags and flags > 0 then
      if has_flag(flags, magf) then
        local cost = mechanic_cost(api, zc, slot, cat, id, magf)
        return MAG, (cost > 0) and cost or (base or 0)
      end
      if has_flag(flags, staf) then
        local cost = mechanic_cost(api, zc, slot, cat, id, staf)
        return STA, (cost > 0) and cost or (base or 0)
      end
      return 0, 0
    end
    if base == 0 then return 0, 0 end
  end
  if not api.GetSlotAbilityCost then return 0, 0 end
  local cm = magf and api.GetSlotAbilityCost(slot, magf, cat) or 0
  local cs = staf and api.GetSlotAbilityCost(slot, staf, cat) or 0
  cm, cs = cm or 0, cs or 0
  if cm <= 0 and cs <= 0 then return 0, 0 end
  if cs <= 0 then return MAG, cm end
  if cm <= 0 then return STA, cs end
  return 0, 0
end

function M.slot_info(slot)
  local api, zc = Vermilion.zenimax.api, Vermilion.zenimax.constants
  if not api.GetSlotBoundId then return 0, 0, 0 end
  local cat = api.GetActiveHotbarCategory and api.GetActiveHotbarCategory() or zc.HOTBAR_CATEGORY_PRIMARY
  local id = slot_ability(api, zc, slot, cat)
  if id <= 0 then return 0, 0, 0 end
  local pool, cost = slot_cost(api, zc, slot, cat, id)
  if not api.GetAbilityCastInfo then return id, pool, cost, 0 end
  local channeled, duration = api.GetAbilityCastInfo(id, nil, "player")
  return id, pool, cost, (channeled and duration) or 0
end

local function push(t, id, pool, cost, tick)
  if n >= CAP then return end
  if cost > COST_CAP then cost = COST_CAP end
  n = n + 1
  local i = n
  while i > 1 and cast_t[i - 1] > t do
    cast_t[i], cast_id[i], cast_pool[i], cast_cost[i], cast_tick[i] = cast_t[i - 1], cast_id[i - 1], cast_pool[i - 1], cast_cost[i - 1], cast_tick[i - 1]
    i = i - 1
  end
  cast_t[i], cast_id[i], cast_pool[i], cast_cost[i], cast_tick[i] = t, id, pool, cost, tick
end

local function pend_remove(q, i)
  for k = i, q.n - 1 do
    q.t[k], q.id[k], q.cost[k], q.chan[k] = q.t[k + 1], q.id[k + 1], q.cost[k + 1], q.chan[k + 1]
  end
  q.n = q.n - 1
end

local function pend_expire(q, t)
  while q.n > 0 and t - q.t[1] > PRESS_WINDOW_MS do pend_remove(q, 1) end
end

local function pend_clear()
  for p = MAG, STA do
    local q = pend[p]
    q.n, q.last_id, q.last_cost, q.last_t, q.last_start, q.last_chan = 0, 0, 0, 0, 0, 0
    held[p].on = false
  end
  block_t = nil
end

local function find(q, amount, slack)
  local best, best_gap = nil, 0
  for i = 1, q.n do
    local cost = q.cost[i]
    local gap = math.abs(amount - cost)
    local room = cost * COST_TOLERANCE
    if slack and room < BATCH_SLACK then room = BATCH_SLACK end
    if gap <= room and amount >= cost * MIN_SHARE and (not best or gap < best_gap) then
      best, best_gap = i, gap
    end
  end
  return best
end

local function accept(q, pool, i, amount, t)
  local id, cost, chan = q.id[i], q.cost[i], q.chan[i]
  for k = q.n, 1, -1 do
    if q.id[k] == id then pend_remove(q, k) end
  end
  push(t, id, pool, amount, 0)
  q.last_id, q.last_cost, q.last_t, q.last_start, q.last_chan = id, cost, t, t, chan
  local other = pend[(pool == MAG) and STA or MAG]
  other.last_id, other.last_chan = 0, 0
end

local function resolve(pool)
  local h = held[pool]
  if not h.on then return end
  h.on = false
  if h.sid > 0 and not h.blocked then
    local q = pend[pool]
    for i = 1, q.n do
      if q.id[i] == h.sid then
        accept(q, pool, i, h.amt, h.t)
        return
      end
    end
  end
  if h.blocked then bump("casts.drop_blocked") end
  bump("casts.drop_unmatched")
end

local function settle(t)
  for p = MAG, STA do
    local h = held[p]
    if h.on and t - h.t > HOLD_MS then resolve(p) end
  end
end

function M.stage(id, pool, cost, t, channel_ms)
  if not recording then return end
  settle(t)
  local q = pend[pool]
  if not q or cost <= 0 then
    push(t, id, pool, cost, 0)
    return
  end
  pend_expire(q, t)
  if q.n >= PEND_CAP then pend_remove(q, 1) end
  q.n = q.n + 1
  q.t[q.n], q.id[q.n], q.cost[q.n], q.chan[q.n] = t, id, cost, channel_ms or 0
end

function M.on_drop(pool, amount, t)
  if not recording then return end
  settle(t)
  local q = pend[pool]
  if not q then return end
  resolve(pool)
  pend_expire(q, t)
  if q.last_id > 0 and q.last_chan > 0 and t - q.last_start <= q.last_chan
     and amount <= q.last_cost * (1 + COST_TOLERANCE) then
    for i = q.n, 1, -1 do
      if q.id[i] == q.last_id then pend_remove(q, i) end
    end
    push(t, q.last_id, pool, amount, 1)
    q.last_t = t
    return true
  end
  local best = find(q, amount, false)
  if best then
    accept(q, pool, best, amount, t)
    return true
  end
  local slack = find(q, amount, true)
  if not slack and q.last_id > 0 and t - q.last_t <= TICK_WINDOW_MS and math.abs(amount - q.last_cost) <= q.last_cost * COST_TOLERANCE then
    if q.last_chan > 0 then
      push(t, q.last_id, pool, amount, 0)
      q.last_start = t
    else
      push(t, q.last_id, pool, amount, 1)
    end
    q.last_t = t
    return true
  end
  local h = held[pool]
  h.on, h.t, h.amt, h.gain = true, t, amount, 0
  h.blocked = block_t ~= nil and t - block_t <= BLOCK_MS
  h.sid = slack and q.id[slack] or 0
  return slack ~= nil
end

function M.on_gain(pool, amount, t)
  if not recording then return end
  local h = held[pool]
  if not h or not h.on then return end
  if t - h.t > HOLD_MS then
    resolve(pool)
    return
  end
  h.gain = h.gain + amount
  local net = h.amt - h.gain
  if net <= 0 then
    h.on = false
    return
  end
  local q = pend[pool]
  local best = find(q, net, false)
  if best then
    h.on = false
    accept(q, pool, best, net, h.t)
  end
end

function M.on_block(t)
  if not recording then return end
  block_t = t
  for p = MAG, STA do
    local h = held[p]
    if h.on and t - h.t <= BLOCK_MS and h.t - t <= BLOCK_MS then h.blocked = true end
  end
end

function M.settle(t)
  if recording then settle(t) end
end

local function channel_of(api, id)
  if not api.GetAbilityCastInfo then return 0 end
  local channeled, duration = api.GetAbilityCastInfo(id, nil, "player")
  if channeled and duration and duration > 0 then return duration end
  return 0
end

function M.on_used(slot)
  bump("casts.used")
  if not recording or n >= CAP then return end
  local api, zc = Vermilion.zenimax.api, Vermilion.zenimax.constants
  if not api.GetSlotBoundId then return end
  local cat = api.GetActiveHotbarCategory and api.GetActiveHotbarCategory() or zc.HOTBAR_CATEGORY_PRIMARY
  local id = slot_ability(api, zc, slot, cat)
  if id <= 0 then return end
  local pool, cost = slot_cost(api, zc, slot, cat, id)
  M.stage(id, pool, cost, now_ms(), channel_of(api, id))
end

function M.start_session()
  recording = true
  n = 0
  pend_clear()
end

function M.finalize()
  if not recording then return end
  resolve(MAG)
  resolve(STA)
  recording = false
  pend_clear()
  log:info("session finalize: casts=", n)
end

function M.reset()
  recording = false
  n = 0
  pend_clear()
end

function M.records() return cast_t, cast_id, cast_pool, cast_cost, n, cast_tick end
function M.count() return n end
function M.is_recording() return recording end

function M.load_session(recs)
  M.reset()
  recs = recs or {}
  for i = 1, #recs do
    local r = recs[i]
    cast_t[i]    = r.t or 0
    cast_id[i]   = r.id or 0
    cast_pool[i] = r.pool or 0
    cast_cost[i] = r.cost or 0
    cast_tick[i] = r.tick or 0
  end
  n = #recs
  log:info("session loaded: casts=", n)
end

function M.spend_top(t_lo, t_hi, pool)
  for k in pairs(acc) do acc[k] = nil end
  local best_id, best = 0, 0
  for i = 1, n do
    local t = cast_t[i]
    if t >= t_lo and t <= t_hi and cast_cost[i] > 0 and (pool == nil or cast_pool[i] == pool) then
      local id = cast_id[i]
      local v = (acc[id] or 0) + cast_cost[i]
      acc[id] = v
      if v > best then best, best_id = v, id end
    end
  end
  return best_id, best
end

function M.bar_ids(cat)
  local api, zc = Vermilion.zenimax.api, Vermilion.zenimax.constants
  local out = {}
  if not api.GetSlotBoundId then return out end
  local first = (zc.ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + 1
  local last  = (zc.ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1
  for slot = first, last do
    out[#out + 1] = (slot_ability(api, zc, slot, cat))
  end
  return out
end

function M.probe_lines()
  local api, zc = Vermilion.zenimax.api, Vermilion.zenimax.constants
  local out = {}
  local active = api.GetActiveHotbarCategory and api.GetActiveHotbarCategory() or zc.HOTBAR_CATEGORY_PRIMARY
  out[#out + 1] = string.format("active bar=%s  flags: magicka=%s stamina=%s  first=%s ult=%s",
    tostring(active), tostring(zc.COMBAT_MECHANIC_FLAGS_MAGICKA), tostring(zc.COMBAT_MECHANIC_FLAGS_STAMINA),
    tostring(zc.ACTION_BAR_FIRST_NORMAL_SLOT_INDEX), tostring(zc.ACTION_BAR_ULTIMATE_SLOT_INDEX))
  local first = (zc.ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + 1
  local last  = zc.ACTION_BAR_ULTIMATE_SLOT_INDEX or 7
  local bars = { zc.HOTBAR_CATEGORY_PRIMARY or 0, zc.HOTBAR_CATEGORY_BACKUP or 1 }
  for b = 1, #bars do
  local cat = bars[b]
  out[#out + 1] = string.format("bar %d", cat)
  for slot = first, last do
    local id, crafted = 0, false
    if api.GetSlotBoundId then id, crafted = slot_ability(api, zc, slot, cat) end
    if id and id > 0 then
      local base, flags, per_tick
      if api.GetAbilityBaseCostInfo then base, flags, per_tick = api.GetAbilityBaseCostInfo(id, nil, "player") end
      local cm = api.GetAbilityCost and zc.COMBAT_MECHANIC_FLAGS_MAGICKA and api.GetAbilityCost(id, zc.COMBAT_MECHANIC_FLAGS_MAGICKA, nil, "player")
      local cs = api.GetAbilityCost and zc.COMBAT_MECHANIC_FLAGS_STAMINA and api.GetAbilityCost(id, zc.COMBAT_MECHANIC_FLAGS_STAMINA, nil, "player")
      local sm = api.GetSlotAbilityCost and zc.COMBAT_MECHANIC_FLAGS_MAGICKA and api.GetSlotAbilityCost(slot, zc.COMBAT_MECHANIC_FLAGS_MAGICKA, cat)
      local ss = api.GetSlotAbilityCost and zc.COMBAT_MECHANIC_FLAGS_STAMINA and api.GetSlotAbilityCost(slot, zc.COMBAT_MECHANIC_FLAGS_STAMINA, cat)
      local pool, cost = slot_cost(api, zc, slot, cat, id)
      out[#out + 1] = string.format("slot %d  %s (%d)%s  base=%s flags=%s tick=%s  abilitycost mag=%s sta=%s  slotcost mag=%s sta=%s  -> pool=%d cost=%d",
        slot, tostring(api.GetAbilityName and api.GetAbilityName(id) or "?"), id,
        crafted and string.format(" scribed from %d", api.GetSlotBoundId(slot, cat) or 0) or "",
        tostring(base), tostring(flags), tostring(per_tick), tostring(cm), tostring(cs), tostring(sm), tostring(ss), pool, cost)
    else
      out[#out + 1] = string.format("slot %d  empty", slot)
    end
  end
  end
  out[#out + 1] = string.format("recorded casts=%d recording=%s", n, tostring(recording))
  return out
end

function M.report_lines()
  return {
    string.format("casts=%d recording=%s used_events=%d", n, tostring(recording), Vermilion.Diagnostics.get("casts.used")),
  }
end

function M.init()
  local zev, zc = Vermilion.zenimax.events, Vermilion.zenimax.constants
  if not zc.EVENT_ACTION_SLOT_ABILITY_USED then
    log:warn("no ability-used event on this client; cast tracker disabled")
    return
  end
  local first = (zc.ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + 1
  local last  = zc.ACTION_BAR_ULTIMATE_SLOT_INDEX or 7
  zev.register("Vermilion_E_CastUsed", zc.EVENT_ACTION_SLOT_ABILITY_USED, function(slot)
    if slot and slot >= first and slot <= last then M.on_used(slot) end
  end)
  if zc.EVENT_COMBAT_EVENT and zc.ACTION_RESULT_BLOCKED_DAMAGE then
    zev.register("Vermilion_E_CastBlock", zc.EVENT_COMBAT_EVENT, function() M.on_block(now_ms()) end)
    zev.add_filter("Vermilion_E_CastBlock", zc.EVENT_COMBAT_EVENT, zc.REGISTER_FILTER_COMBAT_RESULT, zc.ACTION_RESULT_BLOCKED_DAMAGE)
    zev.add_filter("Vermilion_E_CastBlock", zc.EVENT_COMBAT_EVENT, zc.REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, zc.COMBAT_UNIT_TYPE_PLAYER)
  end
  log:info("init: skill slots", first, "to", last)
end
