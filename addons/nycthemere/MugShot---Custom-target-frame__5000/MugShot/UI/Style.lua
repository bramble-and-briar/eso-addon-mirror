-- =========================================================
-- MugShot - Style  (UI/Style.lua)
-- Central style constants for the target frame UI.
-- =========================================================

local MugShot = MugShot
local RGBA = MugShot.Constants.RGBA

MugShot.Style = {
    -- Dimensions (3 equal lines of 32px each)
    LINE_HEIGHT       = 32,
    BAR_WIDTH         = 300,
    BAR_HEIGHT        = 96,  -- 3 * 32px
    BAR_BG_WIDTH      = 304, -- 300 + 4 (2px border on all sides)
    BAR_BG_HEIGHT     = 100, -- 96 + 4 (2px border on all sides)
    PORTRAIT_SIZE     = 96,
    PORTRAIT_BG_SIZE  = 100, -- 96 + 4 (2px border on all sides)
    FRAME_WIDTH       = 402, -- 304 barBg + 100 portraitBg - 2 shared border
    FRAME_HEIGHT      = 100,
    BORDER_THICKNESS  = 2,
    GRID_BORDER_THICKNESS = 1,

    -- Portrait Badges (Race / Alliance)
    BADGE_SIZE        = 30,
    BADGE_TOGGLE_SIZE = 16,
    ALPHA_OPAQUE      = 1.0,
    ALPHA_DISABLED    = 0.35,

    -- Buff/Debuff effect dimensions (Standard row below frame)
    EFFECT_ICON_SIZE  = 32,
    EFFECT_SLOT_SIZE  = 36,
    EFFECT_GAP        = 2,
    MAX_EFFECTS       = 30,  -- Pre-allocated effect slots (3 rows of 10)

    -- Privileged Debuff Slots on Line 3 (5 full-bleed slots across 300px bar: 60px each)
    PRIVILEGED_SLOT_WIDTH  = 60,
    PRIVILEGED_SLOT_HEIGHT = 32,
    PRIVILEGED_SLOT_GAP    = 0,

    -- Vivid reaction colours matching TargetFrame
    REACTION_COLORS = {
        [UNIT_REACTION_HOSTILE]     = RGBA.REACTION_HOSTILE  or { r = 1.00, g = 0.00, b = 0.00, a = 1.00 },
        [UNIT_REACTION_FRIENDLY]    = RGBA.REACTION_FRIENDLY or { r = 0.00, g = 1.00, b = 0.00, a = 1.00 },
        [UNIT_REACTION_PLAYER_ALLY] = RGBA.REACTION_FRIENDLY or { r = 0.00, g = 1.00, b = 0.00, a = 1.00 },
        [UNIT_REACTION_NPC_ALLY]    = RGBA.REACTION_FRIENDLY or { r = 0.00, g = 1.00, b = 0.00, a = 1.00 },
        [UNIT_REACTION_NEUTRAL]     = RGBA.REACTION_NEUTRAL  or { r = 1.00, g = 0.85, b = 0.00, a = 1.00 },
        [UNIT_REACTION_DEFAULT]     = RGBA.REACTION_DEFAULT  or { r = 0.85, g = 0.85, b = 0.85, a = 1.00 },
    },

    -- Full-color Class Theme Colors (Vivid class identity colors for class portraits)
    CLASS_COLORS = {
        [1]   = { r = 1.00, g = 0.45, b = 0.15, a = 1.00 }, -- Dragonknight (Orange)
        [2]   = { r = 0.45, g = 0.55, b = 1.00, a = 1.00 }, -- Sorcerer (Purple/Blue)
        [3]   = { r = 0.95, g = 0.20, b = 0.20, a = 1.00 }, -- Nightblade (Crimson)
        [4]   = { r = 0.35, g = 0.85, b = 0.65, a = 1.00 }, -- Warden (Green/Teal)
        [5]   = { r = 0.35, g = 0.85, b = 0.95, a = 1.00 }, -- Necromancer (Cyan)
        [6]   = { r = 1.00, g = 0.85, b = 0.25, a = 1.00 }, -- Templar (Yellow/Gold)
        [117] = { r = 0.50, g = 1.00, b = 0.30, a = 1.00 }, -- Arcanist (Lime)
    },

    -- Shield overlay colour (translucent teal/cyan)
    SHIELD_COLOR = RGBA.SHIELD or { r = 0.50, g = 0.85, b = 1.00, a = 0.65 },

    -- Background bar texture: empty for native solid CT_TEXTURE fill
    BAR_TEXTURE = "",

    -- Fonts
    FONT_PERCENTAGE     = "$(BOLD_FONT)|20|soft-shadow-thick",
    FONT_HEALTH         = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_NAME           = "$(BOLD_FONT)|18|soft-shadow-thick",
    FONT_TIMER          = "$(BOLD_FONT)|13|soft-shadow-thick",
    FONT_STACK          = "$(BOLD_FONT)|11|soft-shadow-thick",
    FONT_SOURCE         = "$(BOLD_FONT)|10|soft-shadow-thick",
    FONT_BADGE_TOGGLE   = "$(BOLD_FONT)|14|soft-shadow-thick",
    FONT_DEBUFF_HEADER  = "$(BOLD_FONT)|11|soft-shadow-thick",
    FONT_DEBUFF_BADGE   = "$(BOLD_FONT)|10|soft-shadow-thick",
    FONT_DEBUFF_TIMER   = "$(BOLD_FONT)|11|soft-shadow-thick",
    FONT_DEBUFF_SINGLE  = "$(BOLD_FONT)|14|soft-shadow-thick",

    -- Standardized UI Element Colors from Constants.RGBA
    FRAME_BORDER         = RGBA.BLACK               or { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
    BORDER_COLOR_PLAYER  = RGBA.BLACK               or { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
    BORDER_COLOR_MULTI   = RGBA.GROUP_DEBUFF_CYAN   or { r = 0.18, g = 0.78, b = 0.96, a = 1.00 },
    BORDER_COLOR_GROUP   = RGBA.GROUP_DEBUFF_CYAN   or { r = 0.18, g = 0.78, b = 0.96, a = 1.00 },
    MOVE_MODE_BORDER     = RGBA.MOVE_MODE_BORDER    or { r = 0.20, g = 0.80, b = 1.00, a = 1.00 },
    BAR_BG_COLOR         = RGBA.BAR_BG              or { r = 0.08, g = 0.08, b = 0.08, a = 1.00 },
    PORTRAIT_BG_COLOR    = RGBA.PORTRAIT_BG         or { r = 0.04, g = 0.04, b = 0.04, a = 1.00 },
    SLOT_BG_COLOR        = RGBA.DEBUFF_SLOT_BG      or { r = 0.00, g = 0.00, b = 0.00, a = 0.40 },
    TEXT_COLOR_WHITE     = RGBA.WHITE               or { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
    TEXT_COLOR_CYAN      = RGBA.GROUP_DEBUFF_CYAN   or { r = 0.18, g = 0.78, b = 0.96, a = 1.00 },

    -- Quadrant & Debuff Move Mode Highlights
    QUADRANT_BORDER      = RGBA.MOVE_MODE_BORDER    or { r = 0.20, g = 0.80, b = 1.00, a = 1.00 },
    QUADRANT_SELECTED    = RGBA.GOLD_HIGHLIGHT      or { r = 1.00, g = 0.85, b = 0.00, a = 1.00 },
    QUADRANT_SELECTED_BG = RGBA.GOLD_HIGHLIGHT_BG   or { r = 1.00, g = 0.85, b = 0.00, a = 0.25 },
    BADGE_TOGGLE_TEXT    = RGBA.GOLD_HIGHLIGHT      or { r = 1.00, g = 0.85, b = 0.00, a = 1.00 },
    BADGE_DISABLED_COLOR = RGBA.BADGE_DISABLED      or { r = 0.40, g = 0.40, b = 0.40, a = 0.45 },
    DEBUFF_MAJOR_COLOR   = RGBA.GOLD_HIGHLIGHT      or { r = 1.00, g = 0.85, b = 0.00, a = 1.00 },
    DEBUFF_MINOR_COLOR   = RGBA.SILVER_HIGHLIGHT    or { r = 0.80, g = 0.90, b = 1.00, a = 1.00 },
    DEBUFF_GHOST_BORDER  = RGBA.DEBUFF_GHOST_BORDER or { r = 0.70, g = 0.75, b = 0.85, a = 0.35 },
    DEBUFF_GHOST_TEXT    = RGBA.DEBUFF_GHOST_TEXT   or { r = 0.90, g = 0.92, b = 0.95, a = 0.65 },
}

MugShot.logger:Info("=== Style loaded ===")
