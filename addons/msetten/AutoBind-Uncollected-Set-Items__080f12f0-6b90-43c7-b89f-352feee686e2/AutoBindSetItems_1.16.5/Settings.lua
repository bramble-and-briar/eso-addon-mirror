AutoBindSetItems = AutoBindSetItems or {}
AutoBindSetItems.version = "1.16.5"
AutoBindSetItems.author = "msetten"
AutoBindSetItems.name = "AutoBindSetItems" 

--- Creates the settings menu for the AutoBindSetItems addon using LibAddonMenu2
function AutoBindSetItems.CreateSettingsMenu()
    if IsConsoleUI() and not LibAddonMenu2 then return end

    local LAM = LibAddonMenu2
    local panelName = AutoBindSetItems.name .. "OptionsPanel"

    local panelData = {
        type = "panel",
        name = AutoBindSetItems.L("SI_AUTOBIND_PANEL_NAME"),
        displayName = "|c00FF00" .. AutoBindSetItems.L("SI_AUTOBIND_PANEL_NAME") .. "|r",
        author = AutoBindSetItems.author,
        version = AutoBindSetItems.version,
        registerForRefresh = true,
        -- registerForDefaults = true,
    } 

    local optionsTable = {
        {
            type = "checkbox",
            name = AutoBindSetItems.L("SI_AUTOBIND_ENABLE_SET_LABEL"),
            tooltip = AutoBindSetItems.L("SI_AUTOBIND_ENABLE_TOOLTIP"),
            getFunc = function() return AutoBindSetItems.savedVars.enabled end,
            setFunc = function(value) AutoBindSetItems.savedVars.enabled = value end,
            default = AutoBindSetItems.defaultSettings.enabled,
        }, 
        {
            type = "checkbox",
            name = AutoBindSetItems.L("SI_AUTOBIND_ENABLE_MSCOLOR"),
            tooltip = AutoBindSetItems.L("SI_AUTOBIND_ENABLE_MSCOLOR_TOOLTIP"),
            getFunc = function() return AutoBindSetItems.savedVars.message end,
            setFunc = function(value) 
              AutoBindSetItems.savedVars.message = value 
            end,
            default = AutoBindSetItems.defaultSettings.message,
        },
        {
            type = "colorpicker",
            name = AutoBindSetItems.L("SI_AUTOBIND_MSGCOLOR"),
            tooltip = AutoBindSetItems.L("SI_AUTOBIND_MSGCOLOR_TOOLTIP"),
            getFunc = function() return AutoBindSetItems.savedVars.msgcolor.r, AutoBindSetItems.savedVars.msgcolor.g, AutoBindSetItems.savedVars.msgcolor.b end,	--(alpha is optional)
            setFunc = function(r,g,b,a) 
              AutoBindSetItems.savedVars.msgcolor.r = r
              AutoBindSetItems.savedVars.msgcolor.g = g
              AutoBindSetItems.savedVars.msgcolor.b = b
            end,	
            default = AutoBindSetItems.defaultSettings.msgcolor,
            disabled = function() return not AutoBindSetItems.savedVars.message end,
            width = "half",	
            reference = "AutoBindColorPicker"
         },
         {
            type = "checkbox",
            name = AutoBindSetItems.L("SI_AUTOBIND_ENABLE_SHARE_LABEL"),
            tooltip = AutoBindSetItems.L("SI_AUTOBIND_ENABLE_SHARE_TOOLTIP"),
            getFunc = function() return AutoBindSetItems.savedVars.sharegear end,
            setFunc = function(value) AutoBindSetItems.savedVars.sharegear = value end,
            default = AutoBindSetItems.defaultSettings.sharegear,
        }, 
         {
            type = "checkbox",
            name = AutoBindSetItems.L("SI_AUTOBIND_SHARE_UNCOLLECTED_LABEL"),
            tooltip = AutoBindSetItems.L("SI_AUTOBIND_SHARE_UNCOLLECTED_TOOLTIP"),
            getFunc = function() return AutoBindSetItems.savedVars.shareuncollected end,
            setFunc = function(value) AutoBindSetItems.savedVars.shareuncollected = value end,
            default = AutoBindSetItems.defaultSettings.shareuncollected,
        }, 
        {
          type = "divider",
        },
         {
            type = "checkbox",
            name = "Debug",
            tooltip = "Turn on debugging messages.",
            getFunc = function() return AutoBindSetItems.savedVars.debug end,
            setFunc = function(value) AutoBindSetItems.savedVars.debug = value end,
            default = AutoBindSetItems.defaultSettings.debug,
        }, 
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsTable)
end