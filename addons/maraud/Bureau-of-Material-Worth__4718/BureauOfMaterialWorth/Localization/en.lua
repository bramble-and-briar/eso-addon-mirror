local strings = {
    -- Settings panel
    SI_BMW_PANEL_NAME = "Bureau of Material Worth",
    SI_BMW_PANEL_DISPLAY_NAME = "|c6FCB9FBureau|r of Material Worth",
    SI_BMW_PANEL_INTRO = "|c6FCB9FCraft Bag value at a glance.|r Bureau of Material Worth sums the market value of everything in your Craft Bag and shows it in a small panel beside the bag, with an optional breakdown by crafting profession.",
    SI_BMW_PANEL_OVERVIEW = "|c8C8A82• Uses LibPrice (Master Merchant / Tamriel Trade Centre / Arkadius' Trade Tools)\n• Computes lazily, only while the Craft Bag is open\n• Updates incrementally as you deposit or withdraw materials|r",

    -- Live at-a-glance status block at the top of the panel. It reflects the
    -- current configuration (not the live bag value): the valuation only runs
    -- while the Craft Bag is open, so a value readout here would be stale or
    -- zero. On = green, off = muted grey; mode rows (order/baseline) use the
    -- neutral label tone. Each row reads through the same getter as its control.
    SI_BMW_STATUS_TITLE = "|cC5C29ECurrent status|r",
    SI_BMW_STATUS_ON = "on",
    SI_BMW_STATUS_OFF = "off",
    SI_BMW_STATUS_LABEL_BREAKDOWN = "Category breakdown:",
    SI_BMW_STATUS_LABEL_SORT = "Category order:",
    SI_BMW_STATUS_SORT_BY_VALUE = "by value",
    SI_BMW_STATUS_SORT_BY_PROFESSION = "by profession",
    SI_BMW_STATUS_LABEL_COLOR_SCALE = "Color gold by value:",
    SI_BMW_STATUS_LABEL_VALUE_HISTORY = "Value history:",
    SI_BMW_STATUS_LABEL_PROFILE = "Account label:",
    SI_BMW_STATUS_LABEL_NOTIFY = "Announce in chat:",
    SI_BMW_STATUS_LABEL_GUILD_STORE = "In guild store:",
    SI_BMW_STATUS_LABEL_DELTA = "Change baseline:",

    SI_BMW_HEADER_DISPLAY = "|cC5C29EDisplay|r",
    SI_BMW_HEADER_DIAGNOSTICS = "|cC5C29EDiagnostics|r",

    -- Category-breakdown submenu: the master "show breakdown" toggle plus the
    -- three controls that only do anything while it is on (icons, color, sort).
    SI_BMW_SUBMENU_BREAKDOWN_NAME = "Category breakdown",
    SI_BMW_SUBMENU_BREAKDOWN_DESCRIPTION = "|c8C8A82Break the grand total down into per-profession rows, and tune how those rows look. The icon, color, and sort options below only take effect while the breakdown is shown.|r",

    SI_BMW_SETTING_CATEGORY_BREAKDOWN_NAME = "Show category breakdown",
    SI_BMW_SETTING_CATEGORY_BREAKDOWN_TOOLTIP = "Show per-profession subtotals (Blacksmithing, Alchemy, Provisioning, and so on) beneath the grand total. When off, only the grand total is shown.",
    SI_BMW_SETTING_CATEGORY_ICONS_NAME = "Show category icons",
    SI_BMW_SETTING_CATEGORY_ICONS_TOOLTIP = "Show a small profession icon to the left of each category name, so the rows are quicker to scan. \"Other\" uses a generic Craft Bag icon. Has no effect while the category breakdown is off.",
    SI_BMW_SETTING_COLOR_SCALE_NAME = "Color gold by value",
    SI_BMW_SETTING_COLOR_SCALE_TOOLTIP = "Tint each category's gold figure by how large it is - dim for small amounts up to a hot color for the biggest - so your most valuable categories stand out at a glance. When off, all figures use the same gold tone. Has no effect while the category breakdown is off.",
    SI_BMW_SETTING_SORT_BY_VALUE_NAME = "Sort categories by value",
    SI_BMW_SETTING_SORT_BY_VALUE_TOOLTIP = "Order the category rows by descending gold value, so your most valuable holdings are always on top. When off, they follow the fixed profession order. Has no effect while the category breakdown is off.",
    SI_BMW_SETTING_DETAIL_COLUMNS_NAME = "Detail table columns",
    SI_BMW_SETTING_DETAIL_COLUMNS_TOOLTIP = "Basic shows material, quantity, and value for quicker scanning. Analytics also shows cumulative value share and price change. The Changes view always keeps its delta, share, and status columns.",
    SI_BMW_SETTING_DETAIL_COLUMNS_BASIC = "Basic",
    SI_BMW_SETTING_DETAIL_COLUMNS_ANALYTICS = "Analytics",
    SI_BMW_SETTING_PRICE_TREND_THRESHOLD_NAME = "Significant price movement (%)",
    SI_BMW_SETTING_PRICE_TREND_THRESHOLD_TOOLTIP = "Minimum rise or fall shown in Price dynamics over the trailing seven days. Every movement inside the window is analyzed, so a short one- or two-day spike remains visible even if the price later returns near its starting point.",
    SI_BMW_SETTING_DELTA_MODE_NAME = "Stock-change baseline",
    SI_BMW_SETTING_DELTA_MODE_TOOLTIP = "What the footer's change line compares against. \"Since last review\": the state when you last clicked the change line; new changes accumulate across Craft Bag opens and persist across restarts. \"This session\": works the same way, but resets on logout or /reloadui. A pure price change with the same stock shows no delta. Click the row to inspect the breakdown and mark it reviewed.",
    SI_BMW_SETTING_DELTA_MODE_VISIT = "Since last review",
    SI_BMW_SETTING_DELTA_MODE_SESSION = "This session",
    SI_BMW_SETTING_BACKGROUND_NAME = "Show background",
    SI_BMW_SETTING_BACKGROUND_TOOLTIP = "Draw the dark panel background behind the text. Turn off for plain floating text over the Craft Bag.",
    SI_BMW_SETTING_BORDER_NAME = "Show border",
    SI_BMW_SETTING_BORDER_TOOLTIP = "Draw the panel's border edge. Turn off for a cleaner, frameless look.",
    SI_BMW_SETTING_VALUE_HISTORY_NAME = "Show value history",
    SI_BMW_SETTING_VALUE_HISTORY_TOOLTIP = "Draw a small sparkline of your Craft Bag's total value over time at the bottom of the panel. One point is recorded per login or /reloadui; later Craft Bag opens in the same session do not add another point. The last 90 points are kept. Hover the sparkline for the oldest, newest, and net-change figures.",
    SI_BMW_SETTING_PROFILE_NAME = "Show account label",
    SI_BMW_SETTING_PROFILE_TOOLTIP = "Show your @account handle and current character name on the panel's title line. The Craft Bag is shared across your whole account, so the handle names whose bag this is. Turn off for a cleaner title.",
    SI_BMW_SETTING_NOTIFY_VISIT_NAME = "Chat notifications",
    SI_BMW_SETTING_NOTIFY_VISIT_TOOLTIP = "Off: no automatic messages.\nSummary: Craft Bag value on the first open each session.\nImportant: report stock changes of at least 1%% and new significant seven-day price signals.\nDetailed: summary and price signals plus withdrawal results and completed price updates.",
    SI_BMW_SETTING_NOTIFY_MODE_OFF = "Off",
    SI_BMW_SETTING_NOTIFY_MODE_SUMMARY = "Summary",
    SI_BMW_SETTING_NOTIFY_MODE_IMPORTANT = "Important changes",
    SI_BMW_SETTING_NOTIFY_MODE_DETAILED = "Detailed",
    SI_BMW_SETTING_GUILD_STORE_NAME = "Show in guild store",
    SI_BMW_SETTING_GUILD_STORE_TOOLTIP = "Show the value panel while the guild store is open. It is shifted further left so it does not cover the store's browse panel. Turn off to hide the panel entirely while trading.",
    SI_BMW_SETTING_WIDTH_NAME = "Window width",
    SI_BMW_SETTING_WIDTH_TOOLTIP = "Width of the value panel in pixels. Increase it if long category names or large gold figures look cramped.",
    SI_BMW_SETTING_OFFSET_X_NAME = "Horizontal offset",
    SI_BMW_SETTING_OFFSET_X_TOOLTIP = "Fine-tune the window's horizontal position relative to the Craft Bag panel.",
    SI_BMW_SETTING_OFFSET_Y_NAME = "Vertical offset",
    SI_BMW_SETTING_OFFSET_Y_TOOLTIP = "Fine-tune the window's vertical position relative to the Craft Bag panel.",
    SI_BMW_SETTING_DEBUG_MODE_NAME = "Debug mode",
    SI_BMW_SETTING_DEBUG_MODE_TOOLTIP = "Controls how much diagnostic output the addon prints to chat.",
    SI_BMW_SETTING_REFRESH_NAME = "Refresh prices now",
    SI_BMW_SETTING_REFRESH_TOOLTIP = "Clear the cached prices and recompute the Craft Bag value. Useful after Master Merchant or Tamriel Trade Centre finishes importing fresh data. The same action is available by clicking Market prices on the panel.",

    SI_BMW_HEADER_SAVED_DATA = "|cC5C29ESaved data|r",
    SI_BMW_HISTORY_CLEANUP_BUTTON = "Clean outdated price history",
    SI_BMW_HISTORY_CLEANUP_TOOLTIP = "Run the automatic retention rules now, after confirmation. This does not reset recent history or your settings.",
    SI_BMW_HISTORY_CLEANUP_DESCRIPTION = "Price history is already cleaned automatically on addon load and when prices are recorded; it does not wait for a weekly timer. You may run the same cleanup now. It keeps observations from the last seven days and the latest price baseline, and removes history for materials not observed for 30 days. Only the current account and server are affected. Settings, snapshots, stock-change reports and the total-value chart are preserved.",
    SI_BMW_HISTORY_CLEANUP_SAVE_NOTICE = "Cleanup takes effect in memory immediately. The file on disk is updated at your next normal logout or /reloadui. You do not need to reload immediately; the addon will not reload automatically.",
    SI_BMW_HISTORY_CLEANUP_CONFIRM_TITLE = "Clean outdated price history?",
    SI_BMW_HISTORY_CLEANUP_CONFIRM_BODY = "Remove outdated price observations for the current account and server?\n\nThe last seven days and latest price baseline are kept. History for materials not observed for 30 days is removed entirely. Settings, snapshots, stock-change reports and the total-value chart are not reset. Deleted observations cannot be restored.\n\nChanges are saved to disk at your next normal logout or /reloadui; no automatic reload will occur.",
    SI_BMW_HISTORY_CLEANUP_ACCEPT = "Clean history",
    SI_BMW_HISTORY_CLEANUP_CANCEL = "Cancel",
    SI_BMW_HISTORY_CLEANUP_RESULT_TITLE = "Last manual cleanup",
    SI_BMW_HISTORY_CLEANUP_PENDING = "Manual cleanup has not been run this session.",
    SI_BMW_HISTORY_CLEANUP_EMPTY = "No price history has been recorded yet. Nothing was deleted.",
    SI_BMW_HISTORY_CLEANUP_NO_CHANGE = "Materials checked: %s. No outdated data was found; nothing was deleted.",
    SI_BMW_HISTORY_CLEANUP_RESULT = "Materials checked: %s\nPrice observations removed: %s\nMaterial histories removed: %s\nPrice observations retained: %s\nHistory-string reduction: %s bytes (not the total save-file size).",
    SI_BMW_HISTORY_CLEANUP_UNAVAILABLE = "Price-history cleanup is unavailable because the valuation module is not loaded.",

    -- Window
    -- Account/character label on the title line. %s = @account handle, %s =
    -- character name. The Craft Bag is account-wide, so the handle leads.
    SI_BMW_PROFILE_ACCOUNT_CHAR = "%s · %s",
    -- %d = occupied slots (distinct materials), %s = classic 200-item stacks,
    -- %s = total item count.
    SI_BMW_WINDOW_SUBTITLE = "%d slots · %s stacks · %s items",
    SI_BMW_WINDOW_EMPTY = "Craft Bag is empty",
    SI_BMW_WINDOW_ADDON_NAME = "Bureau Of Material Worth",
    -- Footer version line. %s = BureauOfMaterialWorth.version, %s =
    -- BureauOfMaterialWorth.releaseDate, both formatted at render time. The
    -- number and date used to be baked into this sentence in every localization,
    -- which meant a release had to edit them in three places and they silently
    -- drifted apart; the text now carries only the wording. The date is shown in
    -- the canonical DD.MM.YYYY form the core stores rather than being re-spelled
    -- per language, so there is exactly one date in the addon.
    SI_BMW_WINDOW_VERSION_DATE = "Addon version %s (%s)",
    -- Category row: the category's share of the grand total. %d = percent.
    SI_BMW_ROW_PERCENT = "%d%%",

    -- Window: per-category hover tooltip
    SI_BMW_TOOLTIP_VALUE = "Value: %s",
    -- Net after the guild-store fees (1% listing + 7% sales). %s = gold amount.
    SI_BMW_TOOLTIP_NET = "Net if sold: %s",
    SI_BMW_TOOLTIP_SLOTS = "Slots (distinct materials): %d",
    SI_BMW_TOOLTIP_STACKS = "Stacks of 200: %s",
    SI_BMW_TOOLTIP_ITEMS = "Items: %s",
    SI_BMW_TOOLTIP_UNPRICED = "Without price: %d slots",
    SI_BMW_TOOLTIP_TOP_CATEGORY = "Most valuable category",
    SI_BMW_TOOLTIP_CLICK_HINT = "Click for the full material list",

    -- Analytical row below Other and its seven-day detail view.
    SI_BMW_PRICE_TREND_ROW = "Price dynamics",
    SI_BMW_PRICE_TREND_TOOLTIP_WINDOW = "Strongest price movements observed anywhere in the trailing seven days (threshold: %d%%).",
    SI_BMW_PRICE_TREND_TOOLTIP_GAINS = "Strong rises: %d",
    SI_BMW_PRICE_TREND_TOOLTIP_LOSSES = "Strong falls: %d",
    SI_BMW_PRICE_TREND_CLICK_HINT = "Click to inspect price movements",
    SI_BMW_PRICE_TREND_TITLE = "Price dynamics",
    SI_BMW_PRICE_TREND_GROUP = "Analysis",
    SI_BMW_PRICE_TREND_CONTEXT = "%d signals · trailing 7 days · threshold %d%%",
    SI_BMW_PRICE_TREND_EMPTY = "No price movements reached the selected threshold yet.",
    SI_BMW_PRICE_TREND_EMPTY_HISTORY = "Price history is still collecting. A material needs two recorded observations before it can produce a signal.",
    SI_BMW_PRICE_TREND_COL_PRICE = "Price",
    SI_BMW_PRICE_TREND_COL_OVERALL = "7 days",
    SI_BMW_PRICE_TREND_COL_GAIN = "Max rise",
    SI_BMW_PRICE_TREND_COL_LOSS = "Max fall",
    SI_BMW_PRICE_TREND_COL_IMPACT = "Value impact",
    SI_BMW_PRICE_TREND_IMPACT_TOOLTIP_TITLE = "Value impact",
    SI_BMW_PRICE_TREND_IMPACT_TOOLTIP_BODY = "Gold gained or lost on the quantity currently held because the current unit price differs from the oldest comparable observation in the trailing seven days: (current price - oldest price) x quantity. This is not the stack's total value.",
    SI_BMW_PRICE_TREND_OVERALL_TOOLTIP_TITLE = "Seven-day change",
    SI_BMW_PRICE_TREND_OVERALL_TOOLTIP_BODY = "The percentage difference between the oldest available recorded price within the trailing seven-day window and the current price. Before a full week is collected, it uses the oldest observation available.",
    SI_BMW_PRICE_TREND_GAIN_TOOLTIP_TITLE = "Maximum rise",
    SI_BMW_PRICE_TREND_GAIN_TOOLTIP_BODY = "The largest percentage increase between any earlier and later recorded price within the trailing seven days. A short spike remains visible even if the price later falls back.",
    SI_BMW_PRICE_TREND_LOSS_TOOLTIP_TITLE = "Maximum fall",
    SI_BMW_PRICE_TREND_LOSS_TOOLTIP_BODY = "The largest percentage decrease between any earlier and later recorded price within the trailing seven days. A short dip remains visible even if the price later recovers.",
    SI_BMW_PRICE_TREND_FOOTER_GAINS = "Rising: %d",
    SI_BMW_PRICE_TREND_FOOTER_LOSSES = "Falling: %d",
    SI_BMW_PRICE_TREND_TOOLTIP_SECTION = "Seven-day movement",
    SI_BMW_PRICE_TREND_TOOLTIP_CURRENT = "Current price: %s",
    SI_BMW_PRICE_TREND_TOOLTIP_OVERALL = "From oldest point: %s",
    SI_BMW_PRICE_TREND_TOOLTIP_MAX_GAIN = "Maximum rise: %s",
    SI_BMW_PRICE_TREND_TOOLTIP_MAX_LOSS = "Maximum fall: %s",
    SI_BMW_PRICE_TREND_TOOLTIP_IMPACT = "Value impact: %s",
    SI_BMW_PRICE_TREND_TOOLTIP_POINTS = "Compared observations: %d",

    -- Detail window: per-category material table (opened by clicking a row)
    SI_BMW_DETAIL_TITLE = "%s - materials",
    SI_BMW_DETAIL_COL_NAME = "Material",
    SI_BMW_DETAIL_COL_QTY = "Qty",
    SI_BMW_DETAIL_COL_VALUE = "Value",
    -- Cumulative-share column: running % of the list's total value, read top-down
    -- (the "what to sell" Pareto cue). Header kept short for the 70px column; the
    -- hover tooltip on the header spells the meaning out in full.
    -- %d = DetailWindow's CUM_CORE_THRESHOLD, the Pareto cut this column colors
    -- up to. Formatted at render time so the header can never quote a threshold
    -- the code no longer uses.
    SI_BMW_DETAIL_COL_CUM = "Cum. %d%%",
    SI_BMW_DETAIL_CUM = "%d%%",
    SI_BMW_DETAIL_CUM_TOOLTIP_TITLE = "Cumulative share",
    SI_BMW_DETAIL_CUM_TOOLTIP_BODY = "Each material's share of this list's total value, added up from the most valuable downward - so it stays the same no matter how you sort the table. Read it on the default |cFFF897by value|r view: the rows down to roughly 80% are the few stacks that hold most of the worth, so sell those first and skip the long tail. The trailing 100% always lands on the cheapest material. Unpriced materials are left out and show a dash.",
    SI_BMW_DETAIL_CUM_THRESHOLD_HINT = "Gold marker: this material reaches the cumulative %d%% threshold.",
    SI_BMW_DETAIL_COL_CHANGE = "Change",
    -- Price-change magnitude; the sign is carried by an up/down arrow + color.
    -- %s = the percentage (one decimal place).
    SI_BMW_DETAIL_GROWTH = "%s%%",
    -- Shown when a material has no recorded price baseline yet, or no price.
    SI_BMW_DETAIL_GROWTH_NEW = "-",
    SI_BMW_DETAIL_EMPTY = "No materials in this category.",
    SI_BMW_DETAIL_EMPTY_BAG = "No materials in the Craft Bag.",
    SI_BMW_DETAIL_EMPTY_SEARCH = "No materials match this search.",
    SI_BMW_DETAIL_EMPTY_FILTER = "No materials match this filter.",
    -- Search box (whole craft bag) in the detail window. The title carries the
    -- number of matches; %d = result count.
    SI_BMW_DETAIL_SEARCH_HINT = "Search...",
    SI_BMW_DETAIL_SEARCH_TITLE = "Search results (%d)",
    SI_BMW_DETAIL_CONTEXT_CATEGORY = "%s · %d materials · %s",
    SI_BMW_DETAIL_CONTEXT_SEARCH = "Search \"%s\" · %d results · %s",
    SI_BMW_DETAIL_CONTEXT_BAG = "Whole Craft Bag · %d materials · %s",
    SI_BMW_DETAIL_CONTEXT_DIFF = "Compared with snapshot %s",
    SI_BMW_DETAIL_CONTEXT_VISIT_DIFF = "Stock: %s · Prices: %s",
    SI_BMW_DETAIL_CONTEXT_FILTER_ALL = "all prices",
    SI_BMW_DETAIL_GROUP_SNAPSHOT = "Snapshot",
    SI_BMW_DETAIL_SNAPSHOT_READY = "Baseline: %s",
    SI_BMW_DETAIL_SNAPSHOT_MISSING = "No baseline",
    SI_BMW_DETAIL_GROUP_FILTER = "Filter",
    SI_BMW_DETAIL_FILTER_TITLE = "Materials (%d)",
    SI_BMW_DETAIL_FILTER_ALL = "All",
    SI_BMW_DETAIL_FILTER_PRICED = "Priced",
    SI_BMW_DETAIL_FILTER_UNPRICED = "No price",
    SI_BMW_DETAIL_FILTER_RESET = "Reset",
    SI_BMW_DETAIL_SEARCH_CLEAR_TOOLTIP = "Clear search",
    SI_BMW_DETAIL_LINK_HINT = "Shift-click to link",

    -- Row hover tooltip in the detail window: the figures already computed for the
    -- columns, spelled out on hover. %s carries a gold-formatted figure
    -- (FormatGold) except _QTY (a localized count) and _CHANGE (a colored signed
    -- percent). _UNPRICED replaces the price lines when there is no price.
    SI_BMW_ROW_TOOLTIP_QTY = "Quantity: %s",
    SI_BMW_ROW_TOOLTIP_UNIT = "Unit price: %s",
    SI_BMW_ROW_TOOLTIP_TOTAL = "Stack value: %s",
    SI_BMW_ROW_TOOLTIP_VALUE_SECTION = "Value and fees",
    SI_BMW_ROW_TOOLTIP_LISTING_FEE = "Listing fee (1%%): -%s",
    SI_BMW_ROW_TOOLTIP_SALES_TAX = "Sales tax (7%%): -%s",
    SI_BMW_ROW_TOOLTIP_NET = "Net after fees: %s",
    SI_BMW_ROW_TOOLTIP_TECHNICAL_SECTION = "Technical data",
    SI_BMW_ROW_TOOLTIP_SOURCE = "Price source: %s",
    SI_BMW_ROW_TOOLTIP_CHANGE = "Price change: %s",
    SI_BMW_ROW_TOOLTIP_UNPRICED = "No price available",
    SI_BMW_DETAIL_ACTION_WITHDRAW_TOOLTIP = "Withdraw to backpack",
    SI_BMW_DETAIL_ACTION_QUEUE_TOOLTIP = "Add to withdraw queue",

    -- Summary line beneath the detail list. Category/search view: a material count,
    -- the total value (FormatGold), and the list's share of the whole bag's value.
    -- Diff view: the net gold movement plus how many materials rose / fell.
    SI_BMW_DETAIL_FOOTER_COUNT = "Materials: %d",
    SI_BMW_DETAIL_FOOTER_SHARE = "%d%% of bag",
    -- Net for the shown rows after guild-store fees (category/search footer). %s =
    -- gold amount; a gold icon is appended in code.
    SI_BMW_DETAIL_FOOTER_NET_SOLD = "net %s",
    SI_BMW_DETAIL_FOOTER_NET = "Net:",
    SI_BMW_DETAIL_FOOTER_GAINED = "Added: %d",
    SI_BMW_DETAIL_FOOTER_LOST = "Reduced: %d",

    -- Snapshot + diff view (detail window). A one-time automatic baseline is
    -- captured on the first non-empty bag open; Remember overwrites it with a
    -- user-selected composition.
    SI_BMW_DETAIL_BTN_REMEMBER = "Remember",
    SI_BMW_DETAIL_BTN_REMEMBER_TOOLTIP_TITLE = "Remember composition",
    SI_BMW_DETAIL_BTN_REMEMBER_TOOLTIP_BODY = "Save the Craft Bag's current contents as the snapshot. The addon creates one automatic baseline the first time a non-empty Craft Bag is opened; pressing this replaces it with a snapshot you chose.",
    SI_BMW_DETAIL_BTN_CHANGES = "Since snapshot",
    SI_BMW_DETAIL_BTN_CHANGES_TOOLTIP_TITLE = "Changes since snapshot",
    SI_BMW_DETAIL_BTN_CHANGES_TOOLTIP_BODY = "Show how the Craft Bag changed since its saved snapshot: which materials were added, removed, or changed in quantity, and the gold value of each move. A one-time baseline is created automatically when a non-empty Craft Bag is first opened; Remember replaces it at any time.",
    -- Clears the saved snapshot so "Changes" has nothing to diff against until the
    -- next "Remember". Confirmed because the snapshot is the only persisted
    -- baseline and clearing it cannot be undone.
    SI_BMW_DETAIL_BTN_CLEAR = "Clear",
    SI_BMW_DETAIL_BTN_CLEAR_TOOLTIP_TITLE = "Clear snapshot",
    SI_BMW_DETAIL_BTN_CLEAR_TOOLTIP_BODY = "Forget the saved snapshot. The changes view will show nothing until you press \"Remember\" to take a new one. There is only one snapshot, so this cannot be undone.",
    -- Confirmation dialog shown before the snapshot is cleared, so a stray click
    -- can't wipe the baseline. _CONFIRM is the accept button; cancel reuses the
    -- standard dialog cancel.
    SI_BMW_DETAIL_CLEAR_CONFIRM_TITLE = "Clear snapshot?",
    SI_BMW_DETAIL_CLEAR_CONFIRM_BODY = "This forgets the saved snapshot. The changes view will show nothing until you press \"Remember\" again. There is only one snapshot, so this cannot be undone.",
    SI_BMW_DETAIL_CLEAR_CONFIRM_ACCEPT = "Clear",
    SI_BMW_DETAIL_CLEAR_CONFIRM_CANCEL = "Cancel",
    SI_BMW_DETAIL_REPLACE_CONFIRM_TITLE = "Replace snapshot?",
    SI_BMW_DETAIL_REPLACE_CONFIRM_BODY = "A saved snapshot already exists. Replacing it resets the comparison baseline to the Craft Bag's current contents. Continue?",
    SI_BMW_DETAIL_REPLACE_CONFIRM_ACCEPT = "Replace",
    SI_BMW_DETAIL_REPLACE_CONFIRM_CANCEL = "Cancel",
    -- Outside the category view the "Changes" button becomes a "Back" toggle
    -- that returns to the material list from Changes or Price dynamics.
    SI_BMW_DETAIL_BTN_BACK = "Back",
    SI_BMW_DETAIL_BTN_BACK_TOOLTIP_TITLE = "Back to materials",
    SI_BMW_DETAIL_BTN_BACK_TOOLTIP_BODY = "Return to the material list.",
    -- Diff title; %s = relative time of the snapshot (e.g. "5m ago").
    SI_BMW_DETAIL_DIFF_TITLE = "Changes since snapshot (%s)",
    SI_BMW_DETAIL_DIFF_EMPTY = "Nothing changed since the snapshot.",
    SI_BMW_DETAIL_VISIT_DIFF_TITLE = "Changes since last review",
    SI_BMW_DETAIL_VISIT_DIFF_EMPTY = "No material quantities changed since the last review.",
    SI_BMW_DETAIL_VISIT_DIFF_TOOLTIP_TITLE = "How this list works",
    SI_BMW_DETAIL_VISIT_DIFF_TOOLTIP_BODY = "This list contains stock changes since the last review. Clicking the row in the main window already marked them reviewed: new changes accumulate separately, even when the Craft Bag is closed and opened again.",
    SI_BMW_DETAIL_NO_SNAPSHOT = "No snapshot yet. Press Remember.",
    -- Diff column headers. ASCII "+/-" rather than a Unicode delta glyph, which
    -- the UI font will not render (same reason the addon uses arrow textures).
    SI_BMW_DETAIL_COL_QTY_DELTA = "Qty +/-",
    SI_BMW_DETAIL_COL_VALUE_DELTA = "Value +/-",
    SI_BMW_DETAIL_COL_SHARE = "Share",
    SI_BMW_DETAIL_COL_STATUS = "Status",
    -- Per-row status word in the diff's repurposed Change column.
    SI_BMW_DETAIL_STATUS_NEW = "new",
    SI_BMW_DETAIL_STATUS_GONE = "gone",
    SI_BMW_DETAIL_STATUS_ADDED = "added",
    SI_BMW_DETAIL_STATUS_REDUCED = "reduced",
    -- Signed integer for the Qty delta column; %s carries the sign (+/-).
    SI_BMW_DETAIL_QTY_DELTA = "%s%s",

    -- Withdraw dialog: opened by clicking a material row, moves the material out
    -- of the Craft Bag into the backpack.
    SI_BMW_WITHDRAW_TITLE = "Withdraw %s",
    SI_BMW_WITHDRAW_FREE_SLOTS = "Free backpack slots: %d",
    SI_BMW_WITHDRAW_MAX = "Max withdrawable: %s",
    -- %s already carries the gold icon (see FormatGold).
    SI_BMW_WITHDRAW_TOTAL_VALUE = "Total value: %s",
    SI_BMW_WITHDRAW_QTY_LABEL = "Quantity",
    -- Preset buttons. The plain counts (1/10/100) show the number itself; the
    -- stack presets use these so "200" reads as "1 stack", "2000" as "10 stacks".
    SI_BMW_WITHDRAW_PRESET_STACK = "%d stack",
    SI_BMW_WITHDRAW_PRESET_STACKS_FEW = "%d stacks",
    SI_BMW_WITHDRAW_PRESET_STACKS = "%d stacks",
    SI_BMW_WITHDRAW_PRESET_MAX = "Max",
    SI_BMW_WITHDRAW_CONFIRM = "Withdraw",
    SI_BMW_WITHDRAW_ADD_TO_QUEUE = "Add to queue",
    SI_BMW_WITHDRAW_BATCH_TITLE = "Batch withdraw",
    SI_BMW_WITHDRAW_BATCH_SUMMARY = "%d materials · %s items",
    SI_BMW_WITHDRAW_CANCEL = "Cancel",
    SI_BMW_WITHDRAW_HIDE = "Hide",
    SI_BMW_WITHDRAW_BACKPACK_FULL = "Backpack is full",
    -- Live progress while a multi-stack withdrawal runs. %d / %d = moved / total.
    SI_BMW_WITHDRAW_PROGRESS = "Withdrawing... %d / %d",
    -- In-dialog result label. Named _LABEL to keep it distinct from the chat
    -- report SI_BMW_MSG_WITHDRAW_RESULT, which takes three %s arguments instead
    -- of two %d; the two were previously one keystroke apart.
    SI_BMW_WITHDRAW_RESULT_LABEL = "Withdrawn: %d / %d",

    -- Withdraw queue: the multi-material list embedded in the withdraw window.
    SI_BMW_QUEUE_TITLE = "Withdraw queue",
    SI_BMW_QUEUE_EMPTY = "Use Add to queue or + on a material to build a batch.",
    -- Footer summary. %d = materials, %d = slots the queue needs, %s = value.
    SI_BMW_QUEUE_SUMMARY = "%d materials · %d slots · %s",
    SI_BMW_QUEUE_STATUS_READY = "Ready to withdraw",
    SI_BMW_QUEUE_STATUS_NO_SPACE = "Not enough backpack space",
    SI_BMW_QUEUE_WITHDRAW_ALL = "Withdraw all",
    SI_BMW_QUEUE_CLEAR = "Clear",

    -- Window: footer (two-column label -> value rows)
    SI_BMW_FOOTER_INVENTORY_LABEL = "Bag contents",
    SI_BMW_FOOTER_PRICES_LABEL = "Market prices",
    SI_BMW_FOOTER_PRICES_TOOLTIP_TITLE = "Market prices",
    SI_BMW_FOOTER_PRICES_TOOLTIP_BODY = "Prices are cached for this login. Re-query them after Master Merchant or Tamriel Trade Centre finishes importing fresh data.",
    SI_BMW_FOOTER_PRICES_TOOLTIP_CLICK = "Click to refresh prices now.",
    SI_BMW_FOOTER_PRICES_TOOLTIP_BUSY = "Price refresh is already in progress.",
    SI_BMW_FOOTER_PRICES_REFRESHING = "Refreshing...",
    SI_BMW_FOOTER_PRICES_REFRESHED = "Updated",
    SI_BMW_FOOTER_COVERAGE_LABEL = "Price coverage",
    SI_BMW_FOOTER_COVERAGE_VALUE = "%d/%d priced",
    SI_BMW_FOOTER_LOW_COVERAGE = "%d/%d unpriced!",
    SI_BMW_FOOTER_COVERAGE_UNPRICED_HINT = "Click to view materials without a price.",
    SI_BMW_FOOTER_DELTA_LABEL = "Since review",
    SI_BMW_FOOTER_DELTA_LABEL_SESSION = "This session",
    SI_BMW_FOOTER_DELTA_VALUE = "%s",
    SI_BMW_FOOTER_DELTA_TOOLTIP_TITLE = "Value change breakdown",
    SI_BMW_FOOTER_DELTA_TOOLTIP_STOCK = "Stock movement: %s",
    SI_BMW_FOOTER_DELTA_TOOLTIP_PRICES = "Price revaluation: %s",
    SI_BMW_FOOTER_DELTA_TOOLTIP_ACCUMULATION = "Changes accumulate until manually reviewed and do not reset when the Craft Bag opens.",
    SI_BMW_FOOTER_DELTA_TOOLTIP_CLICK = "Click to inspect the changes and mark them reviewed.",
    SI_BMW_FOOTER_GUIDANCE_UNPRICED = "%d materials without a price - view list",

    -- Grand-total hover: "net if sold" breakdown of the guild-store selling fees.
    -- The %% renders a literal percent through string.format. %s = a gold amount.
    -- _LISTING/_SALES are shown as deductions; _NET is what's left after both.
    SI_BMW_NET_TOOLTIP_TITLE = "If sold at a guild trader",
    SI_BMW_NET_TOOLTIP_GROSS = "List price: %s",
    SI_BMW_NET_TOOLTIP_LISTING = "Listing fee (1%%): -%s",
    SI_BMW_NET_TOOLTIP_SALES = "Sales tax (7%%): -%s",
    SI_BMW_NET_TOOLTIP_NET = "You receive (92%%): %s",
    SI_BMW_NET_TOOLTIP_CLICK = "Click to inspect every material in the Craft Bag",
    -- Value-history sparkline caption + hover tooltip.
    SI_BMW_FOOTER_HISTORY_LABEL = "Value history",
    -- Min/max scale line beneath the area chart. %s = lowest recorded value, %s =
    -- highest. Plain hyphen between them (not an en-dash).
    SI_BMW_HISTORY_SCALE = "%s - %s",
    SI_BMW_HISTORY_TOOLTIP_POINTS = "Recorded points: %d",
    SI_BMW_HISTORY_TOOLTIP_OLDEST = "Oldest: %s",
    SI_BMW_HISTORY_TOOLTIP_NEWEST = "Newest: %s",
    SI_BMW_HISTORY_TOOLTIP_CHANGE = "Change: %s",

    -- Window: relative time
    SI_BMW_TIME_NEVER = "never",
    SI_BMW_TIME_JUST_NOW = "just now",
    SI_BMW_TIME_SECONDS = "%ds ago",
    SI_BMW_TIME_MINUTES = "%dm ago",
    SI_BMW_TIME_HOURS = "%dh ago",
    -- Compound "time ago" for the snapshot diff title, which (unlike the footer)
    -- can span days. The age is built from the two largest non-zero units (e.g.
    -- "5d 3h", "3h 20m", "45m") then wrapped by _AGO so word order is localizable.
    SI_BMW_TIME_UNIT_DAYS = "%dd",
    SI_BMW_TIME_UNIT_HOURS = "%dh",
    SI_BMW_TIME_UNIT_MINUTES = "%dm",
    SI_BMW_TIME_AGO = "%s ago",

    -- Material categories
    SI_BMW_CATEGORY_BLACKSMITHING = "Blacksmithing",
    SI_BMW_CATEGORY_CLOTHIER = "Clothier",
    SI_BMW_CATEGORY_WOODWORKING = "Woodworking",
    SI_BMW_CATEGORY_JEWELRY = "Jewelry Crafting",
    SI_BMW_CATEGORY_ALCHEMY = "Alchemy",
    SI_BMW_CATEGORY_ENCHANTING = "Enchanting",
    SI_BMW_CATEGORY_PROVISIONING = "Provisioning",
    SI_BMW_CATEGORY_OTHER = "Other",

    -- Booleans
    SI_BMW_BOOL_TRUE = "true",
    SI_BMW_BOOL_FALSE = "false",

    -- Debug level names (index = level)
    SI_BMW_DEBUG_LEVEL_OFF = "Off",
    SI_BMW_DEBUG_LEVEL_ERRORS = "Errors",
    SI_BMW_DEBUG_LEVEL_WARNINGS = "Warnings",
    SI_BMW_DEBUG_LEVEL_INFO = "Info",
    SI_BMW_DEBUG_LEVEL_VERBOSE = "Verbose",

    -- Log level prefixes
    SI_BMW_LOG_LEVEL_ERROR = "|cFF0000[ERROR]|r",
    SI_BMW_LOG_LEVEL_WARN = "|cFFAA00[WARN]|r",
    SI_BMW_LOG_LEVEL_INFO = "|c00FF00[INFO]|r",
    SI_BMW_LOG_LEVEL_DEBUG = "|c999999[DEBUG]|r",

    -- Log messages
    SI_BMW_LOG_ONADDONLOADED_LOADING = "Loading version %s...",
    SI_BMW_LOG_ADDON_LOADED = "Addon loaded.",
    SI_BMW_LOG_CRAFTBAG_SHOWN = "Craft Bag shown.",
    SI_BMW_LOG_CRAFTBAG_HIDDEN = "Craft Bag hidden.",
    SI_BMW_LOG_RESCAN_DONE = "Full rescan complete: %d slots, total %s.",
    SI_BMW_LOG_SLOT_UPDATED = "Slot %d updated (contribution %s).",
    SI_BMW_LOG_LAM_MISSING = "LibAddonMenu-2.0 not found; settings panel unavailable.",

    -- Chat messages
    SI_BMW_MSG_LIBPRICE_MISSING = "LibPrice is not installed. Bureau of Material Worth needs LibPrice (and a price source such as Master Merchant or Tamriel Trade Centre) to work.",
    SI_BMW_MSG_VERSION_DEBUG = "Version %s, debug: %s (%d)",
    SI_BMW_MSG_STATUS_TOTAL = "Craft Bag value: %s.",
    SI_BMW_MSG_STATUS_SLOTS = "Priced slots: %d, unpriced slots: %d.",
    SI_BMW_MSG_STATUS_FULL_UPDATES = "Full inventory updates this session: %d total, %d while open, %d coalesced rescans.",
    -- First-open-of-session announcement. _DELTA: %s current total, %s signed
    -- change (both already include the gold icon). _TOTAL: %s current total.
    SI_BMW_MSG_VISIT_DELTA = "Craft Bag is worth %s (%s since last review).",
    SI_BMW_MSG_VISIT_TOTAL = "Craft Bag is worth %s.",
    SI_BMW_MSG_SIGNIFICANT_DELTA = "Craft Bag value changed by %s (%d%%).",
    SI_BMW_MSG_PRICE_TRENDS = "Price dynamics · threshold %d%%: %s.",
    SI_BMW_MSG_PRICE_TREND_GAIN = "%s rose by %s%%",
    SI_BMW_MSG_PRICE_TREND_LOSS = "%s fell by %s%%",
    SI_BMW_MSG_PRICE_TREND_MORE = "and %d more",
    SI_BMW_MSG_PRICES_RECOVERED = "Prices are now available for all Craft Bag materials (%d updated).",
    SI_BMW_MSG_WITHDRAW_RESULT = "Withdrawn: %s/%s items, value: %s.",
    SI_BMW_MSG_WITHDRAW_PARTIAL = "Withdrawn: %s/%s items, value: %s. Backpack space or inventory changes prevented the rest.",
    SI_BMW_MSG_VALUE_UNKNOWN = "unknown",
    SI_BMW_MSG_REFRESH_STARTED = "Price refresh started.",
    SI_BMW_MSG_REFRESH_BUSY = "Price refresh is already in progress.",
    -- Chat confirmation when the snapshot is saved/cleared from the detail window.
    -- _SAVED: %d = slots (distinct materials), %s = grand-total gold.
    SI_BMW_MSG_SNAPSHOT_SAVED = "Snapshot saved: %d slots, %s.",
    SI_BMW_MSG_SNAPSHOT_CLEARED = "Snapshot cleared.",
    SI_BMW_MSG_DEBUG_MODE_SET = "Debug mode set to %s (%d).",
    SI_BMW_MSG_INVALID_DEBUG_LEVEL = "Invalid debug level. Use a number from 0 to 4.",
    SI_BMW_MSG_SETTINGS_UNAVAILABLE = "Settings panel is unavailable (LibAddonMenu-2.0 not found).",
    SI_BMW_MSG_UNKNOWN_COMMAND = "Unknown command. Type /bmw help for the command list.",

    -- Slash command help
    SI_BMW_MSG_HELP_TITLE = "|cC5C29EBureau of Material Worth commands:|r",
    SI_BMW_MSG_HELP_STATUS = "|cFFFFFF/bmw status|r - show the current Craft Bag value.",
    SI_BMW_MSG_HELP_REFRESH = "|cFFFFFF/bmw refresh|r - clear cached prices and recompute.",
    SI_BMW_MSG_HELP_SETTINGS = "|cFFFFFF/bmw settings|r - open the settings panel.",
    SI_BMW_MSG_HELP_DEBUG = "|cFFFFFF/bmw debug <0-4>|r - set chat debug verbosity.",
    SI_BMW_MSG_HELP_HELP = "|cFFFFFF/bmw help|r - show this command list.",
}

for stringId, value in pairs(strings) do
    ZO_CreateStringId(stringId, value)
end
