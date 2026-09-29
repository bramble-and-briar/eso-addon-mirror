NQOL = NQOL or {}

local GamepadOptions = {}
NQOL.GamepadOptions = GamepadOptions

GamepadOptions.PanelIds = {
    ROOT = 9107,
    MOUNTS = 9108,
    ANTIQUITIES = 9109,
    GEAR = 9110,
    PROVISIONING = 9111,
    MAP = 9112,
    UI = 9113,
    ACTIVE_QUEST = 9114,
    ACTIVE_COMBAT_TIPS = 9142,
    SYNERGY_PROMPTS = 9143,
    CENTER_SCREEN_ANNOUNCE = 9144,
    ANNOUNCEMENTS = 9187,
    CHAT = 9115,
    CHAT_GUILD_COLORS = 9147,
    CHAT_REMINDERS = 9157,
    SOCIAL = 9162,
    FRIENDS = 9163,
    GROUP_FINDER_MONITOR = 9182,
    TICKER = 9116,
    UTILITY = 9117,
    GROUPING = 9118,
    AUTO_INVITE = 9119,
    LUA_GC = 9120,
    AUTO_BOUND = 9122,
    AUTO_CHARGE = 9123,
    AUTO_REPAIR = 9124,
    BUFFS_DEBUFFS = 9125,
    BUFFS_DEBUFFS_TRACKERS = 9126,
    PROGRESS = 9127,
    XP_TRACKER = 9128,
    XP_TIMERS = 9129,
    GOLD_TRACKER = 9130,
    GOLD_TIMERS = 9131,
    DUNGEONS = 9132,
    TRIALS = 9133,
    ARENAS = 9159,
    DLC_DUNGEONS = 9160,
    SOLO_DUNGEONS = 9188,
    FRAME_STYLING = 9134,
    PLAYER_FRAME = 9135,
    PLAYER_FRAME_CLASSIC = 9136,
    PLAYER_FRAME_PYRAMID = 9137,
    PLAYER_FRAME_STACK = 9138,
    PLAYER_FRAME_VERTICAL = 9139,
    PLAYER_FRAME_RADIAL = 9167,
    COMPANION_FRAME = 9140,
    GROUP_FRAME = 9141,
    FISHING = 9145,
    FISHING_TRACKER = 9146,
    LOOT_LOG = 9148,
    PLAYER_INTERACTION = 9149,
    SUBTITLES = 9150,
    COMBAT_RETICLE = 9151,
    DEFAULT_FRAMES = 9152,
    COMBAT = 9153,
    ULTIMATE_COUNTDOWN_FRONT = 9154,
    ULTIMATE_COUNTDOWN_BACK = 9155,
    ULTIMATE_COUNTDOWN = 9156,
    DEBUG = 9158,
    PLAYER_INFO = 9161,
    MINIMAP = 9166,
    INFINITE_ARCHIVE = 9179,
    INFINITE_ARCHIVE_FRAME = 9180,
    COMBAT_INFINITE_ARCHIVE = 9181,
    COMBAT_MISCELLANEOUS = 9183,
    MAP_OPTIONS = 9184,
    TRIAL_TIMER = 9185,
    CAMERA = 9186,
    GPS = 9189,
    RETICLE_INFO = 9190,
    RETICLE_INFO_TOP_LEFT = 9191,
    RETICLE_INFO_TOP_RIGHT = 9192,
    RETICLE_INFO_BOTTOM_LEFT = 9193,
    RETICLE_INFO_BOTTOM_RIGHT = 9194,
}

local PanelIds = GamepadOptions.PanelIds
local ROOT_PANEL_ID = PanelIds.ROOT
local MOUNTS_PANEL_ID = PanelIds.MOUNTS
local ANTIQUITIES_PANEL_ID = PanelIds.ANTIQUITIES
local GEAR_PANEL_ID = PanelIds.GEAR
local PROVISIONING_PANEL_ID = PanelIds.PROVISIONING
local MAP_PANEL_ID = PanelIds.MAP
local MAP_OPTIONS_PANEL_ID = PanelIds.MAP_OPTIONS
local MINIMAP_PANEL_ID = PanelIds.MINIMAP
local GPS_PANEL_ID = PanelIds.GPS
local FISHING_PANEL_ID = PanelIds.FISHING
local FISHING_TRACKER_PANEL_ID = PanelIds.FISHING_TRACKER
local UI_PANEL_ID = PanelIds.UI
local CAMERA_PANEL_ID = PanelIds.CAMERA
local DEFAULT_FRAMES_PANEL_ID = PanelIds.DEFAULT_FRAMES
local COMBAT_RETICLE_PANEL_ID = PanelIds.COMBAT_RETICLE
local RETICLE_INFO_PANEL_ID = PanelIds.RETICLE_INFO
local RETICLE_INFO_TOP_LEFT_PANEL_ID = PanelIds.RETICLE_INFO_TOP_LEFT
local RETICLE_INFO_TOP_RIGHT_PANEL_ID = PanelIds.RETICLE_INFO_TOP_RIGHT
local RETICLE_INFO_BOTTOM_LEFT_PANEL_ID = PanelIds.RETICLE_INFO_BOTTOM_LEFT
local RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID = PanelIds.RETICLE_INFO_BOTTOM_RIGHT
local COMBAT_RETICLE_PREVIEW_PANEL_IDS = {
    [COMBAT_RETICLE_PANEL_ID] = true,
    [RETICLE_INFO_PANEL_ID] = true,
    [RETICLE_INFO_TOP_LEFT_PANEL_ID] = true,
    [RETICLE_INFO_TOP_RIGHT_PANEL_ID] = true,
    [RETICLE_INFO_BOTTOM_LEFT_PANEL_ID] = true,
    [RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID] = true,
}
local ACTIVE_QUEST_PANEL_ID = PanelIds.ACTIVE_QUEST
local ACTIVE_COMBAT_TIPS_PANEL_ID = PanelIds.ACTIVE_COMBAT_TIPS
local SYNERGY_PROMPTS_PANEL_ID = PanelIds.SYNERGY_PROMPTS
local CENTER_SCREEN_ANNOUNCE_PANEL_ID = PanelIds.CENTER_SCREEN_ANNOUNCE
local ANNOUNCEMENTS_PANEL_ID = PanelIds.ANNOUNCEMENTS
local INFINITE_ARCHIVE_FRAME_PANEL_ID = PanelIds.INFINITE_ARCHIVE_FRAME
local LOOT_LOG_PANEL_ID = PanelIds.LOOT_LOG
local PLAYER_INFO_PANEL_ID = PanelIds.PLAYER_INFO
local PLAYER_INTERACTION_PANEL_ID = PanelIds.PLAYER_INTERACTION
local SUBTITLES_PANEL_ID = PanelIds.SUBTITLES
local COMBAT_PANEL_ID = PanelIds.COMBAT
local COMBAT_INFINITE_ARCHIVE_PANEL_ID = PanelIds.COMBAT_INFINITE_ARCHIVE
local COMBAT_MISCELLANEOUS_PANEL_ID = PanelIds.COMBAT_MISCELLANEOUS
local TRIAL_TIMER_PANEL_ID = PanelIds.TRIAL_TIMER
local ULTIMATE_COUNTDOWN_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN
local ULTIMATE_COUNTDOWN_FRONT_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN_FRONT
local ULTIMATE_COUNTDOWN_BACK_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN_BACK
local DEBUG_PANEL_ID = PanelIds.DEBUG
local CHAT_PANEL_ID = PanelIds.CHAT
local CHAT_GUILD_COLORS_PANEL_ID = PanelIds.CHAT_GUILD_COLORS
local CHAT_REMINDERS_PANEL_ID = PanelIds.CHAT_REMINDERS
local SOCIAL_PANEL_ID = PanelIds.SOCIAL
local FRIENDS_PANEL_ID = PanelIds.FRIENDS
local GROUP_FINDER_MONITOR_PANEL_ID = PanelIds.GROUP_FINDER_MONITOR
local TICKER_PANEL_ID = PanelIds.TICKER
local UTILITY_PANEL_ID = PanelIds.UTILITY
local GROUPING_PANEL_ID = PanelIds.GROUPING
local AUTO_INVITE_PANEL_ID = PanelIds.AUTO_INVITE
local LUA_GC_PANEL_ID = PanelIds.LUA_GC
local AUTO_BOUND_PANEL_ID = PanelIds.AUTO_BOUND
local AUTO_CHARGE_PANEL_ID = PanelIds.AUTO_CHARGE
local AUTO_REPAIR_PANEL_ID = PanelIds.AUTO_REPAIR
local BUFFS_DEBUFFS_PANEL_ID = PanelIds.BUFFS_DEBUFFS
local BUFFS_DEBUFFS_TRACKERS_PANEL_ID = PanelIds.BUFFS_DEBUFFS_TRACKERS
local PROGRESS_PANEL_ID = PanelIds.PROGRESS
local XP_TRACKER_PANEL_ID = PanelIds.XP_TRACKER
local XP_TIMERS_PANEL_ID = PanelIds.XP_TIMERS
GamepadOptions.GOLD_TRACKER_PANEL_ID = PanelIds.GOLD_TRACKER
GamepadOptions.GOLD_TIMERS_PANEL_ID = PanelIds.GOLD_TIMERS
GamepadOptions.DUNGEONS_PANEL_ID = PanelIds.DUNGEONS
GamepadOptions.DLC_DUNGEONS_PANEL_ID = PanelIds.DLC_DUNGEONS
GamepadOptions.TRIALS_PANEL_ID = PanelIds.TRIALS
GamepadOptions.ARENAS_PANEL_ID = PanelIds.ARENAS
GamepadOptions.SOLO_DUNGEONS_PANEL_ID = PanelIds.SOLO_DUNGEONS
GamepadOptions.INFINITE_ARCHIVE_PANEL_ID = PanelIds.INFINITE_ARCHIVE
GamepadOptions.FRAME_STYLING_PANEL_ID = PanelIds.FRAME_STYLING
GamepadOptions.PLAYER_FRAME_PANEL_ID = PanelIds.PLAYER_FRAME
GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID = PanelIds.PLAYER_FRAME_CLASSIC
GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID = PanelIds.PLAYER_FRAME_PYRAMID
GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID = PanelIds.PLAYER_FRAME_STACK
GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID = PanelIds.PLAYER_FRAME_VERTICAL
GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID = PanelIds.PLAYER_FRAME_RADIAL
GamepadOptions.COMPANION_FRAME_PANEL_ID = PanelIds.COMPANION_FRAME
GamepadOptions.GROUP_FRAME_PANEL_ID = PanelIds.GROUP_FRAME
GamepadOptions.ACTIVE_COMBAT_TIPS_PANEL_ID = PanelIds.ACTIVE_COMBAT_TIPS
GamepadOptions.SYNERGY_PROMPTS_PANEL_ID = PanelIds.SYNERGY_PROMPTS
GamepadOptions.CENTER_SCREEN_ANNOUNCE_PANEL_ID = PanelIds.CENTER_SCREEN_ANNOUNCE
GamepadOptions.ANNOUNCEMENTS_PANEL_ID = PanelIds.ANNOUNCEMENTS
GamepadOptions.FISHING_PANEL_ID = PanelIds.FISHING
GamepadOptions.FISHING_TRACKER_PANEL_ID = PanelIds.FISHING_TRACKER
GamepadOptions.CAMERA_PANEL_ID = PanelIds.CAMERA
GamepadOptions.LOOT_LOG_PANEL_ID = PanelIds.LOOT_LOG
GamepadOptions.PLAYER_INFO_PANEL_ID = PanelIds.PLAYER_INFO
GamepadOptions.PLAYER_INTERACTION_PANEL_ID = PanelIds.PLAYER_INTERACTION
GamepadOptions.SUBTITLES_PANEL_ID = PanelIds.SUBTITLES
GamepadOptions.COMBAT_PANEL_ID = PanelIds.COMBAT
GamepadOptions.RETICLE_INFO_PANEL_ID = PanelIds.RETICLE_INFO
GamepadOptions.RETICLE_INFO_TOP_LEFT_PANEL_ID = PanelIds.RETICLE_INFO_TOP_LEFT
GamepadOptions.RETICLE_INFO_TOP_RIGHT_PANEL_ID = PanelIds.RETICLE_INFO_TOP_RIGHT
GamepadOptions.RETICLE_INFO_BOTTOM_LEFT_PANEL_ID = PanelIds.RETICLE_INFO_BOTTOM_LEFT
GamepadOptions.RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID = PanelIds.RETICLE_INFO_BOTTOM_RIGHT
GamepadOptions.COMBAT_INFINITE_ARCHIVE_PANEL_ID = PanelIds.COMBAT_INFINITE_ARCHIVE
GamepadOptions.COMBAT_MISCELLANEOUS_PANEL_ID = PanelIds.COMBAT_MISCELLANEOUS
GamepadOptions.TRIAL_TIMER_PANEL_ID = PanelIds.TRIAL_TIMER
GamepadOptions.ULTIMATE_COUNTDOWN_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN
GamepadOptions.ULTIMATE_COUNTDOWN_FRONT_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN_FRONT
GamepadOptions.ULTIMATE_COUNTDOWN_BACK_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN_BACK
GamepadOptions.DEBUG_PANEL_ID = PanelIds.DEBUG
GamepadOptions.SOCIAL_PANEL_ID = PanelIds.SOCIAL
GamepadOptions.FRIENDS_PANEL_ID = PanelIds.FRIENDS
GamepadOptions.GROUP_FINDER_MONITOR_PANEL_ID = PanelIds.GROUP_FINDER_MONITOR
local CATEGORY_NAME = "|cff0000N|r|c007fffQOL|r"
local ADDONS_MENU_ICON = "/esoui/art/options/gamepad/gp_options_addons.dds"
local ADDON_ENTRY_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds"
local SHARED_ADDONS_MENU_ENTRY_ID = "LibHarvensAddonSettings"
-- NGear already uses this fallback ID. Sharing it lets either add-on create
-- the temporary Add-ons root without producing duplicate top-level entries.
local FALLBACK_ADDONS_MENU_ENTRY_ID = "NGear_AddonsRoot"
local MAIN_MENU_ENTRY_ID = "NQOL_Addons"
local CLEAR_SAVED_FOOD_DIALOG_NAME = "NQOL_CLEAR_AUTO_FOOD_SAVED_FOOD"
local CHAT_MISSING_ITEM_WHISPER_MESSAGE_DIALOG_NAME = "NQOL_CHAT_MISSING_ITEM_WHISPER_MESSAGE"
local AUTO_INVITE_TEXT_DIALOG_NAME = "NQOL_AUTO_INVITE_TEXT"
local GROUP_FINDER_MONITOR_ALARM_TEXT_DIALOG_NAME = "NQOL_GROUP_FINDER_MONITOR_ALARM_TEXT"
local LANGUAGE_RELOAD_DIALOG_NAME = "NQOL_LANGUAGE_RELOAD_CONFIRM"
GamepadOptions.XP_RESET_TIMERS_DIALOG_NAME = "NQOL_XP_RESET_TIMERS"
GamepadOptions.GOLD_RESET_TIMERS_DIALOG_NAME = "NQOL_GOLD_RESET_TIMERS"
GamepadOptions.resetTimersDialogsRegistered = {}
local languageReloadDialogRegistered = false
local pendingLanguagePreference
local DEFERRED_SLIDER_APPLY_MS = 150
local Clamp = NQOL.Util.Clamp
local PANEL_RESET_PATHS
local panelResetInProgress = {}

