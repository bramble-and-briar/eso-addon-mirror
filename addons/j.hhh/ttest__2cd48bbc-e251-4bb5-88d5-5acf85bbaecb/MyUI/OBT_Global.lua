OffBalanceTracker = {
    NAME = "OffBalanceTracker",
    AUTHOR = "@Duesentrieb",
    VERSION = "20260901",
    ADDONVERSION = 0004,
    CHAT = "|cFF7F00[OBT]|r",

    -- UI ELEMENTS
    PARENT = nil,
    BG = nil,
    ICON = nil,
    DURATION = nil,
    BOSS_LABEL = nil,
    UPTIME_LABEL = nil,
    TIME_UPDATE = 100,

    TIMELINE = nil,
    ANIMATION_SCALEUP = 0,
    ANIMATION_SCALEDOWN = 0,
    isAnimationActive = false,

    -- SKILL CONSTANTS & ICONS
    debuffName = "",
    cleanDebuffName = "",
    immuneName = "",
    cleanImmuneName = "",
    ICON_OB = "/esoui/art/icons/ability_debuff_offbalance.dds",
    ICON_IMMUNE = "/esoui/art/icons/achievement_030.dds",

    -- STATE VARIABLES
    isLoaded = false,
    isCombat = false,
    isForceShow = false,
    isMenuPreview = false,
    isConsole = false,
    isHideDelayActive = false,
    combatEndId = 0,
    stateCount = 0,
    targetCount = 0,
    groupRole = 0,
    isTrackingBoss = false,
    hasCombatBoss = false,

    -- UPTIME TRACKING
    timeFightStart = 0,
    timeFightUpdate = 0,
    timeState1 = 0,
    timeState0 = 0,
    uptimePercentage = 0,

    -- SOUND
    lastSoundPlayedTime = 0,
    lastSoundEndTime = 0,
    lastAnimatedataEndTime = 0,
    cooldownEndTime = 0,
    lastDataState = 0,
    targetCountEndTime = 0,

    -- TRACKING VARIABLES
    BossTimers = {},
    KnownBosses = {},
    ActiveOffBalance = {},
    Memory = { state = 0, endTime = 0, isBoss = false },
    BOSS_TAGS = { "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" },
    ColorCache = { 1, 1, 1, 1 },

    -- DEFAULT SETTINGS
    Default = {
        enableAddon = true,
        isOnlyCombat = true,
        isOnlyBosses = false,
        isBossFocus = false,
        combatHideDelay = 2.5,

        -- AUDIO
        volumeSound = 1,
        isSoundEnabledTank = false,
        isSoundEnabledHeal = false,
        isSoundEnabledDPS = false,
        isSoundEnabledSolo = false,
        soundTriggerMode = 1,

        -- ROLES
        isEnabledTank = true,
        isEnabledHeal = true,
        isEnabledDPS = true,
        isEnabledSolo = true,

        -- DIMENSIONS & GLOBAL DESIGN
        isShowBackground = true,
        iconSize = 70,
        borderThickness = 5,
        edgeThickness = 1,
        isThickOutline = true,

        -- TIMER
        fontSizeTimer = 40,
        offsetYTimer = 12,
        isColoredTimer = true,
        ColorTextTimer = { 1, 1, 1, 1 },
        decimalThreshold = 7.5,

        -- BOSS LABEL
        isHideBossLabel = false,
        fontSizeBoss = 22,
        offsetYBoss = 12,
        isColoredBossLabel = true,
        isHideExperimental = false,
        ColorTextBoss = { 1, 1, 1, 1 },

        -- UPTIME
        isHideUptime = true,
        fontSizeUptime = 22,
        ColorTextUptime = { 1, 1, 1, 1 },

        -- BORDER COLORS
        ColorIdle = { 0.5, 0.5, 0.5, 1 },
        ColorActive = { 0, 1, 0, 1 },
        ColorImmune = { 1, 0, 0, 1 },

        -- UI
        offsetX = 0,
        offsetY = -100,
        isLocked = false,

        -- CHAT SUMMARY
        isEnabledChat = false,
        minFightTime = 60,
    },

    SV = {},
    SVVersion = 1,
    SVName = "OffBalanceTrackerVariables",
}