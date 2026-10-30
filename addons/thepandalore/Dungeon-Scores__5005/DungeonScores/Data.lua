DungeonScores = DungeonScores or {}

local DS = DungeonScores
DS.Data = DS.Data or {}
local Data = DS.Data

-- Runtime eligibility gates. Solo and undermanned runs in configured scoring
-- zones remain valid; unknown instances, oversized groups, and explicitly
-- excluded arena/archive zones are rejected.
Data.ELIGIBILITY = {
    maxGroupSize = 4,
    excludedZoneIds = {
        [635] = "Dragonstar Arena",
        [677] = "Maelstrom Arena",
        [1082] = "Blackrose Prison",
        [1227] = "Vateshran Hollows",
        [1436] = "Infinite Archive",
    },
}

-- Scoring constants. XP-bearing deaths score fifty points; a true no-XP
-- death scores five points. If DIED is later upgraded by DIED_XP for the same
-- target, the runtime adjusts the existing record to fifty total points.
Data.SCORING = {
    veteranBase = 10000,
    xpKill = 50,
    noXpKill = 5,
    hardModeBoss = 2000,
    speedRun = 2000,
    noDeath = 2000,
    trifecta = 16000,

    vitalityStartingLives = 16,
    vitalityPerRemainingLife = 1000,
    vitalityDeathPastZero = 1500,

    tempoPointsPerSecond = 15,

    -- Applied once to an unfinished, definitively closed session. This is a
    -- provisional beta-local scoring constant; abandoned runs cannot enter the
    -- existing completed-world-record publication route.
    abandonmentPenalty = 10000, -- provisional beta tuning; flat, unscaled
    abandonedHardModePenalty = 2000, -- once per verified HM encounter, unscaled
    companionPenalty = 5000, -- once per run if any group companion is observed, unscaled
    pitstopPenalty = 5000, -- RTB-only, once per run after a 15-second teammate departure

    -- Completed runs use the largest party ever observed to set their record
    -- division and baseline. The final fight caps a challenge bonus that may
    -- recover 10% of the gap to the whole-run duration-weighted score. Four
    -- players are neutral. Abandoned RTB runs have no terminal encounter and
    -- retain the duration-weighted challenge calculation.
    partyChallengeByGroupSize = {
        [1] = 10000,
        [2] = 5000,
        [3] = 2000,
        [4] = 0,
    },
}

-- Race to the Bottom requires real boss-death credit before an abandoned
-- attempt may be submitted. The per-zone override exists for later audited
-- thresholds; do not infer minimum progress from mere boss tags or elapsed time.
Data.ABANDONMENT_PROGRESS = {
    defaultBossKills = 1,
    byZone = {},
}

-- Preserve the established DLC difficulty curve while expanding its scoring
-- weight. Configured endpoints remain the audited 0.3.48 curve; runtime
-- coefficients double every premium above the neutral 1.00 baseline. Because
-- the same affine transform is applied to both endpoints, all ordering,
-- relative spacing, and multi-HM interpolation are preserved exactly.
Data.DIFFICULTY_PREMIUM_SCALE = 2

-- These dungeons deliberately replace unsupported or unsuitable HM telemetry
-- with an alternate whole-run scoring design. They are not unresolved evidence
-- gaps and must never become trifecta-capable merely because a health value is
-- later observed. Alternate-path zones carry no conditional HM observers.
Data.ALTERNATE_HM_SCORING_ZONES = {
    [934] = true, -- Fungal Grotto II: replacement speed tiers.
    [935] = true, -- The Banished Cells II: replacement speed tiers.
    [931] = true, -- Elden Hollow II: whole-run speed/tempo challenge.
    [936] = true, -- Spindleclutch II: whole-run speed/tempo challenge.
    [930] = true, -- Darkshade Caverns II: replacement speed tiers.
    [933] = true, -- Wayrest Sewers II: replacement speed tiers.
    [681] = true, -- City of Ash II: whole-run speed/tempo challenge.
    [932] = true, -- Crypt of Hearts II: replacement speed tiers.
    [678] = true, -- Imperial City Prison: full Veteran coefficient, no HM share.
    [688] = true, -- White-Gold Tower: replacement speed tiers.
}

-- Verified numeric terminal-cohort evidence for automatic manual/premade
-- completion snapshots. These are regular-Veteran and HM max-health values,
-- not NPC template IDs. A cohort is recognized only after all required boss
-- unit tags have appeared together in a single snapshot and then each has
-- delivered a direct death-state transition for its run-local identity.
-- The whitelist is deliberately narrow; adding a dungeon requires comparable
-- evidence for both difficulty modes. Localized names are never consulted.
Data.NUMERIC_TERMINAL_COHORTS = {
    [22] = { -- Volenfell Guardian Council: three simultaneously present guardians.
        required = 3,
        maxHealth = {
            [1258098] = true, -- live-verified base Veteran
            [1446813] = true, -- live-verified Hard Mode
        },
    },
}

