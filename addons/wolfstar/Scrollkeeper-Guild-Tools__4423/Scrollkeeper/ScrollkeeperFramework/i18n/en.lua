Scrollkeeper = Scrollkeeper or {}
Scrollkeeper.Localization = Scrollkeeper.Localization or {}

--------------------------------------------------------------------------------
-- FRAMEWORK CORE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperFramework"] = {
  FRAMEWORK_LOADED = "Scrollkeeper Framework loaded successfully",
  CRITICAL_ERROR = "CRITICAL ERROR: Could not create settings panel!",
  ERROR_REGISTERING = "ERROR registering settings",
  LAM2_UNAVAILABLE = "LibAddonMenu2 not available!",
  ALREADY_INITIALIZED = "Already initialized, skipping...",
  CHAT_BUTTONS_DISABLED = "LibChatMenuButton not available - chat buttons disabled",
  HEADER_DESC = "Core framework for Scrollkeeper Guild Tools with enhanced library integrations. Individual modules have their own settings and do not require reload.",
  DONATE_BUTTON = "Support Development",
  DONATE_TOOLTIP = "Send a donation to @WolfStar07 on PC/NA to support continued development",
  OPEN_ALL_WINDOWS = "Open All Scrollkeeper Windows",
  OPEN_SETTINGS = "Open Scrollkeeper Settings",
  DISPLAY_NAME = "|cF5DA81Scrollkeeper Guild Tools|r",
}

--------------------------------------------------------------------------------
-- COLOR THEMES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperColorThemes"] = {
  -- Main
  SUBMENU_NAME = "Color Themes",
  DESCRIPTION = "Choose from pre-defined color themes for Scrollkeeper's interface elements.",
  ACTIVE_THEME = "Active Theme",
  ACTIVE_THEME_TOOLTIP = "Select which color theme to apply to Scrollkeeper interface elements.",
  CURRENT_THEME = "Current theme: %s",
  
  -- Preview Section (for future use)
  PREVIEW_HEADER = "Color Preview:",
  BORDER_COLOR = "Border Color",
  BORDER_DESC = "Window borders and edges",
  HEADER_COLOR = "Header Color",
  HEADER_DESC = "Title bars and column headers",
  TEXT_COLOR = "Text Color", 
  TEXT_DESC = "Primary text and labels",
  ACCENT_COLOR = "Accent Color",
  ACCENT_DESC = "Highlighted buttons and selections",
  NOTE = "Note: Theme changes apply immediately to all open Scrollkeeper windows.",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperColorThemes]|r ERROR: ScrollkeeperFramework missing!",
  
  -- Theme Names
  THEME_EMBER = "Ember",
  THEME_FORGE = "Forge",
  THEME_OCEAN = "Ocean",
  THEME_SKY = "Sky",
  THEME_REGALIA = "Regalia",
  THEME_BRIAR = "Briar",
  THEME_JUNGLE = "Jungle",
  
  -- Status Messages
  STATUS_UNKNOWN = "Unknown",
}

