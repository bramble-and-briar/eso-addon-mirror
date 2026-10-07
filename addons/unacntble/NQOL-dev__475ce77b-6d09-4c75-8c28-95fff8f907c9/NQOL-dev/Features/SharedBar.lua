NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local PlayerBars = {}
NQOL.Features.PlayerBars = PlayerBars
PlayerBars.Shared = {}

local Shared = PlayerBars.Shared
PlayerBars.SIEGE_HEALTH = "siegeHealth"
PlayerBars.TEXTURE_NO_HEALING = "EsoUI/Art/UnitAttributeVisualizer/Gamepad/gp_attributeBar_dynamic_invulnerable_munge.dds"
PlayerBars.CHAMPION_ICON = "EsoUI/Art/TreeIcons/achievements_indexIcon_champion_up.dds"

local C = {
    EVENT_NAMESPACE = "NQOL_PlayerBars",
    ROOT_CONTROL_NAME = "NQOLPlayerBarsRoot",
    TEXTURE_WHITE = "EsoUI/Art/Miscellaneous/white.dds",
    TEXTURE_FILL = "EsoUI/Art/Miscellaneous/progressbar_genericFill.dds",
    APPLY_DELAY_MS = 50,
    FRAME_VISIBILITY_TRANSITION_MS = 500,
    DEFAULT_WIDTH = 470,
    HEALTH_HEIGHT = 24,
    RESOURCE_HEIGHT = 17,
    MOUNT_HEIGHT = 10,
    ROW_GAP = 3,
    CLASSIC_WIDTH = 620,
    CLASSIC_WIDTH_RATIO = 0.42,
    CLASSIC_MIN_WIDTH = 420,
    CLASSIC_MOUNT_HEIGHT = 12,
    CLASSIC_ROW_GAP = 4,
    CLASSIC_LABEL_PADDING = 8,
    CLASSIC_DEFAULT_FONT_SIZE = 18,
    CLASSIC_FONT_SIZE_MIN = 10,
    CLASSIC_FONT_SIZE_MAX = 34,
    CLASSIC_DEFAULT_FLYING_FONT_SIZE = 30,
    CLASSIC_FLYING_FONT_SIZE_MIN = 12,
    CLASSIC_FLYING_FONT_SIZE_MAX = 52,
    CLASSIC_CHANGE_FLOAT_DISTANCE = 34,
    CLASSIC_CHANGE_ANIMATION_MS = 900,
    CLASSIC_CHANGE_FADE_DELAY_MS = 260,
    CLASSIC_CHANGE_POOL_SIZE = 4,
    CLASSIC_CHANGE_RANDOM_OFFSET = 28,
    CLASSIC_DEFAULT_BOX_HEIGHT = 28,
    CLASSIC_DEFAULT_SEPARATION = 24,
    CLASSIC_DEFAULT_HEALTH_WIDTH = 190,
    CLASSIC_DEFAULT_MAGICKA_WIDTH = 190,
    CLASSIC_DEFAULT_STAMINA_WIDTH = 190,
    CLASSIC_DEFAULT_BORDER_SIZE = 0,
    CLASSIC_BORDER_SIZE_MIN = 0,
    CLASSIC_BORDER_SIZE_MAX = 12,
    OUTER_PADDING = 0,
    BAR_INSET = 2,
    DRAW_LEVEL = 45,
    CLASSIC = "classic",
    PYRAMID = "pyramid",
    STACK = "stack",
    VERTICAL = "vertical",
    RADIAL = "radial",
    CLASSIC_NAME = NQOL.L("features.player_bars.preset_classic"),
    PYRAMID_NAME = NQOL.L("features.player_bars.preset_pyramid"),
    STACK_NAME = NQOL.L("features.player_bars.preset_stack"),
    VERTICAL_NAME = NQOL.L("features.player_bars.preset_vertical"),
    RADIAL_NAME = NQOL.L("features.player_bars.preset_radial"),
    RADIAL_STACK_NOTHING = "nothing",
    RADIAL_STACK_MAGICKA_STAMINA = "magicka-stamina",
    RADIAL_STACK_STAMINA_MAGICKA = "stamina-magicka",
    RADIAL_STACK_TYPE_EQUAL = "equal",
    RADIAL_STACK_TYPE_RELATIVE = "relative",
    RADIAL_SCALE_MIN = 50,
    RADIAL_SCALE_MAX = 200,
    FLYING_ORIENTATION_LEFT = "left",
    FLYING_ORIENTATION_RIGHT = "right",
    FLYING_ORIENTATION_CHOICE_NAMES = { NQOL.L("common.left"), NQOL.L("common.right") },
    CURRENT_VALUE = {
        NUMBER = "number",
        PERCENTAGE = "percentage",
        CHOICES = { "number", "percentage" },
        CHOICE_NAMES = { NQOL.L("common.number"), NQOL.L("common.percentage") },
        VALID_CHOICES = {
            number = true,
            percentage = true,
        },
    },
    GAMEPLAY_SCENES = {
        hud = true,
        hudui = true,
        siegeBar = true,
        siegeBarUI = true,
    },
    RESOURCE_HEALTH = COMBAT_MECHANIC_FLAGS_HEALTH,
    RESOURCE_MAGICKA = COMBAT_MECHANIC_FLAGS_MAGICKA,
    RESOURCE_STAMINA = COMBAT_MECHANIC_FLAGS_STAMINA,
    RESOURCE_MOUNT_STAMINA = COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA,
    PLAYER_SHIELD_SMOOTH_KEY = "playerShield",
}
C.FLYING_ORIENTATION_CHOICES = { C.FLYING_ORIENTATION_LEFT, C.FLYING_ORIENTATION_RIGHT }
C.RADIAL_STACK_CHOICES = { C.RADIAL_STACK_NOTHING, C.RADIAL_STACK_MAGICKA_STAMINA, C.RADIAL_STACK_STAMINA_MAGICKA }
C.RADIAL_STACK_CHOICE_NAMES = { NQOL.L("common.nothing"), NQOL.L("features.player_bars.magicka_stamina"), NQOL.L("features.player_bars.stamina_magicka") }
C.RADIAL_STACK_VALID = {
    [C.RADIAL_STACK_NOTHING] = true,
    [C.RADIAL_STACK_MAGICKA_STAMINA] = true,
    [C.RADIAL_STACK_STAMINA_MAGICKA] = true,
}
C.RADIAL_STACK_TYPE_CHOICES = { C.RADIAL_STACK_TYPE_EQUAL, C.RADIAL_STACK_TYPE_RELATIVE }
C.RADIAL_STACK_TYPE_CHOICE_NAMES = { NQOL.L("common.equal"), NQOL.L("common.relative") }
C.RADIAL_STACK_TYPE_VALID = {
    [C.RADIAL_STACK_TYPE_EQUAL] = true,
    [C.RADIAL_STACK_TYPE_RELATIVE] = true,
}
C.PRESET_CHOICES = { C.CLASSIC, C.PYRAMID, C.STACK, C.VERTICAL, C.RADIAL }
C.PRESET_CHOICE_NAMES = { C.CLASSIC_NAME, C.PYRAMID_NAME, C.STACK_NAME, C.VERTICAL_NAME, C.RADIAL_NAME }
C.VALID_PRESETS = {
    [C.CLASSIC] = true,
    [C.PYRAMID] = true,
    [C.STACK] = true,
    [C.VERTICAL] = true,
    [C.RADIAL] = true,
}
C.RESOURCE_KEYS = {
    C.RESOURCE_HEALTH,
    C.RESOURCE_MAGICKA,
    C.RESOURCE_STAMINA,
    C.RESOURCE_MOUNT_STAMINA,
    COMBAT_MECHANIC_FLAGS_WEREWOLF,
    PlayerBars.SIEGE_HEALTH,
}
C.RESOURCE_COLORS = {
    [C.RESOURCE_HEALTH] = { 0.86, 0.12, 0.09, 1.00 },
    [C.RESOURCE_MAGICKA] = { 0.16, 0.43, 0.95, 1.00 },
    [C.RESOURCE_STAMINA] = { 0.20, 0.72, 0.21, 1.00 },
    [C.RESOURCE_MOUNT_STAMINA] = { 0.88, 0.67, 0.34, 1.00 },
    [COMBAT_MECHANIC_FLAGS_WEREWOLF] = { 0.58, 0.22, 0.86, 1.00 },
    [PlayerBars.SIEGE_HEALTH] = { 0.86, 0.12, 0.09, 1.00 },
}
C.PLAYER_TRAUMA_COLOR = { 0.42, 0.76, 0.82, 0.82 }
C.PLAYER_SHIELD_COLOR = { 1.00, 0.50, 0.00, 1.00 }
C.PLAYER_RESOURCE_COLOR_KEYS = {
    [C.RESOURCE_HEALTH] = "health",
    [C.RESOURCE_MAGICKA] = "magicka",
    [C.RESOURCE_STAMINA] = "stamina",
}
PlayerBars.Constants = C

