Schlosswerk = Schlosswerk or {}
Schlosswerk.LocalizationData = Schlosswerk.LocalizationData or {}

Schlosswerk.LocalizationData.en = {
    ADDON_NAME = "Schlosswerk",
    ADDON_DESCRIPTION = "A Torfason × Atlas addon for The Elder Scrolls Online. Adds selectable lock designs while preserving ESO's original lockpicking mechanics.",
    SETTINGS_TITLE = "Schlosswerk - Settings",
    SETTINGS_GEAR_TT = "Open Schlosswerk settings",
    SETTINGS_CLOSE = "Close",
    SETTINGS_DEFAULTS = "Defaults",
    SETTINGS_DEFAULTS_TT = "Restore all Schlosswerk settings to their default values.",
    SETTINGS_DEFAULTS_DONE = "Schlosswerk settings restored to defaults.",
    PANEL_DESCRIPTION = "Choose the appearance of ESO's lockpicking lock. Schlosswerk changes only the lock body and front overlay; the original ESO lockpicking mechanics, tools, pins, springs, sounds and timing remain untouched.",

    HEADER_GENERAL = "General",
    HEADER_RANDOM = "Random selection",
    HEADER_APPEARANCE = "Appearance",


    MODE = "Lock selection",
    MODE_TT = "Use one fixed lock or choose a lock at random for every new lockpicking attempt.",
    MODE_FIXED = "Fixed",
    MODE_RANDOM = "Random",

    FIXED_STYLE = "Fixed lock",
    FIXED_STYLE_TT = "The lock design used when lock selection is set to Fixed.",

    PIN_LIGHTS = "Pin glow",
    PIN_LIGHTS_TT = "Off hides ESO's additive pin glow and keeps solved pins in their normal appearance. On restores ESO's original pin highlight and solved-pin appearance.",

    AVOID_REPEAT = "Prevent the same lock twice in a row",
    AVOID_REPEAT_TT = "When Random is active and at least two locks are enabled, the lock used last will be excluded from the next draw.",

    RANDOM_POOL = "Locks in the random pool",
    RANDOM_POOL_TT = "Enable the locks that may be selected in Random mode. If all entries are disabled, Schlosswerk falls back to Original.",

    STYLE_ORIGINAL = "Original",
    STYLE_CLASSIC = "Classic",
    STYLE_DREMORA = "Dremora",
    STYLE_DWEMER = "Dwemer",
    STYLE_HOLZ = "Wood",
    STYLE_NORD = "Nord",
    STYLE_ORSIMER = "Orsimer",

    ORIGINAL_NOTE = "Original uses ESO's own lock body and front overlay. Pin glow is controlled separately.",
    CHANGES_NEXT_ATTEMPT = "Lock selection and pin-glow changes apply to the next lockpicking attempt.",

    CHAT_HELP = "Commands: /schlosswerk opens the settings, /schlosswerk status shows the current configuration, /schlosswerk help shows this help.",
    CHAT_BLOCKED = "The settings cannot be opened while lockpicking.",
    CHAT_STATUS = "Version %s | Mode: %s | Fixed lock: %s | Pin glow: %s | Prevent repeat: %s",
    CHAT_ON = "On",
    CHAT_OFF = "Off",
}
