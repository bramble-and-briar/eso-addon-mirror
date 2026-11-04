InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Cached once, not re-read from _G on every call (ESOUI admin review, 2026-11-02: every bare
-- `LibSets.xxx` sends Lua hunting through the whole global table for the entry). Safe to read
-- straight off the global here, at file load time: LibSets is a hard ## DependsOn, so its own
-- file has already run and set the global by the time any of ours does.
local libSets = LibSets

-- Builds a lookup set from global constant names, skipping any that don't exist in this client version.
local function ConstSet(...)
    local set = {}
    for _, name in ipairs({ ... }) do
        local value = _G[name]
        if value ~= nil then
            set[value] = true
        end
    end
    return set
end

-- Some items can only be told apart by their name. Those checks are skipped on other clients,
-- where the item simply stays in the group its type puts it in. Read this early: it used to be
-- declared halfway down the file, below the Archive's name check that asks it, so that check
-- was reading a global that does not exist and answered no to everything. Every verse went on
-- standing under the experience scrolls the fix was meant to take it away from.
local ENGLISH_CLIENT = GetCVar("Language.2") == "en"

local CONTAINER_TYPES = ConstSet("ITEMTYPE_CONTAINER", "ITEMTYPE_CONTAINER_CURRENCY", "ITEMTYPE_CONTAINER_STACKABLE")
local STYLE_PAGE_SPECIALIZED = ConstSet("SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE", "SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE")
-- UNCOLLECTED tells an outfit style page from a runebox by this same list (BindOnEquip.lua).
IG.STYLE_PAGE_SPECIALIZED = STYLE_PAGE_SPECIALIZED
local TROPHY_COLLECTIBLE_SPECIALIZED = ConstSet("SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH", "SPECIALIZED_ITEMTYPE_COLLECTIBLE_MONSTER_TROPHY")
local TOKEN_TROPHY_SPECIALIZED = ConstSet(
    "SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT",
    "SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT",
    "SPECIALIZED_ITEMTYPE_TROPHY_UPGRADE_FRAGMENT",
    "SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT",
    "SPECIALIZED_ITEMTYPE_TROPHY_KEY_FRAGMENT")
local QUEST_TROPHY_SPECIALIZED = ConstSet(
    "SPECIALIZED_ITEMTYPE_TROPHY_MUSEUM_PIECE",
    "SPECIALIZED_ITEMTYPE_TROPHY_KEY",
    "SPECIALIZED_ITEMTYPE_TROPHY_DUNGEON_BUFF_INGREDIENT",
    "SPECIALIZED_ITEMTYPE_TROPHY_TRIBUTE_CLUE")
-- Experience scrolls, skill line scrolls, pardon edicts and the Archive's verses: the game
-- marks all of them as scroll trophies, so no name matching is needed to gather them into
-- BOOSTS. Which kind of boost each one is does need a name, and that is asked below.
local XP_SCROLL_SPECIALIZED = ConstSet("SPECIALIZED_ITEMTYPE_TROPHY_SCROLL")
-- An unopened treasure map is a container as far as the game is concerned, and containers are
-- asked about before trophies are, so it was filed with the things you open for a reward. It is
-- not a reward: it is the map, and it belongs with the maps.
local TREASURE_MAP_WORDS = { "treasure map" }
-- What the Infinite Archive hands you. Matched as whole words rather than as pieces of one: a
-- universe and a diverse anything would otherwise be filed in the Archive. Anything else the
-- Archive starts handing out belongs on this list.
--
-- The name is asked in two places, because the Archive hands the same thing out in two shapes:
-- the verse itself, which the game files as a scroll trophy, and the mystery box holding one,
-- which it files as a container like any reward bag. Only the first was ever asked, so every
-- unopened verse stood under REWARDS and the group was left with half of what is its own.
local ARCHIVE_WORDS = { "verse", "verses", "vision", "visions" }

local function IsArchiveName(itemName)
    if not ENGLISH_CLIENT then return false end
    local words = IG.NormalizeWords(itemName)
    for _, term in ipairs(ARCHIVE_WORDS) do
        if IG.HasWord(words, term) then return true end
    end
    return false
end

-- Which kind of boost an item is (Colors.lua: IG.BOOST_KINDS). The game files nearly all of
-- them as one specialized type, so the only thing that tells them apart is the name, and the
-- order the names are asked in is the whole of the rule:
--
--   1. the Archive first and always, because a verse is a scroll trophy exactly as an
--      experience scroll is and would otherwise be swept up with the boosts you drink. This has
--      gone wrong twice before, in both directions, and it is asked first for that reason;
--   2. riding lessons, which are crown items whose name says what they raise;
--   3. skill line scrolls, before the experience scrolls they would otherwise read as -- "skill
--      line scroll" carries the word scroll and nothing about experience;
--   4. pardon edicts;
--   5. and what is left is an experience scroll, which is what the great majority of these are
--      and the only sensible thing to call one whose name matches nothing.
--
-- Off an English client no name is read at all, so everything answers as the fifth. That is the
-- same answer the addon has always given there -- one undivided BOOSTS -- and lifting a kind
-- out on such a client leaves an empty category, which is no worse than the empty INFINITE
-- ARCHIVE those clients already had.
local RIDING_WORDS = { "riding" }
local SKILL_LINE_WORDS = { "skill" }
local EDICT_WORDS = { "edict", "edicts" }

local function HasAnyWord(words, terms)
    for _, term in ipairs(terms) do
        if IG.HasWord(words, term) then return true end
    end
    return false
end

local function BoostKind(itemName)
    if IsArchiveName(itemName) then return "ARCHIVE" end
    if not ENGLISH_CLIENT then return "XPSCROLLS" end
    local words = IG.NormalizeWords(itemName)
    if HasAnyWord(words, RIDING_WORDS) then return "RIDING" end
    if HasAnyWord(words, SKILL_LINE_WORDS) then return "SKILLSCROLLS" end
    if HasAnyWord(words, EDICT_WORDS) then return "EDICTS" end
    return "XPSCROLLS"
end

-- Seasonal event items: toys like snowballs and mud balls, and event writs.
local EVENT_SPECIALIZED = ConstSet("SPECIALIZED_ITEMTYPE_TROPHY_TOY", "SPECIALIZED_ITEMTYPE_HOLIDAY_WRIT")
local FURNISHING_PLAN_SPECIALIZED = ConstSet(
    "SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING",
    "SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING")
-- UNCOLLECTED tells a furnishing plan from a recipe by this same list (BindOnEquip.lua).
IG.FURNISHING_PLAN_SPECIALIZED = FURNISHING_PLAN_SPECIALIZED

-- Item type -> { group key, sub-group label } for simple one-to-one rules. A rule belonging to
-- one of the split families carries both answers -- the category it stands as, and the group
-- and sub-group it goes back under -- and says which family, so the switch can be asked.
local TYPE_RULES = {}
local function Rule(groupKey, subLabel, ...)
    for value in pairs(ConstSet(...)) do
        TYPE_RULES[value] = { groupKey, subLabel }
    end
end

-- Both sides of a split family, so that a path naming the side that is not standing can be
-- turned into the side that is. Keyed both ways: by the heading the merged side reads under,
-- and by the category the split side is.
local FAMILY_SIDES = {}  -- [mergedGroup][subLabel] = { family, key }
local FAMILY_BACK = {}   -- [splitKey] = { family, merged, sub }

local function DeclareSide(family, key, mergedGroup, subLabel)
    FAMILY_SIDES[mergedGroup] = FAMILY_SIDES[mergedGroup] or {}
    FAMILY_SIDES[mergedGroup][subLabel] = { family = family, key = key }
    FAMILY_BACK[key] = { family = family, merged = mergedGroup, sub = subLabel }
end

local function SplitRule(family, key, mergedGroup, subLabel, ...)
    DeclareSide(family, key, mergedGroup, subLabel)
    for value in pairs(ConstSet(...)) do
        TYPE_RULES[value] = { mergedGroup, subLabel, family, key }
    end
end
SplitRule("consumables", "POISONS", "CONSUMABLES", "Poisons", "ITEMTYPE_POISON")
SplitRule("consumables", "POTIONS", "CONSUMABLES", "Potions", "ITEMTYPE_POTION")
-- Food and drink do the same job and are read the same way, so they are one thing here.
SplitRule("consumables", "FOODDRINK", "CONSUMABLES", "Food & Drink", "ITEMTYPE_FOOD", "ITEMTYPE_DRINK")
SplitRule("consumables", "PVPSUPPLY", "CONSUMABLES", "PvP Consumables",
    "ITEMTYPE_SIEGE", "ITEMTYPE_AVA_REPAIR", "ITEMTYPE_RECALL_STONE")

Rule("CRAFT", "Master Writs", "ITEMTYPE_MASTER_WRIT")
Rule("CRAFT", "Glyphs", "ITEMTYPE_GLYPH_ARMOR", "ITEMTYPE_GLYPH_JEWELRY", "ITEMTYPE_GLYPH_WEAPON")
Rule("MOTIFS", nil, "ITEMTYPE_RACIAL_STYLE_MOTIF")
-- Crafting materials normally live in the craft bag; they only land here when they show up.
Rule("CRAFT", "Materials",
    "ITEMTYPE_ADDITIVE", "ITEMTYPE_ARMOR_BOOSTER", "ITEMTYPE_ARMOR_TRAIT",
    "ITEMTYPE_BLACKSMITHING_BOOSTER", "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL",
    "ITEMTYPE_CLOTHIER_BOOSTER", "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_CLOTHIER_RAW_MATERIAL",
    "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY",
    "ITEMTYPE_ENCHANTMENT_BOOSTER", "ITEMTYPE_FISH", "ITEMTYPE_FLAVORING", "ITEMTYPE_FURNISHING_MATERIAL",
    "ITEMTYPE_INGREDIENT", "ITEMTYPE_JEWELRYCRAFTING_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL",
    "ITEMTYPE_JEWELRY_RAW_TRAIT", "ITEMTYPE_JEWELRY_TRAIT", "ITEMTYPE_POISON_BASE", "ITEMTYPE_POTION_BASE",
    "ITEMTYPE_RAW_MATERIAL", "ITEMTYPE_REAGENT", "ITEMTYPE_SPICE", "ITEMTYPE_STYLE_MATERIAL",
    "ITEMTYPE_WEAPON_BOOSTER", "ITEMTYPE_WEAPON_TRAIT", "ITEMTYPE_WOODWORKING_BOOSTER",
    "ITEMTYPE_WOODWORKING_MATERIAL", "ITEMTYPE_WOODWORKING_RAW_MATERIAL")