local COMPANION = {
    EVENT_NAMESPACE = "NQOL_CompanionFrame",
    ROOT_CONTROL_NAME = "NQOLCompanionFrameRoot",
    HORIZONTAL = "horizontal",
    VERTICAL = "vertical",
    ORIENTATION_CHOICE_NAMES = { NQOL.L("common.horizontal"), NQOL.L("common.vertical") },
    DEFAULT_WIDTH = 220,
    DEFAULT_HEIGHT = 26,
    WIDTH_MIN = 40,
    WIDTH_MAX = 600,
    HEIGHT_MIN = 10,
    HEIGHT_MAX = 400,
    LABEL_HEIGHT = 22,
    LABEL_GAP = 4,
    XP_BAR_HEIGHT = 7,
    XP_BAR_GAP = 2,
    RAPPORT_ICON = "EsoUI/Art/HUD/lootHistory_icon_rapportIncrease_generic.dds",
    resourceValue = {
        current = nil,
        maximum = nil,
        effectiveMaximum = nil,
        hidden = nil,
    },
}
COMPANION.ORIENTATION_CHOICES = { COMPANION.HORIZONTAL, COMPANION.VERTICAL }
COMPANION.VALID_ORIENTATIONS = {
    [COMPANION.HORIZONTAL] = true,
    [COMPANION.VERTICAL] = true,
}
PlayerBars.Companion = COMPANION
local Shadow = {
    NONE = "none",
    TOP = "top",
    BOTTOM = "bottom",
    LEFT = "left",
    RIGHT = "right",
    CHOICE_NAMES = { NQOL.L("common.none"), NQOL.L("common.top"), NQOL.L("common.bottom"), NQOL.L("common.left"), NQOL.L("common.right") },
    INTENSITY_MIN = 0,
    INTENSITY_MAX = 100,
    INTENSITY_DEFAULT = 50,
    HEIGHT_RATIO = 0.55,
    STRIPS = 12,
}
Shadow.CHOICES = { Shadow.NONE, Shadow.TOP, Shadow.BOTTOM, Shadow.LEFT, Shadow.RIGHT }
Shadow.VALID = {
    [Shadow.NONE] = true,
    [Shadow.TOP] = true,
    [Shadow.BOTTOM] = true,
    [Shadow.LEFT] = true,
    [Shadow.RIGHT] = true,
}
PlayerBars.Shadow = Shadow
PlayerBars.Group = {
    EVENT_NAMESPACE = "NQOL_GroupFrame",
    ROOT_CONTROL_NAME = "NQOLGroupFrameRoot",
    MAX_ROWS = 12,
    NAME_DISPLAY_PLAYER_ID = "playerId",
    NAME_DISPLAY_CHARACTER = "characterName",
    NAME_DISPLAY_CHOICES = { "playerId", "characterName" },
    NAME_DISPLAY_CHOICE_NAMES = { NQOL.L("common.player_id"), NQOL.L("common.character_name") },
    NAME_DISPLAY_VALID_CHOICES = {
        playerId = true,
        characterName = true,
    },
    CHAMPION_POINTS_BEFORE = "before",
    CHAMPION_POINTS_AFTER = "after",
    CHAMPION_POINTS_PLACEMENT_CHOICES = { "before", "after" },
    CHAMPION_POINTS_PLACEMENT_CHOICE_NAMES = { NQOL.L("common.before"), NQOL.L("common.after") },
    CHAMPION_POINTS_PLACEMENT_VALID_CHOICES = {
        before = true,
        after = true,
    },
    DEFAULT_WIDTH = 260,
    DEFAULT_HEIGHT = 26,
    DEFAULT_ROW_GAP = 4,
    DEFAULT_COLUMN_GAP = 0,
    DEFAULT_COLUMNS = 1,
    COLUMNS_MIN = 1,
    COLUMNS_MAX = 2,
    WIDTH_MIN = 80,
    WIDTH_MAX = 700,
    HEIGHT_MIN = 10,
    HEIGHT_MAX = 80,
    ROW_GAP_MIN = 0,
    ROW_GAP_MAX = 30,
    COLUMN_GAP_MIN = 0,
    COLUMN_GAP_MAX = 30,
    ICON_SIZE = 22,
    ICON_GAP = 4,
    VALUE_WIDTH = 86,
    ROLE_SORT_ORDER = {
        tank = 1,
        heal = 2,
        dps = 3,
    },
    AWAY_OPACITY_DEFAULT = 15,
    LEADER_ICON = "EsoUI/Art/UnitFrames/Gamepad/gp_Group_Leader.dds",
    DEAD_ICON = "EsoUI/Art/UnitFrames/Gamepad/gp_deathStatus.dds",
    OFFLINE_ICON = "EsoUI/Art/UnitFrames/Gamepad/gp_offlineStatus.dds",
    DEATH_COUNTER_ICON = "EsoUI/Art/TargetMarkers/Gamepad/Target_White_Skull.dds",
    RESURRECT_PENDING_ICON = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_timer32.dds",
    COMPANION_ICON = "EsoUI/Art/MapPins/activeCompanion_pin.dds",
    DEATH_COUNTER_WIDTH = 54,
    ROLE_COLOR_DPS = "FF007FFF",
    ROLE_COLOR_TANK = "FFFF0000",
    ROLE_COLOR_HEAL = "FFFFFF00",
    FALLBACK_ROLE = "dps",
    roleValues = {},
}
NQOL.Lexicon.RegisterRefreshCallback(function()
    C.CLASSIC_NAME = NQOL.L("features.player_bars.preset_classic")
    C.PYRAMID_NAME = NQOL.L("features.player_bars.preset_pyramid")
    C.STACK_NAME = NQOL.L("features.player_bars.preset_stack")
    C.VERTICAL_NAME = NQOL.L("features.player_bars.preset_vertical")
    C.RADIAL_NAME = NQOL.L("features.player_bars.preset_radial")
    C.PRESET_CHOICE_NAMES[1], C.PRESET_CHOICE_NAMES[2], C.PRESET_CHOICE_NAMES[3] = C.CLASSIC_NAME, C.PYRAMID_NAME, C.STACK_NAME
    C.PRESET_CHOICE_NAMES[4], C.PRESET_CHOICE_NAMES[5] = C.VERTICAL_NAME, C.RADIAL_NAME
    C.FLYING_ORIENTATION_CHOICE_NAMES[1], C.FLYING_ORIENTATION_CHOICE_NAMES[2] = NQOL.L("common.left"), NQOL.L("common.right")
    C.CURRENT_VALUE.CHOICE_NAMES[1], C.CURRENT_VALUE.CHOICE_NAMES[2] = NQOL.L("common.number"), NQOL.L("common.percentage")
    C.RADIAL_STACK_CHOICE_NAMES[1] = NQOL.L("common.nothing")
    C.RADIAL_STACK_CHOICE_NAMES[2] = NQOL.L("features.player_bars.magicka_stamina")
    C.RADIAL_STACK_CHOICE_NAMES[3] = NQOL.L("features.player_bars.stamina_magicka")
    C.RADIAL_STACK_TYPE_CHOICE_NAMES[1], C.RADIAL_STACK_TYPE_CHOICE_NAMES[2] = NQOL.L("common.equal"), NQOL.L("common.relative")
    COMPANION.ORIENTATION_CHOICE_NAMES[1], COMPANION.ORIENTATION_CHOICE_NAMES[2] = NQOL.L("common.horizontal"), NQOL.L("common.vertical")
    Shadow.CHOICE_NAMES[1], Shadow.CHOICE_NAMES[2], Shadow.CHOICE_NAMES[3] = NQOL.L("common.none"), NQOL.L("common.top"), NQOL.L("common.bottom")
    Shadow.CHOICE_NAMES[4], Shadow.CHOICE_NAMES[5] = NQOL.L("common.left"), NQOL.L("common.right")
    PlayerBars.Group.NAME_DISPLAY_CHOICE_NAMES[1], PlayerBars.Group.NAME_DISPLAY_CHOICE_NAMES[2] = NQOL.L("common.player_id"), NQOL.L("common.character_name")
    PlayerBars.Group.CHAMPION_POINTS_PLACEMENT_CHOICE_NAMES[1], PlayerBars.Group.CHAMPION_POINTS_PLACEMENT_CHOICE_NAMES[2] = NQOL.L("common.before"), NQOL.L("common.after")
end)
local function DefaultPlayerBarColors()
    return {
        health = { r = C.RESOURCE_COLORS[C.RESOURCE_HEALTH][1], g = C.RESOURCE_COLORS[C.RESOURCE_HEALTH][2], b = C.RESOURCE_COLORS[C.RESOURCE_HEALTH][3], a = C.RESOURCE_COLORS[C.RESOURCE_HEALTH][4] },
        magicka = { r = C.RESOURCE_COLORS[C.RESOURCE_MAGICKA][1], g = C.RESOURCE_COLORS[C.RESOURCE_MAGICKA][2], b = C.RESOURCE_COLORS[C.RESOURCE_MAGICKA][3], a = C.RESOURCE_COLORS[C.RESOURCE_MAGICKA][4] },
        stamina = { r = C.RESOURCE_COLORS[C.RESOURCE_STAMINA][1], g = C.RESOURCE_COLORS[C.RESOURCE_STAMINA][2], b = C.RESOURCE_COLORS[C.RESOURCE_STAMINA][3], a = C.RESOURCE_COLORS[C.RESOURCE_STAMINA][4] },
        trauma = { r = C.PLAYER_TRAUMA_COLOR[1], g = C.PLAYER_TRAUMA_COLOR[2], b = C.PLAYER_TRAUMA_COLOR[3], a = C.PLAYER_TRAUMA_COLOR[4] },
        shield = { r = C.PLAYER_SHIELD_COLOR[1], g = C.PLAYER_SHIELD_COLOR[2], b = C.PLAYER_SHIELD_COLOR[3], a = C.PLAYER_SHIELD_COLOR[4] },
    }
end
local function DefaultCompanionXpColor()
    if GetInterfaceColor and INTERFACE_COLOR_TYPE_PROGRESSION and PROGRESSION_COLOR_XP_START then
        local red, green, blue, alpha = GetInterfaceColor(INTERFACE_COLOR_TYPE_PROGRESSION, PROGRESSION_COLOR_XP_START)
        return { r = red, g = green, b = blue, a = alpha }
    end

    return { r = 0.20, g = 0.72, b = 0.82, a = 1 }
