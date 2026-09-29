TEB = {
    name = "TEB",
    displayName = "The Elder Bar |cD6660CReloaded|r",
    author = "SimonIllyan",
    website = "",
    version = "12.1.3",
    debug = { },
}

-- libraries
local LAM2 = LibAddonMenu2
local LSV = LibSavedVars
local LFDB = LIB_FOOD_DRINK_BUFF
local LibClockTST = LibClockTST
local LSD = LibSetDetection
local LS = LibSets


-- globals of this addon
local G = {
    barAlpha = 1,
    centerTimer = 3000,
    colors = { },
    combatAlpha = 1,
    deaths = 0,
    highestFPS = 0,
    iconReference = { },
    nameReference = { },
    killingBlows = 0,
    kills = 0,
    lowestFPS = 10000,
    lvl = 0,
    movingGadgetKey = "",
    original = { },
    pulseFunction = function() return 1 end,
    pulseList = { },
    pulseSpeed = 6,
    screenHeight = GuiRoot:GetHeight(),
    screenWidth = GuiRoot:GetWidth(),
    showCombatOpacity = 0,
    spacer = 15, -- between columns in tooltip
    trackerDropdown = { },
    vampirism = { },
    equipped_dirty = true,
}
-- just for debugging
TEB.G = G

-- master gadget list
local gadgetReference = {
    ap            = { name = "Alliance Points",                 },
    fortunes      = { name = "Archival Fortunes",               },  
    bag           = { name = "Bag Space",                       },
    bank          = { name = "Bank Space",                      },
    blacksmithing = { name = "Blacksmithing Research Timer",    },
    bounty        = { name = "Bounty/Heat Timer",               },
    clock         = { name = "Clock",                           },
    companion     = { name = "Companion Info",                  },
    clothing      = { name = "Clothing Research Timer",         },
    crowngems     = { name = "Crown Gems",                      },
    crowns        = { name = "Crowns",                          },
    durability    = { name = "Durability",                      },
    enlightenment = { name = "Enlightenment",                   },
    endeavor      = { name = "Seals",                           },
    equipped      = { name = "Equipped",                        },
    esoplus       = { name = "ESO Plus Subscription",           },
    experience    = { name = "Experience",                      },
    fps           = { name = "FPS",                             },
    ft            = { name = "Fast Travel Timer",               },
    food          = { name = "Food Buff Timer",                 },
    gold          = { name = "Gold",                            },
    imperial      = { name = "Imperial Fragments",              },
    junk          = { name = "Junk",                            },
    jewelry       = { name = "Jewelry Crafting Research Timer", },
    kc            = { name = "Kill Counter",                    },
    latency       = { name = "Latency",                         },
    leads         = { name = "Leads",                           },
    level         = { name = "Level",                           },
    location      = { name = "Location",                        },
    lock          = { name = "Lock/Unlock Bar/Gadgets",         },
    memory        = { name = "Memory Usage",                    },
    mount         = { name = "Mount Timer",                     },
    mundus        = { name = "Mundus Stone",                    },
    outfit        = { name = "Outfit Change Tokens",            },
    skyshards     = { name = "Sky Shards",                      },
    soulgems      = { name = "Soul Gems",                       },
    tomepoints    = { name = "Tome Points",                     },
    tometokens    = { name = "Tome Tokens",                     },
    telvar        = { name = "Tel Var Stones",                  },
    tt            = { name = "Thief's Tools",                   },
    tradebars     = { name = "Trade Bars",                      },
    transmute     = { name = "Transmute Crystals",              },
    undaunted     = { name = "Undaunted Keys",                  },
    mail          = { name = "Unread Mail",                     },
    vampirism     = { name = "Vampirism",                       },
    wc            = { name = "Weapon Charge/Poison",            },
    woodworking   = { name = "Woodworking Research Timer",      },
    writs         = { name = "Writ Vouchers",                   },
}
TEB.gadgetReference = gadgetReference

local settings

-- default values for settings
local defaults = {
    Trackers = {
        ap     = { },
        gold   = { },
        mount  = { },
        mundus = { },
        telvar = { },
        writs  = { },
    },
    antiquities = {     
    },
    ap = {
        DisplayPreference = "Total Points",
        TooltipPreference = "Total Points",
        high = {
            danger = 999999999,
            warning = 999999999,
        },
        low = {
            danger = 0,
            warning = 0,
        },
    },
    autohide = {
        Bank = true,
        Chatter = true,
        Crafting = true,
        Digging = true,
        GameMenu = true,
        GuildBank = true,
        speed = 10,
    },
    bag = {
        DisplayPreference = "slots used/total slots",
        good = true,
        critical = 90,
        danger = 75,
        warning = 50,
        UsageAsPercentage = true,
    },
    bank = {
        DisplayPreference = "slots used/total slots",
        good = true,
        critical = 90,
        danger = 75,
        warning = 50,
        UsageAsPercentage = true,
    },
    bar = {
        Layer = DL_BACKGROUND,
        Locked = true,
        Position = "top",
        Width = "dynamic",
        Y = 0,
        backgroundOpacity = 1,
        bumpActionBar = true,
        bumpCompass = true,
        combatOpacity = 1,
        controlsPosition = "center",
        edgedBackground = false,
        font = "Univers57",
        gadgetsLocked = true,
        iconsInherit = true,
        iconsMode = "color",
        chatMessagesOn = true,
        opacity = 1,
        pulseType = "fade out",
        pulseSpeed = 3,
        pulseWhenCritical = false,
        scale = 1,
        sort = true,
        spacing = 10,
        thousandsSeparator = true,
    },
    bounty = {
        critical = "red",
        danger = "orange",
        DisplayPreference = "simple",
        Dynamic = true,
        good = "normal",
        warning = "yellow",
    },
    clock = {
        DisplayPreference = "local time",
        Type = "24h",
        DateFormat = "%Y-%m-%d",
    },
    colors = {
        critical  = { r = 1,  g = 0,  b = 0,   a = 1, }, -- red
        danger    = { r = 1,  g = 0,  b = 0,   a = 1, }, -- red
        warning   = { r = 1,  g = .5, b = 0,   a = 1, }, -- orange
        caution   = { r = 1,  g = 1,  b = 0,   a = 1, }, -- yellow
        active    = { r = 0,  g = 1,  b = 1,   a = 1, }, -- cyan
        good      = { r = 0,  g = 1,  b = 0,   a = 1, }, -- green
        normal    = { r = .8, g = .8, b = 0.8, a = 1, }, -- off-white
        header    = { r = 0,  g = .5, b = 1,   a = 1, }, -- blue
        highlight = { r = 1,  g = 1,  b = 1,   a = 1, }, -- white
        stage1    = { r = 0,  g = 1,  b = 0,   a = 1, }, -- green
        stage2    = { r = 1,  g = 1,  b = 0,   a = 1, }, -- yellow
        stage3    = { r = 1,  g = .5, b = 0,   a = 1, }, -- orange
        stage4    = { r = 1,  g = 0,  b = 0,   a = 1, }, -- red
        stage5    = { r = 1,  g = 0,  b = .5,  a = 1, }, -- purple
    },
    combatIndicator = true,
    companion = {
        separator = "/",
        Dynamic = true,
        rapportHide = false,
    },
    crowngems = {
    },
    crowns = {
    },
    durability = {
        critical = 5,
        danger = 15,
        DisplayPreference = "durability %",
        good = true,
        warning = 30,
        caution = 50,

    },
    enlightenment = {
        danger = 10000,
        Dynamic = false,
        warning = 20000,
        caution = 50000,
    },
    endeavor = {
    },
    equipped = {
    },
    esoplus = {
        active = false,
        caution = 10,
        critical = 1,
        danger = 3,
        dateformat = "%Y-%m-%d",
        Dynamic = true,
        period = 30,
        start = 0,
        warning = 5,
    },
    experience = {
        DisplayPreference = "% towards next level/CP",
    },
    food = {
        critical = 120,
        danger = 300,
        DisplayPreference = "simple",
        Dynamic = true,
        PulseAfter = false,
        warning = 600,
    },
    fps = {
        caution = 40,
        danger = 15,
        Fixed = false,
        FixedLength = 20,
        good = true,
        warning = 30,
    },
    fortunes = {
    },
    ft = {
        DisplayPreference = "time left/cost",
        Dynamic = true,
        good = false,
        TimerDisplayPreference = "simple",
    },
    gadgets = {
        pve = { "level", "experience", "bag", "bank", "gold", "clock" },
        pvp = { "level", "experience", "bag", "bank", "gold", "clock" },
    },
    gadgetTextEnabled = { },
    gold = {
        DisplayPreference = "on character",
        TooltipPreference = "on character",
        high = {
            danger = 999999999,
            warning = 999999999,
        },
        low = {
            danger = 0,
            warning = 0,
        },
    },
    imperial = {
    },
    kc = {
        DisplayPreference = "Killing Blows/Deaths (Kill Ratio)",
    },
    latency = {
        caution = 100,
        danger = 500,
        Fixed = false,
        FixedLength = 30,
        good = true,
        warning = 200,
    },
    leads = {
        Dynamic = true,
        critical = 4,
        danger = 3,
        warning = 2,
        caution = 1,
        ultrashort = 6,  -- hours
        short = 24,
        medium = 3,     -- days
        long = 7,
    },
    level = {
        cp = { true, true, true, },
        notmax = {
            icon = 1,
            cp = false,
            DisplayPreference = 1,
            Dynamic = true,
        },
        max = {
            icon = 1,
            cp = true,
            DisplayPreference = 3,
            Dynamic = true,
        },
    },
    location = {
        DisplayPreference = "(x, y) Zone Name",
    },
    mail = {
        critical = false,
        Dynamic = true,
        good = false,
    },
    memory = {
        caution = 256,
        danger = 768,
        good = true,
        warning = 512,
    },
    mount = {
        critical = false,
        DisplayPreference = "simple",
        Dynamic = true,
        good = false,
    },
    mundus = {
        DisplayPreference = "Full",
    },
    outfit = {
    },
    poison = {
        critical = 5,
        danger = 10,
        warning = 20,
    },
    research = {
        DisplayAllSlots = true,
        DisplayPreference = "simple",
        Dynamic = true,
        FreeText = "--",
        ShortestOnly = false,
    },
    skyshards = {
        DisplayPreference = "collected/unspent points",
    },
    soulgems = {
        DisplayPreference = "total filled/empty",
    },
    tomepoints = {
    },
    tometokens = {
    },
    transmute = {
        caution = 2800,
        warning = 2900,
        danger = 2950,
    },
    tt = {
        caution = 20,
        danger = 10,
        DisplayPreference = "stolen treasures/stolen goods (lockpicks)",
        good = true,
        warning = 15,
    },
    telvar = {
        DisplayPreference = "on character",
        TooltipPreference = "on character",
        high = {
            danger = 999999999,
            warning = 999999999,
        },
        low = {
            danger = 0,
            warning = 0,
        },
    },
    undaunted = { },
    vampirism = {
        TimerPreference = "short",
        DisplayPreference = "Stage (Timer)",
        Dynamic = true,
    },
    wc = {
        AutoPoison = true,
        critical = 10,
        danger = 25,
        good = true,
        warning = 50,
    },
    writs = {
        DisplayPreference = "on character",
        TooltipPreference = "on character",
        high = {
            danger = 999999999,
            warning = 999999999,
        },
        low = {
            danger = 0,
            warning = 0,
        },
    },
}

-- auxiliary tables

local colorsMenu = {
    { name = "normal",    desc = "Normal color",    tooltip = "Color for normal values and plain text", },
    { name = "header",    desc = "Header color",    tooltip = "Color for tooltip headers", },
    { name = "highlight", desc = "Highlight color", tooltip = "Color for highlights", },
    { name = "active",    desc = "Active color",    tooltip = "Color for 'active' values", },
    { name = "good",      desc = "Good color",      tooltip = "Color for 'good' values (also used for tracked characters)", },
    { name = "caution",   desc = "Caution color",   tooltip = "Color for 'caution' values", },
    { name = "warning",   desc = "Warning color",   tooltip = "Color for 'warning' values", },
    { name = "danger",    desc = "Danger color",    tooltip = "Color for 'danger' values", },
    { name = "critical",  desc = "Critical color",  tooltip = "Color for 'critical' values", },
    { name = "stage1",    desc = "Vampire stage 1", tooltip = "Color for vampirism gadget at stage 1", },
    { name = "stage2",    desc = "Vampire stage 2", tooltip = "Color for vampirism gadget at stage 2", },
    { name = "stage3",    desc = "Vampire stage 3", tooltip = "Color for vampirism gadget at stage 3", },
    { name = "stage4",    desc = "Vampire stage 4", tooltip = "Color for vampirism gadget at stage 4", },
    { name = "stage5",    desc = "Vampire stage 5", tooltip = "Color for vampirism gadget at stage 5", },
}

local mundusStoneReference = {
    Full = {
        "Warrior", "Mage", "Thief", "Serpent", "Lady", "Steed", "Lord",
        "Apprentice", "Atronach", "Ritual", "Lover", "Shadow", "Tower",
    },
    Abbreviated = {
        "Warr", "Mage", "Thf", "Serp", "Lady", "Std", "Lord",
        "Appr", "Atro", "Rit", "Lvr", "Shad", "Twr",
    },
}

local equipSlotReference = {
    [0] = "head",
    [2] = "chest",
    [3] = "shoulders",
    [6] = "waist",
    [8] = "legs",
    [9] = "feet",
    [16] = "hands",
}

local ClassNames = {
    "Dragon Knight", "Sorcerer", "Night Blade", "Warden", "Necromancer", "Templar", [117] = "Arcanist", 
}

local classTexture = {
    "dragonknight", "sorcerer", "nightblade", "warden", "necromancer", "templar", [117] = "arcanist",
}

local timeFormats = {
    ["24h"] = "%H:%M",
    ["24h with seconds"] = "%H:%M:%S",
    ["12h"] = "%I:%M %p",
    ["12h no leading zero"] = "%I:%M %p",
    ["12h with seconds"] = "%I:%M:%S %p",
}

local traitReference = {
    "Powered", "Charged", "Precise", "Infused", "Defending", "Training", "Sharpened", "Decisive",
    "Intricate", "Ornate", "Sturdy", "Impenetrable", "Reinforced", "Well Fitted", "Training", "Infused",
    "Invigorating", "Divines", "Ornate", "Intricate", "Healthy", "Arcane", "Robust", "Ornate",
    "Nirnhoned", "Nirnhoned", "Intricate", "Swift", "Harmony", "Triune", "Bloodthirsty", "Protective", "Infused",
}

local crafts = {
    ["blacksmithing"] = { icon = TEBTopResearchResearchBlacksmithingIcon, id = CRAFTING_TYPE_BLACKSMITHING },
    ["clothing"] = { icon = TEBTopResearchClothingIcon, id = CRAFTING_TYPE_CLOTHIER },
    ["woodworking"] = { icon = TEBTopResearchWoodworkingIcon, id = CRAFTING_TYPE_WOODWORKING },
    ["jewelry"] = { icon = TEBTopResearchJewelryCraftingIcon, id = CRAFTING_TYPE_JEWELRYCRAFTING },
}

local iconPriorities = { normal = 1, caution = 2, warning = 3, danger = 4, critical = 5,  }

local function research_visible(key)
    return function()
        return settings.research.Dynamic == "always" or
        settings.research.Dynamic == 'running' and G[key].TimerRunning or
        settings.research.Dynamic == 'free' and G[key].freeSlots > 0
    end
end

local conditionsTable = {
    blacksmithing   = research_visible("blacksmithing"),
    clothing        = research_visible("clothing"),
    woodworking     = research_visible("woodworking"),
    jewelry         = research_visible("jewelry"),
    bounty          = function() return G.bounty.TimerRunning or not settings.bounty.Dynamic end,
    companion       = function() return G.companion.present or not settings.companion.Dynamic end,
    enlightenment   = function() return G.enlightenment.Visible or not settings.enlightenment.Dynamic end,
    esoplus         = function() return not settings.esoplus.Dynamic or G.esoplus.active end,
    food            = function() return G.food.TimerRunning or not settings.food.Dynamic or settings.food.PulseAfter and G.foodBuffWasActive end,
    ft              = function() return G.ft.TimerRunning or not settings.ft.Dynamic end,
    leads           = function() return G.leads.leadsExpiring or not settings.leads.Dynamic end,
    mail            = function() return G.mail.Unread or not settings.mail.Dynamic end,
    mount           = function() local D = settings.mount.Dynamic; return D == "always" or D == "maxed" and not G.mount.TimerMaxed or D == "free" and not G.mount.TimerRunning or D == "running" and G.mount.TimerRunning or D == "allmaxed" and not G.mount.allmaxed end,
    vampirism       = function() return G.isVampire or not settings.vampirism.Dynamic end,
}

local scenes = { 
    -- show bar in these scenes
    hud = true,
    hudui = true,
    -- and check if it should be shown/hidden in these 
    bank = "Bank",
    guildBank = "GuildBank",
    smithing = "Crafting",
    enchanting = "Crafting",
    interact = "Chatter",
    store = "Store",
    stables = "Store",
    tradinghouse = "GuildStore",
    antiquityDigging = "Digging",
 }

-- auxiliary tables for global variable updaters

local apTooltips = {
    ["Total Points"] = "Total Alliance Points.",
    ["Session Points"] = "Session Alliance Points.",
    ["Points Per Hour"] = "Alliance Points/hour.",
    ["Total Points/Points Per Hour"] = "Total Alliance Points/Points hr.",
    ["Session Points/Points Per Hour"] = "Session Points/Points hr.",
    ["Total Points/Session Points"] = "Total Alliance Points/Session Points.",
    ["Total Points/Session Points (Points Per Hour)"] = "Total Points/Session Points (Points/hr).",
    ["Total Points/Session Points/Points Per Hour"] = "Total Points/Session Points/Points hr.",
}

local apFormats = {
    ["Total Points"] = "<<1>>",
    ["Session Points"] = "<<2>>",
    ["Points Per Hour"] = "<<3>>",
    ["Total Points/Points Per Hour"] = "<<1>>/<<3>>",
    ["Session Points/Points Per Hour"] = "<<2>>/<<3>>",
    ["Total Points/Session Points"] = "<<1>>/<<2>>",
    ["Total Points/Session Points (Points Per Hour)"] = "<<1>>/<<2>> (<<3>>)",
    ["Total Points/Session Points/Points Per Hour"] = "<<1>>/<<2>>/<<3>>",
}

local bangToolTips = {
    ["used%"] = "Percentage of %s space used.",
    ["slots free/total slots"] = "%s space free / maximum size.",
    ["slots free"] = "%s space free.",
    ["free%"] = "Percentage of %s space free.",
}

local bagFormats = {
    ["slots used/total slots"] = "<<1>>/<<3>>",
    ["used%"] = "<<4>>",
    ["slots free/total slots"] = "<<2>>/<<3>>",
    ["slots free"] = "<<2>>",
    ["free%"] = "<<5>>",
}

local monthNames = {
    -- Imperial
    I = {
        "Morning Star",  "Sun's Dawn",   "First Seed",
        "Rain's Hand",   "Second Seed",  "Midyear",
        "Sun's Height",  "Last Seed",    "Hearthfire",
        "Frostfall",     "Sun's Dusk",   "Evening Star",
    },
    -- Argonian
    A = {
        "Vakka",            "Xeech",        "Sisei",
        "Hist-Deek",        "Hist-Dooka",   "Hist-Tsoko",
        "Thtithil-Gah",     "Thtithil",     "Nushmeeko",
        "Shaja-Nushmeeko",  "Saxhleel",     "Xulomaht",
    }
}

local clockFormats = {
    ["ingame time"] = "<<1>>",
    ["UTC time"] = "<<2>>",
    ["local time"] = "<<3>>",
    ["local date and time"] = "<<4>> <<3>>",
    ["local time/ingame time"] = "<<3>>/<<1>>",
}

local companion_info = {
    { "name", "Name:", "<<1>>" },
    { "XP", "Experience:", "<<1>>" },
    { "XPPercent", "% of next level", "<<1>>%" },
    { "level", "Level:", "L<<1>>" },
    { "rapport", "Rapport:", "<<1>>" },
    { "rapportLevel", "Rapport level:", "<<1>>" },
    { "rapportLevelDesc", "", "<<1>>" }
}

local durabilityFormats = {
    ["durability %" ] = "<<1>>%",
    ["durability %/repair cost" ] = "<<1>>%/<<2>>",
    ["repair cost" ] = "<<2>>",
    ["durability % (repair kits)" ] = "<<1>>% (<<3>>)",
    ["durability %/repair cost (repair kits)" ] = "<<1>>%/<<2>> (<<3>>)",
    ["repair cost (repair kits)" ] = "<<2>> (<<3>>)",
    ["most damaged" ] = "<<4>>",
    ["most damaged/durability %" ] = "<<4>>/<<5>>%",
    ["most damaged/durability %/repair cost" ] = "<<4>>/<<5>>%/<<6>>g",
    ["most damaged/repair cost" ] = "<<4>>/<<6>>g",
}

local repairKits = {
    { "grandRepairKit", "Equipment Repair Kit", },
    { "crownRepairKit", "Crown Repair Kit", },
    { "groupRepairKit", "Group Repair Kit", },
}

local lockStates = { "normal", "caution", "warning", "danger", }

local XPTooltips = {
    ["% towards next level/CP"   ] = "Experience towards next %s." ,
    ["% needed for next level/CP"] = "Experience needed for next %s.",
    ["current XP"                ] = "Current experience.",
    ["needed XP"                 ] = "Needed experience for next %s.",
    ["current XP/total needed"   ] = "Current experience/total experience needed.",
}

local constellation_map = {
    {"craft", "stamina"}, {"warfare", "magicka"}, {"fitness", "health"},
}

local currencies = { 
    "ap", "crowngems", "crowns", "endeavor", "fortunes", "gold", "imperial", "outfit",
		"telvar", "tomepoints", "tometokens", "tradebars", "transmute", "undaunted", "writs",
}

local global_currencies = {
    crowngems      = CURT_CROWN_GEMS,
    crowns         = CURT_CROWNS,
    endeavor       = CURT_ENDEAVOR_SEALS,
    fortunes       = CURT_ENDLESS_DUNGEON,
    imperial       = CURT_IMPERIAL_FRAGMENTS,
    outfit         = CURT_STYLE_STONES,
    tomepoints     = CURT_TOME_POINTS,
    tometokens     = CURT_TOME_TOKENS,
    tradebars      = CURT_TRADE_BARS,
    transmute      = CURT_CHAOTIC_CREATIA,
    undaunted      = CURT_UNDAUNTED_KEYS,
}

local non_global_currencies = {
    gold    = CURT_MONEY,
    ap      = CURT_ALLIANCE_POINTS,
    telvar  = CURT_TELVAR_STONES,
    writs   = CURT_WRIT_VOUCHERS,
}

local currencyToolTips = {
    ["on character"] = "<<1>> on your character.",
    ["on character/in bank"] = "<<1>> on your character / in the bank.",
    ["on character (in bank)"] = "<<1>> on your character (<<1>> in the bank).",
    ["character+bank"] = "<<1>> on your character + bank.",
    ["tracked"] = "<<1>> on all tracked characters.",
    ["tracked+bank"] = "<<1>> on all tracked characters + bank.",
    ["total"] = "<<1>> on all characters + bank.",
    ["on character/total"] = "<<1>> on your character / on all characters + bank.",
    ["on character (total)"] = "<<1>> on your character (<<1>> on all characters + bank.",
}

local itemsInSlot = {
    [33271] = "normal_filled",
    [61080] = "crown_filled",
    [33265] = "empty",
    [44879] = "grandRepairKit",
    [61079] = "crownRepairKit",
    [157516] = "groupRepairKit",
    -- to initialize G[n] in the same loop
    treasures       = "treasures" ,
    not_treasures   = "not_treasures",
    stolen          = "stolen",
    junk            = "junk",
}

local infamyLevels = {
    [INFAMY_THRESHOLD_UPSTANDING] = { "Upstanding", "normal", },
    [INFAMY_THRESHOLD_DISREPUTABLE] = { "Disreputable", "warning", },
    [INFAMY_THRESHOLD_NOTORIOUS] = { "Notorious", "danger", },
    [INFAMY_THRESHOLD_FUGITIVE] = { "Fugitive", "critical", },
}

local lvlFormats = { "<<1>>", "<<1>>/<<2>>", "<<2>>", }

local locationToolTips = {
    ["(x, y) Zone Name"] = "(Coordinates) Zone Name.",
    ["Zone Name (x, y)"] = "Zone Name (Coordinates).",
    ["Zone Name"] = "Current zone name.",
    ["x, y"] = "Current coordinates.",
}

