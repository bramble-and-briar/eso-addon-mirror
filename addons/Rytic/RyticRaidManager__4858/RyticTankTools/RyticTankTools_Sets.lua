------------------------------------------------------------
-- RYTICTANK SETS v7.2 - FRAGMENT-SAFE + LOCAL-REFERENCE OPTIMIZATION
--
-- ALL currently equipped sets are shown horizontally.
-- Each set:
--        [ ICON ]
--        NAME/ABBR
--        [pieces]
--
-- Known proc sets:
--   READY    = green R over lower portion of icon
--   COOLDOWN = countdown replaces R
--
-- Adjustable icon size + spacing through functions intended
-- for the RyticTank LibAddonMenu settings panel.
------------------------------------------------------------

local RyticTank = RyticTank

RyticTank.Sets = {}
local Sets = RyticTank.Sets
Sets.items = {}
Sets.equipped = {}
Sets.cooldownEnd = {}
Sets.activeUntil = {}
Sets.registeredAbilityIds = {}

-- Cache hot ESO globals/functions used repeatedly by this module.
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local GetFrameTimeSeconds = GetFrameTimeSeconds
local IsUnitInCombat = IsUnitInCombat
local GetUnitPower = GetUnitPower
local IsUnitDead = IsUnitDead

local TRACKED = {
    {name="Frozen Watcher",        short="FW",     dynamic="frozenwatcher"},
    {name="Pearlescent Ward",      short="PEARL", dynamic="pearl"},
    {name="Lucent Echoes",         short="LUCENT", dynamic="lucent"},
    {name="Puncturing Remedy",     short="PR", needed=2,  setId=0, abilityId=100575, cooldown=5, activeDuration=true},
    {name="Roar of Alkosh",       short="ALK", setId=0, abilityId=76667, cooldown=10, activeDuration=true, alkoshDebuff=true},
    {name="Stonehulk Dominion",   short="SH",  setId=827, abilityId=106754, cooldown=15},
    {name="Claw of Yolnahkriin",short="YOLN",abilityId=121878,cooldown=15,yoln=true,activeDuration=true},
    {name="Turning Tide",         short="TT",  setId=622, abilityId=167350, cooldown=15},
    {name="Crimson Oath's Rive", short="CO",  setId=602, abilityId=159291, cooldown=12},
    {name="Drake's Rush",        short="DR",  setId=571, abilityId=150974, cooldown=18},
    {name="Rush of Agony",       short="RA",  setId=604, abilityId=159279, cooldown=8},
    {name="Nazaray",             short="NAZ", setId=633, abilityId=167065, cooldown=30},
    {name="Nunatak",             short="NUN", setId=634, abilityId=167682, cooldown=15},
    {name="Archdruid Devyric",   short="AD",  setId=666, abilityId=176813, cooldown=15},
    {name="Encratis's Behemoth", short="ENC", setId=577, abilityId=151033, cooldown=15},
    {name="Magma Incarnate",     short="MI",  setId=609, abilityId=161527, cooldown=15},
    {name="Lady Thorn",          short="LT",  setId=535, abilityId=141905, cooldown=10},
    {name="Tremorscale",         short="TS",  setId=276, abilityId=80517, cooldown=10},
    {name="Void Bash",           short="VB", needed=2,  setId=558, altSetId=564, abilityId=147747, cooldown=13},

    -- DPS / arena sets
    -- Null Arca: crystal launch starts the 4 second Sliver lockout.
    {name="Perfected Slivers of the Null Arca", displayName="Null Arca", short="NULL", cooldown=4, combatName={"sliver","null arca"}},
    {name="Slivers of the Null Arca",           displayName="Null Arca", short="NULL", cooldown=4, combatName={"sliver","null arca"}},
    -- Spattering: base proc lockout is 7 seconds. Herald of the Tome can reduce it in play.
    {name="Spattering Disjunction", short="SD", cooldown=7, combatName={"spattering disjunction"}},
    -- Spectral Cloak has no useful proc CD to watch; show the equipped Blade Cloak morph timer instead.
    {name="Perfected Spectral Cloak", short="SC", needed=2, cloakTimer=true},
    {name="Spectral Cloak",           short="SC", needed=2, cloakTimer=true},

    -- Healer / support sets
    -- Pillager cooldown effect is exposed through combat events.
    {name="Pillager's Profit",     short="PP",  abilityId=172055, cooldown=45},
    -- RO has separate normal/perfected cooldown effects.
    {name="Roaring Opportunist",   short="RO",  abilityIds={135924,137985}, cooldown=22},
    -- These are tracked from their proc/effect names because the effect IDs
    -- have changed or are not consistently exposed by the ESO API.
    {name="Way of Martial Knowledge", short="MK", cooldown=8,  supportName={"martial knowledge"}},
    {name="Symphony of Blades",    short="SOB", cooldown=18, supportName={"meridia's favor","meridias favor","symphony of blades"}},
    {name="Ozezan the Inferno",    short="OZ",  activeWindow=1.1, supportName={"ozezan","minor vitality"}},
    -- Jorvuld's has no proc cooldown of its own; it modifies buff duration.
    {name="Jorvuld's Guidance",    short="JOR", dynamic="passive"},
    {name="Master Architect",      short="MA",  dynamic="masterslayer"},


    -- Infinite Archive class sets. These definitions are recognition-first: sets with
    -- no reliable public effect ID are shown as active/passive without registering
    -- unnecessary combat listeners. Specific timers can be promoted as verified.
    {name="Aerie's Cry",             short="AC",  dynamic="passive"},
    {name="Aetheric Lancer",          short="AL",  dynamic="passive"},
    {name="Basalt-Blooded Warrior",   short="BBW", dynamic="passive"},
    {name="Beacon of Oblivion",       short="BO",  dynamic="passive"},
    {name="Corpseburster",            short="CB",  dynamic="passive"},
    {name="Gardener of Seasons",      short="GOS", dynamic="passive"},
    {name="Monolith of Storms",       short="MOS", dynamic="passive"},
    {name="Nobility in Decay",        short="NID", dynamic="passive"},
    {name="Pyrebrand",                short="PYR", dynamic="passive"},
    {name="Reawakened Hierophant",    short="RH",  dynamic="passive"},
    {name="Soulcleaver",              short="SCV", dynamic="passive"},
    -- Spattering Disjunction is defined above with live cooldown handling.
    {name="Umbral Edge",              short="UE",  dynamic="passive"},
    {name="Wrathsun",                 short="WS",  dynamic="passive"},


    -- Arena gear and arena weapon sets. Recognition-first unless a set already has
    -- specialized live tracking above. Perfected variants are recognized by FindTracked().
    -- Dragonstar Arena gear
    {name="Archer's Mind",                 short="AM",   dynamic="passive"},
    {name="Footman's Fortune",             short="FF",   dynamic="passive"},
    {name="Healer's Habit",                 short="HH",   dynamic="passive"},
    {name="Robes of Destruction Mastery",  short="RDM",  dynamic="passive"},

    -- Maelstrom Arena gear
    {name="Elemental Succession",          short="ES",   dynamic="passive"},
    {name="Glorious Defender",              short="GD",   dynamic="passive"},
    {name="Hunt Leader",                    short="HL",   dynamic="passive"},
    {name="Para Bellum",                    short="PB",   dynamic="passive"},
    {name="Permafrost",                     short="PF",   dynamic="passive"},
    {name="Winterborn",                     short="WB",   dynamic="passive"},

    -- Vateshran Hollows gear
    {name="Explosive Rebuke",               short="ER",   dynamic="passive"},
    {name="Hex Siphon",                     short="HS",   dynamic="passive"},
    {name="Pestilent Host",                 short="PH",   dynamic="passive"},

    -- Asylum Sanctorium weapon sets are already included in the trial layer below.

    -- Blackrose Prison arena weapons. Spectral Cloak is specialized above.
    {name="Gallant Charge", short="GC", needed=2, activeWindow=3, supportName={"shield charge","invasion"}},
    {name="Mender's Ward",                  short="MW", needed=2,   dynamic="passive"},
    {name="Radial Uppercut",                short="RU", needed=2,   dynamic="passive"},
    {name="Virulent Shot",                  short="VS", needed=2,   dynamic="passive"},
    {name="Wild Impulse",                   short="WI", needed=2,   dynamic="passive"},

    -- Dragonstar Arena weapons. Puncturing Remedy is specialized above.
    {name="Caustic Arrow", short="CA", needed=2, dynamic="passive"},
    {name="Destructive Impact", short="DI", needed=2, activeWindow=4, supportName={"destructive touch","destructive reach","destructive clench"}},
    {name="Grand Rejuvenation", short="GR", needed=2, activeWindow=6, supportName={"grand healing","healing springs","illustrious healing"}},
    {name="Stinging Slashes", short="SS", needed=2, dynamic="passive"},
    {name="Titanic Cleave", short="TC", needed=2, dynamic="passive"},

    -- Maelstrom Arena weapons
    {name="Crushing Wall", short="CRW", needed=2, dynamic="passive"},
    {name="Cruel Flurry", short="CRF", needed=2, activeWindow=5, supportName={"flurry","rapid strikes","bloodthirst"}},
    {name="Merciless Charge", displayName="Maelstrom 2H", short="MC", needed=2, activeWindow=18, supportName={"critical charge","critical rush","stampede"}},
    {name="Precise Regeneration",           short="PRG", needed=2,  dynamic="passive"},
    {name="Rampaging Slash", short="RS", needed=2, activeWindow=5, supportName={"low slash","heroic slash","deep slash"}},
    {name="Thunderous Volley", short="TV", needed=2, dynamic="passive"},

    -- Vateshran Hollows weapons. Void Bash is specialized above.
    {name="Executioner's Blade", short="EB", needed=2, dynamic="passive"},
    {name="Force Overflow", short="FO", needed=2, dynamic="passive"},
    {name="Frenzied Momentum", short="FM", needed=2, dynamic="passive"},
    {name="Point-Blank Snipe", short="PBS", needed=2, dynamic="passive"},
    {name="Wrath of Elements", short="WOE", needed=2, dynamic="passive"},

    -- Dungeon sets. Recognition-first database entries. These do NOT register
    -- combat/effect listeners merely by existing here; equipped-only tracking remains
    -- the rule. Sets with useful verified proc IDs can be promoted individually later.
    {name="Abyssal Brace", short="AB", dynamic="passive"},
    {name="Aegis Caller", short="AC", dynamic="passive"},
    {name="Amber Plasm", short="AP", dynamic="passive"},
    {name="Apocryphal Inspiration", short="AI", dynamic="passive"},
    {name="Arkasis's Genius", short="ASG", dynamic="passive"},
    {name="Armor of Truth", short="AOT", dynamic="passive"},
    {name="Aspect of Mazzatun", short="AOM", dynamic="passive"},
    {name="Auroran's Thunder", short="AST", dynamic="passive"},
    {name="Azureblight Reaper", short="AR", dynamic="passive"},
    {name="Bani's Torment", short="BST", dynamic="passive"},
    {name="Barkskin", short="BARK", dynamic="passive"},
    {name="Black Foundry Steel", short="BFS", dynamic="passive"},
    {name="Black-Glove Grounding", short="BGG", dynamic="passive"},
    {name="Blind Path Induction", short="BPI", dynamic="passive"},
    {name="Blood Moon", short="BM", dynamic="passive"},
    {name="Blooddrinker", short="BLOO", dynamic="passive"},
    {name="Bone Pirate's Tatters", short="BPST", dynamic="passive"},
    {name="Brands of Imperium", short="BOI", dynamic="passive"},
    {name="Burning Spellweave", short="BS", dynamic="passive"},
    {name="Caluurion's Legacy", short="CSL", dynamic="passive"},
    {name="Cinders of Anthelmir", short="COA", dynamic="passive"},
    {name="Combat Physician", short="CP", dynamic="passive"},
    {name="Crimson Twilight", short="CT", dynamic="passive"},
    {name="Crusader", short="CRUS", dynamic="passive"},
    {name="Curse of Doylemish", short="COD", dynamic="passive"},
    {name="Dagon's Dominion", short="DSD", dynamic="passive"},
    {name="Deeproot Zeal", short="DZ", dynamic="passive"},
    {name="Dragon's Defilement", short="DSD", dynamic="passive"},
    {name="Draugr Hulk", short="DH", dynamic="passive"},
    {name="Draugr's Rest", short="DSR", dynamic="passive"},
    {name="Draugrkin's Grip", short="DSG", dynamic="passive"},
    {name="Dreugh King Slayer", short="DKS", dynamic="passive"},
    {name="Dro'Zakar's Claws", short="DZSC", dynamic="passive"},
    {name="Duneripper's Scales", short="DSS", dynamic="passive"},
    {name="Durok's Bane", short="DSB", dynamic="passive"},
    {name="Ebon Armory", short="EA", dynamic="passive"},
    {name="Elemental Catalyst", short="EC", dynamic="passive"},
    {name="Embershield", short="EMBE", dynamic="passive"},
    {name="Essence Thief", short="ET", dynamic="passive"},
    {name="Flame Blossom", short="FB", dynamic="passive"},
    {name="Fledgling's Nest", short="FSN", dynamic="passive"},
    {name="Foolkiller's Ward", short="FSW", dynamic="passive"},
    {name="Glacial Guardian", short="GG", dynamic="passive"},
    {name="Gossamer", short="GOSS", dynamic="passive"},
    {name="Grave Guardian", short="GG", dynamic="passive"},
    {name="Grave Inevitability", short="GI", dynamic="passive"},
    {name="Grisly Gourmet", short="GG", dynamic="passive"},
    {name="Gryphon's Reprisal", short="GSR", dynamic="passive"},
    {name="Hagraven's Garden", short="HSG", dynamic="passive"},
    {name="Hand of Mephala", short="HOM", dynamic="passive"},
    {name="Hanu's Compassion", short="HSC", dynamic="passive"},
    {name="Haven of Ursus", short="HOU", dynamic="passive"},
    {name="Heem-Jas' Retribution", short="HJR", dynamic="passive"},
    {name="Heroic Unity", short="HU", dynamic="passive"},
    {name="Hircine's Veneer", short="HSV", dynamic="passive"},
    {name="Hiti's Hearth", short="HSH", dynamic="passive"},
    {name="Hollowfang Thirst", short="HT", dynamic="passive"},
    {name="Icy Conjurer", short="IC", dynamic="passive"},
    {name="Ironblood", short="IRON", dynamic="passive"},
    {name="Jailbreaker", short="JAIL", dynamic="passive"},
    {name="Jailer's Tenacity", short="JST", dynamic="passive"},
    {name="Jerensi's Bladestorm", short="JSB", dynamic="passive"},
    {name="Jolting Arms", short="JA", dynamic="passive"},
    {name="Kinras's Wrath", short="KSW", dynamic="passive"},
    {name="Knight-Errant's Mail", short="KESM", dynamic="passive"},
    {name="Knightmare", short="KNIG", dynamic="passive"},
    {name="Kraglen's Howl", short="KSH", dynamic="passive"},
    {name="Lamia's Song", short="LSS", dynamic="passive"},
    {name="Leeching Plate", short="LP", dynamic="passive"},
    {name="Leviathan", short="LEVI", dynamic="passive"},
    {name="Light Speaker", short="LS", dynamic="passive"},
    {name="Lucilla's Windshield", short="LSW", dynamic="passive"},
    {name="Lustrous Soulwell", short="LS", dynamic="passive"},
    {name="Magicka Furnace", short="MF", dynamic="passive"},
    {name="Maligalig's Maelstrom", short="MSM", dynamic="passive"},
    {name="Medusa", short="MEDU", dynamic="passive"},
    {name="Mighty Glacier", short="MG", dynamic="passive"},
    {name="Moon Hunter", short="MH", dynamic="passive"},
    {name="Netch's Touch", short="NST", dynamic="passive"},
    {name="Nikulas' Heavy Armor", short="NHA", dynamic="passive"},
    {name="Nix-Hound's Howl", short="NHSH", dynamic="passive"},
    {name="Noble Duelist's Silks", short="NDSS", dynamic="passive"},
    {name="Noxious Boulder", short="NB", dynamic="passive"},
    {name="Oblivion's Edge", short="OSE", dynamic="passive"},
    {name="Overwhelming Surge", short="OS", dynamic="passive"},
    {name="Pangrit Denmother", short="PD", dynamic="passive"},
    {name="Phylactery's Grasp", short="PSG", dynamic="passive"},
    {name="Pillar of Nirn", short="PON", dynamic="passive"},
    {name="Plague Slinger", short="PS", dynamic="passive"},
    {name="Prayer Shawl", short="PS", dynamic="passive"},
    {name="Rage of the Ursauk", short="ROTU", dynamic="passive"},
    {name="Rattlecage", short="RATT", dynamic="passive"},
    {name="Reflected Fury", short="RF", dynamic="passive"},
    {name="Renald's Resolve", short="RSR", dynamic="passive"},
    {name="Ritemaster's Bond", short="RSB", dynamic="passive"},
    {name="Runecarver's Blaze", short="RSB", dynamic="passive"},
    {name="Sanctuary", short="SANC", dynamic="passive"},
    {name="Savage Werewolf", short="SW", dynamic="passive"},
    {name="Scathing Mage", short="SM", dynamic="passive"},
    {name="Scavenging Demise", short="SD", dynamic="passive"},
    {name="Scorion's Feast", short="SSF", dynamic="passive"},
    {name="Sergeant's Mail", short="SSM", dynamic="passive"},
    {name="Sheer Venom", short="SV", dynamic="passive"},
    {name="Shroud of the Lich", short="SOTL", dynamic="passive"},
    {name="Silver Rose Vigil", short="SRV", dynamic="passive"},
    {name="Sluthrug's Hunger", short="SSH", dynamic="passive"},
    {name="Spell Power Cure", short="SPC", dynamic="passive"},
    {name="Spelunker", short="SPEL", dynamic="passive"},
    {name="Spider Cultist Cowl", short="SCC", dynamic="passive"},
    {name="Spriggan's Vigor", short="SSV", dynamic="passive"},
    {name="Stone's Accord", short="SSA", dynamic="passive"},
    {name="Storm Master", short="SM", dynamic="passive"},
    {name="Storm-Cursed's Revenge", short="SCSR", dynamic="passive"},
    {name="Strength of the Automaton", short="SOTA", dynamic="passive"},
    {name="Sunderflame", short="SUND", dynamic="passive"},
    {name="Sword Dancer", short="SD", dynamic="passive"},
    {name="Talfyg's Treachery", short="TST", dynamic="passive"},
    {name="Tarnished Nightmare", short="TN", dynamic="passive"},
    {name="Telvanni Enforcer", short="TE", dynamic="passive"},
    {name="The Ice Furnace", short="TIF", dynamic="passive"},
    {name="The Worm's Raiment", short="TWSR", dynamic="passive"},
    {name="Thunder Caller", short="TC", dynamic="passive"},
    {name="Titanborn Strength", short="TS", dynamic="passive"},
    {name="Tools of the Trapmaster", short="TOTT", dynamic="passive"},
    {name="Toothrow", short="TOOT", dynamic="passive"},
    {name="Tormentor", short="TORM", dynamic="passive"},
    {name="Trappings of Invigoration", short="TOI", dynamic="passive"},
    {name="Treasure Hunter", short="TH", dynamic="passive"},
    {name="True-Sworn Fury", short="TSF", dynamic="passive"},
    {name="Tzogvin's Warband", short="TSW", dynamic="passive"},
    {name="Ulfnor's Favor", short="USF", dynamic="passive"},
    {name="Undaunted Bastion", short="UB", dynamic="passive"},
    {name="Undaunted Infiltrator", short="UI", dynamic="passive"},
    {name="Undaunted Unweaver", short="UU", dynamic="passive"},
    {name="Unleashed Ritualist", short="UR", dynamic="passive"},
    {name="Unleashed Terror", short="UT", dynamic="passive"},
    {name="Vandorallen's Resonance", short="VSR", dynamic="passive"},
    {name="Vestments of the Warlock", short="VOTW", dynamic="passive"},
    {name="Viper's Sting", short="VSS", dynamic="passive"},
    {name="Vykand's Soulfury", short="VSS", dynamic="passive"},
    {name="Widowmaker", short="WIDO", dynamic="passive"},
    {name="Xanmeer Spellweaver", short="XS", dynamic="passive"},
    {name="Z'en's Redress", short="ZESR", dynamic="passive"},

    -- Trial / raid sets. Recognition-first: normal and Perfected variants both
    -- resolve through FindTracked() without adding live listeners unless a set already
    -- has verified proc tracking above. This keeps the database large and runtime cheap.
    -- Craglorn trials
    {name="Berserking Warrior",          short="BW",   dynamic="passive"},
    {name="Defending Warrior",           short="DW",   dynamic="passive"},
    {name="Destructive Mage",            short="DM",   dynamic="passive"},
    {name="Eternal Warrior",             short="EW",   dynamic="passive"},
    {name="Healing Mage",                short="HM",   dynamic="passive"},
    {name="Immortal Warrior",            short="IW",   dynamic="passive"},
    {name="Infallible Mage",             short="IM",   dynamic="passive"},
    {name="Quick Serpent",               short="QS",   dynamic="passive"},
    {name="Vicious Serpent",             short="VS",   dynamic="passive"},
    {name="Wise Mage",                   short="WM",   dynamic="passive"},

    -- Maw of Lorkhaj
    {name="Lunar Bastion",               short="LB",   dynamic="passive"},
    {name="Moondancer",                  short="MD",   dynamic="passive"},
    {name="Twilight Remedy",             short="TR",   dynamic="passive"},
    -- Roar of Alkosh is already tracked above.

    -- Halls of Fabrication
    {name="Automated Defense",            short="AD2",  dynamic="passive"},
    {name="Inventor's Guard",            short="IG",   dynamic="passive"},
    {name="War Machine",                 short="WM2",  dynamic="passive"},
    -- Master Architect is already tracked above.

    -- Asylum Sanctorium weapon sets
    {name="Chaotic Whirlwind", short="CW", needed=2, dynamic="passive"},
    {name="Concentrated Force", short="CF", needed=2, dynamic="passive"},
    {name="Defensive Position", short="DP", needed=2, dynamic="passive"},
    {name="Disciplined Slash", short="DS", needed=2, dynamic="passive"},
    {name="Piercing Spray", short="PS", needed=2, dynamic="passive"},
    {name="Timeless Blessing", short="TB", needed=2, dynamic="passive"},

    -- Cloudrest
    {name="Arms of Relequen",             short="REL",  dynamic="passive"},
    {name="Mantle of Siroria",            short="SIR",  dynamic="passive"},
    {name="Vestment of Olorime",          short="OLO",  dynamic="passive"},
    {name="Aegis of Galenwe",             short="GAL",  dynamic="passive"},

    -- Sunspire
    {name="False God's Devotion",          short="FGD",  dynamic="passive"},
    {name="Tooth of Lokkestiiz",          short="LOK",  dynamic="passive"},
    {name="Eye of Nahviintaas",           short="NAH",  dynamic="passive"},
    -- Claw of Yolnahkriin is already tracked above.

    -- Kyne's Aegis
    {name="Yandir's Might",               short="YAN",  dynamic="passive"},
    {name="Kyne's Wind",                  short="KW",   dynamic="passive"},
    {name="Vrol's Command",               short="VROL", dynamic="passive"},
    -- Roaring Opportunist is already tracked above.

    -- Rockgrove
    {name="Bahsei's Mania",               short="BAH",  dynamic="passive"},
    {name="Sul-Xan's Torment",            short="SXT",  dynamic="passive"},
    {name="Saxhleel Champion",            short="SAX",  dynamic="passive"},
    {name="Stone-Talker's Oath",          short="STO",  dynamic="passive"},

    -- Dreadsail Reef
    {name="Coral Riptide",                short="CR",   dynamic="passive"},
    {name="Whorl of the Depths",          short="WHORL",dynamic="passive"},
    -- Pearlescent Ward and Pillager's Profit are already tracked above.

    -- Sanity's Edge
    {name="Ansuul's Torment",             short="ANS",  dynamic="passive"},
    {name="Peace and Serenity",           short="PAS",  dynamic="passive"},
    {name="Test of Resolve",              short="TOR",  dynamic="passive"},
    {name="Transformative Hope",          short="TH",   dynamic="passive"},

    -- Lucent Citadel
    {name="Mora Scribe's Thesis",         short="MST",  dynamic="passive"},
    {name="Xoryn's Masterpiece",          short="XOR",  dynamic="passive"},
    -- Lucent Echoes and Slivers of the Null Arca are already tracked above.

    -- Ossein Cage
    {name="Dolorous Arena",               short="DA",   dynamic="passive"},
    {name="Harmony in Chaos",             short="HIC",  dynamic="passive"},
    {name="Kazpian's Cruel Signet",       short="KCS",  dynamic="passive"},
    {name="Recovery Convergence",         short="RC",   dynamic="passive"},

    -- Mythics. Keep recognition cheap: passive/state-only mythics do not register
    -- combat listeners merely because they exist in the database.
    {name="Belharza's Band",                 short="BB",   dynamic="passive", needed=1},
    {name="Bloodlord's Embrace",             short="BE",   dynamic="passive", needed=1},
    {name="Cryptcanon Vestments",             short="CV",   dynamic="passive", needed=1},
    {name="Death Dealer's Fete",             short="DDF",  dynamic="passive", needed=1},
    {name="Dov-rha Sabatons",                 short="DRS",  dynamic="passive", needed=1},
    {name="Esoteric Environment Greaves",     short="EEG",  dynamic="passive", needed=1},
    {name="Faun's Lark Cladding",             short="FLC",  dynamic="passive", needed=1},
    {name="Gaze of Sithis",                   short="GOS",  dynamic="passive", needed=1},
    {name="Harpooner's Wading Kilt",         short="HWK",  dynamic="passive", needed=1},
    {name="Huntsman's Warmask",              short="HW",   dynamic="passive", needed=1},
    {name="Lefthander's Aegis Belt",         short="LAB",  dynamic="passive", needed=1},
    {name="Malacath's Band of Brutality",    short="MBB",  dynamic="passive", needed=1},
    {name="Markyn Ring of Majesty",           short="MRM",  dynamic="passive", needed=1},
    {name="Monomyth Reforged",                short="MR",   dynamic="passive", needed=1},
    {name="Mora's Whispers",                 short="MW",   dynamic="passive", needed=1},
    {name="Oakensoul Ring",                   short="OAK",  dynamic="passive", needed=1},
    {name="Pearls of Ehlnofey",               short="PE",   dynamic="passive", needed=1},
    {name="Prowler's Talisman",              short="PT",   dynamic="passive", needed=1},
    {name="Ring of the Pale Order",           short="RPO",  dynamic="passive", needed=1},
    {name="Ring of the Wild Hunt",            short="RWH",  dynamic="passive", needed=1},
    {name="Sea-Serpent's Coil",              short="SSC",  dynamic="passive", needed=1},
    {name="Shapeshifter's Chain",            short="SSC2", dynamic="passive", needed=1},
    {name="Shattered Paths Signet",           short="SPS",  dynamic="passive", needed=1},
    {name="Snow Treaders",                    short="ST",   dynamic="passive", needed=1},
    {name="Spaulder of Ruin",                 short="SOR",  dynamic="passive", needed=1},
    {name="Stormweaver's Cavort",            short="SWC",  dynamic="passive", needed=1},
    {name="Syrabane's Ward",                 short="SW",   dynamic="passive", needed=1},
    {name="The Saint and the Seducer",        short="SS",   dynamic="passive", needed=1},
    {name="The Shadow Queen's Cowl",         short="SQC",  dynamic="passive", needed=1},
    {name="Thrassian Stranglers",             short="TS",   dynamic="passive", needed=1},
    {name="Tide-Born Wildstalker",            short="TBW",  dynamic="passive", needed=1},
    {name="Torc of Tonal Constancy",          short="TTC",  dynamic="passive", needed=1},
    {name="Torc of the Last Ayleid King",     short="TLAK", dynamic="passive", needed=1},
    {name="Velothi Ur-Mage's Amulet",        short="VEL",  dynamic="passive", needed=1},
    {name="Rourken Steamguards",                 short="RSG",  dynamic="passive", needed=1},
    -- PvP sets. Recognition-first database entries. These do NOT register
    -- combat/effect listeners unless a set is later promoted to verified live tracking.
    {name="Affliction", short="AFFL", dynamic="passive"},
    {name="Agility", short="AGIL", dynamic="passive"},
    {name="Alessian Order", short="AO", dynamic="passive"},
    {name="Almalexia's Mercy", short="ASM", dynamic="passive"},
    {name="Arkay's Charity", short="ASC", dynamic="passive"},
    {name="Baan Dar's Blessing", short="BDSB", dynamic="passive"},
    {name="Bastion of the Heartland", short="BOTH", dynamic="passive"},
    {name="Battalion Defender", short="BD", dynamic="passive"},
    {name="Battlefield Acrobat", short="BA", dynamic="passive"},
    {name="Beckoning Steel", short="BS", dynamic="passive"},
    {name="Black Rose", short="BR", dynamic="passive"},
    {name="Blackfeather Flight", short="BF", dynamic="passive"},
    {name="Blessing of the Potentates", short="BOTP", dynamic="passive"},
    {name="Blunted Blades", short="BB", dynamic="passive"},
    {name="Buffer of the Swift", short="BOTS", dynamic="passive"},
    {name="Bulwark Ruination", short="BR", dynamic="passive"},
    {name="Colovian Highlands General", short="CHG", dynamic="passive"},
    {name="Coup De Grâce", short="CDGC", dynamic="passive"},
    {name="Coward's Gear", short="CSG", dynamic="passive"},
    {name="Crest of Cyrodiil", short="COC", dynamic="passive"},
    {name="Curse Eater", short="CE", dynamic="passive"},
    {name="Dark Convergence", short="DC", dynamic="passive"},
    {name="Deadly Strike", short="DS", dynamic="passive"},
    {name="Desert Rose", short="DR", dynamic="passive"},
    {name="Eagle Eye", short="EE", dynamic="passive"},
    {name="Elf Bane", short="EB", dynamic="passive"},
    {name="Endurance", short="ENDU", dynamic="passive"},
    {name="Enervating Aura", short="EA", dynamic="passive"},
    {name="Farstrider", short="FARS", dynamic="passive"},
    {name="Fasalla's Guile", short="FSG", dynamic="passive"},
    {name="Galerion's Revenge", short="GSR", dynamic="passive"},
    {name="Gorethief", short="GORE", dynamic="passive"},
    {name="Grace of the Ancients", short="GOTA", dynamic="passive"},
    {name="Hawk's Eye", short="HSE", dynamic="passive"},
    {name="Hew and Sunder", short="HAS", dynamic="passive"},
    {name="Hrothgar's Chill", short="HSC", dynamic="passive"},
    {name="Imperial Physique", short="IP", dynamic="passive"},
    {name="Impregnable Armor", short="IA", dynamic="passive"},
    {name="Indomitable Fury", short="IF", dynamic="passive"},
    {name="Jerall Mountains Warchief", short="JMW", dynamic="passive"},
    {name="Judgment of Akatosh", short="JOA", dynamic="passive"},
    {name="Knight Slayer", short="KS", dynamic="passive"},
    {name="Kyne's Kiss", short="KSK", dynamic="passive"},
    {name="Lamp Knight's Art", short="LKSA", dynamic="passive"},
    {name="Languor of Peryite", short="LOP", dynamic="passive"},
    {name="Leki's Focus", short="LSF", dynamic="passive"},
    {name="Light of Cyrodiil", short="LOC", dynamic="passive"},
    {name="Mara's Balm", short="MSB", dynamic="passive"},
    {name="Marksman's Crest", short="MSC", dynamic="passive"},
    {name="Meritorious Service", short="MS", dynamic="passive"},
    {name="Netch Oil", short="NO", dynamic="passive"},
    {name="Nibenay Bay Battlereeve", short="NBB", dynamic="passive"},
    {name="Nocturnal's Ploy", short="NSP", dynamic="passive"},
    {name="Oakfather's Retribution", short="OSR", dynamic="passive"},
    {name="Phoenix", short="PHOE", dynamic="passive"},
    {name="Plaguebreak", short="PLAG", dynamic="passive"},
    {name="Powerful Assault", short="PA", dynamic="passive"},
    {name="Rallying Cry", short="RC", dynamic="passive"},
    {name="Ravager", short="RAVA", dynamic="passive"},
    {name="Reactive Armor", short="RA", dynamic="passive"},
    {name="Robes of Alteration Mastery", short="ROAM", dynamic="passive"},
    {name="Robes of Transmutation", short="ROT", dynamic="passive"},
    {name="Sentry", short="SENT", dynamic="passive"},
    {name="Shadow Walker", short="SW", dynamic="passive"},
    {name="Shared Pain", short="SP", dynamic="passive"},
    {name="Shell Splitter", short="SS", dynamic="passive"},
    {name="Shield Breaker", short="SB", dynamic="passive"},
    {name="Shield of the Valiant", short="SOTV", dynamic="passive"},
    {name="Siegemaster's Focus", short="SSF", dynamic="passive"},
    {name="Snake in the Stars", short="SITS", dynamic="passive"},
    {name="Soldier of Anguish", short="SOA", dynamic="passive"},
    {name="Spell Strategist", short="SS", dynamic="passive"},
    {name="Spellshredder", short="SPEL", dynamic="passive"},
    {name="Steadfast Hero", short="SH", dynamic="passive"},
    {name="The Arch-Mage", short="TAM", dynamic="passive"},
    {name="The Juggernaut", short="TJ", dynamic="passive"},
    {name="The Morag Tong", short="TMT", dynamic="passive"},
    {name="Thews of the Harbinger", short="TOTH", dynamic="passive"},
    {name="Tracker's Lash", short="TSL", dynamic="passive"},
    {name="Unflinching Ultimate", short="UU", dynamic="passive"},
    {name="Vanguard's Challenge", short="VSC", dynamic="passive"},
    {name="Vengeance Leech", short="VL", dynamic="passive"},
    {name="Vicecanon of Venom", short="VOV", dynamic="passive"},
    {name="Vicious Death", short="VD", dynamic="passive"},
    {name="Ward of Cyrodiil", short="WOC", dynamic="passive"},
    {name="Warrior's Fury", short="WSF", dynamic="passive"},
    {name="Willpower", short="WILL", dynamic="passive"},
    {name="Wizard's Riposte", short="WSR", dynamic="passive"},
    {name="Wrath of the Imperium", short="WOTI", dynamic="passive"},

    -- Monster sets (recognition-first; 2-piece activation; equipped-only architecture)
    {name="Anthelmir's Construct", short="AC", dynamic="passive", needed=2},
    {name="Euphotic Gatekeeper", short="EGK", dynamic="passive", needed=2},
    {name="Squall of Retribution", short="SOR2", dynamic="passive", needed=2},
    {name="Balorgh", short="BAL", dynamic="passive", needed=2},
    {name="Baron Thirsk", short="BTH", dynamic="passive", needed=2},
    {name="Baron Zaudrus", short="BZA", dynamic="passive", needed=2},
    {name="Bloodspawn", short="BLS", dynamic="passive", needed=2},
    {name="Nightflame", short="BTN", dynamic="passive", needed=2},
    {name="Chokethorn", short="CHO", dynamic="passive", needed=2},
    {name="Domihaus", short="DOM", dynamic="passive", needed=2},
    {name="Earthgore", short="EAR", dynamic="passive", needed=2},
    {name="Engine Guardian", short="EG", dynamic="passive", needed=2},
    {name="Grothdarr", short="GRO", dynamic="passive", needed=2},
    {name="Ilambris", short="ILA", dynamic="passive", needed=2},
    {name="Iceheart", short="ICE", dynamic="passive", needed=2},
    {name="Infernal Guardian", short="IG", dynamic="passive", needed=2},
    {name="Kargaeda", short="KAR", dynamic="passive", needed=2},
    {name="Kjalnar's Nightmare", short="KJN", dynamic="passive", needed=2},
    {name="Kra'gh", short="KRA", dynamic="passive", needed=2},
    {name="Lady Malygda", short="LM", dynamic="passive", needed=2},
    {name="Lord Warden", short="LW", dynamic="passive", needed=2},
    {name="Maarselok", short="MAA", dynamic="passive", needed=2},
    {name="Maw of the Infernal", short="MOI", dynamic="passive", needed=2},
    {name="Mighty Chudan", short="MC", dynamic="passive", needed=2},
    {name="Molag Kena", short="MK", dynamic="passive", needed=2},
    {name="Mother Ciannait", short="MCI", dynamic="passive", needed=2},
    {name="Nerien'eth", short="NER", dynamic="passive", needed=2},
    {name="Pirate Skeleton", short="PS", dynamic="passive", needed=2},
    {name="Prior Thierric", short="PT", dynamic="passive", needed=2},
    {name="Roksa the Warped", short="RTW", dynamic="passive", needed=2},
    {name="Scourge Harvester", short="SH", dynamic="passive", needed=2},
    {name="Selene", short="SEL", dynamic="passive", needed=2},
    {name="Sellistrix", short="SEX", dynamic="passive", needed=2},
    {name="Sentinel of Rkugamz", short="SOR", dynamic="passive", needed=2},
    {name="Slimecraw", short="SLI", dynamic="passive", needed=2},
    {name="Spawn of Mephala", short="SOM", dynamic="passive", needed=2},
    {name="Stonekeeper", short="SK", dynamic="passive", needed=2},
    {name="Stormfist", short="STF", dynamic="passive", needed=2},
    {name="The Troll King", short="TTK", dynamic="passive", needed=2},
    {name="Thurvokun", short="THU", dynamic="passive", needed=2},
    {name="Valkyn Skoria", short="VS", dynamic="passive", needed=2},
    {name="Velidreth", short="VEL", dynamic="passive", needed=2},
    {name="Vykosa", short="VYK", dynamic="passive", needed=2},
    {name="Zaan", short="ZAA", dynamic="passive", needed=2},
    {name="Grundwulf", short="GRU", dynamic="passive", needed=2},
    {name="Glorgoloch the Destroyer", short="GTD", dynamic="passive", needed=2},
    {name="Immolator Charr", short="IC", dynamic="passive", needed=2},
    {name="Zoal the Ever-Wakeful", short="ZOE", dynamic="passive", needed=2},
    {name="The Blind", short="TBL", dynamic="passive", needed=2},
    {name="Orpheon the Tactician", short="OTT", dynamic="passive", needed=2},
    {name="Black Gem Monstrosity", short="BGM", dynamic="passive", needed=2},
    {name="Glittering Goad", short="GG", dynamic="passive", needed=2},
    {name="Mylenne Moon-Caller", short="MMC", dynamic="passive", needed=2},
    {name="Bar-Sakka", short="BS", dynamic="passive", needed=2},
    {name="The Ruckus", short="TR", dynamic="passive", needed=2},
    {name="Thousand Eyes", short="TE", dynamic="passive", needed=2},
    {name="Swarm Mother", short="SWM", dynamic="passive", needed=2},
    {name="Shadowrend", short="SR", dynamic="passive", needed=2},

    -- Crafted sets (recognition-first; equipped-only architecture)
    {name="Adept Rider", short="AR", dynamic="passive"},
    {name="Aetherial Ascension", short="AA", dynamic="passive"},
    {name="Alessia's Bulwark", short="ASB", dynamic="passive"},
    {name="Ancient Dragonguard", short="AD", dynamic="passive"},
    {name="Armor Master", short="AM", dynamic="passive"},
    {name="Armor of the Seducer", short="AOTS", dynamic="passive"},
    {name="Ashen Grip", short="AG", dynamic="passive"},
    {name="Assassin's Guile", short="ASG", dynamic="passive"},
    {name="Chimera's Rebuke", short="CSR", dynamic="passive"},
    {name="Claw of the Forest Wraith", short="COTFW", dynamic="passive"},
    {name="Clever Alchemist", short="CA", dynamic="passive"},
    {name="Coldharbour's Favorite", short="CSF", dynamic="passive"},
    {name="Critical Riposte", short="CR", dynamic="passive"},
    {name="Daedric Trickery", short="DT", dynamic="passive"},
    {name="Daring Corsair", short="DC", dynamic="passive"},
    {name="Dauntless Combatant", short="DC", dynamic="passive"},
    {name="Deadlands Demolisher", short="DD", dynamic="passive"},
    {name="Death's Wind", short="DSW", dynamic="passive"},
    {name="Diamond's Victory", short="DSV", dynamic="passive"},
    {name="Dragon's Appetite", short="DSA", dynamic="passive"},
    {name="Druid's Braid", short="DSB", dynamic="passive"},
    {name="Eternal Hunt", short="EH", dynamic="passive"},
    {name="Eyes of Mara", short="EOM", dynamic="passive"},
    {name="Fellowship's Fortitude", short="FSF", dynamic="passive"},
    {name="Fortified Brass", short="FB", dynamic="passive"},
    {name="Grave-Stake Collector", short="GSC", dynamic="passive"},
    {name="Heartland Conqueror", short="HC", dynamic="passive"},
    {name="Highland Sentinel", short="HS", dynamic="passive"},
    {name="Hist Bark", short="HB", dynamic="passive"},
    {name="Hist Whisperer", short="HW", dynamic="passive"},
    {name="Hunding's Rage", short="HSR", dynamic="passive"},
    {name="Innate Axiom", short="IA", dynamic="passive"},
    {name="Iron Flask", short="IF", dynamic="passive"},
    {name="Kagrenac's Hope", short="KSH", dynamic="passive"},
    {name="Kvatch Gladiator", short="KG", dynamic="passive"},
    {name="Law of Julianos", short="LOJ", dynamic="passive"},
    {name="Legacy of Karth", short="LOK", dynamic="passive"},
    {name="Magnus' Gift", short="MG", dynamic="passive"},
    {name="Mechanical Acuity", short="MA", dynamic="passive"},
    {name="Might of the Lost Legion", short="MOTLL", dynamic="passive"},
    {name="Morkuldin", short="MORK", dynamic="passive"},
    {name="Naga Shaman", short="NS", dynamic="passive"},
    {name="New Moon Acolyte", short="NMA", dynamic="passive"},
    {name="Night Mother's Gaze", short="NMSG", dynamic="passive"},
    {name="Night's Silence", short="NSS", dynamic="passive"},
    {name="Noble's Conquest", short="NSC", dynamic="passive"},
    {name="Nocturnal's Favor", short="NSF", dynamic="passive"},
    {name="Oblivion's Foe", short="OSF", dynamic="passive"},
    {name="Old Growth Brewer", short="OGB", dynamic="passive"},
    {name="Order's Wrath", short="OSW", dynamic="passive"},
    {name="Orgnum's Scales", short="OSS", dynamic="passive"},
    {name="Pelinal's Wrath", short="PSW", dynamic="passive"},
    {name="Red Eagle's Fury", short="RESF", dynamic="passive"},
    {name="Redistributor", short="REDI", dynamic="passive"},
    {name="Seeker Synthesis", short="SS", dynamic="passive"},
    {name="Senche-Raht's Grit", short="SRSG", dynamic="passive"},
    {name="Serpent's Disdain", short="SSD", dynamic="passive"},
    {name="Shacklebreaker", short="SHAC", dynamic="passive"},
    {name="Shalidor's Curse", short="SSC", dynamic="passive"},
    {name="Shared Burden", short="SB", dynamic="passive"},
    {name="Shattered Fate", short="SF", dynamic="passive"},
    {name="Sload's Semblance", short="SSS", dynamic="passive"},
    {name="Song of Lamae", short="SOL", dynamic="passive"},
    {name="Spectre's Eye", short="SSE", dynamic="passive"},
    {name="Spell Parasite", short="SP", dynamic="passive"},
    {name="Stuhn's Favor", short="SSF", dynamic="passive"},
    {name="Tava's Favor", short="TSF", dynamic="passive"},
    {name="Telvanni Efficiency", short="TE", dynamic="passive"},
    {name="Tharriker's Strike", short="TSS", dynamic="passive"},
    {name="Threads of War", short="TOW", dynamic="passive"},
    {name="Torug's Pact", short="TSP", dynamic="passive"},
    {name="Trial by Fire", short="TBF", dynamic="passive"},
    {name="Twice-Born Star", short="TBS", dynamic="passive"},
    {name="Twilight's Embrace", short="TSE", dynamic="passive"},
    {name="Unchained Aggressor", short="UA", dynamic="passive"},
    {name="Vampire's Kiss", short="VSK", dynamic="passive"},
    {name="Varen's Legacy", short="VSL", dynamic="passive"},
    {name="Vastarie's Tutelage", short="VST", dynamic="passive"},
    {name="Way of the Arena", short="WOTA", dynamic="passive"},
    {name="Whitestrake's Retribution", short="WSR", dynamic="passive"},
    {name="Willow's Path", short="WSP", dynamic="passive"},
    {name="Wretched Vitality", short="WV", dynamic="passive"},

    -- Overland sets (recognition-first; equipped-only architecture)
    {name="Adamant Lurker", short="AL", dynamic="passive"},
    {name="Akaviri Dragonguard", short="AD", dynamic="passive"},
    {name="Armor of the Trainee", short="AT", dynamic="passive", needed=3},
    {name="Armor of the Veiled Heritance", short="AVH", dynamic="passive"},
    {name="Ayleid Refuge", short="AR", dynamic="passive"},
    {name="Back-Alley Gourmand", short="BAG", dynamic="passive"},
    {name="Bahraha's Curse", short="BSC", dynamic="passive"},
    {name="Bastion of the Draoife", short="BD", dynamic="passive"},
    {name="Beekeeper's Gear", short="BSG", dynamic="passive"},
    {name="Blessing of High Isle", short="BHI", dynamic="passive"},
    {name="Bloodthorn's Touch", short="BST", dynamic="passive"},
    {name="Bog Raider", short="BR", dynamic="passive"},
    {name="Briarheart", short="B", dynamic="passive"},
    {name="Bright-Throat's Boast", short="BTSB", dynamic="passive"},
    {name="Call of the Undertaker", short="CU", dynamic="passive"},
    {name="Camonna Tong", short="CT", dynamic="passive"},
    {name="Champion of the Hist", short="CH", dynamic="passive"},
    {name="Crafty Alfiq", short="CA", dynamic="passive"},
    {name="Darkstride", short="D", dynamic="passive"},
    {name="Dead-Water's Guile", short="DWSG", dynamic="passive"},
    {name="Deadlands Assassin", short="DA", dynamic="passive"},
    {name="Death-Dancer", short="DD", dynamic="passive"},
    {name="Defiler", short="D", dynamic="passive"},
    {name="Dragonguard Elite", short="DE", dynamic="passive"},
    {name="Draugr's Heritage", short="DSH", dynamic="passive"},
    {name="Dreamer's Mantle", short="DSM", dynamic="passive"},
    {name="Eternal Vigor", short="EV", dynamic="passive"},
    {name="Eye of the Grasp", short="EG", dynamic="passive"},
    {name="Fiord's Legacy", short="FSL", dynamic="passive"},
    {name="Flanking Strategist", short="FS", dynamic="passive"},
    {name="Frostbite", short="F", dynamic="passive"},
    {name="Full Belly Barricade", short="FBB", dynamic="passive"},
    {name="Grace of Gloom", short="GG", dynamic="passive"},
    {name="Green Pact", short="GP", dynamic="passive"},
    {name="Gryphon's Ferocity", short="GSF", dynamic="passive"},
    {name="Hatchling's Shell", short="HSS", dynamic="passive"},
    {name="Hexos' Ward", short="HW", dynamic="passive"},
    {name="Hide of Morihaus", short="HM", dynamic="passive"},
    {name="Hide of the Werewolf", short="HW", dynamic="passive"},
    {name="Kynmarcher's Cruelty", short="KSC", dynamic="passive"},
    {name="Livewire", short="L", dynamic="passive"},
    {name="Macabre Vintage", short="MV", dynamic="passive"},
    {name="Mad Tinkerer", short="MT", dynamic="passive"},
    {name="Marauder's Haste", short="MSH", dynamic="passive"},
    {name="Mark of the Pariah", short="MP", dynamic="passive"},
    {name="Meridia's Blessed Armor", short="MSBA", dynamic="passive"},
    {name="Mother's Sorrow", short="MSS", dynamic="passive"},
    {name="Necropotence", short="N", dynamic="passive"},
    {name="Night Mother's Embrace", short="NMSE", dynamic="passive"},
    {name="Night Terror", short="NT", dynamic="passive"},
    {name="Order of Diagna", short="OD", dynamic="passive"},
    {name="Phoenix Moth Theurge", short="PMT", dynamic="passive"},
    {name="Plague Doctor", short="PD", dynamic="passive"},
    {name="Prisoner's Rags", short="PSR", dynamic="passive"},
    {name="Queen's Elegance", short="QSE", dynamic="passive"},
    {name="Radiant Bastion", short="RB", dynamic="passive"},
    {name="Ranger's Gait", short="RSG", dynamic="passive"},
    {name="Robes of the Hist", short="RH", dynamic="passive"},
    {name="Robes of the Withered Hand", short="RWH", dynamic="passive"},
    {name="Salvation", short="S", dynamic="passive"},
    {name="Senchal Defender", short="SD", dynamic="passive"},
    {name="Senche's Bite", short="SSB", dynamic="passive"},
    {name="Seventh Legion Brute", short="SLB", dynamic="passive"},
    {name="Shadow Dancer's Raiment", short="SDSR", dynamic="passive"},
    {name="Shadow of the Red Mountain", short="SRM", dynamic="passive"},
    {name="Shalk Exoskeleton", short="SE", dynamic="passive"},
    {name="Silks of the Sun", short="SS", dynamic="passive"},
    {name="Sithis' Touch", short="ST", dynamic="passive"},
    {name="Skooma Smuggler", short="SS", dynamic="passive"},
    {name="Soulshine", short="S", dynamic="passive"},
    {name="Spinner's Garments", short="SSG", dynamic="passive"},
    {name="Spriggan's Thorns", short="SST", dynamic="passive"},
    {name="Steadfast's Mettle", short="SSM", dynamic="passive"},
    {name="Stendarr's Embrace", short="SSE", dynamic="passive"},
    {name="Storm Knight's Plate", short="SKSP", dynamic="passive"},
    {name="Stygian", short="S", dynamic="passive"},
    {name="Swamp Raider", short="SR", dynamic="passive"},
    {name="Sword-Singer", short="SS", dynamic="passive"},
    {name="Symmetry of the Weald", short="SW", dynamic="passive"},
    {name="Syrabane's Grip", short="SSG", dynamic="passive"},
    {name="Systres' Scowl", short="SS", dynamic="passive"},
    {name="Syvarra's Scales", short="SSS", dynamic="passive"},
    {name="Three Queens Wellspring", short="TQW", dynamic="passive"},
    {name="Thunderbug's Carapace", short="TSC", dynamic="passive"},
    {name="Trinimac's Valor", short="TSV", dynamic="passive"},
    {name="Twin Sisters", short="TS", dynamic="passive"},
    {name="Unfathomable Darkness", short="UD", dynamic="passive"},
    {name="Vampire Cloak", short="VC", dynamic="passive"},
    {name="Vampire Lord", short="VL", dynamic="passive"},
    {name="Venomous Smite", short="VS", dynamic="passive"},
    {name="Vesture of Darloc Brae", short="VDB", dynamic="passive"},
    {name="Vivec's Duality", short="VSD", dynamic="passive"},
    {name="Voidcaller", short="V", dynamic="passive"},
    {name="War Maiden", short="WM", dynamic="passive"},
    {name="Warrior-Poet", short="WP", dynamic="passive"},
    {name="Way of Air", short="WA", dynamic="passive"},
    {name="Way of Fire", short="WF", dynamic="passive"},
    {name="Wilderqueen's Arch", short="WSA", dynamic="passive"},
    {name="Winter's Respite", short="WSR", dynamic="passive"},
    {name="Wisdom of Vanus", short="WV", dynamic="passive"},
    {name="Witch-Knight's Defiance", short="WKSD", dynamic="passive"},
    {name="Witchman Armor", short="WA", dynamic="passive"},
    {name="Wyrd Tree's Blessing", short="WTSB", dynamic="passive"},
    {name="Xanmeer Genesis", short="XG", dynamic="passive"},
    {name="Ysgramor's Birthright", short="YSB", dynamic="passive"},

    -- Other / special-acquisition sets.
    -- Includes Level Up Advisor rewards and retired sets still present in game data.
    {name="Armor of the Code",                    short="AOC",  dynamic="passive", needed=4},
    {name="Arms of Infernace",                    short="AOI",  dynamic="passive", needed=3},
    {name="Arms of the Ancestors",                short="AOA",  dynamic="passive", needed=3},
    {name="Broken Soul",                          short="BS",   dynamic="passive", needed=2},
    {name="Giant Spider",                         short="GS",   dynamic="passive", needed=2},
    {name="Prophet's",                            short="PRO",  dynamic="passive", needed=1},
    {name="Relics of the Physician, Ansur",       short="RPA",  dynamic="passive", needed=3},
    {name="Relics of the Rebellion",              short="RTR",  dynamic="passive", needed=3},
    {name="The Destruction Suite",                short="TDS",  dynamic="passive", needed=3},
    {name="Treasures of the Earthforge",          short="TEF",  dynamic="passive", needed=3},
}