local function RoundColorChannel(value)
    return math.floor((Clamp(tonumber(value) or 0, 0, 1) * 255) + 0.5)
end

local function ResolveNumericOptionValue(value)
    if type(value) == "function" then
        value = value()
    end

    return tonumber(value)
end

local function ResolveTextEntry(textEntry, control)
    if type(textEntry) == "function" then
        return textEntry(control)
    elseif type(textEntry) == "number" and GetString then
        return GetString(textEntry)
    end

    return textEntry
end

local function GetNumericValueFormat(valueFormat)
    if type(valueFormat) ~= "string" then
        return "%d"
    end

    return string.match(valueFormat, "(%%[%d%.]*[df])") or "%d"
end

local function FormatSliderLabelValue(value, valueFormat)
    local numericValue = tonumber(value) or 0
    return string.format(GetNumericValueFormat(valueFormat), numericValue)
end

local function BuildSliderLabel(label, valueFormat, getFunc)
    return function(control)
        local labelText = ResolveTextEntry(label, control) or ""
        local value = control and control.data and control.data.nqolLabelValueOverride
        if value == nil then
            value = getFunc()
        end

        return labelText .. " (" .. FormatSliderLabelValue(value, valueFormat) .. ")"
    end
end

function GamepadOptions.ResetNQOLSettingToDefault(control, settingData)
    if not settingData then
        return
    end

    GamepadOptions.ResetPanelOptionsToDefaults(settingData.panel)
end

function GamepadOptions.ResetPanelOptionsToDefaults(panelId)
    if panelResetInProgress[panelId] then
        return
    end

    panelResetInProgress[panelId] = true

    local resetPaths = PANEL_RESET_PATHS[panelId]
    if resetPaths and NQOL.Settings and NQOL.Settings.ResetPath then
        for _, path in ipairs(resetPaths) do
            NQOL.Settings.ResetPath(path)
        end
    end

    GamepadOptions.ApplyPanelOptions(panelId)
    panelResetInProgress[panelId] = nil
end

function GamepadOptions.ResetAllNQOLPanelsToDefaults()
    if NQOL.Settings and NQOL.Settings.ResetAllOptions then
        NQOL.Settings.ResetAllOptions()
    end

    for _, panelId in pairs(GamepadOptions.PanelIds) do
        GamepadOptions.ApplyPanelOptions(panelId)
    end

    GamepadOptions.RefreshCurrentOptionsList()
end

function GamepadOptions.AttachPanelReset(optionsData, panelId)
    if not optionsData or not PANEL_RESET_PATHS[panelId] or #optionsData == 0 then
        return
    end

    if panelId == ROOT_PANEL_ID then
        optionsData[1].customResetToDefaultsFunction = GamepadOptions.ResetAllNQOLPanelsToDefaults
    else
        optionsData[1].customResetToDefaultsFunction = function()
            GamepadOptions.ResetPanelOptionsToDefaults(panelId)
        end
    end
end

function GamepadOptions.ApplyPanelOptions(panelId)
    local panelSettings = GAMEPAD_SETTINGS_DATA and GAMEPAD_SETTINGS_DATA[panelId]
    if not panelSettings or not GAMEPAD_OPTIONS or not GAMEPAD_OPTIONS.GetSettingsData then
        return
    end

    for _, setting in ipairs(panelSettings) do
        local settingData = GAMEPAD_OPTIONS:GetSettingsData(setting.panel, setting.system, setting.settingId)
        if settingData and settingData.GetSettingOverride and settingData.SetSettingOverride then
            settingData.SetSettingOverride(nil, settingData.GetSettingOverride())
        end
    end
end

local function GetPositionSliderStepPercent(minValue, maxValue)
    local positioning = NQOL.Features and NQOL.Features.Positioning
    local stepSize = 5
    if positioning and positioning.GetSliderStepSize then
        stepSize = tonumber(positioning.GetSliderStepSize()) or stepSize
    end

    local range = maxValue - minValue
    if range <= 0 then
        return nil
    end

    return (stepSize / range) * 100
end

local function GetValueSliderStepPercent(minValue, maxValue, stepSize)
    minValue = ResolveNumericOptionValue(minValue) or 0
    maxValue = ResolveNumericOptionValue(maxValue) or minValue
    stepSize = tonumber(stepSize)

    local range = maxValue - minValue
    if not stepSize or stepSize <= 0 or range <= 0 then
        return nil
    end

    return (stepSize / range) * 100
end

local function RgbaToHex(red, green, blue, alpha)
    red = Clamp(tonumber(red) or 1, 0, 1)
    green = Clamp(tonumber(green) or 1, 0, 1)
    blue = Clamp(tonumber(blue) or 1, 0, 1)
    alpha = Clamp(tonumber(alpha) or 1, 0, 1)

    if ZO_ColorDef and ZO_ColorDef.FloatsToHex then
        return ZO_ColorDef.FloatsToHex(red, green, blue, alpha)
    end

    if alpha >= 1 then
        return string.format("%02X%02X%02X", RoundColorChannel(red), RoundColorChannel(green), RoundColorChannel(blue))
    end

    return string.format("%02X%02X%02X%02X", RoundColorChannel(alpha), RoundColorChannel(red), RoundColorChannel(green), RoundColorChannel(blue))
end

local function HexToRgba(value)
    if type(value) ~= "string" then
        return 1, 1, 1, 1
    end

    local hex = value:gsub("#", "")
    if #hex == 6 then
        local red = tonumber(hex:sub(1, 2), 16)
        local green = tonumber(hex:sub(3, 4), 16)
        local blue = tonumber(hex:sub(5, 6), 16)
        if red and green and blue then
            return red / 255, green / 255, blue / 255, 1
        end
    elseif #hex == 8 then
        local alpha = tonumber(hex:sub(1, 2), 16)
        local red = tonumber(hex:sub(3, 4), 16)
        local green = tonumber(hex:sub(5, 6), 16)
        local blue = tonumber(hex:sub(7, 8), 16)
        if alpha and red and green and blue then
            return red / 255, green / 255, blue / 255, alpha / 255
        end
    end

    return 1, 1, 1, 1
end

local colorClickHooked = false
local headerVersionHooked = false
local backOverrideInstalled = false
local panelsRegistered = false
local sharedAddonsMenuHookInstalled = false
local mainMenuWatcherInstalled = false
local clearSavedFoodDialogRegistered = false
local chatMissingItemWhisperMessageDialogRegistered = false
local autoInviteTextDialogRegistered = false
local groupFinderMonitorAlarmTextDialogRegistered = false
GamepadOptions.parentSelectionByChildPanel = {}

local SUBPANEL_PARENT_IDS = {
    [MOUNTS_PANEL_ID] = ROOT_PANEL_ID,
    [ANTIQUITIES_PANEL_ID] = ROOT_PANEL_ID,
    [GEAR_PANEL_ID] = ROOT_PANEL_ID,
    [AUTO_CHARGE_PANEL_ID] = GEAR_PANEL_ID,
    [AUTO_REPAIR_PANEL_ID] = GEAR_PANEL_ID,
    [COMBAT_PANEL_ID] = ROOT_PANEL_ID,
    [COMBAT_INFINITE_ARCHIVE_PANEL_ID] = COMBAT_PANEL_ID,
    [COMBAT_MISCELLANEOUS_PANEL_ID] = COMBAT_PANEL_ID,
    [TRIAL_TIMER_PANEL_ID] = COMBAT_PANEL_ID,
    [ULTIMATE_COUNTDOWN_PANEL_ID] = COMBAT_PANEL_ID,
    [ULTIMATE_COUNTDOWN_FRONT_PANEL_ID] = ULTIMATE_COUNTDOWN_PANEL_ID,
    [ULTIMATE_COUNTDOWN_BACK_PANEL_ID] = ULTIMATE_COUNTDOWN_PANEL_ID,
    [DEBUG_PANEL_ID] = ROOT_PANEL_ID,
    [PROVISIONING_PANEL_ID] = ROOT_PANEL_ID,
    [MAP_PANEL_ID] = ROOT_PANEL_ID,
    [MAP_OPTIONS_PANEL_ID] = MAP_PANEL_ID,
    [MINIMAP_PANEL_ID] = MAP_PANEL_ID,
    [GPS_PANEL_ID] = MAP_PANEL_ID,
    [FISHING_PANEL_ID] = ROOT_PANEL_ID,
    [FISHING_TRACKER_PANEL_ID] = FISHING_PANEL_ID,
    [AUTO_BOUND_PANEL_ID] = GEAR_PANEL_ID,
    [UI_PANEL_ID] = ROOT_PANEL_ID,
    [CAMERA_PANEL_ID] = UI_PANEL_ID,
    [DEFAULT_FRAMES_PANEL_ID] = UI_PANEL_ID,
    [COMBAT_RETICLE_PANEL_ID] = COMBAT_PANEL_ID,
    [RETICLE_INFO_PANEL_ID] = COMBAT_RETICLE_PANEL_ID,
    [RETICLE_INFO_TOP_LEFT_PANEL_ID] = RETICLE_INFO_PANEL_ID,
    [RETICLE_INFO_TOP_RIGHT_PANEL_ID] = RETICLE_INFO_PANEL_ID,
    [RETICLE_INFO_BOTTOM_LEFT_PANEL_ID] = RETICLE_INFO_PANEL_ID,
    [RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID] = RETICLE_INFO_PANEL_ID,
    [ACTIVE_QUEST_PANEL_ID] = DEFAULT_FRAMES_PANEL_ID,
    [ACTIVE_COMBAT_TIPS_PANEL_ID] = DEFAULT_FRAMES_PANEL_ID,
    [SYNERGY_PROMPTS_PANEL_ID] = DEFAULT_FRAMES_PANEL_ID,
    [CENTER_SCREEN_ANNOUNCE_PANEL_ID] = DEFAULT_FRAMES_PANEL_ID,
    [ANNOUNCEMENTS_PANEL_ID] = DEFAULT_FRAMES_PANEL_ID,
    [INFINITE_ARCHIVE_FRAME_PANEL_ID] = DEFAULT_FRAMES_PANEL_ID,
    [LOOT_LOG_PANEL_ID] = UI_PANEL_ID,
    [PLAYER_INFO_PANEL_ID] = UI_PANEL_ID,
    [PLAYER_INTERACTION_PANEL_ID] = DEFAULT_FRAMES_PANEL_ID,
    [SUBTITLES_PANEL_ID] = DEFAULT_FRAMES_PANEL_ID,
    [GamepadOptions.FRAME_STYLING_PANEL_ID] = UI_PANEL_ID,
    [GamepadOptions.PLAYER_FRAME_PANEL_ID] = GamepadOptions.FRAME_STYLING_PANEL_ID,
    [GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID] = GamepadOptions.PLAYER_FRAME_PANEL_ID,
    [GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID] = GamepadOptions.PLAYER_FRAME_PANEL_ID,
    [GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID] = GamepadOptions.PLAYER_FRAME_PANEL_ID,
    [GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID] = GamepadOptions.PLAYER_FRAME_PANEL_ID,
    [GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID] = GamepadOptions.PLAYER_FRAME_PANEL_ID,
    [GamepadOptions.COMPANION_FRAME_PANEL_ID] = GamepadOptions.FRAME_STYLING_PANEL_ID,
    [GamepadOptions.GROUP_FRAME_PANEL_ID] = GamepadOptions.FRAME_STYLING_PANEL_ID,
    [SOCIAL_PANEL_ID] = ROOT_PANEL_ID,
    [CHAT_PANEL_ID] = SOCIAL_PANEL_ID,
    [CHAT_GUILD_COLORS_PANEL_ID] = CHAT_PANEL_ID,
    [CHAT_REMINDERS_PANEL_ID] = CHAT_PANEL_ID,
    [FRIENDS_PANEL_ID] = SOCIAL_PANEL_ID,
    [GROUP_FINDER_MONITOR_PANEL_ID] = SOCIAL_PANEL_ID,
    [TICKER_PANEL_ID] = ROOT_PANEL_ID,
    [UTILITY_PANEL_ID] = ROOT_PANEL_ID,
    [GROUPING_PANEL_ID] = ROOT_PANEL_ID,
    [AUTO_INVITE_PANEL_ID] = GROUPING_PANEL_ID,
    [LUA_GC_PANEL_ID] = UTILITY_PANEL_ID,
    [BUFFS_DEBUFFS_PANEL_ID] = ROOT_PANEL_ID,
    [BUFFS_DEBUFFS_TRACKERS_PANEL_ID] = BUFFS_DEBUFFS_PANEL_ID,
    [PROGRESS_PANEL_ID] = ROOT_PANEL_ID,
    [XP_TRACKER_PANEL_ID] = PROGRESS_PANEL_ID,
    [XP_TIMERS_PANEL_ID] = XP_TRACKER_PANEL_ID,
    [GamepadOptions.GOLD_TRACKER_PANEL_ID] = PROGRESS_PANEL_ID,
    [GamepadOptions.GOLD_TIMERS_PANEL_ID] = GamepadOptions.GOLD_TRACKER_PANEL_ID,
    [GamepadOptions.DUNGEONS_PANEL_ID] = PROGRESS_PANEL_ID,
    [GamepadOptions.DLC_DUNGEONS_PANEL_ID] = PROGRESS_PANEL_ID,
    [GamepadOptions.TRIALS_PANEL_ID] = PROGRESS_PANEL_ID,
    [GamepadOptions.ARENAS_PANEL_ID] = PROGRESS_PANEL_ID,
    [GamepadOptions.SOLO_DUNGEONS_PANEL_ID] = PROGRESS_PANEL_ID,
    [GamepadOptions.INFINITE_ARCHIVE_PANEL_ID] = PROGRESS_PANEL_ID,
}

