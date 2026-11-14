Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.DebuffTracker = {}
local M = Vermilion.DebuffTracker

local pairs      = pairs
local table_sort = table.sort
local log        = Vermilion.Log.for_module("debuff_tracker")

local C = Vermilion.zenimax.constants
local EFFECT_RESULT_GAINED       = C.EFFECT_RESULT_GAINED
local EFFECT_RESULT_UPDATED      = C.EFFECT_RESULT_UPDATED
local EFFECT_RESULT_FULL_REFRESH = C.EFFECT_RESULT_FULL_REFRESH
local EFFECT_RESULT_TRANSFER     = C.EFFECT_RESULT_TRANSFER
local EFFECT_RESULT_FADED        = C.EFFECT_RESULT_FADED
local BUFF_EFFECT_TYPE_DEBUFF    = C.BUFF_EFFECT_TYPE_DEBUFF

local MAX_TRACKED = 48

local by_id      = {}
local by_name    = {}
local slotted_names = {}
local slotted_keys  = {}
local excluded   = {}
local n_excluded = 0
local EXCLUDED_CAP = 20
local order      = {}
local n_tracked  = 0
local free_recs  = {}
local n_free     = 0
local recording  = false
local t_start    = 0
local t_end      = 0

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function wipe(t)
  for k in pairs(t) do t[k] = nil end
end

local function rec_reset(rec, id)
  rec.id           = id
  rec.step_quant   = nil
  rec.name         = nil
  rec.group        = "other"
  rec.n_ids        = 0
  rec.desc         = ""
  rec.applications = 0
  rec.unique_units = 0
  rec.max_conc     = 0
  rec.conc         = 0
  rec.uptime_ms    = 0
  rec.longest_gap_ms = 0
  rec.n_iv         = 0
  rec.n_steps      = 0
  rec.open_t0      = nil
  wipe(rec.holders)
  wipe(rec.holders_n)
  wipe(rec.holder_ids)
  wipe(rec.units_ever)
  wipe(rec.ids)
end

local function rec_acquire(id)
  local rec
  if n_free > 0 then
    rec = free_recs[n_free]
    free_recs[n_free] = nil
    n_free = n_free - 1
  else
    rec = { iv_t0 = {}, iv_t1 = {}, step_t = {}, step_c = {}, holders = {},
            holders_n = {}, holder_ids = {}, units_ever = {}, ids = {} }
  end
  rec_reset(rec, id)
  return rec
end

local function note_excluded(id, effectType, reason)
  if n_excluded >= EXCLUDED_CAP then return end
  local name = Vermilion.SkillColors.ability_name(id)
  if excluded[name] then return end
  n_excluded = n_excluded + 1
  excluded[name] = { id = id, et = effectType or -1, why = reason or "type" }
end

local function resolve_desc(id)
  local api = Vermilion.zenimax.api
  if not api.GetAbilityDescription then return "" end
  local d = api.GetAbilityDescription(id, nil, "player")
  if d and d ~= "" then
    bump("debuffs.desc_from_caster")
    return d
  end
  d = api.GetAbilityDescription(id)
  if d and d ~= "" then
    bump("debuffs.desc_plain")
    return d
  end
  bump("debuffs.desc_unresolved")
  return ""
end

local function skill_key_of(id)
  local st, li, si = Vermilion.zenimax.api.GetSpecificSkillAbilityKeysByAbilityId(id)
  if st and st > 0 and li and si then
    return st * 100000 + li * 1000 + si
  end
  return nil
end

local function scan_slotted()
  local api = Vermilion.zenimax.api
  local zc  = Vermilion.zenimax.constants
  local n   = 0
  for _, cat in ipairs({ zc.HOTBAR_CATEGORY_PRIMARY, zc.HOTBAR_CATEGORY_BACKUP }) do
    for slot = 3, 8 do
      local id = api.GetSlotBoundId(slot, cat)
      if id and id > 0 then
        local name = api.GetAbilityName(id)
        if name and name ~= "" and not slotted_names[name] then
          slotted_names[name] = true
          n = n + 1
        end
        local key = skill_key_of(id)
        if key then slotted_keys[key] = true end
      end
    end
  end
  if n > 0 then log:info("slotted scan:", n, "ability names") end
end

local function is_enemy_tag(tag)
  if tag == nil or tag == "" then return true end
  if tag == "player" then return false end
  local head = tag:sub(1, 5)
  if head == "group" then return false end
  if tag:sub(1, 9) == "playerpet" or tag:sub(1, 9) == "companion" then return false end
  return true
