Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ChartOverlay = {}
local M = Verdant.ChartOverlay

local zc = Verdant.zenimax.constants
local TOPLEFT, BOTTOMLEFT, BOTTOMRIGHT = zc.TOPLEFT, zc.BOTTOMLEFT, zc.BOTTOMRIGHT
local math_floor = math.floor
local TIME_STRIP_H = Verdant.ChartGrid.TIME_STRIP_H

local C_MARK_DEATH = { r = 0.92, g = 0.88, b = 0.84, a = 0.50 }
local C_MARK_RES   = { r = 0.45, g = 1.00, b = 0.62, a = 0.50 }
local TEX_SKULL    = "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds"
local TEX_RES      = "EsoUI/Art/Notifications/notificationIcon_resurrect.dds"
local MARK_ICON_SZ = 11
local MARK_ICON_Y  = 4

local controls, ULT_L, C_ULT_READY, C_VIEWPORT

function M.bind(shared)
  controls, ULT_L = shared.controls, shared.ULT_L
  C_ULT_READY, C_VIEWPORT = shared.C_ULT_READY, shared.C_VIEWPORT
end

local function draw_markers(pool_icon, canvas, t0, span, lane_x, lane_w)
  if span <= 0 or not Verdant.Settings.group_deaths() then return end
  local ms, n = Verdant.TemporalBuffer.markers()
  for i = 1, n do
    local m = ms[i]
    if m.who and m.t >= t0 and m.t <= t0 + span then
      local x = lane_x + math_floor((m.t - t0) / span * lane_w + 0.5)
      local c = m.death and C_MARK_DEATH or C_MARK_RES
      local ic = pool_icon:AcquireObject()
      ic:ClearAnchors()
      ic:SetTexture(m.death and TEX_SKULL or TEX_RES)
      ic:SetDimensions(MARK_ICON_SZ, MARK_ICON_SZ)
      ic:SetAnchor(TOPLEFT, canvas, TOPLEFT, x - math_floor(MARK_ICON_SZ / 2), MARK_ICON_Y)
      ic:SetColor(c.r, c.g, c.b, c.a)
      ic:SetHidden(false)
    end
  end
end

local function ult_seg(pool, canvas, x0, x1, y, lv, avail, min_x, max_x)
  if x1 <= x0 then return min_x, max_x end
  local seg = pool:AcquireObject()
  seg:ClearAnchors()
  seg:SetDrawLevel(6)
  seg:SetAnchor(TOPLEFT, canvas, TOPLEFT, x0, y)
  seg:SetWidth(x1 - x0)
  seg:SetHeight(ULT_L.ROW_H)
  if avail then
    seg:SetColor(C_ULT_READY.r, C_ULT_READY.g, C_ULT_READY.b, 0.95)
  else
    seg:SetColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, 0.10 + 0.045 * lv)
  end
  seg:SetHidden(false)
  if not min_x or x0 < min_x then min_x = x0 end
  if not max_x or x1 > max_x then max_x = x1 end
  return min_x, max_x
end

