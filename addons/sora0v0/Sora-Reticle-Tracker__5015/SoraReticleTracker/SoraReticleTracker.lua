-- New, independent addon. The old SoraSorcReticleTracker is discontinued.
SoraReticleTracker = SoraReticleTracker or {}
local SSRT = SoraReticleTracker

local ADDON_NAME = "SoraReticleTracker"
local SAVED_VARS = "SoraReticleTrackerSavedVariables"
local SAVED_VARS_VERSION = 2

local CRYSTAL_FRAGMENTS_PROC_EFFECT_ID = 46327
-- Crystal Weapon (Sora's live log, 2026-10-26); prototype uses actual bonus damage packets.
local CRYSTAL_WEAPON_BUFF_ID = 46331
local CRYSTAL_WEAPON_BONUS_DAMAGE_IDS = { [143804] = true, [181056] = true }
local CRYSTAL_WEAPON_ARMORY_ICON_INDEX = 31
-- Skill ability ID, distinct from the proc buff ID. Confirm in game before release.
local CRYSTAL_FRAGMENTS_SKILL_ABILITY_ID = 46324
local BOUND_ARMAMENTS_ABILITY_ID = 24165
local BOUND_ARMAMENTS_STACK_EFFECT_ID = 203447

local CRUX_ABILITY_ID = 184220

-- Nightblade Grim Focus family permanent stack effects.
-- U39+ stack effect IDs:
-- Grim Focus 122585 / Merciless Resolve 122586 / Relentless Focus 122587.
local NIGHTBLADE_STACK_EFFECTS = {
    [122585] = 5, -- Grim Focus: ready at 5
    [122586] = 5, -- Merciless Resolve: ready at 5
    [122587] = 4, -- Relentless Focus: ready at 4
}

-- Traveling Knife is crafted ability (grimoire) ID 7.
-- Warrior's Opportunity is identified by its signature-script icon so the
-- tracker does not depend on a localized script name or a re-scribed cast ID.
local TRAVELING_KNIFE_CRAFTED_ID = 7
local WARRIORS_OPPORTUNITY_SCRIPT_ICON_TOKEN = "scribing_secondary_opportunism.dds"
local WARRIORS_OPPORTUNITY_DURATION = 5
-- Backlash morph skill IDs across ranks, from ESOUI historical skill list.
-- Cast-based fallback; in-game effect end behavior remains to be verified.
local BACKLASH_CAST_IDS = {
    [21763] = true, [27569] = true, [27578] = true, [27587] = true, -- Power of the Light
    [21765] = true, [27534] = true, [27549] = true, [27558] = true, -- Purifying Light
}
local BACKLASH_DURATION = 6
local TEMPLAR_EXECUTE_IDS = { [63029] = true, [63044] = true, [63046] = true }
local TEMPLAR_EXECUTE_SECONDS = 3.8 -- combat log hitValue=3800; verify end timing in game
local TEMPLAR_EXECUTE_DEFAULT_ICON = 24 -- Sora selected icon; Backlash stays 23
local BACKLASH_DEFAULT_ICON = 25 -- Sora: reserve icon 23 for Templar Rune Focus.

local FATECARVER_IDS = {
    [185805] = true, -- Fatecarver (Magicka)
    [193331] = true, -- Fatecarver (Stamina)
    [183122] = true, -- Exhausting Fatecarver (Magicka)
    [193397] = true, -- Exhausting Fatecarver (Stamina)
    [186366] = true, -- Pragmatic Fatecarver (Magicka)
    [193398] = true, -- Pragmatic Fatecarver (Stamina)
}

local REMEDY_CASCADE_IDS = {
    [183537] = true, -- Remedy Cascade (Magicka)
    [198309] = true, -- Remedy Cascade (Stamina)
    [186193] = true, -- Cascading Fortune (Magicka)
    [198330] = true, -- Cascading Fortune (Stamina)
    [186200] = true, -- Curative Surge (Magicka)
    [198537] = true, -- Curative Surge (Stamina)
}

local BEAM_IDS = {}
for abilityId in pairs(FATECARVER_IDS) do
    BEAM_IDS[abilityId] = true
end
for abilityId in pairs(REMEDY_CASCADE_IDS) do
    BEAM_IDS[abilityId] = true
end

local ARMORY_ICON_FORMAT = "EsoUI/Art/Armory/BuildIcons/buildIcon_%d.dds"
local CRYSTAL_ARMORY_ICON_INDEX = 20
local BOUND_ARMORY_ICON_INDEX = 39
local BEAM_ARMORY_ICON_INDEX = 76
local CRUX_ARMORY_ICON_INDEX = 75
local NIGHTBLADE_ARMORY_ICON_INDEX = 56
local WARRIOR_ARMORY_ICON_INDEX = 53
local MAELSTROM_ARMORY_ICONS = { stampede = 52, wall = 58, hail = 56 }

-- Dragonknight: Molten Whip stacks and magicka breath channel.
-- Engulfing Dragonfire is a ~4.8s channel, NOT the old Engulfing Flames DoT.
-- Precise effect IDs are intentionally not guessed; use diagnostic events.
local DK_CHANNEL_SECONDS = 4.8
local DK_WHIP_STACK_EFFECT_ID = 122658 -- observed in game: Seething Fury stacks 1, 2, 3
local DK_ICON_WHIP = 6 -- selected by Sora
local DK_ICON_BREATH = 7 -- selected by Sora
local DK_CORE_ICON = 7 -- Sora: Core of Flame support indicator
-- Verified in-game: independent player-buff stack effect for each Skull morph.
local NECRO_SKULL_EFFECTS = { [114131] = true, [117638] = true, [117625] = true }
local NECRO_SKULL_ICON = 18
local TANK_RESOLVE_EFFECT_ID = 61694 -- exact player buff requested by Sora
-- Scribing: Ulfsild's Contingency + Gladiator's Tenacity signature.
-- Community combat logs report the buff as Tenacious Contingency (217654).
-- Player-buff ID requires live confirmation; never infer it from a cast timer.
local GLADIATOR_TENACITY_BUFF_ID = 217654
local MAJOR_VITALITY_EFFECT_ID = 61713 -- Sora: Major Vitality from scribed pull; validate with own buff in game
local TANK_RESOLVE_ICON = 73
-- Shared defensive/support buff groups. Matching is by ESO BuffType, not
-- by the action that gave the buff, so subclasses, sets, and allies work.
-- Major Vitality 61713 / Major Resolve 61694 are preserved fallbacks.
local DEFENSE_GROUPS = {
    heroism = {major = BUFF_TYPE_MAJOR_HEROISM, minor = BUFF_TYPE_MINOR_HEROISM},
    protection = {major = BUFF_TYPE_MAJOR_PROTECTION, minor = BUFF_TYPE_MINOR_PROTECTION},
    tankResolve = {major = BUFF_TYPE_MAJOR_RESOLVE, minor = BUFF_TYPE_MINOR_RESOLVE},
    mending = {major = BUFF_TYPE_MAJOR_MENDING, minor = BUFF_TYPE_MINOR_MENDING},
    vitality = {major = BUFF_TYPE_MAJOR_VITALITY, minor = BUFF_TYPE_MINOR_VITALITY},
    -- Shared offensive buffs. Resolve by actual player effect, regardless of source.
    brutality = {major = BUFF_TYPE_MAJOR_BRUTALITY, minor = BUFF_TYPE_MINOR_BRUTALITY},
    berserk = {major = BUFF_TYPE_MAJOR_BERSERK, minor = BUFF_TYPE_MINOR_BERSERK},
    savagery = {major = BUFF_TYPE_MAJOR_SAVAGERY, minor = BUFF_TYPE_MINOR_SAVAGERY},
    force = {major = BUFF_TYPE_MAJOR_FORCE, minor = BUFF_TYPE_MINOR_FORCE},
    slayer = {major = BUFF_TYPE_MAJOR_SLAYER, minor = BUFF_TYPE_MINOR_SLAYER},
    evasion = {major = BUFF_TYPE_MAJOR_EVASION, minor = BUFF_TYPE_MINOR_EVASION},
}
local DEFENSE_COLORS = {
    heroism = {1.00, 0.77, 0.29}, -- warm gold: Ultimate generation
    protection = {0.52, 0.72, 1.00}, -- calm blue: damage reduction
    tankResolve = {0.42, 0.95, 0.51}, -- trial green: Major Resolve
    mending = {1.00, 0.49, 0.75}, -- pink: healing done
    vitality = {1.00, 0.36, 0.40}, -- red: healing received
    brutality = {0.95, 0.18, 0.21}, -- bright central red
    berserk = {0.75, 0.24, 0.29}, -- dark crimson, left
    savagery = {1.00, 0.39, 0.23}, -- vermilion, right
    force = {0.96, 0.51, 0.29}, -- warm orange-red, far right
    slayer = {0.67, 0.23, 0.30}, -- wine red, far left
    evasion = {0.37, 0.83, 0.78}, -- calm mint-teal, support row
}
-- Keep the mature major/minor buff scanner and paired display for attack buffs.
local DEFENSE_KEYS = {"heroism", "protection", "tankResolve", "mending", "vitality", "evasion", "slayer", "berserk", "brutality", "savagery", "force"}
local DEBUFF_TAUNT_ID = 38254
local DEBUFF_MINOR_VULNERABILITY_ID = 79717 -- diagnostic reference, scan by buff type for any source
local DEBUFF_BREACH_ICON = 44
local DEBUFF_VULNERABILITY_ICON = 71
-- Keep target debuffs outside the central Ultimate display on initial layout.
local DEBUFF_BREACH_X, DEBUFF_VULNERABILITY_X = -60, 60

local SLOT_FIRST = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local SLOT_LAST = SLOT_FIRST + 4

local GEAR_EVENT_NAME = ADDON_NAME .. "Gear"
local UpdateMaelstromEventRegistration
local defaults = {
    debuffTauntEnabled = true,
    debuffBreachMajorEnabled = true, debuffBreachMinorEnabled = true,
    debuffVulnerabilityMajorEnabled = true, debuffVulnerabilityMinorEnabled = true,
    debuffBreachMajorOnTop = true, debuffVulnerabilityMajorOnTop = true,
    debuffMajorSize = 48, debuffMinorSize = 36, debuffTextSize = 24, -- legacy values for migration only
    debuffSizeSplitMigrated = false,
    debuffTauntTextSize = 24, -- taunt has no icon; number only
    debuffBreachMajorSize = 48, debuffBreachMinorSize = 36,
    debuffBreachMajorTextSize = 24, debuffBreachMinorTextSize = 24,
    debuffVulnerabilityMajorSize = 48, debuffVulnerabilityMinorSize = 36,
    debuffVulnerabilityMajorTextSize = 24, debuffVulnerabilityMinorTextSize = 24,
    -- Both effect grades use the same group base X/Y, with a fixed in-group Y gap.
    debuffTauntOffsetX = 0, debuffTauntOffsetY = 0,
    debuffBreachOffsetX = -60, debuffBreachOffsetY = 0,
    debuffVulnerabilityOffsetX = 60, debuffVulnerabilityOffsetY = 0,
    guardIndicatorEnabled = true,
    guardSize = 80, guardOffsetX = 0, guardOffsetY = 0,
    guardFrostTriFocus = true, -- legacy saved setting; never used to override automatic detection
    guardForceMagicka = false, -- legacy saved setting; equipment detection is automatic
    roleFilters = {}, -- per-tracker role masks; nil means all roles (backwards-compatible)
    crystalEnabled = true,
    boundEnabled = true,
    beamEnabled = true,
    cruxEnabled = true,
    nightbladeEnabled = true,
    warriorEnabled = true,
    necroCorpseEnabled = true,
    necroSkullEnabled = true,
    necroSkullOffsetX = -60, necroSkullOffsetY = 80,
    necroSkullIconSize = 78, necroSkullTextSize = 35,
    necroCorpseOffsetX = 60, necroCorpseOffsetY = 80,
    necroCorpseIconSize = 78,
    -- Initial attack-buff row replaces the Ultimate's original Y=-92 position.
    -- The existing Ult starts at the old planned buff-row Y=-225 instead.
    berserkEnabled = true, berserkMinorEnabled = true,
    berserkOffsetX = -120, berserkOffsetY = -92,
    berserkIconIndex = 45, berserkIconSize = 78, berserkTextSize = 35,
    berserkMinorIconSize = 36, berserkMinorTextSize = 21, berserkMajorOnTop = true,
    brutalityEnabled = true, brutalityMinorEnabled = true,
    brutalityOffsetX = 0, brutalityOffsetY = -92,
    brutalityIconIndex = 44, brutalityIconSize = 78, brutalityTextSize = 35,
    brutalityMinorIconSize = 36, brutalityMinorTextSize = 21, brutalityMajorOnTop = true,
    savageryEnabled = true, savageryMinorEnabled = true,
    savageryOffsetX = 120, savageryOffsetY = -92,
    savageryIconIndex = 59, savageryIconSize = 78, savageryTextSize = 35,
    savageryMinorIconSize = 36, savageryMinorTextSize = 21, savageryMajorOnTop = true,
    -- Permanent/offline buffs are optional: reduce default HUD obstruction.
    berserkMajorShowPermanent = false, berserkMinorShowPermanent = false,
    brutalityMajorShowPermanent = false, brutalityMinorShowPermanent = false,
    savageryMajorShowPermanent = false, savageryMinorShowPermanent = false,
    slayerEnabled = true, slayerMinorEnabled = true,
    slayerOffsetX = -240, slayerOffsetY = -92,
    slayerIconIndex = 43, slayerIconSize = 78, slayerTextSize = 35,
    slayerMinorIconSize = 36, slayerMinorTextSize = 21, slayerMajorOnTop = true,
    slayerMajorShowPermanent = false, slayerMinorShowPermanent = false,
    forceEnabled = true, forceMinorEnabled = true,
    forceOffsetX = 240, forceOffsetY = -92,
    forceIconIndex = 36, forceIconSize = 78, forceTextSize = 35,
    forceMinorIconSize = 36, forceMinorTextSize = 21, forceMajorOnTop = true,
    forceMajorShowPermanent = false, forceMinorShowPermanent = false,
    dkWhipEnabled = true,
    dkBreathEnabled = true,
    dkCoreEnabled = true,
    crystalSilentBlockEnabled = false, -- opt-in; requires LibSkillBlocker
    crystalOffsetX = -60,
    crystalOffsetY = 80,
    boundOffsetX = 60,
    boundOffsetY = 80,

    crystalIconSize = 78,
    crystalTextSize = 35,

    boundIconSize = 94,
    boundTextSize = 35,

    beamOffsetX = 60,
    beamOffsetY = 80,
    beamIconSize = 78,
    beamTextSize = 35,

    cruxOffsetX = -60,
    cruxOffsetY = 80,
    cruxIconSize = 94,
    cruxTextSize = 35,

    nightbladeOffsetX = 60,
    nightbladeOffsetY = 80,
    nightbladeIconSize = 94,
    nightbladeTextSize = 35,

    warriorOffsetX = -60,
    warriorOffsetY = 80,
    warriorIconSize = 78,
    warriorTextSize = 35,

    templarRuneEnabled = true,
    templarRuneOffsetX = 0, templarRuneOffsetY = 260, -- support zone, below tank row
    templarRuneIconSize = 78, templarRuneTextSize = 35,
    templarRuneIconIndex = 23,
    tankResolveEnabled = true,
    heroismEnabled = true, protectionEnabled = true, mendingEnabled = true,
    heroismOffsetX = -150, heroismOffsetY = 180,
    heroismIconIndex = 51, heroismIconSize = 78, heroismTextSize = 35,
    protectionOffsetX = -90, protectionOffsetY = 180,
    protectionIconIndex = 72, protectionIconSize = 78, protectionTextSize = 35,
    mendingOffsetX = -60, mendingOffsetY = 260,
    mendingIconIndex = 2, mendingIconSize = 78, mendingTextSize = 35,
    evasionEnabled = true, evasionMinorEnabled = true,
    evasionOffsetX = 150, evasionOffsetY = 260, -- support row: right of Vitality
    evasionIconIndex = 13, evasionIconSize = 78, evasionTextSize = 35,
    evasionMinorIconSize = 36, evasionMinorTextSize = 21, evasionMajorOnTop = true,
    evasionMajorShowPermanent = true, evasionMinorShowPermanent = true,
    -- Pair layout: major and minor occupy fixed slots even if one is absent.
    defenseShowPermanentBuffs = true, -- non-expiring buff icons (passive-like)
    heroismMinorEnabled = true, protectionMinorEnabled = true,
    tankResolveMinorEnabled = true, mendingMinorEnabled = true, vitalityMinorEnabled = true,
    heroismMajorOnTop = true, protectionMajorOnTop = true,
    tankResolveMajorOnTop = true, mendingMajorOnTop = true, vitalityMajorOnTop = true,
    heroismMinorIconSize = 36, protectionMinorIconSize = 36,
    tankResolveMinorIconSize = 36, mendingMinorIconSize = 36, vitalityMinorIconSize = 36,
    heroismMinorTextSize = 21, protectionMinorTextSize = 21,
    tankResolveMinorTextSize = 21, mendingMinorTextSize = 21, vitalityMinorTextSize = 21,
    vitalityEnabled = true,
    vitalityOffsetX = 60, vitalityOffsetY = 260, -- right of Rune Focus; left Mending, center Rune
    vitalityIconIndex = 9, vitalityIconSize = 78, vitalityTextSize = 35,
    gladiatorEnabled = true,
    gladiatorOffsetX = -30, gladiatorOffsetY = 180, -- opposite the shield's +30 / 180
    gladiatorIconIndex = 77, gladiatorIconSize = 78, gladiatorTextSize = 35,
    shieldEnabled = true,
    shieldOffsetX = 30, shieldOffsetY = 180,
    shieldIconIndex = 34, shieldIconSize = 78, shieldTextSize = 35,
    tankResolveOffsetX = 90, tankResolveOffsetY = 180,
    tankResolveIconIndex = TANK_RESOLVE_ICON, tankResolveIconSize = 78, tankResolveTextSize = 35,
    templarBeamEnabled = true,
    templarBeamOffsetX = 60, templarBeamOffsetY = 80,
    templarBeamIconSize = 78, templarBeamTextSize = 35,
    templarBeamIconIndex = TEMPLAR_EXECUTE_DEFAULT_ICON,
    backlashEnabled = true,
    backlashOffsetX = -60,
    backlashOffsetY = 80,
    backlashTextSize = 35,
    backlashIconSize = 78,
    backlashIconIndex = BACKLASH_DEFAULT_ICON,
    wardenEnabled = true,
    wardenOffsetX = -60,
    wardenOffsetY = 80,
    wardenIconSize = 78,
    wardenTextSize = 35,
    wardenIconIndex = 27, -- Sora confirmed Warden icon.
    wardenFlyEnabled = true,
    wardenFlyOffsetX = 60, wardenFlyOffsetY = 80,
    wardenFlyIconSize = 78, wardenFlyTextSize = 35,
    wardenFlyIconIndex = 68,

    dkEnabled = true,
    dkWhipOffsetX = -60, dkWhipOffsetY = 80,
    dkBreathOffsetX = 60, dkBreathOffsetY = 80,
    dkCoreOffsetX = 0, dkCoreOffsetY = 170,
    dkWhipIconIndex = DK_ICON_WHIP, dkBreathIconIndex = DK_ICON_BREATH,
    dkCoreIconIndex = DK_CORE_ICON,
    dkIconSize = 78, dkTextSize = 35,
    dkWhipIconSize = 78, dkWhipTextSize = 35,
    dkBreathIconSize = 78, dkBreathTextSize = 35,
    dkCoreIconSize = 78, dkCoreTextSize = 35,
    maelstromEnabled = true,
    maelstromStampedeEnabled = true,
    maelstromWallEnabled = true,
    maelstromHailEnabled = true,
    maelstromOffsetX = 0,
    maelstromOffsetY = 45,
    maelstromTextSize = 28,
    maelstromIconSize = 78,

    ultimateEnabled = true,
    ultimateHideWithSignet = false, -- optional HUD-only hiding when the Signet is equipped
    ultimateFrontEnabled = true,
    ultimateBackEnabled = true,
    ultimateOffsetX = 0,
    ultimateOffsetY = -225,
    ultimateScale = 100,
}


SSRT.necroSkullStacks = 0
SSRT.necroSkullEffectId = nil
SSRT.vitalityEnd = 0
SSRT.defenseBuffEnds = {}
SSRT.dkWhipStacks = 0
SSRT.dkWhipEffectEnd = 0
SSRT.dkBreathEnd = 0
SSRT.dkCoreEnd = 0
SSRT.crystalActive = false
SSRT.crystalEndTime = 0
SSRT.boundStacks = 0
SSRT.wardenFirstHit = 0
SSRT.wardenSecondHit = 0
SSRT.wardenFlyReady = false
SSRT.beamActive = false
SSRT.beamEndTimeMs = 0
SSRT.cruxStacks = 0
SSRT.nightbladeStacks = 0
SSRT.nightbladeReadyAt = 5
SSRT.warriorOpportunityEndTime = 0
SSRT.backlashEndTime = 0
SSRT.templarBeamEnd = 0
SSRT.wasBlockActive = false
SSRT.maelstromKind = nil
SSRT.maelstromSlot = nil
SSRT.moveTarget = nil

local function Chat(text)
    d("|c66ccff[SoraReticleTracker]|r " .. tostring(text))
end

local function BuildFont(size)
    return string.format("$(BOLD_FONT)|%d|thick-outline", zo_round(size))
end

local function GetArmoryIconTexture(index)
    return string.format(ARMORY_ICON_FORMAT, index)
end

local function RefreshUltimateSignetEquipped()
    return SSRT.Ultimate.RefreshSignet()
end

local function ApplyIconTextures()
    if SSRT.crystalIcon then
        local texture = GetArmoryIconTexture(CRYSTAL_ARMORY_ICON_INDEX)
        SSRT.crystalGlowOuter:SetTexture(texture)
        SSRT.crystalGlowMid:SetTexture(texture)
        SSRT.crystalIcon:SetTexture(texture)
    end

    if SSRT.boundIcon then
        local texture = GetArmoryIconTexture(BOUND_ARMORY_ICON_INDEX)
        SSRT.boundGlowOuter:SetTexture(texture)
        SSRT.boundGlowMid:SetTexture(texture)
        SSRT.boundIcon:SetTexture(texture)
    end

    if SSRT.beamIcon then
        local texture = GetArmoryIconTexture(BEAM_ARMORY_ICON_INDEX)
        SSRT.beamGlowOuter:SetTexture(texture)
        SSRT.beamGlowMid:SetTexture(texture)
        SSRT.beamIcon:SetTexture(texture)
    end

    if SSRT.cruxIcon then
        local texture = GetArmoryIconTexture(CRUX_ARMORY_ICON_INDEX)
        SSRT.cruxGlowOuter:SetTexture(texture)
        SSRT.cruxGlowMid:SetTexture(texture)
        SSRT.cruxIcon:SetTexture(texture)
    end

    if SSRT.nightbladeIcon then
        local texture = GetArmoryIconTexture(NIGHTBLADE_ARMORY_ICON_INDEX)
        SSRT.nightbladeGlowOuter:SetTexture(texture)
        SSRT.nightbladeGlowMid:SetTexture(texture)
        SSRT.nightbladeIcon:SetTexture(texture)
    end

    if SSRT.warriorIcon then
        local texture = GetArmoryIconTexture(WARRIOR_ARMORY_ICON_INDEX)
        SSRT.warriorGlowOuter:SetTexture(texture)
        SSRT.warriorGlowMid:SetTexture(texture)
        SSRT.warriorIcon:SetTexture(texture)
    end
end

local function SetBoundStackColor(stacks)
    if not SSRT.boundStack then return end
    if stacks >= 4 then
        SSRT.boundStack:SetColor(1.00, 0.22, 0.18, 1.00)
    elseif stacks == 3 then
        SSRT.boundStack:SetColor(1.00, 0.78, 0.08, 1.00)
    else
        SSRT.boundStack:SetColor(1.00, 1.00, 1.00, 1.00)
    end
end

local function SetCruxStackColor(stacks)
    if not SSRT.cruxStack then return end
    if stacks >= 3 then
        SSRT.cruxStack:SetColor(1.00, 0.24, 0.18, 1.00)
    elseif stacks == 2 then
        SSRT.cruxStack:SetColor(1.00, 0.82, 0.12, 1.00)
    else
        SSRT.cruxStack:SetColor(1.00, 1.00, 1.00, 1.00)
    end
end

local function SetNightbladeStackColor(stacks, readyAt)
    if not SSRT.nightbladeStack then return end

    if stacks >= readyAt then
        SSRT.nightbladeStack:SetColor(1.00, 0.24, 0.18, 1.00)
    elseif stacks == readyAt - 1 then
        SSRT.nightbladeStack:SetColor(1.00, 0.52, 0.08, 1.00)
    else
        SSRT.nightbladeStack:SetColor(1.00, 1.00, 1.00, 1.00)
    end
end

local function ApplyCrystalPosition()
    SSRT.crystalWindow:ClearAnchors()
    SSRT.crystalWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.crystalOffsetX,
        SSRT.sv.crystalOffsetY
    )
end

local function ApplyBoundPosition()
    SSRT.boundWindow:ClearAnchors()
    SSRT.boundWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.boundOffsetX,
        SSRT.sv.boundOffsetY
    )
end

local function ApplyBeamPosition()
    SSRT.beamWindow:ClearAnchors()
    SSRT.beamWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.beamOffsetX,
        SSRT.sv.beamOffsetY
    )
end

local function ApplyCruxPosition()
    SSRT.cruxWindow:ClearAnchors()
    SSRT.cruxWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.cruxOffsetX,
        SSRT.sv.cruxOffsetY
    )
end

local function ApplyNightbladePosition()
    SSRT.nightbladeWindow:ClearAnchors()
    SSRT.nightbladeWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.nightbladeOffsetX,
        SSRT.sv.nightbladeOffsetY
    )
end

local function ApplyWarriorPosition()
    SSRT.warriorWindow:ClearAnchors()
    SSRT.warriorWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.warriorOffsetX,
        SSRT.sv.warriorOffsetY
    )
end

local function ApplyBacklashPosition()
    SSRT.backlashWindow:ClearAnchors()
    SSRT.backlashWindow:SetAnchor(CENTER, GuiRoot, CENTER, SSRT.sv.backlashOffsetX, SSRT.sv.backlashOffsetY)
end

local function ApplyTemplarBeamPosition()
    local window = SSRT.templarBeamWindow
    window:ClearAnchors()
    window:SetAnchor(CENTER, GuiRoot, CENTER, SSRT.sv.templarBeamOffsetX, SSRT.sv.templarBeamOffsetY)
end

local function ApplyMaelstromPosition()
    SSRT.maelstromWindow:ClearAnchors()
    SSRT.maelstromWindow:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        SSRT.sv.maelstromOffsetX,
        SSRT.sv.maelstromOffsetY
    )
end

local function ApplyUltimatePosition()
    return SSRT.Ultimate.ApplyPosition()
end

local function ApplyWardenPosition()
    SSRT.wardenWindow:ClearAnchors()
    SSRT.wardenWindow:SetAnchor(CENTER, GuiRoot, CENTER, SSRT.sv.wardenOffsetX, SSRT.sv.wardenOffsetY)
end

local function SaveControlOffset(controlName)
    local control
    if controlName == "crystal" then
        control = SSRT.crystalWindow
    elseif controlName == "bound" then
        control = SSRT.boundWindow
    elseif controlName == "beam" then
        control = SSRT.beamWindow
    elseif controlName == "crux" then
        control = SSRT.cruxWindow
    elseif controlName == "nightblade" then
        control = SSRT.nightbladeWindow
    elseif controlName == "warrior" then
        control = SSRT.warriorWindow
    elseif controlName == "dkWhip" or controlName == "dkBreath" or controlName == "dkCore" or controlName == "necroCorpse" or controlName == "necroSkull" or controlName == "templarBeam" or controlName == "wardenFly" or controlName == "templarRune" or controlName == "vitality" or controlName == "heroism" or controlName == "protection" or controlName == "mending" or controlName == "tankResolve" or controlName == "gladiator" or controlName == "slayer" or controlName == "berserk" or controlName == "brutality" or controlName == "savagery" or controlName == "force" or controlName == "evasion" then
        control = SSRT[controlName .. "Window"]
    elseif controlName == "warden" then
        control = SSRT.wardenWindow
    elseif controlName == "backlash" then
        control = SSRT.backlashWindow
    elseif controlName == "ultimate" then
        control = SSRT.ultimateWindow
    elseif controlName == "shield" then
        control = SSRT.shieldWindow
    elseif controlName == "guardIndicator" then
        control = SSRT.guardOutlineWindow
    else
        control = SSRT.maelstromWindow
    end

    local x, y = control:GetCenter()
    local gx, gy = GuiRoot:GetCenter()
    if not (x and y and gx and gy) then return end

    if controlName == "crystal" then
        SSRT.sv.crystalOffsetX = zo_round(x - gx)
        SSRT.sv.crystalOffsetY = zo_round(y - gy)
        ApplyCrystalPosition()
    elseif controlName == "bound" then
        SSRT.sv.boundOffsetX = zo_round(x - gx)
        SSRT.sv.boundOffsetY = zo_round(y - gy)
        ApplyBoundPosition()
    elseif controlName == "beam" then
        SSRT.sv.beamOffsetX = zo_round(x - gx)
        SSRT.sv.beamOffsetY = zo_round(y - gy)
        ApplyBeamPosition()
    elseif controlName == "crux" then
        SSRT.sv.cruxOffsetX = zo_round(x - gx)
        SSRT.sv.cruxOffsetY = zo_round(y - gy)
        ApplyCruxPosition()
    elseif controlName == "nightblade" then
        SSRT.sv.nightbladeOffsetX = zo_round(x - gx)
        SSRT.sv.nightbladeOffsetY = zo_round(y - gy)
        ApplyNightbladePosition()
    elseif controlName == "dkWhip" or controlName == "dkBreath" or controlName == "dkCore" or controlName == "necroCorpse" or controlName == "necroSkull" or controlName == "templarBeam" or controlName == "wardenFly" or controlName == "templarRune" or controlName == "vitality" or controlName == "heroism" or controlName == "protection" or controlName == "mending" or controlName == "tankResolve" or controlName == "gladiator" or controlName == "slayer" or controlName == "berserk" or controlName == "brutality" or controlName == "savagery" or controlName == "force" or controlName == "evasion" then
        SSRT.sv[controlName .. "OffsetX"] = zo_round(x - gx)
        SSRT.sv[controlName .. "OffsetY"] = zo_round(y - gy)
        ApplyDKPositions()
    elseif controlName == "warden" then
        SSRT.sv.wardenOffsetX = zo_round(x - gx)
        SSRT.sv.wardenOffsetY = zo_round(y - gy)
        ApplyWardenPosition()
    elseif controlName == "backlash" then
        SSRT.sv.backlashOffsetX = zo_round(x - gx)
        SSRT.sv.backlashOffsetY = zo_round(y - gy)
        ApplyBacklashPosition()
    elseif controlName == "warrior" then
        SSRT.sv.warriorOffsetX = zo_round(x - gx)
        SSRT.sv.warriorOffsetY = zo_round(y - gy)
        ApplyWarriorPosition()
    elseif controlName == "shield" then
        SSRT.sv.shieldOffsetX = zo_round(x - gx)
        SSRT.sv.shieldOffsetY = zo_round(y - gy)
        SSRT.Shield.ApplyPosition()
    elseif controlName == "guardIndicator" then
        SSRT.sv.guardOffsetX = zo_round(x - gx)
        SSRT.sv.guardOffsetY = zo_round(y - gy)
        -- This function is declared before ApplyGuardPosition; anchor directly
        -- to avoid accidentally calling a global of the same name.
        SSRT.guardOutlineWindow:ClearAnchors()
        SSRT.guardOutlineWindow:SetAnchor(CENTER, GuiRoot, CENTER,
            SSRT.sv.guardOffsetX, SSRT.sv.guardOffsetY)
    elseif controlName == "ultimate" then
        SSRT.sv.ultimateOffsetX = zo_round(x - gx)
        SSRT.sv.ultimateOffsetY = zo_round(y - gy)
        ApplyUltimatePosition()
    else
        SSRT.sv.maelstromOffsetX = zo_round(x - gx)
        SSRT.sv.maelstromOffsetY = zo_round(y - gy)
        ApplyMaelstromPosition()
    end