local byAbility={}
for _,d in ipairs(TRACKED) do
    if d.abilityId then byAbility[d.abilityId]=d end
    if d.abilityIds then
        for _,abilityId in ipairs(d.abilityIds) do byAbility[abilityId]=d end
    end
end

local SLOTS={
    EQUIP_SLOT_HEAD,EQUIP_SLOT_NECK,EQUIP_SLOT_CHEST,EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_OFF_HAND,EQUIP_SLOT_WAIST,EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,EQUIP_SLOT_RING1,EQUIP_SLOT_RING2,EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_OFF,
}

local function EnsureSettings()
    local s=RyticTank.saved.sets
    if s.iconSize==nil then s.iconSize=36 end
    if s.spacing==nil then s.spacing=8 end
    if s.abbreviateNames==nil then s.abbreviateNames=false end
    if s.orientation==nil then s.orientation="HORIZONTAL" end
end

local function FindTracked(name,id)
    local lower=name and zo_strlower(name) or ""

    -- Master Architect: match by the distinctive name fragment rather than
    -- relying on a setId or exact localized item-set string.
    if string.find(lower,"architect",1,true) then
        for _,d in ipairs(TRACKED) do
            if d.name=="Master Architect" then return d end
        end
    end
    if string.find(lower,"yolnahkriin",1,true) then
        for _,d in ipairs(TRACKED) do
            if d.name=="Claw of Yolnahkriin" then return d end
        end
    end
    if string.find(lower,"alkosh",1,true) then
        for _,d in ipairs(TRACKED) do
            if d.name=="Roar of Alkosh" then return d end
        end
    end
    if string.find(lower,"puncturing remedy",1,true) then
        for _,d in ipairs(TRACKED) do
            if d.name=="Puncturing Remedy" then return d end
        end
    end
    if string.find(lower,"frozen watcher",1,true) then
        for _,d in ipairs(TRACKED) do
            if d.name=="Frozen Watcher" then return d end
        end
    end
    if string.find(lower,"pearlescent ward",1,true) then
        for _,d in ipairs(TRACKED) do
            if d.name=="Pearlescent Ward" then return d end
        end
    end
    if string.find(lower,"lucent echoes",1,true) then
        for _,d in ipairs(TRACKED) do
            if d.name=="Lucent Echoes" then return d end
        end
    end
    -- DPS / arena aliases. Keep perfected and normal variants distinct when ESO reports them.
    local dpsAliases={
        {"perfected slivers of the null arca","Perfected Slivers of the Null Arca"},
        {"slivers of the null arca","Slivers of the Null Arca"},
        {"spattering disjunction","Spattering Disjunction"},
        {"perfected spectral cloak","Perfected Spectral Cloak"},
        {"spectral cloak","Spectral Cloak"},
        {"perfected merciless charge","Merciless Charge"},
        {"merciless charge","Merciless Charge"},
    }
    for _,alias in ipairs(dpsAliases) do
        if string.find(lower,alias[1],1,true) then
            for _,d in ipairs(TRACKED) do
                if d.name==alias[2] then return d end
            end
        end
    end

    -- Support-set aliases, including perfected trial variants.
    local supportAliases={
        {"pillager's profit","Pillager's Profit"},
        {"pillagers profit","Pillager's Profit"},
        {"roaring opportunist","Roaring Opportunist"},
        {"martial knowledge","Way of Martial Knowledge"},
        {"symphony of blades","Symphony of Blades"},
        {"ozezan","Ozezan the Inferno"},
        {"jorvuld","Jorvuld's Guidance"},
        {"master architect","Master Architect"},
    }
    for _,alias in ipairs(supportAliases) do
        if string.find(lower,alias[1],1,true) then
            for _,d in ipairs(TRACKED) do
                if d.name==alias[2] then return d end
            end
        end
    end
    -- Generic tracked-name recognition. Also accept the common "Perfected " prefix
    -- without duplicating every class-set/mythic definition.
    local normalized=lower:gsub("^perfected%s+","")
    for _,d in ipairs(TRACKED) do
        local dn=zo_strlower(d.name or "")
        if (id and (id==d.setId or id==d.altSetId)) or
           (name and (lower==dn or normalized==dn)) then return d end
    end
