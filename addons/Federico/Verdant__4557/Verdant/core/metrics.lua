Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Metrics = {}

local M = Verdant.Metrics

local W_MS = Verdant.Constants.METRICS.WINDOW_MS

local heal_buf, overheal_buf, shield_buf, damage_buf
local restore_mag_buf, restore_sta_buf
local KIND_RESTORE_MAG = Verdant.Constants.ABILITY_KIND.RESTORE_MAG
local event_pool
local log = Verdant.Log.for_module("metrics")

local function in_M(entry)
  return Verdant.Coverage.is_in_M(entry.target_type)
end

local CRIT_HEAL, CRIT_HOT

local function is_crit(e)
  local r = e.result
  return r == CRIT_HEAL or r == CRIT_HOT
end

function M.acquire_event()
  return event_pool:acquire()
end

function M.release_event(ev)
  event_pool:release(ev)
end

function M.pool_in_use()
  return event_pool:in_use()
end

function M.pool_capacity()
  return event_pool:capacity()
end

local function release_to_pool(entry)
  event_pool:release(entry)
end

function M.init()
  local cap   = (Verdant.Constants.POOL and Verdant.Constants.POOL.EVENT_CAPACITY) or 4096
  event_pool  = Verdant.lib.mem.BufferPool.new(Verdant.lib.mem.Event.factory, cap, "event_pool")

  local RingBuffer = Verdant.lib.mem.RingBuffer
  heal_buf     = RingBuffer.new(W_MS,        1024, release_to_pool)
  overheal_buf = RingBuffer.new(W_MS,        1024, release_to_pool)
  shield_buf   = RingBuffer.new(W_MS,         512, release_to_pool)
  damage_buf   = RingBuffer.new(W_MS,        2048, release_to_pool)
  restore_mag_buf = RingBuffer.new(W_MS,      512, release_to_pool)
  restore_sta_buf = RingBuffer.new(W_MS,      512, release_to_pool)

  local zc = Verdant.zenimax.constants
  CRIT_HEAL = zc.ACTION_RESULT_CRITICAL_HEAL
  CRIT_HOT  = zc.ACTION_RESULT_HOT_TICK_CRITICAL

  log:info("init: window=", W_MS, "ms pool=", cap)
end

function M.window_seconds() return W_MS / 1000 end

local oh_hot, oh_direct = 0, 0
local tot_heal, tot_shield, tot_overheal = 0, 0, 0
local tot_crit = 0
local by_heal, by_shield = {}, {}
local tot_rmag, tot_rsta = 0, 0
local by_rmag, by_rsta = {}, {}
local counting = false

function M.ingest_heal(ev)
  if ev.amount > 0 then
    if counting and in_M(ev) then
      tot_heal = tot_heal + ev.amount
      if is_crit(ev) then tot_crit = tot_crit + ev.amount end
      local id = ev.ability_id or 0
      by_heal[id] = (by_heal[id] or 0) + ev.amount
    end
    heal_buf:push(ev)
  else
    event_pool:release(ev)
  end
end

function M.ingest_overheal(ev)
  if ev.amount > 0 then
    if counting and in_M(ev) then
      local zc = Verdant.zenimax.constants
      local r  = ev.result
      if r == zc.ACTION_RESULT_HOT_TICK or r == zc.ACTION_RESULT_HOT_TICK_CRITICAL then
        oh_hot = oh_hot + ev.amount
      else
        oh_direct = oh_direct + ev.amount
      end
      tot_overheal = tot_overheal + ev.amount
    end
    overheal_buf:push(ev)
  else
    event_pool:release(ev)
  end
end

function M.ingest_shield(ev)
  if ev.amount > 0 then
    if counting and in_M(ev) then
      tot_shield = tot_shield + ev.amount
      local id = ev.ability_id or 0
      by_shield[id] = (by_shield[id] or 0) + ev.amount
    end
    shield_buf:push(ev)
  else
    event_pool:release(ev)
  end
end

function M.ingest_restore(ev)
  local mag = ev.kind == KIND_RESTORE_MAG
  if counting and in_M(ev) then
    local id = ev.ability_id or 0
    if mag then
      tot_rmag = tot_rmag + ev.amount
      by_rmag[id] = (by_rmag[id] or 0) + ev.amount
    else
      tot_rsta = tot_rsta + ev.amount
      by_rsta[id] = (by_rsta[id] or 0) + ev.amount
    end
    Verdant.TemporalBuffer.add_restore(ev.t, id, mag, ev.target_name, ev.amount)
  end
  if mag then restore_mag_buf:push(ev) else restore_sta_buf:push(ev) end
end

function M.restore_totals()
  return tot_rmag, tot_rsta
end

function M.restore_by_ability()
  return by_rmag, by_rsta
end

function M.totals()
  return tot_heal, tot_shield, tot_overheal
end

function M.by_ability()
  return by_heal, by_shield
end

function M.crit_total()
  return tot_crit
end

