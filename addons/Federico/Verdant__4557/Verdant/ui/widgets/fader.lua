Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Fader = {}
local M = Verdant.Fader

local ZO_AlphaAnimation = Verdant.zenimax.ui.ZO_AlphaAnimation

local FADE_MS = 120

local function make_fader(control)
  return { anim = ZO_AlphaAnimation:New(control), control = control, visible = false }
end
local function fade_in(f)
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
local function fade_out(f)
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

M.new  = make_fader
M.show = fade_in
M.hide = fade_out
