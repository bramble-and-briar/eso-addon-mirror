NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local TRAINING_CHECK_NAMESPACE = "NQOL_MountTrainingCheck"
local TRAINING_CHECK_FALLBACK_MS = 60000
local TRAINING_CHECK_MAX_DELAY_MS = 3600000

local defaults = {
    mounts = {
        remainMounted = false,
        allowUseInteractions = false,
        allowOpenInteractions = false,
        allowTalkInteractions = false,
        allowActivateInteractions = false,
        trainingCheck = false,
    },
}

local Mounts = {}
local savedVariables
local hooksInstalled = false
local trainingHooksInstalled = false
local hookAttempts = 0
local alertAtMilliseconds = 0
local trainingReminderShown = false
local CheckRidingTraining

local function Log(message)
    NQOL.Chat.Message(message, NQOL.L("common.feature.mounts"))
end

local function ShowCenterMessage(message)
    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams then
        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.NONE)
        messageParams:SetText(message)

        if messageParams.SetCSAType and CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT then
            messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
        end

        if messageParams.SetLifespanMS then
            messageParams:SetLifespanMS(3500)
        end

        if CENTER_SCREEN_ANNOUNCE.AddMessageWithParams then
            CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
            return
        elseif CENTER_SCREEN_ANNOUNCE.DisplayMessage then
            CENTER_SCREEN_ANNOUNCE:DisplayMessage(messageParams)
            return
        end
    end

    if ZO_Alert then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NONE, message)
    end
end

local function GetSettings()
    local settings = NQOL.Settings.GetSection(savedVariables, defaults, "mounts")
    local defaultSettings = defaults.mounts

    NQOL.Settings.Default(settings, defaultSettings, "remainMounted")
    NQOL.Settings.Default(settings, defaultSettings, "allowUseInteractions")
    NQOL.Settings.Default(settings, defaultSettings, "allowOpenInteractions")
    NQOL.Settings.Default(settings, defaultSettings, "allowTalkInteractions")
    NQOL.Settings.Default(settings, defaultSettings, "allowActivateInteractions")
    NQOL.Settings.Default(settings, defaultSettings, "trainingCheck")

    return settings
end

local function IsAllowedMountedInteraction()
    if not GetGameCameraInteractableActionInfo or not GetString then
        return false
    end

    local action = GetGameCameraInteractableActionInfo()
    if action == GetString(SI_GAMECAMERAACTIONTYPE5) then
        return Mounts.GetAllowUseInteractions()
    end
    if action == GetString(SI_GAMECAMERAACTIONTYPE13) then
        return Mounts.GetAllowOpenInteractions()
    end
    if action == GetString(SI_GAMECAMERAACTIONTYPE2) then
        return Mounts.GetAllowTalkInteractions()
    end
    if action == GetString(SI_BINDING_NAME_RIGHT_MOUSE_IN_WORLD) then
        return Mounts.GetAllowActivateInteractions()
    end

    return false
end

local function ShouldBlockInteractions()
    return Mounts.GetRemainMounted() and IsMounted() and not IsAllowedMountedInteraction()
end

local function ShowBlockedInteractionMessage()
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if now == 0 or now - alertAtMilliseconds > 1500 then
        alertAtMilliseconds = now
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, NQOL.L("features.mounts.dismount_to_interact"))
    end
end

local function SetReticleBlockedMessage()
    if RETICLE.additionalInfo then
        RETICLE.additionalInfo:SetHidden(false)
        RETICLE.additionalInfo:SetText(NQOL.L("features.mounts.dismount_to_interact"))
    end

    if RETICLE.interactKeybindButton then
        RETICLE.interactKeybindButton:SetEnabled(false)
    end
end

local function HasTrainableRidingStat()
    if not GetRidingStats then
        return false
    end

    local inventoryBonus, maxInventoryBonus, staminaBonus, maxStaminaBonus, speedBonus, maxSpeedBonus = GetRidingStats()
    return (inventoryBonus or 0) < (maxInventoryBonus or 0)
        or (staminaBonus or 0) < (maxStaminaBonus or 0)
        or (speedBonus or 0) < (maxSpeedBonus or 0)
