-- ARC_SetGlowGuardSettings.lua - LibAddonMenu-2.0 Settings Panel
-- Author: @arcsinan

ARC_SetGlowGuard = ARC_SetGlowGuard or {}
local ASGG = ARC_SetGlowGuard

function ASGG.InitSettings()
    local LAM = LibAddonMenu2

    local panelData = {
        type = "panel",
        name = "ARC_SetGlowGuard",
        displayName = "|c00D4FFARC_SetGlowGuard|r - Set Glow & Equipment Tracker",
        author = "|c00E676@arcsinan|r",
        version = ASGG.version or "1.0.2",
        donation = function() ASGG.DonateGold(5000) end,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        ------------------------------------------------------------------------
        -- General Settings & Language
        ------------------------------------------------------------------------
        {
            type = "header",
            name = function() return GetString(SI_ARC_SGG_HDR_GENERAL) end,
        },
        {
            type = "dropdown",
            name = function() return GetString(SI_ARC_SGG_OPT_LANGUAGE) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_LANGUAGE_TT) end,
            choices = { "English", "Türkçe" },
            choicesValues = { "en", "tr" },
            getFunc = function() return (ASGG.vars and ASGG.vars.language) or "en" end,
            setFunc = function(value)
                ASGG.vars.language = value
                if value == "tr" and ASGG.ApplyTurkishStrings then
                    ASGG.ApplyTurkishStrings()
                end
                if LAM.util and LAM.util.RequestRefreshIfNeeded then
                    LAM.util.RequestRefreshIfNeeded(ASGG.settingsPanel)
                end
            end,
            width = "full",
            default = "en",
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_SGG_OPT_ENABLE) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_ENABLE_TT) end,
            getFunc = function() return ASGG.vars.enabled end,
            setFunc = function(value)
                ASGG.vars.enabled = value
                ASGG.Refresh()
            end,
            width = "full",
            default = ASGG.defaults.enabled,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_SGG_OPT_AUTO_CHAR) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_AUTO_CHAR_TT) end,
            getFunc = function() return ASGG.vars.autoShowCharacterOnInventory end,
            setFunc = function(value)
                ASGG.vars.autoShowCharacterOnInventory = value
                ASGG.UpdateInventoryAttachment()
            end,
            width = "full",
            default = ASGG.defaults.autoShowCharacterOnInventory,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_SGG_OPT_HIGHLIGHT_EQUIP) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_HIGHLIGHT_EQUIP_TT) end,
            getFunc = function() return ASGG.vars.highlightEquipment end,
            setFunc = function(value)
                ASGG.vars.highlightEquipment = value
                ASGG.Refresh()
            end,
            width = "full",
            default = ASGG.defaults.highlightEquipment,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_SGG_OPT_HIGHLIGHT_BAG) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_HIGHLIGHT_BAG_TT) end,
            getFunc = function() return ASGG.vars.highlightBackpack end,
            setFunc = function(value)
                ASGG.vars.highlightBackpack = value
                ASGG.Refresh()
            end,
            width = "full",
            default = ASGG.defaults.highlightBackpack,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_SGG_OPT_ROW_BAR) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_ROW_BAR_TT) end,
            getFunc = function() return ASGG.vars.showRowBar end,
            setFunc = function(value)
                ASGG.vars.showRowBar = value
                ASGG.Refresh()
            end,
            width = "full",
            default = ASGG.defaults.showRowBar,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_SGG_OPT_INCOMPLETE) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_INCOMPLETE_TT) end,
            getFunc = function() return ASGG.vars.showIncompleteWarning end,
            setFunc = function(value)
                ASGG.vars.showIncompleteWarning = value
                ASGG.Refresh()
            end,
            width = "full",
            default = ASGG.defaults.showIncompleteWarning,
        },
        {
            type = "slider",
            name = function() return GetString(SI_ARC_SGG_OPT_GLOW_INTENSITY) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_GLOW_INTENSITY_TT) end,
            min = 0.2,
            max = 1.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return ASGG.vars.glowIntensity end,
            setFunc = function(value)
                ASGG.vars.glowIntensity = value
                ASGG.Refresh()
            end,
            width = "full",
            default = ASGG.defaults.glowIntensity,
        },
        {
            type = "dropdown",
            name = function() return GetString(SI_ARC_SGG_OPT_GLOW_STYLE) end,
            tooltip = function() return GetString(SI_ARC_SGG_OPT_GLOW_STYLE_TT) end,
            choices = { "Action Bar Glow", "Magical Soft Highlight", "Item Pulse" },
            choicesValues = {
                "EsoUI/Art/ActionBar/actionBar_mouseOver.dds",
                "EsoUI/Art/ActionBar/abilityHighlight_mage_med.dds",
                "EsoUI/Art/Miscellaneous/icon_highlight_pulse.dds"
            },
            getFunc = function() return ASGG.vars.glowTexture end,
            setFunc = function(value)
                ASGG.vars.glowTexture = value
                ASGG.Refresh()
            end,
            width = "full",
            default = ASGG.defaults.glowTexture,
        },

        ------------------------------------------------------------------------
        -- Set Color Customization
        ------------------------------------------------------------------------
        {
            type = "header",
            name = function() return GetString(SI_ARC_SGG_HDR_COLORS) end,
        },
        {
            type = "description",
            text = function() return GetString(SI_ARC_SGG_DESC_COLORS) end,
            width = "full",
        },
        {
            type = "colorpicker",
            name = function() return GetString(SI_ARC_SGG_COLOR_SET_1) end,
            tooltip = function() return GetString(SI_ARC_SGG_COLOR_SET_1) end,
            getFunc = function()
                local c = ASGG.vars.colors[1]
                return c[1], c[2], c[3], c[4] or 1.0
            end,
            setFunc = function(r, g, b, a)
                ASGG.vars.colors[1] = { r, g, b, a or 1.0 }
                ASGG.Refresh()
            end,
            width = "half",
            default = ASGG.defaults.colors[1],
        },
        {
            type = "colorpicker",
            name = function() return GetString(SI_ARC_SGG_COLOR_SET_2) end,
            tooltip = function() return GetString(SI_ARC_SGG_COLOR_SET_2) end,
            getFunc = function()
                local c = ASGG.vars.colors[2]
                return c[1], c[2], c[3], c[4] or 1.0
            end,
            setFunc = function(r, g, b, a)
                ASGG.vars.colors[2] = { r, g, b, a or 1.0 }
                ASGG.Refresh()
            end,
            width = "half",
            default = ASGG.defaults.colors[2],
        },
        {
            type = "colorpicker",
            name = function() return GetString(SI_ARC_SGG_COLOR_SET_3) end,
            tooltip = function() return GetString(SI_ARC_SGG_COLOR_SET_3) end,
            getFunc = function()
                local c = ASGG.vars.colors[3]
                return c[1], c[2], c[3], c[4] or 1.0
            end,
            setFunc = function(r, g, b, a)
                ASGG.vars.colors[3] = { r, g, b, a or 1.0 }
                ASGG.Refresh()
            end,
            width = "half",
            default = ASGG.defaults.colors[3],
        },
        {
            type = "colorpicker",
            name = function() return GetString(SI_ARC_SGG_COLOR_SET_4) end,
            tooltip = function() return GetString(SI_ARC_SGG_COLOR_SET_4) end,
            getFunc = function()
                local c = ASGG.vars.colors[4]
                return c[1], c[2], c[3], c[4] or 1.0
            end,
            setFunc = function(r, g, b, a)
                ASGG.vars.colors[4] = { r, g, b, a or 1.0 }
                ASGG.Refresh()
            end,
            width = "half",
            default = ASGG.defaults.colors[4],
        },
        {
            type = "colorpicker",
            name = function() return GetString(SI_ARC_SGG_COLOR_MYTHIC) end,
            tooltip = function() return GetString(SI_ARC_SGG_COLOR_MYTHIC) end,
            getFunc = function()
                local c = ASGG.vars.colors.mythic
                return c[1], c[2], c[3], c[4] or 1.0
            end,
            setFunc = function(r, g, b, a)
                ASGG.vars.colors.mythic = { r, g, b, a or 1.0 }
                ASGG.Refresh()
            end,
            width = "half",
            default = ASGG.defaults.colors.mythic,
        },
        {
            type = "colorpicker",
            name = function() return GetString(SI_ARC_SGG_COLOR_WARNING) end,
            tooltip = function() return GetString(SI_ARC_SGG_COLOR_WARNING) end,
            getFunc = function()
                local c = ASGG.vars.colors.warning
                return c[1], c[2], c[3], c[4] or 1.0
            end,
            setFunc = function(r, g, b, a)
                ASGG.vars.colors.warning = { r, g, b, a or 1.0 }
                ASGG.Refresh()
            end,
            width = "half",
            default = ASGG.defaults.colors.warning,
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_SGG_BTN_RESET_COLORS) end,
            tooltip = function() return GetString(SI_ARC_SGG_BTN_RESET_COLORS_TT) end,
            func = function()
                ASGG.vars.colors = ZO_DeepTableCopy(ASGG.defaults.colors)
                ASGG.Refresh()
            end,
            width = "full",
        },

        ------------------------------------------------------------------------
        -- Developer Support & Gold Donation (@arcsinan)
        ------------------------------------------------------------------------
        {
            type = "header",
            name = function() return GetString(SI_ARC_SGG_HDR_DONATE) end,
        },
        {
            type = "description",
            text = function() return GetString(SI_ARC_SGG_DESC_DONATE) end,
            width = "full",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_SGG_BTN_DONATE_5K) end,
            tooltip = function() return GetString(SI_ARC_SGG_BTN_DONATE_5K_TT) end,
            func = function() ASGG.DonateGold(5000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_SGG_BTN_DONATE_25K) end,
            tooltip = function() return GetString(SI_ARC_SGG_BTN_DONATE_25K_TT) end,
            func = function() ASGG.DonateGold(25000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_SGG_BTN_DONATE_100K) end,
            tooltip = function() return GetString(SI_ARC_SGG_BTN_DONATE_100K_TT) end,
            func = function() ASGG.DonateGold(100000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_SGG_BTN_DONATE_CUSTOM) end,
            tooltip = function() return GetString(SI_ARC_SGG_BTN_DONATE_CUSTOM_TT) end,
            func = function() ASGG.DonateGold(0) end,
            width = "half",
        },
    }

    ASGG.settingsPanel = LAM:RegisterAddonPanel("ARC_SetGlowGuard_OptionsPanel", panelData)
    LAM:RegisterOptionControls("ARC_SetGlowGuard_OptionsPanel", optionsData)
end
