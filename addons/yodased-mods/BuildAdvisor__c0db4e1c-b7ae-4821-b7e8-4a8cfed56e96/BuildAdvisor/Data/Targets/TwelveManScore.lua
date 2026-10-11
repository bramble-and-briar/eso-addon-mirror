local BA = BuildAdvisor
-- 12-man score pushing and trifectas. Meta last checked: Update 51 (starting values,
-- unverified in game). Known-comp debuffs plus extra debuff sets, so damage dealers need very
-- little penetration of their own and run lean on health.

-- Estimate for the extra debuff sets score groups run (Alkosh, Tremorscale and similar).
-- Needs checking against current set values.
local SCORE_EXTRA_DEBUFFS = 3000

BA.RegisterActivity({
    id = "group12_score",
    name = "12-man Score / Trifecta",
    note = "Leaderboard score runs and trial trifectas.",
    target = {
        enemyResistance = BA.VETERAN_RESISTANCE,
        debuffs = BA.KNOWN_COMP_DEBUFFS,
        extraPenetration = SCORE_EXTRA_DEBUFFS,
        health = { damage = { 17000, 21000 }, tank = { 35000, 45000 }, healer = { 18000, 24000 } },
        resist = { tank = BA.RESIST_CAP },
        groupContent = true,
        crusherFrom = "off tank",
        note = "Score runs: the group stacks debuffs, so almost all your stats should go to damage. Trifecta adds no-death, so keep the health floor.",
    },
})
