
local strings = {

    -----------
    -- Menu
    GG_MENU_LE_HEADER = "Lead Expiry Reminders",
    GG_MENU_LE_DESC = "Reminders are triggered when the Player changes zone. Leads expiring within the set number of days will trigger reminders. Reminders will be paused for the set interval after a reminder is shown.",
    GG_MENU_LE_ENABLED = "Enabled",
    GG_MENU_LE_ENABLED_TT = "Enable lead expiry reminders?",
    GG_MENU_LE_ANNOUNCE_REMINDERS = "Announce Reminders",
    GG_MENU_LE_ANNOUNCE_REMINDERS_TT = "Display onscreen announcement for lead expiry reminders?",
    GG_MENU_LE_CHAT_REMINDERS = "Show Chat Window Reminders",
    GG_MENU_LE_CHAT_REMINDERS_TT = "Display chat window reminders?",
    GG_MENU_LE_WARNING_PERIOD = "Reminder Expiry Age (days) [1-20]",
    GG_MENU_LE_WARNING_PERIOD_TT = "How many days to go before lead expiry to start reminding.",
    GG_MENU_LE_NO_WARNING_PERIOD = "No Reminder Interval (minutes) [1-120]",
    GG_MENU_LE_NO_WARNING_PERIOD_TT = "The interval in seconds between reminders.",
    GG_MENU_GF_HEADER = "Group Finder Listing Notifications",
    GG_MENU_GF_ENABLED = "Enabled",
    GG_MENU_GF_ENABLED_TT = "Enable Group Finder notifications in the chat window?",
    GG_MENU_GF_CHECK_INTERVAL = "Group Finder check Interval (seconds) [5-60]",
    GG_MENU_GF_CHECK_INTERVAL_TT = "The interval in seconds to check the Group Finder for new Trial listings. Minimum is 5 seconds, Maximum is 60 seconds.",
    GG_MENU_GF_TRIAL_HEADER = "Trials to Notify from Group Finder",
    GG_MENU_GF_TRIAL_DESC = "Please note that group finder listings created with \"Any Trial\" option will be included in the notifications.",
    GG_MENU_GF_TRIAL_TT = "Include %s Group Finder listings?",
    GG_MENU_PA_HEADER = "Personal Assistant Integration",
    GG_MENU_PA_DESC = "Requirements:\n- Addons: LibCharacterKnowledge, LibPrice (and a price source enabled such as TamrielTradeCentre, Master Merchant, Arkadius' Trade Tools)\n- A dedicated Personal Assistant LOOT profile for your Trader, so that surplus items and any items intended for sale are NOT automatically learnt when withdrawn from the bank by the Trader.\n\nRouting Rules:\n1. Items Unknown by the Crafter --> send to the Crafter\n2. Low value items are directed to the next Character per LibCharacterKnowledge settings for learning.\n3. Surplus items and high value items for sale are sent to the Trader (if enabled) otherwise they are left in the Bank.",
    GG_MENU_PA_ENABLED = "Enabled?",
    GG_MENU_PA_ENABLED_TT = "Is the Personal Assistant override enabled? Disabling will require a UI reload to take effect.",
    GG_MENU_PA_SALE_VALUE_THRESHOLD = "Sale Value Threshold",
    GG_MENU_PA_SALE_VALUE_THRESHOLD_TT = "Items with a sale value less than or equal to this threshold will be treated as low value items for the purposes of determining if they are intended for sale or learning.",
    GG_MENU_PA_CRAFTER_CHARACTER_NAME = "Crafter Character Name",
    GG_MENU_PA_CRAFTER_CHARACTER_NAME_TT = "The name of the character who is the Crafter.",
    GG_MENU_PA_TRADER_CHARACTER_NAME = "Trader Character Name",
    GG_MENU_PA_TRADER_CHARACTER_NAME_TT = "The name of the character who is the Trader.",
    GG_MENU_PA_WITHDRAW_TO_TRADER_ENABLED = "Withdraw to Trader Enabled?",
    GG_MENU_PA_WITHDRAW_TO_TRADER_ENABLED_TT = "Suplus items are withdrawn from the bank to the Trader character.",
    GG_MENU_KC_HEADER = "Key Chording",
    GG_MENU_KC_DESC = "Allows Shift, Ctrl and Alt to act as modifiers in Settings > Controls, so you can bind combinations such as Alt+1 to Alt+9 (e.g. Wizard's Wardrobe setups).",
    GG_MENU_KC_ENABLED = "Enable Modifier Keybinds",
    GG_MENU_KC_ENABLED_TT = "Lets you bind Shift, Ctrl and Alt combinations to any action in the Controls menu.",

    -----------
    -- core
    GG_LAM_NOT_FOUND = "LibAddonMenu2 not found, cannot build menu.",
    GG_CHARACTERS = "Characters",
    GG_SHOW_WINDOW = "Show Window",
    GG_TOGGLE_LOCATION_TRACKER = "Toggle Location Change Tracker",
    GG_REMAINING = " Remaining",
    GG_ELAPSED = " Elapsed",

    -----------
    -- Lead Expiry
    GG_LE_NEW_LEAD = "Undiscovered/New Lead",
    GG_LE_LEAD = "Lead",
    GG_LE_LORE_LEAD = "Incomplete Codex/Lore Lead",
    GG_LE_EXPIRY_IN = " Expiry in ",
    GG_LE_EXPIRING_IN = "Lead Expiring in ",
    GG_LE_FOUND_IN = " found in ",
    GG_LE_UNKNOWN_NAME = "Unknown Lead",
    GG_LE_UNKNOWN_ZONE = "Unknown Zone",
    GG_LE_REMIND = "REMIND",
    GG_LE_IGNORE = "IGNORE",
    GG_LE_DISABLE_REMINDER = "Disable Reminder",
    GG_LE_ENABLE_REMINDER = "Enable Reminder",
    GG_LE_TOGGLE_REMINDER = "Toggle Reminder",

    -----------
    -- Group Finder
    GG_GF_NEW_LISTING = "New Listing",
    GG_GF_UPDATED_LISTING = "Updated Listing",
    GG_GF_REMOVED_LISTING = "Removed Listing",
    GG_GF_NO_LISTING = "Group Finder: |cff0000No Listings found.|r Will notify when one is found.",

    -----------
    -- Location Change
    GG_LOCATION_CHANGED = "Location Changed",
    GG_LOCATION_ENABLED = "Location Change Tracker enabled",
    GG_LOCATION_DISABLED = "Location Change Tracker disabled",

    -----------
    -- Personal Assistant Override

    -----------
    -- Night Market
    GG_NM_MENU_ELMS_GUIDANCE_HEADER = "Night Market Quest Objective Guidance",
    GG_NM_MENU_BLUE_MARKERS = "The Blue markers indicate a possible Quest start location.",
    GG_NM_MENU_GREEN_MARKERS = "Green markers show a possible quest objective location.",
    GG_NM_MENU_NOTE_ON_ELMS = "Note: You must have ElmsMarkers installed and enabled for these markers to appear.",
    GG_NM_MENU_QUEST_LIST_HDR = "The numbers align to the following quests.",
    GG_NM_MENU_HIDE_TRACKER = "Hide Faction Score Tracker",
    GG_NM_MENU_HIDE_TRACKER_TT = "Hides the on-screen Night Market faction scores.",
    GG_NM_MENU_ELMS_ENABLE = "Enable Elm's Marker Injection?",
    GG_NM_MENU_ELMS_ENABLE_TT = "Adds 3D markers into ElmsMarkers for the Night Market questing.",
    GG_NM_GROUP_AUTO = "Argent Group automation",
    GG_NM_GROUP_AUTO_OFF = "OFF",
    GG_NM_GROUP_AUTO_ON = "ON",
    GG_NM_GROUP_AUTO_ERROR_NOTINZONE = "Not in the Event Zone",
    GG_NM_GROUP_AUTO_ERROR_ZONENOTACTIVE = "Event Zone not active",
    GG_NM_GROUP_AUTO_ERROR_FAILEDTWICE = "Group Finder creation failed twice",
    GG_NM_GROUP_AUTO_ALLDONE = "All keys obtained",
    GG_NM_GROUP_AUTO_LISTINGREMOVED = "Listing Removed",
    GG_NM_GROUP_AUTO_QUESTSHARE1 = "Shared",
    GG_NM_GROUP_AUTO_QUESTSHARE2 = "quest(s) with group.",
    GG_NM_GROUP_AUTOMATION_KEYBIND = "Toggle Argent Group Automation",

    -----------
    -- Time
    GG_TIME_SECONDS = "seconds",
    GG_TIME_MINUTES = "minutes",
    GG_TIME_HOURS = "hours",
    GG_TIME_DAYS = "days",
    GG_TIME_NONE = "None",

}

for id, val in pairs(strings) do
   ZO_CreateStringId(id, val)
   SafeAddVersion(id, 1)
end