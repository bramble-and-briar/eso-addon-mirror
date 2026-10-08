local TTMP = _G.TamrielTomesMapPins
local ICONS = TTMP.icons

local DARK_ANCHOR_ZONE_IDS = {
    [3] = true, [19] = true, [20] = true, [92] = true, [104] = true,
    [381] = true, [383] = true, [108] = true, [58] = true, [382] = true,
    [41] = true, [57] = true, [117] = true, [101] = true, [103] = true,
    [181] = true,
}

local GUILD_DAILY_ZONE_IDS = { [19] = true, [57] = true, [383] = true }
local THIEVES_DEN_ZONE_IDS = { [3] = true, [816] = true } -- Daggerfall and Abah's Landing.
local DAGGERFALL_ZONE_IDS = { [3] = true }

TTMP:RegisterChallengeData({
    {
        key = "knight_commander_panthius",
        label = "Knight Commander Panthius",
        icon = ICONS.worldBoss,
        activityIds = { 663 },
        pins = {
            { type = "poi", zoneId = 823, poiIndex = 21, label = "Knight Commander Panthius" },
        },
    },
    {
        key = "bogdan_lord_warden",
        label = "Bogdan the Nightflame / Lord Warden Dusk",
        icon = ICONS.groupDungeon,
        activityIds = { 668 },
        pins = {
            { type = "poi", zoneId = 383, poiIndex = 58, label = "Bogdan the Nightflame" },
            { type = "poi", zoneId = 181, poiIndex = 104, label = "Lord Warden Dusk" },
        },
    },
    {
        key = "lava_queen_molag_kena",
        label = "Symphony of Blades / Lava Queen / Molag Kena",
        icon = ICONS.groupDungeon,
        activityIds = { 669 },
        pins = {
            { type = "poi", zoneId = 823, poiIndex = 17, label = "Symphony of Blades" },
            { type = "poi", zoneId = 103, poiIndex = 42, label = "Lava Queen" },
            { type = "poi", zoneId = 181, poiIndex = 105, label = "Molag Kena" },
            { type = "poi", zoneId = 643, poiIndex = 50, label = "Molag Kena" },
            { type = "poi", zoneId = 643, poiIndex = 51, label = "Molag Kena" },
            { type = "poi", zoneId = 643, poiIndex = 52, label = "Molag Kena" },
        },
    },
    {
        key = "serpent_sanctum_ophidia",
        label = "The Serpent",
        icon = ICONS.trial,
        activityIds = { 670 },
        pins = {
            { type = "poi", zoneId = 888, poiIndex = 33, label = "The Serpent" },
        },
    },
    {
        key = "wrothgar_public_dungeon_group_event",
        label = "Wrothgar Public Dungeon Group Event",
        icon = ICONS.publicDungeon,
        activityIds = { 666 },
        pins = {
            { type = "poi", zoneId = 684, poiIndex = 2, label = "Public Dungeon Group Event" },
            { type = "poi", zoneId = 684, poiIndex = 29, label = "Public Dungeon Group Event" },
        },
    },
    {
        key = "corintthac_zandadunoz",
        label = "Corintthac / Zandadunoz",
        icon = ICONS.worldBoss,
        activityIds = { 662 },
        pins = {
            { type = "poi", zoneId = 684, poiIndex = 15, label = "Corintthac the Abomination" },
            { type = "poi", zoneId = 684, poiIndex = 12, label = "Zandadunoz the Reborn" },
        },
    },
    {
        key = "qumehdi_zaman_macius_cento",
        label = "Qumehdi / Zaman / Macius Cento",
        activityIds = { 659 },
        pins = {
            { type = "poi", zoneId = 92, poiIndex = 47, label = "Qumehdi / Zaman", icon = ICONS.worldBoss },
            { type = "poi", zoneId = 347, poiIndex = 40, label = "Macius Cento", icon = ICONS.publicDungeon },
        },
    },
    {
        key = "zymel_etitan_kruz",
        label = "Zymel Etitan / Zymel Kruz",
        icon = ICONS.worldBoss,
        activityIds = { 658 },
        pins = {
            { type = "poi", zoneId = 108, poiIndex = 41, label = "Zymel Etitan" },
            { type = "poi", zoneId = 19, poiIndex = 49, label = "Zymel Kruz" },
        },
    },
    {
        key = "complete_arena",
        label = "Complete 1 Arena",
        icon = ICONS.arenaGeneric,
        genericIcons = {
            default = ICONS.arenaGeneric,
            complete = ICONS.arenaGenericComplete,
            incomplete = ICONS.arenaGenericIncomplete,
        },
        genericChallenge = true,
        activityIds = { 184 },
        dynamicPinType = "arena",
    },
    {
        key = "u50_talk_to_banker",
        label = "Talk to a Banker",
        icon = ICONS.bankGeneric,
        activityIds = { 570, 721 },
        dynamicPinType = "bank",
        locationPins = true,
    },
    {
        key = "u50_delve_bosses",
        label = "Kill Delve Bosses",
        icon = ICONS.delveGeneric,
        genericIcons = {
            default = ICONS.delveGeneric,
            complete = ICONS.delveGenericComplete,
            incomplete = ICONS.delveGenericIncomplete,
        },
        genericChallenge = true,
        activityIds = { 154, 634, 722 },
        dynamicPinType = "delve",
    },
    {
        key = "u50_mundus_stones",
        label = "Acquire Mundus Boons",
        icon = ICONS.mundusGeneric,
        activityIds = { 168, 723 },
        dynamicPinType = "mundus",
    },
    {
        key = "u50_world_events",
        label = "World Events",
        icon = ICONS.worldEventGeneric,
        bonusIcon = ICONS.worldEvent,
        bonusZoneIds = {
            [3] = true,
        },
        bonusActivityIds = {
            [757] = true,
        },
        genericIcons = {
            default = ICONS.worldEventGenericIncomplete,
            complete = ICONS.worldEventGenericComplete,
            incomplete = ICONS.worldEventGenericIncomplete,
            undiscovered = ICONS.worldEventGenericIncomplete,
        },
        genericChallenge = true,
        activityIds = { 187, 292, 293, 295, 296, 597, 724, 757 },
        activityZoneIds = {
            [292] = DARK_ANCHOR_ZONE_IDS,
            [597] = DARK_ANCHOR_ZONE_IDS,
            [293] = { [1011] = true }, -- Summerset geysers.
            [295] = { [1160] = true, [1161] = true, [1207] = true, [1208] = true }, -- Harrowstorms.
            [296] = { [1261] = true, [1286] = true }, -- Blackwood and Deadlands portals.
        },
        dynamicPinType = "worldEvent",
    },
    {
        key = "u50_world_bosses",
        label = "World Bosses",
        icon = ICONS.worldBossGeneric,
        genericIcons = {
            default = ICONS.worldBossGeneric,
            complete = ICONS.worldBossGenericComplete,
            incomplete = ICONS.worldBossGenericIncomplete,
            undiscovered = ICONS.worldBossGenericIncomplete,
        },
        genericChallenge = true,
        activityIds = { 54, 740, 747, 750 },
        dynamicPinType = "worldBoss",
    },
    {
        key = "u50_freerunners_post_favors",
        label = "Freerunners Post Favors",
        icon = ICONS.freerunner,
        genericIcons = {
            default = ICONS.freerunnerIncomplete,
            complete = ICONS.freerunnerComplete,
            incomplete = ICONS.freerunnerIncomplete,
            undiscovered = ICONS.freerunnerIncomplete,
        },
        genericChallenge = true,
        activityIds = { 759 },
        dynamicPinType = "freerunner",
    },
    {
        key = "thieves_den_quests",
        label = "Thieves Den Quests",
        icon = ICONS.thievesDen,
        activityIds = { 172, 762, 763 },
        activityZoneIds = {
            [172] = THIEVES_DEN_ZONE_IDS,
            [762] = THIEVES_DEN_ZONE_IDS,
            [763] = THIEVES_DEN_ZONE_IDS,
        },
        dynamicPinType = "thievesDen",
        locationPins = true,
        -- City-map coordinates verified with GetMapLocationIcon in the live client.
        overviewPins = {
            { type = "coordinates", id = "location:993:15", zoneId = 816, mapId = 993, x = .20337, y = .42852, label = "Thieves Den" },
            { type = "coordinates", id = "location:993:16", zoneId = 816, mapId = 993, x = .27775, y = .34201, label = "Thieves Den" },
        },
    },
    {
        key = "daggerfall_thieves_guild_quests",
        label = "Daggerfall Thieves Guild Quests",
        icon = ICONS.outlawsRefuge,
        activityIds = { 172, 762, 763 },
        activityZoneIds = {
            [172] = DAGGERFALL_ZONE_IDS,
            [762] = DAGGERFALL_ZONE_IDS,
            [763] = DAGGERFALL_ZONE_IDS,
        },
        dynamicPinType = "outlawsRefuge",
        locationPins = true,
        overviewPins = {
            { type = "coordinates", id = "location:63:14", zoneId = 3, mapId = 63, x = .30467, y = .20758, label = "Daggerfall Outlaws Refuge" },
            { type = "coordinates", id = "location:63:15", zoneId = 3, mapId = 63, x = .70551, y = .28749, label = "Daggerfall Outlaws Refuge" },
        },
    },
    {
        key = "dark_brotherhood_daily_quests",
        label = "Dark Brotherhood Daily Quests",
        icon = ICONS.darkBrotherhoodIncomplete,
        genericChallenge = true,
        genericIcons = {
            complete = ICONS.darkBrotherhoodComplete,
            incomplete = ICONS.darkBrotherhoodIncomplete,
            undiscovered = ICONS.darkBrotherhoodIncomplete,
        },
        activityIds = { 762 },
        activityZoneIds = { [762] = { [823] = true } },
        dynamicPinType = "darkBrotherhood",
    },
    {
        key = "u50_fighters_guild_quest",
        label = "Fighters Guild Quest",
        icon = ICONS.fightersGuildGeneric,
        activityIds = { 594, 725, 762 },
        activityZoneIds = { [762] = GUILD_DAILY_ZONE_IDS },
        dynamicPinType = "fightersGuild",
        locationPins = true,
    },
    {
        key = "u50_mages_guild_quest",
        label = "Mages Guild Quest",
        icon = ICONS.magesGuildGeneric,
        activityIds = { 595, 726, 762 },
        activityZoneIds = { [762] = GUILD_DAILY_ZONE_IDS },
        dynamicPinType = "magesGuild",
        locationPins = true,
    },
    {
        key = "u50_guild_trader",
        label = "Visit a Guild Trader",
        icon = ICONS.guildTraderGeneric,
        activityIds = { 372, 603, 729 },
        dynamicPinType = "guildTrader",
        locationPins = true,
    },
    {
        key = "u50_undaunted_quest",
        label = "Undaunted Quest",
        icon = ICONS.undauntedGeneric,
        activityIds = { 596, 730, 762 },
        activityZoneIds = { [762] = GUILD_DAILY_ZONE_IDS },
        dynamicPinType = "undaunted",
        locationPins = true,
    },
    {
        key = "wondrous_nowhere_keys",
        label = "Collect Wondrous Nowhere Keys",
        icon = ICONS.museum,
        activityIds = { 760 },
        activityZoneIds = { [760] = { [753] = true } },
        dynamicPinType = "museum",
        locationPins = true,
        locationIndicesByMapId = { [807] = { [9] = true } },
    },
    {
        key = "nowhere_vault_rooms",
        label = "Complete Rooms in the Nowhere Vault",
        icon = ICONS.publicDungeon,
        activityIds = { 783 },
        pins = {
            { type = "poi", zoneId = 3, poiIndex = 76, label = "Vault Nexus" },
        },
    },
    {
        key = "u50_public_dungeon_bosses",
        label = "Public Dungeons",
        icon = ICONS.publicDungeonGeneric,
        genericIcons = {
            default = ICONS.publicDungeonGeneric,
            complete = ICONS.publicDungeonGenericComplete,
            incomplete = ICONS.publicDungeonGenericIncomplete,
            undiscovered = ICONS.publicDungeonGenericIncomplete,
        },
        genericChallenge = true,
        activityIds = { 153, 183, 412, 634, 739, 746, 749 },
        dynamicPinType = "publicDungeon",
    },
    {
        key = "u50_dynamic_encounters",
        label = "Dynamic Encounters",
        hideDescription = true,
        icon = ICONS.dynamicEncounterGeneric,
        genericChallenge = true,
        activityIds = { 755 },
        -- Encounter locations are not POIs; coordinates from Map Pins' zone data.
        pins = {
            { type = "coordinates", id = "dynamic_encounter", zoneId = 3, x = .663, y = .301, label = "Vampire Hunt" },
            { type = "coordinates", id = "dynamic_encounter", zoneId = 381, x = .648, y = .834, label = "Farm Aflame" },
            { type = "coordinates", id = "dynamic_encounter", zoneId = 41, x = .367, y = .439, label = "Safely Delivered" },
        },
    },
    {
        key = "u50_fungal_grotto_1",
        label = "Fungal Grotto I",
        icon = ICONS.groupDungeon,
        activityIds = { 254, 732 },
        pins = {
            { type = "poi", zoneId = 41, poiIndex = 34, label = "Fungal Grotto I" },
        },
    },
    {
        key = "complete_dungeon",
        label = "Complete 1 Dungeon",
        icon = ICONS.groupDungeonGeneric,
        bonusIcon = ICONS.groupDungeon,
        bonusZoneIds = {
            [3] = true,
        },
        bonusActivityIds = {
            [761] = true,
        },
        genericIcons = {
            default = ICONS.groupDungeonGeneric,
            complete = ICONS.groupDungeonGenericComplete,
            incomplete = ICONS.groupDungeonGenericIncomplete,
        },
        genericChallenge = true,
        activityIds = { 182, 318, 446, 447, 448, 449, 450, 605, 671, 761 },
        dynamicPinType = "groupDungeon",
    },
    {
        key = "complete_trial",
        label = "Complete 1 Trial",
        icon = ICONS.trialGeneric,
        genericIcons = {
            default = ICONS.trialGeneric,
            complete = ICONS.trialGenericComplete,
            incomplete = ICONS.trialGenericIncomplete,
        },
        genericChallenge = true,
        activityIds = { 185, 319, 413, 451, 452, 453, 454 },
        dynamicPinType = "trial",
    },
})
