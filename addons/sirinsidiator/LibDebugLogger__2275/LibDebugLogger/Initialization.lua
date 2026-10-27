-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

local lib = LibDebugLogger
local internal = lib.internal

local strformat = string.format
local tconcat = table.concat
local traceback = debug.traceback
local zo_strformat = zo_strformat
local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local LDL_LOGGER_CONFIG = {
    tag = lib.id
}
local LDL_LOGGER_PERF_CONFIG = {
    tag = lib.id .. "/" .. "PerformanceStats"
}

local UNKNOWN_STATE_STRING = "unknown state (%d)"
local STATE_STRING = {
    [ADDON_STATE_NO_STATE] = "no state",
    [ADDON_STATE_TOC_LOADED] = "toc loaded",
    [ADDON_STATE_ENABLED] = "enabled",
    [ADDON_STATE_DISABLED] = "disabled",
    [ADDON_STATE_VERSION_MISMATCH] = "out of date",
    [ADDON_STATE_DEPENDENCIES_DISABLED] = "missing dependency",
    [ADDON_STATE_ERROR_STATE_UNABLE_TO_LOAD] = "failed to load",
}
local PLATFORMS = {
    [PLATFORM_SERVICE_TYPE_ZOS] = "PC",
    [PLATFORM_SERVICE_TYPE_PSN] = "Playstation",
    [PLATFORM_SERVICE_TYPE_XBL] = "Xbox",
    [PLATFORM_SERVICE_TYPE_STEAM] = "PC - Steam",
    [PLATFORM_SERVICE_TYPE_EPIC] = "PC - Epic",
}
if GetAPIVersion() < 101052 then
    PLATFORMS[PLATFORM_SERVICE_TYPE_DMM] = "PC - DMM"
end

local FULLSCREEN_MODE = {
    [tostring(FULLSCREEN_MODE_FULLSCREEN_EXCLUSIVE)] = "fullscreen",
    [tostring(FULLSCREEN_MODE_FULLSCREEN_WINDOWED)] = "fullscreen windowed",
    [tostring(FULLSCREEN_MODE_WINDOWED)] = "windowed",
}

local GAMEPAD_TYPE = {
    [GAMEPAD_TYPE_NONE] = "no gamepad",
    [GAMEPAD_TYPE_XBOX] = "xbox gamepad",
    [GAMEPAD_TYPE_PS4] = "ps4 gamepad",
    [GAMEPAD_TYPE_SWITCH] = "switch gamepad",
    [GAMEPAD_TYPE_STADIA] = "stadia gamepad",
    [GAMEPAD_TYPE_PS5] = "ps5 gamepad",
    [GAMEPAD_TYPE_XBSX] = "xbox series-x gamepad",
    [GAMEPAD_TYPE_DEPRECATED] = "deprecated"
}
-- player info logging

local AddOnManager = GetAddOnManager()
local numAddons = AddOnManager:GetNumAddOns()
local numEnabledAddons = 0
local addOnInfo = {}
local skippedAddOnInfo = {}