local function draw_ult_band(pool, ipool, canvas, t0, span, t_data_hi)
  pool:ReleaseAllObjects()
  ipool:ReleaseAllObjects()
  if span <= 0 then return end
  local U = Verdant.Ultimate
  if not U.has_data() then return end
  local cw = canvas:GetWidth()
  local x_left = ULT_L.ICON + 4
  local bw = cw - x_left
  local nb = math_floor(bw / 4)
  if nb < 1 then return end
  local st, sv, n = U.steps()
  local ut, ub, un = U.used()
  local at, ab, ai, ac, an = U.abilities()
  local t_hi = t0 + span
  ULT_L.t0, ULT_L.span, ULT_L.xl, ULT_L.bw = t0, span, x_left, bw
  for b = 1, 2 do
    local id = U.id_at(b, t_hi)
    if id > 0 or b == 1 then
      local y = ULT_L.CHIP + ULT_L.PAD + (b - 1) * (ULT_L.ROW_H + ULT_L.GAP)
      local k, ka, cost = 1, 0, 0
      local min_x, max_x
      local run_x0, run_lv, run_avail = nil, -1, false
      for bx = 1, nb do
        local x0 = x_left + math_floor((bx - 1) * bw / nb + 0.5)
        local bt = t0 + (bx - 1) / nb * span
        while k < n and st[k + 1] <= bt do k = k + 1 end
        while ka < an and at[ka + 1] <= bt do
          ka = ka + 1
          if ab[ka] == b then cost = ac[ka] end
        end
        local p = -1
        if bt >= st[1] and bt <= t_data_hi then
          local c = (cost > 0) and cost or U.cost_at(b, bt)
          p = sv[k] / c
          if p > 1 then p = 1 end
        end
        if p < 0 then
          if run_x0 then
            min_x, max_x = ult_seg(pool, canvas, run_x0, x0, y, run_lv, run_avail, min_x, max_x)
            run_x0 = nil
          end
        else
          local avail = p >= 1
          local lv = avail and 8 or math_floor(p * 8)
          if run_x0 and (avail ~= run_avail or lv ~= run_lv) then
            min_x, max_x = ult_seg(pool, canvas, run_x0, x0, y, run_lv, run_avail, min_x, max_x)
            run_x0 = nil
          end
          if not run_x0 then run_x0, run_lv, run_avail = x0, lv, avail end
        end
      end
      if run_x0 then
        min_x, max_x = ult_seg(pool, canvas, run_x0, cw, y, run_lv, run_avail, min_x, max_x)
      end
      if min_x then
        local rim = pool:AcquireObject()
        rim:ClearAnchors()
        rim:SetDrawLevel(5)
        rim:SetAnchor(TOPLEFT, canvas, TOPLEFT, min_x - 1, y - 1)
        rim:SetWidth(max_x - min_x + 2)
        rim:SetHeight(ULT_L.ROW_H + 2)
        rim:SetColor(0.04, 0.04, 0.035, 0.60)
        rim:SetHidden(false)
      end
      for i = 1, un do
        local t = ut[i]
        if (ub[i] or 1) == b and t >= t0 and t <= t_hi then
          local x = x_left + math_floor((t - t0) / span * bw + 0.5)
          local tick = pool:AcquireObject()
          tick:ClearAnchors()
          tick:SetDrawLevel(7)
          tick:SetAnchor(TOPLEFT, canvas, TOPLEFT, x - 1, y - 2)
          tick:SetWidth(2)
          tick:SetHeight(ULT_L.ROW_H + 4)
          tick:SetColor(1, 1, 1, 0.9)
          tick:SetHidden(false)
        end
      end
      if id > 0 then
        local icon = ipool:AcquireObject()
        icon:ClearAnchors()
        icon:SetTexture(Verdant.SkillColors.ability_icon(id))
        icon:SetDimensions(ULT_L.ICON, ULT_L.ICON)
        icon:SetColor(1, 1, 1, 0.95)
        icon:SetAnchor(TOPLEFT, canvas, TOPLEFT, 0, y - math_floor((ULT_L.ICON - ULT_L.ROW_H) / 2))
        icon:SetHidden(false)
      end
    end
  end
end

M.C_DEATH, M.C_RES = C_MARK_DEATH, C_MARK_RES
M.TEX_SKULL, M.TEX_RES = TEX_SKULL, TEX_RES
M.ICON = MARK_ICON_SZ
local function place_line(line, value, max_v, ch_plot)
  if value <= 0 or value > max_v then return end
  local h = math_floor(ch_plot * value / max_v + 0.5) + TIME_STRIP_H
  line:ClearAnchors()
  line:SetAnchor(BOTTOMLEFT, controls.canvas, BOTTOMLEFT, 0, -h)
  line:SetAnchor(BOTTOMRIGHT, controls.canvas, BOTTOMRIGHT, 0, -h)
  line:SetHidden(false)
end

local function hide_lines()
  controls.avg_line:SetHidden(true)
  controls.median_line:SetHidden(true)
end

local function level_lines(max_v, ch_plot)
  local S, TB = Verdant.Settings, Verdant.TemporalBuffer
  if S.average_line() then place_line(controls.avg_line, TB.summary().avg_ems, max_v, ch_plot) end
  if S.median_line() and not TB.is_recording() then
    place_line(controls.median_line, Verdant.FightStats.compute(TB).p50, max_v, ch_plot)
  end
end

M.markers  = draw_markers
M.ult_band = draw_ult_band
M.hide_lines, M.level_lines = hide_lines, level_lines
