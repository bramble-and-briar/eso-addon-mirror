Vermilion = Vermilion or {}
Vermilion.FilmBands = {}
local M = Vermilion.FilmBands

local math_floor = math.floor
local math_max = math.max
local FC = Vermilion.FilmColumns
local axis_span = FC.axis_span

local RES = {}
M.RES = RES

local controls, VIS, CHIP, DTYPE_ICON, C_SHDPS, C_VIEWPORT, top_inset, ult_inset

function M.bind(t)
  controls, VIS, CHIP, DTYPE_ICON = t.controls, t.VIS, t.CHIP, t.DTYPE_ICON
  C_SHDPS, C_VIEWPORT, top_inset, ult_inset = t.C_SHDPS, t.C_VIEWPORT, t.top_inset, t.ult_inset
end

local function shield_cell(x0, x1, y, level)
  local seg = controls.pool_shield:AcquireObject()
  seg:ClearAnchors()
  seg:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x0, y)
  seg:SetWidth(math_max(1, x1 - x0))
  seg:SetHeight(VIS.shield.ROW_H)
  seg:SetDrawLevel(4)
  local col = Vermilion.Heat.lut2(level)
  seg:SetColor(col[1], col[2], col[3], Vermilion.Heat.alpha(level))
  seg:SetHidden(false)
end

function RES.y0()
  return CHIP.H + ult_inset() + (VIS.shield.on and VIS.shield.AREA or 0)
end
local function draw_shield_band_at(t0, span, x_left, bw)
  local pool = controls.pool_shield
  pool:ReleaseAllObjects()
  controls.pool_shield_icon:ReleaseAllObjects()
  local S = VIS.shield
  if not S.on or span <= 0 or bw <= 0 then return end
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if n == 0 then return end
  local Heat = Vermilion.Heat
  local y = CHIP.H + ult_inset() + S.PAD
  S.t0, S.span, S.xl, S.bw = t0, span, x_left, bw
  local track = pool:AcquireObject()
  track:ClearAnchors()
  track:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x_left, y)
  track:SetWidth(bw)
  track:SetHeight(S.ROW_H)
  track:SetDrawLevel(3)
  track:SetColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, 0.10)
  track:SetHidden(false)
  local icon = controls.pool_shield_icon:AcquireObject()
  icon:ClearAnchors()
  icon:SetTexture(DTYPE_ICON[-1])
  icon:SetDimensions(VIS.ult.ICON, VIS.ult.ICON)
  icon:SetColor(C_SHDPS.r, C_SHDPS.g, C_SHDPS.b, (S.max > 0) and 0.95 or 0.40)
  icon:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, 0, y - math_floor((VIS.ult.ICON - S.ROW_H) / 2))
  icon:SetHidden(false)
  if S.max <= 0 then return end
  local run_x0, run_x1, run_lv = nil, nil, -1
  local k0, k1 = FC.samples_in(t0, span, n)
  local x_right = x_left + bw
  for k = k0, k1 do
    local s = TB.at(k)
    local sh = s.ShDPS or 0
    local level = (sh > 0) and Heat.level(math.sqrt(sh / S.max)) or 0
    local x0 = x_left + math_floor((s.t - t0) / span * bw + 0.5)
    local nxt = TB.at(k + 1)
    local x1 = nxt and (x_left + math_floor((nxt.t - t0) / span * bw + 0.5)) or x_right
    if x1 > x_right then x1 = x_right end
    if x1 <= x0 then x1 = x0 + 1 end
    if level > 0 and run_x0 and level == run_lv and x0 <= run_x1 then
      run_x1 = x1
    else
      if run_x0 then shield_cell(run_x0, run_x1, y, run_lv) end
      if level > 0 then run_x0, run_x1, run_lv = x0, x1, level else run_x0 = nil end
    end
  end
  if run_x0 then shield_cell(run_x0, run_x1, y, run_lv) end
end

