Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.SessionStore = {}
local M = Vermilion.SessionStore

local math_floor = math.floor
local table_remove = table.remove

local CAP = 100

local DESC = {
  spans = {
    { name = "t0",   width = 4 },
    { name = "t1",   width = 4 },
    { name = "key",  width = 1 },
    { name = "unit", width = 4 },
  },
  press = {
    { name = "t",    width = 4 },
    { name = "key",  width = 1 },
    { name = "unit", width = 4 },
    { name = "e",    width = 3 },
    { name = "kind", width = 1 },
  },
  series = {
    { name = "t",       width = 4, delta = true },
    { name = "eDPS",    width = 4, scale = 10 },
    { name = "ShDPS",   width = 4, scale = 10 },
    { name = "crit",    width = 4, scale = 10 },
    { name = "noncrit", width = 4, scale = 10 },
    { name = "mag",     width = 2, scale = 1000 },
    { name = "sta",     width = 2, scale = 1000 },
    { name = "mag_in",  width = 3 },
    { name = "mag_out", width = 3 },
    { name = "sta_in",  width = 3 },
    { name = "sta_out", width = 3 },
  },
  steps = {
    { name = "b", width = 1 },
    { name = "t", width = 4 },
    { name = "c", width = 1 },
  },
  shares = {
    { name = "si",  width = 2 },
    { name = "ch",  width = 1 },
    { name = "key", width = 1 },
    { name = "sh",  width = 3, scale = 10000 },
  },
  abilities = {
    { name = "si",  width = 2 },
    { name = "ch",  width = 1 },
    { name = "id",  width = 4 },
    { name = "key", width = 1 },
    { name = "sh",  width = 2, scale = 1000 },
    { name = "ab",  width = 2, scale = 1000 },
  },
  targets = {
    { name = "si",  width = 2 },
    { name = "id",  width = 4 },
    { name = "key", width = 2 },
    { name = "tt",  width = 1 },
    { name = "sh",  width = 2, scale = 1000 },
    { name = "ab",  width = 2, scale = 1000 },
  },
  kills = {
    { name = "t",   width = 4 },
    { name = "id",  width = 4 },
    { name = "key", width = 2 },
    { name = "aid", width = 4 },
  },
  ult = {
    { name = "t", width = 4 },
    { name = "v", width = 2 },
  },
  ultu = {
    { name = "t",   width = 4 },
    { name = "bar", width = 1 },
  },
  ulta = {
    { name = "t",    width = 4 },
    { name = "bar",  width = 1 },
    { name = "id",   width = 4 },
    { name = "cost", width = 2 },
  },
  casts = {
    { name = "t",    width = 4 },
    { name = "id",   width = 4 },
    { name = "pool", width = 1 },
    { name = "cost", width = 3 },
    { name = "tick", width = 1 },
  },
  restores = {
    { name = "t",    width = 4 },
    { name = "id",   width = 4 },
    { name = "pool", width = 1 },
    { name = "amt",  width = 3 },
  },
  deaths = {
    { name = "t", width = 4 },
    { name = "e", width = 4 },
  },
}

M.DESC = DESC
M.CH_SKILL  = 0
M.CH_DTYPE  = 1
M.CH_SHIELD = 2

local log
local api
local start_zone  = ""
local start_group = 0
local start_diff  = 0
local start_kind  = nil
local start_ms    = nil
local end_ms      = nil
local start_class = nil
local start_bars  = nil

function M.on_session_start()
  start_zone  = api.GetUnitZone("player") or ""
  start_group = api.GetGroupSize() or 0
  start_diff  = api.GetCurrentZoneDungeonDifficulty and api.GetCurrentZoneDungeonDifficulty() or 0
  start_kind  = Vermilion.ContentKind and Vermilion.ContentKind.detect() or nil
  start_ms    = api.GetGameTimeMilliseconds()
  end_ms      = nil
  local zc = Vermilion.zenimax.constants
  start_class = api.GetUnitClass and api.GetUnitClass("player") or nil
  start_bars  = { Vermilion.Casts.bar_ids(zc.HOTBAR_CATEGORY_PRIMARY), Vermilion.Casts.bar_ids(zc.HOTBAR_CATEGORY_BACKUP) }
end

function M.session_start() return start_ms end

local function session_zero(first_t)
  local t0 = start_ms or first_t
  if first_t < t0 then t0 = first_t end
  local opened = Vermilion.Metrics.fight_bounds()
  if opened and opened < t0 then t0 = opened end
  return t0