PANEL_RESET_PATHS = {
    [ROOT_PANEL_ID] = {},
    [MOUNTS_PANEL_ID] = { { "mounts" } },
    [ANTIQUITIES_PANEL_ID] = { { "antiquities" } },
    [GEAR_PANEL_ID] = { { "gear" } },
    [AUTO_CHARGE_PANEL_ID] = { { "gear" } },
    [AUTO_REPAIR_PANEL_ID] = { { "gear" } },
    [AUTO_BOUND_PANEL_ID] = { { "gear" } },
    [COMBAT_PANEL_ID] = { { "trialTimer" }, { "ultimateCountdown" }, { "combat", "infiniteArchive" }, { "combat", "miscellaneous" }, { "ui", "combatReticle" } },
    [COMBAT_INFINITE_ARCHIVE_PANEL_ID] = { { "combat", "infiniteArchive" } },
    [COMBAT_MISCELLANEOUS_PANEL_ID] = { { "combat", "miscellaneous" } },
    [TRIAL_TIMER_PANEL_ID] = { { "trialTimer" } },
    [ULTIMATE_COUNTDOWN_PANEL_ID] = { { "ultimateCountdown" } },
    [ULTIMATE_COUNTDOWN_FRONT_PANEL_ID] = { { "ultimateCountdown", "frontBar" } },
    [ULTIMATE_COUNTDOWN_BACK_PANEL_ID] = { { "ultimateCountdown", "backBar" } },
    [PROVISIONING_PANEL_ID] = { { "provisioning" } },
    [MAP_PANEL_ID] = { { "map" }, { "minimap" }, { "gps" } },
    [MAP_OPTIONS_PANEL_ID] = { { "map" } },
    [MINIMAP_PANEL_ID] = { { "minimap" } },
    [GPS_PANEL_ID] = { { "gps" } },
    [FISHING_PANEL_ID] = { { "fishing" } },
    [FISHING_TRACKER_PANEL_ID] = { { "fishing", "tracker" } },
    [UI_PANEL_ID] = {
        { "ui", "camera" },
        { "ui", "disableAlertTexts" },
        { "ui", "sortDungeonsFinder" },
        { "ui", "activeQuest" },
        { "ui", "activeCombatTips" },
        { "ui", "synergyPrompts" },
        { "ui", "centerScreenAnnounce" },
        { "ui", "announcements" },
        { "ui", "infiniteArchive" },
        { "ui", "playerInteraction" },
        { "ui", "subtitles" },
        { "ui", "lootLog" },
        { "ui", "customFrames" },
        { "ui", "playerInfo" },
    },
    [CAMERA_PANEL_ID] = { { "ui", "camera" } },
    [DEFAULT_FRAMES_PANEL_ID] = { { "ui", "activeQuest" }, { "ui", "activeCombatTips" }, { "ui", "synergyPrompts" }, { "ui", "centerScreenAnnounce" }, { "ui", "announcements" }, { "ui", "infiniteArchive" }, { "ui", "playerInteraction" }, { "ui", "subtitles" } },
    [COMBAT_RETICLE_PANEL_ID] = { { "ui", "combatReticle" } },
    [RETICLE_INFO_PANEL_ID] = { { "ui", "combatReticle", "info" } },
    [RETICLE_INFO_TOP_LEFT_PANEL_ID] = { { "ui", "combatReticle", "info", "topLeft" } },
    [RETICLE_INFO_TOP_RIGHT_PANEL_ID] = { { "ui", "combatReticle", "info", "topRight" } },
    [RETICLE_INFO_BOTTOM_LEFT_PANEL_ID] = { { "ui", "combatReticle", "info", "bottomLeft" } },
    [RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID] = { { "ui", "combatReticle", "info", "bottomRight" } },
    [ACTIVE_QUEST_PANEL_ID] = { { "ui", "activeQuest" } },
    [ACTIVE_COMBAT_TIPS_PANEL_ID] = { { "ui", "activeCombatTips" } },
    [SYNERGY_PROMPTS_PANEL_ID] = { { "ui", "synergyPrompts" } },
    [CENTER_SCREEN_ANNOUNCE_PANEL_ID] = { { "ui", "centerScreenAnnounce" } },
    [ANNOUNCEMENTS_PANEL_ID] = { { "ui", "announcements" } },
    [INFINITE_ARCHIVE_FRAME_PANEL_ID] = { { "ui", "infiniteArchive" } },
    [LOOT_LOG_PANEL_ID] = { { "ui", "lootLog" } },
    [PLAYER_INFO_PANEL_ID] = { { "ui", "playerInfo" } },
    [PLAYER_INTERACTION_PANEL_ID] = { { "ui", "playerInteraction" } },
    [SUBTITLES_PANEL_ID] = { { "ui", "subtitles" } },
    [GamepadOptions.FRAME_STYLING_PANEL_ID] = { { "ui", "customFrames" } },
    [GamepadOptions.PLAYER_FRAME_PANEL_ID] = { { "ui", "customFrames", "playerFrame" } },
    [GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID] = { { "ui", "customFrames", "playerFrame", "classic" } },
    [GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID] = { { "ui", "customFrames", "playerFrame", "pyramid" } },
    [GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID] = { { "ui", "customFrames", "playerFrame", "stack" } },
    [GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID] = { { "ui", "customFrames", "playerFrame", "vertical" } },
    [GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID] = { { "ui", "customFrames", "playerFrame", "radial" } },
    [GamepadOptions.COMPANION_FRAME_PANEL_ID] = { { "ui", "customFrames", "companionFrame" } },
    [GamepadOptions.GROUP_FRAME_PANEL_ID] = { { "ui", "customFrames", "groupFrame" } },
    [CHAT_PANEL_ID] = { { "chat" } },
    [CHAT_GUILD_COLORS_PANEL_ID] = { { "chat", "guildMessageColors" } },
    [CHAT_REMINDERS_PANEL_ID] = { { "chat", "reminders" } },
    [SOCIAL_PANEL_ID] = { { "chat" }, { "friends" }, { "groupFinderMonitor" } },
    [FRIENDS_PANEL_ID] = { { "friends" } },
    [GROUP_FINDER_MONITOR_PANEL_ID] = { { "groupFinderMonitor" } },
    [TICKER_PANEL_ID] = { { "ticker" } },
    [UTILITY_PANEL_ID] = { { "utility" } },
    [LUA_GC_PANEL_ID] = { { "utility" } },
    [GROUPING_PANEL_ID] = { { "grouping" } },
    [AUTO_INVITE_PANEL_ID] = { { "grouping", "autoInvite" } },
    [BUFFS_DEBUFFS_PANEL_ID] = { { "buffsDebuffs" } },
    [BUFFS_DEBUFFS_TRACKERS_PANEL_ID] = { { "buffsDebuffs" } },
    [PROGRESS_PANEL_ID] = { { "progress" } },
    [XP_TRACKER_PANEL_ID] = { { "progress", "xp" } },
    [XP_TIMERS_PANEL_ID] = { { "progress", "xp", "timers" } },
    [GamepadOptions.GOLD_TRACKER_PANEL_ID] = { { "progress", "gold" } },
    [GamepadOptions.GOLD_TIMERS_PANEL_ID] = { { "progress", "gold", "timers" } },
    [GamepadOptions.DUNGEONS_PANEL_ID] = {
        { "progress", "dungeons", "baseDetailLevel" },
        { "progress", "dungeons", "baseShowWatermark" },
        { "progress", "dungeons", "baseHorizontalPosition" },
        { "progress", "dungeons", "baseVerticalPosition" },
        { "progress", "dungeons", "baseFont" },
        { "progress", "dungeons", "baseFontSize" },
        { "progress", "dungeons", "baseBackgroundOpacity" },
        { "progress", "dungeons", "fullScrollPositions", "base" },
    },
    [GamepadOptions.DLC_DUNGEONS_PANEL_ID] = {
        { "progress", "dungeons", "dlcDetailLevel" },
        { "progress", "dungeons", "dlcShowWatermark" },
        { "progress", "dungeons", "dlcHorizontalPosition" },
        { "progress", "dungeons", "dlcVerticalPosition" },
        { "progress", "dungeons", "dlcFont" },
        { "progress", "dungeons", "dlcFontSize" },
        { "progress", "dungeons", "dlcBackgroundOpacity" },
        { "progress", "dungeons", "fullScrollPositions", "dlc" },
    },
    [GamepadOptions.TRIALS_PANEL_ID] = { { "progress", "trials" } },
    [GamepadOptions.ARENAS_PANEL_ID] = { { "progress", "arenas" } },
    [GamepadOptions.SOLO_DUNGEONS_PANEL_ID] = { { "progress", "soloDungeons" } },
    [GamepadOptions.INFINITE_ARCHIVE_PANEL_ID] = {
        { "progress", "infiniteArchive", "detailLevel" },
        { "progress", "infiniteArchive", "showWatermark" },
        { "progress", "infiniteArchive", "horizontalPosition" },
        { "progress", "infiniteArchive", "verticalPosition" },
        { "progress", "infiniteArchive", "font" },
        { "progress", "infiniteArchive", "fontSize" },
        { "progress", "infiniteArchive", "backgroundOpacity" },
        { "progress", "infiniteArchive", "scrollRatio" },
    },
}

function GamepadOptions.IsSubpanel(panelId)
    return SUBPANEL_PARENT_IDS[panelId] ~= nil
end

function GamepadOptions.ReplaceSubpanelBackKeybind()
    GAMEPAD_OPTIONS:ReplaceBackKeybind(function()
        local childPanelId = GAMEPAD_OPTIONS.currentCategory
        GamepadOptions.ShowPanel(SUBPANEL_PARENT_IDS[childPanelId] or ROOT_PANEL_ID, GamepadOptions.parentSelectionByChildPanel[childPanelId])
    end)
end

local function SetDefaultFramePreviewPanel(panelId)
    if not NQOL.Features or not NQOL.Features.UI then return end

    local ui = NQOL.Features.UI
    ui.SetActiveQuestSettingsPanelVisible(panelId == ACTIVE_QUEST_PANEL_ID)
    ui.SetActiveCombatTipsSettingsPanelVisible(panelId == ACTIVE_COMBAT_TIPS_PANEL_ID)
    ui.SetSynergyPromptsSettingsPanelVisible(panelId == SYNERGY_PROMPTS_PANEL_ID)
    ui.SetCenterScreenAnnounceSettingsPanelVisible(panelId == CENTER_SCREEN_ANNOUNCE_PANEL_ID)
    ui.SetAnnouncementsSettingsPanelVisible(panelId == ANNOUNCEMENTS_PANEL_ID)
    ui.SetInfiniteArchiveSettingsPanelVisible(panelId == INFINITE_ARCHIVE_FRAME_PANEL_ID)
    ui.SetPlayerInteractionSettingsPanelVisible(panelId == PLAYER_INTERACTION_PANEL_ID)
    ui.SetSubtitlesSettingsPanelVisible(panelId == SUBTITLES_PANEL_ID)
end