end

local function ApplyUltimateVisualSettings()
    return SSRT.Ultimate.ApplyVisualSettings()
end

-- Forward declaration: ApplyVisualSettings calls this function before its definition.
local ApplyDefensePairLayout

local function ApplyVisualSettings()
    -- Crystal
    local crystalSize = SSRT.sv.crystalIconSize
    local crystalWindowSize = math.max(126, crystalSize + 44)
    SSRT.crystalWindow:SetDimensions(crystalWindowSize, crystalWindowSize)

    SSRT.crystalGlowOuter:SetDimensions(crystalSize + 30, crystalSize + 30)
    SSRT.crystalGlowMid:SetDimensions(crystalSize + 14, crystalSize + 14)
    SSRT.crystalIcon:SetDimensions(crystalSize, crystalSize)

    SSRT.crystalTimer:SetDimensions(crystalSize + 16, crystalSize + 16)
    SSRT.crystalTimer:SetFont(BuildFont(SSRT.sv.crystalTextSize))
    SSRT.crystalTimer:ClearAnchors()
    SSRT.crystalTimer:SetAnchor(CENTER, SSRT.crystalWindow, CENTER, 0, 0)

    -- Bound
    local boundSize = SSRT.sv.boundIconSize
    local boundWindowSize = math.max(132, boundSize + 52)
    SSRT.boundWindow:SetDimensions(boundWindowSize, boundWindowSize)

    SSRT.boundGlowOuter:SetDimensions(boundSize + 30, boundSize + 30)
    SSRT.boundGlowMid:SetDimensions(boundSize + 14, boundSize + 14)
    SSRT.boundIcon:SetDimensions(boundSize, boundSize)

    SSRT.boundStack:SetDimensions(boundSize + 16, boundSize + 16)
    SSRT.boundStack:SetFont(BuildFont(SSRT.sv.boundTextSize))
    SSRT.boundStack:ClearAnchors()
    SSRT.boundStack:SetAnchor(CENTER, SSRT.boundWindow, CENTER, 0, 0)

    -- Arcanist Beam
    local beamSize = SSRT.sv.beamIconSize
    local beamWindowSize = math.max(126, beamSize + 44)
    SSRT.beamWindow:SetDimensions(beamWindowSize, beamWindowSize)
    SSRT.beamGlowOuter:SetDimensions(beamSize + 30, beamSize + 30)
    SSRT.beamGlowMid:SetDimensions(beamSize + 14, beamSize + 14)
    SSRT.beamIcon:SetDimensions(beamSize, beamSize)
    SSRT.beamTimer:SetDimensions(beamSize + 16, beamSize + 16)
    SSRT.beamTimer:SetFont(BuildFont(SSRT.sv.beamTextSize))
    SSRT.beamTimer:ClearAnchors()
    SSRT.beamTimer:SetAnchor(CENTER, SSRT.beamWindow, CENTER, 0, 0)

    -- Crux
    local cruxSize = SSRT.sv.cruxIconSize
    local cruxWindowSize = math.max(132, cruxSize + 52)
    SSRT.cruxWindow:SetDimensions(cruxWindowSize, cruxWindowSize)
    SSRT.cruxGlowOuter:SetDimensions(cruxSize + 30, cruxSize + 30)
    SSRT.cruxGlowMid:SetDimensions(cruxSize + 14, cruxSize + 14)
    SSRT.cruxIcon:SetDimensions(cruxSize, cruxSize)
    SSRT.cruxStack:SetDimensions(cruxSize + 16, cruxSize + 16)
    SSRT.cruxStack:SetFont(BuildFont(SSRT.sv.cruxTextSize))
    SSRT.cruxStack:ClearAnchors()
    SSRT.cruxStack:SetAnchor(CENTER, SSRT.cruxWindow, CENTER, 0, 0)

    -- Nightblade Grim Focus family
    local nightbladeSize = SSRT.sv.nightbladeIconSize
    local nightbladeWindowSize = math.max(132, nightbladeSize + 52)
    SSRT.nightbladeWindow:SetDimensions(nightbladeWindowSize, nightbladeWindowSize)
    SSRT.nightbladeGlowOuter:SetDimensions(nightbladeSize + 30, nightbladeSize + 30)
    SSRT.nightbladeGlowMid:SetDimensions(nightbladeSize + 14, nightbladeSize + 14)
    SSRT.nightbladeIcon:SetDimensions(nightbladeSize, nightbladeSize)
    SSRT.nightbladeStack:SetDimensions(nightbladeSize + 16, nightbladeSize + 16)
    SSRT.nightbladeStack:SetFont(BuildFont(SSRT.sv.nightbladeTextSize))
    SSRT.nightbladeStack:ClearAnchors()
    SSRT.nightbladeStack:SetAnchor(CENTER, SSRT.nightbladeWindow, CENTER, 0, 0)

    -- Traveling Knife + Warrior's Opportunity
    local warriorSize = SSRT.sv.warriorIconSize
    local warriorWindowSize = math.max(126, warriorSize + 44)
    SSRT.warriorWindow:SetDimensions(warriorWindowSize, warriorWindowSize)
    SSRT.warriorGlowOuter:SetDimensions(warriorSize + 30, warriorSize + 30)
    SSRT.warriorGlowMid:SetDimensions(warriorSize + 14, warriorSize + 14)
    SSRT.warriorIcon:SetDimensions(warriorSize, warriorSize)
    SSRT.warriorTimer:SetDimensions(warriorSize + 16, warriorSize + 16)
    SSRT.warriorTimer:SetFont(BuildFont(SSRT.sv.warriorTextSize))
    SSRT.warriorTimer:ClearAnchors()
    SSRT.warriorTimer:SetAnchor(CENTER, SSRT.warriorWindow, CENTER, 0, 0)

    -- Backlash uses the same icon/glow/overlaid timer layout as the class trackers.
    local backlashSize = SSRT.sv.backlashIconSize
    SSRT.backlashWindow:SetDimensions(math.max(126, backlashSize + 44), math.max(126, backlashSize + 44))
    SSRT.backlashGlowOuter:SetDimensions(backlashSize + 30, backlashSize + 30)
    SSRT.backlashGlowMid:SetDimensions(backlashSize + 14, backlashSize + 14)
    SSRT.backlashIcon:SetDimensions(backlashSize, backlashSize)
    SSRT.backlashTimer:SetDimensions(backlashSize + 16, backlashSize + 16)
    SSRT.backlashTimer:SetFont(BuildFont(SSRT.sv.backlashTextSize))
    SSRT.backlashTimer:ClearAnchors()
    SSRT.backlashTimer:SetAnchor(CENTER, SSRT.backlashWindow, CENTER, 0, 0)
    local iconTexture = string.format(ARMORY_ICON_FORMAT, SSRT.sv.backlashIconIndex or BACKLASH_DEFAULT_ICON)
    SSRT.backlashGlowOuter:SetTexture(iconTexture)
    SSRT.backlashGlowMid:SetTexture(iconTexture)
    SSRT.backlashIcon:SetTexture(iconTexture)

    local wardenSize = SSRT.sv.wardenIconSize
    SSRT.wardenWindow:SetDimensions(math.max(126, wardenSize + 44), math.max(126, wardenSize + 44))
    SSRT.wardenGlowOuter:SetDimensions(wardenSize + 30, wardenSize + 30)
    SSRT.wardenGlowMid:SetDimensions(wardenSize + 14, wardenSize + 14)
    SSRT.wardenIcon:SetDimensions(wardenSize, wardenSize)
    SSRT.wardenTimer:SetDimensions(wardenSize + 24, wardenSize + 24)
    SSRT.wardenTimer:SetFont(BuildFont(SSRT.sv.wardenTextSize))
    SSRT.wardenTimer:ClearAnchors()
    SSRT.wardenTimer:SetAnchor(CENTER, SSRT.wardenWindow, CENTER, 0, 0)
    local wardenTexture = GetArmoryIconTexture(SSRT.sv.wardenIconIndex)
    SSRT.wardenGlowOuter:SetTexture(wardenTexture)
    SSRT.wardenGlowMid:SetTexture(wardenTexture)
    SSRT.wardenIcon:SetTexture(wardenTexture)

    for _, key in ipairs({"dkWhip", "dkBreath", "dkCore", "necroCorpse", "necroSkull", "templarBeam", "wardenFly", "tankResolve", "shield", "templarRune", "vitality", "heroism", "protection", "mending", "slayer", "berserk", "brutality", "savagery", "force", "evasion", "gladiator"}) do
        local size = SSRT.sv[key .. "IconSize"]
        local window = SSRT[key .. "Window"]
        window:SetDimensions(math.max(126, size + 44), math.max(126, size + 44))
        SSRT[key .. "GlowOuter"]:SetDimensions(size + 30, size + 30)
        SSRT[key .. "GlowMid"]:SetDimensions(size + 14, size + 14)
        SSRT[key .. "Icon"]:SetDimensions(size, size)
        local label = SSRT[key .. "Label"]
        label:SetDimensions(size + 24, size + 24)
        label:SetFont(BuildFont(SSRT.sv[key .. "TextSize"] or 35))
        label:ClearAnchors()
        label:SetAnchor(CENTER, window, CENTER, 0, 0)
        local tex = GetArmoryIconTexture(key == "necroCorpse" and 16 or (key == "necroSkull" and NECRO_SKULL_ICON or (key == "tankResolve" and TANK_RESOLVE_ICON or SSRT.sv[key .. "IconIndex"])))
        SSRT[key .. "GlowOuter"]:SetTexture(tex)
        SSRT[key .. "GlowMid"]:SetTexture(tex)
        SSRT[key .. "Icon"]:SetTexture(tex)
        if DEFENSE_GROUPS[key] then ApplyDefensePairLayout(key) end
    end
    -- Maelstrom: silver-gray icon and white glow; number retains urgency colors.
    local maelstromIconSize = SSRT.sv.maelstromIconSize or 78
    SSRT.maelstromGlowOuter:SetDimensions(maelstromIconSize + 30, maelstromIconSize + 30)
    SSRT.maelstromGlowMid:SetDimensions(maelstromIconSize + 14, maelstromIconSize + 14)
    SSRT.maelstromIcon:SetDimensions(maelstromIconSize, maelstromIconSize)
    -- Maelstrom back-bar timer.
    local maelstromTextSize = SSRT.sv.maelstromTextSize
    local maelstromWindowWidth = math.max(maelstromIconSize + 44, maelstromTextSize * 2.5)
    local maelstromWindowHeight = math.max(maelstromIconSize + 44, maelstromTextSize * 1.8)
    SSRT.maelstromWindow:SetDimensions(maelstromWindowWidth, maelstromWindowHeight)
    SSRT.maelstromTimer:SetDimensions(maelstromWindowWidth, maelstromWindowHeight)
    SSRT.maelstromTimer:SetFont(BuildFont(maelstromTextSize))
    SSRT.maelstromTimer:ClearAnchors()
    SSRT.maelstromTimer:SetAnchor(CENTER, SSRT.maelstromWindow, CENTER, 0, 0)

    ApplyUltimateVisualSettings()

    SetBoundStackColor(SSRT.boundStacks or 0)
    SetCruxStackColor(SSRT.cruxStacks or 0)
    SetNightbladeStackColor(SSRT.nightbladeStacks or 0, SSRT.nightbladeReadyAt or 5)
    ApplyIconTextures()
end

local function SetMoveTarget(target)
    SSRT.moveTarget = target

    local crystalActive = target == "crystal"
    local boundActive = target == "bound"
    local beamActive = target == "beam"
    local cruxActive = target == "crux"
    local nightbladeActive = target == "nightblade"
    local warriorActive = target == "warrior"
    local maelstromActive = target == "maelstrom"
    local backlashActive = target == "backlash"
    local wardenActive = target == "warden"
    local ultimateActive = target == "ultimate"

    for _, key in ipairs({"dkWhip", "dkBreath", "dkCore", "necroCorpse", "necroSkull", "templarBeam", "wardenFly", "tankResolve", "shield", "templarRune", "vitality", "heroism", "protection", "mending", "slayer", "berserk", "brutality", "savagery", "force", "evasion", "gladiator"}) do
        local active = target == key
        SSRT[key .. "Window"]:SetMouseEnabled(active)
        SSRT[key .. "Window"]:SetMovable(active)
        SSRT[key .. "DragBackdrop"]:SetHidden(not active)
    end
    SSRT.crystalWindow:SetMouseEnabled(crystalActive)
    SSRT.crystalWindow:SetMovable(crystalActive)
    SSRT.boundWindow:SetMouseEnabled(boundActive)
    SSRT.boundWindow:SetMovable(boundActive)
    SSRT.beamWindow:SetMouseEnabled(beamActive)
    SSRT.beamWindow:SetMovable(beamActive)
    SSRT.cruxWindow:SetMouseEnabled(cruxActive)
    SSRT.cruxWindow:SetMovable(cruxActive)
    SSRT.nightbladeWindow:SetMouseEnabled(nightbladeActive)
    SSRT.nightbladeWindow:SetMovable(nightbladeActive)
    SSRT.warriorWindow:SetMouseEnabled(warriorActive)
    SSRT.warriorWindow:SetMovable(warriorActive)
    SSRT.wardenWindow:SetMouseEnabled(wardenActive)
    SSRT.wardenWindow:SetMovable(wardenActive)
    SSRT.backlashWindow:SetMouseEnabled(backlashActive)
    SSRT.backlashWindow:SetMovable(backlashActive)
    SSRT.maelstromWindow:SetMouseEnabled(maelstromActive)
    SSRT.maelstromWindow:SetMovable(maelstromActive)
    SSRT.ultimateWindow:SetMouseEnabled(ultimateActive)
    SSRT.ultimateWindow:SetMovable(ultimateActive)
    if SSRT.guardOutlineWindow then
        local guardMoving = target == "guardIndicator"
        SSRT.guardOutlineWindow:SetMouseEnabled(guardMoving)
        SSRT.guardOutlineWindow:SetMovable(guardMoving)
    end
    -- Move each target-debuff group through its main/major icon.
    for key, obj in pairs(SSRT.debuffWindows or {}) do
        local owner = key == "taunt" and "debuffTaunt"
            or (key:find("breach") and "debuffBreach" or "debuffVulnerability")
        local primary = key == "taunt" or key:find("Major") ~= nil
        local moving = target == owner and primary
        obj.window:SetMouseEnabled(moving)
        obj.window:SetMovable(moving)
        if obj.dragBackdrop then obj.dragBackdrop:SetHidden(not moving) end
    end

    SSRT.crystalDragBackdrop:SetHidden(not crystalActive)
    SSRT.boundDragBackdrop:SetHidden(not boundActive)
    SSRT.beamDragBackdrop:SetHidden(not beamActive)
    SSRT.cruxDragBackdrop:SetHidden(not cruxActive)
    SSRT.nightbladeDragBackdrop:SetHidden(not nightbladeActive)
    SSRT.warriorDragBackdrop:SetHidden(not warriorActive)
    SSRT.wardenDragBackdrop:SetHidden(not wardenActive)
    SSRT.backlashDragBackdrop:SetHidden(not backlashActive)
    SSRT.maelstromDragBackdrop:SetHidden(not maelstromActive)
    SSRT.ultimateDragBackdrop:SetHidden(not ultimateActive)

    if target == "guardIndicator" and SSRT.guardOutlineWindow then
        SSRT.guardOutlineTexture:SetColor(0.22, 0.95, 0.48, 0.95)
        SSRT.guardOutlineWindow:SetHidden(false)
        Chat("Guard outline move mode ON")
    elseif target == "debuffTaunt" or target == "debuffBreach" or target == "debuffVulnerability" then
        Chat("Target tracker move mode ON")
    elseif ultimateActive then
        SSRT.Ultimate.Preview()
        Chat("Ultimate move mode ON")
    elseif target == "templarRune" then
        SSRT.templarRuneWindow:SetHidden(false)
        SSRT.templarRuneLabel:SetText("")
        Chat("Templar Rune support move mode ON")
    elseif target == "gladiator" then
        SSRT.gladiatorWindow:SetHidden(false)
        SSRT.gladiatorLabel:SetText("8")
        SSRT.gladiatorLabel:SetColor(1, 1, 1, 1)
        Chat("Gladiator's Tenacity move mode ON")
    elseif target == "shield" then
        SSRT.Shield.Preview()
        Chat("Damage shield move mode ON")
    elseif target == "tankResolve" then
        SSRT.tankResolveWindow:SetHidden(false)
        SSRT.tankResolveLabel:SetText("12")
        Chat("Major Resolve move mode ON")
    elseif target == "slayer" or target == "berserk" or target == "brutality" or target == "savagery" or target == "force" then
        SSRT[target .. "Window"]:SetHidden(false)
        Chat("Move mode ON: " .. target .. " (Major and Minor together)")
    elseif target == "heroism" or target == "protection" or target == "mending" or target == "evasion" then
        SSRT[target .. "Window"]:SetHidden(false)
        Chat("Move mode ON: " .. target .. " (Major and Minor together)")
    elseif target == "vitality" then
        SSRT.vitalityWindow:SetHidden(false)
        SSRT.vitalityLabel:SetText("12")
        SSRT.vitalityLabel:SetColor(1, 1, 1, 1)
        Chat("Vitality move mode ON")
    elseif target == "wardenFly" then
        SSRT.wardenFlyWindow:SetHidden(false)
        SSRT.wardenFlyLabel:SetText("")
        Chat("Warden empowered fly move mode ON")
    elseif target == "templarBeam" then
        SSRT.templarBeamWindow:SetHidden(false)
        SSRT.templarBeamLabel:SetText("3.8")
        Chat("Templar beam move mode ON")
    elseif target == "necroSkull" then
        SSRT.necroSkullWindow:SetHidden(false)
        SSRT.necroSkullLabel:SetText("3")
        Chat("Necromancer Skull move mode ON")
    elseif target == "necroCorpse" then
        SSRT.necroCorpseWindow:SetHidden(false)
        SSRT.necroCorpseLabel:SetText("")
    SSRT.necroSkullLabel:SetText("")
        Chat("Necromancer corpse move mode ON")
    elseif target == "dkWhip" or target == "dkBreath" or target == "dkCore" then
        SSRT[target .. "Window"]:SetHidden(false)
        SSRT[target .. "Label"]:SetText(target == "dkWhip" and "3" or (target == "dkCore" and "4" or "4.8"))
        Chat("Dragonknight move mode ON: " .. target)
    elseif crystalActive then
        SSRT.crystalWindow:SetHidden(false)
        SSRT.crystalTimer:SetText("6")
        Chat("Crystal move mode ON")
    elseif boundActive then
        SSRT.boundWindow:SetHidden(false)
        SSRT.boundStack:SetText("5")
        SetBoundStackColor(5)
        Chat("Bound move mode ON")
    elseif beamActive then
        SSRT.beamWindow:SetHidden(false)
        SSRT.beamTimer:SetText("4.5")
        Chat("Beam move mode ON")
    elseif cruxActive then
        SSRT.cruxWindow:SetHidden(false)
        SSRT.cruxStack:SetText("3")
        SetCruxStackColor(3)
        Chat("Crux move mode ON")
    elseif nightbladeActive then
        SSRT.nightbladeWindow:SetHidden(false)
        SSRT.nightbladeStack:SetText("4")
        SetNightbladeStackColor(4, 5)
        Chat("Nightblade move mode ON")
    elseif warriorActive then
        SSRT.warriorWindow:SetHidden(false)
        SSRT.warriorTimer:SetText("5")
        Chat("Warrior's Opportunity move mode ON")
    elseif wardenActive then
        SSRT.wardenWindow:SetHidden(false)
        SSRT.wardenTimer:SetText("1:3.0")
        Chat("Warden Shalk move mode ON")
    elseif backlashActive then
        SSRT.backlashWindow:SetHidden(false)
        SSRT.backlashTimer:SetText("6")
        Chat("Backlash move mode ON")
    elseif maelstromActive then
        local tex = GetArmoryIconTexture(MAELSTROM_ARMORY_ICONS[SSRT.maelstromKind] or 52)
        SSRT.maelstromGlowOuter:SetTexture(tex)
        SSRT.maelstromGlowMid:SetTexture(tex)
        SSRT.maelstromIcon:SetTexture(tex)
        SSRT.maelstromWindow:SetHidden(false)
        SSRT.maelstromTimer:SetText("5")
        SSRT.maelstromTimer:SetColor(1.00, 0.80, 0.12, 1.00)
        Chat("Maelstrom timer move mode ON")
    else
        Chat("Move mode OFF")
    end
end

local function ResetPositions()
    for _, group in ipairs({"Taunt", "Breach", "Vulnerability"}) do
        SSRT.sv["debuff" .. group .. "OffsetX"] = defaults["debuff" .. group .. "OffsetX"]
        SSRT.sv["debuff" .. group .. "OffsetY"] = defaults["debuff" .. group .. "OffsetY"]
    end
    SSRT.sv.crystalOffsetX = defaults.crystalOffsetX
    SSRT.sv.crystalOffsetY = defaults.crystalOffsetY
    SSRT.sv.boundOffsetX = defaults.boundOffsetX
    SSRT.sv.boundOffsetY = defaults.boundOffsetY
    SSRT.sv.beamOffsetX = defaults.beamOffsetX
    SSRT.sv.beamOffsetY = defaults.beamOffsetY
    SSRT.sv.cruxOffsetX = defaults.cruxOffsetX
    SSRT.sv.cruxOffsetY = defaults.cruxOffsetY
    SSRT.sv.nightbladeOffsetX = defaults.nightbladeOffsetX
    SSRT.sv.nightbladeOffsetY = defaults.nightbladeOffsetY
    SSRT.sv.warriorOffsetX = defaults.warriorOffsetX
    SSRT.sv.warriorOffsetY = defaults.warriorOffsetY
    SSRT.sv.templarBeamOffsetX = defaults.templarBeamOffsetX
    SSRT.sv.templarBeamOffsetY = defaults.templarBeamOffsetY
    SSRT.sv.backlashOffsetX = defaults.backlashOffsetX
    SSRT.sv.backlashOffsetY = defaults.backlashOffsetY
    SSRT.sv.wardenOffsetX = defaults.wardenOffsetX
    SSRT.sv.wardenOffsetY = defaults.wardenOffsetY
    SSRT.sv.maelstromOffsetX = defaults.maelstromOffsetX
    SSRT.sv.maelstromOffsetY = defaults.maelstromOffsetY
    SSRT.sv.ultimateOffsetX = defaults.ultimateOffsetX
    SSRT.sv.ultimateOffsetY = defaults.ultimateOffsetY
    for _, key in ipairs({"dkWhip", "dkBreath", "dkCore", "necroSkull", "necroCorpse", "templarBeam", "wardenFly", "tankResolve", "shield", "vitality", "heroism", "protection", "mending", "slayer", "berserk", "brutality", "savagery", "force", "evasion", "gladiator", "templarRune"}) do
        SSRT.sv[key .. "OffsetX"] = defaults[key .. "OffsetX"]
        SSRT.sv[key .. "OffsetY"] = defaults[key .. "OffsetY"]
    end

    ApplyCrystalPosition()
    ApplyBoundPosition()
    ApplyBeamPosition()
    ApplyCruxPosition()
    ApplyNightbladePosition()
    ApplyWarriorPosition()
    ApplyMaelstromPosition()
    ApplyBacklashPosition()
    ApplyWardenPosition()
    for _, key in ipairs({"dkWhip", "dkBreath", "dkCore", "necroSkull", "necroCorpse", "templarBeam", "wardenFly", "tankResolve", "shield", "vitality", "heroism", "protection", "mending", "slayer", "berserk", "brutality", "savagery", "force", "evasion", "gladiator", "templarRune"}) do
        local window = SSRT[key .. "Window"]
        if window then
            window:ClearAnchors()
            window:SetAnchor(CENTER, GuiRoot, CENTER, SSRT.sv[key .. "OffsetX"], SSRT.sv[key .. "OffsetY"])
        end
    end
    SSRT.sv.guardOffsetX = defaults.guardOffsetX
    SSRT.sv.guardOffsetY = defaults.guardOffsetY
    if SSRT.guardOutlineWindow then
        SSRT.guardOutlineWindow:ClearAnchors()
        SSRT.guardOutlineWindow:SetAnchor(CENTER, GuiRoot, CENTER, SSRT.sv.guardOffsetX, SSRT.sv.guardOffsetY)
    end
    ApplyUltimatePosition()
end

local function CreateUltimateWindow()
    return SSRT.Ultimate.CreateWindow()
end

local function CreateCrystalWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTCrystalWindow")
    SSRT.crystalWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.02, 0.12, 0.16, 0.22)
    dragBackdrop:SetEdgeColor(0.20, 0.80, 1.00, 0.75)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.crystalDragBackdrop = dragBackdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(0.08, 0.75, 1.00, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.crystalGlowOuter = outerGlow

    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(0.18, 0.90, 1.00, 0.42)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.crystalGlowMid = midGlow

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(0.30, 0.70, 1.00, 1.00)
    SSRT.crystalIcon = icon

    local timer = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.crystalTimer = timer

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("crystal")
    end)

    SSRT.crystalFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.crystalFragment)
    HUD_UI_SCENE:AddFragment(SSRT.crystalFragment)
end

local function CreateBoundWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTBoundWindow")
    SSRT.boundWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.12, 0.04, 0.18, 0.20)
    dragBackdrop:SetEdgeColor(0.72, 0.36, 1.00, 0.80)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.boundDragBackdrop = dragBackdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(0.45, 0.08, 1.00, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.boundGlowOuter = outerGlow

    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(0.68, 0.28, 1.00, 0.45)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.boundGlowMid = midGlow

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(0.30, 0.70, 1.00, 1.00)
    SSRT.boundIcon = icon

    local stack = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    stack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stack:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    stack:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.boundStack = stack

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("bound")
    end)

    SSRT.boundFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.boundFragment)
    HUD_UI_SCENE:AddFragment(SSRT.boundFragment)
end



local function CreateBeamWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTBeamWindow")
    SSRT.beamWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.06, 0.12, 0.02, 0.22)
    dragBackdrop:SetEdgeColor(0.48, 1.00, 0.18, 0.80)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.beamDragBackdrop = dragBackdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(0.34, 1.00, 0.08, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.beamGlowOuter = outerGlow

    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(0.56, 1.00, 0.16, 0.46)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.beamGlowMid = midGlow

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(0.35, 1.00, 0.40, 1.00)
    SSRT.beamIcon = icon

    local timer = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.beamTimer = timer

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("beam")
    end)

    SSRT.beamFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.beamFragment)
    HUD_UI_SCENE:AddFragment(SSRT.beamFragment)
end

local function CreateCruxWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTCruxWindow")
    SSRT.cruxWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.06, 0.12, 0.02, 0.22)
    dragBackdrop:SetEdgeColor(0.48, 1.00, 0.18, 0.80)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.cruxDragBackdrop = dragBackdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(0.34, 1.00, 0.08, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.cruxGlowOuter = outerGlow

    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(0.56, 1.00, 0.16, 0.46)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.cruxGlowMid = midGlow

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(0.35, 1.00, 0.40, 1.00)
    SSRT.cruxIcon = icon

    local stack = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    stack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stack:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    stack:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.cruxStack = stack

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("crux")
    end)

    SSRT.cruxFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.cruxFragment)
    HUD_UI_SCENE:AddFragment(SSRT.cruxFragment)
end