-- Static positive HM-health signatures are zone- and encounter-scoped. Localized
-- unit names are deliberately absent: a verified max-health value resolves to a
-- stable internal encounter key only within its instance zone.
-- Structure:
--   [zoneId] = {
--       [hardModeMaxHealth] = "stable-encounter-key",
--   }
--
-- Add signatures only when corroborated from live runtime evidence or an
-- authoritative reference value. Static signatures are positive-only: observing
-- the verified HM max health proves HM activation; encounter completion still
-- controls when HM score is awarded.
Data.HM_HEALTH_SIGNATURES = {
    -- 0.3.31 consolidated HM-health audit, 2026-10-09.
    -- Rows left in HOLD / NO HEALTH SIGNATURE status in Batches 1-8 are
    -- intentionally absent. An observed health transition without a trusted
    -- exact signature is not competitive HM evidence.

    -- Base-game / legacy dungeons.
    [283] = { -- Fungal Grotto I; live corrected in the 0.3.41 differential pass.
        [4133749] = "kragh",
    },
    [380] = { -- The Banished Cells I; current live signature supersedes stale 4,992,448.
        [4133749] = "high-kinlord-rilis",
    },
    [126] = { -- Elden Hollow I; live corrected in the 0.3.41 differential pass.
        [5901794] = "canonreeve-oraneth",
    },
    [144] = { -- Spindleclutch I; live verified in the 0.3.41 differential pass.
        [4133749] = "the-whisperer",
    },
    [63] = { -- Darkshade Caverns I; current live signature supersedes stale 6,240,560.
        [5167187] = "sentinel-rkugamz",
    },
    [146] = { -- Wayrest Sewers I; live verified.
        [5901794] = "allene-pellingare",
    },
    [176] = { -- City of Ash I; difficulty-11 max-health modifier corroborated.
        [4868360] = "razor-master-erthas",
    },
    [130] = { -- Crypt of Hearts I; both Ilambris twins carry the same HM maximum.
        [4868360] = "ilambris-twins",
    },
    [148] = { -- Arx Corinium; live learned signature.
        [4868360] = "sellistrix",
    },
    [449] = { -- Direfrost Keep; exact audit candidate reconciled for 0.3.31.
        [4868360] = "drodda",
    },
    [131] = { -- Tempest Island; exact audit candidate reconciled for 0.3.31.
        [4868360] = "stormreeve-neidir",
    },
    [64] = { -- Blessed Crucible; live pre-damage transition verified after Batch 3.
        [4868360] = "lava-queen",
    },
    [31] = { -- Selene's Web; difficulty-11 max-health modifier corroborated.
        [4868360] = "selene",
    },
    [22] = { -- Volenfell; all three Guardian Council members share this HM maximum.
        [1446813] = "guardian-council",
    },
    [38] = { -- Blackheart Haven; live transition plus first-sight HM runs corroborated.
        [2078702] = "captain-blackheart",
    },
    [11] = { -- Vaults of Madness; live pre-damage transition verified.
        [4868360] = "mad-architect",
    },

    -- Earlier DLC dungeons.
    [843] = { -- Ruins of Mazzatun.
        [3968771] = "tree-minder-na-kesh",
    },
    [848] = { -- Cradle of Shadows.
        [5291695] = "velidreth",
    },
    [973] = { -- Bloodroot Forge.
        [8852692] = "earthgore-amalgam",
    },
    [974] = { -- Falkreath Hold.
        [4868360] = "domihaus",
    },
    [1009] = { -- Fang Lair; live verified.
        [5427792] = "thurvokun",
    },
    [1010] = { -- Scalecaller Peak; live verified.
        [5901794] = "zaan",
    },
    [1052] = { -- Moon Hunter Keep; live verified.
        [5503363] = "vykosa",
    },
    [1055] = { -- March of Sacrifices; difficulty-11 max-health modifier corroborated.
        [6491974] = "balorgh",
    },
    [1080] = { -- Frostvault; live HM pull and base-Veteran reset observed in one encounter log.
        [5334028] = "stonekeeper",
    },
    [1081] = { -- Depths of Malatar; Symphony's HM maximum precedes its phase handoff.
        [7082154] = "symphony-of-blades",
    },

    -- Scalebreaker / Harrowstorm. These exact values were paired against
    -- base-Veteran observations from the same live capture where available.
    [1122] = { -- Moongrave Fane; difficulty 11 Grundwulf pull.
        [13758406] = "grundwulf",
    },
    [1152] = { -- Icereach; authoritative Mother Ciannait HM maximum.
        [5413504] = "mother-ciannait",
    },
    [1153] = { -- Unhallowed Grave; Kjalnar's HM maximum after the pre-pull increase.
        [16165786] = "kjalnar-tombskald",
    },

    -- Stonethorn.
    [1197] = { -- Stone Garden; direct Challenged maxima plus referenced Arkasis HM maximum.
        [9473630] = "exarch-kraglen",
        [12315720] = "stone-behemoth",
        [12008870] = "arkasis",
    },
    [1201] = { -- Castle Thorn; Lady Thorn's Challenged maximum.
        [18547032] = "lady-thorn",
    },
    [1228] = { -- Black Drake Villa; only the final encounter maximum is verified.
        [8607464] = "pyroturge-encratis",
    },
    [1229] = { -- The Cauldron; difficulty-11 max-health modifier corroborated.
        [10263990] = "baron-zaudrus",
    },
    [1267] = { -- Red Petal Bastion; Rogerain remains HOLD.
        [12667598] = "artifact-bearers",
        [15344666] = "prior-thierric",
    },
    [1268] = { -- The Dread Cellar; supplied difficulty-11 target-resource maxima.
        [7714243] = "scorion-broodlord",
        [8392278] = "cyronin-artellian",
        [14010348] = "magma-incarnate",
    },

    -- Ascending Tide. Maligalig has no health differential. The universal
    -- cumulative multi-HM rule lets later verified Sarydil or Varallion evidence
    -- prove required predecessors without inventing a Maligalig signature.
    [1301] = { -- Coral Aerie.
        [9570536] = "sarydil",
        [13195414] = "varallion", -- Coral Aerie; live observed.
    },
    [1302] = { -- Shipwright's Regret; all three Challenged maxima corroborated.
        [8228526] = "foreman-bradiggan",
        [11368356] = "nazaray",
        [13371352] = "captain-numirril",
    },

    -- Lost Depths / Scions of Ithelia.
    [1360] = { -- Earthen Root Enclave; exact maxima from successful cumulative-HM clears.
        [8120255] = "corruption-of-stone",
        [9022496] = "corruption-of-stone",
        [6455598] = "corruption-of-root",
        [12180382] = "archdruid-devyric",
    },
    [1361] = { -- Graven Deep; repeated target-resource maximum matches the direct HM reference.
        [12278298] = "zelvraak",
    },
    [1389] = { -- Bal Sunnar; supplied successful difficulty-11 target-resource maxima.
        [8192246] = "kovan-giryon",
        [12911198] = "roksa",
        [10150318] = "lladi-telvanni",
    },
    [1390] = { -- Scrivener's Hall; supplied difficulty-11 target-resource maxima.
        [9202956] = "riftmaster-naqri",
        [13154812] = "ozezan",
        -- Lamikhai's HM increase is the positive final-encounter signal; the
        -- scored encounter retains Valinna's stable semantic key.
        [14010348] = "valinna",
    },
    [1470] = { -- Oathsworn Pit.
        [5278166] = "packmaster-rethelros", -- Live observed on both Packmaster Rethelros and Malthil.
        [10827006] = "anthelmir",
        [17897834] = "aradros",
    },
    [1471] = { -- Bedlam Veil.
        [8120255] = "shattered-champion",
        [5075159] = "darkshard",
        [16088804] = "the-blind",
    },

    -- Fallen Banners / Feast of Shadows. Current-patch exact public values are
    -- retained as positive signatures; Naj-Caldeesh is additionally live verified.
    [1496] = { -- Exiled Redoubt.
        [8932282] = "executioner-jerensi",
        [12601566] = "vandorallen",
        [15395986] = "squall-of-retribution",
    },
    [1497] = { -- Lep Seclusa.
        [8932282] = "garvin",
        [18189370] = "noriwen",
        [20527982] = "orpheon",
    },
    [1551] = { -- Naj-Caldeesh; all four live-observed boss members map to three scored HMs.
        [10657834] = "poxito",
        [12180382] = "voskrona-stonehulk-poxito",
        [14210446] = "talen-lah",
    },
    [1552] = { -- Black Gem Foundry.
        [13533758] = "saldezaar",
        [13389424] = "black-gem-monstrosity",
        [25659976] = "vykand",
    },
}

