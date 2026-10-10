-- SetHunter_Data.lua : hand-written farming knowledge the game API doesn't expose.
-- Which sets drop in which zone comes from LibItemSets (bundled with Item Set Browser);
-- this file adds the details on top: which boss drops each monster helm, solo notes,
-- arena group sizes, and the whole XP farming guide.
--
-- Location and zone names are the English in-game names; they are matched to the
-- game's zones by name, so keep the spelling exact. Sources: UESP (monster sets,
-- XP bonuses), ArzyeL Builds (grind spots), Update 51 patch notes.

SetHunter = SetHunter or {}
local S = SetHunter
S.DATA = {}
local D = S.DATA

-- ---------------------------------------------------------------------------
-- Monster sets: head guaranteed from this boss on Veteran; shoulders from
-- Undaunted keys. dlc = the dungeon is DLC content (set also in the Crown Store).
-- ---------------------------------------------------------------------------
D.MONSTER_SETS = {
    { set = "Anthelmir's Construct", loc = "Oathsworn Pit",         boss = "Anthelmir's Construct",         dlc = true },
    { set = "Archdruid Devyric",     loc = "Earthen Root Enclave",  boss = "Archdruid Devyric",             dlc = true },
    { set = "Balorgh",               loc = "March of Sacrifices",   boss = "Balorgh",                       dlc = true },
    { set = "Bar-Sakka",             loc = "Naj-Caldeesh",          boss = "Talen-Lah and Bar-Sakka",       dlc = true },
    { set = "Baron Zaudrus",         loc = "The Cauldron",          boss = "Baron Zaudrus",                 dlc = true },
    { set = "Black Gem Monstrosity", loc = "Black Gem Foundry",     boss = "High Soulbinder Vykand",        dlc = true },
    { set = "The Blind",             loc = "Bedlam Veil",           boss = "The Blind",                     dlc = true },
    { set = "Bloodspawn",            loc = "Spindleclutch II",      boss = "Vorenor Winterbourne" },
    { set = "Chokethorn",            loc = "Elden Hollow I",        boss = "Canonreeve Oraneth" },
    { set = "Domihaus",              loc = "Falkreath Hold",        boss = "Domihaus the Bloody-Horned",    dlc = true },
    { set = "Earthgore",             loc = "Bloodroot Forge",       boss = "Earthgore Amalgam",             dlc = true },
    { set = "Encratis's Behemoth",   loc = "Black Drake Villa",     boss = "Pyroturge Encratis",            dlc = true },
    { set = "Engine Guardian",       loc = "Darkshade Caverns II",  boss = "The Engine Guardian" },
    { set = "Euphotic Gatekeeper",   loc = "Graven Deep",           boss = "The Euphotic Gatekeeper",       dlc = true },
    { set = "Grothdarr",             loc = "Vaults of Madness",     boss = "The Mad Architect" },
    { set = "Grundwulf",             loc = "Moongrave Fane",        boss = "Grundwulf",                     dlc = true },
    { set = "Iceheart",              loc = "Direfrost Keep",        boss = "Drodda of Icereach" },
    { set = "Ilambris",              loc = "Crypt of Hearts I",     boss = "Ilambris-Athor and Ilambris-Zaven" },
    { set = "Infernal Guardian",     loc = "City of Ash I",         boss = "Razor Master Erthas" },
    { set = "Kargaeda",              loc = "Coral Aerie",           boss = "Varallion",                     dlc = true },
    { set = "Kjalnar's Nightmare",   loc = "Unhallowed Grave",      boss = "Kjalnar Tombskald",             dlc = true },
    { set = "Kra'gh",                loc = "Fungal Grotto I",       boss = "Kra'gh the Dreugh King" },
    { set = "Lady Thorn",            loc = "Castle Thorn",          boss = "Lady Thorn",                    dlc = true },
    { set = "Lord Warden",           loc = "Imperial City Prison",  boss = "Lord Warden Dusk",              dlc = true },
    { set = "Maarselok",             loc = "Lair of Maarselok",     boss = "Maarselok",                     dlc = true },
    { set = "Magma Incarnate",       loc = "The Dread Cellar",      boss = "Magma Incarnate",               dlc = true },
    { set = "Maw of the Infernal",   loc = "Banished Cells II",     boss = "High Kinlord Rilis" },
    { set = "Mighty Chudan",         loc = "Ruins of Mazzatun",     boss = "Tree-Minder Na-Kesh",           dlc = true },
    { set = "Molag Kena",            loc = "White-Gold Tower",      boss = "Molag Kena",                    dlc = true },
    { set = "Mother Ciannait",       loc = "Icereach",              boss = "Mother Ciannait",               dlc = true },
    { set = "Nazaray",               loc = "Shipwright's Regret",   boss = "Captain Numirril",              dlc = true },
    { set = "Nerien'eth",            loc = "Crypt of Hearts II",    boss = "Nerien'eth" },
    { set = "Nightflame",            loc = "Elden Hollow II",       boss = "Bogdan the Nightflame" },
    { set = "Orpheon the Tactician", loc = "Lep Seclusa",           boss = "Orpheon the Tactician",         dlc = true },
    { set = "Ozezan the Inferno",    loc = "Scrivener's Hall",      boss = "Valinna",                       dlc = true },
    { set = "Pirate Skeleton",       loc = "Blackheart Haven",      boss = "Captain Blackheart" },
    { set = "Prior Thierric",        loc = "Red Petal Bastion",     boss = "Prior Thierric Sarazen",        dlc = true },
    { set = "Roksa the Warped",      loc = "Bal Sunnar",            boss = "Matriarch Lladi Telvanni",      dlc = true },
    { set = "Scourge Harvester",     loc = "Wayrest Sewers II",     boss = "Allene and Varaine Pellingare" },
    { set = "Selene",                loc = "Selene's Web",          boss = "Selene" },
    { set = "Sellistrix",            loc = "Arx Corinium",          boss = "Sellistrix the Lamia Queen" },
    { set = "Sentinel of Rkugamz",   loc = "Darkshade Caverns I",   boss = "Sentinel of Rkugamz" },
    { set = "Shadowrend",            loc = "Banished Cells I",      boss = "Shadowrend" },
    { set = "Slimecraw",             loc = "Wayrest Sewers I",      boss = "Slimecraw" },
    { set = "Spawn of Mephala",      loc = "Fungal Grotto II",      boss = "Vila Theran" },
    { set = "Squall of Retribution", loc = "Exiled Redoubt",        boss = "Squall of Retribution",         dlc = true },
    { set = "Stone Husk",            loc = "Stone Garden",          boss = "Arkasis the Mad Alchemist",     dlc = true },
    { set = "Stonekeeper",           loc = "Frostvault",            boss = "The Stonekeeper",               dlc = true },
    { set = "Stormfist",             loc = "Tempest Island",        boss = "Stormreeve Neidir" },
    { set = "Swarm Mother",          loc = "Spindleclutch I",       boss = "The Whisperer" },
    { set = "Symphony of Blades",    loc = "Depths of Malatar",     boss = "Symphony of Blades",            dlc = true },
    { set = "Thurvokun",             loc = "Fang Lair",             boss = "Thurvokun",                     dlc = true },
    { set = "Tremorscale",           loc = "Volenfell",             boss = "Guardian Council" },
    { set = "The Troll King",        loc = "Blessed Crucible",      boss = "The Lava Queen" },
    { set = "Valkyn Skoria",         loc = "City of Ash II",        boss = "Valkyn Skoria" },
    { set = "Velidreth",             loc = "Cradle of Shadows",     boss = "Velidreth",                     dlc = true },
    { set = "Vykosa",                loc = "Moon Hunter Keep",      boss = "Vykosa",                        dlc = true },
    { set = "Zaan",                  loc = "Scalecaller Peak",      boss = "Zaan the Scalecaller",          dlc = true },
}