--------------------------------------------------------------------------------
-- PROVISIONAL MEMBER TRACKING
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperProvisionMember"] = {
  SUBMENU_NAME = "Provisional Member Tracking",
  DESCRIPTION = "Track guild members in probationary ranks and those not meeting donation requirements. Use |cFFD700/sgtprovision|r to open the management window.",
  MASTER_ENABLE = "Enable Provisional Member Tracking (Master)",
  MASTER_ENABLE_TIP = "Master toggle for all provisional member tracking features.",
  OPEN_ADMIN = "Open Admin Window",
  OPEN_ADMIN_TIP = "Open the provisional member management window",
  CLEAR_SCAN = "Clear Bad Data & Scan",
  CLEAR_SCAN_TIP = "Clear incorrectly tracked members and scan for new ones",
  RESET_GOLD = "Reset Gold Removals",
  RESET_GOLD_TIP = "Clear all gold-based removal flags, allowing members to be re-evaluated for gold tracking",
  STATUS_TRACKING = "Currently tracking: %d active provisional members",
  STATUS_RANK_REMOVED = "Permanently removed (rank): %d members",
  STATUS_GOLD_REMOVED = "Temporarily removed (gold): %d members",
  WINDOW_OPENED_MESSAGE = "Window opened. Use the |cFFFFFFScan|r button to check for members needing tracking.",
  
  -- Window UI
  WINDOW_TITLE = "Provisional Member Management",
  SELECT_GUILD = "Select Guild:",
  FILTER_LABEL = "Filter:",
  MEMBER_NAME = "Member Name",
  DAYS = "Days",
  STATUS = "Status",
  NOTES = "Notes",
  ACTIONS = "Actions",
  
  -- Guild Settings
  ENABLE_FOR_GUILD = "Enable for %s",
  ENABLE_FOR_GUILD_TIP = "Enable provisional member tracking for this guild.",
  AUTO_TAG = "Auto-Tag New Members",
  AUTO_TAG_TIP = "Automatically tag members meeting tracking criteria.",
  NOTIFY_JOIN = "Notify When Members Join",
  NOTIFY_JOIN_TIP = "Show notifications for new members in this guild.",
  PROBATION_DAYS = "Probationary Period (Days)",
  PROBATION_DAYS_TIP = "How many days members remain in probationary status before promotion.",
  
  -- Gold Tracking
  GOLD_HEADER = "Gold Requirements Tracking",
  INACTIVITY_HEADER = "Inactivity Tracking",
  DONOR_HEADER = "Donor Recognition",
  GOLD_ENABLE = "Enable Gold Donation Filter",
  GOLD_ENABLE_TIP = "Track members who haven't met donation requirements.",
  GOLD_AMOUNT = "Required Donation Amount",
  GOLD_AMOUNT_TIP = "Amount of gold members must donate in the time period (e.g., 5000 for 5k dues).",
  GOLD_PERIOD = "Time Period (Days)",
  GOLD_PERIOD_TIP = "Number of days to check for donations (e.g., 30 for monthly dues, 7 for weekly).",
  STATUS_PENDING_DONATION = "Pending Donation",
  SOURCE_MANUAL = "Manual",
  TIP_DAYS_MANUAL = "^ = Manual donation entry",
  
  -- Statistics
  GUILD_STATS = "Guild Statistics",
  NO_MEMBERS = "No provisional members currently tracked for this guild",
  STATS_FORMAT = "Tracking %d members: %d active, %d overdue, %d promoted",
  RECENT_ADDITIONS = "Recent additions (last 7 days): %d",
  
  -- Integration Status
  INTEGRATION_HEADER = "Join Time Data Sources & Integration",
  AMT_AVAILABLE = "Advanced Member Tooltip - Most accurate join times available",
  AMT_UNAVAILABLE = "Advanced Member Tooltip - Not installed",
  AMT_INSTALL = "Install from: esoui.com/downloads/info2351",
  AMT_DESC = "Provides most accurate guild join time tracking",
  LH_READY = "LibHistoire - Ready and processing guild history",
  LH_MISSING = "LibHistoire - Not found (required dependency)",
  DATA_AVAILABLE = "Data Module - Gold donation tracking enabled",
  DATA_UNAVAILABLE = "Data Module - Gold filtering unavailable",
  
  -- Symbol Legend
  SYMBOL_LEGEND = "Days Column Symbols:",
  SYMBOL_AMT = "* = AMT data (most accurate)",
  SYMBOL_HISTOIRE = "~ = LibHistoire guild history",
  SYMBOL_DONATION = "? = First donation estimate",
  SYMBOL_TAGGED = "! = Tracking start time",
  SYMBOL_VALIDATED = "(no symbol) = Validated stored data",
  SYMBOL_UNKNOWN = "UNK = Unknown/unreliable source",
  SYMBOL_FOOTER = "Hover over any days value for detailed source information.",
  TIP_SORT_NAME = "Click to sort by name",
  TIP_SORT_DAYS = "Click to sort by days since join",

  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "[ScrollkeeperProvisionMember] ERROR: Framework missing!",
  ERROR_NO_GUILD_SELECTED = "No guild selected",
  ERROR_MAIL_UNAVAILABLE = "ScrollkeeperNotebookMail not available",
  ERROR_NO_MEMBERS_TO_MAIL = "No members to mail",
  ERROR_MAIL_WINDOW_FAILED = "Failed to access mail window",
  ERROR_SETTINGS_UNAVAILABLE = "Settings unavailable",
  ERROR_NO_GUILDS = "No guilds available. Join a guild to configure per-guild settings.",
 
  -- Success Messages
  SUCCESS_AMT_DETECTED = "Advanced Member Tooltip detected - enhanced tracking enabled",
  SUCCESS_HISTOIRE_READY = "LibHistoire integration ready - accurate join times available",
  SUCCESS_REMOVED = "Removed %s from tracking",
  SUCCESS_BULK_REMOVED = "Bulk removed %d members from tracking",
  SUCCESS_CLEARED_DATA = "Cleared tracking data for %s",
  SUCCESS_CLEARED_GOLD = "Cleared %d gold-based removal flags",
  SUCCESS_MAIL_OPENED = "Mail window opened with %d provisional members from %s",

  -- Status Messages
  STATUS_DISABLED = "Provision tracking is disabled",
  STATUS_NO_DATA = "No data available",
  STATUS_NO_TRACKING = "No tracking data available",
  STATUS_SELECT_GUILD = "Select a guild to view statistics",
  STATUS_NO_FILTER_MATCH = "No members match the current filter criteria.",
  STATUS_NO_SELECTED = "No members selected for promotion",
  STATUS_NO_SELECTED_REMOVE = "No members selected for removal",
  
  -- Notes column - color coding descriptions (for tooltip if needed)
  NOTES_COLOR_DONATION = "Green: Donation information",
  NOTES_COLOR_OFFLINE = "Orange: Offline information",
  NOTES_COLOR_NO_DONATION = "Red: No donations found",

  -- Button Labels
  BTN_REFRESH = "Refresh",
  BTN_REFRESH_TIP = "Refresh guild data and member list",
  BTN_EXPORT = "Export",
  BTN_EXPORT_TIP = "Export member data to copyable text window",
  BTN_SCAN = "Scan",
  BTN_SCAN_TIP = "Scan guild rosters for new provisional members",
  BTN_VIEW_SELECTED = "View Selected",
  BTN_VIEW_ALL = "View All",
  BTN_VIEW_SELECTED_TIP = "Toggle between viewing all members and only selected members",
  BTN_PROMOTE_ALL = "Promote All",
  BTN_PROMOTE_ALL_TIP = "Open guild roster to promote highlighted members.",
  BTN_REMOVE_ALL = "Remove All",
  BTN_REMOVE_ALL_TIP = "Remove all selected members from tracking",
  BTN_MAIL_SELECTED = "Mail Selected",
  BTN_MAIL_SELECTED_TIP_HIGHLIGHTED = "Open mail window with selected members (%d)",
  BTN_MAIL_SELECTED_TIP_FILTERED = "Open mail window with filtered members",
  BTN_SELECT_ALL = "Select All",
  BTN_CLOSE = "Close",

  -- Filter Labels
  FILTER_ALL = "ALL",
  FILTER_PROBATION_ICON_TIP = "Filter by probation members",
  FILTER_GOLD_ICON_TIP = "Filter by low gold donation members",
  STATUS_INACTIVE = "Inactive",
  STATUS_DONOR = "Active Donor",

  -- Export Window
  EXPORT_TITLE = "Export Data - Select and Copy Text",
  EXPORT_INSTRUCTION = "Click 'Select All' then use Ctrl+C to copy to clipboard",
  EXPORT_REPORT_HEADER = "Provisional Members Report for %s",
  EXPORT_GENERATED = "Generated: %s",
  EXPORT_FILTER = "Filter: %s",
  EXPORT_VIEW_SELECTED = "View: Selected Members Only",
  EXPORT_FILTER_ALL = "All Members",
  EXPORT_FILTER_RANK = "Probation Members",
  EXPORT_FILTER_GOLD = "Gold Donation Members",
  EXPORT_FILTER_CUSTOM = "Filtered Members",
  EXPORT_FORMAT = "%s | Status: %s | Days in guild: %s | Reason: %s | Notes: %s",
  EXPORT_DAYS_NA = "N/A (gold filter)",
  EXPORT_DAYS_FORMAT = "%d (%s)",
  EXPORT_DAYS_ACTUAL = "actual",
  EXPORT_DAYS_ESTIMATED = "estimated",
  EXPORT_FILTER_INACTIVE = "Inactive Members",
  EXPORT_FILTER_DONOR = "Active Donors",

  -- Tooltips
  TIP_OPEN_ROSTER = "Open guild roster for %s",
  TIP_REMOVE = "Remove %s from tracking",
  TIP_DAYS_HEADER = "Days since joining guild\n\n",
  TIP_DAYS_OFFLINE_HEADER = "Days Offline",
  TIP_DAYS_OFFLINE_DESC = "Shows how many days this member has been offline.\nHigher numbers indicate longer inactivity.",
  TIP_DAYS_AMT = "* = Advanced Member Tooltip (most accurate)",
  TIP_DAYS_HISTOIRE = "~ = LibHistoire guild history",
  TIP_DAYS_DONATION = "? = First donation estimate",
  TIP_DAYS_TAGGED = "! = Tracking start time",
  TIP_DAYS_UNKNOWN = "(Unknown - no reliable data source)",
  TIP_DAYS_GOLD = "(Gold filter member)",
  TIP_DAYS_VALIDATED = "(Validated from stored data)",
  TIP_INSTALL_AMT = "Install Advanced Member Tooltip\nfor most accurate join times",
  TIP_REVIEW_KICK = "Open roster to review/kick %s (inactive member)",
  TIP_REVIEW_PROMOTE = "Open roster to review/kick %s (probationary member)",
  TIP_REVIEW_DONATION = "Open roster to review %s (pending donation)",
  TIP_PROMOTE_DONOR = "Open roster to promote %s (valued contributor)",
  FILTER_INACTIVE_TIP = "Show members who have been offline for the configured period",
  FILTER_DONOR_TIP = "Show members who meet minimum donation requirements",

  -- Logging Messages
  LOG_STARTING_SCAN = "Starting manual scan...",
  LOG_SCAN_COMPLETE = "Manual scan complete - cleared %d bad entries, found %d new members",
  LOG_REFRESHED = "Display refreshed",
  LOG_NEW_MEMBER = "New member joined %s: %s",
  LOG_OPENING_ROSTER_PROMOTE = "Opening roster to promote: %s",
  LOG_OPENING_ROSTER_BULK = "Opening roster - promote these %d members: %s",
  LOG_NO_GUILD_ID = "Could not find guild ID for: %s",
  LOG_NO_GUILD_ID_SIMPLE = "Could not find guild ID",
  LOG_FILTER_MODE = "%s mode - %d members selected",
  LOG_INITIALIZING = "Initializing - %s",
  ERROR_DATA_NOT_READY = "Guild history data not ready yet. Wait a moment and try again.",
  LOG_SCAN_COMPLETE_SHORT = "Scan complete!",

  -- Mail Integration
  MAIL_SUBJECT_GOLD = "Guild Dues Reminder - %s",
  MAIL_RECIPIENT_COUNT = "Provisional Recipients: %d",
  MAIL_STATUS = "Status: %d provisional members ready to mail",

  -- Stats Display
  STATS_FORMAT_FULL = "Guild: %s | Total: %d | Active: %d | Overdue: %d | Promoted: %d | Probation: %d | Gold: %d",
  STATS_LH_READY = "ready",
  STATS_LH_LOADING = "loading",

  -- Auto-tag Messages
  AUTO_TAG_SCAN = "Auto-tagged (scan)",
  AUTO_TAG_LOGIN = "Auto-tagged (login scan)",
  AUTO_TAG_ONLINE = "Auto-tagged (joined online)",
  ACTIVE_DONOR = "Active Donor",

  -- Dropdown Messages
  DROPDOWN_NO_GUILDS = "No guilds configured for tracking",

  -- Status Values
  STATUS_PROVISIONAL = "provisional",
  STATUS_PROMOTED = "promoted",

  -- Reason Values
  REASON_RANK = "rank",
  REASON_GOLD = "gold",
  REASON_INACTIVE = "Inactive",
  REASON_DONOR = "Donor",
  
  -- Integration Status (detailed)
  INTEGRATION_AMT_INSTALL_URL = "esoui.com/downloads/info2351",
  INTEGRATION_STATUS = "Status of integrated addons and data sources:",

  -- Member Count Status
  MEMBER_COUNT_STATUS = "Member Count Status",
  MEMBER_COUNT_FORMAT = "Currently tracking: %d active provisional members\nPermanently removed (rank): %d members\nTemporarily removed (gold): %d members",

  -- Sources
  SOURCE_AMT = "amt",
  SOURCE_HISTOIRE = "histoire",
  SOURCE_DONATION = "donation",
  SOURCE_TAGGED = "tagged",
  SOURCE_STORED = "stored",
  SOURCE_UNKNOWN = "unknown",
  SOURCE_DATA = "data",

  -- Days display values
  DAYS_UNKNOWN = "UNK",
  DAYS_ERROR = "ERR",
  DAYS_NA = "-",

  -- Inactivity Filter Settings
  INACTIVITY_ENABLE = "Track Inactive Members",
  INACTIVITY_ENABLE_TIP = "Automatically track members who have been offline for an extended period",
  INACTIVITY_DAYS = "Inactive After (Days)",
  INACTIVITY_DAYS_TIP = "Consider a member inactive if they haven't logged in for this many days",

  -- Settings - Donor Filter
  DONOR_ENABLE = "Track Active Donors",
  DONOR_ENABLE_TIP = "Track members who meet or exceed minimum donation requirements (useful for recognizing contributors)",
  DONOR_AMOUNT = "Minimum Donation Amount",
  DONOR_AMOUNT_TIP = "Gold amount required to be considered an active donor",
  DONOR_PERIOD = "Time Period (Days)",
  DONOR_PERIOD_TIP = "Check donations within the last X days",
  MANUAL_SCAN_NOTE = "Note: Member tracking requires manual scanning. Open the Provisional Member window and click the Scan button to check for members needing tracking.",
}

