--[[---------------------------------------------------------------------------
    AntiDK2 - namespace bootstrap

    This file is loaded first (see AntiDK2.addon) and is the single source of
    truth for everything shared across the addon:

        * addon metadata            ADK.name / version / displayName / ...
        * tracked ability IDs       ADK.IDS
        * colour palette            ADK.COLORS, ADK.Colorize(), ADK.RGB()
        * fonts                     ADK.Font(), ADK.PresetFont(), ADK.FONT_PRESETS
        * movable windows           ADK.WINDOWS (control name <-> saved-var keys)
        * saved-variable defaults   ADK.defaults, ADK.Get()
        * small shared helpers      ADK.IsPlayer(), ADK.CancelTimer(), ADK.Msg()

    Every other file starts with `local ADK = AntiDK2` and populates one of the
    sub-namespaces declared at the bottom of this file.
-----------------------------------------------------------------------------]]

AntiDK2 = AntiDK2 or {}
local ADK = AntiDK2

-- ── Metadata ─────────────────────────────────────────────────────────────────
ADK.name              = "AntiDK2"
ADK.displayName       = "Anti DK 2.0"
ADK.author            = "Vixen Hunny"
ADK.version           = "1.5"               -- keep in sync with ## AddOnVersion in AntiDK2.addon
ADK.slashCommand      = "/antidk"
ADK.savedVarsName     = "AntiDK2_SavedVars"  -- must match ## SavedVariables in AntiDK2.addon
ADK.savedVarsVersion  = 1

-- ── Ability IDs ──────────────────────────────────────────────────────────────
-- All combat-event modules filter EVENT_COMBAT_EVENT on these.
ADK.IDS = {
    CORROSIVE_ARMOR     = 17879,    -- Corrosive Armor DoT tick on the player
    WING_BUFFET         = 21007,    -- Wing Buffet stagger/stun effect
    MOLTEN_WHIP         = 122658,   -- Molten Whip stack effect
    MOLTEN_ATTACK       = 20805,    -- Molten Whip damage hit
    POWER_LASH_EFFECT   = 34117,    -- Flame Lash: effect the DK gains at 5 stacks
    POWER_LASH          = 20824,    -- Power Lash: the actual hit ability
    SHATTERING_ROCKS    = 32678,
    FOSSILIZE           = 32685,
    SHIFTING_STANDARD   = 32958,
}

-- ── Colours ──────────────────────────────────────────────────────────────────
-- Each colour is { r, g, b, a } (0-1 floats, positional, so c.PINK[1] still
-- works) plus a `.hex` field for inline "|cRRGGBB...|r" chat/label markup.
-- Trans-pride palette.
local function Color(hex, alpha)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return { r, g, b, alpha or 1, hex = hex }
end

ADK.COLORS = {
    LIGHT_BLUE  = Color("5BCEFA"),
    PINK        = Color("F5A9B8"),
    WHITE       = Color("FFFFFF"),
    NAVY_BG     = Color("0A0F24", 0.90),
    NAVY_EDGE   = Color("38476B", 0.95),
    CORROSIVE   = Color("70E62E"),           -- poison green
    DANGER      = Color("FF2E2E"),           -- bright red
    WARN        = Color("FFA619"),           -- orange
    ROLL        = Color("FFFF00"),           -- "ROLL NOW" yellow
    GREY        = Color("8C8C99"),
    PIP_EMPTY   = Color("444455"),           -- unfilled stack pip
}

--- Wrap text in ESO colour markup using a palette entry.
---@param color table  one of ADK.COLORS
---@param text  string
function ADK.Colorize(color, text)
    return "|c" .. color.hex .. tostring(text) .. "|r"
end

--- Unpack a palette entry for Control:SetColor(r, g, b, a).
function ADK.RGB(color)
    return color[1], color[2], color[3], color[4]
end

-- ── Fonts ────────────────────────────────────────────────────────────────────
-- Bold ESO font with a thick soft shadow (CrutchAlerts-style).
local FONT_FACE  = "$(BOLD_FONT)"
local FONT_STYLE = "soft-shadow-thick"

--- Build a font string at an arbitrary pixel size.
function ADK.Font(size)
    return string.format("%s|%d|%s", FONT_FACE, math.floor(size), FONT_STYLE)
end

-- Preset names in the order they appear in the settings dropdowns.
ADK.FONT_PRESETS       = { "Small", "Medium", "Large", "XLarge" }
ADK.DEFAULT_FONT_PRESET = "Large"

-- Pixel size for each preset, per popup group. The AVOID popup stacks up to
-- four lines, so it runs a step smaller than the Corrosive popup.
ADK.FONT_SIZES = {
    corrosive = { Small = 28, Medium = 38, Large = 48, XLarge = 60 },
    avoid     = { Small = 24, Medium = 32, Large = 40, XLarge = 52 },
}

