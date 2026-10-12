local Hermes = _G['Hermes']

local LAM2 = LibAddonMenu2

local tomeAlertLocation = {}
local tomeAlertLocationLookup = {}
for i = 0, 1 do
    table.insert(tomeAlertLocation, i)
    table.insert(tomeAlertLocationLookup, Hermes.GetDefaultLocaleString("SETTINGS_TOME_CHOICE" .. i))
end

function Hermes:InitializeMenu()
    local panelData = {
        type = "panel",
        name = self.addonName,
        displayName = self.displayName,
        author = self.author,
        version = self.version,
        slashCommand = self.slashCommand,
        website = self.website,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {
        {
            type = "header",
            name = GetString(SI_KEYBINDINGS_GENERIC_CATEGORY_NAME),
            width = "full",
        },
        {
            type = "checkbox",
            name = Hermes.GetDefaultLocaleString("SETTINGS_SHOW_TELEPORT"),
            requiresReload = true,
            getFunc = function()
                return self.db.showTeleport
            end,
            setFunc = function(value)
                self.db.showTeleport = value
            end,
            default = self.defaults.showTeleport,
        },
        {
            type = "checkbox",
            name = Hermes.GetDefaultLocaleString("SETTINGS_SHOW_MAIL"),
            requiresReload = true,
            getFunc = function()
                return self.db.showMail
            end,
            setFunc = function(value)
                self.db.showMail = value
            end,
            default = self.defaults.showMail,
        },
        {
            type = "checkbox",
            name = Hermes.GetDefaultLocaleString("SETTINGS_SHOW_HOUSE"),
            requiresReload = true,
            getFunc = function()
                return self.db.showHouse
            end,
            setFunc = function(value)
                self.db.showHouse = value
            end,
            default = self.defaults.showHouse,
        },
        {
            type = "checkbox",
            name = Hermes.GetDefaultLocaleString("SETTINGS_SHOW_CHANGELOG"),
            getFunc = function()
                return self.db.showChangelog
            end,
            setFunc = function(value)
                self.db.showChangelog = value
            end,
            default = self.defaults.showChangelog,
        },
        {
            type = "submenu",
            name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_TITLE"),
            tooltip = Hermes.GetDefaultLocaleString("SETTINGS_TOOLTIP_TOMES"),
            width = "full",
            controls = {
                {
                    type = "checkbox",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_CLAIM"),
                    getFunc = function()
                        return self.db.enableTomeAutoClaim
                    end,
                    setFunc = function(enable)
                        self.db.enableTomeAutoClaim = enable
                        self:RefreshTomeClaimAllButton()
                    end,
                    default = self.defaults.enableTomeAutoClaim,
                },
                {
                    type = "checkbox",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_AUTO_TRACK"),
                    tooltip = Hermes.GetDefaultLocaleString("SETTINGS_TOOLTIP_TOME_AUTO_TRACK"),
                    getFunc = function()
                        return self.db.autoTrackTomes
                    end,
                    setFunc = function(value)
                        self.db.autoTrackTomes = value
                    end,
                    default = self.defaults.autoTrackTomes,
                },
                {
                    type = "checkbox",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_PROGRESS_BAR"),
                    getFunc = function()
                        return self.db.showTomeProgressBar
                    end,
                    setFunc = function(value)
                        self.db.showTomeProgressBar = value
                        self:RefreshTomeWindowIfVisible()
                    end,
                    default = self.defaults.showTomeProgressBar,
                },
                {
                    type = "header",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_HEADER_CHAT"),
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_ENABLE"),
                    getFunc = function()
                        return self.db.enableTomeAlert
                    end,
                    setFunc = function(enable)
                        self.db.enableTomeAlert = enable
                    end,
                    default = self.defaults.enableTomeAlert,
                },
                {
                    type = "dropdown",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_LOCATION"),
                    choices = tomeAlertLocationLookup,
                    choicesValues = tomeAlertLocation,
                    getFunc = function()
                        return self.db.locationTomeAlert
                    end,
                    setFunc = function(value)
                        self.db.locationTomeAlert = value
                    end,
                    width = "full",
                    default = self.defaults.locationTomeAlert,
                    disabled = function()
                        return not self.db.enableTomeAlert
                    end
                },
                {
                    type = "colorpicker",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_COLOR_WEEKLY"),
                    getFunc = function()
                        return self:ConvHexToRGB(self.db.tomeColorWeekly)
                    end,
                    setFunc = function(r, g, b)
                        self.db.tomeColorWeekly = self:ConvRGBToHex(r, g, b)
                    end,
                    disabled = function()
                        return not self.db.enableTomeAlert
                    end
                },
                {
                    type = "colorpicker",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_COLOR_SEASONAL"),
                    getFunc = function()
                        return self:ConvHexToRGB(self.db.tomeColorSeasonal)
                    end,
                    setFunc = function(r, g, b)
                        self.db.tomeColorSeasonal = self:ConvRGBToHex(r, g, b)
                    end,
                    disabled = function()
                        return not self.db.enableTomeAlert
                    end
                },
                {
                    type = "checkbox",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_REWARD"),
                    getFunc = function()
                        return self.db.showTomeReward
                    end,
                    setFunc = function(enable)
                        self.db.showTomeReward = enable
                    end,
                    default = self.defaults.showTomeReward,
                    disabled = function()
                        return not self.db.enableTomeAlert
                    end
                },
                {
                    type = "checkbox",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_SEASONAL_PROGRESS"),
                    tooltip = Hermes.GetDefaultLocaleString("SETTINGS_TOOLTIP_TOME_SEASONAL_PROGRESS"),
                    getFunc = function()
                        return self.db.showSeasonalTomeProgress
                    end,
                    setFunc = function(enable)
                        self.db.showSeasonalTomeProgress = enable
                    end,
                    default = self.defaults.showSeasonalTomeProgress,
                    disabled = function()
                        return not self.db.enableTomeAlert
                    end
                },
                {
                    type = "header",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_HEADER_WINDOW"),
                    width = "full",
                },
                {
                    type = "description",
                    text = Hermes.GetDefaultLocaleString("SETTINGS_TOME_WINDOW_INFO"),
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_ICON_UI"),
                    getFunc = function()
                        return self.db.showTomeIconUI
                    end,
                    setFunc = function(enable)
                        self.db.showTomeIconUI = enable
                        self:SetTomeIconVisible(enable)
                    end,
                    default = self.defaults.showTomeIconUI,
                },
                {
                    type = "checkbox",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_COMPACT_MODE"),
                    getFunc = function()
                        return self.db.tomeWindowCompactMode
                    end,
                    setFunc = function(enable)
                        self.db.tomeWindowCompactMode = enable
                        self:ApplyTomeWindowLayout()
                        self:RefreshTomeWindowIfVisible()
                    end,
                    default = self.defaults.tomeWindowCompactMode,
                },
                {
                    type = "slider",
                    name = Hermes.GetDefaultLocaleString("SETTINGS_TOME_BGTRANSPARENCY"),
                    min = 0,
                    max = 100,
                    getFunc = function()
                        return self.db.tomeWindowBackgroundAlpha
                    end,
                    setFunc = function(value)
                        self.db.tomeWindowBackgroundAlpha = value
                        self:ApplyTomeWindowLayout()
                        self:RefreshTomeWindowIfVisible()
                    end,
                    default = self.defaults.tomeWindowBackgroundAlpha,
                },
            },
        },
        {
            type = "button",
            name = Hermes.GetDefaultLocaleString("SETTINGS_BUTTON_CHANGELOG"),
            func = function()
                Hermes:ToggleChangelog(true)
            end,
            width = "half",
        },
        {
            type = "button",
            name = Hermes.GetDefaultLocaleString("SETTINGS_SHOW_GUIDEBUTTON"),
            func = function()
                Hermes:ToggleGuide(true)
            end,
            width = "half",
        },
    }

    self.panel = LAM2:RegisterAddonPanel(self.name .. "Options", panelData)
    LAM2:RegisterOptionControls(self.name .. "Options", optionsTable)
end