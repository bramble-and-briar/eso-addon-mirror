Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Metrics = {}

local M = Vermilion.Metrics
local W_MS        = 5000
local W_SHIELD_MS = 30000

local damage_out_buf  -- (eDPS)
local shield_out_buf  -- (ShDPS)
local event_pool
local log = Vermilion.Log.for_module("metrics")

local SkillColors
local DamageTypeColors

local KEY_SHIELD = "shield"
local DT_SHIELD  = -1
M.KEY_SHIELD = KEY_SHIELD
M.DT_SHIELD  = DT_SHIELD

local CRIT_DMG, CRIT_DOT

local function is_crit(e)
  local r = e.result
  return r == CRIT_DMG or r == CRIT_DOT
end

function M.acquire_event()  return event_pool:acquire()   end
function M.release_event(ev) event_pool:release(ev)       end
function M.pool_in_use()    return event_pool:in_use()    end
function M.pool_capacity()  return event_pool:capacity()  end

local function release_to_pool(entry) event_pool:release(entry) end

function M.init()
  local MC = Vermilion.Constants.METRICS or {}
  W_MS        = MC.DAMAGE_WINDOW_MS or 5000
  W_SHIELD_MS = MC.SHIELD_WINDOW_MS or 30000

  local cap  = (Vermilion.Constants.POOL and Vermilion.Constants.POOL.EVENT_CAPACITY) or 4096
  event_pool = Vermilion.lib.mem.BufferPool.new(Vermilion.lib.mem.Event.factory, cap, "event_pool")

  local RingBuffer = Vermilion.lib.mem.RingBuffer
  damage_out_buf = RingBuffer.new(W_MS,        2048, release_to_pool)
  shield_out_buf = RingBuffer.new(W_SHIELD_MS,  512, release_to_pool)

  SkillColors     = Vermilion.SkillColors
  DamageTypeColors = Vermilion.DamageTypeColors

  local zc = Vermilion.zenimax.constants
  CRIT_DMG = zc.ACTION_RESULT_CRITICAL_DAMAGE
  CRIT_DOT = zc.ACTION_RESULT_DOT_TICK_CRITICAL

  log:info("init: dmg_window=", W_MS, "ms shield_window=", W_SHIELD_MS, "ms pool=", cap)
end

function M.set_window(ms)
  W_MS = ms or 5000
  damage_out_buf.window_ms = W_MS
  log:info("dmg window ->", W_MS, "ms")
end

function M.set_shield_window(ms)
  W_SHIELD_MS = ms or 30000
  shield_out_buf.window_ms = W_SHIELD_MS
  log:info("shield window ->", W_SHIELD_MS, "ms")
end

function M.window_seconds() return W_MS / 1000 end
function M.shield_window_seconds() return W_SHIELD_MS / 1000 end

local tot_damage, tot_shield, tot_crit, tot_hits, tot_crit_hits, tot_overkill = 0, 0, 0, 0, 0, 0

local fight_first, fight_last, fight_loaded, fight_loaded_first = nil, nil, nil, nil
local session_closed = true

local OPENING_CAP = 64
local KIND_SHIELD_OUT = Vermilion.Constants.ABILITY_KIND.SHIELD_OUT
local opening, opening_head, opening_n, opening_on = {}, 1, 0, false

local function keep_or_release(ev)
  if not opening_on or (ev.amount or 0) <= 0 then
    event_pool:release(ev)
    return
  end
  local slot
  if opening_n < OPENING_CAP then
    slot = ((opening_head + opening_n - 1) % OPENING_CAP) + 1
    opening_n = opening_n + 1
  else
    slot = opening_head
    event_pool:release(opening[slot])
    opening_head = (opening_head % OPENING_CAP) + 1
  end
  opening[slot] = ev
end

function M.adopt_opening(since, seen)
  local head, n = opening_head, opening_n
  opening_head, opening_n = 1, 0
  for i = 0, n - 1 do
    local slot = ((head + i - 1) % OPENING_CAP) + 1
    local ev = opening[slot]
    opening[slot] = nil
    if since and not session_closed and ev.t >= since then
      if seen then seen(ev) end
      if ev.kind == KIND_SHIELD_OUT then M.ingest_shield_out(ev) else M.ingest_damage_out(ev) end
    else
      event_pool:release(ev)
    end
  end
