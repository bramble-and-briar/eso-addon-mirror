Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ExportReport = {}
local M = Verdant.ExportReport

local api = Verdant.zenimax.api
local GetString = api.GetString
local math_floor = math.floor
local string_format = string.format
local table_concat = table.concat
local table_sort = table.sort

local TIMELINE_BIN_MS = 5000
local TIMELINE_MAX_ROWS = 360

local function clean(name)
  local s = tostring(name)
  s = s:gsub("%^%a+$", ""):gsub("|", ""):gsub(";", ",")
  return s
end

local function int(v) return string_format("%d", math_floor(v + 0.5)) end
local function pct(v) return string_format("%.1f", v * 100) end
local function secs(ms) return string_format("%.1f", ms / 1000) end
local function share(v, total) return (total > 0) and pct(v / total) or "0.0" end

local function section(title, header, lines)
  if #lines == 0 then return "" end
  local out = { "", "## " .. title }
  if header then out[#out + 1] = header end
  for i = 1, #lines do out[#out + 1] = lines[i] end
  return table_concat(out, "\n")
end

local function header_section()
  local head = Verdant.Graph.fight_head()
  local s = Verdant.TemporalBuffer.summary()
  local lines = { string_format(GetString(VERDANT_EXPORT_HEAD), head.build or Verdant.Constants.VERSION) }
  local name = Verdant.SessionStore.title(head)
  if name ~= head.zone and name ~= "?" then
    lines[#lines + 1] = string_format(GetString(VERDANT_EXPORT_FIGHT_NAME), clean(name))
  end
  lines[#lines + 1] = string_format(GetString(VERDANT_EXPORT_META), clean(head.zone), api.GetDateStringFromTimestamp(head.ts),
    secs(head.dur_ms), math.max(head.group_size or 0, 1))
  lines[#lines + 1] = GetString(s.totals_from == "integral" and VERDANT_EXPORT_NOTE_OLD or VERDANT_EXPORT_NOTE)
  return table_concat(lines, "\n")
end

local function summary_section()
  local s = Verdant.TemporalBuffer.summary()
  local lines = {
    GetString(VERDANT_EXPORT_TOTAL_HEAL) .. ";" .. int(s.total_heal),
    GetString(VERDANT_EXPORT_TOTAL_SHIELD) .. ";" .. int(s.total_shield),
    GetString(VERDANT_EXPORT_SHIELD_SHARE) .. ";" .. share(s.total_shield, s.total_heal + s.total_shield),
    GetString(VERDANT_EXPORT_TOTAL_OVERHEAL) .. ";" .. int(s.total_overheal),
    GetString(VERDANT_EXPORT_OVERHEAL) .. ";" .. pct(s.wasted_pct),
    GetString(VERDANT_EXPORT_TIME) .. ";" .. secs(s.dur_ms),
    GetString(VERDANT_EXPORT_AVG) .. ";" .. int(s.avg_ems),
    GetString(VERDANT_EXPORT_PEAK) .. ";" .. int(s.peak_ems),
    GetString(VERDANT_EXPORT_PEAK_AT) .. ";" .. secs(s.peak_t_off),
    GetString(VERDANT_EXPORT_CRIT) .. ";" .. pct(s.crit_pct),
    GetString(VERDANT_EXPORT_ACTIVE) .. ";" .. pct(s.active_pct),
  }
  local TB = Verdant.TemporalBuffer
  local dead = Verdant.FightStats.dead(TB)
  local alive = Verdant.FightStats.alive_average(s.avg_ems, dead)
  if alive then
    lines[#lines + 1] = GetString(VERDANT_EXPORT_AVG_ALIVE) .. ";" .. int(alive)
    lines[#lines + 1] = GetString(VERDANT_EXPORT_DEAD) .. ";" .. secs(dead.ms)
    lines[#lines + 1] = GetString(VERDANT_EXPORT_DEATHS) .. ";" .. int(dead.count)
  end
  local spread = Verdant.FightStats.compute(TB)
  if spread.n > 0 then
    lines[#lines + 1] = GetString(VERDANT_EXPORT_P90) .. ";" .. int(spread.p90)
    lines[#lines + 1] = GetString(VERDANT_EXPORT_MEDIAN) .. ";" .. int(spread.p50)
    lines[#lines + 1] = GetString(VERDANT_EXPORT_P10) .. ";" .. int(spread.p10)
  end
  return section(GetString(VERDANT_EXPORT_SEC_SUMMARY), nil, lines)
end

local function skills_section()
  local CV = Verdant.ContribView
  local order, n, totals = CV.compute()
  local total = totals.heal + totals.shield
  local kinds = { [CV.KIND_HEAL] = GetString(VERDANT_EXPORT_KIND_HEAL), [CV.KIND_SHIELD] = GetString(VERDANT_EXPORT_KIND_SHIELD) }
  local lines = {}
  for i = 1, n do
    local r = order[i]
    lines[i] = table_concat({ i, r.top_id or 0, clean(r.name), kinds[r.ch], int(r.v), share(r.v, total) }, ";")
  end
  if n > 0 then lines[n + 1] = GetString(VERDANT_EXPORT_SKILLS_SUM) .. ";" .. int(total) end
  return section(GetString(VERDANT_EXPORT_SEC_SKILLS), GetString(VERDANT_EXPORT_COL_SKILLS), lines)
end

local function origin_of(r)
  local SC = Verdant.SkillColors
  local g = SC.user_group(r.id) or r.group
  if g and g ~= "other" then return SC.group_label(g) end
  return Verdant.BuffOrigin.label(r.id, r.name) or ""
end

local function buffs_section()
  local BT = Verdant.BuffTracker
  local span = BT.session_end() - BT.session_start()
  local lines = {}
  for i = 1, BT.count() do
    local r = BT.get(i)
    lines[i] = table_concat({ r.id, clean(r.name), clean(origin_of(r)), share(r.uptime_ms, span), r.applications,
      r.unique_units, r.max_conc, secs(r.longest_gap_ms) }, ";")
  end
  return section(GetString(VERDANT_EXPORT_SEC_BUFFS), GetString(VERDANT_EXPORT_COL_BUFFS), lines)
end

local function ultimate_section()
  local U = Verdant.Ultimate
  if not U.has_data() then return "" end
  local us = U.summary()
  local lines = {
    GetString(VERDANT_EXPORT_ULT_READY) .. ";" .. pct(us.ready_pct),
    GetString(VERDANT_EXPORT_ULT_CASTS) .. ";" .. us.casts,
  }
  if us.casts > 1 then
    lines[#lines + 1] = GetString(VERDANT_EXPORT_ULT_GAP) .. ";" .. secs(us.mean_gap_ms)
  end
  return section(GetString(VERDANT_EXPORT_SEC_ULT), nil, lines)
end

local function by_total(a, b)
  if a.total ~= b.total then return a.total > b.total end
  return a.name < b.name
end

local function rows_of(map)
  local list = {}
  for _, row in pairs(map) do
    row.total = row.mag + row.sta
    list[#list + 1] = row
  end
  table_sort(list, by_total)
  return list
end

local function sustain_section()
  local TB = Verdant.TemporalBuffer
  local mag, sta = TB.restore_totals()
  mag, sta = mag or 0, sta or 0
  local total = mag + sta
  if total <= 0 then return "" end
  local parts = { section(GetString(VERDANT_EXPORT_SEC_SUSTAIN), nil, {
    GetString(VERDANT_EXPORT_SUS_MAG) .. ";" .. int(mag),
    GetString(VERDANT_EXPORT_SUS_STA) .. ";" .. int(sta),
  }) }

  local SC = Verdant.SkillColors
  local by_ab = {}
  local mag_by, sta_by = TB.restore_sums()
  for pool, by in pairs({ mag = mag_by or {}, sta = sta_by or {} }) do
    for id, v in pairs(by) do
      if v > 0 then
        local name = clean(SC.ability_name(id))
        local row = by_ab[name]
        if not row then
          row = { name = name, mag = 0, sta = 0, ids = {} }
          by_ab[name] = row
        end
        row[pool] = row[pool] + v
        row.ids[#row.ids + 1] = id
      end
    end
  end
  local lines = {}
  for _, row in ipairs(rows_of(by_ab)) do
    table_sort(row.ids)
    lines[#lines + 1] = table_concat({ table_concat(row.ids, "/"), row.name, int(row.mag), int(row.sta), share(row.total, total) }, ";")
  end
  parts[#parts + 1] = section(GetString(VERDANT_EXPORT_SEC_SUS_AB), GetString(VERDANT_EXPORT_COL_SUS_AB), lines)

  local rl = TB.restore_log()
  if rl.n > 0 then
    local by_pl, given = {}, 0
    for i = 1, rl.n do
      local name = clean(rl.names[rl.who[i]] or "")
      local row = by_pl[name]
      if not row then
        row = { name = name, mag = 0, sta = 0 }
        by_pl[name] = row
      end
      if rl.mag[i] then row.mag = row.mag + rl.amt[i] else row.sta = row.sta + rl.amt[i] end
      given = given + rl.amt[i]
    end
    local pl = {}
    for _, row in ipairs(rows_of(by_pl)) do
      pl[#pl + 1] = table_concat({ row.name, int(row.mag), int(row.sta), share(row.total, given) }, ";")
    end
    if rl.n >= TB.RLOG_CAP then pl[#pl + 1] = string_format(GetString(VERDANT_EXPORT_SUS_PL_CUT), TB.RLOG_CAP) end
    parts[#parts + 1] = section(GetString(VERDANT_EXPORT_SEC_SUS_PL), GetString(VERDANT_EXPORT_COL_SUS_PL), pl)
  end
  return table_concat(parts, "\n")
end

local res_state

local function resources_section()
  local TB = Verdant.TemporalBuffer
  local sums = Verdant.Resources.summary(TB)
  if not sums.has then return "" end
  local RS = Verdant.ResourceSums
  res_state = res_state or RS.state()
  RS.aggregate(res_state, true, true, sums)
  local t = res_state.totals
  local o = res_state.order[RS.SPENT]
  local spent_m, spent_s = 0, 0
  for i = 1, o.n do spent_m, spent_s = spent_m + o[i].mag, spent_s + o[i].sta end
  local low = math_floor(Verdant.Resources.low() * 100 + 0.5)
  local parts = { section(GetString(VERDANT_EXPORT_SEC_RES), nil, {
    GetString(VERDANT_EXPORT_RES_SPENT_MAG) .. ";" .. int(spent_m),
    GetString(VERDANT_EXPORT_RES_SPENT_STA) .. ";" .. int(spent_s),
    GetString(VERDANT_EXPORT_RES_CASTS) .. ";" .. t.casts,
    GetString(VERDANT_EXPORT_RES_IN_MAG) .. ";" .. int(sums.mag_in),
    GetString(VERDANT_EXPORT_RES_IN_STA) .. ";" .. int(sums.sta_in),
    GetString(VERDANT_EXPORT_RES_RESTORED) .. ";" .. int(t.energized),
    string_format(GetString(VERDANT_EXPORT_RES_LOW_MAG), low) .. ";" .. pct(sums.mag_low_pct),
    string_format(GetString(VERDANT_EXPORT_RES_LOW_STA), low) .. ";" .. pct(sums.sta_low_pct),
  }) }

  local SC = Verdant.SkillColors
  local spent = {}
  for i = 1, o.n do
    local r = o[i]
    local per = (r.total > 0 and r.con > 0) and string_format("%.2f", r.con / r.total) or ""
    spent[i] = table_concat({ r.id, clean(SC.ability_name(r.id)), r.n, int(r.mag), int(r.sta), share(r.total, t.spend),
      int(r.con), per }, ";")
  end
  parts[#parts + 1] = section(GetString(VERDANT_EXPORT_SEC_RES_SPENT), GetString(VERDANT_EXPORT_COL_RES_SPENT), spent)

  local rec, q = {}, res_state.order[RS.REC]
  for i = 1, q.n do
    local r = q[i]
    local name = (r.id > 0) and clean(SC.ability_name(r.id)) or GetString(VERDANT_RESH_RECOVERY)
    rec[i] = table_concat({ r.id, name, int(r.mag), int(r.sta), share(r.total, t.regained) }, ";")
  end
  parts[#parts + 1] = section(GetString(VERDANT_EXPORT_SEC_RES_REC), GetString(VERDANT_EXPORT_COL_RES_REC), rec)
  return table_concat(parts, "\n")
end

local function timeline_section()
  local TB = Verdant.TemporalBuffer
  local n = TB.count()
  local t0 = TB.at(1).t
  local span = TB.at(n).t - t0
  local bin_ms = TIMELINE_BIN_MS * (math_floor(span / (TIMELINE_BIN_MS * TIMELINE_MAX_ROWS)) + 1)
  local lines = {}
  local bin, c, heal, shield, over, crit, noncrit, hurt = 0, 0, 0, 0, 0, 0, 0, 0
  local function flush()
    lines[#lines + 1] = table_concat({ secs(bin * bin_ms), int(heal / c), int(shield / c), int(over / c),
      share(crit, crit + noncrit), int(hurt / c) }, ";")
  end
  for i = 1, n do
    local s = TB.at(i)
    local b = math_floor((s.t - t0) / bin_ms)
    if b ~= bin then
      flush()
      bin, c, heal, shield, over, crit, noncrit, hurt = b, 0, 0, 0, 0, 0, 0, 0
    end
    c = c + 1
    heal, shield, over = heal + s.eHPS, shield + s.MPS, over + s.o
    crit, noncrit, hurt = crit + s.crit, noncrit + s.noncrit, hurt + s.d
  end
  flush()
  return section(string_format(GetString(VERDANT_EXPORT_SEC_TIMELINE), bin_ms / 1000), GetString(VERDANT_EXPORT_COL_TIMELINE), lines)
end

M.SECTIONS = { header_section, summary_section, skills_section, buffs_section, ultimate_section, sustain_section, resources_section, timeline_section }

function M.paginate(text, limit)
  local pages = {}
  local cur, size = {}, 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if size + #line + 1 > limit and #cur > 0 then
      pages[#pages + 1] = table_concat(cur, "\n")
      cur, size = {}, 0
    end
    cur[#cur + 1] = line
    size = size + #line + 1
  end
  if #cur > 0 then pages[#pages + 1] = table_concat(cur, "\n") end
  local total = #pages
  if total > 1 then
    for i = 1, total do
      pages[i] = string_format(GetString(VERDANT_EXPORT_PART_LINE), i, total) .. "\n" .. pages[i]
    end
  end
  return pages
end
