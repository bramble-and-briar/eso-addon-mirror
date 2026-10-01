local ADDON_NAME = "NirnsteelUI"
local ADDON_DISPLAY_NAME = "NirnSteel UI"
local SAVED_VARS_VERSION = 1

Nirnsteel_UI = Nirnsteel_UI or {}
local Nirnsteel_UI = Nirnsteel_UI

function Nirnsteel_UI:GetAssetPath(relativePath)
    if not self.assetRoot and GetAddOnManager then
        local manager = GetAddOnManager()
        for index = 1, manager:GetNumAddOns() do
            if manager:GetAddOnInfo(index) == ADDON_NAME then
                local directory = manager:GetAddOnRootDirectoryPath(index)
                -- Texture names are relative to AddOns, not Lua's user:/ mount.
                directory = directory:gsub("\\", "/"):gsub("^[Uu][Ss][Ee][Rr]:/[Aa][Dd][Dd][Oo][Nn][Ss]/", "")
                self.assetRoot = directory:gsub("/+$", "") .. "/"
                break
            end
        end
    end
    return (self.assetRoot or "NirnsteelUI/") .. relativePath
end

local Settings = {}
Nirnsteel_UI.Settings = Settings

local MODULE_MENU_ICONS =
{
    ["Quest Tracker"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_mapandcompass.dds",
    ["Werewolf Rage"] = "/esoui/art/armory/buildicons/buildicon_44.dds",
    ["Achievement Alert"] = Nirnsteel_UI:GetAssetPath("ui/achievement/iron_trophy_dxt5.dds"),
    ["Action Bar"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_abilitybar.dds",
    ["Adventure Camera"] = "EsoUI/Art/Options/Gamepad/gp_options_camera.dds",
    ["Cast Bar"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_castbarsandcooldowns.dds",
    ["Compass"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_mapandcompass.dds",
    ["Damage Numbers"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_combat.dds",
    ["Experience Tracker"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_characterprogression.dds",
    ["Group Callouts"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_chat.dds",
    ["Group Frames"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_unitframes.dds",
    ["HARDCORE Support"] = "EsoUI/Art/Campaign/campaignbrowser_indexicon_hardcore_up.dds",
    ["Kill Sound"] = "EsoUI/Art/Options/Gamepad/gp_options_audio.dds",
    ["Loot History"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_bankandinventory.dds",
    ["Minimap"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_mapandcompass.dds",
    ["Misc"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_uigraphics.dds",
    ["PvP"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_combat.dds",
    ["Resource Bars"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_uigraphics.dds",
    ["Target Frame"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_unitframes.dds",
}

local function ConfigureModuleMenuOptions(options)
    local moduleOptions = {}
    local otherOptions = {}

    for _, option in ipairs(options) do
        if option.type == "submenu" then
            option.icon = MODULE_MENU_ICONS[option.name]
            moduleOptions[#moduleOptions + 1] = option
        else
            otherOptions[#otherOptions + 1] = option
        end
    end

    table.sort(moduleOptions, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)

    local orderedOptions = { otherOptions[1] }
    for _, option in ipairs(moduleOptions) do
        orderedOptions[#orderedOptions + 1] = option
    end
    for index = 2, #otherOptions do
        orderedOptions[#orderedOptions + 1] = otherOptions[index]
    end

    return orderedOptions
end

local PROFILE_MIGRATION_VERSION = 1
local GROUP_CALLOUTS_CHARACTER_MIGRATION_VERSION = 1
local GROUP_FRAMES_DEFAULTS_MIGRATION_VERSION = 1

local CAMERA_PROFILE_DEFAULTS =
{
    horizontalLookSpeed = 0.85,
    verticalLookSpeed = 0.85,
    fieldOfView = 50,
    horizontalPosition = 1,
    horizontalOffset = 0,
    verticalOffset = 0,
}

local ADVENTURE_CAMERA_DISPLAY_SETTINGS =
{
    horizontalLookSpeed = { rawMin = 0.1, rawMax = 1.6, displayMin = 0, displayMax = 100 },
    verticalLookSpeed = { rawMin = 0.1, rawMax = 1.6, displayMin = 0, displayMax = 100 },
    fieldOfView = { rawMin = 35, rawMax = 65, displayMin = 70, displayMax = 130 },
    horizontalPosition = { rawMin = -1, rawMax = 1, displayMin = -100, displayMax = 100 },
    horizontalOffset = { rawMin = -1, rawMax = 1, displayMin = -100, displayMax = 100 },
    verticalOffset = { rawMin = -0.3, rawMax = 0.5, displayMin = -60, displayMax = 100 },
}

local ADVENTURE_CAMERA_SETTING_IDS =
{
    horizontalLookSpeed = CAMERA_SETTING_SENSITIVITY_THIRD_PERSON_X,
    verticalLookSpeed = CAMERA_SETTING_SENSITIVITY_THIRD_PERSON_Y,
    fieldOfView = CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW,
    horizontalPosition = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER,
    horizontalOffset = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET,
    verticalOffset = CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET,
}

local function ClampNumber(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.min(math.max(value, minValue), maxValue)
end

local function RawCameraValueToDisplay(key, rawValue)
    local display = ADVENTURE_CAMERA_DISPLAY_SETTINGS[key]
    if not display then
        return rawValue
    end

    rawValue = ClampNumber(rawValue, display.rawMin, display.rawMax)
    local percent = (rawValue - display.rawMin) / (display.rawMax - display.rawMin)
    return zo_round(display.displayMin + ((display.displayMax - display.displayMin) * percent))
end

local function DisplayCameraValueToRaw(key, displayValue)
    local display = ADVENTURE_CAMERA_DISPLAY_SETTINGS[key]
    if not display then
        return displayValue
    end

    displayValue = ClampNumber(displayValue, display.displayMin, display.displayMax)
    local percent = (displayValue - display.displayMin) / (display.displayMax - display.displayMin)
    return display.rawMin + ((display.rawMax - display.rawMin) * percent)
end

local function CopyCameraProfile(profile)
    local copy = {}
    profile = profile or CAMERA_PROFILE_DEFAULTS

    for key, defaultValue in pairs(CAMERA_PROFILE_DEFAULTS) do
        copy[key] = tonumber(profile[key]) or defaultValue
    end

    return copy
end

local function ReadCurrentCameraProfile()
    local profile = {}

    for key, settingId in pairs(ADVENTURE_CAMERA_SETTING_IDS) do
        profile[key] = tonumber(GetSetting(SETTING_TYPE_CAMERA, settingId)) or CAMERA_PROFILE_DEFAULTS[key]
    end

    return profile
end

local SOUND_CHOICE_LABELS =
{
    TRIBUTE_AGENT_HEALED = "Soft Chime",
    STATS_RESPEC_CLEAR_ALL = "Clean Click",
    TRIBUTE_CARD_UNTARGETED = "Card Tap",
    VENGEANCE_PERK_DROP = "Reward Drop",
    CONSOLE_GAME_ENTER = "Deep Hit",
    RETURNING_PLAYER_OPEN_KEYBOARD = "Sharp Hit",
    VENGEANCE_PERK_EQUIPPED = "Heavy Clang",
    KEYBIND_BUTTON_DISABLED = "Muted Tick",
    PROMOTIONAL_EVENT_REWARD_TO_CLAIM_PROMPT = "Reward Ping",
    BATTLEGROUND_KILL_KILLING_BLOW = "Killing Blow",
    CODE_REDEMPTION_SUCCESS = "Victory Chime",
    BATTLEGROUND_LEAVE_MATCH = "Match Exit",
    BATTLEGROUND_ROUND_RECAP_SCREEN_END = "Round End",
    SKILLS_SUBCLASSING_TRAIN = "Skill Trained",
    none = "None",
    OUTFIT_WEAPON_TYPE_RUNE = "Rune Tick",
    ENDLESS_DUNGEON_COUNTER_DOWN = "Counter Tick",
    BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN = "Major Victory",
    BATTLEGROUND_ROUND_RECAP_SCREEN_WIN = "Victory",
}

local SOUND_KEYS_BY_LABEL = {}
for key, label in pairs(SOUND_CHOICE_LABELS) do
    SOUND_KEYS_BY_LABEL[label] = key
end
SOUND_KEYS_BY_LABEL["Outfit Weapon Type Rune"] = "OUTFIT_WEAPON_TYPE_RUNE"
SOUND_KEYS_BY_LABEL["Promotional Event Reward To Claim"] = "PROMOTIONAL_EVENT_REWARD_TO_CLAIM_PROMPT"
SOUND_KEYS_BY_LABEL["Endless Dungeon Counter Down"] = "ENDLESS_DUNGEON_COUNTER_DOWN"
SOUND_KEYS_BY_LABEL["Battleground Round Recap Final Win"] = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN"
SOUND_KEYS_BY_LABEL["Battleground Round Recap Win"] = "BATTLEGROUND_ROUND_RECAP_SCREEN_WIN"

local function GetSoundChoiceLabel(value)
    return SOUND_CHOICE_LABELS[value] or value
end

local function NormalizeSoundChoice(value)
    return SOUND_KEYS_BY_LABEL[value] or value
end

local GROUP_CALLOUTS_DEFAULTS =
{
    enabled = false,
    unlocked = false,
    soundMode = "leaderOnly",
    soundKey = "KEYBIND_BUTTON_DISABLED",
    scale = 100,
    maxVisible = 3,
    width = 460,
    height = 56,
    rowSpacing = 6,
    iconSize = 24,
    showIcon = true,
    showAccent = true,
    durationMS = 4200,
    slideDistance = 14,
    shimmerEnabled = false,
    shimmerIntensity = 50,
    shimmerTarget = "leaderOnly",
    glowEnabled = false,
    glowIntensity = 50,
    glowTarget = "leaderOnly",
    nameFontKey = "gameSmall",
    messageFontKey = "chat",
    nameFontSize = 14,
    messageFontSize = 14,
    textEffect = "soft-shadow-thin",
    textOpacity = 94,
    hideBackground = false,
    backgroundOpacity = 68,
    borderOpacity = 28,
    accentOpacity = 54,
    memberBackgroundColor = { r = 0.014, g = 0.016, b = 0.020 },
    leaderBackgroundColor = { r = 0.016, g = 0.014, b = 0.012 },
    memberNameColor = { r = 0.72, g = 0.84, b = 0.96 },
    memberTextColor = { r = 0.84, g = 0.87, b = 0.90 },
    memberAccentColor = { r = 0.40, g = 0.55, b = 0.72 },
    leaderNameColor = { r = 0.96, g = 0.78, b = 0.38 },
    leaderTextColor = { r = 0.88, g = 0.84, b = 0.74 },
    leaderAccentColor = { r = 0.92, g = 0.64, b = 0.22 },
    position = { x = 0, y = -260 },
}

local GROUP_FRAMES_DEFAULTS =
{
    enabled = true,
    unlocked = false,
    scale = 100,
    width = 270,
    healthHeight = 24,
    identityHeight = 20,
    rowSpacing = 6,
    columnSpacing = 14,
    trialMembersPerColumn = 0,
    compactTrials = false,
    opacity = 100,
    sortMode = "role",
    displayNameMode = "displayName",
    healthColorMode = "role",
    healthTextMode = "number",
    healthTextPosition = "left",
    showClassIcon = true,
    showRoleIcon = true,
    classIconSize = 16,
    roleIconSize = 16,
    showLeaderIcon = true,
    showShields = true,
    showDeathAnimation = true,
    showFriendIcon = false,
    showGuildIcon = false,
    showLevel = true,
    showLevelStyle = true,
    levelTextSize = 13,
    showRecoveryRhythm = false,
    glossEnabled = true,
    patternEnabled = true,
    patternKey = "ZigZag",
    patternOpacity = 8,
    patternScale = 220,
    feedbackEnabled = true,
    feedbackIntensity = 80,
    lossTrailEnabled = false,
    lowHealthGlowEnabled = true,
    rpgBorder = true,
    borderWidth = 1,
    innerShadowAlpha = 55,
    outerShadowAlpha = 75,
    textFontKey = "gameSmall",
    nameTextSize = 15,
    healthTextSize = 16,
    textOutline = "thick-outline",
    textOpacity = 100,
    textInset = 6,
    staticColor = { r = 0.78, g = 0.10, b = 0.11 },
    fullHealthColor = { r = 0.96, g = 0.96, b = 0.94 },
    lowHealthColor = { r = 0.56, g = 0.035, b = 0.055 },
    tankColor = { r = 0.23, g = 0.51, b = 0.88 },
    healerColor = { r = 0.28, g = 0.72, b = 0.42 },
    damageColor = { r = 0.84, g = 0.27, b = 0.25 },
    otherColor = { r = 0.85, g = 0.60, b = 0.24 },
    companionColor = { r = 0.24, g = 0.62, b = 0.62 },
    shieldFillOpacity = 70,
    shieldFillColor = { r = 0.95, g = 0.60, b = 0.33 },
    shieldGlowEnabled = true,
    shieldGlowOpacity = 58,
    shieldGlowColor = { r = 0.95, g = 0.66, b = 0.56 },
    classColors =
    {
        [1] = { r = 0.85, g = 0.47, b = 0.17 },
        [2] = { r = 0.54, g = 0.39, b = 0.84 },
        [3] = { r = 0.70, g = 0.23, b = 0.28 },
        [4] = { r = 0.26, g = 0.66, b = 0.54 },
        [5] = { r = 0.40, g = 0.54, b = 0.66 },
        [6] = { r = 0.88, g = 0.75, b = 0.33 },
        [117] = { r = 0.25, g = 0.72, b = 0.47 },
    },
    unknownClassColor = { r = 0.54, g = 0.59, b = 0.66 },
}

local TARGET_FRAME_DEFAULTS =
{
    bossDecoration = true,
    enabled = true,
    unlocked = false,
    scale = 100,
    width = 300,
    barHeight = 25,
    opacity = 100,
    glossEnabled = true,
    barPatternEnabled = true,
    barPatternKey = "Molten",
    barPatternOpacity = 6,
    barPatternScale = 228,
    feedbackEnabled = true,
    feedbackIntensity = 95,
    lossTrailEnabled = false,
    gainPulseEnabled = true,
    spendPulseEnabled = true,
    fullResourcePulseEnabled = true,
    shieldPulseEnabled = true,
    lowResourceGlowEnabled = true,
    rpgBorder = true,
    borderWidth = 0,
    innerShadowAlpha = 60,
    outerShadowAlpha = 100,
    textFontKey = "gameSmall",
    nameTextSize = 20,
    healthTextSize = 18,
    textOutline = "thick-outline",
    textOpacity = 100,
    textInset = 6,
    textVerticalOffset = 3,
    textColor = { r = 0.96, g = 0.92, b = 0.82 },
    healthTextFormat = "numberAndPercent",
    healthTextPosition = "sides",
    shieldOverlayEnabled = true,
    shieldTextMode = "healthAndShield",
    shieldFillOpacity = 70,
    shieldFillColor = { r = 0.95, g = 0.60, b = 0.33 },
    shieldGlowEnabled = true,
    shieldGlowOpacity = 65,
    shieldGlowColor = { r = 0.95, g = 0.66, b = 0.56 },
    npcColorMode = "static",
    playerColorMode = "static",
    staticColor = { r = 0.78, g = 0.06, b = 0.08 },
    fullHealthColor = { r = 1.00, g = 1.00, b = 1.00 },
    lowHealthColor = { r = 0.58, g = 0.015, b = 0.025 },
    showClass = true,
    showLevel = true,
    showLevelStyle = true,
    showVeterancyIcon = false,
    showExecuteIcon = true,
    executeIconStyle = "deathDown",
    executeIconScale = 100,
    executeBlinkEnabled = false,
    executeThreshold = 18,
    executePosition = "center",
    classColors =
    {
        [1] = { r = 0.85, g = 0.47, b = 0.17 },
        [2] = { r = 0.54, g = 0.39, b = 0.84 },
        [3] = { r = 0.70, g = 0.23, b = 0.28 },
        [4] = { r = 0.26, g = 0.66, b = 0.54 },
        [5] = { r = 0.40, g = 0.54, b = 0.66 },
        [6] = { r = 0.88, g = 0.75, b = 0.33 },
        [117] = { r = 0.25, g = 0.72, b = 0.47 },
    },
    unknownClassColor = { r = 0.54, g = 0.59, b = 0.66 },
}

local MINIMAP_DEFAULTS =
{
    enabled = true, unlocked = false, shape = "circle", orientation = "north",
    diameter = 280, width = 340, height = 240, questTrackerOffset = 0,
    mapOpacity = 95, frameOpacity = 100, borderThickness = 2, shadow = true,
    borderColor = { r = 0.64, g = 0.72, b = 0.77 },
    accentColor = { r = 0.90, g = 0.74, b = 0.40 },
    showLocation = true, locationNamePosition = "top", showCardinals = true, showCoordinates = false,
    zoneTextSize = 14,
    zoom = 2.5, markerScale = 100, playerScale = 110,
    combatBehavior = "show", combatOpacity = 40,
    clickThrough = false, wheelZoom = true, tooltips = true,
    showGroup = true, showQuests = true, showWayshrines = true,
    showLocations = true, showWaypoint = true, waypointEdge = true, questMode = "tracked",
}

local ACCOUNT_DEFAULTS =
{
    debugMode = false,
    modules =
    {
        questTracker = { enabled = true, unlocked = false, position = false, titleSize = 23, textSize = 17, spacing = 7 },
        werewolfRage = { enabled = true, scale = 100, opacity = 100, showValue = true, showReady = true, unlocked = false, x = 0, y = 170 },
        achievementAlert =
        {
            enabled = true, scale = 100, opacity = 100, duration = 6,
            sound = true, showPoints = true,
            x = 0, y = -220,
        },
        synergyAlert =
        {
            enabled = true,
            unlocked = false,
            scale = 100,
            opacity = 100,
            animationIntensity = 85,
        },
        lootHistory =
        {
            enabled = true,
            legacyStyle = false,
            mirrorLayout = false,
            unlocked = false,
            scale = 100,
            soundsEnabled = true,
            regularSoundKey = "TRIBUTE_AGENT_HEALED",
            filterExperience = false,
        },
        damageNumbers =
        {
            enabled = true,
            unlocked = false,
            hideDefaultDamage = true,
            critSoundEnabled = true,
            fontKey = "trajan",
            textEffect = "shadow",
            critSoundKey = "RETURNING_PLAYER_OPEN_KEYBOARD",
            normalFontSize = 20,
            critFontSize = 55,
            durationMS = 850,
            spread = 170,
            drift = 15,
            bigHitThreshold = 40000,
            maxActive = 20,
            soundThrottleMS = 40,
            savedSctSettings = {},
            damageDoneMinigame =
            {
                enabled = false,
                unlocked = false,
                scale = 100,
                soundEnabled = true,
                tierSoundsEnabled = true,
                faceRight = false,
                displayMode = "damageDone",
                graceMS = 1250,
                animationIntensity = 80,
                showTimer = true,
                showModeLabel = true,
                showHitCount = true,
                showPeakLabel = true,
            },
        },
        killSound =
        {
            enabled = true,
            soundKey = "CODE_REDEMPTION_SUCCESS",
        },
        pvp =
        {
            enabled = true,
            unlocked = false,
            scale = 100,
            intensity = 100,
            soundEnabled = true,
            chainEnabled = true,
            includeDuels = true,
        },
        actionBarFrames =
        {
            enabled = true,
            frameStyle = "rpg",
            skillUseShrinkEnabled = true,
            globalCooldownEnabled = true,
        },
        immersiveTeleport =
        {
            enabled = false,
        },
        adventureCamera =
        {
            enabled = false,
            initialized = false,
            transitionMS = 150,
            actionProfile = CAMERA_PROFILE_DEFAULTS,
            adventureProfile = CAMERA_PROFILE_DEFAULTS,
        },
        castBar =
        {
            enabled = true,
            unlocked = false,
            scale = 100,
            width = 400,
            height = 20,
            opacity = 100,
            textMode = "nameAndTime",
            showIcon = true,
            showTicks = true,
            animationIntensity = 85,
        },
        compass =
        {
            enabled = true,
        },
        minimap = MINIMAP_DEFAULTS,
        experienceTracker =
        {
            enabled = true,
            unlocked = false,
            scale = 100,
            opacity = 100,
            width = 460,
            height = 56,
            durationMS = 3600,
            intensity = 100,
            visibilityMode = "fade",
            chunkSoundKey = "PROMOTIONAL_EVENT_REWARD_TO_CLAIM_PROMPT",
            levelUpSoundKey = "BATTLEGROUND_ROUND_RECAP_SCREEN_FINAL_WIN",
            showGainText = true,
            showProgressText = true,
            showChampionIcon = true,
            levelUpAnimationEnabled = true,
            levelUpIntensity = 100,
            hideBackground = false,
            hideStockProgressBar = true,
        },
        groupFrames = GROUP_FRAMES_DEFAULTS,
        targetFrame = TARGET_FRAME_DEFAULTS,
        resourceBars =
        {
            enabled = true,
            unlocked = false,
            layout = "pyramid",
            attachMountStamina = true,
            scale = 109,
            barHeight = 25,
            rowSpacing = 5,
            columnSpacing = 8,
            rowHealthWidth = 300,
            rowMagickaWidth = 270,
            rowStaminaWidth = 270,
            opacity = 100,
            glossEnabled = true,
            healthTextFormat = "numberAndPercent",
            magickaTextFormat = "numberAndPercent",
            staminaTextFormat = "numberAndPercent",
            healthTextPosition = "sides",
            magickaTextPosition = "sides",
            staminaTextPosition = "sides",
            shieldOverlayEnabled = true,
            shieldTextMode = "healthAndShield",
            shieldFillOpacity = 70,
            shieldFillColor = { r = 0.95, g = 0.60, b = 0.33 },
            shieldGlowEnabled = true,
            shieldGlowOpacity = 65,
            shieldGlowColor = { r = 0.95, g = 0.66, b = 0.56 },
            barPatternEnabled = true,
            barPatternKey = "Molten",
            barPatternOpacity = 6,
            barPatternScale = 228,
            feedbackEnabled = true,
            feedbackIntensity = 100,
            lossTrailEnabled = false,
            gainPulseEnabled = true,
            spendPulseEnabled = true,
            fullResourcePulseEnabled = true,
            shieldPulseEnabled = true,
            lowResourceGlowEnabled = true,
            rpgBorder = true,
            borderWidth = 0,
            innerShadowAlpha = 60,
            outerShadowAlpha = 100,
            textFontKey = "gameSmall",
            textSize = 18,
            textOutline = "thick-outline",
            textOpacity = 100,
            textInset = 6,
            textVerticalOffset = 3,
            textColor = { r = 0.96, g = 0.92, b = 0.82 },
        },
    },
}

local SERVER_DEFAULTS =
{
    servers =
    {
        ["*"] =
        {
            modules =
            {
                lootHistory =
                {
                    x = 180,
                    y = -230,
                },
                damageNumbers =
                {
                    x = 0,
                    y = -45,
                    minigame =
                    {
                        x = 470,
                        y = 250,
                    },
                },
                pvp =
                {
                    x = 0,
                    y = 140,
                },
                experienceTracker =
                {
                    x = 30,
                    y = 30,
                },
                resourceBars =
                {
                    x = 0,
                    y = -120,
                },
                groupFrames =
                {
                    keyboard = { custom = false, x = 28, y = 100 },
                    gamepad = { custom = false, x = 70, y = 55 },
                },
                targetFrame =
                {
                    x = 0,
                    y = 88,
                },
                castBar =
                {
                    x = 0,
                    y = -180,
                },
                synergyAlert =
                {
                    custom = false,
                    x = 0,
                    y = 0,
                },
                minimap = { x = -32, y = -48 },
            },
        },
    },
}

local SERVER_PROFILE_DEFAULTS = SERVER_DEFAULTS.servers["*"]

local CHARACTER_DEFAULTS =
{
    modules =
    {
        groupCallouts = GROUP_CALLOUTS_DEFAULTS,
    },
    hardcoreSupport =
    {
        hideCompass = false,
        hideHealthResourceBar = false,
    },
}

local function GetServerKey()
    local worldName = GetWorldName()
    if worldName and worldName ~= "" then
        return worldName
    end

    return "Default"
end

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function CopySavedValues(target, source, defaults)
    if type(target) ~= "table" or type(source) ~= "table" or type(defaults) ~= "table" then
        return
    end

    for key, defaultValue in pairs(defaults) do
        local savedValue = source[key]
        if type(defaultValue) == "table" then
            if type(savedValue) == "table" then
                if type(target[key]) ~= "table" then
                    target[key] = {}
                end
                CopySavedValues(target[key], savedValue, defaultValue)
            end
        elseif savedValue ~= nil then
            target[key] = savedValue
        end
    end
end

local function MigrateKnownSettings(target, source, defaults)
    if not target or target.nirnsteelServerProfileMigration == PROFILE_MIGRATION_VERSION then
        return
    end

    CopySavedValues(target, source, defaults)
    target.nirnsteelServerProfileMigration = PROFILE_MIGRATION_VERSION
end

local function GetRawAccountWideSettings(savedVariableTableName, profile)
    local savedVariableTable = _G[savedVariableTableName]
    local displayName = GetDisplayName()
    if savedVariableTable and savedVariableTable[profile] and savedVariableTable[profile][displayName] then
        return savedVariableTable[profile][displayName]["$AccountWide"]
    end
end

local function GetRawCharacterIdSettings(savedVariableTableName, profile)
    local savedVariableTable = _G[savedVariableTableName]
    local displayName = GetDisplayName()
    local characterId = GetCurrentCharacterId()
    if savedVariableTable and savedVariableTable[profile] and savedVariableTable[profile][displayName] then
        return savedVariableTable[profile][displayName][characterId]
    end
end

local function MigrateServerSettings(target, serverKey)
    if not target or target.nirnsteelServerProfileMigration == PROFILE_MIGRATION_VERSION then
        return
    end

    local oldServerSettings = GetRawAccountWideSettings("NirnsteelUI_Servers", "Default")
    if oldServerSettings and oldServerSettings.servers and type(oldServerSettings.servers[serverKey]) == "table" then
        CopySavedValues(target, oldServerSettings.servers[serverKey], SERVER_PROFILE_DEFAULTS)
    end

    target.nirnsteelServerProfileMigration = PROFILE_MIGRATION_VERSION
end

local function GetGroupCalloutsServerPositionForCharacterMigration(server, serverKey)
    local modules = server and server.modules
    local position = modules and modules.groupCallouts
    if type(position) == "table" then
        return position
    end

    local oldServerSettings = GetRawAccountWideSettings("NirnsteelUI_Servers", "Default")
    position = oldServerSettings
        and oldServerSettings.servers
        and oldServerSettings.servers[serverKey]
        and oldServerSettings.servers[serverKey].modules
        and oldServerSettings.servers[serverKey].modules.groupCallouts
    if type(position) == "table" then
        return position
    end
end

local function MigrateGroupCalloutsToCharacterSettings(account, server, character, serverKey)
    if not character or character.nirnsteelGroupCalloutsCharacterMigration == GROUP_CALLOUTS_CHARACTER_MIGRATION_VERSION then
        return
    end

    local source = account
        and account.modules
        and account.modules.groupCallouts
    local target = character.modules
        and character.modules.groupCallouts

    if type(source) == "table" and type(target) == "table" then
        CopySavedValues(target, source, GROUP_CALLOUTS_DEFAULTS)
    end

    source = GetGroupCalloutsServerPositionForCharacterMigration(server, serverKey)
    target = target and target.position
    if type(source) == "table" and type(target) == "table" then
        CopySavedValues(target, source, GROUP_CALLOUTS_DEFAULTS.position)
    end

    character.nirnsteelGroupCalloutsCharacterMigration = GROUP_CALLOUTS_CHARACTER_MIGRATION_VERSION
end

local function UpgradeDamageNumberDefaults(account)
    local damageNumbers = account
        and account.modules
        and account.modules.damageNumbers

    if not damageNumbers then
        return
    end

    if damageNumbers.normalFontSize == 42 then
        damageNumbers.normalFontSize = ACCOUNT_DEFAULTS.modules.damageNumbers.normalFontSize
    end

    if damageNumbers.critFontSize == 58 then
        damageNumbers.critFontSize = ACCOUNT_DEFAULTS.modules.damageNumbers.critFontSize
    end

    if damageNumbers.durationMS == 950 then
        damageNumbers.durationMS = ACCOUNT_DEFAULTS.modules.damageNumbers.durationMS
    end

    if damageNumbers.spread == 150 then
        damageNumbers.spread = ACCOUNT_DEFAULTS.modules.damageNumbers.spread
    end

    if damageNumbers.drift == 120 then
        damageNumbers.drift = ACCOUNT_DEFAULTS.modules.damageNumbers.drift
    end
end

local function UpgradeExperienceTrackerDefaults(account)
    local experienceTracker = account
        and account.modules
        and account.modules.experienceTracker

    if not experienceTracker then
        return
    end

    if experienceTracker.width == 420 and experienceTracker.height == 48 then
        experienceTracker.width = ACCOUNT_DEFAULTS.modules.experienceTracker.width
        experienceTracker.height = ACCOUNT_DEFAULTS.modules.experienceTracker.height
    elseif experienceTracker.width == 460 and experienceTracker.height == 64 then
        experienceTracker.height = ACCOUNT_DEFAULTS.modules.experienceTracker.height
    end
end

local function UpgradeResourceBarDefaults(account)
    local resourceBars = account
        and account.modules
        and account.modules.resourceBars

    if not resourceBars then
        return
    end

    if resourceBars.rowHealthWidth == 220 then
        resourceBars.rowHealthWidth = ACCOUNT_DEFAULTS.modules.resourceBars.rowHealthWidth
    end
    if resourceBars.rowMagickaWidth == 220 then
        resourceBars.rowMagickaWidth = ACCOUNT_DEFAULTS.modules.resourceBars.rowMagickaWidth
    end
    if resourceBars.rowStaminaWidth == 220 then
        resourceBars.rowStaminaWidth = ACCOUNT_DEFAULTS.modules.resourceBars.rowStaminaWidth
    end
    if resourceBars.columnSpacing == 0 then
        resourceBars.columnSpacing = ACCOUNT_DEFAULTS.modules.resourceBars.columnSpacing
    end
    resourceBars.layoutMode = nil
    resourceBars.healthPositionMode = nil
    resourceBars.stackedWidth = nil
    resourceBars.width = nil
    resourceBars.healthChaseSpeed = nil

    local textFormatAliases =
    {
        None = "none",
        Number = "number",
        Percent = "percent",
        ["Number + Percent"] = "numberAndPercent",
        ["Number and Percent"] = "numberAndPercent",
    }
    local textPositionAliases =
    {
        Center = "center",
        Sides = "sides",
    }
    local shieldTextAliases =
    {
        Off = "off",
        ["Shield Only"] = "shieldOnly",
        ["Health + Shield"] = "healthAndShield",
    }
    local fontAliases =
    {
        ["Game Small"] = "gameSmall",
        ["Game Medium"] = "gameMedium",
        Antique = "antique",
        Trajan = "trajan",
        Univers = "univers",
        Chat = "chat",
    }
    local outlineAliases =
    {
        None = "none",
        ["Soft Thin"] = "soft-shadow-thin",
        ["Soft Thick"] = "soft-shadow-thick",
        ["Thick Outline"] = "thick-outline",
    }
    local patternAliases =
    {
        Smoke = "smoke",
        Stillwater = "stillwater",
        ["Still Water"] = "stillwater",
        ZigZag = "ZigZag",
        Zigzag = "ZigZag",
        Stone = "Stone",
        Dirt = "Dirt",
        Lava = "Lava",
        RockLava = "RockLava",
        ["Rock Lava"] = "RockLava",
        LavaWave = "LavaWave",
        ["Lava Wave"] = "LavaWave",
        Molten = "Molten",
    }

    for _, key in ipairs({ "healthTextFormat", "magickaTextFormat", "staminaTextFormat" }) do
        resourceBars[key] = textFormatAliases[resourceBars[key]] or resourceBars[key] or ACCOUNT_DEFAULTS.modules.resourceBars[key]
    end
    for _, key in ipairs({ "healthTextPosition", "magickaTextPosition", "staminaTextPosition" }) do
        resourceBars[key] = textPositionAliases[resourceBars[key]] or resourceBars[key] or ACCOUNT_DEFAULTS.modules.resourceBars[key]
    end
    resourceBars.shieldTextMode = shieldTextAliases[resourceBars.shieldTextMode] or resourceBars.shieldTextMode or ACCOUNT_DEFAULTS.modules.resourceBars.shieldTextMode
    resourceBars.textFontKey = fontAliases[resourceBars.textFontKey] or resourceBars.textFontKey or ACCOUNT_DEFAULTS.modules.resourceBars.textFontKey
    resourceBars.textOutline = outlineAliases[resourceBars.textOutline] or resourceBars.textOutline or ACCOUNT_DEFAULTS.modules.resourceBars.textOutline
    resourceBars.barPatternKey = patternAliases[resourceBars.barPatternKey] or resourceBars.barPatternKey or ACCOUNT_DEFAULTS.modules.resourceBars.barPatternKey
end

local function UpgradeGroupFramesDefaults(account)
    local groupFrames = account
        and account.modules
        and account.modules.groupFrames

    if not groupFrames
        or groupFrames.nirnsteelDefaultsMigration == GROUP_FRAMES_DEFAULTS_MIGRATION_VERSION then
        return
    end

    -- Carry users who received the original Group Frames default forward without
    -- overwriting any other pattern scale they may have selected themselves.
    if groupFrames.patternScale == 96 then
        groupFrames.patternScale = GROUP_FRAMES_DEFAULTS.patternScale
    end
    groupFrames.nirnsteelDefaultsMigration = GROUP_FRAMES_DEFAULTS_MIGRATION_VERSION
end

local function UpgradeSoundChoiceLabels(account)
    local modules = account and account.modules
    if not modules then
        return
    end

    if modules.lootHistory then
        modules.lootHistory.regularSoundKey = NormalizeSoundChoice(modules.lootHistory.regularSoundKey)
            or ACCOUNT_DEFAULTS.modules.lootHistory.regularSoundKey
    end

    if modules.damageNumbers then
        modules.damageNumbers.critSoundKey = NormalizeSoundChoice(modules.damageNumbers.critSoundKey)
            or ACCOUNT_DEFAULTS.modules.damageNumbers.critSoundKey
    end

    if modules.killSound then
        modules.killSound.soundKey = NormalizeSoundChoice(modules.killSound.soundKey)
            or ACCOUNT_DEFAULTS.modules.killSound.soundKey
        if modules.killSound.soundKey == "BATTLEGROUND_KILL_KILLING_BLOW" then
            modules.killSound.soundKey = ACCOUNT_DEFAULTS.modules.killSound.soundKey
        end
    end

    if modules.experienceTracker then
        modules.experienceTracker.chunkSoundKey = NormalizeSoundChoice(modules.experienceTracker.chunkSoundKey)
            or ACCOUNT_DEFAULTS.modules.experienceTracker.chunkSoundKey
        modules.experienceTracker.levelUpSoundKey = NormalizeSoundChoice(modules.experienceTracker.levelUpSoundKey)
            or ACCOUNT_DEFAULTS.modules.experienceTracker.levelUpSoundKey
    end
end

local function UpgradeGroupCalloutsSoundChoiceLabels(character)
    local groupCallouts = character
        and character.modules
        and character.modules.groupCallouts

    if not groupCallouts then
        return
    end

    groupCallouts.soundKey = NormalizeSoundChoice(groupCallouts.soundKey)
        or GROUP_CALLOUTS_DEFAULTS.soundKey
end

local function UpgradeCastBarDefaults(account)
    local castBar = account
        and account.modules
        and account.modules.castBar

    if not castBar then
        return
    end

    local textModeAliases =
    {
        ["Name + Time"] = "nameAndTime",
        ["Name Only"] = "nameOnly",
        ["Timer Only"] = "timerOnly",
        Off = "off",
    }

    castBar.textMode = textModeAliases[castBar.textMode] or castBar.textMode or ACCOUNT_DEFAULTS.modules.castBar.textMode
    if castBar.width == 320 or castBar.width == 380 then
        castBar.width = ACCOUNT_DEFAULTS.modules.castBar.width
    end
    if castBar.height == 28 or castBar.height == 34 then
        castBar.height = ACCOUNT_DEFAULTS.modules.castBar.height
    end
    if castBar.animationIntensity == 100 then
        castBar.animationIntensity = ACCOUNT_DEFAULTS.modules.castBar.animationIntensity
    end
end

local function UpgradeTargetFrameExecuteIcon(account)
    local targetFrame = account
        and account.modules
        and account.modules.targetFrame
    if not targetFrame then
        return
    end

    local validStyles =
    {
        whiteSkull = true,
        champion = true,
        darkAnchors = true,
        avaGeneral = true,
        avaLegate = true,
        retrait = true,
        scoring = true,
        deathDown = true,
        deathOver = true,
    }
    if not validStyles[targetFrame.executeIconStyle] then
        targetFrame.executeIconStyle = TARGET_FRAME_DEFAULTS.executeIconStyle
    end
end

function Settings:Initialize()
    self.serverKey = GetServerKey()

    self.account = ZO_SavedVars:NewAccountWide("NirnsteelUI_Account", SAVED_VARS_VERSION, nil, ACCOUNT_DEFAULTS, self.serverKey)
    MigrateKnownSettings(self.account, GetRawAccountWideSettings("NirnsteelUI_Account", "Default"), ACCOUNT_DEFAULTS)
    CopyDefaults(self.account, ACCOUNT_DEFAULTS)
    -- Preserve the old combined preference once, then let each option vary.
    local minigame = self.account.modules.damageNumbers.damageDoneMinigame
    if minigame.showDetails ~= nil then
        for _, key in ipairs({ "showTimer", "showModeLabel", "showHitCount", "showPeakLabel" }) do
            minigame[key] = minigame.showDetails ~= false
        end
        minigame.showDetails = nil
    end
    UpgradeDamageNumberDefaults(self.account)
    UpgradeExperienceTrackerDefaults(self.account)
    UpgradeResourceBarDefaults(self.account)
    UpgradeGroupFramesDefaults(self.account)
    UpgradeSoundChoiceLabels(self.account)
    UpgradeCastBarDefaults(self.account)
    UpgradeTargetFrameExecuteIcon(self.account)
    self.servers = ZO_SavedVars:NewAccountWide("NirnsteelUI_Servers", SAVED_VARS_VERSION, nil, SERVER_PROFILE_DEFAULTS, self.serverKey)
    MigrateServerSettings(self.servers, self.serverKey)
    self.server = self.servers
    CopyDefaults(self.server, SERVER_PROFILE_DEFAULTS)
    self.character = ZO_SavedVars:NewCharacterIdSettings("NirnsteelUI_Character", SAVED_VARS_VERSION, nil, CHARACTER_DEFAULTS, self.serverKey)
    MigrateKnownSettings(self.character, GetRawCharacterIdSettings("NirnsteelUI_Character", "Default"), CHARACTER_DEFAULTS)
    CopyDefaults(self.character, CHARACTER_DEFAULTS)
    MigrateGroupCalloutsToCharacterSettings(self.account, self.server, self.character, self.serverKey)
    UpgradeGroupCalloutsSoundChoiceLabels(self.character)

    self:RegisterAddonMenu()
end

function Settings:GetLootHistory()
    return self.account.modules.lootHistory
end

function Settings:GetLootHistoryPosition()
    return self.server.modules.lootHistory
end

function Settings:GetDamageNumbers()
    return self.account.modules.damageNumbers
end

function Settings:GetDamageNumbersPosition()
    return self.server.modules.damageNumbers
end

function Settings:GetDamageDoneMinigame()
    return self:GetDamageNumbers().damageDoneMinigame
end

function Settings:GetDamageDoneMinigamePosition()
    return self:GetDamageNumbersPosition().minigame
end

function Settings:GetKillSound()
    return self.account.modules.killSound
end

function Settings:GetPvP()
    return self.account.modules.pvp
end

function Settings:GetPvPPosition()
    return self.server.modules.pvp
end

function Settings:GetGroupCallouts()
    return self.character.modules.groupCallouts
end

function Settings:GetGroupCalloutsPosition()
    return self.character.modules.groupCallouts.position
end

function Settings:GetActionBarFrames()
    return self.account.modules.actionBarFrames
end

function Settings:GetAdventureCamera()
    return self.account.modules.adventureCamera
end

function Settings:GetCastBar()
    return self.account.modules.castBar
end

function Settings:GetCastBarPosition()
    return self.server.modules.castBar
end

function Settings:GetCompass()
    return self.account.modules.compass
end

function Settings:GetMinimap()
    return self.account.modules.minimap
end

function Settings:GetMinimapPosition()
    return self.server.modules.minimap
end

function Settings:SetMinimapValue(key, value)
    self:GetMinimap()[key] = value
    if Nirnsteel_UI.Minimap then Nirnsteel_UI.Minimap:RefreshSettings() end
end

function Settings:ResetMinimapSettings()
    local defaults = {}
    CopyDefaults(defaults, MINIMAP_DEFAULTS)
    self.account.modules.minimap = defaults
    local position = self:GetMinimapPosition()
    position.x, position.y = -32, -48
    if Nirnsteel_UI.Minimap then Nirnsteel_UI.Minimap:RefreshSettings() end
end

function Settings:GetExperienceTracker()
    return self.account.modules.experienceTracker
end

function Settings:GetExperienceTrackerPosition()
    return self.server.modules.experienceTracker
end

function Settings:GetResourceBars()
    return self.account.modules.resourceBars
end

function Settings:GetResourceBarsPosition()
    return self.server.modules.resourceBars
end

function Settings:GetGroupFrames()
    return self.account.modules.groupFrames
end

function Settings:GetGroupFramesPosition(mode)
    mode = mode or (IsInGamepadPreferredMode and IsInGamepadPreferredMode() and "gamepad" or "keyboard")
    return self.server.modules.groupFrames[mode]
end

function Settings:GetTargetFrame()
    return self.account.modules.targetFrame
end

function Settings:GetTargetFramePosition()
    return self.server.modules.targetFrame
end

function Settings:GetHardcoreSupport()
    return self.character.hardcoreSupport
end

function Settings:IsDebugModeEnabled()
    return self.account and self.account.debugMode == true
end

function Settings:SetDebugModeEnabled(value)
    self.account.debugMode = value == true

    local modules =
    {
        Nirnsteel_UI.LootHistory,
        Nirnsteel_UI.DamageNumbers,
        Nirnsteel_UI.PvP,
        Nirnsteel_UI.ExperienceTracker,
        Nirnsteel_UI.ResourceBars,
        Nirnsteel_UI.GroupFrames,
        Nirnsteel_UI.TargetFrame,
        Nirnsteel_UI.CastBar,
        Nirnsteel_UI.GroupCallouts,
    }

    for _, module in ipairs(modules) do
        if module and module.RefreshDebugCommands then
            module:RefreshDebugCommands()
        end
    end
end

function Settings:IsLootHistoryEnabled()
    return self:GetLootHistory().enabled
end

function Settings:IsLootHistoryUnlocked()
    return self:GetLootHistory().unlocked
end

function Settings:AreLootHistorySoundsEnabled()
    return self:GetLootHistory().soundsEnabled
end

function Settings:ShouldFilterLootHistoryExperience()
    return self:GetLootHistory().filterExperience
end

function Settings:SetLootHistoryEnabled(value)
    self:GetLootHistory().enabled = value
    if Nirnsteel_UI.LootHistory then
        Nirnsteel_UI.LootHistory:RefreshSettings()
    end
end

function Settings:SetLootHistoryUnlocked(value)
    self:GetLootHistory().unlocked = value
    if Nirnsteel_UI.LootHistory then
        Nirnsteel_UI.LootHistory:RefreshSettings()
    end
end

function Settings:SetLootHistorySoundsEnabled(value)
    self:GetLootHistory().soundsEnabled = value
end

function Settings:SetLootHistoryValue(key, value)
    if key == "regularSoundKey" then
        value = NormalizeSoundChoice(value)
    end

    self:GetLootHistory()[key] = value
    if (key == "scale" or key == "legacyStyle" or key == "mirrorLayout") and Nirnsteel_UI.LootHistory then
        Nirnsteel_UI.LootHistory:RefreshSettings()
    end
end

function Settings:SetLootHistoryFilterExperience(value)
    self:GetLootHistory().filterExperience = value
end

function Settings:SetLootHistoryPosition(x, y)
    local position = self:GetLootHistoryPosition()
    position.x = x
    position.y = y
end

function Settings:IsDamageNumbersEnabled()
    return self:GetDamageNumbers().enabled
end

function Settings:IsDamageNumbersUnlocked()
    return self:GetDamageNumbers().unlocked
end

function Settings:ShouldHideDefaultDamageNumbers()
    return self:GetDamageNumbers().hideDefaultDamage
end

function Settings:AreDamageNumberCritSoundsEnabled()
    return self:GetDamageNumbers().critSoundEnabled
end

function Settings:IsDamageDoneMinigameEnabled()
    return self:GetDamageDoneMinigame().enabled
end

function Settings:IsDamageDoneMinigameUnlocked()
    return self:GetDamageDoneMinigame().unlocked
end

function Settings:AreDamageDoneMinigameSoundsEnabled()
    return self:GetDamageDoneMinigame().soundEnabled
end

function Settings:SetDamageNumbersEnabled(value)
    self:GetDamageNumbers().enabled = value
    if Nirnsteel_UI.DamageNumbers then
        Nirnsteel_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageNumbersUnlocked(value)
    self:GetDamageNumbers().unlocked = value
    if Nirnsteel_UI.DamageNumbers then
        Nirnsteel_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageNumbersHideDefault(value)
    self:GetDamageNumbers().hideDefaultDamage = value
    if Nirnsteel_UI.DamageNumbers then
        Nirnsteel_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageNumberCritSoundsEnabled(value)
    self:GetDamageNumbers().critSoundEnabled = value
end

function Settings:SetDamageNumberValue(key, value)
    if key == "critSoundKey" then
        value = NormalizeSoundChoice(value)
    end

    self:GetDamageNumbers()[key] = value
    if Nirnsteel_UI.DamageNumbers then
        Nirnsteel_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageNumbersPosition(x, y)
    local position = self:GetDamageNumbersPosition()
    position.x = x
    position.y = y
end

function Settings:SetDamageDoneMinigameEnabled(value)
    self:GetDamageDoneMinigame().enabled = value
    if Nirnsteel_UI.DamageNumbers then
        Nirnsteel_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageDoneMinigameUnlocked(value)
    self:GetDamageDoneMinigame().unlocked = value
    if Nirnsteel_UI.DamageNumbers then
        Nirnsteel_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageDoneMinigameValue(key, value)
    self:GetDamageDoneMinigame()[key] = value
    if Nirnsteel_UI.DamageNumbers then
        Nirnsteel_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageDoneMinigamePosition(x, y)
    local position = self:GetDamageDoneMinigamePosition()
    position.x = x
    position.y = y
end

function Settings:IsKillSoundEnabled()
    return self:GetKillSound().enabled
end

function Settings:SetKillSoundEnabled(value)
    self:GetKillSound().enabled = value
    if Nirnsteel_UI.KillSound then
        Nirnsteel_UI.KillSound:RefreshSettings()
    end
end

function Settings:SetKillSoundValue(key, value)
    if key == "soundKey" then
        value = NormalizeSoundChoice(value)
        if value == "BATTLEGROUND_KILL_KILLING_BLOW" then
            value = ACCOUNT_DEFAULTS.modules.killSound.soundKey
        end
    end

    self:GetKillSound()[key] = value
    if Nirnsteel_UI.KillSound then
        Nirnsteel_UI.KillSound:RefreshSettings()
    end
end

function Settings:GetAchievementAlert()
    return self.account.modules.achievementAlert
end

function Settings:GetWerewolfRage()
    return self.account.modules.werewolfRage
end

function Settings:GetQuestTracker()
    return self.account.modules.questTracker
end

function Settings:GetQuestTrackerOptions()
    local controls = {}
    local function Option(key,name,kind,minimum,maximum)
        controls[#controls+1] = {
            type=kind,name=name,min=minimum,max=maximum,step=1,
            getFunc=function() return self:GetQuestTracker()[key] end,
            setFunc=function(value)
                if minimum then value=ClampNumber(value,minimum,maximum) end
                self:GetQuestTracker()[key]=value
                if Nirnsteel_UI.QuestTracker then Nirnsteel_UI.QuestTracker:RefreshSettings() end
            end,
            default=ACCOUNT_DEFAULTS.modules.questTracker[key],
        }
    end
    Option("enabled","Enable Quest Tracker Style","checkbox")
    Option("unlocked","Unlock Quest Log","checkbox")
    controls[#controls].tooltip = "Show a drag handle to move the quest log. Lock it again to keep the saved position. The current position is used until you move it."
    Option("titleSize","Quest Title Size","slider",18,30)
    Option("textSize","Objective Text Size","slider",14,24)
    Option("spacing","Objective Spacing","slider",5,14)
    return controls
end

function Settings:GetWerewolfRageOptions()
    local controls = {}
    local function Option(key,name,kind,minimum,maximum,step)
        controls[#controls+1] = {
            type=kind,name=name,min=minimum,max=maximum,step=step,
            getFunc=function() return self:GetWerewolfRage()[key] end,
            setFunc=function(value)
                if minimum then value=ClampNumber(value,minimum,maximum) end
                self:GetWerewolfRage()[key]=value
                if Nirnsteel_UI.WerewolfRage then Nirnsteel_UI.WerewolfRage:RefreshSettings() end
            end,
            default=ACCOUNT_DEFAULTS.modules.werewolfRage[key],
        }
    end
    Option("enabled","Enable Werewolf Rage","checkbox")
    Option("showValue","Show Rage Value","checkbox")
    Option("showReady","Show Rampage Ready Text","checkbox")
    Option("unlocked","Unlock Position","checkbox")
    Option("scale","Scale (%)","slider",60,160,5)
    Option("opacity","Opacity (%)","slider",20,100,5)
    controls[#controls+1]={type="button",name="Preview Rage Build-up",func=function()
        if Nirnsteel_UI.WerewolfRage then Nirnsteel_UI.WerewolfRage:Preview() end
    end,disabled=function() return not self:GetWerewolfRage().enabled end}
    controls[#controls+1]={type="button",name="Reset Position",func=function()
        self:GetWerewolfRage().x,self:GetWerewolfRage().y=0,170
        if Nirnsteel_UI.WerewolfRage then Nirnsteel_UI.WerewolfRage:RefreshSettings() end
    end}
    return controls
end

function Settings:SetAchievementAlertValue(key, value)
    local ranges = { scale = {60, 160}, opacity = {20, 100}, duration = {3, 12}, x = {-1600, 1600}, y = {-900, 900} }
    if ranges[key] then value = ClampNumber(value, ranges[key][1], ranges[key][2]) end
    self:GetAchievementAlert()[key] = value
    if Nirnsteel_UI.AchievementAlert then Nirnsteel_UI.AchievementAlert:RefreshSettings() end
end

function Settings:GetAchievementAlertOptions()
    local controls = {}
    local function AddOption(key, name, kind, minimum, maximum, step)
        controls[#controls + 1] = {
            type = kind, name = name, min = minimum, max = maximum, step = step,
            getFunc = function() return self:GetAchievementAlert()[key] end,
            setFunc = function(value) self:SetAchievementAlertValue(key, value) end,
            default = ACCOUNT_DEFAULTS.modules.achievementAlert[key],
        }
    end
    AddOption("enabled", "Enable Achievement Alert", "checkbox")
    AddOption("sound", "Play Achievement Sound", "checkbox")
    AddOption("showPoints", "Show Achievement Points", "checkbox")
    AddOption("scale", "Scale (%)", "slider", 60, 160, 5)
    AddOption("opacity", "Opacity (%)", "slider", 20, 100, 5)
    AddOption("duration", "Duration (seconds)", "slider", 3, 12, 1)
    AddOption("x", "Horizontal Position", "slider", -1600, 1600, 10)
    AddOption("y", "Vertical Position", "slider", -900, 900, 10)
    controls[#controls + 1] = {
        type = "button", name = "Preview Achievement",
        func = function() if Nirnsteel_UI.AchievementAlert then Nirnsteel_UI.AchievementAlert:Preview() end end,
        disabled = function() return not self:GetAchievementAlert().enabled end,
    }
    controls[#controls + 1] = {
        type = "button", name = "Reset Position",
        func = function()
            self:SetAchievementAlertValue("x", 0)
            self:SetAchievementAlertValue("y", -220)
        end,
    }
    return controls
end

function Settings:GetSynergyAlert()
    return self.account.modules.synergyAlert
end

function Settings:GetSynergyAlertPosition()
    return self.server.modules.synergyAlert
end

function Settings:SetSynergyAlertValue(key, value)
    local ranges = { scale = { 70, 160 }, opacity = { 20, 100 }, animationIntensity = { 0, 160 } }
    if ranges[key] then
        value = ClampNumber(value, ranges[key][1], ranges[key][2])
    end
    self:GetSynergyAlert()[key] = value
    if Nirnsteel_UI.SynergyAlert then
        Nirnsteel_UI.SynergyAlert:RefreshSettings()
    end
end

function Settings:SetSynergyAlertPosition(x, y)
    local position = self:GetSynergyAlertPosition()
    position.custom = true
    position.x = x
    position.y = y
end

function Settings:ResetSynergyAlertPosition()
    local position = self:GetSynergyAlertPosition()
    position.custom = false
    position.x = 0
    position.y = 0
    if Nirnsteel_UI.SynergyAlert then
        Nirnsteel_UI.SynergyAlert:ApplyLayout()
    end
end

function Settings:IsPvPEnabled()
    return self:GetPvP().enabled
end

function Settings:IsPvPUnlocked()
    return self:GetPvP().unlocked
end

function Settings:SetPvPEnabled(value)
    self:GetPvP().enabled = value == true
    if Nirnsteel_UI.PvP then
        Nirnsteel_UI.PvP:RefreshSettings()
    end
end

function Settings:SetPvPUnlocked(value)
    self:GetPvP().unlocked = value == true
    if Nirnsteel_UI.PvP then
        Nirnsteel_UI.PvP:RefreshSettings()
    end
end

function Settings:SetPvPValue(key, value)
    self:GetPvP()[key] = value
    if Nirnsteel_UI.PvP then
        Nirnsteel_UI.PvP:RefreshSettings()
    end
end

function Settings:SetPvPPosition(x, y)
    local position = self:GetPvPPosition()
    position.x = x
    position.y = y
end

function Settings:IsGroupCalloutsEnabled()
    return self:GetGroupCallouts().enabled
end

function Settings:IsGroupCalloutsUnlocked()
    return self:GetGroupCallouts().unlocked
end

function Settings:SetGroupCalloutsEnabled(value)
    self:GetGroupCallouts().enabled = value
    if Nirnsteel_UI.GroupCallouts then
        Nirnsteel_UI.GroupCallouts:RefreshSettings()
    end
end

function Settings:SetGroupCalloutsUnlocked(value)
    self:GetGroupCallouts().unlocked = value
    if Nirnsteel_UI.GroupCallouts then
        Nirnsteel_UI.GroupCallouts:RefreshSettings()
    end
end

function Settings:SetGroupCalloutsValue(key, value)
    local soundModeAliases =
    {
        Off = "off",
        ["Leader Only"] = "leaderOnly",
        ["Every Message"] = "all",
    }
    local fontAliases =
    {
        ["Game Small"] = "gameSmall",
        ["Game Medium"] = "gameMedium",
        Antique = "antique",
        Trajan = "trajan",
        Univers = "univers",
        Chat = "chat",
    }
    local effectAliases =
    {
        None = "none",
        ["Soft Thin"] = "soft-shadow-thin",
        ["Soft Thick"] = "soft-shadow-thick",
        ["Thick Outline"] = "thick-outline",
    }
    local targetAliases =
    {
        ["Leader Only"] = "leaderOnly",
        ["All Callouts"] = "all",
        All = "all",
    }

    if key == "soundKey" then
        value = NormalizeSoundChoice(value)
    elseif key == "soundMode" then
        value = soundModeAliases[value] or value
        if value ~= "off" and value ~= "leaderOnly" and value ~= "all" then
            value = GROUP_CALLOUTS_DEFAULTS.soundMode
        end
    elseif key == "nameFontKey" or key == "messageFontKey" then
        value = fontAliases[value] or value
        if value ~= "gameSmall"
            and value ~= "gameMedium"
            and value ~= "antique"
            and value ~= "trajan"
            and value ~= "univers"
            and value ~= "chat" then
            value = GROUP_CALLOUTS_DEFAULTS[key]
        end
    elseif key == "textEffect" then
        value = effectAliases[value] or value
        if value ~= "none"
            and value ~= "soft-shadow-thin"
            and value ~= "soft-shadow-thick"
            and value ~= "thick-outline" then
            value = GROUP_CALLOUTS_DEFAULTS.textEffect
        end
    elseif key == "shimmerTarget" or key == "glowTarget" then
        value = targetAliases[value] or value
        if value ~= "leaderOnly" and value ~= "all" then
            value = GROUP_CALLOUTS_DEFAULTS[key]
        end
    end

    self:GetGroupCallouts()[key] = value
    if Nirnsteel_UI.GroupCallouts then
        Nirnsteel_UI.GroupCallouts:RefreshSettings()
    end
end

function Settings:GetGroupCalloutsColor(key)
    local color = self:GetGroupCallouts()[key]
    local defaultColor = GROUP_CALLOUTS_DEFAULTS[key]
    if type(color) ~= "table" then
        color = defaultColor
    end

    return color.r or defaultColor.r, color.g or defaultColor.g, color.b or defaultColor.b, 1
end

function Settings:SetGroupCalloutsColor(key, r, g, b)
    local settings = self:GetGroupCallouts()
    local color = settings[key]
    if type(color) ~= "table" then
        color = {}
        settings[key] = color
    end

    color.r = r
    color.g = g
    color.b = b

    if Nirnsteel_UI.GroupCallouts then
        Nirnsteel_UI.GroupCallouts:RefreshSettings()
    end
end

function Settings:SetGroupCalloutsPosition(x, y)
    local position = self:GetGroupCalloutsPosition()
    position.x = x
    position.y = y
end

function Settings:PreviewGroupCalloutsSound()
    if Nirnsteel_UI.GroupCallouts and Nirnsteel_UI.GroupCallouts.PreviewSound then
        Nirnsteel_UI.GroupCallouts:PreviewSound()
    end
end

function Settings:PreviewGroupCallout()
    if Nirnsteel_UI.GroupCallouts and Nirnsteel_UI.GroupCallouts.PreviewRegular then
        Nirnsteel_UI.GroupCallouts:PreviewRegular()
    end
end

function Settings:PreviewGroupCalloutLeader()
    if Nirnsteel_UI.GroupCallouts and Nirnsteel_UI.GroupCallouts.PreviewLeader then
        Nirnsteel_UI.GroupCallouts:PreviewLeader()
    end
end

function Settings:SetGroupCalloutsSettingsPreviewActive(active)
    if Nirnsteel_UI.GroupCallouts and Nirnsteel_UI.GroupCallouts.SetSettingsPreviewActive then
        Nirnsteel_UI.GroupCallouts:SetSettingsPreviewActive(active)
    end
end

function Settings:PreviewDamageNumberCritSound()
    if Nirnsteel_UI.DamageNumbers and Nirnsteel_UI.DamageNumbers.PreviewCriticalSound then
        Nirnsteel_UI.DamageNumbers:PreviewCriticalSound()
    end
end

function Settings:PreviewDamageDoneMinigame(showTiers)
    if Nirnsteel_UI.DamageNumbers and Nirnsteel_UI.DamageNumbers.PreviewDamageDoneMinigame then
        Nirnsteel_UI.DamageNumbers:PreviewDamageDoneMinigame(showTiers)
    end
end

function Settings:PreviewKillSound()
    if Nirnsteel_UI.KillSound and Nirnsteel_UI.KillSound.PreviewSound then
        Nirnsteel_UI.KillSound:PreviewSound()
    end
end

function Settings:PreviewPvPChain()
    if Nirnsteel_UI.PvP and Nirnsteel_UI.PvP.PreviewChain then
        Nirnsteel_UI.PvP:PreviewChain()
    end
end

function Settings:PreviewLootHistoryRegularSound()
    if Nirnsteel_UI.LootHistory and Nirnsteel_UI.LootHistory.PreviewRegularSound then
        Nirnsteel_UI.LootHistory:PreviewRegularSound()
    end
end

function Settings:IsActionBarFramesEnabled()
    return self:GetActionBarFrames().enabled
end

function Settings:IsActionBarSkillUseShrinkEnabled()
    return self:GetActionBarFrames().skillUseShrinkEnabled
end

function Settings:IsActionBarGlobalCooldownEnabled()
    return self:GetActionBarFrames().globalCooldownEnabled
end

function Settings:SetActionBarFramesEnabled(value)
    self:GetActionBarFrames().enabled = value
    if Nirnsteel_UI.ActionBarFrames then
        Nirnsteel_UI.ActionBarFrames:RefreshSettings()
    end
end

function Settings:SetActionBarSkillUseShrinkEnabled(value)
    self:GetActionBarFrames().skillUseShrinkEnabled = value
end

function Settings:SetActionBarGlobalCooldownEnabled(value)
    self:GetActionBarFrames().globalCooldownEnabled = value
    if Nirnsteel_UI.ActionBarFrames then
        Nirnsteel_UI.ActionBarFrames:RefreshSettings()
    end
end

function Settings:IsImmersiveTeleportEnabled()
    return self.account.modules.immersiveTeleport.enabled
end

function Settings:SetImmersiveTeleportEnabled(value)
    self.account.modules.immersiveTeleport.enabled = value
    if Nirnsteel_UI.ImmersiveTeleport then
        Nirnsteel_UI.ImmersiveTeleport:RefreshSettings()
    end
end

function Settings:IsAdventureCameraEnabled()
    return self:GetAdventureCamera().enabled
end

function Settings:InitializeAdventureCameraProfilesIfNeeded()
    local settings = self:GetAdventureCamera()
    if settings.initialized then
        return
    end

    local currentProfile = ReadCurrentCameraProfile()
    settings.actionProfile = CopyCameraProfile(currentProfile)
    settings.adventureProfile = CopyCameraProfile(currentProfile)
    settings.initialized = true
end

function Settings:SetAdventureCameraEnabled(value)
    if value then
        self:InitializeAdventureCameraProfilesIfNeeded()
    end

    self:GetAdventureCamera().enabled = value
    if Nirnsteel_UI.AdventureCamera then
        Nirnsteel_UI.AdventureCamera:RefreshSettings()
    end
end

function Settings:SetAdventureCameraValue(key, value)
    self:GetAdventureCamera()[key] = value
    if Nirnsteel_UI.AdventureCamera then
        Nirnsteel_UI.AdventureCamera:RefreshSettings()
    end
end

function Settings:GetAdventureCameraDisplayValue(key)
    local settings = self:GetAdventureCamera()
    local profile = settings.adventureProfile or CAMERA_PROFILE_DEFAULTS
    return RawCameraValueToDisplay(key, profile[key] or CAMERA_PROFILE_DEFAULTS[key])
end

function Settings:SetAdventureCameraDisplayValue(key, value)
    local settings = self:GetAdventureCamera()
    settings.adventureProfile = settings.adventureProfile or CopyCameraProfile(CAMERA_PROFILE_DEFAULTS)
    settings.adventureProfile[key] = DisplayCameraValueToRaw(key, value)

    if Nirnsteel_UI.AdventureCamera then
        Nirnsteel_UI.AdventureCamera:RefreshSettings()
    end
end

function Settings:CaptureAdventureCameraActionProfile()
    local settings = self:GetAdventureCamera()
    local currentProfile = ReadCurrentCameraProfile()
    settings.actionProfile = CopyCameraProfile(currentProfile)
    if not settings.initialized then
        settings.adventureProfile = CopyCameraProfile(currentProfile)
    end
    settings.initialized = true

    if Nirnsteel_UI.AdventureCamera then
        Nirnsteel_UI.AdventureCamera:RefreshSettings()
    end
end

function Settings:IsCastBarEnabled()
    return self:GetCastBar().enabled
end

function Settings:IsCastBarUnlocked()
    return self:GetCastBar().unlocked
end

function Settings:SetCastBarEnabled(value)
    self:GetCastBar().enabled = value
    if Nirnsteel_UI.CastBar then
        Nirnsteel_UI.CastBar:RefreshSettings()
    end
end

function Settings:SetCastBarUnlocked(value)
    self:GetCastBar().unlocked = value
    if Nirnsteel_UI.CastBar then
        Nirnsteel_UI.CastBar:RefreshSettings()
    end
end

function Settings:SetCastBarValue(key, value)
    local textModeAliases =
    {
        ["Name + Time"] = "nameAndTime",
        ["Name Only"] = "nameOnly",
        ["Timer Only"] = "timerOnly",
        Off = "off",
    }

    if key == "textMode" then
        value = textModeAliases[value] or value
    end

    self:GetCastBar()[key] = value
    if Nirnsteel_UI.CastBar then
        Nirnsteel_UI.CastBar:RefreshSettings()
    end
end

function Settings:SetCastBarPosition(x, y)
    local position = self:GetCastBarPosition()
    position.x = x
    position.y = y
end

function Settings:PreviewCastBar()
    if Nirnsteel_UI.CastBar and Nirnsteel_UI.CastBar.Preview then
        Nirnsteel_UI.CastBar:Preview()
    end
end

function Settings:IsCompassEnabled()
    return self:GetCompass().enabled
end

function Settings:SetCompassEnabled(value)
    self:GetCompass().enabled = value
    if Nirnsteel_UI.Compass then
        Nirnsteel_UI.Compass:RefreshSettings()
    end
end

function Settings:IsExperienceTrackerEnabled()
    return self:GetExperienceTracker().enabled
end

function Settings:IsExperienceTrackerUnlocked()
    return self:GetExperienceTracker().unlocked
end

function Settings:ShouldExperienceTrackerHideStockProgressBar()
    return self:GetExperienceTracker().hideStockProgressBar
end

function Settings:SetExperienceTrackerEnabled(value)
    self:GetExperienceTracker().enabled = value
    if Nirnsteel_UI.ExperienceTracker then
        Nirnsteel_UI.ExperienceTracker:RefreshSettings()
    end
end

function Settings:SetExperienceTrackerUnlocked(value)
    self:GetExperienceTracker().unlocked = value
    if Nirnsteel_UI.ExperienceTracker then
        Nirnsteel_UI.ExperienceTracker:RefreshSettings()
    end
end

function Settings:SetExperienceTrackerValue(key, value)
    if key == "chunkSoundKey" or key == "levelUpSoundKey" then
        value = NormalizeSoundChoice(value)
    end

    self:GetExperienceTracker()[key] = value
    if Nirnsteel_UI.ExperienceTracker then
        Nirnsteel_UI.ExperienceTracker:RefreshSettings()
    end
end

function Settings:SetExperienceTrackerPosition(x, y)
    local position = self:GetExperienceTrackerPosition()
    position.x = x
    position.y = y
end

function Settings:PreviewExperienceTracker()
    if Nirnsteel_UI.ExperienceTracker and Nirnsteel_UI.ExperienceTracker.PreviewGain then
        Nirnsteel_UI.ExperienceTracker:PreviewGain()
    end
end

function Settings:IsResourceBarsEnabled()
    return self:GetResourceBars().enabled
end

function Settings:IsResourceBarsUnlocked()
    return self:GetResourceBars().unlocked
end

function Settings:SetResourceBarsEnabled(value)
    self:GetResourceBars().enabled = value
    if Nirnsteel_UI.ResourceBars then
        Nirnsteel_UI.ResourceBars:RefreshSettings()
    end
end

function Settings:SetResourceBarsUnlocked(value)
    self:GetResourceBars().unlocked = value
    if Nirnsteel_UI.ResourceBars then
        Nirnsteel_UI.ResourceBars:RefreshSettings()
    end
end

function Settings:SetResourceBarsValue(key, value)
    local textFormatAliases =
    {
        None = "none",
        Number = "number",
        Percent = "percent",
        ["Number + Percent"] = "numberAndPercent",
        ["Number and Percent"] = "numberAndPercent",
    }
    local textPositionAliases =
    {
        Center = "center",
        Sides = "sides",
    }
    local shieldTextAliases =
    {
        Off = "off",
        ["Shield Only"] = "shieldOnly",
        ["Health + Shield"] = "healthAndShield",
    }
    local fontAliases =
    {
        ["Game Small"] = "gameSmall",
        ["Game Medium"] = "gameMedium",
        Antique = "antique",
        Trajan = "trajan",
        Univers = "univers",
        Chat = "chat",
    }
    local outlineAliases =
    {
        None = "none",
        ["Soft Thin"] = "soft-shadow-thin",
        ["Soft Thick"] = "soft-shadow-thick",
        ["Thick Outline"] = "thick-outline",
    }
    local patternAliases =
    {
        Smoke = "smoke",
        Stillwater = "stillwater",
        ["Still Water"] = "stillwater",
        ZigZag = "ZigZag",
        Zigzag = "ZigZag",
        Stone = "Stone",
        Dirt = "Dirt",
        Lava = "Lava",
        RockLava = "RockLava",
        ["Rock Lava"] = "RockLava",
        LavaWave = "LavaWave",
        ["Lava Wave"] = "LavaWave",
        Molten = "Molten",
    }

    if key == "healthTextFormat" or key == "magickaTextFormat" or key == "staminaTextFormat" then
        value = textFormatAliases[value] or value
    elseif key == "healthTextPosition" or key == "magickaTextPosition" or key == "staminaTextPosition" then
        value = textPositionAliases[value] or value
    elseif key == "shieldTextMode" then
        value = shieldTextAliases[value] or value
    elseif key == "textFontKey" then
        value = fontAliases[value] or value
    elseif key == "textOutline" then
        value = outlineAliases[value] or value
    elseif key == "barPatternKey" then
        value = patternAliases[value] or value
    end

    self:GetResourceBars()[key] = value
    if Nirnsteel_UI.ResourceBars then
        Nirnsteel_UI.ResourceBars:RefreshSettings()
    end
end

function Settings:SetResourceBarsPosition(x, y)
    local position = self:GetResourceBarsPosition()
    position.x = x
    position.y = y
end

function Settings:SetResourceBarsSettingsPreviewActive(active)
    if Nirnsteel_UI.ResourceBars and Nirnsteel_UI.ResourceBars.SetSettingsPreviewActive then
        Nirnsteel_UI.ResourceBars:SetSettingsPreviewActive(active)
    end
end

function Settings:IsGroupFramesEnabled()
    return self:GetGroupFrames().enabled ~= false
end

function Settings:IsGroupFramesUnlocked()
    return self:IsGroupFramesEnabled() and self:GetGroupFrames().unlocked == true
end

function Settings:SetGroupFramesEnabled(value)
    self:GetGroupFrames().enabled = value == true
    if Nirnsteel_UI.GroupFrames then
        Nirnsteel_UI.GroupFrames:RefreshSettings()
    end
end

function Settings:SetGroupFramesUnlocked(value)
    self:GetGroupFrames().unlocked = value == true
    if Nirnsteel_UI.GroupFrames then
        Nirnsteel_UI.GroupFrames:RefreshSettings()
    end
end

function Settings:SetGroupFramesValue(key, value)
    self:GetGroupFrames()[key] = value
    if Nirnsteel_UI.GroupFrames then
        Nirnsteel_UI.GroupFrames:RefreshSettings()
    end
end

function Settings:GetGroupFramesColor(key)
    local color = self:GetGroupFrames()[key]
    local fallback = GROUP_FRAMES_DEFAULTS[key]
    return color or fallback
end

function Settings:SetGroupFramesColor(key, r, g, b)
    local settings = self:GetGroupFrames()
    settings[key] = settings[key] or {}
    settings[key].r = r
    settings[key].g = g
    settings[key].b = b
    if Nirnsteel_UI.GroupFrames then
        Nirnsteel_UI.GroupFrames:RefreshSettings()
    end
end

function Settings:GetGroupFramesClassColor(classId)
    local settings = self:GetGroupFrames()
    settings.classColors = settings.classColors or {}
    return settings.classColors[classId] or GROUP_FRAMES_DEFAULTS.classColors[classId]
end

function Settings:SetGroupFramesClassColor(classId, r, g, b)
    local settings = self:GetGroupFrames()
    settings.classColors = settings.classColors or {}
    settings.classColors[classId] = settings.classColors[classId] or {}
    settings.classColors[classId].r = r
    settings.classColors[classId].g = g
    settings.classColors[classId].b = b
    if Nirnsteel_UI.GroupFrames then
        Nirnsteel_UI.GroupFrames:RefreshSettings()
    end
end

function Settings:SetGroupFramesPosition(mode, x, y, custom)
    local position = self:GetGroupFramesPosition(mode)
    position.x = x
    position.y = y
    position.custom = custom == true
end

function Settings:ResetGroupFramesPosition(mode)
    local position = self:GetGroupFramesPosition(mode)
    local defaults = SERVER_PROFILE_DEFAULTS.modules.groupFrames[mode]
    position.x = defaults.x
    position.y = defaults.y
    position.custom = false
end

function Settings:SetGroupFramesSettingsPreviewActive(active)
    if Nirnsteel_UI.GroupFrames and Nirnsteel_UI.GroupFrames.SetSettingsPreviewActive then
        Nirnsteel_UI.GroupFrames:SetSettingsPreviewActive(active)
    end
end

function Settings:IsTargetFrameEnabled()
    return self:GetTargetFrame().enabled ~= false
end

function Settings:IsTargetFrameUnlocked()
    return self:IsTargetFrameEnabled() and self:GetTargetFrame().unlocked == true
end

function Settings:SetTargetFrameEnabled(value)
    self:GetTargetFrame().enabled = value == true
    if Nirnsteel_UI.TargetFrame then
        Nirnsteel_UI.TargetFrame:RefreshSettings()
    end
end

function Settings:SetTargetFrameUnlocked(value)
    self:GetTargetFrame().unlocked = value == true
    if Nirnsteel_UI.TargetFrame and Nirnsteel_UI.TargetFrame.SetUnlocked then
        Nirnsteel_UI.TargetFrame:SetUnlocked(value)
    elseif Nirnsteel_UI.TargetFrame then
        Nirnsteel_UI.TargetFrame:RefreshSettings()
    end
end

function Settings:SetTargetFrameValue(key, value)
    self:GetTargetFrame()[key] = value
    if Nirnsteel_UI.TargetFrame then
        Nirnsteel_UI.TargetFrame:RefreshSettings()
    end
end

function Settings:GetTargetFrameColor(key)
    return self:GetTargetFrame()[key] or TARGET_FRAME_DEFAULTS[key]
end

function Settings:SetTargetFrameColor(key, r, g, b)
    local settings = self:GetTargetFrame()
    settings[key] = settings[key] or {}
    settings[key].r = r
    settings[key].g = g
    settings[key].b = b
    if Nirnsteel_UI.TargetFrame then
        Nirnsteel_UI.TargetFrame:RefreshSettings()
    end
end

function Settings:GetTargetFrameClassColor(classId)
    local settings = self:GetTargetFrame()
    settings.classColors = settings.classColors or {}
    return settings.classColors[classId] or TARGET_FRAME_DEFAULTS.classColors[classId]
end

function Settings:SetTargetFrameClassColor(classId, r, g, b)
    local settings = self:GetTargetFrame()
    settings.classColors = settings.classColors or {}
    settings.classColors[classId] = settings.classColors[classId] or {}
    settings.classColors[classId].r = r
    settings.classColors[classId].g = g
    settings.classColors[classId].b = b
    if Nirnsteel_UI.TargetFrame then
        Nirnsteel_UI.TargetFrame:RefreshSettings()
    end
end

function Settings:SetTargetFramePosition(x, y)
    local position = self:GetTargetFramePosition()
    position.x = x
    position.y = y
end

function Settings:ResetTargetFramePosition()
    local position = self:GetTargetFramePosition()
    position.x = SERVER_PROFILE_DEFAULTS.modules.targetFrame.x
    position.y = SERVER_PROFILE_DEFAULTS.modules.targetFrame.y
end

function Settings:ResetActiveTargetFramePosition()
    if Nirnsteel_UI.TargetFrame and Nirnsteel_UI.TargetFrame.ResetPosition then
        Nirnsteel_UI.TargetFrame:ResetPosition()
    else
        self:ResetTargetFramePosition()
    end
end

function Settings:SetTargetFrameSettingsPreviewActive(active)
    if Nirnsteel_UI.TargetFrame and Nirnsteel_UI.TargetFrame.SetSettingsPreviewActive then
        Nirnsteel_UI.TargetFrame:SetSettingsPreviewActive(active)
    end
end

function Settings:ReplayTargetFramePreviewEffects()
    if Nirnsteel_UI.TargetFrame and Nirnsteel_UI.TargetFrame.ReplayPreviewEffects then
        Nirnsteel_UI.TargetFrame:ReplayPreviewEffects()
    end
end

function Settings:ReplayGroupFramesPreviewEffects()
    if Nirnsteel_UI.GroupFrames and Nirnsteel_UI.GroupFrames.ReplayPreviewEffects then
        Nirnsteel_UI.GroupFrames:ReplayPreviewEffects()
    end
end

function Settings:ResetActiveGroupFramesPosition()
    if Nirnsteel_UI.GroupFrames and Nirnsteel_UI.GroupFrames.ResetPosition then
        Nirnsteel_UI.GroupFrames:ResetPosition()
    else
        local mode = IsInGamepadPreferredMode and IsInGamepadPreferredMode() and "gamepad" or "keyboard"
        self:ResetGroupFramesPosition(mode)
    end
end

function Settings:ShouldHardcoreHideCompass()
    return self:GetHardcoreSupport().hideCompass == true
end

function Settings:SetHardcoreHideCompass(value)
    self:GetHardcoreSupport().hideCompass = value == true
    if Nirnsteel_UI.Compass then
        Nirnsteel_UI.Compass:RefreshSettings()
    end
end

function Settings:ShouldHardcoreHideHealthResourceBar()
    return self:GetHardcoreSupport().hideHealthResourceBar == true
end

function Settings:SetHardcoreHideHealthResourceBar(value)
    self:GetHardcoreSupport().hideHealthResourceBar = value == true
    if Nirnsteel_UI.ResourceBars then
        Nirnsteel_UI.ResourceBars:RefreshSettings()
    end
end

function Settings:HookResourceBarsSubmenuPreview(panelName)
    if self.resourceBarsPreviewHooked then
        return
    end

    self.resourceBarsPreviewHooked = true
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if not panel or panel:GetName() ~= panelName then
            return
        end

        local submenu = Nirnsteel_UI_ResourceBarsSubmenu
        if not submenu or submenu.nirnsteelPreviewHooked then
            return
        end

        local function UpdatePreview()
            zo_callLater(function()
                self:SetResourceBarsSettingsPreviewActive(submenu.open == true)
            end, 50)
        end

        if ZO_PostHookHandler then
            ZO_PostHookHandler(submenu.label, "OnMouseUp", UpdatePreview)
            ZO_PostHookHandler(submenu.btmToggle, "OnMouseUp", UpdatePreview)
        end

        submenu.nirnsteelPreviewHooked = true
        UpdatePreview()
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel and panel:GetName() == panelName then
            self:SetResourceBarsSettingsPreviewActive(false)
        end
    end)
end

function Settings:HookGroupCalloutsSubmenuPreview(panelName)
    if self.groupCalloutsPreviewHooked then
        return
    end

    self.groupCalloutsPreviewHooked = true
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if not panel or panel:GetName() ~= panelName then
            return
        end

        local submenu = Nirnsteel_UI_GroupCalloutsSubmenu
        if not submenu or submenu.nirnsteelPreviewHooked then
            return
        end

        local function UpdatePreview()
            zo_callLater(function()
                self:SetGroupCalloutsSettingsPreviewActive(submenu.open == true)
            end, 50)
        end

        if ZO_PostHookHandler then
            ZO_PostHookHandler(submenu.label, "OnMouseUp", UpdatePreview)
            ZO_PostHookHandler(submenu.btmToggle, "OnMouseUp", UpdatePreview)
        end

        submenu.nirnsteelPreviewHooked = true
        UpdatePreview()
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel and panel:GetName() == panelName then
            self:SetGroupCalloutsSettingsPreviewActive(false)
        end
    end)
end

function Settings:HookGroupFramesSubmenuPreview(panelName)
    if self.groupFramesPreviewHooked then
        return
    end

    self.groupFramesPreviewHooked = true
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if not panel or panel:GetName() ~= panelName then
            return
        end

        local submenu = Nirnsteel_UI_GroupFramesSubmenu
        if not submenu or submenu.nirnsteelPreviewHooked then
            return
        end

        local function UpdatePreview()
            zo_callLater(function()
                self:SetGroupFramesSettingsPreviewActive(submenu.open == true)
            end, 50)
        end

        if ZO_PostHookHandler then
            ZO_PostHookHandler(submenu.label, "OnMouseUp", UpdatePreview)
            ZO_PostHookHandler(submenu.btmToggle, "OnMouseUp", UpdatePreview)
        end

        submenu.nirnsteelPreviewHooked = true
        UpdatePreview()
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel and panel:GetName() == panelName then
            self:SetGroupFramesSettingsPreviewActive(false)
        end
    end)
end

function Settings:HookTargetFrameSubmenuPreview(panelName)
    if self.targetFramePreviewHooked then
        return
    end

    self.targetFramePreviewHooked = true
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if not panel or panel:GetName() ~= panelName then
            return
        end

        local submenu = Nirnsteel_UI_TargetFrameSubmenu
        if not submenu or submenu.nirnsteelPreviewHooked then
            return
        end

        local function UpdatePreview()
            zo_callLater(function()
                self:SetTargetFrameSettingsPreviewActive(submenu.open == true)
            end, 50)
        end

        if ZO_PostHookHandler then
            ZO_PostHookHandler(submenu.label, "OnMouseUp", UpdatePreview)
            ZO_PostHookHandler(submenu.btmToggle, "OnMouseUp", UpdatePreview)
        end

        submenu.nirnsteelPreviewHooked = true
        UpdatePreview()
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel and panel:GetName() == panelName then
            self:SetTargetFrameSettingsPreviewActive(false)
        end
    end)
end

function Settings:BuildGroupFramesOptions()
    local controls = {}
    local function Add(control)
        controls[#controls + 1] = control
    end
    local function Disabled()
        return not self:IsGroupFramesEnabled()
    end
    local function Header(name)
        Add({ type = "header", name = name })
    end
    local function Description(text)
        Add({ type = "description", text = text })
    end
    local function Checkbox(name, key, tooltip, disabled)
        Add(
        {
            type = "checkbox",
            name = name,
            tooltip = tooltip,
            getFunc = function() return self:GetGroupFrames()[key] end,
            setFunc = function(value) self:SetGroupFramesValue(key, value) end,
            disabled = disabled or Disabled,
            default = GROUP_FRAMES_DEFAULTS[key],
        })
    end
    local function Dropdown(name, key, tooltip, choices, values, disabled)
        Add(
        {
            type = "dropdown",
            name = name,
            tooltip = tooltip,
            choices = choices,
            choicesValues = values,
            getFunc = function() return self:GetGroupFrames()[key] end,
            setFunc = function(value) self:SetGroupFramesValue(key, value) end,
            disabled = disabled or Disabled,
            default = GROUP_FRAMES_DEFAULTS[key],
        })
    end
    local function Slider(name, key, tooltip, minimum, maximum, step, disabled)
        Add(
        {
            type = "slider",
            name = name,
            tooltip = tooltip,
            min = minimum,
            max = maximum,
            step = step,
            getFunc = function() return self:GetGroupFrames()[key] end,
            setFunc = function(value) self:SetGroupFramesValue(key, value) end,
            disabled = disabled or Disabled,
            default = GROUP_FRAMES_DEFAULTS[key],
        })
    end
    local function ColorPicker(name, key, tooltip, disabled)
        Add(
        {
            type = "colorpicker",
            name = name,
            tooltip = tooltip,
            getFunc = function()
                local color = self:GetGroupFramesColor(key)
                return color.r, color.g, color.b, 1
            end,
            setFunc = function(r, g, b) self:SetGroupFramesColor(key, r, g, b) end,
            disabled = disabled or Disabled,
            default = function()
                local color = GROUP_FRAMES_DEFAULTS[key]
                return color.r, color.g, color.b, 1
            end,
        })
    end
    local function ClassColorPicker(name, classId)
        Add(
        {
            type = "colorpicker",
            name = name,
            getFunc = function()
                local color = self:GetGroupFramesClassColor(classId)
                return color.r, color.g, color.b, 1
            end,
            setFunc = function(r, g, b) self:SetGroupFramesClassColor(classId, r, g, b) end,
            disabled = function()
                return Disabled() or self:GetGroupFrames().healthColorMode ~= "class"
            end,
            default = function()
                local color = GROUP_FRAMES_DEFAULTS.classColors[classId]
                return color.r, color.g, color.b, 1
            end,
        })
    end

    Header("General & Position")
    Add(
    {
        type = "checkbox",
        name = "Enable Group Frames",
        tooltip = "Swap ESO's group and raid frames for Nirnsteel's. Turn this off anytime to bring ESO's frames back.",
        getFunc = function() return self:IsGroupFramesEnabled() end,
        setFunc = function(value) self:SetGroupFramesEnabled(value) end,
        default = GROUP_FRAMES_DEFAULTS.enabled,
    })
    Add(
    {
        type = "checkbox",
        name = "Unlock Position",
        tooltip = "Show a drag handle for the frames. Keyboard and gamepad positions are saved separately on this server.",
        getFunc = function() return self:IsGroupFramesUnlocked() end,
        setFunc = function(value) self:SetGroupFramesUnlocked(value) end,
        disabled = Disabled,
        default = GROUP_FRAMES_DEFAULTS.unlocked,
    })
    Add(
    {
        type = "button",
        name = "Reset Position",
        tooltip = "Move the frames back to ESO's default spot for your current input mode.",
        func = function() self:ResetActiveGroupFramesPosition() end,
        disabled = Disabled,
        width = "half",
    })
    Slider("Scale", "scale", nil, 70, 160, 1)
    Slider("Player Bar Width", "width", nil, 180, 420, 5)
    Slider("Health Bar Height", "healthHeight", nil, 12, 42, 1)
    Slider("Identity Line Height", "identityHeight", "Set how much room names, levels, and icons get above each bar.", 16, 32, 1)
    Slider("Row Spacing", "rowSpacing", nil, 0, 24, 1)
    Slider("Column Spacing", "columnSpacing", nil, 0, 40, 1)
    Checkbox("Compact Trial Design", "compactTrials", "Use smaller frames for groups larger than four: name, role, health percentage, shields, and essential status indicators. Hides levels, class/social icons, patterns, and iron ornaments. Small parties keep your normal design. Preview shows 12 members when enabled.")
    local trialLayoutChoices = { "Automatic (Default)", "2 Columns / 6 Members", "3 Columns / 4 Members", "4 Columns / 3 Members", "1 Column / 12 Members" }
    local trialLayoutValues = { 0, 6, 4, 3, 12 }
    local currentMembers = self:GetGroupFrames().trialMembersPerColumn
    if currentMembers and currentMembers ~= 0 and currentMembers ~= 6 and currentMembers ~= 4 and currentMembers ~= 3 and currentMembers ~= 12 then
        trialLayoutChoices[#trialLayoutChoices + 1] = string.format("Custom / %s Members per Column", tostring(currentMembers))
        trialLayoutValues[#trialLayoutValues + 1] = currentMembers
    end
    Dropdown("Trial Layout", "trialMembersPerColumn",
        "Choose a layout for 12-player Trials. Each column fills with the listed number of members; the number of columns adjusts to your group size. Groups of 4 or fewer keep one column. Automatic preserves the original layout.",
        trialLayoutChoices, trialLayoutValues)
    Slider("Opacity", "opacity", nil, 10, 100, 1)

    Header("Roster & Names")
    Dropdown("Display Order", "sortMode", "Choose how players are sorted. Role goes Tank, Healer, Damage, then Other; Level puts the highest CP first.",
        { "By Role", "By Name", "By Level", "By Class" }, { "role", "name", "level", "class" })
    Dropdown("Display Name", "displayNameMode", "Choose which player name to show and use for name sorting.",
        { "@ID", "Character Name" }, { "displayName", "characterName" })

    Header("Identity & Status Icons")
    Checkbox("Show Class Icon", "showClassIcon", nil)
    Checkbox("Show Role Icon", "showRoleIcon", "Show each player's chosen group role. It may not match their current build.")
    Slider("Class Icon Size", "classIconSize", "Set the class icon size in pixels.", 10, 28, 1)
    Slider("Role Icon Size", "roleIconSize", "Set the role icon size in pixels.", 10, 28, 1)
    Checkbox("Show Group Leader Icon", "showLeaderIcon", nil)
    Checkbox("Show Friend Icon", "showFriendIcon", nil)
    Checkbox("Show Shared Guild Icon", "showGuildIcon", nil)

    Header("Health & Colors")
    Dropdown("Health Display", "healthTextMode", nil,
        { "Number Only", "Percent Only", "Number + Percent" }, { "number", "percent", "both" })
    Dropdown("Health Text Position", "healthTextPosition", nil,
        { "Left", "Center", "Right" }, { "left", "center", "right" })
    Dropdown("Health Color", "healthColorMode", "Color bars by role, class, or health. Health colors fade from white at full to deep red at low.",
        { "By Role", "Static Red", "Health Percentage", "By Class" }, { "role", "static", "percentage", "class" })

    local function RoleColorsDisabled()
        return Disabled() or self:GetGroupFrames().healthColorMode ~= "role"
    end
    local function StaticColorDisabled()
        return Disabled() or self:GetGroupFrames().healthColorMode ~= "static"
    end
    local function PercentageColorsDisabled()
        return Disabled() or self:GetGroupFrames().healthColorMode ~= "percentage"
    end
    ColorPicker("Tank Color", "tankColor", nil, RoleColorsDisabled)
    ColorPicker("Healer Color", "healerColor", nil, RoleColorsDisabled)
    ColorPicker("Damage Color", "damageColor", nil, RoleColorsDisabled)
    ColorPicker("Other Role Color", "otherColor", nil, RoleColorsDisabled)
    ColorPicker("Companion Color", "companionColor", nil)
    ColorPicker("Static Health Color", "staticColor", nil, StaticColorDisabled)
    ColorPicker("Full Health Color", "fullHealthColor", nil, PercentageColorsDisabled)
    ColorPicker("Low Health Color", "lowHealthColor", nil, PercentageColorsDisabled)
    ClassColorPicker("Dragonknight Color", 1)
    ClassColorPicker("Sorcerer Color", 2)
    ClassColorPicker("Nightblade Color", 3)
    ClassColorPicker("Warden Color", 4)
    ClassColorPicker("Necromancer Color", 5)
    ClassColorPicker("Templar Color", 6)
    ClassColorPicker("Arcanist Color", 117)
    ColorPicker("Unknown Class Color", "unknownClassColor", nil, function()
        return Disabled() or self:GetGroupFrames().healthColorMode ~= "class"
    end)

    Header("Bar Appearance")
    Checkbox("NirnSteel Iron Borders", "rpgBorder")
    Checkbox("Gloss", "glossEnabled", nil)
    Checkbox("Bar Pattern", "patternEnabled", nil)
    Dropdown("Pattern", "patternKey", nil,
        { "ZigZag", "Smoke", "Still Water", "Stone", "Dirt", "Lava", "Rock Lava", "Lava Wave", "Molten" },
        { "ZigZag", "smoke", "stillwater", "Stone", "Dirt", "Lava", "RockLava", "LavaWave", "Molten" },
        function() return Disabled() or self:GetGroupFrames().patternEnabled ~= true end)
    Slider("Pattern Opacity", "patternOpacity", nil, 0, 40, 1,
        function() return Disabled() or self:GetGroupFrames().patternEnabled ~= true end)
    Slider("Pattern Scale", "patternScale", nil, 24, 256, 4,
        function() return Disabled() or self:GetGroupFrames().patternEnabled ~= true end)
    Slider("Black Border Width", "borderWidth", nil, 0, 8, 1)
    Slider("Inner Shadow", "innerShadowAlpha", nil, 0, 100, 1)
    Slider("Outer Shadow", "outerShadowAlpha", nil, 0, 100, 1)
    Dropdown("Text Font", "textFontKey", nil,
        { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
        { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" })
    Slider("Name Size", "nameTextSize", nil, 10, 26, 1)
    Slider("Health Text Size", "healthTextSize", nil, 10, 26, 1)
    Dropdown("Text Outline", "textOutline", nil,
        { "None", "Soft Thin", "Soft Thick", "Thick Outline" },
        { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" })
    Slider("Text Opacity", "textOpacity", nil, 10, 100, 1)
    Slider("Health Text Inset", "textInset", "Move side-aligned health text away from the bar edge.", 0, 24, 1)

    Header("Effects & Shields")
    Checkbox("Show Shields", "showShields", nil)
    Slider("Shield Fill Opacity", "shieldFillOpacity", nil, 0, 100, 1,
        function() return Disabled() or self:GetGroupFrames().showShields == false end)
    ColorPicker("Shield Fill Color", "shieldFillColor", nil,
        function() return Disabled() or self:GetGroupFrames().showShields == false end)
    Checkbox("Shield Glow", "shieldGlowEnabled", nil,
        function() return Disabled() or self:GetGroupFrames().showShields == false end)
    Slider("Shield Glow Opacity", "shieldGlowOpacity", nil, 0, 100, 1,
        function()
            return Disabled() or self:GetGroupFrames().showShields == false or self:GetGroupFrames().shieldGlowEnabled == false
        end)
    ColorPicker("Shield Glow Color", "shieldGlowColor", nil,
        function()
            return Disabled() or self:GetGroupFrames().showShields == false or self:GetGroupFrames().shieldGlowEnabled == false
        end)
    Checkbox("Loss Trailing", "lossTrailEnabled", "Leave a short-lived highlight behind the health bar when health drops.")
    Checkbox("Bar Feedback", "feedbackEnabled", "Show a low-health glow and shield pulses.")
    Slider("Feedback Intensity", "feedbackIntensity", nil, 0, 140, 5,
        function() return Disabled() or self:GetGroupFrames().feedbackEnabled ~= true end)
    Checkbox("Low Health Glow", "lowHealthGlowEnabled", "Glow around the bar below 35% health.",
        function() return Disabled() or self:GetGroupFrames().feedbackEnabled ~= true end)
    Checkbox("Recovery Rhythm (Approx.)", "showRecoveryRhythm", "Sweep a faint glint across the bars every two seconds. It's only decorative because ESO doesn't share the exact server timing.")
    Checkbox("Death Animation", "showDeathAnimation", "Flash and dip the bar when someone dies, then show a death icon.")
    Add(
    {
        type = "button",
        name = "Replay Preview Effects",
        func = function() self:ReplayGroupFramesPreviewEffects() end,
        disabled = Disabled,
        width = "half",
    })

    Header("Level Text")
    Checkbox("Show Level", "showLevel", "Show each character's level or earned Champion Points.")
    Slider("Level Text Size", "levelTextSize", "Set the level and Champion Point text size in pixels.", 10, 17, 1,
        function() return Disabled() or self:GetGroupFrames().showLevel == false end)
    Checkbox("Level Style", "showLevelStyle", "Add tier colors and special effects at CP 1800+. Turn it off for plain white level text.",
        function() return Disabled() or self:GetGroupFrames().showLevel == false end)

    return controls
end

function Settings:BuildTargetFrameOptions()
    local controls = {}
    local function Add(control) controls[#controls + 1] = control end
    local function Disabled() return not self:IsTargetFrameEnabled() end
    local function Header(name) Add({ type = "header", name = name }) end
    local function Description(text) Add({ type = "description", text = text }) end
    local function Checkbox(name, key, tooltip, disabled)
        Add(
        {
            type = "checkbox",
            name = name,
            tooltip = tooltip,
            getFunc = function() return self:GetTargetFrame()[key] end,
            setFunc = function(value) self:SetTargetFrameValue(key, value) end,
            disabled = disabled or Disabled,
            default = TARGET_FRAME_DEFAULTS[key],
        })
    end
    local function Slider(name, key, tooltip, minimum, maximum, step, disabled)
        Add(
        {
            type = "slider",
            name = name,
            tooltip = tooltip,
            min = minimum,
            max = maximum,
            step = step,
            getFunc = function() return self:GetTargetFrame()[key] end,
            setFunc = function(value) self:SetTargetFrameValue(key, value) end,
            disabled = disabled or Disabled,
            default = TARGET_FRAME_DEFAULTS[key],
        })
    end
    local function Dropdown(name, key, tooltip, choices, values, disabled)
        Add(
        {
            type = "dropdown",
            name = name,
            tooltip = tooltip,
            choices = choices,
            choicesValues = values,
            getFunc = function() return self:GetTargetFrame()[key] end,
            setFunc = function(value) self:SetTargetFrameValue(key, value) end,
            disabled = disabled or Disabled,
            default = TARGET_FRAME_DEFAULTS[key],
        })
    end
    local function ColorPicker(name, key, tooltip, disabled)
        Add(
        {
            type = "colorpicker",
            name = name,
            tooltip = tooltip,
            getFunc = function()
                local color = self:GetTargetFrameColor(key)
                return color.r, color.g, color.b, 1
            end,
            setFunc = function(r, g, b) self:SetTargetFrameColor(key, r, g, b) end,
            disabled = disabled or Disabled,
            default = function()
                local color = TARGET_FRAME_DEFAULTS[key]
                return color.r, color.g, color.b, 1
            end,
        })
    end
    local function ClassColorPicker(name, classId)
        Add(
        {
            type = "colorpicker",
            name = name,
            getFunc = function()
                local color = self:GetTargetFrameClassColor(classId)
                return color.r, color.g, color.b, 1
            end,
            setFunc = function(r, g, b) self:SetTargetFrameClassColor(classId, r, g, b) end,
            disabled = function()
                return Disabled() or self:GetTargetFrame().playerColorMode ~= "class"
            end,
            default = function()
                local color = TARGET_FRAME_DEFAULTS.classColors[classId]
                return color.r, color.g, color.b, 1
            end,
        })
    end

    Header("General & Position")
    Add(
    {
        type = "checkbox",
        name = "Enable Target Frame",
        tooltip = "Replace ESO's reticle target frame with Nirnsteel's compact target frame.",
        getFunc = function() return self:IsTargetFrameEnabled() end,
        setFunc = function(value) self:SetTargetFrameEnabled(value) end,
        default = TARGET_FRAME_DEFAULTS.enabled,
    })
    Add(
    {
        type = "checkbox",
        name = "Unlock Position",
        tooltip = "Show a drag handle. The position is saved for this server.",
        getFunc = function() return self:IsTargetFrameUnlocked() end,
        setFunc = function(value) self:SetTargetFrameUnlocked(value) end,
        disabled = Disabled,
        default = TARGET_FRAME_DEFAULTS.unlocked,
    })
    Add(
    {
        type = "button",
        name = "Reset Position",
        tooltip = "Move the Target Frame back to its default top-center position.",
        func = function() self:ResetActiveTargetFramePosition() end,
        disabled = Disabled,
        width = "half",
    })
    Slider("Scale", "scale", nil, 70, 160, 1)
    Slider("Bar Width", "width", nil, 180, 700, 5)
    Slider("Bar Height", "barHeight", nil, 10, 48, 1)
    Slider("Opacity", "opacity", nil, 10, 100, 1)

    Header("Target Information")
    Checkbox("Show Class Icon", "showClass", "Show the player's class icon beside their name.")
    Checkbox("Show Veterancy Icon", "showVeterancyIcon",
        "Show the active Veterancy rank icon for players, or their alliance-colored Alliance War rank when Veterancy is unavailable.")
    Description("Class and Veterancy icons only appear for player targets. Target markers are always retained.")

    Header("Execute Indicator")
    Checkbox("Show Execute Icon", "showExecuteIcon", "Show a finisher indicator inside the bar for living, attackable targets at execute health.")
    Dropdown("Execute Icon", "executeIconStyle", "Choose the symbol used for the execute indicator.",
        { "White Skull", "Champion", "Dark Anchors", "Alliance General", "Alliance Legate", "Retrait", "Scoring", "Death Down", "Death Over" },
        { "whiteSkull", "champion", "darkAnchors", "avaGeneral", "avaLegate", "retrait", "scoring", "deathDown", "deathOver" },
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)
    Slider("Icon Scale", "executeIconScale", "Scale the execute icon independently from the target frame.", 50, 200, 5,
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)
    Checkbox("Blink Animation", "executeBlinkEnabled", "Continuously pulse the execute icon while it is visible.",
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)
    Slider("Execute Threshold", "executeThreshold", "Show the icon at or below this health percentage.", 18, 33, 1,
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)
    Dropdown("Execute Position", "executePosition", "Left and right reserve room for the adjacent health label.",
        { "Left", "Center", "Right" }, { "left", "center", "right" },
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)

    Header("Target Colors")
    Dropdown("Non-Player Target Color", "npcColorMode",
        "Static Red uses your chosen color. Threat / Reaction uses ESO's civilian, allied, neutral, and hostile disposition colors.",
        { "Static Red", "Threat / Reaction" }, { "static", "reaction" })
    Dropdown("Player Target Color", "playerColorMode",
        "Choose a static color, class color, or a health gradient from white to deep red.",
        { "Static Red", "Class Color", "Health Percentage" }, { "static", "class", "health" })
    ColorPicker("Static Target Color", "staticColor", nil, function()
        local settings = self:GetTargetFrame()
        return Disabled() or (settings.npcColorMode ~= "static" and settings.playerColorMode ~= "static")
    end)
    ColorPicker("Full Health Color", "fullHealthColor", nil, function()
        return Disabled() or self:GetTargetFrame().playerColorMode ~= "health"
    end)
    ColorPicker("Low Health Color", "lowHealthColor", nil, function()
        return Disabled() or self:GetTargetFrame().playerColorMode ~= "health"
    end)
    ClassColorPicker("Dragonknight Color", 1)
    ClassColorPicker("Sorcerer Color", 2)
    ClassColorPicker("Nightblade Color", 3)
    ClassColorPicker("Warden Color", 4)
    ClassColorPicker("Necromancer Color", 5)
    ClassColorPicker("Templar Color", 6)
    ClassColorPicker("Arcanist Color", 117)
    ColorPicker("Unknown Class Color", "unknownClassColor", nil, function()
        return Disabled() or self:GetTargetFrame().playerColorMode ~= "class"
    end)

    Header("Bar Appearance")
    Checkbox("NirnSteel Iron Borders", "rpgBorder")
    Checkbox("Gloss", "glossEnabled")
    Checkbox("Fill Pattern", "barPatternEnabled")
    Dropdown("Fill Pattern Type", "barPatternKey", nil,
        { "ZigZag", "Smoke", "Still Water", "Stone", "Dirt", "Lava", "Rock Lava", "Lava Wave", "Molten" },
        { "ZigZag", "smoke", "stillwater", "Stone", "Dirt", "Lava", "RockLava", "LavaWave", "Molten" },
        function() return Disabled() or self:GetTargetFrame().barPatternEnabled ~= true end)
    Slider("Fill Pattern Opacity", "barPatternOpacity", nil, 0, 40, 1,
        function() return Disabled() or self:GetTargetFrame().barPatternEnabled ~= true end)
    Slider("Fill Pattern Scale", "barPatternScale", nil, 24, 512, 4,
        function() return Disabled() or self:GetTargetFrame().barPatternEnabled ~= true end)
    Slider("Black Border Width", "borderWidth", nil, 0, 8, 1)
    Slider("Inner Shadow", "innerShadowAlpha", nil, 0, 100, 1)
    Slider("Outer Shadow", "outerShadowAlpha", nil, 0, 100, 1)

    Header("Text")
    Dropdown("Font", "textFontKey", nil,
        { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
        { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" })
    Slider("Name Size", "nameTextSize", nil, 10, 36, 1)
    Slider("Health Text Size", "healthTextSize", nil, 8, 32, 1)
    Dropdown("Outline", "textOutline", nil,
        { "None", "Soft Thin", "Soft Thick", "Thick Outline" },
        { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" })
    Slider("Text Opacity", "textOpacity", nil, 10, 100, 1)
    ColorPicker("Text Color", "textColor")
    Slider("Health Text Inset", "textInset", "Move side labels away from the bar edge.", 0, 28, 1)
    Slider("Health Text Vertical Offset", "textVerticalOffset", nil, -8, 8, 1)
    Dropdown("Health Format", "healthTextFormat", nil,
        { "None", "Number", "Percent", "Number + Percent" },
        { "none", "number", "percent", "numberAndPercent" })
    Dropdown("Health Text Position", "healthTextPosition",
        "Applies to every health format. Opposite Sides places a number on the left and a percent on the right; single values use their natural side.",
        { "Left", "Center", "Right", "Opposite Sides" }, { "left", "center", "right", "sides" }, Disabled)

    Header("Shields")
    Checkbox("Shield Overlay", "shieldOverlayEnabled")
    Slider("Shield Fill Opacity", "shieldFillOpacity", nil, 0, 100, 1,
        function() return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false end)
    ColorPicker("Shield Fill Color", "shieldFillColor", nil,
        function() return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false end)
    Checkbox("Shield Glow", "shieldGlowEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false end)
    Slider("Shield Glow Opacity", "shieldGlowOpacity", nil, 0, 100, 1,
        function()
            return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false
                or self:GetTargetFrame().shieldGlowEnabled == false
        end)
    ColorPicker("Shield Glow Color", "shieldGlowColor", nil,
        function()
            return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false
                or self:GetTargetFrame().shieldGlowEnabled == false
        end)
    Dropdown("Shield Text Mode", "shieldTextMode", nil,
        { "Off", "Shield Only", "Health + Shield" }, { "off", "shieldOnly", "healthAndShield" })

    Header("Feedback Effects")
    Checkbox("Bar Feedback", "feedbackEnabled")
    Slider("Feedback Intensity", "feedbackIntensity", nil, 0, 140, 5,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox("Damage Pulse", "spendPulseEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox("Heal Pulse", "gainPulseEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox("Full Health Pulse", "fullResourcePulseEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox("Shield Pulse", "shieldPulseEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox("Loss Trail", "lossTrailEnabled", "Leave a short-lived highlight behind the bar when health drops.")
    Checkbox("Low Health Glow", "lowResourceGlowEnabled", "Glow around the target bar below 35% health.",
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Add(
    {
        type = "button",
        name = "Replay Preview Effects",
        func = function() self:ReplayTargetFramePreviewEffects() end,
        disabled = Disabled,
        width = "half",
    })

    Header("Boss Appearance")
    Checkbox("Boss decoration", "bossDecoration", "Add silver steel end caps and a winged skull crest to recognized boss targets.")
    Add(
    {
        type = "checkbox",
        name = "Preview boss",
        tooltip = "Show a boss while this settings section is open. This preview is not saved.",
        getFunc = function() return Nirnsteel_UI.TargetFrame and Nirnsteel_UI.TargetFrame.previewBoss == true end,
        setFunc = function(value)
            if Nirnsteel_UI.TargetFrame then Nirnsteel_UI.TargetFrame:SetBossPreview(value) end
        end,
        disabled = Disabled,
        width = "half",
    })

    Header("Level Text")
    Checkbox("Show Level", "showLevel", "Show the target's level or effective Champion Points.")
    Checkbox("Level Style", "showLevelStyle", "Add tier colors and special effects at CP 1800+. Turn it off for plain white level text.",
        function() return Disabled() or self:GetTargetFrame().showLevel == false end)

    return controls
end

function Settings:BuildMinimapControls()
    local controls = {}
    local function Add(kind, name, key, extra)
        local option = extra or {}
        option.type, option.name = kind, name
        option.getFunc = function() return self:GetMinimap()[key] end
        option.setFunc = function(value) self:SetMinimapValue(key, value) end
        option.default = MINIMAP_DEFAULTS[key]
        if key ~= "enabled" then
            local extraDisabled = option.disabled
            option.disabled = function()
                return not self:GetMinimap().enabled or (extraDisabled and extraDisabled())
            end
        end
        controls[#controls + 1] = option
    end
    local function Header(name) controls[#controls + 1] = { type = "header", name = name } end
    local function Slider(name, key, low, high, step, extra)
        local option = extra or {}
        option.min, option.max, option.step = low, high, step or 1
        if step and step < 1 then option.decimals = 2 end
        Add("slider", name, key, option)
    end
    Add("checkbox", "Enable Minimap", "enabled")
    Add("checkbox", "Unlock Position", "unlocked", {
        tooltip = "With the cursor visible, drag anywhere on the minimap or its header. Position is saved on this server. Waypoint placement is disabled while unlocked.",
    })
    Slider("Quest Tracker Vertical Offset", "questTrackerOffset", 0, 600, 5, {
        tooltip = "Move the native quest tracker down by this many UI pixels to make room for the minimap at the top right. Zero restores its normal position. The offset is removed while Minimap is disabled.",
    })
    Add("dropdown", "Shape", "shape", { choices = { "Circular", "Rectangular" }, choicesValues = { "circle", "rectangle" } })
    Add("dropdown", "Orientation", "orientation", { choices = { "North Up", "Rotating (Camera Heading)" }, choicesValues = { "north", "rotating" } })
    Header("Dimensions")
    Slider("Circle Diameter", "diameter", 180, 500, 10, { disabled = function() return self:GetMinimap().shape ~= "circle" end })
    Slider("Rectangle Width", "width", 220, 600, 10, { disabled = function() return self:GetMinimap().shape ~= "rectangle" end })
    Slider("Rectangle Height", "height", 160, 500, 10, { disabled = function() return self:GetMinimap().shape ~= "rectangle" end })
    Header("Appearance")
    Slider("Map Opacity", "mapOpacity", 0, 100)
    Slider("Frame Opacity", "frameOpacity", 0, 100)
    Slider("Border Thickness", "borderThickness", 1, 6)
    for _, entry in ipairs({ { "Border Color", "borderColor" }, { "Accent Color", "accentColor" } }) do
        local name, key = entry[1], entry[2]
        controls[#controls + 1] = {
            type = "colorpicker", name = name,
            getFunc = function() local c = self:GetMinimap()[key]; return c.r, c.g, c.b, 1 end,
            setFunc = function(r, g, b) self:SetMinimapValue(key, { r = r, g = g, b = b }) end,
            default = { r = MINIMAP_DEFAULTS[key].r, g = MINIMAP_DEFAULTS[key].g, b = MINIMAP_DEFAULTS[key].b, a = 1 },
            disabled = function() return not self:GetMinimap().enabled end,
        }
    end
    Add("checkbox", "Frame Shadow", "shadow")
    Add("checkbox", "Location Name", "showLocation")
    Add("dropdown", "Location Name Position", "locationNamePosition", {
        choices = { "Top", "Bottom" }, choicesValues = { "top", "bottom" },
        disabled = function() return not self:GetMinimap().showLocation end,
    })
    Slider("Zone Text Size", "zoneTextSize", 10, 32, 1, {
        tooltip = "Set the minimap zone name text size in pixels.",
    })
    Add("checkbox", "Cardinal Directions", "showCardinals")
    Add("checkbox", "Player Coordinates", "showCoordinates", { tooltip = "Show normalized map coordinates as percentages, not world distances." })
    Header("Navigation")
    Slider("Zoom", "zoom", 1, 12, 0.25)
    Slider("Marker Scale", "markerScale", 75, 200, 5)
    Slider("Player Arrow Scale", "playerScale", 75, 175, 5)
    Add("checkbox", "Group Members", "showGroup")
    Add("checkbox", "Quest Objectives", "showQuests")
    Add("dropdown", "Quest Filter", "questMode", {
        choices = { "Tracked Only", "All Journal Quests" }, choicesValues = { "tracked", "all" },
        disabled = function() return not self:GetMinimap().showQuests end,
    })
    Add("checkbox", "Discovered Wayshrines", "showWayshrines")
    Add("checkbox", "Locations", "showLocations")
    Add("checkbox", "Personal Waypoint", "showWaypoint")
    Add("checkbox", "Waypoint Edge Indicator", "waypointEdge", { disabled = function() return not self:GetMinimap().showWaypoint end })
    Header("Visibility and Interaction")
    Add("dropdown", "During Combat", "combatBehavior", { choices = { "Show", "Dim", "Hide" }, choicesValues = { "show", "dim", "hide" } })
    Slider("Combat Dim Opacity", "combatOpacity", 0, 100, 1, { disabled = function() return self:GetMinimap().combatBehavior ~= "dim" end })
    Add("checkbox", "Click Through", "clickThrough", { tooltip = "Make the map passive while locked. Unlock Position and Preview remain available here." })
    Add("checkbox", "Mouse Wheel Zoom", "wheelZoom", { disabled = function() return self:GetMinimap().clickThrough end })
    Add("checkbox", "Marker Tooltips", "tooltips", { disabled = function() return self:GetMinimap().clickThrough end })
    controls[#controls + 1] = { type = "description", text = "Assign Minimap: Place Waypoint at Cursor under Controls > Keybindings > Nirnsteel UI (unbound by default). With the cursor over the map, press your assigned key to place a waypoint; right click its marker to remove it. Hover for zoom and world-map buttons. Gamepad navigation uses the full world map." }
    for _, entry in ipairs({ { "Preview", "Preview" }, { "Reset Position", "ResetPosition" } }) do
        local name, method = entry[1], entry[2]
        controls[#controls + 1] = {
            type = "button", name = name,
            func = function() if Nirnsteel_UI.Minimap then Nirnsteel_UI.Minimap[method](Nirnsteel_UI.Minimap) end end,
            disabled = function() return not self:GetMinimap().enabled end,
        }
    end
    controls[#controls + 1] = { type = "button", name = "Reset Minimap Settings", func = function() self:ResetMinimapSettings() end }
    return controls
end

function Settings:RegisterAddonMenu()
    local LAM = LibAddonMenu2
    if not LAM and LibStub then
        local foundLib, lib = pcall(LibStub, "LibAddonMenu-2.0")
        if foundLib then
            LAM = lib
        end
    end

    if not LAM then
        d("Nirnsteel UI: LibAddonMenu-2.0 not found.")
        return
    end

    local panelName = "Nirnsteel_UI_Settings"
    local panelData =
    {
        type = "panel",
        name = ADDON_DISPLAY_NAME,
        displayName = ADDON_DISPLAY_NAME,
        author = "Wrynch",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local options =
    {
        {
            type = "description",
            text = "Most settings are account wide",
        },
        {
            type = "submenu",
            name = "Quest Tracker",
            controls = self:GetQuestTrackerOptions(),
        },
        {
            type = "submenu",
            name = "Werewolf Rage",
            controls = self:GetWerewolfRageOptions(),
        },
        {
            type = "submenu",
            name = "Achievement Alert",
            controls = self:GetAchievementAlertOptions(),
        },
        {
            type = "submenu",
            name = "Misc",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Immersive Teleport",
                    tooltip = "Hide the UI and use the character panel camera with Left Composition during teleport animations. Restore the normal camera and UI when travel completes or is canceled.",
                    getFunc = function() return self:IsImmersiveTeleportEnabled() end,
                    setFunc = function(value) self:SetImmersiveTeleportEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.immersiveTeleport.enabled,
                },
                { type = "header", name = "Synergy Alert" },
                {
                    type = "checkbox",
                    name = "Enable Synergy Alert",
                    tooltip = "Show a large animated synergy icon, with a centered binding and name row underneath. The original sound and activation binding are preserved.",
                    getFunc = function() return self:GetSynergyAlert().enabled end,
                    setFunc = function(value) self:SetSynergyAlertValue("enabled", value) end,
                    default = ACCOUNT_DEFAULTS.modules.synergyAlert.enabled,
                },
                {
                    type = "checkbox",
                    name = "Unlock Position",
                    tooltip = "Drag the sample synergy emblem while settings are open. Its position is saved on this server.",
                    getFunc = function() return self:GetSynergyAlert().unlocked end,
                    setFunc = function(value) self:SetSynergyAlertValue("unlocked", value) end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    default = ACCOUNT_DEFAULTS.modules.synergyAlert.unlocked,
                },
                {
                    type = "slider",
                    name = "Scale",
                    min = 70,
                    max = 160,
                    step = 1,
                    getFunc = function() return self:GetSynergyAlert().scale end,
                    setFunc = function(value) self:SetSynergyAlertValue("scale", value) end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    default = ACCOUNT_DEFAULTS.modules.synergyAlert.scale,
                },
                {
                    type = "slider",
                    name = "Opacity",
                    min = 20,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetSynergyAlert().opacity end,
                    setFunc = function(value) self:SetSynergyAlertValue("opacity", value) end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    default = ACCOUNT_DEFAULTS.modules.synergyAlert.opacity,
                },
                {
                    type = "slider",
                    name = "Animation Intensity",
                    tooltip = "Adjust the soft glow pulse. The icon fades in without resizing or bouncing. Set to zero for a static prompt.",
                    min = 0,
                    max = 160,
                    step = 1,
                    getFunc = function() return self:GetSynergyAlert().animationIntensity end,
                    setFunc = function(value) self:SetSynergyAlertValue("animationIntensity", value) end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    default = ACCOUNT_DEFAULTS.modules.synergyAlert.animationIntensity,
                },
                {
                    type = "button",
                    name = "Preview",
                    tooltip = "Show a silent sample for four seconds, or until locked while positioning.",
                    func = function()
                        if Nirnsteel_UI.SynergyAlert then Nirnsteel_UI.SynergyAlert:Preview() end
                    end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    width = "half",
                },
                {
                    type = "button",
                    name = "Reset Position",
                    tooltip = "Return the emblem to ESO's default synergy location for the current input mode.",
                    func = function() self:ResetSynergyAlertPosition() end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = "Loot History",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Enable Loot History",
                    tooltip = "Use Nirnsteel's loot history instead of ESO's.",
                    getFunc = function() return self:IsLootHistoryEnabled() end,
                    setFunc = function(value) self:SetLootHistoryEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.lootHistory.enabled,
                },
                {
                    type = "checkbox",
                    name = "Legacy Style",
                    tooltip = "Use Nirnsteel's original loot history appearance, before the ornamental shield design. Applies to new loot entries.",
                    getFunc = function() return self:GetLootHistory().legacyStyle == true end,
                    setFunc = function(value) self:SetLootHistoryValue("legacyStyle", value) end,
                    disabled = function() return not self:IsLootHistoryEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.lootHistory.legacyStyle,
                },
                {
                    type = "checkbox",
                    name = "Mirror Layout",
                    tooltip = "Place item icons on the right and item names on the left. Use this layout when moving Loot History to the left side of the screen with Edit HUD.",
                    getFunc = function() return self:GetLootHistory().mirrorLayout == true end,
                    setFunc = function(value) self:SetLootHistoryValue("mirrorLayout", value) end,
                    disabled = function() return not self:IsLootHistoryEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.lootHistory.mirrorLayout,
                },
                {
                    type = "checkbox",
                    name = "Unlock Loot Frame",
                    tooltip = "Show a drag handle for the loot frame. Its position is saved on this server.",
                    getFunc = function() return self:IsLootHistoryUnlocked() end,
                    setFunc = function(value) self:SetLootHistoryUnlocked(value) end,
                    disabled = function() return not self:IsLootHistoryEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.lootHistory.unlocked,
                },
                {
                    type = "slider",
                    name = "Scale",
                    min = 60,
                    max = 180,
                    step = 1,
                    getFunc = function() return self:GetLootHistory().scale end,
                    setFunc = function(value) self:SetLootHistoryValue("scale", value) end,
                    disabled = function() return not self:IsLootHistoryEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.lootHistory.scale,
                },
                {
                    type = "checkbox",
                    name = "Enable Sounds",
                    tooltip = "Play sounds for loot, plus a special fanfare for legendary drops.",
                    getFunc = function() return self:AreLootHistorySoundsEnabled() end,
                    setFunc = function(value) self:SetLootHistorySoundsEnabled(value) end,
                    disabled = function() return not self:IsLootHistoryEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.lootHistory.soundsEnabled,
                },
                {
                    type = "dropdown",
                    name = "Regular Loot Sound",
                    choices =
                    {
                        "Soft Chime",
                        "Clean Click",
                        "Card Tap",
                        "Reward Drop",
                    },
                    getFunc = function() return GetSoundChoiceLabel(self:GetLootHistory().regularSoundKey) end,
                    setFunc = function(value)
                        self:SetLootHistoryValue("regularSoundKey", value)
                        self:PreviewLootHistoryRegularSound()
                    end,
                    disabled = function() return not self:IsLootHistoryEnabled() or not self:AreLootHistorySoundsEnabled() end,
                    default = GetSoundChoiceLabel(ACCOUNT_DEFAULTS.modules.lootHistory.regularSoundKey),
                },
                {
                    type = "checkbox",
                    name = "Hide Experience Gains",
                    getFunc = function() return self:ShouldFilterLootHistoryExperience() end,
                    setFunc = function(value) self:SetLootHistoryFilterExperience(value) end,
                    disabled = function() return not self:IsLootHistoryEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.lootHistory.filterExperience,
                },
            },
        },
        {
            type = "submenu",
            name = "Damage Numbers",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Enable Floating Damage Numbers",
                    tooltip = "Show Nirnsteel's damage numbers near the middle of your screen.",
                    getFunc = function() return self:IsDamageNumbersEnabled() end,
                    setFunc = function(value) self:SetDamageNumbersEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.enabled,
                },
                {
                    type = "checkbox",
                    name = "Unlock Floating Damage Origin",
                    tooltip = "Show a drag handle for where damage numbers pop up. Its position is saved on this server.",
                    getFunc = function() return self:IsDamageNumbersUnlocked() end,
                    setFunc = function(value) self:SetDamageNumbersUnlocked(value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.unlocked,
                },
                {
                    type = "checkbox",
                    name = "Hide Default Damage Numbers",
                    getFunc = function() return self:ShouldHideDefaultDamageNumbers() end,
                    setFunc = function(value) self:SetDamageNumbersHideDefault(value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.hideDefaultDamage,
                },
                {
                    type = "checkbox",
                    name = "Critical Hit Sound",
                    getFunc = function() return self:AreDamageNumberCritSoundsEnabled() end,
                    setFunc = function(value) self:SetDamageNumberCritSoundsEnabled(value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.critSoundEnabled,
                },
                {
                    type = "dropdown",
                    name = "Damage Number Font",
                    choices =
                    {
                        "Antique",
                        "Handwritten",
                        "Stone Tablet",
                        "Prose Antique",
                        "Trajan",
                        "Univers 57",
                        "Univers 67",
                        "Univers Cyrillic",
                        "Univers Cyrillic Bold",
                        "Futura Light",
                        "Futura Medium",
                        "Futura Bold",
                        "ESO Japanese",
                        "ESO Japanese Medium",
                        "Chinese Medium",
                        "Gamepad Bold",
                        "Gamepad Medium",
                        "Gamepad Light",
                        "Gamepad Number",
                        "Keyboard Bold",
                        "Keyboard Medium",
                        "Chat",
                    },
                    choicesValues =
                    {
                        "antique",
                        "handwritten",
                        "stoneTablet",
                        "proseAntique",
                        "trajan",
                        "univers57",
                        "univers67",
                        "universCyrillic",
                        "universCyrillicBold",
                        "futuraLight",
                        "futuraMedium",
                        "futuraBold",
                        "esoJapanese",
                        "esoJapaneseMedium",
                        "chineseMedium",
                        "gamepadBold",
                        "gamepadMedium",
                        "gamepadLight",
                        "gamepadNumber",
                        "keyboardBold",
                        "keyboardMedium",
                        "chat",
                    },
                    getFunc = function() return self:GetDamageNumbers().fontKey end,
                    setFunc = function(value) self:SetDamageNumberValue("fontKey", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.fontKey,
                },
                {
                    type = "dropdown",
                    name = "Text Effect",
                    choices =
                    {
                        "None",
                        "Shadow",
                        "Outline",
                    },
                    choicesValues =
                    {
                        "none",
                        "shadow",
                        "outline",
                    },
                    getFunc = function() return self:GetDamageNumbers().textEffect end,
                    setFunc = function(value) self:SetDamageNumberValue("textEffect", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.textEffect,
                },
                {
                    type = "dropdown",
                    name = "Critical Sound",
                    choices =
                    {
                        "Deep Hit",
                        "Sharp Hit",
                        "Heavy Clang",
                        "Muted Tick",
                        "Reward Ping"
                    },
                    getFunc = function() return GetSoundChoiceLabel(self:GetDamageNumbers().critSoundKey) end,
                    setFunc = function(value)
                        self:SetDamageNumberValue("critSoundKey", value)
                        self:PreviewDamageNumberCritSound()
                    end,
                    disabled = function() return not self:IsDamageNumbersEnabled() or not self:AreDamageNumberCritSoundsEnabled() end,
                    default = GetSoundChoiceLabel(ACCOUNT_DEFAULTS.modules.damageNumbers.critSoundKey),
                },
                {
                    type = "slider",
                    name = "Normal Font Size",
                    min = 12,
                    max = 96,
                    step = 1,
                    getFunc = function() return self:GetDamageNumbers().normalFontSize end,
                    setFunc = function(value) self:SetDamageNumberValue("normalFontSize", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.normalFontSize,
                },
                {
                    type = "slider",
                    name = "Critical Font Size",
                    min = 24,
                    max = 128,
                    step = 1,
                    getFunc = function() return self:GetDamageNumbers().critFontSize end,
                    setFunc = function(value) self:SetDamageNumberValue("critFontSize", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.critFontSize,
                },
                {
                    type = "slider",
                    name = "Duration",
                    tooltip = "Set how long damage numbers stay visible, in milliseconds.",
                    min = 450,
                    max = 1800,
                    step = 25,
                    getFunc = function() return self:GetDamageNumbers().durationMS end,
                    setFunc = function(value) self:SetDamageNumberValue("durationMS", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.durationMS,
                },
                {
                    type = "slider",
                    name = "Spread",
                    tooltip = "Set how far new damage numbers spread out.",
                    min = 40,
                    max = 280,
                    step = 5,
                    getFunc = function() return self:GetDamageNumbers().spread end,
                    setFunc = function(value) self:SetDamageNumberValue("spread", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.spread,
                },
                {
                    type = "slider",
                    name = "Drift",
                    tooltip = "Set how far damage numbers drift after popping up.",
                    min = 0,
                    max = 160,
                    step = 5,
                    getFunc = function() return self:GetDamageNumbers().drift end,
                    setFunc = function(value) self:SetDamageNumberValue("drift", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.drift,
                },
                {
                    type = "slider",
                    name = "Big Hit Threshold",
                    tooltip = "Hits this big or higher drift less, so they feel heavier.",
                    min = 1000,
                    max = 200000,
                    step = 1000,
                    getFunc = function() return self:GetDamageNumbers().bigHitThreshold end,
                    setFunc = function(value) self:SetDamageNumberValue("bigHitThreshold", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.bigHitThreshold,
                },
                {
                    type = "slider",
                    name = "Maximum Active Numbers",
                    tooltip = "Limit how many damage numbers can be on screen. New hits replace the oldest ones.",
                    min = 8,
                    max = 80,
                    step = 1,
                    getFunc = function() return self:GetDamageNumbers().maxActive end,
                    setFunc = function(value) self:SetDamageNumberValue("maxActive", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.maxActive,
                },
                {
                    type = "slider",
                    name = "Critical Sound Throttle",
                    tooltip = "Set the shortest gap between critical-hit sounds, in milliseconds.",
                    min = 0,
                    max = 800,
                    step = 10,
                    getFunc = function() return self:GetDamageNumbers().soundThrottleMS end,
                    setFunc = function(value) self:SetDamageNumberValue("soundThrottleMS", value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() or not self:AreDamageNumberCritSoundsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.soundThrottleMS,
                },
                {
                    type = "header",
                    name = "Damage Done Minigame",
                },
                {
                    type = "description",
                    text = "Chain player and pet damage into a gold arcade score. Keep the timer alive, rescue a draining chain, and finish with your peak score.",
                },
                {
                    type = "checkbox",
                    name = "Enable Damage Done Minigame",
                    tooltip = "Show a separate accumulated damage score. This can run without floating damage numbers.",
                    getFunc = function() return self:IsDamageDoneMinigameEnabled() end,
                    setFunc = function(value) self:SetDamageDoneMinigameEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.enabled,
                },
                {
                    type = "checkbox",
                    name = "Unlock Damage Done Minigame",
                    tooltip = "Show a drag handle for the minigame. Its position is saved on this server.",
                    getFunc = function() return self:IsDamageDoneMinigameUnlocked() end,
                    setFunc = function(value) self:SetDamageDoneMinigameUnlocked(value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.unlocked,
                },
                {
                    type = "checkbox",
                    name = "Minigame Sounds",
                    tooltip = "Play throttled rune ticks, heavier critical impacts, and milestone sounds.",
                    getFunc = function() return self:AreDamageDoneMinigameSoundsEnabled() end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("soundEnabled", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.soundEnabled,
                },
                {
                    type = "checkbox",
                    name = "Tier Progression Sounds",
                    tooltip = "Play a different sound when each new tier is reached, building to a final victory sound at the cap. Applies to Damage Done and DPS. Turn off to keep only normal and critical hit sounds. Preview All Tiers demonstrates the progression.",
                    getFunc = function() return self:GetDamageDoneMinigame().tierSoundsEnabled end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("tierSoundsEnabled", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() or not self:AreDamageDoneMinigameSoundsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.tierSoundsEnabled,
                },
                {
                    type = "checkbox",
                    name = "Face Right",
                    tooltip = "Reverse the number's tilt, skew, and decorative accents so it faces right.",
                    getFunc = function() return self:GetDamageDoneMinigame().faceRight end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("faceRight", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.faceRight,
                },
                {
                    type = "dropdown",
                    name = "Display Mode",
                    tooltip = "Show the current fast-draining damage total, or average damage per second across the active combo streak.",
                    choices = { "Damage Done", "DPS" },
                    choicesValues = { "damageDone", "dps" },
                    getFunc = function() return self:GetDamageDoneMinigame().displayMode end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("displayMode", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.displayMode,
                },
                {
                    type = "slider",
                    name = "Combo Grace Period (ms)",
                    tooltip = "Time after the last hit before the score starts draining over 1.5 seconds. The default allows a normal one-second attack rhythm.",
                    min = 500,
                    max = 3000,
                    step = 50,
                    getFunc = function() return self:GetDamageDoneMinigame().graceMS end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("graceMS", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.graceMS,
                },
                {
                    type = "slider",
                    name = "Impact Animation Intensity",
                    tooltip = "Adjust punch, recoil, echoes, sparks, and flashes. Zero keeps the score and timer with simple fades.",
                    min = 0,
                    max = 150,
                    step = 5,
                    getFunc = function() return self:GetDamageDoneMinigame().animationIntensity end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("animationIntensity", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.animationIntensity,
                },
                {
                    type = "checkbox",
                    name = "Show Combo Timer",
                    tooltip = "Drain the gold in the crest's segmented metal wings to show remaining chain time. Turn off to keep the wings filled.",
                    getFunc = function() return self:GetDamageDoneMinigame().showTimer end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("showTimer", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.showTimer,
                },
                {
                    type = "checkbox",
                    name = "Show Damage Done / DPS Label",
                    tooltip = "Show the Damage Done or DPS text beneath the score, independently of the hit count and peak label.",
                    getFunc = function() return self:GetDamageDoneMinigame().showModeLabel end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("showModeLabel", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.showModeLabel,
                },
                {
                    type = "checkbox",
                    name = "Show Hit Count",
                    tooltip = "Show the number of hits beneath the score, independently of the Damage Done or DPS label.",
                    getFunc = function() return self:GetDamageDoneMinigame().showHitCount end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("showHitCount", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.showHitCount,
                },
                {
                    type = "checkbox",
                    name = "Show Peak Label",
                    tooltip = "Show PEAK beneath the final score when a chain ends. This does not change the final score or the other labels.",
                    getFunc = function() return self:GetDamageDoneMinigame().showPeakLabel end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("showPeakLabel", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.showPeakLabel,
                },
                {
                    type = "slider",
                    name = "Minigame Scale",
                    min = 60,
                    max = 180,
                    step = 1,
                    getFunc = function() return self:GetDamageDoneMinigame().scale end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("scale", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.scale,
                },
                {
                    type = "button",
                    name = "Preview Minigame",
                    tooltip = "Preview rapid hits, critical impacts, milestones, the draining timer, and the final peak score. Real damage starts a fresh chain.",
                    func = function() self:PreviewDamageDoneMinigame() end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                },
                {
                    type = "button",
                    name = "Preview All Tiers",
                    tooltip = "Climb through all six milestones in the selected mode, including the final transformation at 5 million damage or 140,000 DPS.",
                    func = function() self:PreviewDamageDoneMinigame(true) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = "Kill Sound",
            tooltip = "Pick the sound you hear when you land the killing blow.",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Enable Kill Sound",
                    getFunc = function() return self:IsKillSoundEnabled() end,
                    setFunc = function(value) self:SetKillSoundEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.killSound.enabled,
                },
                {
                    type = "dropdown",
                    name = "Killing Blow Sound",
                    choices =
                    {
                        "Victory Chime",
                        "Match Exit",
                        "Round End",
                        "Skill Trained"
                    },
                    getFunc = function() return GetSoundChoiceLabel(self:GetKillSound().soundKey) end,
                    setFunc = function(value)
                        self:SetKillSoundValue("soundKey", value)
                        self:PreviewKillSound()
                    end,
                    disabled = function() return not self:IsKillSoundEnabled() end,
                    default = GetSoundChoiceLabel(ACCOUNT_DEFAULTS.modules.killSound.soundKey),
                },
            },
        },
        {
            type = "submenu",
            name = "PvP",
            tooltip = "Customize your PvP experience.",
            controls =
            {
                {
                    type = "description",
                    text = "Customize your PvP experience.",
                },
                {
                    type = "header",
                    name = "Kill Streak Animation",
                },
                {
                    type = "checkbox",
                    name = "Enable Kill Streak Animation",
                    tooltip = "Celebrate PvP kills and kill streaks.",
                    getFunc = function() return self:IsPvPEnabled() end,
                    setFunc = function(value) self:SetPvPEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.enabled,
                },
                {
                    type = "checkbox",
                    name = "Unlock Animation",
                    tooltip = "Show a drag handle for the PvP medallion. Its position is saved on this server.",
                    getFunc = function() return self:IsPvPUnlocked() end,
                    setFunc = function(value) self:SetPvPUnlocked(value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.unlocked,
                },
                {
                    type = "checkbox",
                    name = "Enable Sounds",
                    tooltip = "Play progressively stronger sounds as the kill chain grows.",
                    getFunc = function() return self:GetPvP().soundEnabled end,
                    setFunc = function(value) self:SetPvPValue("soundEnabled", value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.soundEnabled,
                },
                {
                    type = "checkbox",
                    name = "Enable Kill Chains",
                    tooltip = "Combine rapid killing blows into a single escalating counter.",
                    getFunc = function() return self:GetPvP().chainEnabled end,
                    setFunc = function(value) self:SetPvPValue("chainEnabled", value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.chainEnabled,
                },
                {
                    type = "checkbox",
                    name = "Include Duels",
                    tooltip = "Celebrate duels that you win. Forfeits do not count as kills.",
                    getFunc = function() return self:GetPvP().includeDuels end,
                    setFunc = function(value) self:SetPvPValue("includeDuels", value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.includeDuels,
                },
                {
                    type = "slider",
                    name = "Scale",
                    min = 60,
                    max = 180,
                    step = 1,
                    getFunc = function() return self:GetPvP().scale end,
                    setFunc = function(value) self:SetPvPValue("scale", value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.scale,
                },
                {
                    type = "slider",
                    name = "Animation Intensity",
                    tooltip = "Control flashes, impact shake, sparks, and the maximum-chain shockwave.",
                    min = 0,
                    max = 150,
                    step = 5,
                    getFunc = function() return self:GetPvP().intensity end,
                    setFunc = function(value) self:SetPvPValue("intensity", value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.intensity,
                },
                {
                    type = "button",
                    name = "Preview Kill Chain",
                    tooltip = "Preview the x1, x4, and x8 medallions, kill-card fans, and sounds.",
                    func = function() self:PreviewPvPChain() end,
                    disabled = function() return not self:IsPvPEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = "Group Callouts",
            tooltip = "Show animated HUD callouts for group chat.",
            reference = "Nirnsteel_UI_GroupCalloutsSubmenu",
            controls =
            {
                {
                    type = "description",
                    text = "Uses ESO's verified group chat channel: /group, /g, /party, and /p.",
                },
                {
                    type = "checkbox",
                    name = "Enable Group Callouts",
                    getFunc = function() return self:IsGroupCalloutsEnabled() end,
                    setFunc = function(value) self:SetGroupCalloutsEnabled(value) end,
                    default = GROUP_CALLOUTS_DEFAULTS.enabled,
                },
                {
                    type = "checkbox",
                    name = "Unlock Group Callouts",
                    tooltip = "Show a drag handle for callouts. The position is saved for this character on this server.",
                    getFunc = function() return self:IsGroupCalloutsUnlocked() end,
                    setFunc = function(value) self:SetGroupCalloutsUnlocked(value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.unlocked,
                },
                {
                    type = "dropdown",
                    name = "Callout Sound Mode",
                    choices = { "Off", "Leader Only", "Every Message" },
                    choicesValues = { "off", "leaderOnly", "all" },
                    getFunc = function() return self:GetGroupCallouts().soundMode end,
                    setFunc = function(value) self:SetGroupCalloutsValue("soundMode", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.soundMode,
                },
                {
                    type = "dropdown",
                    name = "Callout Sound",
                    choices =
                    {
                        "Muted Tick",
                        "Soft Chime",
                        "Clean Click",
                        "Sharp Hit",
                    },
                    choicesValues =
                    {
                        "KEYBIND_BUTTON_DISABLED",
                        "TRIBUTE_AGENT_HEALED",
                        "STATS_RESPEC_CLEAR_ALL",
                        "RETURNING_PLAYER_OPEN_KEYBOARD",
                    },
                    getFunc = function() return self:GetGroupCallouts().soundKey end,
                    setFunc = function(value)
                        self:SetGroupCalloutsValue("soundKey", value)
                        self:PreviewGroupCalloutsSound()
                    end,
                    disabled = function()
                        return not self:IsGroupCalloutsEnabled()
                            or self:GetGroupCallouts().soundMode == "off"
                    end,
                    default = GROUP_CALLOUTS_DEFAULTS.soundKey,
                },
                {
                    type = "button",
                    name = "Preview Sound",
                    func = function() self:PreviewGroupCalloutsSound() end,
                    disabled = function()
                        return not self:IsGroupCalloutsEnabled()
                            or self:GetGroupCallouts().soundMode == "off"
                    end,
                },
                {
                    type = "header",
                    name = "Layout",
                },
                {
                    type = "slider",
                    name = "Scale",
                    min = 60,
                    max = 180,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().scale end,
                    setFunc = function(value) self:SetGroupCalloutsValue("scale", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.scale,
                },
                {
                    type = "slider",
                    name = "Maximum Visible",
                    min = 3,
                    max = 6,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().maxVisible end,
                    setFunc = function(value) self:SetGroupCalloutsValue("maxVisible", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.maxVisible,
                },
                {
                    type = "slider",
                    name = "Width",
                    min = 260,
                    max = 760,
                    step = 10,
                    getFunc = function() return self:GetGroupCallouts().width end,
                    setFunc = function(value) self:SetGroupCalloutsValue("width", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.width,
                },
                {
                    type = "slider",
                    name = "Height",
                    min = 42,
                    max = 110,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().height end,
                    setFunc = function(value) self:SetGroupCalloutsValue("height", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.height,
                },
                {
                    type = "slider",
                    name = "Row Spacing",
                    min = 0,
                    max = 24,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().rowSpacing end,
                    setFunc = function(value) self:SetGroupCalloutsValue("rowSpacing", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.rowSpacing,
                },
                {
                    type = "checkbox",
                    name = "Show Icon",
                    tooltip = "Show a member or leader icon on each callout.",
                    getFunc = function() return self:GetGroupCallouts().showIcon end,
                    setFunc = function(value) self:SetGroupCalloutsValue("showIcon", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.showIcon,
                },
                {
                    type = "slider",
                    name = "Icon Size",
                    min = 0,
                    max = 48,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().iconSize end,
                    setFunc = function(value) self:SetGroupCalloutsValue("iconSize", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() or not self:GetGroupCallouts().showIcon end,
                    default = GROUP_CALLOUTS_DEFAULTS.iconSize,
                },
                {
                    type = "checkbox",
                    name = "Show Accent Strip",
                    tooltip = "Show the small color strip on the left.",
                    getFunc = function() return self:GetGroupCallouts().showAccent end,
                    setFunc = function(value) self:SetGroupCalloutsValue("showAccent", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.showAccent,
                },
                {
                    type = "header",
                    name = "Animation",
                },
                {
                    type = "slider",
                    name = "Visible Duration",
                    tooltip = "Set how long each callout stays visible, in milliseconds.",
                    min = 1200,
                    max = 9000,
                    step = 100,
                    getFunc = function() return self:GetGroupCallouts().durationMS end,
                    setFunc = function(value) self:SetGroupCalloutsValue("durationMS", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.durationMS,
                },
                {
                    type = "slider",
                    name = "Slide Distance",
                    tooltip = "Set how far callouts slide as they fade in and out.",
                    min = 0,
                    max = 40,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().slideDistance end,
                    setFunc = function(value) self:SetGroupCalloutsValue("slideDistance", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.slideDistance,
                },
                {
                    type = "checkbox",
                    name = "Shimmer",
                    tooltip = "Sweep a soft highlight across matching callouts.",
                    getFunc = function() return self:GetGroupCallouts().shimmerEnabled end,
                    setFunc = function(value) self:SetGroupCalloutsValue("shimmerEnabled", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.shimmerEnabled,
                },
                {
                    type = "slider",
                    name = "Shimmer Intensity",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().shimmerIntensity end,
                    setFunc = function(value) self:SetGroupCalloutsValue("shimmerIntensity", value) end,
                    disabled = function()
                        return not self:IsGroupCalloutsEnabled()
                            or not self:GetGroupCallouts().shimmerEnabled
                    end,
                    default = GROUP_CALLOUTS_DEFAULTS.shimmerIntensity,
                },
                {
                    type = "dropdown",
                    name = "Shimmer For",
                    choices = { "Leader Only", "All Callouts" },
                    choicesValues = { "leaderOnly", "all" },
                    getFunc = function() return self:GetGroupCallouts().shimmerTarget end,
                    setFunc = function(value) self:SetGroupCalloutsValue("shimmerTarget", value) end,
                    disabled = function()
                        return not self:IsGroupCalloutsEnabled()
                            or not self:GetGroupCallouts().shimmerEnabled
                    end,
                    default = GROUP_CALLOUTS_DEFAULTS.shimmerTarget,
                },
                {
                    type = "checkbox",
                    name = "Glow",
                    tooltip = "Pulse a colored glow around matching callouts.",
                    getFunc = function() return self:GetGroupCallouts().glowEnabled end,
                    setFunc = function(value) self:SetGroupCalloutsValue("glowEnabled", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.glowEnabled,
                },
                {
                    type = "slider",
                    name = "Glow Intensity",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().glowIntensity end,
                    setFunc = function(value) self:SetGroupCalloutsValue("glowIntensity", value) end,
                    disabled = function()
                        return not self:IsGroupCalloutsEnabled()
                            or not self:GetGroupCallouts().glowEnabled
                    end,
                    default = GROUP_CALLOUTS_DEFAULTS.glowIntensity,
                },
                {
                    type = "dropdown",
                    name = "Glow For",
                    choices = { "Leader Only", "All Callouts" },
                    choicesValues = { "leaderOnly", "all" },
                    getFunc = function() return self:GetGroupCallouts().glowTarget end,
                    setFunc = function(value) self:SetGroupCalloutsValue("glowTarget", value) end,
                    disabled = function()
                        return not self:IsGroupCalloutsEnabled()
                            or not self:GetGroupCallouts().glowEnabled
                    end,
                    default = GROUP_CALLOUTS_DEFAULTS.glowTarget,
                },
                {
                    type = "header",
                    name = "Text",
                },
                {
                    type = "dropdown",
                    name = "Name Font",
                    choices = { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
                    choicesValues = { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" },
                    getFunc = function() return self:GetGroupCallouts().nameFontKey end,
                    setFunc = function(value) self:SetGroupCalloutsValue("nameFontKey", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.nameFontKey,
                },
                {
                    type = "dropdown",
                    name = "Message Font",
                    choices = { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
                    choicesValues = { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" },
                    getFunc = function() return self:GetGroupCallouts().messageFontKey end,
                    setFunc = function(value) self:SetGroupCalloutsValue("messageFontKey", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.messageFontKey,
                },
                {
                    type = "slider",
                    name = "Name Text Size",
                    min = 9,
                    max = 28,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().nameFontSize end,
                    setFunc = function(value) self:SetGroupCalloutsValue("nameFontSize", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.nameFontSize,
                },
                {
                    type = "slider",
                    name = "Message Text Size",
                    min = 9,
                    max = 30,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().messageFontSize end,
                    setFunc = function(value) self:SetGroupCalloutsValue("messageFontSize", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.messageFontSize,
                },
                {
                    type = "dropdown",
                    name = "Text Effect",
                    choices = { "None", "Soft Thin", "Soft Thick", "Thick Outline" },
                    choicesValues = { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" },
                    getFunc = function() return self:GetGroupCallouts().textEffect end,
                    setFunc = function(value) self:SetGroupCalloutsValue("textEffect", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.textEffect,
                },
                {
                    type = "slider",
                    name = "Text Opacity",
                    min = 10,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().textOpacity end,
                    setFunc = function(value) self:SetGroupCalloutsValue("textOpacity", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.textOpacity,
                },
                {
                    type = "header",
                    name = "Background",
                },
                {
                    type = "checkbox",
                    name = "Hide Background",
                    tooltip = "Hide the panel and border, but keep the text, icon, and color strip.",
                    getFunc = function() return self:GetGroupCallouts().hideBackground end,
                    setFunc = function(value) self:SetGroupCalloutsValue("hideBackground", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.hideBackground,
                },
                {
                    type = "slider",
                    name = "Background Opacity",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().backgroundOpacity end,
                    setFunc = function(value) self:SetGroupCalloutsValue("backgroundOpacity", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() or self:GetGroupCallouts().hideBackground end,
                    default = GROUP_CALLOUTS_DEFAULTS.backgroundOpacity,
                },
                {
                    type = "slider",
                    name = "Border Opacity",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().borderOpacity end,
                    setFunc = function(value) self:SetGroupCalloutsValue("borderOpacity", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() or self:GetGroupCallouts().hideBackground end,
                    default = GROUP_CALLOUTS_DEFAULTS.borderOpacity,
                },
                {
                    type = "slider",
                    name = "Accent Opacity",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetGroupCallouts().accentOpacity end,
                    setFunc = function(value) self:SetGroupCalloutsValue("accentOpacity", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() or not self:GetGroupCallouts().showAccent end,
                    default = GROUP_CALLOUTS_DEFAULTS.accentOpacity,
                },
                {
                    type = "header",
                    name = "Member Colors",
                },
                {
                    type = "colorpicker",
                    name = "Member Name",
                    getFunc = function() return self:GetGroupCalloutsColor("memberNameColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("memberNameColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.memberNameColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = "Member Message",
                    getFunc = function() return self:GetGroupCalloutsColor("memberTextColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("memberTextColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.memberTextColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = "Member Accent",
                    getFunc = function() return self:GetGroupCalloutsColor("memberAccentColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("memberAccentColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.memberAccentColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = "Member Background",
                    getFunc = function() return self:GetGroupCalloutsColor("memberBackgroundColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("memberBackgroundColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() or self:GetGroupCallouts().hideBackground end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.memberBackgroundColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "header",
                    name = "Leader Colors",
                },
                {
                    type = "colorpicker",
                    name = "Leader Name",
                    getFunc = function() return self:GetGroupCalloutsColor("leaderNameColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("leaderNameColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.leaderNameColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = "Leader Message",
                    getFunc = function() return self:GetGroupCalloutsColor("leaderTextColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("leaderTextColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.leaderTextColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = "Leader Accent",
                    getFunc = function() return self:GetGroupCalloutsColor("leaderAccentColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("leaderAccentColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.leaderAccentColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = "Leader Background",
                    getFunc = function() return self:GetGroupCalloutsColor("leaderBackgroundColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("leaderBackgroundColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() or self:GetGroupCallouts().hideBackground end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.leaderBackgroundColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "button",
                    name = "Preview Regular Callout",
                    func = function() self:PreviewGroupCallout() end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                },
                {
                    type = "button",
                    name = "Preview Leader Callout",
                    func = function() self:PreviewGroupCalloutLeader() end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = "Action Bar",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Enable Action Bar Frames",
                    tooltip = "Restyle action bar buttons and highlight ready ultimates and quickslot cooldowns.",
                    getFunc = function() return self:IsActionBarFramesEnabled() end,
                    setFunc = function(value) self:SetActionBarFramesEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.actionBarFrames.enabled,
                },
                {
                    type = "dropdown",
                    name = "Frame Style",
                    choices = { "NirnSteel", "Original", "None" },
                    choicesValues = { "rpg", "original", "none" },
                    getFunc = function() return self:GetActionBarFrames().frameStyle or "rpg" end,
                    setFunc = function(value)
                        self:GetActionBarFrames().frameStyle = value
                        if Nirnsteel_UI.ActionBarFrames then Nirnsteel_UI.ActionBarFrames:RefreshSettings() end
                    end,
                    disabled = function() return not self:IsActionBarFramesEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.actionBarFrames.frameStyle,
                },
                {
                    type = "checkbox",
                    name = "Shrink Used Skills",
                    getFunc = function() return self:IsActionBarSkillUseShrinkEnabled() end,
                    setFunc = function(value) self:SetActionBarSkillUseShrinkEnabled(value) end,
                    disabled = function() return not self:IsActionBarFramesEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.actionBarFrames.skillUseShrinkEnabled,
                },
                {
                    type = "checkbox",
                    name = "Show Global Cooldown",
                    tooltip = "Show ESO's global cooldown sweep after you use a skill.",
                    getFunc = function() return self:IsActionBarGlobalCooldownEnabled() end,
                    setFunc = function(value) self:SetActionBarGlobalCooldownEnabled(value) end,
                    disabled = function() return not self:IsActionBarFramesEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.actionBarFrames.globalCooldownEnabled,
                },
            },
        },
        {
            type = "submenu",
            name = "Adventure Camera",
            tooltip = "Use a relaxed third-person camera out of combat, then switch back for combat.",
            controls =
            {
                {
                    type = "description",
                    text = "Adventure Camera keeps one camera setup for combat and another for exploration. When you first enable it, your current camera is copied into both setups so nothing jumps. Adjust the sliders below for exploration, then use the capture button whenever you want your current ESO camera to become the combat setup.",
                },
                {
                    type = "checkbox",
                    name = "Enable Adventure Camera",
                    getFunc = function() return self:IsAdventureCameraEnabled() end,
                    setFunc = function(value) self:SetAdventureCameraEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.adventureCamera.enabled,
                },
                {
                    type = "slider",
                    name = "Transition Duration",
                    tooltip = "Set how long the camera switch takes, in milliseconds.",
                    min = 0,
                    max = 3000,
                    step = 50,
                    getFunc = function() return self:GetAdventureCamera().transitionMS end,
                    setFunc = function(value) self:SetAdventureCameraValue("transitionMS", value) end,
                    disabled = function() return not self:IsAdventureCameraEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.adventureCamera.transitionMS,
                },
                {
                    type = "button",
                    name = "Capture Current as Action Camera",
                    tooltip = "Save your current ESO third-person camera as the combat camera.",
                    func = function() self:CaptureAdventureCameraActionProfile() end,
                },
                {
                    type = "header",
                    name = "Adventure Camera",
                },
                {
                    type = "slider",
                    name = "Horizontal Look Speed",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetAdventureCameraDisplayValue("horizontalLookSpeed") end,
                    setFunc = function(value) self:SetAdventureCameraDisplayValue("horizontalLookSpeed", value) end,
                    disabled = function() return not self:IsAdventureCameraEnabled() end,
                    default = RawCameraValueToDisplay("horizontalLookSpeed", ACCOUNT_DEFAULTS.modules.adventureCamera.adventureProfile.horizontalLookSpeed),
                },
                {
                    type = "slider",
                    name = "Vertical Look Speed",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetAdventureCameraDisplayValue("verticalLookSpeed") end,
                    setFunc = function(value) self:SetAdventureCameraDisplayValue("verticalLookSpeed", value) end,
                    disabled = function() return not self:IsAdventureCameraEnabled() end,
                    default = RawCameraValueToDisplay("verticalLookSpeed", ACCOUNT_DEFAULTS.modules.adventureCamera.adventureProfile.verticalLookSpeed),
                },
                {
                    type = "slider",
                    name = "Field of View",
                    min = 70,
                    max = 130,
                    step = 1,
                    getFunc = function() return self:GetAdventureCameraDisplayValue("fieldOfView") end,
                    setFunc = function(value) self:SetAdventureCameraDisplayValue("fieldOfView", value) end,
                    disabled = function() return not self:IsAdventureCameraEnabled() end,
                    default = RawCameraValueToDisplay("fieldOfView", ACCOUNT_DEFAULTS.modules.adventureCamera.adventureProfile.fieldOfView),
                },
                {
                    type = "slider",
                    name = "Horizontal Position",
                    min = -100,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetAdventureCameraDisplayValue("horizontalPosition") end,
                    setFunc = function(value) self:SetAdventureCameraDisplayValue("horizontalPosition", value) end,
                    disabled = function() return not self:IsAdventureCameraEnabled() end,
                    default = RawCameraValueToDisplay("horizontalPosition", ACCOUNT_DEFAULTS.modules.adventureCamera.adventureProfile.horizontalPosition),
                },
                {
                    type = "slider",
                    name = "Horizontal Offset",
                    min = -100,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetAdventureCameraDisplayValue("horizontalOffset") end,
                    setFunc = function(value) self:SetAdventureCameraDisplayValue("horizontalOffset", value) end,
                    disabled = function() return not self:IsAdventureCameraEnabled() end,
                    default = RawCameraValueToDisplay("horizontalOffset", ACCOUNT_DEFAULTS.modules.adventureCamera.adventureProfile.horizontalOffset),
                },
                {
                    type = "slider",
                    name = "Vertical Offset",
                    min = -60,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetAdventureCameraDisplayValue("verticalOffset") end,
                    setFunc = function(value) self:SetAdventureCameraDisplayValue("verticalOffset", value) end,
                    disabled = function() return not self:IsAdventureCameraEnabled() end,
                    default = RawCameraValueToDisplay("verticalOffset", ACCOUNT_DEFAULTS.modules.adventureCamera.adventureProfile.verticalOffset),
                },
            },
        },
        {
            type = "submenu",
            name = "Cast Bar",
            tooltip = "Tweak the progress bar for cast and channel abilities.",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Enable Cast Bar",
                    getFunc = function() return self:IsCastBarEnabled() end,
                    setFunc = function(value) self:SetCastBarEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.enabled,
                },
                {
                    type = "checkbox",
                    name = "Unlock Cast Bar",
                    tooltip = "Show a drag handle for the cast bar. Its position is saved on this server.",
                    getFunc = function() return self:IsCastBarUnlocked() end,
                    setFunc = function(value) self:SetCastBarUnlocked(value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.unlocked,
                },
                {
                    type = "checkbox",
                    name = "Show Ability Icon",
                    getFunc = function() return self:GetCastBar().showIcon end,
                    setFunc = function(value) self:SetCastBarValue("showIcon", value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.showIcon,
                },
                {
                    type = "checkbox",
                    name = "Show Progress Marks",
                    tooltip = "Show progress divisions that pulse as the cast passes them.",
                    getFunc = function() return self:GetCastBar().showTicks end,
                    setFunc = function(value) self:SetCastBarValue("showTicks", value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.showTicks,
                },
                {
                    type = "dropdown",
                    name = "Text Mode",
                    choices = { "Name + Time", "Name Only", "Timer Only", "Off" },
                    choicesValues = { "nameAndTime", "nameOnly", "timerOnly", "off" },
                    getFunc = function() return self:GetCastBar().textMode end,
                    setFunc = function(value) self:SetCastBarValue("textMode", value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.textMode,
                },
                {
                    type = "slider",
                    name = "Scale",
                    min = 70,
                    max = 160,
                    step = 1,
                    getFunc = function() return self:GetCastBar().scale end,
                    setFunc = function(value) self:SetCastBarValue("scale", value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.scale,
                },
                {
                    type = "slider",
                    name = "Width",
                    min = 220,
                    max = 620,
                    step = 10,
                    getFunc = function() return self:GetCastBar().width end,
                    setFunc = function(value) self:SetCastBarValue("width", value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.width,
                },
                {
                    type = "slider",
                    name = "Height",
                    min = 18,
                    max = 48,
                    step = 1,
                    getFunc = function() return self:GetCastBar().height end,
                    setFunc = function(value) self:SetCastBarValue("height", value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.height,
                },
                {
                    type = "slider",
                    name = "Opacity",
                    min = 20,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetCastBar().opacity end,
                    setFunc = function(value) self:SetCastBarValue("opacity", value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.opacity,
                },
                {
                    type = "slider",
                    name = "Animation Intensity",
                    tooltip = "Set the strength of cast pulses, moving highlights, and the completion flash and expanding glow. Zero disables decorative animation.",
                    min = 0,
                    max = 160,
                    step = 5,
                    getFunc = function() return self:GetCastBar().animationIntensity end,
                    setFunc = function(value) self:SetCastBarValue("animationIntensity", value) end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.castBar.animationIntensity,
                },
                {
                    type = "button",
                    name = "Preview",
                    func = function() self:PreviewCastBar() end,
                    disabled = function() return not self:IsCastBarEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = "Compass",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Enable Compass Frame",
                    tooltip = "Frame the native compass with silver rails, forged steel end pieces, a center bearing marker, and antique direction lettering.",
                    getFunc = function() return self:IsCompassEnabled() end,
                    setFunc = function(value) self:SetCompassEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.compass.enabled,
                },
            },
        },
        {
            type = "submenu",
            name = "HARDCORE Support",
            tooltip = "Choose what HARDCORE hides for this character.",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Hide Compass",
                    getFunc = function() return self:ShouldHardcoreHideCompass() end,
                    setFunc = function(value) self:SetHardcoreHideCompass(value) end,
                    default = CHARACTER_DEFAULTS.hardcoreSupport.hideCompass,
                },
                {
                    type = "checkbox",
                    name = "Hide Health Resource Bar",
                    getFunc = function() return self:ShouldHardcoreHideHealthResourceBar() end,
                    setFunc = function(value) self:SetHardcoreHideHealthResourceBar(value) end,
                    default = CHARACTER_DEFAULTS.hardcoreSupport.hideHealthResourceBar,
                },
            },
        },
        {
            type = "submenu",
            name = "Experience Tracker",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Enable Experience Tracker",
                    tooltip = "Show a Nirnsteel animation when you gain XP or Champion Points.",
                    getFunc = function() return self:IsExperienceTrackerEnabled() end,
                    setFunc = function(value) self:SetExperienceTrackerEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.enabled,
                },
                {
                    type = "checkbox",
                    name = "Unlock Experience Tracker",
                    tooltip = "Show a drag handle for the tracker. Its position is saved on this server.",
                    getFunc = function() return self:IsExperienceTrackerUnlocked() end,
                    setFunc = function(value) self:SetExperienceTrackerUnlocked(value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.unlocked,
                },
                {
                    type = "checkbox",
                    name = "Hide Stock Progress Bar",
                    tooltip = "Hide ESO's XP bar while Nirnsteel's tracker is on.",
                    getFunc = function() return self:ShouldExperienceTrackerHideStockProgressBar() end,
                    setFunc = function(value) self:SetExperienceTrackerValue("hideStockProgressBar", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.hideStockProgressBar,
                },
                {
                    type = "checkbox",
                    name = "Show Gained XP Text",
                    getFunc = function() return self:GetExperienceTracker().showGainText end,
                    setFunc = function(value) self:SetExperienceTrackerValue("showGainText", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.showGainText,
                },
                {
                    type = "checkbox",
                    name = "Show Progress Text",
                    tooltip = "Show your current XP amount and percentage.",
                    getFunc = function() return self:GetExperienceTracker().showProgressText end,
                    setFunc = function(value) self:SetExperienceTrackerValue("showProgressText", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.showProgressText,
                },
                {
                    type = "checkbox",
                    name = "Show Champion Icon",
                    tooltip = "Show the Champion discipline icon in the tracker badge.",
                    getFunc = function() return self:GetExperienceTracker().showChampionIcon end,
                    setFunc = function(value) self:SetExperienceTrackerValue("showChampionIcon", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.showChampionIcon,
                },
                {
                    type = "checkbox",
                    name = "Hide Background",
                    tooltip = "Hide the panel background, but keep the badge and progress bar.",
                    getFunc = function() return self:GetExperienceTracker().hideBackground end,
                    setFunc = function(value) self:SetExperienceTrackerValue("hideBackground", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.hideBackground,
                },
                {
                    type = "dropdown",
                    name = "Visibility",
                    choices = { "Fade After Gains", "Always Visible" },
                    choicesValues = { "fade", "always" },
                    getFunc = function() return self:GetExperienceTracker().visibilityMode end,
                    setFunc = function(value) self:SetExperienceTrackerValue("visibilityMode", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.visibilityMode,
                },
                {
                    type = "dropdown",
                    name = "Chunk Sound",
                    tooltip = "Pick the sound for each XP bar chunk.",
                    choices =
                    {
                        "None",
                        "Rune Tick",
                        "Reward Ping",
                        "Counter Tick",
                    },
                    getFunc = function() return GetSoundChoiceLabel(self:GetExperienceTracker().chunkSoundKey) end,
                    setFunc = function(value)
                        self:SetExperienceTrackerValue("chunkSoundKey", value)
                        if Nirnsteel_UI.ExperienceTracker and Nirnsteel_UI.ExperienceTracker.PreviewChunkSound then
                            Nirnsteel_UI.ExperienceTracker:PreviewChunkSound()
                        end
                    end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = GetSoundChoiceLabel(ACCOUNT_DEFAULTS.modules.experienceTracker.chunkSoundKey),
                },
                {
                    type = "dropdown",
                    name = "Level Up Sound",
                    tooltip = "Pick the sound for a new level or Champion Point.",
                    choices =
                    {
                        "None",
                        "Major Victory",
                        "Victory",
                    },
                    getFunc = function() return GetSoundChoiceLabel(self:GetExperienceTracker().levelUpSoundKey) end,
                    setFunc = function(value)
                        self:SetExperienceTrackerValue("levelUpSoundKey", value)
                        if Nirnsteel_UI.ExperienceTracker and Nirnsteel_UI.ExperienceTracker.PreviewLevelUpSound then
                            Nirnsteel_UI.ExperienceTracker:PreviewLevelUpSound()
                        end
                    end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = GetSoundChoiceLabel(ACCOUNT_DEFAULTS.modules.experienceTracker.levelUpSoundKey),
                },
                {
                    type = "checkbox",
                    name = "Enable Level Up Animation",
                    tooltip = "Play a special burst when you gain a level or Champion Point.",
                    getFunc = function() return self:GetExperienceTracker().levelUpAnimationEnabled end,
                    setFunc = function(value) self:SetExperienceTrackerValue("levelUpAnimationEnabled", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.levelUpAnimationEnabled,
                },
                {
                    type = "slider",
                    name = "Scale",
                    min = 70,
                    max = 160,
                    step = 1,
                    getFunc = function() return self:GetExperienceTracker().scale end,
                    setFunc = function(value) self:SetExperienceTrackerValue("scale", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.scale,
                },
                {
                    type = "slider",
                    name = "Opacity",
                    min = 20,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetExperienceTracker().opacity end,
                    setFunc = function(value) self:SetExperienceTrackerValue("opacity", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.opacity,
                },
                {
                    type = "slider",
                    name = "Width",
                    min = 360,
                    max = 680,
                    step = 10,
                    getFunc = function() return self:GetExperienceTracker().width end,
                    setFunc = function(value) self:SetExperienceTrackerValue("width", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.width,
                },
                {
                    type = "slider",
                    name = "Height",
                    min = 54,
                    max = 76,
                    step = 1,
                    getFunc = function() return self:GetExperienceTracker().height end,
                    setFunc = function(value) self:SetExperienceTrackerValue("height", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.height,
                },
                {
                    type = "slider",
                    name = "Visible Duration",
                    tooltip = "Set how long the tracker stays visible after a gain starts, in milliseconds.",
                    min = 1800,
                    max = 7000,
                    step = 100,
                    getFunc = function() return self:GetExperienceTracker().durationMS end,
                    setFunc = function(value) self:SetExperienceTrackerValue("durationMS", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.durationMS,
                },
                {
                    type = "slider",
                    name = "Feedback Intensity",
                    tooltip = "Set the strength of glow, flash, and fill effects.",
                    min = 0,
                    max = 140,
                    step = 5,
                    getFunc = function() return self:GetExperienceTracker().intensity end,
                    setFunc = function(value) self:SetExperienceTrackerValue("intensity", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.intensity,
                },
                {
                    type = "slider",
                    name = "Level Up Animation Strength",
                    min = 0,
                    max = 160,
                    step = 5,
                    getFunc = function() return self:GetExperienceTracker().levelUpIntensity end,
                    setFunc = function(value) self:SetExperienceTrackerValue("levelUpIntensity", value) end,
                    disabled = function()
                        return not self:IsExperienceTrackerEnabled()
                            or not self:GetExperienceTracker().levelUpAnimationEnabled
                    end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.levelUpIntensity,
                },
                {
                    type = "button",
                    name = "Preview",
                    func = function() self:PreviewExperienceTracker() end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = "Group Frames",
            tooltip = "Swap ESO's group and raid frames for compact, sortable Nirnsteel frames.",
            reference = "Nirnsteel_UI_GroupFramesSubmenu",
            controls = self:BuildGroupFramesOptions(),
        },
        {
            type = "submenu",
            name = "Target Frame",
            tooltip = "Replace ESO's reticle target frame with a compact, customizable Nirnsteel frame.",
            reference = "Nirnsteel_UI_TargetFrameSubmenu",
            controls = self:BuildTargetFrameOptions(),
        },
        {
            type = "submenu",
            name = "Resource Bars",
            reference = "Nirnsteel_UI_ResourceBarsSubmenu",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Enable Resource Bars",
                    tooltip = "Swap ESO's health, magicka, and stamina bars for Nirnsteel's centered bars.",
                    getFunc = function() return self:IsResourceBarsEnabled() end,
                    setFunc = function(value) self:SetResourceBarsEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.enabled,
                },
                {
                    type = "checkbox",
                    name = "Unlock Resource Bars",
                    tooltip = "Show a drag handle for the resource bars. Their position is saved on this server.",
                    getFunc = function() return self:IsResourceBarsUnlocked() end,
                    setFunc = function(value) self:SetResourceBarsUnlocked(value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.unlocked,
                },
                {
                    type = "dropdown",
                    name = "Layout",
                    tooltip = "Pyramid: health above magicka and stamina. Linear: magicka, health, stamina in one row. Stacked: health, magicka, stamina from top to bottom.",
                    choices = { "Pyramid", "Linear", "Stacked" },
                    choicesValues = { "pyramid", "linear", "stacked" },
                    getFunc = function() return self:GetResourceBars().layout end,
                    setFunc = function(value) self:SetResourceBarsValue("layout", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.layout,
                },
                {
                    type = "checkbox",
                    name = "Attach Mount Stamina",
                    tooltip = "Attach ESO's mount stamina bar below the character's stamina bar in any layout. The mount bar keeps its normal appearance and mounted visibility.",
                    getFunc = function() return self:GetResourceBars().attachMountStamina end,
                    setFunc = function(value) self:SetResourceBarsValue("attachMountStamina", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.attachMountStamina,
                },
                {
                    type = "slider",
                    name = "Scale",
                    min = 70,
                    max = 160,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().scale end,
                    setFunc = function(value) self:SetResourceBarsValue("scale", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.scale,
                },
                {
                    type = "slider",
                    name = "Health Width",
                    min = 96,
                    max = 620,
                    step = 8,
                    getFunc = function() return self:GetResourceBars().rowHealthWidth end,
                    setFunc = function(value) self:SetResourceBarsValue("rowHealthWidth", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.rowHealthWidth,
                },
                {
                    type = "slider",
                    name = "Magicka Width",
                    min = 96,
                    max = 620,
                    step = 8,
                    getFunc = function() return self:GetResourceBars().rowMagickaWidth end,
                    setFunc = function(value) self:SetResourceBarsValue("rowMagickaWidth", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.rowMagickaWidth,
                },
                {
                    type = "slider",
                    name = "Stamina Width",
                    min = 96,
                    max = 620,
                    step = 8,
                    getFunc = function() return self:GetResourceBars().rowStaminaWidth end,
                    setFunc = function(value) self:SetResourceBarsValue("rowStaminaWidth", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.rowStaminaWidth,
                },
                {
                    type = "slider",
                    name = "Bar Height",
                    min = 10,
                    max = 48,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().barHeight end,
                    setFunc = function(value) self:SetResourceBarsValue("barHeight", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.barHeight,
                },
                {
                    type = "slider",
                    name = "Vertical Spacing",
                    min = 0,
                    max = 32,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().rowSpacing end,
                    setFunc = function(value) self:SetResourceBarsValue("rowSpacing", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.rowSpacing,
                },
                {
                    type = "slider",
                    name = "Horizontal Spacing",
                    min = 0,
                    max = 32,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().columnSpacing end,
                    setFunc = function(value) self:SetResourceBarsValue("columnSpacing", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.columnSpacing,
                },
                {
                    type = "slider",
                    name = "Bar Opacity",
                    min = 10,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().opacity end,
                    setFunc = function(value) self:SetResourceBarsValue("opacity", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.opacity,
                },
                {
                    type = "checkbox",
                    name = "NirnSteel Iron Borders",
                    getFunc = function() return self:GetResourceBars().rpgBorder == true end,
                    setFunc = function(value) self:SetResourceBarsValue("rpgBorder", value) end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.rpgBorder,
                },
                {
                    type = "checkbox",
                    name = "Gloss Overlay",
                    getFunc = function() return self:GetResourceBars().glossEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("glossEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.glossEnabled,
                },
                {
                    type = "checkbox",
                    name = "Fill Pattern Overlay",
                    tooltip = "Add a subtle texture without changing the resource color.",
                    getFunc = function() return self:GetResourceBars().barPatternEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("barPatternEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.barPatternEnabled,
                },
                {
                    type = "dropdown",
                    name = "Fill Pattern",
                    choices = { "Smoke", "Still Water", "Zigzag", "Stone", "Dirt", "Lava", "Rock Lava", "Lava Wave", "Molten" },
                    choicesValues = { "smoke", "stillwater", "ZigZag", "Stone", "Dirt", "Lava", "RockLava", "LavaWave", "Molten" },
                    getFunc = function() return self:GetResourceBars().barPatternKey end,
                    setFunc = function(value) self:SetResourceBarsValue("barPatternKey", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().barPatternEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.barPatternKey,
                },
                {
                    type = "slider",
                    name = "Fill Pattern Opacity",
                    min = 0,
                    max = 60,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().barPatternOpacity end,
                    setFunc = function(value) self:SetResourceBarsValue("barPatternOpacity", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().barPatternEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.barPatternOpacity,
                },
                {
                    type = "slider",
                    name = "Fill Pattern Scale",
                    tooltip = "Use a lower value for smaller tiles or a higher one for larger tiles.",
                    min = 128,
                    max = 512,
                    step = 4,
                    getFunc = function() return self:GetResourceBars().barPatternScale end,
                    setFunc = function(value) self:SetResourceBarsValue("barPatternScale", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().barPatternEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.barPatternScale,
                },
                {
                    type = "header",
                    name = "Resource Feedback",
                },
                {
                    type = "checkbox",
                    name = "Resource Feedback",
                    tooltip = "Show quick effects when resources change, fill up, get low, or gain a shield.",
                    getFunc = function() return self:GetResourceBars().feedbackEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("feedbackEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.feedbackEnabled,
                },
                {
                    type = "checkbox",
                    name = "Loss Trailing",
                    tooltip = "Leave a short-lived highlight behind a resource bar when its value drops.",
                    getFunc = function() return self:GetResourceBars().lossTrailEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("lossTrailEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.lossTrailEnabled,
                },
                {
                    type = "slider",
                    name = "Feedback Intensity",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().feedbackIntensity end,
                    setFunc = function(value) self:SetResourceBarsValue("feedbackIntensity", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().feedbackEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.feedbackIntensity,
                },
                {
                    type = "checkbox",
                    name = "Gain Pulse",
                    tooltip = "Briefly brighten a bar after a noticeable resource gain.",
                    getFunc = function() return self:GetResourceBars().gainPulseEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("gainPulseEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().feedbackEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.gainPulseEnabled,
                },
                {
                    type = "checkbox",
                    name = "Spend Pulse",
                    tooltip = "Briefly brighten a bar after a noticeable spend or loss.",
                    getFunc = function() return self:GetResourceBars().spendPulseEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("spendPulseEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().feedbackEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.spendPulseEnabled,
                },
                {
                    type = "checkbox",
                    name = "Full Resource Pulse",
                    tooltip = "Briefly highlight a bar when it fills up.",
                    getFunc = function() return self:GetResourceBars().fullResourcePulseEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("fullResourcePulseEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().feedbackEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.fullResourcePulseEnabled,
                },
                {
                    type = "checkbox",
                    name = "Shield Pulse",
                    tooltip = "Briefly highlight health when your damage shield grows.",
                    getFunc = function() return self:GetResourceBars().shieldPulseEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("shieldPulseEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().feedbackEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.shieldPulseEnabled,
                },
                {
                    type = "checkbox",
                    name = "Low Resource Glow",
                    tooltip = "Glow around a bar while that resource is low.",
                    getFunc = function() return self:GetResourceBars().lowResourceGlowEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("lowResourceGlowEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().feedbackEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.lowResourceGlowEnabled,
                },
                {
                    type = "header",
                    name = "Frame Styling",
                },
                {
                    type = "slider",
                    name = "Black Border Width",
                    min = 0,
                    max = 8,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().borderWidth end,
                    setFunc = function(value) self:SetResourceBarsValue("borderWidth", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.borderWidth,
                },
                {
                    type = "slider",
                    name = "Inner Shadow",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().innerShadowAlpha end,
                    setFunc = function(value) self:SetResourceBarsValue("innerShadowAlpha", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.innerShadowAlpha,
                },
                {
                    type = "slider",
                    name = "Outer Shadow",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().outerShadowAlpha end,
                    setFunc = function(value) self:SetResourceBarsValue("outerShadowAlpha", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.outerShadowAlpha,
                },
                {
                    type = "header",
                    name = "Text",
                },
                {
                    type = "dropdown",
                    name = "Text Font",
                    choices = { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
                    choicesValues = { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" },
                    getFunc = function() return self:GetResourceBars().textFontKey end,
                    setFunc = function(value) self:SetResourceBarsValue("textFontKey", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.textFontKey,
                },
                {
                    type = "slider",
                    name = "Text Size",
                    min = 8,
                    max = 32,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().textSize end,
                    setFunc = function(value) self:SetResourceBarsValue("textSize", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.textSize,
                },
                {
                    type = "dropdown",
                    name = "Text Outline",
                    choices = { "None", "Soft Thin", "Soft Thick", "Thick Outline" },
                    choicesValues = { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" },
                    getFunc = function() return self:GetResourceBars().textOutline end,
                    setFunc = function(value) self:SetResourceBarsValue("textOutline", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.textOutline,
                },
                {
                    type = "slider",
                    name = "Text Opacity",
                    min = 10,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().textOpacity end,
                    setFunc = function(value) self:SetResourceBarsValue("textOpacity", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.textOpacity,
                },
                {
                    type = "colorpicker",
                    name = "Text Color",
                    getFunc = function()
                        local color = self:GetResourceBars().textColor
                        return color.r, color.g, color.b, 1
                    end,
                    setFunc = function(r, g, b)
                        local color = self:GetResourceBars().textColor
                        color.r = r
                        color.g = g
                        color.b = b
                        if Nirnsteel_UI.ResourceBars then
                            Nirnsteel_UI.ResourceBars:RefreshSettings()
                        end
                    end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = function()
                        local color = ACCOUNT_DEFAULTS.modules.resourceBars.textColor
                        return color.r, color.g, color.b, 1
                    end,
                },
                {
                    type = "slider",
                    name = "Text Side Inset",
                    tooltip = "Move side text away from the bar edges.",
                    min = 0,
                    max = 24,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().textInset end,
                    setFunc = function(value) self:SetResourceBarsValue("textInset", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.textInset,
                },
                {
                    type = "slider",
                    name = "Text Vertical Offset",
                    min = -8,
                    max = 8,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().textVerticalOffset end,
                    setFunc = function(value) self:SetResourceBarsValue("textVerticalOffset", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.textVerticalOffset,
                },
                {
                    type = "dropdown",
                    name = "Health Text Format",
                    choices = { "None", "Number", "Percent", "Number + Percent" },
                    choicesValues = { "none", "number", "percent", "numberAndPercent" },
                    getFunc = function() return self:GetResourceBars().healthTextFormat end,
                    setFunc = function(value) self:SetResourceBarsValue("healthTextFormat", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.healthTextFormat,
                },
                {
                    type = "dropdown",
                    name = "Magicka Text Format",
                    choices = { "None", "Number", "Percent", "Number + Percent" },
                    choicesValues = { "none", "number", "percent", "numberAndPercent" },
                    getFunc = function() return self:GetResourceBars().magickaTextFormat end,
                    setFunc = function(value) self:SetResourceBarsValue("magickaTextFormat", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.magickaTextFormat,
                },
                {
                    type = "dropdown",
                    name = "Stamina Text Format",
                    choices = { "None", "Number", "Percent", "Number + Percent" },
                    choicesValues = { "none", "number", "percent", "numberAndPercent" },
                    getFunc = function() return self:GetResourceBars().staminaTextFormat end,
                    setFunc = function(value) self:SetResourceBarsValue("staminaTextFormat", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.staminaTextFormat,
                },
                {
                    type = "dropdown",
                    name = "Health Text Position",
                    choices = { "Center", "Sides" },
                    choicesValues = { "center", "sides" },
                    getFunc = function() return self:GetResourceBars().healthTextPosition end,
                    setFunc = function(value) self:SetResourceBarsValue("healthTextPosition", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.healthTextPosition,
                },
                {
                    type = "dropdown",
                    name = "Magicka Text Position",
                    choices = { "Center", "Sides" },
                    choicesValues = { "center", "sides" },
                    getFunc = function() return self:GetResourceBars().magickaTextPosition end,
                    setFunc = function(value) self:SetResourceBarsValue("magickaTextPosition", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.magickaTextPosition,
                },
                {
                    type = "dropdown",
                    name = "Stamina Text Position",
                    choices = { "Center", "Sides" },
                    choicesValues = { "center", "sides" },
                    getFunc = function() return self:GetResourceBars().staminaTextPosition end,
                    setFunc = function(value) self:SetResourceBarsValue("staminaTextPosition", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.staminaTextPosition,
                },
                {
                    type = "header",
                    name = "Shield",
                },
                {
                    type = "checkbox",
                    name = "Shield Overlay",
                    tooltip = "Show your shield as an overlay on the health bar.",
                    getFunc = function() return self:GetResourceBars().shieldOverlayEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("shieldOverlayEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.shieldOverlayEnabled,
                },
                {
                    type = "slider",
                    name = "Shield Fill Opacity",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().shieldFillOpacity end,
                    setFunc = function(value) self:SetResourceBarsValue("shieldFillOpacity", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().shieldOverlayEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.shieldFillOpacity,
                },
                {
                    type = "colorpicker",
                    name = "Shield Fill Color",
                    getFunc = function()
                        local color = self:GetResourceBars().shieldFillColor
                        return color.r, color.g, color.b, 1
                    end,
                    setFunc = function(r, g, b)
                        local color = self:GetResourceBars().shieldFillColor
                        color.r = r
                        color.g = g
                        color.b = b
                        if Nirnsteel_UI.ResourceBars then
                            Nirnsteel_UI.ResourceBars:RefreshSettings()
                        end
                    end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().shieldOverlayEnabled end,
                    default = function()
                        local color = ACCOUNT_DEFAULTS.modules.resourceBars.shieldFillColor
                        return color.r, color.g, color.b, 1
                    end,
                },
                {
                    type = "checkbox",
                    name = "Shield Glow",
                    getFunc = function() return self:GetResourceBars().shieldGlowEnabled end,
                    setFunc = function(value) self:SetResourceBarsValue("shieldGlowEnabled", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() or not self:GetResourceBars().shieldOverlayEnabled end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.shieldGlowEnabled,
                },
                {
                    type = "slider",
                    name = "Shield Glow Opacity",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return self:GetResourceBars().shieldGlowOpacity end,
                    setFunc = function(value) self:SetResourceBarsValue("shieldGlowOpacity", value) end,
                    disabled = function()
                        return not self:IsResourceBarsEnabled()
                            or not self:GetResourceBars().shieldOverlayEnabled
                            or not self:GetResourceBars().shieldGlowEnabled
                    end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.shieldGlowOpacity,
                },
                {
                    type = "colorpicker",
                    name = "Shield Glow Color",
                    getFunc = function()
                        local color = self:GetResourceBars().shieldGlowColor
                        return color.r, color.g, color.b, 1
                    end,
                    setFunc = function(r, g, b)
                        local color = self:GetResourceBars().shieldGlowColor
                        color.r = r
                        color.g = g
                        color.b = b
                        if Nirnsteel_UI.ResourceBars then
                            Nirnsteel_UI.ResourceBars:RefreshSettings()
                        end
                    end,
                    disabled = function()
                        return not self:IsResourceBarsEnabled()
                            or not self:GetResourceBars().shieldOverlayEnabled
                            or not self:GetResourceBars().shieldGlowEnabled
                    end,
                    default = function()
                        local color = ACCOUNT_DEFAULTS.modules.resourceBars.shieldGlowColor
                        return color.r, color.g, color.b, 1
                    end,
                },
                {
                    type = "dropdown",
                    name = "Shield Text Mode",
                    choices = { "Off", "Shield Only", "Health + Shield" },
                    choicesValues = { "off", "shieldOnly", "healthAndShield" },
                    getFunc = function() return self:GetResourceBars().shieldTextMode end,
                    setFunc = function(value) self:SetResourceBarsValue("shieldTextMode", value) end,
                    disabled = function() return not self:IsResourceBarsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.resourceBars.shieldTextMode,
                },
            },
        },
        {
            type = "checkbox",
            name = "Debug Mode",
            tooltip = "Turn on slash commands for testing addon features.",
            getFunc = function() return self:IsDebugModeEnabled() end,
            setFunc = function(value) self:SetDebugModeEnabled(value) end,
            default = ACCOUNT_DEFAULTS.debugMode,
        },
    }
    options[#options + 1] = { type = "submenu", name = "Minimap", controls = self:BuildMinimapControls() }
    if Nirnsteel_UI.HUDEditor then Nirnsteel_UI.HUDEditor:ConfigureSettings(options) end
    options = ConfigureModuleMenuOptions(options)

    local noMouseWheelSlider = Nirnsteel_UI.NoMouseWheelSlider
    if noMouseWheelSlider and noMouseWheelSlider:Register(LAM) then
        noMouseWheelSlider:UseForSliderOptions(options)
    end

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, options)
    for _, eventName in ipairs({ "LAM-PanelOpened", "LAM-PanelClosed" }) do
        local visible = eventName == "LAM-PanelOpened"
        CALLBACK_MANAGER:RegisterCallback(eventName, function(panel)
            if panel and panel:GetName() == panelName and Nirnsteel_UI.Minimap then
                Nirnsteel_UI.Minimap:SetSettingsPanelVisible(visible)
            end
            if panel and panel:GetName() == panelName and Nirnsteel_UI.SynergyAlert then
                Nirnsteel_UI.SynergyAlert:SetSettingsPanelVisible(visible)
            end
        end)
    end
    self:HookResourceBarsSubmenuPreview(panelName)
    self:HookGroupCalloutsSubmenuPreview(panelName)
    self:HookGroupFramesSubmenuPreview(panelName)
    self:HookTargetFrameSubmenuPreview(panelName)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Settings", EVENT_ADD_ON_LOADED)
    Settings:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Settings", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
