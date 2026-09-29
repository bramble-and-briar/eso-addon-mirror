-- OCCP_Data.lua
-- All build data lives here so it is easy to edit when the meta changes.
-- Structure: OCCP.Data[mode][role]  where mode = "PVE" | "PVP", role = "MAG" | "STAM" | "HEAL" | "TANK"
-- HEAL and TANK exist for PvE only.
-- Each slot list = the 4 slottable stars of that tree, in priority order.
-- "passives" = the non-slottable stars worth investing in, with suggested points,
-- in the order a low-CP character should buy them.
-- "sources" = credits shown in the window footer (name + update); "note" = one short tip.
-- Per-class differences go in OCCP.ClassOverrides at the bottom (only what differs).
--
-- Sources (checked 28 Sept 2026):
--   PvE DPS / Healer / Tank: hyperioxes.com (U50 guides, Aug 2026)
--   PvE DPS class tweaks:    skinnycheeks.gg (U51 class pages)
--   PvP:                     eso-pvp-builds.com (U50 class builds)

OCCP = OCCP or {}

-- Passive spreads: Hyperioxes unlock orders, final point values.
--   Magicka / Stamina: his Magicka NB and Stamina Warden DPS pages.
--   Support (Healer, also used for Tank): his Templar Healer page. His tank
--   pages list no passives, so tanks use the healer spread.
--   Fitness: the same on all his pages.
-- Craft stars and craft passives are the addon's own picks (Hyperioxes: "Green
-- Champion Points don't affect combat, choose whatever quality of life you prefer").
local HX_WARFARE_MAG     = "Eldritch Insight 20, Quick Recovery 20, Preparation 20, Precision 20, Piercing 20, Flawless Ritual 40, War Mage 30, Battle Mastery 40, Mighty 30, Hardy 20, Elemental Aegis 20, Tireless Discipline 20, Blessed 20"
local HX_WARFARE_STAM    = "Tireless Discipline 20, Quick Recovery 20, Preparation 20, Precision 20, Piercing 20, Flawless Ritual 40, War Mage 30, Battle Mastery 40, Mighty 30, Hardy 20, Elemental Aegis 20, Eldritch Insight 20, Blessed 20"
local HX_WARFARE_SUPPORT = "Eldritch Insight 20, Quick Recovery 20, Preparation 20, Blessed 20, Tireless Discipline 20, Precision 20, Hardy 20, Elemental Aegis 20, Piercing 20, Flawless Ritual 40, Battle Mastery 40, War Mage 30, Mighty 30"
local HX_FITNESS         = "Sprinter 20, Hasty 16, Hero's Vigor 20, Tireless Guardian 20, Tumbling 30, Fortification 30, Defiance 20, Savage Defense 30, Bashing Brutality 20, Nimble Protector 6, Piercing Gaze 10, Tempered Soul 50, Mystic Tenacity 50"
local PVE_CRAFT          = "Breakfall 50, Wanderer 75, Steadfast Enchantment 50, Fortune's Favor 40, Gilded Fingers 40, Inspiration Boost 45"
local PVP_CRAFT          = "Breakfall 50, Wanderer 75, Steadfast Enchantment 50, Fortune's Favor 50, Gilded Fingers 50, Out of Sight 30, Fleet Phantom 40, Soul Reservoir 33"

local DPS_SOURCES = { "Hyperioxes (U50)", "Skinny Cheeks (U51)" }
local HX_SOURCES  = { "Hyperioxes (U50)" }
local PVP_SOURCES = { "eso-pvp-builds.com by MalcolM (U50)", "Hyperioxes (U50)" }
local CRAFT_TIP   = "Craft: own picks."
local DPS_TIP     = "Full trial group? Exploiter for Fighting Finesse. Many enemies? Biting Aura for Deadly Aim. " .. CRAFT_TIP

