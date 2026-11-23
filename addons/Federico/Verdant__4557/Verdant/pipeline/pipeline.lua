
Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Pipeline = Verdant.Pipeline or {}
local M = Verdant.Pipeline

local Acquisition = Verdant.Pipeline.Acquisition
local Filter      = Verdant.Pipeline.Filter
local Processing  = Verdant.Pipeline.Processing

local C = Verdant.zenimax.constants
local string_find = string.find
local EVENT_COMBAT_EVENT          = C.EVENT_COMBAT_EVENT
local EVENT_EFFECT_CHANGED        = C.EVENT_EFFECT_CHANGED
local EVENT_GROUP_MEMBER_JOINED   = C.EVENT_GROUP_MEMBER_JOINED
local EVENT_GROUP_MEMBER_LEFT     = C.EVENT_GROUP_MEMBER_LEFT
local EVENT_GROUP_UPDATE          = C.EVENT_GROUP_UPDATE
local EVENT_PLAYER_ACTIVATED      = C.EVENT_PLAYER_ACTIVATED
local EVENT_UNIT_DEATH_STATE_CHANGED = C.EVENT_UNIT_DEATH_STATE_CHANGED
local REGISTER_FILTER_UNIT_TAG    = C.REGISTER_FILTER_UNIT_TAG
local REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE = C.REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE
local REGISTER_FILTER_COMBAT_RESULT           = C.REGISTER_FILTER_COMBAT_RESULT
local REGISTER_FILTER_IS_ERROR                = C.REGISTER_FILTER_IS_ERROR
local COMBAT_UNIT_TYPE_PLAYER     = C.COMBAT_UNIT_TYPE_PLAYER
local COMBAT_UNIT_TYPE_GROUP      = C.COMBAT_UNIT_TYPE_GROUP
local ACTION_RESULT_HEAL              = C.ACTION_RESULT_HEAL
local ACTION_RESULT_HOT_TICK          = C.ACTION_RESULT_HOT_TICK
local ACTION_RESULT_CRITICAL_HEAL     = C.ACTION_RESULT_CRITICAL_HEAL
local ACTION_RESULT_HOT_TICK_CRITICAL = C.ACTION_RESULT_HOT_TICK_CRITICAL
local ACTION_RESULT_DAMAGE_SHIELDED   = C.ACTION_RESULT_DAMAGE_SHIELDED
local ACTION_RESULT_POWER_ENERGIZE    = C.ACTION_RESULT_POWER_ENERGIZE
local POOL_MAGICKA                    = C.COMBAT_MECHANIC_FLAGS_MAGICKA
local POOL_STAMINA                    = C.COMBAT_MECHANIC_FLAGS_STAMINA
local KIND_RESTORE_MAG = Verdant.Constants.ABILITY_KIND.RESTORE_MAG
local KIND_RESTORE_STA = Verdant.Constants.ABILITY_KIND.RESTORE_STA
local ACTION_RESULT_DAMAGE            = C.ACTION_RESULT_DAMAGE
local ACTION_RESULT_DOT_TICK          = C.ACTION_RESULT_DOT_TICK
local ACTION_RESULT_CRITICAL_DAMAGE   = C.ACTION_RESULT_CRITICAL_DAMAGE
local ACTION_RESULT_DOT_TICK_CRITICAL = C.ACTION_RESULT_DOT_TICK_CRITICAL
local ACTION_RESULT_BLOCKED_DAMAGE    = C.ACTION_RESULT_BLOCKED_DAMAGE
local ACTION_RESULT_FALL_DAMAGE       = C.ACTION_RESULT_FALL_DAMAGE
local EFFECT_RESULT_GAINED = C.EFFECT_RESULT_GAINED
local EFFECT_RESULT_FADED  = C.EFFECT_RESULT_FADED

local Log = Verdant.Log.for_module("pipeline")

local prof_enter = Verdant.Profiler.enter
local prof_exit  = Verdant.Profiler.exit

local function bump(key) Verdant.Diagnostics.bump(key) end

local function release(ev)
  if ev then Verdant.Metrics.release_event(ev) end
end

local now = Acquisition.now