local function ult_seg(x0, x1, y, lv, avail, min_x, max_x)
  if x1 <= x0 then return min_x, max_x end
  local seg = controls.pool_ult:AcquireObject()
  seg:ClearAnchors()
  seg:SetDrawLevel(6)
  seg:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x0, y)
  seg:SetWidth(x1 - x0)
  seg:SetHeight(VIS.ult.ROW_H)
  if avail then
    seg:SetColor(VIS.ready.r, VIS.ready.g, VIS.ready.b, 0.95)
  else
    seg:SetColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, 0.10 + 0.045 * lv)
  end
  seg:SetHidden(false)
  if not min_x or x0 < min_x then min_x = x0 end
  if not max_x or x1 > max_x then max_x = x1 end
  return min_x, max_x
end

local function draw_ult_band_at(t0, span, x_left, bw, t_last)
  local pool, ipool = controls.pool_ult, controls.pool_ult_icon
  pool:ReleaseAllObjects()
  ipool:ReleaseAllObjects()
  local U = Vermilion.Ultimate
  if not (U and U.has_data()) or span <= 0 then return end
  local canvas = controls.canvas
  local nb = math_floor(bw / 4)
  if nb < 1 then return end
  local st, sv, ns = U.steps()
  local ut, ub, un = U.casts()
  local at, ab, _, ac, an = U.abilities()
  local t_hi = t0 + span
  VIS.ult.t0, VIS.ult.span, VIS.ult.xl, VIS.ult.bw = t0, span, x_left, bw
  for b = 1, 2 do
    local id = U.id_at(b, t_hi)
    if id > 0 or b == 1 then
      local y = CHIP.H + VIS.ult.PAD + (b - 1) * (VIS.ult.ROW_H + VIS.ult.GAP)
      local k, ka, cost = 1, 0, 0
      local min_x, max_x
      local run_x0, run_lv, run_avail = nil, -1, false
      for bx = 1, nb do
        local x0 = x_left + math_floor((bx - 1) * bw / nb + 0.5)
        local bt = t0 + (bx - 1) / nb * span
        while k < ns and st[k + 1] <= bt do k = k + 1 end
        while ka < an and at[ka + 1] <= bt do
          ka = ka + 1
          if ab[ka] == b then cost = ac[ka] end
        end
        local p = -1
        if bt >= st[1] and bt <= t_last then
          local c = (cost > 0) and cost or U.cost_at(b, bt)
          p = sv[k] / c
          if p > 1 then p = 1 end
        end
        if p < 0 then
          if run_x0 then
            min_x, max_x = ult_seg(run_x0, x0, y, run_lv, run_avail, min_x, max_x)
            run_x0 = nil
          end
        else
          local avail = p >= 1
          local lv = avail and 8 or math_floor(p * 8)
          if run_x0 and (avail ~= run_avail or lv ~= run_lv) then
            min_x, max_x = ult_seg(run_x0, x0, y, run_lv, run_avail, min_x, max_x)
            run_x0 = nil
          end
          if not run_x0 then run_x0, run_lv, run_avail = x0, lv, avail end
        end
      end
      if run_x0 then
        min_x, max_x = ult_seg(run_x0, x_left + bw, y, run_lv, run_avail, min_x, max_x)
      end
      if min_x then
        local rim = pool:AcquireObject()
        rim:ClearAnchors()
        rim:SetDrawLevel(5)
        rim:SetAnchor(TOPLEFT, canvas, TOPLEFT, min_x - 1, y - 1)
        rim:SetWidth(max_x - min_x + 2)
        rim:SetHeight(VIS.ult.ROW_H + 2)
        rim:SetColor(0.04, 0.02, 0.02, 0.60)
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
          tick:SetHeight(VIS.ult.ROW_H + 4)
          tick:SetColor(1, 1, 1, 0.9)
          tick:SetHidden(false)
        end
      end
      if id > 0 then
        local icon = ipool:AcquireObject()
        icon:ClearAnchors()
        icon:SetTexture(Vermilion.SkillColors.ability_icon(id))
        icon:SetDimensions(VIS.ult.ICON, VIS.ult.ICON)
        icon:SetColor(1, 1, 1, 0.95)
        icon:SetAnchor(TOPLEFT, canvas, TOPLEFT, 0, y - math_floor((VIS.ult.ICON - VIS.ult.ROW_H) / 2))
        icon:SetHidden(false)
      end
    end
  end
