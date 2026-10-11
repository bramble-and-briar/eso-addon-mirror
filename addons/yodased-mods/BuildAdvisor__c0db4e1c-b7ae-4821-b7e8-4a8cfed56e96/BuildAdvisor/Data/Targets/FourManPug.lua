local BA = BuildAdvisor
-- 4-man pick-up groups. Meta last checked: Update 51 (starting values, unverified in game).
-- Assume Major Breach plus Sundered, Off Balance, Bleeding and Burning (BA.PUG_DEBUFFS).

BA.RegisterActivity({
    id = "group4_pug",
    name = "4-man PUG",
    note = "Random-group veteran dungeons and group arenas (Dragonstar, Blackrose Prison).",
    target = {
        enemyResistance = BA.VETERAN_RESISTANCE,
        debuffs = BA.PUG_DEBUFFS,
        health = { damage = { 20000, 26000 }, tank = { 35000, 45000 }, healer = { 20000, 26000 } },
        resist = { tank = BA.RESIST_CAP },
        groupContent = true,
        crusherFrom = "tank",
        note = "PUG: expect Major Breach and the common status effects, nothing more. Carry a little extra health.",
        roleNotes = {
            tank = "PUG: Major Breach is assumed in every PUG, so make sure it's on your bar.",
            healer = "PUG: expect more damage taken than in a set group; keep some self-sustain.",
        },
    },
})