-------------------------------------------------------------------------------
-- GUILD MAIL
-------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebookMail"] = {
  SUBMENU_NAME = "Guild Mail",
  DESCRIPTION = "Bulk mail composition with template integration. Mail sends are automatically throttled at 3.1 seconds between messages. Use |cFFD700/sgtmail|r to open the mail window.",
  ENABLE_MAIL = "Enable Guild Mail",
  ENABLE_MAIL_TIP = "Toggle the Guild Mail feature on or off.",
  OPEN_MAIL = "Open Mail Window",
  OPEN_MAIL_TIP = "Click to open the mail composition window.",
  
  -- Window UI
  WINDOW_TITLE = "Scrollkeeper Guild Mail",
  MAIL_TEMPLATES = "Mail Templates:",
  SELECT_TEMPLATE = "-- Select Template --",
  GUILD_LABEL = "Guild:",
  RANK_FILTER = "Rank Filter:",
  ALL_RANKS = "All Ranks",
  PROVISIONAL_LABEL = "Provisional Members:",
  ALL_PROVISIONAL = "All Provisional",
  GOLD_ONLY = "Gold Filter Only",
  RANK_ONLY = "Rank Filter Only",
  USE_PROVISIONAL = "Use Provisional List",
  KICK_AFTER_MAIL = "Remove After Mailing:",
  KICK_NO = "Don't Remove",
  KICK_YES = "Remove After Mail",
  KICK_NO_PERMISSION = "You don't have permission to remove members from this guild",
  MEMBER_KICKED = "Kicked: %s",
  MEMBER_NOT_FOUND = "Could not find member %s in guild roster",
  PREVIEW_TITLE = "Mail Preview",
  PREVIEW_MAIL = "Preview",
  
  -- Composition
  SUBJECT_LABEL = "Subject:",
  BODY_LABEL = "Message Body:",
  READY_TO_SEND = "Ready to send",
  STATUS_READY = "Status: Ready",
  RECIPIENTS = "Recipients: %d",
  
  -- Buttons
  SAVE_TEMPLATE = "Save Template",
  PREVIEW_RECIPIENTS = "Preview Recipients",
  SEND_MAIL = "Send Mail",
  PAUSE = "Pause",
  RESUME = "Resume",
  
  -- Status Messages
  NO_GUILD = "Status: Please select a guild first",
  NO_SUBJECT = "Status: Please enter a subject",
  NO_BODY = "Status: Please enter a message body",
  NO_RECIPIENTS = "Status: No recipients found",
  STARTING = "Status: Starting mail send...",
  SENDING = "Sending %d/%d",
  SENDING_TO = "To: %s",
  SUCCESS = "Status: Mail sent successfully",
  FAILED = "Status: Failed - %s",
  PAUSED = "Status: Paused",
  COMPLETED = "Completed: %d sent, %d failed",
  TEMPLATE_SAVED = "Status: Template saved",
  TEMPLATE_FAILED = "Status: Failed to save template",
  NEED_SUBJECT_BODY = "Status: Please enter subject and body",
  RECIPIENTS_FOUND = "Status: %d recipients found",
  NO_MATCH_FILTERS = "Status: No recipients match filters",
  PROVISIONAL_SELECTED = "Status: %d provisional members selected",
  NO_PROVISIONAL = "Status: No provisional members found",
  USING_PROVISIONAL = "Status: Using provisional member list...",
  
  -- Failure Reasons
  RECIPIENT_NOT_FOUND = "Recipient not found",
  MAILBOX_FULL = "Mailbox full",
  IGNORED = "Recipient ignoring mail",
  BLANK_MAIL = "Blank mail not allowed",
  UNKNOWN_ERROR = "Unknown error",

  -- Character count display (used in the count labels)
  CHAR_COUNT = "%d/%d",  -- for "0/100" and "0/700" displays

  -- Provisional member filter type display
  PROVISION_FILTER_ALL = "all",
  PROVISION_FILTER_GOLD = "gold", 
  PROVISION_FILTER_RANK = "rank",

  -- Auto-generated subject for gold filter
  DUES_REMINDER_SUBJECT = "Guild Dues Reminder - %s",

  -- Failure log content (these are for the saved notebook entry)
  FAILURE_LOG_TITLE = "Mail Send Failure Report",
  FAILURE_LOG_DATE = "Date: %s",
  FAILURE_LOG_SUBJECT_LINE = "Subject: %s",
  FAILURE_LOG_TOTAL_SENT = "Total Sent: %d",
  FAILURE_LOG_TOTAL_FAILED = "Total Failed: %d",
  FAILURE_LOG_FAILED_LIST = "Failed Recipients:",
  FAILURE_LOG_SEPARATOR = string.rep("-", 50),
  FAILURE_LOG_BODY_HEADER = "Original Message Body:",
  FAILURE_LOG_SAVED = "Failure log saved to Notebook: '%s'",
  FAILURE_LOG_SAVE_FAILED = "Failed to save failure log to Notebook",
  FAILURE_LOG_NO_NOTEBOOK = "Cannot save failure log - Notebook not available",
    
  -- Tags
  TAG_MAIL = "mail",
  TAG_TEMPLATE = "template",
  TAG_MAIL_LOG = "mail-log",
  TAG_FAILURES = "failures",
  
  -- Failure log title format
  FAILURE_LOG_TITLE_FORMAT = "Mail Failures - %s",  -- %s will be date/time
}