OCCP.Data = {

    ---------------------------------------------------------------- PvE (DPS)
    PVE = {
        MAG = {
            sources  = DPS_SOURCES,
            verified = true,
            warfare  = { "Master-at-Arms", "Deadly Aim", "Wrathful Strikes", "Fighting Finesse" },
            fitness  = { "Boundless Vitality", "Fortified", "Celerity", "Rejuvenation" },
            craft    = { "Steed's Blessing", "Gifted Rider", "Liquid Efficiency", "Treasure Hunter" },
            passives = {
                warfare = HX_WARFARE_MAG,
                fitness = HX_FITNESS,
                craft   = PVE_CRAFT,
            },
            note = DPS_TIP,
        },
        STAM = {
            sources  = DPS_SOURCES,
            verified = true,
            warfare  = { "Master-at-Arms", "Deadly Aim", "Wrathful Strikes", "Fighting Finesse" },
            fitness  = { "Boundless Vitality", "Fortified", "Celerity", "Rejuvenation" },
            craft    = { "Steed's Blessing", "Gifted Rider", "Liquid Efficiency", "Treasure Hunter" },
            passives = {
                warfare = HX_WARFARE_STAM,
                fitness = HX_FITNESS,
                craft   = PVE_CRAFT,
            },
            note = DPS_TIP,
        },
        HEAL = {
            sources  = HX_SOURCES,
            verified = true,
            warfare  = { "Soothing Tide", "Swift Renewal", "Enlivening Overflow", "From the Brink" },
            fitness  = { "Fortified", "Rejuvenation", "Celerity", "Boundless Vitality" },
            craft    = { "Steed's Blessing", "Gifted Rider", "Liquid Efficiency", "Treasure Hunter" },
            passives = {
                warfare = HX_WARFARE_SUPPORT,
                fitness = HX_FITNESS,
                craft   = PVE_CRAFT,
            },
            note = "Using shields? Bastion + Shield Master for Fortified + Celerity. " .. CRAFT_TIP,
        },
        TANK = {
            sources  = HX_SOURCES,
            verified = true,
            warfare  = { "Ironclad", "Duelist's Rebuff", "Bulwark", "Focused Mending" },
            fitness  = { "Boundless Vitality", "Fortified", "Rejuvenation", "Bracing Anchor" },
            craft    = { "Steed's Blessing", "Gifted Rider", "Liquid Efficiency", "Treasure Hunter" },
            passives = {
                warfare = HX_WARFARE_SUPPORT,
                fitness = HX_FITNESS,
                craft   = PVE_CRAFT,
            },
            note = "At the armor cap? Enduring Resolve for Bulwark, Shield Master for Fortified. " .. CRAFT_TIP,
        },
    },

    ---------------------------------------------------------------- PvP (Cyrodiil / BG)
    -- Every class has its own slots (see ClassOverrides); these are the shared
    -- craft stars and passive spreads.
    -- Slotted stars: eso-pvp-builds.com (MalcolM). That site lists no passive
    -- points, so passives use Hyperioxes' spreads.
    PVP = {
        MAG = {
            sources  = PVP_SOURCES,
            verified = true,
            warfare  = { "Deadly Aim", "Master-at-Arms", "Fighting Finesse", "Duelist's Rebuff" },
            fitness  = { "Sustained by Suffering", "Pain's Refuge", "Survival Instincts", "Boundless Vitality" },
            craft    = { "Steed's Blessing", "Gifted Rider", "War Mount", "Treasure Hunter" },
            passives = {
                warfare = HX_WARFARE_MAG,
                fitness = HX_FITNESS,
                craft   = PVP_CRAFT,
            },
            note = "Stars by MalcolM, passive points by Hyperioxes. " .. CRAFT_TIP,
        },
        STAM = {
            sources  = PVP_SOURCES,
            verified = true,
            warfare  = { "Master-at-Arms", "Fighting Finesse", "Deadly Aim", "Duelist's Rebuff" },
            fitness  = { "Sustained by Suffering", "Pain's Refuge", "Survival Instincts", "Boundless Vitality" },
            craft    = { "Steed's Blessing", "Gifted Rider", "War Mount", "Treasure Hunter" },
            passives = {
                warfare = HX_WARFARE_STAM,
                fitness = HX_FITNESS,
                craft   = PVP_CRAFT,
            },
            note = "Stars by MalcolM, passive points by Hyperioxes. " .. CRAFT_TIP,
        },
    },
}