end
local defaults = {
    ui = {
        customFrames = {
            playerFrame = {
                showNqolPlayerFrame = false,
                showOnlyInCombat = false,
                preset = C.CLASSIC,
                showInSettings = true,
                showShield = false,
                showTrauma = false,
                showNoHealing = false,
                classic = {
                    barColors = DefaultPlayerBarColors(),
                    horizontalPosition = 50,
                    verticalPosition = 86,
                    boxHeight = C.CLASSIC_DEFAULT_BOX_HEIGHT,
                    separation = C.CLASSIC_DEFAULT_SEPARATION,
                    healthWidth = C.CLASSIC_DEFAULT_HEALTH_WIDTH,
                    magickaWidth = C.CLASSIC_DEFAULT_MAGICKA_WIDTH,
                    staminaWidth = C.CLASSIC_DEFAULT_STAMINA_WIDTH,
                    borderSize = C.CLASSIC_DEFAULT_BORDER_SIZE,
                    smoothTransitions = true,
                    transitionShadow = true,
                    font = NQOL.Util.GetDefaultFont(),
                    fontSize = C.CLASSIC_DEFAULT_FONT_SIZE,
                    currentValue = C.CURRENT_VALUE.NUMBER,
                    flyingPositiveAnimation = true,
                    flyingNegativeAnimation = true,
                    flyingOrientation = C.FLYING_ORIENTATION_LEFT,
                    flyingAnimationFont = NQOL.Util.GetDefaultFont(),
                    flyingAnimationFontSize = C.CLASSIC_DEFAULT_FLYING_FONT_SIZE,
                    shadow = Shadow.TOP,
                    shadowIntensity = 25,
                },
                pyramid = {
                    barColors = DefaultPlayerBarColors(),
                    horizontalPosition = 50,
                    verticalPosition = 86,
                    healthHeight = C.CLASSIC_DEFAULT_BOX_HEIGHT,
                    resourceHeight = C.CLASSIC_DEFAULT_BOX_HEIGHT,
                    healthWidth = C.CLASSIC_DEFAULT_HEALTH_WIDTH,
                    magickaWidth = C.CLASSIC_DEFAULT_MAGICKA_WIDTH,
                    staminaWidth = C.CLASSIC_DEFAULT_STAMINA_WIDTH,
                    borderSize = C.CLASSIC_DEFAULT_BORDER_SIZE,
                    smoothTransitions = true,
                    transitionShadow = true,
                    font = NQOL.Util.GetDefaultFont(),
                    fontSize = C.CLASSIC_DEFAULT_FONT_SIZE,
                    currentValue = C.CURRENT_VALUE.NUMBER,
                    flyingPositiveAnimation = true,
                    flyingNegativeAnimation = true,
                    flyingAnimationFont = NQOL.Util.GetDefaultFont(),
                    flyingAnimationFontSize = C.CLASSIC_DEFAULT_FLYING_FONT_SIZE,
                    shadow = Shadow.TOP,
                    shadowIntensity = 25,
                },
                stack = {
                    barColors = DefaultPlayerBarColors(),
                    horizontalPosition = 50,
                    verticalPosition = 86,
                    healthHeight = C.CLASSIC_DEFAULT_BOX_HEIGHT,
                    magickaHeight = C.CLASSIC_DEFAULT_BOX_HEIGHT,
                    staminaHeight = C.CLASSIC_DEFAULT_BOX_HEIGHT,
                    width = C.CLASSIC_DEFAULT_HEALTH_WIDTH,
                    borderSize = C.CLASSIC_DEFAULT_BORDER_SIZE,
                    smoothTransitions = true,
                    transitionShadow = true,
                    font = NQOL.Util.GetDefaultFont(),
                    fontSize = C.CLASSIC_DEFAULT_FONT_SIZE,
                    currentValue = C.CURRENT_VALUE.NUMBER,
                    reverse = false,
                    flyingPositiveAnimation = true,
                    flyingNegativeAnimation = true,
                    flyingAnimationFont = NQOL.Util.GetDefaultFont(),
                    flyingAnimationFontSize = C.CLASSIC_DEFAULT_FLYING_FONT_SIZE,
                    shadow = Shadow.TOP,
                    shadowIntensity = 25,
                },
                vertical = {
                    barColors = DefaultPlayerBarColors(),
                    healthWidth = 34,
                    healthHeight = 180,
                    healthHorizontalPosition = 50,
                    healthVerticalPosition = 84,
                    healthFlyingOrientation = C.FLYING_ORIENTATION_LEFT,
                    healthReverse = false,
                    healthCurrentValue = C.CURRENT_VALUE.NUMBER,
                    magickaWidth = 30,
                    magickaHeight = 150,
                    magickaHorizontalPosition = 47,
                    magickaVerticalPosition = 88,
                    magickaFlyingOrientation = C.FLYING_ORIENTATION_LEFT,
                    magickaReverse = false,
                    magickaCurrentValue = C.CURRENT_VALUE.NUMBER,
                    staminaWidth = 30,
                    staminaHeight = 150,
                    staminaHorizontalPosition = 53,
                    staminaVerticalPosition = 88,
                    staminaFlyingOrientation = C.FLYING_ORIENTATION_RIGHT,
                    staminaReverse = false,
                    staminaCurrentValue = C.CURRENT_VALUE.NUMBER,
                    borderSize = C.CLASSIC_DEFAULT_BORDER_SIZE,
                    smoothTransitions = true,
                    transitionShadow = true,
                    font = NQOL.Util.GetDefaultFont(),
                    fontSize = C.CLASSIC_DEFAULT_FONT_SIZE,
                    flyingPositiveAnimation = true,
                    flyingNegativeAnimation = true,
                    flyingAnimationFont = NQOL.Util.GetDefaultFont(),
                    flyingAnimationFontSize = C.CLASSIC_DEFAULT_FLYING_FONT_SIZE,
                    shadow = Shadow.TOP,
                    shadowIntensity = Shadow.INTENSITY_DEFAULT,
                },
                radial = {
                    barColors = DefaultPlayerBarColors(),
                    horizontalPosition = 11,
                    verticalPosition = 50,
                    scale = 100,
                    borderSize = 2,
                    smoothTransitions = true,
                    transitionShadow = true,
                    font = "EsoUI/Common/Fonts/FTN87.slug",
                    fontSize = C.CLASSIC_DEFAULT_FONT_SIZE,
                    currentValue = C.CURRENT_VALUE.NUMBER,
                    flyingPositiveAnimation = true,
                    flyingNegativeAnimation = true,
                    flyingAnimationFont = NQOL.Util.GetDefaultFont(),
                    flyingAnimationFontSize = C.CLASSIC_DEFAULT_FLYING_FONT_SIZE,
                    shadow = Shadow.NONE,
                    shadowIntensity = Shadow.INTENSITY_DEFAULT,
                    healthSide = C.FLYING_ORIENTATION_LEFT,
                    magickaSide = C.FLYING_ORIENTATION_LEFT,
                    staminaSide = C.FLYING_ORIENTATION_LEFT,
                    stack = C.RADIAL_STACK_MAGICKA_STAMINA,
                    stackType = C.RADIAL_STACK_TYPE_RELATIVE,
                    stackPosition = C.FLYING_ORIENTATION_LEFT,
                },
            },
            companionFrame = {
                showNqolCompanionFrame = false,
                showOnlyInCombat = false,
                healthColor = { r = C.RESOURCE_COLORS[C.RESOURCE_HEALTH][1], g = C.RESOURCE_COLORS[C.RESOURCE_HEALTH][2], b = C.RESOURCE_COLORS[C.RESOURCE_HEALTH][3], a = C.RESOURCE_COLORS[C.RESOURCE_HEALTH][4] },
                xpColor = DefaultCompanionXpColor(),
                showInSettings = true,
                orientation = COMPANION.HORIZONTAL,
                horizontalPosition = 50,
                verticalPosition = 72,
                width = COMPANION.DEFAULT_WIDTH,
                height = COMPANION.DEFAULT_HEIGHT,
                borderSize = C.CLASSIC_DEFAULT_BORDER_SIZE,
                font = NQOL.Util.GetDefaultFont(),
                fontSize = C.CLASSIC_DEFAULT_FONT_SIZE,
                showName = true,
                showRapport = false,
                showXpProgress = false,
                currentValue = C.CURRENT_VALUE.NUMBER,
                smoothTransitions = true,
                transitionShadow = true,
                reverse = false,
                shadow = Shadow.TOP,
                shadowIntensity = 25,
            },
            groupFrame = {
                showNqolGroupFrame = false,
                showOnlyInCombat = false,
                showCustomNames = false,
                showInSettings = true,
                showShield = false,
                showTrauma = false,
                showNoHealing = false,
                horizontalPosition = 8,
                verticalPosition = 36,
                width = PlayerBars.Group.DEFAULT_WIDTH,
                height = PlayerBars.Group.DEFAULT_HEIGHT,
                rowGap = PlayerBars.Group.DEFAULT_ROW_GAP,
                columnGap = PlayerBars.Group.DEFAULT_COLUMN_GAP,
                columns = PlayerBars.Group.DEFAULT_COLUMNS,
                borderSize = C.CLASSIC_DEFAULT_BORDER_SIZE,
                font = NQOL.Util.GetDefaultFont(),
                fontSize = C.CLASSIC_DEFAULT_FONT_SIZE,
                nameDisplay = PlayerBars.Group.NAME_DISPLAY_CHARACTER,
                showClass = true,
                showTargetMarker = false,
                showChampionPoints = true,
                championPointsPlacement = PlayerBars.Group.CHAMPION_POINTS_BEFORE,
                showCompanions = false,
                showLeader = true,
                showDeathCounter = true,
                showResurrectingColor = true,
                dimAwayOpacity = PlayerBars.Group.AWAY_OPACITY_DEFAULT,
                currentValue = C.CURRENT_VALUE.NUMBER,
                smoothTransitions = true,
                transitionShadow = true,
                reverse = false,
                shadow = Shadow.TOP,
                shadowIntensity = 25,
                shieldColor = { r = C.PLAYER_SHIELD_COLOR[1], g = C.PLAYER_SHIELD_COLOR[2], b = C.PLAYER_SHIELD_COLOR[3], a = C.PLAYER_SHIELD_COLOR[4] },
                traumaColor = { r = 0.42, g = 0.76, b = 0.82, a = 0.82 },
                resurrectingColor = { r = 0.1, g = 0.9, b = 0.8, a = 1 },
                roleColors = {
                    dps = { r = 0, g = 0.5, b = 1, a = 1 },
                    tank = { r = 1, g = 0, b = 0, a = 1 },
                    heal = { r = 1, g = 1, b = 0, a = 1 },
                },
            },
        },
    },
}



local Clamp = NQOL.Util.Clamp
local Round = NQOL.Util.Round

function PlayerBars.Group.IsArgbHex(value)
    return type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x$") ~= nil
end

function PlayerBars.Group.HexToColorTable(value, fallback)
    if not PlayerBars.Group.IsArgbHex(value) then
        value = fallback or "FFFFFFFF"
    end

    return {
        r = (tonumber(value:sub(3, 4), 16) or 255) / 255,
        g = (tonumber(value:sub(5, 6), 16) or 255) / 255,
        b = (tonumber(value:sub(7, 8), 16) or 255) / 255,
        a = (tonumber(value:sub(1, 2), 16) or 255) / 255,
    }
end

function PlayerBars.Group.IsColorTable(value)
    return type(value) == "table" and type(value.r) == "number" and type(value.g) == "number" and type(value.b) == "number"
end

function PlayerBars.Group.CopyColorTable(value)
    return {
        r = Clamp(tonumber(value.r) or 1, 0, 1),
        g = Clamp(tonumber(value.g) or 1, 0, 1),
        b = Clamp(tonumber(value.b) or 1, 0, 1),
        a = Clamp(tonumber(value.a) or 1, 0, 1),
    }
end

function PlayerBars.Group.EnsureColor(settings, defaults, key)
    local value = settings[key]
    if PlayerBars.Group.IsColorTable(value) then
        settings[key] = PlayerBars.Group.CopyColorTable(value)
    elseif PlayerBars.Group.IsArgbHex(value) then
        settings[key] = PlayerBars.Group.HexToColorTable(value)
    elseif PlayerBars.Group.IsColorTable(defaults[key]) then
        settings[key] = PlayerBars.Group.CopyColorTable(defaults[key])
    else
        settings[key] = PlayerBars.Group.HexToColorTable(defaults[key])
    end
end

local savedVariables
local playerSettings
local initialized = false
local sceneCallbackInstalled = false
local settingsPanelVisible = false
local refreshQueued = false
local mounted = false
local activePresetKey
local presets = {}
local resourceValues = {}
local healthVisuals = {
    shield = 0,
    trauma = 0,
    noHealing = 0,
}
PlayerBars.EMPTY_HEALTH_VISUALS = {
    shield = 0,
    showShield = false,
    trauma = 0,
    noHealing = 0,
}
local classicFontString
local classicFontKey
local classicChangeFontString
local classicChangeFontKey
local pyramidFontString
local pyramidFontKey
local pyramidChangeFontString
local pyramidChangeFontKey
local stackFontString
local stackFontKey
local stackChangeFontString
local stackChangeFontKey
local verticalFontString
local verticalFontKey
local verticalChangeFontString
local verticalChangeFontKey
local radialChangeFontString
local radialChangeFontKey
local companionFontString
local companionFontKey

local function EnsurePlayerBarColors(settings, presetDefaults)
    local barColors = NQOL.Settings.EnsureTable(settings, "barColors")
    local barColorDefaults = presetDefaults.barColors
    PlayerBars.Group.EnsureColor(barColors, barColorDefaults, "health")
    PlayerBars.Group.EnsureColor(barColors, barColorDefaults, "magicka")
    PlayerBars.Group.EnsureColor(barColors, barColorDefaults, "stamina")
    PlayerBars.Group.EnsureColor(barColors, barColorDefaults, "trauma")
    PlayerBars.Group.EnsureColor(barColors, barColorDefaults, "shield")
end

local function EnsurePyramidSettings(frameSettings, frameDefaults)
    local settings = NQOL.Settings.EnsurePath(frameSettings, { C.PYRAMID })
    local presetDefaults = frameDefaults.pyramid
    EnsurePlayerBarColors(settings, presetDefaults)
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "verticalPosition", 0, 100)
    settings.boxHeight = nil
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "healthHeight", 10, 80, true)
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "resourceHeight", 10, 80, true)
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "healthWidth", 80, 600, true)
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "magickaWidth", 80, 600, true)
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "staminaWidth", 80, 600, true)
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "borderSize", C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX, true)
    settings.barIntensity = nil
    settings.barOpacity = nil
    NQOL.Settings.Boolean(settings, presetDefaults, "smoothTransitions")
    NQOL.Settings.Boolean(settings, presetDefaults, "transitionShadow")
    if not NQOL.Util.IsFontChoice(settings.font) then
        settings.font = presetDefaults.font
    end
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "fontSize", C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(settings, presetDefaults, "currentValue", C.CURRENT_VALUE.VALID_CHOICES)
    NQOL.Settings.Boolean(settings, presetDefaults, "flyingPositiveAnimation")
    NQOL.Settings.Boolean(settings, presetDefaults, "flyingNegativeAnimation")
    if not NQOL.Util.IsFontChoice(settings.flyingAnimationFont) then
        settings.flyingAnimationFont = presetDefaults.flyingAnimationFont
    end
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "flyingAnimationFontSize", C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(settings, presetDefaults, "shadow", Shadow.VALID)
    NQOL.Settings.ClampedNumber(settings, presetDefaults, "shadowIntensity", Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX, true)
end

