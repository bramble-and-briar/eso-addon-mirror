TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Settings = TacticalDisplay.Settings or {}
local _Settings = TacticalDisplay.Settings
local _Data = TacticalDisplay.Data
local _Panel = TacticalDisplay.Panel

local SAVED_VARS_VERSION = 2

local _savedVars

local function ApplySettings()
    if _savedVars.enabled then
        _Data.Enable()
    else
        _Data.Disable()
    end

    if _savedVars.enabled and _savedVars.panelEnabled then
        _Panel.Enable()
    else
        _Panel.Disable()
    end
end

local function CreateSettingsUI()
    if not LibAddonMenu2 then
        return
    end

    LibAddonMenu2:RegisterAddonPanel("TacticalDisplayOptions", {
        type = "panel",
        name = "Tactical Display",
        displayName = "Tactical Display",
        author = "moo",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LibAddonMenu2:RegisterOptionControls("TacticalDisplayOptions", {
        {
            type = "checkbox",
            name = "Enable Combat Tracking",
            getFunc = function()
                return _savedVars.enabled
            end,
            setFunc = function(enabled)
                _savedVars.enabled = enabled
                ApplySettings()
            end,
        },
        {
            type = "submenu",
            name = "Opponents Panel",
            disabled = function()
                return not _savedVars.enabled
            end,
            controls = {
                {
                    type = "checkbox",
                    name = "Enable Panel",
                    getFunc = function()
                        return _savedVars.panelEnabled
                    end,
                    setFunc = function(enabled)
                        _savedVars.panelEnabled = enabled
                        ApplySettings()
                    end,
                },
                {
                    type = "button",
                    name = "Reset panel layout",
                    disabled = function()
                        return not _savedVars.panelEnabled
                    end,
                    func = function()
                        _Panel.ResetLayout()
                    end,
                },
            },
        },
    })
end

function _Settings.CreateSavedVars()
    return ZO_SavedVars:NewAccountWide("TacticalDisplaySavedVariables", SAVED_VARS_VERSION, nil, {
        enabled = true,
        panelEnabled = true,
    })
end

function _Settings.Initialize(savedVars)
    _savedVars = savedVars

    CreateSettingsUI()
    ApplySettings()
end
