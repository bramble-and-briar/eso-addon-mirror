InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

local ART = "EsoUI/Art/"

-- Top-level groups, in display order.
IG.GROUPS = {
    -- What was made at this bench since you walked up to it, first in the improvement and
    -- deconstruction lists; never in the bag (JustCrafted.lua).
    { key = "JUSTCRAFTED", label = "JUST CRAFTED",       color = "F0A868", icon = ART .. "Crafting/smithing_tabIcon_creation_up.dds" },
    { key = "NEW",         label = "NEW",                color = "00F0FF", icon = ART .. "Inventory/newItem_icon.dds" },
    { key = "REWARDS",     label = "REWARDS",            color = "FFFAC8", icon = ART .. "Inventory/inventory_tabIcon_Container_up.dds" },
    -- UNCOLLECTED: unbound bind-on-equip pieces, and motifs, recipes and furnishing plans this
    -- character has not learned (BindOnEquip.lua). Called BIND ON EQUIP once; the key stays, so
    -- everything saved against it still reads.
    { key = "BINDONEQUIP", label = "UNCOLLECTED",        color = "3FD9C0", icon = ART .. "Inventory/inventory_tabIcon_armor_up.dds" },
    -- MODULES. Three things a module gathered, then what you have decided about a piece, then
    -- what is on its way out of the bag: none of it is a kind of thing the way a set or a
    -- potion is, which is what ATTENTION above is now left holding.
    -- What you are wearing first: a module like the rest (equippedEnabled), gathered from the
    -- worn bag rather than the backpack. A light aqua none of its neighbours wears.
    { key = "EQUIPPED",    label = "EQUIPPED",           color = "7FF5E8", icon = ART .. "Inventory/inventory_tabIcon_armor_up.dds" },
    { key = "LASTRUN",     label = "RECENT LOOT",        color = "FFB627", icon = ART .. "LFG/LFG_indexIcon_dungeon_up.dds" },
    { key = "ARMORY",      label = "ARMORY",             color = "FFFFFF", icon = "EsoUI/Art/Armory/buildItem_icon.dds" },
    -- Your saved equipment setups, one sub-category per setup (Setups.lua, setupsEnabled).
    { key = "SETUPS",      label = "SETUPS",             color = "E8C872", icon = "EsoUI/Art/Armory/buildItem_icon.dds" },
    { key = "HOME",        label = "HOME CONTAINERS",    color = "C59AA6", icon = ART .. "WorldMap/map_indexIcon_housing_up.dds" },
    -- What a crafting writ in the journal is waiting for: an errand like STOLEN below, and a
    -- light lime none of its neighbours wears (DailyWrit.lua).
    { key = "DAILYWRIT",   label = "DAILY WRIT",         color = "D2F56E", icon = "EsoUI/Art/Journal/journal_tabIcon_quest_up.dds" },
    -- The four piles of what is leaving the bag (STOLEN, SELL, SELL [GUILD STORE], DECONSTRUCT)
    -- under one heading; each can be moved back out on its own (IG.DISPOSAL_MEMBERS, below).
    -- Art: the guild store's own Sell tab (tradinghouse_sell_tabIcon_up.dds, the base UI's
    -- trading house tabs; also used by SetTracker).
    { key = "DISPOSAL",    label = "DISPOSAL",           color = "E8845C", icon = ART .. "TradingHouse/tradinghouse_sell_tabIcon_up.dds" },
    -- Where the fence is the errand, so it stands at the head of the pieces you are taking
    -- somewhere rather than among the things you are told about.
    { key = "STOLEN",      label = "STOLEN",             color = "FF5C5C", icon = ART .. "Inventory/inventory_stolenItem_icon.dds" },
    -- Nothing lands here by any rule: it holds what you have said, one piece at a time, you mean
    -- to sell. Orange, which nothing else it stands beside wears, so a decision of yours is not
    -- read as a guess of ours.
    { key = "SELL",        label = "SELL",               color = "FF9A2E", icon = ART .. "currency/currency_gold.dds" },
    -- The same decision told apart by where it is carried out. A piece worth more than a
    -- merchant pays for it is not sold at a merchant, and the pile you take to a guild store is
    -- a different errand from the pile you empty at the next vendor you walk past -- so it is a
    -- category of its own beside SELL rather than a note inside it. A paler gold than SELL's
    -- orange: they are the same errand, and a relative reads as one.
    { key = "GUILDSELL",   label = "SELL [GUILD STORE]", color = "F2D479", icon = ART .. "MainMenu/menuBar_guilds_up.dds" },
    -- Its twin: the other thing you decide to do with a piece rather than keep it.
    { key = "DECON",       label = "DECONSTRUCT",        color = "6FC3D9", icon = ART .. "Crafting/enchantment_tabIcon_deconstruction_up.dds" },
    -- Gear whose trait this character can still research (Researchable.lua): on its way to a
    -- research bench. The smithing bench's own Research tab; a light orchid none of its
    -- DISPOSAL neighbours wears.
    { key = "RESEARCH",    label = "RESEARCHABLE",       color = "D9A6FF", icon = ART .. "Crafting/smithing_tabIcon_research_up.dds" },
    -- A category that is nothing but what you put in it: no rule ever fills it, and what it is
    -- called is yours to say, from its own header. Third of the three you fill by hand.
    { key = "CUSTOM",      label = "CUSTOM",             color = "6FD3B5", icon = ART .. "MainMenu/menuBar_inventory_up.dds" },
    -- (TO BANK stands here, straight after CUSTOM; it is written at the foot of this table.)
    -- What the rules say is worth nothing, and what you said so yourself: the two ends of the
    -- same errand, and the foot of the heading because nobody goes looking here first.
    { key = "GARBAGE",     label = "GARBAGE",            color = "8E8E8E", icon = ART .. "Inventory/inventory_tabIcon_trash_up.dds" },
    { key = "JUNK",        label = "JUNK",               color = "7E7468", icon = ART .. "Inventory/inventory_tabIcon_junk_up.dds" },
    -- SETS. PVE SETS is the four dungeon and trial ones put back together; only one side of
    -- that is ever a group at a time (IG.IsGroupAvailable).
    { key = "PVE",         label = "PVE SETS",           color = "B98CFF", icon = ART .. "LFG/LFG_indexIcon_group_up.dds" },
    { key = "DUNGEON",     label = "DUNGEON SETS",       color = "D6BFFF", icon = ART .. "LFG/LFG_normalDungeon_up.dds" },
    -- A deeper purple than the base game dungeons rather than another shade of the same one:
    -- the two stood side by side and were two hues apart, which is no distance at all.
    { key = "DLCDUNGEON",  label = "DLC DUNGEON SETS",   color = "7B5CD6", icon = ART .. "LFG/LFG_veteranDungeon_up.dds" },
    { key = "ARENA",       label = "ARENA SETS",         color = "4FC3F7", icon = ART .. "Journal/leaderboard_indexIcon_challenge_up.dds" },
    { key = "TRIAL",       label = "TRIAL SETS",         color = "F5C542", icon = ART .. "Journal/leaderboard_indexIcon_raids_up.dds" },
    { key = "OVERLAND",    label = "OVERLAND SETS",      color = "7FD99A", icon = ART .. "LFG/LFG_indexIcon_zoneStories_up.dds" },
    { key = "CRAFTABLE",   label = "CRAFTABLE SETS",     color = "D9BC8C", icon = ART .. "Crafting/smithing_tabIcon_armorSet_up.dds" },
    { key = "MONSTER",     label = "MONSTER SETS",       color = "A6E05A", icon = ART .. "LFG/LFG_championDungeon_up.dds" },
    { key = "MYTHIC",      label = "MYTHIC ITEMS",       color = "FF8A4C", icon = ART .. "Journal/journal_tabIcon_antiquities_up.dds" },
    { key = "PVP",         label = "PVP SETS",           color = "5AA9FF", icon = ART .. "MainMenu/menuBar_ava_up.dds" },
    { key = "CLASS",       label = "CLASS SETS",         color = "FF6FA3", icon = ART .. "MainMenu/menuBar_skills_up.dds" },
    { key = "COMPANION",   label = "COMPANION GEAR",     color = "A9C2E6", icon = ART .. "Inventory/inventory_tabIcon_companion_up.dds" },
    -- Gear with no set that you locked: it reads oddly under SETS until you see that this is
    -- where you go looking for a piece, and a piece with no set is still a piece.
    { key = "NONSET",      label = "NON-SET ITEMS",      color = "9AA4B0", icon = ART .. "Inventory/inventory_tabIcon_weapons_up.dds" },
    -- COLLECTIBLES
    { key = "TOKENS",      label = "TOKENS",             color = "8C9BFF", icon = ART .. "MainMenu/menuBar_collections_up.dds" },
    { key = "EVENTS",      label = "EVENTS",             color = "E86BF0", icon = ART .. "TradingHouse/tradingHouse_holiday_writ_up.dds" },
    -- Away from the events' magenta it was standing next to: a page of a book, not a festival.
    { key = "MOTIFS",      label = "MOTIFS & STYLE PAGES", color = "9B6FD9", icon = ART .. "Collections/collections_tabIcon_outfitStyles_up.dds" },
    { key = "FURNISHING",  label = "FURNISHINGS",        color = "C9A27A", icon = ART .. "Collections/collections_tabIcon_housing_up.dds" },
    -- CONSUMABLES
    { key = "CONSUMABLES", label = "CONSUMABLES",        color = "4FDB8B", icon = ART .. "Inventory/inventory_tabIcon_consumables_up.dds" },
    { key = "POISONS",     label = "POISONS",            color = "8BE36B", icon = ART .. "TradingHouse/tradingHouse_potions_poisonSolvent_up.dds" },
    { key = "POTIONS",     label = "POTIONS",            color = "FF7A9A", icon = ART .. "TradingHouse/tradingHouse_potions_potionSolvent_up.dds" },
    { key = "FOODDRINK",   label = "FOOD & DRINK",       color = "F4A261", icon = ART .. "TradingHouse/tradingHouse_materials_provisioning_food_up.dds" },
    -- Steel rather than another tan: siege is metal, and the tan it wore was the same colour
    -- as the food standing above it.
    { key = "PVPSUPPLY",   label = "PVP CONSUMABLES",    color = "7FB5B0", icon = ART .. "Inventory/inventory_tabIcon_siege_up.dds" },
    -- Everything you spend on yourself rather than on a fight: experience scrolls, the riding
    -- lessons and skill line scrolls that never wear off, and the pardon edicts that buy back a
    -- bounty. EXPERIENCE SCROLLS is what this was called, and EDICTS stood beside it; the two
    -- were named after what the game files them as -- scroll trophies -- rather than after what
    -- they are for, and a lesson that raises your horse forever was reading as a scroll you
    -- drink before a dungeon. One category, no headings inside it: the list is short and every
    -- line of it is the same instruction. The colour is the one the experience scrolls already
    -- wore, so a bag that was sorted yesterday still reads the same today.
    { key = "BOOSTS",      label = "BOOSTS",             color = "F2F2F2", icon = ART .. "TradingHouse/tradingHouse_trophy_scroll_up.dds" },
    -- The five kinds BOOSTS is made of, each one a category it can be broken out into
    -- (IG.BOOST_KINDS, below). None of them stands unless it has been asked for, so a bag
    -- nobody has told otherwise reads as one BOOSTS and these are five headings inside it.
    -- They keep their place in this table all the same: a category that is folded away still
    -- has a name, a colour, an icon and a place of its own waiting for it, and the settings the
    -- player gave it are kept under the very same key.
    { key = "XPSCROLLS",   label = "EXPERIENCE SCROLLS", color = "DCC98F", icon = ART .. "TradingHouse/tradingHouse_trophy_scroll_up.dds" },
    { key = "SKILLSCROLLS",label = "SKILL LINE SCROLLS", color = "7FA8E8", icon = ART .. "MainMenu/menuBar_skills_up.dds" },
    { key = "RIDING",      label = "RIDING LESSONS",     color = "B08968", icon = ART .. "Collections/collections_tabIcon_mounts_up.dds" },
    { key = "EDICTS",      label = "PARDON EDICTS",      color = "C77BD9", icon = ART .. "Inventory/inventory_stolenItem_icon.dds" },
    -- Verses and visions: they are scroll trophies like an experience scroll, and no more an
    -- experience scroll than an edict is. What they have in common is where they are spent.
    -- It stood on its own once, and the name, the colour and the icon it wore then are the ones
    -- written here, so lifting it back out gives the same category it always was.
    { key = "ARCHIVE",     label = "INFINITE ARCHIVE",   color = "9B7BE0", icon = ART .. "LFG/LFG_veteranDungeon_up.dds" },
    -- WORLD
    { key = "WORLD",       label = "WORLD",              color = "8FCBB0", icon = ART .. "MainMenu/menuBar_map_up.dds" },
    { key = "RESOURCES",   label = "RESOURCES",          color = "9FB8A8", icon = ART .. "Inventory/inventory_tabIcon_tool_up.dds" },
    { key = "SCRIBING",    label = "SCRIBING",           color = "9A8CFF", icon = ART .. "Crafting/scribing_tabIcon_scribing_up.dds" },
    { key = "APPEARANCE",  label = "APPEARANCE",         color = "E89ACB", icon = ART .. "Inventory/inventory_tabIcon_appearance_up.dds" },
    { key = "TROPHIES",    label = "TROPHIES",           color = "D4A15C", icon = ART .. "Inventory/inventory_tabIcon_trophy_up.dds" },
    { key = "MAPS",        label = "TREASURE MAPS",      color = "E8D5A9", icon = ART .. "TradingHouse/tradingHouse_trophy_treasure_map_up.dds" },
    { key = "QUEST",       label = "QUEST ITEMS",        color = "FFA9A0", icon = ART .. "Inventory/inventory_tabIcon_quest_up.dds" },
    { key = "MISC",        label = "MISC",               color = "B5B5B5", icon = ART .. "Inventory/inventory_tabIcon_misc_up.dds" },
    { key = "CRAFT",       label = "CRAFT",              color = "F0A35C", icon = ART .. "Inventory/inventory_tabIcon_crafting_up.dds" },
    -- What you locked, out of the way. Last of all: the point of it is to be the end of the list.
    { key = "LOCKED",      label = "LOCKED",             color = "8C97A8", icon = ART .. "Miscellaneous/status_locked.dds" },
    -- What goes into the bank the next time it is opened (ToBank.lua): filled by hand like
    -- CUSTOM, emptied by the bank itself. A blue none of its neighbours wears. Art: the bank's
    -- own Deposit tab (LarvalTear/ui/main.lua:2782 builds the same path). Written last so that
    -- no category above moves a place down -- an order the player gave a category is compared
    -- with these numbers -- and placed after CUSTOM by an order of its own, below.
    { key = "TOBANK",      label = "TO BANK",            color = "6F9BFF", icon = ART .. "Bank/bank_tabIcon_deposit_up.dds" },
}

