NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local UI = {}

local APPLY_DELAY_MS = 50
local DEFAULT_MAX_WIDTH = 1920
local DEFAULT_MAX_HEIGHT = 1080
local ALERT_TEXT_NAMESPACE = "NQOL_UI_AlertText"
local ACTIVE_COMBAT_TIPS_NAMESPACE = "NQOL_UI_ActiveCombatTips"
local SYNERGY_PROMPTS_NAMESPACE = "NQOL_UI_SynergyPrompts"
local CENTER_SCREEN_ANNOUNCE_NAMESPACE = "NQOL_UI_CenterScreenAnnounce"
local MOVABLE_UI_FRAMES_NAMESPACE = "NQOL_UI_MovableFrames"
local PLAYER_FRAME_VISIBILITY_NAMESPACE = "NQOL_UI_PlayerFrameVisibility"
local COMPANION_FRAME_VISIBILITY_NAMESPACE = "NQOL_UI_CompanionFrameVisibility"
local GROUP_FRAME_VISIBILITY_NAMESPACE = "NQOL_UI_GroupFrameVisibility"
local LOOT_LOG_PRICE_OFF = "off"
local LOOT_LOG_PRICE_MIN = "min"
local LOOT_LOG_PRICE_MAX = "max"
local LOOT_LOG_PRICE_AVERAGE = "average"
local DUNGEON_FINDER_SPECIFIC_NAVIGATION_MODE = 3
local DUNGEON_FINDER_SORT_RETRY_MS = 1000
local DUNGEON_FINDER_SORT_MAX_ATTEMPTS = 10
local PREVIEW_BORDER_PADDING = 8
local PREVIEW_BORDER_MIN_WIDTH = 180
local PREVIEW_BORDER_MIN_HEIGHT = 48
local PREVIEW_BORDER_COLOR = { 1, 0.48, 0 }
local ACTIVE_COMBAT_TIPS_PANEL_ID = 9142
local SYNERGY_PROMPTS_PANEL_ID = 9143
local CENTER_SCREEN_ANNOUNCE_PANEL_ID = 9144
local ACTIVE_QUEST_PREVIEW_WIDTH = 350
local ACTIVE_QUEST_PREVIEW_HEIGHT = 120
local ACTIVE_COMBAT_TIPS_PREVIEW_WIDTH = 250
local ACTIVE_COMBAT_TIPS_PREVIEW_HEIGHT = 20
local SYNERGY_PROMPTS_PREVIEW_WIDTH = 200
local SYNERGY_PROMPTS_PREVIEW_HEIGHT = 50
local ACTIVE_QUEST_SEPARATION_KEYS = { { false, "originalSeparatedKeyboard" }, { true, "originalSeparatedGamepad" } }
local MOVABLE_UI_FRAMES = {
    announcements = {
        controlName = "ZO_AlertTextNotificationGamepad",
        wrapperName = "NQOL_UI_Announcements",
        previewName = "Announcements",
        label = NQOL.L("features.ui.announcements"),
        width = 500,
        height = 90,
        defaultHorizontalPosition = 100,
        defaultVerticalPosition = 0,
    },
    infiniteArchive = {
        controlName = "ZO_EndDunHUDTrackerContainer",
        wrapperName = "NQOL_UI_InfiniteArchive",
        previewName = "InfiniteArchive",
        label = NQOL.L("features.ui.infinite_archive_frame_53d0c3a"),
        width = 230,
        height = 100,
        defaultHorizontalPosition = 100,
        defaultVerticalPosition = 0,
        defaultAnchor = function(control)
            if ENDLESS_DUNGEON_HUD_TRACKER and ENDLESS_DUNGEON_HUD_TRACKER.RefreshAnchors then
                ENDLESS_DUNGEON_HUD_TRACKER:RefreshAnchors()
            elseif ZO_EndDunHUDTracker then
                control:SetAnchor(TOPLEFT, ZO_EndDunHUDTracker, TOPLEFT, 0, 0)
                control:SetAnchor(TOPRIGHT, ZO_EndDunHUDTracker, TOPRIGHT, -15, 0)
            end
        end,
    },
    playerInteraction = {
        controlName = "ZO_PlayerToPlayerAreaPromptContainer",
        wrapperName = "NQOL_UI_PlayerInteraction",
        previewName = "PlayerInteraction",
        label = NQOL.L("features.ui.player_interaction_e138127"),
        width = 870,
        height = 30,
        defaultHorizontalPosition = 50,
        defaultVerticalPosition = 90,
        defaultAnchor = function(control)
            control:SetAnchor(BOTTOM, nil, BOTTOM, 0, -285)
        end,
    },
    subtitles = {
        controlName = "ZO_Subtitles",
        wrapperName = "NQOL_UI_Subtitles",
        previewName = "Subtitles",
        label = NQOL.L("features.ui.subtitles_1777047"),
        width = 256,
        height = 80,
        defaultHorizontalPosition = 50,
        defaultVerticalPosition = 86,
        defaultAnchor = function(control)
            if ZO_PlayerToPlayerAreaPromptContainerTarget then
                control:SetAnchor(BOTTOM, ZO_PlayerToPlayerAreaPromptContainerTarget, TOP, 0, 0)
            else
                control:SetAnchor(CENTER, GuiRoot, BOTTOM, 0, -150)
            end
        end,
    },
}
local PREVIEW_BORDER_LABELS = {
    ActiveCombatTips = NQOL.L("features.ui.active_combat_tips"),
    ActiveQuest = NQOL.L("ui.gamepad_options.active_quest_8036d24"),
    Announcements = NQOL.L("features.ui.announcements"),
    InfiniteArchive = NQOL.L("features.ui.infinite_archive"),
    PlayerInteraction = NQOL.L("features.ui.player_interaction"),
    SynergyPrompts = NQOL.L("features.ui.synergy_prompts"),
    Subtitles = NQOL.L("features.ui.subtitles"),
    CenterScreenAnnounce = NQOL.L("features.ui.center_screen_announce"),
}
NQOL.Lexicon.RegisterRefreshCallback(function()
    MOVABLE_UI_FRAMES.announcements.label = NQOL.L("features.ui.announcements")
    MOVABLE_UI_FRAMES.infiniteArchive.label = NQOL.L("features.ui.infinite_archive_frame_53d0c3a")
    MOVABLE_UI_FRAMES.playerInteraction.label = NQOL.L("features.ui.player_interaction_e138127")
    MOVABLE_UI_FRAMES.subtitles.label = NQOL.L("features.ui.subtitles_1777047")
    PREVIEW_BORDER_LABELS.ActiveCombatTips = NQOL.L("features.ui.active_combat_tips")
    PREVIEW_BORDER_LABELS.ActiveQuest = NQOL.L("ui.gamepad_options.active_quest_8036d24")
    PREVIEW_BORDER_LABELS.Announcements = NQOL.L("features.ui.announcements")
    PREVIEW_BORDER_LABELS.InfiniteArchive = NQOL.L("features.ui.infinite_archive")
    PREVIEW_BORDER_LABELS.PlayerInteraction = NQOL.L("features.ui.player_interaction")
    PREVIEW_BORDER_LABELS.SynergyPrompts = NQOL.L("features.ui.synergy_prompts")
    PREVIEW_BORDER_LABELS.Subtitles = NQOL.L("features.ui.subtitles")
    PREVIEW_BORDER_LABELS.CenterScreenAnnounce = NQOL.L("features.ui.center_screen_announce")
end)

local defaults = {
    ui = {
        combatReticle = {
            shape = "default",
            scale = 1,
            animated = true,
            color = { r = 1, g = 1, b = 1, a = 1 },
            fightColor = { r = 1, g = 1, b = 1, a = 1 },
            info = {
                topLeft = { content = "off", iconPosition = "off", horizontalOffset = -60, verticalOffset = -30, font = NQOL.Util.GetDefaultFont(), fontSize = 28, color = { r = 1, g = 1, b = 1, a = 1 } },
                topRight = { content = "off", iconPosition = "off", horizontalOffset = 60, verticalOffset = -30, font = NQOL.Util.GetDefaultFont(), fontSize = 28, color = { r = 1, g = 1, b = 1, a = 1 } },
                bottomLeft = { content = "off", iconPosition = "off", horizontalOffset = -60, verticalOffset = 30, font = NQOL.Util.GetDefaultFont(), fontSize = 28, color = { r = 1, g = 1, b = 1, a = 1 } },
                bottomRight = { content = "off", iconPosition = "off", horizontalOffset = 60, verticalOffset = 30, font = NQOL.Util.GetDefaultFont(), fontSize = 28, color = { r = 1, g = 1, b = 1, a = 1 } },
            },
        },
        disableAlertTexts = false,
        sortDungeonsFinder = false,
        activeQuest = {
            enabled = false,
            horizontalPosition = 100,
            verticalPosition = 50,
        },
        activeCombatTips = {
            enabled = false,
            horizontalPosition = 50,
            verticalPosition = 82,
        },
        synergyPrompts = {
            enabled = false,
            horizontalPosition = 50,
            verticalPosition = 85,
        },
        centerScreenAnnounce = {
            enabled = false,
            horizontalPosition = 50,
            verticalPosition = 27,
        },
        announcements = {
            enabled = false,
            horizontalPosition = 100,
            verticalPosition = 0,
        },
        infiniteArchive = {
            enabled = false,
            horizontalPosition = 100,
            verticalPosition = 0,
        },
        playerInteraction = {
            enabled = false,
            horizontalPosition = 50,
            verticalPosition = 90,
        },
        subtitles = {
            enabled = false,
            horizontalPosition = 50,
            verticalPosition = 86,
        },
        lootLog = {
            showTotals = false,
            showPrice = LOOT_LOG_PRICE_OFF,
            bufferSize = 5,
            timerSeconds = 4,
        },
    },
}

local savedVariables
local initialized = false
local activeQuestApplyQueued = false
local activeQuestLayoutHookInstalled = false
local activeCombatTipsApplyQueued = false
local synergyPromptsApplyQueued = false
local centerScreenAnnounceApplyQueued = false
local movableUiFrameApplyQueued = {}
local activeCombatTipsHookInstalled = false
local synergyPromptsHookInstalled = false
local centerScreenAnnounceHookInstalled = false
local activeCombatTipsEventsInstalled = false
local synergyPromptsEventsInstalled = false
local centerScreenAnnounceEventsInstalled = false
local movableUiFrameEventsInstalled = false
local infiniteArchiveFrameHookInstalled = false
local dungeonFinderSortHookInstalled = false
local officialUnitFrameCreateHookInstalled = false
local dungeonFinderSortHookAttempts = 0
local activeQuestSettingsPanelVisible = false
local activeCombatTipsSettingsPanelVisible = false
local synergyPromptsSettingsPanelVisible = false
local centerScreenAnnounceSettingsPanelVisible = false
local movableUiFrameSettingsPanelVisible = {}
local previewBorders = {}
local officialPlayerFrameBarRequirements = {}
local UpdatePositionPreviewBorder
local runtimeState = {
    alertTextEventsInstalled = false,
    alertTextHooksInstalled = false,
    playerFrameEventsInstalled = false,
    companionFrameEventsInstalled = false,
    groupFrameEventsInstalled = false,
    groupFrameRetryDelays = { 200, 750, 1000 },
    activeCombatTipsActive = false,
    synergyPromptsActive = false,
    centerScreenAnnounceActive = false,
    movableUiFrameActive = {},
    anyMovableUiFrameActive = false,
    alertTextsActive = false,
    dungeonFinderSortActive = false,
}