end

function M.hold_opening(on)
  opening_on = on and true or false
  if not opening_on then M.adopt_opening(nil) end
end

local ex_skills, ex_skills_abs, ex_shields = {}, {}, {}
local ex_tg, ex_tg_abs, ex_tg_name, ex_tg_type = {}, {}, {}, {}
local ex_live = {
  skills = ex_skills, skills_abs = ex_skills_abs, shields = ex_shields,
  targets = ex_tg, targets_abs = ex_tg_abs, target_names = ex_tg_name, target_types = ex_tg_type,
}
local ex_loaded = nil

function M.session_mark(open)
  if Vermilion.Pipeline and Vermilion.Pipeline.drop_pending then Vermilion.Pipeline.drop_pending() end
  for _, t in pairs(ex_live) do
    for k in pairs(t) do t[k] = nil end
  end
  ex_loaded = nil
  tot_damage, tot_shield, tot_crit, tot_hits, tot_crit_hits, tot_overkill = 0, 0, 0, 0, 0, 0
  fight_first, fight_last, fight_loaded, fight_loaded_first = nil, nil, nil, nil
  session_closed = not open
  damage_out_buf:reset()
  shield_out_buf:reset()
end

function M.close_session() session_closed = true end

local function note_fight(t)
  if not t then return end
  if not fight_first or t < fight_first then fight_first = t end
  if not fight_last or t > fight_last then fight_last = t end
  local R = Vermilion.Resources
  if R then R.note_hit(t) end
end

function M.set_fight_ms(ms, first, exact) fight_loaded, fight_loaded_first, ex_loaded = ms, first, exact end

function M.is_loaded() return fight_loaded ~= nil end

function M.exact()
  if fight_loaded then return ex_loaded end
  return ex_live
end

function M.exact_copy()
  local out = {}
  for name, t in pairs(ex_live) do
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    out[name] = c
  end
  out.pool = Vermilion.Resources.flow_copy()
  return out
end

function M.output_total()
  local ex = M.exact()
  if not ex then return nil end
  local total = 0
  for _, v in pairs(ex.skills) do total = total + v end
  return total
end

function M.fight_bounds()
  if fight_loaded then
    if fight_loaded_first then return fight_loaded_first, fight_loaded_first + fight_loaded end
    return nil, nil
  end
  if fight_first and fight_last > fight_first then return fight_first, fight_last end
  return nil, nil
end

function M.fight_ms()
  if fight_loaded then return fight_loaded end
  if fight_first and fight_last > fight_first then return fight_last - fight_first end
  return 0
end

function M.session_avg(sum)
  if sum.fight_ms and sum.fight_ms > 0 then
    return ((sum.total_damage or 0) + (sum.total_shield or 0)) / (sum.fight_ms / 1000)
  end
  return sum.avg or 0
end

function M.totals()
  return tot_damage, tot_shield, tot_crit, tot_hits, tot_crit_hits, tot_overkill
end

function M.ingest_damage_out(ev)
  local amt = ev.amount
  if amt > 0 and not session_closed then
    tot_damage = tot_damage + amt
    tot_hits   = tot_hits + 1
    tot_overkill = tot_overkill + (ev.overflow or 0)
    note_fight(ev.t)
    local key = (ev.ability_id or 0) * 64 + (ev.damage_type or 0) + 1
    ex_skills[key] = (ex_skills[key] or 0) + amt
    local uid = ev.target_unit_id or 0
    ex_tg[uid] = (ex_tg[uid] or 0) + amt
    ex_tg_name[uid] = ev.target_name
    ex_tg_type[uid] = ev.target_type
    if is_crit(ev) then
      tot_crit = tot_crit + amt
      tot_crit_hits = tot_crit_hits + 1
    end
    damage_out_buf:push(ev)
  else
    keep_or_release(ev)
  end
end

