Vermilion = Vermilion or {}
Vermilion.ChartDrag = {}
local M = Vermilion.ChartDrag

local api = Vermilion.zenimax.api
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local zui = Vermilion.zenimax.ui
local math_floor = math.floor

local LEFT_BUTTON = zc.MOUSE_BUTTON_INDEX_LEFT or 1
local UPDATE, AWAY = "VermilionChartDrag", "Vermilion_ChartDragAway"
local HOVER_POLL, HOVER_MS = "VermilionHoverPoll", 50

local VIEWS = Vermilion.Views.list
local Hover = Vermilion.ChartHover

local STATE, controls, render
local dragging = false
local x0, first0, len0 = 0, 1, 1

function M.bind(t) STATE, controls, render = t.STATE, t.controls, t.render end

function M.active() return dragging end

local function cursor(shape)
  if zc.MOUSE_CURSOR_PAN then zui.WINDOW_MANAGER:SetMouseCursor(shape) end
end

local function over_chart()
  local mx, my = api.GetUIMousePosition()
  local c = controls.canvas
  local left, top = c:GetLeft(), c:GetTop()
  return mx >= left and mx < left + c:GetWidth() and my >= top and my < top + c:GetHeight()
end

local function follow()
  local cw = controls.canvas:GetWidth()
  if cw <= 0 then return end
  local dx = api.GetUIMousePosition() - x0
  local shift = math_floor(-dx * len0 / cw + 0.5)
  if Vermilion.FilmWindow.move_to(first0 + shift, Vermilion.TemporalBuffer.count()) then render() end
end

function M.finish()
  if not dragging then return false end
  dragging = false
  cursor(zc.MOUSE_CURSOR_DO_NOT_CARE)
  zev.unregister_update(UPDATE)
  if zc.EVENT_GLOBAL_MOUSE_UP then zev.unregister(AWAY, zc.EVENT_GLOBAL_MOUSE_UP) end
  if Hover.allowed() and over_chart() then zev.register_update(HOVER_POLL, HOVER_MS, Hover.poll) end
  return true
end

function M.begin(button)
  if dragging or button ~= LEFT_BUTTON then return false end
  local TB = Vermilion.TemporalBuffer
  if not VIEWS[STATE.view].bars or TB.is_recording() then return false end
  local first, len = Vermilion.FilmWindow.grab(TB.count())
  if not first then return false end
  dragging = true
  cursor(zc.MOUSE_CURSOR_PAN)
  x0 = api.GetUIMousePosition()
  first0, len0 = first, len
  Hover.stop_poll()
  Hover.hide_ui()
  if STATE.hover_key ~= nil then
    STATE.hover_key = nil
    render()
  end
  zev.register_update(UPDATE, 16, follow)
  if zc.EVENT_GLOBAL_MOUSE_UP then zev.register(AWAY, zc.EVENT_GLOBAL_MOUSE_UP, M.finish) end
  return true
end

function M.rebase()
  if not dragging then return end
  local first, len = Vermilion.FilmWindow.grab(Vermilion.TemporalBuffer.count())
  if not first then
    M.finish()
    return
  end
  x0 = api.GetUIMousePosition()
  first0, len0 = first, len
end
