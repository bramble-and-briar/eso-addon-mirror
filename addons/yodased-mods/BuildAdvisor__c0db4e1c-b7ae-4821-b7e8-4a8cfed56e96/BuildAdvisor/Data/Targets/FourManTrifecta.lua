local BA = BuildAdvisor
-- 4-man progression: hard mode, speed run and no death in one run. Meta last checked:
-- Update 51 (starting values, unverified in game). Known-comp debuffs, but no deaths
-- allowed, so health floors sit a little higher than plain organized runs.

BA.RegisterActivity({
    id = "group4_trifecta",
    name = "4-man Trifecta",
    note = "Hard mode + speed run + no death in veteran dungeons and group arenas.",
    target = {
        enemyResistance = BA.VETERAN_RESISTANCE,
        debuffs = BA.KNOWN_COMP_DEBUFFS,
        health = { damage = { 20000, 24000 }, tank = { 35000, 45000 }, healer = { 20000, 26000 } },
        resist = { tank = BA.RESIST_CAP },
        groupContent = true,
        crusherFrom = "tank",
        note = "No-death runs: one death fails it, so don't go glass cannon. The group keeps Breach and status effects up.",
    },
})