--------------------------------------------------------------------------------
-- NOTEBOOK
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebook"] = {
  -- Main
  SUBMENU_NAME = "Notebook Settings",
  WINDOW_TITLE = "Scrollkeeper Notebook",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperNotebook]|r ERROR: ScrollkeeperFramework missing!",
  ERROR_ALREADY_INIT = "|cFFD700[ScrollkeeperNotebook]|r Already initialized, skipping...",
  ERROR_WINDOW_EXISTS = "|cFFD700[ScrollkeeperNotebook]|r Window already exists, returning existing",
  ERROR_DROPDOWN_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Warning: Could not create dropdown",
  ERROR_WINDOW_NOT_INIT = "Notebook window not initialized.",
  ERROR_NO_NOTE_ENTRY = "There is no note entry for %s.",
  ERROR_DISABLED = "|cFFD700[ScrollkeeperNotebook]|r Notebook is disabled",
  ERROR_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Please enter a title for the note",
  ERROR_SAVE_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Failed to save note",
  ERROR_TEMPLATE_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Please enter a title for the template",
  
  -- Success Messages
  SUCCESS_NOTE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Note saved: %s",
  SUCCESS_TEMPLATE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Mail template saved: %s",
  
  -- Window Labels
  LABEL_SEARCH = "Search:",
  LABEL_CATEGORY = "Category:",
  LABEL_SAVED_NOTES = "Saved Notes:",
  LABEL_NOTE_TITLE = "Note Title:",
  LABEL_TAGS = "Tags (comma separated):",
  LABEL_NOTE_CONTENT = "Note Content:",
  LABEL_NOTES_COUNT = "Notes: %d/%d",
  LABEL_NOTES_SIMPLE = "Notes: %d",
  
  -- Character Counts
  CHAR_COUNT_TITLE = "%d/100",
  CHAR_COUNT_BODY = "%d/5000",
  
  -- Dropdown Options
  DROPDOWN_SELECT = "-- Select Note --",
  DROPDOWN_NO_MATCHES = "-- No matches found --",
  
  -- Default Text
  DEFAULT_NOTE_TITLE = "New Note",
  DEFAULT_NOTE_BODY = "Enter your note here...",
  
  -- Button Labels
  BTN_SAVE = "Save",
  BTN_NEW = "New",
  BTN_DELETE = "Delete",
  BTN_SAVE_MAIL = "Save Mail",
  BTN_OPEN_NOTEBOOK = "Open Notebook",
  
  -- Button Tooltips
  TIP_OPEN_NOTEBOOK = "Click to open the notebook window (same as /sgtnote command).",
  
  -- Settings
  SETTING_ENABLE = "Enable Notebook Module",
  SETTING_ENABLE_TIP = "Toggle the Notebook feature on/off.",
  SETTING_SEARCH = "Enable Search Filter",
  SETTING_SEARCH_TIP = "Allow filtering notes by search terms.",
  SETTING_DEFAULT_CATEGORY = "Default Category",
  SETTING_DEFAULT_CATEGORY_TIP = "Default category for new notes. Use 'Mail' for mail templates.",
  
  -- Descriptions
  DESC_MAIN = "A full-featured in-game notepad with search, categories, and tagging.\nUse |cFFD700/sgtnote|r to open the notebook window.",
  DESC_MAIL_TEMPLATES = "Mail templates: Save notes in the 'Mail' category to use them as templates in both the native mail client and the guild mail system.",
  
  -- Mail Integration
  MAIL_LABEL_TEMPLATES = "Mail Templates:",
  MAIL_DROPDOWN_SELECT = "-- Select Template --",
  
  -- Categories
  CAT_GENERAL = "General",
  CAT_MAIL = "Mail",
  CAT_EVENTS = "Events",
  CAT_ALL_CATEGORIES = "All Categories",
  
  ERROR_MAX_TOTAL_NOTES = "Cannot create note: Maximum total notes (%d) reached. Delete some notes first.",
  ERROR_MAX_CATEGORY_NOTES = "Cannot create note: Maximum notes (%d) for category '%s' reached.",
  ERROR_NOTE_TOO_LARGE = "Note is too large (%d characters). Maximum is %d characters.",
  STATS_HEADER = "Scrollkeeper Notebook Storage Statistics",
  STATS_TOTAL = "Total Notes: %d / %d",
  STATS_CATEGORY = "  %s: %d / %d notes (~%.1f KB)",
  BTN_PREVIEW_MAIL = "Preview",
  PREVIEW_TITLE = "Mail Preview",
  ERROR_NO_BODY = "Please enter some text in the body",
  
  -- Guild Tools Integration
  GUILDMAIL_NO_TEMPLATES    = "(Use 'Save Mail' in Notebook to add templates)",
  SETTING_GUILDMAIL_INJECT  = "Show Template Dropdown in Guild Mail",
  SETTING_GUILDMAIL_INJECT_TIP = "Show a Notebook mail-template selector in the guild tools mail compose window.",
}

