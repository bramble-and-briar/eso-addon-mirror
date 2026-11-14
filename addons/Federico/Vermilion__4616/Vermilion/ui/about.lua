Vermilion = Vermilion or {}
Vermilion.About = {}
local M = Vermilion.About

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local Scene = Vermilion.zenimax.scene
local Sound = Vermilion.Sound
local GetString = api.GetString

local AUTHOR = "Federico Vergelli"
local HANDLE = "@vergelli"
local CREDITS = { "Solinur", "Baertram", "@KertHertBert" }

local BASE = "Vermilion/assets/skin/"
local FILL = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local PAD, W = 14, 312
local FIELD_W, FIELD_H, ROW_H = 66, 20, 18
local CARD_W, CARD_PAD, NAME_H = 168, 9, 18
local LEVEL_CARD = 100
local C_HEAD = { 0.95, 0.42, 0.34 }
local C_TEXT = { 0.92, 0.88, 0.84 }
local HEX_GOLD, HEX_DIM = "C4A15C", "9E9E9E"

local window
local rows = {}
local credits = {}

local function label(name, font, x, y, w, h, r, g, b, align)
  local l = zui.WINDOW_MANAGER:CreateControl(name, window, zc.CT_LABEL)
  l:SetFont(font)
  l:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, x, y)
  l:SetDimensions(w, h)
  l:SetColor(r, g, b, 1)
  l:SetHorizontalAlignment(align or zc.TEXT_ALIGN_LEFT)
  l:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  return l
end

local function heading(name, text, y)
  local l = label(name, "ZoFontGameSmall", PAD, y, W, 12, C_HEAD[1], C_HEAD[2], C_HEAD[3])
  l:SetText(text)
  local sep = zui.WINDOW_MANAGER:CreateControl(name .. "Sep", window, zc.CT_TEXTURE)
  sep:SetColor(C_HEAD[1], C_HEAD[2], C_HEAD[3], 0.22)
  sep:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD, y + 14)
  sep:SetDimensions(W, 1)
end

local function field(name, key, y)
  local l = label(name .. "Label", "ZoFontGameSmall", PAD, y, FIELD_W, FIELD_H, C_HEAD[1], C_HEAD[2], C_HEAD[3])
  l:SetText(GetString(key))
  return label(name, "ZoFontGame", PAD + FIELD_W, y, W - FIELD_W, FIELD_H, C_TEXT[1], C_TEXT[2], C_TEXT[3]), l
end

local function row(name, key, y)
  local title = label(name .. "Title", "ZoFontGameSmall", PAD, y, W * 0.55, ROW_H, 0.75, 0.75, 0.75)
  title:SetText(GetString(key))
  return label(name .. "Value", "ZoFontGameSmall", PAD + W * 0.55, y, W * 0.45, ROW_H, 0.95, 0.80, 0.20, zc.TEXT_ALIGN_RIGHT)
end

local function overlay(c, level)
  c:SetDrawLayer(DL_OVERLAY)
  c:SetDrawLevel(level)
end

local function show_credits(on)
  credits.card:SetHidden(not on)
  local c = on and C_TEXT or C_HEAD
  credits.word:SetColor(c[1], c[2], c[3], 1)
end

local function credits_enter() show_credits(true) end
local function credits_exit() show_credits(false) end

