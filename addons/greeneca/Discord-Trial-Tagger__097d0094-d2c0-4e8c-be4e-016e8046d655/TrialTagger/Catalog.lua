-- GENERATED FILE -- DO NOT EDIT.
-- Produced by tools/gen_addon_catalog.py from shared/trials.json.
-- Edit the JSON and re-run the generator instead.

TrialTagger = TrialTagger or {}
local TT = TrialTagger

TT.Catalog = {

    payloadVersion = 2,
    catalogVersion = 3,
    numTrials = 15,
    trialBits = 58,
    trialBytes = 10,
    maxSlots = 5,

    panel = {
        width = 1280,
        height = 780,
        padding = 24,
        stripTop = 134,
        stripHeight = 72,
        accountTop = 64,
        accountHeight = 34,
    },

    tiers = {
        { key = "vet_complete", short = "vC", label = "Veteran Clear", match = "all" },
        { key = "vet_hm_boss", short = "vHMB", label = "Veteran Hard Mode Boss", match = "all" },
        { key = "vet_hm_complete", short = "vHM", label = "Veteran Hard Mode Clear", match = "all" },
        { key = "trifecta", short = "TRI", label = "Trifecta", match = "all" },
        { key = "complete", short = "C", label = "Clear", match = "all" },
        { key = "no_death", short = "ND", label = "No Death", match = "all" },
    },

    trials = {
        {
            index = 0,
            key = "hrc",
            abbr = "HRC",
            name = "Hel Ra Citadel",
            prefix = "V",
            width = 2,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 2, short = "vC", label = "vC", ids = { 1474 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 1, short = "vHM", label = "HM", ids = { 1136 } },
            },
        },
        {
            index = 1,
            key = "aa",
            abbr = "AA",
            name = "Aetherian Archive",
            prefix = "V",
            width = 2,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 2, short = "vC", label = "vC", ids = { 1503 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 1, short = "vHM", label = "HM", ids = { 1137 } },
            },
        },
        {
            index = 2,
            key = "so",
            abbr = "SO",
            name = "Sanctum Ophidia",
            prefix = "V",
            width = 2,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 2, short = "vC", label = "vC", ids = { 1462 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 1, short = "vHM", label = "HM", ids = { 1138 } },
            },
        },
        {
            index = 3,
            key = "mol",
            abbr = "MOL",
            name = "Maw of Lorkhaj",
            prefix = "V",
            width = 2,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 2, short = "vC", label = "vC", ids = { 1368 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 1, short = "vHM", label = "HM", ids = { 1344 } },
            },
        },
        {
            index = 4,
            key = "hof",
            abbr = "HOF",
            name = "Halls of Fabrication",
            prefix = "V",
            width = 3,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 4, short = "vC", label = "vC", ids = { 1810 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 1829 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Tick-Tock Tormentor", ids = { 1838 } },
            },
        },
        {
            index = 5,
            key = "as",
            abbr = "AS",
            name = "Asylum Sanctorium",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 2077 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "+Llo", label = "+ Llothis", ids = { 2085 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "+Fel", label = "+ Felms", ids = { 2086 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 2079 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Immortal Redeemer", ids = { 2087 } },
            },
        },
        {
            index = 6,
            key = "cr",
            abbr = "CR",
            name = "Cloudrest",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 2133 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "+1", label = "+1", ids = { 2134 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "+2", label = "+2", ids = { 2135 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 2136 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Gryphon Heart", ids = { 2139 } },
            },
        },
        {
            index = 7,
            key = "ss",
            abbr = "SS",
            name = "Sunspire",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 2435 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "Lok", label = "HM Lokkestiiz", ids = { 2470 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "Yol", label = "HM Yolnahkriin", ids = { 2469 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 2466 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Godslayer", ids = { 2467 } },
            },
        },
        {
            index = 8,
            key = "ka",
            abbr = "KA",
            name = "Kyne's Aegis",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 2734 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "Yandir", label = "HM Yandir", ids = { 2736 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "Vrol", label = "HM Vrol", ids = { 2737 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 2739 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Kyne's Wrath", ids = { 2740 } },
            },
        },
        {
            index = 9,
            key = "rg",
            abbr = "RG",
            name = "Rockgrove",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 2987 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "Oax", label = "HM Oaxiltso", ids = { 3005 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "Bahsei", label = "HM Bahsei", ids = { 3006 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 3007 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Planesbreaker", ids = { 3003 } },
            },
        },
        {
            index = 10,
            key = "dsr",
            abbr = "DSR",
            name = "Dreadsail Reef",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 3244 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "L&T", label = "HM Lylanar & Turlassil", ids = { 3250 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "Reef", label = "HM Reef Guardian", ids = { 3251 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 3252 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Soul of the Squall", ids = { 3248 } },
            },
        },
        {
            index = 11,
            key = "se",
            abbr = "SE",
            name = "Sanity's Edge",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 3560 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "Yaseyla", label = "HM Yaseyla", ids = { 3566 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "Twelvane", label = "HM Twelvane", ids = { 3567 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 3568 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Dream Master", ids = { 3564 } },
            },
        },
        {
            index = 12,
            key = "lc",
            abbr = "LC",
            name = "Lucent Citadel",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 4015 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "R&Z", label = "HM Ryelaz & Zilyesset", ids = { 4021 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "Shard", label = "HM Shard", ids = { 4022 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 4023 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Unstoppable", ids = { 4019 } },
            },
        },
        {
            index = 13,
            key = "oc",
            abbr = "OC",
            name = "Ossein Cage",
            prefix = "V",
            width = 5,
            slots = {
                { key = "vet_complete", tier = "vet_complete", mask = 16, short = "vC", label = "vC", ids = { 4268 } },
                { key = "vet_hm_boss_1", tier = "vet_hm_boss", mask = 8, short = "Flesh", label = "HM Shapers of Flesh", ids = { 4274 } },
                { key = "vet_hm_boss_2", tier = "vet_hm_boss", mask = 4, short = "J&S", label = "HM Jynorah & Skorkhif", ids = { 4275 } },
                { key = "vet_hm_complete", tier = "vet_hm_complete", mask = 2, short = "vHM", label = "HM", ids = { 4276 } },
                { key = "trifecta", tier = "trifecta", mask = 1, short = "TRI", label = "Misery's Master", ids = { 4272 } },
            },
        },
        {
            index = 14,
            key = "oo",
            abbr = "OO",
            name = "Opulent Ordeal",
            prefix = "",
            width = 2,
            slots = {
                { key = "complete", tier = "complete", mask = 2, short = "C", label = "C", ids = { 4517 } },
                { key = "no_death", tier = "no_death", mask = 1, short = "ND", label = "Pathwalker", ids = { 4485 } },
            },
        },
    },
}

-- Convenience lookup so the UI can resolve a tier by key without a scan.
TT.Catalog.tierByKey = {}
for _, tier in ipairs(TT.Catalog.tiers) do
    TT.Catalog.tierByKey[tier.key] = tier
end
