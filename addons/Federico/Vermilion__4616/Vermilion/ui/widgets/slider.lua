Vermilion = Vermilion or {}
Vermilion.Slider = {}
local M = Vermilion.Slider

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local math_floor = math.floor
local string_format = string.format

local BASE = "Vermilion/assets/skin/"
local GROOVE_H, FILL_H, FILL_INSET, THUMB_SIZE = 10, 6, 2, 22
local DRAG_MS = 16

local function layer(name, parent, texture, level)
  local t = zui.WINDOW_MANAGER:CreateControl(name, parent, zc.CT_TEXTURE)
  t:SetTexture(BASE .. texture)
  t:SetDrawLevel(level)
  return t
end

function M.new(opts)
  local track, label, on_change = opts.track, opts.label, opts.on_change
  local min, max, name = opts.min, opts.max, opts.name
  local value = opts.value
  local drag_update = name .. "Drag"
  local dragging = false
  local self = {}

  local groove = layer(name .. "Groove", track, "slider_groove.dds", 1)
  groove:SetAnchor(zc.LEFT, track, zc.LEFT, 0, 0)
  groove:SetAnchor(zc.RIGHT, track, zc.RIGHT, 0, 0)
  groove:SetHeight(GROOVE_H)
  local fill = layer(name .. "Fill", track, "slider_fill.dds", 2)
  fill:SetAnchor(zc.LEFT, track, zc.LEFT, FILL_INSET, 0)
  fill:SetHeight(FILL_H)
  local thumb = layer(name .. "Thumb", track, "slider_thumb.dds", 3)
  thumb:SetDimensions(THUMB_SIZE, THUMB_SIZE)

  local function paint()
    local w = track:GetWidth()
    if w <= 0 then return end
    local pct = (value - min) / (max - min)
    local run = w - 2 * FILL_INSET
    fill:SetWidth(run * pct)
    fill:SetTextureCoords(0, pct, 0, 1)
    fill:SetHidden(pct <= 0)
    thumb:ClearAnchors()
    thumb:SetAnchor(zc.CENTER, track, zc.LEFT, FILL_INSET + run * pct, 0)
    label:SetText(string_format("%d%%", value))
  end

  local function follow_mouse()
    local w = track:GetWidth()
    if w <= 0 then return end
    local pct = (api.GetUIMousePosition() - track:GetLeft() - FILL_INSET) / (w - 2 * FILL_INSET)
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    local v = min + math_floor(pct * (max - min) + 0.5)
    if v == value then return end
    value = v
    paint()
    on_change(v)
  end

  local function stop_drag()
    if not dragging then return end
    dragging = false
    zev.unregister_update(drag_update)
  end

  track:SetHandler("OnMouseDown", function()
    follow_mouse()
    if not dragging then
      dragging = true
      zev.register_update(drag_update, DRAG_MS, follow_mouse)
    end
  end)
  track:SetHandler("OnMouseUp", stop_drag)

  function self.set(v)
    if v < min then v = min elseif v > max then v = max end
    value = v
    paint()
  end
  function self.get() return value end
  function self.refresh() paint() end

  self.set(value)
  return self
end
