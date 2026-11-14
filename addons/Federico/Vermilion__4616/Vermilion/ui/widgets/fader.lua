Vermilion = Vermilion or {}
Vermilion.Fader = {}
local M = Vermilion.Fader

local FADE_MS = 120
function M.new(control)
  return { anim = ZO_AlphaAnimation:New(control), control = control, visible = false }
end
function M.show(f)
  if not f or f.visible then return end
  f.visible = true
  local control = f.control
  if control:GetAlpha() >= 0.99 then
    f.anim:Stop()
    control:SetAlpha(1)
    control:SetHidden(false)
  else
    f.anim:FadeIn(0, FADE_MS)
  end
end
function M.hide(f)
  if not f or not f.visible then return end
  f.visible = false
  local control = f.control
  if control:GetAlpha() <= 0.01 then
    f.anim:Stop()
    control:SetAlpha(0)
    control:SetHidden(true)
  else
    f.anim:FadeOut(0, FADE_MS, nil, function() if not f.visible then control:SetHidden(true) end end)
  end
end
