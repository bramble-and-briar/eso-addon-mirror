Verdant = Verdant or {}
local Verdant = Verdant

Verdant.FilmOverview = {}
local M = Verdant.FilmOverview

local api  = Verdant.zenimax.api
local zui  = Verdant.zenimax.ui
local zc   = Verdant.zenimax.constants
local zev  = Verdant.zenimax.events
local Skin = Verdant.Skin
local math_floor = math.floor
local math_abs   = math.abs

local STRIP_H = 20
local GAP = 3
local PITCH = 3
local INSET = 6
local GRAB = 6
local GRIP_W, GRIP_H, GRIP_TOP = 3, 10, 5
local DEAD_MIN_W = 2
local C_DEAD = { r = 0.62, g = 0.62, b = 0.66, a = 0.45 }
local DRAG_UPDATE = "VerdantFilmStripDrag"
local HOVER_UPDATE = "VerdantFilmStripHover"
local FILL = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

local strip, viewport, canvas, on_change
local shade_l, shade_r
local frame = {}
local grips = {}
local edge_x0, edge_x1 = 0, 0
local drag_edge, hot_edge, hovering = nil, nil, false
local bars = {}
local peaks = {}
local dead_marks = {}
local showing = false
local side_w = 0
local dragging = false
local sig_n, sig_w, sig_t = -1, -1, -1

local function texture(name, level)
  local t = zui.WINDOW_MANAGER:CreateControl(name, strip, zc.CT_TEXTURE)
  t:SetTexture(FILL)
  t:SetTextureCoords(0, 1, 0, 0.05)
  t:SetDrawLevel(level)
  t:SetHidden(true)
  return t
end

local function place(t, x, y, w, h)
  t:ClearAnchors()
  t:SetAnchor(zc.TOPLEFT, strip, zc.TOPLEFT, x, y)
  t:SetDimensions(w, h)
  t:SetHidden(false)
end

local function draw_bars(n, w)
  local TB = Verdant.TemporalBuffer
  local count = math_floor(w / PITCH)
  if count > n then count = n end
  for i = 1, count do peaks[i] = 0 end
  local top = 0
  for i = 1, n do
    local s = TB.at(i)
    local v = s.eHPS + s.MPS
    local c = math_floor((i - 1) * count / n) + 1
    if v > peaks[c] then
      peaks[c] = v
      if v > top then top = v end
    end
  end
  local bw = w / count
  for i = 1, count do
    local bar = bars[i]
    if not bar then
      bar = texture("VerdantFilmStripBar" .. i, 3)
      Skin.label(bar, "metal", 0.75)
      bars[i] = bar
    end
    local h = (top > 0) and math_floor((STRIP_H - 2) * peaks[i] / top + 0.5) or 0
    if h > 0 then
      local x0 = math_floor((i - 1) * bw)
      local x1 = math_floor(i * bw)
      place(bar, x0, STRIP_H - 1 - h, (x1 > x0 + 1) and (x1 - x0 - 1) or 1, h)
    else
      bar:SetHidden(true)
    end
  end
  for i = count + 1, #bars do bars[i]:SetHidden(true) end
end

local function draw_dead(n, w)
  local TB = Verdant.TemporalBuffer
  local period = (TB.at(n).t - TB.at(1).t) / (n - 1)
  local t0 = TB.at(1).t - period
  local span = period * n
  local t1 = t0 + span
  local used = 0
  local dts, dn, dte = Verdant.FilmDead.spans()
  for i = 1, dn do
    local a = dts[i]
    local b = (dte[i] > 0) and dte[i] or t1
    if b > t0 then
      if a < t0 then a = t0 end
      local x0 = math_floor((a - t0) / span * w)
      local x1 = math_floor((b - t0) / span * w + 0.5)
      if x1 < x0 + DEAD_MIN_W then x1 = x0 + DEAD_MIN_W end
      if x1 > w then
        x1 = w
        if x0 > w - DEAD_MIN_W then x0 = w - DEAD_MIN_W end
      end
      used = used + 1
      local mark = dead_marks[used]
      if not mark then
        mark = texture("VerdantFilmStripDead" .. used, 2)
        mark:SetColor(C_DEAD.r, C_DEAD.g, C_DEAD.b, C_DEAD.a)
        dead_marks[used] = mark
      end
      place(mark, x0, 0, x1 - x0, STRIP_H)
    end
  end
  for i = used + 1, #dead_marks do dead_marks[i]:SetHidden(true) end
end

local function place_grip(i, x, hot)
  place(grips[i], x, hot and 0 or GRIP_TOP, GRIP_W, hot and STRIP_H or GRIP_H)
  grips[i]:SetAlpha(hot and 1 or 0.75)
end

local function place_grips()
  place_grip(1, edge_x0, hot_edge == -1)
  place_grip(2, edge_x1 - GRIP_W, hot_edge == 1)
end

local function draw_window(n, w)
  local cols = Verdant.ChartColumns.cols
  local x0 = math_floor((cols.first - 1) / n * w)
  local x1 = math_floor(cols.last / n * w + 0.5)
  if x1 < x0 + 4 then x1 = x0 + 4 end
  if x0 > 0 then place(shade_l, 0, 0, x0, STRIP_H) else shade_l:SetHidden(true) end
  if x1 < w then place(shade_r, x1, 0, w - x1, STRIP_H) else shade_r:SetHidden(true) end
  place(frame[1], x0, 0, x1 - x0, 1)
  place(frame[2], x0, STRIP_H - 1, x1 - x0, 1)
  place(frame[3], x0, 0, 1, STRIP_H)
  place(frame[4], x1 - 1, 0, 1, STRIP_H)
  edge_x0, edge_x1 = x0, x1
  place_grips()