--- Font string for a popup group ("corrosive" / "avoid") and preset name.
--- Unknown presets fall back to the default preset.
function ADK.PresetFont(group, preset)
    local sizes = ADK.FONT_SIZES[group] or ADK.FONT_SIZES.corrosive
    return ADK.Font(sizes[preset] or sizes[ADK.DEFAULT_FONT_PRESET])
end

-- ── Movable windows ──────────────────────────────────────────────────────────
-- Ties each top-level window to its saved-variable keys so the settings panel
-- and the UI modules agree on names, anchors and what gets persisted.
--   control   top-level window name passed to CreateTopLevelWindow
--   anchor    anchor point used against GuiRoot (offsets are stored in x/y)
--   x, y      saved-var keys for the anchor offsets
--   scale     saved-var key for SetScale
--   font      saved-var key for the font preset (popups only)
--   fontGroup key into ADK.FONT_SIZES (popups only)
ADK.WINDOWS = {
    main = {
        control = "AntiDK2MainPanel",
        anchor  = TOPLEFT,
        x = "mainPanelX", y = "mainPanelY", scale = "mainPanelScale",
    },
    corrosive = {
        control = "AntiDK2CorrosivePanel",
        anchor  = CENTER,
        x = "corrosivePopupX", y = "corrosivePopupY", scale = "corrosiveScale",
        font = "corrosiveFontPreset", fontGroup = "corrosive",
    },
    avoid = {
        control = "AntiDK2StunPanel",
        anchor  = CENTER,
        x = "avoidPopupX", y = "avoidPopupY", scale = "avoidScale",
        font = "avoidFontPreset", fontGroup = "avoid",
    },
}

-- ── Saved-variable defaults ──────────────────────────────────────────────────
-- Keys are persisted per character in ADK.savedVarsName; renaming one here
-- silently resets that setting for existing users.
ADK.defaults = {
    -- Which mechanics to track
    trackCorrosive          = true,
    trackWings              = true,
    trackMoltenWhip         = true,
    trackPowerLash          = true,
    trackShatteringRocks    = true,
    trackFossilize          = true,
    trackShiftingStandard   = true,

    -- Timing (seconds)
    corrosiveFadeDelay      = 2.5,  -- hide Corrosive popup this long after the last tick
    avoidFadeDelay          = 2.0,  -- how long each AVOID line stays up
    wingsCombatTimeout      = 8,    -- drop a Wing Buffet target after this much silence

    -- Main panel (TOPLEFT offsets from the screen's top-left corner)
    mainPanelX              = 20,
    mainPanelY              = 400,
    mainPanelScale          = 1.0,

    -- Corrosive popup (CENTER offsets from screen centre)
    corrosivePopupX         = 0,
    corrosivePopupY         = -120,
    corrosiveScale          = 1.0,
    corrosiveFontPreset     = ADK.DEFAULT_FONT_PRESET,

    -- AVOID popup (CENTER offsets from screen centre)
    avoidPopupX             = 0,
    avoidPopupY             = -40,
    avoidScale              = 1.0,
    avoidFontPreset         = ADK.DEFAULT_FONT_PRESET,
}

--- Read a setting, falling back to the default if saved vars are not loaded
--- yet or the key is missing. Safe to call from any module at any time.
function ADK.Get(key)
    local sv = ADK.savedVars
    if sv and sv[key] ~= nil then return sv[key] end
    return ADK.defaults[key]
end

-- ── Shared helpers ───────────────────────────────────────────────────────────

-- Player name is cached lazily; it is empty until the player is activated.
local playerName
function ADK.PlayerName()
    if not playerName or playerName == "" then
        playerName = GetUnitName("player")
    end
    return playerName
end

--- True if a combat-event source/target name refers to the local player.
--- Strips the gender/grammar suffix (e.g. "^Mx") that EVENT_COMBAT_EVENT adds.
function ADK.IsPlayer(unitName)
    if not unitName or unitName == "" then return false end
    return zo_strformat("<<1>>", unitName) == ADK.PlayerName()
end

--- Cancel a zo_callLater handle if set. Always returns nil so callers can
--- write `handle = ADK.CancelTimer(handle)`.
function ADK.CancelTimer(handle)
    if handle then zo_removeCallLater(handle) end
    return nil
end

-- Chat output with a consistent, colour-coded prefix.
local CHAT_PREFIX = ADK.Colorize(ADK.COLORS.LIGHT_BLUE, "[" .. ADK.displayName .. "]")

function ADK.Msg(text)
    CHAT_ROUTER:AddSystemMessage(CHAT_PREFIX .. " " .. tostring(text))
end

function ADK.Error(context, err)
    CHAT_ROUTER:AddSystemMessage(
        CHAT_PREFIX .. " " .. ADK.Colorize(ADK.COLORS.DANGER, context .. " error:") .. " " .. tostring(err))
end

-- ── Sub-namespaces (populated by the other files) ────────────────────────────
ADK.Combat          = ADK.Combat or {}
ADK.Combat.Events   = ADK.Combat.Events or {}
ADK.UI              = ADK.UI or {}
ADK.Config          = ADK.Config or {}
