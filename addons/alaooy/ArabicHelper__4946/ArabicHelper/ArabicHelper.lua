-- كل الأدون يستخدم جدول عام واحد بس: ArabicHelper (ينعمل في arabic.lua)
ArabicHelper = ArabicHelper or {}
local AH = ArabicHelper

-- تعريف اسم الزر الذي سيظهر في إعدادات اللعبة
ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_ARABIC_HELPER", "Open/Close Arabic Helper")

local myWindow
local buffsWindow
local trialsWindow
local termsWindow
local currentCategory = ""
local favoritesMode = false
local selectedSetInfo = nil
local savedVars

-- ثوابت عامة
local str_format = string.format
local IMAGE_PATH = "ArabicHelper/images/%s.dds"
local function Img(fileName) return str_format(IMAGE_PATH, fileName) end

local CATEGORY = {
    DUNGEON   = "Dungeon",
    TRIAL     = "Trial",
    ARENA     = "Arena",
    CRAFTABLE = "craftable",
    PVP       = "PvP",
    MONSTER   = "Monster",
    MYTHIC    = "Mythic",
    ARCHIVE   = "Archive",
}
local CATEGORY_ORDER = {
    CATEGORY.DUNGEON, CATEGORY.TRIAL, CATEGORY.ARENA, CATEGORY.CRAFTABLE,
    CATEGORY.PVP, CATEGORY.MONSTER, CATEGORY.MYTHIC, CATEGORY.ARCHIVE,
}
AH.CATEGORY = CATEGORY -- لو احتجناها في ملف ثاني

-- أيقونات الشريط العلوي (من اللعبة نفسها)
-- up = عادي ، over = لما تأشر بالماوس ، down = مضغوط
-- لو أيقونة طلعت فاضية، غيّر المسار هنا بس
local TOP_ICONS = {
    house = {
        up   = "/esoui/art/collections/collections_tabicon_housing_up.dds",
        over = "/esoui/art/collections/collections_tabicon_housing_over.dds",
        down = "/esoui/art/collections/collections_tabicon_housing_down.dds",
    },
    fav = {
        up   = "/esoui/art/collections/favorite_staronly.dds",
        over = "/esoui/art/collections/favorite_staronly.dds",
        down = "/esoui/art/collections/favorite_staronly.dds",
    },
    buffs = {
        up   = "/esoui/art/mainmenu/menubar_skills_up.dds",
        over = "/esoui/art/mainmenu/menubar_skills_over.dds",
        down = "/esoui/art/mainmenu/menubar_skills_down.dds",
    },
    trial = {
        up   = "/esoui/art/lfg/lfg_indexicon_trial_up.dds",
        over = "/esoui/art/lfg/lfg_indexicon_trial_over.dds",
        down = "/esoui/art/lfg/lfg_indexicon_trial_down.dds",
    },
    terms = {
        up   = "/esoui/art/mainmenu/menubar_journal_up.dds",
        over = "/esoui/art/mainmenu/menubar_journal_over.dds",
        down = "/esoui/art/mainmenu/menubar_journal_down.dds",
    },
}

-- زر الإغلاق بنفس شكل اللعبة
local CLOSE_ICON = {
    up   = "/esoui/art/buttons/closebutton_up.dds",
    over = "/esoui/art/buttons/closebutton_mouseover.dds",
    down = "/esoui/art/buttons/closebutton_down.dds",
}

-- يركّب الأيقونة على الزر
local function ApplyIcon(btn, icon)
    btn:SetNormalTexture(icon.up)
    btn:SetMouseOverTexture(icon.over)
    btn:SetPressedTexture(icon.down)
end

-- إعدادات المفضلة المحفوظة على مستوى الحساب
local savedVarsDefaults = {
    favorites = {},
    showCard = true, -- بطاقة الست جنب وصف القطعة
}