end

local function CanTrainRidingNow()
    if not GetTimeUntilCanBeTrained then
        return false
    end

    local timeUntilTrainableMs = GetTimeUntilCanBeTrained()
    return (timeUntilTrainableMs or 0) <= 0
end

local function GetRidingTrainingDelay()
    if not GetTimeUntilCanBeTrained then
        return TRAINING_CHECK_FALLBACK_MS
    end

    local timeUntilTrainableMs = GetTimeUntilCanBeTrained()
    timeUntilTrainableMs = tonumber(timeUntilTrainableMs) or TRAINING_CHECK_FALLBACK_MS

    if timeUntilTrainableMs <= 0 then
        return TRAINING_CHECK_FALLBACK_MS
    end

    if timeUntilTrainableMs > TRAINING_CHECK_MAX_DELAY_MS then
        return TRAINING_CHECK_MAX_DELAY_MS
    end

    return timeUntilTrainableMs
end

local function StopRidingTrainingChecks()
    if EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate(TRAINING_CHECK_NAMESPACE)
    end
end

local function ScheduleRidingTrainingCheck(delayMs)
    StopRidingTrainingChecks()

    if Mounts.GetTrainingCheck() and HasTrainableRidingStat() and EVENT_MANAGER then
        EVENT_MANAGER:RegisterForUpdate(TRAINING_CHECK_NAMESPACE, delayMs or GetRidingTrainingDelay(), function()
            StopRidingTrainingChecks()
            CheckRidingTraining()
        end)
    end
end

CheckRidingTraining = function()
    if not Mounts.GetTrainingCheck() or not HasTrainableRidingStat() then
        StopRidingTrainingChecks()
        trainingReminderShown = false
        return
    end

    if CanTrainRidingNow() then
        if not trainingReminderShown then
            trainingReminderShown = true
            local trainingMessage = NQOL.L("features.mounts.training_available")
            Log(trainingMessage)
            ShowCenterMessage(trainingMessage)
        end
        ScheduleRidingTrainingCheck(TRAINING_CHECK_FALLBACK_MS)
    else
        trainingReminderShown = false
        ScheduleRidingTrainingCheck(GetRidingTrainingDelay())
    end
end

local function InstallInteractionHooks()
    if hooksInstalled then
        return
    end

    if not RETICLE or not RETICLE.GetInteractPromptVisible or not RETICLE.UpdateInteractText then
        hookAttempts = hookAttempts + 1
        if hookAttempts < 10 then
            zo_callLater(InstallInteractionHooks, 1000)
        end
        return
    end

    hooksInstalled = true

    local originalGetInteractPromptVisible = RETICLE.GetInteractPromptVisible
    RETICLE.GetInteractPromptVisible = function(self, ...)
        if ShouldBlockInteractions() then
            ShowBlockedInteractionMessage()
            return false
        end

        return originalGetInteractPromptVisible(self, ...)
    end

    local originalUpdateInteractText = RETICLE.UpdateInteractText
    RETICLE.UpdateInteractText = function(self, ...)
        local result = originalUpdateInteractText(self, ...)

        if ShouldBlockInteractions() then
            SetReticleBlockedMessage()
        end

        return result
    end
end

local function InstallTrainingHooks()
    if trainingHooksInstalled or not EVENT_MANAGER then
        return
    end

    trainingHooksInstalled = true
    if EVENT_RIDING_SKILL_IMPROVEMENT then
        EVENT_MANAGER:RegisterForEvent(TRAINING_CHECK_NAMESPACE, EVENT_RIDING_SKILL_IMPROVEMENT, function()
            trainingReminderShown = false
            zo_callLater(CheckRidingTraining, 1000)
        end)
    end
end

local function UninstallTrainingHooks()
    if not trainingHooksInstalled or not EVENT_MANAGER then
        return
    end

    trainingHooksInstalled = false
    if EVENT_RIDING_SKILL_IMPROVEMENT then
        EVENT_MANAGER:UnregisterForEvent(TRAINING_CHECK_NAMESPACE, EVENT_RIDING_SKILL_IMPROVEMENT)
    end
