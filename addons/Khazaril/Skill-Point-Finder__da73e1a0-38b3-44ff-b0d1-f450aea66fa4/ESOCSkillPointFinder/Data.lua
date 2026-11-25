-- Skill Point Finder: the few facts the game can't tell an add-on.
-- Source: UESP, "Earning Skill Points", checked 25 November 2026.

ESOC_SkillPointFinder = ESOC_SkillPointFinder or {}
local SP = ESOC_SkillPointFinder
local Data = {}
SP.Data = Data

-- Skill points from each zone's storyline, by lower-case zone name. The game can show how far
-- through a zone's story you are, but not which story quests give the points, so these are "up to".
Data.STORY_POINTS = {
    -- Daggerfall Covenant (Glenumbra has one extra)
    ["glenumbra"] = 4, ["stormhaven"] = 3, ["rivenspire"] = 3, ["alik'r desert"] = 3, ["bangkorai"] = 3,
    -- Ebonheart Pact
    ["stonefalls"] = 3, ["deshaan"] = 3, ["shadowfen"] = 3, ["eastmarch"] = 3, ["the rift"] = 3,
    -- Aldmeri Dominion
    ["auridon"] = 3, ["grahtwood"] = 3, ["greenshade"] = 3, ["malabal tor"] = 3, ["reaper's march"] = 3,
    ["coldharbour"] = 3,
    -- DLCs and chapters
    ["imperial city"] = 1,
    ["wrothgar"] = 3,
    ["hew's bane"] = 6,          -- Thieves Guild
    ["gold coast"] = 8,          -- Dark Brotherhood
    ["vvardenfell"] = 3,
    ["clockwork city"] = 8,
    ["summerset"] = 3,
    ["murkmire"] = 7,
    ["northern elsweyr"] = 3,
    ["southern elsweyr"] = 6,    -- Dragonhold
    ["western skyrim"] = 3,      -- Greymoor
    ["the reach"] = 6,           -- Markarth
    ["blackwood"] = 2,
    ["the deadlands"] = 6,
    ["high isle"] = 3,
    ["galen"] = 6,
    ["telvanni peninsula"] = 9,  -- Necrom (the whole storyline, including Apocrypha)
    ["west weald"] = 5,
    ["solstice"] = 9,            -- Western Solstice 3 + Eastern Solstice 6
}

-- Quest points the add-on doesn't track yet, shown on the Overview as a reminder.
Data.NOT_TRACKED = {
    "Main quest: 11",
    "Mages Guild book (Folium Discognitum): 2",
    "Chapter epilogues: 3 each (Season of the Dragon, Dark Heart of Skyrim, Gates of Oblivion, Legacy of the Bretons, Secrets of Apocrypha)",
    "Alliance War ranks: up to 50",
    "Maelstrom Arena: 1 · Scribing quests: 1 · High Isle public dungeon quests: 2",
}

-- Zones that came with the base game. Everything else counts as DLC (group events there are harder).
Data.BASE_ZONES = {
    ["glenumbra"] = true, ["stormhaven"] = true, ["rivenspire"] = true, ["alik'r desert"] = true, ["bangkorai"] = true,
    ["stonefalls"] = true, ["deshaan"] = true, ["shadowfen"] = true, ["eastmarch"] = true, ["the rift"] = true,
    ["auridon"] = true, ["grahtwood"] = true, ["greenshade"] = true, ["malabal tor"] = true, ["reaper's march"] = true,
    ["coldharbour"] = true, ["craglorn"] = true, ["cyrodiil"] = true,
    ["stros m'kai"] = true, ["betnikh"] = true, ["bleakrock isle"] = true, ["bal foyen"] = true, ["khenarthi's roost"] = true,
}

-- PvP zones: skyshards here are risky, so they go last and can be hidden.
Data.PVP_ZONES = { ["cyrodiil"] = true, ["imperial city"] = true, ["imperial sewers"] = true }

-- Zones whose skyshards are mostly inside group delves: soloable for a decent player, but tougher than normal delves.
Data.GROUP_SHARD_ZONES = { ["craglorn"] = true }

