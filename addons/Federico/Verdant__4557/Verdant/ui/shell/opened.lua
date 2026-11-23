Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Opened = {}
local M = Verdant.Opened

local GetString     = Verdant.zenimax.api.GetString
local string_format = string.format
local Sound         = Verdant.Sound

local SEP = "  ·  "

local controls, load_session

function M.bind(t)
  controls, load_session = t.controls, t.load_session
end

function M.index()
  local sess = controls.loaded_sess
  local SS = Verdant.SessionStore
  for i = 1, SS.count() do
    if SS.get(i) == sess then return i end
  end
  return nil
end

function M.step(dir)
  if not controls.window or controls.window:IsHidden() then return false end
  local SS = Verdant.SessionStore
  local n = SS.count()
  if Verdant.TemporalBuffer.is_recording() then
    Sound.play("deny")
    return false
  end
  local at = M.index()
  local target = n
  if at then target = at + ((dir and dir < 0) and -1 or 1) end
  if target < 1 or target > n then
    Sound.play("deny")
    return false
  end
  if not load_session(SS.get(target)) then return false end
  Sound.play("page")
  return true
end

function M.refresh_status()
  local sess = controls.loaded_sess
  if not sess then return end
  local head = sess.head
  local zone = head.zone or "?"
  local name = Verdant.SessionStore.title(head)
  local title = (name ~= zone) and (name .. SEP .. zone) or zone
  local status = string_format(GetString(VERDANT_LIB_LOADED), title)
  local at = M.index()
  if at then status = string_format("%s%s%d/%d", status, SEP, at, Verdant.SessionStore.count()) end
  controls.status:SetText(status)
  controls.status:SetColor(0.65, 0.65, 0.65, 1)
end