local locationFormats = {
    ["(x, y) Zone Name"] = "(<<2>>) <<1>>",
    ["Zone Name (x, y)"] = "<<1>> (<<2>>)",
    ["Zone Name"] = "<<1>>",
    ["x, y"] = "<<2>>",
}

local pvpFormats = {
    ["Assists/Killing Blows/Deaths (Kill Ratio)"] = "<<2>>/<<1>>/<<3>> (<<4>>)",
    ["Assists/Killing Blows/Deaths"] = "<<2>>/<<1>>/<<3>>",
    ["Killing Blows/Deaths (Kill Ratio)"] = "<<1>>/<<3>> (<<4>>)",
    ["Killing Blows/Deaths"] = "<<1>>/<<3>>",
    ["Kill Ratio"] = "<<4>>",
}

local skyshardsToolTips = {
    ["collected/unspent points"] = "Collected skyshards / unspent skill points.",
    ["collected"] = "Collected skyshards.",
    ["collected/total needed (unspent points)"] = "Collected skyshards/total needed for skill point (unspent skill points).",
    ["needed/unspent points"] = "Needed skyshards / unspent skill points.",
    ["needed"] = "Needed skyshards.",
}

local skyshardsFormats = {
    ["collected/unspent points"] = "<<1>>/<<2>>",
    ["collected/total needed (unspent points)"] = "<<1>>/3 (<<2>>)",
    ["collected"] = "<<1>>",
    ["needed/unspent points"] = "<<3>>/<<2>>",
    ["needed"] = "<<3>>",
}

local ftToolTips = {
    ["time left"] = "Recall time left until cheapest.\n",
    ["cost"] = "Recall current cost.\n",
    ["time left/cost"] = "Recall time left until cheapest/cost.\n",
}

local soulgemToolTips = {
    ["total filled/empty"] = "Total filled / empty soul gems.",
    ["total filled (crown)/empty"] = "Total filled (crown filled) / empty soul gems.",
    ["total filled (empty)"] = "Total filled (empty) soul gems.",
    ["normal filled/crown/empty"] = "Normal filled / crown / empty soul gems.",
    ["total filled"] = "Total filled soul gems.",
    ["normal filled"] = "Normal filled soul gems.",
}

local soulgemsFormats = {
    ["total filled/empty"] =  "<<1>>/<<4>>",
    ["total filled (crown)/empty"] = "<<1>> (<<3>>)/<<4>>",
    ["total filled (empty)"] = "<<1>> (<<4>>)",
    ["normal filled/crown/empty"] = "<<2>>/<<3>>/<<4>>",
    ["total filled"] = "<<1>>",
    ["normal filled"] = "<<2>>",
}

local ttFormats = {
    ["stolen treasures/stolen goods"] = "<<1>><<5>><<2>>",
    ["stolen treasures/stolen goods fence_remaining/launder_remaining"] = "<<1>><<5>><<2>> <<3>><<5>><<4>>",
    ["stolen treasures/fence_remaining stolen goods/launder_remaining"] = "<<1>><<5>><<3>> <<2>><<5>><<4>>",
}

-- auxiliary functions

local function round(val, decimal)
    local divisor = 10 ^ (decimal or 0) -- 10 ^ 0 == 1
    return math.floor( val * divisor + 0.5) / divisor
end

local function ucfirst(s)
    return s:sub(1,1):upper() .. s:sub(2)
end

local function SortKeys(T)
    local tempKeys = {}
    for k in pairs(T) do
        table.insert(tempKeys, k)
    end
    table.sort(tempKeys)
    return tempKeys
end


local function SortCharacters(T)
    if G.characterSortCache then 
        return G.characterSortCache
    end
    -- initialize slot table
    local slot = {}
    for i = 1, GetNumCharacters() do
        local name = GetCharacterInfo(i)
        name = string.sub(name, 1, -4)
        slot[name] = i
    end
    -- skip nonexistent characters
    local tempKeys = {}
    for k in pairs(T) do
        if slot[k] then
            table.insert(tempKeys, k)
        end
    end
    if settings.bar.sort then
        -- sort by slot number rather than by name
        table.sort(tempKeys, function(a, b) return slot[a] < slot[b] end)
    else
        table.sort(tempKeys)
    end
    -- cache present sort order
    G.characterSortCache = tempKeys
    return tempKeys
end

local function ShowBar()
    G.hideBar = false
end

-- scene detection for autohiding
local function SceneChange(scene, newState) 
    if newState == "showing" then
        local sceneName = scene:GetName()
        local sceneType = scenes[sceneName]
        if sceneType == true then 
            -- HUD 
            ShowBar()
        elseif sceneType ~= nil then
            -- Bank, Crafting etc.
            G.hideBar = settings.autohide[sceneType]
        else
            -- everything else is a menu (or close enough)
            G.hideBar = settings.autohide["GameMenu"]
        end
    end
end
    

local function ShowToolTip(gadgetKey)
    local gadgetData = gadgetReference[gadgetKey]
    local gadget = gadgetData.icon
    local g = G[gadgetKey]
    TEBTooltipLeft:SetText(g.Left)
    TEBTooltipRight:SetText(g.Right)
    TEBTooltip:SetHeight(TEBTooltipLeft:GetHeight())
    TEBTooltip:SetWidth(TEBTooltipLeft:GetWidth() + TEBTooltipRight:GetWidth() + G.spacer)
    if gadget:GetTop() > G.screenHeight / 2 then
        TEBTooltip:SetAnchor(TOPLEFT, gadget, BOTTOMRIGHT, -12, -12 - TEBTop:GetHeight() - TEBTooltip:GetHeight())
    else
        TEBTooltip:SetAnchor(TOPLEFT, gadget, BOTTOMRIGHT, -12, 12)
    end
    TEBTooltip:SetHidden(false)
end

local function HideTooltip()
    TEBTooltip:SetHidden(true)
end

local function FillColors(name_color_table)
    for k, v in pairs(name_color_table) do
        G.colors[k] = ZO_ColorDef:New(v)
    end
end

local function Upgrade_from_6(sv_data)
    table.insert(TEB.debug, "Upgrading from 6\n")
    local move_to_bar_subtable = {
        backdropOpacity = "backgroundOpacity",
        barLayer = "Layer",
        barLocked = "Locked",
        barPosition = "Position",
        barY = "Y",
        bumpActionBar = "bumpActionBar",
        bumpCompass = "bumpCompass",
        combatIndicator = "combatIndicator",
        combatOpacity = "combatOpacity",
        controlsPosition = "controlsPosition",
        font = "font",
        gadgetsLocked = "gadgetsLocked",
        icons_Mode = "iconsMode",
        chatMessagesOn = "chatMessagesOn",
        pulseType = "pulseType",
        pulseWhenCritical = "pulseWhenCritical",
        scale = "scale",
        thousandsSeparator = "thousandsSeparator",
        Width = "Width",
    }
    -- create subtables
    for k, _ in pairs(defaults) do
        if sv_data[k] == nil then
            sv_data[k] = { }
        end
    end
    -- create "v6" list of keys
    local keys = { et = "eventtickets", gadgetsText = "gadgetTextEnabled", } -- does not exist in v9 and later
    for k in pairs(defaults) do
        keys[k] = k
    end

    -- analyze the data
    for old_key, old_v in pairs(sv_data) do
        table.insert(TEB.debug, string.format("# %s\n", old_key))
        local new_subkey = move_to_bar_subtable[old_key]
        if new_subkey then
            table.insert(TEB.debug, string.format("bar.%s = %s\n", new_subkey, old_key))
            sv_data.bar[new_subkey] = old_v
            sv_data[old_key] = nil
        elseif old_key == "gadgets" then
            sv_data.gadgets_pve = old_v
            sv_data.gadgets = nil
        elseif old_key ~= "gadgets_pvp" then
            for k, v in pairs(keys) do
                local c_start, c_end = string.find(old_key, k)
                if c_start and c_start == 1 and c_end < string.len(old_key) then
                    -- remove prefix (including _ if present)
                    new_subkey = old_key:sub(c_end+1, c_end+1) == '_' and
                        old_key:sub(c_end+2, -1) or old_key:sub(c_end+1, -1)
                    if new_subkey == "Critical" or new_subkey == "Danger" or
                        new_subkey == "Warning" or new_subkey == "Caution" then
                        new_subkey = string.lower(new_subkey)
                    end
                    if sv_data[v] then
                        sv_data[v][new_subkey] = old_v
                    end
                    table.insert(TEB.debug, string.format("%s.%s = %s\n", k, new_subkey, old_key))
                    sv_data[old_key] = nil
                end
            end
        end
    end
    for old, new in pairs({ ["Bounty Timer"] = "Bounty/Heat Timer",
                            ["Weapon Charge"] = "Weapon Charge/Poison" }) do
        table.insert(TEB.debug, string.format("%s -> %s\n", old, new))
        for _, submenu in ipairs({"gadgetTextEnabled", "iconIndicator"}) do
            sv_data[submenu][new] = sv_data[submenu][old]
            sv_data[submenu][old] = nil
        end
        for _, submenu in ipairs({"gadgets_pve", "gadgets_pvp"}) do
            if sv_data[submenu] then
                for i = 1, #sv_data[submenu] do
                    if sv_data[submenu][i] == old then
                        sv_data[submenu][i] = new
                    end
                end
            end
        end
    end
end

local function Upgrade_from_7(sv_data)
    if sv_data.version ~= 7 then Upgrade_from_6(sv_data) end
    table.insert(TEB.debug, "Upgrading from 7\n")
    if not sv_data.gadgets then
        sv_data.gadgets = { }
        for new, old in pairs({ pve = "gadgets_pve", pvp = "gadgets_pvp" }) do
        table.insert(TEB.debug, string.format("%s -> %s\n", old, new)           )
            if sv_data[old] then
                sv_data.gadgets[new] = {}
                for i, v in ipairs(sv_data[old]) do
                    if v ~= "(None)" and v ~= "" then
                        table.insert(sv_data.gadgets[new], v)
                    end
                end
                sv_data[old] = nil
            end
        end
    end
    for k, v in pairs(sv_data) do
        if type(v) == "table" and v.Good ~= nil then
            if v.good == nil then
                v.good = v.Good
            end
            v.Good = nil
        end
    end
    if sv_data.bar.scale then
        if sv_data.bar.scale > 1 then
            sv_data.bar.scale = sv_data.bar.scale / 100
        elseif sv_data.bar.scale < 0.01 then
            sv_data.bar.scale = sv_data.bar.scale * 100
        end
    else
        sv_data.bar.scale = 1
    end
    if not sv_data.poison and sv_data.wc then
        sv_data.poison = {
            warning = sv_data.wc.PoisonWarning,
            danger = sv_data.wc.PoisonDanger,
            critical = sv_data.wc.PoisonCritical,
        }
        sv_data.wc.PoisonWarning, sv_data.wc.PoisonDanger, sv_data.wc.PoisonCritical = nil, nil, nil
    end
    if not sv_data.mundus.Tracker then sv_data.mundus.Tracker = {} end
    for _, tracked in ipairs({ "gold", "mount", "mundus" }) do
        -- grab and sort Tracker keys
        local t = {}
        for k, _ in pairs(sv_data[tracked].Tracker) do
            table.insert(t, k)
        end
        table.sort(t)
        if #t > 1 then
        --[[ if two consecutive keys differ only in case, remove the former -
                it has caps in wrong places due to bug in original TEB ]]--
            local candidate = t[1]
            for i = 2, #t do
                if string.lower(candidate) == string.lower(t[i]) then
                    sv_data[tracked].Tracker[candidate] = nil
                end
                candidate = t[i]
            end
        end
    end
end

local function Upgrade_from_8(sv_data)
    if sv_data.version ~= 8 then Upgrade_from_7(sv_data) end
    table.insert(TEB.debug, "Upgrading from 8\n")
    sv_data.endeavor        = sv_data.es
    sv_data.eventtickets    = sv_data.et
    sv_data.transmute       = sv_data.tc
    sv_data.undaunted       = sv_data.uk
    sv_data.es = nil
    sv_data.et = nil
    sv_data.tc = nil
    sv_data.uk = nil
    sv_data.vampirism.StageColor = nil
end

