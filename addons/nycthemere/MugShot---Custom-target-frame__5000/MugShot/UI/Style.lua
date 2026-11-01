-- =========================================================
-- MugShot - Style  (UI/Style.lua)
-- Central style constants for the target frame UI.
-- =========================================================

local MugShot = MugShot
local RGBA = (MugShot.Constants and MugShot.Constants.RGBA) or {}

MugShot.Style = {
    -- Dimensions matching
    BAR_WIDTH         = 300,
    BAR_HEIGHT        = 75,
    BAR_BG_WIDTH      = 304, -- 300 + 4 (2px border on all sides)
    BAR_BG_HEIGHT     = 79,  -- 75 + 4 (2px border on all sides)
    PORTRAIT_SIZE     = 75,
    PORTRAIT_BG_SIZE  = 79,  -- 75 + 4 (2px border on all sides)
    FRAME_WIDTH       = 381, -- 304 barBg + 79 portraitBg - 2 shared border
    FRAME_HEIGHT      = 79,

    -- Buff/Debuff effect dimensions
    EFFECT_ICON_SIZE  = 32,
    EFFECT_SLOT_SIZE  = 36,
    EFFECT_GAP        = 2,
    MAX_EFFECTS       = 30,  -- Pre-allocated effect slots (3 rows of 10)

    -- Vivid reaction colours matching TargetFrame / src.png
    REACTION_COLORS = {
        [UNIT_REACTION_HOSTILE]     = RGBA.REACTION_HOSTILE  or { r = 1.00, g = 0.00, b = 0.00, a = 1.00 },
        [UNIT_REACTION_FRIENDLY]    = RGBA.REACTION_FRIENDLY or { r = 0.00, g = 1.00, b = 0.00, a = 1.00 },
        [UNIT_REACTION_PLAYER_ALLY] = RGBA.REACTION_FRIENDLY or { r = 0.00, g = 1.00, b = 0.00, a = 1.00 },
        [UNIT_REACTION_NPC_ALLY]    = RGBA.REACTION_FRIENDLY or { r = 0.00, g = 1.00, b = 0.00, a = 1.00 },
        [UNIT_REACTION_NEUTRAL]     = RGBA.REACTION_NEUTRAL  or { r = 1.00, g = 0.85, b = 0.00, a = 1.00 },
        [UNIT_REACTION_DEFAULT]     = RGBA.REACTION_DEFAULT  or { r = 0.85, g = 0.85, b = 0.85, a = 1.00 },
    },

    -- Shield overlay colour (translucent teal/cyan)
    SHIELD_COLOR = { r = 0.50, g = 0.85, b = 1.00, a = 0.65 },

    -- Background bar texture: empty for native solid CT_TEXTURE fill
    BAR_TEXTURE = "",

    -- Fonts
    FONT_PERCENTAGE = "$(BOLD_FONT)|20|soft-shadow-thick",
    FONT_HEALTH     = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_NAME       = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_TIMER      = "$(BOLD_FONT)|13|soft-shadow-thick",
    FONT_STACK      = "$(BOLD_FONT)|11|soft-shadow-thick",
    FONT_SOURCE     = "$(BOLD_FONT)|10|soft-shadow-thick",

    -- Standardized UI Element Colors from Constants.RGBA
    SHIELD_COLOR        = RGBA.SHIELD            or { r = 0.50, g = 0.85, b = 1.00, a = 0.65 },
    FRAME_BORDER        = RGBA.BLACK             or { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
    BORDER_COLOR_PLAYER = RGBA.BLACK             or { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
    BORDER_COLOR_MULTI  = RGBA.GROUP_DEBUFF_CYAN or { r = 0.18, g = 0.78, b = 0.96, a = 1.00 },
    BORDER_COLOR_GROUP  = RGBA.GROUP_DEBUFF_CYAN or { r = 0.18, g = 0.78, b = 0.96, a = 1.00 },
    MOVE_MODE_BORDER    = RGBA.MOVE_MODE_BORDER  or { r = 0.20, g = 0.80, b = 1.00, a = 1.00 },
    BAR_BG_COLOR        = RGBA.BAR_BG            or { r = 0.08, g = 0.08, b = 0.08, a = 1.00 },
    PORTRAIT_BG_COLOR   = RGBA.PORTRAIT_BG       or { r = 0.04, g = 0.04, b = 0.04, a = 1.00 },
    SLOT_BG_COLOR       = RGBA.SLOT_BG           or { r = 0.04, g = 0.04, b = 0.04, a = 0.95 },
    TEXT_COLOR_WHITE    = RGBA.WHITE             or { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
    TEXT_COLOR_CYAN     = RGBA.GROUP_DEBUFF_CYAN or { r = 0.18, g = 0.78, b = 0.96, a = 1.00 },
}

MugShot.logger:Info("=== Style loaded ===")