end

local function draw_kills_at(t0, span, x_left, bw, y)
  local pool = controls.pool_kill
  pool:ReleaseAllObjects()
  local K = Vermilion.Kills
  if not K or span <= 0 then return end
  if Vermilion.Settings and Vermilion.Settings.kill_markers and not Vermilion.Settings.kill_markers() then return end
  local n = K.count()
  if n == 0 then return end
  local canvas = controls.canvas
  local sz = VIS.kill_size
  VIS.kills_y = y
  VIS.kills_t0, VIS.kills_span, VIS.kills_xl, VIS.kills_bw = t0, span, x_left, bw
  for i = 1, n do
    local kt = K.get(i)
    if kt >= t0 and kt <= t0 + span then
      local x = x_left + math_floor((kt - t0) / span * bw + 0.5)
      local icon = pool:AcquireObject()
      icon:ClearAnchors()
      icon:SetTexture(VIS.kill_icon)
      icon:SetDimensions(sz, sz)
      icon:SetColor(1, 0.92, 0.88, 0.95)
      icon:SetAnchor(TOPLEFT, canvas, TOPLEFT, x - math_floor(sz / 2), y)
      icon:SetHidden(false)
    end
  end
end

local function dead_box(x0, x1, y0, y1)
  local box = controls.pool_dead:AcquireObject()
  box:ClearAnchors()
  box:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x0, y0)
  box:SetDimensions(x1 - x0, y1 - y0)
  box:SetColor(0.62, 0.62, 0.66, 0.17)
  box:SetHidden(false)
end

local function draw_dead(m, num_cols, cw, y0, y1)
  controls.pool_dead:ReleaseAllObjects()
  local dts, dn, dte = Vermilion.Resources.deaths()
  if dn == 0 or y1 <= y0 then return end
  local dec = FC.cols
  local d = 1
  local run_x0, run_x1 = nil, nil
  for i = 1, m do
    local col = dec[i]
    local t = col.t
    while d <= dn and dte[d] > 0 and dte[d] < t do d = d + 1 end
    local left, right = FC.rect(col.c, num_cols, cw)
    if d <= dn and t >= dts[d] then
      if not run_x0 then run_x0 = left end
      run_x1 = right
    elseif run_x0 then
      dead_box(run_x0, run_x1, y0, y1)
      run_x0 = nil
    end
  end
  if run_x0 then dead_box(run_x0, run_x1, y0, y1) end
end

local function draw_kills(span_ms, n)
  if n == 0 then controls.pool_kill:ReleaseAllObjects() return end
  local t_last = FC.view_last_t()
  local span = axis_span(span_ms)
  local x_left = VIS.ult.ICON + 4
  draw_kills_at(t_last - span, span, x_left, controls.canvas:GetWidth() - x_left, CHIP.H + top_inset() + 2)
end

function RES.cell(x0, x1, y_bottom, level, c)
  if x1 <= x0 then return end
  local h = math_floor(level * VIS.res.ROW_H + 0.5)
  if h < 1 then h = 1 end
  local seg = controls.pool_res:AcquireObject()
  seg:ClearAnchors()
  seg:SetDrawLevel(6)
  seg:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x0, y_bottom - h)
  seg:SetWidth(x1 - x0)
  seg:SetHeight(h)
  seg:SetColor(c.r, c.g, c.b, 0.92)
  seg:SetHidden(false)
end

