TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Settings = TacticalDisplay.Settings or {}
local _Settings = TacticalDisplay.Settings
local _Base = TacticalDisplay.Base
local _Data = TacticalDisplay.Data
local _Panel = TacticalDisplay.Panel
local _LibAddonMenu2 = LibAddonMenu2
local _CountTable = TacticalDisplay.Utilities.CountTable

local _config
local _defaults = {
    enabled = true,
    debugLog = false,
    minDamage = 400,
    signatureFilterOff = false,
    signatureTTL = 600,
    panelEnabled = true,
    panelActiveDuration = 2,
    panelVisibleDuration = 60,
}

local SAVED_VARS_VERSION = 3

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

local function RebuildDBAndApply()
    _Base.RebuildDB()

    -- apply DoT changes
    if _config.enabled then
        _Data.Disable()
        _Data.Enable()
    end
end

local function UpdateParameters()
    _Base.UpdateParameters(_config.debugLog)
    _Data.UpdateParameters(_config.debugLog, _config.minDamage, _config.signatureFilterOff, _config.signatureTTL)
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
            type = "description",
            name = "Game database",
            title = "Game database",
            text = function()
                local numHiddenAbilities = _CountTable(_Base.HIDDEN_ABILITIES)
                local numTrackedDoTs = _CountTable(_Base.TRACKED_DOT_ABILITIES)
                local numSignatureAbilities = _CountTable(_Base.SIGNATURE_ABILITIES)
                local numMeasurablePlayerAbilities = _CountTable(_Base.MEASURABLE_PLAYER_ABILITIES)
                if numHiddenAbilities == 0 then
                    return "Empty database; Click \"Rebuild game database\" below"
                else
                    return ("Hidden abilities: %d\nTracked DoTs: %d\nSignature ablities: %d\nMeasurable abilities: %d")
                        :format(numHiddenAbilities, numTrackedDoTs, numSignatureAbilities, numMeasurablePlayerAbilities)
                end
            end,
            width = "full",
        },
        {
            type = "button",
            name = "Rebuild game database",
            func = function()
                RebuildDBAndApply()
            end,
        },
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
            type = "submenu",
            name = "Combat Details",
            disabled = function()
                return not _config.enabled
            end,
            controls = {
                {
                    type = "slider",
                    name = "Minimum damage to track",
                    min = 0,
                    max = 2000,
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
                    type = "slider",
                    name = "How long to keep signatures, in received attacks",
                    min = 20,
                    max = 2000,
                    disabled = function()
                        return not _config.enabled
                    end,
                    getFunc = function()
                        return _config.signatureTTL
                    end,
                    setFunc = function(value)
                        _config.signatureTTL = value
                        UpdateParameters()
                    end,
                },
            },
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
                    name = "How long to highlight recent opponents, in seconds",
                    min = 2,
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
                    name = "How long to keep recent opponents, in seconds",
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
        {
            type = "submenu",
            name = "Debug Functions",
            disabled = function()
                return not _config.enabled
            end,
            controls = {
                {
                    type = "checkbox",
                    name = "Enable Logging to Chat",
                    getFunc = function()
                        return _config.debugLog
                    end,
                    setFunc = function(enabled)
                        _config.debugLog = enabled
                        UpdateParameters()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Mark all incoming attacks as signature",
                    getFunc = function()
                        return _config.signatureFilterOff
                    end,
                    setFunc = function(enabled)
                        _config.signatureFilterOff = enabled
                        UpdateParameters()
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