end
function M.start_meta() return start_zone, start_group end
function M.live_build() return start_class, start_bars end

local function lib_root()
  local sv = Vermilion.SavedVars
  if not sv then return nil end
  sv.library = sv.library or { version = 1, sessions = {} }
  sv.library.sessions = sv.library.sessions or {}
  return sv.library
end

local YIELD_EVERY = 40

local function plain_name(raw)
  return (raw:gsub("%^.*$", ""))
end

local function fight_names(exact)
  local bosses = {}
  for name in pairs(Vermilion.AutoRecord.session_bosses()) do bosses[plain_name(name)] = true end
  local player = Vermilion.zenimax.constants.COMBAT_UNIT_TYPE_OTHER
  local by_name = {}
  for id, amount in pairs(exact.targets) do
    local raw = exact.target_names[id]
    if raw and raw ~= "" and exact.target_types[id] ~= player then
      local name = plain_name(raw)
      by_name[name] = (by_name[name] or 0) + amount
    end
  end
  local boss, boss_v, top, top_v = nil, 0, nil, 0
  for name, amount in pairs(by_name) do
    if amount > top_v then top, top_v = name, amount end
    if bosses[name] and amount > boss_v then boss, boss_v = name, amount end
  end
  return boss, top
end

function M.live_names()
  local ex = Vermilion.Metrics.exact()
  if not (ex and ex.targets) then return nil, nil end
  return fight_names(ex)
end

function M.title(head)
  return head.label or head.boss or head.top or head.zone or "?"
end

