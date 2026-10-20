MyExtras = {}
MyExtras.name = "MyExtras"
MyExtras.version = "1.1"
MyExtras.savedVariables = nil
MyExtras.charVariables = nil
MyExtras.defaults = {
    settingsFontSize       = 30,
    settingsOpacity        = 100,
    settingsHighlight      = "Alliance",
    settingsHighlightColor = { r = 1, g = 1, b = 1, a = 1 },
    settingsRemember       = true,
}
MyExtras.charDefaults = {}
MyExtras.features = {}

--------------------------------------------------
-- Settings Details
--------------------------------------------------
MyExtras.SAVED_ACCOUNT_TIP   = "Account wide: the same on all your characters."
MyExtras.SAVED_CHARACTER_TIP = "Per character: set separately on each of your characters."
MyExtras.PREVIEW_TIP         = "Shows it on screen so you can place it. Stays on until you turn it off."

local ICON_SETTINGS = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds"
local ICON_MENU     = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_misc.dds"

local FRAME_GREY = { r = 0.55, g = 0.55, b = 0.55 }

local RAINBOW_PALETTE = { "FF2222", "FF9900", "FFEE00", "33DD33", "00CCCC", "3399FF", "BB44EE" }

local function RainbowText(text)
    local out = {}
    local idx = 1
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == " " then
            out[#out + 1] = ch
        else
            local color = RAINBOW_PALETTE[((idx - 1) % #RAINBOW_PALETTE) + 1]
            out[#out + 1] = "|c" .. color .. ch .. "|r"
            idx = idx + 1
        end
    end
    return table.concat(out)
end

local function PanelCall(method)
    local panel = MyExtras.settingsPanel
    if panel and panel[method] then panel[method](panel) end
end

--------------------------------------------------
-- Features
--------------------------------------------------
function MyExtras:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
    if type(feature.defaults) == "table" then
        for key, value in pairs(feature.defaults) do
            self.defaults[key] = value
        end
    end
    if type(feature.charDefaults) == "table" then
        for key, value in pairs(feature.charDefaults) do
            self.charDefaults[key] = value
        end
    end
end

local function CallFeatures(method, ...)
    for _, feature in ipairs(MyExtras.features) do
        if type(feature[method]) == "function" then
            pcall(feature[method], feature, ...)
        end
    end
end

--------------------------------------------------
-- Reset
--------------------------------------------------
function MyExtras:ResetSettings()
    if not self.savedVariables then return end

    for key, value in pairs(self.defaults) do
        if type(value) == "table" then
            local copy = {}
            for k, v in pairs(value) do copy[k] = v end
            self.savedVariables[key] = copy
        else
            self.savedVariables[key] = value
        end
    end
    self.savedVariables.settingsLastPage = nil

    CallFeatures("OnReset")

    PanelCall("ApplyTextSize")
    PanelCall("ApplyOpacity")
    PanelCall("ApplyAccent")
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function MyExtras:SettingsMenu()
    local defaults = self.defaults
    return {
        type    = "submenu",
        name    = "Settings",
        icon    = ICON_SETTINGS,
        tooltip = self.SAVED_ACCOUNT_TIP,
        options = {
            {
                type    = "slider",
                name    = "Font Size",
                min     = 18, max = 44, step = 1,
                default = defaults.settingsFontSize,
                tooltip = "Default is 30.",
                getFunc = function() return self.savedVariables.settingsFontSize end,
                setFunc = function(val)
                    self.savedVariables.settingsFontSize = val
                    PanelCall("ApplyTextSize")
                end,
            },
            {
                type    = "slider",
                name    = "Opacity",
                min     = 0, max = 100, step = 5,
                default = defaults.settingsOpacity,
                tooltip = "Default is 100.",
                getFunc = function() return self.savedVariables.settingsOpacity end,
                setFunc = function(val)
                    self.savedVariables.settingsOpacity = val
                    PanelCall("ApplyOpacity")
                end,
            },
            {
                type         = "stylecolor",
                name         = RainbowText("Highlight / Slider Color"),
                choices      = { "Alliance", "Custom" },
                customValue  = "Custom",
                default      = defaults.settingsHighlight,
                colorDefault = { r = 1, g = 1, b = 1 },
                details      = function()
                    if self.savedVariables.settingsHighlight == "Custom" then
                        return "Highlights and sliders use your color."
                    end
                    return "Highlights and sliders use your alliance color."
                end,
                getFunc  = function() return self.savedVariables.settingsHighlight end,
                setFunc  = function(val)
                    self.savedVariables.settingsHighlight = val
                    PanelCall("ApplyAccent")
                end,
                getColor = function()
                    local c = self.savedVariables.settingsHighlightColor
                    if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                    return 1, 1, 1
                end,
                setColor = function(r, g, b)
                    self.savedVariables.settingsHighlightColor = { r = r, g = g, b = b, a = 1 }
                    PanelCall("ApplyAccent")
                end,
            },
            {
                type    = "toggle",
                name    = "Remember Last Page",
                preset  = "YES_NO",
                default = defaults.settingsRemember,
                tooltip = "Reopens the last page where you left off.",
                getFunc = function() return self.savedVariables.settingsRemember end,
                setFunc = function(val) self.savedVariables.settingsRemember = val end,
            },
            {
                type       = "button",
                name       = "|cFF3333Reset All|r",
                buttonText = "Reset All",
                tooltip    = "Puts every MyExtras setting back to its default. Guild Loop is only reset on this character.",
                confirm    = "Reset every MyExtras setting to its default? This can't be undone.",
                func       = function() self:ResetSettings() end,
            },
        },
    }
end

function MyExtras:SettingsPreviewControls()
    local controls = {}
    for _, feature in ipairs(self.features) do
        if type(feature.GetPreviewControls) == "function" then
            local list = feature:GetPreviewControls()
            for i = 1, #list do
                controls[#controls + 1] = list[i]
            end
        end
    end
    return controls
end

function MyExtras:CreateSettings()
    local lib = rawget(_G, "LibUser562")
    if not (lib and lib.RegisterSettings) then
        self.settingsUnavailable = true
        return
    end

    local options = {}
    for _, feature in ipairs(self.features) do
        if type(feature.GetOptions) == "function" then
            local featureOptions = feature:GetOptions()
            for i = 1, #featureOptions do
                options[#options + 1] = featureOptions[i]
            end
        end
    end
    options[#options + 1] = self:SettingsMenu()

    local sv = self.savedVariables
    self.settingsPanel = lib:RegisterSettings({
        name            = "MyExtras",
        placement       = "addons",
        menuTitle       = "MyExtras",
        menuIcon        = ICON_MENU,
        title           = "MyExtras",
        author          = "user562",
        version         = self.version,
        frameColor      = FRAME_GREY,
        previewControls = function() return MyExtras:SettingsPreviewControls() end,
        textSize        = function() return sv.settingsFontSize end,
        windowOpacity   = function() return sv.settingsOpacity end,
        rememberPage    = function() return sv.settingsRemember == true end,
        lastPage        = function()
            if type(sv.settingsLastPage) ~= "table" then sv.settingsLastPage = {} end
            return sv.settingsLastPage
        end,
        accentColor     = function()
            if sv.settingsHighlight ~= "Custom" then return nil end
            local c = sv.settingsHighlightColor
            if type(c) ~= "table" then return nil end
            return c.r or 1, c.g or 1, c.b or 1
        end,
        options         = options,
    })
    if not self.settingsPanel then self.settingsUnavailable = true end
end

--------------------------------------------------
-- Load
--------------------------------------------------
local function OnAddonLoaded(event, addonName)
    if addonName ~= MyExtras.name then return end

    MyExtras.savedVariables = ZO_SavedVars:NewAccountWide(
        "MyExtras_SavedVars",
        1,
        nil,
        MyExtras.defaults
    )

    MyExtras.charVariables = ZO_SavedVars:NewCharacterIdSettings(
        "MyExtras_CharVars",
        1,
        nil,
        MyExtras.charDefaults
    )

    CallFeatures("Init")

    local settingsOk, settingsErr = pcall(function() MyExtras:CreateSettings() end)
    if not settingsOk then
        MyExtras.settingsUnavailable = true
        MyExtras.settingsError = tostring(settingsErr)
    end

    EVENT_MANAGER:RegisterForEvent(MyExtras.name, EVENT_PLAYER_ACTIVATED,
        function() CallFeatures("OnPlayerActivated") end)

    EVENT_MANAGER:UnregisterForEvent(MyExtras.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(MyExtras.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
