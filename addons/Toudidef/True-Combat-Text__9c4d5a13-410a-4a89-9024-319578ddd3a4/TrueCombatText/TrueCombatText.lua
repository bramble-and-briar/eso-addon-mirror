local TCT = {
    name = "TrueCombatText",
    version = "1.1",
    savedVarsName = "TrueCombatTextSavedVars",
    variableVersion = 2,
}

-- Default values: Univers 67 with standard outline
local defaults = {
    fontPath = "EsoUI/Common/Fonts/univers67.otf",
    fontStyle = FONT_STYLE_OUTLINE or 1,
}

-- List of verified fonts usable for SCT
local AVAILABLE_FONTS = {
    { name = "Univers 67 (Recommended)", path = "EsoUI/Common/Fonts/univers67.otf" },
    { name = "Univers 57 (Game Default)", path = "EsoUI/Common/Fonts/univers57.otf" },
    { name = "Univers 55",                path = "EsoUI/Common/Fonts/univers55.otf" },
    { name = "Futura Condensed",          path = "EsoUI/Common/Fonts/futurastd-condensed.otf" },
    { name = "Futura Condensed Light",    path = "EsoUI/Common/Fonts/futurastd-condensedlight.otf" },
    { name = "Trajan Pro",                path = "EsoUI/Common/Fonts/trajanpro-regular.otf" },
    { name = "Arial Narrow",              path = "EsoUI/Common/Fonts/arialn.ttf" },
    { name = "Handwritten Bold",          path = "EsoUI/Common/Fonts/handwritten_bold.ttf" },
}

-- Outline and shadow styles accepted by the engine (FontStyle enum)
local AVAILABLE_STYLES = {
    { name = "Outline (Recommended)",     value = FONT_STYLE_OUTLINE or 1 },
    { name = "Thick Soft Shadow",         value = FONT_STYLE_SOFT_SHADOW_THICK or 4 },
    { name = "Thin Soft Shadow",          value = FONT_STYLE_SOFT_SHADOW_THIN or 3 },
    { name = "Drop Shadow",               value = FONT_STYLE_SHADOW or 2 },
    { name = "None",                      value = FONT_STYLE_NONE or 0 },
}

-- Apply settings natively to ZOS SCT engine
local function ApplyFontSettings()
    if not TCT.savedVars then return end

    local path = TCT.savedVars.fontPath
    local style = TCT.savedVars.fontStyle

    if type(style) ~= "number" then
        style = defaults.fontStyle
        TCT.savedVars.fontStyle = style
    end

    if SetSCTGamepadFont then
        SetSCTGamepadFont(path, style)
    end
    if SetSCTKeyboardFont then
        SetSCTKeyboardFont(path, style)
    end
end

-- Settings menu builder
local function BuildSettingsMenu()
    local menuHandler = LibConsoleMenu or LibAddonMenu2
    if not menuHandler then return end

    local fontChoices, fontValues = {}, {}
    for _, item in ipairs(AVAILABLE_FONTS) do
        table.insert(fontChoices, item.name)
        table.insert(fontValues, item.path)
    end

    local styleChoices, styleValues = {}, {}
    for _, item in ipairs(AVAILABLE_STYLES) do
        table.insert(styleChoices, item.name)
        table.insert(styleValues, item.value)
    end

    local panelData = {
        type = "panel",
        name = "True Combat Text",
        displayName = "True Combat Text",
        author = "|cff5900To|cb16754ud|c6374a8id|c1581fcef|r",
        version = TCT.version,
    }

    local optionsData = {
        {
            type = "dropdown",
            name = "Combat Text Font",
            tooltip = "Select typography for damage and healing numbers.",
            choices = fontChoices,
            choicesValues = fontValues,
            getFunc = function() return TCT.savedVars.fontPath end,
            setFunc = function(value)
                TCT.savedVars.fontPath = value
                ApplyFontSettings()
            end,
            default = defaults.fontPath,
        },
        {
            type = "dropdown",
            name = "Outline / Shadow Style",
            tooltip = "Sets the text outline or drop shadow effect.",
            choices = styleChoices,
            choicesValues = styleValues,
            getFunc = function() return TCT.savedVars.fontStyle end,
            setFunc = function(value)
                TCT.savedVars.fontStyle = value
                ApplyFontSettings()
            end,
            default = defaults.fontStyle,
        },
    }

    menuHandler:RegisterAddonPanel("TrueCombatTextOptions", panelData)
    menuHandler:RegisterOptionControls("TrueCombatTextOptions", optionsData)
end

-- Backup Chat Commands (/tct)
local function RegisterSlashCommands()
    SLASH_COMMANDS["/tct"] = function()
        d("|cff5900[True Combat Text]|r Current Settings:")
        d("Font : " .. tostring(TCT.savedVars.fontPath))
        d("Style: " .. tostring(TCT.savedVars.fontStyle))
        d("To change settings, open: Options -> Settings -> Addons.")
    end
end

-- Re-apply on zoning / character load to prevent engine overrides
local function OnPlayerActivated(eventCode)
    ApplyFontSettings()
end

-- Addon Initialization
local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= TCT.name then return end

    EVENT_MANAGER:UnregisterForEvent(TCT.name, EVENT_ADD_ON_LOADED)

    -- Account-wide SavedVariables
    TCT.savedVars = ZO_SavedVars:NewAccountWide(TCT.savedVarsName, TCT.variableVersion, nil, defaults)

    if type(TCT.savedVars.fontStyle) ~= "number" then
        TCT.savedVars.fontStyle = defaults.fontStyle
    end

    -- Initial apply
    ApplyFontSettings()

    -- Register menu and commands
    BuildSettingsMenu()
    RegisterSlashCommands()

    -- Ensure font is applied after the world and engine have completely loaded
    EVENT_MANAGER:RegisterForEvent(TCT.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(TCT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)