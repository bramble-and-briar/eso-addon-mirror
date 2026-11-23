Verdant = Verdant or {}
local Verdant = Verdant
if not Verdant.Constants.DEBUG then return end

Verdant.TideProbe = {}
local M = Verdant.TideProbe

local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local api = Verdant.zenimax.api
local WINDOW_MANAGER = zui.WINDOW_MANAGER
local TOPLEFT, TOPRIGHT, BOTTOMLEFT, CENTER = zc.TOPLEFT, zc.TOPRIGHT, zc.BOTTOMLEFT, zc.CENTER
local GuiRoot, DT_HIGH, TEXT_ALIGN_RIGHT = zc.GuiRoot, zc.DT_HIGH, zc.TEXT_ALIGN_RIGHT
local math_floor, math_min, math_max = math.floor, math.min, math.max
local string_format = string.format

local W, PAD, LABEL_W = 780, 14, 150
local ROW_H, ROW_GAP, ROWS_MAX = 34, 8, 6
local HEAD_H, FOOT_H = 30, 26
local GROUP = 12
local LINE_PX = 2
local REPS = 10
local COLORS = {
  { 0.98, 0.60, 0.45 }, { 0.72, 0.94, 0.84 }, { 0.45, 0.62, 0.90 },
  { 0.75, 0.65, 0.95 }, { 0.66, 0.72, 0.69 }, { 0.95, 0.80, 0.35 },
}
local MODES = {
  { key = "poly_smooth", label = "polygon fill, smoothing on" },
  { key = "poly_plain",  label = "polygon fill, smoothing off" },
  { key = "rects",       label = "rectangle fill" },
  { key = "poly_border", label = "polygon fill and its own border" },
}

local window, info, mode_btn, mode_lbl
local mode = 1
local polys, rects, labels = { n = 0 }, { n = 0 }, { n = 0 }
local last = { controls = 0, points = 0, ms = 0, rows = 0, source = "" }

local function scale()
  local sc = api.GetUIGlobalScale and api.GetUIGlobalScale() or 1
  if not sc or sc <= 0 then sc = 1 end
  return sc
end

local function snap(v, sc)
  return math_floor(v * sc + 0.5) / sc
end

local function take(list, kind, prefix)
  list.n = list.n + 1
  local c = list[list.n]
  if not c then
    c = WINDOW_MANAGER:CreateControl(prefix .. list.n, window, kind)
    list[list.n] = c
  end
  c:SetHidden(false)
  return c
end

local function release(list)
  for i = 1, #list do list[i]:SetHidden(true) end
  list.n = 0
end

local function synthetic()
  local steps_t, steps_c = {}, {}
  local n = 0
  local t, c = 0, 0
  for k = 1, 120 do
    n = n + 1
    steps_t[n], steps_c[n] = t, c
    t = t + 400 + ((k * 37) % 9) * 120
    c = (c + ((k * 7) % 5) - 2) % (GROUP + 1)
  end
  return { name = "synthetic", n_steps = n, step_t = steps_t, step_c = steps_c }, t
end

