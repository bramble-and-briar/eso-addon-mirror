-- ESO Hybrid UI: the single shared addon table, string ids, defaults, runtime state.
-- User-facing strings live in lang/en.lua.
-- Every other file starts with `local ADDON = ESOHybridUI` (one global, per ESOUI guidance).

local ADDON = _G.ESOHybridUI or {}
_G.ESOHybridUI = ADDON


ADDON.ADDON_NAME = "ESOHybridUI"
ADDON.SAVED_VARIABLES = "ESOHybridUI_SavedVariables"
-- Keep at 1: changing it makes ZO_SavedVars discard every user's saved settings.
ADDON.SAVED_VARIABLES_VERSION = 1
ADDON.VERSION = "4.2.1-beta"

ADDON.MODE_GAMEPAD = "gamepad"
ADDON.MODE_HYBRID = "hybrid"

-- How menus opened from the HUD are chosen (see Policy.lua).
ADDON.POLICY_GAMEPAD = "gamepad"
ADDON.POLICY_LEGACY = "legacy"

-- Only plain values and the one nested "fonts" table live here. Nested tables are
-- always read and written through helpers in Core.lua (GetFont/SetFont) so the
-- code never depends on how ZO_SavedVars proxies nested defaults.
ADDON.defaults = {
    mode = ADDON.MODE_GAMEPAD,
    menuPolicy = ADDON.POLICY_GAMEPAD,

    -- Hybrid feature switches (each one can be turned off if a game patch breaks it).
    hybridQuickslotWheel = true,
    hybridActionBarGlyphs = true,

    fonts = {
        reticle = "ZoFontKeybindStripDescription",
        reticleContext = "ZoInteractionPrompt",
        stealthIcon = "ZoInteractionPrompt",
    },

    announceLoaded = false,
    debugLoggingEnabled = false,
}

ADDON.runtime = {
    originalIsInGamepadPreferredMode = nil,
    modeOverrideInstalled = false,
    overrideFunction = nil,

    -- Context depth counters (see Policy.lua). >0 means "answer this way".
    forceNativeModeDepth = 0,
    forceKeyboardWheelDepth = 0,
    gamepadDialogName = nil,

    -- Cached copy of "is Hybrid selected" so the hot path never touches saved vars.
    hybrid = false,
    menusGamepad = true,

    isLockpicking = false,
    isRefreshing = false,
    platformDirty = false,
    platformRefreshScheduled = false,
    initialized = false,

    -- Install bookkeeping (InstallWhenReady in Core.lua).
    installed = {},
    attempts = {},
    retryRegistered = {},

    -- Active only while the keyboard-style quickslot wheel is open.
    utilityWheelLayerActive = false,

    -- Prompt bookkeeping. Weak keys so we never keep a dead descriptor alive.
    promptOriginals = setmetatable({}, { __mode = "k" }),
    stackAllOriginals = setmetatable({}, { __mode = "k" }),

    -- Diagnostics.
    logger = nil,
    debugLoggingEnabled = false,
    traceEnabled = false,
    trace = nil,
}
