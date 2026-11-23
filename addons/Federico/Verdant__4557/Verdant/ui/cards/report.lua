Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ReportCard = {}
local M = Verdant.ReportCard

local GetString     = Verdant.zenimax.api.GetString
local math_floor    = math.floor
local string_format = string.format

local HoverCard = Verdant.HoverCard
local clear_card_rows, position_card = HoverCard.clear_rows, HoverCard.place
local size_card, card_donut = HoverCard.size, HoverCard.donut
local CARD_ROW_H, CARD_MAX_ROWS, CARD_ROWS_Y0 = HoverCard.ROW_H, HoverCard.MAX_ROWS, HoverCard.ROWS_Y0
local C_CARD_STAT, C_CARD_NAME = HoverCard.C_STAT, HoverCard.C_NAME
local fmt_secs, hexc, fmt_val = Verdant.Format.secs, Verdant.Format.hex, Verdant.Format.value

local controls, report, card_fader
local C_EHPS, C_OVERHEAL, C_MEDIAN, C_RMAG, C_RSTA
local C_DIRECT = { r = 0.91, g = 0.58, b = 0.42 }
local RING_ROOM = 250 - 12 - 56 - 8

function M.bind(shared)
  controls, report = shared.controls, shared.report
  C_EHPS, C_OVERHEAL, C_MEDIAN = shared.C_EHPS, shared.C_OVERHEAL, shared.C_MEDIAN
  C_RMAG, C_RSTA = shared.C_RMAG, shared.C_RSTA
end

function M.attach(fader)
  card_fader = fader
end

local function show_report_card()
  local card = controls.card
  local chip = controls.summary
  if not card or not chip then return end
  local s = Verdant.TemporalBuffer.summary()
  if s.count == 0 then return end
  size_card(250)
  clear_card_rows(card)
  card.swatch:SetColor(C_OVERHEAL.r, C_OVERHEAL.g, C_OVERHEAL.b, 1.0)
  card.name:SetColor(C_CARD_NAME.r, C_CARD_NAME.g, C_CARD_NAME.b, 1.0)
  card.name:SetText(GetString(VERDANT_REPORT_TITLE))
  card.name:SetWidth(250 - 36 - 56)

  local wasted = s.wasted_pct
  local landed = 1 - wasted
  card.stat:SetText(string_format(GetString(VERDANT_REPORT_EFF_AMOUNT), hexc(C_EHPS), fmt_val(s.total_heal)))
  card.stat:SetWidth(RING_ROOM)
  card.time:SetText(string_format(GetString(VERDANT_REPORT_OVER_AMOUNT), hexc(C_OVERHEAL), fmt_val(s.total_overheal)))
  card.time:SetWidth(RING_ROOM)

  local split_total = report.hot + report.direct
  local known = split_total > 0
  local hot_share = known and (report.hot / split_total) or 0
  local hot_pct    = known and (wasted * hot_share) or 0
  local direct_pct = known and (wasted * (1 - hot_share)) or 0

  local dn = card_donut()
  if not report.cols then
    report.vals = {}
    report.cols = { C_EHPS, C_OVERHEAL, C_DIRECT }
  end
  report.vals[1] = landed
  report.vals[2] = known and hot_pct or wasted
  report.vals[3] = direct_pct
  dn:set(report.vals, report.cols)
  dn:control():SetHidden(false)

  local rows = card.rows
  local function share_row(r, label, value, c)
    r.name:SetText(GetString(label))
    r.name:SetColor(c.r, c.g, c.b, 1.0)
    r.name:SetHidden(false)
    r.val:SetText(value)
    r.val:SetHidden(false)
    HoverCard.row_swatch(r, c)
  end
  share_row(rows[1], VERDANT_REPORT_EFF_ROW, string_format("%d%%", math_floor(landed * 100 + 0.5)), C_EHPS)
  share_row(rows[2], VERDANT_REPORT_HOT, known and string_format("%d%%", math_floor(hot_pct * 100 + 0.5)) or "-",
    C_OVERHEAL)
  share_row(rows[3], VERDANT_REPORT_DIRECT, known and string_format("%d%%", math_floor(direct_pct * 100 + 0.5)) or "-",
    C_DIRECT)
  local n_rows = 3

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

  local TB = Verdant.TemporalBuffer
  local dead = Verdant.FightStats.dead(TB)
  local alive = Verdant.FightStats.alive_average(s.avg_ems, dead)
  if alive then
    add_row(GetString(VERDANT_REPORT_AVG_ALIVE), fmt_val(alive), C_EHPS)
    add_row(GetString(VERDANT_REPORT_AVG_ALL), fmt_val(s.avg_ems), C_CARD_STAT)
    add_row(GetString(VERDANT_REPORT_DEAD), string_format(GetString(VERDANT_REPORT_DEAD_VALUE),
      dead.count, fmt_secs(dead.ms), math_floor(dead.ms / dead.length * 100 + 0.5)), C_DIRECT)
  end
  local spread = Verdant.FightStats.compute(TB)
  if spread.p90 > 0 then
    add_row(GetString(VERDANT_REPORT_P90), fmt_val(spread.p90), C_EHPS)
    add_row(GetString(VERDANT_REPORT_MEDIAN), fmt_val(spread.p50), C_MEDIAN)
    if spread.p10 > 0 then add_row(GetString(VERDANT_REPORT_P10), fmt_val(spread.p10), C_OVERHEAL) end
  end

  local mag, sta = TB.restore_totals()
  mag, sta = mag or 0, sta or 0
  if mag + sta > 0 then
    add_row(GetString(VERDANT_REPORT_SUSTAIN), string_format(GetString(VERDANT_REPORT_SUSTAIN_VALUE), hexc(C_RMAG), fmt_val(mag), hexc(C_RSTA), fmt_val(sta)),
      C_CARD_STAT)
  end

  local us = Verdant.Ultimate.summary()
  if us.dur_ms > 0 then
    add_row(GetString(VERDANT_REPORT_ULT_READY),
      string_format("%d%%", math_floor(us.ready_pct * 100 + 0.5)),
      (us.ready_pct > 0.25) and C_DIRECT or C_CARD_STAT)
    local casts = (us.casts > 1)
      and string_format(GetString(VERDANT_REPORT_APART), us.casts, fmt_secs(us.mean_gap_ms))
      or tostring(us.casts)
    add_row(GetString(VERDANT_REPORT_ULT_CASTS), casts, C_CARD_STAT)
  end
  if s.peak_ems > 0 then
    add_row(GetString(VERDANT_REPORT_PEAK), fmt_secs(s.peak_t_off), C_CARD_STAT)
  end

  card.root:SetHeight(CARD_ROWS_Y0 + n_rows * CARD_ROW_H + 6)
  position_card(chip.bg:GetLeft() - 16, chip.bg:GetBottom() - 14)
  card_fader.report = true
end

M.show = show_report_card
