Verdant = Verdant or {}
local Verdant = Verdant

Verdant.BuffTracker = {}
local M = Verdant.BuffTracker

local pairs      = pairs
local table_sort = table.sort
local string_find = string.find
local log        = Verdant.Log.for_module("buff_tracker")

local C = Verdant.zenimax.constants
local EFFECT_RESULT_GAINED       = C.EFFECT_RESULT_GAINED
local EFFECT_RESULT_UPDATED      = C.EFFECT_RESULT_UPDATED
local EFFECT_RESULT_FULL_REFRESH = C.EFFECT_RESULT_FULL_REFRESH
local EFFECT_RESULT_TRANSFER     = C.EFFECT_RESULT_TRANSFER
local EFFECT_RESULT_FADED        = C.EFFECT_RESULT_FADED
local BUFF_EFFECT_TYPE_BUFF      = C.BUFF_EFFECT_TYPE_BUFF
local ABILITY_TYPE_HEAL          = C.ABILITY_TYPE_HEAL
local ABILITY_TYPE_IMMUNITY      = C.ABILITY_TYPE_IMMUNITY

local MAX_TRACKED = 48
local IDS_PER_ROW = 64
local SAME_GAIN_MS = 50

local BUFF_VETO = {
  [217608] = true,
  [221161] = true,
  [222285] = true,
}

local BUFF_BLOCK = {
}

local by_id      = {}
local by_name    = {}
local excluded   = {}
local n_excluded = 0
local EXCLUDED_CAP = 20
local slotted_names = {}
local slotted_keys  = {}
local order      = {}
local n_tracked  = 0
local free_recs  = {}
local n_free     = 0
local recording  = false
local t_start    = 0
local t_end      = 0

local function bump(key) Verdant.Diagnostics.bump(key) end

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
  rec.desc_tries   = 0
  rec.only_self    = true
  rec.on_group     = false
  rec.vetoed       = false
  rec.immunity     = false
  rec.applications = 0
  rec.unique_units = 0
  rec.max_conc     = 0
  rec.conc         = 0
  rec.uptime_ms    = 0
  rec.longest_gap_ms = 0
  rec.n_iv         = 0
  rec.n_steps      = 0
  rec.open_t0      = nil
  wipe(rec.held)
  wipe(rec.gained_at)
  wipe(rec.ended)
  wipe(rec.per_unit)
  wipe(rec.units_ever)
  wipe(rec.ids)
  wipe(rec.index)
end

local function rec_acquire(id)
  local rec
  if n_free > 0 then
    rec = free_recs[n_free]
    free_recs[n_free] = nil
    n_free = n_free - 1
  else
    rec = { iv_t0 = {}, iv_t1 = {}, step_t = {}, step_c = {}, held = {}, gained_at = {}, ended = {},
            per_unit = {}, units_ever = {}, ids = {}, index = {} }
  end
  rec_reset(rec, id)
  return rec
end

local function note_excluded(id, effectType, abilityType, reason)
  if n_excluded >= EXCLUDED_CAP then return end
  local name = Verdant.SkillColors.ability_name(id)
  if excluded[name] then return end
  n_excluded = n_excluded + 1
  excluded[name] = { id = id, et = effectType or -1, at = abilityType or -1,
                     why = reason or "type" }
end

local function on_group_tag(tag)
  if tag == "player" or tag == "companion" then return true end
  return type(tag) == "string" and string_find(tag, "^group%d") ~= nil
end

local function skill_key_of(id)
  local st, li, si = Verdant.zenimax.api.GetSpecificSkillAbilityKeysByAbilityId(id)
  if st and st > 0 and li and si then
    return st * 100000 + li * 1000 + si
  end
  return nil
end

local function scan_slotted()
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
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

