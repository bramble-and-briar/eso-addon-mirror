Verdant = Verdant or {}
local Verdant = Verdant

Verdant.About = {}
local M = Verdant.About

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local Scene = Verdant.zenimax.scene
local Sound = Verdant.Sound
local Skin = Verdant.Skin
local Themes = Verdant.lib.themes
local GetString = api.GetString
local hex = Verdant.Format.hex

local AUTHOR = "Federico Vergelli"
local HANDLE = "@vergelli"
local CREDITS = { "Solinur", "@KertHertBert" }

local FILL = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local PAD, W = 14, 312
local FIELD_W, FIELD_H, ROW_H = 66, 20, 18
local CARD_W, CARD_PAD, NAME_H = 168, 9, 18
local LEVEL_CARD = 100

local window
local rows = {}
local credits = {}
local head = {}

local function label(name, font, x, y, w, h, role, align)
  local l = zui.WINDOW_MANAGER:CreateControl(name, window, zc.CT_LABEL)
  l:SetFont(font)
  l:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, x, y)
  l:SetDimensions(w, h)
  Skin.label(l, role)
  l:SetHorizontalAlignment(align or zc.TEXT_ALIGN_LEFT)
  l:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  return l
end

local function heading(name, text, y)
  local l = label(name, "ZoFontGameSmall", PAD, y, W, 12, "metal")
  l:SetText(text)
  local sep = zui.WINDOW_MANAGER:CreateControl(name .. "Sep", window, zc.CT_TEXTURE)
  sep:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD, y + 14)
  sep:SetDimensions(W, 1)
  Skin.label(sep, "metal", 0.22)
end

local function field(name, key, y)
  local l = label(name .. "Label", "ZoFontGameSmall", PAD, y, FIELD_W, FIELD_H, "metal")
  l:SetText(GetString(key))
  return label(name, "ZoFontGame", PAD + FIELD_W, y, W - FIELD_W, FIELD_H, "text")
end

local function row(name, key, y)
  local title = label(name .. "Title", "ZoFontGameSmall", PAD, y, W * 0.55, ROW_H, "dim")
  title:SetText(GetString(key))
  return label(name .. "Value", "ZoFontGameSmall", PAD + W * 0.55, y, W * 0.45, ROW_H, "metal", zc.TEXT_ALIGN_RIGHT)
end

local function overlay(c, level)
  c:SetDrawLayer(zc.DL_OVERLAY)
  c:SetDrawLevel(level)
end

local function show_credits(on)
  credits.card:SetHidden(not on)
  Skin.label(credits.word, on and "text" or "metal")
end

local function credits_enter() show_credits(true) end
local function credits_exit() show_credits(false) end

local function build_credits(y)
  local WM = zui.WINDOW_MANAGER
  credits.word = label("VerdantAboutCreditsLabel", "ZoFontGameSmall", PAD, y, FIELD_W, FIELD_H, "metal")
  credits.word:SetText(GetString(VERDANT_ABOUT_CREDITS))
  local help = WM:CreateControl("VerdantAboutCreditsHelp", window, zc.CT_TEXTURE)
  Skin.texture(help, "help")
  help:SetDimensions(16, 16)
  help:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD + FIELD_W, y + 2)
  local hit = WM:CreateControl("VerdantAboutCreditsHit", window, zc.CT_CONTROL)
  hit:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD, y)
  hit:SetDimensions(FIELD_W + 20, FIELD_H)
  hit:SetMouseEnabled(true)
  zui.handler(hit, "OnMouseEnter", credits_enter)
  zui.handler(hit, "OnMouseExit", credits_exit)

  local card = WM:CreateControl("VerdantAboutCreditsCard", window, zc.CT_CONTROL)
  card:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD + FIELD_W + 24, y - 5)
  card:SetDimensions(CARD_W, #CREDITS * NAME_H + CARD_PAD * 2)
  card:SetMouseEnabled(false)
  card:SetHidden(true)
  overlay(card, LEVEL_CARD)
  local fill = WM:CreateControl("VerdantAboutCreditsCardFill", card, zc.CT_TEXTURE)
  fill:SetTexture(FILL)
  fill:SetTextureCoords(0, 1, 0, 0.05)
  fill:SetColor(0.05, 0.06, 0.05, 1)
  fill:SetAnchorFill(card)
  overlay(fill, LEVEL_CARD + 1)
  local bg = WM:CreateControl("VerdantAboutCreditsCardBg", card, zc.CT_BACKDROP)
  bg:SetAnchorFill(card)
  Skin.panel(bg)
  overlay(bg, LEVEL_CARD + 2)
  for i = 1, #CREDITS do
    local l = WM:CreateControl("VerdantAboutCredit" .. i, card, zc.CT_LABEL)
    l:SetFont("ZoFontGame")
    l:SetAnchor(zc.TOPLEFT, card, zc.TOPLEFT, CARD_PAD + 3, CARD_PAD + (i - 1) * NAME_H)
    l:SetDimensions(CARD_W - (CARD_PAD + 3) * 2, NAME_H)
    Skin.label(l, "text")
    l:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
    l:SetText(CREDITS[i])
    overlay(l, LEVEL_CARD + 3)
  end
  credits.card = card
end

local function paint_head()
  head.name:SetText(string.format("Verdant  |c%s%s|r", hex(Themes.color("metal")), Verdant.Constants.VERSION))
  head.author:SetText(string.format("%s  |c%s%s|r", AUTHOR, hex(Themes.color("dim")), HANDLE))
end

local function build()
  head.name = label("VerdantAboutName", "ZoFontWindowTitle", 42, 6, W - 54, 28, "text")
  local y = 46
  head.author = field("VerdantAboutAuthor", VERDANT_ABOUT_AUTHOR, y)
  paint_head()
  Themes.on_change(paint_head)
  y = y + FIELD_H + 2
  build_credits(y)
  y = y + FIELD_H + 12
  heading("VerdantAboutDisk", GetString(VERDANT_ABOUT_DISK), y)
  y = y + 20
  rows.sessions = row("VerdantAboutSessions", VERDANT_ABOUT_SESSIONS, y)
  y = y + ROW_H
  if Verdant.Constants.DEBUG then
    rows.diagnostics = row("VerdantAboutDiagnostics", VERDANT_ABOUT_DIAGNOSTICS, y)
    y = y + ROW_H
  end
  rows.preferences = row("VerdantAboutPreferences", VERDANT_ABOUT_PREFERENCES, y)
  y = y + ROW_H + 10
  window:SetHeight(y)
end

function M.refresh()
  local R = Verdant.StorageReport
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
  window = VerdantAbout
  Scene.register_top_level(window)
  Skin.panel(VerdantAboutBg)
  Skin.close(VerdantAboutCloseBtn)
  build()
end
