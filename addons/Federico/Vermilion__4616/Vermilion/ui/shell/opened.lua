Vermilion = Vermilion or {}
Vermilion.Opened = {}
local M = Vermilion.Opened

local GetString     = Vermilion.zenimax.api.GetString
local string_format = string.format
local Sound         = Vermilion.Sound

local controls

function M.bind(t)
  controls = t.controls
  M.load_session = t.load_session
end

function M.step_session(dir)
  if not controls.window or controls.window:IsHidden() then return false end
  local SS = Vermilion.SessionStore
  local n = SS.count()
  if n == 0 or Vermilion.TemporalBuffer.is_recording() then
    Sound.play("deny")
    return false
  end
  local idx = M.loaded_session_index()
  local target
  if not idx then target = n
  elseif dir and dir < 0 then target = idx - 1
  else target = idx + 1 end
  if target < 1 or target > n then
    Sound.play("deny")
    return false
  end
  local sess = SS.get(target)
  if sess and M.load_session(sess) then
    Sound.play("page")
    return true
  end
  return false
end

function M.loaded_session_index()
  local sess = controls.loaded_sess
  if not sess then return nil end
  local SS = Vermilion.SessionStore
  for i = 1, SS.count() do
    if SS.get(i) == sess then return i end
  end
  return nil
end

function M.refresh_loaded_status()
  local sess = controls.loaded_sess
  if not sess or Vermilion.TemporalBuffer.is_recording() then return end
  local SS = Vermilion.SessionStore
  local title = SS.title(sess.head)
  local zone_name = sess.head.zone
  local status = string_format(GetString(VERMILION_LIB_LOADED), (zone_name and zone_name ~= title) and (title .. "  ·  " .. zone_name) or title)
  local idx = M.loaded_session_index()
  if idx then status = string_format("%s  ·  %d/%d", status, idx, SS.count()) end
  controls.status:SetText(status)
  controls.status:SetColor(0.65, 0.65, 0.65, 1)
end
