Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Watch = {}
local M = Verdant.Watch
local Sound = Verdant.Sound

local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local WINDOW_MANAGER = zui.WINDOW_MANAGER
local string_format  = string.format
local math_floor     = math.floor

local log = Verdant.Log.for_module("watch")
local TOPLEFT     = zc.TOPLEFT
local BOTTOMRIGHT = zc.BOTTOMRIGHT
local CT_TEXTURE  = zc.CT_TEXTURE
local CT_LABEL    = zc.CT_LABEL
local GuiRoot     = zc.GuiRoot

local FILL_TEXTURE   = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local MAX_ROWS = 4
local ROW_H    = 30
local ROW_GAP  = 4
local PAD      = 2

local C_BG     = { r = 0.05, g = 0.11, b = 0.07, a = 0.92 }
local C_ACCENT = Verdant.lib.themes.tint("watch", 1.0)
local C_NAME   = { r = 0.90, g = 1.00, b = 0.92, a = 1.0 }
local C_SOON   = { r = 1.00, g = 0.85, b = 0.40, a = 1.0 }
local C_NOW    = { r = 0.95, g = 0.34, b = 0.28, a = 1.0 }

local window
local rows = {}

local function build_row(i)
  local WM = WINDOW_MANAGER
  local y  = PAD + (i - 1) * (ROW_H + ROW_GAP)

  local bg = WM:CreateControl("VerdantWatchRowBg" .. i, window, CT_TEXTURE)
  bg:SetTexture(FILL_TEXTURE)
  bg:SetTextureCoords(0, 1, 0, 0.05)
  bg:SetAnchor(TOPLEFT, window, TOPLEFT, 0, y)
  bg:SetDimensions(230, ROW_H)
  bg:SetColor(C_BG.r, C_BG.g, C_BG.b, C_BG.a)
  bg:SetHidden(true)

  local accent = WM:CreateControl("VerdantWatchRowAccent" .. i, window, CT_TEXTURE)
  accent:SetTexture(FILL_TEXTURE)
  accent:SetTextureCoords(0, 1, 0, 0.05)
  accent:SetAnchor(TOPLEFT, window, TOPLEFT, 0, y)
  accent:SetDimensions(3, ROW_H)
  accent:SetColor(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, C_ACCENT.a)
  accent:SetHidden(true)

  local icon = WM:CreateControl("VerdantWatchRowIcon" .. i, window, CT_TEXTURE)
  icon:SetPixelRoundingEnabled(false)
  icon:SetAnchor(TOPLEFT, window, TOPLEFT, 8, y + math_floor((ROW_H - 22) / 2))
  icon:SetDimensions(22, 22)
  icon:SetHidden(true)

  local name = WM:CreateControl("VerdantWatchRowName" .. i, window, CT_LABEL)
  name:SetFont("ZoFontGameBold")
  name:SetHorizontalAlignment(zc.TEXT_ALIGN_LEFT)
  name:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  name:SetColor(C_NAME.r, C_NAME.g, C_NAME.b, C_NAME.a)
  name:SetMaxLineCount(1)
  name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  name:SetAnchor(TOPLEFT, window, TOPLEFT, 36, y)
  name:SetDimensions(130, ROW_H)
  name:SetHidden(true)

  local time = WM:CreateControl("VerdantWatchRowTime" .. i, window, CT_LABEL)
  time:SetFont("ZoFontGameBold")
  time:SetHorizontalAlignment(zc.TEXT_ALIGN_RIGHT)
  time:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  time:SetAnchor(TOPLEFT, window, TOPLEFT, 166, y)
  time:SetDimensions(56, ROW_H)
  time:SetHidden(true)

  rows[i] = { bg = bg, accent = accent, icon = icon, name = name, time = time }
end

local function row_hidden(row, hidden)
  row.bg:SetHidden(hidden)
  row.accent:SetHidden(hidden)
  row.icon:SetHidden(hidden)
  row.name:SetHidden(hidden)
  row.time:SetHidden(hidden)
end

local last_alerts

function M.render(alerts)
  if not window then return end
  last_alerts = alerts
  local chime = alerts.chime or 0
  if chime == 2 then
    Sound.play("alert_ready")
  elseif chime == 1 then
    Sound.play("alert_timer")
  end
  alerts.chime = 0
  local n = alerts.n
  if n > MAX_ROWS then n = MAX_ROWS end
  if n == 0 then
    window:SetHidden(true)
    return
  end
  local SC = Verdant.SkillColors
  local GetString = Verdant.zenimax.api.GetString
  for i = 1, MAX_ROWS do
    local row = rows[i]
    if i <= n then
      local a = alerts[i]
      row.icon:SetTexture(SC.ability_icon(a.id))
      row.name:SetText(a.name)
      if a.remaining <= 0 or a.remaining < 1.5 then
        row.accent:SetColor(C_NOW.r, C_NOW.g, C_NOW.b, C_NOW.a)
      else
        row.accent:SetColor(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, C_ACCENT.a)
      end
      if a.remaining > 0 then
        row.time:SetText(string_format("%.1fs", a.remaining))
        if a.remaining < 1.5 then
          row.time:SetColor(C_NOW.r, C_NOW.g, C_NOW.b, C_NOW.a)
        else
          row.time:SetColor(C_SOON.r, C_SOON.g, C_SOON.b, C_SOON.a)
        end
      else
        row.time:SetText(GetString(VERDANT_WATCH_NOW))
        row.time:SetColor(C_NOW.r, C_NOW.g, C_NOW.b, C_NOW.a)
      end
      row_hidden(row, false)
    else
      row_hidden(row, true)
    end
  end
  window:SetHeight(PAD * 2 + n * ROW_H + (n - 1) * ROW_GAP)
  window:SetHidden(false)
end

Verdant.lib.themes.on_change(function()
  if window and last_alerts and not window:IsHidden() then M.render(last_alerts) end
end)

function M.on_move_stop()
  local sv = Verdant.SavedVars
  if not sv or not window then return end
  sv.settings = sv.settings or {}
  sv.settings.watch_x = window:GetLeft()
  sv.settings.watch_y = window:GetTop()
end

function M.init()
  window = VerdantWatchOverlay
  for i = 1, MAX_ROWS do build_row(i) end

  local sv = Verdant.SavedVars
  local s  = sv and sv.settings
  window:ClearAnchors()
  if s and s.watch_x then
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, s.watch_x, s.watch_y)
  else
    window:SetAnchor(zc.TOP, GuiRoot, zc.TOP, 0, 180)
  end
  log:info("init")
end