local function GetMissingDependencyInfo(i)
    local info = {}
    for j = 1, AddOnManager:GetAddOnNumDependencies(i) do
        local dependencyName, dependencyExists, dependencyActive, dependencyMinVersion, dependencyVersion = AddOnManager:GetAddOnDependencyInfo(i, j)
        local dependencyTooLowVersion = dependencyVersion < dependencyMinVersion
        if not dependencyActive or not dependencyExists or dependencyTooLowVersion then
            local reason
            if not dependencyExists then
                reason = "missing"
            elseif not dependencyActive then
                reason = "disabled"
            elseif dependencyTooLowVersion then
                reason = "outdated"
            end
            info[#info + 1] = string.format("%s: %s", reason, dependencyName)
        end
    end
    if #info > 0 then
        return string.format(" (%s)", table.concat(info, ", "))
    end
    return ""
end

for i = 1, numAddons do
    local name, _, _, _, enabled, state = AddOnManager:GetAddOnInfo(i)
    local version = AddOnManager:GetAddOnVersion(i)
    local directory = AddOnManager:GetAddOnRootDirectoryPath(i)
    if(enabled) then
        if(state == ADDON_STATE_ENABLED) then
            addOnInfo[name] = strformat("Addon loaded: %s, AddOnVersion: %d, directory: '%s'", name, version, directory)
        else
            local stateString = STATE_STRING[state] or UNKNOWN_STATE_STRING:format(state)
            if state == ADDON_STATE_DEPENDENCIES_DISABLED then
                stateString = stateString .. GetMissingDependencyInfo(i)
            end
            skippedAddOnInfo[name] = strformat("Did not load addon: %s, AddOnVersion: %d, directory: '%s', state: %s", name, version, directory, stateString)
        end
        numEnabledAddons = numEnabledAddons + 1
    end
end

local function GenerateDebugInfo()
    local buildInfo = ScriptBuildInfo()
    local graphicsInfo = {
        GetCVar("GraphicsDriver.7"), 
    }
    if IsMacUI() then
        graphicsInfo[#graphicsInfo + 1] = "mac ui"
    end
    if IsMinSpecMachine() then
        graphicsInfo[#graphicsInfo + 1] = "min spec"
    end

    local customScale
    if GetSetting(SETTING_TYPE_UI, UI_SETTING_USE_CUSTOM_SCALE) == "1" then
        customScale = strformat("custom scale (%s; %s)", tostring(GetUICustomScale()), tostring(GetUIGlobalScale()))
    else
        customScale = strformat("default scale (%s)", tostring(GetUIGlobalScale()))
    end

    local debugInfo = {
        "", -- for the first line break
        GetDisplayName(),
        GetUnitName("player"),
        internal.FormatTime(internal.SESSION_START_TIME),
        strformat("%s (%s)", GetESOVersionString(), GetAPIVersion()),
        GetWorldName(),
        strformat("%s (%s)", PLATFORMS[GetPlatformServiceType()], buildInfo["Platform"]),
        IsInGamepadPreferredMode() and "gamepad" or "keyboard",
        IsESOPlusSubscriber() and "eso+" or "regular",
        GetCVar("language.2"),
        GetKeyboardLayout(),
        strformat("addon count: %d/%d", numEnabledAddons, numAddons),
        AddOnManager:GetLoadOutOfDateAddOns() and "allow outdated" or "block outdated",
        strformat("%s (%s)", FULLSCREEN_MODE[GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FULLSCREEN)], tconcat(graphicsInfo, "; ")),
        strformat("%d x %d", GuiRoot:GetWidth(), GuiRoot:GetHeight()),
        customScale,
        GAMEPAD_TYPE[GetMostRecentGamepadType()],
        GetTrialInfo() > 0 and "trial account" or "regular account",
        GetCVar("ForceConsoleFlow.2") == "1" and "force console flow" or "no console flow"
    }
    return tconcat(debugInfo, "\n")
end

local function LogPerformance(trigger, extra)
    if not internal.logPerformanceStats then return end
    internal.Log(internal.LOG_LEVEL_DEBUG, LDL_LOGGER_PERF_CONFIG, "fps: %.2f, latency: %d, memory usage: %d, trigger: %s, extra: %s", GetFramerate(), GetLatency(), collectgarbage("count") * 1024, trigger, extra or "")
end
internal.LogPerformance = LogPerformance

local function LogErrorMessage(errorString, errorCode)
    local message, stacktrace = errorString:match("(.+)\n(stack traceback:.+)")
    if(not message) then message = errorString end

    internal.LogRaw(internal.LOG_LEVEL_ERROR, internal.TAG_INGAME, message, stacktrace, errorCode)
end

local success, debugInfo = pcall(GenerateDebugInfo)
if not success then
    LogErrorMessage(debugInfo)
    debugInfo = ""
end
internal.Log(internal.LOG_LEVEL_INFO, LDL_LOGGER_CONFIG, "Initializing..." .. debugInfo)
LogPerformance("init")

-- ingame logging hooks

EVENT_MANAGER:RegisterForEvent(lib.id, EVENT_LUA_ERROR, function(eventCode, errorString, errorCode)
    if(errorString and not internal.TIME_SYNC_ERROR_CODE[errorCode]) then
        if internal.tlcStacktrace then
            local name = errorString:match("TopLevelControl (.*) cannot be parented to any control but GuiRoot.")
            if name and internal.tlcStacktrace[name] then
                errorString = errorString .. "\n" .. internal.tlcStacktrace[name]
                internal.tlcStacktrace[name] = nil
            end
        end
        LogErrorMessage(errorString, errorCode)
    end
end)

local function LogChatMessage(self, text)
    local stacktrace
    if(internal.settings.logTraces) then
        stacktrace = traceback()
    end

    internal.LogRaw(internal.LOG_LEVEL_INFO, internal.TAG_INGAME, text, stacktrace)
    return internal.blockChatOutput
end

-- ZO_ChatRouter is local, so we have no other choice than to hook the instance, but it's fine since it's the same for everyone
ZO_PreHook(CHAT_ROUTER, "AddDebugMessage", LogChatMessage)

local IGNORED_SOUND_IDS = {
    SOUNDS.ABILITY_NOT_READY,
    SOUNDS.ABILITY_TARGET_OUT_OF_RANGE,
    SOUNDS.ABILITY_TARGET_OUT_OF_LOS,
    SOUNDS.ABILITY_TARGET_IMMUNE,
    SOUNDS.ABILITY_CASTER_SILENCED,
    SOUNDS.ABILITY_CASTER_STUNNED,
    SOUNDS.ABILITY_CASTER_BUSY,
    SOUNDS.ABILITY_TARGET_BAD_TARGET,
    SOUNDS.ABILITY_TARGET_DEAD,
    SOUNDS.ABILITY_CASTER_DEAD,
    SOUNDS.ABILITY_NOT_ENOUGH_STAMINA,
    SOUNDS.ABILITY_NOT_ENOUGH_MAGICKA,
    SOUNDS.ABILITY_NOT_ENOUGH_HEALTH,
    SOUNDS.ABILITY_NOT_ENOUGH_ULTIMATE,
    SOUNDS.ABILITY_FAILED,
    SOUNDS.ABILITY_FAILED_IN_COMBAT,
    SOUNDS.ABILITY_FAILED_REQUIREMENTS,
    SOUNDS.ABILITY_CASTER_FEARED,
    SOUNDS.ABILITY_CASTER_DISORIENTED,
    SOUNDS.ABILITY_TARGET_TOO_CLOSE,
    SOUNDS.ABILITY_WRONG_WEAPON,
    SOUNDS.ABILITY_TARGET_NOT_PVP_FLAGGED,
    SOUNDS.ABILITY_CASTER_PACIFIED,
    SOUNDS.ABILITY_CASTER_LEVITATED,
    SOUNDS.ABILITY_WEAPON_SWAP_FAIL,
    SOUNDS.ABILITY_INVALID_JUSTICE_TARGET,
}
local IS_IGNORED_SOUND_ID = {}
for i = 1, #IGNORED_SOUND_IDS do
    IS_IGNORED_SOUND_ID[IGNORED_SOUND_IDS[i]] = true
end

local function LogAlertMessage(category, soundId, message, ...)
    if(category ~= UI_ALERT_CATEGORY_ERROR or not message or IS_IGNORED_SOUND_ID[soundId]) then return end
    message = zo_strformat(message, ...)
    if(message == "") then return end

    local stacktrace
    if(internal.settings.logTraces) then
        stacktrace = traceback()
    end

    internal.LogRaw(internal.LOG_LEVEL_WARNING, internal.TAG_INGAME, message, stacktrace)
end

ZO_PreHook("ZO_Alert", LogAlertMessage)
ZO_PreHook("ZO_AlertNoSuppression", LogAlertMessage)

if internal.logOriginStacktrace then
    local originalzo_callLater = zo_callLater
    function zo_callLater(originalFunc, ...)
        local stacktrace = debug.traceback()
        local func = function(...)
            internal.originStacktrace = stacktrace
            originalFunc(...)
            internal.originStacktrace = nil
        end
        return originalzo_callLater(func, ...)
    end

    internal.tlcStacktrace = {}
    ZO_PreHook(WINDOW_MANAGER, "CreateControl", function(_, name, parent, type)
        if type == CT_TOPLEVELCONTROL then
            internal.tlcStacktrace[name or ""] = debug.traceback()
        end
    end)
end

if internal.logPerformanceStats then
    local PERFORMANCE_LOG_INTERVAL = 10000
    EVENT_MANAGER:RegisterForUpdate(lib.id .. "PerformanceStats", PERFORMANCE_LOG_INTERVAL, function()
        LogPerformance("interval")
    end)
end

-- loading screen duration logging

local regularLoadingScreen = false
EVENT_MANAGER:RegisterForEvent(lib.id, EVENT_PLAYER_ACTIVATED, function(event, initial)
    -- the "initial" parameter passed to the event is only ever false when the UI was reloaded
    -- to fix this, we track if the event was the first of its kind and set the flag to false otherwise
    if(regularLoadingScreen) then
        initial = false
    else
        for name, message in pairs(addOnInfo) do
            -- should not happen, but we want to know it in case it does
            internal.Log(internal.LOG_LEVEL_WARNING, LDL_LOGGER_CONFIG, "No loaded event detected for %s", name)
        end
        for name, message in pairs(skippedAddOnInfo) do
            internal.Log(internal.LOG_LEVEL_WARNING, LDL_LOGGER_CONFIG, message)
        end
    end

    local now = internal.SESSION_START_TIME + GetGameTimeMilliseconds()
    local duration
    if(initial) then
        duration = now - internal.UI_LOAD_START_TIME
    else
        duration = now - internal.settings.loadScreenStartTime
    end
    local name = initial and "Initial loading" or "Loading"
    local prefix = initial and "approximate " or ""
    local level = regularLoadingScreen and internal.LOG_LEVEL_DEBUG or internal.LOG_LEVEL_INFO
    internal.Log(level, LDL_LOGGER_CONFIG, strformat("%s screen ended (%sduration: %.3fs)", name, prefix, duration / 1000))
    LogPerformance("loadscreen", "end")

    regularLoadingScreen = true
end)

EVENT_MANAGER:RegisterForEvent(lib.id, EVENT_PLAYER_DEACTIVATED, function(event)
    internal.settings.loadScreenStartTime = internal.SESSION_START_TIME + GetGameTimeMilliseconds()
    internal.Log(internal.LOG_LEVEL_DEBUG, LDL_LOGGER_CONFIG, "Loading screen started")
    LogPerformance("loadscreen", "start")
end)

-- initialization

EVENT_MANAGER:RegisterForEvent(lib.id, EVENT_ADD_ON_LOADED, function(event, name)
    internal.Log(internal.LOG_LEVEL_INFO, LDL_LOGGER_CONFIG, addOnInfo[name] or strformat("UI module loaded: %s", name))
    addOnInfo[name] = nil

    if(name == lib.id) then
        internal:InitializeSettings()
        internal:InitializeLog()

        if rawget(ZO_Object, "__call") then
            local call = ZO_Object.__call
            internal.Log(internal.LOG_LEVEL_WARNING, LDL_LOGGER_CONFIG, "ZO_Object has been modified with a __call metamethod")
        end
        if rawget(ZO_InitializingObject, "__call") then
            local call = ZO_InitializingObject.__call
            internal.Log(internal.LOG_LEVEL_WARNING, LDL_LOGGER_CONFIG, "ZO_InitializingObject has been modified with a __call metamethod")
        end

        internal.Log(internal.LOG_LEVEL_INFO, LDL_LOGGER_CONFIG, "Initialization complete")
    end

    LogPerformance("addon", name)
end)