IG.GROUP_BY_KEY = {}
for order, group in ipairs(IG.GROUPS) do
    group.order = order
    IG.GROUP_BY_KEY[group.key] = group
end
-- Between CUSTOM and whatever comes after it.
IG.GROUP_BY_KEY.TOBANK.order = IG.GROUP_BY_KEY.CUSTOM.order + 0.5

---------------------------------------------------------------------------
-- A group as the user sees it: their own name, color, place and whether it shows at all.
-- Saved settings win over the defaults above.
---------------------------------------------------------------------------

-- Colors can be switched off (General > Visuals > Colors). Everything then wears ESO's own
-- default cream and the list has to read by shape alone.
local function ColorsOn()
    return not IG.sv or IG.sv.groupColors ~= false
end
IG.ColorsOn = ColorsOn

-- Two ways of colouring the categories, and this is the one that is on unless it is switched
-- off (Colors > Category Buttons): every heading is a colour family and every category under it
-- a tone of that family, so the list is read in blocks. Off, each category wears the colour it
-- was given, which owes nothing to what it stands among.
local function GroupedColors()
    return IG.sv ~= nil and IG.sv.coloredGroups ~= false
end

-- Written further down, once the colour maths it is built on has been read.
local SectionTone

-- Any color that isn't a group's own (an Armory loadout's green, a house chest's pink).
function IG.Tone(hex)
    return ColorsOn() and IG.Adapt(hex) or IG.DEFAULT_ICON_COLOR
