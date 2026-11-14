Vermilion = Vermilion or {}
Vermilion.FilmOverview = {}
local M = Vermilion.FilmOverview

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local math_floor = math.floor
local math_abs = math.abs

local STRIP_H = 20
local GAP = 3
local PITCH = 3
local INSET = 6
local GRAB = 6
local GRIP_W, GRIP_H, GRIP_TOP = 3, 10, 5
local DRAG_UPDATE = "VermilionFilmStripDrag"
local HOVER_UPDATE = "VermilionFilmStripHover"
local RIGHT_BUTTON = MOUSE_BUTTON_INDEX_RIGHT or 2
local C_BAR = { r = 0.80, g = 0.68, b = 0.40, a = 0.75 }
local C_FRAME = { r = 0.86, g = 0.28, b = 0.18, a = 0.95 }
local C_GRIP = { r = 0.93, g = 0.76, b = 0.38 }
local C_DEAD = { r = 0.62, g = 0.62, b = 0.66, a = 0.45 }
local C_KILL = { r = 1.00, g = 0.92, b = 0.88, a = 0.95 }
local DEAD_MIN_W = 2
local KILL_W, KILL_H = 2, 4

local strip, viewport, canvas, on_change
local shade_l, shade_r
local frame = {}
local grips = {}
local edge_x0, edge_x1 = 0, 0
local drag_edge, hot_edge, hovering = nil, nil, false
local bars = {}
local peaks = {}
local showing = false
local dragging = false
local sig_n, sig_w, sig_t = -1, -1, -1
local sig_kill = -1
local dead_marks, kill_marks = {}, {}

local function texture(name, level, r, g, b, a)
  local t = zui.WINDOW_MANAGER:CreateControl(name, strip, zc.CT_TEXTURE)
  t:SetColor(r, g, b, a)
  t:SetDrawLevel(level)
  t:SetHidden(true)
  return t
end

local function place(t, x, y, w, h)
  t:ClearAnchors()
  t:SetAnchor(TOPLEFT, strip, TOPLEFT, x, y)
  t:SetDimensions(w, h)
  t:SetHidden(false)
end

local function draw_bars(n, w)
  local TB = Vermilion.TemporalBuffer
  local count = math_floor(w / PITCH)
  if count > n then count = n end
  if count < 1 then count = 1 end
  for i = 1, count do peaks[i] = 0 end
  local top = 0
  for i = 1, n do
    local s = TB.at(i)
    local v = s.eDPS + s.ShDPS
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
      bar = texture("VermilionFilmStripBar" .. i, 3, C_BAR.r, C_BAR.g, C_BAR.b, C_BAR.a)
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

local function kills_shown()
  local S = Vermilion.Settings
  if S and S.kill_markers and not S.kill_markers() then return -1 end
  return Vermilion.Kills.count()
end

local function draw_marks(n, w, kills)
  local TB = Vermilion.TemporalBuffer
  local period = (TB.at(n).t - TB.at(1).t) / (n - 1)
  local t0 = TB.at(1).t - period
  local span = period * n
  local t1 = t0 + span
  local used = 0
  local dts, dn, dte = Vermilion.Resources.deaths()
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
        mark = texture("VermilionFilmStripDead" .. used, 2, C_DEAD.r, C_DEAD.g, C_DEAD.b, C_DEAD.a)
        dead_marks[used] = mark
      end
      place(mark, x0, 0, x1 - x0, STRIP_H)
    end
  end
  for i = used + 1, #dead_marks do dead_marks[i]:SetHidden(true) end
  used = 0
  local K = Vermilion.Kills
  for i = 1, kills do
    local kt = K.get(i)
    if kt >= t0 then
      local x = math_floor((kt - t0) / span * w) - 1
      if x < 0 then x = 0 end
      if x > w - KILL_W then x = w - KILL_W end
      used = used + 1
      local mark = kill_marks[used]
      if not mark then
        mark = texture("VermilionFilmStripKill" .. used, 4, C_KILL.r, C_KILL.g, C_KILL.b, C_KILL.a)
        kill_marks[used] = mark
      end
      place(mark, x, 0, KILL_W, KILL_H)
    end
  end
  for i = used + 1, #kill_marks do kill_marks[i]:SetHidden(true) end
end

local function place_grip(i, x, hot)
  place(grips[i], x, hot and 0 or GRIP_TOP, GRIP_W, hot and STRIP_H or GRIP_H)
  grips[i]:SetColor(C_GRIP.r, C_GRIP.g, C_GRIP.b, hot and 1 or 0.75)
