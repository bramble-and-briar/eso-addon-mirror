Verdant = Verdant or {}
local Verdant = Verdant

Verdant.FightStats = {}
local M = Verdant.FightStats

local math_floor = math.floor
local table_sort = table.sort

local WINDOW_MS   = Verdant.Constants.METRICS.WINDOW_MS
local MIN_WINDOWS = 6

local out = { n = 0, p10 = 0, p50 = 0, p90 = 0 }
local dead = { ms = 0, count = 0, length = 0 }
local values = {}

local function at(sorted, n, p)
  local k = (n - 1) * p + 1
  local i = math_floor(k)
  local j = (i < n) and (i + 1) or n
  return sorted[i] + (sorted[j] - sorted[i]) * (k - i)
end

function M.compute(TB)
  out.n, out.p10, out.p50, out.p90 = 0, 0, 0, 0
  local count = TB.count()
  if count == 0 then return out end
  local from = TB.at(1).t - TB.period() + WINDOW_MS
  local starts, spans, ends = TB.dead_spans()
  local d, n = 1, 0
  for i = 1, count do
    local s = TB.at(i)
    local t = s.t
    if t >= from then
      while d <= spans and ends[d] > 0 and ends[d] < t do d = d + 1 end
      if not (d <= spans and t >= starts[d]) then
        n = n + 1
        values[n] = s.eHPS + s.MPS
      end
    end
  end
  for i = #values, n + 1, -1 do values[i] = nil end
  if n < MIN_WINDOWS then return out end
  table_sort(values)
  out.n = n
  out.p10, out.p50, out.p90 = at(values, n, 0.1), at(values, n, 0.5), at(values, n, 0.9)
  return out
end

function M.dead(TB)
  dead.ms, dead.count, dead.length = 0, 0, 0
  local count = TB.count()
  if count == 0 then return dead end
  local first, last = TB.at(1).t - TB.period(), TB.at(count).t
  dead.length = last - first
  local starts, spans, ends = TB.dead_spans()
  for d = 1, spans do
    local a = starts[d]
    local b = (ends[d] > 0) and ends[d] or last
    if a < first then a = first end
    if b > last then b = last end
    if b > a then
      dead.ms = dead.ms + (b - a)
      dead.count = dead.count + 1
    end
  end
  return dead
end

function M.alive_average(avg, d)
  if d.ms <= 0 or d.ms >= d.length then return nil end
  return avg * d.length / (d.length - d.ms)
end