end

local function Abbreviate(name)
    local words={}
    for word in string.gmatch(name or "","[%w']+") do
        if #words < 3 then table.insert(words,word) end
    end
    local s=""
    for _,word in ipairs(words) do s=s..string.sub(word,1,1) end
    return string.upper(s)
end

function Sets.Scan()
    local sets={}
    local activePair=GetActiveWeaponPairInfo()

    local function IsWeaponSlot(slot)
        return slot==EQUIP_SLOT_MAIN_HAND or slot==EQUIP_SLOT_OFF_HAND
            or slot==EQUIP_SLOT_BACKUP_MAIN or slot==EQUIP_SLOT_BACKUP_OFF
    end

    local function IsActiveWeaponSlot(slot)
        if activePair==ACTIVE_WEAPON_PAIR_MAIN then
            return slot==EQUIP_SLOT_MAIN_HAND or slot==EQUIP_SLOT_OFF_HAND
        elseif activePair==ACTIVE_WEAPON_PAIR_BACKUP then
            return slot==EQUIP_SLOT_BACKUP_MAIN or slot==EQUIP_SLOT_BACKUP_OFF
        end
        return false
    end

    local function PieceWeight(link,slot)
        if not IsWeaponSlot(slot) then return 1 end
        if not IsActiveWeaponSlot(slot) then return 0 end

        -- A two-handed weapon/staff supplies two set pieces.
        local equipType=GetItemLinkEquipType(link)
        if equipType==EQUIP_TYPE_TWO_HAND then return 2 end
        return 1
    end

    for _,slot in ipairs(SLOTS) do
        local link=GetItemLink(BAG_WORN,slot,LINK_STYLE_DEFAULT)
        if link and link~="" then
            -- We use the API here only for identity/name/setId.
            -- Piece count is calculated from the actual active equipment slots.
            local hasSet,setName,_,_,_,setId=GetItemLinkSetInfo(link,false)
            if hasSet and setName and setName~="" then
                local key=tostring(setId or 0)..":"..setName
                local row=sets[key]
                if not row then
                    local icon=GetItemLinkInfo(link)
                    local tracked=FindTracked(setName,setId)
                    row={
                        name=setName,
                        setId=setId,
                        pieces=0,
                        icon=icon or "",
                        tracked=tracked,
                        short=(tracked and tracked.short) or Abbreviate(setName),
                    }
                    sets[key]=row
                end
                row.pieces=row.pieces+PieceWeight(link,slot)
            end
        end
    end

    Sets.equipped=sets
