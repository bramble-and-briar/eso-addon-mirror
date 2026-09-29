--- @class Srendarr
local Srendarr = _G['Srendarr'] -- grab addon table from global
local L = Srendarr:GetLocale()

-- UPVALUES --
local GetAbilityName = GetAbilityName
local ZOSName = function (data, mode) if mode == 1 then return zo_strformat('<<t:1>>', GetAbilityName(data)) else return zo_strformat('<<t:1>>', GetItemSetName(data)) end end
local ATd = function (id) -- temp fix for missing ability IDs in PTS API 101042, will need ability-specific updates on release (Phinix)
    local tDur = GetAbilityDuration(id)
    if tDur ~= nil then
        return tDur / 1000
    else
        -- Disabled for now.
        -- d('Srendarr: ' .. tostring(id) .. ' has no duration value (nil).')
        return 0
    end
end
local strformat = string.format
local maxStage = Srendarr.maxSearchStage
local buffTypeScan = {}

-- Major & Minor Effect Identifiers
local EFFECT_AEGIS = 1
local EFFECT_BERSERK = 2
local EFFECT_BREACH = 3
local EFFECT_BRITTLE = 4
local EFFECT_BRUTALITY = 5
local EFFECT_COURAGE = 6
local EFFECT_COWARDICE = 7
local EFFECT_DEFILE = 8
local EFFECT_ENDURANCE = 9
local EFFECT_ENERVATION = 10
local EFFECT_EVASION = 11
local EFFECT_EXPEDITION = 12
local EFFECT_FORCE = 13
local EFFECT_FORTITUDE = 14
local EFFECT_GALLOP = 15
local EFFECT_HEROISM = 16
local EFFECT_HINDRANCE = 17
local EFFECT_INTELLECT = 18
local EFFECT_LIFESTEAL = 19
local EFFECT_MAGICKASTEAL = 20
local EFFECT_MAIM = 21
local EFFECT_MANGLE = 22
local EFFECT_MENDING = 23
local EFFECT_PROPHECY = 24
local EFFECT_PROTECTION = 25
local EFFECT_RESOLVE = 26
local EFFECT_SAVAGERY = 27
local EFFECT_SLAYER = 28
local EFFECT_SORCERY = 29
local EFFECT_TIMIDITY = 30
local EFFECT_TOUGHNESS = 31
local EFFECT_UNCERTAINTY = 32
local EFFECT_VITALITY = 33
local EFFECT_VULNERABILITY = 34
local EFFECT_VEXATION = 35

local minorEffects, majorEffects                              -- populated at the end of file due to how large they are (legibility reasons)

Srendarr.BahseiData = { ID = 154691, nSet = 587, pSet = 591 } -- global values for Bahsei's Mania to make it easier to update if data changes (Phinix)
Srendarr.POrderData = { ID = 147414, set = 575 }              -- global values for Pale Order to make it easier to update if data changes (Phinix)
Srendarr.AnthelmirData = { ID = 215119, pAxe = 215157, nTimer = 0 }

-- special table for fake Off Balance Immunity tracking (Phinix)
Srendarr.OffBalance = { ID = 249901, CD = 15, nameID = 134599, obN1 = zo_strformat('<<t:1>>', GetAbilityName(137312)), obN2 = zo_strformat('<<t:1>>', GetAbilityName(130139)), icon = '/esoui/art/icons/achievement_030.dds' }

-- special case aura ID's for easy access in case game update changes them (Phinix)

Srendarr.specialGallop = 63569
Srendarr.screamingBuff = 87663
Srendarr.screamingEmpower = 178330
Srendarr.cruxId = 184220
Srendarr.volatileFam = 88933
Srendarr.cruxCurrent = 0
Srendarr.CombatState = 0
Srendarr.crystalFragments = ZOSName(46324, 1) -- special case for merging frags procs
Srendarr.exhaustingFatecarver = ZOSName(193397, 1)
Srendarr.crystalFragmentsPassive = 46327      -- with the general proc system
Srendarr.crystalFragmentsProc = false         -- tracks when crystal fragments proc is active

Srendarr.keepAuras = {}


-- ------------------------
-- GENERAL DATABASE
-- ------------------------
local alteredAuraIcons =
{                                                               -- used to alter the default icon for selected auras
    [135397] = [[Srendarr/Icons/Vamp_Stage1.dds]],              -- Stage 1 Vampirism
    [135399] = [[Srendarr/Icons/Vamp_Stage2.dds]],              -- Stage 2 Vampirism
    [135400] = [[Srendarr/Icons/Vamp_Stage3.dds]],              -- Stage 3 Vampirism
    [135402] = [[Srendarr/Icons/Vamp_Stage4.dds]],              -- Stage 4 Vampirism
    [23392]  = [[/esoui/art/icons/ability_mage_042.dds]],       -- Altmer Glamour
    [31272]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Arrow Spray Rank I
    [40760]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Arrow Spray Rank II
    [40763]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Arrow Spray Rank III
    [40766]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Arrow Spray Rank IV
    [38706]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Bombard Rank I
    [40770]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Bombard Rank II
    [40774]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Bombard Rank III
    [40778]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Bombard Rank IV
    [38702]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Acid Spray Rank I
    [40784]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Acid Spray Rank II
    [40788]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Acid Spray Rank III
    [40792]  = [[/esoui/art/icons/ability_debuff_snare.dds]],   -- Acid Spray Rank IV
    [59533]  = [[Srendarr/Icons/DSphere_Arcane.dds]],           -- Arcane Engine Guardian
    [59543]  = [[Srendarr/Icons/DSphere_Healthy.dds]],          -- Healthy Engine Guardian
    [59540]  = [[Srendarr/Icons/DSphere_Robust.dds]],           -- Robust Engine Guardian
    [147140] = [[/esoui/art/icons/ability_mage_051.dds]],       -- Voidcaller Proc
    [127284] = [[/esoui/art/icons/ability_warrior_018.dds]],    -- Ravager Proc
    [147692] = [[/esoui/art/icons/death_recap_fire_aoe.dds]],   -- Explosive Rebuke bomb
    [159244] = [[/esoui/art/icons/death_recap_shock_aoe2.dds]], -- Thinder Caller Proc
    [73296]  = [[/esoui/art/icons/ability_mage_004.dds]],       -- Winterborn Snare
    [160445] = [[/esoui/art/icons/ability_mage_047.dds]],       -- Palinal's Wrath
}

local alteredAuraData =
{                                                               -- used to alter various data for selected auras
    -- Warden Healing Seed (and morphs) - Game reports incorrect duration (?).
    [85578] = { unitTag = nil, duration = 6 },                  -- Healing Seed
    [85840] = { unitTag = nil, duration = 6 },                  -- Budding Seeds
    [85845] = { unitTag = nil, duration = 6 },                  -- Corrupting Pollen
    -- Alliance War Caltrops (and morphs)
    [33376] = { unitTag = nil, duration = ATd(33376) + 1 },     -- Caltrops
    [40255] = { unitTag = nil, duration = ATd(40255) + 1 },     -- Anti-Cavalry Caltrops
    [40242] = { unitTag = nil, duration = ATd(40242) + 1 },     -- Razor Caltrops
    -- Sorcerer Haunting Curse 2nd Proc
    [89491] = { unitTag = 'groundaoe', duration = ATd(89491) }, -- Haunting Curse
    -- Warden Bugs
    [86009] = { unitTag = 'groundaoe', duration = 3 },          -- Scorch
    [178020] = { unitTag = 'groundaoe', duration = 6 },         -- Scorch
    [86015] = { unitTag = 'groundaoe', duration = 3 },          -- Deep Fissure
    [178028] = { unitTag = 'groundaoe', duration = 6 },         -- Deep Fissure
    [146919] = { unitTag = 'groundaoe', duration = 3 },         -- Subterranean Assault
}

local barCastAuras =
{                                                                                              -- used to spawn fake auras to handle mismatch of information provided by the API to what user's want|need
    -- Nightblade Summon Shade (and morphs)
    [ZOSName(33211, 1)] = { unitTag = 'player', duration = ATd(33211), abilityID = 33211 },    -- Summon Shade
    [ZOSName(35434, 1)] = { unitTag = 'player', duration = ATd(35434), abilityID = 35434 },    -- Dark Shades
    [ZOSName(35441, 1)] = { unitTag = 'player', duration = ATd(35441), abilityID = 35441 },    -- Shadow Image
    -- Sorcerer Daedric Curse (and morphs)						
    [ZOSName(24326, 1)] = { unitTag = 'groundaoe', duration = ATd(24326), abilityID = 24326 }, -- Daedric Curse
    [ZOSName(24328, 1)] = { unitTag = 'groundaoe', duration = ATd(24328), abilityID = 24328 }, -- Daedric Prey
    [ZOSName(24330, 1)] = { unitTag = 'groundaoe', duration = 3.5, abilityID = 24330 },        -- Haunting Curse (lower rank?)
    [ZOSName(24331, 1)] = { unitTag = 'groundaoe', duration = 3.5, abilityID = 24331 },        -- Haunting Curse
}

local castBarDelayAuras =
{ -- need a separate table for auras that require using the target glyph system otherwise timers start when targeting begins not when actual casting starts (Phinix)
    -- also used for any ability cast with a cast time to account for the weapon unsheathe animation when casting with weapons sheathed so cast bar doesn't start early
    -- 	sAura 0 = no aura
    -- Arcanist
    [185805] = { unitTag = 'groundaoe', duration = 4.5, result = 2240 }, -- Fatecarver
    [183122] = { unitTag = 'groundaoe', duration = 4.5, result = 2240 }, -- Exhausting Fatecarver
    [186366] = { unitTag = 'groundaoe', duration = 4.5, result = 2240 }, -- Pragmatic Fatecarver
    [183537] = { unitTag = 'groundaoe', duration = 4.5, result = 2240 }, -- Remedy Cascade
    [186193] = { unitTag = 'groundaoe', duration = 4.5, result = 2240 }, -- Cascading Fortune
    [186200] = { unitTag = 'groundaoe', duration = 4.5, result = 2240 }, -- Curative Surge
    -- Sorcerer
    [43714]  = { unitTag = 'player', duration = 0.8, result = 2200 },    -- Crystal Shard
    [46324]  = { unitTag = 'player', duration = 0.8, result = 2200 },    -- Crystal Fragments
    [24584]  = { unitTag = 'player', duration = 1, result = 2200 },      -- Dark Exchange
    [24595]  = { unitTag = 'player', duration = 1, result = 2200 },      -- Dark Deal
    [24589]  = { unitTag = 'player', duration = 1, result = 2200 },      -- Dark Conversion
    [23304]  = { unitTag = 'player', duration = 1.5, result = 2200 },    -- Summon Unstable Familiar
    [23319]  = { unitTag = 'player', duration = 1.5, result = 2200 },    -- Summon Unstable Clannfear
    [23316]  = { unitTag = 'player', duration = 1.5, result = 2200 },    -- Summon Volatile Familiar
    [24613]  = { unitTag = 'player', duration = 1.5, result = 2200 },    -- Summon Winged Twilight
    [24636]  = { unitTag = 'player', duration = 1.5, result = 2200 },    -- Summon Twilight Tormentor
    [24639]  = { unitTag = 'player', duration = 1.5, result = 2200 },    -- Summon Twilight Matriarch
    -- Nightblade
    [33398]  = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Death Stroke
    [113105] = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Incapacitating Strike
    [36514]  = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Soul Harvest
    [18342]  = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Teleport Strike
    [25493]  = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Lotus Fan
    [25484]  = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Ambush
    [25091]  = { unitTag = 'player', duration = 0.5, result = 2200 },    -- Soul Shred
    [35508]  = { unitTag = 'player', duration = 0.5, result = 2200 },    -- Soul Siphon
    [35460]  = { unitTag = 'player', duration = 0.5, result = 2200 },    -- Soul Tether
    -- Templar
    [22138]  = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Radial Sweep
    [22144]  = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Everlasting Sweep
    [22139]  = { unitTag = 'player', duration = 0.4, result = 2200 },    -- Crescent Sweep
    [26114]  = { unitTag = 'player', duration = 0.8, result = 2240 },    -- Puncturing Strikes
    [26792]  = { unitTag = 'player', duration = 0.8, result = 2240 },    -- Biting Jabs
    [26797]  = { unitTag = 'player', duration = 0.8, result = 2240 },    -- Puncturing Sweep
    [22057]  = { unitTag = 'player', duration = 0.8, result = 2200 },    -- Solar Flare
    [22110]  = { unitTag = 'player', duration = 0.8, result = 2200 },    -- Dark Flare
    [63029]  = { unitTag = 'player', duration = 1.8, result = 2240 },    -- Radiant Destruction
    [63044]  = { unitTag = 'player', duration = 1.8, result = 2240 },    -- Radiant Glory
    [63046]  = { unitTag = 'player', duration = 1.8, result = 2240 },    -- Radiant Oppression
    [22223]  = { unitTag = 'groundaoe', duration = 4, result = 2200 },   -- Rite of Passage
    [22229]  = { unitTag = 'groundaoe', duration = 4, result = 2200 },   -- Remembrance
    [22226]  = { unitTag = 'groundaoe', duration = 8, result = 2200 },   -- Practiced Incantation
    -- Warden
    [85982]  = { unitTag = 'player', duration = 2.5, result = 2200 },    -- Feral Guardian
    [85986]  = { unitTag = 'player', duration = 2.5, result = 2200 },    -- Eternal Guardian
    [85990]  = { unitTag = 'player', duration = 2.5, result = 2200 },    -- Wild Guardian
    -- Psijic
    [103488] = { unitTag = 'groundaoe', duration = 2, result = 2240 },   -- Time Stop
    [104059] = { unitTag = 'groundaoe', duration = 2, result = 2240 },   -- Borrowed Time
    [103706] = { unitTag = 'player', duration = 1.3, result = 2200 },    -- Channeled Acceleration
    -- 2H Uppercut
    [28279]  = { unitTag = 'player', duration = 0.8, result = 2200 },    -- Uppercut
    [38814]  = { unitTag = 'player', duration = 0.8, result = 2200 },    -- Dizzying Swing
    [38807]  = { unitTag = 'player', duration = 0.8, result = 2200 },    -- Wrecking Blow
    -- Bow Rapid Fire Ultimate
    [83465]  = { unitTag = 'player', duration = 4, result = 2240 },      -- Rapid Fire
    [85257]  = { unitTag = 'player', duration = 4, result = 2240 },      -- Toxic Barrage
    -- Soul Strike Ultimate
    [39270]  = { unitTag = 'player', duration = 5, result = 2240 },      -- Soul Strike
    [40420]  = { unitTag = 'player', duration = 6, result = 2240 },      -- Soul Assault
    [40414]  = { unitTag = 'player', duration = 5, result = 2240 },      -- Shatter Soul
    -- Alliance War
    [61487]  = { unitTag = 'player', duration = 1, result = 2200 },      -- Magicka Detonation
    [61491]  = { unitTag = 'player', duration = 1, result = 2200 },      -- Inevitable Detonation
    -- Scribing
    [217625] = { unitTag = 'player', duration = 2, result = 2240 },      -- Torchbearer
    [217228] = { unitTag = 'player', duration = 2, result = 2200 },      -- Elemental Explosion
    [220542] = { unitTag = 'player', duration = 1.5, result = 2200 },    -- Trample
    [217203] = { unitTag = 'player', duration = 0.6, result = 2200 },    -- Smash
}

local debuffAuras =
{                    -- used to fix game bug where certain debuffs (mostly set procs) are tracked as buffs instead
    [60416] = true,  -- Sunderflame special case to show properly as debuff
    [81519] = true,  -- Infallible Aether special case to show properly as debuff
    [69143] = true,  -- Dodge Fatigue
    [51392] = true,  -- Bolt Escape Fatigue
    [147692] = true, -- Explosive Rebuke bomb
}

local alternateAura =
{                                                                  -- used by the consolidate multi-aura function
    [26213] = { altName = ZOSName(26207, 1), unitTag = 'player' }, -- Display "Restoring Aura" instead of all three auras
    [76420] = { altName = ZOSName(34080, 1), unitTag = 'player' }, -- Display "Flames of Oblivion" instead of both auras
}

local procAbilityNames =
{                                -- using names rather than IDs to ease matching multiple IDs to multiple different IDs
    [ZOSName(46327, 1)] = false, -- Crystal Fragments -- special case, controlled by the actual aura
    [ZOSName(61902, 1)] = true,  -- Grim Focus
    [ZOSName(61919, 1)] = true,  -- Merciless Resolve
    [ZOSName(61927, 1)] = true,  -- Relentless Focus
    [ZOSName(23903, 1)] = true,  -- Power Lash
    [ZOSName(62549, 1)] = true,  -- Deadly Throw
}

local toggledAuras =
{                     -- there is a separate abilityID for every rank of a skill
    -- Sorcerer pets (GetToggled dump; exclude pet-passive / spectral-arrow name collisions)
    [23316] = true,   -- Summon Volatile Familiar
    [77182] = true,   -- Summon Volatile Familiar
    [23304] = true,   -- Summon Unstable Familiar
    [108840] = true,  -- Summon Unstable Familiar
    [23319] = true,   -- Summon Unstable Clannfear
    [76076] = true,   -- Summon Unstable Clannfear
    [80161] = true,   -- Summon Unstable Clannfear
    [24613] = true,   -- Summon Winged Twilight
    [24639] = true,   -- Summon Twilight Matriarch
    [80066] = true,   -- Summon Twilight Matriarch
    [80155] = true,   -- Summon Twilight Matriarch
    [24636] = true,   -- Summon Twilight Tormentor
    -- Support / toggles
    [61529] = true,   -- Stalwart Guard
    [61536] = true,   -- Mystic Guard
    [36908] = true,   -- Leeching Strikes
    [61511] = true,   -- Guard
    [78338] = true,   -- Guard
    [81415] = true,   -- Guard
    [81420] = true,   -- Guard
    [46712] = true,   -- Bound Armor
    [56797] = true,   -- Bound Armor
    [24165] = true,   -- Bound Armaments
    [46711] = true,   -- Bound Aegis
    [56796] = true,   -- Bound Aegis
    [916007] = true,  -- Sample Aura (FAKE)
    [916008] = true,  -- Sample Aura (FAKE)
}

local specialNames =
{ -- special database for name-swapping custom auras the game doesn't track or name correctly
    -- Changes Kena 1st hit tracker from "Molag Kena" to "Molag Kena 1st Hit"
    [66808]  = { name = ZOSName(66808, 1) .. L.MolagKenaHit1 },
    -- Changes Sorcerer Summon Volatile Familiar active ability "to Volatile Familiar AOE"
    [88933]  = { name = L.VolatileAOE },
    -- Swaps Aggressive Warhorn Major Force to say "Major Force"
    [46522]  = { name = ZOSName(40225, 1) },
    [46533]  = { name = ZOSName(40225, 1) },
    [46536]  = { name = ZOSName(40225, 1) },
    [46539]  = { name = ZOSName(40225, 1) },
    -- Swaps Templar Sun Fire (and morphs) self-buff name from "Sun Fire" to "Major Savagery"
    -- U51: Prophecy was removed and replaced with Savagery. Ability IDs remain named "Sun Fire"
    -- so the display name is sourced from 61667 (generic Major Savagery). BuffType for these IDs
    -- still maps through the deprecated PROPHECY slot; ignoreEffects keeps them in majorEffects.
    [21726]  = { name = ZOSName(61667, 1) },
    [24160]  = { name = ZOSName(61667, 1) },
    [24167]  = { name = ZOSName(61667, 1) },
    [24171]  = { name = ZOSName(61667, 1) },
    [21729]  = { name = ZOSName(61667, 1) },
    [24174]  = { name = ZOSName(61667, 1) },
    [24177]  = { name = ZOSName(61667, 1) },
    [24180]  = { name = ZOSName(61667, 1) },
    [21732]  = { name = ZOSName(61667, 1) },
    [24184]  = { name = ZOSName(61667, 1) },
    [24187]  = { name = ZOSName(61667, 1) },
    [24195]  = { name = ZOSName(61667, 1) },
    -- Changes duplicate Bombard snare effect to "Snare 40%"
    [38706]  = { name = ZOSName(48502, 1) .. ' 40%' }, -- Bombard Rank I
    [40770]  = { name = ZOSName(48502, 1) .. ' 40%' }, -- Bombard Rank II
    [40774]  = { name = ZOSName(48502, 1) .. ' 40%' }, -- Bombard Rank III
    [40778]  = { name = ZOSName(48502, 1) .. ' 40%' }, -- Bombard Rank IV
    -- Cooldown tracker proc auras reverted to original name rather than copying cooldown name (Phinix)
    [135926] = { name = ZOSName(135926, 1) },          -- Vrol's Command Major Aegis effect
    [137989] = { name = ZOSName(137989, 1) },          -- Vrol's Command (Perfected) Major Aegis effect
    [147417] = { name = ZOSName(147417, 1) },          -- Claw of Yolnakhriin Major Minor Courage
    [159237] = { name = ZOSName(159237, 1) },          -- Scorion's Feast Imbued Aura
    [71193]  = { name = ZOSName(71193, 1) },           -- Para Bellum
    [106804] = { name = ZOSName(106804, 1) },          -- Nocturnal's Heal
    [59590]  = { name = ZOSName(59591, 1) },           -- Bogdan Totem
    [151033] = { name = ZOSName(151033, 1) },          -- Encratis' Behemoth
    [141905] = { name = ZOSName(141905, 1) },          -- Lady Thorn
    [59497]  = { name = ZOSName(59498, 1) },           -- Mephala's Web
    -- Combines aura names to make "Stonekeeper Charging"
    [116839] = { name = ZOSName(116846, 1) .. ' ' .. ZOSName(116839, 1) },
    -- Changes "Nikulas' Heavy Armor" to "Nikulas' Resolve"
    [160263] = { name = ZOSName(160262, 1) },
}

local stackingAuras =
{ -- used to track stacks on auras like Hawk Eye (Phinix)
    -- rTimer means each tick resets the stack timer
    -- proc is the stack number the aura will cause an additional effect if any
    -- picon is an icon to change to if the aura has a proc as described above (this is optional)
    -- Weapon & Armor Sets
    -- 	[111387]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Blood Moon																	*
    -- 	[155176]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Death Dealer's Fete Mythic													*
    -- 	[129407]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Dragonguard Elite															*
    -- 	[155150]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Harpooner's Wading Kilt Mythic (Hunter's Focus)								*
    -- 	[133505]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Kjalnar's Nightmare (Monster Set)											*
    -- 	[127280]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Ravager (PVP)																*
    -- 	[126535]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Renald's Resolve Set															*
    -- 	[51176]		= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Two-Fanged/Twice-Fanged Snake/Serpent Set									*
    -- 	[116742]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Tzogvin's Warband Set														*
    -- 	[147141]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Voidcaller																	*
    -- 	[167058]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Spriggan’s Vigor																*
    -- 	[110118]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Mantle of Siroria (uses same for Perfected)									*
    -- 	[135950]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Yandir's Might (Giant's Endurance)											*
    -- 	[50978]		= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Berserking Warrior (advancing yokeda)										*
    -- 	[107203]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Arms of Relequen (same for Perfected)										*
    -- 	[100306]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Asylum Destruction Staff Concentrated Force									*
    -- 	[99989]		= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Asylum Destruction Staff Concentrated Force (Perfected)						*
    -- 	[152673]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Baron Zaudrus (Monster Set)													*
    -- 	[145199]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Stone Husk (Monster Set) "Husk Drain" stacking aura							*
    -- 	[116839]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Stonekeeper Monster Set														*
    -- 	[147701]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Frenzied Momentum (Vateshran 2H Weapon)										*
    -- 	[79421]		= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Galerion's Revenge															*
    -- 	[155390]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Glorgoloch the Destroyer (Monster Set)										*
    -- 	[137126]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Dragon's Appetite															*
    -- 	[150750]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Kinras's Wrath																*
    -- 	[159262]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Grisly Gourmet																*
    -- 	[159372]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Realm Shaper																	*
    -- 	[163376]	= {start = 2,	proc = 0, picon = nil, base = true, rTimer = true},		-- Belharaza's Temper															*
    -- 	[79200]		= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Sithis Touch																	*
    -- 	[129442]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Senchal's Duty																*
    -- 	[160262]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Nikulas' Resolve																*
    -- 	[126631]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Blight Seed																	*
    -- 	[99204]		= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Mechanical Acuity															*
    -- 	[160443]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Palinal's Wrath																*
    -- 	[172732]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Dov-Rha Sabatons Mythic														*
    -- 	[181117]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Bastion of the Draoife														*
    -- 	[176851]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Grave Inevitability															*
    -- 	[188146]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Roksa the Warped																*
    -- 	[188758]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Shell Splitter																*
    -- 	[176055]	= {start = 1,	proc = 0, picon = nil, base = true, rTimer = true},		-- Sergeant's Mail																*
    -- Special Game Mechanics
    [146631] = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Vateshran Fortitude Remnant
    [146637] = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Vateshran Mysticism Remnant
    [146635] = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Vateshran Endurance Remnant
    -- Abilities & Passives
    [51392]  = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Bolt Escape Fatigue
    [69143]  = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Dodge Fatigue
    [122658] = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Dragon Knight Seething Fury
    [78854]  = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Hawk Eye (Bow) Lvl 1
    [78855]  = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Hawk Eye (Bow) Lvl 2
    [103820] = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Psijic Spell Orb
    [130293] = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Sorcerer Bound Armaments
    [76950]  = { start = 1, proc = 0, picon = nil, base = true, rTimer = true },  -- Warrior's Fury
    [128494] = { start = 20, proc = 0, picon = nil, base = true, rTimer = true }, -- Warrior's Fury

    -- Special
    [100474] = { start = 1, proc = 5, picon = '/esoui/art/icons/ability_mage_049.dds', base = true, rTimer = true }, -- Chaotic Whirlwind (Asylum Dual Wield)		*
    [136123] = { start = 1, proc = 0, picon = nil, base = true, rTimer = false },                                    -- Thrassian Stranglers Mythic													*
    -- Vampire Frenzy
    [172418] = { start = 0, proc = 0, picon = nil, base = true, rTimer = false },                                    -- Blood Frenzy
    [172648] = { start = 0, proc = 0, picon = nil, base = true, rTimer = false },                                    -- Sated Fury
    [134166] = { start = 0, proc = 0, picon = nil, base = true, rTimer = false },                                    -- Simmering Frenzy
    -- Warden Screaming Cliffracer
    [87663]  = { start = 1, proc = 0, picon = nil, base = true, rTimer = false },
    [178330] = { start = 4, proc = 0, picon = nil, base = true, rTimer = false },
}