-- قاعدة بيانات الستات
-- نستخدم رقم الست (setId) بدل اسمه، لأن الرقم ثابت بكل لغات اللعبة.
-- اسم الست نجيبه من اللعبة نفسها: GetItemSetName(setId)
-- كل سطر: { setId, "اسم ملف الصورة" }   (الصورة في ArabicHelper/images/)
local SETS_BY_CATEGORY = {
    [CATEGORY.DUNGEON] = {
        { 686, "set1" }, -- Abyssal Brace
        { 475, "set2" }, -- Aegis Caller
        { 258, "set3" }, -- Amber Plasm
        { 685, "set4" }, -- Apocryphal Inspiration
        { 518, "set5" }, -- Arkasis's Genius
        { 96, "set6" }, -- Armor of Truth
        { 260, "set7" }, -- Aspect of Mazzatun
        { 435, "set8" }, -- Auroran's Thunder
        { 456, "set9" }, -- Azureblight Reaper
        { 473, "set10" }, -- Bani's Torment
        { 28, "set11" }, -- Barkskin
        { 824, "set12" }, -- Black Foundry Steel
        { 732, "set13" }, -- Black-Glove Grounding
        { 735, "set14" }, -- Blind Path Induction
        { 400, "set15" }, -- Blood Moon
        { 339, "set16" }, -- Blooddrinker
        { 308, "set17" }, -- Bone Pirate's Tatters
        { 184, "set18" }, -- Brands of Imperium
        { 160, "set19" }, -- Burning Spellweave
        { 343, "set20" }, -- Caluurion's Legacy
        { 730, "set21" }, -- Cinders of Anthelmir
        { 194, "set22" }, -- Combat Physician
        { 602, "set23" }, -- Crimson Oath's Rive
        { 515, "set24" }, -- Crimson Twilight
        { 77, "set25" }, -- Crusader
        { 348, "set26" }, -- Curse of Doylemish
        { 573, "set27" }, -- Dagon's Dominion
        { 660, "set28" }, -- Deeproot Zeal
        { 457, "set29" }, -- Dragon's Defilement
        { 571, "set30" }, -- Drake's Rush
        { 307, "set31" }, -- Draugr Hulk
        { 335, "set32" }, -- Draugr's Rest
        { 474, "set33" }, -- Draugrkin's Grip
        { 61, "set34" }, -- Dreugh King Slayer
        { 453, "set35" }, -- Dro'Zakar's Claws
        { 102, "set36" }, -- Duneripper's Scales
        { 71, "set37" }, -- Durok's Bane
        { 122, "set38" }, -- Ebon Armory
        { 516, "set39" }, -- Elemental Catalyst
        { 158, "set40" }, -- Embershield
        { 198, "set41" }, -- Essence Thief
        { 338, "set42" }, -- Flame Blossom
        { 799, "set43" }, -- Fledgling's Nest
        { 574, "set44" }, -- Foolkiller's Ward
        { 433, "set45" }, -- Frozen Watcher
        { 621, "set46" }, -- Glacial Guardian
        { 261, "set47" }, -- Gossamer
        { 476, "set48" }, -- Grave Guardian
        { 664, "set49" }, -- Grave Inevitability
        { 607, "set50" }, -- Grisly Gourmet
        { 620, "set51" }, -- Gryphon's Reprisal
        { 340, "set52" }, -- Hagraven's Garden
        { 263, "set53" }, -- Hand of Mephala
        { 399, "set54" }, -- Hanu's Compassion
        { 401, "set55" }, -- Haven of Ursus
        { 259, "set56" }, -- Heem-Jas' Retribution
        { 798, "set57" }, -- Heroic Unity
        { 123, "set58" }, -- Hircine's Veneer
        { 471, "set59" }, -- Hiti's Hearth
        { 452, "set60" }, -- Hollowfang Thirst
        { 431, "set61" }, -- Icy Conjurer
        { 337, "set62" }, -- Ironblood
        { 295, "set63" }, -- Jailbreaker
        { 404, "set64" }, -- Jailer's Tenacity
        { 795, "set65" }, -- Jerensi's Bladestorm
        { 186, "set66" }, -- Jolting Arms
        { 346, "set67" }, -- Jorvuld's Guidance
        { 570, "set68" }, -- Kinras's Wrath
        { 309, "set69" }, -- Knight-Errant's Mail
        { 35, "set70" }, -- Knightmare
        { 517, "set71" }, -- Kraglen's Howl
        { 303, "set72" }, -- Lamia's Song
        { 196, "set73" }, -- Leeching Plate
        { 302, "set74" }, -- Leviathan
        { 298, "set75" }, -- Light Speaker
        { 796, "set76" }, -- Lucilla's Windshield
        { 822, "set77" }, -- Lustrous Soulwell
        { 103, "set78" }, -- Magicka Furnace
        { 619, "set79" }, -- Maligalig's Maelstrom
        { 304, "set80" }, -- Medusa
        { 429, "set81" }, -- Mighty Glacier
        { 402, "set82" }, -- Moon Hunter
        { 300, "set83" }, -- Netch's Touch
        { 72, "set84" }, -- Nikulas' Heavy Armor
        { 681, "set85" }, -- Nix-Hound's Howl
        { 46, "set86" }, -- Noble Duelist's Silks
        { 800, "set87" }, -- Noxious Boulder
        { 91, "set88" }, -- Oblivion's Edge
        { 193, "set89" }, -- Overwhelming Surge
        { 663, "set90" }, -- Pangrit Denmother
        { 665, "set91" }, -- Phylactery's Grasp
        { 336, "set92" }, -- Pillar of Nirn
        { 347, "set93" }, -- Plague Slinger
        { 55, "set94" }, -- Prayer Shawl
        { 662, "set95" }, -- Rage of the Ursauk
        { 311, "set96" }, -- Rattlecage
        { 737, "set97" }, -- Reflected Fury
        { 454, "set98" }, -- Renald's Resolve
        { 680, "set99" }, -- Ritemaster's Bond
        { 684, "set100" }, -- Runecarver's Blaze
        { 604, "set101" }, -- Rush of Agony
        { 110, "set102" }, -- Sanctuary
        { 403, "set103" }, -- Savage Werewolf
        { 190, "set104" }, -- Scathing Mage
        { 434, "set105" }, -- Scavenging Demise
        { 603, "set106" }, -- Scorion's Feast
        { 29, "set107" }, -- Sergeant's Mail
        { 195, "set108" }, -- Sheer Venom
        { 134, "set109" }, -- Shroud of the Lich
        { 605, "set110" }, -- Silver Rose Vigil
        { 731, "set111" }, -- Sluthrug's Hunger
        { 185, "set112" }, -- Spell Power Cure
        { 296, "set113" }, -- Spelunker
        { 297, "set114" }, -- Spider Cultist Cowl
        { 624, "set115" }, -- Spriggan's Vigor
        { 661, "set116" }, -- Stone's Accord
        { 827, "set117" }, -- Stonehulk Domination
        { 188, "set118" }, -- Storm Master
        { 623, "set119" }, -- Storm-Cursed's Revenge
        { 301, "set120" }, -- Strength of the Automaton
        { 159, "set121" }, -- Sunderflame
        { 310, "set122" }, -- Sword Dancer
        { 513, "set123" }, -- Talfyg's Treachery
        { 736, "set124" }, -- Tarnished Nightmare
        { 682, "set125" }, -- Telvanni Enforcer
        { 53, "set126" }, -- The Ice Furnace
        { 124, "set127" }, -- The Worm's Raiment
        { 606, "set128" }, -- Thunder Caller
        { 472, "set129" }, -- Titanborn Strength
        { 826, "set130" }, -- Tools of the Trapmaster
        { 299, "set131" }, -- Toothrow
        { 197, "set132" }, -- Tormentor
        { 344, "set133" }, -- Trappings of Invigoration
        { 305, "set134" }, -- Treasure Hunter
        { 569, "set135" }, -- True-Sworn Fury
        { 622, "set136" }, -- Turning Tide
        { 430, "set137" }, -- Tzogvin's Warband
        { 345, "set138" }, -- Ulfnor's Favor
        { 155, "set139" }, -- Undaunted Bastion
        { 156, "set140" }, -- Undaunted Infiltrator
        { 157, "set141" }, -- Undaunted Unweaver
        { 572, "set142" }, -- Unleashed Ritualist
        { 514, "set143" }, -- Unleashed Terror
        { 794, "set144" }, -- Vandorallen's Resonance
        { 19, "set145" }, -- Vestments of the Warlock
        { 33, "set146" }, -- Viper's Sting
        { 823, "set147" }, -- Vykand's Soulfury
        { 262, "set148" }, -- Widowmaker
        { 825, "set149" }, -- Xanmeer Spellweaver
        { 455, "set150" }, -- Z'en's Redress
    },
    [CATEGORY.TRIAL] = {
        { 392, "tril1" }, -- Perfected Aegis of Galenwe
        { 707, "tril2" }, -- Perfected Ansuul's Torment
        { 393, "tril3" }, -- Perfected Arms of Relequen
        { 591, "tril4" }, -- Perfected Bahsei's Mania
        { 359, "tril5" }, -- Perfected Chaotic Whirlwind
        { 451, "tril6" }, -- Perfected Claw of Yolnahkriin
        { 361, "tril7" }, -- Perfected Concentrated Force
        { 652, "tril8" }, -- Perfected Coral Riptide
        { 358, "tril9" }, -- Perfected Defensive Position
        { 357, "tril10" }, -- Perfected Disciplined Slash
        { 819, "tril11" }, -- Perfected Dolorous Arena
        { 448, "tril12" }, -- Perfected Eye of Nahviintaas
        { 449, "tril13" }, -- Perfected False God's Devotion
        { 821, "tril14" }, -- Perfected Harmony in Chaos
        { 820, "tril15" }, -- Perfected Kazpian's Cruel Signet
        { 493, "tril16" }, -- Perfected Kyne's Wind
        { 771, "tril17" }, -- Perfected Lucent Echoes
        { 394, "tril18" }, -- Perfected Mantle of Siroria
        { 773, "tril19" }, -- Perfected Mora Scribe's Thesis
        { 708, "tril20" }, -- Perfected Peace and Serenity
        { 651, "tril21" }, -- Perfected Pearlescent Ward
        { 360, "tril22" }, -- Perfected Piercing Spray
        { 650, "tril23" }, -- Perfected Pillager's Profit
        { 818, "tril24" }, -- Perfected Recovery Convergence
        { 497, "tril25" }, -- Perfected Roaring Opportunist
        { 589, "tril26" }, -- Perfected Saxhleel Champion
        { 772, "tril27" }, -- Perfected Slivers of the Null Arca
        { 592, "tril28" }, -- Perfected Stone-Talker's Oath
        { 590, "tril29" }, -- Perfected Sul-Xan's Torment
        { 706, "tril30" }, -- Perfected Test of Resolve
        { 362, "tril31" }, -- Perfected Timeless Blessing
        { 450, "tril32" }, -- Perfected Tooth of Lokkestiiz
        { 705, "tril33" }, -- Perfected Transformative Hope
        { 395, "tril34" }, -- Perfected Vestment of Olorime
        { 495, "tril35" }, -- Perfected Vrol's Command
        { 653, "tril36" }, -- Perfected Whorl of the Depths
        { 770, "tril37" }, -- Perfected Xoryn's Masterpiece
        { 499, "tril38" }, -- Perfected Yandir's Might
        { 138, "tril39" }, -- Defending Warrior
        { 141, "tril40" }, -- Healing Mage
        { 142, "tril41" }, -- Quick Serpent
        { 137, "tril42" }, -- Berserking Warrior
        { 140, "tril43" }, -- Destructive Mage
        { 143, "tril44" }, -- Poisonous Serpent
        { 136, "tril45" }, -- Immortal Warrior
        { 144, "tril46" }, -- Twice-Fanged Serpent
        { 139, "tril47" }, -- Wise Mage
        { 231, "tril48" }, -- Lunar Bastion
        { 230, "tril49" }, -- Moondancer
        { 232, "tril50" }, -- Roar of Alkosh
        { 229, "tril51" }, -- Twilight Remedy
        { 330, "tril52" }, -- Automated Defense
        { 333, "tril53" }, -- Inventor's Guard
        { 332, "tril54" }, -- Master Architect
        { 331, "tril55" }, -- War Machine
        { 171, "tril56" }, -- Eternal Warrior
        { 172, "tril57" }, -- Infallible Mage
        { 173, "tril58" }, -- Vicious Serpent
    },
    [CATEGORY.ARENA] = {
        { 531, "ar1" }, -- Perfected Caustic Arrow
        { 524, "ar2" }, -- Perfected Cruel Flurry
        { 526, "ar3" }, -- Perfected Crushing Wall
        { 532, "ar4" }, -- Perfected Destructive Impact
        { 563, "ar5" }, -- Perfected Executioner's Blade
        { 568, "ar6" }, -- Perfected Force Overflow
        { 565, "ar7" }, -- Perfected Frenzied Momentum
        { 423, "ar8" }, -- Perfected Gallant Charge
        { 533, "ar9" }, -- Perfected Grand Rejuvenation
        { 428, "ar10" }, -- Perfected Mender's Ward
        { 522, "ar11" }, -- Perfected Merciless Charge
        { 566, "ar12" }, -- Perfected Point-Blank Snipe
        { 527, "ar13" }, -- Perfected Precise Regeneration
        { 529, "ar14" }, -- Perfected Puncturing Remedy
        { 424, "ar15" }, -- Perfected Radial Uppercut
        { 523, "ar16" }, -- Perfected Rampaging Slash
        { 425, "ar17" }, -- Perfected Spectral Cloak
        { 530, "ar18" }, -- Perfected Stinging Slashes
        { 525, "ar19" }, -- Perfected Thunderous Volley
        { 528, "ar20" }, -- Perfected Titanic Cleave
        { 426, "ar21" }, -- Perfected Virulent Shot
        { 564, "ar22" }, -- Perfected Void Bash
        { 427, "ar23" }, -- Perfected Wild Impulse
        { 567, "ar24" }, -- Perfected Wrath of Elements
    },
    [CATEGORY.CRAFTABLE] = {
        { 385, "cr1" }, -- Adept Rider
        { 541, "cr2" }, -- Aetherial Ascension
        { 82, "cr3" }, -- Alessia's Bulwark
        { 469, "cr4" }, -- Ancient Dragonguard
        { 178, "cr5" }, -- Armor Master
        { 43, "cr6" }, -- Armor of the Seducer
        { 54, "cr7" }, -- Ashen Grip
        { 323, "cr8" }, -- Assassin's Guile
        { 677, "cr9" }, -- Chimera's Rebuke
        { 679, "cr10" }, -- Claw of the Forest Wraith
        { 225, "cr11" }, -- Clever Alchemist
        { 437, "cr12" }, -- Coldharbour's Favorite
        { 480, "cr13" }, -- Critical Riposte
        { 324, "cr14" }, -- Daedric Trickery
        { 468, "cr15" }, -- Daring Corsair
        { 482, "cr16" }, -- Dauntless Combatant
        { 611, "cr17" }, -- Deadlands Demolisher
        { 37, "cr18" }, -- Death's Wind
        { 584, "cr19" }, -- Diamond's Victory
        { 491, "cr20" }, -- Dragon's Appetite
        { 642, "cr21" }, -- Druid's Braid
        { 226, "cr22" }, -- Eternal Hunt
        { 87, "cr23" }, -- Eyes of Mara
        { 810, "cr24" }, -- Fellowship's Fortitude
        { 352, "cr25" }, -- Fortified Brass
        { 408, "cr26" }, -- Grave-Stake Collector
        { 583, "cr27" }, -- Heartland Conqueror
        { 764, "cr28" }, -- Highland Sentinel
        { 78, "cr29" }, -- Hist Bark
        { 582, "cr30" }, -- Hist Whisperer
        { 80, "cr31" }, -- Hunding's Rage
        { 351, "cr32" }, -- Innate Axiom
        { 612, "cr33" }, -- Iron Flask
        { 92, "cr34" }, -- Kagrenac's Hope
        { 240, "cr35" }, -- Kvatch Gladiator
        { 207, "cr36" }, -- Law of Julianos
        { 540, "cr37" }, -- Legacy of Karth
        { 48, "cr38" }, -- Magnus' Gift
        { 353, "cr39" }, -- Mechanical Acuity
        { 410, "cr40" }, -- Might of the Lost Legion
        { 219, "cr41" }, -- Morkuldin
        { 409, "cr42" }, -- Naga Shaman
        { 470, "cr43" }, -- New Moon Acolyte
        { 51, "cr44" }, -- Night Mother's Gaze
        { 40, "cr45" }, -- Night's Silence
        { 176, "cr46" }, -- Noble's Conquest
        { 387, "cr47" }, -- Nocturnal's Favor
        { 73, "cr48" }, -- Oblivion's Foe
        { 678, "cr49" }, -- Old Growth Brewer
        { 640, "cr50" }, -- Order's Wrath
        { 84, "cr51" }, -- Orgnum's Scales
        { 242, "cr52" }, -- Pelinal's Wrath
        { 539, "cr53" }, -- Red Eagle's Fury
        { 177, "cr54" }, -- Redistributor
        { 697, "cr55" }, -- Seeker Synthesis
        { 438, "cr56" }, -- Senche-Raht's Grit
        { 641, "cr57" }, -- Serpent's Disdain
        { 325, "cr58" }, -- Shacklebreaker
        { 95, "cr59" }, -- Shalidor's Curse
        { 808, "cr60" }, -- Shared Burden
        { 695, "cr61" }, -- Shattered Fate
        { 386, "cr62" }, -- Sload's Semblance
        { 81, "cr63" }, -- Song of Lamae
        { 74, "cr64" }, -- Spectre's Eye
        { 506, "cr65" }, -- Spell Parasite
        { 490, "cr66" }, -- Stuhn's Favor
        { 224, "cr67" }, -- Tava's Favor
        { 696, "cr68" }, -- Telvanni Efficiency
        { 763, "cr69" }, -- Tharriker's Strike
        { 765, "cr70" }, -- Threads of War
        { 809, "cr71" }, -- Tide-Born Wildstalker
        { 75, "cr72" }, -- Torug's Pact
        { 208, "cr73" }, -- Trial by Fire
        { 161, "cr74" }, -- Twice-Born Star
        { 38, "cr75" }, -- Twilight's Embrace
        { 481, "cr76" }, -- Unchained Aggressor
        { 44, "cr77" }, -- Vampire's Kiss
        { 241, "cr78" }, -- Varen's Legacy
        { 439, "cr79" }, -- Vastarie's Tutelage
        { 148, "cr80" }, -- Way of the Arena
        { 41, "cr81" }, -- Whitestrake's Retribution
        { 79, "cr82" }, -- Willow's Path
        { 610, "cr83" }, -- Wretched Vitality
    },
    [CATEGORY.PVP] = {
        { 101, "pvp1" }, -- Affliction
        { 206, "pvp2" }, -- Agility
        { 39, "pvp3" }, -- Alessian Order
        { 85, "pvp4" }, -- Almalexia's Mercy
        { 802, "pvp5" }, -- Arkay's Charity
        { 756, "pvp6" }, -- Baan Dar's Blessing
        { 131, "pvp7" }, -- Bastion of the Heartland
        { 422, "pvp8" }, -- Battalion Defender
        { 419, "pvp9" }, -- Battlefield Acrobat
        { 52, "pvp10" }, -- Beckoning Steel
        { 179, "pvp11" }, -- Black Rose
        { 804, "pvp12" }, -- Blackfeather Flight
        { 128, "pvp13" }, -- Blessing of the Potentates
        { 755, "pvp14" }, -- Blunted Blades
        { 133, "pvp15" }, -- Buffer of the Swift
        { 791, "pvp16" }, -- Bulwark Ruination
        { 711, "pvp17" }, -- Colovian Highlands General
        { 831, "pvp18" }, -- Coup De Grâce
        { 327, "pvp19" }, -- Coward's Gear
        { 113, "pvp20" }, -- Crest of Cyrodiil
        { 104, "pvp21" }, -- Curse Eater
        { 616, "pvp22" }, -- Dark Convergence
        { 127, "pvp23" }, -- Deadly Strike
        { 25, "pvp24" }, -- Desert Rose
        { 130, "pvp25" }, -- Eagle Eye
        { 83, "pvp26" }, -- Elf Bane
        { 204, "pvp27" }, -- Endurance
        { 631, "pvp28" }, -- Enervating Aura
        { 792, "pvp29" }, -- Farstrider
        { 238, "pvp30" }, -- Fasalla's Guile
        { 246, "pvp31" }, -- Galerion's Revenge
        { 855, "pvp32" }, -- Gorethief
        { 126, "pvp33" }, -- Grace of the Ancients
        { 100, "pvp34" }, -- Hawk's Eye
        { 630, "pvp35" }, -- Hew and Sunder
        { 618, "pvp36" }, -- Hrothgar's Chill
        { 253, "pvp37" }, -- Imperial Physique
        { 334, "pvp38" }, -- Impregnable Armor
        { 417, "pvp39" }, -- Indomitable Fury
        { 712, "pvp40" }, -- Jerall Mountains Warchief
        { 690, "pvp41" }, -- Judgment of Akatosh
        { 328, "pvp42" }, -- Knight Slayer
        { 59, "pvp43" }, -- Kyne's Kiss
        { 803, "pvp44" }, -- Lamp Knight's Art
        { 668, "pvp45" }, -- Languor of Peryite
        { 237, "pvp46" }, -- Leki's Focus
        { 109, "pvp47" }, -- Light of Cyrodiil
        { 670, "pvp48" }, -- Mara's Balm
        { 234, "pvp49" }, -- Marksman's Crest
        { 181, "pvp50" }, -- Meritorious Service
        { 793, "pvp51" }, -- Netch Oil
        { 713, "pvp52" }, -- Nibenay Bay Battlereeve
        { 669, "pvp53" }, -- Nocturnal's Ploy
        { 754, "pvp54" }, -- Oakfather's Retribution
        { 200, "pvp55" }, -- Phoenix
        { 617, "pvp56" }, -- Plaguebreak
        { 180, "pvp57" }, -- Powerful Assault
        { 629, "pvp58" }, -- Rallying Cry
        { 108, "pvp59" }, -- Ravager
        { 201, "pvp60" }, -- Reactive Armor
        { 76, "pvp61" }, -- Robes of Alteration Mastery
        { 235, "pvp62" }, -- Robes of Transmutation
        { 89, "pvp63" }, -- Sentry
        { 67, "pvp64" }, -- Shadow Walker
        { 783, "pvp65" }, -- Shared Pain
        { 689, "pvp66" }, -- Shell Splitter
        { 199, "pvp67" }, -- Shield Breaker
        { 132, "pvp68" }, -- Shield of the Valiant
        { 784, "pvp69" }, -- Siegemaster's Focus
        { 688, "pvp70" }, -- Snake in the Stars
        { 420, "pvp71" }, -- Soldier of Anguish
        { 418, "pvp72" }, -- Spell Strategist
        { 830, "pvp73" }, -- Spellshredder
        { 421, "pvp74" }, -- Steadfast Hero
        { 97, "pvp75" }, -- The Arch-Mage
        { 63, "pvp76" }, -- The Juggernaut
        { 50, "pvp77" }, -- The Morag Tong
        { 248, "pvp78" }, -- Thews of the Harbinger
        { 782, "pvp79" }, -- Tracker's Lash
        { 832, "pvp80" }, -- Unflinching Ultimate
        { 326, "pvp81" }, -- Vanguard's Challenge
        { 129, "pvp82" }, -- Vengeance Leech
        { 247, "pvp83" }, -- Vicecanon of Venom
        { 236, "pvp84" }, -- Vicious Death
        { 111, "pvp85" }, -- Ward of Cyrodiil
        { 239, "pvp86" }, -- Warrior's Fury
        { 205, "pvp87" }, -- Willpower
        { 329, "pvp88" }, -- Wizard's Riposte
        { 125, "pvp89" }, -- Wrath of the Imperium
    },
    [CATEGORY.MONSTER] = {
        { 734, "mo1" }, -- Anthelmir's Construct
        { 666, "mo2" }, -- Archdruid Devyric
        { 397, "mo3" }, -- Balorgh
        { 829, "mo4" }, -- Bar-Sakka
        { 636, "mo5" }, -- Baron Thirsk
        { 578, "mo6" }, -- Baron Zaudrus
        { 828, "mo7" }, -- Black Gem Monstrosity
        { 163, "mo8" }, -- Bloodspawn
        { 269, "mo9" }, -- Chokethorn
        { 342, "mo10" }, -- Domihaus
        { 341, "mo11" }, -- Earthgore
        { 577, "mo12" }, -- Encratis's Behemoth
        { 166, "mo13" }, -- Engine Guardian
        { 667, "mo14" }, -- Euphotic Gatekeeper
        { 849, "mo15" }, -- Glittering Goad
        { 600, "mo16" }, -- Glorgoloch the Destroyer
        { 280, "mo17" }, -- Grothdarr
        { 458, "mo18" }, -- Grundwulf
        { 274, "mo19" }, -- Iceheart
        { 273, "mo20" }, -- Ilambris
        { 599, "mo21" }, -- Immolator Charr
        { 272, "mo22" }, -- Infernal Guardian
        { 632, "mo23" }, -- Kargaeda
        { 479, "mo24" }, -- Kjalnar's Nightmare
        { 266, "mo25" }, -- Kra'gh
        { 635, "mo26" }, -- Lady Malygda
        { 535, "mo27" }, -- Lady Thorn
        { 164, "mo28" }, -- Lord Warden
        { 459, "mo29" }, -- Maarselok
        { 609, "mo30" }, -- Magma Incarnate
        { 170, "mo31" }, -- Maw of the Infernal
        { 256, "mo32" }, -- Mighty Chudan
        { 183, "mo33" }, -- Molag Kena
        { 478, "mo34" }, -- Mother Ciannait
        { 633, "mo35" }, -- Nazaray
        { 168, "mo36" }, -- Nerien'eth
        { 167, "mo37" }, -- Nightflame
        { 634, "mo38" }, -- Nunatak
        { 801, "mo39" }, -- Orpheon the Tactician
        { 687, "mo40" }, -- Ozezan the Inferno
        { 277, "mo41" }, -- Pirate Skeleton
        { 608, "mo42" }, -- Prior Thierric
        { 683, "mo43" }, -- Roksa the Warped
        { 165, "mo44" }, -- Scourge Harvester
        { 279, "mo45" }, -- Selene
        { 271, "mo46" }, -- Sellistrix
        { 268, "mo47" }, -- Sentinel of Rkugamz
        { 265, "mo48" }, -- Shadowrend
        { 270, "mo49" }, -- Slimecraw
        { 162, "mo50" }, -- Spawn of Mephala
        { 797, "mo51" }, -- Squall of Retribution
        { 534, "mo52" }, -- Stone Husk
        { 432, "mo53" }, -- Stonekeeper
        { 275, "mo54" }, -- Stormfist
        { 267, "mo55" }, -- Swarm Mother
        { 436, "mo56" }, -- Symphony of Blades
        { 738, "mo57" }, -- The Blind
        { 851, "mo58" }, -- The Ruckus
        { 278, "mo59" }, -- The Troll King
        { 850, "mo60" }, -- Thousand Eyes
        { 349, "mo61" }, -- Thurvokun
        { 276, "mo62" }, -- Tremorscale
        { 169, "mo63" }, -- Valkyn Skoria
        { 257, "mo64" }, -- Velidreth
        { 398, "mo65" }, -- Vykosa
        { 350, "mo66" }, -- Zaan
        { 598, "mo67" }, -- Zoal the Ever-Wakeful
        { 876, "mo68" }, -- Tarcyr
        { 877, "mo69" }, -- Mylenne Moon-Caller
    },
    [CATEGORY.MYTHIC] = {
        { 626, "my1" }, -- Belharza's Band
        { 521, "my2" }, -- Bloodlord's Embrace
        { 691, "my3" }, -- Cryptcanon Vestments
        { 596, "my4" }, -- Death Dealer's Fete
        { 655, "my5" }, -- Dov-Rha Sabatons
        { 692, "my6" }, -- Esoteric Environment Greaves
        { 674, "my7" }, -- Faun's Lark Cladding
        { 593, "my8" }, -- Gaze of Sithis
        { 594, "my9" }, -- Harpooner's Wading Kilt
        { 845, "my10" }, -- Huntsman's Warmask
        { 656, "my11" }, -- Lefthander's Aegis Belt
        { 811, "my12" }, -- Mad God's Dancing Shoes
        { 520, "my13" }, -- Malacath's Band of Brutality
        { 625, "my14" }, -- Markyn Ring of Majesty
        { 813, "my15" }, -- Monomyth Reforged
        { 654, "my16" }, -- Mora's Whispers
        { 658, "my17" }, -- Oakensoul Ring
        { 576, "my18" }, -- Pearls of Ehlnofey
        { 854, "my19" }, -- Prowler's Talisman
        { 812, "my20" }, -- Rakkhat's Voidmantle
        { 575, "my21" }, -- Ring of the Pale Order
        { 503, "my22" }, -- Ring of the Wild Hunt
        { 760, "my23" }, -- Rourken Steamguards
        { 657, "my24" }, -- Sea-Serpent's Coil
        { 597, "my25" }, -- Shapeshifter's Chain
        { 848, "my26" }, -- Shattered Paths Signet
        { 519, "my27" }, -- Snow Treaders
        { 627, "my28" }, -- Spaulder of Ruin
        { 675, "my29" }, -- Stormweaver's Cavort
        { 676, "my30" }, -- Syrabane's Ward
        { 762, "my31" }, -- The Saint and the Seducer
        { 761, "my32" }, -- The Shadow Queen's Cowl
        { 501, "my33" }, -- Thrassian Stranglers
        { 505, "my34" }, -- Torc of Tonal Constancy
        { 693, "my35" }, -- Torc of the Last Ayleid King
        { 694, "my36" }, -- Velothi Ur-Mage's Amulet
    },
    [CATEGORY.ARCHIVE] = {
        { 781, "ia1" }, -- Aerie's Cry
        { 780, "ia2" }, -- Aetheric Lancer
        { 723, "ia3" }, -- Basalt-Blooded Warrior
        { 779, "ia4" }, -- Beacon of Oblivion
        { 777, "ia5" }, -- Corpseburster
        { 729, "ia6" }, -- Gardener of Seasons
        { 727, "ia7" }, -- Monolith of Storms
        { 724, "ia8" }, -- Nobility in Decay
        { 776, "ia9" }, -- Pyrebrand
        { 722, "ia10" }, -- Reawakened Hierophant
        { 726, "ia11" }, -- Soulcleaver
        { 775, "ia12" }, -- Spattering Disjunction
        { 778, "ia13" }, -- Umbral Edge
        { 728, "ia14" }, -- Wrathsun
    },
}