local Clamp = NQOL.Util.Clamp

local function GetScreenWidth()
    if GuiRoot and GuiRoot.GetWidth then
        return math.floor(GuiRoot:GetWidth())
    end

    return DEFAULT_MAX_WIDTH
end

local function GetScreenHeight()
    if GuiRoot and GuiRoot.GetHeight then
        return math.floor(GuiRoot:GetHeight())
    end

    return DEFAULT_MAX_HEIGHT
end

local function GetSettings()
    local settings = NQOL.Settings.GetSection(savedVariables, defaults, "ui")
    settings.coloredCombatReticle = nil
    NQOL.Settings.Boolean(settings, defaults.ui, "disableAlertTexts")
    NQOL.Settings.Boolean(settings, defaults.ui, "sortDungeonsFinder")

    local combatReticleSettings = NQOL.Settings.EnsureTable(settings, "combatReticle")
    local combatReticleDefaults = defaults.ui.combatReticle
    NQOL.Settings.Default(combatReticleSettings, combatReticleDefaults, "shape")
    NQOL.Settings.ClampedNumber(combatReticleSettings, combatReticleDefaults, "scale", 1, 10)
    NQOL.Settings.Boolean(combatReticleSettings, combatReticleDefaults, "animated")
    combatReticleSettings.scale = math.floor(combatReticleSettings.scale + 0.5)
    if type(combatReticleSettings.color) ~= "table" then
        combatReticleSettings.color = {}
    end
    combatReticleSettings.color.r = Clamp(tonumber(combatReticleSettings.color.r) or combatReticleDefaults.color.r, 0, 1)
    combatReticleSettings.color.g = Clamp(tonumber(combatReticleSettings.color.g) or combatReticleDefaults.color.g, 0, 1)
    combatReticleSettings.color.b = Clamp(tonumber(combatReticleSettings.color.b) or combatReticleDefaults.color.b, 0, 1)
    combatReticleSettings.color.a = 1
    if type(combatReticleSettings.fightColor) ~= "table" then
        combatReticleSettings.fightColor = {}
    end
    combatReticleSettings.fightColor.r = Clamp(tonumber(combatReticleSettings.fightColor.r) or combatReticleDefaults.fightColor.r, 0, 1)
    combatReticleSettings.fightColor.g = Clamp(tonumber(combatReticleSettings.fightColor.g) or combatReticleDefaults.fightColor.g, 0, 1)
    combatReticleSettings.fightColor.b = Clamp(tonumber(combatReticleSettings.fightColor.b) or combatReticleDefaults.fightColor.b, 0, 1)
    combatReticleSettings.fightColor.a = 1
    local reticleInfoSettings = NQOL.Settings.EnsureTable(combatReticleSettings, "info")
    for _, positionKey in ipairs({ "topLeft", "topRight", "bottomLeft", "bottomRight" }) do
        local positionSettings = NQOL.Settings.EnsureTable(reticleInfoSettings, positionKey)
        local positionDefaults = combatReticleDefaults.info[positionKey]
        NQOL.Settings.Default(positionSettings, positionDefaults, "content")
        if positionSettings.content ~= "off" and positionSettings.content ~= "crux" and positionSettings.content ~= "offBalance" and positionSettings.content ~= "offBalanceImmunity" and positionSettings.content ~= "taunt" and positionSettings.content ~= "sulXan" and positionSettings.content ~= "zensRedress" then
            positionSettings.content = positionDefaults.content
        end
        NQOL.Settings.Default(positionSettings, positionDefaults, "iconPosition")
        if positionSettings.iconPosition ~= "off" and positionSettings.iconPosition ~= "left" and positionSettings.iconPosition ~= "right" then
            positionSettings.iconPosition = positionDefaults.iconPosition
        end
        NQOL.Settings.ClampedNumber(positionSettings, positionDefaults, "horizontalOffset", -500, 500)
        positionSettings.horizontalOffset = math.floor(positionSettings.horizontalOffset + 0.5)
        NQOL.Settings.ClampedNumber(positionSettings, positionDefaults, "verticalOffset", -500, 500)
        positionSettings.verticalOffset = math.floor(positionSettings.verticalOffset + 0.5)
        NQOL.Settings.Default(positionSettings, positionDefaults, "font")
        if not NQOL.Util.IsFontChoice(positionSettings.font) then
            positionSettings.font = positionDefaults.font
        end
        NQOL.Settings.ClampedNumber(positionSettings, positionDefaults, "fontSize", 12, 60)
        positionSettings.fontSize = math.floor(positionSettings.fontSize + 0.5)
        if type(positionSettings.color) ~= "table" then
            positionSettings.color = {}
        end
        positionSettings.color.r = Clamp(tonumber(positionSettings.color.r) or positionDefaults.color.r, 0, 1)
        positionSettings.color.g = Clamp(tonumber(positionSettings.color.g) or positionDefaults.color.g, 0, 1)
        positionSettings.color.b = Clamp(tonumber(positionSettings.color.b) or positionDefaults.color.b, 0, 1)
        positionSettings.color.a = 1
    end

    local activeQuestSettings = NQOL.Settings.EnsureTable(settings, "activeQuest")
    local activeQuestDefaults = defaults.ui.activeQuest

    activeQuestSettings.horizontalOffset = nil
    activeQuestSettings.verticalOffset = nil
    NQOL.Settings.Boolean(activeQuestSettings, activeQuestDefaults, "enabled")
    NQOL.Settings.ClampedNumber(activeQuestSettings, activeQuestDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(activeQuestSettings, activeQuestDefaults, "verticalPosition", 0, 100)
    activeQuestSettings.showInSettings = nil
    activeQuestSettings.drawBorders = nil

    local activeCombatTipsSettings = NQOL.Settings.EnsureTable(settings, "activeCombatTips")
    local activeCombatTipsDefaults = defaults.ui.activeCombatTips

    NQOL.Settings.Boolean(activeCombatTipsSettings, activeCombatTipsDefaults, "enabled")
    NQOL.Settings.ClampedNumber(activeCombatTipsSettings, activeCombatTipsDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(activeCombatTipsSettings, activeCombatTipsDefaults, "verticalPosition", 0, 100)
    activeCombatTipsSettings.drawBorders = nil

    local synergyPromptsSettings = NQOL.Settings.EnsureTable(settings, "synergyPrompts")
    local synergyPromptsDefaults = defaults.ui.synergyPrompts

    NQOL.Settings.Boolean(synergyPromptsSettings, synergyPromptsDefaults, "enabled")
    NQOL.Settings.ClampedNumber(synergyPromptsSettings, synergyPromptsDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(synergyPromptsSettings, synergyPromptsDefaults, "verticalPosition", 0, 100)
    synergyPromptsSettings.drawBorders = nil

    local centerScreenAnnounceSettings = NQOL.Settings.EnsureTable(settings, "centerScreenAnnounce")
    local centerScreenAnnounceDefaults = defaults.ui.centerScreenAnnounce

    NQOL.Settings.Boolean(centerScreenAnnounceSettings, centerScreenAnnounceDefaults, "enabled")
    NQOL.Settings.ClampedNumber(centerScreenAnnounceSettings, centerScreenAnnounceDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(centerScreenAnnounceSettings, centerScreenAnnounceDefaults, "verticalPosition", 0, 100)
    centerScreenAnnounceSettings.drawBorders = nil

    for key in pairs(MOVABLE_UI_FRAMES) do
        local frameSettings = NQOL.Settings.EnsureTable(settings, key)
        local frameDefaults = defaults.ui[key]

        NQOL.Settings.Boolean(frameSettings, frameDefaults, "enabled")
        NQOL.Settings.ClampedNumber(frameSettings, frameDefaults, "horizontalPosition", 0, 100)
        NQOL.Settings.ClampedNumber(frameSettings, frameDefaults, "verticalPosition", 0, 100)
        frameSettings.drawBorders = nil
    end

    local lootLogSettings = NQOL.Settings.EnsureTable(settings, "lootLog")
    local lootLogDefaults = defaults.ui.lootLog

    NQOL.Settings.Boolean(lootLogSettings, lootLogDefaults, "showTotals")
    NQOL.Settings.Default(lootLogSettings, lootLogDefaults, "showPrice")
    if lootLogSettings.showPrice ~= LOOT_LOG_PRICE_OFF
        and lootLogSettings.showPrice ~= LOOT_LOG_PRICE_MIN
        and lootLogSettings.showPrice ~= LOOT_LOG_PRICE_MAX
        and lootLogSettings.showPrice ~= LOOT_LOG_PRICE_AVERAGE
    then
        lootLogSettings.showPrice = lootLogDefaults.showPrice
    end
    NQOL.Settings.Default(lootLogSettings, lootLogDefaults, "bufferSize")
    if lootLogSettings.bufferSize ~= 5
        and lootLogSettings.bufferSize ~= 10
        and lootLogSettings.bufferSize ~= 15
        and lootLogSettings.bufferSize ~= 20
    then
        lootLogSettings.bufferSize = lootLogDefaults.bufferSize
    end
    NQOL.Settings.ClampedNumber(lootLogSettings, lootLogDefaults, "timerSeconds", 1, 10)
    lootLogSettings.timerSeconds = math.floor(lootLogSettings.timerSeconds + 0.5)

    return settings
end

local function GetActiveQuestSettings()
    return GetSettings().activeQuest
end

local function GetActiveCombatTipsSettings()
    return GetSettings().activeCombatTips
end

local function GetSynergyPromptsSettings()
    return GetSettings().synergyPrompts
end

local function GetMovableUiFrameSettings(key)
    return GetSettings()[key]
end

local function GetCenterScreenAnnounceSettings()
    return GetSettings().centerScreenAnnounce
end

local function GetLootLogSettings()
    return GetSettings().lootLog
end

function UI.GetLootLogSettings()
    return GetLootLogSettings()
end

function UI.GetCombatReticleSettings()
    return GetSettings().combatReticle
end

local function IsGamepadOptionsPanelActive(panelId)
    return GAMEPAD_OPTIONS and GAMEPAD_OPTIONS.currentCategory == panelId
end

local function IsActiveCombatTipsPreviewActive()
    return activeCombatTipsSettingsPanelVisible
end

local function IsSynergyPromptsPreviewActive()
    return synergyPromptsSettingsPanelVisible
end

local function IsMovableUiFramePreviewActive(key)
    return movableUiFrameSettingsPanelVisible[key] == true
end

local function IsCenterScreenAnnouncePreviewActive()
    return centerScreenAnnounceSettingsPanelVisible
end

function runtimeState.IsActiveCombatTipsActive()
    local settings = GetActiveCombatTipsSettings()
    return settings.enabled == true or activeCombatTipsSettingsPanelVisible
end

function runtimeState.IsSynergyPromptsActive()
    local settings = GetSynergyPromptsSettings()
    return settings.enabled == true or synergyPromptsSettingsPanelVisible
end

function runtimeState.IsCenterScreenAnnounceActive()
    local settings = GetCenterScreenAnnounceSettings()
    return settings.enabled == true or centerScreenAnnounceSettingsPanelVisible
end

function runtimeState.IsMovableUiFrameActive(key)
    local settings = GetMovableUiFrameSettings(key)
    return settings.enabled == true or movableUiFrameSettingsPanelVisible[key] == true
end

local function ApplyActiveQuestPosition()
    local settings = GetActiveQuestSettings()
    if not HUD_TRACKER_MANAGER or not HUD_TRACKER_MANAGER.isFullyLoaded or not FOCUSED_QUEST_TRACKER then
        return
    end

    -- The HUD tracker manager rebuilds anchors for grouped trackers.
    -- Separate the quest tracker while NQOL controls its position.
    if settings.enabled == true then
        local element = HUD_TRACKER_MANAGER:GetPlatformHUDElement()
        local originalKey = IsInGamepadPreferredMode() and "originalSeparatedGamepad" or "originalSeparatedKeyboard"
        local separated = element:GetCustomOptionValue("SeparatedTrackers", "Quest") == true
        if settings[originalKey] == nil then
            settings[originalKey] = separated
        end
        if not separated then
            element:SetCustomOptionValue("SeparatedTrackers", "Quest", true)
        end
    else
        local hadSeparationOverride = false
        for _, entry in ipairs(ACTIVE_QUEST_SEPARATION_KEYS) do
            local original = settings[entry[2]]
            if original ~= nil then
                hadSeparationOverride = true
                local element = HUD_TRACKER_MANAGER:GetHUDElement(entry[1])
                if element:GetCustomOptionValue("SeparatedTrackers", "Quest") ~= original then
                    element:SetCustomOptionValue("SeparatedTrackers", "Quest", original)
                end
                settings[entry[2]] = nil
            end
        end
        if hadSeparationOverride then
            HUD_TRACKER_MANAGER:RefreshLayout()
        end
    end

    local control = ZO_FocusedQuestTrackerPanel
    if not GuiRoot then
        return
    end

    local width = control and control:GetWidth() or 0
    local height = control and control:GetHeight() or 0
    if width <= 0 then width = ACTIVE_QUEST_PREVIEW_WIDTH end
    if height <= 0 then height = ACTIVE_QUEST_PREVIEW_HEIGHT end

    if settings.enabled == true and control then
        local x = math.max(GetScreenWidth() - width, 0) * settings.horizontalPosition * 0.01
        local y = math.max(GetScreenHeight() - height, 0) * settings.verticalPosition * 0.01
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    end

    UpdatePositionPreviewBorder("ActiveQuest", settings, activeQuestSettingsPanelVisible, width, height)
end

local function InstallActiveQuestLayoutHook()
    if activeQuestLayoutHookInstalled or not HUD_TRACKER_MANAGER or not HUD_TRACKER_MANAGER.RefreshLayout then
        return
    end

    activeQuestLayoutHookInstalled = true
    SecurePostHook(HUD_TRACKER_MANAGER, "RefreshLayout", ApplyActiveQuestPosition)
end

local function ApplyMovedControlPosition(control, settings, settingsPanelVisible, showControlInPreview)
    if settings.enabled ~= true and not (settingsPanelVisible and settings.showInSettings == true) then
        return
    end

    if not control or not GuiRoot then
        return
    end

    local width = control:GetWidth()
    local height = control:GetHeight()
    local x = math.max(GetScreenWidth() - width, 0) * settings.horizontalPosition * 0.01
    local y = math.max(GetScreenHeight() - height, 0) * settings.verticalPosition * 0.01

    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)

    if settingsPanelVisible and settings.showInSettings == true and showControlInPreview ~= false then
        control:SetHidden(false)
    end
end

local function GetGlobalControl(name)
    if type(name) ~= "string" then
        return nil
    end

    if GetControl then
        local control = GetControl(name)
        if control then
            return control
        end
    end

    return _G[name]
end

local function ApplyAnnouncementsFrameAnchor(control, relativeTo, rootOffsetY, bufferOffsetY, offsetX)
    control:ClearAnchors()
    control:SetAnchor(TOPRIGHT, relativeTo, TOPRIGHT, offsetX, rootOffsetY)

    local buffer = ALERT_MESSAGES_GAMEPAD and ALERT_MESSAGES_GAMEPAD.alerts
    if not buffer or not ZO_Anchor then
        return
    end

    buffer.anchor = ZO_Anchor:New(TOPRIGHT, relativeTo, TOPRIGHT, offsetX, bufferOffsetY)

    local activeEntries = buffer.activeEntries
    if not activeEntries then
        return
    end

    for index = 1, #activeEntries do
        buffer.anchor:Set(activeEntries[index])
    end

    if #activeEntries > 0 and buffer.MoveEntriesOrLines then
        buffer:MoveEntriesOrLines(activeEntries)
    end
end

local function GetMovableUiFrameWrapper(key)
    local frame = MOVABLE_UI_FRAMES[key]
    if not frame or not GuiRoot or not WINDOW_MANAGER then
        return nil
    end

    local control = GetGlobalControl(frame.controlName)
    if not control then
        return nil
    end

    local wrapper = _G[frame.wrapperName]
    if not wrapper then
        wrapper = WINDOW_MANAGER:CreateControl(frame.wrapperName, GuiRoot, CT_CONTROL)
        wrapper:SetAnchor(CENTER, GuiRoot, BOTTOM, 0, -150)
    end

    wrapper:SetDimensions(frame.width, frame.height)
    wrapper:SetDrawLayer(DL_CONTROLS)

    if key == "announcements" then
        ApplyAnnouncementsFrameAnchor(control, wrapper, 0, 0, 0)
    else
        control:ClearAnchors()
        control:SetAnchor(CENTER, wrapper, CENTER, 0, 0)
    end
    control:SetInheritScale(true)

    return wrapper
end

local function RestoreMovableUiFrameDefaultPosition(key)
    local frame = MOVABLE_UI_FRAMES[key]
    if not frame then
        return
    end

    local control = GetGlobalControl(frame.controlName)
    if not control then
        return
    end

    if key == "announcements" then
        ApplyAnnouncementsFrameAnchor(control, GuiRoot, 10, 4, -15)
    else
        control:ClearAnchors()
        if type(frame.defaultAnchor) == "function" then
            frame.defaultAnchor(control)
        end
    end
end

local function ApplyMovableUiFramePosition(key)
    local frame = MOVABLE_UI_FRAMES[key]
    if not frame then
        return
    end

    local settings = GetMovableUiFrameSettings(key)
    if settings.enabled == true then
        ApplyMovedControlPosition(GetMovableUiFrameWrapper(key), settings, false, false)
    else
        RestoreMovableUiFrameDefaultPosition(key)
    end

    UpdatePositionPreviewBorder(frame.previewName, settings, IsMovableUiFramePreviewActive(key), frame.width, frame.height)
end

local function GetPreviewBorder(name)
    if previewBorders[name] then
        return previewBorders[name]
    end

    local windowManager = WINDOW_MANAGER or (GetWindowManager and GetWindowManager())
    if not GuiRoot or not windowManager then
        return nil
    end

    local border = windowManager:CreateTopLevelWindow("NQOL_UI_" .. name .. "PreviewBorder")
    border:SetHidden(true)
    border:SetMouseEnabled(false)
    border:SetClampedToScreen(true)
    border:SetDrawLayer(DL_OVERLAY)
    border:SetDrawTier(DT_HIGH)
    border:SetDrawLevel(5)

    local backdrop = windowManager:CreateControl(nil, border, CT_BACKDROP)
    backdrop:SetAnchorFill()
    backdrop:SetCenterColor(PREVIEW_BORDER_COLOR[1], PREVIEW_BORDER_COLOR[2], PREVIEW_BORDER_COLOR[3], 0.18)
    backdrop:SetEdgeColor(PREVIEW_BORDER_COLOR[1], PREVIEW_BORDER_COLOR[2], PREVIEW_BORDER_COLOR[3], 0.9)
    backdrop:SetEdgeTexture("", 2, 1, 1, 1)
    backdrop:SetDrawLayer(DL_OVERLAY)
    backdrop:SetDrawTier(DT_LOW)
    backdrop:SetDrawLevel(2)
    backdrop:SetMouseEnabled(false)
    border.backdrop = backdrop

    local label = windowManager:CreateControl(nil, border, CT_LABEL)
    label:SetAnchorFill()
    label:SetFont("ZoFontGamepadBold27")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 0.86, 0.28, 1)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawTier(DT_HIGH)
    label:SetDrawLevel(6)
    label:SetMouseEnabled(false)
    label:SetText(PREVIEW_BORDER_LABELS[name] or "")
    border.label = label

    previewBorders[name] = border
    return border
end

local function HidePreviewBorder(name)
    if previewBorders[name] then
        previewBorders[name]:SetHidden(true)
    end
end

local function UpdatePreviewBorderBounds(name, show, left, top, right, bottom)
    if not show or not left or not top or not right or not bottom or right <= left or bottom <= top then
        HidePreviewBorder(name)
        return
    end

    local border = GetPreviewBorder(name)
    if not border then
        return
    end

    border:ClearAnchors()
    border:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left - PREVIEW_BORDER_PADDING, top - PREVIEW_BORDER_PADDING)
    border:SetDimensions((right - left) + PREVIEW_BORDER_PADDING * 2, (bottom - top) + PREVIEW_BORDER_PADDING * 2)
    border:SetHidden(false)
end

local function AddBounds(bounds, left, top, right, bottom)
    if not left or not top or not right or not bottom or right <= left or bottom <= top then
        return bounds
    end

    if not bounds then
        return { left = left, top = top, right = right, bottom = bottom }
    end

    bounds.left = math.min(bounds.left, left)
    bounds.top = math.min(bounds.top, top)
    bounds.right = math.max(bounds.right, right)
    bounds.bottom = math.max(bounds.bottom, bottom)
    return bounds
end

local function AddControlBounds(bounds, control)
    if not control or (control.IsHidden and control:IsHidden()) then
        return bounds
    end

    if not control.GetLeft or not control.GetTop or not control.GetWidth or not control.GetHeight then
        return bounds
    end

    local left = control:GetLeft()
    local top = control:GetTop()
    local width = control:GetWidth()
    local height = control:GetHeight()

    return AddBounds(bounds, left, top, left and width and left + width or nil, top and height and top + height or nil)
end

local function AddLabelTextBounds(bounds, label)
    if not label or (label.IsHidden and label:IsHidden()) then
        return bounds
    end

    if not label.GetLeft or not label.GetTop or not label.GetWidth or not label.GetHeight then
        return AddControlBounds(bounds, label)
    end

    local text = label.GetText and label:GetText() or ""
    if text == "" then
        return bounds
    end

    local labelLeft = label:GetLeft()
    local labelTop = label:GetTop()
    local labelWidth = label:GetWidth()
    local labelHeight = label:GetHeight()
    local textWidth = label.GetTextWidth and label:GetTextWidth() or labelWidth
    local textHeight = label.GetTextHeight and label:GetTextHeight() or labelHeight

    if not labelLeft or not labelTop or not labelWidth or not labelHeight or not textWidth or not textHeight then
        return AddControlBounds(bounds, label)
    end

    textWidth = math.min(textWidth, labelWidth)
    textHeight = math.min(textHeight, labelHeight)

    local left = labelLeft + (labelWidth - textWidth) * 0.5
    local top = labelTop + (labelHeight - textHeight) * 0.5

    return AddBounds(bounds, left, top, left + textWidth, top + textHeight)
end

local function AddCenterScreenAnnounceLineBounds(bounds, line)
    if not line then
        return bounds
    end

    if line.largeText then
        bounds = AddLabelTextBounds(bounds, line.largeText)
        bounds = AddLabelTextBounds(bounds, line.smallCombinedText)
        bounds = AddControlBounds(bounds, line.largeInformationIcon)
        bounds = AddControlBounds(bounds, line.raidCompleteContainer)
        return bounds
    end

    return AddControlBounds(bounds, line.GetControl and line:GetControl() or nil)
end

local function GetCenterScreenAnnounceActiveBounds()
    if not CENTER_SCREEN_ANNOUNCE or not CENTER_SCREEN_ANNOUNCE.activeLines then
        return nil
    end

    local bounds
    for _, lines in pairs(CENTER_SCREEN_ANNOUNCE.activeLines) do
        for _, line in ipairs(lines) do
            bounds = AddCenterScreenAnnounceLineBounds(bounds, line)
        end
    end

    return bounds
end

function UpdatePositionPreviewBorder(name, settings, show, width, height)
    if not show or not GuiRoot then
        HidePreviewBorder(name)
        return
    end

    local border = GetPreviewBorder(name)
    if not border then
        return
    end

    width = width or PREVIEW_BORDER_MIN_WIDTH
    height = height or PREVIEW_BORDER_MIN_HEIGHT

    local x = math.max(GetScreenWidth() - width, 0) * settings.horizontalPosition * 0.01
    local y = math.max(GetScreenHeight() - height, 0) * settings.verticalPosition * 0.01

    border:ClearAnchors()
    border:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x - PREVIEW_BORDER_PADDING, y - PREVIEW_BORDER_PADDING)
    border:SetDimensions(width + PREVIEW_BORDER_PADDING * 2, height + PREVIEW_BORDER_PADDING * 2)
    border:SetHidden(false)
