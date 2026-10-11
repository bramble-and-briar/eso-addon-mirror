local BA = BuildAdvisor
-- Human-readable acquisition data is useful even without collection APIs.
-- Map IDs, set IDs, individual drops and coordinates MUST be validated before publishing.
BA.gearSources = {
    sergeants_mail = { name = "Sergeant's Mail", source = "Wayrest Sewers I & II", zone = "Stormhaven", method = "Dungeon bosses and chests. Final boss is a key source of weapons/jewelry; verify specific loot slots." },
    infallible_mage = { name = "Infallible Mage", source = "Craglorn trials", zone = "Craglorn", method = "Trial rewards. Check current trial-specific drop tables before farming." },
    noble_duelist = { name = "Noble Duelist's Silks", source = "Blessed Crucible", zone = "The Rift", method = "Dungeon boss and chest drops." },
    oakensoul = { name = "Oakensoul Ring", source = "Antiquities", zone = "Multiple zones", method = "Find the required leads, scry and excavate; requires access to Antiquities." },
    slimecraw = { name = "Slimecraw", source = "Wayrest Sewers I", zone = "Stormhaven", method = "Veteran dungeon monster helmet; shoulders through relevant Undaunted coffers." },
}
