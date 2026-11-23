Verdant = Verdant or {}
local Verdant = Verdant

Verdant.FilmWindow = {}
local M = Verdant.FilmWindow

local math_floor = math.floor
local math_max   = math.max

local MIN_SPAN = 15
local ZOOM_IN, ZOOM_OUT = 0.8, 1.25
local PAN_FRACTION = 0.1

local view_len = nil
local view_first = 1

local function clamp_first(first, len, n)
  local top = n - len + 1
  if first > top then first = top end
  if first < 1 then first = 1 end
  return first
end

function M.reset()
  local changed = view_len ~= nil
  view_len, view_first = nil, 1
  return changed
end

function M.is_zoomed() return view_len ~= nil end

function M.range(n, recording, live, zoomable)
  if recording then return math_max(1, n - live + 1), live end
  if zoomable and view_len and view_len < n then
    view_first = clamp_first(view_first, view_len, n)
    return view_first, view_len
  end
  return 1, n
end

function M.zoom(dir, frac, n)
  local cur = (view_len and view_len < n) and view_len or n
  local first = (cur < n) and view_first or 1
  local want
  if dir > 0 then
    want = math_floor(cur * ZOOM_OUT)
  else
    want = math_floor(cur * ZOOM_IN)
  end
  if want < MIN_SPAN then want = MIN_SPAN end
  if want >= n then return M.reset() end
  if want == cur then return false end
  local anchor = first + frac * cur
  view_len = want
  view_first = math_floor(anchor - frac * want + 0.5)
  return true
end

function M.pan(dir, n)
  if not view_len or view_len >= n then return false end
  local step = math_floor(view_len * PAN_FRACTION)
  local first = clamp_first(view_first + dir * step, view_len, n)
  if first == view_first then return false end
  view_first = first
  return true
end

function M.drag_edge(edge, frac, n)
  local zoomed = view_len and view_len < n
  local first = zoomed and view_first or 1
  local last = zoomed and (view_first + view_len - 1) or n
  local at = math_floor(frac * n + 0.5)
  if edge < 0 then
    first = at + 1
    if first > last - MIN_SPAN + 1 then first = last - MIN_SPAN + 1 end
  else
    last = at
    if last < first + MIN_SPAN - 1 then last = first + MIN_SPAN - 1 end
  end
  local len = last - first + 1
  if len >= n then return M.reset() end
  if zoomed and first == view_first and len == view_len then return false end
  view_first, view_len = first, len
  return true
end

function M.grab(n)
  if not view_len or view_len >= n then return nil end
  return clamp_first(view_first, view_len, n), view_len
end

function M.move_to(first, n)
  if not view_len or view_len >= n then return false end
  first = clamp_first(first, view_len, n)
  if first == view_first then return false end
  view_first = first
  return true
end

function M.center_on(frac, n)
  if not view_len or view_len >= n then return false end
  local first = clamp_first(math_floor(frac * n - view_len / 2 + 0.5) + 1, view_len, n)
  if first == view_first then return false end
  view_first = first
  return true
end