end

function Mounts.InitializeSavedVariables()
    savedVariables = NQOL.Settings.NewAccountWide(defaults)
    GetSettings()
end

function Mounts.Initialize()
    InstallInteractionHooks()
    if Mounts.GetTrainingCheck() then
        InstallTrainingHooks()
        zo_callLater(CheckRidingTraining, 1500)
    end
end

function Mounts.GetRemainMounted()
    if not savedVariables then
        return defaults.mounts.remainMounted
    end

    return GetSettings().remainMounted
end

function Mounts.SetRemainMounted(value)
    GetSettings().remainMounted = value == true
end

function Mounts.GetAllowUseInteractions()
    if not savedVariables then
        return defaults.mounts.allowUseInteractions
    end

    return GetSettings().allowUseInteractions
end

function Mounts.SetAllowUseInteractions(value)
    GetSettings().allowUseInteractions = value == true
end

function Mounts.GetAllowOpenInteractions()
    if not savedVariables then
        return defaults.mounts.allowOpenInteractions
    end

    return GetSettings().allowOpenInteractions
end

function Mounts.SetAllowOpenInteractions(value)
    GetSettings().allowOpenInteractions = value == true
end

function Mounts.GetAllowTalkInteractions()
    if not savedVariables then
        return defaults.mounts.allowTalkInteractions
    end

    return GetSettings().allowTalkInteractions
end

function Mounts.SetAllowTalkInteractions(value)
    GetSettings().allowTalkInteractions = value == true
end

function Mounts.GetAllowActivateInteractions()
    if not savedVariables then
        return defaults.mounts.allowActivateInteractions
    end

    return GetSettings().allowActivateInteractions
end

function Mounts.SetAllowActivateInteractions(value)
    GetSettings().allowActivateInteractions = value == true
end

function Mounts.GetTrainingCheck()
    if not savedVariables then
        return defaults.mounts.trainingCheck
    end

    return GetSettings().trainingCheck
end

function Mounts.SetTrainingCheck(value)
    GetSettings().trainingCheck = value == true

    if GetSettings().trainingCheck then
        InstallTrainingHooks()
        trainingReminderShown = false
        CheckRidingTraining()
    else
        StopRidingTrainingChecks()
        UninstallTrainingHooks()
    end
end

function Mounts.GetRemainMountedLabel()
    return NQOL.L("features.mounts.remain_mounted_label")
end

function Mounts.GetRemainMountedTooltip()
    return NQOL.L("features.mounts.remain_mounted_tooltip")
end

function Mounts.GetAllowUseInteractionsLabel()
    return NQOL.L("features.mounts.allow_use_interactions_label")
end

function Mounts.GetAllowUseInteractionsTooltip()
    return NQOL.L("features.mounts.allow_use_interactions_tooltip")
end

function Mounts.GetAllowOpenInteractionsLabel()
    return NQOL.L("features.mounts.allow_open_interactions_label")
end

function Mounts.GetAllowOpenInteractionsTooltip()
    return NQOL.L("features.mounts.allow_open_interactions_tooltip")
end

function Mounts.GetAllowTalkInteractionsLabel()
    return NQOL.L("features.mounts.allow_talk_interactions_label")
end

function Mounts.GetAllowTalkInteractionsTooltip()
    return NQOL.L("features.mounts.allow_talk_interactions_tooltip")
end

function Mounts.GetAllowActivateInteractionsLabel()
    return NQOL.L("features.mounts.allow_activate_interactions_label", GetString(SI_BINDING_NAME_RIGHT_MOUSE_IN_WORLD))
end

function Mounts.GetAllowActivateInteractionsTooltip()
    return NQOL.L("features.mounts.allow_activate_interactions_tooltip", GetString(SI_BINDING_NAME_RIGHT_MOUSE_IN_WORLD))
end

function Mounts.GetTrainingCheckLabel()
    return NQOL.L("features.mounts.training_check_label")
end

function Mounts.GetTrainingCheckTooltip()
    return NQOL.L("features.mounts.training_check_tooltip")
end

NQOL.Features.Mounts = Mounts