local function Upgrade_from_9(sv_data)
    if sv_data.version ~= 9 then Upgrade_from_8(sv_data) end
    table.insert(TEB.debug, "Upgrading from 9\n")
    -- create reverse mapping
    local rev = { }
    local k, v
    for k, v in pairs(gadgetReference) do
        rev[v.name] = k
    end
    table.insert(TEB.debug, "reverse mapping done\n")

    local function iconv(x)
        if not x then return {} end
        local indices = { }
        local k, _
        for k in pairs(x) do
            indices[#indices+1] = k
        end
        table.sort(indices)
        -- now indices are monotonous, but might have holes and duplicates
        local result = { }
        local last
        for _, k in ipairs(indices) do
            if last ~= k and x[k] ~= "" then
                result[#result+1] = rev[x[k]]
                last = k
            end
        end
        -- result has no holes nor duplicates in indices and no empty strings in values
        return result
    end

    local function conv(x)
        local k, v
        local result = { }
        for k, v in pairs(x) do
            if rev[k] then
                result[rev[k]] = v
            end
        end
        return result
    end

    -- convert arrays, removing duplicates
    if sv_data.gadgets then
        sv_data.gadgets.pve = iconv(sv_data.gadgets.pve)
        sv_data.gadgets.pvp = iconv(sv_data.gadgets.pvp)
    end
    -- convert tables
    sv_data.gadgetTextEnabled = conv(sv_data.gadgetTextEnabled)
    sv_data.gadgetText = nil
end

local function Upgrade_from_10(sv_data)
    if sv_data.version < 10 then Upgrade_from_9(sv_data) end
    table.insert(TEB.debug, "Upgrading from 10\n")
    sv_data.Trackers = { }
    for _, k in ipairs({ "ap", "gold", "mount", "mundus", "telvar", "writs", }) do
        if sv_data[k].Tracker then
            sv_data.Trackers[k] = sv_data[k].Tracker 
            sv_data[k].Tracker = nil
        end
    end        
end

local function Upgrade_from_11(sv_data)
    if sv_data.version < 11 then Upgrade_from_10(sv_data) end
    table.insert(TEB.debug, "Upgrading from 11\n")
    if sv_data.bar.pulseType == 'slow blink' then 
        sv_data.bar.pulseType = 'blink'
        sv_data.bar.pulseSpeed = 10
    elseif sv_data.bar.pulseType == 'fast blink' then 
        sv_data.bar.pulseType = 'blink'
        sv_data.bar.pulseSpeed = 2
    elseif sv_data.bar.pulseType == 'slow fade in/out' then 
        sv_data.bar.pulseType = 'fade in/out'
        sv_data.bar.pulseSpeed = 10
    end
end

local function Upgrade_from_12(sv_data)
    if sv_data.version < 12 then Upgrade_from_11(sv_data) end
    table.insert(TEB.debug, "Upgrading from 12\n")
    sv_data.eventtickets = nil
    for i, d in ipairs(sv_data.gadgets.pve) do
        if d == "eventtickets" then
            sv_data.gadgets.pve[i] = nil
        end
    end
    for i, d in ipairs(sv_data.gadgets.pvp) do
        if d == "eventtickets" then
            sv_data.gadgets.pvp[i] = nil
        end
    end
    table.insert(TEB.debug, "conversion done\n")        
end

local function ConvertSeconds(displayMethod, seconds)
    local struct = os.date("!*t", seconds)
    local exact_time = os.date("!%Hh%Mm%Ss", seconds)
    struct.yday = struct.yday - 1 -- yday is never 0 - New Year is 1st day of the year, not 0th
    if displayMethod == "exact" then
        return (struct.yday > 0 and string.format("%dd", struct.yday) or "") .. exact_time
    elseif displayMethod == "short" then
        return struct.yday > 0 and string.format("%dd%dh", struct.yday, struct.hour) or
        struct.hour > 0 and string.format("%dh%dm", struct.hour, struct.min) or
        struct.min > 0 and string.format("%dm%ds", struct.min, struct.sec) or
        string.format("%ds", struct.sec)
    elseif displayMethod == "simple" then
        return struct.yday > 0 and string.format("%dd", struct.yday) or
        struct.hour > 0 and string.format("%dh", struct.hour) or
        struct.min > 0 and string.format("%dm", struct.min) or
        string.format("%ds", struct.sec)
    end
end

local function SetWidth(setting, gadget)
    if setting.Fixed then
        gadget:SetWidth(setting.FixedLength)
    else
        local x = gadget:GetTextWidth()
        gadget:SetWidth(x)
    end
end

local function SetBarLayer()
    TEBTop:SetDrawLayer(settings.bar.Layer)
    TEBTooltip:SetDrawLayer(1)
end

local function SetOpacity()
    local EdgeWidth = 16
    local edgePath = settings.bar.edgedBackground and "EsoUI/Art/Tooltips/UI-Border.dds" or
        "EsoUI/Art/Tooltips/UI-TooltipCenter.dds"
    TEBTopBG:SetEdgeTexture(edgePath, 128, 16)
    TEBTopBG:SetInsets(EdgeWidth, EdgeWidth, -EdgeWidth, -EdgeWidth)
    TEBTopCombatBG:SetEdgeTexture("TEB/Images/combat-border.dds", 128, 16)
    TEBTopCombatBG:SetInsets(EdgeWidth, EdgeWidth, -EdgeWidth, -EdgeWidth)
    TEBTopBG:SetAlpha(settings.bar.backgroundOpacity)
    TEBTop:SetAlpha(settings.bar.opacity)
end

local function SetIcon(gadgetKey, iconStyle)
    local gadgetData = gadgetReference[gadgetKey]
    local fileName, colorTag
    if gadgetKey == "companion" then
        fileName = G.companion.icon
    elseif gadgetKey == "lock" then
        fileName = string.format("TEB/Images/lock_%s.dds", iconStyle)
    else
        -- bar.iconsMode : white, color
        -- iconStyle: good, normal, caution, warning, danger, critical
        colorTag = settings.bar.iconsInherit and "white" or settings.bar.iconsMode
		local currency = global_currencies[gadgetKey] or non_global_currencies[gadgetKey]
		if currency and colorTag ~= "white" then
            fileName = ZO_Currency_GetPlatformCurrencyIcon(currency)
		else
	        fileName = string.format("TEB/Images/%s_%s.dds", gadgetKey, colorTag)
		end
        -- critical -> danger
        iconStyle = iconStyle == "critical" and "danger" or iconStyle
        if settings.bar.iconsInherit then
            gadgetData.icon:SetColor(G.colors[iconStyle]:UnpackRGBA())
        end
    end
    if gadgetData.texture ~= fileName then
        gadgetData.texture = fileName
        if gadgetKey == "lock" then
            gadgetData.icon:SetNormalTexture(fileName) -- a Button!
        else
            gadgetData.icon:SetTexture(fileName) -- a Texture
        end
    end
end

local function AddToMountDatabase(character)
    local foundCharacter = false
    for k, v in pairs(settings.Trackers.mount) do
        if k == character then
            foundCharacter = true
        end
    end
    local mountTimeLeft = GetTimeUntilCanBeTrained() / 1000
    local trainTime = os.time() + mountTimeLeft

    if settings.Trackers.mount[character] then
        local characterTracked = settings.Trackers.mount[character][1]
        local savedTrainTime = settings.Trackers.mount[character][2]
        if not STABLE_MANAGER:IsRidingSkillMaxedOut() and savedTrainTime ~= -1 then
            settings.Trackers.mount[character] = {characterTracked, trainTime}
        else
            settings.Trackers.mount[character] = {false, -1}
        end
    else
        if not STABLE_MANAGER:IsRidingSkillMaxedOut() then
            settings.Trackers.mount[character] = { true, trainTime }
        end
    end
end

local function RebuildMountTrackerList()
    G.trackerDropdown = {}
    G.trackerDropdown[1] = "(choose a character)"
    local index = 2
    for k, v in pairs(settings.Trackers.mount) do
        if v[2] ~= -1 then
            G.trackerDropdown[index] = string.format("%s (%stracked)", k, v[1] and "" or "un")
            index = index + 1
        end
    end
end

local function DisableMountTracker()
    return not settings.Trackers.mount[G.characterName]
end

local function DisableGoldTracker(key)
    return not settings.Trackers[key][G.characterName] or not settings.Trackers[key][G.characterName][1]
end

local function GetCharacterGoldTracked(key)
    return settings.Trackers[key][G.characterName] and
        settings.Trackers[key][G.characterName][1] or false
end

local function GetCharacterMountTracked()
    return TEB.settings.Trackers.mount[G.characterName] and
        TEB.settings.Trackers.mount[G.characterName][1] or false
end

local function SetCharacterMountTracked(track)
    local mountTimeLeft = GetTimeUntilCanBeTrained() / 1000
    local trainTime = os.time() + mountTimeLeft
    local maxed = TEB.settings.Trackers.mount[G.characterName] and TEB.settings.Trackers.mount[G.characterName][3] or false
    TEB.settings.Trackers.mount[G.characterName] = { track, trainTime, maxed }
end

local function SetCharacterGoldTracked(track, key)
    if settings.Trackers[key][G.characterName] then
        local goldCharacter = GetCurrencyAmount(non_global_currencies[key], CURRENCY_LOCATION_CHARACTER)
        settings.Trackers[key][G.characterName] = { track, goldCharacter }
    end
end

local function SetBarWidth(Width)
    local outsideEdgeWidth = 10
    for _, bg in ipairs({ TEBTopBG, TEBTopCombatBG }) do
        if Width == "screen width" then
            -- TEBTop has the full width of screen
            bg:SetAnchor(TOPLEFT, TEBTop, TOPLEFT, -outsideEdgeWidth, -outsideEdgeWidth)
            bg:SetAnchor(BOTTOMRIGHT, TEBTop, BOTTOMRIGHT, outsideEdgeWidth, outsideEdgeWidth)
        else
            -- relative to left and right anchor
            bg:SetAnchor(TOPLEFT, TEBTopStartingAnchor, TOPLEFT, -outsideEdgeWidth, -outsideEdgeWidth)
            bg:SetAnchor(BOTTOMRIGHT, TEBTopEndingAnchor, BOTTOMRIGHT, outsideEdgeWidth, outsideEdgeWidth)
        end
    end
end

local function SetBarPosition()
    if settings.bar.bumpCompass then
        local offset = settings.bar.Position == "top" and
            22 * settings.bar.scale + settings.bar.Y or 0
        ZO_CompassFrame:ClearAnchors()
        ZO_TargetUnitFramereticleover:ClearAnchors()
        ZO_CompassFrame:SetAnchor( TOP, GuiRoot, TOP, 0, G.original.CompassTop + offset )
        ZO_TargetUnitFramereticleover:SetAnchor( TOP, GuiRoot, TOP, 0,
            G.original.TargetUnitFrameTop + offset )
    end
    if settings.bar.bumpActionBar then
        local bottomBump = settings.bar.Position == "bottom" and
            G.screenHeight - settings.bar.Y + 6 or 0
        ZO_ActionBar1:ClearAnchors()
        ZO_PlayerAttributeHealth:ClearAnchors()
        ZO_PlayerAttributeMagicka:ClearAnchors()
        ZO_PlayerAttributeStamina:ClearAnchors()
        ZO_HUDInfamyMeter:ClearAnchors()
        ZO_ActionBar1:SetAnchor( TOP, GuiRoot, TOP, 0, G.original.ActionBarTop - bottomBump )
        ZO_PlayerAttributeHealth:SetAnchor( TOP, GuiRoot, TOP, 
            0, G.original.HealthTop - bottomBump )
        ZO_PlayerAttributeMagicka:SetAnchor( TOPRIGHT, GuiRoot, TOPRIGHT, 
            ZO_PlayerAttributeMagicka:GetRight() - G.screenWidth,
            G.original.MagickaTop - bottomBump)
        ZO_PlayerAttributeStamina:SetAnchor( TOPLEFT, GuiRoot, TOPLEFT,
            ZO_PlayerAttributeStamina:GetLeft(), G.original.StaminaTop - bottomBump)
        ZO_PlayerAttributeMountStamina:SetAnchor(TOPLEFT, ZO_PlayerAttributeStamina, BOTTOMLEFT, 0, 0)
        ZO_HUDInfamyMeter:SetAnchor( TOPLEFT, GuiRoot, TOPLEFT,
            ZO_HUDInfamyMeter:GetLeft(), G.original.BountyTop - bottomBump )
    end
end

local function AddPulseItem(gadgetKey)
    if not gadgetReference[gadgetKey].pulsing then
        gadgetReference[gadgetKey].pulsing = true
        table.insert(G.pulseList, gadgetKey)
    end
end

local function RemovePulseItem(gadgetKey)
    local g = gadgetReference[gadgetKey]
    if g.pulsing then
        g.pulsing = false
        for i = 1, #G.pulseList do
            if G.pulseList[i] == gadgetKey then
                table.remove(G.pulseList, i)
                g.icon:SetAlpha(settings.bar.opacity)
                g.text:SetAlpha(settings.bar.opacity)
            end
        end
    end
end

local function UpdateControlsPosition()
    local controlsWidth = TEBTopEndingAnchor:GetLeft() - TEBTopStartingAnchor:GetLeft()
    local newX
    if settings.bar.controlsPosition == "left" then
        newX = settings.bar.spacing
    elseif settings.bar.controlsPosition == "right" then
        newX = G.screenWidth - controlsWidth - settings.bar.spacing
    else
        newX =  (G.screenWidth - controlsWidth) / 2
    end
    TEBTopStartingAnchor:SetAnchor(LEFT, TEBTop, LEFT, newX, 0)
end

local function ResizeBar()
    local fontPath = string.format("EsoUI/Common/Fonts/%s.otf", settings.bar.font)
    local fontSize = 18 * settings.bar.scale
    local fontOutline = "shadow"
    local barHeight = 22 * settings.bar.scale
    local k, v
    for k, v in pairs(gadgetReference) do
        v.text:SetFont(string.format("%s|%s|%s", fontPath, fontSize, fontOutline))
        v.icon:SetScale(settings.bar.scale)
    end
    TEBTop:SetHeight(barHeight)
    TEBTopStartingAnchor:SetHeight(barHeight)
    TEBTopEndingAnchor:SetHeight(barHeight)
    SetBarWidth(settings.bar.Width)
    UpdateControlsPosition()
end

local function RebuildGadget(g, lastGadget, firstGadgetAdded)
    local gadgetText, gadgetIcon = g.text, g.icon
    gadgetText:SetHidden(false)
    gadgetIcon:SetHidden(false)
    gadgetIcon:SetAnchor(LEFT, lastGadget, RIGHT,
        firstGadgetAdded and settings.bar.spacing * settings.bar.scale or 0, 0)
    firstGadgetAdded = true
    gadgetText:SetAnchor(LEFT, gadgetIcon, RIGHT, 0, 0)
    gadgetText:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    gadgetText:SetMaxLineCount(1)
    return gadgetText, firstGadgetAdded
end

local function RebuildBar()
    local k, g, key
    local lastGadget = TEBTopStartingAnchor
    local firstGadgetAdded = false
    local gadgetList = settings.gadgets[G.pvpMode and "pvp" or "pve"]
    -- hide all gadgets (except the one being moved, if any)
    for k, g in pairs(gadgetReference) do
        if G.movingGadgetKey ~= k then
            g.icon:ClearAnchors()
            g.icon:SetHidden(true)
            g.text:ClearAnchors()
            g.text:SetHidden(true)
        end
    end
    for k, key in ipairs(gadgetList) do
        if key ~= "" and gadgetReference[key] then
            g = gadgetReference[key]
            -- condition is a function or nil
            local condition = conditionsTable[key]
            -- gadget should be shown except when gadgets locked and condition() returns false
            if not settings.bar.gadgetsLocked or not condition or condition() then
                if key == "level" then
                    -- icon for level is special case - either class or cp
                    local iconType = G.lvl < 50 and settings.level.notmax.icon or settings.level.max.icon
                    local iconFormat = iconType ~= 1 and "TEB/Images/cp_%s.dds" or
                        string.format("TEB/Images/class_%s_%%s.dds", classTexture[G.playerClass])
                    local texturePath = string.format(iconFormat, settings.bar.iconsMode )
                    if settings.bar.iconsInherit then
                        texturePath = string.format(iconFormat, "white" )
                        TEBTopLevelIcon:SetColor(G.colors.normal:UnpackRGBA())
                    end
                    TEBTopLevelIcon:SetTexture(texturePath)
                end
                lastGadget, firstGadgetAdded = RebuildGadget(g, lastGadget, firstGadgetAdded)
            end
        end
    end
    TEBTopEndingAnchor:ClearAnchors()
    TEBTopEndingAnchor:SetAnchor(LEFT, lastGadget, RIGHT, 0, 0)
    UpdateControlsPosition()
end

local function KeyLockUnlockBar()
    LockUnlockBar(not settings.bar.Locked)
end

local function KeyLockUnlockGadgets()
    LockUnlockGadgets(not settings.bar.gadgetsLocked)
end

local function LockUnlockBar(newValue)
    settings.bar.Locked = newValue
    TEBTop:SetMovable(not newValue)
    if settings.bar.chatMessagesOn then
        df("The Elder Bar is now %s.",
            G.colors.active:Colorize(newValue and "LOCKED" or "UNLOCKED"))
    end
end

local function LockUnlockGadgets(newValue)
    local k, v
    settings.bar.gadgetsLocked = newValue
    for k, v in pairs(gadgetReference) do
        v.icon:SetMovable(not newValue)
    end
    RebuildBar()
    if settings.bar.chatMessagesOn then
        df("The Elder Bar gadgets are now %s.",
            G.colors.active:Colorize(newValue and "LOCKED" or "UNLOCKED"))
    end
end

local function ToggleLock()
    local newState = not (settings.bar.Locked or settings.bar.gadgetsLocked)
    LockUnlockBar(newState)
    LockUnlockGadgets(newState)
end

-- updates settings.gadgets.{pve, pvp}
local function UpdateGadgetVisibility(key, newValue)
    -- newValue = 1 or 3 - visible on PvE, 2 or 3 - visible on PvP
    local whichBars = { pve = tonumber(newValue) % 2 == 1, pvp = tonumber(newValue) >= 2 }
    for bar, addToBar in pairs(whichBars) do
        local thisBar = settings.gadgets[bar]
        local found
        for i = 1, G.totalGadgets do
            if thisBar[i] == key then
                found = i
            end
        end
        if addToBar and not found then
            -- add if it should be on this bar, but isn't
            table.insert(thisBar, key)
        elseif not addToBar and found then
            -- remove if it shouldn't be on this bar, but is
            table.remove(thisBar, found)
        end
    end
    RebuildBar()
end

-- fills TEB.gadgetVisibility according to settings.gadgets.{pve,pvp}
local function ConvertGadgetVisibility()
    local gadgetVisibility = { }
    for k in pairs(gadgetReference) do
        local g = 0
        for i = 1, G.totalGadgets do
            -- add 1 if k found in settings.gadgets.pve, 2 if k found in settings.gadgets.pvp
            g = g + (settings.gadgets.pve[i] == k and 1 or 0) +
                (settings.gadgets.pvp[i] == k and 2 or 0)
        end
        gadgetVisibility[k] = g
    end
    G.gadgetVisibility = gadgetVisibility
end

local thresholdLevels = { "critical", "danger", "warning", "caution", "normal", }

local function CheckThresholds(testval, direction, group)
--[[
direction == true -> check testval > threshold (upper limits)
direction == false -> check testval < threshold (lower limits)
group is subtree in settings, like settings.food;
values of group[x] for x in thresholdLevels must be descending if direction is true,
ascending otherwise
]]--
    local tag
    if group and testval then
        for _, tag in ipairs(thresholdLevels) do
            if group[tag] then
                if direction and testval >= group[tag] or
                    not direction and testval < group[tag] then
                    return G.colors[tag], tag
                end
            end
        end
    end
    return G.colors.normal, "normal"
end

local function StopMovingBar()
    local barY = TEBTop:GetTop()
    settings.bar.Y = barY
    settings.bar.Position =
        barY < 72 and "top" or barY > G.screenHeight - 144 and "bottom" or "middle"
    SetBarPosition()
    TEBTop:SetDrawLayer(settings.bar.Layer)
end

-- parameter refers to a gadget object
local function StartMovingGadget(gadget)
    local gadgetLeft, gadgetTop = gadget:GetLeft(), gadget:GetTop()
    -- gadget:SetAnchor(TOPLEFT, TEBTop, TOPLEFT, gadgetLeft, gadgetTop)
    gadget:SetDrawLayer(DL_OVERLAY)
    local gadgetList = settings.gadgets[G.pvpMode and "pvp" or "pve"]
    local movingGadget = gadget:GetName() -- name of icon object as string
    G.movingGadgetKey = G.iconReference[movingGadget] -- name of the gadget
    for i = #gadgetList, 1, -1 do
        if gadgetList[i] == G.movingGadgetKey then
            table.remove(gadgetList, i)
        end
    end
    RebuildBar()
end

local function StopMovingGadget(gadget)
    local foundGadget = ""
    local testGadgetObject = ""
    local gadgetList = settings.gadgets[G.pvpMode and "pvp" or "pve"]
    local targetGadgetNumber = #gadgetList + 1
    for i = 1, #gadgetList do
        -- gadgetList[i] - gadget's key
        local key = gadgetList[i]
        if key ~= "" then
            testGadgetObject = gadgetReference[key].icon
            if gadget:GetLeft() <= testGadgetObject:GetLeft() and not testGadgetObject:IsHidden() then
                targetGadgetNumber = i
                break
            end
        end
    end
    table.insert(gadgetList, targetGadgetNumber, G.movingGadgetKey)
    gadget:SetDrawLayer(DL_CONTROLS)
    G.movingGadgetKey = ""
    RebuildBar()
end

local function FormattedCurrency(g, s, tracked, onCharacter, textColor)
    if s == "tracked" or s == "tracked+bank" then
        return settings.bar.thousandsSeparator and
            zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(tracked)) or
            zo_strformat("<<1>>", tracked)
    elseif key ~= "ap" then
        return s == "on character" and
            textColor:Colorize(onCharacter) or
            s == "on character/in bank" and
            string.format("%s/%s", textColor:Colorize(onCharacter), G.colors.normal:Colorize(g.Bank)) or
            s == "on character (in bank)" and
            string.format("%s (%s)", textColor:Colorize(onCharacter), G.colors.normal:Colorize(g.Bank)) or
            s == "on character/total" and
            string.format("%s/%s", textColor:Colorize(onCharacter), G.colors.normal:Colorize(g.Total)) or
            s == "on character (total)" and
            string.format("%s (%s)", textColor:Colorize(onCharacter), G.colors.normal:Colorize(g.Total)) or
            s == "total" and
            g.Total
    end
end

-- global variable updaters (called from RefreshBar)

local function balance()
    local currentChar = G.characterName
    for _, key in ipairs(currencies) do
        local g, s, tracker, name = G[key], settings[key], settings.Trackers[key], gadgetReference[key].name
        local currency_code = global_currencies[key]
        if currency_code then -- global currency
            g.inBank = GetCurrencyAmount(currency_code, CURRENCY_LOCATION_ACCOUNT)
            if key == "transmute" then
                local color, icon = CheckThresholds(g.inBank, true, s)
                g.Info = color:Colorize(g.inBank)
                SetIcon(key, icon)
            else
                g.Info = G.colors.normal:Colorize(settings.bar.thousandsSeparator and
                    zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(g.inBank)) or tostring(g.inBank))
                SetIcon(key, "normal")
            end
            g.TooltipInfo = g.Info
        else -- non-global currency
            local currency_code = non_global_currencies[key]
            local onCharacter = GetCurrencyAmount(currency_code, CURRENCY_LOCATION_CHARACTER) 
            local inBank = GetCurrencyAmount(currency_code, CURRENCY_LOCATION_BANK)  
            g.inBank = inBank
            local total = inBank
            local tracked = s.DisplayPreference == "tracked+bank" and inBank or 0
            -- store amount in Tracker
            if tracker[currentChar] then
                tracker[currentChar][2] = onCharacter
            else 
                tracker[currentChar] = { false, onCharacter }
            end
            -- create tooltip headers
            local left, right
            local rowColor, amount
            local ttfmt = currencyToolTips[s.DisplayPreference] or ""
            if key == "ap" then
                -- Alliance Points are special case
                local ap = g
                local currentAP = settings.Trackers.ap[currentChar][2]
                ap.Session = currentAP - ap.SessionStartPoints
                ap.Hour = 0
                if os.time() - ap.SessionStart > 0 then
                    if os.time() - ap.SessionStart < 3600 then
                        ap.Hour = math.floor(ap.Session)
                    else
                        ap.Hour = math.floor(ap.Session / ((os.time() - ap.SessionStart) / 3600))
                    end
                end
                ap.Session = settings.bar.thousandsSeparator and zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(ap.Session)) or ap.Session
                ap.Hour = settings.bar.thousandsSeparator and zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(ap.Hour)) or ap.Hour
                ap.Info = G.colors.normal:Colorize(
                    zo_strformat(apFormats[settings.ap.DisplayPreference],
                        currentAP, ap.Session, ap.Hour))
                ap.TooltipInfo = G.colors.normal:Colorize(
                    zo_strformat(apFormats[settings.ap.TooltipPreference],
                        currentAP, ap.Session, ap.Hour))
                ap.Session = G.colors.normal:Colorize(G.ap.Session)
                ap.Hour = G.colors.normal:Colorize(G.ap.Hour)
                left = {
                    G.colors.header:Colorize(apTooltips[settings.ap.DisplayPreference]),
                    G.colors.normal:Colorize("Points gained this session\nPoints gained per hour")
                }
                right = { string.format("\n%s\n%s",
                            G.colors.highlight:Colorize(G.ap.Session),
                            G.colors.highlight:Colorize(G.ap.Hour) )
                }
            else
                left, right =
                { G.colors.header:Colorize(zo_strformat(ttfmt, name)) },
                { "" }
            end
            for _, k in ipairs(SortCharacters(tracker)) do
                local v = tracker[k]
                total = total + v[2]
                if v[1] then
                    tracked = tracked + v[2]                        
                end
                amount = settings.bar.thousandsSeparator and
                    zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(v[2])) or
                    tostring(v[2])
                rowColor = (k == G.characterName) and G.colors.active or
                    v[1] and G.colors.good or G.colors.normal
                table.insert(left, rowColor:Colorize(k))
                table.insert(right, rowColor:Colorize(amount))
            end
            -- text and icon color
            local textColor, iconColor = CheckThresholds(onCharacter, false, s.low)
            if iconColor == "normal" then
                textColor, iconColor = CheckThresholds(onCharacter, true, s.high)
            end
            SetIcon(key, iconColor)
            -- format numbers
            if settings.bar.thousandsSeparator then
                onCharacter = zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(onCharacter))
                g.Bank = zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(inBank))
                g.Total = zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(total))
            else
                g.Bank = tostring(inBank)
                g.Total = tostring(total)
            end
            -- select right format and colorize gadget text
            if key ~= "ap" then 
                g.Info = FormattedCurrency(g, s.DisplayPreference, tracked, onCharacter, textColor)
            end
            g.TooltipInfo = FormattedCurrency(g, s.TooltipPreference, tracked, onCharacter, textColor)
            -- colorize tooltip texts
            table.insert(left, G.colors.highlight:Colorize(zo_strformat("<<1>> in bank", name)))
            table.insert(right, G.colors.highlight:Colorize(g.Bank))
            table.insert(left, G.colors.highlight:Colorize(zo_strformat("Total <<1>>", name)))
            table.insert(right, G.colors.highlight:Colorize(g.Total))
            -- and create tooltips
            g.Left = table.concat( left, "\n" )
            g.Right = table.concat( right, "\n")
        end
    end
    -- complete tooltips for global currencies (including data for non-global ones)
    for _, currentCurrency in ipairs(currencies) do
        if global_currencies[currentCurrency] then
            local left, right, color = { }, { }, nil
            local fmt = "|t18:18:%s|t%s"
            -- local fmt = "|t18:18:TEB/Images/%s_color.dds|t%s" -- 18x18 icons, like the font
            left = { G.colors.header:Colorize(gadgetReference[currentCurrency].name .. " (and other currencies)") }
            right = { "" }
            for _, c in ipairs(currencies) do
                local color = c == currentCurrency and G.colors.active or G.colors.normal
                table.insert(left, color:Colorize(gadgetReference[c].name))
                -- table.insert(right, string.format(fmt, c, color:Colorize(G[c].TooltipInfo)))
                local icon = ZO_Currency_GetPlatformCurrencyIcon(global_currencies[c] or non_global_currencies[c])
                table.insert(right, string.format(fmt, icon, color:Colorize(G[c].TooltipInfo)))
            end
            G[currentCurrency].Left, G[currentCurrency].Right =
                table.concat( left, "\n" ), table.concat( right, "\n")
        end
    end
end

local function bang(usedslots, maxslots, tag) -- bank & bag
    local bagOrBank = settings[tag]
    local g = G[tag]
    local freeSlots = maxslots - usedslots
    local bagPercentUsed = math.floor((usedslots / maxslots) * 100)
    local bagPercentFree = 100 - bagPercentUsed
    local testval = bagOrBank.UsageAsPercentage and bagPercentUsed or usedslots
    local bagColor, iconColor = CheckThresholds(testval, true, bagOrBank)
    SetIcon(tag, iconColor)
    if iconColor == "critical" and settings.bar.pulseWhenCritical then
        AddPulseItem(tag)
    else
        RemovePulseItem(tag)
    end
    g.Left, g.Right =
        G.colors.header:Colorize(zo_strformat("<<C:1>> <<2>>",
            string.format(bangToolTips[settings[tag].DisplayPreference] or
        "%s space used / maximum size", tag))),
        ""
    g.Info = bagColor:Colorize(zo_strformat(bagFormats[bagOrBank.DisplayPreference],
        usedslots, freeSlots, maxslots, bagPercentUsed, bagPercentFree))
end

local function bag()
    local bagUsedSlots, bagMaxSlots = PLAYER_INVENTORY:GetNumSlots(INVENTORY_BACKPACK)
    bang(bagUsedSlots, bagMaxSlots, "bag")
end

local function bank()
    local bankUsedSlots, bankMaxSlots = PLAYER_INVENTORY:GetNumSlots(INVENTORY_BANK)
    bang(bankUsedSlots, bankMaxSlots, "bank")
end

local function bagItems()
    local bagUsedSlots, bagMaxSlots = PLAYER_INVENTORY:GetNumSlots(INVENTORY_BACKPACK)
    local _, n
    G.slots = { }
    for _, n in pairs(itemsInSlot) do
        G.slots[n] = 0
    end
    for slotIndex = 0, bagMaxSlots-1 do
        local itemLink = GetItemLink( INVENTORY_BACKPACK, slotIndex )
        local itemType, specializedItemType = GetItemLinkItemType( itemLink )
        local itemId = GetItemLinkItemId( itemLink )
        local icon, stack, sellPrice, meetsUsageRequirement, locked, equipType,
            itemStyleId, itemQuality = GetItemInfo(INVENTORY_BACKPACK, slotIndex)
        local key
        if IsItemLinkStolen( itemLink ) then
            G.slots.stolen = G.slots.stolen + 1
            key = itemType == ITEMTYPE_TREASURE and "treasures" or "not_treasures"
        elseif IsItemJunk( INVENTORY_BACKPACK, slotIndex ) then
            G.slots.junk = G.slots.junk + 1
        else
            key = itemsInSlot[itemId]
        end
        if key then
            G.slots[key] = G.slots[key] + stack
        end
    end
    G.junk.Info = G.colors.normal:Colorize(G.slots.junk)
    G.junk.Left, G.junk.Right = G.colors.header:Colorize("Junk in bag."), ""
    -- repair kits
    G.totalRepairKits = G.slots.groupRepairKit + G.slots.grandRepairKit + G.slots.crownRepairKit
    -- soul gems
    G.total_filled = G.slots.normal_filled + G.slots.crown_filled
    local soulgemStrings = {
            G.colors.active:Colorize(G.total_filled),
            G.colors.normalSoulGem:Colorize(G.slots.normal_filled),
            G.colors.crownSoulGem:Colorize(G.slots.crown_filled),
            G.colors.emptySoulGem:Colorize(G.slots.empty),
        }
    G.soulgems.Info = G.colors.normal:Colorize(
        zo_strformat(soulgemsFormats[settings.soulgems.DisplayPreference],
        G.total_filled, G.slots.normal_filled, G.slots.crown_filled, G.slots.empty))
    G.soulgems.Right = "\n" .. table.concat( soulgemStrings, "\n" )
    G.soulgems.Left = table.concat({
        G.colors.header:Colorize(soulgemToolTips[settings.soulgems.DisplayPreference] or ""),
        G.colors.active:Colorize("Total filled"),
        G.colors.normalSoulGem:Colorize("Regular filled"),
        G.colors.crownSoulGem:Colorize("Crown Soul Gems"),
        G.colors.emptySoulGem:Colorize("Empty"),
    }, "\n")
    SetIcon("soulgems", "normal")
    -- thieves' tools
    G.lockpicks = GetNumLockpicksLeft()
    G.total_stolen = G.slots.treasures + G.slots.not_treasures
    G.totalSells, G.sellsUsed, _ = GetFenceSellTransactionInfo()
    local fence = G.totalSells - G.sellsUsed
    G.totalLaunders, G.laundersUsed = GetFenceLaunderTransactionInfo()
    local launder = G.totalLaunders - G.laundersUsed
    local fenceColor, iconColor1 = CheckThresholds(fence, false, settings.tt)
    local launderColor, iconColor2 = CheckThresholds(launder, false, settings.tt)
    iconColor = iconPriorities[iconColor1] < iconPriorities[iconColor2] and iconColor2 or iconColor1
    SetIcon("tt", iconColor)
    local stolenInvPerc = 100 * G.slots.stolen / bagMaxSlots
    local ttdp, add_lockpicks = settings.tt.DisplayPreference:gsub(" %(lockpicks%)", "")
    local fmt =
        ttdp == "lockpicks" and G.colors.normal:Colorize(G.lockpicks) or
        ttdp == "total stolen" and G.colors.normal:Colorize(G.total_stolen) or ttFormats[ttdp]
    local tt = zo_strformat(fmt,
        G.colors.normal:Colorize(G.slots.treasures),
        G.colors.normal:Colorize(G.slots.not_treasures),
        fenceColor:Colorize(fence),
        launderColor:Colorize(launder),
        G.colors.normal:Colorize("/"))
    G.tt.Info =  add_lockpicks ~= 0 and string.format("%s%s%s%s", tt,
        G.colors.normal:Colorize(" ("),
        G.colors.normal:Colorize(G.lockpicks),
        G.colors.normal:Colorize(")")) or tt
    G.tt.Left =
        G.colors.header:Colorize("Thief's Tools.") ..
        G.colors.normal:Colorize("\nLockpicks\nStolen Treasures\nOther Stolen Items\nFence Interactions\nLaunder Interactions")
    G.tt.Right =
        G.colors.highlight:Colorize(string.format("\n%s\n%s\n%s\n%s/%s\n%s/%s",
        G.lockpicks, G.slots.treasures, G.slots.not_treasures,
        G.sellsUsed, G.totalSells, G.laundersUsed, G.totalLaunders))
end

local function bounty()
    local bountyColor, iconColor
    local bountyTime = GetSecondsUntilBountyDecaysToZero()
    local heatTime = GetSecondsUntilHeatDecaysToZero()
    G.bounty.TimerRunning = bountyTime > 0 or heatTime > 0
    local longestTime = heatTime
    if bountyTime > heatTime then longestTime = bountyTime end
    local infamy = GetInfamyLevel(GetInfamy())
    local iconColor = infamyLevels[infamy][2]
    bountyColor = G.colors[iconColor]
    if settings.bounty.good == "good" and iconColor == "normal" then
        bountyColor = G.colors.good
        iconColor = "good"
    end
    local Payoff = GetReducedBountyPayoffAmount()
    local TimerText = ConvertSeconds(settings.bounty.DisplayPreference, bountyTime)
    local heatTimerText = ConvertSeconds(settings.bounty.DisplayPreference, heatTime)
    local infamyText = bountyColor:Colorize(infamyLevels[infamy][1])
    G.bounty.Info = bountyColor:Colorize(
        ConvertSeconds(settings.bounty.DisplayPreference, longestTime))
    SetIcon("bounty", iconColor)
    if G.bounty.TimerRunning and not G.bounty.TimerVisible or
        not G.bounty.TimerRunning and G.bounty.TimerVisible then
        G.bounty.TimerVisible = not G.bounty.TimerVisible
        RebuildBar()
    end
    G.bounty.Left = G.colors.header:Colorize("Bounty and heat\n") ..
        G.colors.normal:Colorize("Heat Time Left\nBounty Time Left\nInfamy\nPayoff")
    G.bounty.Right = bountyColor:Colorize(string.format("\n%s\n%s\n%s\n|t18:18:TEB/Images/gold_color.dds|t%s",
        heatTimerText, TimerText, infamyText, Payoff))
