--[[
    Constants: ids, icons, fonts, sounds, defaults.
    Loads right after the language files and creates the single add-on table.
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
-- Language files load first and place their strings on this single add-on table.
local HMK = _G[ADDON]
if not HMK then HMK = {}; _G[ADDON] = HMK end
HMK.Strings = HMK.Strings or {}
local STRINGS = HMK.Strings
local function T(key) return STRINGS[key] or key end
HMK.T = T

HMK.name = ADDON
HMK.version = "1.1.0"
HMK.active = false   -- mask equipped right now
HMK.unlocked = false -- move mode (not saved)

HMK.WARMASK_PLAYER_EFFECT_ABILITY_ID = 252050 -- Huntsman's Warmask self effect (player)

-- White art on a transparent background: the icon colour is multiplied with the white,
-- so every icon takes ANY colour chosen in the settings.
local ICONS = {
    { id = "wolf", label = T("ICON_WOLF"),       path = ADDON .. "/textures/huntsman_wolf.dds" },
    { id = "stag", label = T("ICON_STAG"), path = ADDON .. "/textures/huntsman_stag.dds" },
    { id = "paw",  label = T("ICON_PAW"),   path = ADDON .. "/textures/huntsman_paw.dds" },
    { id = "boar",    label = T("ICON_BOAR"),     path = ADDON .. "/textures/huntsman_boar.dds" },
    { id = "raven",   label = T("ICON_RAVEN"),     path = ADDON .. "/textures/huntsman_raven.dds" },
    { id = "bear",    label = T("ICON_BEAR"),    path = ADDON .. "/textures/huntsman_bear.dds" },
    { id = "braid",   label = T("ICON_BRAID"), path = ADDON .. "/textures/huntsman_braid.dds" },
    { id = "arrow",   label = T("ICON_ARROW"), path = ADDON .. "/textures/huntsman_arrow.dds" },
    { id = "thorn",   label = T("ICON_THORN"),     path = ADDON .. "/textures/huntsman_thorn.dds" },
    { id = "triple",  label = T("ICON_TRIPLE"),     path = ADDON .. "/textures/huntsman_triple.dds" },
    { id = "hircine", label = T("ICON_HIRCINE"),  path = ADDON .. "/textures/huntsman_hircine.dds" },
    { id = "beast",   label = T("ICON_BEAST"),   path = ADDON .. "/textures/huntsman_beast.dds" },
}
-- Shared safe crop measured from the union of all icon alpha bounds (256x256 DDS).
-- The two-pixel safety margin keeps antialiased edges intact and preserves one aspect ratio.
local ICON_U_LEFT, ICON_U_RIGHT = 7 / 256, 249 / 256
local ICON_V_TOP, ICON_V_BOTTOM = 7 / 256, 249 / 256

local FONT_DIR     = ADDON .. "/fonts/"

local FONTS = {
    { id = "Cinzel-Regular",   label = "Cinzel Regular",   path = FONT_DIR .. "Cinzel-Regular.slug" },
    { id = "Cinzel-Medium",    label = "Cinzel Medium",    path = FONT_DIR .. "Cinzel-Medium.slug" },
    { id = "Cinzel-SemiBold",  label = "Cinzel SemiBold",  path = FONT_DIR .. "Cinzel-SemiBold.slug" },
    { id = "Cinzel-Bold",      label = "Cinzel Bold",      path = FONT_DIR .. "Cinzel-Bold.slug" },
    { id = "Cinzel-ExtraBold", label = "Cinzel ExtraBold", path = FONT_DIR .. "Cinzel-ExtraBold.slug" },
    { id = "Cinzel-Black",     label = "Cinzel Black",     path = FONT_DIR .. "Cinzel-Black.slug" },
    { id = "ESO-Bold",         label = "ESO Bold (game default)", path = "$(BOLD_FONT)" },
}

-- ESO addons cannot play their own audio files, only the game's built-in sounds.
-- Candidates that do not exist in the running client are skipped automatically.
local SOUND_CANDIDATES = {
    { id = "DUEL_START",          label = T("SOUND_DUEL_START") },
    { id = "GUILD_ROSTER_ADDED",  label = T("SOUND_GUILD_JOIN") },
}

local OUTLINES = {
    { id = "none",             label = T("OUTLINE_NONE"),         value = "" },
    { id = "soft-shadow-thin", label = T("OUTLINE_SOFT_THIN"),  value = "soft-shadow-thin" },
    { id = "soft-shadow-thick",label = T("OUTLINE_SOFT_THICK"), value = "soft-shadow-thick" },
    { id = "thick-outline",    label = T("OUTLINE_THICK"), value = "thick-outline" },
}

-- Slots that may hold the mask (it is a headpiece, but scanning armor+jewelry is cheap).
local SCAN_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_HAND, EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
}

local DEFAULTS = {
    mark = {
        size      = 64,
        icon      = "wolf",                                 -- see ICONS
        color     = { r = 1, g = 1, b = 1, a = 1 },        -- icon tint
        x         = 0,                                      -- offset of icon centre from screen centre
        y         = 0,
        positionValid = false,                              -- true only after the player saves a real window position
        timerMode = "edge",                                 -- "inside" | "edge" (half over the icon's bottom edge) | "hidden"
        timerOffsetY = 0,                                   -- fine tuning of the timer, + = down
        font      = "Cinzel-Bold",
        fontSize  = 24,
        outline   = "soft-shadow-thick",
        timerColor = { r = 1, g = 0.85, b = 0.3, a = 1 },
        tenths    = true,                                   -- show 4.2 instead of 5 under 5 s
        warnEnabled   = true,                               -- recolor when the mark is about to expire
        warnSeconds   = 15,
        warnColor     = { r = 1, g = 0.1, b = 0.1, a = 1 },
        warnIcon      = true,
        warnTimer     = false,
        soundEnabled  = true,                               -- play a sound when the warning time is reached
        soundInterval = 1,                                  -- 0 = once, otherwise repeat every N seconds until refreshed/ended
        sound         = "DUEL_START",                       -- see SOUND_CANDIDATES
    },
    maskSetId = 0,      -- learned set id of the mask (0 = unknown)
}

HMK.ICONS = ICONS
HMK.ICON_U_LEFT, HMK.ICON_U_RIGHT = ICON_U_LEFT, ICON_U_RIGHT
HMK.ICON_V_TOP, HMK.ICON_V_BOTTOM = ICON_V_TOP, ICON_V_BOTTOM
HMK.FONTS = FONTS
HMK.SOUND_CANDIDATES = SOUND_CANDIDATES
HMK.OUTLINES = OUTLINES
HMK.SCAN_SLOTS = SCAN_SLOTS
HMK.DEFAULTS = DEFAULTS
