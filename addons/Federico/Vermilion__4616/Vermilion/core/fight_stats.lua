Vermilion = Vermilion or {}
Vermilion.FightStats = {}
local M = Vermilion.FightStats

local math_floor = math.floor
local table_sort = table.sort

local MIN_WINDOWS = 6

local out = { n = 0, p10 = 0, p50 = 0, p90 = 0 }
local values = {}
local median_all, median_damage = { n = -1 }, { n = -1 }

local function at(sorted, n, p)
  local k = (n - 1) * p + 1
  local i = math_floor(k)
  local j = (i < n) and (i + 1) or n
  return sorted[i] + (sorted[j] - sorted[i]) * (k - i)
end

local function collect(TB, with_shield)
  local Me = Vermilion.Metrics
  local lo, hi = Me.fight_bounds()
  if not lo then return 0 end
  local from = lo + Me.window_seconds() * 1000
  local dts, dn, dte = Vermilion.Resources.deaths()
  local d, n = 1, 0
  for i = 1, TB.count() do
    local s = TB.at(i)
    local t = s.t
    if t >= from and t <= hi then
      while d <= dn and dte[d] > 0 and dte[d] < t do d = d + 1 end
      if not (d <= dn and t >= dts[d]) then
        n = n + 1
        values[n] = with_shield and (s.eDPS + s.ShDPS) or s.eDPS
      end
    end
  end
  for i = #values, n + 1, -1 do values[i] = nil end
  if n >= MIN_WINDOWS then table_sort(values) end
  return n
end

function M.compute(TB)
  out.n, out.p10, out.p50, out.p90 = 0, 0, 0, 0
  local n = collect(TB, true)
  if n < MIN_WINDOWS then return out end
  out.n = n
  out.p10, out.p50, out.p90 = at(values, n, 0.1), at(values, n, 0.5), at(values, n, 0.9)
  return out
end

function M.median(TB, with_shield)
  local count = TB.count()
  if count == 0 then return 0 end
  local Me = Vermilion.Metrics
  local lo = Me.fight_bounds()
  local fight, last = Me.fight_ms(), TB.at(count).t
  local c = with_shield and median_all or median_damage
  if c.n == count and c.last == last and c.fight == fight and c.lo == lo then return c.value end
  local n = collect(TB, with_shield)
  c.n, c.last, c.fight, c.lo = count, last, fight, lo
  c.value = (n >= MIN_WINDOWS) and at(values, n, 0.5) or 0
  return c.value
end
