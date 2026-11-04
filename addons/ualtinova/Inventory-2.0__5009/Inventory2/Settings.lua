InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Cached once rather than read off _G on every call (ESOUI admin review, 2026-11-02).
-- LibAddonMenu-2.0 is a ## DependsOn now: the manifest guarantees its file loads ahead of ours,
-- so this is never nil by the time anything here reads it.
local libAddonMenu2 = LibAddonMenu2

IG.DISPLAY_NAME = "Inventory 2.0"
IG.SHORT_NAME = "INV2.0" -- what the right click menu signs its lines with
IG.VERSION = "1.0.6"
IG.DATA_VERSION = 22-- shape of the saved settings; see IG.MigrateSavedVars

IG.DEFAULT_SETTINGS = {
    dataVersion = IG.DATA_VERSION, -- what this save was written by, so older ones can be updated
    -- The Global Switch (settings: General). Off and the addon installs nothing at all: the game's
    -- own inventory is back, untouched. Everything below is kept, so switching it on again carries
    -- on exactly where you left off.
    addonEnabled = true,
    -- nil follows the client's own language (IG.GameLanguage); a code here (Settings > About >
    -- Language) overrides it. See Strings.lua.
    languageOverride = nil,
    -- Whether the Getting Started window has shown itself. Set the moment it opens, by whatever
    -- door -- its own first login, the General button, or /inv2tutorial -- so a player who found
    -- it one way is never also greeted by it the other way (Tutorial.lua).
    tutorialSeen = false,
    expanded = { backpack = {}, bank = {}, guildbank = {}, housebank = {}, craft = {}, trading = {},
        minimal = {} },
    groups = {},           -- [groupKey] = { name, color, order, section } chosen by the user
    -- Colours painted on a heading from its own right click menu. A category keeps its one in
    -- the table above; these two are for the headings that had nowhere to keep one.
    subColors = {},        -- [node key, e.g. "PVE/Trial Sets"] = hex
    setColors = {},        -- [setId] = hex, so the colour follows the set between categories
    -- Dungeon, DLC dungeon, arena and trial sets back under one PVE SETS, the way they used to
    -- be. Overland is never among them; it is a group of its own either way.
    -- Categories gathered under headings, which is what the three switches below cannot be
    -- used against: the headings are made out of the very categories they would put away.
    sections = true,
    setRules = false,      -- a set is a line with its name on it, not a button to open
    setRuleDetails = false,-- and that line carries what the button carried, all of it or none
    mergePveSets = false,
    mergeConsumables = false, -- poisons, potions, food & drink and the rest back under one
    mergeWorld = false,       -- resources, scribing, appearance and trophies back under one
    -- Cyrodiil / Imperial City / Battleground as headings inside PVP SETS. Off: the sets stand
    -- straight under the category, the way every other category's do.
    pvpByInstance = false,
    -- items: [piece id] = groupKey, one piece at a time; sets: [setId] = groupKey, the whole set.
    overrides = { items = {}, sets = {} },
    -- Settings > Modules > Bank Modules: [group key] = false turns one off while the bank's own
    -- list is the one open. Missing or true both mean on -- every one of these starts on.
    bankModules = {},
    -- TO HOME CONTAINER (ToHome.lua): [piece id] = the container it was marked for, and every
    -- container seen in a house you own, [houseId .. ":" .. bagId] = { houseId, bagId,
    -- collectibleId, name, houseName }.
    homeTargets = {},
    homeContainers = {},
    -- [piece id] = "upgrade" | "pricedrop", for the pieces in SELL [GUILD STORE] you are holding
    -- back, and what each one is waiting for. Nothing older has to be reshaped for it: a save
    -- written before today simply has no marks, which is what an empty table says.
    awaiting = {},
    -- Off by default: the right click lines that write to the table above (Modules > On/Off).
    awaitingMarksEnabled = false,
    -- What the money tracker could not name (Gold.lua). reasons is keyed by the game's own
    -- reason and the currency it moved, and dropped counts the ones turned away once the list
    -- was full. Nothing on screen reads it; it is here so that the question "what is Other
    -- made of" can be answered from the save instead of guessed.
    goldUnknown = { reasons = {}, dropped = 0 },
    accordion = true,      -- opening a group closes the others next to it
    showCounts = true,     -- the (12) after a group's name
    showTotalItems = true, -- a second bracket: everything in a category's whole tree
    showEmptyGroups = false, -- keep groups on screen even with nothing in them
    -- A piece sent to SELL or DECONSTRUCT also keeps its place where it belongs, stood down.
    -- What a list that has never been asked starts out doing. Each window has a button of its
    -- own for it (Toolbar.lua), and once that button has been pressed on a list, the list's own
    -- answer is the one that counts and this setting no longer reaches it.
    asideAtHome = true,
    -- The two trait rules (AUTOMATE: Intricate Gear, Ornate Gear). Off like every other rule.
    autoDeconstructIntricate = false,
    autoSellOrnate = false,
    -- AUTOMATE (Classify.lua, IG.AUTOMATE_RULES): every other rule and switch starts off.
    autoSellTrash = false,
    autoSellGlyphs = false,
    autoSellTraitless = false,
    autoDeconGlyphs = false,
    autoDeconJewelry = false,
    autoDeconTraitless = false,
    automateTab = "SELL",  -- the tab the AUTOMATE drawer's page opens on
    automateHideStolen = false,
    -- The three actions (Classify.lua, IG.AUTOMATE_ACTIONS): "off", "ask" or "auto".
    actionSell = "off",
    actionDecon = "off",
    actionFence = "off",
    sortBy = "name",       -- name / value / quality, inside every group

    icons = {},            -- [iconKey] = texture path chosen by the user
    theme = "full",        -- which ready-made look the switches below are set to
    -- Visuals. A theme is nothing but a set of values for these.
    -- Colors
    groupColors = true,    -- group, sub-group and set colors; off = ESO's own cream everywhere
    -- On: every heading is a colour family and its categories are tones of it. Off (the way it
    -- comes): each category wears the colour it was given, which owes nothing to what it
    -- stands among.
    coloredGroups = false,
    roleColors = true,     -- a set wears the colors of the roles it serves
    -- Surfaces
    headerSurfaces = true, -- the tinted glass behind a header
    groupSurface = true,   -- the faint ground inside an open group
    specialSurfaces = true,-- the brighter grounds NEW, REWARDS and the modules get
    -- [groupKey] = { level = "low"/"medium"/"strong"/"none" }: how much each one glows.
    -- Only what the player changed is kept; the rest follows IG.DEFAULT_GLOW.
    glows = {},
    -- No switch of its own: the Quiet Black theme is what turns it on, and picking any other
    -- theme is what turns it off again.
    blackSurfaces = false, -- surfaces are ink instead of tinted glass
    lowBrightness = false, -- every color taken down a step (the low brightness theme)
    -- off / protanopia / deuteranopia / tritanopia: the palette moved off the axis that eye
    -- cannot split. Not a theme's to set, so a theme never touches it.
    colorblind = "off",
    frames = true,         -- the thin outlines around groups
    accentStrips = true,   -- the strips on the left of a header, and the foot of an open group
    -- Layout. The first two have no switch of their own: the Minimal theme is what turns them
    -- on, and picking any other theme is what turns them off again.
    flatGrouping = false,  -- one level only: every set its own category, everything else in buckets
    startExpanded = false, -- every group comes open
    rowDensity = "normal", -- compact / normal / roomy: how tall our own rows are
    showLocation = true,   -- where each set drops, on the right of its header
    showSetTooltip = true, -- set bonuses and owned pieces when hovering a set header
    showPieces = true,     -- row of gear slot icons under each set header
    showCollect = true,    -- the set collection counter on a set header, and its pulsing "+X"
    showRoles = true,      -- damage / tank / support markers left of each set header
    -- [groupKey] = { style = "shift"/"pulse"/"trace"/"none", speed = "slow"/"normal"/"fast" }.
    -- Only what the player changed is kept; the rest follows IG.DEFAULT_ANIMATED.
    animations = {},
    -- A category with no headings of its own -- SELL, GARBAGE, JUNK, NEW -- broken into what
    -- its pieces are once it has grown past a length worth reading straight through. Off, so
    -- that a bag that has always been drawn one way goes on being drawn that way; the number is
    -- how many rows a category may open before it is asked to sort itself out.
    autoSplit = false,
    autoSplitOver = 5,
    -- [groupKey] = "split" / "merge": what one category was told from its own right click menu,
    -- which beats the two above whichever way they are set.
    splitChoice = {},
    -- [kind key] = true: a kind of boost lifted out of BOOSTS and left standing as a category of
    -- its own (Settings: BOOSTS, and Colors.lua: IG.BOOST_KINDS). Empty, so BOOSTS comes as one
    -- category holding all five kinds. A kind that is not in here is a heading inside it.
    boostSplit = {},
    -- [category key] = true: one of DISPOSAL's categories moved back out to stand as a
    -- top-level category of its own (Colors.lua: IG.DISPOSAL_MEMBERS). SELL [GUILD STORE] is
    -- out by default -- a piece you are holding for a guild store is a decision still open,
    -- not something waiting to be sold or broken down.
    disposalOut = { GUILDSELL = true },
    -- The flat trading layout (Trading.lua): one switch over all five, and one more per NPC kind
    -- (Settings.lua: NPC_CATEGORY_TYPES) for turning it off at just one of them. A kind missing
    -- from npcCategoryTypes reads as on, the way a kind nobody has touched should.
    npcCategoryEnabled = true,
    npcCategoryTypes = {},
    -- Our own grouping on a crafting station's deconstruction and improvement panels (Craft.lua):
    -- one switch over all of them, and one more per crafting skill (Settings.lua:
    -- CRAFT_STATION_TYPES) for leaving just one skill's bench to the game.
    craftStationCategoryEnabled = true,
    craftStationCategoryTypes = {},
    previewEnabled = true, -- the sample group beside the settings page (Preview.lua)
    -- The sample is about what the lists look like, not about what is missing from them, so
    -- neither of these is in it until it is asked for (the two switches on the sample's spine).
    -- Off: the sample shows everything, full colour, whatever your real settings say (Preview.lua).
    previewRealOnly = false,
    animationsEnabled = true,   -- the animations play at all (a theme never touches this)
    animationsAdvanced = false, -- set each group's animation separately
    -- NEW group: what has arrived since you last looked. On, because it is what the bag has
    -- always opened with; off, the pieces are only ever in the categories they belong to.
    newEnabled = true,
    -- Keep Out of NEW: kinds of piece never shown under NEW (asked while drawing).
    newOutGarbage = true, newOutJunk = true, newOutSell = true, newOutDecon = true,
    newOutTrash = true, newOutTreasure = true, newOutStolen = true, newOutMaterials = true,
    newOutStock = true, newOutDailyWrit = true,
    equippedEnabled = true,    -- EQUIPPED group: what you are wearing, under MODULES in the bag
    bindOnEquipEnabled = true, -- UNCOLLECTED group (key BINDONEQUIP): not bound yet, or not learned yet
    justCraftedEnabled = true, -- JUST CRAFTED group: what you made at this bench, atop its lists
    researchableEnabled = true, -- RESEARCHABLE (inside DISPOSAL): gear with a trait still to research
    researchAltsEnabled = false, -- RESEARCHABLE (ALTS): off by default, needs LibCharacterKnowledge
    researchAltsShowLocked = false, -- Also list locked pieces, dimmed
    researchAltsShowArmory = false, -- Also list Armory build pieces, dimmed
    researchAltsShowSetup = false,  -- Also list Setup pieces, dimmed
    dailyWritEnabled = true,   -- DAILY WRIT group: what a crafting writ in the journal wants
    setupsEnabled = true,      -- SETUPS group: your saved equipment setups (Setups.lua)
    bindOnEquipShowGuild = false, -- UNCOLLECTED also lists what is in SELL [GUILD STORE]
    -- UNCOLLECTED also lists what this character has not learned yet, one switch per kind.
    bindOnEquipMotifs = true,  -- crafting motifs (books and chapters)
    bindOnEquipRecipes = true, -- provisioning recipes
    bindOnEquipPlans = true,   -- furnishing plans (blueprints, patterns, diagrams, formulae, ...)
    bindOnEquipStylePages = true, -- outfit style pages whose style the account has not unlocked
    junkEnabled = true,        -- JUNK group: what you marked as junk, which the game hides
    fullSetGlow = true,        -- Equipped Sets: a set worn in full is tied together with green light
    showArmorWeight = false,   -- Equipped Sets: marks coloured by armour weight, with the key (off by default)
    junkOnModules = true,      -- JUNK stands with the modules instead of at the foot of the list
    -- The one setting in this corner that changes your bag rather than the way it is drawn:
    -- stolen goods below a quality of your choosing are marked as junk as they arrive.
    junkStolenEnabled = false,
    junkStolenBelow = ITEM_QUALITY_MAGIC, -- green: grey and white stolen pieces are junked
    -- The same, by what a piece is rather than where it came from: each kind GARBAGE would have
    -- held is junked as it lands, if you asked for that kind. All off -- nothing marks your bag
    -- unless you say so.
    junkGarbageTreasure = false,
    junkGarbageWeapons = false,
    junkGarbageArmor = false,
    junkGarbageJewelry = false,
    -- Everything locked, under a heading of its own at the foot of the list. Switched from the
    -- Group Locked button on the sort header rather than from this page.
    -- What a list does with the pieces you locked, kept per list: the bank can hold them mixed
    -- in while the bag holds them apart, and neither answers for the other.
    -- [listKey] = "hidden" or "grouped"; a list that has not been asked is missing from here
    -- and leaves them where they belong (IG.LOCKED_DEFAULT_MODE).
    lockedLists = {},
    -- And what a list does with the pieces you sent to SELL, DECONSTRUCT or a category of your
    -- own: [listKey] = true to keep the stood-down copy standing where the piece belongs, false
    -- to draw it only in the category you sent it to. A list nobody has pressed the button on
    -- is missing from here and starts out doing whatever asideAtHome says.
    movedLists = {},
    -- And how one list draws the sets inside one category: [listKey] = { [groupKey] = "dividers"
    -- or "buttons" }. Split apart in the bank and gathered into buttons in the bag is the
    -- ordinary case, and one switch on the settings page cannot say that. A list and a category
    -- that have not been asked are missing from here and follow Don't Group Sets.
    setViewLists = {},
    armoryEnabled = true,  -- ARMORY group with your Armory loadouts
    customEnabled = true,  -- CUSTOM: a category of your own, filled one piece at a time
    guildSellEnabled = true, -- SELL [GUILD STORE]: off puts its pieces back, what was sent is kept
    -- TO BANK: whether its button is on show. Marking still works either way.
    toBankShown = true,
    -- Whether a marked piece deposits itself when the bank opens, or waits for your own hand.
    toBankAutoDeposit = true,
    lastRunEnabled = true,     -- RECENT LOOT group: what the places you have just been dropped
    lastRunAccumulate = true,  -- keep the runs before this one, each one listed on its own
    -- Off: what a run hands you is under NEW as well as under RECENT LOOT. NEW is the first
    -- thing looked at after a run, and a piece missing from it because another category already
    -- had it reads as a piece that never dropped. On, RECENT LOOT keeps it to itself.
    lastRunOverNew = false,
    lastRunRules = true,       -- each place is a line with its name on it, not a category
    lastRunPileStolen = true,  -- a run's stolen haul gathers under one Stolen line
    -- What counts as a run:
    lastRunInstances = true,      -- dungeons, trials, group and solo arenas
    lastRunEndless = true,        -- Endless Archive
    lastRunCyrodiil = true,       -- Cyrodiil
    lastRunImperialCity = true,   -- Imperial City
    lastRunBattlegrounds = true,  -- battlegrounds
    lastRunOverland = true,       -- out in a zone: one run per zone
    lastRunRewardMail = true,     -- rewards that arrive by system mail afterwards
    homeEnabled = true,        -- HOME CONTAINERS group: saved contents of your house chests
    -- The drawers that open beside the bag (Drawer.lua). Which one was open when the bag was
    -- last shut, so it is open again when it is next opened; nil is none of them.
    drawerOpen = nil,
    -- Which purses have a tab in the gold tracker. A player who has never been to Cyrodiil has
    -- no use for a tab that will read nought for ever.
    drawerCurrencies = { gold = true, telvar = true, ap = true, vouchers = true },
    goldCurrency = "gold", -- the tab the tracker was last reading
    goldRange = "today",   -- and over what stretch: today / week / month / all
}

-- Settings page colors: bold option names, soft descriptions, one accent per section.
local TEXT = "F2F2F2"
local SOFT = "9A9AA2"
local SECTION = {
    general = "FFFFFF",
    -- Not an accent: what a title wears when it names a way of working rather than a subject.
    white = "FFFFFF",
    yellow = "FFD84A",
    behaviour = "4FDB8B",
    groups = "FF6FA3",
    sets = "B98CFF",
    modules = "FFB627",
    look = "F0A35C",
    orange = "FF8A3D",
}

local function Color(hex, text)
    return string.format("|c%s%s|r", hex, text)
end

-- A checkbox with its explanation written right under it (no hover tooltips on this page).
-- One row per setting. The explanation is the control's tooltip rather than a line of its own:
-- LAM puts a fixed gap between widgets, so a description underneath doubles the height of every
-- single option and leaves the page full of air.
-- Whether a saved key is a module's switch (IG.MODULE_GROUPS): those are written through
-- IG.SetModuleEnabled, which empties the classify cache as well.
local function IsModuleFlag(key)
    if key == "lockedLists" or not IG.SetModuleEnabled then return false end
    for _, flag in pairs(IG.MODULE_GROUPS or {}) do
        if flag == key then return true end
    end
    return false
end

local function Option(name, description, key, refresh)
    return {
        {
            type = "checkbox",
            name = Color(TEXT, name),
            tooltip = description,
            getFunc = function() return IG.sv[key] end,
            setFunc = function(value)
                if IsModuleFlag(key) then return IG.SetModuleEnabled(key, value) end
                IG.sv[key] = value
                if refresh then IG.RefreshLists() end
            end,
            default = IG.DEFAULT_SETTINGS[key],
        },
    }
end

local function Append(list, items)
    for _, item in ipairs(items) do list[#list + 1] = item end
    return list
end

local function IconPicker(name, iconKey, defaultIcon, choices)
    return {
        type = "iconpicker",
        name = Color(TEXT, name),
        choices = choices,
        maxColumns = 8,
        visibleRows = 4,
        iconSize = 32,
        width = "half",
        getFunc = function() return IG.sv.icons[iconKey] or defaultIcon end,
        setFunc = function(icon)
            IG.sv.icons[iconKey] = icon ~= defaultIcon and icon or nil
            IG.RefreshLists()
        end,
        default = defaultIcon,
    }
end

---------------------------------------------------------------------------
-- Keybind and saved variable housekeeping
---------------------------------------------------------------------------

-- Keybind (Controls > Inventory 2.0) and anything else that wants to jump to the settings.
-- How items are ordered inside a group. The dropdown on this page and the button standing on
-- the list's own price header walk this one list, so what the two offer cannot drift apart, and
-- the order here is the order the button steps through them in.
IG.SORT_METHODS = {
    { key = "name",    label = "Name" },
    { key = "value",   label = "Value" },
    { key = "quality", label = "Quality" },
    { key = "count",   label = "Count" },
    -- The game stamps a slot with the moment something new landed in it and leaves everything
    -- else at nothing, so this is what arrived, newest first, and then all you already had.
    { key = "age",     label = "Newest" },
}

-- The five NPC kinds the flat trading layout can be told apart for (InventoryGrouping.lua:
-- TRADING_SCENE_TYPE keys the same way). Order is the order they are offered on the page.
IG.NPC_CATEGORY_TYPES = {
    { key = "merchant",    label = "Merchant" },
    { key = "fence",       label = "Fence" },
    { key = "guildstore",  label = "Guild Store" },
    { key = "playertrade", label = "Player Trade" },
    { key = "mail",        label = "Mail" },
}

-- The crafting skills whose deconstruction and improvement panels Craft.lua groups. Alchemy,
-- Enchanting and Provisioning have no such panel -- their stations are left to the game either
-- way, so they are not offered here; a switch with nothing to turn off would only mislead.
IG.CRAFT_STATION_TYPES = {
    { key = CRAFTING_TYPE_BLACKSMITHING,   label = "Blacksmithing" },
    { key = CRAFTING_TYPE_CLOTHIER,        label = "Clothing" },
    { key = CRAFTING_TYPE_WOODWORKING,     label = "Woodworking" },
    { key = CRAFTING_TYPE_JEWELRYCRAFTING, label = "Jewelry Crafting" },
}

-- Whether the station the player is standing at right now (if any) should be left to the game:
-- the global switch is off, or this one skill's own switch is. Asked by Craft.lua's
-- GroupStationList, once per rebuild of that station's list.
function IG.CraftStationCategoryOff()
    if IG.sv.craftStationCategoryEnabled == false then return true end
    local skill = GetCraftingInteractionType and GetCraftingInteractionType()
    if not skill or skill == CRAFTING_TYPE_INVALID then return false end
    return IG.sv.craftStationCategoryTypes[skill] == false
end

local function SortChoices()
    local labels = {}
    for index, method in ipairs(IG.SORT_METHODS) do labels[index] = method.label end
    return labels
end

-- What this one list does with the pieces you locked. Asked with a list's own key (the ones
-- sv.expanded is kept under), so the answer can differ from window to window.
--
-- Three answers, in the order the button on the bar steps through them: "hidden" keeps them out
-- of the list altogether, "grouped" gathers them at its foot under LOCKED, and "asis" leaves
-- them in the categories they belong to. A list starts on the last of the three -- a lock is
-- something you put on a piece, not something you asked the list to do about it.
IG.LOCKED_MODES = { "hidden", "grouped", "asis" }
IG.LOCKED_DEFAULT_MODE = "asis"

function IG.LockedMode(listKey)
    if listKey == nil or IG.sv == nil then return IG.LOCKED_DEFAULT_MODE end
    local mode = IG.sv.lockedLists[listKey]
    -- A save written before the three modes kept a yes or no in this table. Those are carried
    -- over in IG.MigrateSavedVars; this is the belt to that braces, since a stale value here
    -- would otherwise read as a mode nobody has.
    if mode == true then return "grouped" end
    if type(mode) ~= "string" then return IG.LOCKED_DEFAULT_MODE end
    return mode
