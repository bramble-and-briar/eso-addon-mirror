InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion


------------------------------------------------------------------
-- Constants & Magic Number Definitions
------------------------------------------------------------------
this.constants = {
    -- Item Tracking Modes
    TRACKING_MODE_SHOW   = 1,
    TRACKING_MODE_NOTIFY = 2,
    TRACKING_MODE_MUTE   = 3,
    
    -- Context Menu & UI
    CONTEXT_MENU_DELAY_MS = 50,
}

this.preLoadedRulesets = {
    ["treasure_maps"] = { 
        displayName = "Treasure Maps", 
        patterns = { "*treasure map *" }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["surveys"] = { 
        displayName = "Surveys", 
        patterns = { "*survey*","unidentified * survey report", }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["master_writs"] = { 
        displayName = "Master Writs", 
        patterns = { "master * writ", "unknown * writ" }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["leads"] = { 
        displayName = "Leads", 
        patterns = { "*antiquity lead*" }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["motifs"] = { 
        displayName = "Motifs", 
        patterns = { "*crafting motif*" }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["crafting_recipes"] = {
        displayName = "Crafting Recipes",
        patterns = { 
            "recipe:*", 
            "pattern:*", 
            "design:*",
            "blueprint:*",
            "praxis:*",
            "furnishing:*",
            "formula:*",
            "diagram:*",
            "schematic:*",
        }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["rare_mats"] = { 
        displayName = "Rare Mats",
        patterns = { 
            "perfect roe", 
            "kuta", 
            "dawn prism", 
            "*nirncrux", 
            "tempering alloy", 
            "dreugh wax", 
            "rosin", 
            "chromium plating",
            "chromium grains",
            "frost mirriam",
            "powdered mother of pearl",
            "dragon's blood",
            "dragon rheum",
            "dragon's bile",
            "*cultivated cryptpods*",       
            "*daedra-blood maggots*",       
            "*grave tongue*",      
            "*verminous*", 
            "columbine",
            "scrib jelly",
            "mudcrab chitin",
            "harvester silk",
            "daedric skin",
            "colossus iron",
            "rough heavy armor component" 
        }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["harvested_materials"] = {
        displayName = "Harvested Materials",
        patterns = {
            "raw ancestor silk",
            "rough ruby ash",
            "*hide scraps",
            "*platinum dust",
            "* ore",
        },
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["collectible_fragments"] = { 
        displayName = "Collectible Fragments",
        patterns = { 
            "*fragment*", 
            "*runebox*",
            "Battlemaster Token",
            "Arena Gladiator's Proof",
            "Siege of Cyrodiil Merit",
            "Welkynar Binding",
            "*shred*",
            "shard of parched stone",
        }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["pardons"] = { 
        displayName = "Pardons",
        patterns = { 
            "*edict",
        }, 
       display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["refined_materials"] = {
        displayName = "Refined Materials",
        patterns = {
            "*platinum ounce","* ingot","sanded *","*silk","*leather"
        },
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["boosts"] = {
        displayName = "Boosts",
        patterns = {
            "*scroll",
            "*ambrosia*",
            "*war torte*",
            "*alliance war skill line scroll*",
        },
        display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false } 
    },	
    ["crafting_rewards"] = { 
        displayName = "Crafting Rewards",
        patterns = { 
            "blacksmith's *", 
            "clothier's *", 
            "woodworker's *", 
            "alchemist's *", 
            "enchanter's *", 
            "provisioner's *", 
            "jewelry crafter's *",
            "shipment*",
        }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["provisioning_writ_items"] = { 
        displayName = "Provisioning Writ Items",
        patterns = { 
            "fishy stick", "baked apples", "baked potato", "carrot soup", "chicken breast",
            "chorrol corn on the cob", "cyrodilic cornbread", "cyrodilic pumpkin fritters",
            "elinhir roast antelope", "firsthold fruit and cheese plate", "garlic mashed potatoes",
            "garlic pumpkin seeds", "hare in garlic sauce", "hearty garlic corn chowder",
            "jerall view inn carrot cake", "lilmoth garlic hagfish", "mammoth snout pie",
            "nibenese garlic carrots", "orcrest garlic apple jelly", "pellitine tomato rice",
            "roast corn", "roast pig", "senchal curry fish and rice", "whiterun cheese-baked trout",
            "argonian saddle-cured rabbit", "fresh apples and eidar cheese", "hagraven's tonic",
            "khenarthi's wings chai", "muthsera's remorse", "pickled carrot slurry", 
            "sipping imga tonic", "arenthian brandy",
            "aetherial tea", "alik'r beets with goat cheese", "barley nectar", "battaglir chowder",
            "bitterlemon tea", "blue road marathon", "bog-iron ale", "breton pork sausage",
            "cinnamon grape jelly", "clarified syrah wine", "comely wench *", "eltheric hooch",
            "four-eye gog", "ginger wheat beer", "gods-blind-me", "golden lager", "gossamer mazte",
            "grandpa's bedtime tonic", "grape preserves", "honey rye", "lemon flower mazte",
            "maormer tea", "markarth mead", "mazte", "mermaid whiskey", "millet-stuffed pork loin",
            "mulled wine", "nereid wine", "nut brown ale", "red rye beer", "redoran peppered melon",
            "rye-in-your-eye", "seaflower tea"
        }, 
        display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["miscellaneous"] = { 
        displayName = "Miscellaneous",
        patterns = {}, 
        display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false } 
    },	
    ["pvp"] = { 
        displayName = "PvP",
        patterns = {
            "cyrodiil repair kit", "siege repair kit", "keep wall masonry repair kit", "keep door woodwork repair kit",
            "*alliance war recall stone*", "*ballista*", "*trebuchet*", "*catapult*", "flaming oil", "*meatbag*",
            "*battering ram*", "*forward camp*", "keep recall stone", "sigil of imperial retreat",
        }, 
        display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
    ["utility"] = { 
        displayName = "Utility",
        patterns = {
            "*soul gem*",
            "equipment repair kit",
            "crown repair kit",
            "*group repair kit",
        }, 
        display = { show = false, notify = false, bank = false, group = true, isExpanded = true, isHidden = false } 
    },
}


------------------------------------------------------------------
-- Account-Wide Defaults
------------------------------------------------------------------
this.defaultsAccount = {
    bankItemDelay = 100,
    debugEnabled = false,
    houseBankNames = {},
    autoMergeChests = true,
	
    -- Item Tracker
    trackedItems = {},
    trackedRules = {},
    
    -- Item Tracker Overlay
    showTrackedItemsPanel = true,
    showEmptyTrackedItems = true,
    trackerOffsetX = 50,
    trackerOffsetY = 50,
    wrapTrackedItemNames = false,
    trackerGroupThreshold = 8,
    trackerMaxRows = 20,
    trackerTitleSize = 20,

    -- Currency & Capacity Overlay
    showEmptyCurrencies = true,
    currencyOffsetX = 50,
    currencyOffsetY = 150,
    currencyNamesById = {},

    -- Standalone Progress Bars
    progressBarPreferences = {},
    progressBarAlertColors = {},
}

------------------------------------------------------------------
-- Character-Specific Defaults
------------------------------------------------------------------
this.defaultsCharacter = {
    isEnabled = true,    
    trackedItems = {},
    trackedRules = {},
    filterShow = true,
    filterNotify = true,
    filterCraftbag = false,
    filterMute = true,
    filterUntracked = false,
    useCharacterItemList = false,
}