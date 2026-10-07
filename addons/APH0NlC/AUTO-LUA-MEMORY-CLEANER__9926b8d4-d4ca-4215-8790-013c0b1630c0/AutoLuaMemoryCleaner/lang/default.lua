--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local function RegisterString(id, text)
	if _G[id] then
		SafeAddString(_G[id], text, 1)
	else
		ZO_CreateStringId(id, text)
		SafeAddVersion(_G[id], 1)
	end
end

local strings = {

	YES = "Yes",
	NO = "No",
	USE_DEFAULT = "Use Default",
	CUSTOMIZE = "Customize",
	LOW = "Low (%s)",
	HIGH = "High (%s)",
	SHORT = "Short (%s)",
	LONG = "Long (%s)",

	-- Setup wizard: welcome
	WELCOME_TITLE = "Welcome to Auto Lua Memory Cleaner!",
	WELCOME_BODY = "Run a quick first-time setup? A few short questions, then you're done. Everything here can be changed later in the settings menu or via /alc.",
	QUICK_SETUP = "Quick Setup",
	SKIP = "Skip",

	-- Setup wizard: simple yes/no questions
	CHATLOGS_BODY = "Log cleanups to chat?",
	CSA_BODY = "Show screen announcements when memory gets cleaned?",
	MEMORY_UI_BODY = "Show the on-screen memory display?",
	RENDER_MENUS_BODY = "Keep the memory UI visible while menus/inventory are open too?",
	POOL_CLEANUP_BODY = "Enable Auto Pool Cleanup After Travel (wayshrine, recall, etc.)?",

	-- Setup wizard: default-or-customize questions (%d/%g gets replaced with the actual default number)
	LUA_THRESHOLD_BODY = "Lua cleanup threshold: use the default (%d MB), or customize it?",
	LUA_THRESHOLD_CUSTOM_BODY = "Low or high Lua threshold?",
	POOL_THRESHOLD_BODY = "Pool cleanup threshold: use the default (%g MB), or customize it?",
	POOL_THRESHOLD_CUSTOM_BODY = "Low or high pool threshold?",
	LUA_DELAY_BODY = "Lua Cleanup Delay: use the default (300 sec / 5 min) before re-checking after a cleanup, or customize it?",
	LUA_DELAY_CUSTOM_BODY = "Short or long Lua Cleanup Delay?",
	POOL_DELAY_BODY = "Pool Cleanup Delay: use the default (2 seconds) before reloading after high pool usage, or customize it?",
	POOL_DELAY_CUSTOM_BODY = "Short or long Pool Cleanup Delay?",

	-- Wizard: closing chat message
	WIZARD_FINISH_MSG = "Setup complete. Adjust anytime under Cleanup Settings / UI Configuration, or /alcdelvars to start over.",

	-- Always-on-screen memory display / chat / CSA
	LABEL_LUA = "Lua",
	LABEL_POOL = "Pool",
	LABEL_COMBAT = "(Combat)",
	LABEL_ALREADY_CLEAN = "(Already Clean)",
	CSA_TITLE_CLEANED = "Memory Cleaned",
	CSA_TITLE_ALREADY_CLEAN = "Already Clean",
	CSA_TITLE_POOL_CLEARED = "Pool Cleaned",
	CSA_TITLE_POOL_STUCK = "Pool Needs a Game Restart",
	CHAT_POOL_RELOAD_STUCK = "The Pool did not shrink after the reload (%.1f MB), The game keeps this memory until the game is restarted, so ALC will not reload for the pool again until then.",
	CSA_TITLE_SETTINGS_UNAVAILABLE = "Settings Menu Unavailable",
	CHAT_UI_POSITION_RESET = "UI Position Reset.",
	CHAT_UI_SIZE_RESET = "UI Size Reset.",
	CHAT_WIPING_SETTINGS = "Wiping all settings...",
	CHAT_POOL_RELOAD_NOTICE = "Reloading in %.1f seconds to clear pool usage.",
	CHAT_SETTINGS_RESET_OLDVERSION = "Settings from an older, incompatible version detected - resetting to current defaults.",
	WORD_ON = "ON",
	WORD_OFF = "OFF",
	CHAT_RELOAD_TO_APPLY = "/reloadui to apply changes.",
	CHAT_SETTING_STATE = "%s: %s",
	CHAT_POOL_RELOAD_TOGGLE = "Auto Pool Cleanup After Travel: %s",
	CHAT_POOL_CONFIRM_TOGGLE = "Auto Pool Cleanup After Travel Confirmation: %s",
	CHAT_CLEANUP_MODE = "Cleanup Method: %s",
	CHAT_LIBWARN_TOGGLE = "Library Warning Messages: %s",
	MODULE_TOGGLE_UNLOADED = "Module unloaded: %s",
	MODULE_TOGGLE_REENABLED = "Module re-enabled: %s",
	MODULE_TOGGLE_LIVE = " - applied live.",
	MODULE_TOGGLE_RELOAD = ". /reloadui to apply.",
	DIALOG_MISSING_LIBRARY_TITLE = "ALC - Optional Dependency Alert",
	DIALOG_MISSING_LIBRARY_BODY = "For full functionality, please update or install and enable:",
	BTN_ACKNOWLEDGE_CLOSE = "Acknowledge / Close",
	LIBWARN_MISSING = "%s is not installed - Please Install %s %s - %s",
	LIBWARN_DISABLED = "%s is installed but not enabled - %s",
	LIBWARN_OLD = "%s (%s) is installed - not the recommended version but can be enabled - Please Update to %s - %s",
	LIBWARN_CONSEQUENCE_LAM = "the settings menu won't appear without it.",
	LIBWARN_CONSEQUENCE_LHAS = "the settings menu won't appear on console without it.",

	-- Client Info panel: field labels
	FIELD_INSTALLED_SINCE = "Installed Since:",
	FIELD_VERSION_HISTORY = "Version History:",
	FIELD_PLATFORM = "Platform:",
	FIELD_LIBRARY_VERSION = "Library Version:",
	FIELD_WIZARD = "Wizard:",
	FIELD_CURRENT_LANGUAGE = "Current Language:",
	FIELD_FILES = "Files:",
	FIELD_SETTINGS = "Settings:",
	INSTALL_DATE_UNKNOWN = "Unknown",

	-- Client Info panel: library version status
	NOT_FOUND = "Not Found",
	STATE_DISABLED = "(Disabled)",
	STATE_OLD = "(v%s - Old)",
	STATE_NEWER = "(v%s - Newer)",
	STATE_EXPECTED = "(Expected v%s)",

	-- Client Info panel: wizard/file status
	WIZARD_SETUP_DONE = "(Setup Done)",
	WIZARD_NOT_YET_RUN = "(Not Yet Run)",
	FILE_LOADED = "(Loaded)",
	FILE_UNLOADED_BY_USER = "(Unloaded)",

	-- Popup UI: Bug Report
	BTN_CLOSE = "Close",
	BUG_REPORT_COPY_TITLE = "COPY & PASTE THIS BUG REPORT",
	BUG_REPORT_COPY_PROMPT = "Copy this and paste it into your bug report:\n\n",
	BUG_REPORT_NONE_CAPTURED = "No %s errors have been captured yet this session.\n\n",
	BUG_REPORT_DESCRIBE_INSTEAD = "If you just saw an error message on screen, please describe what you were doing when it happened in the bug report instead.",

	-- Settings menu: section headers
	HEADER_CLEANUP_SETTINGS = "Cleanup Settings",
	HEADER_UI_CONFIG = "UI Configuration",
	HEADER_CLIENT_INFO = "Client Information",
	HEADER_ADVANCED_SETTINGS = "Advanced Settings",
	HEADER_MODULE_MANAGER = "Module Manager",
	HEADER_MODULE_FILE_STATUS = "Module File Status",
	LABEL_MODULE = "Module",
	BTN_RELOAD_UI = "Reload UI",
	COMMANDS_INFO_TITLE = "Commands Info",

	-- Settings menu: checkboxes
	CHK_AUTO_LUA_CLEANUP = "Auto Lua Cleanup",
	CHK_AUTO_POOL_CLEANUP = "Auto Pool Cleanup After Travel",
	CHK_AUTO_POOL_CLEANUP_CONFIRM = "Auto Pool Cleanup After Travel Confirmation",
	DD_CLEANUP_MODE = "Cleanup Method",
	MODE_AUTOMATIC = "Automatic (Recommended)",
	MODE_VANILLA = "Vanilla",
	MODE_BACKGROUND = "Background",
	MODE_AGGRESSIVE = "Aggressive",
	MODE_DEEP = "Deep Clean",
	MODE_FORCED = "Forced Cleanup",
	DESC_MODE_AUTOMATIC = "Picks the best method each time: Background outside menus, Deep Clean while a menu is open (Aggressive when a second pass would free almost nothing), Deep Clean on a console low-memory warning, and Vanilla when memory has barely grown since the last cleanup.",
	DESC_MODE_VANILLA = "Leave memory management to the game engine.",
	AUTO_PICKED = "Automatic: %s",
	CLEANED_BY = "Cleaned by %s",
	PICK_BACKGROUND = "Background",
	PICK_AGGRESSIVE = "Aggressive",
	PICK_DEEP = "Deep Clean",
	DESC_MODE_BACKGROUND = "Cleans up in small steps over several frames, which keeps memory spikes down without any stutter.",
	DESC_MODE_AGGRESSIVE = "Forces a single-pass cleanup. Clears ordinary dead memory at once, with a minor frame stutter.",
	DESC_MODE_DEEP = "Forces a double-pass cleanup. Reclaims the most memory from heavy data, but the game freezes for a moment.",
	CLEANUP_MODE_BODY = "Cleanup Method: Automatic (Recommended) picks the best method each time. Use it?",
	CLEANUP_MODE_CUSTOM_BODY = "Background cleans up in small steps over several frames, so it never stutters. Use it?",
	CLEANUP_MODE_MANUAL_BODY = "Vanilla leaves memory to the game engine. Forced Cleanup clears it all at once, which can stutter.",
	CLEANUP_MODE_FORCED_BODY = "Aggressive runs one pass with a minor stutter. Deep Clean runs two and freezes the game for a moment.",
	DLG_POOL_RELOAD_CONFIRM_TITLE = "Reload UI to Clear Memory Pool?",
	DLG_POOL_RELOAD_CONFIRM_BODY = "Your memory pool usage is high. Reload UI now to clear it?",
	BTN_CONFIRM = "Confirm",
	BTN_SKIP = "Skip",
	CHK_CSA = "Center Screen Announcements",
	CHK_LIB_WARNING_ENABLED = "Library Warning Messages",
	CHK_SHOW_UI = "Show UI",
	CHK_RENDER_IN_MENUS = "Render UI in Menus",
	CHK_LOCK_UI = "Lock UI Position",
	SLIDER_UI_SCALE = "UI Scale",
	CHK_CHAT_LOGS = "Chat Logs",

	-- Settings menu: sliders
	SLIDER_LUA_DELAY = "Lua Cleanup Delay (Seconds)",
	SLIDER_POOL_DELAY = "Pool Cleanup Delay (Seconds)",
	SLIDER_PC_LUA_THRESHOLD = "PC Lua Threshold (MB)",
	SLIDER_PC_POOL_THRESHOLD = "PC Pool Threshold (MB)",
	SLIDER_CONSOLE_LUA_THRESHOLD = "Console Lua Threshold (MB)",
	SLIDER_CONSOLE_POOL_THRESHOLD = "Console Pool Threshold (MB)",

	-- Settings menu: buttons and their tooltips
	MENU_COMMANDS_INFO = "COMMANDS INFO",
	MENU_MANUAL_CLEANUP = "MANUAL CLEANUP",
	MENU_MAIL = "Mail",
	MENU_RUN_WIZARD = "SETUP WIZARD",
	MENU_RESET_DEFAULTS = "RESET TO DEFAULTS",
	WARN_RESET_DEFAULTS = "Puts every setting on this panel back to its default.",
	WARN_RESET_UI_POSITION = "Moves the window back to where it starts.",
	WARN_RESET_UI_SIZE = "Puts the window back to its starting size and scale.",
	MENU_BUG_REPORT = "BUG REPORT",
	MENU_MOVE_UI = "Move UI (Right Stick)",
	MENU_RESET_UI_POSITION = "RESET UI POSITION",
	MENU_RESET_UI_SIZE = "RESET UI SIZE",
	MENU_CHANGE_MODE = "Change Mode",
	MODE_PC = "PC",
	MODE_CONSOLE = "Console",

	-- Commands Info: category titles
	CAT_CLEANUP = "Cleanup",
	CAT_MEMORY_UI = "Memory UI",
	CAT_GENERAL = "General",
	CAT_MODULE_MANAGER = "Module Manager",

	-- Commands Info: per-command descriptions
	CMD_ALCON = "Toggle Auto Lua Cleanup",
	CMD_ALCCLEAN = "Force manual Lua cleanup",
	CMD_ALCPOOLRELOAD = "Toggle Auto Pool Cleanup After Travel",
	CMD_ALCPOOLCONFIRM = "Toggle Auto Pool Cleanup After Travel Confirmation",
	CMD_ALCCLEANUPMODE = "Switch the Cleanup Method",
	CMD_ALCBUGREPORT = "Open the bug report copy box",
	CMD_ALCUI = "Toggle UI",
	CMD_ALCLOCK = "Lock/Unlock UI",
	CMD_ALCRESET = "Reset UI Position",
	CMD_ALCCSA = "Toggle Center Screen Announcements",
	CMD_ALCLOGS = "Toggle Chat Logs",
	CMD_ALCWIZARD = "Re-run Setup Wizard",
	CMD_ALCLIBWARN = "Toggle Library Warning Messages",
	CMD_ALCDELVARS = "Reset ALL settings to defaults",
	CMD_ALCUNLOADWIZARD = "Toggle unload Wizard module",
	CMD_ALCUNLOADMENU = "Toggle unload Menu module",
	CMD_ALCUNLOADMIGRATION = "Toggle unload Migration module",
}

for key, text in pairs(strings) do
	RegisterString("SI_ALC_" .. key, text)
end