end

local function ClearMovableUiFrameBorder(key)
    local frame = MOVABLE_UI_FRAMES[key]
    if frame then
        HidePreviewBorder(frame.previewName)
    end
end

local function ClearNamedChildText(control, childName, text)
    if not control or not control.GetNamedChild then
        return
    end

    local label = control:GetNamedChild(childName)
    if label and label.GetText and label.SetText and label:GetText() == text then
        label:SetText("")
    end
end

local function ApplyActiveCombatTipsPosition()
    local control = ZO_ActiveCombatTipsTip
    local settings = GetActiveCombatTipsSettings()
    ApplyMovedControlPosition(control, settings, false, false)

    UpdatePositionPreviewBorder(
        "ActiveCombatTips",
        settings,
        IsActiveCombatTipsPreviewActive(),
        ACTIVE_COMBAT_TIPS_PREVIEW_WIDTH,
        ACTIVE_COMBAT_TIPS_PREVIEW_HEIGHT
    )
end

local function ApplySynergyPromptsPosition()
    local control = ZO_SynergyTopLevelContainer
    local settings = GetSynergyPromptsSettings()
    ApplyMovedControlPosition(control, settings, false, false)
    ClearNamedChildText(control, "Action", NQOL.L("features.ui.synergy_prompt"))

    UpdatePositionPreviewBorder(
        "SynergyPrompts",
        settings,
        IsSynergyPromptsPreviewActive(),
        SYNERGY_PROMPTS_PREVIEW_WIDTH,
        SYNERGY_PROMPTS_PREVIEW_HEIGHT
    )
