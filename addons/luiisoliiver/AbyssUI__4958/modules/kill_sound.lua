local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_KillSound"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local KillSound = {}
NAGA_UI.KillSound = KillSound

local DEFAULT_SETTINGS =
{
    enabled = true,
    soundKey = "CODE_REDEMPTION_SUCCESS",
}

local FALLBACK_SOUND_KEYS =
{
    "CODE_REDEMPTION_SUCCESS",
    "BATTLEGROUND_LEAVE_MATCH",
}

local function AddFlag(target, key)
    if key ~= nil then
        target[key] = true
    end
end

local KILL_RESULTS = {}
AddFlag(KILL_RESULTS, ACTION_RESULT_DIED)
AddFlag(KILL_RESULTS, ACTION_RESULT_DIED_XP)
AddFlag(KILL_RESULTS, ACTION_RESULT_KILLING_BLOW)

local PLAYER_SOURCE_TYPES = {}
AddFlag(PLAYER_SOURCE_TYPES, COMBAT_UNIT_TYPE_PLAYER)
AddFlag(PLAYER_SOURCE_TYPES, COMBAT_UNIT_TYPE_PLAYER_PET)
AddFlag(PLAYER_SOURCE_TYPES, COMBAT_UNIT_TYPE_PLAYER_COMPANION)

local PLAYER_TARGET_TYPES = {}
AddFlag(PLAYER_TARGET_TYPES, COMBAT_UNIT_TYPE_PLAYER)
AddFlag(PLAYER_TARGET_TYPES, COMBAT_UNIT_TYPE_PLAYER_PET)
AddFlag(PLAYER_TARGET_TYPES, COMBAT_UNIT_TYPE_PLAYER_COMPANION)

local function RegisterFilteredCombatEvent(namespace, sourceType, result, callback)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, callback)
    EVENT_MANAGER:AddFilterForEvent(
        namespace,
        EVENT_COMBAT_EVENT,
        REGISTER_FILTER_IS_ERROR, false,
        REGISTER_FILTER_COMBAT_RESULT, result,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, sourceType
    )
end

local function GetSettings()
    if NAGA_UI.Settings then
        return NAGA_UI.Settings:GetKillSound()
    end

    return DEFAULT_SETTINGS
end

local function GetSettingValue(key)
    local settings = GetSettings()
    local value = settings and settings[key]
    if value == nil then
        return DEFAULT_SETTINGS[key]
    end

    return value
end

local function IsModuleEnabled()
    return not NAGA_UI.Settings or NAGA_UI.Settings:IsKillSoundEnabled()
end

local function GetKillingBlowSound()
    local configuredKey = GetSettingValue("soundKey")
    if configuredKey == "BATTLEGROUND_KILL_KILLING_BLOW" then
        configuredKey = DEFAULT_SETTINGS.soundKey
    end

    if configuredKey and SOUNDS[configuredKey] then
        return SOUNDS[configuredKey]
    end

    for _, fallbackKey in ipairs(FALLBACK_SOUND_KEYS) do
        if SOUNDS[fallbackKey] then
            return SOUNDS[fallbackKey]
        end
    end
end

function KillSound:PreviewSound()
    local sound = GetKillingBlowSound()
    if sound then
        PlaySound(sound)
    end
end

function KillSound:OnCombatEvent(result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType)
    if isError or not KILL_RESULTS[result] then
        return
    end

    if not PLAYER_SOURCE_TYPES[sourceType] or PLAYER_TARGET_TYPES[targetType] then
        return
    end

    self:PreviewSound()
end

function KillSound:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    local callback = function(_, ...)
        self:OnCombatEvent(...)
    end

    self.eventNamespaces = {}
    for result in pairs(KILL_RESULTS) do
        for sourceType in pairs(PLAYER_SOURCE_TYPES) do
            local namespace = string.format("%s_Source_%s_%s", EVENT_NAMESPACE, tostring(sourceType), tostring(result))
            RegisterFilteredCombatEvent(namespace, sourceType, result, callback)
            table.insert(self.eventNamespaces, namespace)
        end
    end

    self.eventsRegistered = true
end

function KillSound:UnregisterEvents()
    if not self.eventsRegistered then
        return
    end

    for _, namespace in ipairs(self.eventNamespaces or {}) do
        EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_COMBAT_EVENT)
    end
    self.eventNamespaces = nil
    self.eventsRegistered = nil
end

function KillSound:RefreshSettings()
    if IsModuleEnabled() then
        self:RegisterEvents()
    else
        self:UnregisterEvents()
    end
end

NAGA_UI.OnAddonLoaded(function()
    KillSound:RefreshSettings()
end)