local function resolve_desc(id, tag)
  local api = Verdant.zenimax.api
  local d = api.GetAbilityDescription(id, nil, "player")
  if d and d ~= "" then
    bump("buffs.desc_from_caster")
    return d
  end
  d = api.GetAbilityDescription(id)
  if d and d ~= "" then
    bump("buffs.desc_plain")
    return d
  end
  if tag and tag ~= "" then
    local n = api.GetNumBuffs(tag) or 0
    for i = 1, n do
      local _, _, _, buffSlot, _, _, _, _, _, _, buffAbilityId = api.GetUnitBuffInfo(tag, i)
      if buffAbilityId == id then
        d = api.GetAbilityEffectDescription(buffSlot)
        if d and d ~= "" then
          bump("buffs.desc_from_slot")
          return d
        end
        break
      end
    end
  end
  bump("buffs.desc_unresolved")
  return ""
end

local function get_rec(id, tag)
  local rec = by_id[id]
  if rec then return rec end
  local SC   = Verdant.SkillColors
  local name = SC.ability_name(id)
  rec = by_name[name]
  if rec then
    if rec.n_ids >= IDS_PER_ROW then
      bump("buffs.dropped_alias")
      return nil
    end
    by_id[id] = rec
    rec.n_ids = rec.n_ids + 1
    rec.ids[rec.n_ids] = id
    rec.index[id] = rec.n_ids
    if rec.group == "other" then
      local g = SC.group_of_quiet(id)
      if g and g ~= "other" then rec.group = g end
    end
    if rec.desc == "" then
      rec.desc = resolve_desc(id, tag)
    end
    bump("buffs.alias_merged")
    return rec
  end
  if slotted_names[name] then
    bump("buffs.skipped_ability")
    note_excluded(id, nil, nil, "slotted ability")
    return nil
  end
  if BUFF_BLOCK[id] then
    bump("buffs.skipped_curated_block")
    note_excluded(id, nil, nil, "curated block")
    return nil
  end
  local skey = skill_key_of(id)
  if skey and slotted_keys[skey] then
    bump("buffs.skipped_ability_morph")
    note_excluded(id, nil, nil, "slotted ability (renamed aura)")
    return nil
  end
  if skey then
    if BUFF_VETO[id] then
      bump("buffs.aura_vetoed_by_override")
    else
      bump("buffs.skipped_skill_aura")
      note_excluded(id, nil, nil, "skill aura")
      return nil
    end
  end
  if Verdant.zenimax.api.IsAbilityPassive(id) then
    bump("buffs.skipped_passive")
    note_excluded(id, nil, nil, "passive skill")
    return nil
  end
  local grp = SC.group_of_quiet(id) or "other"
  if grp ~= "other" and grp ~= "item" and grp ~= "champion" and grp ~= "synergy" and not BUFF_VETO[id] and not SC.user_group(id) then
    bump("buffs.skipped_skill_line_proc")
    note_excluded(id, nil, nil, "skill-line proc (" .. grp .. ")")
    return nil
  end
  if n_tracked >= MAX_TRACKED then
    bump("buffs.dropped_capacity")
    return nil
  end
  rec = rec_acquire(id)
  rec.name    = name
  rec.group   = grp
  rec.n_ids   = 1
  rec.ids[1]  = id
  rec.index[id] = 1
  rec.desc    = resolve_desc(id, tag)
  rec.desc_tries = (tag and tag ~= "") and 1 or 0
  rec.vetoed  = BUFF_VETO[id] == true
  n_tracked   = n_tracked + 1
  by_id[id]   = rec
  by_name[name] = rec
  order[n_tracked] = rec
  bump("buffs.tracked")
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

local function held_key(rec, abilityId, unitId)
  return unitId * IDS_PER_ROW + rec.index[abilityId] - 1
end

local function holder_add(rec, key, unitId, endTime, t)
  local added = rec.held[key] == nil
  rec.held[key] = endTime or 0
  if added then
    local n = (rec.per_unit[unitId] or 0) + 1
    rec.per_unit[unitId] = n
    if n == 1 then
      rec.conc = rec.conc + 1
      if rec.conc > rec.max_conc then rec.max_conc = rec.conc end
      if rec.conc == 1 then open_interval(rec, t) end
      push_step(rec, t)
    end
  end
  if not rec.units_ever[unitId] then
    rec.units_ever[unitId] = true
    rec.unique_units = rec.unique_units + 1
  end
end