end

local function place_grips()
  place_grip(1, edge_x0, hot_edge == -1)
  place_grip(2, edge_x1 - GRIP_W, hot_edge == 1)
end

local function draw_window(n, w)
  local cols = Vermilion.FilmColumns.cols
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
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if n < 2 then return end
  local w = strip:GetWidth()
  if w <= 0 then return end
  local t = TB.at(n).t
  local kills = kills_shown()
  if n ~= sig_n or w ~= sig_w or t ~= sig_t or kills ~= sig_kill then
    sig_n, sig_w, sig_t, sig_kill = n, w, t, kills
    draw_bars(n, w)
    draw_marks(n, w, kills)
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

function M.sync(on)
  if on == showing or not strip then return end
  if not on then stop_hover() end
  showing = on
  strip:SetHidden(not on)
  canvas:ClearAnchors()
  canvas:SetAnchor(TOPLEFT, viewport, TOPLEFT, INSET, INSET)
  canvas:SetAnchor(BOTTOMRIGHT, viewport, BOTTOMRIGHT, -INSET, on and -(INSET + STRIP_H + GAP) or -INSET)
  sig_n = -1
end

function M.is_showing() return showing end
function M.forget() sig_n = -1 end

function M.drag_to(frac)
  local n = Vermilion.TemporalBuffer.count()
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  if Vermilion.FilmWindow.center_on(frac, n) and on_change then on_change() end
end

local function follow_mouse()
  local w = strip:GetWidth()
  if w <= 0 then return end
  local frac = (api.GetUIMousePosition() - strip:GetLeft()) / w
  if drag_edge then
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    local n = Vermilion.TemporalBuffer.count()
    if Vermilion.FilmWindow.drag_edge(drag_edge, frac, n) and on_change then on_change() end
  else
    M.drag_to(frac)
  end
end

local function stop_drag()
  if not dragging then return end
  dragging = false
  drag_edge = nil
  zev.unregister_update(DRAG_UPDATE)
  if hovering then hover_tick() else set_hot(nil) end
end

function M.mouse_down(button)
  if button == RIGHT_BUTTON then
    if Vermilion.FilmWindow.reset() and on_change then on_change() end
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

function M.mouse_up() stop_drag() end

function M.wheel(delta)
  local cols = Vermilion.FilmColumns.cols
  local n = Vermilion.TemporalBuffer.count()
  local mid = (cols.first + cols.last) / 2
  local dir = (delta and delta < 0) and 1 or -1
  local denom = cols.denom
  local frac = (denom > 0) and ((mid - cols.first) / denom) or 0.5
  if Vermilion.FilmWindow.zoom(dir, frac, n) and on_change then on_change() end
end

function M.attach(view, canv, changed)
  viewport, canvas, on_change = view, canv, changed
  strip = zui.WINDOW_MANAGER:CreateControl("VermilionFilmStrip", viewport, zc.CT_CONTROL)
  strip:SetAnchor(BOTTOMLEFT, viewport, BOTTOMLEFT, INSET, -INSET)
  strip:SetAnchor(BOTTOMRIGHT, viewport, BOTTOMRIGHT, -INSET, -INSET)
  strip:SetHeight(STRIP_H)
  strip:SetMouseEnabled(true)
  strip:SetHidden(true)
  local track = texture("VermilionFilmStripTrack", 2, 0, 0, 0, 0.35)
  track:SetAnchorFill(strip)
  track:SetHidden(false)
  shade_l = texture("VermilionFilmStripShadeL", 4, 0, 0, 0, 0.60)
  shade_r = texture("VermilionFilmStripShadeR", 4, 0, 0, 0, 0.60)
  for i = 1, 4 do
    frame[i] = texture("VermilionFilmStripFrame" .. i, 5, C_FRAME.r, C_FRAME.g, C_FRAME.b, C_FRAME.a)
  end
  for i = 1, 2 do
    grips[i] = texture("VermilionFilmStripGrip" .. i, 6, C_GRIP.r, C_GRIP.g, C_GRIP.b, 0.75)
  end
  strip:SetHandler("OnMouseEnter", function() start_hover() end)
  strip:SetHandler("OnMouseExit", function() stop_hover() end)
  strip:SetHandler("OnMouseDown", function(_, button) M.mouse_down(button) end)
  strip:SetHandler("OnMouseUp", function() M.mouse_up() end)
  strip:SetHandler("OnMouseWheel", function(_, delta) M.wheel(delta) end)
end