end

local function ApplyCenterScreenAnnouncePosition()
    local control = ZO_CenterScreenAnnounce
    local settings = GetCenterScreenAnnounceSettings()
    ApplyMovedControlPosition(control, settings, false, false)

    local bounds = GetCenterScreenAnnounceActiveBounds()
    if bounds then
        UpdatePreviewBorderBounds("CenterScreenAnnounce", IsCenterScreenAnnouncePreviewActive(), bounds.left, bounds.top, bounds.right, bounds.bottom)
    else
        UpdatePositionPreviewBorder("CenterScreenAnnounce", settings, IsCenterScreenAnnouncePreviewActive(), 1160, 160)
    end
end

local function ClearActiveCombatTipsBorder()
    HidePreviewBorder("ActiveCombatTips")

    if ZO_ActiveCombatTipsTip and (not ACTIVE_COMBAT_TIP_SYSTEM or not ACTIVE_COMBAT_TIP_SYSTEM.activeCombatTipId) then
        ZO_ActiveCombatTipsTip:SetAlpha(0)
        if SHARED_INFORMATION_AREA and SHARED_INFORMATION_AREA.SetHidden then
            SHARED_INFORMATION_AREA:SetHidden(ZO_ActiveCombatTipsTip, true)
        end
    end
end

local function ClearSynergyPromptsBorder()
    HidePreviewBorder("SynergyPrompts")

    ClearNamedChildText(ZO_SynergyTopLevelContainer, "Action", NQOL.L("features.ui.synergy_prompt"))

    if SYNERGY and SYNERGY.OnSynergyAbilityChanged then
        SYNERGY:OnSynergyAbilityChanged()
    elseif ZO_SynergyTopLevel then
        ZO_SynergyTopLevel:SetHidden(true)
    end
end

local function QueueActiveQuestApply()
    if activeQuestApplyQueued then
        return
    end

    activeQuestApplyQueued = true
    zo_callLater(function()
        activeQuestApplyQueued = false
        ApplyActiveQuestPosition()
    end, APPLY_DELAY_MS)
end

local function QueueActiveCombatTipsApply()
    if activeCombatTipsApplyQueued then
        return
    end

    activeCombatTipsApplyQueued = true
    zo_callLater(function()
        activeCombatTipsApplyQueued = false
        ApplyActiveCombatTipsPosition()
    end, APPLY_DELAY_MS)
end

local function QueueSynergyPromptsApply()
    if synergyPromptsApplyQueued then
        return
    end

    synergyPromptsApplyQueued = true
    zo_callLater(function()
        synergyPromptsApplyQueued = false
        ApplySynergyPromptsPosition()
    end, APPLY_DELAY_MS)
end

local function QueueCenterScreenAnnounceApply()
    if centerScreenAnnounceApplyQueued then
        return
    end

    centerScreenAnnounceApplyQueued = true
    zo_callLater(function()
        centerScreenAnnounceApplyQueued = false
        ApplyCenterScreenAnnouncePosition()
    end, APPLY_DELAY_MS)
end

local function QueueMovableUiFrameApply(key)
    if movableUiFrameApplyQueued[key] then
        return
    end

    movableUiFrameApplyQueued[key] = true
    zo_callLater(function()
        movableUiFrameApplyQueued[key] = false
        ApplyMovableUiFramePosition(key)
    end, APPLY_DELAY_MS)
end

local function SetOfficialPlayerFrameControlVisible(control, visible)
    if not control then
        return
    end

    local playerAttributeBarObject = control.playerAttributeBarObject
    if playerAttributeBarObject and playerAttributeBarObject.SetExternalVisibilityRequirement then
        if officialPlayerFrameBarRequirements[control] == nil then
            officialPlayerFrameBarRequirements[control] = playerAttributeBarObject.externalVisibilityRequirement or false
        end

        if visible then
            local originalRequirement = officialPlayerFrameBarRequirements[control]
            if originalRequirement == false then
                originalRequirement = nil
            end

            playerAttributeBarObject:SetExternalVisibilityRequirement(originalRequirement)
        else
            playerAttributeBarObject:SetExternalVisibilityRequirement(function()
                return false
            end)
        end

        if playerAttributeBarObject.UpdateStatusBar then
            playerAttributeBarObject:UpdateStatusBar()
        end

        if playerAttributeBarObject.UpdateContextualFading then
            playerAttributeBarObject:UpdateContextualFading()
        end
    end

    control:SetHidden(not visible)
end

local function ApplyOfficialPlayerFrameVisibility()
    local visible = NQOL.Features.PlayerBars.GetShowNqolPlayerFrame() ~= true

    SetOfficialPlayerFrameControlVisible(ZO_PlayerAttributeHealth, visible)
    SetOfficialPlayerFrameControlVisible(ZO_PlayerAttributeSiegeHealth, visible)
    SetOfficialPlayerFrameControlVisible(ZO_PlayerAttributeMagicka, visible)
    SetOfficialPlayerFrameControlVisible(ZO_PlayerAttributeWerewolf, visible)
    SetOfficialPlayerFrameControlVisible(ZO_PlayerAttributeStamina, visible)
    SetOfficialPlayerFrameControlVisible(ZO_PlayerAttributeMountStamina, visible)
end

function runtimeState.IsPlayerFrameActive()
    return NQOL.Features.PlayerBars.GetShowNqolPlayerFrame() == true
end

local function ApplyOfficialCompanionFrameVisibility()
    if not UNIT_FRAMES or not UNIT_FRAMES.SetFrameHiddenForReason then
        return
    end

    local visible = NQOL.Features.PlayerBars.GetShowNqolCompanionFrame() ~= true
    UNIT_FRAMES:SetFrameHiddenForReason("companion", "NQOL", not visible)
end

function runtimeState.IsCompanionFrameActive()
    return NQOL.Features.PlayerBars.GetShowNqolCompanionFrame() == true
end

local function ApplyOfficialGroupFrameVisibility()
    if not UNIT_FRAMES or not UNIT_FRAMES.SetFrameHiddenForReason then
        return
    end

    local visible = NQOL.Features.PlayerBars.GetShowNqolGroupFrame() ~= true
    for index = 1, (MAX_GROUP_SIZE_THRESHOLD or 24) do
        local unitTag = (GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(index)) or ("group" .. tostring(index))
        UNIT_FRAMES:SetFrameHiddenForReason(unitTag, "NQOL", not visible)

        local companionUnitTag = GetCompanionUnitTagByGroupUnitTag and GetCompanionUnitTagByGroupUnitTag(unitTag) or nil
        if companionUnitTag then
            UNIT_FRAMES:SetFrameHiddenForReason(companionUnitTag, "NQOL", not visible)
        end
    end
end

function runtimeState.IsGroupFrameActive()
    return NQOL.Features.PlayerBars.GetShowNqolGroupFrame() == true
end

local function IsGroupOrGroupCompanionUnitTag(unitTag)
    if not unitTag then
        return false
    end

    if ZO_Group_IsGroupUnitTag and ZO_Group_IsGroupUnitTag(unitTag) then
        return true
    end

    return IsGroupCompanionUnitTag and IsGroupCompanionUnitTag(unitTag) == true
end

local function ApplyOfficialCreatedUnitFrameVisibility(unitTag)
    if not unitTag or not UNIT_FRAMES or not UNIT_FRAMES.SetFrameHiddenForReason then
        return
    end

    if unitTag == "companion" and runtimeState.IsCompanionFrameActive() then
        UNIT_FRAMES:SetFrameHiddenForReason(unitTag, "NQOL", NQOL.Features.PlayerBars.GetShowNqolCompanionFrame() == true)
    elseif IsGroupOrGroupCompanionUnitTag(unitTag) and runtimeState.IsGroupFrameActive() then
        UNIT_FRAMES:SetFrameHiddenForReason(unitTag, "NQOL", NQOL.Features.PlayerBars.GetShowNqolGroupFrame() == true)
    end
end

local function ApplyOfficialGroupMembershipFrameVisibility()
    ApplyOfficialGroupFrameVisibility()
end

local function QueueOfficialPlayerFrameApply()
    if zo_callLater then
        zo_callLater(ApplyOfficialPlayerFrameVisibility, APPLY_DELAY_MS)
    else
        ApplyOfficialPlayerFrameVisibility()
    end
end

local function QueueOfficialCompanionFrameApply()
    if zo_callLater then
        zo_callLater(ApplyOfficialCompanionFrameVisibility, APPLY_DELAY_MS)
    else
        ApplyOfficialCompanionFrameVisibility()
    end