-- A small number of encounters expose one shared API maximum in both modes but
-- settle to different active health pools before combat. These signatures are
-- deliberately separate from HM_HEALTH_SIGNATURES: the shared maximum is not HM
-- evidence. Runtime latches the stable encounter key only while the observed
-- current health is above the base pool and at or below the verified HM pool.
-- Once latched to a run-local identity, ordinary damage never removes it.
Data.HM_ACTIVE_HEALTH_POOL_SIGNATURES = {
    [1123] = { -- Lair of Maarselok; controlled difficulty 10 / 11 / 10 final pulls.
        encounterKey = "maarselok",
        reportedMaxHealth = 22580776,
        basePoolHealth = 11290388,
        hardModePoolHealth = 15806543,
    },
}

-- Official Veteran dungeon Speed Run cutoffs. Zone IDs are instance zone IDs.
-- The runtime intentionally uses one normalized timer anchor (first hostile
-- combat engagement), even where older base-game achievements use a nearby
-- hallway/door/area trigger. Thresholds themselves match the achievement text.
--
-- Every scored dungeon has an explicit terminal encounter for manual/premade
-- completion fallback. Activity Finder completion remains generic and authoritative.
-- Terminal encounter fallback is still combat-death driven; merely observing or
-- despawning a boss never marks the dungeon complete.
local SECOND = 1000
local MINUTE = 60 * SECOND

-- Dungeon-browser grouping for the Basegame/DLC high-score tabs. Keep the
-- original launch/base-game dungeon set explicit; every scored dungeon not in
-- this set is treated as DLC. This makes future DLC additions automatically
-- land in the DLC tab without changing UI code.
Data.BASE_GAME_ZONE_IDS = {
    [283] = true, [380] = true, [126] = true, [144] = true, [63] = true, [146] = true,
    [176] = true, [130] = true, [148] = true, [131] = true, [31] = true, [64] = true,
    [22] = true, [38] = true, [449] = true, [11] = true, [934] = true, [935] = true,
    [931] = true, [936] = true, [930] = true, [933] = true, [681] = true, [932] = true,
}

