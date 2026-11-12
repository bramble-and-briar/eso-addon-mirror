-- lang/en.lua
-- English strings (default; other languages override single entries)

-- Only global of the addon (shared by all lua files): WhatDropsHere
WhatDropsHere = {}

local WDH_STRINGS = {
    -- General
    PREFIX              = "|c66CCFF[WDH]|r ",
    DEBUG_PREFIX        = "|c888888[WDH-Debug]|r ",

    -- Debug
    DEBUG_ON            = "|c88FF88[WDH]|r Debug mode ON.",
    DEBUG_OFF           = "|c88FF88[WDH]|r Debug mode OFF.",
    -- %s = source, %s = zone, %s = targetType, %s = AoE target, %s = AoE setting, %d = gold, %s = type
    DEBUG_SESSION       = "%s |cAAAAAA(zone: %s, targetType=%s, AoE target=%s, AoE setting=%s, gold=%d, type=%s)|r",
    -- %s = item, %d = count, %s = category
    DEBUG_ITEM          = "  %s x%d |cAAAAAA-> %s|r",
    -- %s = item link, %d = count
    DEBUG_NO_WINDOW     = "Loot without loot window: %s x%d",
    DEBUG_NEW_TARGET    = "New target without LOOT_CLOSED in between, previous session saved.",
    -- %s = source
    DEBUG_REOPEN        = "%s reopened, only known leftovers - not counted again.",
    DEBUG_NO_NAME       = "Loot without a source name discarded:",
    -- %s = action, %s = target
    DEBUG_INTERACT      = "Interaction: %s - %s",
    -- %s = item link, %d = count, %s = source of the open loot window
    DEBUG_DURING_WINDOW = "Loot during loot window, but not in its list (not counted): %s x%d (window: %s)",
    -- %s = item link, %d = count
    DEBUG_AFTER_WINDOW  = "Loot shortly after loot window, but not in its list (not counted): %s x%d",
    DEBUG_TIMEOUT       = "No LOOT_CLOSED after 5 sec., session saved anyway.",
    DEBUG_LATE          = "|cFFAA00Loot window was already empty (auto-loot was faster), counting the received loot:|r",

    -- Statistics (/wdh)
    -- %s = source, %s = zone, %d = loots, %d = gold
    RECORD_HEADER       = "|cFFFFFF%s|r |cAAAAAA(%s)|r - looted %dx, %d gold",
    RECORD_AOE          = " |cFFAA00[group loot]|r",
    RECORD_PICKPOCKET   = " |cFFAA00[pickpocketing]|r",
    RECORD_THEFT        = " |cFF6666[theft]|r",
    RECORD_LOOSE        = "Loose items",
    DEBUG_LOOSE_IGNORED = "|cFFAA00Item lying around (%s), not recorded:|r",
    -- %s = name, %d = count, %d = hits, %d = loots, %s = qualities
    RECORD_LINE         = "  %s: %d total, in %d of %d (%s)",
    RECORD_ITEM         = "      %s: %d total, in %d of %d (%s)",
    -- %s = set name, %s = slots, %d = count, %d = hits, %d = loots, %s = qualities
    RECORD_SET          = "  Set %s [%s]: %d total, in %d of %d (%s)",
    RECORD_NONE         = "|cAAAAAA[WDH]|r No data found.",
    RECORD_NO_LAST      = "|cAAAAAA[WDH]|r No last source known. Usage: /wdh [source name], overview: /wdh_zones",

    -- Zone list (/wdh_zone)
    ZONE_HEADER         = "|cFFFFFF[WDH] Sources in %s:|r",
    ZONE_ENTRY          = "  %s: %dx",

    -- Zone overview (/wdh_zones)
    ZONES_HEADER        = "|cFFFFFF[WDH] Saved data:|r",
    -- %s = zone, %d = sources, %d = loots
    ZONES_ENTRY         = "  %s: %d sources, %d loots",

    -- Crosshair display
    -- %d = loots
    HUD_HEADER          = "|cAAAAAAlooted %dx|r",
    -- %d = gold per loot
    HUD_GOLD            = "|cAAAAAA · avg %d gold|r",
    -- %s = name (colored), %d = count, %d = percent
    HUD_ITEM            = "%s  |cAAAAAA%dx · %d %%|r",
    -- %s = set name (colored), %s = slots, %d = count, %d = percent
    HUD_SET             = "%s [%s]  |cAAAAAA%dx · %d %%|r",
    -- %d = number of further entries, %s = name for /wdh
    HUD_MORE            = "|cAAAAAA+%d more (/wdh %s)|r",

    -- Settings
    NAMES_SET           = "|c88FF88[WDH]|r Show names at the crosshair from: %s",
    NAMES_USAGE         = "|cFFFF00[WDH]|r Usage: /wdh_names 0-5 (0 = everything by name, 2 = green and up, 3 = blue and up)",
    SHOW_SET            = "|c88FF88[WDH]|r Display threshold for all enabled source types: %s",
    SHOW_USAGE          = "|cFFFF00[WDH]|r Usage: /wdh_show 0-5 (0 = everything, 1 = white and up, 3 = blue and up)",
    HUD_ON              = "|c88FF88[WDH]|r Crosshair display ON.",
    HUD_OFF             = "|c88FF88[WDH]|r Crosshair display OFF.",
    HUD_UNITS_ON        = "|c88FF88[WDH]|r Display for living targets ON.",
    HUD_UNITS_OFF       = "|c88FF88[WDH]|r Display for living targets OFF.",

    -- Reset
    RESET_CONFIRM       = "yes",
    RESET_USAGE         = "|cFFFF00[WDH]|r Delete all data: /wdh_reset yes",
    RESET_DONE          = "|c88FF88[WDH]|r All data deleted.",

    -- Misc
    PICKPOCKET_UNKNOWN  = "Unknown victim",
    ZONE_ANYWHERE       = "anywhere",
    SET_UNKNOWN         = "Set #%d",
}

