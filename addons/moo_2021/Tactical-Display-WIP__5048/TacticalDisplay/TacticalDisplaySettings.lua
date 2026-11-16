TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Settings = TacticalDisplay.Settings or {}
local _Settings = TacticalDisplay.Settings
local _Base = TacticalDisplay.Base
local _Data = TacticalDisplay.Data
local _Panel = TacticalDisplay.Panel
local _LibAddonMenu2 = LibAddonMenu2

local _config
local _defaults = {
    enabled = true,
    debugLog = false,
    minDamage = 300,
    panelEnabled = true,
    panelActiveDuration = 2,
    panelVisibleDuration = 30,
}

local SAVED_VARS_VERSION = 2

local function ApplySettings()
    if _config.enabled then
        _Base.Enable()
    else
        _Base.Disable()
    end

    if _config.enabled then
        _Data.Enable()
    else
        _Data.Disable()
    end

    if _config.enabled and _config.panelEnabled then
        _Panel.Enable()
    else
        _Panel.Disable()
    end
end

local function UpdateParameters()
    _Base.UpdateParameters(_config.debugLog)
    _Data.UpdateParameters(_config.debugLog, _config.minDamage)
    _Panel.UpdateParameters(_config.panelActiveDuration, _config.panelVisibleDuration)
end

local function CreateSettingsUI()
    _LibAddonMenu2:RegisterAddonPanel("TacticalDisplayOptions", {
        type = "panel",
        name = "Tactical Display",
        displayName = "Tactical Display",
        author = "moo",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    _LibAddonMenu2:RegisterOptionControls("TacticalDisplayOptions", {
        {
            type = "checkbox",
            name = "Enable Combat Tracking",
            getFunc = function()
                return _config.enabled
            end,
            setFunc = function(enabled)
                _config.enabled = enabled
                ApplySettings()
            end,
        },
        {
            type = "checkbox",
            name = "Enable Debug Logging",
            getFunc = function()
                return _config.debugLog
            end,
            setFunc = function(enabled)
                _config.debugLog = enabled
                UpdateParameters()
            end,
        },
        {
            type = "slider",
            name = "Minimum damage to track",
            min = 0,
            max = 1000,
            disabled = function()
                return not _config.enabled
            end,
            getFunc = function()
                return _config.minDamage
            end,
            setFunc = function(value)
                _config.minDamage = value
                UpdateParameters()
            end,
        },
        {
            type = "submenu",
            name = "Opponents Panel",
            disabled = function()
                return not _config.enabled
            end,
            controls = {
                {
                    type = "checkbox",
                    name = "Enable Panel",
                    getFunc = function()
                        return _config.panelEnabled
                    end,
                    setFunc = function(enabled)
                        _config.panelEnabled = enabled
                        ApplySettings()
                    end,
                },
                {
                    type = "slider",
                    name = "How long (seconds) to highlight recent opponents",
                    min = 1,
                    max = 30,
                    disabled = function()
                        return not _config.panelEnabled
                    end,
                    getFunc = function()
                        return _config.panelActiveDuration
                    end,
                    setFunc = function(value)
                        _config.panelActiveDuration = value
                        UpdateParameters()
                    end,
                },
                {
                    type = "slider",
                    name = "How long (seconds) to keep recent opponents",
                    min = 30,
                    max = 600,
                    disabled = function()
                        return not _config.panelEnabled
                    end,
                    getFunc = function()
                        return _config.panelVisibleDuration
                    end,
                    setFunc = function(value)
                        _config.panelVisibleDuration = value
                        UpdateParameters()
                    end,
                },
                {
                    type = "button",
                    name = "Reset panel layout",
                    disabled = function()
                        return not _config.panelEnabled
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
    return ZO_SavedVars:NewAccountWide("TacticalDisplaySavedVariables", SAVED_VARS_VERSION, nil, {})
end

function _Settings.Initialize(savedVars)
    savedVars.settings = savedVars.settings or _defaults
    _config = savedVars.settings
    for key, defaultValue in pairs(_defaults) do
        if _config[key] == nil then
            _config[key] = defaultValue
        end
    end

    CreateSettingsUI()
    ApplySettings()
    UpdateParameters()
end