end

local function QueueOfficialGroupFrameApply()
    if runtimeState.groupFrameApplyQueued then
        return
    end

    ApplyOfficialGroupFrameVisibility()

    if zo_callLater then
        runtimeState.groupFrameApplyQueued = true
        runtimeState.groupFrameApplyStep = 1
        zo_callLater(runtimeState.RunQueuedGroupFrameApply, APPLY_DELAY_MS)
    end
end

local function QueueOfficialGroupMembershipFrameApply()
    QueueOfficialGroupFrameApply()
end

function runtimeState.RunQueuedGroupFrameApply()
    ApplyOfficialGroupMembershipFrameVisibility()

    if not runtimeState.IsGroupFrameActive() then
        runtimeState.groupFrameApplyQueued = false
        runtimeState.groupFrameApplyStep = nil
        return
    end

    runtimeState.groupFrameApplyStep = runtimeState.groupFrameApplyStep + 1
    local delay = runtimeState.groupFrameRetryDelays[runtimeState.groupFrameApplyStep - 1]
    if delay and zo_callLater then
        zo_callLater(runtimeState.RunQueuedGroupFrameApply, delay)
    else
        runtimeState.groupFrameApplyQueued = false
        runtimeState.groupFrameApplyStep = nil
    end
end

local function InstallActiveCombatTipsHooks()
    if not EVENT_MANAGER or not runtimeState.activeCombatTipsActive then
        return
    end

    if not activeCombatTipsEventsInstalled then
        EVENT_MANAGER:RegisterForEvent(ACTIVE_COMBAT_TIPS_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
            InstallActiveCombatTipsHooks()
            QueueActiveCombatTipsApply()
        end)

        if EVENT_DISPLAY_ACTIVE_COMBAT_TIP then
            EVENT_MANAGER:RegisterForEvent(ACTIVE_COMBAT_TIPS_NAMESPACE, EVENT_DISPLAY_ACTIVE_COMBAT_TIP, function()
                QueueActiveCombatTipsApply()
            end)
        end

        activeCombatTipsEventsInstalled = true
    end

    if activeCombatTipsHookInstalled or not ACTIVE_COMBAT_TIP_SYSTEM or type(ZO_PostHook) ~= "function" then
        return
    end

    ZO_PostHook(ACTIVE_COMBAT_TIP_SYSTEM, "ApplyStyle", function()
        if runtimeState.activeCombatTipsActive then
            QueueActiveCombatTipsApply()
        end
    end)

    activeCombatTipsHookInstalled = true
end

local function InstallSynergyPromptHooks()
    if not EVENT_MANAGER or not runtimeState.synergyPromptsActive then
        return
    end

    if not synergyPromptsEventsInstalled then
        EVENT_MANAGER:RegisterForEvent(SYNERGY_PROMPTS_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
            InstallSynergyPromptHooks()
            QueueSynergyPromptsApply()
        end)

        if EVENT_SYNERGY_ABILITY_CHANGED then
            EVENT_MANAGER:RegisterForEvent(SYNERGY_PROMPTS_NAMESPACE, EVENT_SYNERGY_ABILITY_CHANGED, function()
                QueueSynergyPromptsApply()
            end)
        end

        synergyPromptsEventsInstalled = true
    end

    if synergyPromptsHookInstalled or not SYNERGY or type(ZO_PostHook) ~= "function" then
        return
    end

    ZO_PostHook(SYNERGY, "ApplyTextStyle", function()
        if runtimeState.synergyPromptsActive then
            QueueSynergyPromptsApply()
        end
    end)

    synergyPromptsHookInstalled = true
end

local function InstallCenterScreenAnnounceHooks()
    if not EVENT_MANAGER or not runtimeState.centerScreenAnnounceActive then
        return
    end

    if not centerScreenAnnounceEventsInstalled then
        EVENT_MANAGER:RegisterForEvent(CENTER_SCREEN_ANNOUNCE_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
            InstallCenterScreenAnnounceHooks()
            QueueCenterScreenAnnounceApply()
        end)

        if EVENT_DISPLAY_ANNOUNCEMENT then
            EVENT_MANAGER:RegisterForEvent(CENTER_SCREEN_ANNOUNCE_NAMESPACE, EVENT_DISPLAY_ANNOUNCEMENT, function()
                QueueCenterScreenAnnounceApply()
            end)
        end

        centerScreenAnnounceEventsInstalled = true
    end

    if centerScreenAnnounceHookInstalled or not CENTER_SCREEN_ANNOUNCE or type(ZO_PostHook) ~= "function" then
        return
    end

    ZO_PostHook(CENTER_SCREEN_ANNOUNCE, "ApplyPlatformStyle", function()
        if runtimeState.centerScreenAnnounceActive then
            QueueCenterScreenAnnounceApply()
        end
    end)
    ZO_PostHook(CENTER_SCREEN_ANNOUNCE, "DisplayMessage", function()
        if runtimeState.centerScreenAnnounceActive then
            QueueCenterScreenAnnounceApply()
        end
    end)

    centerScreenAnnounceHookInstalled = true
end

local function InstallMovableUiFrameHooks()
    if not EVENT_MANAGER or not runtimeState.anyMovableUiFrameActive then
        return
    end

    if not movableUiFrameEventsInstalled then
        EVENT_MANAGER:RegisterForEvent(MOVABLE_UI_FRAMES_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
            InstallMovableUiFrameHooks()
            for key in pairs(MOVABLE_UI_FRAMES) do
                if runtimeState.movableUiFrameActive[key] then
                    QueueMovableUiFrameApply(key)
                end
            end
        end)

        movableUiFrameEventsInstalled = true
    end

    if infiniteArchiveFrameHookInstalled
        or not ENDLESS_DUNGEON_HUD_TRACKER
        or type(ZO_PostHook) ~= "function"
    then
        return
    end

    ZO_PostHook(ENDLESS_DUNGEON_HUD_TRACKER, "RefreshAnchors", function()
        if runtimeState.movableUiFrameActive.infiniteArchive then
            QueueMovableUiFrameApply("infiniteArchive")
        end
    end)

    infiniteArchiveFrameHookInstalled = true
end

