MyExtras = {}
MyExtras.name = "MyExtras"
MyExtras.version = "1"
MyExtras.savedVariables = nil
MyExtras.charVariables = nil
MyExtras.defaults = {}
MyExtras.charDefaults = {}
MyExtras.features = {}

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
        self.savedVariables[key] = value
    end

    CallFeatures("OnReset")
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function MyExtras:HasConsoleMenu()
    return type(LibConsoleMenu) == "table"
       and type(LibConsoleMenu.CreateAddonMenu) == "function"
end

function MyExtras:CreateSettings()
    if not self:HasConsoleMenu() then
        self.settingsUnavailable = true
        return
    end

    local menu = LibConsoleMenu:CreateAddonMenu("MyExtras", {
        title          = "MyExtras",
        author         = "user562",
        version        = self.version,
        category       = MOD_BROWSER_CATEGORY_TYPE_MISC,
        enableDefaults = true,
        enableReset    = true,
        childrenAlign  = "center",
        resetFunc      = function() self:ResetSettings() end,
    })

    if not menu then return end

    self.menu = menu

    local options = {}
    for _, feature in ipairs(self.features) do
        if type(feature.GetOptions) == "function" then
            local featureOptions = feature:GetOptions()
            for i = 1, #featureOptions do
                options[#options + 1] = featureOptions[i]
            end
        end
    end

    menu:AddOptions(options)
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
