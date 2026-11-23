local AH = _G.MarkTrialHelper

-- some ability names do not match the achievement name
AH.EXCEPTIONS = {[191802] = _G.MARKTRIALHELPER_WEREWOLF_BEHEMOTH}

AH.TYPES = {
    VERSE = ENDLESS_DUNGEON_BUFF_TYPE_VERSE,
    VISION = ENDLESS_DUNGEON_BUFF_TYPE_VISION
}

AH.CLASSES = {
    AVATAR = SI_ENDLESSDUNGEONBUFFTYPE_AVATAR2,
    DEFENCE = SI_ENDLESSDUNGEONBUFFBUCKETTYPE1,
    OFFENCE = SI_ENDLESSDUNGEONBUFFBUCKETTYPE0,
    UTILITY = SI_ENDLESSDUNGEONBUFFBUCKETTYPE2
}

AH.ABILITIES = {
    [191802] = {ids = {3796}, class = AH.CLASSES.AVATAR}, -- Bestial Transformation
    [191849] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Flame Aura
    [191936] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Sequential Shield
    [192667] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Swift Gale
    [192848] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Pustulent Globs
    [192992] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Archival Weaponry
    [193146] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Tempered Ward
    [193551] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Cold Blast
    [193597] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Beatdown
    [193692] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Transfusion
    [193711] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Siphoning Vigor
    [193749] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Enhanced Remedy
    [193758] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Magicka Renewal
    [193977] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Augmented Areas
    [193984] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Exsanguinate
    [194030] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Regenerating Bastion
    [194058] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Restorative Elixirs
    [194062] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Stamina Renewal
    [194138] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Rebirth
    [194153] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Reactive Curse
    [194166] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Archival Evasion
    [194179] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Head-On Defense
    [194181] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Magical Expiration
    [194183] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Energetic Expiration
    [194192] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Glamorous Scholar
    [195038] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Shackled Resolve
    [195928] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Vital Expiration
    [196018] = {ids = {3797}, class = AH.CLASSES.AVATAR}, -- Iron Atronach
    [197522] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Curative Vigor
    [197652] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Hearty Vitality
    [197684] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Refined Restoration
    [197694] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Armored Shell
    [199960] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Sweeping Guard
    [199990] = {ids = {3785, 3796}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Ferocious Fortification
    [199997] = {ids = {3785, 3795}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Crystalline Fortification
    [200004] = {ids = {3785, 3797}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Scorching Fortification
    [200015] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Archival Worldliness
    [200016] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Guild Superiority
    [200017] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Class Embodiment
    [200018] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Archival Assault
    [200020] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Magical Multitudes
    [200022] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Bolstered Mending
    [200045] = {ids = {3799, 3800, 3801, 4153}, class = AH.CLASSES.OFFENCE}, -- Orbiting Echoes ***
    [200051] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Energized Salve
    [200075] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Frenzied Zeal
    [200093] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Guardian of Pestilence
    [200127] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Effortless Aegis
    [200135] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Unrestrained Endurance
    [200142] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Effortless Acrobatics
    [200150] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Mystical Ward
    [200164] = {ids = {3785}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Restorative Protection
    [200175] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Redirecting Bonds
    [200180] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Powerful Domain
    [200202] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Defensive Maneuver
    [200204] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Fortified Dexterity
    [200236] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Restorative Enabling
    [200291] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Lethal Sorcery
    [200306] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Bountiful Resources
    [200311] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Mighty Bash
    [200359] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Brawling Advantage
    [200370] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Thaumic Boom
    [200399] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Brawling Blitz
    [200412] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Tomefoolery
    [200421] = {ids = {3784, 3796}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Ferocious Strikes
    [200494] = {ids = {3784, 3795}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Crystalline Strikes
    [200521] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Unwitting Fortress
    [200679] = {ids = {3784, 3797}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Scorching Strikes
    [200686] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Piercing Perfection
    [200714] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Painful Proficient
    [200728] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Thumping Thaumaturgy
    [200742] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Persistant Pain
    [200790] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Lasting Harm
    [200798] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Targeted Ire
    [200904] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Focused Efforts
    [200941] = {ids = {3783, 3805, 3806, 3807}, class = AH.CLASSES.UTILITY}, -- Gilded Sleight
    [201012] = {ids = {3784}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Well-Trained Command
    [201098] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Lessons Learned
    [201341] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Full Coffers
    [201400] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Archival Intelligence
    [201407] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Archival Endurance
    [201414] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Stamina Reserves
    [201428] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Magicka Reserves
    [201435] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Boundless Potential
    [201443] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Extended Favor
    [201472] = {ids = {3782, 3802, 3803, 3804}, class = AH.CLASSES.DEFENCE}, -- Eye Catching
    [201474] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Resolute Mind
    [201491] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Attuned Enchantments
    [201504] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Vicious Poisons
    [202134] = {ids = {3795}, class = AH.CLASSES.AVATAR}, -- Ice Avatar
    [202510] = {ids = {3786, 3795}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Crystalline Support
    [202743] = {ids = {3796, 3786}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Ferocious Support
    [202804] = {ids = {3786, 3797}, type = AH.TYPES.VISION, class = AH.CLASSES.AVATAR}, -- Scorching Support
    [211730] = {ids = {3786}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Supplemental Thread
    [220160] = {ids = {3802, 3803, 3804, 4153}, class = AH.CLASSES.DEFENCE}, -- Reflected Ruin ***
    [220184] = {ids = {3799, 3800, 3801, 4153}, class = AH.CLASSES.OFFENCE}, -- Tempest ***
    [220189] = {ids = {4153, 4155}, class = AH.CLASSES.AVATAR}, -- Undead Avatar ***
    [220193] = {ids = {3805, 3806, 3807, 4153}, class = AH.CLASSES.UTILITY}, -- Grasping Limbs ***
    [220194] = {ids = {3805, 3806, 3807, 4153}, class = AH.CLASSES.UTILITY}, -- Temporal Speed ***
    [220195] = {ids = {3805, 3806, 3807, 4153}, class = AH.CLASSES.UTILITY}, -- Extravagant Elixirs ***
    [220557] = {ids = {3802, 3803, 3804, 4154, 4155}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Necrotic Fortification ***
    [220563] = {ids = {3799, 3800, 3801, 4154, 4155}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Necrotic Strikes ***
    [220568] = {ids = {3805, 3806, 3807, 4154, 4155}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Necrotic Support ***
    [220730] = {ids = {3802, 3803, 3804, 4153}, class = AH.CLASSES.DEFENCE}, -- Phalanx ***
    [220765] = {ids = {3799, 3800, 3801, 4154}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Storm Projection ***
    [220770] = {ids = {3802, 3803, 3804, 4154}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Prickly Retort ***
    [220775] = {ids = {3802, 3803, 3804, 4154}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Apocryphal Emissary ***
    [220780] = {ids = {3805, 3806, 3807, 4154}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY}, -- Quickened Tinctures ***
    [221194] = {ids = {3781, 3799, 3800, 3801}, class = AH.CLASSES.OFFENCE}, -- Fire Orb
    [222405] = {ids = {3802, 3803, 3804, 4154}, type = AH.TYPES.VISION, class = AH.CLASSES.DEFENCE}, -- Adaptive Defender ***
    [222413] = {ids = {3799, 3800, 3801, 4154}, type = AH.TYPES.VISION, class = AH.CLASSES.OFFENCE}, -- Adaptive Conqueror ***
    [222418] = {ids = {3805, 3806, 3807, 4154}, type = AH.TYPES.VISION, class = AH.CLASSES.UTILITY} -- Adaptive Athlete ***
}

do
    for _, info in pairs(AH.ABILITIES) do
        if (not info.type) then
            info.type = AH.TYPES.VERSE
        end
    end
end

AH.AVATAR = {
    ICE = {id = 3795, abilityIds = {202134, 202510, 200494, 199997}, class = AH.CLASSES.DEFENCE, transform = 202134},
    WOLF = {id = 3796, abilityIds = {202743, 200421, 199990, 191802}, class = AH.CLASSES.OFFENCE, transform = 191802},
    IRON = {id = 3797, abilityIds = {202804, 200679, 200004, 196018}, class = AH.CLASSES.UTILITY, transform = 196018},
    UNDEAD = {id = 4155, abilityIds = {220557, 220563, 220568, 220189}, class = AH.CLASSES.OFFENCE, transform = 220189}
}

-- collect a number of unspecified verse/vision types
AH.GENERAL = {
    3799,
    3800,
    3801,
    3802,
    3803,
    3804,
    3805,
    3806,
    3807
}

AH.MYSTERY = {
    [203611] = "u40_verse_item_offense", -- offensive
    [203612] = "u40_verse_item_defense", -- defensive
    [203613] = "u40_verse_item_utility" -- utility
}

AH.ACHIEVEMENTS = {
    IDS = {
        [3751] = true,
        [3752] = true,
        [3753] = true,
        [3754] = true,
        [3755] = true,
        [3756] = true,
        [3757] = true,
        [3758] = true,
        [3759] = true,
        [3760] = true,
        [3761] = true,
        [3762] = true,
        [3763] = true,
        [3764] = true,
        [3765] = true,
        [3766] = true,
        [3767] = true,
        [3768] = true,
        [3769] = true,
        [3770] = true,
        [3771] = true,
        [3772] = true,
        [3773] = true,
        [3774] = true,
        [3775] = true,
        [3776] = true,
        [3777] = true,
        [3778] = true,
        [3779] = true,
        [3780] = true,
        [3781] = true,
        [3782] = true,
        [3783] = true,
        [3784] = true,
        [3785] = true,
        [3786] = true,
        [3787] = true,
        [3789] = true,
        [3790] = true,
        [3791] = true,
        [3792] = true,
        [3793] = true,
        [3794] = true,
        [3795] = true,
        [3796] = true,
        [3797] = true,
        [3798] = true,
        [3799] = true,
        [3800] = true,
        [3801] = true,
        [3802] = true,
        [3803] = true,
        [3804] = true,
        [3805] = true,
        [3806] = true,
        [3807] = true,
        [3848] = true,
        [3926] = true,
        [3927] = true,
        [3928] = true,
        [3929] = true,
        [3930] = true,
        [3931] = true,
        [3932] = true,
        [3933] = true,
        [3934] = true,
        [3935] = true,
        [3936] = true,
        [3937] = true,
        [3938] = true,
        [4005] = true,
        [4008] = true,
        [4152] = true,
        [4153] = true,
        [4154] = true,
        [4155] = true,
        [4156] = true,
        [4157] = true,
        [4198] = true,
        [4199] = true
    },
    LIMIT = {
        3760,
        3761,
        3762 -- defeat thousands of maligraphies, really don't need this firing every time you kill something
    }
}

AH.SKILL_TYPE_BUFFS = {
    [SKILL_TYPE_AVA] = {200018},
    [SKILL_TYPE_CLASS] = {200017},
    [SKILL_TYPE_GUILD] = {200016},
    [SKILL_TYPE_WORLD] = {200015},
    [AH.SKILL_TYPE_PET] = {201012}
}

AH.PETS = {
    [23304] = true,
    [23316] = true,
    [23319] = true,
    [24613] = true,
    [24636] = true,
    [24639] = true,
    [30581] = true,
    [30584] = true,
    [30587] = true,
    [30592] = true,
    [30595] = true,
    [30598] = true,
    [30618] = true,
    [30622] = true,
    [30626] = true,
    [30631] = true,
    [30636] = true,
    [30641] = true,
    [30647] = true,
    [30652] = true,
    [30657] = true,
    [30664] = true,
    [30669] = true,
    [30674] = true,
    [85982] = true,
    [85983] = true,
    [85984] = true,
    [85985] = true,
    [85986] = true,
    [85987] = true,
    [85988] = true,
    [85989] = true,
    [85990] = true,
    [85991] = true,
    [85992] = true,
    [85993] = true
}

AH.TERRAIN = {
    -- Molten rain (which ones are relevant?)
    151317, -- Molten rain
    151328, -- Molten rain
    "151357,151362", -- Molten rain
    151365, -- Molten rain
    151367, -- Molten rain
    151369, -- Molten rain
    "151370,151371", -- Molten rain
    "151391,151395", -- Molten rain
    151397, -- Molten rain
    "151402,151403", -- Molten rain
    152194, -- Molten rain
    "154992,154993", -- Molten rain
    "154995,154998", -- Molten rain
    "155000,155001", -- Molten rain
    "155004,155005", -- Molten rain
    "156951,156952", -- Molten rain
    "157482,157504", -- Molten rain
    "158393,158405", -- Molten rain
    "182805,182807", -- Lava
    182833, -- Lava
    "195454,195458", -- Molten rain
    198997, -- Molten rain
    199002, -- Molten rain
    "224944,224945", -- Frigid waters
    "224947,224949", -- Frigid Waters
    "224951,224952" -- Frigid waters
}

AH.AUDITOR = 12269

AH.ARCANE_BARRAGE = {
    "212081,212088"
}

AH.SEEKING_RUNESCRAWL = {
    "207590,207592"
}

--[[
3781, -- I crave violence
3782, -- You can't touch me
3783, -- Viable and versatile
3784, -- Visions of violence
3785, -- Infinite defender
3786, -- Seeing the big picture
3795, -- Keeping it cool
3796, -- Howling with rage
3797, -- Molten measures
3799, -- Battle ready 5 offensive versions/visions
3800, -- Armed onslaught 25 offensive versions/visions
3801, -- Mora's onslaught 75 offensive versions/visions
3802, -- A sturdy shield 5 defensive versions/visions
3803, -- Forceful Fortification 25 defensive versions/visions
3804, -- Under Mora's protection 75 defensive versions/visions
3805, -- Studying up 5 utility versions/visions
3806, -- Unorthdox approach 25 utility versions/visions
3807, -- Power practicum 75 utility versions/visions
4153, -- Gifted and Accomplished 8 verses
4154, -- Prepared Foresight 10 visions
4155, -- Cadaverous Crusader - necrotic set

]]