function runtimeState.RefreshActiveCombatTips()
    runtimeState.activeCombatTipsActive = runtimeState.IsActiveCombatTipsActive()
    if runtimeState.activeCombatTipsActive then
        InstallActiveCombatTipsHooks()
        QueueActiveCombatTipsApply()
    elseif activeCombatTipsEventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(ACTIVE_COMBAT_TIPS_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        if EVENT_DISPLAY_ACTIVE_COMBAT_TIP then
            EVENT_MANAGER:UnregisterForEvent(ACTIVE_COMBAT_TIPS_NAMESPACE, EVENT_DISPLAY_ACTIVE_COMBAT_TIP)
        end
        activeCombatTipsEventsInstalled = false
    end
end

function runtimeState.RefreshSynergyPrompts()
    runtimeState.synergyPromptsActive = runtimeState.IsSynergyPromptsActive()
    if runtimeState.synergyPromptsActive then
        InstallSynergyPromptHooks()
        QueueSynergyPromptsApply()
    elseif synergyPromptsEventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(SYNERGY_PROMPTS_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        if EVENT_SYNERGY_ABILITY_CHANGED then
            EVENT_MANAGER:UnregisterForEvent(SYNERGY_PROMPTS_NAMESPACE, EVENT_SYNERGY_ABILITY_CHANGED)
        end
        synergyPromptsEventsInstalled = false
    end
end

function runtimeState.RefreshCenterScreenAnnounce()
    runtimeState.centerScreenAnnounceActive = runtimeState.IsCenterScreenAnnounceActive()
    if runtimeState.centerScreenAnnounceActive then
        InstallCenterScreenAnnounceHooks()
        QueueCenterScreenAnnounceApply()
    elseif centerScreenAnnounceEventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(CENTER_SCREEN_ANNOUNCE_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        if EVENT_DISPLAY_ANNOUNCEMENT then
            EVENT_MANAGER:UnregisterForEvent(CENTER_SCREEN_ANNOUNCE_NAMESPACE, EVENT_DISPLAY_ANNOUNCEMENT)
        end
        centerScreenAnnounceEventsInstalled = false
    end
end

function runtimeState.RefreshMovableUiFrames()
    runtimeState.anyMovableUiFrameActive = false
    for key in pairs(MOVABLE_UI_FRAMES) do
        local active = runtimeState.IsMovableUiFrameActive(key)
        runtimeState.movableUiFrameActive[key] = active
        runtimeState.anyMovableUiFrameActive = runtimeState.anyMovableUiFrameActive or active
    end

    if runtimeState.anyMovableUiFrameActive then
        InstallMovableUiFrameHooks()
        for key in pairs(MOVABLE_UI_FRAMES) do
            if runtimeState.movableUiFrameActive[key] then
                QueueMovableUiFrameApply(key)
            end
        end
    elseif movableUiFrameEventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(MOVABLE_UI_FRAMES_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        movableUiFrameEventsInstalled = false
    end
end

local function RefreshActiveCombatTipsSettingsPreview()
    if not IsActiveCombatTipsPreviewActive() then
        ClearActiveCombatTipsBorder()
        return
    end

    ApplyActiveCombatTipsPosition()
end

local function RefreshSynergyPromptsSettingsPreview()
    if not IsSynergyPromptsPreviewActive() then
        ClearSynergyPromptsBorder()
        return
    end

    ApplySynergyPromptsPosition()
end

local function RefreshCenterScreenAnnounceSettingsPreview()
    if not IsCenterScreenAnnouncePreviewActive() then
        HidePreviewBorder("CenterScreenAnnounce")
        return
    end

    ApplyCenterScreenAnnouncePosition()
end

local function RefreshMovableUiFrameSettingsPreview(key)
    if not IsMovableUiFramePreviewActive(key) then
        ClearMovableUiFrameBorder(key)
        return
    end

    ApplyMovableUiFramePosition(key)
end

local function ClearAlertManager(alertManager)
    if not alertManager then
        return
    end

    if alertManager.ClearAll then
        alertManager:ClearAll()
    elseif alertManager.alerts and alertManager.alerts.ClearAll then
        alertManager.alerts:ClearAll()
    end
end

local function ClearAlertTexts()
    ClearAlertManager(ALERT_MESSAGES_GAMEPAD)
    ClearAlertManager(ALERT_MESSAGES)

    if ZO_AlertClearAll_Gamepad then
        ZO_AlertClearAll_Gamepad()
    end
end

local function ShouldSuppressAlertText()
    return runtimeState.alertTextsActive
end

local function PreHookGlobalFunction(functionName, callback)
    if _G and type(_G[functionName]) == "function" and type(ZO_PreHook) == "function" then
        ZO_PreHook(functionName, callback)
    end
end

local function IsDungeonFinderEntry(entryData)
    local location = entryData and entryData.data
    if not location or location.isRoleSelector == true then
        return false
    end

    return type(location.GetEntryType) == "function"
end

local function ShouldSortDungeonFinderEntry(entryData)
    if not IsDungeonFinderEntry(entryData) then
        return false
    end

    local location = entryData.data
    if type(location.HasRewardData) == "function" and location:HasRewardData() then
        return false
    end

    return true
end

local function GetDungeonFinderEntryName(entryData)
    local location = entryData and entryData.data
    if not location then
        return ""
    end

    if type(location.GetNameGamepad) == "function" then
        local name = location:GetNameGamepad()
        if name and name ~= "" then
            return name
        end
    end

    if location.rawName and location.rawName ~= "" then
        return location.rawName
    end

    if type(location.GetName) == "function" then
        local name = location:GetName()
        if name and name ~= "" then
            return name
        end
    end

    return ""
end

local function GetDungeonFinderEntryTieBreaker(entryData)
    local location = entryData and entryData.data
    if not location then
        return ""
    end

    if type(location.GetId) == "function" then
        local id = location:GetId()
        if id then
            return tostring(id)
        end
    end

    if location.activityId then
        return tostring(location.activityId)
    end

    return GetDungeonFinderEntryName(entryData)
end

local function CompareDungeonFinderEntries(left, right)
    local leftShouldSort = ShouldSortDungeonFinderEntry(left)
    local rightShouldSort = ShouldSortDungeonFinderEntry(right)

    if leftShouldSort ~= rightShouldSort then
        return leftShouldSort == false
    end

    if not leftShouldSort then
        return false
    end

    local leftName = zo_strlower(GetDungeonFinderEntryName(left))
    local rightName = zo_strlower(GetDungeonFinderEntryName(right))

    if leftName ~= rightName then
        return leftName < rightName
    end

    return GetDungeonFinderEntryTieBreaker(left) < GetDungeonFinderEntryTieBreaker(right)
end

local function ApplyDungeonFinderSortForRefresh(activityFinder)
    if activityFinder ~= DUNGEON_FINDER_GAMEPAD or not activityFinder.entryList or not activityFinder.entryList.SetSortFunction then
        return
    end

    if runtimeState.dungeonFinderSortActive and activityFinder.navigationMode == DUNGEON_FINDER_SPECIFIC_NAVIGATION_MODE then
        activityFinder.entryList:SetSortFunction(CompareDungeonFinderEntries)
    else
        activityFinder.entryList:SetSortFunction(nil)
    end
end

local function InstallDungeonFinderSortHook()
    if dungeonFinderSortHookInstalled or not runtimeState.dungeonFinderSortActive then
        return
    end

    if not ZO_ActivityFinderTemplate_Gamepad or type(ZO_PreHook) ~= "function" then
        dungeonFinderSortHookAttempts = dungeonFinderSortHookAttempts + 1
        if dungeonFinderSortHookAttempts < DUNGEON_FINDER_SORT_MAX_ATTEMPTS and zo_callLater then
            zo_callLater(InstallDungeonFinderSortHook, DUNGEON_FINDER_SORT_RETRY_MS)
        end
        return
    end

    ZO_PreHook(ZO_ActivityFinderTemplate_Gamepad, "RefreshView", ApplyDungeonFinderSortForRefresh)

    dungeonFinderSortHookInstalled = true
end

local function InstallAlertTextHooks()
    if not EVENT_MANAGER or not ShouldSuppressAlertText() then
        return
    end

    if not runtimeState.alertTextHooksInstalled then
        PreHookGlobalFunction("ZO_Alert", ShouldSuppressAlertText)
        PreHookGlobalFunction("ZO_AlertNoSuppression", ShouldSuppressAlertText)
        PreHookGlobalFunction("ZO_AlertTemplated_Gamepad", ShouldSuppressAlertText)
        PreHookGlobalFunction("ZO_AlertNoSuppressionTemplated_Gamepad", ShouldSuppressAlertText)
        runtimeState.alertTextHooksInstalled = true
    end

    if not runtimeState.alertTextEventsInstalled then
        EVENT_MANAGER:RegisterForEvent(ALERT_TEXT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
            if ShouldSuppressAlertText() then
                ClearAlertTexts()
            end
        end)
        runtimeState.alertTextEventsInstalled = true
    end
end

function runtimeState.RefreshAlertTexts()
    runtimeState.alertTextsActive = GetSettings().disableAlertTexts == true
    if ShouldSuppressAlertText() then
        InstallAlertTextHooks()
        ClearAlertTexts()
    elseif runtimeState.alertTextEventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(ALERT_TEXT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        runtimeState.alertTextEventsInstalled = false
    end
end

local function InstallPlayerFrameVisibilityHooks()
    if not EVENT_MANAGER or runtimeState.playerFrameEventsInstalled or not runtimeState.IsPlayerFrameActive() then
        return
    end

    EVENT_MANAGER:RegisterForEvent(PLAYER_FRAME_VISIBILITY_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        QueueOfficialPlayerFrameApply()
    end)
    runtimeState.playerFrameEventsInstalled = true
end

local function InstallCompanionFrameVisibilityHooks()
    if not EVENT_MANAGER or runtimeState.companionFrameEventsInstalled or not runtimeState.IsCompanionFrameActive() then
        return
    end

    EVENT_MANAGER:RegisterForEvent(COMPANION_FRAME_VISIBILITY_NAMESPACE, EVENT_PLAYER_ACTIVATED, QueueOfficialCompanionFrameApply)
    if EVENT_ACTIVE_COMPANION_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(COMPANION_FRAME_VISIBILITY_NAMESPACE, EVENT_ACTIVE_COMPANION_STATE_CHANGED, QueueOfficialCompanionFrameApply)
    end
    if EVENT_UNIT_CREATED then
        EVENT_MANAGER:RegisterForEvent(COMPANION_FRAME_VISIBILITY_NAMESPACE, EVENT_UNIT_CREATED, function(_, unitTag)
            if unitTag == "companion" then
                QueueOfficialCompanionFrameApply()
            end
        end)
    end
    if EVENT_UNIT_DESTROYED then
        EVENT_MANAGER:RegisterForEvent(COMPANION_FRAME_VISIBILITY_NAMESPACE, EVENT_UNIT_DESTROYED, function(_, unitTag)
            if unitTag == "companion" then
                QueueOfficialCompanionFrameApply()
            end
        end)
    end
    runtimeState.companionFrameEventsInstalled = true
end

local function InstallOfficialUnitFrameCreateHook()
    if officialUnitFrameCreateHookInstalled
        or not (runtimeState.IsCompanionFrameActive() or runtimeState.IsGroupFrameActive())
        or not UNIT_FRAMES
        or type(UNIT_FRAMES.CreateFrame) ~= "function"
        or type(ZO_PostHook) ~= "function"
    then
        return
    end

    ZO_PostHook(UNIT_FRAMES, "CreateFrame", function(_, unitTag)
        ApplyOfficialCreatedUnitFrameVisibility(unitTag)
    end)

    officialUnitFrameCreateHookInstalled = true
end

local function InstallGroupFrameVisibilityHooks()
    if not EVENT_MANAGER or runtimeState.groupFrameEventsInstalled or not runtimeState.IsGroupFrameActive() then
        return
    end

    EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        InstallOfficialUnitFrameCreateHook()
        QueueOfficialGroupMembershipFrameApply()
    end)
    if EVENT_GROUP_UPDATE then
        EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_UPDATE, QueueOfficialGroupMembershipFrameApply)
    end
    if EVENT_GROUP_MEMBER_JOINED then
        EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_MEMBER_JOINED, QueueOfficialGroupMembershipFrameApply)
    end
    if EVENT_GROUP_MEMBER_LEFT then
        EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_MEMBER_LEFT, QueueOfficialGroupMembershipFrameApply)
    end
    if EVENT_GROUP_MEMBER_CONNECTED_STATUS then
        EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_MEMBER_CONNECTED_STATUS, QueueOfficialGroupMembershipFrameApply)
    end
    if EVENT_GROUP_TYPE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_TYPE_CHANGED, QueueOfficialGroupMembershipFrameApply)
    end
    if EVENT_GROUP_MEMBER_ROLE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_MEMBER_ROLE_CHANGED, QueueOfficialGroupMembershipFrameApply)
    end
    if EVENT_UNIT_CREATED then
        EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_UNIT_CREATED, function(_, unitTag)
            if IsGroupOrGroupCompanionUnitTag(unitTag) then
                QueueOfficialGroupFrameApply()
            end
        end)
    end
    if EVENT_UNIT_DESTROYED then
        EVENT_MANAGER:RegisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_UNIT_DESTROYED, function(_, unitTag)
            if IsGroupOrGroupCompanionUnitTag(unitTag) then
                QueueOfficialGroupFrameApply()
            end
        end)
    end
    runtimeState.groupFrameEventsInstalled = true
end

function runtimeState.RefreshOfficialPlayerFrame()
    if runtimeState.IsPlayerFrameActive() then
        InstallPlayerFrameVisibilityHooks()
        QueueOfficialPlayerFrameApply()
    elseif runtimeState.playerFrameEventsInstalled and EVENT_MANAGER then
        ApplyOfficialPlayerFrameVisibility()
        EVENT_MANAGER:UnregisterForEvent(PLAYER_FRAME_VISIBILITY_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        runtimeState.playerFrameEventsInstalled = false
    end
end

function runtimeState.RefreshOfficialCompanionFrame()
    if runtimeState.IsCompanionFrameActive() then
        InstallOfficialUnitFrameCreateHook()
        InstallCompanionFrameVisibilityHooks()
        QueueOfficialCompanionFrameApply()
    elseif runtimeState.companionFrameEventsInstalled and EVENT_MANAGER then
        ApplyOfficialCompanionFrameVisibility()
        EVENT_MANAGER:UnregisterForEvent(COMPANION_FRAME_VISIBILITY_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        if EVENT_ACTIVE_COMPANION_STATE_CHANGED then
            EVENT_MANAGER:UnregisterForEvent(COMPANION_FRAME_VISIBILITY_NAMESPACE, EVENT_ACTIVE_COMPANION_STATE_CHANGED)
        end
        if EVENT_UNIT_CREATED then
            EVENT_MANAGER:UnregisterForEvent(COMPANION_FRAME_VISIBILITY_NAMESPACE, EVENT_UNIT_CREATED)
        end
        if EVENT_UNIT_DESTROYED then
            EVENT_MANAGER:UnregisterForEvent(COMPANION_FRAME_VISIBILITY_NAMESPACE, EVENT_UNIT_DESTROYED)
        end
        runtimeState.companionFrameEventsInstalled = false
    end
end

function runtimeState.RefreshOfficialGroupFrame()
    if runtimeState.IsGroupFrameActive() then
        InstallOfficialUnitFrameCreateHook()
        InstallGroupFrameVisibilityHooks()
        QueueOfficialGroupMembershipFrameApply()
    elseif runtimeState.groupFrameEventsInstalled and EVENT_MANAGER then
        ApplyOfficialGroupFrameVisibility()
        EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        if EVENT_GROUP_UPDATE then
            EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_UPDATE)
        end
        if EVENT_GROUP_MEMBER_JOINED then
            EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_MEMBER_JOINED)
        end
        if EVENT_GROUP_MEMBER_LEFT then
            EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_MEMBER_LEFT)
        end
        if EVENT_GROUP_MEMBER_CONNECTED_STATUS then
            EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_MEMBER_CONNECTED_STATUS)
        end
        if EVENT_GROUP_TYPE_CHANGED then
            EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_TYPE_CHANGED)
        end
        if EVENT_GROUP_MEMBER_ROLE_CHANGED then
            EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_GROUP_MEMBER_ROLE_CHANGED)
        end
        if EVENT_UNIT_CREATED then
            EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_UNIT_CREATED)
        end
        if EVENT_UNIT_DESTROYED then
            EVENT_MANAGER:UnregisterForEvent(GROUP_FRAME_VISIBILITY_NAMESPACE, EVENT_UNIT_DESTROYED)
        end
        runtimeState.groupFrameEventsInstalled = false
    end
