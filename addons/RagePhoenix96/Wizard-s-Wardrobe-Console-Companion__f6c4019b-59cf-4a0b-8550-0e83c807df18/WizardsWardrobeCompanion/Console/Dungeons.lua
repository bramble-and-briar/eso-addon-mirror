WizardsWardrobeCompanion = WizardsWardrobeCompanion or {}
local companion = WizardsWardrobeCompanion

-- Keep the same tags/condition key as the earlier local patch for saved builds.
companion.bossKey = "WW_DUNGEON_BOSS"
companion.dungeons = {
    {
        tag = "DUN",
        name = "Dungeons",
        category = "DUNGEONS",
        priority = 20,
        icon = "/esoui/art/lfg/lfg_indexicon_dungeon_up.dds",
        ids = {
            11, 22, 31, 38, 63, 64, 126, 130, 131, 144, 146, 148, 176,
            283, 380, 449, 678, 681, 688, 930, 931, 932, 933, 934, 935, 936,
        },
    },
    {
        tag = "DLC",
        name = "DLC Dungeons",
        category = "DLC_DUNGEONS",
        priority = 21,
        icon = "/esoui/art/treeicons/store_indexicon_dungdlc_up.dds",
        ids = {
            843, 848, 973, 974, 1009, 1010, 1052, 1055, 1080, 1081,
            1122, 1123, 1152, 1153, 1197, 1201, 1228, 1229, 1267, 1268,
            1301, 1302, 1360, 1361, 1389, 1390, 1470, 1471, 1496, 1497,
            1551, 1552,
        },
    },
}
