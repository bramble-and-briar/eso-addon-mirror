-- Native timed-activity rows are selected before tracked/claimable icons are added.
-- Fit the final title to a fixed one-line region; retain native list heights and anchors.
local R = ESO_ARABIC_TEXT
local function FitChallengeTitle(_, control)
    if not R or not R.IsActive() or not IsInGamepadPreferredMode() then return end
    local label = control and control.nameLabel
    if not label then return end
    label:SetMaxLineCount(1)
    local refresh = R.BindLabel(label, function(current)
        return { single = true, flow = false, autoWidth = false,
            width = current:GetWidth(), height = 50,
            size = 34, minimum = 18, align = TEXT_ALIGN_RIGHT,
            reflowVisual = true }
    end)
    if refresh then refresh() end
end
if ZO_TimedActivitiesList_Gamepad and SecurePostHook then
    SecurePostHook(ZO_TimedActivitiesList_Gamepad, "SetupActivityRow", FitChallengeTitle)
end