function GamepadOptions.ShowPanel(panelId, selectedIndex)
    local currentPanelId = GAMEPAD_OPTIONS.currentCategory

    if panelId == GamepadOptions.GROUP_FRAME_PANEL_ID and NQOL.Features and NQOL.Features.PlayerBars then
        NQOL.Features.PlayerBars.ValidateGroupCustomNamesSetting()
    end

    if SUBPANEL_PARENT_IDS[panelId] == currentPanelId then
        local optionsList = GAMEPAD_OPTIONS.optionsList
        if optionsList and optionsList.GetSelectedIndex then
            GamepadOptions.parentSelectionByChildPanel[panelId] = optionsList:GetSelectedIndex()
        end
    end

    if GAMEPAD_OPTIONS.optionsList and GAMEPAD_OPTIONS.DeactivateSelectedControl then
        GAMEPAD_OPTIONS:DeactivateSelectedControl()
    end

    GAMEPAD_OPTIONS.currentCategory = panelId
    GAMEPAD_OPTIONS:RefreshHeader()
    GAMEPAD_OPTIONS:RefreshOptionsList()

    local optionsList = GAMEPAD_OPTIONS.optionsList
    if optionsList and selectedIndex then
        if optionsList.SetSelectedIndexWithoutAnimation then
            optionsList:SetSelectedIndexWithoutAnimation(selectedIndex, true)
        elseif optionsList.SetSelectedIndex then
            optionsList:SetSelectedIndex(selectedIndex, true)
        end
    end

    if NQOL.Features and NQOL.Features.UI then
        NQOL.Features.UI.SetCombatReticleSettingsPanelVisible(COMBAT_RETICLE_PREVIEW_PANEL_IDS[panelId] == true)
    end
    SetDefaultFramePreviewPanel(panelId)

    if NQOL.Features and NQOL.Features.UIPlayerInfo then
        NQOL.Features.UIPlayerInfo.SetSettingsPanelVisible(panelId == PLAYER_INFO_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.Minimap then
        NQOL.Features.Minimap.SetSettingsPanelVisible(panelId == MINIMAP_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.GPS then
        NQOL.Features.GPS.SetSettingsPanelVisible(panelId == GPS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.PlayerBars then
        NQOL.Features.PlayerBars.SetSettingsPanelVisible(panelId == GamepadOptions.PLAYER_FRAME_PANEL_ID or panelId == GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID or panelId == GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID or panelId == GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID or panelId == GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID or panelId == GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID)
        NQOL.Features.PlayerBars.SetCompanionSettingsPanelVisible(panelId == GamepadOptions.COMPANION_FRAME_PANEL_ID)
        NQOL.Features.PlayerBars.SetGroupSettingsPanelVisible(panelId == GamepadOptions.GROUP_FRAME_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.Chat then
        NQOL.Features.Chat.SetSettingsPanelVisible(panelId == CHAT_PANEL_ID, panelId)
    end

    if NQOL.Features and NQOL.Features.ChatReminders then
        NQOL.Features.ChatReminders.SetSettingsPanelVisible(panelId == CHAT_REMINDERS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.Friends then
        NQOL.Features.Friends.SetSettingsPanelVisible(panelId == FRIENDS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.GroupFinderMonitor then
        NQOL.Features.GroupFinderMonitor.SetSettingsPanelVisible(panelId == GROUP_FINDER_MONITOR_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.Ticker then
        NQOL.Features.Ticker.SetSettingsPanelVisible(panelId == TICKER_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.BuffsDebuffs then
        NQOL.Features.BuffsDebuffs.SetSettingsPanelVisible(panelId == BUFFS_DEBUFFS_PANEL_ID or panelId == BUFFS_DEBUFFS_TRACKERS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.Progress then
        NQOL.Features.Progress.SetSettingsPanelVisible(panelId == XP_TRACKER_PANEL_ID or panelId == XP_TIMERS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.ProgressGold then
        NQOL.Features.ProgressGold.SetSettingsPanelVisible(panelId == GamepadOptions.GOLD_TRACKER_PANEL_ID or panelId == GamepadOptions.GOLD_TIMERS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.ProgressDungeons then
        if panelId == GamepadOptions.DUNGEONS_PANEL_ID then
            NQOL.Features.ProgressDungeons.SetSettingsPanelVisible(NQOL.Features.ProgressDungeons.GetBaseGroupKey())
        elseif panelId == GamepadOptions.DLC_DUNGEONS_PANEL_ID then
            NQOL.Features.ProgressDungeons.SetSettingsPanelVisible(NQOL.Features.ProgressDungeons.GetDlcGroupKey())
        else
            NQOL.Features.ProgressDungeons.SetSettingsPanelVisible(nil)
        end
    end

    if NQOL.Features and NQOL.Features.ProgressTrials then
        NQOL.Features.ProgressTrials.SetSettingsPanelVisible(panelId == GamepadOptions.TRIALS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.ProgressArenas then
        NQOL.Features.ProgressArenas.SetSettingsPanelVisible(panelId == GamepadOptions.ARENAS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.ProgressSoloDungeons then
        NQOL.Features.ProgressSoloDungeons.SetSettingsPanelVisible(panelId == GamepadOptions.SOLO_DUNGEONS_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.ProgressInfiniteArchive then
        NQOL.Features.ProgressInfiniteArchive.SetSettingsPanelVisible(panelId == GamepadOptions.INFINITE_ARCHIVE_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.Fishing then
        NQOL.Features.Fishing.SetSettingsPanelVisible(panelId == FISHING_TRACKER_PANEL_ID)
    end

    if NQOL.Features and NQOL.Features.UltimateCountdown then
        if panelId == ULTIMATE_COUNTDOWN_FRONT_PANEL_ID then
            NQOL.Features.UltimateCountdown.SetSettingsPanelVisible(NQOL.Features.UltimateCountdown.GetFrontBarKey())
        elseif panelId == ULTIMATE_COUNTDOWN_BACK_PANEL_ID then
            NQOL.Features.UltimateCountdown.SetSettingsPanelVisible(NQOL.Features.UltimateCountdown.GetBackBarKey())
        else
            NQOL.Features.UltimateCountdown.SetSettingsPanelVisible(nil)
        end
    end

    if NQOL.Features and NQOL.Features.TrialTimer then
        NQOL.Features.TrialTimer.SetSettingsPanelVisible(panelId == TRIAL_TIMER_PANEL_ID)
    end

    if GamepadOptions.IsSubpanel(panelId) then
        GamepadOptions.ReplaceSubpanelBackKeybind()
    else
        GAMEPAD_OPTIONS:RevertBackKeybind()
    end
end

function GamepadOptions.AddChevron(control)
    if control.NQOLChevron then
        control.NQOLChevron:SetHidden(false)
        return
    end

    local chevron = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    chevron:SetDimensions(24, 24)
    chevron:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_menu_rightArrow.dds")
    chevron:SetAnchor(RIGHT, control, RIGHT, -8, 0)
    control.NQOLChevron = chevron
end

function GamepadOptions.HideChevron(control)
    if control.NQOLChevron then
        control.NQOLChevron:SetHidden(true)
    end
end

function GamepadOptions.HideDivider(control)
    if control.NQOLDivider then
        control.NQOLDivider:SetHidden(true)
    end
end

function GamepadOptions.InitializeNavigationEntry(control)
    GamepadOptions.HideDivider(control)
    GamepadOptions.AddChevron(control)
end

function GamepadOptions.InitializeDecorativeEntry(control)
    GamepadOptions.HideChevron(control)
    GamepadOptions.HideDivider(control)
end

function GamepadOptions.MakeHeader(text)
    return function()
        return text
    end
end

function GamepadOptions.WithHeader(option, text)
    option.header = GamepadOptions.MakeHeader(text)
    return option
end

function GamepadOptions.RefreshCurrentOptionsList()
    if GAMEPAD_OPTIONS and GAMEPAD_OPTIONS.RefreshOptionsList then
        GAMEPAD_OPTIONS:RefreshOptionsList()
    end
end

function GamepadOptions.RegisterLanguageReloadDialog()
    if languageReloadDialogRegistered or not ZO_Dialogs_RegisterCustomDialog then
        return
    end

    ZO_Dialogs_RegisterCustomDialog(LANGUAGE_RELOAD_DIALOG_NAME, {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title = {
            text = NQOL.L("dialogs.language_reload.title"),
        },
        mainText = {
            text = NQOL.L("dialogs.language_reload.message"),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_YES,
                callback = function(dialog)
                    local preference = dialog and dialog.data and dialog.data.languagePreference
                    if preference and NQOL.Lexicon.IsLanguagePreference(preference) then
                        if NQOL.Lexicon.SetLanguagePreference(preference) then
                            ReloadUI("ingame")
                        end
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_NO,
            },
        },
    })

    languageReloadDialogRegistered = true
end

function GamepadOptions.ShowLanguageReloadDialog(languagePreference)
    if languagePreference == NQOL.Lexicon.GetLanguagePreference()
        or not NQOL.Lexicon.IsLanguagePreference(languagePreference) then
        return
    end

    GamepadOptions.RegisterLanguageReloadDialog()
    if not languageReloadDialogRegistered then
        return
    end

    local data = { languagePreference = languagePreference }
    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(LANGUAGE_RELOAD_DIALOG_NAME, data)
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(LANGUAGE_RELOAD_DIALOG_NAME, data)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(LANGUAGE_RELOAD_DIALOG_NAME, data)
    end
end

function GamepadOptions.GetPendingLanguagePreference()
    return pendingLanguagePreference or NQOL.Lexicon.GetLanguagePreference()
end

function GamepadOptions.SetPendingLanguagePreference(value)
    if not NQOL.Lexicon.IsLanguagePreference(value) then
        return
    end

    local normalizedValue = NQOL.Lexicon.NormalizeLanguagePreference(value)
    if normalizedValue == NQOL.Lexicon.GetLanguagePreference() then
        pendingLanguagePreference = nil
    else
        pendingLanguagePreference = normalizedValue
    end
end

function GamepadOptions.PromptForPendingLanguageChange()
    local preference = pendingLanguagePreference
    pendingLanguagePreference = nil
    if not preference or preference == NQOL.Lexicon.GetLanguagePreference() then
        return false
    end

    local showDialog = function()
        GamepadOptions.ShowLanguageReloadDialog(preference)
    end
    if zo_callLater then
        zo_callLater(showDialog, 1)
    else
        showDialog()
    end
    return true
end

function GamepadOptions.RegisterClearSavedFoodDialog()
    if clearSavedFoodDialogRegistered or not ZO_Dialogs_RegisterCustomDialog then
        return
    end

    ZO_Dialogs_RegisterCustomDialog(CLEAR_SAVED_FOOD_DIALOG_NAME, {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title = {
            text = NQOL.L("ui.gamepad_options.clear_saved_food_c53fd5c"),
        },
        mainText = {
            text = function()
                local provisioning = NQOL.Features.Provisioning
                return NQOL.L("features.provisioning.clear_saved_food", provisioning.GetAutoFoodSavedFoodLabel())
            end,
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_YES,
                callback = function()
                    NQOL.Features.Provisioning.ClearAutoFoodSavedFood()
                    GamepadOptions.RefreshCurrentOptionsList()
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_NO,
            },
        },
    })

    clearSavedFoodDialogRegistered = true
end

function GamepadOptions.ShowClearSavedFoodDialog()
    local provisioning = NQOL.Features.Provisioning
    if not provisioning.HasAutoFoodSavedFood() then
        return
    end

    GamepadOptions.RegisterClearSavedFoodDialog()

    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(CLEAR_SAVED_FOOD_DIALOG_NAME)
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(CLEAR_SAVED_FOOD_DIALOG_NAME)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(CLEAR_SAVED_FOOD_DIALOG_NAME)
    end
end

function GamepadOptions.RegisterResetTimersDialog(dialogName, titleText, bodyText, resetCallback)
    if not ZO_Dialogs_RegisterCustomDialog or GamepadOptions.resetTimersDialogsRegistered[dialogName] == true then
        return
    end

    ZO_Dialogs_RegisterCustomDialog(dialogName, {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title = {
            text = titleText,
        },
        mainText = {
            text = bodyText,
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_YES,
                callback = function()
                    resetCallback()
                    GamepadOptions.RefreshCurrentOptionsList()
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_NO,
            },
        },
    })

    GamepadOptions.resetTimersDialogsRegistered[dialogName] = true
end

function GamepadOptions.ShowResetTimersDialog(dialogName, titleText, bodyText, resetCallback)
    GamepadOptions.RegisterResetTimersDialog(dialogName, titleText, bodyText, resetCallback)

    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(dialogName)
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(dialogName)
    elseif ZO_Dialogs_ShowDialog then
        ZO_Dialogs_ShowDialog(dialogName)
    end
end

function GamepadOptions.RegisterChatMissingItemWhisperMessageDialog()
    if chatMissingItemWhisperMessageDialogRegistered or not ZO_Dialogs_RegisterCustomDialog or not ZO_GenericGamepadDialog_GetControl then
        return
    end

    local parametricDialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)

    ZO_Dialogs_RegisterCustomDialog(CHAT_MISSING_ITEM_WHISPER_MESSAGE_DIALOG_NAME, {
        blockDialogReleaseOnPress = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        setup = function(dialog)
            dialog.data.pendingText = NQOL.Features.Chat.GetAnnotateMissingItemsWhisperMessage()
            dialog:setupFunc()
        end,
        title = {
            text = NQOL.L("features.chat.annotate_missing_items_whisper_message_title"),
        },
        parametricList = {
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData = {
                    textChangedCallback = function(control)
                        parametricDialog.data.pendingText = control:GetText()
                    end,
                    setup = function(control, data, selected)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl.textChangedCallback = data.textChangedCallback
                        control.editBoxControl:SetDefaultText(NQOL.Features.Chat.GetAnnotateMissingItemsWhisperMessageDefault())
                        control.editBoxControl:SetMaxInputChars(MAX_TEXT_CHAT_INPUT_CHARACTERS or 350)
                        control.editBoxControl:SetText(parametricDialog.data.pendingText or "")
                    end,
                    callback = function(dialog)
                        local targetControl = dialog.entryList:GetTargetControl()
                        if targetControl and targetControl.editBoxControl then
                            targetControl.editBoxControl:TakeFocus()
                        end
                    end,
                    narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                },
            },
            {
                template = "ZO_GamepadTextFieldSubmitItem",
                templateData = {
                    text = NQOL.L("ui.gamepad_options.save_efc007a"),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(dialog)
                        NQOL.Features.Chat.SetAnnotateMissingItemsWhisperMessage(dialog.data.pendingText or "")
                        GamepadOptions.RefreshCurrentOptionsList()
                        ZO_Dialogs_ReleaseDialogOnButtonPress(CHAT_MISSING_ITEM_WHISPER_MESSAGE_DIALOG_NAME)
                    end,
                },
            },
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    if data and data.callback then
                        data.callback(dialog)
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(CHAT_MISSING_ITEM_WHISPER_MESSAGE_DIALOG_NAME)
                end,
            },
        },
    })

    chatMissingItemWhisperMessageDialogRegistered = true
end

function GamepadOptions.ShowChatMissingItemWhisperMessageDialog()
    GamepadOptions.RegisterChatMissingItemWhisperMessageDialog()

    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(CHAT_MISSING_ITEM_WHISPER_MESSAGE_DIALOG_NAME, {})
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(CHAT_MISSING_ITEM_WHISPER_MESSAGE_DIALOG_NAME, {})
    end
end

function GamepadOptions.RegisterAutoInviteTextDialog()
    if autoInviteTextDialogRegistered or not ZO_Dialogs_RegisterCustomDialog or not ZO_GenericGamepadDialog_GetControl then
        return
    end

    local parametricDialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)

    ZO_Dialogs_RegisterCustomDialog(AUTO_INVITE_TEXT_DIALOG_NAME, {
        blockDialogReleaseOnPress = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        setup = function(dialog)
            dialog.data.pendingText = NQOL.Features.Grouping.GetAutoInviteTriggerText()
            dialog:setupFunc()
        end,
        title = {
            text = NQOL.L("ui.gamepad_options.auto_invite_text_8911a14"),
        },
        parametricList = {
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData = {
                    textChangedCallback = function(control)
                        parametricDialog.data.pendingText = control:GetText()
                    end,
                    setup = function(control, data, selected)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl.textChangedCallback = data.textChangedCallback
                        control.editBoxControl:SetDefaultText(NQOL.L("dialogs.auto_invite.placeholder"))
                        control.editBoxControl:SetMaxInputChars(100)
                        control.editBoxControl:SetText(parametricDialog.data.pendingText or "")
                    end,
                    callback = function(dialog)
                        local targetControl = dialog.entryList:GetTargetControl()
                        if targetControl and targetControl.editBoxControl then
                            targetControl.editBoxControl:TakeFocus()
                        end
                    end,
                    narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                },
            },
            {
                template = "ZO_GamepadTextFieldSubmitItem",
                templateData = {
                    text = NQOL.L("ui.gamepad_options.save_efc007a"),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(dialog)
                        NQOL.Features.Grouping.SetAutoInviteTriggerText(dialog.data.pendingText or "")
                        GamepadOptions.RefreshCurrentOptionsList()
                        ZO_Dialogs_ReleaseDialogOnButtonPress(AUTO_INVITE_TEXT_DIALOG_NAME)
                    end,
                },
            },
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    if data and data.callback then
                        data.callback(dialog)
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(AUTO_INVITE_TEXT_DIALOG_NAME)
                end,
            },
        },
    })

    autoInviteTextDialogRegistered = true
end

function GamepadOptions.ShowAutoInviteTextDialog()
    GamepadOptions.RegisterAutoInviteTextDialog()

    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(AUTO_INVITE_TEXT_DIALOG_NAME, {})
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(AUTO_INVITE_TEXT_DIALOG_NAME, {})
    end
end

function GamepadOptions.RegisterGroupFinderMonitorAlarmTextDialog()
    if groupFinderMonitorAlarmTextDialogRegistered or not ZO_Dialogs_RegisterCustomDialog or not ZO_GenericGamepadDialog_GetControl then
        return
    end

    local parametricDialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)

    ZO_Dialogs_RegisterCustomDialog(GROUP_FINDER_MONITOR_ALARM_TEXT_DIALOG_NAME, {
        blockDialogReleaseOnPress = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        setup = function(dialog)
            dialog.data.pendingText = NQOL.Features.GroupFinderMonitor.GetAlarmText()
            dialog:setupFunc()
        end,
        title = {
            text = NQOL.L("features.group_finder_monitor.alarm_text_dialog_title"),
        },
        parametricList = {
            {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                templateData = {
                    textChangedCallback = function(control)
                        parametricDialog.data.pendingText = control:GetText()
                    end,
                    setup = function(control, data, selected)
                        control.highlight:SetHidden(not selected)
                        control.editBoxControl.textChangedCallback = data.textChangedCallback
                        control.editBoxControl:SetDefaultText(NQOL.L("features.group_finder_monitor.alarm_text_placeholder"))
                        control.editBoxControl:SetMaxInputChars(250)
                        control.editBoxControl:SetText(parametricDialog.data.pendingText or "")
                    end,
                    callback = function(dialog)
                        local targetControl = dialog.entryList:GetTargetControl()
                        if targetControl and targetControl.editBoxControl then
                            targetControl.editBoxControl:TakeFocus()
                        end
                    end,
                    narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                },
            },
            {
                template = "ZO_GamepadTextFieldSubmitItem",
                templateData = {
                    text = NQOL.L("ui.gamepad_options.save_efc007a"),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(dialog)
                        NQOL.Features.GroupFinderMonitor.SetAlarmText(dialog.data.pendingText or "")
                        GamepadOptions.RefreshCurrentOptionsList()
                        ZO_Dialogs_ReleaseDialogOnButtonPress(GROUP_FINDER_MONITOR_ALARM_TEXT_DIALOG_NAME)
                    end,
                },
            },
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    if data and data.callback then data.callback(dialog) end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
                callback = function()
                    ZO_Dialogs_ReleaseDialogOnButtonPress(GROUP_FINDER_MONITOR_ALARM_TEXT_DIALOG_NAME)
                end,
            },
        },
    })

    groupFinderMonitorAlarmTextDialogRegistered = true
end

function GamepadOptions.ShowGroupFinderMonitorAlarmTextDialog()
    GamepadOptions.RegisterGroupFinderMonitorAlarmTextDialog()

    if ZO_Dialogs_ShowGamepadDialog then
        ZO_Dialogs_ShowGamepadDialog(GROUP_FINDER_MONITOR_ALARM_TEXT_DIALOG_NAME, {})
    elseif ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog(GROUP_FINDER_MONITOR_ALARM_TEXT_DIALOG_NAME, {})
    end
end

function GamepadOptions.IsNQOLOptionControl(control)
    local data = control and control.data
    return data and data.nqolOption == true and data.SetSettingOverride ~= nil
end

function GamepadOptions.ApplyNQOLSetting(control, value)
    if not GamepadOptions.IsNQOLOptionControl(control) then
        return false
    end

    local data = control.data
    data.SetSettingOverride(control, value)
    data.nqolUpdatingControl = true
    ZO_Options_UpdateOption(control)
    data.nqolUpdatingControl = nil
    GamepadOptions.SetNQOLOptionControlHandler(control)

    local optionsManager = control.optionsManager
    if SCREEN_NARRATION_MANAGER and optionsManager and optionsManager.IsGamepadOptions and optionsManager:IsGamepadOptions() and optionsManager.IsShowing and optionsManager:IsShowing() then
        SCREEN_NARRATION_MANAGER:QueueParametricListEntry(optionsManager:GetCurrentList())
    end

    return true
end

function GamepadOptions.RefreshNQOLControlLabel(control)
    local data = control and control.data
    if not data or not data.nqolRefreshLabelOnChange then
        return
    end

    local labelControl = control.label or control:GetNamedChild("Name") or control:GetNamedChild("Label")
    if not labelControl then
        return
    end

    local text = data.gamepadTextOverride or data.text
    text = ResolveTextEntry(text, control)

    if type(text) == "string" then
        labelControl:SetText(text)
    end
end

function GamepadOptions.ApplyNQOLSliderSetting(control, value)
    if not GamepadOptions.IsNQOLOptionControl(control) then
        return false
    end

    local data = control.data
    local valueFormat = data.valueFormat or "%d"
    local formattedValueString = string.format(valueFormat, value)

    local valueLabelControl = control:GetNamedChild("ValueLabel")
    if data.showValue and valueLabelControl and ZO_Options_GetFormattedSliderValues then
        local formattedShowValueString = ZO_Options_GetFormattedSliderValues(data, formattedValueString)
        valueLabelControl:SetText(formattedShowValueString)
    end

    if data.deferredApply then
        data.nqolDeferredSliderSerial = (data.nqolDeferredSliderSerial or 0) + 1
        local serial = data.nqolDeferredSliderSerial
        local delayMs = data.deferredApplyDelayMs or DEFERRED_SLIDER_APPLY_MS

        if zo_callLater then
            zo_callLater(function()
                if data.nqolDeferredSliderSerial == serial then
                    data.SetSettingOverride(control, value)
                end
            end, delayMs)
        else
            data.SetSettingOverride(control, value)
        end
    else
        data.SetSettingOverride(control, value)
    end

    data.nqolLabelValueOverride = value
    GamepadOptions.RefreshNQOLControlLabel(control)
    data.nqolLabelValueOverride = nil

    local optionsManager = control.optionsManager
    if SCREEN_NARRATION_MANAGER and optionsManager and optionsManager.IsGamepadOptions and optionsManager:IsGamepadOptions() and optionsManager.IsShowing and optionsManager:IsShowing() then
        SCREEN_NARRATION_MANAGER:QueueParametricListEntry(optionsManager:GetCurrentList())
    end

    return true
end

function GamepadOptions.OpenNQOLColorPicker(control)
    if not GamepadOptions.IsNQOLOptionControl(control) or not SYSTEMS then
        return false
    end

    local data = control.data
    if data.nqolColorOption ~= true then
        return false
    end

    local red, green, blue, alpha
    if data.GetNQOLColorChannels then
        red, green, blue, alpha = data.GetNQOLColorChannels(control)
    else
        red, green, blue, alpha = HexToRgba(data.GetSettingOverride(control))
    end
    red = Clamp(tonumber(red) or 1, 0, 1)
    green = Clamp(tonumber(green) or 1, 0, 1)
    blue = Clamp(tonumber(blue) or 1, 0, 1)
    alpha = Clamp(tonumber(alpha) or 1, 0, 1)

    local function OnColorSet(red, green, blue, alpha)
        if data.SetNQOLColorChannels then
            data.SetNQOLColorChannels(control, red, green, blue, alpha or 1)
        else
            data.SetSettingOverride(control, RgbaToHex(red, green, blue, alpha or 1))
        end

        local colorControl = control:GetNamedChild("Color")
        if colorControl then
            colorControl:SetColor(red, green, blue)
        end

        if ZO_Options_UpdateOption then
            ZO_Options_UpdateOption(control)
            GamepadOptions.SetNQOLOptionControlHandler(control)
        else
            GamepadOptions.RefreshCurrentOptionsList()
        end
    end

    local colorPicker
    if SYSTEMS.GetGamepadObject then
        colorPicker = SYSTEMS:GetGamepadObject("colorPicker")
    end
    if not colorPicker and SYSTEMS.GetObject then
        colorPicker = SYSTEMS:GetObject("colorPicker")
    end
    if not colorPicker or not colorPicker.Show then
        if NQOL.Chat and NQOL.Chat.Message then
            NQOL.Chat.Message(NQOL.L("ui.gamepad_options.color_picker_is_not_available_930cbcc"), NQOL.L("common.feature.group_frame"))
        end
        return true
    end

    colorPicker:Show(OnColorSet, red, green, blue, alpha)
    return true
end

function GamepadOptions.HookColorClicks()
    if colorClickHooked or type(ZO_PreHook) ~= "function" or not ZO_Options_ColorOnClicked then
        return
    end

    colorClickHooked = true
    ZO_PreHook("ZO_Options_ColorOnClicked", function(control)
        return GamepadOptions.OpenNQOLColorPicker(control)
    end)
end

function GamepadOptions.OnNQOLScrollListSelectionChanged(selectedData, oldData, reselectingDuringRebuild)
    local parentControl = selectedData and selectedData.parentControl
    if parentControl and parentControl.data and parentControl.data.enabled == false then
        return
    end
    if oldData ~= nil and reselectingDuringRebuild ~= true and parentControl then
        GamepadOptions.ApplyNQOLSetting(parentControl, selectedData.value)
    end
end

function GamepadOptions.SetNQOLOptionControlHandler(control)
    if not GamepadOptions.IsNQOLOptionControl(control) then
        return
    end

    local data = control.data

    if data.controlType == OPTIONS_FINITE_LIST and control.horizontalListObject then
        control.horizontalListObject:SetOnSelectedDataChangedCallback(GamepadOptions.OnNQOLScrollListSelectionChanged)
    elseif data.controlType == OPTIONS_CHECKBOX then
        local checkBoxControl = control:GetNamedChild("Checkbox")
        if checkBoxControl then
            ZO_CheckButton_SetToggleFunction(checkBoxControl, function(_, boxIsChecked)
                GamepadOptions.ApplyNQOLSetting(control, boxIsChecked)
            end)
        end
    elseif data.controlType == OPTIONS_SLIDER then
        if data.nqolPositionSlider == true then
            data.gamepadValueStepPercent = GetPositionSliderStepPercent(data.minValue, data.maxValue)
        end

        local sliderControl = control:GetNamedChild("Slider")
        if sliderControl then
            sliderControl:SetHandler("OnValueChanged", function(_, value)
                if data.nqolUpdatingControl then
                    return
                end

                GamepadOptions.ApplyNQOLSliderSetting(control, value)
            end)
        end
    elseif data.nqolColorOption == true then
        GamepadOptions.HookColorClicks()
    end
end

function GamepadOptions.RunOptionInitialize(control, isKeyboardControl, initializeFunc)
    GamepadOptions.SetNQOLOptionControlHandler(control)

    if initializeFunc then
        initializeFunc(control, isKeyboardControl)
    end

    local data = control and control.data
    if zo_callLater then
        zo_callLater(function()
            if control and control.data == data then
                GamepadOptions.SetNQOLOptionControlHandler(control)
                GamepadOptions.RefreshNQOLControlLabel(control)
            end
        end, 0)
    else
        GamepadOptions.SetNQOLOptionControlHandler(control)
        GamepadOptions.RefreshNQOLControlLabel(control)
    end
end

function GamepadOptions.BuildSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, gamepadValueStepPercent, deferredApply, defaultValue)
    local sliderLabel = BuildSliderLabel(label, valueFormat, getFunc)

    return {
        panel = panelId,
        system = panelId,
        settingId = settingId,
        nqolOption = true,
        controlType = OPTIONS_SLIDER,
        text = sliderLabel,
        gamepadTextOverride = sliderLabel,
        tooltipText = tooltip,
        minValue = minValue,
        maxValue = maxValue,
        valueFormat = valueFormat,
        showValue = true,
        showValueMin = minValue,
        showValueMax = maxValue,
        gamepadValueStepPercent = gamepadValueStepPercent,
        deferredApply = deferredApply == true,
        default = defaultValue,
        nqolRefreshLabelOnChange = true,
        customResetToDefaultsFunction = GamepadOptions.ResetNQOLSettingToDefault,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, tooltip)
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return getFunc()
        end,
        SetSettingOverride = function(_, value)
            setFunc(value)
        end,
    }
end

function GamepadOptions.BuildValueStepSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, valueStep, deferredApply, defaultValue)
    local stepPercent = GetValueSliderStepPercent(minValue, maxValue, valueStep)
    return GamepadOptions.BuildSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, stepPercent, deferredApply, defaultValue)