local function source_rows()
  local BT = Verdant.BuffTracker
  local t0, t1 = BT.session_start(), BT.session_end()
  local rows = {}
  if t0 and t1 and t1 > t0 then
    for i = 1, BT.count() do
      local r = BT.get(i)
      if (r.max_conc or 0) > 1 and (r.n_steps or 0) > 1 then rows[#rows + 1] = r end
    end
    table.sort(rows, function(a, b) return (a.uptime_ms or 0) > (b.uptime_ms or 0) end)
    for k = ROWS_MAX + 1, #rows do rows[k] = nil end
  end
  if #rows > 0 then return rows, t0, t1 - t0, "the buffs of the session in the window" end
  local rec, span = synthetic()
  return { rec }, 0, span, "synthetic steps, no session in the window"
end

local function level(c)
  if c <= 0 then return 0 end
  return math_min(1, c / GROUP)
end

local function rect(x, y, w, h, col, a)
  local r = take(rects, zc.CT_TEXTURE, "VerdantTideProbeRect")
  r:ClearAnchors()
  r:SetAnchor(TOPLEFT, window, TOPLEFT, x, y)
  r:SetDimensions(math_max(w, 1), math_max(h, 1))
  r:SetColor(col[1], col[2], col[3], a)
  r:SetDrawLevel(3)
  return r
end

local function edge(rec, t0, span, x0, y0, lane_w, sc, col)
  local prev_y
  for k = 1, rec.n_steps do
    local st = rec.step_t[k]
    local en = (k < rec.n_steps) and rec.step_t[k + 1] or (t0 + span)
    local xa = snap(x0 + (st - t0) / span * lane_w, sc)
    local xb = snap(x0 + (en - t0) / span * lane_w, sc)
    local y = snap(y0 + (1 - level(rec.step_c[k])) * (ROW_H - LINE_PX), sc)
    if xb > xa then rect(xa, y, xb - xa, LINE_PX, col, 1) end
    if prev_y and prev_y ~= y then
      local top, bot = math_min(prev_y, y), math_max(prev_y, y)
      rect(xa, top, LINE_PX, bot - top + LINE_PX, col, 1)
    end
    prev_y = y
  end
end

local function draw_row(i, rec, t0, span, y0, kind)
  local col = COLORS[((i - 1) % #COLORS) + 1]
  local sc = scale()
  local x0 = PAD + LABEL_W
  local lane_w = W - x0 - PAD
  local lane = rect(x0, y0, lane_w, ROW_H, { 1, 1, 1 }, 0.04)
  lane:SetDrawLevel(1)
  local lbl = take(labels, zc.CT_LABEL, "VerdantTideProbeName")
  lbl:SetFont("ZoFontGameSmall")
  lbl:ClearAnchors()
  lbl:SetAnchor(TOPLEFT, window, TOPLEFT, PAD, y0 + 9)
  lbl:SetDimensions(LABEL_W - 8, 16)
  lbl:SetColor(0.86, 0.92, 0.88, 1)
  lbl:SetText(rec.name or tostring(rec.id))
  local points = 0
  if kind == "rects" then
    for k = 1, rec.n_steps do
      local v = level(rec.step_c[k])
      if v > 0 then
        local st = rec.step_t[k]
        local en = (k < rec.n_steps) and rec.step_t[k + 1] or (t0 + span)
        local xa = snap(x0 + (st - t0) / span * lane_w, sc)
        local xb = snap(x0 + (en - t0) / span * lane_w, sc)
        local top = snap(y0 + (1 - v) * ROW_H, sc)
        if xb > xa then rect(xa, top, xb - xa, y0 + ROW_H - top, col, 0.30) end
      end
    end
  else
    local poly = take(polys, zc.CT_POLYGON, "VerdantTideProbePoly")
    poly:ClearAnchors()
    poly:SetAnchor(TOPLEFT, window, TOPLEFT, x0, y0)
    poly:SetDimensions(lane_w, ROW_H)
    poly:ClearPoints()
    if zc.POLYGON_POINT_LAYOUT_CLOCKWISE then poly:SetPointLayout(zc.POLYGON_POINT_LAYOUT_CLOCKWISE) end
    poly:SetSmoothingEnabled(kind ~= "poly_plain")
    local px, py = 0, 1
    poly:AddPoint(0, 1)
    points = 1
    local function add(nx, ny)
      if nx ~= px or ny ~= py then
        poly:AddPoint(nx, ny)
        points = points + 1
        px, py = nx, ny
      end
    end
    for k = 1, rec.n_steps do
      local st = rec.step_t[k]
      local en = (k < rec.n_steps) and rec.step_t[k + 1] or (t0 + span)
      local ny = 1 - level(rec.step_c[k])
      add((st - t0) / span, ny)
      add((en - t0) / span, ny)
    end
    add(1, 1)
    poly:SetCenterColor(col[1], col[2], col[3], 0.30)
    if kind == "poly_border" then
      poly:SetBorderThickness(LINE_PX, LINE_PX, 1)
      poly:SetBorderColor(col[1], col[2], col[3], 1)
    else
      poly:SetBorderThickness(0, 0, 0)
    end
    poly:SetDrawLevel(2)
  end
  if kind ~= "poly_border" then edge(rec, t0, span, x0, y0, lane_w, sc, col) end
  return points
end

local function build_once(rows, t0, span, kind)
  release(polys)
  release(rects)
  release(labels)
  local points = 0
  for i, rec in ipairs(rows) do
    points = points + draw_row(i, rec, t0, span, HEAD_H + (i - 1) * (ROW_H + ROW_GAP), kind)
  end
  return points
end

local function render()
  local rows, t0, span, source = source_rows()
  local kind = MODES[mode].key
  if kind ~= "rects" and not zc.CT_POLYGON then
    info:SetText("this client has no polygon control")
    return
  end
  window:SetHeight(HEAD_H + #rows * (ROW_H + ROW_GAP) + FOOT_H)
  local clock = api.GetGameTimeMilliseconds
  local start = clock()
  local points = 0
  for _ = 1, REPS do points = build_once(rows, t0, span, kind) end
  local ms = (clock() - start) / REPS
  last.controls, last.points, last.ms, last.rows, last.source = polys.n + rects.n, points, ms, #rows, source
  mode_lbl:SetText(MODES[mode].label)
  info:SetText(string_format("%d rows of %s  ·  %d controls  ·  %d polygon points  ·  %.2f ms a build  ·  UI scale %.2f",
    #rows, source, last.controls, points, ms, scale()))
end

local function build()
  window = WINDOW_MANAGER:CreateTopLevelWindow("VerdantTideProbe")
  window:SetDimensions(W, 200)
  window:SetAnchor(CENTER, GuiRoot, CENTER, 0, -80)
  window:SetMovable(true)
  window:SetMouseEnabled(true)
  window:SetClampedToScreen(true)
  window:SetDrawTier(DT_HIGH)
  local bg = WINDOW_MANAGER:CreateControl("VerdantTideProbeBg", window, zc.CT_BACKDROP)
  bg:SetAnchorFill(window)
  bg:SetCenterColor(0.10, 0.13, 0.12, 0.96)
  bg:SetEdgeColor(0.30, 0.42, 0.34, 0.9)
  bg:SetEdgeTexture("", 1, 1, 1)
  local title = WINDOW_MANAGER:CreateControl("VerdantTideProbeTitle", window, zc.CT_LABEL)
  title:SetFont("ZoFontGameSmall")
  title:SetAnchor(TOPLEFT, window, TOPLEFT, PAD, 8)
  title:SetDimensions(220, 16)
  title:SetColor(0.75, 0.90, 0.80, 1)
  title:SetText("tide probe  ·  click the mode to change it")
  mode_btn = WINDOW_MANAGER:CreateControl("VerdantTideProbeMode", window, zc.CT_BUTTON)
  mode_btn:SetAnchor(TOPRIGHT, window, TOPRIGHT, -PAD, 6)
  mode_btn:SetDimensions(260, 20)
  zui.handler(mode_btn, "OnClicked", function() M.next_mode() end)
  mode_lbl = WINDOW_MANAGER:CreateControl("VerdantTideProbeModeLabel", mode_btn, zc.CT_LABEL)
  mode_lbl:SetFont("ZoFontGameSmall")
  mode_lbl:SetAnchorFill(mode_btn)
  mode_lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  mode_lbl:SetColor(0.95, 0.80, 0.35, 1)
  info = WINDOW_MANAGER:CreateControl("VerdantTideProbeInfo", window, zc.CT_LABEL)
  info:SetFont("ZoFontGameSmall")
  info:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, PAD, -6)
  info:SetDimensions(W - 2 * PAD, 16)
  info:SetColor(0.70, 0.78, 0.74, 1)
  window:SetHidden(true)
end

function M.toggle()
  if not window then build() end
  local show = window:IsHidden()
  window:SetHidden(not show)
  if show then render() end
end

function M.next_mode()
  mode = (mode % #MODES) + 1
  if window and not window:IsHidden() then render() end
  return MODES[mode].key
end

function M.mode() return MODES[mode].key end
function M.last() return last end
function M.is_shown() return window ~= nil and not window:IsHidden() end
