Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ChartGrid = {}
local M = Verdant.ChartGrid

local api  = Verdant.zenimax.api
local zui  = Verdant.zenimax.ui
local zc   = Verdant.zenimax.constants
local WINDOW_MANAGER    = zui.WINDOW_MANAGER
local GetString         = api.GetString
local math_max          = math.max
local math_floor        = math.floor
local TOPLEFT           = zc.TOPLEFT
local BOTTOMLEFT        = zc.BOTTOMLEFT
local BOTTOM            = zc.BOTTOM
local BOTTOMRIGHT       = zc.BOTTOMRIGHT
local CT_TEXTURE        = zc.CT_TEXTURE
local CT_LABEL          = zc.CT_LABEL
local TEXT_ALIGN_LEFT   = zc.TEXT_ALIGN_LEFT
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local TEXT_ALIGN_RIGHT  = zc.TEXT_ALIGN_RIGHT
local TEXT_ALIGN_BOTTOM = zc.TEXT_ALIGN_BOTTOM

local FILL_TEXTURE = Verdant.ChartPools.FILL_TEXTURE
local fmt_val      = Verdant.Format.value
local fmt_secs     = Verdant.Format.secs

local N_HGRID      = 3
local N_VGRID      = 3
local TIME_STRIP_H = 18
local C_GRID_LINE = { r = 0.55, g = 0.58, b = 0.70, a = 0.25 }
local C_GRID_LBL  = { r = 0.82, g = 0.85, b = 0.90, a = 0.92 }
local C_TIME_LBL  = { r = 0.68, g = 0.70, b = 0.75, a = 0.85 }

local controls

function M.bind(shared)
  controls = shared.controls
end

local function create_grid(prefix, parent_ctrl)
  local WM  = WINDOW_MANAGER
  local obj = { hlines = {}, vlines = {}, ylabels = {} }

  for i = 1, N_HGRID do
    local gl = WM:CreateControl(prefix .. "H" .. i, parent_ctrl, CT_TEXTURE)
    gl:SetTexture(FILL_TEXTURE)
    gl:SetTextureCoords(0, 1, 0, 0.05)
    gl:SetHeight(1)
    gl:SetColor(C_GRID_LINE.r, C_GRID_LINE.g, C_GRID_LINE.b, C_GRID_LINE.a)
    gl:SetHidden(true)
    obj.hlines[i] = gl

    local lbl = WM:CreateControl(prefix .. "YL" .. i, parent_ctrl, CT_LABEL)
    lbl:SetFont("ZoFontGameSmall")
    lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    lbl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    lbl:SetColor(C_GRID_LBL.r, C_GRID_LBL.g, C_GRID_LBL.b, C_GRID_LBL.a)
    lbl:SetDimensions(54, 10)
    lbl:SetHidden(true)
    obj.ylabels[i] = lbl
  end

  for i = 1, N_VGRID do
    local vl = WM:CreateControl(prefix .. "V" .. i, parent_ctrl, CT_TEXTURE)
    vl:SetTexture(FILL_TEXTURE)
    vl:SetTextureCoords(0, 1, 0, 0.05)
    vl:SetWidth(1)
    vl:SetColor(C_GRID_LINE.r, C_GRID_LINE.g, C_GRID_LINE.b, C_GRID_LINE.a)
    vl:SetHidden(true)
    obj.vlines[i] = vl
  end

  local ymax = WM:CreateControl(prefix .. "YMax", parent_ctrl, CT_LABEL)
  ymax:SetFont("ZoFontGameSmall")
  ymax:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  ymax:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
  ymax:SetColor(C_GRID_LBL.r, C_GRID_LBL.g, C_GRID_LBL.b, C_GRID_LBL.a)
  ymax:SetDimensions(54, 10)
  ymax:SetHidden(true)
  obj.ymax = ymax

  local function make_time_lbl(name, align)
    local t = WM:CreateControl(name, parent_ctrl, CT_LABEL)
    t:SetFont("ZoFontGameSmall")
    t:SetHorizontalAlignment(align)
    t:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    t:SetColor(C_TIME_LBL.r, C_TIME_LBL.g, C_TIME_LBL.b, C_TIME_LBL.a)
    t:SetDimensions(44, 10)
    t:SetHidden(true)
    return t
  end
  obj.time_l = make_time_lbl(prefix .. "TL", TEXT_ALIGN_LEFT)
  obj.time_m = make_time_lbl(prefix .. "TM", TEXT_ALIGN_CENTER)
  obj.time_r = make_time_lbl(prefix .. "TR", TEXT_ALIGN_RIGHT)

  return obj
