Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ChartDrag = {}
local M = Verdant.ChartDrag

local api = Verdant.zenimax.api
local zc  = Verdant.zenimax.constants
local zev = Verdant.zenimax.events
local zui = Verdant.zenimax.ui
local math_floor = math.floor

local UPDATE, AWAY = "VerdantChartDrag", "Verdant_ChartDragAway"
local HOVER_POLL, HOVER_MS = "VerdantHoverPoll", 50

local VIEWS = Verdant.Views.list
local Hover = Verdant.ChartHover

local STATE, controls, render
local dragging = false
local x0, first0, len0 = 0, 1, 1

function M.bind(t) STATE, controls, render = t.STATE, t.controls, t.render end

function M.active() return dragging end

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
  if Verdant.FilmWindow.move_to(first0 + shift, Verdant.TemporalBuffer.count()) then render() end
end

function M.finish()
  if not dragging then return false end
  dragging = false
  zui.WINDOW_MANAGER:SetMouseCursor(zc.MOUSE_CURSOR_DO_NOT_CARE)
  zev.unregister_update(UPDATE)
  zev.unregister(AWAY, zc.EVENT_GLOBAL_MOUSE_UP)
  if Hover.allowed() and over_chart() then zev.register_update(HOVER_POLL, HOVER_MS, Hover.poll) end
  return true
end

function M.begin(button)
  if dragging or button ~= zc.MOUSE_BUTTON_INDEX_LEFT then return end
  if not VIEWS[STATE.view].bars then return end
  local first, len = Verdant.FilmWindow.grab(Verdant.TemporalBuffer.count())
  if not first then return end
  dragging = true
  zui.WINDOW_MANAGER:SetMouseCursor(zc.MOUSE_CURSOR_PAN)
  x0 = api.GetUIMousePosition()
  first0, len0 = first, len
  Hover.stop_poll()
  Hover.hide_ui()
  if STATE.hover_key ~= nil then
    STATE.hover_key = nil
    render()
  end
  zev.register_update(UPDATE, 16, follow)
  zev.register(AWAY, zc.EVENT_GLOBAL_MOUSE_UP, M.finish)
end

function M.rebase()
  if not dragging then return end
  local first, len = Verdant.FilmWindow.grab(Verdant.TemporalBuffer.count())
  if not first then
    M.finish()
    return
  end
  x0 = api.GetUIMousePosition()
  first0, len0 = first, len
end
