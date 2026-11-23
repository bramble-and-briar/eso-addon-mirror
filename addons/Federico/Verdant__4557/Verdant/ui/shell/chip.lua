Verdant = Verdant or {}
local Verdant = Verdant

Verdant.SummaryChip = {}
local M = Verdant.SummaryChip

local GetString    = Verdant.zenimax.api.GetString
local math_floor   = math.floor
local string_format = string.format

local fmt_val, hexc = Verdant.Format.value, Verdant.Format.hex
local text_width = Verdant.Format.text_width

local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local WM                = zui.WINDOW_MANAGER
local TOPRIGHT          = zc.TOPRIGHT
local CT_CONTROL        = zc.CT_CONTROL
local CT_LABEL          = zc.CT_LABEL
local CT_TEXTURE        = zc.CT_TEXTURE
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local FILL_TEXTURE      = Verdant.ChartPools.FILL_TEXTURE
local fade_out          = Verdant.Fader.hide
local show_report_card  = Verdant.ReportCard.show

local controls, STATE, ULT_L, C_SUM
local C_LINE_EHPS, C_LINE_EMS, C_CRIT, C_OVERHEAL

function M.bind(t)
  controls, STATE, ULT_L = t.controls, t.STATE, t.ULT_L
  C_LINE_EHPS, C_LINE_EMS, C_CRIT, C_OVERHEAL = t.C_LINE_EHPS, t.C_LINE_EMS, t.C_CRIT, t.C_OVERHEAL
  C_SUM = {
    AVG  = C_LINE_EHPS,
    PEAK = C_LINE_EMS,
    CRIT = C_CRIT,
    VAL  = { r = 0.92, g = 0.95, b = 0.93 },
    ACTIVE = { r = 0.80, g = 0.88, b = 0.62 },
    SHIELD = C_LINE_EMS,
  }
end

local function build_summary_text()
  local s = Verdant.TemporalBuffer.summary()
  if s.count == 0 then return nil end
  local vc = hexc(C_SUM.VAL)
  local crit_pct = math_floor(s.crit_pct * 100 + 0.5)
  local parts = {
    string_format("|c%s%s|r |c%s%s|r", hexc(C_SUM.AVG),  GetString(VERDANT_SUMMARY_AVG),  vc, fmt_val(s.avg_ems)),
    string_format("|c%s%s|r |c%s%s|r", hexc(C_SUM.PEAK), GetString(VERDANT_SUMMARY_PEAK), vc, fmt_val(s.peak_ems)),
    string_format("|c%s%s|r |c%s%d%%|r", hexc(C_SUM.CRIT), GetString(VERDANT_SUMMARY_CRIT), vc, crit_pct),
    string_format("|c%s%s|r |c%s%d%%|r", hexc(C_SUM.ACTIVE), GetString(VERDANT_SUMMARY_ACTIVE), vc,
      math_floor(s.active_pct * 100 + 0.5)),
  }
  local out_total = s.total_heal + s.total_shield
  if s.total_shield > 0 and out_total > 0 then
    parts[#parts + 1] = string_format("|c%s%s|r |c%s%d%%|r",
      hexc(C_SUM.SHIELD), GetString(VERDANT_SUMMARY_SHIELD), vc,
      math_floor(s.total_shield / out_total * 100 + 0.5))
  end
  if s.total_overheal > 0 then
    parts[#parts + 1] = string_format("|c%s%s|r |c%s%d%%|r",
      hexc(C_OVERHEAL), GetString(VERDANT_SUMMARY_OVERHEAL), vc,
      math_floor(s.wasted_pct * 100 + 0.5))
  end
  return parts
end

local function compose_summary(label, parts, avail)
  local lines, widest = 1, 0
  local text = ""
  local line = ""
  for i = 1, #parts do
    local candidate = (line == "") and parts[i] or (line .. "   " .. parts[i])
    local w = text_width(label, candidate)
    if w <= avail or line == "" then
      line = candidate
      if w > widest then widest = w end
    else
      text = (text == "") and line or (text .. "\n" .. line)
      lines = lines + 1
      line = parts[i]
      local lw = text_width(label, line)
      if lw > widest then widest = lw end
    end
  end
  text = (text == "") and line or (text .. "\n" .. line)
  return text, widest, lines
end

local function update_summary_chip()
  local chip = controls.summary
  if not chip then return end
  local show = STATE.summary ~= nil
            and not Verdant.TemporalBuffer.is_recording()
            and Verdant.TemporalBuffer.count() > 0
  if show then
    local avail = controls.window:GetWidth() - 36 - 34
    local text, w, lines = compose_summary(chip.label, STATE.summary, avail)
    chip.label:SetText(text)
    chip.label:SetWidth(w)
    chip.label:SetHeight(18 * lines + 2)
    chip.bg:SetWidth(w + 34)
    chip.bg:SetHeight(18 * lines + 2)
    chip.bg:SetHidden(false)
    chip.label:SetHidden(false)
    chip.help:SetHidden(false)
    chip.hit:SetHidden(false)
    ULT_L.CHIP = 18 * lines + 2 + 8
    ULT_L.CHIP_W = w + 34
  else
    chip.bg:SetHidden(true)
    chip.label:SetHidden(true)
    chip.help:SetHidden(true)
    chip.hit:SetHidden(true)
    ULT_L.CHIP = 0
  end
end

function M.create()
  local sum_bg = WM:CreateControl("VerdantGraphSummaryBg", controls.window, CT_TEXTURE)
  sum_bg:SetTexture(FILL_TEXTURE)
  sum_bg:SetTextureCoords(0, 1, 0, 0.05)
  sum_bg:SetColor(0.04, 0.09, 0.06, 0.55)
  sum_bg:SetAnchor(TOPRIGHT, controls.viewport, TOPRIGHT, -4, 4)
  sum_bg:SetHeight(20)
  sum_bg:SetDrawLevel(11)
  sum_bg:SetHidden(true)

  local sum_label = WM:CreateControl("VerdantGraphSummaryLabel", controls.window, CT_LABEL)
  sum_label:SetFont("ZoFontGameSmall")
  sum_label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  sum_label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  sum_label:SetAnchor(TOPRIGHT, controls.viewport, TOPRIGHT, -30, 4)
  sum_label:SetHeight(20)
  sum_label:SetDrawLevel(12)
  sum_label:SetHidden(true)

  local sum_help = WM:CreateControl("VerdantGraphSummaryHelp", controls.window, CT_TEXTURE)
  sum_help:SetTexture("EsoUI/Art/Miscellaneous/help_icon.dds")
  sum_help:SetDimensions(16, 16)
  sum_help:SetAnchor(TOPRIGHT, controls.viewport, TOPRIGHT, -8, 6)
  sum_help:SetColor(0.75, 0.90, 0.80, 0.9)
  sum_help:SetDrawLevel(12)
  sum_help:SetHidden(true)

  local sum_hit = WM:CreateControl("VerdantGraphSummaryHit", controls.window, CT_CONTROL)
  sum_hit:SetAnchorFill(sum_bg)
  sum_hit:SetMouseEnabled(true)
  sum_hit:SetDrawLevel(13)
  sum_hit:SetHidden(true)
  zui.handler(sum_hit, "OnMouseEnter", function()
    show_report_card()
  end)
  zui.handler(sum_hit, "OnMouseExit", function()
    fade_out(controls.card_fader)
  end)

  controls.summary = { bg = sum_bg, label = sum_label, help = sum_help, hit = sum_hit }
end

M.build       = build_summary_text
M.update      = update_summary_chip