end

local function CreateItem(parent)
    local wm=WM
    local c=wm:CreateControl(nil,parent,CT_CONTROL)

    local icon=wm:CreateControl(nil,c,CT_TEXTURE)
    icon:SetAnchor(TOP,c,TOP,0,0)
    c.icon=icon

    -- No square/card/background. The texture itself is the graphic.

    local statusShadow=wm:CreateControl(nil,c,CT_LABEL)
    statusShadow:SetFont("ZoFontGameBold")
    statusShadow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    statusShadow:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    statusShadow:SetColor(0,0,0,1)
    statusShadow:SetDrawLayer(DL_OVERLAY)
    c.statusShadow=statusShadow

    local status=wm:CreateControl(nil,c,CT_LABEL)
    status:SetFont("ZoFontGameBold")
    status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    status:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    status:SetDrawLayer(DL_OVERLAY)
    c.status=status

    local name=wm:CreateControl(nil,c,CT_LABEL)
    name:SetFont("ZoFontGameSmall")
    name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    name:SetColor(1,1,1,1)
    c.name=name

    local pieces=wm:CreateControl(nil,c,CT_LABEL)
    pieces:SetFont("ZoFontGameSmall")
    pieces:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    pieces:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    pieces:SetColor(.78,.78,.78,1)
    c.pieces=pieces

    return c