function M.dispatch_heal_out(result, isError, _name, _g, _slot,
                              _src, sourceType, targetName, targetType, hit,
                              _pt, _dt, _log, sourceUnitId, targetUnitId,
                              abilityId, overflow)
  prof_enter("pipeline.combat_event")
  bump("engine.heal.in")
  if isError then bump("engine.heal.dropped_error") prof_exit("pipeline.combat_event") return end
  if (hit or 0) == 0 and (overflow or 0) == 0 then
    bump("engine.heal.dropped_noise") prof_exit("pipeline.combat_event") return
  end
  if not Verdant.Mode.uses("heal") and not Verdant.Mode.uses("overheal") then
    bump("engine.heal.dropped_mode") prof_exit("pipeline.combat_event") return
  end

  if sourceType == COMBAT_UNIT_TYPE_PLAYER and sourceUnitId and sourceUnitId ~= 0 then
    Verdant.GroupSet.set_player(sourceUnitId)
  end
  if targetType == COMBAT_UNIT_TYPE_GROUP and targetUnitId and targetUnitId ~= 0 then
    Verdant.GroupSet.add(targetUnitId)
    bump("engine.heal.target_group")
  else
    bump("engine.heal.target_other")
  end
  bump("engine.heal.accepted")

  local t = now()
  prof_enter("pipeline.combat_event.acquisition")
  local ev_heal, ev_overheal = Acquisition.acquire_heal_out(
    t, hit, overflow, targetUnitId, targetType, abilityId, result)
  prof_exit("pipeline.combat_event.acquisition")

  if ev_heal then
    prof_enter("pipeline.combat_event.filter")
    local allowed = Filter.allow(ev_heal)
    prof_exit("pipeline.combat_event.filter")
    if allowed then
      prof_enter("pipeline.combat_event.processing")
      Processing.process(ev_heal)
      prof_exit("pipeline.combat_event.processing")
    else
      release(ev_heal)
    end
  elseif (hit or 0) > 0 then
    bump("engine.pool.exhausted")
    Log:warn("event pool exhausted (heal)")
  end

  if ev_overheal then
    prof_enter("pipeline.combat_event.filter")
    local allowed = Filter.allow(ev_overheal)
    prof_exit("pipeline.combat_event.filter")
    if allowed then
      prof_enter("pipeline.combat_event.processing")
      Processing.process(ev_overheal)
      prof_exit("pipeline.combat_event.processing")
    else
      release(ev_overheal)
    end
  elseif (overflow or 0) > 0 then
    bump("engine.pool.exhausted")
    Log:warn("event pool exhausted (overheal)")
  end
  prof_exit("pipeline.combat_event")
end

function M.dispatch_restore_out(_result, _isError, _name, _g, _slot,
                                 _src, _sourceType, targetName, targetType, hit,
                                 pool, _dt, _log, _suid, _tuid,
                                 abilityId, _overflow)
  prof_enter("pipeline.combat_event")
  bump("engine.restore.in")
  local kind = (pool == POOL_MAGICKA and KIND_RESTORE_MAG) or (pool == POOL_STAMINA and KIND_RESTORE_STA) or nil
  if targetType == COMBAT_UNIT_TYPE_PLAYER then
    bump("engine.restore.dropped_self")
  elseif not kind then
    bump("engine.restore.dropped_pool")
  else
    local ev = Acquisition.acquire_restore(now(), kind, hit, targetType, abilityId, targetName)
    if ev then
      bump("engine.restore.accepted")
      Processing.process(ev)
    elseif (hit or 0) > 0 then
      bump("engine.pool.exhausted")
      Log:warn("event pool exhausted (restore)")
    end
  end
  prof_exit("pipeline.combat_event")
end

