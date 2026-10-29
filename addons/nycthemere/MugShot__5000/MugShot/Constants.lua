-- =========================================================
-- MugShot - Constants  (Constants.lua)
-- =========================================================

MugShot = MugShot or {}

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
    ADDON_VERSION   = "2026.10.29-101045",
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
    },
}

C.DISPLAY_NAME = string.format("%s%s|r", C.COLORS.MAUVE, C.ADDON_NAME)

MugShot.Constants = C

MugShot.logger:Info("=== Constants loaded ===")
