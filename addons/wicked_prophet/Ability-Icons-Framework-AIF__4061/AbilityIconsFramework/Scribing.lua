-- =============================================================================
-- Ability Icons Framework (AIF) - Dynamic Scribing & Grimoire Subsystem
-- =============================================================================
-- Solves one of Scribing's greatest visual disappointments: by default, Zenimax
-- gives every Grimoire a single generic icon. Whether your Banner Bearer rains
-- fiery doom, frostbite, shock storms, or healing buffs, vanilla ESO shows the
-- exact same banner texture.
--
-- This subsystem inspects the player's slotted Focus Script (Flame, Frost, Shock,
-- Bleed, Taunt, Healing, etc.) across 5 client languages, and dynamically swaps
-- the generic grimoire texture for an icon that actually tells you what your spell does.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}
local AbilityIconsFramework = AbilityIconsFramework

local pairs                             = pairs
local string_find                       = string.find
local zo_strlower                       = zo_strlower
local IsCraftedAbilityScribed           = IsCraftedAbilityScribed
local GetCraftedAbilityActiveScriptIds   = GetCraftedAbilityActiveScriptIds
local GetCraftedAbilityScriptDisplayName = GetCraftedAbilityScriptDisplayName

local DEFAULT_ICONS = AbilityIconsFramework.DEFAULT_ICONS
local EFFECT        = AbilityIconsFramework.EFFECT

--------------------------------------------------------------------------------
-- Scribed Skills Configuration & Texture Mapping Matrix
--------------------------------------------------------------------------------

