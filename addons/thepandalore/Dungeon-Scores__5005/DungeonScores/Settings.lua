DungeonScores = DungeonScores or {}

local DS = DungeonScores
DS.Settings = DS.Settings or {}
local Settings = DS.Settings

Settings.PANEL_ID = "DungeonScoresSettings"

function Settings:Initialize(savedVariables)
    self.saved = savedVariables

    local LAM = LibAddonMenu2
    if not LAM then
        d(GetString(SI_DUNGEON_SCORES_LAM_REQUIRED))
        return false
    end

    local panelData = {
        type = "panel",
        name = GetString(SI_DUNGEON_SCORES_ADDON_NAME),
        displayName = GetString(SI_DUNGEON_SCORES_ADDON_NAME_BETA),
        author = "@thepandalore",
        version = DS.VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    self.panel = LAM:RegisterAddonPanel(self.PANEL_ID, panelData)

    local options = {
        {
            type = "description",
            text = GetString(SI_DUNGEON_SCORES_SETTINGS_DESCRIPTION),
        },
        {
            type = "description",
            text = GetString(SI_DUNGEON_SCORES_SETTINGS_COMPLETION_CONTROLS),
        },
        {
            type = "header",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_BROWSER),
        },
        {
            type = "button",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_OPEN),
            tooltip = GetString(SI_DUNGEON_SCORES_SETTINGS_OPEN_TOOLTIP),
            func = function()
                DS.History:Show()
            end,
            width = "full",
        },
        {
            type = "button",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_RESET_BROWSER),
            tooltip = GetString(SI_DUNGEON_SCORES_SETTINGS_RESET_BROWSER_TOOLTIP),
            func = function()
                DS.History:ResetWindowSize()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_TITLE_FONT),
            min = 18,
            max = 34,
            step = 1,
            getFunc = function()
                return self.saved.settings.browserTitleFontSize or 24
            end,
            setFunc = function(value)
                self.saved.settings.browserTitleFontSize = zo_round(value)
                DS.History:ApplyFonts()
                DS.History:ApplyLayout(true)
            end,
            default = 24,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_HEADER_FONT),
            min = 14,
            max = 22,
            step = 1,
            getFunc = function()
                return self.saved.settings.browserHeaderFontSize or 18
            end,
            setFunc = function(value)
                self.saved.settings.browserHeaderFontSize = zo_round(value)
                DS.History:ApplyFonts()
                DS.History:ApplyLayout(true)
            end,
            default = 18,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_LIST_FONT),
            min = 12,
            max = 22,
            step = 1,
            getFunc = function()
                return self.saved.settings.browserListFontSize or 16
            end,
            setFunc = function(value)
                self.saved.settings.browserListFontSize = zo_round(value)
                DS.History:ApplyFonts()
                DS.History:Refresh()
            end,
            default = 16,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_DETAIL_FONT),
            min = 12,
            max = 20,
            step = 1,
            getFunc = function()
                return self.saved.settings.browserDetailFontSize or 16
            end,
            setFunc = function(value)
                self.saved.settings.browserDetailFontSize = zo_round(value)
                DS.History:ApplyFonts()
                DS.History:ApplyLayout(true)
            end,
            default = 16,
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_DUNGEON_SCORES_SETTINGS_RESIZE_DESCRIPTION),
        },
        {
            type = "header",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_DISPLAY),
        },
        {
            type = "checkbox",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_FINAL_NOTIFICATION),
            tooltip = GetString(SI_DUNGEON_SCORES_SETTINGS_FINAL_NOTIFICATION_TOOLTIP),
            getFunc = function()
                return self.saved.settings.showFinalScoreNotification ~= false
            end,
            setFunc = function(value)
                self.saved.settings.showFinalScoreNotification = value == true
            end,
            default = true,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_SHOW_HUD),
            tooltip = GetString(SI_DUNGEON_SCORES_SETTINGS_SHOW_HUD_TOOLTIP),
            getFunc = function()
                return self.saved.settings.showHud
            end,
            setFunc = function(value)
                self.saved.settings.showHud = value == true
                DS:RefreshHud()
            end,
            default = true,
            width = "full",
        },
        {
            type = "button",
            name = GetString(SI_DUNGEON_SCORES_SETTINGS_RESET_HUD),
            tooltip = GetString(SI_DUNGEON_SCORES_SETTINGS_RESET_HUD_TOOLTIP),
            func = function()
                DS:ResetHudPosition()
            end,
            width = "full",
        },
    }

    LAM:RegisterOptionControls(self.PANEL_ID, options)
    return true
end

function Settings:Open()
    if self.panel and LibAddonMenu2 then
        LibAddonMenu2:OpenToPanel(self.panel)
    end
end