--------------------------------------------------------------------------------
-- HISTORY
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperHistory"] = {
  -- Main
  SUBMENU_NAME = "Guild History Search",
  WINDOW_TITLE = "Guild History Search",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperHistory]|r ERROR: ScrollkeeperFramework missing!",
  ERROR_WINDOW_FAILED = "|cFFD700[ScrollkeeperHistory]|r Failed to create window",
  ERROR_NO_EXPORT = "|cFFD700[ScrollkeeperHistory]|r No events to export",
  
  -- Success Messages
  SUCCESS_READY = "|cFFD700[ScrollkeeperHistory]|r Ready - use /sgthistory",
  
  -- Log Messages
  LOG_LOADING = "|cFFD700[ScrollkeeperHistory]|r Loading... SF.Data exists: %s",
  LOG_DATA_GETEVENTS = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents at load: %s",
  LOG_DATA_UNAVAILABLE = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents not available",
  LOG_FALLBACK_INIT = "|cFFD700[ScrollkeeperHistory]|r Fallback initialization triggered",
  
  -- Window Labels
  LABEL_GUILD = "Guild:",
  LABEL_CATEGORY = "Category:",
  LABEL_SEARCH = "Search:",
  LABEL_EVENTS_COUNT = "Events: %d",
  LABEL_REFRESH = "Refresh",
  LABEL_EXPORT = "Export",
  
  -- Status Messages
  STATUS_READY = "Ready",
  STATUS_READY_LOADED = "Ready - %d events loaded",
  STATUS_NO_GUILD = "No guild selected",
  STATUS_DATA_NOT_READY = "Data module not ready",
  STATUS_NO_EVENTS_CACHE = "No events found - cache may still be building. Ensure the category is active in Libhistoire.",
  STATUS_WAITING_LH = "Waiting for LibHistoire to initialize...",
  STATUS_ENABLE_GUILDS = "Enable guilds in History settings",
  
  -- Column Headers
  HEADER_TIME = "Time",
  HEADER_CATEGORY = "Category",
  HEADER_EVENT = "Event",
  HEADER_MEMBER = "Member",
  HEADER_DETAILS = "Details",
  
  -- Category Names
  CAT_ALL = "All Events",
  CAT_ROSTER = "Roster",
  CAT_BANK_GOLD = "Bank Gold",
  CAT_BANK_ITEMS = "Bank Items",
  CAT_SALES = "Sales",
  
  -- Event Type Names - Roster
  EVENT_INVITED = "Invited",
  EVENT_JOINED = "Joined",
  EVENT_PROMOTED = "Promoted",
  EVENT_DEMOTED = "Demoted",
  EVENT_LEFT = "Left",
  EVENT_KICKED = "Kicked",
  EVENT_APP_ACCEPTED = "Application Accepted",
  
  -- Event Type Names - Bank Gold
  EVENT_GOLD_DEPOSITED = "Gold Deposited",
  EVENT_GOLD_WITHDRAWN = "Gold Withdrawn",
  EVENT_TRADER_BID = "Trader Bid",
  EVENT_BID_RETURNED = "Bid Returned",
  
  -- Event Type Names - Bank Items
  EVENT_ITEM_DEPOSITED = "Item Deposited",
  EVENT_ITEM_WITHDRAWN = "Item Withdrawn",
  
  -- Event Type Names - Sales
  EVENT_ITEM_SOLD = "Item Sold",
  
  -- Unknown Event
  EVENT_UNKNOWN = "Unknown (%s)",
  
  -- Time Formatting
  TIME_JUST_NOW = "Just now",
  TIME_MINUTES_AGO = "%dm ago",
  TIME_HOURS_AGO = "%dh ago",
  TIME_DAYS_AGO = "%dd ago",
  TIME_MONTHS_AGO = "%dmo ago",
  
  -- Export Window
  EXPORT_TITLE = "Export Data - Select and Copy Text",
  EXPORT_INSTRUCTION = "Click 'Select All' then use Ctrl+C to copy to clipboard",
  EXPORT_SELECT_ALL = "Select All",
  EXPORT_HEADER = "Guild History Export for %s",
  EXPORT_GENERATED = "Generated: %s",
  EXPORT_CATEGORY = "Category: %s",
  EXPORT_TOTAL = "Total Events: %d",
  EXPORT_FORMAT = "%s | %s | %s | %s | %s",
  
  -- Tooltips
  TIP_REFRESH = "Refresh guild list and event data",
  TIP_EXPORT = "Export visible events to text",
  TIP_FULL_TIMESTAMP = "Full timestamp",
  TIP_FULL_DETAILS = "Full details",
  
  -- Settings - Main
  SETTINGS_DESC = "Search cached guild history events. Use |cFFD700/sgthistory|r to open the search window.\n\nData is automatically cached for all guilds by ScrollkeeperData. Here you control which guilds and categories to display in the search window.",
  SETTINGS_DISPLAY = "Display Settings",
  SETTINGS_MAX_EVENTS = "Max Events",
  SETTINGS_MAX_EVENTS_TIP = "Maximum number of events to load at once",
  SETTINGS_SEARCH_DELAY = "Search Delay (ms)",
  SETTINGS_SEARCH_DELAY_TIP = "Delay before search executes while typing",
  SETTINGS_COLOR_CODING = "Enable Color Coding",
  SETTINGS_COLOR_CODING_TIP = "Color code events by type",
  
  -- Settings - Per Guild
  SETTINGS_SHOW_GUILD = "Show in History Window",
  SETTINGS_SHOW_GUILD_TIP = "Display this guild in the history search window",
  SETTINGS_CATEGORIES = "Event Categories to Display",
  SETTINGS_ROSTER_EVENTS = "Roster Events",
  SETTINGS_ROSTER_EVENTS_TIP = "Show member joins, leaves, promotions, kicks",
  SETTINGS_BANK_GOLD_EVENTS = "Bank Gold Events",
  SETTINGS_BANK_GOLD_EVENTS_TIP = "Show gold deposits, withdrawals, trader bids",
  SETTINGS_BANK_ITEMS_EVENTS = "Bank Item Events",
  SETTINGS_BANK_ITEMS_EVENTS_TIP = "Show item deposits and withdrawals",
  SETTINGS_SALES_EVENTS = "Sales Events",
  SETTINGS_SALES_EVENTS_TIP = "Show guild store sales",
  
  -- Dropdown
  DROPDOWN_NO_GUILDS = "No guilds enabled - see settings",
  
  -- Formatting
  FORMAT_GOLD = "%s gold",
  FORMAT_QUANTITY_ITEM = "%dx %s",
  FORMAT_SOLD_TO = "to %s",
  FORMAT_RANK_ARROW = "→",
  MANUAL_ENTRY_TOOLTIP = "This is a manually logged donation",
  NOTES_LABEL = "Notes",
  DELETE_MANUAL_ENTRY = "Delete this manual entry",
  SUCCESS_DELETED_ENTRY = "Manual entry deleted successfully",
  ERROR_DELETE_FAILED = "Failed to delete manual entry",
  
  -- Member Names
  MEMBER_UNKNOWN = "Unknown",
  
  LOG_LIBSCROLL_NOT_FOUND = "|cFFD700[ScrollkeeperHistory]|r LibScroll not found - using basic scrolling",  
}

--------------------------------------------------------------------------------
-- ROSTER
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperRoster"] = {
  -- Main
  SUBMENU_NAME = "Roster Enhancement",
  
  -- Settings
  SETTING_TRADER_TIMER = "Show Trader Flip Timer",
  SETTING_TRADER_TIMER_TIP = "Display countdown timer showing time until next guild trader flip.\n\n" ..
                              "Timer color indicates urgency:\n" ..
                              "• |c00FF0024+ hrs|r - Safe\n" ..
                              "• |cFFFF006-24 hrs|r - Plan ahead\n" ..
                              "• |cFF88002-6 hrs|r - Act soon\n" ..
                              "• |cFF0000< 2 hrs|r - Urgent!",
  
  -- Timer Display
  TIMER_LABEL = "Trader Flip: %s",
  TIMER_FLIPPING = "Flipping now",
  TIMER_FORMAT = "%dh %dm",
  
  -- Full tooltip (for easy formatting)
  TOOLTIP_FULL = "Time until guild trader flip\n\n" ..
                 "Color indicates urgency:\n" ..
                 "|c00FF0024+ hours|r - Safe\n" ..
                 "|cFFFF006-24 hours|r - Plan ahead\n" ..
                 "|cFF88002-6 hours|r - Act soon\n" ..
                 "|cFF0000< 2 hours|r - Urgent!",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperRoster]|r ERROR: ScrollkeeperFramework is missing!",
  
  -- Tasks
  TASKS_HEADER = "Task Reminders",
  TASKS_DESCRIPTION = "Task reminders are configured per-guild below. Enable 'Show Tasks on Roster' for each guild where you want reminders.",
  CUSTOM_TASKS = "Custom Tasks",
  CUSTOM_TASKS_DESC = "Add and configure custom tasks. The settings panel will not update until you reload, but the task will be added or removed in real time.",
  ADD_CUSTOM_TASK = "Add Custom Task",
  REMOVE = "Remove",
  
  -- Per-guild task toggle
  GUILD_TASKS_ENABLE = "Show Tasks on Roster",
  GUILD_TASKS_ENABLE_TIP = "Enable task reminders for this guild's roster page",

  -- Guild configuration header
  GUILD_CONFIG_DESC = "Configure task reminders for %s",

  -- Preset tasks section
  PRESET_TASKS_HEADER = "Preset Tasks",

  -- Frequency settings
  FREQUENCY_NUMBER = "Frequency (number)",
  FREQUENCY_NUMBER_TIP = "Enter number of time units",
  FREQUENCY_UNIT = "Unit",

  -- Task window
  TASK_WINDOW_TITLE = "Add Custom Task",
  TASK_WINDOW_NAME_LABEL = "Task Name:",
  TASK_WINDOW_FREQ_LABEL = "Frequency:",
  TASK_WINDOW_GUILD_LABEL = "Guilds (select multiple or 'All'):",
  TASK_WINDOW_ADD = "Add Task",
  TASK_WINDOW_CANCEL = "Cancel",

  -- Task window validation messages
  ERROR_NO_TASK_NAME = "Please enter a task name",
  ERROR_INVALID_FREQ_NUMBER = "Please enter a valid number for frequency",
  ERROR_NO_FREQ_UNIT = "Please select a frequency unit",

  -- Task completion messages
  TASK_COMPLETED = "Task completed: %s",
  TASK_ADDED = "Task added: %s (guild: %s, enabled: true, isCustom: true)",
  TASK_REMOVED = "Task removed: %s",
  ERROR_PRESET_REMOVE = "Preset tasks cannot be removed. Disable them in settings instead.",

  -- Task list display
  TASK_STATUS_OVERDUE = "OVERDUE",

  -- Tooltip for task labels
  TASK_TOOLTIP_LEFT = "Left-click: Complete task",
  TASK_TOOLTIP_RIGHT = "Right-click: Remove task",

  PRESET_REVIEW_APPLICATIONS = "Review Applications",
  PRESET_CHECK_BANK_DEPOSITS = "Check Bank Deposits",
  PRESET_UPDATE_MOTD = "Update MotD",
  PRESET_PROMOTE_PROBATIONARY = "Promote Probationary",
  PRESET_REVIEW_INACTIVES = "Review Inactives",

  TASK_COLOR_LEGEND = "Color Legend - Time remaining:\n|c00FF00>25%|r - Safe\n|cFFFF0010-25%|r - Plan ahead\n|cFF88005-10%|r - Act soon\n|cFF0000<5% or overdue|r - Urgent!",
  
  -- Remove Button
  REMOVE_CUSTOM_TASK = "Remove Custom Task",
  REMOVE_CUSTOM_TASK_TIP = "Select a custom task to permanently remove",
  REMOVE_WARNING = "WARNING: Removal is permanent! To restore a task, you must add it again manually.",
  REMOVE_INSTRUCTION = "Click on a task below to remove it:",
  REMOVE_WINDOW_CANCEL = "Cancel",
}