end

local function get_rec(id)
  local rec = by_id[id]
  if rec then return rec end
  local SC   = Vermilion.SkillColors
  local name = SC.ability_name(id)
  rec = by_name[name]
  if rec then
    by_id[id] = rec
    rec.n_ids = rec.n_ids + 1
    rec.ids[rec.n_ids] = id
    if rec.group == "other" then
      local g = SC.group_of_quiet and SC.group_of_quiet(id) or SC.group_of(id)
      if g and g ~= "other" then rec.group = g end
    end
    if rec.desc == "" then rec.desc = resolve_desc(id) end
    bump("debuffs.alias_merged")
    return rec
  end
  if slotted_names[name] then
    bump("debuffs.skipped_slotted")
    note_excluded(id, nil, "slotted ability")
    return nil
  end
  local skey = skill_key_of(id)
  if skey then
    bump("debuffs.skipped_skill")
    note_excluded(id, nil, slotted_keys[skey] and "slotted ability (renamed effect)" or "skill effect")
    return nil
  end
  if Vermilion.zenimax.api.IsAbilityPassive and Vermilion.zenimax.api.IsAbilityPassive(id) then
    bump("debuffs.skipped_passive")
    note_excluded(id, nil, "passive skill")
    return nil
  end
  if n_tracked >= MAX_TRACKED then
    bump("debuffs.dropped_capacity")
    return nil
  end
  rec = rec_acquire(id)
  rec.name    = name
  rec.group   = (SC.group_of_quiet and SC.group_of_quiet(id) or SC.group_of(id)) or "other"
  rec.n_ids   = 1
  rec.ids[1]  = id
  rec.desc    = resolve_desc(id)
  n_tracked   = n_tracked + 1
  by_id[id]   = rec
  by_name[name] = rec
  order[n_tracked] = rec
  bump("debuffs.tracked")
  return rec
end

local STEP_QUANT_MS   = 250
local STEP_COARSEN_AT = 1200

local function push_step(rec, t)
  local n = rec.n_steps
  if n > 0 and (t - rec.step_t[n]) < (rec.step_quant or STEP_QUANT_MS) then
    rec.step_c[n] = rec.conc
    return
  end
  n = n + 1
  rec.n_steps = n
  rec.step_t[n] = t
  rec.step_c[n] = rec.conc
  if n % STEP_COARSEN_AT == 0 then
    rec.step_quant = (rec.step_quant or STEP_QUANT_MS) * 2
  end
end

local function open_interval(rec, t)
  local n = rec.n_iv + 1
  rec.n_iv = n
  rec.iv_t0[n] = t
  rec.iv_t1[n] = 0
  rec.open_t0 = t
end

local function close_interval(rec, t)
  if rec.open_t0 == nil then return end
  rec.iv_t1[rec.n_iv] = t
  rec.open_t0 = nil
end

local function holder_add(rec, unitId, endTime, t, abilityId)
  local n = rec.holders_n[unitId] or 0
  local ids = rec.holder_ids[unitId]
  if not ids then
    ids = {}
    rec.holder_ids[unitId] = ids
  end
  local fresh = n == 0
  if fresh then
    rec.conc = rec.conc + 1
    if rec.conc > rec.max_conc then rec.max_conc = rec.conc end
    if rec.conc == 1 then open_interval(rec, t) end
    push_step(rec, t)
    rec.holders[unitId] = endTime or 0
  else
    local et = endTime or 0
    if et > (rec.holders[unitId] or 0) then rec.holders[unitId] = et end
  end
  if not ids[abilityId] then
    ids[abilityId] = true
    rec.holders_n[unitId] = n + 1
  end
  if not rec.units_ever[unitId] then
    rec.units_ever[unitId] = true
    rec.unique_units = rec.unique_units + 1
  end
  return fresh
end

local function holder_remove(rec, unitId, t, force, abilityId)
  local n = rec.holders_n[unitId]
  if n == nil or n == 0 then return end
  local ids = rec.holder_ids[unitId]
  if not force then
    if not ids or not ids[abilityId] then return end
    ids[abilityId] = nil
    n = n - 1
    if n > 0 then
      rec.holders_n[unitId] = n
      return
    end
  elseif ids then
    wipe(ids)
  end
  rec.holders_n[unitId] = 0
  rec.holders[unitId] = nil
  rec.conc = rec.conc - 1
  push_step(rec, t)
  if rec.conc == 0 then close_interval(rec, t) end
