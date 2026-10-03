local AE = AtlasAddon

AE.Translations.en = {
    NAME = "Atlas",
    ADDON_DESCRIPTION = "A Torfason × Atlas addon for The Elder Scrolls Online. Reveals the world map as your character explores Tamriel.",
    PREFIX = "|cD8B36A[Atlas]|r ",

    LOADED = "loaded. /atlas help shows the commands.",

    HELP = [[
|cD8B36AAtlas – Commands|r
/atlas – open Atlas settings
/atlas help – show this help
/atlas on – enable Atlas
/atlas off – disable Atlas
/atlas reveal – fully reveal the current map
/atlas forget – clear exploration of the current map
/atlas import – import TrueExploration for the current character
/atlas importall – merge all found TrueExploration profiles
/atlas status – show information about the current map
/atlas archive – open the Atlas archive on the world map
/atlas settings – open Atlas settings
/atlas style <1-6> – choose the unexplored map style
/atlas radius <1-8> – reveal radius in map cells
/atlas opacity <10-100> – opacity of the unexplored map in percent
/ae remains available as a short alias.

German commands continue to work as well, e.g. /atlas hilfe, /atlas an, /atlas aufdecken.
]],

    ENABLED = "Atlas is enabled.",
    DISABLED = "Atlas is disabled.",
    CURRENT_MAP_REVEALED = "The current map has been fully revealed.",
    CURRENT_MAP_CLEARED = "Exploration data for the current map has been cleared.",
    NO_MAP = "No usable map area could be detected right now.",
    STATUS = "Map: %s | discovered: %d / %d cells (%.1f%%) | style: %s",
    STYLE_SET = "Unexplored map style: %s",
    RADIUS_SET = "Reveal radius: %d map cells.",
    OPACITY_SET = "Opacity: %d%%.",
    BAD_VALUE = "That value is not valid. Use /atlas help.",

    ARCHIVE_TITLE = "MAP ARCHIVE",
    ARCHIVE_SUBTITLE = "Every map on which Atlas has already drawn something.",
    ARCHIVE_COUNT = "%d saved maps",
    ARCHIVE_EMPTY = "No explored maps have been saved yet.",
    ARCHIVE_PAGE = "Page %d / %d",
    ARCHIVE_PREV = "Previous",
    ARCHIVE_NEXT = "Next",
    ARCHIVE_OPEN_HINT = "Click to open this map.",
    ARCHIVE_OPEN_FAILED = "ESO does not allow this map to be opened directly from here. Atlas will keep it in the archive.",
    ARCHIVE_UNRESOLVED = "Atlas knows this drawing but has not matched it to an ESO map ID yet. The next time you visit the map, it will be linked automatically.",
    ARCHIVE_RESOLVING = "Atlas is matching older saved maps to their ESO map IDs in the background …",
    ARCHIVE_PATH = "Saved as: %s",
    ARCHIVE_UNKNOWN_MAP = "Unknown map",

    IMPORT_NO_TE = "TrueExploration data is not loaded. Enable TrueExploration together with Atlas once, reload the UI, and start the import again.",
    IMPORT_START = "Checking TrueExploration import …",
    IMPORT_DONE = "Import complete: %d maps found, %d maps merged, %d cells added, %d entries could not be recognized.",
    IMPORT_NONE = "The current character's TrueExploration profile was not found. Enable TrueExploration together with Atlas and reload the UI.",
    IMPORT_NONE_ALL = "No TrueExploration map tables were found in TE_SavedVars.",
    IMPORT_ALL_WARNING = "All found TrueExploration profiles will be merged into this character.",

    STYLE_NAMES = {
        "Parchment",
        "Light Paper",
        "Dark Parchment",
        "Mist Gray",
        "Charcoal",
        "Deep Black",
    },
    STYLE_VALUES = AE.LanguageStyleValues,
    STYLE_TOOLTIPS = {
        "Parchment – old explorer's map with faded compass and navigation drawings",
        "Light Paper – cartographer's sheet with fine survey lines and measurement marks",
        "Dark Parchment – aged nautical chart with faded coastlines and fold marks",
        "Mist Gray – cool mist with subtle contour lines and soft haze",
        "Charcoal – rough charcoal paper with hand-drawn paths and old waymarks",
        "Deep Black – mysterious night map with a very subtle star and navigation pattern",
    },

    SETTINGS_VERSION = "Version %s",
    SETTINGS_TITLE = "Atlas - Settings",
    SETTINGS_GENERAL_HEADER = "GENERAL",
    SETTINGS_APPEARANCE_HEADER = "APPEARANCE",
    SETTINGS_EXPLORATION_HEADER = "EXPLORATION",
    SETTINGS_DEFAULTS = "Defaults",
    SETTINGS_DEFAULTS_TT = "Reset all Atlas settings to their defaults. Your saved exploration progress is kept.",
    SETTINGS_CLOSE = "Close",
    SETTINGS_CLOSE_SHORT = "X",
    SETTINGS_GEAR_TOOLTIP = "Open Atlas settings",
    SETTINGS_SELECTED_STYLE = "%s: %s",

    OPTION_DESCRIPTION = "The world map starts unexplored and becomes visible only where your character has actually travelled. Exploration progress is stored per character; visual settings apply account-wide.",
    OPTION_ENABLED = "Enable Atlas",
    OPTION_ENABLED_TT = "Covers unexplored parts of the map and reveals new areas as you travel.",
    OPTION_STYLE = "Unexplored map style – preview",
    OPTION_STYLE_TT = "Click the preview image to see all map styles as thumbnails and select one directly.",
    OPTION_SELECTED = "Selected",
    OPTION_OPACITY = "Unexplored map opacity",
    OPTION_OPACITY_TT = "100% completely covers the underlying map. Lower values let it faintly show through.",
    OPTION_RADIUS = "Reveal radius – large maps",
    OPTION_RADIUS_TT = "How many of the 48×48 map cells around your character become visible.",
    OPTION_SUBZONES = "Explore cities, dungeons and submaps",
    OPTION_SUBZONES_TT = "When enabled, submaps also start unexplored.",
    OPTION_SUBRADIUS = "Reveal radius – submaps",
    OPTION_SUBRADIUS_TT = "Submaps are often smaller, so they can use a separate, larger reveal radius.",
    OPTION_CURRENT_HEADER = "Current map",
    OPTION_REVEAL = "Fully reveal current map",
    OPTION_REVEAL_TT = "Marks the currently displayed map as fully discovered.",
    OPTION_CLEAR = "Forget current map",
    OPTION_CLEAR_TT = "Clears only Atlas exploration progress for the currently displayed map.",
    OPTION_IMPORT_HEADER = "TrueExploration import",
    OPTION_IMPORT_DESC = "The import only reads TrueExploration and never modifies its data. To import the current character, enable TrueExploration together with Atlas once. Atlas understands the real 31-bit storage format of the 48×48 grid; map paths that only differ in capitalization are merged automatically.",
    OPTION_IMPORT_CURRENT = "Import current character",
    OPTION_IMPORT_CURRENT_TT = "Recommended: imports only the TrueExploration data of the currently logged-in character.",
    OPTION_IMPORT_ALL = "Merge all old profiles",
    OPTION_IMPORT_ALL_TT = "Merges all found TrueExploration maps into the current character. Existing Atlas cells are never removed.",
    OPTION_COMMANDS_HEADER = "Chat commands",
    OPTION_COMMANDS = "/atlas   /atlas help   /atlas reveal   /atlas forget   /atlas import   /atlas status\n/atlas style 1-6   /atlas radius 1-8   /atlas opacity 10-100",
}