-- Competitive run-integrity floor. This is intentionally NOT a count of every
-- optional/secret boss that can award score. It is the minimum number of distinct
-- boss encounters a client should credibly have observed by ESO's official dungeon
-- completion milestone for a whole-run record to be trusted. Legitimate skip routes
-- are reflected here (for example, Fungal Grotto I does not require all five
-- score-bearing bosses). Values are locale-independent and cover every scored zone.
--
-- If observed boss encounters at completion are below this floor, the record remains
-- scoreable but is marked PARTIAL and loses whole-run competitive metrics (Speed Run,
-- WR comparison, No Death/trifecta bonus, and PB preservation). Post-completion boss
-- kills may raise the score but never repair the frozen integrity status.
Data.EXPECTED_BOSS_ENCOUNTERS_AT_COMPLETION = {
    -- Base game
    [283] = 3, -- Fungal Grotto I: common speed route legitimately skips two middle bosses
    [380] = 2, -- The Banished Cells I
    [126] = 3, -- Elden Hollow I
    [144] = 2, -- Spindleclutch I
    [63]  = 3, -- Darkshade Caverns I
    [146] = 3, -- Wayrest Sewers I
    [176] = 3, -- City of Ash I
    [130] = 3, -- Crypt of Hearts I
    [148] = 3, -- Arx Corinium
    [131] = 3, -- Tempest Island
    [31]  = 3, -- Selene's Web
    [64]  = 3, -- Blessed Crucible
    [22]  = 3, -- Volenfell
    [38]  = 3, -- Blackheart Haven
    [449] = 3, -- Direfrost Keep
    [11]  = 4, -- Vaults of Madness
    [934] = 3, -- Fungal Grotto II
    [935] = 3, -- The Banished Cells II
    [931] = 3, -- Elden Hollow II
    [936] = 3, -- Spindleclutch II
    [930] = 3, -- Darkshade Caverns II
    [933] = 3, -- Wayrest Sewers II
    [681] = 3, -- City of Ash II
    [932] = 3, -- Crypt of Hearts II

    -- DLC dungeons
    [678] = 6, -- Imperial City Prison
    [688] = 4, -- White-Gold Tower
    [843] = 4, -- Ruins of Mazzatun
    [848] = 5, -- Cradle of Shadows
    [973] = 6, -- Bloodroot Forge
    [974] = 5, -- Falkreath Hold
    [1009] = 5, -- Fang Lair
    [1010] = 5, -- Scalecaller Peak
    [1052] = 5, -- Moon Hunter Keep
    [1055] = 5, -- March of Sacrifices
    [1080] = 5, -- Frostvault
    [1081] = 5, -- Depths of Malatar
    [1122] = 5, -- Moongrave Fane
    -- Maarselok is fought in multiple staged appearances under the same runtime
    -- identity. Three distinct encounter signatures are a conservative, abuse-safe
    -- whole-run floor without requiring fragile stage counting.
    [1123] = 3, -- Lair of Maarselok
    [1152] = 5, -- Icereach
    [1153] = 5, -- Unhallowed Grave
    [1197] = 3, -- Stone Garden
    [1201] = 5, -- Castle Thorn
    [1228] = 3, -- Black Drake Villa (secret bosses are score-bearing but optional pre-completion)
    [1229] = 4, -- The Cauldron
    [1267] = 3, -- Red Petal Bastion
    [1268] = 3, -- The Dread Cellar
    [1301] = 3, -- Coral Aerie
    [1302] = 3, -- Shipwright's Regret
    [1360] = 3, -- Earthen Root Enclave
    [1361] = 3, -- Graven Deep
    [1389] = 3, -- Bal Sunnar
    [1390] = 3, -- Scrivener's Hall
    [1470] = 3, -- Oathsworn Pit
    [1471] = 3, -- Bedlam Veil
    [1496] = 3, -- Exiled Redoubt
    [1497] = 3, -- Lep Seclusa
    [1551] = 3, -- Naj-Caldeesh
    [1552] = 3, -- Black Gem Foundry
}