end

function M.on_effect(changeType, abilityId, unitId, endTime, now_ms, unitTag, effectType)
  if not recording then return end
  if not abilityId or abilityId == 0 then return end
  if not unitId or unitId == 0 then
    bump("debuffs.no_unit_id")
    return
  end
  if not is_enemy_tag(unitTag) then
    bump("debuffs.skipped_friendly")
    return
  end

  if changeType == EFFECT_RESULT_GAINED
     or changeType == EFFECT_RESULT_UPDATED
     or changeType == EFFECT_RESULT_FULL_REFRESH
     or changeType == EFFECT_RESULT_TRANSFER then
    if by_id[abilityId] == nil and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then
      bump("debuffs.skipped_not_debuff")
      note_excluded(abilityId, effectType, "not a debuff")
      return
    end
    if changeType == EFFECT_RESULT_UPDATED and (endTime or 0) * 1000 <= now_ms then
      local known = by_id[abilityId]
      if not known or (known.holders_n[unitId] or 0) == 0 then
        bump("debuffs.empty_update")
        return
      end
    end
    local rec = get_rec(abilityId)
    if not rec then return end
    if changeType == EFFECT_RESULT_GAINED then bump("debuffs.gained") else bump("debuffs.refreshed") end
    if holder_add(rec, unitId, endTime, now_ms, abilityId) then
      rec.applications = rec.applications + 1
    end
  elseif changeType == EFFECT_RESULT_FADED then
    local rec = by_id[abilityId]
    if rec then
      bump("debuffs.faded")
      holder_remove(rec, unitId, now_ms, false, abilityId)
    end
  end
end

local function purge_slotted_matches()
  for i = n_tracked, 1, -1 do
    local rec = order[i]
    if slotted_names[rec.name] then
      bump("debuffs.purged_rescan")
      note_excluded(rec.ids[1], nil, "slotted ability (bar swap rescan)")
      for k = 1, rec.n_ids do by_id[rec.ids[k]] = nil end
      by_name[rec.name] = nil
      table.remove(order, i)
      n_tracked = n_tracked - 1
      n_free = n_free + 1
      free_recs[n_free] = rec
    end
  end
end

function M.on_bars_changed()
  if not recording then return end
  bump("debuffs.bars_rescan")
  scan_slotted()
  purge_slotted_matches()
end

function M.expire_stale(now_ms)
  local now_s = now_ms / 1000
  for i = 1, n_tracked do
    local rec = order[i]
    for unitId, endTime in pairs(rec.holders) do
      if endTime and endTime > 0 and endTime < now_s then
        bump("debuffs.expired_watchdog")
        holder_remove(rec, unitId, now_ms, true)
      end
    end
  end
end

function M.start_session(now_ms)
  wipe(by_id)
  wipe(by_name)
  wipe(excluded)
  n_excluded = 0
  wipe(slotted_names)
  wipe(slotted_keys)
  scan_slotted()
  for i = 1, n_tracked do
    local rec = order[i]
    n_free = n_free + 1
    free_recs[n_free] = rec
    order[i] = nil
  end
  n_tracked = 0
  recording = true
  t_start   = now_ms
  t_end     = 0
  log:info("session start t=", now_ms)
end

local function finalize_rec(rec, t)
  close_interval(rec, t)
  local lo, hi = Vermilion.Metrics.fight_bounds()
  if not lo then lo, hi = t_start, t end
  local uptime = 0
  local longest = 0
  local prev_end = lo
  for i = 1, rec.n_iv do
    local a, b = rec.iv_t0[i], rec.iv_t1[i]
    if a > hi then a = hi end
    if b > hi then b = hi end
    local gap = a - prev_end
    if gap > longest then longest = gap end
    if b > prev_end then prev_end = b end
    if a < lo then a = lo end
    if b > a then uptime = uptime + (b - a) end
  end
  rec.uptime_ms = uptime
  local tail = hi - prev_end
  if tail > longest then longest = tail end
  rec.longest_gap_ms = longest
end

local function by_uptime_desc(a, b) return a.uptime_ms > b.uptime_ms end

function M.finalize(now_ms)
  if not recording then return end
  recording = false
  t_end = now_ms
  for i = 1, n_tracked do
    finalize_rec(order[i], now_ms)
  end
  table_sort(order, by_uptime_desc)
  log:info("session finalize: tracked=", n_tracked, "dur_ms=", now_ms - t_start)
