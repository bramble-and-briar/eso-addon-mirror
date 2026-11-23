Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Dropdown = {}
local M = Verdant.Dropdown

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local zev = Verdant.zenimax.events
local Skin = Verdant.Skin
local Sound = Verdant.Sound
local WINDOW_MANAGER = zui.WINDOW_MANAGER

local FILL = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local AWAY = "Verdant_DropdownAway"
local ROW_H, PAD, GAP = 22, 5, 2
local ONE_COLUMN_MAX = 6
local LEVEL_ROOT, LEVEL_FILL, LEVEL_BG, LEVEL_HOT, LEVEL_TEXT, LEVEL_HIT = 100, 101, 102, 103, 104, 105

local function inside(c, x, y)
  return x >= c:GetLeft() and x <= c:GetRight() and y >= c:GetTop() and y <= c:GetBottom()
end

local function overlay(c, level)
  c:SetDrawLayer(zc.DL_OVERLAY)
  c:SetDrawLevel(level)
end

local function paint(dd)
  local now = dd.selected()
  for i = 1, #dd.rows do
    local r = dd.rows[i]
    Skin.label(r.label, (r.key == now) and "metal" or "text")
    r.hot:SetHidden(true)
  end
end

local function build_row(dd, i, item, w, x, y)
  local nm = dd.name .. "Row" .. i

  local hot = WINDOW_MANAGER:CreateControl(nm .. "Hot", dd.root, zc.CT_TEXTURE)
  hot:SetTexture(FILL)
  hot:SetTextureCoords(0, 1, 0, 0.05)
  Skin.label(hot, "metal", 0.16)
  hot:SetAnchor(zc.TOPLEFT, dd.root, zc.TOPLEFT, x, y)
  hot:SetDimensions(w, ROW_H)
  overlay(hot, LEVEL_HOT)

  local label = WINDOW_MANAGER:CreateControl(nm .. "Label", dd.root, zc.CT_LABEL)
  label:SetFont("ZoFontGameSmall")
  label:SetHorizontalAlignment(zc.TEXT_ALIGN_LEFT)
  label:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  label:SetAnchor(zc.TOPLEFT, dd.root, zc.TOPLEFT, x + 8, y)
  label:SetDimensions(w - 16, ROW_H)
  label:SetText(item.label)
  overlay(label, LEVEL_TEXT)

  local hit = WINDOW_MANAGER:CreateControl(nm, dd.root, zc.CT_CONTROL)
  hit:SetAnchor(zc.TOPLEFT, dd.root, zc.TOPLEFT, x, y)
  hit:SetDimensions(w, ROW_H)
  hit:SetMouseEnabled(true)
  overlay(hit, LEVEL_HIT)
  zui.handler(hit, "OnMouseEnter", function() hot:SetHidden(false) end)
  zui.handler(hit, "OnMouseExit", function() hot:SetHidden(true) end)
  zui.handler(hit, "OnMouseUp", function(_, _, upInside)
    if upInside == false then return end
    dd.close()
    Sound.play("click")
    dd.on_pick(item.key)
  end)

  return { key = item.key, hit = hit, label = label, hot = hot }
end

local function build(dd)
  local w = dd.button:GetWidth()
  local n = #dd.items
  local cols = (n > ONE_COLUMN_MAX) and 2 or 1
  local rows = math.ceil(n / cols)
  local root = WINDOW_MANAGER:CreateControl(dd.name, dd.parent, zc.CT_CONTROL)
  root:SetDimensions(w, PAD * 2 + rows * ROW_H)
  root:SetMouseEnabled(true)
  overlay(root, LEVEL_ROOT)
  dd.root = root

  local fill = WINDOW_MANAGER:CreateControl(dd.name .. "Fill", root, zc.CT_TEXTURE)
  fill:SetTexture(FILL)
  fill:SetTextureCoords(0, 1, 0, 0.05)
  fill:SetColor(0.05, 0.06, 0.05, 1)
  fill:SetAnchorFill(root)
  overlay(fill, LEVEL_FILL)

  local bg = WINDOW_MANAGER:CreateControl(dd.name .. "Bg", root, zc.CT_BACKDROP)
  bg:SetAnchorFill(root)
  Skin.panel(bg)
  overlay(bg, LEVEL_BG)

  local cw = math.floor((w - PAD * 2) / cols)
  for i = 1, n do
    local col, row = math.floor((i - 1) / rows), (i - 1) % rows
    dd.rows[i] = build_row(dd, i, dd.items[i], cw, PAD + col * cw, PAD + row * ROW_H)
  end
end

function M.new(o)
  local dd = { name = o.name, parent = o.parent, button = o.button, items = o.items,
               selected = o.selected, on_pick = o.on_pick, rows = {} }

  function dd.is_open() return dd.root ~= nil and not dd.root:IsHidden() end

  function dd.close()
    if not dd.is_open() then return end
    dd.root:SetHidden(true)
    zev.unregister(AWAY, zc.EVENT_GLOBAL_MOUSE_UP)
  end

  function dd.away()
    local x, y = api.GetUIMousePosition()
    if inside(dd.root, x, y) or inside(dd.button, x, y) then return end
    dd.close()
  end

  function dd.toggle()
    if dd.is_open() then
      dd.close()
      Sound.play("close")
      return
    end
    if not dd.root then build(dd) end
    paint(dd)
    local btn, root = dd.button, dd.root
    root:ClearAnchors()
    local _, screen_h = zc.GuiRoot:GetDimensions()
    if btn:GetBottom() + GAP + root:GetHeight() > screen_h then
      root:SetAnchor(zc.BOTTOMLEFT, btn, zc.TOPLEFT, 0, -GAP)
    else
      root:SetAnchor(zc.TOPLEFT, btn, zc.BOTTOMLEFT, 0, GAP)
    end
    root:SetHidden(false)
    zev.register(AWAY, zc.EVENT_GLOBAL_MOUSE_UP, dd.away)
    Sound.play("page")
  end

  return dd
end