end

function GamepadOptions.BuildPositionSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, deferredApply, defaultValue)
    minValue = ResolveNumericOptionValue(minValue) or 0
    maxValue = ResolveNumericOptionValue(maxValue) or minValue
    local stepPercent = GetPositionSliderStepPercent(minValue, maxValue)
    if valueFormat == "%.0f" then
        valueFormat = "%.2f"
    end

    local option = GamepadOptions.BuildSliderOption(panelId, settingId, label, tooltip, minValue, maxValue, valueFormat, getFunc, setFunc, stepPercent, deferredApply, defaultValue)
    option.nqolPositionSlider = true
    return option
end

function GamepadOptions.BuildCheckboxOption(panelId, settingId, label, tooltip, getFunc, setFunc, enabledFunc, defaultValue)
    return {
        panel = panelId,
        system = panelId,
        settingId = settingId,
        nqolOption = true,
        controlType = OPTIONS_CHECKBOX,
        text = label,
        gamepadTextOverride = label,
        tooltipText = tooltip,
        enabled = enabledFunc,
        default = defaultValue,
        customResetToDefaultsFunction = GamepadOptions.ResetNQOLSettingToDefault,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, tooltip)
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return getFunc()
        end,
        SetSettingOverride = function(_, value)
            setFunc(value)
        end,
    }
