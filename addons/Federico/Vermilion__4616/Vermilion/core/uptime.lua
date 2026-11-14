Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Uptime = {}
local M = Vermilion.Uptime

local log = Vermilion.Log.for_module("uptime")

local KEY_CAP   = 48
local OPEN_CAP  = 128
local SPAN_CAP  = 4096
local PRESS_CAP = 4096
local LAST_CAP  = 256
local ECHO_MS   = 150
local MIN_DUR_MS = 1000
local STALE_MS  = 1500
local GAP_LOOK_MS = 60000
local E_LIMIT   = 30000

M.KIND_FRESH, M.KIND_REFRESH, M.KIND_REPLACE, M.KIND_GAP = 1, 2, 3, 4

local recording = false
local t_start = 0

local key_of = {}
local key_name = {}
local key_slot = {}
local key_id = {}
local nk = 0

local o_key, o_unit, o_t0, o_end, o_press, o_id = {}, {}, {}, {}, {}, {}
local on = 0

local s_key, s_unit, s_t0, s_t1 = {}, {}, {}, {}
local sn = 0

local p_key, p_unit, p_t, p_e, p_kind = {}, {}, {}, {}, {}
local pn = 0

local l_key, l_unit, l_t = {}, {}, {}
local ln, l_head = 0, 0

local slotted_names = {}

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function is_enemy_tag(tag)
  if tag == nil or tag == "" then return true end
  if tag == "player" then return false end
  if tag:sub(1, 5) == "group" then return false end
  if tag:sub(1, 9) == "playerpet" or tag:sub(1, 9) == "companion" then return false end
  return true
end

local function scan_slotted()
  for k in pairs(slotted_names) do slotted_names[k] = nil end
  local api = Vermilion.zenimax.api
  local zc  = Vermilion.zenimax.constants
  if not api.GetSlotBoundId then return end
  for _, cat in ipairs({ zc.HOTBAR_CATEGORY_PRIMARY, zc.HOTBAR_CATEGORY_BACKUP }) do
    for slot = 3, 8 do
      local id = api.GetSlotBoundId(slot, cat)
      if id and id > 0 then
        local name = api.GetAbilityName(id)
        if name and name ~= "" then slotted_names[name] = id end
      end
    end
  end
end

local friend_uid = {}

local function drop_open(unit)
  local i = on
  while i >= 1 do
    if o_unit[i] == unit then
      o_key[i], o_unit[i], o_t0[i], o_end[i], o_press[i], o_id[i] = o_key[on], o_unit[on], o_t0[on], o_end[on], o_press[on], o_id[on]
      on = on - 1
    end
    i = i - 1
  end
end

local function key_for(name, abilityId)
  local k = key_of[name]
  if k then return k end
  if nk >= KEY_CAP then bump("uptime.keys_full") return nil end
  nk = nk + 1
  key_of[name] = nk
  key_name[nk] = name
  key_slot[nk] = slotted_names[name] ~= nil
  key_id[nk] = slotted_names[name] or abilityId or 0
  return nk
end

local function find_open(k, unit)
  for i = 1, on do
    if o_key[i] == k and o_unit[i] == unit then return i end
  end
  return nil
end

local function last_close(k, unit)
  for i = 1, ln do
    if l_key[i] == k and l_unit[i] == unit then return l_t[i] end
  end
  return nil
end

local function remember_close(k, unit, t)
  for i = 1, ln do
    if l_key[i] == k and l_unit[i] == unit then l_t[i] = t return end
  end
  if ln < LAST_CAP then
    ln = ln + 1
    l_key[ln], l_unit[ln], l_t[ln] = k, unit, t
  else
    l_head = (l_head % LAST_CAP) + 1
    l_key[l_head], l_unit[l_head], l_t[l_head] = k, unit, t
  end
end

local function press(k, unit, t, e, kind)
  if pn >= PRESS_CAP then bump("uptime.press_full") return end
  if e > E_LIMIT then e = E_LIMIT elseif e < -E_LIMIT then e = -E_LIMIT end
  pn = pn + 1
  p_key[pn], p_unit[pn], p_t[pn], p_e[pn], p_kind[pn] = k, unit, t, e, kind
