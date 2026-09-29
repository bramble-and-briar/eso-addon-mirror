---------------------------------------------
-- English localization for MasterThief
---------------------------------------------
-- translated by Adalan@Aruntas
-- updated by WolfStar07

local localization_strings = {
	-- settings panel name
	MASTER_THIEF_NAME = "Master Thief",
	
	-- options checkboxes
	MT_SNEAK_MODE_NAME = "Sneak and steal mode",
	MT_SNEAK_MODE_TEXT = "It works like a safety net. You can inspect all containers (except safeboxes) without without being stealthed and not autoloot everything. This helps if guards or NPCs are around and you just want to see if there is anything worth stealing.",
	MT_SHOW_MESSAGEBOX_NAME = "Show message frame",
	MT_SHOW_MESSAGEBOX_TEXT = "Force show the message frame on screen to allowing moving and positioning.",
	MT_EXCLUDE_COMPARE_NAME = "Shared knowledge looting",
	MT_EXCLUDE_COMPARE_TEXT = "This option checks your known recipes and blueprints across your account (requires LibCharacterKnowledge). If it's disabled, only your current character's knowledge will be checked.",
	MT_LOOT_UNKNOWN_RECIPES_NAME = "Force loot unknown",
	MT_LOOT_UNKNOWN_RECIPES_TEXT = "Loot all unknown recipes and blueprints regardless of set quality level. If it's disabled then you autoloot only recipes and blueprints of the set quality level or higher.",
	MT_AUTOLOOT_FROM_LOOTLIST_NAME = "Loot list autoloot",	
	MT_AUTOLOOT_FROM_LOOTLIST_TEXT = "If activated, you automatically steal items added to the loot list. Get access to the loot window by typing |cedbe3e/mtloot|r.",
	MT_PICKPOCKET_COUNTER_NAME = "Pickpocket counter",
	MT_PICKPOCKET_COUNTER_TEXT = "On-screen pickpocket counter since NPCs like to move around. Kill to reset counter. Will apply to all NPCs of the same generic name, such as Lion Guard, so be sure to reset by killing or teleporting.",
	
	-- options slider
	MT_MESSAGE_DELAY_NAME = "Message delay",
	MT_MESSAGE_DELAY_TEXT = "Set your on-screen message delay in milliseconds, i.e. 1000 units = 1 second.",
	MT_FREE_SLOTS_LEFT_LIMIT_NAME = "Free bag slots warning threshold",
	MT_FREE_SLOTS_LEFT_LIMIT_TEXT = "Set the minimum number of slots left in your bag before displaying a warning message about free slots left.",
	MT_MIN_SELL_PRICE_AUTOLOOT_NAME = "Minimum vendor price for autolooting",
	MT_MIN_SELL_PRICE_AUTOLOOT_TEXT = "Set the minimum vendor price to enable automatic looting of stolen items. Note that this exclude recipes, blueprints, and motifs, which are controlled by autoloot settings.",

	-- options dropdown
	MT_RECIPE_QUALITY_NAME = "Minimum quality of recipes",
	MT_RECIPE_QUALITY_TEXT = "Choose the minimum quality level of a recipe or blueprint to be autolooted. Unknowns below the given level will be autolooted only if you allow it explicitly.",
	MT_RECIPE_COLOR_GREEN = "green",
	MT_RECIPE_COLOR_BLUE = "blue",
	MT_RECIPE_COLOR_PURPLE = "purple",
	MT_RECIPE_COLOR_GOLD = "gold",

	-- options submenu - announcements
	MT_SUB_ANNOUNCE_NAME = "Announcements",
	MT_SUB_ANNOUNCE_TEXT = "All announcements",
	MT_SUB_ANNOUNCE_ONSCREENMSG_NAME = "Announce with on-screen message",
	MT_SUB_ANNOUNCE_ONSCREENMSG_TEXT = "Announce recipes blueprints, and motifs as on-screen message.",
	MT_SUB_ANNOUNCE_SPECIALS_NAME = "Announce special items in chat",
	MT_SUB_ANNOUNCE_SPECIALS_TEXT = "Announce recipes, blueprints, and motifs in chat. Only you will see these announcements.",
	MT_SUB_ANNOUNCE_REGULAR_NAME = "Announce information in chat",
	MT_SUB_ANNOUNCE_REGULAR_TEXT = "Announce information like payoffs to guards/launders, sold items, bounty, etc in chat.",	
	MT_SUB_ANNOUNCE_USELESS_NAME = "Announce junk items",
	MT_SUB_ANNOUNCE_USELESS_TEXT = "Announce junk items as defined by minimum autoloot vendor value. You can list these items with /mt_junk command. Excludes recipes blueprints, or motifs.",
	MT_SUB_ANNOUNCE_BECAREFUL_NAME = "Announce \"Be careful\" in sneak",
	MT_SUB_ANNOUNCE_BECAREFUL_TEXT = "Show \"Be careful\" message, because of the distance to NPCs is not far enough to be fully stealthed. This should assist you in fully stealthed sneaking and stealing.",	
	MT_SUB_ANNOUNCE_KNOWN_RECIPES_NAME = "Announce known recipes",
	MT_SUB_ANNOUNCE_KNOWN_RECIPES_TEXT = "Print a message about looting of already known recipes in chat.",	
	MT_SUB_ANNOUNCE_SELLS_TRANSFERS_NAME = "Announce item fence in chat",
	MT_SUB_ANNOUNCE_SELLS_TRANSFERS_TEXT = "Print a message about fence transactions in chat.",	
	MT_SUB_ANNOUNCE_MAX_FENCER_LIMITS_NAME = "Announce fencer limits",
	MT_SUB_ANNOUNCE_MAX_FENCER_LIMITS_TEXT = "Print a message about in chat if you have reached your maximum daily limit for fence or launder.",
	
	-- options submenu - companion
	MT_COMP_MENU_SUBMENU_NAME = "Companion Rapport Protection",
	MT_COMP_MENU_SUBMENU_TOOLTIP = "Settings to protect companion rapport during thieving activities.",
	MT_COMP_MENU_WARN_NAME = "Warn on Disapproved Actions",
	MT_COMP_MENU_WARN_TOOLTIP = "Show a warning when your companion would lose rapport.",
	MT_COMP_MENU_BLOCK_NAME = "Block Disapproved Actions",
	MT_COMP_MENU_BLOCK_TOOLTIP = "Prevent actions your companion disapproves of instead of just warning you.",
	MT_COMP_MENU_AUTODISMISS_NAME = "Auto-Dismiss at Dark Brotherhood Areas",
	MT_COMP_MENU_AUTODISMISS_TOOLTIP = "Automatically dismiss companions who dislike the Dark Brotherhood when you near their sanctuary.",

	-- Misc Text
	MT_MISC_TRASH_TEXT = "Junk: ",
	MT_MISC_SOLD_FOR = " sold for ",
	MT_MISC_BOUNTY_IS = "Bounty is ",
	MT_MISC_BOUNTY_REMOVED_FROM_BODY = "Full bounty got removed from your dead body!",
	MT_MISC_ALL_STOLEN_ITEMS_REMOVED = "All stolen items were removed by a guard!",
	MT_MISC_YOU_PAID_BOUNTY = "You've paid bounty: ",
	MT_MISC_YOU_SOLD_AN_ITEM_FOR = "You've fenced an item for ",
	MT_MISC_SNEAKMODE_ACTIVE = "Sneak and steal active",
	MT_MISC_SNEAKMODE_SLEEPING = "Sneak and steal inactive",
	MT_MISC_BE_CAREFUL = "Be careful!",
	MT_MISC_IS_KNOWN = "Already known: ",
	MT_MISC_FREE_SLOTS_LEFT = "Free slots left: ",
	MT_MISC_SELL_MAXIMUM_REACHED = "Warning: Carrying more items than remaining fence slots!",
	MT_MISC_TRANSFER_MAXIMUM_REACHED = "Warning: Carrying more items than remaining launder slots!",
	MT_MISC_ITEM_DESTROYED = "...destroyed!",
	MT_MISC_LIST_USELESS_ITEMS = "List of junk items: ",
	MT_MISC_USELESS_ITEMS_FOUND = "Junk items found: ",
	MT_MISC_TYPE_COMMAND_DESTROY_ITEM = "Type /mt_junk delete to destroy them",
	MT_MISC_NO_ITEMS_FOUND = "No items found to destroy",
	MT_MISC_ITEMS_BELOW_VALUE_USELESS = "Items below this sell price are junk: ",
	MT_MISC_FOUND_ALOT_GOLD_TEXT = "You've looted gold. Stolen: ",
	MT_MISC_ITS_KNOWN_BUT_WANTED_TEXT = "Known, but looted: ",
	MT_MISC_LOOTLIST_TEXT = "Show lootlist",

	--Text for command list on chat
	MT_MISC_MASTERTHIEF_COMMANDS = "MasterThief commands:",
	MT_MISC_MASTERTHIEF_LISTCOMMANDS = "List all chat commands",
	MT_MISC_CMD_LIST_ALL_USELESS_ITEMS = "List of all junk items",
	MT_MISC_CMD_DESTROY_ALL_USELESS_ITEMS = "destroy all junk items",
	
	--Text for recipe tooltip
	MT_MISC_TOOLTIP_RECIPE_CHARS = "This recipe is known by:",

	--Text for Lootlist
	MT_MISC_LOOTLIST_DELETE = " removed from lootlist",
	MT_MISC_ITEM_ADDED = " added to lootlist",
	MT_MISC_ITEM_ALREADY_ON_LOOTLIST = "Item is already on lootlist",
	MT_MISC_WORTHFUL_ITEMS = "Lootlist of interesting items",
	MT_MISC_ITEM_TOOLTIP = "item is already on lootlist",
	
	-- Text for Context-Menu
	MT_CONTEXTMENU_LOOT_MARK = "Mark for autoloot",	
	
	-- Statistics window headers
	MT_STATS_SESSION_HEADER = "Session Statistics",
	MT_STATS_LIFETIME_HEADER = "Lifetime Statistics",
	
	-- Session stats - Looting
	MT_STATS_ITEMS_LOOTED = "Items Auto-Looted:",
	MT_STATS_ITEMS_SKIPPED = "Items Skipped:",
	MT_STATS_MOTIFS_LOOTED = "Motifs Looted:",
	MT_STATS_RECIPES_LOOTED = "Recipes Looted:",
	MT_STATS_FURNISHING_PLANS = "Furnishing Plans:",
	MT_STATS_FURNISHINGS = "Furnishings Looted:",
	MT_STATS_HIDDEN_WALLETS = "Hidden Wallets:",
	MT_STATS_RESEARCH_PORTFOLIOS = "Research Portfolios:",
	MT_STATS_EDICTS = "Edicts Looted:",
	
	-- Session stats - Justice
	MT_STATS_PICKPOCKETS = "Pickpockets:",
	MT_STATS_SAFEBOXES = "Safeboxes Picked:",
	MT_STATS_DOORS = "Doors Picked:",
	MT_STATS_LOCKPICK_BREAKS_PREVENTED = "Tanlorin's Guidance:",
	MT_STATS_BOW_KILLS = "Blade of Woe Kills:",
	MT_STATS_GUARD_DEATHS = "Deaths by Guards:",
	MT_STATS_GOLD_FENCED = "Gold Fenced:",
	MT_STATS_HIGHEST_BOUNTY = "Highest Bounty:",
	MT_STATS_TROVES = "Thieves Troves:",
	MT_STATS_HIGHEST_VALUE = "Highest Value Item:",
	
	-- Lifetime stats
	MT_STATS_LIFETIME_BOUNTY_PAID = "Total Bounty Paid:",
	MT_STATS_GOLD_LAUNDERED = "Gold Spent Laundering:",
	MT_DIALOG_RESET_LIFETIME_TITLE = "Reset Lifetime Statistics",
	MT_DIALOG_RESET_LIFETIME_TEXT = "Are you sure you want to reset all lifetime statistics? This cannot be undone.",
	MT_DIALOG_RESET_LIFETIME_CONFIRM = "Reset",
	MT_DIALOG_RESET_LIFETIME_CANCEL = "Cancel",
	
	-- Buttons
	MT_STATS_RESET_SESSION = "Reset Session Stats",
	MT_STATS_RESET_LIFETIME = "Reset Lifetime Stats",
	MT_STATS_CLOSE = "Close",
	
	-- Bastian
	MT_COMP_STEALTH_BASTIAN = "dislikes all stealing and pickpocketing. Consider dismissing him.",
	MT_COMP_ARRESTED_BASTIAN = "dislikes fleeing! Ask for clemency or accept the fine to minimize rapport loss.",
	
	-- Isobel
	MT_COMP_STEALTH_ISOBEL = "dislikes stealing from containers, corpses, and Thieves Troves.",
	
	-- Sharp
	MT_COMP_STEALTH_SHARP = "dislikes pickpocketing a beggar, laborer, or fisher.",
	
	-- Tanlorin
	MT_COMP_STEALTH_TANLORIN = "will lose rapport if you steal children's toys or dolls, or loot corpses.",
	
	-- Zerith
	MT_COMP_STEALTH_ZERITH = "will lose rapport if you steal medicinal, religious, or sentimental items, loot corpses, or use edicts.",
	
	-- Arrest advice
	MT_COMP_ARRESTED_PAYBOUNTY = "dislikes paying guards! Flee or ask for clemency to avoid rapport loss.",
	MT_COMP_ARRESTED_GENERIC = "dislikes this situation! Consider your options carefully.",

	-- Other warnings
	MT_COMP_TROVE_WARN = "dislikes looting Thieves Troves! Rapport will decrease.",
	MT_COMP_PICKPOCKET_WARN = "dislikes pickpocketing! Rapport will decrease.",
	MT_COMP_CONTAINER_WARN = "dislikes stealing from containers! Rapport will decrease.",
	MT_COMP_CORPSE_WARN = "dislikes looting corpses! Rapport will decrease.",
	MT_COMP_BOUNTY_WARN = "dislikes you getting caught! Consider using an edict or dismissing before a guard arrests you.",
	MT_COMP_BOW_AVAILABLE_WARN = "dislikes assassination — Blade of Woe is available! Step away to avoid rapport loss.",
	MT_COMP_BOW_USED_WARN = "dislikes the Blade of Woe! Rapport has decreased.",
	MT_COMP_REFUGE_WARN = "dislikes Outlaw Refuges! Rapport will decrease.",
	MT_COMP_DB_WARN = "dislikes the Dark Brotherhood!",
	MT_COMP_PAYBOUNTY_WARN = "dislikes paying bounty to a guard! Rapport will decrease.",
	MT_COMP_FENCE_WARN = "dislikes fencing stolen goods! Rapport will decrease.",
	MT_COMP_EDICT_WARN = "dislikes using edicts! Rapport will decrease.",
	
	-- Blocked actions
	MT_COMP_TROVE_BLOCK = "dislikes Thieves Troves! Action blocked.",
	MT_COMP_PICKPOCKET_BLOCK = "dislikes pickpocketing! Action blocked.",
	MT_COMP_CONTAINER_BLOCK = "dislikes stealing from containers! Action blocked.",
	MT_COMP_BOW_BLOCK = "dislikes assassination! Blade of Woe blocked.",
	MT_COMP_REFUGE_BLOCK = "dislikes Outlaw Refuges! Entry blocked.",
	MT_COMP_DB_DISMISSED = "has been dismissed — she dislikes the Dark Brotherhood.",
	MT_COMP_FENCE_BLOCK = "dislikes fencing stolen goods! Fence closed.",
	MT_COMP_EDICT_BLOCK = "dislikes using edicts! Action blocked.",
	
}

for stringId, stringValue in pairs(localization_strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end