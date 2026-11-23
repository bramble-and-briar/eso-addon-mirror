Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ShieldRegistry = {}

local M = Verdant.ShieldRegistry

local pairs       = pairs
local tostring    = tostring
local string_find = string.find
local log      = Verdant.Log.for_module("shield_registry")

local C = Verdant.zenimax.constants
local COMBAT_UNIT_TYPE_PLAYER    = C.COMBAT_UNIT_TYPE_PLAYER
local EFFECT_RESULT_GAINED       = C.EFFECT_RESULT_GAINED
local EFFECT_RESULT_UPDATED      = C.EFFECT_RESULT_UPDATED
local EFFECT_RESULT_FULL_REFRESH = C.EFFECT_RESULT_FULL_REFRESH
local EFFECT_RESULT_TRANSFER     = C.EFFECT_RESULT_TRANSFER
local EFFECT_RESULT_FADED        = C.EFFECT_RESULT_FADED

local KEY_SPAN       = 16777216
local STALE_AFTER_MS = 1000

local function key(abilityId, targetUnitId)
  return (abilityId or 0) * KEY_SPAN + ((targetUnitId or 0) % KEY_SPAN)
end

local active = {}
local stats  = { gained = 0, faded = 0, hits = 0, misses = 0, stale = 0 }

local function is_member_tag(unitTag)
  return unitTag ~= nil and string_find(unitTag, "group", 1, true) == 1
end

function M.on_effect(changeType, abilityId, targetUnitId, sourceType, endTime, unitTag)
  if not abilityId or abilityId == 0 then return end
  if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
  if not targetUnitId or targetUnitId == 0 then return end

  local k = key(abilityId, targetUnitId)
  if changeType == EFFECT_RESULT_GAINED
     or changeType == EFFECT_RESULT_UPDATED
     or changeType == EFFECT_RESULT_FULL_REFRESH
     or changeType == EFFECT_RESULT_TRANSFER then
    local rec = active[k]
    if rec then
      rec.endTime = endTime
      rec.member = rec.member or is_member_tag(unitTag)
    else
      active[k] = { abilityId = abilityId, targetUnitId = targetUnitId, endTime = endTime,
                    member = is_member_tag(unitTag) }
    end
    stats.gained = stats.gained + 1
  elseif changeType == EFFECT_RESULT_FADED then
    active[k] = nil
    stats.faded = stats.faded + 1
  end
end

function M.is_self_cast(abilityId, targetUnitId, now_ms)
  local k = key(abilityId, targetUnitId)
  local rec = active[k]
  if rec ~= nil then
    local ends = rec.endTime
    if now_ms == nil or ends == nil or ends <= 0 or ends * 1000 + STALE_AFTER_MS >= now_ms then
      stats.hits = stats.hits + 1
      return true
    end
    active[k] = nil
    stats.stale = stats.stale + 1
  end
  stats.misses = stats.misses + 1
  return false
end

function M.on_member(abilityId, targetUnitId)
  local rec = active[key(abilityId, targetUnitId)]
  return rec ~= nil and rec.member == true
end

function M.reset()
  local n = 0
  for _ in pairs(active) do n = n + 1 end
  log:info("reset: cleared", n, "active shields,",
           "gained=", stats.gained, "faded=", stats.faded,
           "hits=", stats.hits, "misses=", stats.misses, "stale=", stats.stale)
  active = {}
  stats  = { gained = 0, faded = 0, hits = 0, misses = 0, stale = 0 }
end

function M.snapshot()
  local n = 0
  for _ in pairs(active) do n = n + 1 end
  return { active = n, gained = stats.gained, faded = stats.faded,
           hits = stats.hits, misses = stats.misses, stale = stats.stale }
end
