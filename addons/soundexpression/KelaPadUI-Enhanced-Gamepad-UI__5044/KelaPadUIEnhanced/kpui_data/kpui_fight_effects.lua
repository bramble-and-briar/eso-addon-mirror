-- KelaPadUI Fight Stats: the buffs and debuffs the Stats and Group pages know.
--
-- Each entry is one effect as the game applies it. Weapon and spell versions of
-- the same buff are one entry with two aliases (Major Brutality and Major
-- Sorcery): the game counts weapon and spell damage and critical at whichever
-- is higher, so whichever of the two was up longer is the entry's uptime.
--
-- An effect is recognised, in this order, by
--   * `ids`: ability ids known to be right (read from Combat Metrics and
--     HodorReflexes); the game names them in the client's language;
--   * `name`: the English name, for every other source of the same effect;
--   * `icon`: the file name of the effect's icon, which is the same in every
--     language, so effects without a known id are found on any client.
--
-- `pen` and `crit` are what an enemy debuff takes off the target's resistance
-- and adds to critical damage; `status` marks a status effect, which only
-- counts with the Force of Nature champion star (LibCombat's star 276).
-- `roles` limits an essential effect to the roles it matters to (any role when
-- absent); `monsters` marks one that does nothing against players.

local DD, TANK, HEAL = LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL

KPUI_FIGHT_EFFECTS =
{
	debuffs =
	{
		{ key = "majorBreach", aliases = { { name = "Major Breach", ids = { 61743 } } }, pen = 5948, essential = true },
		{ key = "minorBreach", aliases = { { name = "Minor Breach", ids = { 61742 } } }, pen = 2974, essential = true },
		{ key = "majorVulnerability", aliases = { { name = "Major Vulnerability", ids = { 106754 } } }, essential = true },
		{ key = "minorVulnerability", aliases = { { name = "Minor Vulnerability", ids = { 79717 } } }, essential = true },
		{ key = "minorBrittle", aliases = { { name = "Minor Brittle", ids = { 145975 } } }, crit = 10, essential = true },
		{ key = "taunt", aliases = { { name = "Taunt", ids = { 38254 } } }, essential = true, roles = { TANK } },
		{ key = "majorMaim", aliases = { { name = "Major Maim", icon = "ability_debuff_major_maim" } }, essential = true, roles = { TANK } },
		{ key = "minorMaim", aliases = { { name = "Minor Maim", icon = "ability_debuff_minor_maim" } }, essential = true, roles = { TANK } },
		{ key = "majorCowardice", aliases = { { name = "Major Cowardice", icon = "ability_debuff_major_cowardice" } }, essential = true, roles = { TANK } },
		{ key = "minorCowardice", aliases = { { name = "Minor Cowardice", icon = "ability_debuff_minor_cowardice" } }, essential = true, roles = { TANK } },
		{ key = "majorBrittle", aliases = { { name = "Major Brittle", ids = { 145977 } } }, crit = 20 },
		{ key = "elementalCatalyst", aliases = { { name = "Elemental Catalyst", ids = { 181606 } } }, crit = 15 },
		{ key = "crusher", aliases = { { name = "Crusher", ids = { 17906 } } }, pen = 2108 },
		{ key = "alkosh", aliases = { { name = "Roar of Alkosh", ids = { 76667 } } }, pen = 6000 },
		{ key = "tremorscale", aliases = { { name = "Tremorscale", ids = { 80866 } } }, pen = 2640 },
		{ key = "crystalWeapon", aliases = { { name = "Crystal Weapon", ids = { 143808 } } }, pen = 1000 },
		{ key = "crimsonOath", aliases = { { name = "Crimson Oath's Rive", ids = { 159288 } }, { name = "Crimson Oath" } }, pen = 3541 },
		{ key = "runicSunder", aliases = { { name = "Runic Sunder", ids = { 187742 } } }, pen = 2200 },
		{ key = "flameWeakness", aliases = { { name = "Flame Weakness", ids = { 142610 } } }, crit = 5 },
		{ key = "shockWeakness", aliases = { { name = "Shock Weakness", ids = { 142653 } } }, crit = 5 },
		{ key = "frostWeakness", aliases = { { name = "Frost Weakness", ids = { 142652 } } }, crit = 5 },
		-- Status effects take 660 penetration off each, with Force of Nature only.
		{ key = "overcharged", aliases = { { name = "Overcharged", ids = { 178118 } } }, pen = 660, status = true },
		{ key = "burning", aliases = { { name = "Burning", ids = { 18084 } } }, pen = 660, status = true },
		{ key = "chilled", aliases = { { name = "Chilled", ids = { 95136 } } }, pen = 660, status = true },
		{ key = "concussion", aliases = { { name = "Concussion", ids = { 95134 } } }, pen = 660, status = true },
		{ key = "sundered", aliases = { { name = "Sundered", ids = { 178123 } } }, pen = 660, status = true },
		{ key = "poisoned", aliases = { { name = "Poisoned", ids = { 21929 } } }, pen = 660, status = true },
		{ key = "diseased", aliases = { { name = "Diseased", ids = { 178127 } } }, pen = 660, status = true },
		{ key = "hemorrhaging", aliases = { { name = "Hemorrhaging", ids = { 148801 } } }, pen = 660, status = true },
	},

	buffs =
	{
		{ key = "majorForce", aliases = { { name = "Major Force", ids = { 61747 } } }, essential = true, roles = { DD } },
		{ key = "minorForce", aliases = { { name = "Minor Force", icon = "ability_buff_minor_force" } }, essential = true, roles = { DD } },
		-- Weapon and spell damage: one buff, the higher of the two.
		{
			key = "majorBrutalitySorcery",
			aliases =
			{
				{ name = "Major Brutality", icon = "ability_buff_major_brutality" },
				{ name = "Major Sorcery", icon = "ability_buff_major_sorcery" },
			},
			essential = true, roles = { DD },
		},
		{
			key = "minorBrutalitySorcery",
			aliases =
			{
				{ name = "Minor Brutality", icon = "ability_buff_minor_brutality" },
				{ name = "Minor Sorcery", icon = "ability_buff_minor_sorcery" },
			},
		},
		{ key = "majorBerserk", aliases = { { name = "Major Berserk", ids = { 61745 } } }, essential = true, roles = { DD } },
		{ key = "minorBerserk", aliases = { { name = "Minor Berserk", icon = "ability_buff_minor_berserk" } }, essential = true, roles = { DD } },
		-- Weapon and spell critical: one buff, the higher of the two.
		{
			key = "majorSavageryProphecy",
			aliases =
			{
				{ name = "Major Savagery", icon = "ability_buff_major_savagery" },
				{ name = "Major Prophecy", icon = "ability_buff_major_prophecy" },
			},
			essential = true, roles = { DD },
		},
		{
			key = "minorSavageryProphecy",
			aliases =
			{
				{ name = "Minor Savagery", ids = { 61898 } },
				{ name = "Minor Prophecy", icon = "ability_buff_minor_prophecy" },
			},
			essential = true, roles = { DD },
		},
		{ key = "majorCourage", aliases = { { name = "Major Courage", icon = "ability_buff_major_courage" } }, essential = true, roles = { DD, HEAL } },
		{ key = "minorCourage", aliases = { { name = "Minor Courage", icon = "ability_buff_minor_courage" } }, essential = true, roles = { DD, HEAL } },
		{ key = "majorSlayer", aliases = { { name = "Major Slayer", ids = { 93109 } } }, essential = true, roles = { DD }, monsters = true },
		{ key = "minorSlayer", aliases = { { name = "Minor Slayer", icon = "ability_buff_minor_slayer" } }, essential = true, roles = { DD }, monsters = true },
		{ key = "majorResolve", aliases = { { name = "Major Resolve", icon = "ability_buff_major_resolve" } }, essential = true, roles = { TANK, HEAL } },
		{ key = "minorResolve", aliases = { { name = "Minor Resolve", icon = "ability_buff_minor_resolve" } }, essential = true, roles = { TANK } },
		{ key = "majorProtection", aliases = { { name = "Major Protection", icon = "ability_buff_major_protection" } }, essential = true, roles = { TANK } },
		{ key = "minorProtection", aliases = { { name = "Minor Protection", icon = "ability_buff_minor_protection" } }, essential = true, roles = { TANK } },
		{ key = "majorMending", aliases = { { name = "Major Mending", icon = "ability_buff_major_mending" } }, essential = true, roles = { HEAL } },
		{ key = "minorMending", aliases = { { name = "Minor Mending", icon = "ability_buff_minor_mending" } }, essential = true, roles = { HEAL } },
	},
}