--------------------------------------------------------------------------------
-- CONTEXT MENU
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperContextMenu"] = {
  SUBMENU_NAME = "Context Menu Options",
  DESCRIPTION = "Adds new-mail, guild-invite and chat-invite entries to all right-click context menus.",
  MASTER_ENABLE = "Enable Context Menu Features",
  MASTER_ENABLE_TIP = "Master toggle for all context menu enhancements.",
  SF_UNAVAILABLE = "ERROR: ScrollkeeperFramework missing!",
  
  -- Headers
  SCROLLKEEPER_TOOLS = "Scrollkeeper Tools",
  CHAT_HEADER = "Chat Options",
  ROSTER_HEADER = "Guild Roster Options",
  
  -- Options
  NEW_MAIL = "New Mail",
  NEW_MAIL_TIP = "Add 'New Mail' option to chat context menus.",
  GUILD_INVITE = "Guild Invite",
  GUILD_INVITE_TIP = "Add guild invite options to chat context menus.",
  ROSTER_DESC = "Adds notebook integration to the guild roster right-click menu.",
  NOTEBOOK_CONTEXT = "Enable Notebook Context Menu",
  NOTEBOOK_CONTEXT_TIP = "Right-click guild members to open or create notebook entries.",
  ROSTER_INVITE = "Guild Invite from Roster",
  ROSTER_INVITE_TIP = "Add guild invite options to guild roster context menus.",
  
  -- Context Menu Items
  INVITE_TO = "Invite to %s",
  GO_TO_NOTEBOOK = "Go to Notebook Entry",
  MAKE_NOTE = "Make Notebook Note",
  
  -- Messages
  NOTEBOOK_NOT_FOUND = "Notebook module not found.",
  NOTE_EXISTS = "Note already exists for %s.",
  NOTE_CREATED = "Created note for %s in Notebook.",
  OPEN_NOTE = "Open Notebook Entry",
  CREATE_NOTE = "Create Notebook Note",
  LOG_CONVERSATION = "Log Recent Chat",
  CONVERSATION_LOGGED = "Logged %d recent messages involving %s in Notebook under 'Chat' category",
  NO_CONVERSATION = "No recent chat found involving %s in last 100 messages.",
  LOG_CONVERSATIONS = "Enable Conversation Logging",
  LOG_CONVERSATIONS_TIP = "Log chat conversations to Notebook (requires pChat addon).",
  PCHAT_WARNING = "pChat addon not detected - this feature will not work",

 -- Mail Menu Items
  LOG_DONATION = "Log Donation",
  LOG_DONATION_TIP = "Manually record a donation for this player",
  DONATION_WINDOW_TITLE = "Log Manual Donation",
  DONATION_PLAYER = "Player",
  DONATION_GUILD = "Guild",
  DONATION_VALUE_LABEL = "Gold Value",
  DONATION_VALUE_TIP = "Enter the gold value of this donation",
  DONATION_NOTES_LABEL = "Notes (Optional)",
  DONATION_NOTES_TIP = "Additional details about this donation",
  DONATION_TYPE_LABEL = "Donation Type",
  DONATION_TYPE_GOLD = "Gold (Mail)",
  DONATION_TYPE_ITEMS = "Items (Valued)",
  BTN_RECORD_DONATION = "Record Donation",
  BTN_CANCEL = "Cancel",
  SUCCESS_DONATION_LOGGED = "Donation of %d gold logged for %s",
  ERROR_INVALID_AMOUNT = "Please enter a valid gold amount",
}

--------------------------------------------------------------------------------
-- DATA MODULE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperData"] = {
  -- Module Info
  DESCRIPTION = "Background caching service for guild history data using LibHistoire.",
  
  -- Status Messages
  HISTOIRE_READY = "LibHistoire ready - caching all guild history",
  CACHE_STATUS = "=== Event Cache Status ===",
  NO_CACHED_DATA = "No cached data found",
  CACHE_EMPTY = "Cache is empty - this may take a few minutes on first load",
  WAITING_FOR_HISTOIRE = "Waiting for LibHistoire to initialize...",
  
  -- Log Messages
  EVENTS_CACHED = "%s/%s: %d events cached",
  STARTED_CACHING = "Started caching %d guilds",
  MODULE_LOADED = "|cFFD700[ScrollkeeperData]|r Loaded - background caching service",
  LOG_MANUAL_DONATION = "Manual donation logged: %s - %d gold",
  MANUAL_DONATION_SOURCE = "Manual Entry",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperData]|r ERROR: ScrollkeeperFramework missing!",
  ERROR_DATA_NOT_TABLE = "|cFFD700[ScrollkeeperData]|r CRITICAL: SF.Data is not a table!",
  ERROR_HISTOIRE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r ERROR: LibHistoire not found!",
  
  -- Cache Display
  GUILD_HEADER = "%s:",
  CATEGORY_LINE = "  %s: %d events",
  HISTOIRE_STATUS = "LibHistoire ready: %s",
  
  -- Category Names (for display)
  CAT_ROSTER = "roster",
  CAT_BANKED_GOLD = "bankedGold",
  CAT_BANKED_ITEMS = "bankedItems",
  CAT_SALES = "sales",
  
  -- Manual donation logging
  LOG_MANUAL_DONATION = "|cFFD700[ScrollkeeperData]|r Logged: %d gold from %s to %s",

  -- Delete entry messages
  ERROR_DELETE_MISSING_PARAMS = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Missing required parameters",
  SUCCESS_DELETE_ENTRY = "|cFFD700[ScrollkeeperData]|r Successfully deleted manual entry from cache and storage",
  ERROR_DELETE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Entry not found",

  -- Debug cache messages
  DEBUG_NO_GUILD = "[Data Debug] No guild specified",
  DEBUG_NO_CACHE_FOR_GUILD = "[Data Debug] No cache for guild: %s",
  DEBUG_AVAILABLE_GUILDS = "[Data Debug] Available guilds:",
  DEBUG_GUILD_LIST_ITEM = "  - %s",
  DEBUG_CACHE_FOR_GUILD = "[Data Debug] Cache for %s:",
  DEBUG_BANKED_GOLD_COUNT = "  bankedGold: %d events",
  DEBUG_RECENT_DEPOSITS = "  Recent deposits:",
  DEBUG_NO_DEPOSITS = "  No deposits found",
  DEBUG_BANKED_GOLD_MISSING = "  bankedGold: NOT PRESENT",
  DEBUG_ROSTER_COUNT = "  roster: %d events",
  DEBUG_ROSTER_MISSING = "  roster: NOT PRESENT",

  -- Slash command messages
  ERROR_DATA_MODULE_UNAVAILABLE = "Data module or check function not available",
  CMD_CHECKGOLD_USAGE = "Usage: /sgtcheckgold GuildName|@DisplayName|Days",
  CMD_CHECKGOLD_EXAMPLE = "Example: /sgtcheckgold Dragon's Nest Thievery Co|@YourName|14",
  CMD_CHECKGOLD_RESULT = "%s donated %d gold in last %d days (%s)",

  -- Initialization
  ERROR_LIBHISTOIRE_MISSING = "|cFFD700[ScrollkeeperData]|r ERROR: LibHistoire not found",
}