end

local function LayoutItem(c)
    EnsureSettings()
    local size=zo_clamp(tonumber(RyticTank.saved.sets.iconSize) or 36,24,64)
    local width=math.max(size+8,70)
    local nameH=17
    local pieceH=15
    local height=size+nameH+pieceH+3

    c:SetDimensions(width,height)

    c.icon:ClearAnchors()
    c.icon:SetDimensions(size,size)
    c.icon:SetAnchor(TOP,c,TOP,0,0)

    c.statusShadow:ClearAnchors()
    c.statusShadow:SetDimensions(size,size)
    c.statusShadow:SetAnchor(CENTER,c.icon,CENTER,1,1)

    c.status:ClearAnchors()
    c.status:SetDimensions(size,size)
    c.status:SetAnchor(CENTER,c.icon,CENTER,0,0)

    c.name:ClearAnchors()
    c.name:SetDimensions(width,nameH)
    c.name:SetAnchor(TOP,c.icon,BOTTOM,0,1)

    c.pieces:ClearAnchors()
    c.pieces:SetDimensions(width,pieceH)
    c.pieces:SetAnchor(TOP,c.name,BOTTOM,0,-1)

    return width,height
end

local function EnsureHUD()
    if Sets.window then return end
    local wm=WM
    local w=wm:CreateTopLevelWindow("RyticTankSetHUD")
    Sets.window=w
    Sets.hudFragment=RyticTank.UI.Attach(w,function()
        local settings=RyticTank.saved.sets
        return settings.enabled and not IsUnitDead("player") and
            (settings.preview or Sets.editMode or not settings.hideOutOfCombat or IsUnitInCombat("player"))
    end,function() Sets.Update() end)
    w:SetClampedToScreen(true)
    w:ClearAnchors()
    w:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,
        RyticTank.saved.sets.position.x,RyticTank.saved.sets.position.y)

    w:SetHandler("OnMoveStop",function()
        RyticTank.saved.sets.position.x=w:GetLeft()
        RyticTank.saved.sets.position.y=w:GetTop()
    end)

    Sets.ApplyLock()
