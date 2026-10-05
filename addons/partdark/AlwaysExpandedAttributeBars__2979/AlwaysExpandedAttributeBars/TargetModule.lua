-- AEAB Module: Target Attribute Bars Resizer
-- Resizes the target unit frame attribute bars to a fixed size.
-- Managed from the Always Expanded Attribute Bars settings menu
-- (disabled by default).

local AEAB = AEAB or {}
AEAB.name = "AlwaysExpandedAttributeBars"

local ApplyTemplate = ApplyTemplateToControl

AEAB.modules = AEAB.modules or {}

local module = {}

function module.IsEnabled()
    return AEAB.savedVars ~= nil and AEAB.savedVars.enableTargetBarsResizer == true
end

-- Apply the fixed-size template to the target unit frame.
-- Safe to call any time; does nothing when the module is disabled.
function module.Apply()
    if not module.IsEnabled() then return end

    local ok, err = pcall(function()
        -- Hide the reticle brackets around the target frame
        if ZO_TargetUnitFramereticleoverRightBracket then
            ZO_TargetUnitFramereticleoverRightBracket:SetParent(GuiRoot)
        end
        if ZO_TargetUnitFramereticleoverLeftBracket then
            ZO_TargetUnitFramereticleoverLeftBracket:SetParent(GuiRoot)
        end

        -- Apply the fixed-size template to the target unit frame
        if ZO_TargetUnitFramereticleover then
            ApplyTemplate(ZO_TargetUnitFramereticleover, 'AEAB_TargetUnitFrame')
        end
    end)
    if not ok then
        d("[AEAB] Target bars module error: " .. tostring(err))
    end
end

----------------------------------------------------------
-- Target power shield overlay
----------------------------------------------------------

SecurePostHook(ZO_UnitVisualizer_PowerShieldModule, 'ShowOverlay', function(_, _, info)
    if not module.IsEnabled() then return end
    if not (info and info.overlayControls and info.overlayControls[1]) then return end

    local name = info.overlayControls[1]:GetName()
    if not (name and string.find(name, "Target", 1, true)) then return end

    ApplyTemplate(info.overlayControls[1], 'AEAB_TargetPowerShieldBar')
    if info.overlayControls[2] then
        ApplyTemplate(info.overlayControls[2], 'AEAB_TargetPowerShieldBar')
    end
end)

----------------------------------------------------------
-- Apply on unit frame creation and on every player activation
----------------------------------------------------------

CALLBACK_MANAGER:RegisterCallback('UnitFramesCreated', module.Apply)

EVENT_MANAGER:RegisterForEvent(AEAB.name .. "_TargetModule_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
    zo_callLater(module.Apply, 1000)
end)

AEAB.modules.targetBarsResizer = module