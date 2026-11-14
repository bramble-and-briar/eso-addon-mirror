Vermilion = Vermilion or {}
Vermilion.ChartOverlay = {}
local M = Vermilion.ChartOverlay

local zc = Vermilion.zenimax.constants
local BOTTOMLEFT, BOTTOMRIGHT = zc.BOTTOMLEFT, zc.BOTTOMRIGHT
local math_floor = math.floor
local TIME_STRIP_H = Vermilion.ChartGrid.TIME_STRIP_H
local FC = Vermilion.FilmColumns

local controls, VIS

function M.bind(t) controls, VIS = t.controls, t.VIS end

function M.scale_top(whole, with_shield)
  VIS.scale_is_local = false
  if not Vermilion.Settings.zoom_local_scale() or not Vermilion.FilmWindow.is_zoomed()
     or Vermilion.TemporalBuffer.is_recording() then return whole end
  local top = FC.visible_peak(with_shield)
  if top <= 0 then return whole end
  VIS.scale_is_local = true
  return top
end

function M.avg_line(with_shield, max_v, ch_plot)
  local line = controls.avg_line
  if not line or max_v <= 0 or not Vermilion.Settings.average_line() then return end
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if n == 0 then return end
  local value = 0
  local fight = Vermilion.Metrics.fight_ms()
  if fight > 0 then
    local dmg, shd = Vermilion.Metrics.totals()
    local ls = controls.loaded_sum
    if ls then dmg, shd = ls.total_damage or 0, ls.total_shield or 0 end
    value = (dmg + (with_shield and shd or 0)) / (fight / 1000)
  else
    for i = 1, n do
      local s = TB.at(i)
      value = value + s.eDPS + (with_shield and s.ShDPS or 0)
    end
    value = value / n
  end
  if VIS.scale_is_local and value > max_v then return end
  local h = math_floor(ch_plot * value / max_v + 0.5) + TIME_STRIP_H
  line:ClearAnchors()
  line:SetAnchor(BOTTOMLEFT, controls.canvas, BOTTOMLEFT, 0, -h)
  line:SetAnchor(BOTTOMRIGHT, controls.canvas, BOTTOMRIGHT, 0, -h)
  line:SetHidden(false)
end

function M.hide_lines()
  if controls.avg_line then controls.avg_line:SetHidden(true) end
  if controls.median_line then controls.median_line:SetHidden(true) end
end

function M.median_line(with_shield, max_v, ch_plot)
  local line = controls.median_line
  local TB = Vermilion.TemporalBuffer
  if not line or max_v <= 0 or TB.is_recording() or not Vermilion.Settings.median_line() then return end
  local value = Vermilion.FightStats.median(TB, with_shield)
  if value <= 0 or value > max_v then return end
  local h = math_floor(ch_plot * value / max_v + 0.5) + TIME_STRIP_H
  line:ClearAnchors()
  line:SetAnchor(BOTTOMLEFT, controls.canvas, BOTTOMLEFT, 0, -h)
  line:SetAnchor(BOTTOMRIGHT, controls.canvas, BOTTOMRIGHT, 0, -h)
  line:SetHidden(false)
end
