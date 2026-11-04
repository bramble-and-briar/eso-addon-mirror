-- English (base). Other language files only override the keys they translate.
-- Buff names are not here: they come from the game, already in the client language.
-- Strings the game already has are taken with GetString, so every language gets them.
local L = Vigilant.L

-- Lema: qué hace el addon, junto al nombre.
L.TAGLINE = "Group Buff Tracker"

-- Key bindings
L.BINDING_TOGGLE = "Show/hide the panel"
L.BINDING_LOCK = "Lock/unlock the panel"

-- Panel
L.NO_BUFFS = "No buffs selected: /vigilant settings"
L.MISSING = "|cFF4444Missing|r"
L.MISSING_ON = "|cFF4444Missing on:|r"
L.OUT_OF_RANGE = "|c999999Out of range or offline|r"
L.REMAINING = "%s s left"
L.CLOSE_TIP = GetString(SI_DIALOG_CLOSE)
L.SETTINGS_TIP = GetString(SI_GAME_MENU_SETTINGS)
L.LOCK_TIP_BUTTON = "Lock: fix it in place"
L.UNLOCK_TIP = "Unlock: move and resize it"
L.SWITCH_TO = "Switch to %s"
L.HIDDEN = "Panel hidden. Type |cFFFF00/vigilant|r to show it again."

-- Common buff categories (settings)
L.CAT_OFFENSE = "Offensive buffs"
L.CAT_DEFENSE = "Defensive buffs"
L.CAT_RESOURCES = "Resources and mobility"
L.CAT_SETS = "Sets and ultimates"

-- Catalog of every effect
L.BROWSER_TITLE = "Buffs and procs"
L.BROWSER_SEARCH = GetString(SI_SCREEN_NARRATION_EDIT_BOX_SEARCH_NAME)
L.BROWSER_HINT = "Click + (or double-click) to track it. Every variant with the same name counts."
L.BROWSER_LOADING = "Preparing the list of game effects... %d%%"
L.BROWSER_EMPTY = "Nothing found."
L.BROWSER_NO_ACTIVE = "Nobody in range has buffs right now.\nGet the buff or proc and come back."
L.BROWSER_COUNT = "%s effects"
L.BROWSER_TRACKED = "Tracked"
L.BROWSER_VARIANTS = "%d variants"
L.BROWSER_ADDED = "Tracking: %s"
L.BROWSER_REMOVED = "No longer tracking: %s"
L.CAT_GROUP_QUICK = "Quick"
L.CAT_ACTIVE = "Active now (you and group)"
L.CAT_TRACKED = "Tracked"
L.CAT_GROUP_GENERAL = GetString(SI_GAMEPLAY_OPTIONS_GENERAL)
L.CAT_ALL = GetString(SI_ITEMTYPEDISPLAYCATEGORY0)
L.CAT_MAJOR_MINOR = "Major and Minor buffs"
L.CAT_GEAR = "Sets and procs"
L.CAT_CONSUMABLE = GetString(SI_ITEMTYPEDISPLAYCATEGORY4)
L.CAT_GROUP_CLASSES = "Classes"
L.CAT_GROUP_OTHER = "Other"
L.CAT_WEAPON = GetString(SI_ITEMTYPEDISPLAYCATEGORY1)
L.CAT_ARMOR = GetString(SI_ITEMTYPEDISPLAYCATEGORY2)
L.CAT_GUILD = GetString(SI_SOCIAL_MENU_GUILDS)
L.CAT_WORLD = "World and PvP"
L.CAT_MISC = GetString(SI_ITEMTYPEDISPLAYCATEGORY7)

-- Custom buffs
L.CUSTOM_BAD_ID = "There is no ability with ID %d."
L.CUSTOM_EXISTS = "Already tracked: %s"
L.CUSTOM_ADDED = "Buff added: %s"
L.CUSTOM_REMOVED = "Buff removed: %s"
L.CUSTOM_NOT_FOUND = "No custom buff matches '%s' (see |cFFFF00/vigilant list|r)"
L.CUSTOM_TAG = "custom"

-- Chat commands
L.HELP_HEADER = "Commands (v%s):"
L.HELP = {
    "|cFFFF00/vigilant|r - show/hide the panel",
    "|cFFFF00/vigilant unlock|r / |cFFFF00lock|r - move and resize the panel / fix it in place",
    "|cFFFF00/vigilant grid|r / |cFFFF00summary|r - one row per member / one row per buff",
    "|cFFFF00/vigilant browse|r - catalog of every buff and proc, to track any of them",
    "|cFFFF00/vigilant add <name>|r - track a buff by its name",
    "|cFFFF00/vigilant remove <name or number>|r - stop tracking a custom buff",
    "|cFFFF00/vigilant list|r - list the tracked buffs",
    "|cFFFF00/vigilant reset|r - reset the uptime",
    "|cFFFF00/vigilant settings|r - open the settings",
}
L.USAGE_ADD = "Usage: /vigilant add <buff name>   (or open the catalog: /vigilant browse)"
L.USAGE_REMOVE = "Usage: /vigilant remove <name or number from /vigilant list>"
L.LOCKED = "Panel locked."
L.UNLOCKED = "Panel unlocked: drag it to move it, and drag its edges or the bottom-right corner to resize it."
L.UNIT_NOT_FOUND = "Unit '%s' does not exist (try player, group1, group2...)"
L.SCAN_HEADER = "%d buffs on %s:"
L.LIST_HEADER = "%d tracked buffs:"
L.CHECK_OK = "All IDs of the buff list are correct."
L.CHECK_BAD = "%d IDs no longer match the expected buff (in red above)."

