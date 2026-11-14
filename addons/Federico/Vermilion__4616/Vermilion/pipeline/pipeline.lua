---* Event Pipeline Orchestrator.

---* Motivation: To isolate the core logic from the noise of the raw ZOS API. 
---* Instead of polluting individual pipeline stages with global state, profiling, 
---* or early-exit checks, this module acts as a strict boundary layer. It handles 
---* the raw ingest, performs fast-fail validation (errors, zero-hits, active modes), 
---* updates diagnostic counters, and drives the lifecycle of an event through 
---* its three phases: Acquisition -> Filter -> Processing.
---
--- @module Vermilion.Pipeline
---
--- Entry points:
--- * `M.dispatch_damage_out` - Combat handler for outgoing player damage.
--- * `M.dispatch_shield_out` - Combat handler for player-applied damage shields.
--- * `M.init`                - Bootstraps ZOS subscriptions and API hardware filters.

Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Pipeline = Vermilion.Pipeline or {}
local M = Vermilion.Pipeline

local Acquisition = Vermilion.Pipeline.Acquisition
local Filter      = Vermilion.Pipeline.Filter
local Processing  = Vermilion.Pipeline.Processing

local C = Vermilion.zenimax.constants
local EVENT_COMBAT_EVENT          = C.EVENT_COMBAT_EVENT
local REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE = C.REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE
local EVENT_EFFECT_CHANGED = C.EVENT_EFFECT_CHANGED
local REGISTER_FILTER_COMBAT_RESULT           = C.REGISTER_FILTER_COMBAT_RESULT
local REGISTER_FILTER_IS_ERROR                = C.REGISTER_FILTER_IS_ERROR
local COMBAT_UNIT_TYPE_PLAYER     = C.COMBAT_UNIT_TYPE_PLAYER
local ACTION_RESULT_DAMAGE            = C.ACTION_RESULT_DAMAGE
local ACTION_RESULT_DOT_TICK          = C.ACTION_RESULT_DOT_TICK
local ACTION_RESULT_CRITICAL_DAMAGE   = C.ACTION_RESULT_CRITICAL_DAMAGE
local ACTION_RESULT_DOT_TICK_CRITICAL = C.ACTION_RESULT_DOT_TICK_CRITICAL
local ACTION_RESULT_BLOCKED_DAMAGE    = C.ACTION_RESULT_BLOCKED_DAMAGE
local ACTION_RESULT_DAMAGE_SHIELDED   = C.ACTION_RESULT_DAMAGE_SHIELDED

local Log = Vermilion.Log.for_module("pipeline")

local prof_enter = Vermilion.Profiler.enter
local prof_exit  = Vermilion.Profiler.exit

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function release(ev)
  if ev then Vermilion.Metrics.release_event(ev) end
end

local now = Acquisition.now

local function run_stages(ev, accepted_key)
  if not ev then
    bump("engine.pool.exhausted")
    Log:warn("event pool exhausted")
    return
  end
  prof_enter("pipeline.combat_event.filter")
  local allowed = Filter.allow(ev)
  prof_exit("pipeline.combat_event.filter")
  if allowed then
    bump(accepted_key)
    prof_enter("pipeline.combat_event.processing")
    Processing.process(ev)
    prof_exit("pipeline.combat_event.processing")
  else
    release(ev)
  end
end

local PAIR_MS     = 50
local PENDING_CAP = 8
local pending   = {}
local pending_n = 0

local function ingest_pending(i)
  local ev = pending[i]
  pending[i] = pending[pending_n]
  pending[pending_n] = nil
  pending_n = pending_n - 1
  run_stages(ev, "engine.shield.accepted")
end

function M.flush_pending(now_ms, force)
  local i = 1
  while i <= pending_n do
    if force or (now_ms - pending[i].t) >= PAIR_MS then
      bump("engine.shield.unpaired")
      ingest_pending(i)
    else
      i = i + 1
    end
  end
