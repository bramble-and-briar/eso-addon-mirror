Vermilion = Vermilion or {}
Vermilion.ExportReport = {}
local M = Vermilion.ExportReport

local api = Vermilion.zenimax.api
local GetString = api.GetString
local math_floor = math.floor
local string_format = string.format
local table_concat = table.concat

local TIMELINE_BIN_MS = 5000
local TIMELINE_MAX_ROWS = 360

local function clean(name)
  local s = tostring(name or "")
  s = s:gsub("%^%a+$", ""):gsub("|", ""):gsub(";", ",")
  return s
end

local function int(v) return string_format("%d", math_floor((v or 0) + 0.5)) end
local function pct(v) return string_format("%.1f", (v or 0) * 100) end
local function secs(ms) return string_format("%.1f", (ms or 0) / 1000) end
local function share(v, total) return (total and total > 0) and pct(v / total) or "0.0" end

local function section(title, header, lines)
  if #lines == 0 then return "" end
  local out = { "", "## " .. title }
  if header then out[#out + 1] = header end
  for i = 1, #lines do out[#out + 1] = lines[i] end
  return table_concat(out, "\n")
end

local function film()
  local TB = Vermilion.TemporalBuffer
  local first = TB.at(1).t
  local start = 0
  if not Vermilion.Metrics.is_loaded() then
    start = Vermilion.SessionStore.session_start() or first
    if first < start then start = first end
  end
  local lead = first - start
  return first, TB.at(TB.count()).t - first, (lead > 2 * TB.period()) and lead or 0
end

local function header_section()
  local G = Vermilion.Graph
  local head = G.export_head()
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  local dur = head.dur_ms or (TB.at(n).t - TB.at(1).t)
  local date = api.GetDateStringFromTimestamp and head.ts and api.GetDateStringFromTimestamp(head.ts) or "?"
  local rate = head.cfg and head.cfg.sample_rate_ms or TB.period()
  local lines = { string_format(GetString(VERMILION_EXPORT_HEAD), head.build or Vermilion.Constants.VERSION) }
  local title = Vermilion.SessionStore.title(head)
  if title ~= head.zone and title ~= "?" then
    lines[#lines + 1] = string_format(GetString(VERMILION_EXPORT_FIGHT_NAME), clean(title))
  end
  lines[#lines + 1] = string_format(GetString(VERMILION_EXPORT_META), clean(head.zone), date, secs(dur), math.max(head.group_size or 0, 1),
    (rate % 1000 == 0) and string_format("%d", rate / 1000) or string_format("%.1f", rate / 1000))
  local _, span, lead = film()
  if lead > 0 then
    lines[#lines + 1] = string_format(GetString(VERMILION_EXPORT_FILM), secs(span), secs(lead))
  end
  lines[#lines + 1] = GetString(Vermilion.Metrics.exact() and VERMILION_EXPORT_NOTE or VERMILION_EXPORT_NOTE_OLD)
  return table_concat(lines, "\n")
end

local function summary_section()
  local sm = Vermilion.Graph.export_summary()
  local total = sm.total_damage + sm.total_shield
  local lines = {
    GetString(VERMILION_EXPORT_TOTAL_DAMAGE) .. ";" .. int(sm.total_damage),
    GetString(VERMILION_EXPORT_TOTAL_SHIELD) .. ";" .. int(sm.total_shield),
    GetString(VERMILION_EXPORT_SHIELD_SHARE) .. ";" .. share(sm.total_shield, total),
    GetString(VERMILION_EXPORT_FIGHT) .. ";" .. secs(sm.fight_ms),
    GetString(VERMILION_EXPORT_AVG) .. ";" .. int(sm.avg),
    GetString(VERMILION_EXPORT_PEAK) .. ";" .. int(sm.peak),
    GetString(VERMILION_EXPORT_PEAK_AT) .. ";" .. secs(sm.peak_t_off),
    GetString(VERMILION_EXPORT_CRIT_RATE) .. ";" .. (sm.crit_hits and share(sm.crit_hits, sm.hits) or "?"),
    GetString(VERMILION_EXPORT_CRIT) .. ";" .. pct(sm.crit_pct),
    GetString(VERMILION_EXPORT_HITS) .. ";" .. int(sm.hits),
  }
  if sm.alive_avg then
    lines[#lines + 1] = GetString(VERMILION_EXPORT_AVG_ALIVE) .. ";" .. int(sm.alive_avg)
    lines[#lines + 1] = GetString(VERMILION_EXPORT_DEAD) .. ";" .. secs(sm.dead_ms)
    lines[#lines + 1] = GetString(VERMILION_EXPORT_DEATHS) .. ";" .. int(sm.deaths)
  end
  local st = Vermilion.FightStats.compute(Vermilion.TemporalBuffer)
  if st.n > 0 then
    lines[#lines + 1] = GetString(VERMILION_EXPORT_P90) .. ";" .. int(st.p90)
    lines[#lines + 1] = GetString(VERMILION_EXPORT_MEDIAN) .. ";" .. int(st.p50)
    lines[#lines + 1] = GetString(VERMILION_EXPORT_P10) .. ";" .. int(st.p10)
  end
  if sm.overkill then
    lines[#lines + 1] = GetString(VERMILION_EXPORT_OVERKILL) .. ";" .. int(sm.overkill)
  end
  if sm.hits > 0 then
    lines[#lines + 1] = GetString(VERMILION_EXPORT_AVG_HIT) .. ";" .. int(sm.total_damage / sm.hits)
  end
  if sm.dom_type ~= nil and Vermilion.DamageTypeColors then
    lines[#lines + 1] = GetString(VERMILION_EXPORT_MAIN_TYPE) .. ";" .. clean(Vermilion.DamageTypeColors.name(sm.dom_type)) .. ";" .. pct(sm.dom_pct)
  end
  return section(GetString(VERMILION_EXPORT_SEC_SUMMARY), nil, lines)
end

local function build_section()
  local head = Vermilion.Graph.export_head()
  local bars = head.bars
  if not bars then return "" end
  local names = { GetString(VERMILION_EXPORT_BAR_FRONT), GetString(VERMILION_EXPORT_BAR_BACK) }
  local rows, any = {}, false
  for b = 1, 2 do
    local row = { names[b] }
    for i = 1, 6 do
      local id = bars[b] and bars[b][i] or 0
      row[i + 1] = (id > 0) and clean(Vermilion.SkillColors.ability_name(id)) or ""
      any = any or id > 0
    end
    rows[b] = table_concat(row, ";")
  end
  if not any then return "" end
  local lines = {}
  if head.class and head.class ~= "" then lines[1] = GetString(VERMILION_EXPORT_CLASS) .. ";" .. clean(head.class) end
  lines[#lines + 1] = GetString(VERMILION_EXPORT_COL_BARS)
  lines[#lines + 1] = rows[1]
  lines[#lines + 1] = rows[2]
  return section(GetString(VERMILION_EXPORT_SEC_BUILD), nil, lines)
end

local function skills_section()
  local order, n, totals = Vermilion.ContribView.compute()
  local total = totals.damage + totals.shield
  local lines = {}
  for i = 1, n do
    local r = order[i]
    lines[i] = table_concat({ i, clean(r.name), clean(r.type), int(r.v), share(r.v, total), int(r.abs) }, ";")
  end
  lines[#lines + 1] = GetString(VERMILION_EXPORT_SKILLS_SUM) .. ";" .. int(total)
  local TB = Vermilion.TemporalBuffer
  local lo = Vermilion.Metrics.fight_bounds()
  if not Vermilion.Metrics.exact() and lo and TB.count() > 0 and TB.at(1).t > lo + 2000 then
    lines[#lines + 1] = string_format(GetString(VERMILION_EXPORT_PARTIAL), secs(TB.at(TB.count()).t - TB.at(1).t))
  end
  return section(GetString(VERMILION_EXPORT_SEC_SKILLS), GetString(VERMILION_EXPORT_COL_SKILLS), lines)
end

local function targets_section()
  local TV = Vermilion.TargetsView
  local order, n, totals = TV.compute()
  local lines = {}
  for i = 1, n do
    local r = order[i]
    lines[i] = table_concat({ clean(r.name), r.n, int(r.total), share(r.total, totals.damage), int(r.abs) }, ";")
  end
  if n > 1 then
    local on_top, switches = TV.focus()
    lines[#lines + 1] = GetString(VERMILION_EXPORT_FOCUS) .. ";" .. pct(on_top)
    lines[#lines + 1] = GetString(VERMILION_EXPORT_SWITCHES) .. ";" .. switches
  end
  return section(GetString(VERMILION_EXPORT_SEC_TARGETS), GetString(VERMILION_EXPORT_COL_TARGETS), lines)
end

local function uptime_section()
  local UV = Vermilion.UptimeView
  local order, n, rows = UV.compute()
  local lines = {}
  for i = 1, n do
    local r = rows[order[i]]
    lines[i] = table_concat({ clean(r.name), pct(r.uptime), r.apps, secs(r.dur), secs(r.down), r.early, r.late, int(r.dps), UV.priced(r) and int(r.cost) or "" }, ";")
  end
  return section(GetString(VERMILION_EXPORT_SEC_UPTIME), GetString(VERMILION_EXPORT_COL_UPTIME), lines)
end

local function debuffs_section()
  local DT = Vermilion.DebuffTracker
  local lines = {}
  for i = 1, DT.count() do
    local r = DT.get(i)
    lines[i] = table_concat({ clean(r.name), pct(DT.uptime_of(r)), r.applications or 0, r.unique_units or 0, r.max_conc or 0, secs(r.longest_gap_ms) }, ";")
  end
  return section(GetString(VERMILION_EXPORT_SEC_DEBUFFS), GetString(VERMILION_EXPORT_COL_DEBUFFS), lines)
end

local function resources_section()
  local TB = Vermilion.TemporalBuffer
  local out = {}
  Vermilion.ResourcesView.with_all(function(spent, recovered, totals, dmg_total)
    local rs = Vermilion.Resources.summary(TB)
    if not rs.has then return end
    local lines = {
      GetString(VERMILION_EXPORT_RES_MAG) .. ";" .. int(rs.mag_in) .. ";" .. int(rs.mag_out) .. ";" .. string_format("%.2f", rs.mag_sigma) .. ";" .. pct(rs.mag_low_pct),
      GetString(VERMILION_EXPORT_RES_STA) .. ";" .. int(rs.sta_in) .. ";" .. int(rs.sta_out) .. ";" .. string_format("%.2f", rs.sta_sigma) .. ";" .. pct(rs.sta_low_pct),
      GetString(VERMILION_EXPORT_RES_EFF) .. ";" .. int(rs.eff),
    }
    out[#out + 1] = section(GetString(VERMILION_EXPORT_SEC_RESOURCES), GetString(VERMILION_EXPORT_COL_RESOURCES), lines)
    lines = {}
    for i = 1, spent.n do
      local r = spent[i]
      local per = (r.total > 0) and r.dmg / r.total or 0
      lines[i] = table_concat({ clean(r.name), r.n, int(r.mag), int(r.sta), share(r.total, totals.spend), int(r.dmg), share(r.dmg, dmg_total), string_format("%.1f", per) }, ";")
    end
    local table_mag, table_sta = 0, 0
    for i = 1, spent.n do
      table_mag, table_sta = table_mag + spent[i].mag, table_sta + spent[i].sta
    end
    local other_mag, other_sta = rs.mag_out - table_mag, rs.sta_out - table_sta
    if other_mag > 0 or other_sta > 0 then
      lines[#lines + 1] = table_concat({ GetString(VERMILION_EXPORT_SPENT_OTHER), "", int(math.max(other_mag, 0)), int(math.max(other_sta, 0)) }, ";")
    end
    out[#out + 1] = section(GetString(VERMILION_EXPORT_SEC_SPENT), GetString(VERMILION_EXPORT_COL_SPENT), lines)
    lines = {}
    for i = 1, recovered.n do
      local r = recovered[i]
      lines[i] = table_concat({ clean(r.name), int(r.mag), int(r.sta), share(r.total, totals.regained) }, ";")
    end
    out[#out + 1] = section(GetString(VERMILION_EXPORT_SEC_RECOVERED), GetString(VERMILION_EXPORT_COL_RECOVERED), lines)
    for i = #out, 1, -1 do
      if out[i] == "" then table.remove(out, i) end
    end
  end)
  return table_concat(out, "\n")
end

local function ultimate_section()
  local U = Vermilion.Ultimate
  if not U.has_data() then return "" end
  local us = U.summary()
  local lines = {
    GetString(VERMILION_EXPORT_ULT_READY) .. ";" .. pct(us.ready_pct),
    GetString(VERMILION_EXPORT_ULT_CASTS) .. ";" .. us.casts,
  }
  if us.casts > 1 then
    lines[#lines + 1] = GetString(VERMILION_EXPORT_ULT_GAP) .. ";" .. secs(us.mean_gap_ms)
  end
  return section(GetString(VERMILION_EXPORT_SEC_ULT), nil, lines)
end

local function kills_section()
  local K = Vermilion.Kills
  local n = K.count()
  if n == 0 then return "" end
  local t0, _, lead = film()
  local lines = {}
  for i = 1, n do
    local t, _, name, aid = K.get(i)
    local rel = t - t0
    if rel < 0 and lead == 0 then rel = 0 end
    lines[i] = table_concat({ secs(rel), clean(name), clean((aid and aid > 0) and Vermilion.SkillColors.ability_name(aid) or "") }, ";")
  end
  return section(GetString(VERMILION_EXPORT_SEC_KILLS), GetString(VERMILION_EXPORT_COL_KILLS), lines)
end

local function timeline_section()
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  local t0, span = film()
  local bin_ms = TIMELINE_BIN_MS * (math_floor(span / (TIMELINE_BIN_MS * TIMELINE_MAX_ROWS)) + 1)
  local lines = {}
  local bin, c, dps, shd, crit, noncrit, mag, sta = 0, 0, 0, 0, 0, 0, 0, 0
  local function flush()
    if c == 0 then return end
    local hits = crit + noncrit
    lines[#lines + 1] = table_concat({ secs(bin * bin_ms), int(dps / c), int(shd / c), share(crit, hits), pct(mag / c), pct(sta / c) }, ";")
  end
  for i = 1, n do
    local s = TB.at(i)
    local b = math_floor((s.t - t0) / bin_ms)
    if b ~= bin then
      flush()
      bin, c, dps, shd, crit, noncrit, mag, sta = b, 0, 0, 0, 0, 0, 0, 0
    end
    c = c + 1
    dps = dps + (s.eDPS or 0)
    shd = shd + (s.ShDPS or 0)
    crit = crit + (s.crit or 0)
    noncrit = noncrit + (s.noncrit or 0)
    mag = mag + (s.mag or 0)
    sta = sta + (s.sta or 0)
  end
  flush()
  return section(string_format(GetString(VERMILION_EXPORT_SEC_TIMELINE), bin_ms / 1000), GetString(VERMILION_EXPORT_COL_TIMELINE), lines)
end

M.SECTIONS = {
  header_section, summary_section, build_section, skills_section, targets_section, uptime_section,
  debuffs_section, resources_section, ultimate_section, kills_section, timeline_section,
}

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
      pages[i] = string_format(GetString(VERMILION_EXPORT_PART_LINE), i, total) .. "\n" .. pages[i]
    end
  end
  return pages
end
