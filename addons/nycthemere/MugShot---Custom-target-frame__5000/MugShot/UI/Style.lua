-- =========================================================
-- MugShot - Style  (UI/Style.lua)
-- Central style constants for the target frame UI.
-- =========================================================

local MugShot = MugShot

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
        [UNIT_REACTION_HOSTILE]     = { r = 1.00, g = 0.00, b = 0.00 }, -- Vivid Enemy Red (255, 0, 0)
        [UNIT_REACTION_FRIENDLY]    = { r = 0.00, g = 1.00, b = 0.00 }, -- Vivid Friendly Green (0, 255, 0)
        [UNIT_REACTION_PLAYER_ALLY] = { r = 0.00, g = 1.00, b = 0.00 }, -- Vivid Ally Green
        [UNIT_REACTION_NPC_ALLY]    = { r = 0.00, g = 1.00, b = 0.00 }, -- Vivid Ally Green
        [UNIT_REACTION_NEUTRAL]     = { r = 1.00, g = 0.85, b = 0.00 }, -- Vivid Neutral Yellow (255, 215, 0)
        [UNIT_REACTION_DEFAULT]     = { r = 0.85, g = 0.85, b = 0.85 }, -- Clean Grey
    },

    -- Shield overlay colour (translucent teal/cyan)
    SHIELD_COLOR = { r = 0.50, g = 0.85, b = 1.00, a = 0.65 },

    -- Background bar texture: empty for native solid CT_TEXTURE fill
    BAR_TEXTURE = "",

    -- Fonts
    FONT_PERCENTAGE = "$(BOLD_FONT)|20|soft-shadow-thick",
    FONT_HEALTH     = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_NAME       = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_TIMER      = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_STACK      = "$(BOLD_FONT)|14|soft-shadow-thick",
}

MugShot.logger:Info("=== Style loaded ===")
