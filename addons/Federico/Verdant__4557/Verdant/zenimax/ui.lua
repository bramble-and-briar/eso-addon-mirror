
Verdant = Verdant or {}
Verdant.zenimax = Verdant.zenimax or {}
local Verdant = Verdant

Verdant.zenimax.ui = {}
local M = Verdant.zenimax.ui

M.WINDOW_MANAGER          = WINDOW_MANAGER
M.ZO_ObjectPool           = ZO_ObjectPool
M.CreateControlFromVirtual = CreateControlFromVirtual
M.ZO_AlphaAnimation       = ZO_AlphaAnimation

local zos_PlaySound = PlaySound
M.PlaySound = function(id)
  local sv = Verdant.SavedVars
  if sv and sv.settings and sv.settings.sounds == false then return end
  return zos_PlaySound(id)
end

function M.pick_color(cb, r, g, b)
  local sys = SYSTEMS
  local picker = sys and sys.GetObject and sys:GetObject("colorPicker")
  if not (picker and picker.Show) then return false end
  picker:Show(cb, r, g, b)
  return true
end

function M.handler(control, event, fn)
  if fn == nil then
    control:SetHandler(event, nil)
    return
  end
  local name = control:GetName()
  if name == nil or name == "" then name = "a control" end
  control:SetHandler(event, Verdant.zenimax.events.guard(name .. " " .. event, fn))
end

