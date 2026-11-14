Vermilion = Vermilion or {}
Vermilion.SummaryChip = {}
local M = Vermilion.SummaryChip

local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local WINDOW_MANAGER    = zui.WINDOW_MANAGER
local TOPRIGHT          = zc.TOPRIGHT
local CT_TEXTURE        = zc.CT_TEXTURE
local CT_LABEL          = zc.CT_LABEL
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local FILL_TEXTURE      = Vermilion.ChartPools.FILL_TEXTURE
local fade_out          = Vermilion.Fader.hide
local show_report_card  = Vermilion.ReportCard.show

local controls, CHIP
local card_fader

function M.bind(t) controls, CHIP = t.controls, t.CHIP end
function M.attach(fader) card_fader = fader end

local function compose_summary(label, parts, avail)
  label:SetWidth(avail + 200)
  local lines, widest = 1, 0
  local text = ""
  local line = ""
  for i = 1, #parts do
    local candidate = (line == "") and parts[i] or (line .. "   " .. parts[i])
    label:SetText(candidate)
    local w = label:GetTextWidth()
    if w <= avail or line == "" then
      line = candidate
      if w > widest then widest = w end
    else
      text = (text == "") and line or (text .. "\n" .. line)
      lines = lines + 1
      line = parts[i]
      label:SetText(line)
      local lw = label:GetTextWidth()
      if lw > widest then widest = lw end
    end
  end
  text = (text == "") and line or (text .. "\n" .. line)
  return text, widest, lines
end

local function update_summary_chip()
  local chip = controls.summary
  if not chip then return end
  local show = CHIP.text ~= nil
            and not Vermilion.TemporalBuffer.is_recording()
            and Vermilion.TemporalBuffer.count() > 0
  if show then
    local avail = controls.window:GetWidth() - 36 - 34
    local text, w, lines = compose_summary(chip.label, CHIP.text, avail)
    chip.label:SetText(text)
    chip.label:SetWidth(w)
    chip.label:SetHeight(18 * lines + 2)
    chip.bg:SetWidth(w + 34)
    chip.bg:SetHeight(18 * lines + 2)
    chip.bg:SetHidden(false)
    chip.label:SetHidden(false)
    chip.help:SetHidden(false)
    chip.hit:SetHidden(false)
    CHIP.H = 18 * lines + 2 + 8
  else
    chip.bg:SetHidden(true)
    chip.label:SetHidden(true)
    chip.help:SetHidden(true)
    chip.hit:SetHidden(true)
    CHIP.H = 0
  end
end

function M.build()
  local sum_bg = WINDOW_MANAGER:CreateControl("VermilionGraphSummaryBg", controls.window, CT_TEXTURE)
  sum_bg:SetTexture(FILL_TEXTURE)
  sum_bg:SetTextureCoords(0, 1, 0, 0.05)
  sum_bg:SetColor(0.10, 0.04, 0.04, 0.55)
  sum_bg:SetAnchor(TOPRIGHT, controls.viewport, TOPRIGHT, -4, 4)
  sum_bg:SetHeight(20)
  sum_bg:SetDrawLevel(11)
  sum_bg:SetHidden(true)

  local sum_label = WINDOW_MANAGER:CreateControl("VermilionGraphSummaryLabel", controls.window, CT_LABEL)
  sum_label:SetFont("ZoFontGameSmall")
  sum_label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  sum_label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  sum_label:SetAnchor(TOPRIGHT, controls.viewport, TOPRIGHT, -30, 4)
  sum_label:SetHeight(20)
  sum_label:SetDrawLevel(12)
  sum_label:SetHidden(true)

  local sum_help = WINDOW_MANAGER:CreateControl("VermilionGraphSummaryHelp", controls.window, CT_TEXTURE)
  sum_help:SetTexture("Vermilion/assets/skin/help.dds")
  sum_help:SetDimensions(16, 16)
  sum_help:SetAnchor(TOPRIGHT, controls.viewport, TOPRIGHT, -8, 6)
  sum_help:SetColor(1, 1, 1, 1)
  sum_help:SetDrawLevel(12)
  sum_help:SetHidden(true)

  local sum_hit = WINDOW_MANAGER:CreateControl("VermilionGraphSummaryHit", controls.window, zc.CT_CONTROL)
  sum_hit:SetAnchorFill(sum_bg)
  sum_hit:SetMouseEnabled(true)
  sum_hit:SetDrawLevel(13)
  sum_hit:SetHidden(true)
  sum_hit:SetHandler("OnMouseEnter", function() show_report_card() end)
  sum_hit:SetHandler("OnMouseExit", function() fade_out(card_fader) end)
  controls.summary = { bg = sum_bg, label = sum_label, help = sum_help, hit = sum_hit }
end

M.update = update_summary_chip