SplitRule("world", "RESOURCES", "WORLD", "Resources",
    "ITEMTYPE_SOUL_GEM", "ITEMTYPE_TOOL", "ITEMTYPE_CROWN_REPAIR", "ITEMTYPE_GROUP_REPAIR",
    "ITEMTYPE_LOCKPICK", "ITEMTYPE_LURE")
SplitRule("world", "SCRIBING", "WORLD", "Scribing",
    "ITEMTYPE_CRAFTED_ABILITY", "ITEMTYPE_CRAFTED_ABILITY_SCRIPT", "ITEMTYPE_SCRIBING_INK")
SplitRule("world", "APPEARANCE", "WORLD", "Appearance",
    "ITEMTYPE_COSTUME", "ITEMTYPE_DISGUISE", "ITEMTYPE_TABARD", "ITEMTYPE_DYE_STAMP")
Rule("FURNISHING", nil, "ITEMTYPE_FURNISHING")
Rule("GARBAGE", "Treasure", "ITEMTYPE_TREASURE", "ITEMTYPE_TRASH")

-- Intricate is worth more at a crafting station than it is anywhere else.
local DECONSTRUCT_TRAITS = ConstSet(
    "ITEM_TRAIT_TYPE_ARMOR_INTRICATE", "ITEM_TRAIT_TYPE_WEAPON_INTRICATE", "ITEM_TRAIT_TYPE_JEWELRY_INTRICATE")
-- Ornate is worth more at a merchant, and deconstructing one throws that away. They sat with the
-- intricate pieces because both are traits you keep a piece for; they are kept for opposite
-- reasons, and the category is the instruction.
local SELL_TRAITS = ConstSet(
    "ITEM_TRAIT_TYPE_ARMOR_ORNATE", "ITEM_TRAIT_TYPE_WEAPON_ORNATE", "ITEM_TRAIT_TYPE_JEWELRY_ORNATE")
local JEWELRY_EQUIP_TYPES = ConstSet("EQUIP_TYPE_NECK", "EQUIP_TYPE_RING")

-- Which category a setless piece's trait sends it to, or nothing if its trait says nothing.
-- SELL and DECONSTRUCT were the two categories you reached by deciding about a piece, and these
-- two traits are the game deciding the same thing for you: intricate is worth more broken down
-- and ornate is worth more sold, which is precisely what those two categories say. A piece
-- carrying one goes there on its own rather than standing in GARBAGE under a heading GARBAGE is
-- too flat to draw, where the instruction was written and never shown.
--
-- Both are AUTOMATE rules (Ornate Gear, Intricate Gear) and start off like every other rule; off,
-- the piece stands in GARBAGE with the rest of the setless gear.
local function TraitCategory(traitType)
    if DECONSTRUCT_TRAITS[traitType] then
        if IG.sv and IG.sv.autoDeconstructIntricate == true then return "DECON" end
    elseif SELL_TRAITS[traitType] then
        if IG.sv and IG.sv.autoSellOrnate == true then return "SELL" end
    end
    return nil
end

---------------------------------------------------------------------------
-- AUTOMATE: rules that file a piece into SELL or DECONSTRUCT on their own
---------------------------------------------------------------------------

-- Every rule is one switch and only ever says where a piece stands; nothing here acts on it
-- (the one thing that acts is the auto-sell in Trading.lua, and it only reads the category).
-- Every rule starts off: a fresh install sorts nothing into SELL or DECONSTRUCT until asked.
--
-- pair names the switch this one cannot be on together with: turning one on turns the other
-- off. The drawer page and the settings page are both drawn from this one table.
IG.AUTOMATE_RULES = {
    { section = "SELL", key = "autoSellTrash", name = "Trash",
      description = "Trash, treasures and sell-only trophies go to SELL. Off: GARBAGE." },
    { section = "SELL", key = "autoSellOrnate", name = "Ornate Gear",
      description = "Setless ornate gear goes to SELL." },
    { section = "SELL", key = "autoSellGlyphs", name = "Glyphs (instead of Deconstruct)",
      pair = "autoDeconGlyphs",
      description = "Glyphs go to SELL." },
    { section = "SELL", key = "autoSellTraitless", name = "Traitless Gear (instead of Deconstruct)",
      pair = "autoDeconTraitless",
      description = "Setless traitless gear goes to SELL." },
    { section = "SELL", key = "autoSellKnownRecipes", name = "Known Recipes",
      description = "Recipes and plans you already know go to SELL. Off: CRAFT." },
    { section = "DECON", key = "autoDeconstructIntricate", name = "Intricate Gear",
      description = "Setless intricate gear goes to DECONSTRUCT." },
    { section = "DECON", key = "autoDeconGlyphs", name = "Glyphs (instead of Sell)",
      pair = "autoSellGlyphs",
      description = "Glyphs go to DECONSTRUCT." },
    { section = "DECON", key = "autoDeconJewelry", name = "Setless Jewelry",
      description = "Setless rings and necklaces go to DECONSTRUCT." },
    { section = "DECON", key = "autoDeconTraitless", name = "Traitless Gear (instead of Sell)",
      pair = "autoSellTraitless",
      description = "Setless traitless gear goes to DECONSTRUCT." },
}

