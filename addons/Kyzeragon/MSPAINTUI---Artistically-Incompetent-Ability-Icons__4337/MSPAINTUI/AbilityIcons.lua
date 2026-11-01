local MSP = MSPAINTUI

local ABILITY_ICONS = {
    ["Dragonknight"] = {
        -- Dragonknight - Ardent Flame (pre-U49) - @BirdSalad
        "ability_dragonknight_001.dds",
        "ability_dragonknight_001_a.dds",
        "ability_dragonknight_001_b.dds",
        "ability_dragonknight_002.dds",
        "ability_dragonknight_002_a.dds",
        "ability_dragonknight_002_b.dds",
        "ability_dragonknight_003.dds",
        "ability_dragonknight_003_a.dds",
        "ability_dragonknight_003_b.dds",
        "ability_dragonknight_004.dds",
        "ability_dragonknight_004_a.dds",
        "ability_dragonknight_004_b.dds",
        "ability_dragonknight_005.dds",
        "ability_dragonknight_005_a.dds",
        "ability_dragonknight_005_b.dds",
        "ability_dragonknight_006.dds",
        "ability_dragonknight_006_a.dds",
        "ability_dragonknight_006_b.dds",
        "ability_warrior_025.dds", -- Whip proc

        -- Dragonknight - Draconic Power (pre-U49) - @BortSmithson
        "ability_dragonknight_007.dds", -- Earthspike Mantle
        "ability_dragonknight_007_a.dds",
        "ability_dragonknight_007_b.dds",
        "ability_dragonknight_008.dds", -- Wing Buffet
        "ability_dragonknight_008_a.dds",
        "ability_dragonknight_008_b.dds",
        "ability_dragonknight_009.dds", -- Dragon Leap - @BirdSalad
        "ability_dragonknight_009_a.dds",
        "ability_dragonknight_009_b.dds",
        "ability_dragonknight_010.dds", -- Talons
        "ability_dragonknight_010_a.dds",
        "ability_dragonknight_010_b.dds",
        "ability_dragonknight_011.dds", -- Dragon Blood
        "ability_dragonknight_011_a.dds",
        "ability_dragonknight_011_b.dds",
        "ability_dragonknight_012.dds", -- Core of Flame
        "ability_dragonknight_012_a.dds",
        "ability_dragonknight_012_b.dds",

        -- Dragonknight - Earthen Heart (pre-U49)
        -- "ability_dragonknight_013.dds",
        -- "ability_dragonknight_013_a.dds",
        -- "ability_dragonknight_013_b.dds",
        -- "ability_dragonknight_014.dds",
        -- "ability_dragonknight_014_a.dds",
        -- "ability_dragonknight_014b.dds",
        -- "ability_dragonknight_015.dds",
        -- "ability_dragonknight_015_a.dds",
        -- "ability_dragonknight_015_b.dds",
        -- "ability_dragonknight_016.dds",
        -- "ability_dragonknight_016a.dds",
        -- "ability_dragonknight_016b.dds",
        -- "ability_dragonknight_017.dds",
        -- "ability_dragonknight_017a.dds",
        -- "ability_dragonknight_017b.dds",
        -- "ability_dragonknight_018.dds",
        -- "ability_dragonknight_018_a.dds",
        -- "ability_dragonknight_018_b.dds",
    },

    ["Sorcerer"] = {
        -- Sorcerer - Storm Calling - @Thepinja
        "ability_sorcerer_overload.dds",
        "ability_sorcerer_power_overload.dds",
        "ability_sorcerer_energy_overload.dds",
        "ability_sorcerer_mage_fury.dds",
        "ability_sorcerer_endless_fury.dds",
        "ability_sorcerer_mage_wraith.dds",
        "ability_sorcerer_lightning_form.dds",
        "ability_sorcerer_boundless_storm.dds",
        "ability_sorcerer_thundering_presence.dds", -- Hurricane
        "ability_sorcerer_lightning_splash.dds",
        "ability_sorcerer_lightning_flood.dds",
        "ability_sorcerer_liquid_lightning.dds",
        "ability_sorcerer_surge.dds",
        "ability_sorcerer_critical_surge.dds",
        "ability_sorcerer_power_surge.dds",
        "ability_sorcerer_bolt_escape.dds",
        "ability_sorcerer_ball_of_lightning.dds",
        "ability_sorcerer_streak.dds",

        -- Sorcerer - Daedric Summoning - @Thepinja
        "ability_sorcerer_storm_atronach.dds",
        "ability_sorcerer_endless_atronachs.dds", -- Charged Atronach
        "ability_sorcerer_greater_storm_atronach.dds",
        "ability_sorcerer_unstable_fimiliar.dds",
        "ability_sorcerer_unstable_fimiliar_summoned.dds",
        "ability_sorcerer_speedy_familiar.dds", -- Volatile
        "ability_sorcerer_speedy_familiar_summoned.dds",
        "ability_sorcerer_unstable_clannfear.dds",
        "ability_sorcerer_unstable_clannfear_summoned.dds",
        "ability_sorcerer_daedric_curse.dds",
        "ability_sorcerer_explosive_curse.dds", -- Daedric Prey
        "ability_sorcerer_velocious_curse.dds", -- Haunting Curse
        "ability_sorcerer_lightning_prey.dds", -- Winged Twilight
        "ability_sorcerer_lightning_prey_summoned.dds",
        "ability_sorcerer_lightning_matriarch.dds", -- Twilight Tormentor
        "ability_sorcerer_lightning_matriarch_summoned.dds",
        "ability_sorcerer_storm_prey.dds", -- Matriarch
        "ability_sorcerer_storm_prey_summoned.dds",
        "ability_sorcerer_hurricane.dds", -- Conjured Ward
        "ability_sorcerer_tempest.dds", -- Regenerative Ward
        "ability_sorcerer_typhoon.dds", -- Hardened Ward
        "ability_sorcerer_bound_armor.dds",
        "ability_sorcerer_bound_aegis.dds",
        "ability_sorcerer_bound_armaments.dds",
        "ability_sorcerer_bound_armaments_proc.dds",

        -- Sorcerer - Dark Magic - @Thepinja
        "ability_sorcerer_monsoon.dds", -- Negate Magic
        "ability_sorcerer_crushing_monsoon.dds", -- Suppression Field
        "ability_sorcerer_rushing_winds.dds", -- Absorption Field
        "ability_sorcerer_crystalweapon.dds",
        "ability_sorcerer_thunder_burst.dds", -- unsure what this is, might've been crystal blast
        "ability_sorcerer_thunderclap.dds", -- Crystal Shard
        "ability_sorcerer_thunderstomp.dds", -- Crystal Fragments
        "ability_sorcerer_thunderstomp_proc.dds",
        "ability_sorcerer_cyclone.dds", -- Encase
        "ability_sorcerer_crushing_winds.dds", -- Vibrant Shroud
        "ability_sorcerer_twister.dds", -- Shattering Spines
        "ability_sorcerer_dark_fog.dds", -- Rune Prison
        "ability_sorcerer_dark_haze.dds", -- Rune Cage
        "ability_sorcerer_weakening_fog.dds", -- Defensive Rune
        "ability_sorcerer_dark_conversion.dds",
        "ability_sorcerer_dark_deal.dds",
        "ability_sorcerer_dark_exchange.dds",
        "ability_sorcerer_daedric_minefield.dds",
        "ability_sorcerer_daedric_mines.dds",
        "ability_sorcerer_daedric_tomb.dds",
    },

    ["Nightblade"] = {
        -- Nightblade - Assassination - @Kyzeragon
        "ability_nightblade_002.dds", -- Veiled Strike
        "ability_nightblade_002_a.dds",
        "ability_nightblade_002_b.dds",
        "ability_nightblade_005.dds", -- Grim Focus
        "ability_nightblade_005_a.dds",
        "ability_nightblade_005_b.dds",
        "ability_nightblade_007.dds", -- Death Stroke
        "ability_nightblade_007_a.dds", -- Incap
        "ability_nightblade_007_b.dds", -- Soul Harvest
        "ability_nightblade_007_c.dds", -- Incap green
        "ability_nightblade_008.dds", -- Teleport Strike
        "ability_nightblade_008_a.dds",
        "ability_nightblade_008_b.dds",
        "ability_nightblade_014.dds", -- Mark Target
        "ability_nightblade_014_a.dds",
        "ability_nightblade_014_b.dds",
        "ability_nightblade_017.dds", -- Assassin's Blade
        "ability_nightblade_017_a.dds",
        "ability_nightblade_017_b.dds",

        -- Nightblade - Shadow - @Kyzeragon
        "ability_nightblade_001.dds", -- Shade
        "ability_nightblade_001_a.dds",
        "ability_nightblade_001_b.dds",
        "ability_nightblade_004.dds", -- Shadow Cloak
        "ability_nightblade_004_a.dds",
        "ability_nightblade_004_b.dds",
        "ability_nightblade_009.dds", -- Blur
        "ability_nightblade_009_a.dds",
        "ability_nightblade_009_b.dds",
        "ability_nightblade_010.dds", -- Path
        "ability_nightblade_010_a.dds",
        "ability_nightblade_010_b.dds",
        "ability_nightblade_015.dds", -- Consuming Darkness
        "ability_nightblade_015_a.dds",
        "ability_nightblade_015_b.dds",
        "ability_nightblade_016.dds", -- Aspect of Terror
        "ability_nightblade_016_a.dds",
        "ability_nightblade_016_b.dds",

        -- Nightblade - Siphoning - @Lykeion
        "ability_nightblade_003.dds", -- Siphoning Strikes
        "ability_nightblade_003_a.dds",
        "ability_nightblade_003_b.dds",
        "ability_nightblade_006.dds", -- Cripple
        "ability_nightblade_006_a.dds",
        "ability_nightblade_006_b.dds",
        "ability_nightblade_011.dds", -- Offering
        "ability_nightblade_011_a.dds",
        "ability_nightblade_011_b.dds",
        "ability_nightblade_012.dds", -- Strife
        "ability_nightblade_012_a.dds",
        "ability_nightblade_012_b.dds",
        "ability_nightblade_013.dds", -- Drain Power
        "ability_nightblade_013_a.dds",
        "ability_nightblade_013_b.dds",
        "ability_nightblade_018.dds", -- Soul Shred
        "ability_nightblade_018_a.dds",
        "ability_nightblade_018_b.dds",
    },

    ["Templar"] = {
        -- Templar - Aedric Spear - @camrenis
        "ability_templar_radial_sweep.dds",
        "ability_templar_crescent_sweep.dds",
        "ability_templar_empowering_sweep.dds", -- Everlasting Sweep
        "ability_templar_trained_attacker.dds", -- Puncturing Strikes
        "ability_templar_reckless_attacks.dds", -- Puncturing Sweep
        "ability_templar_recovery.dds", -- Biting Jabs
        "ability_templar_returning_spear.dds", -- Piercing Javelin
        "ability_templar_light_spear.dds", -- Binding Javelin
        "ability_templar_ripping_spear.dds", -- Aurora Javelin
        -- "ability_templar_focused_charge.dds",
        -- "ability_templar_double_tipped_charge.dds", -- Explosive Charge
        -- "ability_templar_toppling_charge.dds",
        -- "ability_templar_sun_strike.dds", -- Spear Shards
        -- "ability_templarsun_thrust.dds", -- Blazing Spear
        -- "ability_templar_light_strike.dds", -- Luminous Shards
        -- "ability_templar_sun_shield.dds",
        -- "ability_templar_blazing_shield.dds",
        -- "ability_templar_radiant_ward.dds",

        -- Templar - Dawn's Wrath - @BirdSalad
        "ability_templar_nova.dds",
        "ability_templar_solar_disturbance.dds",
        "ability_templar_solar_prison.dds",
        "ability_templar_sun_fire.dds",
        "ability_templar_reflective_light.dds",
        "ability_templar_vampire_bane.dds",
        "ability_templar_solar_flare.dds",
        "ability_templar_solar_power.dds", -- Solar Barrage
        "ability_templar_dark_flare.dds",
        "ability_templar_backlash.dds",
        "ability_templar_power_of_the_light.dds",
        "ability_templar_purifying_light.dds",
        "ability_templar_eclipse.dds",
        "ability_templar_total_dark.dds", -- Unstable Core
        "ability_templar_unstable_core.dds", -- Living Dark
        "ability_templar_over_exposure.dds", -- Radiant Destruction
        "ability_templar_stendarr_aura.dds", -- Radiant Oppression
        "ability_templar_under_exposure.dds", -- Radiant Glory

        -- Templar - Restoring Light - @BirdSalad
        "ability_templar_rite_of_passage.dds",
        "ability_templar_remembrance.dds",
        "ability_templar_practiced_incantation.dds",
        "ability_templar_rushed_ceremony.dds",
        "ability_templar_breath_of_life.dds",
        "ability_templar_honor_the_dead.dds",
        "ability_templar_healing_ritual.dds",
        "ability_templar_lingering_ritual.dds", -- Hasty Prayer
        "ability_templar_ritual_of_rebirth.dds",
        "ability_templar_restoring_sigil.dds", -- Restoring Aura
        "ability_templar_life_giving_sigil.dds", -- Radiant Aura
        "ability_templar_persistant_sigil.dds", -- Repentance
        "ability_templar_cleansing_ritual.dds",
        "ability_templar_extended_ritual.dds",
        "ability_templar_purifying_ritual.dds", -- Ritual of Retribution
        "ability_templar_rune_focus.dds",
        "ability_templar_channeled_focus.dds",
        "ability_templar_uninterrupted_focus.dds", -- Restoring Focus
    },

    ["Warden"] = {
        -- Warden - Winter's Embrace - @M0R_Gaming
        "ability_warden_001.dds", -- Frost Cloak
        "ability_warden_001_a.dds",
        "ability_warden_001_b.dds",
        "ability_warden_002.dds", -- Crystallized Shield
        "ability_warden_002_a.dds",
        "ability_warden_002_b.dds",
        "ability_warden_003.dds", -- Arctic Wind
        "ability_warden_003_a.dds",
        "ability_warden_003_b.dds",
        -- "ability_warden_004.dds",
        -- "ability_warden_004_a.dds",
        -- "ability_warden_004_b.dds",
        -- "ability_warden_005.dds",
        -- "ability_warden_005_a.dds",
        -- "ability_warden_005_b.dds",
        "ability_warden_006.dds", -- Sleet Storm
        "ability_warden_006_a.dds",
        "ability_warden_006_b.dds",

        -- Warden - Green Balance
        -- "ability_warden_007.dds",
        -- "ability_warden_007_a.dds",
        -- "ability_warden_007_b.dds",
        -- "ability_warden_007_c.dds",
        -- "ability_warden_008.dds",
        -- "ability_warden_008_a.dds",
        -- "ability_warden_008_b.dds",
        -- "ability_warden_009.dds",
        -- "ability_warden_009_a.dds",
        -- "ability_warden_009_b.dds",
        -- "ability_warden_010.dds",
        -- "ability_warden_010_a.dds",
        -- "ability_warden_010_b.dds",
        -- "ability_warden_011.dds",
        -- "ability_warden_011_a.dds",
        -- "ability_warden_011_b.dds",
        -- "ability_warden_012.dds",
        -- "ability_warden_012_a.dds",
        -- "ability_warden_012_b.dds",

        -- Warden - Animal Companions - @BirdSalad
        "ability_warden_013.dds", -- Dive
        "ability_warden_013_a.dds",
        "ability_warden_013_b.dds",
        "ability_warden_014.dds", -- Swarm
        "ability_warden_014_a.dds",
        "ability_warden_014_b.dds",
        "ability_warden_015.dds", -- Shalks
        "ability_warden_015_a.dds",
        "ability_warden_015_b.dds",
        "ability_warden_016.dds", -- Wings
        "ability_warden_016_a.dds",
        "ability_warden_016_b.dds",
        "ability_warden_017.dds", -- Netch
        "ability_warden_017_a.dds",
        "ability_warden_017_b.dds",
        "ability_warden_018.dds", -- Bear
        "ability_warden_018_a.dds", -- active swipe
        "ability_warden_018_b.dds",
        "ability_warden_018_c.dds",
    },

    ["Necromancer"] = {
        -- Necro - Grave Lord - @BirdSalad
        "ability_necromancer_001.dds",
        "ability_necromancer_001_a.dds",
        "ability_necromancer_001_b.dds",
        "ability_necromancer_002.dds",
        "ability_necromancer_002_blackedout.dds",
        "ability_necromancer_002_a.dds",
        "ability_necromancer_002_a_blackedout.dds",
        "ability_necromancer_002_b.dds",
        "ability_necromancer_002_b_blackedout.dds",
        "ability_necromancer_003.dds",
        "ability_necromancer_003_a.dds",
        "ability_necromancer_003_b.dds",
        "ability_necromancer_004.dds",
        "ability_necromancer_004_a.dds",
        "ability_necromancer_004_b.dds",
        "ability_necromancer_005.dds",
        "ability_necromancer_005_a.dds",
        "ability_necromancer_005_b.dds",
        "ability_necromancer_006.dds",
        "ability_necromancer_006_a.dds",
        "ability_necromancer_006_b.dds",

        -- Necro - Bone Tyrant - @BirdSalad
        "ability_necromancer_007.dds",
        "ability_necromancer_007_a.dds",
        "ability_necromancer_007_b.dds",
        "ability_necromancer_008.dds",
        "ability_necromancer_008_a.dds",
        "ability_necromancer_008_b.dds",
        "ability_necromancer_009.dds",
        "ability_necromancer_009_a.dds",
        "ability_necromancer_009_b.dds",
        "ability_necromancer_010.dds",
        "ability_necromancer_010_a.dds",
        "ability_necromancer_010_b.dds",
        "ability_necromancer_011.dds",
        "ability_necromancer_011_a.dds",
        "ability_necromancer_011_b.dds",
        "ability_necromancer_012.dds",
        "ability_necromancer_012_a.dds",
        "ability_necromancer_012_b.dds",

        -- Necro - Living Death - @BirdSalad
        "ability_necromancer_013.dds", -- Render Flesh
        "ability_necromancer_013_a.dds",
        "ability_necromancer_013_b.dds",
        "ability_necromancer_014.dds", -- Expunge
        "ability_necromancer_014_a.dds",
        "ability_necromancer_014_b.dds",
        "ability_necromancer_015.dds", -- Spirit
        "ability_necromancer_015_a.dds",
        "ability_necromancer_015_b.dds",
        "ability_necromancer_016.dds", -- Life amid Death
        "ability_necromancer_016_a.dds",
        "ability_necromancer_016_b.dds",
        "ability_necromancer_017.dds", -- Restoring Tether
        "ability_necromancer_017_a.dds",
        "ability_necromancer_017_b.dds",
        "ability_necromancer_018.dds", -- Reanimate
        "ability_necromancer_018_a.dds",
        "ability_necromancer_018_b.dds",
    },

    ["Arcanist"] = {
        -- Arcanist - Herald of the Tome - @Kyzeragon
        "ability_arcanist_001.dds",
        "ability_arcanist_001_a.dds",
        "ability_arcanist_001_b.dds",
        "ability_arcanist_002.dds",
        "ability_arcanist_002_a.dds",
        "ability_arcanist_002_b.dds",
        "ability_arcanist_003.dds",
        "ability_arcanist_003_a.dds",
        "ability_arcanist_003_b.dds",
        "ability_arcanist_004.dds",
        "ability_arcanist_004_a.dds",
        "ability_arcanist_004_b.dds",
        "ability_arcanist_005.dds",
        "ability_arcanist_005_a.dds",
        "ability_arcanist_005_b.dds",
        "ability_arcanist_006.dds",
        "ability_arcanist_006_a.dds",
        "ability_arcanist_006_b.dds",

        -- Arcanist - Soldier of Apocrypha - @Kyzeragon
        "ability_arcanist_007.dds", -- Runic Jolt
        "ability_arcanist_007_a.dds",
        "ability_arcanist_007_b.dds",
        "ability_arcanist_008.dds", -- Runespite Ward
        "ability_arcanist_008_a.dds",
        "ability_arcanist_008_b.dds",
        "ability_arcanist_009.dds", -- Fatewoven Armor
        "ability_arcanist_009_a.dds",
        "ability_arcanist_009_b.dds",
        -- "ability_arcanist_010.dds",
        -- "ability_arcanist_010_a.dds",
        -- "ability_arcanist_010_b.dds",
        -- "ability_arcanist_011.dds",
        -- "ability_arcanist_011_a.dds",
        -- "ability_arcanist_011_b.dds",
        "ability_arcanist_012.dds", -- Gibbering Shield
        "ability_arcanist_012_a.dds",
        "ability_arcanist_012_b.dds",

        -- Arcanist - Curative Runeforms
        -- "ability_arcanist_013.dds",
        -- "ability_arcanist_013_a.dds",
        -- "ability_arcanist_013_b.dds",
        -- "ability_arcanist_014.dds",
        -- "ability_arcanist_014_a.dds",
        -- "ability_arcanist_014_b.dds",
        -- "ability_arcanist_015.dds",
        -- "ability_arcanist_015_a.dds",
        -- "ability_arcanist_015_b.dds",
        -- "ability_arcanist_016.dds",
        -- "ability_arcanist_016_a.dds",
        -- "ability_arcanist_016_b.dds",
        -- "ability_arcanist_017.dds",
        -- "ability_arcanist_017_a.dds",
        -- "ability_arcanist_017_b.dds",
        -- "ability_arcanist_018.dds",
        -- "ability_arcanist_018_a.dds",
        -- "ability_arcanist_018_b.dds",
    },

    ["Weapon"] = {
        -- Destro - @Eashi
        "ability_destructionstaff_001.dds", -- Force Shock
        "ability_destructionstaff_001a.dds",
        "ability_destructionstaff_001b.dds",
        "ability_destructionstaff_002.dds", -- Ice Wall
        "ability_destructionstaff_002a.dds",
        "ability_destructionstaff_002b.dds",
        "ability_destructionstaff_003.dds", -- Lightning Wall
        "ability_destructionstaff_003_a.dds",
        "ability_destructionstaff_003_b.dds",
        "ability_destructionstaff_004.dds", -- Inferno Wall
        "ability_destructionstaff_004_a.dds",
        "ability_destructionstaff_004_b.dds",
        "ability_destructionstaff_005.dds", -- Ice Touch
        "ability_destructionstaff_005_a.dds",
        "ability_destructionstaff_005_b.dds",
        "ability_destructionstaff_006.dds", -- Lightning Touch
        "ability_destructionstaff_006_a.dds",
        "ability_destructionstaff_006_b.dds",
        "ability_destructionstaff_007.dds", -- Inferno Touch
        "ability_destructionstaff_007_a.dds",
        "ability_destructionstaff_007_b.dds",
        "ability_destructionstaff_008.dds", -- Ice Impulse
        "ability_destructionstaff_008_a.dds",
        "ability_destructionstaff_008_b.dds",
        "ability_destructionstaff_009.dds", -- Lightning Impulse
        "ability_destructionstaff_009_a.dds",
        "ability_destructionstaff_009_b.dds",
        "ability_destructionstaff_010.dds", -- Inferno Impulse
        "ability_destructionstaff_010_a.dds",
        "ability_destructionstaff_010_b.dds",
        "ability_destructionstaff_011.dds", -- Weakness to Elements
        "ability_destructionstaff_011a.dds",
        "ability_destructionstaff_011b.dds",
        "ability_destructionstaff_012.dds", -- "magic" destro
        "ability_destructionstaff_012_a.dds",
        "ability_destructionstaff_012_b.dds",
        "ability_destructionstaff_013.dds", -- Inferno destro
        "ability_destructionstaff_013_a.dds",
        "ability_destructionstaff_013_b.dds",
        "ability_destructionstaff_014.dds", -- Ice destro
        "ability_destructionstaff_014_a.dds",
        "ability_destructionstaff_014_b.dds",
        "ability_destructionstaff_015.dds", -- Lightning destro
        "ability_destructionstaff_015_a.dds",
        "ability_destructionstaff_015_b.dds",
        -- "ability_grimoire_staffdestro.dds",

        -- 2H - @t.ea
        "ability_2handed_001.dds", -- Uppercut
        "ability_2handed_001_a.dds",
        "ability_2handed_001_b.dds",
        "ability_2handed_002.dds", -- Cleave
        "ability_2handed_002_a.dds",
        "ability_2handed_002_b.dds",
        "ability_2handed_003.dds", -- Critical Charge
        "ability_2handed_003_a.dds",
        "ability_2handed_003_b.dds",
        "ability_2handed_004.dds", -- Reverse Slash
        "ability_2handed_004_a.dds",
        "ability_2handed_004_b.dds",
        "ability_2handed_005.dds", -- Momentum
        "ability_2handed_005_a.dds",
        "ability_2handed_005_b.dds",
        "ability_2handed_006.dds", -- Berserker Strike
        "ability_2handed_006_a.dds",
        "ability_2handed_006_b.dds",
        -- "ability_grimoire_2handed.dds",

        -- Bow - @BortSmithson
        "ability_bow_001.dds",
        "ability_bow_001_a.dds",
        "ability_bow_001_b.dds",
        "ability_bow_002.dds",
        "ability_bow_002_a.dds",
        "ability_bow_002_b.dds",
        "ability_bow_003.dds",
        "ability_bow_003_a.dds",
        "ability_bow_003_b.dds",
        "ability_bow_004.dds",
        "ability_bow_004_a.dds",
        "ability_bow_004_b.dds",
        "ability_bow_005.dds",
        "ability_bow_005_a.dds",
        "ability_bow_005_b.dds",
        "ability_bow_006.dds",
        "ability_bow_006_a.dds",
        "ability_bow_006_b.dds",
        "ability_grimoire_bow.dds",

        -- Sword n Board
        -- "ability_1handed_001.dds",
        -- "ability_1handed_001_a.dds",
        -- "ability_1handed_001_b.dds",
        -- "ability_1handed_002.dds",
        -- "ability_1handed_002_a.dds",
        -- "ability_1handed_002_b.dds",
        -- "ability_1handed_003.dds",
        -- "ability_1handed_003_a.dds",
        -- "ability_1handed_003_b.dds",
        -- "ability_1handed_004.dds",
        -- "ability_1handed_004_a.dds",
        -- "ability_1handed_004_b.dds",
        -- "ability_1handed_005.dds",
        -- "ability_1handed_005_a.dds",
        -- "ability_1handed_005_b.dds",
        -- "ability_1handed_006.dds",
        -- "ability_1handed_006_a.dds",
        -- "ability_1handed_006_b.dds",
        -- "ability_grimoire_1handed.dds",

        -- Dual Wield - @BirdSalad
        "ability_dualwield_001.dds",
        "ability_dualwield_001_a.dds",
        "ability_dualwield_001_b.dds",
        "ability_dualwield_002.dds",
        "ability_dualwield_002_a.dds",
        "ability_dualwield_002_b.dds",
        "ability_dualwield_003.dds",
        "ability_dualwield_003_a.dds",
        "ability_dualwield_003_b.dds",
        "ability_dualwield_004.dds",
        "ability_dualwield_004_a.dds",
        "ability_dualwield_004_b.dds",
        "ability_dualwield_005.dds",
        "ability_dualwield_005_a.dds",
        "ability_dualwield_005_b.dds",
        "ability_dualwield_006.dds",
        "ability_dualwield_006_a.dds",
        "ability_dualwield_006_b.dds",
        "ability_grimoire_dualwield.dds", -- @BirdSalad

        -- Resto - @cfblack
        -- "ability_restorationstaff_001.dds",
        -- "ability_restorationstaff_001_a.dds",
        -- "ability_restorationstaff_001_b.dds",
        -- "ability_restorationstaff_002.dds",
        -- "ability_restorationstaff_002a.dds",
        -- "ability_restorationstaff_002b.dds",
        "ability_restorationstaff_003.dds", -- Blessing of Protection
        "ability_restorationstaff_003_a.dds",
        "ability_restorationstaff_003_b.dds",
        -- "ability_restorationstaff_004.dds",
        -- "ability_restorationstaff_004a.dds",
        -- "ability_restorationstaff_004b.dds",
        -- "ability_restorationstaff_005.dds",
        -- "ability_restorationstaff_005_a.dds",
        -- "ability_restorationstaff_005_b.dds",
        "ability_restorationstaff_006.dds", -- Panacea
        "ability_restorationstaff_006_a.dds",
        "ability_restorationstaff_006_b.dds",
        -- "ability_grimoire_staffresto.dds",
    },

    ["Guild"] = {
        -- Fighters Guild - @QueuesAsTanks
        "ability_fightersguild_001.dds", -- Circle
        "ability_fightersguild_001_a.dds",
        "ability_fightersguild_001_b.dds",
        "ability_fightersguild_002.dds", -- Expert Hunter @Eashi
        -- "ability_fightersguild_002_a.dds",
        "ability_fightersguild_002_b.dds", -- Camo @Eashi
        "ability_fightersguild_003.dds", -- Silver
        "ability_fightersguild_003_a.dds",
        "ability_fightersguild_003_b.dds",
        "ability_fightersguild_004.dds", -- Trap
        "ability_fightersguild_004_a.dds",
        "ability_fightersguild_004_b.dds",
        "ability_fightersguild_005.dds", -- Dawnbreaker
        "ability_fightersguild_005_a.dds",
        "ability_fightersguild_005_b.dds",
        -- "ability_grimoire_fightersguild.dds",

        -- Mages Guild - @Thepinja
        "ability_mageguild_001.dds", -- Fire Fune
        "ability_mageguild_001_a.dds",
        "ability_mageguild_001_b.dds",
        -- "ability_mageguild_002.dds",
        -- "ability_mageguild_002_a.dds",
        -- "ability_mageguild_002_b.dds",
        "ability_mageguild_003.dds", -- Balance
        "ability_mageguild_003_a.dds",
        "ability_mageguild_003_b.dds",
        "ability_mageguild_004.dds", -- Entropy
        "ability_mageguild_004_a.dds",
        "ability_mageguild_004_b.dds",
        "ability_mageguild_005.dds", -- Meteor
        "ability_mageguild_005_a.dds",
        "ability_mageguild_005_b.dds",
        "ability_grimoire_magesguild.dds", -- Contingency

        -- Psijic - @Eashi
        "ability_psijic_001.dds", -- Undo
        "ability_psijic_001_a.dds",
        "ability_psijic_001_b.dds",
        "ability_psijic_002.dds", -- Time Stop
        "ability_psijic_002_a.dds",
        "ability_psijic_002_b.dds",
        "ability_psijic_003.dds", -- Imbue Weapon
        "ability_psijic_003_a.dds",
        "ability_psijic_003_b.dds",
        "ability_psijic_004.dds", -- Meditate
        "ability_psijic_004_a.dds",
        "ability_psijic_004_b.dds",
        "ability_psijic_005.dds", -- Accelerate
        "ability_psijic_005_a.dds",
        "ability_psijic_005_b.dds",
        "ability_psijic_006.dds", -- Mend Wounds
        "ability_psijic_006_a.dds",
        "ability_psijic_006_b.dds",

        -- Undaunted
        -- "ability_undaunted_001.dds",
        -- "ability_undaunted_001_a.dds",
        -- "ability_undaunted_001_b.dds",
        -- "ability_undaunted_002.dds",
        -- "ability_undaunted_002_a.dds",
        -- "ability_undaunted_002_b.dds",
        -- "ability_undaunted_003.dds",
        -- "ability_undaunted_003_a.dds",
        -- "ability_undaunted_003_b.dds",
        -- "ability_undaunted_004.dds",
        -- "ability_undaunted_004_a.dds",
        -- "ability_undaunted_004b.dds",
        -- "ability_undaunted_005.dds",
        -- "ability_undaunted_005a.dds",
        -- "ability_undaunted_005b.dds",
    },

    ["Alliance War"] = {
        -- Assault
        -- "ability_ava_001.dds",
        -- "ability_ava_001_a.dds",
        -- "ability_ava_001_b.dds",
        -- "ability_ava_002.dds",
        -- "ability_ava_002_a.dds",
        -- "ability_ava_002_b.dds",
        "ability_ava_003.dds", -- War Horn - @SuddenGhost24
        "ability_ava_003_a.dds",
        "ability_ava_003_b.dds",
        -- "ability_ava_echoing_vigor.dds",
        -- "ability_ava_vigor.dds",
        "ability_ava_resolving_vigor.dds", -- @BirdSalad
        -- "ability_ava_inevitable_detonation.dds",
        -- "ability_ava_magicka_detonation.dds",
        -- "ability_ava_proximity_detonation.dds",
        "ability_grimoire_assault.dds", -- @Eashi

        -- Support - @BirdSalad
        "ability_ava_004.dds",
        "ability_ava_004_a.dds",
        "ability_ava_004_b.dds",
        "ability_ava_005.dds",
        "ability_ava_005_a.dds",
        "ability_ava_005_b.dds",
        "ability_ava_006.dds",
        "ability_ava_006_a.dds",
        "ability_ava_006_b.dds",
        "ability_ava_guard.dds",
        "ability_ava_mystic_guard.dds",
        "ability_ava_stalwart_guard.dds",
        "ability_ava_lingering_flare.dds",
        "ability_ava_revealing_flare.dds",
        "ability_ava_scorching_flare.dds",
        "ability_grimoire_support.dds", -- @BirdSalad
    },

    ["World"] = {
        -- Soul Magic - @Thepinja
        "ability_otherclass_001.dds",
        "ability_otherclass_001_a.dds",
        "ability_otherclass_001_b.dds",
        "ability_otherclass_002.dds",
        "ability_otherclass_002_a.dds",
        "ability_otherclass_002_b.dds",
        "ability_grimoire_soulmagic1.dds",
        "ability_grimoire_soulmagic2.dds",

        -- Vampire - @SpookaSpooka
        -- "ability_u26_vampire_01.dds",
        -- "ability_u26_vampire_01_a.dds",
        -- "ability_u26_vampire_01_b.dds",
        "ability_u26_vampire_02.dds", -- Blood Frenzy
        "ability_u26_vampire_02_a.dds",
        "ability_u26_vampire_02_b.dds",
        "ability_u26_vampire_03.dds", -- Vampiric Drain
        "ability_u26_vampire_03_a.dds",
        "ability_u26_vampire_03_b.dds",
        -- "ability_u26_vampire_04.dds",
        -- "ability_u26_vampire_04_a.dds",
        -- "ability_u26_vampire_04_b.dds",
        -- "ability_u26_vampire_05.dds",
        -- "ability_u26_vampire_05_a.dds",
        -- "ability_u26_vampire_05_b.dds",
        "ability_u26_vampire_06.dds", -- Blood Scion
        "ability_u26_vampire_06_a.dds",
        "ability_u26_vampire_06_b.dds",

        -- Werewolf - @Plonkerr
        "ability_werewolf_001.dds", -- Werewolf Transformation
        "ability_werewolf_001_a.dds",
        "ability_werewolf_001_b.dds",
        "ability_werewolf_002.dds", -- Pounce
        "ability_werewolf_002_rend.dds",
        "ability_werewolf_002_a.dds",
        "ability_werewolf_002_rend_a.dds", -- (blue)
        "ability_werewolf_002_b.dds",
        "ability_werewolf_002_rend_b.dds",
        "ability_werewolf_003.dds", -- Roar
        "ability_werewolf_003_a.dds",
        "ability_werewolf_003_b.dds",
        "ability_werewolf_004_a.dds", -- Hircine's Bounty
        "ability_werewolf_004_b.dds", -- Hircine's Rage
        "ability_werewolf_004_c.dds", -- Hircine's Fortitude
        "ability_werewolf_005_a.dds", -- Piercing Howl
        "ability_werewolf_005_b.dds",
        "ability_werewolf_005_c.dds",
        "ability_werewolf_006_a.dds", -- Infectious Claws
        "ability_werewolf_006_b.dds",
        "ability_werewolf_006_c.dds",
    },

    ["Armor"] = {
        -- Armor - @Thepinja
        "ability_armor_001.dds",
        "ability_armor_001_a.dds",
        "ability_armor_001_b.dds",
        "ability_armor_002.dds",
        "ability_armor_002_a.dds",
        "ability_armor_002_b.dds",
        "ability_armor_003.dds",
        "ability_armor_003_a.dds",
        "ability_armor_003_b.dds",
    },
}
MSP.ABILITY_ICONS = ABILITY_ICONS

local function RedirectAbilityTextures()
    for groupName, group in pairs(ABILITY_ICONS) do
        if (MSP.savedOptions.enable[groupName]) then
            for _, iconPath in ipairs(group) do
                RedirectTexture("/esoui/art/icons/" .. iconPath, "MSPAINTUI/art/abilities/" .. iconPath)
            end
        end
    end
end
MSP.RedirectAbilityTextures = RedirectAbilityTextures