-- Settings menu (LibAddonMenu)
WDH_STRINGS.MENU_INTRO            = "Remembers what every loot source has given you so far and shows it at the crosshair.\n" ..
                                    "|cFFFF88All loot is always recorded.|r The display settings only decide what appears at the crosshair."
WDH_STRINGS.MENU_HUD_HEADER       = "Crosshair display"
WDH_STRINGS.MENU_HUD              = "Enable display"
WDH_STRINGS.MENU_HUD_TT           = "Shows next to the crosshair what the targeted source has given you so far. Hidden in combat."
WDH_STRINGS.MENU_MAX_LINES        = "Maximum entries"
WDH_STRINGS.MENU_MAX_LINES_TT     = "Further entries appear as \"+N more\". Full list with /wdh <name>."
WDH_STRINGS.MENU_TYPES_HEADER     = "Display by source type"
WDH_STRINGS.MENU_TYPES_INFO       = "Per source type: from which quality entries appear at the crosshair, or \"Off\". Entries below are only hidden, everything is always recorded."
WDH_STRINGS.MENU_ENEMIES          = "Enemies"
WDH_STRINGS.MENU_ENEMIES_TT       = "Corpses of enemies, animals and NPCs."
WDH_STRINGS.MENU_UNITS            = "   also living enemies"
WDH_STRINGS.MENU_UNITS_TT         = "Shows the statistics as soon as you target a living enemy (outside of combat). Only clear assignments, no group loot."
WDH_STRINGS.MENU_CONTAINERS       = "Chests and containers"
WDH_STRINGS.MENU_CONTAINERS_TT    = "Chests, sacks, barrels, crates, backpacks and other containers with a loot window."
WDH_STRINGS.MENU_RESOURCES        = "Resources"
WDH_STRINGS.MENU_RESOURCES_TT     = "Ore, wood, plants, fibers, runestones, solvents."
WDH_STRINGS.MENU_OTHER            = "Critters and other"
WDH_STRINGS.MENU_OTHER_TT         = "Critters picked up with \"Take\" and items without a loot window."
WDH_STRINGS.MENU_THEFT            = "Theft"
WDH_STRINGS.MENU_THEFT_TT         = "Owned containers, safeboxes and items that belong to someone. Stored separately from free containers with the same name."
WDH_STRINGS.MENU_DATA_HEADER      = "Database"
WDH_STRINGS.MENU_DATA_INFO        = "Every loot is stored completely: each item with item ID and category. All settings above only affect the display and can be changed at any time, also for past data."
WDH_STRINGS.MENU_NAME_QUALITY     = "Show names from quality"
WDH_STRINGS.MENU_NAME_QUALITY_TT  = "Below this, items are grouped into their category (e.g. \"Blacksmithing material\"). Set items, furnishings, style pages, treasure maps and leads always by name; trash, treasures and gear without a set always as a category. Full list with /wdh <name>."
-- %d = zones, %d = sources, %d = loots
WDH_STRINGS.MENU_DATA_SUMMARY     = "Recorded: %d zones, %d sources, %d loots."
WDH_STRINGS.MENU_ZONES            = "Zones in chat"
WDH_STRINGS.MENU_ZONES_TT         = "Lists all zones with recorded data in chat (like /wdh_zones)."
WDH_STRINGS.MENU_RESET            = "Delete all data"
WDH_STRINGS.MENU_RESET_TT         = "Deletes all collected loot. Settings are kept."
WDH_STRINGS.MENU_RESET_WARNING    = "All collected loot will be deleted permanently."
WDH_STRINGS.MENU_DEV_HEADER       = "Development"
WDH_STRINGS.MENU_DEBUG            = "Debug output in chat"
WDH_STRINGS.MENU_DEBUG_TT         = "Shows every loot with source, type and categories in chat. Applies to all characters."

