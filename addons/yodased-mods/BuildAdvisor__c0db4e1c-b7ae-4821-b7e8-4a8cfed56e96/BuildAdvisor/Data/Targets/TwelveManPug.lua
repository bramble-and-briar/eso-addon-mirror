local BA = BuildAdvisor
-- 12-man pick-up trials. Meta last checked: Update 51 (starting values, unverified in game).
-- Assume Major Breach plus Sundered, Off Balance, Bleeding and Burning (BA.PUG_DEBUFFS).

BA.RegisterActivity({
    id = "group12_pug",
    name = "12-man PUG",
    note = "Random-group trials.",
    target = {
        enemyResistance = BA.VETERAN_RESISTANCE,
        debuffs = BA.PUG_DEBUFFS,
        health = { damage = { 20000, 24000 }, tank = { 40000, 50000 }, healer = { 20000, 25000 } },
        resist = { tank = BA.RESIST_CAP },
        groupContent = true,
        crusherFrom = "off tank",
        note = "PUG trial: expect Major Breach and the common status effects, nothing more.",
        roleNotes = {
            tank = "PUG trial: agree with the other tank who keeps Major Breach up.",
        },
    },
})