end

-- The next one along, wrapping at the end. The button asks for this and nothing else.
function IG.NextLockedMode(listKey)
    local current = IG.LockedMode(listKey)
    for index, mode in ipairs(IG.LOCKED_MODES) do
        if mode == current then return IG.LOCKED_MODES[index % #IG.LOCKED_MODES + 1] end
    end
    return IG.LOCKED_MODES[1]
end

function IG.SetLockedMode(listKey, mode)
    if not (listKey and IG.sv) then return end
    -- The default is written as nothing at all, so a list nobody has touched and a list put
    -- back the way it started are the same thing in the save.
    IG.sv.lockedLists[listKey] = mode ~= IG.LOCKED_DEFAULT_MODE and mode or nil
end

-- Most of the list only cares about one of the three: does LOCKED stand at the foot of it.
function IG.LockedSeparated(listKey)
    return IG.LockedMode(listKey) == "grouped"
end

function IG.SetLockedSeparated(listKey, on)
    IG.SetLockedMode(listKey, on and "grouped" or IG.LOCKED_DEFAULT_MODE)
end

-- And the one the list build cares about: are they to be left out of it entirely.
function IG.LockedHidden(listKey)
    return IG.LockedMode(listKey) == "hidden"
end

-- Whether this one list still draws a piece where it belongs after you have sent it somewhere
-- else. Two answers rather than three, kept per list the same way the one above is.
--
-- The setting on the settings page (INFO SHOWN > Sold And Salvaged Pieces) is the answer a list
-- starts with and nothing more: the moment the button on that window has been pressed, the
-- list's own answer is written down and is the only one read from then on. That is why the
-- table holds a true or a false rather than only the true -- a list that was told "no" has to
-- be able to say so against a setting that says "yes".
function IG.MovedShown(listKey)
    if IG.sv == nil then return true end
    local own = listKey ~= nil and IG.sv.movedLists and IG.sv.movedLists[listKey]
    if own ~= nil then return own == true end
    return IG.sv.asideAtHome ~= false
end

function IG.SetMovedShown(listKey, on)
    if not (listKey and IG.sv and IG.sv.movedLists) then return end
    IG.sv.movedLists[listKey] = on == true
end

-- How the sets under one category are drawn in one list. Two shapes, and they are the two the
-- Don't Group Sets switch already makes: "dividers" draws each set as a line with its name on
-- it that cannot be shut, with its pieces standing under it, and "buttons" draws it as a button
-- you open and close. Nothing new is invented here -- the right click only says which of the
-- two this category wears in this list.
--
-- Kept per list and per category at once, because both halves of what was asked for are real:
-- the right click is on a category, and the bank splitting its sets apart while the bag gathers
-- them into buttons is the case the switch on the settings page cannot say.
IG.SET_VIEW_DIVIDERS = "dividers"
IG.SET_VIEW_BUTTONS = "buttons"

-- The answer this list and category were given, or nil where they were never asked.
function IG.SetViewChoice(listKey, groupKey)
    if not (listKey and groupKey and IG.sv and IG.sv.setViewLists) then return nil end
    local list = IG.sv.setViewLists[listKey]
    local choice = list and list[groupKey]
    if choice == IG.SET_VIEW_DIVIDERS or choice == IG.SET_VIEW_BUTTONS then return choice end
    return nil
end

-- And the one the list build acts on: the category's own answer beats the setting in both
-- directions, and without one of its own it follows Don't Group Sets.
function IG.SetsAsDividers(listKey, groupKey)
    local choice = IG.SetViewChoice(listKey, groupKey)
    if choice then return choice == IG.SET_VIEW_DIVIDERS end
    return IG.sv ~= nil and IG.sv.setRules == true
end

function IG.SetSetViewChoice(listKey, groupKey, choice)
    if not (listKey and groupKey and IG.sv) then return end
    IG.sv.setViewLists = IG.sv.setViewLists or {}
    -- The list's own entry first and the category's answer after it, for the reason
    -- IG.SetGroupSetting gives: either of them may be made or dropped by this call, and the
    -- replay walks its notes backwards.
    IG.NoteSaved(IG.sv.setViewLists, listKey)
    local list = IG.sv.setViewLists[listKey]
    if list then IG.NoteSaved(list, groupKey) end
    if choice == nil then
        -- Taking an answer back leaves nothing behind, so a list whose every category has been
        -- handed back is the same in the save as one nobody ever right clicked.
        if not list then return end
        list[groupKey] = nil
        if next(list) == nil then IG.sv.setViewLists[listKey] = nil end
        return
    end
    list = list or {}
    IG.sv.setViewLists[listKey] = list
    list[groupKey] = choice
end

function IG.SortLabel()
    local current = IG.sv and IG.sv.sortBy
    for _, method in ipairs(IG.SORT_METHODS) do
        if method.key == current then return method.label end
    end
    return IG.SORT_METHODS[1].label
end

-- The next one along, wrapping at the end. The button asks for this and nothing else.
function IG.NextSortMethod()
    local methods = IG.SORT_METHODS
    for index, method in ipairs(methods) do
        if method.key == IG.sv.sortBy then return methods[index % #methods + 1].key end
    end
    return methods[1].key
end

ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_OPEN_SETTINGS", "Open settings")
ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_FOCUS_SEARCH", "Search the open list")
ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_COLLAPSE_ALL", "Close every group")
ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_SEND_TO_SELL", "Send hovered to SELL")
ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_SEND_TO_GUILDSELL", "Send hovered to GUILD STORE")
ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_SEND_TO_DECONSTRUCT", "Send hovered to DECON")
ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_SEND_TO_BANK", "Send hovered to TO BANK")
ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_MARK_AS_JUNK", "Mark as junk")
ZO_CreateStringId("SI_BINDING_NAME_INVENTORY_GROUPING_UNDO", "Undo")

local function OpenSubmenuByReference(submenuRef)
    local submenu = submenuRef and _G[submenuRef]
    if submenu and submenu.label and not submenu.open then
        local handler = submenu.label:GetHandler("OnMouseUp")
        if handler then handler(submenu.label) end
        return true
    end
    return false
end

-- submenuRef: the global name a submenu was given through LAM's own "reference" field (the
-- BANK MODULES page uses "Inventory2BankModulesSubmenu", below) -- opened the same way its own
-- label's click does, since LAM has no "go straight to this page" call of its own to ask for.
-- The panel's own controls are not built yet the moment this runs: LAM builds a panel's page the
-- first time it is actually shown, and this very call is what starts that -- confirmed taking
-- over 100ms and under 1.5s (reported 2026-11-03), so this polls every 150ms rather than betting
-- on one guessed delay, and gives up after two seconds.
local SUBMENU_POLL_MS = 150
local SUBMENU_POLL_TRIES = 40
function IG.OpenSettings(submenuRef)
    if not IG.settingsPanel then return end
    libAddonMenu2:OpenToPanel(IG.settingsPanel)
    if not submenuRef or OpenSubmenuByReference(submenuRef) then return end
    local tries = 0
    local function Poll()
        tries = tries + 1
        if OpenSubmenuByReference(submenuRef) or tries >= SUBMENU_POLL_TRIES then return end
        zo_callLater(Poll, SUBMENU_POLL_MS)
    end
    zo_callLater(Poll, SUBMENU_POLL_MS)
end

-- Drops saved entries that no longer mean anything (renamed or removed groups).
function IG.CleanupSavedVars(sv)
    sv.logoPick = nil   -- left behind by the logo picker, which was only there to choose one
    sv.tintIcons = nil  -- icons always take their button's color now
    sv.indentStep = nil -- every level steps in by the same amount now, and it is not a setting
    -- A piece already in your collection said nothing worth a counter of its own.
    sv.showDuplicates = nil
    -- Advanced off means the defaults are what plays, so a save that still carries per-category
    -- animations from before has them put aside here rather than at the next click of the switch.
    if sv.animationsAdvanced ~= true and next(sv.animations or {}) then
        sv.animationsKept = ZO_DeepTableCopy(sv.animations)
        sv.animations = {}
    end
    local validIcons = {}
    for _, group in ipairs(IG.GROUPS) do validIcons[group.key] = true end
    for _, sub in ipairs(IG.SUBGROUP_LIST) do validIcons["sub:" .. sub.label] = true end
    for key in pairs(sv.icons) do
        if not validIcons[key] then sv.icons[key] = nil end
    end
    -- The flat layouts name their categories themselves, so their memory is left alone.
    local OWN_KEYS = { minimal = true, trading = true }
    for name, states in pairs(sv.expanded) do
        if not OWN_KEYS[name] then
            for key in pairs(states) do
                local root = key:match("^[^/]+")
                if not IG.GROUP_BY_KEY[root] then states[key] = nil end
            end
        end
    end
    for key, group in pairs(sv.groups) do
        if not IG.GROUP_BY_KEY[key] then
            sv.groups[key] = nil
        elseif group.section and not IG.SECTION_INDEX[group.section] then
            group.section = nil
        end
    end
    for _, scope in pairs(sv.overrides) do
        for id, groupKey in pairs(scope) do
            if not IG.GROUP_BY_KEY[groupKey] then scope[id] = nil end
        end
    end
    -- A mark only ever means something about a piece sitting in SELL [GUILD STORE], so the
    -- overrides that put pieces there are what the marks are measured against: an id no override
    -- answers belongs to a piece that has been sold, spent or filed elsewhere since, and no menu
    -- anywhere could reach it to take the mark off again. This keeps the table from ever growing
    -- past the list of pieces it can be about.
    --
    -- Unless a whole set was sent there, in which case the pieces in it are named by nothing an
    -- id can be looked up in, and the bags are not open to be asked at the time this runs. Then
    -- nothing is dropped: a handful of marks nobody can see costs less than a mark thrown away
    -- from a piece still sitting in the pile wearing it.
    --
    -- The marks are read here rather than in MigrateSavedVars for the one shape that came
    -- before them: while there was only one thing to wait for, a mark was written as true under
    -- a key of its own. That shape and this one were written by the same dataVersion, so the
    -- version number cannot tell them apart and only the old key itself can. Every such mark
    -- meant the upgrade, because there was nothing else it could mean.
    if sv.awaitingUpgrade then
        for id, marked in pairs(sv.awaitingUpgrade) do
            if marked and sv.awaiting[id] == nil then sv.awaiting[id] = "upgrade" end
        end
        sv.awaitingUpgrade = nil
    end
    local setAside
    for _, groupKey in pairs(sv.overrides.sets) do
        if groupKey == IG.AWAITING_GROUP then
            setAside = true
            break
        end
    end
    if not setAside then
        for id in pairs(sv.awaiting or {}) do
            if sv.overrides.items[id] ~= IG.AWAITING_GROUP then sv.awaiting[id] = nil end
        end
    end
    -- An answer given about a category that is no longer one says nothing to anybody.
    for key in pairs(sv.splitChoice or {}) do
        if not IG.GROUP_BY_KEY[key] then sv.splitChoice[key] = nil end
    end
    -- The same for how a list draws one category's sets, one list at a time; a list left with
    -- no answers at all goes with them.
    for listKey, choices in pairs(sv.setViewLists or {}) do
        for key in pairs(choices) do
            local inLocked = type(key) == "string" and key:match("^LOCKED/(.+)$")
            if not IG.GROUP_BY_KEY[inLocked or key] then choices[key] = nil end
        end
        if next(choices) == nil then sv.setViewLists[listKey] = nil end
    end
    -- The same for a kind of boost: one asked to stand on its own and since taken off the list
    -- of kinds would otherwise keep a category alive that nothing can ever be filed into.
    for key in pairs(sv.boostSplit or {}) do
        if not IG.BOOST_KIND_BY_KEY[key] then sv.boostSplit[key] = nil end
    end
    for key in pairs(sv.disposalOut or {}) do
        if not (IG.DISPOSAL_MEMBERS and IG.DISPOSAL_MEMBERS[key]) then sv.disposalOut[key] = nil end
    end
    local validNpcTypes = {}
    for _, kind in ipairs(IG.NPC_CATEGORY_TYPES) do validNpcTypes[kind.key] = true end
    for key in pairs(sv.npcCategoryTypes or {}) do
        if not validNpcTypes[key] then sv.npcCategoryTypes[key] = nil end
    end
    local validCraftTypes = {}
    for _, kind in ipairs(IG.CRAFT_STATION_TYPES) do validCraftTypes[kind.key] = true end
    for key in pairs(sv.craftStationCategoryTypes or {}) do
        if not validCraftTypes[key] then sv.craftStationCategoryTypes[key] = nil end
    end
end

-- Older saves are brought up to date here, one step per version, so nobody loses their settings
-- when the structure changes.
function IG.MigrateSavedVars(sv)
    local from = sv.dataVersion or 0
    if from == IG.DATA_VERSION then return end
    if from < 21 then
        -- Auto-sell was one switch; it is now one of the two actions, with Ask between off and on.
        if sv.automateAutoSell == true then sv.actionSell = "auto" end
        sv.automateAutoSell = nil
    end
    if from < 20 then
        -- AUTOMATE's "Show Moved Pieces Where They Were" was a master switch over INFO SHOWN's
        -- Sold And Salvaged Pieces and every window's own Show Moved button, and it is gone: the
        -- two below it already say the same thing. A save that had it off is written into them,
        -- so every list goes on drawing moved pieces only where they went; pressing a window's
        -- own button still turns that one window back on.
        if sv.automateMovedCopies == false then
            sv.asideAtHome = false
            if type(sv.movedLists) == "table" then
                for listKey in pairs(sv.movedLists) do sv.movedLists[listKey] = false end
            end
        end
        sv.automateMovedCopies = nil
    end
    if from < 19 then
        -- SELL and DECONSTRUCT no longer share one heading (the side-by-side split is gone;
        -- both stand inside DISPOSAL now), so its switch goes.
        sv.sellDeconPaired = nil
    end
    if from < 18 then
        -- The two setless gear switches became one Off / Sell / Deconstruct line per quality.
        local setless = type(sv.autoSetless) == "table" and sv.autoSetless or {}
        if sv.autoSellLowGear == true then
            setless[ITEM_FUNCTIONAL_QUALITY_NORMAL] = "sell"
            setless[ITEM_FUNCTIONAL_QUALITY_MAGIC] = "sell"
        end
        if sv.autoDeconHighGear == true then
            setless[ITEM_FUNCTIONAL_QUALITY_ARCANE] = "decon"
            setless[ITEM_FUNCTIONAL_QUALITY_ARTIFACT] = "decon"
            setless[ITEM_FUNCTIONAL_QUALITY_LEGENDARY] = "decon"
        end
        sv.autoSetless = setless
        sv.autoSellLowGear = nil
        sv.autoDeconHighGear = nil
    end
    if from < 17 then
        -- SELL and DECONSTRUCT are always left out of RECENT LOOT now, so the switch for it is gone.
        sv.automateHideRecent = nil
    end
    if from < 16 then
        -- The per-window switches are gone: every list is grouped while the addon runs, and the
        -- Global Switch is the one way back to the game's own lists.
        for _, key in ipairs({ "enableBackpack", "enableTrading", "enableBank", "guildBank",
            "houseBank", "craftStations" }) do
            sv[key] = nil
        end
    end
    if from < 15 then
        -- RECENT LOOT no longer lists garbage at all, so its Garbage pile and the switch for it
        -- are gone.
        sv.lastRunPileGarbage = nil
    end
    if from < 14 then
        -- Run loot used to be kept out of NEW and now it is not. Every save written before this
        -- carries the old answer whether or not anybody chose it: the value was copied in from
        -- the defaults the first time the addon loaded, so an untouched save and a deliberate
        -- one cannot be told apart. The addon has not been published, so there is no one whose
        -- considered choice this overwrites, and leaving old saves alone would mean nobody who
        -- already has one ever sees what the addon now does by default. The switch is where it
        -- always was for anyone who wants the old behaviour back.
        sv.lastRunOverNew = false
    end
    if from < 13 then
        -- SELL [GUILD STORE] arrives as a category of its own, and it is the category some
        -- people had already made for themselves: CUSTOM is the only one that could be called
        -- anything, so anybody who wanted a guild store pile renamed CUSTOM and used that.
        --
        -- Where that is what a save says -- CUSTOM given a name of the player's own, and that
        -- name naming the guild store -- the pieces in it are pointed at the new category and
        -- the name is let go, so CUSTOM goes back to being the empty one to fill next time.
        -- Nothing is lost by that: a piece keeps the only thing it was carrying, which is that
        -- it was set aside, and it is set aside in the category that now says out loud what the
        -- name was saying. Leaving them where they were would have put the same meaning in two
        -- categories standing one above the other, and the one the player would go looking in
        -- is the new one.
        --
        -- Every other save is left alone. A CUSTOM used for anything else is a category of the
        -- player's own doing something the new one knows nothing about, and emptying it would
        -- be reaching into a decision nobody asked us about.
        local groups = sv.groups or {}
        local named = groups.CUSTOM and groups.CUSTOM.name
        if named and zo_strfind(zo_strlower(named), "guild") then
            for _, scope in pairs(sv.overrides or {}) do
                for id, groupKey in pairs(scope) do
                    if groupKey == "CUSTOM" then scope[id] = "GUILDSELL" end
                end
            end
            -- The colour and the place go with the name: they were chosen for the pile, and the
            -- pile has moved. An entry left holding nothing says nothing the defaults do not.
            local colour = groups.CUSTOM.color
            groups.CUSTOM.name, groups.CUSTOM.color = nil, nil
            if next(groups.CUSTOM) == nil then groups.CUSTOM = nil end
            if colour then
                groups.GUILDSELL = groups.GUILDSELL or {}
                groups.GUILDSELL.color = groups.GUILDSELL.color or colour
            end
        end
    end
    if from < 12 then
        -- Where JUNK starts out is the MODULES heading now, and the switch that used to lift it
        -- there starts on. A save written before today says off because that was the default,
        -- not because anybody said so, and reading it as an answer would leave the very
        -- category this change is about sitting where it always was. The switch is still there
        -- and still puts JUNK back at the foot of the list.
        sv.junkOnModules = true
    end
    if from < 11 then
        -- INFINITE ARCHIVE stops being a category of its own and becomes one of the five kinds
        -- BOOSTS is made of, folded in with the rest of them: verses and visions read under an
        -- Infinite Archive heading inside BOOSTS now, and the category comes back the moment it
        -- is asked for from the BOOSTS page.
        --
        -- Nothing of the Archive's is thrown away, and none of it needs moving either: the key
        -- is still ARCHIVE and every table that holds something about a category holds it under
        -- that key -- the name and colour and place the player gave it (sv.groups), its glow,
        -- its animation, the answer it gave about splitting itself up, and the pieces sent to it
        -- by hand (sv.overrides). All of it sits exactly where it was, meaning exactly what it
        -- meant, and is read again the day the category stands again.
        --
        -- That the pieces may stay is the part worth saying twice. A piece sent to a category
        -- that is not standing is not lost and does not vanish: the classifier does not ask a
        -- category that is folded away to answer for anything (Classify.lua: ClassifyKind), so
        -- such a piece is filed by what it is, like any other, and goes back to where it was
        -- sent when the category returns. Dropping those choices here would have lost them for
        -- good with nobody told.
        sv.boostSplit = sv.boostSplit or {}
    end
    if from < 10 then
        -- The switch under JUNK that broke it into what its pieces are is gone. That question
        -- is asked of every category with no headings of its own now, from the one setting in
        -- General or from the category's own right click menu, and JUNK had no business being
        -- the only one that could answer it.
        --
        -- A save that had it on says so about JUNK by hand, which is the answer that beats the
        -- setting either way it is set; the new setting starts off, so a save that had it off
        -- changes nothing either. Nobody's list is drawn differently at this login.
        sv.splitChoice = sv.splitChoice or {}
        if sv.junkSplit == true then sv.splitChoice.JUNK = "split" end
        sv.junkSplit = nil
    end
    if from < 9 then
        -- Hiding a category is gone. A category that was hidden was simply not in any list, so
        -- a save still carrying the flag would keep it out for good with nothing left on the
        -- settings page to switch it back on. The flag is dropped here and every category the
        -- player hid comes back at this login. An entry that was only ever written to hold the
        -- flag is left empty by that, and an empty entry says nothing the defaults do not
        -- already say, so it goes too rather than sit in the save file forever.
        for key, group in pairs(sv.groups or {}) do
            group.hidden = nil
            if next(group) == nil then sv.groups[key] = nil end
        end
    end
    if from < 8 then
        -- EXPERIENCE SCROLLS and EDICTS folded into one category, BOOSTS. BOOSTS stands where
        -- EXPERIENCE SCROLLS stood and holds nearly all of what it held, so that is the one
        -- whose settings carry over -- a name, a colour and a place are one category's
        -- worth of choices and only one of the two can keep them. EDICTS' own are let go: it was
        -- the smaller of the two and its colour would read as somebody else's now.
        if sv.groups then
            sv.groups.BOOSTS = sv.groups.BOOSTS or sv.groups.XPSCROLLS
            sv.groups.XPSCROLLS, sv.groups.EDICTS = nil, nil
        end
        for _, store in ipairs({ sv.glows or {}, sv.animations or {}, sv.animationsKept or {} }) do
            store.BOOSTS = store.BOOSTS or store.XPSCROLLS
            store.XPSCROLLS, store.EDICTS = nil, nil
        end
        -- A piece sent to either category by hand is still sent by hand: it is pointed at the
        -- category they became. Left alone it would name a category that is not there any more,
        -- and the tidy-up below would drop it -- the piece would come back, but the choice about
        -- it would be gone without anybody being told.
        if sv.overrides then
            for _, scope in pairs(sv.overrides) do
                for id, groupKey in pairs(scope) do
                    if groupKey == "XPSCROLLS" or groupKey == "EDICTS" then scope[id] = "BOOSTS" end
                end
            end
        end
    end
    if from < 7 then
        -- The yes or no each list kept about locked pieces became one of three answers. Yes was
        -- gathering them at the foot of the list, and no was leaving them where they belong --
        -- which is what the mode the table now leaves empty means -- so no list changes today.
        sv.lockedLists = sv.lockedLists or {}
        for listKey, value in pairs(sv.lockedLists) do
            sv.lockedLists[listKey] = value == true and "grouped" or nil
        end
    end
    if from < 6 then
        -- One switch for every list became one per list. Whatever it said, every list is
        -- started off saying the same, so nothing about any of them changes today.
        sv.lockedLists = sv.lockedLists or {}
        for _, listKey in ipairs({ "backpack", "bank", "guildbank", "housebank", "craft" }) do
            -- Written as the mode it became rather than as the yes it was: the steps run
            -- newest first, so the step above has already been and gone by the time an old
            -- enough save reaches this one.
            sv.lockedLists[listKey] = sv.lockedGroup == true and "grouped" or nil
        end
        sv.lockedGroup = nil
    end
    if from < 5 then
        -- Colour families arrived switched on and are switched off again: the palette a save
        -- was written with is the one it should still be reading when it is opened.
        sv.coloredGroups = false
    end
    if from < 4 then
        -- Sending one piece aside used to send everything that looked like it: the choice was
        -- kept per item id. It is kept per piece now, and an old entry names a kind rather than
        -- a piece, so there is nothing in it to carry over.
        if sv.overrides and sv.overrides.items then ZO_ClearTable(sv.overrides.items) end
    end
    if from < 3 then
        -- The three animation checkboxes became one list with a style and a speed each.
        for key, setting in pairs({ NEW = "animateNew", REWARDS = "animateRewards", LASTRUN = "animateLastRun" }) do
            if sv[setting] == false then sv.animations[key] = { style = "none", speed = "normal" } end
            sv[setting] = nil
        end
    end
    if from < 2 then
        -- RECENT LOOT used to hold one pile of loot; now every run is listed on its own and the
        -- option that used to mean "pile runs up" means "keep the older ones", so it starts on.
        sv.lastRunAccumulate = true
    end
    sv.dataVersion = IG.DATA_VERSION
end

local function ResetEverything()
    -- The Global Switch is not a setting like the others: it decides whether the addon is running
    -- at all, and a reset while it is off would half-start one. It keeps its value.
    local wasEnabled = IG.sv.addonEnabled
    for key, value in pairs(IG.DEFAULT_SETTINGS) do
        IG.sv[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
    end
    IG.sv.addonEnabled = wasEnabled
    -- Settings this addon has written but no longer starts with. A key that is not in the
    -- defaults is not reached by the loop above, so it is named here.
    IG.sv.animationsKept = nil
    IG.sv.previewPos = nil -- the preview goes back beside the page rather than where it was dragged
    -- Row heights are read once and kept on the list's data types, so they are written again
    -- rather than waiting for the next reload.
    IG.ApplyRowDensity()
    IG.RefreshLists()
    -- The page the button was pressed on is still showing every old value until it is told.
    IG.RefreshSettingsPanel()
end

-- Nothing here can be undone, so it is asked for first.
local RESET_DIALOG = "INVENTORY_GROUPING_RESET"

ESO_Dialogs[RESET_DIALOG] = {
    title = { text = "Reset everything" },
    mainText = { text = "Every setting, icon and open group goes back to how the addon starts." },
    buttons = {
        { text = SI_DIALOG_YES, callback = function() ResetEverything() end },
        { text = SI_DIALOG_NO },
    },
}

local function ConfirmReset()
    ZO_Dialogs_ShowDialog(RESET_DIALOG)
end

-- Also on a keybind: closes every group in every list at once.
function IG.CollapseAllGroups()
    IG.CollapseEverything()
    IG.RefreshLists()
end

---------------------------------------------------------------------------
-- Sets and the Last run module
---------------------------------------------------------------------------

local function SetControls()
    local controls = {}
    Append(controls, Option("Set info on hover",
        "Hover a set to see its bonuses and which pieces you have.",
        "showSetTooltip", false))
    Append(controls, Option("Full set glow",
        "Equipped Sets page: a fully worn set glows green.",
        "fullSetGlow", false))
    -- Repaints the page at once rather than the lists, which do not show it.
    local weight = Option("Show Armor Weight",
        "Equipped Sets page: armor marks are colored Light, Medium or Heavy.",
        "showArmorWeight", false)
    weight[1].setFunc = function(value)
        IG.sv.showArmorWeight = value
        if IG.RefreshOpenDrawer then IG.RefreshOpenDrawer() end
    end
    Append(controls, weight)
    Append(controls, Option("Owned pieces",
        "Slot icons under each set: owned pieces lit, worn ones green.",
        "showPieces", true))
    Append(controls, Option("Drop location",
        "Where a set drops, on the right of its header.",
        "showLocation", true))
    return controls
end

local function LastRunControls()
    local controls = {}
    Append(controls, Option("Keep older runs",
        "Keeps your last five runs. Off: only the current one.",
        "lastRunAccumulate", true))
    Append(controls, Option("Places As Lines",
        "Each place is a heading line with its loot under it. Off: a category to open.",
        "lastRunRules", true))
    -- Dimmed while the NEW module is off: the question it answers is which of the two groups a
    -- run's loot goes to, and with one of them gone it has nothing left to decide. Left readable
    -- rather than hidden, so the line does not come and go as another page is switched.
    local overNew = Option("Keep run loot out of NEW",
        "Run loot shows only in RECENTLY ACQUIRED, not in NEW. Off: in both.",
        "lastRunOverNew", true)
    overNew[1].disabled = function() return IG.sv.newEnabled ~= true end
    Append(controls, overNew)
    Append(controls, Option("Show Stolen",
        "Groups a run's stolen items under one Stolen line. Off: each listed by name.",
        "lastRunPileStolen", true))
    Append(controls, Option("Keep Stolen Items Out",
        "Stolen items go to STOLEN, never RECENTLY ACQUIRED.",
        "automateHideStolen", true))
    Append(controls, { { type = "header", name = Color(SECTION.modules, "What counts as a run") } })
    Append(controls, Option("Dungeons, trials and arenas",
        "Each entry starts a new run.",
        "lastRunInstances", true))
    Append(controls, Option("Endless Archive",
        "Your Endless Archive session counts as one run.",
        "lastRunEndless", true))
    Append(controls, Option("Cyrodiil",
        "Everything you pick up in Cyrodiil, until you leave.",
        "lastRunCyrodiil", true))
    Append(controls, Option("Imperial City",
        "Everything you pick up in the Imperial City and its sewers.",
        "lastRunImperialCity", true))
    Append(controls, Option("Battlegrounds",
        "Each battleground match counts as its own run.",
        "lastRunBattlegrounds", true))
    Append(controls, Option("Out in the world",
        "One run per zone, including delves, dolmens and world bosses.",
        "lastRunOverland", true))
    Append(controls, Option("Rewards by mail",
        "Mailed rewards (e.g. Rewards of the Worthy) join the run when you take them.",
        "lastRunRewardMail", false))
    return controls
end

---------------------------------------------------------------------------
-- Visuals: the switches a theme writes
---------------------------------------------------------------------------

-- A dropdown over a fixed set of values (Compact / Normal / Roomy and the like). labels and
-- values line up one to one; apply runs before the lists are rebuilt.
-- One letter at a time, each in its own color, for the one option that is about color itself.
local RAINBOW = { "FF6B6B", "FF9F45", "FFE14C", "6BE06B", "4CC9FF", "8C7BFF", "FF7BD5" }

-- dim, when given, is how much of each color is kept: the low brightness theme writes its own
-- name in what it does.
local function Rainbow(text, dim)
    local parts = {}
    for index = 1, #text do
        local hex = RAINBOW[(index - 1) % #RAINBOW + 1]
        if dim then hex = IG.DimColor(hex, dim) end
        parts[index] = string.format("|c%s%s|r", hex, text:sub(index, index))
    end
    return table.concat(parts)
end

-- One section title says what it is by doing it. Its letters are a ramp: green on the first,
-- turning letter by letter into a grey barely short of white on the last. Over that ramp a light
-- travels left to right, lifting each letter it passes a little further toward white and letting
-- it fall again. The letters themselves never move, so the title takes no more room than any
-- other, and with no light on it the ramp alone is already the title.
local TITLE_START = "3FDD85"  -- the first letter
local TITLE_END = "E4E4EA"    -- the last one
local TITLE_LIFT = 0.5        -- how far toward white the light takes the letter under its middle
local TITLE_CYCLE = 2800      -- one pass across the word, in milliseconds
local TITLE_BAND = 0.3        -- how much of the word the light covers at once
local TITLE_STEPS = 90        -- how many times across a pass the string is written again

-- head is where the middle of the light sits, 0 being the first letter and 1 the last. Left out,
-- no letter is lit and what comes back is the ramp on its own.
local function TitleText(text, head)
    local startR, startG, startB = IG.HexToRGB(TITLE_START)
    local endR, endG, endB = IG.HexToRGB(TITLE_END)
    local last = zo_max(#text - 1, 1)
    local parts = {}
    for index = 1, #text do
        local at = (index - 1) / last
        local r = startR + (endR - startR) * at
        local g = startG + (endG - startG) * at
        local b = startB + (endB - startB) * at
        if head then
            -- How far this letter is from the middle of the light, as a share of its width.
            local distance = math.abs(at - head) / TITLE_BAND
            if distance < 1 then
                local lift = (0.5 + 0.5 * math.cos(distance * math.pi)) * TITLE_LIFT
                r, g, b = r + (1 - r) * lift, g + (1 - g) * lift, b + (1 - b) * lift
            end
        end
        parts[index] = string.format("|c%02X%02X%02X%s|r",
            zo_round(r * 255), zo_round(g * 255), zo_round(b * 255), text:sub(index, index))
    end
    return table.concat(parts)
end

local ANIMATED_TITLE = "ANIMATED NOTIFICATIONS"
-- What the title reads as before any light is put on it.
local ANIMATED_TITLE_STILL = TitleText(ANIMATED_TITLE)

-- Writing twenty-two letters out again every frame buys nothing the eye can see, so the string is
-- only rebuilt once the light has moved a step. A hidden control gets no OnUpdate of its own, so
-- nothing here runs while the page is away.
local function AnimateTitle(label)
    label:SetHandler("OnUpdate", function(self)
        local phase = (GetFrameTimeMilliseconds() % TITLE_CYCLE) / TITLE_CYCLE
        local step = zo_floor(phase * TITLE_STEPS)
        if step == self.igTitleStep then return end
        self.igTitleStep = step
        -- The light starts just off one end and finishes just off the other, so the first and
        -- last letters get the whole of it rather than half.
        self:SetText(TitleText(ANIMATED_TITLE, -TITLE_BAND + phase * (1 + TITLE_BAND * 2)))
    end)
end

---------------------------------------------------------------------------
-- A block of switches, drawn as one
---------------------------------------------------------------------------

-- The role markers, drawn inline in a label, each in its own color.
local ROLE_SAMPLE_SIZE = 22

local function RoleIcons()
    local parts = {}
    for _, sample in ipairs(IG.GetRoleSamples()) do
        parts[#parts + 1] = string.format("|c%s|t%d:%d:%s:inheritcolor|t|r",
            sample.color, ROLE_SAMPLE_SIZE, ROLE_SAMPLE_SIZE, sample.icon)
    end
    return table.concat(parts, " ")
end

-- LAM leaves 15 pixels between every widget it lays out, so a switch built from a checkbox, a
-- description and a divider ends up with two holes inside it and no way to close them. A whole
-- block of switches is drawn as a single widget instead, and the spacing inside it is ours:
-- the explanation sits right under its name, and the line between two switches has the same air
-- above it as below.
local SWITCH_NAME_FONT = "ZoFontWinH4"
local SWITCH_TEXT_FONT = "ZoFontGame"
local SWITCH_TEXT_GAP = 1   -- name to explanation
local SWITCH_RULE_GAP = 9   -- explanation to line, and line to the next name
local SWITCH_RULE_ALPHA = 0.3
local SWITCH_ON, SWITCH_OFF = "5CE07A", "9A9AA2"
local SWITCH_HOVER_ALPHA = 0.07
local SWITCH_ROW_HEIGHT = ROLE_SAMPLE_SIZE -- a name line is at least as tall as an icon in it

local SWITCH_DIM_ALPHA = 0.4

-- A line whose answer is one of a handful rather than yes or no wears a button where the others
-- wear their ON/OFF, the same size the category tables give their columns.
local SWITCH_PICK_WIDTH = 96
local SWITCH_PICK_HEIGHT = 22
local SWITCH_STATE_ROOM = 48 -- what an ON/OFF takes on the right of its line
local SWITCH_SIDE_GAP = 12   -- kept clear between a name and what stands on its right

-- Nearly every switch on this page is one named setting, read and written straight. A few
-- answer for something kept under a key of its own inside another table -- one entry per
-- category, say, where naming each of them as a setting would mean a setting the addon invents
-- at load. Those hand the block a reader and a writer instead of a name, and nothing else about
-- the line changes.
local function SwitchValue(option)
    if option.get then return option.get() end
    return IG.sv[option.key]
end

local function SetSwitchValue(option, value)
    if option.set then option.set(value)
    elseif IsModuleFlag(option.key) then IG.SetModuleEnabled(option.key, value)
    else IG.sv[option.key] = value end
end

-- What the button reads: the name of whatever the setting is set to, falling back to the first
-- answer if it is set to something no longer on the list.
local function PickLabel(option)
    local current = SwitchValue(option)
    for index, value in ipairs(option.pick.values) do
        if value == current then return option.pick.labels[index] end
    end
    return option.pick.labels[1]
end

local function PaintSwitch(row)
    local on = SwitchValue(row.option) == true
    local live = row.enabled == nil or row.enabled()
    if row.pick then
        -- Nothing here is on or off, so the only thing to say is what it is set to, and the
        -- line goes quiet as a whole while the switch above it is.
        row.pick:SetText(PickLabel(row.option))
        row.pick:SetEnabled(live)
        row:SetAlpha(live and 1 or SWITCH_DIM_ALPHA)
        if row.outerText then row.outerText:SetAlpha(live and 1 or SWITCH_DIM_ALPHA) end
        if row.describe then row.text:SetText(row.describe()) end
        return
    end
    row.state:SetText(on and "ON" or "OFF")
    row.state:SetColor(IG.HexToRGB(on and SWITCH_ON or SWITCH_OFF))
    -- Dim while the switch above it says this one is not yours to set, and -- for a switch that
    -- only governs other settings -- while it is off and there is nothing under it to read.
    local lit = live and (on or not row.dimOff)
    row:SetAlpha(lit and 1 or SWITCH_DIM_ALPHA)
    -- The explanation under a name is a child of the block, not of the row, so that a long one
    -- can run the full width. It has to be dimmed alongside its row by hand.
    if row.outerText then row.outerText:SetAlpha(lit and 1 or SWITCH_DIM_ALPHA) end
    -- An explanation that depends on the switch is written again every time it moves.
    if row.describe then row.text:SetText(row.describe()) end
end

local function RefreshSwitchBlock(control)
    for _, row in ipairs(control.rows or {}) do PaintSwitch(row) end
end

-- options: { { name, description, key, get, set, richName, inline, look, enabled, dimOff, onToggle, pick } ... }
-- key names the setting the line is; get and set stand in for it where what the line answers
-- for is not a setting of its own (SwitchValue, above).
-- pick = { values, labels, apply } turns the line into one with several answers instead of two:
-- the ON/OFF gives way to a button reading the answer it is set to, and pressing it takes the
-- next. apply is optional and runs before the lists are refreshed, for a setting they are
-- measured by rather than merely drawn from.
-- in the order they should read. description may be a function, and is then written again on
-- every paint; look = false marks a switch that is not about the look, so moving it is not "a
-- theme of your own"; dimOff dims the line itself while it is off; onToggle(on) runs after the
-- switch has moved, for a switch that has to put something else in order.
-- edges: a line of its own above and below the block, or "bottom" for the closing one alone --
-- what a block that opens a category wants, so that whatever follows it is ruled off rather than
-- left hanging under the last switch. LAM's own divider widget would sit in between two of its
-- 15 pixel gaps; drawn in here it keeps the block's own spacing.
-- indent = true makes a line the child of the one above it: set in, with a thin guide down its
-- left, so a switch and the setting that only means something under it read as one thing.
local SWITCH_INDENT = 18
local function SwitchBlock(options, edges)
    return {
        type = "custom",
        minHeight = 40,
        -- Generous on purpose: the block grows to fit its rows, and a cap below its real height
        -- lets the last lines spill over the widget under it.
        maxHeight = 4000,
        refreshFunc = RefreshSwitchBlock,
        createFunc = function(control)
            local width = control:GetWidth()
            control.rows = {}
            local previous -- whatever the next thing hangs from

            -- Down from whatever came before, across from the block's own left edge (plus an
            -- indent): an indented line must not set in everything that follows it.
            local function Hang(item, after, left, gap)
                if after then
                    item:SetAnchor(TOPLEFT, after, BOTTOMLEFT, 0, gap, ANCHOR_CONSTRAINS_Y)
                    item:SetAnchor(TOPLEFT, control, TOPLEFT, left, 0, ANCHOR_CONSTRAINS_X)
                else
                    item:SetAnchor(TOPLEFT, control, TOPLEFT, left, 0)
                end
            end

            local function Rule(after, left)
                left = left or 0
                local rule = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
                rule:SetDimensions(width - left, 1)
                rule:SetColor(IG.HexToRGB(SOFT))
                rule:SetAlpha(SWITCH_RULE_ALPHA)
                Hang(rule, after, left, SWITCH_RULE_GAP)
                return rule
            end

            if edges and edges ~= "bottom" then previous = Rule(nil) end

            local first = true
            for _, option in ipairs(options) do
                local left = option.indent and SWITCH_INDENT or 0
                local rowWidth = width - left
                if not first then previous = Rule(previous, left) end
                first = false

                -- The name and its ON/OFF share one line, and the whole line is the button.
                local row = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
                row:SetWidth(rowWidth)
                row:SetMouseEnabled(true)
                Hang(row, previous, left, SWITCH_RULE_GAP)
                if option.indent then
                    -- The guide: a thin line down the left of the child line and its text.
                    local guide = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
                    guide:SetWidth(2)
                    guide:SetAnchor(TOPRIGHT, row, TOPLEFT, -SWITCH_INDENT / 2 + 1, 0)
                    guide:SetAnchor(BOTTOMRIGHT, row, BOTTOMLEFT, -SWITCH_INDENT / 2 + 1, 0)
                    guide:SetColor(IG.HexToRGB(option.guideColor or SOFT))
                    guide:SetAlpha(0.5)
                end

                local hover = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
                hover:SetAnchorFill(row)
                hover:SetColor(1, 1, 1, SWITCH_HOVER_ALPHA)
                hover:SetHidden(true)

                local name = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
                name:SetFont(SWITCH_NAME_FONT)
                name:SetText(option.richName or Color(TEXT, option.name))
                name:SetAnchor(LEFT, row, LEFT, 0, 0)
                -- Kept clear of the ON/OFF or the pick button on the right: a long name is cut
                -- short rather than written under them.
                name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
                name:SetDimensionConstraints(0, 0,
                    rowWidth - (option.pick and SWITCH_PICK_WIDTH or SWITCH_STATE_ROOM) - SWITCH_SIDE_GAP, 0)

                -- A line with more than two answers gets a button instead of the ON/OFF word:
                -- pressing it steps to the next answer. LAM's own dropdown is a widget of its
                -- own and would cut the block in two, which is the whole thing this block is
                -- here to avoid.
                local state, pick
                if option.pick then
                    pick = WINDOW_MANAGER:CreateControlFromVirtual(nil, row, "ZO_DefaultButton")
                    pick:SetDimensions(SWITCH_PICK_WIDTH, SWITCH_PICK_HEIGHT)
                    pick:SetAnchor(RIGHT, row, RIGHT, 0, 0)
                else
                    state = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
                    state:SetFont(SWITCH_NAME_FONT)
                    state:SetAnchor(RIGHT, row, RIGHT, 0, 0)
                end
                row:SetHeight(zo_max(name:GetTextHeight(), SWITCH_ROW_HEIGHT))

                -- An explanation short enough to sit beside its name does, in its own font. A
                -- switch whose name says it all goes without one and the next line moves up.
                local text
                if option.description then
                    text = WINDOW_MANAGER:CreateControl(nil, option.inline and row or control, CT_LABEL)
                    text:SetFont(SWITCH_TEXT_FONT)
                    if option.inline then
                        -- Runs from the name to the ON/OFF, never under it.
                        text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
                        text:SetAnchor(LEFT, name, RIGHT, 8, 0)
                        text:SetAnchor(RIGHT, pick or state, LEFT, -SWITCH_SIDE_GAP, 0)
                    else
                        text:SetWrapMode(TEXT_WRAP_MODE_WRAP)
                        text:SetWidth(rowWidth)
                        text:SetAnchor(TOPLEFT, row, BOTTOMLEFT, 0, SWITCH_TEXT_GAP)
                    end
                    if type(option.description) == "function" then
                        row.describe, row.text = option.description, text
                    else
                        text:SetText(Color(SOFT,
                            option.inline and ("- " .. option.description) or option.description))
                    end
                    -- An inline one is a child of the row and follows it on its own.
                    if not option.inline then row.outerText = text end
                end

                -- The option itself rather than the name of the setting it is: a line that
                -- answers for something other than a setting has no name to keep.
                row.state, row.enabled = state, option.enabled
                row.dimOff = option.dimOff
                row.pick, row.option = pick, option
                if pick then
                    pick:SetHandler("OnClicked", function()
                        if option.enabled and not option.enabled() then return end
                        local values = option.pick.values
                        local at = 1
                        for index, value in ipairs(values) do
                            if value == SwitchValue(option) then at = index end
                        end
                        SetSwitchValue(option, values[at % #values + 1])
                        PaintSwitch(row)
                        PlaySound(SOUNDS.DEFAULT_CLICK)
                        if option.look ~= false then IG.NoteCustomTheme() end
                        -- A setting the lists are measured by has to say so before they are
                        -- built again; one that is only read while drawing needs nothing here.
                        if option.pick.apply then option.pick.apply() end
                        IG.RefreshLists()
                        IG.RefreshSettingsPanel()
                    end)
                end
                row:SetHandler("OnMouseEnter", function() hover:SetHidden(false) end)
                row:SetHandler("OnMouseExit", function() hover:SetHidden(true) end)
                row:SetHandler("OnMouseUp", function(_, _, upInside)
                    -- The whole line is the button for a switch. For a line with a button of
                    -- its own it is not: a setting with several answers should only move when
                    -- the button itself is pressed.
                    if option.pick then return end
                    if not upInside then return end
                    if option.enabled and not option.enabled() then return end
                    local turned = not (SwitchValue(option) == true)
                    SetSwitchValue(option, turned)
                    if option.onToggle then option.onToggle(turned) end
                    PaintSwitch(row)
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    if option.look ~= false then IG.NoteCustomTheme() end
                    IG.RefreshLists()
                    IG.RefreshSettingsPanel()
                end)

                control.rows[#control.rows + 1] = row
                previous = (option.inline or not text) and row or text
            end

            if edges then Rule(previous) end
            RefreshSwitchBlock(control)
        end,
    }
end

-- LAM's own divider fades out at both ends and stops short of the edges. This one is the same
-- line a block rules itself off with, run the whole way across the page.
local function PageRule(alpha)
    return {
        type = "custom",
        minHeight = 1,
        maxHeight = 4,
        createFunc = function(control)
            local rule = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
            rule:SetDimensions(control:GetWidth(), 1)
            rule:SetColor(IG.HexToRGB(SOFT))
            rule:SetAlpha(alpha or SWITCH_RULE_ALPHA)
            rule:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        end,
    }
end

local function Choice(name, description, key, labels, values, defaultLabel, apply)
    return {
        {
            type = "dropdown",
            name = Color(TEXT, name),
            tooltip = description,
            choices = labels,
            getFunc = function()
                for index, value in ipairs(values) do
                    if IG.sv[key] == value then return labels[index] end
                end
                return defaultLabel
            end,
            setFunc = function(choice)
                for index, label in ipairs(labels) do
                    if label == choice then IG.sv[key] = values[index] end
                end
                IG.NoteCustomTheme()
                if apply then apply() end
                IG.RefreshLists()
            end,
            default = defaultLabel,
        },
    }
end

---------------------------------------------------------------------------
-- Vendors & Crafting Stations: whether a merchant, a crafting bench and the like get our flat
-- layout or our grouping at all, one switch for all of a kind and one more per kind underneath.
---------------------------------------------------------------------------

local function NpcCategoryLive()
    return IG.sv.npcCategoryEnabled ~= false
end

local function CraftStationCategoryLive()
    return IG.sv.craftStationCategoryEnabled ~= false
end

local function VendorStationControls()
    local npcOptions = {
        {
            richName = Color(SECTION.behaviour, "NPCs (Merchant, Fence, Guild Store, Trade, Mail)"),
            description = "Selling, trading or mailing switches the bag to a flat, easy to sell "
                .. "from layout. Off: the bag keeps its usual grouping everywhere.",
            key = "npcCategoryEnabled",
            look = false,
        },
    }
    for _, kind in ipairs(IG.NPC_CATEGORY_TYPES) do
        npcOptions[#npcOptions + 1] = {
            name = kind.label,
            description = "Off: " .. kind.label .. " keeps the bag's usual grouping instead of the flat layout.",
            get = function() return IG.sv.npcCategoryTypes[kind.key] ~= false end,
            set = function(value) IG.sv.npcCategoryTypes[kind.key] = value or nil end,
            enabled = NpcCategoryLive,
            indent = true,
            look = false,
        }
    end

    local craftOptions = {
        {
            richName = Color(SECTION.behaviour, "CRAFTING STATIONS (Deconstruction, Improvement)"),
            description = "A bench's deconstruction and improvement lists are grouped the same "
                .. "way the bag is. Off: every bench is left exactly as the game draws it.",
            key = "craftStationCategoryEnabled",
            look = false,
        },
    }
    for _, kind in ipairs(IG.CRAFT_STATION_TYPES) do
        craftOptions[#craftOptions + 1] = {
            name = kind.label,
            description = "Off: " .. kind.label .. "'s own bench is left exactly as the game draws it.",
            get = function() return IG.sv.craftStationCategoryTypes[kind.key] ~= false end,
            set = function(value) IG.sv.craftStationCategoryTypes[kind.key] = value or nil end,
            enabled = CraftStationCategoryLive,
            indent = true,
            look = false,
        }
    end

    return {
        SwitchBlock(npcOptions, true),
        SwitchBlock(craftOptions, true),
    }
end

---------------------------------------------------------------------------
-- Category tables: animated notifications, and the groups that glow
---------------------------------------------------------------------------

-- Two settings are laid out the same way: a list of categories, each with a dot that starts or
-- stops it and a button or two for how it behaves, and under the list a button that puts another
-- category on it. One table builds both, told by a spec what it keeps and what its buttons cycle
-- through. The dot never takes a category off the list -- that is what the X is for -- and a
-- category switched off keeps what it was set to, so switching it back on picks that up again.

local TABLE_ROW_HEIGHT = 26
-- The game's own radio button draws the ring and lights it under the mouse, but its pressed
-- state leaves the middle empty, so the filled circle that says "on" is drawn on top of it.
local DOT_SIZE = 20
local FILL_SIZE = 12
-- The soft round glow the NEW header sweeps with. Drawn small it is a filled circle, and unlike
-- the bullet art it is one this addon already proves is there.
local FILL_TEXTURE = "EsoUI/Art/Miscellaneous/icon_highlight_pulse.dds"
-- Under the mouse the game lights its own dot in the middle of the ring; ours takes the same
-- color so the two read as one thing. Measured off the game rather than guessed.
local FILL_HOVER = "8ECDD0"
local COLUMN_WIDTH = 76
local COLUMN_HEIGHT = 22
local COLUMN_GAP = 8
local COLUMN_RIGHT = 4       -- the last column, from the right edge of the line
local REMOVE_COLOR = "FF5C5C"
local REMOVE_REST = 0.5      -- the X sits quietly next to the name until the mouse is on it
local REMOVE_WIDTH = 20
local REMOVE_HEIGHT = 16
local REMOVE_GAP = 10
local NAME_PAD = 14          -- how far past the longest name the column of Xs stands
local NAME_MIN = 120
local NAME_MAX = 220         -- a name longer than this is cut short instead of moving the column
local HEAD_FONT = "ZoFontWinH4"
local HEAD_COLOR = "F0A35C"
local NOTE_COLOR = "FFD84A" -- the page's own yellow: something to know, not something wrong
local NOTE_GAP = 12         -- from the end of the "Category" heading
local RULE_ALPHA = 0.14      -- between two categories
local HEAD_RULE_ALPHA = 0.45 -- under the column headings
local SPLIT_RULE_ALPHA = 0.5 -- between the list and the button that adds to it
local DIM_ALPHA = 0.4        -- the whole block while it is not yours to set

-- The way out of a menu, wherever one is shown from.
IG.CANCEL_LABEL = "|cFF5C5CCancel|r"

-- A menu is a window of its own: scroll the page under it and it hangs there over nothing. The
-- page's own wheel handler is left alone -- replacing it is how scrolling gets broken -- and the
-- menu simply watches where the page is while it is open. The watcher also remembers that the
-- menu is up, so that a second click on the button that opened it counts as a click away from it.
local function WatchMenu(owner)
    owner.igMenuOpen = true
    local scroll = IG.settingsPanel and IG.settingsPanel.scroll
    local openedAt = scroll and scroll:GetTop()
    owner:SetHandler("OnUpdate", function(self)
        local menuGone = not ZO_Menu or ZO_Menu:IsHidden()
        if menuGone or (scroll and scroll:GetTop() ~= openedAt) then
            if not menuGone then ClearMenu() end
            self.igMenuOpen = false
            self:SetHandler("OnUpdate", nil)
        end
    end)
end

local function ForgetMenu(owner)
    local wasOpen = owner.igMenuOpen
    owner.igMenuOpen = false
    owner:SetHandler("OnUpdate", nil)
    ClearMenu()
    return wasOpen
end

local STYLE_ORDER = { "shift", "pulse", "trace" }
local STYLE_LABELS = { shift = "Shift", pulse = "Pulse", trace = "Trace", none = "Off" }
-- Three names tell you nothing about what they look like, so each says so under the mouse.
local STYLE_TIPS = {
    shift = "A band of light sweeps across the category and starts over.",
    pulse = "The whole category brightens and fades where it stands.",
    trace = "A short light runs around the category's edge.",
}
local SPEED_ORDER = { "slow", "normal", "fast" }
local SPEED_LABELS = { slow = "Slow", normal = "Normal", fast = "Fast" }
local GLOW_ORDER = { "low", "medium", "strong" }
local GLOW_LABELS = { low = "Low", medium = "Medium", strong = "Strong", none = "Off" }
local GLOW_TIPS = {
    low = "A hint of color, only just above the categories around it.",
    medium = "The level every glowing category used to have.",
    strong = "As bright as NEW: the one the eye goes to first.",
}

-- What each table keeps and what its buttons cycle through. The first column is the one that
-- says whether a category is on at all: "none" there means off. Everything reaches into IG
-- through a function because this file is read before the one that fills IG in.
local ANIMATION_TABLE = {
    store = "animations",
    default = function(key) return IG.DEFAULT_ANIMATED[key] end,
    read = function(key) return IG.AnimationSetting(key) end,
    live = function() return IG.sv.animationsEnabled ~= false and IG.sv.animationsAdvanced == true end,
    -- Dimmed, the table looks switched off rather than not yours to set, and nothing on screen
    -- says the rows under it are still what plays. One word beside the heading does.
    note = function()
        if IG.sv.animationsEnabled == false or IG.sv.animationsAdvanced == true then return nil end
        return "showing the defaults"
    end,
    columns = {
        { heading = "Type", field = "style", order = STYLE_ORDER, labels = STYLE_LABELS,
          tips = STYLE_TIPS, fallback = "shift" },
        { heading = "Speed", field = "speed", order = SPEED_ORDER, labels = SPEED_LABELS,
          fallback = "normal" },
    },
}

local GLOW_TABLE = {
    store = "glows",
    default = function(key) return IG.DEFAULT_GLOW[key] end,
    read = function(key) return IG.GlowSetting(key) end,
    live = function() return IG.sv.specialSurfaces ~= false end,
    columns = {
        { heading = "Glow", field = "level", order = GLOW_ORDER, labels = GLOW_LABELS,
          tips = GLOW_TIPS, fallback = "medium" },
    },
}

local function Store(spec)
    IG.sv[spec.store] = IG.sv[spec.store] or {}
    return IG.sv[spec.store]
end

local function NextIn(order, current)
    for index, value in ipairs(order) do
        if value == current then return order[index % #order + 1] end
    end
    return order[1]
end

-- What a category is set to, one value per column.
local function Values(spec, key)
    local values = { spec.read(key) }
    for index, column in ipairs(spec.columns) do
        values[index] = values[index] or column.fallback
    end
    return values
end

-- Writes them back. "last" is what the category was set to before it was switched off.
local function Set(spec, key, values, last)
    local entry = Store(spec)[key] or {}
    for index, column in ipairs(spec.columns) do
        entry[column.field] = values[index]
    end
    if last then entry.last = last end
    Store(spec)[key] = entry
    IG.RefreshLists()
end

-- A category is on the list once it has been given a setting, or because it is one of the few
-- that start with one. Taking it off the list is what the dot does not do: the dot only stops it.
local function IsListed(spec, key)
    return Store(spec)[key] ~= nil or spec.default(key) ~= nil
end

local function ListedGroups(spec, wanted)
    local list = {}
    for _, group in ipairs(IG.GetOrderedGroups()) do
        if IsListed(spec, group.key) == wanted then list[#list + 1] = group end
    end
    return list
end

local function RemoveCategory(spec, key)
    Store(spec)[key] = nil
    IG.RefreshLists()
end

-- The dot in front of a category: on, or off with what it was kept for later.
local function ToggleCategory(spec, key)
    local values = Values(spec, key)
    if values[1] == "none" then
        local entry = Store(spec)[key]
        values[1] = (entry and entry.last) or spec.columns[1].fallback
        Set(spec, key, values)
    else
        local was = values[1]
        values[1] = "none"
        Set(spec, key, values, was)
    end
end

-- Columns are laid out from the right, in the order they are written.
local function ColumnRight(spec, index)
    return COLUMN_RIGHT + (#spec.columns - index) * (COLUMN_WIDTH + COLUMN_GAP)
end

local function RefreshRows(control)
    local spec = control.spec
    local live = spec.live()
    local shown = ListedGroups(spec, true)

    control:SetAlpha(live and 1 or DIM_ALPHA)
    if control.note then
        local note = spec.note()
        control.note:SetText(note and Color(NOTE_COLOR, note) or "")
    end
    for index, row in ipairs(control.rows) do
        local group = shown[index]
        row.key = group and group.key
        if group then
            local values = Values(spec, group.key)
            local on = values[1] ~= "none"
            row.name:SetText(Color(on and TEXT or SOFT, group.label))
            row.fill:SetHidden(not on)
            row.dot:SetEnabled(live)
            local permanent = spec.default(group.key) ~= nil
            row.remove:SetHidden(permanent)
            row.remove:SetMouseEnabled(live and not permanent)
            for columnIndex, column in ipairs(spec.columns) do
                local showing = values[columnIndex]
                if columnIndex == 1 and not on then
                    -- Off, the button still says what the category will go back to.
                    showing = (Store(spec)[group.key] or {}).last or spec.default(group.key)
                        or column.fallback
                end
                local button = row.buttons[columnIndex]
                button:SetText(column.labels[showing] or showing)
                button.tip = column.tips and column.tips[showing]
                button:SetEnabled(live and on)
            end
            row:SetAlpha(on and 1 or 0.6)
            row:SetHeight(TABLE_ROW_HEIGHT)
            row:SetHidden(false)
            row.rule:SetHidden(shown[index + 1] == nil)
        else
            row:SetHeight(0)
            row:SetHidden(true)
            row.rule:SetHidden(true)
        end
    end

    -- With the switch above it off the whole block stays exactly as it was, only dimmed: nothing
    -- moves or disappears, it simply is not yours to set right now.
    control.add:SetEnabled(live and #ListedGroups(spec, false) > 0)
end

-- Every X stands in the same column: the names all get one width, taken from the longest of
-- them, and a name too long for it is cut short rather than pushing the column along.
local function NameColumnWidth(parent)
    local probe = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    probe:SetFont(SWITCH_TEXT_FONT)
    probe:SetAnchor(LEFT, parent, LEFT, 0, 0)
    probe:SetAlpha(0)
    local widest = 0
    for _, group in ipairs(IG.GetOrderedGroups()) do
        probe:SetText(group.label or "")
        local measured = probe:GetTextWidth() or 0
        if measured > widest then widest = measured end
    end
    probe:SetHidden(true)
    return zo_clamp(zo_round(widest) + NAME_PAD, NAME_MIN, NAME_MAX)
end

-- A box drawn from four thin lines. The game's button virtuals bring frame art of their own, and
-- its bright edges read as a yellow line above and below the letter.
local function RemoveBox(parent)
    local edges = {}
    local function Edge(edgeWidth, edgeHeight, point)
        local edge = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
        edge:SetDimensions(edgeWidth, edgeHeight)
        edge:SetAnchor(point, parent, point, 0, 0)
        edges[#edges + 1] = edge
    end
    Edge(REMOVE_WIDTH, 1, TOPLEFT)
    Edge(REMOVE_WIDTH, 1, BOTTOMLEFT)
    Edge(1, REMOVE_HEIGHT, TOPLEFT)
    Edge(1, REMOVE_HEIGHT, TOPRIGHT)
    return edges
end

-- One line per category: a dot that stops or starts it, its name, and a button per column. A
-- heading row names the columns, and the button that puts another category on the list sits
-- under a heavier line of its own.
local function CategoryTable(spec)
    return {
        type = "custom",
        minHeight = TABLE_ROW_HEIGHT,
        maxHeight = 4000,
        refreshFunc = RefreshRows,
        createFunc = function(control)
            control.spec = spec
            local width = control:GetWidth()
            local nameWidth = NameColumnWidth(control)
            local removeR, removeG, removeB = IG.HexToRGB(REMOVE_COLOR)
            control.rows = {}

            local function Line(previous, height)
                local row = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
                row:SetWidth(width)
                row:SetHeight(height or TABLE_ROW_HEIGHT)
                if previous then
                    row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
                else
                    row:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
                end
                return row
            end

            local function Rule(previous, alpha, thickness)
                local rule = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
                rule:SetDimensions(width, thickness or 1)
                rule:SetColor(IG.HexToRGB(SOFT))
                rule:SetAlpha(alpha)
                rule:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
                return rule
            end

            local function Heading(row, text, offsetRight)
                local label = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
                label:SetFont(HEAD_FONT)
                label:SetText(Color(HEAD_COLOR, text))
                if offsetRight then
                    label:SetWidth(COLUMN_WIDTH)
                    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                    label:SetAnchor(RIGHT, row, RIGHT, -offsetRight, 0)
                else
                    label:SetAnchor(LEFT, row, LEFT, 0, 0)
                end
                return label
            end

            -- The column headings, and the line under them.
            local head = Line(nil)
            control.head = head
            local heading = Heading(head, "Category")
            if spec.note then
                control.note = WINDOW_MANAGER:CreateControl(nil, head, CT_LABEL)
                control.note:SetFont(SWITCH_TEXT_FONT)
                control.note:SetAnchor(LEFT, heading, RIGHT, NOTE_GAP, 0)
                control.note:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            end
            for index, column in ipairs(spec.columns) do
                Heading(head, column.heading, ColumnRight(spec, index))
            end
            local previous = Rule(head, HEAD_RULE_ALPHA, 2)

            for _ = 1, #IG.GROUPS do
                local row = Line(previous)

                row.dot = WINDOW_MANAGER:CreateControlFromVirtual(nil, row, "ZO_RadioButton")
                row.dot:SetDimensions(DOT_SIZE, DOT_SIZE)
                row.dot:SetAnchor(LEFT, row, LEFT, 0, 0)
                row.dot:SetHandler("OnClicked", function()
                    if not row.key or not spec.live() then return end
                    ToggleCategory(spec, row.key)
                    RefreshRows(control)
                end)

                -- Not mouse enabled, so every click still lands on the ring behind it.
                row.fill = WINDOW_MANAGER:CreateControl(nil, row.dot, CT_TEXTURE)
                row.fill:SetTexture(FILL_TEXTURE)
                row.fill:SetDesaturation(1) -- the art has a tint of its own; our color decides
                row.fill:SetDimensions(FILL_SIZE, FILL_SIZE)
                row.fill:SetAnchor(CENTER, row.dot, CENTER, 0, 0)
                row.fill:SetDrawLayer(DL_OVERLAY)
                row.fill:SetDrawLevel(5)
                row.fill:SetHidden(true)

                local function PaintFill(hovered)
                    row.fill:SetColor(IG.HexToRGB(hovered and FILL_HOVER or IG.DEFAULT_ICON_COLOR))
                end
                PaintFill(false)
                row.dot:SetHandler("OnMouseEnter", function() PaintFill(true) end)
                row.dot:SetHandler("OnMouseExit", function() PaintFill(false) end)

                row.name = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
                row.name:SetFont(SWITCH_TEXT_FONT)
                row.name:SetAnchor(LEFT, row.dot, RIGHT, 8, 0)
                row.name:SetWidth(nameWidth)
                row.name:SetMaxLineCount(1)
                row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

                row.remove = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
                row.remove:SetDimensions(REMOVE_WIDTH, REMOVE_HEIGHT)
                row.remove:SetAnchor(LEFT, row.name, RIGHT, REMOVE_GAP, 0)
                row.remove:SetMouseEnabled(true)
                row.remove.edges = RemoveBox(row.remove)

                row.remove.mark = WINDOW_MANAGER:CreateControl(nil, row.remove, CT_LABEL)
                row.remove.mark:SetFont(SWITCH_TEXT_FONT)
                row.remove.mark:SetText("X")
                row.remove.mark:SetAnchor(CENTER, row.remove, CENTER, 0, 0)

                local function PaintRemove(hovered)
                    local alpha = hovered and 1 or REMOVE_REST
                    for _, edge in ipairs(row.remove.edges) do
                        edge:SetColor(removeR, removeG, removeB, alpha)
                    end
                    row.remove.mark:SetColor(removeR, removeG, removeB, alpha)
                end
                PaintRemove(false)
                row.remove:SetHandler("OnMouseEnter", function() PaintRemove(true) end)
                row.remove:SetHandler("OnMouseExit", function() PaintRemove(false) end)
                row.remove:SetHandler("OnMouseUp", function(_, _, upInside)
                    if not upInside or not row.key or not spec.live() then return end
                    RemoveCategory(spec, row.key)
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    RefreshRows(control)
                end)

                row.buttons = {}
                for columnIndex, column in ipairs(spec.columns) do
                    local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, row, "ZO_DefaultButton")
                    button:SetDimensions(COLUMN_WIDTH, COLUMN_HEIGHT)
                    button:SetAnchor(RIGHT, row, RIGHT, -ColumnRight(spec, columnIndex), 0)
                    button:SetHandler("OnClicked", function()
                        if not row.key or not spec.live() then return end
                        local values = Values(spec, row.key)
                        values[columnIndex] = NextIn(column.order, values[columnIndex])
                        Set(spec, row.key, values)
                        RefreshRows(control)
                    end)

                    -- A name tells you nothing about what it looks like, so the ones that need
                    -- it say so under the mouse. The button lights itself there; that handler is
                    -- kept and the tooltip hung off the back of it rather than put in its place.
                    if column.tips then
                        local lit = button:GetHandler("OnMouseEnter")
                        local unlit = button:GetHandler("OnMouseExit")
                        button:SetHandler("OnMouseEnter", function(self)
                            if lit then lit(self) end
                            if self.tip then ZO_Tooltips_ShowTextTooltip(self, TOP, self.tip) end
                        end)
                        button:SetHandler("OnMouseExit", function(self)
                            if unlit then unlit(self) end
                            ZO_Tooltips_HideTextTooltip()
                        end)
                    end

                    row.buttons[columnIndex] = button
                end

                row.rule = Rule(row, RULE_ALPHA)
                control.rows[#control.rows + 1] = row
                previous = row.rule
            end

            -- A heavier line, then the button that opens the list of everything not on the list.
            local split = Rule(previous, SPLIT_RULE_ALPHA, 2)
            local addRow = Line(split, TABLE_ROW_HEIGHT + 4)
            control.add = WINDOW_MANAGER:CreateControlFromVirtual(nil, addRow, "ZO_DefaultButton")
            control.add:SetDimensions(160, COLUMN_HEIGHT)
            control.add:SetText("Add a category")
            control.add:SetAnchor(LEFT, addRow, LEFT, 0, 0)
            control.add:SetHandler("OnClicked", function(self)
                -- The menu is already up: this click is the one that puts it away.
                if ForgetMenu(self) then return end
                for _, group in ipairs(ListedGroups(spec, false)) do
                    AddMenuItem(group.label, function()
                        local values = {}
                        for index, column in ipairs(spec.columns) do values[index] = column.fallback end
                        Set(spec, group.key, values)
                        RefreshRows(control)
                    end)
                end
                AddMenuItem(IG.CANCEL_LABEL, function() end)
                ShowMenu(self)
                WatchMenu(self)
            end)

            RefreshRows(control)
        end,
    }
end

local function AnimationControls()
    return {
        SwitchBlock({
            {
                name = "Notification Animations",
                description = "A light plays on the categories that have something new in them.",
                key = "animationsEnabled",
                -- No theme has an opinion about what moves on the screen, so moving this is
                -- not a look of your own: the picker above keeps whatever it says.
                look = false,
            },
            {
                name = "Advanced",
                -- Off, the line says what plays instead, or the dimmed table below it reads as
                -- nothing playing at all. Both halves are one line long, so the page does not
                -- move when the switch does.
                description = function()
                    if IG.sv.animationsAdvanced == true then
                        return Color(SOFT, "Give each category its own animation and speed.")
                    end
                    return Color(SOFT, "Every category plays the animation it starts with.")
                end,
                key = "animationsAdvanced",
                look = false,
                enabled = function() return IG.sv.animationsEnabled ~= false end,
                -- Off, the table below is not yours to set, so it shows -- and plays -- what the
                -- addon starts with rather than settings nothing on screen says are in force.
                -- What was there is put aside and handed back the moment it is switched on again.
                onToggle = function(on)
                    if on then
                        IG.sv.animations = IG.sv.animationsKept or {}
                        IG.sv.animationsKept = nil
                    else
                        IG.sv.animationsKept = ZO_DeepTableCopy(IG.sv.animations or {})
                        IG.sv.animations = {}
                    end
                end,
            },
        }),
        CategoryTable(ANIMATION_TABLE),
    }
end

-- Which groups glow, and how much. The switch that turns the whole thing on sits with the other
-- button colors, one level up; this is the list behind it.
local function GlowControls()
    return { CategoryTable(GLOW_TABLE) }
end

-- The buttons the list is made of: one per category, each carrying a color of its own.
local function CategoryButtonControls()
    return {
        SwitchBlock({
            {
                name = "Category Button Background",
                description = "Fills category buttons with their color.",
                key = "headerSurfaces",
            },
            {
                name = "Individual Category Colors",
                richName = Color(TEXT, "Individual Category ") .. Rainbow("Colors"),
                description = "Every category gets its own color.",
                key = "groupColors",
            },
            {
                name = "Colored Groups",
                description = "Categories take shades of their heading's color. Off: each picks its "
                    .. "own. A color you set yourself always wins.",
                key = "coloredGroups",
                enabled = function() return IG.sv.groupColors ~= false end,
            },
            {
                name = "Glowing Groups",
                description = "A few groups get a brighter color (by default NEW, REWARDS and the modules).",
                key = "specialSurfaces",
            },
        }),
        {
            type = "submenu",
            name = Color(SECTION.look, "Which groups glow"),
            igBlurb = "How much each one stands out",
            controls = GlowControls(),
        },
    }
end

-- A set's own button. The markers come first: they are what it says about a set before any
-- color does, and they are what the colors below are taken from.
local function SetButtonControls()
    return {
        SwitchBlock({
            {
                name = "Role Markers",
                richName = Color(TEXT, "Role Markers") .. "  " .. RoleIcons(),
                description = "Damage, tank and support marks left of each set.",
                key = "showRoles",
            },
            {
                name = "Set Type Colors",
                richName = Color(TEXT, "Set Type ") .. Rainbow("Colors"),
                description = "Set buttons are colored by their roles.",
                key = "roleColors",
            },
        }),
    }
end

local function StyleControls()
    local controls = {
        SwitchBlock({
            {
                name = "Outlines",
                description = "Thin frames around groups and item rows.",
                key = "frames",
            },
            {
                name = "Color Strips",
                description = "A colored strip left of each header and under each open group.",
                key = "accentStrips",
            },
            -- The last of what the Backgrounds category held. A group's ground is drawn the way
            -- its edges are, so it belongs with them rather than in a category of its own.
            {
                name = "Category Background Fill",
                description = "An open category's contents are tinted in its color.",
                key = "groupSurface",
            },
            -- The last of what the Layout category held. One switch does not make a category,
            -- so it stands with the other three settings about how a row is drawn rather than
            -- off on its own. Its answer is one of three rather than yes or no, so it wears a
            -- button where the others wear their ON/OFF.
            {
                name = "Row height",
                description = "Height of header and gap rows. Item rows are not affected.",
                key = "rowDensity",
                pick = {
                    values = { "compact", "normal", "roomy" },
                    labels = { "Compact", "Normal", "Roomy" },
                    -- The rows have to be measured again before the lists are built from them.
                    apply = function() IG.ApplyRowDensity() end,
                },
            },
        }),
    }
    return controls
end

-- A theme's name is written in what it stands for: Full in every color there is, the two Quiets
-- in neighbouring greys so they read as a pair, Minimal plain, Custom in the page's own yellow.
local THEME_TINT = { quiet = "A8BACB", quietBlack = "7C8FA3", minimal = "EDEDF2", saved = "5AE0C8",
    custom = "FFD84A" }

local THEME_LABELS = {
    Rainbow("Full Colors"),
    Rainbow("Full Colors - Low Brightness", IG.LOW_BRIGHTNESS),
    Color(THEME_TINT.quiet, "Quiet"),
    Color(THEME_TINT.quietBlack, "Quiet Black"),
    Color(THEME_TINT.minimal, "Minimal"),
    Color(THEME_TINT.saved, "My Theme"),
}
local THEME_VALUES = { "full", "fullLow", "quiet", "quietBlack", "minimal", "saved" }

-- What a theme looks like is on screen in the preview, so the line beside the picker is given
-- to the one thing the preview cannot show: that picking one is not a small thing. It goes in
-- the empty run between the words and the box, so it costs the page no height at all.
local THEME_MODIFIED = "Modified. Save As My Theme to keep it."

-- Asked only when there is something to lose: a theme of your own is switches nobody can put
-- back, while one ready-made theme giving way to another costs nothing.
local THEME_DIALOG = "INVENTORY_GROUPING_THEME"
local pendingTheme

ESO_Dialogs[THEME_DIALOG] = {
    title = { text = "Use a quick theme?" },
    mainText = { text = "The switches you set by hand are written over by the theme you picked, "
        .. "and what you had is not kept." },
    buttons = {
        {
            text = SI_DIALOG_YES,
            callback = function()
                if pendingTheme then IG.ApplyTheme(pendingTheme) end
                pendingTheme = nil
            end,
        },
        {
            text = SI_DIALOG_NO,
            callback = function()
                pendingTheme = nil
                -- The box is showing the theme it was not allowed to change to.
                IG.RefreshSettingsPanel()
            end,
        },
    },
}

local function PickTheme(value)
    if IG.sv.theme ~= "custom" or value == "custom" then
        IG.ApplyTheme(value)
        return
    end
    pendingTheme = value
    ZO_Dialogs_ShowDialog(THEME_DIALOG)
end

-- The way in for the mark on the toolbar, which steps to the next look rather than picking one.
-- It goes through the same door the picker does, so the one question worth asking is still
-- asked: switches set by hand are not written over without a word.
function IG.CycleTheme()
    PickTheme(IG.NextTheme())
end

-- Built once the page exists, as a child of the picker itself: LAM hands out no widget that sits
-- beside another one, and a widget of its own below would be the stacked wall of text again.
-- Empty while the look is the theme the picker shows; amber once a switch has been moved by hand,
-- which is the one moment picking a theme would lose something.
function IG.UpdateThemeBlurb()
    local blurb = IG.themeBlurb
    if not blurb then return end
    blurb:SetText(IG.sv and IG.sv.theme == "custom" and Color("FFB627", THEME_MODIFIED) or "")
end

local function CreateThemeBlurb()
    local picker = InventoryGroupingThemePicker
    if IG.themeBlurb or not picker or not picker.container then return end

    local blurb = WINDOW_MANAGER:CreateControl(nil, picker, CT_LABEL)
    blurb:SetFont("ZoFontGameSmall")
    blurb:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    blurb:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    blurb:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    -- LAM's own label reaches all the way to the box, so the line is hung off the end of the
    -- word rather than off the end of the label, and stops short of the box.
    local label = picker.label
    blurb:SetAnchor(TOPLEFT, label, TOPLEFT, zo_max(label:GetTextWidth(), 60) + 16, 0)
    blurb:SetAnchor(BOTTOMRIGHT, picker.container, BOTTOMLEFT, -12, 0)
    IG.themeBlurb = blurb
    IG.UpdateThemeBlurb()
end

-- Which cone is missing. Each one is named the way the people who have it name it, with what
-- it costs in plainer words beside it.
local COLORBLIND_LABELS = {
    "Off",
    "Protanopia (red)",
    "Deuteranopia (green)",
    "Tritanopia (blue)",
}
local COLORBLIND_VALUES = { "off", "protanopia", "deuteranopia", "tritanopia" }

-- Offered whenever the categories wear colors of their own, since that is what it moves. It
-- used to follow the theme instead, which meant that moving any color switch by hand -- which
-- makes the theme "custom" -- quietly switched it off. Dimmed otherwise, holding its value.
local function ColorblindLive()
    return IG.sv.groupColors ~= false
end
local function ColorControls()
    return {
        {
            type = "dropdown",
            name = Color(TEXT, "Colorblind Mode"),
            choices = COLORBLIND_LABELS,
            choicesValues = COLORBLIND_VALUES,
            disabled = function() return not ColorblindLive() end,
            getFunc = function() return IG.sv.colorblind or "off" end,
            setFunc = function(value)
                IG.sv.colorblind = value
                -- Not one of a theme's switches, so moving it is not a theme of your own.
                IG.RefreshLists()
            end,
            default = COLORBLIND_VALUES[1],
        },
        PageRule(),
        {
            type = "submenu",
            name = Color(SECTION.look, "CATEGORY BUTTONS"),
            igBlurb = "The colors a category button wears",
            controls = CategoryButtonControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.sets, "SET EQUIPMENT BUTTONS"),
            igBlurb = "What a set button says about the set",
            controls = SetButtonControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.sets, "Set details"),
            igBlurb = "Pieces, where it drops, what is missing",
            controls = SetControls(),
        },
    }
end

-- Everything about how the lists are drawn. Each category inside keeps its own title; only the
-- heading over them is plain.
-- Built once by CreateSettingsPanel and handed down here so VISUALS can show them at its foot
-- instead of standing as two submenus of their own beside it, which was more than this page
-- needed to lead with.
local visualsIconSubmenus

local function VisualsControls()
    return {
        {
            type = "button",
            name = "Save As My Theme",
            tooltip = "Saves your current colors, surfaces, outlines, glows and animations as My "
                .. "Theme in Quick Themes. Replaces the one saved before. Rows / Chips / Tiles are "
                .. "kept on the LAYOUT page instead.",
            width = "full",
            func = function()
                IG.SaveCurrentLook()
                d("Inventory 2.0: Saved as My Theme. Quick Themes > My Theme brings it back.")
            end,
        },
        {
            type = "dropdown",
            reference = "InventoryGroupingThemePicker",
            name = Color(TEXT, "Quick Themes"),
            choices = THEME_LABELS,
            choicesValues = THEME_VALUES,
            getFunc = function()
                if IG.sv.theme == "custom" then return IG.sv.themeBase or THEME_VALUES[1] end
                return IG.sv.theme
            end,
            setFunc = PickTheme,
            default = THEME_VALUES[1],
        },
        PageRule(),
        {
            type = "submenu",
            name = Rainbow("COLORS"),
            igBlurb = "What wears which color",
            controls = ColorControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.orange, "STYLE"),
            igBlurb = "Outlines, strips and backgrounds",
            controls = StyleControls(),
        },
        {
            type = "submenu",
            name = ANIMATED_TITLE_STILL,
            igBlurb = "The light that says something is new",
            igAnimateTitle = true, -- picked up again once the page has been built (SetUpAccordion)
            controls = AnimationControls(),
        },
        PageRule(),
        { type = "header", name = Color(SECTION.yellow, "Icons") },
        visualsIconSubmenus[1],
        visualsIconSubmenus[2],
    }
end


-- General holds the sub-categories that are about the addon itself rather than about one list.
-- The Global Switch sits above everything else: one line that decides whether the addon runs at
-- all. Off, the game gets its own inventory back and not a hook of ours is installed; the page
-- below stays exactly as it is, so switching it on again picks up where you left off.
--
-- It only takes hold at load, so while the page says one thing and the running game another,
-- that is what the line under it says.
local function GlobalSwitchNote()
    local on = IG.sv.addonEnabled ~= false
    if IG.startedEnabled ~= nil and on ~= IG.startedEnabled then
        return Color("FFB627", "Reload the UI to make this take effect.")
    end
    if on then
        return Color(SOFT, "Shuts down the add-on entirely.")
    end
    return Color(SOFT, "The game's own inventory is running. Nothing here is lost.")
end

local function GlobalSwitchControls()
    return {
        SwitchBlock({
            {
                richName = Color("6BE06B", "GLOBAL SWITCH"),
                description = GlobalSwitchNote,
                key = "addonEnabled",
                look = false,
            },
        }, true),
    }
end

-- The two switches under Preview only mean anything while there is a preview to change.
local function PreviewLive()
    return IG.sv.previewEnabled ~= false
end

-- The threshold is the second half of one answer, so it is only the player's to set while the
-- first half is on. Dimmed otherwise, holding the number it was left at.
local function AutoSplitLive()
    return IG.sv.autoSplit == true
end

-- Offered as numbers and nothing else. "How many rows before this category sorts itself out"
-- is a number the player has in mind already, and a word standing in for one -- short, long,
-- very long -- would only have to be translated back into rows to be understood.
local SPLIT_OVER_VALUES = { 5, 10, 15, 20 }
local SPLIT_OVER_LABELS = { "5", "10", "15", "20" }

-- The sample bag beside this page, set apart in a colour of its own right under the Global
-- Switch: it is about this page, not about the lists.
local PREVIEW_COLOR = "5AA9FF"
local function PreviewControls()
    return {
        SwitchBlock({
            {
                richName = Color(PREVIEW_COLOR, "PREVIEW"),
                description = "A sample bag beside this page that shows your changes live.",
                key = "previewEnabled",
                -- It is a window on this page, not a look the lists have, so no theme owns it.
                look = false,
                onToggle = function(on) IG.SetPreviewShown(on) end,
            },
            {
                name = "Show My Current Settings",
                description = "Off: the sample shows everything, modules you have switched off "
                    .. "included. On: only what your bag actually has right now.",
                key = "previewRealOnly",
                enabled = PreviewLive,
                indent = true,
                guideColor = PREVIEW_COLOR,
                look = false,
            },
        }, "bottom"),
    }
end

-- LAYOUT: Rows / Chips / Tiles. Chosen per section from the bag itself (a line per section and
-- per list here would be a page of its own); this page says where, and keeps one saved copy.
-- Asked before it touches a choice made section by section, the same care the theme picker
-- takes before it overwrites a look set by hand.
local DISPLAY_LABEL = { rows = "Rows", chips = "Chips", tiles = "Tiles" }
local LAYOUT_SET_ALL_DIALOG = "INVENTORY_GROUPING_LAYOUT_SET_ALL"
local pendingDisplayMode

ESO_Dialogs[LAYOUT_SET_ALL_DIALOG] = {
    title = { text = "Set every section?" },
    mainText = { text = "" },
    buttons = {
        {
            text = SI_DIALOG_YES,
            callback = function()
                if pendingDisplayMode then
                    IG.SetAllSectionDisplays(pendingDisplayMode)
                    IG.RefreshLists()
                    d("Inventory 2.0: Every section set to " .. DISPLAY_LABEL[pendingDisplayMode] .. ".")
                end
                pendingDisplayMode = nil
            end,
        },
        { text = SI_DIALOG_NO, callback = function() pendingDisplayMode = nil end },
    },
}

local function ConfirmSetAllDisplay(mode)
    pendingDisplayMode = mode
    ESO_Dialogs[LAYOUT_SET_ALL_DIALOG].mainText.text = string.format(
        "Every section in every list switches to %s. The choice you made for any one section by "
            .. "hand is gone; Save Current Layout first if you want it back.", DISPLAY_LABEL[mode])
    ZO_Dialogs_ShowDialog(LAYOUT_SET_ALL_DIALOG)
end

local function LayoutControls()
    return {
        {
            type = "description",
            text = Color(TEXT, "Right-click a section heading in your bag, bank or station list to "
                .. "show it as Rows, Chips or Tiles.") .. "\n"
                .. Color(SOFT, "Every list keeps its own choice for every section."),
        },
        {
            type = "button",
            name = "Save Current Layout",
            tooltip = "Saves Rows / Chips / Tiles for every section of every list, and how sets "
                .. "are drawn in each category. Replaces the layout saved before.",
            width = "half",
            func = function()
                IG.SaveLayout()
                d("Inventory 2.0: Layout saved.")
            end,
        },
        {
            type = "button",
            name = "Restore Saved Layout",
            tooltip = "Puts every section back the way it was when you saved.",
            width = "half",
            disabled = function() return not IG.HasSavedLayout() end,
            func = function()
                if IG.RestoreLayout() then d("Inventory 2.0: Saved layout restored.") end
            end,
        },
        PageRule(),
        {
            type = "description",
            text = Color("FF4A3A", "Overwrites every section you set by hand.") .. "\n"
                .. Color(SOFT, "Save Current Layout first if you want a way back."),
        },
        {
            type = "button",
            name = "Set Everything To Rows",
            tooltip = "Every section, every list, drawn as plain rows.",
            width = "full",
            func = function() ConfirmSetAllDisplay("rows") end,
        },
        {
            type = "button",
            name = "Set Everything To Chips",
            tooltip = "Every section, every list, drawn as a row of chips.",
            width = "full",
            func = function() ConfirmSetAllDisplay("chips") end,
        },
        {
            type = "button",
            name = "Set Everything To Tiles",
            tooltip = "Every section, every list, drawn as a grid of tiles.",
            width = "full",
            func = function() ConfirmSetAllDisplay("tiles") end,
        },
    }
end

local function GeneralControls()
    local controls = GlobalSwitchControls()
    Append(controls, PreviewControls())
    Append(controls, { SwitchBlock({
        {
            name = "One Group Open At A Time",
            description = "Opening a group closes the others beside it.",
            key = "accordion",
            look = false,
        },
        {
            name = "Split Long Categories",
            description = "Flat lists like SELL, GARBAGE or JUNK get split into weapons, armour, "
                .. "treasure, materials once they grow past the length below.",
            key = "autoSplit",
            look = false,
        },
        {
            name = "Split Over",
            description = "Rows a category may hold before it splits.",
            key = "autoSplitOver",
            pick = { values = SPLIT_OVER_VALUES, labels = SPLIT_OVER_LABELS },
            enabled = AutoSplitLive,
            indent = true,
            look = false,
        },
    }, "bottom") })
    Append(controls, {
        {
            type = "dropdown",
            name = Color(TEXT, "Sort items by"),
            tooltip = "Item order inside every group. The button on the list's price header "
                .. "cycles it too.",
            choices = SortChoices(),
            getFunc = IG.SortLabel,
            setFunc = function(choice)
                for _, method in ipairs(IG.SORT_METHODS) do
                    if method.label == choice then IG.sv.sortBy = method.key end
                end
                IG.RefreshLists()
            end,
            default = "Name",
        },
    })
    return controls
end

-- What a row says beyond its name.
local function InfoShownControls()
    return {
        SwitchBlock({
            {
                name = "Category Counts",
                description = "(X) after a category's name: rows inside it.",
                key = "showCounts",
                look = false,
            },
            {
                name = "Total Items",
                description = "(Total: X): every item in the category, sub-groups included.",
                key = "showTotalItems",
                look = false,
            },
            {
                name = "Collected Items",
                description = "Under each set: how much of it you have collected, and how many "
                    .. "new slots your pieces could fill.",
                key = "showCollect",
            },
            {
                name = "Empty Groups",
                description = "Keeps every group on screen even when it holds nothing.",
                key = "showEmptyGroups",
                look = false,
            },
        }),
    }
end

---------------------------------------------------------------------------
-- Group customization: one group at a time, picked from the dropdown
---------------------------------------------------------------------------

local selectedGroup = IG.GROUPS[1].key

-- The dropdown lists the built-in names in their built-in order, so a group stays where the
-- player last saw it even after they rename it or move it; the new name shows in the box below.
-- Under another heading, and at the end of it: a category arriving in the middle of a run it
-- has never been in has no place it obviously belongs.
local function SendToSection(key, section)
    -- Moving and re-placing are one thing done, so they are taken back as one.
    IG.UndoStep(string.format("where %s stands", IG.MenuGroupName(key)), function()
        IG.SetGroupSetting(key, "section", section)
        local last = 0
        for _, group in ipairs(IG.GetOrderedGroups()) do
            if group.key ~= key and IG.GetGroupSection(group.key) == section then
                last = zo_max(last, IG.GetGroupOrder(group.key))
            end
        end
        IG.SetGroupSetting(key, "order", last + 1)
    end)
    IG.RefreshLists()
end

local function GroupChoices()
    local labels, byLabel = {}, {}
    for _, group in ipairs(IG.GetOrderedGroups()) do
        labels[#labels + 1] = group.label
        byLabel[group.label] = group.key
    end
    return labels, byLabel
end

-- Where the selected group currently sits in the list.
local function GroupPosition(key)
    for index, group in ipairs(IG.GetOrderedGroups()) do
        if group.key == key then return index end
    end
    return 1
end

local function RefreshPanel()
    CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", IG.settingsPanel)
    IG.UpdateThemeBlurb()
end

-- Switches further up the page decide whether the ones below them mean anything, so every switch
-- gives the whole page a chance to catch up.
function IG.RefreshSettingsPanel()
    RefreshPanel()
end

---------------------------------------------------------------------------
-- Themes: ready-made values for the Visuals switches
---------------------------------------------------------------------------

-- Everything a theme has an opinion about. A switch left out of this list is the player's alone
-- and survives every theme change.
-- flatGrouping and startExpanded have no switch of their own anywhere on the page: the one look
-- that wants them is Minimal, and every other theme is what puts them back.
local THEME_KEYS = {
    "groupColors", "roleColors",
    "headerSurfaces", "groupSurface", "specialSurfaces", "blackSurfaces", "frames", "accentStrips",
    "showRoles", "showPieces", "showLocation", "showCollect", "showSetTooltip",
    "flatGrouping", "startExpanded", "rowDensity", "lowBrightness",
}

local THEMES = {
    -- The complete look, and what the addon has always done.
    full = {
        groupColors = true, roleColors = true,
        headerSurfaces = true, groupSurface = true, specialSurfaces = true, blackSurfaces = false,
        frames = true, accentStrips = true,
        showRoles = true, showPieces = true, showLocation = true, showCollect = true,
        showSetTooltip = true,
        flatGrouping = false, startExpanded = false, rowDensity = "normal",
        lowBrightness = false,
    },
    -- The same look with every color taken down a step, for a screen the full one shouts on.
    -- Nothing else about it differs, so it is written as Full with the one switch moved.
    fullLow = {
        groupColors = true, roleColors = true,
        headerSurfaces = true, groupSurface = true, specialSurfaces = true, blackSurfaces = false,
        frames = true, accentStrips = true,
        showRoles = true, showPieces = true, showLocation = true, showCollect = true,
        showSetTooltip = true,
        flatGrouping = false, startExpanded = false, rowDensity = "normal",
        lowBrightness = true,
    },
    -- Same structure, same information, no color and no glass: the outlines and strips stay so the
    -- groups still have edges, but in ESO's own cream, on the game's own background.
    quiet = {
        groupColors = false, roleColors = false,
        headerSurfaces = false, groupSurface = false, specialSurfaces = false, blackSurfaces = false,
        frames = true, accentStrips = true,
        showRoles = true, showPieces = true, showLocation = true, showCollect = true,
        showSetTooltip = true,
        flatGrouping = false, startExpanded = false, rowDensity = "normal",
        lowBrightness = false,
    },
    -- Quiet again, but the headers stand on ink rather than on whatever the window is over.
    quietBlack = {
        groupColors = false, roleColors = false,
        headerSurfaces = true, groupSurface = true, specialSurfaces = false, blackSurfaces = true,
        frames = true, accentStrips = true,
        showRoles = true, showPieces = true, showLocation = true, showCollect = true,
        showSetTooltip = true,
        flatGrouping = false, startExpanded = false, rowDensity = "normal",
        lowBrightness = false,
    },
    -- One level and nothing drawn: every set its own category, the rest in six buckets, all open.
    minimal = {
        groupColors = false, roleColors = false,
        headerSurfaces = false, groupSurface = false, specialSurfaces = false, blackSurfaces = false,
        frames = false, accentStrips = false,
        showRoles = false, showPieces = false, showLocation = false, showCollect = false,
        showSetTooltip = false,
        flatGrouping = true, startExpanded = true, rowDensity = "normal",
        lowBrightness = false,
    },
}

-- The ring the toolbar's mark steps round, and the names to say them by without the mark-up the
-- picker writes them in. "Custom" is not in the ring and cannot be stepped onto: it is not a
-- look but the name for switches set by hand, and IG.ApplyTheme answers it by changing nothing,
-- so a press that landed there would read as a button that had failed. It is still where the
-- ring may be entered from, and the press that leaves it hands out the first look of all.
local THEME_RING = { "full", "fullLow", "quiet", "quietBlack", "minimal" }
local THEME_NAMES = {
    full = "Full Colors", fullLow = "Full Colors - Low Brightness", quiet = "Quiet",
    quietBlack = "Quiet Black", minimal = "Minimal", saved = "My Theme", custom = "Modified",
}

function IG.ThemeName(name)
    return THEME_NAMES[name or IG.sv.theme] or THEME_NAMES.custom
end

function IG.NextTheme()
    -- The saved look joins the ring once there is one.
    local ring = THEME_RING
    if type(IG.sv.savedLook) == "table" then
        ring = { unpack(THEME_RING) }
        ring[#ring + 1] = "saved"
    end
    for index, name in ipairs(ring) do
        if IG.sv.theme == name then return ring[index % #ring + 1] end
    end
    return ring[1]
end

-- Moving any of the switches by hand: the look is no longer the theme it was. The panel is told
-- once, when the theme actually changes, so the picker and the line under it keep up.
function IG.NoteCustomTheme()
    if IG.sv.theme == "custom" then return end
    IG.sv.theme = "custom"
    RefreshPanel()
end

-- My Theme: everything a theme sets, plus the rest of the look no ready-made theme touches --
-- the glow and animation of each category, colour families and colorblind mode. How sections
-- are laid out (Rows / Chips / Tiles) is not a look and is saved on its own (IG.SaveLayout).
-- One slot; saving again replaces it.
local LOOK_EXTRA_KEYS = { "coloredGroups", "colorblind", "animationsEnabled", "animationsAdvanced" }
local LOOK_TABLES = { "glows", "animations" }

-- LAYOUT: each list's Rows / Chips / Tiles per section and how sets are drawn in each category.
local LAYOUT_TABLES = { "sectionDisplay", "setViewLists" }

function IG.SaveLayout()
    if not IG.sv then return end
    local layout = {}
    for _, key in ipairs(LAYOUT_TABLES) do layout[key] = ZO_DeepTableCopy(IG.sv[key] or {}) end
    IG.sv.savedLayout = layout
    RefreshPanel()
end

function IG.HasSavedLayout()
    return IG.sv ~= nil and type(IG.sv.savedLayout) == "table"
end

function IG.RestoreLayout()
    if not IG.HasSavedLayout() then return false end
    for _, key in ipairs(LAYOUT_TABLES) do
        if type(IG.sv.savedLayout[key]) == "table" then IG.sv[key] = ZO_DeepTableCopy(IG.sv.savedLayout[key]) end
    end
    IG.RefreshLists()
    return true
end

function IG.SaveCurrentLook()
    if not IG.sv then return end
    local look = {}
    for _, key in ipairs(THEME_KEYS) do look[key] = IG.sv[key] end
    for _, key in ipairs(LOOK_EXTRA_KEYS) do look[key] = IG.sv[key] end
    for _, key in ipairs(LOOK_TABLES) do look[key] = ZO_DeepTableCopy(IG.sv[key] or {}) end
    IG.sv.savedLook = look
    -- What is on screen now is the saved look, so leaving it asks nothing.
    IG.sv.theme, IG.sv.themeBase = "saved", "saved"
    RefreshPanel()
end

local function ApplySavedLook()
    local look = IG.sv.savedLook
    if type(look) ~= "table" then
        IG.sv.theme = "custom"
        return
    end
    for _, key in ipairs(THEME_KEYS) do
        if look[key] ~= nil then IG.sv[key] = look[key] end
    end
    for _, key in ipairs(LOOK_EXTRA_KEYS) do
        if look[key] ~= nil then IG.sv[key] = look[key] end
    end
    for _, key in ipairs(LOOK_TABLES) do
        if type(look[key]) == "table" then IG.sv[key] = ZO_DeepTableCopy(look[key]) end
    end
    IG.sv.theme, IG.sv.themeBase = "saved", "saved"
    IG.ApplyRowDensity()
    IG.RefreshLists()
    RefreshPanel()
end

function IG.ApplyTheme(name)
    if name == "saved" then return ApplySavedLook() end
    local theme = THEMES[name]
    if not theme then
        -- "Custom" is a state, not an instruction: picking it changes nothing.
        IG.sv.theme = "custom"
        return
    end
    for _, key in ipairs(THEME_KEYS) do
        if theme[key] ~= nil then IG.sv[key] = theme[key] end
    end
    IG.sv.theme, IG.sv.themeBase = name, name
    IG.ApplyRowDensity()
    IG.RefreshLists()
    RefreshPanel()
end

-- Writes a plain 1..n order for every group, with one of them moved up or down.
local function MoveGroup(key, direction)
    -- One press is one step, however many categories had their number rewritten by it: the
    -- whole run is renumbered every time, and handing back only the one that moved would leave
    -- the rest holding numbers nobody asked for. A press that reaches the end of the run writes
    -- nothing, and a step with nothing in it is not kept (see Undo.lua).
    IG.UndoStep(string.format("where %s stands", IG.MenuGroupName(key)), function()
        local ordered = IG.GetOrderedGroups()
        for index, group in ipairs(ordered) do
            if group.key == key then
                local target = index + direction
                if target < 1 or target > #ordered then return end
                -- A run of categories is what a heading is over, so a category cannot be stepped
                -- out of its own: it would either take the heading with it or break the run in
                -- two. Sending it under another heading is what the picker beside these buttons
                -- is for.
                if IG.SectionsOn()
                    and IG.GetGroupSection(ordered[target].key) ~= IG.GetGroupSection(key) then
                    return
                end
                ordered[index], ordered[target] = ordered[target], ordered[index]
                break
            end
        end
        for index, group in ipairs(ordered) do IG.SetGroupSetting(group.key, "order", index) end
    end)
    IG.RefreshLists()
    RefreshPanel()
end

-- The two switches under the JUNK group only mean anything while there is a group to place.
local function JunkLive()
    return IG.sv.junkEnabled == true
end

-- The threshold is only yours to set while the thing that reads it is running. The two are not
-- tied to the JUNK group at all: junking stolen rubbish is worth having whether or not you want
-- the pile listed back in your bag.
local function JunkStolenLive()
    return IG.sv.junkStolenEnabled == true
end

-- Gold is not offered: a threshold of "below gold" would junk a stolen legendary, which is
-- nobody's intent, and the piece a fence pays most for is the last one to throw away.
local STOLEN_QUALITY_VALUES = {
    ITEM_QUALITY_TRASH, ITEM_QUALITY_NORMAL, ITEM_QUALITY_MAGIC,
    ITEM_QUALITY_ARCANE, ITEM_QUALITY_ARTIFACT,
}
local STOLEN_QUALITY_LABELS = { "Grey", "White", "Green", "Blue", "Purple" }

-- A family can only be put back together while categorisation is off, so rather than leave a
-- dimmed switch to explain itself, the line under it says which of the two it is waiting on.
local function MergeNote(whenFree)
    return function()
        if IG.sv.sections ~= false then
            return Color(SECTION.modules, "Categorization is on, so these stay apart.")
        end
        return Color(SOFT, whenFree)
    end
end

local function MergeLive()
    return IG.sv.sections == false
end

-- Defined below: the page only asks for it once, while it is being built.
local GroupEditorControls

local function CategorizationControls()
    return {
        {
            type = "description",
            text = Color(SOFT, "Right-click a category in your bag to group or ungroup its sets "
                .. "(Group Sets / Don't Group Sets)."),
        },
        SwitchBlock({
            {
                name = "Categorization",
                description = "Splits the list into parts under headings (modules, gear, "
                    .. "consumables and so on).",
                key = "sections",
                look = false,
            },
            -- Group Sets / Don't Group Sets is chosen per category from its right click in the
            -- bag (InventoryGrouping.lua, AddSetViewItems), so there is no switch for it here;
            -- a category never asked keeps the default (sv.setRules). What a set's line says is
            -- the same everywhere, so that one stays a switch.
            {
                name = "Detailed Set Lines",
                description = "Where sets are not grouped, each set line also shows piece count, "
                    .. "roles, drop location and collection.",
                key = "setRuleDetails",
                look = false,
            },
        }, true),
        SwitchBlock({
            {
                name = "Keep PVE Sets Together",
                description = MergeNote("Dungeon, arena and trial sets share one PVE SETS "
                    .. "category."),
                key = "mergePveSets",
                enabled = MergeLive,
                look = false,
            },
            {
                name = "Keep Consumables Together",
                description = MergeNote("Potions, poisons, food and scrolls share one "
                    .. "CONSUMABLES category."),
                key = "mergeConsumables",
                enabled = MergeLive,
                look = false,
            },
            {
                name = "Keep World Together",
                description = MergeNote("Resources, scribing, appearance and trophies share one "
                    .. "WORLD category."),
                key = "mergeWorld",
                enabled = MergeLive,
                look = false,
            },
            {
                name = "Split PVP Sets By Instance",
                description = "Cyrodiil, Imperial City and battlegrounds each get a heading "
                    .. "inside PVP SETS.",
                key = "pvpByInstance",
                look = false,
            },
        }, true),
    }
end

-- Two titles to open, and neither of them is a subject the way COLORS or Modules is: one is how
-- the list is read in parts, the other is one category at a time. They wear plain white for
-- that reason, and the accents are left to the categories that name a thing.
local function BoostControls()
    local switches = {}
    for _, kind in ipairs(IG.BOOST_KINDS) do
        local key = kind.key
        switches[#switches + 1] = {
            name = kind.label,
            -- Lettered in the colour the category wears, so the page says which heading in the
            -- list each line is about rather than only naming it.
            richName = Color(IG.GetGroupColor(key), kind.label),
            description = kind.blurb .. " Off: a heading inside BOOSTS.",
            look = false,
            -- Not a setting of its own: one entry in the table of kinds that were asked for.
            get = function() return IG.IsBoostSplit(key) end,
            set = function(value) IG.SetBoostSplit(key, value) end,
        }
    end

    return {
        {
            type = "description",
            text = Color(SOFT, "Switch a kind on to move it out of BOOSTS into a category of "
                .. "its own."),
        },
        SwitchBlock(switches, true),
    }
end

local function GroupControls()
    return {
        {
            type = "submenu",
            name = Color(SECTION.white, "Categorization"),
            igBlurb = "Headings over the list, and what stays apart",
            controls = CategorizationControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.white, "Name, color, order"),
            igBlurb = "One category at a time",
            controls = GroupEditorControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.groups, "BOOSTS"),
            igBlurb = "What stands inside it, and what stands on its own",
            controls = BoostControls(),
        },
    }
end

-- One category at a time: what it is called, what colour it wears, which heading it is read
-- under and where it stands in that run.
function GroupEditorControls()
    local labels = GroupChoices()
    return {
        {
            type = "description",
            text = Color(SOFT, "Faster in the bag: right-click any category to rename or "
                .. "recolor it. Heading and order are set here."),
        },
        {
            type = "dropdown",
            name = Color(TEXT, "Group"),
            choices = labels,
            scrollable = true,
            width = "half",
            getFunc = function() return IG.GROUP_BY_KEY[selectedGroup].label end,
            setFunc = function(label)
                local _, byLabel = GroupChoices()
                selectedGroup = byLabel[label] or selectedGroup
                RefreshPanel()
            end,
        },
        {
            type = "description",
            width = "half",
            text = function()
                return Color(SOFT, string.format("Shown as |c%s%s|r, %d of %d in the list.",
                    IG.GetGroupColor(selectedGroup), IG.GetGroupLabel(selectedGroup),
                    GroupPosition(selectedGroup), #IG.GetOrderedGroups()))
            end,
        },
        {
            type = "editbox",
            name = Color(TEXT, "Name"),
            width = "half",
            getFunc = function() return IG.GetGroupLabel(selectedGroup) end,
            setFunc = function(value)
                value = zo_strtrim(value)
                IG.UndoStep(string.format("the name of %s", IG.MenuGroupName(selectedGroup)),
                    function()
                        IG.SetGroupSetting(selectedGroup, "name", value ~= "" and value or nil)
                    end)
                IG.RefreshLists()
                RefreshPanel()
            end,
        },
        {
            type = "colorpicker",
            name = Color(TEXT, "Color"),
            width = "half",
            getFunc = function() return IG.HexToRGB(IG.GetGroupColor(selectedGroup)) end,
            setFunc = function(r, g, b)
                IG.UndoStep(string.format("the colour of %s", IG.MenuGroupName(selectedGroup)),
                    function()
                        IG.SetGroupSetting(selectedGroup, "color", IG.RGBToHex(r, g, b))
                    end)
                IG.RefreshLists()
            end,
        },
        {
            type = "dropdown",
            name = Color(TEXT, "Heading"),
            width = "full",
            choices = IG.SECTION_ORDER,
            disabled = function() return not IG.SectionsOn() end,
            getFunc = function() return IG.GetGroupSection(selectedGroup) end,
            setFunc = function(value)
                SendToSection(selectedGroup, value)
                RefreshPanel()
            end,
        },
        PageRule(),
        {
            type = "button",
            name = "Move up",
            width = "half",
            func = function() MoveGroup(selectedGroup, -1) end,
        },
        {
            type = "button",
            name = "Move down",
            width = "half",
            func = function() MoveGroup(selectedGroup, 1) end,
        },
        PageRule(),
        {
            type = "button",
            name = "Reset this group",
            width = "half",
            func = function()
                IG.sv.groups[selectedGroup] = nil
                IG.RefreshLists()
                RefreshPanel()
            end,
        },
        {
            type = "button",
            name = "Reset every group",
            width = "half",
            isDangerous = true,
            func = function()
                ZO_ClearTable(IG.sv.groups)
                IG.RefreshLists()
                RefreshPanel()
            end,
        },
    }
end

---------------------------------------------------------------------------
-- About block at the top of the settings page
---------------------------------------------------------------------------

-- The addon's author, reached in game by mail (mail only reaches players on the same server).
IG.AUTHOR = "@blekays"
IG.AUTHOR_SERVER = "PC"

-- Read with IG.S() from inside CreateAboutBlock, not as a top-level local here: a local computed
-- at this file's own parse time runs before IG.sv exists (see the note at the top of
-- Strings.lua), so it could only ever answer in the client's own language, never a hand-picked
-- languageOverride.
local PITCH_KEY = "ABOUT_PITCH"
local PITCH_POINT_KEYS = { "ABOUT_PITCH_1", "ABOUT_PITCH_2", "ABOUT_PITCH_3", "ABOUT_PITCH_4" }

-- The icon of the "Reinfyr's Hero" achievement, found by name; the bag icon if it can't be found.
-- The logo is an achievement icon, which is round art on a transparent square. A thin border of
-- its own puts a frame around it so it reads as the addon's mark, not as loose art on the page.
local LOGO_OUTLINE = 2

-- Shared with Tutorial.lua, which frames its own small logo the same way: a thin outline drawn
-- as four edge textures in the target's parent, since a control cannot draw a border on itself.
function IG.AddOutline(target, thickness, color)
    local parent = target:GetParent()
    local r, g, b = IG.HexToRGB(color)
    local function Edge(point, relative, offsetX, offsetY, point2, relative2, offsetX2, offsetY2)
        local line = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
        line:SetColor(r, g, b, 1)
        line:SetAnchor(point, target, relative, offsetX, offsetY)
        line:SetAnchor(point2, target, relative2, offsetX2, offsetY2)
        return line
    end
    local t = thickness
    Edge(BOTTOMLEFT, TOPLEFT, -t, 0, BOTTOMRIGHT, TOPRIGHT, t, 0):SetHeight(t)
    Edge(TOPLEFT, BOTTOMLEFT, -t, 0, TOPRIGHT, BOTTOMRIGHT, t, 0):SetHeight(t)
    Edge(TOPRIGHT, TOPLEFT, 0, -t, BOTTOMRIGHT, BOTTOMLEFT, 0, t):SetWidth(t)
    Edge(TOPLEFT, TOPRIGHT, 0, -t, BOTTOMLEFT, BOTTOMRIGHT, 0, t):SetWidth(t)
end

-- Shared with Tutorial.lua, so both of the addon's own logos name the same achievement.
IG.LOGO_ACHIEVEMENT = "Loot Sanitizer"
IG.FALLBACK_LOGO = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds"
local LOGO_ACHIEVEMENT = IG.LOGO_ACHIEVEMENT
local FALLBACK_LOGO = IG.FALLBACK_LOGO

-- Hands every achievement's name and icon to the visitor. A visitor that returns something stops
-- the walk, and that value comes back out.
local function ForEachAchievement(visit)
    -- An index gives the first achievement of a line ("Treasure Hunter I, II, III"); the rest are
    -- only reachable by stepping along it, and they carry their own art.
    local function AtLine(achievementId)
        local steps = 0
        while achievementId and achievementId ~= 0 and steps < 20 do
            local name, _, _, icon = GetAchievementInfo(achievementId)
            if name and name ~= "" then
                local found = visit(zo_strformat("<<1>>", name), icon)
                if found then return found end
            end
            achievementId = GetNextAchievementInLine and GetNextAchievementInLine(achievementId)
            steps = steps + 1
        end
    end
    for top = 1, GetNumAchievementCategories() do
        local _, numSubCategories, numAchievements = GetAchievementCategoryInfo(top)
        for index = 1, numAchievements do
            local found = AtLine(GetAchievementId(top, nil, index))
            if found then return found end
        end
        for sub = 1, numSubCategories do
            local _, numSubAchievements = GetAchievementSubCategoryInfo(top, sub)
            for index = 1, numSubAchievements do
                local found = AtLine(GetAchievementId(top, sub, index))
                if found then return found end
            end
        end
    end
end

-- Shared with Tutorial.lua, which puts the same achievement icon in its own small header.
function IG.FindAchievementIcon(achievementName)
    return ForEachAchievement(function(name, icon)
        if name == achievementName then return icon end
    end)
end

local function OpenMailToAuthor(subject)
    if ComposeMail then
        ComposeMail(IG.AUTHOR, subject, "")
    else
        SCENE_MANAGER:Show("mailSend")
        zo_callLater(function()
            ZO_MailSendToField:SetText(IG.AUTHOR)
            ZO_MailSendSubjectField:SetText(subject)
        end, 200)
    end
end

local BUTTON_HEIGHT = 28
-- Declared here, ahead of Button(), rather than down by ABOUT_BUTTONS where it used to live:
-- Button() reads it at call time, but Lua resolves a bare name against whatever local scope is
-- open at the point a function's BODY is written, not where it is later called from. A `local`
-- further down the file is invisible to an earlier function -- it would see the name as an
-- unset global and hand SetDimensions a nil width -- so the width every button and the language
-- box line up on has to be declared before the first thing that reads it.
local ABOUT_COLUMN_WIDTH = 170     -- the button column down the right, and every entry in it
-- Moved up here with ABOUT_COLUMN_WIDTH for the same reason: Button() reads it, so it has to be
-- declared before Button() is, not down by the version plate where it used to live alone.
local VERSION_FILL = "12121A"

-- ZO_DefaultButton on its own is bare text that fades at its edges -- standing next to the
-- language box's own real border it read as a different, smaller control even at the same
-- width. A plate behind the text (the same dark fill and thin gold outline the logo and version
-- plate already wear) gives every entry in this column the one frame, so all four read as the
-- same kind of thing at a glance.
local function Button(parent, text, onClick, color)
    local plate = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    plate:SetDimensions(ABOUT_COLUMN_WIDTH, BUTTON_HEIGHT)
    plate:SetColor(IG.HexToRGB(VERSION_FILL))
    IG.AddOutline(plate, LOGO_OUTLINE, IG.DEFAULT_ICON_COLOR)

    local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, parent, "ZO_DefaultButton")
    button:SetText(text)
    button:SetAnchorFill(plate)
    button:SetHandler("OnClicked", onClick)
    if color then
        local r, g, b = IG.HexToRGB(color)
        button:SetNormalFontColor(r, g, b, 1)
        button:SetMouseOverFontColor(1, 1, 1, 1)
        button:SetPressedFontColor(r, g, b, 1)
    end
    return plate
end

-- Changing the language takes a UI reload to actually swap every string over (anything already
-- built -- the open settings page itself included -- was built in the old language and nothing
-- here walks the whole UI tree repainting it). Asked first rather than done the moment the
-- dropdown closes, the same way Reset Everything is asked first.
local LANGUAGE_RELOAD_DIALOG = "INVENTORY_GROUPING_LANGUAGE_RELOAD"

ESO_Dialogs[LANGUAGE_RELOAD_DIALOG] = {
    title = { text = function() return IG.S("LANGUAGE_RELOAD_TITLE") end },
    mainText = { text = function(dialog) return dialog.data.body end },
    buttons = {
        { text = SI_DIALOG_YES, callback = function(dialog) dialog.data.apply() end },
        { text = SI_DIALOG_NO, callback = function(dialog) dialog.data.cancel() end },
    },
}

-- Icon (as wide as the "Quick actions" heading), the pitch right next to it, author on the right.
-- The buttons down the right of the About block. The first opens a mail to the author; `special`
-- marks the one entry that is not a button at all (a language dropdown, built by hand in the loop
-- below) so it can share the same column and the same even spacing as the real buttons.
local ABOUT_BUTTONS = {
    { special = "language" },
    { stringKey = "ABOUT_HELP_BUG_REPORT", subject = "Help / Bug Report" },
    { stringKey = "ABOUT_SUPPORT", subject = "Donation", color = "5CE07A" },
    { stringKey = "ABOUT_RESET", confirm = true, color = "FF5C5C" },
}
local ABOUT_BUTTON_GAP = 10        -- the least room between two of them
local ABOUT_TEXT_GAP = 14          -- logo to the pitch beside it
-- ZoFontWinH1 draws its capitals well below the top of its line, so the title is lifted by the
-- difference: what lines up with the top of the logo is the lettering, not the box around it.
local ABOUT_TITLE_LIFT = 7
local VERSION_GAP = 10             -- logo to the plate under it
local VERSION_MIN_HEIGHT = 26

-- A real ZO_ComboBox (the control LibAddonMenu's own dropdowns are built from) standing in the
-- button column, the same ABOUT_COLUMN_WIDTH every button there is. Clicking it drops its own
-- list immediately below itself, which is what "click Language, a list opens under it" means in
-- practice -- no custom popup needed. A small label sits above the box (within the gap the layout
-- already leaves between two entries) so the bare face text -- just the language's own name, no
-- "Language:" running head that used to overflow the box at its widest entries -- still reads as
-- what it is. The list itself offers just the short names, set with SetSelectedItemText so the
-- two can differ without one selection event overwriting it.
local LANGUAGE_LABEL_HEIGHT = 14
local LANGUAGE_LABEL_GAP = 2
-- What the language entry stands taller than a plain button by: its own heading plus the gap
-- down to the box. Both the content height below and the per-entry spacing have to carry this,
-- or the stack runs this many pixels past the block's own bottom.
local LANGUAGE_EXTRA_HEIGHT = LANGUAGE_LABEL_HEIGHT + LANGUAGE_LABEL_GAP

-- Returns a container the height of the label plus the box, not the box itself: CreateAboutBlock
-- anchors whatever this hands back both to the entry above it AND as the entry the one below it
-- hangs from. A plain label's own bottom is the label's bottom, not the box's -- handing that back
-- would leave the box hanging below the next entry's top instead of above it. The container's own
-- top and bottom cover both, so the chain above and below it lands exactly where it does for any
-- plain button.
local function CreateLanguageDropdown(parent)
    local group = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    group:SetDimensions(ABOUT_COLUMN_WIDTH, LANGUAGE_EXTRA_HEIGHT + BUTTON_HEIGHT)

    local heading = WINDOW_MANAGER:CreateControl(nil, group, CT_LABEL)
    heading:SetFont("ZoFontGameSmall")
    heading:SetText(Color(SOFT, IG.S("LANGUAGE_LABEL")))
    heading:SetAnchor(TOPLEFT, group, TOPLEFT, 0, 0)
    heading:SetHeight(LANGUAGE_LABEL_HEIGHT)

    local control = WINDOW_MANAGER:CreateControlFromVirtual(nil, group, "ZO_ComboBox")
    control:SetDimensions(ABOUT_COLUMN_WIDTH, BUTTON_HEIGHT)
    control:SetAnchor(TOPLEFT, heading, BOTTOMLEFT, 0, LANGUAGE_LABEL_GAP)
    local box = ZO_ComboBox_ObjectFromContainer(control)
    box:SetSortsItems(false)

    local function FaceText(label) return IG.S("LANGUAGE_PREFIX") .. label end

    local function CurrentFaceText()
        for _, lang in ipairs(IG.LANGUAGES) do
            if lang.code == IG.sv.languageOverride then return FaceText(lang.label) end
        end
        return FaceText(IG.LANGUAGES[1].label)
    end

    for _, lang in ipairs(IG.LANGUAGES) do
        local code, label = lang.code, lang.label
        local function OnPicked()
            if code == IG.sv.languageOverride then return end
            ZO_Dialogs_ShowDialog(LANGUAGE_RELOAD_DIALOG, {
                body = string.format(IG.S("LANGUAGE_RELOAD_BODY"), label),
                apply = function()
                    IG.sv.languageOverride = code
                    ReloadUI()
                end,
                -- The combobox has already swapped its own face to the clicked label by the time
                -- this runs (that is ZO_ComboBox's own behaviour, not ours); saying No puts the
                -- real current language's face back rather than leaving a label standing for a
                -- language nothing was ever switched to.
                cancel = function() box:SetSelectedItemText(CurrentFaceText()) end,
            })
        end
        local item = box:CreateItemEntry(label, OnPicked)
        box:AddItem(item)
    end
    box:SetSelectedItemText(CurrentFaceText())
    return group
end

-- Logo top left, the pitch beside it, the buttons down the right. The pitch is the tallest of
-- the three and sets the height of the whole block; the other two are stretched to match it, the
-- logo by the version plate under it and the buttons by the air between them. So all three
-- columns start at the top of the logo and end on the same line.
local function CreateAboutBlock(block)
    local logoSize = 112

    local logo = WINDOW_MANAGER:CreateControl(nil, block, CT_TEXTURE)
    logo:SetDimensions(logoSize, logoSize)
    logo:SetAnchor(TOPLEFT, block, TOPLEFT, LOGO_OUTLINE, LOGO_OUTLINE)
    logo:SetTexture(IG.FindAchievementIcon(LOGO_ACHIEVEMENT) or FALLBACK_LOGO)
    IG.AddOutline(logo, LOGO_OUTLINE, IG.DEFAULT_ICON_COLOR)

    local textWidth = block:GetWidth() - logoSize - ABOUT_TEXT_GAP - ABOUT_COLUMN_WIDTH - 16

    local title = WINDOW_MANAGER:CreateControl(nil, block, CT_LABEL)
    title:SetFont("ZoFontWinH1")
    title:SetText(Color("E8D5A9", IG.DISPLAY_NAME))
    title:SetAnchor(TOPLEFT, logo, TOPRIGHT, ABOUT_TEXT_GAP, -ABOUT_TITLE_LIFT)

    local pitch = WINDOW_MANAGER:CreateControl(nil, block, CT_LABEL)
    pitch:SetFont("ZoFontGame")
    pitch:SetText(Color("D8D8DE", IG.S(PITCH_KEY)))
    pitch:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 4)
    pitch:SetWidth(textWidth)

    local previous = pitch
    for _, pointKey in ipairs(PITCH_POINT_KEYS) do
        local line = WINDOW_MANAGER:CreateControl(nil, block, CT_LABEL)
        line:SetFont("ZoFontGameSmall")
        line:SetText(Color(SOFT, "\194\183 " .. IG.S(pointKey)))
        line:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 2)
        line:SetWidth(textWidth)
        previous = line
    end

    -- How far the text reaches below the top of the logo, and what the other two columns need.
    local textHeight = title:GetTextHeight() + 4 + pitch:GetTextHeight()
        + #PITCH_POINT_KEYS * (previous:GetTextHeight() + 2) - ABOUT_TITLE_LIFT
    local buttonsHeight = #ABOUT_BUTTONS * BUTTON_HEIGHT + (#ABOUT_BUTTONS - 1) * ABOUT_BUTTON_GAP
        + LANGUAGE_EXTRA_HEIGHT
    local logoHeight = logoSize + VERSION_GAP + VERSION_MIN_HEIGHT
    local contentHeight = zo_max(textHeight, zo_max(buttonsHeight, logoHeight))

    -- The logo is square and the column is not: the rest of it says which version this is.
    local plate = WINDOW_MANAGER:CreateControl(nil, block, CT_TEXTURE)
    plate:SetColor(IG.HexToRGB(VERSION_FILL))
    plate:SetDimensions(logoSize, contentHeight - logoSize - VERSION_GAP)
    plate:SetAnchor(TOPLEFT, logo, BOTTOMLEFT, 0, VERSION_GAP)
    IG.AddOutline(plate, LOGO_OUTLINE, IG.DEFAULT_ICON_COLOR)

    local version = WINDOW_MANAGER:CreateControl(nil, block, CT_LABEL)
    version:SetFont("ZoFontGameSmall")
    version:SetText(Color(IG.DEFAULT_ICON_COLOR, "Version " .. IG.VERSION))
    version:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    version:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    version:SetAnchorFill(plate)

    -- The buttons take the air between them from whatever is left over.
    local author = WINDOW_MANAGER:CreateControl(nil, block, CT_CONTROL)
    author:SetDimensions(ABOUT_COLUMN_WIDTH, contentHeight)
    author:SetAnchor(TOPRIGHT, block, TOPRIGHT, 0, LOGO_OUTLINE)
    local gap = (contentHeight - #ABOUT_BUTTONS * BUTTON_HEIGHT - LANGUAGE_EXTRA_HEIGHT)
        / (#ABOUT_BUTTONS - 1)
    local above
    for _, entry in ipairs(ABOUT_BUTTONS) do
        local widget
        if entry.special == "language" then
            widget = CreateLanguageDropdown(author)
        else
            widget = Button(author, IG.S(entry.stringKey), entry.confirm and ConfirmReset or function()
                OpenMailToAuthor(IG.DISPLAY_NAME .. " - " .. entry.subject)
            end, entry.color)
        end
        if above then
            widget:SetAnchor(TOPLEFT, above, BOTTOMLEFT, 0, gap)
        else
            widget:SetAnchor(TOPLEFT, author, TOPLEFT, 0, 0)
        end
        above = widget
    end

    block:SetHeight(contentHeight + LOGO_OUTLINE * 2)
end

---------------------------------------------------------------------------
-- Settings page
---------------------------------------------------------------------------

-- Every category is named before the page is built, so the control the library makes for it can
-- be found again by that name. Walking the page for them is what this used to do, and it came
-- back with nothing every time: the library hands its widgets to a scroll child of its own and
-- moves some of them again afterwards, so what sits under the page at any one moment is its
-- business. A name it is handed is ours, and `reference` is what it names the control.
local CATEGORY_NAME = "InventoryGroupingCategory"
local categoryCount = 0

local function NameCategories(list)
    for _, entry in ipairs(list) do
        if entry.type == "submenu" then
            categoryCount = categoryCount + 1
            entry.reference = entry.reference or (CATEGORY_NAME .. categoryCount)
            if entry.controls then NameCategories(entry.controls) end
        end
    end
end

-- The categories standing side by side in one list, as controls, in the order they are read in.
-- One that failed to build is simply not there.
local function CategoriesIn(list)
    local submenus = {}
    for _, entry in ipairs(list) do
        if entry.type == "submenu" and entry.reference then
            local control = _G[entry.reference]
            if control then submenus[#submenus + 1] = control end
        end
    end
    return submenus
end

-- A line beside a category's title saying what is inside it, so the page can be read without
-- opening anything. It hangs off the end of the title rather than off the label, which runs the
-- width of the page, and stops short of the arrow. Categories without one simply go without:
-- a title that already says everything (Where the addon works) gains nothing from a second line.
-- ZoFontGameSmall is 14, and this is that a tenth larger.
local BLURB_FONT = "$(MEDIUM_FONT)|15|soft-shadow-thin"
local BLURB_MARK = "> "       -- in front of every one, so the line reads as an aside
local BLURB_GAP = 14          -- from the last letter of the title
local BLURB_ARROW_ROOM = 34   -- kept clear on the right for the arrow
local BLURB_MIN_TITLE = 60    -- a title measured before it is drawn comes back at nothing

local function AddBlurb(submenu)
    local label, text = submenu.label, submenu.data.igBlurb
    if not label or not text or submenu.igBlurbLabel then return end

    local blurb = WINDOW_MANAGER:CreateControl(nil, label, CT_LABEL)
    blurb:SetFont(BLURB_FONT)
    -- The box is the title's own, so standing the small line on the bottom of it stands it on
    -- the line the title is written on.
    blurb:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    blurb:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    blurb:SetAnchor(TOPLEFT, label, TOPLEFT,
        zo_max(label:GetTextWidth(), BLURB_MIN_TITLE) + BLURB_GAP, 0)
    blurb:SetAnchor(BOTTOMRIGHT, label, BOTTOMRIGHT, -BLURB_ARROW_ROOM, 0)
    blurb:SetText(Color(SOFT, BLURB_MARK .. text))
    submenu.igBlurbLabel = blurb
end

-- One category open at a time, among the ones standing side by side. LAM's own toggle is left in
-- place and this runs after it, so the arrow and the animation stay the library's; all this does
-- is shut the one that was open next to it. Every level has a ring of its own: opening COLORS
-- closes STYLE beside it without disturbing the VISUALS they both live in.
local function SetUpAccordion(list)
    local submenus = CategoriesIn(list)

    for _, submenu in ipairs(submenus) do
        local function Also(target)
            if not target then return end
            local toggle = target:GetHandler("OnMouseUp")
            target:SetHandler("OnMouseUp", function(self, ...)
                if toggle then toggle(self, ...) end
                -- The same switch the bag answers: off, and the page keeps every category the
                -- player opened open.
                if not (IG.sv and IG.sv.accordion) then return end
                if not submenu.open then return end
                for _, other in ipairs(submenus) do
                    if other ~= submenu and other.open then
                        other.open = false
                        other.animation:PlayFromEnd()
                    end
                end
            end)
        end
        Also(submenu.label)
        Also(submenu.icon)
        Also(submenu.btmToggle)

        AddBlurb(submenu)

        -- The one title that moves. The library hands its own data table back untouched, so the
        -- submenu is found by a mark left on it rather than by what its label reads as.
        if submenu.label and submenu.data.igAnimateTitle then
            AnimateTitle(submenu.label)
        end

        -- Categories of its own inside: they close each other, not the one holding them.
        if submenu.data.controls then SetUpAccordion(submenu.data.controls) end
    end
end

---------------------------------------------------------------------------
-- BOOSTS: which of the kinds inside it stand on their own
---------------------------------------------------------------------------

-- BOOSTS gathers everything you spend on yourself, which is one answer for a bag with three of
-- them in it and another for a bag with thirty. Each kind it is made of can be lifted out of it
-- here and left standing as a category in its own right, with its own name, colour, icon,
-- counter and row on the Groups page -- the way INFINITE ARCHIVE used to stand, which is the
-- one kind that is exactly that when it is lifted out.
--
-- Where this sits beside the other way a category comes apart -- Split Long Categories in
-- General, and the three lines the right click menu offers -- is worth saying plainly, because
-- the two look alike and are not:
--
--   * a kind lifted out here is not in BOOSTS at all any more. It is somewhere else in the
--     list, with a heading of its own, and what BOOSTS was told about splitting itself up is
--     not asked about it and cannot reach it;
--   * BOOSTS' own answer goes on working on what is left behind, and breaks that into the
--     same headings this page names. The classifier gives both the same heading for a piece
--     (Classify.lua: BoostPath), so a kind reads the same whichever road it arrived by.
--
-- Nothing a lifted category was given is lost by folding it back in. A category keeps what it
-- was told under its own key, and the key does not change: fold RIDING LESSONS back into
-- BOOSTS, lift it out again a month later, and the name, colour and place you gave it are the
-- ones it comes back wearing.
---------------------------------------------------------------------------
-- DRAWERS: the panels that open beside the bag
---------------------------------------------------------------------------

-- A page of its own rather than a corner of VISUALS, because a drawer is not a way of drawing
-- the list: it is another thing standing beside it, with its own contents to be set. There is
-- one drawer finished so far and its settings are what is here; the other two will bring theirs
-- with them.
--
-- Nothing on this page is about the look, so every line says look = false: switching a purse
-- off is not "a theme of your own".
-- The AUTOMATE drawer's own category: the same lines its page draws, from the same tables.
-- The two actions, Off / Ask / Auto (IG.AUTOMATE_ACTIONS, Classify.lua).
local function ActionLines()
    local lines = {}
    for _, action in ipairs(IG.AUTOMATE_ACTIONS or {}) do
        local key, which = action.key, action.which
        lines[#lines + 1] = {
            name = action.name,
            description = action.description,
            look = false,
            pick = IG.ACTION_PICK,
            get = function() return IG.ActionMode(which) end,
            set = function(value)
                IG.sv[key] = value
                IG.RefreshLists()
                if IG.RefreshOpenDrawer then IG.RefreshOpenDrawer() end
            end,
        }
    end
    -- Off by default: a set piece not yet in your set collection is skipped by both Auto-Sell
    -- and Auto-Deconstruct (Trading.lua, Deconstruct.lua), because selling or breaking it down
    -- loses it for good. Either switch lets that one piece through too.
    lines[#lines + 1] = { name = "Sell Uncollected Set Pieces Too",
        description = "Auto-Sell normally skips a set piece you have not unlocked in your set "
            .. "collection yet. On: it is sold anyway.",
        key = "sellIncludeUncollected", look = false }
    lines[#lines + 1] = { name = "Deconstruct Uncollected Set Pieces Too",
        description = "Auto-Deconstruct normally skips a set piece you have not unlocked in your "
            .. "set collection yet. On: it is broken down anyway.",
        key = "deconIncludeUncollected", look = false }
    return lines
end

-- One tab of the AUTOMATE drawer as it stands on this page: a heading, then each of its sections
-- as a small heading over its own block (IG.AUTOMATE_LAYOUT, Classify.lua). A one-way rule is a
-- switch here, its way written into its name; a paired line keeps its Off / Sell / Deconstruct.
local function AutomateTab(controls, tab, title)
    controls[#controls + 1] = { type = "description", text = Color(TEXT, title) }
    for _, section in ipairs(IG.AutomateSections and IG.AutomateSections(tab) or {}) do
        local lines = {}
        for _, line in ipairs(section.lines) do
            local oneWay = line.target ~= nil
            lines[#lines + 1] = {
                name = oneWay and (line.name .. " into " .. (line.category or line.target)) or line.name,
                description = line.description,
                look = false,
                pick = not oneWay and line.pick or nil,
                get = line.get,
                set = function(value)
                    line.set(value)
                    if IG.RefreshOpenDrawer then IG.RefreshOpenDrawer() end
                end,
            }
        end
        controls[#controls + 1] = { type = "description", text = Color(SOFT, section.title) }
        controls[#controls + 1] = SwitchBlock(lines, true)
    end
end

-- REPAIRING (Repair.lua): its own getters, since its keys are not rules of Classify.lua's.
local function RepairLines()
    local lines = {}
    for _, rule in ipairs(IG.AUTOMATE_REPAIR or {}) do
        local key = rule.key
        lines[#lines + 1] = {
            name = rule.name,
            description = rule.description,
            look = false,
            pick = rule.pick,
            get = function() return IG.RepairGet(key) end,
            set = function(value)
                IG.RepairSet(key, value)
                if IG.RefreshOpenDrawer then IG.RefreshOpenDrawer() end
            end,
        }
    end
    return lines
end

local function AutomateSettingsPage()
    -- The same order as the drawer: what the page does, the sorting rules, then the warning and
    -- the two actions under them.
    local controls = {
        {
            type = "description",
            text = Color("FF6F61", "AUTOMATIC SORTING") .. "\n"
                .. Color(SOFT, "Sorts items into SELL or DECONSTRUCT. Nothing is sold or broken "
                .. "down until you turn on the actions at the bottom. Set, locked and worn pieces "
                .. "are never touched."),
        },
    }
    AutomateTab(controls, "GEAR", "SETLESS GEAR")
    AutomateTab(controls, "ITEMS", "ITEMS")
    controls[#controls + 1] = { type = "description", text = Color(TEXT, "REPAIRING") }
    controls[#controls + 1] = SwitchBlock(RepairLines(), true)
    controls[#controls + 1] = { type = "description", text = Color("FF4A3A", "USE AT YOUR OWN RISK") }
    controls[#controls + 1] = SwitchBlock(ActionLines(), true)
    return controls
end

local function DrawerControls()
    local currencies = {}
    for _, currency in ipairs(IG.CURRENCIES or {}) do
        local key = currency.key
        currencies[#currencies + 1] = {
            name = currency.label,
            description = "Its own tab in the gold tracker.",
            look = false,
            -- Not a setting of its own: one entry in the table of purses that are wanted.
            get = function() return IG.CurrencyShown(key) end,
            set = function(value)
                IG.sv.drawerCurrencies = IG.sv.drawerCurrencies or {}
                IG.sv.drawerCurrencies[key] = value
                if IG.RefreshOpenDrawer then IG.RefreshOpenDrawer() end
            end,
        }
    end

    -- Each drawer's settings are a category of their own inside this one, named after the drawer
    -- and lettered in its accent, so the gear on a drawer's head can open the page straight at
    -- its own (IG.OpenDrawerSettings). A drawer with nothing to set yet still has its category,
    -- saying so, so that the gear never opens on nothing.
    local pages = {
        gold = {
            {
                type = "description",
                text = Color(SOFT, "Income and spending per currency and character, by source, "
                    .. "for the last 30 days. Time the addon was off is not counted."),
            },
            SwitchBlock(currencies, true),
        },
        automate = AutomateSettingsPage(),
    }
    -- The MODULES drawer's own category: the same switches as the drawer, through the same
    -- IG.SetModuleEnabled, so either page shows what the other one set.
    pages.modules = {}
    for _, module in ipairs(IG.ModuleSwitches and IG.ModuleSwitches() or {}) do
        local flag = module.flag
        pages.modules[#pages.modules + 1] = {
            type = "checkbox",
            name = Color(TEXT, IG.GetGroupLabel(module.key)),
            getFunc = function() return IG.sv[flag] == true end,
            setFunc = function(value) IG.SetModuleEnabled(flag, value) end,
            default = IG.DEFAULT_SETTINGS[flag],
        }
    end

    local controls = {
        {
            type = "description",
            text = Color(SOFT, "The marks left of your bag open a drawer beside it. Unlock its "
                .. "padlock to move or resize it."),
        },
        {
            type = "button",
            name = "Reset Drawer Position",
            tooltip = "Moves the drawer back beside the bag at its default size.",
            func = function()
                if IG.ResetDrawerPanel then IG.ResetDrawerPanel() end
            end,
        },
        PageRule(),
    }
    for _, drawer in ipairs(IG.DRAWERS or {}) do
        controls[#controls + 1] = {
            type = "submenu",
            name = Color(drawer.color, drawer.label),
            reference = IG.DrawerSettingsReference(drawer.key),
            controls = pages[drawer.key] or {
                { type = "description", text = Color(SOFT, "No settings yet.") },
            },
        }
    end
    return controls
end

-- The name the category for one drawer is built under, which is how the gear finds it again.
function IG.DrawerSettingsReference(key)
    return "InventoryGroupingDrawerPage_" .. tostring(key)
end

-- The settings, opened at one drawer's own category: the page is opened, DRAWERS is opened, that
-- drawer's category is opened -- each by the same click handler the player's own click runs, so
-- the one-at-a-time rule shuts whatever else was open -- and the page is scrolled to put it in
-- view. The page's widgets are only built the first time it is shown, so the rest waits for them,
-- trying again a few times rather than once.
local DRAWERS_REFERENCE = "InventoryGroupingDrawersCategory"

local function OpenCategory(submenu)
    if not submenu or submenu.open then return end
    local handler = submenu.label and submenu.label:GetHandler("OnMouseUp")
    if handler then handler(submenu.label, MOUSE_BUTTON_INDEX_LEFT, true) end
end

function IG.OpenDrawerSettings(key)
    if not IG.settingsPanel then return end
    libAddonMenu2:OpenToPanel(IG.settingsPanel)
    if not key then return end
    local tries = 0
    local function Jump()
        tries = tries + 1
        local outer = _G[DRAWERS_REFERENCE]
        local page = _G[IG.DrawerSettingsReference(key)]
        if not (outer and page) or IG.settingsPanel:IsHidden() then
            if tries < 20 then zo_callLater(Jump, 100) end
            return
        end
        OpenCategory(outer)
        OpenCategory(page)
        -- Scrolled once the categories have been laid out at their open size.
        zo_callLater(function()
            local container = IG.settingsPanel.container
            if container and ZO_Scroll_ScrollControlIntoCentralView then
                pcall(ZO_Scroll_ScrollControlIntoCentralView, container, page)
            end
        end, 150)
    end
    zo_callLater(Jump, 100)
end

function IG.CreateSettingsPanel()
    -- No "if not LAM then return end" here: LibAddonMenu-2.0 is a ## DependsOn, so the manifest
    -- itself already refuses to load this addon at all without it present (ESOUI admin review,
    -- 2026-11-02) -- a guard against something that can no longer happen is dead code, not safety.
    local LAM = libAddonMenu2

    IG.settingsPanel = LAM:RegisterAddonPanel("InventoryGroupingSettings", {
        type = "panel",
        name = IG.DISPLAY_NAME,
        displayName = Color("E8D5A9", IG.DISPLAY_NAME),
        author = "blekays",
        version = IG.VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local choices = IG.GetAllIcons()
    local groupIcons, subIcons = {}, {}
    for _, group in ipairs(IG.GROUPS) do
        groupIcons[#groupIcons + 1] = IconPicker(group.label, group.key, group.icon, choices)
    end
    for _, sub in ipairs(IG.SUBGROUP_LIST) do
        subIcons[#subIcons + 1] = IconPicker(sub.label, "sub:" .. sub.label, sub.icon, choices)
    end
    -- Handed to VisualsControls, which reads this global once it builds VISUALS' own controls
    -- further down in this same function.
    visualsIconSubmenus = {
        {
            type = "submenu",
            name = Color(SECTION.yellow, "Group icons"),
            igBlurb = "One icon per top-level group, or back to the defaults",
            controls = Append({
                { type = "description", text = Color(SOFT, "Pick the icon shown on each top-level group.") },
                {
                    type = "button",
                    name = "Reset all icons",
                    tooltip = "Every group and sub-group goes back to its default icon.",
                    func = function()
                        ZO_ClearTable(IG.sv.icons)
                        IG.RefreshLists()
                    end,
                },
            }, groupIcons),
        },
        {
            type = "submenu",
            name = Color(SECTION.yellow, "Sub-group icons"),
            igBlurb = "One icon per sub-group",
            controls = Append({ { type = "description", text = Color(SOFT, "Pick the icon shown on each sub-group.") } }, subIcons),
        },
    }

    local controls = {
        -- About: icon, pitch and author, side by side on one line.
        {
            type = "custom",
            reference = "InventoryGroupingAbout",
            createFunc = CreateAboutBlock,
            minHeight = 120,
            maxHeight = 260,
        },
        PageRule(),
    }
    Append(controls, {
        {
            type = "submenu",
            name = Color(SECTION.general, IG.S("CATEGORY_GENERAL")),
            igBlurb = "The addon itself, and where it runs",
            controls = GeneralControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.yellow, IG.S("CATEGORY_VISUALS")),
            igBlurb = "Interface style and animations",
            controls = VisualsControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.yellow, IG.S("CATEGORY_LAYOUT")),
            igBlurb = "Rows, Chips or Tiles for each section",
            controls = LayoutControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.orange, IG.S("CATEGORY_DRAWERS")),
            igBlurb = "The pages that open beside your bag",
            reference = DRAWERS_REFERENCE,
            controls = DrawerControls(),
        },
    })

    Append(controls, {
        {
            type = "submenu",
            name = Color(SECTION.behaviour, IG.S("CATEGORY_INFO_SHOWN")),
            igBlurb = "The numbers beside a category's name",
            controls = InfoShownControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.groups, IG.S("CATEGORY_GROUPS")),
            igBlurb = "Rename one, move it, or hide it",
            controls = GroupControls(),
        },
        {
            type = "submenu",
            name = Color(SECTION.groups, IG.S("CATEGORY_ITEMS_MOVED")),
            igBlurb = "Where your right clicks sent things",
            controls = {
                SwitchBlock({
                    {
                        name = "Show Where It Used To Be",
                        description = "A piece you sent to SELL, SELL [GUILD STORE], DECONSTRUCT, "
                            .. "TO BANK or CUSTOM also stays, dimmed, in its own category, saying "
                            .. "where it went. Off: it only shows up where you sent it.",
                        key = "asideAtHome",
                        look = false,
                        -- One global switch, as asked for: pressing this answers for every list,
                        -- even one whose own Show Moved button was pressed before and so was
                        -- answering for itself alone (IG.MovedShown).
                        set = function(value)
                            IG.sv.asideAtHome = value
                            if type(IG.sv.movedLists) == "table" then
                                ZO_ClearTable(IG.sv.movedLists)
                            end
                            IG.RefreshLists()
                        end,
                    },
                }, true),
                { type = "description", text = Color(SOFT, "Items you sent to a group with right click. "
                    .. "These always beat the automatic rules.") },
                {
                    type = "description",
                    text = function()
                        local lines = IG.OverrideBreakdown()
                        if #lines == 0 then return Color(SOFT, "Nothing moved yet.") end
                        local rows = { Color(TEXT, IG.CountOverrides() .. " moved:") }
                        for _, line in ipairs(lines) do rows[#rows + 1] = Color(SOFT, "  " .. line.text) end
                        return table.concat(rows, "\n")
                    end,
                },
                {
                    type = "button",
                    name = "Forget them all",
                    isDangerous = true,
                    func = function()
                        IG.ClearOverrides()
                        RefreshPanel()
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = Color(SECTION.behaviour, IG.S("CATEGORY_VENDORS_STATIONS")),
            igBlurb = "The flat selling layout, and the grouped benches",
            controls = VendorStationControls(),
        },
        -- Pink: the MODULES drawer's own colour (Drawer.lua, IG.DRAWERS), not the shared section
        -- token -- this header is a direct stand-in for that page, so it wears its colour.
        { type = "header", name = Color("FF7AD9", IG.S("CATEGORY_MODULES_HEADER")) },
        {
            type = "description",
            text = Color(SOFT, "Each of these can also be switched on the bag's own MODULES "
                .. "drawer, faster than coming here."),
        },
        {
            type = "submenu",
            name = Color("FF7AD9", IG.S("CATEGORY_MODULES_ON_OFF")),
            igBlurb = "Every module, one switch each",
            controls = { SwitchBlock({
                { name = "Custom Category", description = "A CUSTOM category you fill by hand from an item's right click menu.", key = "customEnabled", look = false },
                { name = "Sell [Guild Store]", description = "A SELL [GUILD STORE] category you fill from an item's right click menu.", key = "guildSellEnabled", look = false },
                { name = "Researchable", description = "A RESEARCHABLE category inside DISPOSAL for gear whose trait this character can still research.", key = "researchableEnabled", look = false },
                { name = "Researchable (Alts)", description = "A RESEARCHABLE (ALTS) group for gear this character already knows but another character on your account does not yet. Needs LibCharacterKnowledge installed; off by default.", key = "researchAltsEnabled", look = false },
                { name = "To Bank Button", description = "Shows the TO BANK button. Marking still works either way; see Module Settings for whether it deposits itself.", key = "toBankShown", look = false },
                { name = "Equipped", description = "An EQUIPPED group with everything you are wearing.", key = "equippedEnabled", look = false },
                { name = "Setups", description = "A SETUPS group with one sub-category per saved setup. Right click a saved setup to Equip All its pieces at once.", key = "setupsEnabled", look = false },
                { name = "Armory", description = "An ARMORY group listing each loadout with its sets and pieces.", key = "armoryEnabled", look = false },
                { name = "Uncollected", description = "An UNCOLLECTED group with unbound gear you can trade, plus what you have not learned yet.", key = "bindOnEquipEnabled", look = false },
                { name = "Just Crafted", description = "A JUST CRAFTED group at crafting stations with what you made there.", key = "justCraftedEnabled", look = false },
                { name = "Daily Writ", description = "A DAILY WRIT group with items your crafting writs ask for.", key = "dailyWritEnabled", look = false },
                { name = "Home Containers", description = "A HOME CONTAINERS group showing your house storage.", key = "homeEnabled", look = false },
                { name = "Junk", description = "A JUNK group with everything marked as junk.", key = "junkEnabled", look = false },
                { name = "New Items", description = "A NEW group with what arrived since you last closed the bag.", key = "newEnabled", look = false },
                { name = "Recently Acquired", description = "A RECENTLY ACQUIRED group with what you picked up in recent places.", key = "lastRunEnabled", look = false },
            }, true) },
        },
        {
            type = "submenu",
            name = Color("FF7AD9", "BANK MODULES"),
            reference = "Inventory2BankModulesSubmenu",
            igBlurb = "Which of these categories show while the bank's own list is open",
            controls = {
                { type = "description", text = Color(SOFT, "On above and here both: only while this list "
                    .. "is the bank's own. The bag goes on reading the switches above as it always has.") },
                SwitchBlock((function()
                    local BANK_MODULE_LINES = {
                        { name = "Armory", key = "ARMORY" },
                        { name = "Sell", key = "SELL" },
                        { name = "Sell [Guild Store]", key = "GUILDSELL" },
                        { name = "Deconstruct", key = "DECON" },
                        { name = "Custom Category", key = "CUSTOM" },
                        { name = "Researchable", key = "RESEARCH" },
                        { name = "Researchable (Alts)", key = "RESEARCHALTS" },
                        { name = "Setups", key = "SETUPS" },
                        { name = "Daily Writ", key = "DAILYWRIT" },
                    }
                    local lines = {}
                    for _, line in ipairs(BANK_MODULE_LINES) do
                        local key = line.key
                        lines[#lines + 1] = {
                            name = line.name,
                            look = false,
                            get = function() return not (IG.sv.bankModules and IG.sv.bankModules[key] == false) end,
                            set = function(value)
                                IG.sv.bankModules = IG.sv.bankModules or {}
                                -- Off is stored as false and on as nothing at all: `value or nil`
                                -- turned false back into nil, so switching one off never stuck.
                                if value then IG.sv.bankModules[key] = nil else IG.sv.bankModules[key] = false end
                                IG.RefreshLists()
                                if IG.RefreshSettingsPanel then IG.RefreshSettingsPanel() end
                            end,
                        }
                    end
                    return lines
                end)(), true),
            },
        },
        {
            type = "submenu",
            name = Color("FF7AD9", IG.S("CATEGORY_MODULE_SETTINGS")),
            igBlurb = "Extra settings for Sell [Guild Store], To Bank, Uncollected, Junk, New Items, Recent Loot",
            controls = {
                { type = "description", text = Color(SOFT, "On / off for every module is one page back. "
                    .. "These are the settings for the ones that have more than a switch.") },
                {
                    type = "submenu",
                    name = Color(SECTION.modules, "Sell [Guild Store]"),
                    igBlurb = "Market Study and Awaiting Upgrade marks",
                    controls = { SwitchBlock({
                        { name = "Market Study / Awaiting Upgrade", description = "Right click a SELL [GUILD STORE] piece to mark it Upgrade or Price Drop.", key = "awaitingMarksEnabled", look = false },
                    }, true) },
                },
                {
                    type = "submenu",
                    name = Color(SECTION.modules, "Researchable (Alts)"),
                    igBlurb = "Whether locked, Armory or Setup pieces are listed too",
                    controls = { SwitchBlock({
                        { name = "Also List Locked Pieces", description = "Off: a piece you locked is left out. On: it is listed too, dimmed, with a note.", key = "researchAltsShowLocked", look = false },
                        { name = "Also List Armory Pieces", description = "Off: a piece in an Armory build is left out. On: it is listed too, dimmed, with a note.", key = "researchAltsShowArmory", look = false },
                        { name = "Also List Setup Pieces", description = "Off: a piece in a saved Setup is left out. On: it is listed too, dimmed, with a note.", key = "researchAltsShowSetup", look = false },
                    }, true) },
                },
                {
                    type = "submenu",
                    name = Color(SECTION.modules, "To Bank"),
                    igBlurb = "Whether a marked piece deposits itself",
                    controls = { SwitchBlock({
                        { name = "Deposit Automatically", description = "A marked piece empties into your bank the moment it opens. Off: it stays marked and you deposit it by hand.", key = "toBankAutoDeposit", look = false },
                    }, true) },
                },
                {
                    type = "submenu",
                    name = Color(SECTION.modules, "Uncollected"),
                    igBlurb = "What you can still trade, or still learn",
                    controls = { SwitchBlock({
                        { name = "Show Guild Store Pieces", description = "Also list the pieces you sent to SELL [GUILD STORE].", key = "bindOnEquipShowGuild", look = false },
                        { name = "Include Unknown Motifs", description = "Motif books and chapters not learned yet.", key = "bindOnEquipMotifs", look = false },
                        { name = "Include Unknown Recipes", description = "Recipes not learned yet.", key = "bindOnEquipRecipes", look = false },
                        { name = "Include Unknown Furnishing Plans", description = "Furnishing plans not learned yet.", key = "bindOnEquipPlans", look = false },
                        { name = "Include Unknown Style Pages", description = "Outfit style pages not unlocked yet.", key = "bindOnEquipStylePages", look = false },
                    }, true) },
                },
                {
                    type = "submenu",
                    name = Color(SECTION.modules, "Junk"),
                    igBlurb = "What you marked as junk, back in sight",
                    controls = { SwitchBlock({
                        { name = "Stand With The Modules", description = "JUNK sits under MODULES. Off: at the bottom of the list.", key = "junkOnModules", look = false },
                    }, true),
                    { type = "description", text = Color(SECTION.modules, "Below: marks items as junk for you.") },
                    SwitchBlock({
                        -- onToggle: junkStolenEnabled is not one of IG.MODULE_GROUPS, so
                        -- IG.SetModuleEnabled never sees it moving -- Junk.lua's own arrival
                        -- watch (IG.ApplyJunkStolenEnabled) is told by hand instead.
                        { name = "Junk Stolen Rubbish", description = "New stolen items under the quality chosen below are junked.", key = "junkStolenEnabled", look = false,
                            onToggle = function(on) if IG.ApplyJunkStolenEnabled then IG.ApplyJunkStolenEnabled(on) end end },
                        { name = "Junk Stolen Under", description = "Stolen items under this quality are junked.", key = "junkStolenBelow", pick = { values = STOLEN_QUALITY_VALUES, labels = STOLEN_QUALITY_LABELS }, enabled = JunkStolenLive, look = false },
                    }, true),
                    { type = "description", text = Color(SECTION.modules, "Junk these kinds as they arrive:") },
                    -- Same idea as above: one shared arrival watch (IG.ApplyJunkGarbageEnabled)
                    -- behind all four, told by hand whenever any one of them moves.
                    SwitchBlock({
                        { name = "Junk Treasure", description = "Treasure and trash items worth only gold.", key = "junkGarbageTreasure", look = false,
                            onToggle = function() if IG.ApplyJunkGarbageEnabled then IG.ApplyJunkGarbageEnabled() end end },
                        { name = "Junk Plain Weapons", description = "Setless weapons. Ornate and intricate are never junked.", key = "junkGarbageWeapons", look = false,
                            onToggle = function() if IG.ApplyJunkGarbageEnabled then IG.ApplyJunkGarbageEnabled() end end },
                        { name = "Junk Plain Armour", description = "Setless armour. Ornate and intricate are never junked.", key = "junkGarbageArmor", look = false,
                            onToggle = function() if IG.ApplyJunkGarbageEnabled then IG.ApplyJunkGarbageEnabled() end end },
                        { name = "Junk Plain Jewellery", description = "Setless rings and necklaces. Ornate and intricate are never junked.", key = "junkGarbageJewelry", look = false,
                            onToggle = function() if IG.ApplyJunkGarbageEnabled then IG.ApplyJunkGarbageEnabled() end end },
                    }, true) },
                },
                {
                    type = "submenu",
                    name = Color(SECTION.modules, "New Items"),
                    igBlurb = "Keep certain kinds out of NEW",
                    controls = {
                        { type = "description", text = Color(TEXT, "KEEP OUT OF NEW") },
                        SwitchBlock({
                            { name = "Garbage", description = "Pieces standing in GARBAGE.", inline = true, key = "newOutGarbage", look = false },
                            { name = "Junk", description = "Pieces in JUNK or marked junk.", inline = true, key = "newOutJunk", look = false },
                            { name = "Sell", description = "Pieces standing in SELL.", inline = true, key = "newOutSell", look = false },
                            { name = "Deconstruct", description = "Pieces standing in DECONSTRUCT.", inline = true, key = "newOutDecon", look = false },
                            { name = "Trash", description = "Items of the Trash type.", inline = true, key = "newOutTrash", look = false },
                            { name = "Treasures", description = "Treasures and sell-only trophies.", inline = true, key = "newOutTreasure", look = false },
                            { name = "Stolen", description = "Stolen pieces, or those in STOLEN.", inline = true, key = "newOutStolen", look = false },
                            { name = "Crafting Materials", description = "Materials, runes, reagents, styles, traits.", inline = true, key = "newOutMaterials", look = false },
                            { name = "Stock", description = "Soul gems and repair kits.", inline = true, key = "newOutStock", look = false },
                            { name = "Daily Writ", description = "Items your crafting writs need.", inline = true, key = "newOutDailyWrit", look = false },
                        }, true),
                    },
                },
                {
                    type = "submenu",
                    name = Color(SECTION.modules, "Recent Loot"),
                    igBlurb = "What counts as a run, and how it is shown",
                    controls = LastRunControls(),
                },
            },
        },    })

    NameCategories(controls)
    LAM:RegisterOptionControls("InventoryGroupingSettings", controls)

    -- Both of these want widgets that only exist once the page has been built for the first time.
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if panel ~= IG.settingsPanel then return end
        CreateThemeBlurb()
        SetUpAccordion(controls)
    end)
end