local ignoreStacks =
{ -- table of auras that send stack information but do not actually have stacks (Major Gallop for example) (Phinix)
    -- 	[63569] = true, -- Major Gallop
}

-- ------------------------
-- COMBAT_EVENT FILTERS
-- ------------------------
local releaseTriggers =
{ -- special case used to detect release events which should cancel active auras
    -- nCE means this trigger is detected in normal aura change event and doesn't need combat event registration (Phinix)
    -- Defensive Rune release
    [24576] = { release = 24574 },    -- Defensive Rune I Release
    [62294] = { release = 24574 },    -- Defensive Rune II Release
    [62298] = { release = 24574 },    -- Defensive Rune III Release
    [62299] = { release = 24574 },    -- Defensive Rune IV Release
    -- Nightblade Grim Focus (and morphs)
    [61902] = { release = 122585 },   -- Grim Focus			61902
    [61919] = { release = 122586 },   -- Merciless Resolve	61919
    [61927] = { release = 122587 },   -- Relentless Focus		61927
    -- Essence Thief
    [70290] = { release = 67308 },    -- Essence Thief pool collection
    -- Explosive Rebuke
    [147694] = { release = 147692 },  -- Explosive Rebuke heavy attack detonation
    -- Beast Trap (target dies cancel AOE)
    [35753] = { release = 35750 },    -- Trap Beast
    [40384] = { release = 40382 },    -- Barbed Trap
    [40374] = { release = 40372 },    -- Lightweight Beast Trap
    -- Warden Bugs
    [86009] = { release = 178020 },   -- Scorch
    [178020] = { release = 86009 },   -- Scorch
    [86015] = { release = 178028 },   -- Deep Fissure
    [178028] = { release = 86015 },   -- Deep Fissure
    [86019] = { release = 146919 },   -- Subterranean Assault
    [146919] = { release = 86019 },   -- Subterranean Assault
    -- Fire Rune (rune triggered cancel AOE)
    [31633] = { release = 31632 },    -- Fire Rune
    [40467] = { release = 40465 },    -- Scalding Rune
    [40472] = { release = 40470 },    -- Volcanic Rune
    -- Grisly Gourmet Sweetroll
    [159298] = { release = 159289 },  -- Consumption
    -- Scorion's Feast
    [159236] = { release = 159237 },  -- Overflow Aura
    -- Vengeful Soul (Sul-Xan's Torment)
    [154737] = { release = 154720 },  -- Soul Collected
    -- Foolkiller
    [151135] = { release = 4151126 }, -- Shield pop
    -- Grave Strake
    [113237] = { release = 113181 },  -- Collection
    [113185] = { release = 113181 },  -- Collection (backup)
    -- Haven of Ursus
    [111440] = { release = 111442 },  -- Haven of Ursus synergy activation
    [112414] = { release = 4111442 }, -- Haven of Ursus (test)
    -- Blastbones
    [115608] = { release = 114863 },  -- Blastbones
    [117757] = { release = 117750 },  -- Stalking Blastbones
    [117715] = { release = 117691 },  -- Blighted Blastbones
    -- Screaming Cliffracer
    [178330] = { release = 87663, nCE = true },
}

local specialRelease =
{                    -- only release when Combat Event result is type gained (Phinix)
    [86009] = true,  -- Scorch
    [86015] = true,  -- Deep Fissure
    [86019] = true,  -- Subterranean Assault
    [178020] = true, -- Scorch
    [178028] = true, -- Deep Fissure
    [146919] = true, -- Subterranean Assault
}

local enchantProcs =
{                                                                                           -- used to spawn fake auras to handle enchant procs the game doesn't track
    -- Weapon enchant procs
    [21230] = { duration = ATd(21230), icon = '/esoui/art/icons/ability_rogue_006.dds' },   -- Weapon/spell power enchant (Berserker)
    [17906] = { duration = ATd(17906), icon = '/esoui/art/icons/ability_armor_001.dds' },   -- Reduce spell/physical resist (Crusher)
    [21578] = { duration = ATd(21578), icon = '/esoui/art/icons/ability_healer_029.dds' },  -- Damage shield enchant (Hardening)
    [17945] = { duration = ATd(17945), icon = '/esoui/art/icons/ability_warrior_013.dds' }, -- Reduce target damage (Weakening)
}

local fakeTargetDebuffs =
{                                                                                                          -- used to spawn fake auras to handle invisible debuffs on current target
    -- Special case for Fighters Guild Beast Trap (and morph) tracking
    [35754] = { duration = ATd(35754), icon = '/esoui/art/icons/ability_fightersguild_004.dds' },          -- Trap Beast I
    [42712] = { duration = ATd(42712), icon = '/esoui/art/icons/ability_fightersguild_004.dds' },          -- Trap Beast II
    [42719] = { duration = ATd(42719), icon = '/esoui/art/icons/ability_fightersguild_004.dds' },          -- Trap Beast III
    [42726] = { duration = ATd(42726), icon = '/esoui/art/icons/ability_fightersguild_004.dds' },          -- Trap Beast IV
    [40389] = { duration = ATd(40389), icon = '/esoui/art/icons/ability_fightersguild_004_a.dds' },        -- Rearming Trap I
    [42731] = { duration = ATd(42731), icon = '/esoui/art/icons/ability_fightersguild_004_a.dds' },        -- Rearming Trap II
    [42741] = { duration = ATd(42741), icon = '/esoui/art/icons/ability_fightersguild_004_a.dds' },        -- Rearming Trap III
    [42751] = { duration = ATd(42751), icon = '/esoui/art/icons/ability_fightersguild_004_a.dds' },        -- Rearming Trap IV
    [40376] = { duration = ATd(40376), icon = '/esoui/art/icons/ability_fightersguild_004_b.dds' },        -- Lightweight Beast Trap I
    [42761] = { duration = ATd(42761), icon = '/esoui/art/icons/ability_fightersguild_004_b.dds' },        -- Lightweight Beast Trap II
    [42768] = { duration = ATd(42768), icon = '/esoui/art/icons/ability_fightersguild_004_b.dds' },        -- Lightweight Beast Trap III
    [42775] = { duration = ATd(42775), icon = '/esoui/art/icons/ability_fightersguild_004_b.dds' },        -- Lightweight Beast Trap IV
    -- Wise Mage special case for target vulnerability proc
    [51434] = { duration = ATd(51434), icon = '/esoui/art/icons/ability_debuff_minor_vulnerability.dds' }, -- Wise Mage
    -- AOE/snare effects
    [38834] = { duration = ATd(69950), icon = '/esoui/art/icons/death_recap_magic_aoe.dds' },              -- Desecrated Ground (Zombie Snare)
    [60402] = { duration = ATd(60402), icon = '/esoui/art/icons/ability_warrior_015.dds' },                -- Ensnare
    [39060] = { duration = ATd(39060), icon = '/esoui/art/icons/ability_debuff_root.dds' },                -- Bear Trap
    [63168] = { duration = ATd(63168), icon = '/esoui/art/icons/ability_dragonknight_010.dds' },           -- Guard: Cage Talons
}

local cdTex =
{ -- used just to save space so abilityCooldowns and specialProcs tables are more readable (Phinix)
    -- /script d(GetAbilityIcon(166731))
    -- abilityCooldowns icons
    [147692] = '/esoui/art/icons/death_recap_fire_aoe.dds',
    [74106]  = '/esoui/art/icons/ability_mage_066.dds',
    [71647]  = '/esoui/art/icons/death_recap_cold_aoe.dds',
    [121914] = '/esoui/art/icons/pet_251_coldharbourbantam.dds',
    [134104] = '/esoui/art/icons/ability_healer_002.dds',
    [164087] = '/esoui/art/icons/gear_clockwork_medium_head_a.dds',
    [113092] = '/esoui/art/icons/death_recap_oblivion.dds',
    [92774]  = '/esoui/art/icons/ability_mage_022.dds',
    [92775]  = '/esoui/art/icons/ability_mage_022.dds',
    [92771]  = '/esoui/art/icons/ability_mage_022.dds',
    [92773]  = '/esoui/art/icons/ability_mage_022.dds',
    [92776]  = '/esoui/art/icons/ability_mage_022.dds',
    [133493] = '/esoui/art/icons/death_recap_bleed.dds',
    [84277]  = '/esoui/art/icons/gear_mazzatun_heavy_head_a.dds',
    [111386] = '/esoui/art/icons/store_werewolfbite_01.dds',
    [102027] = '/esoui/art/icons/death_recap_fire_ranged.dds',
    [102032] = '/esoui/art/icons/death_recap_cold_ranged.dds',
    [102033] = '/esoui/art/icons/death_recap_disease_ranged.dds',
    [102034] = '/esoui/art/icons/death_recap_shock_ranged.dds',
    [159291] = '/esoui/art/icons/ability_debuff_minor_fracture.dds',
    [97538]  = '/esoui/art/icons/gear_falkreath_light_head_a.dds',
    [67298]  = '/esoui/art/icons/ability_mage_043.dds',
    [99144]  = '/esoui/art/icons/ability_mage_011.dds',
    [97908]  = '/esoui/art/icons/ability_mage_038.dds',
    [84354]  = '/esoui/art/icons/ability_undaunted_003.dds',
    [111442] = '/esoui/art/icons/ability_warden_018_c.dds',
    [112414] = '/esoui/art/icons/ability_mage_047.dds',
    [126924] = '/esoui/art/icons/ability_healer_031.dds',
    [117666] = '/esoui/art/icons/ability_mage_050.dds',
    [97627]  = '/esoui/art/icons/u15dlc_bullet_5220.dds',
    [142816] = '/esoui/art/icons/achievement_u26_skyrim_werewolfdevour100.dds',
    [34813]  = '/esoui/art/icons/ability_mage_007.dds',
    [116805] = '/esoui/art/icons/ability_mage_050.dds',
    [57206]  = '/esoui/art/icons/ability_healer_017.dds',
    [97714]  = '/esoui/art/icons/gear_falkreath_medium_head_a.dds',
    [102106] = '/esoui/art/icons/ability_mage_019.dds',
    [159279] = '/esoui/art/icons/death_recap_melee_basic.dds',
    [159380] = '/esoui/art/icons/death_recap_magic_ranged.dds',
    [159244] = '/esoui/art/icons/ability_skeevatonshockfield.dds',
    [101970] = '/esoui/art/icons/ability_buff_major_endurance.dds',
    [57163]  = '/esoui/art/icons/ability_mage_044.dds',
    [151135] = '/esoui/art/icons/ability_mage_062.dds',
    [67205]  = '/esoui/art/icons/ability_rogue_022.dds',
    [85978]  = '/esoui/art/icons/ability_healer_029.dds',
    [59590]  = '/esoui/art/icons/gear_undaunted_titan_head_a.dds',
    [81069]  = '/esoui/art/icons/gear_undaunted_strangler_heavy_head_a.dds',
    [97882]  = '/esoui/art/icons/gear_undauntedminotaur_a.dds',
    [97855]  = '/esoui/art/icons/gear_undaunted_ironatronach_head_a.dds',
    [126687] = '/esoui/art/icons/ability_healer_019.dds',
    [80527]  = '/esoui/art/icons/death_recap_shock_aoe.dds',
    [141905] = '/esoui/art/icons/ability_u23_bloodball_chokeonit.dds',
    [59587]  = '/esoui/art/icons/gear_undauntedgrievoust_head_a.dds',
    [161527] = '/esoui/art/icons/ability_buff_minor_resolve.dds',
    [59568]  = '/esoui/art/icons/gear_undauntedharvester_head_a.dds',
    [59508]  = '/esoui/art/icons/gear_undaunted_daedroth_head_a.dds',
    [59594]  = '/esoui/art/icons/ability_mage_051.dds',
    [98421]  = '/esoui/art/icons/ability_rogue_022.dds',
    [160839] = '/esoui/art/icons/gear_undauntedspider_head_a.dds',
    [80545]  = '/esoui/art/icons/gear_undauntedlamia_head_a.dds',
    [81036]  = '/esoui/art/icons/gear_undauntedcenturion_head_a.dds',
    [80954]  = '/esoui/art/icons/gear_undauntedclannfear_head_a.dds',
    [59497]  = '/esoui/art/icons/gear_undauntedspiderdaedra_head_a.dds',
    [116881] = '/esoui/art/icons/achievement_update16_025.dds',
    [80523]  = '/esoui/art/icons/gear_undauntedstormatronach_head_a.dds',
    [102093] = '/esoui/art/icons/gear_undaunted_fanglair_head_a.dds',
    [80487]  = '/esoui/art/icons/gear_undaunted_hoarvordaedra_head_a.dds',
    [106868] = '/esoui/art/icons/ability_rogue_060.dds',
    [75691]  = '/esoui/art/icons/ability_mage_028.dds',
    [93308]  = '/esoui/art/icons/quest_head_monster_020.dds',
    [92982]  = '/esoui/art/icons/quest_head_monster_007.dds',
    [97806]  = '/esoui/art/icons/death_recap_fire_ranged.dds',
    [71664]  = '/esoui/art/icons/gear_orc_heavy_head_d.dds',
    [135659] = '/esoui/art/icons/ability_mage_013.dds',
    [34522]  = '/esoui/art/icons/ability_mage_026.dds',
    [163044] = '/esoui/art/icons/ability_mage_042.dds',
    [163060] = '/esoui/art/icons/ability_debuff_major_maim.dds',
    [163062] = '/esoui/art/icons/ability_debuff_major_maim.dds',
    [163064] = '/esoui/art/icons/ability_debuff_major_maim.dds',
    [163065] = '/esoui/art/icons/ability_debuff_major_maim.dds',
    [163066] = '/esoui/art/icons/ability_debuff_major_maim.dds',
    [159388] = '/esoui/art/icons/death_recap_magic_aoe.dds',
    [70492]  = '/esoui/art/icons/ability_mage_070.dds',
    [113382] = '/esoui/art/icons/ability_mage_063.dds',
    [115771] = '/esoui/art/icons/ability_warrior_027.dds',
    [111575] = '/esoui/art/icons/ability_warrior_020.dds',
    [51443]  = '/esoui/art/icons/ability_mage_014.dds',
    [136098] = '/esoui/art/icons/ability_healer_015.dds',
    [75814]  = '/esoui/art/icons/ability_mage_058.dds',
    [110067] = '/esoui/art/icons/ability_mage_062.dds',
    [135923] = '/esoui/art/icons/procs_006.dds',
    [107141] = '/esoui/art/icons/ability_mage_045.dds',
    [163375] = '/esoui/art/icons/mythic_ring_belharzas_band.dds',
    [75726]  = '/esoui/art/icons/ability_mage_067.dds',
    [166729] = '/esoui/art/icons/ability_healer_005.dds',
    [167402] = '/esoui/art/icons/ability_healer_009.dds',
    [167682] = '/esoui/art/icons/ability_mage_050.dds',
    [166782] = '/esoui/art/icons/death_recap_shock_ranged.dds',
    [167043] = '/esoui/art/icons/achievement_trial_cr_flavor_3.dds',
    [167052] = '/esoui/art/icons/achievement_trial_cr_flavor_2.dds',
    [172671] = '/esoui/art/icons/death_recap_cold_aoe.dds',
    [86019]  = '/esoui/art/icons/ability_warden_015_b.dds',
    [177678] = '/esoui/art/icons/ability_healer_011.dds',
    [176813] = '/esoui/art/icons/gear_terrorbear_head_a.dds',
    [175350] = '/esoui/art/icons/gear_hadolid_head_a.dds',
    [187904] = '/esoui/art/icons/ability_mage_022.dds',
    [187935] = '/esoui/art/icons/ability_healer_023.dds',
    [172055] = '/esoui/art/icons/u42_dun1_death_challenge.dds',
    [235835] = '/esoui/art/icons/death_recap_shock_dot_heavy.dds',
    [236163] = '/esoui/art/icons/u45_ability_dun1_ironteeth.dds',
    [237146] = '/esoui/art/icons/ability_warrior_017.dds',
    [236443] = '/esoui/art/icons/scribing_gryphonquest.dds',
    [236827] = '/esoui/art/icons/death_recap_poison_aoe.dds',
    [236654] = '/esoui/art/icons/ability_warrior_005.dds',
    [184634] = '/esoui/art/icons/ability_healer_031.dds',
    [215054] = '/esoui/art/icons/ability_warrior_029.dds',
    [214889] = '/esoui/art/icons/death_recap_fire_aoe.dds',





    -- specialProcs icons
    [113181] = '/esoui/art/icons/ability_mage_020.dds',
    [159289] = '/esoui/art/icons/crowncrate_sweetroll.dds',
    [159319] = '/esoui/art/icons/ability_buff_major_empower.dds',
    [49220]  = '/esoui/art/icons/ability_dragonknight_023.dds',
    [67308]  = '/esoui/art/icons/ability_mage_043.dds',
    [95932]  = '/esoui/art/icons/ability_templar_sun_strike.dds',
    [95956]  = '/esoui/art/icons/ability_templar_light_strike.dds',
    [44445]  = '/esoui/art/icons/ability_templarsun_thrust.dds',
    [126475] = '/esoui/art/icons/ability_2handed_003_a.dds',
    [46522]  = '/esoui/art/icons/ability_ava_003_a.dds',
    [46533]  = '/esoui/art/icons/ability_ava_003_a.dds',
    [46536]  = '/esoui/art/icons/ability_ava_003_a.dds',
    [46539]  = '/esoui/art/icons/ability_ava_003_a.dds',
    [63430]  = '/esoui/art/icons/ability_mageguild_005.dds',
    [63456]  = '/esoui/art/icons/ability_mageguild_005_b.dds',
    [63473]  = '/esoui/art/icons/ability_mageguild_005_a.dds',
    [32788]  = '/esoui/art/icons/ability_dragonknight_012_b.dds',
    [9237]   = '/esoui/art/icons/crafting_poisonmaking_reagent_fleshfly_larva.dds',
    [10392]  = '/esoui/art/icons/pet_mephalawasp.dds',
    [154720] = '/esoui/art/icons/u30_trial_soulrip.dds',
    [113312] = '/esoui/art/icons/ability_buff_major_empower.dds',
    [188546] = '/esoui/art/icons/death_recap_poison_dot_base.dds',
    [163359] = '/esoui/art/icons/ability_warrior_018.dds',
}

local aR =
{ -- table of action results for future proofing in rare case numbers change globals shouldn't (Phinix)
    [1073741840] = ACTION_RESULT_HOT_TICK,
    [2240]       = ACTION_RESULT_EFFECT_GAINED,
    -- 	[2245]			= ACTION_RESULT_EFFECT_GAINED_DURATION,
    -- 	[128]			= ACTION_RESULT_POWER_ENERGIZE,
    [16]         = ACTION_RESULT_HEAL,
    -- 	[32]			= ACTION_RESULT_CRITICAL_HEAL,
    -- 	[1]				= ACTION_RESULT_DAMAGE,
    -- 	[2]				= ACTION_RESULT_CRITICAL_DAMAGE,
}

local specialProcs =
{                                                                                                                            -- special cases requiring hidden EVENT_COMBAT_EVENT ID's to track properly
    -- Armor set procs	
    [145199] = { unitTag = nil, iH = nil, altTime = 0, altName = nil, bar = false, altIcon = nil },                          -- Stone Husk Monster Set "Husk Drain" stacking buff				*
    [109976] = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = false, altIcon = nil },                        -- Aegis of Galenwe													*
    [97896]  = { unitTag = nil, iH = nil, altTime = 0, altName = nil, bar = false, altIcon = nil },                          -- Domihaus AOE passive												*
    [106798] = { unitTag = nil, iH = nil, altTime = 6, altName = nil, bar = false, altIcon = nil },                          -- Sload's Embrace													*
    [113181] = { unitTag = 'groundaoe', iH = nil, altTime = 6, altName = nil, bar = false, altIcon = cdTex[113181] },        -- Grave Strake proc												*
    [159289] = { unitTag = 'groundaoe', iH = nil, altTime = 5, altName = nil, bar = false, altIcon = cdTex[159289] },        -- Grisly Gourmet Sweetroll Consumption								*
    [159319] = { unitTag = nil, iH = nil, altTime = 10, altName = ZOSName(61737, 1), bar = false, altIcon = cdTex[159319] }, -- Grisly Gourmet Empower proc										*
    [49220]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = false, altIcon = cdTex[49220] },       -- Crusader AOE proc												*
    [154720] = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = false, altIcon = cdTex[154720] },      -- Sul-Xan's TormentVengeful Soul AOE								*
    [67308]  = { unitTag = 'groundaoe', iH = nil, altTime = 5, altName = nil, bar = false, altIcon = cdTex[67308] },         -- Essence Thief proc pool AOE										*
    [113312] = { unitTag = nil, iH = nil, altTime = 3, altName = ZOSName(61737, 1), bar = false, altIcon = cdTex[113312] },  -- Might of the Lost Legion proc									*
    [172673] = { unitTag = 'groundaoe', iH = nil, altTime = 6, altName = nil, bar = false, altIcon = cdTex[172671] },        -- Whorl of the Depths AOE proc										*
    [163359] = { unitTag = 'groundaoe', iH = aR[2240], altTime = nil, altName = nil, bar = false, altIcon = cdTex[163359] }, -- Spaulders of Ruin												*

    -- Ability bar procs
    [95932]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = true, altIcon = cdTex[95932] },      -- Templar Spear Shards
    [95956]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = true, altIcon = cdTex[95956] },      -- Templar Luminous Shards
    [44445]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = true, altIcon = cdTex[44445] },      -- Templar Blazing Spear
    [46522]  = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = true, altIcon = cdTex[46522] },              -- Aggressive Warhorn Major Force Lvl 4
    [46533]  = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = true, altIcon = cdTex[46533] },              -- Aggressive Warhorn Major Force Lvl 4
    [46536]  = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = true, altIcon = cdTex[46536] },              -- Aggressive Warhorn Major Force Lvl 4
    [46539]  = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = true, altIcon = cdTex[46539] },              -- Aggressive Warhorn Major Force Lvl 4
    [63430]  = { unitTag = 'groundaoe', iH = nil, altTime = 13.4, altName = nil, bar = true, altIcon = cdTex[63430] },     -- Meteor
    [63456]  = { unitTag = 'groundaoe', iH = nil, altTime = 13.4, altName = nil, bar = true, altIcon = cdTex[63456] },     -- Ice Comet
    [63473]  = { unitTag = 'groundaoe', iH = nil, altTime = 13.4, altName = nil, bar = true, altIcon = cdTex[63473] },     -- Shooting Star
    [108842] = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = ZOSName(23617, 1), bar = true, altIcon = nil }, -- Sorcerer Unstable Familiar
    [77187]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = ZOSName(23641, 1), bar = true, altIcon = nil }, -- Sorcerer Volatile Familiar
    [77354]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = true, altIcon = nil },               -- Sorcerer Twilight Tormentor

    -- Abilities
    [32788]  = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = true, altIcon = cdTex[32788] },                   -- DK Inhale Hit Timer (Draw Essence)
    [38792]  = { unitTag = 'groundaoe', iH = nil, altTime = ATd(126475), altName = nil, bar = false, altIcon = cdTex[126475] }, -- 2H Stampede AOE
    [146920] = { unitTag = 'groundaoe', iH = nil, altTime = 3, altName = nil, bar = true, altIcon = cdTex[86019] },             -- Warden Subterranean Assault
    [35750]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = false, altIcon = nil },                   -- Trap Beast on ground pre-proc
    [40382]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = false, altIcon = nil },                   -- Barbed Trap on ground pre-proc
    [40372]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = false, altIcon = nil },                   -- Lightweight Beast Trap on ground pre-proc

    -- Random procs
    [9237]   = { unitTag = nil, iH = nil, altTime = 10, altName = nil, bar = false, altIcon = cdTex[9237] },           -- Larva Gestation (Young Wasp)
    [10392]  = { unitTag = nil, iH = nil, altTime = 180, altName = L.YoungWasp, bar = false, altIcon = cdTex[10392] }, -- Larva Burst (Young Wasp)
    [65541]  = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = false, altIcon = nil },                  -- Empower (mage guild)
    -- 	[57170]		= {unitTag = nil,			iH = nil,		altTime = nil,			altName = nil,				bar = false,	altIcon = nil},				-- Blood Frenzy (?)													
    [118366] = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = false, altIcon = nil },                  -- Empowering Grasp
    [76537]  = { unitTag = nil, iH = nil, altTime = nil, altName = nil, bar = false, altIcon = nil },                  -- Empower (Molten Armaments)
    [21403]  = { unitTag = 'groundaoe', iH = nil, altTime = 21.4, altName = nil, bar = false, altIcon = nil },         -- Auridon quest ghost avoidance buff

    -- Templar Cleansing Ritual AOE (and morphs)
    [22265]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = true, altIcon = nil }, -- Cleansing Ritual
    [22259]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = true, altIcon = nil }, -- Ritual of Retribution
    [22262]  = { unitTag = 'groundaoe', iH = nil, altTime = nil, altName = nil, bar = true, altIcon = nil }, -- Extended Ritual
}

