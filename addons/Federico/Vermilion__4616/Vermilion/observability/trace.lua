Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Trace = {}
local M = Vermilion.Trace

local NOOP = function() end
M.start       = NOOP
M.stop        = NOOP
M.save        = NOOP
M.clear       = NOOP
M.init        = NOOP
M.on_record   = NOOP
M.on_stop     = NOOP
M.on_adopted  = NOOP
M.set_auto    = NOOP
M.auto_enabled = function() return false end
M.status_line = function() return "trace disabled (DEBUG=false)" end
M.mark        = function() return "trace disabled (DEBUG=false)" end

if not Vermilion.Constants.DEBUG then return end

local d       = d
local select  = select
local type    = type
local api     = Vermilion.zenimax.api
local zev     = Vermilion.zenimax.events
local C       = Vermilion.zenimax.constants
local GetGameTimeMilliseconds = api.GetGameTimeMilliseconds

local CAP       = 60000
local RING_EVENTS = 200000
local CHUNK_MAX = 1800
local RING      = 30

local CONST_NAMES = {
  "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK",
  "ACTION_RESULT_DOT_TICK_CRITICAL", "ACTION_RESULT_BLOCKED_DAMAGE",
  "ACTION_RESULT_FALL_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED",
  "ACTION_RESULT_HEAL", "ACTION_RESULT_CRITICAL_HEAL", "ACTION_RESULT_HOT_TICK",
  "ACTION_RESULT_HOT_TICK_CRITICAL", "ACTION_RESULT_HEAL_ABSORBED",
  "EFFECT_RESULT_GAINED", "EFFECT_RESULT_FADED", "EFFECT_RESULT_UPDATED",
  "EFFECT_RESULT_FULL_REFRESH", "EFFECT_RESULT_TRANSFER",
  "COMBAT_MECHANIC_FLAGS_MAGICKA", "COMBAT_MECHANIC_FLAGS_STAMINA", "COMBAT_MECHANIC_FLAGS_ULTIMATE",
  "POWERTYPE_HEALTH", "BUFF_EFFECT_TYPE_BUFF", "BUFF_EFFECT_TYPE_DEBUFF",
  "COMBAT_UNIT_TYPE_PLAYER", "COMBAT_UNIT_TYPE_PLAYER_PET",
  "COMBAT_UNIT_TYPE_GROUP", "COMBAT_UNIT_TYPE_OTHER",
  "DAMAGE_TYPE_NONE", "DAMAGE_TYPE_GENERIC", "DAMAGE_TYPE_PHYSICAL", "DAMAGE_TYPE_FIRE",
  "DAMAGE_TYPE_SHOCK", "DAMAGE_TYPE_OBLIVION", "DAMAGE_TYPE_COLD", "DAMAGE_TYPE_EARTH",
  "DAMAGE_TYPE_MAGIC", "DAMAGE_TYPE_DROWN", "DAMAGE_TYPE_DISEASE", "DAMAGE_TYPE_POISON",
  "DAMAGE_TYPE_BLEED",
}

local EFFECT_NOISE = { [2240] = true, [2245] = true, [2250] = true }

local lines  = {}
local n      = 0
local active = false
local capped = false

local function fld(v)
  local tv = type(v)
  if v == nil then return "" end
  if tv == "boolean" then return v and "T" or "F" end
  if tv == "number" then return tostring(v) end
  return (tostring(v):gsub("[\t\n]", " "))
end

