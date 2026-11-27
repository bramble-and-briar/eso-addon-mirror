-- MasterWrits Companion: English texts, and the default for every other client language.
--
-- Translating: copy this file to Lang/<language>.lua (de, fr, ru, es, jp, zh: the game's own language codes),
-- start it with "local L = MWC.L" instead of "local L = {}", drop the last line (MWC.L = L), and set only the
-- texts you translate, as L.KEY = "...". Anything left out stays English.
-- %s, %d and %%: keep every one of them, in the same order. "\n" is a line break.
local L = {}

-- Game texts the addon recognises (not shown) ------------------------------------------------------------
-- These must match the game's own texts in this client language. Most things are recognised by numbers, not
-- texts; these are the few exceptions, and each has a fallback that works without them.

-- The Mastercraft Mediators (Autodelivery hands in only there). Without the right names here, a hand-in done
-- once by hand teaches the addon the NPC (kept per account).
L.MEDIATORS = { "Rolis Hlaalu" }

-- Charity holiday writ quests: how their names start, and a word telling the holiday (the default is New Life).
-- Fallback without them: any holiday quest is recognised by its data once its writ was seen in the bag.
L.CHARITY_QUEST = {
  prefix = "A Charitable Contribution",
  kinds = { deepwinter = "Deep Winter", imperial = "Imperial" },
  default = "newlife",
}

-- The item a writ asks for, read from the writ's text, for the list (a Lua pattern, one capture). Without a
-- match, the text in the first parentheses, or else the task line (after a "Consume to start quest:" line) is shown.
L.GEAR_NAME_PATTERN = "Craft an? (.-);"
L.ALCHEMY_NAME_PATTERN = "Craft an? (.-) with"

-- Importing a quest started by hand compares its text with the writs' texts. Words that say nothing about the
-- task are left out, and the word that tells a poison from a potion.
L.IMPORT_FILLER_WORDS = "consume to start quest craft a an with the following traits trait properties property quality set style progress and of"
L.POISON_WORD = "poison"

-- Common ----------------------------------------------------------------------------------------------------
L.BINDING_TOGGLE = "Toggle window"
L.TOOLTIP_PREFIX = "MasterWrits: "

L.CRAFT = {
  blacksmithing = "Blacksmithing", clothier = "Clothing", woodworking = "Woodworking", jewelry = "Jewelry",
  alchemy = "Alchemy", enchanting = "Enchanting", provisioning = "Provisioning",
}
-- Tab tooltips (main window and Keep materials).
L.CRAFT_TAB = {
  blacksmithing = "Blacksmithing", clothier = "Clothing", woodworking = "Woodworking", jewelry = "Jewelry crafting",
  alchemy = "Alchemy", enchanting = "Enchanting", provisioning = "Provisioning",
}
L.TAB_ALL = "All writs"
L.TAB_SEALED = "Sealed writs"

-- Material kinds (Materials Used tabs, Keep materials).
L.KIND = {
  All = "All", Base = "Base", Upgrade = "Upgrade", Trait = "Trait", Style = "Style", Reagent = "Reagent",
  Rune = "Rune", Ingredient = "Ingredient", Solvent = "Solvent", Potency = "Potency", Essence = "Essence",
  Aspect = "Aspect",
}

-- What a writ row is (type icon tooltip).
L.TYPE_DRINK = "Drink"
L.TYPE_FOOD = "Food"
L.TYPE_POISON = "Poison"
L.TYPE_POTION = "Potion"
L.TYPE_GLYPH = "Glyph"
L.TYPE_GLYPH_ARMOR = "Armor glyph"
L.TYPE_GLYPH_WEAPON = "Weapon glyph"
L.TYPE_GLYPH_JEWELRY = "Jewelry glyph"
L.SEALED_WRIT = "Sealed writ"
L.EVENT_LABEL = {
  witches = "Witches Festival writ", newlife = "New Life Charity writ", deepwinter = "Deep Winter Charity writ",
  imperial = "Imperial Charity writ",
}

-- Why a writ can't be crafted (red marker tooltip, chat).
L.PROBLEM_STYLE_UNKNOWN = "style not known"
L.PROBLEM_RECIPE_UNKNOWN = "recipe not known"
L.PROBLEM_TRAIT_UNKNOWN = "trait not researched on this item"
L.PROBLEM_SET_TRAITS = "set needs %d traits researched on this item (%d)"
L.PROBLEM_GOLD_GLYPH = "gold glyph needs Aspect Improvement at max rank"
L.PROBLEM_THREE_REAGENTS = "needs three reagents: Laboratory Use passive"
L.PROBLEM_NO_COMBINATION = "no reagent combination"
L.PROBLEM_ONLY_KEPT_REAGENTS = "only reagents from Keep materials make it"
L.PROBLEM_NO_EXACT_POTION = "no reagents make exactly this potion"
L.PROBLEM_UNKNOWN_GLYPH = "unknown glyph"
L.PROBLEM_UNKNOWN_GLYPH_LEVEL = "unknown glyph level or quality"
L.PROBLEM_NO_PREVIEW = "the station shows no result preview"
L.PROBLEM_NO_REAGENTS_WITHOUT_KEPT = "no reagents you have make %s without using Keep materials"
L.PROBLEM_WRONG_GLYPH = "the station would make %s, not the writ's glyph"
L.PROBLEM_SET_NOT_AVAILABLE = "set not available at this station"
L.PROBLEM_SET_LOCKED = "set not unlocked at this station"
L.PROBLEM_SET_NOT_SWITCHED = "the station didn't switch to the set (active %d)"
L.PROBLEM_SET_STATION = "needs this set's crafting station"
L.PROBLEM_STYLE_UNKNOWN_PIECE = "style not known for this piece"
L.PROBLEM_NOT_ENOUGH_IN_BAG = "not enough %s in bag or craft bag"
L.PROBLEM_NONE_IN_BAG = "no %s in bag or craft bag"
L.PROBLEM_GAME_REFUSES = "the game refuses to craft it"
L.PROBLEM_NO_PATTERN = "no matching pattern at this station"
L.PROBLEM_WRONG_ITEM = "the station would craft %s, not the writ's item"
L.PROBLEM_NOTHING = "nothing"
L.PROBLEM_FINISHED_MISMATCH = "the finished item %s doesn't match the writ"
L.PROBLEM_NOT_FOUND = "(not found)"
L.PROBLEM_LOST_ITEM = "lost track of the crafted item"
L.PROBLEM_CANT_IMPROVE = "the game can't improve the item at quality %d"
L.PROBLEM_NO_SURE_STEP = "no sure improvement step possible: improvement skill too low?"
L.PROBLEM_NOT_ENOUGH = "not enough %s: %d needed, %d owned"
L.PROBLEM_ITEM_NOT_IN_BAG = "the crafted item was not found in the bag"
L.PROBLEM_IMPROVEMENT_NOT_SHOWN = "the improvement didn't show on the item"

-- Operations (progress bar labels) ----------------------------------------------------------------------------
L.ACTIVITY_CRAFTING = "Crafting"
L.ACTIVITY_MOVING = "Moving"
L.ACTIVITY_OPENING = "Opening"
L.ACTIVITY_STARTING_QUESTS = "Starting quests"
L.ALREADY_RUNNING = "%s is still running. Stop it first."

-- Crafting ----------------------------------------------------------------------------------------------------
L.IN_BAG_OR_CRAFT_BAG = "%s (bag or craft bag)"
L.MORE_CRAFTS = "%s (%d more)"
L.STOPPED_RUN_LIMIT = "Stopped at the run's limit. Still to craft: %s. Craft again."
L.DONE_SKIPPED = "Done. Skipped: %s"
L.DONE_ALL_CRAFTED = "Done, everything is crafted."
L.DONE_ALL_ITEMS_CRAFTED = "Done, every queued item is crafted."
L.STATION_CLOSED = "Station closed, crafting stopped."
L.SKIP_SPENDS_KEPT = "%s (spends Keep materials)"
L.SKIP_MISSING_MATERIALS = "%s (missing materials)"
L.SKIP_MUST_BE_IN_BAG = "%s (%s must be in the bag or craft bag)"
L.SKIP_WRONG_COUNT = "%s (expected %d, got %d: details in SavedVariables)"
L.SKIP_REASON = "%s (%s)"
L.BAG_FULL_CRAFT = "Bag full. Free some slots and craft again."
L.CRAFTING_COUNT = "Crafting %s ×%d…"
L.CRAFTING_ITEM = "Crafting %s…"
L.IMPROVING_ITEM = "Improving %s (%d → %d)…"
L.CRAFTING_FAILED = "Crafting failed: %s"
L.ALREADY_CRAFTING = "Already crafting. Press Stop in the window to stop."
L.OPEN_STATION_FIRST = "Open a crafting station first."
L.NOTHING_TO_CRAFT = "Nothing to craft here."
L.CRAFTING_STOPPED = "Crafting stopped."

-- Bank ----------------------------------------------------------------------------------------------------------
L.MOVED_WRITS = "Moved %d writs"
L.MOVED_ITEMS = " and %d items in %d stacks"
L.MOVED_SUMMARY = "%s. Bag free slots: %d → %d."
L.BANK_CLOSED_STOPPED = "Bank closed, moving stopped. "
L.STORAGE_FULL_STOPPED = "No space left in storage, moving stopped. "
L.BAG_FULL_STOPPED = "No space left in the bag, moving stopped. "
L.MOVING_PROGRESS = "Moving… %d writs and %d items so far"
L.MOVE_NOT_CONFIRMED = "The game didn't confirm the move, stopped. Try again."
L.MOVING_STOPPED = "Moving stopped. "
L.ALREADY_MOVING = "Already moving items."
L.OPEN_HOUSE_CHEST = "Open a house storage chest first."
L.OPEN_BANK_FIRST = "Open your bank first (not a house chest)."
L.NOTHING_WITHDRAW_MARKED = "Nothing to withdraw: no marked writs in the bank or no bag space (%d slots kept free)."
L.NOTHING_WITHDRAW_SEALED = "Nothing to withdraw: no sealed writs in the bank or no bag space (%d slots kept free)."
L.NOTHING_WITHDRAW_SELECTED = "Nothing to withdraw: no selected writs in the bank or no bag space (%d slots kept free)."
L.NOTHING_WITHDRAW_READY = "Nothing to withdraw: no ready writs in the bank or no bag space (%d slots kept free)."
L.NO_MASTER_WRITS_IN_BAG = "No master writs in the bag."
L.NO_MARKED_IN_BAG = "No marked writs in the bag."
L.NO_RECIPE_ITEMS_IN_BAG = "No writs or crafted items of these recipes in the bag."
L.NO_LEFTOVERS = "No leftover crafted items in the bag."

-- Sealed writs ----------------------------------------------------------------------------------------------------
L.OPENED_COUNT = "%s Opened %d."
L.DONE = "Done."
L.BAG_IS_FULL = "Bag is full."
L.STOPPED_CANT_OPEN = "Stopped: can't open containers right now (combat, looting or an open interaction)."
L.OPENING_ITEM = "Opening %s…"
L.COOLDOWN_STOPPED = "The item cooldown didn't end, stopped."
L.CONTAINER_NOT_OPENED = "The game didn't open the container after several tries, stopped."
L.CANT_OPEN_NOW = "Can't open containers right now: leave combat, close the loot window, bank or station."
L.NOTHING_TO_OPEN = "Nothing to open: nothing selected, no sealed writs in the bag or no free slots."
L.OPENING_STOPPED = "Opening stopped."

-- Turning in ------------------------------------------------------------------------------------------------------
L.DOLGUBON_CONFLICT = "Dolgubon's Lazy Writ Crafter (its auto accept / turn in writs)"
L.DOLGUBON_PATH = "Settings > Addons > Lazy Writ Crafter > Timesavers > Automatic complete"
L.TURN_OFF = "Turn off: %s."
L.OPEN_ITS_SETTINGS = "[Open its settings]"
L.CONFLICT_CHAT = "Also hands in at the mediator: %s. Turn its Automatic complete off, or Autodelivery here."
L.CONFLICT_PANEL = "Also hands in at the mediator: %s. Turn one of them off."
L.QUESTS_SKIPPED = " Skipped: %s (the quest didn't start, try again)."
L.QUESTS_STARTED = "Done: %d writ quests started. Talk to the Mastercraft Mediator.%s"
L.NO_NEW_QUESTS = "Done: no new quests (each craft with a ready writ already has one).%s"
L.KEEP_SLOTS_FREE = "Keep at least %d bag slots free for the rewards."
L.JOURNAL_FULL = "The quest journal is full (%d quests). Finish or abandon some first."
L.STARTING_QUESTS_PROGRESS = "Starting quests %d / %d: %s… wait before talking to the Mediator"
L.CANT_START_QUESTS = "Can't start writ quests now: leave combat, close the loot window, bank or conversation."
L.NOTHING_TO_START = "Nothing to start: no ready writ in the bag for a craft without an active quest."
L.STOPPED = "Stopped."
L.NO_HANDIN_OPTION = "No hand-in option recognized. Pick it yourself."
L.UNKNOWN_MEDIATOR = "If this is the Mastercraft Mediator, hand in one writ here yourself: Autodelivery then works with this NPC."

-- Main window --------------------------------------------------------------------------------------------------
L.CHECK_BAG = "Bag"
L.CHECK_BANK = "Bank"
L.CHECK_SKIPPED = "Skipped"
L.CHECK_COMPLETED = "Completed"
L.CHECK_EVENT = "Event"
L.REFRESH = "Refresh"
L.KEEP_MATERIALS = "Keep materials"
L.DESELECT_KEPT = "Deselect kept"
L.DESELECT_KEPT_COUNT = "Deselect kept (%d)"
L.DESELECT_KEPT_TOOLTIP = "Dequeue every writ that would spend a material from Keep materials (orange rows), on all tabs."
L.BUTTON_MATERIALS = "Materials Used"
L.BUTTON_STATS = "Stats"
L.BUTTON_TURN_IN = "Turn in"
L.BUTTON_CRAFT = "Craft"
L.BUTTON_STOP = "Stop"
L.BUTTON_DEPOSIT_ALL = "Deposit all"
L.BUTTON_WITHDRAW_ALL = "Withdraw all"
L.BUTTON_WITHDRAW_MARKED = "Withdraw marked"
L.BUTTON_OPEN_SEALED = "Open sealed"
L.BUTTON_OPEN_COUNT = "Open %d"
L.BUTTON_DEPOSIT_WRITS = "Deposit writs"
L.BUTTON_WITHDRAW_SEALED = "Withdraw sealed"
L.BUTTON_STORE_MARKED = "Store marked"
L.DRAG_TO_RESIZE = "Drag to resize"
L.COLUMN_RESIZE_TOOLTIP = "Drag to resize the column. Right-click: default widths."

-- Column titles of the writ list.
L.HEADER_RECIPE = "Recipe   %s %s %s"
L.HEADER_SEALED = "Sealed writ   %s %s"
L.HEADER_BANK = "(bank)"
L.HEADER_BAG = "(bag)"
L.HEADER_BAG_BANK = "(bag/bank)"
L.HEADER_QUALITY = "Q"
L.HEADER_SET = "Set"
L.HEADER_STYLE = "Style"
L.HEADER_TRAIT = "Trait"
L.HEADER_QUEUED = "Q"
L.HEADER_READY = "Ready"
L.HEADER_VOUCHERS = "V"
L.HEADER_TO_OPEN = "To open"
L.HEADER_OPENED = "Opened"

L.ROW_ACTIVE_QUEST = "(%d quest)"
L.ROW_TURNED_IN = "(%d turned in)"
L.MIMIC_ON = "Crafted with a Crown Mimic Stone instead of the style material. Click to use the style material."
L.MIMIC_OFF = "Crafted with the style material. Click to use a Crown Mimic Stone instead."
L.MENU_LINK_WRIT = "Link writ in chat"
L.MENU_QUEUE_ALL = "Queue all (%d)"
L.MENU_QUEUE_AFFORDABLE = "Queue %d (what materials cover)"
L.MENU_WITHDRAW = "Withdraw from bank (what fits)"
L.MENU_DEPOSIT = "Deposit to bank (writs and crafted items)"
L.MENU_SKIP_USING = "Skip all writs using this (%d recipes)"
L.MENU_LINK = "Link in chat"
L.SELECT_BAG_OR_BANK = "Select Bag or Bank."
L.NO_WRITS = "No writs found."
L.SEALED_SUMMARY = "%d to open  ·  %d in bag  ·  %d in bank  ·  %s"

-- Item tooltips (after the prefix).
L.TOOLTIP_SET = "Set: "
L.TOOLTIP_STYLE = "Style: "
L.TOOLTIP_TRAIT = "Trait: "
L.TOOLTIP_ALCHEMY_UNCHECKED = "the reagents for this name aren't checked yet: open an alchemy station and the materials list will be confirmed"
L.TOOLTIP_SPENDS_KEPT = "spends kept "
L.STATE_ACTIVE = "quest active: hand it in at the Mastercraft Mediator"
L.STATE_COMPLETED = "turned in this session"
L.STATE_ABANDONED = "quest abandoned"
L.STATE_UNKNOWN = "quest left the journal while the addon couldn't see it: handed in or abandoned"
L.MARK_SKIP = "skip"
L.MARK_READY = "ready to turn in"

-- Progress bar.
L.BAR_STOPPED = "Stopped: "
L.BAR_INVENTORY_LIMIT = "Inventory limit reached: %d of %d fit"
L.BAR_READY_TURNED = "Ready %d + turned in %d / %d"
L.BAR_READY = "Ready %d / %d  ·  %d%%"
L.BAR_CLICK_DISMISS = " (click to dismiss)"

-- Materials Used and Session totals.
L.TTC_MISSING = "TTC not found: no prices."
L.KEPT = "Kept"
L.MATERIALS_COST = "%s %s g  ·  all materials %s g"
L.MATERIALS_MISSING = "  ·  %d missing"
L.MATERIALS_DEFAULT_ORDER = "Default order: craft, kind, best quality first"
L.COLUMN_CRAFT = "Craft"
L.COLUMN_MATERIAL = "Material"
L.COLUMN_NEED = "Need"
L.COLUMN_HAVE = "Have"
L.COLUMN_TTC_PRICE = "TTC price"
L.COLUMN_TOTAL = "Total"
L.COLUMN_USED_TOTAL = "Used / total"
L.COLUMN_LEFT = "Left"
L.COLUMN_TOTAL_COST = "Total cost"
L.SESSION_TOTALS = "Session Totals"
L.SESSION_TOTALS_HINT = "All materials of the queued writs on the current tab: already spent on crafted items / needed in total."
L.TOTALS_SUMMARY = "Spent %s g  ·  left %s g  ·  total %s g"

-- Stats.
L.STAT_WRITS = "Writs"
L.STAT_VOUCHERS = "Vouchers"
L.STAT_MATERIALS = "Materials"
L.STAT_GOLD_PER_VOUCHER = "Gold per voucher"
L.STAT_QUEUED = "Queued"
L.STAT_READY = "Ready"
L.STAT_TURNED_IN = "Turned in"
L.RESET_SESSION = "Reset session"
L.BUTTON_SESSION_TOTALS = "Session totals"
L.SESSION_SINCE = "Session since %s"
L.RESET_CONFIRM = "Reset the session? All \"skip\" marks and the history of turned-in writs will be cleared."

-- Turn in panel.
L.TI_CRAFT = "Craft"
L.TI_QUEST = "Quest"
L.TI_BAG = "In bag"
L.TI_BANK = "In bank"
L.TI_NOT_READY = "Not ready"
L.TI_HOLIDAY = "Holiday"
L.TI_STARTING = "starting…"
L.TI_ACTIVE = "active"
L.TURNIN_INFO = "Crafting quests active: %d / 7%s  ·  turned in this session: %d"
L.TURNIN_UNKNOWN_CRAFT = " (%d of unknown craft)"
L.AUTODELIVERY = "Autodelivery"
L.AUTODELIVERY_TOOLTIP = "Opening the bank takes the ready writs, closing it starts their quests, and talking to the Mastercraft Mediator hands them in and starts the next ones."
L.NEXT_STEP = "Next step"
L.BUTTON_WITHDRAW_READY = "Withdraw ready"
L.WITHDRAW_READY_TOOLTIP = "At the bank: writs ready to turn in, with their crafted items, mixed across crafts, as many as fit."
L.BUTTON_START = "Start quests"
L.BUTTON_START_COUNT = "Start quests (%d)"
L.START_TOOLTIP = "Open one ready writ per craft (one quest per craft is the game's limit)."
L.BUTTON_DEPOSIT_LEFTOVERS = "Deposit leftovers"
L.DEPOSIT_LEFTOVERS_TOOLTIP = "At the bank: crafted items in the bag beyond what the queued writs in the bag need."
L.BUTTON_IMPORT = "Import quests"
L.BUTTON_IMPORT_COUNT = "Import quests (%d)"
L.IMPORT_TOOLTIP = "Adds writ quests you started by hand to the session: matched by their task against a writ of the same kind that you still have."
L.IMPORTED = "Imported %d quests."
L.NOT_IMPORTED = "Not imported, no matching writ: %s"

-- Next step advice.
L.STEP_TAKING = "%d ready writs are here: taking what fits."
L.STEP_PRESS_WITHDRAW = "Press Withdraw ready: %d ready writs are here."
L.STEP_CLOSE_BANK_AUTO = "Close the bank: the quests start by themselves."
L.STEP_CLOSE_BANK = "Close the bank, then press Start quests."
L.STEP_NOTHING_IN_BANK = "Nothing ready to take from the bank."
L.STEP_START_MORE = "Press Start quests: %d more crafts can start one."
L.STEP_MEDIATOR = "Talk to the Mastercraft Mediator: %d quests are ready to hand in."
L.STEP_START = "Press Start quests: %d crafts can start one."
L.STEP_OPEN_BANK = "Open the bank: %d ready writs are there%s."
L.STEP_OPEN_BANK_HOLIDAY = "Open the bank: %d ready holiday writs are there%s."
L.STEP_TAKEN_AT_ONCE = ", they are taken at once"
L.STEP_CRAFT_FIRST = "Nothing is ready: craft the queued writs first."
L.STEP_ALL_DONE = "Everything ready is turned in."
L.STEP_EVENT_STARTING = "Starting the holiday quest of %s…"
L.STEP_EVENT_DELIVER = "Holiday quest ready (%s): hand it in at a writ crate (where daily writs go)."
L.STEP_EVENT_CRAFT = "Holiday quest active (%s): craft its item first."
L.STEP_EVENT_READY_AUTO = "Holiday writ ready: %s, its quest starts next."
L.STEP_EVENT_READY = "Holiday writ ready: %s. Use it, or turn on Autodelivery."
-- The same in two words, on the progress bar.
L.SHORT_EVENT_STARTING = "Starting quest"
L.SHORT_EVENT_DELIVER = "Writ crate"
L.SHORT_EVENT_CRAFT = "Craft holiday item"
L.SHORT_EVENT_READY = "Holiday writ"
L.SHORT_WITHDRAW = "Withdraw ready"
L.SHORT_CLOSE_BANK = "Close the bank"
L.SHORT_NOTHING_IN_BANK = "Nothing in the bank"
L.SHORT_START = "Start quests"
L.SHORT_MEDIATOR = "Talk to the Mediator"
L.SHORT_OPEN_BANK = "Open the bank"
L.SHORT_CRAFT_REST = "Craft the rest"
L.SHORT_ALL_TURNED_IN = "All turned in"

L.FEEDBACK = "Feedback"
L.FEEDBACK_MAIL = "Mail the authors (in game)"
L.FEEDBACK_ESOUI = "Comments on ESOUI"

-- Keep materials window.
L.KEEP_HINT = "Writs needing checked materials are highlighted and not crafted. To dequeue them all: Deselect kept."
L.KEEP_HEADER = { On = "On", Name = "Item", Detail = "Trait/Style", Kind = "Kind", QualityText = "Quality", Price = "TTC price" }

-- /mwc report and the bag line.
L.SKILL_NOT_MAXED = " [skill not maxed]"
L.IMPROVEMENT_NOT_MAXED = " [improvement skill not maxed]"
L.BAG_LINE = "Bag (%d) → %s / %d"
L.BAG_OVERFLOW = "  ·  Inventory limit reached: %d don't fit"
L.REPORT_ALL_READY = "all ready"
L.REPORT_NOT_READY = "%d not ready, %d crafts"
L.REPORT_CRAFT = "%s: %d writs, %d ready, %s"
L.REPORT_GROUP = "    %s: ready %d/%d, %d crafts%s"
L.REPORT_NONE = "No queued writs."
L.REPORT_MISSING = "Missing: %s"

-- Chat commands.
L.LOG_NONE = "This build keeps no log."
L.LOG_INFO = "Log: %d lines, saved in SavedVariables/MasterWritsCompanion.lua after /reloadui or logout. /mwc log clear empties it."
L.LOG_CLEARED = "Log cleared."
L.COMMANDS = "Commands: /mwc (window), /mwc report, /mwc craft, /mwc stop, /mwc log, /mwc log clear"

MWC.L = L
