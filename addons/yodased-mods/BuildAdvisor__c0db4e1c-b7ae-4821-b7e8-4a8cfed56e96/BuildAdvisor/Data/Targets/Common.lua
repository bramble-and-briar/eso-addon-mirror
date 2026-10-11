local BA = BuildAdvisor
-- Shared values for the target files in this folder. Each file covers one content tier and
-- starts with the patch its numbers were last checked against; update them with the meta.
--
-- Target fields (all optional):
--   enemyResistance   resistance of enemies in this content
--   debuffs           debuff ids (BA.DEBUFFS) a group in this tier can be assumed to keep up;
--                     groupPenetration and statusCount are worked out from it
--   extraPenetration  penetration from sources not in BA.DEBUFFS (e.g. score-run sets)
--   health            { role = { min, max } }; above max the stats are better spent elsewhere
--   resist            { role = minimum resistance }
--   groupContent      true when group buffs/debuffs apply (crit and damage get prioritized)
--   pvp               true for PvP rules (Impenetrable, no penetration target)
--   crusherFrom       who brings Crusher: "tank" (4-man) or "off tank" (12-man); tanks are
--                     checked for a Crusher weapon enchant
--   note              shown under Survivability to damage dealers
--   roleNotes         { role = note } for tanks/healers (or to override the damage note)

BA.RESIST_CAP = 33100 -- 50% mitigation
BA.VETERAN_RESISTANCE = 18200
-- Force of Nature CP star: penetration per negative status effect on the target. Needs checking.
BA.FORCE_OF_NATURE_PER_STATUS = 660

-- pen: resistance it removes. status: counts toward Force of Nature (needs checking for
-- Off Balance and Brittle, which are treated as non-status debuffs here).
BA.DEBUFFS = {
    major_breach = { name = "Major Breach", pen = 5948 },
    sundered = { name = "Sundered (Minor Breach)", pen = 2974, status = true },
    crusher = { name = "Crusher", pen = 2108 },
    off_balance = { name = "Off Balance" },
    bleeding = { name = "Bleeding", status = true },
    burning = { name = "Burning", status = true },
    brittle = { name = "Brittle" },
    chilled = { name = "Chilled", status = true },
    diseased = { name = "Diseased", status = true },
    poisoned = { name = "Poisoned", status = true },
}

-- What a pick-up group can be assumed to keep on a boss, and what a known comp adds.
-- Crusher comes from the tank in 4-man and the off tank in 12-man (see crusherFrom).
BA.PUG_DEBUFFS = { "major_breach", "sundered", "crusher", "off_balance", "bleeding", "burning" }
BA.KNOWN_COMP_DEBUFFS = {
    "major_breach", "sundered", "crusher", "off_balance", "bleeding", "burning",
    "brittle", "chilled", "diseased", "poisoned",
}
