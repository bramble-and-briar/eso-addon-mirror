local BA = BuildAdvisor
-- PvE solo and 2-man. Meta last checked: Update 51 (starting values, unverified in game).
-- Solo means no group debuffs: all penetration comes from the player.

BA.RegisterActivity({
    id = "overland",
    name = "Overland / Questing",
    note = "Overland, delves, world bosses, public dungeons.",
    target = {
        enemyResistance = 8000,
        health = { damage = { 16000 }, tank = { 22000, 35000 }, healer = { 16000 } },
        note = "Overland enemies are soft; damage and speed matter more than defense.",
    },
})

BA.RegisterActivity({
    id = "solo_arena",
    name = "Solo Arena",
    note = "Maelstrom Arena, Vateshran Hollows.",
    target = {
        enemyResistance = BA.VETERAN_RESISTANCE,
        health = { damage = { 22000 }, tank = { 30000, 45000 }, healer = { 22000 } },
        note = "Solo: no group debuffs, so all 18,200 penetration comes from you.",
    },
})

BA.RegisterActivity({
    id = "infinite_archive",
    name = "Infinite Archive",
    note = "Solo or duo.",
    target = {
        enemyResistance = BA.VETERAN_RESISTANCE,
        health = { damage = { 22000 }, tank = { 30000, 45000 }, healer = { 22000 } },
        note = "Treated as solo; with a duo partner bringing Breach you need less.",
    },
})
