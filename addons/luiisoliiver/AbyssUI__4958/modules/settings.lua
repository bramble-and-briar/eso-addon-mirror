local ADDON_NAME = "AbyssUI"
local ADDON_DISPLAY_NAME = "AbyssUI"
local SAVED_VARS_VERSION = 1

-- Migra as configuracoes salvas pelos nomes antigos para os novos (uma vez, so se o novo estiver vazio).
-- Os nomes antigos continuam declarados no .txt apenas para isso; depois de abrir o jogo uma vez
-- eles podem ser apagados daqui e do .txt.
NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI

local LEGACY_SAVED_VARS = {
    { "NAGA_Account", "NaguiUI_Account" },
    { "NAGA_Servers", "NaguiUI_Servers" },
    { "NAGA_Character", "NaguiUI_Character" },
    { "NAGA_StatisticsReports", "NaguiUI_StatisticsReports" },
}
local legacyMigrated = false
function NAGA_UI.MigrateLegacySV()
    if legacyMigrated then return end
    legacyMigrated = true
    local function Deep(v)
        if type(v) ~= "table" then return v end
        local r = {}
        for k, i in pairs(v) do r[k] = Deep(i) end
        return r
    end
    for _, pair in ipairs(LEGACY_SAVED_VARS) do
        local newName, oldName = pair[1], pair[2]
        local newT, oldT = _G[newName], _G[oldName]
        if type(oldT) == "table" and (type(newT) ~= "table" or next(newT) == nil) then
            _G[newName] = Deep(oldT)
        end
    end
end
-- Local alias for faster access inside this file
local MigrateLegacySV = NAGA_UI.MigrateLegacySV

-- i18n: traduz strings da UI conforme idioma do cliente / EsoBR
local function T(s)
    if NAGA_UI.T then return NAGA_UI.T(s) end
    return s
end

function NAGA_UI:GetAssetPath(relativePath)
    if not self.assetRoot and GetAddOnManager then
        local manager = GetAddOnManager()
        for index = 1, manager:GetNumAddOns() do
            if manager:GetAddOnInfo(index) == ADDON_NAME then
                local directory = manager:GetAddOnRootDirectoryPath(index)
                directory = directory:gsub("\\", "/"):gsub("^[Uu][Ss][Ee][Rr]:/[Aa][Dd][Dd][Oo][Nn][Ss]/", "")
                self.assetRoot = directory:gsub("/+$", "") .. "/"
                break
            end
        end
    end
    -- Assets live under AbyssUI/assets/ (legacy NAGAUI/ui/ and NAGAUI/ paths rewritten)
    local root = self.assetRoot or "AbyssUI/"
    self.assetRoot = root
    relativePath = relativePath or ""
    relativePath = relativePath:gsub("^NAGAUI/", "")
    relativePath = relativePath:gsub("^ui/", "")
    if not relativePath:find("^assets/") then
        relativePath = "assets/" .. relativePath
    end
    return root .. relativePath
end

local Settings = {}
NAGA_UI.Settings = Settings