-- PvP builds per class (eso-pvp-builds.com, U50). Most classes use the same
-- hybrid build for Magicka and Stamina.
local PVP_DK = { -- Hybrid Melee
    warfare = { "Master-at-Arms", "Fighting Finesse", "Ironclad", "Duelist's Rebuff" },
    fitness = { "Boundless Vitality", "Sustained by Suffering", "Pain's Refuge", "Survival Instincts" },
}
local PVP_SORC = { -- Magicka Ranged
    warfare = { "Deadly Aim", "Master-at-Arms", "Weapons Expert", "Duelist's Rebuff" },
    fitness = { "Bastion", "Sustained by Suffering", "Pain's Refuge", "Survival Instincts" },
}
local PVP_NB = { -- Hybrid Brawler
    warfare = { "Resilience", "Fighting Finesse", "Master-at-Arms", "Deadly Aim" },
    fitness = { "Sustained by Suffering", "Pain's Refuge", "Survival Instincts", "Bastion" },
}
local PVP_WARDEN = { -- Magicka Melee
    warfare = { "Focused Mending", "Fighting Finesse", "Ironclad", "Resilience" },
    fitness = { "Sustained by Suffering", "Pain's Refuge", "Survival Instincts", "Rejuvenation" },
}
local PVP_NECRO = { -- Hybrid Melee
    warfare = { "Focused Mending", "Master-at-Arms", "Wrathful Strikes", "Fighting Finesse" },
    fitness = { "Sustained by Suffering", "Pain's Refuge", "Survival Instincts", "Relentlessness" },
}
local PVP_ARC = { -- Hybrid Melee
    warfare = { "Focused Mending", "Fighting Finesse", "Duelist's Rebuff", "Master-at-Arms" },
    fitness = { "Sustained by Suffering", "Pain's Refuge", "Survival Instincts", "Rejuvenation" },
}

-- Arcanist DPS: both Hyperioxes and Skinny Cheeks slot Biting Aura over Deadly Aim.
local PVE_ARC = {
    sources = DPS_SOURCES,
    warfare = { "Master-at-Arms", "Biting Aura", "Wrathful Strikes", "Fighting Finesse" },
    note    = "Full trial group? Exploiter for Fighting Finesse. " .. CRAFT_TIP,
}

-- Tanks whose class shields benefit from Bastion (Hyperioxes DK / Arcanist tank).
local TANK_SHIELDS = {
    fitness = { "Boundless Vitality", "Fortified", "Bastion", "Bracing Anchor" },
}

-- Per-class overrides. Only fill in what differs from the tables above.
-- Class IDs: 1 Dragonknight, 2 Sorcerer, 3 Nightblade, 4 Warden, 5 Necromancer, 6 Templar, 117 Arcanist
-- Anything not listed here falls back to the standard setup for that mode/role.
OCCP.ClassOverrides = {
    [1] = { -- Dragonknight
        PVE = { TANK = TANK_SHIELDS },
        PVP = { MAG = PVP_DK, STAM = PVP_DK },
    },
    [2] = { -- Sorcerer
        PVP = { MAG = PVP_SORC, STAM = PVP_SORC },
    },
    [3] = { -- Nightblade
        PVP = { MAG = PVP_NB, STAM = PVP_NB },
    },
    [4] = { -- Warden
        PVP = { MAG = PVP_WARDEN, STAM = PVP_WARDEN },
    },
    [5] = { -- Necromancer
        PVP = { MAG = PVP_NECRO, STAM = PVP_NECRO },
    },
    [6] = { -- Templar
        PVP = {
            MAG = { -- Ranged
                warfare = { "Focused Mending", "Fighting Finesse", "Master-at-Arms", "Deadly Aim" },
                fitness = { "Sustained by Suffering", "Pain's Refuge", "Survival Instincts", "Celerity" },
            },
            STAM = { -- Cyrodiil & Battlegrounds
                warfare = { "Ironclad", "Focused Mending", "Master-at-Arms", "Resilience" },
                fitness = { "Sustained by Suffering", "Pain's Refuge", "Survival Instincts", "Celerity" },
            },
        },
    },
    [117] = { -- Arcanist
        PVE = { MAG = PVE_ARC, STAM = PVE_ARC, TANK = TANK_SHIELDS },
        PVP = { MAG = PVP_ARC, STAM = PVP_ARC },
    },
}
