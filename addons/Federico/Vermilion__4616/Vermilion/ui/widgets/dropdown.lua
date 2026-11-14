Vermilion = Vermilion or {}
Vermilion.Dropdown = {}
local M = Vermilion.Dropdown

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local WINDOW_MANAGER = zui.WINDOW_MANAGER

local FILL = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local ROW_H, PAD = 22, 5
local LEVEL_ROOT, LEVEL_FILL, LEVEL_BG, LEVEL_HOT, LEVEL_TEXT, LEVEL_HIT = 100, 101, 102, 103, 104, 105

local function inside(c, x, y)
  return x >= c:GetLeft() and x <= c:GetRight() and y >= c:GetTop() and y <= c:GetBottom()
end

local function overlay(c, level)
  c:SetDrawLayer(DL_OVERLAY)
  c:SetDrawLevel(level)
end

local function paint(dd)
  local Skin = Vermilion.Skin
  local now = dd.selected()
  for i = 1, #dd.rows do
    local r = dd.rows[i]
    local col = (r.key == now) and Skin.GOLD or Skin.TEXT
    r.label:SetColor(col.r, col.g, col.b, 1)
    r.hot:SetHidden(true)
  end
end

local function build_row(dd, i, item, w)
  local Skin = Vermilion.Skin
  local nm = dd.name .. "Row" .. i
  local y = PAD + (i - 1) * ROW_H

  local hot = WINDOW_MANAGER:CreateControl(nm .. "Hot", dd.root, zc.CT_TEXTURE)
  hot:SetTexture(FILL)
  hot:SetTextureCoords(0, 1, 0, 0.05)
  hot:SetColor(Skin.GOLD.r, Skin.GOLD.g, Skin.GOLD.b, 0.16)
  hot:SetAnchor(zc.TOPLEFT, dd.root, zc.TOPLEFT, PAD, y)
  hot:SetDimensions(w, ROW_H)
  hot:SetHidden(true)
  overlay(hot, LEVEL_HOT)

  local label = WINDOW_MANAGER:CreateControl(nm .. "Label", dd.root, zc.CT_LABEL)
  label:SetFont("ZoFontGameSmall")
  label:SetHorizontalAlignment(zc.TEXT_ALIGN_LEFT)
  label:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  label:SetAnchor(zc.TOPLEFT, dd.root, zc.TOPLEFT, PAD + 8, y)
  label:SetDimensions(w - 16, ROW_H)
  label:SetText(item.label)
  overlay(label, LEVEL_TEXT)

  local hit = WINDOW_MANAGER:CreateControl(nm, dd.root, zc.CT_CONTROL)
  hit:SetAnchor(zc.TOPLEFT, dd.root, zc.TOPLEFT, PAD, y)
  hit:SetDimensions(w, ROW_H)
  hit:SetMouseEnabled(true)
  overlay(hit, LEVEL_HIT)
  hit:SetHandler("OnMouseEnter", function() hot:SetHidden(false) end)
  hit:SetHandler("OnMouseExit", function() hot:SetHidden(true) end)
  hit:SetHandler("OnMouseUp", function(_, _, upInside)
    if upInside == false then return end
    dd.close()
    Vermilion.Sound.play("click")
    dd.on_pick(item.key)
  end)

  return { key = item.key, hit = hit, label = label, hot = hot }
end

local function build(dd)
  local w = dd.button:GetWidth()
  local n = #dd.items
  local root = WINDOW_MANAGER:CreateControl(dd.name, dd.parent, zc.CT_CONTROL)
  root:SetDimensions(w, PAD * 2 + n * ROW_H)
  root:SetMouseEnabled(true)
  root:SetHidden(true)
  overlay(root, LEVEL_ROOT)
  dd.root = root

  local fill = WINDOW_MANAGER:CreateControl(dd.name .. "Fill", root, zc.CT_TEXTURE)
  fill:SetTexture(FILL)
  fill:SetTextureCoords(0, 1, 0, 0.05)
  fill:SetColor(0.06, 0.05, 0.05, 1)
  fill:SetAnchorFill(root)
  overlay(fill, LEVEL_FILL)

  local bg = WINDOW_MANAGER:CreateControl(dd.name .. "Bg", root, zc.CT_BACKDROP)
  bg:SetAnchorFill(root)
  Vermilion.Skin.panel(bg)
  overlay(bg, LEVEL_BG)

  for i = 1, n do dd.rows[i] = build_row(dd, i, dd.items[i], w - PAD * 2) end
end

function M.new(o)
  local dd = { name = o.name, parent = o.parent, button = o.button, items = o.items,
               selected = o.selected, on_pick = o.on_pick, rows = {} }

  function dd.is_open() return dd.root ~= nil and not dd.root:IsHidden() end

  function dd.close()
    if not dd.is_open() then return end
    dd.root:SetHidden(true)
    if zc.EVENT_GLOBAL_MOUSE_UP then zev.unregister(dd.name .. "Away", zc.EVENT_GLOBAL_MOUSE_UP) end
  end

  function dd.away()
    if not dd.is_open() then return end
    local x, y = api.GetUIMousePosition()
    if inside(dd.root, x, y) or inside(dd.button, x, y) then return end
    dd.close()
  end

  function dd.toggle()
    if dd.is_open() then
      dd.close()
      Vermilion.Sound.play("close")
      return
    end
    if not dd.root then build(dd) end
    paint(dd)
    local btn, root = dd.button, dd.root
    root:ClearAnchors()
    local _, screen_h = zc.GuiRoot:GetDimensions()
    if btn:GetBottom() + root:GetHeight() > screen_h then
      root:SetAnchor(zc.BOTTOMLEFT, btn, zc.TOPLEFT, 0, -2)
    else
      root:SetAnchor(zc.TOPLEFT, btn, zc.BOTTOMLEFT, 0, 2)
    end
    root:SetHidden(false)
    if zc.EVENT_GLOBAL_MOUSE_UP then zev.register(dd.name .. "Away", zc.EVENT_GLOBAL_MOUSE_UP, dd.away) end
    Vermilion.Sound.play("page")
  end

  return dd
end
