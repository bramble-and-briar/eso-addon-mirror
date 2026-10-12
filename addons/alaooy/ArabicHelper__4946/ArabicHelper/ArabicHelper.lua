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

-- تعريف قاعدة بيانات الستات
local setsDatabase = {
    {name = "Abyssal Brace", icon = "ArabicHelper/images/set1.dds", category = "Dungeon"},
    {name = "Aegis Caller", icon = "ArabicHelper/images/set2.dds", category = "Dungeon"},
    {name = "Amber Plasm", icon = "ArabicHelper/images/set3.dds", category = "Dungeon"},
    {name = "Apocryphal Inspiration", icon = "ArabicHelper/images/set4.dds", category = "Dungeon"},
    {name = "Arkasis's Genius", icon = "ArabicHelper/images/set5.dds", category = "Dungeon"},
    {name = "Armor of Truth", icon = "ArabicHelper/images/set6.dds", category = "Dungeon"},
    {name = "Aspect of Mazzatun", icon = "ArabicHelper/images/set7.dds", category = "Dungeon"},
    {name = "Auroran's Thunder", icon = "ArabicHelper/images/set8.dds", category = "Dungeon"},
    {name = "Azureblight Reaper", icon = "ArabicHelper/images/set9.dds", category = "Dungeon"},
    {name = "Bani's Torment", icon = "ArabicHelper/images/set10.dds", category = "Dungeon"},
    {name = "Barkskin", icon = "ArabicHelper/images/set11.dds", category = "Dungeon"},
    {name = "Black Foundry Steel", icon = "ArabicHelper/images/set12.dds", category = "Dungeon"},
    {name = "Black-Glove Grounding", icon = "ArabicHelper/images/set13.dds", category = "Dungeon"},
    {name = "Blind Path Induction", icon = "ArabicHelper/images/set14.dds", category = "Dungeon"},
    {name = "Blood Moon", icon = "ArabicHelper/images/set15.dds", category = "Dungeon"},
    {name = "Blooddrinker", icon = "ArabicHelper/images/set16.dds", category = "Dungeon"},
    {name = "Bone Pirate's Tatters", icon = "ArabicHelper/images/set17.dds", category = "Dungeon"},
    {name = "Brands of Imperium", icon = "ArabicHelper/images/set18.dds", category = "Dungeon"},
    {name = "Burning Spellweave", icon = "ArabicHelper/images/set19.dds", category = "Dungeon"},
    {name = "Caluurion's Legacy", icon = "ArabicHelper/images/set20.dds", category = "Dungeon"},
    {name = "Cinders of Anthelmir", icon = "ArabicHelper/images/set21.dds", category = "Dungeon"},
    {name = "Combat Physician", icon = "ArabicHelper/images/set22.dds", category = "Dungeon"},
    {name = "Crimson Oath's Rive", icon = "ArabicHelper/images/set23.dds", category = "Dungeon"},
    {name = "Crimson Twilight", icon = "ArabicHelper/images/set24.dds", category = "Dungeon"},
    {name = "Crusader", icon = "ArabicHelper/images/set25.dds", category = "Dungeon"},
    {name = "Curse of Doylemish", icon = "ArabicHelper/images/set26.dds", category = "Dungeon"},
    {name = "Dagon's Dominion", icon = "ArabicHelper/images/set27.dds", category = "Dungeon"},
    {name = "Deeproot Zeal", icon = "ArabicHelper/images/set28.dds", category = "Dungeon"},
    {name = "Dragon's Defilement", icon = "ArabicHelper/images/set29.dds", category = "Dungeon"},
    {name = "Drake's Rush", icon = "ArabicHelper/images/set30.dds", category = "Dungeon"},
    {name = "Draugr Hulk", icon = "ArabicHelper/images/set31.dds", category = "Dungeon"},
    {name = "Draugr's Rest", icon = "ArabicHelper/images/set32.dds", category = "Dungeon"},
    {name = "Draugrkin's Grip", icon = "ArabicHelper/images/set33.dds", category = "Dungeon"},
    {name = "Dreugh King Slayer", icon = "ArabicHelper/images/set34.dds", category = "Dungeon"},
    {name = "Dro'Zakar's Claws", icon = "ArabicHelper/images/set35.dds", category = "Dungeon"},
    {name = "Duneripper's Scales", icon = "ArabicHelper/images/set36.dds", category = "Dungeon"},
    {name = "Durok's Bane", icon = "ArabicHelper/images/set37.dds", category = "Dungeon"},
    {name = "Ebon Armory", icon = "ArabicHelper/images/set38.dds", category = "Dungeon"},
    {name = "Elemental Catalyst", icon = "ArabicHelper/images/set39.dds", category = "Dungeon"},
    {name = "Embershield", icon = "ArabicHelper/images/set40.dds", category = "Dungeon"},
    {name = "Essence Thief", icon = "ArabicHelper/images/set41.dds", category = "Dungeon"},
    {name = "Flame Blossom", icon = "ArabicHelper/images/set42.dds", category = "Dungeon"},
    {name = "Fledgling's Nest", icon = "ArabicHelper/images/set43.dds", category = "Dungeon"},
    {name = "Foolkiller's Ward", icon = "ArabicHelper/images/set44.dds", category = "Dungeon"},
    {name = "Frozen Watcher", icon = "ArabicHelper/images/set45.dds", category = "Dungeon"},
    {name = "Glacial Guardian", icon = "ArabicHelper/images/set46.dds", category = "Dungeon"},
    {name = "Gossamer", icon = "ArabicHelper/images/set47.dds", category = "Dungeon"},
    {name = "Grave Guardian", icon = "ArabicHelper/images/set48.dds", category = "Dungeon"},
    {name = "Grave Inevitability", icon = "ArabicHelper/images/set49.dds", category = "Dungeon"},
    {name = "Grisly Gourmet", icon = "ArabicHelper/images/set50.dds", category = "Dungeon"},
    {name = "Gryphon's Reprisal", icon = "ArabicHelper/images/set51.dds", category = "Dungeon"},
    {name = "Hagraven's Garden", icon = "ArabicHelper/images/set52.dds", category = "Dungeon"},
    {name = "Hand of Mephala", icon = "ArabicHelper/images/set53.dds", category = "Dungeon"},
    {name = "Hanu's Compassion", icon = "ArabicHelper/images/set54.dds", category = "Dungeon"},
    {name = "Haven of Ursus", icon = "ArabicHelper/images/set55.dds", category = "Dungeon"},
    {name = "Heem-Jas' Retribution", icon = "ArabicHelper/images/set56.dds", category = "Dungeon"},
    {name = "Heroic Unity", icon = "ArabicHelper/images/set57.dds", category = "Dungeon"},
    {name = "Hircine's Veneer", icon = "ArabicHelper/images/set58.dds", category = "Dungeon"},
    {name = "Hiti's Hearth", icon = "ArabicHelper/images/set59.dds", category = "Dungeon"},
    {name = "Hollowfang Thirst", icon = "ArabicHelper/images/set60.dds", category = "Dungeon"},
    {name = "Icy Conjurer", icon = "ArabicHelper/images/set61.dds", category = "Dungeon"},
    {name = "Ironblood", icon = "ArabicHelper/images/set62.dds", category = "Dungeon"},
    {name = "Jailbreaker", icon = "ArabicHelper/images/set63.dds", category = "Dungeon"},
    {name = "Jailer's Tenacity", icon = "ArabicHelper/images/set64.dds", category = "Dungeon"},
    {name = "Jerensi's Bladestorm", icon = "ArabicHelper/images/set65.dds", category = "Dungeon"},
    {name = "Jolting Arms", icon = "ArabicHelper/images/set66.dds", category = "Dungeon"},
    {name = "Jorvuld's Guidance", icon = "ArabicHelper/images/set67.dds", category = "Dungeon"},
    {name = "Kinras's Wrath", icon = "ArabicHelper/images/set68.dds", category = "Dungeon"},
    {name = "Knight-Errant's Mail", icon = "ArabicHelper/images/set69.dds", category = "Dungeon"},
    {name = "Knightmare", icon = "ArabicHelper/images/set70.dds", category = "Dungeon"},
    {name = "Kraglen's Howl", icon = "ArabicHelper/images/set71.dds", category = "Dungeon"},
    {name = "Lamia's Song", icon = "ArabicHelper/images/set72.dds", category = "Dungeon"},
    {name = "Leeching Plate", icon = "ArabicHelper/images/set73.dds", category = "Dungeon"},
    {name = "Leviathan", icon = "ArabicHelper/images/set74.dds", category = "Dungeon"},
    {name = "Light Speaker", icon = "ArabicHelper/images/set75.dds", category = "Dungeon"},
    {name = "Lucilla's Windshield", icon = "ArabicHelper/images/set76.dds", category = "Dungeon"},
    {name = "Lustrous Soulwell", icon = "ArabicHelper/images/set77.dds", category = "Dungeon"},
    {name = "Magicka Furnace", icon = "ArabicHelper/images/set78.dds", category = "Dungeon"},
    {name = "Maligalig's Maelstrom", icon = "ArabicHelper/images/set79.dds", category = "Dungeon"},
    {name = "Medusa", icon = "ArabicHelper/images/set80.dds", category = "Dungeon"},
    {name = "Mighty Glacier", icon = "ArabicHelper/images/set81.dds", category = "Dungeon"},
    {name = "Moon Hunter", icon = "ArabicHelper/images/set82.dds", category = "Dungeon"},
    {name = "Netch's Touch", icon = "ArabicHelper/images/set83.dds", category = "Dungeon"},
    {name = "Nikulas' Heavy Armor", icon = "ArabicHelper/images/set84.dds", category = "Dungeon"},
    {name = "Nix-Hound's Howl", icon = "ArabicHelper/images/set85.dds", category = "Dungeon"},
    {name = "Noble Duelist's Silks", icon = "ArabicHelper/images/set86.dds", category = "Dungeon"},
    {name = "Noxious Boulder", icon = "ArabicHelper/images/set87.dds", category = "Dungeon"},
    {name = "Oblivion's Edge", icon = "ArabicHelper/images/set88.dds", category = "Dungeon"},
    {name = "Overwhelming Surge", icon = "ArabicHelper/images/set89.dds", category = "Dungeon"},
    {name = "Pangrit Denmother", icon = "ArabicHelper/images/set90.dds", category = "Dungeon"},
    {name = "Phylactery's Grasp", icon = "ArabicHelper/images/set91.dds", category = "Dungeon"},
    {name = "Pillar of Nirn", icon = "ArabicHelper/images/set92.dds", category = "Dungeon"},
    {name = "Plague Slinger", icon = "ArabicHelper/images/set93.dds", category = "Dungeon"},
    {name = "Prayer Shawl", icon = "ArabicHelper/images/set94.dds", category = "Dungeon"},
    {name = "Rage of the Ursauk", icon = "ArabicHelper/images/set95.dds", category = "Dungeon"},
    {name = "Rattlecage", icon = "ArabicHelper/images/set96.dds", category = "Dungeon"},
    {name = "Reflected Fury", icon = "ArabicHelper/images/set97.dds", category = "Dungeon"},
    {name = "Renald's Resolve", icon = "ArabicHelper/images/set98.dds", category = "Dungeon"},
    {name = "Ritemaster's Bond", icon = "ArabicHelper/images/set99.dds", category = "Dungeon"},
    {name = "Runecarver's Blaze", icon = "ArabicHelper/images/set100.dds", category = "Dungeon"},
    {name = "Rush of Agony", icon = "ArabicHelper/images/set101.dds", category = "Dungeon"},
    {name = "Sanctuary", icon = "ArabicHelper/images/set102.dds", category = "Dungeon"},
    {name = "Savage Werewolf", icon = "ArabicHelper/images/set103.dds", category = "Dungeon"},
    {name = "Scathing Mage", icon = "ArabicHelper/images/set104.dds", category = "Dungeon"},
    {name = "Scavenging Demise", icon = "ArabicHelper/images/set105.dds", category = "Dungeon"},
    {name = "Scorion's Feast", icon = "ArabicHelper/images/set106.dds", category = "Dungeon"},
    {name = "Sergeant's Mail", icon = "ArabicHelper/images/set107.dds", category = "Dungeon"},
    {name = "Sheer Venom", icon = "ArabicHelper/images/set108.dds", category = "Dungeon"},
    {name = "Shroud of the Lich", icon = "ArabicHelper/images/set109.dds", category = "Dungeon"},
    {name = "Silver Rose Vigil", icon = "ArabicHelper/images/set110.dds", category = "Dungeon"},
    {name = "Sluthrug's Hunger", icon = "ArabicHelper/images/set111.dds", category = "Dungeon"},
    {name = "Spell Power Cure", icon = "ArabicHelper/images/set112.dds", category = "Dungeon"},
    {name = "Spelunker", icon = "ArabicHelper/images/set113.dds", category = "Dungeon"},
    {name = "Spider Cultist Cowl", icon = "ArabicHelper/images/set114.dds", category = "Dungeon"},
    {name = "Spriggan's Vigor", icon = "ArabicHelper/images/set115.dds", category = "Dungeon"},
    {name = "Stone's Accord", icon = "ArabicHelper/images/set116.dds", category = "Dungeon"},
    {name = "Stonehulk Domination", icon = "ArabicHelper/images/set117.dds", category = "Dungeon"},
    {name = "Storm Master", icon = "ArabicHelper/images/set118.dds", category = "Dungeon"},
    {name = "Storm-Cursed's Revenge", icon = "ArabicHelper/images/set119.dds", category = "Dungeon"},
    {name = "Strength of the Automaton", icon = "ArabicHelper/images/set120.dds", category = "Dungeon"},
    {name = "Sunderflame", icon = "ArabicHelper/images/set121.dds", category = "Dungeon"},
    {name = "Sword Dancer", icon = "ArabicHelper/images/set122.dds", category = "Dungeon"},
    {name = "Talfyg's Treachery", icon = "ArabicHelper/images/set123.dds", category = "Dungeon"},
    {name = "Tarnished Nightmare", icon = "ArabicHelper/images/set124.dds", category = "Dungeon"},
    {name = "Telvanni Enforcer", icon = "ArabicHelper/images/set125.dds", category = "Dungeon"},
    {name = "The Ice Furnace", icon = "ArabicHelper/images/set126.dds", category = "Dungeon"},
    {name = "The Worm's Raiment", icon = "ArabicHelper/images/set127.dds", category = "Dungeon"},
    {name = "Thunder Caller", icon = "ArabicHelper/images/set128.dds", category = "Dungeon"},
    {name = "Titanborn Strength", icon = "ArabicHelper/images/set129.dds", category = "Dungeon"},
    {name = "Tools of the Trapmaster", icon = "ArabicHelper/images/set130.dds", category = "Dungeon"},
    {name = "Toothrow", icon = "ArabicHelper/images/set131.dds", category = "Dungeon"},
    {name = "Tormentor", icon = "ArabicHelper/images/set132.dds", category = "Dungeon"},
    {name = "Trappings of Invigoration", icon = "ArabicHelper/images/set133.dds", category = "Dungeon"},
    {name = "Treasure Hunter", icon = "ArabicHelper/images/set134.dds", category = "Dungeon"},
    {name = "True-Sworn Fury", icon = "ArabicHelper/images/set135.dds", category = "Dungeon"},
    {name = "Turning Tide", icon = "ArabicHelper/images/set136.dds", category = "Dungeon"},
    {name = "Tzogvin's Warband", icon = "ArabicHelper/images/set137.dds", category = "Dungeon"},
    {name = "Ulfnor's Favor", icon = "ArabicHelper/images/set138.dds", category = "Dungeon"},
    {name = "Undaunted Bastion", icon = "ArabicHelper/images/set139.dds", category = "Dungeon"},
    {name = "Undaunted Infiltrator", icon = "ArabicHelper/images/set140.dds", category = "Dungeon"},
    {name = "Undaunted Unweaver", icon = "ArabicHelper/images/set141.dds", category = "Dungeon"},
    {name = "Unleashed Ritualist", icon = "ArabicHelper/images/set142.dds", category = "Dungeon"},
    {name = "Unleashed Terror", icon = "ArabicHelper/images/set143.dds", category = "Dungeon"},
    {name = "Vandorallen's Resonance", icon = "ArabicHelper/images/set144.dds", category = "Dungeon"},
    {name = "Vestments of the Warlock", icon = "ArabicHelper/images/set145.dds", category = "Dungeon"},
    {name = "Viper's Sting", icon = "ArabicHelper/images/set146.dds", category = "Dungeon"},
    {name = "Vykand's Soulfury", icon = "ArabicHelper/images/set147.dds", category = "Dungeon"},
    {name = "Widowmaker", icon = "ArabicHelper/images/set148.dds", category = "Dungeon"},
    {name = "Xanmeer Spellweaver", icon = "ArabicHelper/images/set149.dds", category = "Dungeon"},
    {name = "Z'en's Redress", icon = "ArabicHelper/images/set150.dds", category = "Dungeon"},
    -- ===== قسم الترايلات (Trials) =====
    {name = "Perfected Aegis of Galenwe", icon = "ArabicHelper/images/tril1.dds", category = "Trial"},
    {name = "Perfected Ansuul's Torment", icon = "ArabicHelper/images/tril2.dds", category = "Trial"},
    {name = "Perfected Arms of Relequen", icon = "ArabicHelper/images/tril3.dds", category = "Trial"},
    {name = "Perfected Bahsei's Mania", icon = "ArabicHelper/images/tril4.dds", category = "Trial"},
    {name = "Perfected Chaotic Whirlwind", icon = "ArabicHelper/images/tril5.dds", category = "Trial"},
    {name = "Perfected Claw of Yolnahkriin", icon = "ArabicHelper/images/tril6.dds", category = "Trial"},
    {name = "Perfected Concentrated Force", icon = "ArabicHelper/images/tril7.dds", category = "Trial"},
    {name = "Perfected Coral Riptide", icon = "ArabicHelper/images/tril8.dds", category = "Trial"},
    {name = "Perfected Defensive Position", icon = "ArabicHelper/images/tril9.dds", category = "Trial"},
    {name = "Perfected Disciplined Slash", icon = "ArabicHelper/images/tril10.dds", category = "Trial"},
    {name = "Perfected Dolorous Arena", icon = "ArabicHelper/images/tril11.dds", category = "Trial"},
    {name = "Perfected Eye of Nahviintaas", icon = "ArabicHelper/images/tril12.dds", category = "Trial"},
    {name = "Perfected False God's Devotion", icon = "ArabicHelper/images/tril13.dds", category = "Trial"},
    {name = "Perfected Harmony in Chaos", icon = "ArabicHelper/images/tril14.dds", category = "Trial"},
    {name = "Perfected Kazpian's Cruel Signet", icon = "ArabicHelper/images/tril15.dds", category = "Trial"},
    {name = "Perfected Kyne's Wind", icon = "ArabicHelper/images/tril16.dds", category = "Trial"},
    {name = "Perfected Lucent Echoes", icon = "ArabicHelper/images/tril17.dds", category = "Trial"},
    {name = "Perfected Mantle of Siroria", icon = "ArabicHelper/images/tril18.dds", category = "Trial"},
    {name = "Perfected Mora Scribe's Thesis", icon = "ArabicHelper/images/tril19.dds", category = "Trial"},
    {name = "Perfected Peace and Serenity", icon = "ArabicHelper/images/tril20.dds", category = "Trial"},
    {name = "Perfected Pearlescent Ward", icon = "ArabicHelper/images/tril21.dds", category = "Trial"},
    {name = "Perfected Piercing Spray", icon = "ArabicHelper/images/tril22.dds", category = "Trial"},
    {name = "Perfected Pillager's Profit", icon = "ArabicHelper/images/tril23.dds", category = "Trial"},
    {name = "Perfected Recovery Convergence", icon = "ArabicHelper/images/tril24.dds", category = "Trial"},
    {name = "Perfected Roaring Opportunist", icon = "ArabicHelper/images/tril25.dds", category = "Trial"},
    {name = "Perfected Saxhleel Champion", icon = "ArabicHelper/images/tril26.dds", category = "Trial"},
    {name = "Perfected Slivers of the Null Arca", icon = "ArabicHelper/images/tril27.dds", category = "Trial"},
    {name = "Perfected Stone-Talker's Oath", icon = "ArabicHelper/images/tril28.dds", category = "Trial"},
    {name = "Perfected Sul-Xan's Torment", icon = "ArabicHelper/images/tril29.dds", category = "Trial"},
    {name = "Perfected Test of Resolve", icon = "ArabicHelper/images/tril30.dds", category = "Trial"},
    {name = "Perfected Timeless Blessing", icon = "ArabicHelper/images/tril31.dds", category = "Trial"},
    {name = "Perfected Tooth of Lokkestiiz", icon = "ArabicHelper/images/tril32.dds", category = "Trial"},
    {name = "Perfected Transformative Hope", icon = "ArabicHelper/images/tril33.dds", category = "Trial"},
    {name = "Perfected Vestment of Olorime", icon = "ArabicHelper/images/tril34.dds", category = "Trial"},
    {name = "Perfected Vrol's Command", icon = "ArabicHelper/images/tril35.dds", category = "Trial"},
    {name = "Perfected Whorl of the Depths", icon = "ArabicHelper/images/tril36.dds", category = "Trial"},
    {name = "Perfected Xoryn's Masterpiece", icon = "ArabicHelper/images/tril37.dds", category = "Trial"},
    {name = "Perfected Yandir's Might", icon = "ArabicHelper/images/tril38.dds", category = "Trial"},
    {name = "Defending Warrior", icon = "ArabicHelper/images/tril39.dds", category = "Trial"},
    {name = "Healing Mage", icon = "ArabicHelper/images/tril40.dds", category = "Trial"},
    {name = "Quick Serpent", icon = "ArabicHelper/images/tril41.dds", category = "Trial"},
    {name = "Berserking Warrior", icon = "ArabicHelper/images/tril42.dds", category = "Trial"},
    {name = "Destructive Mage", icon = "ArabicHelper/images/tril43.dds", category = "Trial"},
    {name = "Poisonous Serpent", icon = "ArabicHelper/images/tril44.dds", category = "Trial"},
    {name = "Immortal Warrior", icon = "ArabicHelper/images/tril45.dds", category = "Trial"},
    {name = "Twice-Fanged Serpent", icon = "ArabicHelper/images/tril46.dds", category = "Trial"},
    {name = "Wise Mage", icon = "ArabicHelper/images/tril47.dds", category = "Trial"},
    {name = "Lunar Bastion", icon = "ArabicHelper/images/tril48.dds", category = "Trial"},
    {name = "Moondancer", icon = "ArabicHelper/images/tril49.dds", category = "Trial"},
    {name = "Roar of Alkosh", icon = "ArabicHelper/images/tril50.dds", category = "Trial"},
    {name = "Twilight Remedy", icon = "ArabicHelper/images/tril51.dds", category = "Trial"},
    {name = "Automated Defense", icon = "ArabicHelper/images/tril52.dds", category = "Trial"},
    {name = "Inventor's Guard", icon = "ArabicHelper/images/tril53.dds", category = "Trial"},
    {name = "Master Architect", icon = "ArabicHelper/images/tril54.dds", category = "Trial"},
    {name = "War Machine", icon = "ArabicHelper/images/tril55.dds", category = "Trial"},
    {name = "Eternal Warrior", icon = "ArabicHelper/images/tril56.dds", category = "Trial"},
    {name = "Infallible Mage", icon = "ArabicHelper/images/tril57.dds", category = "Trial"},
    {name = "Vicious Serpent", icon = "ArabicHelper/images/tril58.dds", category = "Trial"},
    -- ===== قسم أطقم الوحوش (Monster Sets) =====
  {name = "Anthelmir's Construct", icon = "ArabicHelper/images/mo1.dds", category = "Monster"},
    {name = "Archdruid Devyric", icon = "ArabicHelper/images/mo2.dds", category = "Monster"},
    {name = "Balorgh", icon = "ArabicHelper/images/mo3.dds", category = "Monster"},
    {name = "Bar-Sakka", icon = "ArabicHelper/images/mo4.dds", category = "Monster"},
    {name = "Baron Thirsk", icon = "ArabicHelper/images/mo5.dds", category = "Monster"},
    {name = "Baron Zaudrus", icon = "ArabicHelper/images/mo6.dds", category = "Monster"},
    {name = "Black Gem Monstrosity", icon = "ArabicHelper/images/mo7.dds", category = "Monster"},
    {name = "Bloodspawn", icon = "ArabicHelper/images/mo8.dds", category = "Monster"},
    {name = "Chokethorn", icon = "ArabicHelper/images/mo9.dds", category = "Monster"},
    {name = "Domihaus", icon = "ArabicHelper/images/mo10.dds", category = "Monster"},
    {name = "Earthgore", icon = "ArabicHelper/images/mo11.dds", category = "Monster"},
    {name = "Encratis's Behemoth", icon = "ArabicHelper/images/mo12.dds", category = "Monster"},
    {name = "Engine Guardian", icon = "ArabicHelper/images/mo13.dds", category = "Monster"},
    {name = "Euphotic Gatekeeper", icon = "ArabicHelper/images/mo14.dds", category = "Monster"},
    {name = "Glittering Goad", icon = "ArabicHelper/images/mo15.dds", category = "Monster"},
    {name = "Glorgoloch the Destroyer", icon = "ArabicHelper/images/mo16.dds", category = "Monster"},
    {name = "Grothdarr", icon = "ArabicHelper/images/mo17.dds", category = "Monster"},
    {name = "Grundwulf", icon = "ArabicHelper/images/mo18.dds", category = "Monster"},
    {name = "Iceheart", icon = "ArabicHelper/images/mo19.dds", category = "Monster"},
    {name = "Ilambris", icon = "ArabicHelper/images/mo20.dds", category = "Monster"},
    {name = "Immolator Charr", icon = "ArabicHelper/images/mo21.dds", category = "Monster"},
    {name = "Infernal Guardian", icon = "ArabicHelper/images/mo22.dds", category = "Monster"},
    {name = "Kargaeda", icon = "ArabicHelper/images/mo23.dds", category = "Monster"},
    {name = "Kjalnar's Nightmare", icon = "ArabicHelper/images/mo24.dds", category = "Monster"},
    {name = "Kra'gh", icon = "ArabicHelper/images/mo25.dds", category = "Monster"},
    {name = "Lady Malygda", icon = "ArabicHelper/images/mo26.dds", category = "Monster"},
    {name = "Lady Thorn", icon = "ArabicHelper/images/mo27.dds", category = "Monster"},
    {name = "Lord Warden", icon = "ArabicHelper/images/mo28.dds", category = "Monster"},
    {name = "Maarselok", icon = "ArabicHelper/images/mo29.dds", category = "Monster"},
    {name = "Magma Incarnate", icon = "ArabicHelper/images/mo30.dds", category = "Monster"},
    {name = "Maw of the Infernal", icon = "ArabicHelper/images/mo31.dds", category = "Monster"},
    {name = "Mighty Chudan", icon = "ArabicHelper/images/mo32.dds", category = "Monster"},
    {name = "Molag Kena", icon = "ArabicHelper/images/mo33.dds", category = "Monster"},
    {name = "Mother Ciannait", icon = "ArabicHelper/images/mo34.dds", category = "Monster"},
    {name = "Nazaray", icon = "ArabicHelper/images/mo35.dds", category = "Monster"},
    {name = "Nerien'eth", icon = "ArabicHelper/images/mo36.dds", category = "Monster"},
    {name = "Nightflame", icon = "ArabicHelper/images/mo37.dds", category = "Monster"},
    {name = "Nunatak", icon = "ArabicHelper/images/mo38.dds", category = "Monster"},
    {name = "Orpheon the Tactician", icon = "ArabicHelper/images/mo39.dds", category = "Monster"},
    {name = "Ozezan the Inferno", icon = "ArabicHelper/images/mo40.dds", category = "Monster"},
    {name = "Pirate Skeleton", icon = "ArabicHelper/images/mo41.dds", category = "Monster"},
    {name = "Prior Thierric", icon = "ArabicHelper/images/mo42.dds", category = "Monster"},
    {name = "Roksa the Warped", icon = "ArabicHelper/images/mo43.dds", category = "Monster"},
    {name = "Scourge Harvester", icon = "ArabicHelper/images/mo44.dds", category = "Monster"},
    {name = "Selene", icon = "ArabicHelper/images/mo45.dds", category = "Monster"},
    {name = "Sellistrix", icon = "ArabicHelper/images/mo46.dds", category = "Monster"},
    {name = "Sentinel of Rkugamz", icon = "ArabicHelper/images/mo47.dds", category = "Monster"},
    {name = "Shadowrend", icon = "ArabicHelper/images/mo48.dds", category = "Monster"},
    {name = "Slimecraw", icon = "ArabicHelper/images/mo49.dds", category = "Monster"},
    {name = "Spawn of Mephala", icon = "ArabicHelper/images/mo50.dds", category = "Monster"},
    {name = "Squall of Retribution", icon = "ArabicHelper/images/mo51.dds", category = "Monster"},
    {name = "Stone Husk", icon = "ArabicHelper/images/mo52.dds", category = "Monster"},
    {name = "Stonekeeper", icon = "ArabicHelper/images/mo53.dds", category = "Monster"},
    {name = "Stormfist", icon = "ArabicHelper/images/mo54.dds", category = "Monster"},
    {name = "Swarm Mother", icon = "ArabicHelper/images/mo55.dds", category = "Monster"},
    {name = "Symphony of Blades", icon = "ArabicHelper/images/mo56.dds", category = "Monster"},
    {name = "The Blind", icon = "ArabicHelper/images/mo57.dds", category = "Monster"},
    {name = "The Ruckus", icon = "ArabicHelper/images/mo58.dds", category = "Monster"},
    {name = "The Troll King", icon = "ArabicHelper/images/mo59.dds", category = "Monster"},
    {name = "Thousand Eyes", icon = "ArabicHelper/images/mo60.dds", category = "Monster"},
    {name = "Thurvokun", icon = "ArabicHelper/images/mo61.dds", category = "Monster"},
    {name = "Tremorscale", icon = "ArabicHelper/images/mo62.dds", category = "Monster"},
    {name = "Valkyn Skoria", icon = "ArabicHelper/images/mo63.dds", category = "Monster"},
    {name = "Velidreth", icon = "ArabicHelper/images/mo64.dds", category = "Monster"},
    {name = "Vykosa", icon = "ArabicHelper/images/mo65.dds", category = "Monster"},
    {name = "Zaan", icon = "ArabicHelper/images/mo66.dds", category = "Monster"},
      {name = "Zoal the Ever-Wakeful", icon = "ArabicHelper/images/mo67.dds", category = "Monster"},
	  -- ===== قسم أطقم الكرافت (Craftable Sets) =====
    {name = "Adept Rider", icon = "ArabicHelper/images/cr1.dds", category = "craftable"},
    {name = "Aetherial Ascension", icon = "ArabicHelper/images/cr2.dds", category = "craftable"},
    {name = "Alessia's Bulwark", icon = "ArabicHelper/images/cr3.dds", category = "craftable"},
    {name = "Ancient Dragonguard", icon = "ArabicHelper/images/cr4.dds", category = "craftable"},
    {name = "Armor Master", icon = "ArabicHelper/images/cr5.dds", category = "craftable"},
    {name = "Armor of the Seducer", icon = "ArabicHelper/images/cr6.dds", category = "craftable"},
    {name = "Ashen Grip", icon = "ArabicHelper/images/cr7.dds", category = "craftable"},
    {name = "Assassin's Guile", icon = "ArabicHelper/images/cr8.dds", category = "craftable"},
    {name = "Chimera's Rebuke", icon = "ArabicHelper/images/cr9.dds", category = "craftable"},
    {name = "Claw of the Forest Wraith", icon = "ArabicHelper/images/cr10.dds", category = "craftable"},
    {name = "Clever Alchemist", icon = "ArabicHelper/images/cr11.dds", category = "craftable"},
    {name = "Coldharbour's Favorite", icon = "ArabicHelper/images/cr12.dds", category = "craftable"},
    {name = "Critical Riposte", icon = "ArabicHelper/images/cr13.dds", category = "craftable"},
    {name = "Daedric Trickery", icon = "ArabicHelper/images/cr14.dds", category = "craftable"},
    {name = "Daring Corsair", icon = "ArabicHelper/images/cr15.dds", category = "craftable"},
    {name = "Dauntless Combatant", icon = "ArabicHelper/images/cr16.dds", category = "craftable"},
    {name = "Deadlands Demolisher", icon = "ArabicHelper/images/cr17.dds", category = "craftable"},
    {name = "Death's Wind", icon = "ArabicHelper/images/cr18.dds", category = "craftable"},
    {name = "Diamond's Victory", icon = "ArabicHelper/images/cr19.dds", category = "craftable"},
    {name = "Dragon's Appetite", icon = "ArabicHelper/images/cr20.dds", category = "craftable"},
    {name = "Druid's Braid", icon = "ArabicHelper/images/cr21.dds", category = "craftable"},
    {name = "Eternal Hunt", icon = "ArabicHelper/images/cr22.dds", category = "craftable"},
    {name = "Eyes of Mara", icon = "ArabicHelper/images/cr23.dds", category = "craftable"},
    {name = "Fellowship's Fortitude", icon = "ArabicHelper/images/cr24.dds", category = "craftable"},
    {name = "Fortified Brass", icon = "ArabicHelper/images/cr25.dds", category = "craftable"},
    {name = "Grave-Stake Collector", icon = "ArabicHelper/images/cr26.dds", category = "craftable"},
    {name = "Heartland Conqueror", icon = "ArabicHelper/images/cr27.dds", category = "craftable"},
    {name = "Highland Sentinel", icon = "ArabicHelper/images/cr28.dds", category = "craftable"},
    {name = "Hist Bark", icon = "ArabicHelper/images/cr29.dds", category = "craftable"},
    {name = "Hist Whisperer", icon = "ArabicHelper/images/cr30.dds", category = "craftable"},
    {name = "Hunding's Rage", icon = "ArabicHelper/images/cr31.dds", category = "craftable"},
    {name = "Innate Axiom", icon = "ArabicHelper/images/cr32.dds", category = "craftable"},
    {name = "Iron Flask", icon = "ArabicHelper/images/cr33.dds", category = "craftable"},
    {name = "Kagrenac's Hope", icon = "ArabicHelper/images/cr34.dds", category = "craftable"},
    {name = "Kvatch Gladiator", icon = "ArabicHelper/images/cr35.dds", category = "craftable"},
    {name = "Law of Julianos", icon = "ArabicHelper/images/cr36.dds", category = "craftable"},
    {name = "Legacy of Karth", icon = "ArabicHelper/images/cr37.dds", category = "craftable"},
    {name = "Magnus' Gift", icon = "ArabicHelper/images/cr38.dds", category = "craftable"},
    {name = "Mechanical Acuity", icon = "ArabicHelper/images/cr39.dds", category = "craftable"},
    {name = "Might of the Lost Legion", icon = "ArabicHelper/images/cr40.dds", category = "craftable"},
    {name = "Morkuldin", icon = "ArabicHelper/images/cr41.dds", category = "craftable"},
    {name = "Naga Shaman", icon = "ArabicHelper/images/cr42.dds", category = "craftable"},
    {name = "New Moon Acolyte", icon = "ArabicHelper/images/cr43.dds", category = "craftable"},
    {name = "Night Mother's Gaze", icon = "ArabicHelper/images/cr44.dds", category = "craftable"},
    {name = "Night's Silence", icon = "ArabicHelper/images/cr45.dds", category = "craftable"},
    {name = "Noble's Conquest", icon = "ArabicHelper/images/cr46.dds", category = "craftable"},
    {name = "Nocturnal's Favor", icon = "ArabicHelper/images/cr47.dds", category = "craftable"},
    {name = "Oblivion's Foe", icon = "ArabicHelper/images/cr48.dds", category = "craftable"},
    {name = "Old Growth Brewer", icon = "ArabicHelper/images/cr49.dds", category = "craftable"},
    {name = "Order's Wrath", icon = "ArabicHelper/images/cr50.dds", category = "craftable"},
    {name = "Orgnum's Scales", icon = "ArabicHelper/images/cr51.dds", category = "craftable"},
    {name = "Pelinal's Wrath", icon = "ArabicHelper/images/cr52.dds", category = "craftable"},
    {name = "Red Eagle's Fury", icon = "ArabicHelper/images/cr53.dds", category = "craftable"},
    {name = "Redistributor", icon = "ArabicHelper/images/cr54.dds", category = "craftable"},
    {name = "Seeker Synthesis", icon = "ArabicHelper/images/cr55.dds", category = "craftable"},
    {name = "Senche-Raht's Grit", icon = "ArabicHelper/images/cr56.dds", category = "craftable"},
    {name = "Serpent's Disdain", icon = "ArabicHelper/images/cr57.dds", category = "craftable"},
    {name = "Shacklebreaker", icon = "ArabicHelper/images/cr58.dds", category = "craftable"},
    {name = "Shalidor's Curse", icon = "ArabicHelper/images/cr59.dds", category = "craftable"},
    {name = "Shared Burden", icon = "ArabicHelper/images/cr60.dds", category = "craftable"},
    {name = "Shattered Fate", icon = "ArabicHelper/images/cr61.dds", category = "craftable"},
    {name = "Sload's Semblance", icon = "ArabicHelper/images/cr62.dds", category = "craftable"},
    {name = "Song of Lamae", icon = "ArabicHelper/images/cr63.dds", category = "craftable"},
    {name = "Spectre's Eye", icon = "ArabicHelper/images/cr64.dds", category = "craftable"},
    {name = "Spell Parasite", icon = "ArabicHelper/images/cr65.dds", category = "craftable"},
    {name = "Stuhn's Favor", icon = "ArabicHelper/images/cr66.dds", category = "craftable"},
    {name = "Tava's Favor", icon = "ArabicHelper/images/cr67.dds", category = "craftable"},
    {name = "Telvanni Efficiency", icon = "ArabicHelper/images/cr68.dds", category = "craftable"},
    {name = "Tharriker's Strike", icon = "ArabicHelper/images/cr69.dds", category = "craftable"},
    {name = "Threads of War", icon = "ArabicHelper/images/cr70.dds", category = "craftable"},
    {name = "Tide-Born Wildstalker", icon = "ArabicHelper/images/cr71.dds", category = "craftable"},
    {name = "Torug's Pact", icon = "ArabicHelper/images/cr72.dds", category = "craftable"},
    {name = "Trial by Fire", icon = "ArabicHelper/images/cr73.dds", category = "craftable"},
    {name = "Twice-Born Star", icon = "ArabicHelper/images/cr74.dds", category = "craftable"},
    {name = "Twilight's Embrace", icon = "ArabicHelper/images/cr75.dds", category = "craftable"},
    {name = "Unchained Aggressor", icon = "ArabicHelper/images/cr76.dds", category = "craftable"},
    {name = "Vampire's Kiss", icon = "ArabicHelper/images/cr77.dds", category = "craftable"},
    {name = "Varen's Legacy", icon = "ArabicHelper/images/cr78.dds", category = "craftable"},
    {name = "Vastarie's Tutelage", icon = "ArabicHelper/images/cr79.dds", category = "craftable"},
    {name = "Way of the Arena", icon = "ArabicHelper/images/cr80.dds", category = "craftable"},
    {name = "Whitestrake's Retribution", icon = "ArabicHelper/images/cr81.dds", category = "craftable"},
    {name = "Willow's Path", icon = "ArabicHelper/images/cr82.dds", category = "craftable"},
    {name = "Wretched Vitality", icon = "ArabicHelper/images/cr83.dds", category = "craftable"},
    -- ===== قسم الأرينا (Arena) =====
    {name = "Perfected Caustic Arrow", icon = "ArabicHelper/images/ar1.dds", category = "Arena"},
    {name = "Perfected Cruel Flurry", icon = "ArabicHelper/images/ar2.dds", category = "Arena"},
    {name = "Perfected Crushing Wall", icon = "ArabicHelper/images/ar3.dds", category = "Arena"},
    {name = "Perfected Destructive Impact", icon = "ArabicHelper/images/ar4.dds", category = "Arena"},
    {name = "Perfected Executioner's Blade", icon = "ArabicHelper/images/ar5.dds", category = "Arena"},
    {name = "Perfected Force Overflow", icon = "ArabicHelper/images/ar6.dds", category = "Arena"},
    {name = "Perfected Frenzied Momentum", icon = "ArabicHelper/images/ar7.dds", category = "Arena"},
    {name = "Perfected Gallant Charge", icon = "ArabicHelper/images/ar8.dds", category = "Arena"},
    {name = "Perfected Grand Rejuvenation", icon = "ArabicHelper/images/ar9.dds", category = "Arena"},
    {name = "Perfected Mender's Ward", icon = "ArabicHelper/images/ar10.dds", category = "Arena"},
    {name = "Perfected Merciless Charge", icon = "ArabicHelper/images/ar11.dds", category = "Arena"},
    {name = "Perfected Point-Blank Snipe", icon = "ArabicHelper/images/ar12.dds", category = "Arena"},
    {name = "Perfected Precise Regeneration", icon = "ArabicHelper/images/ar13.dds", category = "Arena"},
    {name = "Perfected Puncturing Remedy", icon = "ArabicHelper/images/ar14.dds", category = "Arena"},
    {name = "Perfected Radial Uppercut", icon = "ArabicHelper/images/ar15.dds", category = "Arena"},
    {name = "Perfected Rampaging Slash", icon = "ArabicHelper/images/ar16.dds", category = "Arena"},
    {name = "Perfected Spectral Cloak", icon = "ArabicHelper/images/ar17.dds", category = "Arena"},
    {name = "Perfected Stinging Slashes", icon = "ArabicHelper/images/ar18.dds", category = "Arena"},
    {name = "Perfected Thunderous Volley", icon = "ArabicHelper/images/ar19.dds", category = "Arena"},
    {name = "Perfected Titanic Cleave", icon = "ArabicHelper/images/ar20.dds", category = "Arena"},
    {name = "Perfected Virulent Shot", icon = "ArabicHelper/images/ar21.dds", category = "Arena"},
    {name = "Perfected Void Bash", icon = "ArabicHelper/images/ar22.dds", category = "Arena"},
    {name = "Perfected Wild Impulse", icon = "ArabicHelper/images/ar23.dds", category = "Arena"},
    {name = "Perfected Wrath of Elements", icon = "ArabicHelper/images/ar24.dds", category = "Arena"},
    -- ===== قسم الـ PvP (Cyrodiil / Battlegrounds / Imperial City) =====
    {name = "Affliction", icon = "ArabicHelper/images/pvp1.dds", category = "PvP"},
    {name = "Agility", icon = "ArabicHelper/images/pvp2.dds", category = "PvP"},
    {name = "Alessian Order", icon = "ArabicHelper/images/pvp3.dds", category = "PvP"},
    {name = "Almalexia's Mercy", icon = "ArabicHelper/images/pvp4.dds", category = "PvP"},
    {name = "Arkay's Charity", icon = "ArabicHelper/images/pvp5.dds", category = "PvP"},
    {name = "Baan Dar's Blessing", icon = "ArabicHelper/images/pvp6.dds", category = "PvP"},
    {name = "Bastion of the Heartland", icon = "ArabicHelper/images/pvp7.dds", category = "PvP"},
    {name = "Battalion Defender", icon = "ArabicHelper/images/pvp8.dds", category = "PvP"},
    {name = "Battlefield Acrobat", icon = "ArabicHelper/images/pvp9.dds", category = "PvP"},
    {name = "Beckoning Steel", icon = "ArabicHelper/images/pvp10.dds", category = "PvP"},
    {name = "Black Rose", icon = "ArabicHelper/images/pvp11.dds", category = "PvP"},
    {name = "Blackfeather Flight", icon = "ArabicHelper/images/pvp12.dds", category = "PvP"},
    {name = "Blessing of the Potentates", icon = "ArabicHelper/images/pvp13.dds", category = "PvP"},
    {name = "Blunted Blades", icon = "ArabicHelper/images/pvp14.dds", category = "PvP"},
    {name = "Buffer of the Swift", icon = "ArabicHelper/images/pvp15.dds", category = "PvP"},
    {name = "Bulwark Ruination", icon = "ArabicHelper/images/pvp16.dds", category = "PvP"},
    {name = "Colovian Highlands General", icon = "ArabicHelper/images/pvp17.dds", category = "PvP"},
    {name = "Coup De Grâce", icon = "ArabicHelper/images/pvp18.dds", category = "PvP"},
    {name = "Coward's Gear", icon = "ArabicHelper/images/pvp19.dds", category = "PvP"},
    {name = "Crest of Cyrodiil", icon = "ArabicHelper/images/pvp20.dds", category = "PvP"},
    {name = "Curse Eater", icon = "ArabicHelper/images/pvp21.dds", category = "PvP"},
    {name = "Dark Convergence", icon = "ArabicHelper/images/pvp22.dds", category = "PvP"},
    {name = "Deadly Strike", icon = "ArabicHelper/images/pvp23.dds", category = "PvP"},
    {name = "Desert Rose", icon = "ArabicHelper/images/pvp24.dds", category = "PvP"},
    {name = "Eagle Eye", icon = "ArabicHelper/images/pvp25.dds", category = "PvP"},
    {name = "Elf Bane", icon = "ArabicHelper/images/pvp26.dds", category = "PvP"},
    {name = "Endurance", icon = "ArabicHelper/images/pvp27.dds", category = "PvP"},
    {name = "Enervating Aura", icon = "ArabicHelper/images/pvp28.dds", category = "PvP"},
    {name = "Farstrider", icon = "ArabicHelper/images/pvp29.dds", category = "PvP"},
    {name = "Fasalla's Guile", icon = "ArabicHelper/images/pvp30.dds", category = "PvP"},
    {name = "Galerion's Revenge", icon = "ArabicHelper/images/pvp31.dds", category = "PvP"},
    {name = "Gorethief", icon = "ArabicHelper/images/pvp32.dds", category = "PvP"},
    {name = "Grace of the Ancients", icon = "ArabicHelper/images/pvp33.dds", category = "PvP"},
    {name = "Hawk's Eye", icon = "ArabicHelper/images/pvp34.dds", category = "PvP"},
    {name = "Hew and Sunder", icon = "ArabicHelper/images/pvp35.dds", category = "PvP"},
    {name = "Hrothgar's Chill", icon = "ArabicHelper/images/pvp36.dds", category = "PvP"},
    {name = "Imperial Physique", icon = "ArabicHelper/images/pvp37.dds", category = "PvP"},
    {name = "Impregnable Armor", icon = "ArabicHelper/images/pvp38.dds", category = "PvP"},
    {name = "Indomitable Fury", icon = "ArabicHelper/images/pvp39.dds", category = "PvP"},
    {name = "Jerall Mountains Warchief", icon = "ArabicHelper/images/pvp40.dds", category = "PvP"},
    {name = "Judgment of Akatosh", icon = "ArabicHelper/images/pvp41.dds", category = "PvP"},
    {name = "Knight Slayer", icon = "ArabicHelper/images/pvp42.dds", category = "PvP"},
    {name = "Kyne's Kiss", icon = "ArabicHelper/images/pvp43.dds", category = "PvP"},
    {name = "Lamp Knight's Art", icon = "ArabicHelper/images/pvp44.dds", category = "PvP"},
    {name = "Languor of Peryite", icon = "ArabicHelper/images/pvp45.dds", category = "PvP"},
    {name = "Leki's Focus", icon = "ArabicHelper/images/pvp46.dds", category = "PvP"},
    {name = "Light of Cyrodiil", icon = "ArabicHelper/images/pvp47.dds", category = "PvP"},
    {name = "Mara's Balm", icon = "ArabicHelper/images/pvp48.dds", category = "PvP"},
    {name = "Marksman's Crest", icon = "ArabicHelper/images/pvp49.dds", category = "PvP"},
    {name = "Meritorious Service", icon = "ArabicHelper/images/pvp50.dds", category = "PvP"},
    {name = "Netch Oil", icon = "ArabicHelper/images/pvp51.dds", category = "PvP"},
    {name = "Nibenay Bay Battlereeve", icon = "ArabicHelper/images/pvp52.dds", category = "PvP"},
    {name = "Nocturnal's Ploy", icon = "ArabicHelper/images/pvp53.dds", category = "PvP"},
    {name = "Oakfather's Retribution", icon = "ArabicHelper/images/pvp54.dds", category = "PvP"},
    {name = "Phoenix", icon = "ArabicHelper/images/pvp55.dds", category = "PvP"},
    {name = "Plaguebreak", icon = "ArabicHelper/images/pvp56.dds", category = "PvP"},
    {name = "Powerful Assault", icon = "ArabicHelper/images/pvp57.dds", category = "PvP"},
    {name = "Rallying Cry", icon = "ArabicHelper/images/pvp58.dds", category = "PvP"},
    {name = "Ravager", icon = "ArabicHelper/images/pvp59.dds", category = "PvP"},
    {name = "Reactive Armor", icon = "ArabicHelper/images/pvp60.dds", category = "PvP"},
    {name = "Robes of Alteration Mastery", icon = "ArabicHelper/images/pvp61.dds", category = "PvP"},
    {name = "Robes of Transmutation", icon = "ArabicHelper/images/pvp62.dds", category = "PvP"},
    {name = "Sentry", icon = "ArabicHelper/images/pvp63.dds", category = "PvP"},
    {name = "Shadow Walker", icon = "ArabicHelper/images/pvp64.dds", category = "PvP"},
    {name = "Shared Pain", icon = "ArabicHelper/images/pvp65.dds", category = "PvP"},
    {name = "Shell Splitter", icon = "ArabicHelper/images/pvp66.dds", category = "PvP"},
    {name = "Shield Breaker", icon = "ArabicHelper/images/pvp67.dds", category = "PvP"},
    {name = "Shield of the Valiant", icon = "ArabicHelper/images/pvp68.dds", category = "PvP"},
    {name = "Siegemaster's Focus", icon = "ArabicHelper/images/pvp69.dds", category = "PvP"},
    {name = "Snake in the Stars", icon = "ArabicHelper/images/pvp70.dds", category = "PvP"},
    {name = "Soldier of Anguish", icon = "ArabicHelper/images/pvp71.dds", category = "PvP"},
    {name = "Spell Strategist", icon = "ArabicHelper/images/pvp72.dds", category = "PvP"},
    {name = "Spellshredder", icon = "ArabicHelper/images/pvp73.dds", category = "PvP"},
    {name = "Steadfast Hero", icon = "ArabicHelper/images/pvp74.dds", category = "PvP"},
    {name = "The Arch-Mage", icon = "ArabicHelper/images/pvp75.dds", category = "PvP"},
    {name = "The Juggernaut", icon = "ArabicHelper/images/pvp76.dds", category = "PvP"},
    {name = "The Morag Tong", icon = "ArabicHelper/images/pvp77.dds", category = "PvP"},
    {name = "Thews of the Harbinger", icon = "ArabicHelper/images/pvp78.dds", category = "PvP"},
    {name = "Tracker's Lash", icon = "ArabicHelper/images/pvp79.dds", category = "PvP"},
    {name = "Unflinching Ultimate", icon = "ArabicHelper/images/pvp80.dds", category = "PvP"},
    {name = "Vanguard's Challenge", icon = "ArabicHelper/images/pvp81.dds", category = "PvP"},
    {name = "Vengeance Leech", icon = "ArabicHelper/images/pvp82.dds", category = "PvP"},
    {name = "Vicecanon of Venom", icon = "ArabicHelper/images/pvp83.dds", category = "PvP"},
    {name = "Vicious Death", icon = "ArabicHelper/images/pvp84.dds", category = "PvP"},
    {name = "Ward of Cyrodiil", icon = "ArabicHelper/images/pvp85.dds", category = "PvP"},
    {name = "Warrior's Fury", icon = "ArabicHelper/images/pvp86.dds", category = "PvP"},
    {name = "Willpower", icon = "ArabicHelper/images/pvp87.dds", category = "PvP"},
    {name = "Wizard's Riposte", icon = "ArabicHelper/images/pvp88.dds", category = "PvP"},
    {name = "Wrath of the Imperium", icon = "ArabicHelper/images/pvp89.dds", category = "PvP"},
}