local abilityCooldowns =
{ -- assign cooldown tracker to a display frame to monitor ability cooldowns
    -- Values: (Phinix)
    -- CD			= how often the set can proc.
    -- hT			= whether the set proc effect needs an additional timer separate from the cooldown, for buffs the game does not show by default.
    -- altTime		= duration of the above proc buff effect. nil unless GetAbilityDuration(ID) / 1000 is not correct, then input in seconds.
    -- altName		= used when GetAbilityName(ID) for the trigger event of the set proc doesn't match the set name or anything identifiable.
    -- altIcon		= used to give the cooldown a different icon, used mainly when GetAbilityIcon(ID) for the trigger event uses a boring default icon.
    -- unitTag		= used to determine the type of effect of the additional proc timer when hasTimer is true.
    -- cdE			= 1 requires EVENT_COMBAT_EVENT to track procs the game does not normally show, otherwise use EVENT_EFFECT_CHANGED.
    -- s1/s2		= internal game setID of the normal/perfected version of a gear piece used for various checks and naming purposes.
    -- iH			= result code for initial hit used to avoid resetting the cooldown on subsequent ticks/effects. most can be nil, but some like Skoria need this.
    -- oH			= boolean set true if ability has additional hits that use the same ID as iH to avoid resetting cooldown
    -- cdTex		= custom texture

    -- * = created/verified, and manually tested on PTS November 2021 by Phinix

    -- Arena Sets
    [147692] = { s1 = 544, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = 10, altName = nil, altIcon = cdTex[147692], unitTag = 'reticleover' }, -- Explosive Rebuke									*
    [147872] = { s1 = 562, s2 = 568, cdE = 1, CD = 10, iH = aR[2240], oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },            -- Force Overflow (Vateshran Restoration Staff)		*
    [71188]  = { s1 = 213, s2 = 0, cdE = 1, CD = 13, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                   -- Glorious Defender (Maelstrom Arena Set)			*
    [147675] = { s1 = 542, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                    -- Hex Siphon										*
    [74106]  = { s1 = 216, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[74106], unitTag = nil },          -- Hunt Leader (Maelstrom Arena Set)				*
    [71193]  = { s1 = 214, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(214, 2), altIcon = nil, unitTag = nil },        -- Para Bellum										*
    [147747] = { s1 = 558, s2 = 564, cdE = 1, CD = 13, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                 -- Void Bash (Vateshran 1h&shield)					*
    [71647]  = { s1 = 217, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[71647], unitTag = 'groundaoe' },   -- Winterborn (Maelstrom Arena Set)					*
    [147843] = { s1 = 561, s2 = 567, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = 10, altName = nil, altIcon = nil, unitTag = nil },                  -- Wrath of Elements (Vateshran Destruction Staff)	*

    -- Crafted Sets
    [34502]  = { s1 = 54, s2 = 0, cdE = 1, CD = 4, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                       -- Ashen Grip										*
    [121914] = { s1 = 437, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[121914], unitTag = nil },           -- Coldharbour's Favorite							*
    [92774]  = { s1 = 324, s2 = 0, cdE = 1, CD = 9, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(324, 2), altIcon = cdTex[92774], unitTag = nil }, -- Daedric Trickery									*
    [92775]  = { s1 = 324, s2 = 0, cdE = 1, CD = 9, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(324, 2), altIcon = cdTex[92775], unitTag = nil }, -- Daedric Trickery									*
    [92771]  = { s1 = 324, s2 = 0, cdE = 1, CD = 9, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(324, 2), altIcon = cdTex[92771], unitTag = nil }, -- Daedric Trickery									*
    [92773]  = { s1 = 324, s2 = 0, cdE = 1, CD = 9, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(324, 2), altIcon = cdTex[92773], unitTag = nil }, -- Daedric Trickery									*
    [92776]  = { s1 = 324, s2 = 0, cdE = 1, CD = 9, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(324, 2), altIcon = cdTex[92776], unitTag = nil }, -- Daedric Trickery									*
    [129536] = { s1 = 468, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(468, 2), altIcon = nil, unitTag = nil },          -- Daring Corsair									*
    [134104] = { s1 = 482, s2 = 0, cdE = 1, CD = 21, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[134104], unitTag = nil },           -- Dauntless Combatant								*
    [33764]  = { s1 = 37, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                      -- Death's Wind										*
    [164087] = { s1 = 353, s2 = 0, cdE = 1, CD = 25, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[164087], unitTag = nil },           -- Mechanical Acuity								*
    [71671]  = { s1 = 219, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                      -- Morkuldin										*
    [113307] = { s1 = 409, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(409, 2), altIcon = nil, unitTag = nil },          -- Naga Shaman										*
    [61781]  = { s1 = 176, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                      -- Noble's Conquest									*
    [106804] = { s1 = 387, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(387, 2), altIcon = nil, unitTag = nil },           -- Nocturnal's Favor								*
    [113092] = { s1 = 386, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[113092], unitTag = nil },            -- Sload's Semblance								*
    -- 	[34587]		= {s1 = 81,		s2 = 0, 	cdE = 1, CD = 3,		iH = nil,				oH = false,	hT = false,		altTime = nil,		altName = nil,				altIcon = nil,				unitTag = nil},				-- Song of Lamae									*
    [69685]  = { s1 = 74, s2 = 0, cdE = 1, CD = 30, iH = nil, oH = false, hT = true, altTime = 30, altName = ZOSName(74, 2), altIcon = nil, unitTag = nil },             -- Spectre's Eye									*
    [75726]  = { s1 = 224, s2 = 0, cdE = 1, CD = 3, iH = nil, oH = false, hT = true, altTime = 3, altName = nil, altIcon = cdTex[75726], unitTag = nil },                -- Tava's Favor										*
    [134094] = { s1 = 481, s2 = 0, cdE = 1, CD = 14, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(481, 2), altIcon = nil, unitTag = nil },         -- Unchained Aggressor								*
    [49236]  = { s1 = 41, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                       -- Whitestrake's Retribution						*

    -- Dungeon Sets
    [133493] = { s1 = 475, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = 11, altName = ZOSName(475, 2), altIcon = cdTex[133493], unitTag = nil },         -- Aegis Caller										*
    [142660] = { s1 = 518, s2 = 0, cdE = 1, CD = 30, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                             -- Arkasis's Genius									*
    [84277]  = { s1 = 260, s2 = 0, cdE = 1, CD = 45, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[84277], unitTag = nil },                    -- Aspect of Mazzatun								*
    [116884] = { s1 = 435, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Auroran's Thunder								*
    [133292] = { s1 = 473, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(473, 2), altIcon = nil, unitTag = nil },                 -- Bani's Torment									*
    [85978]  = { s1 = 28, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[85978], unitTag = nil },                      -- Barkskin											*
    [111386] = { s1 = 400, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(400, 2), altIcon = cdTex[111386], unitTag = nil },        -- Blood Moon										*
    [66887]  = { s1 = 184, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Brands of Imperium								*
    [61459]  = { s1 = 160, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Burning Spellweave								*
    [102027] = { s1 = 343, s2 = 0, cdE = 1, CD = 5, iH = aR[2240], oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[102027], unitTag = nil },               -- Caluurion's Legacy (flame)						*
    [102032] = { s1 = 343, s2 = 0, cdE = 1, CD = 5, iH = aR[2240], oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[102032], unitTag = nil },               -- Caluurion's Legacy (frost)						*
    [102033] = { s1 = 343, s2 = 0, cdE = 1, CD = 5, iH = aR[2240], oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[102033], unitTag = nil },               -- Caluurion's Legacy (disease)						*
    [102034] = { s1 = 343, s2 = 0, cdE = 1, CD = 5, iH = aR[2240], oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[102034], unitTag = nil },               -- Caluurion's Legacy (shock)						*
    [159291] = { s1 = 602, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[159291], unitTag = 'reticleover' },         -- Crimson Oath's Rive								*
    [141638] = { s1 = 515, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                               -- Crimson Twilight									*
    [160395] = { s1 = 77, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                               -- Crusader											*
    [102023] = { s1 = 348, s2 = 0, cdE = 1, CD = 4, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Curse of Doylemish								*
    [126682] = { s1 = 457, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                               -- Dragon's Defilement								*
    [150974] = { s1 = 571, s2 = 0, cdE = 1, CD = 18, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(571, 2), altIcon = nil, unitTag = nil },                 -- Drake's Rush										*
    [97538]  = { s1 = 335, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[97538], unitTag = 'groundaoe' },             -- Draugr's Rest									*
    [133406] = { s1 = 474, s2 = 0, cdE = 1, CD = 9, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'reticleover' },                     -- Draugrkin's Grip									*
    [67298]  = { s1 = 198, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[67298], unitTag = 'groundaoe' },            -- Essence Thief									*
    [99144]  = { s1 = 338, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[99144], unitTag = nil },                    -- Flame Blossom									*
    [151126] = { s1 = 574, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Foolkiller										*
    [151135] = { s1 = 574, s2 = 0, cdE = 1, CD = 30, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[151135], unitTag = nil },                    -- Foolkiller shield pop							*
    [167114] = { s1 = 621, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'reticleover' },                    -- Glacial Guardian									*
    [167043] = { s1 = 620, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[167043], unitTag = 'groundaoe' },            -- Gryphon’s Reprisal								*
    [97908]  = { s1 = 340, s2 = 0, cdE = 1, CD = 30, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[97908], unitTag = nil },                     -- Hagraven's Garden								*
    [84354]  = { s1 = 263, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[84354], unitTag = 'groundaoe' },              -- Hand of Mephala									*
    [111442] = { s1 = 401, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[111442], unitTag = 'groundaoe' },            -- Haven of Ursus									*
    [112414] = { s1 = 401, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[112414], unitTag = nil },                    -- Haven of Ursus									*
    [133210] = { s1 = 471, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(471, 2), altIcon = nil, unitTag = nil },                  -- Hiti's Hearth									*
    [126924] = { s1 = 452, s2 = 0, cdE = 1, CD = 9, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[126924], unitTag = nil },                    -- Hollowfang's Thirst								*
    [117666] = { s1 = 431, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[117666], unitTag = 'reticleover' },         -- Icy Conjuror										*
    [97627]  = { s1 = 337, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(337, 2), altIcon = cdTex[97627], unitTag = nil },        -- Ironblood										*
    [67078]  = { s1 = 186, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                               -- Jolting Arms										*
    [33512]  = { s1 = 35, s2 = 0, cdE = 1, CD = 3, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(35, 2), altIcon = nil, unitTag = nil },                    -- Knightmare										*
    [142687] = { s1 = 517, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[142816], unitTag = nil },                   -- Kraglen's Howl									*
    [67205]  = { s1 = 196, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[67205], unitTag = 'groundaoe' },              -- Leeching Plate									*
    [34813]  = { s1 = 103, s2 = 0, cdE = 1, CD = 30, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[34813], unitTag = nil },                    -- Magicka Furnace									*
    [167040] = { s1 = 619, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                      -- Maligalig’s Maelstrom							*
    [116805] = { s1 = 429, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(429, 2), altIcon = cdTex[116805], unitTag = nil },       -- Mighty Glacier									*
    [34373]  = { s1 = 46, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                               -- Noble Duelist									*
    [57206]  = { s1 = 91, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[57206], unitTag = nil },                     -- Oblivion's Edge									*
    [67129]  = { s1 = 193, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                       -- Overwhelming Surge								*
    [97714]  = { s1 = 336, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[97714], unitTag = nil },                    -- Pillar of Nirn									*
    [102106] = { s1 = 347, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(347, 2), altIcon = cdTex[102106], unitTag = 'groundaoe' }, -- Plague Slinger									*
    [187935] = { s1 = 680, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[187935], unitTag = nil },                    -- Ritemaster										*
    [159279] = { s1 = 604, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[159279], unitTag = 'groundaoe' },             -- Rush of Agony									*
    [67288]  = { s1 = 190, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                               -- Scathing Mage									*
    [116954] = { s1 = 434, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(434, 2), altIcon = nil, unitTag = nil },                 -- Scavenging Demise								*
    [159237] = { s1 = 603, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(603, 2), altIcon = nil, unitTag = nil },                  -- Scorion's Feast									*
    [57164]  = { s1 = 134, s2 = 0, cdE = 1, CD = 60, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Shroud of the Lich								*
    [159380] = { s1 = 605, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[159380], unitTag = nil },                   -- Silver Rose Vigil								*
    [70298]  = { s1 = 188, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Storm Master										*
    [159244] = { s1 = 606, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = 7, altName = nil, altIcon = cdTex[159244], unitTag = 'groundaoe' },              -- Thunder Caller									*
    [101970] = { s1 = 344, s2 = 0, cdE = 1, CD = 45, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[101970], unitTag = nil },                   -- Trappings of Invigoration						*
    [167350] = { s1 = 622, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Turning Tide										*
    [61200]  = { s1 = 155, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Undaunted Bastion								*
    [57163]  = { s1 = 19, s2 = 0, cdE = 1, CD = 45, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(19, 2), altIcon = cdTex[57163], unitTag = nil },          -- Vestments of the Warlock							*
    [33691]  = { s1 = 33, s2 = 0, cdE = 1, CD = 4, iH = nil, oH = false, hT = true, altTime = 4, altName = nil, altIcon = nil, unitTag = 'reticleover' },                        -- Viper's Sting									*
    [177678] = { s1 = 662, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[177678], unitTag = nil },                     -- Rage of the Ursauk								*
    [174996] = { s1 = 665, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'reticleover' },                    -- Phylactery’s Grasp								*
    [235832] = { s1 = 794, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[235835], unitTag = nil },                    -- Vandorallen’s Resonance							*
    [235746] = { s1 = 795, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[236163], unitTag = nil },                   -- Jerensi’s Bladestorm								*
    [235885] = { s1 = 796, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[237146], unitTag = nil },                    -- Lucilla’s Windshield								*
    [236355] = { s1 = 799, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[236443], unitTag = nil },                   -- Fledgling's Nest									*
    [236745] = { s1 = 800, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[236827], unitTag = nil },                   -- Noxious Boulder									*
    [215028] = { s1 = 732, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[215054], unitTag = nil },                   -- Black-Glove Grounding							*
    [214873] = { s1 = 730, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[214889], unitTag = nil },                    -- Cinders of Anthelmir								*
    [217085] = { s1 = 736, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Tarnished Nightmare								*

    -- Monster Sets
    [167739] = { s1 = 636, s2 = 0, cdE = 1, CD = 25, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'reticleover' },                     -- Baron Thirsk 									*
    [59517]  = { s1 = 163, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                -- Bloodspawn										*
    [59590]  = { s1 = 167, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = 6, altName = ZOSName(167, 2), altIcon = cdTex[59590], unitTag = 'groundaoe' },    -- Bogdan the Nightflame							*
    [81069]  = { s1 = 269, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[81069], unitTag = 'groundaoe' },             -- Chokethorn										*
    [97882]  = { s1 = 342, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = 10, altName = nil, altIcon = cdTex[97882], unitTag = 'groundaoe' },               -- Domihaus											*
    [97855]  = { s1 = 341, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = 10, altName = nil, altIcon = cdTex[97855], unitTag = 'groundaoe' },               -- Earthgore										*
    [151033] = { s1 = 577, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(577, 2), altIcon = nil, unitTag = 'groundaoe' },           -- Encratis's Behemoth								*
    [59522]  = { s1 = 166, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                              -- Engine Guardian									*
    [84504]  = { s1 = 280, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                       -- Grothdar											*
    [126687] = { s1 = 458, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[126687], unitTag = nil },                     -- Grundwulf (NO EVENT IF RESOURCES FULL)			*
    [80562]  = { s1 = 274, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                -- Iceheart											*
    [80527]  = { s1 = 273, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[80527], unitTag = 'groundaoe' },               -- Ilambris											*
    [155333] = { s1 = 599, s2 = 0, cdE = 1, CD = 40, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                               -- Immolator Charr									*
    [83405]  = { s1 = 272, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = 3, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                          -- Infernal Guardian								*
    [167052] = { s1 = 632, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[167052], unitTag = 'groundaoe' },             -- Kargaeda 										*
    [80566]  = { s1 = 266, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                        -- Kra'gh											*
    [166782] = { s1 = 635, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[166782], unitTag = 'groundaoe' },             -- Lady Malydga 									*
    [141905] = { s1 = 535, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(535, 2), altIcon = cdTex[141905], unitTag = 'groundaoe' }, -- Lady Thorn										*
    [59587]  = { s1 = 164, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[59587], unitTag = 'groundaoe' },              -- Lord Warden Dusk									*
    [126941] = { s1 = 459, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = 4, altName = nil, altIcon = nil, unitTag = 'reticleover' },                       -- Maarselok										*
    [161527] = { s1 = 609, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[161527], unitTag = nil },                    -- Magma Incarnate									*
    [59568]  = { s1 = 165, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = 6, altName = nil, altIcon = cdTex[59568], unitTag = nil },                         -- Malubeth the Scourger							*
    [59508]  = { s1 = 170, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(170, 2), altIcon = cdTex[59508], unitTag = nil },          -- Maw of the Infernal								*
    [66812]  = { s1 = 183, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(183, 2), altIcon = nil, unitTag = nil },                    -- Molag Kena										*
    [133381] = { s1 = 478, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                -- Mother Ciannait									*
    [167065] = { s1 = 633, s2 = 0, cdE = 1, CD = 30, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                       -- Nazaray	 										*
    [59594]  = { s1 = 168, s2 = 0, cdE = 1, CD = 3, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(168, 2), altIcon = cdTex[59594], unitTag = 'groundaoe' },   -- Nerien'eth										*
    [167682] = { s1 = 634, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[167682], unitTag = 'groundaoe' },             -- Nunatak											*
    [98421]  = { s1 = 277, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[98421], unitTag = nil },                     -- Pirate Skeleton									*
    [159500] = { s1 = 608, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                       -- Prior Thierric									*
    [160839] = { s1 = 279, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = false, altTime = 2, altName = ZOSName(279, 2), altIcon = cdTex[160839], unitTag = nil },           -- Selene											*
    [80545]  = { s1 = 271, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[80545], unitTag = 'groundaoe' },              -- Sellistrix										*
    [81036]  = { s1 = 268, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = 8, altName = nil, altIcon = cdTex[81036], unitTag = 'groundaoe' },                -- Sentinel of Rkugamz								*
    [80954]  = { s1 = 265, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(265, 2), altIcon = cdTex[80954], unitTag = nil },          -- Shadowrend										*
    [59497]  = { s1 = 162, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(162, 2), altIcon = cdTex[59497], unitTag = 'groundaoe' },  -- Spawn of Mephala									*
    [143032] = { s1 = 534, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                       -- Stone Husk										*
    [116881] = { s1 = 432, s2 = 0, cdE = 1, CD = 14, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(432, 2), altIcon = cdTex[116881], unitTag = nil },        -- Stonekeeper										*
    [80523]  = { s1 = 275, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[80523], unitTag = 'groundaoe' },               -- Stormfist										*
    [117111] = { s1 = 436, s2 = 0, cdE = 1, CD = 18, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(436, 2), altIcon = nil, unitTag = nil },                  -- Symphony of Blades								*
    [102093] = { s1 = 349, s2 = 0, cdE = 1, CD = 16, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[102093], unitTag = 'groundaoe' },             -- Thurvokun										*
    [80517]  = { s1 = 276, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = 15, altName = nil, altIcon = nil, unitTag = nil },                               -- Tremorscale										*
    [59596]  = { s1 = 169, s2 = 0, cdE = 1, CD = 5, iH = aR[2240], oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                          -- Valkyn Skoria									*
    [80487]  = { s1 = 257, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(257, 2), altIcon = cdTex[80487], unitTag = nil },          -- Velidreth										*
    [111354] = { s1 = 398, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(398, 2), altIcon = nil, unitTag = nil },                  -- Vykosa											*
    [110997] = { s1 = 350, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = 10, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                        -- Zaan												*
    [176813] = { s1 = 666, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[176813], unitTag = 'groundaoe' },            -- Archdruid Devyric								*
    [175350] = { s1 = 667, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[175350], unitTag = 'groundaoe' },            -- Euphotic Gatekeeper								*
    [202778] = { s1 = 713, s2 = 0, cdE = 1, CD = 14, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                               -- Nibenay Bay Battlereeve							*
    [236654] = { s1 = 801, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[236654], unitTag = nil },                      -- Orpheon the Tactician							*

    -- Overland Sets
    [75691]  = { s1 = 227, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[75691], unitTag = 'groundaoe' },                 -- Bahraha's Curse									*
    [34522]  = { s1 = 65, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[34522], unitTag = nil },                         -- Bloodthorn's Touch								*
    [154490] = { s1 = 581, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                 -- Bog Raider										*
    [71107]  = { s1 = 212, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                 -- Briarheart										*
    [154347] = { s1 = 580, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                -- Deadlands Assassin								*
    [93308]  = { s1 = 321, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[93308], unitTag = nil },                        -- Defiler											*
    [57297]  = { s1 = 135, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                 -- Draugr Heritage									*
    [31213]  = { s1 = 22, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                  -- Dreamer's Mantle									*
    [163044] = { s1 = 613, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[163044], unitTag = nil },                       -- Eye of the Grasp (NO EVENT IF ULT FULL)			*
    [106868] = { s1 = 382, s2 = 0, cdE = 1, CD = 20, iH = aR[1073741840], oH = true, hT = true, altTime = 10, altName = ZOSName(382, 2), altIcon = cdTex[106868], unitTag = nil },  -- Grace of Gloom									*
    [112523] = { s1 = 62, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                   -- Hatchling's Shell								*
    [163033] = { s1 = 614, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                  -- Hexos' Ward										*
    [34508]  = { s1 = 58, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                  -- Hide of the Werewolf								*
    [163060] = { s1 = 615, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(615, 2), altIcon = cdTex[163060], unitTag = 'reticleover' }, -- Kynmarcher's Cruelty (Major Vulnerability)		*
    [163062] = { s1 = 615, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(615, 2), altIcon = cdTex[163062], unitTag = 'reticleover' }, -- Kynmarcher's Cruelty (Major Breach)				*
    [163064] = { s1 = 615, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(615, 2), altIcon = cdTex[163064], unitTag = 'reticleover' }, -- Kynmarcher's Cruelty (Major Maim)				*
    [163065] = { s1 = 615, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(615, 2), altIcon = cdTex[163065], unitTag = 'reticleover' }, -- Kynmarcher's Cruelty (Major Cowardice)			*
    [163066] = { s1 = 615, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(615, 2), altIcon = cdTex[163066], unitTag = 'reticleover' }, -- Kynmarcher's Cruelty (Major Defile)				*
    [99286]  = { s1 = 356, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                 -- Livewire											*
    [92982]  = { s1 = 354, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[92982], unitTag = nil },                        -- Mad Tinkerer										*
    [34711]  = { s1 = 94, s2 = 0, cdE = 1, CD = 25, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                  -- Meridia's Blessed Armor							*
    [187904] = { s1 = 681, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(681, 2), altIcon = cdTex[187904], unitTag = nil },           -- Nix Hound's Howl									*
    [122755] = { s1 = 47, s2 = 0, cdE = 1, CD = 3, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                  -- Robes of the Withered Hand						*
    [127270] = { s1 = 70, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                  -- Seventh Legion Brute								*
    [174523] = { s1 = 64, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                  -- Shadow Dancer's Raiment							*
    [97806]  = { s1 = 49, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[97806], unitTag = nil },                         -- Shadow of the Red Mountain						*
    [57210]  = { s1 = 93, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                           -- Storm Knight's Plate								*
    [76344]  = { s1 = 228, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                 -- Syvarra's Scales									*
    [33497]  = { s1 = 30, s2 = 0, cdE = 1, CD = 3, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                  -- Thunderbug's Carapace							*
    [71664]  = { s1 = 218, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[71664], unitTag = nil },                        -- Trinimac's Valor									*
    [34817]  = { s1 = 105, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(105, 2), altIcon = nil, unitTag = 'reticleover' },           -- Twin Sisters										*
    [99268]  = { s1 = 355, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = 12, altName = nil, altIcon = nil, unitTag = nil },                                  -- Unfathomable Darkness							*
    [135690] = { s1 = 488, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = true, altTime = 10, altName = ZOSName(488, 2), altIcon = nil, unitTag = 'reticleover' },            -- Venomous Smite									*
    [127070] = { s1 = 147, s2 = 0, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'reticleover' },                        -- Way of Martial Knowledge							*
    [135659] = { s1 = 487, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[135659], unitTag = 'groundaoe' },               -- Winter's Respite Set								*

    -- PvP Sets
    [34787]  = { s1 = 101, s2 = 0, cdE = 1, CD = 4, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                        -- Affliction										*
    [111575] = { s1 = 113, s2 = 0, cdE = 1, CD = 4, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[111575], unitTag = nil },              -- Crest of Cyrodiil								*
    [159388] = { s1 = 616, s2 = 0, cdE = 1, CD = 25, iH = nil, oH = false, hT = true, altTime = 4, altName = nil, altIcon = cdTex[159388], unitTag = 'groundaoe' },        -- Dark Convergence									*
    [167402] = { s1 = 631, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[167402], unitTag = 'reticleover' },   -- Enervating Aura									*
    [166719] = { s1 = 630, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                         -- Hew and Sunder									*
    [159713] = { s1 = 618, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = 'groundaoe' },                -- Hrothgar's Chill									*
    [188882] = { s1 = 690, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(690, 2), altIcon = nil, unitTag = 'reticleover' }, -- Judgement of Akatosh								*
    [142401] = { s1 = 63, s2 = 0, cdE = 1, CD = 60, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                         -- Juggernaut										*
    [70492]  = { s1 = 59, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[70492], unitTag = nil },                -- Kyne's Kiss (Rewards of the Worthy)				*
    [127032] = { s1 = 200, s2 = 0, cdE = 1, CD = 60, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                        -- Phoenix (Tel Var)								*
    [166729] = { s1 = 629, s2 = 0, cdE = 1, CD = 15, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[166729], unitTag = nil },             -- Rallying Cry										*
    [69567]  = { s1 = 201, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(201, 2), altIcon = nil, unitTag = nil },            -- Reactive Armor (Tel Var)							*
    [117391] = { s1 = 89, s2 = 0, cdE = 1, CD = 30, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                         -- Sentry (Rewards of the Worthy)					*
    [194324] = { s1 = 688, s2 = 0, cdE = 1, CD = 14, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[188546], unitTag = nil },             -- Snake in the Stars								*
    [115771] = { s1 = 420, s2 = 0, cdE = 1, CD = 6, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[115771], unitTag = nil },              -- Soldier of Anguish								*
    [113382] = { s1 = 418, s2 = 0, cdE = 1, CD = 4, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[113382], unitTag = 'reticleover' },     -- Spell Strategist (Rewards of the Worthy)			*
    [113509] = { s1 = 421, s2 = 0, cdE = 1, CD = 12, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(421, 2), altIcon = nil, unitTag = nil },            -- Steadfast Hero (Rewards of the Worthy)			*
    [230719] = { s1 = 792, s2 = 0, cdE = 1, CD = 7, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                        -- Farstrider										*
    [234071] = { s1 = 804, s2 = 0, cdE = 1, CD = 28, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                       -- Blackfeather Flight								*
    [184634] = { s1 = 670, s2 = 0, cdE = 1, CD = 28, iH = aR[16], oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[184634], unitTag = nil },          -- Mara's Balm										*

    -- Trial Sets
    -- 	[61737]		= {s1 = 388,	s2 = 392,	cdE = 1, CD = 2,		iH = nil,				oH = false,	hT = false,		altTime = nil,		altName = ZOSName(388,2),	altIcon = nil,				unitTag = nil},				-- Aegis of Galenwe									*
    [121878] = { s1 = 446, s2 = 451, cdE = 1, CD = 8, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(446, 2), altIcon = nil, unitTag = nil },                   -- Claw of Yolnakhriin (same for Perfected)			*
    [86907]  = { s1 = 138, s2 = 0, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                 -- Defending Warrior								*
    [51315]  = { s1 = 140, s2 = 0, cdE = 1, CD = 4, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = nil, unitTag = 'reticleover' },                        -- Destructive Mage									*
    [127235] = { s1 = 171, s2 = 0, cdE = 1, CD = 60, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = nil, unitTag = nil },                                -- Eternal Warrior									*
    [51443]  = { s1 = 141, s2 = 0, cdE = 1, CD = 3, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(141, 2), altIcon = cdTex[51443], unitTag = nil },            -- Healing Mage										*
    [129477] = { s1 = 136, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(136, 2), altIcon = nil, unitTag = nil },                    -- Immortal Warrior (Yokeda)						*
    [136098] = { s1 = 492, s2 = 493, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[136098], unitTag = 'groundaoe' },             -- Kyne's Wind (same for Perfected)					*
    [75814]  = { s1 = 231, s2 = 0, cdE = 1, CD = 20, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[75814], unitTag = 'groundaoe' },                -- Lunar Bastion									*
    [110067] = { s1 = 390, s2 = 394, cdE = 1, CD = 8, iH = nil, oH = false, hT = true, altTime = 10, altName = ZOSName(390, 2), altIcon = cdTex[110067], unitTag = 'groundaoe' },   -- Mantle of Siroria (same for Perfected)			*
    [135923] = { s1 = 496, s2 = 497, cdE = 1, CD = 22, iH = nil, oH = false, hT = false, altTime = nil, altName = ZOSName(496, 2), altIcon = cdTex[135923], unitTag = nil },        -- Roaring Opportunist (same for Perfected)			*
    [154783] = { s1 = 588, s2 = 592, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(588, 2), altIcon = nil, unitTag = 'reticleover' },         -- Stone-Talker's Oath (same for Perfected)			*
    [107141] = { s1 = 391, s2 = 395, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = nil, altName = nil, altIcon = cdTex[107141], unitTag = 'groundaoe' },             -- Vestment of Olirime (same for Perfected)			*
    [135926] = { s1 = 494, s2 = 495, cdE = 1, CD = 21, iH = nil, oH = false, hT = true, altTime = nil, altName = ZOSName(494, 2), altIcon = nil, unitTag = nil },                   -- Vrol's Aegis (same for Perfected)				*
    [172671] = { s1 = 646, s2 = 653, cdE = 1, CD = 18, iH = nil, oH = false, hT = true, altTime = 8, altName = ZOSName(646, 2), altIcon = cdTex[172671], unitTag = 'reticleover' }, -- Whorl of the Depths (same for Perfected)			*
    [220863] = { s1 = 767, s2 = 772, cdE = 1, CD = 5, iH = nil, oH = false, hT = false, altTime = 5, altName = nil, altIcon = nil, unitTag = nil },                                 -- Slivers of the Null Arca (same for Perfected)	*

    -- Mythic Sets
    [163375] = { s1 = 626, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = false, altTime = nil, altName = nil, altIcon = cdTex[163375], unitTag = nil }, -- Belharza's Band									*
    [220958] = { s1 = 760, s2 = 0, cdE = 1, CD = 10, iH = nil, oH = false, hT = true, altTime = 10, altName = nil, altIcon = nil, unitTag = nil },             -- Rourken Steamguards								*

}

local grimBase =
{                                                                          -- procStacks: spectral bow is usable at this count; all morphs cap at 10
    [122585] = { icon = '/esoui/art/icons/ability_nightblade_005.dds', procStacks = 5, buffId = 61905 },   -- Grim Focus (game stack buff 61905)
    [122586] = { icon = '/esoui/art/icons/ability_nightblade_005_b.dds', procStacks = 5, buffId = 61920 }, -- Merciless Resolve (game stack buff 61920)
    [122587] = { icon = '/esoui/art/icons/ability_nightblade_005_a.dds', procStacks = 4, buffId = 61928 }, -- Relentless Focus (game stack buff 61928)
}

local grimBar =
{                               -- slotted ability -> grimBase tracker id
    [61902] = { aID = 122585 }, -- Grim Focus
    [61919] = { aID = 122586 }, -- Merciless Resolve
    [61927] = { aID = 122587 }, -- Relentless Focus
}

local grimBuffToTracker =
{
    [61905] = 122585, -- Grim Focus
    [61920] = 122586, -- Merciless Resolve
    [61928] = 122587, -- Relentless Focus
}

local multiProcSets =
{ -- special cases where srendarr needs to be aware of multiple possible procs (like Daedric Trickery) from a set in order to update the cooldown bar (Phinix)
    [324] =
    {
        [92774] = 92771, -- Daedric Trickery	
        [92775] = 92771, -- Daedric Trickery	
        [92771] = 92771, -- Daedric Trickery	
        [92773] = 92771, -- Daedric Trickery	
        [92776] = 92771, -- Daedric Trickery	
    },
    [343] =
    {
        [102027] = 102027, -- Caluurion's Legacy
        [102032] = 102027, -- Caluurion's Legacy
        [102033] = 102027, -- Caluurion's Legacy
        [102034] = 102027, -- Caluurion's Legacy
    },
    [615] =
    {
        [163060] = 163064, -- Kynmarcher's Cruelty
        [163062] = 163064, -- Kynmarcher's Cruelty
        [163064] = 163064, -- Kynmarcher's Cruelty
        [163065] = 163064, -- Kynmarcher's Cruelty
        [163066] = 163064, -- Kynmarcher's Cruelty
    },
}

local abilityBarSets =
{
    -- Arena Sets
    [544] = 147692,
    [542] = 147675,
    [213] = 71188,
    [216] = 74106,
    [214] = 71193,
    [217] = 71647,
    [561] = 147843,
    [562] = 147872,
    [558] = 147747,
    [567] = 147843,
    [568] = 147872,
    [564] = 147747,

    -- Crafted Sets
    [54] = 34502,
    [437] = 121914,
    [468] = 129536,
    [482] = 134104,
    [37] = 33764,
    [353] = 164087,
    [219] = 71671,
    [409] = 113307,
    [176] = 61781,
    [387] = 106804,
    [386] = 113092,
    -- 	[81]	= 34587,
    [74] = 69685,
    [481] = 134094,
    [41] = 49236,
    [324] = 92771,
    [224] = 75726,

    -- Dungeon Sets
    [475] = 133493,
    [518] = 142660,
    [260] = 84277,
    [435] = 116884,
    [473] = 133292,
    [400] = 111386,
    [184] = 66887,
    [160] = 61459,
    [343] = 102027,
    [602] = 159291,
    [515] = 141638,
    [348] = 102023,
    [457] = 126682,
    [571] = 150974,
    [335] = 97538,
    [474] = 133406,
    [198] = 67298,
    [338] = 99144,
    [340] = 97908,
    [263] = 84354,
    [401] = 111442,
    [471] = 133210,
    [452] = 126924,
    [431] = 117666,
    [337] = 97627,
    [186] = 67078,
    [517] = 142687,
    [103] = 34813,
    [429] = 116805,
    [91] = 57206,
    [193] = 67129,
    [336] = 97714,
    [347] = 102106,
    [604] = 159279,
    [190] = 67288,
    [434] = 116954,
    [603] = 159237,
    [134] = 57164,
    [605] = 159380,
    [188] = 70298,
    [606] = 159244,
    [344] = 101970,
    [155] = 61200,
    [19] = 57163,
    [46] = 34373,
    [574] = 151135,
    [35] = 33512,
    [196] = 67205,
    [28] = 85978,
    [77] = 160395,
    [33] = 33691,
    [619] = 167040,
    [620] = 167043,
    [621] = 167114,
    [622] = 167350,
    [662] = 177678,
    [665] = 174996,
    [680] = 187935,
    [794] = 235832,
    [795] = 235746,
    [796] = 235885,
    [799] = 236355,
    [800] = 236745,
    [732] = 215028,
    [730] = 214873,
    [736] = 217085,

    -- Monster Sets
    [163] = 59517,
    [167] = 59590,
    [269] = 81069,
    [342] = 97882,
    [341] = 97855,
    [577] = 151033,
    [166] = 59522,
    [280] = 84504,
    [458] = 126687,
    [274] = 80562,
    [273] = 80527,
    [599] = 155333,
    [272] = 83405,
    [266] = 80566,
    [535] = 141905,
    [164] = 59587,
    [459] = 126941,
    [609] = 161527,
    [165] = 59568,
    [170] = 59508,
    [183] = 66812,
    [478] = 133381,
    [168] = 59594,
    [277] = 98421,
    [608] = 159500,
    [279] = 160839,
    [271] = 80545,
    [268] = 81036,
    [265] = 80954,
    [162] = 59497,
    [534] = 143032,
    [432] = 116881,
    [275] = 80523,
    [436] = 117111,
    [349] = 102093,
    [276] = 80517,
    [169] = 59596,
    [257] = 80487,
    [398] = 111354,
    [350] = 110997,
    [634] = 167682,
    [635] = 166782,
    [636] = 167739,
    [632] = 167052,
    [633] = 167065,
    [666] = 176813,
    [667] = 175350,
    [713] = 202778,
    [801] = 236654,

    -- Overland Sets
    [62] = 112523,
    [581] = 154490,
    [212] = 71107,
    [382] = 106868,
    [94] = 34711,
    [70] = 127270,
    [93] = 57210,
    [105] = 34817,
    [355] = 99268,
    [488] = 135690,
    [147] = 127070,
    [614] = 163033,
    [227] = 75691,
    [580] = 154347,
    [321] = 93308,
    [135] = 57297,
    [22] = 31213,
    [58] = 34508,
    [356] = 99286,
    [354] = 92982,
    [47] = 122755,
    [49] = 97806,
    [228] = 76344,
    [30] = 33497,
    [218] = 71664,
    [487] = 135659,
    [65] = 34522,
    [613] = 163044,
    [615] = 163064,
    [64] = 174523,
    [681] = 187904,

    -- PvP Sets
    [616] = 159388,
    [618] = 159713,
    [59] = 70492,
    [89] = 117391,
    [418] = 113382,
    [421] = 113509,
    [201] = 69567,
    [200] = 127032,
    [101] = 34787,
    [420] = 115771,
    [63] = 142401,
    [113] = 111575,
    [629] = 166729,
    [630] = 166719,
    [631] = 167402,
    [688] = 194324,
    [690] = 188882,
    [792] = 230719,
    [804] = 234071,
    [670] = 184634,

    -- Trial Sets
    -- 	[388]	= 61737,
    -- 	[392]	= 61737,
    [446] = 121878,
    [451] = 121878,
    [138] = 86907,
    [140] = 51315,
    [171] = 127235,
    [141] = 51443,
    [136] = 129477,
    [492] = 136098,
    [493] = 136098,
    [231] = 75814,
    [390] = 110067,
    [394] = 110067,
    [496] = 135923,
    [497] = 135923,
    [391] = 107141,
    [395] = 107141,
    [588] = 154783,
    [592] = 154783,
    [494] = 135926,
    [495] = 135926,
    [646] = 172671,
    [653] = 172671,
    [767] = 220863,
    [772] = 220863,
    [649] = 172055,
    [650] = 172055,

    -- Mythic Sets
    [626] = 163375,
    [760] = 220958,
}

local specialGearSets =
{
    [Srendarr.BahseiData.nSet] = { ID = 154691, alt = Srendarr.BahseiData.pSet, icon = '/esoui/art/icons/gear_rockgrove_lgt_head_a.dds' },
    [Srendarr.BahseiData.pSet] = { ID = 154691, alt = Srendarr.BahseiData.nSet, icon = '/esoui/art/icons/gear_rockgrove_lgt_head_a.dds' },
}

local castbarCancel =
{                   -- list of abilityId's that should immediately cancel the cast bar (Phinix)
    [28549] = true, -- roll dodge
    [55146] = true, -- interrupt bash
    [20309] = true, -- hidden
}


Srendarr.keepAuras[Srendarr.BahseiData.ID] = true
Srendarr.keepAuras[Srendarr.POrderData.ID] = true
-- Grim Focus and Morphs
Srendarr.keepAuras[122585] = true
Srendarr.keepAuras[122586] = true
Srendarr.keepAuras[122587] = true


-- /script d(GetAbilityIcon(61737))
-- /script d(GetAbilityDuration(142401))
-- /script d(GetItemLinkIcon(''))
-- /script d(GetAbilityName(112414))
-- /script d(GetItemSetName(615))
-- /script d(GetAbilityDescription(147875))
-- /script Srendarr:FindIDByName("Spear Shards", 1, true)
-- /script d("|t24:24:/esoui/art/icons/gear_terrorbear_head_a.dds|t")


-- ------------------------
-- MAIN FILTER TABLES
-- ------------------------
local filterAlwaysIgnored =
{
    -- Weird ZOS double auras since Lost Depths DLC
    -- 	[177567] = true,	-- Unstable Wall of Fire
    [28807] = true,  -- Unstable Wall of Fire
    -- 	[177570] = true,	-- Unstable Wall of Lightning
    [28854] = true,  -- Unstable Wall of Lightning
    [39073] = true,  -- Unstable Wall of Lightning
    [177578] = true, -- Unstable Wall of Frost
    -- Default ignore list
    [26188] = true,  -- Spear Shards extra proc effect
    [26869] = true,  -- Blazing Spear extra proc effect
    [113417] = true, -- Spell Strategist (superfluous)
    [25381] = true,  -- Shadowy Disguise (superfluous)
    [23205] = true,  -- Duplicate Lightning Flood short proc
    [29667] = true,  -- Concentration (Light Armour)
    [45569] = true,  -- Medicinal Use (Alchemy)
    [62760] = true,  -- Spell Shield (Champion Point Ability)
    [64160] = true,  -- Crystal Fragments Passive (Not Timed)
    [36603] = true,  -- Soul Siphoner Passive I
    [45155] = true,  -- Soul Siphoner Passive II
    [26858] = true,  -- Extra Luminous Shards
    [46672] = true,  -- Propelling Shield (Extra Aura)
    [42198] = true,  -- Spinal Surge (Extra Aura)
    [62587] = true,  -- Focused Aim (2s Refreshing Aura)
    [38698] = true,  -- Focused Aim (2s Refreshing Aura)
    [42589] = true,  -- Flawless Dawnbreaker (2s aura on Weaponswap)
    -- Target Ogrim (because um... WE KNOW!)
    [159874] = true,
    -- Off Balance Immunity (prevent refreshing off balance when immunity is up)
    [134599] = true,
    -- Special case for NB Grim Focus morphs
    [61905] = true,  -- Grim Focus
    [61920] = true,  -- Merciless Resolve
    [61928] = true,  -- Relentless Focus passive
    -- Special case for Fighters Guild Beast Trap (and morph) tracking
    [35753] = true,  -- Redundant Trap Beast I
    [42710] = true,  -- Redundant Trap Beast II
    [42717] = true,  -- Redundant Trap Beast III
    [42724] = true,  -- Redundant Trap Beast IV
    [40384] = true,  -- Redundant Rearming Trap I
    [42732] = true,  -- Redundant Rearming Trap II
    [42742] = true,  -- Redundant Rearming Trap III
    [42752] = true,  -- Redundant Rearming Trap IV
    [40374] = true,  -- Redundant Lightweight Beast Trap I
    [42759] = true,  -- Redundant Lightweight Beast Trap II
    [42766] = true,  -- Redundant Lightweight Beast Trap III
    [42773] = true,  -- Redundant Lightweight Beast Trap IV
    [35754] = true,  -- Redundant Trap Beast
    [40389] = true,  -- Redundant Barbed Trap
    [40376] = true,  -- Redundant Lightweight Beast Trap
    -- Light Armor active ability redundant buffs
    [41503] = true,  -- Annulment Dummy
    [39188] = true,  -- Dampen Magic
    [41110] = true,  -- Dampen Magic
    [41112] = true,  -- Dampen Magic
    [41114] = true,  -- Dampen Magic
    [44323] = true,  -- Dampen Magic
    [39185] = true,  -- Harness Magicka
    [41117] = true,  -- Harness Magicka
    [41120] = true,  -- Harness Magicka
    [41123] = true,  -- Harness Magicka
    [42876] = true,  -- Harness Magicka
    [42877] = true,  -- Harness Magicka
    [42878] = true,  -- Harness Magicka
    -- Redundant Food Auras
    [84732] = true,  -- Witchmother's Potent Brew
    [84733] = true,  -- Witchmother's Potent Brew
    -- Scorion's Feast
    [159231] = true, -- Scorion's Feast (redundant passive)
    [159233] = true, -- Scorion's Feast (redundant passive)
    -- Grisly Gourmet
    [61737] = true,  -- zero duration empower proc (?)
    -- Templar Focus
    [22237] = true,  -- Restoring Focus no longer separate duration for rune and effects
    [22240] = true,  -- Extra Channeled Focus buff (tracks as AOE)
    -- Random blacklisted (thanks Scootworks)
    -- 	[29705] = true,		-- Whirlpool
    -- 	[30455] = true,		-- Arachnophobia
    -- 	[37136] = true,		-- Amulet
    -- 	[37342] = true,		-- dummy
    -- 	[37475] = true,		-- Manifestation of Terror
    -- 	[43588] = true,		-- Killing Blow
    -- 	[43594] = true,		-- Wait for teleport
    -- 	[44912] = true,		-- Q4730 Shackle Breakign Shakes
    -- 	[45050] = true,		-- Executioner
    -- 	[47718] = true,		-- Death Stun
    -- 	[49807] = true,		-- Killing Blow Stun
    -- 	[55406] = true,		-- Resurrect Trigger
    -- 	[55915] = true,		-- Sucked Under Fall Bonus
    -- 	[56739] = true,		-- Damage Shield
    -- 	[57275] = true,		-- Shadow Tracker
    -- 	[57360] = true,		-- Portal
    -- 	[57425] = true,		-- Brace For Impact
    -- 	[57756] = true,		-- Blend into Shadows
    -- 	[57771] = true,		-- Clone Die Counter
    -- 	[58107] = true,		-- Teleport
    -- 	[58210] = true,		-- PORTAL CHARGED
    -- 	[58241] = true,		-- Shadow Orb - Lord Warden
    -- 	[58242] = true,		-- Fearpicker
    -- 	[58955] = true,		-- Death Achieve Check
    -- 	[59040] = true,		-- Teleport Tracker
    -- 	[59911] = true,		-- Boss Speed
    -- 	[60414] = true,		-- Tower Destroyed
    -- 	[60947] = true,		-- Soul Absorbed
    -- 	[60967] = true,		-- Summon Adds
    -- 	[64132] = true,		-- Grapple Immunity
    -- 	[66808] = true,		-- Molag Kena
    -- 	[66813] = true,		-- White-Gold Tower Item Set
    -- 	[69809] = true,		-- Hard Mode
    -- 	[70113] = true,		-- Shade Despawn
}

local filterAuraGroups =
{
    ['esoplus'] =
    {
        [63601] = true, -- ESO Plus status
    },
    ['cyrodiil'] =
    {
        [11341] = true, -- Enemy Keep Bonus I
        [11343] = true, -- Enemy Keep Bonus II
        [11345] = true, -- Enemy Keep Bonus III
        [11347] = true, -- Enemy Keep Bonus IV
        [11348] = true, -- Enemy Keep Bonus V
        [11350] = true, -- Enemy Keep Bonus VI
        [11352] = true, -- Enemy Keep Bonus VII
        [11353] = true, -- Enemy Keep Bonus VIII
        [11356] = true, -- Enemy Keep Bonus IX
        [12033] = true, -- Battle Spirit
        [15058] = true, -- Offensive Scroll Bonus I
        [15060] = true, -- Defensive Scroll Bonus I
        [16348] = true, -- Offensive Scroll Bonus II
        [16350] = true, -- Defensive Scroll Bonus II
        [39671] = true, -- Emperorship Alliance Bonus
    },
    ['disguise'] =
    {
        -- intentionally empty table just so setup can iterate through filters more simply
    },
    ['mundusBoon'] =
    {
        [13940] = true, -- Boon: The Warrior
        [13943] = true, -- Boon: The Mage
        [13974] = true, -- Boon: The Serpent
        [13975] = true, -- Boon: The Thief
        [13976] = true, -- Boon: The Lady
        [13977] = true, -- Boon: The Steed
        [13978] = true, -- Boon: The Lord
        [13979] = true, -- Boon: The Apprentice
        [13980] = true, -- Boon: The Ritual
        [13981] = true, -- Boon: The Lover
        [13982] = true, -- Boon: The Atronach
        [13984] = true, -- Boon: The Shadow
        [13985] = true, -- Boon: The Tower
    },
    ['soulSummons'] =
    {
        [39269] = true, -- Soul Summons (Rank 1)
        [43752] = true, -- Soul Summons (Rank 2)
        [45590] = true, -- Soul Summons (Rank 2)
    },
    ['vampLycan'] =
    {
        [35658] = true, -- Lycanthropy
        [35771] = true, -- Stage 1 Vampirism (trivia: has a duration even though others don't)
        [35773] = true, -- Stage 2 Vampirism
        [35780] = true, -- Stage 3 Vampirism
        [35786] = true, -- Stage 4 Vampirism
        [35792] = true, -- Stage 4 Vampirism
    },
    ['vampLycanBite'] =
    {
        [40359] = true, -- Fed On Ally
        [40525] = true, -- Bit an ally
        [39472] = true, -- Vampirism
        [40521] = true, -- Sanies Lupinus
    },
}

local filteredAuras =
{ -- used to hold the abilityIDs of filtered auras
    ['player']      = {},
    ['reticleover'] = {},
    ['groundaoe']   = {}
}

for id in pairs(filterAlwaysIgnored) do -- populate initial ignored auras to filters
    if not Srendarr.alwaysIgnore then Srendarr.alwaysIgnore = {} end
    Srendarr.alwaysIgnore[id] = true    -- always ignore these even if added to prominent (Phinix)
    filteredAuras['player'][id] = true
    filteredAuras['reticleover'][id] = true
    filteredAuras['groundaoe'][id] = true
end -- run once on init of addon


-- set external references
Srendarr.alteredAuraIcons = alteredAuraIcons
Srendarr.alteredAuraData = alteredAuraData
Srendarr.stackingAuras = stackingAuras
Srendarr.barCastAuras = barCastAuras
Srendarr.castBarDelayAuras = castBarDelayAuras
Srendarr.enchantProcs = enchantProcs
Srendarr.specialProcs = specialProcs
Srendarr.specialNames = specialNames
Srendarr.releaseTriggers = releaseTriggers
Srendarr.specialRelease = specialRelease
Srendarr.fakeTargetDebuffs = fakeTargetDebuffs
Srendarr.debuffAuras = debuffAuras
Srendarr.alternateAura = alternateAura
Srendarr.filteredAuras = filteredAuras
Srendarr.procAbilityNames = procAbilityNames
Srendarr.abilityCooldowns = abilityCooldowns
Srendarr.abilityBarSets = abilityBarSets
Srendarr.multiProcSets = multiProcSets
Srendarr.specialGearSets = specialGearSets
Srendarr.grimBase = grimBase
Srendarr.grimBar = grimBar
Srendarr.grimBuffToTracker = grimBuffToTracker

function Srendarr.IsGrimProcReady(abilityOffset, stacks)
    local grimData = grimBase[abilityOffset]
    if not grimData then return false end
    return (stacks or 0) >= grimData.procStacks
end

function Srendarr.GetGrimRemainingStacks(abilityOffset, currentStacks)
    local grimData = grimBase[abilityOffset]
    if not grimData then return 0 end
    local remainingStacks = (currentStacks or 0) - grimData.procStacks
    if remainingStacks < 0 then remainingStacks = 0 end
    return remainingStacks
end

function Srendarr.GetGrimBuffStacks(unitTag, abilityOffset)
    local grimData = grimBase[abilityOffset]
    if not grimData or not unitTag or unitTag == 'notag' then return nil end

    local numAuras = GetNumBuffs(unitTag)
    if numAuras <= 0 then return nil end

    local trackerStacks
    local buffStacks
    local buffId = grimData.buffId
    for i = 1, numAuras do
        local _, _, _, _, tStacks, _, _, _, _, _, tAbility = GetUnitBuffInfo(unitTag, i)
        if tAbility == abilityOffset then
            trackerStacks = tStacks
        elseif tAbility == buffId then
            buffStacks = tStacks
        end
    end

    if buffStacks ~= nil then return buffStacks end
    return trackerStacks
end

Srendarr.castbarCancel = castbarCancel
Srendarr.ignoreStacks = ignoreStacks


-- ------------------------
-- OTHER DATA TABLES
-- ------------------------
Srendarr.auraLookup =
{
    ['player']      = {},
    ['reticleover'] = {},
    ['groundaoe']   = {},
    ['group1']      = {},
    ['group2']      = {},
    ['group3']      = {},
    ['group4']      = {},
    ['group5']      = {},
    ['group6']      = {},
    ['group7']      = {},
    ['group8']      = {},
    ['group9']      = {},
    ['group10']     = {},
    ['group11']     = {},
    ['group12']     = {},
    ['group13']     = {},
    ['group14']     = {},
    ['group15']     = {},
    ['group16']     = {},
    ['group17']     = {},
    ['group18']     = {},
    ['group19']     = {},
    ['group20']     = {},
    ['group21']     = {},
    ['group22']     = {},
    ['group23']     = {},
    ['group24']     = {},
}

Srendarr.sampleAuraData =
{
    -- player timed
    [916001] = { auraName = strformat('%s %d', L.SampleAura_PlayerTimed, 1), unitTag = 'player', duration = 10, icon = [[/esoui/art/icons/ability_destructionstaff_001.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916002] = { auraName = strformat('%s %d', L.SampleAura_PlayerTimed, 2), unitTag = 'player', duration = 20, icon = [[/esoui/art/icons/ability_destructionstaff_002.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916003] = { auraName = strformat('%s %d', L.SampleAura_PlayerTimed, 3), unitTag = 'player', duration = 30, icon = [[/esoui/art/icons/ability_destructionstaff_003.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916004] = { auraName = strformat('%s %d', L.SampleAura_PlayerTimed, 4), unitTag = 'player', duration = 60, icon = [[/esoui/art/icons/ability_destructionstaff_004.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916005] = { auraName = strformat('%s %d', L.SampleAura_PlayerTimed, 5), unitTag = 'player', duration = 120, icon = [[/esoui/art/icons/ability_destructionstaff_005.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916006] = { auraName = strformat('%s %d', L.SampleAura_PlayerTimed, 6), unitTag = 'player', duration = 600, icon = [[/esoui/art/icons/ability_destructionstaff_006.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    -- player toggled
    [916007] = { auraName = strformat('%s %d', L.SampleAura_PlayerToggled, 1), unitTag = 'player', duration = 0, icon = [[esoui/art/icons/ability_mageguild_001.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916008] = { auraName = strformat('%s %d', L.SampleAura_PlayerToggled, 2), unitTag = 'player', duration = 0, icon = [[esoui/art/icons/ability_mageguild_002.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    -- player passive
    [916009] = { auraName = strformat('%s %d', L.SampleAura_PlayerPassive, 1), unitTag = 'player', duration = 0, icon = [[esoui/art/icons/ability_restorationstaff_001.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916010] = { auraName = strformat('%s %d', L.SampleAura_PlayerPassive, 2), unitTag = 'player', duration = 0, icon = [[esoui/art/icons/ability_restorationstaff_002.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    -- player debuff
    [916011] = { auraName = strformat('%s %d', L.SampleAura_PlayerDebuff, 1), unitTag = 'player', duration = 10, icon = [[esoui/art/icons/ability_nightblade_001.dds]], effectType = BUFF_EFFECT_TYPE_DEBUFF, abilityType = ABILITY_TYPE_BONUS },
    [916012] = { auraName = strformat('%s %d', L.SampleAura_PlayerDebuff, 2), unitTag = 'player', duration = 30, icon = [[esoui/art/icons/ability_nightblade_002.dds]], effectType = BUFF_EFFECT_TYPE_DEBUFF, abilityType = ABILITY_TYPE_BONUS },
    -- player ground
    [916013] = { auraName = strformat('%s %d', L.SampleAura_PlayerGround, 1), unitTag = '', duration = 10, icon = [[/esoui/art/icons/ability_destructionstaff_008.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_AREAEFFECT },
    [916014] = { auraName = strformat('%s %d', L.SampleAura_PlayerGround, 2), unitTag = '', duration = 30, icon = [[/esoui/art/icons/ability_destructionstaff_011.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_AREAEFFECT },
    -- player major|minor buffs
    [916015] = { auraName = strformat('%s %d', L.SampleAura_PlayerMajor, 1), unitTag = 'player', duration = 30, icon = [[/esoui/art/icons/ability_sorcerer_boundless_storm.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916016] = { auraName = strformat('%s %d', L.SampleAura_PlayerMinor, 1), unitTag = 'player', duration = 30, icon = [[/esoui/art/icons/ability_sorcerer_boundless_storm.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    -- target buff (2 timeds and 1 passive)
    [916017] = { auraName = strformat('%s %d', L.SampleAura_TargetBuff, 1), unitTag = 'reticleover', duration = 10, icon = [[esoui/art/icons/ability_restorationstaff_004.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916018] = { auraName = strformat('%s %d', L.SampleAura_TargetBuff, 2), unitTag = 'reticleover', duration = 30, icon = [[esoui/art/icons/ability_restorationstaff_005.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    [916019] = { auraName = strformat('%s %d', L.SampleAura_TargetBuff, 3), unitTag = 'reticleover', duration = 0, icon = [[/esoui/art/icons/ability_armor_001.dds]], effectType = BUFF_EFFECT_TYPE_BUFF, abilityType = ABILITY_TYPE_BONUS },
    -- target debuff
    [916020] = { auraName = strformat('%s %d', L.SampleAura_TargetDebuff, 1), unitTag = 'reticleover', duration = 10, icon = [[esoui/art/icons/ability_nightblade_003.dds]], effectType = BUFF_EFFECT_TYPE_DEBUFF, abilityType = ABILITY_TYPE_BONUS },
    [916021] = { auraName = strformat('%s %d', L.SampleAura_TargetDebuff, 2), unitTag = 'reticleover', duration = 30, icon = [[esoui/art/icons/ability_nightblade_004.dds]], effectType = BUFF_EFFECT_TYPE_DEBUFF, abilityType = ABILITY_TYPE_BONUS },
}

local groupUnit =
{
    ['group1']  = true,
    ['group2']  = true,
    ['group3']  = true,
    ['group4']  = true,
    ['group5']  = true,
    ['group6']  = true,
    ['group7']  = true,
    ['group8']  = true,
    ['group9']  = true,
    ['group10'] = true,
    ['group11'] = true,
    ['group12'] = true,
    ['group13'] = true,
    ['group14'] = true,
    ['group15'] = true,
    ['group16'] = true,
    ['group17'] = true,
    ['group18'] = true,
    ['group19'] = true,
    ['group20'] = true,
    ['group21'] = true,
    ['group22'] = true,
    ['group23'] = true,
    ['group24'] = true,
}


-- Permanent Trial dummy debuffs that are not Major/Minor (NPC-applied; shown with Only Player Debuffs)
local alwaysShowTargetDebuffs =
{
    [120007] = true, -- Crusher (Target Iron Atronach, Trial)
    [120011] = true, -- Engulfing Flames (Target Iron Atronach, Trial)
    [120018] = true, -- Roar of Alkosh (Target Iron Atronach, Trial)
}

-- ------------------------
-- AURA DATA FUNCTIONS
-- ------------------------
function Srendarr.IsToggledAura(abilityID)
    return toggledAuras[abilityID] and true or false
end

function Srendarr.IsMajorEffect(abilityID)
    return majorEffects[abilityID] and true or false
end

function Srendarr.IsMinorEffect(abilityID)
    return minorEffects[abilityID] and true or false
end

function Srendarr.IsAlwaysShowTargetDebuff(abilityID)
    return alwaysShowTargetDebuffs[abilityID] and true or false
end

function Srendarr.IsEnchantProc(abilityID)
    if enchantProcs[abilityID] ~= nil then return true else return false end
end

function Srendarr.IsAlternateAura(abilityID)
    if alternateAura[abilityID] ~= nil then return true else return false end
end

function Srendarr.IsGroupUnit(unitTag)
    if groupUnit[unitTag] ~= nil then return true else return false end
end

function Srendarr:PopulateFilteredAuras()
    for _, filterUnitTag in pairs(filteredAuras) do
        for id in pairs(filterUnitTag) do
            if (not filterAlwaysIgnored[id]) then
                filterUnitTag[id] = nil -- clean out existing filters unless always ignored
            end
        end
    end

    -- populate player aura filters
    for filterGroup, doFilter in pairs(self.db.filtersPlayer) do
        if (filterAuraGroups[filterGroup] and doFilter) then -- filtering this group for player
            for id in pairs(filterAuraGroups[filterGroup]) do
                filteredAuras.player[id] = true
            end
        end
    end

    -- populate target aura filters
    for filterGroup, doFilter in pairs(self.db.filtersTarget) do
        if (doFilter) then
            if (filterGroup == 'majorEffects') and (not Srendarr.db.onlyTargetMajor) then -- special case for majorEffects
                for id in pairs(majorEffects) do
                    filteredAuras.reticleover[id] = true
                end
            elseif (filterGroup == 'minorEffects') then -- special case for minorEffects
                for id in pairs(minorEffects) do
                    filteredAuras.reticleover[id] = true
                end
            elseif (filterAuraGroups[filterGroup]) then
                for id in pairs(filterAuraGroups[filterGroup]) do
                    filteredAuras.reticleover[id] = true
                end
            end
        end
    end

    -- populate ground aoe filters

    -- add blacklisted auras to all filter tables
    for _, filterForUnitTag in pairs(filteredAuras) do
        for _, abilityIDs in pairs(self.db.blacklist) do
            for id in pairs(abilityIDs) do
                filterForUnitTag[id] = true
            end
        end
    end
end

-- ------------------------
-- MINOR & MAJOR EFFECT DATA
-- ------------------------
minorEffects =
{

    -- Minor Aegis
    [76618] = EFFECT_AEGIS,
    [147225] = EFFECT_AEGIS,
    [181841] = EFFECT_AEGIS,
    -- Minor Berserk
    [61744] = EFFECT_BERSERK,
    [62636] = EFFECT_BERSERK,
    [80471] = EFFECT_BERSERK,
    [80481] = EFFECT_BERSERK,
    [114862] = EFFECT_BERSERK,
    [120008] = EFFECT_BERSERK,
    [150782] = EFFECT_BERSERK,
    [174982] = EFFECT_BERSERK,
    [175655] = EFFECT_BERSERK,
    [176704] = EFFECT_BERSERK,
    [196184] = EFFECT_BERSERK,
    [123323] = EFFECT_BERSERK,
    [214428] = EFFECT_BERSERK,
    [237972] = EFFECT_BERSERK,
    [238541] = EFFECT_BERSERK,
    [258640] = EFFECT_BERSERK,
    [267570] = EFFECT_BERSERK,
    [243916] = EFFECT_BERSERK,
    [243917] = EFFECT_BERSERK,
    [242718] = EFFECT_BERSERK,
    [218988] = EFFECT_BERSERK,
    [217203] = EFFECT_BERSERK,
    [238020] = EFFECT_BERSERK,
    [191765] = EFFECT_BERSERK,
    [255326] = EFFECT_BERSERK,
    [249092] = EFFECT_BERSERK,
    -- Minor Breach
    [38688] = EFFECT_BREACH,
    [61742] = EFFECT_BREACH,
    [68588] = EFFECT_BREACH,
    [83031] = EFFECT_BREACH,
    [84358] = EFFECT_BREACH,
    [108825] = EFFECT_BREACH,
    [120019] = EFFECT_BREACH,
    [126685] = EFFECT_BREACH,
    [146908] = EFFECT_BREACH,
    [148803] = EFFECT_BREACH,
    [175667] = EFFECT_BREACH,
    [190180] = EFFECT_BREACH,
    [193278] = EFFECT_BREACH,
    [183649] = EFFECT_BREACH,
    [185910] = EFFECT_BREACH,
    [186479] = EFFECT_BREACH,
    [213104] = EFFECT_BREACH,
    [211843] = EFFECT_BREACH,
    [209396] = EFFECT_BREACH,
    [212214] = EFFECT_BREACH,
    [210551] = EFFECT_BREACH,
    [212168] = EFFECT_BREACH,
    [205144] = EFFECT_BREACH,
    [218010] = EFFECT_BREACH,
    [221683] = EFFECT_BREACH,
    [212243] = EFFECT_BREACH,
    [212111] = EFFECT_BREACH,
    [230694] = EFFECT_BREACH,
    [238257] = EFFECT_BREACH,
    [259089] = EFFECT_BREACH,
    [259347] = EFFECT_BREACH,
    [249083] = EFFECT_BREACH,
    [259129] = EFFECT_BREACH,
    [259137] = EFFECT_BREACH,
    [217196] = EFFECT_BREACH,
    [218013] = EFFECT_BREACH,
    -- Minor Brittle
    [145975] = EFFECT_BRITTLE,
    [146697] = EFFECT_BRITTLE,
    [148977] = EFFECT_BRITTLE,
    [184986] = EFFECT_BRITTLE,
    [221725] = EFFECT_BRITTLE,
    [235890] = EFFECT_BRITTLE,
    [259326] = EFFECT_BRITTLE,
    [249087] = EFFECT_BRITTLE,
    [219247] = EFFECT_BRITTLE,
    -- Minor Brutality
    [61662] = EFFECT_BRUTALITY,
    [61798] = EFFECT_BRUTALITY,
    [61799] = EFFECT_BRUTALITY,
    [79281] = EFFECT_BRUTALITY,
    [79283] = EFFECT_BRUTALITY,
    [120023] = EFFECT_BRUTALITY,
    [214416] = EFFECT_BRUTALITY,
    [259761] = EFFECT_BRUTALITY,
    [219749] = EFFECT_BRUTALITY,
    [220313] = EFFECT_BRUTALITY,
    -- Minor Courage
    [121878] = EFFECT_COURAGE,
    [137348] = EFFECT_COURAGE,
    [147417] = EFFECT_COURAGE,
    [159310] = EFFECT_COURAGE,
    [159341] = EFFECT_COURAGE,
    [159352] = EFFECT_COURAGE,
    [159356] = EFFECT_COURAGE,
    [160394] = EFFECT_COURAGE,
    [175664] = EFFECT_COURAGE,
    [172721] = EFFECT_COURAGE,
    [176883] = EFFECT_COURAGE,
    [177885] = EFFECT_COURAGE,
    [187940] = EFFECT_COURAGE,
    [183579] = EFFECT_COURAGE,
    [186230] = EFFECT_COURAGE,
    [186235] = EFFECT_COURAGE,
    [214410] = EFFECT_COURAGE,
    [236475] = EFFECT_COURAGE,
    [259634] = EFFECT_COURAGE,
    [180949] = EFFECT_COURAGE,
    [217967] = EFFECT_COURAGE,
    -- Minor Cowardice
    [46202] = EFFECT_COWARDICE,
    [46244] = EFFECT_COWARDICE,
    [51443] = EFFECT_COWARDICE,
    [79069] = EFFECT_COWARDICE,
    [79082] = EFFECT_COWARDICE,
    [79193] = EFFECT_COWARDICE,
    [79278] = EFFECT_COWARDICE,
    [79867] = EFFECT_COWARDICE,
    [126675] = EFFECT_COWARDICE,
    [175671] = EFFECT_COWARDICE,
    [221718] = EFFECT_COWARDICE,
    [219109] = EFFECT_COWARDICE,
    [263414] = EFFECT_COWARDICE,
    [217253] = EFFECT_COWARDICE,
    -- Minor Defile
    [21927] = EFFECT_DEFILE,
    [38686] = EFFECT_DEFILE,
    [61726] = EFFECT_DEFILE,
    [78606] = EFFECT_DEFILE,
    [79851] = EFFECT_DEFILE,
    [79854] = EFFECT_DEFILE,
    [79857] = EFFECT_DEFILE,
    [79860] = EFFECT_DEFILE,
    [79861] = EFFECT_DEFILE,
    [79862] = EFFECT_DEFILE,
    [85637] = EFFECT_DEFILE,
    [88470] = EFFECT_DEFILE,
    [114206] = EFFECT_DEFILE,
    [117885] = EFFECT_DEFILE,
    [117890] = EFFECT_DEFILE,
    [134427] = EFFECT_DEFILE,
    [134445] = EFFECT_DEFILE,
    [183391] = EFFECT_DEFILE,
    [213342] = EFFECT_DEFILE,
    [223923] = EFFECT_DEFILE,
    [238253] = EFFECT_DEFILE,
    [249063] = EFFECT_DEFILE,
    [217914] = EFFECT_DEFILE,
    [76947] = EFFECT_DEFILE,
    -- Minor Endurance
    [26215] = EFFECT_ENDURANCE,
    [61704] = EFFECT_ENDURANCE,
    [80271] = EFFECT_ENDURANCE,
    [80276] = EFFECT_ENDURANCE,
    [80284] = EFFECT_ENDURANCE,
    [87019] = EFFECT_ENDURANCE,
    [124703] = EFFECT_ENDURANCE,
    [126527] = EFFECT_ENDURANCE,
    [126534] = EFFECT_ENDURANCE,
    [126537] = EFFECT_ENDURANCE,
    [137212] = EFFECT_ENDURANCE,
    [175661] = EFFECT_ENDURANCE,
    [176150] = EFFECT_ENDURANCE,
    [177260] = EFFECT_ENDURANCE,
    [177301] = EFFECT_ENDURANCE,
    [177303] = EFFECT_ENDURANCE,
    [186236] = EFFECT_ENDURANCE,
    [187941] = EFFECT_ENDURANCE,
    [183580] = EFFECT_ENDURANCE,
    [186231] = EFFECT_ENDURANCE,
    [238542] = EFFECT_ENDURANCE,
    [238022] = EFFECT_ENDURANCE,
    [246073] = EFFECT_ENDURANCE,
    [240485] = EFFECT_ENDURANCE,
    [216792] = EFFECT_ENDURANCE,
    [217662] = EFFECT_ENDURANCE,
    [240483] = EFFECT_ENDURANCE,
    [217404] = EFFECT_ENDURANCE,
    [240045] = EFFECT_ENDURANCE,
    [260246] = EFFECT_ENDURANCE,
    [227123] = EFFECT_ENDURANCE,
    -- Minor Enervation
    [47202] = EFFECT_ENERVATION,
    [47203] = EFFECT_ENERVATION,
    [79113] = EFFECT_ENERVATION,
    [79116] = EFFECT_ENERVATION,
    [79450] = EFFECT_ENERVATION,
    [79454] = EFFECT_ENERVATION,
    [79907] = EFFECT_ENERVATION,
    [92921] = EFFECT_ENERVATION,
    [134040] = EFFECT_ENERVATION,
    [166837] = EFFECT_ENERVATION,
    [214492] = EFFECT_ENERVATION,
    [249096] = EFFECT_ENERVATION,
    [217913] = EFFECT_ENERVATION,
    [260578] = EFFECT_ENERVATION,
    [260579] = EFFECT_ENERVATION,
    [226700] = EFFECT_ENERVATION,
    [218012] = EFFECT_ENERVATION,
    [168463] = EFFECT_ENERVATION,
    -- Minor Evasion
    [61715] = EFFECT_EVASION,
    [114858] = EFFECT_EVASION,
    [187865] = EFFECT_EVASION,
    [184931] = EFFECT_EVASION,
    [184933] = EFFECT_EVASION,
    [240740] = EFFECT_EVASION,
    -- Minor Expedition
    [34741] = EFFECT_EXPEDITION,
    [40219] = EFFECT_EXPEDITION,
    [61735] = EFFECT_EXPEDITION,
    [82797] = EFFECT_EXPEDITION,
    [85602] = EFFECT_EXPEDITION,
    [106860] = EFFECT_EXPEDITION,
    [108935] = EFFECT_EXPEDITION,
    [125901] = EFFECT_EXPEDITION,
    [214996] = EFFECT_EXPEDITION,
    [249082] = EFFECT_EXPEDITION,
    [217363] = EFFECT_EXPEDITION,
    -- Minor Force
    [61746] = EFFECT_FORCE,
    [68595] = EFFECT_FORCE,
    [68628] = EFFECT_FORCE,
    [68632] = EFFECT_FORCE,
    [76564] = EFFECT_FORCE,
    [80984] = EFFECT_FORCE,
    [80986] = EFFECT_FORCE,
    [85611] = EFFECT_FORCE,
    [103521] = EFFECT_FORCE,
    [103708] = EFFECT_FORCE,
    [103712] = EFFECT_FORCE,
    [106861] = EFFECT_FORCE,
    [116775] = EFFECT_FORCE,
    [143685] = EFFECT_FORCE,
    [143706] = EFFECT_FORCE,
    [144032] = EFFECT_FORCE,
    [176703] = EFFECT_FORCE,
    [176852] = EFFECT_FORCE,
    [180953] = EFFECT_FORCE,
    [188427] = EFFECT_FORCE,
    [193448] = EFFECT_FORCE,
    [200082] = EFFECT_FORCE,
    [214863] = EFFECT_FORCE,
    [240484] = EFFECT_FORCE,
    [237721] = EFFECT_FORCE,
    [256698] = EFFECT_FORCE,
    [260752] = EFFECT_FORCE,
    [249086] = EFFECT_FORCE,
    [238191] = EFFECT_FORCE,
    [260742] = EFFECT_FORCE,
    [217887] = EFFECT_FORCE,
    -- Minor Fortitude
    [26213] = EFFECT_FORTITUDE,
    [26220] = EFFECT_FORTITUDE,
    [61697] = EFFECT_FORTITUDE,
    [124701] = EFFECT_FORTITUDE,
    [137210] = EFFECT_FORTITUDE,
    [176117] = EFFECT_FORTITUDE,
    [186232] = EFFECT_FORTITUDE,
    [187942] = EFFECT_FORTITUDE,
    [185750] = EFFECT_FORTITUDE,
    [186239] = EFFECT_FORTITUDE,
    [238021] = EFFECT_FORTITUDE,
    [238543] = EFFECT_FORTITUDE,
    [258548] = EFFECT_FORTITUDE,
    [258585] = EFFECT_FORTITUDE,
    [258619] = EFFECT_FORTITUDE,
    [237717] = EFFECT_FORTITUDE,
    -- Minor Gallop
    -- Minor Heroism
    [61708] = EFFECT_HEROISM,
    [62505] = EFFECT_HEROISM,
    [85593] = EFFECT_HEROISM,
    [113284] = EFFECT_HEROISM,
    [113355] = EFFECT_HEROISM,
    [125027] = EFFECT_HEROISM,
    [125041] = EFFECT_HEROISM,
    [125204] = EFFECT_HEROISM,
    [125206] = EFFECT_HEROISM,
    [129536] = EFFECT_HEROISM,
    [155993] = EFFECT_HEROISM,
    [176706] = EFFECT_HEROISM,
    [187948] = EFFECT_HEROISM,
    [191063] = EFFECT_HEROISM,
    [192741] = EFFECT_HEROISM,
    [210079] = EFFECT_HEROISM,
    [210901] = EFFECT_HEROISM,
    [261912] = EFFECT_HEROISM,
    [20780] = EFFECT_HEROISM,
    [29126] = EFFECT_HEROISM,
    [258618] = EFFECT_HEROISM,
    [217968] = EFFECT_HEROISM,
    [272533] = EFFECT_HEROISM,
    [272010] = EFFECT_HEROISM,
    [272539] = EFFECT_HEROISM,
    [272004] = EFFECT_HEROISM,
    [265933] = EFFECT_HEROISM,
    [196750] = EFFECT_HEROISM,
    [272543] = EFFECT_HEROISM,
    -- Minor Hindrance
    -- Minor Intellect
    [26216] = EFFECT_INTELLECT,
    [36740] = EFFECT_INTELLECT,
    [61706] = EFFECT_INTELLECT,
    [77418] = EFFECT_INTELLECT,
    [86300] = EFFECT_INTELLECT,
    [124702] = EFFECT_INTELLECT,
    [175660] = EFFECT_INTELLECT,
    [176141] = EFFECT_INTELLECT,
    [177302] = EFFECT_INTELLECT,
    [177304] = EFFECT_INTELLECT,
    [186240] = EFFECT_INTELLECT,
    [186233] = EFFECT_INTELLECT,
    [185751] = EFFECT_INTELLECT,
    [187943] = EFFECT_INTELLECT,
    [238544] = EFFECT_INTELLECT,
    [238023] = EFFECT_INTELLECT,
    [217521] = EFFECT_INTELLECT,
    [240044] = EFFECT_INTELLECT,
    [217965] = EFFECT_INTELLECT,
    [217661] = EFFECT_INTELLECT,
    [227124] = EFFECT_INTELLECT,
    -- Minor Lifesteal
    [80020] = EFFECT_LIFESTEAL,
    [86304] = EFFECT_LIFESTEAL,
    [86307] = EFFECT_LIFESTEAL,
    [88565] = EFFECT_LIFESTEAL,
    [88575] = EFFECT_LIFESTEAL,
    [88606] = EFFECT_LIFESTEAL,
    [121634] = EFFECT_LIFESTEAL,
    [187757] = EFFECT_LIFESTEAL,
    [217912] = EFFECT_LIFESTEAL,
    [218991] = EFFECT_LIFESTEAL,
    [241536] = EFFECT_LIFESTEAL,
    [217783] = EFFECT_LIFESTEAL,
    -- Minor Magickasteal
    [39100] = EFFECT_MAGICKASTEAL,
    [88401] = EFFECT_MAGICKASTEAL,
    [88576] = EFFECT_MAGICKASTEAL,
    [148798] = EFFECT_MAGICKASTEAL,
    [149012] = EFFECT_MAGICKASTEAL,
    [214421] = EFFECT_MAGICKASTEAL,
    [214324] = EFFECT_MAGICKASTEAL,
    [253647] = EFFECT_MAGICKASTEAL,
    [217520] = EFFECT_MAGICKASTEAL,
    [218014] = EFFECT_MAGICKASTEAL,
    [217915] = EFFECT_MAGICKASTEAL,
    -- Minor Maim
    [29308] = EFFECT_MAIM,
    [31899] = EFFECT_MAIM,
    [33228] = EFFECT_MAIM,
    [33512] = EFFECT_MAIM,
    [44206] = EFFECT_MAIM,
    [46204] = EFFECT_MAIM,
    [46246] = EFFECT_MAIM,
    [51558] = EFFECT_MAIM,
    [61723] = EFFECT_MAIM,
    [62495] = EFFECT_MAIM,
    [62504] = EFFECT_MAIM,
    [68368] = EFFECT_MAIM,
    [79083] = EFFECT_MAIM,
    [79085] = EFFECT_MAIM,
    [79280] = EFFECT_MAIM,
    [79282] = EFFECT_MAIM,
    [80848] = EFFECT_MAIM,
    [80990] = EFFECT_MAIM,
    [89012] = EFFECT_MAIM,
    [91174] = EFFECT_MAIM,
    [102097] = EFFECT_MAIM,
    [108939] = EFFECT_MAIM,
    [118313] = EFFECT_MAIM,
    [121517] = EFFECT_MAIM,
    [123946] = EFFECT_MAIM,
    [172523] = EFFECT_MAIM,
    [186532] = EFFECT_MAIM,
    [196187] = EFFECT_MAIM,
    [183166] = EFFECT_MAIM,
    [183431] = EFFECT_MAIM,
    [212397] = EFFECT_MAIM,
    [221722] = EFFECT_MAIM,
    [234093] = EFFECT_MAIM,
    [234094] = EFFECT_MAIM,
    [234096] = EFFECT_MAIM,
    [213304] = EFFECT_MAIM,
    [224389] = EFFECT_MAIM,
    [238229] = EFFECT_MAIM,
    [238239] = EFFECT_MAIM,
    [256009] = EFFECT_MAIM,
    [255674] = EFFECT_MAIM,
    [253164] = EFFECT_MAIM,
    [249060] = EFFECT_MAIM,
    [240559] = EFFECT_MAIM,
    [218000] = EFFECT_MAIM,
    [81034] = EFFECT_MAIM,
    [217405] = EFFECT_MAIM,
    [217884] = EFFECT_MAIM,
    [267261] = EFFECT_MAIM,
    [218990] = EFFECT_MAIM,
    [217782] = EFFECT_MAIM,
    -- Minor Mangle
    [39168] = EFFECT_MANGLE,
    [39180] = EFFECT_MANGLE,
    [39181] = EFFECT_MANGLE,
    [61733] = EFFECT_MANGLE,
    [91334] = EFFECT_MANGLE,
    [91337] = EFFECT_MANGLE,
    [93363] = EFFECT_MANGLE,
    [249081] = EFFECT_MANGLE,
    [223865] = EFFECT_MANGLE,
    [91340] = EFFECT_MANGLE,
    [217199] = EFFECT_MANGLE,
    [200433] = EFFECT_MANGLE,
    [223863] = EFFECT_MANGLE,
    -- Minor Mending
    [29096] = EFFECT_MENDING,
    [61710] = EFFECT_MENDING,
    [108934] = EFFECT_MENDING,
    [113307] = EFFECT_MENDING,
    [134627] = EFFECT_MENDING,
    [179940] = EFFECT_MENDING,
    [213952] = EFFECT_MENDING,
    [260731] = EFFECT_MENDING,
    [163684] = EFFECT_MENDING,
    [260725] = EFFECT_MENDING,
    [249062] = EFFECT_MENDING,
    -- Minor Prophecy
    [61691] = EFFECT_PROPHECY,
    [120028] = EFFECT_PROPHECY,
    [214415] = EFFECT_PROPHECY,
    [237784] = EFFECT_PROPHECY,
    [253590] = EFFECT_PROPHECY,
    -- Minor Protection
    [35739] = EFFECT_PROTECTION,
    [40171] = EFFECT_PROTECTION,
    [40185] = EFFECT_PROTECTION,
    [61721] = EFFECT_PROTECTION,
    [62475] = EFFECT_PROTECTION,
    [79712] = EFFECT_PROTECTION,
    [79714] = EFFECT_PROTECTION,
    [79725] = EFFECT_PROTECTION,
    [79727] = EFFECT_PROTECTION,
    [85551] = EFFECT_PROTECTION,
    [87194] = EFFECT_PROTECTION,
    [103570] = EFFECT_PROTECTION,
    [108913] = EFFECT_PROTECTION,
    [113356] = EFFECT_PROTECTION,
    [114838] = EFFECT_PROTECTION,
    [114841] = EFFECT_PROTECTION,
    [115097] = EFFECT_PROTECTION,
    [118385] = EFFECT_PROTECTION,
    [118409] = EFFECT_PROTECTION,
    [146795] = EFFECT_PROTECTION,
    [146796] = EFFECT_PROTECTION,
    [146797] = EFFECT_PROTECTION,
    [176700] = EFFECT_PROTECTION,
    [179755] = EFFECT_PROTECTION,
    [186493] = EFFECT_PROTECTION,
    [194597] = EFFECT_PROTECTION,
    [193277] = EFFECT_PROTECTION,
    [194647] = EFFECT_PROTECTION,
    [203344] = EFFECT_PROTECTION,
    [203438] = EFFECT_PROTECTION,
    [203440] = EFFECT_PROTECTION,
    [213458] = EFFECT_PROTECTION,
    [221103] = EFFECT_PROTECTION,
    [236328] = EFFECT_PROTECTION,
    [238263] = EFFECT_PROTECTION,
    [228176] = EFFECT_PROTECTION,
    [32753] = EFFECT_PROTECTION,
    [246072] = EFFECT_PROTECTION,
    [241459] = EFFECT_PROTECTION,
    [108849] = EFFECT_PROTECTION,
    [213459] = EFFECT_PROTECTION,
    [108855] = EFFECT_PROTECTION,
    [249059] = EFFECT_PROTECTION,
    [217966] = EFFECT_PROTECTION,
    [218343] = EFFECT_PROTECTION,
    -- Minor Resolve
    [37247] = EFFECT_RESOLVE,
    [61693] = EFFECT_RESOLVE,
    [61817] = EFFECT_RESOLVE,
    [62626] = EFFECT_RESOLVE,
    [62634] = EFFECT_RESOLVE,
    [108856] = EFFECT_RESOLVE,
    [159311] = EFFECT_RESOLVE,
    [159340] = EFFECT_RESOLVE,
    [159350] = EFFECT_RESOLVE,
    [159358] = EFFECT_RESOLVE,
    [174981] = EFFECT_RESOLVE,
    [176991] = EFFECT_RESOLVE,
    [183424] = EFFECT_RESOLVE,
    [185913] = EFFECT_RESOLVE,
    [186490] = EFFECT_RESOLVE,
    [221104] = EFFECT_RESOLVE,
    [228053] = EFFECT_RESOLVE,
    [228054] = EFFECT_RESOLVE,
    [228063] = EFFECT_RESOLVE,
    [238264] = EFFECT_RESOLVE,
    [241528] = EFFECT_RESOLVE,
    [255184] = EFFECT_RESOLVE,
    [217625] = EFFECT_RESOLVE,
    [217522] = EFFECT_RESOLVE,
    -- Minor Savagery
    [61666] = EFFECT_SAVAGERY,
    [61882] = EFFECT_SAVAGERY,
    [61898] = EFFECT_SAVAGERY,
    [79453] = EFFECT_SAVAGERY,
    [79455] = EFFECT_SAVAGERY,
    [120029] = EFFECT_SAVAGERY,
    [214427] = EFFECT_SAVAGERY,
    [237783] = EFFECT_SAVAGERY,
    [241189] = EFFECT_SAVAGERY,
    [249094] = EFFECT_SAVAGERY,
    -- Minor Slayer
    [76617] = EFFECT_SLAYER,
    [147226] = EFFECT_SLAYER,
    [181840] = EFFECT_SLAYER,
    -- Minor Sorcery
    [61685] = EFFECT_SORCERY,
    [120017] = EFFECT_SORCERY,
    [214417] = EFFECT_SORCERY,
    -- Minor Timidity
    [134149] = EFFECT_TIMIDITY,
    [134150] = EFFECT_TIMIDITY,
    [140699] = EFFECT_TIMIDITY,
    [140700] = EFFECT_TIMIDITY,
    [140701] = EFFECT_TIMIDITY,
    [167738] = EFFECT_TIMIDITY,
    [242729] = EFFECT_TIMIDITY,
    [261345] = EFFECT_TIMIDITY,
    [125205] = EFFECT_TIMIDITY,
    [125203] = EFFECT_TIMIDITY,
    -- Minor Toughness
    [88490] = EFFECT_TOUGHNESS,
    [88492] = EFFECT_TOUGHNESS,
    [88509] = EFFECT_TOUGHNESS,
    [92762] = EFFECT_TOUGHNESS,
    [120020] = EFFECT_TOUGHNESS,
    [214420] = EFFECT_TOUGHNESS,
    [221105] = EFFECT_TOUGHNESS,
    [249088] = EFFECT_TOUGHNESS,
    -- Minor Uncertainty
    [47204] = EFFECT_UNCERTAINTY,
    [47205] = EFFECT_UNCERTAINTY,
    [79117] = EFFECT_UNCERTAINTY,
    [79118] = EFFECT_UNCERTAINTY,
    [79446] = EFFECT_UNCERTAINTY,
    [79448] = EFFECT_UNCERTAINTY,
    [79895] = EFFECT_UNCERTAINTY,
    [134034] = EFFECT_UNCERTAINTY,
    [249089] = EFFECT_UNCERTAINTY,
    [218992] = EFFECT_UNCERTAINTY,
    -- Minor Vitality
    [61549] = EFFECT_VITALITY,
    [64080] = EFFECT_VITALITY,
    [79852] = EFFECT_VITALITY,
    [79855] = EFFECT_VITALITY,
    [80953] = EFFECT_VITALITY,
    [85565] = EFFECT_VITALITY,
    [91670] = EFFECT_VITALITY,
    [108832] = EFFECT_VITALITY,
    [113306] = EFFECT_VITALITY,
    [126925] = EFFECT_VITALITY,
    [188505] = EFFECT_VITALITY,
    [211370] = EFFECT_VITALITY,
    [256018] = EFFECT_VITALITY,
    [242714] = EFFECT_VITALITY,
    [249080] = EFFECT_VITALITY,
    -- Minor Vulnerability
    [42062] = EFFECT_VULNERABILITY,
    [51434] = EFFECT_VULNERABILITY,
    [61782] = EFFECT_VULNERABILITY,
    [68359] = EFFECT_VULNERABILITY,
    [79715] = EFFECT_VULNERABILITY,
    [79717] = EFFECT_VULNERABILITY,
    [79720] = EFFECT_VULNERABILITY,
    [79723] = EFFECT_VULNERABILITY,
    [79726] = EFFECT_VULNERABILITY,
    [79844] = EFFECT_VULNERABILITY,
    [79846] = EFFECT_VULNERABILITY,
    [81519] = EFFECT_VULNERABILITY,
    [117025] = EFFECT_VULNERABILITY,
    [118613] = EFFECT_VULNERABILITY,
    [120030] = EFFECT_VULNERABILITY,
    [124803] = EFFECT_VULNERABILITY,
    [124804] = EFFECT_VULNERABILITY,
    [124806] = EFFECT_VULNERABILITY,
    [130155] = EFFECT_VULNERABILITY,
    [130168] = EFFECT_VULNERABILITY,
    [130173] = EFFECT_VULNERABILITY,
    [185920] = EFFECT_VULNERABILITY,
    [185449] = EFFECT_VULNERABILITY,
    [186754] = EFFECT_VULNERABILITY,
    [191299] = EFFECT_VULNERABILITY,
    [185923] = EFFECT_VULNERABILITY,
    [183271] = EFFECT_VULNERABILITY,
    [208043] = EFFECT_VULNERABILITY,
    [221728] = EFFECT_VULNERABILITY,
    [204879] = EFFECT_VULNERABILITY,
    [228104] = EFFECT_VULNERABILITY,
    [228115] = EFFECT_VULNERABILITY,
    [228118] = EFFECT_VULNERABILITY,
    [238097] = EFFECT_VULNERABILITY,
    [238269] = EFFECT_VULNERABILITY,
    [224387] = EFFECT_VULNERABILITY,
    [259088] = EFFECT_VULNERABILITY,
    [259345] = EFFECT_VULNERABILITY,
    [259130] = EFFECT_VULNERABILITY,
    [249093] = EFFECT_VULNERABILITY,
    [242719] = EFFECT_VULNERABILITY,
    [214992] = EFFECT_VULNERABILITY,
    [218989] = EFFECT_VULNERABILITY,
    [217666] = EFFECT_VULNERABILITY,
    [217658] = EFFECT_VULNERABILITY,
    -- Minor Vexation (P51 BuffType 64; populated from FullUpdate dump)
    [260855] = EFFECT_VEXATION,
    [260730] = EFFECT_VEXATION,
    [263403] = EFFECT_VEXATION,
    [260724] = EFFECT_VEXATION,
    [260860] = EFFECT_VEXATION,
    [260859] = EFFECT_VEXATION,
    [260863] = EFFECT_VEXATION,
}

majorEffects =
{

    -- Major Aegis
    [93123] = EFFECT_AEGIS,
    [93125] = EFFECT_AEGIS,
    [93444] = EFFECT_AEGIS,
    [135926] = EFFECT_AEGIS,
    [137989] = EFFECT_AEGIS,
    [179756] = EFFECT_AEGIS,
    [193731] = EFFECT_AEGIS,
    [194171] = EFFECT_AEGIS,
    -- Major Berserk
    [36973] = EFFECT_BERSERK,
    [61745] = EFFECT_BERSERK,
    [62195] = EFFECT_BERSERK,
    [84310] = EFFECT_BERSERK,
    [134094] = EFFECT_BERSERK,
    [134433] = EFFECT_BERSERK,
    [143992] = EFFECT_BERSERK,
    [147421] = EFFECT_BERSERK,
    [150757] = EFFECT_BERSERK,
    [172866] = EFFECT_BERSERK,
    [188408] = EFFECT_BERSERK,
    [219674] = EFFECT_BERSERK,
    [221601] = EFFECT_BERSERK,
    [263248] = EFFECT_BERSERK,
    [267420] = EFFECT_BERSERK,
    [263306] = EFFECT_BERSERK,
    [249159] = EFFECT_BERSERK,
    [237624] = EFFECT_BERSERK,
    [246057] = EFFECT_BERSERK,
    [238078] = EFFECT_BERSERK,
    -- Major Breach
    [28307] = EFFECT_BREACH,
    [33363] = EFFECT_BREACH,
    [34386] = EFFECT_BREACH,
    [36972] = EFFECT_BREACH,
    [36980] = EFFECT_BREACH,
    [40254] = EFFECT_BREACH,
    [48946] = EFFECT_BREACH,
    [53881] = EFFECT_BREACH,
    [61743] = EFFECT_BREACH,
    [62474] = EFFECT_BREACH,
    [62485] = EFFECT_BREACH,
    [62775] = EFFECT_BREACH,
    [62787] = EFFECT_BREACH,
    [78609] = EFFECT_BREACH,
    [85362] = EFFECT_BREACH,
    [91175] = EFFECT_BREACH,
    [91200] = EFFECT_BREACH,
    [100988] = EFFECT_BREACH,
    [103628] = EFFECT_BREACH,
    [108951] = EFFECT_BREACH,
    [117818] = EFFECT_BREACH,
    [118438] = EFFECT_BREACH,
    [120010] = EFFECT_BREACH,
    [163062] = EFFECT_BREACH,
    [167888] = EFFECT_BREACH,
    [194997] = EFFECT_BREACH,
    [196546] = EFFECT_BREACH,
    [190219] = EFFECT_BREACH,
    [192892] = EFFECT_BREACH,
    [192837] = EFFECT_BREACH,
    [193226] = EFFECT_BREACH,
    [191763] = EFFECT_BREACH,
    [209725] = EFFECT_BREACH,
    [213286] = EFFECT_BREACH,
    [215812] = EFFECT_BREACH,
    [240548] = EFFECT_BREACH,
    [137321] = EFFECT_BREACH,
    [226349] = EFFECT_BREACH,
    [226553] = EFFECT_BREACH,
    [237604] = EFFECT_BREACH,
    [216945] = EFFECT_BREACH,
    [237003] = EFFECT_BREACH,
    [241447] = EFFECT_BREACH,
    -- Major Brittle
    [145977] = EFFECT_BRITTLE,
    [167681] = EFFECT_BRITTLE,
    [263825] = EFFECT_BRITTLE,
    [256736] = EFFECT_BRITTLE,
    -- Major Brutality
    [23673] = EFFECT_BRUTALITY,
    [36903] = EFFECT_BRUTALITY,
    [61665] = EFFECT_BRUTALITY,
    [61670] = EFFECT_BRUTALITY,
    [62060] = EFFECT_BRUTALITY,
    [62147] = EFFECT_BRUTALITY,
    [62387] = EFFECT_BRUTALITY,
    [62415] = EFFECT_BRUTALITY,
    [63768] = EFFECT_BRUTALITY,
    [64554] = EFFECT_BRUTALITY,
    [64555] = EFFECT_BRUTALITY,
    [68807] = EFFECT_BRUTALITY,
    [72936] = EFFECT_BRUTALITY,
    [76518] = EFFECT_BRUTALITY,
    [81517] = EFFECT_BRUTALITY,
    [86695] = EFFECT_BRUTALITY,
    [89110] = EFFECT_BRUTALITY,
    [95419] = EFFECT_BRUTALITY,
    [104013] = EFFECT_BRUTALITY,
    [116371] = EFFECT_BRUTALITY,
    [126647] = EFFECT_BRUTALITY,
    [126670] = EFFECT_BRUTALITY,
    [131340] = EFFECT_BRUTALITY,
    [131341] = EFFECT_BRUTALITY,
    [131342] = EFFECT_BRUTALITY,
    [131343] = EFFECT_BRUTALITY,
    [131346] = EFFECT_BRUTALITY,
    [131350] = EFFECT_BRUTALITY,
    [168273] = EFFECT_BRUTALITY,
    [168282] = EFFECT_BRUTALITY,
    [168447] = EFFECT_BRUTALITY,
    [176701] = EFFECT_BRUTALITY,
    [183049] = EFFECT_BRUTALITY,
    [207429] = EFFECT_BRUTALITY,
    [215505] = EFFECT_BRUTALITY,
    [228041] = EFFECT_BRUTALITY,
    [228043] = EFFECT_BRUTALITY,
    [228045] = EFFECT_BRUTALITY,
    [261904] = EFFECT_BRUTALITY,
    [267554] = EFFECT_BRUTALITY,
    [265932] = EFFECT_BRUTALITY,
    [261901] = EFFECT_BRUTALITY,
    [260247] = EFFECT_BRUTALITY,
    [272336] = EFFECT_BRUTALITY,
    [272005] = EFFECT_BRUTALITY,
    [217255] = EFFECT_BRUTALITY,
    [137193] = EFFECT_BRUTALITY,
    [265386] = EFFECT_BRUTALITY,
    [26795] = EFFECT_BRUTALITY,
    [217790] = EFFECT_BRUTALITY,
    [253038] = EFFECT_BRUTALITY,
    [272011] = EFFECT_BRUTALITY,
    -- Major Courage
    [66902] = EFFECT_COURAGE,
    [109966] = EFFECT_COURAGE,
    [109994] = EFFECT_COURAGE,
    [110020] = EFFECT_COURAGE,
    [120015] = EFFECT_COURAGE,
    [172867] = EFFECT_COURAGE,
    [187904] = EFFECT_COURAGE,
    [221536] = EFFECT_COURAGE,
    [214431] = EFFECT_COURAGE,
    [249158] = EFFECT_COURAGE,
    [137295] = EFFECT_COURAGE,
    -- Major Cowardice
    [111354] = EFFECT_COWARDICE,
    [147643] = EFFECT_COWARDICE,
    [163065] = EFFECT_COWARDICE,
    [177247] = EFFECT_COWARDICE,
    [177249] = EFFECT_COWARDICE,
    [177251] = EFFECT_COWARDICE,
    [187899] = EFFECT_COWARDICE,
    [192835] = EFFECT_COWARDICE,
    [210081] = EFFECT_COWARDICE,
    [228087] = EFFECT_COWARDICE,
    [228088] = EFFECT_COWARDICE,
    [111788] = EFFECT_COWARDICE,
    [76502] = EFFECT_COWARDICE,
    [76498] = EFFECT_COWARDICE,
    [118407] = EFFECT_COWARDICE,
    [268235] = EFFECT_COWARDICE,
    -- Major Defile
    [24686] = EFFECT_DEFILE,
    [32961] = EFFECT_DEFILE,
    [34527] = EFFECT_DEFILE,
    [34876] = EFFECT_DEFILE,
    [36515] = EFFECT_DEFILE,
    [44229] = EFFECT_DEFILE,
    [61727] = EFFECT_DEFILE,
    [63148] = EFFECT_DEFILE,
    [80838] = EFFECT_DEFILE,
    [81017] = EFFECT_DEFILE,
    [83955] = EFFECT_DEFILE,
    [85944] = EFFECT_DEFILE,
    [91312] = EFFECT_DEFILE,
    [91332] = EFFECT_DEFILE,
    [93375] = EFFECT_DEFILE,
    [97531] = EFFECT_DEFILE,
    [99786] = EFFECT_DEFILE,
    [105100] = EFFECT_DEFILE,
    [117727] = EFFECT_DEFILE,
    [133060] = EFFECT_DEFILE,
    [133703] = EFFECT_DEFILE,
    [163066] = EFFECT_DEFILE,
    [168764] = EFFECT_DEFILE,
    [196728] = EFFECT_DEFILE,
    [214635] = EFFECT_DEFILE,
    [212606] = EFFECT_DEFILE,
    [237628] = EFFECT_DEFILE,
    [254356] = EFFECT_DEFILE,
    [246315] = EFFECT_DEFILE,
    [230314] = EFFECT_DEFILE,
    [242071] = EFFECT_DEFILE,
    [198888] = EFFECT_DEFILE,
    [217788] = EFFECT_DEFILE,
    [32965] = EFFECT_DEFILE,
    [265488] = EFFECT_DEFILE,
    [114439] = EFFECT_DEFILE,
    -- Major Endurance
    [32748] = EFFECT_ENDURANCE,
    [45226] = EFFECT_ENDURANCE,
    [61705] = EFFECT_ENDURANCE,
    [62575] = EFFECT_ENDURANCE,
    [63681] = EFFECT_ENDURANCE,
    [63683] = EFFECT_ENDURANCE,
    [63766] = EFFECT_ENDURANCE,
    [63789] = EFFECT_ENDURANCE,
    [68361] = EFFECT_ENDURANCE,
    [68408] = EFFECT_ENDURANCE,
    [72935] = EFFECT_ENDURANCE,
    [78054] = EFFECT_ENDURANCE,
    [78080] = EFFECT_ENDURANCE,
    [86693] = EFFECT_ENDURANCE,
    [116385] = EFFECT_ENDURANCE,
    [157802] = EFFECT_ENDURANCE,
    [193745] = EFFECT_ENDURANCE,
    [256016] = EFFECT_ENDURANCE,
    [261913] = EFFECT_ENDURANCE,
    [217792] = EFFECT_ENDURANCE,
    [272009] = EFFECT_ENDURANCE,
    [190588] = EFFECT_ENDURANCE,
    [255189] = EFFECT_ENDURANCE,
    [272541] = EFFECT_ENDURANCE,
    -- Major Enervation
    -- Major Evasion
    [49264] = EFFECT_EVASION,
    [61716] = EFFECT_EVASION,
    [63015] = EFFECT_EVASION,
    [63019] = EFFECT_EVASION,
    [63030] = EFFECT_EVASION,
    [69685] = EFFECT_EVASION,
    [76940] = EFFECT_EVASION,
    [84341] = EFFECT_EVASION,
    [86555] = EFFECT_EVASION,
    [90587] = EFFECT_EVASION,
    [90593] = EFFECT_EVASION,
    [90620] = EFFECT_EVASION,
    [106867] = EFFECT_EVASION,
    [123652] = EFFECT_EVASION,
    [123653] = EFFECT_EVASION,
    [123651] = EFFECT_EVASION,
    [221603] = EFFECT_EVASION,
    [260259] = EFFECT_EVASION,
    [76506] = EFFECT_EVASION,
    [222727] = EFFECT_EVASION,
    [262916] = EFFECT_EVASION,
    [241188] = EFFECT_EVASION,
    [247595] = EFFECT_EVASION,
    -- Major Expedition
    [23216] = EFFECT_EXPEDITION,
    [34511] = EFFECT_EXPEDITION,
    [36050] = EFFECT_EXPEDITION,
    [38967] = EFFECT_EXPEDITION,
    [50997] = EFFECT_EXPEDITION,
    [61736] = EFFECT_EXPEDITION,
    [62531] = EFFECT_EXPEDITION,
    [64005] = EFFECT_EXPEDITION,
    [64566] = EFFECT_EXPEDITION,
    [64567] = EFFECT_EXPEDITION,
    [78081] = EFFECT_EXPEDITION,
    [79368] = EFFECT_EXPEDITION,
    [79370] = EFFECT_EXPEDITION,
    [79623] = EFFECT_EXPEDITION,
    [79624] = EFFECT_EXPEDITION,
    [79625] = EFFECT_EXPEDITION,
    [79877] = EFFECT_EXPEDITION,
    [81524] = EFFECT_EXPEDITION,
    [85592] = EFFECT_EXPEDITION,
    [86267] = EFFECT_EXPEDITION,
    [89076] = EFFECT_EXPEDITION,
    [89078] = EFFECT_EXPEDITION,
    [91193] = EFFECT_EXPEDITION,
    [92418] = EFFECT_EXPEDITION,
    [92771] = EFFECT_EXPEDITION,
    [98489] = EFFECT_EXPEDITION,
    [98490] = EFFECT_EXPEDITION,
    [101161] = EFFECT_EXPEDITION,
    [101169] = EFFECT_EXPEDITION,
    [101178] = EFFECT_EXPEDITION,
    [103321] = EFFECT_EXPEDITION,
    [103520] = EFFECT_EXPEDITION,
    [103707] = EFFECT_EXPEDITION,
    [103711] = EFFECT_EXPEDITION,
    [106776] = EFFECT_EXPEDITION,
    [116374] = EFFECT_EXPEDITION,
    [121827] = EFFECT_EXPEDITION,
    [124801] = EFFECT_EXPEDITION,
    [126957] = EFFECT_EXPEDITION,
    [144708] = EFFECT_EXPEDITION,
    [160047] = EFFECT_EXPEDITION,
    [176310] = EFFECT_EXPEDITION,
    [187939] = EFFECT_EXPEDITION,
    [259744] = EFFECT_EXPEDITION,
    [259745] = EFFECT_EXPEDITION,
    [260258] = EFFECT_EXPEDITION,
    [258812] = EFFECT_EXPEDITION,
    [246400] = EFFECT_EXPEDITION,
    [259746] = EFFECT_EXPEDITION,
    [240159] = EFFECT_EXPEDITION,
    [143705] = EFFECT_EXPEDITION,
    [238027] = EFFECT_EXPEDITION,
    [143684] = EFFECT_EXPEDITION,
    [272637] = EFFECT_EXPEDITION,
    [237647] = EFFECT_EXPEDITION,
    -- Major Force
    [46522] = EFFECT_FORCE,   -- Aggressive Warhorn Major Force (DO NOT REMOVE!)
    [46533] = EFFECT_FORCE,   -- Aggressive Warhorn Major Force (DO NOT REMOVE!)
    [46536] = EFFECT_FORCE,   -- Aggressive Warhorn Major Force (DO NOT REMOVE!)
    [46539] = EFFECT_FORCE,   -- Aggressive Warhorn Major Force (DO NOT REMOVE!)
    [5159289] = EFFECT_FORCE, -- Grisly Gourmet (DON NOT REMOVE!)
    [40225] = EFFECT_FORCE,
    [61747] = EFFECT_FORCE,
    [85154] = EFFECT_FORCE,
    [120013] = EFFECT_FORCE,
    [154830] = EFFECT_FORCE,
    [176849] = EFFECT_FORCE,
    [214424] = EFFECT_FORCE,
    [221602] = EFFECT_FORCE,
    [238550] = EFFECT_FORCE,
    [249160] = EFFECT_FORCE,
    [242717] = EFFECT_FORCE,
    [258816] = EFFECT_FORCE,
    [159624] = EFFECT_FORCE,
    [260689] = EFFECT_FORCE,
    [159626] = EFFECT_FORCE,
    [260739] = EFFECT_FORCE,
    [272538] = EFFECT_FORCE,
    [272542] = EFFECT_FORCE,
    [263418] = EFFECT_FORCE,
    -- Major Fortitude
    [29011] = EFFECT_FORTITUDE,
    [45222] = EFFECT_FORTITUDE,
    [61698] = EFFECT_FORTITUDE,
    [61884] = EFFECT_FORTITUDE,
    [62555] = EFFECT_FORTITUDE,
    [63670] = EFFECT_FORTITUDE,
    [63672] = EFFECT_FORTITUDE,
    [63784] = EFFECT_FORTITUDE,
    [66256] = EFFECT_FORTITUDE,
    [68375] = EFFECT_FORTITUDE,
    [68405] = EFFECT_FORTITUDE,
    [72928] = EFFECT_FORTITUDE,
    [86697] = EFFECT_FORTITUDE,
    [91674] = EFFECT_FORTITUDE,
    [92415] = EFFECT_FORTITUDE,
    [157804] = EFFECT_FORTITUDE,
    [193741] = EFFECT_FORTITUDE,
    [256014] = EFFECT_FORTITUDE,
    [256017] = EFFECT_FORTITUDE,
    [187860] = EFFECT_FORTITUDE,
    [272545] = EFFECT_FORTITUDE,
    [272552] = EFFECT_FORTITUDE,
    -- Major Gallop
    -- Major Heroism
    [61709] = EFFECT_HEROISM,
    [65133] = EFFECT_HEROISM,
    [87234] = EFFECT_HEROISM,
    [92775] = EFFECT_HEROISM,
    [111377] = EFFECT_HEROISM,
    [111380] = EFFECT_HEROISM,
    [150974] = EFFECT_HEROISM,
    [194148] = EFFECT_HEROISM,
    [194149] = EFFECT_HEROISM,
    [193747] = EFFECT_HEROISM,
    [213946] = EFFECT_HEROISM,
    [236448] = EFFECT_HEROISM,
    [265972] = EFFECT_HEROISM,
    [268257] = EFFECT_HEROISM,
    [262138] = EFFECT_HEROISM,
    [262137] = EFFECT_HEROISM,
    [147462] = EFFECT_HEROISM,
    -- Major Hindrance
    -- Major Intellect
    [45224] = EFFECT_INTELLECT,
    [61707] = EFFECT_INTELLECT,
    [62577] = EFFECT_INTELLECT,
    [63676] = EFFECT_INTELLECT,
    [63678] = EFFECT_INTELLECT,
    [63771] = EFFECT_INTELLECT,
    [63785] = EFFECT_INTELLECT,
    [68133] = EFFECT_INTELLECT,
    [68406] = EFFECT_INTELLECT,
    [72932] = EFFECT_INTELLECT,
    [86683] = EFFECT_INTELLECT,
    [157806] = EFFECT_INTELLECT,
    [193744] = EFFECT_INTELLECT,
    [207428] = EFFECT_INTELLECT,
    [255190] = EFFECT_INTELLECT,
    [261911] = EFFECT_INTELLECT,
    [272537] = EFFECT_INTELLECT,
    [272003] = EFFECT_INTELLECT,
    [272334] = EFFECT_INTELLECT,
    [187862] = EFFECT_INTELLECT,
    [272531] = EFFECT_INTELLECT,
    -- Major Lifesteal
    -- Major Magickasteal
    -- Major Maim
    [21754] = EFFECT_MAIM,
    [21760] = EFFECT_MAIM,
    [61725] = EFFECT_MAIM,
    [78607] = EFFECT_MAIM,
    [92041] = EFFECT_MAIM,
    [93078] = EFFECT_MAIM,
    [108833] = EFFECT_MAIM,
    [133292] = EFFECT_MAIM,
    [133214] = EFFECT_MAIM,
    [134444] = EFFECT_MAIM,
    [141927] = EFFECT_MAIM,
    [147746] = EFFECT_MAIM,
    [159376] = EFFECT_MAIM,
    [159664] = EFFECT_MAIM,
    [163064] = EFFECT_MAIM,
    [183389] = EFFECT_MAIM,
    [212073] = EFFECT_MAIM,
    [214441] = EFFECT_MAIM,
    [214457] = EFFECT_MAIM,
    [214759] = EFFECT_MAIM,
    [238180] = EFFECT_MAIM,
    [237701] = EFFECT_MAIM,
    [137311] = EFFECT_MAIM,
    [244073] = EFFECT_MAIM,
    [118358] = EFFECT_MAIM,
    [244075] = EFFECT_MAIM,
    [114440] = EFFECT_MAIM,
    [217105] = EFFECT_MAIM,
    [21757] = EFFECT_MAIM,
    -- Major Mangle
    -- Major Mending
    [55033] = EFFECT_MENDING,
    [61711] = EFFECT_MENDING,
    [77918] = EFFECT_MENDING,
    [77922] = EFFECT_MENDING,
    [88525] = EFFECT_MENDING,
    [88528] = EFFECT_MENDING,
    [92774] = EFFECT_MENDING,
    [93364] = EFFECT_MENDING,
    [106806] = EFFECT_MENDING,
    [108675] = EFFECT_MENDING,
    [108676] = EFFECT_MENDING,
    [193739] = EFFECT_MENDING,
    [260721] = EFFECT_MENDING,
    [272554] = EFFECT_MENDING,
    [238067] = EFFECT_MENDING,
    [272532] = EFFECT_MENDING,
    [272335] = EFFECT_MENDING,
    [260711] = EFFECT_MENDING,
    -- Major Prophecy (BuffType slot 8 is BUFF_TYPE_MAJOR_PROPHECY_DEPRECATED on U51)
    -- Sun Fire morphs still occupy this slot; specialNames displays them as Major Savagery
    [21726] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [21729] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [21732] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24160] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24167] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24171] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24174] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24177] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24180] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24184] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24187] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [24195] = EFFECT_PROPHECY, -- Templar Sun Fire (and morphs) Major Savagery display (DO NOT REMOVE!)
    [61689] = EFFECT_PROPHECY,
    [62747] = EFFECT_PROPHECY,
    [62751] = EFFECT_PROPHECY,
    [62755] = EFFECT_PROPHECY,
    [64572] = EFFECT_PROPHECY,
    [86303] = EFFECT_PROPHECY,
    [163663] = EFFECT_PROPHECY,
    [168108] = EFFECT_PROPHECY,
    [168109] = EFFECT_PROPHECY,
    [168440] = EFFECT_PROPHECY,
    [176151] = EFFECT_PROPHECY,
    [228047] = EFFECT_PROPHECY,
    [228050] = EFFECT_PROPHECY,
    [228052] = EFFECT_PROPHECY,
    [238068] = EFFECT_PROPHECY,
    [265985] = EFFECT_PROPHECY,
    [226784] = EFFECT_PROPHECY,
    [218001] = EFFECT_PROPHECY,
    [227122] = EFFECT_PROPHECY,
    [217670] = EFFECT_PROPHECY,
    [217671] = EFFECT_PROPHECY,
    [252763] = EFFECT_PROPHECY,
    [218016] = EFFECT_PROPHECY,
    [217341] = EFFECT_PROPHECY,
    [217886] = EFFECT_PROPHECY,
    [226614] = EFFECT_PROPHECY,
    -- Major Protection
    [22233] = EFFECT_PROTECTION,
    [44854] = EFFECT_PROTECTION,
    [44862] = EFFECT_PROTECTION,
    [44871] = EFFECT_PROTECTION,
    [61722] = EFFECT_PROTECTION,
    [79068] = EFFECT_PROTECTION,
    [80853] = EFFECT_PROTECTION,
    [86249] = EFFECT_PROTECTION,
    [88859] = EFFECT_PROTECTION,
    [88862] = EFFECT_PROTECTION,
    [92773] = EFFECT_PROTECTION,
    [92909] = EFFECT_PROTECTION,
    [93079] = EFFECT_PROTECTION,
    [97627] = EFFECT_PROTECTION,
    [97910] = EFFECT_PROTECTION,
    [113509] = EFFECT_PROTECTION,
    [118629] = EFFECT_PROTECTION,
    [129477] = EFFECT_PROTECTION,
    [160074] = EFFECT_PROTECTION,
    [161716] = EFFECT_PROTECTION,
    [197244] = EFFECT_PROTECTION,
    [197249] = EFFECT_PROTECTION,
    [193730] = EFFECT_PROTECTION,
    [194169] = EFFECT_PROTECTION,
    [210902] = EFFECT_PROTECTION,
    [238143] = EFFECT_PROTECTION,
    [238101] = EFFECT_PROTECTION,
    [235891] = EFFECT_PROTECTION,
    [237703] = EFFECT_PROTECTION,
    [263250] = EFFECT_PROTECTION,
    [137347] = EFFECT_PROTECTION,
    [258811] = EFFECT_PROTECTION,
    [242715] = EFFECT_PROTECTION,
    [248806] = EFFECT_PROTECTION,
    [263307] = EFFECT_PROTECTION,
    [255689] = EFFECT_PROTECTION,
    [32714] = EFFECT_PROTECTION,
    [242028] = EFFECT_PROTECTION,
    [246074] = EFFECT_PROTECTION,
    [201394] = EFFECT_PROTECTION,
    [237930] = EFFECT_PROTECTION,
    -- Major Resolve
    [22236] = EFFECT_RESOLVE,
    [44828] = EFFECT_RESOLVE,
    [44836] = EFFECT_RESOLVE,
    [61694] = EFFECT_RESOLVE,
    [61815] = EFFECT_RESOLVE,
    [61827] = EFFECT_RESOLVE,
    [61836] = EFFECT_RESOLVE,
    [62159] = EFFECT_RESOLVE,
    [62168] = EFFECT_RESOLVE,
    [62175] = EFFECT_RESOLVE,
    [63084] = EFFECT_RESOLVE,
    [63119] = EFFECT_RESOLVE,
    [63134] = EFFECT_RESOLVE,
    [66075] = EFFECT_RESOLVE,
    [66083] = EFFECT_RESOLVE,
    [80160] = EFFECT_RESOLVE,
    [80482] = EFFECT_RESOLVE,
    [86224] = EFFECT_RESOLVE,
    [88758] = EFFECT_RESOLVE,
    [88761] = EFFECT_RESOLVE,
    [91194] = EFFECT_RESOLVE,
    [103752] = EFFECT_RESOLVE,
    [107632] = EFFECT_RESOLVE,
    [115211] = EFFECT_RESOLVE,
    [116805] = EFFECT_RESOLVE,
    [118239] = EFFECT_RESOLVE,
    [118246] = EFFECT_RESOLVE,
    [150998] = EFFECT_RESOLVE,
    [176070] = EFFECT_RESOLVE,
    [193728] = EFFECT_RESOLVE,
    [185909] = EFFECT_RESOLVE,
    [183650] = EFFECT_RESOLVE,
    [186478] = EFFECT_RESOLVE,
    [213450] = EFFECT_RESOLVE,
    [217775] = EFFECT_RESOLVE,
    [221510] = EFFECT_RESOLVE,
    [237631] = EFFECT_RESOLVE,
    [238077] = EFFECT_RESOLVE,
    [237955] = EFFECT_RESOLVE,
    [247597] = EFFECT_RESOLVE,
    [256051] = EFFECT_RESOLVE,
    [256047] = EFFECT_RESOLVE,
    [237632] = EFFECT_RESOLVE,
    [230692] = EFFECT_RESOLVE,
    [166278] = EFFECT_RESOLVE,
    [254375] = EFFECT_RESOLVE,
    [215048] = EFFECT_RESOLVE,
    [91657] = EFFECT_RESOLVE,
    [196714] = EFFECT_RESOLVE,
    [215051] = EFFECT_RESOLVE,
    [158894] = EFFECT_RESOLVE,
    [136185] = EFFECT_RESOLVE,
    [238256] = EFFECT_RESOLVE,
    [238041] = EFFECT_RESOLVE,
    [217106] = EFFECT_RESOLVE,
    [158867] = EFFECT_RESOLVE,
    [237630] = EFFECT_RESOLVE,
    [216949] = EFFECT_RESOLVE,
    [226162] = EFFECT_RESOLVE,
    [246025] = EFFECT_RESOLVE,
    [192999] = EFFECT_RESOLVE,
    [187481] = EFFECT_RESOLVE,
    [223710] = EFFECT_RESOLVE,
    [238139] = EFFECT_RESOLVE,
    [223708] = EFFECT_RESOLVE,
    [68829] = EFFECT_RESOLVE,
    [226238] = EFFECT_RESOLVE,
    [158599] = EFFECT_RESOLVE,
    -- Major Savagery
    [61667] = EFFECT_SAVAGERY,
    [63770] = EFFECT_SAVAGERY,
    [64509] = EFFECT_SAVAGERY,
    [64568] = EFFECT_SAVAGERY,
    [64569] = EFFECT_SAVAGERY,
    [85605] = EFFECT_SAVAGERY,
    [86694] = EFFECT_SAVAGERY,
    [87061] = EFFECT_SAVAGERY,
    [137007] = EFFECT_SAVAGERY,
    [138072] = EFFECT_SAVAGERY,
    [163664] = EFFECT_SAVAGERY,
    [167936] = EFFECT_SAVAGERY,
    [167937] = EFFECT_SAVAGERY,
    [167939] = EFFECT_SAVAGERY,
    [168107] = EFFECT_SAVAGERY,
    [168111] = EFFECT_SAVAGERY,
    [168444] = EFFECT_SAVAGERY,
    [168445] = EFFECT_SAVAGERY,
    [168446] = EFFECT_SAVAGERY,
    [176152] = EFFECT_SAVAGERY,
    [203343] = EFFECT_SAVAGERY,
    [228048] = EFFECT_SAVAGERY,
    [228049] = EFFECT_SAVAGERY,
    [228051] = EFFECT_SAVAGERY,
    [240058] = EFFECT_SAVAGERY,
    [238069] = EFFECT_SAVAGERY,
    [265984] = EFFECT_SAVAGERY,
    [217360] = EFFECT_SAVAGERY,
    [227121] = EFFECT_SAVAGERY,
    [214994] = EFFECT_SAVAGERY,
    [61907] = EFFECT_SAVAGERY,
    [218004] = EFFECT_SAVAGERY,
    [108853] = EFFECT_SAVAGERY,
    [252759] = EFFECT_SAVAGERY,
    [214995] = EFFECT_SAVAGERY,
    [217673] = EFFECT_SAVAGERY,
    [61930] = EFFECT_SAVAGERY,
    [271723] = EFFECT_SAVAGERY,
    [61932] = EFFECT_SAVAGERY,
    [217885] = EFFECT_SAVAGERY,
    [226783] = EFFECT_SAVAGERY,
    [218015] = EFFECT_SAVAGERY,
    -- Major Slayer
    [93109] = EFFECT_SLAYER,
    [93120] = EFFECT_SLAYER,
    [93442] = EFFECT_SLAYER,
    [121871] = EFFECT_SLAYER,
    [137986] = EFFECT_SLAYER,
    [177886] = EFFECT_SLAYER,
    [214407] = EFFECT_SLAYER,
    -- Major Sorcery
    [33317] = EFFECT_SORCERY,
    [61687] = EFFECT_SORCERY,
    [62062] = EFFECT_SORCERY,
    [62240] = EFFECT_SORCERY,
    [63227] = EFFECT_SORCERY,
    [87929] = EFFECT_SORCERY,
    [89107] = EFFECT_SORCERY,
    [92503] = EFFECT_SORCERY,
    [92507] = EFFECT_SORCERY,
    [92512] = EFFECT_SORCERY,
    [93350] = EFFECT_SORCERY,
    [95125] = EFFECT_SORCERY,
    [131310] = EFFECT_SORCERY,
    [131311] = EFFECT_SORCERY,
    [131344] = EFFECT_SORCERY,
    [135923] = EFFECT_SLAYER,
    [163655] = EFFECT_SORCERY,
    [167853] = EFFECT_SORCERY,
    [168214] = EFFECT_SORCERY,
    [168215] = EFFECT_SORCERY,
    [168220] = EFFECT_SORCERY,
    [168270] = EFFECT_SORCERY,
    [168272] = EFFECT_SORCERY,
    [168274] = EFFECT_SORCERY,
    [168275] = EFFECT_SORCERY,
    [168281] = EFFECT_SORCERY,
    [176702] = EFFECT_SORCERY,
    [201089] = EFFECT_SORCERY,
    [215504] = EFFECT_SORCERY,
    [228042] = EFFECT_SORCERY,
    [228044] = EFFECT_SORCERY,
    [228046] = EFFECT_SORCERY,
    [260248] = EFFECT_SORCERY,
    [261905] = EFFECT_SORCERY,
    [267555] = EFFECT_SORCERY,
    [261902] = EFFECT_SORCERY,
    [216948] = EFFECT_SORCERY,
    [217254] = EFFECT_SORCERY,
    -- Major Timidity
    -- Major Toughness
    -- Major Uncertainty
    -- Major Vitality
    [42197] = EFFECT_VITALITY,
    [61275] = EFFECT_VITALITY,
    [61713] = EFFECT_VITALITY,
    [63533] = EFFECT_VITALITY,
    [79848] = EFFECT_VITALITY,
    [79850] = EFFECT_VITALITY,
    [92776] = EFFECT_VITALITY,
    [111221] = EFFECT_VITALITY,
    [113653] = EFFECT_VITALITY,
    [133318] = EFFECT_VITALITY,
    [191062] = EFFECT_VITALITY,
    [193740] = EFFECT_VITALITY,
    [261903] = EFFECT_VITALITY,
    [263413] = EFFECT_VITALITY,
    [272546] = EFFECT_VITALITY,
    [272553] = EFFECT_VITALITY,
    -- Major Vulnerability
    [106754] = EFFECT_VULNERABILITY,
    [106755] = EFFECT_VULNERABILITY,
    [106758] = EFFECT_VULNERABILITY,
    [106760] = EFFECT_VULNERABILITY,
    [106762] = EFFECT_VULNERABILITY,
    [122177] = EFFECT_VULNERABILITY,
    [122397] = EFFECT_VULNERABILITY,
    [122389] = EFFECT_VULNERABILITY,
    [148976] = EFFECT_VULNERABILITY,
    [163060] = EFFECT_VULNERABILITY,
    [167061] = EFFECT_VULNERABILITY,
    [176815] = EFFECT_VULNERABILITY,
    [195242] = EFFECT_VULNERABILITY,
    [192836] = EFFECT_VULNERABILITY,
    [226400] = EFFECT_VULNERABILITY,
    [269996] = EFFECT_VULNERABILITY,
    [248789] = EFFECT_VULNERABILITY,
    -- Major Vexation (P51 BuffType 65; populated from FullUpdate dump)
    [263406] = EFFECT_VEXATION,
    -- Sample Auras (settings preview; matches Srendarr.sampleAuraData major sample ID)
    [248427] = EFFECT_VULNERABILITY,
}



--------------------------------------------------------------------------------------------------------------------
-- AURA DATA DEBUG & PATCH FUNCTIONS
-- Used after patches to assist in getting hold of changed abilityIDs
--------------------------------------------------------------------------------------------------------------------

-- Sample / preview FAKE ability IDs - skip when seeding toggle name scan
local toggleFakeAbilityIDs =
{
    [916007] = true, -- Sample Aura (FAKE)
    [916008] = true, -- Sample Aura (FAKE)
}

local toggleScanNames = {}
local toggleScanData = {}

-- Usage: /script Srendarr:GetToggled()
-- Staged scan (same 50k chunks as GetAurasByName / FullUpdate). Reload UI after complete, then
-- process SavedVariables with tools/process_toggled_dump.py
function Srendarr:GetToggled(stage)
    stage = (stage ~= nil) and stage or 1

    if stage == 1 then
        toggleScanNames = {}
        toggleScanData = {}
        Srendarr.db.toggled = {}

        for abilityID, _ in pairs(toggledAuras) do
            if not toggleFakeAbilityIDs[abilityID] and DoesAbilityExist(abilityID) then
                local abilityName = GetAbilityName(abilityID)
                if abilityName and abilityName ~= '' then
                    toggleScanNames[abilityName] = true
                end
            end
        end
        d('Srendarr:GetToggled - scanning toggled aura ability IDs...')
    end

    local tempInt = (stage == 1) and 0 or 1
    local IdLow = (50000 * stage) - 50000
    local IdHigh = 50000 * stage

    for i = IdLow, IdHigh, 1 do
        local abilityID = i + tempInt
        if DoesAbilityExist(abilityID) then
            local abilityName = GetAbilityName(abilityID)
            if toggleScanNames[abilityName] and GetAbilityDuration(abilityID) == 0 then
                local abilityDescription = GetAbilityDescription(abilityID)
                if abilityDescription and abilityDescription ~= '' then
                    table.insert(toggleScanData, { abilityName, abilityID, abilityDescription })
                end
            end
        end
        if i == IdHigh then
            if stage == maxStage then
                table.sort(toggleScanData, function (a, b) return a[1] > b[1] end)

                local saved = {}
                for _, entry in ipairs(toggleScanData) do
                    local abilityName = entry[1]
                    local foundAbilityID = entry[2]
                    local abilityDescription = entry[3]
                    d(foundAbilityID .. ' ' .. abilityName .. '      ' .. string.sub(abilityDescription, 1, 30))
                    table.insert(saved, foundAbilityID .. '|' .. abilityName .. '||' .. string.sub(abilityDescription, 1, 30))
                end
                Srendarr.db.toggled = saved
                d('Srendarr:GetToggled complete (' .. tostring(#saved) .. ' entries). Reload UI to export to SavedVariables.')
            else
                zo_callLater(function () Srendarr:GetToggled(stage + 1) end, 500)
                return
            end
        end
    end
end

-- Useage:	/script Srendarr:GetAurasByName("Shooting Star") -- New staggered method for stability (Phinix)
-- 			/script Srendarr:GetAurasByName("", true) -- Export ability data (Phinix)
function Srendarr:GetAurasByName(name, export, stage)
    stage = (stage ~= nil) and stage or 1
    local eName = string.lower(name)
    local tempInt = (stage == 1) and 0 or 1
    local IdLow = (50000 * stage) - 50000
    local IdHigh = 50000 * stage

    for i = IdLow, IdHigh, 1 do
        local cID = i + tempInt
        if (DoesAbilityExist(cID)) then
            if (export) then
                local linkstring = ZOSName(cID, 1)
                if linkstring and linkstring ~= '' then
                    Srendarr.db.tempExport[cID] = linkstring
                end
            else
                local linkstring = string.lower(ZOSName(cID, 1))
                if string.find(linkstring, eName) ~= nil then
                    d('[' .. tostring(cID) .. '] ' .. GetAbilityName(cID) .. '-' .. ATd(cID) * 1000 .. '-' .. GetAbilityDescription(cID))
                end
            end
        end
        if i == IdHigh then
            if stage == maxStage then
                d('Search complete.')
            else
                zo_callLater(function () Srendarr:GetAurasByName(name, export, stage + 1) end, 500)
                return
            end
        end
    end
    -- function Srendarr:GetAurasByName(name, set)
    -- 	local start = (set == 1) and 1 or 100001
    -- 	local cap = (set == 1) and 100000 or 200000
    -- 	for x = start, cap do
    -- 	--	if (DoesAbilityExist(x) and GetAbilityName(x) == name and GetAbilityDuration(x) > 0) then
    -- 		if (DoesAbilityExist(x) and GetAbilityName(x) == name) then
    -- 			d('['..x ..'] '..GetAbilityName(x) .. '-' .. GetAbilityDuration(x) .. '-' .. GetAbilityDescription(x))
    -- 		end
    -- 	end
    -- end
end

--[[
function GetAuraInfo(idA, idB)
	d(string.format('[%d] %s (%ds) - %s', idA, GetAbilityName(idA), GetAbilityDuration(idA), GetAbilityDescription(idA)))
	d(string.format('[%d] %s (%ds) - %s', idB, GetAbilityName(idB), GetAbilityDuration(idB), GetAbilityDescription(idB)))
end
]]


--------------------------------------------------------------------------------------------------------------------
-- Major/Minor effect table update by GetAbilityBuffType (P51 BuffType 0..65)
-- Usage: /script Srendarr:GetEffects(buffType)
--        buffType = numeric BuffType. 64 = Minor Vexation, 65 = Major Vexation
-- Usage: /script Srendarr:FullUpdate()
-- https://en.uesp.net/wiki/Online:Buffs
--------------------------------------------------------------------------------------------------------------------

-- Dual-API safe numeric keys (do not index BUFF_TYPE_* globals: U50 lacks VEXATION,
-- U51 renamed PROPHECY/SORCERY to *_DEPRECATED). Matches P51 BuffType meta 0..65.
local BUFF_TYPE_SCAN_MIN = 0
local BUFF_TYPE_SCAN_MAX = 65

-- Mapped BuffTypes only (skip NONE, EMPOWER, DEPRECATED_*, GALLOP).
-- tier 1 = minorEffects, tier 2 = majorEffects
local BuffTypeMap =
{
    [1]  = { tier = 1, effect = EFFECT_BRUTALITY, effectName = 'EFFECT_BRUTALITY', displayName = 'Minor Brutality' },
    [2]  = { tier = 2, effect = EFFECT_BRUTALITY, effectName = 'EFFECT_BRUTALITY', displayName = 'Major Brutality' },
    [3]  = { tier = 1, effect = EFFECT_SAVAGERY, effectName = 'EFFECT_SAVAGERY', displayName = 'Minor Savagery' },
    [4]  = { tier = 2, effect = EFFECT_SAVAGERY, effectName = 'EFFECT_SAVAGERY', displayName = 'Major Savagery' },
    [5]  = { tier = 1, effect = EFFECT_SORCERY, effectName = 'EFFECT_SORCERY', displayName = 'Minor Sorcery' },       -- *_DEPRECATED slot
    [6]  = { tier = 2, effect = EFFECT_SORCERY, effectName = 'EFFECT_SORCERY', displayName = 'Major Sorcery' },       -- *_DEPRECATED slot
    [7]  = { tier = 1, effect = EFFECT_PROPHECY, effectName = 'EFFECT_PROPHECY', displayName = 'Minor Prophecy' },    -- *_DEPRECATED slot
    [8]  = { tier = 2, effect = EFFECT_PROPHECY, effectName = 'EFFECT_PROPHECY', displayName = 'Major Prophecy' },    -- *_DEPRECATED slot
    [9]  = { tier = 1, effect = EFFECT_RESOLVE, effectName = 'EFFECT_RESOLVE', displayName = 'Minor Resolve' },
    [10] = { tier = 2, effect = EFFECT_RESOLVE, effectName = 'EFFECT_RESOLVE', displayName = 'Major Resolve' },
    [11] = { tier = 1, effect = EFFECT_BRITTLE, effectName = 'EFFECT_BRITTLE', displayName = 'Minor Brittle' },
    [12] = { tier = 2, effect = EFFECT_BRITTLE, effectName = 'EFFECT_BRITTLE', displayName = 'Major Brittle' },
    [13] = { tier = 1, effect = EFFECT_FORTITUDE, effectName = 'EFFECT_FORTITUDE', displayName = 'Minor Fortitude' },
    [14] = { tier = 2, effect = EFFECT_FORTITUDE, effectName = 'EFFECT_FORTITUDE', displayName = 'Major Fortitude' },
    [15] = { tier = 1, effect = EFFECT_ENDURANCE, effectName = 'EFFECT_ENDURANCE', displayName = 'Minor Endurance' },
    [16] = { tier = 2, effect = EFFECT_ENDURANCE, effectName = 'EFFECT_ENDURANCE', displayName = 'Major Endurance' },
    [17] = { tier = 1, effect = EFFECT_INTELLECT, effectName = 'EFFECT_INTELLECT', displayName = 'Minor Intellect' },
    [18] = { tier = 2, effect = EFFECT_INTELLECT, effectName = 'EFFECT_INTELLECT', displayName = 'Major Intellect' },
    [19] = { tier = 1, effect = EFFECT_HEROISM, effectName = 'EFFECT_HEROISM', displayName = 'Minor Heroism' },
    [20] = { tier = 2, effect = EFFECT_HEROISM, effectName = 'EFFECT_HEROISM', displayName = 'Major Heroism' },
    [21] = { tier = 1, effect = EFFECT_MENDING, effectName = 'EFFECT_MENDING', displayName = 'Minor Mending' },
    [22] = { tier = 2, effect = EFFECT_MENDING, effectName = 'EFFECT_MENDING', displayName = 'Major Mending' },
    [23] = { tier = 1, effect = EFFECT_VITALITY, effectName = 'EFFECT_VITALITY', displayName = 'Minor Vitality' },
    [24] = { tier = 2, effect = EFFECT_VITALITY, effectName = 'EFFECT_VITALITY', displayName = 'Major Vitality' },
    [25] = { tier = 1, effect = EFFECT_EVASION, effectName = 'EFFECT_EVASION', displayName = 'Minor Evasion' },
    [26] = { tier = 2, effect = EFFECT_EVASION, effectName = 'EFFECT_EVASION', displayName = 'Major Evasion' },
    [27] = { tier = 1, effect = EFFECT_PROTECTION, effectName = 'EFFECT_PROTECTION', displayName = 'Minor Protection' },
    [28] = { tier = 2, effect = EFFECT_PROTECTION, effectName = 'EFFECT_PROTECTION', displayName = 'Major Protection' },
    [29] = { tier = 1, effect = EFFECT_MAIM, effectName = 'EFFECT_MAIM', displayName = 'Minor Maim' },
    [30] = { tier = 2, effect = EFFECT_MAIM, effectName = 'EFFECT_MAIM', displayName = 'Major Maim' },
    [31] = { tier = 1, effect = EFFECT_DEFILE, effectName = 'EFFECT_DEFILE', displayName = 'Minor Defile' },
    [32] = { tier = 2, effect = EFFECT_DEFILE, effectName = 'EFFECT_DEFILE', displayName = 'Major Defile' },
    [33] = { tier = 1, effect = EFFECT_MANGLE, effectName = 'EFFECT_MANGLE', displayName = 'Minor Mangle' },
    [34] = { tier = 2, effect = EFFECT_MANGLE, effectName = 'EFFECT_MANGLE', displayName = 'Major Mangle' },
    [35] = { tier = 1, effect = EFFECT_EXPEDITION, effectName = 'EFFECT_EXPEDITION', displayName = 'Minor Expedition' },
    [36] = { tier = 2, effect = EFFECT_EXPEDITION, effectName = 'EFFECT_EXPEDITION', displayName = 'Major Expedition' },
    [38] = { tier = 1, effect = EFFECT_COWARDICE, effectName = 'EFFECT_COWARDICE', displayName = 'Minor Cowardice' },
    [39] = { tier = 2, effect = EFFECT_COWARDICE, effectName = 'EFFECT_COWARDICE', displayName = 'Major Cowardice' },
    [40] = { tier = 1, effect = EFFECT_BREACH, effectName = 'EFFECT_BREACH', displayName = 'Minor Breach' },
    [41] = { tier = 2, effect = EFFECT_BREACH, effectName = 'EFFECT_BREACH', displayName = 'Major Breach' },
    [42] = { tier = 1, effect = EFFECT_BERSERK, effectName = 'EFFECT_BERSERK', displayName = 'Minor Berserk' },
    [43] = { tier = 2, effect = EFFECT_BERSERK, effectName = 'EFFECT_BERSERK', displayName = 'Major Berserk' },
    [44] = { tier = 1, effect = EFFECT_FORCE, effectName = 'EFFECT_FORCE', displayName = 'Minor Force' },
    [45] = { tier = 2, effect = EFFECT_FORCE, effectName = 'EFFECT_FORCE', displayName = 'Major Force' },
    [46] = { tier = 1, effect = EFFECT_SLAYER, effectName = 'EFFECT_SLAYER', displayName = 'Minor Slayer' },
    [47] = { tier = 2, effect = EFFECT_SLAYER, effectName = 'EFFECT_SLAYER', displayName = 'Major Slayer' },
    [48] = { tier = 1, effect = EFFECT_COURAGE, effectName = 'EFFECT_COURAGE', displayName = 'Minor Courage' },
    [49] = { tier = 2, effect = EFFECT_COURAGE, effectName = 'EFFECT_COURAGE', displayName = 'Major Courage' },
    [50] = { tier = 1, effect = EFFECT_TOUGHNESS, effectName = 'EFFECT_TOUGHNESS', displayName = 'Minor Toughness' },
    [51] = { tier = 1, effect = EFFECT_AEGIS, effectName = 'EFFECT_AEGIS', displayName = 'Minor Aegis' },
    [52] = { tier = 2, effect = EFFECT_AEGIS, effectName = 'EFFECT_AEGIS', displayName = 'Major Aegis' },
    [55] = { tier = 1, effect = EFFECT_ENERVATION, effectName = 'EFFECT_ENERVATION', displayName = 'Minor Enervation' },
    [56] = { tier = 1, effect = EFFECT_UNCERTAINTY, effectName = 'EFFECT_UNCERTAINTY', displayName = 'Minor Uncertainty' },
    [57] = { tier = 1, effect = EFFECT_LIFESTEAL, effectName = 'EFFECT_LIFESTEAL', displayName = 'Minor Lifesteal' },
    [58] = { tier = 1, effect = EFFECT_MAGICKASTEAL, effectName = 'EFFECT_MAGICKASTEAL', displayName = 'Minor Magickasteal' },
    [60] = { tier = 1, effect = EFFECT_VULNERABILITY, effectName = 'EFFECT_VULNERABILITY', displayName = 'Minor Vulnerability' },
    [61] = { tier = 2, effect = EFFECT_VULNERABILITY, effectName = 'EFFECT_VULNERABILITY', displayName = 'Major Vulnerability' },
    [62] = { tier = 1, effect = EFFECT_TIMIDITY, effectName = 'EFFECT_TIMIDITY', displayName = 'Minor Timidity' },
    [63] = { tier = 2, effect = EFFECT_TIMIDITY, effectName = 'EFFECT_TIMIDITY', displayName = 'Major Timidity' },
    [64] = { tier = 1, effect = EFFECT_VEXATION, effectName = 'EFFECT_VEXATION', displayName = 'Minor Vexation' },
    [65] = { tier = 2, effect = EFFECT_VEXATION, effectName = 'EFFECT_VEXATION', displayName = 'Major Vexation' },
}

local ignoreEffects =
{
    [46522] = true,
    [46533] = true,
    [46536] = true,
    [46539] = true,
    [21726] = true,
    [21729] = true,
    [21732] = true,
    [24160] = true,
    [24167] = true,
    [24171] = true,
    [24174] = true,
    [24177] = true,
    [24180] = true,
    [24184] = true,
    [24187] = true,
    [24195] = true,
    [5159289] = true,
}

local function UpdateIDTable(scanTable, mapping, full)
    local eTable = (mapping.tier == 1) and minorEffects or majorEffects
    local eName = string.lower(mapping.displayName)
    local aTable = {}
    local rTable = {}

    for abilityID, line in pairs(scanTable) do
        if eTable[abilityID] == nil then
            aTable[abilityID] = line
        end
    end
    for abilityID, effectConstant in pairs(eTable) do
        if scanTable[abilityID] == nil and not ignoreEffects[abilityID] and effectConstant == mapping.effect then
            rTable[abilityID] = '[' .. tostring(abilityID) .. '] = ' .. mapping.effectName .. ','
        end
    end

    if (full) then
        local addedDB = (mapping.tier == 1) and Srendarr.db.updateDB.MinorAdded or Srendarr.db.updateDB.MajorAdded
        local removedDB = (mapping.tier == 1) and Srendarr.db.updateDB.MinorRemoved or Srendarr.db.updateDB.MajorRemoved

        if next(aTable) ~= nil then
            if addedDB[eName] == nil then
                addedDB[eName] = {}
            end
            for _, line in pairs(aTable) do
                table.insert(addedDB[eName], line)
            end
        end
        if next(rTable) ~= nil then
            if removedDB[eName] == nil then
                removedDB[eName] = {}
            end
            for _, line in pairs(rTable) do
                table.insert(removedDB[eName], line)
            end
        end
    else
        if next(aTable) ~= nil then
            d('New effects added:')
            for _, line in pairs(aTable) do
                d('    ' .. line)
            end
        else
            d(mapping.displayName .. ' - No new effects added.')
        end
        if next(rTable) ~= nil then
            d('Effects removed:')
            for _, line in pairs(rTable) do
                d('    ' .. line)
            end
        else
            d(mapping.displayName .. ' - No effects removed.')
        end
    end
end

local function ScanBuffTypes(stage, full, maxID, filterBuffType)
    stage = (stage ~= nil) and stage or 1
    maxID = (maxID ~= nil) and maxID or 0

    if stage == 1 then
        buffTypeScan = {}
        if filterBuffType then
            buffTypeScan[filterBuffType] = {}
        else
            for mappedType = BUFF_TYPE_SCAN_MIN, BUFF_TYPE_SCAN_MAX do
                if BuffTypeMap[mappedType] then
                    buffTypeScan[mappedType] = {}
                end
            end
        end
        if (full) then
            Srendarr.db.updateDB = {}
            Srendarr.db.updateDB.MinorAdded = {}
            Srendarr.db.updateDB.MinorRemoved = {}
            Srendarr.db.updateDB.MajorAdded = {}
            Srendarr.db.updateDB.MajorRemoved = {}
            d('Srendarr:FullUpdate - scanning GetAbilityBuffType for BuffType ' .. tostring(BUFF_TYPE_SCAN_MIN) .. '..' .. tostring(BUFF_TYPE_SCAN_MAX) .. '...')
        end
    end

    local tempInt = (stage == 1) and 0 or 1
    local IdLow = (50000 * stage) - 50000
    local IdHigh = 50000 * stage

    for i = IdLow, IdHigh, 1 do
        local abilityID = i + tempInt
        if DoesAbilityExist(abilityID) then
            if (full) and (abilityID > maxID) then
                maxID = abilityID
            end
            local buffType, isValid = GetAbilityBuffType(abilityID, 'player')
            if isValid ~= false and buffTypeScan[buffType] then
                local mapping = BuffTypeMap[buffType]
                buffTypeScan[buffType][abilityID] = '[' .. tostring(abilityID) .. '] = ' .. mapping.effectName .. ','
            end
        end
        if i == IdHigh then
            if stage == maxStage then
                if filterBuffType then
                    UpdateIDTable(buffTypeScan[filterBuffType], BuffTypeMap[filterBuffType], false)
                else
                    for mappedType = BUFF_TYPE_SCAN_MIN, BUFF_TYPE_SCAN_MAX do
                        local mapping = BuffTypeMap[mappedType]
                        if mapping then
                            UpdateIDTable(buffTypeScan[mappedType], mapping, full)
                        end
                    end
                    if (full) then
                        d('Max ID found: ' .. tostring(maxID))
                        d('Done: Reload UI to export to SV.')
                    end
                end
            else
                zo_callLater(function () ScanBuffTypes(stage + 1, full, maxID, filterBuffType) end, 500)
                return
            end
        end
    end
end

-- Usage: /script Srendarr:GetEffects(64) -- Minor Vexation (BuffType numeric, P51 0..65)
function Srendarr:GetEffects(buffType)
    local mappedType = tonumber(buffType)
    if BuffTypeMap[mappedType] == nil then
        d('Srendarr:GetEffects - unknown BuffType ' .. tostring(buffType) .. ' (use numeric BuffType 0..' .. tostring(BUFF_TYPE_SCAN_MAX) .. ')')
        return
    end
    d('Processing ' .. BuffTypeMap[mappedType].displayName .. ' (BuffType ' .. tostring(mappedType) .. ')')
    ScanBuffTypes(1, false, 0, mappedType)
end

-- One-pass Major/Minor audit via GetAbilityBuffType (replaces name-substring FullUpdate)
-- Usage: /script Srendarr:FullUpdate()
function Srendarr:FullUpdate()
    ScanBuffTypes(1, true, 0, nil)
end