local function holder_drop(rec, key, unitId, t)
  if rec.held[key] == nil then return end
  rec.held[key] = nil
  local n = rec.per_unit[unitId] - 1
  rec.per_unit[unitId] = n
  if n == 0 then
    rec.conc = rec.conc - 1
    push_step(rec, t)
    if rec.conc == 0 then close_interval(rec, t) end
  end
end

function M.on_effect(changeType, abilityId, unitId, endTime, now_ms, unitTag, effectType, abilityType)
  if not recording then return end
  if not abilityId or abilityId == 0 then return end
  if not unitId or unitId == 0 then
    bump("buffs.no_unit_id")
    return
  end

  if changeType == EFFECT_RESULT_GAINED
     or changeType == EFFECT_RESULT_UPDATED
     or changeType == EFFECT_RESULT_FULL_REFRESH
     or changeType == EFFECT_RESULT_TRANSFER then
    if by_id[abilityId] == nil then
      if effectType ~= BUFF_EFFECT_TYPE_BUFF then
        bump("buffs.skipped_not_buff")
        note_excluded(abilityId, effectType, abilityType, "not a buff")
        return
      end
      if abilityType == ABILITY_TYPE_HEAL then
        bump("buffs.skipped_heal_effect")
        note_excluded(abilityId, effectType, abilityType, "heal effect")
        return
      end
    end
    local rec = get_rec(abilityId, unitTag)
    if not rec then return end
    if abilityType == ABILITY_TYPE_IMMUNITY then rec.immunity = true end
    local key = held_key(rec, abilityId, unitId)
    local gained = changeType == EFFECT_RESULT_GAINED
    if not gained and endTime and endTime > 0 and endTime * 1000 <= now_ms then
      bump("buffs.already_over")
      return
    end
    if not gained and rec.ended[key] and rec.held[key] == nil then
      bump("buffs.refresh_after_end")
      return
    end
    if unitTag == "player" then
      Verdant.GroupSet.set_player(unitId)
    elseif unitId ~= Verdant.GroupSet.player_id() then
      rec.only_self = false
    end
    if on_group_tag(unitTag) then rec.on_group = true end
    holder_add(rec, key, unitId, endTime, now_ms)
    if gained then
      local last = rec.gained_at[key]
      if last == nil or now_ms - last > SAME_GAIN_MS then rec.applications = rec.applications + 1 end
      rec.gained_at[key] = now_ms
      bump("buffs.gained")
      if rec.desc == "" and unitTag and unitTag ~= "" and rec.desc_tries < 5 then
        rec.desc_tries = rec.desc_tries + 1
        rec.desc = resolve_desc(abilityId, unitTag)
      end
    else
      bump("buffs.refreshed")
    end
  elseif changeType == EFFECT_RESULT_FADED then
    local rec = by_id[abilityId]
    if rec then
      bump("buffs.faded")
      local key = held_key(rec, abilityId, unitId)
      rec.ended[key] = true
      holder_drop(rec, key, unitId, now_ms)
    end
  end
end

local function purge_slotted_matches()
  for i = n_tracked, 1, -1 do
    local rec = order[i]
    if slotted_names[rec.name] then
      bump("buffs.purged_rescan")
      note_excluded(rec.ids[1], nil, nil, "slotted ability (bar swap rescan)")
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
  bump("buffs.bars_rescan")
  scan_slotted()
  purge_slotted_matches()
end

function M.expire_stale(now_ms)
  local now_s = now_ms / 1000
  for i = 1, n_tracked do
    local rec = order[i]
    for key, endTime in pairs(rec.held) do
      if endTime > 0 and endTime < now_s then
        bump("buffs.expired_watchdog")
        holder_drop(rec, key, (key - key % IDS_PER_ROW) / IDS_PER_ROW, now_ms)
      end
    end
    if rec.desc == "" and rec.desc_tries < 8 then
      rec.desc_tries = rec.desc_tries + 1
      rec.desc = resolve_desc(rec.id, "player")
      if rec.desc ~= "" then bump("buffs.desc_resolved_tick") end
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
  local uptime = 0
  for i = 1, rec.n_iv do
    uptime = uptime + (rec.iv_t1[i] - rec.iv_t0[i])
  end
  rec.uptime_ms = uptime
  local longest = 0
  local prev_end = t_start
  for i = 1, rec.n_iv do
    local gap = rec.iv_t0[i] - prev_end
    if gap > longest then longest = gap end
    prev_end = rec.iv_t1[i]
  end
  local tail = t - prev_end
  if tail > longest then longest = tail end
  rec.longest_gap_ms = longest