function M.dispatch_shield_abs(_result, isError, _name, _g, _slot,
                                _src, _sourceType, _tgt, targetType, hit,
                                _pt, _dt, _log, _suid, targetUnitId,
                                abilityId, _overflow)
  prof_enter("pipeline.combat_event")
  bump("engine.shield.in")
  if isError then bump("engine.shield.dropped_error") prof_exit("pipeline.combat_event") return end
  if not Verdant.Mode.uses("shield_abs") then
    bump("engine.shield.dropped_mode") prof_exit("pipeline.combat_event") return
  end

  local t = now()
  prof_enter("pipeline.combat_event.acquisition")
  local ev = Acquisition.acquire_shield_abs(t, hit, targetUnitId, targetType, abilityId)
  prof_exit("pipeline.combat_event.acquisition")
  if ev then
    prof_enter("pipeline.combat_event.filter")
    local allowed = Filter.allow(ev)
    prof_exit("pipeline.combat_event.filter")
    if allowed then
      if not Verdant.Coverage.is_group_target_type(ev.target_type)
         and Verdant.ShieldRegistry.on_member(ev.ability_id, ev.target_unit_id) then
        ev.target_type = COMBAT_UNIT_TYPE_GROUP
      end
      bump("engine.shield.accepted")
      prof_enter("pipeline.combat_event.processing")
      Processing.process(ev)
      prof_exit("pipeline.combat_event.processing")
    else
      release(ev)
    end
  elseif (hit or 0) > 0 then
    bump("engine.pool.exhausted")
    Log:warn("event pool exhausted (shield)")
  end
  Verdant.Coverage.touch(targetUnitId, t)
  prof_exit("pipeline.combat_event")
end

function M.dispatch_group_damage(_result, isError, _name, _g, _slot,
                                  _src, _sourceType, _tgt, _targetType, hit,
                                  _pt, _dt, _log, _suid, targetUnitId,
                                  _abilityId, _overflow)
  prof_enter("pipeline.combat_event")
  bump("engine.damage.in")
  if isError then bump("engine.damage.dropped_error") prof_exit("pipeline.combat_event") return end
  if not Verdant.Mode.uses("damage") then
    bump("engine.damage.dropped_mode") prof_exit("pipeline.combat_event") return
  end

  local t = now()
  prof_enter("pipeline.combat_event.acquisition")
  local ev = Acquisition.acquire_damage_group(t, hit, targetUnitId)
  prof_exit("pipeline.combat_event.acquisition")
  if ev then
    prof_enter("pipeline.combat_event.filter")
    local allowed = Filter.allow(ev)
    prof_exit("pipeline.combat_event.filter")
    if allowed then
      bump("engine.damage.accepted")
      prof_enter("pipeline.combat_event.processing")
      Processing.process(ev)
      prof_exit("pipeline.combat_event.processing")
    else
      release(ev)
    end
  elseif (hit or 0) > 0 then
    bump("engine.pool.exhausted")
    Log:warn("event pool exhausted (damage)")
  end
  prof_exit("pipeline.combat_event")
end

function M.dispatch_effect_player_src(changeType, _slot, _name, unitTag, beginTime, endTime,
                                       _stack, _icon, _depBuff, effectType, abilityType,
                                       _stat, _uname, unitId, abilityId, sourceType)
  prof_enter("pipeline.effect")
  bump("engine.effect.in_player_src")
  if changeType == EFFECT_RESULT_GAINED then
    bump("engine.effect.gained")
  elseif changeType == EFFECT_RESULT_FADED then
    bump("engine.effect.faded")
  end
  Verdant.ShieldRegistry.on_effect(changeType, abilityId, unitId, sourceType, endTime, unitTag)
  local ends = (endTime and endTime > (beginTime or 0)) and endTime or 0
  Verdant.BuffTracker.on_effect(changeType, abilityId, unitId, ends, now(), unitTag, effectType, abilityType)
  Verdant.BuffWatch.on_effect(changeType, abilityId, unitId, ends, now(), unitTag)
  prof_exit("pipeline.effect")
end

function M.dispatch_effect_on_group(_changeType, _slot, _name, unitTag, _bt, _endTime,
                                    _stack, _icon, _depBuff, _effectType, _abilityType,
                                    _stat, _uname, unitId)
  if unitTag and string_find(unitTag, "^group%d+$") then
    Verdant.GroupSet.add(unitId)
  end
end

function M.dispatch_death_state(_unitTag, isDead)
  bump(isDead and "engine.death.player_died" or "engine.death.player_res")
  if Verdant.TemporalBuffer.is_recording() then
    Verdant.TemporalBuffer.add_marker(now(), isDead)
    Log:info(isDead and "death marker" or "res marker")
  end
end

function M.dispatch_death_state_group(unitTag, isDead)
  if Verdant.zenimax.api.AreUnitsEqual(unitTag, "player") then return end
  bump(isDead and "engine.death.group_died" or "engine.death.group_res")
  if not Verdant.TemporalBuffer.is_recording() then return end
  local sv = Verdant.SavedVars
  if not (sv and sv.settings and sv.settings.group_death_markers) then return end
  Verdant.TemporalBuffer.add_marker(now(), isDead, unitTag)
  Log:info(isDead and "group death marker" or "group res marker", unitTag)
