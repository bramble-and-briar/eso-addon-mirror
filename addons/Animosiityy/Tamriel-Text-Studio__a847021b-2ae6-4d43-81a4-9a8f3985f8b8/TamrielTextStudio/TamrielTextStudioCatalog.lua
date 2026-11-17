-- Tamriel Text Studio - built-in, searchable texture catalogue.
-- Texture files are part of ESO itself; this table stores their in-game paths,
-- not copies of copyrighted game assets. A path is only useful if that texture
-- exists in the player's current ESO client.
TTS_TEXTURES = {
    -- Map, travel, and points of interest
    { name="Wayshrine", path="esoui/art/icons/poi/poi_wayshrine_complete.dds", category="Map & Travel", keywords="travel fast travel shrine" },
    { name="Group Boss", path="esoui/art/icons/poi/poi_groupboss_complete.dds", category="Map & Travel", keywords="world boss boss skull" },
    { name="Town", path="esoui/art/icons/poi/poi_town_complete.dds", category="Map & Travel", keywords="city village settlement" },
    { name="Dungeon", path="esoui/art/icons/poi/poi_dungeon_complete.dds", category="Map & Travel", keywords="delve instance cave" },
    { name="Fighters Guild Map Pin", path="esoui/art/icons/servicemappins/servicepin_fightersguild.dds", category="Services", keywords="fighters guild warrior" },
    { name="Delve", path="esoui/art/icons/poi/poi_delve_complete.dds", category="Map & Travel", keywords="cave delve" },
    { name="Public Dungeon", path="esoui/art/icons/poi/poi_publicdungeon_complete.dds", category="Map & Travel", keywords="public dungeon" },
    { name="Group Dungeon", path="esoui/art/icons/poi/poi_groupinstance_complete.dds", category="Map & Travel", keywords="group dungeon instance" },
    { name="Set Crafting Station", path="esoui/art/icons/poi/poi_setstation_complete.dds", category="Map & Travel", keywords="craft set station" },
    { name="Quest Giver", path="esoui/art/icons/poi/poi_questgiver_complete.dds", category="Map & Travel", keywords="quest mission" },

    -- Alliance banners and emblems (paths reported by the ESO community texture guide)
    { name="Aldmeri Dominion Flag", path="esoui/art/ava/ava_allianceflag_aldmeri.dds", category="Factions", keywords="aldmeri dominion yellow elf AD alliance banner" },
    { name="Daggerfall Covenant Flag", path="esoui/art/ava/ava_allianceflag_daggerfall.dds", category="Factions", keywords="daggerfall covenant blue DC alliance banner" },
    { name="Ebonheart Pact Flag", path="esoui/art/ava/ava_allianceflag_ebonheart.dds", category="Factions", keywords="ebonheart pact red EP alliance banner" },

    -- Known common textures
    { name="Baby Netch", path="esoui/art/icons/pet_081.dds", category="Pets & Creatures", keywords="netch pet creature animal" },
    { name="Coin Bag", path="esoui/art/icons/item_generic_coinbag.dds", category="Crafting & Items", keywords="gold coin money currency bag" },
    { name="Heavy Armor", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_heavyarmor.dds", category="Services", keywords="armor equipment gear" },
    { name="Mages Guild", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_magesguild.dds", category="Services", keywords="mage magic guild" },
    { name="Stablemaster", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_stablemaster.dds", category="Services", keywords="mount stable horse riding" },

    -- Service and activity icons from the ESO UI icon tree.
    { name="Bank", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_bank.dds", category="Services", keywords="bank storage gold" },
    { name="Blacksmithing", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_blacksmithing.dds", category="Crafting & Items", keywords="smith metal forge" },
    { name="Clothier", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_clothier.dds", category="Crafting & Items", keywords="cloth leather tailor" },
    { name="Woodworking", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_woodworking.dds", category="Crafting & Items", keywords="wood carpentry staff bow" },
    { name="Alchemy", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_alchemy.dds", category="Crafting & Items", keywords="potion potionmaking" },
    { name="Enchanting", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_enchanting.dds", category="Crafting & Items", keywords="rune glyph" },
    { name="Provisioning", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_provisioning.dds", category="Crafting & Items", keywords="food drink cooking" },
    { name="Guild Store", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_guildstore.dds", category="Services", keywords="guild trader trade market" },
    { name="Merchant", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_merchant.dds", category="Services", keywords="vendor shop sell" },
    { name="Outfit Station", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_outfit.dds", category="Services", keywords="outfit dye costume fashion" },
    { name="Jewelry Crafting", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_jewelrycrafting.dds", category="Crafting & Items", keywords="jewelry necklace ring" },
    { name="Transmute", path="esoui/art/icons/servicetooltipicons/servicetooltipicon_transmutation.dds", category="Services", keywords="transmute reconstruction traits" },

    -- Frequently used ability-family icons. The full skill collection varies by game update;
    -- the gallery also includes a manual advanced path option for edge cases.
    { name="Dragonknight Ability", path="esoui/art/icons/ability_dragonknight_001.dds", category="Icons & Skills", keywords="class dragon knight fire tank" },
    { name="Sorcerer Ability", path="esoui/art/icons/ability_sorcerer_001.dds", category="Icons & Skills", keywords="class sorcerer storm lightning" },
    { name="Nightblade Ability", path="esoui/art/icons/ability_nightblade_001.dds", category="Icons & Skills", keywords="class nightblade shadow assassin" },
    { name="Templar Ability", path="esoui/art/icons/ability_templar_001.dds", category="Icons & Skills", keywords="class templar holy light" },
    { name="Warden Ability", path="esoui/art/icons/ability_warden_001.dds", category="Icons & Skills", keywords="class warden nature ice bear" },
    { name="Necromancer Ability", path="esoui/art/icons/ability_necromancer_001.dds", category="Icons & Skills", keywords="class necromancer death bone" },
    { name="Arcanist Ability", path="esoui/art/icons/ability_arcanist_001.dds", category="Icons & Skills", keywords="class arcanist eldritch tentacle" },

    -- Pet icons form a large family in the ESO texture tree. They are named in-game,
    -- so numbered names keep them easy to browse without exposing path syntax to users.
    { name="Pet / Creature Icon 001", path="esoui/art/icons/pet_001.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 002", path="esoui/art/icons/pet_002.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 003", path="esoui/art/icons/pet_003.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 004", path="esoui/art/icons/pet_004.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 005", path="esoui/art/icons/pet_005.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 006", path="esoui/art/icons/pet_006.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 007", path="esoui/art/icons/pet_007.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 008", path="esoui/art/icons/pet_008.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 009", path="esoui/art/icons/pet_009.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 010", path="esoui/art/icons/pet_010.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 011", path="esoui/art/icons/pet_011.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 012", path="esoui/art/icons/pet_012.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 013", path="esoui/art/icons/pet_013.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 014", path="esoui/art/icons/pet_014.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 015", path="esoui/art/icons/pet_015.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 016", path="esoui/art/icons/pet_016.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 017", path="esoui/art/icons/pet_017.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 018", path="esoui/art/icons/pet_018.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 019", path="esoui/art/icons/pet_019.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 020", path="esoui/art/icons/pet_020.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 021", path="esoui/art/icons/pet_021.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 022", path="esoui/art/icons/pet_022.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 023", path="esoui/art/icons/pet_023.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 024", path="esoui/art/icons/pet_024.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 025", path="esoui/art/icons/pet_025.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 026", path="esoui/art/icons/pet_026.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 027", path="esoui/art/icons/pet_027.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 028", path="esoui/art/icons/pet_028.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 029", path="esoui/art/icons/pet_029.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 030", path="esoui/art/icons/pet_030.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 031", path="esoui/art/icons/pet_031.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 032", path="esoui/art/icons/pet_032.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 033", path="esoui/art/icons/pet_033.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 034", path="esoui/art/icons/pet_034.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 035", path="esoui/art/icons/pet_035.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 036", path="esoui/art/icons/pet_036.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 037", path="esoui/art/icons/pet_037.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 038", path="esoui/art/icons/pet_038.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 039", path="esoui/art/icons/pet_039.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 040", path="esoui/art/icons/pet_040.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 041", path="esoui/art/icons/pet_041.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 042", path="esoui/art/icons/pet_042.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 043", path="esoui/art/icons/pet_043.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 044", path="esoui/art/icons/pet_044.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 045", path="esoui/art/icons/pet_045.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 046", path="esoui/art/icons/pet_046.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 047", path="esoui/art/icons/pet_047.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 048", path="esoui/art/icons/pet_048.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 049", path="esoui/art/icons/pet_049.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 050", path="esoui/art/icons/pet_050.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 051", path="esoui/art/icons/pet_051.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 052", path="esoui/art/icons/pet_052.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 053", path="esoui/art/icons/pet_053.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 054", path="esoui/art/icons/pet_054.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 055", path="esoui/art/icons/pet_055.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 056", path="esoui/art/icons/pet_056.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 057", path="esoui/art/icons/pet_057.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 058", path="esoui/art/icons/pet_058.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 059", path="esoui/art/icons/pet_059.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 060", path="esoui/art/icons/pet_060.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 061", path="esoui/art/icons/pet_061.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 062", path="esoui/art/icons/pet_062.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 063", path="esoui/art/icons/pet_063.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 064", path="esoui/art/icons/pet_064.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 065", path="esoui/art/icons/pet_065.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 066", path="esoui/art/icons/pet_066.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 067", path="esoui/art/icons/pet_067.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 068", path="esoui/art/icons/pet_068.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 069", path="esoui/art/icons/pet_069.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 070", path="esoui/art/icons/pet_070.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 071", path="esoui/art/icons/pet_071.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 072", path="esoui/art/icons/pet_072.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 073", path="esoui/art/icons/pet_073.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 074", path="esoui/art/icons/pet_074.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 075", path="esoui/art/icons/pet_075.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 076", path="esoui/art/icons/pet_076.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 077", path="esoui/art/icons/pet_077.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 078", path="esoui/art/icons/pet_078.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 079", path="esoui/art/icons/pet_079.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 080", path="esoui/art/icons/pet_080.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 082", path="esoui/art/icons/pet_082.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 083", path="esoui/art/icons/pet_083.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 084", path="esoui/art/icons/pet_084.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 085", path="esoui/art/icons/pet_085.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 086", path="esoui/art/icons/pet_086.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 087", path="esoui/art/icons/pet_087.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 088", path="esoui/art/icons/pet_088.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 089", path="esoui/art/icons/pet_089.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 090", path="esoui/art/icons/pet_090.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 091", path="esoui/art/icons/pet_091.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 092", path="esoui/art/icons/pet_092.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 093", path="esoui/art/icons/pet_093.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 094", path="esoui/art/icons/pet_094.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 095", path="esoui/art/icons/pet_095.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 096", path="esoui/art/icons/pet_096.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 097", path="esoui/art/icons/pet_097.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 098", path="esoui/art/icons/pet_098.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 099", path="esoui/art/icons/pet_099.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 100", path="esoui/art/icons/pet_100.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 101", path="esoui/art/icons/pet_101.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 102", path="esoui/art/icons/pet_102.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 103", path="esoui/art/icons/pet_103.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 104", path="esoui/art/icons/pet_104.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 105", path="esoui/art/icons/pet_105.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 106", path="esoui/art/icons/pet_106.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 107", path="esoui/art/icons/pet_107.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 108", path="esoui/art/icons/pet_108.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 109", path="esoui/art/icons/pet_109.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 110", path="esoui/art/icons/pet_110.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 111", path="esoui/art/icons/pet_111.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 112", path="esoui/art/icons/pet_112.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 113", path="esoui/art/icons/pet_113.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 114", path="esoui/art/icons/pet_114.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 115", path="esoui/art/icons/pet_115.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 116", path="esoui/art/icons/pet_116.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 117", path="esoui/art/icons/pet_117.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 118", path="esoui/art/icons/pet_118.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 119", path="esoui/art/icons/pet_119.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },
    { name="Pet / Creature Icon 120", path="esoui/art/icons/pet_120.dds", category="Pets & Creatures", keywords="pet creature animal companion collectible" },

    -- Common general UI and item icons
    { name='Coin Pouch', path='esoui/art/icons/item_generic_coinbag.dds', category='Crafting & Items', keywords='coin gold money currency' },
    { name='Lockpick', path='esoui/art/icons/item_generic_lockpick.dds', category='Crafting & Items', keywords='lockpick chest lock' },
    { name='Soul Gem', path='esoui/art/icons/item_generic_soulgem.dds', category='Crafting & Items', keywords='soul gem revive resurrection' },
    { name='Health Potion', path='esoui/art/icons/item_potion_health_001.dds', category='Crafting & Items', keywords='potion health red healing' },
    { name='Magicka Potion', path='esoui/art/icons/item_potion_magicka_001.dds', category='Crafting & Items', keywords='potion magicka blue' },
    { name='Stamina Potion', path='esoui/art/icons/item_potion_stamina_001.dds', category='Crafting & Items', keywords='potion stamina green' },
    { name='Crown Icon', path='esoui/art/icons/crownstore/crownstore_currency_crowns.dds', category='Decorative / UI', keywords='crown store currency premium' },
    { name='Alliance War', path='esoui/art/icons/ava/ava_siegeweapon_ram.dds', category='Factions', keywords='pvp cyrodiil siege ram war' },
    { name='Group Icon', path='esoui/art/icons/group/groupmember_default.dds', category='Icons & Skills', keywords='group party player teammate' },
    { name='Guild Icon', path='esoui/art/icons/guild/guild_rank_01.dds', category='Decorative / UI', keywords='guild rank emblem' },
    { name='Champion Points', path='esoui/art/icons/champion/champion_points.dds', category='Icons & Skills', keywords='champion points cp constellation' },
    { name='Achievement', path='esoui/art/icons/achievement_points.dds', category='Decorative / UI', keywords='achievement trophy score' },
    { name='Mail', path='esoui/art/icons/servicemappins/servicepin_mail.dds', category='Services', keywords='mail message letter' },
    { name='Banker Service', path='esoui/art/icons/servicemappins/servicepin_banker.dds', category='Services', keywords='bank storage' },
    { name='Merchant Service', path='esoui/art/icons/servicemappins/servicepin_merchant.dds', category='Services', keywords='merchant vendor shop' },
    { name='Guild Trader Service', path='esoui/art/icons/servicemappins/servicepin_guildstore.dds', category='Services', keywords='guild trader store market' },
    { name='Mages Guild Service', path='esoui/art/icons/servicemappins/servicepin_magesguild.dds', category='Services', keywords='mages guild wizard magic' },
    { name='Undaunted Service', path='esoui/art/icons/servicemappins/servicepin_undaunted.dds', category='Services', keywords='undaunted dungeon pledge' },

}

-- TTS_EXPANDED_CATALOG_V21
-- Additional high-interest candidates. The live API index in TamrielTextStudio.lua
-- adds exact paths for collectibles and trial/dungeon achievement icons returned by ESO.
local function TTSAddTexture(name, path, category, keywords)
    TTS_TEXTURES[#TTS_TEXTURES + 1] = {
        name = name, path = path, category = category, keywords = keywords or "",
    }
end

-- Public-facing map / group / dungeon / trial-style symbols from ESO's UI art.
local TTS_POI = {
    {"Area of Interest", "poi_areaofinterest_complete", "exploration region landmark"},
    {"Ayleid Ruin", "poi_ayliedruin_complete", "ayleid ruin ancient elf"},
    {"Battlefield", "poi_battlefield_incomplete", "pvp battleground battle"},
    {"Cave", "poi_cave_complete", "cave delve underground"},
    {"Cemetery", "poi_cemetery_complete", "grave cemetery undead"},
    {"City", "poi_city_complete", "city town urban"},
    {"Crafting Site", "poi_crafting_complete", "crafting station workshop"},
    {"Daedric Ruin", "poi_daedricruin_complete", "daedric oblivion ruin"},
    {"Daedric Ruin (Incomplete)", "poi_daedricruin_incomplete", "daedric oblivion ruin"},
    {"Dock", "poi_dock_complete", "dock harbor ship port"},
    {"Dungeon (Incomplete)", "poi_dungeon_incomplete", "dungeon delve"},
    {"Estate", "poi_estate_complete", "estate house manor"},
    {"Explorable Area", "poi_explorable_complete", "exploration area"},
    {"Explorable Area (Incomplete)", "poi_explorable_incomplete", "exploration area"},
    {"Farm", "poi_farm_complete", "farm agriculture"},
    {"Group Boss (Incomplete)", "poi_groupboss_incomplete", "world boss trial boss"},
    {"Grove", "poi_grove_complete", "grove nature forest"},
    {"Mine", "poi_mine_complete", "mine ore cave"},
    {"Mundus Stone", "poi_mundus_complete", "mundus stone boon"},
    {"Portal", "poi_portal_complete", "portal oblivion gate"},
    {"Portal (Incomplete)", "poi_portal_incomplete", "portal oblivion gate"},
    {"Ruin", "poi_ruin_complete", "ruin ancient"},
    {"Tower", "poi_tower_complete", "tower landmark"},
    {"Town (Incomplete)", "poi_town_incomplete", "town village"},
    {"Wayshrine (Complete)", "poi_wayshrine_complete", "wayshrine teleport travel"},
}
for _, item in ipairs(TTS_POI) do
    TTSAddTexture(item[1], "esoui/art/icons/poi/" .. item[2] .. ".dds", "Map & Travel", item[3])
end

-- Other map pins and activity symbols referenced by the ESO UI texture lists/community examples.
local TTS_PATHS = {
    {"Player Map Key", "esoui/art/icons/mapkey/mapkey_player.dds", "Map & Travel", "player map pin location"},
    {"Area of Interest Map Key", "esoui/art/icons/mapkey/mapkey_areaofinterest.dds", "Map & Travel", "map pin region"},
    {"Group Map Pin", "esoui/art/icons/mapkey/mapkey_group.dds", "Map & Travel", "group party map pin"},
    {"Wayshrine Map Key", "esoui/art/icons/mapkey/mapkey_wayshrine.dds", "Map & Travel", "wayshrine fast travel"},
    {"Dungeon Map Key", "esoui/art/icons/mapkey/mapkey_dungeon.dds", "Map & Travel", "dungeon delve"},
    {"World Boss Map Key", "esoui/art/icons/mapkey/mapkey_groupboss.dds", "Map & Travel", "world boss group"},
    {"Alliance Keep Status", "esoui/art/ava/ava_keepstatus_tabicon_wood_inactive.dds", "Factions", "pvp cyrodiil keep alliance"},
    {"Anvil Crafting Icon", "esoui/art/crafting/anvil_icon.dds", "Crafting & Items", "anvil blacksmith forge"},
    {"Bank Service Pin", "esoui/art/icons/servicemappins/servicepin_bank.dds", "Services", "bank gold storage"},
    {"Dock Service Pin", "esoui/art/icons/servicemappins/servicepin_dock.dds", "Services", "dock harbor"},
    {"Inn Service Pin", "esoui/art/icons/servicemappins/servicepin_inn.dds", "Services", "inn tavern lodging"},
    {"Outfitter Service Pin", "esoui/art/icons/servicemappins/servicepin_outfitter.dds", "Services", "outfitter outfit dye style"},
    {"Respec Altar Pin", "esoui/art/icons/servicemappins/servicepin_respecaltar.dds", "Services", "respec skills shrine"},
    {"Stable Service Pin", "esoui/art/icons/servicemappins/servicepin_stable.dds", "Services", "stable mount horse"},
    {"Vendor Service Pin", "esoui/art/icons/servicemappins/servicepin_vendor.dds", "Services", "vendor shop merchant"},
    {"Woodworker Service Pin", "esoui/art/icons/servicetooltipicons/servicepin_woodworker_new.dds", "Services", "woodworker carpenter"},
    {"Heavy Armor Service Icon", "esoui/art/icons/servicetooltipicons/servicetooltipicon_heavyarmor.dds", "Crafting & Items", "heavy armor tank"},
    {"Fighters Guild Service Icon", "esoui/art/icons/servicetooltipicons/servicetooltipicon_fightersguild.dds", "Services", "fighters guild warrior"},
    {"General Goods Service Icon", "esoui/art/icons/servicetooltipicons/servicetooltipicon_generalgoods.dds", "Services", "goods vendor shop"},
    {"Magister Service Icon", "esoui/art/icons/servicetooltipicons/servicetooltipicon_magister.dds", "Services", "magister npc quest"},
    {"Mail Service Pin", "esoui/art/icons/servicemappins/servicepin_mail.dds", "Services", "mail letter message"},
    {"Stablemaster Service Icon", "esoui/art/icons/servicetooltipicons/servicetooltipicon_stablemaster.dds", "Services", "stablemaster mount riding"},
    {"Bank Service Icon", "esoui/art/icons/servicetooltipicons/servicetooltipicon_bank.dds", "Services", "bank storage"},
    {"Guild Menu — Leave Guild", "esoui/art/guild/gamepad/gp_guild_menuicon_leaveguild.dds", "Decorative / UI", "gamepad guild menu"},
    {"Gamepad Menu — Mail", "esoui/art/tutorial/gamepad/gp_playermenu_icon_mail.dds", "Decorative / UI", "gamepad menu mail letter"},
    {"Gamepad Menu — Groups", "esoui/art/tutorial/gamepad/gp_playermenu_icon_groups.dds", "Decorative / UI", "gamepad group party"},
    {"Timed Activities Menu Icon", "esoui/art/treeicons/gamepad/gp_tutorial_idexicon_timedactivities.dds", "Decorative / UI", "timed activities endeavor event"},
    {"Online Status Icon", "esoui/art/contacts/gamepad/gp_social_status_online.dds", "Decorative / UI", "online social status"},
    {"Away Status Icon", "esoui/art/contacts/gamepad/gp_social_status_afk.dds", "Decorative / UI", "away afk social status"},
    {"Do Not Disturb Status Icon", "esoui/art/contacts/gamepad/gp_social_status_dnd.dds", "Decorative / UI", "dnd do not disturb"},
    {"Offline Status Icon", "esoui/art/contacts/gamepad/gp_social_status_offline.dds", "Decorative / UI", "offline social status"},
    {"Achievements Icon Background", "esoui/art/achievements/achievements_iconBG.dds", "Trials & Achievements", "achievement trial dungeon reward"},
    {"Undaunted Dragon Priest Helmet", "esoui/art/icons/gear_undaunted_dragonpriest_head_a.dds", "Crafting & Items", "gear helmet dragon priest undaunted"},
    {"Mirri Companion Icon", "esoui/art/icons/comp_mirri.dds", "Mounts & Companions", "companion mirri ally"},
    {"Bastian Companion Icon", "esoui/art/icons/comp_bastian.dds", "Mounts & Companions", "companion bastian ally"},
}
for _, item in ipairs(TTS_PATHS) do
    TTSAddTexture(item[1], item[2], item[3], item[4])
end

-- Class ability art families. ESO returns exact ability/collectible paths dynamically where supported;
-- these indexed class-icon families make the common skill artwork immediately searchable as well.
local TTS_CLASS_SKILLS = {
    {"Dragonknight", "dragonknight", "dragonknight dk fire draconic class"},
    {"Sorcerer", "sorcerer", "sorcerer sorc storm lightning class"},
    {"Nightblade", "nightblade", "nightblade nb shadow assassin class"},
    {"Templar", "templar", "templar holy light class"},
    {"Warden", "warden", "warden nature ice bear class"},
    {"Necromancer", "necromancer", "necromancer death bone class"},
    {"Arcanist", "arcanist", "arcanist eldritch tentacle class"},
}
for _, family in ipairs(TTS_CLASS_SKILLS) do
    for i = 1, 60 do
        local id = string.format("%03d", i)
        TTSAddTexture(family[1] .. " Skill Icon " .. id,
            "esoui/art/icons/ability_" .. family[2] .. "_" .. id .. ".dds",
            "Skills & Abilities", family[3] .. " skill ability combat icon " .. id)
    end
    local gamepad = "esoui/art/icons/class/gamepad/gp_class_" .. family[2] .. ".dds"
    TTSAddTexture(family[1] .. " Class Emblem", gamepad, "Skills & Abilities", family[3] .. " class emblem gamepad")
end

-- Broad skill-line artwork families for common weapon, guild, world and Alliance War skills.
local TTS_SKILL_LINES = {
    {"Two-Handed", "2handed", "two handed greatsword maul battleaxe"},
    {"Bow", "bow", "bow ranged archer"},
    {"Destruction Staff", "destructionstaff", "destruction staff fire frost shock"},
    {"Restoration Staff", "restorationstaff", "restoration staff healer healing"},
    {"Dual Wield", "dualwield", "dual wield daggers swords"},
    {"One-Hand and Shield", "onehandedandshield", "one hand shield sword tank"},
    {"Light Armor", "armorlight", "light armor magicka"},
    {"Medium Armor", "armormedium", "medium armor stamina"},
    {"Heavy Armor", "armorheavy", "heavy armor defense tank"},
    {"Mages Guild", "guild_magesguild", "mages guild magic mage"},
    {"Fighters Guild", "guild_fightersguild", "fighters guild fighter warrior"},
    {"Undaunted", "guild_undaunted", "undaunted dungeon pledge"},
    {"Psijic Order", "guild_psijicorder", "psijic order time magic"},
    {"Soul Magic", "world_soulmagic", "soul magic soul gem"},
    {"Vampire", "world_vampire", "vampire blood dark"},
    {"Werewolf", "world_werewolf", "werewolf lycanthrope beast"},
    {"Alliance War Assault", "alliancewar_assault", "pvp cyrodiil assault siege"},
    {"Alliance War Support", "alliancewar_support", "pvp cyrodiil support siege"},
}
for _, family in ipairs(TTS_SKILL_LINES) do
    for i = 1, 30 do
        local id = string.format("%03d", i)
        TTSAddTexture(family[1] .. " Skill Icon " .. id,
            "esoui/art/icons/ability_" .. family[2] .. "_" .. id .. ".dds",
            "Skills & Abilities", family[3] .. " skill ability combat icon " .. id)
    end
end

-- Additional numbered pet/item collectible icons complement the live collectible index.
for i = 121, 260 do
    local id = string.format("%03d", i)
    TTSAddTexture("Pet / Creature Icon " .. id, "esoui/art/icons/pet_" .. id .. ".dds",
        "Pets & Creatures", "pet creature animal companion vanity collectible " .. id)
end

