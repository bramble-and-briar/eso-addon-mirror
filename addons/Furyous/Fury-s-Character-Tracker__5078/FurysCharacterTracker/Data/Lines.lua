-- The skill lines on the board, grouped.
-- name: the line's name as the game shows it (English client). max: its top rank.
-- (Scribing is not here: it has no skill line. It is learned like recipes, so the board counts it.)
-- short: column title on the board. keepPeak: the game hides the line when you are cured,
-- so the board keeps the highest rank it has ever seen instead of dropping to nothing.
local CT = FurysCharacterTracker

CT.GROUPS = {
    { id = "weapons", title = "Weapons", lines = {
        { name = "Two Handed",          short = "2H",      max = 50 },
        { name = "One Hand and Shield", short = "1H+S",    max = 50 },
        { name = "Dual Wield",          short = "DW",      max = 50 },
        { name = "Bow",                 short = "Bow",     max = 50 },
        { name = "Destruction Staff",   short = "Destro",  max = 50 },
        { name = "Restoration Staff",   short = "Resto",   max = 50 },
    } },
    { id = "armor", title = "Armor", lines = {
        { name = "Light Armor",  short = "Light",  max = 50 },
        { name = "Medium Armor", short = "Medium", max = 50 },
        { name = "Heavy Armor",  short = "Heavy",  max = 50 },
    } },
    { id = "guilds", title = "Guilds & AvA", lines = {
        { name = "Dark Brotherhood", short = "Dark Bro",  max = 12 },
        { name = "Fighters Guild",   short = "Fighters",  max = 10 },
        { name = "Mages Guild",      short = "Mages",     max = 10 },
        { name = "Psijic Order",     short = "Psijic",    max = 10 },
        { name = "Thieves Guild",    short = "Thieves",   max = 12 },
        { name = "Undaunted",        short = "Undaunted", max = 10 },
        { name = "Assault",          short = "Alliance War", max = 10 },  -- Support ranks with it
    } },
    { id = "world", title = "World", lines = {
        { name = "Excavation",  short = "Antiquities", max = 10 },  -- Scrying ranks with it
        { name = "Soul Magic",  short = "Soul Magic",  max = 6 },
        { name = "Legerdemain", short = "Legerdemain", max = 20 },
        { name = "Vampire",     short = "Vampire",     max = 10, keepPeak = true },
        { name = "Werewolf",    short = "Werewolf",    max = 10, keepPeak = true },
    } },
    { id = "crafting", title = "Crafting", lines = {
        { name = "Blacksmithing",    short = "Smith",   max = 50 },
        { name = "Clothing",         short = "Cloth",   max = 50 },
        { name = "Woodworking",      short = "Wood",    max = 50 },
        { name = "Jewelry Crafting", short = "Jewelry", max = 50 },
        { name = "Alchemy",          short = "Alchemy", max = 50 },
        { name = "Enchanting",       short = "Enchant", max = 50 },
        { name = "Provisioning",     short = "Provis",  max = 50 },
    } },
}

CT.RESEARCH_TOTAL = 324   -- 9 traits on each of 36 items (smithing, clothing, woodworking, jewelry)
CT.CP_MAX = 3600         -- Champion Point cap; change it here if ZOS raises it
CT.RIDING_MAX = 180       -- speed, stamina and capacity, 60 each
CT.SKILL_POINTS_MAX = 586 -- most a character can earn as of Update 50 (Nov 2026); change it if ZOS adds more
CT.COMPANION_TOTAL = 8
CT.SCRIPTS_TOTAL = 79     -- scribing grimoires + scripts, until the game has told us how many exist    -- used until the game has told us how many companions exist

-- Language-neutral IDs, so the addon works on every client language. Taken with /fct ids on an
-- English client: [skillLineId] = English line name, [questId] = companion short name.
-- Anything missing here falls back to matching the English name.
CT.SKILL_LINE_IDS = {
    [24] = "Light Armor", [25] = "Medium Armor", [26] = "Heavy Armor",
    [29] = "One Hand and Shield", [30] = "Two Handed", [31] = "Dual Wield", [32] = "Bow",
    [33] = "Destruction Staff", [34] = "Restoration Staff",
    [44] = "Mages Guild", [45] = "Fighters Guild", [48] = "Assault", [55] = "Undaunted",
    [117] = "Thieves Guild", [118] = "Dark Brotherhood", [130] = "Psijic Order",
    [50] = "Werewolf", [51] = "Vampire", [72] = "Soul Magic", [111] = "Legerdemain", [157] = "Excavation",
    [76] = "Provisioning", [77] = "Alchemy", [78] = "Enchanting", [79] = "Blacksmithing",
    [80] = "Woodworking", [81] = "Clothing", [141] = "Jewelry Crafting",
}
CT.INTRO_QUEST_IDS = {
    [6626] = "Bastian", [6648] = "Mirri", [6760] = "Isobel", [6771] = "Ember",
    [7017] = "Sharp", [7021] = "Azandar", [7186] = "Tanlorin", [7194] = "Zerith",
}

-- Lines by name, for the scanner and the board.
CT.LINE_BY_NAME = {}
for _, group in ipairs(CT.GROUPS) do
    for _, line in ipairs(group.lines) do
        line.group = group.id
        CT.LINE_BY_NAME[line.name] = line
    end
end