local MODULE_MENU_ICONS =
{
    ["AbyssQuest"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_mapandcompass.dds",
    ["Achievement Alert"] = NAGA_UI:GetAssetPath("ui/achievement/iron_trophy_dxt5.dds"),
    ["Action Bar"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_abilitybar.dds",
    ["Adventure Camera"] = "EsoUI/Art/Options/Gamepad/gp_options_camera.dds",
    ["Buffs"] = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
    ["Cast Bar"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_castbarsandcooldowns.dds",
    ["Cast Skill"] = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
    ["Compass"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_mapandcompass.dds",
    ["Damage Numbers"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_combat.dds",
    ["Experience Tracker"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_characterprogression.dds",
    ["Group Callouts"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_chat.dds",
    ["Group Frames"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_unitframes.dds",
    ["HARDCORE Support"] = "EsoUI/Art/Campaign/campaignbrowser_indexicon_hardcore_up.dds",
    ["Kill Sound"] = "EsoUI/Art/Options/Gamepad/gp_options_audio.dds",
    ["Minimap"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_mapandcompass.dds",
    ["Chat"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_chat.dds",
    ["Misc"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_uigraphics.dds",
    ["Companheiro"] = "EsoUI/Art/TreeIcons/collection_indexIcon_companions_up.dds",
    ["Companion Frame"] = "EsoUI/Art/TreeIcons/collection_indexIcon_companions_up.dds",
    ["HUD DE PERSONAGEM"] = "EsoUI/Art/MainMenu/menuBar_character_up.dds",
    ["PvP"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_combat.dds",
    ["Resource Bars"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_uigraphics.dds",
    ["Target Frame"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_unitframes.dds",
    ["Loot History"] = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds",
    ["Info Panel"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_uigraphics.dds",
    ["NAGA"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_uigraphics.dds",
    ["Estatística de Dano"] = "EsoUI/Art/AddOns/Gamepad/gp_mod_listing_category_combat.dds",
}
NAGA_UI.MODULE_MENU_ICONS = MODULE_MENU_ICONS


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
    enabled = true, -- NAGAUI
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
    enabled = true, -- NAGAUI
    unlocked = false,
    scale = 100,
    width = 300,
    barHeight = 25,
    opacity = 100,
    barTextureKey = "genericTall",
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
    lowResourceGlowEnabled = false,
    rpgBorder = true,
    borderWidth = 0,
    innerShadowAlpha = 60,
    outerShadowAlpha = 100,
    textFontKey = "trajan",
    nameTextSize = 20,
    healthTextSize = 18,
    levelTextSize = 16,
    titleTextSize = 14,
    classIconSize = 18,
    championIconSize = 18,
    textOutline = "thick-outline",
    textOpacity = 100,
    textInset = 6,
    textVerticalOffset = 3,
    textColor = { r = 1, g = 1, b = 1 },
    healthTextFormat = "numberAndPercent",
    healthTextPosition = "center",
    shieldOverlayEnabled = true,
    shieldTextMode = "healthAndShield",
    shieldFillOpacity = 70,
    shieldFillColor = { r = 0.95, g = 0.33, b = 0.60 },
    shieldGlowEnabled = true,
    shieldGlowOpacity = 65,
    shieldGlowColor = { r = 0.95, g = 0.56, b = 0.66 },
    npcColorMode = "static",
    playerColorMode = "static",
    staticColor = { r = 0.78, g = 0.06, b = 0.08 },
    fullHealthColor = { r = 1.00, g = 1.00, b = 1.00 },
    lowHealthColor = { r = 0.58, g = 0.015, b = 0.025 },
    showClass = true,
    showLevel = true,
    showLevelStyle = true,
    showVeterancyIcon = false,
    showTitle = true,
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

local INFO_PANEL_DEFAULTS =
{
    enabled            = true,
    panelScale         = 100,
    transparency       = 100,
    HideInCombat       = false,
    DisableInfoColours = false,
    TextBlackOutline   = true,
    ClockFormat        = "HH:MM:SS",
    FontFace           = "ZoFontGame",
    FontSize           = 16,
    IconSize           = 20,
    HideLatency        = false,
    HideFPS            = false,
    HideMemory         = false,
    HideClock          = false,
    HideGems           = false,
    HideMount          = false,
    HideArmour         = false,
    HideWeapons        = false,
    HideBags           = false,
    HideGold           = false,
}

local MINIMAP_DEFAULTS =
{
    -- Disabled by default: use the NAGA Minimap instead.
    enabled = false, unlocked = false, shape = "circle", orientation = "rotating",
    diameter = 280, width = 340, height = 240, questTrackerOffset = 0,
    mapOpacity = 95, frameOpacity = 100, borderThickness = 2, shadow = true,
    borderColor = { r = 0, g = 0, b = 0 },
    accentColor = { r = 0.8980392218, g = 0.7098039389, b = 0.2274509817 },
    showLocation = true, locationNamePosition = "bottom", showCardinals = true, showCoordinates = false,
    zoneTextSize = 20,
    zoom = 4.5, markerScale = 125, playerScale = 110,
    combatBehavior = "show", combatOpacity = 40,
    clickThrough = false, wheelZoom = true, tooltips = true,
    showGroup = true, showQuests = true, showWayshrines = true,
    showLocations = true, showWaypoint = true, waypointEdge = true, questMode = "tracked",
    showMapPins = true,
}

local ACCOUNT_DEFAULTS =
{
    debugMode = false,
    modules =
    {
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
            scale = 85,
            opacity = 50,
            animationIntensity = 85,
        },
        companionSwitcher =
        {
            enabled = true,
            announceEnabled = true,
            announceMessage = 'Invocando Companheiro = "<<1>>"',
            announceColor = { r = 1, g = 1, b = 0, a = 1 },
            announceDuration = 2500,
            announceFontSize = 28,
        },
        companionFrame =
        {
            enabled = true,
            width = 220,
            height = 90,
            scale = 100,
            showLevel = true,
            showRapport = true,
            showXP = true,
            showButtons = true,
            opacityIn = 100,
            opacityOut = 70,
            nameFontKey = "trajan",
            valueFontKey = "standard",
            fontSize = 14,
            textOutline = "thick-outline",
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            healthColor = { r = 0.80, g = 0.15, b = 0.15, a = 1 },
            rapportColor = { r = 0.25, g = 0.55, b = 0.95, a = 1 },
            xpColor = { r = 0.25, g = 0.75, b = 0.30, a = 1 },
            trackColor = { r = 0.008, g = 0.009, b = 0.012, a = 0.78 },
            borderColor = { r = 0.20, g = 0.20, b = 0.20, a = 1 },
            roundedBarCorners = true,
            barInset = 2,
            textureKey = "genericTall",
        },
        lootHistory =
        {
            enabled = true,
            legacyStyle = false,
            unlocked = false,
            scale = 80,
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
            enabled = true, -- NAGAUI
            frameStyle = "rpg",
            skillUseShrinkEnabled = true,
            globalCooldownEnabled = true,
            cooldownTextEnabled = true,
        },
        immersiveTeleport =
        {
            enabled = false,
        },
        automations =
        {
            DeleteMail=false, ConfirmLocked=false, JumpToLeader=false, GroupLeave=false, Books=false, FriendStatus=false,
            LargeGroupInvite=true, LargeGroupAnnoucement=true, FastTravel=false, InitialDialog=false, RepeatableQuests=false,
            CovetousCountess=false, DarkBrotherhoodSpree=false, AdvancedSynergy=false, BlockAnnouncement=false,
            ContainerHandler=false, StealthWield=false, LootStolen=false, UndauntedPledges=false, DungeonQuests=false,
            CollapseNormalDungeon=false, PlayerToPlayer=false, BuiltInGlobalCooldown=false, AutoDismissPet=true,
            AutoQueue=false, HousePins=4,
        },
        adventureCamera =
        {
            enabled = false,
            initialized = false,
            transitionMS = 150,
            actionProfile = CAMERA_PROFILE_DEFAULTS,
            adventureProfile = CAMERA_PROFILE_DEFAULTS,
        },
        infoPanel = INFO_PANEL_DEFAULTS,
        castBar =
        {
            enabled = false, -- NAGAUI
            unlocked = false,
            scale = 100,
            width = 400,
            height = 20,
            opacity = 100,
            rpgBorder = true,
            borderWidth = 2,
            innerShadowAlpha = 35,
            outerShadowAlpha = 65,
            glossEnabled = true,
            textFontKey = "gameSmall",
            textSize = 16,
            textOutline = "thick-outline",
            textOpacity = 100,
            textColor = { r = 0.88, g = 0.93, b = 0.96 },
            textMode = "nameAndTime",
            showIcon = true,
            showTicks = true,
            animationIntensity = 85,
        },
        compass =
        {
            enabled = true,
            style = "ds3", -- "naga" | "ds3"
            worldEventPin = true, -- pin EventWorld + distância no compass
        },
        buffs =
        {
            enabled = true,
            showPlayer = true,
            showTarget = true,
            unlocked = false,
            -- Player
            playerBuffSize = 40,
            buffsImportant = false,
            minimumDuration = 3,
            buffsOtherHide = true,
            playerBuffsAlign = 128, -- CENTER
            -- Passives
            buffsPassives = "On additional panel",
            passiveBuffSize = 36,
            passiveProgress = false,
            passivePWidth = 100,
            passivePSide = "left",
            passiveOakFilter = true,
            -- Target
            targetBuffSize = 40,
            targetBuffsAlign = 128,
            -- Blacklist
            enableBlackList = false,
            blackList =
            {
                [63601] = true, -- ESO Plus
                [14890] = true, -- Block
                [43752] = true, -- Soul Summons / Invocacao de Alma
                ["Invocação de Alma"] = true,
                ["Invocacao de Alma"] = true,
                ["Soul Summons"] = true,
            },
            -- Custom buffs panel
            enableCustomBuffs = false,
            customBuffSize = 44,
            customBuffsDirection = "vertical",
            customBuffsProgress = true,
            customBuffsPWidth = 120,
            customBuffsPSide = "right",
            customBuffs = {},
            -- Synergy CD
            enableSynergyCd = false,
            synergyCdSize = 44,
            synergyCdDirection = "vertical",
            synergyCdProgress = true,
            synergyCdPWidth = 120,
            synergyCdPSide = "right",
            -- Widgets
            enableWidgets = false,
            widgetsSize = 44,
            widgetsPWidth = 120,
            widgetPotion = true,
            widgets =
            {
                ["Major Resolve"] = true,
                ["Major Sorcery"] = true,
                ["Major Brutality"] = true,
                ["Major Courage"] = true,
                [61919] = true,
                [61927] = true,
                [46327] = true,
                [110118] = true,
                [107141] = true,
                [126941] = true,
            },
        },
        minimap = MINIMAP_DEFAULTS,
        experienceTracker =
        {
            enabled = true,
            unlocked = false,
            scale = 100,
            opacity = 50,
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
            enabled = true, -- NAGAUI
            unlocked = false,
            layout = "stacked",
            barTextureKey = "Cloud",
            healthBarTexture = "Cloud",
            staminaBarTexture = "Cloud",
            magickaBarTexture = "Cloud",
            attachMountStamina = true,
            scale = 109,
            barHeight = 25,
            rowSpacing = 0,
            columnSpacing = 8,
            rowHealthWidth = 270,
            rowMagickaWidth = 270,
            rowStaminaWidth = 270,
            opacity = 100,
            glossEnabled = true,
            healthTextFormat = "numberAndPercent",
            magickaTextFormat = "numberAndPercent",
            staminaTextFormat = "numberAndPercent",
            healthTextPosition = "center",
            magickaTextPosition = "center",
            staminaTextPosition = "center",
            shieldOverlayEnabled = true,
            shieldTextMode = "healthAndShield",
            shieldFillOpacity = 70,
            shieldFillColor = { r = 0.95, g = 0.33, b = 0.60 },
            shieldGlowEnabled = true,
            shieldGlowOpacity = 65,
            shieldGlowColor = { r = 0.95, g = 0.56, b = 0.66 },
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
            lowResourceGlowEnabled = false,
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
            identityClassIconSize = 20,
            identityLevelIconSize = 20,
            identityNameSize = 18,
            identityNameFontKey = "trajan",
            identityNameOutline = "thick-outline",
            identityNameOpacity = 100,
            identityNameColor = { r = 1, g = 1, b = 1 },
            hud2BuffsEnabled = true,
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
                    x = 960,
                    y = 540,
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
                    x = 508,
                    y = 66,
                },
                experienceTracker =
                {
                    x = 15,
                    y = 130,
                },
                resourceBars =
                {
                    x = -406,
                    y = 226.9999694824,
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
                buffs =
                {
                    -- Defaults iguais ao NagaHUDCUSTOM (CENTER relativo ao GuiRoot).
                    player  = { point = "CENTER", rel = "CENTER", x = 0, y = 345, saved = false, format = 4 },
                    target  = { point = "CENTER", rel = "CENTER", x = 0, y = -350, saved = false, format = 4 },
                    passive = { point = "BOTTOMRIGHT", rel = "BOTTOMRIGHT", x = 0, y = 0, saved = false, format = 4 },
                    custom  = { point = "CENTER", rel = "CENTER", x = 0, y = 300, saved = false, format = 4 },
                    synergy = { point = "CENTER", rel = "CENTER", x = -300, y = 200, saved = false, format = 4 },
                    widgets = { point = "CENTER", rel = "CENTER", x = 400, y = 350, saved = false, format = 4 },
                },
                minimap = { x = 0, y = -683 },
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
    if not target or (target.nagaServerProfileMigration or target.naguiServerProfileMigration) == PROFILE_MIGRATION_VERSION then
        return
    end

    CopySavedValues(target, source, defaults)
    target.nagaServerProfileMigration = PROFILE_MIGRATION_VERSION
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
    if not target or (target.nagaServerProfileMigration or target.naguiServerProfileMigration) == PROFILE_MIGRATION_VERSION then
        return
    end

    MigrateLegacySV()

    local oldServerSettings = GetRawAccountWideSettings("NAGA_Servers", "Default")
    if oldServerSettings and oldServerSettings.servers and type(oldServerSettings.servers[serverKey]) == "table" then
        CopySavedValues(target, oldServerSettings.servers[serverKey], SERVER_PROFILE_DEFAULTS)
    end

    target.nagaServerProfileMigration = PROFILE_MIGRATION_VERSION
end

local function GetGroupCalloutsServerPositionForCharacterMigration(server, serverKey)
    local modules = server and server.modules
    local position = modules and modules.groupCallouts
    if type(position) == "table" then
        return position
    end

    MigrateLegacySV()

    local oldServerSettings = GetRawAccountWideSettings("NAGA_Servers", "Default")
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
    if not character or (character.nagaGroupCalloutsCharacterMigration or character.naguiGroupCalloutsCharacterMigration) == GROUP_CALLOUTS_CHARACTER_MIGRATION_VERSION then
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

    character.nagaGroupCalloutsCharacterMigration = GROUP_CALLOUTS_CHARACTER_MIGRATION_VERSION
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
    -- Força layout empilhado: Vida → Magicka → Vigor (sem pirâmide)
    if resourceBars.layout == nil or resourceBars.layout == "pyramid" then
        resourceBars.layout = "stacked"
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
        or (groupFrames.nagaDefaultsMigration or groupFrames.naguiDefaultsMigration) == GROUP_FRAMES_DEFAULTS_MIGRATION_VERSION then
        return
    end

    -- Carry users who received the original Group Frames default forward without
    -- overwriting any other pattern scale they may have selected themselves.
    if groupFrames.patternScale == 96 then
        groupFrames.patternScale = GROUP_FRAMES_DEFAULTS.patternScale
    end
    groupFrames.nagaDefaultsMigration = GROUP_FRAMES_DEFAULTS_MIGRATION_VERSION
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

    MigrateLegacySV()

    self.account = ZO_SavedVars:NewAccountWide("NAGA_Account", SAVED_VARS_VERSION, nil, ACCOUNT_DEFAULTS, self.serverKey)
    MigrateKnownSettings(self.account, GetRawAccountWideSettings("NAGA_Account", "Default"), ACCOUNT_DEFAULTS)

    -- Import the standalone NAGA Info Panel settings once, preserving existing user choices.
    if _G.NAGA_SAVED_VARS and type(_G.NAGA_SAVED_VARS.InfoPanel) == "table" then
        local target = self.account.modules.infoPanel
        CopySavedValues(target, _G.NAGA_SAVED_VARS.InfoPanel, INFO_PANEL_DEFAULTS)
        target.migratedStandaloneNagaInfoPanel = true
    end

    CopyDefaults(self.account, ACCOUNT_DEFAULTS)

    -- HUD 1 / HUD Central foi removido desta versão.
    if NewWorldUI and NewWorldUI.SetSettingValue then
        NewWorldUI:SetSettingValue("enabled", false)
    end

    -- O HUD 2 é o HUD padrão. Migra contas antigas que deixaram ambos desligados.
    local resourceBars = self:GetResourceBars()
    local actionBarFrames = self:GetActionBarFrames()
    if resourceBars and actionBarFrames
        and resourceBars.enabled ~= true
        and actionBarFrames.enabled ~= true
    then
        resourceBars.enabled = true
        actionBarFrames.enabled = true
    end
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
    -- HUD 2 (NAGA Resource Bars + Action Bar) is the only player HUD in this build.
    do
        local mods = self.account.modules
        if not (self.account.nagaIntegratedFramesEnabledOnce or self.account.nwuiIntegratedFramesEnabledOnce) then
            if mods.targetFrame then mods.targetFrame.enabled = true end
            if mods.castBar then mods.castBar.enabled = true end
            if mods.groupFrames then mods.groupFrames.enabled = true end
            self.account.nagaIntegratedFramesEnabledOnce = true
        end
    end
    UpgradeGroupFramesDefaults(self.account)
    UpgradeSoundChoiceLabels(self.account)
    UpgradeCastBarDefaults(self.account)
    UpgradeTargetFrameExecuteIcon(self.account)
    MigrateLegacySV()
    self.servers = ZO_SavedVars:NewAccountWide("NAGA_Servers", SAVED_VARS_VERSION, nil, SERVER_PROFILE_DEFAULTS, self.serverKey)
    MigrateServerSettings(self.servers, self.serverKey)
    self.server = self.servers
    CopyDefaults(self.server, SERVER_PROFILE_DEFAULTS)
    MigrateLegacySV()
    self.character = ZO_SavedVars:NewCharacterIdSettings("NAGA_Character", SAVED_VARS_VERSION, nil, CHARACTER_DEFAULTS, self.serverKey)
    MigrateKnownSettings(self.character, GetRawCharacterIdSettings("NAGA_Character", "Default"), CHARACTER_DEFAULTS)
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

function Settings:GetBuffs()
    return self.account.modules.buffs
end

function Settings:IsBuffsEnabled()
    return self:GetBuffs().enabled ~= false
end

function Settings:SetBuffsEnabled(value)
    self:GetBuffs().enabled = value == true
    if NAGA_UI.Buffs and NAGA_UI.Buffs.SetEnabled then
        NAGA_UI.Buffs:SetEnabled(value == true)
    end
end

function Settings:IsPlayerBuffsEnabled()
    return self:GetBuffs().showPlayer ~= false
end

function Settings:SetPlayerBuffsEnabled(value)
    self:GetBuffs().showPlayer = value == true
    if NAGA_UI.Buffs and NAGA_UI.Buffs.Refresh then
        NAGA_UI.Buffs:Refresh()
    end
end

function Settings:IsTargetBuffsEnabled()
    return self:GetBuffs().showTarget ~= false
end

function Settings:SetTargetBuffsEnabled(value)
    self:GetBuffs().showTarget = value == true
    if NAGA_UI.Buffs and NAGA_UI.Buffs.Refresh then
        NAGA_UI.Buffs:Refresh()
    end
end



function Settings:GetBuffOption(key)
    return self:GetBuffs()[key]
end

function Settings:SetBuffOption(key, value, rebuild)
    self:GetBuffs()[key] = value
    if NAGA_UI.Buffs then
        if rebuild and NAGA_UI.Buffs.RebuildPanels then
            NAGA_UI.Buffs:RebuildPanels()
        elseif NAGA_UI.Buffs.Refresh then
            NAGA_UI.Buffs:Refresh()
        end
    end
end

function Settings:AddBuffListEntry(listKey, text)
    local buffs = self:GetBuffs()
    local list = buffs[listKey]
    if type(list) ~= "table" then
        list = {}
        buffs[listKey] = list
    end
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return end
    local id = tonumber(text)
    if id then
        list[id] = true
    else
        list[text] = true
    end
    if NAGA_UI.Buffs and NAGA_UI.Buffs.Refresh then
        NAGA_UI.Buffs:Refresh()
    end
end


function Settings:ResetBuffsDefaults()
    local defaults = ACCOUNT_DEFAULTS.modules.buffs
    local buffs = self:GetBuffs()
    for k, v in pairs(defaults) do
        if k ~= "blackList" and k ~= "customBuffs" and k ~= "widgets" then
            if type(v) ~= "table" then
                buffs[k] = v
            end
        end
    end
    if NAGA_UI.Buffs and NAGA_UI.Buffs.RebuildPanels then
        NAGA_UI.Buffs:RebuildPanels()
    end
end

function Settings:GetBuffsPosition(which)
    local buffs = self.server.modules.buffs
    if not buffs[which] then
        local defaults = SERVER_PROFILE_DEFAULTS.modules.buffs[which]
        if defaults then
            buffs[which] = {
                point = defaults.point or "CENTER",
                rel = defaults.rel or "CENTER",
                x = defaults.x or 0,
                y = defaults.y or 0,
                saved = false,
                format = 4,
            }
        else
            buffs[which] = { point = "CENTER", rel = "CENTER", x = 0, y = 0, saved = false, format = 4 }
        end
    end
    return buffs[which]
end



function Settings:GetMinimap()
    return self.account.modules.minimap
end

function Settings:GetMinimapPosition()
    return self.server.modules.minimap
end



function Settings:GetExperienceTracker()
    return self.account.modules.experienceTracker
end

function Settings:GetExperienceTrackerPosition()
    return self.server.modules.experienceTracker
end

function Settings:GetResourceBars()
    local settings = self.account.modules.resourceBars
    if settings and (not settings.barTextureKey or settings.barTextureKey == "") then
        settings.barTextureKey = settings.healthBarTexture or settings.magickaBarTexture or settings.staminaBarTexture or "genericTall"
    end
    return settings
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

function Settings:GetInfoPanel()
    return self.account.modules.infoPanel
end

function Settings:GetCompanionFrame()
    return self.account.modules.companionFrame
end

function Settings:SetCompanionFrameValue(key, value)
    local companion = self:GetCompanionFrame()
    companion[key] = value
    if NAGA_UI.CompanionFrame and NAGA_UI.CompanionFrame.RefreshSettings then
        NAGA_UI.CompanionFrame:RefreshSettings()
    end
end

function Settings:SetInfoPanelValue(key, value)
    local info = self:GetInfoPanel()
    info[key] = value
    local module = NAGAInfoPainel
    if not module then return end

    if key == "enabled" and module.SetEnabled then
        module.SetEnabled(value)
    elseif key == "panelScale" and module.ApplyScale then
        module.ApplyScale()
    elseif key == "transparency" and module.ApplyAlpha then
        module.ApplyAlpha()
    elseif (key == "TextBlackOutline" or key == "FontFace" or key == "FontSize") and module.ApplyFont then
        module.ApplyFont()
    elseif key == "IconSize" and module.ApplyIconSize then
        module.ApplyIconSize()
    elseif key:find("^Hide") or key == "ClockFormat" or key == "DisableInfoColours" then
        if module.RearrangePanel then module.RearrangePanel() end
        if module.UpdateAll then module.UpdateAll() end
    elseif module.UpdateAll then
        module.UpdateAll()
    end
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
    if NAGA_UI.LootHistory then
        NAGA_UI.LootHistory:RefreshSettings()
    end
end

function Settings:SetLootHistoryUnlocked(value)
    self:GetLootHistory().unlocked = value
    if NAGA_UI.LootHistory then
        NAGA_UI.LootHistory:RefreshSettings()
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
    if (key == "scale" or key == "legacyStyle") and NAGA_UI.LootHistory then
        NAGA_UI.LootHistory:RefreshSettings()
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

function Settings:ShouldOcultarDefaultDamageNumbers()
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
    if NAGA_UI.DamageNumbers then
        NAGA_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageNumbersUnlocked(value)
    self:GetDamageNumbers().unlocked = value
    if NAGA_UI.DamageNumbers then
        NAGA_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageNumbersOcultarDefault(value)
    self:GetDamageNumbers().hideDefaultDamage = value
    if NAGA_UI.DamageNumbers then
        NAGA_UI.DamageNumbers:RefreshSettings()
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
    if NAGA_UI.DamageNumbers then
        NAGA_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageNumbersPosition(x, y)
    local position = self:GetDamageNumbersPosition()
    position.x = x
    position.y = y
end

function Settings:SetDamageDoneMinigameEnabled(value)
    self:GetDamageDoneMinigame().enabled = value
    if NAGA_UI.DamageNumbers then
        NAGA_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageDoneMinigameUnlocked(value)
    self:GetDamageDoneMinigame().unlocked = value
    if NAGA_UI.DamageNumbers then
        NAGA_UI.DamageNumbers:RefreshSettings()
    end
end

function Settings:SetDamageDoneMinigameValue(key, value)
    self:GetDamageDoneMinigame()[key] = value
    if NAGA_UI.DamageNumbers then
        NAGA_UI.DamageNumbers:RefreshSettings()
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
    if NAGA_UI.KillSound then
        NAGA_UI.KillSound:RefreshSettings()
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
    if NAGA_UI.KillSound then
        NAGA_UI.KillSound:RefreshSettings()
    end
end

function Settings:GetAchievementAlert()
    return self.account.modules.achievementAlert
end


-- Opções do AbyssQuest (modules/quest): substituem as do antigo Quest Tracker.
function Settings:GetAbyssQuestOptions()
    local ok, result = pcall(function()
        return AbyssQuest.Settings:BuildOptions()
    end)
    if ok and type(result) == "table" then
        return result
    end
    return {
        {
            type = "description",
            text = T("AbyssQuest não foi carregado (modules/quest). ") .. tostring(result),
        },
    }
end

function Settings:SetAchievementAlertValue(key, value)
    local ranges = { scale = {60, 160}, opacity = {20, 100}, duration = {3, 12}, x = {-1600, 1600}, y = {-900, 900} }
    if ranges[key] then value = ClampNumber(value, ranges[key][1], ranges[key][2]) end
    self:GetAchievementAlert()[key] = value
    if NAGA_UI.AchievementAlert then NAGA_UI.AchievementAlert:RefreshSettings() end
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
    AddOption("showPoints", "Mostrar Achievement Points", "checkbox")
    AddOption("scale", "Scale (%)", "slider", 60, 160, 5)
    AddOption("opacity", "Opacity (%)", "slider", 20, 100, 5)
    AddOption("duration", "Duration (seconds)", "slider", 3, 12, 1)
    AddOption("x", "Horizontal Position", "slider", -1600, 1600, 10)
    AddOption("y", "Vertical Position", "slider", -900, 900, 10)
    controls[#controls + 1] = {
        type = "button", name = T("Pré-visualizar Achievement"),
        func = function() if NAGA_UI.AchievementAlert then NAGA_UI.AchievementAlert:Preview() end end,
        disabled = function() return not self:GetAchievementAlert().enabled end,
    }
    controls[#controls + 1] = {
        type = "button", name = T("Redefinir posição"),
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

function Settings:GetCompanionSwitcher()
    local mod = self.account.modules.companionSwitcher
    if not mod then
        mod = {
            enabled = true,
            announceEnabled = true,
            announceMessage = 'Invocando Companheiro = "<<1>>"',
            announceColor = { r = 1, g = 1, b = 0, a = 1 },
            announceDuration = 2500,
            announceFontSize = 28,
        }
        self.account.modules.companionSwitcher = mod
    end
    return mod
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
    if NAGA_UI.SynergyAlert then
        NAGA_UI.SynergyAlert:RefreshSettings()
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
    if NAGA_UI.SynergyAlert then
        NAGA_UI.SynergyAlert:ApplyLayout()
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
    if NAGA_UI.PvP then
        NAGA_UI.PvP:RefreshSettings()
    end
end

function Settings:SetPvPUnlocked(value)
    self:GetPvP().unlocked = value == true
    if NAGA_UI.PvP then
        NAGA_UI.PvP:RefreshSettings()
    end
end

function Settings:SetPvPValue(key, value)
    self:GetPvP()[key] = value
    if NAGA_UI.PvP then
        NAGA_UI.PvP:RefreshSettings()
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
    if NAGA_UI.GroupCallouts then
        NAGA_UI.GroupCallouts:RefreshSettings()
    end
end

function Settings:SetGroupCalloutsUnlocked(value)
    self:GetGroupCallouts().unlocked = value
    if NAGA_UI.GroupCallouts then
        NAGA_UI.GroupCallouts:RefreshSettings()
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
    if NAGA_UI.GroupCallouts then
        NAGA_UI.GroupCallouts:RefreshSettings()
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

    if NAGA_UI.GroupCallouts then
        NAGA_UI.GroupCallouts:RefreshSettings()
    end
end

function Settings:SetGroupCalloutsPosition(x, y)
    local position = self:GetGroupCalloutsPosition()
    position.x = x
    position.y = y
end

function Settings:PreviewGroupCalloutsSound()
    if NAGA_UI.GroupCallouts and NAGA_UI.GroupCallouts.PreviewSound then
        NAGA_UI.GroupCallouts:PreviewSound()
    end
end

function Settings:PreviewGroupCallout()
    if NAGA_UI.GroupCallouts and NAGA_UI.GroupCallouts.PreviewRegular then
        NAGA_UI.GroupCallouts:PreviewRegular()
    end
end

function Settings:PreviewGroupCalloutLeader()
    if NAGA_UI.GroupCallouts and NAGA_UI.GroupCallouts.PreviewLeader then
        NAGA_UI.GroupCallouts:PreviewLeader()
    end
end

function Settings:SetGroupCalloutsSettingsPreviewActive(active)
    if NAGA_UI.GroupCallouts and NAGA_UI.GroupCallouts.SetSettingsPreviewActive then
        NAGA_UI.GroupCallouts:SetSettingsPreviewActive(active)
    end
end

function Settings:PreviewDamageNumberCritSound()
    if NAGA_UI.DamageNumbers and NAGA_UI.DamageNumbers.PreviewCriticalSound then
        NAGA_UI.DamageNumbers:PreviewCriticalSound()
    end
end

function Settings:PreviewDamageDoneMinigame(showTiers)
    if NAGA_UI.DamageNumbers and NAGA_UI.DamageNumbers.PreviewDamageDoneMinigame then
        NAGA_UI.DamageNumbers:PreviewDamageDoneMinigame(showTiers)
    end
end

function Settings:PreviewKillSound()
    if NAGA_UI.KillSound and NAGA_UI.KillSound.PreviewSound then
        NAGA_UI.KillSound:PreviewSound()
    end
end

function Settings:PreviewPvPChain()
    if NAGA_UI.PvP and NAGA_UI.PvP.PreviewChain then
        NAGA_UI.PvP:PreviewChain()
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

function Settings:IsActionBarCooldownTextEnabled()
    return self:GetActionBarFrames().cooldownTextEnabled ~= false
end





function Settings:IsImmersiveTeleportEnabled()
    return self.account.modules.immersiveTeleport.enabled
end

function Settings:SetImmersiveTeleportEnabled(value)
    self.account.modules.immersiveTeleport.enabled = value
    if NAGA_UI.ImmersiveTeleport then
        NAGA_UI.ImmersiveTeleport:RefreshSettings()
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
    if NAGA_UI.AdventureCamera then
        NAGA_UI.AdventureCamera:RefreshSettings()
    end
end

function Settings:SetAdventureCameraValue(key, value)
    self:GetAdventureCamera()[key] = value
    if NAGA_UI.AdventureCamera then
        NAGA_UI.AdventureCamera:RefreshSettings()
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

    if NAGA_UI.AdventureCamera then
        NAGA_UI.AdventureCamera:RefreshSettings()
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

    if NAGA_UI.AdventureCamera then
        NAGA_UI.AdventureCamera:RefreshSettings()
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
    if NAGA_UI.CastBar then
        NAGA_UI.CastBar:RefreshSettings()
    end
end

function Settings:SetCastBarUnlocked(value)
    self:GetCastBar().unlocked = value
    if NAGA_UI.CastBar then
        NAGA_UI.CastBar:RefreshSettings()
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
    if NAGA_UI.CastBar then
        NAGA_UI.CastBar:RefreshSettings()
    end
end

function Settings:SetCastBarPosition(x, y)
    local position = self:GetCastBarPosition()
    position.x = x
    position.y = y
end

function Settings:ResetCastBarPosition()
    local position = self:GetCastBarPosition()
    local defaults = SERVER_PROFILE_DEFAULTS.modules.castBar
    position.x = defaults.x
    position.y = defaults.y
    if NAGA_UI.CastBar and NAGA_UI.CastBar.RefreshSettings then
        NAGA_UI.CastBar:RefreshSettings()
    end
end

function Settings:GetCastBarColor(key)
    local settings = self:GetCastBar()
    return settings[key] or ACCOUNT_DEFAULTS.modules.castBar[key]
end

function Settings:SetCastBarColor(key, r, g, b)
    local settings = self:GetCastBar()
    settings[key] = settings[key] or {}
    settings[key].r = r
    settings[key].g = g
    settings[key].b = b
    if NAGA_UI.CastBar then
        NAGA_UI.CastBar:RefreshSettings()
    end
end

function Settings:PreviewCastBar()
    if NAGA_UI.CastBar and NAGA_UI.CastBar.Preview then
        NAGA_UI.CastBar:Preview()
    end
end

function Settings:IsCompassEnabled()
    return self:GetCompass().enabled
end

function Settings:SetCompassEnabled(value)
    self:GetCompass().enabled = value
    if NAGA_UI.Compass then
        NAGA_UI.Compass:RefreshSettings()
    end
end

function Settings:GetCompassStyle()
    local style = self:GetCompass().style
    if style ~= "ds3" then
        return "naga"
    end
    return style
end

function Settings:SetCompassStyle(value)
    if value ~= "ds3" then
        value = "naga"
    end
    self:GetCompass().style = value
    if NAGA_UI.Compass then
        NAGA_UI.Compass:RefreshSettings()
    end
end

function Settings:IsWorldEventCompassEnabled()
    local c = self:GetCompass()
    if c.worldEventPin == nil then return true end
    return c.worldEventPin == true
end

function Settings:SetWorldEventCompassEnabled(value)
    self:GetCompass().worldEventPin = value == true
end

function Settings:IsExperienceTrackerEnabled()
    return self:GetExperienceTracker().enabled
end

function Settings:IsExperienceTrackerUnlocked()
    return self:GetExperienceTracker().unlocked
end

function Settings:ShouldExperienceTrackerOcultarStockProgressBar()
    return self:GetExperienceTracker().hideStockProgressBar
end

function Settings:SetExperienceTrackerEnabled(value)
    self:GetExperienceTracker().enabled = value
    if NAGA_UI.ExperienceTracker then
        NAGA_UI.ExperienceTracker:RefreshSettings()
    end
end

function Settings:SetExperienceTrackerUnlocked(value)
    self:GetExperienceTracker().unlocked = value
    if NAGA_UI.ExperienceTracker then
        NAGA_UI.ExperienceTracker:RefreshSettings()
    end
end

function Settings:SetExperienceTrackerValue(key, value)
    if key == "chunkSoundKey" or key == "levelUpSoundKey" then
        value = NormalizeSoundChoice(value)
    end

    self:GetExperienceTracker()[key] = value
    if NAGA_UI.ExperienceTracker then
        NAGA_UI.ExperienceTracker:RefreshSettings()
    end
end

function Settings:SetExperienceTrackerPosition(x, y)
    local position = self:GetExperienceTrackerPosition()
    position.x = x
    position.y = y
end

function Settings:PreviewExperienceTracker()
    if NAGA_UI.ExperienceTracker and NAGA_UI.ExperienceTracker.PreviewGain then
        NAGA_UI.ExperienceTracker:PreviewGain()
    end
end

function Settings:IsResourceBarsEnabled()
    return self:GetResourceBars().enabled
end

function Settings:IsResourceBarsUnlocked()
    return self:GetResourceBars().unlocked
end


function Settings:SetResourceBarsUnlocked(value)
    self:GetResourceBars().unlocked = value
    if NAGA_UI.ResourceBars then
        NAGA_UI.ResourceBars:RefreshSettings()
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

    -- Keep legacy per-bar texture keys and NAGA/NewWorldUI in sync when the
    -- unified bar texture changes, so Target and Companion pick up the same DDS.
    if key == "barTextureKey" then
        local rb = self:GetResourceBars()
        rb.healthBarTexture = value
        rb.magickaBarTexture = value
        rb.staminaBarTexture = value
        if NewWorldUI and NewWorldUI.SetSettingValue then
            -- Avoid re-entrancy: SetSettingValue also writes barTextureKey back.
            if NewWorldUI.savedVars then
                NewWorldUI.savedVars.barTextureKey = value
            end
            if NewWorldUI.ApplyResourceBarTextures then
                NewWorldUI:ApplyResourceBarTextures()
            elseif NewWorldUI.ApplySettings then
                NewWorldUI:ApplySettings()
            end
        end
        if NAGA_UI.TargetFrame and NAGA_UI.TargetFrame.RefreshSettings then
            NAGA_UI.TargetFrame:RefreshSettings()
        end
        if NAGA_UI.CompanionFrame and NAGA_UI.CompanionFrame.RefreshSettings then
            NAGA_UI.CompanionFrame:RefreshSettings()
        end
    end

    if NAGA_UI.ResourceBars then
        NAGA_UI.ResourceBars:RefreshSettings()
    end
end

function Settings:GetResourceBarsColor(key)
    local color = self:GetResourceBars()[key]
    local fallback = ACCOUNT_DEFAULTS.modules.resourceBars[key]
    return color or fallback or { r = 1, g = 1, b = 1 }
end

function Settings:SetResourceBarsColor(key, r, g, b)
    local settings = self:GetResourceBars()
    settings[key] = settings[key] or {}
    settings[key].r = r
    settings[key].g = g
    settings[key].b = b
    if NAGA_UI.ResourceBars then
        NAGA_UI.ResourceBars:RefreshSettings()
    end
end

function Settings:SetResourceBarsPosition(x, y)
    local position = self:GetResourceBarsPosition()
    position.x = x
    position.y = y
end

function Settings:SetResourceBarsSettingsPreviewActive(active)
    if NAGA_UI.ResourceBars and NAGA_UI.ResourceBars.SetSettingsPreviewActive then
        NAGA_UI.ResourceBars:SetSettingsPreviewActive(active)
    end
end

function Settings:IsGroupFramesEnabled()
    return self:GetGroupFrames().enabled ~= false
end


function Settings:SetGroupFramesEnabled(value)
    self:GetGroupFrames().enabled = value == true
    if NAGA_UI.GroupFrames then
        NAGA_UI.GroupFrames:RefreshSettings()
    end
end


function Settings:SetGroupFramesValue(key, value)
    self:GetGroupFrames()[key] = value
    if NAGA_UI.GroupFrames then
        NAGA_UI.GroupFrames:RefreshSettings()
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
    if NAGA_UI.GroupFrames then
        NAGA_UI.GroupFrames:RefreshSettings()
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
    if NAGA_UI.GroupFrames then
        NAGA_UI.GroupFrames:RefreshSettings()
    end
end


function Settings:ResetGroupFramesPosition(mode)
    local position = self:GetGroupFramesPosition(mode)
    local defaults = SERVER_PROFILE_DEFAULTS.modules.groupFrames[mode]
    position.x = defaults.x
    position.y = defaults.y
    position.custom = false
end

function Settings:SetGroupFramesSettingsPreviewActive(active)
    if NAGA_UI.GroupFrames and NAGA_UI.GroupFrames.SetSettingsPreviewActive then
        NAGA_UI.GroupFrames:SetSettingsPreviewActive(active)
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
    if NAGA_UI.TargetFrame then
        NAGA_UI.TargetFrame:RefreshSettings()
    end
end

function Settings:SetTargetFrameUnlocked(value)
    self:GetTargetFrame().unlocked = value == true
    if NAGA_UI.TargetFrame and NAGA_UI.TargetFrame.SetUnlocked then
        NAGA_UI.TargetFrame:SetUnlocked(value)
    elseif NAGA_UI.TargetFrame then
        NAGA_UI.TargetFrame:RefreshSettings()
    end
end

function Settings:SetTargetFrameValue(key, value)
    self:GetTargetFrame()[key] = value
    if NAGA_UI.TargetFrame then
        NAGA_UI.TargetFrame:RefreshSettings()
    end
    -- Shared text sizes refresh player identity above health.
    if (key == "nameTextSize" or key == "levelTextSize" or key == "textFontKey" or key == "textOutline")
        and NAGA_UI.ResourceBars and NAGA_UI.ResourceBars.UpdateIdentityDisplay then
        NAGA_UI.ResourceBars:UpdateIdentityDisplay()
    end
    if key == "nameTextSize" and NewWorldUI and NewWorldUI.ApplyIdentityFont then
        NewWorldUI:ApplyIdentityFont()
        if NewWorldUI.UpdateIdentityDisplay then
            NewWorldUI:UpdateIdentityDisplay()
        end
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
    if NAGA_UI.TargetFrame then
        NAGA_UI.TargetFrame:RefreshSettings()
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
    if NAGA_UI.TargetFrame then
        NAGA_UI.TargetFrame:RefreshSettings()
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
    if NAGA_UI.TargetFrame and NAGA_UI.TargetFrame.ResetPosition then
        NAGA_UI.TargetFrame:ResetPosition()
    else
        self:ResetTargetFramePosition()
    end
end

function Settings:SetTargetFrameSettingsPreviewActive(active)
    if NAGA_UI.TargetFrame and NAGA_UI.TargetFrame.SetSettingsPreviewActive then
        NAGA_UI.TargetFrame:SetSettingsPreviewActive(active)
    end
end

function Settings:ReplayTargetFramePreviewEffects()
    if NAGA_UI.TargetFrame and NAGA_UI.TargetFrame.ReplayPreviewEffects then
        NAGA_UI.TargetFrame:ReplayPreviewEffects()
    end
end

function Settings:ReplayGroupFramesPreviewEffects()
    if NAGA_UI.GroupFrames and NAGA_UI.GroupFrames.ReplayPreviewEffects then
        NAGA_UI.GroupFrames:ReplayPreviewEffects()
    end
end


function Settings:ShouldHardcoreOcultarCompass()
    return self:GetHardcoreSupport().hideCompass == true
end

function Settings:SetHardcoreOcultarCompass(value)
    self:GetHardcoreSupport().hideCompass = value == true
    if NAGA_UI.Compass then
        NAGA_UI.Compass:RefreshSettings()
    end
end

function Settings:ShouldHardcoreOcultarHealthResourceBar()
    return self:GetHardcoreSupport().hideHealthResourceBar == true
end

function Settings:SetHardcoreOcultarHealthResourceBar(value)
    self:GetHardcoreSupport().hideHealthResourceBar = value == true
    if NAGA_UI.ResourceBars then
        NAGA_UI.ResourceBars:RefreshSettings()
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

        local submenu = AbyssUI_HUD2_ResourceBarsSubmenu or NAGA_UI_HUD2_ResourceBarsSubmenu or NAGA_UI_ResourceBarsSubmenu
        if not submenu or submenu.nagaPreviewHooked then
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

        submenu.nagaPreviewHooked = true
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

        local submenu = NAGA_UI_GroupCalloutsSubmenu
        if not submenu or submenu.nagaPreviewHooked then
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

        submenu.nagaPreviewHooked = true
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

        local submenu = NAGA_UI_GroupFramesSubmenu
        if not submenu or submenu.nagaPreviewHooked then
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

        submenu.nagaPreviewHooked = true
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

        local submenu = NAGA_UI_TargetFrameSubmenu
        if not submenu or submenu.nagaPreviewHooked then
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

        submenu.nagaPreviewHooked = true
        UpdatePreview()
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel and panel:GetName() == panelName then
            self:SetTargetFrameSettingsPreviewActive(false)
        end
    end)
end


function Settings:BuildCastBarOptions()
    local controls = {}
    local function Add(control) controls[#controls + 1] = control end
    local function Disabled() return not self:IsCastBarEnabled() end
    local function Header(name) Add({ type = "header", name = name }) end
    local function Description(text) Add({ type = "description", text = text }) end
    local function Checkbox(name, key, tooltip, disabled)
        Add(
        {
            type = "checkbox",
            name = name,
            tooltip = tooltip,
            getFunc = function() return self:GetCastBar()[key] end,
            setFunc = function(value) self:SetCastBarValue(key, value) end,
            disabled = disabled or Disabled,
            default = ACCOUNT_DEFAULTS.modules.castBar[key],
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
            getFunc = function() return self:GetCastBar()[key] end,
            setFunc = function(value) self:SetCastBarValue(key, value) end,
            disabled = disabled or Disabled,
            default = ACCOUNT_DEFAULTS.modules.castBar[key],
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
            getFunc = function() return self:GetCastBar()[key] end,
            setFunc = function(value) self:SetCastBarValue(key, value) end,
            disabled = disabled or Disabled,
            default = ACCOUNT_DEFAULTS.modules.castBar[key],
        })
    end
    local function ColorPicker(name, key, tooltip, disabled)
        Add(
        {
            type = "colorpicker",
            name = name,
            tooltip = tooltip,
            getFunc = function()
                local color = self:GetCastBarColor(key)
                return color.r, color.g, color.b, 1
            end,
            setFunc = function(r, g, b) self:SetCastBarColor(key, r, g, b) end,
            disabled = disabled or Disabled,
            default = function()
                local color = ACCOUNT_DEFAULTS.modules.castBar[key]
                return color.r, color.g, color.b, 1
            end,
        })
    end

    Header(T("Geral e Tamanho"))
    Add({
        type = "checkbox",
        name = T("Ativar Cast Skill"),
        tooltip = T("Mostrar a barra de carregamento/cast da habilidade ativa."),
        getFunc = function() return self:IsCastBarEnabled() end,
        setFunc = function(value) self:SetCastBarEnabled(value) end,
        default = ACCOUNT_DEFAULTS.modules.castBar.enabled,
    })
    Add({
        type = "checkbox",
        name = T("Desbloquear posição"),
        tooltip = T("Libera a área de arraste do Cast Skill. A posição é salva neste servidor."),
        getFunc = function() return self:IsCastBarUnlocked() end,
        setFunc = function(value) self:SetCastBarUnlocked(value) end,
        disabled = Disabled,
        default = ACCOUNT_DEFAULTS.modules.castBar.unlocked,
    })
    Add({
        type = "button",
        name = T("Redefinir posição"),
        tooltip = T("Voltar o Cast Skill para a posição padrão."),
        func = function() self:ResetCastBarPosition() end,
        disabled = Disabled,
        width = "half",
    })
    Slider(T("Scale"), "scale", "Tamanho geral do Cast Skill.", 70, 160, 1)
    Slider(T("Largura da barra"), "width", "Largura total da barra do Cast Skill.", 220, 620, 5)
    Slider(T("Altura da barra"), "height", "Altura/espessura visual da barra do Cast Skill.", 18, 48, 1)
    Slider(T("Opacidade"), "opacity", "Transparência geral do Cast Skill.", 10, 100, 1)

    Header(T("Borda e Aparência"))
    Checkbox(T("Borda NAGA"), "rpgBorder", "Ativa a moldura metálica do Cast Skill.")
    Slider(T("Espessura da borda"), "borderWidth", "Controla a espessura da moldura da barra.", 0, 8, 1)
    Checkbox(T("Brilho interno"), "glossEnabled", "Ativa o brilho/reflexo dentro da barra.")
    Slider(T("Sombra interna"), "innerShadowAlpha", "Intensidade da sombra interna.", 0, 100, 1)
    Slider(T("Sombra externa"), "outerShadowAlpha", "Intensidade da sombra ao redor da barra.", 0, 100, 1)
    ColorPicker("Cor do texto", "textColor", "Cor dos textos do Cast Skill.")

    Header(T("Texto"))
    Dropdown(T("Fonte"), "textFontKey", nil,
        { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
        { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" })
    Slider(T("Tamanho do texto"), "textSize", "Tamanho da fonte do nome e do tempo do cast.", 8, 30, 1)
    Dropdown(T("Contorno do texto"), "textOutline", nil,
        { "None", "Soft Thin", "Soft Thick", "Thick Outline" },
        { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" })
    Slider(T("Opacidade do texto"), "textOpacity", nil, 10, 100, 1)
    Dropdown(T("Informação exibida"), "textMode", "Escolha quais informações aparecem na barra.",
        { "Nome + Tempo", "Somente Nome", "Somente Tempo", "Desligado" },
        { "nameAndTime", "nameOnly", "timerOnly", "off" })

    Header(T("Ícone e Cast"))
    Checkbox(T("Mostrar ícone da habilidade"), "showIcon", "Mostrar o ícone da habilidade que está sendo usada.")
    Checkbox(T("Mostrar divisões de tempo"), "showTicks", "Mostrar as marcações de tempo na barra.")
    Slider(T("Intensidade da animação"), "animationIntensity", "Controla os brilhos e efeitos do Cast Skill.", 0, 160, 1)
    Add({
        type = "button",
        name = T("Pré-visualizar Cast Skill"),
        func = function() self:PreviewCastBar() end,
        disabled = Disabled,
        width = "half",
    })
    Description(T("As configurações de tamanho, altura, escala, borda, sombras e texto são salvas junto com o NAGA Modules e não alteram o sistema nativo de Edit HUD."))

    return controls
end

function Settings:BuildInfoPanelOptions()
    local controls = {}
    local defaults = INFO_PANEL_DEFAULTS
    local function Add(control) controls[#controls + 1] = control end
    local function Disabled() return not self:GetInfoPanel().enabled end
    local function Set(key, value) self:SetInfoPanelValue(key, value) end

    Add({ type = "description", text = T("Painel de informações com Latency, FPS, memória, relógio, Soul Gems, montaria, armadura, armas, Bags e Gold. A posição é controlada exclusivamente pelo Edit HUD do ESO.") })
    Add({ type = "checkbox", name = T("Ativar painel"), tooltip = T("Mostra ou esconde o NAGA Info Panel."), getFunc = function() return self:GetInfoPanel().enabled end, setFunc = function(v) Set("enabled", v) end, default = defaults.enabled })
    Add({ type = "slider", name = T("Escala (%)"), tooltip = T("Tamanho geral do painel."), min = 50, max = 200, step = 5, getFunc = function() return self:GetInfoPanel().panelScale end, setFunc = function(v) Set("panelScale", v) end, disabled = Disabled, default = defaults.panelScale })
    Add({ type = "slider", name = T("Transparência (%)"), tooltip = T("100 = opaco."), min = 10, max = 100, step = 5, getFunc = function() return self:GetInfoPanel().transparency end, setFunc = function(v) Set("transparency", v) end, disabled = Disabled, default = defaults.transparency })

    local fonts = (NAGAInfoPainel and NAGAInfoPainel.FontList) or {
        "ZoFontGame", "ZoFontGameBold", "ZoFontGameOutline", "ZoFontGameShadow",
        "ZoFontGameSmall", "ZoFontChat", "ZoFontChatBold", "ZoFontWindowTitle",
        "ZoFontHeader", "ZoFontHeader2", "ZoFontHeader3", "ZoFontCallout3",
        "ZoFontBookPaper", "ZoFontTooltipTitle",
    }
    Add({ type = "dropdown", name = T("Fonte"), tooltip = T("Fonte usada em todos os textos do painel."), choices = fonts, getFunc = function() return self:GetInfoPanel().FontFace end, setFunc = function(v) Set("FontFace", v) end, disabled = Disabled, default = defaults.FontFace })
    Add({ type = "slider", name = T("Tamanho da fonte"), tooltip = T("Tamanho dos textos do painel."), min = 12, max = 28, step = 1, getFunc = function() return self:GetInfoPanel().FontSize end, setFunc = function(v) Set("FontSize", v) end, disabled = Disabled, default = defaults.FontSize })
    Add({ type = "slider", name = T("Tamanho dos ícones"), tooltip = T("Tamanho dos ícones do painel."), min = 12, max = 36, step = 1, getFunc = function() return self:GetInfoPanel().IconSize end, setFunc = function(v) Set("IconSize", v) end, disabled = Disabled, default = defaults.IconSize })
    Add({ type = "checkbox", name = T("Esconder em combate"), tooltip = T("Oculta o painel durante combate."), getFunc = function() return self:GetInfoPanel().HideInCombat end, setFunc = function(v) Set("HideInCombat", v) end, disabled = Disabled, default = defaults.HideInCombat })
    Add({ type = "checkbox", name = T("Desativar cores dinâmicas"), tooltip = T("FPS, Latency e Memória ficam brancos."), getFunc = function() return self:GetInfoPanel().DisableInfoColours end, setFunc = function(v) Set("DisableInfoColours", v) end, disabled = Disabled, default = defaults.DisableInfoColours })
    Add({ type = "checkbox", name = T("Borda preta nos textos e números"), tooltip = T("Ativa ou desativa a borda preta nas letras e números do Info Panel."), getFunc = function() return self:GetInfoPanel().TextBlackOutline end, setFunc = function(v) Set("TextBlackOutline", v) end, disabled = Disabled, default = defaults.TextBlackOutline })

    Add({ type = "header", name = T("Elementos do painel") })
    local function Toggle(key, label, tooltip)
        Add({ type = "checkbox", name = label, tooltip = tooltip, getFunc = function() return not self:GetInfoPanel()[key] end, setFunc = function(v) Set(key, not v) end, disabled = Disabled, default = not defaults[key] })
    end
    Toggle("HideLatency", "Mostrar Latency", "Ping em ms.")
    Toggle("HideFPS", "Mostrar FPS")
    Toggle("HideMemory", "Mostrar Memória (Lua)", "Uso aproximado de memória Lua.")
    Toggle("HideClock", "Mostrar Relógio")
    Add({ type = "editbox", name = T("Formato do relógio"), tooltip = T("Use HH:MM:SS ou HH:MM."), getFunc = function() return self:GetInfoPanel().ClockFormat end, setFunc = function(v) Set("ClockFormat", v) end, disabled = function() return Disabled() or self:GetInfoPanel().HideClock end, default = defaults.ClockFormat })
    Toggle("HideGems", "Mostrar Soul Gems", "Contagem de Soul Gems cheias.")
    Toggle("HideMount", "Mostrar Mount Feed Timer", "Tempo até a próxima melhoria da montaria.")
    Toggle("HideArmour", "Mostrar Durabilidade da Armadura")
    Toggle("HideWeapons", "Mostrar Carga das Armas")
    Toggle("HideBags", "Mostrar Espaço das Bags")
    Toggle("HideGold", "Mostrar Gold")
    Add({ type = "description", text = T("Mover: ESC → Editar HUD do ESO → NAGA Info Panel. O módulo não usa mover antigo nem salva coordenadas próprias.") })
    return controls
end

function Settings:BuildCompanionFrameOptions()
    local defaults = ACCOUNT_DEFAULTS.modules.companionFrame
    local function Disabled() return self:GetCompanionFrame().enabled ~= true end
    local function Set(key, value) self:SetCompanionFrameValue(key, value) end
    local function ColorPicker(name, key)
        return
        {
            type = "colorpicker",
            name = name,
            getFunc = function()
                local color = self:GetCompanionFrame()[key] or defaults[key]
                return color.r, color.g, color.b, color.a or 1
            end,
            setFunc = function(r, g, b, a)
                Set(key, { r = r, g = g, b = b, a = a or 1 })
            end,
            disabled = Disabled,
            default = function()
                local color = defaults[key]
                return color.r, color.g, color.b, color.a or 1
            end,
        }
    end

    local controls =
    {
        {
            type = "checkbox",
            name = T("Ativar Companheiro"),
            tooltip = T("Mostra o Companion Frame do NAGA Modules."),
            getFunc = function() return self:GetCompanionFrame().enabled end,
            setFunc = function(value) Set("enabled", value == true) end,
            default = defaults.enabled,
        },
        {
            type = "slider",
            name = T("Largura"),
            min = 120, max = 500, step = 5,
            getFunc = function() return self:GetCompanionFrame().width end,
            setFunc = function(value) Set("width", value) end,
            disabled = Disabled,
            default = defaults.width,
        },
        {
            type = "slider",
            name = T("Altura"),
            min = 60, max = 180, step = 5,
            getFunc = function() return self:GetCompanionFrame().height end,
            setFunc = function(value) Set("height", value) end,
            disabled = Disabled,
            default = defaults.height,
        },
        {
            type = "slider",
            name = T("Escala (%)"),
            min = 70, max = 160, step = 5,
            getFunc = function() return self:GetCompanionFrame().scale end,
            setFunc = function(value) Set("scale", value) end,
            disabled = Disabled,
            default = defaults.scale,
        },
        {
            type = "checkbox",
            name = T("Mostrar nível"),
            getFunc = function() return self:GetCompanionFrame().showLevel end,
            setFunc = function(value) Set("showLevel", value == true) end,
            disabled = Disabled,
            default = defaults.showLevel,
        },
        {
            type = "checkbox",
            name = T("Mostrar Rapport"),
            getFunc = function() return self:GetCompanionFrame().showRapport end,
            setFunc = function(value) Set("showRapport", value == true) end,
            disabled = Disabled,
            default = defaults.showRapport,
        },
        {
            type = "checkbox",
            name = T("Mostrar XP"),
            getFunc = function() return self:GetCompanionFrame().showXP end,
            setFunc = function(value) Set("showXP", value == true) end,
            disabled = Disabled,
            default = defaults.showXP,
        },
        {
            type = "checkbox",
            name = T("Mostrar botões"),
            tooltip = T("Mostra os botões para trocar e dispensar o companheiro."),
            getFunc = function() return self:GetCompanionFrame().showButtons end,
            setFunc = function(value) Set("showButtons", value == true) end,
            disabled = Disabled,
            default = defaults.showButtons,
        },
        {
            type = "slider",
            name = T("Opacidade em combate (%)"),
            min = 0, max = 100, step = 5,
            getFunc = function() return self:GetCompanionFrame().opacityIn end,
            setFunc = function(value) Set("opacityIn", value) end,
            disabled = Disabled,
            default = defaults.opacityIn,
        },
        {
            type = "slider",
            name = T("Opacidade fora de combate (%)"),
            min = 0, max = 100, step = 5,
            getFunc = function() return self:GetCompanionFrame().opacityOut end,
            setFunc = function(value) Set("opacityOut", value) end,
            disabled = Disabled,
            default = defaults.opacityOut,
        },
        { type = "header", name = T("Fontes") },
        {
            type = "dropdown",
            name = T("Fonte do nome"),
            choices = { "ESO Standard", "ESO Bold", "Prose Antique", "Handwritten", "Trajan Pro", "Futura Standard", "Futura Bold", "Univers 57", "Univers 67", "Gamepad Standard", "Gamepad Bold", "Chat" },
            choicesValues = { "standard", "esobold", "antique", "handwritten", "trajan", "futura", "futurabold", "univers", "universbold", "gamepad_medium", "gamepad_bold", "chat" },
            getFunc = function() return self:GetCompanionFrame().nameFontKey end,
            setFunc = function(value) Set("nameFontKey", value) end,
            disabled = Disabled,
            default = defaults.nameFontKey,
        },
        {
            type = "dropdown",
            name = T("Fonte dos valores"),
            choices = { "ESO Standard", "ESO Bold", "Prose Antique", "Handwritten", "Trajan Pro", "Futura Standard", "Futura Bold", "Univers 57", "Univers 67", "Gamepad Standard", "Gamepad Bold", "Chat" },
            choicesValues = { "standard", "esobold", "antique", "handwritten", "trajan", "futura", "futurabold", "univers", "universbold", "gamepad_medium", "gamepad_bold", "chat" },
            getFunc = function() return self:GetCompanionFrame().valueFontKey end,
            setFunc = function(value) Set("valueFontKey", value) end,
            disabled = Disabled,
            default = defaults.valueFontKey,
        },
        {
            type = "slider",
            name = T("Tamanho da fonte"),
            min = 8, max = 36, step = 1,
            getFunc = function() return self:GetCompanionFrame().fontSize end,
            setFunc = function(value) Set("fontSize", value) end,
            disabled = Disabled,
            default = defaults.fontSize,
        },
        {
            type = "dropdown",
            name = T("Contorno da fonte"),
            choices = { "None", "Soft Thin", "Soft Thick", "Thick Outline" },
            choicesValues = { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" },
            getFunc = function() return self:GetCompanionFrame().textOutline end,
            setFunc = function(value) Set("textOutline", value) end,
            disabled = Disabled,
            default = defaults.textOutline,
        },
        { type = "header", name = T("Cores") },
        ColorPicker("Cor da vida", "healthColor"),
        ColorPicker("Cor do Rapport", "rapportColor"),
        ColorPicker("Cor do XP", "xpColor"),
        ColorPicker("Cor do texto", "textColor"),
        ColorPicker("Cor da borda", "borderColor"),
        {
            type = "checkbox",
            name = T("Cantos arredondados"),
            getFunc = function() return self:GetCompanionFrame().roundedBarCorners end,
            setFunc = function(value) Set("roundedBarCorners", value == true) end,
            disabled = Disabled,
            default = defaults.roundedBarCorners,
        },
        {
            type = "slider",
            name = T("Espessura / Inset da barra"),
            min = 0, max = 10, step = 1,
            getFunc = function() return self:GetCompanionFrame().barInset end,
            setFunc = function(value) Set("barInset", value) end,
            disabled = Disabled,
            default = defaults.barInset,
        },
        {
            type = "description",
            text = T("Mover: ESC → Editar HUD do ESO → NAGA Companion Frame. A posição é salva pelo sistema nativo do ESO; não existe mover antigo neste módulo."),
        },
    }
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

    Header(T("General & Position"))
    Add(
    {
        type = "checkbox",
        name = T("Enable Target Frame"),
        tooltip = T("Replace ESO's reticle target frame with NAGA's compact target frame."),
        getFunc = function() return self:IsTargetFrameEnabled() end,
        setFunc = function(value) self:SetTargetFrameEnabled(value) end,
        default = TARGET_FRAME_DEFAULTS.enabled,
    })
    Add(
    {
        type = "checkbox",
        name = T("Desbloquear posição"),
        tooltip = T("Mostrar a drag handle. The position is saved for this server."),
        getFunc = function() return self:IsTargetFrameUnlocked() end,
        setFunc = function(value) self:SetTargetFrameUnlocked(value) end,
        disabled = Disabled,
        default = TARGET_FRAME_DEFAULTS.unlocked,
    })
    Add(
    {
        type = "button",
        name = T("Redefinir posição"),
        tooltip = T("Move the Target Frame back to its default top-center position."),
        func = function() self:ResetActiveTargetFramePosition() end,
        disabled = Disabled,
        width = "half",
    })
    Slider(T("Scale"), "scale", nil, 70, 160, 1)
    Slider(T("Bar Width"), "width", nil, 180, 700, 5)
    Slider(T("Bar Height"), "barHeight", nil, 10, 48, 1)
    Slider(T("Opacity"), "opacity", nil, 10, 100, 1)

    Header(T("Target Information"))
    Checkbox(T("Mostrar Class Icon"), "showClass", "Mostrar the player's class icon beside their name.")
    Slider(T("Class Icon Size"), "classIconSize", "Tamanho do ícone de classe ao lado do nome.", 12, 36, 1,
        function() return Disabled() or self:GetTargetFrame().showClass == false end)
    Slider(T("CP Icon Size"), "championIconSize", "Tamanho do ícone de Champion Points no badge de level/CP (independente do texto).", 8, 36, 1,
        function() return Disabled() or self:GetTargetFrame().showLevel == false end)
    Checkbox(T("Mostrar Veterancy Icon"), "showVeterancyIcon",
        "Mostrar the active Veterancy rank icon for players, or their alliance-colored Alliance War rank when Veterancy is unavailable.")
    Checkbox(T("Mostrar AVA Rank"), "showTitle",
        "Mostrar o rank de Alliance War (nome + ícone) centralizado abaixo da barra de target, só em jogadores.")
    Slider(T("AVA Rank Text Size"), "titleTextSize", "Tamanho da fonte do nome do rank abaixo da barra.", 10, 24, 1)

    Header(T("Execute Indicator"))
    Checkbox(T("Mostrar Execute Icon"), "showExecuteIcon", "Mostrar a finisher indicator inside the bar for living, attackable targets at execute health.")
    Dropdown(T("Execute Icon"), "executeIconStyle", "Choose the symbol used for the execute indicator.",
        { "White Skull", "Champion", "Dark Anchors", "Alliance General", "Alliance Legate", "Retrait", "Scoring", "Death Down", "Death Over" },
        { "whiteSkull", "champion", "darkAnchors", "avaGeneral", "avaLegate", "retrait", "scoring", "deathDown", "deathOver" },
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)
    Slider(T("Icon Scale"), "executeIconScale", "Scale the execute icon independently from the target frame.", 50, 200, 5,
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)
    Checkbox(T("Blink Animation"), "executeBlinkEnabled", "Continuously pulse the execute icon while it is visible.",
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)
    Slider(T("Execute Threshold"), "executeThreshold", "Mostrar the icon at or below this health percentage.", 18, 33, 1,
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)
    Dropdown(T("Execute Position"), "executePosition", "Left and right reserve room for the adjacent health label.",
        { "Left", "Center", "Right" }, { "left", "center", "right" },
        function() return Disabled() or self:GetTargetFrame().showExecuteIcon == false end)

    Header(T("Target Colors"))
    Dropdown(T("Non-Player Target Color"), "npcColorMode",
        "Static Red uses your chosen color. Threat / Reaction uses ESO's civilian, allied, neutral, and hostile disposition colors.",
        { "Static Red", "Threat / Reaction" }, { "static", "reaction" })
    Dropdown(T("Player Target Color"), "playerColorMode",
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

    Header(T("Bar Aparência"))
    Checkbox(T("NAGA Iron Borders"), "rpgBorder")
    Checkbox(T("Gloss"), "glossEnabled")
    Checkbox(T("Fill Pattern"), "barPatternEnabled")
    Dropdown(T("Fill Pattern Type"), "barPatternKey", nil,
        { "ZigZag", "Smoke", "Still Water", "Stone", "Dirt", "Lava", "Rock Lava", "Lava Wave", "Molten" },
        { "ZigZag", "smoke", "stillwater", "Stone", "Dirt", "Lava", "RockLava", "LavaWave", "Molten" },
        function() return Disabled() or self:GetTargetFrame().barPatternEnabled ~= true end)
    Slider(T("Fill Pattern Opacity"), "barPatternOpacity", nil, 0, 40, 1,
        function() return Disabled() or self:GetTargetFrame().barPatternEnabled ~= true end)
    Slider(T("Fill Pattern Scale"), "barPatternScale", nil, 24, 512, 4,
        function() return Disabled() or self:GetTargetFrame().barPatternEnabled ~= true end)
    Slider(T("Black Border Width"), "borderWidth", nil, 0, 8, 1)
    Slider(T("Inner Shadow"), "innerShadowAlpha", nil, 0, 100, 1)
    Slider(T("Outer Shadow"), "outerShadowAlpha", nil, 0, 100, 1)

    Header(T("Text"))
    Dropdown(T("Font"), "textFontKey", nil,
        { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
        { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" })
    Slider(T("Name Size"), "nameTextSize", "Tamanho da fonte do nick do target (separado do CP/level).", 10, 36, 1)
    Slider(T("Level / CP Size"), "levelTextSize", "Tamanho da fonte do level e do CP (separado do nick).", 8, 32, 1)
    Slider(T("Health Text Size"), "healthTextSize", nil, 8, 32, 1)
    Dropdown(T("Outline"), "textOutline", nil,
        { "None", "Soft Thin", "Soft Thick", "Thick Outline" },
        { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" })
    Slider(T("Text Opacity"), "textOpacity", nil, 10, 100, 1)
    ColorPicker("Text Color", "textColor")
    Slider(T("Health Text Inset"), "textInset", "Move side labels away from the bar edge.", 0, 28, 1)
    Slider(T("Health Text Vertical Offset"), "textVerticalOffset", nil, -8, 8, 1)
    Dropdown(T("Health Format"), "healthTextFormat", nil,
        { "None", "Number", "Percent", "Number + Percent" },
        { "none", "number", "percent", "numberAndPercent" })
    Dropdown(T("Health Text Position"), "healthTextPosition",
        "Applies to every health format. Opposite Sides places a number on the left and a percent on the right; single values use their natural side.",
        { "Left", "Center", "Right", "Opposite Sides" }, { "left", "center", "right", "sides" }, Disabled)

    Header(T("Shields"))
    Checkbox(T("Shield Overlay"), "shieldOverlayEnabled")
    Slider(T("Shield Fill Opacity"), "shieldFillOpacity", nil, 0, 100, 1,
        function() return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false end)
    ColorPicker("Shield Fill Color", "shieldFillColor", nil,
        function() return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false end)
    Checkbox(T("Shield Glow"), "shieldGlowEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false end)
    Slider(T("Shield Glow Opacity"), "shieldGlowOpacity", nil, 0, 100, 1,
        function()
            return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false
                or self:GetTargetFrame().shieldGlowEnabled == false
        end)
    ColorPicker("Shield Glow Color", "shieldGlowColor", nil,
        function()
            return Disabled() or self:GetTargetFrame().shieldOverlayEnabled == false
                or self:GetTargetFrame().shieldGlowEnabled == false
        end)
    Dropdown(T("Shield Text Mode"), "shieldTextMode", nil,
        { "Off", "Shield Only", "Health + Shield" }, { "off", "shieldOnly", "healthAndShield" })

    Header(T("Feedback Effects"))
    Checkbox(T("Bar Feedback"), "feedbackEnabled")
    Slider(T("Feedback Intensity"), "feedbackIntensity", nil, 0, 140, 5,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox(T("Damage Pulse"), "spendPulseEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox(T("Heal Pulse"), "gainPulseEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox(T("Full Health Pulse"), "fullResourcePulseEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox(T("Shield Pulse"), "shieldPulseEnabled", nil,
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Checkbox(T("Loss Trail"), "lossTrailEnabled", "Leave a short-lived highlight behind the bar when health drops.")
    Checkbox(T("Low Health Glow"), "lowResourceGlowEnabled", "Glow around the target bar below 35% health.",
        function() return Disabled() or self:GetTargetFrame().feedbackEnabled ~= true end)
    Add(
    {
        type = "button",
        name = T("Replay Pré-visualizar Effects"),
        func = function() self:ReplayTargetFramePreviewEffects() end,
        disabled = Disabled,
        width = "half",
    })

    Header(T("Boss Aparência"))
    Checkbox(T("Boss decoration"), "bossDecoration", "Add silver steel end caps and a winged skull crest to recognized boss targets.")
    Add(
    {
        type = "checkbox",
        name = T("Pré-visualizar boss"),
        tooltip = T("Mostrar a boss while this settings section is open. This preview is not saved."),
        getFunc = function() return NAGA_UI.TargetFrame and NAGA_UI.TargetFrame.previewBoss == true end,
        setFunc = function(value)
            if NAGA_UI.TargetFrame then NAGA_UI.TargetFrame:SetBossPreview(value) end
        end,
        disabled = Disabled,
        width = "half",
    })

    Header(T("Level Text"))
    Checkbox(T("Mostrar Level"), "showLevel", "Mostrar the target's level or effective Champion Points.")
    Checkbox(T("Level Style"), "showLevelStyle", "Add tier colors and special effects at CP 1800+. Turn it off for plain white level text.",
        function() return Disabled() or self:GetTargetFrame().showLevel == false end)

    return controls
end

function Settings:BuildMinimapControls()
    local controls = {}
    local function MapSV()
        if NagaMapUI and NagaMapUI.SavedVariables then
            return NagaMapUI.SavedVariables.Account("minimap", {
                zoomBias = 1, unlocked = true, visible = true,
                showClock = true, showZone = true,
                clockPosition = "bottom", zonePosition = "bottom", rotateMap = true, showCamera = true,
            playerSize = 24, pinSize = 32, enabled = true, wheelFrame = "Daedric",
            frameAdjust = -40, frameRotate = true, mapSize = 250, zoneFont = "trajan",
            zoneFontSize = 18, borderPinOffset = -6,
            })
        end
        return {
            zoomBias = 1, unlocked = true, visible = true,
            showClock = true, showZone = true,
            clockPosition = "bottom", zonePosition = "bottom", rotateMap = true, showCamera = true,
            playerSize = 24, pinSize = 32, enabled = true, wheelFrame = "Daedric",
            frameAdjust = -40, frameRotate = true, mapSize = 250, zoneFont = "trajan",
            zoneFontSize = 18, borderPinOffset = -6,
        }
    end
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Ativar minimapa"),
        tooltip = T("Desligado: o AbyssUI não cria nem atualiza o minimapa."),
        getFunc = function() return MapSV().enabled ~= false end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetEnabled then
                NagaMapUI.Minimap.SetEnabled(v)
            else
                MapSV().enabled = v
            end
        end,
        default = true,
    }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Mostrar minimapa"),
        getFunc = function() return MapSV().visible ~= false end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetVisible then
                NagaMapUI.Minimap.SetVisible(v)
            else
                MapSV().visible = v
            end
        end,
        default = true,
    }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Desbloquear (arrastar)"),
        tooltip = T("Permite arrastar o minimapa pelo título ou pela borda. A posição é salva automaticamente."),
        getFunc = function() return MapSV().unlocked ~= false end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetUnlocked then
                NagaMapUI.Minimap.SetUnlocked(v)
            else
                MapSV().unlocked = v
            end
        end,
        default = true,
    }
    controls[#controls + 1] = {
        type = "slider",
        name = T("Zoom do minimapa"),
        tooltip = T("Também funciona com a roda do mouse sobre o mapa."),
        min = 25, max = 300, step = 5,
        getFunc = function() return math.floor((MapSV().zoomBias or 1) * 100 + 0.5) end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetZoomBias then
                NagaMapUI.Minimap.SetZoomBias(v / 100)
            else
                MapSV().zoomBias = v / 100
            end
        end,
        default = 100,
    }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Girar mapa (direção do personagem)"),
        tooltip = T("O minimapa gira conforme o personagem olha, igual ao MiniMap. A seta do jogador fica para cima."),
        getFunc = function() return MapSV().rotateMap ~= false end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetRotateMap then
                NagaMapUI.Minimap.SetRotateMap(v)
            else
                MapSV().rotateMap = v
            end
        end,
        default = true,
    }
    -- Moldura fixa: Daedric (outras Wheelframes removidas)
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Girar moldura junto com o mapa"),
        tooltip = T("Liga/desliga a rotação da moldura (N/E/S/W acompanham o mapa). Desligue se alguma moldura apresentar defeito visual ao girar. As molduras 'Steady' nunca giram."),
        getFunc = function() return MapSV().frameRotate ~= false end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetFrameRotate then
                NagaMapUI.Minimap.SetFrameRotate(v)
            else
                MapSV().frameRotate = v
            end
        end,
        default = true,
    }
    controls[#controls + 1] = {
        type = "slider",
        name = T("Tamanho do mapa (círculo)"),
        tooltip = T("Aumenta ou diminui o círculo do minimapa (em pixels). A moldura acompanha o tamanho. Diferente do 'Zoom', que só aproxima o conteúdo do mapa."),
        min = 150, max = 400, step = 2,
        getFunc = function() return MapSV().mapSize or 250 end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetMapSize then
                NagaMapUI.Minimap.SetMapSize(v)
            else
                MapSV().mapSize = v
            end
        end,
        default = 250,
    }
    -- Ajuste fino da moldura: UI removida; frameAdjust continua no SavedVariables
    -- (lido em Minimap.lua) para não invalidar configs antigas.
    controls[#controls + 1] = {
        type = "slider",
        name = T("Tamanho da setinha do jogador"),
        tooltip = T("Tamanho da seta do personagem no centro do minimapa (o cone da câmera acompanha)."),
        min = 8, max = 96, step = 2,
        getFunc = function() return MapSV().playerSize or 32 end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetPlayerSize then
                NagaMapUI.Minimap.SetPlayerSize(v)
            else
                MapSV().playerSize = v
            end
        end,
        default = 32,
    }
    controls[#controls + 1] = {
        type = "slider",
        name = T("Tamanho dos pins do minimapa"),
        tooltip = T("Aumenta ou diminui os ícones dos pontos dentro do minimapa e os pins posicionados na borda do círculo."),
        min = 12, max = 48, step = 2,
        getFunc = function() return MapSV().pinSize or 22 end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetPinSize then
                NagaMapUI.Minimap.SetPinSize(v)
            else
                MapSV().pinSize = v
            end
        end,
        default = 22,
    }
    controls[#controls + 1] = {
        type = "dropdown",
        name = T("Fonte do nome da zona"),
        tooltip = T("Fonte do nome da zona no minimapa (mesmas fontes já usadas no addon)."),
        choices = { "Padrão do tema", "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
        choicesValues = { "theme", "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" },
        getFunc = function() return MapSV().zoneFont or "theme" end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetZoneFont then
                NagaMapUI.Minimap.SetZoneFont(v)
            else
                MapSV().zoneFont = v
            end
        end,
        default = "theme",
    }
    controls[#controls + 1] = {
        type = "slider",
        name = T("Tamanho da fonte da zona"),
        tooltip = T("Tamanho do texto do nome da zona."),
        min = 8, max = 32, step = 1,
        getFunc = function() return MapSV().zoneFontSize or 18 end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetZoneFontSize then
                NagaMapUI.Minimap.SetZoneFontSize(v)
            else
                MapSV().zoneFontSize = v
            end
        end,
        default = 18,
    }
    controls[#controls + 1] = {
        type = "slider",
        name = T("Posição dos pins da borda (px)"),
        tooltip = T("Move os pins que ficam na borda do minimapa: valores negativos puxam para dentro do mapa, positivos empurram para fora (sobre a moldura)."),
        min = -60, max = 80, step = 1,
        getFunc = function() return MapSV().borderPinOffset or 0 end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetBorderPinOffset then
                NagaMapUI.Minimap.SetBorderPinOffset(v)
            else
                MapSV().borderPinOffset = v
            end
        end,
        default = 0,
    }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Setas da câmera (para onde olho)"),
        tooltip = T("Mostra o cone/setas da direção da câmera no centro do minimapa (CameraPointer)."),
        getFunc = function() return MapSV().showCamera ~= false end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetShowCamera then
                NagaMapUI.Minimap.SetShowCamera(v)
            else
                MapSV().showCamera = v
            end
        end,
        default = true,
    }
    controls[#controls + 1] = { type = "header", name = T("Pins na borda") }
    controls[#controls + 1] = {
        type = "description",
        text = T("Pins fora do alcance do minimapa aparecem na borda do círculo, apontando a direção. Funciona também onde não há mapa."),
    }
    local borderOpts = {
        { "borderPins", "Ativar pins na borda", "Liga/desliga todos os pins na borda do minimapa.", true },
        { "borderAssisted", "Só pins da missão assistida", "Mostra na borda apenas os pins da missão assistida (desligado: também as outras missões rastreadas).", true },
        { "borderLeader", "Só o líder do grupo", "Na borda, mostra apenas o líder do grupo.", false },
        { "borderWaypoint", "Waypoint do jogador", "Mostra o waypoint do jogador na borda.", true },
        { "borderBank", "Banco", "Mostra bancos na borda.", true },
        { "borderStables", "Estábulos", "Mostra estábulos na borda.", true },
        { "borderWayshrine", "Santuário mais próximo", "Mostra o santuário (wayshrine) mais próximo na borda.", true },
        { "borderTreasure", "Tesouros/Pesquisas", "Mostra mapas de tesouro e pesquisas na borda.", true },
        { "borderQuestGivers", "Missões disponíveis", "Mostra quem oferece missões na borda.", true },
        { "borderCrafting", "Estações de criação", "Mostra estações de criação na borda.", true },
        { "borderWorldEvents", "Eventos mundiais (dinâmicos)", "Mostra dragões, tempestades e outros eventos mundiais na borda.", true },
        { "borderAvaBg", "Objetivos AvA e BG", "Mostra objetivos de AvA e campos de batalha na borda.", true },
        { "borderKeep", "Forte mais próximo", "Mostra o forte mais próximo na borda (só em Cyrodiil).", true },
        { "borderSkyshard", "Skyshard mais próximo", "Mostra o skyshard mais próximo na borda.", true },
    }
    for _, o in ipairs(borderOpts) do
        local key, default = o[1], o[4]
        controls[#controls + 1] = {
            type = "checkbox",
            name = o[2],
            tooltip = o[3],
            getFunc = function()
                local v = MapSV()[key]
                if v == nil then return default end
                return v and true or false
            end,
            setFunc = function(v)
                if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetBorderOption then
                    NagaMapUI.Minimap.SetBorderOption(key, v)
                else
                    MapSV()[key] = v
                end
            end,
            disabled = key ~= "borderPins" and function() return MapSV().borderPins == false end or nil,
            default = default,
        }
    end
    controls[#controls + 1] = { type = "header", name = T("Distância para ver cada pin") }
    controls[#controls + 1] = {
        type = "description",
        text = T("Distância em METROS a partir da qual cada tipo de pin aparece na borda do minimapa (100 = 100 metros). 0 = sem limite. Pins na borda mais longe que o valor ficam escondidos; os que já estão dentro do círculo não mudam. Ao entrar em um mapa novo, ande um pouco para o minimapa calibrar a escala."),
    }
    local distOpts = {
        { "assisted", "Missão assistida" },
        { "tracked", "Outras missões rastreadas" },
        { "questoffer", "Missões disponíveis" },
        { "waypoint", "Waypoint do jogador" },
        { "wayshrine", "Santuários (wayshrines)" },
        { "skyshard", "Skyshards" },
        { "worldevent", "Eventos mundiais" },
        { "treasure", "Tesouros/Pesquisas" },
        { "avabg", "Objetivos AvA e BG" },
        { "keep", "Fortes" },
        { "bank", "Bancos" },
        { "stable", "Estábulos" },
        { "crafting", "Estações de criação" },
        { "group", "Membros do grupo" },
        { "other", "Outros pins" },
    }
    for _, o in ipairs(distOpts) do
        local cat = o[1]
        controls[#controls + 1] = {
            type = "slider",
            name = T("Distância (m): ") .. o[2],
            tooltip = T("Distância máxima, em metros, para ver este pin na borda do minimapa. 0 = sem limite."),
            min = 0, max = 5000, step = 10,
            getFunc = function() return tonumber(MapSV()["pinDistM_" .. cat]) or 0 end,
            setFunc = function(v)
                if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetPinDistance then
                    NagaMapUI.Minimap.SetPinDistance(cat, v)
                else
                    MapSV()["pinDistM_" .. cat] = v
                end
            end,
            default = 0,
        }
    end
    controls[#controls + 1] = { type = "header", name = T("Zona") }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Mostrar nome da zona"),
        getFunc = function() return MapSV().showZone ~= false end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetShowZone then
                NagaMapUI.Minimap.SetShowZone(v)
            else
                MapSV().showZone = v
            end
        end,
        default = true,
    }
    controls[#controls + 1] = {
        type = "dropdown",
        name = T("Posição da zona"),
        tooltip = T("Nome da zona centralizado acima ou abaixo do mapa."),
        choices = { "Cima", "Baixo" },
        choicesValues = { "top", "bottom" },
        getFunc = function() return MapSV().zonePosition == "top" and "top" or "bottom" end,
        setFunc = function(v)
            if NagaMapUI and NagaMapUI.Minimap and NagaMapUI.Minimap.SetZonePosition then
                NagaMapUI.Minimap.SetZonePosition(v)
            else
                MapSV().zonePosition = v
            end
        end,
        default = "bottom",
        disabled = function() return MapSV().showZone == false end,
    }
    return controls
end


function Settings:GetLootHistoryOptions()
    local defaults = ACCOUNT_DEFAULTS.modules.lootHistory
    local controls = {}
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Enable Loot History Style"),
        tooltip = T("Replace the default loot history look with NAGA style, position and scale."),
        getFunc = function() return self:IsLootHistoryEnabled() end,
        setFunc = function(value) self:SetLootHistoryEnabled(value) end,
        default = defaults.enabled,
    }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Desbloquear posição"),
        tooltip = T("Mostrar a drag handle for the loot history. Lock again to keep the saved position."),
        getFunc = function() return self:IsLootHistoryUnlocked() end,
        setFunc = function(value) self:SetLootHistoryUnlocked(value) end,
        default = defaults.unlocked,
        disabled = function() return not self:IsLootHistoryEnabled() end,
    }
    controls[#controls + 1] = {
        type = "slider",
        name = T("Scale (%)"),
        min = 60, max = 180, step = 5,
        getFunc = function() return self:GetLootHistory().scale end,
        setFunc = function(value) self:SetLootHistoryValue("scale", value) end,
        default = defaults.scale,
        disabled = function() return not self:IsLootHistoryEnabled() end,
    }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Legacy Style"),
        tooltip = T("Use the simpler legacy loot history style."),
        getFunc = function() return self:GetLootHistory().legacyStyle == true end,
        setFunc = function(value) self:SetLootHistoryValue("legacyStyle", value) end,
        default = defaults.legacyStyle,
        disabled = function() return not self:IsLootHistoryEnabled() end,
    }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Loot Sounds"),
        getFunc = function() return self:AreLootHistorySoundsEnabled() end,
        setFunc = function(value) self:SetLootHistorySoundsEnabled(value) end,
        default = defaults.soundsEnabled,
        disabled = function() return not self:IsLootHistoryEnabled() end,
    }
    controls[#controls + 1] = {
        type = "checkbox",
        name = T("Ocultar Experience Lines"),
        tooltip = T("Do not show experience gain in the loot history stream."),
        getFunc = function() return self:ShouldFilterLootHistoryExperience() end,
        setFunc = function(value) self:SetLootHistoryFilterExperience(value) end,
        default = defaults.filterExperience,
        disabled = function() return not self:IsLootHistoryEnabled() end,
    }
    controls[#controls + 1] = {
        type = "button",
        name = T("Redefinir posição"),
        func = function()
            self:SetLootHistoryPosition(180, -230)
            if NAGA_UI.LootHistory then NAGA_UI.LootHistory:RefreshSettings() end
        end,
        disabled = function() return not self:IsLootHistoryEnabled() end,
    }
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
        d("AbyssUI: LibAddonMenu-2.0 not found.")
        return
    end

    local panelName = "AbyssUI_Settings"
    local panelData =
    {
        type = "panel",
        name = T("AbyssUI"),
        displayName = "|cFF0000Abyss|rUI",
        author = "|cFF0000N A G A|r",
        version = "21/10/2026",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local options =
    {
        {
            type = "submenu",
            name = T("AbyssQuest"),
            controls = self:GetAbyssQuestOptions(),
            reference = "AbyssUI_AbyssQuestSubmenu",
        },
        {
            type = "submenu",
            name = T("Achievement Alert"),
            controls = self:GetAchievementAlertOptions(),
        },
        {
            type = "submenu",
            name = T("Buffs"),
            controls =
            {
                {
                    type = "description",
                    text = T("Sistema completo de buffs (jogador, passivas, alvo, lista negra, personalizados, sinergia e widgets). Para mover os paineis use o Edit HUD nativo do jogo."),
                },
                {
                    type = "checkbox",
                    name = T("Ativar Buffs"),
                    getFunc = function() return self:IsBuffsEnabled() end,
                    setFunc = function(value) self:SetBuffsEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.buffs.enabled,
                },

                -- BUFFS DO JOGADOR
                {
                    type = "submenu",
                    name = T("Buffs do Jogador"),
                    controls =
                    {
                        {
                            type = "checkbox",
                            name = T("Buffs do Jogador"),
                            getFunc = function() return self:IsPlayerBuffsEnabled() end,
                            setFunc = function(value) self:SetPlayerBuffsEnabled(value) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = true,
                        },
                        {
                            type = "checkbox",
                            name = T("Mostrar efeitos importantes em tamanho maior"),
                            getFunc = function() return self:GetBuffOption("buffsImportant") end,
                            setFunc = function(value) self:SetBuffOption("buffsImportant", value == true) end,
                            disabled = function() return not self:IsBuffsEnabled() or not self:IsPlayerBuffsEnabled() end,
                            default = true,
                        },
                        {
                            type = "checkbox",
                            name = T("Ocultar buffs de outros jogadores"),
                            getFunc = function() return self:GetBuffOption("buffsOtherHide") end,
                            setFunc = function(value) self:SetBuffOption("buffsOtherHide", value == true) end,
                            disabled = function() return not self:IsBuffsEnabled() or not self:IsPlayerBuffsEnabled() end,
                            default = true,
                            tooltip = T("Exceto buffs importantes (Major Force, Alkosh, etc.)."),
                        },
                        {
                            type = "slider",
                            name = T("Duracao minima dos buffs (s)"),
                            min = 0, max = 10, step = 1,
                            getFunc = function() return self:GetBuffOption("minimumDuration") or 3 end,
                            setFunc = function(value) self:SetBuffOption("minimumDuration", value) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = 3,
                        },
                        {
                            type = "slider",
                            name = T("Tamanho do icone (jogador)"),
                            min = 30, max = 80, step = 2,
                            getFunc = function() return self:GetBuffOption("playerBuffSize") or 44 end,
                            setFunc = function(value) self:SetBuffOption("playerBuffSize", value, true) end,
                            disabled = function() return not self:IsBuffsEnabled() or not self:IsPlayerBuffsEnabled() end,
                            default = 44,
                        },
                    },
                },
                -- PASSIVAS
                {
                    type = "submenu",
                    name = T("Passivas"),
                    controls =
                    {
                        {
                            type = "dropdown",
                            name = T("Buffs passivos"),
                            choices = { "On one panel", "On additional panel", "Disabled" },
                            getFunc = function() return self:GetBuffOption("buffsPassives") or "On additional panel" end,
                            setFunc = function(value) self:SetBuffOption("buffsPassives", value, true) end,
                            disabled = function() return not self:IsBuffsEnabled() or not self:IsPlayerBuffsEnabled() end,
                            default = "On additional panel",
                        },
                        {
                            type = "slider",
                            name = T("Tamanho do icone (passivas)"),
                            min = 24, max = 80, step = 2,
                            getFunc = function() return self:GetBuffOption("passiveBuffSize") or 36 end,
                            setFunc = function(value) self:SetBuffOption("passiveBuffSize", value, true) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = 36,
                        },
                        {
                            type = "checkbox",
                            name = T("Ocultar buffs do Oakensoul"),
                            getFunc = function() return self:GetBuffOption("passiveOakFilter") end,
                            setFunc = function(value) self:SetBuffOption("passiveOakFilter", value == true) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = true,
                        },
                    },
                },
                -- BUFFS DO ALVO
                {
                    type = "submenu",
                    name = T("Buffs do Alvo"),
                    controls =
                    {
                        {
                            type = "checkbox",
                            name = T("Buffs / Debuffs do Alvo"),
                            getFunc = function() return self:IsTargetBuffsEnabled() end,
                            setFunc = function(value) self:SetTargetBuffsEnabled(value) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = true,
                        },
                        {
                            type = "slider",
                            name = T("Tamanho do icone (alvo)"),
                            min = 30, max = 80, step = 2,
                            getFunc = function() return self:GetBuffOption("targetBuffSize") or 44 end,
                            setFunc = function(value) self:SetBuffOption("targetBuffSize", value, true) end,
                            disabled = function() return not self:IsBuffsEnabled() or not self:IsTargetBuffsEnabled() end,
                            default = 44,
                        },
                    },
                },
                -- LISTA NEGRA
                {
                    type = "submenu",
                    name = T("Lista Negra de Buffs"),
                    controls =
                    {
                        {
                            type = "checkbox",
                            name = T("Aplicar lista negra"),
                            getFunc = function() return self:GetBuffOption("enableBlackList") end,
                            setFunc = function(value) self:SetBuffOption("enableBlackList", value == true) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = true,
                        },
                        {
                            type = "editbox",
                            name = T("Adicionar a lista negra (nome ou ID)"),
                            getFunc = function() return "" end,
                            setFunc = function(text) self:AddBuffListEntry("blackList", text) end,
                            isMultiline = false,
                            disabled = function() return not self:IsBuffsEnabled() or not self:GetBuffOption("enableBlackList") end,
                            tooltip = T("Digite o nome ou o ID do buff e confirme."),
                        },
                        {
                            type = "description",
                            text = T("Padrao: ESO Plus (63601), Block (14890). Remocoes avancadas podem ser feitas no SavedVariables."),
                        },
                    },
                },
                -- CUSTOM
                {
                    type = "submenu",
                    name = T("Painel de Buffs Personalizados"),
                    controls =
                    {
                        {
                            type = "checkbox",
                            name = T("Ativar painel personalizado"),
                            getFunc = function() return self:GetBuffOption("enableCustomBuffs") end,
                            setFunc = function(value) self:SetBuffOption("enableCustomBuffs", value == true, true) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = false,
                        },
                        {
                            type = "slider",
                            name = T("Tamanho do icone"),
                            min = 30, max = 80, step = 2,
                            getFunc = function() return self:GetBuffOption("customBuffSize") or 44 end,
                            setFunc = function(value) self:SetBuffOption("customBuffSize", value, true) end,
                            disabled = function() return not self:GetBuffOption("enableCustomBuffs") end,
                            default = 44,
                        },
                        {
                            type = "dropdown",
                            name = T("Direcao"),
                            choices = { "horizontal", "vertical" },
                            getFunc = function() return self:GetBuffOption("customBuffsDirection") or "vertical" end,
                            setFunc = function(value) self:SetBuffOption("customBuffsDirection", value, true) end,
                            disabled = function() return not self:GetBuffOption("enableCustomBuffs") end,
                            default = "vertical",
                        },
                        {
                            type = "editbox",
                            name = T("Adicionar buff personalizado (nome ou ID)"),
                            getFunc = function() return "" end,
                            setFunc = function(text) self:AddBuffListEntry("customBuffs", text) end,
                            isMultiline = false,
                            disabled = function() return not self:GetBuffOption("enableCustomBuffs") end,
                        },
                    },
                },
                -- SYNERGY CD
                {
                    type = "submenu",
                    name = T("Painel de Cooldown de Sinergia"),
                    controls =
                    {
                        {
                            type = "checkbox",
                            name = T("Ativar cooldown de sinergia"),
                            getFunc = function() return self:GetBuffOption("enableSynergyCd") end,
                            setFunc = function(value) self:SetBuffOption("enableSynergyCd", value == true, true) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = false,
                        },
                        {
                            type = "slider",
                            name = T("Tamanho do icone"),
                            min = 30, max = 80, step = 2,
                            getFunc = function() return self:GetBuffOption("synergyCdSize") or 44 end,
                            setFunc = function(value) self:SetBuffOption("synergyCdSize", value, true) end,
                            disabled = function() return not self:GetBuffOption("enableSynergyCd") end,
                            default = 44,
                        },
                        {
                            type = "dropdown",
                            name = T("Direcao"),
                            choices = { "horizontal", "vertical" },
                            getFunc = function() return self:GetBuffOption("synergyCdDirection") or "vertical" end,
                            setFunc = function(value) self:SetBuffOption("synergyCdDirection", value, true) end,
                            disabled = function() return not self:GetBuffOption("enableSynergyCd") end,
                            default = "vertical",
                        },
                    },
                },
                -- WIDGETS
                {
                    type = "submenu",
                    name = T("Widgets"),
                    controls =
                    {
                        {
                            type = "checkbox",
                            name = T("Ativar widgets"),
                            getFunc = function() return self:GetBuffOption("enableWidgets") end,
                            setFunc = function(value) self:SetBuffOption("enableWidgets", value == true, true) end,
                            disabled = function() return not self:IsBuffsEnabled() end,
                            default = false,
                            tooltip = T("Painel separado para buffs importantes (Major Resolve, procs, etc.)."),
                        },
                        {
                            type = "slider",
                            name = T("Tamanho do icone"),
                            min = 30, max = 80, step = 2,
                            getFunc = function() return self:GetBuffOption("widgetsSize") or 44 end,
                            setFunc = function(value) self:SetBuffOption("widgetsSize", value, true) end,
                            disabled = function() return not self:GetBuffOption("enableWidgets") end,
                            default = 44,
                        },
                        {
                            type = "editbox",
                            name = T("Adicionar widget (nome ou ID)"),
                            getFunc = function() return "" end,
                            setFunc = function(text) self:AddBuffListEntry("widgets", text) end,
                            isMultiline = false,
                            disabled = function() return not self:GetBuffOption("enableWidgets") end,
                        },
                    },
                },
                {
                    type = "button",
                    name = T("Redefinir Buffs"),
                    func = function()
                        self:ResetBuffsDefaults()
                    end,
                    tooltip = T("Restaura opcoes padrao dos buffs (posicoes ficam no Edit HUD nativo)."),
                },
            },
        },
        {
            type = "submenu",
            name = T("Minimap"),
            controls = self:BuildMinimapControls(),
        },
        {
            type = "submenu",
            name = T("Target Frame"),
            controls = self:BuildTargetFrameOptions(),
        },
        {
            type = "submenu",
            name = T("Cast Skill"),
            controls = self:BuildCastBarOptions(),
        },
        {
            type = "submenu",
            name = T("Info Panel"),
            controls = self:BuildInfoPanelOptions(),
        },
        {
            type = "submenu",
            name = T("Companion Frame"),
            controls = self:BuildCompanionFrameOptions(),
        },
        {
            type = "submenu",
            name = T("Loot History"),
            controls = self:GetLootHistoryOptions(),
        },
        {
            type = "submenu",
            name = T("Misc"),
            controls =
            {
                {
                    type = "checkbox",
                    name = T("Immersive Teleport"),
                    tooltip = T("Ocultar the UI and use the character panel camera with Left Composition during teleport animations. Restore the normal camera and UI when travel completes or is canceled."),
                    getFunc = function() return self:IsImmersiveTeleportEnabled() end,
                    setFunc = function(value) self:SetImmersiveTeleportEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.immersiveTeleport.enabled,
                },
                { type = "header", name = T("Synergy Alert") },
                {
                    type = "checkbox",
                    name = T("Enable Synergy Alert"),
                    tooltip = T("Mostrar a large animated synergy icon, with a centered binding and name row underneath. The original sound and activation binding are preserved."),
                    getFunc = function() return self:GetSynergyAlert().enabled end,
                    setFunc = function(value) self:SetSynergyAlertValue("enabled", value) end,
                    default = ACCOUNT_DEFAULTS.modules.synergyAlert.enabled,
                },
                {
                    type = "checkbox",
                    name = T("Desbloquear posição"),
                    tooltip = T("Drag the sample synergy emblem while settings are open. Its position is saved on this server."),
                    getFunc = function() return self:GetSynergyAlert().unlocked end,
                    setFunc = function(value) self:SetSynergyAlertValue("unlocked", value) end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    default = ACCOUNT_DEFAULTS.modules.synergyAlert.unlocked,
                },
                {
                    type = "slider",
                    name = T("Scale"),
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
                    name = T("Opacity"),
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
                    name = T("Animation Intensity"),
                    tooltip = T("Adjust the soft glow pulse. The icon fades in without resizing or bouncing. Set to zero for a static prompt."),
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
                    name = T("Pré-visualizar"),
                    tooltip = T("Mostrar a silent sample for four seconds, or until locked while positioning."),
                    func = function()
                        if NAGA_UI.SynergyAlert then NAGA_UI.SynergyAlert:Preview() end
                    end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    width = "half",
                },
                {
                    type = "button",
                    name = T("Redefinir posição"),
                    tooltip = T("Return the emblem to ESO's default synergy location for the current input mode."),
                    func = function() self:ResetSynergyAlertPosition() end,
                    disabled = function() return not self:GetSynergyAlert().enabled end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = T("Damage Numbers"),
            controls =
            {
                {
                    type = "checkbox",
                    name = T("Enable Floating Damage Numbers"),
                    tooltip = T("Mostrar NAGA's damage numbers near the middle of your screen."),
                    getFunc = function() return self:IsDamageNumbersEnabled() end,
                    setFunc = function(value) self:SetDamageNumbersEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.enabled,
                },
                {
                    type = "checkbox",
                    name = T("Unlock Floating Damage Origin"),
                    tooltip = T("Mostrar a drag handle for where damage numbers pop up. Its position is saved on this server."),
                    getFunc = function() return self:IsDamageNumbersUnlocked() end,
                    setFunc = function(value) self:SetDamageNumbersUnlocked(value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.unlocked,
                },
                {
                    type = "checkbox",
                    name = T("Ocultar Default Damage Numbers"),
                    getFunc = function() return self:ShouldOcultarDefaultDamageNumbers() end,
                    setFunc = function(value) self:SetDamageNumbersOcultarDefault(value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.hideDefaultDamage,
                },
                {
                    type = "checkbox",
                    name = T("Critical Hit Sound"),
                    getFunc = function() return self:AreDamageNumberCritSoundsEnabled() end,
                    setFunc = function(value) self:SetDamageNumberCritSoundsEnabled(value) end,
                    disabled = function() return not self:IsDamageNumbersEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.critSoundEnabled,
                },
                {
                    type = "dropdown",
                    name = T("Damage Number Font"),
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
                    name = T("Text Effect"),
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
                    name = T("Critical Sound"),
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
                    name = T("Normal Font Size"),
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
                    name = T("Critical Font Size"),
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
                    name = T("Duration"),
                    tooltip = T("Set how long damage numbers stay visible, in milliseconds."),
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
                    name = T("Spread"),
                    tooltip = T("Set how far new damage numbers spread out."),
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
                    name = T("Drift"),
                    tooltip = T("Set how far damage numbers drift after popping up."),
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
                    name = T("Big Hit Threshold"),
                    tooltip = T("Hits this big or higher drift less, so they feel heavier."),
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
                    name = T("Maximum Active Numbers"),
                    tooltip = T("Limit how many damage numbers can be on screen. New hits replace the oldest ones."),
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
                    name = T("Critical Sound Throttle"),
                    tooltip = T("Set the shortest gap between critical-hit sounds, in milliseconds."),
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
                    name = T("Damage Done Minigame"),
                },
                {
                    type = "description",
                    text = T("Chain player and pet damage into a gold arcade score. Keep the timer alive, rescue a draining chain, and finish with your peak score."),
                },
                {
                    type = "checkbox",
                    name = T("Enable Damage Done Minigame"),
                    tooltip = T("Mostrar a separate accumulated damage score. This can run without floating damage numbers."),
                    getFunc = function() return self:IsDamageDoneMinigameEnabled() end,
                    setFunc = function(value) self:SetDamageDoneMinigameEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.enabled,
                },
                {
                    type = "checkbox",
                    name = T("Unlock Damage Done Minigame"),
                    tooltip = T("Mostrar a drag handle for the minigame. Its position is saved on this server."),
                    getFunc = function() return self:IsDamageDoneMinigameUnlocked() end,
                    setFunc = function(value) self:SetDamageDoneMinigameUnlocked(value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.unlocked,
                },
                {
                    type = "checkbox",
                    name = T("Minigame Sounds"),
                    tooltip = T("Play throttled rune ticks, heavier critical impacts, and milestone sounds."),
                    getFunc = function() return self:AreDamageDoneMinigameSoundsEnabled() end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("soundEnabled", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.soundEnabled,
                },
                {
                    type = "checkbox",
                    name = T("Tier Progression Sounds"),
                    tooltip = T("Play a different sound when each new tier is reached, building to a final victory sound at the cap. Applies to Damage Done and DPS. Turn off to keep only normal and critical hit sounds. Pré-visualizar All Tiers demonstrates the progression."),
                    getFunc = function() return self:GetDamageDoneMinigame().tierSoundsEnabled end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("tierSoundsEnabled", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() or not self:AreDamageDoneMinigameSoundsEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.tierSoundsEnabled,
                },
                {
                    type = "checkbox",
                    name = T("Face Right"),
                    tooltip = T("Reverse the number's tilt, skew, and decorative accents so it faces right."),
                    getFunc = function() return self:GetDamageDoneMinigame().faceRight end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("faceRight", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.faceRight,
                },
                {
                    type = "dropdown",
                    name = T("Display Mode"),
                    tooltip = T("Mostrar the current fast-draining damage total, or average damage per second across the active combo streak."),
                    choices = { "Damage Done", "DPS" },
                    choicesValues = { "damageDone", "dps" },
                    getFunc = function() return self:GetDamageDoneMinigame().displayMode end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("displayMode", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.displayMode,
                },
                {
                    type = "slider",
                    name = T("Combo Grace Period (ms)"),
                    tooltip = T("Time after the last hit before the score starts draining over 1.5 seconds. The default allows a normal one-second attack rhythm."),
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
                    name = T("Impact Animation Intensity"),
                    tooltip = T("Adjust punch, recoil, echoes, sparks, and flashes. Zero keeps the score and timer with simple fades."),
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
                    name = T("Mostrar Combo Timer"),
                    tooltip = T("Drain the gold in the crest's segmented metal wings to show remaining chain time. Turn off to keep the wings filled."),
                    getFunc = function() return self:GetDamageDoneMinigame().showTimer end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("showTimer", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.showTimer,
                },
                {
                    type = "checkbox",
                    name = T("Mostrar Damage Done / DPS Label"),
                    tooltip = T("Mostrar the Damage Done or DPS text beneath the score, independently of the hit count and peak label."),
                    getFunc = function() return self:GetDamageDoneMinigame().showModeLabel end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("showModeLabel", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.showModeLabel,
                },
                {
                    type = "checkbox",
                    name = T("Mostrar Hit Count"),
                    tooltip = T("Mostrar the number of hits beneath the score, independently of the Damage Done or DPS label."),
                    getFunc = function() return self:GetDamageDoneMinigame().showHitCount end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("showHitCount", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.showHitCount,
                },
                {
                    type = "checkbox",
                    name = T("Mostrar Peak Label"),
                    tooltip = T("Mostrar PEAK beneath the final score when a chain ends. This does not change the final score or the other labels."),
                    getFunc = function() return self:GetDamageDoneMinigame().showPeakLabel end,
                    setFunc = function(value) self:SetDamageDoneMinigameValue("showPeakLabel", value) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.damageNumbers.damageDoneMinigame.showPeakLabel,
                },
                {
                    type = "slider",
                    name = T("Minigame Scale"),
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
                    name = T("Pré-visualizar Minigame"),
                    tooltip = T("Pré-visualizar rapid hits, critical impacts, milestones, the draining timer, and the final peak score. Real damage starts a fresh chain."),
                    func = function() self:PreviewDamageDoneMinigame() end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                },
                {
                    type = "button",
                    name = T("Pré-visualizar All Tiers"),
                    tooltip = T("Climb through all six milestones in the selected mode, including the final transformation at 5 million damage or 140,000 DPS."),
                    func = function() self:PreviewDamageDoneMinigame(true) end,
                    disabled = function() return not self:IsDamageDoneMinigameEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = T("Kill Sound"),
            tooltip = T("Pick the sound you hear when you land the killing blow."),
            controls =
            {
                {
                    type = "checkbox",
                    name = T("Enable Kill Sound"),
                    getFunc = function() return self:IsKillSoundEnabled() end,
                    setFunc = function(value) self:SetKillSoundEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.killSound.enabled,
                },
                {
                    type = "dropdown",
                    name = T("Killing Blow Sound"),
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
            name = T("PvP"),
            tooltip = T("Customize your PvP experience."),
            controls =
            {
                {
                    type = "description",
                    text = T("Customize your PvP experience."),
                },
                {
                    type = "header",
                    name = T("Kill Streak Animation"),
                },
                {
                    type = "checkbox",
                    name = T("Enable Kill Streak Animation"),
                    tooltip = T("Celebrate PvP kills and kill streaks."),
                    getFunc = function() return self:IsPvPEnabled() end,
                    setFunc = function(value) self:SetPvPEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.enabled,
                },
                {
                    type = "checkbox",
                    name = T("Unlock Animation"),
                    tooltip = T("Mostrar a drag handle for the PvP medallion. Its position is saved on this server."),
                    getFunc = function() return self:IsPvPUnlocked() end,
                    setFunc = function(value) self:SetPvPUnlocked(value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.unlocked,
                },
                {
                    type = "checkbox",
                    name = T("Enable Sounds"),
                    tooltip = T("Play progressively stronger sounds as the kill chain grows."),
                    getFunc = function() return self:GetPvP().soundEnabled end,
                    setFunc = function(value) self:SetPvPValue("soundEnabled", value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.soundEnabled,
                },
                {
                    type = "checkbox",
                    name = T("Enable Kill Chains"),
                    tooltip = T("Combine rapid killing blows into a single escalating counter."),
                    getFunc = function() return self:GetPvP().chainEnabled end,
                    setFunc = function(value) self:SetPvPValue("chainEnabled", value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.chainEnabled,
                },
                {
                    type = "checkbox",
                    name = T("Include Duels"),
                    tooltip = T("Celebrate duels that you win. Forfeits do not count as kills."),
                    getFunc = function() return self:GetPvP().includeDuels end,
                    setFunc = function(value) self:SetPvPValue("includeDuels", value) end,
                    disabled = function() return not self:IsPvPEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.pvp.includeDuels,
                },
                {
                    type = "slider",
                    name = T("Scale"),
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
                    name = T("Animation Intensity"),
                    tooltip = T("Control flashes, impact shake, sparks, and the maximum-chain shockwave."),
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
                    name = T("Pré-visualizar Kill Chain"),
                    tooltip = T("Pré-visualizar the x1, x4, and x8 medallions, kill-card fans, and sounds."),
                    func = function() self:PreviewPvPChain() end,
                    disabled = function() return not self:IsPvPEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = T("Group Callouts"),
            tooltip = T("Mostrar animated HUD callouts for group chat."),
            reference = "NAGA_UI_GroupCalloutsSubmenu",
            controls =
            {
                {
                    type = "description",
                    text = T("Uses ESO's verified group chat channel: /group, /g, /party, and /p."),
                },
                {
                    type = "checkbox",
                    name = T("Enable Group Callouts"),
                    getFunc = function() return self:IsGroupCalloutsEnabled() end,
                    setFunc = function(value) self:SetGroupCalloutsEnabled(value) end,
                    default = GROUP_CALLOUTS_DEFAULTS.enabled,
                },
                {
                    type = "checkbox",
                    name = T("Unlock Group Callouts"),
                    tooltip = T("Mostrar a drag handle for callouts. The position is saved for this character on this server."),
                    getFunc = function() return self:IsGroupCalloutsUnlocked() end,
                    setFunc = function(value) self:SetGroupCalloutsUnlocked(value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.unlocked,
                },
                {
                    type = "dropdown",
                    name = T("Callout Sound Mode"),
                    choices = { "Off", "Leader Only", "Every Message" },
                    choicesValues = { "off", "leaderOnly", "all" },
                    getFunc = function() return self:GetGroupCallouts().soundMode end,
                    setFunc = function(value) self:SetGroupCalloutsValue("soundMode", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.soundMode,
                },
                {
                    type = "dropdown",
                    name = T("Callout Sound"),
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
                    name = T("Pré-visualizar Sound"),
                    func = function() self:PreviewGroupCalloutsSound() end,
                    disabled = function()
                        return not self:IsGroupCalloutsEnabled()
                            or self:GetGroupCallouts().soundMode == "off"
                    end,
                },
                {
                    type = "header",
                    name = T("Layout"),
                },
                {
                    type = "slider",
                    name = T("Scale"),
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
                    name = T("Maximum Visible"),
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
                    name = T("Width"),
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
                    name = T("Height"),
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
                    name = T("Row Spacing"),
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
                    name = T("Mostrar Icon"),
                    tooltip = T("Mostrar a member or leader icon on each callout."),
                    getFunc = function() return self:GetGroupCallouts().showIcon end,
                    setFunc = function(value) self:SetGroupCalloutsValue("showIcon", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.showIcon,
                },
                {
                    type = "slider",
                    name = T("Icon Size"),
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
                    name = T("Mostrar Accent Strip"),
                    tooltip = T("Mostrar the small color strip on the left."),
                    getFunc = function() return self:GetGroupCallouts().showAccent end,
                    setFunc = function(value) self:SetGroupCalloutsValue("showAccent", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.showAccent,
                },
                {
                    type = "header",
                    name = T("Animation"),
                },
                {
                    type = "slider",
                    name = T("Visible Duration"),
                    tooltip = T("Set how long each callout stays visible, in milliseconds."),
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
                    name = T("Slide Distance"),
                    tooltip = T("Set how far callouts slide as they fade in and out."),
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
                    name = T("Shimmer"),
                    tooltip = T("Sweep a soft highlight across matching callouts."),
                    getFunc = function() return self:GetGroupCallouts().shimmerEnabled end,
                    setFunc = function(value) self:SetGroupCalloutsValue("shimmerEnabled", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.shimmerEnabled,
                },
                {
                    type = "slider",
                    name = T("Shimmer Intensity"),
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
                    name = T("Shimmer For"),
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
                    name = T("Glow"),
                    tooltip = T("Pulse a colored glow around matching callouts."),
                    getFunc = function() return self:GetGroupCallouts().glowEnabled end,
                    setFunc = function(value) self:SetGroupCalloutsValue("glowEnabled", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.glowEnabled,
                },
                {
                    type = "slider",
                    name = T("Glow Intensity"),
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
                    name = T("Glow For"),
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
                    name = T("Text"),
                },
                {
                    type = "dropdown",
                    name = T("Name Font"),
                    choices = { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
                    choicesValues = { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" },
                    getFunc = function() return self:GetGroupCallouts().nameFontKey end,
                    setFunc = function(value) self:SetGroupCalloutsValue("nameFontKey", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.nameFontKey,
                },
                {
                    type = "dropdown",
                    name = T("Message Font"),
                    choices = { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" },
                    choicesValues = { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" },
                    getFunc = function() return self:GetGroupCallouts().messageFontKey end,
                    setFunc = function(value) self:SetGroupCalloutsValue("messageFontKey", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.messageFontKey,
                },
                {
                    type = "slider",
                    name = T("Name Text Size"),
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
                    name = T("Message Text Size"),
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
                    name = T("Text Effect"),
                    choices = { "None", "Soft Thin", "Soft Thick", "Thick Outline" },
                    choicesValues = { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" },
                    getFunc = function() return self:GetGroupCallouts().textEffect end,
                    setFunc = function(value) self:SetGroupCalloutsValue("textEffect", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.textEffect,
                },
                {
                    type = "slider",
                    name = T("Text Opacity"),
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
                    name = T("Background"),
                },
                {
                    type = "checkbox",
                    name = T("Ocultar Background"),
                    tooltip = T("Ocultar the panel and border, but keep the text, icon, and color strip."),
                    getFunc = function() return self:GetGroupCallouts().hideBackground end,
                    setFunc = function(value) self:SetGroupCalloutsValue("hideBackground", value) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = GROUP_CALLOUTS_DEFAULTS.hideBackground,
                },
                {
                    type = "slider",
                    name = T("Background Opacity"),
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
                    name = T("Border Opacity"),
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
                    name = T("Accent Opacity"),
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
                    name = T("Member Colors"),
                },
                {
                    type = "colorpicker",
                    name = T("Member Name"),
                    getFunc = function() return self:GetGroupCalloutsColor("memberNameColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("memberNameColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.memberNameColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = T("Member Message"),
                    getFunc = function() return self:GetGroupCalloutsColor("memberTextColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("memberTextColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.memberTextColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = T("Member Accent"),
                    getFunc = function() return self:GetGroupCalloutsColor("memberAccentColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("memberAccentColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.memberAccentColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = T("Member Background"),
                    getFunc = function() return self:GetGroupCalloutsColor("memberBackgroundColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("memberBackgroundColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() or self:GetGroupCallouts().hideBackground end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.memberBackgroundColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "header",
                    name = T("Leader Colors"),
                },
                {
                    type = "colorpicker",
                    name = T("Leader Name"),
                    getFunc = function() return self:GetGroupCalloutsColor("leaderNameColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("leaderNameColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.leaderNameColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = T("Leader Message"),
                    getFunc = function() return self:GetGroupCalloutsColor("leaderTextColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("leaderTextColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.leaderTextColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = T("Leader Accent"),
                    getFunc = function() return self:GetGroupCalloutsColor("leaderAccentColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("leaderAccentColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.leaderAccentColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "colorpicker",
                    name = T("Leader Background"),
                    getFunc = function() return self:GetGroupCalloutsColor("leaderBackgroundColor") end,
                    setFunc = function(r, g, b) self:SetGroupCalloutsColor("leaderBackgroundColor", r, g, b) end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() or self:GetGroupCallouts().hideBackground end,
                    default = function() local color = GROUP_CALLOUTS_DEFAULTS.leaderBackgroundColor return color.r, color.g, color.b, 1 end,
                },
                {
                    type = "button",
                    name = T("Pré-visualizar Regular Callout"),
                    func = function() self:PreviewGroupCallout() end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                },
                {
                    type = "button",
                    name = T("Pré-visualizar Leader Callout"),
                    func = function() self:PreviewGroupCalloutLeader() end,
                    disabled = function() return not self:IsGroupCalloutsEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = T("Adventure Camera"),
            tooltip = T("Use a relaxed third-person camera out of combat, then switch back for combat."),
            controls =
            {
                {
                    type = "description",
                    text = T("Adventure Camera keeps one camera setup for combat and another for exploration. When you first enable it, your current camera is copied into both setups so nothing jumps. Adjust the sliders below for exploration, then use the capture button whenever you want your current ESO camera to become the combat setup."),
                },
                {
                    type = "checkbox",
                    name = T("Enable Adventure Camera"),
                    getFunc = function() return self:IsAdventureCameraEnabled() end,
                    setFunc = function(value) self:SetAdventureCameraEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.adventureCamera.enabled,
                },
                {
                    type = "slider",
                    name = T("Transition Duration"),
                    tooltip = T("Set how long the camera switch takes, in milliseconds."),
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
                    name = T("Capture Current as Action Camera"),
                    tooltip = T("Save your current ESO third-person camera as the combat camera."),
                    func = function() self:CaptureAdventureCameraActionProfile() end,
                },
                {
                    type = "header",
                    name = T("Adventure Camera"),
                },
                {
                    type = "slider",
                    name = T("Horizontal Look Speed"),
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
                    name = T("Vertical Look Speed"),
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
                    name = T("Field of View"),
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
                    name = T("Horizontal Position"),
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
                    name = T("Horizontal Offset"),
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
                    name = T("Vertical Offset"),
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
            name = T("Compass"),
            controls =
            {
                {
                    type = "checkbox",
                    name = T("Enable Compass Frame"),
                    tooltip = T("Frame the native compass with silver rails, forged steel end pieces, a center bearing marker, and antique direction lettering."),
                    getFunc = function() return self:IsCompassEnabled() end,
                    setFunc = function(value) self:SetCompassEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.compass.enabled,
                },
                {
                    type = "dropdown",
                    name = T("Compass Style"),
                    tooltip = T("NAGA: silver rails with forged steel end caps.\nDS3: single Dark Souls-style compass bar texture (disables the other pieces)."),
                    choices = { "NAGA", "DS3" },
                    choicesValues = { "naga", "ds3" },
                    getFunc = function() return self:GetCompassStyle() end,
                    setFunc = function(value) self:SetCompassStyle(value) end,
                    default = ACCOUNT_DEFAULTS.modules.compass.style,
                    disabled = function() return not self:IsCompassEnabled() end,
                },
                {
                    type = "checkbox",
                    name = T("Eventos (mundo/dinâmico) no Compass"),
                    tooltip = T("Mostra no compass o pin de evento mundial (EventWorld) e de evento dinâmico (ícone padrão do jogo), com animação e distância. Desative para ocultar esses pins."),
                    getFunc = function() return self:IsWorldEventCompassEnabled() end,
                    setFunc = function(value) self:SetWorldEventCompassEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.compass.worldEventPin,
                    disabled = function() return not self:IsCompassEnabled() end,
                },
            },
        },
        {
            type = "submenu",
            name = T("HARDCORE Support"),
            tooltip = T("Choose what HARDCORE hides for this character."),
            controls =
            {
                {
                    type = "checkbox",
                    name = T("Ocultar Compass"),
                    getFunc = function() return self:ShouldHardcoreOcultarCompass() end,
                    setFunc = function(value) self:SetHardcoreOcultarCompass(value) end,
                    default = CHARACTER_DEFAULTS.hardcoreSupport.hideCompass,
                },
                {
                    type = "checkbox",
                    name = T("Ocultar Health Resource Bar"),
                    getFunc = function() return self:ShouldHardcoreOcultarHealthResourceBar() end,
                    setFunc = function(value) self:SetHardcoreOcultarHealthResourceBar(value) end,
                    default = CHARACTER_DEFAULTS.hardcoreSupport.hideHealthResourceBar,
                },
            },
        },
        {
            type = "submenu",
            name = T("Experience Tracker"),
            controls =
            {
                {
                    type = "checkbox",
                    name = T("Enable Experience Tracker"),
                    tooltip = T("Mostrar a NAGA animation when you gain XP or Champion Points."),
                    getFunc = function() return self:IsExperienceTrackerEnabled() end,
                    setFunc = function(value) self:SetExperienceTrackerEnabled(value) end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.enabled,
                },
                {
                    type = "checkbox",
                    name = T("Unlock Experience Tracker"),
                    tooltip = T("Mostrar a drag handle for the tracker. Its position is saved on this server."),
                    getFunc = function() return self:IsExperienceTrackerUnlocked() end,
                    setFunc = function(value) self:SetExperienceTrackerUnlocked(value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.unlocked,
                },
                {
                    type = "checkbox",
                    name = T("Ocultar Stock Progress Bar"),
                    tooltip = T("Ocultar ESO's XP bar while NAGA's tracker is on."),
                    getFunc = function() return self:ShouldExperienceTrackerOcultarStockProgressBar() end,
                    setFunc = function(value) self:SetExperienceTrackerValue("hideStockProgressBar", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.hideStockProgressBar,
                },
                {
                    type = "checkbox",
                    name = T("Mostrar Gained XP Text"),
                    getFunc = function() return self:GetExperienceTracker().showGainText end,
                    setFunc = function(value) self:SetExperienceTrackerValue("showGainText", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.showGainText,
                },
                {
                    type = "checkbox",
                    name = T("Mostrar Progress Text"),
                    tooltip = T("Mostrar your current XP amount and percentage."),
                    getFunc = function() return self:GetExperienceTracker().showProgressText end,
                    setFunc = function(value) self:SetExperienceTrackerValue("showProgressText", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.showProgressText,
                },
                {
                    type = "checkbox",
                    name = T("Mostrar Champion Icon"),
                    tooltip = T("Mostrar the Champion discipline icon in the tracker badge."),
                    getFunc = function() return self:GetExperienceTracker().showChampionIcon end,
                    setFunc = function(value) self:SetExperienceTrackerValue("showChampionIcon", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.showChampionIcon,
                },
                {
                    type = "checkbox",
                    name = T("Ocultar Background"),
                    tooltip = T("Ocultar the panel background, but keep the badge and progress bar."),
                    getFunc = function() return self:GetExperienceTracker().hideBackground end,
                    setFunc = function(value) self:SetExperienceTrackerValue("hideBackground", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.hideBackground,
                },
                {
                    type = "dropdown",
                    name = T("Visibility"),
                    choices = { "Fade After Gains", "Always Visible" },
                    choicesValues = { "fade", "always" },
                    getFunc = function() return self:GetExperienceTracker().visibilityMode end,
                    setFunc = function(value) self:SetExperienceTrackerValue("visibilityMode", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.visibilityMode,
                },
                {
                    type = "dropdown",
                    name = T("Chunk Sound"),
                    tooltip = T("Pick the sound for each XP bar chunk."),
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
                        if NAGA_UI.ExperienceTracker and NAGA_UI.ExperienceTracker.PreviewChunkSound then
                            NAGA_UI.ExperienceTracker:PreviewChunkSound()
                        end
                    end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = GetSoundChoiceLabel(ACCOUNT_DEFAULTS.modules.experienceTracker.chunkSoundKey),
                },
                {
                    type = "dropdown",
                    name = T("Level Up Sound"),
                    tooltip = T("Pick the sound for a new level or Champion Point."),
                    choices =
                    {
                        "None",
                        "Major Victory",
                        "Victory",
                    },
                    getFunc = function() return GetSoundChoiceLabel(self:GetExperienceTracker().levelUpSoundKey) end,
                    setFunc = function(value)
                        self:SetExperienceTrackerValue("levelUpSoundKey", value)
                        if NAGA_UI.ExperienceTracker and NAGA_UI.ExperienceTracker.PreviewLevelUpSound then
                            NAGA_UI.ExperienceTracker:PreviewLevelUpSound()
                        end
                    end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = GetSoundChoiceLabel(ACCOUNT_DEFAULTS.modules.experienceTracker.levelUpSoundKey),
                },
                {
                    type = "checkbox",
                    name = T("Enable Level Up Animation"),
                    tooltip = T("Play a special burst when you gain a level or Champion Point."),
                    getFunc = function() return self:GetExperienceTracker().levelUpAnimationEnabled end,
                    setFunc = function(value) self:SetExperienceTrackerValue("levelUpAnimationEnabled", value) end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                    default = ACCOUNT_DEFAULTS.modules.experienceTracker.levelUpAnimationEnabled,
                },
                {
                    type = "slider",
                    name = T("Scale"),
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
                    name = T("Opacity"),
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
                    name = T("Width"),
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
                    name = T("Height"),
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
                    name = T("Visible Duration"),
                    tooltip = T("Set how long the tracker stays visible after a gain starts, in milliseconds."),
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
                    name = T("Feedback Intensity"),
                    tooltip = T("Set the strength of glow, flash, and fill effects."),
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
                    name = T("Level Up Animation Strength"),
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
                    name = T("Pré-visualizar"),
                    func = function() self:PreviewExperienceTracker() end,
                    disabled = function() return not self:IsExperienceTrackerEnabled() end,
                },
            },
        },
    }
    table.insert(options, 2, {
        type = "submenu",
        name = T("Estatística de Dano"),
        controls = (NAGA_UI.Statistics and NAGA_UI.Statistics.GetOptions and NAGA_UI.Statistics:GetOptions()) or {},
    })

    table.insert(options, 2, {
        type = "submenu",
        name = T("|t32:32:/esoui/art/treeicons/store_indexicon_bundle_up.dds|t Automação"),
        controls = (NAGA_UI.Automation and NAGA_UI.Automation.GetOptions and NAGA_UI.Automation:GetOptions()) or {},
    })

    options = ConfigureModuleMenuOptions(options)

    -- Mouse-wheel on sliders is disabled after the panel is built (no custom LAM widget).
    local noMouseWheelSlider = NAGA_UI.NoMouseWheelSlider
    if noMouseWheelSlider then
        noMouseWheelSlider:Register(LAM)
    end

    -- HUD DE PERSONAGEM no topo + módulos no mesmo nível (sem pasta NAGA Modules)
    local finalOptions = {
        {
            type = "submenu",
            name = T("HUD DE PERSONAGEM"),
            icon = MODULE_MENU_ICONS["HUD DE PERSONAGEM"],
            tooltip = T("Configurações do HUD DE PERSONAGEM."),
            controls = (self.GetHUD2Options and self:GetHUD2Options()) or {},
            reference = "AbyssUI_HUD2_ResourceBarsSubmenu",
        },
    }
    for _, entry in ipairs(options) do
        local ref = entry and entry.reference
        if ref ~= "NAGA_UI_ResourceBarsSubmenu"
            and ref ~= "NAGA_UI_HUD2_ResourceBarsSubmenu"
            and ref ~= "AbyssUI_HUD2_ResourceBarsSubmenu"
        then
            finalOptions[#finalOptions + 1] = entry
        end
    end

    NAGA_UI.Settings.ExportedLamOptions = finalOptions
    NAGA_UI.Settings.ExportedPanelName = panelName

    local lamPanel = LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, finalOptions)

    -- Disable mouse-wheel on all sliders without overwriting LAMCreateControl
    if noMouseWheelSlider and lamPanel then
        zo_callLater(function()
            noMouseWheelSlider:ApplyToPanel(lamPanel)
        end, 100)
        if lamPanel and lamPanel.panel then
            -- Re-apply when the panel is shown (controls may be rebuilt)
            local root = lamPanel.panel
            if root and root.SetHandler then
                local prev = root:GetHandler("OnEffectivelyShown")
                root:SetHandler("OnEffectivelyShown", function(...)
                    if prev then prev(...) end
                    noMouseWheelSlider:ApplyToPanel(lamPanel)
                end)
            end
        end
    end
    if AbyssQuest and AbyssQuest.Settings then
        AbyssQuest.Settings.panel = lamPanel
    end

    for _, eventName in ipairs({ "LAM-PanelOpened", "LAM-PanelClosed" }) do
        local visible = eventName == "LAM-PanelOpened"
        CALLBACK_MANAGER:RegisterCallback(eventName, function(panel)
            if panel and panel:GetName() == panelName and NAGA_UI.Minimap then
                NAGA_UI.Minimap:SetSettingsPanelVisible(visible)
            end
            if panel and panel:GetName() == panelName and NAGA_UI.SynergyAlert then
                NAGA_UI.SynergyAlert:SetSettingsPanelVisible(visible)
            end
        end)
    end
    self:HookResourceBarsSubmenuPreview(panelName)
    self:HookGroupCalloutsSubmenuPreview(panelName)
    self:HookGroupFramesSubmenuPreview(panelName)
    self:HookTargetFrameSubmenuPreview(panelName)
end


-- Opções do HUD 2 (Resource Bars) para o painel AbyssUI.
function Settings:GetHUD2Options()
    local defaults = ACCOUNT_DEFAULTS.modules.resourceBars
    local function GetRB(key)
        local rb = self:GetResourceBars()
        local v = rb and rb[key]
        if v == nil and defaults then v = defaults[key] end
        return v
    end
    local function SetRB(key)
        return function(value)
            self:SetResourceBarsValue(key, value)
        end
    end
    local function Disabled()
        return not self:IsResourceBarsEnabled()
    end

    local formatChoices = { "Nenhum", "Número (1500)", "Percentual (%)", "Número + % (1500 / 100%)", "Atual/Máximo (1500/1500)" }
    local formatValues = { "none", "number", "percent", "numberAndPercent", "currentMax" }
    local posChoices = { "Esquerda", "Centro", "Direita", "Lados (núm | %)" }
    local posValues = { "left", "center", "right", "sides" }
    local fontChoices = { "Game Small", "Game Medium", "Antique", "Trajan", "Univers", "Chat" }
    local fontValues = { "gameSmall", "gameMedium", "antique", "trajan", "univers", "chat" }
    local outlineChoices = { "Nenhum", "Sombra fina", "Sombra grossa", "Contorno grosso" }
    local outlineValues = { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" }
    local identityFontChoices = fontChoices
    local identityFontValues = fontValues
    local identityOutlineChoices = outlineChoices
    local identityOutlineValues = outlineValues
    local layoutChoices = { "Empilhado (Vida→Magicka→Vigor)", "Pirâmide", "Linear (lado a lado)" }
    local layoutValues = { "stacked", "pyramid", "linear" }

    return {
        {
            type = "description",
            text = T("Configurações do |cFFFFFFHUD DE PERSONAGEM|r."),
            width = "full",
        },
        {
            type = "checkbox",
            name = T("Desbloquear posição (mover)"),
            tooltip = T("Mostra a alça para arrastar as barras do HUD 2 pela tela."),
            getFunc = function() return self:IsResourceBarsUnlocked() end,
            setFunc = function(value) self:SetResourceBarsUnlocked(value == true) end,
            disabled = Disabled,
            default = false,
        },
        {
            type = "header",
            name = T("Layout e tamanho"),
            width = "full",
        },
        {
            type = "dropdown",
            name = T("Layout das barras"),
            choices = layoutChoices,
            choicesValues = layoutValues,
            getFunc = function() return GetRB("layout") or "stacked" end,
            setFunc = SetRB("layout"),
            disabled = Disabled,
            default = "stacked",
        },
        {
            type = "slider",
            name = T("Escala geral"),
            min = 70, max = 160, step = 1,
            getFunc = function() return GetRB("scale") or 109 end,
            setFunc = SetRB("scale"),
            disabled = Disabled,
            default = defaults.scale,
        },
        {
            type = "slider",
            name = T("Altura das barras"),
            min = 10, max = 48, step = 1,
            getFunc = function() return GetRB("barHeight") or 25 end,
            setFunc = SetRB("barHeight"),
            disabled = Disabled,
            default = defaults.barHeight,
        },
        {
            type = "slider",
            name = T("Espaçamento entre linhas"),
            min = 0, max = 32, step = 1,
            getFunc = function() return GetRB("rowSpacing") or 5 end,
            setFunc = SetRB("rowSpacing"),
            disabled = Disabled,
            default = defaults.rowSpacing,
        },
        {
            type = "slider",
            name = T("Largura — Vida"),
            min = 120, max = 500, step = 5,
            getFunc = function() return GetRB("rowHealthWidth") or 300 end,
            setFunc = SetRB("rowHealthWidth"),
            disabled = Disabled,
            default = defaults.rowHealthWidth,
        },
        {
            type = "slider",
            name = T("Largura — Magicka"),
            min = 120, max = 500, step = 5,
            getFunc = function() return GetRB("rowMagickaWidth") or 270 end,
            setFunc = SetRB("rowMagickaWidth"),
            disabled = Disabled,
            default = defaults.rowMagickaWidth,
        },
        {
            type = "slider",
            name = T("Largura — Vigor"),
            min = 120, max = 500, step = 5,
            getFunc = function() return GetRB("rowStaminaWidth") or 270 end,
            setFunc = SetRB("rowStaminaWidth"),
            disabled = Disabled,
            default = defaults.rowStaminaWidth,
        },
        {
            type = "slider",
            name = T("Opacidade"),
            min = 10, max = 100, step = 1,
            getFunc = function() return GetRB("opacity") or 100 end,
            setFunc = SetRB("opacity"),
            disabled = Disabled,
            default = defaults.opacity,
        },
        {
            type = "checkbox",
            name = T("Gloss (brilho)"),
            tooltip = T("Ativa o brilho/reflexo sobre o preenchimento das barras."),
            getFunc = function() return GetRB("glossEnabled") ~= false end,
            setFunc = SetRB("glossEnabled"),
            disabled = Disabled,
            default = defaults.glossEnabled ~= false,
        },
        {
            type = "checkbox",
            name = T("Padrão de preenchimento"),
            tooltip = T("Sobreposição de padrão (lava, fumaça, etc.) sobre as barras."),
            getFunc = function() return GetRB("barPatternEnabled") == true end,
            setFunc = SetRB("barPatternEnabled"),
            disabled = Disabled,
            default = defaults.barPatternEnabled == true,
        },
        {
            type = "dropdown",
            name = T("Tipo de padrão"),
            choices = { "ZigZag", "Smoke", "Still Water", "Stone", "Dirt", "Lava", "Rock Lava", "Lava Wave", "Molten" },
            choicesValues = { "ZigZag", "smoke", "stillwater", "Stone", "Dirt", "Lava", "RockLava", "LavaWave", "Molten" },
            getFunc = function() return GetRB("barPatternKey") or "Molten" end,
            setFunc = SetRB("barPatternKey"),
            disabled = function() return Disabled() or GetRB("barPatternEnabled") ~= true end,
            default = defaults.barPatternKey or "Molten",
        },
        {
            type = "slider",
            name = T("Opacidade do padrão"),
            min = 0, max = 40, step = 1,
            getFunc = function() return GetRB("barPatternOpacity") or 6 end,
            setFunc = SetRB("barPatternOpacity"),
            disabled = function() return Disabled() or GetRB("barPatternEnabled") ~= true end,
            default = defaults.barPatternOpacity or 6,
        },
        {
            type = "slider",
            name = T("Escala do padrão"),
            min = 24, max = 256, step = 4,
            getFunc = function() return GetRB("barPatternScale") or 228 end,
            setFunc = SetRB("barPatternScale"),
            disabled = function() return Disabled() or GetRB("barPatternEnabled") ~= true end,
            default = defaults.barPatternScale or 228,
        },
        {
            type = "header",
            name = T("Identidade do jogador"),
            width = "full",
        },
        {
            type = "description",
            text = T("Centraliza classe + nick + ícone de CP/nível acima das barras. Ajuste o tamanho dos ícones e do nick abaixo."),
            width = "full",
        },
        {
            type = "slider",
            name = T("Tamanho do ícone de classe"),
            min = 10, max = 40, step = 1,
            getFunc = function() return GetRB("identityClassIconSize") or 18 end,
            setFunc = SetRB("identityClassIconSize"),
            disabled = Disabled,
            default = defaults.identityClassIconSize or 18,
        },
        {
            type = "slider",
            name = T("Tamanho do ícone de CP/nível"),
            tooltip = T("Tamanho do ícone de CP acima da sua vida (independente do target). Padrão = tamanho do ícone de classe."),
            min = 8, max = 40, step = 1,
            getFunc = function() return GetRB("identityLevelIconSize") or GetRB("identityClassIconSize") or 18 end,
            setFunc = SetRB("identityLevelIconSize"),
            disabled = Disabled,
            default = defaults.identityLevelIconSize or 18,
        },
        {
            type = "slider",
            name = T("Tamanho do nick"),
            min = 10, max = 32, step = 1,
            getFunc = function() return GetRB("identityNameSize") or 18 end,
            setFunc = SetRB("identityNameSize"),
            disabled = Disabled,
            default = defaults.identityNameSize or 18,
        },
        {
            type = "dropdown",
            name = T("Fonte do nick"),
            tooltip = T("Escolha a fonte usada somente no nome do personagem."),
            choices = identityFontChoices,
            choicesValues = identityFontValues,
            getFunc = function() return GetRB("identityNameFontKey") or "gameSmall" end,
            setFunc = SetRB("identityNameFontKey"),
            disabled = Disabled,
            default = defaults.identityNameFontKey or "gameSmall",
        },
        {
            type = "dropdown",
            name = T("Contorno/sombra do nick"),
            tooltip = T("Define o contorno ou sombra aplicada ao nome do personagem."),
            choices = identityOutlineChoices,
            choicesValues = identityOutlineValues,
            getFunc = function() return GetRB("identityNameOutline") or "thick-outline" end,
            setFunc = SetRB("identityNameOutline"),
            disabled = Disabled,
            default = defaults.identityNameOutline or "thick-outline",
        },
        {
            type = "slider",
            name = T("Opacidade do nick"),
            min = 10, max = 100, step = 1,
            getFunc = function() return GetRB("identityNameOpacity") or 100 end,
            setFunc = SetRB("identityNameOpacity"),
            disabled = Disabled,
            default = defaults.identityNameOpacity or 100,
        },
        {
            type = "colorpicker",
            name = T("Cor do nick"),
            tooltip = T("Escolha a cor usada somente no nome do personagem."),
            getFunc = function()
                local color = self:GetResourceBarsColor("identityNameColor")
                return color.r, color.g, color.b, 1
            end,
            setFunc = function(r, g, b)
                self:SetResourceBarsColor("identityNameColor", r, g, b)
            end,
            disabled = Disabled,
            default = function()
                local color = defaults.identityNameColor or { r = 0.92, g = 0.90, b = 0.84 }
                return color.r, color.g, color.b, 1
            end,
        },
        {
            type = "header",
            name = T("Texto das barras"),
            width = "full",
        },
        {
            type = "dropdown",
            name = T("Formato — Vida"),
            tooltip = T("Número, %, número+%, ou atual/máximo (1500/1500)."),
            choices = formatChoices,
            choicesValues = formatValues,
            getFunc = function() return GetRB("healthTextFormat") or "numberAndPercent" end,
            setFunc = SetRB("healthTextFormat"),
            disabled = Disabled,
            default = defaults.healthTextFormat,
        },
        {
            type = "dropdown",
            name = T("Posição do texto — Vida"),
            choices = posChoices,
            choicesValues = posValues,
            getFunc = function() return GetRB("healthTextPosition") or "sides" end,
            setFunc = SetRB("healthTextPosition"),
            disabled = Disabled,
            default = defaults.healthTextPosition,
        },
        {
            type = "dropdown",
            name = T("Formato — Magicka"),
            choices = formatChoices,
            choicesValues = formatValues,
            getFunc = function() return GetRB("magickaTextFormat") or "numberAndPercent" end,
            setFunc = SetRB("magickaTextFormat"),
            disabled = Disabled,
            default = defaults.magickaTextFormat,
        },
        {
            type = "dropdown",
            name = T("Posição do texto — Magicka"),
            choices = posChoices,
            choicesValues = posValues,
            getFunc = function() return GetRB("magickaTextPosition") or "sides" end,
            setFunc = SetRB("magickaTextPosition"),
            disabled = Disabled,
            default = defaults.magickaTextPosition,
        },
        {
            type = "dropdown",
            name = T("Formato — Vigor"),
            choices = formatChoices,
            choicesValues = formatValues,
            getFunc = function() return GetRB("staminaTextFormat") or "numberAndPercent" end,
            setFunc = SetRB("staminaTextFormat"),
            disabled = Disabled,
            default = defaults.staminaTextFormat,
        },
        {
            type = "dropdown",
            name = T("Posição do texto — Vigor"),
            choices = posChoices,
            choicesValues = posValues,
            getFunc = function() return GetRB("staminaTextPosition") or "sides" end,
            setFunc = SetRB("staminaTextPosition"),
            disabled = Disabled,
            default = defaults.staminaTextPosition,
        },
        {
            type = "header",
            name = T("Fonte"),
            width = "full",
        },
        {
            type = "dropdown",
            name = T("Fonte do texto"),
            choices = fontChoices,
            choicesValues = fontValues,
            getFunc = function() return GetRB("textFontKey") or "gameSmall" end,
            setFunc = SetRB("textFontKey"),
            disabled = Disabled,
            default = defaults.textFontKey,
        },
        {
            type = "slider",
            name = T("Tamanho da fonte"),
            min = 8, max = 32, step = 1,
            getFunc = function() return GetRB("textSize") or 18 end,
            setFunc = SetRB("textSize"),
            disabled = Disabled,
            default = defaults.textSize,
        },
        {
            type = "dropdown",
            name = T("Contorno da fonte"),
            choices = outlineChoices,
            choicesValues = outlineValues,
            getFunc = function() return GetRB("textOutline") or "thick-outline" end,
            setFunc = SetRB("textOutline"),
            disabled = Disabled,
            default = defaults.textOutline,
        },
        {
            type = "slider",
            name = T("Opacidade do texto"),
            min = 10, max = 100, step = 1,
            getFunc = function() return GetRB("textOpacity") or 100 end,
            setFunc = SetRB("textOpacity"),
            disabled = Disabled,
            default = defaults.textOpacity,
        },
        {
            type = "slider",
            name = T("Recuo do texto (bordas)"),
            min = 0, max = 24, step = 1,
            getFunc = function() return GetRB("textInset") or 6 end,
            setFunc = SetRB("textInset"),
            disabled = Disabled,
            default = defaults.textInset,
        },
        {
            type = "slider",
            name = T("Deslocamento vertical do texto"),
            min = -8, max = 8, step = 1,
            getFunc = function() return GetRB("textVerticalOffset") or 3 end,
            setFunc = SetRB("textVerticalOffset"),
            disabled = Disabled,
            default = defaults.textVerticalOffset,
        },
    }
end

-- GetHUD2Options definido acima (Settings:GetHUD2Options)