end

local function buffs()
    -- food
    local isBuffActive, timeLeftInSeconds, abilityId =
        LFDB:IsFoodBuffActiveAndGetTimeLeft("player")
    if isBuffActive then
        G.food.TimerRunning = true
        G.food.BuffWasActive = true
    else
        G.food.TimerRunning = false
    end
    if timeLeftInSeconds < settings.food.critical and timeLeftInSeconds > 0 or
        timeLeftInSecond == 0 and G.foodBuffWasActive and settings.bar.pulseWhenCritical then
        AddPulseItem("food")
    elseif timeLeftInSeconds >= settings.food.critical or
        not settings.bar.pulseWhenCritical then
        RemovePulseItem("food")
    end
    local foodColor, iconColor = CheckThresholds(timeLeftInSeconds, false, settings.food)
    G.food.Info = foodColor:Colorize(
        ConvertSeconds(settings.food.DisplayPreference, timeLeftInSeconds))
    SetIcon("food", iconColor)
    if G.food.TimerRunning ~= G.food.TimerVisible then
        G.food.TimerVisible = G.food.TimerRunning
        RebuildBar()
    end
    G.food.Left, G.food.Right =
        G.colors.normal:Colorize("Food Buff Remaining"), G.food.Info

    -- mundus and vampirism
    local mundus = ""
    G.vampirism.Left = G.colors.header:Colorize("Vampirism.\n")
    G.vampirism.Right = ""
    numBuffs = GetNumBuffs("player")
    if numBuffs then
        for i = 0, numBuffs, 1 do
            local buffName, timeStarted, timeEnding, buffSlot, stackCount, textureName,
                buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff =
                GetUnitBuffInfo("player", i)
            if textureName and textureName ~= "" then
                if PlainStringFind(textureName, "ability_mundusstones_") then
                    mundus = tonumber(string.sub(textureName,-7, -5))
                elseif PlainStringFind(textureName,"_vampire_infection_") then
                    if not G.isVampire then
                        G.isVampire = true
                        RebuildBar()
                    end
                    local timeEnding = math.floor(timeEnding) * 1000
                    local timeStarted = math.floor(timeStarted)
                    local stage = tonumber(string.match(buffName,"%d+") or 1)
                    local buffTimeLeft = math.floor((timeEnding - GetFrameTimeMilliseconds()) / 1000)
                    local vampireTimeLeft = ConvertSeconds(settings.vampirism.TimerPreference, buffTimeLeft)
                    local skillIndex = 0
                    local SkillLinesCount = GetNumSkillLines(SKILL_TYPE_WORLD)
                    local nextRankXP
                    local currentXP
                    local lineName
                    local lineLevel = 0
                    local skillLineId
                    local vampireSkillsID = 51
                    for i = 1, SkillLinesCount, 1 do
                        skillLineId = GetSkillLineId(SKILL_TYPE_WORLD, i)
                        if skillLineId == vampireSkillsID then
                            skillIndex = i
                            break
                        end
                    end
                    if skillIndex > 0 then
                        local rank,advised,active,discovered = GetSkillLineDynamicInfo(SKILL_TYPE_WORLD, skillIndex)
                        if discovered == true and active == true then
                            _, nextRankXP, currentXP = GetSkillLineXPInfo(SKILL_TYPE_WORLD, skillIndex)
                        end
                        if GetSkillLineInfo then
                            _, lineLevel = GetSkillLineInfo(SKILL_TYPE_WORLD, skillIndex)
                        else
                            local skillLineData = SKILLS_DATA_MANAGER:GetSkillLineDataByIndices(SKILL_TYPE_WORLD, skillIndex)
                            if skillLineData then
                                _, lineLevel = skillLineData:GetName(), skillLineData:GetCurrentRank()
                            end
                        end
                    end
                    if stage == 1 then vampireTimeLeft = "--" end
                    local s = string.format("stage%d", stage)
                    local textColor, iconColor = G.colors[s], "normal" -- XXX
                    G.vampirism.Info = settings.vampirism.DisplayPreference == "Stage (Timer)" and
                        textColor:Colorize(string.format("%d (%s)", stage, vampireTimeLeft)) or
                        textColor:Colorize(vampireTimeLeft)
                    SetIcon("vampirism", iconColor)
                    G.vampirism.Left = G.vampirism.Left ..
                        G.colors.normal:Colorize("Stage\nTime until stage expires")
                    G.vampirism.Right = textColor:Colorize(string.format("\n%d\n%s", stage, vampireTimeLeft))
                end
            end
        end
    end
    settings.Trackers.mundus[G.characterName] =
        mundusStoneReference["Full"][mundus] or G.colors.danger:Colorize("None")
    G.mundus.Info = G.colors.normal:Colorize(
        mundusStoneReference[settings.mundus.DisplayPreference][mundus] or
        G.colors.danger:Colorize("None"))
    local leftMundus, rightMundus = { G.colors.header:Colorize("Mundus Stone.") }, { "" }
    for _, k in ipairs(SortCharacters(settings.Trackers.mundus)) do
        local v = settings.Trackers.mundus[k]
        table.insert(leftMundus, k == G.characterName and G.colors.active:Colorize(k) or
            G.colors.normal:Colorize(k))
        table.insert(rightMundus, k == G.characterName and G.colors.active:Colorize(v) or
            G.colors.normal:Colorize(v))
    end
    SetIcon("mundus", "normal")
    G.mundus.Left, G.mundus.Right = table.concat(leftMundus, "\n"), table.concat(rightMundus, "\n")
end

local function clock()
    local UTCTime, localTime, inGameTime, imperialDate, argonianDate, earthDate
    local timeFormat = timeFormats[settings.clock.Type]
    local tamrielDateFmt = "<<i:1>> <<G:2>> 2E <<3>>"
    if LibClockTST then
        -- Tamriel time available
        local LCTST_Instance = LibClockTST:Instance()
        local t, d = LCTST_Instance:GetTime(), LCTST_Instance:GetDate()
        local td = { sec = t.second, min = t.minute, hour = t.hour,
            day = d.day, month = d.month, year = d.year }
        for tag, a_or_i in pairs({ argonianDate = "A", imperialDate = "I" }) do
            G.clock[tag] = ZO_CachedStrFormat(tamrielDateFmt,
                td.day, monthNames[a_or_i][td.month], td.year)
        end
        td.year = 2020 -- 611 is too early for os.time…
        inGameTime, imperialDate, argonianDate =
            os.date(timeFormat,  os.time(td)), G.clock.imperialDate, G.clock.argonianDate

    else
        inGameTime, imperialDate, argonianDate = "not available", "LibClockTST", "required"
    end
    local localTime = os.date(timeFormat)
    local UTCTime = os.date("!" .. timeFormat)
    if settings.clock.Type == "12h no leading zero" then
        inGameTime = inGameTime:gsub("^0", " ")
        localTime  = localTime:gsub("^0", " ")
        UTCTime    = UTCTime:gsub("^0", " ")
    end
    local dateFormat = settings.clock.DateFormat
    local translation = dateFormat:sub(-1, -1)
    if translation == 'I' or translation == 'A' then
        dateFormat = string.sub(dateFormat, 1, -2)
    end
    earthDate = os.date(dateFormat)
    localDate = translation == 'I' and imperialDate or
        translation == 'A' and argonianDate or earthDate
    local tbl = {
        {"Local date"   , earthDate,    },
        {"Local time"   , localTime,    },
        {"UTC time"     , UTCTime,      },
        {"Tamriel time" , inGameTime,   },
        {"Imperial date", imperialDate, },
        {"Argonian date", argonianDate, },
    }
    local left = { G.colors.header:Colorize("Clock: " .. settings.clock.DisplayPreference) }
    local right = { "" }
    for _, row in pairs(tbl) do
        table.insert(left, G.colors.normal:Colorize(string.format("%s:", row[1])))
        table.insert(right, G.colors.highlight:Colorize(row[2]))
    end
    G.clock.Left, G.clock.Right = table.concat(left, "\n"), table.concat(right, "\n")
    G.clock.Info = G.colors.normal:Colorize( zo_strformat(
        clockFormats[settings.clock.DisplayPreference],
        inGameTime, UTCTime, localTime, localDate ))
    SetIcon("clock", "normal")
end

local function companion()
    local present = HasActiveCompanion()
    if present then
        local data = {
            name = zo_strformat("<<1>>", GetCompanionName(GetActiveCompanionDefId())),
            rapportLevel = GetActiveCompanionRapportLevel(),
            rapportMin = GetMinimumRapport(),
            rapportMax = GetMaximumRapport(),
            rapport = GetActiveCompanionRapport(),
        }
        data.level, data.XP = GetActiveCompanionLevelInfo()
        data.totalXP = GetNumExperiencePointsInCompanionLevel(data.level + 1) or 0
        data.XPPercent = data.totalXP > 0 and zo_floor(data.XP * 100 / data.totalXP) or 0
        data.rapportLevelDesc = GetString("SI_COMPANIONRAPPORTLEVEL", data.rapportLevel)
        G.companion.icon = ZO_COMPANION_MANAGER:GetActiveCompanionIcon()            
        local info = { }
        local left = { G.colors.header:Colorize("Companion") }
        local right = { string.format("|t18:18:%s|t", G.companion.icon) }
        for _, r in ipairs(companion_info) do
            local k, desc, fmt = unpack(r)
            local v = data[k]
            local hide = data.rapport == data.rapportMax and settings.companion.rapportHide and 
                k:sub(1, 7) == "rapport"
            table.insert(left, desc)
            if settings.bar.thousandsSeparator and type(v) == "number" then
                v = zo_strformat(fmt, ZO_LocalizeDecimalNumber(v))
            else
                v = zo_strformat(fmt, v)
            end
            if k == "XPPercent" and data.level == 20 then v = "" end
            table.insert(right, v)
            if not hide and settings.companion[k] and v ~= "" then
                table.insert(info, v)
            end
        end
        G.companion.Info = G.colors.normal:Colorize(table.concat(info, settings.companion.separator))
        G.companion.Left = G.colors.normal:Colorize(table.concat(left, "\n"))
        G.companion.Right = G.colors.highlight:Colorize(table.concat(right, "\n"))
    else
        G.companion = { Info = "", Left = "Companion", Right = "not present",
            icon = GetCollectibleIcon(GetCompanionCollectibleId(1)) }
    end
    SetIcon("companion", "normal")
    if G.companion.present ~= present then
        G.companion.present = present
        RebuildBar()
    end
end

local function crafting(craftName, craftIcon, craftId)
    local craft = G[craftName]
    local researchInfo
    local leastTime = 9999999
    local left = { G.colors.header:Colorize(string.format("Time until %s research is complete.",
        craftName)) }
    local right = { "" }
    local timers, info = {}, {}
    local totalSlots = GetMaxSimultaneousSmithingResearch(craftId)
    local totalResearchLines = GetNumSmithingResearchLines(craftId)
    for researchLine = 1, totalResearchLines do
        local lineName, icon, totalTraits, researchTimeSecs =
            GetSmithingResearchLineInfo(craftId, researchLine)
        for traitNum = 1, totalTraits do
            totalSecs, remainingSecs =
                GetSmithingResearchLineTraitTimes(craftId, researchLine, traitNum)
            if remainingSecs ~= nil then
                local traitId, traitDescription, known =
                    GetSmithingResearchLineTraitInfo(craftId, researchLine, traitNum)
                table.insert(timers, { secs = remainingSecs, trait = traitReference[traitId] })
            end
        end
    end
    local freeSlots = totalSlots - #timers
    craft.TimerRunning = false
    if #timers > 0 then
        craft.TimerRunning = true
        for timerIndex = 1, totalSlots do
            if timerIndex <= #timers then
                if timers[timerIndex].secs < leastTime then
                    leastTime = timers[timerIndex].secs
                end
                local timerString = ConvertSeconds(settings.research.DisplayPreference, timers[timerIndex].secs)
                table.insert(info, timerString)
                table.insert(right, timerString)
                table.insert(left, string.format("Slot %s - %s", timerIndex, timers[timerIndex].trait))
            elseif settings.research.DisplayAllSlots then
                -- show empty slots too
                table.insert(info, settings.research.FreeText)
                table.insert(right, settings.research.FreeText)
                table.insert(left, string.format("Slot %s", timerIndex))
            end
        end
    end

    table.insert(left, "Free Slots:\nTotal Slots:")
    table.insert(right, string.format("%s\n%s", freeSlots, totalSlots))
    if settings.research.ShortestOnly then
        craft.Info = G.colors.normal:Colorize( leastTime == 9999999 and
            settings.research.FreeText or
            ConvertSeconds(settings.research.DisplayPreference, leastTime) )
    else
        craft.Info = G.colors.normal:Colorize(table.concat(info, "/"))
    end
    if settings.research.DisplayAllSlots then
        craft.Info = craft.Info .. ( freeSlots == 0 and
        G.colors.normal:Colorize(" (0)") or
        G.colors.good:Colorize(string.format(" (%s)", freeSlots)) )
    end
    craft.freeSlots = freeSlots
    craft.Left = G.colors.normal:Colorize(table.concat(left, "\n"))
    craft.Right = G.colors.highlight:Colorize(table.concat(right, "\n"))
    SetIcon(craftName, freeSlots == 0 and "normal" or "good")
    if craft.TimerRunning and not craft.TimerVisible or
        not craft.TimerRunning and craft.TimerVisible then
        craft.TimerVisible = craft.TimerRunning
        RebuildBar()
    end
end

--[[
local function endeavors()
    local e = { daily = { done = 0 }, weekly = { done = 0 } }
    local endeavors_periods = SortKeys(e)
    local eNum = GetNumTimedActivities()
    for i = 1, eNum do
        local eType = GetTimedActivityType(i) == TIMED_ACTIVITY_TYPE_DAILY and "daily" or "weekly"
        if not e[eType].Time then
            e[eType].Time = GetTimedActivityTimeRemainingSeconds(i)
        end
        if GetTimedActivityProgress(i) >= GetTimedActivityMaxProgress(i) then
            e[eType].done = e[eType].done + 1
        end
    end
    G.endeavors = { daily = e.daily.done, weekly = e.weekly.done }
    local dailyColor, d_tag = CheckThresholds(e.daily.Time, false, settings.endeavors)
    local weeklyColor, w_tag = CheckThresholds(e.weekly.Time, false, settings.endeavors)
    if e.daily.done == 3 then
        e.daily.time = G.colors.normal:Colorize(0) 
        e.daily.todo = G.colors.normal:Colorize(0) 
        e.daily.done = G.colors.normal:Colorize(3)
    else
        e.daily.time = dailyColor:Colorize(ConvertSeconds(settings.endeavors.TimeFormat, e.daily.Time))
        e.daily.todo = G.colors.warning:Colorize(3 - e.daily.done)
        e.daily.done = G.colors.warning:Colorize(e.daily.done)
    end
    if e.weekly.done == 1 then
        e.weekly.time = G.colors.normal:Colorize(0) 
        e.weekly.todo = G.colors.normal:Colorize(0) 
        e.weekly.done = G.colors.normal:Colorize(1)
    else
        e.weekly.time = weeklyColor:Colorize(ConvertSeconds(settings.endeavors.TimeFormat, e.weekly.Time))
        e.weekly.todo = G.colors.warning:Colorize(1)
        e.weekly.done = G.colors.warning:Colorize(0)
    end
    local info = { }
    for _, period in ipairs(endeavors_periods) do
        local v = e[period]
        for _, param in ipairs(endeavors_params) do
            if settings.endeavors[string.format("%s_%s", period, param)] then
                table.insert(info, v[param])
            end
        end
    end    
    G.endeavors.Info = table.concat(info, settings.endeavors.separator)
    G.endeavors.Left = string.format("%s\n%s\n%s\n%s\n%s",
        G.colors.header:Colorize("Endeavor Progress"),
        G.colors.normal:Colorize("Daily Endeavors done"),
        G.colors.normal:Colorize("Weekly Endeavors done"),
        G.colors.normal:Colorize("Daily Endeavors remaining time"),
        G.colors.normal:Colorize("Weekly Endeavors remaining time"))
    G.endeavors.Right = string.format("\n%s\n%s\n%s\n%s", e.daily.done, e.weekly.done, 
        e.daily.time, e.weekly.time)
    SetIcon("endeavors", w_tag ~= "normal" and w_tag or d_tag)
end
]]--

local function enlightenment()
    local enlightenment_amount, enlightenment
    if IsEnlightenedAvailableForCharacter() then
        enlightenment_amount = GetEnlightenedPool()
        if settings.bar.thousandsSeparator then
            enlightenment = zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(enlightenment_amount))
        else
            enlightenment = tostring(enlightenment_amount)
        end
    else
        enlightenment = "--"
        enlightenment_amount = 0
    end
    local enlightenmentColor, iconColor = CheckThresholds(enlightenment_amount, false, settings.enlightenment)
    SetIcon("enlightenment", iconColor)
    G.enlightenment.Info, G.enlightenment.Left, G.enlightenment.Right =
        enlightenmentColor:Colorize(enlightenment),
        G.colors.header:Colorize("Current enlightenment."), ""
    if (enlightenment_amount > 0) ~= G.enlightenment.Visible then
        G.enlightenment.Visible = not G.enlightenment.Visible
        RebuildBar()
    end
end

local function equipped()
    if not (LSD and LS) then return end
    if G.equipped_dirty then 
        G.equipped_dirty = false
    else
        return
    end
    --d("equipped!")
    local left, right = { "Currently Equipped" }, { "" }
    local lang = "en"
    local equipped_class = 5 -- normal
    local equip_sets = LSD.GetEquippedSetsTable()
    -- this loop based on CurrentlyEquipped addon
    for setID, info in pairs(equip_sets) do
        local set_name
        local set_max_equip = 0
        local set_num_equip = 0
        local temp_bar = 0
        if info.name ~= "" then
            set_name = info.name
        else
            set_name = LS.GetSetName(setID, lang)
        end
        if info.maxEquipped ~= 0 then 
            set_max_equip = info.maxEquipped
        else
            _, set_max_equip, _ = LS.GetNumEquippedItemsBySetId(setID)
        end
        -- If body pieces, add them, if weapons, add highest value, otherwise double barred set will add front and back
        for loc, num_equip in pairs(info.numEquipped) do
            if loc == "body" then 
                set_num_equip = set_num_equip + num_equip
            elseif num_equip > temp_bar then
                set_num_equip = set_num_equip + num_equip - temp_bar
                temp_bar = num_equip
            end            
        end
        local tmp_right = string.format("%d/%s", set_num_equip, set_max_equip)
        if set_num_equip == set_max_equip then -- good
            table.insert(left, G.colors.good:Colorize(set_name))
            table.insert(right, G.colors.good:Colorize(tmp_right))
        elseif set_num_equip > set_max_equip or LS.IsMonsterSet(setID) then -- overequipped or monster
            table.insert(left, G.colors.caution:Colorize(set_name))
            table.insert(right, G.colors.caution:Colorize(tmp_right))
            if equipped_class > 4 then equipped_class = 4 end -- caution
        else -- underequipped and not monster
            table.insert(left, G.colors.warning:Colorize(set_name))
            table.insert(right, G.colors.warning:Colorize(tmp_right))
            if equipped_class > 3 then equipped_class = 3 end -- warning
        end
    end
    local iconColor = equipped_class == 5 and "good" or thresholdLevels[equipped_class]
    local equippedColor = G.colors[iconColor]
    SetIcon("equipped", iconColor)  
    G.equipped.Info, G.equipped.Left, G.equipped.Right =
        equippedColor:Colorize(tostring(#left - 1)), -- number of sets equipped
        table.concat( left, "\n" ),
        table.concat( right, "\n")
end

local function esoplus()
    local esoplus_ends = settings.esoplus.start + settings.esoplus.period * 86400 -- Unix time
    local esoplus_left = math.floor(esoplus_ends / 86400) - math.floor(os.time() / 86400)
    local esoplus_end_date = os.date(settings.esoplus.dateformat, esoplus_ends)
    if esoplus_left <= 0 then
        esoplus_left = 0
        G.esoplus.active = false
    end
    local esoplusColor, iconColor = CheckThresholds(esoplus_left, false, settings.esoplus)
    SetIcon("esoplus", iconColor)
    if iconColor == "critical" and settings.bar.pulseWhenCritical then
        AddPulseItem("esoplus")
    else
        RemovePulseItem("esoplus")
    end
    
    G.esoplus.Info, G.esoplus.Left, G.esoplus.Right =
        esoplusColor:Colorize(esoplus_left),
        G.colors.header:Colorize("ESO+ subscription days left until "), 
        G.colors.header:Colorize(esoplus_end_date)
end

local function experience()
    local gcp, gmaxxp, gxp, gxpCurrentPercentage, gxpperc, gxpneeded
    local levelThing = G.lvl == 50 and "champion point" or "level"
    if IsUnitChampion("player") then
        gcp = GetUnitChampionPoints("player")
        if gcp < GetChampionPointsPlayerProgressionCap() then
            gcp = GetChampionPointsPlayerProgressionCap()
        elseif gcp == 3600 then
            gcp = 3599
        end
        gmaxxp = GetNumChampionXPInChampionPoint(gcp)
        gxp = GetPlayerChampionXP()
    else
        gmaxxp = GetUnitXPMax("player")
        gxp = GetUnitXP("player")
    end
    gxpCurrentPercentage = round(100 * gxp / gmaxxp, 1)
    gxpperc = 100 - gxpCurrentPercentage
    gxpneeded = gmaxxp - gxp
    if settings.bar.thousandsSeparator then
        gxp = zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(gxp))
        gmaxxp = zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(gmaxxp))
        gxpneeded = zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(gxpneeded))
    else
        gxp = tostring(gxp)
        gmaxxp = tostring(gmaxxp)
        gxpneeded = tostring(gxpneeded)
    end
    G.experience.Info = G.colors.normal:Colorize(
        settings.experience.DisplayPreference == "% towards next level/CP" and
        string.format("%s%%", gxpCurrentPercentage) or
        settings.experience.DisplayPreference == "% needed for next level/CP" and
        string.format("%s%%", gxpperc) or
        settings.experience.DisplayPreference == "current XP" and
        gxp or
        settings.experience.DisplayPreference == "needed XP" and
        gxpneeded or
        settings.experience.DisplayPreference == "current XP/total needed" and
        string.format("%s/%s", gxp, gmaxxp))
    G.experience.Left, G.experience.Right =
        G.colors.header:Colorize(string.format(XPTooltips[settings.experience.DisplayPreference], levelThing)),
        ""
end

local function durability()
    local repairCost
    local leastDurability = 100
    local totalRepairCost = 0
    local mostDamagedItem = ""
    local mostDamagedCost = 0
    local mostDamagedCondition = 100
    local durabilityColor, iconColor
    local condition
    local left, right = { G.colors.header:Colorize("Armor durability.") }, { "" }
    for slotIndex = 0, 16, 1 do
        if DoesItemHaveDurability(BAG_WORN, slotIndex) then
            repairCost = GetItemRepairCost(BAG_WORN, slotIndex) or 0
            totalRepairCost = totalRepairCost + repairCost
            condition = GetItemCondition(BAG_WORN, slotIndex)
            if condition < mostDamagedCondition then
                mostDamagedItem = equipSlotReference[slotIndex]
                mostDamagedCost = repairCost
                mostDamagedCondition = condition
            end
            if leastDurability > condition then
                leastDurability = condition
            end
            durabilityColor, iconColor = CheckThresholds(condition, false, settings.durability)
            table.insert(left, durabilityColor:Colorize(zo_strformat("<<C:1>>", GetItemName(BAG_WORN, slotIndex))))
            table.insert(right, durabilityColor:Colorize(string.format("(%dg) %d%%", repairCost, condition)))
        end
    end
    totalRepairCost = settings.bar.thousandsSeparator and
        zo_strformat("<<1>>g", ZO_LocalizeDecimalNumber(totalRepairCost)) or
        zo_strformat("<<1>>g", totalRepairCost)
    table.insert(left, G.colors.active:Colorize("Total Repair Cost"))
    table.insert(right, G.colors.active:Colorize(totalRepairCost))
    for _, p in ipairs(repairKits) do
        table.insert(left, G.colors.normal:Colorize(p[2]))
        table.insert(right, G.colors.highlight:Colorize(G.slots[p[1]]))
    end
    durabilityColor, iconColor = CheckThresholds(leastDurability, false, settings.durability)
    SetIcon("durability", iconColor)
    if iconColor == "critical" and settings.bar.pulseWhenCritical then
        AddPulseItem("durability")
    else
        RemovePulseItem("durability")
    end
    local fmt = durabilityFormats[settings.durability.DisplayPreference]
    G.durability.Info = durabilityColor:Colorize(zo_strformat(fmt,
        leastDurability, totalRepairCost, G.totalRepairKits,
        mostDamagedItem, mostDamagedCondition, mostDamagedCost))
    G.durability.Left = G.colors.normal:Colorize(table.concat( left, "\n"))
    G.durability.Right = G.colors.highlight:Colorize(table.concat( right, "\n"))
