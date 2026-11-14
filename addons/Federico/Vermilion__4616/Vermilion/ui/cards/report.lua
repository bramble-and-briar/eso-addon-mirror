Vermilion = Vermilion or {}
Vermilion.ReportCard = {}
local M = Vermilion.ReportCard

local GetString     = Vermilion.zenimax.api.GetString
local math_floor    = math.floor
local string_format = string.format

local HC = Vermilion.HoverCard
local clear_card_rows, position_card, size_card = HC.clear_rows, HC.place, HC.size
local fit_card_rows, swatch_solid = HC.fit_rows, HC.swatch_solid
local CARD_ROW_H, CARD_MAX_ROWS, CARD_ROWS_Y0 = HC.ROW_H, HC.MAX_ROWS, HC.ROWS_Y0
local C_CARD_STAT, C_CARD_NAME = HC.C_STAT, HC.C_NAME

local Format = Vermilion.Format
local fmt_val, fmt_secs, hexc = Format.val, Format.secs, Format.hex

local DamageTypeColors = Vermilion.DamageTypeColors

local controls, VIS, DTYPE_ICON, C_SUM
local C_LINE_EDPS, C_LINE_EOS, C_SHDPS, C_CRIT, C_CRIT_BELOW
local card_fader

function M.bind(t)
  controls, VIS, DTYPE_ICON, C_SUM = t.controls, t.VIS, t.DTYPE_ICON, t.C_SUM
  C_LINE_EDPS, C_LINE_EOS, C_SHDPS = t.C_LINE_EDPS, t.C_LINE_EOS, t.C_SHDPS
  C_CRIT, C_CRIT_BELOW = t.C_CRIT, t.C_CRIT_BELOW
end

function M.attach(fader) card_fader = fader end

local SUM = { count = 0 }
local DOM = {}

local function session_summary()
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  SUM.count = n
  local sum_eos, peak, peak_t, first_t = 0, 0, 0, 0
  local sum_crit, sum_noncrit = 0, 0
  for k in pairs(DOM) do DOM[k] = nil end
  for k in pairs(VIS.shd) do VIS.shd[k] = nil end
  local dom_total, prev_t = 0, nil
  for i = 1, n do
    local s = TB.at(i)
    local eos = s.eDPS + s.ShDPS
    sum_eos = sum_eos + eos
    if i == 1 then first_t = s.t end
    if prev_t then
      local dv = eos * (s.t - prev_t) / 1000
      local dg = s.dtype_groups
      for g = 1, (dg and dg.count or 0) do
        local e = dg[g]
        local key = e.key or 0
        local v = (e.share or 0) * dv
        DOM[key] = (DOM[key] or 0) + v
        dom_total = dom_total + v
      end
      local sa = s.shield_abilities
      local sv = s.ShDPS * (s.t - prev_t) / 1000
      for a = 1, (sa and sa.count or 0) do
        local e = sa[a]
        local id = e.id or 0
        VIS.shd[id] = (VIS.shd[id] or 0) + (e.share or 0) * sv
      end
    end
    prev_t = s.t
    if eos > peak then peak = eos; peak_t = s.t end
    sum_crit = sum_crit + (s.crit or 0)
    sum_noncrit = sum_noncrit + (s.noncrit or 0)
  end
  SUM.avg = (n > 0) and (sum_eos / n) or 0
  SUM.peak = peak
  SUM.peak_t_off = (peak > 0) and (peak_t - first_t) or 0
  SUM.crit_pct = (sum_crit + sum_noncrit) > 0 and (sum_crit / (sum_crit + sum_noncrit)) or 0
  SUM.dom_type, SUM.dom_pct = nil, 0
  local ex = Vermilion.Metrics.exact()
  if ex then
    for k in pairs(DOM) do DOM[k] = nil end
    for k in pairs(VIS.shd) do VIS.shd[k] = nil end
    dom_total = 0
    for key, v in pairs(ex.skills) do
      local dt = key % 64 - 1
      DOM[dt] = (DOM[dt] or 0) + v
      dom_total = dom_total + v
    end
    for id, v in pairs(ex.shields or VIS.shd) do VIS.shd[id] = v end
  end
  if dom_total > 0 then
    local best, best_v = nil, 0
    for key, v in pairs(DOM) do
      if v > best_v then best, best_v = key, v end
    end
    SUM.dom_type = best
    SUM.dom_pct = best_v / dom_total
  end
  SUM.top_shield, SUM.top_shield_v = nil, 0
  for id, v in pairs(VIS.shd) do
    if id > 0 and v > SUM.top_shield_v then SUM.top_shield, SUM.top_shield_v = id, v end
  end
  SUM.total_damage, SUM.total_shield, SUM.total_crit, SUM.hits, SUM.crit_hits, SUM.overkill = Vermilion.Metrics.totals()
  local ls = controls.loaded_sum
  if ls then
    SUM.total_damage = ls.total_damage or 0
    SUM.total_shield = ls.total_shield or 0
    SUM.total_crit   = ls.total_crit or 0
    SUM.hits         = ls.hits or 0
    SUM.crit_hits    = ls.crit_hits
    SUM.overkill     = ls.overkill
  end
  if SUM.total_damage > 0 and SUM.total_crit > 0 then SUM.crit_pct = SUM.total_crit / SUM.total_damage end
  SUM.crit_rate = Vermilion.Metrics.session_crit_rate(SUM)
  SUM.fight_ms = Vermilion.Metrics.fight_ms()
  SUM.alive_avg, SUM.dead_ms, SUM.deaths = nil, 0, 0
  if SUM.fight_ms > 0 then
    SUM.avg = (SUM.total_damage + SUM.total_shield) / (SUM.fight_ms / 1000)
    local lo, hi = Vermilion.Metrics.fight_bounds()
    if lo then
      local dead, count = Vermilion.Resources.dead_ms(lo, hi)
      if dead > 0 and dead < SUM.fight_ms then
        SUM.dead_ms, SUM.deaths = dead, count
        SUM.alive_avg = (SUM.total_damage + SUM.total_shield) / ((SUM.fight_ms - dead) / 1000)
      end
    end
  end
  return SUM