-- DLC public dungeon group events known to be tougher than usual (lower-case public dungeon name).
-- Empty for now: add names as they turn out to be hard.
Data.HARD_GROUP_EVENTS = {}

Data.EASE_NAMES = { [5] = "Very easy", [4] = "Easy", [3] = "Medium", [2] = "Harder", [1] = "Hard" }

-- Each group dungeon's story quest (the one that gives the skill point), by dungeon name.
-- Source: UESP "Undaunted" page, checked against UESP's list of skill point quests, 25 November 2026.
Data.DUNGEON_QUESTS = {
    ["banished cells i"] = "Banishing the Banished",
    ["banished cells ii"] = "The Plan",
    ["city of ash i"] = "Razor's Edge",
    ["city of ash ii"] = "Return to Ash",
    ["elden hollow i"] = "Ancient Remains",
    ["elden hollow ii"] = "Consuming Darkness",
    ["selene's web"] = "Knowledge Gained",
    ["tempest island"] = "Eye of the Storm",
    ["blackheart haven"] = "Jumping Ship",
    ["crypt of hearts i"] = "Lover's Torment",
    ["crypt of hearts ii"] = "Edge of Darkness",
    ["spindleclutch i"] = "Deadly Whispers",
    ["spindleclutch ii"] = "Blood Relations",
    ["volenfell"] = "Blood and Sand",
    ["wayrest sewers i"] = "Deception in the Dark",
    ["wayrest sewers ii"] = "No Second Chances",
    ["arx corinium"] = "Force of Nature",
    ["blessed crucible"] = "Fires of Battle",
    ["darkshade caverns i"] = "Mine All Mine",
    ["darkshade caverns ii"] = "What Was Lost",
    ["direfrost keep"] = "Nobles' Rest",
    ["fungal grotto i"] = "Kings of the Grotto",
    ["fungal grotto ii"] = "Lighting the Shadows",
    ["vaults of madness"] = "Mind of Madness",
    ["imperial city prison"] = "Summary Execution",
    ["white-gold tower"] = "Planemeld Obverse",
    ["cradle of shadows"] = "Silk and Shadow",
    ["ruins of mazzatun"] = "Sap and Stone",
    ["bloodroot forge"] = "Blood for Blood",
    ["falkreath hold"] = "Falkreath's Demise",
    ["fang lair"] = "Casting the Bones",
    ["scalecaller peak"] = "Plans of Pestilence",
    ["march of sacrifices"] = "The Great Hunt",
    ["moon hunter keep"] = "Moonlight Ascent",
    ["depths of malatar"] = "The Guiding Light",
    ["frostvault"] = "Lock and Keystone",
    ["moongrave fane"] = "The Sanguine Successor",
    ["lair of maarselok"] = "The Azure Blight",
    ["icereach"] = "The Frozen Isle",
    ["unhallowed grave"] = "Unhallowed Grave",
    ["castle thorn"] = "Blood of the Past",
    ["stone garden"] = "Method and Madness",
    ["black drake villa"] = "Burning Secrets",
    ["cauldron"] = "Into the Deep",
    ["red petal bastion"] = "A Rose of Many Thorns",
    ["dread cellar"] = "Quaking Dread",
    ["coral aerie"] = "An Order Gone Awry",
    ["shipwright's regret"] = "Wright of Passage",
    ["earthen root enclave"] = "The Stonelore Defense",
    ["graven deep"] = "Haunted Depths",
    ["bal sunnar"] = "Unstuck From Time",
    ["scrivener's hall"] = "A War of Scribes",
    ["oathsworn pit"] = "Victory Through Strife",
    ["bedlam veil"] = "The Forgotten Vault",
    ["lep seclusa"] = "Upstart Emperor",
    ["exiled redoubt"] = "Undying Requiem",
    ["black gem foundry"] = "Deadly Armaments",
    ["naj-caldeesh"] = "Unearthed and Unexplored",
}
