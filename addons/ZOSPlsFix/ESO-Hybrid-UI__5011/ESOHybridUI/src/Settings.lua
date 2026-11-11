-- Settings: one control list feeds both the keyboard Add-Ons panel (LibAddonMenu)
-- and the optional native controller page (LibGamepadOptions).
-- All visible text comes from lang/*.lua through GetString.

local ADDON = ESOHybridUI

local FONT_VALUES = {
    reticle = { "ZoFontWinH5", "ZoFontKeybindStripDescription", "ZoFontCallout", "ZoFontCallout2" },
    reticleContext = { "ZoFontWinH5", "ZoInteractionPrompt", "ZoFontCallout", "ZoFontCallout2" },
    stealthIcon = { "ZoFontWinH5", "ZoInteractionPrompt", "ZoFontCallout", "ZoFontCallout2" },
}

local function FontChoices()
    return {
        GetString(SI_ESOHYBRIDUI_FONT_SMALL),
        GetString(SI_ESOHYBRIDUI_FONT_DEFAULT),
        GetString(SI_ESOHYBRIDUI_FONT_LARGE),
        GetString(SI_ESOHYBRIDUI_FONT_XLARGE),
    }
end

local function FontDropdown(nameId, tooltipId, key)
    local values = FONT_VALUES[key]
    return {
        type = "dropdown",
        name = GetString(nameId),
        tooltip = GetString(tooltipId),
        choices = FontChoices(),
        choicesValues = values,
        default = ADDON.defaults.fonts[key],
        getFunc = function()
            local current = ADDON:GetFont(key)
            for _, value in ipairs(values) do
                if current == value then
                    return current
                end
            end
            -- Older versions offered more sizes; show the default for those
            -- without changing what is saved.
            return ADDON.defaults.fonts[key]
        end,
        setFunc = function(value)
            ADDON:SetFont(key, value)
            ADDON:ApplyPrompts()
        end,
    }
end

local function Checkbox(nameId, tooltipId, key, default, onChange)
    return {
        type = "checkbox",
        name = GetString(nameId),
        tooltip = GetString(tooltipId),
        default = default,
        getFunc = function()
            local value = ADDON:GetSettings()[key]
            if value == nil then
                return default
            end
            return value == true
        end,
        setFunc = function(value)
            ADDON:GetSettings()[key] = value == true
            if onChange then onChange(value) end
        end,
    }
end

local function OpenDonationMail()
    if not MAIL_SEND or not MAIL_SEND.ComposeMailTo then
        ADDON:Say(GetString(SI_ESOHYBRIDUI_MAIL_UNAVAILABLE))
        return
    end
    -- Only opens an addressed draft; the player chooses any gold and amount.
    MAIL_SEND:ComposeMailTo("@ZOSPlsFix")
end

local function BuildControls(isGamepad)
    local controls = {}
    local function add(control) controls[#controls + 1] = control end

    if isGamepad then
        add({ type = "description", name = GetString(SI_ESOHYBRIDUI_GP_INTRO_NAME),
            text = GetString(SI_ESOHYBRIDUI_GP_INTRO_TEXT) })
        add({ type = "header", name = GetString(SI_ESOHYBRIDUI_HEADER_INTERFACE) })
    else
        add({ type = "description", text = GetString(SI_ESOHYBRIDUI_KB_INTRO_TEXT) })
    end

    add({
        type = "button",
        name = GetString(SI_ESOHYBRIDUI_RECOMMENDED_NAME),
        tooltip = GetString(SI_ESOHYBRIDUI_RECOMMENDED_TOOLTIP),
        buttonText = GetString(SI_ESOHYBRIDUI_RECOMMENDED_BUTTON),
        func = function() ADDON:ApplyRecommendedESOSettings() end,
    })

    add({
        type = "dropdown",
        name = GetString(SI_ESOHYBRIDUI_MODE_NAME),
        tooltip = GetString(SI_ESOHYBRIDUI_MODE_TOOLTIP),
        choices = { GetString(SI_ESOHYBRIDUI_MODE_GAMEPAD), GetString(SI_ESOHYBRIDUI_MODE_HYBRID) },
        choicesValues = { ADDON.MODE_GAMEPAD, ADDON.MODE_HYBRID },
        default = ADDON.MODE_GAMEPAD,
        getFunc = function() return ADDON:IsHybrid() and ADDON.MODE_HYBRID or ADDON.MODE_GAMEPAD end,
        setFunc = function(value) ADDON:SetMode(value) end,
    })

    add({
        type = "dropdown",
        name = GetString(SI_ESOHYBRIDUI_POLICY_NAME),
        tooltip = GetString(SI_ESOHYBRIDUI_POLICY_TOOLTIP),
        choices = { GetString(SI_ESOHYBRIDUI_POLICY_GAMEPAD), GetString(SI_ESOHYBRIDUI_POLICY_LEGACY) },
        choicesValues = { ADDON.POLICY_GAMEPAD, ADDON.POLICY_LEGACY },
        default = ADDON.POLICY_GAMEPAD,
        getFunc = function()
            return ADDON:GetSettings().menuPolicy == ADDON.POLICY_LEGACY and ADDON.POLICY_LEGACY or ADDON.POLICY_GAMEPAD
        end,
        setFunc = function(value) ADDON:SetMenuPolicy(value) end,
    })

    add({
        type = "checkbox",
        name = GetString(SI_ESOHYBRIDUI_ACCOUNT_NAME),
        tooltip = GetString(SI_ESOHYBRIDUI_ACCOUNT_TOOLTIP),
        default = false,
        getFunc = function()
            local account = ADDON.savedVariablesAccountWide
            return account ~= nil and account._esoHybridUseAccountWideSettings == true
        end,
        setFunc = function(value) ADDON:SetUseAccountWideSettings(value) end,
    })

    add({ type = "header", name = GetString(SI_ESOHYBRIDUI_HEADER_HYBRID_HUD) })
    local refresh = function() ADDON:Refresh() end
    add(Checkbox(SI_ESOHYBRIDUI_WHEEL_NAME, SI_ESOHYBRIDUI_WHEEL_TOOLTIP, "hybridQuickslotWheel", true, refresh))
    add(Checkbox(SI_ESOHYBRIDUI_GLYPHS_NAME, SI_ESOHYBRIDUI_GLYPHS_TOOLTIP, "hybridActionBarGlyphs", true, refresh))

    add({ type = "header", name = GetString(SI_ESOHYBRIDUI_HEADER_PROMPTS) })
    add(FontDropdown(SI_ESOHYBRIDUI_FONT_RETICLE_NAME, SI_ESOHYBRIDUI_FONT_RETICLE_TOOLTIP, "reticle"))
    add(FontDropdown(SI_ESOHYBRIDUI_FONT_CONTEXT_NAME, SI_ESOHYBRIDUI_FONT_CONTEXT_TOOLTIP, "reticleContext"))
    add(FontDropdown(SI_ESOHYBRIDUI_FONT_STEALTH_NAME, SI_ESOHYBRIDUI_FONT_STEALTH_TOOLTIP, "stealthIcon"))

    local advanced = {
        Checkbox(SI_ESOHYBRIDUI_DEBUG_NAME, SI_ESOHYBRIDUI_DEBUG_TOOLTIP, "debugLoggingEnabled", false,
            function(value) ADDON:SetDebugLogging(value) end),
        Checkbox(SI_ESOHYBRIDUI_ANNOUNCE_NAME, SI_ESOHYBRIDUI_ANNOUNCE_TOOLTIP, "announceLoaded", false),
        { type = "description", text = GetString(SI_ESOHYBRIDUI_COMMANDS_TEXT) },
    }
    if isGamepad then
        add({ type = "header", name = GetString(SI_ESOHYBRIDUI_ADVANCED_NAME) })
        for _, control in ipairs(advanced) do add(control) end
    else
        add({ type = "submenu", name = GetString(SI_ESOHYBRIDUI_ADVANCED_NAME),
            tooltip = GetString(SI_ESOHYBRIDUI_ADVANCED_TOOLTIP), controls = advanced })
    end

    add({ type = "header", name = GetString(SI_ESOHYBRIDUI_HEADER_SUPPORT) })
    add({ type = "description", text = GetString(SI_ESOHYBRIDUI_SUPPORT_TEXT) })
    add({
        type = "button",
        name = GetString(SI_ESOHYBRIDUI_DONATE_NAME),
        tooltip = GetString(SI_ESOHYBRIDUI_DONATE_TOOLTIP),
        buttonText = GetString(SI_ESOHYBRIDUI_DONATE_BUTTON),
        func = OpenDonationMail,
    })

    return controls
end

local function RegisterGamepadOptions()
    local library = LibGamepadOptions
    if type(library) ~= "table" or type(library.RegisterAddon) ~= "function" then
        ADDON:LogInfo("LibGamepadOptions is not installed; native gamepad settings are unavailable.")
        return false
    end

    local ok, err = pcall(function()
        library:RegisterAddon("ESOHybridUI", {
            name = "ESO Hybrid UI",
            displayName = "ESO Hybrid UI",
            categoryName = "ESO Hybrid UI",
            directOpen = true,
            showInRoot = false,
            tooltip = GetString(SI_ESOHYBRIDUI_GP_INTRO_TEXT),
            sortOrder = 200,
        }, BuildControls(true))
    end)

    if not ok then
        ADDON:LogError("Could not register native gamepad settings:", tostring(err))
        return false
    end
    ADDON:LogInfo("Registered native gamepad settings.")
    return true
end

function ADDON:RegisterSettings()
    local panelName = "ESOHybridUI_Settings"
    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "ESO Hybrid UI",
        author = "ZOSPlsFix",
        version = ADDON.VERSION,
        slashCommand = "/esohybrid_settings",
        registerForRefresh = true,
        registerForDefaults = true,
    })
    LibAddonMenu2:RegisterOptionControls(panelName, BuildControls(false))
    RegisterGamepadOptions()
end
