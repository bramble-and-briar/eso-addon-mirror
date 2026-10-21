local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_AdventureCamera"
local UPDATE_NAMESPACE = EVENT_NAMESPACE .. "_Transition"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local AdventureCamera = {}
NAGA_UI.AdventureCamera = AdventureCamera

local CAMERA_SETTINGS =
{
    horizontalLookSpeed = CAMERA_SETTING_SENSITIVITY_THIRD_PERSON_X,
    verticalLookSpeed = CAMERA_SETTING_SENSITIVITY_THIRD_PERSON_Y,
    fieldOfView = CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW,
    horizontalPosition = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER,
    horizontalOffset = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET,
    verticalOffset = CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET,
}

local CAMERA_SETTING_KEYS =
{
    "horizontalLookSpeed",
    "verticalLookSpeed",
    "fieldOfView",
    "horizontalPosition",
    "horizontalOffset",
    "verticalOffset",
}

local DEFAULT_PROFILE =
{
    horizontalLookSpeed = 0.85,
    verticalLookSpeed = 0.85,
    fieldOfView = 50,
    horizontalPosition = 1,
    horizontalOffset = 0,
    verticalOffset = 0,
}

local function GetSettings()
    if NAGA_UI.Settings then
        return NAGA_UI.Settings:GetAdventureCamera()
    end

    return nil
end

local function IsModuleEnabled()
    return NAGA_UI.Settings and NAGA_UI.Settings:IsAdventureCameraEnabled()
end

local function ReadCameraValue(key)
    local settingId = CAMERA_SETTINGS[key]
    if not settingId then
        return DEFAULT_PROFILE[key] or 0
    end

    local value = tonumber(GetSetting(SETTING_TYPE_CAMERA, settingId))
    if value == nil then
        value = DEFAULT_PROFILE[key] or 0
    end

    return value
end

local function WriteCameraValue(key, value)
    local settingId = CAMERA_SETTINGS[key]
    if settingId then
        SetSetting(SETTING_TYPE_CAMERA, settingId, tostring(value))
    end
end

local function CopyProfile(profile)
    local copy = {}
    profile = profile or DEFAULT_PROFILE

    for _, key in ipairs(CAMERA_SETTING_KEYS) do
        local value = tonumber(profile[key])
        if value == nil then
            value = DEFAULT_PROFILE[key] or 0
        end
        copy[key] = value
    end

    return copy
end

function AdventureCamera:CaptureCurrentProfile()
    local profile = {}
    for _, key in ipairs(CAMERA_SETTING_KEYS) do
        profile[key] = ReadCameraValue(key)
    end
    return profile
end

function AdventureCamera:InitializeProfilesIfNeeded()
    if not NAGA_UI.Settings or not NAGA_UI.Settings.InitializeAdventureCameraProfilesIfNeeded then
        return
    end

    NAGA_UI.Settings:InitializeAdventureCameraProfilesIfNeeded()
end

function AdventureCamera:StopTransition()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE)
    self.transition = nil
end

function AdventureCamera:ApplyProfile(profile)
    self:StopTransition()

    profile = CopyProfile(profile)
    for _, key in ipairs(CAMERA_SETTING_KEYS) do
        WriteCameraValue(key, profile[key])
    end
end

function AdventureCamera:GetCurrentTargetProfile()
    local settings = GetSettings()
    if not settings then
        return DEFAULT_PROFILE
    end

    if self.inCombat then
        return settings.actionProfile or DEFAULT_PROFILE
    end

    return settings.adventureProfile or DEFAULT_PROFILE
end

function AdventureCamera:TransitionToProfile(profile)
    profile = CopyProfile(profile)

    local settings = GetSettings()
    local durationMS = settings and tonumber(settings.transitionMS) or 0
    durationMS = zo_clamp(durationMS or 0, 0, 3000)

    local startProfile = self:CaptureCurrentProfile()
    if durationMS <= 0 then
        self:ApplyProfile(profile)
        return
    end

    local startMS = GetFrameTimeMilliseconds()
    self.transition =
    {
        startProfile = startProfile,
        targetProfile = profile,
        startMS = startMS,
        durationMS = durationMS,
    }

    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAMESPACE, 0, function()
        AdventureCamera:OnTransitionUpdate()
    end)
end

function AdventureCamera:OnTransitionUpdate()
    local transition = self.transition
    if not transition then
        self:StopTransition()
        return
    end

    local elapsedMS = GetFrameTimeMilliseconds() - transition.startMS
    local progress = zo_clamp(elapsedMS / transition.durationMS, 0, 1)

    for _, key in ipairs(CAMERA_SETTING_KEYS) do
        local startValue = transition.startProfile[key] or DEFAULT_PROFILE[key] or 0
        local targetValue = transition.targetProfile[key] or DEFAULT_PROFILE[key] or 0
        WriteCameraValue(key, startValue + ((targetValue - startValue) * progress))
    end

    if progress >= 1 then
        self:StopTransition()
    end
end

function AdventureCamera:ApplyCurrentState(instant)
    if not IsModuleEnabled() then
        self:RestoreActionProfile()
        return
    end

    self:InitializeProfilesIfNeeded()
    self.inCombat = IsUnitInCombat("player") == true

    local targetProfile = self:GetCurrentTargetProfile()
    if instant then
        self:ApplyProfile(targetProfile)
    else
        self:TransitionToProfile(targetProfile)
    end
end

function AdventureCamera:RestoreActionProfile()
    local settings = GetSettings()
    self:StopTransition()

    if settings and settings.initialized and settings.actionProfile then
        self:ApplyProfile(settings.actionProfile)
    end
end


function AdventureCamera:OnCombatStateChanged(inCombat)
    if not IsModuleEnabled() then
        return
    end

    self.inCombat = inCombat == true
    self:TransitionToProfile(self:GetCurrentTargetProfile())
end

function AdventureCamera:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        self:ApplyCurrentState(true)
    end)

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Combat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        self:OnCombatStateChanged(inCombat)
    end)

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        self:RestoreActionProfile()
    end)

    self.eventsRegistered = true
end

function AdventureCamera:RefreshSettings()
    self:RegisterEvents()

    if IsModuleEnabled() then
        self:ApplyCurrentState(true)
    else
        self:RestoreActionProfile()
    end
end

NAGA_UI.OnAddonLoaded(function()
    AdventureCamera:RefreshSettings()
end)