end

function Sets.ApplyLock()
    if not Sets.window then return end
    local movable=not RyticTank.saved.sets.locked
    Sets.window:SetMovable(movable)
    Sets.window:SetMouseEnabled(movable)
end

function Sets.Rebuild()
    EnsureSettings(); EnsureHUD(); Sets.Scan()
    for _,c in ipairs(Sets.items) do c:SetHidden(true) end
    local names={}
    for name,_ in pairs(Sets.equipped) do table.insert(names,name) end
    table.sort(names)
    local x,y,maxW,maxH=0,0,1,1
    local gap=zo_clamp(tonumber(RyticTank.saved.sets.spacing) or 8,0,30)
    local vertical=RyticTank.saved.sets.orientation=="VERTICAL"
    for i,name in ipairs(names) do
        local e=Sets.equipped[name]
        local c=Sets.items[i]
        if not c then c=CreateItem(Sets.window); Sets.items[i]=c end
        local width,height=LayoutItem(c)
        c:ClearAnchors(); c:SetAnchor(TOPLEFT,Sets.window,TOPLEFT,x,y)
        c:SetHidden(false); c.data=e; c.icon:SetTexture(e.icon)
        c.name:SetText(RyticTank.saved.sets.abbreviateNames and e.short or ((e.tracked and e.tracked.displayName) or e.name))
        c.pieces:SetText("["..tostring(e.pieces).."]")
        if vertical then y=y+height+gap; maxW=math.max(maxW,width)
        else x=x+width+gap; maxH=math.max(maxH,height) end
    end
    if vertical then Sets.window:SetDimensions(maxW,math.max(1,y-gap))
    else Sets.window:SetDimensions(math.max(1,x-gap),maxH) end
    Sets.Update()
    if Sets.trackingRegistered and Sets.RefreshTracking then
        Sets.RefreshTracking()
    end