function RES.row(p, y, t0, span, x_left, bw, key, c, letter)
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  local track = controls.pool_res:AcquireObject()
  track:ClearAnchors()
  track:SetDrawLevel(3)
  track:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x_left, y)
  track:SetWidth(bw)
  track:SetHeight(VIS.res.ROW_H)
  track:SetColor(c.r, c.g, c.b, 0.10)
  track:SetHidden(false)
  local lbl = controls.pool_res_lbl:AcquireObject()
  lbl:ClearAnchors()
  lbl:SetText(letter)
  lbl:SetColor(c.r, c.g, c.b, 0.95)
  lbl:SetDimensions(VIS.ult.ICON, VIS.res.ROW_H + 6)
  lbl:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, 0, y - 3)
  lbl:SetHidden(false)
  local y_bottom = y + VIS.res.ROW_H
  local run_x0, run_x1, run_h, run_low = nil, nil, -1, false
  local k0, k1 = FC.samples_in(t0, span, n)
  local x_right = x_left + bw
  for k = k0, k1 do
    local s = TB.at(k)
    local level = s[key] or 0
    local x0 = x_left + math_floor((s.t - t0) / span * bw + 0.5)
    local nxt = TB.at(k + 1)
    local x1 = nxt and (x_left + math_floor((nxt.t - t0) / span * bw + 0.5)) or x_right
    if x1 > x_right then x1 = x_right end
    if x1 <= x0 then x1 = x0 + 1 end
    local h = math_floor(level * VIS.res.ROW_H + 0.5)
    local is_low = level > 0 and level < 0.30
    if level > 0 and run_x0 and h == run_h and is_low == run_low and x0 <= run_x1 then
      run_x1 = x1
    else
      if run_x0 then RES.cell(run_x0, run_x1, y_bottom, run_h / VIS.res.ROW_H, run_low and VIS.low or c) end
      if level > 0 then run_x0, run_x1, run_h, run_low = x0, x1, h, is_low else run_x0 = nil end
    end
  end
  if run_x0 then RES.cell(run_x0, run_x1, y_bottom, run_h / VIS.res.ROW_H, run_low and VIS.low or c) end
end

function RES.band(t0, span, x_left, bw)
  controls.pool_res:ReleaseAllObjects()
  controls.pool_res_lbl:ReleaseAllObjects()
  local R = VIS.res
  if not R.on or span <= 0 or bw <= 0 then return end
  if Vermilion.TemporalBuffer.count() == 0 then return end
  R.t0, R.span, R.xl, R.bw = t0, span, x_left, bw
  local y = RES.y0() + R.PAD
  RES.row(1, y, t0, span, x_left, bw, "mag", VIS.mag, "M")
  RES.row(2, y + R.ROW_H + R.GAP, t0, span, x_left, bw, "sta", VIS.sta, "S")
end

local function draw_bands_at(t0, span, x_left, bw, t_last)
  draw_ult_band_at(t0, span, x_left, bw, t_last)
  draw_shield_band_at(t0, span, x_left, bw)
  RES.band(t0, span, x_left, bw)
end

local function draw_ult_band(span_ms, n)
  if n == 0 then
    controls.pool_ult:ReleaseAllObjects()
    controls.pool_ult_icon:ReleaseAllObjects()
    controls.pool_shield:ReleaseAllObjects()
    controls.pool_shield_icon:ReleaseAllObjects()
    controls.pool_res:ReleaseAllObjects()
    controls.pool_res_lbl:ReleaseAllObjects()
    return
  end
  local t_last = FC.view_last_t()
  local span = axis_span(span_ms)
  local x_left = VIS.ult.ICON + 4
  draw_bands_at(t_last - span, span, x_left, controls.canvas:GetWidth() - x_left, t_last)
end

M.draw_dead = draw_dead
M.draw_kills = draw_kills
M.draw_ult_band = draw_ult_band
M.draw_bands_at = draw_bands_at
