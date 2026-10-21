--[[
    ARC_NetGraph Settings Panel
    LibAddonMenu-2.0 Integration
]]

ARC_NetGraph = ARC_NetGraph or {}

function ARC_NetGraph:InitializeSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = GetString(SI_ARC_NG_TITLE),
        displayName = "|c00D4FFARC_NetGraph|r",
        author = "@arcsinan",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
        website = "https://www.esoui.com",
    }

    local optionsTable = {
        {
            type = "description",
            text = GetString(SI_ARC_NG_DESC),
        },
        {
            type = "dropdown",
            name = function() return GetString(SI_ARC_NG_OPT_LANGUAGE) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_LANGUAGE_TIP) end,
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
            name = function() return GetString(SI_ARC_NG_HDR_GENERAL) end,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_NG_OPT_ENABLE) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_ENABLE_TIP) end,
            getFunc = function() return self.savedVars.enabled end,
            setFunc = function(value)
                self.savedVars.enabled = value
                if value then
                    self:ShowHUD()
                else
                    self:HideHUD()
                end
            end,
            default = true,
        },
        {
            type = "dropdown",
            name = function() return GetString(SI_ARC_NG_OPT_LAYOUT_MODE) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_LAYOUT_MODE_TIP) end,
            choices = {
                GetString(SI_ARC_NG_LAYOUT_COMPACT),
                GetString(SI_ARC_NG_LAYOUT_DETAILED),
                GetString(SI_ARC_NG_LAYOUT_MINIMAL),
            },
            choicesValues = { "compact", "detailed", "minimal" },
            getFunc = function() return self.savedVars.layoutMode or "compact" end,
            setFunc = function(val)
                self.savedVars.layoutMode = val
                self:RefreshDisplay()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = "compact",
        },
        {
            type = "slider",
            name = function() return GetString(SI_ARC_NG_OPT_UPDATE_INTERVAL) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_UPDATE_INTERVAL_TIP) end,
            min = 200,
            max = 2000,
            step = 50,
            getFunc = function() return self.savedVars.updateInterval or 500 end,
            setFunc = function(val)
                self.savedVars.updateInterval = val
                self:StartTicker()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = 500,
        },
        {
            type = "header",
            name = function() return GetString(SI_ARC_NG_HDR_METRICS) end,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_NG_OPT_SHOW_PING) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_SHOW_PING_TIP) end,
            getFunc = function() return self.savedVars.showPing end,
            setFunc = function(val)
                self.savedVars.showPing = val
                self:RefreshDisplay()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = true,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_NG_OPT_SHOW_JITTER) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_SHOW_JITTER_TIP) end,
            getFunc = function() return self.savedVars.showJitter end,
            setFunc = function(val)
                self.savedVars.showJitter = val
                self:RefreshDisplay()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = true,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_NG_OPT_SHOW_FPS) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_SHOW_FPS_TIP) end,
            getFunc = function() return self.savedVars.showFPS end,
            setFunc = function(val)
                self.savedVars.showFPS = val
                self:RefreshDisplay()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = true,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_NG_OPT_SHOW_MINMAX) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_SHOW_MINMAX_TIP) end,
            getFunc = function() return self.savedVars.showMinMax end,
            setFunc = function(val)
                self.savedVars.showMinMax = val
                self:RefreshDisplay()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = true,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_NG_OPT_SHOW_SERVER) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_SHOW_SERVER_TIP) end,
            getFunc = function() return self.savedVars.showServer end,
            setFunc = function(val)
                self.savedVars.showServer = val
                self:RefreshDisplay()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = false,
        },
        {
            type = "header",
            name = function() return GetString(SI_ARC_NG_HDR_VISUAL) end,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_NG_OPT_LOCK) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_LOCK_TIP) end,
            getFunc = function() return self.savedVars.isLocked end,
            setFunc = function(val)
                self.savedVars.isLocked = val
                self:ApplyAppearance()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = false,
        },
        {
            type = "slider",
            name = function() return GetString(SI_ARC_NG_OPT_SCALE) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_SCALE_TIP) end,
            min = 0.50,
            max = 1.50,
            step = 0.05,
            decimals = 2,
            getFunc = function() return self.savedVars.uiScale or 1.0 end,
            setFunc = function(val)
                self.savedVars.uiScale = val
                self:ApplyAppearance()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = 1.0,
        },
        {
            type = "slider",
            name = function() return GetString(SI_ARC_NG_OPT_OPACITY) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_OPACITY_TIP) end,
            min = 0.0,
            max = 1.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return self.savedVars.backgroundOpacity or 0.85 end,
            setFunc = function(val)
                self.savedVars.backgroundOpacity = val
                self:ApplyAppearance()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = 0.85,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_NG_OPT_COLOR_CODING) end,
            tooltip = function() return GetString(SI_ARC_NG_OPT_COLOR_CODING_TIP) end,
            getFunc = function() return self.savedVars.colorCoding end,
            setFunc = function(val)
                self.savedVars.colorCoding = val
                self:RefreshDisplay()
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = true,
        },
        {
            type = "header",
            name = function() return GetString(SI_ARC_NG_HEADER_DONATE) end,
        },
        {
            type = "description",
            text = function() return GetString(SI_ARC_NG_DONATE_DESC) end,
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_NG_BTN_DONATE_5K) end,
            tooltip = function() return GetString(SI_ARC_NG_BTN_DONATE_5K_TT) end,
            func = function() ARC_NetGraph.DonateGold(5000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_NG_BTN_DONATE_25K) end,
            tooltip = function() return GetString(SI_ARC_NG_BTN_DONATE_25K_TT) end,
            func = function() ARC_NetGraph.DonateGold(25000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_NG_BTN_DONATE_100K) end,
            tooltip = function() return GetString(SI_ARC_NG_BTN_DONATE_100K_TT) end,
            func = function() ARC_NetGraph.DonateGold(100000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_NG_BTN_DONATE_CUSTOM) end,
            tooltip = function() return GetString(SI_ARC_NG_BTN_DONATE_CUSTOM_TT) end,
            func = function() ARC_NetGraph.DonateGold(0) end,
            width = "half",
        },
    }

    self.settingsPanel = LAM:RegisterAddonPanel("ARC_NetGraph_SettingsPanel", panelData)
    LAM:RegisterOptionControls("ARC_NetGraph_SettingsPanel", optionsTable)
end
