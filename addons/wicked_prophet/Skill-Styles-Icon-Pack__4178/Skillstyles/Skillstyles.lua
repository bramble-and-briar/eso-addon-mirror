local ADDON_NAME  = "Skillstyles"
local LAM2 = LibAddonMenu2

local SAVEDVARS_VERSION = 1
local DEFAULTS = {
	resolutionChoice = "256", "64", "128", "256"
}

local SkillStyles_SV = nil

local function GetIconsResolution()
	if SkillStyles_SV and SkillStyles_SV.resolutionChoice and SkillStyles_SV.resolutionChoice ~= "Flat" then
		return tostring(SkillStyles_SV.resolutionChoice)
	end
	return nil
end

local function GetAddOnIconsPath()
	local res = GetIconsResolution()
	if res == nil then
		return "/Skillstyles/icons/"
	end
	return "/Skillstyles/icons/" .. res .. "/"
end

local ADDON_ICONS = {

	-- ========================================================================
	-- CLASSES
	-- ========================================================================

	-- arcanist
	"ability_arcanist_001_blue.dds",
	"ability_arcanist_002_aetherius.dds",
	"ability_arcanist_002_blue.dds",
	"ability_arcanist_003_blue.dds",
	"ability_arcanist_006_hallowjack.dds",
	"ability_arcanist_008_blue.dds",
	"ability_arcanist_013_blue.dds",
	"u49_ability_heraldofthetome_tomebearersinspiration.dds",

	-- dragonknight
	"ability_dragonknight_001_blue.dds",
	"ability_dragonknight_002_blue.dds",
	"ability_dragonknight_003_blue.dds",
	"ability_dragonknight_003_emerald.dds",
	"ability_dragonknight_004_blue.dds",
	"ability_dragonknight_004_emerald.dds",
	"ability_dragonknight_005_blue.dds",
	"ability_dragonknight_006_blue.dds",
	"ability_dragonknight_007_blue.dds",
	"ability_dragonknight_008_blue.dds",
	"ability_dragonknight_009_blue.dds",
	"ability_dragonknight_009_nocturnal.dds",
	"ability_dragonknight_010_blue.dds",
	"ability_dragonknight_011_blue.dds",
	"ability_dragonknight_012_blue.dds",
	"ability_dragonknight_013_blue.dds",
	"ability_dragonknight_013_stonefist_blue.dds",
	"ability_dragonknight_014_blue.dds",
	"ability_dragonknight_015_blue.dds",
	"ability_dragonknight_015_noweaponswap.dds",
	"ability_dragonknight_016_blue.dds",
	"ability_dragonknight_017_blue.dds",
	"ability_dragonknight_018_blue.dds",
	"ability_dragonknight_018_emerald.dds",
	"u49_ability_dragonknight_ashcloud.dds",
	"u49_ability_dragonknight_darktalons.dds",
	"u49_ability_dragonknight_dragonblood.dds",
	"u49_ability_dragonknight_dragonleap.dds",
	"u49_ability_dragonknight_fierygrip.dds",
	"u49_ability_dragonknight_inferno.dds",
	"u49_ability_dragonknight_inhale.dds",
	"u49_ability_dragonknight_obsidianshield.dds",
	"u49_ability_dragonknight_petrify.dds",
	"u49_ability_dragonknight_protectivescale.dds",
	"u49_ability_dragonknight_searingstrike.dds",
	"u49_ability_dragonknight_standard.dds",
	"u49_ability_dragonknight_stonefist.dds",

	-- necromancer
	"ability_necromancer_001_red.dds",
	"ability_necromancer_004_fireytorment.dds",
	"ability_necromancer_006_red.dds",
	"ability_necromancer_007_red.dds",
	"ability_necromancer_008_red.dds",
	"ability_necromancer_013_red.dds",

	-- nightblade
	"ability_nightblade_001_sagecyan.dds",
	"ability_nightblade_002_purple.dds",
	"ability_nightblade_002_strikinggold.dds",
	"ability_nightblade_003_purple.dds",
	"ability_nightblade_005_jadegreen.dds",
	"ability_nightblade_005_malacathsfury.dds",
	"ability_nightblade_007_purple.dds",
	"ability_nightblade_007_strikinggold.dds",
	"ability_nightblade_012_violet.dds",
	"ability_nightblade_017_purple.dds",
	"u49_ability_shadowcloak_dawn.dds",

	-- sorcerer
	"ability_sorcerer_daedric_curse_red.dds",
	"ability_sorcerer_dark_exchange_red.dds",
	"ability_sorcerer_lightning_form_red.dds",
	"ability_sorcerer_lightning_prey_redcelestial.dds",
	"ability_sorcerer_mage_fury_red.dds",
	"ability_sorcerer_overload_lightningyellow.dds",
	"ability_sorcerer_surge_fieryyellow.dds",
	"ability_sorcerer_thunderclap_red.dds",
	"u49_ability_stormcalling_lightningform_celestial.dds",

	-- templar
	"ability_templar_backlash_blue.dds",
	"ability_templar_cleansing_ritual_blue.dds",
	"ability_templar_over_exposure_blue.dds",
	"ability_templar_rushed_ceremony_blue.dds",
	"ability_templar_sun_strike_fierytorment.dds",
	"ability_templar_trained_attacker_blue.dds",
	"ability_templar_trained_attacker_winddragon.dds",

	-- warden
	"ability_warden_001_orange.dds",
	"ability_warden_003_orange.dds",
	"ability_warden_007_orange.dds",
	"ability_warden_008_orange.dds",
	"ability_warden_013_crow.dds",
	"ability_warden_014_crows.dds",
	"ability_warden_015_orange.dds",
	"ability_warden_018_grey.dds",
	"ability_warden_018_polar.dds",

	-- ========================================================================
	-- WEAPONS
	-- ========================================================================

	-- 1h & shield
	"ability_1handed_001_orange.dds",
	"ability_1handed_001_red.dds",
	"ability_1handed_002_lava.dds",
	"ability_1handed_003_dragonclash.dds",
	"ability_1handed_004_spellbreaker.dds",
	"ability_1handed_005_moltenmight.dds",

	-- 2h
	"ability_2handed_001_green.dds",
	"ability_2handed_002_blue.dds",
	"ability_2handed_002_red.dds",
	"ability_2handed_003_ice.dds",
	"ability_2handed_003_vividpurple.dds",
	"ability_2handed_004_red.dds",
	"ability_2handed_005_yellow.dds",
	"u49_ability_reverseslash_namirashunger.dds",

	-- bow
	"ability_bow_001_red.dds",
	"ability_bow_001_rose.dds",
	"ability_bow_001_yellow.dds",
	"ability_bow_002_red.dds",
	"ability_bow_003_ice.dds",
	"ability_bow_003_meteors.dds",
	"ability_bow_005_goldcoin.dds",

	-- destruction staff
	"ability_destructionstaff_001_blackcore.dds",
	"ability_destructionstaff_001_bluewhite.dds",
	"ability_destructionstaff_002_floral.dds",
	"ability_destructionstaff_002_green.dds",
	"ability_destructionstaff_002_purple.dds",
	"ability_destructionstaff_005_green.dds",
	"ability_destructionstaff_011_orange.dds",
	"ability_destructionstaff_011_purple.dds",
	"ability_destructionstaff_012_padomayvortex.dds",
	"ability_destructionstaff_012_purple.dds",

	-- dual wield
	"ability_dualwield_001_goldcoin.dds",
	"ability_dualwield_001_purple.dds",
	"ability_dualwield_002_peryite.dds",
	"ability_dualwield_004_jadearrow.dds",
	"ability_dualwield_004_mirrormoor.dds",
	"ability_dualwield_004_strikinggold.dds",
	"ability_dualwield_005_jadegreen.dds",
	"ability_dualwield_005_orange.dds",
	"ability_dualwield_005_red.dds",
	"u49_ability_dualwield_whirlwind_blacksands.dds",

	-- restoration staff
	"ability_restorationstaff_001_green.dds",
	"ability_restorationstaff_002_blue.dds",
	"ability_restorationstaff_002_purple.dds",
	"ability_restorationstaff_002_radianceofanu.dds",
	"ability_restorationstaff_003_blue.dds",
	"ability_restorationstaff_004_purple.dds",
	"ability_restorationstaff_004_water.dds",
	"u49_ability_blessingofprotection.dds",

	-- ========================================================================
	-- GUILDS
	-- ========================================================================

	-- fighters guild
	"ability_fightersguild_002_red.dds",
	"ability_fightersguild_003_gold.dds",
	"ability_fightersguild_004_orange.dds",
	"ability_fightersguild_005_darkpurple.dds",
	"ability_fightersguild_005_yellow.dds",
	"u49_ability_circleofprotection_fightersguild.dds",
	"u49_ability_silverbolts_fightersguild.dds",

	-- mages guild
	"ability_mageguild_001_white.dds",
	"ability_mageguild_002_floral.dds",
	"ability_mageguild_002_green.dds",
	"ability_mageguild_004_purple.dds",
	"ability_mageguild_004_yellow.dds",
	"ability_mageguild_005_ice.dds",
	"ability_mageguild_005_orange.dds",

	-- psijic order
	"ability_psijic_001_purple.dds",
	"ability_psijic_005_purple.dds",

	-- ========================================================================
	-- OTHERS
	-- ========================================================================

	-- armor
	"ability_armor_002_sagecyan.dds",
	"ability_armor_003_yellow.dds",

	-- alliance war (ava)
	"ability_ava_001_bones.dds",
	"ability_ava_003_orange.dds",
	"ability_ava_003_shell.dds",
	"ability_ava_006_blue.dds",
	"ability_ava_006_green.dds",
	"ability_ava_revealing_flare_orange.dds",
	"ability_ava_vigor_blue.dds",
	"ability_ava_vigor_green.dds",
	"u49_ability_assault_vigor_dawn.dds",
	"u49_ability_assault_vigor_dusk.dds",

	-- soul magic
	"ability_soulmagic_001_purple.dds",
	"ability_soulmagic_001_red.dds",
	"ability_soulmagic_001_wormwrithe.dds",

	-- vampire
	"ability_u26_vampire_01_purple.dds",
	"ability_u26_vampire_05_purple.dds",

	-- werewolf
	"ability_werewolf_001_ashen.dds",
	"ability_werewolf_001_black.dds",
	"ability_werewolf_001_ragefire.dds",
	"ability_werewolf_001_red.dds",
	"ability_werewolf_001_white.dds",
	"ability_werewolf_003_green.dds",
	"ability_werewolf_006_green.dds",
	"ability_werewolf_gnash_dusk.dds",
	"u49_ability_werewolf_piercinghowl_dusk.dds",

}