end

local function Custom(key)
    return IG.sv and IG.sv.groups and IG.sv.groups[key] or nil
end

function IG.GetGroupLabel(key)
    local custom = Custom(key)
    if custom and custom.name then return custom.name end
    -- A key that is no category (a trading heading, a key from an older version) reads as
    -- itself rather than taking the menu down with it.
    local group = IG.GROUP_BY_KEY[key]
    return group and group.label or tostring(key or "")
end

function IG.GetGroupColor(key)
    -- With the colours switched off (Quiet, Quiet Black, Minimal) every heading is cream, the ones
    -- painted by hand included: a theme that says no colour means it. The painted colours are kept
    -- and come back with any theme that has colours.
    if not ColorsOn() then return IG.DEFAULT_ICON_COLOR end
    local custom = Custom(key)
    if custom and custom.color then return IG.Adapt(custom.color) end
    local group = IG.GROUP_BY_KEY[key]
    if not group then return IG.DEFAULT_ICON_COLOR end
    if GroupedColors() then return IG.Adapt(SectionTone(key)) end
    return IG.Adapt(group.color)
end

-- A destination written into the middle of a menu line, in one shape wherever it appears: the
-- name in capitals and in the colour its heading wears, with the sentence around it left in the
-- lettering the rest of the menu is written in. Where the line is a category and a verb, the
-- category is the part that is being chosen between -- "sell it" and "junk it" are read off the
-- one word that differs -- so that word is the one that stands out, and the same word stands out
-- the same way in every line that says it. No quotation marks: the capitals and the colour
-- already say this is a name and not part of the sentence, and the marks were only ever there
-- because nothing else was saying it.
--
-- The name is read live rather than written here, because the player can rename a category and
-- a line naming the old one names nothing.
function IG.MenuName(label, color)
    return string.format("|c%s%s|r", color or IG.DEFAULT_ICON_COLOR, zo_strupper(label or ""))
end

-- The usual case: a category, by key.
function IG.MenuGroupName(key)
    return IG.MenuName(IG.GetGroupLabel(key), IG.GetGroupColor(key))
end

-- The headings the list is read under, in the order they come. This order is the addon's and
-- is not the player's to change; which heading a category starts under is (Settings: Groups).
IG.SECTION_ORDER = { "ATTENTION", "MODULES", "SETS", "CONSUMABLES", "COLLECTIBLES", "WORLD",
    -- A heading of its own, and nothing else is read under it: what you locked is not a kind of
    -- thing, it is a decision you made about a thing.
    "LOCKED" }

-- The mark drawn before each heading's name, tinted the heading's own colour. One art family:
-- the keyboard tab and menu-bar *_up.dds buttons, each path used by the base UI.
IG.SECTION_ICONS = {
    ATTENTION    = "EsoUI/Art/MainMenu/menuBar_notifications_up.dds",       -- zo_mainmenu_keyboard.lua
    MODULES      = "EsoUI/Art/Inventory/inventory_tabIcon_items_up.dds",    -- inventorymenubar.lua
    SETS         = "EsoUI/Art/Collections/collections_tabIcon_itemSets_up.dds", -- itemsetcollectionsdata.lua
    CONSUMABLES  = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_up.dds", -- itemfilterutils.lua
    COLLECTIBLES = "EsoUI/Art/MainMenu/menuBar_collections_up.dds",         -- zo_mainmenu_keyboard.lua
    WORLD        = "EsoUI/Art/MainMenu/menuBar_map_up.dds",                 -- zo_mainmenu_keyboard.lua
    LOCKED       = "EsoUI/Art/Miscellaneous/locked_up.dds",
}

