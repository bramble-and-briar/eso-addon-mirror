------------------------------------------------------------
-- No Target Frame
-- by j.hhh
-- Console release 1.1.0
--
-- Hides the vanilla reticle target frame only.
-- Does not modify attributes, boss bar, compass, nameplates,
-- group frames, positions or anchors.
------------------------------------------------------------

local ADDON_NAME = "NoTargetFrame"

local defaults = {
    enabled = true,
}

local settings = nil

local function IsEnabled()
    return settings and settings.enabled == true
end

local function RegisterSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    local panelName = ADDON_NAME .. "_Options"

    LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "No Target Frame",
        displayName = "No Target Frame",
        author = "j.hhh",
        version = "1.1.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls(panelName, {
        {
            type = "description",
            text = "Hides the vanilla reticle target frame only.",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Hide Target Frame",
            tooltip = "Hides the vanilla reticle target frame only.",
            getFunc = function()
                return IsEnabled()
            end,
            setFunc = function(value)
                settings.enabled = value
            end,
            default = defaults.enabled,
            requiresReload = true,
            width = "full",
        },
    })
end

local function HideTargetFrame()
    if not IsEnabled() then
        return
    end

    local targetFrame

    if ZO_UnitFrames_GetUnitFrame then
        targetFrame = ZO_UnitFrames_GetUnitFrame("reticleover")
    end

    if targetFrame then
        if targetFrame.SetAnimateShowHide then
            targetFrame:SetAnimateShowHide(false)
        end

        if targetFrame.SetHiddenForReason then
            targetFrame:SetHiddenForReason(ADDON_NAME, true)
        end
    end

    if UNIT_FRAMES and UNIT_FRAMES.SetFrameHiddenForReason then
        UNIT_FRAMES:SetFrameHiddenForReason("reticleover", ADDON_NAME, true)
    end

    if ZO_UnitFrames_UpdateWindow then
        ZO_UnitFrames_UpdateWindow("reticleover", true)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    settings = ZO_SavedVars:NewAccountWide(
        "NoTargetFrameSavedVariables",
        1,
        nil,
        defaults
    )

    RegisterSettingsMenu()

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_TargetChanged",
        EVENT_RETICLE_TARGET_CHANGED,
        HideTargetFrame
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_Combat",
        EVENT_PLAYER_COMBAT_STATE,
        HideTargetFrame
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_Activated",
        EVENT_PLAYER_ACTIVATED,
        HideTargetFrame
    )

    local guard = WINDOW_MANAGER:CreateControl(
        ADDON_NAME .. "_Guard",
        GuiRoot,
        CT_CONTROL
    )

    guard:SetHandler("OnUpdate", function(control, elapsed)
        control._elapsed = (control._elapsed or 0) + elapsed

        if control._elapsed >= 0.25 then
            control._elapsed = 0
            HideTargetFrame()
        end
    end)

    HideTargetFrame()
    zo_callLater(HideTargetFrame, 250)
    zo_callLater(HideTargetFrame, 1000)

    EVENT_MANAGER:UnregisterForEvent(
        ADDON_NAME,
        EVENT_ADD_ON_LOADED
    )
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddOnLoaded
)
