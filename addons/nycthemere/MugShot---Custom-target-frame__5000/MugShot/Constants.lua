-- =========================================================
-- MugShot - Constants  (Constants.lua)
-- =========================================================

local MugShot = MugShot

-- ── Logger (available immediately for all modules) ────────
-- Uses LibDebugLogger when present; falls back to a no-op stub
-- so every module can call MugShot.logger:Info/Debug/Warn/Error
-- without guarding every call site.
if LibDebugLogger then
    MugShot.logger = LibDebugLogger("MugShot")
else
    local noop = function() end
    local stub = {
        Info    = noop,
        Debug   = noop,
        Warn    = noop,
        Error   = noop,
        Verbose = noop,
        Create  = function(self, _tag) return self end,
    }
    MugShot.logger = stub
end

-- ── Constants ──────────────────────────────────────────────
local C = {
    ADDON_NAME      = "MugShot",
    ADDON_VERSION   = "2026.10.31-101047",
    AUTHOR          = "|c783f04nyc|r|c8fce00thé|r|c6a329fmère|r",
    SAVED_VARS_NAME = "MugShotSV",
    UNIT_TAG        = "reticleover",
    HUD_SCENES      = { hud = true, hudui = true },
    EVENT_NAMESPACE = "MugShot",

    COLORS = {
        MAUVE  = "|c9b00af",
        WHITE  = "|cffffff",
        RED    = "|cff0000",
        GREEN  = "|c00ff00",
        CYAN   = "|c2ec7f5",
    },

    -- Standardized RGBA color palettes (Flyweight singletons - zero GC allocation)
    RGBA = {
        BLACK               = { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
        WHITE               = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
        BAR_BG              = { r = 0.08, g = 0.08, b = 0.08, a = 1.00 },
        PORTRAIT_BG         = { r = 0.04, g = 0.04, b = 0.04, a = 1.00 },
        SLOT_BG             = { r = 0.04, g = 0.04, b = 0.04, a = 0.95 },

        -- Accents & Borders
        SHIELD              = { r = 0.50, g = 0.85, b = 1.00, a = 0.65 },
        MOVE_MODE_BORDER    = { r = 0.20, g = 0.80, b = 1.00, a = 1.00 },
        GROUP_DEBUFF_CYAN   = { r = 0.18, g = 0.78, b = 0.96, a = 1.00 },

        -- Target Reaction Colors
        REACTION_HOSTILE     = { r = 1.00, g = 0.00, b = 0.00, a = 1.00 },
        REACTION_FRIENDLY    = { r = 0.00, g = 1.00, b = 0.00, a = 1.00 },
        REACTION_NEUTRAL     = { r = 1.00, g = 0.85, b = 0.00, a = 1.00 },
        REACTION_DEFAULT     = { r = 0.85, g = 0.85, b = 0.85, a = 1.00 },
    },
}

C.DISPLAY_NAME = string.format("%s%s|r", C.COLORS.MAUVE, C.ADDON_NAME)

MugShot.Constants = C

MugShot.logger:Info("=== Constants loaded ===")
