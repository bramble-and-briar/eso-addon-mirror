local BA = BuildAdvisor
-- 4-man organized groups with a known comp. Meta last checked: Update 51 (starting values,
-- unverified in game). PUG debuffs plus Brittle, Chilled, Diseased and Poisoned
-- (BA.KNOWN_COMP_DEBUFFS), so damage dealers push crit and damage instead of penetration.

BA.RegisterActivity({
    id = "group4_organized",
    name = "4-man Organized",
    note = "Veteran dungeons and group arenas with a set group.",
    target = {
        enemyResistance = BA.VETERAN_RESISTANCE,
        debuffs = BA.KNOWN_COMP_DEBUFFS,
        health = { damage = { 18000, 22000 }, tank = { 30000, 40000 }, healer = { 18000, 24000 } },
        resist = { tank = BA.RESIST_CAP },
        groupContent = true,
        crusherFrom = "tank",
        note = "Known comp: the group keeps Breach and most status effects up. Push crit and damage.",
    },
})