-- Settings
L.SETTINGS_DESC = "Shows which buffs every group member has. Pick the common buffs below, or any other buff or proc from the catalog."
L.H_GENERAL = GetString(SI_GAMEPLAY_OPTIONS_GENERAL)
L.ACCOUNT_WIDE = "Same settings for all characters"
L.ACCOUNT_WIDE_TIP = "On: every character uses the account settings. Off: this character keeps its own (it starts with a copy of the account ones). Needs a UI reload."
L.SHOW_PANEL = "Show panel"
L.LOCK_PANEL = "Lock panel"
L.LOCK_TIP = "Unlocked, the panel is always visible and can be moved and resized. Locked, it follows the conditions below."
L.LAYOUT = "Layout"
L.LAYOUT_GRID = "Grid (one row per member)"
L.LAYOUT_SUMMARY = "Summary (one row per buff)"
L.LAYOUT_TIP = "Summary shows how many members have each buff (e.g. 6/8). Hover a row to see who is missing it."
L.ONLY_GROUP = "Only in a group"
L.ONLY_GROUP_TIP = "When solo the panel shows only you, which is handy to test it."
L.ONLY_COMBAT = "Only in combat"
L.RESET_POSITION = GetString(SI_INTERFACE_OPTIONS_FRAMERATE_LATENCY_POSITION_RESET)
L.H_LOOK = "Appearance"
L.NAME_WIDTH = "Name width"
L.BG_ALPHA = "Background opacity"
L.NAME_FORMAT = "Names"
L.NAME_CHARACTER = GetString(SI_GROUP_LIST_PANEL_NAME_HEADER)
L.NAME_ACCOUNT = "@Account"
L.SHOW_ROLES = "Show role icons"
L.SORT_ROLE = "Sort by role (%s, %s, %s)"
L.SHOW_TIMERS = "Show time left"
L.WARN_SECONDS = "Warn when less than (s)"
L.WARN_SECONDS_TIP = "The time left turns orange below this many seconds. 0 = never."
L.MISSING_STYLE = "Missing buffs"
L.MISSING_DIM = "Dimmed icon"
L.MISSING_RED = "Dimmed icon on red"
L.H_BUFFS = "Tracked buffs"
L.BUFFS_DESC = "Each buff counts no matter which skill or set gives it."
L.BUFFS_DEFAULT = "Recommended"
L.BUFFS_NONE = "None"
L.H_CUSTOM = "Other buffs and procs"
L.CUSTOM_DESC = "Open the catalog to search any buff or proc of the game by name and track it with one click. Tip: get the proc first and look in |cFFFF00Active now|r."
L.BROWSE_BUTTON = "Open catalog"
L.BROWSE_TIP = "Every buff and proc of the game, by category, with a search box."
L.CUSTOM_LIST = "Added from the catalog"
L.CUSTOM_NONE = "(none)"
L.CUSTOM_REMOVE = GetString(SI_DIALOG_REMOVE)
L.H_COMMANDS = "Chat commands"

-- Uptime (bottom bar)
L.UPTIME_TITLE = "Uptime in combat"
L.UPTIME_NONE = "No fight yet."
L.UPTIME_TIP_FIGHT = "Duration of the current or last fight. Below each buff, the share of that fight the group had it (only members in range count). Hover a percentage to see each member."
L.UPTIME_TIP_RUN = "Combat time of the whole run (every fight since you entered this zone). Below each buff, the share of that time the group had it (only members in range count). Hover a percentage to see each member."
L.UPTIME_SWITCH = "Click to count: %s"
L.UPTIME_RESET = "Reset uptime"
L.UPTIME_RESET_DONE = "Uptime reset."
L.UPTIME_SCOPE = "Uptime counts"
L.UPTIME_SCOPE_FIGHT = "Each fight"
L.UPTIME_SCOPE_RUN = "Whole run (until you change zone)"
L.UPTIME_SCOPE_TIP = "Each fight: it restarts when a fight starts. Whole run: it adds up every fight (only time in combat), e.g. a full dungeon or trial, and restarts when you change zone or press the reset button (circular arrow) of the bottom bar."
L.SHOW_UPTIME = "Show uptime in combat"
L.SHOW_UPTIME_TIP = "Bottom bar with the combat duration and the uptime of each buff. It only counts while you are in combat."

-- Buff order
L.ORDER_BUTTON = "Sort buffs"
L.ORDER_TIP = "Opens the catalog on the tracked buffs: use the arrows to change the order of the columns."
L.BROWSER_ORDER_HINT = "Use the arrows to change the order of the columns. X stops tracking a buff."
