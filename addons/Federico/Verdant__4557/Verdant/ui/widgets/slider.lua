Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Slider = {}
local M = Verdant.Slider

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local zev = Verdant.zenimax.events
local Skin = Verdant.Skin
local math_floor = math.floor
local math_abs = math.abs

local GROOVE_H, FILL_H, FILL_INSET, THUMB_SIZE = 10, 6, 2, 22
local DRAG_TICK = "VerdantSliderDrag"
local DRAG_MS = 16

local function layer(name, parent, piece, level)
  local t = zui.WINDOW_MANAGER:CreateControl(name, parent, zc.CT_TEXTURE)
  Skin.texture(t, piece)
  t:SetDrawLevel(level)
  return t
end

local function nearest(steps, v)
  local at, gap = 1, math.huge
  for i = 1, #steps do
    local apart = math_abs(steps[i] - v)
    if apart < gap then at, gap = i, apart end
  end
  return at
end

function M.range(first, last, step)
  local steps = {}
  for v = first, last, step do steps[#steps + 1] = v end
  return steps
end

function M.new(o)
  local track, label, steps, text, on_change = o.track, o.label, o.steps, o.text, o.on_change
  local name = o.name
  local at = 1
  local dragging = false
  local self = {}

  local groove = layer(name .. "Groove", track, "slider_groove", 1)
  groove:SetAnchor(zc.LEFT, track, zc.LEFT, 0, 0)
  groove:SetAnchor(zc.RIGHT, track, zc.RIGHT, 0, 0)
  groove:SetHeight(GROOVE_H)
  local fill = layer(name .. "Fill", track, "slider_fill", 2)
  fill:SetAnchor(zc.LEFT, track, zc.LEFT, FILL_INSET, 0)
  fill:SetHeight(FILL_H)
  local thumb = layer(name .. "Thumb", track, "slider_thumb", 3)
  thumb:SetDimensions(THUMB_SIZE, THUMB_SIZE)

  local function paint()
    local w = track:GetWidth()
    if w <= 0 then return end
    local share = (at - 1) / (#steps - 1)
    local run = w - 2 * FILL_INSET
    fill:SetWidth(run * share)
    fill:SetTextureCoords(0, share, 0, 1)
    fill:SetHidden(share <= 0)
    thumb:ClearAnchors()
    thumb:SetAnchor(zc.CENTER, track, zc.LEFT, FILL_INSET + run * share, 0)
    label:SetText(text(steps[at]))
  end

  local function follow_mouse()
    local w = track:GetWidth()
    if w <= 0 then return end
    local share = (api.GetUIMousePosition() - track:GetLeft() - FILL_INSET) / (w - 2 * FILL_INSET)
    if share < 0 then share = 0 elseif share > 1 then share = 1 end
    local i = math_floor(share * (#steps - 1) + 0.5) + 1
    if i == at then return end
    at = i
    paint()
    on_change(steps[at])
  end

  local function stop_drag()
    if not dragging then return end
    dragging = false
    zev.unregister_update(DRAG_TICK)
  end

  zui.handler(track, "OnMouseDown", function()
    follow_mouse()
    if not dragging then
      dragging = true
      zev.register_update(DRAG_TICK, DRAG_MS, follow_mouse)
    end
  end)
  zui.handler(track, "OnMouseUp", stop_drag)
  zui.handler(track, "OnEffectivelyHidden", stop_drag)

  function self.set(v)
    at = nearest(steps, v)
    paint()
  end

  function self.get() return steps[at] end

  self.set(o.value)
  return self
end