end

local function build_summary_text()
  local sm = session_summary()
  if sm.count == 0 then return nil end
  local vc = hexc(C_SUM.VAL)
  local parts = {
    string_format("|c%s%s|r |c%s%s|r", hexc(C_SUM.AVG),  GetString(VERMILION_SUMMARY_AVG),  vc, fmt_val(sm.avg)),
    string_format("|c%s%s|r |c%s%s|r", hexc(C_SUM.PEAK), GetString(VERMILION_SUMMARY_PEAK), vc, fmt_val(sm.peak)),
    string_format("|c%s%s|r |c%s%d%%|r", hexc(C_SUM.CRIT), GetString(VERMILION_SUMMARY_CRIT), vc, math_floor(sm.crit_rate * 100 + 0.5)),
  }
  local out_total = sm.total_damage + sm.total_shield
  if sm.total_shield > 0 and out_total > 0 then
    parts[#parts + 1] = string_format("|c%s%s|r |c%s%d%%|r",
      hexc(C_SUM.SHIELD), GetString(VERMILION_SUMMARY_SHIELD), vc,
      math_floor(sm.total_shield / out_total * 100 + 0.5))
  end
  if sm.dom_type ~= nil and DTYPE_ICON[sm.dom_type] then
    parts[#parts + 1] = string_format("|t14:14:%s|t |c%s%d%%|r", DTYPE_ICON[sm.dom_type], vc,
      math_floor(sm.dom_pct * 100 + 0.5))
  end
  return parts
end

