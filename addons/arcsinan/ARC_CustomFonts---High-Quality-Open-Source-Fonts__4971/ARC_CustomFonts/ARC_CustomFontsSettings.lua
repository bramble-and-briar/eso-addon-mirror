--[[
    ARC Custom Fonts - Settings Panel
    LibAddonMenu-2.0 Integration
]]

ARC_CustomFonts = ARC_CustomFonts or {}

function ARC_CustomFonts:InitializeSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    -- Prepare font dropdown choices
    local fontChoices = { "None" }
    local fontChoicesValues = { "None" }

    for _, font in ipairs(self.fontList) do
        table.insert(fontChoices, font.key)
        table.insert(fontChoicesValues, font.key)
    end

    local panelData = {
        type = "panel",
        name = GetString(SI_ARC_CF_TITLE),
        displayName = "|c00D4FFARC_CustomFonts|r",
        author = "@arcsinan",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
        website = "https://www.esoui.com",
    }

    local hasLMP = (LibMediaProvider ~= nil)

    local optionsTable = {
        {
            type = "description",
            text = GetString(SI_ARC_CF_DESC),
        },
        {
            type = "dropdown",
            name = function() return GetString(SI_ARC_CF_OPT_LANGUAGE) end,
            tooltip = function() return GetString(SI_ARC_CF_OPT_LANGUAGE_TIP) end,
            choices = { "English", "Türkçe" },
            choicesValues = { "en", "tr" },
            getFunc = function() return self.savedVars.language or "en" end,
            setFunc = function(value)
                self.savedVars.language = value
                if value == "tr" and self.ApplyTurkishStrings then
                    self.ApplyTurkishStrings()
                end
            end,
            warning = "Changing language requires /reloadui to fully refresh all labels.",
            default = "en",
        },
        {
            type = "header",
            name = GetString(SI_ARC_CF_HEADER_LMP),
        },
        {
            type = "description",
            text = hasLMP and ("|c00FF00" .. GetString(SI_ARC_CF_LMP_REGISTERED) .. "|r") or ("|cFF9900" .. GetString(SI_ARC_CF_LMP_NOT_FOUND) .. "|r"),
        },
        {
            type = "header",
            name = GetString(SI_ARC_CF_HEADER_OVERRIDES),
        },
        {
            type = "description",
            text = GetString(SI_ARC_CF_OVERRIDES_DESC),
        },
        {
            type = "checkbox",
            name = GetString(SI_ARC_CF_ENABLE_OVERRIDES),
            tooltip = GetString(SI_ARC_CF_ENABLE_OVERRIDES_TIP),
            getFunc = function() return self.savedVars.enableOverrides end,
            setFunc = function(value) self.savedVars.enableOverrides = value end,
            default = false,
        },
        {
            type = "dropdown",
            name = GetString(SI_ARC_CF_CHAT_FONT),
            tooltip = GetString(SI_ARC_CF_CHAT_FONT_TIP),
            choices = fontChoices,
            choicesValues = fontChoicesValues,
            getFunc = function() return self.savedVars.chatFont or "None" end,
            setFunc = function(value) self.savedVars.chatFont = value end,
            disabled = function() return not self.savedVars.enableOverrides end,
            default = "None",
        },
        {
            type = "dropdown",
            name = GetString(SI_ARC_CF_UI_FONT),
            tooltip = GetString(SI_ARC_CF_UI_FONT_TIP),
            choices = fontChoices,
            choicesValues = fontChoicesValues,
            getFunc = function() return self.savedVars.uiFont or "None" end,
            setFunc = function(value) self.savedVars.uiFont = value end,
            disabled = function() return not self.savedVars.enableOverrides end,
            default = "None",
        },
        {
            type = "dropdown",
            name = GetString(SI_ARC_CF_HEADER_FONT),
            tooltip = GetString(SI_ARC_CF_HEADER_FONT_TIP),
            choices = fontChoices,
            choicesValues = fontChoicesValues,
            getFunc = function() return self.savedVars.headerFont or "None" end,
            setFunc = function(value) self.savedVars.headerFont = value end,
            disabled = function() return not self.savedVars.enableOverrides end,
            default = "None",
        },
        {
            type = "dropdown",
            name = GetString(SI_ARC_CF_BOOK_FONT),
            tooltip = GetString(SI_ARC_CF_BOOK_FONT_TIP),
            choices = fontChoices,
            choicesValues = fontChoicesValues,
            getFunc = function() return self.savedVars.bookFont or "None" end,
            setFunc = function(value) self.savedVars.bookFont = value end,
            disabled = function() return not self.savedVars.enableOverrides end,
            default = "None",
        },
        {
            type = "button",
            name = GetString(SI_ARC_CF_RELOAD_BTN),
            tooltip = GetString(SI_ARC_CF_RELOAD_BTN_TIP),
            func = function()
                ReloadUI()
            end,
            width = "half",
        },
        {
            type = "header",
            name = GetString(SI_ARC_CF_HEADER_DONATE),
        },
        {
            type = "description",
            text = GetString(SI_ARC_CF_DONATE_DESC),
        },
        {
            type = "button",
            name = GetString(SI_ARC_CF_BTN_DONATE_5K),
            tooltip = GetString(SI_ARC_CF_BTN_DONATE_5K_TT),
            func = function() ARC_CustomFonts.DonateGold(5000) end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(SI_ARC_CF_BTN_DONATE_25K),
            tooltip = GetString(SI_ARC_CF_BTN_DONATE_25K_TT),
            func = function() ARC_CustomFonts.DonateGold(25000) end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(SI_ARC_CF_BTN_DONATE_100K),
            tooltip = GetString(SI_ARC_CF_BTN_DONATE_100K_TT),
            func = function() ARC_CustomFonts.DonateGold(100000) end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(SI_ARC_CF_BTN_DONATE_CUSTOM),
            tooltip = GetString(SI_ARC_CF_BTN_DONATE_CUSTOM_TT),
            func = function() ARC_CustomFonts.DonateGold(0) end,
            width = "half",
        },
    }

    self.settingsPanel = LAM:RegisterAddonPanel("ARC_CustomFonts_SettingsPanel", panelData)
    LAM:RegisterOptionControls("ARC_CustomFonts_SettingsPanel", optionsTable)
end
