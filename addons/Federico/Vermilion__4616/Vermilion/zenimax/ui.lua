
Vermilion = Vermilion or {}
Vermilion.zenimax = Vermilion.zenimax or {}
local Vermilion = Vermilion

Vermilion.zenimax.ui = {}
local M = Vermilion.zenimax.ui

M.WINDOW_MANAGER          = WINDOW_MANAGER
M.ZO_ObjectPool           = ZO_ObjectPool
M.CreateControlFromVirtual = CreateControlFromVirtual

local zos_PlaySound = PlaySound
M.PlaySound = function(id)
  local sv = Vermilion.SavedVars
  if sv and sv.settings and sv.settings.sounds == false then return end
  return zos_PlaySound(id)
end

function M.tooltip(control, string_id, side, on_enter, on_exit)
  control:SetHandler("OnMouseEnter", function(self)
    ZO_Tooltips_ShowTextTooltip(self, side or BOTTOM, GetString(string_id))
    if on_enter then on_enter() end
  end)
  control:SetHandler("OnMouseExit", function()
    ZO_Tooltips_HideTextTooltip()
    if on_exit then on_exit() end
  end)
end