local function show_report_card()
  local card = controls.card
  local chip = controls.summary
  if not card or not chip then return end
  local sm = session_summary()
  if sm.count == 0 then return end
  size_card(250)
  clear_card_rows(card)
  swatch_solid(card, C_CRIT.r, C_CRIT.g, C_CRIT.b)
  card.name:SetColor(C_CARD_NAME.r, C_CARD_NAME.g, C_CARD_NAME.b, 1.0)
  card.name:SetText(GetString(VERMILION_REPORT_TITLE))
  local total = sm.total_damage + sm.total_shield
  card.stat:SetText(string_format(GetString(VERMILION_REPORT_STAT),
    hexc(C_CRIT), math_floor(sm.crit_rate * 100 + 0.5), fmt_val(total)))
  card.time:SetText("")

  local rows = card.rows
  local n_rows = 0
  local function add_row(label, value, col)
    if n_rows >= CARD_MAX_ROWS then return end
    n_rows = n_rows + 1
    local r = rows[n_rows]
    r.name:SetText(label)
    r.name:SetColor(col.r, col.g, col.b, 1.0)
    r.name:SetHidden(false)
    r.val:SetText(value)
    r.val:SetHidden(false)
  end
  add_row(GetString(VERMILION_REPORT_DAMAGE), fmt_val(sm.total_damage), C_LINE_EDPS)
  add_row(GetString(VERMILION_REPORT_SHIELDED),
    (total > 0) and string_format("%s  ·  %d%%", fmt_val(sm.total_shield), math_floor(sm.total_shield / total * 100 + 0.5)) or "-",
    C_SHDPS)
  if sm.alive_avg then
    add_row(GetString(VERMILION_REPORT_AVG_ALIVE), fmt_val(sm.alive_avg), C_LINE_EOS)
    add_row(GetString(VERMILION_REPORT_AVG_ALL), fmt_val(sm.avg), C_CARD_STAT)
    add_row(GetString(VERMILION_REPORT_DEAD),
      string_format("%d  ·  %s  ·  %d%%", sm.deaths, fmt_secs(sm.dead_ms), math_floor(sm.dead_ms / sm.fight_ms * 100 + 0.5)), C_CRIT_BELOW)
  end
  local st = Vermilion.FightStats.compute(Vermilion.TemporalBuffer)
  if st.n > 0 then
    add_row(GetString(VERMILION_REPORT_P90), fmt_val(st.p90), C_SUM.P90)
    add_row(GetString(VERMILION_REPORT_MEDIAN), fmt_val(st.p50), C_SUM.MEDIAN)
    if st.p10 > 0 then add_row(GetString(VERMILION_REPORT_P10), fmt_val(st.p10), C_SUM.P10) end
  end
  if Vermilion.Kills and Vermilion.Kills.count() > 0 then
    add_row(GetString(VERMILION_REPORT_KILLS), tostring(Vermilion.Kills.count()), C_CRIT)
  end
  add_row(GetString(VERMILION_REPORT_HITS),
    (sm.hits > 0) and string_format(GetString(VERMILION_REPORT_HITS_AVG), sm.hits, fmt_val(sm.total_damage / sm.hits)) or "0",
    C_CARD_STAT)
  if sm.peak > 0 then
    add_row(GetString(VERMILION_REPORT_PEAK), fmt_secs(sm.peak_t_off), C_CARD_STAT)
  end
  local us = Vermilion.Ultimate and Vermilion.Ultimate.summary()
  if us and us.dur_ms > 0 and Vermilion.Ultimate.has_data() then
    add_row(GetString(VERMILION_REPORT_ULT_READY), string_format("%d%%", math_floor(us.ready_pct * 100 + 0.5)),
      (us.ready_pct > 0.25) and C_CRIT_BELOW or C_CARD_STAT)
    local casts = (us.casts > 1)
      and string_format(GetString(VERMILION_REPORT_APART), us.casts, fmt_secs(us.mean_gap_ms))
      or tostring(us.casts)
    add_row(GetString(VERMILION_REPORT_ULT_CASTS), casts, C_CARD_STAT)
  end
  local rs = Vermilion.Resources and Vermilion.Resources.summary(Vermilion.TemporalBuffer)
  if rs and rs.has then
    if rs.mag_out > 0 then
      add_row(GetString(VERMILION_RES_MAGICKA),
        string_format(GetString(VERMILION_REPORT_RES_SUSTAIN), rs.mag_sigma, math_floor(rs.mag_low_pct * 100 + 0.5)),
        (rs.mag_sigma < 0.8 or rs.mag_low_pct > 0.15) and C_CRIT_BELOW or C_CARD_STAT)
    end
    if rs.sta_out > 0 then
      add_row(GetString(VERMILION_RES_STAMINA),
        string_format(GetString(VERMILION_REPORT_RES_SUSTAIN), rs.sta_sigma, math_floor(rs.sta_low_pct * 100 + 0.5)),
        (rs.sta_sigma < 0.8 or rs.sta_low_pct > 0.15) and C_CRIT_BELOW or C_CARD_STAT)
    end
    if rs.eff > 0 then add_row(GetString(VERMILION_REPORT_RES_EFF), fmt_val(rs.eff), C_CARD_STAT) end
  end
  if sm.dom_type ~= nil and DamageTypeColors then
    local dc = DamageTypeColors.lookup(sm.dom_type)
    add_row(GetString(VERMILION_REPORT_MAIN_TYPE),
      string_format("%s  ·  %d%%", DamageTypeColors.name(sm.dom_type) or "?", math_floor(sm.dom_pct * 100 + 0.5)), dc or C_CARD_STAT)
  end

  local TVw = Vermilion.TargetsView
  local top_rows, top_n = TVw.compute()
  if top_n > 0 then
    add_row(GetString(VERMILION_REPORT_TOP_TARGET),
      string_format("%s  ·  %s", top_rows[1].name, fmt_val(top_rows[1].total)), C_LINE_EDPS)
    local on_top, switches, lanes = TVw.focus()
    if lanes > 1 then
      add_row(GetString(VERMILION_REPORT_FOCUS_TIME), string_format("%d%%", math_floor(on_top * 100 + 0.5)), C_CARD_STAT)
      add_row(GetString(VERMILION_REPORT_SWITCHES), tostring(switches), C_CARD_STAT)
    end
  end
  if sm.top_shield then
    add_row(GetString(VERMILION_REPORT_TOP_SHIELD),
      string_format("%s  ·  %s", Vermilion.SkillColors.ability_name(sm.top_shield), fmt_val(sm.top_shield_v)), C_SHDPS)
  end

  fit_card_rows(card, n_rows, 250)
  card.root:SetHeight(CARD_ROWS_Y0 + n_rows * CARD_ROW_H + 6)
  position_card(chip.bg:GetLeft() - 16, chip.bg:GetBottom() - 14)
  card_fader.report = true
end

M.summary, M.text, M.show = session_summary, build_summary_text, show_report_card