local function EnsureStackSettings(frameSettings, frameDefaults)
    local settings = NQOL.Settings.EnsurePath(frameSettings, { C.STACK })
    local stackDefaults = frameDefaults.stack
    EnsurePlayerBarColors(settings, stackDefaults)
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "verticalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "healthHeight", 10, 80, true)
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "magickaHeight", 10, 80, true)
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "staminaHeight", 10, 80, true)
    settings.boxHeight = nil
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "width", 80, 600, true)
    settings.healthWidth = nil
    settings.magickaWidth = nil
    settings.staminaWidth = nil
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "borderSize", C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX, true)
    settings.barIntensity = nil
    settings.barOpacity = nil
    NQOL.Settings.Boolean(settings, stackDefaults, "smoothTransitions")
    NQOL.Settings.Boolean(settings, stackDefaults, "transitionShadow")
    if not NQOL.Util.IsFontChoice(settings.font) then
        settings.font = stackDefaults.font
    end
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "fontSize", C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(settings, stackDefaults, "currentValue", C.CURRENT_VALUE.VALID_CHOICES)
    NQOL.Settings.Boolean(settings, stackDefaults, "reverse")
    NQOL.Settings.Boolean(settings, stackDefaults, "flyingPositiveAnimation")
    NQOL.Settings.Boolean(settings, stackDefaults, "flyingNegativeAnimation")
    NQOL.Settings.Choice(settings, stackDefaults, "flyingOrientation", {
        [C.FLYING_ORIENTATION_LEFT] = true,
        [C.FLYING_ORIENTATION_RIGHT] = true,
    })
    if not NQOL.Util.IsFontChoice(settings.flyingAnimationFont) then
        settings.flyingAnimationFont = stackDefaults.flyingAnimationFont
    end
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "flyingAnimationFontSize", C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(settings, stackDefaults, "shadow", Shadow.VALID)
    NQOL.Settings.ClampedNumber(settings, stackDefaults, "shadowIntensity", Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX, true)
end

local function EnsureVerticalSettings(frameSettings, frameDefaults)
    local settings = NQOL.Settings.EnsurePath(frameSettings, { C.VERTICAL })
    local verticalDefaults = frameDefaults.vertical
    EnsurePlayerBarColors(settings, verticalDefaults)
    settings.horizontalPosition = nil
    settings.verticalPosition = nil
    settings.healthX = nil
    settings.healthY = nil
    settings.magickaX = nil
    settings.magickaY = nil
    settings.staminaX = nil
    settings.staminaY = nil
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "healthWidth", 10, 160, true)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "healthHeight", 40, 400, true)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "healthHorizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "healthVerticalPosition", 0, 100)
    NQOL.Settings.Choice(settings, verticalDefaults, "healthFlyingOrientation", {
        [C.FLYING_ORIENTATION_LEFT] = true,
        [C.FLYING_ORIENTATION_RIGHT] = true,
    })
    NQOL.Settings.Boolean(settings, verticalDefaults, "healthReverse")
    NQOL.Settings.Choice(settings, verticalDefaults, "healthCurrentValue", C.CURRENT_VALUE.VALID_CHOICES)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "magickaWidth", 10, 160, true)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "magickaHeight", 40, 400, true)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "magickaHorizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "magickaVerticalPosition", 0, 100)
    NQOL.Settings.Choice(settings, verticalDefaults, "magickaFlyingOrientation", {
        [C.FLYING_ORIENTATION_LEFT] = true,
        [C.FLYING_ORIENTATION_RIGHT] = true,
    })
    NQOL.Settings.Boolean(settings, verticalDefaults, "magickaReverse")
    NQOL.Settings.Choice(settings, verticalDefaults, "magickaCurrentValue", C.CURRENT_VALUE.VALID_CHOICES)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "staminaWidth", 10, 160, true)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "staminaHeight", 40, 400, true)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "staminaHorizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "staminaVerticalPosition", 0, 100)
    NQOL.Settings.Choice(settings, verticalDefaults, "staminaFlyingOrientation", {
        [C.FLYING_ORIENTATION_LEFT] = true,
        [C.FLYING_ORIENTATION_RIGHT] = true,
    })
    NQOL.Settings.Boolean(settings, verticalDefaults, "staminaReverse")
    NQOL.Settings.Choice(settings, verticalDefaults, "staminaCurrentValue", C.CURRENT_VALUE.VALID_CHOICES)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "borderSize", C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX, true)
    settings.barIntensity = nil
    settings.barOpacity = nil
    NQOL.Settings.Boolean(settings, verticalDefaults, "smoothTransitions")
    NQOL.Settings.Boolean(settings, verticalDefaults, "transitionShadow")
    if not NQOL.Util.IsFontChoice(settings.font) then
        settings.font = verticalDefaults.font
    end
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "fontSize", C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX, true)
    NQOL.Settings.Boolean(settings, verticalDefaults, "flyingPositiveAnimation")
    NQOL.Settings.Boolean(settings, verticalDefaults, "flyingNegativeAnimation")
    if not NQOL.Util.IsFontChoice(settings.flyingAnimationFont) then
        settings.flyingAnimationFont = verticalDefaults.flyingAnimationFont
    end
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "flyingAnimationFontSize", C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(settings, verticalDefaults, "shadow", Shadow.VALID)
    NQOL.Settings.ClampedNumber(settings, verticalDefaults, "shadowIntensity", Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX, true)
end

local function EnsureRadialSettings(frameSettings, frameDefaults)
    local settings = NQOL.Settings.EnsurePath(frameSettings, { C.RADIAL })
    EnsurePlayerBarColors(settings, frameDefaults.radial)
    local previousOrientation = settings.orientation
    if settings.horizontalPosition == nil then
        settings.horizontalPosition = previousOrientation == C.FLYING_ORIENTATION_RIGHT and 94 or frameDefaults.radial.horizontalPosition
    end
    if settings.healthSide == nil and previousOrientation ~= nil then
        settings.healthSide = previousOrientation == C.FLYING_ORIENTATION_RIGHT and C.FLYING_ORIENTATION_LEFT or C.FLYING_ORIENTATION_RIGHT
        settings.magickaSide = previousOrientation
        settings.staminaSide = previousOrientation
        settings.stackPosition = previousOrientation
    end
    settings.orientation = nil
    settings.separation = nil
    local validSides = {
        [C.FLYING_ORIENTATION_LEFT] = true,
        [C.FLYING_ORIENTATION_RIGHT] = true,
    }
    NQOL.Settings.ClampedNumber(settings, frameDefaults.radial, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, frameDefaults.radial, "verticalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, frameDefaults.radial, "scale", C.RADIAL_SCALE_MIN, C.RADIAL_SCALE_MAX, true)
    NQOL.Settings.ClampedNumber(settings, frameDefaults.radial, "borderSize", C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX, true)
    settings.barIntensity = nil
    settings.barOpacity = nil
    NQOL.Settings.Boolean(settings, frameDefaults.radial, "smoothTransitions")
    NQOL.Settings.Boolean(settings, frameDefaults.radial, "transitionShadow")
    if not NQOL.Util.IsFontChoice(settings.font) then settings.font = frameDefaults.radial.font end
    NQOL.Settings.ClampedNumber(settings, frameDefaults.radial, "fontSize", C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(settings, frameDefaults.radial, "currentValue", C.CURRENT_VALUE.VALID_CHOICES)
    NQOL.Settings.Boolean(settings, frameDefaults.radial, "flyingPositiveAnimation")
    NQOL.Settings.Boolean(settings, frameDefaults.radial, "flyingNegativeAnimation")
    if not NQOL.Util.IsFontChoice(settings.flyingAnimationFont) then
        settings.flyingAnimationFont = frameDefaults.radial.flyingAnimationFont
    end
    NQOL.Settings.ClampedNumber(settings, frameDefaults.radial, "flyingAnimationFontSize", C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(settings, frameDefaults.radial, "shadow", Shadow.VALID)
    NQOL.Settings.ClampedNumber(settings, frameDefaults.radial, "shadowIntensity", Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX, true)
    NQOL.Settings.Choice(settings, frameDefaults.radial, "healthSide", validSides)
    NQOL.Settings.Choice(settings, frameDefaults.radial, "magickaSide", validSides)
    NQOL.Settings.Choice(settings, frameDefaults.radial, "staminaSide", validSides)
    NQOL.Settings.Choice(settings, frameDefaults.radial, "stack", C.RADIAL_STACK_VALID)
    NQOL.Settings.Choice(settings, frameDefaults.radial, "stackType", C.RADIAL_STACK_TYPE_VALID)
    NQOL.Settings.Choice(settings, frameDefaults.radial, "stackPosition", validSides)
end

local function GetSettings()
    if playerSettings then
        return playerSettings
    end

    local uiSettings = NQOL.Settings.GetSection(savedVariables, defaults, "ui")
    local frameSettings = NQOL.Settings.EnsurePath(uiSettings, { "customFrames", "playerFrame" })
    local frameDefaults = defaults.ui.customFrames.playerFrame

    NQOL.Settings.Boolean(frameSettings, frameDefaults, "showNqolPlayerFrame")
    NQOL.Settings.Boolean(frameSettings, frameDefaults, "showOnlyInCombat")
    NQOL.Settings.Choice(frameSettings, frameDefaults, "preset", C.VALID_PRESETS)
    NQOL.Settings.Boolean(frameSettings, frameDefaults, "showInSettings")
    NQOL.Settings.Boolean(frameSettings, frameDefaults, "showShield")
    NQOL.Settings.Boolean(frameSettings, frameDefaults, "showTrauma")
    NQOL.Settings.Boolean(frameSettings, frameDefaults, "showNoHealing")

    local classicSettings = NQOL.Settings.EnsurePath(frameSettings, { "classic" })
    local classicDefaults = frameDefaults.classic
    EnsurePlayerBarColors(classicSettings, classicDefaults)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "verticalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "boxHeight", 10, 80, true)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "separation", 0, 160, true)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "healthWidth", 80, 600, true)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "magickaWidth", 80, 600, true)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "staminaWidth", 80, 600, true)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "borderSize", C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX, true)
    classicSettings.barIntensity = nil
    classicSettings.barOpacity = nil
    NQOL.Settings.Boolean(classicSettings, classicDefaults, "smoothTransitions")
    NQOL.Settings.Boolean(classicSettings, classicDefaults, "transitionShadow")
    if not NQOL.Util.IsFontChoice(classicSettings.font) then
        classicSettings.font = classicDefaults.font
    end
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "fontSize", C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(classicSettings, classicDefaults, "currentValue", C.CURRENT_VALUE.VALID_CHOICES)
    NQOL.Settings.Boolean(classicSettings, classicDefaults, "flyingPositiveAnimation")
    NQOL.Settings.Boolean(classicSettings, classicDefaults, "flyingNegativeAnimation")
    if not NQOL.Util.IsFontChoice(classicSettings.flyingAnimationFont) then
        classicSettings.flyingAnimationFont = classicDefaults.flyingAnimationFont
    end
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "flyingAnimationFontSize", C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX, true)
    NQOL.Settings.Choice(classicSettings, classicDefaults, "shadow", Shadow.VALID)
    NQOL.Settings.ClampedNumber(classicSettings, classicDefaults, "shadowIntensity", Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX, true)

    EnsurePyramidSettings(frameSettings, frameDefaults)
    EnsureStackSettings(frameSettings, frameDefaults)
    EnsureVerticalSettings(frameSettings, frameDefaults)
    EnsureRadialSettings(frameSettings, frameDefaults)

    if savedVariables then
        playerSettings = frameSettings
    end
    return frameSettings
end

local function GetPlayerResourceColor(settings, resourceType)
    local colorKey = C.PLAYER_RESOURCE_COLOR_KEYS[resourceType]
    local color = colorKey and settings and settings.barColors and settings.barColors[colorKey] or nil
    if color then
        return color.r, color.g, color.b, color.a or 1
    end

    local fallback = C.RESOURCE_COLORS[resourceType]
    if fallback then
        return fallback[1], fallback[2], fallback[3], fallback[4]
    end

    return 1, 1, 1, 1
end

local function GetPlayerTraumaColor(settings)
    local color = settings and settings.barColors and settings.barColors.trauma or nil
    if color then
        return color.r, color.g, color.b, color.a or 1
    end

    return C.PLAYER_TRAUMA_COLOR[1], C.PLAYER_TRAUMA_COLOR[2], C.PLAYER_TRAUMA_COLOR[3], C.PLAYER_TRAUMA_COLOR[4]
end

local function GetPlayerShieldColor(settings)
    local color = settings and settings.barColors and settings.barColors.shield or nil
    if color then
        return color.r, color.g, color.b, color.a or 1
    end

    return C.PLAYER_SHIELD_COLOR[1], C.PLAYER_SHIELD_COLOR[2], C.PLAYER_SHIELD_COLOR[3], C.PLAYER_SHIELD_COLOR[4]
end

local function GetCompanionSettings()
    local uiSettings = NQOL.Settings.GetSection(savedVariables, defaults, "ui")
    local settings = NQOL.Settings.EnsurePath(uiSettings, { "customFrames", "companionFrame" })
    local companionDefaults = defaults.ui.customFrames.companionFrame

    NQOL.Settings.Boolean(settings, companionDefaults, "showNqolCompanionFrame")
    NQOL.Settings.Boolean(settings, companionDefaults, "showOnlyInCombat")
    PlayerBars.Group.EnsureColor(settings, companionDefaults, "healthColor")
    PlayerBars.Group.EnsureColor(settings, companionDefaults, "xpColor")
    NQOL.Settings.Boolean(settings, companionDefaults, "showInSettings")
    NQOL.Settings.Choice(settings, companionDefaults, "orientation", COMPANION.VALID_ORIENTATIONS)
    NQOL.Settings.ClampedNumber(settings, companionDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, companionDefaults, "verticalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, companionDefaults, "width", COMPANION.WIDTH_MIN, COMPANION.WIDTH_MAX, true)
    NQOL.Settings.ClampedNumber(settings, companionDefaults, "height", COMPANION.HEIGHT_MIN, COMPANION.HEIGHT_MAX, true)
    NQOL.Settings.ClampedNumber(settings, companionDefaults, "borderSize", C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX, true)
    if not NQOL.Util.IsFontChoice(settings.font) then
        settings.font = companionDefaults.font
    end
    NQOL.Settings.ClampedNumber(settings, companionDefaults, "fontSize", C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX, true)
    NQOL.Settings.Boolean(settings, companionDefaults, "showName")
    NQOL.Settings.Boolean(settings, companionDefaults, "showRapport")
    NQOL.Settings.Boolean(settings, companionDefaults, "showXpProgress")
    NQOL.Settings.Choice(settings, companionDefaults, "currentValue", C.CURRENT_VALUE.VALID_CHOICES)
    settings.barIntensity = nil
    settings.barOpacity = nil
    NQOL.Settings.Boolean(settings, companionDefaults, "smoothTransitions")
    NQOL.Settings.Boolean(settings, companionDefaults, "transitionShadow")
    NQOL.Settings.Boolean(settings, companionDefaults, "reverse")
    NQOL.Settings.Choice(settings, companionDefaults, "shadow", Shadow.VALID)
    NQOL.Settings.ClampedNumber(settings, companionDefaults, "shadowIntensity", Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX, true)

    return settings
end

function PlayerBars.Group.GetSettings()
    local uiSettings = NQOL.Settings.GetSection(savedVariables, defaults, "ui")
    local settings = NQOL.Settings.EnsurePath(uiSettings, { "customFrames", "groupFrame" })
    local groupDefaults = defaults.ui.customFrames.groupFrame

    NQOL.Settings.Boolean(settings, groupDefaults, "showNqolGroupFrame")
    NQOL.Settings.Boolean(settings, groupDefaults, "showOnlyInCombat")
    NQOL.Settings.Boolean(settings, groupDefaults, "showCustomNames")
    NQOL.Settings.Boolean(settings, groupDefaults, "showInSettings")
    NQOL.Settings.Boolean(settings, groupDefaults, "showShield")
    NQOL.Settings.Boolean(settings, groupDefaults, "showTrauma")
    NQOL.Settings.Boolean(settings, groupDefaults, "showNoHealing")
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "verticalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "width", PlayerBars.Group.WIDTH_MIN, PlayerBars.Group.WIDTH_MAX, true)
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "height", PlayerBars.Group.HEIGHT_MIN, PlayerBars.Group.HEIGHT_MAX, true)
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "rowGap", PlayerBars.Group.ROW_GAP_MIN, PlayerBars.Group.ROW_GAP_MAX, true)
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "columnGap", PlayerBars.Group.COLUMN_GAP_MIN, PlayerBars.Group.COLUMN_GAP_MAX, true)
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "columns", PlayerBars.Group.COLUMNS_MIN, PlayerBars.Group.COLUMNS_MAX, true)
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "borderSize", C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX, true)
    if not NQOL.Util.IsFontChoice(settings.font) then
        settings.font = groupDefaults.font
    end
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "fontSize", C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX, true)
    if not PlayerBars.Group.NAME_DISPLAY_VALID_CHOICES[settings.nameDisplay] then
        settings.nameDisplay = PlayerBars.Group.NAME_DISPLAY_CHARACTER
    end
    NQOL.Settings.Boolean(settings, groupDefaults, "showClass")
    NQOL.Settings.Boolean(settings, groupDefaults, "showTargetMarker")
    NQOL.Settings.Boolean(settings, groupDefaults, "showChampionPoints")
    NQOL.Settings.Choice(settings, groupDefaults, "championPointsPlacement", PlayerBars.Group.CHAMPION_POINTS_PLACEMENT_VALID_CHOICES)
    NQOL.Settings.Boolean(settings, groupDefaults, "showCompanions")
    NQOL.Settings.Boolean(settings, groupDefaults, "showLeader")
    NQOL.Settings.Boolean(settings, groupDefaults, "showDeathCounter")
    settings["show" .. "Resurrect" .. "Counter"] = nil
    NQOL.Settings.Boolean(settings, groupDefaults, "showResurrectingColor")
    if type(settings.dimAway) == "boolean" and settings.dimAwayOpacity == nil then
        settings.dimAwayOpacity = settings.dimAway and groupDefaults.dimAwayOpacity or 100
    end
    settings.dimAway = nil
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "dimAwayOpacity", 0, 100, true)
    settings.showName = nil
    NQOL.Settings.Choice(settings, groupDefaults, "currentValue", C.CURRENT_VALUE.VALID_CHOICES)
    settings.barOpacity = nil
    NQOL.Settings.Boolean(settings, groupDefaults, "smoothTransitions")
    NQOL.Settings.Boolean(settings, groupDefaults, "transitionShadow")
    NQOL.Settings.Boolean(settings, groupDefaults, "reverse")
    NQOL.Settings.Choice(settings, groupDefaults, "shadow", Shadow.VALID)
    NQOL.Settings.ClampedNumber(settings, groupDefaults, "shadowIntensity", Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX, true)

    local roleColors = NQOL.Settings.EnsureTable(settings, "roleColors")
    local roleColorDefaults = groupDefaults.roleColors
    PlayerBars.Group.EnsureColor(roleColors, roleColorDefaults, "dps")
    PlayerBars.Group.EnsureColor(roleColors, roleColorDefaults, "tank")
    PlayerBars.Group.EnsureColor(roleColors, roleColorDefaults, "heal")
    PlayerBars.Group.EnsureColor(settings, groupDefaults, "shieldColor")
    PlayerBars.Group.EnsureColor(settings, groupDefaults, "traumaColor")
    PlayerBars.Group.EnsureColor(settings, groupDefaults, "resurrectingColor")

    return settings