function M.ingest_shield_out(ev)
  local amt = ev.amount
  if amt > 0 and not session_closed then
    tot_shield = tot_shield + amt
    note_fight(ev.t)
    local aid = ev.attack_id or 0
    local dt = (aid > 0) and (ev.attack_dtype or 0) or DT_SHIELD
    local key = aid * 64 + dt + 1
    ex_skills[key] = (ex_skills[key] or 0) + amt
    ex_skills_abs[key] = (ex_skills_abs[key] or 0) + amt
    local sid = ev.ability_id or 0
    ex_shields[sid] = (ex_shields[sid] or 0) + amt
    local uid = ev.target_unit_id or 0
    ex_tg[uid] = (ex_tg[uid] or 0) + amt
    ex_tg_abs[uid] = (ex_tg_abs[uid] or 0) + amt
    if ex_tg_name[uid] == nil then
      ex_tg_name[uid] = ev.target_name
      ex_tg_type[uid] = ev.target_type
    end
    shield_out_buf:push(ev)
  else
    keep_or_release(ev)
  end
end

function M.eDPS(now_ms)  return damage_out_buf:sum(now_ms, "amount") / (W_MS / 1000)        end
local function pending_shield()
  local P = Vermilion.Pipeline
  if P and P.pending_amount then return P.pending_amount() end
  return 0
end

function M.ShDPS(now_ms) return (shield_out_buf:sum(now_ms, "amount") + pending_shield()) / (W_SHIELD_MS / 1000) end
function M.EOS(now_ms)   return M.eDPS(now_ms) + M.ShDPS(now_ms)                            end

function M.crit_split(now_ms)
  damage_out_buf:trim(now_ms)
  local ws    = W_MS / 1000
  local crit  = 0
  local total = 0
  for i = damage_out_buf.head, damage_out_buf.tail do
    local e   = damage_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      total = total + amt
      if is_crit(e) then crit = crit + amt end
    end
  end
  crit = crit / ws
  return crit, (total / ws) - crit
end

function M.session_crit_rate(sum)
  if sum.crit_hits and (sum.hits or 0) > 0 then return sum.crit_hits / sum.hits end
  return sum.crit_pct or 0
end

local accum_buckets = {}

local function accumulate(now_ms, buckets)
  for k in pairs(buckets) do buckets[k] = nil end   --* reset in place for zero alloc !!
  local ws  = W_MS / 1000
  local wss = W_SHIELD_MS / 1000
  local total = 0

  damage_out_buf:trim(now_ms)
  for i = damage_out_buf.head, damage_out_buf.tail do
    local e   = damage_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local r = amt / ws
      local g = SkillColors.group_of(e.ability_id)
      buckets[g] = (buckets[g] or 0) + r
      total = total + r
    end
  end

  shield_out_buf:trim(now_ms)
  for i = shield_out_buf.head, shield_out_buf.tail do
    local e   = shield_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local r = amt / wss
      local aid = e.attack_id or 0
      local g = (aid > 0) and SkillColors.group_of(aid) or KEY_SHIELD
      buckets[g] = (buckets[g] or 0) + r
      total = total + r
    end
  end

  return total
end

function M.eos_groups_into(out, now_ms)
  local buckets = accum_buckets
  local total   = accumulate(now_ms, buckets)
  local n = 0
  if total > 0 then
    for g, val in pairs(buckets) do
      n = n + 1
      local slot = out[n]
      if not slot then slot = {}; out[n] = slot end
      local c = SkillColors.group_color(g)
      slot.r = c.r; slot.g = c.g; slot.b = c.b; slot.a = c.a
      slot.share = val / total
      slot.key = g   -- stable group id (string) for the hover highlight + card name
    end

    -- out is reused, so its tail holds stale slots from bigger calls.
    -- sort by hand over 1..n; table.sort would order #out and drag the tail in.
    for i = 2, n do
      local key = out[i]
      local j = i - 1
      while j >= 1 and out[j].share < key.share do
        out[j + 1] = out[j]
        j = j - 1
      end
      out[j + 1] = key
    end
  end
  out.count = n   -- readers loop 1..count, never #out
  return n
end

local function sort_shares_desc(out, n)
  for i = 2, n do
    local key = out[i]
    local ks  = key.share
    local j   = i - 1
    while j >= 1 and out[j].share < ks do
      out[j + 1] = out[j]
      j = j - 1
    end
    out[j + 1] = key
  end
end

local ab_amt = {}
local ab_grp = {}
local ab_abs = {}