end

local function close_slot(i, t)
  if sn < SPAN_CAP then
    sn = sn + 1
    s_key[sn], s_unit[sn], s_t0[sn], s_t1[sn] = o_key[i], o_unit[i], o_t0[i], t
  else
    bump("uptime.spans_full")
  end
  remember_close(o_key[i], o_unit[i], t)
  o_key[i], o_unit[i], o_t0[i], o_end[i], o_press[i], o_id[i] = o_key[on], o_unit[on], o_t0[on], o_end[on], o_press[on], o_id[on]
  on = on - 1
end

local function open_slot(k, unit, t, end_ms, id)
  if on >= OPEN_CAP then bump("uptime.open_full") return end
  on = on + 1
  o_key[on], o_unit[on], o_t0[on], o_end[on], o_press[on], o_id[on] = k, unit, t, end_ms, t, id
end

function M.on_effect(changeType, abilityId, unitId, beginTime, endTime, now_ms, unitTag, effectType, name)
  if not recording then return end
  if not unitId or unitId == 0 then bump("uptime.no_unit") return end
  if not is_enemy_tag(unitTag) then
    if not friend_uid[unitId] then
      friend_uid[unitId] = true
      drop_open(unitId)
    end
    return
  end
  if friend_uid[unitId] then bump("uptime.on_friend") return end
  local zc = Vermilion.zenimax.constants
  if changeType == zc.EFFECT_RESULT_FADED then
    local k = name and key_of[name]
    if not k then return end
    local i = find_open(k, unitId)
    if i and abilityId ~= o_id[i] and o_end[i] > now_ms then
      bump("uptime.fade_other_id")
      return
    end
    if i then close_slot(i, now_ms); bump("uptime.faded") end
    return
  end
  if changeType ~= zc.EFFECT_RESULT_GAINED and changeType ~= zc.EFFECT_RESULT_UPDATED then return end
  if not name or name == "" then return end
  local end_ms = (endTime or 0) * 1000
  local dur = end_ms - (beginTime or 0) * 1000
  if changeType == zc.EFFECT_RESULT_GAINED and dur < MIN_DUR_MS then
    local k = key_of[name]
    if not k then bump("uptime.short") return end
  end
  if changeType == zc.EFFECT_RESULT_UPDATED and not key_of[name] and end_ms - now_ms < MIN_DUR_MS then
    bump("uptime.short")
    return
  end
  local k = key_for(name, abilityId)
  if not k then return end
  local i = find_open(k, unitId)
  if i and abilityId ~= o_id[i] then
    if end_ms > o_end[i] then o_end[i], o_id[i] = end_ms, abilityId end
    bump("uptime.other_id")
    return
  end
  if changeType == zc.EFFECT_RESULT_UPDATED then
    if not i then
      if end_ms <= now_ms then
        bump("uptime.empty_update")
        return
      end
      open_slot(k, unitId, now_ms, end_ms, abilityId)
      press(k, unitId, now_ms, 0, M.KIND_FRESH)
      bump("uptime.update_without_gain")
      return
    end
    if now_ms - o_press[i] < ECHO_MS then
      o_end[i] = end_ms
      bump("uptime.echo")
      return
    end
    press(k, unitId, now_ms, o_end[i] - now_ms, M.KIND_REFRESH)
    o_end[i], o_press[i] = end_ms, now_ms
    bump("uptime.refreshed")
    return
  end
  if i and now_ms - o_press[i] < ECHO_MS then
    o_end[i] = end_ms
    bump("uptime.echo")
    return
  end
  if i then
    press(k, unitId, now_ms, o_end[i] - now_ms, M.KIND_REPLACE)
    close_slot(i, now_ms)
    bump("uptime.replaced")
  else
    local lc = last_close(k, unitId)
    if lc and now_ms - lc <= GAP_LOOK_MS then
      press(k, unitId, now_ms, lc - now_ms, M.KIND_GAP)
      bump("uptime.after_gap")
    else
      press(k, unitId, now_ms, 0, M.KIND_FRESH)
      bump("uptime.fresh")
    end
  end
  open_slot(k, unitId, now_ms, end_ms, abilityId)