end

local function GetClassicSettings()
    return GetSettings().classic
end

local function GetPyramidSettings()
    return GetSettings().pyramid
end

local function GetStackSettings()
    return GetSettings().stack
end

local function GetVerticalSettings()
    return GetSettings().vertical
end

local function GetRadialSettings()
    return GetSettings().radial
end

local function GetScreenWidth()
    return GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth() or 1920
end

local function GetScreenHeight()
    return GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight() or 1080
end

local PREVIEW_DRAW_LEVEL_OFFSET = C.DRAW_LEVEL + 10
local previewDrawOrders = setmetatable({}, { __mode = "k" })

local function MoveAboveHud(control)
    if not control then
        return
    end

    if control.SetDrawLayer and DL_OVERLAY then
        control:SetDrawLayer(DL_OVERLAY)
    end

    if control.SetDrawTier and DT_HIGH then
        control:SetDrawTier(DT_HIGH)
    end

    if control.SetDrawLevel then
        control:SetDrawLevel(C.DRAW_LEVEL)
    end
end

function Shared.SetSettingsPreviewDrawOrder(control)
    if not control then
        return
    end

    local drawOrder = previewDrawOrders[control]
    if not drawOrder and control.GetDrawTier and control.GetDrawLayer and control.GetDrawLevel then
        drawOrder = {
            tier = control:GetDrawTier(),
            layer = control:GetDrawLayer(),
            level = control:GetDrawLevel(),
        }
        previewDrawOrders[control] = drawOrder
    end

    if drawOrder then
        if control.SetDrawTier and DT_LOW then
            control:SetDrawTier(DT_LOW)
        end
        if control.SetDrawLayer and DL_BACKGROUND then
            control:SetDrawLayer(DL_BACKGROUND)
        end
        if control.SetDrawLevel then
            control:SetDrawLevel((tonumber(drawOrder.level) or C.DRAW_LEVEL) - PREVIEW_DRAW_LEVEL_OFFSET)
        end
    end

    if control.GetNumChildren and control.GetChild then
        for index = 1, control:GetNumChildren() do
            Shared.SetSettingsPreviewDrawOrder(control:GetChild(index))
        end
    end
end

function Shared.RestoreDrawOrder(control)
    if not control then
        return
    end

    local drawOrder = previewDrawOrders[control]
    if drawOrder then
        if control.SetDrawTier then
            control:SetDrawTier(drawOrder.tier)
        end
        if control.SetDrawLayer then
            control:SetDrawLayer(drawOrder.layer)
        end
        if control.SetDrawLevel then
            control:SetDrawLevel(drawOrder.level)
        end
        previewDrawOrders[control] = nil
    end

    if control.GetNumChildren and control.GetChild then
        for index = 1, control:GetNumChildren() do
            Shared.RestoreDrawOrder(control:GetChild(index))
        end
    end
end

function Shadow.CreateStrips(widget)
    if not widget or not WINDOW_MANAGER then
        return
    end

    local strips = {}
    for index = 1, Shadow.STRIPS do
        local strip = WINDOW_MANAGER:CreateControl(nil, widget, CT_BACKDROP)
        strip:SetCenterColor(0, 0, 0, 0)
        strip:SetEdgeColor(0, 0, 0, 0)
        strip:SetEdgeTexture(C.TEXTURE_WHITE, 1, 1, 1)
        strip:SetHidden(true)
        MoveAboveHud(strip)
        strip:SetDrawLevel(C.DRAW_LEVEL + 3)
        strips[index] = strip
    end

    widget.innerShadowStrips = strips
end

function Shadow.Layout(widget, width, height, borderSize, direction, intensity)
    local strips = widget and widget.innerShadowStrips
    if not strips then
        return
    end

    local count = #strips
    intensity = Clamp(tonumber(intensity) or Shadow.INTENSITY_DEFAULT, Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX) * 0.01

    if direction == Shadow.NONE or not Shadow.VALID[direction] or intensity <= 0 then
        for index = 1, count do
            strips[index]:SetHidden(true)
        end
        return
    end

    borderSize = Clamp(borderSize or 0, 0, math.max(0, zo_floor((math.min(width, height) - 1) * 0.5)))
    local innerWidth = math.max(width - borderSize * 2, 1)
    local innerHeight = math.max(height - borderSize * 2, 1)
    local horizontal = direction == Shadow.LEFT or direction == Shadow.RIGHT
    local span = horizontal and innerWidth or innerHeight
    local shadowSpan = math.max(zo_floor(span * Shadow.HEIGHT_RATIO), count)

    for index = 1, count do
        local strip = strips[index]
        local stripStart = zo_floor(shadowSpan * (index - 1) / count)
        local stripEnd = zo_floor(shadowSpan * index / count)
        local stripSpan = math.max(stripEnd - stripStart, 1)
        local alpha = intensity * (1 - (index - 1) / count)
        strip:SetCenterColor(0, 0, 0, alpha)
        strip:ClearAnchors()
        if direction == Shadow.TOP then
            strip:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize + stripStart)
            strip:SetDimensions(innerWidth, stripSpan)
        elseif direction == Shadow.BOTTOM then
            strip:SetAnchor(BOTTOMLEFT, widget, BOTTOMLEFT, borderSize, -borderSize - stripStart)
            strip:SetDimensions(innerWidth, stripSpan)
        elseif direction == Shadow.LEFT then
            strip:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize + stripStart, borderSize)
            strip:SetDimensions(stripSpan, innerHeight)
        else
            strip:SetAnchor(TOPRIGHT, widget, TOPRIGHT, -borderSize - stripStart, borderSize)
            strip:SetDimensions(stripSpan, innerHeight)
        end
        strip:SetHidden(false)
    end