function M.capture(cooperative)
  local ye = cooperative and YIELD_EVERY or nil
  local coroutine_yield = coroutine.yield
  local TB = Vermilion.TemporalBuffer
  local vsf = Vermilion.lib.vsf

  local n_series = TB.count()
  if n_series == 0 then return nil end
  local first_t = TB.at(1).t
  local t0 = session_zero(first_t)
  local t_end = end_ms or api.GetGameTimeMilliseconds()
  local last_t = TB.at(n_series).t
  if t_end < last_t then t_end = last_t end

  local share_recs = {}
  local gkeys = {}
  local gkey_idx = {}
  local function key_of(k)
    local idx = gkey_idx[k]
    if not idx then
      gkeys[#gkeys + 1] = k
      idx = #gkeys - 1
      gkey_idx[k] = idx
    end
    return idx
  end
  local function harvest(si, ch, groups)
    if si > 4095 then return end
    local n = (groups and groups.count) or 0
    for g = 1, n do
      local e = groups[g]
      share_recs[#share_recs + 1] = {
        si = si, ch = ch, key = key_of(e.key == nil and "other" or e.key), sh = e.share or 0,
      }
    end
  end
  local ability_recs = {}
  local function harvest_abilities(si, ch, abilities)
    if si > 4095 then return end
    local n = (abilities and abilities.count) or 0
    for a = 1, n do
      local e = abilities[a]
      ability_recs[#ability_recs + 1] = {
        si = si, ch = ch, id = e.id or 0, key = key_of(e.key == nil and "other" or e.key), sh = e.share or 0, ab = e.abs or 0,
      }
    end
  end

  local target_recs = {}
  local function harvest_targets(si, targets)
    if si > 4095 then return end
    local n = (targets and targets.count) or 0
    for a = 1, n do
      local e = targets[a]
      target_recs[#target_recs + 1] = {
        si = si, id = e.id or 0, key = key_of(e.name or ""), tt = e.ttype or 0, sh = e.share or 0, ab = e.abs or 0,
      }
    end
  end

  local sum_eos, peak_eos = 0, 0
  local sum_edps, peak_edps = 0, 0
  local sum_crit, sum_noncrit = 0, 0
  for i = 1, n_series do
    local s = TB.at(i)
    local eos = s.eDPS + s.ShDPS
    sum_eos = sum_eos + eos
    if eos > peak_eos then peak_eos = eos end
    sum_edps = sum_edps + s.eDPS
    if s.eDPS > peak_edps then peak_edps = s.eDPS end
    sum_crit = sum_crit + (s.crit or 0)
    sum_noncrit = sum_noncrit + (s.noncrit or 0)
    harvest(i, 0, s.eos_groups)
    harvest(i, 1, s.dtype_groups)
    harvest_abilities(i, 0, s.eos_abilities)
    harvest_abilities(i, 1, s.dtype_abilities)
    harvest_abilities(i, 2, s.shield_abilities)
    harvest_targets(i, s.targets)
    if ye and i % ye == 0 then coroutine_yield() end
  end
  local function series_get(r, name)
    local s = TB.at(r)
    if name == "t" then return s.t - t0 end
    return s[name] or 0
  end

  local DT = Vermilion.DebuffTracker
  local debuffs_meta = {}
  local steps = {}
  local n_debuffs = DT and DT.count() or 0
  if n_debuffs > 64 then n_debuffs = 64 end
  for i = 1, n_debuffs do
    local rec = DT.get(i)
    debuffs_meta[i] = {
      name = rec.name, id = rec.id, grp = rec.group, desc = rec.desc,
      uptime_ms = rec.uptime_ms, max_conc = rec.max_conc,
      unique_units = rec.unique_units or 0, applications = rec.applications or 0,
      conc_avg = DT.avg_concurrency(rec), longest_gap_ms = rec.longest_gap_ms or 0,
    }
    for k = 1, rec.n_steps do
      local rel = rec.step_t[k] - t0
      if rel < 0 then rel = 0 end
      steps[#steps + 1] = { b = i - 1, t = rel, c = rec.step_c[k] }
    end
  end

  local K = Vermilion.Kills
  local kill_recs = {}
  for i = 1, K.count() do
    local kt, kuid, kname, kaid = K.get(i)
    local rel = kt - t0
    if rel < 0 then rel = 0 end
    kill_recs[i] = { t = rel, id = kuid, key = key_of(kname or ""), aid = kaid }
  end

  local U = Vermilion.Ultimate
  local ust, usv, usn = U.steps()
  local ult_recs = {}
  for i = 1, usn do
    local v = math_floor(usv[i] + 0.5)
    if v < 0 then v = 0 end
    if v > 65535 then v = 65535 end
    local rel = ust[i] - t0
    if rel < 0 then rel = 0 end
    ult_recs[i] = { t = rel, v = v }
  end
  local uut, uub, uun = U.used()
  local ultu_recs = {}
  for i = 1, uun do
    local rel = uut[i] - t0
    if rel < 0 then rel = 0 end
    ultu_recs[i] = { t = rel, bar = uub[i] or 1 }
  end
  local uat, uab, uai, uac, uan = U.abilities()
  local ulta_recs = {}
  for i = 1, uan do
    local rel = uat[i] - t0
    if rel < 0 then rel = 0 end
    local cost = uac[i] or 0
    if cost > 65535 then cost = 65535 end
    ulta_recs[i] = { t = rel, bar = uab[i] or 1, id = uai[i], cost = cost }
  end
  local usk, usu, ust0, ust1, usn = Vermilion.Uptime.spans()
  local span_recs = {}
  for i = 1, usn do
    local a, b = ust0[i] - t0, ust1[i] - t0
    if a < 0 then a = 0 end
    if b < a then b = a end
    span_recs[i] = { t0 = a, t1 = b, key = usk[i] or 0, unit = usu[i] or 0 }
  end
  local upk, upu, upt, upe, upkind, upn = Vermilion.Uptime.presses()
  local press_recs = {}
  local E_LIMIT = Vermilion.Uptime.E_LIMIT()
  for i = 1, upn do
    local rel = upt[i] - t0
    if rel < 0 then rel = 0 end
    press_recs[i] = { t = rel, key = upk[i] or 0, unit = upu[i] or 0, e = (upe[i] or 0) + E_LIMIT, kind = upkind[i] or 1 }
  end
  local ukn, uks, uknn, uki = Vermilion.Uptime.keys()
  local uptime_meta = { names = {}, slotted = {}, ids = {} }
  for k = 1, uknn do uptime_meta.names[k] = ukn[k]; uptime_meta.slotted[k] = uks[k] and 1 or 0; uptime_meta.ids[k] = uki[k] or 0 end
  local ctt, cti, ctp, ctc, ctn, ctk = Vermilion.Casts.records()
  local cast_recs = {}
  for i = 1, ctn do
    local rel = ctt[i] - t0
    if rel < 0 then rel = 0 end
    local cost = ctc[i] or 0
    if cost > 65535 then cost = 65535 end
    cast_recs[i] = { t = rel, id = cti[i] or 0, pool = ctp[i] or 0, cost = cost, tick = ctk[i] or 0 }
  end
  local rtt, rti, rtp, rta, rtn = Vermilion.Restores.records()
  local restore_recs = {}
  for i = 1, rtn do
    local rel = rtt[i] - t0
    if rel < 0 then rel = 0 end
    local amt = rta[i] or 0
    if amt > 65535 then amt = 65535 end
    restore_recs[i] = { t = rel, id = rti[i] or 0, pool = rtp[i] or 0, amt = amt }
  end
  local dts, dn, dte = Vermilion.Resources.deaths()
  local death_recs = {}
  for i = 1, dn do
    local rel = dts[i] - t0
    if rel < 0 then rel = 0 end
    local back = (dte[i] > 0) and (dte[i] - t0) or (t_end - t0)
    if back < rel then back = rel end
    death_recs[i] = { t = rel, e = back }
  end

  local total_damage, total_shield, total_crit, hits, crit_hits, overkill = Vermilion.Metrics.totals()
  local C = Vermilion.Constants

  local exact = Vermilion.Metrics.exact_copy()
  local boss_name, top_name = fight_names(exact)
  local session = {
    v = 1,
    head = {
      boss = boss_name,
      top = top_name,
      ts = api.GetTimeStamp(),
      zone = (start_zone ~= "") and start_zone or (api.GetUnitZone("player") or ""),
      dur_ms = t_end - t0,
      group_size = math.max(start_group, api.GetGroupSize() or 0),
      build = C.VERSION,
      api = api.GetAPIVersion(),
      locked = false,
      difficulty = start_diff or 0,
      kind = start_kind,
      class = start_class,
      bars = start_bars,
      regen = { mag = Vermilion.Restores.regen(1), sta = Vermilion.Restores.regen(2) },
      uptime = uptime_meta,
      sum = {
        avg = math_floor(sum_eos / n_series + 0.5),
        peak = math_floor(peak_eos + 0.5),
        avg_edps = math_floor(sum_edps / n_series + 0.5),
        peak_edps = math_floor(peak_edps + 0.5),
        crit_pct = (total_damage > 0 and total_crit / total_damage) or ((sum_crit + sum_noncrit) > 0 and (sum_crit / (sum_crit + sum_noncrit))) or 0,
        total_damage = total_damage,
        total_shield = total_shield,
        total_crit = total_crit,
        hits = hits,
        crit_hits = crit_hits,
        overkill = overkill,
        exact = exact,
        fight_ms = Vermilion.Metrics.fight_ms(),
        fight_t0 = (function()
          local lo = Vermilion.Metrics.fight_bounds()
          return lo and math.max(0, lo - t0) or nil
        end)(),
      },
      cfg = {
        window_ms = math_floor(Vermilion.Metrics.window_seconds() * 1000 + 0.5),
        shield_window_ms = math_floor(Vermilion.Metrics.shield_window_seconds() * 1000 + 0.5),
        sample_rate_ms = Vermilion.TemporalBuffer.period(),
      },
    },
    gkeys = gkeys,
    debuffs = debuffs_meta,
    desc = DESC,
    streams = {
      series    = vsf.pack(series_get, DESC.series, n_series, ye),
      steps     = vsf.pack(steps, DESC.steps, nil, ye),
      shares    = vsf.pack(share_recs, DESC.shares, nil, ye),
      abilities = vsf.pack(ability_recs, DESC.abilities, nil, ye),
      targets   = vsf.pack(target_recs, DESC.targets, nil, ye),
      kills     = vsf.pack(kill_recs, DESC.kills, nil, ye),
      ult       = vsf.pack(ult_recs, DESC.ult, nil, ye),
      ultu      = vsf.pack(ultu_recs, DESC.ultu, nil, ye),
      ulta      = vsf.pack(ulta_recs, DESC.ulta, nil, ye),
      casts     = vsf.pack(cast_recs, DESC.casts, nil, ye),
      spans     = vsf.pack(span_recs, DESC.spans, nil, ye),
      press     = vsf.pack(press_recs, DESC.press, nil, ye),
      restores  = vsf.pack(restore_recs, DESC.restores, nil, ye),
      deaths    = vsf.pack(death_recs, DESC.deaths, nil, ye),
    },
  }
  return session
end

function M.store(session)
  local lib = lib_root()
  if not lib then return false end
  local sessions = lib.sessions
  sessions[#sessions + 1] = session
  local i = 1
  while #sessions > CAP and i <= #sessions do
    if not (sessions[i].head and sessions[i].head.locked) then
      table_remove(sessions, i)
    else
      i = i + 1
    end
  end
  Vermilion.Diagnostics.bump("library.session_stored")
  return true
end

local autosave_co = nil
local autosave_frames = 0
local manual_pending = false

local function autosave_finish(session)
  Vermilion.zenimax.events.unregister_update("VermilionAutosave")
  autosave_co = nil
  if M.on_save_end then M.on_save_end(session ~= nil) end
  if session then
    if manual_pending then session.head.manual = true end
    manual_pending = false
    M.store(session)
    if log then
      log:info("session autosaved: zone=", session.head.zone,
               "dur=", session.head.dur_ms, "ms", "frames=", autosave_frames)
    end
    if M.on_saved then M.on_saved(session) end
  end
end

local function autosave_step()
  if not autosave_co then return end
  Vermilion.Hitch.mark("save")
  autosave_frames = autosave_frames + 1
  local ok, res = coroutine.resume(autosave_co)
  if not ok then
    if log then log:warn("autosave failed:", tostring(res)) end
    autosave_finish(nil)
    return
  end
  if coroutine.status(autosave_co) == "dead" then
    autosave_finish(res)
  end
end

local function begin_capture()
  M.finish_autosave()
  autosave_frames = 0
  autosave_co = coroutine.create(function() return M.capture(true) end)
  Vermilion.zenimax.events.register_update("VermilionAutosave", 1, autosave_step)
  if M.on_save_begin then M.on_save_begin() end
end

function M.on_session_stop()
  end_ms = api.GetGameTimeMilliseconds()
  local sv = Vermilion.SavedVars
  if not (sv and sv.settings and sv.settings.session_autosave) then return end
  local damage, shield = Vermilion.Metrics.totals()
  if damage + shield <= 0 then
    d("[Vm] " .. GetString(VERMILION_LIB_SKIPPED))
    return
  end
  manual_pending = false
  begin_capture()
end

function M.save_now()
  if Vermilion.TemporalBuffer.count() == 0 then return false end
  local damage, shield = Vermilion.Metrics.totals()
  if damage + shield <= 0 then return false end
  begin_capture()
  manual_pending = true
  return true
end

function M.live_duration()
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if n == 0 then return 0 end
  local first_t, last_t = TB.at(1).t, TB.at(n).t
  local t0 = session_zero(first_t)
  local t_end = end_ms or api.GetGameTimeMilliseconds()
  if t_end < last_t then t_end = last_t end
  return t_end - t0
end

function M.autosave_pending()
  return autosave_co ~= nil
end

local function attach_shares(series, sess, vsf)
  local gkeys = sess.gkeys or {}
  local SC = Vermilion.SkillColors
  local DTC = Vermilion.DamageTypeColors
  local shares = sess.streams.shares and sess.desc.shares and vsf.unpack(sess.streams.shares, sess.desc.shares)
  for i = 1, (shares and #shares or 0) do
    local r = shares[i]
    local sample = series[r.si]
    if sample then
      local key = gkeys[r.key + 1]
      local field = (r.ch == 0) and "eg" or "dg"
      local tbl = sample[field]
      if not tbl then tbl = { count = 0 }; sample[field] = tbl end
      local c = (r.ch == 0) and SC.group_color(key or "other") or DTC.lookup(key or 0)
      tbl.count = tbl.count + 1
      tbl[tbl.count] = { r = c.r, g = c.g, b = c.b, a = c.a, share = r.sh, key = (r.ch == 0) and (key or "other") or (key or 0) }
    end
  end
  local abilities = sess.streams.abilities and sess.desc.abilities and vsf.unpack(sess.streams.abilities, sess.desc.abilities)
  for i = 1, (abilities and #abilities or 0) do
    local r = abilities[i]
    local sample = series[r.si]
    if sample then
      local field = (r.ch == 0) and "ea" or ((r.ch == 2) and "sa" or "da")
      local tbl = sample[field]
      if not tbl then tbl = { count = 0 }; sample[field] = tbl end
      local key = (r.key ~= nil) and gkeys[r.key + 1] or nil
      local c
      if r.ch == 0 then
        if not key or key == "other" then
          local now_group = SC.group_of(r.id)
          key = key or now_group
        end
        c = SC.group_color(key)
      elseif r.ch == 2 then
        key = "shield"
        c = SC.group_color(key)
      else
        key = key or 0
        c = DTC.lookup(key)
      end
      tbl.count = tbl.count + 1
      tbl[tbl.count] = { id = r.id, share = r.sh, abs = r.ab or 0, key = key, r = c.r, g = c.g, b = c.b, a = c.a }
    end
  end
  local targets = sess.streams.targets and sess.desc.targets and vsf.unpack(sess.streams.targets, sess.desc.targets)
  for i = 1, (targets and #targets or 0) do
    local r = targets[i]
    local sample = series[r.si]
    if sample then
      local tbl = sample.tg
      if not tbl then tbl = { count = 0 }; sample.tg = tbl end
      tbl.count = tbl.count + 1
      tbl[tbl.count] = { id = r.id, name = gkeys[r.key + 1] or "", ttype = r.tt or 0, share = r.sh, abs = r.ab or 0 }
    end
  end
end

function M.decode(sess)
  if not (sess and sess.streams and sess.desc and sess.head) then return nil, "missing structure" end
  local vsf = Vermilion.lib.vsf
  local series, err = vsf.unpack(sess.streams.series, sess.desc.series)
  if not series then return nil, err end
  attach_shares(series, sess, vsf)
  local function stream(name)
    if sess.streams[name] and sess.desc[name] then return vsf.unpack(sess.streams[name], sess.desc[name]) or {} end
    return nil
  end
  local dec = { series = series }
  dec.steps = (sess.streams.steps and sess.desc.steps) and vsf.unpack(sess.streams.steps, sess.desc.steps) or nil
  dec.ult = stream("ult")
  if dec.ult then
    dec.ultu = (sess.streams.ultu and sess.desc.ultu) and vsf.unpack(sess.streams.ultu, sess.desc.ultu) or nil
    dec.ulta = (sess.streams.ulta and sess.desc.ulta) and vsf.unpack(sess.streams.ulta, sess.desc.ulta) or nil
  end
  dec.casts = stream("casts")
  dec.spans = stream("spans")
  if dec.spans then
    dec.press = (sess.streams.press and sess.desc.press) and vsf.unpack(sess.streams.press, sess.desc.press) or nil
  end
  dec.restores = stream("restores")
  dec.deaths = stream("deaths")
  dec.kills = stream("kills")
  if dec.kills then
    local gk = sess.gkeys or {}
    for i = 1, #dec.kills do dec.kills[i].name = gk[(dec.kills[i].key or 0) + 1] or "" end
  end
  return dec
end

function M.finish_autosave()
  local guard = 0
  while autosave_co and guard < 10000 do
    autosave_step()
    guard = guard + 1
  end
end

function M.set_label(idx, text)
  local lib = lib_root()
  local s = lib and lib.sessions[idx]
  if not s or not s.head then return false end
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then s.head.label = nil else s.head.label = text end
  return true
end

function M.count()
  local lib = lib_root()
  return lib and #lib.sessions or 0
end

function M.cap() return CAP end

function M.get(i)
  local lib = lib_root()
  return lib and lib.sessions[i] or nil
end

function M.delete(i)
  local lib = lib_root()
  if lib and lib.sessions[i] then
    table_remove(lib.sessions, i)
    return true
  end
  return false
end

function M.set_locked(i, locked)
  local s = M.get(i)
  if s and s.head then
    s.head.locked = locked and true or false
    return true
  end
  return false
end

local function session_bytes(s)
  local total = 0
  for _, st in pairs(s.streams or {}) do
    for _, c in ipairs(st.data or {}) do total = total + #c end
  end
  return total
end

function M.report_lines()
  local lib = lib_root()
  local lines = {}
  local sv = Vermilion.SavedVars
  local auto = sv and sv.settings and sv.settings.session_autosave and "ON" or "off"
  local n = lib and #lib.sessions or 0
  local total = 0
  local locked = 0
  for i = 1, n do
    total = total + session_bytes(lib.sessions[i])
    if lib.sessions[i].head and lib.sessions[i].head.locked then locked = locked + 1 end
  end
  lines[#lines + 1] = string.format(
    "sessions=%d/%d (locked=%d)  packed=%.1f KB  autosave=%s",
    n, CAP, locked, total / 1024, auto)
  for i = math.max(1, n - 4), n do
    local h = lib.sessions[i].head
    lines[#lines + 1] = string.format(
      "  [%d] %s  %ds  grp=%d  avg=%d peak=%d  dmg=%d%s",
      i, h.zone, math_floor(h.dur_ms / 1000), h.group_size,
      h.sum.avg, h.sum.peak, h.sum.total_damage or 0,
      h.locked and "  LOCKED" or "")
  end
  return lines
end

function M.init()
  log = Vermilion.Log.for_module("session_store")
  api = Vermilion.zenimax.api
end