end

local function fps()
    local fpsValue = math.floor(GetFramerate())
    if fpsValue < G.lowestFPS then G.lowestFPS = fpsValue end
    if fpsValue > G.highestFPS then G.highestFPS = fpsValue end
    local fpsColor, iconColor = CheckThresholds(fpsValue, false, settings.fps)
    G.fps.Info = fpsColor:Colorize(tostring(fpsValue))
    G.fps.Left, G.fps.Right =
    G.colors.header:Colorize("Current frames per second.") ..
    G.colors.normal:Colorize("\nLowest FPS this session\nHighest FPS this session"),
    string.format("\n%s\n%s",
        G.colors.highlight:Colorize(G.lowestFPS),
        G.colors.highlight:Colorize(G.highestFPS))
    SetIcon("fps", iconColor)
end

local function latency()
    local latencyValue = GetLatency()
    local latencyColor, iconColor = CheckThresholds(latencyValue, true, settings.latency)
    G.latency.Info = latencyColor:Colorize(string.format("%d", latencyValue))
    G.latency.Left, G.latency.Right =
        G.colors.normal:Colorize("Current network latency: "), G.latency.Info .. G.colors.normal:Colorize(" ms")
    SetIcon("latency", iconColor)
end

local function leads()
    local long_count, medium_count, short_count, ultrashort_count, total, shortest = 0, 0, 0, 0, 0, 10000000
    local ultrashort = settings.leads.ultrashort
    local short = settings.leads.short
    local medium = settings.leads.medium
    local long = settings.leads.long
    -- we need days/hours here
    local leftside = string.format("\nNearest expiration in\nTotal leads\nLeads expiring in %d hours\nLeads expiring in %d hours\nLeads expiring in %d days\nLeads expiring in %d days", ultrashort, short, medium, long)
    -- … and seconds later
    ultrashort = ultrashort * 3600 -- hours, default 1 
    short = short * 3600           -- hours, default 24
    medium = medium * 86400        -- days,  default 3 
    long = long * 86400            -- days,  default 7
    local i = GetNextAntiquityId()
    while i do
        local havelead = DoesAntiquityHaveLead(i)
        if havelead then
            local leadtimeleft = GetAntiquityLeadTimeRemainingSeconds(i)
            -- some expiration timers come back 0 for a couple of days set to 33
            if leadtimeleft == 0 then leadtimeleft = 2851200 end
            if leadtimeleft < shortest then shortest = leadtimeleft end
            if leadtimeleft < ultrashort then ultrashort_count = ultrashort_count + 1 
            elseif leadtimeleft < short  then short_count = short_count + 1 
            elseif leadtimeleft < medium then medium_count = medium_count + 1
            elseif leadtimeleft < long   then long_count = long_count + 1
            end
            total = total + 1
        end
        i = GetNextAntiquityId(i)
    end
    local leadsValue = ultrashort_count > 0 and 4 or short_count > 0 and 3 or medium_count > 0 and 2 or long_count > 0 and 1 or 0
    G.leads.leadsExpiring = leadsValue
    local leadsColor, iconColor = CheckThresholds(leadsValue, true, settings.leads)
    G.leads.Info = leadsColor:Colorize(total)
    G.leads.Left, G.leads.Right =
        G.colors.header:Colorize("Antiquity leads") .. G.colors.normal:Colorize(leftside),
        string.format("\n%s\n%s\n%s\n%s\n%s\n%s",
            shortest == 10000000 and "--" or leadsColor:Colorize(ConvertSeconds("short", shortest)),
            G.colors.normal:Colorize(total),
            ultrashort_count > 0 and G.colors.critical:Colorize(ultrashort_count) or G.colors.normal:Colorize(ultrashort_count),
            short_count > 0 and G.colors.danger:Colorize(short_count) or G.colors.normal:Colorize(short_count),
            medium_count > 0 and G.colors.warning:Colorize(medium_count) or G.colors.normal:Colorize(medium_count),
            long_count > 0 and G.colors.caution:Colorize(long_count) or G.colors.normal:Colorize(long_count) 
        )
    SetIcon("leads", iconColor)
    if iconColor == "critical" and settings.bar.pulseWhenCritical then
        AddPulseItem("leads")
    else
        RemovePulseItem("leads")
    end
end

local function level()
    -- level & CP
    G.lvl = GetUnitLevel("player")
    G.cp = GetPlayerChampionPointsEarned()
    local unspentText, unspentTotal = "", 0
    local fmt = G.lvl < 50 and lvlFormats[settings.level.notmax.DisplayPreference] or
        lvlFormats[settings.level.max.DisplayPreference]
    G.level.Info, G.unspent = "", {}
    local unspentTooltips = {"", "", ""}
    for i = 1, 3 do
        local u = GetNumUnspentChampionPoints( (i+1) % 3 + 1 )
        G.unspent[i] = u
        unspentTotal = unspentTotal + u
    end
    if G.lvl < 50 and settings.level.notmax.cp or
        G.lvl == 50 and settings.level.max.cp then
        local dyn = G.lvl < 50 and settings.level.notmax.Dynamic or settings.level.max.Dynamic
        if not dyn or unspentTotal > 0 then
            local t = { }
            for i, r in ipairs(constellation_map) do
                local unspent = G.unspent[i]
                local u = G.colors[r[1]]:Colorize(zo_iconFormatInheritColor(string.format(
                    "esoui/art/champion/champion_points_%s_icon.dds", r[2]), 18, 18) .. unspent)
                unspentTooltips[i] = u
                if (not dyn or unspent > 0) and settings.level.cp[i] then
                    table.insert(t, u)
                end
            end
            if #t > 0 then
                unspentText = G.colors.normal:Colorize(" (") .. table.concat(t, "") ..
                    G.colors.normal:Colorize(")")
            end
        end
    end
    G.unspentTooltips = table.concat(unspentTooltips, "\n")
    G.level.Info = G.colors.normal:Colorize(zo_strformat(fmt, G.lvl, G.cp)) .. unspentText
    G.level.Left = table.concat({
        string.format(G.colors.header:Colorize(G.characterName)),
        G.colors.normal:Colorize(string.format("%s level", ClassNames[G.playerClass])),
        G.colors.normal:Colorize("Champion Points"),
        G.colors.craft:Colorize("Unspent Craft Points"),
        G.colors.warfare:Colorize("Unspent Warfare Points"),
        G.colors.fitness:Colorize("Unspent Fitness Points"),
        G.colors.highlight:Colorize("Total Unspent Points"),
    }, "\n")
    G.level.Right = table.concat({
        "",
        G.colors.normal:Colorize(string.format("%d", G.lvl)),
        G.colors.normal:Colorize(string.format("%d", G.cp)),
        G.unspentTooltips,
        G.colors.highlight:Colorize(
        zo_iconFormatInheritColor("TEB/Images/cp_white.dds", 18, 18) .. unspentTotal),
    }, "\n")

end

local function location()
    local x, y, heading = GetMapPlayerPosition("player")
    G.zoneName = GetPlayerActiveSubzoneName()
    if G.zoneName == "" then
        G.zoneName = GetUnitZone("player")
    end
    G.zoneName = ZO_CachedStrFormat("<<C:1>>", G.zoneName)
    G.coordinates = string.format("%.2f, %.2f", 100 * x, 100 * y)
    G.location.Info = G.colors.normal:Colorize(zo_strformat(
        locationFormats[settings.location.DisplayPreference], G.zoneName, G.coordinates))
    G.location.Left = G.colors.header:Colorize(locationToolTips[settings.location.DisplayPreference] or "") ..
        G.colors.normal:Colorize(string.format("\n%s\n(%s)", G.zoneName, G.coordinates))
    G.location.Right = ""
    SetIcon("location", "normal")
end

local function lock()
    local state = lockStates[(settings.bar.Locked and 0 or 2) + (settings.bar.gadgetsLocked and 0 or 1) + 1]
    local iconStyle = state == "normal" and "white" or
        settings.bar.iconsInherit and state or "good"
    SetIcon("lock", iconStyle)
    G.lock.Left, G.lock.Right = G.colors.normal:Colorize("Bar:\nGadgets:"),
        string.format("%s\n%s",
        settings.bar.Locked and G.colors.highlight:Colorize("locked") or G.colors[state]:Colorize("unlocked"),
        settings.bar.gadgetsLocked and G.colors.highlight:Colorize("locked") or G.colors[state]:Colorize("unlocked"))
    G.lock.Info = settings.gadgetTextEnabled.lock and 
        (settings.bar.Locked and G.colors.highlight:Colorize("B") or G.colors.danger:Colorize("B")) ..
        (settings.bar.gadgetsLocked and G.colors.highlight:Colorize("G") or G.colors.danger:Colorize("G"))
        or ""
end

local function mail()
    local unreadMailCount = GetNumUnreadMail()
    if not G.mail.Unread and unreadMailCount > 0  then
        G.mail.Unread = true
        RebuildBar()
    elseif G.mail.Unread and unreadMailCount == 0 then
        G.mail.Unread = false
        RebuildBar()
    end
    SetIcon("mail", settings.mail.good and G.mail.Unread and "good" or "normal")
    if G.mail.Unread and settings.mail.pulse then
        AddPulseItem("mail")
    else
        RemovePulseItem("mail")
    end
    G.mail.Info =
        G.colors[settings.mail.good and G.mail.Unread and "good" or "normal"]:Colorize(unreadMailCount)
    G.mail.Left = G.colors.normal:Colorize("Unread Mail")
    G.mail.Right = unreadMailCount
    SetIcon("mail", "normal")
end

local function memory()
    local memory = math.floor(collectgarbage("count") / 1024 + 0.5)
    local memColor, iconColor = CheckThresholds(memory, true, settings.memory)
    G.memory.Info = memColor:Colorize(string.format("%sMB", memory))
    G.memory.Left, G.memory.Right =
        G.colors.header:Colorize("Memory usage of all loaded addons."), ""
    SetIcon("memory", iconColor)
end

local function mount()
    local char = G.characterName
    local tracker = settings.Trackers.mount[char]
    local mountTimeLeft = GetTimeUntilCanBeTrained() / 1000
    local carry, carryMax, stamina, staminaBonus, speed, speedMax = GetRidingStats()
    local left = { "Current Training:\nSpeed\nStamina\nCarry Capacity\n\nMount Training Tracker:" }
    local right = { string.format("\n%s/60\n%s/60\n%s/60\n\n", speed, stamina, carry) }
    local timer_maxed = STABLE_MANAGER:IsRidingSkillMaxedOut()
    G.mount.TimerMaxed = timer_maxed
    G.mount.TimerRunning = mountTimeLeft > 0
    local mountlbltxt = timer_maxed and "Max" or
        G.mount.TimerRunning and ConvertSeconds(settings.mount.DisplayPreference, mountTimeLeft) or
        "TRAIN!"

    if timer_maxed and G.mount.TimerVisible or
        not timer_maxed and not G.mount.TimerVisible then
        G.mount.TimerVisible = not G.mount.TimerVisible
        RebuildBar()
    end
    
    local allmaxed = true
    local train_other = false
    for _, k in ipairs(SortCharacters(settings.Trackers.mount)) do
        local v = settings.Trackers.mount[k]
        if v and v[1] and v[2] ~= -1 and k ~= "LocalPlayer" then
            local timeLeft = v[2] - os.time()
            local rowColor
            if timeLeft > 0 then
                timeLeft = ConvertSeconds(settings.mount.DisplayPreference, timeLeft)
                rowColor = k == char and G.colors.active or G.colors.normal
            else
                train_other = k ~= char
                timeLeft = "TRAIN!"
                rowColor = train_other and G.colors.warning or G.colors.danger
            end
            table.insert(left, rowColor:Colorize(k))
            table.insert(right, rowColor:Colorize(timeLeft))
            allmaxed = false -- if we're here, v[2] ~= -1, i. e. this character haven't yet maxed out
        end
    end
    G.mount.allmaxed = allmaxed
    
    if mountlbltxt == "TRAIN!" or train_other then
        if train_other then
            mountlbltxt = G.colors.danger:Colorize(mountlbltxt)
            SetIcon("mount", "danger")
        elseif settings.mount.good then
            mountlbltxt = G.colors.good:Colorize(mountlbltxt)
            SetIcon("mount", "good")
        end
        if settings.mount.critical then
            AddPulseItem("mount")
        end
    else
        if settings.mount.good then
            SetIcon("mount", "normal")
        end
        RemovePulseItem("mount")
    end
    
    G.mount.Info = mountlbltxt
    G.mount.Left = table.concat(left, "\n")
    G.mount.Right = table.concat(right, "\n")
end

local function UpdateKillingBlows( eventID, result , isError , abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log )
    if G.pvpMode and sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_OTHER then
        G.kills = G.kills + 1
        if abilityName ~= "" then -- If I got the killing blow
            G.killingBlows = G.killingBlows + 1
        end
    end
end

local function UpdateDeaths()
    if G.pvpMode then
        G.deaths = G.deaths + 1
    end
end

local function UpdateLeadCount()
    
end

local function pvp()
    local pvp = IsUnitPvPFlagged("player")
    if pvp ~= G.pvpMode then
        -- mode changed
        G.pvpMode = pvp
        if G.pvpMode then
            -- just getting into PvP
            G.kills, G.killingBlows, G.deaths = 0, 0, 0
        end
        ShowBar()
        RebuildBar()
    end
    G.killRatio = G.deaths == 0 and tostring(G.killingBlows) or
        string.format("%s:1", round(G.killingBlows/G.deaths, 1))
    G.kc.Info = G.colors.normal:Colorize(zo_strformat(pvpFormats[settings.kc.DisplayPreference],
        G.killingBlows, G.kills, G.deaths, G.killRatio))
    G.kc.Left = G.colors.header:Colorize("Kill Counter.") ..
        G.colors.normal:Colorize("\n\nKilling Blows\nAssists\nDeaths\nKill/Death Ratio")
    G.kc.Right = G.colors.highlight:Colorize(string.format("\n\n%s\n%s\n%s\n%s",
        G.killingBlows, G.kills, G.deaths, G.killRatio))
    SetIcon("kc", "normal")
end

local function skyshards()
    local availablePoints = GetAvailableSkillPoints()
    local skyShards = GetNumSkyShards()
    local fmt = skyshardsFormats[settings.skyshards.DisplayPreference]
    G.skyshards.Info = G.colors.normal:Colorize(
        zo_strformat(fmt, skyShards, availablePoints, 3 - skyShards))
    G.skyshards.Left = string.format("%s\nCollected Sky Shards\nUnspent Skill Points",
        G.colors.header:Colorize(skyshardsToolTips[settings.skyshards.DisplayPreference] or ""))
    G.skyshards.Right =
        G.colors.highlight:Colorize(string.format("\n%d\n%s", skyShards, availablePoints))
    SetIcon("skyshards", "normal")
end

local function ft()
    local remain, duration = GetRecallCooldown()
    local timeLeft = ConvertSeconds("simple", math.floor(remain / 1000))
    if timeLeft == "" then timeLeft = "--" end
    local cost = GetRecallCost()
    G.ft.TimerRunning = remain > 0
    if G.ft.TimerRunning ~= G.ft.TimerVisible then
        G.ft.TimerVisible = G.ft.TimerRunning
        RebuildBar()
    end
    cost = settings.bar.thousandsSeparator and zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(cost)) or tostring(cost)
    G.ft.Info = G.colors.normal:Colorize(
        settings.ft.DisplayPreference == "time left" and timeLeft or
        settings.ft.DisplayPreference == "cost" and cost.."g" or
        zo_strformat("<<1>>/<<2>>g", timeLeft, cost))
    G.ft.Left = G.colors.header:Colorize(ftToolTips[settings.ft.DisplayPreference]  or "\n")
    G.ft.Right = ""
    SetIcon("ft", "normal")
end

local function getitemcharge(slotNum)
    local itemLink = GetItemLink( BAG_WORN, slotNum )
    if itemLink == nil or not IsItemChargeable( BAG_WORN, slotNum ) then
        return 10000
    end
    return math.floor(100 * GetItemLinkNumEnchantCharges(itemLink) / GetItemLinkMaxEnchantCharges(itemLink))
end

local function wc()
    local activeWeaponPair, locked = GetActiveWeaponPairInfo()
    local mainHandHasPoison, mainHandPoisonCount, _, _ =
        GetItemPairedPoisonInfo(EQUIP_SLOT_MAIN_HAND)
    local backupMainHandHasPoison, backupMainHandPoisonCount, _, _ =
        GetItemPairedPoisonInfo(EQUIP_SLOT_BACKUP_MAIN)
    local mainHandChargePerc = getitemcharge(EQUIP_SLOT_MAIN_HAND)
    local offHandChargePerc = getitemcharge(EQUIP_SLOT_OFF_HAND)
    local backupMainHandChargePerc = getitemcharge(EQUIP_SLOT_BACKUP_MAIN)
    local backupOffHandChargePerc = getitemcharge(EQUIP_SLOT_BACKUP_OFF)
    local left, right = { G.colors.header:Colorize("Weapon Charge:") }, { "" }
    local mainCharge, offCharge, hasPoison, poisonCount
    if activeWeaponPair == 0 then
        G.wc.ToolTipLeft = left[1] .. G.colors.critical:Colorize("No weapons are equipped.")
        G.wc.Info = "--"
        return
    elseif activeWeaponPair == 1 then
        mainCharge, offCharge, hasPoison, poisonCount =
            mainHandChargePerc, offHandChargePerc, mainHandHasPoison, mainHandPoisonCount
    elseif activeWeaponPair == 2 then
        mainCharge, offCharge, hasPoison, poisonCount =
            backupMainHandChargePerc, backupOffHandChargePerc, backupMainHandHasPoison, backupMainHandPoisonCount
    end
    local leastPerc = offCharge < mainCharge and offCharge or mainCharge
    local wcColor, iconColor, poisonColor = getWCColor(leastPerc, hasPoison, poisonCount)
    if hasPoison and settings.wc.AutoPoison then
        G.wc.Info = poisonColor:Colorize(poisonCount)
    elseif leastPerc == 10000 then
        G.wc.Info = wcColor:Colorize("--")
    else
        G.wc.Info = wcColor:Colorize(string.format("%s%%", leastPerc))
    end
    SetIcon("wc", iconColor)
    if hasPoison and settings.wc.AutoPoison then
        if poisonCount < settings.poison.critical and settings.bar.pulseWhenCritical then
            AddPulseItem("wc")
        elseif poisonCount >= settings.poison.critical or not settings.bar.pulseWhenCritical then
            RemovePulseItem("wc")
        end
    else
        if leastPerc < settings.wc.critical and settings.bar.pulseWhenCritical then
            AddPulseItem("wc")
        elseif leastPerc >= settings.wc.critical or not settings.bar.pulseWhenCritical then
            RemovePulseItem("wc")
        end
    end
    -- charges of all weapons
    for _, p in ipairs({
        { mainHandChargePerc, mainHandHasPoison, mainHandPoisonCount, EQUIP_SLOT_MAIN_HAND, },
        { offHandChargePerc,  mainHandHasPoison, mainHandPoisonCount, EQUIP_SLOT_OFF_HAND},
        { backupMainHandChargePerc, backupMainHandHasPoison, backupMainHandPoisonCount, EQUIP_SLOT_BACKUP_MAIN, },
        { backupOffHandChargePerc,  backupMainHandHasPoison, backupMainHandPoisonCount, EQUIP_SLOT_BACKUP_OFF},
    }) do
        local handChargePerc, handHasPoison, handPoisonCount, equipSlot = unpack(p)
        if handChargePerc and handChargePerc ~= 10000 then
            local wcColor, iconColor, poisonColor =
                getWCColor(handChargePerc, handHasPoison, handPoisonCount)
            table.insert(left, wcColor:Colorize(zo_strformat("<<C:1>>", GetItemName(BAG_WORN, equipSlot))))
            table.insert(right, wcColor:Colorize(string.format("%s%%", handChargePerc)))
        end
    end
    -- poisons on all weapons
    if mainHandHasPoison or backupMainHandHasPoison then
        table.insert(left, G.colors.header:Colorize("\nPoison Count:"))
        table.insert(right, "\n")
        for _, p in ipairs({
            { mainHandChargePerc, mainHandHasPoison, mainHandPoisonCount, "Primary Weapon", },
            { backupMainHandChargePerc, backupMainHandHasPoison, backupMainHandPoisonCount, "Secondary Weapon", },
            }) do
            local handChargePerc, handHasPoison, handPoisonCount, equipSlot = unpack(p)
            if handHasPoison then
                local wcColor, iconColor, poisonColor = getWCColor(handChargePerc, handHasPoison, handPoisonCount)
                table.insert(left, poisonColor:Colorize(equipSlot))
                table.insert(right, poisonColor:Colorize(handPoisonCount))
            end
        end
    end
    G.wc.Left, G.wc.Right = table.concat(left, "\n"), table.concat(right, "\n")
end

function getWCColor(wcPerc, hasPoison, poisonCount)
    local wcColor, poisonColor, iconColor = G.colors.normal, G.colors.normal, "normal"
    if hasPoison and settings.wc.AutoPoison then
        poisonColor, iconColor = CheckThresholds(poisonCount, false, settings.poison)
    elseif wcPerc then
        wcColor, iconColor = CheckThresholds(wcPerc, false, settings.wc)
    end
    return wcColor, iconColor, poisonColor
end

local TEBfunctions = { level, balance, bank, bag, bagItems, bounty, buffs, clock,   
    companion, durability, enlightenment, equipped, esoplus, experience, fps, ft, latency,
    leads, location, lock, mail, memory, mount, pvp, skyshards, wc, }

local function SetPulse() -- used in callback from SetterFactory()
    local speed = settings.bar.pulseSpeed
    local pulseFunctions = {
        ["none"]                = function(t) return 1 end,
        ["fade in"]             = function(t) return t % speed / speed  end,
        ["fade out"]            = function(t) return 1 - t % speed / speed end,
        ["fade in/out"]         = function(t) return math.abs(2 * (t % speed) - speed) / speed end,
        ["blink"]               = function(t) return math.floor(10 * t / speed) % 2 end,
    }
    G.pulseFunction = pulseFunctions[settings.bar.pulseType]
end

local function RefreshBar(forceRebuild, timerun)
    if not G.addonInitialized or not settings then return end
    
    if forceRebuild then
        -- rebuild data for every gadget when force==true 
        -- (this is done from OnUpdate every second, and occassionally in other places)
        for _, func in ipairs(TEBfunctions) do
            func()
        end
        -- research gadgets are done separately
        for k, v in pairs(crafts) do
            crafting(k, v.icon, v.id)
        end
        AddToMountDatabase(G.characterName)
        
        -- display labels
        for key, gadget in pairs(gadgetReference) do
            local txt = settings.gadgetTextEnabled[key] and G[key].Info or ""
            gadget.text:SetText(txt)
        end
        UpdateControlsPosition()
    
        -- reposition the bar as needed
        if settings.bar.bumpCompass and settings.bar.Position == "top" and
                ZO_CompassFrame:GetTop() == G.original.CompassTop or
            settings.bar.bumpActionBar and settings.bar.Position == "bottom" and
                ZO_ActionBar1:GetTop() == G.original.ActionBarTop then
            SetBarPosition()
        end 
    end

    -- pulsing gadgets
    if timerun then -- timerun ~= nil if called from OnUpdate
        local pulseAlpha = G.pulseFunction(timerun)
        for i = 1, #G.pulseList do
            if pulseAlpha < 2 then
                local g = gadgetReference[G.pulseList[i]]
                g.icon:SetAlpha(pulseAlpha)
                g.text:SetAlpha(pulseAlpha)
            end
        end
    end
    
    -- autohide
    if settings.autohide.speed == 0 then
        G.barAlpha = G.hideBar and 0 or settings.bar.opacity
    else
        local step = 1 / settings.autohide.speed
        if G.hideBar then
            G.barAlpha =  G.barAlpha > 0 and G.barAlpha - step or 0
        else
            G.barAlpha =  G.barAlpha < settings.bar.opacity and G.barAlpha + step or
                settings.bar.opacity
        end
    end
    TEBTop:SetAlpha(G.barAlpha)

    G.inCombat = IsUnitInCombat("player")
    local maxAlpha = settings.bar.combatOpacity
    local incrementAlpha = settings.autohide.speed == 0 and 1 or maxAlpha / settings.autohide.speed
    if G.inCombat and settings.bar.combatIndicator and G.combatAlpha < maxAlpha then
        G.combatAlpha = G.combatAlpha + incrementAlpha
        if G.combatAlpha > maxAlpha then G.combatAlpha = maxAlpha end
        TEBTopCombatBG:SetAlpha(G.combatAlpha)
        G.showCombatOpacity = 300
    elseif not G.inCombat and G.combatAlpha > 0 and G.showCombatOpacity == 0 then
        G.combatAlpha = G.combatAlpha - incrementAlpha
        if G.combatAlpha < 0 then G.combatAlpha = 0 end
        TEBTopCombatBG:SetAlpha(G.combatAlpha)
    elseif G.showCombatOpacity > 0 then
        G.showCombatOpacity = G.showCombatOpacity - 1
    end