end

function UI.InitializeSavedVariables()
    savedVariables = NQOL.Settings.NewAccountWide(defaults)
    GetSettings()
end

function UI.Initialize()
    if initialized then
        return
    end

    initialized = true
    if type(UI.InitializeCombatReticle) == "function" then
        UI.InitializeCombatReticle()
    end
    runtimeState.RefreshActiveCombatTips()
    runtimeState.RefreshSynergyPrompts()
    runtimeState.RefreshCenterScreenAnnounce()
    runtimeState.RefreshMovableUiFrames()
    runtimeState.RefreshAlertTexts()
    runtimeState.dungeonFinderSortActive = GetSettings().sortDungeonsFinder == true
    if runtimeState.dungeonFinderSortActive then
        InstallDungeonFinderSortHook()
    end
    if type(UI.InitializeLootLog) == "function" then
        UI.InitializeLootLog()
    end
    runtimeState.RefreshOfficialPlayerFrame()
    runtimeState.RefreshOfficialCompanionFrame()
    runtimeState.RefreshOfficialGroupFrame()
    InstallActiveQuestLayoutHook()
    QueueActiveQuestApply()
end

function UI.SetActiveQuestSettingsPanelVisible(visible)
    visible = visible == true
    if activeQuestSettingsPanelVisible == visible then return end
    activeQuestSettingsPanelVisible = visible
    ApplyActiveQuestPosition()
end

function UI.SetActiveCombatTipsSettingsPanelVisible(visible)
    visible = visible == true
    if activeCombatTipsSettingsPanelVisible == visible then return end
    activeCombatTipsSettingsPanelVisible = visible
    runtimeState.RefreshActiveCombatTips()
    RefreshActiveCombatTipsSettingsPreview()
end

function UI.SetSynergyPromptsSettingsPanelVisible(visible)
    visible = visible == true
    if synergyPromptsSettingsPanelVisible == visible then return end
    synergyPromptsSettingsPanelVisible = visible
    runtimeState.RefreshSynergyPrompts()
    RefreshSynergyPromptsSettingsPreview()
end

function UI.SetCenterScreenAnnounceSettingsPanelVisible(visible)
    visible = visible == true
    if centerScreenAnnounceSettingsPanelVisible == visible then return end
    centerScreenAnnounceSettingsPanelVisible = visible
    runtimeState.RefreshCenterScreenAnnounce()
    RefreshCenterScreenAnnounceSettingsPreview()
end

local function SetMovableUiFrameSettingsPanelVisible(key, visible)
    visible = visible == true
    if (movableUiFrameSettingsPanelVisible[key] == true) == visible then return end
    movableUiFrameSettingsPanelVisible[key] = visible
    runtimeState.RefreshMovableUiFrames()
    RefreshMovableUiFrameSettingsPreview(key)
end

function UI.SetPlayerInteractionSettingsPanelVisible(visible)
    SetMovableUiFrameSettingsPanelVisible("playerInteraction", visible)
end

function UI.SetInfiniteArchiveSettingsPanelVisible(visible)
    SetMovableUiFrameSettingsPanelVisible("infiniteArchive", visible)
end

function UI.SetSubtitlesSettingsPanelVisible(visible)
    SetMovableUiFrameSettingsPanelVisible("subtitles", visible)
end

function UI.SetAnnouncementsSettingsPanelVisible(visible)
    SetMovableUiFrameSettingsPanelVisible("announcements", visible)
end

local function RegisterMovableUiFrameApi(key, prefix)
    local frame = MOVABLE_UI_FRAMES[key]

    UI["Get" .. prefix .. "HorizontalOffset"] = function()
        return GetMovableUiFrameSettings(key).horizontalPosition
    end

    UI["Set" .. prefix .. "HorizontalOffset"] = function(value)
        GetMovableUiFrameSettings(key).horizontalPosition = Clamp(value, 0, 100)
        if runtimeState.movableUiFrameActive[key] then
            QueueMovableUiFrameApply(key)
        end
        RefreshMovableUiFrameSettingsPreview(key)
    end

    UI["Get" .. prefix .. "VerticalOffset"] = function()
        return GetMovableUiFrameSettings(key).verticalPosition
    end

    UI["Get" .. prefix .. "VerticalOffsetDefault"] = function()
        return defaults.ui[key].verticalPosition
    end

    UI["Set" .. prefix .. "VerticalOffset"] = function(value)
        GetMovableUiFrameSettings(key).verticalPosition = Clamp(value, 0, 100)
        if runtimeState.movableUiFrameActive[key] then
            QueueMovableUiFrameApply(key)
        end
        RefreshMovableUiFrameSettingsPreview(key)
    end

    UI["Get" .. prefix .. "Enabled"] = function()
        return GetMovableUiFrameSettings(key).enabled
    end

    UI["Get" .. prefix .. "EnabledDefault"] = function()
        return defaults.ui[key].enabled
    end

    UI["Set" .. prefix .. "Enabled"] = function(value)
        GetMovableUiFrameSettings(key).enabled = value == true
        if not runtimeState.IsMovableUiFrameActive(key) then
            ApplyMovableUiFramePosition(key)
        end
        runtimeState.RefreshMovableUiFrames()
        RefreshMovableUiFrameSettingsPreview(key)
    end

    UI["Get" .. prefix .. "HorizontalOffsetMin"] = function()
        return 0
    end

    UI["Get" .. prefix .. "HorizontalOffsetMax"] = function()
        return 100
    end

    UI["Get" .. prefix .. "VerticalOffsetMin"] = function()
        return 0
    end

    UI["Get" .. prefix .. "VerticalOffsetMax"] = function()
        return 100
    end

    UI["Get" .. prefix .. "HorizontalOffsetLabel"] = function()
        return NQOL.L("features.ui.frame_horizontal_position_label")
    end

    UI["Get" .. prefix .. "HorizontalOffsetTooltip"] = function()
        return NQOL.L("features.ui.frame_horizontal", NQOL.Util.Lower(frame.label))
    end

    UI["Get" .. prefix .. "VerticalOffsetLabel"] = function()
        return NQOL.L("features.ui.frame_vertical_position_label")
    end

    UI["Get" .. prefix .. "VerticalOffsetTooltip"] = function()
        return NQOL.L("features.ui.frame_vertical", NQOL.Util.Lower(frame.label))
    end

    UI["Get" .. prefix .. "EnabledLabel"] = function()
        return NQOL.L("features.ui.active_quest_enabled_label")
    end

    UI["Get" .. prefix .. "EnabledTooltip"] = function()
        return NQOL.L("features.ui.frame_enabled", NQOL.Util.Lower(frame.label))
    end
end

RegisterMovableUiFrameApi("playerInteraction", "PlayerInteraction")
RegisterMovableUiFrameApi("infiniteArchive", "InfiniteArchive")
RegisterMovableUiFrameApi("subtitles", "Subtitles")
RegisterMovableUiFrameApi("announcements", "Announcements")

function UI.GetActiveQuestHorizontalOffset()
    return GetActiveQuestSettings().horizontalPosition
end

function UI.GetActiveQuestEnabled()
    return GetActiveQuestSettings().enabled
end

function UI.GetActiveQuestEnabledDefault()
    return defaults.ui.activeQuest.enabled
end

function UI.SetActiveQuestEnabled(value)
    GetActiveQuestSettings().enabled = value == true
    QueueActiveQuestApply()
end

function UI.SetActiveQuestHorizontalOffset(value)
    GetActiveQuestSettings().horizontalPosition = Clamp(value, 0, 100)
    QueueActiveQuestApply()
end

function UI.GetActiveQuestVerticalOffset()
    return GetActiveQuestSettings().verticalPosition
end

function UI.GetActiveQuestVerticalOffsetDefault()
    return defaults.ui.activeQuest.verticalPosition
end

function UI.SetActiveQuestVerticalOffset(value)
    GetActiveQuestSettings().verticalPosition = Clamp(value, 0, 100)
    QueueActiveQuestApply()
end

function UI.GetActiveCombatTipsHorizontalOffset()
    return GetActiveCombatTipsSettings().horizontalPosition
end

function UI.GetActiveCombatTipsEnabled()
    return GetActiveCombatTipsSettings().enabled
end

function UI.GetActiveCombatTipsEnabledDefault()
    return defaults.ui.activeCombatTips.enabled
end

function UI.SetActiveCombatTipsEnabled(value)
    GetActiveCombatTipsSettings().enabled = value == true
    runtimeState.RefreshActiveCombatTips()
    RefreshActiveCombatTipsSettingsPreview()
end

function UI.SetActiveCombatTipsHorizontalOffset(value)
    GetActiveCombatTipsSettings().horizontalPosition = Clamp(value, 0, 100)
    if runtimeState.activeCombatTipsActive then
        QueueActiveCombatTipsApply()
    end
    RefreshActiveCombatTipsSettingsPreview()
end

function UI.GetActiveCombatTipsVerticalOffset()
    return GetActiveCombatTipsSettings().verticalPosition
end

function UI.GetActiveCombatTipsVerticalOffsetDefault()
    return defaults.ui.activeCombatTips.verticalPosition
end

function UI.SetActiveCombatTipsVerticalOffset(value)
    GetActiveCombatTipsSettings().verticalPosition = Clamp(value, 0, 100)
    if runtimeState.activeCombatTipsActive then
        QueueActiveCombatTipsApply()
    end
    RefreshActiveCombatTipsSettingsPreview()
end

function UI.GetSynergyPromptsHorizontalOffset()
    return GetSynergyPromptsSettings().horizontalPosition
end

function UI.GetSynergyPromptsEnabled()
    return GetSynergyPromptsSettings().enabled
end

function UI.GetSynergyPromptsEnabledDefault()
    return defaults.ui.synergyPrompts.enabled
end

function UI.SetSynergyPromptsEnabled(value)
    GetSynergyPromptsSettings().enabled = value == true
    runtimeState.RefreshSynergyPrompts()
    RefreshSynergyPromptsSettingsPreview()
end

function UI.SetSynergyPromptsHorizontalOffset(value)
    GetSynergyPromptsSettings().horizontalPosition = Clamp(value, 0, 100)
    if runtimeState.synergyPromptsActive then
        QueueSynergyPromptsApply()
    end
    RefreshSynergyPromptsSettingsPreview()
end

function UI.GetSynergyPromptsVerticalOffset()
    return GetSynergyPromptsSettings().verticalPosition
end

function UI.GetSynergyPromptsVerticalOffsetDefault()
    return defaults.ui.synergyPrompts.verticalPosition
end

function UI.SetSynergyPromptsVerticalOffset(value)
    GetSynergyPromptsSettings().verticalPosition = Clamp(value, 0, 100)
    if runtimeState.synergyPromptsActive then
        QueueSynergyPromptsApply()
    end
    RefreshSynergyPromptsSettingsPreview()
end

function UI.GetCenterScreenAnnounceHorizontalOffset()
    return GetCenterScreenAnnounceSettings().horizontalPosition
end

function UI.GetCenterScreenAnnounceEnabled()
    return GetCenterScreenAnnounceSettings().enabled
end

function UI.GetCenterScreenAnnounceEnabledDefault()
    return defaults.ui.centerScreenAnnounce.enabled
end

function UI.SetCenterScreenAnnounceEnabled(value)
    GetCenterScreenAnnounceSettings().enabled = value == true
    runtimeState.RefreshCenterScreenAnnounce()
    RefreshCenterScreenAnnounceSettingsPreview()
