--[[
    ARC_ZoneExplorer Settings Panel
    LibAddonMenu-2.0 Integration
]]

ARC_ZoneExplorer = ARC_ZoneExplorer or {}

function ARC_ZoneExplorer:InitializeSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = GetString(SI_ARC_ZE_TITLE),
        displayName = "|c00D4FFARC_ZoneExplorer|r",
        author = "@arcsinan",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
        website = "https://www.esoui.com",
    }

    local optionsTable = {
        {
            type = "description",
            text = GetString(SI_ARC_ZE_DESC),
        },
        {
            type = "dropdown",
            name = function() return GetString(SI_ARC_ZE_OPT_LANGUAGE) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_LANGUAGE_TIP) end,
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
            name = function() return GetString(SI_ARC_ZE_HDR_GENERAL) end,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_ENABLE) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_ENABLE_TIP) end,
            getFunc = function() return self.savedVars.enabled end,
            setFunc = function(value) self.savedVars.enabled = value end,
            default = true,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_AUTO_SHOW) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_AUTO_SHOW_TIP) end,
            getFunc = function() return self.savedVars.autoShowOnArrival end,
            setFunc = function(value) self.savedVars.autoShowOnArrival = value end,
            disabled = function() return not self.savedVars.enabled end,
            default = true,
        },
        {
            type = "slider",
            name = function() return GetString(SI_ARC_ZE_OPT_DURATION) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_DURATION_TIP) end,
            min = 0,
            max = 30,
            step = 1,
            getFunc = function() return self.savedVars.displayDuration end,
            setFunc = function(value) self.savedVars.displayDuration = value end,
            disabled = function() return not self.savedVars.enabled end,
            default = 8,
        },
        {
            type = "slider",
            name = function() return GetString(SI_ARC_ZE_OPT_OPACITY) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_OPACITY_TIP) end,
            min = 0.3,
            max = 1.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return self.savedVars.windowOpacity end,
            setFunc = function(value)
                self.savedVars.windowOpacity = value
                if self.hud then
                    self.hud:SetAlpha(value)
                end
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = 0.90,
        },
        {
            type = "slider",
            name = function() return GetString(SI_ARC_ZE_OPT_SCALE) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_SCALE_TIP) end,
            min = 0.50,
            max = 1.30,
            step = 0.05,
            decimals = 2,
            getFunc = function() return self.savedVars.uiScale or 1.0 end,
            setFunc = function(value)
                self.savedVars.uiScale = value
                if self.ApplyLayout then
                    self:ApplyLayout()
                end
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = 1.0,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_COMPACT) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_COMPACT_TIP) end,
            getFunc = function() return self.savedVars.compactMode or false end,
            setFunc = function(value)
                self.savedVars.compactMode = value
                if self.ApplyLayout then
                    self:ApplyLayout()
                end
                if self.RefreshData then
                    self:RefreshData()
                end
            end,
            disabled = function() return not self.savedVars.enabled end,
            default = false,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_HIDE_COMPLETED) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_HIDE_COMPLETED_TIP) end,
            getFunc = function() return self.savedVars.hideCompleted end,
            setFunc = function(value) self.savedVars.hideCompleted = value end,
            disabled = function() return not self.savedVars.enabled end,
            default = false,
        },
        {
            type = "submenu",
            name = function() return GetString(SI_ARC_ZE_SUBMENU_ACTIVITIES) end,
            tooltip = function() return GetString(SI_ARC_ZE_SUBMENU_ACTIVITIES_DESC) end,
            disabled = function() return not self.savedVars.enabled end,
            controls = {
                {
                    type = "checkbox",
                    name = function() return GetString(SI_ARC_ZE_OPT_TRACK_SKYSHARDS) end,
                    getFunc = function() return self.savedVars.trackSkyshards end,
                    setFunc = function(val) self.savedVars.trackSkyshards = val end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = function() return GetString(SI_ARC_ZE_OPT_TRACK_WAYSHRINES) end,
                    getFunc = function() return self.savedVars.trackWayshrines end,
                    setFunc = function(val) self.savedVars.trackWayshrines = val end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = function() return GetString(SI_ARC_ZE_OPT_TRACK_DELVES) end,
                    getFunc = function() return self.savedVars.trackDelves end,
                    setFunc = function(val) self.savedVars.trackDelves = val end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = function() return GetString(SI_ARC_ZE_OPT_TRACK_DUNGEONS) end,
                    getFunc = function() return self.savedVars.trackDungeons end,
                    setFunc = function(val) self.savedVars.trackDungeons = val end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = function() return GetString(SI_ARC_ZE_OPT_TRACK_BOSSES) end,
                    getFunc = function() return self.savedVars.trackBosses end,
                    setFunc = function(val) self.savedVars.trackBosses = val end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = function() return GetString(SI_ARC_ZE_OPT_TRACK_EVENTS) end,
                    getFunc = function() return self.savedVars.trackEvents end,
                    setFunc = function(val) self.savedVars.trackEvents = val end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = function() return GetString(SI_ARC_ZE_OPT_TRACK_LOCALES) end,
                    getFunc = function() return self.savedVars.trackLocales end,
                    setFunc = function(val) self.savedVars.trackLocales = val end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = function() return GetString(SI_ARC_ZE_OPT_TRACK_STORY) end,
                    getFunc = function() return self.savedVars.trackStory end,
                    setFunc = function(val) self.savedVars.trackStory = val end,
                    default = true,
                },
            },
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_SHOW_SETS) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_SHOW_SETS_TIP) end,
            getFunc = function() return self.savedVars.showSets end,
            setFunc = function(value) self.savedVars.showSets = value end,
            disabled = function() return not self.savedVars.enabled end,
            default = true,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_HIDE_COMPLETED_SETS) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_HIDE_COMPLETED_SETS_TIP) end,
            getFunc = function() return self.savedVars.hideCompletedSets end,
            setFunc = function(value) self.savedVars.hideCompletedSets = value end,
            disabled = function() return not self.savedVars.enabled or not self.savedVars.showSets end,
            default = false,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_SHOW_DAILIES) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_SHOW_DAILIES_TIP) end,
            getFunc = function() return self.savedVars.showDailies end,
            setFunc = function(value) self.savedVars.showDailies = value end,
            disabled = function() return not self.savedVars.enabled end,
            default = true,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_TRACK_RIDING) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_TRACK_RIDING_TIP) end,
            getFunc = function() return self.savedVars.trackRiding end,
            setFunc = function(value) self.savedVars.trackRiding = value end,
            disabled = function() return not self.savedVars.enabled or not self.savedVars.showDailies end,
            default = true,
        },
        {
            type = "checkbox",
            name = function() return GetString(SI_ARC_ZE_OPT_TRACK_WRITS) end,
            tooltip = function() return GetString(SI_ARC_ZE_OPT_TRACK_WRITS_TIP) end,
            getFunc = function() return self.savedVars.trackWrits end,
            setFunc = function(value) self.savedVars.trackWrits = value end,
            disabled = function() return not self.savedVars.enabled or not self.savedVars.showDailies end,
            default = true,
        },
        {
            type = "button",
            name = "Test / Toggle HUD",
            tooltip = "Shows or hides the Zone Explorer HUD right now.",
            func = function()
                self:ToggleHUD()
            end,
            width = "half",
        },
        {
            type = "header",
            name = function() return GetString(SI_ARC_ZE_HEADER_DONATE) end,
        },
        {
            type = "description",
            text = function() return GetString(SI_ARC_ZE_DONATE_DESC) end,
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_ZE_BTN_DONATE_5K) end,
            tooltip = function() return GetString(SI_ARC_ZE_BTN_DONATE_5K_TT) end,
            func = function() ARC_ZoneExplorer.DonateGold(5000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_ZE_BTN_DONATE_25K) end,
            tooltip = function() return GetString(SI_ARC_ZE_BTN_DONATE_25K_TT) end,
            func = function() ARC_ZoneExplorer.DonateGold(25000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_ZE_BTN_DONATE_100K) end,
            tooltip = function() return GetString(SI_ARC_ZE_BTN_DONATE_100K_TT) end,
            func = function() ARC_ZoneExplorer.DonateGold(100000) end,
            width = "half",
        },
        {
            type = "button",
            name = function() return GetString(SI_ARC_ZE_BTN_DONATE_CUSTOM) end,
            tooltip = function() return GetString(SI_ARC_ZE_BTN_DONATE_CUSTOM_TT) end,
            func = function() ARC_ZoneExplorer.DonateGold(0) end,
            width = "half",
        },
    }

    self.settingsPanel = LAM:RegisterAddonPanel("ARC_ZoneExplorer_SettingsPanel", panelData)
    LAM:RegisterOptionControls("ARC_ZoneExplorer_SettingsPanel", optionsTable)
end