--- Builds the master lookup matrix for all 12 player-craftable Grimoires.
--- Each Grimoire entry pairs its vanilla base texture with:
---   1. SCRIBING_ID_KEY: The numeric craftedAbilityId used by ESO's Scribing engine.
---   2. EFFECT.<TYPE>: High-resolution replacement textures for each viable Focus Script.
---   3. EFFECT.DEFAULT: Fallback texture if no Focus Script is chosen or unrecognized.
function AbilityIconsFramework.GenerateScribedSkillsIcons()

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.BANNER_BEARER] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 12,
        [EFFECT.FLAME] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support_flame.dds")],
        [EFFECT.SHOCK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support_shock.dds")],
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support_magic.dds")],
        [EFFECT.RESOURCES] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support_resources.dds")],
        [EFFECT.MULTITARGET] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support_multitarget.dds")],
        [EFFECT.MITIGATION] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support_mitigation.dds")],
		[EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support_physical.dds")],
		[EFFECT.IMMOBILIZE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support_immobilize.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_support.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.ELEMENTAL_EXPLOSION] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 5,
        [EFFECT.FLAME] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_flame.dds")],
        [EFFECT.FROST] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_frost.dds")],
        [EFFECT.SHOCK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_shock.dds")],
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_magic.dds")],
        [EFFECT.DISPEL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_dispel.dds")],
        [EFFECT.TRAUMA] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_trauma.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_physical.dds")],
        [EFFECT.KNOCKBACK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_knockback.dds")],
        [EFFECT.STUN] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro_stun.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffdestro.dds")]
    }
    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.MENDERS_BOND] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 6,
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffresto_magic.dds")],
        [EFFECT.RESOURCES] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffresto_resources.dds")],
        [EFFECT.SHIELD] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffresto_shield.dds")],
        [EFFECT.IMMOBILIZE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffresto_immobilize.dds")],
        [EFFECT.HEAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffresto_heal.dds")],
        [EFFECT.ULTIMATE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffresto_ultimate.dds")],
        [EFFECT.MITIGATION] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffresto_mitigation.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_staffresto.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.SHIELD_THROW] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 3,
        [EFFECT.FROST] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed_frost.dds")],
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed_magic.dds")],
        [EFFECT.IMMOBILIZE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed_immobilize.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed_physical.dds")],
        [EFFECT.MULTITARGET] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed_multitarget.dds")],
        [EFFECT.TAUNT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed_taunt.dds")],
        [EFFECT.KNOCKBACK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed_knockback.dds")],
        [EFFECT.PULL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed_pull.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_1handed.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.SMASH] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 4,
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_magic.dds")],
        [EFFECT.HEAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_heal.dds")],
        [EFFECT.SHIELD] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_shield.dds")],
        [EFFECT.BLEED] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_bleed.dds")],
        [EFFECT.POISON] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_poison.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_physical.dds")],
        [EFFECT.TAUNT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_taunt.dds")],
        [EFFECT.KNOCKBACK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_knockback.dds")],
        [EFFECT.STUN] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed_stun.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_2handed.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.SOUL_BURST] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 8,
        [EFFECT.FLAME] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_flame.dds")],
        [EFFECT.FROST] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_frost.dds")],
        [EFFECT.SHOCK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_shock.dds")],
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_magic.dds")],
        [EFFECT.HEAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_heal.dds")],
        [EFFECT.IMMOBILIZE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_immobilize.dds")],
        [EFFECT.SHIELD] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_shield.dds")],
        [EFFECT.BLEED] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_bleed.dds")],
        [EFFECT.DISEASE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_disease.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_physical.dds")],
        [EFFECT.PULL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2_pull.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic2.dds")]
    }
    
    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.TORCHBEARER] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 10,
        [EFFECT.FLAME] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild_flame.dds")],
        [EFFECT.FROST] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild_frost.dds")],
        [EFFECT.HEAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild_heal.dds")],
        [EFFECT.ULTIMATE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild_ultimate.dds")],
        [EFFECT.BLEED] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild_bleed.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild_physical.dds")],
        [EFFECT.KNOCKBACK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild_knockback.dds")],
        [EFFECT.STUN] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild_stun.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_fightersguild.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.TRAMPLE] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 11,
        [EFFECT.FROST] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault_frost.dds")],
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault_magic.dds")],
        [EFFECT.STUN] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault_stun.dds")],
        [EFFECT.DISPEL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault_dispel.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault_physical.dds")],
        [EFFECT.TRAUMA] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault_trauma.dds")],
        [EFFECT.DISEASE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault_disease.dds")],
        [EFFECT.KNOCKBACK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault_knockback.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_assault.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.TRAVELING_KNIFE] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 7,
        [EFFECT.FROST] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield_frost.dds")],
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield_magic.dds")],
        [EFFECT.BLEED] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield_bleed.dds")],
        [EFFECT.POISON] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield_poison.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield_physical.dds")],
        [EFFECT.MULTITARGET] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield_multitarget.dds")],
        [EFFECT.PULL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield_pull.dds")],
        [EFFECT.STUN] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield_stun.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_dualwield.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.ULFSILDS_CONTINGENCY] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 9,
        [EFFECT.FLAME] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_flame.dds")],
        [EFFECT.FROST] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_frost.dds")],
        [EFFECT.SHOCK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_shock.dds")],
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_magic.dds")],
        [EFFECT.BLEED] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_bleed.dds")],
        [EFFECT.HEAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_heal.dds")],
        [EFFECT.KNOCKBACK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_knockback.dds")],
        [EFFECT.SHIELD] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_shield.dds")],
        [EFFECT.IMMOBILIZE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild_immobilize.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_magesguild.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.VAULT] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 1,
        [EFFECT.FLAME] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow_flame.dds")],
        [EFFECT.HEAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow_heal.dds")],
        [EFFECT.BLEED] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow_bleed.dds")],
        [EFFECT.POISON] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow_poison.dds")],
        [EFFECT.DISEASE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow_disease.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow_physical.dds")],
        [EFFECT.TAUNT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow_taunt.dds")],
        [EFFECT.IMMOBILIZE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow_immobilize.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_bow.dds")]
    }

    AbilityIconsFramework.CUSTOM_ABILITY_ICONS[DEFAULT_ICONS.WIELD_SOUL] = {
        [AbilityIconsFramework.SCRIBING_ID_KEY] = 2,
        [EFFECT.FLAME] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_flame.dds")],
        [EFFECT.FROST] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_frost.dds")],
        [EFFECT.SHOCK] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_shock.dds")],
        [EFFECT.PHYSICAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_physical.dds")],
        [EFFECT.MAGIC] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_magic.dds")],
        [EFFECT.HEAL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_heal.dds")],
        [EFFECT.STUN] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_stun.dds")],
        [EFFECT.SHIELD] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_shield.dds")],
        [EFFECT.BLEED] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_bleed.dds")],
        [EFFECT.DISEASE] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_disease.dds")],
        [EFFECT.PULL] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1_pull.dds")],
        [EFFECT.DEFAULT] = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[AbilityIconsFramework.esoIcon("ability_grimoire_soulmagic1.dds")]
    }
end

----------------------------------------
-- Scribing Multi-Language Dictionary --
----------------------------------------

-- Mapping of effect names in different languages
local effectTranslations = {
    ["en"] = {
        ["flame"] = "flame",
        ["frost"] = "frost",
        ["shock"] = "shock",
        ["magic"] = "magic",
        ["heal"] = "heal",
        ["resources"] = "resources",
        ["ultimate"] = "ultimate",
        ["stun"] = "stun",
        ["immobilize"] = "immobilize",
        ["knockback"] = "knockback",
        ["dispel"] = "dispel",
        ["shield"] = "shield",
        ["physical"] = "physical",
        ["multi-target"] = "multi-target",
        ["bleed"] = "bleed",
        ["trauma"] = "trauma",
        ["poison"] = "poison",
        ["disease"] = "disease",
        ["mitigation"] = "mitigation",
        ["taunt"] = "taunt",
        ["pull"] = "pull",
    },
    ["de"] = {
        ["flame"] = "flammen",
        ["frost"] = "frost",
        ["shock"] = "schock",
        ["magic"] = "magie",
        ["heal"] = "heilung",
        ["resources"] = "ressourcen",
        ["ultimate"] = "ultimativ",
        ["stun"] = "betäubung",
        ["immobilize"] = "festhalten",
        ["knockback"] = "rückstoß",
        ["dispel"] = "bannen",
        ["shield"] = "schild",
        ["physical"] = "physisch",
        ["multi-target"] = "mehrere",
        ["bleed"] = "blutung",
        ["trauma"] = "trauma",
        ["poison"] = "gift",
        ["disease"] = "seuche",
        ["mitigation"] = "mitigation",
        ["taunt"] = "verspotten",
        ["pull"] = "ziehen",
    },
    ["fr"] = {
        ["flame"] = "flamme",
        ["frost"] = "givre",
        ["shock"] = "foudre",
        ["magic"] = "magique",
        ["heal"] = "soin",
        ["resources"] = "ressources",
        ["ultimate"] = "ultime",
        ["stun"] = "étourdissement",
        ["immobilize"] = "immobiliser",
        ["knockback"] = "repousse",
        ["dispel"] = "dissiper",
        ["shield"] = "bouclier",
        ["physical"] = "physique",
        ["multi-target"] = "cible multiple",
        ["bleed"] = "saignement",
        ["trauma"] = "trauma",
        ["poison"] = "poison",
        ["disease"] = "maladie",
        ["mitigation"] = "absorption",
        ["taunt"] = "provocation",
        ["pull"] = "attraction",
    },
    ["es"] = {
        ["flame"] = "fuego",
        ["frost"] = "escarcha",
        ["shock"] = "descarga",
        ["magic"] = "mágic",
        ["heal"] = "cura",
        ["resources"] = "recursos",
        ["ultimate"] = "habilidad máxima",
        ["stun"] = "aturdimiento",
        ["immobilize"] = "inmovilizar",
        ["knockback"] = "empuj",
        ["dispel"] = "disipar",
        ["shield"] = "escudo",
        ["physical"] = "físico",
        ["multi-target"] = "multiobjetivo",
        ["bleed"] = "sangrado",
        ["trauma"] = "trauma",
        ["poison"] = "veneno",
        ["disease"] = "enfermedad",
        ["mitigation"] = "mitigación",
        ["taunt"] = "provocar",
        ["pull"] = "atracción",
    },
    ["ru"] = {
        ["flame"] = "огненный",
        ["frost"] = "мороз",
        ["shock"] = "электричество",
        ["magic"] = "магический",
        ["heal"] = "исцеление",
        ["resources"] = "ресурс",
        ["ultimate"] = "суперспособности",
        ["stun"] = "оглушение",
        ["immobilize"] = "обездвиживание",
        ["knockback"] = "отбрасывание",
        ["dispel"] = "рассеивание",
        ["shield"] = "щит",
        ["physical"] = "физический",
        ["multi-target"] = "нескольким целям",
        ["bleed"] = "кровотечения",
        ["trauma"] = "рана",
        ["poison"] = "яд",
        ["disease"] = "болезнетворный",
        ["mitigation"] = "увеличение эффективности",
        ["taunt"] = "провоцирование",
        ["pull"] = "притяжение",
    },
}

-- Cache active language translation table once at file load
local currentLang = zo_strlower(GetCVar("language.2") or "en")
local activeTranslations = effectTranslations[currentLang] or effectTranslations["en"]

--------------------------------------------------------------------------------
-- Dynamic Scribing Script-to-Icon Mapping Engine
--------------------------------------------------------------------------------

-- Fast memoization cache: maps numeric primaryScriptId -> canonical effectKey (e.g., 5 -> "flame").
-- Once a player's Focus Script ID is resolved, subsequent checks bypass all string comparisons.
local scriptIdToEffect = {}

--- Maps a Focus Script's display name and Grimoire base icon to its custom elemental icon.
---
--- How this works:
---   1. Fast Path: If we have already seen this numeric primaryScriptId, perform an
---      instant O(1) table lookup using our memoized scriptIdToEffect cache.
---   2. Slow Path: If seeing this script for the first time, search the localized script
---      name against the active client language dictionary (English, German, French,
---      Spanish, Russian) to identify the damage type / mechanic.
---   3. Cache the resolved effectKey to primaryScriptId so we never scan strings again.
---
--- @param scriptName string The localized display name of the active Focus Script.
--- @param defaultIcon string The vanilla base icon path of the Grimoire (e.g., "ability_grimoire_support.dds").
--- @param primaryScriptId number? The unique numeric ID of the active Focus Script.
--- @return string? replacementTexture The redirected texture path, or default icon if unmapped.
function AbilityIconsFramework.MapScriptToIcon(scriptName, defaultIcon, primaryScriptId)
    local customIcons = AbilityIconsFramework.CUSTOM_ABILITY_ICONS[defaultIcon]
    if not customIcons then
        return nil
    end

    -- Fast path: if primaryScriptId was already resolved to an effect, do instant O(1) lookup
    if primaryScriptId and primaryScriptId > 0 and scriptIdToEffect[primaryScriptId] then
        local effectKey = scriptIdToEffect[primaryScriptId]
        if customIcons[effectKey] then
            return customIcons[effectKey]
        end
    end

    if not scriptName or scriptName == "" then
        return customIcons[EFFECT.DEFAULT]
    end

    scriptName = zo_strlower(scriptName)

    for key, value in pairs(customIcons) do
        local translatedEffect = activeTranslations[key]
        if translatedEffect and string_find(scriptName, translatedEffect, 1, true) then
            if primaryScriptId and primaryScriptId > 0 then
                scriptIdToEffect[primaryScriptId] = key
            end
            return value
        end
    end

    if primaryScriptId and primaryScriptId > 0 then
        scriptIdToEffect[primaryScriptId] = EFFECT.DEFAULT
    end
    return customIcons[EFFECT.DEFAULT]
end

--- Iterates through all 12 Scribing Grimoires and updates texture redirection.
---
--- For each Grimoire:
---   - If scribing icons are enabled and the ability is unlocked/crafted on this character,
---     queries GetCraftedAbilityActiveScriptIds to find the slotted Focus Script.
---   - Redirects the Grimoire's base icon to the matching elemental/utility texture.
---   - If custom scribing is disabled in settings, cleanly resets the texture back to vanilla.
function AbilityIconsFramework.UpdateDefaultScribingIcons()
    local settings = AbilityIconsFramework.GetSettings()
    if not settings then return end

    local showCustom = settings.showCustomScribeIcons

    for BaseIcon, IconDataList in pairs(AbilityIconsFramework.CUSTOM_ABILITY_ICONS) do
        if showCustom then
            local CustomScribedIcon = nil
            local scribingId = IconDataList[AbilityIconsFramework.SCRIBING_ID_KEY]

            if scribingId and IsCraftedAbilityScribed(scribingId) then
                local primaryScriptId = GetCraftedAbilityActiveScriptIds(scribingId)
                local scriptName = GetCraftedAbilityScriptDisplayName(primaryScriptId)
                CustomScribedIcon = AbilityIconsFramework.MapScriptToIcon(scriptName, BaseIcon, primaryScriptId)
            end

            local CustomDefaultIcon = IconDataList[EFFECT.DEFAULT]
            if CustomScribedIcon ~= nil then
                AbilityIconsFramework.RedirectTexture(BaseIcon, CustomScribedIcon)
            elseif CustomDefaultIcon ~= nil then
                AbilityIconsFramework.RedirectTexture(BaseIcon, CustomDefaultIcon)
            else
                AbilityIconsFramework.RedirectTexture(BaseIcon, BaseIcon)
            end
        else
            AbilityIconsFramework.RedirectTexture(BaseIcon, BaseIcon)
        end
    end
end

--- Callback triggered whenever the player crafts or modifies a Grimoire at a Scribing Altar.
--- Re-evaluates all scribed abilities and repaints action bar slots immediately.
function AbilityIconsFramework.OnScribingUpdate()
    local settings = AbilityIconsFramework.GetSettings()
    if settings and settings.showCustomScribeIcons then
        AbilityIconsFramework.UpdateDefaultScribingIcons()
    end
    AbilityIconsFramework.UpdateAllSlots()
end