end

function UI.SetCenterScreenAnnounceHorizontalOffset(value)
    GetCenterScreenAnnounceSettings().horizontalPosition = Clamp(value, 0, 100)
    if runtimeState.centerScreenAnnounceActive then
        QueueCenterScreenAnnounceApply()
    end
end

function UI.GetCenterScreenAnnounceVerticalOffset()
    return GetCenterScreenAnnounceSettings().verticalPosition
end

function UI.GetCenterScreenAnnounceVerticalOffsetDefault()
    return defaults.ui.centerScreenAnnounce.verticalPosition
end

function UI.SetCenterScreenAnnounceVerticalOffset(value)
    GetCenterScreenAnnounceSettings().verticalPosition = Clamp(value, 0, 100)
    if runtimeState.centerScreenAnnounceActive then
        QueueCenterScreenAnnounceApply()
    end
end

function UI.GetLootLogShowTotals()
    return GetLootLogSettings().showTotals
end

function UI.GetLootLogShowTotalsDefault()
    return defaults.ui.lootLog.showTotals
end

function UI.SetLootLogShowTotals(value)
    GetLootLogSettings().showTotals = value == true
end

function UI.GetLootLogShowPrice()
    return GetLootLogSettings().showPrice
end

function UI.GetLootLogShowPriceDefault()
    return defaults.ui.lootLog.showPrice
end

function UI.GetLootLogShowPriceChoices()
    return {
        LOOT_LOG_PRICE_OFF,
        LOOT_LOG_PRICE_MIN,
        LOOT_LOG_PRICE_MAX,
        LOOT_LOG_PRICE_AVERAGE,
    }
end

function UI.GetLootLogShowPriceChoiceNames()
    return {
        "Off",
        "Min",
        "Max",
        "Average",
    }
end

function UI.SetLootLogShowPrice(value)
    if value ~= LOOT_LOG_PRICE_OFF
        and value ~= LOOT_LOG_PRICE_MIN
        and value ~= LOOT_LOG_PRICE_MAX
        and value ~= LOOT_LOG_PRICE_AVERAGE
    then
        value = defaults.ui.lootLog.showPrice
    end

    GetLootLogSettings().showPrice = value
end

function UI.GetLootLogBufferSize()
    return GetLootLogSettings().bufferSize
end

function UI.GetLootLogBufferSizeDefault()
    return defaults.ui.lootLog.bufferSize
end

function UI.GetLootLogBufferSizeChoices()
    return { 5, 10, 15, 20 }
end

function UI.GetLootLogBufferSizeChoiceNames()
    return { "5", "10", "15", "20" }
end

function UI.SetLootLogBufferSize(value)
    value = tonumber(value)
    if value ~= 5 and value ~= 10 and value ~= 15 and value ~= 20 then
        value = defaults.ui.lootLog.bufferSize
    end

    GetLootLogSettings().bufferSize = value
    if type(UI.ApplyLootLogBufferSettings) == "function" then
        UI.ApplyLootLogBufferSettings()
    end
end

function UI.GetLootLogTimerSeconds()
    return GetLootLogSettings().timerSeconds
end

function UI.GetLootLogTimerSecondsDefault()
    return defaults.ui.lootLog.timerSeconds
end

function UI.GetLootLogTimerSecondsMin()
    return 1
end

function UI.GetLootLogTimerSecondsMax()
    return 10
end

function UI.SetLootLogTimerSeconds(value)
    GetLootLogSettings().timerSeconds = math.floor(Clamp(tonumber(value) or defaults.ui.lootLog.timerSeconds, 1, 10) + 0.5)
    if type(UI.ApplyLootLogBufferSettings) == "function" then
        UI.ApplyLootLogBufferSettings()
    end
end

function UI.GetDisableAlertTexts()
    return GetSettings().disableAlertTexts
end

function UI.RefreshOfficialPlayerFrameVisibility()
    runtimeState.RefreshOfficialPlayerFrame()
end

function UI.RefreshOfficialCompanionFrameVisibility()
    runtimeState.RefreshOfficialCompanionFrame()
end

function UI.RefreshOfficialGroupFrameVisibility()
    runtimeState.RefreshOfficialGroupFrame()
end

function UI.SetDisableAlertTexts(value)
    GetSettings().disableAlertTexts = value == true
    runtimeState.RefreshAlertTexts()
end

function UI.GetActiveQuestHorizontalOffsetMin()
    return 0
end

function UI.GetActiveQuestHorizontalOffsetMax()
    return 100
end

function UI.GetActiveQuestVerticalOffsetMin()
    return 0
end

function UI.GetActiveQuestVerticalOffsetMax()
    return 100
end

function UI.GetActiveQuestHorizontalOffsetLabel()
    return NQOL.L("features.ui.active_quest_horizontal_offset_label")
end

function UI.GetActiveQuestHorizontalOffsetTooltip()
    return NQOL.L("features.ui.active_quest_horizontal_offset_tooltip")
end

function UI.GetActiveQuestVerticalOffsetLabel()
    return NQOL.L("features.ui.active_quest_vertical_offset_label")
end

function UI.GetActiveQuestVerticalOffsetTooltip()
    return NQOL.L("features.ui.active_quest_vertical_offset_tooltip")
end

function UI.GetActiveQuestEnabledLabel()
    return NQOL.L("features.ui.active_quest_enabled_label")
end

function UI.GetActiveQuestEnabledTooltip()
    return NQOL.L("features.ui.active_quest_enabled_tooltip")
end

function UI.GetActiveCombatTipsHorizontalOffsetMin()
    return 0
end

function UI.GetActiveCombatTipsHorizontalOffsetMax()
    return 100
end

function UI.GetActiveCombatTipsVerticalOffsetMin()
    return 0
end

function UI.GetActiveCombatTipsVerticalOffsetMax()
    return 100
end

function UI.GetActiveCombatTipsHorizontalOffsetLabel()
    return NQOL.L("features.ui.active_combat_tips_horizontal_offset_label")
end

function UI.GetActiveCombatTipsHorizontalOffsetTooltip()
    return NQOL.L("features.ui.active_combat_tips_horizontal_offset_tooltip")
end

function UI.GetActiveCombatTipsVerticalOffsetLabel()
    return NQOL.L("features.ui.active_combat_tips_vertical_offset_label")
end

function UI.GetActiveCombatTipsVerticalOffsetTooltip()
    return NQOL.L("features.ui.active_combat_tips_vertical_offset_tooltip")
end

function UI.GetActiveCombatTipsEnabledLabel()
    return NQOL.L("features.ui.active_combat_tips_enabled_label")
end

function UI.GetActiveCombatTipsEnabledTooltip()
    return NQOL.L("features.ui.active_combat_tips_enabled_tooltip")
end

function UI.GetSynergyPromptsHorizontalOffsetMin()
    return 0
end

function UI.GetSynergyPromptsHorizontalOffsetMax()
    return 100
end

function UI.GetSynergyPromptsVerticalOffsetMin()
    return 0
end

function UI.GetSynergyPromptsVerticalOffsetMax()
    return 100
end

function UI.GetSynergyPromptsHorizontalOffsetLabel()
    return NQOL.L("features.ui.synergy_prompts_horizontal_offset_label")
end

function UI.GetSynergyPromptsHorizontalOffsetTooltip()
    return NQOL.L("features.ui.synergy_prompts_horizontal_offset_tooltip")
end

function UI.GetSynergyPromptsVerticalOffsetLabel()
    return NQOL.L("features.ui.synergy_prompts_vertical_offset_label")
end

function UI.GetSynergyPromptsVerticalOffsetTooltip()
    return NQOL.L("features.ui.synergy_prompts_vertical_offset_tooltip")
end

function UI.GetSynergyPromptsEnabledLabel()
    return NQOL.L("features.ui.synergy_prompts_enabled_label")
end

function UI.GetSynergyPromptsEnabledTooltip()
    return NQOL.L("features.ui.synergy_prompts_enabled_tooltip")
end

function UI.GetCenterScreenAnnounceHorizontalOffsetMin()
    return 0
end

function UI.GetCenterScreenAnnounceHorizontalOffsetMax()
    return 100
end

function UI.GetCenterScreenAnnounceVerticalOffsetMin()
    return 0
end

function UI.GetCenterScreenAnnounceVerticalOffsetMax()
    return 100
end

function UI.GetCenterScreenAnnounceHorizontalOffsetLabel()
    return NQOL.L("features.ui.center_screen_announce_horizontal_offset_label")
end

function UI.GetCenterScreenAnnounceHorizontalOffsetTooltip()
    return NQOL.L("features.ui.center_screen_announce_horizontal_offset_tooltip")
end

function UI.GetCenterScreenAnnounceVerticalOffsetLabel()
    return NQOL.L("features.ui.center_screen_announce_vertical_offset_label")
end

function UI.GetCenterScreenAnnounceVerticalOffsetTooltip()
    return NQOL.L("features.ui.center_screen_announce_vertical_offset_tooltip")
end

function UI.GetCenterScreenAnnounceEnabledLabel()
    return NQOL.L("features.ui.center_screen_announce_enabled_label")
end

function UI.GetCenterScreenAnnounceEnabledTooltip()
    return NQOL.L("features.ui.center_screen_announce_enabled_tooltip")
end

function UI.GetLootLogShowTotalsLabel()
    return NQOL.L("features.ui.loot_log_show_totals_label")
end

function UI.GetLootLogShowTotalsTooltip()
    return NQOL.L("features.ui.loot_log_show_totals_tooltip")
end

function UI.GetLootLogShowPriceLabel()
    return NQOL.L("features.ui.loot_log_show_price_label")
end

function UI.GetLootLogShowPriceTooltip()
    return NQOL.L("features.ui.loot_log_show_price_tooltip")
end

function UI.GetLootLogBufferSizeLabel()
    return NQOL.L("features.ui.loot_log_buffer_size_label")
end

function UI.GetLootLogBufferSizeTooltip()
    return NQOL.L("features.ui.loot_log_buffer_size_tooltip")
end

function UI.GetLootLogTimerSecondsLabel()
    return NQOL.L("features.ui.loot_log_timer_seconds_label")
end

function UI.GetLootLogTimerSecondsTooltip()
    return NQOL.L("features.ui.loot_log_timer_seconds_tooltip")
end

function UI.GetDisableAlertTextsLabel()
    return NQOL.L("features.ui.disable_alert_texts_label")
end

function UI.GetDisableAlertTextsTooltip()
    return NQOL.L("features.ui.disable_alert_texts_tooltip")
end

function UI.GetSortDungeonsFinder()
    return GetSettings().sortDungeonsFinder
end

function UI.GetSortDungeonsFinderDefault()
    return defaults.ui.sortDungeonsFinder
end

function UI.SetSortDungeonsFinder(value)
    GetSettings().sortDungeonsFinder = value == true
    runtimeState.dungeonFinderSortActive = value == true
    if runtimeState.dungeonFinderSortActive then
        InstallDungeonFinderSortHook()
    end

    ApplyDungeonFinderSortForRefresh(DUNGEON_FINDER_GAMEPAD)
end

function UI.GetSortDungeonsFinderLabel()
    return NQOL.L("features.ui.sort_dungeons_finder_label")
end

function UI.GetSortDungeonsFinderTooltip()
    return NQOL.L("features.ui.sort_dungeons_finder_tooltip")
end

NQOL.Features.UI = UI
