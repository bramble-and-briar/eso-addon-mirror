-- Quartermaster/localization/en.lua
-- Default English string table. ALL user-visible text must come through this file.
-- Other locales (de/fr/ru) are stubs that fall back to en.

local strings = {
    -- Addon identity
    SI_ACCOUNTHOLD_ADDON_NAME            = "Quartermaster",
    SI_ACCOUNTHOLD_LOAD_BANNER           = "|cFFD700Quartermaster|r v%s loaded.",
    -- Private-beta / rollout access gate (see config/FeatureAccess.lua and
    -- src/Features.lua). Shown to accounts not on the whole-add-on allowlist.
    SI_ACCOUNTHOLD_BETA_BANNER           = "[BETA TEST IN PROGRESS]",
    -- Shown in chat beneath the banner AND as the locked settings-panel label,
    -- so it has to stand on its own in both places: state that the add-on is
    -- unreleased, and that nothing is broken on the player's end.
    SI_ACCOUNTHOLD_FEATURES_DISABLED     = "Features disabled — this add-on is still in private testing and is not yet released to the public. It is not enabled for your account.",
    -- Gamepad/console-only follow-up to LOAD_BANNER. On gamepad the entry
    -- point is a third header tab on the Inventory screen (after Items and
    -- Craft Bag), so point console players straight at it.
    SI_ACCOUNTHOLD_LOAD_BANNER_GAMEPAD   = "|cFFD700Quartermaster|r: open your |cFFFFFFInventory|r and scroll the top tabs to the |cFFFFFFQuartermaster|r tab (after Items and Craft Bag).",
    SI_ACCOUNTHOLD_DIAG_HEADER           = "Recent Quartermaster diagnostics",
    SI_ACCOUNTHOLD_DIAG_EMPTY            = "No Quartermaster diagnostics recorded.",
    SI_ACCOUNTHOLD_DIAG_DUMP             = "Show recent diagnostics",
    SI_ACCOUNTHOLD_DIAG_DUMP_TIP         = "Print the most recent Quartermaster diagnostic messages to chat. Use this on Xbox / PS5 to confirm the addon initialised correctly and to see why a popup or panel did not appear.",

    -- Empty-state text for the gamepad Quartermaster inventory list.
    SI_ACCOUNTHOLD_EMPTY                 = "No items scanned yet. Open your bank or bags to scan.",

    -- Gamepad item-detail tooltip: extra lines appended under the item card.
    -- <<1>> is the location/holder label; <<1>> is the status word.
    SI_ACCOUNTHOLD_TOOLTIP_LOCATION      = "Location: <<1>>",
    SI_ACCOUNTHOLD_TOOLTIP_HOLD_STATUS   = "Quartermaster: <<1>>",
    -- A set reservation names the SET, not the piece it was created from: any
    -- piece of the set satisfies it. string.format style (one %s).
    -- A set reservation covers EVERY piece of the set, so it gets one
    -- unambiguous line naming the set and the holder, rather than three
    -- overlapping "Reserved" lines that each told half the story.
    -- string.format style: %s = set name, %s = character name.
    SI_ACCOUNTHOLD_TOOLTIP_SET_RESERVED_FOR = "Quartermaster: All %s items currently reserved for %s",
    SI_ACCOUNTHOLD_TOOLTIP_SET_RESERVED     = "Quartermaster: All %s items currently reserved",
    SI_ACCOUNTHOLD_HOLD_SET_LABEL        = "%s (Set)",
    -- The Priorities blade: named for the add-on so it is unambiguous sitting
    -- among the base game's own Collections entries.
    SI_ACCOUNTHOLD_PRIORITIES_MENU       = "Quartermaster Priorities",
    -- Presentation toggle for the gamepad Quartermaster blade. The note spells
    -- out the before/after, because the label alone does not tell the player
    -- what will actually change on screen.
    SI_ACCOUNTHOLD_SETTINGS_ROW_LOCATION = "Show item location under each row",
    SI_ACCOUNTHOLD_SETTINGS_ROW_LOCATION_NOTE =
        "OFF (default) - the row shows only the item name, and the location "
        .. "appears on the tooltip:\n"
        .. "    Rush of Agony Sash\n"
        .. "ON - the location is also repeated under every row in the list:\n"
        .. "    Rush of Agony Sash\n"
        .. "    Bank\n"
        .. "The tooltip shows the location either way.",
    -- Priorities blade: failure reasons and section headers. Every one of these
    -- exists so a blank screen is impossible -- the blade must always say
    -- either what it found or why it could not open.
    SI_ACCOUNTHOLD_PRIO_SHOW_FAILED      = "Quartermaster Priorities could not open (%s). Type /qmpriorities to read the list in chat.",
    SI_ACCOUNTHOLD_PRIO_SUMMARY          = "%s, %s",
    SI_ACCOUNTHOLD_PRIO_SUMMARY_ACTIVITY_ONE  = "%d activity",
    SI_ACCOUNTHOLD_PRIO_SUMMARY_ACTIVITY_MANY = "%d activities",
    SI_ACCOUNTHOLD_PRIO_SUMMARY_WANTED   = "%d wanted",
    SI_ACCOUNTHOLD_PRIO_SUMMARY_ERROR    = "Could not read your priorities: %s",
    SI_ACCOUNTHOLD_PRIO_EMPTY_HINT       = "Nothing wanted yet. Collections > Item Sets, highlight a set piece, press Y.",
    SI_ACCOUNTHOLD_PRIO_HEADER_PLAN      = "Run these - dungeons & trials",
    SI_ACCOUNTHOLD_PRIO_HEADER_WANTED    = "Wanted sets & items",
    SI_ACCOUNTHOLD_PRIO_NO_SCENE         = "no screen was ready to host it",
    SI_ACCOUNTHOLD_PRIO_NO_DIALOG_API    = "gamepad dialogs are unavailable",
    SI_ACCOUNTHOLD_PRIO_NO_ENTRY_API     = "the gamepad list template is unavailable",
    SI_ACCOUNTHOLD_PRIO_NO_REGISTER      = "the dialog could not be registered",
    SI_ACCOUNTHOLD_PRIO_SHOW_THREW       = "the game refused the request",
    SI_ACCOUNTHOLD_PRIO_LIST_NOT_BUILT   = "the list was not built",
    SI_ACCOUNTHOLD_PRIO_QUEUED_BEHIND    = "Quartermaster Priorities will open when the current window closes.",
    SI_ACCOUNTHOLD_PRIO_DEFERRED         = "Quartermaster Priorities will open as soon as you are back in the world.",
    SI_ACCOUNTHOLD_PRIO_NO_SELECTION     = "Nothing is selected on the Priorities list.",
    SI_ACCOUNTHOLD_PRIO_NOT_A_PLACE      = "Pick a row under the activities heading - a wanted set is not a place.",
    -- PRI-11: the detail panel beside the Priorities list, and the native host
    -- screen's recovery keybind.
    SI_ACCOUNTHOLD_PRIO_ZONE             = "Zone: %s",
    SI_ACCOUNTHOLD_PRIO_OUTSTANDING      = "%d wanted piece(s) outstanding",
    SI_ACCOUNTHOLD_PRIO_UNKNOWN_SOURCE_DESC = "No activity data for these sets - this plan is incomplete.",
    SI_ACCOUNTHOLD_PRIO_DETAIL_SETS_HEADER = "Wanted sets from here:",
    SI_ACCOUNTHOLD_PRIO_DETAIL_SET_PROGRESS = "%s - %d/%d collected",
    SI_ACCOUNTHOLD_PRIO_DETAIL_COLLECTED = "Collected: %d/%d pieces",
    SI_ACCOUNTHOLD_PRIO_DETAIL_DROPS_FROM = "Drops from: %s",
    SI_ACCOUNTHOLD_PRIO_DETAIL_SOURCE_UNKNOWN = "Source unknown - Quartermaster has no activity data for this set yet.",
    SI_ACCOUNTHOLD_PRIO_DETAIL_NOTHING_OUTSTANDING = "Nothing outstanding - every wanted piece is collected.",
    SI_ACCOUNTHOLD_PRIO_DETAIL_WANTED_ITEM = "Marked as wanted.",
    SI_ACCOUNTHOLD_PRIO_BTN_REOPEN       = "Show list",
    SI_ACCOUNTHOLD_ARMORY_MENU           = "Quartermaster Armory",
    -- Epic 0008: quality-of-life actions on base-game screens.
    SI_ACCOUNTHOLD_FEATURE_QOL           = "Quality of life",
    -- Travel tracing (diagnostic, BUGS.md QMQ-1). Off by default.
    SI_ACCOUNTHOLD_TRACE_TRAVEL          = "Log travel to chat (diagnostic)",
    SI_ACCOUNTHOLD_TRACE_TRAVEL_TIP      = "Prints the travel node used by every jump you make, including ones from the world map. Used to work out what a dungeon's travel node is called.",
    SI_ACCOUNTHOLD_TRACE_ON              = "tracing is ON. Travel anywhere to log the node it uses.",
    SI_ACCOUNTHOLD_TRACE_DUMP            = "List dungeon travel nodes",
    SI_ACCOUNTHOLD_TRACE_DUMP_TIP        = "Prints every dungeon-type travel node the client knows about, with its name and zone.",
    SI_ACCOUNTHOLD_QOL_CLEAR_NEW         = "Clear new item notifications",    SI_ACCOUNTHOLD_QOL_CLEAR_NEW_N       = "Clear new item notifications (%d)",
    -- Collections-wide clear-all (hold to activate). The label says "Hold"
    -- because the bind is NOT the Y button: Y is already claimed in three of
    -- the collections book's four keybind groups, so the slot is negotiated at
    -- runtime and the player is told the gesture, not the letter.
    SI_ACCOUNTHOLD_QOL_CLEARALL_HOLD     = "Hold: Clear all new notifications (%d)",
    SI_ACCOUNTHOLD_QOL_CLEARALL_HOLDING  = "Clearing...",
    SI_ACCOUNTHOLD_QOL_CLEARALL_NONE     = "Nothing was marked new.",
    SI_ACCOUNTHOLD_QOL_CLEARALL_DONE     = "Cleared %d new marker(s).",
    -- Honest about persistence: inventory / craft-bag markers are a Lua-cache
    -- write with no C call behind them, so they return after a reload.
    SI_ACCOUNTHOLD_QOL_CLEARALL_DONE_SESSION =
        "Cleared %d new marker(s). %d were inventory markers, which return after a reload.",
    SI_ACCOUNTHOLD_QOL_CLEARED_N         = "Cleared %d new-item marker(s).",
    SI_ACCOUNTHOLD_QOL_CLEARED_NONE      = "Nothing was marked new.",
    -- Bank tab reservation options dialog (Y).
    SI_ACCOUNTHOLD_BANK_OPTIONS          = "Reservation options",
    SI_ACCOUNTHOLD_BANK_OPT_PIECES       = "Pieces (A toggles)",
    SI_ACCOUNTHOLD_BANK_OPT_ACTIONS      = "Actions",
    SI_ACCOUNTHOLD_BANK_OPT_CANCEL       = "Cancel this reservation",
    SI_ACCOUNTHOLD_BANK_OPT_SELECT       = "Select",
    SI_ACCOUNTHOLD_BANK_OPT_ON           = "[x] ",
    SI_ACCOUNTHOLD_BANK_OPT_OFF          = "[  ] ",
    -- Status word plus the set it applies to, e.g. "Reserved: Rush of Agony".
    -- string.format style: %s = status word, %s = set name.
    SI_ACCOUNTHOLD_STATUS_SET_SUFFIX     = "%s: %s",
    -- Reservation status line including who the item is reserved for.
    SI_ACCOUNTHOLD_TOOLTIP_HOLD_STATUS_FOR = "Quartermaster: <<1>> for <<2>>",
    -- Bug 8: native item-tooltip "Reserved" annotation (string.format style).
    SI_ACCOUNTHOLD_TOOLTIP_RESERVED_FOR  = "Quartermaster: Reserved for %s",
    SI_ACCOUNTHOLD_TOOLTIP_RESERVED      = "Quartermaster: Reserved",
    -- Hold/reservation status indicators.
    SI_ACCOUNTHOLD_STATUS_RESERVED       = "Reserved",
    SI_ACCOUNTHOLD_STATUS_AWAITING       = "Awaiting deposit",
    SI_ACCOUNTHOLD_STATUS_IN_TRANSIT     = "In transit",

    -- Gamepad filter & sort dialog (guild-store-style dropdown panel).
    SI_ACCOUNTHOLD_BTN_FILTERS           = "Filters",
    SI_ACCOUNTHOLD_FILTERS_TITLE         = "Filter & Sort",
    SI_ACCOUNTHOLD_SORT_HEADER           = "Sort By",
    SI_ACCOUNTHOLD_SORT_NAME             = "Name (A-Z)",
    SI_ACCOUNTHOLD_SORT_QUALITY          = "Quality",
    SI_ACCOUNTHOLD_SORT_TYPE             = "Item Type",
    SI_ACCOUNTHOLD_FILTER_ALL            = "All",
    SI_ACCOUNTHOLD_BOUND_ANY             = "Any",
    SI_ACCOUNTHOLD_BOUND_BOUND           = "Bound only",
    SI_ACCOUNTHOLD_BOUND_UNBOUND         = "Unbound only",
    SI_ACCOUNTHOLD_RESET_FILTERS         = "Reset",
    SI_ACCOUNTHOLD_FILTERS_DONE          = "Done",

    -- In-list search field + guild-store-style headers.
    SI_ACCOUNTHOLD_SEARCH_NAME_HEADER    = "Item Name",
    SI_ACCOUNTHOLD_SEARCH_NAME_DEFAULT   = "Enter a name",
    SI_ACCOUNTHOLD_RESET_SEARCH          = "Reset Search",
    SI_ACCOUNTHOLD_FILTER_CATEGORY       = "Category",
    SI_ACCOUNTHOLD_FILTER_CHARACTER_ALL  = "All Characters",
    SI_ACCOUNTHOLD_FILTER_ITEM_QUALITY   = "Item Quality",
    SI_ACCOUNTHOLD_FILTER_LEVEL          = "Level",
    SI_ACCOUNTHOLD_FILTER_MIN_LEVEL      = "Min Level",
    SI_ACCOUNTHOLD_FILTER_MAX_LEVEL      = "Max Level",
    SI_ACCOUNTHOLD_FILTER_TRAITS         = "Traits",
    SI_ACCOUNTHOLD_FILTER_WEAPON_SUBTYPE = "Weapon Type",
    SI_ACCOUNTHOLD_FILTER_CONSUMABLE_TYPE = "Consumable Type",
    SI_ACCOUNTHOLD_FILTER_MATERIAL_TYPE  = "Material Type",
    SI_ACCOUNTHOLD_FILTER_GLYPH_TYPE     = "Glyph Type",
    SI_ACCOUNTHOLD_FILTER_FURNISHING_TYPE = "Furnishing Type",
    SI_ACCOUNTHOLD_FILTER_COMPANION_TYPE = "Companion Equipment Type",
    SI_ACCOUNTHOLD_FILTER_MISC_TYPE      = "Miscellaneous Type",
    SI_ACCOUNTHOLD_LEVEL_ALL             = "All Levels",
    SI_ACCOUNTHOLD_LEVEL_PLAYER          = "Player Level",
    SI_ACCOUNTHOLD_LEVEL_CP              = "Champion Points",
    SI_ACCOUNTHOLD_WEAPON_ALL            = "All Weapons",
    SI_ACCOUNTHOLD_WEAPON_ONE_HANDED     = "One-Handed Melee",
    SI_ACCOUNTHOLD_WEAPON_TWO_HANDED     = "Two-Handed Melee",
    SI_ACCOUNTHOLD_WEAPON_DESTRO_STAFF   = "Destruction Staff",
    SI_ACCOUNTHOLD_WEAPON_RESTO_STAFF    = "Restoration Staff",
    SI_ACCOUNTHOLD_WEAPON_ALL_TYPES      = "All Weapon Types",
    SI_ACCOUNTHOLD_TRAIT_NONE            = "No Trait",
    SI_ACCOUNTHOLD_TRAITS_SELECTED       = "<<1>> selected",
    SI_ACCOUNTHOLD_QUALITY_ANY           = "Any",

    -- Scenes & headers
    SI_ACCOUNTHOLD_SCENE_TITLE           = "Account Inventory",
    SI_ACCOUNTHOLD_HEADER_FILTERS        = "Filters",
    SI_ACCOUNTHOLD_HEADER_RESULTS        = "Results",
    SI_ACCOUNTHOLD_HEADER_HOLDS          = "Active Holds",
    SI_ACCOUNTHOLD_HEADER_BANK_PANEL     = "Quartermaster — Pending",

    -- Filter chip labels
    SI_ACCOUNTHOLD_FILTER_TYPE           = "Item Type",
    SI_ACCOUNTHOLD_FILTER_SUBTYPE        = "Subtype",
    SI_ACCOUNTHOLD_FILTER_SET            = "Set",
    SI_ACCOUNTHOLD_FILTER_TRAIT          = "Trait",
    SI_ACCOUNTHOLD_FILTER_WEAPON_TYPE    = "Weapon Type",
    SI_ACCOUNTHOLD_FILTER_ARMOR_WEIGHT   = "Armor Weight",
    SI_ACCOUNTHOLD_FILTER_CHARACTER      = "Character",
    SI_ACCOUNTHOLD_FILTER_QUALITY        = "Quality",
    SI_ACCOUNTHOLD_FILTER_EQUIP_SLOT     = "Equip Slot",
    SI_ACCOUNTHOLD_FILTER_BOUND          = "Bound",
    SI_ACCOUNTHOLD_FILTER_HOLDER         = "Holder",
    SI_ACCOUNTHOLD_FILTER_LOCATION       = "Location",
    SI_ACCOUNTHOLD_FILTER_SEARCH_TEXT    = "Search...",  -- PC only

    -- Result columns
    SI_ACCOUNTHOLD_COL_ICON              = "",
    SI_ACCOUNTHOLD_COL_NAME              = "Name",
    SI_ACCOUNTHOLD_COL_TRAIT             = "Trait",
    SI_ACCOUNTHOLD_COL_QUALITY           = "Quality",
    SI_ACCOUNTHOLD_COL_LEVEL             = "Level",
    SI_ACCOUNTHOLD_COL_SET               = "Set",
    SI_ACCOUNTHOLD_COL_LOCATION          = "Location",
    SI_ACCOUNTHOLD_COL_COUNT             = "Count",

    -- Item categories (the guild-bank-style category filter across ALL items).
    SI_ACCOUNTHOLD_CAT_ALL               = "All",
    SI_ACCOUNTHOLD_CAT_WEAPONS           = "Weapons",
    SI_ACCOUNTHOLD_CAT_ARMOR             = "Apparel",
    SI_ACCOUNTHOLD_CAT_JEWELRY           = "Jewelry",
    SI_ACCOUNTHOLD_CAT_CONSUMABLES       = "Consumables",
    SI_ACCOUNTHOLD_CAT_MATERIALS         = "Materials",
    SI_ACCOUNTHOLD_CAT_GLYPHS            = "Glyphs",
    SI_ACCOUNTHOLD_CAT_FURNISHINGS       = "Furnishings",
    SI_ACCOUNTHOLD_CAT_COMPANION         = "Companion Equipment",
    SI_ACCOUNTHOLD_CAT_MISC              = "Miscellaneous",
    SI_ACCOUNTHOLD_CAT_CHARACTER         = "Character",
    SI_ACCOUNTHOLD_CAT_SETS              = "Sets",
    -- Owner view: only the pieces a character is actually wearing. Pairs with
    -- the Character filter (pick a character to see just their kit); with no
    -- character selected it shows every character's equipped gear.
    SI_ACCOUNTHOLD_CAT_EQUIPPED          = "Equipped",
    -- Section headers for the per-character view.
    SI_ACCOUNTHOLD_SECTION_EQUIPPED      = "Equipped",
    SI_ACCOUNTHOLD_SECTION_HELD          = "Held Items",
    -- Set dropdown label in the Sets category: "<name> (<owned> / <reconstructable>)"
    -- -- owned unique pieces, then pieces reconstructable from Collections.
    SI_ACCOUNTHOLD_SET_WITH_COUNT        = "%s (%d / %d)",

    -- Locations
    SI_ACCOUNTHOLD_LOC_CHARACTER         = "<<1>>",
    SI_ACCOUNTHOLD_LOC_BANK              = "Account Bank",
    SI_ACCOUNTHOLD_LOC_GUILD_BANK        = "Guild Bank: <<1>>",
    SI_ACCOUNTHOLD_LOC_HOUSE             = "House: <<1>>",
    SI_ACCOUNTHOLD_LOC_CRAFT_BAG         = "Craft Bag",
    SI_ACCOUNTHOLD_LOC_WORN              = "<<1>> (equipped)",

    -- Hold dialog
    SI_ACCOUNTHOLD_DIALOG_HOLD_TITLE     = "Place Hold",
    SI_ACCOUNTHOLD_DIALOG_HOLD_BODY      = "Reserve %d of %s from %s?",
    -- Extended body: name / location / route. Used by the count + route
    -- enabled dialog (P1 #6).
    SI_ACCOUNTHOLD_DIALOG_HOLD_BODY_FULL = "Reserve |cFFFFFF%s|r from %s.\n\nReserve for: |cFFFFFF%s|r\nRoute via: |cFFFFFF%s|r\nEnter the count to reserve below, then Confirm.",
    -- Body variant used when the item is ALREADY in a shared storage container
    -- (bank / guild bank / house storage): no route step, the item is simply
    -- added to the target character's bank/storage collect list.
    SI_ACCOUNTHOLD_DIALOG_HOLD_BODY_INSTORAGE = "Reserve |cFFFFFF%s|r from %s.\n\nReserve for: |cFFFFFF%s|r\n\nAlready in storage — it will be added to the collect list on the Quartermaster tab of %s.\nEnter the count to reserve below, then Confirm.",
    SI_ACCOUNTHOLD_DIALOG_CYCLE_ROUTE    = "Next route",
    SI_ACCOUNTHOLD_DIALOG_CYCLE_TARGET   = "Reserve For:",
    SI_ACCOUNTHOLD_DIALOG_HOLD_TARGET    = "Reserve for",
    SI_ACCOUNTHOLD_DIALOG_HOLD_COUNT     = "Count",
    SI_ACCOUNTHOLD_DIALOG_HOLD_ROUTE     = "Route via",
    SI_ACCOUNTHOLD_DIALOG_HOLD_EQUIP     = "Auto-equip on receive",
    SI_ACCOUNTHOLD_DIALOG_CONFIRM        = "Confirm",
    SI_ACCOUNTHOLD_DIALOG_CANCEL         = "Cancel",

    -- Override an existing reservation (bug 3)
    SI_ACCOUNTHOLD_DIALOG_OVERRIDE_TITLE   = "Item Already Reserved",
    SI_ACCOUNTHOLD_DIALOG_OVERRIDE_BODY    = "|cFFFFFF%s|r is already reserved for |cFFFFFF%s|r.\n\nReplace the existing reservation?",
    SI_ACCOUNTHOLD_DIALOG_OVERRIDE_BODY_ANON = "|cFFFFFF%s|r is already reserved.\n\nReplace the existing reservation?",
    SI_ACCOUNTHOLD_DIALOG_OVERRIDE_CONFIRM = "Override",

    -- Hold action subtitles
    SI_ACCOUNTHOLD_DISABLED_BOUND        = "Cannot transfer — character bound",
    SI_ACCOUNTHOLD_DISABLED_CRAFT_BAG    = "Already account-wide",
    SI_ACCOUNTHOLD_INFO_CHARACTER_BOUND  = "Character Bound: %s",

    -- Notifications: holder-side
    SI_ACCOUNTHOLD_NOTIFY_HOLDER_LOGIN   = "Another character has reserved %d item(s). Visit a bank to deposit.",
    SI_ACCOUNTHOLD_NOTIFY_HOLDER_AT_BANK = "You have %d item(s) to deposit for other characters.",
    SI_ACCOUNTHOLD_PROMPT_DEPOSIT_TITLE  = "Deposit pending items?",
    SI_ACCOUNTHOLD_PROMPT_DEPOSIT_BODY   = "%d item(s) reserved by other characters. Deposit now?",

    -- Notifications: requester-side
    SI_ACCOUNTHOLD_NOTIFY_REQ_LOGIN      = "%d reserved item(s) have been deposited for you. Visit your bank to collect.",
    SI_ACCOUNTHOLD_NOTIFY_LOGIN_BOTH     = "You have %d item(s) to deposit and %d reserved item(s) waiting to collect. Visit a bank.",
    SI_ACCOUNTHOLD_NOTIFY_REQ_AT_BANK    = "You have %d reserved item(s) waiting in this container.",
    SI_ACCOUNTHOLD_PROMPT_WITHDRAW_TITLE = "Withdraw pending items?",
    SI_ACCOUNTHOLD_PROMPT_WITHDRAW_BODY  = "%d item(s) reserved for you are in this container. Withdraw now?",

    -- Bank action panel
    SI_ACCOUNTHOLD_PANEL_DEPOSIT_ALL     = "Deposit All",
    SI_ACCOUNTHOLD_PANEL_WITHDRAW_ALL    = "Withdraw All",
    SI_ACCOUNTHOLD_PANEL_REVIEW          = "Review",
    SI_ACCOUNTHOLD_PANEL_CONFIRM_ROW     = "Confirm",
    SI_ACCOUNTHOLD_PANEL_CONFIRM_ALL     = "Approve All",
    SI_ACCOUNTHOLD_PANEL_SKIP_ROW        = "Skip",
    SI_ACCOUNTHOLD_PANEL_CLOSE           = "Close",
    SI_ACCOUNTHOLD_PANEL_EMPTY           = "No pending items here.",

    -- Keystrip prompts
    SI_BINDING_NAME_ACCOUNTHOLD_OPEN     = "Open Account Inventory",
    SI_KEYBIND_ACCOUNTHOLD_OPEN          = "Open Search",
    SI_KEYBIND_ACCOUNTHOLD_DEPOSIT       = "Deposit Holds",
    SI_KEYBIND_ACCOUNTHOLD_WITHDRAW      = "Withdraw Holds",
    SI_KEYBIND_ACCOUNTHOLD_REVIEW        = "Review",
    SI_KEYBIND_ACCOUNTHOLD_RETRY         = "Retry Moves",
    SI_KEYBIND_ACCOUNTHOLD_RESERVE       = "Place Hold",

    -- Settings panel
    SI_ACCOUNTHOLD_SETTINGS_TITLE                = "Quartermaster",
    SI_ACCOUNTHOLD_SETTINGS_GENERAL              = "General",
    SI_ACCOUNTHOLD_SETTINGS_SCANNING             = "Scanning",
    SI_ACCOUNTHOLD_SETTINGS_NOTIFICATIONS        = "Notifications",
    SI_ACCOUNTHOLD_SETTINGS_CONTROLS             = "Controls",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_ON_LOGIN        = "Scan on login",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_INTERVAL        = "Scan interval (minutes)",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_CRAFT_BAG       = "Include craft bag",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_CRAFT_NOTE      = "Show craft bag contents in the Quartermaster list. Read live from the bag, never stored, so it is always up to date. Turn off to keep the list to items held by characters and containers.",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_ON_BANK         = "Scan when opening the bank",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_ON_GUILDBANK    = "Scan when opening a guild bank",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_ON_HOUSE        = "Scan when opening house storage",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_ANNOUNCE        = "Announce scan results in chat",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_ANNOUNCE_TIP    = "When on, each scan prints how many items were indexed. When off, results are only recorded to diagnostics.",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_NOW             = "Scan now",
    SI_ACCOUNTHOLD_SETTINGS_SCAN_NOW_TIP         = "Immediately re-index every container currently open (bag, bank, guild bank, house storage).",
    SI_ACCOUNTHOLD_BTN_SCAN_NOW                  = "Scan",
    SI_ACCOUNTHOLD_SETTINGS_PROMPT_LOGIN         = "Notify once on character login",
    SI_ACCOUNTHOLD_SETTINGS_PROMPT_BANK          = "Prompt at bank",
    SI_ACCOUNTHOLD_SETTINGS_PROMPT_GUILDBANK     = "Prompt at guild bank",
    SI_ACCOUNTHOLD_SETTINGS_PROMPT_HOUSE         = "Prompt at house storage",
    SI_ACCOUNTHOLD_SETTINGS_PANEL_BANK           = "Show action panel at bank",
    SI_ACCOUNTHOLD_SETTINGS_PANEL_GUILDBANK      = "Show action panel at guild bank",
    SI_ACCOUNTHOLD_SETTINGS_PANEL_HOUSE          = "Show action panel at house storage",
    SI_ACCOUNTHOLD_SETTINGS_PANEL_TIP            = "Independent of the chat / center-screen prompt above. Disable to hide the on-screen Quartermaster panel at this container even when there are pending items.",
    SI_ACCOUNTHOLD_SETTINGS_CONFIRM_EACH         = "Confirm each move",
    SI_ACCOUNTHOLD_SETTINGS_DEFAULT_ROUTE        = "Default deposit route",
    SI_ACCOUNTHOLD_SETTINGS_DEFAULT_ROUTE_TIP    = "Pre-selected in the Place Hold dialog. The dialog still lets you cycle to any route reachable from the current scene.",
    SI_ACCOUNTHOLD_SETTINGS_ROUTE_BANK           = "Account Bank",
    SI_ACCOUNTHOLD_SETTINGS_AUTO_EQUIP           = "Auto-equip eligible holds",
    SI_ACCOUNTHOLD_SETTINGS_NOTIFY_STYLE         = "Notification style",
    SI_ACCOUNTHOLD_SETTINGS_NOTIFY_CHAT          = "Chat",
    SI_ACCOUNTHOLD_SETTINGS_NOTIFY_CENTER        = "Center screen",
    SI_ACCOUNTHOLD_SETTINGS_NOTIFY_BOTH          = "Both",
    SI_ACCOUNTHOLD_SETTINGS_NOTIFY_PREVIEW       = "Sample notification — this is how Quartermaster will alert you.",
    SI_ACCOUNTHOLD_SETTINGS_RETENTION            = "Hold retention (days)",
    SI_ACCOUNTHOLD_SETTINGS_DEBUG                = "Debug logging",

    -- Optional features (Epic 0001 per-feature gates). Rows are generated only
    -- for features that are implemented AND that this account is allowed to
    -- use; a user may turn an allowed feature off but can never turn on one
    -- they are gated out of. See config/FeatureAccess.lua / src/Features.lua.
    SI_ACCOUNTHOLD_SETTINGS_FEATURES             = "Optional Features",
    SI_ACCOUNTHOLD_SETTINGS_FEATURE_TIP          = "Turn this optional feature off if you don't want it. You can only disable features your account is allowed to use — you cannot enable one you are gated out of.",
    SI_ACCOUNTHOLD_FEATURE_BUILDCREATOR          = "Build Creator",
    SI_ACCOUNTHOLD_FEATURE_PRIORITIES            = "Priorities",
    -- Shown when a wanted set has no entry in data/setSources.lua. Surfaced
    -- explicitly rather than omitted: a plan that silently drops a set looks
    -- complete when it is not.
    SI_ACCOUNTHOLD_SOURCE_UNKNOWN                = "Source unknown",
    SI_ACCOUNTHOLD_PRIO_LIST_FAILED              = "Priorities could not open. Use Show recent diagnostics for details.",
    SI_ACCOUNTHOLD_FEATURE_GUILDSTOREINDEXER     = "Guild Store Indexer",
    SI_ACCOUNTHOLD_FEATURE_TIPMENU               = "Tip Menu",

    -- Per-character permissions (who can request items / act as holding space)
    SI_ACCOUNTHOLD_SETTINGS_CHARACTERS           = "Character Permissions",
    SI_ACCOUNTHOLD_SETTINGS_CHAR_INTRO           = "Every character can always deposit reserved items. Use these toggles to choose which characters may REQUEST items (place holds). Characters that are just extra storage can be switched off here so they can hold and deposit but never request.",
    SI_ACCOUNTHOLD_SETTINGS_CHAR_CAN_REQUEST     = "%s — can request items",
    SI_ACCOUNTHOLD_SETTINGS_CHAR_NONE            = "No characters scanned yet. Log into each character once to populate this list.",

    -- Errors / log
    SI_ACCOUNTHOLD_ERR_MOVE_FAILED       = "Move failed: %s",
    SI_ACCOUNTHOLD_ERR_DEST_FULL         = "Destination container is full.",
    SI_ACCOUNTHOLD_ERR_NO_SOURCE         = "Source item no longer present.",
    -- Space-blocked alerts + retry (features F1 / F2)
    SI_ACCOUNTHOLD_ALERT_BANK_FULL       = "Not enough room in the container for %d reserved item(s). Free space, then retry.",
    SI_ACCOUNTHOLD_ALERT_INV_FULL        = "Not enough inventory space for %d reserved item(s). Free space, then retry.",
    SI_ACCOUNTHOLD_ALERT_RETRY_NONE      = "Nothing pending to retry.",
    SI_ACCOUNTHOLD_ALERT_RETRY_DONE      = "Retry queued %d item(s).",
    SI_ACCOUNTHOLD_LOG_HOLD_CREATED      = "Hold created: %s x%d (for %s)",
    SI_ACCOUNTHOLD_LOG_HOLD_DEPOSITED    = "Deposited %s x%d into %s",
    SI_ACCOUNTHOLD_LOG_HOLD_DELIVERED    = "Delivered %s x%d to %s",
    SI_ACCOUNTHOLD_LOG_HOLD_CANCELLED    = "Hold cancelled: %s",
    -- Refused: deselecting the last piece would leave a set reservation that
    -- matches nothing and can never complete. Cancel the hold instead.
    SI_ACCOUNTHOLD_LOG_HOLD_LAST_PIECE   = "Kept the last selected piece; cancel the reservation to want none of it.",
    SI_ACCOUNTHOLD_LOG_HOLD_PURGED       = "Purged %d expired hold(s).",
    SI_ACCOUNTHOLD_LOG_CANCELLED_N       = "Cancelled %d hold(s).",

    -- ----------------------------------------------------------------
    -- Account Gear inventory tab
    -- ----------------------------------------------------------------
    SI_ACCOUNTHOLD_TAB_LABEL             = "Account Gear",
    -- Label for the Character-screen keybind-strip button that opens the
    -- full Quartermaster blade on console/gamepad.
    SI_ACCOUNTHOLD_OPEN_ENTRY            = "Quartermaster",
    SI_ACCOUNTHOLD_FILTER_ALL            = "All",
    SI_ACCOUNTHOLD_FILTER_BOUND_ONLY     = "Bound only",
    SI_ACCOUNTHOLD_FILTER_UNBOUND_ONLY   = "Unbound only",
    -- A reserves the concrete item/stack; X reserves the whole set (by setId).
    SI_ACCOUNTHOLD_BTN_PLACE_ITEM_HOLD   = "Reserve Item",
    SI_ACCOUNTHOLD_BTN_PLACE_SET_HOLD    = "Reserve Set",
    SI_ACCOUNTHOLD_BTN_CANCEL_HOLD       = "Cancel Hold",
    SI_ACCOUNTHOLD_BTN_CANCEL_HOLD_FOR   = "Cancel %s's Hold",
    SI_ACCOUNTHOLD_BTN_REFRESH           = "Refresh",
    SI_ACCOUNTHOLD_SUMMARY_HOLDS         = "Active holds: %d",

    -- Reset / wipe section in Settings
    SI_ACCOUNTHOLD_SETTINGS_RESET        = "Reset / Clear Data",
    SI_ACCOUNTHOLD_WIPE_SNAPSHOT         = "Clear scanned inventory",
    SI_ACCOUNTHOLD_WIPE_SNAPSHOT_TIP     = "Forget every scanned character / bank / guild bank / house storage entry. Holds are preserved. Re-scan triggers automatically when each character next logs in.",
    SI_ACCOUNTHOLD_WIPE_HOLDS            = "Clear all holds",
    SI_ACCOUNTHOLD_WIPE_HOLDS_TIP        = "Cancel and remove every active hold. Scanned inventory is preserved.",
    SI_ACCOUNTHOLD_WIPE_ALL              = "Wipe everything",
    SI_ACCOUNTHOLD_WIPE_ALL_TIP          = "Reset the addon to a clean state — scanned inventory, holds, priorities AND saved builds. Settings are preserved. There is no undo.",
    SI_ACCOUNTHOLD_BTN_WIPE              = "Clear",
    SI_ACCOUNTHOLD_BTN_WIPE_ALL          = "Wipe",
    SI_ACCOUNTHOLD_DIALOG_CONFIRM_WIPE_TITLE = "Confirm Reset",
    SI_ACCOUNTHOLD_CONFIRM_WIPE_SNAPSHOT = "Forget every scanned inventory entry?\n\nThis cannot be undone. Holds will be kept; characters will re-scan on next login.",
    SI_ACCOUNTHOLD_CONFIRM_WIPE_HOLDS    = "Cancel and remove every active hold?\n\nThis cannot be undone. Scanned inventory is preserved.",
    SI_ACCOUNTHOLD_CONFIRM_WIPE_ALL      = "Wipe ALL inventory data, holds, priorities and saved builds?\n\nThis is a full reset. Settings are preserved. This cannot be undone.",
    SI_ACCOUNTHOLD_DIALOG_WIPE_CONFIRM   = "Yes, wipe",
    SI_ACCOUNTHOLD_WIPE_DONE             = "Quartermaster data cleared (scope: %s).",

    -- Gamepad tab: "Clear My Holds" keybind (QUATERNARY, bulk action). Cancels
    -- only holds reserved for the current character; full wipes live in Settings.
    SI_ACCOUNTHOLD_CLEAR_MY_HOLDS        = "Clear My Holds",
    SI_ACCOUNTHOLD_CLEAR_MY_HOLDS_TITLE  = "Clear My Holds",
    SI_ACCOUNTHOLD_CONFIRM_CLEAR_MY_HOLDS = "Cancel every active hold reserved for this character?\n\nOther characters' holds and your scanned inventory are not affected.",
    SI_ACCOUNTHOLD_CLEAR_MY_HOLDS_CONFIRM = "Yes, clear",

    -- Gamepad bank: our third tab (alongside Withdraw / Deposit).
    SI_ACCOUNTHOLD_BANK_TAB_EMPTY        = "No reserved items to move at this bank.",
    SI_ACCOUNTHOLD_BANK_APPROVE_WITHDRAW = "Withdraw",
    SI_ACCOUNTHOLD_BANK_APPROVE_DEPOSIT  = "Deposit",
    SI_ACCOUNTHOLD_BANK_APPROVE_ALL      = "Withdraw All",
    SI_ACCOUNTHOLD_BANK_SECTION_WITHDRAW = "Reserved for You (Withdraw)",
    SI_ACCOUNTHOLD_BANK_SECTION_DEPOSIT  = "Needed Elsewhere (Deposit)",
    SI_ACCOUNTHOLD_BANK_SECTION_PENDING  = "Reserved (pending)",
    -- Feedback when an approve action moved nothing. The two cases have
    -- opposite causes and opposite remedies, so they must not share a string:
    -- a WITHDRAW pulls from the open container, a DEPOSIT pushes from the
    -- player's own bags. Telling someone whose character no longer carries an
    -- item to "reopen the bank" sends them chasing the wrong problem.
    SI_ACCOUNTHOLD_BANK_MOVE_NONE        = "Couldn't move that item — it may no longer be in the bank. Try reopening the bank.",
    SI_ACCOUNTHOLD_BANK_MOVE_NONE_DEPOSIT = "Couldn't deposit that item — this character isn't carrying it any more. The reservation stays active for whichever character has it.",
    SI_ACCOUNTHOLD_BANK_MOVE_OK          = "Moved %d reserved item(s).",
    SI_ACCOUNTHOLD_BANK_MOVE_FAILED      = "%d reserved item move(s) did not complete. Check the item is still there and you have space, then try again.",
    -- Immediate feedback when work is enqueued but not yet engine-confirmed.
    -- The confirmed total is announced separately by MOVE_OK on completion.
    SI_ACCOUNTHOLD_BANK_MOVE_QUEUED      = "Queued %d reserved item(s)...",

    -- Epic 0002 part 2: Quartermaster Armory - create / equip / auto-equip /
    -- save into the in-game Armory (ui/ArmoryScreen_Gamepad.lua and
    -- src/BuildEquip.lua). Each module also carries the same English text as
    -- its L() fallback, so a missing registration still renders readable text.
    SI_ACCOUNTHOLD_ARMORY_AUTO_FAILED = "Could not change auto-equip for that build.",
    SI_ACCOUNTHOLD_ARMORY_AUTO_INFO = "Auto-equip never acts in combat. A swap that triggers mid-fight waits until combat ends.",
    SI_ACCOUNTHOLD_ARMORY_AUTO_NEEDS_LOADOUT = "Save what you are wearing to this build first - there is nothing to equip yet.",
    SI_ACCOUNTHOLD_ARMORY_AUTO_NO_BOSS = "To add a specific boss, open this page while that boss's health bar is on screen.",
    SI_ACCOUNTHOLD_ARMORY_AUTO_NO_RULES = "No conditions yet. Add one below while you are in the place you want.",
    SI_ACCOUNTHOLD_ARMORY_AUTO_OFF = "Auto-equip is off for this build.",
    SI_ACCOUNTHOLD_ARMORY_AUTO_OFF_ROW = "Auto-equip: Off",
    SI_ACCOUNTHOLD_ARMORY_AUTO_ON = "Auto-equip is on for this build.",
    SI_ACCOUNTHOLD_ARMORY_AUTO_ON_EMPTY = "Auto-equip is on, but it has no conditions yet, so it will not do anything until you add one.",
    SI_ACCOUNTHOLD_ARMORY_AUTO_ON_ROW = "Auto-equip: On (%d condition(s))",
    SI_ACCOUNTHOLD_ARMORY_AUTO_TURN_OFF = "Turn auto-equip off",
    SI_ACCOUNTHOLD_ARMORY_AUTO_TURN_ON = "Turn auto-equip on",
    SI_ACCOUNTHOLD_ARMORY_BACK_BAR = "Skills - back bar",
    SI_ACCOUNTHOLD_ARMORY_BODY_AUTO = "Equip this build automatically when you enter a zone, dungeon or trial, or when a boss appears. Off unless you turn it on.",
    SI_ACCOUNTHOLD_ARMORY_BODY_BUILD = "X equips this build. Y saves what you are wearing into it.",
    SI_ACCOUNTHOLD_ARMORY_BODY_EXPORT_SLOT = "Pick the in-game Armory slot. Nothing is overwritten until you confirm at an Armory Station.",
    SI_ACCOUNTHOLD_ARMORY_BODY_FOOD = "This food is eaten each time you equip the build yourself. Auto-equip does not re-eat it when the same build is put back on.",
    SI_ACCOUNTHOLD_ARMORY_CANCEL = "Cancel",
    SI_ACCOUNTHOLD_ARMORY_CAPTURE = "Save what I am wearing to this build",
    SI_ACCOUNTHOLD_ARMORY_CAPTURED = "Saved what you are wearing to \"%s\": %d gear, %d skills, %d champion stars.",
    SI_ACCOUNTHOLD_ARMORY_CHAMPION = "Champion",
    SI_ACCOUNTHOLD_ARMORY_CONFIRM_CAPTURE = "Replace \"%s\" with what I am wearing",
    SI_ACCOUNTHOLD_ARMORY_EQUIP = "Equip this build",
    SI_ACCOUNTHOLD_ARMORY_EQUIP_ERROR = "The Quartermaster Armory hit an error. Details are in the diagnostics.",
    SI_ACCOUNTHOLD_ARMORY_EQUIP_SHORT = "Equip Build",
    SI_ACCOUNTHOLD_ARMORY_EXPORT_CANCEL = "Cancel the pending save",
    SI_ACCOUNTHOLD_ARMORY_EXPORT_PENDING = "Waiting: \"%s\" into Armory slot %d.",
    SI_ACCOUNTHOLD_ARMORY_EXPORT_ROW = "Save a build into the in-game Armory",
    SI_ACCOUNTHOLD_ARMORY_EXPORT_TO = "Save to an in-game Armory slot",
    SI_ACCOUNTHOLD_ARMORY_FOOD_CLEAR = "No food for this build",
    SI_ACCOUNTHOLD_ARMORY_FOOD_FAILED = "Could not set the food for that build.",
    SI_ACCOUNTHOLD_ARMORY_FOOD_NONE = "No food or drink in your backpack. Carry the one you want, then come back.",
    SI_ACCOUNTHOLD_ARMORY_FOOD_ROW = "Food: %s",
    SI_ACCOUNTHOLD_ARMORY_FRONT_BAR = "Skills - front bar",
    SI_ACCOUNTHOLD_ARMORY_GEAR_SAVED = "Weapons & apparel: %d saved",
    SI_ACCOUNTHOLD_ARMORY_HDR_ADD = "Add a condition",
    SI_ACCOUNTHOLD_ARMORY_HDR_ASSIGNED = "Assigned",
    SI_ACCOUNTHOLD_ARMORY_HDR_AUTO = "Auto-equip",
    SI_ACCOUNTHOLD_ARMORY_HDR_CONDITIONS = "Conditions",
    SI_ACCOUNTHOLD_ARMORY_HDR_CONFIRM = "Are you sure?",
    SI_ACCOUNTHOLD_ARMORY_HDR_EXPORT = "Saving to the in-game Armory",
    SI_ACCOUNTHOLD_ARMORY_HDR_EXPORT_SLOT = "Choose an Armory slot",
    SI_ACCOUNTHOLD_ARMORY_HDR_FOOD = "Food and drink in your backpack",
    SI_ACCOUNTHOLD_ARMORY_HDR_FOOD_TITLE = "Food",
    SI_ACCOUNTHOLD_ARMORY_HDR_LOADOUT = "Equipment saved in this build",
    SI_ACCOUNTHOLD_ARMORY_HDR_PENDING = "Pending",
    SI_ACCOUNTHOLD_ARMORY_HDR_QUICK = "Quick equip - %s",
    SI_ACCOUNTHOLD_ARMORY_IMPORT_LOADOUT = "Its gear, skills and champion stars were saved too, so it can be equipped from here.",
    SI_ACCOUNTHOLD_ARMORY_NONE = "none",
    SI_ACCOUNTHOLD_ARMORY_NO_ARMORY = "No unlocked Armory builds found on this character. Unlock one at an Armory Station first.",
    SI_ACCOUNTHOLD_ARMORY_NO_ARMORY_API_SAVE = "This client does not expose the Armory API, so nothing can be saved into it.",
    SI_ACCOUNTHOLD_ARMORY_NO_LOADOUT = "Nothing saved to equip yet. Press Y (Save Build) to save what you are wearing now.",
    SI_ACCOUNTHOLD_ARMORY_QUICK_ROW = "Equip %s",
    SI_ACCOUNTHOLD_ARMORY_RULE_ADDED = "Added: %s.",
    SI_ACCOUNTHOLD_ARMORY_RULE_ANY_BOSS = "When any boss appears in %s",
    SI_ACCOUNTHOLD_ARMORY_RULE_BOSS = "When %s appears",
    SI_ACCOUNTHOLD_ARMORY_RULE_BOSS_IN = "When %s appears (%s)",
    SI_ACCOUNTHOLD_ARMORY_RULE_FAILED = "Could not add that condition (the list may be full).",
    SI_ACCOUNTHOLD_ARMORY_RULE_REMOVED = "Removed: %s.",
    SI_ACCOUNTHOLD_ARMORY_RULE_REMOVE_FAILED = "Could not remove that condition.",
    SI_ACCOUNTHOLD_ARMORY_RULE_ZONE = "When I enter %s",
    SI_ACCOUNTHOLD_ARMORY_SAVE_SHORT = "Save Build",
    SI_ACCOUNTHOLD_ARMORY_SUB_ADD = "Press A to add",
    SI_ACCOUNTHOLD_ARMORY_SUB_ARMORY_SLOT = "Armory slot %d",
    SI_ACCOUNTHOLD_ARMORY_SUB_AUTO = "Zones, dungeons, trials and boss fights",
    SI_ACCOUNTHOLD_ARMORY_SUB_AUTO_IS_OFF = "Currently off",
    SI_ACCOUNTHOLD_ARMORY_SUB_AUTO_IS_ON = "Currently on",
    SI_ACCOUNTHOLD_ARMORY_SUB_AUTO_ON = "Auto-equip on",
    SI_ACCOUNTHOLD_ARMORY_SUB_CAPTURE = "Gear, both skill bars and champion stars",
    SI_ACCOUNTHOLD_ARMORY_SUB_CONFIRM_CAPTURE = "The gear, skills and stars saved in it now are overwritten",
    SI_ACCOUNTHOLD_ARMORY_SUB_EMPTY = "Empty",
    SI_ACCOUNTHOLD_ARMORY_SUB_EQUIP = "Gear, skills, champion stars and food",
    SI_ACCOUNTHOLD_ARMORY_SUB_EQUIPPED = "Equipped",
    SI_ACCOUNTHOLD_ARMORY_SUB_EXPORT_PENDING = "Waiting for an Armory Station (slot %d)",
    SI_ACCOUNTHOLD_ARMORY_SUB_EXPORT_TO = "Equips it, then saves at the next Armory Station",
    SI_ACCOUNTHOLD_ARMORY_SUB_FOOD = "Eaten when this build is equipped",
    SI_ACCOUNTHOLD_ARMORY_SUB_GEAR_HERE = "%d of %d on this character",
    SI_ACCOUNTHOLD_ARMORY_SUB_GEAR_MISSING = "Not found: %s",
    SI_ACCOUNTHOLD_ARMORY_SUB_HOW = "How it works",
    SI_ACCOUNTHOLD_ARMORY_SUB_OVERWRITE = "Will be overwritten after you confirm at a station",
    SI_ACCOUNTHOLD_ARMORY_SUB_PRESS_EQUIP = "Press A to equip",
    SI_ACCOUNTHOLD_ARMORY_SUB_QUEUED = "Queued until out of combat",
    SI_ACCOUNTHOLD_ARMORY_SUB_REMOVE = "Press A to remove",
    SI_ACCOUNTHOLD_ARMORY_BODY_CHARACTERS = "Create builds, save what you are wearing into them, and equip them with one press. Plan the sets each character still needs.",
    SI_ACCOUNTHOLD_ARMORY_BODY_EXPORT = "Quartermaster equips the build first, then saves it at the next Armory Station you open - after you confirm.",
    SI_ACCOUNTHOLD_ARMORY_EXPORT_1 = "1. Open one of your builds and choose \"Save to an in-game Armory slot\".",
    SI_ACCOUNTHOLD_ARMORY_EXPORT_2 = "2. Quartermaster equips that build on this character - only ever out of combat.",
    SI_ACCOUNTHOLD_ARMORY_EXPORT_3 = "3. Open any Armory Station. Quartermaster asks to save the build into the slot you picked; press A to save.",
    SI_ACCOUNTHOLD_ARMORY_EXPORT_4 = "Why the extra step: ESO's SaveArmoryBuild only works at an Armory Station and saves what you are wearing, so the build has to be on you first.",
    SI_ACCOUNTHOLD_BUILDEQ_ALREADY = "\"%s\" is already equipped.",
    SI_ACCOUNTHOLD_BUILDEQ_AMBIGUOUS = "Auto-equip skipped: more than one build matches here (%s). Remove a condition so only one does.",
    SI_ACCOUNTHOLD_BUILDEQ_AUTO = "Auto-equip: \"%s\" (%s).",
    SI_ACCOUNTHOLD_BUILDEQ_CP = "Champion stars",
    SI_ACCOUNTHOLD_BUILDEQ_CP_LOCKED = "champion system not unlocked",
    SI_ACCOUNTHOLD_BUILDEQ_DEFERRED = "Quartermaster will equip \"%s\" as soon as you are out of combat (%s).",
    SI_ACCOUNTHOLD_BUILDEQ_DISABLED = "The Quartermaster Armory is switched off.",
    SI_ACCOUNTHOLD_BUILDEQ_DONE = "Equipped \"%s\" (%s).",
    SI_ACCOUNTHOLD_BUILDEQ_DONE_PROBLEMS = "Equipped \"%s\" (%s) with problems - %s.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_BAD_SLOT = "That Armory slot is not unlocked on this character.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_BODY = "Save the Quartermaster build \"%s\" into Armory slot %d (%s)? This replaces what is saved in that slot.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_BUSY = "Quartermaster is still equipping \"%s\". Reopen the Armory Station when it has finished.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_COMBAT = "You cannot save to the Armory in combat.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_COOLDOWN = "The Armory is on cooldown for %d more second(s). Try again then.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_DONE = "Saved \"%s\" into Armory slot %d.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FAILED = "Saving to the Armory failed. Nothing was changed.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FORGET = "Forget export",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FORGOTTEN = "Export cancelled. Nothing was saved.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_LATER = "Not now",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NEXT = "Now open an Armory Station: Quartermaster will ask to save \"%s\" into Armory slot %d.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NOT_ON = "\"%s\" is not fully equipped (%d difference(s)), so it was not offered for the Armory. Equip it from the Quartermaster Armory first.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_API = "This client has no Armory save function. Nothing was saved.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_DIALOG = "This client could not show the Armory save prompt. Use Save Build (Y) on the Armory Station instead.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_LOADOUT = "Save a loadout to this build first - the Armory stores what you are wearing.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_REFUSED = "The Armory did not save the build: %s. The export is still pending.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_SAVE = "Save",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_STALE = "That export is no longer pending. Nothing was saved.",
    SI_ACCOUNTHOLD_BUILDEQ_EXPORT_TITLE = "Save to the Armory",
    SI_ACCOUNTHOLD_BUILDEQ_FOOD = "Food",
    SI_ACCOUNTHOLD_BUILDEQ_HANDLER_FAILED = "Quartermaster Armory: %s hit an error and stopped. Details are in the diagnostics.",
    SI_ACCOUNTHOLD_BUILDEQ_MORE = "%d more",
    SI_ACCOUNTHOLD_BUILDEQ_NOTHING = "nothing changed",
    SI_ACCOUNTHOLD_BUILDEQ_NO_BUILD = "That build no longer exists.",
    SI_ACCOUNTHOLD_BUILDEQ_NO_LOADOUT = "\"%s\" has nothing saved to equip yet. Save what you are wearing to it first (Y).",
    SI_ACCOUNTHOLD_BUILDEQ_NO_TICKER = "This client cannot schedule the equip. Nothing was changed.",
    SI_ACCOUNTHOLD_BUILDEQ_N_CP = "%d stars",
    SI_ACCOUNTHOLD_BUILDEQ_N_FOOD = "food",
    SI_ACCOUNTHOLD_BUILDEQ_N_GEAR = "%d gear",
    SI_ACCOUNTHOLD_BUILDEQ_N_SKILLS = "%d skills",
    SI_ACCOUNTHOLD_BUILDEQ_OTHER_CHAR = "That build belongs to another character. Assign it to this character first.",
    SI_ACCOUNTHOLD_BUILDEQ_PAUSED = "Paused equipping \"%s\" (%s). It will finish when you are out of combat.",
    SI_ACCOUNTHOLD_BUILDEQ_SAVE_CODE = "result code %s",
    SI_ACCOUNTHOLD_BUILDEQ_SKILLS = "Skills",
    SI_ACCOUNTHOLD_BUILDEQ_STALE = "Skipped auto-equip of \"%s\": the fight or zone that triggered it is over.",
    SI_ACCOUNTHOLD_BUILDEQ_STARTED = "Equipping \"%s\"...",
    SI_ACCOUNTHOLD_BUILDEQ_STEP_FAILED = "Quartermaster stopped equipping the build because of an error. Details are in the diagnostics.",
    SI_ACCOUNTHOLD_BUILDEQ_STOPPED_GATE = "Quartermaster stopped equipping: the Armory was switched off.",
    SI_ACCOUNTHOLD_BUILDEQ_WHY_BOSS = "%s appeared",
    SI_ACCOUNTHOLD_BUILDEQ_WHY_BOSS_GONE = "boss fight over",
    SI_ACCOUNTHOLD_BUILDEQ_WHY_COMBAT = "you are in combat",
    SI_ACCOUNTHOLD_BUILDEQ_WHY_DEAD = "you are dead",
    SI_ACCOUNTHOLD_BUILDEQ_WHY_NOAPI = "this client cannot report combat state",
    SI_ACCOUNTHOLD_BUILDEQ_WHY_ZONE = "entered %s",
}

-- Register every string with the game's localization system so SI_* identifiers
-- resolve via GetString().
for stringId, value in pairs(strings) do
    ZO_CreateStringId(stringId, value)
end

-- Also expose via the addon namespace for code paths that prefer table lookup
-- (e.g. dialog body strings that need format args).
AccountHold = AccountHold or {}
AccountHold.Strings = strings
