Verdant = Verdant or {}
local Verdant = Verdant

Verdant.SessionStore = {}
local M = Verdant.SessionStore

local math_floor = math.floor
local table_remove = table.remove
local table_sort = table.sort

local CAP = 24

local DESC = {
  series = {
    { name = "t",       width = 4, delta = true },
    { name = "eHPS",    width = 4, scale = 10 },
    { name = "MPS",     width = 4, scale = 10 },
    { name = "crit",    width = 4, scale = 10 },
    { name = "noncrit", width = 4, scale = 10 },
    { name = "d",       width = 4, scale = 10 },
    { name = "o",       width = 4, scale = 10 },
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
  markers = {
    { name = "t",     width = 4 },
    { name = "death", width = 1 },
    { name = "who",   width = 1 },
  },
  shares = {
    { name = "si",  width = 2 },
    { name = "ch",  width = 1 },
    { name = "key", width = 1 },
    { name = "sh",  width = 3, scale = 10000 },
  },
  abilities = {
    { name = "si", width = 2 },
    { name = "ch", width = 1 },
    { name = "id", width = 4 },
    { name = "sh", width = 2, scale = 1000 },
  },
  sums = {
    { name = "ch", width = 1 },
    { name = "id", width = 4 },
    { name = "v",  width = 6 },
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
  restores = {
    { name = "si", width = 2 },
    { name = "rm", width = 4, scale = 10 },
    { name = "rs", width = 4, scale = 10 },
  },
  rsums = {
    { name = "ch", width = 1 },
    { name = "id", width = 4 },
    { name = "v",  width = 6 },
  },
  rlog = {
    { name = "t",   width = 4, delta = true },
    { name = "id",  width = 4 },
    { name = "ch",  width = 1 },
    { name = "who", width = 1 },
    { name = "v",   width = 4 },
  },
  casts = {
    { name = "t",    width = 4 },
    { name = "id",   width = 4 },
    { name = "pool", width = 1 },
    { name = "cost", width = 3 },
    { name = "tick", width = 1 },
  },
  regained = {
    { name = "t",    width = 4 },
    { name = "id",   width = 4 },
    { name = "pool", width = 1 },
    { name = "amt",  width = 3 },
  },
}

M.DESC = DESC

local log
local api
local start_zone  = ""
local start_group = 0
local start_diff  = 0

local start_kind = nil

function M.on_session_start()
  start_zone  = api.GetUnitZone("player") or ""
  start_group = api.GetGroupSize() or 0
  start_diff  = api.GetCurrentZoneDungeonDifficulty and api.GetCurrentZoneDungeonDifficulty() or 0
  start_kind  = Verdant.ContentKind and Verdant.ContentKind.detect() or nil
end

local function lib_root()
  local sv = Verdant.SavedVars
  if not sv then return nil end
  sv.library = sv.library or { version = 1, sessions = {} }
  sv.library.sessions = sv.library.sessions or {}
  return sv.library
end

local YIELD_EVERY = 40

local function by_kind_then_id(a, b)
  if a.ch ~= b.ch then return a.ch < b.ch end
  return a.id < b.id
end

local function sum_records(heal_by, shield_by)
  local recs = {}
  for id, v in pairs(heal_by) do
    recs[#recs + 1] = { ch = 0, id = id, v = v }
  end
  for id, v in pairs(shield_by) do
    recs[#recs + 1] = { ch = 1, id = id, v = v }
  end
  table_sort(recs, by_kind_then_id)
  return recs
end

function M.capture(cooperative)
  local ye = cooperative and YIELD_EVERY or nil
  local coroutine_yield = coroutine.yield
  local TB = Verdant.TemporalBuffer
  local BT = Verdant.BuffTracker
  local vsf = Verdant.lib.vsf

  if TB.count() == 0 then return nil end
  local t0 = BT.session_start()
  local t_end = BT.session_end()
  local tb_sum = TB.summary()
  local oh_hot, oh_direct = Verdant.Metrics.overheal_split()
  local heal_by, shield_by = TB.ability_sums()

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
        si = si, ch = ch, key = key_of(e.key or "other"), sh = e.share or 0,
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
        si = si, ch = ch, id = e.id or 0, sh = e.share or 0,
      }
    end
  end
  local restore_recs = {}
  local n_series = TB.count()
  for i = 1, n_series do
    local s = TB.at(i)
    if s.rm > 0 or s.rs > 0 then
      restore_recs[#restore_recs + 1] = { si = i, rm = s.rm, rs = s.rs }
    end
    harvest(i, 0, s.ehps_groups)
    harvest(i, 1, s.mps_groups)
    harvest_abilities(i, 0, s.ehps_abilities)
    harvest_abilities(i, 1, s.mps_abilities)
    if ye and i % ye == 0 then coroutine_yield() end
  end
  local function series_get(r, name)
    local s = TB.at(r)
    if name == "t" then return s.t - t0 end
    if name == "o" then return s.o or 0 end
    return s[name]
  end

  local buffs_meta = {}
  local steps = {}
  local n_buffs = BT.count()
  if n_buffs > 64 then n_buffs = 64 end
  for i = 1, n_buffs do
    local rec = BT.get(i)
    buffs_meta[i] = {
      name = rec.name, id = rec.id, grp = rec.group,
      desc = rec.desc, uptime_ms = rec.uptime_ms,
      max_conc = rec.max_conc, only_self = rec.only_self or false,
      vetoed = rec.vetoed or false,
      unique_units = rec.unique_units or 0,
      applications = rec.applications or 0,
      conc_avg = rec.conc_avg or 0,
      longest_gap_ms = rec.longest_gap_ms or 0,
    }
    for k = 1, rec.n_steps do
      steps[#steps + 1] = {
        b = i - 1,
        t = rec.step_t[k] - t0,
        c = rec.step_c[k],
      }
    end
  end

  local ust, usv, usn = Verdant.Ultimate.steps()
  local ult_recs = {}
  for i = 1, usn do
    local v = math_floor(usv[i] + 0.5)
    if v < 0 then v = 0 end
    if v > 65535 then v = 65535 end
    ult_recs[i] = { t = ust[i] - t0, v = v }
  end
  local uut, uub, uun = Verdant.Ultimate.used()
  local ultu_recs = {}
  for i = 1, uun do
    ultu_recs[i] = { t = uut[i] - t0, bar = uub[i] or 1 }
  end
  local uat, uab, uai, uac, uan = Verdant.Ultimate.abilities()
  local ulta_recs = {}
  for i = 1, uan do
    local rel = uat[i] - t0
    if rel < 0 then rel = 0 end
    local cost = uac[i] or 0
    if cost > 65535 then cost = 65535 end
    ulta_recs[i] = { t = rel, bar = uab[i] or 1, id = uai[i], cost = cost }
  end

  local ms, mn = TB.markers()
  local mk_recs = {}
  for i = 1, mn do
    local m = ms[i]
    local who = 0
    if m.who then
      who = tonumber(tostring(m.who):match("group(%d+)")) or 0
    end
    mk_recs[i] = { t = m.t - t0, death = m.death and 1 or 0, who = who }
  end

  local rmag, rsta = TB.restore_totals()
  local rmag_by, rsta_by = TB.restore_sums()
  local rl = TB.restore_log()
  local rlog_recs, rnames = {}, {}
  for i = 1, rl.n do
    local rel = rl.t[i] - t0
    if rel < 0 then rel = 0 end
    rlog_recs[i] = { t = rel, id = rl.id[i], ch = rl.mag[i] and 0 or 1, who = rl.who[i], v = rl.amt[i] }
  end
  for i = 1, #rl.names do rnames[i] = rl.names[i] end
  local ctt, cti, ctp, ctc, ctn, ctk = Verdant.Casts.records()
  local cast_recs = {}
  for i = Verdant.Casts.first(), ctn do
    local rel = ctt[i] - t0
    if rel < 0 then rel = 0 end
    local cost = ctc[i] or 0
    if cost > 65535 then cost = 65535 end
    cast_recs[#cast_recs + 1] = { t = rel, id = cti[i] or 0, pool = ctp[i] or 0, cost = cost, tick = ctk[i] or 0 }
  end
  local rtt, rti, rtp, rta, rtn = Verdant.Restores.records()
  local regained_recs = {}
  for i = Verdant.Restores.first(), rtn do
    local rel = rtt[i] - t0
    if rel < 0 then rel = 0 end
    local amt = rta[i] or 0
    if amt > 65535 then amt = 65535 end
    regained_recs[#regained_recs + 1] = { t = rel, id = rti[i] or 0, pool = rtp[i] or 0, amt = amt }
  end
  local head = M.recording_head()
  local session = {
    v = 1,
    head = {
      ts = head.ts,
      zone = head.zone,
      boss = head.boss,
      dur_ms = head.dur_ms,
      group_size = head.group_size,
      build = head.build,
      api = api.GetAPIVersion(),
      locked = false,
      difficulty = start_diff or 0,
      kind = start_kind,
      sum = {
        avg = math_floor(tb_sum.avg_ems + 0.5),
        peak = math_floor(tb_sum.peak_ems + 0.5),
        crit_pct = tb_sum.crit_pct,
        active_pct = tb_sum.active_pct,
        whole = { avg = tb_sum.avg_ems, peak = tb_sum.peak_ems, peak_at = tb_sum.peak_t_off },
        total_heal = tb_sum.total_heal,
        total_shield = tb_sum.total_shield,
        total_overheal = tb_sum.total_overheal,
        oh_hot = oh_hot, oh_direct = oh_direct,
        total_rmag = rmag, total_rsta = rsta,
      },
      cfg = { sample_rate_ms = TB.period(), window_ms = Verdant.Constants.METRICS.WINDOW_MS },
      regen = { mag = Verdant.Restores.regen(1), sta = Verdant.Restores.regen(2) },
    },
    buffs = buffs_meta,
    rnames = rnames,
    gkeys = gkeys,
    desc = DESC,
    streams = {
      series    = vsf.pack(series_get, DESC.series, n_series, ye),
      steps     = vsf.pack(steps, DESC.steps, nil, ye),
      markers   = vsf.pack(mk_recs, DESC.markers, nil, ye),
      shares    = vsf.pack(share_recs, DESC.shares, nil, ye),
      abilities = vsf.pack(ability_recs, DESC.abilities, nil, ye),
      sums      = heal_by and vsf.pack(sum_records(heal_by, shield_by), DESC.sums, nil, ye) or nil,
      ult       = vsf.pack(ult_recs, DESC.ult, nil, ye),
      ultu      = vsf.pack(ultu_recs, DESC.ultu, nil, ye),
      ulta      = vsf.pack(ulta_recs, DESC.ulta, nil, ye),
      restores  = vsf.pack(restore_recs, DESC.restores, nil, ye),
      rsums     = vsf.pack(sum_records(rmag_by, rsta_by), DESC.rsums, nil, ye),
      rlog      = vsf.pack(rlog_recs, DESC.rlog, nil, ye),
      casts     = vsf.pack(cast_recs, DESC.casts, nil, ye),
      regained  = vsf.pack(regained_recs, DESC.regained, nil, ye),
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
  Verdant.Diagnostics.bump("library.session_stored")
  return true
end

local autosave_co = nil
local autosave_frames = 0
local manual_pending = false

local function autosave_finish(session)
  Verdant.zenimax.events.unregister_update("VerdantAutosave")
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
  if Verdant.Hitch then Verdant.Hitch.mark("stop") end
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
  Verdant.zenimax.events.register_update("VerdantAutosave", 1, autosave_step)
  if M.on_save_begin then M.on_save_begin() end
end

function M.has_work()
  local heal, shield, overheal = Verdant.Metrics.totals()
  if (heal or 0) + (shield or 0) + (overheal or 0) > 0 then return true end
  local mag, sta = Verdant.TemporalBuffer.restore_totals()
  if (mag or 0) + (sta or 0) > 0 then return true end
  return Verdant.BuffTracker.count() > 0
end

function M.on_session_stop()
  local sv = Verdant.SavedVars
  if not (sv and sv.settings and sv.settings.session_autosave) then return end
  if not M.has_work() then
    Verdant.Diagnostics.bump("library.skipped_empty")
    if M.on_skipped then M.on_skipped() end
    return
  end
  manual_pending = false
  begin_capture()
end

function M.save_now()
  if Verdant.TemporalBuffer.count() == 0 or not M.has_work() then return false end
  begin_capture()
  manual_pending = true
  return true
end

function M.autosave_pending()
  return autosave_co ~= nil
end

function M.finish_autosave()
  local guard = 0
  while autosave_co and guard < 10000 do
    autosave_step()
    guard = guard + 1
  end
end

function M.recording_zone()
  return (start_zone ~= "") and start_zone or (api.GetUnitZone("player") or "")
end

function M.title(head)
  return head.label or head.boss or head.zone or "?"
end

function M.recording_head()
  local BT = Verdant.BuffTracker
  return {
    ts = api.GetTimeStamp(),
    zone = M.recording_zone(),
    boss = Verdant.AutoRecord.session_boss(),
    dur_ms = BT.session_end() - BT.session_start(),
    group_size = math.max(start_group, api.GetGroupSize() or 0),
    build = Verdant.Constants.VERSION,
  }
end

function M.set_label(idx, text)
  local lib = lib_root()
  local s = lib and lib.sessions[idx]
  if not s or not s.head then return false end
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then s.head.label = nil else s.head.label = text end
  return true
end

function M.decode(sess)
  if not (sess and sess.streams and sess.desc and sess.head) then
    return nil, "missing structure"
  end
  local vsf = Verdant.lib.vsf
  local series, e1 = vsf.unpack(sess.streams.series,   sess.desc.series)
  local steps,  e2 = vsf.unpack(sess.streams.steps,    sess.desc.steps)
  local mks,    e3 = vsf.unpack(sess.streams.markers,  sess.desc.markers)
  if not (series and steps and mks) then
    return nil, tostring(e1 or e2 or e3)
  end

  if sess.streams.shares and sess.desc.shares then
    local shares = vsf.unpack(sess.streams.shares, sess.desc.shares)
    if shares then
      local gkeys = sess.gkeys or {}
      local SC = Verdant.SkillColors
      for i = 1, #shares do
        local r = shares[i]
        local sample = series[r.si]
        if sample then
          local field = (r.ch == 0) and "eg" or "mg"
          local tbl = sample[field]
          if not tbl then tbl = { count = 0 }; sample[field] = tbl end
          local key = gkeys[r.key + 1] or "other"
          local c = SC.group_color(key)
          tbl.count = tbl.count + 1
          tbl[tbl.count] = {
            r = c.r, g = c.g, b = c.b, a = c.a,
            share = r.sh, key = key,
          }
        end
      end
    end
  end

  if sess.streams.abilities and sess.desc.abilities then
    local abilities = vsf.unpack(sess.streams.abilities, sess.desc.abilities)
    if abilities then
      local SC = Verdant.SkillColors
      for i = 1, #abilities do
        local r = abilities[i]
        local sample = series[r.si]
        if sample then
          local field = (r.ch == 0) and "ea" or "ma"
          local tbl = sample[field]
          if not tbl then tbl = { count = 0 }; sample[field] = tbl end
          local key = SC.ability_group(r.id)
          local c = SC.group_color(key)
          tbl.count = tbl.count + 1
          tbl[tbl.count] = {
            id = r.id, share = r.sh, key = key,
            r = c.r, g = c.g, b = c.b, a = c.a,
          }
        end
      end
    end
  end

  if sess.streams.restores and sess.desc.restores then
    local recs = vsf.unpack(sess.streams.restores, sess.desc.restores)
    for i = 1, (recs and #recs or 0) do
      local r = recs[i]
      local sample = series[r.si]
      if sample then sample.rm, sample.rs = r.rm, r.rs end
    end
  end
  local restores
  local head_sum = sess.head.sum
  if head_sum and head_sum.total_rmag ~= nil then
    restores = { mag = head_sum.total_rmag, sta = head_sum.total_rsta or 0, mag_by = {}, sta_by = {} }
    local recs = sess.streams.rsums and sess.desc.rsums and vsf.unpack(sess.streams.rsums, sess.desc.rsums)
    for i = 1, (recs and #recs or 0) do
      local r = recs[i]
      local into = (r.ch == 0) and restores.mag_by or restores.sta_by
      into[r.id] = (into[r.id] or 0) + r.v
    end
    restores.log = sess.streams.rlog and sess.desc.rlog and vsf.unpack(sess.streams.rlog, sess.desc.rlog) or nil
    restores.names = sess.rnames
  end

  local markers = {}
  for i = 1, #mks do
    local m = mks[i]
    markers[i] = {
      t = m.t, death = m.death == 1,
      who = (m.who > 0) and ("group" .. m.who) or nil,
    }
  end
  local saved_sum = sess.head.sum
  local saved_totals = (saved_sum and saved_sum.total_heal ~= nil) and {
    heal = saved_sum.total_heal, shield = saved_sum.total_shield or 0, overheal = saved_sum.total_overheal or 0,
  } or nil
  local sums
  if sess.streams.sums and sess.desc.sums then
    local recs = vsf.unpack(sess.streams.sums, sess.desc.sums)
    if recs then
      sums = { heal = {}, shield = {} }
      for i = 1, #recs do
        local r = recs[i]
        local into = (r.ch == 0) and sums.heal or sums.shield
        into[r.id] = (into[r.id] or 0) + r.v
      end
    end
  end
  local whole
  if saved_sum and saved_sum.whole then
    whole = {
      avg = saved_sum.whole.avg or 0, peak = saved_sum.whole.peak or 0, peak_at = saved_sum.whole.peak_at or 0,
      crit_pct = saved_sum.crit_pct or 0, active_pct = saved_sum.active_pct or 0,
    }
  end
  local ult
  if sess.streams.ult and sess.desc.ult then
    local ult_steps = vsf.unpack(sess.streams.ult, sess.desc.ult)
    local ult_used  = (sess.streams.ultu and sess.desc.ultu)
                      and vsf.unpack(sess.streams.ultu, sess.desc.ultu) or nil
    local ult_abil  = (sess.streams.ulta and sess.desc.ulta)
                      and vsf.unpack(sess.streams.ulta, sess.desc.ulta) or nil
    ult = { steps = ult_steps or {}, used = ult_used or {}, abilities = ult_abil or {} }
  end
  local casts = (sess.streams.casts and sess.desc.casts) and vsf.unpack(sess.streams.casts, sess.desc.casts) or nil
  local regained = (sess.streams.regained and sess.desc.regained) and vsf.unpack(sess.streams.regained, sess.desc.regained) or nil
  return {
    series = series, steps = steps, markers = markers, totals = saved_totals, ult = ult,
    sums = sums, whole = whole, restores = restores, casts = casts, regained = regained,
  }
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

function M.autosave_on()
  local sv = Verdant.SavedVars
  return sv ~= nil and sv.settings ~= nil and sv.settings.session_autosave == true
end

function M.set_autosave(on)
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.settings = sv.settings or {}
  sv.settings.session_autosave = on and true or false
end

function M.report_lines()
  local lib = lib_root()
  local lines = {}
  local sv = Verdant.SavedVars
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
      "  [%d] %s  %ds  grp=%d  avg=%d peak=%d%s",
      i, h.zone, math_floor(h.dur_ms / 1000), h.group_size,
      h.sum.avg, h.sum.peak,
      h.locked and "  LOCKED" or "")
  end
  return lines
end

function M.init()
  log = Verdant.Log.for_module("session_store")
  api = Verdant.zenimax.api
end
