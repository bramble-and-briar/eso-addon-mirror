-- -----------------------------------------------------------------------------
-- HUDitorTools
-- LibAddonMenu-2.0 settings menu
-- -----------------------------------------------------------------------------

-- Global table
local HT = HUDitorTools

-- LAM dropdown choices must be tables (dropdown.lua UpdateChoices uses #).
-- Functions are valid for name/tooltip/getFunc, not for choices/choicesValues.
local LAM_ACTIVE_LAYOUT_DROPDOWN_REFERENCE = "HUDitorTools_LAM_ActiveLayoutDropdown"
local lamLayoutChoices = {}
local lamLayoutChoiceValues = {}

function HT.RefreshLamLayoutDropdown()
    local names, values = HT.GetLayoutDropdownChoices()
    ZO_ClearNumericallyIndexedTable(lamLayoutChoices)
    ZO_ClearNumericallyIndexedTable(lamLayoutChoiceValues)
    for index = 1, #names do
        lamLayoutChoices[index] = names[index]
        lamLayoutChoiceValues[index] = values[index]
    end

    local dropdownControl = _G[LAM_ACTIVE_LAYOUT_DROPDOWN_REFERENCE]
    if not dropdownControl or not dropdownControl.UpdateChoices then
        return
    end
    dropdownControl:UpdateChoices(lamLayoutChoices, lamLayoutChoiceValues)
    dropdownControl:UpdateValue()
end

function HT.buildSettingsMenu()
    local LAM = LibAddonMenu2
    local defaults = HT.Defaults
    local settings = HT.SV

    local panelData =
    {
        type                = "panel",
        name                = HT.name,
        displayName         = HT.displayName,
        author              = HT.author,
        version             = tostring(HT.version),
        registerForRefresh  = true,
        registerForDefaults = true,
        slashCommand        = "/hudis",
        website             = HT.addonWebsite,
        feedback            = HT.addonFeedback,
        donation            = HT.addonDonation,
    }
    local lamSettingsPanelName = HT.eventName .. "_LAM"
    HT.LAMSettingsPanel = LAM:RegisterAddonPanel(lamSettingsPanelName, panelData)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel == HT.LAMSettingsPanel then
            HT.RefreshLamLayoutDropdown()
        end
    end)

    local optionsTable =
    {
        -- ==============================================================================
        {
            type = "header",
            name = GetString(SI_HUDITORTOOLS_INFO_BOX_LAM_HEADER),
        },
        {
            type = "checkbox",
            name = GetString(SI_HUDITORTOOLS_INFO_BOX_SETTINGS_BUTTON_LAM),
            tooltip = GetString(SI_HUDITORTOOLS_INFO_BOX_SETTINGS_BUTTON_LAM_TT),
            getFunc = function () return settings.HUDEditorShowInfoBoxSettingsButton end,
            setFunc = function (value)
                settings.HUDEditorShowInfoBoxSettingsButton = value
                HT.HUDUIStuff()
            end,
            default = defaults.HUDEditorShowInfoBoxSettingsButton,
            -- requiresReload = true,
            width = "full",
        },
        {
            type = "header",
            name = GetString(SI_HUDITORTOOLS_HUD_EDITOR_LAM_HEADER),
        },
        {
            type = "checkbox",
            name = GetString(SI_HUDITORTOOLS_HUD_EDITOR_CNTXTMENU_LAM),
            tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_CNTXTMENU_LAM_TT),
            getFunc = function () return settings.HUDEditContextMenu end,
            setFunc = function (value)
                settings.HUDEditContextMenu = value
                HT.HUDUIStuff()
            end,
            default = defaults.HUDEditContextMenu,
            -- requiresReload = true,
            width = "full",
        },
        {
            type = "colorpicker",
            name = GetString(SI_HUDITORTOOLS_HUD_EDITOR_HIDDEN_BORDER_COLOR_LAM),
            tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_HIDDEN_BORDER_COLOR_LAM_TT),
            getFunc = function ()
                local HUDEditHiddenBorderColor = settings.HUDEditHiddenBorderColor
                return HUDEditHiddenBorderColor.r, HUDEditHiddenBorderColor.g, HUDEditHiddenBorderColor.b, HUDEditHiddenBorderColor.a
            end,
            setFunc = function (r, g, b, a)
                settings.HUDEditHiddenBorderColor = { r = r, g = g, b = b, a = a }
                HT.HUDUI_UpdateColor("HUDEditHiddenBorderColor")
            end,
            default = function ()
                HT.HUDUI_UpdateColor("HUDEditHiddenBorderColor", true)
                local defaultEdgeColor = ZO_HUD_EDITOR_ELEMENT_COLORS_KEYBOARD.selectedHidden.edge
                return defaultEdgeColor:UnpackRGBA()
            end,
            width = "full",
        },
        {
            type = "header",
            name = GetString(SI_HUDITORTOOLS_GRID_LAM_HEADER),
        },
        {
            type = "checkbox",
            name = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_LAM),
            tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_LAM_TT),
            getFunc = function () return settings.showGrid end,
            setFunc = function (value)
                settings.showGrid = value
                HT.HUDUIStuff()
            end,
            default = defaults.showGrid,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SNAP_LAM),
            tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SNAP_LAM_TT),
            getFunc = function () return settings.gridSnap end,
            setFunc = function (value)
                settings.gridSnap = value
                HT.HUDUIStuff()
            end,
            default = defaults.gridSnap,
            width = "full",
            disabled = function () return not settings.showGrid end
        },
        {
            type = "slider",
            name = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SIZE_LAM),
            tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SIZE_LAM_TT),
            min = 2,
            max = 100,
            step = 1,
            clampInput = true,
            decimals = 0,
            autoSelect = true,
            getFunc = function () return settings.gridSize end,
            setFunc = function (value)
                settings.gridSize = value
                -- HT.RefreshGridOverlay() Editor never shows if the LAM menu is used
            end,
            default = defaults.gridSize,
            width = "full",
            disabled = function () return not settings.showGrid end
        },
        {
            type = "colorpicker",
            name = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_LINE_COLOR_LAM),
            tooltip = GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_LINE_COLOR_LAM_TT),
            getFunc = function ()
                local HUDEditGridColor = settings[HT.COLOR_SLOT_GRID]
                return HUDEditGridColor.r, HUDEditGridColor.g, HUDEditGridColor.b, HUDEditGridColor.a
            end,
            setFunc = function (r, g, b, a)
                settings[HT.COLOR_SLOT_GRID] = { r = r, g = g, b = b, a = a }
                HT.HUDUI_UpdateColor(HT.COLOR_SLOT_GRID)
            end,
            default = function ()
                local defaultGridColor = defaults[HT.COLOR_SLOT_GRID]
                return defaultGridColor.r, defaultGridColor.g, defaultGridColor.b, defaultGridColor.a
            end,
            disabled = function () return not settings.showGrid end,
            width = "full",
        },
        {
            type = "header",
            name = GetString(SI_HUDITORTOOLS_LAYOUT_LAM_HEADER),
        },
        {
            type = "dropdown",
            name = GetString(SI_HUDITORTOOLS_LAYOUT_LAM_ACTIVE),
            tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_LAM_ACTIVE_TOOLTIP),
            choices = lamLayoutChoices,
            choicesValues = lamLayoutChoiceValues,
            getFunc = function()
                return HT.GetActiveLayoutChoiceValue()
            end,
            setFunc = function(value)
                HT.SwitchHudLayoutFromChoiceValue(value)
            end,
            scrollable = true,
            width = "full",
            reference = LAM_ACTIVE_LAYOUT_DROPDOWN_REFERENCE,
        },
        {
            type = "checkbox",
            name = GetString(SI_HUDITORTOOLS_LAYOUT_LAM_CHAT),
            tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_LAM_CHAT_TOOLTIP),
            getFunc = function()
                return settings.showChatMessages
            end,
            setFunc = function(value)
                settings.showChatMessages = value
            end,
            default = defaults.showChatMessages,
            width = "full",
        },
        {
            type = "button",
            name = GetString(SI_HUDITORTOOLS_LAYOUT_SAVE),
            tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_SAVE_TOOLTIP),
            func = function()
                HT.SaveActiveLayout()
            end,
            disabled = function()
                return not HT.IsLiveLayoutDirty()
            end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(SI_HUDITORTOOLS_LAYOUT_NEW),
            tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_NEW_TOOLTIP),
            func = function()
                HT.ShowLayoutNameDialog("new")
            end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(SI_HUDITORTOOLS_LAYOUT_DELETE),
            tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_DELETE_TOOLTIP),
            func = function()
                HT.ShowLayoutDeleteConfirmation()
            end,
            disabled = function()
                return (HT.CountAllLayoutsForCharacter() <= 1)
            end,
            width = "full",
            reference = "HUDITORTOOLS_LAM_DELETE_LAYOUT_BUTTON"
        },
        {
            type = "button",
            name = GetString(SI_HUDITORTOOLS_LAYOUT_IMPORT),
            tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_IMPORT_TOOLTIP),
            func = function()
                HT.ShowLayoutImportDialog()
            end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(SI_HUDITORTOOLS_LAYOUT_EXPORT),
            tooltip = GetString(SI_HUDITORTOOLS_LAYOUT_EXPORT_TOOLTIP),
            func = function()
                HT.ShowLayoutExportDialog()
            end,
            width = "half",
        },
    }

    LAM:RegisterOptionControls(lamSettingsPanelName, optionsTable)
end
