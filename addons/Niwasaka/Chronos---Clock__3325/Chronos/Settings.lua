local Chronos = _G['Chronos']

local LAM2 = LibAddonMenu2
local LMP = LibMediaProvider

local outlineStyles = { 'none', 'outline', 'thin-outline', 'thick-outline', 'shadow', 'soft-shadow-thin', 'soft-shadow-thick' }

function Chronos:InitMenu()
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
            name = Chronos.GetDefaultLocaleString("SETTINGS_HEADER_GENERAL"),
            width = "full",
        },
        {
            type = "checkbox",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_SHOW"),
            getFunc = function()
                return self.db.showClock
            end,
            setFunc = function(value)
                self.db.showClock = value
                self:InitClock()
            end,
            default = self.defaults.showClock,
        },
        {
            type = "colorpicker",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_COLOR"),
            getFunc = function()
                return self:ConvHexToRGB(self.db.clockFontColor)
            end,
            setFunc = function(r, g, b)
                self.db.clockFontColor = self:ConvRGBToHex(r, g, b)
                self:UpdateClockStyle()
            end,
            disabled = function()
                return not self.db.showClock
            end,
            default = self:GetDefaultColor("clockFontColor"),
        },
        {
            type = "dropdown",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_FONT"),
            choices = LMP:List("font"),
            getFunc = function()
                return self.db.clockTextFont
            end,
            setFunc = function(value)
                self.db.clockTextFont = value
                self:UpdateClockStyle()
            end,
            disabled = function()
                return not self.db.showClock
            end,
            default = self.defaults.clockTextFont,
        },
        {
            type = "checkbox",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_SHOW_BG"),
            getFunc = function()
                return self.db.showClockBG
            end,
            setFunc = function(value)
                self.db.showClockBG = value
                self:UpdateClockStyle()
            end,
            disabled = function()
                return not self.db.showClock
            end,
            default = self.defaults.showClockBG,
        },
        {
            type = "dropdown",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_BG"),
            choices = LMP:List("background"),
            getFunc = function()
                return self.db.clockBackground
            end,
            setFunc = function(value)
                self.db.clockBackground = value
                self:UpdateClockStyle()
            end,
            disabled = function()
                return not self.db.showClock or not self.db.showClockBG
            end,
            default = self.defaults.clockBackground,
        },
        {
            type = "colorpicker",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_BGCOLOR"),
            tooltip = Chronos.GetDefaultLocaleString("SETTINGS_TOOLTIP_BGCOLOR"),
            getFunc = function()
                return self:ConvHexToRGB(self.db.clockBackgroundColor)
            end,
            setFunc = function(r, g, b)
                self.db.clockBackgroundColor = self:ConvRGBToHex(r, g, b)
                self:UpdateClockStyle()
            end,
            disabled = function()
                return not self.db.showClock or not self.db.showClockBG
            end,
            default = self:GetDefaultColor("clockBackgroundColor"),
        },
        {
            type = "slider",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_BGTRANSPARENCY"),
            min = 0,
            max = 100,
            getFunc = function()
                return self.db.clockBackgroundAlpha
            end,
            setFunc = function(value)
                self.db.clockBackgroundAlpha = value
                self:UpdateClockStyle()
            end,
            disabled = function()
                return not self.db.showClock or not self.db.showClockBG
            end,
            default = self.defaults.clockBackgroundAlpha,
        },
        {
            type = "slider",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_FONTSIZE"),
            min = 10,
            max = 32,
            getFunc = function()
                return self.db.clockFontSize
            end,
            setFunc = function(value)
                self.db.clockFontSize = value
                self:UpdateClockStyle()
            end,
            disabled = function()
                return not self.db.showClock
            end,
            default = self.defaults.clockFontSize,
        },
        {
            type = "dropdown",
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_OUTLINE"),
            choices = outlineStyles,
            getFunc = function()
                return self.db.clockFontOutline
            end,
            setFunc = function(value)
                self.db.clockFontOutline = value
                self:UpdateClockStyle()
            end,
            disabled = function()
                return not self.db.showClock
            end,
            default = self.defaults.clockFontOutline,
        },
        {
            type = "checkbox",
            name = Chronos.GetDefaultLocaleString("SETTINGS_SHOW_CHANGELOG"),
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
            name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_TIMEZONE_HEADER"),
            tooltip = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_TIMEZONE_HEADER_TOOLTIP"),
            width = "full",
            controls = {
                {
                    type = "dropdown",
                    name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_TIMEZONES_LIST"),
                    choices = self.timeZoneLookup,
                    scrollable = true,
                    getFunc = function()
                        return self.timeZoneLookup[self.db.timeZoneIndex]
                    end,
                    setFunc = function(value)
                        self.db.timeZoneIndex = self:GetIndexFromTimeZone(value)
                        self:UpdateTimeZone()
                        self:UpdateTime()
                        self:UpdateClockStyle()
                    end,
                    default = self.timeZoneLookup[self:GetIndexFromOffset(self:GetTimeZone())],
                },
                {
                    type = "checkbox",
                    name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_DST"),
                    getFunc = function()
                        return self.db.clockDst
                    end,
                    setFunc = function(value)
                        self.db.clockDst = value
                        self:UpdateTimeZone()
                        self:UpdateTime()
                    end,
                    default = self.defaults.clockDst,
                },
                {
                    type = "checkbox",
                    name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_SHOW_UTC"),
                    getFunc = function()
                        return self.db.showClockUTC
                    end,
                    setFunc = function(value)
                        self.db.showClockUTC = value
                        self:UpdateTimeZone()
                        self:UpdateClockStyle()
                    end,
                    default = self.defaults.showClockUTC,
                },
                {
                    type = "colorpicker",
                    name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_UTC_COLOR"),
                    getFunc = function()
                        return self:ConvHexToRGB(self.db.clockUTCColor)
                    end,
                    setFunc = function(r, g, b)
                        self.db.clockUTCColor = self:ConvRGBToHex(r, g, b)
                        self:UpdateClockStyle()
                    end,
                    disabled = function()
                        return not self.db.showClockUTC
                    end,
                    default = self:GetDefaultColor("clockUTCColor"),
                },
                {
                    type = "slider",
                    name = Chronos.GetDefaultLocaleString("SETTINGS_CLOCK_UTC_FONTSIZE"),
                    min = 6,
                    max = 32,
                    getFunc = function()
                        return self.db.clockUTCFontSize
                    end,
                    setFunc = function(value)
                        self.db.clockUTCFontSize = value
                        self:UpdateClockStyle()
                    end,
                    disabled = function()
                        return not self.db.showClockUTC
                    end,
                    default = self.defaults.clockUTCFontSize,
                },
            }
        },
        {
            type = "button",
            name = Chronos.GetDefaultLocaleString("SETTINGS_SHOW_CHANGELOGBUTTON"),
            func = function()
                self:ToggleChangelog(true)
            end,
            width = "half",
        },
        {
            type = "button",
            name = Chronos.GetDefaultLocaleString("SETTINGS_SHOW_GUIDEBUTTON"),
            func = function()
                self:ToggleGuide(true)
            end,
            width = "half",
        },
    }

    self.panel = LAM2:RegisterAddonPanel(self.addonName .. "Options", panelData)
    LAM2:RegisterOptionControls(self.addonName .. "Options", optionsTable)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel == self.panel then
            self:SetClockPreview(true)
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel == self.panel then
            self:SetClockPreview(false)
        end
    end)
end