local function CreateNightbladeWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTNightbladeWindow")
    SSRT.nightbladeWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.14, 0.02, 0.08, 0.22)
    dragBackdrop:SetEdgeColor(1.00, 0.24, 0.52, 0.82)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.nightbladeDragBackdrop = dragBackdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(1.00, 0.08, 0.38, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.nightbladeGlowOuter = outerGlow

    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(1.00, 0.24, 0.54, 0.45)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.nightbladeGlowMid = midGlow

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(1.00, 0.24, 0.25, 1.00)
    SSRT.nightbladeIcon = icon

    local stack = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    stack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stack:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    stack:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.nightbladeStack = stack

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("nightblade")
    end)

    SSRT.nightbladeFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.nightbladeFragment)
    HUD_UI_SCENE:AddFragment(SSRT.nightbladeFragment)
end

local function CreateBacklashWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTBacklashWindow")
    SSRT.backlashWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.15, 0.12, 0.01, 0.25)
    backdrop:SetEdgeColor(1, 0.85, 0.20, 0.85)
    backdrop:SetHidden(true)
    SSRT.backlashDragBackdrop = backdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(0.95, 0.70, 0.07, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.backlashGlowOuter = outerGlow
    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(1.0, 0.79, 0.18, 0.45)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.backlashGlowMid = midGlow
    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(1.00, 0.90, 0.18, 1.00)
    SSRT.backlashIcon = icon
    local timer = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.0, 1.0, 1.0, 1.0)
    SSRT.backlashTimer = timer
    window:SetHandler("OnMoveStop", function() SaveControlOffset("backlash") end)
    local fragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function CreateWardenWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTWardenWindow")
    SSRT.wardenWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.15, 0.12, 0.01, 0.25)
    backdrop:SetEdgeColor(1, 0.85, 0.20, 0.85)
    backdrop:SetHidden(true)
    SSRT.wardenDragBackdrop = backdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(0.22, 0.70, 0.38, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.wardenGlowOuter = outerGlow
    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(0.33, 0.85, 0.45, 0.45)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.wardenGlowMid = midGlow
    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(0.28, 0.92, 0.40, 1.00)
    SSRT.wardenIcon = icon
    local timer = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.0, 1.0, 1.0, 1.0)
    SSRT.wardenTimer = timer
    window:SetHandler("OnMoveStop", function() SaveControlOffset("warden") end)
    local fragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

ApplyDefensePairLayout = function(key)
    local grp = SSRT.defensePairs and SSRT.defensePairs[key]
    if not grp then return end
    local majorTop = SSRT.sv[key .. "MajorOnTop"] ~= false
    local majorY, minorY = majorTop and -25 or 25, majorTop and 25 or -25
    local minorSize = SSRT.sv[key .. "MinorIconSize"] or 36
    for _, art in ipairs({SSRT[key .. "GlowOuter"], SSRT[key .. "GlowMid"], SSRT[key .. "Icon"], SSRT[key .. "Label"]}) do
        art:ClearAnchors()
        art:SetAnchor(CENTER, grp.window, CENTER, 0, majorY)
    end
    for _, art in ipairs({grp.icon, grp.label}) do
        art:ClearAnchors()
        art:SetAnchor(CENTER, grp.window, CENTER, 0, minorY)
    end
    grp.icon:SetDimensions(minorSize, minorSize)
    grp.label:SetDimensions(minorSize + 22, minorSize + 22)
    grp.label:SetFont(BuildFont(SSRT.sv[key .. "MinorTextSize"] or 21))
    grp.icon:SetTexture(GetArmoryIconTexture(SSRT.sv[key .. "IconIndex"] or 9))
    local c = DEFENSE_COLORS[key]
    if c then grp.icon:SetColor(c[1], c[2], c[3], 0.93) end
end

local function CreateDKWindow(key, title, red, green, blue)
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTDK" .. title)
    SSRT[key .. "Window"] = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHidden(true)
    local backdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.3, 0.1, 0.01, 0.25)
    backdrop:SetEdgeColor(1, 0.4, 0.15, 0.8)
    backdrop:SetHidden(true)
    SSRT[key .. "DragBackdrop"] = backdrop
    local glow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    glow:SetAnchor(CENTER, window, CENTER, 0, 0)
    glow:SetColor(1.00, 0.12, 0.10, 0.45)
    glow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT[key .. "GlowMid"] = glow
    local outer = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outer:SetAnchor(CENTER, window, CENTER, 0, 0)
    outer:SetColor(1.00, 0.07, 0.06, 0.22)
    outer:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT[key .. "GlowOuter"] = outer
    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(1, 0.82, 0.79, 1)
    -- Keep class color on the icon artwork, rather than making the halo the main color.
    if key == "dkWhip" or key == "dkBreath" or key == "dkCore" then
        icon:SetColor(1.00, 0.48, 0.12, 1.00)  -- Dragonknight orange
        glow:SetColor(1.00, 0.38, 0.08, 0.45)
        outer:SetColor(1.00, 0.30, 0.05, 0.20)
    elseif key == "gladiator" then
        -- Muted burnt orange, not generic DPS-bright yellow.
        icon:SetColor(0.98, 0.60, 0.24, 1.00)
        glow:SetColor(0.95, 0.43, 0.11, 0.45)
        outer:SetColor(0.72, 0.30, 0.07, 0.20)
    elseif key == "shield" then
        -- Same cyan as before, one brighter step toward white.
        icon:SetColor(0.68, 0.94, 1.00, 1)
        glow:SetColor(0.51, 0.89, 1.00, 0.43)
        outer:SetColor(0.38, 0.79, 1.00, 0.18)
    elseif DEFENSE_COLORS[key] then
        -- Unique colors for shared buffs, not class color.  Resolve trial = green.
        local c = DEFENSE_COLORS[key]
        icon:SetColor(c[1], c[2], c[3], 1)
        glow:SetColor(c[1], c[2], c[3], 0.43)
        outer:SetColor(c[1], c[2], c[3], 0.18)
    elseif key == "wardenFly" then
        icon:SetColor(0.28, 0.92, 0.40, 1.00)
        glow:SetColor(0.33, 0.85, 0.45, 0.45)
        outer:SetColor(0.22, 0.70, 0.38, 0.20)
    elseif key == "templarRune" or key == "templarBeam" then
        icon:SetColor(1.00, 0.90, 0.18, 1.00)
        glow:SetColor(1.00, 0.79, 0.18, 0.45)
        outer:SetColor(0.95, 0.70, 0.07, 0.20)
    elseif key == "necroCorpse" or key == "necroSkull" then
        icon:SetColor(0.91, 0.67, 1.00, 1.00)  -- Brighter Necromancer lavender
        glow:SetColor(0.80, 0.42, 1.00, 0.45)
        outer:SetColor(0.65, 0.24, 1.00, 0.20)
    end
    SSRT[key .. "Icon"] = icon
    local label = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 1, 1, 1)
    SSRT[key .. "Label"] = label
    if DEFENSE_GROUPS[key] then
        local minorIcon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
        local minorLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
        minorLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        minorLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        minorLabel:SetColor(1, 1, 1, 1)
        SSRT.defensePairs = SSRT.defensePairs or {}
        SSRT.defensePairs[key] = { window = window, icon = minorIcon, label = minorLabel }
        ApplyDefensePairLayout(key)
    end
    window:SetHandler("OnMoveStop", function() SaveControlOffset(key) end)
    local fragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function ApplyDKPositions()
    for _, key in ipairs({"dkWhip", "dkBreath", "dkCore", "necroCorpse", "necroSkull", "templarBeam", "wardenFly", "tankResolve", "shield", "templarRune", "vitality", "heroism", "protection", "mending", "slayer", "berserk", "brutality", "savagery", "force", "evasion", "gladiator"}) do
        local window = SSRT[key .. "Window"]
        window:ClearAnchors()
        window:SetAnchor(CENTER, GuiRoot, CENTER, SSRT.sv[key .. "OffsetX"], SSRT.sv[key .. "OffsetY"])
    end
end

local function CreateArmoryIconFinder()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTArmoryIconFinder")
    SSRT.iconFinder = window
    window:SetDimensions(820, 470)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(50)
    window:SetMouseEnabled(false)
    window:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.015, 0.015, 0.025, 0.94)
    backdrop:SetEdgeColor(0.30, 1.00, 0.72, 0.90)
    backdrop:SetEdgeTexture("", 1, 1, 1, 1)

    local title = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    title:SetDimensions(780, 28)
    title:SetAnchor(TOP, window, TOP, 0, 10)
    title:SetFont("$(BOLD_FONT)|20|thick-outline")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("Armory Build Icons 1-78")

    local cols = 13
    local cellW = 60
    local cellH = 68
    local iconSize = 42
    local startX = 22
    local startY = 48

    for index = 1, 78 do
        local zero = index - 1
        local col = zero % cols
        local row = zo_floor(zero / cols)
        local cx = startX + col * cellW
        local cy = startY + row * cellH

        local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
        icon:SetDimensions(iconSize, iconSize)
        icon:SetAnchor(TOPLEFT, window, TOPLEFT, cx, cy)
        icon:SetTexture(string.format(ARMORY_ICON_FORMAT, index))
        icon:SetColor(1, 1, 1, 1)

        local number = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
        number:SetDimensions(iconSize, 18)
        number:SetAnchor(TOP, icon, BOTTOM, 0, 1)
        number:SetFont("$(BOLD_FONT)|13|thick-outline")
        number:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        number:SetText(tostring(index))
    end

    local note = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    note:SetDimensions(780, 22)
    note:SetAnchor(BOTTOM, window, BOTTOM, 0, -8)
    note:SetFont("$(MEDIUM_FONT)|14|soft-shadow-thin")
    note:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    note:SetText("/srt icons to close")
end

local function ToggleArmoryIconFinder()
    SSRT.iconFinder:SetHidden(not SSRT.iconFinder:IsHidden())
end

local function CreateWarriorWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTWarriorWindow")
    SSRT.warriorWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.14, 0.07, 0.01, 0.22)
    dragBackdrop:SetEdgeColor(1.00, 0.62, 0.12, 0.82)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.warriorDragBackdrop = dragBackdrop

    local outerGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outerGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    outerGlow:SetColor(1.00, 0.42, 0.04, 0.20)
    outerGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.warriorGlowOuter = outerGlow

    local midGlow = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    midGlow:SetAnchor(CENTER, window, CENTER, 0, 0)
    midGlow:SetColor(1.00, 0.62, 0.12, 0.45)
    midGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.warriorGlowMid = midGlow

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(1.00, 0.82, 0.42, 1.00)
    SSRT.warriorIcon = icon

    local timer = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.warriorTimer = timer

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("warrior")
    end)

    SSRT.warriorFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.warriorFragment)
    HUD_UI_SCENE:AddFragment(SSRT.warriorFragment)
end

local function CreateMaelstromWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SRTMaelstromWindow")
    SSRT.maelstromWindow = window
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawLevel(10)
    window:SetMouseEnabled(false)
    window:SetMovable(false)

    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(window)
    dragBackdrop:SetCenterColor(0.10, 0.08, 0.02, 0.22)
    dragBackdrop:SetEdgeColor(1.00, 0.74, 0.20, 0.78)
    dragBackdrop:SetEdgeTexture("", 1, 1, 1, 1)
    dragBackdrop:SetHidden(true)
    SSRT.maelstromDragBackdrop = dragBackdrop

    local outer = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    outer:SetAnchor(CENTER, window, CENTER, 0, 0)
    outer:SetColor(1.0, 1.0, 1.0, 0.20)
    outer:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.maelstromGlowOuter = outer

    local mid = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    mid:SetAnchor(CENTER, window, CENTER, 0, 0)
    mid:SetColor(1.0, 1.0, 1.0, 0.45)
    mid:SetBlendMode(TEX_BLEND_MODE_ADD)
    SSRT.maelstromGlowMid = mid

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetAnchor(CENTER, window, CENTER, 0, 0)
    icon:SetColor(0.82, 0.82, 0.82, 1.0)
    SSRT.maelstromIcon = icon

    local timer = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    timer:SetAnchor(CENTER, window, CENTER, 0, 0)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.00, 1.00, 1.00, 1.00)
    SSRT.maelstromTimer = timer

    window:SetHandler("OnMoveStop", function()
        SaveControlOffset("maelstrom")
    end)

    SSRT.maelstromFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(SSRT.maelstromFragment)
    HUD_UI_SCENE:AddFragment(SSRT.maelstromFragment)
end

-- Crystal Weapon has no useful buff stack count; the game reports stacks=0.
-- Count only observed Crystal Weapon bonus damage packets. Do not count generic
-- light attacks, enchantments, concussion, or other proc effects.
local crystalWeaponLastProcAt = -100
local function ScanCrystalWeaponBuff()
    local now = GetFrameTimeSeconds()
    local endTime = 0
    for i = 1, GetNumBuffs("player") do
        local _, _, finish, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if id == CRYSTAL_WEAPON_BUFF_ID then
            endTime = finish or 0
            break
        end
    end
    if endTime > now then
        -- Re-login/reload with an active buff: unknown spent charges, don't fabricate 3.
        if not SSRT.crystalWeaponEnd or SSRT.crystalWeaponEnd <= 0 then
            SSRT.crystalWeaponCharges = 0
        end
        SSRT.crystalWeaponEnd = endTime
    else
        SSRT.crystalWeaponEnd = 0
        SSRT.crystalWeaponCharges = 0
    end
end

local function OnCrystalWeaponEffect(_, changeType, _, _, unitTag, _, endTime)
    if unitTag ~= "player" then return end
    if changeType == EFFECT_RESULT_FADED then
        SSRT.crystalWeaponCharges = 0
        SSRT.crystalWeaponEnd = 0
    else
        local currentEnd = SSRT.crystalWeaponEnd or 0
        if changeType == EFFECT_RESULT_GAINED or currentEnd <= GetFrameTimeSeconds() then
            SSRT.crystalWeaponCharges = 3
            crystalWeaponLastProcAt = -100
        end
        SSRT.crystalWeaponEnd = endTime or 0
    end
end

local function OnCrystalWeaponBonusDamage(_, result, _, _, _, _, _, sourceType,
                                          _, _, _, _, _, _, _, _, abilityId)
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if result ~= ACTION_RESULT_DAMAGE and result ~= ACTION_RESULT_CRITICAL_DAMAGE then return end
    if not CRYSTAL_WEAPON_BONUS_DAMAGE_IDS[abilityId] then return end
    local now = GetFrameTimeSeconds()
    if (SSRT.crystalWeaponEnd or 0) <= now or (SSRT.crystalWeaponCharges or 0) <= 0 then return end
    -- Safety against multiple bonus packets from a single swing (tentative).
    if now - crystalWeaponLastProcAt < 0.18 then return end
    crystalWeaponLastProcAt = now
    SSRT.crystalWeaponCharges = math.max(0, SSRT.crystalWeaponCharges - 1)
end

local function ScanCrystalProc()
    local now = GetFrameTimeSeconds()
    local active = false
    local endTime = 0

    for buffIndex = 1, GetNumBuffs("player") do
        local _, _, buffEndTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        if abilityId == CRYSTAL_FRAGMENTS_PROC_EFFECT_ID then
            active = true
            endTime = buffEndTime or 0
            break
        end
    end

    SSRT.crystalActive = active and endTime > now
    SSRT.crystalEndTime = SSRT.crystalActive and endTime or 0
end

local function IsBoundArmamentsSlot(slotIndex, hotbarCategory)
    local abilityId = GetSlotBoundId(slotIndex, hotbarCategory)
    if not abilityId or abilityId == 0 then
        return false
    end

    if abilityId == BOUND_ARMAMENTS_ABILITY_ID then
        return true
    end

    return GetEffectiveAbilityIdForAbilityOnHotbar(abilityId, hotbarCategory) == BOUND_ARMAMENTS_ABILITY_ID
end

local function ScanBoundBuffStacks()
    for buffIndex = 1, GetNumBuffs("player") do
        local _, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        if abilityId == BOUND_ARMAMENTS_STACK_EFFECT_ID then
            return math.max(0, stackCount or 0)
        end
    end
    return 0
end

local function ScanBoundStacks()
    local best = 0
    local categories = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }

    for _, hotbarCategory in ipairs(categories) do
        for slotIndex = SLOT_FIRST, SLOT_LAST do
            if IsBoundArmamentsSlot(slotIndex, hotbarCategory) then
                local stacks = GetActionSlotEffectStackCount(slotIndex, hotbarCategory) or 0
                if stacks > best then
                    best = stacks
                end
            end
        end
    end

    if best <= 0 then
        best = ScanBoundBuffStacks()
    end

    SSRT.boundStacks = math.max(0, best)
end


local function ScanCrux()
    for buffIndex = 1, GetNumBuffs("player") do
        local _, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        if abilityId == CRUX_ABILITY_ID then
            SSRT.cruxStacks = math.max(0, stackCount or 0)
            return
        end
    end
    SSRT.cruxStacks = 0
end

local function OnCruxEffectChanged(_, changeType, _, _, _, _, _, stackCount)
    if changeType == EFFECT_RESULT_FADED then
        SSRT.cruxStacks = 0
    else
        SSRT.cruxStacks = math.max(0, stackCount or 0)
    end
end

local function ScanNightbladeStacks()
    local bestStacks = 0
    local readyAt = 5

    for buffIndex = 1, GetNumBuffs("player") do
        local _, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        local threshold = NIGHTBLADE_STACK_EFFECTS[abilityId]
        if threshold then
            local stacks = math.max(0, stackCount or 0)
            if stacks > bestStacks then
                bestStacks = stacks
                readyAt = threshold
            end
        end
    end

    SSRT.nightbladeStacks = bestStacks
    SSRT.nightbladeReadyAt = readyAt
end

local function OnNightbladeEffectChanged(_, changeType, _, _, _, _, _, stackCount, _, _, _, _, _, _, _, abilityId)
    local readyAt = NIGHTBLADE_STACK_EFFECTS[abilityId]
    if not readyAt then return end

    if changeType == EFFECT_RESULT_FADED then
        SSRT.nightbladeStacks = 0
        SSRT.nightbladeReadyAt = readyAt
    else
        SSRT.nightbladeStacks = math.max(0, stackCount or 0)
        SSRT.nightbladeReadyAt = readyAt
    end
end

local function IsWarriorsOpportunityTravelingKnife(slotIndex, hotbarCategory)
    if GetSlotType(slotIndex, hotbarCategory) ~= ACTION_TYPE_CRAFTED_ABILITY then
        return false
    end

    local craftedAbilityId = GetSlotBoundId(slotIndex, hotbarCategory) or 0
    if craftedAbilityId ~= TRAVELING_KNIFE_CRAFTED_ID then
        return false
    end

    local _, signatureScriptId = GetCraftedAbilityActiveScriptIds(craftedAbilityId)
    if not signatureScriptId or signatureScriptId == 0 then
        return false
    end

    local icon = zo_strlower(GetCraftedAbilityScriptIcon(signatureScriptId) or "")
    return icon:find(WARRIORS_OPPORTUNITY_SCRIPT_ICON_TOKEN, 1, true) ~= nil
end

local function DetectWardenShalk(slot, hotbarCategory)
    local texture = zo_strlower(GetSlotTexture(slot, hotbarCategory) or "")
    local bound = GetSlotBoundId(slot, hotbarCategory) or 0
    local effective = bound ~= 0 and (GetEffectiveAbilityIdForAbilityOnHotbar(bound, hotbarCategory) or 0) or 0
    -- Sora-confirmed in-game bound/effective ability IDs (base and both morphs).
    -- No localized skill-name or icon-texture matching.
    local shalkId = (bound == 86009 or bound == 86015 or bound == 86019) and bound
        or ((effective == 86009 or effective == 86015 or effective == 86019) and effective or nil)
    if not shalkId then return nil end
    -- Second hit at 6s for Subterranean Assault, 9s for Scorch/Deep Fissure.
    if shalkId == 86019 then return 6 end
    return 9
end

local function InspectDKCast(slot, hotbarCategory)
    local texture = zo_strlower(GetSlotTexture(slot, hotbarCategory) or "")
    local bound = GetSlotBoundId(slot, hotbarCategory) or 0
    local effective = bound ~= 0 and (GetEffectiveAbilityIdForAbilityOnHotbar(bound, hotbarCategory) or 0) or 0
    local name = zo_strlower(zo_strformat("<<1>>", GetSlotName(slot, hotbarCategory) or ""))
    if not SSRT.sv.dkEnabled then return end
    -- Confirmed in-game by Sora: Consuming Dragonfire has bound/effective ID 20930.
    -- Use the actual ability ID rather than a localized name guess.
    if SSRT.sv.dkBreathEnabled and (bound == 20930 or effective == 20930) then
        SSRT.dkBreathEnd = GetFrameTimeSeconds() + DK_CHANNEL_SECONDS
    end
end

-- Core of Flame / Heart of Flame / Soul of Flame, including JA names.
-- ESO's four-second channel begins about 0.35s after use (Update 49).
-- Do not guess ability IDs. This comparison uses the actual slotted skill name
-- returned by the client; once IDs are observed in game, IDs can replace names.
local DK_CORE_NAMES = {
    ["core of flame"] = true, ["heart of flame"] = true, ["soul of flame"] = true,
    ["炎のコア"] = true, ["炎の心臓"] = true, ["炎の魂"] = true,
}
local function OnDKCoreUsed(_, slot)
    if not SSRT.sv.dkCoreEnabled then return end
    local category = GetActiveHotbarCategory()
    local rawName = GetSlotName(slot, category) or ""
    local name = zo_strlower(zo_strformat("<<1>>", rawName))
    if DK_CORE_NAMES[name] then
        SSRT.dkCoreEnd = GetFrameTimeSeconds() + 4.35
    end
end

-- Empowered Screaming Cliff Racer availability: own buff only, no timer.
-- Confirmed by Sora's Srendarr display; test the gain/removal with game events.
local WARDEN_FLY_READY_BUFF_ID = SSRT.ClassSkills.WardenFlyBuffId
local function ScanWardenFlyReady()
    return SSRT.ClassSkills.ScanWardenFlyReady()
end
local function OnWardenFlyEffect(...)
    return SSRT.ClassSkills.OnWardenFlyEffect(...)
end

local function OnDKEffectChanged(_, changeType, _, effectName, unitTag, _, endTime, stackCount, _, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" then return end
    local name = zo_strlower(zo_strformat("<<1>>", effectName or ""))
    if not SSRT.sv.dkWhipEnabled then return end
    -- Effect ID is language-independent; do not match localized buff names.
    if abilityId ~= DK_WHIP_STACK_EFFECT_ID then return end
    if changeType == EFFECT_RESULT_FADED then
        SSRT.dkWhipStacks = 0
        SSRT.dkWhipEffectEnd = 0
    else
        SSRT.dkWhipStacks = math.max(0, stackCount or 0)
        SSRT.dkWhipEffectEnd = endTime or 0
    end
end

-- Slot-use only arms the next channel-start event; it never displays a timer.
local templarBeamPendingUntil = 0
local templarBeamPendingBar = nil
local function ClearTemplarBeam()
    SSRT.templarBeamEnd = 0
    templarBeamPendingUntil = 0
    templarBeamPendingBar = nil
end

local function OnActionSlotAbilityUsed(_, actionSlotIndex)
    if actionSlotIndex < SLOT_FIRST or actionSlotIndex > SLOT_LAST then
        return
    end

    local hotbarCategory = GetActiveHotbarCategory()
    if SSRT.sv.templarBeamEnabled then
        local bound = GetSlotBoundId(actionSlotIndex, hotbarCategory) or 0
        local effective = bound ~= 0 and (GetEffectiveAbilityIdForAbilityOnHotbar(bound, hotbarCategory) or 0) or 0
        if TEMPLAR_EXECUTE_IDS[bound] or TEMPLAR_EXECUTE_IDS[effective] then
            local now = GetFrameTimeSeconds()
            -- Slot-use only arms a short window for the genuine channel BEGIN.
            -- No timer is started here, including during repeated slot presses.
            if not IsBlockActive() then
                templarBeamPendingUntil = now + 0.85
                templarBeamPendingBar = hotbarCategory
            end
        end
    end
    if SSRT.sv.backlashEnabled then
        local boundId = GetSlotBoundId(actionSlotIndex, hotbarCategory) or 0
        local effectiveId = boundId ~= 0
            and (GetEffectiveAbilityIdForAbilityOnHotbar(boundId, hotbarCategory) or 0) or 0
        -- The bound hotbar ID is not guaranteed to be the active morph/rank ID.
        -- Compare both, and use the skill's actual icon as a narrow fallback.
        local texture = zo_strlower(GetSlotTexture(actionSlotIndex, hotbarCategory) or "")
        local backlashIcon = texture:find("ability_templar_power_of_the_light", 1, true)
            or texture:find("ability_templar_purifying_light", 1, true)
            or texture:find("ability_templar_backlash", 1, true)
        local slotName = zo_strlower(zo_strformat("<<1>>", GetSlotName(actionSlotIndex, hotbarCategory) or ""))
        local matchedName = false
        if slotName ~= "" then
            -- Match localized names using the game's own ability names, not English strings.
            for knownId in pairs(BACKLASH_CAST_IDS) do
                local knownName = zo_strlower(zo_strformat("<<1>>", GetAbilityName(knownId) or ""))
                if knownName ~= "" and slotName == knownName then
                    matchedName = true
                    break
                end
            end
        end
        if BACKLASH_CAST_IDS[boundId] or BACKLASH_CAST_IDS[effectiveId] or backlashIcon or matchedName then
            SSRT.backlashEndTime = GetFrameTimeSeconds() + BACKLASH_DURATION
        end
    end
    if SSRT.sv.wardenEnabled then
        local duration = DetectWardenShalk(actionSlotIndex, hotbarCategory)
        if duration then
            local now = GetFrameTimeSeconds()
            SSRT.wardenFirstHit = now + 3
            SSRT.wardenSecondHit = now + duration
        end
    end
    InspectDKCast(actionSlotIndex, hotbarCategory)
    if SSRT.sv.warriorEnabled and IsWarriorsOpportunityTravelingKnife(actionSlotIndex, hotbarCategory) then
        SSRT.warriorOpportunityEndTime = GetFrameTimeSeconds() + WARRIORS_OPPORTUNITY_DURATION
    end
end

local function FormatGenericTime(seconds)
    seconds = math.max(0, seconds)
    if seconds < 3 then
        return string.format("%.1f", seconds)
    end
    return tostring(math.ceil(seconds))
end

local function OnBeamCombatEvent(_, result, _, _, _, _, _, _, _, _, hitValue)
    if result == ACTION_RESULT_BEGIN then
        if hitValue and hitValue > 75 then
            SSRT.beamActive = true
            SSRT.beamEndTimeMs = GetFrameTimeMilliseconds() + hitValue
        end
    elseif result == ACTION_RESULT_EFFECT_FADED or result == ACTION_RESULT_INTERRUPT then
        SSRT.beamActive = false
        SSRT.beamEndTimeMs = 0
    end
end

-- Breath shares the beam's combat-event cancellation model.  Skill ID 20930
-- was confirmed in-game by Sora; ability-specific filters avoid localized names.
local function OnDKBreathCombatEvent(_, result)
    if result == ACTION_RESULT_INTERRUPT or result == ACTION_RESULT_EFFECT_FADED then
        SSRT.dkBreathEnd = 0
    end
end

local function RegisterDKBreathEvents()
    local eventName = ADDON_NAME .. "DKBreath20930"
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, OnDKBreathCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID, 20930,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
        REGISTER_FILTER_IS_ERROR, false)
end

local function RegisterBeamEvents()
    for abilityId in pairs(BEAM_IDS) do
        local eventName = ADDON_NAME .. "Beam" .. tostring(abilityId)
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, OnBeamCombatEvent)
        EVENT_MANAGER:AddFilterForEvent(
            eventName,
            EVENT_COMBAT_EVENT,
            REGISTER_FILTER_ABILITY_ID, abilityId,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
            REGISTER_FILTER_IS_ERROR, false
        )
    end
end

local function FormatBeamTime(milliseconds)
    local seconds = math.max(0, milliseconds / 1000)
    if seconds < 3 then
        return string.format("%.1f", seconds)
    end
    return tostring(math.ceil(seconds))
end

local function IsMaelstromTrackingEnabled()
    return SSRT.WeaponSkills.IsTrackingEnabled()
end
local function RefreshMaelstromBinding()
    return SSRT.WeaponSkills.RefreshBinding()
end
local function ReadMaelstromTimer()
    return SSRT.WeaponSkills.ReadTimer()
end

-- Gladiator's Tenacity: player effect from Ulfsild's Contingency,
-- *not* an estimated eight-second countdown started when arming the grimoire.
local function ScanGladiatorTenacity()
    local ending = 0
    local now = GetFrameTimeSeconds()
    for i = 1, GetNumBuffs("player") do
        local _, _, expires, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if abilityId == GLADIATOR_TENACITY_BUFF_ID and expires and expires > now then
            ending = math.max(ending, expires)
        end
    end
    SSRT.gladiatorEnd = ending
end

-- One source-independent reader for Major/Minor defensive buffs.
-- GetUnitBuffInfo's `buffType` string is NOT the ESO BuffType enum.
-- Resolve the numeric buff type from the buff ability ID.
-- Buffs with endTime == 0 have no defined expiry; do not discard them as
-- inactive. Distinguish those from timed buffs so the HUD never fabricates
-- countdown seconds for permanent/passive-like effects.
local function NewDefenseBuffSlots()
    local found = {}
    for _, key in ipairs(DEFENSE_KEYS) do
        found[key] = {major = 0, minor = 0, majorPermanent = false, minorPermanent = false}
    end
    return found
end

-- Source independent ID overrides for effects that are not classified by
-- GetAbilityBuffType. No localized buff or skill names are used in tracking.
-- IDs cross-checked against ESOUI community/library data; live passive IDs
-- (Bound Aegis / Sacred Ground) still need Sora's in-game verification.
local DEFENSE_BUFF_ID_OVERRIDES = {
    [61693] = {"tankResolve", "minor"}, -- Minor Resolve
    [61721] = {"protection", "minor"}, -- Minor Protection
    [61710] = {"mending", "minor"}, -- Minor Mending
}
local function DefenseBuffGrade(key, id, buffType, valid)
    local def = DEFENSE_GROUPS[key]
    -- A known specific buff ID takes precedence over an uncertain type.
    local known = DEFENSE_BUFF_ID_OVERRIDES[id]
    if known and known[1] == key then return known[2] end
    if (valid ~= false and buffType ~= nil and def.major ~= nil and buffType == def.major)
        or (key == "tankResolve" and id == TANK_RESOLVE_EFFECT_ID)
        or (key == "vitality" and id == MAJOR_VITALITY_EFFECT_ID) then
        return "major"
    end
    if valid ~= false and buffType ~= nil and def.minor ~= nil and buffType == def.minor then
        return "minor"
    end
    return nil