local function build_credits(y)
  local WM = zui.WINDOW_MANAGER
  credits.word = label("VermilionAboutCreditsLabel", "ZoFontGameSmall", PAD, y, FIELD_W, FIELD_H, C_HEAD[1], C_HEAD[2], C_HEAD[3])
  credits.word:SetText(GetString(VERMILION_ABOUT_CREDITS))
  local help = WM:CreateControl("VermilionAboutCreditsHelp", window, zc.CT_TEXTURE)
  help:SetTexture(BASE .. "help.dds")
  help:SetDimensions(16, 16)
  help:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD + FIELD_W, y + 2)
  local hit = WM:CreateControl("VermilionAboutCreditsHit", window, zc.CT_CONTROL)
  hit:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD, y)
  hit:SetDimensions(FIELD_W + 20, FIELD_H)
  hit:SetMouseEnabled(true)
  hit:SetHandler("OnMouseEnter", credits_enter)
  hit:SetHandler("OnMouseExit", credits_exit)

  local card = WM:CreateControl("VermilionAboutCreditsCard", window, zc.CT_CONTROL)
  card:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD + FIELD_W + 24, y - 5)
  card:SetDimensions(CARD_W, #CREDITS * NAME_H + CARD_PAD * 2)
  card:SetMouseEnabled(false)
  card:SetHidden(true)
  overlay(card, LEVEL_CARD)
  local fill = WM:CreateControl("VermilionAboutCreditsCardFill", card, zc.CT_TEXTURE)
  fill:SetTexture(FILL)
  fill:SetTextureCoords(0, 1, 0, 0.05)
  fill:SetColor(0.06, 0.05, 0.05, 1)
  fill:SetAnchorFill(card)
  overlay(fill, LEVEL_CARD + 1)
  local bg = WM:CreateControl("VermilionAboutCreditsCardBg", card, zc.CT_BACKDROP)
  bg:SetAnchorFill(card)
  Vermilion.Skin.panel(bg)
  overlay(bg, LEVEL_CARD + 2)
  for i = 1, #CREDITS do
    local l = WM:CreateControl("VermilionAboutCredit" .. i, card, zc.CT_LABEL)
    l:SetFont("ZoFontGame")
    l:SetAnchor(zc.TOPLEFT, card, zc.TOPLEFT, CARD_PAD + 3, CARD_PAD + (i - 1) * NAME_H)
    l:SetDimensions(CARD_W - (CARD_PAD + 3) * 2, NAME_H)
    l:SetColor(C_TEXT[1], C_TEXT[2], C_TEXT[3], 1)
    l:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
    l:SetText(CREDITS[i])
    overlay(l, LEVEL_CARD + 3)
  end
  credits.card = card
end

local function build()
  local name = label("VermilionAboutName", "ZoFontWindowTitle", 42, 6, W - 54, 28, C_HEAD[1], C_HEAD[2], C_HEAD[3])
  name:SetText(string.format("Vermilion  |c%s%s|r", HEX_GOLD, Vermilion.Constants.VERSION))
  local y = 46
  local by = field("VermilionAboutAuthor", VERMILION_ABOUT_AUTHOR, y)
  by:SetText(string.format("%s  |c%s%s|r", AUTHOR, HEX_DIM, HANDLE))
  y = y + FIELD_H + 2
  build_credits(y)
  y = y + FIELD_H + 12
  heading("VermilionAboutDisk", GetString(VERMILION_ABOUT_DISK), y)
  y = y + 20
  rows.sessions = row("VermilionAboutSessions", VERMILION_ABOUT_SESSIONS, y)
  y = y + ROW_H
  if Vermilion.Constants.DEBUG then
    rows.diagnostics = row("VermilionAboutDiagnostics", VERMILION_ABOUT_DIAGNOSTICS, y)
    y = y + ROW_H
  end
  rows.preferences = row("VermilionAboutPreferences", VERMILION_ABOUT_PREFERENCES, y)
  y = y + ROW_H + 10
  window:SetHeight(y)
end

function M.refresh()
  local R = Vermilion.StorageReport
  local r = R.report()
  local fmt = R.format_bytes
  rows.sessions:SetText(string.format("%s  ·  %d/%d", fmt(r.sessions), r.session_count, r.session_cap))
  if rows.diagnostics then rows.diagnostics:SetText(fmt(r.diagnostics)) end
  rows.preferences:SetText(fmt(r.preferences))
end

function M.show()
  M.refresh()
  Scene.show_top_level(window)
  Sound.play("open")
end

function M.hide()
  if window:IsHidden() then return end
  show_credits(false)
  Sound.play("close")
  Scene.hide_top_level(window)
end

function M.toggle()
  if window:IsHidden() then M.show() else M.hide() end
end

function M.init()
  window = VermilionAbout
  Scene.register_top_level(window)
  window:SetHidden(true)
  Vermilion.Skin.panel(VermilionAboutBg)
  Vermilion.Skin.close(VermilionAboutCloseBtn)
  build()
end