local function InitializeSettings()
	SkillStyles_SV = ZO_SavedVars:NewAccountWide("SkillStyles_SavedVariables", SAVEDVARS_VERSION, nil, DEFAULTS)

	if not LAM2 then return end

	local panelData = {
		type = "panel",
		name = "Skill Styles",
		displayName = "|cffaa00SkillStyles|r",
		author = "|ce6202dKwiebe-Kwibus|r",
		version = tostring(GetAddOnVersion and GetAddOnVersion(ADDON_NAME) or ""),
		registerForRefresh = true,
		registerForDefaults = true,
	}

	LAM2:RegisterAddonPanel("SkillStyles_Panel", panelData)

	local optionsData = {
		{
			type = "dropdown",
			name = "Icon pack resolution",
			tooltip = "Select which resolution folder Skill Styles should use.",
			choices = { "64", "128", "256" },
			getFunc = function() return tostring(SkillStyles_SV.resolutionChoice) end,
			setFunc = function(value) SkillStyles_SV.resolutionChoice = value end,
			default = DEFAULTS.resolutionChoice,
			warning = "Requires /reloadui to apply the changes",
		},
		{
			type = "button",
			name = "Reload UI",
			width = "full",
			func = function() ReloadUI("ingame") end,
		},
	}

	LAM2:RegisterOptionControls("SkillStyles_Panel", optionsData)
end

-- Function to initialize icons
local function InitializeIcons()
    if AbilityIconsFramework and AbilityIconsFramework.AddCustomIconPack then
        -- Add the custom icon pack
        AbilityIconsFramework.AddCustomIconPack(GetAddOnIconsPath(), ADDON_ICONS)
    else
        d("SkillStyles: AbilityIconsFramework not found or incompatible!")
    end
end


-- Initialize icons when the addon is loaded
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
	InitializeSettings()
	InitializeIcons()
end)