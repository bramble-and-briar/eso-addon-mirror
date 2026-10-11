local BA = BuildAdvisor
BA.builds = {
    oak_sorc_ia = {
        id = "oak_sorc_ia",
        name = "Solo Arena Heavy Attack Sorcerer",
        class = "sorcerer",
        role = "solo_arena",
        activity = { "vma", "vateshran", "solo_pve" },
        difficulty = "comfortable",
        description = "Ranged lightning heavy attacks; high self-penetration, shields, and execute damage.",
        sets = {
            { id = "sergeants_mail", pieces = 5 },
            { id = "infallible_mage", pieces = 5 },
            { id = "oakensoul", pieces = 1 },
            { id = "slimecraw", pieces = 1 },
        },
        skills = { "Hardened Ward", "Lightning Form", "Mage's Wrath", "Elemental Blockade", "Twilight Matriarch" },
        ultimate = "Summon Storm Atronach",
        notes = {
            "Lover Mundus and Sharpened staff prioritize solo penetration.",
            "Infallible Mage provides Minor Vulnerability without melee activation.",
            "Adjust gear choices to actual arena mechanics rather than a trial dummy parse.",
        },
        -- This is an example build; validate exact equipment slots before publishing.
    },
    oak_sorc_noble = {
        id = "oak_sorc_noble",
        name = "Solo Arena Heavy Attack Sorcerer (Noble test)",
        class = "sorcerer", role = "solo_arena", activity = { "vma", "vateshran" },
        sets = {
            { id = "sergeants_mail", pieces = 5 },
            { id = "noble_duelist", pieces = 5 },
            { id = "oakensoul", pieces = 1 },
            { id = "slimecraw", pieces = 1 },
        },
        description = "Comparison variant: Noble Duelist requires melee activation, then grants a temporary ranged-compatible heavy attack bonus.",
    },
}