end

function M.avg_concurrency(rec)
  if rec.uptime_ms <= 0 or rec.n_steps == 0 then return 0 end
  local weighted = 0
  local t_close = t_end
  for i = 1, rec.n_steps do
    local t0 = rec.step_t[i]
    local t1 = (i < rec.n_steps) and rec.step_t[i + 1] or t_close
    weighted = weighted + rec.step_c[i] * (t1 - t0)
  end
  return weighted / rec.uptime_ms
end

function M.is_recording() return recording end
function M.count() return n_tracked end
function M.session_start() return t_start end
function M.session_end() return t_end end
function M.fight_ms()
  local f = Vermilion.Metrics.fight_ms()
  if f > 0 then return f end
  return t_end - t_start
end
function M.uptime_of(rec)
  local f = M.fight_ms()
  if f <= 0 then return 0 end
  local p = rec.uptime_ms / f
  return (p > 1) and 1 or p
end

function M.load_session(metas, steps, t0, t1)
  M.reset()
  recording = false
  t_start = t0
  t_end   = t1
  for i = 1, #metas do
    local m = metas[i]
    order[i] = {
      name = m.name, id = m.id, group = m.grp or "other", desc = m.desc or "",
      uptime_ms = m.uptime_ms or 0, max_conc = m.max_conc or 1,
      unique_units = m.unique_units or 0, applications = m.applications or 0,
      conc_avg = m.conc_avg or 0, longest_gap_ms = m.longest_gap_ms or 0,
      n_steps = 0, step_t = {}, step_c = {},
      n_iv = 0, iv_t0 = {}, iv_t1 = {},
      holders = {}, holders_n = {}, holder_ids = {}, units_ever = {}, ids = { m.id }, n_ids = 1,
    }
    n_tracked = i
  end
  for i = 1, #steps do
    local st = steps[i]
    local rec = order[st.b + 1]
    if rec then
      rec.n_steps = rec.n_steps + 1
      rec.step_t[rec.n_steps] = st.t
      rec.step_c[rec.n_steps] = st.c
    end
  end
  log:info("session loaded: debuffs=", n_tracked, "steps=", #steps)
end

function M.get(i) return order[i] end

function M.iterate(fn)
  for i = 1, n_tracked do fn(i, order[i]) end
end

function M.concurrency_at(rec, t)
  local n = rec.n_steps
  if n == 0 then return 0 end
  if t < rec.step_t[1] then return 0 end
  local lo, hi = 1, n
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if rec.step_t[mid] <= t then lo = mid else hi = mid - 1 end
  end
  return rec.step_c[lo]
end

function M.report_lines()
  local lines = {}
  local dur = (t_end > t_start) and (t_end - t_start) or 0
  lines[#lines + 1] = string.format("tracked=%d recording=%s session=%.1fs cap=%d",
    n_tracked, tostring(recording), dur / 1000, MAX_TRACKED)
  for i = 1, n_tracked do
    local rec = order[i]
    local pct = (dur > 0) and (rec.uptime_ms / dur * 100) or 0
    lines[#lines + 1] = string.format(
      "%-28s up=%5.1f%%  apps=%d  targets=%d  conc_max=%d  conc_avg=%.1f  ivs=%d  gap=%.1fs  grp=%s  ids=%s",
      rec.name or tostring(rec.id), pct, rec.applications, rec.unique_units,
      rec.max_conc, M.avg_concurrency(rec), rec.n_iv, rec.longest_gap_ms / 1000,
      rec.group, table.concat(rec.ids, "/", 1, rec.n_ids))
  end
  if n_tracked == 0 then lines[#lines + 1] = "(no debuffs tracked this session)" end
  if n_excluded > 0 then
    lines[#lines + 1] = string.format("excluded (%d):", n_excluded)
    for name, e in pairs(excluded) do
      lines[#lines + 1] = string.format("  %-28s %s  (id=%d effectType=%d)", name, e.why, e.id, e.et)
    end
  end
  local sn = {}
  for name in pairs(slotted_names) do sn[#sn + 1] = name end
  table_sort(sn)
  lines[#lines + 1] = "slotted filter: " .. ((#sn > 0) and table.concat(sn, ", ") or "(empty scan)")
  return lines
end

function M.reset()
  M.start_session(0)
  recording = false
end
