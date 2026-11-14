local ADDON_NAME = "NQOL-dev"
local DEFAULT_ADDON_VERSION = 0
local SOURCE_DEV_MODE = true

local function GetAddonVersion()
    if not GetAddOnManager then
        return DEFAULT_ADDON_VERSION
    end

    local addonManager = GetAddOnManager()
    if not addonManager or not addonManager.GetNumAddOns or not addonManager.GetAddOnInfo or not addonManager.GetAddOnVersion then
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

NQOL = NQOL or {}
NQOL.name = ADDON_NAME
NQOL.version = GetAddonVersion()

function NQOL.IsDevMode()
    return SOURCE_DEV_MODE or NQOL.name == "NQOL-dev"
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    NQOL.Lexicon.Initialize()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    NQOL.version = GetAddonVersion()

    local steps = {}
    local function AddStep(name, run, requiresPlayer, yieldAfter)
        steps[#steps + 1] = {
            name = name,
            run = run,
            requiresPlayer = requiresPlayer,
            yieldAfter = yieldAfter,
        }
    end

    local savedVariableModules = {
        NQOL.FirstRun,
        NQOL.WhatsNew,
        NQOL.Features.Mounts,
        NQOL.Features.Antiquities,
        NQOL.Features.Gear,
        NQOL.Features.Provisioning,
        NQOL.Features.Map,
        NQOL.Features.Minimap,
        NQOL.Features.GPS,
        NQOL.Features.Fishing,
        NQOL.Features.UI,
        NQOL.Features.Camera,
        NQOL.Features.UIPlayerInfo,
        NQOL.Features.PlayerBars,
        NQOL.Features.Chat,
        NQOL.Features.ChatReminders,
        NQOL.Features.Friends,
        NQOL.Features.Guilds,
        NQOL.Features.GroupFinderMonitor,
        NQOL.Features.Grouping,
        NQOL.Features.TomePoints,
        NQOL.Features.VeterancyRewards,
        NQOL.Features.TransmuteWatch,
        NQOL.Features.SkipLogoutConfirmation,
        NQOL.Features.ErrorsDismissal,
        NQOL.Features.Positioning,
        NQOL.Features.LuaGc,
        NQOL.Features.UltimateCountdown,
        NQOL.Features.TrialTimer,
        NQOL.Features.CombatInfiniteArchive,
        NQOL.Features.CombatMiscellaneous,
        NQOL.Features.BuffsDebuffs,
        NQOL.Features.Ticker,
        NQOL.Features.Progress,
        NQOL.Features.ProgressGold,
        NQOL.Features.ProgressDungeons,
        NQOL.Features.ProgressSoloDungeons,
        NQOL.Features.ProgressTrials,
        NQOL.Features.ProgressArenas,
        NQOL.Features.ProgressInfiniteArchive,
    }
    if NQOL.IsDevMode() then
        savedVariableModules[#savedVariableModules + 1] = NQOL.Features.Debug
    end
    for index, module in ipairs(savedVariableModules) do
        AddStep("SavedVariables " .. index, module.InitializeSavedVariables)
    end
    AddStep("Settings cleanup", function()
        NQOL.Settings.RemovePath({ "collections" })
        NQOL.Settings.RemovePath({ "mounts", "randomMount" })
        NQOL.Settings.RemovePath({ "ui", "customFrames", "playerFrame", "defaultFrame" })
        NQOL.Settings.RemovePath({ "ui", "customFrames", "companionFrame", "defaultFrame" })
        NQOL.Settings.RemovePath({ "ui", "customFrames", "groupFrame", "defaultFrame" })
        NQOL.Settings.RemovePath({ "utility", "cameraSensitivity" })
    end)
    -- Install chat/error handlers before activation when possible. Their initializers
    -- also read current state, so an activation received during this phase is safe.
    AddStep("Chat", NQOL.Features.Chat.Initialize, false, true)
    AddStep("ErrorsDismissal", NQOL.Features.ErrorsDismissal.Initialize, false, true)
    AddStep("ChatMissingItemRequests", NQOL.Features.ChatMissingItemRequests.Initialize, false, true)
    AddStep("ChatReminders", NQOL.Features.ChatReminders.Initialize, false, true)

    -- Preserve feature dependencies, but run at most one feature initializer per
    -- frame. Each module reads the latest player/UI state when it starts.
    local featureModules = {
        NQOL.Features.Mounts,
        NQOL.Features.Antiquities,
        NQOL.Features.Gear,
        NQOL.Features.Provisioning,
        NQOL.Features.Map,
        NQOL.Features.MapTravelTabs,
        NQOL.Features.Minimap,
        NQOL.Features.GPS,
        NQOL.Features.Fishing,
        NQOL.Features.Freeport,
        NQOL.Features.Camera,
        NQOL.Features.UI,
        NQOL.Features.UIPlayerInfo,
        NQOL.Features.PlayerBars,
        NQOL.Features.Grouping,
        NQOL.Features.TomePoints,
        NQOL.Features.VeterancyRewards,
        NQOL.Features.TransmuteWatch,
        NQOL.Features.SkipLogoutConfirmation,
        NQOL.Features.LuaGc,
        NQOL.Features.UltimateCountdown,
        NQOL.Features.TrialTimer,
        NQOL.Features.CombatInfiniteArchive,
        NQOL.Features.CombatMiscellaneous,
        NQOL.Features.BuffsDebuffs,
        NQOL.Features.Ticker,
        NQOL.Features.Friends,
        NQOL.Features.Guilds,
        NQOL.Features.GroupFinderMonitor,
        NQOL.Features.Progress,
        NQOL.Features.ProgressGold,
        NQOL.Features.ProgressDungeons,
        NQOL.Features.ProgressSoloDungeons,
        NQOL.Features.ProgressTrials,
        NQOL.Features.ProgressArenas,
        NQOL.Features.ProgressInfiniteArchive,
    }
    if NQOL.IsDevMode() then
        featureModules[#featureModules + 1] = NQOL.Features.Debug
    end
    for index, module in ipairs(featureModules) do
        AddStep("Feature " .. index, module.Initialize, true, true)
    end
    -- Commands and menu actions must not expose features that are still starting.
    AddStep("SlashCommands", NQOL.Features.SlashCommands.Initialize, true, true)
    if NQOL.GamepadOptions then
        AddStep("GamepadOptions", NQOL.GamepadOptions.Initialize, true, true)
    end
    AddStep("Onboarding", function()
        local isFirstRun = NQOL.FirstRun.Initialize()
        NQOL.WhatsNew.Initialize(isFirstRun)
    end, true, true)
    AddStep("Loaded", function()
        NQOL.Chat.Message(NQOL.L("addon.loaded", tostring(NQOL.version)))
    end, true)

    NQOL.Initialization.Start(steps)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