end

local function FormatNumber(value)
    value = Round(tonumber(value) or 0)
    if zo_strformat and SI_NUMBER_FORMAT then
        return zo_strformat(SI_NUMBER_FORMAT, value)
    end

    return tostring(value)
end

local function FormatCompactNumber(value)
    value = tonumber(value) or 0
    local sign = value < 0 and "-" or ""
    local absoluteValue = math.abs(value)

    if absoluteValue >= 1000 then
        return string.format("%s%.1fk", sign, absoluteValue / 1000)
    end

    return sign .. tostring(Round(absoluteValue))
end

local function FormatCurrentValue(resourceValue, rangeMaximum, mode, compact)
    if mode == C.CURRENT_VALUE.PERCENTAGE then
        local maximum = tonumber(rangeMaximum) or 0
        if maximum < 1 then
            maximum = 1
        end

        return tostring(Round(Clamp((resourceValue.current or 0) / maximum, 0, 1) * 100)) .. "%"
    end

    if compact then
        return FormatCompactNumber(resourceValue.current)
    end

    return FormatNumber(resourceValue.current)
end

local function GetClassicLabelFont()
    local settings = GetClassicSettings()
    local key = tostring(settings.font) .. ":" .. tostring(settings.fontSize)
    if classicFontString and classicFontKey == key then
        return classicFontString
    end

    classicFontKey = key
    classicFontString = NQOL.Util.CreateFontString(settings.font, settings.fontSize, "ZoFontGamepad18")
    return classicFontString
end

local function GetPyramidLabelFont()
    local settings = GetPyramidSettings()
    local key = tostring(settings.font) .. ":" .. tostring(settings.fontSize)
    if pyramidFontString and pyramidFontKey == key then
        return pyramidFontString
    end

    pyramidFontKey = key
    pyramidFontString = NQOL.Util.CreateFontString(settings.font, settings.fontSize, "ZoFontGamepad18")
    return pyramidFontString
end

local function GetStackLabelFont()
    local settings = GetStackSettings()
    local key = tostring(settings.font) .. ":" .. tostring(settings.fontSize)
    if stackFontString and stackFontKey == key then
        return stackFontString
    end

    stackFontKey = key
    stackFontString = NQOL.Util.CreateFontString(settings.font, settings.fontSize, "ZoFontGamepad18")
    return stackFontString
end

local function GetVerticalLabelFont()
    local settings = GetVerticalSettings()
    local key = tostring(settings.font) .. ":" .. tostring(settings.fontSize)
    if verticalFontString and verticalFontKey == key then
        return verticalFontString
    end

    verticalFontKey = key
    verticalFontString = NQOL.Util.CreateFontString(settings.font, settings.fontSize, "ZoFontGamepad18")
    return verticalFontString
end

local function GetGroupLabelFont()
    local settings = PlayerBars.Group.GetSettings()
    local key = tostring(settings.font) .. ":" .. tostring(settings.fontSize)
    if PlayerBars.Group.fontString and PlayerBars.Group.fontKey == key then
        return PlayerBars.Group.fontString
    end

    PlayerBars.Group.fontKey = key
    PlayerBars.Group.fontString = NQOL.Util.CreateFontString(settings.font, settings.fontSize, "ZoFontGamepad18")
    return PlayerBars.Group.fontString
end

local function GetCompanionLabelFont()
    local settings = GetCompanionSettings()
    local key = tostring(settings.font) .. ":" .. tostring(settings.fontSize)
    if companionFontString and companionFontKey == key then
        return companionFontString
    end

    companionFontKey = key
    companionFontString = NQOL.Util.CreateFontString(settings.font, settings.fontSize, "ZoFontGamepad18")
    return companionFontString
end

local function GetChangeFont(settings, cacheName)
    local fontSize = Clamp(tonumber(settings.flyingAnimationFontSize) or C.CLASSIC_DEFAULT_FLYING_FONT_SIZE, C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX)
    local key = tostring(settings.flyingAnimationFont) .. ":change:" .. tostring(fontSize)
    if cacheName == C.PYRAMID and pyramidChangeFontString and pyramidChangeFontKey == key then
        return pyramidChangeFontString
    end

    if cacheName == C.STACK and stackChangeFontString and stackChangeFontKey == key then
        return stackChangeFontString
    end

    if cacheName == C.VERTICAL and verticalChangeFontString and verticalChangeFontKey == key then
        return verticalChangeFontString
    end

    if cacheName == C.RADIAL and radialChangeFontString and radialChangeFontKey == key then
        return radialChangeFontString
    end

    if cacheName ~= C.PYRAMID and cacheName ~= C.STACK and cacheName ~= C.VERTICAL and cacheName ~= C.RADIAL and classicChangeFontString and classicChangeFontKey == key then
        return classicChangeFontString
    end

    local fontString = NQOL.Util.CreateFontString(settings.flyingAnimationFont, fontSize, "ZoFontGamepad34")
    if cacheName == C.PYRAMID then
        pyramidChangeFontKey = key
        pyramidChangeFontString = fontString
        return pyramidChangeFontString
    end

    if cacheName == C.STACK then
        stackChangeFontKey = key
        stackChangeFontString = fontString
        return stackChangeFontString
    end

    if cacheName == C.VERTICAL then
        verticalChangeFontKey = key
        verticalChangeFontString = fontString
        return verticalChangeFontString
    end

    if cacheName == C.RADIAL then
        radialChangeFontKey = key
        radialChangeFontString = fontString
        return radialChangeFontString
    end

    classicChangeFontKey = key
    classicChangeFontString = fontString
    return classicChangeFontString
end

local function GetClassicChangeFont()
    return GetChangeFont(GetClassicSettings(), C.CLASSIC)
end

local function GetPyramidChangeFont()
    return GetChangeFont(GetPyramidSettings(), C.PYRAMID)
end

local function GetStackChangeFont()
    return GetChangeFont(GetStackSettings(), C.STACK)
end

local function GetVerticalChangeFont()
    return GetChangeFont(GetVerticalSettings(), C.VERTICAL)
end

local function GetRadialChangeFont()
    return GetChangeFont(GetRadialSettings(), C.RADIAL)
end

local function CreateClassicLabel(parent, horizontalAlignment)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(GetClassicLabelFont())
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(horizontalAlignment)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetDrawLevel(C.DRAW_LEVEL + 2)
    return label
end

local function CreateClassicChangeLabel(parent)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetAnchor(CENTER, parent, CENTER, 0, 0)
    label:SetFont(GetClassicChangeFont())
    label:SetColor(0.96, 0.94, 0.78, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLevel(C.DRAW_LEVEL + 3)
    label:SetAlpha(0)
    label:SetHidden(true)
    return label
end

local function CreateCompanionNameLabel(parent, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font or NQOL.Util.CreateFontString(NQOL.Util.GetDefaultFont(), C.CLASSIC_DEFAULT_FONT_SIZE, "ZoFontGamepad18"))
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetDrawLevel(C.DRAW_LEVEL + 2)
    MoveAboveHud(label)
    return label
end

local ApplyRootPosition

local function CreateRootControl(controlName)
    local control = WINDOW_MANAGER:CreateTopLevelWindow(controlName)
    control:SetParent(GuiRoot)
    control:SetClampedToScreen(true)
    control:SetMouseEnabled(false)
    control:SetHidden(true)
    MoveAboveHud(control)
    return control
end

local function StopFrameVisibilityTransition(root)
    local timeline = root and root.nqolVisibilityTimeline
    if not timeline then
        return
    end

    timeline:SetHandler("OnStop", nil)
    timeline:Stop()
    root.nqolVisibilityTimeline = nil
end

local function SetFrameVisibilityImmediate(root, visible)
    if not root then
        return
    end

    StopFrameVisibilityTransition(root)
    root.nqolVisibilityTarget = visible == true
    root:SetAlpha(1)
    root:SetHidden(visible ~= true)
end

local function SetFrameCombatVisibility(root, visible)
    if not root then
        return
    end

    visible = visible == true
    local currentTimeline = root.nqolVisibilityTimeline
    if root.nqolVisibilityTarget == visible and currentTimeline and currentTimeline:IsPlaying() then
        return
    end

    local wasHidden = root:IsHidden()
    local currentAlpha = wasHidden and 0 or root:GetAlpha()
    local targetAlpha = visible and 1 or 0
    if not ANIMATION_MANAGER or not ANIMATION_ALPHA then
        SetFrameVisibilityImmediate(root, visible)
        return
    end

    StopFrameVisibilityTransition(root)
    root.nqolVisibilityTarget = visible
    if visible then
        root:SetHidden(false)
        if wasHidden then
            root:SetAlpha(0)
        end
    elseif wasHidden then
        root:SetAlpha(1)
        return
    end

    if math.abs(currentAlpha - targetAlpha) < 0.001 then
        root:SetAlpha(targetAlpha)
        root:SetHidden(not visible)
        return
    end

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, root, 0)
    fade:SetAlphaValues(currentAlpha, targetAlpha)
    fade:SetDuration(math.max(1, C.FRAME_VISIBILITY_TRANSITION_MS * math.abs(targetAlpha - currentAlpha)))
    local easingFunction = visible and ZO_EaseOutQuadratic or ZO_EaseInQuadratic
    if easingFunction then
        fade:SetEasingFunction(easingFunction)
    end

    root.nqolVisibilityTimeline = timeline
    timeline:SetHandler("OnStop", function(stoppedTimeline, completedPlaying)
        if root.nqolVisibilityTimeline ~= stoppedTimeline then
            return
        end

        root.nqolVisibilityTimeline = nil
        if not completedPlaying then
            return
        end

        local targetVisible = root.nqolVisibilityTarget == true
        root:SetAlpha(targetVisible and 1 or 0)
        root:SetHidden(not targetVisible)
    end)
    timeline:PlayFromStart()
end

ApplyRootPosition = function(root, settings)
    if not settings then
        root:ClearAnchors()
        root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        return
    end

    local width = root:GetWidth()
    local height = root:GetHeight()
    local x = math.max(GetScreenWidth() - width, 0) * settings.horizontalPosition * 0.01 + (width * 0.5)
    local y = math.max(GetScreenHeight() - height, 0) * settings.verticalPosition * 0.01 + (height * 0.5)

    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y)
end

local function CreateResourceWidget(parent, resourceType)
    local widget = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    local color = C.RESOURCE_COLORS[resourceType]

    widget.track = WINDOW_MANAGER:CreateControl(nil, widget, CT_BACKDROP)
    widget.track:SetAnchorFill(widget)
    widget.track:SetCenterColor(0, 0, 0, 0.72)
    widget.track:SetEdgeColor(0, 0, 0, 0)
    widget.track:SetEdgeTexture(C.TEXTURE_WHITE, 1, 1, 1)
    widget.track:SetDrawLevel(C.DRAW_LEVEL)

    widget.status = WINDOW_MANAGER:CreateControl(nil, widget, CT_STATUSBAR)
    widget.status:SetAnchor(TOPLEFT, widget, TOPLEFT, C.BAR_INSET, C.BAR_INSET)
    widget.status:SetAnchor(BOTTOMRIGHT, widget, BOTTOMRIGHT, -C.BAR_INSET, -C.BAR_INSET)
    widget.status:SetTexture(C.TEXTURE_FILL)
    widget.status:SetColor(color[1], color[2], color[3], color[4])
    widget.status:SetMinMax(0, 1)
    widget.status:SetValue(1)

    MoveAboveHud(widget)
    MoveAboveHud(widget.track)
    MoveAboveHud(widget.status)
    widget.track:SetDrawLevel(C.DRAW_LEVEL)
    widget.status:SetDrawLevel(C.DRAW_LEVEL + 1)
    return widget