end

function GamepadOptions.BuildFiniteListOption(panelId, settingId, label, tooltip, choices, choiceNames, getFunc, setFunc, defaultValue)
    return {
        panel = panelId,
        system = panelId,
        settingId = settingId,
        nqolOption = true,
        controlType = OPTIONS_FINITE_LIST,
        text = label,
        gamepadTextOverride = label,
        tooltipText = tooltip,
        valid = choices,
        itemText = choiceNames,
        default = defaultValue,
        customResetToDefaultsFunction = GamepadOptions.ResetNQOLSettingToDefault,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, tooltip)
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return getFunc()
        end,
        SetSettingOverride = function(_, value)
            setFunc(value)
        end,
    }
end

function GamepadOptions.BuildColorOption(panelId, settingId, label, tooltip, getFunc, setFunc, defaultValue)
    return {
        panel = panelId,
        system = panelId,
        settingId = settingId,
        nqolOption = true,
        nqolColorOption = true,
        controlType = OPTIONS_COLOR,
        text = label,
        gamepadTextOverride = label,
        tooltipText = tooltip,
        default = defaultValue,
        customResetToDefaultsFunction = GamepadOptions.ResetNQOLSettingToDefault,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, tooltip)
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            local red, green, blue, alpha = getFunc()
            return RgbaToHex(red, green, blue, alpha)
        end,
        SetSettingOverride = function(_, value)
            setFunc(HexToRgba(value))
        end,
        GetNQOLColorChannels = function()
            return getFunc()
        end,
        SetNQOLColorChannels = function(_, red, green, blue, alpha)
            setFunc(red, green, blue, alpha)
        end,
    }
end

function GamepadOptions.RegisterSharedOptions(panelId, optionsData)
    if not ZO_SharedOptions or not ZO_SharedOptions.AddTableToPanel then
        return
    end

    local sharedOptions = {
        [panelId] = {},
    }

    for _, optionData in ipairs(optionsData) do
        sharedOptions[panelId][optionData.settingId] = ZO_ShallowTableCopy(optionData)
    end

    ZO_SharedOptions.AddTableToPanel(panelId, sharedOptions)
end

function GamepadOptions.RegisterPanel(panelId, optionsData)
    GamepadOptions.AttachPanelReset(optionsData, panelId)

    local isRegistered = GAMEPAD_SETTINGS_DATA[panelId] ~= nil
    GAMEPAD_SETTINGS_DATA[panelId] = optionsData

    if not isRegistered then
        GamepadOptions.RegisterSharedOptions(panelId, optionsData)
    end
end

