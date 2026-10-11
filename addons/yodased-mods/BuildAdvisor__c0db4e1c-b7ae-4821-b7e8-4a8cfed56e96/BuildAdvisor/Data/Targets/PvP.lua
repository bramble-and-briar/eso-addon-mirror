local BA = BuildAdvisor
-- PvP. Meta last checked: Update 51 (starting values, unverified in game).

BA.RegisterActivity({
    id = "cyrodiil",
    name = "Cyrodiil",
    note = "Open-world PvP.",
    target = {
        -- Player resistances vary too much for a single penetration target.
        health = { damage = { 25000 }, tank = { 35000 }, healer = { 25000 } },
        resist = { damage = 25000, tank = BA.RESIST_CAP, healer = 25000 },
        pvp = true,
        note = "PvP: survive first. Impenetrable armor and higher resistances matter.",
    },
})