-- The actions: the two lines that do something to your items rather than saying where they
-- stand. Each one empties a category -- SELL at a merchant (Trading.lua), DECONSTRUCT at a
-- crafting station (Deconstruct.lua) -- whatever put the pieces there, a rule or your own hand.
-- Off does nothing; Ask puts up a window first; Auto does it as the window opens and says what it
-- did in chat. Showing moved pieces where they were (INFO SHOWN > Sold And Salvaged Pieces) and
-- keeping stolen items out of RECENT LOOT (RECENT LOOT's own settings) are about how the lists
-- are drawn, and stand with the rest of their kind rather than here.
IG.ACTION_PICK = {
    values = { "off", "ask", "auto" }, labels = { "Off", "Ask", "Auto" }, offValue = "off",
    -- Every answer its own colour on the drawer's line: off grey, ask amber, auto red.
    colors = { off = "9A9AA2", ask = "FFB627", auto = "FF5A4A" },
}
IG.AUTOMATE_ACTIONS = {
    { key = "actionSell", which = "sell", name = "Auto-Sell", button = "AUTO-SELL",
      description = "Sells everything in SELL at a merchant. Ask: confirm first. Auto: at once. "
          .. "Cannot be undone." },
    { key = "actionDecon", which = "decon", name = "Auto-Deconstruct", button = "AUTO-DECONSTRUCT",
      description = "Deconstructs everything in DECONSTRUCT at a crafting station. Ask: confirm "
          .. "first. Auto: at once. Cannot be undone." },
    { key = "actionFence", which = "fence", name = "Auto-Sell Stolen", button = "AUTO-SELL STOLEN",
      description = "Sells everything in STOLEN to a fence, up to however many it will buy this "
          .. "visit. Ask: confirm first. Auto: at once. Cannot be undone." },
}

local ACTION_SV_KEY = {}
for _, action in ipairs(IG.AUTOMATE_ACTIONS) do ACTION_SV_KEY[action.which] = action.key end

-- "off", "ask" or "auto" for "sell", "decon" or "fence".
function IG.ActionMode(which)
    local key = ACTION_SV_KEY[which]
    local value = key and IG.sv and IG.sv[key]
    return (value == "ask" or value == "auto") and value or "off"
end

-- A small tag after SELL's, DECONSTRUCT's and STOLEN's names while their action is on, so the
-- bag says which category is going to be emptied without the drawer having to be opened.
local ACTION_TAGS = {
    SELL = { which = "sell", ask = "ASK TO SELL", auto = "AUTO SELL" },
    DECON = { which = "decon", ask = "ASK TO DECONS", auto = "AUTO DECONS" },
    STOLEN = { which = "fence", ask = "ASK TO SELL", auto = "AUTO SELL" },
}
function IG.ActionHeaderTag(groupKey)
    local tag = ACTION_TAGS[groupKey]
    if not tag then return nil end
    local mode = IG.ActionMode(tag.which)
    if mode == "off" then return nil end
    return tag[mode], IG.ACTION_PICK.colors[mode]
end

local AUTOMATE_BY_KEY = {}
for _, rule in ipairs(IG.AUTOMATE_RULES) do AUTOMATE_BY_KEY[rule.key] = rule end

function IG.AutomateOn(key)
    local rule = AUTOMATE_BY_KEY[key]
    local value = IG.sv and IG.sv[key]
    if rule and rule.defaultOn then return value ~= false end
    return value == true
end

-- The one writer both pages use. A rule moves pieces, so the classify cache goes; the lists are
-- rebuilt by the caller through the normal path (IG.RefreshLists clears it again anyway).
function IG.SetAutomate(key, value)
    if not IG.sv then return end
    local rule = AUTOMATE_BY_KEY[key]
    IG.sv[key] = value and true or false
    if value and rule and rule.pair then IG.sv[rule.pair] = false end
    IG.ClearClassifyCache()
end

-- The two rules that come in pairs (a piece goes to SELL or to DECONSTRUCT, never both) are one
-- line each on both pages: Off, Sell or Deconstruct. The saved keys underneath are the two
-- rules above, so a save written before this reads the same. Both pages skip a rule with a
-- pair in its own section and draw these instead.
IG.AUTOMATE_PAIRS = {
    { name = "Glyphs", sell = "autoSellGlyphs", decon = "autoDeconGlyphs",
      description = "Glyphs go to SELL or DECONSTRUCT." },
    { name = "Traitless Gear", sell = "autoSellTraitless", decon = "autoDeconTraitless",
      description = "Setless traitless gear goes to SELL or DECONSTRUCT." },
}
-- Setless weapons and armour by quality, one line each. These keep their answer in
-- sv.autoSetless[quality] ("sell" / "decon", nil is off) rather than in two switches; quality is
-- GetItemLinkFunctionalQuality, the one GearRuleCategory reads. Trash quality counts as white.
for _, q in ipairs({
    { "White", "ITEM_FUNCTIONAL_QUALITY_NORMAL" }, { "Green", "ITEM_FUNCTIONAL_QUALITY_MAGIC" },
    { "Blue", "ITEM_FUNCTIONAL_QUALITY_ARCANE" }, { "Purple", "ITEM_FUNCTIONAL_QUALITY_ARTIFACT" },
    { "Gold", "ITEM_FUNCTIONAL_QUALITY_LEGENDARY" },
}) do
    local quality = _G[q[2]]
    if quality then
        IG.AUTOMATE_PAIRS[#IG.AUTOMATE_PAIRS + 1] = { name = "Setless " .. q[1], quality = quality,
            description = "Setless " .. string.lower(q[1]) .. " weapons and armour go to SELL or "
                .. "DECONSTRUCT." }
    end
end
-- offValue: the answer that reads as off (dimmed) on the drawer's line.
IG.AUTOMATE_PAIR_PICK = { values = { "off", "sell", "decon" }, labels = { "Off", "To SELL", "To DECON" },
    offValue = "off" }

function IG.AutomatePairGet(pair)
    if pair.quality then
        local value = IG.sv and IG.sv.autoSetless and IG.sv.autoSetless[pair.quality]
        return (value == "sell" or value == "decon") and value or "off"
    end
    if IG.AutomateOn(pair.sell) then return "sell" end
    if IG.AutomateOn(pair.decon) then return "decon" end
    return "off"
end

function IG.AutomatePairSet(pair, value)
    if not IG.sv then return end
    if pair.quality then
        IG.sv.autoSetless = IG.sv.autoSetless or {}
        IG.sv.autoSetless[pair.quality] = (value == "sell" or value == "decon") and value or nil
        IG.ClearClassifyCache()
        return
    end
    IG.SetAutomate(pair.sell, value == "sell")
    IG.SetAutomate(pair.decon, value == "decon")
end

-- Where every rule stands on the AUTOMATE drawer and on its settings category: by what the
-- piece is, not by where it goes. Setless gear is one tab (its trait, its quality, jewellery),
-- everything else that is not gear is the other. A line names a rule of IG.AUTOMATE_RULES by its
-- key, or a line of IG.AUTOMATE_PAIRS by its name. A rule with one way to go reads Off or that
-- way (Sell / Deconstruct), the same answers a paired line gives, so every line on these two
-- tabs says where its pieces end up.
IG.AUTOMATE_LAYOUT = {
    { tab = "GEAR", title = "By trait",
      lines = { "autoSellOrnate", "autoDeconstructIntricate", "Traitless Gear" } },
    { tab = "GEAR", title = "By quality",
      lines = { "Setless White", "Setless Green", "Setless Blue", "Setless Purple", "Setless Gold" } },
    { tab = "GEAR", title = "Jewelry", lines = { "autoDeconJewelry" } },
    { tab = "ITEMS", title = "Items", lines = { "autoSellTrash", "autoSellKnownRecipes", "Glyphs" } },
}

-- The answer a one-way rule gives, and the category it names on the settings page. Written as a
-- place ("To SELL") rather than a deed ("Sell"), because a rule only sorts: the actions above the
-- tabs are the only lines that sell or deconstruct anything.
local TARGET_LABEL = { SELL = "To SELL", DECON = "To DECON" }
local TARGET_CATEGORY = { SELL = "SELL", DECON = "DECONSTRUCT" }

-- The lines of one tab, section by section: { title, lines = { { name, description, pick, get,
-- set, target } } }. A line whose rule or pair this client does not have is left out.
function IG.AutomateSections(tab)
    local pairsByName = {}
    for _, pair in ipairs(IG.AUTOMATE_PAIRS) do pairsByName[pair.name] = pair end
    local sections = {}
    for _, section in ipairs(IG.AUTOMATE_LAYOUT) do
        if section.tab == tab then
            local lines = {}
            for _, ref in ipairs(section.lines) do
                local rule, pair = AUTOMATE_BY_KEY[ref], pairsByName[ref]
                if rule then
                    local key, target = rule.key, TARGET_LABEL[rule.section] or "On"
                    lines[#lines + 1] = {
                        name = rule.name, description = rule.description, target = target,
                        category = TARGET_CATEGORY[rule.section],
                        pick = { values = { false, true }, labels = { "Off", target }, offValue = false },
                        get = function() return IG.AutomateOn(key) end,
                        set = function(value) IG.SetAutomate(key, value == true) end,
                    }
                elseif pair then
                    lines[#lines + 1] = {
                        name = pair.name, description = pair.description, pick = IG.AUTOMATE_PAIR_PICK,
                        get = function() return IG.AutomatePairGet(pair) end,
                        set = function(value) IG.AutomatePairSet(pair, value) end,
                    }
                end
            end
            if #lines > 0 then sections[#sections + 1] = { title = section.title, lines = lines } end
        end
    end
    return sections
end

local GLYPH_TYPES = ConstSet("ITEMTYPE_GLYPH_ARMOR", "ITEMTYPE_GLYPH_JEWELRY", "ITEMTYPE_GLYPH_WEAPON")

-- A rule may only send a piece to a category that is standing; otherwise it says nothing and
-- the piece stays where it would have gone.
local function RuleTarget(key)
    if key and IG.IsGroupAvailable(key) then return key end
    return nil
end

-- Where a setless piece of gear is sent by the rules, or nil. The traits first (they were first
-- before any other rule existed), then the traitless pair, then jewellery, then quality.
local function GearRuleCategory(itemLink, equipType, traitType)
    local trait = TraitCategory(traitType)
    if trait then return RuleTarget(trait) end
    if traitType == ITEM_TRAIT_TYPE_NONE then
        if IG.AutomateOn("autoSellTraitless") then return RuleTarget("SELL") end
        if IG.AutomateOn("autoDeconTraitless") then return RuleTarget("DECON") end
    end
    if JEWELRY_EQUIP_TYPES[equipType] then
        if IG.AutomateOn("autoDeconJewelry") then return RuleTarget("DECON") end
        return nil
    end
    -- Quality comes last, so the traitless line wins over it.
    local quality = GetItemLinkFunctionalQuality(itemLink)
    if quality and quality < ITEM_FUNCTIONAL_QUALITY_NORMAL then quality = ITEM_FUNCTIONAL_QUALITY_NORMAL end
    local pick = quality and IG.sv and IG.sv.autoSetless and IG.sv.autoSetless[quality]
    if pick == "sell" then return RuleTarget("SELL") end
    if pick == "decon" then return RuleTarget("DECON") end
    return nil
end

-- Where a rule sends an item that is not gear, or nil. The Trash rule also takes plain
-- treasures (specialized type TREASURE only) that are not stolen: stolen ones are the fence's
-- and are sent to STOLEN before this is ever asked, the link check is a second guard.
local function TypeRuleCategory(itemType, specializedType, itemLink)
    if itemType == ITEMTYPE_TREASURE then
        if specializedType == SPECIALIZED_ITEMTYPE_TREASURE
            and not (itemLink and IsItemLinkStolen(itemLink))
            and IG.AutomateOn("autoSellTrash") then
            return RuleTarget("SELL")
        end
    elseif itemType == ITEMTYPE_TRASH then
        if IG.AutomateOn("autoSellTrash") then return RuleTarget("SELL") end
    elseif GLYPH_TYPES[itemType] then
        if IG.AutomateOn("autoSellGlyphs") then return RuleTarget("SELL") end
        if IG.AutomateOn("autoDeconGlyphs") then return RuleTarget("DECON") end
    end
    return nil
end

-- Writ reward containers are named after the crafter ("Blacksmith's Satchel", "Enchanter's Coffer", ...).
local WRIT_REWARD_WORDS = { "blacksmith", "clothier", "woodworker", "enchanter", "alchemist", "provisioner", "jewelry crafter", "jeweler", "shipment" }

local function ContainsAny(text, words)
    for _, word in ipairs(words) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

local function NameHas(lowerName, words)
    return ENGLISH_CLIENT and ContainsAny(lowerName, words)
end

local function GearSlotLabel(itemType, equipType)
    if itemType == ITEMTYPE_WEAPON then return "Weapons" end
    if JEWELRY_EQUIP_TYPES[equipType] then return "Jewelry" end
    return "Armor"
end

-- Which heading inside GARBAGE a piece would have stood under, if GARBAGE had headings. It has
-- none by choice (see FLAT_KEYS), so the classifier works this out on the way in and drops it;
-- the auto-junk in Junk.lua is the one caller that wants the finer answer, and asking for it
-- here keeps the rule in the one file that owns it rather than copied into the module.
--
-- Read from the link alone, because it is asked one slot at a time as things land in the bag
-- and there is no row to read. Nil for anything that is not garbage at all, which is most of
-- what arrives.
function IG.GarbageKind(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex)
    if itemLink == nil or itemLink == "" then return nil end

    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_TREASURE or itemType == ITEMTYPE_TRASH then return "Treasure" end
    if itemType ~= ITEMTYPE_WEAPON and itemType ~= ITEMTYPE_ARMOR then return nil end

    -- A companion's gear is read with the companion, never as garbage, and a piece of a set is
    -- filed under its set whatever its trait says. Both are the classifier's own order of
    -- questions, kept here so the two answers cannot drift apart.
    if GetItemLinkActorCategory
        and GetItemLinkActorCategory(itemLink) == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        return nil
    end
    if GetItemLinkSetInfo(itemLink, false) then return nil end

    local traitType = GetItemLinkTraitInfo(itemLink)
    -- A trait that takes the piece out of GARBAGE altogether answers for it first: it is not
    -- garbage of any kind then, and the auto-junk has nothing to ask about it. With that rule
    -- switched off the piece is back in GARBAGE and reads under its old heading -- a heading no
    -- switch offers, so it is still never junked, which is the whole point of naming it.
    if GearRuleCategory(itemLink, GetItemLinkEquipType(itemLink), traitType) then return nil end
    if DECONSTRUCT_TRAITS[traitType] then return "Deconstruct" end
    if SELL_TRAITS[traitType] then return "Sell" end
    return GearSlotLabel(itemType, GetItemLinkEquipType(itemLink))
end

-- The same for a set, which answers in parts rather than with a path.
local function PveSet(key, label)
    if IG.IsFamilyMerged("pve") then return "PVE", label end
    return key
end

-- Cyrodiil, the Imperial City and the battlegrounds are headings inside PVP SETS only if you
-- ask for them. Every other category lists its sets one under another and says where each one
-- drops on the set's own header, which is where the question is actually asked; three headings
-- over three short runs answer it before it is asked and cost two clicks to get past.
local function PvpPlace(label)
    if IG.sv and IG.sv.pvpByInstance == true then return label end
    return nil
end

-- One handler per LIBSETS_SETTYPE_*, dispatched through SET_TYPE_HANDLERS below instead of an
-- if/elseif chain (ESOUI admin review, 2026-11-02) -- same branches, same order of precedence,
-- nothing about where a set ends up changes. Each handler returns exactly what its old branch
-- returned: a group key alone, or a group key plus a sub-group label.
local function HandleDungeonSet(setId)
    local dlcId = libSets.GetDLCId(setId)
    if dlcId == nil or dlcId == DLC_BASE_GAME then
        return PveSet("DUNGEON", "Base Game Dungeon Sets")
    end
    return PveSet("DLCDUNGEON", "DLC Dungeon Sets")
end

local function HandleTrialSet() return PveSet("TRIAL", "Trial Sets") end
local function HandleArenaSet() return PveSet("ARENA", "Arena Sets") end

-- Never put back with the rest: where a set drops in the world says nothing about how you came
-- by it, so it is a group of its own on either side of the switch.
local function HandleOverlandSet() return "OVERLAND" end

local function HandleCraftedSet() return "CRAFTABLE" end
local function HandleMonsterSet() return "MONSTER" end
local function HandleCyrodiilSet() return "PVP", PvpPlace("Cyrodiil") end

-- The reward sets the daily random dungeon and the Imperial City both hand out. They were read
-- as dungeon sets, and since the DLC they belong to is not the base game they stood under DLC
-- DUNGEON SETS -- beside sets from dungeons they have nothing to do with, and against what their
-- own drop location says, which is the City.
local function HandleImperialCitySet() return "PVP", PvpPlace("Imperial City") end
local function HandleBattlegroundSet() return "PVP", PvpPlace("Battleground") end
local function HandleMythicSet() return "MYTHIC" end
local function HandleClassSet() return "CLASS" end

local SET_TYPE_HANDLERS = {
    [LIBSETS_SETTYPE_DUNGEON] = HandleDungeonSet,
    [LIBSETS_SETTYPE_TRIAL] = HandleTrialSet,
    [LIBSETS_SETTYPE_ARENA] = HandleArenaSet,
    [LIBSETS_SETTYPE_OVERLAND] = HandleOverlandSet,
    [LIBSETS_SETTYPE_CRAFTED] = HandleCraftedSet,
    [LIBSETS_SETTYPE_MONSTER] = HandleMonsterSet,
    [LIBSETS_SETTYPE_IMPERIALCITY_MONSTER] = HandleMonsterSet,
    [LIBSETS_SETTYPE_CYRODIIL_MONSTER] = HandleMonsterSet,
    [LIBSETS_SETTYPE_CYRODIIL] = HandleCyrodiilSet,
    [LIBSETS_SETTYPE_IMPERIALCITY] = HandleImperialCitySet,
    [LIBSETS_SETTYPE_DAILYRANDOMDUNGEONANDICREWARD] = HandleImperialCitySet,
    [LIBSETS_SETTYPE_BATTLEGROUND] = HandleBattlegroundSet,
    [LIBSETS_SETTYPE_MYTHIC] = HandleMythicSet,
    [LIBSETS_SETTYPE_CLASS] = HandleClassSet,
}

-- Maps a set to a group key and an optional sub-group label. IsMythicSet/IsClassSet are asked
-- ahead of GetSetType, same as before the table existed -- a set LibSets would otherwise type as
-- something else (a crafted mythic, say) is still caught here first.
local function SetGroupFromLibSets(setId)
    if libSets.IsMythicSet(setId) then return "MYTHIC" end
    if libSets.IsClassSet(setId) then return "CLASS" end

    local setType = libSets.GetSetType(setId)
    if setType == nil then return nil end

    local handler = SET_TYPE_HANDLERS[setType]
    if handler then return handler(setId) end
    return "MISC"
end

-- The category a set stands under, asked by set id alone. Everything else here classifies a
-- piece that is in a bag; the equipped-sets drawer has a set and no piece to classify, because
-- what it is looking at is on the character, and it jumps to the category by this.
function IG.SetGroupKey(setId)
    if not (setId and libSets and libSets.fullyLoaded) then return nil end
    local groupKey = SetGroupFromLibSets(setId)
    return groupKey
end

-- Where a set comes from, shown on the right of its header.
-- Dungeon-like sets name their dungeon/trial/arena, the others their zone.
local LOCATION_BY_ZONE = { OVERLAND = true, CRAFTABLE = true, MYTHIC = true, PVP = true }

local function GetSetLocation(setId, groupKey, subLabel)
    local names
    if not LOCATION_BY_ZONE[groupKey] and subLabel ~= "Overland Sets" then
        -- LibSets returns these as a set: { [name] = true }
        local nameSet = libSets.GetDropLocationNamesBySetId(setId)
        if nameSet then
            names = {}
            -- A name with a colon is not a place but a list of who drops what ("Varlariel:
            -- Head, chest, shoulders / ..." for the older trials); the zone below names the place.
            for name in pairs(nameSet) do
                if type(name) == "string" and not name:find(":", 1, true) then names[#names + 1] = name end
            end
            table.sort(names)
        end
    end
    if not names or #names == 0 then
        local zoneIds = libSets.GetZoneIds(setId)
        if zoneIds then
            names = {}
            for _, zoneId in ipairs(zoneIds) do
                local name = libSets.GetZoneName(zoneId)
                if name and name ~= "" then
                    names[#names + 1] = name
                end
            end
        end
    end
    if not names or #names == 0 then return nil end
    -- Only the main location; extra entries are usually the same place in another form.
    return zo_strformat("<<1>>", names[1])
end

-- Node helpers. A path is a list of nodes { id, label, color, icon, iconKey, order, location };
-- the first node is the top-level group.
-- order is what the player put this category at. A node standing at the top of the list is
-- sorted by that number directly and never reads the field; one standing under LOCKED has only
-- its siblings to be sorted against, and this keeps that run in the same order as the list it
-- was taken out of.
-- What a category counts beside its name, where the rows it opens are not the answer. A
-- category that holds whatever you put in it holds things, not an arrangement of things: how
-- many sets they happen to fall into is not what you put there.
local COUNTS_ITEMS = { CUSTOM = true, GUILDSELL = true, TOBANK = true, TOHOME = true }

local function GroupNode(key)
    local group = IG.GROUP_BY_KEY[key]
    return { id = key, label = IG.GetGroupLabel(key), color = IG.GetGroupColor(key),
        icon = group.icon, iconKey = key, order = IG.GetGroupOrder(key),
        countsItems = COUNTS_ITEMS[key] }
end

local function SubNode(parent, label)
    local sub = IG.SUBGROUPS[label]
    return {
        id = label,
        label = label,
        color = IG.GetSubColor(parent.color, sub),
        icon = sub and sub.icon or parent.icon,
        iconKey = "sub:" .. label,
        order = sub and sub.order,
    }
end

-- Where the unknown goes. A rule that asks for a category that is not there has met an item
-- nobody wrote a rule for, and MISC is where the addon already puts those.
local FALLBACK_KEY = "MISC"
-- Categories with no headings inside them. GARBAGE holds what you are done with, and sorting
-- that into kinds is work spent on the wrong end of the bag. BOOSTS is flat for the opposite
-- reason: it is short, and every line in it says the same thing -- use this on yourself.
--
-- SELL and DECONSTRUCT are flat for a third reason. They were flat by accident before -- every
-- piece in them had been sent by hand, and nothing sent by hand says what it is -- and now that
-- traits fill them the pieces do say. Drawing that as a heading would make them the only two
-- categories a piece can be in either under a heading or straight under the category, depending
-- on how it got there, and the splitter reads a category with one heading in it as already
-- shaped and leaves it alone. Flat, both roads end in the same place: the heading is set down
-- as typeLabel, and Split Long Categories draws it for the whole category at once or not at all.
local FLAT_KEYS = { GARBAGE = true, BOOSTS = true, SELL = true, DECON = true }

-- Only one side of a split family is a category at a time, and a rule may name either. Rather
-- than ask every rule to remember which -- one of them did not, and conjured a CONSUMABLES
-- category with an EXPERIENCE SCROLLS heading inside it while both were standing on their own --
-- the side that is not standing is translated here. This is the one place a path is built, so
-- nothing downstream has to know, and a category that does not exist cannot be drawn.
local function Standing(key, subLabel)
    local sides = FAMILY_SIDES[key]
    local side = sides and subLabel and sides[subLabel]
    if side and not IG.IsFamilyMerged(side.family) then
        -- Named the merged group while the family stands apart: the heading is the category.
        key, subLabel = side.key, nil
    else
        local back = FAMILY_BACK[key]
        if back and IG.IsFamilyMerged(back.family) then
            -- Named a category while the family is back together: it is a heading again.
            key, subLabel = back.merged, subLabel or back.sub
        end
    end
    -- Whatever is left must be a category that exists and is standing. Anything else is a rule
    -- written without this in mind, or an item the game added since; it goes where the unknown
    -- goes rather than inventing a heading of its own.
    if not IG.GROUP_BY_KEY[key] or not IG.IsGroupAvailable(key) then
        return FALLBACK_KEY, nil
    end
    return key, subLabel
end

local function Path(key, subLabel)
    key, subLabel = Standing(key, subLabel)
    -- The heading a flat category will not draw is not thrown away, only set down beside the
    -- path: a category asked to break itself into what its pieces are has to know what this
    -- piece would have been called, and working it out a second time from the item would mean
    -- a second copy of every rule that named it here.
    local dropped
    if FLAT_KEYS[key] then dropped, subLabel = subLabel, nil end
    local root = GroupNode(key)
    if subLabel then
        return { root, SubNode(root, subLabel) }
    end
    return { root, typeLabel = dropped }
end

-- A category of a split family: it stands on its own, or goes back under the group it came
-- from with its old sub-group heading, depending on the switch in Settings > Groups.
local function FamilyPath(family, key, mergedGroup, subLabel)
    if IG.IsFamilyMerged(family) then return Path(mergedGroup, subLabel) end
    return Path(key)
end

-- One kind of boost, standing wherever the player has put it. Lifted out of BOOSTS it is a
-- category and nothing else is said about it; folded in, it is BOOSTS carrying the heading the
-- kind reads under -- and BOOSTS is flat, so Path sets that heading down beside the path as
-- typeLabel rather than drawing it (see FLAT_KEYS above).
--
-- Which settles, in this one line, how this meets the other way a category can be broken up.
-- Breaking BOOSTS by type (Settings: Split Long Categories, or the category's own right click
-- menu) reads that very typeLabel, so the two are the same headings arrived at by two roads and
-- can never disagree. The order is: a kind lifted out is gone from BOOSTS before the splitter
-- ever sees the list, so BOOSTS' own answer is not asked about it and cannot reach it; what is
-- left behind is what BOOSTS' answer is about, and it goes on working on exactly that.
local function BoostPath(kind)
    if IG.IsBoostSplit(kind) then return Path(kind) end
    return Path("BOOSTS", IG.BOOST_KIND_BY_KEY[kind].label)
end

local function SetNode(setId, setName, itemLink, groupKey, subLabel)
    local color, colors = IG.GetSetLook(setId, itemLink)
    return {
        id = "set" .. setId,
        label = zo_strformat("<<1>>", setName),
        -- No role came out of the bonuses: the set wears its group's color.
        color = color or IG.GetGroupColor(groupKey),
        colors = colors,
        isSet = true,
        setId = setId,
        location = GetSetLocation(setId, groupKey, subLabel),
    }
end

-- The set header node for an item (used under ARMORY loadouts, where every set gets a header,
-- mythics included). Returns nil for items that aren't part of a set.
local setNodeCache = {}

function IG.GetSetNode(itemLink)
    local cached = setNodeCache[itemLink]
    if cached ~= nil then return cached or nil end
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
    if not hasSet then
        setNodeCache[itemLink] = false
        return nil
    end
    local groupKey, subLabel
    if libSets.fullyLoaded then
        groupKey, subLabel = SetGroupFromLibSets(setId)
    end
    local node = SetNode(setId, setName, itemLink, groupKey or "MISC", subLabel)
    -- Only cache once LibSets is ready, so the location gets filled in later.
    if libSets.fullyLoaded then setNodeCache[itemLink] = node end
    return node
end

local function ClassifyGear(itemLink, itemType, equipType)
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)

    if not hasSet then
        local traitType = GetItemLinkTraitInfo(itemLink)
        local slotLabel = GearSlotLabel(itemType, equipType)
        -- The trait first: it names a category of its own, and the piece carries the slot it
        -- fills in as the heading that category reads it under once it is worth splitting.
        local aside = GearRuleCategory(itemLink, equipType, traitType)
        local home = Path("GARBAGE", (DECONSTRUCT_TRAITS[traitType] and "Deconstruct")
            or (SELL_TRAITS[traitType] and "Sell")
            or slotLabel)
        -- Marked, so that a lock on one of these can be answered differently. The treasure and
        -- trash that also lands in GARBAGE is not gear, and a lock on it says nothing about sets.
        home.nonSetGear = true
        if not aside then return home, true end
        -- A rule sent it: it keeps where it would have stood, for a lock or the worn bag to
        -- fall back to (ClassifyWith).
        local path = Path(aside, slotLabel)
        path.nonSetGear = true
        path.automated = aside
        path.ruleHome = home
        return path, true
    end

    -- LibSets loads its data after login; don't cache until it's ready.
    if not libSets.fullyLoaded then
        return Path("MISC"), false
    end

    local groupKey, subLabel = SetGroupFromLibSets(setId)
    if not groupKey and GetItemLinkDisplayQuality(itemLink) == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
        groupKey = "MYTHIC"
    end
    groupKey = groupKey or "MISC"

    if groupKey == "MYTHIC" then
        -- Mythics have no set header, so the location is shown on the item row itself.
        local path = Path("MYTHIC", GearSlotLabel(itemType, equipType))
        path.itemLocation = GetSetLocation(setId, groupKey)
        return path, true
    end

    local path = Path(groupKey, subLabel)
    path[#path + 1] = SetNode(setId, setName, itemLink, groupKey, subLabel)
    return path, true
end

-- Classification that depends only on the item link (cached per link).
-- Returns path, cacheable.
local function ClassifyStatic(itemLink, slotData)
    local itemType, specializedType = GetItemLinkItemType(itemLink)
    local lowerName = zo_strlower(GetItemLinkName(itemLink))

    if slotData.actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        return Path("COMPANION"), true
    end

    if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR then
        return ClassifyGear(itemLink, itemType, GetItemLinkEquipType(itemLink))
    end

    if XP_SCROLL_SPECIALIZED[specializedType] then
        return BoostPath(BoostKind(lowerName)), true
    end
    if itemType == ITEMTYPE_CROWN_ITEM then
        -- Crown items are nearly all boosts -- experience scrolls and the riding lessons that
        -- raise your horse for good. The two that are not are told apart by name on English
        -- clients, and they are asked before any kind of boost is named: they leave BOOSTS
        -- altogether, so naming a kind first would be answering a question that is not put.
        if NameHas(lowerName, { "research" }) then return Path("CRAFT", "Research Scrolls"), true end
        if NameHas(lowerName, { "mimic stone" }) then return Path("CRAFT", "Materials"), true end
        return BoostPath(BoostKind(lowerName)), true
    end

    if EVENT_SPECIALIZED[specializedType] then
        return Path("EVENTS"), true
    end
    if STYLE_PAGE_SPECIALIZED[specializedType] then
        return Path("MOTIFS"), true
    end
    if CONTAINER_TYPES[itemType] then
        if NameHas(lowerName, WRIT_REWARD_WORDS) then
            return Path("CRAFT", "Writ Rewards"), true
        end
        if specializedType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP
            or NameHas(lowerName, TREASURE_MAP_WORDS) then
            return Path("MAPS"), true
        end
        -- A box holding a verse is no more a reward bag than the verse in it is an experience
        -- scroll: it is spent where the rest of the Archive's is spent. Asked here, inside the
        -- container branch and before the runebox check below it, because an unopened verse is
        -- a container as far as the game is concerned and containers are answered before names
        -- are read anywhere else -- which is how every verse came to stand under REWARDS once.
        if IsArchiveName(lowerName) then return BoostPath("ARCHIVE"), true end
        -- Runeboxes and the like hand you a collectible when opened.
        if GetItemLinkContainerCollectibleId and GetItemLinkContainerCollectibleId(itemLink) ~= 0 then
            return Path("TOKENS"), true
        end
        return Path("REWARDS"), true
    end
    if itemType == ITEMTYPE_COLLECTIBLE then
        if TROPHY_COLLECTIBLE_SPECIALIZED[specializedType] then
            return FamilyPath("world", "TROPHIES", "WORLD", "Trophies"), true
        end
        return Path("TOKENS"), true
    end
    if itemType == ITEMTYPE_RECIPE then
        local label = FURNISHING_PLAN_SPECIALIZED[specializedType] and "Furnishing Plans" or "Recipes"
        local home = Path("CRAFT", label)
        -- The Known Recipes rule is the only way a recipe reaches SELL on its own. Off (the
        -- default), nothing asks whether it is known. On, the answer changes the moment the
        -- recipe is learned, so the result is not cached against the link.
        if not IG.AutomateOn("autoSellKnownRecipes") then return home, true end
        local aside = IsItemLinkRecipeKnown(itemLink) and RuleTarget("SELL") or nil
        if not aside then return home, false end
        local path = Path(aside, label)
        path.automated = aside
        path.ruleHome = home
        return path, false
    end

    if itemType == ITEMTYPE_TROPHY then
        if specializedType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP then
            return Path("MAPS"), true
        elseif specializedType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
            return Path("CRAFT", "Survey Reports"), true
        elseif TOKEN_TROPHY_SPECIALIZED[specializedType] then
            return Path("TOKENS"), true
        elseif specializedType == SPECIALIZED_ITEMTYPE_TROPHY_MATERIAL_UPGRADER then
            return Path("CRAFT", "Materials"), true
        elseif QUEST_TROPHY_SPECIALIZED[specializedType] then
            return Path("QUEST"), true
        elseif specializedType == SPECIALIZED_ITEMTYPE_NONE and not IsItemLinkBound(itemLink)
            and (GetItemLinkValue(itemLink) or 0) > 0 then
            -- A trophy with no specialized type is the plain "sell to a merchant" kind: every
            -- useful trophy (maps, surveys, fragments, keys, toys, scrolls) carries its own.
            -- It is garbage like a treasure, and the Trash rule sends it to SELL unless stolen.
            local home = Path("GARBAGE", "Treasure")
            if not IG.AutomateOn("autoSellTrash") or IsItemLinkStolen(itemLink) then
                return home, true
            end
            local path = Path(RuleTarget("SELL"), "Treasure")
            path.automated = RuleTarget("SELL")
            path.ruleHome = home
            return path, true
        end
    end

    local rule = TYPE_RULES[itemType]
    if rule then
        local home
        if rule[3] then home = FamilyPath(rule[3], rule[4], rule[1], rule[2])
        else home = Path(rule[1], rule[2]) end
        local aside = TypeRuleCategory(itemType, specializedType, itemLink)
        if not aside then return home, true end
        local path = Path(aside, itemType == ITEMTYPE_TRASH and "Trash" or rule[2])
        path.automated = aside
        path.ruleHome = home
        return path, true
    end

    -- Bound leftovers that can't be traded or deleted are almost always quest-related.
    if IsItemLinkBound(itemLink) and (itemType == ITEMTYPE_TROPHY or itemType == ITEMTYPE_NONE) then
        return Path("QUEST"), true
    end

    return Path("MISC"), true
end

IG.MakeGroupNode = GroupNode
IG.MakeSubNode = SubNode

-- Boxes, coffers, reward bags: things that hand you other items when you open them.
function IG.IsContainerItem(itemLink)
    return itemLink ~= nil and itemLink ~= "" and CONTAINER_TYPES[GetItemLinkItemType(itemLink)] == true
end

local staticCache = {}     -- [itemLink] = path
local instanceCache = {}   -- [itemInstanceId] = path; saves building the link on every rebuild
local newPath, stolenPath, nonSetPath, lockedRoot, uncollectedPath, researchPath
-- [group key] = { LOCKED, that group's own node }: one per category rather than one per piece.
local lockedPaths = {}

-- Called whenever something that changes the grouping changes (settings, custom groups, icons).
function IG.ClearClassifyCache()
    IG.ClearMinimalCache()
    -- A category's tone is decided by where it stands among the others under its heading, so
    -- anything that moves one of them is enough to make every tone under it the wrong one.
    IG.ClearColorCache()
    ZO_ClearTable(staticCache)
    ZO_ClearTable(instanceCache)
    ZO_ClearTable(setNodeCache)
    newPath, stolenPath, nonSetPath, lockedRoot, uncollectedPath, researchPath = nil, nil, nil, nil, nil, nil
    ZO_ClearTable(lockedPaths)
end

-- The piece rather than the kind. A decision is made about the one thing under the cursor, and
-- two of the same thing are two things: the game's own unique id is what tells them apart, and
-- it is the same id NEW and RECENT LOOT remember their pieces by.
--
-- It follows the piece into the bank and back. It does not survive a stack being split or piled
-- onto another, which is the one thing a decision about a stack cannot be asked to outlive.
function IG.PieceId(bagId, slotIndex)
    if not (bagId and slotIndex and GetItemUniqueId) then return nil end
    local uniqueId = GetItemUniqueId(bagId, slotIndex)
    return uniqueId and Id64ToString(uniqueId) or nil
end

local function SlotPieceId(slotData)
    if slotData.uniqueId then return Id64ToString(slotData.uniqueId) end
    return IG.PieceId(slotData.bagId, slotData.slotIndex)
end

-- Returns the node path for an inventory slot.
-- isNew: the item hasn't been seen yet (only passed for the backpack).
-- An item (or a whole set) the user sent to a group of their own choosing. The piece answers
-- first: a set sent somewhere is about every piece of it, and a piece sent somewhere is about
-- that piece, so the narrower of the two wins.
local function OverrideFor(itemLink, pieceId)
    local overrides = IG.sv.overrides
    -- Nothing was moved by hand: don't pay for the lookups on every item.
    if pieceId and next(overrides.items) then
        local byPiece = overrides.items[pieceId]
        if byPiece then return byPiece end
    end
    -- "Always send this item to": every piece of one item id, now and later. Narrower than a
    -- set, wider than a piece. The item id covers every level and quality of the same item.
    local types = overrides.types
    if types and next(types) and GetItemLinkItemId then
        local byType = types[GetItemLinkItemId(itemLink)]
        if byType then return byType end
    end
    if next(overrides.sets) then
        local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        if hasSet then return overrides.sets[setId] end
    end
end

-- Whether a guild store would take this piece at all. A bound piece cannot be listed, and
-- neither can stolen goods, so SELL [GUILD STORE] is not a place either of them can be sent.
--
-- Asked of the slot rather than of the kind, and asked the way UNCOLLECTED asks it:
-- IsItemBound is about this one piece, and a piece that binds on pickup is already bound the
-- moment it is yours. Nothing is remembered, because the answer changes the first time you
-- wear the thing.
--
-- These two are the reasons that can be named. The API has no function that puts the store's
-- own question -- may this be listed -- so a piece the store turns away for some third reason
-- is one this cannot know about, and it would still be offered.
function IG.CanListOnGuildStore(bagId, slotIndex)
    if not (bagId and slotIndex) then return false end
    if IsItemBound and IsItemBound(bagId, slotIndex) then return false end
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then return false end
    -- Bind on Pickup but tradeable for a while yet: dungeon and trial drops read this way until
    -- they bind for good. That window is a direct trade with whoever was in the group, never an
    -- open guild store listing -- the game's own UI gates its "freely tradeable" bucket on the
    -- same call (backpacklayouts.lua:119, shipped client source).
    if IsItemBoPAndTradeable and IsItemBoPAndTradeable(bagId, slotIndex) then return false end
    return true
end

-- Whether TO BANK can take this piece (ToBank.lua). Only the backpack is ever emptied into the
-- bank, so a piece anywhere else -- already in the bank, worn -- is not one to send there.
-- Stolen goods are refused by the bank (LarvalTear's deposit leaves them out the same way,
-- equipment_deposit.lua:321), and a piece bound to this one character
-- (BIND_TYPE_ON_PICKUP_BACKPACK, read the way CharacterKnowledge.lua:91-96 reads it) has no
-- business in a bank the whole account shares.
function IG.CanDepositToBank(bagId, slotIndex)
    if bagId ~= BAG_BACKPACK or not slotIndex then return false end
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then return false end
    if GetItemBindType and BIND_TYPE_ON_PICKUP_BACKPACK
        and GetItemBindType(bagId, slotIndex) == BIND_TYPE_ON_PICKUP_BACKPACK then
        return false
    end
    return true
end

-- What the player said about this slot, and the link it was read off, so nothing below has to
-- read it a second time. Costs nothing at all while nothing has been moved by hand.
--
-- One thing said is not taken at its word: a piece in the guild store pile that has since been
-- bound. A whole set can have been sent there and one of its pieces worn since, and the piece
-- itself can have been worn after you filed it -- either way what the pile means about it has
-- stopped being true, and a pile of things to list that cannot be listed is worse than no pile
-- at all. So the piece simply falls back to where it would have stood on its own, here, at the
-- one place every answer about it is read from. What is written down is left alone: for a set
-- it still speaks for the pieces that are still free, and binding is not a thing you undo.
local function OverrideForSlot(slotData)
    local overrides = IG.sv and IG.sv.overrides
    if not overrides or not (next(overrides.items) or next(overrides.sets)
        or (overrides.types and next(overrides.types))) then return nil end
    if not (slotData.bagId and slotData.slotIndex) then return nil end
    local itemLink = GetItemLink(slotData.bagId, slotData.slotIndex)
    if not itemLink or itemLink == "" then return nil end
    local override = OverrideFor(itemLink, SlotPieceId(slotData))
    if override == "GUILDSELL"
        and not IG.CanListOnGuildStore(slotData.bagId, slotData.slotIndex) then
        return nil, itemLink
    end
    -- And the whole pile while SELL [GUILD STORE] is switched off: every piece sent there
    -- stands where it would have stood on its own, and comes back the moment it is on again.
    -- What is written down is left alone.
    if override == "GUILDSELL" and not IG.IsGroupAvailable("GUILDSELL") then
        return nil, itemLink
    end
    -- The same for DECONSTRUCT: a piece no station takes apart (a recipe filed there before the
    -- line asked) falls back to where it would have stood. What is written down is left alone.
    if override == "DECON" and CanItemBeDeconstructed
        and not CanItemBeDeconstructed(slotData.bagId, slotData.slotIndex) then
        return nil, itemLink
    end
    -- And for TO BANK: a marked piece that is not in the backpack (it reached the bank some
    -- other way, or is worn) stands where it would on its own. The mark is left for the bank
    -- to tidy away the next time it is opened (ToBank.lua).
    if override == "TOBANK" and not IG.CanDepositToBank(slotData.bagId, slotData.slotIndex) then
        return nil, itemLink
    end
    -- And for TO HOME CONTAINER: a piece with no container written down for it, or one that
    -- could not be put in a chest, stands where it would on its own (ToHome.lua).
    if override == "TOHOME" and not (IG.IsHomeMarked and IG.IsHomeMarked(slotData.bagId, slotData.slotIndex)) then
        return nil, itemLink
    end
    return override, itemLink
end

-- The two categories a piece reaches by deciding about it rather than by what it is: you are
-- going to sell this, or you are going to break this down. Either way it is a decision, not a
-- description, so it outranks what the item happens to be and the groups that would otherwise
-- repeat it stand down. Sent by the piece, or by the whole set from a set header.
--
-- This is about the sending, not about the category. An ornate piece standing in SELL because
-- of its trait was never sent anywhere and has no override at all, so nothing here is asked
-- about it -- which is right: it is not set aside from where it belongs, it is where it
-- belongs. Sending it on to somewhere else writes an override like any other, and that
-- override is read before the trait is ever looked at.
--
-- Not asked at all while the category it names is off the list: a category that is not there
-- would otherwise swallow every piece sent to it, and the piece would be in no group anywhere.
-- CUSTOM is the third: a category no rule fills, so the only way anything reaches it is by
-- hand, and a piece there is a decision of yours exactly as the other two are.
-- SELL [GUILD STORE] is the fourth: no rule fills it either, and like CUSTOM it can be switched
-- off, which puts its pieces back where they stand on their own until it is on again.
-- TO BANK is the fifth: a piece marked for the bank, which is a decision too. Its switch hides
-- the button only, and while it is hidden its pieces stand where they would on their own.
local SET_ASIDE = { SELL = true, GUILDSELL = true, DECON = true, CUSTOM = true, TOBANK = true, TOHOME = true }

local function SetAsideFrom(key)
    if not (key and SET_ASIDE[key]) then return nil end
    if not IG.IsGroupAvailable(key) then return nil end
    return key
end

function IG.SetAsideKey(slotData)
    return SetAsideFrom((OverrideForSlot(slotData)))
end

function IG.IsSetAside(slotData)
    return IG.SetAsideKey(slotData) ~= nil
end

-- Waiting, said about a piece in SELL [GUILD STORE] and nowhere else.
--
-- That category is the one pile where a piece is worth keeping for a while rather than getting
-- rid of today, so it is the one that can be told "not yet". Every other category is either
-- what a piece is or what you decided to do with it now, and neither of those has anything to
-- wait for.
--
-- What it is waiting for is one of two things, and never both: a better piece to replace it, or
-- the price of this one to come back up off the floor. They are two answers to the same
-- question -- why this is not listed yet -- so a piece holds one of them and choosing the other
-- is changing your mind rather than adding a second reason.
--
-- Kept per piece, under the game's own unique id, exactly as a moved piece is: the row it is
-- drawn on comes out of a pool and is somebody else's on the next rebuild, and the mark has to
-- outlive that. Nothing else about the piece is remembered -- the category it is in is already
-- written down, and reading it back from there is one fewer thing to keep true.
IG.AWAITING_GROUP = "GUILDSELL"

-- The whole note is one colour, in capitals, with an exclamation mark: "AWAITING UPGRADE!".
-- Each reason has a colour of its own (cool for the price you are watching); the upgrade's is
-- worked out per piece instead -- the colour of the quality one step above the piece's own,
-- the quality it is waiting to become (IG.AwaitingColor).
IG.AWAITING_REASONS = {
    { key = "upgrade",  word = "Upgrade",    color = "FFC24A" },
    { key = "pricedrop", word = "Price Drop", label = "Market Study", bang = false, color = "5CC8FF" },
}

IG.AWAITING_BY_KEY = {}
for _, reason in ipairs(IG.AWAITING_REASONS) do IG.AWAITING_BY_KEY[reason.key] = reason end

-- What the menu writes and what the row wears, said once so the two can never drift apart.
function IG.AwaitingLabel(reasonKey)
    local reason = IG.AWAITING_BY_KEY[reasonKey]
    if not reason then return "" end
    -- A reason may carry a label of its own; the key (what is saved) never changes with it.
    return reason.label or string.format("Awaiting %s", reason.word)
end

-- The colour a piece's note (and the pulse on its row) wears. Upgrade: the game's own colour
-- for the next quality up (GetItemQualityColor, a ZO_ColorDef) -- white to green, green to
-- blue, blue to purple, purple to gold; gold and above keep their own. Anything else: the
-- reason's own colour.
function IG.AwaitingColor(reasonKey, slotData)
    local reason = IG.AWAITING_BY_KEY[reasonKey]
    if not reason then return "FFFFFF" end
    if reasonKey ~= "upgrade" or not GetItemQualityColor then return reason.color end
    local quality = slotData and (slotData.displayQuality or slotData.quality) or 0
    local top = ITEM_DISPLAY_QUALITY_LEGENDARY or 5
    local wanted = quality >= top and quality or quality + 1
    local color = GetItemQualityColor(wanted)
    if not (color and color.UnpackRGB) then return reason.color end
    return IG.RGBToHex(color:UnpackRGB())
end

function IG.AwaitingMarkup(reasonKey, slotData)
    local reason = IG.AWAITING_BY_KEY[reasonKey]
    if not reason then return "" end
    -- Always bright white, whatever the pulse colour is: the note must stay legible on the wash.
    return string.format("|cFFFFFF%s%s|r", zo_strupper(IG.AwaitingLabel(reasonKey)),
        reason.bang == false and "" or "!")
end

-- One table for both reasons rather than one table each: a piece has a single answer, and two
-- tables would be two places for it to be given at once.
function IG.AwaitingReason(pieceId)
    if not pieceId then return nil end
    local marks = IG.sv and IG.sv.awaiting
    local reason = marks and marks[pieceId]
    return IG.AWAITING_BY_KEY[reason] and reason or nil
end

-- The row's own question. Asked on every item row the list draws, so it costs nothing at all
-- while nobody has marked anything, and it answers nothing for a piece filed anywhere else
-- however the mark got there: the mark means "not yet" about listing it on the guild store, and
-- a piece that is not in that pile is not waiting for anything.
function IG.AwaitingFor(slotData)
    local marks = IG.sv and IG.sv.awaiting
    if not (marks and next(marks)) then return nil end
    if not (slotData and slotData.bagId and slotData.slotIndex) then return nil end
    local reason = IG.AwaitingReason(SlotPieceId(slotData))
    if not reason then return nil end
    if IG.SetAsideKey(slotData) ~= IG.AWAITING_GROUP then return nil end
    return reason
end

-- Writing one reason is letting go of the other, which is the whole of what "never both" needs.
function IG.SetAwaitingReason(pieceId, reasonKey)
    if not pieceId then return end
    IG.NoteSaved(IG.sv.awaiting, pieceId)
    IG.sv.awaiting[pieceId] = IG.AWAITING_BY_KEY[reasonKey] and reasonKey or nil
end

-- The group an item lands in from what it is alone, with NEW, STOLEN, the modules and the
-- player's own overrides left out of it. The Minimal layout builds its buckets on top of this,
-- so it inherits every rule the full layout has without repeating any of them.
function IG.ClassifyByType(slotData, itemLink)
    itemLink = itemLink or GetItemLink(slotData.bagId, slotData.slotIndex)
    local path = staticCache[itemLink]
    if not path then
        local cacheable
        path, cacheable = ClassifyStatic(itemLink, slotData)
        if cacheable then staticCache[itemLink] = path end
    end
    return path
end

-- What kind of item this is. Two of the same kind land in the same place unless one of them was
-- moved by hand, so the answer is kept per item id: reopening a group then costs no item link
-- and no set lookups at all.
local function ClassifyKind(slotData, override, itemLink)
    -- Asked before either cache is read or written. What was moved is one piece, and two of the
    -- same kind can now stand in different groups, so neither may answer for the other.
    --
    -- And only while the category it names is standing. A module switched off is not a place:
    -- without this, every piece sent to one would be filed under the category the unknown goes
    -- to rather than back where it belongs.
    if override and IG.GROUP_BY_KEY[override] and IG.IsGroupAvailable(override) then
        itemLink = itemLink or GetItemLink(slotData.bagId, slotData.slotIndex)
        local path = Path(override)
        local setNode = IG.GetSetNode(itemLink)
        if setNode then path[#path + 1] = setNode end
        return path
    end

    local instanceId = slotData.itemInstanceId
    local remembered = instanceId and instanceCache[instanceId]
    if remembered then return remembered end

    itemLink = itemLink or GetItemLink(slotData.bagId, slotData.slotIndex)
    local path = staticCache[itemLink]
    if not path then
        local cacheable
        path, cacheable = ClassifyStatic(itemLink, slotData)
        if cacheable then
            staticCache[itemLink] = path
            if instanceId then instanceCache[instanceId] = path end
        end
    elseif instanceId then
        instanceCache[instanceId] = path
    end
    return path
end

-- Whether the player has put a lock on this one piece. Asked here, and asked again by the list
-- build when a list is keeping locked pieces out of itself altogether -- the same question has
-- to have the same answer in both places, or a piece would be counted as hidden and drawn.
-- A row that is not a real slot (a saved one, a module's copy) has no lock of its own.
function IG.IsSlotLocked(slotData)
    return slotData.bagId ~= nil and slotData.slotIndex ~= nil
        and IsItemPlayerLocked(slotData.bagId, slotData.slotIndex) == true
end

-- The body of the two questions below: where this piece stands, given what has been said
-- about it -- or, with that left out, where it would have stood if nothing had been.
local function ClassifyWith(slotData, isNew, override, itemLink, lockedOn)
    local sell = SetAsideFrom(override)
    if isNew and not sell then
        newPath = newPath or Path("NEW")
        return newPath
    end
    -- A stolen box is still a box. You open it before any of what is in it can be sold, so it
    -- waits with the other things to be opened rather than with the things to be fenced -- and
    -- it loses nothing by that: the game keeps its own stolen mark on the row, and what falls
    -- out of it is stolen too. Everything else stolen goes where stolen things go.
    if slotData.stolen and not sell then
        local link = itemLink or (slotData.bagId and slotData.slotIndex
            and GetItemLink(slotData.bagId, slotData.slotIndex))
        if not (link and IG.IsContainerItem(link)) then
            stolenPath = stolenPath or Path("STOLEN")
            return stolenPath
        end
    end

    -- A piece a crafting writ is waiting for lives in DAILY WRIT (DailyWrit.lua): above every
    -- AUTOMATE rule, above where its kind would put it (GARBAGE, NONSET) and above a move made
    -- by hand -- a piece sent to SELL last month is still the piece the writ wants today (reported
    -- 2026-11-04). Asked outside both caches, because the answer follows the quest journal
    -- rather than the item.
    local path
    local handMoved = override and IG.GROUP_BY_KEY[override] and IG.IsGroupAvailable(override)
    if IG.IsDailyWritItem and IG.IsDailyWritItem(slotData) then
        path = Path("DAILYWRIT")
        local link = itemLink or GetItemLink(slotData.bagId, slotData.slotIndex)
        local setNode = link and IG.GetSetNode(link)
        if setNode then path[#path + 1] = setNode end
    elseif not handMoved and IG.IsUnlearnedItem and IG.IsUnlearnedItem(slotData) then
        -- A motif, recipe, furnishing plan or outfit style page still to learn or unlock lives in
        -- UNCOLLECTED (BindOnEquip.lua) instead of MOTIFS or CRAFT: below DAILY WRIT and a move
        -- made by hand, above where its kind would put it. Asked outside both caches, because
        -- learning it changes the answer and nothing about the item; once it is known it goes
        -- back to its kind on the next build.
        uncollectedPath = uncollectedPath or Path("BINDONEQUIP")
        path = uncollectedPath
    elseif not handMoved and IG.IsResearchableItem and IG.IsResearchableItem(slotData) then
        -- Gear whose trait this character can still research lives in RESEARCHABLE
        -- (Researchable.lua): below DAILY WRIT, UNCOLLECTED and a move made by hand, above every
        -- AUTOMATE rule, so no rule files it into SELL or DECONSTRUCT. Outside both caches: the
        -- answer follows research, not the item.
        researchPath = researchPath or Path("RESEARCH")
        path = researchPath
    else
        path = ClassifyKind(slotData, override, itemLink)
    end

    -- Asked of the one piece rather than of its kind, and outside the cache above, because a
    -- lock goes on a single piece and can come off it again.
    local locked = IG.IsSlotLocked(slotData)

    -- A rule (AUTOMATE) never speaks for a locked piece or one you are wearing: it stands where
    -- it would have stood with the rule off.
    if path.ruleHome and (locked or slotData.bagId == BAG_WORN) then
        path = path.ruleHome
    end

    -- Locking a piece is the opposite of saying you are done with it, so a locked piece with no
    -- set is not garbage: it is a piece without a set, which is a different thing and has a
    -- category of its own.
    if path.nonSetGear and locked then
        nonSetPath = nonSetPath or Path("NONSET")
        path = nonSetPath
    end

    -- (LOCKED, below, is the last word on where a piece goes.)
    -- Everything you locked, gathered at the foot of the list -- but each piece still under the
    -- category it would have stood in, so the run is read the way the rest of the list is. Only
    -- the top of that category comes along: the list carries three headings at most, and LOCKED
    -- is already one of them.
    -- Whether they are gathered is the list's own answer, handed in: the same piece is at the
    -- foot of one window and in its own category in the next.
    -- TO BANK is exempt: a piece marked for the bank is locked on purpose, to keep it from being
    -- sold or broken down before it goes in, and gathering it under LOCKED instead would hide it
    -- from the one place (its own module) that is actually going to empty it in.
    if locked and lockedOn and path[1] and path[1].id ~= "TOBANK" then
        local top = path[1]
        -- And its set comes with it. A set is how a piece of gear is known -- which is the
        -- whole reason the list draws a divider for one -- so a run of locked gear with the
        -- dividers taken out is a run of names in no order anyone can see. What does not come
        -- along is the heading between the two: the list carries three levels of them and
        -- LOCKED has taken one, so the choice is a set or a heading, and the set says more.
        local leaf = path[#path]
        local setNode = leaf ~= top and leaf.isSet and leaf or nil
        local key = setNode and (top.id .. "/" .. setNode.id) or top.id
        local under = lockedPaths[key]
        if not under then
            lockedRoot = lockedRoot or GroupNode("LOCKED")
            under = setNode and { lockedRoot, top, setNode } or { lockedRoot, top }
            lockedPaths[key] = under
        end
        return under
    end
    return path
end

-- Returns the node path for an inventory slot.
-- isNew: the item hasn't been seen yet (only passed for the backpack).
function IG.ClassifySlot(slotData, isNew, lockedOn)
    -- A gear piece of an equipment setup belongs to that setup, above everything (Setups.lua).
    local setupPath = IG.SetupPathFor and IG.SetupPathFor(slotData)
    if setupPath then return setupPath end
    local override, itemLink = OverrideForSlot(slotData)
    return ClassifyWith(slotData, isNew, override, itemLink, lockedOn)
end

-- Which category a rule (AUTOMATE) put this piece in, or nil. Nil for anything moved by hand,
-- stolen, locked or worn: those are never a rule's.
function IG.AutomatedKey(slotData)
    if not (slotData and slotData.bagId and slotData.slotIndex) then return nil end
    local path = IG.ClassifySlot(slotData, false, false)
    return path and path.automated or nil
end

-- Whether RECENT LOOT leaves this piece out (the stolen switch, and garbage, SELL and
-- DECONSTRUCT). NEW is not asked.
function IG.HiddenFromRecentLoot(slotData)
    if not (IG.sv and slotData) then return false end
    if IG.sv.automateHideStolen == true and slotData.stolen then return true end
    -- Garbage, SELL and DECONSTRUCT are never recent loot. Asked of where the piece stands now
    -- (rules and moves by hand included), so one moved out is listed again and one moved in
    -- drops out.
    if slotData.bagId and slotData.slotIndex then
        local path = IG.ClassifySlot(slotData, false, false)
        if path and path[1] and (path[1].id == "GARBAGE" or path[1].id == "SELL"
            or path[1].id == "DECON") then return true end
    end
    return false
end

-- And where the same piece would stand if you had said nothing about it, with the category it
-- was sent to instead. Only a piece that was sent aside gets an answer: that is the one case
-- where something is somewhere it would not have gone on its own, and it is drawn in both
-- places then. Both are answered at once because finding out costs an item link, and a full
-- bag is a lot of item links to read twice.
function IG.ClassifyAsideHome(slotData, isNew, lockedOn)
    if IG.SetupPathFor and IG.SetupPathFor(slotData) then return nil end
    local override, itemLink = OverrideForSlot(slotData)
    local key = SetAsideFrom(override)
    if not key then return nil end
    local home = ClassifyWith(slotData, isNew, nil, itemLink, lockedOn)
    -- Unless it was already going there. An ornate piece reaches SELL on its own now, and
    -- sending it to SELL by hand says nothing it was not saying already: a stood-down copy
    -- under the category it belongs to would be a stood-down copy in the very category the row
    -- above it is standing in, and the piece would be drawn twice with an arrow pointing at
    -- itself. Nothing was moved as far as the list is concerned, so nothing is shown twice.
    if home[1] and home[1].id == key then return nil end
    return home, key
end

---------------------------------------------------------------------------
-- Breaking a long flat category into what its pieces are
---------------------------------------------------------------------------

-- Some categories have headings inside them and some do not, and the ones that do not are the
-- ones that grow without any shape: SELL, DECONSTRUCT, GARBAGE, JUNK, NEW, STOLEN -- a piece
-- reaches those by a decision or by where it came from, not by what it is, so nothing about
-- what it is has been said. Six rows like that read fine. Sixty do not. SELL and DECONSTRUCT
-- are the two that now fill themselves as well, which only makes this more true of them: what
-- a trait sends there is every setless weapon, every piece of armour and every ring you pick up
-- carrying it, and the category is long by evening.
--
-- So the heading each piece would have stood under had it been filed by its kind is asked for
-- here -- the very answer the classifier already worked out on the way in -- and the category
-- is broken into those. The node is rebuilt under the category being split rather than taken
-- from the type's own path, so every heading wears that category's colour and reads as part of
-- it: a Weapons heading under JUNK is junk, not a visit from somewhere else.
--
-- Which category is flat is not a list kept somewhere. It is asked of the rows: a category
-- none of whose pieces stand under anything is flat, and one that has drawn a single heading
-- of its own is left exactly as it is. That way a category that gains headings later -- or one
-- whose headings are switched off on the Groups page -- answers for itself, and nothing here
-- has to be kept in step with the classifier.
--
-- Three are never asked, for reasons of their own rather than because they are not flat:
-- RECENT LOOT counts the runs it holds rather than the pieces, and its rows are already
-- gathered by where they came from; HOME CONTAINERS holds rows read out of a saved chest,
-- which have no slot in any bag to be classified from. EQUIPPED has fixed headings of its own
-- (Equipped.lua).
local SPLIT_NEVER = { LASTRUN = true, HOME = true, EQUIPPED = true }

-- What a category is set to, in the order the answers beat one another: the category's own
-- answer, given from its right click menu, beats the setting every time -- including while the
-- setting is off altogether. Without one of its own it follows the setting, which counts the
-- rows that would open under the category and asks whether that is more than the player said.
--
-- Rows, not items and not stacks-flattened-into-items, because the number in the bracket after
-- a category's name is rows, and a threshold that counted anything else would split a category
-- saying (6) while the setting read 10.
function IG.SplitChoice(key)
    local choices = IG.sv and IG.sv.splitChoice
    return choices and choices[key] or nil
end

function IG.SetSplitChoice(key, choice)
    if not (IG.sv and key) then return end
    IG.sv.splitChoice = IG.sv.splitChoice or {}
    IG.NoteSaved(IG.sv.splitChoice, key)
    IG.sv.splitChoice[key] = choice
end

local function SplitWanted(key, rows)
    local choice = IG.SplitChoice(key)
    if choice == "split" then return true end
    if choice == "merge" then return false end
    if not (IG.sv and IG.sv.autoSplit == true) then return false end
    return rows > (IG.sv.autoSplitOver or 5)
end

-- One node per name rather than one per row, so the rows of a kind gather under the one heading.
local function TypeSubNode(root, subs, slotData)
    if not (slotData.bagId and slotData.slotIndex) then return nil end
    local itemLink = GetItemLink(slotData.bagId, slotData.slotIndex)
    if not itemLink or itemLink == "" then return nil end
    local path = IG.ClassifyByType(slotData, itemLink)
    if not path then return nil end
    -- The deeper name is the better one -- "Weapons" rather than "GARBAGE" -- and where the
    -- category the piece would have gone to is flat itself, the heading it dropped on the way
    -- in is that deeper name. Failing both, the piece is named by its own category, which is
    -- all anybody knows about it.
    local label = (path[2] and path[2].label) or path.typeLabel or (path[1] and path[1].label)
    if not label then return nil end
    subs[label] = subs[label] or IG.MakeSubNode(root, label)
    return subs[label]
end

IG.TypeSubNode = TypeSubNode

-- Rewrites the paths of every flat category that is to be split, in the list of entries one
-- window is being built from. Returns which categories were flat -- whether or not they are
-- split today -- because that is the same question the right click menu asks before it offers
-- to split one, and the answer is only known while the list is in hand.
function IG.SplitFlatCategories(items)
    local flat, rows = {}, {}
    for _, entry in ipairs(items) do
        -- A category drawn empty carries a path with nothing in it and says nothing about shape.
        if not entry.igEmpty then
            local path = entry.igPath
            local key = path and path[1] and path[1].id
            if key then
                rows[key] = (rows[key] or 0) + 1
                -- EQUIPPED is offered the menu all the same: its "type" split is its own fixed
                -- headings, and "merge" drops them (Equipped.lua); nothing here rewrites it.
                if key == "EQUIPPED" then
                    flat[key] = true
                elseif #path > 1 or SPLIT_NEVER[key] then
                    flat[key] = false
                elseif flat[key] == nil then
                    flat[key] = true
                end
            end
        end
    end

    local working = {}
    for key, isFlat in pairs(flat) do
        if isFlat and not SPLIT_NEVER[key] and SplitWanted(key, rows[key] or 0) then
            working[key] = { subs = {}, moves = {} }
        end
    end
    if not next(working) then return flat end

    for _, entry in ipairs(items) do
        local work = not entry.igEmpty and working[entry.igPath[1].id]
        if work then
            local sub = TypeSubNode(entry.igPath[1], work.subs, entry.data)
            -- A row nothing can be read off keeps its place directly under the category, where
            -- the sort already puts what stands under a node before the nodes under it.
            if sub then work.moves[#work.moves + 1] = { entry = entry, sub = sub } end
        end
    end

    for _, work in pairs(working) do
        local names = 0
        for _ in pairs(work.subs) do names = names + 1 end
        -- A split into one heap is not a split. A category that holds one kind of thing --
        -- motifs, tokens, quest items -- would gain a heading repeating its own name and
        -- nothing else, and cost a click to get past it.
        if names > 1 then
            for _, move in ipairs(work.moves) do
                local path = move.entry.igPath
                -- A new table every time: the path a piece was classified with is shared by
                -- everything of its kind and cached by the classifier, and writing into one
                -- would move far more than the row in hand.
                move.entry.igPath = { path[1], move.sub, itemLocation = path.itemLocation }
            end
        end
    end
    return flat
end