end

function M.drop_pending()
  for i = 1, pending_n do
    release(pending[i])
    pending[i] = nil
  end
  pending_n = 0
end

function M.pending_count() return pending_n end

function M.pending_amount()
  local sum = 0
  for i = 1, pending_n do sum = sum + (pending[i].amount or 0) end
  return sum
end

local function hold_pending(ev, t)
  M.flush_pending(t)
  if pending_n >= PENDING_CAP then ingest_pending(1) end
  pending_n = pending_n + 1
  pending[pending_n] = ev
end

local function pair_pending(t, targetUnitId, abilityId, damageType)
  local i = 1
  while i <= pending_n do
    local p = pending[i]
    if p.target_unit_id == targetUnitId and (t - p.t) < PAIR_MS then
      p.attack_id    = abilityId or 0
      p.attack_dtype = damageType or 0
      bump("engine.shield.paired")
      ingest_pending(i)
    else
      i = i + 1
    end
  end
end

function M.dispatch_damage_out(result, isError, _name, _g, _slot,
                               _src, _sourceType, _tgt, targetType, hit,
                               _pt, _dt, _log, sourceUnitId, targetUnitId, abilityId, overflow)
  prof_enter("pipeline.combat_event")
  bump("engine.damage.in")
  if isError then bump("engine.damage.dropped_error") prof_exit("pipeline.combat_event") return end
  if pending_n > 0 then pair_pending(now(), targetUnitId, abilityId, _dt) end
  if (hit or 0) <= 0 then bump("engine.damage.dropped_noise") prof_exit("pipeline.combat_event") return end
  if not Vermilion.Mode.uses("damage") then
    bump("engine.damage.dropped_mode") prof_exit("pipeline.combat_event") return
  end

  local t = now()
  prof_enter("pipeline.combat_event.acquisition")
  local ev = Acquisition.acquire_damage_out(t, hit, targetUnitId, targetType, abilityId, result, sourceUnitId, _dt, _tgt, overflow)
  prof_exit("pipeline.combat_event.acquisition")
  run_stages(ev, "engine.damage.accepted")
  prof_exit("pipeline.combat_event")
end

function M.dispatch_shield_out(result, isError, _name, _g, _slot,
                               _src, _sourceType, _tgt, targetType, hit,
                               _pt, _dt, _log, sourceUnitId, targetUnitId, abilityId)
  prof_enter("pipeline.combat_event")
  bump("engine.shield.in")
  if isError then bump("engine.shield.dropped_error") prof_exit("pipeline.combat_event") return end
  if (hit or 0) <= 0 then bump("engine.shield.dropped_noise") prof_exit("pipeline.combat_event") return end
  if not Vermilion.Mode.uses("shield") then
    bump("engine.shield.dropped_mode") prof_exit("pipeline.combat_event") return
  end

  local t = now()
  prof_enter("pipeline.combat_event.acquisition")
  local ev = Acquisition.acquire_shield_out(t, hit, targetUnitId, targetType, abilityId, result, sourceUnitId, _tgt)
  prof_exit("pipeline.combat_event.acquisition")
  if not ev then bump("engine.pool.exhausted")
  elseif not Filter.allow(ev) then bump("engine.shield.dropped_filter") release(ev)
  else hold_pending(ev, t) end
  prof_exit("pipeline.combat_event")
end

function M.dispatch_effect_player_src(changeType, _slot, name, unitTag, beginTime, endTime,
                                       _stack, _icon, _depBuff, effectType, _abilityType,
                                       _stat, _uname, unitId, abilityId)
  bump("engine.effect.in_player_src")
  local t = now()
  Vermilion.DebuffTracker.on_effect(changeType, abilityId, unitId, endTime, t, unitTag, effectType)
  Vermilion.Uptime.on_effect(changeType, abilityId, unitId, beginTime, endTime, t, unitTag, effectType, name)
end