IG.SECTION_INDEX = {}
for index, name in ipairs(IG.SECTION_ORDER) do IG.SECTION_INDEX[name] = index end

-- Where each category starts out.
local DEFAULT_SECTION = {
    -- ATTENTION is what the bag has to tell you about a piece. What you are going to do with a
    -- piece -- sell it, break it, throw it away -- is not news, so it reads under MODULES.
    JUSTCRAFTED = "ATTENTION", NEW = "ATTENTION", REWARDS = "ATTENTION", BINDONEQUIP = "ATTENTION",
    EQUIPPED = "MODULES", LASTRUN = "MODULES", ARMORY = "MODULES", SETUPS = "MODULES", HOME = "MODULES", DAILYWRIT = "MODULES", STOLEN = "MODULES",
    SELL = "MODULES", GUILDSELL = "MODULES", DECON = "MODULES", RESEARCH = "MODULES", CUSTOM = "MODULES", DISPOSAL = "MODULES",
    TOBANK = "MODULES",
    GARBAGE = "MODULES",
    JUNK = "MODULES",
    PVE = "SETS", DUNGEON = "SETS", DLCDUNGEON = "SETS", ARENA = "SETS", TRIAL = "SETS",
    OVERLAND = "SETS", CRAFTABLE = "SETS", MONSTER = "SETS", MYTHIC = "SETS", PVP = "SETS",
    CLASS = "SETS", COMPANION = "SETS", NONSET = "SETS",
    CONSUMABLES = "CONSUMABLES", POISONS = "CONSUMABLES", POTIONS = "CONSUMABLES",
    FOODDRINK = "CONSUMABLES", PVPSUPPLY = "CONSUMABLES", BOOSTS = "CONSUMABLES",
    XPSCROLLS = "CONSUMABLES", SKILLSCROLLS = "CONSUMABLES", RIDING = "CONSUMABLES",
    EDICTS = "CONSUMABLES", ARCHIVE = "CONSUMABLES",
    TOKENS = "COLLECTIBLES", EVENTS = "COLLECTIBLES", MOTIFS = "COLLECTIBLES",
    FURNISHING = "COLLECTIBLES",
    WORLD = "WORLD", RESOURCES = "WORLD", SCRIBING = "WORLD", APPEARANCE = "WORLD",
    TROPHIES = "WORLD", MAPS = "WORLD", QUEST = "WORLD", MISC = "WORLD", CRAFT = "WORLD",
    LOCKED = "LOCKED",
}

function IG.SectionsOn()
    return IG.sv == nil or IG.sv.sections ~= false
end

function IG.GetGroupSection(key)
    local custom = Custom(key)
    if custom and custom.section then return custom.section end
    -- JUNK is the one category whose heading is asked rather than assumed: it either stands with
    -- the other modules, which is where it starts, or at the very foot of the list under WORLD.
    -- Moving it by hand still wins, as above.
    if key == "JUNK" and IG.sv and IG.sv.junkOnModules == false then return "WORLD" end
    return DEFAULT_SECTION[key] or "WORLD"
end

function IG.GetGroupOrder(key)
    local custom = Custom(key)
    return custom and custom.order or IG.GROUP_BY_KEY[key].order
end

-- Three categories that each held a family of sub-categories, and are that family standing as
-- categories of their own now. The switch on the Groups page can put one back the way it was,
-- but only while categorisation is off: with it on the white headings are made out of these
-- very categories, and a family put away would leave its heading with nothing under it.
IG.SPLIT_FAMILIES = {
    pve =         { merged = "PVE",         setting = "mergePveSets",
                    keys = { "DUNGEON", "DLCDUNGEON", "ARENA", "TRIAL" } },
    consumables = { merged = "CONSUMABLES", setting = "mergeConsumables",
                    -- BOOSTS is not on this list, though EXPERIENCE SCROLLS was. Back then what
                    -- stood in it was a drink you take before a dungeon; what stands in it now
                    -- mostly never wears off, and folding a permanent riding lesson back under
                    -- CONSUMABLES would file it with the food.
                    keys = { "POISONS", "POTIONS", "FOODDRINK", "PVPSUPPLY" } },
    world =       { merged = "WORLD",       setting = "mergeWorld",
                    keys = { "RESOURCES", "SCRIBING", "APPEARANCE", "TROPHIES" } },
}

local FAMILY_OF_MERGED, FAMILY_OF_SPLIT = {}, {}
for family, split in pairs(IG.SPLIT_FAMILIES) do
    FAMILY_OF_MERGED[split.merged] = family
    for _, key in ipairs(split.keys) do FAMILY_OF_SPLIT[key] = family end
end

function IG.IsFamilyMerged(family)
    local split = IG.SPLIT_FAMILIES[family]
    if not split or not IG.sv then return false end
    if IG.sv.sections ~= false then return false end
    return IG.sv[split.setting] == true
end

-- Whichever side of a family's switch is not standing is not a group at all just now, and
-- nothing should list it, count it or draw it empty. Overland is on neither side of the PVE
-- switch -- it is always its own -- so it is in no family and is always available.
---------------------------------------------------------------------------
-- BOOSTS and the kinds inside it
---------------------------------------------------------------------------

-- BOOSTS is one category holding several kinds of thing that happen to be used the same way:
-- you spend them on yourself. That is one answer for a bag with three of them in it and quite
-- another for a bag with thirty, so each kind can be lifted out of BOOSTS and left standing as
-- a category of its own (Settings: BOOSTS). INFINITE ARCHIVE is the one that was a category
-- before this table existed; it is a kind now like the rest, folded in unless it is asked for.
--
-- key is the category the kind becomes, and is a real entry in IG.GROUPS above -- which is what
-- makes its name, colour, icon and place, and everything the player has said about any of them,
-- survive being folded back in and lifted out again: they are kept under that key and nothing
-- here touches them. label is the heading it reads under while it is folded in, which is the
-- same name the classifier hands the splitter (Classify.lua: path.typeLabel).
IG.BOOST_KINDS = {
    { key = "XPSCROLLS",    label = "Experience Scrolls",
      blurb = "The scrolls you drink for a while: experience, and what the Crown Store sells "
          .. "alongside them." },
    { key = "SKILLSCROLLS", label = "Skill Line Scrolls",
      blurb = "Scrolls that raise a skill line for good rather than for an hour." },
    { key = "RIDING",       label = "Riding Lessons",
      blurb = "The lessons that raise your horse permanently. They never wear off, which is the "
          .. "one thing they have in common with nothing else standing in BOOSTS." },
    { key = "EDICTS",       label = "Pardon Edicts",
      blurb = "What buys back a bounty. Spent on a guard rather than on yourself, which is why "
          .. "it used to be a category of its own." },
    { key = "ARCHIVE",      label = "Infinite Archive",
      blurb = "Verses and visions, and the mystery boxes holding them. Spent inside the Archive, "
          .. "on the run you are on -- lift it out and you have the INFINITE ARCHIVE category "
          .. "exactly as it used to be, colour, icon, name and all." },
}