function M.eos_abilities_into(out, now_ms)
  for k in pairs(ab_amt) do ab_amt[k] = nil end
  for k in pairs(ab_grp) do ab_grp[k] = nil end
  for k in pairs(ab_abs) do ab_abs[k] = nil end
  local ws    = W_MS / 1000
  local wss   = W_SHIELD_MS / 1000
  local total = 0

  damage_out_buf:trim(now_ms)
  for i = damage_out_buf.head, damage_out_buf.tail do
    local e   = damage_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local id = e.ability_id or 0
      local r  = amt / ws
      ab_amt[id] = (ab_amt[id] or 0) + r
      if ab_grp[id] == nil then ab_grp[id] = SkillColors.group_of(id) end
      total = total + r
    end
  end

  shield_out_buf:trim(now_ms)
  for i = shield_out_buf.head, shield_out_buf.tail do
    local e   = shield_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local id = e.attack_id or 0
      local r  = amt / wss
      ab_amt[id] = (ab_amt[id] or 0) + r
      ab_abs[id] = (ab_abs[id] or 0) + r
      if ab_grp[id] == nil then ab_grp[id] = (id > 0) and SkillColors.group_of(id) or KEY_SHIELD end
      total = total + r
    end
  end

  local n = 0
  if total > 0 then
    for id, amt in pairs(ab_amt) do
      n = n + 1
      local slot = out[n]
      if not slot then slot = {}; out[n] = slot end
      local g = ab_grp[id] or "other"
      local c = SkillColors.group_color(g)
      slot.id = id; slot.share = amt / total; slot.key = g
      slot.abs = (ab_abs[id] or 0) / total
      slot.r = c.r; slot.g = c.g; slot.b = c.b; slot.a = c.a
    end
    sort_shares_desc(out, n)
  end
  out.count = n
  return n
end

local dt_buckets = {}

function M.dtype_groups_into(out, now_ms)
  for k in pairs(dt_buckets) do dt_buckets[k] = nil end
  local ws    = W_MS / 1000
  local wss   = W_SHIELD_MS / 1000
  local total = 0
  damage_out_buf:trim(now_ms)
  for i = damage_out_buf.head, damage_out_buf.tail do
    local e   = damage_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local r  = amt / ws
      local dt = e.damage_type or 0
      dt_buckets[dt] = (dt_buckets[dt] or 0) + r
      total = total + r
    end
  end
  shield_out_buf:trim(now_ms)
  for i = shield_out_buf.head, shield_out_buf.tail do
    local e   = shield_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local r  = amt / wss
      local dt = ((e.attack_id or 0) > 0) and (e.attack_dtype or 0) or DT_SHIELD
      dt_buckets[dt] = (dt_buckets[dt] or 0) + r
      total = total + r
    end
  end
  local n = 0
  if total > 0 then
    for dt, val in pairs(dt_buckets) do
      n = n + 1
      local slot = out[n]
      if not slot then slot = {}; out[n] = slot end
      local c = DamageTypeColors.lookup(dt)
      slot.r = c.r; slot.g = c.g; slot.b = c.b; slot.a = c.a
      slot.share = val / total
      slot.key = dt
    end
    sort_shares_desc(out, n)
  end
  out.count = n
  return n
end

local dta_amt = {}
local dta_dt  = {}
local dta_abs = {}

function M.dtype_abilities_into(out, now_ms)
  for k in pairs(dta_amt) do dta_amt[k] = nil end
  for k in pairs(dta_dt)  do dta_dt[k]  = nil end
  for k in pairs(dta_abs) do dta_abs[k] = nil end
  local ws    = W_MS / 1000
  local wss   = W_SHIELD_MS / 1000
  local total = 0
  damage_out_buf:trim(now_ms)
  for i = damage_out_buf.head, damage_out_buf.tail do
    local e   = damage_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local id = e.ability_id or 0
      local r  = amt / ws
      dta_amt[id] = (dta_amt[id] or 0) + r
      if dta_dt[id] == nil then dta_dt[id] = e.damage_type or 0 end
      total = total + r
    end
  end
  shield_out_buf:trim(now_ms)
  for i = shield_out_buf.head, shield_out_buf.tail do
    local e   = shield_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local id = e.attack_id or 0
      local r  = amt / wss
      dta_amt[id] = (dta_amt[id] or 0) + r
      dta_abs[id] = (dta_abs[id] or 0) + r
      if dta_dt[id] == nil then dta_dt[id] = (id > 0) and (e.attack_dtype or 0) or DT_SHIELD end
      total = total + r
    end
  end
  local n = 0
  if total > 0 then
    for id, amt in pairs(dta_amt) do
      n = n + 1
      local slot = out[n]
      if not slot then slot = {}; out[n] = slot end
      local dt = dta_dt[id] or 0
      local c  = DamageTypeColors.lookup(dt)
      slot.id = id; slot.share = amt / total; slot.key = dt
      slot.abs = (dta_abs[id] or 0) / total
      slot.r = c.r; slot.g = c.g; slot.b = c.b; slot.a = c.a
    end
    sort_shares_desc(out, n)
  end
  out.count = n
  return n