-- Per-character settings
-- %s = character name
WDH_STRINGS.MENU_CHAR_INFO        = "The display settings apply to |cFFFFFF%s|r only. Every character has its own."
WDH_STRINGS.MENU_SHOW_OFF         = "Off"
WDH_STRINGS.MENU_COPY_HEADER      = "Settings of other characters"
WDH_STRINGS.MENU_COPY_INFO        = "Copies all display settings of another character to this character."
WDH_STRINGS.MENU_COPY_FROM        = "Copy from"
WDH_STRINGS.MENU_COPY_FROM_TT     = "A character appears here once it has logged in with What Drops Here?."
WDH_STRINGS.MENU_COPY_NONE        = "(no other characters)"
WDH_STRINGS.MENU_COPY             = "Copy"
WDH_STRINGS.MENU_COPY_TT          = "Replaces the display settings of this character with those of the selected character."
WDH_STRINGS.MENU_COPY_WARNING     = "The display settings of this character will be overwritten."
-- %s = character name
WDH_STRINGS.COPY_DONE             = "|c88FF88[WDH]|r Display settings copied from %s."

-- Gear slots
local WDH_SLOT_NAMES = {
    armor   = "Armor",
    weapon  = "Weapon",
    jewelry = "Jewelry",
    -- New slot since API 101052; name from the game
    trinket = ITEMTYPE_TRINKET and GetString("SI_ITEMTYPE", ITEMTYPE_TRINKET) or "Trinket",
}

-- Category display names (keys from WDH_Categories.lua)
local WDH_CAT_NAMES = {
    SET             = "Set gear",
    GEAR_ARMOR      = "Armor without set",
    GEAR_WEAPON     = "Weapon without set",
    GEAR_JEWELRY    = "Jewelry without set",
    GEAR_COMPANION  = "Companion gear",
    TREASURE        = "Treasures",
    TRASH           = "Trash",
    FURNISHING      = "Furnishing",
    FURNISHING_PLAN = "Furnishing plan",
    MOTIF           = "Motif",
    STYLE_PAGE      = "Style page",
    RECIPE          = "Recipe",
    COLLECTIBLE     = "Collectible",
    TREASURE_MAP    = "Treasure map",
    SURVEY          = "Survey report",
    TROPHY          = "Trophy",
    CONTAINER       = "Container",
    MAT_SMITH       = "Blacksmithing material",
    MAT_CLOTH       = "Clothing material (cloth)",
    MAT_LEATHER     = "Clothing material (leather)",
    MAT_WOOD        = "Woodworking material",
    MAT_JEWELRY     = "Jewelry material",
    MAT_STYLE       = "Style material",
    MAT_TRAIT       = "Trait material",
    MAT_FURNISHING  = "Furnishing material",
    TEMPER          = "Temper",
    REAGENT         = "Reagent",
    SOLVENT         = "Solvent",
    INGREDIENT      = "Ingredient",
    RUNE_ASPECT     = "Aspect rune",
    RUNE_ESSENCE    = "Essence rune",
    RUNE_POTENCY    = "Potency rune",
    LURE            = "Bait",
    CONSUMABLE      = "Consumable",
    GLYPH           = "Glyph",
    SOUL_GEM        = "Soul gem",
    TOOL            = "Tool",
    LEAD            = "Lead",
    TRINKET         = ITEMTYPE_TRINKET and GetString("SI_ITEMTYPE", ITEMTYPE_TRINKET) or "Trinket",
    NO_ITEM         = "Other (no item)",
    MISC            = "Other",
}

WhatDropsHere.L          = WDH_STRINGS
WhatDropsHere.SLOT_NAMES = WDH_SLOT_NAMES
WhatDropsHere.CAT_NAMES  = WDH_CAT_NAMES