-- قاعدة بيانات البفات والديبفات 
local buffsDatabase = {
    -- ===== قسم البفات (Buffs) =====
    { nameEn = "Aegis", icon = "ArabicHelper/images/buff1.dds", type = "Buff" },
    { nameEn = "Berserk", icon = "ArabicHelper/images/buff2.dds", type = "Buff" },
    { nameEn = "Brutality", icon = "ArabicHelper/images/buff3.dds", type = "Buff" },
    { nameEn = "Courage", icon = "ArabicHelper/images/buff4.dds", type = "Buff" },
    { nameEn = "Empower", icon = "ArabicHelper/images/buff5.dds", type = "Buff" },
    { nameEn = "Endurance", icon = "ArabicHelper/images/buff6.dds", type = "Buff" },
    { nameEn = "Evasion", icon = "ArabicHelper/images/buff7.dds", type = "Buff" },
    { nameEn = "Expedition", icon = "ArabicHelper/images/buff8.dds", type = "Buff" },
    { nameEn = "Force", icon = "ArabicHelper/images/buff9.dds", type = "Buff" },
    { nameEn = "Fortitude", icon = "ArabicHelper/images/buff10.dds", type = "Buff" },
    { nameEn = "Gallop", icon = "ArabicHelper/images/buff11.dds", type = "Buff" },
    { nameEn = "Heroism", icon = "ArabicHelper/images/buff12.dds", type = "Buff" },
    { nameEn = "Intellect", icon = "ArabicHelper/images/buff13.dds", type = "Buff" },
    { nameEn = "Mending", icon = "ArabicHelper/images/buff14.dds", type = "Buff" },
    { nameEn = "Resolve", icon = "ArabicHelper/images/buff15.dds", type = "Buff" },
    { nameEn = "Prophecy", icon = "ArabicHelper/images/buff16.dds", type = "Buff" },
    { nameEn = "Protection", icon = "ArabicHelper/images/buff17.dds", type = "Buff" },
    { nameEn = "Resolve", icon = "ArabicHelper/images/buff18.dds", type = "Buff" },
    { nameEn = "Savagery", icon = "ArabicHelper/images/buff19.dds", type = "Buff" },
    { nameEn = "Slayer", icon = "ArabicHelper/images/buff20.dds", type = "Buff" },
    { nameEn = "Sorcery", icon = "ArabicHelper/images/buff21.dds", type = "Buff" },
    { nameEn = "Spell Resistance", icon = "ArabicHelper/images/buff22.dds", type = "Buff" },
    { nameEn = "Spell Resistance Potion", icon = "ArabicHelper/images/buff23.dds", type = "Buff" },
    { nameEn = "Toughness", icon = "ArabicHelper/images/buff24.dds", type = "Buff" },
    { nameEn = "Vitality", icon = "ArabicHelper/images/buff25.dds", type = "Buff" },

    -- ===== قسم الديبفات (Debuffs) =====
    { nameEn = "Breach", icon = "ArabicHelper/images/debuff1.dds", type = "Debuff" },
    { nameEn = "Brittle", icon = "ArabicHelper/images/debuff2.dds", type = "Debuff" },
    { nameEn = "Cowardice", icon = "ArabicHelper/images/debuff3.dds", type = "Debuff" },
    { nameEn = "Defile", icon = "ArabicHelper/images/debuff4.dds", type = "Debuff" },
    { nameEn = "Enervation", icon = "ArabicHelper/images/debuff5.dds", type = "Debuff" },
    { nameEn = "Hindrance", icon = "ArabicHelper/images/debuff6.dds", type = "Debuff" },
    { nameEn = "Lifesteal", icon = "ArabicHelper/images/debuff7.dds", type = "Debuff" },
    { nameEn = "Magickasteal", icon = "ArabicHelper/images/debuff8.dds", type = "Debuff" },
    { nameEn = "Maim", icon = "ArabicHelper/images/debuff9.dds", type = "Debuff" },
    { nameEn = "Mangle", icon = "ArabicHelper/images/debuff10.dds", type = "Debuff" },
    { nameEn = "Timidity", icon = "ArabicHelper/images/debuff11.dds", type = "Debuff" },
    { nameEn = "Uncertainty", icon = "ArabicHelper/images/debuff12.dds", type = "Debuff" },
    { nameEn = "Vulnerability", icon = "ArabicHelper/images/debuff13.dds", type = "Debuff" }
}

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= "ArabicHelper" then return end

    -- تحميل المفضلة المحفوظة.
    -- ملاحظة: يجب أن يحتوي ملف Manifest (.txt) على:
    -- ## SavedVariables: ArabicHelperSavedVariables
    savedVars = ZO_SavedVars:NewAccountWide("ArabicHelperSavedVariables", 1, nil, savedVarsDefaults)
    
    ----------------------------------------------------
    -- 1. النافذة الرئيسية للأطقم
    ----------------------------------------------------
    myWindow = WINDOW_MANAGER:CreateTopLevelWindow("ArabicHelperWindow")
    myWindow:SetDimensions(600, 860) 
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
    divider:SetDimensions(550, 2) 
    divider:SetAnchor(TOPLEFT, myWindow, TOPLEFT, 25, 55) 
    divider:SetCenterColor(0.77, 0.76, 0.62, 0.6) 

    ----------------------------------------------------
    -- تبويبات وصندوق البحث للأطقم
    ----------------------------------------------------
    local categories = {"All", "Dungeon", "Trial", "Arena", "craftable", "PvP", "Monster"}
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
        tab:SetDimensions(72, 30)
        tab:SetAnchor(TOPLEFT, myWindow, TOPLEFT, (i-1)*78 + 25, 65) 
        tab:SetText(catName)
        tab:SetFont("ZoFontWinH4")
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

    local function IsFavorite(setName)
        return savedVars and savedVars.favorites and savedVars.favorites[setName] == true
    end

    local function UpdateFavoriteStar()
        if not selectedSetInfo or myImage:IsHidden() then
            favoriteStarBtn:SetHidden(true)
            favoriteLabel:SetHidden(true)
            return
        end

        if IsFavorite(selectedSetInfo.name) then
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
        local setName = selectedSetInfo.name
        if savedVars.favorites[setName] then
            savedVars.favorites[setName] = nil
        else
            savedVars.favorites[setName] = true
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
            local matchesFavorite = (not favoritesMode or IsFavorite(setInfo.name))
            
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
                -- نشيل كلمة "Perfected" من العرض بس (البحث يبقى بالاسم الكامل)
                local shownName = string.gsub(selectedSet.name, "^Perfected ", "P. ")
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
                { name = "1. Lightning Storm Atronach", card = "ArabicHelper/images/trial_aa_lightning.dds" },
                { name = "2. Foundation Stone Atronach", card = "ArabicHelper/images/trial_aa_stone.dds" },
                { name = "3. Varlariel", card = "ArabicHelper/images/trial_aa_varlariel.dds" },
                { name = "4. The Celestial Mage", card = "ArabicHelper/images/trial_aa_mage.dds" },
            }
        },

        HRC = {
            title = "Hel Ra Citadel (HRC)",
            bosses = {
                { name = "1. Ra Kotu", card = "ArabicHelper/images/trial_hrc_rakotu.dds" },
                { name = "2. Yokeda Rok'dun", card = "ArabicHelper/images/trial_hrc_rokdun.dds" },
                { name = "3. Yokeda Kai", card = "ArabicHelper/images/trial_hrc_kai.dds" },
                { name = "4. The Warrior", card = "ArabicHelper/images/trial_hrc_warrior.dds" },
            }
        },

        SO = {
            title = "Sanctum Ophidia (SO)",
            bosses = {
                { name = "1. Possessed Mantikora", card = "ArabicHelper/images/trial_so_mantikora.dds" },
                { name = "2. Stonebreaker", card = "ArabicHelper/images/trial_so_stonebreaker.dds" },
                { name = "3. Ozara", card = "ArabicHelper/images/trial_so_ozara.dds" },
                { name = "4. The Serpent", card = "ArabicHelper/images/trial_so_serpent.dds" },
            }
        },

        MOL = {
            title = "Maw of Lorkhaj (MoL)",
            bosses = {
                { name = "1. Zhaj'hassa the Forgotten", card = "ArabicHelper/images/trial_mol_zhajhassa.dds" },
                { name = "2. Vashai & S'kinrai", card = "ArabicHelper/images/trial_mol_twins.dds" },
                { name = "3. Rakkhat", card = "ArabicHelper/images/trial_mol_rakkhat.dds" },
            }
        },

        HOF = {
            title = "Halls of Fabrication (HoF)",
            bosses = {
                { name = "1. Hunter-Killer Negatrix & Positrox", card = "ArabicHelper/images/trial_hof_hunterkillers.dds" },
                { name = "2. Pinnacle Factotum", card = "ArabicHelper/images/trial_hof_pinnacle.dds" },
                { name = "3. Archcustodian", card = "ArabicHelper/images/trial_hof_archcustodian.dds" },
                { name = "4. Refabrication Committee", card = "ArabicHelper/images/trial_hof_committee.dds" },
                { name = "5. Assembly General", card = "ArabicHelper/images/trial_hof_assembly.dds" },
            }
        },

        AS = {
            title = "Asylum Sanctorium (AS)",
            bosses = {
                { name = "1. Saint Felms the Bold", card = "ArabicHelper/images/trial_as_felms.dds" },
                { name = "2. Saint Llothis the Pious", card = "ArabicHelper/images/trial_as_llothis.dds" },
                { name = "3. Saint Olms the Just", card = "ArabicHelper/images/trial_as_olms.dds" },
            }
        },

        CR = {
            title = "Cloudrest (CR)",
            bosses = {
                { name = "1. Shade of Galenwe", card = "ArabicHelper/images/trial_cr_galenwe.dds" },
                { name = "2. Shade of Relequen", card = "ArabicHelper/images/trial_cr_relequen.dds" },
                { name = "3. Shade of Siroria", card = "ArabicHelper/images/trial_cr_siroria.dds" },
                { name = "4. Z'Maja", card = "ArabicHelper/images/trial_cr_zmaja.dds" },
            }
        },

        SS = {
            title = "Sunspire (SS)",
            bosses = {
                { name = "1. Lokkestiiz", card = "ArabicHelper/images/trial_ss_lokkestiiz.dds" },
                { name = "2. Yolnahkriin", card = "ArabicHelper/images/trial_ss_yolnahkriin.dds" },
                { name = "3. Nahviintaas", card = "ArabicHelper/images/trial_ss_nahviintaas.dds" },
            }
        },

        KA = {
            title = "Kyne's Aegis (KA)",
            bosses = {
                { name = "1. Yandir the Butcher", card = "ArabicHelper/images/trial_ka_yandir.dds" },
                { name = "2. Captain Vrol", card = "ArabicHelper/images/trial_ka_vrol.dds" },
                { name = "3. Lord Falgravn", card = "ArabicHelper/images/trial_ka_falgravn.dds" },
            }
        },

        RG = {
            title = "Rockgrove (RG)",
            bosses = {
                { name = "1. Oaxiltso", card = "ArabicHelper/images/trial_rg_oaxiltso.dds" },
                { name = "2. Flame-Herald Bahsei", card = "ArabicHelper/images/trial_rg_bahsei.dds" },
                { name = "3. Xalvakka", card = "ArabicHelper/images/trial_rg_xalvakka.dds" },
            }
        },

        DSR = {
            title = "Dreadsail Reef (DSR)",
            bosses = {
                { name = "1. Lylanar & Turlassil", card = "ArabicHelper/images/trial_dsr_lylanar_turlassil.dds" },
                { name = "2. Reef Guardian", card = "ArabicHelper/images/trial_dsr_reef_guardian.dds" },
                { name = "3. Tideborn Taleria", card = "ArabicHelper/images/trial_dsr_taleria.dds" },
            }
        },

        SE = {
            title = "Sanity's Edge (SE)",
            bosses = {
                { name = "1. Exarchanic Yaseyla", card = "ArabicHelper/images/trial_se_yaseyla.dds" },
                { name = "2. Archwizard Twelvane & Chimera", card = "ArabicHelper/images/trial_se_twelvane.dds" },
                { name = "3. Ansuul the Tormentor", card = "ArabicHelper/images/trial_se_ansuul.dds" },
            }
        },

        LC = {
            title = "Lucent Citadel (LC)",
            bosses = {
                { name = "1. Count Ryelaz & Zilyesset", card = "ArabicHelper/images/trial_lc_ryelaz_zilyesset.dds" },
                { name = "2. Orphic Shattered Shard", card = "ArabicHelper/images/trial_lc_orphic.dds" },
                { name = "3. Xoryn", card = "ArabicHelper/images/trial_lc_xoryn.dds" },
            }
        },

        OC = {
            title = "Ossein Cage (OC)",
            bosses = {
                { name = "1. Shapers of Flesh", card = "ArabicHelper/images/trial_oc_shapers.dds" },
                { name = "2. Jynorah & Skorkhif", card = "ArabicHelper/images/trial_oc_jynorah_skorkhif.dds" },
                { name = "3. Overfiend Kazpian", card = "ArabicHelper/images/trial_oc_kazpian.dds" },
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
        local AR = ArabicHelper_Arabic
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
    -- جدول سريع: اسم الست (حروف صغيرة) -> صورته
    local setIconByName = {}
    for _, info in ipairs(setsDatabase) do
        setIconByName[string.lower(info.name)] = info.icon
    end

    local function FindSetIcon(setName)
        if not setName or setName == "" then return nil end
        local key = string.lower(zo_strformat("<<1>>", setName))
        if setIconByName[key] then return setIconByName[key] end
        -- لو الاسم فيه Perfected أو العكس، نجرب بدونه
        local noPerfected = string.gsub(key, "^perfected ", "")
        if setIconByName[noPerfected] then return setIconByName[noPerfected] end
        if setIconByName["perfected " .. key] then return setIconByName["perfected " .. key] end
        return nil
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

        local hasSet, setName = GetItemLinkSetInfo(itemLink, false)
        if cardDebug then
            d("ArabicHelper card: set=" .. tostring(setName) .. " hasSet=" .. tostring(hasSet)
              .. " image=" .. tostring(FindSetIcon(setName)))
        end
        if not hasSet then return HideCard() end

        local icon = FindSetIcon(setName)
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

    local function HookGamepadBag()
        if not GAMEPAD_TOOLTIPS then
            hookReport[#hookReport + 1] = "Gamepad=missing"
            return
        end
        if type(SecurePostHook) ~= "function" then
            hookReport[#hookReport + 1] = "Gamepad=noSecureHook"
            return
        end
        local hooked = {}
        for _, methodName in ipairs(GAMEPAD_LAYOUT_METHODS) do
            if type(GAMEPAD_TOOLTIPS[methodName]) == "function" then
                local ok = pcall(SecurePostHook, GAMEPAD_TOOLTIPS, methodName, function(self, tooltipType, ...)
                    if not IsInGamepadPreferredMode() then return end
                    local link = LinkFromArgs(...)
                    if cardDebug then d("ArabicHelper gamepad: " .. methodName .. " link=" .. tostring(link ~= nil)) end
                    if not link then return end
                    gamepadShownType = tooltipType
                    local okShow, err = pcall(ShowCardFor, GamepadAnchor(self, tooltipType), link)
                    if not okShow and cardDebug then d("ArabicHelper gamepad card error: " .. tostring(err)) end
                end)
                if ok then hooked[#hooked + 1] = methodName end
            end
        end
        -- نخفي البطاقة بس لما ينمسح نفس الوصف اللي هي جنبه (مو الوصف الثاني)
        local okClear = pcall(SecurePostHook, GAMEPAD_TOOLTIPS, "ClearTooltip", function(self, tooltipType)
            if IsInGamepadPreferredMode() and tooltipType == gamepadShownType then
                gamepadShownType = nil
                HideCard()
            end
        end)
        hookReport[#hookReport + 1] = "Gamepad=" .. table.concat(hooked, "/") .. " clear=" .. tostring(okClear)
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

    _G.ArabicHelper_ToggleWindow = function()
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