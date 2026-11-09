-- =========================================================================
-- ARCHITECTURAL CONTRACT & CODING RULES (MANDATORY FOR ALL AI AGENTS & DEVS)
-- =========================================================================
-- 1. SCOPE: MugShot tracks the 'reticleover' target frame.
--    Line 3 (privileged debuffs) is strictly for HOSTILE / ENEMY targets.
--    NEVER put player/ally buffs (e.g. Combat Prayer, Spell Power Cure)
--    into enemy debuff templates.
-- 2. ZERO MOCK DATA: Constants must only contain immutable definitions
--    (ability IDs, canonical names, short tags, static configurations).
--    NEVER put dynamic runtime state here (no timerText, no isActive,
--    no isGhost, no stackText). Mock preview data belongs exclusively
--    in test/preview files or dedicated preview helper functions.
-- 3. LOCALIZATION: All user-facing text and translations belong STRICTLY in
--    Localisation.lua. Do NOT put multilingual keyword tables, accent maps,
--    or hardcoded non-English strings in Constants or Core logic.
--    Abilities are resolved natively via abilityId and GetAbilityName().
-- 4. NO BACKWARD COMPATIBILITY BAGGAGE:
--    Do NOT keep legacy aliases (e.g. TOP_LEFT, BOTTOM_RIGHT) or hacky
--    migration layers. If SavedVariables are invalid or outdated, defaults
--    are loaded directly from Defaults.lua.
-- 5. VALID ESO ASSETS: Never invent ability IDs (abilityId = 0 is forbidden)
--    or fake texture paths. Only use real, verified ESO paths.
-- 6. NO DEAD CODE: Do not define constants or palettes (e.g. CLASS_COLORS)
--    that are never consumed by the addon.
-- 7. EVENT FILTERS: Never duplicate native event filters in Lua code
--    (no re-checking unitTag or powerType when already filtered).
-- 8. NO AI SLOP: Never guard native ESO APIs or standard events with
--    defensive 'if' checks; consult local 'eso_dev' as the source of truth.
-- =========================================================================

-- =========================================================
-- MugShot - Constants  (Constants.lua)
-- =========================================================

MugShot = MugShot or {}
local MugShot = MugShot

-- ── Logger (available immediately for all modules) ────────
local noop = function() end
local stub = {
    Info    = noop,
    Debug   = noop,
    Warn    = noop,
    Error   = noop,
    Verbose = noop,
    Create  = function(self, _tag) return self end,
}

if LibDebugLogger then
    local logger = (type(LibDebugLogger.Create) == "function" and LibDebugLogger.Create("MugShot"))
        or (type(LibDebugLogger) == "function" and LibDebugLogger("MugShot"))
    MugShot.logger = logger or stub
else
    MugShot.logger = stub
end

-- ── Constants ──────────────────────────────────────────────
local ICON_MISSING = "/esoui/art/icons/icon_missing.dds"