end

function M.on_unit_dead(unitId, now_ms)
  if not recording or not unitId then return end
  local i = on
  while i >= 1 do
    if o_unit[i] == unitId then close_slot(i, now_ms) end
    i = i - 1
  end
end

function M.expire_stale(now_ms)
  if not recording then return end
  local i = on
  while i >= 1 do
    if o_end[i] > 0 and now_ms > o_end[i] + STALE_MS then
      close_slot(i, o_end[i])
      bump("uptime.stale_closed")
    end
    i = i - 1
  end
end

local function wipe()
  for k in pairs(key_of) do key_of[k] = nil end
  for k in pairs(friend_uid) do friend_uid[k] = nil end
  nk, on, sn, pn, ln, l_head = 0, 0, 0, 0, 0, 0
end

function M.start_session(now_ms)
  wipe()
  scan_slotted()
  recording = true
  t_start = now_ms or Vermilion.zenimax.api.GetGameTimeMilliseconds()
end

function M.finalize(now_ms)
  if not recording then return end
  local t = now_ms or Vermilion.zenimax.api.GetGameTimeMilliseconds()
  while on > 0 do close_slot(on, t) end
  recording = false
  log:info("session finalize: keys=", nk, "spans=", sn, "presses=", pn)
end

function M.reset()
  recording = false
  wipe()
end

function M.is_recording() return recording end
function M.keys() return key_name, key_slot, nk, key_id end
function M.spans() return s_key, s_unit, s_t0, s_t1, sn end
function M.open_spans() return o_key, o_unit, o_t0, o_end, on end
function M.presses() return p_key, p_unit, p_t, p_e, p_kind, pn end
function M.key_of(name) return key_of[name] end

function M.load_session(span_recs, press_recs, meta)
  M.reset()
  meta = meta or {}
  local names, slots, ids = meta.names or {}, meta.slotted or {}, meta.ids or {}
  for i = 1, #names do
    nk = nk + 1
    key_name[nk], key_slot[nk], key_id[nk] = names[i], slots[i] == true or slots[i] == 1, ids[i] or 0
    key_of[names[i]] = nk
  end
  span_recs = span_recs or {}
  for i = 1, #span_recs do
    local r = span_recs[i]
    s_key[i], s_unit[i], s_t0[i], s_t1[i] = r.key or 0, r.unit or 0, r.t0 or 0, r.t1 or 0
  end
  sn = #span_recs
  press_recs = press_recs or {}
  for i = 1, #press_recs do
    local r = press_recs[i]
    p_key[i], p_unit[i], p_t[i], p_e[i], p_kind[i] = r.key or 0, r.unit or 0, r.t or 0, (r.e or E_LIMIT) - E_LIMIT, r.kind or 1
  end
  pn = #press_recs
  log:info("session loaded: keys=", nk, "spans=", sn, "presses=", pn)
end

function M.E_LIMIT() return E_LIMIT end

function M.report_lines()
  local lines = { string.format("uptime: recording=%s keys=%d open=%d spans=%d presses=%d", tostring(recording), nk, on, sn, pn) }
  for k = 1, nk do
    local spans, presses, early, late = 0, 0, 0, 0
    for i = 1, sn do if s_key[i] == k then spans = spans + 1 end end
    for i = 1, pn do
      if p_key[i] == k then
        presses = presses + 1
        if p_e[i] > 500 then early = early + 1 elseif p_e[i] < -500 then late = late + 1 end
      end
    end
    lines[#lines + 1] = string.format("  %-26s %s spans=%d presses=%d early=%d late=%d", key_name[k], key_slot[k] and "skill" or "other", spans, presses, early, late)
  end
  return lines
end