end

-- Timeless buffs can be encoded as a zero end time, matching start/end times,
-- or a far-future expiry. Verified first in the Oakensoul checker; these
-- are *timing* heuristics only. Actual defense-buff identity stays ID/type-
-- based, never localized-name based (required for public ESOUI release).
local function IsUntimedDefenseBuff(beginTime, endTime, now)
    beginTime = tonumber(beginTime) or 0
    endTime = tonumber(endTime) or 0
    if endTime == 0 then return true end
    if beginTime > 0 and math.abs(endTime - beginTime) <= 1.0 then return true end
    return endTime - (now or GetFrameTimeSeconds()) > 86400
end

local function ScanDefenseBuffs()
    local found = NewDefenseBuffSlots()
    local now = GetFrameTimeSeconds()
    for i = 1, GetNumBuffs("player") do
        local _, beginTime, finish, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        local untimed = finish ~= nil and IsUntimedDefenseBuff(beginTime, finish, now)
        if id and finish ~= nil and (untimed or finish > now) then
            local buffType, valid = GetAbilityBuffType(id, "player")
            for _, key in ipairs(DEFENSE_KEYS) do
                local grade = DefenseBuffGrade(key, id, buffType, valid)
                if grade then
                    if untimed then
                        found[key][grade .. "Permanent"] = true
                    else
                        found[key][grade] = math.max(found[key][grade], finish)
                    end
                end
            end
        end
    end
    SSRT.defenseBuffEnds = found
end

-- Called only for player effect changes. Update the relevant slot immediately,
-- then settle from the actual player buffs (handles multiple buff sources).
local defenseScanPending = false
local function OnDefenseBuffChanged(_, changeType, _, _, unitTag, beginTime, finish, _, _, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" or not abilityId then return end
    if abilityId == GLADIATOR_TENACITY_BUFF_ID then
        -- Immediate event update, then read the authoritative player buff list
        -- after the client has settled the effect change.
        SSRT.gladiatorEnd = (changeType ~= EFFECT_RESULT_FADED and finish and finish > GetFrameTimeSeconds()) and finish or 0
        zo_callLater(ScanGladiatorTenacity, 70)
    end
    local buffType, valid = GetAbilityBuffType(abilityId, "player")
    local touched = false
    for _, key in ipairs(DEFENSE_KEYS) do
        local grade = DefenseBuffGrade(key, abilityId, buffType, valid)
        if grade then
            SSRT.defenseBuffEnds[key] = SSRT.defenseBuffEnds[key] or
                {major = 0, minor = 0, majorPermanent = false, minorPermanent = false}
            local slot = SSRT.defenseBuffEnds[key]
            if changeType == EFFECT_RESULT_FADED then
                slot[grade] = 0
                slot[grade .. "Permanent"] = false
            elseif finish ~= nil and IsUntimedDefenseBuff(beginTime, finish) then
                slot[grade .. "Permanent"] = true
            elseif finish and finish > GetFrameTimeSeconds() then
                slot[grade] = finish
            end
            touched = true
        end
    end
    if touched and not defenseScanPending then
        defenseScanPending = true
        zo_callLater(function()
            defenseScanPending = false
            ScanDefenseBuffs()
        end, 70)
    end
end

local function RefreshState()
    ScanDefenseBuffs()
    ScanGladiatorTenacity()
    ScanCrystalProc()
    ScanCrystalWeaponBuff()
    ScanBoundStacks()
    ScanCrux()
    ScanNightbladeStacks()
    RefreshMaelstromBinding()
    RefreshUltimateSignetEquipped()
end

local function FormatCrystalTime(seconds)
    seconds = math.max(0, seconds)
    if seconds < 3 then
        return string.format("%.1f", seconds)
    end
    return tostring(math.ceil(seconds))
end


local function FormatMaelstromTime(milliseconds)
    local seconds = math.max(0, milliseconds / 1000)
    if seconds < 3 then
        return string.format("%.1f", seconds)
    end
    return tostring(math.ceil(seconds))
end


-- Timer warnings are tailored to the actual job of each tracker.
-- Bigger maintenance buffs warn earlier, short offensive channels warn later.
-- Keys cover both Major and Minor of a defensive group; this changes only
-- countdown text colors, never detection, timer duration or buff visibility.
local TIMER_WARNINGS = {
    taunt = {yellow = 7, red = 3},
    breach = {yellow = 5, red = 2},
    vulnerability = {yellow = 5, red = 2},
    heroism = {yellow = 6, red = 3},
    protection = {yellow = 5, red = 2},
    tankResolve = {yellow = 6, red = 3},
    mending = {yellow = 4, red = 2},
    vitality = {yellow = 4, red = 2},
    gladiator = {yellow = 3, red = 1.5},
    crystal = {yellow = 4, red = 2},
    beam = {yellow = 2, red = 1},
    templarBeam = {yellow = 2, red = 1},
    dkBreath = {yellow = 2, red = 1},
    dkCore = {yellow = 2, red = 1},
    wardenFirst = {yellow = 1.5, red = 0.7},
    wardenSecond = {yellow = 3, red = 1.5},
    backlash = {yellow = 3, red = 1.5},
    warrior = {yellow = 2, red = 1},
}

local function SetTrackerTimerColor(label, seconds, trackerKey)
    local warn = TIMER_WARNINGS[trackerKey]
    local yellowAt = warn and warn.yellow or 3
    local redAt = warn and warn.red or 1.5
    if seconds <= redAt then
        label:SetColor(1.00, 0.24, 0.18, 1.00)
    elseif seconds <= yellowAt then
        label:SetColor(1.00, 0.80, 0.12, 1.00)
    else
        label:SetColor(1.00, 1.00, 1.00, 1.00)
    end
end

local function SetMaelstromTimerColor(milliseconds)
    local seconds = math.max(0, milliseconds / 1000)

    if seconds <= 2 then
        SSRT.maelstromTimer:SetColor(1.00, 0.24, 0.18, 1.00)
    elseif seconds <= 5 then
        SSRT.maelstromTimer:SetColor(1.00, 0.80, 0.12, 1.00)
    else
        SSRT.maelstromTimer:SetColor(1.00, 1.00, 1.00, 1.00)
    end
end

-- Role flags are independent from class/subclass and from the skill's source.
-- GetPlayerRoles returns DPS, healer, tank booleans. No selected role means
-- no filtering, so the solo HUD stays visible when the grouping UI is unused.
local ROLE_DPS, ROLE_HEAL, ROLE_TANK = 1, 2, 4
local roleTrackerKeys = {
    "tankResolve", "vitality", "heroism", "protection", "mending", "slayer", "berserk", "brutality", "savagery", "force", "evasion", "gladiator", "templarRune", "dkWhip", "dkBreath", "dkCore", "crystal", "bound", "nightblade",
    "backlash", "templarBeam", "warden", "wardenFly", "necroSkull",
    "necroCorpse", "beam", "crux", "warrior", "maelstrom", "shield", "ultimate",
}
local function CurrentRoleMask()
    if not GetPlayerRoles then return 7 end
    local dps, heal, tank = GetPlayerRoles()
    local mask = (dps and ROLE_DPS or 0) + (heal and ROLE_HEAL or 0) + (tank and ROLE_TANK or 0)
    return mask ~= 0 and mask or 7
end
local function RoleAllowsTracker(key, selectedRoles)
    local filters = SSRT.sv and SSRT.sv.roleFilters
    local allowed = filters and filters[key]
    if allowed == nil then allowed = key == "debuffTaunt" and ROLE_TANK or 7 end
    return (allowed % 2 == 1 and selectedRoles % 2 == 1)
        or (math.floor(allowed / 2) % 2 == 1 and math.floor(selectedRoles / 2) % 2 == 1)
        or (math.floor(allowed / 4) % 2 == 1 and math.floor(selectedRoles / 4) % 2 == 1)
end

-- Target effect display: direct unit buffs, not inferred casts. Effect IDs from
-- different classes/morphs are classified by ESO buff-type when available.
-- This is a test feature: target API visibility and caster attribution need in-game checks.
local DEBUFF_TYPES = { [40] = "breachMinor", [41] = "breachMajor",
    [60] = "vulnerabilityMinor", [61] = "vulnerabilityMajor" }
local function ReadTargetDebuffs()
    local found = {}
    if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") then return found end
    for i = 1, GetNumBuffs("reticleover") do
        local _, _, finish, _, _, _, _, effectType, _, _, id, _, castByPlayer = GetUnitBuffInfo("reticleover", i)
        if finish and finish > GetFrameTimeSeconds() then
            if id == DEBUFF_TAUNT_ID and castByPlayer then
                found.taunt = math.max(found.taunt or 0, finish)
            end
            if effectType == BUFF_EFFECT_TYPE_DEBUFF and GetAbilityBuffType then
                local buffType, valid = GetAbilityBuffType(id, "reticleover")
                local kind = valid ~= false and DEBUFF_TYPES[buffType]
                if kind then found[kind] = math.max(found[kind] or 0, finish) end
            end
        end
    end
    return found
end
local function CreateTargetDebuffWindow(key, iconIndex, x, y, scale)
    local win = WINDOW_MANAGER:CreateTopLevelWindow("SRTTargetDebuff" .. key)
    win:SetDimensions(100, 92)
    win:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetMouseEnabled(false)
    win:SetHidden(true)
    local icon = nil
    if iconIndex then
        icon = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
        icon:SetAnchor(CENTER, win, CENTER)
        icon:SetTexture(GetArmoryIconTexture(iconIndex))
        icon:SetDimensions(scale, scale)
        local colors = { [1]={1,.48,.12}, [2]={.4,.68,1}, [3]={.95,.24,.28},
            [4]={.28,.92,.4}, [5]={.91,.67,1}, [6]={1,.9,.18}, [7]={.32,.92,.64} }
        local c = colors[GetUnitClassId("player")] or {1,1,1}
        icon:SetColor(c[1],c[2],c[3],1)
    end
    local label = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    label:SetAnchor(CENTER,win,CENTER)
    label:SetDimensions(90,90)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    local prefix = key == "taunt" and "debuffTaunt"
        or (key:find("breach") and "debuffBreach" or "debuffVulnerability")
    local grade = (key == "taunt") and "" or (key:find("Major") and "Major" or "Minor")
    label:SetFont(BuildFont(SSRT.sv[prefix .. grade .. "TextSize"] or SSRT.sv.debuffTextSize or 24))
    label:SetColor(1,1,1,1)
    local dragBackdrop = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
    dragBackdrop:SetAnchorFill(win)
    dragBackdrop:SetCenterColor(0.1, 0.35, 0.5, 0.14)
    dragBackdrop:SetEdgeColor(0.5, 0.9, 1.0, 0.8)
    dragBackdrop:SetHidden(true)
    win:SetHandler("OnMoveStop", function()
        local group = key == "taunt" and "debuffTaunt"
            or (key:find("breach") and "debuffBreach" or "debuffVulnerability")
        -- Group dragging uses its major tracker as an anchor.
        if key ~= "taunt" and not key:find("Major") then return end
        local x, y = win:GetCenter()
        local cx, cy = GuiRoot:GetCenter()
        if not (x and y and cx and cy) then return end
        local upper = group == "debuffBreach" and SSRT.sv.debuffBreachMajorOnTop
            or (group == "debuffVulnerability" and SSRT.sv.debuffVulnerabilityMajorOnTop)
        local shiftY = group == "debuffTaunt" and 0 or (upper and -30 or 32)
        SSRT.sv[group .. "OffsetX"] = zo_round(x - cx)
        SSRT.sv[group .. "OffsetY"] = zo_round(y - cy - shiftY)
    end)
    SSRT.debuffWindows[key]={window=win,label=label,icon=icon,dragBackdrop=dragBackdrop}
    local fragment = ZO_HUDFadeSceneFragment:New(win)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end
local function CreateTargetDebuffs()
    SSRT.debuffWindows={}
    CreateTargetDebuffWindow("taunt",nil,0,0,0)
    for _, data in ipairs({ {"breachMajor",DEBUFF_BREACH_ICON,DEBUFF_BREACH_X}, {"breachMinor",DEBUFF_BREACH_ICON,DEBUFF_BREACH_X},
        {"vulnerabilityMajor",DEBUFF_VULNERABILITY_ICON,DEBUFF_VULNERABILITY_X}, {"vulnerabilityMinor",DEBUFF_VULNERABILITY_ICON,DEBUFF_VULNERABILITY_X} }) do
        CreateTargetDebuffWindow(data[1],data[2],data[3],0,SSRT.sv.debuffMajorSize)
    end
end
local function ApplyTargetDebuffSizes()
    if not SSRT.debuffWindows then return end
    for key, obj in pairs(SSRT.debuffWindows) do
        local prefix = key == "taunt" and "debuffTaunt"
            or (key:find("breach") and "debuffBreach" or "debuffVulnerability")
        local grade = key == "taunt" and "" or (key:find("Major") and "Major" or "Minor")
        local size = SSRT.sv[prefix .. grade .. "Size"]
        local textSize = SSRT.sv[prefix .. grade .. "TextSize"] or SSRT.sv.debuffTextSize or 24
        if obj.icon and size then obj.icon:SetDimensions(size, size) end
        obj.label:SetFont(BuildFont(textSize))
    end
end
local function UpdateTargetDebuffs(now, visible, roleMask)
    local found = visible and ReadTargetDebuffs() or {}
    local bTop = SSRT.sv.debuffBreachMajorOnTop
    local vTop = SSRT.sv.debuffVulnerabilityMajorOnTop
    for key, obj in pairs(SSRT.debuffWindows or {}) do
        local group = key == "taunt" and "debuffTaunt"
            or (key:find("breach") and "debuffBreach" or "debuffVulnerability")
        local preview = SSRT.moveTarget == group
        local previewMain = key == "taunt" or key:find("Major") ~= nil
        if key == "taunt" and not preview then
            obj.window:ClearAnchors()
            obj.window:SetAnchor(CENTER, GuiRoot, CENTER,
                SSRT.sv.debuffTauntOffsetX or defaults.debuffTauntOffsetX,
                SSRT.sv.debuffTauntOffsetY or defaults.debuffTauntOffsetY)
        end
        local enabledKey = key == "taunt" and "debuffTauntEnabled" or ("debuff" .. key:sub(1,1):upper() .. key:sub(2) .. "Enabled")
        local enabled = SSRT.sv[enabledKey] and RoleAllowsTracker("debuff" .. key:sub(1,1):upper() .. key:sub(2),roleMask)
        local remain = (found[key] or 0)-now
        if preview then
            obj.window:SetHidden(not previewMain)
            if previewMain then
                obj.label:SetText("7")
                obj.label:SetColor(1, 1, 1, 1)
            end
        elseif enabled and remain > 0 then
            obj.window:SetHidden(false)
            obj.label:SetText(FormatGenericTime(remain))
            SetTrackerTimerColor(obj.label, remain, key == "taunt" and "taunt" or (key:find("breach") and "breach" or "vulnerability"))
        else
            obj.window:SetHidden(true)
        end
        if key ~= "taunt" and not (preview and previewMain) then
            local major = key:find("Major") ~= nil
            local top = vTop
            if key:find("breach") then top = bTop end
            -- The reticle (0,0) stays between the upper and lower grades.
            -- Do not shift the user's saved Breach/Vulnerability group X/Y.
            local y = (major == top) and -30 or 32
            local group = key:find("breach") and "debuffBreach" or "debuffVulnerability"
            local x = SSRT.sv[group .. "OffsetX"] or defaults[group .. "OffsetX"]
            local groupY = SSRT.sv[group .. "OffsetY"] or defaults[group .. "OffsetY"]
            obj.window:ClearAnchors()
            obj.window:SetAnchor(CENTER,GuiRoot,CENTER,x,groupY + y)
            if obj.icon then
                local size = SSRT.sv[group .. (major and "Major" or "Minor") .. "Size"]
                    or (major and SSRT.sv.debuffMajorSize or SSRT.sv.debuffMinorSize)
                obj.icon:SetDimensions(size,size)
            end
        end
    end
end

-- Templar Rune Focus morphs: cast location tracks the placed ground rune.
-- The player's temporary buff is NOT the rune lifetime: its own expiry can
-- be shorter/refreshed while the player is still inside the active rune.
-- Display is an inside/outside indicator, not a buff timer.
local RUNE_SUPPORT_SKILL_TO_BUFF = { [22234] = 33516, [22240] = 33524, [22237] = 33528 }
local RUNE_SUPPORT_DURATION = { [33516] = 20, [33524] = 25, [33528] = 20 }
local runeSupportCenter, runeSupportEnd = nil, 0
local runeSupportInside = false
local function OnRuneSupportTick()
    local now = GetFrameTimeSeconds()
    if not runeSupportCenter or now >= runeSupportEnd then
        runeSupportCenter, runeSupportInside = nil, false
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "RuneSupportTick")
        return
    end
    runeSupportInside = false
    if GetUnitRawWorldPosition then
        local zone, x, y, z = GetUnitRawWorldPosition("player")
        if zone == runeSupportCenter.zone and x and y and z then
            local dx, dy, dz = x-runeSupportCenter.x, y-runeSupportCenter.y, z-runeSupportCenter.z
            runeSupportInside = dx*dx + dy*dy + dz*dz <= 300*300
        end
    end
end
local function OnRuneSupportCast(_, slot)
    if not SSRT.sv or not SSRT.sv.templarRuneEnabled or type(slot) ~= "number" then return end
    local bar = GetActiveHotbarCategory()
    local id = GetSlotBoundId(slot, bar) or 0
    local effective = id ~= 0 and (GetEffectiveAbilityIdForAbilityOnHotbar(id, bar) or 0) or 0
    local buffId = RUNE_SUPPORT_SKILL_TO_BUFF[id] or RUNE_SUPPORT_SKILL_TO_BUFF[effective]
    if not buffId then return end
    if not GetUnitRawWorldPosition then return end
    local zone, x, y, z = GetUnitRawWorldPosition("player")
    if not (zone and x and y and z) then return end
    local now = GetFrameTimeSeconds()
    runeSupportCenter = {zone=zone,x=x,y=y,z=z,castTime=now,buffId=buffId}
    runeSupportEnd = now + RUNE_SUPPORT_DURATION[buffId] -- actual ground rune lifetime; do not cap to player buff
    runeSupportInside = false
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "RuneSupportTick")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "RuneSupportTick", 150, OnRuneSupportTick)
end

-- Low-layer transparent shield outline; independent of the target's taunt.
-- No shield is drawn while not blocking, so the reticle stays unobstructed.
local function CreateGuardIndicator()
    local window = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "GuardOutline")
    window:SetDimensions(80,80)
    window:SetDrawLayer(DL_BACKGROUND)
    window:SetDrawLevel(0)
    window:SetMouseEnabled(false)
    window:SetHidden(true)
    local texture = WINDOW_MANAGER:CreateControl(nil,window,CT_TEXTURE)
    texture:SetAnchorFill(window)
    texture:SetTexture("SoraReticleTracker/textures/guard_outline.dds")
    window:SetHandler("OnMoveStop", function() SaveControlOffset("guardIndicator") end)
    SSRT.guardOutlineWindow,SSRT.guardOutlineTexture = window,texture
end
local function ApplyGuardPosition()
    if not SSRT.guardOutlineWindow then return end
    local size = SSRT.sv.guardSize or 80
    local window = SSRT.guardOutlineWindow
    window:SetDimensions(size,size)
    window:ClearAnchors()
    window:SetAnchor(CENTER,GuiRoot,CENTER,SSRT.sv.guardOffsetX or 0,SSRT.sv.guardOffsetY or 0)
end
local function IsFrostGuardWeapon()
    local slot = GetActiveHotbarCategory() == HOTBAR_CATEGORY_BACKUP and EQUIP_SLOT_BACKUP_MAIN or EQUIP_SLOT_MAIN_HAND
    local link = GetItemLink(BAG_WORN,slot,LINK_STYLE_DEFAULT)
    return link and link ~= "" and GetItemLinkWeaponType(link) == WEAPONTYPE_FROST_STAFF
end
-- Guard resource automation, refreshed only on equipment/skill/character changes.
-- The learned passive and set equipment determine guard color automatically.
-- Old manual values remain in SavedVariables only for backwards compatibility.
local STORMWEAVER_CAVORT_SET_ID = 675
local TRI_FOCUS_BASE_ABILITY_ID = 45500
local guardStormweaverEquipped = false
local guardTriFocusLearned = nil -- nil: ESO could not resolve this skill on this client

local function RefreshGuardAutomation()
    guardStormweaverEquipped = false
    local itemLink = GetItemLink(BAG_WORN, EQUIP_SLOT_LEGS, LINK_STYLE_DEFAULT)
    if itemLink and itemLink ~= "" then
        local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, true)
        guardStormweaverEquipped = (hasSet and setId == STORMWEAVER_CAVORT_SET_ID) or false
    end

    guardTriFocusLearned = nil
    -- Resolve the passive by ability ID, not localized name or skill-line position.
    if GetSpecificSkillAbilityKeysByAbilityId then
        local skillType, skillLineIndex, abilityIndex =
            GetSpecificSkillAbilityKeysByAbilityId(TRI_FOCUS_BASE_ABILITY_ID)
        if skillType and skillLineIndex and abilityIndex
            and skillType > 0 and skillLineIndex > 0 and abilityIndex > 0 then
            if IsSkillAbilityPurchased then
                guardTriFocusLearned = IsSkillAbilityPurchased(skillType, skillLineIndex, abilityIndex) and true or false
            elseif GetSkillAbilityInfo then
                local _, _, _, passive, _, purchased =
                    GetSkillAbilityInfo(skillType, skillLineIndex, abilityIndex)
                if passive then guardTriFocusLearned = purchased and true or false end
            end
        end
    end
end

local function UpdateGuardIndicator(blockActive,roleMask)
    local window = SSRT.guardOutlineWindow
    if not window then return end
    if SSRT.moveTarget == "guardIndicator" then
        SSRT.guardOutlineTexture:SetColor(0.22, 0.95, 0.48, 0.95)
        window:SetHidden(false)
        return
    end
    local allowed = SSRT.sv.guardIndicatorEnabled and RoleAllowsTracker("guardIndicator",roleMask)
    if not (allowed and blockActive) then window:SetHidden(true);return end
    -- Keep existing blue/green rules. Equipped Stormweaver overrides weapon type;
    -- Tri Focus automatically drives ice-staff blocking when skill ID resolves.
    -- Unknown/unresolved passive state must not silently revive a legacy ON override.
    local triFocus = guardTriFocusLearned == true
    local magicka = guardStormweaverEquipped or (triFocus and IsFrostGuardWeapon())
    if magicka then
        SSRT.guardOutlineTexture:SetColor(0.28,0.85,1,0.95)
    else
        SSRT.guardOutlineTexture:SetColor(0.22,0.95,0.48,0.95)
    end
    window:SetHidden(false)
end

local function UpdateUltimateDisplay()
    return SSRT.Ultimate.UpdateDisplay()
end