end

local function CreateFlatResourceWidgets(root)
    local widgets = {}
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        widgets[resourceType] = CreateResourceWidget(root, resourceType)
    end

    return widgets
end

local function CreateClassicResourceWidget(parent, resourceType)
    local widget = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    local color = C.RESOURCE_COLORS[resourceType]
    if widget.SetClipsChildren then
        widget:SetClipsChildren(true)
    end

    widget.track = WINDOW_MANAGER:CreateControl(nil, widget, CT_BACKDROP)
    widget.track:SetAnchorFill(widget)
    widget.track:SetCenterColor(0, 0, 0, 0.78)
    widget.track:SetEdgeColor(0, 0, 0, 0)
    widget.track:SetEdgeTexture(C.TEXTURE_WHITE, 1, 1, 1)

    widget.fill = WINDOW_MANAGER:CreateControl(nil, widget, CT_BACKDROP)
    widget.fill:SetAnchor(TOPLEFT, widget, TOPLEFT, C.CLASSIC_DEFAULT_BORDER_SIZE, C.CLASSIC_DEFAULT_BORDER_SIZE)
    widget.fill:SetDimensions(1, 1)
    widget.fill:SetCenterColor(color[1], color[2], color[3], color[4])
    widget.fill:SetEdgeColor(0, 0, 0, 0)
    widget.fill:SetEdgeTexture(C.TEXTURE_WHITE, 1, 1, 1)

    widget.loss = WINDOW_MANAGER:CreateControl(nil, widget, CT_BACKDROP)
    widget.loss:SetAnchor(TOPLEFT, widget, TOPLEFT, C.CLASSIC_DEFAULT_BORDER_SIZE, C.CLASSIC_DEFAULT_BORDER_SIZE)
    widget.loss:SetDimensions(1, 1)
    widget.loss:SetCenterColor(1, 1, 1, 0)
    widget.loss:SetEdgeColor(0, 0, 0, 0)
    widget.loss:SetEdgeTexture(C.TEXTURE_WHITE, 1, 1, 1)
    widget.loss:SetHidden(true)

    if resourceType == C.RESOURCE_HEALTH then
        widget.trauma = WINDOW_MANAGER:CreateControl(nil, widget, CT_BACKDROP)
        widget.trauma:SetDimensions(1, 1)
        widget.trauma:SetCenterColor(0.42, 0.76, 0.82, 0.82)
        widget.trauma:SetEdgeColor(0, 0, 0, 0)
        widget.trauma:SetEdgeTexture(C.TEXTURE_WHITE, 1, 1, 1)
        widget.trauma:SetHidden(true)

        widget.shield = WINDOW_MANAGER:CreateControl(nil, widget, CT_BACKDROP)
        widget.shield:SetDimensions(1, 1)
        widget.shield:SetCenterColor(C.PLAYER_SHIELD_COLOR[1], C.PLAYER_SHIELD_COLOR[2], C.PLAYER_SHIELD_COLOR[3], C.PLAYER_SHIELD_COLOR[4])
        widget.shield:SetEdgeColor(0, 0, 0, 0)
        widget.shield:SetEdgeTexture(C.TEXTURE_WHITE, 1, 1, 1)
        widget.shield:SetHidden(true)

        widget.noHealingFractureGlowTiles = {}
        widget.noHealingFractureTiles = {}
    end

    widget.leftLabel = CreateClassicLabel(widget, TEXT_ALIGN_LEFT)
    widget.leftLabel:SetAnchor(TOPLEFT, widget, TOPLEFT, C.CLASSIC_LABEL_PADDING, 0)
    widget.leftLabel:SetAnchor(BOTTOMRIGHT, widget, BOTTOMRIGHT, -C.CLASSIC_LABEL_PADDING, 0)

    widget.rightLabel = CreateClassicLabel(widget, TEXT_ALIGN_RIGHT)
    widget.rightLabel:SetAnchor(TOPLEFT, widget, TOPLEFT, C.CLASSIC_LABEL_PADDING, 0)
    widget.rightLabel:SetAnchor(BOTTOMRIGHT, widget, BOTTOMRIGHT, -C.CLASSIC_LABEL_PADDING, 0)

    if resourceType == C.RESOURCE_MOUNT_STAMINA or resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF or resourceType == PlayerBars.SIEGE_HEALTH then
        widget.icon = WINDOW_MANAGER:CreateControl(nil, widget, CT_TEXTURE)
        if resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF then
            widget.icon:SetTexture(GetAbilityIcon and GetAbilityIcon(32455) or "EsoUI/Art/Icons/ability_werewolf_001.dds")
        elseif resourceType == PlayerBars.SIEGE_HEALTH then
            widget.icon:SetTexture("EsoUI/Art/MapPins/AvA_siegeWeaponry.dds")
        else
            widget.icon:SetTexture("EsoUI/Art/Collections/Default/collections_default_mount.dds")
        end
        widget.icon:SetColor(1, 1, 1, 0.92)
        widget.icon:SetDimensions(16, 16)
        widget.icon:SetDrawLevel(C.DRAW_LEVEL + 2)
    end

    widget.changeLabels = {}
    widget.nextChangeLabelIndex = 1
    for index = 1, C.CLASSIC_CHANGE_POOL_SIZE do
        widget.changeLabels[index] = CreateClassicChangeLabel(widget)
    end

    MoveAboveHud(widget)
    MoveAboveHud(widget.track)
    MoveAboveHud(widget.loss)
    MoveAboveHud(widget.fill)
    if widget.trauma then
        MoveAboveHud(widget.trauma)
    end
    if widget.shield then
        MoveAboveHud(widget.shield)
    end
    MoveAboveHud(widget.leftLabel)
    MoveAboveHud(widget.rightLabel)
    if widget.icon then
        MoveAboveHud(widget.icon)
        widget.icon:SetDrawLevel(C.DRAW_LEVEL + 2)
    end
    for _, changeLabel in ipairs(widget.changeLabels) do
        MoveAboveHud(changeLabel)
        changeLabel:SetDrawLevel(C.DRAW_LEVEL + 5)
    end
    widget.track:SetDrawLevel(C.DRAW_LEVEL)
    widget.loss:SetDrawLevel(C.DRAW_LEVEL + 1)
    widget.fill:SetDrawLevel(C.DRAW_LEVEL + 2)
    if widget.trauma then
        widget.trauma:SetDrawLevel(C.DRAW_LEVEL + 3)
    end
    if widget.shield then
        widget.shield:SetDrawLevel(C.DRAW_LEVEL + 3)
    end
    widget.leftLabel:SetDrawLevel(C.DRAW_LEVEL + 5)
    widget.rightLabel:SetDrawLevel(C.DRAW_LEVEL + 5)
    Shadow.CreateStrips(widget)
    return widget
end

local function CreateClassicResourceWidgets(root)
    local widgets = {}
    for _, resourceType in ipairs(C.RESOURCE_KEYS) do
        widgets[resourceType] = CreateClassicResourceWidget(root, resourceType)
    end

    return widgets
end

local function CreateClassicControls(root)
    return {
        widgets = CreateClassicResourceWidgets(root),
    }
end