--------------------------------------------------------------------------------
-- WELCOME MESSAGES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperWelcome"] = {
  SUBMENU_NAME = "Welcome Messages",
  DESCRIPTION = "Configure welcome messages for guild members. Use %1 for player name and %2 for guild name. Messages will queue when accepting multiple applications or if text field is active.",
  MASTER_ENABLE = "Enable Welcome Messages",
  MASTER_ENABLE_TIP = "Toggle all welcome messages on or off.",
  LOG_MEMBER_JOINED = "|cFFD700[ScrollkeeperWelcome]|r %s joined %s as %s",
  
  -- Template
  TEMPLATE_HEADER = "Template Variables",
  VAR_PLAYER = "%1 - Player Name",
  VAR_GUILD = "%2 - Guild Name",
  
  -- Guild Settings
  ENABLE_FOR_GUILD = "Enable for this Guild",
  MESSAGE_TEMPLATE = "Message Template",
  PREVIEW = "Preview: %s",
  DEFAULT_MESSAGE = "Welcome %1 to %2",
}

--------------------------------------------------------------------------------
-- STANDARD COMMANDS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperStandardCommands"] = {
  -- Main
  SUBMENU_NAME = "Chat Commands & Utilities",
  DESCRIPTION = "Additional utility commands and keybinding support for Scrollkeeper.",
  
  -- Headers
  COMMANDS_HEADER = "Available Commands",
  UTILITY_HEADER = "Utility Commands",
  STATUS_HEADER = "Status Commands",
  MODULE_HEADER = "Module Commands",
  DEBUG_HEADER = "Debug Commands",
  
  -- Command Documentation
  CMD_SKDEBUG = "|cf3ebd1/skdebug|r - Show system debug information",
  CMD_SKTEST = "|cf3ebd1/sktest <option>|r - Run module tests (options: context, settings, notebook, mail, data)",
  CMD_SGTNOTE = "|cf3ebd1/sgtnote|r - Toggle notebook window",
  CMD_SGTMAIL = "|cf3ebd1/sgtmail|r - Open mail window",
  CMD_SGTHISTORY = "|cf3ebd1/sgthistory|r - Open history search window",
  CMD_SGTPROVISION = "|cf3ebd1/sgtprovision|r - Open provisional member window",
  CMD_SGTCACHE = "|cf3ebd1/sgtcache|r - Show event cache status",
  CMD_ROLL = "|cf3ebd1/roll <number>|r - Roll dice (example: /roll 20)",
  CMD_DICE = "|cf3ebd1/dice <number>|r - Same as /roll",
  CMD_RL = "|cf3ebd1/rl|r - Reload UI",
  CMD_ON = "|cf3ebd1/on|r - Set status to Online",
  CMD_OFF = "|cf3ebd1/off|r - Set status to Offline",
  CMD_AFK = "|cf3ebd1/afk|r - Set status to Away",
  CMD_DND = "|cf3ebd1/dnd|r - Set status to Do Not Disturb",
  CMD_OFFL = "|cf3ebd1/offl|r - Toggle Online/Offline",
  
  -- Full command list (for description text)
  COMMAND_LIST = "|cf3ebd1/sgtnote|r - Toggle notebook window\n" ..
                 "|cf3ebd1/sgtmail|r - Open mail window\n" ..
                 "|cf3ebd1/sgthistory|r - Open history search\n" ..
                 "|cf3ebd1/sgtprovision|r - Open provisional member window\n" ..
                 "|cf3ebd1/roll <number>|r - Roll dice\n" ..
                 "|cf3ebd1/rl|r - Reload UI\n" ..
                 "|cf3ebd1/on /off /afk /dnd|r - Set player status\n" ..
                 "|cf3ebd1/offl|r - Toggle offline\n" ..
                 "|cf3ebd1/skdebug|r - Show debug info\n" ..
                 "|cf3ebd1/sgtcache|r - Show cache status\n" ..
                 "|cf3ebd1/sgtcheckpm GuildName|@DisplayName|r - Debug gold donation check for specific member\n" ..
                 "|cf3ebd1/sgtattendance start [event name]|r - Start tracking\n" ..
                 "|cf3ebd1/sgtattendance stop|r - Stop and save report\n" ..
                 "|cf3ebd1/sgtattendance status|r - Show current session information" ..
				 "|cf3ebd1/sgttask add <name>|<frequency>|<guild>|r to add a custom task" ..
				 "|cf3ebd1/sgttask list|r - Show all tasks with status" ..
				 "|cf3ebd1/sgttask complete <number>|r - Mark task complete",
  
  -- Buttons
  TEST_BUTTON = "Test All Systems",
  TEST_BUTTON_TIP = "Run a comprehensive test of all Scrollkeeper modules",
  
  -- Status Messages
  STATUS_ONLINE = "Status set to Online",
  STATUS_OFFLINE = "Status set to Offline",
  STATUS_DND = "Status set to Do Not Disturb",
  STATUS_AWAY = "Status set to Away",
  STATUS_CHANGED = "Scrollkeeper: Status set to %s",
  STATUS_TOGGLED = "Notebook window toggled",
  
  -- Roll Messages
  ROLL_USAGE = "Usage: /roll <max>",
  ROLL_EXAMPLE = "Example: /roll 20",
  ROLL_INVALID = "Invalid number: %s",
  ROLL_OUTPUT = "rolled %d (1-%d)",
  
  -- Debug Messages
  DEBUG_HEADER = "=== Scrollkeeper Debug Info ===",
  DEBUG_FRAMEWORK = "Framework loaded: %s",
  DEBUG_SETTINGS = "Settings table: %s",
  DEBUG_LAM = "LAM2 available: %s",
  DEBUG_FUNC = "SF.func available: %s",
  DEBUG_GET_SETTINGS = "SF.getModuleSettings: %s",
  DEBUG_PANEL = "Panel registered: %s",
  DEBUG_MODULE = "Module: %s - Controls: %d - Icon: %s",
  DEBUG_TOTAL_MODULES = "Total modules registered: %d",
  DEBUG_NO_MODULES = "No module settings found",
  DEBUG_CONTEXT = "Context Menu enabled: %s",
  DEBUG_NOTEBOOK = "Notebook module: %s",
  DEBUG_DATA = "Data module: %s",
  DEBUG_HISTOIRE = "LibHistoire: %s",
  DEBUG_DATETIME = "LibDateTime: %s",
  
  -- Test Messages
  TEST_HEADER = "=== Scrollkeeper Test Commands ===",
  TEST_USAGE = "Usage: /sktest <option>",
  TEST_OPTIONS = "Options: context, settings, notebook, mail, data, attendance",
  TEST_RUNNING = "Running comprehensive system test...",
  TEST_UNKNOWN = "Unknown test option: %s",
  TEST_AVAILABLE = "Available options: context, settings, notebook, mail, data, attendance",
  
  -- Test: Context
  TEST_CONTEXT_HEADER = "=== Context Menu Test ===",
  TEST_CONTEXT_ACTIVE = "Context menu hook is active",
  TEST_CONTEXT_ENABLED = "Context menu enabled in settings: %s",
  TEST_CONTEXT_MAIL = "Chat new mail option: %s",
  TEST_CONTEXT_INVITE = "Chat invite option: %s",
  TEST_CONTEXT_NOT_LOADED = "ScrollkeeperContextMenu module not loaded",
  TEST_CONTEXT_FAILED = "Context menu hook FAILED - CHAT_SYSTEM not available",
  
  -- Test: Settings
  TEST_SETTINGS_HEADER = "=== Settings Test ===",
  TEST_SETTINGS_ACCESSIBLE = "%s settings accessible: %s",
  TEST_SETTINGS_PANEL = "Settings panel is registered",
  TEST_SETTINGS_NO_PANEL = "Settings panel not registered",
  TEST_SETTINGS_NO_ACCESS = "Cannot access module settings - framework issue",
  
  -- Test: Notebook
  TEST_NOTEBOOK_HEADER = "=== Notebook Test ===",
  TEST_NOTEBOOK_LOADED = "Notebook module loaded",
  TEST_NOTEBOOK_ENABLED = "Enabled: %s",
  TEST_NOTEBOOK_WINDOW = "Notebook window exists: %s",
  TEST_NOTEBOOK_SAVE = "Test note save: %s",
  TEST_NOTEBOOK_NOT_LOADED = "Notebook module not loaded",
  
  -- Test: Mail
  TEST_MAIL_HEADER = "=== Mail Module Test ===",
  TEST_MAIL_LOADED = "Mail module loaded",
  TEST_MAIL_ENABLED = "Enabled: %s",
  TEST_MAIL_WINDOW = "Mail window exists: %s",
  TEST_MAIL_COMMAND = "/sgtmail command registered",
  TEST_MAIL_NO_COMMAND = "/sgtmail command not registered",
  TEST_MAIL_NOT_LOADED = "Mail module not loaded",
  
  -- Test: Data
  TEST_DATA_HEADER = "=== Data Module Test ===",
  TEST_DATA_LOADED = "Data module loaded",
  TEST_DATA_LH_AVAILABLE = "LibHistoire available",
  TEST_DATA_CACHE_ACCESSIBLE = "Event cache accessible: %s",
  TEST_DATA_RECORDS = "Total cached event records: %d",
  TEST_DATA_NO_FUNCTIONS = "Data functions not available",
  TEST_DATA_NO_LH = "LibHistoire not available",
  TEST_DATA_NOT_LOADED = "Data module not loaded",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperStandardCommands]|r ERROR: ScrollkeeperFramework missing!",
  ERROR_NOTEBOOK_DISABLED = "Notebook is disabled in settings",
  ERROR_NOTEBOOK_NO_WINDOW = "Notebook window not available",
  ERROR_NOTEBOOK_NOT_LOADED = "Notebook module not loaded",
  
  -- Log Messages
  LOG_REGISTERING = "|cFFD700[ScrollkeeperStandardCommands]|r Registering slash commands...",
  LOG_REGISTERED = "|cFFD700[ScrollkeeperStandardCommands]|r Slash commands registered",
  LOG_INITIALIZING = "|cFFD700[ScrollkeeperStandardCommands]|r Initializing...",
  LOG_COMPLETE = "|cFFD700[ScrollkeeperStandardCommands]|r Initialization complete",
}

