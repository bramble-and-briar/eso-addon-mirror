
Verdant = Verdant or {}
local Verdant = Verdant

Verdant.CopyBox = {}
local M = Verdant.CopyBox

local NOOP = function() end
M.show       = NOOP
M.append     = NOOP
M.clear      = NOOP
M.hide       = NOOP
M.is_visible = function() return false end

local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local WINDOW_MANAGER         = zui.WINDOW_MANAGER
local CreateControlFromVirtual = zui.CreateControlFromVirtual
local TOPLEFT        = zc.TOPLEFT
local TOPRIGHT       = zc.TOPRIGHT
local BOTTOMLEFT     = zc.BOTTOMLEFT
local BOTTOMRIGHT    = zc.BOTTOMRIGHT
local CT_LABEL       = zc.CT_LABEL
local CT_BACKDROP    = zc.CT_BACKDROP
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local GuiRoot        = zc.GuiRoot

local controls
local buffer = ""

local function build()
  local win = WINDOW_MANAGER:CreateTopLevelWindow("VerdantCopyBoxWindow")
  win:SetDimensions(560, 360)
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 200, 120)
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:SetMouseEnabled(true)
  win:SetResizeHandleSize(8)
  zui.handler(win, "OnMoveStop", function()
    if Verdant.SavedVars and Verdant.SavedVars.copybox then
      Verdant.SavedVars.copybox.x = win:GetLeft()
      Verdant.SavedVars.copybox.y = win:GetTop()
    end
  end)

  local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", win, CT_BACKDROP)
  bg:SetAnchorFill(win)
  bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 6)
  bg:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
  bg:SetInsets(6, 6, -6, -6)

  local title = WINDOW_MANAGER:CreateControl("$(parent)Title", win, CT_LABEL)
  title:SetFont("ZoFontWindowTitle")
  title:SetColor(1, 0.8, 0, 1)
  title:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 10)
  title:SetText("Verdant Debug Copy")

  local close = CreateControlFromVirtual("$(parent)Close", win, "ZO_CloseButton")
  close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 8)
  zui.handler(close, "OnClicked", function() M.hide() end)

  local ebbg = CreateControlFromVirtual("$(parent)EBBg", win, "ZO_MultiLineEditBackdrop_Keyboard")
  ebbg:SetAnchor(TOPLEFT,     win, TOPLEFT,      14, 44)
  ebbg:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -14, -54)

  local edit = CreateControlFromVirtual("VerdantCopyBoxEdit", ebbg, "ZO_DefaultEditMultiLineForBackdrop")
  edit:SetMaxInputChars(500000)
  zui.handler(edit, "OnMouseWheel", function(self, delta, ctrl, alt, shift)
    local cur = self:GetTopLineIndex()
    if shift then delta = delta * 10 end
    self:SetTopLineIndex(zo_clamp(cur - delta, 1, self:GetScrollExtents() + 1))
  end)

  local function mkbtn(name, label, anchor_offset_x, on_click)
    local b = CreateControlFromVirtual("$(parent)" .. name, win, "ZO_DefaultButton")
    b:SetDimensions(120, 26)
    b:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, anchor_offset_x, -16)
    b:SetText(label)
    zui.handler(b, "OnClicked", on_click)
    return b
  end
  mkbtn("SelAll", "Select All", 14,  function()
    edit:TakeFocus()
    edit:SelectAll()
  end)
  mkbtn("Clr",    "Clear",      138, function() M.clear() end)

  controls = { window = win, edit = edit }

  local sv = Verdant.SavedVars and Verdant.SavedVars.copybox
  if sv and sv.x and sv.y then
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y)
  end

  win:SetHidden(true)
end

local function ensure_built()
  if not controls then build() end
end

function M.show(title, text)
  ensure_built()
  if title then
    controls.window:GetNamedChild("Title"):SetText(title)
  end
  if text then
    buffer = text
    controls.edit:SetText(buffer)
  end
  controls.window:SetHidden(false)
  controls.window:BringWindowToTop()
end

function M.append(text)
  ensure_built()
  if buffer == "" then
    buffer = text or ""
  else
    buffer = buffer .. "\n" .. (text or "")
  end
  controls.edit:SetText(buffer)
  controls.window:SetHidden(false)
end

function M.clear()
  buffer = ""
  if controls then controls.edit:SetText("") end
end

function M.hide()
  if controls then controls.window:SetHidden(true) end
end

function M.is_visible()
  return controls ~= nil and not controls.window:IsHidden()
end