end

local function SetStatus(c,text,r,g,b)
    c.statusShadow:SetText(text)
    c.status:SetText(text)
    c.status:SetColor(r,g,b,1)
end

local function Ready(c)
    c.icon:SetAlpha(1)
    -- Green R centered on icon. No border/square.
    SetStatus(c,"R",0.1,1,0.15)
end

local function GetPlayerMajorSlayerRemaining()
    if not GetNumBuffs or not GetUnitBuffInfo then return 0 end
    local now=GetFrameTimeSeconds()
    local count=GetNumBuffs("player") or 0
    local best=0
    for i=1,count do
        local buffName,startTime,endTime=GetUnitBuffInfo("player",i)
        if buffName and zo_strlower(buffName)=="major slayer" then
            local remain=(tonumber(endTime) or 0)-now
            if remain>best then best=remain end
        end
    end
    return math.max(0,best)
end

local function Dynamic(c,d)
    c.icon:SetAlpha(1)
    -- Green K = live/dynamic set bonus (Pearl/Lucent), not a cooldown-ready state.
    SetStatus(c,"K",0.1,1,0.15)

    if d.dynamic=="masterslayer" then
        -- Master Architect has no internal cooldown. While its Major Slayer
        -- proc is live on the player, show the ACTUAL remaining Major Slayer
        -- duration from ESO. Otherwise K means the 5-piece is equipped/ready.
        local remain=GetPlayerMajorSlayerRemaining()
        if remain>0 then
            c.icon:SetAlpha(1)
            SetStatus(c,string.format("%.1f",remain),1,0.72,0.08)
        else
            SetStatus(c,"K",0.1,1,0.15)
        end
    elseif d.dynamic=="lucent" then
        -- ESO GetUnitPower supplies current/max values; avoid nonexistent GetUnitPowerMax.
        local hp,maxhp,effectiveMax=GetUnitPower("player",POWERTYPE_HEALTH)
        -- GetUnitPower already returns numbers; avoid calling tonumber here.
        -- This also prevents the scene-update crash seen when tonumber resolved nil.
        hp=hp or 0
        maxhp=effectiveMax or maxhp or 0
        local pct=maxhp>0 and (hp/maxhp)*100 or 100
        if pct>50 then c.pieces:SetText("[5] +11% CRIT")
        else c.pieces:SetText("[5] 20% DR") end
    elseif d.dynamic=="pearl" then
        local total=(type(GetGroupSize)=="function") and (GetGroupSize() or 0) or 0
        if total<=0 then total=1 end
        local alive=0
        if total==1 then
            alive=IsUnitDead("player") and 0 or 1
        else
            for i=1,total do
                local tag=(type(GetGroupUnitTagByIndex)=="function") and GetGroupUnitTagByIndex(i) or nil
                if tag and (type(DoesUnitExist)~="function" or DoesUnitExist(tag)) and not IsUnitDead(tag) then alive=alive+1 end
            end
        end
        -- Pearlescent Ward scales to 180 W/S Damage at 12 alive and 66% PvE DR at 12 dead.
        local alive12=math.min(12,alive)
        local dead12=math.max(0,12-alive12)
        local wd=math.floor((180*alive12/12)+0.5)
        local dr=66*dead12/12
        c.pieces:SetText(string.format("[%d/%d] +%d WD  %.1f%% DR",alive,total,wd,dr))
    end
end

local function Cooldown(c,remain)
    c.icon:SetAlpha(.62)
    local text
    if remain>=10 then text=string.format("%.0f",remain)
    else text=string.format("%.1f",remain) end
    SetStatus(c,text,1,.82,.25)
end

local function Active(c,remain)
    c.icon:SetAlpha(1)
    local text=remain>=10 and string.format("%.0f",remain) or string.format("%.1f",remain)
    SetStatus(c,text,0.1,1,0.15)
end

local function Normal(c)
    c.icon:SetAlpha(1)
    SetStatus(c,"",1,1,1)
end

function Sets.Update()
    local w=Sets.window
    if not w then return end
    if not RyticTank.UI.Refresh(w) then return end

    local now=GetGameTimeMilliseconds()
    for _,c in ipairs(Sets.items) do
        if not c:IsHidden() and c.data then
            local d=c.data.tracked
            if d then
                if d.cloakTimer then
                    local remain=((Sets.activeUntil[d.name] or 0)-now)/1000
                    if remain>0 then Active(c,remain) else Ready(c) end
                elseif d.dynamic then
                    local needed=d.needed or 5
                    if (c.data.pieces or 0)>=needed then Dynamic(c,d) else Normal(c) end
                elseif d.alkoshDebuff then
                    -- Alkosh is driven by the actual Roar of Alkosh target debuff (76667).
                    -- Every confirmed application/refresh supplies a fresh effect end time.
                    local remain=((Sets.activeUntil[d.name] or 0)-now)/1000
                    if remain>0 then Active(c,remain) else Ready(c) end
                elseif d.activeWindow then
                    local remain=((Sets.activeUntil[d.name] or 0)-now)/1000
                    if remain>0 then Active(c,remain) else Ready(c) end
                else
                    local remain=((Sets.cooldownEnd[d.name] or 0)-now)/1000
                    if remain>0 then Cooldown(c,remain) else Ready(c) end
                end
            else
                Normal(c)
            end
        end
    end
end

local function IsEquipped(d)
    for _,e in pairs(Sets.equipped) do
        if e.tracked==d then return true end
    end
    return false
end

local function StartCooldown(d)
    if not d or d.dynamic or not IsEquipped(d) then return end
    local now=GetGameTimeMilliseconds()
    if d.activeWindow then
        Sets.activeUntil[d.name]=now+d.activeWindow*1000
        return
    end
    if not d.cooldown then return end
    if (Sets.cooldownEnd[d.name] or 0)>now then return end
    Sets.cooldownEnd[d.name]=now+d.cooldown*1000
end

local function SupportNameEvent(eventCode,changeType,effectSlot,effectName,unitTag,
    beginTime,endTime,stackCount,iconName,buffType,effectType,abilityType,
    statusEffectType,unitName,unitId,abilityId,sourceType)
    if changeType~=EFFECT_RESULT_GAINED and changeType~=EFFECT_RESULT_UPDATED then return end
    local lower=zo_strlower(effectName or "")
    if lower=="" then return end
    for _,d in ipairs(Sets.activeSupportDefs or {}) do
        for _,pattern in ipairs(d.supportName) do
            if string.find(lower,pattern,1,true) then
                StartCooldown(d)
                return
            end
        end
    end
end

local function CombatEvent(eventCode,result,isError,abilityName,abilityGraphic,
    abilityActionSlotType,sourceName,sourceType,targetName,targetType,hitValue,
    powerType,damageType,log,sourceUnitId,targetUnitId,abilityId,overflow)
    local d=byAbility[abilityId]
    -- Alkosh's combat/damage packets are not the timer source. 76667's
    -- EVENT_EFFECT_CHANGED application is authoritative and can refresh early.
    if d and d.alkoshDebuff then return end
    StartCooldown(d)
end

local function EffectChanged(eventCode,changeType,effectSlot,effectName,unitTag,
    beginTime,endTime,stackCount,iconName,buffType,effectType,abilityType,
    statusEffectType,unitName,unitId,abilityId,sourceType)
    local d=byAbility[abilityId]
    if not d then return end

    if d.alkoshDebuff then
        if not IsEquipped(d) then return end
        if changeType==EFFECT_RESULT_GAINED or changeType==EFFECT_RESULT_UPDATED then
            -- ESO effect times use frame-time seconds; convert the reported end time
            -- into the millisecond clock used by the Sets UI. This means every real
            -- Alkosh reapplication resets the display from ESO's actual debuff timer.
            local remain=(endTime or 0)-GetFrameTimeSeconds()
            if remain<=0 then
                remain=((endTime or 0)-(beginTime or 0))
            end
            if remain>0 then
                Sets.activeUntil[d.name]=GetGameTimeMilliseconds()+(remain*1000)
            end
        elseif changeType==EFFECT_RESULT_FADED then
            Sets.activeUntil[d.name]=0
        end
        return
    end

    if changeType==EFFECT_RESULT_GAINED or changeType==EFFECT_RESULT_UPDATED then
        StartCooldown(d)
    end
end