IG.BOOST_KIND_BY_KEY = {}
for order, kind in ipairs(IG.BOOST_KINDS) do
    kind.order = order
    IG.BOOST_KIND_BY_KEY[kind.key] = kind
end

-- Whether this kind is standing on its own today. Off is the answer for everything the player
-- has not asked about, so a bag nobody has touched has one BOOSTS in it and nothing else.
function IG.IsBoostSplit(key)
    if not IG.BOOST_KIND_BY_KEY[key] then return false end
    local split = IG.sv and IG.sv.boostSplit
    return split ~= nil and split[key] == true
end

function IG.SetBoostSplit(key, value)
    if not (IG.sv and IG.BOOST_KIND_BY_KEY[key]) then return end
    IG.sv.boostSplit = IG.sv.boostSplit or {}
    -- Written as nothing rather than as false: the table says which kinds were asked for, and a
    -- kind that was asked for and then put back has said nothing in the end.
    IG.sv.boostSplit[key] = value == true or nil
end

---------------------------------------------------------------------------
-- DISPOSAL and the categories inside it
---------------------------------------------------------------------------

-- DISPOSAL holds four categories as its sub-categories. Each stays a category in every other
-- way -- its key, name, colour, icon, menus, rules and the pieces sent to it are all its own --
-- and only the list draws it one level down, under DISPOSAL (InventoryGrouping.lua: the
-- paths are nested while the list is built, and a sub-category keeps its own key there).
-- Any of them can be moved back out to stand as a top-level category again, one at a time,
-- from its own heading (sv.disposalOut, account-wide). Default: all four inside.
IG.DISPOSAL_KEY = "DISPOSAL"
IG.DISPOSAL_MEMBERS = { STOLEN = true, SELL = true, GUILDSELL = true, DECON = true, RESEARCH = true }

function IG.InDisposal(key)
    if not (key and IG.DISPOSAL_MEMBERS[key]) then return false end
    local out = IG.sv and IG.sv.disposalOut
    return not (out and out[key])
end

function IG.SetDisposalOut(key, out)
    if not (IG.sv and IG.DISPOSAL_MEMBERS[key]) then return end
    IG.sv.disposalOut = IG.sv.disposalOut or {}
    if IG.NoteSaved then IG.NoteSaved(IG.sv.disposalOut, key) end
    -- Written as nothing rather than as false: the table only says which were moved out.
    IG.sv.disposalOut[key] = out == true or nil
end

-- A category nothing collects for: what is in it got there by hand, so there is no module of
-- its own to leave it out of the list and the switch is read here instead.
-- TO BANK's switch only says whether its button is on show. Off, the category is not drawn
-- and its pieces stand where they would on their own -- but the right click line and the
-- deposit at the bank go on working, because neither asks this (Overrides.lua: aside.always,
-- ToBank.lua reads the marks themselves).
local MODULE_ONLY = { CUSTOM = "customEnabled", GUILDSELL = "guildSellEnabled", TOBANK = "toBankShown",
    -- RESEARCHABLE is filled by the classifier, but only while its switch is on; off, a piece
    -- sent there by hand falls back too, and the category is not offered.
    RESEARCH = "researchableEnabled" }

function IG.IsGroupAvailable(key)
    -- DISPOSAL is there while at least one of its categories is inside it and standing.
    if key == IG.DISPOSAL_KEY then
        for member in pairs(IG.DISPOSAL_MEMBERS) do
            if IG.InDisposal(member) and IG.IsGroupAvailable(member) then return true end
        end
        return false
    end
    local module = MODULE_ONLY[key]
    if module and not (IG.sv and IG.sv[module] == true) then return false end
    -- A kind of boost is a category only while it has been lifted out of BOOSTS. Folded in, it
    -- is a heading inside one and nothing should list it, count it or draw it empty -- the same
    -- as the side of a split family that is not standing, below.
    if IG.BOOST_KIND_BY_KEY[key] then return IG.IsBoostSplit(key) end
    local merged = FAMILY_OF_MERGED[key]
    if merged then return IG.IsFamilyMerged(merged) end
    local split = FAMILY_OF_SPLIT[key]
    if split then return not IG.IsFamilyMerged(split) end
    return true
end