local C = {
    ADDON_NAME         = "MugShot",
    ADDON_VERSION      = "2026.11.08-101121",
    AUTHOR             = "|c783f04nyc|r|c8fce00thé|r|c6a329fmère|r",
    SAVED_VARS_NAME    = "MugShotSV",
    UNIT_TAG           = "reticleover", -- Target unit tracked by MugShot
    UPDATE_INTERVAL_MS = 250,

    COLORS = {
        MAUVE  = "|c9b00af",
        WHITE  = "|cffffff",
        RED    = "|cff0000",
        GREEN  = "|c00ff00",
        CYAN   = "|c2ec7f5",
        GOLD   = "|cffd700",
        SILVER = "|cc0c0c0",
    },

    -- Zone Identifiers & Value Types (3 Equal Lines, Left & Right)
    QUADRANTS = {
        LINE1_LEFT   = "line1Left",
        LINE1_RIGHT  = "line1Right",
        LINE2_LEFT   = "line2Left",
        LINE2_RIGHT  = "line2Right",
        LINE3_LEFT   = "line3Left",
        LINE3_RIGHT  = "line3Right",
    },

    VALUES = {
        PERCENT    = "percent",
        HEALTH     = "health",
        NAME       = "name",
        PRIVILEGED = "privileged",
        NONE       = "none",
    },

    -- Standardized RGBA color palettes (Flyweight singletons - zero GC allocation)
    RGBA = {
        BLACK               = { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
        WHITE               = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
        BAR_BG              = { r = 0.08, g = 0.08, b = 0.08, a = 1.00 },
        PORTRAIT_BG         = { r = 0.04, g = 0.04, b = 0.04, a = 1.00 },
        SLOT_BG             = { r = 0.00, g = 0.00, b = 0.00, a = 0.40 },

        -- Accents & Borders
        SHIELD              = { r = 0.50, g = 0.85, b = 1.00, a = 0.65 },
        MOVE_MODE_BORDER    = { r = 0.20, g = 0.80, b = 1.00, a = 1.00 },
        GROUP_DEBUFF_CYAN   = { r = 0.18, g = 0.78, b = 0.96, a = 1.00 },
        GOLD_HIGHLIGHT      = { r = 1.00, g = 0.85, b = 0.00, a = 1.00 },
        GOLD_HIGHLIGHT_BG   = { r = 1.00, g = 0.85, b = 0.00, a = 0.25 },
        SILVER_HIGHLIGHT    = { r = 0.80, g = 0.90, b = 1.00, a = 1.00 },
        BADGE_DISABLED      = { r = 0.40, g = 0.40, b = 0.40, a = 0.45 },

        -- High-contrast debuff colors
        DEBUFF_GHOST_TEXT   = { r = 0.90, g = 0.92, b = 0.95, a = 0.65 },
        DEBUFF_GHOST_BORDER = { r = 0.70, g = 0.75, b = 0.85, a = 0.35 },
        DEBUFF_SLOT_BG      = { r = 0.00, g = 0.00, b = 0.00, a = 0.40 },

        -- Target Reaction Colors
        REACTION_HOSTILE     = { r = 1.00, g = 0.00, b = 0.00, a = 1.00 },
        REACTION_FRIENDLY    = { r = 0.00, g = 1.00, b = 0.00, a = 1.00 },
        REACTION_NEUTRAL     = { r = 1.00, g = 0.85, b = 0.00, a = 1.00 },
        REACTION_DEFAULT     = { r = 0.85, g = 0.85, b = 0.85, a = 1.00 },

        -- Reusable static flyweights to prevent GC allocations
        WHITE_ARRAY          = { 1.00, 1.00, 1.00, 1.00 },
        DEFAULT_BORDER       = { r = 0.00, g = 0.00, b = 0.00, a = 1.00 },
    },

    ICONS = {
        MISSING           = ICON_MISSING,
    },

    -- Canonical debuff abbreviations (Fallback headers when tag is omitted)
    SHORT_DEBUFF_NAMES = {
        ["Crusher"]                  = "CRUSH",
        ["Breach"]                   = "BREACH",
        ["Major Breach"]             = "BREACH",
        ["Minor Breach"]             = "BREACH",
        ["Brittle"]                  = "BRITTLE",
        ["Major Brittle"]            = "BRITTLE",
        ["Minor Brittle"]            = "BRITTLE",
        ["Line Breaker"]             = "ALKOSH",
        ["Maim"]                     = "MAIM",
        ["Major Maim"]               = "MAIM",
        ["Minor Maim"]               = "MAIM",
        ["Weakening"]                = "WEAK",
        ["Off Balance"]              = "OFF-BAL",
        ["Touch of Z'en"]            = "Z'EN",
        ["Martial Knowledge"]        = "MK",
        ["Vulnerability"]            = "VULN",
        ["Major Vulnerability"]      = "VULN",
        ["Minor Vulnerability"]      = "VULN",
        ["The Morag Tong"]           = "MORAG",
    },

    -- ── Data-driven Role Debuff Builder Templates (Line 3 Privileged Debuffs) ──
    -- STRICT CONTRACT: Only immutable definitions here (abilityId, tag, name, isPair).
    -- NO dynamic runtime fields (timerText, isActive, isGhost, stackText).
    -- NO ally buffs: only genuine debuffs applicable to the HOSTILE TARGET.
    BUILDER_TEMPLATES = {
        tank = {
            name = "Tank (Raid)",
            debuffs = {
                { key = "crusher",      tag = "CRUSH",   name = "Crusher",       abilityId = 17906, isPair = false },
                { key = "breach",       tag = "BREACH",  name = "Breach",        majorAbilityId = 61743, minorAbilityId = 61742, isPair = true,  majorName = "Major Breach", minorName = "Minor Breach" },
                { key = "brittle",      tag = "BRITTLE",    name = "Brittle",       majorAbilityId = 145975, minorAbilityId = 145977, isPair = true,  majorName = "Major Brittle", minorName = "Minor Brittle" },
                { key = "line_breaker", tag = "ALKOSH",  name = "Line Breaker",  abilityId = 139708, isPair = false },
                { key = "maim",         tag = "MAIM",    name = "Maim",          majorAbilityId = 61725, minorAbilityId = 61723, isPair = true,  majorName = "Major Maim", minorName = "Minor Maim" },
            }
        },
        healer = {
            name = "Healer (Raid)",
            debuffs = {
                { key = "brittle",       tag = "BRITTLE",    name = "Brittle",          majorAbilityId = 145975, minorAbilityId = 145977, isPair = true,  majorName = "Major Brittle", minorName = "Minor Brittle" },
                { key = "weakening",     tag = "WEAK",    name = "Weakening",        abilityId = 17945, isPair = false },
                { key = "maim",          tag = "MAIM",    name = "Maim",             majorAbilityId = 61725, minorAbilityId = 61723, isPair = true,  majorName = "Major Maim", minorName = "Minor Maim" },
                { key = "off_balance",   tag = "OFF-BAL", name = "Off Balance",      abilityId = 39077, isPair = false },
                { key = "vulnerability", tag = "VULN",    name = "Vulnerability",    majorAbilityId = 106754, minorAbilityId = 106757, isPair = true,  majorName = "Major Vulnerability", minorName = "Minor Vulnerability" },
            }
        },
        dps = {
            name = "DPS Mag (Z'en / MK)",
            debuffs = {
                { key = "touch_of_zen",      tag = "Z'EN",    name = "Touch of Z'en",     abilityId = 126597, isPair = false },
                { key = "martial_knowledge", tag = "MK",      name = "Martial Knowledge", abilityId = 127070, isPair = false },
                { key = "vulnerability",     tag = "VULN",    name = "Vulnerability",     majorAbilityId = 106754, minorAbilityId = 106757, isPair = true,  majorName = "Major Vulnerability", minorName = "Minor Vulnerability" },
                { key = "off_balance",       tag = "OFF-BAL", name = "Off Balance",       abilityId = 39077, isPair = false },
                { key = "the_morag_tong",    tag = "MORAG",   name = "The Morag Tong",    abilityId = 104743, isPair = false },
            }
        },
    },

    -- Sample effects definition strictly for Move Mode preview
    SAMPLE_EFFECT_DEFS = {
        { abilityId = 61744, defaultIcon = ICON_MISSING, timerText = "3s", stackText = "x2", isGroup = true },
        { abilityId = 39077, defaultIcon = ICON_MISSING, timerText = "15s", stackText = "" },
        { abilityId = 17906, defaultIcon = ICON_MISSING, timerText = "2s", stackText = "" },
    },

    -- ── Data-Driven Badges & Portrait Metadata ────────────────────
    -- Used by Portraits.lua when ESO native API is unavailable.
    RACE_ID_TO_NAME = {
        [1]  = "breton",    [2]  = "redguard",  [3]  = "orc",
        [4]  = "dunmer",    [5]  = "nord",      [6]  = "argonian",
        [7]  = "altmer",    [8]  = "bosmer",    [9]  = "khajiit",
        [10] = "imperial",
    },

    CLASS_ICONS = {
        [1]   = "/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds",
        [2]   = "/esoui/art/icons/class/gamepad/gp_class_sorcerer.dds",
        [3]   = "/esoui/art/icons/class/gamepad/gp_class_nightblade.dds",
        [4]   = "/esoui/art/icons/class/gamepad/gp_class_warden.dds",
        [5]   = "/esoui/art/icons/class/gamepad/gp_class_necromancer.dds",
        [6]   = "/esoui/art/icons/class/gamepad/gp_class_templar.dds",
        [117] = "/esoui/art/icons/class/gamepad/gp_class_arcanist.dds",
    },

    ALLIANCE_FLAG_BASE = "/esoui/art/compass/ava_flagneutral.dds",

    ALLIANCE_ICONS = {
        [1] = "/esoui/art/stats/alliancebadge_aldmeri.dds",
        [2] = "/esoui/art/stats/alliancebadge_ebonheart.dds",
        [3] = "/esoui/art/stats/alliancebadge_daggerfall.dds",
    },

    ALLIANCE_COLORS = {
        [1] = { r = 1.00, g = 0.85, b = 0.00, a = 1.00 }, -- Aldmeri Dominion
        [2] = { r = 1.00, g = 0.15, b = 0.15, a = 1.00 }, -- Ebonheart Pact
        [3] = { r = 0.15, g = 0.65, b = 1.00, a = 1.00 }, -- Daggerfall Covenant
    },
}

C.DISPLAY_NAME = string.format("%s%s|r", C.COLORS.MAUVE, C.ADDON_NAME)

MugShot.Constants = C

MugShot.logger:Info("=== Constants loaded ===")