function M.ingest_damage_group(ev)
  if ev.amount > 0 then
    damage_buf:push(ev)
  else
    event_pool:release(ev)
  end
end

local function rate(buf, now_ms, predicate)
  return buf:sum(now_ms, "amount", predicate) / (W_MS / 1000)
end

function M.eHPS(now_ms)    return rate(heal_buf,     now_ms, in_M) end
function M.OHPS(now_ms)    return rate(overheal_buf, now_ms, in_M) end
function M.MPS(now_ms)     return rate(shield_buf,   now_ms, in_M) end
function M.D_group(now_ms) return rate(damage_buf,   now_ms, nil)  end
function M.RMag(now_ms)    return rate(restore_mag_buf, now_ms, in_M) end
function M.RSta(now_ms)    return rate(restore_sta_buf, now_ms, in_M) end

function M.EMS(now_ms)
  return M.eHPS(now_ms) + M.MPS(now_ms)
end

function M.O_self(now_ms)
  return M.eHPS(now_ms) + M.MPS(now_ms) + M.OHPS(now_ms)
end

local contrib = { mode = "", eHPS = 0, MPS = 0, OHPS = 0, EMS = 0, D_group = 0, O_self = 0,
                  C_self = 0, C_heal = 0, C_shield = 0 }

function M.contribution(now_ms)
  local ems = M.EMS(now_ms)
  local heal_share, shield_share = 0, 0
  if ems > 0 then
    heal_share   = M.eHPS(now_ms) / ems
    shield_share = M.MPS(now_ms)  / ems
  end

  local c, mode_used
  if Verdant.Coverage.is_grouped() then
    local d = M.D_group(now_ms)
    mode_used = "group"
    if d <= 0 then
      c = 0
    else
      local ratio = ems / d
      c = ratio > 1 and 1 or ratio
    end
  else
    local o = M.O_self(now_ms)
    mode_used = "open"
    c = (o > 0) and (ems / o) or 0
  end

  local r = contrib
  r.mode     = mode_used
  r.eHPS     = M.eHPS(now_ms)
  r.MPS      = M.MPS(now_ms)
  r.OHPS     = M.OHPS(now_ms)
  r.EMS      = ems
  r.D_group  = M.D_group(now_ms)
  r.O_self   = M.O_self(now_ms)
  r.C_self   = c
  r.C_heal   = c * heal_share
  r.C_shield = c * shield_share
  return r
end

function M.eHPS_crit_split(now_ms)
  heal_buf:trim(now_ms)
  local ws    = W_MS / 1000
  local crit  = 0
  local total = 0
  for i = heal_buf.head, heal_buf.tail do
    local e   = heal_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 and in_M(e) then
      total = total + amt
      if is_crit(e) then crit = crit + amt end
    end
  end
  crit = crit / ws
  return crit, (total / ws) - crit
end

function M.eHPS_by_group(now_ms)
  return Verdant.SkillColors.group_shares(heal_buf, now_ms, in_M)
end

function M.MPS_by_group(now_ms)
  return Verdant.SkillColors.group_shares(shield_buf, now_ms, in_M)
end

function M.eHPS_by_group_into(out, now_ms)
  return Verdant.SkillColors.group_shares_into(out, heal_buf, now_ms, in_M)
end

function M.MPS_by_group_into(out, now_ms)
  return Verdant.SkillColors.group_shares_into(out, shield_buf, now_ms, in_M)
end

function M.eHPS_by_ability_into(out, now_ms)
  return Verdant.SkillColors.ability_shares_into(out, heal_buf, now_ms, in_M)
end

function M.MPS_by_ability_into(out, now_ms)
  return Verdant.SkillColors.ability_shares_into(out, shield_buf, now_ms, in_M)
end

function M.reset()
  log:info("reset: heal=", heal_buf:size(), "overheal=", overheal_buf:size(),
           "shield=", shield_buf:size(), "damage=", damage_buf:size(),
           "pool_in_use=", event_pool:in_use())
  heal_buf:reset()
  overheal_buf:reset()
  shield_buf:reset()
  damage_buf:reset()
  restore_mag_buf:reset()
  restore_sta_buf:reset()
end

function M.session_mark()
  oh_hot, oh_direct = 0, 0
  tot_heal, tot_shield, tot_overheal = 0, 0, 0
  tot_crit = 0
  for id in pairs(by_heal) do by_heal[id] = nil end
  for id in pairs(by_shield) do by_shield[id] = nil end
  tot_rmag, tot_rsta = 0, 0
  for id in pairs(by_rmag) do by_rmag[id] = nil end
  for id in pairs(by_rsta) do by_rsta[id] = nil end
  counting = true
end

function M.session_close()
  counting = false
end

function M.overheal_split()
  return oh_hot, oh_direct
end

function M.size_snapshot()
  return {
    heal     = heal_buf:size(),
    overheal = overheal_buf:size(),
    shield   = shield_buf:size(),
    damage   = damage_buf:size(),
    restore_mag = restore_mag_buf:size(),
    restore_sta = restore_sta_buf:size(),
  }
end