-- ستات جديدة رقمها لسا ما انضاف (نلقاها بالاسم الإنجليزي لين نضيف الرقم)
local SETS_PENDING = {
}

local setsDatabase = {} -- يتعبّى في BuildSetsDatabase()

-- اسم الست بلغة اللاعب (من اللعبة)
local function SetDisplayName(setId)
    local name = GetItemSetName(setId)
    if not name or name == "" then return nil end
    return zo_strformat("<<1>>", name)
end

-- نلقى رقم الست الجديد من اسمه الإنجليزي (يشتغل بس لو اللعبة إنجليزي)
local function FindSetIdByEnglishName(englishName)
    local wanted = string.lower(englishName)
    for setId = 1, 1500 do
        local name = GetItemSetName(setId)
        if name and name ~= "" and string.lower(zo_strformat("<<1>>", name)) == wanted then
            return setId
        end
    end
    return nil
end

local function BuildSetsDatabase()
    local byCategory = {}
    for _, category in ipairs(CATEGORY_ORDER) do
        local list = {}
        for _, entry in ipairs(SETS_BY_CATEGORY[category] or {}) do
            local setId, image = entry[1], entry[2]
            local name = SetDisplayName(setId)
            if name then
                list[#list + 1] = { setId = setId, name = name, icon = Img(image), category = category }
            end
        end
        byCategory[category] = list
    end
    for _, pending in ipairs(SETS_PENDING) do
        local setId = FindSetIdByEnglishName(pending.name)
        local list = byCategory[pending.category]
        if setId and list then
            list[#list + 1] = { setId = setId, name = SetDisplayName(setId), icon = Img(pending.image), category = pending.category }
        end
    end
    for _, category in ipairs(CATEGORY_ORDER) do
        local list = byCategory[category]
        table.sort(list, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
        for _, info in ipairs(list) do
            setsDatabase[#setsDatabase + 1] = info
        end
    end
end

-- المفضلة القديمة كانت محفوظة بالاسم، الحين بالرقم
local function MigrateFavorites(favorites)
    if type(favorites) ~= "table" then return end
    local byName = {}
    for _, info in ipairs(setsDatabase) do byName[string.lower(info.name)] = info.setId end
    for key, value in pairs(favorites) do
        if type(key) == "string" then
            favorites[key] = nil
            local setId = byName[string.lower(key)]
            if setId and value then favorites[setId] = true end
        end
    end
end

-- قاعدة بيانات البفات والديبفات 
local buffsDatabase = {
    -- ===== قسم البفات (Buffs) =====
    { nameEn = "Aegis", icon = Img("buff1"), type = "Buff" },
    { nameEn = "Berserk", icon = Img("buff2"), type = "Buff" },
    { nameEn = "Brutality", icon = Img("buff3"), type = "Buff" },
    { nameEn = "Courage", icon = Img("buff4"), type = "Buff" },
    { nameEn = "Empower", icon = Img("buff5"), type = "Buff" },
    { nameEn = "Endurance", icon = Img("buff6"), type = "Buff" },
    { nameEn = "Evasion", icon = Img("buff7"), type = "Buff" },
    { nameEn = "Expedition", icon = Img("buff8"), type = "Buff" },
    { nameEn = "Force", icon = Img("buff9"), type = "Buff" },
    { nameEn = "Fortitude", icon = Img("buff10"), type = "Buff" },
    { nameEn = "Gallop", icon = Img("buff11"), type = "Buff" },
    { nameEn = "Heroism", icon = Img("buff12"), type = "Buff" },
    { nameEn = "Intellect", icon = Img("buff13"), type = "Buff" },
    { nameEn = "Mending", icon = Img("buff14"), type = "Buff" },
    { nameEn = "Resolve", icon = Img("buff15"), type = "Buff" },
    { nameEn = "Prophecy", icon = Img("buff16"), type = "Buff" },
    { nameEn = "Protection", icon = Img("buff17"), type = "Buff" },
    { nameEn = "Resolve", icon = Img("buff18"), type = "Buff" },
    { nameEn = "Savagery", icon = Img("buff19"), type = "Buff" },
    { nameEn = "Slayer", icon = Img("buff20"), type = "Buff" },
    { nameEn = "Sorcery", icon = Img("buff21"), type = "Buff" },
    { nameEn = "Spell Resistance", icon = Img("buff22"), type = "Buff" },
    { nameEn = "Spell Resistance Potion", icon = Img("buff23"), type = "Buff" },
    { nameEn = "Toughness", icon = Img("buff24"), type = "Buff" },
    { nameEn = "Vitality", icon = Img("buff25"), type = "Buff" },

    -- ===== قسم الديبفات (Debuffs) =====
    { nameEn = "Breach", icon = Img("debuff1"), type = "Debuff" },
    { nameEn = "Brittle", icon = Img("debuff2"), type = "Debuff" },
    { nameEn = "Cowardice", icon = Img("debuff3"), type = "Debuff" },
    { nameEn = "Defile", icon = Img("debuff4"), type = "Debuff" },
    { nameEn = "Enervation", icon = Img("debuff5"), type = "Debuff" },
    { nameEn = "Hindrance", icon = Img("debuff6"), type = "Debuff" },
    { nameEn = "Lifesteal", icon = Img("debuff7"), type = "Debuff" },
    { nameEn = "Magickasteal", icon = Img("debuff8"), type = "Debuff" },
    { nameEn = "Maim", icon = Img("debuff9"), type = "Debuff" },
    { nameEn = "Mangle", icon = Img("debuff10"), type = "Debuff" },
    { nameEn = "Timidity", icon = Img("debuff11"), type = "Debuff" },
    { nameEn = "Uncertainty", icon = Img("debuff12"), type = "Debuff" },
    { nameEn = "Vulnerability", icon = Img("debuff13"), type = "Debuff" }
}

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= "ArabicHelper" then return end

    -- تحميل المفضلة المحفوظة.
    -- ملاحظة: يجب أن يحتوي ملف Manifest (.txt) على:
    -- ## SavedVariables: ArabicHelperSavedVariables
    BuildSetsDatabase()

    -- الإعدادات لكل سيرفر (EU / NA / PTS) بشكل منفصل
    savedVars = ZO_SavedVars:NewAccountWide("ArabicHelperSavedVariables", 1, nil, savedVarsDefaults, GetWorldName())
    if not savedVars.migratedFromDefault then
        -- ننقل المفضلة من النسخة القديمة (قبل ما تصير لكل سيرفر)
        local old = ZO_SavedVars:NewAccountWide("ArabicHelperSavedVariables", 1, nil, savedVarsDefaults)
        if old and old.favorites and next(old.favorites) and not next(savedVars.favorites) then
            for k, v in pairs(old.favorites) do savedVars.favorites[k] = v end
            savedVars.showCard = old.showCard
        end
        savedVars.migratedFromDefault = true
    end
    MigrateFavorites(savedVars.favorites)
    
    ----------------------------------------------------
    -- 1. النافذة الرئيسية للأطقم
    ----------------------------------------------------
    myWindow = WINDOW_MANAGER:CreateTopLevelWindow("ArabicHelperWindow")
    myWindow:SetDimensions(660, 860) 
    myWindow:SetAnchor(CENTER, GuiRoot, CENTER, -200, 0) 
    myWindow:SetMouseEnabled(true)
    myWindow:SetMovable(true)
    myWindow:SetHidden(true)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", myWindow, CT_BACKDROP)
    bg:SetAnchorFill(myWindow)
    bg:SetCenterColor(0, 0, 0, 0.95)

    local closeBtn = WINDOW_MANAGER:CreateControl("$(parent)CloseBtn", myWindow, CT_BUTTON)
    closeBtn:SetDimensions(32, 32)
    closeBtn:SetAnchor(TOPRIGHT, myWindow, TOPRIGHT, -12, 12)
    ApplyIcon(closeBtn, CLOSE_ICON)
    closeBtn:SetHandler("OnClicked", function()
        myWindow:SetHidden(true)
        if buffsWindow then buffsWindow:SetHidden(true) end
        if trialsWindow then trialsWindow:SetHidden(true) end
        if termsWindow then termsWindow:SetHidden(true) end
    end)

    ----------------------------------------------------
    -- شريط الأدوات العلوي
    ----------------------------------------------------
    local buffsBtn = WINDOW_MANAGER:CreateControl("$(parent)BuffsBtn", myWindow, CT_BUTTON)
    buffsBtn:SetDimensions(48, 48)
    buffsBtn:SetAnchor(TOPLEFT, myWindow, TOPLEFT, 123, 4)
    ApplyIcon(buffsBtn, TOP_ICONS.buffs)
    buffsBtn:SetHandler("OnClicked", function()
        if trialsWindow then trialsWindow:SetHidden(true) end
        if termsWindow then termsWindow:SetHidden(true) end
        buffsWindow:SetHidden(not buffsWindow:IsHidden())
    end)

    local houseBtn = WINDOW_MANAGER:CreateControl("$(parent)HouseBtn", myWindow, CT_BUTTON)
    houseBtn:SetDimensions(48, 48)
    houseBtn:SetAnchor(TOPLEFT, myWindow, TOPLEFT, 23, 4)
    ApplyIcon(houseBtn, TOP_ICONS.house)
    houseBtn:SetHandler("OnClicked", function()
        local targetAccount = "@ALAOOY"
        local myAccount = GetDisplayName and GetDisplayName() or ""

        if string.lower(myAccount) == string.lower(targetAccount) then
            local primaryHouseId = GetHousingPrimaryHouse and GetHousingPrimaryHouse() or 0
            if primaryHouseId and primaryHouseId > 0 and RequestJumpToHouse then
                RequestJumpToHouse(primaryHouseId, false)
            end
        else
            if JumpToHouse then
                JumpToHouse(targetAccount)
            end
        end
    end)

    local favBtn = WINDOW_MANAGER:CreateControl("$(parent)FavBtn", myWindow, CT_BUTTON)
    favBtn:SetDimensions(40, 40)
    favBtn:SetAnchor(TOPLEFT, myWindow, TOPLEFT, 77, 8)
    ApplyIcon(favBtn, TOP_ICONS.fav)
    favBtn:SetAlpha(0.6) -- النجمة باهتة لما المفضلة مقفلة
    favBtn:SetHandler("OnMouseEnter", function(self) self:SetAlpha(1) end)
    favBtn:SetHandler("OnMouseExit", function(self)
        if not favoritesMode then self:SetAlpha(0.6) end
    end)

    -- زر الترايلات
    local trialsBtn = WINDOW_MANAGER:CreateControl("$(parent)TrialsBtn", myWindow, CT_BUTTON)
    trialsBtn:SetDimensions(48, 48)
    trialsBtn:SetAnchor(TOPLEFT, myWindow, TOPLEFT, 177, 4)
    ApplyIcon(trialsBtn, TOP_ICONS.trial)
    trialsBtn:SetHandler("OnClicked", function()
        if not trialsWindow then return end
        if buffsWindow then buffsWindow:SetHidden(true) end
        if termsWindow then termsWindow:SetHidden(true) end
        trialsWindow:SetHidden(not trialsWindow:IsHidden())
    end)

    local function UpdateFavoriteButtonColor()
        -- المفضلة مفتوحة = النجمة واضحة ، مقفلة = باهتة
        if favoritesMode then
            favBtn:SetAlpha(1)
        else
            favBtn:SetAlpha(0.6)
        end
    end

    local divider = WINDOW_MANAGER:CreateControl("$(parent)Divider", myWindow, CT_BACKDROP)
    divider:SetDimensions(610, 2) 
    divider:SetAnchor(TOPLEFT, myWindow, TOPLEFT, 25, 55) 
    divider:SetCenterColor(0.77, 0.76, 0.62, 0.6) 

    ----------------------------------------------------
    -- تبويبات وصندوق البحث للأطقم
    ----------------------------------------------------
    local categories = {"All", "Dungeon", "Trial", "Arena", "craftable", "PvP", "Monster", "Mythic", "Archive"}
    local searchBox 
    local tabButtons = {} -- جدول جديد لحفظ أزرار التبويبات

    -- دالة لتحديث لون التبويب النشط
    local function UpdateActiveTabColor(activeCatName)
        for catName, btn in pairs(tabButtons) do
            if catName == activeCatName then
                btn:SetNormalFontColor(1, 1, 1, 1) -- لون أبيض للتبويب النشط
            else
                btn:SetNormalFontColor(0.77, 0.76, 0.62, 1) -- اللون الذهبي/البيج للباقي
            end
        end
    end

    for i, catName in ipairs(categories) do
        local tab = WINDOW_MANAGER:CreateControl("$(parent)Tab" .. catName, myWindow, CT_BUTTON)
        tab:SetDimensions(68, 30)
        tab:SetAnchor(TOPLEFT, myWindow, TOPLEFT, (i-1)*70 + 15, 65) 
        tab:SetText(catName)
        tab:SetFont("ZoFontWinH5")
        tab:SetNormalFontColor(0.77, 0.76, 0.62, 1)
        tab:SetMouseOverFontColor(1, 1, 1, 1) 
        
        tabButtons[catName] = tab -- حفظ الزر في الجدول

        tab:SetHandler("OnClicked", function() 
            favoritesMode = false
            UpdateFavoriteButtonColor()
            if catName == "All" then currentCategory = "" else currentCategory = catName end
            UpdateActiveTabColor(catName) -- تحديث اللون عند الضغط
            local currentSearch = searchBox:GetText()
            if currentSearch == "Type here to search..." then currentSearch = "" end
            myWindow.UpdateResults(currentSearch)
        end)
    end

    local searchBg = WINDOW_MANAGER:CreateControl("$(parent)SearchBg", myWindow, CT_BACKDROP)
    searchBg:SetDimensions(520, 40)
    searchBg:SetAnchor(TOP, myWindow, TOP, 0, 105) 
    searchBg:SetCenterColor(0.15, 0.15, 0.15, 1) 

    searchBox = WINDOW_MANAGER:CreateControl("$(parent)SearchBox", myWindow, CT_EDITBOX)
    searchBox:SetDimensions(510, 40)
    searchBox:SetAnchor(CENTER, searchBg, CENTER, 0, 0)
    searchBox:SetFont("ZoFontWinH2")
    searchBox:SetText("Type here to search...")
    searchBox:SetEditEnabled(true)
    searchBox:SetMouseEnabled(true)
    searchBox:SetColor(0.77, 0.76, 0.62, 1)

    local scrollContainer = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ScrollContainer", myWindow, "ZO_ScrollContainer")
    scrollContainer:SetDimensions(560, 300) 
    scrollContainer:SetAnchor(TOP, myWindow, TOP, 0, 155) 
    local scrollChild = scrollContainer:GetNamedChild("ScrollChild")

    local myImage = WINDOW_MANAGER:CreateControl("$(parent)MyImage", myWindow, CT_TEXTURE)
    myImage:SetDimensions(400, 400) 
    myImage:SetAnchor(BOTTOM, myWindow, BOTTOM, 0, -15)
    myImage:SetHidden(true)

    ----------------------------------------------------
    -- Favorite button - DDS star with label underneath
    ----------------------------------------------------
    local favoriteStarBtn = WINDOW_MANAGER:CreateControl("$(parent)FavoriteStarBtn", myWindow, CT_BUTTON)
    favoriteStarBtn:SetDimensions(40, 40)
    favoriteStarBtn:SetAnchor(TOPLEFT, myImage, TOPRIGHT, 24, 18)
    -- نجمة اللعبة نفسها (ما تحتاج صور في مجلد images)
    favoriteStarBtn:SetNormalTexture("/esoui/art/collections/favorite_staronly.dds")
    favoriteStarBtn:SetMouseOverTexture("/esoui/art/collections/favorite_staronly.dds")
    favoriteStarBtn:SetPressedTexture("/esoui/art/collections/favorite_staronly.dds")
    favoriteStarBtn:SetDrawLayer(DL_OVERLAY)
    favoriteStarBtn:SetDrawTier(DT_HIGH)
    favoriteStarBtn:SetHidden(true)

    local favoriteLabel = WINDOW_MANAGER:CreateControl("$(parent)FavoriteLabel", myWindow, CT_LABEL)
    favoriteLabel:SetDimensions(90, 22)
    favoriteLabel:SetAnchor(TOP, favoriteStarBtn, BOTTOM, 0, 2)
    favoriteLabel:SetFont("ZoFontGameSmall")
    favoriteLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    favoriteLabel:SetColor(0.77, 0.76, 0.62, 1)
    favoriteLabel:SetText("Favorite")
    favoriteLabel:SetDrawLayer(DL_OVERLAY)
    favoriteLabel:SetDrawTier(DT_HIGH)
    favoriteLabel:SetHidden(true)

    local favoritesEmptyLabel = WINDOW_MANAGER:CreateControl("$(parent)FavoritesEmptyLabel", scrollChild, CT_LABEL)
    favoritesEmptyLabel:SetDimensions(520, 40)
    favoritesEmptyLabel:SetAnchor(TOP, scrollChild, TOP, 0, 15)
    favoritesEmptyLabel:SetFont("ZoFontWinH3")
    favoritesEmptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    favoritesEmptyLabel:SetColor(0.77, 0.76, 0.62, 1)
    favoritesEmptyLabel:SetText("No favorites yet")
    favoritesEmptyLabel:SetHidden(true)

    local function IsFavorite(setId)
        return savedVars and savedVars.favorites and savedVars.favorites[setId] == true
    end

    local function UpdateFavoriteStar()
        if not selectedSetInfo or myImage:IsHidden() then
            favoriteStarBtn:SetHidden(true)
            favoriteLabel:SetHidden(true)
            return
        end

        if IsFavorite(selectedSetInfo.setId) then
            favoriteStarBtn:SetAlpha(1) -- في المفضلة = النجمة واضحة
            favoriteLabel:SetText("Favorited")
        else
            favoriteStarBtn:SetAlpha(0.35) -- مو في المفضلة = النجمة باهتة
            favoriteLabel:SetText("Favorite")
        end

        favoriteStarBtn:SetHidden(false)
        favoriteLabel:SetHidden(false)
    end

    local function HideSelectedSet()
        selectedSetInfo = nil
        myImage:SetHidden(true)
        favoriteStarBtn:SetHidden(true)
        favoriteLabel:SetHidden(true)
    end

    favoriteStarBtn:SetHandler("OnClicked", function()
        if not selectedSetInfo or not savedVars then return end

        savedVars.favorites = savedVars.favorites or {}
        local setId = selectedSetInfo.setId
        if savedVars.favorites[setId] then
            savedVars.favorites[setId] = nil
        else
            savedVars.favorites[setId] = true
        end

        UpdateFavoriteStar()

        -- إذا كنا داخل صفحة المفضلة وحذف اللاعب الـSet منها، حدّث القائمة مباشرة.
        if favoritesMode and myWindow.UpdateResults then
            local currentSearch = searchBox:GetText()
            if currentSearch == "Type here to search..." then currentSearch = "" end
            myWindow.UpdateResults(currentSearch)
        end
    end)

    local function UpdateResults(input)
        local searchText = string.lower(input or "")
        if searchText == "type here to search..." then searchText = "" end
        
        for i = 1, scrollChild:GetNumChildren() do scrollChild:GetChild(i):SetHidden(true) end
        HideSelectedSet()
        favoritesEmptyLabel:SetHidden(true)

        -- الوضع العادي يبقى بنفس سلوك الأدون الحالي: لا تظهر نتائج قبل الكتابة.
        -- وضع المفضلة يعرض كل المفضلات حتى لو كان البحث فارغاً.
        if searchText == "" and not favoritesMode then
            scrollChild:SetHeight(0)
            if ZO_Scroll_UpdateChildSize then ZO_Scroll_UpdateChildSize(scrollContainer) end
            return
        end
        
        local count = 0
        local colWidth = 180   
        local rowHeight = 35   
        local maxCols = 3      
        
        for i, setInfo in ipairs(setsDatabase) do
            local matchesCat = (currentCategory == "" or setInfo.category == currentCategory)
            local matchesSearch = (searchText == "" or string.find(string.lower(setInfo.name), searchText, 1, true) ~= nil)
            local matchesFavorite = (not favoritesMode or IsFavorite(setInfo.setId))
            
            if matchesCat and matchesSearch and matchesFavorite then
                local selectedSet = setInfo
                local btnName = "ArabicHelperBtn" .. i
                local btn = WINDOW_MANAGER:GetControlByName(btnName) or WINDOW_MANAGER:CreateControl(btnName, scrollChild, CT_BUTTON)
                
                local col = count % maxCols
                local row = math.floor(count / maxCols)
                local xPosition = col * colWidth + 15 
                local yPosition = row * rowHeight
                
                btn:SetDimensions(170, 30)
                btn:ClearAnchors()
                btn:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, xPosition, yPosition)
                -- الست المطوّر (Perfected) نكتبه مختصر: "P. " + اسم الست العادي (بأي لغة)
                local shownName = selectedSet.name
                local unperfectedId = GetItemSetUnperfectedSetId(selectedSet.setId)
                if unperfectedId and unperfectedId ~= 0 and unperfectedId ~= selectedSet.setId then
                    shownName = "P. " .. (SetDisplayName(unperfectedId) or selectedSet.name)
                end
                -- لو الاسم طويل نصغّر الخط عشان ما ينقص
                if string.len(shownName) > 18 then
                    btn:SetFont("ZoFontWinH5")
                else
                    btn:SetFont("ZoFontWinH4")
                end
                btn:SetText(shownName)
                btn:SetHidden(false)
                
                btn:SetMouseEnabled(true)
                btn:SetNormalFontColor(0.77, 0.76, 0.62, 1)
                btn:SetMouseOverFontColor(1, 1, 1, 1)
                
                btn:SetHandler("OnClicked", function()
                    selectedSetInfo = selectedSet
                    myImage:SetTexture(selectedSet.icon)
                    myImage:SetHidden(false)
                    UpdateFavoriteStar()
                end)
                
                count = count + 1
            end
        end

        if favoritesMode and count == 0 then
            favoritesEmptyLabel:SetHidden(false)
            scrollChild:SetHeight(60)
        else
            local totalRows = math.ceil(count / maxCols)
            scrollChild:SetHeight(totalRows * rowHeight)
        end
        
        if ZO_Scroll_UpdateChildSize then 
            ZO_Scroll_UpdateChildSize(scrollContainer) 
        end
    end

    myWindow.UpdateResults = UpdateResults

    -- زر [F]: فتح/إغلاق وضع المفضلة داخل نفس قائمة النتائج.
    favBtn:SetHandler("OnClicked", function()
        favoritesMode = not favoritesMode
        HideSelectedSet()
        UpdateFavoriteButtonColor()

        if favoritesMode then
            currentCategory = ""
            UpdateActiveTabColor(nil)
            searchBox:SetText("Type here to search...")
            UpdateResults("")
        else
            currentCategory = ""
            UpdateActiveTabColor("All")
            searchBox:SetText("Type here to search...")
            UpdateResults("")
        end
    end)

    searchBox:SetHandler("OnMouseUp", function(self) self:TakeFocus() end)
    searchBox:SetHandler("OnFocusGained", function(self) if self:GetText() == "Type here to search..." then self:SetText("") end end)
    searchBox:SetHandler("OnTextChanged", function(self) UpdateResults(self:GetText()) end)

    ----------------------------------------------------
    -- 2. نافذة دليل البفات والديبفات العائمة
    ----------------------------------------------------
    buffsWindow = WINDOW_MANAGER:CreateTopLevelWindow("ArabicHelperBuffsWindow")
    buffsWindow:SetDimensions(520, 700) 
    buffsWindow:SetAnchor(CENTER, GuiRoot, CENTER, 380, 0)
    buffsWindow:SetMouseEnabled(true)
    buffsWindow:SetMovable(true)
    buffsWindow:SetHidden(true)

    local buffsBg = WINDOW_MANAGER:CreateControl("$(parent)BG", buffsWindow, CT_BACKDROP)
    buffsBg:SetAnchorFill(buffsWindow)
    buffsBg:SetCenterColor(0, 0, 0, 0.95)

    local buffsCloseBtn = WINDOW_MANAGER:CreateControl("$(parent)CloseBtn", buffsWindow, CT_BUTTON)
    buffsCloseBtn:SetDimensions(32, 32)
    buffsCloseBtn:SetAnchor(TOPRIGHT, buffsWindow, TOPRIGHT, -12, 12)
    ApplyIcon(buffsCloseBtn, CLOSE_ICON)
    buffsCloseBtn:SetHandler("OnClicked", function() buffsWindow:SetHidden(true) end)

    local currentBuffTab = "Buff"
    local buffTabs = { {id="Buff", name="Buffs"}, {id="Debuff", name="Debuffs"} }
    
    local buffScrollContainer = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ScrollContainer", buffsWindow, "ZO_ScrollContainer")
    buffScrollContainer:SetDimensions(480, 330) 
    buffScrollContainer:SetAnchor(TOP, buffsWindow, TOP, 0, 80) 
    local buffScrollChild = buffScrollContainer:GetNamedChild("ScrollChild")

    local buffImage = WINDOW_MANAGER:CreateControl("$(parent)BuffImage", buffsWindow, CT_TEXTURE)
    buffImage:SetDimensions(500, 250) 
    buffImage:SetAnchor(BOTTOM, buffsWindow, BOTTOM, 0, -20)
    buffImage:SetDrawLayer(DL_OVERLAY) 
    buffImage:SetDrawTier(DT_HIGH)     
    buffImage:SetHidden(true)

    -- دالة تحديث قائمة البفات وإضافة الخطوط
    local function UpdateBuffResults()
        -- إخفاء كل العناصر القديمة (أزرار + خطوط)
        for i = 1, buffScrollChild:GetNumChildren() do buffScrollChild:GetChild(i):SetHidden(true) end
        buffImage:SetHidden(true) 
        
        local yPosition = 0
        local btnHeight = 35 -- صغرنا ارتفاع الزر شوي عشان يتناسب مع الخط

        for i, buffInfo in ipairs(buffsDatabase) do
            if buffInfo.type == currentBuffTab then
                local btnName = "ArabicHelperBuffBtn" .. i
                local btn = WINDOW_MANAGER:GetControlByName(btnName) or WINDOW_MANAGER:CreateControl(btnName, buffScrollChild, CT_BUTTON)
                
                btn:SetDimensions(440, btnHeight)
                btn:SetAnchor(TOPLEFT, buffScrollChild, TOPLEFT, 10, yPosition)
                btn:SetText(buffInfo.nameEn or "Unknown")
                btn:SetFont("ZoFontWinH3")
                btn:SetHorizontalAlignment(TEXT_ALIGN_LEFT) 
                btn:SetNormalFontColor(0.77, 0.76, 0.62, 1)
                btn:SetMouseOverFontColor(1, 1, 1, 1)
                btn:SetHidden(false)

                btn:SetHandler("OnClicked", function() 
                    if buffInfo.icon then
                        buffImage:SetTexture(buffInfo.icon)
                        buffImage:SetHidden(false)
                    end
                end)

                -- إضافة الخط النحيف الفاصل
                local divName = "ArabicHelperBuffItemDivider" .. i
                local lineDivider = WINDOW_MANAGER:GetControlByName(divName) or WINDOW_MANAGER:CreateControl(divName, buffScrollChild, CT_BACKDROP)
                lineDivider:SetDimensions(440, 1) -- ارتفاع 1 بكسل فقط
                lineDivider:SetAnchor(TOPLEFT, buffScrollChild, TOPLEFT, 10, yPosition + btnHeight + 2) -- ننزل الخط تحت الزر بـ 2 بكسل
                lineDivider:SetCenterColor(0.77, 0.76, 0.62, 0.15) -- لون ذهبي شفاف جداً
                lineDivider:SetEdgeColor(0, 0, 0, 0) -- إزالة الحدود
                lineDivider:SetHidden(false)

                -- تحديث مسافة الزر القادم (الزر + الخط + مسافة إضافية)
                yPosition = yPosition + btnHeight + 8
            end
        end
        buffScrollChild:SetHeight(yPosition)
        if ZO_Scroll_UpdateChildSize then ZO_Scroll_UpdateChildSize(buffScrollContainer) end
    end

    for i, tabData in ipairs(buffTabs) do
        local tabBtn = WINDOW_MANAGER:CreateControl("$(parent)Tab" .. tabData.id, buffsWindow, CT_BUTTON)
        tabBtn:SetDimensions(150, 30)
        tabBtn:SetAnchor(TOPLEFT, buffsWindow, TOPLEFT, (i-1)*160 + 25, 25) 
        tabBtn:SetText(tabData.name)
        tabBtn:SetFont("ZoFontWinH3")
        tabBtn:SetNormalFontColor(0.77, 0.76, 0.62, 1)
        tabBtn:SetMouseOverFontColor(1, 1, 1, 1) 
        tabBtn:SetHandler("OnClicked", function() 
            currentBuffTab = tabData.id
            UpdateBuffResults()
        end)
    end

    local buffDivider = WINDOW_MANAGER:CreateControl("$(parent)Divider", buffsWindow, CT_BACKDROP)
    buffDivider:SetDimensions(470, 2) 
    buffDivider:SetAnchor(TOPLEFT, buffsWindow, TOPLEFT, 25, 65) 
    buffDivider:SetCenterColor(0.77, 0.76, 0.62, 0.6) 

    UpdateBuffResults() 

    -- تفعيل لون All كافتراضي عند التشغيل لأول مرة
    UpdateActiveTabColor("All")


    ----------------------------------------------------
    -- 3. Trial Mechanics window
    ----------------------------------------------------
    trialsWindow = WINDOW_MANAGER:CreateTopLevelWindow("ArabicHelperTrialsWindow")
    trialsWindow:SetDimensions(560, 760)
    trialsWindow:SetAnchor(CENTER, GuiRoot, CENTER, 390, 0)
    trialsWindow:SetMouseEnabled(true)
    trialsWindow:SetMovable(true)
    trialsWindow:SetHidden(true)

    local trialsBg = WINDOW_MANAGER:CreateControl("$(parent)BG", trialsWindow, CT_BACKDROP)
    trialsBg:SetAnchorFill(trialsWindow)
    trialsBg:SetCenterColor(0, 0, 0, 0.96)

    local trialsCloseBtn = WINDOW_MANAGER:CreateControl("$(parent)CloseBtn", trialsWindow, CT_BUTTON)
    trialsCloseBtn:SetDimensions(32, 32)
    trialsCloseBtn:SetAnchor(TOPRIGHT, trialsWindow, TOPRIGHT, -12, 12)
    ApplyIcon(trialsCloseBtn, CLOSE_ICON)
    trialsCloseBtn:SetHandler("OnClicked", function() trialsWindow:SetHidden(true) end)

    ----------------------------------------------------
    -- Trial data
    ----------------------------------------------------
    local trialsDatabase = {
        AA = {
            title = "Aetherian Archive (AA)",
            bosses = {
                { name = "1. Lightning Storm Atronach", card = Img("trial_aa_lightning") },
                { name = "2. Foundation Stone Atronach", card = Img("trial_aa_stone") },
                { name = "3. Varlariel", card = Img("trial_aa_varlariel") },
                { name = "4. The Celestial Mage", card = Img("trial_aa_mage") },
            }
        },

        HRC = {
            title = "Hel Ra Citadel (HRC)",
            bosses = {
                { name = "1. Ra Kotu", card = Img("trial_hrc_rakotu") },
                { name = "2. Yokeda Rok'dun", card = Img("trial_hrc_rokdun") },
                { name = "3. Yokeda Kai", card = Img("trial_hrc_kai") },
                { name = "4. The Warrior", card = Img("trial_hrc_warrior") },
            }
        },

        SO = {
            title = "Sanctum Ophidia (SO)",
            bosses = {
                { name = "1. Possessed Mantikora", card = Img("trial_so_mantikora") },
                { name = "2. Stonebreaker", card = Img("trial_so_stonebreaker") },
                { name = "3. Ozara", card = Img("trial_so_ozara") },
                { name = "4. The Serpent", card = Img("trial_so_serpent") },
            }
        },

        MOL = {
            title = "Maw of Lorkhaj (MoL)",
            bosses = {
                { name = "1. Zhaj'hassa the Forgotten", card = Img("trial_mol_zhajhassa") },
                { name = "2. Vashai & S'kinrai", card = Img("trial_mol_twins") },
                { name = "3. Rakkhat", card = Img("trial_mol_rakkhat") },
            }
        },

        HOF = {
            title = "Halls of Fabrication (HoF)",
            bosses = {
                { name = "1. Hunter-Killer Negatrix & Positrox", card = Img("trial_hof_hunterkillers") },
                { name = "2. Pinnacle Factotum", card = Img("trial_hof_pinnacle") },
                { name = "3. Archcustodian", card = Img("trial_hof_archcustodian") },
                { name = "4. Refabrication Committee", card = Img("trial_hof_committee") },
                { name = "5. Assembly General", card = Img("trial_hof_assembly") },
            }
        },

        AS = {
            title = "Asylum Sanctorium (AS)",
            bosses = {
                { name = "1. Saint Felms the Bold", card = Img("trial_as_felms") },
                { name = "2. Saint Llothis the Pious", card = Img("trial_as_llothis") },
                { name = "3. Saint Olms the Just", card = Img("trial_as_olms") },
            }
        },

        CR = {
            title = "Cloudrest (CR)",
            bosses = {
                { name = "1. Shade of Galenwe", card = Img("trial_cr_galenwe") },
                { name = "2. Shade of Relequen", card = Img("trial_cr_relequen") },
                { name = "3. Shade of Siroria", card = Img("trial_cr_siroria") },
                { name = "4. Z'Maja", card = Img("trial_cr_zmaja") },
            }
        },

        SS = {
            title = "Sunspire (SS)",
            bosses = {
                { name = "1. Lokkestiiz", card = Img("trial_ss_lokkestiiz") },
                { name = "2. Yolnahkriin", card = Img("trial_ss_yolnahkriin") },
                { name = "3. Nahviintaas", card = Img("trial_ss_nahviintaas") },
            }
        },

        KA = {
            title = "Kyne's Aegis (KA)",
            bosses = {
                { name = "1. Yandir the Butcher", card = Img("trial_ka_yandir") },
                { name = "2. Captain Vrol", card = Img("trial_ka_vrol") },
                { name = "3. Lord Falgravn", card = Img("trial_ka_falgravn") },
            }
        },

        RG = {
            title = "Rockgrove (RG)",
            bosses = {
                { name = "1. Oaxiltso", card = Img("trial_rg_oaxiltso") },
                { name = "2. Flame-Herald Bahsei", card = Img("trial_rg_bahsei") },
                { name = "3. Xalvakka", card = Img("trial_rg_xalvakka") },
            }
        },

        DSR = {
            title = "Dreadsail Reef (DSR)",
            bosses = {
                { name = "1. Lylanar & Turlassil", card = Img("trial_dsr_lylanar_turlassil") },
                { name = "2. Reef Guardian", card = Img("trial_dsr_reef_guardian") },
                { name = "3. Tideborn Taleria", card = Img("trial_dsr_taleria") },
            }
        },

        SE = {
            title = "Sanity's Edge (SE)",
            bosses = {
                { name = "1. Exarchanic Yaseyla", card = Img("trial_se_yaseyla") },
                { name = "2. Archwizard Twelvane & Chimera", card = Img("trial_se_twelvane") },
                { name = "3. Ansuul the Tormentor", card = Img("trial_se_ansuul") },
            }
        },

        LC = {
            title = "Lucent Citadel (LC)",
            bosses = {
                { name = "1. Count Ryelaz & Zilyesset", card = Img("trial_lc_ryelaz_zilyesset") },
                { name = "2. Orphic Shattered Shard", card = Img("trial_lc_orphic") },
                { name = "3. Xoryn", card = Img("trial_lc_xoryn") },
            }
        },

        OC = {
            title = "Ossein Cage (OC)",
            bosses = {
                { name = "1. Shapers of Flesh", card = Img("trial_oc_shapers") },
                { name = "2. Jynorah & Skorkhif", card = Img("trial_oc_jynorah_skorkhif") },
                { name = "3. Overfiend Kazpian", card = Img("trial_oc_kazpian") },
            }
        },
    }

    local currentTrialKey = nil
    local selectedBossIndex = nil

    ----------------------------------------------------
    -- ESO-style Trial selector
    ----------------------------------------------------
    local trialsHeader = WINDOW_MANAGER:CreateControl("$(parent)TrialsHeader", trialsWindow, CT_LABEL)
    trialsHeader:SetDimensions(460, 36)
    trialsHeader:SetAnchor(TOP, trialsWindow, TOP, 0, 16)
    trialsHeader:SetFont("ZoFontWinH2")
    trialsHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    trialsHeader:SetColor(0.90, 0.82, 0.58, 1)
    trialsHeader:SetText("Trial Mechanics")

    local trialsDivider = WINDOW_MANAGER:CreateControl("$(parent)Divider", trialsWindow, CT_BACKDROP)
    trialsDivider:SetDimensions(510, 2)
    trialsDivider:SetAnchor(TOP, trialsWindow, TOP, 0, 58)
    trialsDivider:SetCenterColor(0.77, 0.76, 0.62, 0.55)

    -- Main selector box
    local trialSelectBox = WINDOW_MANAGER:CreateControl("$(parent)TrialSelectBox", trialsWindow, CT_BACKDROP)
    trialSelectBox:SetDimensions(420, 36)
    trialSelectBox:SetAnchor(TOP, trialsWindow, TOP, 0, 70)
    trialSelectBox:SetCenterColor(0.02, 0.02, 0.02, 0.98)
    trialSelectBox:SetEdgeColor(0.77, 0.76, 0.62, 0.95)

    local trialSelectLabel = WINDOW_MANAGER:CreateControl("$(parent)TrialSelectLabel", trialSelectBox, CT_LABEL)
    trialSelectLabel:SetDimensions(350, 34)
    trialSelectLabel:SetAnchor(LEFT, trialSelectBox, LEFT, 14, 0)
    trialSelectLabel:SetFont("ZoFontWinH3")
    trialSelectLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    trialSelectLabel:SetColor(0.95, 0.95, 0.95, 1)
    trialSelectLabel:SetText("Select Trial")

    local trialSelectArrow = WINDOW_MANAGER:CreateControl("$(parent)TrialSelectArrow", trialSelectBox, CT_LABEL)
    trialSelectArrow:SetDimensions(35, 34)
    trialSelectArrow:SetAnchor(RIGHT, trialSelectBox, RIGHT, -6, 0)
    trialSelectArrow:SetFont("ZoFontWinH2")
    trialSelectArrow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    trialSelectArrow:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    trialSelectArrow:SetColor(0.77, 0.76, 0.62, 1)
    trialSelectArrow:SetText("v")

    local trialSelectButton = WINDOW_MANAGER:CreateControl("$(parent)TrialSelectButton", trialSelectBox, CT_BUTTON)
    trialSelectButton:SetAnchorFill(trialSelectBox)

    ----------------------------------------------------
    -- Dropdown list
    ----------------------------------------------------
    local trialSelectorPanel = WINDOW_MANAGER:CreateControl("$(parent)TrialSelectorPanel", trialsWindow, CT_BACKDROP)
    trialSelectorPanel:SetDimensions(420, 596)
    trialSelectorPanel:SetAnchor(TOP, trialSelectBox, BOTTOM, 0, 4)
    trialSelectorPanel:SetCenterColor(0.02, 0.02, 0.02, 1)
    trialSelectorPanel:SetEdgeColor(0.77, 0.76, 0.62, 0.95)
    trialSelectorPanel:SetDrawLayer(DL_OVERLAY)
    trialSelectorPanel:SetDrawTier(DT_HIGH)
    trialSelectorPanel:SetDrawLevel(80)
    trialSelectorPanel:SetHidden(true)

    local function CreateTrialOption(controlName, textValue, yOffset)
        local hover = WINDOW_MANAGER:CreateControl("$(parent)" .. controlName .. "Hover", trialSelectorPanel, CT_BACKDROP)
        hover:SetDimensions(408, 40)
        hover:SetAnchor(TOP, trialSelectorPanel, TOP, 0, yOffset)
        hover:SetCenterColor(0.10, 0.34, 0.40, 0.78)
        hover:SetEdgeColor(0, 0, 0, 0)
        hover:SetHidden(true)
        hover:SetDrawLayer(DL_OVERLAY)
        hover:SetDrawTier(DT_HIGH)
        hover:SetDrawLevel(81)

        local label = WINDOW_MANAGER:CreateControl("$(parent)" .. controlName .. "Label", trialSelectorPanel, CT_LABEL)
        label:SetDimensions(380, 40)
        label:SetAnchor(TOP, trialSelectorPanel, TOP, 0, yOffset)
        label:SetFont("ZoFontWinH3")
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetColor(0.77, 0.76, 0.62, 1)
        label:SetText(textValue)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawTier(DT_HIGH)
        label:SetDrawLevel(90)

        local button = WINDOW_MANAGER:CreateControl("$(parent)" .. controlName, trialSelectorPanel, CT_BUTTON)
        button:SetDimensions(408, 40)
        button:SetAnchor(TOP, trialSelectorPanel, TOP, 0, yOffset)
        button:SetDrawLayer(DL_OVERLAY)
        button:SetDrawTier(DT_HIGH)
        button:SetDrawLevel(100)

        button:SetHandler("OnMouseEnter", function()
            hover:SetHidden(false)
            label:SetColor(1, 1, 1, 1)
        end)

        button:SetHandler("OnMouseExit", function()
            hover:SetHidden(true)
            label:SetColor(0.77, 0.76, 0.62, 1)
        end)

        return button
    end

    local aaOption = CreateTrialOption("AAOption", "Aetherian Archive (AA)", 5)
    local hrcOption = CreateTrialOption("HRCOption", "Hel Ra Citadel (HRC)", 47)
    local soOption = CreateTrialOption("SOOption", "Sanctum Ophidia (SO)", 89)
    local molOption = CreateTrialOption("MOLOption", "Maw of Lorkhaj (MoL)", 131)
    local hofOption = CreateTrialOption("HOFOption", "Halls of Fabrication (HoF)", 173)
    local asOption = CreateTrialOption("ASOption", "Asylum Sanctorium (AS)", 215)
    local crOption = CreateTrialOption("CROption", "Cloudrest (CR)", 257)
    local ssOption = CreateTrialOption("SSOption", "Sunspire (SS)", 299)
    local kaOption = CreateTrialOption("KAOption", "Kyne's Aegis (KA)", 341)
    local rgOption = CreateTrialOption("RGOption", "Rockgrove (RG)", 383)
    local dsrOption = CreateTrialOption("DSROption", "Dreadsail Reef (DSR)", 425)
    local seOption = CreateTrialOption("SEOption", "Sanity's Edge (SE)", 467)
    local lcOption = CreateTrialOption("LCOption", "Lucent Citadel (LC)", 509)
    local ocOption = CreateTrialOption("OCOption", "Ossein Cage (OC)", 551)

    ----------------------------------------------------
    -- Boss card + buttons
    ----------------------------------------------------
    local trialCard = WINDOW_MANAGER:CreateControl("$(parent)TrialCard", trialsWindow, CT_TEXTURE)
    trialCard:SetDimensions(500, 500)
    trialCard:SetAnchor(BOTTOM, trialsWindow, BOTTOM, 0, -15)
    trialCard:SetDrawLayer(DL_OVERLAY)
    trialCard:SetDrawTier(DT_HIGH)
    trialCard:SetHidden(true)

    local trialBossButtons = {}
    local currentTrialKey = nil
    local selectedBossIndex = nil

    local function UpdateSelectedBoss(index)
        selectedBossIndex = index

        for i, btn in ipairs(trialBossButtons) do
            if i == index then
                btn:SetNormalFontColor(1, 1, 1, 1)
                btn:SetMouseOverFontColor(1, 1, 1, 1)
            else
                btn:SetNormalFontColor(0.77, 0.76, 0.62, 1)
                btn:SetMouseOverFontColor(1, 1, 1, 1)
            end
        end
    end

    local function ShowBoss(index)
        if not currentTrialKey then return end

        local trialInfo = trialsDatabase[currentTrialKey]
        local bossInfo = trialInfo and trialInfo.bosses[index]
        if not bossInfo then return end

        trialCard:SetTexture(bossInfo.card)
        trialCard:SetHidden(false)
        UpdateSelectedBoss(index)
    end

    for i = 1, 5 do
        local bossIndex = i
        local bossBtn = WINDOW_MANAGER:CreateControl("$(parent)Boss" .. i, trialsWindow, CT_BUTTON)
        bossBtn:SetDimensions(500, 30)
        bossBtn:SetAnchor(TOP, trialsWindow, TOP, 0, 110 + ((i - 1) * 31))
        bossBtn:SetFont("ZoFontWinH3")
        bossBtn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        bossBtn:SetNormalFontColor(0.77, 0.76, 0.62, 1)
        bossBtn:SetMouseOverFontColor(1, 1, 1, 1)
        bossBtn:SetHidden(true)
        bossBtn:SetHandler("OnClicked", function()
            ShowBoss(bossIndex)
        end)

        trialBossButtons[i] = bossBtn
    end

    local function SetBossButtonsVisible(visible)
        for _, btn in ipairs(trialBossButtons) do
            btn:SetHidden(not visible)
        end
    end

    local function LoadTrial(trialKey)
        local trialInfo = trialsDatabase[trialKey]
        if not trialInfo then return end

        currentTrialKey = trialKey
        selectedBossIndex = 1

        local bossCount = #trialInfo.bosses
        local bossHeight = 30
        local bossStep = 31

        if bossCount >= 5 then
            bossHeight = 26
            bossStep = 27
        end

        for i, btn in ipairs(trialBossButtons) do
            btn:ClearAnchors()
            btn:SetDimensions(500, bossHeight)
            btn:SetAnchor(TOP, trialsWindow, TOP, 0, 110 + ((i - 1) * bossStep))
        end

        trialSelectLabel:SetText(trialInfo.title)
        trialSelectArrow:SetText("v")
        trialSelectorPanel:SetHidden(true)

        for i, btn in ipairs(trialBossButtons) do
            local bossInfo = trialInfo.bosses[i]
            if bossInfo then
                btn:SetText(bossInfo.name)
                btn:SetHidden(false)
            else
                btn:SetHidden(true)
            end
        end

        ShowBoss(1)
    end

    local function ResetTrialView()
        currentTrialKey = nil
        selectedBossIndex = nil

        trialSelectLabel:SetText("Select Trial")
        trialSelectArrow:SetText("v")
        trialSelectorPanel:SetHidden(true)
        trialCard:SetHidden(true)
        SetBossButtonsVisible(false)
    end

    local function OpenTrialSelector()
        trialCard:SetHidden(true)
        SetBossButtonsVisible(false)
        trialSelectorPanel:SetHidden(false)
        trialSelectArrow:SetText("^")
    end

    local function CloseTrialSelectorAndRestore()
        trialSelectorPanel:SetHidden(true)
        trialSelectArrow:SetText("v")

        if currentTrialKey then
            SetBossButtonsVisible(true)
            if selectedBossIndex then
                ShowBoss(selectedBossIndex)
            end
        end
    end

    trialSelectButton:SetHandler("OnMouseEnter", function()
        trialSelectBox:SetCenterColor(0.08, 0.08, 0.08, 0.98)
        trialSelectLabel:SetColor(1, 1, 1, 1)
    end)

    trialSelectButton:SetHandler("OnMouseExit", function()
        trialSelectBox:SetCenterColor(0.02, 0.02, 0.02, 0.98)
        trialSelectLabel:SetColor(0.95, 0.95, 0.95, 1)
    end)

    trialSelectButton:SetHandler("OnClicked", function()
        if trialSelectorPanel:IsHidden() then
            OpenTrialSelector()
        else
            CloseTrialSelectorAndRestore()
        end
    end)

    aaOption:SetHandler("OnClicked", function()
        LoadTrial("AA")
    end)

    hrcOption:SetHandler("OnClicked", function()
        LoadTrial("HRC")
    end)

    soOption:SetHandler("OnClicked", function()
        LoadTrial("SO")
    end)

    molOption:SetHandler("OnClicked", function()
        LoadTrial("MOL")
    end)

    hofOption:SetHandler("OnClicked", function()
        LoadTrial("HOF")
    end)

    asOption:SetHandler("OnClicked", function()
        LoadTrial("AS")
    end)

    crOption:SetHandler("OnClicked", function()
        LoadTrial("CR")
    end)

    ssOption:SetHandler("OnClicked", function()
        LoadTrial("SS")
    end)

    kaOption:SetHandler("OnClicked", function()
        LoadTrial("KA")
    end)

    rgOption:SetHandler("OnClicked", function()
        LoadTrial("RG")
    end)

    dsrOption:SetHandler("OnClicked", function()
        LoadTrial("DSR")
    end)

    seOption:SetHandler("OnClicked", function()
        LoadTrial("SE")
    end)

    lcOption:SetHandler("OnClicked", function()
        LoadTrial("LC")
    end)

    ocOption:SetHandler("OnClicked", function()
        LoadTrial("OC")
    end)

    -- Every time Trial Mechanics opens, begin with the selector only.
    trialsWindow:SetHandler("OnShow", function()
        ResetTrialView()
    end)


    ----------------------------------------------------
    -- 4. نافذة المصطلحات (Terms) - الشرح بالعربي
    ----------------------------------------------------
    -- الخط العربي من مجلد fonts داخل الأدون
    local AR_FONT = "ArabicHelper/fonts/NotoNaskhArabic.slug|20|soft-shadow-thin"
    local AR_LINE_HEIGHT = 30   -- ارتفاع سطر العربي
    local AR_LINE_WIDTH = 42    -- كم حرف في السطر قبل ما ينزل سطر جديد

    -- يحوّل النص العربي عشان يطلع متصل ومن اليمين لليسار
    local function ArabicText(text)
        local AR = AH.Arabic
        if not AR or not AR.process then return text end
        local ok, res = pcall(AR.process, text, { mode = "visual", width = AR_LINE_WIDTH })
        if ok and type(res) == "string" then return res end
        return text
    end

    -- قاعدة بيانات المصطلحات
    local termsDatabase = {
        -- ===== الستاتات الأساسية (Stats) =====
        { en = "Weapon / Spell Damage", ar = "تزيد قوة ضرر السلاح والسحر، وكل ما زادت زاد ضرر مهاراتك", cat = "Stats" },
        { en = "Recovery", ar = "سرعة رجوع الصحة أو الماجيكا أو الستامينا مع الوقت", cat = "Stats" },
        { en = "Critical Chance", ar = "فرصة إن ضربتك تطلع ضربة حاسمة (كريتكل) أقوى من العادية", cat = "Stats" },
        { en = "Critical Damage", ar = "تزيد قوة الضربة الحاسمة لما تطلع", cat = "Stats" },
        { en = "Offensive Penetration", ar = "تتجاهل جزء من دفاع العدو، فيوصله ضربك أقوى", cat = "Stats" },
        { en = "Armor / Spell Resistance", ar = "دفاعك ضد الضرر الفيزيائي والسحري، كل ما زاد قل الضرر عليك", cat = "Stats" },
        { en = "Healing Done", ar = "تزيد قوة العلاج اللي تسويه لنفسك أو للفريق", cat = "Stats" },
        { en = "Healing Taken", ar = "تزيد العلاج اللي يوصلك من أي أحد", cat = "Stats" },
        { en = "Damage Done / Damage Taken", ar = "الضرر اللي تسويه، الضرر اللي يجيك (بنفس الترتيب)", cat = "Stats" },

        -- ===== أنواع الضرر (Damage) =====
        { en = "Direct Damage", ar = "ضرر يصير مرة وحدة فوراً", cat = "Damage" },
        { en = "Damage over Time (DoT)", ar = "ضرر مستمر يتكرر على مدة معينة", cat = "Damage" },
        { en = "Single Target", ar = "يأثر على عدو واحد بس", cat = "Damage" },
        { en = "Area of Effect (AoE)", ar = "يأثر على كل الأعداء اللي في المنطقة", cat = "Damage" },
        { en = "Flame / Shock / Frost", ar = "ضرر نار، كهرباء، ثلج (بنفس الترتيب)", cat = "Damage" },
        { en = "Poison / Disease / Bleed", ar = "ضرر سم، مرض، نزيف (بنفس الترتيب)", cat = "Damage" },
        { en = "Physical / Magic", ar = "ضرر فيزيائي، سحري (بنفس الترتيب)", cat = "Damage" },
        { en = "Melee / Ranged", ar = "قريب، بعيد (بنفس الترتيب)", cat = "Damage" },
        { en = "Cone", ar = "منطقة على شكل مخروط قدامك", cat = "Damage" },

        -- ===== الهجوم والقتال (Combat) =====
        { en = "Light Attack", ar = "ضربة عادية خفيفة بضغطة وحدة", cat = "Combat" },
        { en = "Heavy Attack", ar = "ضربة قوية لما تضغط مطوّل على زر الهجوم", cat = "Combat" },
        { en = "Fully-charged Heavy Attack", ar = "ضربة قوية مشحونة للآخر (تكمل الضغط للنهاية)", cat = "Combat" },
        { en = "Bash", ar = "ضربة بالسلاح أو الدرع وأنت ماسك بلوك", cat = "Combat" },
        { en = "Block", ar = "صد الضرر وتقليله وأنت ماسك زر البلوك", cat = "Combat" },
        { en = "Synergy", ar = "مهارة يفعّلها لاعب ثاني من مهارتك، أو أنت من مهارته", cat = "Combat" },
        { en = "Execute", ar = "مهارة ضررها أقوى على العدو اللي صحته قليلة", cat = "Combat" },
        { en = "Dodge / Roll Dodge", ar = "التفادي، الدحرجة عشان تتفادى الضرر", cat = "Combat" },
        { en = "Interrupt", ar = "تقطع مهارة العدو وهو يجهّزها", cat = "Combat" },
        { en = "Break Free", ar = "تفك نفسك من الشلل أو التثبيت", cat = "Combat" },
        { en = "Pet", ar = "مخلوق يقاتل معك، مثل حيوانات Sorcerer و Warden", cat = "Combat" },

        -- ===== التأثيرات (Effects) =====
        { en = "Proc", ar = "لما يشتغل تأثير الست تلقائياً", cat = "Effects" },
        { en = "Cooldown", ar = "الوقت اللي لازم يمر قبل ما يشتغل التأثير مرة ثانية", cat = "Effects" },
        { en = "Stacks", ar = "تأثير يتجمّع ويزيد كل مرة يتكرر", cat = "Effects" },
        { en = "Status Effect", ar = "تأثير حالة على العدو مثل الحرق والتجميد", cat = "Effects" },
        { en = "Damage Shield", ar = "درع يمتص الضرر بدالك", cat = "Effects" },
        { en = "Healing over Time", ar = "علاج مستمر يتكرر على مدة معينة", cat = "Effects" },
        { en = "Tether", ar = "رابط بينك وبين هدف أو لاعب", cat = "Effects" },
        { en = "Snare / Immobilize / Stun", ar = "إبطاء، تثبيت، شلل (بنفس الترتيب)", cat = "Effects" },
        { en = "Taunt", ar = "تجبر الزعيم يهاجمك أنت", cat = "Effects" },
        { en = "Off Balance", ar = "العدو يفقد توازنه، وتقدر تشلّه بضربة Heavy Attack", cat = "Effects" },
        { en = "Crowd Control (CC)", ar = "أي تأثير يتحكم بالعدو مثل الشلل والتثبيت والإبطاء", cat = "Effects" },
    }

    -- نجهّز النص العربي مرة وحدة بس (أسرع)
    for _, term in ipairs(termsDatabase) do
        term.arShown = ArabicText(term.ar)
        local lines = 1
        for _ in string.gmatch(term.arShown, "\n") do lines = lines + 1 end
        term.arLines = lines
    end

    termsWindow = WINDOW_MANAGER:CreateTopLevelWindow("ArabicHelperTermsWindow")
    termsWindow:SetDimensions(540, 760)
    termsWindow:SetAnchor(CENTER, GuiRoot, CENTER, 390, 0)
    termsWindow:SetMouseEnabled(true)
    termsWindow:SetMovable(true)
    termsWindow:SetHidden(true)

    local termsBg = WINDOW_MANAGER:CreateControl("$(parent)BG", termsWindow, CT_BACKDROP)
    termsBg:SetAnchorFill(termsWindow)
    termsBg:SetCenterColor(0, 0, 0, 0.95)

    local termsCloseBtn = WINDOW_MANAGER:CreateControl("$(parent)CloseBtn", termsWindow, CT_BUTTON)
    termsCloseBtn:SetDimensions(32, 32)
    termsCloseBtn:SetAnchor(TOPRIGHT, termsWindow, TOPRIGHT, -12, 12)
    ApplyIcon(termsCloseBtn, CLOSE_ICON)
    termsCloseBtn:SetHandler("OnClicked", function() termsWindow:SetHidden(true) end)

    local termsHeader = WINDOW_MANAGER:CreateControl("$(parent)Header", termsWindow, CT_LABEL)
    termsHeader:SetDimensions(460, 36)
    termsHeader:SetAnchor(TOP, termsWindow, TOP, 0, 16)
    termsHeader:SetFont("ZoFontWinH2")
    termsHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    termsHeader:SetColor(0.90, 0.82, 0.58, 1)
    termsHeader:SetText("Set Terms")

    local termsDivider = WINDOW_MANAGER:CreateControl("$(parent)Divider", termsWindow, CT_BACKDROP)
    termsDivider:SetDimensions(490, 2)
    termsDivider:SetAnchor(TOP, termsWindow, TOP, 0, 58)
    termsDivider:SetCenterColor(0.77, 0.76, 0.62, 0.6)

    -- تبويبات المصطلحات
    local termTabs = { "All", "Stats", "Damage", "Combat", "Effects" }
    local currentTermCat = "All"
    local termTabButtons = {}

    -- خانة البحث
    local termsSearchBg = WINDOW_MANAGER:CreateControl("$(parent)SearchBg", termsWindow, CT_BACKDROP)
    termsSearchBg:SetDimensions(490, 36)
    termsSearchBg:SetAnchor(TOP, termsWindow, TOP, 0, 108)
    termsSearchBg:SetCenterColor(0.15, 0.15, 0.15, 1)

    local TERMS_HINT = "Search term..."
    local termsSearch = WINDOW_MANAGER:CreateControl("$(parent)SearchBox", termsWindow, CT_EDITBOX)
    termsSearch:SetDimensions(480, 36)
    termsSearch:SetAnchor(CENTER, termsSearchBg, CENTER, 0, 0)
    termsSearch:SetFont("ZoFontWinH3")
    termsSearch:SetText(TERMS_HINT)
    termsSearch:SetEditEnabled(true)
    termsSearch:SetMouseEnabled(true)
    termsSearch:SetColor(0.77, 0.76, 0.62, 1)

    local termsScroll = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ScrollContainer", termsWindow, "ZO_ScrollContainer")
    termsScroll:SetDimensions(500, 590)
    termsScroll:SetAnchor(TOP, termsWindow, TOP, 0, 155)
    local termsChild = termsScroll:GetNamedChild("ScrollChild")

    local function UpdateTermTabColors()
        for name, btn in pairs(termTabButtons) do
            if name == currentTermCat then
                btn:SetNormalFontColor(1, 1, 1, 1)
            else
                btn:SetNormalFontColor(0.77, 0.76, 0.62, 1)
            end
        end
    end

    local function UpdateTerms()
        local searchText = string.lower(termsSearch:GetText() or "")
        if searchText == string.lower(TERMS_HINT) then searchText = "" end

        for i = 1, termsChild:GetNumChildren() do termsChild:GetChild(i):SetHidden(true) end

        local y = 0
        for i, term in ipairs(termsDatabase) do
            local matchCat = (currentTermCat == "All" or term.cat == currentTermCat)
            local matchSearch = (searchText == "" or string.find(string.lower(term.en), searchText, 1, true) ~= nil)

            if matchCat and matchSearch then
                -- اسم المصطلح بالإنجليزي
                local enName = "ArabicHelperTermEn" .. i
                local enLabel = WINDOW_MANAGER:GetControlByName(enName) or WINDOW_MANAGER:CreateControl(enName, termsChild, CT_LABEL)
                enLabel:SetDimensions(470, 30)
                enLabel:ClearAnchors()
                enLabel:SetAnchor(TOPLEFT, termsChild, TOPLEFT, 10, y)
                enLabel:SetFont("ZoFontWinH3")
                enLabel:SetColor(0.90, 0.82, 0.58, 1)
                enLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                enLabel:SetText(term.en)
                enLabel:SetHidden(false)
                y = y + 30

                -- الشرح بالعربي (من اليمين)
                local arName = "ArabicHelperTermAr" .. i
                local arLabel = WINDOW_MANAGER:GetControlByName(arName) or WINDOW_MANAGER:CreateControl(arName, termsChild, CT_LABEL)
                local arHeight = term.arLines * AR_LINE_HEIGHT
                arLabel:SetDimensions(470, arHeight)
                arLabel:ClearAnchors()
                arLabel:SetAnchor(TOPLEFT, termsChild, TOPLEFT, 10, y)
                arLabel:SetFont(AR_FONT)
                arLabel:SetColor(1, 1, 1, 1)
                arLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                arLabel:SetText(term.arShown)
                arLabel:SetHidden(false)
                y = y + arHeight + 6

                -- خط فاصل
                local divName = "ArabicHelperTermDiv" .. i
                local line = WINDOW_MANAGER:GetControlByName(divName) or WINDOW_MANAGER:CreateControl(divName, termsChild, CT_BACKDROP)
                line:SetDimensions(470, 1)
                line:ClearAnchors()
                line:SetAnchor(TOPLEFT, termsChild, TOPLEFT, 10, y)
                line:SetCenterColor(0.77, 0.76, 0.62, 0.15)
                line:SetEdgeColor(0, 0, 0, 0)
                line:SetHidden(false)
                y = y + 10
            end
        end

        termsChild:SetHeight(y)
        if ZO_Scroll_UpdateChildSize then ZO_Scroll_UpdateChildSize(termsScroll) end
    end

    for i, catName in ipairs(termTabs) do
        local tab = WINDOW_MANAGER:CreateControl("$(parent)Tab" .. catName, termsWindow, CT_BUTTON)
        tab:SetDimensions(90, 30)
        tab:SetAnchor(TOPLEFT, termsWindow, TOPLEFT, (i - 1) * 98 + 25, 68)
        tab:SetText(catName)
        tab:SetFont("ZoFontWinH4")
        tab:SetNormalFontColor(0.77, 0.76, 0.62, 1)
        tab:SetMouseOverFontColor(1, 1, 1, 1)
        termTabButtons[catName] = tab
        tab:SetHandler("OnClicked", function()
            currentTermCat = catName
            UpdateTermTabColors()
            UpdateTerms()
        end)
    end

    termsSearch:SetHandler("OnMouseUp", function(self) self:TakeFocus() end)
    termsSearch:SetHandler("OnFocusGained", function(self) if self:GetText() == TERMS_HINT then self:SetText("") end end)
    termsSearch:SetHandler("OnTextChanged", function() UpdateTerms() end)

    -- كل ما تنفتح النافذة ترجع على All
    termsWindow:SetHandler("OnShow", function()
        currentTermCat = "All"
        termsSearch:SetText(TERMS_HINT)
        UpdateTermTabColors()
        UpdateTerms()
    end)

    -- زر المصطلحات في الشريط العلوي
    local termsBtn = WINDOW_MANAGER:CreateControl("$(parent)TermsBtn", myWindow, CT_BUTTON)
    termsBtn:SetDimensions(48, 48)
    termsBtn:SetAnchor(TOPLEFT, myWindow, TOPLEFT, 231, 4)
    ApplyIcon(termsBtn, TOP_ICONS.terms)
    termsBtn:SetHandler("OnClicked", function()
        if buffsWindow then buffsWindow:SetHidden(true) end
        if trialsWindow then trialsWindow:SetHidden(true) end
        termsWindow:SetHidden(not termsWindow:IsHidden())
    end)


    ----------------------------------------------------
    -- 5. بطاقة الست تطلع تلقائي جنب وصف القطعة (Tooltip)
    ----------------------------------------------------
    -- جدول سريع: رقم الست -> صورته
    local setIconById = {}
    for _, info in ipairs(setsDatabase) do
        setIconById[info.setId] = info.icon
    end
    -- لو عندنا بطاقة للنسخة المطوّرة بس، نستخدمها للنسخة العادية بعد (والعكس)
    for _, info in ipairs(setsDatabase) do
        local unperfectedId = GetItemSetUnperfectedSetId(info.setId)
        if unperfectedId and unperfectedId ~= 0 and not setIconById[unperfectedId] then
            setIconById[unperfectedId] = info.icon
        end
    end

    -- نافذة البطاقة
    local CARD_SIZE = 360
    local cardWindow = WINDOW_MANAGER:CreateTopLevelWindow("ArabicHelperSetCard")
    cardWindow:SetDimensions(CARD_SIZE, CARD_SIZE)
    cardWindow:SetDrawLayer(DL_OVERLAY)
    cardWindow:SetDrawTier(DT_HIGH)
    cardWindow:SetMouseEnabled(false)
    cardWindow:SetHidden(true)

    local cardBg = WINDOW_MANAGER:CreateControl("$(parent)BG", cardWindow, CT_BACKDROP)
    cardBg:SetAnchorFill(cardWindow)
    cardBg:SetCenterColor(0, 0, 0, 0.95)
    cardBg:SetEdgeColor(0.77, 0.76, 0.62, 0.8)

    local cardImage = WINDOW_MANAGER:CreateControl("$(parent)Image", cardWindow, CT_TEXTURE)
    cardImage:SetAnchor(TOPLEFT, cardWindow, TOPLEFT, 4, 4)
    cardImage:SetAnchor(BOTTOMRIGHT, cardWindow, BOTTOMRIGHT, -4, -4)

    local cardAnchor = nil -- الوصف اللي البطاقة لازقة فيه

    local function HideCard()
        cardWindow:SetHidden(true)
        cardAnchor = nil
    end

    -- لو الوصف اختفى (مثلاً سكّرت الحقيبة)، البطاقة تختفي معه
    cardWindow:SetHandler("OnUpdate", function()
        if cardAnchor and cardAnchor ~= GuiRoot and cardAnchor.IsHidden and cardAnchor:IsHidden() then
            HideCard()
        end
    end)

    local cardDebug = false
    local hookReport = {}

    local function ShowCardFor(tooltip, itemLink)
        if not savedVars or savedVars.showCard == false then return HideCard() end
        if not itemLink or itemLink == "" then return HideCard() end

        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        local icon = hasSet and setId and setIconById[setId] or nil
        if cardDebug then
            d("ArabicHelper card: set=" .. tostring(setName) .. " id=" .. tostring(setId) .. " image=" .. tostring(icon))
        end
        if not hasSet then return HideCard() end

        if not icon then return HideCard() end

        cardImage:SetTexture(icon)
        cardWindow:ClearAnchors()
        -- نحطها يسار الوصف، ولو ما فيه مكان نحطها يمين
        if tooltip == GuiRoot then
            -- وضع اليد وما لقينا مكان الوصف: نحطها يمين الشاشة
            cardWindow:SetAnchor(RIGHT, GuiRoot, RIGHT, -60, 0)
        elseif tooltip:GetLeft() and tooltip:GetLeft() > CARD_SIZE + 20 then
            cardWindow:SetAnchor(TOPRIGHT, tooltip, TOPLEFT, -8, 0)
        else
            cardWindow:SetAnchor(TOPLEFT, tooltip, TOPRIGHT, 8, 0)
        end
        cardAnchor = tooltip
        cardWindow:SetHidden(false)
    end

    -- مهم: ما نلمس دوال اللعبة أبداً (لا نغيّرها ولا نلفها)، لأن هذا يخرّب
    -- استخدام القطع (فتح الصناديق، شرب البوشن...) ويطلّع UI Error.
    -- بدالها نسمع لحدث "OnAddGameData" على الوصف، وهذا آمن.

    -- نجيب رابط القطعة من الخانة اللي تحت الماوس (الحقيبة، البنك، اللبس، اللوت...)
    local function LinkFromControl(ctrl)
        local c = ctrl
        for _ = 1, 4 do
            if not c then return nil end
            local ok, bag, slot = pcall(ZO_Inventory_GetBagAndIndex, c)
            if ok and bag and slot then return GetItemLink(bag, slot) end
            local data = c.dataEntry and c.dataEntry.data
            if type(data) == "table" then
                if data.bagId and data.slotIndex then return GetItemLink(data.bagId, data.slotIndex) end
                if type(data.itemLink) == "string" then return data.itemLink end
                if data.lootId then return GetLootItemLink(data.lootId) end
            end
            if type(c.itemLink) == "string" then return c.itemLink end
            c = c.GetParent and c:GetParent() or nil
        end
        return nil
    end

    local function OnItemTooltipData(tooltip)
        local ok, link = pcall(LinkFromControl, moc())
        if ok and link then
            local okShow, err = pcall(ShowCardFor, tooltip, link)
            if not okShow and cardDebug then d("ArabicHelper card error: " .. tostring(err)) end
        elseif cardDebug then
            d("ArabicHelper card: no link under mouse")
        end
    end

    local function OnPopupTooltipData(tooltip)
        local okShow, err = pcall(ShowCardFor, tooltip, tooltip.lastLink)
        if not okShow and cardDebug then d("ArabicHelper card error: " .. tostring(err)) end
    end

    -- نضيف المستمع باسمنا الخاص، فما نغيّر مستمعات اللعبة أو الأدونات الثانية
    local function AddHandler(tooltip, label, eventName, fn)
        if not tooltip then
            hookReport[#hookReport + 1] = label .. "=missing"
            return
        end
        local ok = pcall(function() tooltip:SetHandler(eventName, fn, "ArabicHelper") end)
        if not ok then
            ok = pcall(ZO_PostHookHandler, tooltip, eventName, fn)
        end
        hookReport[#hookReport + 1] = label .. "." .. eventName .. "=" .. tostring(ok)
    end

    ----------------------------------------------------
    -- وضع اليد (Gamepad): البطاقة في الحقيبة بس
    -- نستخدم SecurePostHook لأنه ما يخرّب استخدام القطع (عكس تغيير الدوال)
    ----------------------------------------------------
    local function GamepadAnchor(gpTooltips, tooltipType)
        for _, getter in ipairs({ "GetTooltipContainer", "GetTooltip" }) do
            if type(gpTooltips[getter]) == "function" then
                local ok, ctrl = pcall(gpTooltips[getter], gpTooltips, tooltipType)
                if ok and ctrl ~= nil and ctrl.GetLeft then
                    return ctrl
                end
            end
        end
        return GuiRoot
    end

    local gamepadShownType = nil -- أي وصف (يمين/يسار) طلعت جنبه البطاقة

    -- نطلع رابط القطعة من معطيات دالة الوصف: رابط مباشر، أو (حقيبة + خانة)
    local function LinkFromArgs(...)
        local a, b = ...
        if type(a) == "string" and string.find(a, "|H", 1, true) then return a end
        if type(a) == "number" and type(b) == "number" then
            local ok, link = pcall(GetItemLink, a, b)
            if ok and link and link ~= "" then return link end
        end
        return nil
    end

    local GAMEPAD_LAYOUT_METHODS = {
        "LayoutBagItem", "LayoutItem", "LayoutItemWithStackCount",
        "LayoutItemWithStackCountSimple", "LayoutGuildStoreSearchResult",
        "LayoutStoreItem", "LayoutLootItem",
    }

    -- مهم: ما نلمس GAMEPAD_TOOLTIPS:LayoutXxx نفسها. هذي ما هي دوال حقيقية،
    -- اللعبة تحدد اسم الدالة لحظة القراءة، ولو ركّبنا عليها تختلط الأسماء
    -- (مثل خطأ LayoutCurrency لما تفتح صندوق بالكنترول).
    -- بدلها نركّب على كائن الوصف الحقيقي لكل جهة (يمين/يسار/المتحرك).
    local GAMEPAD_TOOLTIP_TYPES = { "GAMEPAD_LEFT_TOOLTIP", "GAMEPAD_RIGHT_TOOLTIP", "GAMEPAD_MOVABLE_TOOLTIP" }

    local function HookGamepadBag()
        if not (GAMEPAD_TOOLTIPS and ZO_GamepadTooltip) then
            hookReport[#hookReport + 1] = "Gamepad=missing"
            return
        end
        if type(SecurePostHook) ~= "function" then
            hookReport[#hookReport + 1] = "Gamepad=noSecureHook"
            return
        end
        local hooked = 0
        for _, typeName in ipairs(GAMEPAD_TOOLTIP_TYPES) do
            local tooltipType = _G[typeName]
            local okTip, tip = pcall(GAMEPAD_TOOLTIPS.GetTooltip, GAMEPAD_TOOLTIPS, tooltipType)
            if tooltipType and okTip and tip then
                for _, methodName in ipairs(GAMEPAD_LAYOUT_METHODS) do
                    local okGet, fn = pcall(function() return tip[methodName] end)
                    if okGet and type(fn) == "function" then
                        local ok = pcall(SecurePostHook, tip, methodName, function(_, ...)
                            if not IsInGamepadPreferredMode() then return end
                            local link = LinkFromArgs(...)
                            if not link then return end
                            gamepadShownType = tooltipType
                            local okShow, err = pcall(ShowCardFor, GamepadAnchor(GAMEPAD_TOOLTIPS, tooltipType), link)
                            if not okShow and cardDebug then d("ArabicHelper gamepad card error: " .. tostring(err)) end
                        end)
                        if ok then hooked = hooked + 1 end
                    end
                end
            end
        end
        -- نركّب على دالة الكلاس (مو الكائن) عشان ما نخرّب ركّبات الأدونات الثانية
        local okClear = pcall(SecurePostHook, ZO_GamepadTooltip, "ClearTooltip", function(_, tooltipType)
            if IsInGamepadPreferredMode() and tooltipType == gamepadShownType then
                gamepadShownType = nil
                HideCard()
            end
        end)
        hookReport[#hookReport + 1] = "Gamepad=" .. hooked .. " clear=" .. tostring(okClear)
    end

    local cardHooked = false
    EVENT_MANAGER:RegisterForEvent("ArabicHelper_Card", EVENT_PLAYER_ACTIVATED, function()
        if cardHooked then return end
        cardHooked = true
        EVENT_MANAGER:UnregisterForEvent("ArabicHelper_Card", EVENT_PLAYER_ACTIVATED)
        AddHandler(ItemTooltip, "ItemTooltip", "OnAddGameData", OnItemTooltipData)
        AddHandler(ItemTooltip, "ItemTooltip", "OnHide", HideCard)
        AddHandler(PopupTooltip, "PopupTooltip", "OnAddGameData", OnPopupTooltipData)
        AddHandler(PopupTooltip, "PopupTooltip", "OnHide", HideCard)
        HookGamepadBag()
    end)

    ----------------------------------------------------
    -- زر تشغيل / إيقاف بطاقة الست (للي ما يبيها تطلع لما يأشر على القطعة)
    ----------------------------------------------------
    local cardToggleBtn = WINDOW_MANAGER:CreateControl("$(parent)CardToggleBtn", myWindow, CT_BUTTON)
    cardToggleBtn:SetDimensions(44, 44)
    cardToggleBtn:SetAnchor(TOPLEFT, myWindow, TOPLEFT, 287, 6)
    ApplyIcon(cardToggleBtn, {
        up   = "/esoui/art/inventory/inventory_tabicon_armor_up.dds",
        over = "/esoui/art/inventory/inventory_tabicon_armor_over.dds",
        down = "/esoui/art/inventory/inventory_tabicon_armor_down.dds",
    })

    local function CardToggleText()
        return "Set card on hover: " .. ((savedVars.showCard ~= false) and "ON" or "OFF")
    end

    -- شغال = واضح ، مطفي = باهت
    local function UpdateCardToggleLook()
        cardToggleBtn:SetAlpha((savedVars.showCard ~= false) and 1 or 0.35)
    end

    cardToggleBtn:SetHandler("OnClicked", function(self)
        savedVars.showCard = (savedVars.showCard == false)
        HideCard()
        UpdateCardToggleLook()
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -5)
        SetTooltipText(InformationTooltip, CardToggleText())
    end)
    cardToggleBtn:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -5)
        SetTooltipText(InformationTooltip, CardToggleText())
    end)
    cardToggleBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    UpdateCardToggleLook()

    ----------------------------------------------------
    -- أوامر الفتح والإغلاق
    ----------------------------------------------------
    SLASH_COMMANDS["/arhelper"] = function(arg)
        -- /arhelper card = تشغيل / إيقاف بطاقة الست جنب وصف القطعة
        -- /arhelper carddebug = يطبع في الشات وش يصير لما تأشر على قطعة (للتشخيص)
        if arg and string.lower(arg) == "carddebug" then
            cardDebug = not cardDebug
            d("ArabicHelper: card debug " .. (cardDebug and "ON" or "OFF")
              .. " | card=" .. tostring(savedVars.showCard) .. " | hooks: " .. table.concat(hookReport, ", "))
            return
        end
        if arg and string.lower(arg) == "card" then
            savedVars.showCard = (savedVars.showCard == false)
            HideCard()
            UpdateCardToggleLook()
            d("ArabicHelper: set card " .. (savedVars.showCard and "ON" or "OFF"))
            return
        end
        local isHidden = not myWindow:IsHidden()
        myWindow:SetHidden(isHidden)
        if isHidden then
            buffsWindow:SetHidden(true)
            if trialsWindow then trialsWindow:SetHidden(true) end
        if termsWindow then termsWindow:SetHidden(true) end
        end 
        if not isHidden then 
            favoritesMode = false
            UpdateFavoriteButtonColor()
            searchBox:SetText("Type here to search...")
            currentCategory = "" 
            UpdateActiveTabColor("All") -- تصفير اللون لخانة All عند الفتح
            myWindow.UpdateResults("") 
        end
    end

    AH.ToggleWindow = function()
        local isHidden = not myWindow:IsHidden()
        myWindow:SetHidden(isHidden)
        -- لما تنفتح بزر الاختصار نطلّع الماوس عشان تقدر تتحكم بالنافذة
        if not isHidden and not IsGameCameraUIModeActive() then
            SetGameCameraUIMode(true)
        end
        if isHidden then
            buffsWindow:SetHidden(true)
            if trialsWindow then trialsWindow:SetHidden(true) end
        if termsWindow then termsWindow:SetHidden(true) end
        end
        if not isHidden then 
            favoritesMode = false
            UpdateFavoriteButtonColor()
            searchBox:SetText("Type here to search...")
            currentCategory = ""
            UpdateActiveTabColor("All") -- تصفير اللون لخانة All عند الفتح
            myWindow.UpdateResults("") 
        end
    end
end

EVENT_MANAGER:RegisterForEvent("ArabicHelper", EVENT_ADD_ON_LOADED, OnAddOnLoaded)