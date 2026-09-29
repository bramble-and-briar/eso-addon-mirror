GildedUI = GildedUI or {}
local Addon = GildedUI

Addon.name = "GildedUI"
Addon.title = "Gilded UI"
Addon.version = "0.2.46"

-- Feature modules RegisterDefaults() into this table at load time.
Addon.defaults = Addon.defaults or {
    updateRate = 1,
}

if not IsConsoleUI() then return end

local SCREEN_W = 1920
local SCREEN_H = 1080

Addon.defaults.updateRate = Addon.defaults.updateRate or 1

Addon.limits = {
    posX = { min = 0, max = SCREEN_W },
    posY = { min = 0, max = SCREEN_H },
    backgroundOpacity = { min = 0, max = 1 },
    spaceWarnThreshold = { min = 10, max = 95 },
}

Addon.fontMap = {
    [16] = "EsoUI/Common/Fonts/Univers57.otf|16|soft-shadow-thick",
    [20] = "EsoUI/Common/Fonts/Univers57.otf|20|soft-shadow-thick",
    [22] = "EsoUI/Common/Fonts/Univers57.otf|22|soft-shadow-thick",
    [24] = "EsoUI/Common/Fonts/Univers57.otf|24|soft-shadow-thick",
    [28] = "EsoUI/Common/Fonts/Univers57.otf|28|soft-shadow-thick",
    [32] = "EsoUI/Common/Fonts/Univers57.otf|32|soft-shadow-thick",
}

Addon.fontSizeItems = {
    { name = "Small (16)",   value = 16 },
    { name = "Normal (20)",  value = 20 },
    { name = "Medium (22)",  value = 22 },
    { name = "Large (24)",   value = 24 },
    { name = "X-Large (28)", value = 28 },
    { name = "Huge (32)",    value = 32 },
}

Addon.state = Addon.state or {
    hudVisible = true,
    sv = nil,
}

function Addon:SanitizeSavedVars()
    local sv = self.state.sv
    local defaults = self.defaults

    if type(sv.updateRate) ~= "number" or sv.updateRate < 0.25 then
        sv.updateRate = defaults.updateRate
    end

    self:SanitizeMonitoring()
    self:SanitizeResourcesGeneral()
    self:SanitizeIndicators()
    self:SanitizeCurrencies()
    self:SanitizePlayerIndicators()
    self:SanitizeTrackerColumn()
    self:SanitizeAlertText()
    self:SanitizeStayMounted()
end

function Addon:SetupSceneHiding()
    local addon = self
    local function OnHudStateChange(oldState, newState)
        if newState == SCENE_SHOWN then
            addon.state.hudVisible = true
        elseif newState == SCENE_HIDDEN then
            addon.state.hudVisible = false
        else
            return
        end
        addon:UpdateVisibility()
    end

    local hudScene = SCENE_MANAGER:GetScene("hud")
    local huduiScene = SCENE_MANAGER:GetScene("hudui")
    if hudScene then hudScene:RegisterCallback("StateChange", OnHudStateChange) end
    if huduiScene then huduiScene:RegisterCallback("StateChange", OnHudStateChange) end

    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
        local function isShown(scene)
            return scene and scene.GetState and scene:GetState() == SCENE_SHOWN
        end
        if isShown(hudScene) or isShown(huduiScene) then
            addon.state.hudVisible = true
        elseif not addon.state.sv.showInMenu then
            addon.state.hudVisible = false
        end
        addon:UpdateVisibility()
    end)
end

function Addon:Initialize()
    GildedUISV = GildedUISV or {}
    self:InitCurrencies()
    self.state.sv = ZO_SavedVars:NewAccountWide("GildedUISV", 8, nil, self.defaults)
    self:SanitizeSavedVars()

    self:CreateOverlay()
    self:ApplyFont()
    self:SetupSceneHiding()
    self:UpdateVisibility()
    self:UpdateResources()
    self:InitTrackerColumn()
    self:InitAlertText()

    if not LibConsoleMenu then
        self.state.sv.lastError = "LibConsoleMenu is not loaded"
    else
        local ok, err = pcall(function() self:BuildSettingsMenu() end)
        if not ok then
            self.state.sv.lastError = tostring(err)
        else
            self.state.sv.lastError = nil
        end
    end

    self:RegisterUpdateLoop()
    self:RegisterResourceEvents()
    self:RegisterCombatStatusEvents()
    self:InitStayMounted()
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= Addon.name then return end
    Addon:Initialize()
    EVENT_MANAGER:UnregisterForEvent(Addon.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(Addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