function M.sync_duel()
  local info = Vermilion.zenimax.api.GetDuelInfo
  Filter.set_dueling(info ~= nil and C.DUEL_STATE_DUELING ~= nil and info() == C.DUEL_STATE_DUELING)
end

function M.init()
  local E = Vermilion.zenimax.events

  Vermilion.Diagnostics.init()
  Vermilion.Metrics.init()

  local function on_damage_event(...)
    local r = ...
    if r == ACTION_RESULT_DAMAGE
       or r == ACTION_RESULT_DOT_TICK
       or r == ACTION_RESULT_CRITICAL_DAMAGE
       or r == ACTION_RESULT_DOT_TICK_CRITICAL
       or r == ACTION_RESULT_BLOCKED_DAMAGE then
      M.dispatch_damage_out(...)
    end
  end
  E.register("Vermilion_E_DamageOut", EVENT_COMBAT_EVENT, on_damage_event)
  E.add_filter("Vermilion_E_DamageOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter("Vermilion_E_DamageOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)
  E.register("Vermilion_E_DamagePet", EVENT_COMBAT_EVENT, on_damage_event)
  E.add_filter("Vermilion_E_DamagePet", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, C.COMBAT_UNIT_TYPE_PLAYER_PET)
  E.add_filter("Vermilion_E_DamagePet", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Vermilion_E_ShieldOut", EVENT_COMBAT_EVENT, M.dispatch_shield_out)
  E.add_filter("Vermilion_E_ShieldOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE_SHIELDED)
  E.add_filter("Vermilion_E_ShieldOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter("Vermilion_E_ShieldOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)
  E.register("Vermilion_E_ShieldPet", EVENT_COMBAT_EVENT, M.dispatch_shield_out)
  E.add_filter("Vermilion_E_ShieldPet", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE_SHIELDED)
  E.add_filter("Vermilion_E_ShieldPet", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, C.COMBAT_UNIT_TYPE_PLAYER_PET)
  E.add_filter("Vermilion_E_ShieldPet", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  local function on_kill_event(_r, _err, _name, _g, _slot, _src, _st, tgt, _tt, _hit, _pt, _dt, _log, _suid, targetUnitId, abilityId)
    local t = now()
    Vermilion.Kills.on_kill(t, targetUnitId, tgt, abilityId)
    Vermilion.Uptime.on_unit_dead(targetUnitId, t)
  end
  local kill_results = { C.ACTION_RESULT_DIED_XP or 2262, C.ACTION_RESULT_KILLING_BLOW or 2265, C.ACTION_RESULT_DIED or 2260 }
  local kill_sources = { COMBAT_UNIT_TYPE_PLAYER, C.COMBAT_UNIT_TYPE_PLAYER_PET }
  for i = 1, #kill_results do
    for s = 1, #kill_sources do
      local name = "Vermilion_E_Kill" .. i .. "_" .. s
      E.register(name, EVENT_COMBAT_EVENT, on_kill_event)
      E.add_filter(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, kill_results[i])
      E.add_filter(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, kill_sources[s])
    end
  end

  E.register("Vermilion_E_EffectPlayer", EVENT_EFFECT_CHANGED, M.dispatch_effect_player_src)
  E.add_filter("Vermilion_E_EffectPlayer", EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  if C.EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
    E.register("Vermilion_E_WeaponPair", C.EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
      Vermilion.DebuffTracker.on_bars_changed()
    end)
  end

  if C.EVENT_DUEL_STARTED and C.EVENT_DUEL_FINISHED then
    E.register("Vermilion_E_DuelStart", C.EVENT_DUEL_STARTED, function() Filter.set_dueling(true) end)
    E.register("Vermilion_E_DuelEnd", C.EVENT_DUEL_FINISHED, function() Filter.set_dueling(false) end)
  end
  M.sync_duel()

  Log:info("init complete; 2 combat-event handlers and the effect handler registered")
end