--------------------------------------------------------------------------------
-- ATTENDANCE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperAttendance"] = {
  -- Module info
  SUBMENU_NAME = "Event Attendance",
  
  -- Description
  DESCRIPTION = "Track event attendance with automatic late/early detection.",
  
  -- Settings
  MASTER_ENABLE = "Enable Event Attendance Tracking",
  MASTER_ENABLE_TIP = "Enable attendance tracking features and commands",
  
  -- Headers
  HEADER_COMMANDS = "Commands & Usage",
  HEADER_HISTORY = "Session History",
  
  -- Command help
  COMMANDS_DESC = "/sgtattendance start [name] - Begin tracking\n/sgtattendance stop - End and save\n/sgtattendance status - Check current session",
  
  -- Help text (for /attendance help)
  HELP_HEADER = "=== Attendance Tracking Commands ===",
  HELP_START = "/sgtattendance start [event name] - Start tracking",
  HELP_STOP = "/sgtattendance stop - Stop and save report",
  HELP_STATUS = "/sgtattendance status - Show current session information",
  
  -- Success messages
  SUCCESS_TRACKING_STARTED = "Started tracking: %s (%d members present)",
  SUCCESS_TRACKING_STOPPED = "Stopped tracking: %s",
  SUCCESS_SAVED_TO_NOTEBOOK = "Attendance report saved to Notebook 'Events' category as '%s'",
  SUCCESS_HISTORY_CLEARED = "Attendance history cleared",
  
  -- Error messages
  ERROR_ALREADY_TRACKING = "Already tracking an event! Use /sgtattendance stop first.",
  ERROR_NO_ACTIVE_SESSION = "No active tracking session",
  ERROR_UNKNOWN_COMMAND = "Unknown command. Use /sgtattendance help",
  ERROR_NOT_SAVED = "Warning: Could not save to Notebook",
  ERROR_NOTEBOOK_DISABLED = "Notebook not available - report saved to attendance history only",
  
  -- Status messages
  STATUS_NO_SESSION = "No active tracking session",
  STATUS_ACTIVE = "Tracking: %s | Duration: %d min | Attendees: %d",
  
  -- Real-time log messages
  LOG_MEMBER_JOINED = "%s joined the event (%d minutes late)",
  LOG_MEMBER_LEFT = "%s left the event (present for %d minutes)",
  
  -- Report sections
  REPORT_HEADER = "Attendance Report: %s",
  REPORT_TIME = "Time: %s to %s",
  REPORT_SUMMARY = "Total Attendees: %d | Full Attendance: %d | Late Arrivals: %d | Left Early: %d",
  
  SECTION_FULL_ATTENDANCE = "Full Attendance",
  SECTION_ON_TIME = "On Time",
  SECTION_LATE = "Late Arrivals",
  SECTION_LEFT_EARLY = "Left Early",
  
  -- History display
  NO_SESSIONS = "No tracked sessions yet",
  SESSIONS_COUNT = "Tracked Sessions: %d",
  
  -- Settings buttons
  BTN_CLEAR_HISTORY = "Clear History",
  BTN_CLEAR_HISTORY_TIP = "Remove all saved attendance sessions",
  WARNING_CLEAR_HISTORY = "This will permanently delete all attendance records!",
}

--------------------------------------------------------------------------------
-- APPLICATIONS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperApplications"] = {
  -- Module info
  SUBMENU_NAME = "Guild Applications",
  DESCRIPTION = "Automatically log guild applications to your Notebook for record keeping. Applications are saved with full details including the applicant's message.",
  
  -- Settings
  MASTER_ENABLE = "Enable Application Logging",
  MASTER_ENABLE_TIP = "Master toggle for application logging functionality",
  AUTO_LOG = "Automatically Log New Applications",
  AUTO_LOG_TIP = "When enabled, new guild applications are automatically saved to Notebook",
  SHOW_NOTIFICATIONS = "Show Chat Notifications",
  SHOW_NOTIFICATIONS_TIP = "Display a message in chat when applications are logged",
  
  -- Guild settings
  HEADER_GUILDS = "Per-Guild Settings",
  GUILDS_DESC = "Choose which guilds to log applications for:",
  GUILD_TOGGLE_TIP = "Log applications for %s",
  
  -- Errors
  ERROR_NOTEBOOK_UNAVAILABLE = "|cFFD700[ScrollkeeperApplications]|r Notebook module is not available. Applications cannot be logged.",
  WARNING_NOTEBOOK_MISSING = "|cFFD700[ScrollkeeperApplications]|r WARNING: Notebook module not loaded. Application logging will not work.",
  
  SUCCESS_LOGGED_SINGLE = "|cFFD700[ScrollkeeperApplications]|r Logged application from |cFFD700%s|r to |cFFD700%s|r",
  ERROR_SAVE_FAILED = "|cFF5555[ScrollkeeperApplications]|r Failed to save application from %s",
  SUCCESS_LOGGED_MULTIPLE = "|cFFD700[ScrollkeeperApplications]|r Logged %d applications for |cFFD700%s|r",
}
-- Backward compatibility (DEPRECATED)
_G.Scrollkeeper.Localization = Scrollkeeper.Localization