end

function M.draw()
  if not showing then return end
  local TB = Verdant.TemporalBuffer
  local n = TB.count()
  local w = strip:GetWidth()
  if w < PITCH then return end
  local t = TB.at(n).t
  if n ~= sig_n or w ~= sig_w or t ~= sig_t then
    sig_n, sig_w, sig_t = n, w, t
    draw_bars(n, w)
    draw_dead(n, w)
  end
  draw_window(n, w)
end

local function set_hot(edge)
  if edge == hot_edge then return end
  hot_edge = edge
  zui.WINDOW_MANAGER:SetMouseCursor(edge and zc.MOUSE_CURSOR_RESIZE_EW or zc.MOUSE_CURSOR_DO_NOT_CARE)
  if showing then place_grips() end
end

local function edge_at()
  local x = api.GetUIMousePosition() - strip:GetLeft()
  local left, right = math_abs(x - edge_x0), math_abs(x - edge_x1)
  if left <= GRAB and left <= right then return -1 end
  if right <= GRAB then return 1 end
  return nil
end

local function hover_tick()
  if not drag_edge then set_hot(edge_at()) end
end

local function stop_hover()
  if hovering then
    hovering = false
    zev.unregister_update(HOVER_UPDATE)
  end
  if not drag_edge then set_hot(nil) end
end

local function start_hover()
  if not hovering then
    hovering = true
    zev.register_update(HOVER_UPDATE, 33, hover_tick)
  end
  hover_tick()
end

local function follow_mouse()
  local w = strip:GetWidth()
  if w <= 0 then return end
  local frac = (api.GetUIMousePosition() - strip:GetLeft()) / w
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  local W = Verdant.FilmWindow
  local n = Verdant.TemporalBuffer.count()
  local changed
  if drag_edge then
    changed = W.drag_edge(drag_edge, frac, n)
  else
    changed = W.center_on(frac, n)
  end
  if changed then on_change() end
end

local function stop_drag()
  if not dragging then return end
  dragging = false
  drag_edge = nil
  zev.unregister_update(DRAG_UPDATE)
  if hovering then hover_tick() else set_hot(nil) end
end

function M.sync(on, side)
  side = side or 0
  if on == showing and side == side_w then return end
  if not on and showing then
    stop_drag()
    stop_hover()
  end
  showing, side_w = on, side
  strip:SetHidden(not on)
  canvas:ClearAnchors()
  canvas:SetAnchor(zc.TOPLEFT, viewport, zc.TOPLEFT, INSET, INSET)
  canvas:SetAnchor(zc.BOTTOMRIGHT, viewport, zc.BOTTOMRIGHT, -INSET - side, on and -(INSET + STRIP_H + GAP) or -INSET)
end

function M.is_showing() return showing end
function M.forget() sig_n = -1 end

function M.mouse_down(button)
  if button == zc.MOUSE_BUTTON_INDEX_RIGHT then
    if Verdant.FilmWindow.reset() then on_change() end
    return
  end
  drag_edge = edge_at()
  set_hot(drag_edge)
  if not drag_edge then follow_mouse() end
  if not dragging then
    dragging = true
    zev.register_update(DRAG_UPDATE, 16, follow_mouse)
  end
end

function M.wheel(delta)
  local cols = Verdant.ChartColumns.cols
  local n = Verdant.TemporalBuffer.count()
  local mid = (cols.first + cols.last) / 2
  local dir = (delta < 0) and 1 or -1
  if Verdant.FilmWindow.zoom(dir, (mid - cols.first) / cols.denom, n) then on_change() end
end

function M.attach(view, canv, changed)
  viewport, canvas, on_change = view, canv, changed
  strip = zui.WINDOW_MANAGER:CreateControl("VerdantFilmStrip", viewport, zc.CT_CONTROL)
  strip:SetAnchor(zc.BOTTOMLEFT, viewport, zc.BOTTOMLEFT, INSET, -INSET)
  strip:SetAnchor(zc.BOTTOMRIGHT, viewport, zc.BOTTOMRIGHT, -INSET, -INSET)
  strip:SetHeight(STRIP_H)
  strip:SetMouseEnabled(true)
  strip:SetHidden(true)
  local track = texture("VerdantFilmStripTrack", 2)
  track:SetColor(0, 0, 0, 0.35)
  track:SetAnchorFill(strip)
  track:SetHidden(false)
  shade_l = texture("VerdantFilmStripShadeL", 4)
  shade_l:SetColor(0, 0, 0, 0.60)
  shade_r = texture("VerdantFilmStripShadeR", 4)
  shade_r:SetColor(0, 0, 0, 0.60)
  for i = 1, 4 do
    frame[i] = texture("VerdantFilmStripFrame" .. i, 5)
    Skin.label(frame[i], "accent", 0.95)
  end
  for i = 1, 2 do
    grips[i] = texture("VerdantFilmStripGrip" .. i, 6)
    Skin.label(grips[i], "metal", 1)
  end
  zui.handler(strip, "OnMouseEnter", start_hover)
  zui.handler(strip, "OnMouseExit", stop_hover)
  zui.handler(strip, "OnMouseDown", function(_, button) M.mouse_down(button) end)
  zui.handler(strip, "OnMouseUp", stop_drag)
  zui.handler(strip, "OnEffectivelyHidden", function()
    stop_drag()
    stop_hover()
  end)
  zui.handler(strip, "OnMouseWheel", function(_, delta) M.wheel(delta) end)
end
