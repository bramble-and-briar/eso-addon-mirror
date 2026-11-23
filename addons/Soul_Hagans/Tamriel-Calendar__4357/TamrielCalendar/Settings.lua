TamrielCalendar = TamrielCalendar or {}
local TC = TamrielCalendar

function TC.RegisterSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Tamriel Calendar",
        displayName = "|c66f2ffTamriel Calendar|r",
        author = "|cff6401Soul_Hagans|r",
        slashCommand = "/tcsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "header",
            name = GetString(SI_TC_SECTION_APPEARANCE),
        },
        {
            type = "checkbox",
            name = GetString(SI_TC_AUTO_WIDTH_NAME),
            tooltip = GetString(SI_TC_AUTO_WIDTH_TIP),
            getFunc = function() return TC.savedVars.autoWidth end,
            setFunc = function(value)
                TC.savedVars.autoWidth = value
                TC.ApplyVisualSettings()
                TC.UpdateUI()
            end,
            default = true,
        },
        {
            type = "slider",
            name = GetString(SI_TC_STRIP_WIDTH_NAME),
            tooltip = GetString(SI_TC_STRIP_WIDTH_TIP),
            min = 200,
            max = 1000,
            step = 10,
            getFunc = function() return TC.savedVars.stripWidth end,
            setFunc = function(value)
                TC.savedVars.stripWidth = value
                TC.ApplyVisualSettings()
            end,
            disabled = function() return TC.savedVars.autoWidth end,
            default = 650,
        },
        {
            type = "slider",
            name = GetString(SI_TC_STRIP_HEIGHT_NAME),
            min = 20,
            max = 80,
            step = 2,
            getFunc = function() return TC.savedVars.stripHeight end,
            setFunc = function(value)
                TC.savedVars.stripHeight = value
                TC.ApplyVisualSettings()
            end,
            default = 32,
        },
        {
            type = "slider",
            name = GetString(SI_TC_STRIP_ALPHA_NAME),
            min = 0,
            max = 100,
            step = 5,
            getFunc = function() return math.floor(TC.savedVars.stripAlpha * 100) end,
            setFunc = function(value)
                TC.savedVars.stripAlpha = value / 100
                TC.ApplyVisualSettings()
            end,
            default = 80,
        },
        {
            type = "checkbox",
            name = GetString(SI_TC_STRIP_LOCK_NAME),
            tooltip = GetString(SI_TC_STRIP_LOCK_TIP),
            getFunc = function() return TC.savedVars.stripLocked end,
            setFunc = function(value)
                TC.savedVars.stripLocked = value
                TC.ApplyVisualSettings()
            end,
            default = false,
        },
        {
            type = "header",
            name = GetString(SI_TC_SECTION_FONT),
        },
        {
            type = "colorpicker",
            name = GetString(SI_TC_TEXT_COLOR_NAME),
            tooltip = GetString(SI_TC_TEXT_COLOR_TIP),
            getFunc = function()
                local c = TC.savedVars.textColor or {r = 0.9, g = 0.82, b = 0.5, a = 1}
                return c.r, c.g, c.b, c.a or 1
            end,
            setFunc = function(r, g, b, a)
                TC.savedVars.textColor = {r = r, g = g, b = b, a = a or 1}
                TC.ApplyVisualSettings()
            end,
            default = {r = 0.9, g = 0.82, b = 0.5, a = 1},
        },
        {
            type = "dropdown",
            name = GetString(SI_TC_FONT_FAMILY_NAME),
            choices = {
                GetString(SI_TC_FONT_CHOICE_BOLD),
                GetString(SI_TC_FONT_CHOICE_REGULAR),
                GetString(SI_TC_FONT_CHOICE_MEDIUM),
                GetString(SI_TC_FONT_CHOICE_GAME),
                GetString(SI_TC_FONT_CHOICE_ANTIQUE),
                GetString(SI_TC_FONT_CHOICE_HANDWRITTEN),
                GetString(SI_TC_FONT_CHOICE_STONE),
            },
            choicesValues = {
                "$(BOLD_FONT)",
                "$(CHAT_FONT)",
                "$(MEDIUM_FONT)",
                "$(GAME_FONT)",
                "$(ANTIQUE_FONT)",
                "$(HANDWRITTEN_FONT)",
                "$(STONE_TABLET_FONT)",
            },
            getFunc = function() return TC.savedVars.fontPath end,
            setFunc = function(value)
                TC.savedVars.fontPath = value
                TC.ApplyVisualSettings()
                TC.UpdateUI()
            end,
            default = "$(BOLD_FONT)",
        },
        {
            type = "slider",
            name = GetString(SI_TC_FONT_SIZE_NAME),
            min = 12,
            max = 36,
            step = 1,
            getFunc = function() return TC.savedVars.fontSize end,
            setFunc = function(value)
                TC.savedVars.fontSize = value
                TC.ApplyVisualSettings()
                TC.UpdateUI()
            end,
            default = 18,
        },
        {
            type = "dropdown",
            name = GetString(SI_TC_FONT_STYLE_NAME),
            choices = {
                GetString(SI_TC_STYLE_CHOICE_SOFT),
                GetString(SI_TC_STYLE_CHOICE_HARD),
                GetString(SI_TC_STYLE_CHOICE_OUTLINE),
                GetString(SI_TC_STYLE_CHOICE_THIN),
                GetString(SI_TC_STYLE_CHOICE_NONE),
            },
            choicesValues = {
                "soft-shadow-thick",
                "shadow",
                "outline",
                "soft-shadow-thin",
                "",
            },
            getFunc = function() return TC.savedVars.fontStyle end,
            setFunc = function(value)
                TC.savedVars.fontStyle = value
                TC.ApplyVisualSettings()
                TC.UpdateUI()
            end,
            default = "soft-shadow-thick",
        },
        {
            type = "header",
            name = GetString(SI_TC_SECTION_ELEMENTS),
        },
        {
            type = "checkbox",
            name = GetString(SI_TC_SHOW_WDAY_NAME),
            tooltip = GetString(SI_TC_SHOW_WDAY_TIP),
            getFunc = function() return TC.savedVars.showDayOfWeek end,
            setFunc = function(value)
                TC.savedVars.showDayOfWeek = value
                TC.UpdateUI()
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = GetString(SI_TC_SHOW_DATE_NAME),
            tooltip = GetString(SI_TC_SHOW_DATE_TIP),
            getFunc = function() return TC.savedVars.showDate end,
            setFunc = function(value)
                TC.savedVars.showDate = value
                TC.UpdateUI()
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = GetString(SI_TC_SHOW_YEAR_NAME),
            tooltip = GetString(SI_TC_SHOW_YEAR_TIP),
            getFunc = function() return TC.savedVars.showYear end,
            setFunc = function(value)
                TC.savedVars.showYear = value
                TC.UpdateUI()
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = GetString(SI_TC_SHOW_SIGN_NAME),
            tooltip = GetString(SI_TC_SHOW_SIGN_TIP),
            getFunc = function() return TC.savedVars.showSign end,
            setFunc = function(value)
                TC.savedVars.showSign = value
                TC.UpdateUI()
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = GetString(SI_TC_SHOW_TIME_NAME),
            tooltip = GetString(SI_TC_SHOW_TIME_TIP),
            getFunc = function() return TC.savedVars.showTime end,
            setFunc = function(value)
                TC.savedVars.showTime = value
                TC.UpdateUI()
            end,
            default = true,
        },
    }

    LAM:RegisterAddonPanel("TamrielCalendarOptions", panelData)
    LAM:RegisterOptionControls("TamrielCalendarOptions", optionsData)
end