-- Extra notes for specific locations (shown in the location's info panel).
D.LOCATION_NOTES = {
    ["March of Sacrifices"] = "Update 51: can be run solo, with optional Meted Misfortunes difficulty (0-3).",
    ["Moon Hunter Keep"]    = "Update 51: can be run solo, with optional Meted Misfortunes difficulty (0-3).",
    ["Imperial City Prison"] = "Imperial City: other monster sets here are bought with Tel Var Stones, not dropped.",
}

-- Arenas: how many players.
D.ARENAS = {
    ["Maelstrom Arena"]    = "solo",
    ["Vateshran Hollows"]  = "solo",
    ["Blackrose Prison"]   = "group",
    ["Dragonstar Arena"]   = "group",
    ["Infinite Archive"]   = "soloduo",
}

-- ---------------------------------------------------------------------------
-- XP grind spots. group: "solo", "any" (solo or group) or "duo" (2+ players).
-- near: the closest wayshrine's name (start of it is enough); "Travel there" uses it
-- when you know it. Without it the spot is looked up on the zone map, which fails
-- until you've discovered the spot.
-- ---------------------------------------------------------------------------
D.GRIND_SPOTS = {
    {
        name = "Blackrose Prison", zone = "Murkmire", near = "Blackrose Prison", group = "duo", dlc = "Murkmire", rank = 1,
        enemies = "Arena waves",
        how = "Clear the first four arena rounds, then leave and reset the instance. The fastest XP in the game, but needs at least 2 players.",
    },
    {
        name = "Skyreach Catacombs", zone = "Craglorn", near = "Skyreach", group = "duo", rank = 2,
        enemies = "Undead and cultists",
        how = "Instanced loop: run the circular route, then reset the instance after a full clear. Best with 2+ players.",
    },
    {
        name = "Vile Manse", zone = "Reaper's March", near = "Fort Grimwatch", group = "any", rank = 3,
        enemies = "Humans",
        how = "Two floors with a circular route on each. Humans drop gold and loot, so it doubles as a gold farm.",
    },
    {
        name = "Obsidian Scar", zone = "Rivenspire", group = "any", rank = 4,
        enemies = "Humans",
        how = "Circular route through the public dungeon; bosses along the way add loot.",
    },
    {
        name = "Spellscar", zone = "Craglorn", near = "Spellscar", group = "solo", rank = 5,
        enemies = "Mixed packs",
        how = "Large open area with many enemy groups. Pull big packs and AoE them down. Can be crowded.",
    },
    {
        name = "Razak's Wheel", zone = "Bangkorai", group = "any", rank = 6,
        enemies = "Humans and Dwarven constructs",
        how = "Circular route through the public dungeon.",
    },
    {
        name = "Leftwheal Trading Post", zone = "West Weald", near = "Centurion's Watch", group = "any", dlc = "Gold Road", rank = 7,
        enemies = "Humanoids",
        how = "Large circular route with plenty of humanoid packs.",
    },
    {
        name = "Sentinel Docks", zone = "Alik'r Desert", near = "Sentinel", group = "solo", rank = 8,
        enemies = "Zombies",
        how = "North of Sentinel. Zombies respawn very fast; they also drop fleshfly larva (bait).",
    },
    {
        name = "Verrant Morass", zone = "Greenshade", near = "Verrant Morass", group = "solo", rank = 9,
        enemies = "Feral Bosmer",
        how = "Open area with weak enemies you can pull together.",
    },
    {
        name = "Vile Laboratory", zone = "Coldharbour", group = "solo", rank = 10,
        enemies = "Zombies",
        how = "Zombies that respawn quickly and drop fleshfly larva.",
    },
    {
        name = "Old Orsinium / Rkindaleft", zone = "Wrothgar", group = "any", dlc = "Orsinium",
        enemies = "Mixed",
        how = "Good beginner spots: public dungeons with steady respawns.",
    },
    {
        name = "Northglen", zone = "Bangkorai", group = "any", backup = true,
        enemies = "Humans and zombies",
        how = "Compact area; a good backup when Razak's Wheel is busy.",
    },
    {
        name = "Motalion Necropolis", zone = "Alik'r Desert", group = "any", backup = true,
        enemies = "Zombies and humans",
        how = "Backup spot near Sentinel.",
    },
    {
        name = "Obsidian Gorge", zone = "Deshaan", group = "any", backup = true,
        enemies = "Scattered small groups",
        how = "Smaller, spread-out enemies; quieter backup spot.",
    },
}

D.GRIND_TIPS = {
    "Humans drop gold and loot; zombies respawn faster but drop less.",
    "Do your daily Random Dungeon first: the first one each day gives a large XP bonus.",
    "XP scrolls and Ambrosia don't stack with each other, but they do stack with everything else (events, ESO Plus, group bonus).",
}

-- ---------------------------------------------------------------------------
-- XP boosts. kill = only affects XP from killing enemies.
-- How the addon finds the ones you own (all bags, bank, house storage):
--   items = parts of the English item name ("experience scroll" also finds the Gold
--           Coast and event scrolls); itemsByLang adds the same for other game
--           languages (de / fr / es: best known names, check them in those clients)
--   trait = gear with the Training trait
--   set   = a set; owned pieces come from the set tracking
--   status = shown live instead ("esoplus", "group", "enlightenment")
-- ---------------------------------------------------------------------------
D.XP_BOOSTS = {
    { key = "scroll", name = "Experience Scrolls", value = "+50 / 100 / 150%", items = { "experience scroll" },
      itemsByLang = { de = { "erfahrungsschriftrolle" }, fr = { "parchemin d'expérience" }, es = { "pergamino de experiencia" } },
      how = "Crown Store (50%, 2 hours; packs of 5 are cheaper). Crown Crate versions last 1 hour; the 100% and 150% versions come from Crown Crates / Crown Gems. Events and the Gold Coast also give scrolls.",
      note = "Doesn't stack with Ambrosia." },
    { key = "ambrosia", name = "Psijic / Aetherial / Mythic Aetherial Ambrosia", value = "+50 / 100 / 150%", items = { "ambrosia" },
      itemsByLang = { de = { "ambrosia" }, fr = { "ambroisie" }, es = { "ambrosía", "ambrosia" } },
      how = "Crafted drinks from rare provisioning recipes (the recipes are counted too).",
      note = "Same buff as Experience Scrolls: use one or the other." },
    { key = "esoplus", name = "ESO Plus", value = "+10%", how = "Active subscription.", status = "esoplus" },
    { key = "group", name = "Group bonus", value = "+10%", how = "Be in a group.", kill = true, status = "group" },
    { key = "mara", name = "Ring of Mara", value = "+10%", items = { "ring of mara" },
      itemsByLang = { de = { "mara" }, fr = { "mara" }, es = { "mara" } },
      how = "Wear the ring while grouped with the character you're joined with (Pledge of Mara)." },
    { key = "training", name = "Training trait", value = "up to ~86% total", trait = true, kill = true,
      how = "Put the Training trait on armor and weapons. Higher quality gives more." },
    { key = "heartland", name = "Heartland Conqueror", value = "+5-9%", set = "Heartland Conqueror",
      how = "Crafted set: doubles the value of your weapon's trait, including Training." },
    { key = "mora", name = "Mora's Whispers", value = "up to +15%", set = "Mora's Whispers",
      how = "Mythic item from Antiquities." },
    { key = "keeps", name = "Alliance keeps", value = "+5-15%", how = "Your alliance holding keeps in your Cyrodiil campaign.", kill = true },
    { key = "cyrodiil", name = "Cyrodiil overland", value = "+25%", how = "Any XP in Cyrodiil's open world (not delves or Imperial City)." },
    { key = "enlightenment", name = "Enlightenment", value = "x4 Champion XP", status = "enlightenment",
      how = "Builds up daily on every account; used up as you earn CP XP." },
    { key = "challenge", name = "Challenge Difficulty", value = "up to +100%", how = "Update 50: raise the overland difficulty tier." },
    { key = "apprentice", name = "Apprentice mundus", value = "XP and Inspiration", how = "Update 51: the Apprentice stone now boosts XP and Inspiration instead of Spell Damage. Exact value not published." },
    { key = "events", name = "XP events", value = "x2 and more", how = "Official double-XP events stack with scrolls and everything above." },
}

D.XP_MAX_NOTE = "Stacking everything reaches roughly +290% XP for most content."

-- ---------------------------------------------------------------------------
-- Grinding setup: sets, skills per class, consumables, mundus.
-- classId: 1 Dragonknight, 2 Sorcerer, 3 Nightblade, 4 Warden, 5 Necromancer,
-- 6 Templar, 117 Arcanist.
-- ---------------------------------------------------------------------------
-- short: fits on the row (keep it under ~38 characters); long: the tooltip.
-- boost: an XP_BOOSTS key, so the row shows (and links to) what you own of it.
D.SETUP_GEAR = {
    { name = "Training trait", short = "On every armor piece and weapon", boost = "training",
      long = "Training is a trait you can put on armor and weapons when you craft them (or find gear that has it). Every piece with Training gives you more XP per kill, and higher quality gives more." },
    { name = "Heartland Conqueror", short = "Crafted set: doubles weapon Training", boost = "heartland",
      long = "A set you craft at a set crafting station. Its bonus doubles the trait on your weapon, so a Training weapon counts twice." },
    { name = "Mora's Whispers", short = "Mythic item: up to +15% XP", boost = "mora",
      long = "A mythic item you dig up with Antiquities. It gives up to 15% more XP." },
    { name = "An area-damage set", short = "Kill whole groups at once",
      long = "Any set that boosts damage to many enemies. You level fastest by pulling a big group and killing it all at once." },
}

-- Skills that hit many enemies at once, per class.
D.SETUP_SKILLS = {
    { classId = 117, class = "Arcanist",     skills = "Escalating Runeblades, Fatecarver" },
    { classId = 1,   class = "Dragonknight", skills = "Shifting Standard, Core of Flame" },
    { classId = 5,   class = "Necromancer",  skills = "Boneyard, Frozen Colossus" },
    { classId = 3,   class = "Nightblade",   skills = "Twisting Path, Soul Tether" },
    { classId = 2,   class = "Sorcerer",     skills = "Storm Atronach, Lightning Flood" },
    { classId = 6,   class = "Templar",      skills = "Radial Sweep, Blazing Spear" },
    { classId = 4,   class = "Warden",       skills = "Sleet Storm, Impaling Shards" },
}

D.SETUP_CONSUMABLES = {
    { name = "XP Scroll or Ambrosia", short = "The biggest boost: +50 to +150% XP", boost = "scroll",
      long = "Experience Scrolls and Ambrosia both boost XP by 50%, 100% or 150%. They share the same buff, so use one at a time." },
    { name = "Food and drink", short = "Keeps your magicka and stamina up",
      long = "Food or drink that restores magicka or stamina lets you keep using your area skills between groups of enemies." },
    { name = "Filled soul gems", short = "Revive right where you died",
      long = "With a filled soul gem you revive on the spot instead of running back from a wayshrine." },
    { name = "Repair kits", short = "Long grinds wear out your gear",
      long = "Your armor loses durability every time you die. Repair kits fix it anywhere." },
}

D.SETUP_MUNDUS = {
    { name = "The Apprentice", short = "More XP (since Update 51)",
      long = "Mundus stones are standing stones in every zone. Since Update 51 the Apprentice gives more XP and Inspiration, which makes it the stone to use while leveling." },
}