end

local sh_amt = {}

function M.shield_abilities_into(out, now_ms)
  for k in pairs(sh_amt) do sh_amt[k] = nil end
  local total = 0
  shield_out_buf:trim(now_ms)
  for i = shield_out_buf.head, shield_out_buf.tail do
    local e   = shield_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local id = e.ability_id or 0
      sh_amt[id] = (sh_amt[id] or 0) + amt
      total = total + amt
    end
  end
  local n = 0
  if total > 0 then
    local c = SkillColors.group_color(KEY_SHIELD)
    for id, amt in pairs(sh_amt) do
      n = n + 1
      local slot = out[n]
      if not slot then slot = {}; out[n] = slot end
      slot.id = id; slot.share = amt / total; slot.key = KEY_SHIELD; slot.abs = amt / total
      slot.r = c.r; slot.g = c.g; slot.b = c.b; slot.a = c.a
    end
    sort_shares_desc(out, n)
  end
  out.count = n
  return n
end

local tg_amt, tg_abs, tg_name, tg_type = {}, {}, {}, {}

function M.targets_into(out, now_ms)
  for k in pairs(tg_amt)  do tg_amt[k]  = nil end
  for k in pairs(tg_abs)  do tg_abs[k]  = nil end
  for k in pairs(tg_name) do tg_name[k] = nil end
  for k in pairs(tg_type) do tg_type[k] = nil end
  local ws    = W_MS / 1000
  local wss   = W_SHIELD_MS / 1000
  local total = 0
  damage_out_buf:trim(now_ms)
  for i = damage_out_buf.head, damage_out_buf.tail do
    local e   = damage_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local id = e.target_unit_id or 0
      local r  = amt / ws
      tg_amt[id] = (tg_amt[id] or 0) + r
      tg_name[id] = e.target_name
      tg_type[id] = e.target_type
      total = total + r
    end
  end
  shield_out_buf:trim(now_ms)
  for i = shield_out_buf.head, shield_out_buf.tail do
    local e   = shield_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local id = e.target_unit_id or 0
      local r  = amt / wss
      tg_amt[id] = (tg_amt[id] or 0) + r
      tg_abs[id] = (tg_abs[id] or 0) + r
      if tg_name[id] == nil then tg_name[id] = e.target_name; tg_type[id] = e.target_type end
      total = total + r
    end
  end
  local n = 0
  if total > 0 then
    for id, amt in pairs(tg_amt) do
      n = n + 1
      local slot = out[n]
      if not slot then slot = {}; out[n] = slot end
      slot.id = id; slot.name = tg_name[id] or ""; slot.ttype = tg_type[id] or 0
      slot.share = amt / total; slot.abs = (tg_abs[id] or 0) / total
    end
    sort_shares_desc(out, n)
  end
  out.count = n
  return n
end

function M.reset()
  log:info("reset: damage=", damage_out_buf:size(), "shield=", shield_out_buf:size(),
           "pool_in_use=", event_pool:in_use())
  if Vermilion.Pipeline and Vermilion.Pipeline.drop_pending then Vermilion.Pipeline.drop_pending() end
  M.adopt_opening(nil)
  damage_out_buf:reset()
  shield_out_buf:reset()
end

function M.size_snapshot()
  return {
    damage = damage_out_buf:size(),
    shield = shield_out_buf:size(),
  }
end