end

function M.shown(rec)
  if rec.on_group == false then return false end
  return not (rec.only_self and (rec.desc == "" or rec.immunity) and rec.group ~= "item" and not rec.vetoed)
end

function M.finalize(now_ms)
  if not recording then return end
  recording = false
  t_end = now_ms
  for i = 1, n_tracked do
    finalize_rec(order[i], now_ms)
  end
  for i = n_tracked, 1, -1 do
    local rec = order[i]
    if not M.shown(rec) then
      if rec.on_group then
        bump("buffs.excluded_self_state")
        note_excluded(rec.id, nil, nil, "self-only state")
      else
        bump("buffs.excluded_off_group")
        note_excluded(rec.id, nil, nil, "never on the group")
      end
      for k = 1, rec.n_ids do by_id[rec.ids[k]] = nil end
      by_name[rec.name] = nil
      table.remove(order, i)
      n_tracked = n_tracked - 1
      n_free = n_free + 1
      free_recs[n_free] = rec
    end
  end
  table_sort(order, function(a, b) return a.uptime_ms > b.uptime_ms end)
  for i = 1, n_tracked do
    local rec = order[i]
    for k = 1, rec.n_ids do Verdant.BuffOrigin.note(rec.ids[k], rec.name) end
  end
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

function M.load_session(metas, steps, t0, t1)
  M.reset()
  recording = false
  t_start = t0
  t_end   = t1
  for i = 1, #metas do
    local m = metas[i]
    order[i] = {
      name = m.name, id = m.id, group = m.grp, desc = m.desc or "",
      uptime_ms = m.uptime_ms or 0, max_conc = m.max_conc or 1,
      only_self = m.only_self or false, vetoed = m.vetoed or false,
      unique_units = m.unique_units or 0, applications = m.applications or 0,
      conc_avg = m.conc_avg or 0, longest_gap_ms = m.longest_gap_ms or 0,
      n_steps = 0, step_t = {}, step_c = {},
      n_iv = 0, iv_t0 = {}, iv_t1 = {},
      held = {}, gained_at = {}, ended = {}, per_unit = {}, units_ever = {}, ids = { m.id }, index = { [m.id] = 1 },
    }
    n_tracked = i
    Verdant.BuffOrigin.note(m.id, m.name)
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
  log:info("session loaded: buffs=", n_tracked, "steps=", #steps)
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

function M.snapshot()
  local abilities = {}
  for i = 1, n_tracked do
    local rec = order[i]
    abilities[i] = {
      id = rec.id, name = rec.name, group = rec.group, applications = rec.applications,
      unique_units = rec.unique_units, max_conc = rec.max_conc,
      intervals = rec.n_iv, uptime_ms = rec.uptime_ms,
    }
  end
  return { tracked = n_tracked, recording = recording,
           t_start = t_start, t_end = t_end, abilities = abilities }
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
      "%-28s up=%5.1f%%  apps=%d  units=%d  conc_max=%d  conc_avg=%.1f  ivs=%d  gap=%.1fs  grp=%s  desc=%s  self=%s  ids=%s",
      rec.name or tostring(rec.id), pct, rec.applications, rec.unique_units,
      rec.max_conc, M.avg_concurrency(rec), rec.n_iv, rec.longest_gap_ms / 1000,
      rec.group, (rec.desc ~= "") and "y" or "n",
      rec.only_self and "y" or "n",
      table.concat(rec.ids, "/", 1, rec.n_ids))
  end
  if n_tracked == 0 then lines[#lines + 1] = "(no buffs tracked this session)" end
  if n_excluded > 0 then
    lines[#lines + 1] = string.format("excluded as non-buffs (%d):", n_excluded)
    for name, e in pairs(excluded) do
      lines[#lines + 1] = string.format("  %-28s %s  (id=%d effectType=%d abilityType=%d)",
        name, e.why, e.id, e.et, e.at)
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