local function UpdateUI()
    -- All reticle windows belong to the HUD, never to menus/inventory/dialogue.
    -- UpdateUI explicitly shows windows every 100ms, so the scene fragments alone
    -- cannot keep them hidden when another scene is active.
    if not (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")) then
        for _, key in ipairs({"crystal", "bound", "beam", "crux", "nightblade", "warrior", "warden", "backlash", "maelstrom", "templarBeam", "dkWhip", "dkBreath", "dkCore", "necroCorpse", "necroSkull", "wardenFly", "tankResolve", "shield", "templarRune", "vitality", "heroism", "protection", "mending", "slayer", "berserk", "brutality", "savagery", "force", "evasion", "gladiator", "ultimate"}) do
            local window = SSRT[key .. "Window"]
            if window then window:SetHidden(true) end
        end
        if SSRT.guardOutlineWindow then SSRT.guardOutlineWindow:SetHidden(true) end
        if SSRT.iconFinder then SSRT.iconFinder:SetHidden(true) end
        for _, v in pairs(SSRT.debuffWindows or {}) do v.window:SetHidden(true) end
        return
    end
    -- Display actual Skull buff stacks, never inferred cast counts.
    if SSRT.necroSkullWindow then
        if SSRT.moveTarget == "necroSkull" then
            SSRT.necroSkullWindow:SetHidden(false)
            SSRT.necroSkullLabel:SetText("3")
        elseif SSRT.sv.necroSkullEnabled and (SSRT.necroSkullStacks or 0) > 0 then
            local n = SSRT.necroSkullStacks
            SSRT.necroSkullWindow:SetHidden(false)
            SSRT.necroSkullLabel:SetText(tostring(n))
            local ready = n >= 2
            SSRT.necroSkullLabel:SetColor(1, ready and 0.22 or 0.83, 0.12, 1)
        else
            SSRT.necroSkullWindow:SetHidden(true)
        end
    end
    -- Update the corpse readiness display every HUD tick. Earlier versions put
    -- this in ScanCrystalProc(), which was never called by the live update path.
    -- Experimental corpse-ready indicator. Evaluate only the selected active-bar slot:
    -- ESO can return stale target/state flags for a weapon pair that is not active.
    -- If the highest-priority equipped absorb is on the other bar, hide rather than guess.
    if SSRT.necroCorpseWindow then
        if SSRT.moveTarget == "necroCorpse" then
            SSRT.necroCorpseWindow:SetHidden(false)
        elseif SSRT.sv.necroCorpseEnabled then
            local activeCategory = GetActiveHotbarCategory()
            local selected = SSRT.necroCorpseSelectedByBar and SSRT.necroCorpseSelectedByBar[activeCategory]
            -- Read the CURRENT bar only: inactive-bar action-slot failure flags may be stale.
            -- Each bar chooses its own best equipped absorb so primary-bar priority
            -- cannot suppress a usable absorb equipped on the backup bar.
            local lit = selected ~= nil
                and not ActionSlotHasTargetFailure(selected.slot, activeCategory)
                and not ActionSlotHasNonCostStateFailure(selected.slot, activeCategory)
            SSRT.necroCorpseWindow:SetHidden(not lit)
        else
            SSRT.necroCorpseWindow:SetHidden(true)
        end
    end
    local now = GetFrameTimeSeconds()

    local blockActive = IsBlockActive()
    UpdateGuardIndicator(blockActive,CurrentRoleMask())
    SSRT.Shield.Update(now)
    -- The effect can expire independently of the shield absorbing damage.
    if SSRT.moveTarget == "gladiator" then
        SSRT.gladiatorWindow:SetHidden(false)
        SSRT.gladiatorLabel:SetText("8")
        SSRT.gladiatorLabel:SetColor(1, 1, 1, 1)
    else
        local remaining = (SSRT.gladiatorEnd or 0) - now
        if SSRT.sv.gladiatorEnabled and remaining > 0 then
            SSRT.gladiatorWindow:SetHidden(false)
            SSRT.gladiatorLabel:SetText(FormatGenericTime(remaining))
            SetTrackerTimerColor(SSRT.gladiatorLabel, remaining, "gladiator")
        else
            SSRT.gladiatorWindow:SetHidden(true)
        end
    end
    if SSRT.beamActive and blockActive and not SSRT.wasBlockActive then
        SSRT.beamActive = false
        SSRT.beamEndTimeMs = 0
    end
    if blockActive and not SSRT.wasBlockActive then
        SSRT.dkBreathEnd = 0
    end
    if blockActive and not SSRT.wasBlockActive then
        ClearTemplarBeam()
    end
    SSRT.wasBlockActive = blockActive

    if SSRT.moveTarget ~= "beam" then
        if SSRT.sv.beamEnabled and SSRT.beamActive then
            local remainingMs = SSRT.beamEndTimeMs - GetFrameTimeMilliseconds()
            if remainingMs > 0 then
                SSRT.beamWindow:SetHidden(false)
                SSRT.beamTimer:SetText(FormatBeamTime(remainingMs))
                SetTrackerTimerColor(SSRT.beamTimer, remainingMs / 1000, "beam")
            else
                SSRT.beamActive = false
                SSRT.beamEndTimeMs = 0
                SSRT.beamWindow:SetHidden(true)
            end
        else
            SSRT.beamWindow:SetHidden(true)
        end
    else
        SSRT.beamWindow:SetHidden(false)
        SSRT.beamTimer:SetText("4.5")
    end

    if SSRT.moveTarget == "templarRune" then
        SSRT.templarRuneWindow:SetHidden(false)
    else
        SSRT.templarRuneWindow:SetHidden(not (SSRT.sv.templarRuneEnabled and runeSupportInside))
    end

    for _, key in ipairs(DEFENSE_KEYS) do
        local pair = SSRT.defensePairs[key]
        local ends = SSRT.defenseBuffEnds[key] or {}
        local majorRemain = (ends.major or 0) - now
        local minorRemain = (ends.minor or 0) - now
        local preview = SSRT.moveTarget == key
        -- Each grade has its own permanent-buff switch.  The legacy global
        -- setting is a fallback for accounts that have not configured the new
        -- switches yet (do not silently re-enable a previously hidden aura).
        local majorSetting = SSRT.sv[key .. "MajorShowPermanent"]
        local minorSetting = SSRT.sv[key .. "MinorShowPermanent"]
        if majorSetting == nil then majorSetting = SSRT.sv.defenseShowPermanentBuffs ~= false end
        if minorSetting == nil then minorSetting = SSRT.sv.defenseShowPermanentBuffs ~= false end
        -- A timed source takes precedence over an overlapping no-expiry source.
        local majorPermanent = majorSetting and ends.majorPermanent and majorRemain <= 0 or false
        local minorPermanent = minorSetting and ends.minorPermanent and minorRemain <= 0 or false
        local majorVisible = preview or (SSRT.sv[key .. "Enabled"] and (majorPermanent or majorRemain > 0))
        local minorVisible = preview or (SSRT.sv[key .. "MinorEnabled"] and (minorPermanent or minorRemain > 0))
        SSRT[key .. "Window"]:SetHidden(not (majorVisible or minorVisible))
        for _, art in ipairs({SSRT[key .. "GlowOuter"], SSRT[key .. "GlowMid"], SSRT[key .. "Icon"]}) do
            art:SetHidden(not majorVisible)
        end
        -- A permanent buff has no countdown. Show the icon but never a false '0'.
        SSRT[key .. "Label"]:SetHidden(not majorVisible or (majorPermanent and not preview))
        pair.icon:SetHidden(not minorVisible)
        pair.label:SetHidden(not minorVisible or (minorPermanent and not preview))
        if majorVisible and (preview or not majorPermanent) then
            SSRT[key .. "Label"]:SetText(preview and "12" or FormatGenericTime(majorRemain))
            if preview then SSRT[key .. "Label"]:SetColor(1,1,1,1)
            else SetTrackerTimerColor(SSRT[key .. "Label"], majorRemain, key) end
        end
        if minorVisible and (preview or not minorPermanent) then
            pair.label:SetText(preview and "8" or FormatGenericTime(minorRemain))
            if preview then pair.label:SetColor(1,1,1,1)
            else SetTrackerTimerColor(pair.label, minorRemain, key) end
        end
    end

    if SSRT.moveTarget ~= "templarBeam" then
        local remaining = (SSRT.templarBeamEnd or 0) - now
        if SSRT.sv.templarBeamEnabled and remaining > 0 then
            SSRT.templarBeamWindow:SetHidden(false)
            SSRT.templarBeamLabel:SetText(FormatGenericTime(remaining))
            SetTrackerTimerColor(SSRT.templarBeamLabel, remaining, "templarBeam")
        else
            SSRT.templarBeamWindow:SetHidden(true)
        end
    else
        SSRT.templarBeamWindow:SetHidden(false)
        SSRT.templarBeamLabel:SetText("3.8")
    end

    if SSRT.moveTarget ~= "crux" then
        if SSRT.sv.cruxEnabled and (SSRT.cruxStacks or 0) > 0 then
            SSRT.cruxWindow:SetHidden(false)
            SSRT.cruxStack:SetText(tostring(SSRT.cruxStacks))
            SetCruxStackColor(SSRT.cruxStacks)
        else
            SSRT.cruxWindow:SetHidden(true)
        end
    else
        SSRT.cruxWindow:SetHidden(false)
        SSRT.cruxStack:SetText("3")
        SetCruxStackColor(3)
    end

    if SSRT.moveTarget ~= "nightblade" then
        if SSRT.sv.nightbladeEnabled and (SSRT.nightbladeStacks or 0) > 0 then
            SSRT.nightbladeWindow:SetHidden(false)
            SSRT.nightbladeStack:SetText(tostring(SSRT.nightbladeStacks))
            SetNightbladeStackColor(SSRT.nightbladeStacks, SSRT.nightbladeReadyAt or 5)
        else
            SSRT.nightbladeWindow:SetHidden(true)
        end
    else
        SSRT.nightbladeWindow:SetHidden(false)
        SSRT.nightbladeStack:SetText("4")
        SetNightbladeStackColor(4, 5)
    end

    for _, key in ipairs({"dkWhip", "dkBreath"}) do
        local window, label = SSRT[key .. "Window"], SSRT[key .. "Label"]
        if SSRT.moveTarget == key then
            window:SetHidden(false)
            label:SetText(key == "dkWhip" and "3" or "4.8")
        elseif not SSRT.sv.dkEnabled or not SSRT.sv[key .. "Enabled"] then
            window:SetHidden(true)
        elseif key == "dkWhip" then
            local stacks = SSRT.dkWhipStacks or 0
            if stacks > 0 then
                window:SetHidden(false)
                label:SetText(tostring(stacks))
                label:SetColor(stacks >= 3 and 1 or 1, stacks >= 3 and 0.22 or 0.83, 0.12, 1)
            else window:SetHidden(true) end
        elseif key == "templarBeam" then
            -- Updated in dedicated beam block above.
        elseif key == "dkBreath" then
            local remaining = SSRT.dkBreathEnd - now
            if remaining > 0 then
                window:SetHidden(false)
                label:SetText(FormatGenericTime(remaining))
                SetTrackerTimerColor(label, remaining, "dkBreath")
            else window:SetHidden(true) end
        end
    end

    -- Core of Flame (and morphs): support timer is independent of DK attack trackers.
    if SSRT.moveTarget == "dkCore" then
        SSRT.dkCoreWindow:SetHidden(false)
        SSRT.dkCoreLabel:SetText("4")
    else
        local remain = (SSRT.dkCoreEnd or 0) - now
        if SSRT.sv.dkCoreEnabled and remain > 0 then
            SSRT.dkCoreWindow:SetHidden(false)
            SSRT.dkCoreLabel:SetText(FormatGenericTime(remain))
            SetTrackerTimerColor(SSRT.dkCoreLabel, remain, "dkCore")
        else
            SSRT.dkCoreWindow:SetHidden(true)
        end
    end

    ScanWardenFlyReady()
    if SSRT.moveTarget ~= "wardenFly" then
        SSRT.wardenFlyWindow:SetHidden(not (SSRT.sv.wardenFlyEnabled and SSRT.wardenFlyReady))
    else
        SSRT.wardenFlyWindow:SetHidden(false)
    end

    if SSRT.moveTarget ~= "warden" then
        local first = (SSRT.wardenFirstHit or 0) - now
        local second = (SSRT.wardenSecondHit or 0) - now
        if SSRT.sv.wardenEnabled and second > 0 then
            SSRT.wardenWindow:SetHidden(false)
            if first > 0 then
                SSRT.wardenTimer:SetText("1:" .. FormatGenericTime(first))
                SetTrackerTimerColor(SSRT.wardenTimer, first, "wardenFirst")
            else
                SSRT.wardenTimer:SetText("2:" .. FormatGenericTime(second))
                SetTrackerTimerColor(SSRT.wardenTimer, second, "wardenSecond")
            end
        else
            SSRT.wardenWindow:SetHidden(true)
        end
    else
        SSRT.wardenWindow:SetHidden(false)
        SSRT.wardenTimer:SetText("1:3.0")
    end

    if SSRT.moveTarget ~= "backlash" then
        local backlashRemaining = (SSRT.backlashEndTime or 0) - now
        if SSRT.sv.backlashEnabled and backlashRemaining > 0 then
            SSRT.backlashWindow:SetHidden(false)
            SSRT.backlashTimer:SetText(FormatGenericTime(backlashRemaining))
            SetTrackerTimerColor(SSRT.backlashTimer, backlashRemaining, "backlash")
        else
            SSRT.backlashWindow:SetHidden(true)
        end
    else
        SSRT.backlashWindow:SetHidden(false)
        SSRT.backlashTimer:SetText("6")
    end

    if SSRT.moveTarget ~= "warrior" then
        local warriorRemaining = (SSRT.warriorOpportunityEndTime or 0) - now
        if warriorRemaining > 0 then
            SSRT.warriorWindow:SetHidden(false)
            SSRT.warriorTimer:SetText(FormatGenericTime(warriorRemaining))
            SetTrackerTimerColor(SSRT.warriorTimer, warriorRemaining, "warrior")
        else
            SSRT.warriorOpportunityEndTime = 0
            SSRT.warriorWindow:SetHidden(true)
        end
    else
        SSRT.warriorWindow:SetHidden(false)
        SSRT.warriorTimer:SetText("5")
    end

    if SSRT.moveTarget ~= "crystal" then
        local weaponReady = (SSRT.crystalWeaponCharges or 0) > 0 and (SSRT.crystalWeaponEnd or 0) > now
        local fragmentReady = SSRT.crystalActive and SSRT.crystalEndTime > now
        if weaponReady or fragmentReady then
            local tex = GetArmoryIconTexture(weaponReady and CRYSTAL_WEAPON_ARMORY_ICON_INDEX or CRYSTAL_ARMORY_ICON_INDEX)
            SSRT.crystalGlowOuter:SetTexture(tex)
            SSRT.crystalGlowMid:SetTexture(tex)
            SSRT.crystalIcon:SetTexture(tex)
            SSRT.crystalWindow:SetHidden(false)
            if weaponReady then
                SSRT.crystalTimer:SetText(tostring(SSRT.crystalWeaponCharges))
                SSRT.crystalTimer:SetColor(1, 1, 1, 1)
            else
                local crystalRemaining = SSRT.crystalEndTime - now
                SSRT.crystalTimer:SetText(FormatCrystalTime(crystalRemaining))
                SetTrackerTimerColor(SSRT.crystalTimer, crystalRemaining, "crystal")
            end
        else
            SSRT.crystalWindow:SetHidden(true)
        end
    else
        SSRT.crystalWindow:SetHidden(false)
        SSRT.crystalTimer:SetText("3")
    end

    if SSRT.moveTarget ~= "bound" then
        if SSRT.sv.boundEnabled and (SSRT.boundStacks or 0) > 0 then
            SSRT.boundWindow:SetHidden(false)
            SSRT.boundStack:SetText(tostring(SSRT.boundStacks))
            SetBoundStackColor(SSRT.boundStacks)
        else
            SSRT.boundWindow:SetHidden(true)
        end
    else
        SSRT.boundWindow:SetHidden(false)
        SSRT.boundStack:SetText("5")
        SetBoundStackColor(5)
    end

    if SSRT.moveTarget ~= "maelstrom" then
        local remainingMs = ReadMaelstromTimer()

        if remainingMs > 0 then
            local iconIndex = MAELSTROM_ARMORY_ICONS[SSRT.maelstromKind]
            if iconIndex then
                local tex = GetArmoryIconTexture(iconIndex)
                SSRT.maelstromGlowOuter:SetTexture(tex)
                SSRT.maelstromGlowMid:SetTexture(tex)
                SSRT.maelstromIcon:SetTexture(tex)
            end
            SSRT.maelstromWindow:SetHidden(false)
            SSRT.maelstromTimer:SetText(FormatMaelstromTime(remainingMs))
            SetMaelstromTimerColor(remainingMs)
        else
            SSRT.maelstromWindow:SetHidden(true)
        end
    else
        local tex = GetArmoryIconTexture(MAELSTROM_ARMORY_ICONS[SSRT.maelstromKind] or 52)
        SSRT.maelstromGlowOuter:SetTexture(tex)
        SSRT.maelstromGlowMid:SetTexture(tex)
        SSRT.maelstromIcon:SetTexture(tex)
        SSRT.maelstromWindow:SetHidden(false)
        SSRT.maelstromTimer:SetText("5")
        SSRT.maelstromTimer:SetColor(1.00, 0.80, 0.12, 1.00)
    end
    UpdateTargetDebuffs(GetFrameTimeSeconds(), true, CurrentRoleMask())
    if SSRT.moveTarget ~= "ultimate" then
        UpdateUltimateDisplay()
    end
    -- Final visibility filter only: never change tracker timers or event state.
    -- Allow dragging even if the current role is excluded from the filter.
    local selectedRoles = CurrentRoleMask()
    for _, key in ipairs(roleTrackerKeys) do
        if SSRT.moveTarget ~= key and not RoleAllowsTracker(key, selectedRoles) then
            local window = SSRT[key .. "Window"]
            if window then window:SetHidden(true) end
        end
    end
end

-- Separate input handling from reticle HUD. Do not override ESO action bindings.
-- LibSkillBlocker v1.1.0 provides gamepad-aware blocking and a silent option.
local function ShouldBlockUnproccedCrystal(slotNum, abilityId)
    return not (SSRT.crystalActive and SSRT.crystalEndTime > GetFrameTimeSeconds())
end

local crystalBlockRegistered = false
local function ApplyCrystalSilentBlock()
    local lib = LibSkillBlocker
    if crystalBlockRegistered and lib then
        lib.UnregisterSkillBlock(ADDON_NAME, CRYSTAL_FRAGMENTS_SKILL_ABILITY_ID)
        crystalBlockRegistered = false
    end
    if not SSRT.sv.crystalSilentBlockEnabled then return end
    if not lib then
        Chat("Crystal silent block needs LibSkillBlocker (1.1.0+). Existing skill behavior unchanged.")
        return
    end
    -- Test: older LibSkillBlocker source uses showError=false for silent blocking.
    lib.RegisterSkillBlock(ADDON_NAME, CRYSTAL_FRAGMENTS_SKILL_ABILITY_ID, ShouldBlockUnproccedCrystal, false)
    crystalBlockRegistered = true
end

-- Position controls: each slider has an editable number box (LibAddonMenu default).
-- SavedVariables are left untouched until a user moves or resets the tracker.
-- UI localization happens *after* menu classification and role lookup.
-- Keys are stable identifiers; no effect detection or saved setting uses these labels.
local MENU_LABEL_KEYS = {
    ["Attack — Berserk (Major / Minor)"] = "ATK_BERSERK_TITLE",
    ["Berserk (Major / Minor)"] = "ATK_BERSERK_SHORT",
    ["Attack — Brutality (Major / Minor)"] = "ATK_BRUTALITY_TITLE",
    ["Brutality (Major / Minor)"] = "ATK_BRUTALITY_SHORT",
    ["Attack — Savagery (Major / Minor)"] = "ATK_SAVAGERY_TITLE",
    ["Attack — Force (Major / Minor)"] = "ATK_FORCE_TITLE",
    ["Attack — Slayer (Major / Minor)"] = "ATK_SLAYER_TITLE",
    ["Savagery (Major / Minor)"] = "ATK_SAVAGERY_SHORT",
    ["Force (Major / Minor)"] = "ATK_FORCE_SHORT",
    ["Slayer (Major / Minor)"] = "ATK_SLAYER_SHORT",
    ["Track this attack buff on yourself from any source. Major/Minor are separate; timed versions count down, no-expiry versions can be shown as icons."] = "ATK_BUFF_DESC",
    ["Move Berserk buff"] = "COMMON_MOVE_DISPLAY",
    ["Move Brutality buff"] = "COMMON_MOVE_DISPLAY",
    ["Move Savagery buff"] = "COMMON_MOVE_DISPLAY",
    ["Move Force buff"] = "COMMON_MOVE_DISPLAY",
    ["Move Slayer buff"] = "COMMON_MOVE_DISPLAY",
    ["Move Evasion"] = "COMMON_MOVE_DISPLAY",
    ["Enable Major Berserk"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Brutality"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Savagery"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Force"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Slayer"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Evasion"] = "COMMON_MAJOR_SHOW",
    ["Enable Minor Berserk"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Brutality"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Savagery"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Force"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Slayer"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Evasion"] = "COMMON_MINOR_SHOW",

    ["A corpse is usable here! Lights up when a slotted corpse-consuming skill can reach one. It checks usability, not the number of corpses nearby."] = "NECRO_CORPSE_DESC",
    ["A quick sign that you're blocking: green for Stamina, cyan for Magicka. Frost Staff / Tri Focus and special gear can change the resource you guard with."] = "TANK_GUARD_DESC",
    ["Arcanist Beam timer"] = "POS_ARC_BEAM",
    ["Arcanist Beam timer X position"] = "COMMON_POSITION_X",
    ["Arcanist Beam timer Y position"] = "COMMON_POSITION_Y",
    ["Arcanist — Beam"] = "ARC_BEAM_TITLE",
    ["Arcanist — Crux"] = "ARC_CRUX_TITLE",
    ["Attack"] = "ROLE_ATTACK",
    ["Backlash icon size"] = "COMMON_ICON_SIZE",
    ["Backlash timer"] = "POS_BACKLASH",
    ["Backlash timer X position"] = "COMMON_POSITION_X",
    ["Backlash timer Y position"] = "COMMON_POSITION_Y",
    ["Backlash timer text size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Beam icon size"] = "COMMON_ICON_SIZE",
    ["Beam timer size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Block Crystal Fragments without proc (silent)"] = "SORC_CRYSTAL_BLOCK_CRYSTAL_FRAGMENTS_WITHOUT_PROC_SILENT",
    ["Bound Armaments stacks"] = "POS_BOUND",
    ["Bound Armaments stacks X position"] = "COMMON_POSITION_X",
    ["Bound Armaments stacks Y position"] = "COMMON_POSITION_Y",
    ["Bound icon size"] = "COMMON_ICON_SIZE",
    ["Bound stack text size"] = "COMMON_STACK_NUMBER_SIZE",
    ["Breach pair"] = "POSITION_BREACH_PAIR",
    ["Breach pair X position"] = "COMMON_POSITION_X",
    ["Breach pair Y position"] = "COMMON_POSITION_Y",
    ["Breath icon size"] = "COMMON_ICON_SIZE",
    ["Breath number size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Breath timer"] = "POS_BREATH",
    ["Breath timer X position"] = "COMMON_POSITION_X",
    ["Breath timer Y position"] = "COMMON_POSITION_Y",
    ["Build toward your empowered Skull! Tracks Flame Skull, Ricochet Skull and Venom Skull so the next boosted hit is easy to notice."] = "NECRO_SKULL_DESC",
    ["Check Major and Minor Vitality when incoming heals matter. The two strengths stay separate, and permanent effects don't need a countdown."] = "BUFF_VITALITY_DESC",
    ["Corpse Detector"] = "POS_CORPSE",
    ["Corpse Detector X position"] = "COMMON_POSITION_X",
    ["Corpse Detector Y position"] = "COMMON_POSITION_Y",
    ["Corpse icon size"] = "COMMON_ICON_SIZE",
    ["Crushing Wall — Blockade / Unstable Wall"] = "WPN_MAEL_CRUSHING_WALL_BLOCKADE_UNSTABLE_WALL",
    ["Crux icon size"] = "COMMON_ICON_SIZE",
    ["Crux stack text size"] = "COMMON_STACK_NUMBER_SIZE",
    ["Crux stacks"] = "POS_CRUX",
    ["Crux stacks X position"] = "COMMON_POSITION_X",
    ["Crux stacks Y position"] = "COMMON_POSITION_Y",
    ["Crux stacks are ready for your next beam! The number goes gold at 2 and red at 3."] = "ARC_CRUX_DESC",
    ["Crystal Fragments proc and Crystal Weapon charges share one HUD position. See which effect is ready without watching two separate icons."] = "SORC_CRYSTAL_DESC",
    ["Crystal icon size"] = "COMMON_ICON_SIZE",
    ["Crystal timer size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Crystal tracker"] = "POS_CRYSTAL",
    ["Crystal tracker X position"] = "COMMON_POSITION_X",
    ["Crystal tracker Y position"] = "COMMON_POSITION_Y",
    ["Damage Shield"] = "POS_SHIELD",
    ["Damage Shield X position"] = "COMMON_POSITION_X",
    ["Damage Shield Y position"] = "COMMON_POSITION_Y",
    ["Debuffs — Breach — Target"] = "DEBUFF_BREACH_TITLE",
    ["Debuffs — Vulnerability — Target"] = "DEBUFF_VULN_TITLE",
    ["Drag the slider or type a number. Relative to the screen center. Existing saved positions are preserved."] = "POSITION_TIP",
    ["Dragonknight — Breath"] = "DK_BREATH_TITLE",
    ["Dragonknight — Core of Flame"] = "DK_CORE_TITLE",
    ["Tracks the 4-second resource recovery of Core of Flame, Heart of Flame, and Soul of Flame after casting. This is a cast-based support timer."] = "DK_CORE_DESC",
    ["Core icon size"] = "COMMON_ICON_SIZE",
    ["Core number size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Move Core of Flame timer"] = "DK_CORE_MOVE",
    ["Dragonknight — Whip"] = "DK_WHIP_TITLE",
    ["Empowered Fly indicator"] = "POS_FLY",
    ["Empowered Fly indicator X position"] = "COMMON_POSITION_X",
    ["Empowered Fly indicator Y position"] = "COMMON_POSITION_Y",
    ["Enable Major Heroism"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Mending"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Protection"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Resolve"] = "COMMON_MAJOR_SHOW",
    ["Enable Major Vitality"] = "COMMON_MAJOR_SHOW",
    ["Enable Minor Heroism"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Mending"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Protection"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Resolve"] = "COMMON_MINOR_SHOW",
    ["Enable Minor Vitality"] = "COMMON_MINOR_SHOW",
    ["Enable when Tri Focus is learned; frost-staff blocking uses Magicka. Disable if your character has not learned it."] = "TANK_GUARD_TOOLTIP_ENABLE_WHEN_TRI_FOCUS_IS_LEARNED_FROST_STAFF_BLOCKING_U",
    ["Feel Seething Fury build! Your whip stacks turn warm yellow at 1-2 and red at 3, so the big hit is easy to spot."] = "DK_WHIP_DESC",
    ["Fly icon size"] = "COMMON_ICON_SIZE",
    ["Follow both Shalk hits from Deep Fissure or Subterranean Assault, not just a total timer. The first and second hit timings stay visible."] = "WARDEN_SHALK_DESC",
    ["Force Magicka Guard (Stormweaver)"] = "TANK_GUARD_FORCE_MAGICKA_GUARD_STORMWEAVER",
    ["Frost Staff + Tri Focus learned"] = "TANK_GUARD_FROST_STAFF_TRI_FOCUS_LEARNED",
    ["General"] = "GENERAL_TITLE",
    ["Grim Focus stacks"] = "POS_NB",
    ["Grim Focus stacks X position"] = "COMMON_POSITION_X",
    ["Grim Focus stacks Y position"] = "COMMON_POSITION_Y",
    ["Guard indicator size"] = "COMMON_DISPLAY_SIZE",
    ["Guard outline size"] = "COMMON_DISPLAY_SIZE",
    ["Guard position X"] = "COMMON_POSITION_X",
    ["Guard position Y"] = "COMMON_POSITION_Y",
    ["Heal"] = "ROLE_HEAL",
    ["Heroism buffs"] = "POS_HEROISM",
    ["Heroism buffs X position"] = "COMMON_POSITION_X",
    ["Heroism buffs Y position"] = "COMMON_POSITION_Y",
    ["Heroism major icon size"] = "COMMON_MAJOR_ICON_SIZE",
    ["Heroism major number size"] = "COMMON_MAJOR_NUMBER_SIZE",
    ["Heroism minor icon size"] = "COMMON_MINOR_ICON_SIZE",
    ["Heroism minor number size"] = "COMMON_MINOR_NUMBER_SIZE",
    ["Heroism: Major above Minor"] = "COMMON_MAJOR_ABOVE_MINOR",
    ["Hide Ultimate HUD with Shattered Paths Signet"] = "ULT_HIDE_ULTIMATE_HUD_WITH_SHATTERED_PATHS_SIGNET",
    ["Hide both Ultimate tracker rows while Shattered Paths Signet is equipped. Does not change Ultimate skills, points, or input controls. Default OFF."] = "ULT_TOOLTIP_HIDE_BOTH_ULTIMATE_TRACKER_ROWS_WHILE_SHATTERED_PATHS_S",
    ["Keep Maelstrom weapon effect timers in sight whether the matching skill is on the front or back bar. Track the effect, not a fixed weapon side."] = "WPN_MAEL_DESC",
    ["Keep Major and Minor Breach in sight on your current target, including effects placed by allies. Their two icons stay put when one disappears."] = "DEBUFF_BREACH_DESC",
    ["Keep Major and Minor Resolve within reach of your eyes. Each grade stays in its own spot, with a countdown only when it has an expiry."] = "BUFF_TANKRESOLVE_DESC",
    ["Keep an eye on the remaining time of the tracked Breath effect. Its countdown tells you when it's time to use Breath again."] = "DK_BREATH_DESC",
    ["Keep the Fatecarver and Remedy Cascade beam durations in view, including their supported morphs. Works with subclassed skill lines too."] = "ARC_BEAM_DESC",
    ["Keep track of the 6-second buildup from Power of the Light or Purifying Light, right up to the final burst."] = "TPL_BACKLASH_DESC",
    ["Maelstrom timer"] = "POS_MAEL",
    ["Maelstrom timer X position"] = "COMMON_POSITION_X",
    ["Maelstrom timer Y position"] = "COMMON_POSITION_Y",
    ["Maelstrom icon size"] = "COMMON_ICON_SIZE",
    ["Maelstrom timer text size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Maelstrom — Weapon timer"] = "WPN_MAEL_TITLE",
    ["Major Breach"] = "COMMON_MAJOR_SHOW",
    ["Major Breach above Minor"] = "COMMON_MAJOR_ABOVE_MINOR",
    ["Major Vulnerability"] = "COMMON_MAJOR_SHOW",
    ["Major Vulnerability above Minor"] = "COMMON_MAJOR_ABOVE_MINOR",
    ["Major effect icon size"] = "COMMON_MAJOR_ICON_SIZE",
    ["Mending buffs"] = "POS_MENDING",
    ["Mending buffs X position"] = "COMMON_POSITION_X",
    ["Mending buffs Y position"] = "COMMON_POSITION_Y",
    ["Evasion"] = "POS_EVASION",
    ["Mending major icon size"] = "COMMON_MAJOR_ICON_SIZE",
    ["Mending major number size"] = "COMMON_MAJOR_NUMBER_SIZE",
    ["Mending minor icon size"] = "COMMON_MINOR_ICON_SIZE",
    ["Mending minor number size"] = "COMMON_MINOR_NUMBER_SIZE",
    ["Mending: Major above Minor"] = "COMMON_MAJOR_ABOVE_MINOR",
    ["Merciless Charge — Stampede"] = "WPN_MAEL_MERCILESS_CHARGE_STAMPEDE",
    ["Minor Breach"] = "COMMON_MINOR_SHOW",
    ["Minor Vulnerability"] = "COMMON_MINOR_SHOW",
    ["Minor effect icon size"] = "COMMON_MINOR_ICON_SIZE",
    ["Move Arcanist Beam timer"] = "COMMON_MOVE_DISPLAY",
    ["Move Backlash timer"] = "COMMON_MOVE_DISPLAY",
    ["Move Bound Armaments stacks"] = "COMMON_MOVE_DISPLAY",
    ["Move Breach pair"] = "COMMON_MOVE_DISPLAY",
    ["Move Breath timer"] = "COMMON_MOVE_DISPLAY",
    ["Move Corpse Detector"] = "COMMON_MOVE_DISPLAY",
    ["Move Crux stacks"] = "COMMON_MOVE_DISPLAY",
    ["Move Crystal tracker"] = "COMMON_MOVE_DISPLAY",
    ["Move Damage Shield"] = "COMMON_MOVE_DISPLAY",
    ["Move Damage Shield timer"] = "COMMON_MOVE_DISPLAY",
    ["Move Empowered Fly indicator"] = "COMMON_MOVE_DISPLAY",
    ["Move Grim Focus stacks"] = "COMMON_MOVE_DISPLAY",
    ["Move Guard Indicator"] = "COMMON_MOVE_DISPLAY",
    ["Move Heroism"] = "COMMON_MOVE_DISPLAY",
    ["Move Heroism buffs"] = "COMMON_MOVE_DISPLAY",
    ["Move Maelstrom timer"] = "COMMON_MOVE_DISPLAY",
    ["Move Mending"] = "COMMON_MOVE_DISPLAY",
    ["Move Mending buffs"] = "COMMON_MOVE_DISPLAY",
    ["Move Protection"] = "COMMON_MOVE_DISPLAY",
    ["Move Protection buffs"] = "COMMON_MOVE_DISPLAY",
    ["Move Resolve"] = "COMMON_MOVE_DISPLAY",
    ["Move Resolve buffs"] = "COMMON_MOVE_DISPLAY",
    ["Move Rune Focus area"] = "COMMON_MOVE_DISPLAY",
    ["Move Shalk timer"] = "COMMON_MOVE_DISPLAY",
    ["Move Skull stacks"] = "COMMON_MOVE_DISPLAY",
    ["Move Taunt"] = "COMMON_MOVE_DISPLAY",
    ["Move Templar Beam timer"] = "COMMON_MOVE_DISPLAY",
    ["Move Ultimate tracker"] = "COMMON_MOVE_DISPLAY",
    ["Move Vitality"] = "COMMON_MOVE_DISPLAY",
    ["Move Vitality buffs"] = "COMMON_MOVE_DISPLAY",
    ["Move Vulnerability pair"] = "COMMON_MOVE_DISPLAY",
    ["Move Warrior's Opportunity timer"] = "COMMON_MOVE_DISPLAY",
    ["Move Whip stacks"] = "COMMON_MOVE_DISPLAY",
    ["Move {label}"] = "MOVE_TARGET",
    ["Move display"] = "COMMON_MOVE_DISPLAY",
    ["Taunt number size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Major effect number size"] = "COMMON_MAJOR_NUMBER_SIZE",
    ["Minor effect number size"] = "COMMON_MINOR_NUMBER_SIZE",
    ["Necromancer — Corpse Detector"] = "NECRO_CORPSE_TITLE",
    ["Necromancer — Skull stacks"] = "NECRO_SKULL_TITLE",
    ["Nightblade icon size"] = "COMMON_ICON_SIZE",
    ["Nightblade stack text size"] = "COMMON_STACK_NUMBER_SIZE",
    ["Nightblade — Grim Focus"] = "NB_GRIM_TITLE",
    ["ON"] = "COMMON_ON",
    ["Open a tracker to edit enable/roles, size, position and other options together. Role switches use [x] ON / [ ] OFF. Saved positions only change when you move or reset them."] = "GENERAL_DESC",
    ["Optional: requires LibSkillBlocker 1.1.0 or later. Only allow Crystal Fragments with its proc active. Default OFF."] = "SORC_CRYSTAL_TOOLTIP_OPTIONAL_REQUIRES_LIBSKILLBLOCKER_1_1_0_OR_LATER_ONLY_A",
    ["Protection buffs"] = "POS_PROTECTION",
    ["Protection buffs X position"] = "COMMON_POSITION_X",
    ["Protection buffs Y position"] = "COMMON_POSITION_Y",
    ["Protection major icon size"] = "COMMON_MAJOR_ICON_SIZE",
    ["Protection major number size"] = "COMMON_MAJOR_NUMBER_SIZE",
    ["Protection minor icon size"] = "COMMON_MINOR_ICON_SIZE",
    ["Protection minor number size"] = "COMMON_MINOR_NUMBER_SIZE",
    ["Protection: Major above Minor"] = "COMMON_MAJOR_ABOVE_MINOR",
    ["Reset Arcanist Beam timer position"] = "COMMON_RESET_POSITION",
    ["Reset Backlash timer position"] = "COMMON_RESET_POSITION",
    ["Reset Bound Armaments stacks position"] = "COMMON_RESET_POSITION",
    ["Reset Breach pair position"] = "COMMON_RESET_POSITION",
    ["Reset Breath timer position"] = "COMMON_RESET_POSITION",
    ["Reset Corpse Detector position"] = "COMMON_RESET_POSITION",
    ["Reset Crux stacks position"] = "COMMON_RESET_POSITION",
    ["Reset Crystal tracker position"] = "COMMON_RESET_POSITION",
    ["Reset Damage Shield position"] = "COMMON_RESET_POSITION",
    ["Reset Empowered Fly indicator position"] = "COMMON_RESET_POSITION",
    ["Reset Grim Focus stacks position"] = "COMMON_RESET_POSITION",
    ["Reset Heroism buffs position"] = "COMMON_RESET_POSITION",
    ["Reset Maelstrom timer position"] = "COMMON_RESET_POSITION",
    ["Reset Mending buffs position"] = "COMMON_RESET_POSITION",
    ["Reset Protection buffs position"] = "COMMON_RESET_POSITION",
    ["Reset Resolve buffs position"] = "COMMON_RESET_POSITION",
    ["Reset Rune Focus area position"] = "COMMON_RESET_POSITION",
    ["Reset Shalk timer position"] = "COMMON_RESET_POSITION",
    ["Reset Skull stacks position"] = "COMMON_RESET_POSITION",
    ["Reset Taunt position"] = "COMMON_RESET_POSITION",
    ["Reset Templar Beam timer position"] = "COMMON_RESET_POSITION",
    ["Reset This Position"] = "COMMON_RESET_POSITION",
    ["Reset Ultimate tracker position"] = "COMMON_RESET_POSITION",
    ["Reset Vitality buffs position"] = "COMMON_RESET_POSITION",
    ["Reset Vulnerability pair position"] = "COMMON_RESET_POSITION",
    ["Reset Warrior's Opportunity timer position"] = "COMMON_RESET_POSITION",
    ["Reset Whip stacks position"] = "COMMON_RESET_POSITION",
    ["Reset all positions"] = "COMMON_RESET_ALL",
    ["Reset {label} position"] = "RESET_TARGET",
    ["Resolve buffs"] = "POS_RESOLVE",
    ["Resolve buffs X position"] = "COMMON_POSITION_X",
    ["Resolve buffs Y position"] = "COMMON_POSITION_Y",
    ["Resolve major icon size"] = "COMMON_MAJOR_ICON_SIZE",
    ["Resolve major number size"] = "COMMON_MAJOR_NUMBER_SIZE",
    ["Resolve minor icon size"] = "COMMON_MINOR_ICON_SIZE",
    ["Resolve minor number size"] = "COMMON_MINOR_NUMBER_SIZE",
    ["Resolve: Major above Minor"] = "COMMON_MAJOR_ABOVE_MINOR",
    ["Rune Focus area"] = "POS_TPL_RUNE",
    ["Rune Focus area X position"] = "COMMON_POSITION_X",
    ["Rune Focus area Y position"] = "COMMON_POSITION_Y",
    ["Rune Focus, Channeled Focus and Restoring Focus: see whether you're standing inside your placed rune. A position indicator, not a countdown."] = "TPL_RUNE_DESC",
    ["Rune icon size"] = "COMMON_ICON_SIZE",
    ["See how much time is left on your taunt against the enemy you're aiming at. Yellow means it's time to refresh; red means it's almost gone."] = "TANK_TAUNT_DESC",
    ["See the remaining time on your strongest active damage shield, including shields from allies. When there's no shield, the display steps aside."] = "TANK_SHIELD_DESC",
    ["See when your magicka-version Empowered Fetcher effect is ready. The stamina morph isn't tracked; there is no countdown here."] = "WARDEN_FLY_DESC",
    ["See when your outgoing healing gets a boost from Major or Minor Mending. Timed effects count down; permanent ones can show quietly."] = "BUFF_MENDING_DESC",
    ["See whether your current target has Major or Minor Vulnerability. Each grade has its own place, so you can read them at a glance."] = "DEBUFF_VULN_DESC",
    ["See your Ultimate charge and its ready glow. Both bars can show together; with a single row, the displayed Ultimate follows your weapon swap. You can also hide the HUD while Shattered Paths Signet is equipped."] = "ULT_DESC",
    ["Shalk icon size"] = "COMMON_ICON_SIZE",
    ["Shalk text size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Shalk timer"] = "POS_SHALK",
    ["Shalk timer X position"] = "COMMON_POSITION_X",
    ["Shalk timer Y position"] = "COMMON_POSITION_Y",
    ["Shield icon size"] = "COMMON_ICON_SIZE",
    ["Shield number size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Show a permanent/no-expiry version as an icon without a timer. Timed sources remain visible. Does not identify the skill or source as passive."] = "COMMON_PERMANENT_TOOLTIP",
    ["Show back bar"] = "ULT_SHOW_BACK_BAR",
    ["Show front bar"] = "ULT_SHOW_FRONT_BAR",
    ["Show no-expiry Major Heroism"] = "COMMON_MAJOR_PASSIVE",
    ["Show no-expiry Major Mending"] = "COMMON_MAJOR_PASSIVE",
    ["Show no-expiry Major Protection"] = "COMMON_MAJOR_PASSIVE",
    ["Show no-expiry Major Resolve"] = "COMMON_MAJOR_PASSIVE",
    ["Show no-expiry Major Vitality"] = "COMMON_MAJOR_PASSIVE",
    ["Show no-expiry Minor Heroism"] = "COMMON_MINOR_PASSIVE",
    ["Show no-expiry Minor Mending"] = "COMMON_MINOR_PASSIVE",
    ["Show no-expiry Minor Protection"] = "COMMON_MINOR_PASSIVE",
    ["Show no-expiry Minor Resolve"] = "COMMON_MINOR_PASSIVE",
    ["Show no-expiry Minor Vitality"] = "COMMON_MINOR_PASSIVE",
    ["Skull icon size"] = "COMMON_ICON_SIZE",
    ["Skull number size"] = "COMMON_STACK_NUMBER_SIZE",
    ["Skull stacks"] = "POS_SKULL",
    ["Skull stacks X position"] = "COMMON_POSITION_X",
    ["Skull stacks Y position"] = "COMMON_POSITION_Y",
    ["Sora Reticle Tracker"] = "APP_NAME",
    ["Sora Reticle Tracker - CLASS SKILLS"] = "MENU_CLASS",
    ["Sora Reticle Tracker - DEBUFFS"] = "MENU_DEBUFF",
    ["Sora Reticle Tracker - TANK & SUPPORT"] = "MENU_TANK",
    ["Sora Reticle Tracker - ULTIMATE"] = "MENU_ULT",
    ["Sora Reticle Tracker - WEAPON SKILLS"] = "MENU_WEAPON",
    ["Sorcerer — Bound Armaments"] = "SORC_BOUND_TITLE",
    ["Sorcerer — Crystal Fragments"] = "SORC_CRYSTAL_TITLE",
    ["Stay on top of Ultimate generation with Major and Minor Heroism. Both can appear independently; timeless versions show without numbers."] = "BUFF_HEROISM_DESC",
    ["Stop move mode"] = "COMMON_STOP_MOVING",
    ["Stop moving"] = "COMMON_STOP_MOVING",
    ["Tank"] = "ROLE_TANK",
    ["Tank — Damage Shield"] = "TANK_SHIELD_TITLE",
    ["Tank — Damage shields"] = "TANK_SHIELD_TITLE",
    ["Tank — Guard Indicator"] = "TANK_GUARD_TITLE",
    ["Tank — Heroism (Major / Minor)"] = "BUFF_HEROISM_TITLE",
    ["Tank — Mending (Support)"] = "BUFF_MENDING_TITLE",
    ["Tank — Protection (Major / Minor)"] = "BUFF_PROTECTION_TITLE",
    ["Tank — Resolve (Major / Minor)"] = "BUFF_TANKRESOLVE_TITLE",
    ["Debuffs — Taunt — Target"] = "TANK_TAUNT_TITLE",
    ["Tank — Vitality (Support)"] = "BUFF_VITALITY_TITLE",
    ["Tank — Evasion (Support)"] = "BUFF_EVASION_TITLE",
    ["Track your Major and Minor Evasion buffs from any source. Timed effects count down, and permanent effects show an icon."] = "BUFF_EVASION_DESC",
    ["Tank — Gladiator's Tenacity (Support)"] = "SUPPORT_GLADIATOR_TITLE",
    ["Damage-reduction timer from Ulfsild's Contingency."] = "SUPPORT_GLADIATOR_DESC",
    ["Gladiator icon size"] = "COMMON_ICON_SIZE",
    ["Gladiator number size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Move Gladiator's Tenacity"] = "COMMON_MOVE_DISPLAY",
    ["Taunt"] = "POSITION_TAUNT",
    ["Taunt X position"] = "COMMON_POSITION_X",
    ["Taunt Y position"] = "COMMON_POSITION_Y",
    ["Templar Beam timer"] = "POS_TPL_BEAM",
    ["Templar Beam timer X position"] = "COMMON_POSITION_X",
    ["Templar Beam timer Y position"] = "COMMON_POSITION_Y",
    ["Templar beam icon size"] = "COMMON_ICON_SIZE",
    ["Templar beam number size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Templar — Backlash"] = "TPL_BACKLASH_TITLE",
    ["Templar — Execute beam"] = "TPL_BEAM_TITLE",
    ["Templar — Rune Focus"] = "TPL_RUNE_TITLE",
    ["Throw Traveling Knife with Warrior's Opportunity and watch its 5-second window count down at your reticle."] = "WPN_WARRIOR_DESC",
    ["Thunderous Volley — Endless Hail"] = "WPN_MAEL_THUNDEROUS_VOLLEY_ENDLESS_HAIL",
    ["Traveling Knife — Warrior’s Opportunity"] = "WPN_WARRIOR_TITLE",
    ["Ultimate"] = "ULT_TITLE",
    ["Ultimate size"] = "COMMON_DISPLAY_SIZE",
    ["Ultimate tracker"] = "POS_ULT",
    ["Ultimate tracker X position"] = "COMMON_POSITION_X",
    ["Ultimate tracker Y position"] = "COMMON_POSITION_Y",
    ["Use when your gear changes blocking to Magicka rather than Stamina."] = "TANK_GUARD_TOOLTIP_USE_WHEN_YOUR_GEAR_CHANGES_BLOCKING_TO_MAGICKA_RATHER_T",
    ["Vitality buffs"] = "POS_VITALITY",
    ["Vitality buffs X position"] = "COMMON_POSITION_X",
    ["Vitality buffs Y position"] = "COMMON_POSITION_Y",
    ["Vitality major icon size"] = "COMMON_MAJOR_ICON_SIZE",
    ["Vitality major number size"] = "COMMON_MAJOR_NUMBER_SIZE",
    ["Vitality minor icon size"] = "COMMON_MINOR_ICON_SIZE",
    ["Vitality minor number size"] = "COMMON_MINOR_NUMBER_SIZE",
    ["Vitality: Major above Minor"] = "COMMON_MAJOR_ABOVE_MINOR",
    ["Vulnerability pair"] = "POSITION_VULN_PAIR",
    ["Vulnerability pair X position"] = "COMMON_POSITION_X",
    ["Vulnerability pair Y position"] = "COMMON_POSITION_Y",
    ["Warden — Empowered Fetcher"] = "WARDEN_FLY_TITLE",
    ["Warden — Empowered Fly"] = "WARDEN_FLY_TITLE",
    ["Warden — Shalk"] = "WARDEN_SHALK_TITLE",
    ["Warrior's Opportunity icon size"] = "COMMON_ICON_SIZE",
    ["Warrior's Opportunity timer"] = "POS_WARRIOR",
    ["Warrior's Opportunity timer X position"] = "COMMON_POSITION_X",
    ["Warrior's Opportunity timer Y position"] = "COMMON_POSITION_Y",
    ["Warrior's Opportunity timer size"] = "COMMON_TIMER_NUMBER_SIZE",
    ["Watch Major and Minor Protection when you're bracing for damage. Separate icons keep both grades easy to see, even when one has no timer."] = "BUFF_PROTECTION_DESC",
    ["Watch Seething Fury build up! Whip stacks turn yellow at 1–2 and red at 3, so your next heavy hit is easy to spot."] = "DK_WHIP_DESC",
    ["Watch your execute beam's remaining channel time, so you can see when the current beam is about to finish."] = "TPL_BEAM_DESC",
    ["Watch your summoned daggers pile up! The stack number turns gold at 3 and red at 4 or more - time to strike."] = "SORC_BOUND_DESC",
    ["Whip icon size"] = "COMMON_ICON_SIZE",
    ["Whip number size"] = "COMMON_STACK_NUMBER_SIZE",
    ["Whip stacks"] = "POS_WHIP",
    ["Whip stacks X position"] = "COMMON_POSITION_X",
    ["Whip stacks Y position"] = "COMMON_POSITION_Y",
    ["Your bow shot is getting ready! Relentless Focus turns orange at 3 stacks and red at 4; Merciless Resolve / Grim Focus turns orange at 4 and red at 5."] = "NB_GRIM_DESC",
    ["Your spectral bow is charging! Relentless Focus turns orange at 3 stacks and red at 4; Merciless Resolve / Grim Focus turns orange at 4 and red at 5."] = "NB_GRIM_DESC",
    ["[ ] {role}"] = "ROLE_OFF",
    ["[x] {role}"] = "ROLE_ON",
    ["{label} X position"] = "POSITION_X",
    ["{label} Y position"] = "POSITION_Y",
}
local function UiText(key)
    local ui = SSRT.L and SSRT.L.ui
    return ui and ui[key] or key
end
local function UiLabel(english)
    -- These six labels are built dynamically for the shared attack-buff widgets.
    for _, label in ipairs({"Berserk", "Brutality", "Savagery", "Force", "Slayer", "Evasion"}) do
        if english == "Show no-expiry Major "..label then return UiText("COMMON_MAJOR_PASSIVE") end
        if english == "Show no-expiry Minor "..label then return UiText("COMMON_MINOR_PASSIVE") end
        if english == label..": Major above Minor" then return UiText("COMMON_MAJOR_ABOVE_MINOR") end
        if english == label.." major icon size" then return UiText("COMMON_MAJOR_ICON_SIZE") end
        if english == label.." minor icon size" then return UiText("COMMON_MINOR_ICON_SIZE") end
        if english == label.." major number size" then return UiText("COMMON_MAJOR_NUMBER_SIZE") end
        if english == label.." minor number size" then return UiText("COMMON_MINOR_NUMBER_SIZE") end
    end
    if english == "Evasion major icon size" then return UiText("COMMON_MAJOR_ICON_SIZE") end
    if english == "Evasion major number size" then return UiText("COMMON_MAJOR_NUMBER_SIZE") end
    if english == "Evasion minor icon size" then return UiText("COMMON_MINOR_ICON_SIZE") end
    if english == "Evasion minor number size" then return UiText("COMMON_MINOR_NUMBER_SIZE") end
    local key = MENU_LABEL_KEYS[english]
    return key and UiText(key) or english
end
local function LocalizeControl(control)
    if control.name and type(control.name) == "string" then
        control.name = UiLabel(control.name)
    end
    if control.text and type(control.text) == "string" then
        control.text = UiLabel(control.text)
    end
    if control.tooltip and type(control.tooltip) == "string" then
        control.tooltip = UiLabel(control.tooltip)
    end
    if control.controls then
        for _, child in ipairs(control.controls) do LocalizeControl(child) end
    end
end
local function LocalizeOptionList(controls)
    for _, control in ipairs(controls) do LocalizeControl(control) end
end

local function PositionOptions(key, label, apply)
    local controls = {}
    for _, axis in ipairs({"X", "Y"}) do
        local field = key .. "Offset" .. axis
        controls[#controls + 1] = {
            type = "slider", name = UiText("COMMON_POSITION_" .. axis),
            min = axis == "X" and -1000 or -700,
            max = axis == "X" and 1000 or 700,
            step = 1, decimals = 0, autoSelect = true,
            tooltip = UiText("POSITION_TIP"),
            getFunc = function() return SSRT.sv[field] end,
            setFunc = function(value)
                SSRT.sv[field] = zo_round(value)
                apply()
            end,
            default = defaults[field], width = "full",
        }
    end
    return controls
end

local function RegisterSettings()
    local LAM = LibAddonMenu2
    local panelName = ADDON_NAME .. "Options"

    local options = {
        { type = "header", name = "Debuffs — Taunt — Target" },
        { type = "description", text = "See how much time is left on your taunt against the enemy you're aiming at. Yellow means it's time to refresh; red means it's almost gone." },
        { type = "checkbox", name = "ON", width = "full", getFunc=function() return SSRT.sv.debuffTauntEnabled end,
            setFunc=function(v) SSRT.sv.debuffTauntEnabled=v end, default=true },
        { type = "slider", name = "Taunt number size", min=14,max=56,step=1,width="full",default=24,
          getFunc=function() return SSRT.sv.debuffTauntTextSize end,
          setFunc=function(v) SSRT.sv.debuffTauntTextSize=v; ApplyTargetDebuffSizes() end },
        { type = "header", name = "Debuffs — Breach — Target" },
        { type = "description", text = "Keep Major and Minor Breach in sight on your current target, including effects placed by allies. Their two icons stay put when one disappears." },
        { type = "checkbox", name = "Major Breach", width = "half",getFunc=function() return SSRT.sv.debuffBreachMajorEnabled end,
            setFunc=function(v) SSRT.sv.debuffBreachMajorEnabled=v end,default=true },
        { type = "checkbox", name = "Minor Breach", width = "half",getFunc=function() return SSRT.sv.debuffBreachMinorEnabled end,
            setFunc=function(v) SSRT.sv.debuffBreachMinorEnabled=v end,default=true },
        { type = "checkbox", name = "Major Breach above Minor",width="full",getFunc=function() return SSRT.sv.debuffBreachMajorOnTop end,
            setFunc=function(v) SSRT.sv.debuffBreachMajorOnTop=v end,default=true },
        { type = "slider", name = "Major effect icon size", min=20, max=90, step=2, width="full",default=48,
          getFunc=function() return SSRT.sv.debuffBreachMajorSize end,
          setFunc=function(v) SSRT.sv.debuffBreachMajorSize=v; ApplyTargetDebuffSizes() end },
        { type = "slider", name = "Major effect number size", min=14,max=56,step=1,width="full",default=24,
          getFunc=function() return SSRT.sv.debuffBreachMajorTextSize end,
          setFunc=function(v) SSRT.sv.debuffBreachMajorTextSize=v; ApplyTargetDebuffSizes() end },
        { type = "slider", name = "Minor effect icon size", min=20, max=90, step=2, width="full",default=36,
          getFunc=function() return SSRT.sv.debuffBreachMinorSize end,
          setFunc=function(v) SSRT.sv.debuffBreachMinorSize=v; ApplyTargetDebuffSizes() end },
        { type = "slider", name = "Minor effect number size", min=14,max=56,step=1,width="full",default=24,
          getFunc=function() return SSRT.sv.debuffBreachMinorTextSize end,
          setFunc=function(v) SSRT.sv.debuffBreachMinorTextSize=v; ApplyTargetDebuffSizes() end },
        { type = "header", name = "Debuffs — Vulnerability — Target" },
        { type = "description", text = "See whether your current target has Major or Minor Vulnerability. Each grade has its own place, so you can read them at a glance." },
        { type = "checkbox", name = "Major Vulnerability",width="half",getFunc=function() return SSRT.sv.debuffVulnerabilityMajorEnabled end,
            setFunc=function(v) SSRT.sv.debuffVulnerabilityMajorEnabled=v end,default=true },
        { type = "checkbox", name = "Minor Vulnerability",width="half",getFunc=function() return SSRT.sv.debuffVulnerabilityMinorEnabled end,
            setFunc=function(v) SSRT.sv.debuffVulnerabilityMinorEnabled=v end,default=true },
        { type = "checkbox", name = "Major Vulnerability above Minor",width="full",getFunc=function() return SSRT.sv.debuffVulnerabilityMajorOnTop end,
            setFunc=function(v) SSRT.sv.debuffVulnerabilityMajorOnTop=v end,default=true },

        { type = "slider", name = "Major effect icon size", min=20, max=90, step=2, width="full",default=48,
          getFunc=function() return SSRT.sv.debuffVulnerabilityMajorSize end,
          setFunc=function(v) SSRT.sv.debuffVulnerabilityMajorSize=v; ApplyTargetDebuffSizes() end },
        { type = "slider", name = "Major effect number size", min=14,max=56,step=1,width="full",default=24,
          getFunc=function() return SSRT.sv.debuffVulnerabilityMajorTextSize end,
          setFunc=function(v) SSRT.sv.debuffVulnerabilityMajorTextSize=v; ApplyTargetDebuffSizes() end },
        { type = "slider", name = "Minor effect icon size", min=20, max=90, step=2, width="full",default=36,
          getFunc=function() return SSRT.sv.debuffVulnerabilityMinorSize end,
          setFunc=function(v) SSRT.sv.debuffVulnerabilityMinorSize=v; ApplyTargetDebuffSizes() end },
        { type = "slider", name = "Minor effect number size", min=14,max=56,step=1,width="full",default=24,
          getFunc=function() return SSRT.sv.debuffVulnerabilityMinorTextSize end,
          setFunc=function(v) SSRT.sv.debuffVulnerabilityMinorTextSize=v; ApplyTargetDebuffSizes() end },
        { type = "header", name = "Tank — Guard Indicator" },
        { type = "description", text = "A quick sign that you're blocking: green for Stamina, cyan for Magicka. Frost Staff / Tri Focus and special gear can change the resource you guard with." },
        { type = "checkbox", name = "ON", width = "full",getFunc=function() return SSRT.sv.guardIndicatorEnabled end,setFunc=function(v) SSRT.sv.guardIndicatorEnabled=v;UpdateUI() end,default=true },
        { type = "slider", name = "Guard outline size",min=40,max=140,step=2,width="full",getFunc=function() return SSRT.sv.guardSize end,setFunc=function(v) SSRT.sv.guardSize=v;ApplyGuardPosition() end,default=80 },
        { type = "button", name = "Move Guard Indicator",width="half",func=function() SetMoveTarget("guardIndicator") end },
        { type = "slider", name = "Guard position X",min=-300,max=300,step=1,width="full",getFunc=function() return SSRT.sv.guardOffsetX end,setFunc=function(v) SSRT.sv.guardOffsetX=v;ApplyGuardPosition() end,default=0 },
        { type = "slider", name = "Guard position Y",min=-300,max=300,step=1,width="full",getFunc=function() return SSRT.sv.guardOffsetY end,setFunc=function(v) SSRT.sv.guardOffsetY=v;ApplyGuardPosition() end,default=0 },
        { type = "button", name = "Reset This Position",width="half",func=function() SSRT.sv.guardOffsetX=0;SSRT.sv.guardOffsetY=0;ApplyGuardPosition() end },
        { type = "header", name = "Tank — Damage shields" },
        { type = "description", text = "See the remaining time on your strongest active damage shield, including shields from allies. When there's no shield, the display steps aside." },
        { type = "checkbox", name = "ON", width="full", default=true,
          getFunc=function() return SSRT.sv.shieldEnabled end,
          setFunc=function(v) SSRT.sv.shieldEnabled=v; SSRT.Shield.Invalidate(); UpdateUI() end },
        { type = "slider", name = "Shield icon size", min=40,max=140,step=2,width="full",default=78,
          getFunc=function() return SSRT.sv.shieldIconSize end,
          setFunc=function(v) SSRT.sv.shieldIconSize=v; ApplyVisualSettings() end },
        { type = "slider", name = "Shield number size", min=14,max=56,step=1,width="full",default=35,
          getFunc=function() return SSRT.sv.shieldTextSize end,
          setFunc=function(v) SSRT.sv.shieldTextSize=v; ApplyVisualSettings() end },
        { type = "button", name = "Move Damage Shield timer",width="half",
          func=function() SetMoveTarget("shield") end },
        { type = "button", name = "Reset This Position",width="half",
          func=function()
              SSRT.sv.shieldOffsetX=defaults.shieldOffsetX
              SSRT.sv.shieldOffsetY=defaults.shieldOffsetY
              SSRT.Shield.ApplyPosition()
          end },
        { type = "header", name = "Dragonknight — Whip" },
        { type = "description", text = "Feel Seething Fury build! Your whip stacks turn warm yellow at 1-2 and red at 3, so the big hit is easy to spot." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.dkWhipEnabled end,
          setFunc = function(v) SSRT.sv.dkWhipEnabled = v end, default = defaults.dkWhipEnabled, width = "full" },
        { type = "slider", name = "Whip icon size", min = 40, max = 140, step = 2,
          getFunc = function() return SSRT.sv.dkWhipIconSize end,
          setFunc = function(v) SSRT.sv.dkWhipIconSize = v; ApplyVisualSettings() end, default = defaults.dkWhipIconSize, width = "full" },
        { type = "slider", name = "Whip number size", min = 14, max = 56, step = 1,
          getFunc = function() return SSRT.sv.dkWhipTextSize end,
          setFunc = function(v) SSRT.sv.dkWhipTextSize = v; ApplyVisualSettings() end, default = defaults.dkWhipTextSize, width = "full" },
        { type = "button", name = "Move Whip stacks", func = function() SetMoveTarget("dkWhip") end, width = "half" },
        { type = "button", name = "Reset This Position", func = function()
            SSRT.sv.dkWhipOffsetX = defaults.dkWhipOffsetX
            SSRT.sv.dkWhipOffsetY = defaults.dkWhipOffsetY
            ApplyDKPositions()
        end, width = "half" },
        { type = "header", name = "Dragonknight — Breath" },
        { type = "description", text = "Keep an eye on the remaining time of the tracked Breath effect. Its countdown tells you when it's time to use Breath again." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.dkBreathEnabled end,
          setFunc = function(v) SSRT.sv.dkBreathEnabled = v end, default = defaults.dkBreathEnabled, width = "full" },
        { type = "slider", name = "Breath icon size", min = 40, max = 140, step = 2,
          getFunc = function() return SSRT.sv.dkBreathIconSize end,
          setFunc = function(v) SSRT.sv.dkBreathIconSize = v; ApplyVisualSettings() end, default = defaults.dkBreathIconSize, width = "full" },
        { type = "slider", name = "Breath number size", min = 14, max = 56, step = 1,
          getFunc = function() return SSRT.sv.dkBreathTextSize end,
          setFunc = function(v) SSRT.sv.dkBreathTextSize = v; ApplyVisualSettings() end, default = defaults.dkBreathTextSize, width = "full" },
        { type = "button", name = "Move Breath timer", func = function() SetMoveTarget("dkBreath") end, width = "half" },
        { type = "button", name = "Reset This Position", func = function()
            SSRT.sv.dkBreathOffsetX = defaults.dkBreathOffsetX
            SSRT.sv.dkBreathOffsetY = defaults.dkBreathOffsetY
            ApplyDKPositions()
        end, width = "half" },
        { type = "header", name = "Dragonknight — Core of Flame" },
        { type = "description", text = "Tracks the 4-second resource recovery of Core of Flame, Heart of Flame, and Soul of Flame after casting. This is a cast-based support timer." },
        { type = "checkbox", name = "ON", width = "full", default = true,
          getFunc = function() return SSRT.sv.dkCoreEnabled end,
          setFunc = function(v) SSRT.sv.dkCoreEnabled = v end },
        { type = "slider", name = "Core icon size", min = 40, max = 140, step = 2, width = "full", default = defaults.dkCoreIconSize,
          getFunc = function() return SSRT.sv.dkCoreIconSize end,
          setFunc = function(v) SSRT.sv.dkCoreIconSize = v; ApplyVisualSettings() end },
        { type = "slider", name = "Core number size", min = 14, max = 56, step = 1, width = "full", default = defaults.dkCoreTextSize,
          getFunc = function() return SSRT.sv.dkCoreTextSize end,
          setFunc = function(v) SSRT.sv.dkCoreTextSize = v; ApplyVisualSettings() end },
        { type = "button", name = "Move Core of Flame timer", width = "half", func = function() SetMoveTarget("dkCore") end },
        { type = "button", name = "Reset This Position", width = "half", func = function()
            SSRT.sv.dkCoreOffsetX = defaults.dkCoreOffsetX
            SSRT.sv.dkCoreOffsetY = defaults.dkCoreOffsetY
            ApplyDKPositions()
        end },
        {
            type = "header",
            name = "Sorcerer — Crystal Fragments",
        },
        { type = "description", text = "Crystal Fragments proc and Crystal Weapon charges share one HUD position. See which effect is ready without watching two separate icons." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.crystalEnabled end,
          setFunc = function(value) SSRT.sv.crystalEnabled = value end, default = defaults.crystalEnabled, width = "full" },
        {
            type = "checkbox",
            name = "Block Crystal Fragments without proc (silent)",
            tooltip = "Optional: requires LibSkillBlocker 1.1.0 or later. Only allow Crystal Fragments with its proc active. Default OFF.",
            getFunc = function() return SSRT.sv.crystalSilentBlockEnabled end,
            setFunc = function(value)
                SSRT.sv.crystalSilentBlockEnabled = value
                ApplyCrystalSilentBlock()
            end,
            default = defaults.crystalSilentBlockEnabled,
            width = "full",
        },
        {
            type = "slider",
            name = "Crystal icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.crystalIconSize end,
            setFunc = function(value)
                SSRT.sv.crystalIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.crystalIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Crystal timer size",
            min = 14,
            max = 56,
            step = 1,
            getFunc = function() return SSRT.sv.crystalTextSize end,
            setFunc = function(value)
                SSRT.sv.crystalTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.crystalTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Crystal tracker",
            func = function() SetMoveTarget("crystal") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset This Position",
            func = function()
                SSRT.sv.crystalOffsetX = defaults.crystalOffsetX
                SSRT.sv.crystalOffsetY = defaults.crystalOffsetY
                ApplyCrystalPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Sorcerer — Bound Armaments",
        },
        { type = "description", text = "Watch your summoned daggers pile up! The stack number turns gold at 3 and red at 4 or more - time to strike." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.boundEnabled end,
          setFunc = function(value) SSRT.sv.boundEnabled = value end, default = defaults.boundEnabled, width = "full" },
        {
            type = "slider",
            name = "Bound icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.boundIconSize end,
            setFunc = function(value)
                SSRT.sv.boundIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.boundIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Bound stack text size",
            min = 14,
            max = 56,
            step = 1,
            getFunc = function() return SSRT.sv.boundTextSize end,
            setFunc = function(value)
                SSRT.sv.boundTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.boundTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Bound Armaments stacks",
            func = function() SetMoveTarget("bound") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset This Position",
            func = function()
                SSRT.sv.boundOffsetX = defaults.boundOffsetX
                SSRT.sv.boundOffsetY = defaults.boundOffsetY
                ApplyBoundPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Nightblade — Grim Focus",
        },
        { type = "description", text = "Your bow shot is getting ready! Relentless Focus turns orange at 3 stacks and red at 4; Merciless Resolve / Grim Focus turns orange at 4 and red at 5." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.nightbladeEnabled end,
          setFunc = function(value) SSRT.sv.nightbladeEnabled = value end, default = defaults.nightbladeEnabled, width = "full" },
        {
            type = "slider",
            name = "Nightblade icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.nightbladeIconSize end,
            setFunc = function(value)
                SSRT.sv.nightbladeIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.nightbladeIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Nightblade stack text size",
            min = 14,
            max = 56,
            step = 1,
            getFunc = function() return SSRT.sv.nightbladeTextSize end,
            setFunc = function(value)
                SSRT.sv.nightbladeTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.nightbladeTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Grim Focus stacks",
            func = function() SetMoveTarget("nightblade") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset This Position",
            func = function()
                SSRT.sv.nightbladeOffsetX = defaults.nightbladeOffsetX
                SSRT.sv.nightbladeOffsetY = defaults.nightbladeOffsetY
                ApplyNightbladePosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Templar — Backlash",
        },
        { type = "description", text = "Keep track of the 6-second buildup from Power of the Light or Purifying Light, right up to the final burst." },
        {
            type = "checkbox",
            name = "ON",
            getFunc = function() return SSRT.sv.backlashEnabled end,
            setFunc = function(value)
                SSRT.sv.backlashEnabled = value
                if not value then
                    SSRT.backlashEndTime = 0
                    SSRT.backlashWindow:SetHidden(true)
                end
            end,
            default = defaults.backlashEnabled,
            width = "full",
        },
        {
            type = "slider", name = "Backlash icon size",
            min = 40, max = 140, step = 2,
            getFunc = function() return SSRT.sv.backlashIconSize end,
            setFunc = function(value) SSRT.sv.backlashIconSize = value; ApplyVisualSettings() end,
            default = defaults.backlashIconSize, width = "full",
        },
        {
            type = "slider",
            name = "Backlash timer text size",
            min = 14, max = 56, step = 1,
            getFunc = function() return SSRT.sv.backlashTextSize end,
            setFunc = function(value)
                SSRT.sv.backlashTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.backlashTextSize,
            width = "full",
        },
        {
            type = "button", name = "Move Backlash timer",
            func = function() SetMoveTarget("backlash") end,
            width = "half",
        },
        {
            type = "button", name = "Reset This Position",
            func = function()
                SSRT.sv.backlashOffsetX = defaults.backlashOffsetX
                SSRT.sv.backlashOffsetY = defaults.backlashOffsetY
                ApplyBacklashPosition()
            end,
            width = "half",
        },
        { type = "header", name = "Templar — Execute beam" },
        { type = "description", text = "Watch your execute beam's remaining channel time, so you can see when the current beam is about to finish." },
        { type = "checkbox", name = "ON", width = "full",
          getFunc = function() return SSRT.sv.templarBeamEnabled end,
          setFunc = function(v) SSRT.sv.templarBeamEnabled = v; if not v then SSRT.templarBeamEnd = 0 end end,
          default = defaults.templarBeamEnabled },
        { type = "slider", name = "Templar beam icon size", min = 40, max = 140, step = 2, width = "full",
          getFunc = function() return SSRT.sv.templarBeamIconSize end,
          setFunc = function(v) SSRT.sv.templarBeamIconSize = v; ApplyVisualSettings() end,
          default = defaults.templarBeamIconSize },
        { type = "slider", name = "Templar beam number size", min = 14, max = 56, step = 1, width = "full",
          getFunc = function() return SSRT.sv.templarBeamTextSize end,
          setFunc = function(v) SSRT.sv.templarBeamTextSize = v; ApplyVisualSettings() end,
          default = defaults.templarBeamTextSize },
        { type = "button", name = "Move Templar Beam timer", width = "half",
          func = function() SetMoveTarget("templarBeam") end },
        { type = "button", name = "Reset This Position", width = "half",
          func = function()
              SSRT.sv.templarBeamOffsetX = defaults.templarBeamOffsetX
              SSRT.sv.templarBeamOffsetY = defaults.templarBeamOffsetY
              ApplyTemplarBeamPosition()
          end },
        { type = "header", name = "Templar — Rune Focus" },
        { type = "description", text = "Rune Focus, Channeled Focus and Restoring Focus: see whether you're standing inside your placed rune. A position indicator, not a countdown." },
        { type = "checkbox", name = "ON", width = "full",
          getFunc = function() return SSRT.sv.templarRuneEnabled end,
          setFunc = function(v) SSRT.sv.templarRuneEnabled = v end, default = defaults.templarRuneEnabled },
        { type = "slider", name = "Rune icon size", min = 40, max = 140, step = 2,
          getFunc = function() return SSRT.sv.templarRuneIconSize end,
          setFunc = function(v) SSRT.sv.templarRuneIconSize = v; ApplyVisualSettings() end,
          default = defaults.templarRuneIconSize },
        { type = "button", name = "Move Rune Focus area", width = "half",
          func = function() SetMoveTarget("templarRune") end },
        { type = "button", name = "Reset This Position", width = "half",
          func = function()
              SSRT.sv.templarRuneOffsetX = defaults.templarRuneOffsetX
              SSRT.sv.templarRuneOffsetY = defaults.templarRuneOffsetY
              ApplyDKPositions()
          end },
        { type = "header", name = "Warden — Shalk",
        },
        { type = "description", text = "Follow both Shalk hits from Deep Fissure or Subterranean Assault, not just a total timer. The first and second hit timings stay visible." },
        {
            type = "checkbox", name = "ON",
            getFunc = function() return SSRT.sv.wardenEnabled end,
            setFunc = function(value)
                SSRT.sv.wardenEnabled = value
                if not value then SSRT.wardenWindow:SetHidden(true) end
            end,
            default = defaults.wardenEnabled, width = "full",
        },
        {
            type = "slider", name = "Shalk icon size", min = 40, max = 140, step = 2,
            getFunc = function() return SSRT.sv.wardenIconSize end,
            setFunc = function(value) SSRT.sv.wardenIconSize = value; ApplyVisualSettings() end,
            default = defaults.wardenIconSize, width = "full",
        },
        {
            type = "slider", name = "Shalk text size", min = 14, max = 56, step = 1,
            getFunc = function() return SSRT.sv.wardenTextSize end,
            setFunc = function(value) SSRT.sv.wardenTextSize = value; ApplyVisualSettings() end,
            default = defaults.wardenTextSize, width = "full",
        },
        {
            type = "button", name = "Move Shalk timer",
            func = function() SetMoveTarget("warden") end, width = "half",
        },
        {
            type = "button", name = "Reset This Position",
            func = function()
                SSRT.sv.wardenOffsetX = defaults.wardenOffsetX
                SSRT.sv.wardenOffsetY = defaults.wardenOffsetY
                ApplyWardenPosition()
            end, width = "half",
        },
        { type = "header", name = "Warden — Empowered Fly" },
        { type = "description", text = "See when your magicka-version Empowered Fetcher effect is ready. The stamina morph isn't tracked; there is no countdown here." },
        { type = "checkbox", name = "ON", width = "full",
          getFunc = function() return SSRT.sv.wardenFlyEnabled end,
          setFunc = function(v) SSRT.sv.wardenFlyEnabled = v end, default = defaults.wardenFlyEnabled },
        { type = "slider", name = "Fly icon size", min = 40, max = 140, step = 2,
          getFunc = function() return SSRT.sv.wardenFlyIconSize end,
          setFunc = function(v) SSRT.sv.wardenFlyIconSize = v; ApplyVisualSettings() end,
          default = defaults.wardenFlyIconSize },
        { type = "button", name = "Move Empowered Fly indicator", width = "half",
          func = function() SetMoveTarget("wardenFly") end },
        { type = "button", name = "Reset This Position", width = "half",
          func = function()
              SSRT.sv.wardenFlyOffsetX = defaults.wardenFlyOffsetX
              SSRT.sv.wardenFlyOffsetY = defaults.wardenFlyOffsetY
              ApplyDKPositions()
          end },
        { type = "header", name = "Necromancer — Skull stacks" },
        { type = "description", text = "Build toward your empowered Skull! Tracks Flame Skull, Ricochet Skull and Venom Skull so the next boosted hit is easy to notice." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.necroSkullEnabled end,
          setFunc = function(v) SSRT.sv.necroSkullEnabled = v end, default = defaults.necroSkullEnabled, width = "full" },
        { type = "slider", name = "Skull icon size", min = 40, max = 140, step = 2,
          getFunc = function() return SSRT.sv.necroSkullIconSize end,
          setFunc = function(v) SSRT.sv.necroSkullIconSize = v; ApplyVisualSettings() end, default = defaults.necroSkullIconSize, width = "full" },
        { type = "slider", name = "Skull number size", min = 14, max = 56, step = 1,
          getFunc = function() return SSRT.sv.necroSkullTextSize end,
          setFunc = function(v) SSRT.sv.necroSkullTextSize = v; ApplyVisualSettings() end, default = defaults.necroSkullTextSize, width = "full" },
        { type = "button", name = "Move Skull stacks", func = function() SetMoveTarget("necroSkull") end, width = "half" },
        { type = "button", name = "Reset This Position", func = function()
            SSRT.sv.necroSkullOffsetX = defaults.necroSkullOffsetX
            SSRT.sv.necroSkullOffsetY = defaults.necroSkullOffsetY
            ApplyDKPositions()
        end, width = "half" },
        { type = "header", name = "Necromancer — Corpse Detector" },
        { type = "description", text = "A corpse is usable here! Lights up when a slotted corpse-consuming skill can reach one. It checks usability, not the number of corpses nearby." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.necroCorpseEnabled end,
          setFunc = function(v) SSRT.sv.necroCorpseEnabled = v end, default = defaults.necroCorpseEnabled, width = "full" },
        { type = "slider", name = "Corpse icon size", min = 40, max = 140, step = 2,
          getFunc = function() return SSRT.sv.necroCorpseIconSize end,
          setFunc = function(v) SSRT.sv.necroCorpseIconSize = v; ApplyVisualSettings() end,
          default = defaults.necroCorpseIconSize, width = "full" },
        { type = "button", name = "Move Corpse Detector", func = function() SetMoveTarget("necroCorpse") end, width = "half" },
        { type = "button", name = "Reset This Position", func = function()
            SSRT.sv.necroCorpseOffsetX = defaults.necroCorpseOffsetX
            SSRT.sv.necroCorpseOffsetY = defaults.necroCorpseOffsetY
            ApplyDKPositions()
        end, width = "half" },
        {
            type = "header",
            name = "Arcanist — Beam",
        },
        { type = "description", text = "Keep the Fatecarver and Remedy Cascade beam durations in view, including their supported morphs. Works with subclassed skill lines too." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.beamEnabled end,
          setFunc = function(value) SSRT.sv.beamEnabled = value end, default = defaults.beamEnabled, width = "full" },
        {
            type = "slider",
            name = "Beam icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.beamIconSize end,
            setFunc = function(value)
                SSRT.sv.beamIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.beamIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Beam timer size",
            min = 14,
            max = 56,
            step = 1,
            getFunc = function() return SSRT.sv.beamTextSize end,
            setFunc = function(value)
                SSRT.sv.beamTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.beamTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Arcanist Beam timer",
            func = function() SetMoveTarget("beam") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset This Position",
            func = function()
                SSRT.sv.beamOffsetX = defaults.beamOffsetX
                SSRT.sv.beamOffsetY = defaults.beamOffsetY
                ApplyBeamPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Arcanist — Crux",
        },
        { type = "description", text = "Crux stacks are ready for your next beam! The number goes gold at 2 and red at 3." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.cruxEnabled end,
          setFunc = function(value) SSRT.sv.cruxEnabled = value end, default = defaults.cruxEnabled, width = "full" },
        {
            type = "slider",
            name = "Crux icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.cruxIconSize end,
            setFunc = function(value)
                SSRT.sv.cruxIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.cruxIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Crux stack text size",
            min = 14,
            max = 56,
            step = 1,
            getFunc = function() return SSRT.sv.cruxTextSize end,
            setFunc = function(value)
                SSRT.sv.cruxTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.cruxTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Crux stacks",
            func = function() SetMoveTarget("crux") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset This Position",
            func = function()
                SSRT.sv.cruxOffsetX = defaults.cruxOffsetX
                SSRT.sv.cruxOffsetY = defaults.cruxOffsetY
                ApplyCruxPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Traveling Knife — Warrior’s Opportunity",
        },
        { type = "description", text = "Throw Traveling Knife with Warrior's Opportunity and watch its 5-second window count down at your reticle." },
        { type = "checkbox", name = "ON", getFunc = function() return SSRT.sv.warriorEnabled end,
          setFunc = function(value) SSRT.sv.warriorEnabled = value end, default = defaults.warriorEnabled, width = "full" },
        {
            type = "slider",
            name = "Warrior's Opportunity icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.warriorIconSize end,
            setFunc = function(value)
                SSRT.sv.warriorIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.warriorIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Warrior's Opportunity timer size",
            min = 14,
            max = 56,
            step = 1,
            getFunc = function() return SSRT.sv.warriorTextSize end,
            setFunc = function(value)
                SSRT.sv.warriorTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.warriorTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Warrior's Opportunity timer",
            func = function() SetMoveTarget("warrior") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset This Position",
            func = function()
                SSRT.sv.warriorOffsetX = defaults.warriorOffsetX
                SSRT.sv.warriorOffsetY = defaults.warriorOffsetY
                ApplyWarriorPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Maelstrom — Weapon timer",
        },
        { type = "description", text = "Keep Maelstrom weapon effect timers in sight whether the matching skill is on the front or back bar. Track the effect, not a fixed weapon side." },
        {
            type = "checkbox",
            name = "ON",
            getFunc = function() return SSRT.sv.maelstromEnabled end,
            setFunc = function(value)
                SSRT.sv.maelstromEnabled = value
                UpdateMaelstromEventRegistration()
                RefreshMaelstromBinding()
                if not IsMaelstromTrackingEnabled() then
                    SSRT.maelstromWindow:SetHidden(true)
                end
            end,
            default = defaults.maelstromEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Merciless Charge — Stampede",
            getFunc = function() return SSRT.sv.maelstromStampedeEnabled end,
            setFunc = function(value)
                SSRT.sv.maelstromStampedeEnabled = value
                UpdateMaelstromEventRegistration()
                RefreshMaelstromBinding()
                if not IsMaelstromTrackingEnabled() then
                    SSRT.maelstromWindow:SetHidden(true)
                end
            end,
            default = defaults.maelstromStampedeEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Crushing Wall — Blockade / Unstable Wall",
            getFunc = function() return SSRT.sv.maelstromWallEnabled end,
            setFunc = function(value)
                SSRT.sv.maelstromWallEnabled = value
                UpdateMaelstromEventRegistration()
                RefreshMaelstromBinding()
                if not IsMaelstromTrackingEnabled() then
                    SSRT.maelstromWindow:SetHidden(true)
                end
            end,
            default = defaults.maelstromWallEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Thunderous Volley — Endless Hail",
            getFunc = function() return SSRT.sv.maelstromHailEnabled end,
            setFunc = function(value)
                SSRT.sv.maelstromHailEnabled = value
                UpdateMaelstromEventRegistration()
                RefreshMaelstromBinding()
                if not IsMaelstromTrackingEnabled() then
                    SSRT.maelstromWindow:SetHidden(true)
                end
            end,
            default = defaults.maelstromHailEnabled,
            width = "full",
        },
        {
            type = "slider",
            name = "Maelstrom icon size",
            min = 40,
            max = 140,
            step = 2,
            getFunc = function() return SSRT.sv.maelstromIconSize end,
            setFunc = function(value)
                SSRT.sv.maelstromIconSize = value
                ApplyVisualSettings()
            end,
            default = defaults.maelstromIconSize,
            width = "full",
        },
        {
            type = "slider",
            name = "Maelstrom timer text size",
            min = 14,
            max = 52,
            step = 1,
            getFunc = function() return SSRT.sv.maelstromTextSize end,
            setFunc = function(value)
                SSRT.sv.maelstromTextSize = value
                ApplyVisualSettings()
            end,
            default = defaults.maelstromTextSize,
            width = "full",
        },
        {
            type = "button",
            name = "Move Maelstrom timer",
            func = function() SetMoveTarget("maelstrom") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset This Position",
            func = function()
                SSRT.sv.maelstromOffsetX = defaults.maelstromOffsetX
                SSRT.sv.maelstromOffsetY = defaults.maelstromOffsetY
                ApplyMaelstromPosition()
            end,
            width = "half",
        },
        {
            type = "header",
            name = "Ultimate",
        },
        { type = "description", text = "See your Ultimate charge and its ready glow. Both bars can show together; with a single row, the displayed Ultimate follows your weapon swap. You can also hide the HUD while Shattered Paths Signet is equipped." },
        {
            type = "checkbox",
            name = "ON",
            getFunc = function() return SSRT.sv.ultimateEnabled end,
            setFunc = function(v) SSRT.sv.ultimateEnabled = v; UpdateUI() end,
            default = defaults.ultimateEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Hide Ultimate HUD with Shattered Paths Signet",
            tooltip = "Hide both Ultimate tracker rows while Shattered Paths Signet is equipped. Does not change Ultimate skills, points, or input controls. Default OFF.",
            getFunc = function() return SSRT.sv.ultimateHideWithSignet == true end,
            setFunc = function(v) SSRT.sv.ultimateHideWithSignet = v; UpdateUI() end,
            default = false,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show front bar",
            getFunc = function() return SSRT.sv.ultimateFrontEnabled end,
            setFunc = function(v) SSRT.sv.ultimateFrontEnabled = v; UpdateUI() end,
            default = defaults.ultimateFrontEnabled,
            width = "half",
        },
        {
            type = "checkbox",
            name = "Show back bar",
            getFunc = function() return SSRT.sv.ultimateBackEnabled end,
            setFunc = function(v) SSRT.sv.ultimateBackEnabled = v; UpdateUI() end,
            default = defaults.ultimateBackEnabled,
            width = "half",
        },
        {
            type = "slider",
            name = "Ultimate size",
            min = 60, max = 160, step = 1,
            getFunc = function() return SSRT.sv.ultimateScale end,
            setFunc = function(v) SSRT.sv.ultimateScale = zo_round(v); ApplyVisualSettings(); UpdateUI() end,
            default = defaults.ultimateScale,
            width = "full",
        },
        {
            type = "button",
            name = "Move Ultimate tracker",
            func = function() SetMoveTarget("ultimate") end,
            width = "half",
        },
        {
            type = "button",
            name = "Reset This Position",
            func = function()
                SSRT.sv.ultimateOffsetX = defaults.ultimateOffsetX
                SSRT.sv.ultimateOffsetY = defaults.ultimateOffsetY
                ApplyUltimatePosition()
            end,
            width = "half",
        },
    }
    -- Scribing signature script: show its *real* player buff duration.
    options[#options+1] = {type="header", name="Tank — Gladiator's Tenacity (Support)"}
    options[#options+1] = {type="description", text="Damage-reduction timer from Ulfsild's Contingency."}
    options[#options+1] = {type="checkbox", name="ON", width="full", default=true,
        getFunc=function() return SSRT.sv.gladiatorEnabled end,
        setFunc=function(v) SSRT.sv.gladiatorEnabled=v; UpdateUI() end}
    options[#options+1] = {type="slider", name="Gladiator icon size", min=40,max=140,step=2,width="full",default=78,
        getFunc=function() return SSRT.sv.gladiatorIconSize end,
        setFunc=function(v) SSRT.sv.gladiatorIconSize=v; ApplyVisualSettings() end}
    options[#options+1] = {type="slider", name="Gladiator number size", min=14,max=56,step=1,width="full",default=35,
        getFunc=function() return SSRT.sv.gladiatorTextSize end,
        setFunc=function(v) SSRT.sv.gladiatorTextSize=v; ApplyVisualSettings() end}
    options[#options+1] = {type="button", name="Move Gladiator's Tenacity",width="half",
        func=function() SetMoveTarget("gladiator") end}
    options[#options+1] = {type="button", name="Reset This Position",width="half",
        func=function()
            SSRT.sv.gladiatorOffsetX=defaults.gladiatorOffsetX
            SSRT.sv.gladiatorOffsetY=defaults.gladiatorOffsetY
            ApplyDKPositions()
        end}
    -- Offensive major/minor buffs: one movable pair per group. Independent from
    -- class/maelstrom/taunt UI; source-independent player-effect tracking.
    for _, spec in ipairs({
        {key="berserk", label="Berserk", header="Attack — Berserk (Major / Minor)", descKey="ATK_BERSERK_DESC"},
        {key="brutality", label="Brutality", header="Attack — Brutality (Major / Minor)", descKey="ATK_BRUTALITY_DESC"},
        {key="savagery", label="Savagery", header="Attack — Savagery (Major / Minor)", descKey="ATK_SAVAGERY_DESC"},
        {key="force", label="Force", header="Attack — Force (Major / Minor)", descKey="ATK_FORCE_DESC"},
        {key="slayer", label="Slayer", header="Attack — Slayer (Major / Minor)", descKey="ATK_SLAYER_DESC"},
    }) do
        local key, label = spec.key, spec.label
        options[#options+1] = {type="header", name=spec.header}
        options[#options+1] = {type="description", text=UiText(spec.descKey)}
        options[#options+1] = {type="checkbox", name="Enable Major "..label, width="full", default=true,
            getFunc=function() return SSRT.sv[key.."Enabled"] end,
            setFunc=function(v) SSRT.sv[key.."Enabled"]=v; UpdateUI() end}
        options[#options+1] = {type="checkbox", name="Enable Minor "..label, width="full", default=true,
            getFunc=function() return SSRT.sv[key.."MinorEnabled"] end,
            setFunc=function(v) SSRT.sv[key.."MinorEnabled"]=v; UpdateUI() end}
        for _, grade in ipairs({"Major", "Minor"}) do
            local field = key..grade.."ShowPermanent"
            options[#options+1] = {type="checkbox", name="Show no-expiry "..grade.." "..label,
                width="full", default=false,
                getFunc=function() return SSRT.sv[field] end,
                setFunc=function(v) SSRT.sv[field]=v; UpdateUI() end}
        end
        options[#options+1] = {type="checkbox", name=label..": Major above Minor", width="full", default=true,
            getFunc=function() return SSRT.sv[key.."MajorOnTop"] end,
            setFunc=function(v) SSRT.sv[key.."MajorOnTop"]=v; ApplyVisualSettings() end}
        for _, specSize in ipairs({
            {suffix="IconSize", name=" major icon size", min=40, max=140, default=78},
            {suffix="TextSize", name=" major number size", min=14, max=56, default=35},
            {suffix="MinorIconSize", name=" minor icon size", min=20, max=90, default=36},
            {suffix="MinorTextSize", name=" minor number size", min=14, max=45, default=21},
        }) do
            local field = key..specSize.suffix
            options[#options+1] = {type="slider", name=label..specSize.name,
                min=specSize.min, max=specSize.max, step=1, width="full",
                default=specSize.default,
                getFunc=function() return SSRT.sv[field] end,
                setFunc=function(v) SSRT.sv[field]=v; ApplyVisualSettings() end}
        end
        -- The existing controller automatically appends Stop moving.
        options[#options+1] = {type="button", name="Move "..label.." buff", width="half",
            func=function() SetMoveTarget(key) end}
        for _, control in ipairs(PositionOptions(key, label, ApplyDKPositions)) do
            options[#options+1] = control
        end
        options[#options+1] = {type="button", name="Reset This Position", width="half", func=function()
            SSRT.sv[key.."OffsetX"] = defaults[key.."OffsetX"]
            SSRT.sv[key.."OffsetY"] = defaults[key.."OffsetY"]
            ApplyDKPositions()
        end}
    end
    -- One settings section per buff, for both grades.  No duplicate Resolve/
    -- Vitality headings; each Major/Minor pair can be moved as a single unit.
    for _, spec in ipairs({
        {key="heroism", label="Heroism", header="Tank — Heroism (Major / Minor)", icon=51},
        {key="protection", label="Protection", header="Tank — Protection (Major / Minor)", icon=72},
        {key="tankResolve", label="Resolve", header="Tank — Resolve (Major / Minor)", icon=73},
        {key="mending", label="Mending", header="Tank — Mending (Support)", icon=2},
        {key="vitality", label="Vitality", header="Tank — Vitality (Support)", icon=9},
        {key="evasion", label="Evasion", header="Tank — Evasion (Support)", icon=13},
    }) do
        local key, label = spec.key, spec.label
        options[#options+1] = {type="header", name=spec.header}
        options[#options+1] = {type="description", text=({
            ["Tank — Heroism (Major / Minor)"] = "Stay on top of Ultimate generation with Major and Minor Heroism. Both can appear independently; timeless versions show without numbers.",
            ["Tank — Protection (Major / Minor)"] = "Watch Major and Minor Protection when you're bracing for damage. Separate icons keep both grades easy to see, even when one has no timer.",
            ["Tank — Resolve (Major / Minor)"] = "Keep Major and Minor Resolve within reach of your eyes. Each grade stays in its own spot, with a countdown only when it has an expiry.",
            ["Tank — Mending (Support)"] = "See when your outgoing healing gets a boost from Major or Minor Mending. Timed effects count down; permanent ones can show quietly.",
            ["Tank — Vitality (Support)"] = "Check Major and Minor Vitality when incoming heals matter. The two strengths stay separate, and permanent effects don't need a countdown.",
            ["Tank — Evasion (Support)"] = "Track your Major and Minor Evasion buffs from any source. Timed effects count down, and permanent effects show an icon.",
        })[spec.header]}
        options[#options+1] = {type="checkbox", name="Enable Major "..label, width="full",
            getFunc=function() return SSRT.sv[key.."Enabled"] end,
            setFunc=function(v) SSRT.sv[key.."Enabled"]=v; UpdateUI() end, default=true}
        options[#options+1] = {type="checkbox", name="Enable Minor "..label, width="full",
            getFunc=function() return SSRT.sv[key.."MinorEnabled"] end,
            setFunc=function(v) SSRT.sv[key.."MinorEnabled"]=v; UpdateUI() end,default=true}
        for _, grade in ipairs({{"Major", "Major"}, {"Minor", "Minor"}}) do
            local field = key .. grade[1] .. "ShowPermanent"
            options[#options+1] = {type="checkbox", name="Show no-expiry "..grade[2].." "..label,
                tooltip="Show a permanent/no-expiry version as an icon without a timer. Timed sources remain visible. Does not identify the skill or source as passive.",
                width="full", default=true,
                getFunc=function()
                    local value = SSRT.sv[field]
                    if value == nil then return SSRT.sv.defenseShowPermanentBuffs ~= false end
                    return value
                end,
                setFunc=function(v) SSRT.sv[field] = v; UpdateUI() end}
        end
        options[#options+1] = {type="checkbox", name=label..": Major above Minor", width="full",
            getFunc=function() return SSRT.sv[key.."MajorOnTop"] end,
            setFunc=function(v) SSRT.sv[key.."MajorOnTop"]=v; ApplyVisualSettings() end,default=true}
        options[#options+1] = {type="slider", name=label.." major icon size", min=40,max=140,step=2,width="full",
            getFunc=function() return SSRT.sv[key.."IconSize"] end,
            setFunc=function(v) SSRT.sv[key.."IconSize"]=v; ApplyVisualSettings() end, default=78}
        options[#options+1] = {type="slider", name=label.." major number size", min=14,max=56,step=1,width="full",
            getFunc=function() return SSRT.sv[key.."TextSize"] end,
            setFunc=function(v) SSRT.sv[key.."TextSize"]=v; ApplyVisualSettings() end, default=35}
        options[#options+1] = {type="slider", name=label.." minor icon size",min=20,max=90,step=2,width="full",
            getFunc=function() return SSRT.sv[key.."MinorIconSize"] end,
            setFunc=function(v) SSRT.sv[key.."MinorIconSize"]=v; ApplyVisualSettings() end,default=36}
        options[#options+1] = {type="slider", name=label.." minor number size",min=14,max=45,step=1,width="full",
            getFunc=function() return SSRT.sv[key.."MinorTextSize"] end,
            setFunc=function(v) SSRT.sv[key.."MinorTextSize"]=v; ApplyVisualSettings() end,default=21}
        options[#options+1] = {type="button", name="Move "..label,width="half",func=function() SetMoveTarget(key) end}
        -- The player-facing Move name is shorter than the internal label used
        -- for X/Y positioning. Attach controls by key here, not by button text.
        for _, control in ipairs(PositionOptions(key, label, ApplyDKPositions)) do
            options[#options+1] = control
        end
        options[#options+1] = {type="button", name="Reset This Position",width="half",func=function()
            SSRT.sv[key.."OffsetX"]=defaults[key.."OffsetX"]
            SSRT.sv[key.."OffsetY"]=defaults[key.."OffsetY"]
            ApplyDKPositions()
        end}
    end
    -- Keep existing class sections and move buttons; sliders follow each matching move button.
    local positionTargets = {
        crystal = {"Crystal tracker", ApplyCrystalPosition},
        bound = {"Bound Armaments stacks", ApplyBoundPosition},
        beam = {"Arcanist Beam timer", ApplyBeamPosition},
        crux = {"Crux stacks", ApplyCruxPosition},
        nightblade = {"Grim Focus stacks", ApplyNightbladePosition},
        warrior = {"Warrior's Opportunity timer", ApplyWarriorPosition},
        backlash = {"Backlash timer", ApplyBacklashPosition},
        templarBeam = {"Templar Beam timer", ApplyTemplarBeamPosition},
        templarRune = {"Rune Focus area", ApplyDKPositions},
        warden = {"Shalk timer", ApplyWardenPosition},
        wardenFly = {"Empowered Fly indicator", ApplyDKPositions},
        tankResolve = {"Resolve buffs", ApplyDKPositions},
        vitality = {"Vitality buffs", ApplyDKPositions},
        heroism = {"Heroism buffs", ApplyDKPositions},
        protection = {"Protection buffs", ApplyDKPositions},
        mending = {"Mending buffs", ApplyDKPositions},
        shield = {"Damage Shield", SSRT.Shield.ApplyPosition},
        gladiator = {"Gladiator's Tenacity", ApplyDKPositions},
        dkWhip = {"Whip stacks", ApplyDKPositions},
        dkBreath = {"Breath timer", ApplyDKPositions},
        dkCore = {"Core of Flame timer", ApplyDKPositions},
        necroCorpse = {"Corpse Detector", ApplyDKPositions},
        necroSkull = {"Skull stacks", ApplyDKPositions},
        maelstrom = {"Maelstrom timer", ApplyMaelstromPosition},
        ultimate = {"Ultimate tracker", ApplyUltimatePosition},
    }
    local roleHeaderKeys = {
        ["Attack — Berserk (Major / Minor)"] = "berserk",
        ["Attack — Brutality (Major / Minor)"] = "brutality",
        ["Attack — Savagery (Major / Minor)"] = "savagery",
        ["Attack — Force (Major / Minor)"] = "force",
        ["Attack — Slayer (Major / Minor)"] = "slayer",
        ["Tank — Damage shields"] = "shield",
        ["Tank — Gladiator's Tenacity (Support)"] = "gladiator",
        ["Tank — Resolve (Major / Minor)"] = "tankResolve",
        ["Tank — Vitality (Support)"] = "vitality",
        ["Tank — Heroism (Major / Minor)"] = "heroism",
        ["Tank — Protection (Major / Minor)"] = "protection",
        ["Tank — Mending (Support)"] = "mending",
        ["Tank — Evasion (Support)"] = "evasion",
        ["Tank — Guard Indicator"] = "guardIndicator",
        ["Ultimate"] = "ultimate",
        ["Debuffs — Taunt — Target"] = "debuffTaunt",
        ["Dragonknight — Whip"] = "dkWhip", ["Dragonknight — Breath"] = "dkBreath",
        ["Dragonknight — Core of Flame"] = "dkCore",
        ["Sorcerer — Crystal Fragments"] = "crystal",
        ["Sorcerer — Bound Armaments"] = "bound",
        ["Nightblade — Grim Focus"] = "nightblade",
        ["Templar — Backlash"] = "backlash",
        ["Templar — Execute beam"] = "templarBeam",
        ["Templar — Rune Focus"] = "templarRune",
        ["Warden — Shalk"] = "warden", ["Warden — Empowered Fly"] = "wardenFly",
        ["Necromancer — Skull stacks"] = "necroSkull",
        ["Necromancer — Corpse Detector"] = "necroCorpse",
        ["Arcanist — Beam"] = "beam", ["Arcanist — Crux"] = "crux",
        ["Traveling Knife — Warrior’s Opportunity"] = "warrior",
        ["Maelstrom — Weapon timer"] = "maelstrom",
    }
    -- Three independent toggles per tracker; keep the existing 1/2/4 bitmask
    -- so saved choices from v1.7.34 migrate without conversion.
    local roleButtons = {
        {label = UiText("ROLE_ATTACK"), bit = ROLE_DPS},
        {label = UiText("ROLE_HEAL"), bit = ROLE_HEAL},
        {label = UiText("ROLE_TANK"), bit = ROLE_TANK},
    }
    local debuffRoleCheckboxKeys = {
        ["Major Breach"] = "debuffBreachMajor",
        ["Minor Breach"] = "debuffBreachMinor",
        ["Major Vulnerability"] = "debuffVulnerabilityMajor",
        ["Minor Vulnerability"] = "debuffVulnerabilityMinor",
    }
    local debuffPositionHeaders = {
        ["Debuffs — Taunt — Target"] = {"debuffTaunt", "Taunt"},
        ["Debuffs — Breach — Target"] = {"debuffBreach", "Breach pair"},
        ["Debuffs — Vulnerability — Target"] = {"debuffVulnerability", "Vulnerability pair"},
    }
    -- LibAddonMenu uses only 'half' and 'full' widths for ordinary checkboxes.
    -- A custom single-line row keeps Attack / Heal / Tank together without
    -- changing the existing roleFilters bitmask or existing saved selections.
    local function RoleRow(key)
        -- This must run at first construction, not only after LAM refresh.
        -- A RoleRow is a custom control: its buttons have no visible text until
        -- SetText is called. Previously toggling Enable caused the first refresh.
        local function RefreshButtons(control)
            local mask = (SSRT.sv.roleFilters or {})[key]
            if mask == nil then mask = key == "debuffTaunt" and ROLE_TANK or 7 end
            for i, role in ipairs(roleButtons) do
                local selected = math.floor(mask / role.bit) % 2 == 1
                local button = control.srtRoleButtons[i]
                button:SetText((selected and "[x] " or "[ ] ") .. role.label)
                if selected then
                    button:SetNormalFontColor(0.65, 0.97, 0.72, 1)
                else
                    button:SetNormalFontColor(0.65, 0.65, 0.65, 1)
                end
            end
        end
        local function CreateButtons(control)
            if control.srtRoleButtons then return end
            control.srtRoleButtons = {}
            local width = control:GetWidth()
            local buttonWidth = math.floor((width - 12) / 3)
            for i, role in ipairs(roleButtons) do
                local bit, label = role.bit, role.label
                local button = WINDOW_MANAGER:CreateControl(nil, control, CT_BUTTON)
                button:SetDimensions(buttonWidth, 28)
                button:SetAnchor(TOPLEFT, control, TOPLEFT, (i - 1) * (buttonWidth + 6), 2)
                button:SetFont("ZoFontGame")
                button:SetHandler("OnClicked", function()
                    SSRT.sv.roleFilters = SSRT.sv.roleFilters or {}
                    local mask = SSRT.sv.roleFilters[key]
                    if mask == nil then mask = key == "debuffTaunt" and ROLE_TANK or 7 end
                    local selected = math.floor(mask / bit) % 2 == 1
                    SSRT.sv.roleFilters[key] = mask + (selected and -bit or bit)
                    RefreshButtons(control)
                    UpdateUI()
                end)
                control.srtRoleButtons[i] = button
            end
            -- LAM does not necessarily call refreshFunc the first time a
            -- collapsed submenu is expanded. Initialize labels immediately.
            RefreshButtons(control)
        end
        return {
            type = "custom", width = "full", minHeight = 32, maxHeight = 32,
            createFunc = CreateButtons,
            refreshFunc = function(control)
                CreateButtons(control)
                RefreshButtons(control)
            end,
        }
    end
    local ordered = {}
    local pendingRole, pendingDebuffPosition
    local function AppendDebuffPosition()
        if not pendingDebuffPosition then return end
        local key, label = pendingDebuffPosition[1], pendingDebuffPosition[2]
        ordered[#ordered + 1] = {type="button",name="Move "..label,width="half",
            func=function() SetMoveTarget(key) end}
        ordered[#ordered + 1] = {type="button",name="Stop moving",width="half",
            func=function() SetMoveTarget(nil) end}
        for _, control in ipairs(PositionOptions(key, label, UpdateUI)) do
            ordered[#ordered + 1] = control
        end
        ordered[#ordered + 1] = {type="button", name="Reset "..label.." position",width="full",func=function()
            SSRT.sv[key.."OffsetX"] = defaults[key.."OffsetX"]
            SSRT.sv[key.."OffsetY"] = defaults[key.."OffsetY"]
            UpdateUI()
        end}
        pendingDebuffPosition = nil
    end
    for _, item in ipairs(options) do
        if item.type == "header" then
            AppendDebuffPosition()
            pendingRole = roleHeaderKeys[item.name]
            pendingDebuffPosition = debuffPositionHeaders[item.name]
        end
        ordered[#ordered + 1] = item
        if item.type == "button" and type(item.name) == "string"
            and item.name:find("^Move ") then
            -- Each move action has its stop button beside it, in this submenu.
            ordered[#ordered + 1] = {type="button",name="Stop moving",width="half",
                func=function() SetMoveTarget(nil) end}
        end
        -- Place role switches immediately after the tracker enable control,
        -- not between its title and description or on distant rows.
        if item.type == "checkbox" then
            if pendingRole then
                ordered[#ordered + 1] = RoleRow(pendingRole)
                pendingRole = nil
            end
            local individual = debuffRoleCheckboxKeys[item.name]
            if individual then ordered[#ordered + 1] = RoleRow(individual) end
        end
        if item.type == "button" and type(item.name) == "string" then
            for key, definition in pairs(positionTargets) do
                if item.name == "Move " .. definition[1]
                    or (key == "shield" and item.name == "Move Damage Shield timer") then
                    for _, control in ipairs(PositionOptions(key, definition[1], definition[2])) do
                        ordered[#ordered + 1] = control
                    end
                    break
                end
            end
        end
    end
    AppendDebuffPosition()

    -- Every tracker owns its own foldable section. Keep the checkbox, roles,
    -- grade options, sizes, movement and reset under ONE heading. This avoids
    -- scrolling through dozens of always-expanded controls and stops later
    -- features from drifting into unrelated sections.
    local groups = {class={}, weapon={}, support={}, debuffs={}, ultimate={}, attack={}}
    local current, sectionTitle, sectionControls = "ultimate", nil, nil
    local function FinishSection()
        if sectionControls and #sectionControls > 0 then
            for _, control in ipairs(sectionControls) do
                if control.type == "button" and type(control.name) == "string"
                    and control.name:find("^Move ") then
                    control.name = "Move display"
                end
            end
            local title = UiLabel(sectionTitle)
            title = title:gsub("^Tank — ", ""):gsub("^Debuffs — ", "")
                         :gsub("^Attack — ", "")
                         :gsub("^タンク — ", ""):gsub("^デバフ — ", "")
                         :gsub("^アタック — ", "")
            if current == "attack" then
                title = title:gsub("%(Major / Minor%)$", ""):gsub("（強・弱）$", "")
            elseif current == "support" then
                title = title:gsub("%(Major / Minor%)$", "")
                             :gsub("%(Support%)$", "")
                             :gsub("（強・弱）$", "")
                             :gsub("（サポート）$", "")
                             :gsub("%(強・弱%)$", ""):gsub("%(サポート%)$", "")
            end
            title = title:gsub("%s+$", "")
            groups[current][#groups[current]+1] = {
                type = "submenu", name = title, controls = sectionControls, width = "full"
            }
        end
        sectionTitle, sectionControls = nil, nil
    end
    for _, item in ipairs(ordered) do
        if item.type == "header" then
            FinishSection()
            local n = item.name or ""
            if n:find("^Debuffs — ") then current="debuffs"
            elseif n:find("^Tank — ") then current="support"
            elseif n:find("^Attack — ") then current="attack"
            elseif n:find("^Ultimate") then current="ultimate"
            elseif n:find("^Maelstrom") or n:find("^Traveling Knife") then current="weapon"
            elseif n:find("^Dragonknight") or n:find("^Sorcerer") or n:find("^Nightblade")
                or n:find("^Templar") or n:find("^Warden") or n:find("^Necromancer")
                or n:find("^Arcanist") then current="class"
            end
            sectionTitle, sectionControls = n, {}
        elseif sectionControls then
            sectionControls[#sectionControls+1] = item
        else
            groups[current][#groups[current]+1] = item
        end
    end
    FinishSection()
    -- Translate only after groups and role/control attachments are finalized.
    for _, group in pairs(groups) do LocalizeOptionList(group) end
    -- Prefix numbers because LAM orders separate setting panels by name.
    -- The old unnumbered panel has no unique settings, so do not register it.
    for _, desc in ipairs({
        {"Ultimate", "01", UiText("MENU_ULT"), groups.ultimate},
        {"Class", "02", UiText("MENU_CLASS"), groups.class},
        {"Weapon", "03", UiText("MENU_WEAPON"), groups.weapon},
        {"Attack", "04", UiText("MENU_ATTACK"), groups.attack},
        {"Support", "05", UiText("MENU_SUPPORT"), groups.support},
        {"Debuffs", "06", UiText("MENU_DEBUFF"), groups.debuffs},
    }) do
        local id=panelName .. desc[1]
        local title = "Sora Reticle Tracker - " .. desc[2] .. " " .. desc[3]:gsub("^Sora Reticle Tracker %- ", "")
        LAM:RegisterAddonPanel(id,{type="panel",name=title,displayName=title,
            author="sora0v0",version="1.0.3",registerForRefresh=true,registerForDefaults=true})
        LAM:RegisterOptionControls(id,desc[4])
    end
end

-- Necromancer discovery, release-facing mechanics require verified ability/effect IDs.
-- ID capture uses the game API, never localized names as a predicate.
-- Necromancer readiness diagnostic: compare highlight and failure flags against
-- the native action bar, while keeping the UI unchanged until validated in game.
-- Resolve the highest-priority equipped absorb across both bars. No class check.
-- This scan deliberately uses only confirmed ability IDs, never localized names.
local NECRO_ABSORB_PRIORITY = {
    [115924]=1, [118008]=1, [118763]=1,
    [115926]=2, [118070]=2, [118122]=2,
    [115238]=3, [118639]=3, [118623]=3,
}
local function UpdateNecroCorpseSelected()
    local selectedByBar = {}
    for _, category in ipairs({HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP}) do
        local best, bestPriority = nil, 100
        for slot = SLOT_FIRST, SLOT_LAST do
            local id = GetSlotBoundId(slot, category) or 0
            local priority = NECRO_ABSORB_PRIORITY[id]
            if priority and priority < bestPriority then
                bestPriority = priority
                best = {category = category, slot = slot, id = id}
            end
        end
        selectedByBar[category] = best
    end
    SSRT.necroCorpseSelectedByBar = selectedByBar
end

-- Production callback: keep necromancer corpse slot selection refreshed.
local function OnNecroCorpseSlotUpdate()
    UpdateNecroCorpseSelected()
end

-- Developer rune probes are retained in the previously archived v1.7.47 source.
-- Production Rune Support tracking above remains unchanged.

local function HandleSlash(text)
    text = zo_strlower((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))

    if text == "crystal" or text == "cmove" then
        SetMoveTarget("crystal")
    elseif text == "bound" or text == "bmove" then
        SetMoveTarget("bound")
    elseif text == "templarbeam" then
        SetMoveTarget("templarBeam")
    elseif text == "beam" then
        SetMoveTarget("beam")
    elseif text == "crux" then
        SetMoveTarget("crux")
    elseif text == "nightblade" or text == "nb" then
        SetMoveTarget("nightblade")
    elseif text == "warrior" or text == "opportunity" then
        SetMoveTarget("warrior")
    elseif text == "necroskull" then
        SetMoveTarget("necroSkull")
    elseif text == "necrocorpse" then
        SetMoveTarget("necroCorpse")
    elseif text == "icons" then
        ToggleArmoryIconFinder()
    elseif text == "fly" then
        SetMoveTarget("wardenFly")
    elseif text == "dkwhip" or text == "dkbreath" then
        SetMoveTarget(text == "dkwhip" and "dkWhip" or "dkBreath")
    elseif text == "warden" or text == "shalk" then
        SetMoveTarget("warden")
    elseif text == "backlash" or text == "templar" then
        SetMoveTarget("backlash")
    elseif text == "maelstrom" or text == "mmove" then
        SetMoveTarget("maelstrom")
    elseif text == "vitality" or text == "heart" then
        SetMoveTarget("vitality")
    elseif text == "mending" then
        SetMoveTarget("mending")
    elseif text == "protection" then
        SetMoveTarget("protection")
    elseif text == "heroism" then
        SetMoveTarget("heroism")
    elseif text == "shield" then
        SetMoveTarget("shield")
    elseif text == "gladiator" then
        SetMoveTarget("gladiator")
    elseif text == "stop" then
        SetMoveTarget(nil)
    elseif text == "reset" then
        ResetPositions()
        Chat("All positions reset.")
    else
        Chat("/srt crystal  bound  templarbeam  beam  crux  nb  warrior  necroskull  necrocorpse  fly  dkwhip  dkbreath  backlash  warden  shield  vitality  mending  protection  heroism  icons  maelstrom  stop  reset")
    end
end

local function OnCrystalEffectChanged(_, changeType, _, _, _, _, endTime)
    if changeType == EFFECT_RESULT_FADED then
        SSRT.crystalActive = false
        SSRT.crystalEndTime = 0
    else
        SSRT.crystalActive = true
        SSRT.crystalEndTime = endTime or 0
    end
end

local function OnBoundEffectChanged(_, changeType, _, _, _, _, _, stackCount)
    if changeType == EFFECT_RESULT_FADED then
        SSRT.boundStacks = 0
    else
        SSRT.boundStacks = math.max(0, stackCount or 0)
    end
end

local function OnPlayerActivated()
    RefreshGuardAutomation()
    zo_callLater(RefreshState, 300)
end

local function OnActionStateChanged()
    RefreshGuardAutomation()
    zo_callLater(function()
        -- Reconcile permanent buffs after bar/slot changes as well as effect events.
        ScanDefenseBuffs()
        ScanBoundStacks()
        ScanNightbladeStacks()
        if IsMaelstromTrackingEnabled() then
            RefreshMaelstromBinding()
        end
    end, 50)
end

local function OnWornInventoryChanged()
    zo_callLater(RefreshMaelstromBinding, 100)
end

UpdateMaelstromEventRegistration = function()
    local shouldRegister = IsMaelstromTrackingEnabled()

    if shouldRegister == SSRT.maelstromGearEventRegistered then
        return
    end

    if shouldRegister then
        EVENT_MANAGER:RegisterForEvent(
            GEAR_EVENT_NAME,
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            OnWornInventoryChanged
        )
        EVENT_MANAGER:AddFilterForEvent(
            GEAR_EVENT_NAME,
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_WORN,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT
        )
    else
        EVENT_MANAGER:UnregisterForEvent(GEAR_EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end

    SSRT.maelstromGearEventRegistered = shouldRegister
end

local function Initialize()
    SSRT.sv = ZO_SavedVars:NewAccountWide(
        SAVED_VARS,
        SAVED_VARS_VERSION,
        GetWorldName(),
        defaults
    )
    -- First run after splitting Breach / Vulnerability controls: use the player's
    -- previously configured shared sizes as the initial independent values.
    if not SSRT.sv.debuffSizeSplitMigrated then
        for _, group in ipairs({"debuffBreach", "debuffVulnerability"}) do
            SSRT.sv[group .. "MajorSize"] = SSRT.sv.debuffMajorSize or 48
            SSRT.sv[group .. "MinorSize"] = SSRT.sv.debuffMinorSize or 36
            SSRT.sv[group .. "MajorTextSize"] = SSRT.sv.debuffTextSize or 24
            SSRT.sv[group .. "MinorTextSize"] = SSRT.sv.debuffTextSize or 24
        end
        SSRT.sv.debuffTauntTextSize = SSRT.sv.debuffTextSize or 24
        SSRT.sv.debuffSizeSplitMigrated = true
    end
    -- v1.7.22 introduced Beam with temporary icon 23. Update that old default
    -- without resetting other saved settings or positions.
    if SSRT.sv.templarBeamIconIndex == 23 then
        SSRT.sv.templarBeamIconIndex = TEMPLAR_EXECUTE_DEFAULT_ICON
    end

    -- Preserve users' individually chosen development icons; migrate only the old placeholder (27).
    if SSRT.sv.dkWhipIconIndex == 27 then SSRT.sv.dkWhipIconIndex = DK_ICON_WHIP end
    if SSRT.sv.dkBreathIconIndex == 27 then SSRT.sv.dkBreathIconIndex = DK_ICON_BREATH end
    RefreshGuardAutomation()
    -- No automatic offset migration. Saved positions belong to the player.
    -- Defaults apply on first install or via individual Reset This Position.
    -- Default icons are supplied by ZO_SavedVars.
    -- Do not overwrite icon selections already saved by the player.
    CreateCrystalWindow()
    CreateBoundWindow()
    CreateBeamWindow()
    CreateCruxWindow()
    CreateNightbladeWindow()
    CreateWarriorWindow()
    CreateBacklashWindow()
    CreateDKWindow("templarBeam", "TemplarBeam", 1, 0.85, 0.2)
    CreateDKWindow("templarRune", "TemplarRune", 1, 0.85, 0.2)
    SSRT.templarRuneLabel:SetText("")
    CreateWardenWindow()
    CreateDKWindow("wardenFly", "Fly", 0.28, 0.92, 0.40)
    SSRT.wardenFlyLabel:SetText("")
    CreateDKWindow("dkWhip", "Whip", 1, 0.25, 0.1)
    CreateDKWindow("dkBreath", "Breath", 1, 0.5, 0.1)
    CreateDKWindow("dkCore", "Core", 1, 0.5, 0.1)
    CreateDKWindow("necroCorpse", "Corpse", 0.75, 0.32, 0.85)
    CreateDKWindow("necroSkull", "Skull", 0.75, 0.32, 0.85)
    SSRT.necroCorpseLabel:SetText("")
    SSRT.necroSkullLabel:SetText("")
    CreateDKWindow("tankResolve", "TankResolve", 0.42, 0.95, 0.51)
    CreateDKWindow("heroism", "Heroism", 1.0, 0.77, 0.29)
    CreateDKWindow("protection", "Protection", 0.52, 0.72, 1.0)
    CreateDKWindow("vitality", "MajorVitality", 1, 0.36, 0.4)
    CreateDKWindow("mending", "Mending", 1.0, 0.49, 0.75)
    CreateDKWindow("berserk", "AttackBerserk", 0.75, 0.24, 0.29)
    CreateDKWindow("brutality", "AttackBrutality", 0.95, 0.18, 0.21)
    CreateDKWindow("savagery", "AttackSavagery", 1.0, 0.39, 0.23)
    CreateDKWindow("force", "AttackForce", 0.96, 0.51, 0.29)
    CreateDKWindow("slayer", "AttackSlayer", 0.67, 0.23, 0.30)
    CreateDKWindow("evasion", "SupportEvasion", 0.37, 0.83, 0.78)
    CreateDKWindow("shield", "Shield", 0.4, 0.88, 1.0)
    CreateDKWindow("gladiator", "Gladiator", 0.98, 0.60, 0.24)
    CreateArmoryIconFinder()
    CreateTargetDebuffs()
    ApplyTargetDebuffSizes()
    CreateGuardIndicator()
    CreateUltimateWindow()
    ApplyGuardPosition()
    CreateMaelstromWindow()
    ApplyCrystalPosition()
    ApplyBoundPosition()
    ApplyBeamPosition()
    ApplyCruxPosition()
    ApplyNightbladePosition()
    ApplyWarriorPosition()
    ApplyBacklashPosition()
    ApplyWardenPosition()
    ApplyDKPositions()
    ApplyTemplarBeamPosition()
    ApplyMaelstromPosition()
    ApplyUltimatePosition()
    SSRT.Shield.Initialize()
    UpdateNecroCorpseSelected()
    ScanWardenFlyReady()
    ApplyVisualSettings()
    RegisterSettings()
    ApplyCrystalSilentBlock()

    SLASH_COMMANDS["/srt"] = HandleSlash

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "DefenseBuffs", EVENT_EFFECT_CHANGED, OnDefenseBuffChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "DefenseBuffs", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WardenFlyReady", EVENT_EFFECT_CHANGED, OnWardenFlyEffect)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "WardenFlyReady", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, WARDEN_FLY_READY_BUFF_ID, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Crystal", EVENT_EFFECT_CHANGED, OnCrystalEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME .. "Crystal",
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, CRYSTAL_FRAGMENTS_PROC_EFFECT_ID,
        REGISTER_FILTER_UNIT_TAG, "player"
    )

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CrystalWeapon", EVENT_EFFECT_CHANGED, OnCrystalWeaponEffect)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "CrystalWeapon", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, CRYSTAL_WEAPON_BUFF_ID, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CrystalWeaponProc", EVENT_COMBAT_EVENT, OnCrystalWeaponBonusDamage)
    -- Two logged damage ability IDs. Filtering avoids work on unrelated combat events.
    -- One event registration per ID, since one event filter only accepts one ability ID.
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "CrystalWeaponProc", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID, 143804)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CrystalWeaponProcAlt", EVENT_COMBAT_EVENT, OnCrystalWeaponBonusDamage)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "CrystalWeaponProcAlt", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID, 181056)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Bound", EVENT_EFFECT_CHANGED, OnBoundEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME .. "Bound",
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, BOUND_ARMAMENTS_STACK_EFFECT_ID,
        REGISTER_FILTER_UNIT_TAG, "player"
    )

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Crux", EVENT_EFFECT_CHANGED, OnCruxEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME .. "Crux",
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID, CRUX_ABILITY_ID,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
        REGISTER_FILTER_UNIT_TAG, "player"
    )

    RegisterBeamEvents()
    RegisterDKBreathEvents()
    for abilityId in pairs(TEMPLAR_EXECUTE_IDS) do
        local eventName = ADDON_NAME .. "TemplarExec" .. tostring(abilityId)
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT,
            function(_, result, _, _, _, _, _, sourceType, _, _, _, _, _, _, _, _, _, _, _, eventId)
                if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
                if result == ACTION_RESULT_INTERRUPT then
                    ClearTemplarBeam()
                elseif result == ACTION_RESULT_BEGIN then
                    local now = GetFrameTimeSeconds()
                    -- Start only on a real BEGIN following a recent slot-use.
                    -- Consume the pending arm so an extra BEGIN cannot restart it.
                    if SSRT.sv.templarBeamEnabled
                        and now <= templarBeamPendingUntil
                        and templarBeamPendingBar == GetActiveHotbarCategory()
                        and not IsBlockActive() then
                        SSRT.templarBeamEnd = now + TEMPLAR_EXECUTE_SECONDS
                        templarBeamPendingUntil = 0
                        templarBeamPendingBar = nil
                    end
                end
            end)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
    end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "TemplarBeamSwap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
        function()
            if (SSRT.templarBeamEnd or 0) > GetFrameTimeSeconds() then
                ClearTemplarBeam()
            end
        end)

    for abilityId in pairs(NIGHTBLADE_STACK_EFFECTS) do
        local eventName = ADDON_NAME .. "Nightblade" .. tostring(abilityId)
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, OnNightbladeEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(
            eventName,
            EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_ABILITY_ID, abilityId,
            REGISTER_FILTER_UNIT_TAG, "player"
        )
    end

    local skullEvent = ADDON_NAME .. "SkullBuff"
    EVENT_MANAGER:RegisterForEvent(skullEvent, EVENT_EFFECT_CHANGED, function(_, changeType, _, _, unitTag, _, _, stackCount, _, _, _, _, _, _, _, abilityId)
        if unitTag ~= "player" or not NECRO_SKULL_EFFECTS[abilityId] then return end
        if changeType == EFFECT_RESULT_FADED then
            if SSRT.necroSkullEffectId == abilityId then
                SSRT.necroSkullStacks = 0
                SSRT.necroSkullEffectId = nil
            end
        else
            SSRT.necroSkullEffectId = abilityId
            SSRT.necroSkullStacks = math.max(0, stackCount or 0)
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(skullEvent, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "DKBuff", EVENT_EFFECT_CHANGED, OnDKEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "DKBuff", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "NecroCorpseSlots", EVENT_ACTION_SLOT_UPDATED, OnNecroCorpseSlotUpdate)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "NecroCorpseAllSlots", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnNecroCorpseSlotUpdate)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WarriorOpportunity", EVENT_ACTION_SLOT_ABILITY_USED, OnActionSlotAbilityUsed)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "RuneSupportCast", EVENT_ACTION_SLOT_ABILITY_USED, OnRuneSupportCast)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "DKCoreCast", EVENT_ACTION_SLOT_ABILITY_USED, OnDKCoreUsed)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "GuardSkillPoints", EVENT_SKILL_POINTS_CHANGED,
        function() zo_callLater(RefreshGuardAutomation, 100) end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "UltimateGear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function() RefreshUltimateSignetEquipped(); RefreshGuardAutomation() end)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "UltimateGear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "UltimateGearFull", EVENT_INVENTORY_FULL_UPDATE,
        function() RefreshUltimateSignetEquipped(); RefreshGuardAutomation() end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOT_UPDATED, OnActionStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnActionStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnActionStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnActionStateChanged)

    UpdateMaelstromEventRegistration()
    -- Cast-event Maelstrom timer; no native slot remaining-time polling.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "MaelstromCast",
        EVENT_ACTION_SLOT_ABILITY_USED, SSRT.WeaponSkills.OnSkillUsed)

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Display", 100, UpdateUI)

    zo_callLater(RefreshState, 500)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