local function rec(tag, ...)
  if not active then return end
  if n >= CAP then
    active = false
    capped = true
    d("[trace] capacity reached (" .. CAP .. "), capture stopped; what was captured is kept and saved on stop")
    return
  end
  local parts = { tag, tostring(GetGameTimeMilliseconds()) }
  local argc = select("#", ...)
  for i = 1, argc do
    parts[#parts + 1] = fld((select(i, ...)))
  end
  n = n + 1
  lines[n] = table.concat(parts, "\t")
end

local function rec_group()
  local names = {}
  local size = api.GetGroupSize() or 0
  local player_slot = 0
  for i = 1, size do
    names[i] = (api.GetUnitName("group" .. i) or ""):gsub("[|\t\n]", " ")
    if api.AreUnitsEqual and api.AreUnitsEqual("group" .. i, "player") then player_slot = i end
  end
  rec("GR", api.IsUnitGrouped("player"), size, table.concat(names, "|"), player_slot)
end

local function rec_bosses()
  local names = {}
  if C.BOSS_RANK_ITERATION_BEGIN and api.DoesUnitExist then
    for i = C.BOSS_RANK_ITERATION_BEGIN, C.BOSS_RANK_ITERATION_END do
      local tag = "boss" .. i
      if api.DoesUnitExist(tag) then
        names[#names + 1] = (api.GetUnitName(tag) or ""):gsub("[|\t\n]", " ")
      end
    end
  end
  rec("BO", table.concat(names, "|"))
end

function M.set_ring_events(v) RING_EVENTS = v end

function M.set_cap(cap)
  CAP = cap
end

function M.start()
  active = true
  capped = false
  rec("EP", api.GetTimeStamp() or 0)
  rec_group()
  rec_bosses()
  d("[trace] capturing (" .. n .. "/" .. CAP .. " events)")
end

function M.mark(label)
  label = label or ""
  local ts = api.GetTimeStamp() or 0
  local gm = GetGameTimeMilliseconds()
  rec("MK", label, ts)
  return "mark " .. (label ~= "" and ("'" .. label .. "' ") or "")
    .. "epoch=" .. ts .. " game_ms=" .. gm
    .. (active and "" or " (trace idle, not recorded)")
end

function M.stop()
  active = false
  d("[trace] stopped at " .. n .. " events")
end

function M.clear(sv)
  lines  = {}
  n      = 0
  active = false
  if sv then
    sv.trace  = nil
    sv.traces = nil
  end
end

local function reset()
  lines  = {}
  n      = 0
  active = false
  capped = false
end

function M.save(sv)
  local chunks = {}
  local buf, blen = {}, 0
  for i = 1, n do
    local llen = #lines[i] + 1
    if blen + llen > CHUNK_MAX and #buf > 0 then
      chunks[#chunks + 1] = table.concat(buf, "\n")
      buf, blen = {}, 0
    end
    buf[#buf + 1] = lines[i]
    blen = blen + llen
  end
  if #buf > 0 then chunks[#chunks + 1] = table.concat(buf, "\n") end
  local consts = { API_VERSION = api.GetAPIVersion() }
  for _, k in ipairs(CONST_NAMES) do
    consts[k] = rawget(_G, k)
  end
  local temporal = sv.temporal or {}
  local entry = {
    version   = 2,
    build     = Vermilion.Constants.VERSION,
    settings  = {
      sample_rate_ms = temporal.sample_rate_ms or Vermilion.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT,
      sample_auto    = (temporal.sample_auto == true) or nil,
      time_window_s  = Vermilion.Settings and Vermilion.Settings.snapshot().time_window_s or Vermilion.Constants.TEMPORAL.CAPACITY,
    },
    world     = api.GetWorldName(),
    zone      = (api.GetUnitZone and api.GetUnitZone("player")) or "",
    ts        = (api.GetTimeStamp and api.GetTimeStamp()) or 0,
    count     = n,
    chunks    = chunks,
    constants = consts,
  }
  sv.trace = entry
  sv.traces = sv.traces or {}
  local ring = sv.traces
  ring[#ring + 1] = entry
  local held = 0
  for i = 1, #ring do held = held + (ring[i].count or 0) end
  while #ring > 1 and (#ring > RING or held > RING_EVENTS) do
    held = held - (ring[1].count or 0)
    table.remove(ring, 1)
  end
  d("[trace] " .. n .. " events staged, slot " .. #ring .. "; /vermilion flush writes them to disk")
  return entry
end

function M.auto_enabled(sv)
  return sv and sv.debug and sv.debug.auto_trace == true or false
end

function M.set_auto(sv, on)
  if not sv then return end
  sv.debug = sv.debug or {}
  sv.debug.auto_trace = on and true or false
end

local function record_power_baseline()
  if not api.GetUnitPower then return end
  for _, flag in ipairs({ C.COMBAT_MECHANIC_FLAGS_MAGICKA, C.COMBAT_MECHANIC_FLAGS_STAMINA, C.COMBAT_MECHANIC_FLAGS_ULTIMATE }) do
    if flag then
      local value, max, effective = api.GetUnitPower("player", flag)
      if value then rec("PU", "player", 0, flag, value, max or 0, effective or max or 0) end
    end
  end
end

function M.on_record(sv)
  if not M.auto_enabled(sv) then return end
  reset()
  M.start()
  record_power_baseline()
  local U = Vermilion.Ultimate
  U.refresh_slots()
  rec("UC", U.bar_id(1) or 0, U.cost(1) or 0, U.bar_id(2) or 0, U.cost(2) or 0)
end

function M.on_stop(sv)
  if not M.auto_enabled(sv) then return end
  if not (active or capped) then return end
  M.stop()
  if n > 0 then M.save(sv) end
end

function M.on_adopted(ev)
  rec("CE", ev.result, false, "", 0, 0, "", C.COMBAT_UNIT_TYPE_PLAYER, ev.target_name, ev.target_type, ev.amount, 0,
      ev.damage_type or 0, false, ev.source_unit_id, ev.target_unit_id, ev.ability_id, ev.overflow or 0)
end

function M.status_line()
  return "trace " .. (active and "ACTIVE" or "idle") .. (capped and " (capped)" or "")
    .. "  events=" .. n .. "/" .. CAP
end

function M.init()
  zev.register("Vermilion_Trace_CE", C.EVENT_COMBAT_EVENT, function(...)
    local result = ...
    if EFFECT_NOISE[result] and select(7, ...) ~= C.COMBAT_UNIT_TYPE_PLAYER then return end
    rec("CE", ...)
  end)
  zev.register("Vermilion_Trace_EF", C.EVENT_EFFECT_CHANGED, function(...)
    if select(16, ...) ~= C.COMBAT_UNIT_TYPE_PLAYER and select(4, ...) ~= "player" then return end
    rec("EF", ...)
  end)
  if C.EVENT_POWER_UPDATE then
    zev.register("Vermilion_Trace_PU", C.EVENT_POWER_UPDATE, function(...) rec("PU", ...) end)
    zev.add_filter("Vermilion_Trace_PU", C.EVENT_POWER_UPDATE, C.REGISTER_FILTER_UNIT_TAG, "player")
  end
  if C.EVENT_ACTION_SLOT_ABILITY_USED then
    zev.register("Vermilion_Trace_SU", C.EVENT_ACTION_SLOT_ABILITY_USED, function(slot)
      if not active then return end
      local id, pool, cost, channel = Vermilion.Casts.slot_info(slot)
      rec("SU", slot, id, pool, cost, channel)
    end)
  end
  zev.register("Vermilion_Trace_CS", C.EVENT_PLAYER_COMBAT_STATE, function(in_combat) rec("CS", in_combat) end)
  if C.EVENT_UNIT_DEATH_STATE_CHANGED then
    zev.register("Vermilion_Trace_DE", C.EVENT_UNIT_DEATH_STATE_CHANGED, function(tag, dead) rec("DE", tag, dead) end)
  end
  if C.EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
    zev.register("Vermilion_Trace_WP", C.EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() rec("WP") end)
  end
  if C.EVENT_BOSSES_CHANGED then
    zev.register("Vermilion_Trace_BO", C.EVENT_BOSSES_CHANGED, rec_bosses)
  end
  zev.register("Vermilion_Trace_GJ", C.EVENT_GROUP_MEMBER_JOINED, rec_group)
  zev.register("Vermilion_Trace_GL", C.EVENT_GROUP_MEMBER_LEFT, rec_group)
  zev.register("Vermilion_Trace_GU", C.EVENT_GROUP_UPDATE, rec_group)
end