local function ApplyClassicLabelFont(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local font = GetClassicLabelFont()
    for _, widget in pairs(widgets) do
        if widget.leftLabel then
            widget.leftLabel:SetFont(font)
        end

        if widget.rightLabel then
            widget.rightLabel:SetFont(font)
        end
    end
end

local function ApplyPyramidLabelFont(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local font = GetPyramidLabelFont()
    for _, widget in pairs(widgets) do
        if widget.leftLabel then
            widget.leftLabel:SetFont(font)
        end

        if widget.rightLabel then
            widget.rightLabel:SetFont(font)
        end
    end
end

local function ApplyStackLabelFont(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local font = GetStackLabelFont()
    for _, widget in pairs(widgets) do
        if widget.leftLabel then
            widget.leftLabel:SetFont(font)
        end

        if widget.rightLabel then
            widget.rightLabel:SetFont(font)
        end
    end
end

local function ApplyVerticalLabelFont(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local font = GetVerticalLabelFont()
    for _, widget in pairs(widgets) do
        if widget.leftLabel then
            widget.leftLabel:SetFont(font)
        end

        if widget.rightLabel then
            widget.rightLabel:SetFont(font)
        end
    end
end

local function ApplyChangeFont(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local font = GetClassicChangeFont()
    if preset.key == C.PYRAMID then
        font = GetPyramidChangeFont()
    elseif preset.key == C.STACK then
        font = GetStackChangeFont()
    elseif preset.key == C.VERTICAL then
        font = GetVerticalChangeFont()
    elseif preset.key == C.RADIAL then
        font = GetRadialChangeFont()
    end

    for _, widget in pairs(widgets) do
        if widget.changeLabels then
            for _, changeLabel in ipairs(widget.changeLabels) do
                changeLabel:SetFont(font)
            end
        end
    end
end

local function ApplyClassicBorder(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local borderSize = GetClassicSettings().borderSize
    for _, widget in pairs(widgets) do
        if widget.fill then
            widget.fill:ClearAnchors()
            widget.fill:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
        end
    end
end

local function ApplyPyramidBorder(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local borderSize = GetPyramidSettings().borderSize
    for _, widget in pairs(widgets) do
        if widget.fill then
            widget.fill:ClearAnchors()
            widget.fill:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
        end
    end
end

local function ApplyStackBorder(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local borderSize = GetStackSettings().borderSize
    for _, widget in pairs(widgets) do
        if widget.fill then
            widget.fill:ClearAnchors()
            widget.fill:SetAnchor(TOPLEFT, widget, TOPLEFT, borderSize, borderSize)
        end
    end
end

local function ApplyVerticalBorder(preset)
    local widgets = preset.controls and preset.controls.widgets
    if not widgets then
        return
    end

    local borderSize = GetVerticalSettings().borderSize
    for _, widget in pairs(widgets) do
        if widget.fill then
            widget.fill:ClearAnchors()
            widget.fill:SetAnchor(BOTTOMLEFT, widget, BOTTOMLEFT, borderSize, -borderSize)
        end
    end
end

local function HideClassicChangeLabel(changeLabel)
    if not changeLabel then
        return
    end

    changeLabel:SetAlpha(0)
    changeLabel:SetHidden(true)
end

local function HideClassicChangeLabels(widget)
    if not widget or not widget.changeLabels then
        return
    end

    for _, changeLabel in ipairs(widget.changeLabels) do
        if changeLabel.changeTimeline then
            changeLabel.changeTimeline:Stop()
        end
        HideClassicChangeLabel(changeLabel)
    end
end

local function AcquireClassicChangeLabel(widget)
    if not widget or not widget.changeLabels then
        return nil, nil
    end

    local index = widget.nextChangeLabelIndex or 1
    local label = widget.changeLabels[index]
    widget.nextChangeLabelIndex = index + 1
    if widget.nextChangeLabelIndex > C.CLASSIC_CHANGE_POOL_SIZE then
        widget.nextChangeLabelIndex = 1
    end

    if label.changeTimeline then
        label.changeTimeline:Stop()
    end

    return label
end

local function EnsureClassicChangeTimeline(label)
    if label.changeTimeline then
        return label.changeTimeline, label.changeTranslate
    end

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local translate = timeline:InsertAnimation(ANIMATION_TRANSLATE, label, 0)
    translate:SetDuration(C.CLASSIC_CHANGE_ANIMATION_MS)
    if ZO_EaseOutCubic then
        translate:SetEasingFunction(ZO_EaseOutCubic)
    end

    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, label, C.CLASSIC_CHANGE_FADE_DELAY_MS)
    fade:SetDuration(C.CLASSIC_CHANGE_ANIMATION_MS - C.CLASSIC_CHANGE_FADE_DELAY_MS)
    fade:SetAlphaValues(1, 0)
    if ZO_EaseInQuadratic then
        fade:SetEasingFunction(ZO_EaseInQuadratic)
    end

    timeline:SetHandler("OnStop", function()
        HideClassicChangeLabel(label)
    end)

    label.changeTimeline = timeline
    label.changeTranslate = translate
    return timeline, translate
end

local function PlayChangeNumber(widget, amount, settings, direction)
    if not widget or amount == 0 then
        return
    end

    local isGain = amount > 0
    if (isGain and not settings.flyingPositiveAnimation) or (not isGain and not settings.flyingNegativeAnimation) then
        return
    end

    local label = AcquireClassicChangeLabel(widget)
    if not label then
        return
    end

    local absoluteAmount = math.abs(amount)
    if isGain then
        label:SetText("+" .. FormatNumber(absoluteAmount))
        label:SetColor(0.72, 1.00, 0.58, 1)
    else
        label:SetText(FormatNumber(absoluteAmount) .. "!")
        label:SetColor(0.96, 0.94, 0.78, 1)
    end

    local sideOffset = math.random(-C.CLASSIC_CHANGE_RANDOM_OFFSET, C.CLASSIC_CHANGE_RANDOM_OFFSET)
    local verticalOffset = math.random(-8, 8)
    label:ClearAnchors()
    if direction == "left" then
        label:SetAnchor(RIGHT, widget, LEFT, -C.CLASSIC_LABEL_PADDING, 0)
    elseif direction == "right" then
        label:SetAnchor(LEFT, widget, RIGHT, C.CLASSIC_LABEL_PADDING, 0)
    else
        label:SetAnchor(CENTER, widget, CENTER, 0, 0)
    end
    label:SetAlpha(1)
    label:SetHidden(false)

    if ANIMATION_MANAGER then
        local timeline, translate = EnsureClassicChangeTimeline(label)
        if direction == "left" then
            translate:SetTranslateOffsets(sideOffset, verticalOffset, sideOffset - C.CLASSIC_CHANGE_FLOAT_DISTANCE, verticalOffset)
        elseif direction == "right" then
            translate:SetTranslateOffsets(sideOffset, verticalOffset, sideOffset + C.CLASSIC_CHANGE_FLOAT_DISTANCE, verticalOffset)
        else
            local floatDistance = direction == "down" and C.CLASSIC_CHANGE_FLOAT_DISTANCE or -C.CLASSIC_CHANGE_FLOAT_DISTANCE
            translate:SetTranslateOffsets(sideOffset, verticalOffset, sideOffset, verticalOffset + floatDistance)
        end
        timeline:PlayFromStart()
    elseif zo_callLater then
        zo_callLater(function()
            HideClassicChangeLabel(label)
        end, C.CLASSIC_CHANGE_ANIMATION_MS)
    end
end

local function GetPresetSettings(preset)
    if preset and preset.key == C.PYRAMID then
        return GetPyramidSettings()
    end

    if preset and preset.key == C.STACK then
        return GetStackSettings()
    end

    if preset and preset.key == C.VERTICAL then
        return GetVerticalSettings()
    end

    if preset and preset.key == C.RADIAL and PlayerBars.Radial then
        return PlayerBars.Radial.GetAnimationSettings()
    end

    return GetClassicSettings()
end

local function GetVerticalFlyingOrientationForResource(resourceType, settings)
    settings = settings or GetVerticalSettings()
    if resourceType == C.RESOURCE_HEALTH then
        return settings.healthFlyingOrientation
    end

    if resourceType == C.RESOURCE_MAGICKA then
        return settings.magickaFlyingOrientation
    end

    if resourceType == C.RESOURCE_STAMINA then
        return settings.staminaFlyingOrientation
    end

    return C.FLYING_ORIENTATION_LEFT
end

local function GetVerticalReverseForResource(resourceType, settings)
    if resourceType == C.RESOURCE_HEALTH then
        return settings.healthReverse == true
    end

    if resourceType == C.RESOURCE_MAGICKA then
        return settings.magickaReverse == true
    end

    if resourceType == C.RESOURCE_STAMINA then
        return settings.staminaReverse == true
    end

    if resourceType == C.RESOURCE_MOUNT_STAMINA then
        return settings.staminaReverse == true
    end

    if resourceType == COMBAT_MECHANIC_FLAGS_WEREWOLF then
        return settings.magickaReverse == true
    end

    if resourceType == PlayerBars.SIEGE_HEALTH then
        return settings.healthReverse == true
    end

    return false
end

local function GetVerticalCurrentValueForResource(resourceType, settings)
    if resourceType == C.RESOURCE_HEALTH then
        return settings.healthCurrentValue
    end

    if resourceType == C.RESOURCE_MAGICKA then
        return settings.magickaCurrentValue
    end

    if resourceType == C.RESOURCE_STAMINA then
        return settings.staminaCurrentValue
    end

    return C.CURRENT_VALUE.NUMBER
end

local function GetChangeDirection(preset, resourceType, settings)
    if preset and preset.key == C.RADIAL and PlayerBars.Radial then
        return PlayerBars.Radial.GetChangeDirection(resourceType, settings)
    end

    if preset and preset.key == C.VERTICAL then
        return GetVerticalFlyingOrientationForResource(resourceType, settings)
    end

    if preset and preset.key == C.STACK then
        settings = settings or GetStackSettings()
        if settings.flyingOrientation == C.FLYING_ORIENTATION_RIGHT then
            return C.FLYING_ORIENTATION_RIGHT
        end

        return C.FLYING_ORIENTATION_LEFT
    end

    if preset and preset.key == C.PYRAMID and (resourceType == C.RESOURCE_MAGICKA or resourceType == C.RESOURCE_STAMINA) then
        return "down"
    end

    return "up"
end

local function CreatePyramidControls(root)
    return {
        widgets = CreateClassicResourceWidgets(root),
    }
end

local function CreateStackControls(root)
    return {
        widgets = CreateClassicResourceWidgets(root),
    }
end

local function CreateVerticalControls(root)
    return {
        widgets = CreateClassicResourceWidgets(root),
    }
end

local function GetCurrentSceneName()
    if not SCENE_MANAGER then
        return nil
    end

    if SCENE_MANAGER.GetCurrentSceneName then
        return SCENE_MANAGER:GetCurrentSceneName()
    end

    if SCENE_MANAGER.GetCurrentScene then
        local scene = SCENE_MANAGER:GetCurrentScene()
        if scene and scene.GetName then
            return scene:GetName()
        end
    end

    return nil
end

local function IsGameplaySceneShowing()
    if not SCENE_MANAGER then
        return true
    end

    return C.GAMEPLAY_SCENES[GetCurrentSceneName()] == true
end

local function ShouldShowForCurrentScene()
    if IsGameplaySceneShowing() then
        return true
    end

    return settingsPanelVisible and GetSettings().showInSettings == true
end

Shared.defaults = defaults
Shared.GetPlayerSettings = GetSettings
Shared.GetPlayerResourceColor = GetPlayerResourceColor
Shared.GetPlayerTraumaColor = GetPlayerTraumaColor
Shared.GetPlayerShieldColor = GetPlayerShieldColor
Shared.GetCompanionSettings = GetCompanionSettings
Shared.GetClassicSettings = GetClassicSettings
Shared.GetPyramidSettings = GetPyramidSettings
Shared.GetStackSettings = GetStackSettings
Shared.GetVerticalSettings = GetVerticalSettings
Shared.GetRadialSettings = GetRadialSettings
Shared.GetScreenWidth = GetScreenWidth
Shared.GetScreenHeight = GetScreenHeight
Shared.MoveAboveHud = MoveAboveHud
Shared.ApplyRootPosition = ApplyRootPosition
Shared.FormatNumber = FormatNumber
Shared.FormatCompactNumber = FormatCompactNumber
Shared.FormatCurrentValue = FormatCurrentValue
Shared.GetClassicLabelFont = GetClassicLabelFont
Shared.GetPyramidLabelFont = GetPyramidLabelFont
Shared.GetStackLabelFont = GetStackLabelFont
Shared.GetVerticalLabelFont = GetVerticalLabelFont
Shared.GetGroupLabelFont = GetGroupLabelFont
Shared.GetCompanionLabelFont = GetCompanionLabelFont
Shared.GetClassicChangeFont = GetClassicChangeFont
Shared.GetPyramidChangeFont = GetPyramidChangeFont
Shared.GetStackChangeFont = GetStackChangeFont
Shared.GetVerticalChangeFont = GetVerticalChangeFont
Shared.CreateClassicLabel = CreateClassicLabel
Shared.CreateClassicChangeLabel = CreateClassicChangeLabel
Shared.CreateCompanionNameLabel = CreateCompanionNameLabel
Shared.CreateRootControl = CreateRootControl
Shared.SetFrameVisibilityImmediate = SetFrameVisibilityImmediate
Shared.SetFrameCombatVisibility = SetFrameCombatVisibility
Shared.CreateResourceWidget = CreateResourceWidget
Shared.CreateFlatResourceWidgets = CreateFlatResourceWidgets
Shared.CreateClassicResourceWidget = CreateClassicResourceWidget
Shared.CreateClassicResourceWidgets = CreateClassicResourceWidgets
Shared.CreateClassicControls = CreateClassicControls
Shared.ApplyClassicLabelFont = ApplyClassicLabelFont
Shared.ApplyPyramidLabelFont = ApplyPyramidLabelFont
Shared.ApplyStackLabelFont = ApplyStackLabelFont
Shared.ApplyVerticalLabelFont = ApplyVerticalLabelFont
Shared.ApplyChangeFont = ApplyChangeFont
Shared.ApplyClassicBorder = ApplyClassicBorder
Shared.ApplyPyramidBorder = ApplyPyramidBorder
Shared.ApplyStackBorder = ApplyStackBorder
Shared.ApplyVerticalBorder = ApplyVerticalBorder
Shared.HideClassicChangeLabels = HideClassicChangeLabels
Shared.PlayChangeNumber = PlayChangeNumber
Shared.GetPresetSettings = GetPresetSettings
Shared.GetVerticalFlyingOrientationForResource = GetVerticalFlyingOrientationForResource
Shared.GetVerticalReverseForResource = GetVerticalReverseForResource
Shared.GetVerticalCurrentValueForResource = GetVerticalCurrentValueForResource
Shared.GetChangeDirection = GetChangeDirection
Shared.CreatePyramidControls = CreatePyramidControls
Shared.CreateStackControls = CreateStackControls
Shared.CreateVerticalControls = CreateVerticalControls
Shared.IsGameplaySceneShowing = IsGameplaySceneShowing

function Shared.ClearFontCache(name)
    if name == "classic" then
        classicFontString = nil
        classicFontKey = nil
    elseif name == "classicChange" then
        classicChangeFontString = nil
        classicChangeFontKey = nil
    elseif name == "pyramid" then
        pyramidFontString = nil
        pyramidFontKey = nil
    elseif name == "pyramidChange" then
        pyramidChangeFontString = nil
        pyramidChangeFontKey = nil
    elseif name == "stack" then
        stackFontString = nil
        stackFontKey = nil
    elseif name == "stackChange" then
        stackChangeFontString = nil
        stackChangeFontKey = nil
    elseif name == "vertical" then
        verticalFontString = nil
        verticalFontKey = nil
    elseif name == "verticalChange" then
        verticalChangeFontString = nil
        verticalChangeFontKey = nil
    elseif name == "radialChange" then
        radialChangeFontString = nil
        radialChangeFontKey = nil
    elseif name == "companion" then
        companionFontString = nil
        companionFontKey = nil
    end
end

function Shared.InitializeSavedVariables()
    playerSettings = nil
    savedVariables = NQOL.Settings.NewAccountWide(defaults)
    GetSettings()
    GetCompanionSettings()
    PlayerBars.Group.GetSettings()
end