function GamepadOptions.RegisterPanelHeaderStrings()
    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. ROOT_PANEL_ID, "NQOL")
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. ROOT_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. MOUNTS_PANEL_ID, NQOL.L("ui.gamepad_options.mounts_9516ba1"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. MOUNTS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. ANTIQUITIES_PANEL_ID, NQOL.L("ui.gamepad_options.antiquities_20f1518"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. ANTIQUITIES_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GEAR_PANEL_ID, NQOL.L("ui.gamepad_options.gear_def2b5f"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GEAR_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. COMBAT_PANEL_ID, NQOL.L("ui.gamepad_options.combat_af169bb"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. COMBAT_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. COMBAT_INFINITE_ARCHIVE_PANEL_ID, NQOL.L("ui.gamepad_options.infinite_archive_52c9059"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. COMBAT_INFINITE_ARCHIVE_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. COMBAT_MISCELLANEOUS_PANEL_ID, NQOL.L("ui.gamepad_options.miscellaneous"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. COMBAT_MISCELLANEOUS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. TRIAL_TIMER_PANEL_ID, NQOL.L("ui.gamepad_options.trial_timer"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. TRIAL_TIMER_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. ULTIMATE_COUNTDOWN_PANEL_ID, NQOL.L("ui.gamepad_options.ultimate_countdown_12344ec"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. ULTIMATE_COUNTDOWN_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. ULTIMATE_COUNTDOWN_FRONT_PANEL_ID, NQOL.L("ui.gamepad_options.front_bar_countdown_12c6f81"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. ULTIMATE_COUNTDOWN_FRONT_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. ULTIMATE_COUNTDOWN_BACK_PANEL_ID, NQOL.L("ui.gamepad_options.back_bar_countdown_bdfedc4"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. ULTIMATE_COUNTDOWN_BACK_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. DEBUG_PANEL_ID, "Debug")
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. DEBUG_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. PROVISIONING_PANEL_ID, NQOL.L("ui.gamepad_options.provisioning_c9d0ab3"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. PROVISIONING_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. MAP_PANEL_ID, NQOL.L("ui.gamepad_options.map_ab478f3"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. MAP_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. MAP_OPTIONS_PANEL_ID, NQOL.L("ui.gamepad_options.map_ab478f3"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. MAP_OPTIONS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. MINIMAP_PANEL_ID, NQOL.L("ui.gamepad_options.minimap_03000e5"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. MINIMAP_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GPS_PANEL_ID, NQOL.Features.GPS.GetName())
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GPS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. FISHING_PANEL_ID, NQOL.L("ui.gamepad_options.fishing_cadfb5b"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. FISHING_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. FISHING_TRACKER_PANEL_ID, NQOL.L("ui.gamepad_options.fishing_tracker_d082c00"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. FISHING_TRACKER_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. UI_PANEL_ID, NQOL.L("ui.gamepad_options.ui_9d57875"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. UI_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. CAMERA_PANEL_ID, NQOL.Features.Camera.GetName())
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. CAMERA_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. DEFAULT_FRAMES_PANEL_ID, NQOL.L("ui.gamepad_options.default_frames_acdfa98"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. DEFAULT_FRAMES_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. COMBAT_RETICLE_PANEL_ID, NQOL.L("ui.gamepad_options.combat_reticle_7a159a7"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. COMBAT_RETICLE_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_PANEL_ID, NQOL.L("features.ui_combat_reticle.reticle_info_label"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_TOP_LEFT_PANEL_ID, NQOL.L("features.ui_combat_reticle.top_left_label"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_TOP_LEFT_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_TOP_RIGHT_PANEL_ID, NQOL.L("features.ui_combat_reticle.top_right_label"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_TOP_RIGHT_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_BOTTOM_LEFT_PANEL_ID, NQOL.L("features.ui_combat_reticle.bottom_left_label"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_BOTTOM_LEFT_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID, NQOL.L("features.ui_combat_reticle.bottom_right_label"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. ACTIVE_QUEST_PANEL_ID, NQOL.L("ui.gamepad_options.active_quest_8036d24"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. ACTIVE_QUEST_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. ACTIVE_COMBAT_TIPS_PANEL_ID, NQOL.L("ui.gamepad_options.active_combat_tips_6e90fb1"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. ACTIVE_COMBAT_TIPS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. SYNERGY_PROMPTS_PANEL_ID, NQOL.L("ui.gamepad_options.synergy_prompts_384f9c9"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. SYNERGY_PROMPTS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. CENTER_SCREEN_ANNOUNCE_PANEL_ID, NQOL.L("ui.gamepad_options.center_screen_announce_9b7d2b5"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. CENTER_SCREEN_ANNOUNCE_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. ANNOUNCEMENTS_PANEL_ID, NQOL.L("features.ui.announcements"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. ANNOUNCEMENTS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. INFINITE_ARCHIVE_FRAME_PANEL_ID, NQOL.L("ui.gamepad_options.infinite_archive_52c9059"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. INFINITE_ARCHIVE_FRAME_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. LOOT_LOG_PANEL_ID, NQOL.L("ui.gamepad_options.loot_log_f30da82"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. LOOT_LOG_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. PLAYER_INFO_PANEL_ID, NQOL.L("ui.gamepad_options.player_info_f6475d5"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. PLAYER_INFO_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. PLAYER_INTERACTION_PANEL_ID, NQOL.L("ui.gamepad_options.player_interaction_c4371b1"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. PLAYER_INTERACTION_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. SUBTITLES_PANEL_ID, NQOL.L("ui.gamepad_options.subtitles_1777047"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. SUBTITLES_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.FRAME_STYLING_PANEL_ID, NQOL.L("ui.gamepad_options.custom_frames_80b9e03"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.FRAME_STYLING_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_PANEL_ID, NQOL.L("ui.gamepad_options.player_frame_2197e12"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, NQOL.L("ui.gamepad_options.classic_130cd7f"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, NQOL.L("ui.gamepad_options.pyramid_38d1f19"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, NQOL.L("ui.gamepad_options.stack_83e5a0d"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, NQOL.L("ui.gamepad_options.vertical_4b937cc"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, NQOL.L("ui.gamepad_options.radial_e2a166d"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.COMPANION_FRAME_PANEL_ID, NQOL.L("ui.gamepad_options.companion_frame_5c3e63f"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.COMPANION_FRAME_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.GROUP_FRAME_PANEL_ID, NQOL.L("ui.gamepad_options.group_frame_b9dc0c6"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.GROUP_FRAME_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. CHAT_PANEL_ID, NQOL.L("ui.gamepad_options.chat_2ced57f"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. CHAT_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. CHAT_GUILD_COLORS_PANEL_ID, NQOL.L("ui.gamepad_options.guild_colors_6be2c28"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. CHAT_GUILD_COLORS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. CHAT_REMINDERS_PANEL_ID, NQOL.L("ui.gamepad_options.reminders_ae8c393"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. CHAT_REMINDERS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. SOCIAL_PANEL_ID, NQOL.L("ui.gamepad_options.social_41a5750"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. SOCIAL_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. FRIENDS_PANEL_ID, NQOL.L("ui.gamepad_options.friends_c11d5e1"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. FRIENDS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GROUP_FINDER_MONITOR_PANEL_ID, NQOL.L("features.group_finder_monitor.entry_label"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GROUP_FINDER_MONITOR_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. TICKER_PANEL_ID, NQOL.L("ui.gamepad_options.ticker_5586cf3"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. TICKER_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. UTILITY_PANEL_ID, NQOL.L("ui.gamepad_options.utility_8918950"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. UTILITY_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GROUPING_PANEL_ID, NQOL.L("ui.gamepad_options.grouping_2ae6967"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GROUPING_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. AUTO_INVITE_PANEL_ID, NQOL.L("ui.gamepad_options.auto_invite_da2185d"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. AUTO_INVITE_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. LUA_GC_PANEL_ID, NQOL.L("ui.gamepad_options.lua_gc_be3883a"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. LUA_GC_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. AUTO_BOUND_PANEL_ID, NQOL.L("ui.gamepad_options.auto_bind_2381c3f"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. AUTO_BOUND_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. AUTO_CHARGE_PANEL_ID, NQOL.L("ui.gamepad_options.auto_charge_439c4d3"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. AUTO_CHARGE_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. AUTO_REPAIR_PANEL_ID, NQOL.L("ui.gamepad_options.auto_repair_4002023"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. AUTO_REPAIR_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. BUFFS_DEBUFFS_PANEL_ID, NQOL.L("ui.gamepad_options.buffs_debuffs_774d3a3"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. BUFFS_DEBUFFS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. BUFFS_DEBUFFS_TRACKERS_PANEL_ID, NQOL.L("ui.gamepad_options.trackers_4be3b88"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. BUFFS_DEBUFFS_TRACKERS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. PROGRESS_PANEL_ID, NQOL.L("ui.gamepad_options.progress_1b90271"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. PROGRESS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. XP_TRACKER_PANEL_ID, NQOL.L("ui.gamepad_options.xp_53af638"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. XP_TRACKER_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. XP_TIMERS_PANEL_ID, NQOL.L("ui.gamepad_options.timers_841cd03"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. XP_TIMERS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.GOLD_TRACKER_PANEL_ID, NQOL.L("ui.gamepad_options.gold_c57604d"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.GOLD_TRACKER_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.GOLD_TIMERS_PANEL_ID, NQOL.L("ui.gamepad_options.timers_841cd03"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.GOLD_TIMERS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.DUNGEONS_PANEL_ID, NQOL.L("ui.gamepad_options.base_dungeons_98c539e"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.DUNGEONS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.DLC_DUNGEONS_PANEL_ID, NQOL.L("ui.gamepad_options.dlc_dungeons_d2c30fd"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.DLC_DUNGEONS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.TRIALS_PANEL_ID, NQOL.L("ui.gamepad_options.trials_3dcdcaf"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.TRIALS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.ARENAS_PANEL_ID, NQOL.L("ui.gamepad_options.arenas_05bb528"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.ARENAS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.SOLO_DUNGEONS_PANEL_ID, NQOL.L("ui.gamepad_options.solo_dungeons"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.SOLO_DUNGEONS_PANEL_ID, 1)

    ZO_CreateStringId("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.INFINITE_ARCHIVE_PANEL_ID, NQOL.L("ui.gamepad_options.infinite_archive_52c9059"))
    SafeAddVersion("SI_SETTINGSYSTEMPANEL" .. GamepadOptions.INFINITE_ARCHIVE_PANEL_ID, 1)

end

function GamepadOptions.ApplyHeaderVersionSubtitle()
    if not GAMEPAD_OPTIONS or not GAMEPAD_OPTIONS.header or not GAMEPAD_OPTIONS.headerData or not ZO_GamepadGenericHeader_RefreshData then
        return
    end

    if GAMEPAD_OPTIONS.currentCategory ~= ROOT_PANEL_ID then
        return
    end

    local version = NQOL.version
    if not version or version == 0 then
        return
    end

    GAMEPAD_OPTIONS.headerData.subtitleText = "v" .. tostring(version)
    ZO_GamepadGenericHeader_RefreshData(GAMEPAD_OPTIONS.header, GAMEPAD_OPTIONS.headerData)
end

function GamepadOptions.HookHeaderVersionSubtitle()
    if headerVersionHooked or not GAMEPAD_OPTIONS or type(ZO_PostHook) ~= "function" then
        return
    end

    headerVersionHooked = true
    ZO_PostHook(GAMEPAD_OPTIONS, "RefreshHeader", function()
        -- Other add-ons share this header and may also post-hook RefreshHeader.
        -- Apply NQOL's subtitle after the synchronous hook chain has completed.
        if type(zo_callLater) == "function" then
            zo_callLater(GamepadOptions.ApplyHeaderVersionSubtitle, 0)
        else
            GamepadOptions.ApplyHeaderVersionSubtitle()
        end
    end)
end

function GamepadOptions.RegisterPanels()
    if panelsRegistered then
        return true
    end

    if not GAMEPAD_OPTIONS or not GAMEPAD_SETTINGS_DATA or not ZO_GamepadEntryData then
        return false
    end

    GamepadOptions.HookHeaderVersionSubtitle()
    GamepadOptions.RegisterPanelHeaderStrings()
    if not GAMEPAD_SETTINGS_DATA[ROOT_PANEL_ID] then
        GamepadOptions.RegisterPanel(ROOT_PANEL_ID, GamepadOptions.BuildRootOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[MOUNTS_PANEL_ID] then
        GamepadOptions.RegisterPanel(MOUNTS_PANEL_ID, GamepadOptions.BuildMountsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[ANTIQUITIES_PANEL_ID] then
        GamepadOptions.RegisterPanel(ANTIQUITIES_PANEL_ID, GamepadOptions.BuildAntiquitiesOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GEAR_PANEL_ID] then
        GamepadOptions.RegisterPanel(GEAR_PANEL_ID, GamepadOptions.BuildGearOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[AUTO_CHARGE_PANEL_ID] then
        GamepadOptions.RegisterPanel(AUTO_CHARGE_PANEL_ID, GamepadOptions.BuildAutoChargeOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[AUTO_REPAIR_PANEL_ID] then
        GamepadOptions.RegisterPanel(AUTO_REPAIR_PANEL_ID, GamepadOptions.BuildAutoRepairOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[AUTO_BOUND_PANEL_ID] then
        GamepadOptions.RegisterPanel(AUTO_BOUND_PANEL_ID, GamepadOptions.BuildAutoBoundOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[COMBAT_PANEL_ID] then
        GamepadOptions.RegisterPanel(COMBAT_PANEL_ID, GamepadOptions.BuildCombatOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[COMBAT_INFINITE_ARCHIVE_PANEL_ID] then
        GamepadOptions.RegisterPanel(COMBAT_INFINITE_ARCHIVE_PANEL_ID, GamepadOptions.BuildCombatInfiniteArchiveOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[COMBAT_MISCELLANEOUS_PANEL_ID] then
        GamepadOptions.RegisterPanel(COMBAT_MISCELLANEOUS_PANEL_ID, GamepadOptions.BuildCombatMiscellaneousOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[TRIAL_TIMER_PANEL_ID] then
        GamepadOptions.RegisterPanel(TRIAL_TIMER_PANEL_ID, GamepadOptions.BuildTrialTimerOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[ULTIMATE_COUNTDOWN_PANEL_ID] then
        GamepadOptions.RegisterPanel(ULTIMATE_COUNTDOWN_PANEL_ID, GamepadOptions.BuildUltimateCountdownOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[ULTIMATE_COUNTDOWN_FRONT_PANEL_ID] then
        GamepadOptions.RegisterPanel(ULTIMATE_COUNTDOWN_FRONT_PANEL_ID, GamepadOptions.BuildUltimateCountdownFrontOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[ULTIMATE_COUNTDOWN_BACK_PANEL_ID] then
        GamepadOptions.RegisterPanel(ULTIMATE_COUNTDOWN_BACK_PANEL_ID, GamepadOptions.BuildUltimateCountdownBackOptionsData())
    end

    if NQOL.IsDevMode and NQOL.IsDevMode() and not GAMEPAD_SETTINGS_DATA[DEBUG_PANEL_ID] then
        GamepadOptions.RegisterPanel(DEBUG_PANEL_ID, GamepadOptions.BuildDebugOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GROUPING_PANEL_ID] then
        GamepadOptions.RegisterPanel(GROUPING_PANEL_ID, GamepadOptions.BuildGroupingOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[AUTO_INVITE_PANEL_ID] then
        GamepadOptions.RegisterPanel(AUTO_INVITE_PANEL_ID, GamepadOptions.BuildAutoInviteOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[PROVISIONING_PANEL_ID] then
        GamepadOptions.RegisterPanel(PROVISIONING_PANEL_ID, GamepadOptions.BuildProvisioningOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[MAP_PANEL_ID] then
        GamepadOptions.RegisterPanel(MAP_PANEL_ID, GamepadOptions.BuildMapOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[MAP_OPTIONS_PANEL_ID] then
        GamepadOptions.RegisterPanel(MAP_OPTIONS_PANEL_ID, GamepadOptions.BuildMapSettingsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[MINIMAP_PANEL_ID] then
        GamepadOptions.RegisterPanel(MINIMAP_PANEL_ID, GamepadOptions.BuildMinimapOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GPS_PANEL_ID] then
        GamepadOptions.RegisterPanel(GPS_PANEL_ID, GamepadOptions.BuildGPSOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[FISHING_PANEL_ID] then
        GamepadOptions.RegisterPanel(FISHING_PANEL_ID, GamepadOptions.BuildFishingOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[FISHING_TRACKER_PANEL_ID] then
        GamepadOptions.RegisterPanel(FISHING_TRACKER_PANEL_ID, GamepadOptions.BuildFishingTrackerOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[UI_PANEL_ID] then
        GamepadOptions.RegisterPanel(UI_PANEL_ID, GamepadOptions.BuildUIOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[CAMERA_PANEL_ID] then
        GamepadOptions.RegisterPanel(CAMERA_PANEL_ID, GamepadOptions.BuildCameraOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[DEFAULT_FRAMES_PANEL_ID] then
        GamepadOptions.RegisterPanel(DEFAULT_FRAMES_PANEL_ID, GamepadOptions.BuildDefaultFramesOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[COMBAT_RETICLE_PANEL_ID] then
        GamepadOptions.RegisterPanel(COMBAT_RETICLE_PANEL_ID, GamepadOptions.BuildCombatReticleOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[RETICLE_INFO_PANEL_ID] then
        GamepadOptions.RegisterPanel(RETICLE_INFO_PANEL_ID, GamepadOptions.BuildReticleInfoOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[RETICLE_INFO_TOP_LEFT_PANEL_ID] then
        GamepadOptions.RegisterPanel(RETICLE_INFO_TOP_LEFT_PANEL_ID, GamepadOptions.BuildReticleInfoTopLeftOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[RETICLE_INFO_TOP_RIGHT_PANEL_ID] then
        GamepadOptions.RegisterPanel(RETICLE_INFO_TOP_RIGHT_PANEL_ID, GamepadOptions.BuildReticleInfoTopRightOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[RETICLE_INFO_BOTTOM_LEFT_PANEL_ID] then
        GamepadOptions.RegisterPanel(RETICLE_INFO_BOTTOM_LEFT_PANEL_ID, GamepadOptions.BuildReticleInfoBottomLeftOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID] then
        GamepadOptions.RegisterPanel(RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID, GamepadOptions.BuildReticleInfoBottomRightOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[ACTIVE_QUEST_PANEL_ID] then
        GamepadOptions.RegisterPanel(ACTIVE_QUEST_PANEL_ID, GamepadOptions.BuildActiveQuestOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[ACTIVE_COMBAT_TIPS_PANEL_ID] then
        GamepadOptions.RegisterPanel(ACTIVE_COMBAT_TIPS_PANEL_ID, GamepadOptions.BuildActiveCombatTipsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[SYNERGY_PROMPTS_PANEL_ID] then
        GamepadOptions.RegisterPanel(SYNERGY_PROMPTS_PANEL_ID, GamepadOptions.BuildSynergyPromptsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[CENTER_SCREEN_ANNOUNCE_PANEL_ID] then
        GamepadOptions.RegisterPanel(CENTER_SCREEN_ANNOUNCE_PANEL_ID, GamepadOptions.BuildCenterScreenAnnounceOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[ANNOUNCEMENTS_PANEL_ID] then
        GamepadOptions.RegisterPanel(ANNOUNCEMENTS_PANEL_ID, GamepadOptions.BuildAnnouncementsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[INFINITE_ARCHIVE_FRAME_PANEL_ID] then
        GamepadOptions.RegisterPanel(INFINITE_ARCHIVE_FRAME_PANEL_ID, GamepadOptions.BuildInfiniteArchiveFrameOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[LOOT_LOG_PANEL_ID] then
        GamepadOptions.RegisterPanel(LOOT_LOG_PANEL_ID, GamepadOptions.BuildLootLogOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[PLAYER_INFO_PANEL_ID] then
        GamepadOptions.RegisterPanel(PLAYER_INFO_PANEL_ID, GamepadOptions.BuildPlayerInfoOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[PLAYER_INTERACTION_PANEL_ID] then
        GamepadOptions.RegisterPanel(PLAYER_INTERACTION_PANEL_ID, GamepadOptions.BuildPlayerInteractionOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[SUBTITLES_PANEL_ID] then
        GamepadOptions.RegisterPanel(SUBTITLES_PANEL_ID, GamepadOptions.BuildSubtitlesOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.FRAME_STYLING_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.FRAME_STYLING_PANEL_ID, GamepadOptions.BuildFrameStylingOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.PLAYER_FRAME_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.PLAYER_FRAME_PANEL_ID, GamepadOptions.BuildPlayerFrameOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, GamepadOptions.BuildClassicOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, GamepadOptions.BuildPyramidOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, GamepadOptions.BuildStackOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, GamepadOptions.BuildVerticalOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, GamepadOptions.BuildRadialOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.COMPANION_FRAME_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.COMPANION_FRAME_PANEL_ID, GamepadOptions.BuildCompanionFrameOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.GROUP_FRAME_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.GROUP_FRAME_PANEL_ID, GamepadOptions.BuildGroupFrameOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[CHAT_PANEL_ID] then
        GamepadOptions.RegisterPanel(CHAT_PANEL_ID, GamepadOptions.BuildChatOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[SOCIAL_PANEL_ID] then
        GamepadOptions.RegisterPanel(SOCIAL_PANEL_ID, GamepadOptions.BuildSocialOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[FRIENDS_PANEL_ID] then
        GamepadOptions.RegisterPanel(FRIENDS_PANEL_ID, GamepadOptions.BuildFriendsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GROUP_FINDER_MONITOR_PANEL_ID] then
        GamepadOptions.RegisterPanel(GROUP_FINDER_MONITOR_PANEL_ID, GamepadOptions.BuildGroupFinderMonitorOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[CHAT_GUILD_COLORS_PANEL_ID] then
        GamepadOptions.RegisterPanel(CHAT_GUILD_COLORS_PANEL_ID, GamepadOptions.BuildChatGuildColorsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[CHAT_REMINDERS_PANEL_ID] then
        GamepadOptions.RegisterPanel(CHAT_REMINDERS_PANEL_ID, GamepadOptions.BuildChatRemindersOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[TICKER_PANEL_ID] then
        GamepadOptions.RegisterPanel(TICKER_PANEL_ID, GamepadOptions.BuildTickerOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[UTILITY_PANEL_ID] then
        GamepadOptions.RegisterPanel(UTILITY_PANEL_ID, GamepadOptions.BuildUtilityOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[LUA_GC_PANEL_ID] then
        GamepadOptions.RegisterPanel(LUA_GC_PANEL_ID, GamepadOptions.BuildLuaGcOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[BUFFS_DEBUFFS_PANEL_ID] then
        GamepadOptions.RegisterPanel(BUFFS_DEBUFFS_PANEL_ID, GamepadOptions.BuildBuffsDebuffsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[BUFFS_DEBUFFS_TRACKERS_PANEL_ID] then
        GamepadOptions.RegisterPanel(BUFFS_DEBUFFS_TRACKERS_PANEL_ID, GamepadOptions.BuildBuffsDebuffsTrackersOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[PROGRESS_PANEL_ID] then
        GamepadOptions.RegisterPanel(PROGRESS_PANEL_ID, GamepadOptions.BuildProgressOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[XP_TRACKER_PANEL_ID] then
        GamepadOptions.RegisterPanel(XP_TRACKER_PANEL_ID, GamepadOptions.BuildXpTrackerOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[XP_TIMERS_PANEL_ID] then
        GamepadOptions.RegisterPanel(XP_TIMERS_PANEL_ID, GamepadOptions.BuildXpTimersOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.GOLD_TRACKER_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.GOLD_TRACKER_PANEL_ID, GamepadOptions.BuildGoldTrackerOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.GOLD_TIMERS_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.GOLD_TIMERS_PANEL_ID, GamepadOptions.BuildGoldTimersOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.DUNGEONS_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.DUNGEONS_PANEL_ID, GamepadOptions.BuildBaseDungeonsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.DLC_DUNGEONS_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.DLC_DUNGEONS_PANEL_ID, GamepadOptions.BuildDlcDungeonsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.TRIALS_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.TRIALS_PANEL_ID, GamepadOptions.BuildTrialsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.ARENAS_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.ARENAS_PANEL_ID, GamepadOptions.BuildArenasOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.SOLO_DUNGEONS_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.SOLO_DUNGEONS_PANEL_ID, GamepadOptions.BuildSoloDungeonsOptionsData())
    end

    if not GAMEPAD_SETTINGS_DATA[GamepadOptions.INFINITE_ARCHIVE_PANEL_ID] then
        GamepadOptions.RegisterPanel(GamepadOptions.INFINITE_ARCHIVE_PANEL_ID, GamepadOptions.BuildInfiniteArchiveOptionsData())
    end

    panelsRegistered = true
    return true
end

local function OpenRootPanel()
    if not GAMEPAD_OPTIONS or not SCENE_MANAGER then
        return
    end

    GAMEPAD_OPTIONS.currentCategory = ROOT_PANEL_ID
    if NQOL.Features and NQOL.Features.UI then
        NQOL.Features.UI.SetCombatReticleSettingsPanelVisible(false)
    end
    SetDefaultFramePreviewPanel(nil)
    if NQOL.Features and NQOL.Features.UIPlayerInfo then
        NQOL.Features.UIPlayerInfo.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.Minimap then
        NQOL.Features.Minimap.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.GPS then
        NQOL.Features.GPS.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.PlayerBars then
        NQOL.Features.PlayerBars.SetSettingsPanelVisible(false)
        NQOL.Features.PlayerBars.SetCompanionSettingsPanelVisible(false)
        NQOL.Features.PlayerBars.SetGroupSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.Chat then
        NQOL.Features.Chat.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.ChatReminders then
        NQOL.Features.ChatReminders.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.Friends then
        NQOL.Features.Friends.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.Ticker then
        NQOL.Features.Ticker.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.BuffsDebuffs then
        NQOL.Features.BuffsDebuffs.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.Progress then
        NQOL.Features.Progress.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.ProgressGold then
        NQOL.Features.ProgressGold.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.ProgressDungeons then
        NQOL.Features.ProgressDungeons.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.ProgressTrials then
        NQOL.Features.ProgressTrials.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.ProgressArenas then
        NQOL.Features.ProgressArenas.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.ProgressSoloDungeons then
        NQOL.Features.ProgressSoloDungeons.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.ProgressInfiniteArchive then
        NQOL.Features.ProgressInfiniteArchive.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.Fishing then
        NQOL.Features.Fishing.SetSettingsPanelVisible(false)
    end
    if NQOL.Features and NQOL.Features.UltimateCountdown then
        NQOL.Features.UltimateCountdown.SetSettingsPanelVisible(nil)
    end
    if NQOL.Features and NQOL.Features.TrialTimer then
        NQOL.Features.TrialTimer.SetSettingsPanelVisible(false)
    end
    SCENE_MANAGER:Push("gamepad_options_panel")
end

local function FindMainMenuEntry(entries, entryId)
    for index, entry in ipairs(entries or {}) do
        if entry.id == entryId then
            return entry, index
        end
    end

    return nil, nil
end

local function GetMainMenuSubMenu(entry)
    if not entry then
        return nil
    end

    local subMenu = entry.subMenu or (entry.data and entry.data.subMenu) or {}
    entry.subMenu = subMenu
    if entry.data then
        entry.data.subMenu = subMenu
    end
    return subMenu
end

local function GetMainMenuSortName(entry)
    local name = entry and entry.data and entry.data.name or entry and entry.text or ""
    if type(name) == "function" then
        name = name()
    end

    name = tostring(name or "")
    name = string.gsub(name, "|[Cc]%x%x%x%x%x%x", "")
    name = string.gsub(name, "|[Rr]", "")
    return NQOL.Util.Lower(name)
end

local function InsertMainMenuEntry(entries, entry)
    local sortName = GetMainMenuSortName(entry)
    local insertIndex = #entries + 1
    for index, existingEntry in ipairs(entries) do
        if sortName < GetMainMenuSortName(existingEntry) then
            insertIndex = index
            break
        end
    end
    table.insert(entries, insertIndex, entry)
end

local function CreateMainMenuEntry(name, icon, entryId, activatedCallback)
    local entryData = {
        name = name,
        icon = icon,
        activatedCallback = activatedCallback,
    }
    local entry = ZO_GamepadEntryData:New(name, icon)
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry.data = entryData
    entry.id = entryId
    return entry
end

local function RefreshMainMenu()
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.UpdateEntryEnabledStates then
        MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates()
    elseif MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.RefreshMainList then
        MAIN_MENU_GAMEPAD:RefreshMainList()
    end
end

local function AddNQOLMainMenuEntry(addonsEntry)
    local subMenu = GetMainMenuSubMenu(addonsEntry)
    if not subMenu or FindMainMenuEntry(subMenu, MAIN_MENU_ENTRY_ID) then
        return false
    end

    InsertMainMenuEntry(subMenu, CreateMainMenuEntry(
        CATEGORY_NAME,
        ADDON_ENTRY_ICON,
        MAIN_MENU_ENTRY_ID,
        OpenRootPanel
    ))
    return true
end

local function MergeFallbackAddonsMenu(fallbackEntry, sharedEntry)
    local fallbackSubMenu = GetMainMenuSubMenu(fallbackEntry)
    local sharedSubMenu = GetMainMenuSubMenu(sharedEntry)
    if not fallbackSubMenu or not sharedSubMenu then
        return false
    end

    local changed = false
    for _, childEntry in ipairs(fallbackSubMenu) do
        if childEntry.id and not FindMainMenuEntry(sharedSubMenu, childEntry.id) then
            InsertMainMenuEntry(sharedSubMenu, childEntry)
            changed = true
        end
    end
    return changed
end

function GamepadOptions.EnsureMainMenuEntry(createFallback)
    if not ZO_MENU_ENTRIES or not ZO_MENU_MAIN_ENTRIES or not ZO_GamepadEntryData or not SCENE_MANAGER then
        return false
    end

    local sharedEntry = FindMainMenuEntry(ZO_MENU_ENTRIES, SHARED_ADDONS_MENU_ENTRY_ID)
    local fallbackEntry, fallbackIndex = FindMainMenuEntry(ZO_MENU_ENTRIES, FALLBACK_ADDONS_MENU_ENTRY_ID)

    if sharedEntry then
        local changed = false
        if fallbackEntry then
            changed = MergeFallbackAddonsMenu(fallbackEntry, sharedEntry) or changed
            table.remove(ZO_MENU_ENTRIES, fallbackIndex)
            changed = true
        end
        changed = AddNQOLMainMenuEntry(sharedEntry) or changed
        if changed then
            RefreshMainMenu()
        end
        return true
    end

    if fallbackEntry then
        if AddNQOLMainMenuEntry(fallbackEntry) then
            RefreshMainMenu()
        end
        return true
    end

    if not createFallback then
        return false
    end

    local subMenu = {}
    local entryData = {
        name = GetString(SI_GAME_MENU_ADDONS),
        icon = ADDONS_MENU_ICON,
        customTemplate = "ZO_GamepadMenuEntryTemplateWithArrow",
        subMenu = subMenu,
    }
    local addonsEntry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
    addonsEntry:SetIconTintOnSelection(true)
    addonsEntry:SetIconDisabledTintOnSelection(true)
    addonsEntry.data = entryData
    addonsEntry.id = FALLBACK_ADDONS_MENU_ENTRY_ID
    addonsEntry.subMenu = subMenu
    AddNQOLMainMenuEntry(addonsEntry)

    local _, activityFinderIndex = FindMainMenuEntry(ZO_MENU_ENTRIES, ZO_MENU_MAIN_ENTRIES.ACTIVITY_FINDER)
    if activityFinderIndex then
        table.insert(ZO_MENU_ENTRIES, activityFinderIndex, addonsEntry)
    else
        table.insert(ZO_MENU_ENTRIES, addonsEntry)
    end

    RefreshMainMenu()
    return true
end

function GamepadOptions.InstallSharedAddonsMenuHook()
    if sharedAddonsMenuHookInstalled then
        return true
    end
    if not LibHarvensAddonSettings
        or type(LibHarvensAddonSettings.CreateAddonSettingsPanel) ~= "function"
        or type(ZO_PostHook) ~= "function"
    then
        return false
    end

    ZO_PostHook(LibHarvensAddonSettings, "CreateAddonSettingsPanel", function()
        GamepadOptions.EnsureMainMenuEntry(false)
    end)
    sharedAddonsMenuHookInstalled = true
    GamepadOptions.EnsureMainMenuEntry(false)
    return true
end

function GamepadOptions.InstallMainMenuWatcher()
    if mainMenuWatcherInstalled then
        return true
    end
    if not MAIN_MENU_GAMEPAD_SCENE or not MAIN_MENU_GAMEPAD_SCENE.RegisterCallback
        or type(zo_callLater) ~= "function"
    then
        return false
    end

    MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING or newState == "showing" then
            zo_callLater(function()
                GamepadOptions.EnsureMainMenuEntry(true)
            end, 0)
        end
    end)
    mainMenuWatcherInstalled = true

    if MAIN_MENU_GAMEPAD_SCENE.IsShowing and MAIN_MENU_GAMEPAD_SCENE:IsShowing() then
        zo_callLater(function()
            GamepadOptions.EnsureMainMenuEntry(true)
        end, 0)
    end
    return true
end

function GamepadOptions.InstallSubpanelBackOverride()
    if backOverrideInstalled or not SCENE_MANAGER then
        return
    end

    local panelScene = SCENE_MANAGER:GetScene("gamepad_options_panel")
    if not panelScene then
        return
    end

    panelScene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING or newState == "showing" then
            if NQOL.Features and NQOL.Features.UI and GAMEPAD_OPTIONS then
                NQOL.Features.UI.SetCombatReticleSettingsPanelVisible(COMBAT_RETICLE_PREVIEW_PANEL_IDS[GAMEPAD_OPTIONS.currentCategory] == true)
                SetDefaultFramePreviewPanel(GAMEPAD_OPTIONS.currentCategory)
            end
            if GAMEPAD_OPTIONS and GamepadOptions.IsSubpanel(GAMEPAD_OPTIONS.currentCategory) then
                GamepadOptions.ReplaceSubpanelBackKeybind()
            end
        elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN or newState == "hiding" or newState == "hidden" then
            if NQOL.Features and NQOL.Features.UI then
                NQOL.Features.UI.SetCombatReticleSettingsPanelVisible(false)
            end
            SetDefaultFramePreviewPanel(nil)
            if NQOL.Features and NQOL.Features.PlayerBars then
                NQOL.Features.PlayerBars.SetSettingsPanelVisible(false)
                NQOL.Features.PlayerBars.SetCompanionSettingsPanelVisible(false)
                NQOL.Features.PlayerBars.SetGroupSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.Minimap then
                NQOL.Features.Minimap.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.GPS then
                NQOL.Features.GPS.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.Chat then
                NQOL.Features.Chat.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.Ticker then
                NQOL.Features.Ticker.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.BuffsDebuffs then
                NQOL.Features.BuffsDebuffs.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.Progress then
                NQOL.Features.Progress.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.ProgressGold then
                NQOL.Features.ProgressGold.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.ProgressDungeons then
                NQOL.Features.ProgressDungeons.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.ProgressTrials then
                NQOL.Features.ProgressTrials.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.ProgressArenas then
                NQOL.Features.ProgressArenas.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.ProgressSoloDungeons then
                NQOL.Features.ProgressSoloDungeons.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.ProgressInfiniteArchive then
                NQOL.Features.ProgressInfiniteArchive.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.Fishing then
                NQOL.Features.Fishing.SetSettingsPanelVisible(false)
            end
            if NQOL.Features and NQOL.Features.UltimateCountdown then
                NQOL.Features.UltimateCountdown.SetSettingsPanelVisible(nil)
            end
            if NQOL.Features and NQOL.Features.TrialTimer then
                NQOL.Features.TrialTimer.SetSettingsPanelVisible(false)
            end
            if GAMEPAD_OPTIONS then
                GAMEPAD_OPTIONS:RevertBackKeybind()
            end
            if newState == SCENE_HIDDEN or newState == "hidden" then
                GamepadOptions.PromptForPendingLanguageChange()
            end
        end
    end)

    backOverrideInstalled = true
end

function GamepadOptions.Initialize()
    GamepadOptions.InstallSubpanelBackOverride()

    local attempts = 0
    local function TryRegister()
        local panelsReady = GamepadOptions.RegisterPanels()
        GamepadOptions.InstallSharedAddonsMenuHook()
        GamepadOptions.EnsureMainMenuEntry(false)
        local mainMenuWatcherReady = GamepadOptions.InstallMainMenuWatcher()
        if panelsReady and mainMenuWatcherReady then
            return
        end

        attempts = attempts + 1
        if attempts < 10 then
            zo_callLater(TryRegister, 1000)
        end
    end

    TryRegister()
end

NQOL.GamepadOptions = GamepadOptions