-- Every group there is right now, in the order they appear: the settings page, the right click
-- menu, the category tables and the lists themselves all walk this, so the side of the PVE
-- switch that is not standing is left out here and nothing downstream has to know about it.
function IG.GetOrderedGroups()
    local ordered = {}
    for _, group in ipairs(IG.GROUPS) do
        if IG.IsGroupAvailable(group.key) then ordered[#ordered + 1] = group end
    end
    table.sort(ordered, function(a, b)
        if IG.SectionsOn() then
            local sectionA = IG.SECTION_INDEX[IG.GetGroupSection(a.key)] or 0
            local sectionB = IG.SECTION_INDEX[IG.GetGroupSection(b.key)] or 0
            if sectionA ~= sectionB then return sectionA < sectionB end
        end
        local orderA, orderB = IG.GetGroupOrder(a.key), IG.GetGroupOrder(b.key)
        if orderA ~= orderB then return orderA < orderB end
        return a.order < b.order
    end)
    return ordered
end

-- Writes one of the user's group settings, creating the entry the first time.
function IG.SetGroupSetting(key, field, value)
    -- Both halves are noted, and in this order: the entry may not have existed at all before
    -- this call, so putting the field back is not enough to leave the settings as they were.
    -- The undo replay walks its notes backwards, which lands the field first and the entry
    -- after it (see Undo.lua).
    IG.NoteSaved(IG.sv.groups, key)
    IG.sv.groups[key] = IG.sv.groups[key] or {}
    IG.NoteSaved(IG.sv.groups[key], field)
    IG.sv.groups[key][field] = value
end

-- Colours painted on a heading by hand, from the menu its right click opens.
--
-- A category keeps its own in the settings it already has (groups[key].color, which the settings
-- page writes too). The two below had nowhere to keep one, so they got a table each, and what
-- they are kept under has to be the same name every time the list is built or the colour would
-- wander to another heading at the next login:
--   * a sub-heading by the node key the list already remembers it open or shut by -- the ids of
--     the headings above it and its own, joined -- so "PVE/Trial Sets" is Trial Sets under PVE
--     and nothing else;
--   * a set by the game's own set id, the same id the overrides table names a set with, so the
--     colour follows the set even when it is moved to another category.
-- The hex goes in raw and comes back through IG.Adapt, so a player on the colourblind setting
-- still gets a colour they can tell apart from the rest.
function IG.GetManualSubColor(nodeKey)
    local colors = nodeKey and IG.sv and IG.sv.subColors
    return colors and colors[nodeKey] or nil
end

function IG.SetManualSubColor(nodeKey, hex)
    if not (nodeKey and IG.sv and IG.sv.subColors) then return end
    IG.NoteSaved(IG.sv.subColors, nodeKey)
    IG.sv.subColors[nodeKey] = hex
end

function IG.GetManualSetColor(setId)
    local colors = setId and IG.sv and IG.sv.setColors
    return colors and colors[setId] or nil
end

function IG.SetManualSetColor(setId, hex)
    if not (setId and IG.sv and IG.sv.setColors) then return end
    IG.NoteSaved(IG.sv.setColors, setId)
    IG.sv.setColors[setId] = hex
end

-- Named sub-groups: fixed display order inside their parent, optional own color and icon
-- (without a color they use a dimmed parent color, without an icon the parent's icon).
local SUBGROUP_LIST = {
    -- PVE SETS
    { label = "Base Game Dungeon Sets", color = "D6BFFF", icon = ART .. "LFG/LFG_normalDungeon_up.dds" },
    { label = "DLC Dungeon Sets",       color = "A77BFF", icon = ART .. "LFG/LFG_veteranDungeon_up.dds" },
    { label = "Trial Sets",             color = "F5C542", icon = ART .. "Journal/leaderboard_indexIcon_raids_up.dds" },
    { label = "Arena Sets",             color = "4FC3F7", icon = ART .. "Journal/leaderboard_indexIcon_challenge_up.dds" },
    { label = "Overland Sets",          color = "7FD99A", icon = ART .. "LFG/LFG_indexIcon_zoneStories_up.dds" },
    -- PVP SETS
    { label = "Cyrodiil",               icon = ART .. "LFG/LFG_indexIcon_allianceWar_up.dds" },
    { label = "Imperial City",          icon = ART .. "LFG/LFG_indexIcon_imperialCity_up.dds" },
    { label = "Battleground",           icon = ART .. "LFG/LFG_indexIcon_battlegrounds_up.dds" },
    -- MYTHIC / GARBAGE
    { label = "Deconstruct",            icon = ART .. "Crafting/enchantment_tabIcon_deconstruction_up.dds" },
    { label = "Sell",                   icon = ART .. "currency/currency_gold.dds" },
    { label = "Weapons",                icon = ART .. "Inventory/inventory_tabIcon_weapons_up.dds" },
    { label = "Armor",                  icon = ART .. "Inventory/inventory_tabIcon_armor_up.dds" },
    { label = "Jewelry",                icon = ART .. "Crafting/jewelry_tabIcon_icon_up.dds" },
    { label = "Treasure",               icon = ART .. "Inventory/inventory_tabIcon_trash_up.dds" },
    -- RECENT LOOT: one pile for what a run through a city brought back.
    { label = "Stolen",                 color = "FF5C5C", icon = ART .. "Inventory/inventory_stolenItem_icon.dds" },
    -- CONSUMABLES
    { label = "Poisons",                color = "8BE36B", icon = ART .. "TradingHouse/tradingHouse_potions_poisonSolvent_up.dds" },
    { label = "Potions",                color = "FF7A9A", icon = ART .. "TradingHouse/tradingHouse_potions_potionSolvent_up.dds" },
    { label = "Food & Drink",           color = "F4A261", icon = ART .. "TradingHouse/tradingHouse_materials_provisioning_food_up.dds" },
    { label = "PvP Consumables",        color = "C2B38F", icon = ART .. "Inventory/inventory_tabIcon_siege_up.dds" },
    -- BOOSTS: the five kinds it is made of, as they read while they are folded into it. Each
    -- one wears the colour and the icon of the category it would be if it were lifted out, so
    -- lifting one out changes where it stands and nothing about how it looks.
    { label = "Experience Scrolls",     color = "DCC98F", icon = ART .. "TradingHouse/tradingHouse_trophy_scroll_up.dds" },
    { label = "Skill Line Scrolls",     color = "7FA8E8", icon = ART .. "MainMenu/menuBar_skills_up.dds" },
    { label = "Riding Lessons",         color = "B08968", icon = ART .. "Collections/collections_tabIcon_mounts_up.dds" },
    { label = "Pardon Edicts",          color = "C77BD9", icon = ART .. "Inventory/inventory_stolenItem_icon.dds" },
    { label = "Infinite Archive",       color = "9B7BE0", icon = ART .. "LFG/LFG_veteranDungeon_up.dds" },
    -- CRAFT
    { label = "Master Writs",           icon = ART .. "TradingHouse/tradingHouse_master_writ_up.dds" },
    { label = "Writ Rewards",           icon = ART .. "Inventory/inventory_tabIcon_Container_up.dds" },
    { label = "Survey Reports",         icon = ART .. "Crafting/smithing_tabIcon_refine_up.dds" },
    { label = "Materials",              icon = ART .. "Inventory/inventory_tabIcon_craftBag_up.dds" },
    { label = "Glyphs",                 icon = ART .. "Inventory/inventory_tabIcon_craftBag_enchanting_up.dds" },
    { label = "Recipes",                icon = ART .. "Inventory/inventory_tabIcon_recipe_up.dds" },
    { label = "Furnishing Plans",       icon = ART .. "Crafting/blueprints_tabIcon_up.dds" },
    { label = "Research Scrolls",       icon = ART .. "Crafting/smithing_tabIcon_research_up.dds" },
    -- WORLD
    { label = "Resources",              icon = ART .. "Inventory/inventory_tabIcon_tool_up.dds" },
    { label = "Scribing",               icon = ART .. "Crafting/scribing_tabIcon_scribing_up.dds" },
    { label = "Appearance",             icon = ART .. "Inventory/inventory_tabIcon_appearance_up.dds" },
    { label = "Trophies",               icon = ART .. "Inventory/inventory_tabIcon_trophy_up.dds" },
}

IG.SUBGROUP_LIST = SUBGROUP_LIST
IG.SUBGROUPS = {}
for order, sub in ipairs(SUBGROUP_LIST) do
    sub.order = order
    IG.SUBGROUPS[sub.label] = sub
end

-- Loadout headers under ARMORY: one soft greyish white for all of them.
IG.LOADOUT_COLOR = "C9CCD2"
-- The loadout you are wearing right now stands out from the others.
IG.EQUIPPED_LOADOUT_COLOR = "5CE07A"
-- House chests under HOME CONTAINERS.
IG.CHEST_COLOR = "D8B4BE"

-- Default ESO text color, used when icons are not tinted with the group color.
IG.DEFAULT_ICON_COLOR = "C5C29E"

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function RGBToHex(r, g, b)
    local function c(v) return zo_clamp(zo_round(v * 255), 0, 255) end
    return string.format("%02X%02X%02X", c(r), c(g), c(b))
end

IG.HexToRGB = HexToRGB
IG.RGBToHex = RGBToHex

-- A color pushed toward white, for text that has to read on top of a surface of its own color.
function IG.LightenColor(hex, amount)
    local r, g, b = HexToRGB(hex)
    return RGBToHex(r + (1 - r) * amount, g + (1 - g) * amount, b + (1 - b) * amount)
end

-- Sub-headers that are not sets (e.g. "Cyrodiil", "Weapons") use a dimmed parent color.
function IG.DimColor(hex, factor)
    local r, g, b = HexToRGB(hex)
    return RGBToHex(r * factor, g * factor, b * factor)
end

---------------------------------------------------------------------------
-- COLORED GROUPS: a colour family per heading, a tone of it per category
---------------------------------------------------------------------------

-- Which block of the list you are in is then answered before any name is read: what wants you
-- is red, the modules are its opposite, and every set in the list is one purple or another.
--
-- hue is where a family sits on the wheel, span how far its tones drift either side of that,
-- sat how much colour it carries. Seven families cannot be far apart on a wheel with only
-- three hundred and sixty degrees on it, so the two that stand next to each other in the list
-- are the ones set furthest apart, and the pair that ended up closest -- the pinks of the
-- collectibles and the ambers of the world under them -- are still seventy degrees apart.
local SECTION_FAMILY = {
    ATTENTION    = { hue = 12,  span = 34, sat = 0.85 },
    MODULES      = { hue = 188, span = 20, sat = 0.62 },
    SETS         = { hue = 266, span = 46, sat = 0.72 },
    CONSUMABLES  = { hue = 125, span = 56, sat = 0.62 },
    COLLECTIBLES = { hue = 332, span = 30, sat = 0.72 },
    WORLD        = { hue = 42,  span = 30, sat = 0.55 },
    -- What you locked is not a kind of thing, and it is not a colour either. A family of one
    -- has no run to be light or dark against, so it says outright how light it is: pale grey
    -- beside the pale olive the world ends on read as the same colour twice.
    LOCKED       = { hue = 214, span = 0,  sat = 0.12, light = 0.62 },
}
-- Two categories standing next to each other are told apart by how light they are rather than
-- by their hue, and light and dark simply take turns: every neighbour is then the full step
-- apart, which three bands could not manage -- a third of the steps between three of them are
-- half the distance, and half a step is not a difference. The hue drifts slowly across the
-- family underneath that, which is what still makes them relatives, and the saturation walks
-- three of its own on top, so the pattern cannot come round again before six have gone by.
local TONE_LIGHT = { 0.78, 0.56 }
local TONE_SAT = { 1, 0.72, 0.86 }
-- Sub-headings are tones of their parent the same way, by where they stand in their own run.
local SUB_DIM = { 0.88, 0.72, 0.80 }

local function HSLToHex(hue, sat, light)
    if sat <= 0 then return RGBToHex(light, light, light) end
    local q = light < 0.5 and light * (1 + sat) or light + sat - light * sat
    local p = 2 * light - q
    local function channel(shift)
        local t = (hue % 360) / 360 + shift
        if t < 0 then t = t + 1 elseif t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    return RGBToHex(channel(1 / 3), channel(0), channel(-1 / 3))
end

-- Offered out because the equipped-sets drawer hands out a colour per set the same way the
-- categories are toned here: a place on the wheel and a weight, rather than a colour written
-- down somewhere. Two ways of turning a hue into a hex would drift apart.
IG.HSLToHex = HSLToHex

-- Worked out for the whole list at once, since a category's tone is decided by where it stands
-- among the others under its own heading -- move one and the tones under that heading re-flow,
-- which is the point: what is next to what is what they are keeping apart.
local tones

function IG.ClearColorCache()
    tones = nil
end

local function BuildTones()
    tones = {}
    local ordered = IG.GetOrderedGroups()
    local counts, seen = {}, {}
    for _, group in ipairs(ordered) do
        local section = IG.GetGroupSection(group.key)
        counts[section] = (counts[section] or 0) + 1
    end
    for _, group in ipairs(ordered) do
        local section = IG.GetGroupSection(group.key)
        local family = SECTION_FAMILY[section] or SECTION_FAMILY.WORLD
        local index = (seen[section] or 0) + 1
        seen[section] = index
        -- Where this one stands in its family, from one end of the drift to the other.
        local count = counts[section]
        local place = count > 1 and (index - 1) / (count - 1) - 0.5 or 0
        tones[group.key] = HSLToHex(family.hue + place * family.span,
            family.sat * TONE_SAT[(index - 1) % #TONE_SAT + 1],
            family.light or TONE_LIGHT[(index - 1) % #TONE_LIGHT + 1])
    end
end

-- Assigns the local declared at the top of the file.
function SectionTone(key)
    if not tones then BuildTones() end
    -- A category that is not in the list at all (one side of a split family) still has a group
    -- colour to fall back on.
    local group = IG.GROUP_BY_KEY[key]
    return tones[key] or (group and group.color) or IG.DEFAULT_ICON_COLOR
end

---------------------------------------------------------------------------
-- What is done to a color after it has been chosen
---------------------------------------------------------------------------

-- Two of the looks change every color rather than any one of them, so neither is written down as
-- a color anywhere. They are done here instead, on the way out, which means they reach the colors
-- the player picked for themselves exactly as they reach the ones the addon ships with.

-- Low brightness: the same palette taken down a step, for a screen the full one shouts on.
-- The settings page writes the theme's own name in it, so it is shared rather than repeated.
IG.LOW_BRIGHTNESS = 0.65
local LOW_BRIGHTNESS = IG.LOW_BRIGHTNESS

-- sRGB is stored bent, so it is straightened before any of the arithmetic below and bent back
-- afterwards. Mixing cone responses on bent numbers gives the wrong color.
local function ToLinear(value)
    if value <= 0.04045 then return value / 12.92 end
    return ((value + 0.055) / 1.055) ^ 2.4
end

local function ToSRGB(value)
    value = zo_clamp(value, 0, 1)
    if value <= 0.0031308 then return value * 12.92 end
    return 1.055 * value ^ (1 / 2.4) - 0.055
end

-- How much each of the three cones answers a color, and back again.
local function ToLMS(r, g, b)
    return 17.8824 * r + 43.5161 * g + 4.11935 * b,
        3.45565 * r + 27.1554 * g + 3.86714 * b,
        0.0299566 * r + 0.184309 * g + 1.46709 * b
end

local function FromLMS(l, m, s)
    return 0.0809444479 * l - 0.130504409 * m + 0.116721066 * s,
        -0.0102485335 * l + 0.0540193266 * m - 0.113614708 * s,
        -0.000365296938 * l - 0.00412161469 * m + 0.693511405 * s
end

-- What that eye actually sees: the cone that is missing, rebuilt out of the two that are left.
local SIMULATE = {
    protanopia = function(l, m, s) return 2.02344 * m - 2.52581 * s, m, s end,
    deuteranopia = function(l, m, s) return l, 0.494207 * l + 1.24827 * s, s end,
    tritanopia = function(l, m, s) return l, m, -0.395913 * l + 0.801109 * m end,
}

-- Where the difference between the real color and the seen one is put back. Red and green lost
-- to each other come back apart as blue and yellow; blue and yellow lost come back as red and
-- green. The row is the channel written to, the column the channel the difference came from.
local SHIFT = {
    protanopia = { { 0, 0, 0 }, { 0.7, 1, 0 }, { 0.7, 0, 1 } },
    deuteranopia = { { 0, 0, 0 }, { 0.7, 1, 0 }, { 0.7, 0, 1 } },
    tritanopia = { { 1, 0, 0.7 }, { 0, 1, 0.7 }, { 0, 0, 0 } },
}

local function Daltonize(hex, mode)
    local simulate, shift = SIMULATE[mode], SHIFT[mode]
    if not simulate then return hex end

    local r, g, b = HexToRGB(hex)
    r, g, b = ToLinear(r), ToLinear(g), ToLinear(b)
    local seenR, seenG, seenB = FromLMS(simulate(ToLMS(r, g, b)))
    local lostR, lostG, lostB = r - seenR, g - seenG, b - seenB

    return RGBToHex(
        ToSRGB(r + shift[1][1] * lostR + shift[1][2] * lostG + shift[1][3] * lostB),
        ToSRGB(g + shift[2][1] * lostR + shift[2][2] * lostG + shift[2][3] * lostB),
        ToSRGB(b + shift[3][1] * lostR + shift[3][2] * lostG + shift[3][3] * lostB))
end

-- The mode in force, or nothing at all. Both halves are read fresh every time, and the answers
-- are kept under a key that carries them, so nothing has to be thrown away when they change.
local function Mode()
    if not IG.sv then return nil, false end
    -- Nothing to move when the categories are all wearing the same cream, and the page offers
    -- it on that same condition.
    local mode = ColorsOn() and IG.sv.colorblind or nil
    if mode == "off" then mode = nil end
    return mode, IG.sv.lowBrightness == true
end

local adapted = {}

-- Every color the lists draw leaves through here.
function IG.Adapt(hex)
    if not hex then return hex end
    local mode, dim = Mode()
    if not mode and not dim then return hex end

    local key = hex .. (mode or "") .. (dim and "-" or "")
    local answer = adapted[key]
    if not answer then
        answer = mode and Daltonize(hex, mode) or hex
        if dim then answer = IG.DimColor(answer, LOW_BRIGHTNESS) end
        adapted[key] = answer
    end
    return answer
end

-- A set's role colors, all of them at once. Untouched, the list comes back as it went in: it is
-- held in a cache of its own and copying it every time a header is drawn would buy nothing.
local function AdaptList(colors)
    local mode, dim = Mode()
    if not colors or (not mode and not dim) then return colors end
    local out = {}
    for index, hex in ipairs(colors) do out[index] = IG.Adapt(hex) end
    return out
end

-- Whole-word matching without %f frontier patterns: the game's Lua doesn't match them, which
-- silently turned every lookup into "not found". Text is reduced to lower case words with single
-- spaces between them (color codes dropped), and a term is then looked up as " term ".
function IG.NormalizeWords(text)
    text = zo_strlower(text or ""):gsub("|c%x%x%x%x%x%x", " "):gsub("|r", " "):gsub("[^%a]+", " ")
    return " " .. text .. " "
end

function IG.HasWord(normalized, term)
    return normalized:find(" " .. term .. " ", 1, true) ~= nil
end

-- A set's colors come from the roles it serves: one color for one role, two or three blended
-- across its header for sets that cover more. A set whose bonuses say nothing returns nothing,
-- and the caller falls back to the group's own color. Returns the first color and the whole list.
function IG.GetSetLook(setId, itemLink)
    if not ColorsOn() or IG.sv.roleColors == false then return nil end
    local colors = AdaptList(IG.GetSetRoleColors(setId, itemLink)) -- cached per set in SetDetails.lua
    return colors and colors[1] or nil, colors
end

-- GetSetLook for a set whose roles are already known rather than read off an item: the settings
-- preview's sample. Same answer, same two switches deciding it.
function IG.GetRoleLook(roles)
    if not ColorsOn() or IG.sv.roleColors == false then return nil end
    local colors = {}
    for index, role in ipairs(roles) do colors[index] = IG.Adapt(IG.RGBToHex(unpack(role.color))) end
    return colors[1], colors
end

-- A named sub-group ("DLC Dungeon Sets") has a color of its own; the rest, and all of them with
-- colors switched off, take a dimmed shade of the group above.
function IG.GetSubColor(parentColor, sub)
    -- The parent color has already been through IG.Adapt, so a shade of it needs nothing more.
    if ColorsOn() and sub and sub.color and not GroupedColors() then return IG.Adapt(sub.color) end
    -- In one family a sub-heading is a tone of its parent as well, and the same walk through
    -- the bands keeps the ones standing next to each other apart.
    if GroupedColors() and sub and sub.order then
        return IG.DimColor(parentColor, SUB_DIM[(sub.order - 1) % #SUB_DIM + 1])
    end
    return IG.DimColor(parentColor, 0.85)
end

-- Every icon used anywhere, offered as choices in the settings icon pickers.
function IG.GetAllIcons()
    local seen, icons = {}, {}
    local function add(icon)
        if icon and not seen[icon] then
            seen[icon] = true
            icons[#icons + 1] = icon
        end
    end
    for _, group in ipairs(IG.GROUPS) do add(group.icon) end
    for _, sub in ipairs(SUBGROUP_LIST) do add(sub.icon) end
    return icons
end
