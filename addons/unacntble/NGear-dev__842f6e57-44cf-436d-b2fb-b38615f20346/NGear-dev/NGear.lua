local ADDON_NAME = "NGear-dev"
local DEFAULT_ADDON_VERSION = 0
local SOURCE_DEV_MODE = true

local function GetAddonVersion()
    if not GetAddOnManager then
        return DEFAULT_ADDON_VERSION
    end

    local addonManager = GetAddOnManager()
    if not addonManager or not addonManager.GetNumAddOns or not addonManager.GetAddOnInfo
        or not addonManager.GetAddOnVersion then
        return DEFAULT_ADDON_VERSION
    end

    for addonIndex = 1, addonManager:GetNumAddOns() do
        local addonName = addonManager:GetAddOnInfo(addonIndex)
        if addonName == ADDON_NAME then
            return addonManager:GetAddOnVersion(addonIndex)
        end
    end

    return DEFAULT_ADDON_VERSION
end

NGear = NGear or {}
NGear.name = ADDON_NAME
NGear.version = GetAddonVersion()

function NGear.IsDevMode()
    return SOURCE_DEV_MODE or NGear.name == "NGear-dev"
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    NGear.version = GetAddonVersion()
    NGear.Lexicon.Initialize()

    NGear.Settings.InitializeAccountWide()
    NGear.ItemLocator.InitializeSavedVariables()
    NGear.Features.StickerBook.InitializeSavedVariables()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)

        NGear.ItemLocator.Initialize()
        NGear.Features.StickerBook.Initialize()
        NGear.GamepadOptions.Initialize()
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
