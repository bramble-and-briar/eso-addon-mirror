local ADDON_NAME = "SynergyImprover"
local SynergyImprover = {}

local DEFAULTS = {
    synergyScale = 1.0,
    hideText = true,
    hideIcon = false,
    hideKey = false,
    uiX = nil,
    uiY = nil,
}

local synergyWasHooked = false

local function LoadSavedVariables()
    SynergyImprover.savedVariables = ZO_SavedVars:NewAccountWide("SynergyImproverSavedVars", 3, nil, DEFAULTS)
end

local function GetRootSize()
    local width = GuiRoot and GuiRoot:GetWidth() or 1920
    local height = GuiRoot and GuiRoot:GetHeight() or 1080
    if not width or width <= 0 then width = 1920 end
    if not height or height <= 0 then height = 1080 end
    return math.floor(width), math.floor(height)
end

local function CaptureDefaultPosition()
    if not SYNERGY or not SYNERGY.container then return end
    if SynergyImprover.savedVariables.uiX ~= nil and SynergyImprover.savedVariables.uiY ~= nil then return end

    local left = SYNERGY.container:GetLeft()
    local top = SYNERGY.container:GetTop()
    if left and top then
        SynergyImprover.savedVariables.uiX = math.floor(left + 0.5)
        SynergyImprover.savedVariables.uiY = math.floor(top + 0.5)
    end
end

local function ApplySynergySettings()
    if not SYNERGY or not SYNERGY.container then return end

    if SYNERGY.action then
        SYNERGY.action:SetHidden(SynergyImprover.savedVariables.hideText)
    end
    if SYNERGY.icon then
        SYNERGY.icon:SetHidden(SynergyImprover.savedVariables.hideIcon)
    end
    if SYNERGY.key then
        SYNERGY.key:SetHidden(SynergyImprover.savedVariables.hideKey)
    end

    SYNERGY.container:SetScale(SynergyImprover.savedVariables.synergyScale or 1.0)

    CaptureDefaultPosition()
    local x = SynergyImprover.savedVariables.uiX
    local y = SynergyImprover.savedVariables.uiY
    if x ~= nil and y ~= nil then
        SYNERGY.container:ClearAnchors()
        SYNERGY.container:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    end
end

local function ResetPosition()
    SynergyImprover.savedVariables.uiX = nil
    SynergyImprover.savedVariables.uiY = nil

    -- Let the base console UI rebuild the control first, then capture/apply its position.
    zo_callLater(function()
        CaptureDefaultPosition()
        ApplySynergySettings()
        d("Synergy Improver: Synergy position reset.")
    end, 100)
end

local function RestoreDefaults()
    SynergyImprover.savedVariables.synergyScale = DEFAULTS.synergyScale
    SynergyImprover.savedVariables.hideText = DEFAULTS.hideText
    SynergyImprover.savedVariables.hideIcon = DEFAULTS.hideIcon
    SynergyImprover.savedVariables.hideKey = DEFAULTS.hideKey
    SynergyImprover.savedVariables.uiX = nil
    SynergyImprover.savedVariables.uiY = nil

    zo_callLater(function()
        CaptureDefaultPosition()
        ApplySynergySettings()
    end, 100)
end

local function HookSynergyFunction()
    if synergyWasHooked or not SYNERGY then return end

    SecurePostHook(SYNERGY, "OnSynergyAbilityChanged", function()
        ApplySynergySettings()
    end)
    synergyWasHooked = true
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/bsreset"] = ResetPosition
end

local function CreateSettingsMenu()
    if not LibAddonMenu2 then return end

    local rootWidth, rootHeight = GetRootSize()
    local LAM = LibAddonMenu2
    local panelData = {
        type = "panel",
        name = "Synergy Improver",
        displayName = "Synergy Improver",
        author = "SkullElf / Console port",
        version = "1.2-console",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            text = "Console/Gamepad-only version. Synergy text can be hidden while keeping the icon and controller keybind visible. Position is adjusted with X/Y controls instead of mouse dragging.",
        },
        {
            type = "slider",
            name = "Synergy Frame Size",
            tooltip = "Adjust the size of the synergy prompt.",
            min = 0.5,
            max = 2.0,
            step = 0.05,
            getFunc = function() return SynergyImprover.savedVariables.synergyScale end,
            setFunc = function(value)
                SynergyImprover.savedVariables.synergyScale = value
                ApplySynergySettings()
            end,
            default = DEFAULTS.synergyScale,
        },
        {
            type = "slider",
            name = "Synergy Position X",
            tooltip = "Move the synergy prompt left or right.",
            min = 0,
            max = rootWidth,
            step = 5,
            getFunc = function()
                CaptureDefaultPosition()
                return SynergyImprover.savedVariables.uiX or 0
            end,
            setFunc = function(value)
                SynergyImprover.savedVariables.uiX = value
                ApplySynergySettings()
            end,
        },
        {
            type = "slider",
            name = "Synergy Position Y",
            tooltip = "Move the synergy prompt up or down.",
            min = 0,
            max = rootHeight,
            step = 5,
            getFunc = function()
                CaptureDefaultPosition()
                return SynergyImprover.savedVariables.uiY or 0
            end,
            setFunc = function(value)
                SynergyImprover.savedVariables.uiY = value
                ApplySynergySettings()
            end,
        },
        {
            type = "checkbox",
            name = "Hide Synergy Text",
            tooltip = "Hide the synergy name/action text.",
            getFunc = function() return SynergyImprover.savedVariables.hideText end,
            setFunc = function(value)
                SynergyImprover.savedVariables.hideText = value
                ApplySynergySettings()
            end,
            default = DEFAULTS.hideText,
        },
        {
            type = "checkbox",
            name = "Hide Synergy Icon",
            tooltip = "Hide the synergy icon.",
            getFunc = function() return SynergyImprover.savedVariables.hideIcon end,
            setFunc = function(value)
                SynergyImprover.savedVariables.hideIcon = value
                ApplySynergySettings()
            end,
            default = DEFAULTS.hideIcon,
        },
        {
            type = "checkbox",
            name = "Hide Synergy Keybind",
            tooltip = "Hide the controller keybind prompt.",
            getFunc = function() return SynergyImprover.savedVariables.hideKey end,
            setFunc = function(value)
                SynergyImprover.savedVariables.hideKey = value
                ApplySynergySettings()
            end,
            default = DEFAULTS.hideKey,
        },
        {
            type = "button",
            name = "Reset Synergy Position",
            tooltip = "Reset the synergy prompt position.",
            func = ResetPosition,
        },
        {
            type = "button",
            name = "Restore Defaults",
            tooltip = "Reset all Synergy Improver settings.",
            func = RestoreDefaults,
        },
    }

    LAM:RegisterAddonPanel("SynergyImproverOptions", panelData)
    LAM:RegisterOptionControls("SynergyImproverOptions", optionsData)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    LoadSavedVariables()
    CreateSettingsMenu()
    HookSynergyFunction()
    RegisterSlashCommands()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(ApplySynergySettings, 100)
    end)

    zo_callLater(ApplySynergySettings, 250)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