-- Track Quick Cloak / Deadly Cloak / base Blade Cloak by the actual effect end time.
-- This makes Spectral Cloak's icon an actionable recast timer rather than showing its auto-refreshing 2s proc.
local function CloakEffectChanged(eventCode,changeType,effectSlot,effectName,unitTag,
    beginTime,endTime,stackCount,iconName,buffType,effectType,abilityType,
    statusEffectType,unitName,unitId,abilityId,sourceType)
    if unitTag~="player" then return end
    local lower=zo_strlower(effectName or "")
    if lower~="quick cloak" and lower~="deadly cloak" and lower~="blade cloak" then return end
    local nowMs=GetGameTimeMilliseconds()
    for _,d in ipairs(Sets.activeCloakDefs or {}) do
        if changeType==EFFECT_RESULT_GAINED or changeType==EFFECT_RESULT_UPDATED then
            local remain=math.max(0,(tonumber(endTime) or 0)-GetFrameTimeSeconds())
            Sets.activeUntil[d.name]=nowMs+(remain*1000)
        elseif changeType==EFFECT_RESULT_FADED then
            Sets.activeUntil[d.name]=0
        end
    end
end

-- Some proc-set effect IDs are not stable/publicly documented. For Null Arca and
-- Spattering, use the combat-event ability name only while one of those sets is equipped.
local function NamedProcCombatEvent(eventCode,result,isError,abilityName,abilityGraphic,
    abilityActionSlotType,sourceName,sourceType,targetName,targetType,hitValue,
    powerType,damageType,log,sourceUnitId,targetUnitId,abilityId,overflow)
    local lower=zo_strlower(abilityName or "")
    if lower=="" then return end
    for _,d in ipairs(Sets.activeNamedDefs or {}) do
        for _,pattern in ipairs(d.combatName) do
            if string.find(lower,pattern,1,true) then
                StartCooldown(d)
                return
            end
        end
    end
end

local function InventoryChanged()
    zo_callLater(Sets.Rebuild,100)
end

-- Settings hooks
function Sets.SetOrientation(v)
    EnsureSettings()
    RyticTank.saved.sets.orientation=(v=="VERTICAL") and "VERTICAL" or "HORIZONTAL"
    Sets.Rebuild()
end

function Sets.SetIconSize(v)
    EnsureSettings()
    RyticTank.saved.sets.iconSize=zo_clamp(tonumber(v) or 36,24,64)
    Sets.Rebuild()
end

function Sets.SetSpacing(v)
    EnsureSettings()
    RyticTank.saved.sets.spacing=zo_clamp(tonumber(v) or 8,0,30)
    Sets.Rebuild()
end

function Sets.SetAbbreviate(v)
    EnsureSettings()
    RyticTank.saved.sets.abbreviateNames=v and true or false
    Sets.Rebuild()
end

local function WeaponPairChanged(_, activeWeaponPair, locked)
    -- The event can fire during the swap's locked transition.
    -- Rebuild after the swap settles so numEquipped reflects the active bar.
    zo_callLater(function()
        if not RyticTank.saved.sets.enabled then return end
        Sets.Scan()
        Sets.Rebuild()
    end, 100)
end

local function UnregisterEquippedTracking()
    -- Only proc/effect listeners are cycled here. Inventory, weapon-pair and the
    -- lightweight HUD update remain registered while the Set HUD is enabled so
    -- an equipment change can immediately rebuild this list.
    for abilityId,_ in pairs(Sets.registeredAbilityIds or {}) do
        EM:UnregisterForEvent("RyticTankSetsCombat"..tostring(abilityId),EVENT_COMBAT_EVENT)
        EM:UnregisterForEvent("RyticTankSetsEffect"..tostring(abilityId),EVENT_EFFECT_CHANGED)
    end
    Sets.registeredAbilityIds={}
    Sets.activeSupportDefs={}
    Sets.activeCloakDefs={}
    Sets.activeNamedDefs={}
    EM:UnregisterForEvent("RyticTankSetsSupportEffects",EVENT_EFFECT_CHANGED)
    EM:UnregisterForEvent("RyticTankSetsCloakEffects",EVENT_EFFECT_CHANGED)
    EM:UnregisterForEvent("RyticTankSetsNamedProcs",EVENT_COMBAT_EVENT)
end

local function RegisterEquippedTracking()
    if not Sets.trackingRegistered then return end
    UnregisterEquippedTracking()

    local neededAbilities={}
    local needSupport=false
    local needCloak=false
    local needNamed=false

    -- Hot-event callbacks must never walk the full set catalog. Build tiny
    -- equipped-only lists whenever gear/bar state changes.
    Sets.activeSupportDefs={}
    Sets.activeCloakDefs={}
    Sets.activeNamedDefs={}

    -- IMPORTANT: TRACKED can grow to hundreds of known sets. We only inspect
    -- the few sets actually equipped here and register listeners for those.
    for _,e in pairs(Sets.equipped) do
        local d=e.tracked
        if d then
            if d.abilityId then neededAbilities[d.abilityId]=d end
            if d.abilityIds then
                for _,abilityId in ipairs(d.abilityIds) do neededAbilities[abilityId]=d end
            end
            if d.supportName then
                needSupport=true
                table.insert(Sets.activeSupportDefs,d)
            end
            if d.cloakTimer then
                needCloak=true
                table.insert(Sets.activeCloakDefs,d)
            end
            if d.combatName then
                needNamed=true
                table.insert(Sets.activeNamedDefs,d)
            end
        end
    end

    for abilityId,d in pairs(neededAbilities) do
        local combatName="RyticTankSetsCombat"..tostring(abilityId)
        EM:RegisterForEvent(combatName,EVENT_COMBAT_EVENT,CombatEvent)
        EM:AddFilterForEvent(
            combatName,EVENT_COMBAT_EVENT,
            REGISTER_FILTER_ABILITY_ID,abilityId,
            REGISTER_FILTER_IS_ERROR,false
        )

        if not d.combatOnly then
            local effectName="RyticTankSetsEffect"..tostring(abilityId)
            EM:RegisterForEvent(effectName,EVENT_EFFECT_CHANGED,EffectChanged)
            EM:AddFilterForEvent(
                effectName,EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_ABILITY_ID,abilityId
            )
        end
        Sets.registeredAbilityIds[abilityId]=true
    end

    if needSupport then
        EM:RegisterForEvent("RyticTankSetsSupportEffects",EVENT_EFFECT_CHANGED,SupportNameEvent)
        EM:AddFilterForEvent(
            "RyticTankSetsSupportEffects",EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER
        )
    end

    if needCloak then
        EM:RegisterForEvent("RyticTankSetsCloakEffects",EVENT_EFFECT_CHANGED,CloakEffectChanged)
        EM:AddFilterForEvent(
            "RyticTankSetsCloakEffects",EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_UNIT_TAG,"player"
        )
    end

    if needNamed then
        EM:RegisterForEvent("RyticTankSetsNamedProcs",EVENT_COMBAT_EVENT,NamedProcCombatEvent)
        EM:AddFilterForEvent(
            "RyticTankSetsNamedProcs",EVENT_COMBAT_EVENT,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER
        )
        EM:AddFilterForEvent(
            "RyticTankSetsNamedProcs",EVENT_COMBAT_EVENT,
            REGISTER_FILTER_IS_ERROR,false
        )
    end
end

function Sets.RefreshTracking()
    if not Sets.trackingRegistered then return end
    RegisterEquippedTracking()
end

function Sets.RegisterTracking()
    if Sets.trackingRegistered then
        Sets.RefreshTracking()
        return
    end

    -- Base listeners are the only always-on listeners while the Set HUD is
    -- enabled. Proc/effect listeners are registered ONLY for equipped sets.
    EM:RegisterForEvent("RyticTankSetsInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,InventoryChanged)
    EM:AddFilterForEvent(
        "RyticTankSetsInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID,BAG_WORN
    )

    EM:RegisterForEvent(
        "RyticTankSetsWeaponPair",
        EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
        WeaponPairChanged
    )

    EM:RegisterForUpdate("RyticTankSetsTimer",100,Sets.Update)
    Sets.trackingRegistered=true
    RegisterEquippedTracking()
end

function Sets.UnregisterTracking()
    if not Sets.trackingRegistered then return end
    UnregisterEquippedTracking()
    EM:UnregisterForEvent("RyticTankSetsInventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EM:UnregisterForEvent("RyticTankSetsWeaponPair",EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
    EM:UnregisterForUpdate("RyticTankSetsTimer")
    Sets.trackingRegistered=false
end

function Sets.SetEnabled(enabled)
    EnsureSettings()
    RyticTank.saved.sets.enabled=enabled and true or false

    if RyticTank.saved.sets.enabled then
        Sets.RegisterTracking()
        Sets.Scan()
        Sets.Rebuild()
        Sets.Update()
    else
        Sets.UnregisterTracking()
        if Sets.window then RyticTank.UI.Refresh(Sets.window) end
    end
end

function Sets.Initialize()
    if not RyticTank.saved.sets then
        RyticTank.saved.sets=ZO_DeepTableCopy(RyticTank.defaults.sets)
    end
    if not RyticTank.saved.sets.position then
        RyticTank.saved.sets.position={x=700,y=300}
    end

    EnsureSettings()
    EnsureHUD()
    Sets.Rebuild()

    if RyticTank.saved.sets.enabled then
        Sets.RegisterTracking()
    else
        Sets.UnregisterTracking()
        if Sets.window then RyticTank.UI.Refresh(Sets.window) end
    end

    SLASH_COMMANDS["/setmove"]=function()
        local hud=Sets.window
        if not hud then return end
        Sets.editMode=not Sets.editMode
        hud:SetMovable(Sets.editMode); hud:SetMouseEnabled(Sets.editMode); RyticTank.UI.Refresh(hud)
        if Sets.editMode then
            hud:SetHandler("OnMouseDown",function(_,button)
                if button==MOUSE_BUTTON_INDEX_LEFT then hud:StartMoving() end
            end)
            hud:SetHandler("OnMouseUp",function(_,button)
                if button==MOUSE_BUTTON_INDEX_LEFT then
                    hud:StopMovingOrResizing()
                    RyticTank.saved.sets.position.x=hud:GetLeft()
                    RyticTank.saved.sets.position.y=hud:GetTop()
                end
            end)
            d("|c55FF55RyticTankTools Set HUD MOVE MODE ON - drag it, then /setmove again.|r")
        else
            hud:SetHandler("OnMouseDown",nil); hud:SetHandler("OnMouseUp",nil)
            RyticTank.saved.sets.position.x=hud:GetLeft()
            RyticTank.saved.sets.position.y=hud:GetTop()
            d("|c55FF55RyticTankTools Set HUD position saved.|r")
        end
    end
end