Data.ZONES = {
    -- Coefficients are stored as integer percentages. Veteran and full-HM
    -- difficulty are independent endpoints; expectedHardModes controls the
    -- interpolation between them. Pace and release order do not derive either
    -- endpoint. Dungeons without explicit endpoints remain at 1.00x.

    -- Base game: 1.00 coefficient baseline. HM points still score independently.
    [283] = {
        speedThresholdMs = 15 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Kra'gh the Dreugh King"] = true }, required = 1 },
    }, -- Fungal Grotto I
    [380] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["High Kinlord Rilis"] = true }, required = 1 },
    }, -- The Banished Cells I
    [126] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Canonreeve Oraneth"] = true }, required = 1 },
    }, -- Elden Hollow I
    [144] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["The Whisperer"] = true }, required = 1 },
    }, -- Spindleclutch I
    [63] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Sentinel of Rkugamz"] = true }, required = 1 },
    }, -- Darkshade Caverns I
    [146] = {
        speedThresholdMs = 15 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Allene Pellingare"] = true }, required = 1 },
    }, -- Wayrest Sewers I
    [176] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Razor Master Erthas"] = true }, required = 1 },
    }, -- City of Ash I
    [130] = {
        speedThresholdMs = 20 * MINUTE, -- Crypt of Hearts I
        expectedHardModes = 1,
        finalEncounter = {
            mode = "composite",
            label = "Ilambris Twins",
            members = {
                ["Ilambris-Zaven"] = true,
                ["Ilambris-Athor"] = true,
            },
            required = 2,
            hmCreditMode = "single",
            hmCreditKey = "ilambris-twins",
        },
    },
    [148] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Sellistrix the Lamia Queen"] = true }, required = 1 },
    }, -- Arx Corinium
    [131] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Stormreeve Neidir"] = true }, required = 1 },
    }, -- Tempest Island
    [31] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Selene"] = true }, required = 1 },
    }, -- Selene's Web
    [64]  = { -- Blessed Crucible
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        -- The Lava Queen is the verified terminal encounter. Registering it here
        -- lets Activity Finder/manual completion reconcile HM from retained boss
        -- state even when ESO omits the terminal combat-death event.
        finalEncounter = {
            mode = "single",
            members = { ["The Lava Queen"] = true },
            required = 1,
        },
    },
    [22]  = {
        speedThresholdMs = 20 * MINUTE, -- Volenfell
        expectedHardModes = 1,
        -- The Guardian Council is one HM encounter composed of three bosses.
        -- Completion requires all three members in the same encounter attempt;
        -- their shared Hard Mode is credited exactly once, on encounter completion.
        finalEncounter = {
            mode = "composite",
            label = "Guardian Council",
            members = {
                ["The Guardian's Strength"] = true,
                ["The Guardian's Spark"] = true,
                ["The Guardian's Soul"] = true,
            },
            required = 3,
            hmCreditMode = "single",
            hmCreditKey = "guardian-council",
        },
    },
    [38] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = {
            mode = "single",
            members = { ["Captain Blackheart"] = true },
            required = 1,
            hmEncounterKey = "captain-blackheart",
        },
    }, -- Blackheart Haven
    [449] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Drodda of Icereach"] = true }, required = 1 },
    }, -- Direfrost Keep
    [11] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["The Mad Architect"] = true }, required = 1 },
    }, -- Vaults of Madness
    [934] = {
        speedThresholdMs = 20 * MINUTE, expectedHardModes = 0, -- Fungal Grotto II
        -- Fearless Assaulter is not scored from HM telemetry. The protection-dome
        -- condition is an absence test that has proven unreliable enough to make
        -- competitive scoring depend on it. Use provisional speed tiers instead.
        additionalSpeedBonusTiers = {
            { maxMs = 330 * SECOND, points = 10000 }, -- 5:30
            { maxMs = 390 * SECOND, points = 8000 }, -- 6:30
            { maxMs = 450 * SECOND, points = 2000 }, -- 7:30
        },
        finalEncounter = { mode = "single", members = { ["Vila Theran"] = true }, required = 1 },
    },
    [935] = {
        speedThresholdMs = 20 * MINUTE, expectedHardModes = 1, -- The Banished Cells II
        -- Provisional legacy speed tiers. Every qualifying tier is added; these
        -- values are deliberately zone data so they can be retuned without
        -- changing scoring logic.
        additionalSpeedBonusTiers = {
            { maxMs = 5 * MINUTE, points = 10000 },
            { maxMs = 6 * MINUTE, points = 8000 },
            { maxMs = 7 * MINUTE, points = 2000 },
        },
        finalEncounter = { mode = "single", members = { ["High Kinlord Rilis"] = true }, required = 1 },
    },
    [931] = {
        speedThresholdMs = 20 * MINUTE,
        expectedHardModes = 1,
        -- Bogdan's Veteran and HM maximum health are identical. Do not infer HM
        -- from health or reserve competitive scoring for an unobservable state;
        -- the alternate policy uses the whole-run speed/tempo result instead.
        finalEncounter = { mode = "single", members = { ["Bogdan the Nightflame"] = true }, required = 1 },
    }, -- Elden Hollow II
    [936] = {
        speedThresholdMs = 20 * MINUTE, -- Spindleclutch II
        expectedHardModes = 1,
        -- Conditional HM evidence is not used by the alternate scoring path.
        finalEncounter = {
            mode = "single",
            members = { ["Vorenor Winterbourne"] = true },
            required = 1,
        },
    },
    [930] = {
        speedThresholdMs = 20 * MINUTE, expectedHardModes = 0, -- Darkshade Caverns II
        -- Deadly Engineer's individual lever use is not dependable groupwide HM
        -- telemetry. Competitive scoring therefore uses provisional speed tiers
        -- instead of awarding an assumed HM.
        additionalSpeedBonusTiers = {
            { maxMs = 7 * MINUTE, points = 10000 },
            { maxMs = 8 * MINUTE, points = 8000 },
            { maxMs = 9 * MINUTE, points = 2000 },
        },
        finalEncounter = { mode = "single", members = { ["Engine Guardian"] = true }, required = 1 },
    },
    [933] = {
        speedThresholdMs = 20 * MINUTE, -- Wayrest Sewers II
        expectedHardModes = 0,
        healthBasedHM = false,
        -- Ghoul Slayer HM is replaced by cumulative whole-run speed tiers.
        -- Route-boss numeric signatures remain for encounter accounting.
        additionalSpeedBonusTiers = {
            { maxMs = 5 * MINUTE, points = 10000 },
            { maxMs = 6 * MINUTE, points = 8000 },
            { maxMs = 7 * MINUTE, points = 2000 },
        },
        -- ESO does not consistently expose the five non-final route bosses through
        -- bossN. Recognize their encounters from zone-scoped numeric emissions
        -- instead. The first four signatures are unique in
        -- all four reviewed full clears. The Forgotten One shares its basic attacks
        -- with ordinary Ghost actors, so that encounter is admitted only after
        -- Garron's independently verified signature. A raw live client log adds a
        -- unique Haunting Spectre damage signal. Because ESO omits usable source
        -- identities for these filtered events, the fallback is an encounter-wide
        -- damage threshold validated against both live clears and all four offline
        -- reports, rather than an impossible same-emitter join.
        routeAbilityEncounters = {
            {
                key = "wayrest-ii-malubeth",
                -- Ethereal Bolt reaches tanks reliably; Scourging Spark covers
                -- fast kills where the local player never receives the bolt.
                abilityIds = { [36412] = true, [36625] = true },
                requiredDistinctAbilityIds = 1,
            },
            {
                key = "wayrest-ii-skull-reaper",
                abilityIds = { [36966] = true },
                requiredDistinctAbilityIds = 1,
            },
            {
                key = "wayrest-ii-uulgarg",
                abilityIds = { [36869] = true },
                requiredDistinctAbilityIds = 1,
            },
            {
                key = "wayrest-ii-garron",
                -- Necrotic Bolt is target-dependent. Necrotic Barrage is visible
                -- in every reviewed player-perspective log and collision-free.
                abilityIds = { [36709] = true, [36904] = true },
                requiredDistinctAbilityIds = 1,
            },
            {
                key = "wayrest-ii-forgotten-one-cohort",
                -- Haunting Spectre damage is a direct signal when it occurs. The
                -- second live clear proved it is not guaranteed, so the fallback
                -- counts both damaging halves of Double Strike plus Chill Touch
                -- across the post-Garron encounter window. Eight Double Strike
                -- hits is above the observed ordinary-Ghost maximum of seven.
                abilityIds = {
                    [36897] = true,
                    [8812] = true,
                    [8813] = true,
                    [18514] = true,
                },
                directAbilityIds = { [36897] = true },
                encounterWideAbilityIds = {
                    [8812] = true,
                    [8813] = true,
                    [18514] = true,
                },
                minimumAbilityCounts = {
                    [8812] = 1,
                    [8813] = 1,
                    [18514] = 1,
                },
                minimumAbilityGroupCounts = {
                    {
                        abilityIds = { [8812] = true, [8813] = true },
                        minimumCount = 8,
                    },
                },
                requiredDistinctAbilityIds = 3,
                requireDamageResult = true,
                requiredPriorEncounterKey = "wayrest-ii-garron",
            },
        },
        finalEncounter = {
            mode = "composite",
            label = "Pellingare Twins",
            members = {
                ["Allene Pellingare"] = true,
                ["Varaine Pellingare"] = true,
            },
            required = 2,
        },
    },
    [681] = {
        speedThresholdMs = 30 * MINUTE,
        expectedHardModes = 1,
        -- Valkyn Skoria's Veteran and HM maximum health are identical. The
        -- alternate policy scores the whole-run speed/tempo result and never
        -- infers HM from health.
        finalEncounter = { mode = "single", members = { ["Valkyn Skoria"] = true }, required = 1 },
    }, -- City of Ash II
    [932] = {
        speedThresholdMs = 30 * MINUTE, expectedHardModes = 1, -- Crypt of Hearts II
        -- Same provisional legacy speed tiers as Banished Cells II.
        additionalSpeedBonusTiers = {
            { maxMs = 5 * MINUTE, points = 10000 },
            { maxMs = 6 * MINUTE, points = 8000 },
            { maxMs = 7 * MINUTE, points = 2000 },
        },
        finalEncounter = { mode = "single", members = { ["Nerien'eth"] = true }, required = 1 },
    },

    -- DLC dungeons, chronological release order.
    -- Legacy DLC: 1.15x Veteran; 1.35x HM where HM is observable.
    [678] = {
        speedThresholdMs = 45 * MINUTE, -- Imperial City Prison
        veteranCoefficient = 115, hardModeCoefficient = 115,
        expectedHardModes = 1,
        finalEncounter = {
            mode = "single",
            members = { ["Lord Warden Dusk"] = true },
            required = 1,
        },
    },
    [688] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 115, hardModeCoefficient = 115,
        expectedHardModes = 0,
        -- Molag Kena HM has no safe language-independent runtime discriminator.
        -- Score base Veteran and HM identically through cumulative whole-run
        -- speed tiers instead of inventing HM state.
        healthBasedHM = false,
        additionalSpeedBonusTiers = {
            { maxMs = 8 * MINUTE, points = 10000 },
            { maxMs = 10 * MINUTE, points = 8000 },
            { maxMs = 12 * MINUTE, points = 2000 },
        },
        finalEncounter = {
            mode = "single",
            members = { ["Molag Kena"] = true },
            required = 1,
        },
    }, -- White-Gold Tower
    [843] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 115, hardModeCoefficient = 135,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Tree-Minder Na-Kesh"] = true }, required = 1 },
    }, -- Ruins of Mazzatun

    -- Shadows of the Hist / Horns of the Reach calibration.
    [848] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 120, hardModeCoefficient = 144,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Velidreth"] = true }, required = 1 },
    }, -- Cradle of Shadows
    [973] = {
        speedThresholdMs = 20 * MINUTE,
        veteranCoefficient = 115, hardModeCoefficient = 135,
        expectedHardModes = 1,
        -- Earthgore's terminal sequence exposes three distinct boss identities
        -- sharing one display name. Completion therefore requires all three
        -- identities, not the first normalized-name death. Boss death-state is
        -- accepted here because ESO can omit a combat DIED event for individual
        -- clones while still exposing authoritative boss-tag death state.
        finalEncounter = {
            mode = "identity-count",
            members = { ["Earthgore Amalgam"] = true },
            required = 3,
            allowBossDeathState = true,
            hmCreditMode = "single",
            hmCreditKey = "earthgore-amalgam",
            label = "Earthgore Amalgam",
        },
    }, -- Bloodroot Forge
    [974] = {
        speedThresholdMs = 20 * MINUTE,
        veteranCoefficient = 115, hardModeCoefficient = 135,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Domihaus"] = true }, required = 1 },
    }, -- Falkreath Hold

    -- Dragon Bones calibration.
    [1009] = {
        speedThresholdMs = 30 * MINUTE, -- Fang Lair
        veteranCoefficient = 142, hardModeCoefficient = 183,
        expectedHardModes = 1,
        finalEncounter = {
            mode = "single",
            members = {
                ["Thurvokun"] = true,
            },
            required = 1,
        },
    },
    [1010] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 137, hardModeCoefficient = 174,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Zaan the Scalecaller"] = true }, required = 1 },
    }, -- Scalecaller Peak

    -- Wolfhunter calibration.
    [1052] = {
        speedThresholdMs = 30 * MINUTE, -- Moon Hunter Keep
        veteranCoefficient = 142, hardModeCoefficient = 183,
        expectedHardModes = 1,
        finalEncounter = {
            mode = "single",
            members = {
                ["Vykosa the Ascendant"] = true,
            },
            required = 1,
        },
    },
    [1055] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 137, hardModeCoefficient = 174,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Balorgh"] = true }, required = 1 },
    }, -- March of Sacrifices

    -- Wrathstone calibration.
    [1080] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 132, hardModeCoefficient = 165,
        expectedHardModes = 1,
        finalEncounter = {
            mode = "single",
            members = { ["Stonekeeper"] = true },
            required = 1,
            hmEncounterKey = "stonekeeper",
        },
    }, -- Frostvault
    [1081] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 126, hardModeCoefficient = 154,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Symphony of Blades"] = true }, required = 1 },
    }, -- Depths of Malatar

    -- Scalebreaker calibration.
    [1122] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 158, hardModeCoefficient = 211,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Grundwulf"] = true }, required = 1 },
    }, -- Moongrave Fane
    [1123] = {
        speedThresholdMs = 35 * MINUTE, -- Lair of Maarselok
        veteranCoefficient = 132, hardModeCoefficient = 165,
        expectedHardModes = 1,
        hardModeEncounters = {
            {
                key = "maarselok",
                required = 1,
                -- Maarselok also appears in staged non-terminal encounters. HM
                -- evidence and the direct death-state must therefore belong to
                -- the same run-local identity before the final HM can score.
                requireHMIdentityDeath = true,
                requireLatestBossDeathIdentity = true,
                requireAuthoritativeCompletion = true,
            },
        },
        finalEncounter = {
            mode = "single",
            members = {
                ["Maarselok"] = true,
            },
            required = 1,
            hmEncounterKey = "maarselok",
            -- Maarselok appears in an earlier non-terminal encounter and flees.
            -- Global terminal-completion policy already requires a real combat
            -- death (or authoritative Activity Finder completion).
        },
    },

    -- Harrowstorm calibration.
    [1152] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 148, hardModeCoefficient = 192,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Mother Ciannait"] = true }, required = 1 },
    }, -- Icereach
    [1153] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 126, hardModeCoefficient = 154,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Kjalnar Tombskald"] = true }, required = 1 },
    }, -- Unhallowed Grave

    -- Stonethorn: Stone Garden has three independent encounter HMs; Castle Thorn has one.
    [1197] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 132, hardModeCoefficient = 165, expectedHardModes = 3, -- Stone Garden
        hardModeEncounters = {
            { key = "exarch-kraglen", members = { ["Exarch Kraglen"] = true }, required = 1 },
            { key = "stone-behemoth", members = { ["Stone Behemoth"] = true }, required = 1 },
            { key = "arkasis", members = { ["Arkasis the Mad Alchemist"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Arkasis the Mad Alchemist"] = true }, required = 1, hmEncounterKey = "arkasis" },
    },
    [1201] = {
        speedThresholdMs = 30 * MINUTE,
        veteranCoefficient = 148, hardModeCoefficient = 192,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Lady Thorn"] = true }, required = 1 },
    }, -- Castle Thorn

    -- Flames of Ambition: Black Drake Villa has three independent encounter HMs; The Cauldron has one.
    [1228] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 126, hardModeCoefficient = 154, expectedHardModes = 3, -- Black Drake Villa
        hardModeEncounters = {
            { key = "kinras-ironeye", members = { ["Kinras Ironeye"] = true }, required = 1 },
            { key = "captain-geminus", members = { ["Captain Geminus"] = true }, required = 1 },
            { key = "pyroturge-encratis", members = { ["Pyroturge Encratis"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Pyroturge Encratis"] = true }, required = 1, hmEncounterKey = "pyroturge-encratis" },
    },
    [1229] = {
        speedThresholdMs = 35 * MINUTE,
        veteranCoefficient = 120, hardModeCoefficient = 144,
        expectedHardModes = 1,
        finalEncounter = { mode = "single", members = { ["Baron Zaudrus"] = true }, required = 1 },
    }, -- The Cauldron

    -- Waking Flame: three independent encounter HMs.
    [1267] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 153, hardModeCoefficient = 202, expectedHardModes = 3, -- Red Petal Bastion
        hardModeEncounters = {
            { key = "rogerain", members = { ["Rogerain the Sly"] = true }, required = 1 },
            {
                key = "artifact-bearers", label = "Artifact Bearers", required = 3,
                members = { ["Eliam Merick"] = true, ["Ihudir"] = true, ["Liramindrel"] = true },
            },
            { key = "prior-thierric", members = { ["Prior Thierric Sarazen"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Prior Thierric Sarazen"] = true }, required = 1, hmEncounterKey = "prior-thierric" },
    },
    [1268] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 148, hardModeCoefficient = 192, expectedHardModes = 3, -- The Dread Cellar
        hardModeEncounters = {
            { key = "scorion-broodlord", members = { ["Scorion Broodlord"] = true }, required = 1 },
            { key = "cyronin-artellian", members = { ["Cyronin Artellian"] = true }, required = 1 },
            { key = "magma-incarnate", members = { ["Magma Incarnate"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Magma Incarnate"] = true }, required = 1, hmEncounterKey = "magma-incarnate" },
    },

    -- Ascending Tide: three independent encounter HMs.
    [1301] = {
        speedThresholdMs = 25 * MINUTE, -- Coral Aerie
        veteranCoefficient = 180, hardModeCoefficient = 250,
        expectedHardModes = 3,
        hardModeEncounters = {
            { key = "maligalig", members = { ["Maligalig"] = true }, required = 1 },
            { key = "sarydil", members = { ["Sarydil"] = true }, required = 1 },
            { key = "varallion", members = { ["Varallion"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Varallion"] = true }, required = 1, hmEncounterKey = "varallion" },
    },
    [1302] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 164, hardModeCoefficient = 222, expectedHardModes = 3, -- Shipwright's Regret
        hardModeEncounters = {
            { key = "foreman-bradiggan", members = { ["Foreman Bradiggan"] = true }, required = 1 },
            { key = "nazaray", members = { ["Nazaray"] = true }, required = 1 },
            { key = "captain-numirril", members = { ["Captain Numirril"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Captain Numirril"] = true }, required = 1, hmEncounterKey = "captain-numirril" },
    },

    -- Lost Depths: three independent encounter HMs.
    [1360] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 164, hardModeCoefficient = 222, expectedHardModes = 3, -- Earthen Root Enclave
        hardModeEncounters = {
            { key = "corruption-of-stone", members = { ["Corruption of Stone"] = true }, required = 1 },
            { key = "corruption-of-root", members = { ["Corruption of Root"] = true }, required = 1 },
            { key = "archdruid-devyric", members = { ["Archdruid Devyric"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Archdruid Devyric"] = true }, required = 1, hmEncounterKey = "archdruid-devyric" },
    },
    [1361] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 169, hardModeCoefficient = 231, expectedHardModes = 3, -- Graven Deep
        hardModeEncounters = {
            { key = "euphotic-gatekeeper", members = { ["Euphotic Gatekeeper"] = true }, required = 1 },
            { key = "varzunon", members = { ["Varzunon"] = true }, required = 1 },
            { key = "zelvraak", members = { ["Zelvraak the Unbreathing"] = true }, required = 1 },
        },
        -- Zelvraak spawns same-name Phantasmal Illusions with distinct unit ids.
        -- Combat-death completion must therefore match the actual boss unit id.
        finalEncounter = {
            mode = "single",
            members = { ["Zelvraak the Unbreathing"] = true },
            required = 1,
            hmEncounterKey = "zelvraak",
            requireBossUnitIdMatch = true,
        },
    },

    -- Scribes of Fate: three independent encounter HMs.
    [1389] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 175, hardModeCoefficient = 241, expectedHardModes = 3, -- Bal Sunnar
        hardModeEncounters = {
            { key = "kovan-giryon", members = { ["Kovan Giryon"] = true }, required = 1 },
            { key = "roksa", members = { ["Roksa the Warped"] = true }, required = 1 },
            { key = "lladi-telvanni", members = { ["Matriarch Lladi Telvanni"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Matriarch Lladi Telvanni"] = true }, required = 1, hmEncounterKey = "lladi-telvanni" },
    },
    [1390] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 169, hardModeCoefficient = 231, expectedHardModes = 3, -- Scrivener's Hall
        hardModeEncounters = {
            { key = "riftmaster-naqri", members = { ["Riftmaster Naqri"] = true }, required = 1 },
            { key = "ozezan", members = { ["Ozezan the Inferno"] = true }, required = 1 },
            { key = "valinna", members = { ["Valinna"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Valinna"] = true }, required = 1, hmEncounterKey = "valinna" },
    },

    -- Scions of Ithelia: three independent encounter HMs.
    [1470] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 158, hardModeCoefficient = 211, expectedHardModes = 3, -- Oathsworn Pit
        hardModeEncounters = {
            {
                key = "packmaster-rethelros", label = "Packmaster Rethelros and Malthil", required = 2,
                completionMode = "terminal-cohort-death",
                members = { ["Packmaster Rethelros"] = true, ["Malthil"] = true },
            },
            {
                key = "anthelmir", label = "Anthelmir and Anthelmir's Construct", required = 2,
                completionMode = "terminal-cohort-death",
                terminalAbilityEvidence = {
                    requiredDistinct = 2,
                    abilityIds = { [204164] = true, [204176] = true, [204177] = true },
                },
                members = { ["Anthelmir"] = true, ["Anthelmir's Construct"] = true },
            },
            { key = "aradros", members = { ["Aradros the Awakened"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Aradros the Awakened"] = true }, required = 1, hmEncounterKey = "aradros" },
    },
    [1471] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 153, hardModeCoefficient = 202, expectedHardModes = 3, -- Bedlam Veil
        hardModeEncounters = {
            { key = "shattered-champion", members = { ["Shattered Champion"] = true }, required = 1 },
            { key = "darkshard", members = { ["Darkshard"] = true }, required = 1 },
            { key = "the-blind", members = { ["The Blind"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["The Blind"] = true }, required = 1, hmEncounterKey = "the-blind" },
    },

    -- Fallen Banners: three independent encounter HMs.
    [1496] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 142, hardModeCoefficient = 183, expectedHardModes = 3, -- Exiled Redoubt
        hardModeEncounters = {
            { key = "executioner-jerensi", members = { ["Executioner Jerensi"] = true }, required = 1 },
            { key = "vandorallen", members = { ["Prime Sorcerer Vandorallen"] = true }, required = 1 },
            { key = "squall-of-retribution", members = { ["Squall of Retribution"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Squall of Retribution"] = true }, required = 1, hmEncounterKey = "squall-of-retribution" },
    },
    [1497] = {
        speedThresholdMs = 30 * MINUTE, veteranCoefficient = 169, hardModeCoefficient = 231, expectedHardModes = 3, -- Lep Seclusa
        hardModeEncounters = {
            { key = "garvin", members = { ["Garvin the Tracker"] = true }, required = 1 },
            { key = "noriwen", members = { ["Noriwen"] = true }, required = 1 },
            { key = "orpheon", members = { ["Orpheon the Tactician"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["Orpheon the Tactician"] = true }, required = 1, hmEncounterKey = "orpheon" },
    },

    -- Feast of Shadows: three independent encounter HMs.
    [1551] = {
        speedThresholdMs = 25 * MINUTE, veteranCoefficient = 175, hardModeCoefficient = 241, expectedHardModes = 3, -- Naj-Caldeesh
        hardModeEncounters = {
            { key = "poxito", members = { ["Poxito"] = true }, required = 1 },
            { key = "voskrona-stonehulk-poxito", members = { ["Voskrona Stonehulk Poxito"] = true }, required = 1 },
            {
                key = "talen-lah", label = "Talen-Lah and Bar-Sakka", required = 2,
                completionMode = "terminal-cohort-death", allowCohortReentry = true,
                terminalAbilityEvidence = {
                    requiredDistinct = 2,
                    abilityIds = { [242187] = true, [242468] = true, [243112] = true },
                },
                members = { ["Talen-Lah"] = true, ["Bar-Sakka"] = true },
            },
        },
        finalEncounter = { mode = "single", members = { ["Talen-Lah"] = true }, required = 1, hmEncounterKey = "talen-lah" },
    },
    [1552] = {
        speedThresholdMs = 30 * MINUTE, veteranCoefficient = 175, hardModeCoefficient = 241, expectedHardModes = 3, -- Black Gem Foundry
        hardModeEncounters = {
            { key = "saldezaar", members = { ["Quarrymaster Saldezaar"] = true }, required = 1 },
            { key = "black-gem-monstrosity", members = { ["Black Gem Monstrosity"] = true }, required = 1 },
            { key = "vykand", members = { ["High Soulbinder Vykand"] = true }, required = 1 },
        },
        finalEncounter = { mode = "single", members = { ["High Soulbinder Vykand"] = true }, required = 1, hmEncounterKey = "vykand" },
    },
}
