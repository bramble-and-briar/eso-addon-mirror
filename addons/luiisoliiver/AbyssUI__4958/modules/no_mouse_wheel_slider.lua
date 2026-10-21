-- Disable mouse-wheel on LAM sliders without registering a custom LAM widget
-- or overwriting LAMCreateControl (ESOUI best practice).
-- Uses panel walk + ZO_PostHookHandler only.

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI

local NoMouseWheelSlider = {}
NAGA_UI.NoMouseWheelSlider = NoMouseWheelSlider

local LAM_SLIDER_HANDLER_NAMESPACE = "LAM2_Slider"

local function DisableMouseWheel(control)
    if not control then return end
    local slider = control.slider
    if slider then
        slider:SetHandler("OnMouseWheel", nil, LAM_SLIDER_HANDLER_NAMESPACE)
        slider:SetHandler("OnMouseWheel", nil)
    end
end

local function WalkAndDisable(control)
    if not control then return end
    if control.slider then
        DisableMouseWheel(control)
        if ZO_PostHookHandler then
            ZO_PostHookHandler(control.slider, "OnMouseEnter", function()
                DisableMouseWheel(control)
            end)
            ZO_PostHookHandler(control.slider, "OnMouseUp", function()
                zo_callLater(function() DisableMouseWheel(control) end, 0)
            end)
        end
        if control.slidervalue and ZO_PostHookHandler then
            ZO_PostHookHandler(control.slidervalue, "OnFocusGained", function()
                DisableMouseWheel(control)
            end)
            ZO_PostHookHandler(control.slidervalue, "OnFocusLost", function()
                DisableMouseWheel(control)
            end)
        end
    end
    local n = control.GetNumChildren and control:GetNumChildren()
    if n then
        for i = 1, n do
            WalkAndDisable(control:GetChild(i))
        end
    end
end

--- Call after LAM panel is created / refreshed. Safe to call multiple times.
function NoMouseWheelSlider:ApplyToPanel(panel)
    if not panel then return end
    local root = panel.panel or panel
    if not root then return end
    WalkAndDisable(root)
end

--- Does NOT register a custom LAM widget and does NOT touch LAMCreateControl.
function NoMouseWheelSlider:Register(LAM)
    if not LAM then return false end
    if self._registered then return true end
    self._registered = true
    return true
end

--- No-op kept for settings.lua compatibility (option.type stays "slider").
function NoMouseWheelSlider:UseForSliderOptions(options)
    -- Intentionally empty.
end