end

local function hide_grid(grid)
  for i = 1, N_HGRID do
    grid.hlines[i]:SetHidden(true)
    grid.ylabels[i]:SetHidden(true)
  end
  for i = 1, N_VGRID do
    grid.vlines[i]:SetHidden(true)
  end
  grid.time_l:SetHidden(true)
  grid.time_m:SetHidden(true)
  grid.time_r:SetHidden(true)
  grid.ymax:SetHidden(true)
end

local function draw_grid(grid, canvas, max_val, span_ms, lookback, top_inset, from_ms, floor)
  lookback = lookback and Verdant.TemporalBuffer.is_recording()
  local from = from_ms or 0
  local cw = canvas:GetWidth()
  local ch = canvas:GetHeight()
  if cw <= 0 or ch <= 0 then
    hide_grid(grid)
    return
  end

  local has_y    = (max_val > 0)
  local has_time = (span_ms > 0)
  if not has_y and not has_time then
    hide_grid(grid)
    return
  end

  local time_h   = has_time and TIME_STRIP_H or 0
  local y_base   = floor or time_h
  local ch_plot  = math_max(1, ch - y_base - (top_inset or 0))

  if has_y then
    for i = 1, N_HGRID do
      local frac = i / (N_HGRID + 1)
      local y    = y_base + math_floor(ch_plot * frac)

      local gl = grid.hlines[i]
      gl:ClearAnchors()
      gl:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT,  0, -y)
      gl:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMRIGHT, 0, -y)
      gl:SetHidden(false)

      local lbl = grid.ylabels[i]
      lbl:ClearAnchors()
      lbl:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, 2, -(y + 1))
      lbl:SetText(fmt_val(max_val * frac))
      local spacing = ch_plot / (N_HGRID + 1)
      lbl:SetHidden(spacing < 14 and (spacing * 2 < 14 or i ~= 2))
    end
    if ch_plot >= 96 then
      local ymax_y = y_base + ch_plot - 12
      grid.ymax:ClearAnchors()
      grid.ymax:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, 2, -ymax_y)
      grid.ymax:SetText(fmt_val(max_val))
      grid.ymax:SetHidden(false)
    else
      grid.ymax:SetHidden(true)
    end
  else
    for i = 1, N_HGRID do
      grid.hlines[i]:SetHidden(true)
      grid.ylabels[i]:SetHidden(true)
    end
    grid.ymax:SetHidden(true)
  end

  for i = 1, N_VGRID do
    local vl = grid.vlines[i]
    if has_time or not floor then
      local x = math_floor(cw * i / (N_VGRID + 1))
      vl:ClearAnchors()
      vl:SetAnchor(TOPLEFT,    canvas, TOPLEFT,    x, 0)
      vl:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -time_h)
      vl:SetHidden(false)
    else
      vl:SetHidden(true)
    end
  end

  if has_time then
    grid.time_l:ClearAnchors()
    grid.time_l:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT,  2, 0)
    grid.time_l:SetText(lookback and ("-" .. fmt_secs(span_ms)) or fmt_secs(from))
    grid.time_l:SetHidden(false)

    grid.time_m:ClearAnchors()
    grid.time_m:SetAnchor(BOTTOM, canvas, BOTTOM, 0, 0)
    grid.time_m:SetText(lookback and ("-" .. fmt_secs(span_ms / 2)) or fmt_secs(from + span_ms / 2))
    grid.time_m:SetHidden(false)

    grid.time_r:ClearAnchors()
    grid.time_r:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMRIGHT, -2, 0)
    grid.time_r:SetText(lookback and GetString(VERDANT_GRAPH_NOW) or fmt_secs(from + span_ms))
    grid.time_r:SetHidden(false)
  else
    grid.time_l:SetHidden(true)
    grid.time_m:SetHidden(true)
    grid.time_r:SetHidden(true)
  end
end

local function hide_all_grids()
  hide_grid(controls.grid_ems)
  hide_grid(controls.grid_skill)
end

M.TIME_STRIP_H = TIME_STRIP_H
M.create       = create_grid
M.hide         = hide_grid
M.draw         = draw_grid
M.hide_all     = hide_all_grids