end

function M.dispatch_group_change()
  bump("engine.group.changed")
  Log:info("group changed; refreshing coverage mode")
  Verdant.Coverage.refresh_mode()
end

function M.dispatch_zone_arrived()
  bump("engine.zone.arrived")
  Verdant.Coverage.refresh_mode()
  Verdant.GroupSet.reset()
end

function M.dispatch_group_left()
  bump("engine.group.left")
  Log:info("group left; resetting groupset sz=", Verdant.GroupSet.size())
  Verdant.Coverage.refresh_mode()
  Verdant.GroupSet.reset()
end

function M.init()
  local E = Verdant.zenimax.events

  Verdant.Diagnostics.init()
  Verdant.Metrics.init()
  Verdant.Coverage.refresh_mode()

  E.register("Verdant_E_HealOut", EVENT_COMBAT_EVENT, function(...)
    local r = ...
    if r == ACTION_RESULT_HEAL
       or r == ACTION_RESULT_HOT_TICK
       or r == ACTION_RESULT_CRITICAL_HEAL
       or r == ACTION_RESULT_HOT_TICK_CRITICAL then
      M.dispatch_heal_out(...)
    elseif r == ACTION_RESULT_POWER_ENERGIZE then
      M.dispatch_restore_out(...)
    end
  end)
  E.add_filter("Verdant_E_HealOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter("Verdant_E_HealOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_ShieldAbs", EVENT_COMBAT_EVENT, M.dispatch_shield_abs)
  E.add_filter("Verdant_E_ShieldAbs", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE_SHIELDED)
  E.add_filter("Verdant_E_ShieldAbs", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_GroupDmg", EVENT_COMBAT_EVENT, function(...)
    local r = ...
    if r == ACTION_RESULT_DAMAGE
       or r == ACTION_RESULT_DOT_TICK
       or r == ACTION_RESULT_CRITICAL_DAMAGE
       or r == ACTION_RESULT_DOT_TICK_CRITICAL
       or r == ACTION_RESULT_BLOCKED_DAMAGE
       or r == ACTION_RESULT_FALL_DAMAGE then
      M.dispatch_group_damage(...)
    end
  end)
  E.add_filter("Verdant_E_GroupDmg", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_EffectPlayer", EVENT_EFFECT_CHANGED, M.dispatch_effect_player_src)
  E.add_filter("Verdant_E_EffectPlayer", EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  E.register("Verdant_E_EffectGroup", EVENT_EFFECT_CHANGED, M.dispatch_effect_on_group)
  E.add_filter("Verdant_E_EffectGroup", EVENT_EFFECT_CHANGED,
    C.REGISTER_FILTER_UNIT_TAG_PREFIX, "group")

  E.register("Verdant_E_WeaponPair", C.EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
    Verdant.BuffTracker.on_bars_changed()
  end)

  E.register("Verdant_E_Death", EVENT_UNIT_DEATH_STATE_CHANGED, M.dispatch_death_state)
  E.add_filter("Verdant_E_Death", EVENT_UNIT_DEATH_STATE_CHANGED,
    REGISTER_FILTER_UNIT_TAG, "player")

  E.register("Verdant_E_DeathGroup", EVENT_UNIT_DEATH_STATE_CHANGED, M.dispatch_death_state_group)
  E.add_filter("Verdant_E_DeathGroup", EVENT_UNIT_DEATH_STATE_CHANGED,
    C.REGISTER_FILTER_UNIT_TAG_PREFIX, "group")

  E.register("Verdant_E_GroupJ", EVENT_GROUP_MEMBER_JOINED, M.dispatch_group_change)
  E.register("Verdant_E_GroupL", EVENT_GROUP_MEMBER_LEFT,   M.dispatch_group_left)
  E.register("Verdant_E_GroupU", EVENT_GROUP_UPDATE,        M.dispatch_group_change)
  E.register("Verdant_E_PlayerAct", EVENT_PLAYER_ACTIVATED, M.dispatch_zone_arrived)

  Log:info("init complete")
end
