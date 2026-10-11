local BA = BuildAdvisor
-- 12-man organized trials with a known comp. Meta last checked: Update 51 (starting values,
-- unverified in game). PUG debuffs plus Brittle, Chilled, Diseased and Poisoned.

BA.RegisterActivity({
    id = "group12_organized",
    name = "12-man Organized",
    note = "Trials with a set group (progression, farm runs).",
    target = {
        enemyResistance = BA.VETERAN_RESISTANCE,
        debuffs = BA.KNOWN_COMP_DEBUFFS,
        health = { damage = { 18000, 22000 }, tank = { 40000, 50000 }, healer = { 20000, 25000 } },
        resist = { tank = BA.RESIST_CAP },
        groupContent = true,
        crusherFrom = "off tank",
        note = "Known comp: the group keeps Breach and most status effects up. Push crit and damage.",
    },
})