end

local lastrun = 0
local function OnUpdate(self, timerun)
    local forceRebuild = false
    -- force rebuild of gadget data once per second 
    if timerun - lastrun > 1.0 then
        lastrun = timerun
        forceRebuild = true
    end
    RefreshBar(forceRebuild, timerun)
end
    
local function CreateSettingsWindow()
    local name, k, v, key, r
    local panelData = {
        type = "panel",
        name = "The Elder Bar Reloaded",
        displayName = TEB.displayName,
        author = TEB.author,
        version = TEB.version,
        slashCommand = "/teb",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local visibilityChoiceList = { "Off", "PvE only ", "PvP only", "PvE & PvP", }
    local visibilityValueList = { 0, 1, 2, 3, }
    local lvlChoiceList = { "Character Level", "Character Level/Champion Points", "Champion Points", }
    local lvlValueList = { 1, 2, 3, }
    local iconChoiceList = { "Character class icon", "CP icon", }
    local iconValueList = { 1, 2, }
    local currencyChoices = {
        "on character",
        "on character/in bank",
        "on character (in bank)",
        "character+bank",
        "tracked",
        "tracked+bank",
        "total",
        "on character/total",
        "on character (total)",
    }

    local function VisibilityGetterFactory(key)
        return function() return G.gadgetVisibility[key] end
    end

    local function VisibilitySetterFactory(key)
        return
            function(newValue)
                -- newValue = 1 or 3 - visible on PvE, 2 or 3 - visible on PvP
                G.gadgetVisibility[key] = newValue
                UpdateGadgetVisibility(key, newValue)
                UpdateControlsPosition()
            end
    end

    local GadgetVisibilityControls = { }
    for k, v in pairs(gadgetReference) do
        table.insert(GadgetVisibilityControls, {
            key = k,
            name = v.name,
            type = "dropdown",
            default = 0,
            choices = visibilityChoiceList,
            choicesValues = visibilityValueList,
            getFunc = VisibilityGetterFactory(k),
            setFunc = VisibilitySetterFactory(k),
        })
    end
    table.sort(GadgetVisibilityControls, function(a, b) return a.name < b.name end)

    local function GetterFactory(submenu, option)
        return function() return settings[submenu][option] end
    end

    local function SetterFactory(submenu, option, callback)
        return function(newValue)
            settings[submenu][option] = newValue
            if callback then callback() end
        end
    end

    local function ColorPickerFactory(tag, name, tooltip, default)
        return {
            type = "colorpicker",
            name = name,
            tooltip = tooltip,
            default = default,
            getFunc = function() return G.colors[tag]:UnpackRGBA() end,
            setFunc = function(r, g, b, a)
                settings.colors[tag] = { r = r, g = g, b = b, a = a, }
                G.colors[tag] = ZO_ColorDef:New(r, g, b, a)
                RefreshBar(true)
            end,
        }
    end

    local colorPickers = { }
    for k, v in ipairs(colorsMenu) do
        table.insert(colorPickers, ColorPickerFactory(v.name, v.desc, v.tooltip, G.colors[v.name]))
    end

    local function AutoHideCheckBoxFactory(tag, name, tooltip)
        return  {
                    type = "checkbox",
                    name = name,
                    default = true,
                    tooltip = tooltip,
                    getFunc = GetterFactory("autohide", tag),
                    setFunc = SetterFactory("autohide", tag),
                }
    end

    local function CurrencyLimit(name, key, high_low, danger_level)
        return {
            type = "editbox",
            textType = TEXT_TYPE_NUMERIC_UNSIGNED_INT,
            name = name,
            tooltip = string.format("Enter %d to disable",
                high_low == "high" and 999999999 or 0),
            default = high_low == "high" and 999999999 or 0,
            isMultiline = false,
            isExtraWide = false,
            maxChars = 9,
            getFunc = function() return settings[key][high_low][danger_level] end,
            setFunc = function(newValue)
                settings[key][high_low][danger_level] = tonumber(newValue)
            end,
        }
    end

    local function CurrencyControls(key)
        return
            {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose what to display in the gadget.",
                    choices = currencyChoices,
                    default = "on character",
                    getFunc = GetterFactory(key, "DisplayPreference"),
                    setFunc = SetterFactory(key, "DisplayPreference"),
                },
                {
                    type = "dropdown",
                    name = "Tooltip format",
                    tooltip = "Choose what to display for this currency in tooltips.",
                    choices = currencyChoices,
                    default = "on character",
                    getFunc = GetterFactory(key, "TooltipPreference"),
                    setFunc = SetterFactory(key, "TooltipPreference"),
                },
                CurrencyLimit("Warning below this level", key, "low", "warning"),
                CurrencyLimit("Danger below this level", key, "low", "danger"),
                CurrencyLimit("Warning above this level", key, "high", "warning"),
                CurrencyLimit("Danger above this level", key, "high", "danger"),
                {
                    type = "checkbox",
                    name = "Track this character",
                    tooltip = "Track this character's currency.",
                    default = true,
                    -- disabled = function() return DisableGoldTracker(key) end,
                    getFunc = function() return GetCharacterGoldTracked(key) end,
                    setFunc = function(newValue)
                        SetCharacterGoldTracked(newValue, key)
                    end,
                },
            }
    end

    local function SetBangAsPercentageFactory(subsettings, maxItems, bagOrBank)
        return function(newValue)
            subsettings.UsageAsPercentage = newValue
            local newMax = newValue and 100 or maxItems
            local factor = newValue and 100/maxItems or maxItems/100
            local slidervalue

            for i, w in ipairs({"Caution", "Warning", "Danger", "Critical"}) do
                local objname = string.format("TEB%sSlider%s", bagOrBank, w)
                local s = _G[objname]
                -- controlStructure[n].controls[i], where bag: n=7, bank: n=8, sliders: i=4..7
                slidervalue = s.data.getFunc()
                s.data.max = newMax
                s.slider:SetMinMax(0, newMax)
                s.maxText:SetText(newMax)
                s:UpdateValue(false, slidervalue * factor)
            end
        end
    end

    local controlStructure = {
        {
            type = "submenu",
            name = "General Settings",
            controls = {
                {
                    type = "checkbox",
                    name = "Lock the bar",
                    tooltip = "Lock the bar, preventing it from being moved.",
                    default = true,
                    getFunc = function() return settings.bar.Locked end,
                    setFunc = function(newValue)
                        LockUnlockBar(newValue)
                        lock()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Lock the gadgets",
                    tooltip = "Lock the gadgets, preventing them from being moved.",
                    default = true,
                    getFunc = function() return settings.bar.gadgetsLocked end,
                    setFunc = function(newValue)
                        LockUnlockGadgets(newValue)
                        lock()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Sort characters by age",
                    tooltip = "Sort characters in lists like mount tracker) by age (from earliest created) rather than by name (alphabetically)",
                    default = true,
                    getFunc = function() return settings.bar.sort end,
                    setFunc = function(newValue)
                        settings.bar.sort = newValue
                        G.characterSortCache = nil -- invalidate cache
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show messages in chat",
                    tooltip = "Show a message in chat on initialization and each time the bar or gadgets are locked or unlocked.",
                    default = true,
                    getFunc = GetterFactory("bar", "chatMessagesOn"), setFunc = SetterFactory("bar", "chatMessagesOn"),
                },
                {
                    type = "dropdown",
                    name = "Icon color",
                    tooltip = "Choose how you'd like the icons displayed.",
                    default = "color",
                    choices = {"monochrome", "color"},
                    choicesValues = {"white", "color"},
                    getFunc = function() return settings.bar.iconsMode end,
                    setFunc = function(newValue)
                        settings.bar.iconsMode = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Icons inherit color",
                    tooltip = "Should icons be the same color as their labels?",
                    default = true,
                    getFunc = GetterFactory("bar", "iconsInherit"), setFunc = SetterFactory("bar", "iconsInherit"),
                },
                {
                    type = "slider",
                    name = "Draw Layer (0=background, 4=foreground)",
                    tooltip = "Choose which layer on which you'd like the bar drawn. Background is underneath everything, foreground is on top of everything.",
                    min = 0,
                    max = 4,
                    step = 1,
                    default = 0,
                    getFunc = function() return settings.bar.Layer end,
                    setFunc = function(newValue)
                        settings.bar.Layer = newValue
                        SetBarLayer()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Bump compass down when bar at top",
                    tooltip = "Bump the compass down if the bar position is set to top. Disable this if other addons will be moving the compass.",
                    default = true,
                    warning = "Disabling this will cause UI reload.",
                    getFunc = function() return settings.bar.bumpCompass end,
                    setFunc = function(newValue)
                        settings.bar.bumpCompass = newValue
                        ReloadUI("ingame")
                        if not settings.bar.bumpCompass then
                            ReloadUI("ingame")
                        else
                            SetBarPosition()
                            UpdateControlsPosition()
                        end
                    end,
                },
                {
                    type = "checkbox",
                    name = "Bump action/resource bars up when bar at bottom",
                    tooltip = "Bump the action bar, magicka, health, and stamina bars up if the bar position is set to bottom. Disable this if other addons will be moving the action bar or health/stamina/magicka bars.",
                    default = true,
                    warning = "Disabling this will cause UI reload.",
                    getFunc = function() return settings.bar.bumpActionBar end,
                    setFunc = function(newValue)
                        settings.bar.bumpActionBar = newValue
                        if not settings.bar.bumpActionBar then
                            ReloadUI("ingame")
                        else
                            SetBarPosition()
                            UpdateControlsPosition()
                        end
                    end,
                },
                {
                    type = "dropdown",
                    name = "Gadgets position",
                    tooltip = "Set The Elder Bar's horizontal position on the screen.",
                    default = "center",
                    choices = {"left", "center", "right"},
                    getFunc = function() return settings.bar.controlsPosition end,
                    setFunc = function(newValue)
                        settings.bar.controlsPosition = newValue
                        UpdateControlsPosition()
                    end,
                },
                {
                    type = "slider",
                    name = "Spacing between gadgets",
                    tooltip = "Set the spacing between gadgets in the bar.",
                    min = 5,
                    max = 30,
                    step = 1,
                    default = 10,
                    getFunc = function() return settings.bar.spacing end,
                    setFunc = function(newValue)
                      settings.bar.spacing = newValue
                      ResizeBar()
                      RebuildBar()
                    end,
                },
                {
                    type = "dropdown",
                    name = "Font",
                    tooltip = "Set the font used for gadget text.",
                    default = "Univers57",
                    choices = {"Univers57", "Univers67", "FTN47", "FTN57", "FTN87", "ProseAntiquePSMT", "Handwritten_Bold", "TrajanPro-Regular"},
                    getFunc = function() return settings.bar.font end,
                    setFunc = function(newValue)
                      settings.bar.font = newValue
                      ResizeBar()
                    end,
                },
                {
                    type = "slider",
                    name = "Scale",
                    tooltip = "Set The Elder Bar's scale.",
                    min = 50,
                    max = 150,
                    step = 5,
                    default = 100,
                    getFunc = function() return settings.bar.scale * 100 end,
                    setFunc = function(newValue)
                      settings.bar.scale = newValue / 100
                      ResizeBar()
                      SetBarPosition()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Use thousands separator",
                    tooltip = "Makes numbers a bit more readable by adding a thousands separator (comma, space, period, etc).",
                    default = true,
                    getFunc = GetterFactory("bar", "thousandsSeparator"), setFunc = SetterFactory("bar", "thousandsSeparator"),
                },
                {
                    type = "checkbox",
                    name = "Pulse gadgets when critical",
                    tooltip = "Pulse gadgets when the critical threshold is reached.",
                    default = false,
                    getFunc = GetterFactory("bar", "pulseWhenCritical"), setFunc = SetterFactory("bar", "pulseWhenCritical"),
                },
                {
                    type = "dropdown",
                    name = "Pulse type",
                    tooltip = "Choose the type of pulse used when a gadget needs your attention.",
                    default = "fade in",
                    choices = {"none", "fade in", "fade out", "fade in/out", "blink"},
                    getFunc = GetterFactory("bar", "pulseType"), setFunc = SetterFactory("bar", "pulseType", SetPulse),
                },
                {
                    type = "slider",
                    name = "Pulse speed (1 = fastest)",
                    min = 1,
                    max = 12,
                    step = 1,
                    default = 6,
                    tooltip = "Choose the speed of pulse used when a gadget needs your attention.",
                    default = false,
                    getFunc = GetterFactory("bar", "pulseSpeed"), setFunc = SetterFactory("bar", "pulseSpeed", SetPulse),
                },
                {
                    type = "dropdown",
                    name = "Background width",
                    tooltip = "Choose how you'd like the bar background displays, either full screen width or dynamic.",
                    default = "dynamic",
                    choices = {"dynamic", "screen width"},
                    getFunc = function() return settings.bar.Width end,
                    setFunc = function(newValue)
                        settings.bar.Width = newValue
                        SetBarWidth(newValue)
                    end,
                },
                {
                    type = "slider",
                    name = "Bar opacity",
                    tooltip = "Set The Elder Bar's opacity (0 - transparent, 100 - opaque)",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 100,
                    getFunc = function() return settings.bar.opacity * 100 end,
                    setFunc = function(newValue)
                        settings.bar.opacity = newValue / 100
                        SetOpacity()
                    end,
                },
                {
                    type = "slider",
                    name = "Bar background opacity",
                    tooltip = "Set The Elder Bar's background opacity (0 - transparent, 100 - opaque)",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 0,
                    getFunc = function() return settings.bar.backgroundOpacity * 100 end,
                    setFunc = function(newValue)
                        settings.bar.backgroundOpacity = newValue / 100
                        SetOpacity()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Draw a border around the bar",
                    tooltip = "Draw a border around the bar.",
                    default = true,
                    getFunc = GetterFactory("bar", "edgedBackground"),
                    setFunc = SetterFactory("bar", "edgedBackground", SetOpacity),
                },
                {
                    type = "checkbox",
                    name = "Turn the bar red when in combat",
                    tooltip = "Turn the bar red with in combat.",
                    default = true,
                    getFunc = GetterFactory("bar", "combatIndicator"), setFunc = SetterFactory("bar", "combatIndicator"),
                },
                {
                    type = "slider",
                    name = "Combat indicator opacity",
                    tooltip = "Set the combat indicator's opacity (0 - transparent, 100 - opaque).",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 100,
                    getFunc = function() return settings.bar.combatOpacity * 100 end,
                    setFunc = function(newValue)
                        settings.bar.combatOpacity = newValue / 100
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = "Custom Colors",
            controls = colorPickers,
        },
        {
            type = "submenu",
            name = "AUTO-HIDE Settings",
            controls = {
                {
                    type = "description",
                    text = "Choose when The Elder Bar will automatically hide and show itself. Hide the bar when:",
                },
                AutoHideCheckBoxFactory("GameMenu", "Opening the game menu", "Hide the bar when you open the game menu (crown store, map, character, inventory, skills, etc."),
                AutoHideCheckBoxFactory("Chatter" , "Conversing with NPCs", "Hide the bar when you talk to any NPC."),
                AutoHideCheckBoxFactory("Crafting", "Using a crafting station", "Hide the bar when you use a crafting station."),
                AutoHideCheckBoxFactory("Bank", "Visiting your personal bank", "Hide the bar when you visit your bank."),
                AutoHideCheckBoxFactory("GuildBank", "Visiting your guild's bank", "Hide the bar when you visit your guild's bank."),
                AutoHideCheckBoxFactory("GuildStore", "Visiting a guild store (trader)", "Hide the bar when you visit a guild store."),
                AutoHideCheckBoxFactory("Store", "Visiting a store (merchant)", "Hide the bar when you visit a store."),
                AutoHideCheckBoxFactory("Digging", "Digging for antiquities", "Hide the bar when you dig for antiquities."),
                {
                    type = "slider",
                    name = "Autohide animation speed",
                    tooltip = "How long will it take for the bar to hide/show (0 - immediately)",
                    min = 0,
                    max = 100,
                    getFunc = GetterFactory("autohide", "speed"), setFunc = SetterFactory("autohide", "speed"),
                },
            },
        },
        {
            type = "submenu",
            name = G.colors.craft:Colorize("Gadget Visibility"),
            controls = GadgetVisibilityControls,
        },
        {
            type = "header",
            name = G.colors.fitness:Colorize(" Gadget Options"),

        },
        {
            name = "Alliance Points",
            controls = CurrencyControls("ap"),
        },
        {
            name = "Archival Fortunes",
            controls = {
            },
        },
        {
            name = "Bag Space",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display bag space.",
                    default = "slots used/total slots",
                    choices = {"slots used/total slots", "used%", "slots free/total slots", "slots free", "free%"},
                    getFunc = GetterFactory("bag", "DisplayPreference"), setFunc = SetterFactory("bag", "DisplayPreference"),
                },
                {
                    type = "checkbox",
                    name = "Thresholds as percentage of the total space",
                    tooltip = "Thresholds are expressed in percents of total space rather than absolute values",
                    default = true,
                    getFunc = GetterFactory("bag", "UsageAsPercentage"),
                    setFunc = SetBangAsPercentageFactory(settings.bag, 210, "Bag"),
                },
                {
                    type = "slider",
                    name = "Caution threshold",
                    tooltip = "Choose at what percentage bag space will be colored yellow.",
                    min = 0,
                    max = settings.bag.UsageAsPercentage and 100 or 210,
                    step = 1,
                    default = settings.bag.UsageAsPercentage and 50 or 105,
                    decimals = 0,
                    reference = "TEBBagSliderCaution",
                    getFunc = GetterFactory("bag", "caution"), setFunc = SetterFactory("bag", "caution"),
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "Choose at what percentage bag space will be colored orange.",
                    min = 0,
                    max = settings.bag.UsageAsPercentage and 100 or 210,
                    step = 1,
                    default = settings.bag.UsageAsPercentage and 80 or 168,
                    decimals = 0,
                    reference = "TEBBagSliderWarning",
                    getFunc = GetterFactory("bag", "warning"), setFunc = SetterFactory("bag", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "Choose at what percentage bag space will be colored red.",
                    min = 0,
                    max = settings.bag.UsageAsPercentage and 100 or 210,
                    step = 1,
                    default = settings.bag.UsageAsPercentage and 90 or 189,
                    decimals = 0,
                    reference = "TEBBagSliderDanger",
                    getFunc = GetterFactory("bag", "danger"), setFunc = SetterFactory("bag", "danger"),
                },
                {
                    type = "slider",
                    name = "Critical threshold",
                    tooltip = "Bag Space used over this percentage will cause the gadget to pulse.",
                    min = 0,
                    max = settings.bag.UsageAsPercentage and 100 or 210,
                    step = 1,
                    default = settings.bag.UsageAsPercentage and 99 or 209,
                    decimals = 0,
                    reference = "TEBBagSliderCritical",
                    getFunc = GetterFactory("bag", "critical"), setFunc = SetterFactory("bag", "critical"),
                },
            },
        },
        {
            name = "Bank Space",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display bank space.",
                    default = "slots used/total slots",
                    choices = {"slots used/total slots", "used%", "slots free/total slots", "slots free", "free%"},
                    getFunc = GetterFactory("bank", "DisplayPreference"), setFunc = SetterFactory("bank", "DisplayPreference"),
                },
                {
                    type = "checkbox",
                    name = "Thresholds as percentage of the total space",
                    tooltip = "Thresholds are expressed in percents of total space rather than absolute values",
                    default = false,
                    getFunc = GetterFactory("bank", "UsageAsPercentage"),
                    setFunc = SetBangAsPercentageFactory(settings.bank, 480, "Bank"),
                },
                {
                    type = "slider",
                    name = "Caution threshold",
                    tooltip = "Choose at what percentage bank space will be colored yellow.",
                    min = 0,
                    max = settings.bank.UsageAsPercentage and 100 or 480,
                    step = 1,
                    default = settings.bank.UsageAsPercentage and 50 or 240,
                    decimals = 0,
                    reference = "TEBBankSliderCaution",
                    getFunc = GetterFactory("bank", "caution"), setFunc = SetterFactory("bank", "caution"),
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "Choose at what percentage bank space will be colored orange.",
                    min = 0,
                    max = settings.bank.UsageAsPercentage and 100 or 480,
                    step = 1,
                    default = 360,
                    decimals = 0,
                    reference = "TEBBankSliderWarning",
                    getFunc = GetterFactory("bank", "warning"), setFunc = SetterFactory("bank", "warning"),
                    reference = "TEBBankSliderWarning",
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "Choose at what percentage bank space will be colored red.",
                    min = 0,
                    max = settings.bank.UsageAsPercentage and 100 or 480,
                    step = 1,
                    default = settings.bank.UsageAsPercentage and 90 or 432,
                    decimals = 0,
                    reference = "TEBBankSliderDanger",
                    getFunc = GetterFactory("bank", "danger"), setFunc = SetterFactory("bank", "danger"),
                    reference = "TEBBankSliderDanger",
                },
                {
                    type = "slider",
                    name = "Critical threshold",
                    tooltip = "Bank Space used over this percentage will cause the gadget to pulse.",
                    min = 0,
                    max = settings.bank.UsageAsPercentage and 100 or 480,
                    step = 1,
                    default = settings.bank.UsageAsPercentage and 99 or 479,
                    decimals = 0,
                    reference = "TEBBankSliderCritical",
                    getFunc = GetterFactory("bank", "critical"), setFunc = SetterFactory("bank", "critical"),
                    reference = "TEBBankSliderCritical",

                },
            },
        },
        {
            name = "Bounty/Heat Timer",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display the bounty timer.",
                    default = "simple",
                    choices = {"simple", "short", "exact"},
                    getFunc = GetterFactory("bounty", "DisplayPreference"), setFunc = SetterFactory("bounty", "DisplayPreference"),
                },
                {
                    type = "checkbox",
                    name = "Dynamically show timer",
                    default = true,
                    tooltip = "Show the icon and timer only when you have a bounty or heat.",
                    getFunc = function() return settings.bounty.Dynamic end,
                    setFunc = function(newValue)
                        settings.bounty.Dynamic = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "dropdown",
                    name = "Upstanding shown as",
                    tooltip = "What color to use for upstanding status",
                    default = "normal",
                    choices = {"normal", "good"},
                    getFunc = GetterFactory("bounty", "good"), setFunc = SetterFactory("bounty", "good"),
                },
            },
        },
        {
            name = "Clock",
            controls = {
                {
                    type = "description",
                    text = "For Tamriel time and dates |cffff00LibClockTST|r must be installed",
                },
                {
                    type = "dropdown",
                    name = "Clock(s) to display",
                    tooltip = "Choose what to display as clock.",
                    default = "local time",
                    choices = {"Local date and time", "Local time", "UTC time", "Tamriel time", "Local time/Tamriel time", },
                    choicesValues = {"local date and time", "local time", "UTC time", "ingame time", "local time/ingame time", },
                    getFunc = GetterFactory("clock", "DisplayPreference"), setFunc = SetterFactory("clock", "DisplayPreference"),
                },
                {
                    type = "dropdown",
                    name = "Time format",
                    tooltip = "Choose how to display the time.",
                    default = "24h",
                    choices = { "24h", "24h with seconds", "12h", "12h no leading zero", "12h with seconds" },
                    getFunc = GetterFactory("clock", "Type"), setFunc = SetterFactory("clock", "Type"),
                },
                {
                    type = "dropdown",
                    name = "Date format",
                    tooltip = "Choose how to display the date.",
                    default = "24h",
                    choices = {"YYYY-MM-DD", "DD.MM.YY", "DD Mon", "DD Month", "Imperial", "Argonian" },
                    choicesValues = { "%Y-%m-%d", "%d.%m.%y", "%d %b", "%d %B", "%d %BI", "%d %BA", },
                    getFunc = GetterFactory("clock", "DateFormat"), setFunc = SetterFactory("clock", "DateFormat"),
                },
            },
        },
        {
            name = "Companion Info",
            controls = {
                {
                    type = "checkbox",
                    name = "Hide when no active companion",
                    default = true,
                    tooltip = "Automatically hide the Companion gadget when the character has no active companion.",
                    getFunc = function() return settings.companion.Dynamic end,
                    setFunc = function(newValue)
                        settings.companion.Dynamic = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "dropdown",
                    name = "Field separator",
                    tooltip = "Choose character to separate fields in this gadget's label.",
                    default = " ",
                    choices = {"space", "slash", "dash", "comma", },
                    choicesValues = { " ", "/", "-", ",", },
                    getFunc = GetterFactory("companion", "separator"), setFunc = SetterFactory("companion", "separator", companion),
                },
                {
                    type = "checkbox",
                    name = "Show companion's name",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("companion", "name"), setFunc = SetterFactory("companion", "name", companion),
                },
                {
                    type = "checkbox",
                    name = "Show companion's experience",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("companion", "XP"), setFunc = SetterFactory("companion", "XP", companion),
                },
                {
                    type = "checkbox",
                    name = "Show % of companion's next level experience",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("companion", "XPPercent"), setFunc = SetterFactory("companion", "XPPercent", companion),
                },
                {
                    type = "checkbox",
                    name = "Show companion's level",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("companion", "level"), setFunc = SetterFactory("companion", "level", companion),
                },
                {
                    type = "checkbox",
                    name = "Show companion's rapport",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("companion", "rapport"), setFunc = SetterFactory("companion", "rapport", companion),
                },
                {
                    type = "checkbox",
                    name = "Show companion's rapport level",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("companion", "rapportLevel"), setFunc = SetterFactory("companion", "rapportLevel", companion),
                },
                {
                    type = "checkbox",
                    name = "Show companion's rapport level description",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("companion", "rapportLevelDesc"), setFunc = SetterFactory("companion", "rapportLevelDesc", companion),
                },
                {
                    type = "checkbox",
                    name = "Hide companion's rapport if maxed out",
                    default = false,
                    tooltip = "",
                    getFunc = GetterFactory("companion", "rapportHide"), setFunc = SetterFactory("companion", "rapportHide", companion),
                },
            },
        },
        {
            name = "Crown Gems",
            controls = {
            },
        },
        {
            name = "Crowns",
            controls = {
            },
        },
        {
            name = "Durability",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display durability.",
                    default = "durability %",
                    choices = {"durability %", "durability %/repair cost", "repair cost", "durability % (repair kits)", "durability %/repair cost (repair kits)", "repair cost (repair kits)", "most damaged", "most damaged/durability %", "most damaged/durability %/repair cost", "most damaged/repair cost"},
                    getFunc = GetterFactory("durability", "DisplayPreference"), setFunc = SetterFactory("durability", "DisplayPreference"),
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "Choose at what percentage durability will be colored yellow.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 50,
                    getFunc = GetterFactory("durability", "warning"), setFunc = SetterFactory("durability", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "Choose at what percentage durability will be colored red, indicating armor is about to break.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 25,
                    getFunc = GetterFactory("durability", "danger"), setFunc = SetterFactory("durability", "danger"),
                },
                {
                    type = "slider",
                    name = "Critical threshold (pulse red)",
                    tooltip = "Durability below this number will cause the gadget to pulse.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 10,
                    getFunc = GetterFactory("durability", "critical"), setFunc = SetterFactory("durability", "critical"),
                },
            },
        },
        --[[
        {
            name = "Endeavor Progress",
            controls = {
                {
                    type = "dropdown",
                    name = "Field separator",
                    tooltip = "Choose character to separate fields in this gadget's label.",
                    default = " ",
                    choices = {"space", "slash", "dash", "pipe", },
                    choicesValues = { " ", "/", "-", "|", },
                    getFunc = GetterFactory("endeavors", "separator"), setFunc = SetterFactory("endeavors", "separator", companion),
                },
                {
                    type = "checkbox",
                    name = "Show remaining daily endeavors",
                    default = false,
                    tooltip = "",
                    getFunc = GetterFactory("endeavors", "daily_todo"), setFunc = SetterFactory("endeavors", "daily_todo", companion),
                },
                {
                    type = "checkbox",
                    name = "Show remaining weekly endeavors",
                    default = false,
                    tooltip = "",
                    getFunc = GetterFactory("endeavors", "weekly_todo"), setFunc = SetterFactory("endeavors", "weekly_todo", companion),
                },
                {
                    type = "checkbox",
                    name = "Show completed daily endeavors",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("endeavors", "daily_done"), setFunc = SetterFactory("endeavors", "daily_done", companion),
                },
                {
                    type = "dropdown",
                    name = "Remaining time display format",
                    tooltip = "Choose how to display the daily/weekly timer.",
                    default = "simple",
                    choices = { "simple", "short", "exact" },
                    getFunc = GetterFactory("endeavors", "TimeFormat"), setFunc = SetterFactory("endeavors", "TimeFormat"),
                },
                {
                    type = "checkbox",
                    name = "Show completed weekly endeavors",
                    default = true,
                    tooltip = "",
                    getFunc = GetterFactory("endeavors", "weekly_done"), setFunc = SetterFactory("endeavors", "weekly_done", companion),
                },
                {
                    type = "checkbox",
                    name = "Show remaining time for daily endeavors",
                    default = false,
                    tooltip = "",
                    getFunc = GetterFactory("endeavors", "daily_time"), setFunc = SetterFactory("endeavors", "daily_time", companion),
                },
                {
                    type = "checkbox",
                    name = "Show remaining time for weekly endeavors",
                    default = false,
                    tooltip = "",
                    getFunc = GetterFactory("endeavors", "weekly_time"), setFunc = SetterFactory("endeavors", "weekly_time", companion),
                },
                {
                    type = "checkbox",
                    name = "Hide when everything completed",
                    default = true,
                    tooltip = "Automatically hide the Endeavor Progress gadget when both daily and weekly endeavors have been completed.",
                    getFunc = function() return settings.endeavors.Dynamic end,
                    setFunc = function(newValue)
                        settings.endeavors.Dynamic = newValue
                        RebuildBar()
                    end,
                },
                
                {
                    type = "slider",
                    name = "Progress caution threshold",
                    tooltip = "Caution if less than this time left to finish the endeavors.",
                    min = 0,
                    max = 86400,
                    step = 600,
                    default = 7200,
                    getFunc = GetterFactory("endeavors", "caution"), setFunc = SetterFactory("endeavors", "caution"),
                },
                {
                    type = "slider",
                    name = "Progress warning threshold",
                    tooltip = "Warning  if less than this time left to finish the endeavors.",
                    min = 0,
                    max = 86400,
                    step = 600,
                    default = 3600,
                    getFunc = GetterFactory("endeavors", "warning"), setFunc = SetterFactory("endeavors", "warning"),
                },
                {
                    type = "slider",
                    name = "Progress danger threshold",
                    tooltip = "Danger if less than this time left to finish the endeavors.",
                    min = 0,
                    max = 86400,
                    step = 600,
                    default = 1800,
                    getFunc = GetterFactory("endeavors", "danger"), setFunc = SetterFactory("endeavors", "danger"),
                },
            },
        },
        ]]--
        {
            name = "Seals",
            controls = {
            },
        },
        {
            name = "Enlightenment",
            controls = {
                {
                    type = "checkbox",
                    name = "Hide when enlighenment empty",
                    default = true,
                    tooltip = "Automatically hide the Enlighenment gadget, when there is no enlightenment to spend.",
                    getFunc = function() return settings.enlightenment.Dynamic end,
                    setFunc = function(newValue)
                        settings.enlightenment.Dynamic = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "slider",
                    name = "Caution threshold",
                    tooltip = "Enlightenment below this number will be colored yellow.",
                    min = -1,
                    max = 400000,
                    step = 1000,
                    default = 50000,
                    getFunc = GetterFactory("enlightenment", "caution"), setFunc = SetterFactory("enlightenment", "caution"),
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "Enlightenment below this number will be colored orange.",
                    min = -1,
                    max = 400000,
                    step = 1000,
                    default = 20000,
                    getFunc = GetterFactory("enlightenment", "warning"), setFunc = SetterFactory("enlightenment", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "Enlightenment below this number will be colored red.",
                    min = -1,
                    max = 400000,
                    step = 1000,
                    default = 10000,
                    getFunc = GetterFactory("enlightenment", "danger"), setFunc = SetterFactory("enlightenment", "danger"),
                },
            },
        },
        {
            name = "ESO Plus Subscription",
            controls = {
                {
                    type = "datepicker",
                    name = "Last subscription purchase",
                    tooltip = "When did your current ESO+ subscription begin?",
                    helpUrl = "https://www.esoui.com/downloads/info2932-LibAddonMenu-DatePickerwidget.html",
                    getFunc = GetterFactory("esoplus", "start"), setFunc = SetterFactory("esoplus", "start", RebuildBar),
                },          
                {
                    type = "checkbox",
                    name = "Hide when still a long time to go (no warnings)",
                    default = true,
                    tooltip = "Automatically hide the ESO Plus Subscription gadget when none of the caution/warning/danger/critical periods is longer than the remaining subscription time.",
                    getFunc = GetterFactory("esoplus", "Dynamic"), setFunc = SetterFactory("esoplus", "Dynamic", RebuildBar),
                },
                {
                    type = "dropdown",
                    name = "Subscription period",
                    tooltip = "How long is your subscription period?",
                    choices = { 30, 60, 90, 180, 365, },
                    helpUrl = "https://www.elderscrollsonline.com/en-gb/esoplus",
                    getFunc = GetterFactory("esoplus", "period"), setFunc = SetterFactory("esoplus", "period", RebuildBar), 
                },                  
                {
                    type = "dropdown",
                    name = "Date format for subscription end",
                    tooltip = "When does your subscription end?",
                    choices = { "YYYY-MM-DD", "DD.MM.YYYY", },
                    choicesValues = { "%Y-%m-%d", "%d.%m.%Y", },
                    -- helpUrl = "https://www.elderscrollsonline.com/en-gb/esoplus",
                    getFunc = GetterFactory("esoplus", "dateformat"), setFunc = SetterFactory("esoplus", "dateformat", RebuildBar), 
                },                  
                {
                    type = "slider",
                    name = "Caution threshold (days)",
                    tooltip = "If your ESO+ subscription expires in this many days, 'caution' color will be used.",
                    min = 1,
                    max = 90,
                    step = 1,
                    default = 7,
                    getFunc = GetterFactory("esoplus", "caution"), setFunc = SetterFactory("esoplus", "caution", RebuildBar),
                },
                {
                    type = "slider",
                    name = "Warning threshold (days)",
                    tooltip = "If your ESO+ subscription expires in this many days, 'warning' color will be used.",
                    min = 1,
                    max = 30,
                    step = 1,
                    default = 5,
                    getFunc = GetterFactory("esoplus", "warning"), setFunc = SetterFactory("esoplus", "warning", RebuildBar),
                },
                {
                    type = "slider",
                    name = "Danger threshold (days)",
                    tooltip = "If your ESO+ subscription expires  in this many days, 'danger' color will be used.",
                    min = 1,
                    max = 30,
                    step = 1,
                    default = 3,
                    getFunc = GetterFactory("esoplus", "danger"), setFunc = SetterFactory("esoplus", "danger", RebuildBar),
                },
                {
                    type = "slider",
                    name = "Critical threshold (days)",
                    tooltip = "If your ESO+ subscription expires  in this many days, 'critical' color will be used.",
                    min = 1,
                    max = 30,
                    step = 1,
                    default = 1,
                    getFunc = GetterFactory("esoplus", "critical"), setFunc = SetterFactory("esoplus", "critical", RebuildBar),
                },
            },
        },
        {
            name = "Experience",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display experience.",
                    default = "% towards next level/CP",
                    choices = {"% towards next level/CP", "% needed for next level/CP", "current XP", "needed XP", "current XP/total needed"},
                    getFunc = GetterFactory("experience", "DisplayPreference"), setFunc = SetterFactory("experience", "DisplayPreference"),
                },
            },
        },
        {
            name = "Fast Travel Timer",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display fast travel timer.",
                    default = "time left/cost",
                    choices = {"time left", "cost", "time left/cost"},
                    getFunc = GetterFactory("ft", "DisplayPreference"), setFunc = SetterFactory("ft", "DisplayPreference"),
                },
                {
                    type = "dropdown",
                    name = "Timer display format",
                    tooltip = "Choose how to display fast travel time left until cheapest.",
                    default = "simple",
                    choices = {"simple", "short", "exact"},
                    getFunc = GetterFactory("ft", "TimerDisplayPreference"), setFunc = SetterFactory("ft", "TimerDisplayPreference"),
                },
                {
                    type = "checkbox",
                    name = "Only show timer after traveling",
                    default = true,
                    tooltip = "Show the icon and timer only after you've fast traveled. When the timer reaches zero, the timer disappears again.",
                    getFunc = function() return settings.ft.Dynamic end,
                    setFunc = function(newValue)
                        settings.ft.Dynamic = newValue
                        RebuildBar()
                    end,
                },
            },
        },
        {
            name = "Food Buff Timer",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display the food buff timer.",
                    default = "simple",
                    choices = {"simple", "short", "exact"},
                    getFunc = GetterFactory("food", "DisplayPreference"), setFunc = SetterFactory("food", "DisplayPreference"),
                },
                {
                    type = "slider",
                    name = "Warning threshold (minutes remaining)",
                    tooltip = "The warning color will be used when the timer falls below what is set here.",
                    min = 0,
                    max = 120,
                    step = 1,
                    default = 15,
                    -- set/display in minutes, but store in seconds
                    getFunc = function() return settings.food.warning / 60 end,
                    setFunc = function(newValue)
                        settings.food.warning = newValue * 60
                    end,
                },
                {
                    type = "slider",
                    name = "Danger threshold (minutes remaining)",
                    tooltip = "The danger color will be used when the timer falls below what is set here.",
                    min = 0,
                    max = 120,
                    step = 1,
                    default = 7,
                    getFunc = function() return settings.food.danger / 60 end,
                    setFunc = function(newValue)
                        settings.food.danger = newValue * 60
                    end,
                },
                {
                    type = "slider",
                    name = "Critical threshold (minutes remaining)",
                    tooltip = "The gadget will pulse when the timer falls below what is set here.",
                    min = 0,
                    max = 120,
                    step = 1,
                    default = 2,
                    getFunc = function() return settings.food.critical / 60 end,
                    setFunc = function(newValue)
                        settings.food.critical = newValue * 60
                    end,
                },
                {
                    type = "checkbox",
                    name = "Keep Pulsing After Expiring",
                    default = true,
                    tooltip = "Allows the gadget to continue pulsing even after the timer has expired.",
                    getFunc = GetterFactory("food", "PulseAfter"), setFunc = SetterFactory("food", "PulseAfter"),
                },
                {
                    type = "checkbox",
                    name = "Only show timer when buff active",
                    default = true,
                    tooltip = "Show the icon and timer only when a food buff is active.",
                    getFunc = function() return settings.food.Dynamic end,
                    setFunc = function(newValue)
                        settings.food.Dynamic = newValue
                        RebuildBar()
                    end,
                  },
            },
        },
        {
            name = "FPS",
            controls = {
                {
                    type = "slider",
                    name = "Caution threshold",
                    tooltip = "FPS below this number will be colored yellow.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 30,
                    getFunc = GetterFactory("fps", "caution"), setFunc = SetterFactory("fps", "caution"),
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "FPS below this number will be colored orange.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 30,
                    getFunc = GetterFactory("fps", "warning"), setFunc = SetterFactory("fps", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "FPS below this number will be colored red.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 15,
                    getFunc = GetterFactory("fps", "danger"), setFunc = SetterFactory("fps", "danger"),
                },
                {
                    type = "checkbox",
                    name = "Use fixed width",
                    default = true,
                    tooltip = "Use fixed width for this gadget.",
                    getFunc = function() return settings.fps.Fixed end,
                    setFunc = function(newValue)
                        settings.fps.Fixed = newValue
                        SetWidth(settings.fps, TEBTopFPS)
                    end,
                },
                {
                    type = "slider",
                    name = "Fixed Width Size",
                    tooltip = "The size in pixels for the gadget.",
                    min = 16,
                    max = 100,
                    step = 1,
                    default = 20,
                    getFunc = function() return settings.fps.FixedLength end,
                    setFunc = function(newValue)
                        settings.fps.FixedLength = newValue
                        SetWidth(settings.fps, TEBTopFPS)
                    end,
                },
            },
        },
        {
            name = "Gold",
            controls = CurrencyControls("gold"),
        },
        {
            name = "Junk",
            controls = {
            },
        },
        {
            name = "Kill Counter",
            controls = {
                {
                    type = "dropdown",
                    name = "Kill Counter display format",
                    tooltip = "Choose how to display the kill counter.",
                    default = "Killing Blows/Deaths (Kill Ratio)",
                    choices = {"Assists/Killing Blows/Deaths (Kill Ratio)", "Assists/Killing Blows/Deaths", "Killing Blows/Deaths (Kill Ratio)", "Killing Blows/Deaths", "Kill Ratio"},
                    getFunc = GetterFactory("kc", "DisplayPreference"), setFunc = SetterFactory("kc", "DisplayPreference"),
                },
            },
        },
        {
            name = "Latency",
            controls = {
                {
                    type = "slider",
                    name = "Caution threshold",
                    tooltip = "Latency above this number will be colored yellow.",
                    min = 0,
                    max = 5000,
                    step = 10,
                    default = 60,
                    getFunc = GetterFactory("latency", "caution"), setFunc = SetterFactory("latency", "caution"),
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "Latency above this number will be colored yellow.",
                    min = 0,
                    max = 5000,
                    step = 10,
                    default = 100,
                    getFunc = GetterFactory("latency", "warning"), setFunc = SetterFactory("latency", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "Latency above this number will be colored red.",
                    min = 0,
                    max = 5000,
                    step = 10,
                    default = 500,
                    getFunc = GetterFactory("latency", "danger"), setFunc = SetterFactory("latency", "danger"),
                },
                {
                    type = "checkbox",
                    name = "Use Fixed Width",
                    default = true,
                    tooltip = "Use fixed width for this gadget.",
                    getFunc = function() return settings.latency.Fixed end,
                    setFunc = function(newValue)
                        settings.latency.Fixed = newValue
                        SetWidth(settings.latency, TEBTopLatency)
                    end,
                },
                {
                    type = "slider",
                    name = "Fixed width size",
                    tooltip = "The size in pixels for the gadget.",
                    min = 20,
                    max = 100,
                    step = 1,
                    default = 30,
                    getFunc = function() return settings.latency.FixedLength end,
                    setFunc = function(newValue)
                        settings.latency.FixedLength = newValue
                        SetWidth(settings.latency, TEBTopLatency)
                    end,
                },
            },
        },
        {
            name = "Leads",
            controls = {
                {
                    type = "slider",
                    name = "Caution threshold (days)",
                    tooltip = "If there are leads expiring in this many days, 'caution' color will be used.",
                    min = 1,
                    max = 30,
                    step = 1,
                    default = 7,
                    getFunc = GetterFactory("leads", "long"), setFunc = SetterFactory("leads", "long"),
                },
                {
                    type = "slider",
                    name = "Warning threshold (days)",
                    tooltip = "If there are leads expiring in this many days, 'warning' color will be used.",
                    min = 1,
                    max = 30,
                    step = 1,
                    default = 3,
                    getFunc = GetterFactory("leads", "medium"), setFunc = SetterFactory("leads", "medium"),
                },
                {
                    type = "slider",
                    name = "Danger threshold (hours)",
                    tooltip = "If there are leads expiring in this many hours, 'danger' color will be used.",
                    min = 1,
                    max = 72,
                    step = 1,
                    default = 24,
                    getFunc = GetterFactory("leads", "short"), setFunc = SetterFactory("leads", "short"),
                },
                {
                    type = "slider",
                    name = "Critical threshold (hours)",
                    tooltip = "If there are leads expiring in this many hours, 'critical' color will be used.",
                    min = 1,
                    max = 72,
                    step = 1,
                    default = 6,
                    getFunc = GetterFactory("leads", "ultrashort"), setFunc = SetterFactory("leads", "ultrashort"),
                },
            },
        },
        {
            name = "Level",
            controls = {

                {
                    type = "description",
                    text = "Display format when |cff0000below|r level 50",
                },
                {
                    type = "dropdown",
                    name = "Icon to use (<L50)",
                    tooltip = "Choose icon to precede level when below level 50.",
                    default = 1,
                    choices = iconChoiceList,
                    choicesValues = iconValueList,
                    getFunc = function() return settings.level.notmax.icon end,
                    setFunc = function(newValue)
                        settings.level.notmax.icon = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "dropdown",
                    name = "Display level (<L50)",
                    tooltip = "Choose how to display the level when below level 50.",
                    default = 1,
                    choices = lvlChoiceList,
                    choicesValues = lvlValueList,
                    getFunc = function() return settings.level.notmax.DisplayPreference end,
                    setFunc = function(newValue)
                        settings.level.notmax.DisplayPreference = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Display Champion Points (<L50)",
                    default = true,
                    tooltip = "Display Champion Points after level when below level 50.",
                    getFunc = function() return settings.level.notmax.cp end,
                    setFunc = function(newValue)
                        settings.level.notmax.cp = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Dynamically show champion points (<L50)",
                    default = true,
                    tooltip = "Show the icon and unspent points only when there is at least one point to spend.",
                    getFunc = function() return settings.level.notmax.Dynamic end,
                    setFunc = function(newValue)
                        settings.level.notmax.Dynamic = newValue
                        RebuildBar()
                    end,
                },

                {
                    type = "description",
                    text = "Display format when |cff0000at|r level 50",
                },
                {
                    type = "dropdown",
                    name = "Icon to use",
                    tooltip = "Choose icon to precede level when at level 50.",
                    default = 1,
                    choices = iconChoiceList,
                    choicesValues = iconValueList,
                    getFunc = function() return settings.level.max.icon end,
                    setFunc = function(newValue)
                        settings.level.max.icon = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "dropdown",
                    name = "Display level",
                    tooltip = "Choose how to display the level when at level 50.",
                    default = 1,
                    choices = lvlChoiceList,
                    choicesValues = lvlValueList,
                    getFunc = function() return settings.level.max.DisplayPreference end,
                    setFunc = function(newValue)
                        settings.level.max.DisplayPreference = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Display Champion Points",
                    default = true,
                    tooltip = "Display Champion Points after level when at level 50.",
                    getFunc = function() return settings.level.max.cp end,
                    setFunc = function(newValue)
                        settings.level.max.cp = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Dynamically show champion points",
                    default = true,
                    tooltip = "Show the icon and unspent points only when there is at least one point to spend.",
                    getFunc = function() return settings.level.max.Dynamic end,
                    setFunc = function(newValue)
                        settings.level.max.Dynamic = newValue
                        RebuildBar()
                    end,
                },
                
                {
                    type = "description",
                    text = "Champion Points to show/ignore",
                },
                {
                    type = "checkbox",
                    width = "half",
                    name = "Crafting (Green) CP",
                    default = true,
                    tooltip = "Show unspent crafting Champion Points",
                    getFunc = function() return settings.level.cp[1] end,
                    setFunc = function(newValue)
                        settings.level.cp[1] = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    width = "half",
                    name = "Warfare (Blue) CP",
                    default = true,
                    tooltip = "Show unspent warfare Champion Points",
                    getFunc = function() return settings.level.cp[2] end,
                    setFunc = function(newValue)
                        settings.level.cp[2] = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    width = "half",
                    name = "Fitness (Red) CP",
                    default = true,
                    tooltip = "Show unspent fitness Champion Points",
                    getFunc = function() return settings.level.cp[3] end,
                    setFunc = function(newValue)
                        settings.level.cp[3] = newValue
                        RebuildBar()
                    end,
                },              
            },
        },
        {
            name = "Location",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display your location.",
                    default = "(x, y) Zone Name",
                    choices = {"(x, y) Zone Name", "Zone Name (x, y)", "Zone Name", "x, y"},
                    getFunc = GetterFactory("location", "DisplayPreference"), setFunc = SetterFactory("location", "DisplayPreference"),
                },
            },
        },
        {
            name = "Lock/Unlock Bar/Gadgets",
            controls = {
            },
        },
        {
            name = "Memory Usage",
            controls = {
                {
                    type = "slider",
                    name = "Caution threshold",
                    tooltip = "Memory Usage above this number will be colored yellow.",
                    min = 0,
                    max = 1024,
                    step = 8,
                    default = 256,
                    getFunc = GetterFactory("memory", "caution"), setFunc = SetterFactory("memory", "caution"),
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "Memory Usage above this number will be colored yellow.",
                    min = 0,
                    max = 1024,
                    step = 8,
                    default = 512,
                    getFunc = GetterFactory("memory", "warning"), setFunc = SetterFactory("memory", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "Memory usage above this number will be colored red.",
                    min = 0,
                    max = 1024,
                    step = 8,
                    default = 768,
                    getFunc = GetterFactory("memory", "danger"), setFunc = SetterFactory("memory", "danger"),
                },
            },
        },
        {
            name = "Mount Timer",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display the mount timer.",
                    default = "simple",
                    choices = {"simple", "short", "exact"},
                    getFunc = GetterFactory("mount", "DisplayPreference"), setFunc = SetterFactory("mount", "DisplayPreference"),
                },
                {
                    type = "dropdown",
                    name = "Show this gadget",
                    choices = { "always", "only when training", "only when not training", "only when not maxed", "when not all tracked characters maxed" },
                    choicesValues = { "always", "running", "free", "maxed", "allmaxed" },
                    default = "always",
                    tooltip = "When to show the icon and timer.",
                    getFunc = function() return settings.mount.Dynamic end,
                    setFunc = function(newValue)
                        settings.mount.Dynamic = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Indicate when the timer has reached zero",
                    default = true,
                    tooltip = "When the timer has reached zero, turn the gadget green.",
                    getFunc = GetterFactory("mount", "good"), setFunc = SetterFactory("mount", "good"),
                },
                {
                    type = "checkbox",
                    name = "Pulse gadget",
                    default = true,
                    tooltip = "Pulse the gadget when it is time to train your mount.",
                    getFunc = GetterFactory("mount", "critical"), setFunc = SetterFactory("mount", "critical"),
                },
                {
                    type = "checkbox",
                    name = "Track this character",
                    tooltip = "Track this character's mount training time left.",
                    default = true,
                    disabled = DisableMountTracker,
                    getFunc = GetCharacterMountTracked,
                    setFunc = SetCharacterMountTracked,
                },
            },
        },
        {
            name = "Mundus Stone",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display your Mundus",
                    default = "Full",
                    choices = {"Abbreviated", "Full"},
                    getFunc = GetterFactory("mundus", "DisplayPreference"), setFunc = SetterFactory("mundus", "DisplayPreference"),
                },

            },
        },
        {
            name = "Research Timers",
            controls = {
                {
                    type = "checkbox",
                    name = "Display Text",
                    default = true,
                    tooltip = "Display text for these gadgets.",
                    getFunc = function() return settings.gadgetTextEnabled.blacksmithing end,
                    setFunc = function(newValue)
                        settings.gadgetTextEnabled.blacksmithing = newValue
                        settings.gadgetTextEnabled.clothing = newValue
                        settings.gadgetTextEnabled.woodworking = newValue
                        settings.gadgetTextEnabled.jewelry = newValue
                    end,
                },
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display research timers.",
                    default = "simple",
                    choices = {"simple", "short", "exact"},
                    getFunc = GetterFactory("research", "DisplayPreference"), setFunc = SetterFactory("research", "DisplayPreference"),
                },
                {
                    type = "dropdown",
                    name = "Show this gadget",
                    default = "always",
                    choices = { "always", "only when there are free slots", "only when researching" },
                    choicesValues = { "always", "free", "running" },
                    tooltip = "When to show this gadget.",
                    getFunc = function() return settings.research.Dynamic end,
                    setFunc = function(newValue)
                        settings.research.Dynamic = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Only show the shortest timer",
                    default = false,
                    tooltip = "When researching multiple items, only show the timer that has the least amount of time left.",
                    getFunc = function() return settings.research.ShortestOnly end,
                    setFunc = function(newValue)
                        settings.research.ShortestOnly = newValue
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show free slots",
                    default = true,
                    tooltip = "Show the number of free slots available for research.",
                    getFunc = GetterFactory("research", "DisplayAllSlots"), setFunc = SetterFactory("research", "DisplayAllSlots"),
                },
                {
                    type = "dropdown",
                    name = "Display free slots as",
                    tooltip = "Choose how to display free research slots.",
                    default = "--",
                    choices = {"--", "-", "free", "0", "done"},
                    getFunc = GetterFactory("research", "FreeText"), setFunc = SetterFactory("research", "FreeText"),
                },
            },
        },
        {
            name = "Sky Shards",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display sky shard count.",
                    default = "collected/unspent points",
                    choices = {"collected/unspent points", "collected/total needed (unspent points)", "needed/unspent points", "collected", "needed"},
                    getFunc = GetterFactory("skyshards", "DisplayPreference"), setFunc = SetterFactory("skyshards", "DisplayPreference"),
                },
            },
        },
        {
            name = "Soul Gems",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display soul gem count.\ntotal filled = normal (non-crown) filled soul gems + crown soul gems\nnormal filled = normal (non-crown) filled soul gems\ncrown = crown soul gems\nempty = empty soul gems",
                    default = "total filled/empty",
                    choices = {"total filled/empty", "total filled (empty)", "total filled (crown)/empty", "normal filled/crown/empty", "total filled", "normal filled"},
                    getFunc = function() return settings.soulgems.DisplayPreference end,
                    setFunc = function(newValue)
                        settings.soulgems.DisplayPreference = newValue
                        CalculateBagItems()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Color soul gems",
                    default = true,
                    tooltip = "Appriopriately color each kind of soul gems in tooltips",
                    getFunc = GetterFactory("soulgems", "Color"), setFunc = SetterFactory("soulgems", "Color"),
                },
            },
        },
        {
            name = "Tel Var Stones",
            controls = CurrencyControls("telvar"),
        },
        {
            name = "Thief's Tools",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display the thief's tools.",
                    default = "stolen treasures/stolen goods (lockpicks)",
                    choices = {"lockpicks", "total stolen", "total stolen (lockpicks)", "stolen treasures/stolen goods", "stolen treasures/stolen goods (lockpicks)", "stolen treasures/fence_remaining stolen goods/launder_remaining", "stolen treasures/fence_remaining stolen goods/launder_remaining (lockpicks)", "stolen treasures/stolen goods fence_remaining/launder_remaining", "stolen treasures/stolen goods fence_remaining/launder_remaining (lockpicks)"},
                    getFunc = function() return settings.tt.DisplayPreference end,
                    setFunc = function(newValue)
                        settings.tt.DisplayPreference = newValue
                        CalculateBagItems()
                    end,
                },
                {
                    type = "slider",
                    name = "Interactions caution threshold",
                    tooltip = "Fence and launder interactions below this number will be colored yellow.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 25,
                    getFunc = function() return settings.tt.caution end,
                    setFunc = function(newValue)
                        settings.tt.caution = newValue
                        CalculateBagItems()
                    end,
                },
                {
                    type = "slider",
                    name = "Interactions warning threshold",
                    tooltip = "Fence and launder interactions below this number will be colored yellow.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 25,
                    getFunc = function() return settings.tt.warning end,
                    setFunc = function(newValue)
                        settings.tt.warning = newValue
                        CalculateBagItems()
                    end,
                },
                {
                    type = "slider",
                    name = "Interactions danger threshold",
                    tooltip = "Fence and launder interactions below this number will be colored red.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 10,
                    getFunc = function() return settings.tt.danger end,
                    setFunc = function(newValue)
                        settings.tt.danger = newValue
                        CalculateBagItems()
                    end,
                },
            },
        },
        {
            name = "Trade Bars",
            controls = {
            },
        },
        {
            name = "Transmute Crystals",
            controls = {
                {
                    type = "slider",
                    name = "Caution threshold",
                    tooltip = "The caution color will be used when the number of transmute crystals is equal to or higher than what is set here.",
                    min = 0,
                    max = 3000,
                    step = 1,
                    default = 2800,
                    getFunc = GetterFactory("transmute", "caution"), setFunc = SetterFactory("transmute", "caution"),
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "The warning color will be used when the number of transmute crystals is equal to or higher than what is set here.",
                    min = 0,
                    max = 3000,
                    step = 1,
                    default = 2900,
                    getFunc = GetterFactory("transmute", "warning"), setFunc = SetterFactory("transmute", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "The danger color will be used when the number of transmute crystals is equal to or higher than what is set here.",
                    min = 0,
                    max = 3000,
                    step = 1,
                    default = 2950,
                    getFunc = GetterFactory("transmute", "danger"), setFunc = SetterFactory("transmute", "danger"),
                },

            },
        },
        {
            name = "Tome Points",
            controls = {
            },
        },
        {
            name = "Tome Tokens",
            controls = {
            },
        },
        {
            name = "Undaunted Keys",
            controls = {
            },
        },
        {
            name = "Unread Mail",
            controls =
            {
                {
                    type = "checkbox",
                    name = "Automatically hide when no unread mail",
                    default = true,
                    tooltip = "Hide the gadget only when there in no unread mail.",
                    getFunc = function() return settings.mail.Dynamic end,
                    setFunc = function(newValue)
                        settings.mail.Dynamic = newValue
                        mail()
                        RebuildBar()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Indicate when there is unread mail",
                    default = true,
                    tooltip = "When there is unread mail, turn the gadget green.",
                    getFunc = GetterFactory("mail", "good"), setFunc = SetterFactory("mail", "good", mail),
                },
                {
                    type = "checkbox",
                    name = "Pulse gadget",
                    default = true,
                    tooltip = "Pulse the gadget when there is unread mail.",
                    getFunc = GetterFactory("mail", "pulse"), setFunc = SetterFactory("mail", "pulse", mail),
                },
            },
        },
        {
            name = "Vampirism",
            controls = {
                {
                    type = "dropdown",
                    name = "Display format",
                    tooltip = "Choose how to display the vampirism gadget information.",
                    default = "Stage (Timer)",
                    choices = {"Stage (Timer)", "Timer"},
                    getFunc = GetterFactory("vampirism", "DisplayPreference"), setFunc = SetterFactory("vampirism", "DisplayPreference"),
                },
                {
                    type = "dropdown",
                    name = "Timer Display format",
                    tooltip = "Choose how to display the vampirism stage timer.",
                    default = "simple",
                    choices = {"simple", "short", "exact"},
                    getFunc = GetterFactory("vampirism", "TimerPreference"), setFunc = SetterFactory("vampirism", "TimerPreference"),
                },
            },
        },
        {
            name = "Weapon Charge/Poison",
            controls = {
                {
                    type = "checkbox",
                    name = "Display poison count when poison is applied",
                    default = true,
                    tooltip = "Replace weapon charge display with poison count whenever poison is applied to a weapon.",
                    getFunc = GetterFactory("wc", "AutoPoison"), setFunc = SetterFactory("wc", "AutoPoison"),
                },
                {
                        type = "description",
                        text = "|c2A8FEEWeapon Charge Thresholds:",
                        width = "full"
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "Weapon charge below this number will be colored yellow.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 50,
                    getFunc = GetterFactory("wc", "warning"), setFunc = SetterFactory("wc", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "Weapon charge below this number will be colored red.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 25,
                    getFunc = GetterFactory("wc", "danger"), setFunc = SetterFactory("wc", "danger"),
                },
                {
                    type = "slider",
                    name = "Critical threshold (pulse)",
                    tooltip = "Weapon charge below this number will cause the gadget to pulse.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 10,
                    getFunc = GetterFactory("wc", "critical"), setFunc = SetterFactory("wc", "critical"),
                },
                {
                        type = "description",
                        text = "|c2A8FEEPoison Count Thresholds:",
                        width = "full"
                },
                {
                    type = "slider",
                    name = "Warning threshold",
                    tooltip = "Poison Count below this number will be colored yellow.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 20,
                    getFunc = GetterFactory("poison", "warning"), setFunc = SetterFactory("poison", "warning"),
                },
                {
                    type = "slider",
                    name = "Danger threshold",
                    tooltip = "Poison Count below this number will be colored red.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 10,
                    getFunc = GetterFactory("poison", "danger"), setFunc = SetterFactory("poison", "danger"),
                },
                {
                    type = "slider",
                    name = "Critical threshold (pulse)",
                    tooltip = "Poison Count below this number will cause the gadget to pulse.",
                    min = 0,
                    max = 100,
                    step = 1,
                    default = 5,
                    getFunc = GetterFactory("poison", "critical"), setFunc = SetterFactory("poison", "critical"),
                },
            },
        },
        {
            name = "Writ Vouchers",
            controls = CurrencyControls("writs"),
        },
    }

    -- LibAddonMenuDatePicker is an OPTIONAL dependency, but necessary for the "ESO Plus Subscription" gadget
    if LAMCreateControl.datepicker == nil then
        for i, c in ipairs(controlStructure) do
            if c.key == "esoplus" then
                table.remove(controlStructure, i)
                break
            end
        end
        for i, c in ipairs(GadgetVisibilityControls) do
            if c.key == "esoplus" then
                table.remove(GadgetVisibilityControls, i)
                break
            end
        end
    end
    
    -- LibSetDetection and LibSets are OPTIONAL dependencies, but necessary for the "Currently Equipped" gadget
    if not (LSD and LS) then
        for i, c in ipairs(GadgetVisibilityControls) do
            if c.key == "equipped" then
                table.remove(GadgetVisibilityControls, i)
                break
            end
        end
    end
    
    for i = 6, #controlStructure do -- 6 is first gadget submenu (Alliance Points)
        local c = controlStructure[i]
        local name = c.name
        local key = G.nameReference[name]
        c.type = "submenu"
        if name ~= "Research Timers" then
            table.insert(c.controls, 1, {
                type = "checkbox",
                name = "Display Text",
                default = true,
                tooltip = "Display text for this gadget.",
                getFunc = function() return settings.gadgetTextEnabled[key] end,
                setFunc = function(newValue) settings.gadgetTextEnabled[key] = newValue end,
            })
        end
        if name == "Alliance Points" then
            c.controls[2] = {
                type = "dropdown",
                name = "Display format",
                tooltip = "Choose how to display alliance points.",
                default = "Total Points",
                choices = {"Total Points", "Session Points", "Points Per Hour", "Total Points/Points Per Hour", "Session Points/Points Per Hour", "Total Points/Session Points", "Total Points/Session Points (Points Per Hour)", "Total Points/Session Points/Points Per Hour"},
                getFunc = GetterFactory("ap", "DisplayPreference"),
                setFunc = SetterFactory("ap", "DisplayPreference"),
            }
        end
    end

    local panelControl = LAM2:RegisterAddonPanel("TEB_ASUGB", panelData)
    LAM2:RegisterOptionControls("TEB_ASUGB", controlStructure)
end

local function SetEquipmentDirty()
    G.equipped_dirty = true 
end

local function FinishInitialization(eventCode)
    zo_callLater(SetEquipmentDirty, GetLatency() + 3000) -- at every EVENT_PLAYER_ACTIVATED
    -- the rest needs to be done at first player activation only
    if G.addonInitialized then return end

    -- fill G.colors with ZO_ColorDef objects
    FillColors(settings.colors)
    -- add colors for CP constellations, soul gems
    FillColors({ craft = "51AB0D", warfare = "1970C9", fitness = "D6660C",
        crownSoulGem = "ffdf00", normalSoulGem = "bb00ff", emptySoulGem = "8800ff",
    })

    for k, v in pairs(non_global_currencies) do
        settings.Trackers[k] = settings.Trackers[k] or { false, 0}
    end

    G.ap.SessionStart = os.time()
    G.ap.SessionStartPoints = GetCurrencyAmount(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_CHARACTER)
    settings.enlightenment.critical = nil -- remove critical from settings

    CreateSettingsWindow()
    table.insert(TEB.debug, "CreateSettingsWindow done\n")

    SetWidth(settings.latency, TEBTopLatency)
    SetWidth(settings.fps, TEBTopFPS)
    TEBTop:ClearAnchors()
    TEBTop:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, settings.bar.Y)
    SetBarLayer()
    RefreshBar(true)
    LockUnlockBar(settings.bar.Locked)
    LockUnlockGadgets(settings.bar.gadgetsLocked)
    ConvertGadgetVisibility()
    SetOpacity()
    SetPulse()
    SetBarPosition()
    SetBarWidth(settings.bar.Width)
    RebuildBar()
    ResizeBar()
    AddToMountDatabase(G.characterName)
    TEBTop:SetHidden(false)
    if settings.bar.chatMessagesOn then
        df("%s v. %s initialized for %s.", TEB.displayName, TEB.version, GetUnitName("player"))
    end
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", SceneChange)
    -- force rebuild for new player
    G.addonInitialized = true
end

-- it all begins here…
local function OnAddOnLoaded(event, addOnName)
    if addOnName ~= TEB.name or G.addonInitialized then return end
    table.insert(TEB.debug, "OnAddOnLoaded\n")

    local events = {
        [EVENT_PLAYER_ACTIVATED] = FinishInitialization,
        --[[
        [EVENT_OPEN_BANK] = HideBarFactory("Bank"),
        [EVENT_CLOSE_BANK] = ShowBar,
        [EVENT_CHATTER_BEGIN] = HideBarFactory("Chatter"),
        [EVENT_CHATTER_END] = ShowBar,
        [EVENT_CRAFTING_STATION_INTERACT] = HideBarFactory("Crafting"),
        [EVENT_END_CRAFTING_STATION_INTERACT] = ShowBar,
        [EVENT_OPEN_GUILD_BANK] = HideBarFactory("GuildBank"),
        [EVENT_CLOSE_GUILD_BANK] = ShowBar,
        ]]--
        [EVENT_INVENTORY_SINGLE_SLOT_UPDATE] = CalculateBagItems,
        [EVENT_JUSTICE_STOLEN_ITEMS_REMOVED] = CalculateBagItems,
        [EVENT_COMBAT_EVENT] = UpdateKillingBlows,
        [EVENT_PLAYER_DEAD] = UpdateDeaths,
        [EVENT_ANTIQUITY_LEAD_ACQUIRED] = UpdateLeadCount,
        [EVENT_ANTIQUITY_UPDATED] = UpdateLeadCount,
        [EVENT_INVENTORY_SINGLE_SLOT_UPDATE] = function() zo_callLater(SetEquipmentDirty, GetLatency() + 1000) end,
        [EVENT_ARMORY_BUILD_RESTORE_RESPONSE] = function() zo_callLater(SetEquipmentDirty, GetLatency() + 4000) end,
    }

    for k, f in pairs(events) do
        EVENT_MANAGER:RegisterForEvent(TEB.name, k, f)
    end
    
    EVENT_MANAGER:AddFilterForEvent(TEB.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW)
    -- Filters keep event from firing twice on gear swap or on non-gear inv change
    for k, v in pairs({
        [REGISTER_FILTER_BAG_ID] = BAG_WORN,
        [REGISTER_FILTER_IS_NEW_ITEM] = false,
        [REGISTER_FILTER_INVENTORY_UPDATE_REASON] = INVENTORY_UPDATE_REASON_DEFAULT,
    }) do
        EVENT_MANAGER:AddFilterForEvent(TEB.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, k, v)
    end
    
    ZO_CreateStringId("SI_BINDING_NAME_RUN_TEB", GetString(SI_CWA_KEY_BINDING))
    ZO_CreateStringId("SI_BINDING_NAME_LOCK_UNLOCK_BAR", "Lock/Unlock Bar")
    ZO_CreateStringId("SI_BINDING_NAME_LOCK_UNLOCK_GADGETS", "Lock/Unlock Gadgets")

    TEBTop:SetWidth(G.screenWidth)
    TEBTop:SetHidden(true)
    TEBTooltip:SetHidden(true)

    -- those will not change during the session…
    G.account = GetDisplayName("player")
    G.characterName = GetUnitName("player")
    G.playerClass = GetUnitClassId("player")
    -- saved data for SetBarPosition
    G.original = {
        TargetUnitFrameTop = ZO_TargetUnitFramereticleover:GetTop(),
        CompassTop = ZO_CompassFrame:GetTop(),
        ActionBarTop = ZO_ActionBar1:GetTop(),
        HealthTop = ZO_PlayerAttributeHealth:GetTop(),
        MagickaTop = ZO_PlayerAttributeMagicka:GetTop(),
        StaminaTop = ZO_PlayerAttributeStamina:GetTop(),
        MountStaminaTop = ZO_PlayerAttributeMountStamina:GetTop(),
        BountyTop = ZO_HUDInfamyMeter:GetTop(),
    }
    --[[
    gadgetReference - master table for gadgets
    Key: same as in table G and settings
    1. label     = Label object name (string)
    2. name      = descriptive name of a gadget
    3. icon      = Icon Object (object) - filled below
    4. text      = Text Object (object) - filled below
    5. texture   = Current Icon Texture Filename (string) - filled later
    6. pulsing   = Gadget Is Pulsing
    ]]--
    G.totalGadgets = 0
    for key, r in pairs(gadgetReference) do
        local gadgetName = r.name
        local label = string.len(gadgetName) > 3 and ucfirst(gadgetName) or string.upper(gadgetName)
        local labelObjName = string.format("TEBTop%s", label)
        local iconName = string.format("%sIcon", labelObjName)
        local currency = global_currencies[key] or non_global_currencies[key]
        -- map icon name to gadget key
        G.iconReference[iconName] = key
        -- and descriptive name to key
        G.nameReference[gadgetName] = key
        -- prepare to fill G.key.Info later
        G[key] = { Info = "", Left = "", Right = ""}
        if currency then
            G[key].inBank = 0
        end
        -- create controls
            
        local text = WINDOW_MANAGER:CreateControl(labelObjName, TEBTop, CT_LABEL)
        local icon
        if key == "lock" then
            -- "lock" gadget is a special case
            icon = WINDOW_MANAGER:CreateControl(iconName, TEBTop, CT_BUTTON)
            icon:SetNormalTexture(string.format("TEB/Images/%s_white.dds", key))
            icon:SetHandler("OnClicked", ToggleLock)
        else
            icon = WINDOW_MANAGER:CreateControl(iconName, TEBTop, CT_TEXTURE)
            if currency then
                icon:SetTexture(ZO_Currency_GetPlatformCurrencyIcon(currency))
            else
                icon:SetTexture(string.format("TEB/Images/%s_white.dds", key))
            end
        end
        r.text, r.icon = text, icon
        text:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        text:SetMaxLineCount(1)
        icon:SetParent(TEBTop)
        icon:SetDimensions(22, 22)
        --icon:SetText(string.format("|t:18:18:TEB/Images/%s_white.dds|t", key))
        icon:SetMouseEnabled(true)
        icon:SetHandler("OnMouseEnter", function() ShowToolTip(key) end)
        icon:SetHandler("OnMouseExit", HideTooltip)
        icon:SetHandler("OnMoveStart", StartMovingGadget)
        icon:SetHandler("OnMoveStop", StopMovingGadget)
        icon:SetDrawTier(DT_HIGH)
        icon:SetDrawLayer(DL_CONTROLS)
        icon:SetDrawLevel(1)
        -- default: all gadgets have text on
        defaults.gadgetTextEnabled[key] = true
        G.totalGadgets = G.totalGadgets + 1
    end
    -- sentinels
    WINDOW_MANAGER:CreateControl("TEBTopStartingAnchor", TEBTop, CT_BUTTON)
    WINDOW_MANAGER:CreateControl("TEBTopEndingAnchor", TEBTop, CT_BUTTON)
    table.insert(TEB.debug, string.format("G.totalGadgets = %d\n", G.totalGadgets))
    for k, _ in pairs(crafts) do
        G[k].freeSlots = 0
    end
    -- read in settings from SavedVariables
    local sv_name = TEB.name .. "SavedVariables"
    settings = LSV:NewAccountWide(sv_name, "Account", defaults)
        :MigrateFromAccountWide( { name = sv_name } )
        -- changing settings structure:
        :Version(13, Upgrade_from_12)
        -- :EnableDefaultsTrimming()
    TEB.settings = settings -- to simplify debugging
    settings.addonVersion = TEB.version
    table.insert(TEB.debug, "LSV done\n")
end -- OnAddOnLoaded

-- called from XML
TEB.OnUpdate = OnUpdate
TEB.StopMovingBar = StopMovingBar

-- call initialization when addon loaded
EVENT_MANAGER:RegisterForEvent(TEB.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
table.insert(TEB.debug, "Main code finished\n")

-- THE END
-- vi: tabstop=4: shiftwidth=4: softtabstop=4: expandtab: fileencoding=utf-8: mouse=:
