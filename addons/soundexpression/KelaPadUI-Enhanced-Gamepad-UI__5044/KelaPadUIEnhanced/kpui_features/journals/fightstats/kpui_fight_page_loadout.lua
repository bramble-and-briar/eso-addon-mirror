-- KelaPadUI Fight Stats: Loadout page. Your character sheet for the fight:
-- race, class, role, attributes, class skill lines and mastery, the skill bars
-- with scribed scripts, mundus, food and potions, the gear (weights, weapons,
-- sets, then every piece with its trait and enchant) and the champion stars.
-- Y picks a group member instead: the game does not share their gear or
-- skills, so it shows what is known, the class skill lines they share through
-- LibGroupCombatStats and the gear sets their buffs point to.

local UI = KPUI_FIGHT_STATS.UI
local COLORS, DIM_STYLE, STYLE_BAD = UI.COLORS, UI.DIM_STYLE, UI.STYLE_BAD
local EnumText, Join, GetNameWithAccount = UI.EnumText, UI.Join, UI.GetNameWithAccount
local GetRaceText, GetClassText, GetRoleText = UI.GetRaceText, UI.GetClassText, UI.GetRoleText
local MODE_LOADOUT = UI.MODE_LOADOUT

local Loadout = {}
KPUI_FIGHT_STATS.Loadout = Loadout
do
	local ARMOR_SLOTS =
	{
		EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND,
		EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
	}
	local ARMOR_TYPES = { ARMORTYPE_LIGHT, ARMORTYPE_MEDIUM, ARMORTYPE_HEAVY }

	-- Pieces of each armor weight, as "Light x2".
	local function GetArmorWeightText(equip)
		local counts = {}
		for _, slot in ipairs(ARMOR_SLOTS) do
			local link = equip[slot]
			if link then
				local armorType = GetItemLinkArmorType(link)
				counts[armorType] = (counts[armorType] or 0) + 1
			end
		end
		local parts = {}
		for _, armorType in ipairs(ARMOR_TYPES) do
			if counts[armorType] then
				parts[#parts + 1] = EnumText("SI_ARMORTYPE", armorType) .. " x" .. counts[armorType]
			end
		end
		return table.concat(parts, ", ")
	end

	local TWO_HANDED_WEAPONS =
	{
		[WEAPONTYPE_TWO_HANDED_AXE] = true,
		[WEAPONTYPE_TWO_HANDED_HAMMER] = true,
		[WEAPONTYPE_TWO_HANDED_SWORD] = true,
	}

	-- The game names a two-handed mace just "Mace"; the equip type tells it apart.
	local function GetWeaponTypeText(weaponType)
		local text = EnumText("SI_WEAPONTYPE", weaponType)
		if TWO_HANDED_WEAPONS[weaponType] then
			text = EnumText("SI_EQUIPTYPE", EQUIP_TYPE_TWO_HAND) .. " " .. text
		end
		return text
	end

	-- The weapons of one bar, as "Two-Handed Mace" or "Sword + Shield".
	local function GetWeaponText(equip, mainSlot, offSlot)
		local parts = {}
		for _, slot in ipairs({ mainSlot, offSlot }) do
			local link = equip[slot]
			if link then
				local weaponType = GetItemLinkWeaponType(link)
				if weaponType ~= WEAPONTYPE_NONE then
					parts[#parts + 1] = GetWeaponTypeText(weaponType)
				end
			end
		end
		return table.concat(parts, " + ")
	end

	local function GetItemSubText(link)
		local parts = {}
		local trait = GetItemLinkTraitType(link)
		if trait and trait ~= ITEM_TRAIT_TYPE_NONE then
			parts[#parts + 1] = GetString("SI_ITEMTRAITTYPE", trait)
		end
		local _, enchant = GetItemLinkEnchantInfo(link)
		if enchant and enchant ~= "" then
			parts[#parts + 1] = zo_strformat("<<1>>", enchant)
		end
		return Join(parts)
	end

	local function GetItemNameText(link)
		local quality = GetItemLinkDisplayQuality(link)
		return GetItemQualityColor(quality):Colorize(zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link)))
	end

	local function GetScriptsText(scripts)
		local names = {}
		if scripts then
			for index = 1, 3 do
				if scripts[index] and scripts[index] > 0 then
					names[#names + 1] = GetCraftedAbilityScriptDisplayName(scripts[index])
				end
			end
		end
		return table.concat(names, " / ")
	end

	-- Race, class, role, level and champion points sit in the page's header.
	local function GetLoadoutSubText(record)
		local parts = { GetRaceText(record), GetClassText(record), GetRoleText(record) }
		if record.level then
			parts[#parts + 1] = GetString(KELA_FIGHT_STATS_LEVEL) .. " " .. record.level
		end
		if record.championPoints and record.championPoints > 0 then
			parts[#parts + 1] = GetString(KELA_FIGHT_STATS_CP) .. " " .. record.championPoints
		end
		return Join(parts)
	end

	-- The game's own colours for the three champion trees: Warfare is the magicka
	-- tree, Fitness the health tree, Craft the stamina tree. The attributes use the
	-- same colours.
	local RED, BLUE, GREEN = ZO_ColorDef:New("E05555"), ZO_ColorDef:New("5C9EED"), ZO_ColorDef:New("6CC66A")
	local CHAMPION_STYLES =
	{
		[CHAMPION_DISCIPLINE_TYPE_COMBAT] = { color = BLUE, icon = "EsoUI/Art/Champion/champion_points_magicka_icon.dds" },
		[CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = { color = RED, icon = "EsoUI/Art/Champion/champion_points_health_icon.dds" },
		[CHAMPION_DISCIPLINE_TYPE_WORLD] = { color = GREEN, icon = "EsoUI/Art/Champion/champion_points_stamina_icon.dds" },
	}

	-- "35 Health / 29 Magicka / 0 Stamina", each in its colour.
	local function GetAttributesText(loadout)
		if not loadout or not loadout.health then
			return ""
		end
		local parts = {}
		for _, attribute in ipairs({
			{ loadout.health, RED, COMBAT_MECHANIC_FLAGS_HEALTH },
			{ loadout.magicka, BLUE, COMBAT_MECHANIC_FLAGS_MAGICKA },
			{ loadout.stamina, GREEN, COMBAT_MECHANIC_FLAGS_STAMINA },
		}) do
			parts[#parts + 1] = attribute[2]:Colorize((attribute[1] or 0) .. " " .. EnumText("SI_COMBATMECHANICFLAGS", attribute[3]))
		end
		return table.concat(parts, " / ")
	end

	-- The class skill lines by name, then the class mastery passives.
	local function AddSkillLines(sheet, ids, mastery)
		local lines = {}
		for index = 1, 3 do
			local id = ids[index]
			if id and id > 0 then
				lines[#lines + 1] = zo_strformat(SI_SKILLS_ENTRY_NAME_FORMAT, GetSkillLineNameById(id))
			end
		end
		if #lines > 0 then
			sheet:Heading(GetString(KELA_FIGHT_STATS_SKILL_LINES))
			for _, line in ipairs(lines) do
				sheet:Text(line)
			end
		end
		if mastery and #mastery > 0 then
			sheet:Heading(GetString(KELA_FIGHT_STATS_CLASS_MASTERY))
			for _, abilityId in ipairs(mastery) do
				sheet:IconRow(GetAbilityIcon(abilityId), zo_strformat(SI_ABILITY_NAME, GetAbilityName(abilityId)))
			end
		end
	end

	local function AddSkillLinesSection(sheet, loadout)
		AddSkillLines(sheet, loadout.skillLines, loadout.mastery)
	end

	-- The names of the buffs behind some ability ids, joined.
	local function GetBuffNames(entries, idOf)
		local names = {}
		for _, entry in ipairs(entries or {}) do
			local id = idOf(entry)
			if id then
				names[#names + 1] = zo_strformat(SI_ABILITY_NAME, GetAbilityName(id))
			end
		end
		return table.concat(names, ", ")
	end

	local function AddGearSection(sheet, loadout, prep)
		sheet:Heading(GetString(KELA_FIGHT_STATS_GEAR))
		local armor = GetArmorWeightText(loadout.equip)
		if armor ~= "" then
			sheet:Row(GetString(KELA_FIGHT_STATS_ARMOR), armor)
		end
		local front = GetWeaponText(loadout.equip, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND)
		if front ~= "" then
			sheet:Row(zo_strformat(GetString(KELA_FIGHT_STATS_BAR), 1), front)
		end
		local back = GetWeaponText(loadout.equip, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF)
		if back ~= "" then
			sheet:Row(zo_strformat(GetString(KELA_FIGHT_STATS_BAR), 2), back)
		end
		for _, set in ipairs(loadout.sets) do
			sheet:Row(set.name, "x" .. set.count)
		end
		-- Preparation shows red when missing: a fight without them is worth knowing.
		if prep then
			local mundus = GetBuffNames(prep.mundus, function(id)
				return id
			end)
			sheet:Row(GetString(KELA_FIGHT_STATS_MUNDUS), mundus ~= "" and mundus or GetString(KELA_FIGHT_STATS_NONE), mundus == "" and STYLE_BAD or nil)
			if prep.foodKnown then
				local food = GetBuffNames(prep.food, function(entry)
					return entry.id
				end)
				sheet:Row(GetString(KELA_FIGHT_STATS_FOOD_DRINK), food ~= "" and food or GetString(KELA_FIGHT_STATS_NONE), food == "" and STYLE_BAD or nil)
			end
		end
	end

	-- Mundus stone, food, drink and the potions used, for the Loadout page.
	local function AddPrepSection(sheet, prep)
		if not prep then
			return
		end
		sheet:Heading(GetString(KELA_FIGHT_STATS_PREP))
		local any = false
		for _, abilityId in ipairs(prep.mundus or {}) do
			any = true
			sheet:IconRow(GetAbilityIcon(abilityId), zo_strformat(SI_ABILITY_NAME, GetAbilityName(abilityId)), nil, GetString(KELA_FIGHT_STATS_MUNDUS))
		end
		for _, entry in ipairs(prep.food or {}) do
			any = true
			sheet:IconRow(GetAbilityIcon(entry.id), zo_strformat(SI_ABILITY_NAME, GetAbilityName(entry.id)), nil, GetString(entry.drink and KELA_FIGHT_STATS_DRINK or KELA_FIGHT_STATS_FOOD))
		end
		for _, entry in ipairs(prep.potions or {}) do
			any = true
			sheet:IconRow(GetItemLinkIcon(entry.link), zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(entry.link)), nil, "x" .. entry.count)
		end
		if not any then
			sheet:Text(GetString(KELA_FIGHT_STATS_NONE), DIM_STYLE)
		end
	end

	-- The slotted stars of each tree, with what the game says each gave at the
	-- points you had.
	local function AddChampionSection(sheet, loadout)
		sheet:Heading(GetString(KELA_FIGHT_STATS_CHAMPION))
		if #loadout.champion == 0 then
			sheet:Text(GetString(KELA_FIGHT_STATS_NONE), DIM_STYLE)
			return
		end
		for _, discipline in ipairs(loadout.champion) do
			local style = CHAMPION_STYLES[GetChampionDisciplineType(discipline.id)] or { color = COLORS.COLOR_WHITE }
			local name = zo_strformat(SI_CHAMPION_CONSTELLATION_NAME_FORMAT, GetChampionDisciplineName(discipline.id))
			sheet:Space(8)
			sheet:IconRow(style.icon, style.color:Colorize(name), nil, style.color:Colorize(tostring(discipline.total)))
			for _, star in ipairs(discipline.stars) do
				if star.slotted then
					sheet:IconRow(nil, style.color:Colorize(zo_strformat(SI_CHAMPION_STAR_NAME, GetChampionSkillName(star.id))),
						GetChampionSkillCurrentBonusText(star.id, star.points), style.color:Colorize(tostring(star.points)))
				end
			end
		end
	end

	-- Weapons first, then armor from head to feet, then jewelry.
	local EQUIPMENT_ORDER =
	{
		EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
		EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HAND,
		EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
		EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
	}

	-- Armor weight at the start of the trait line: [M] medium green, [L] light
	-- blue, [H] heavy red (the same colours as the attributes they build on).
	local WEIGHT_TAGS =
	{
		[ARMORTYPE_MEDIUM] = GREEN:Colorize("[M]"),
		[ARMORTYPE_LIGHT] = BLUE:Colorize("[L]"),
		[ARMORTYPE_HEAVY] = RED:Colorize("[H]"),
	}

	local function GetEquipmentSubText(link)
		local text = GetItemSubText(link)
		local tag = WEIGHT_TAGS[GetItemLinkArmorType(link)]
		if tag then
			return text ~= "" and (tag .. " " .. text) or tag
		end
		return text
	end

	local function AddEquipmentSection(sheet, loadout)
		sheet:Heading(GetString(KELA_FIGHT_STATS_EQUIPMENT))
		for _, slot in ipairs(EQUIPMENT_ORDER) do
			local link = loadout.equip[slot]
			if link then
				sheet:IconRow(GetItemLinkIcon(link), GetItemNameText(link), GetEquipmentSubText(link))
			end
		end
	end

	-- Slots 1 and 2 are the light and heavy attack; the rest are skills and the ultimate.
	local FIRST_SKILL_SLOT, LAST_SKILL_SLOT = 3, 8

	local function AddSkillsSection(sheet, loadout)
		local bars = {}
		for bar in pairs(loadout.bars) do
			bars[#bars + 1] = bar
		end
		table.sort(bars)
		for _, bar in ipairs(bars) do
			sheet:Heading(zo_strformat(GetString(KELA_FIGHT_STATS_BAR), bar))
			for slot = FIRST_SKILL_SLOT, LAST_SKILL_SLOT do
				local abilityId = loadout.bars[bar][slot]
				if abilityId and abilityId > 0 then
					sheet:IconRow(GetAbilityIcon(abilityId), zo_strformat(SI_ABILITY_NAME, GetAbilityName(abilityId)), GetScriptsText(loadout.scribed[abilityId]))
				end
			end
		end
	end

	-- A group member: only what the game and their add-ons share.
	local function BuildMemberLoadout(sheet, record, name)
		local detail = record.detail
		local info = detail.roster[name] or {}
		sheet:Title(GetNameWithAccount(name, info.account), GetLoadoutSubText(info), UI.GetClassIcon(info.classId))
		local any = false
		if info.skillLines then
			AddSkillLines(sheet, info.skillLines)
			any = true
		end
		sheet:SetColumn(2)
		any = UI.AddSetsSeen(sheet, detail, name) or any
		if not any then
			sheet:SetColumn(1)
		end
		sheet:Paragraph(GetString(KELA_FIGHT_STATS_MEMBER_LOADOUT_NOTE), DIM_STYLE)
	end

	local function BuildLoadoutPage(_, sheet, record)
		sheet:Clear({ 1, 1.1, 1 })
		local _, member = UI.GetSelection(record, MODE_LOADOUT)
		if member then
			BuildMemberLoadout(sheet, record, member)
			return
		end
		local loadout = record.loadout
		sheet:Title(GetNameWithAccount(record.character, record.account), Join({ GetLoadoutSubText(record), GetAttributesText(loadout) }), record.classIcon)
		if not loadout then
			sheet:Text(GetString(KELA_FIGHT_STATS_NO_LOADOUT), DIM_STYLE)
			return
		end
		AddSkillLinesSection(sheet, loadout)
		AddSkillsSection(sheet, loadout)
		AddPrepSection(sheet, record.detail and record.detail.prep)
		sheet:SetColumn(2)
		AddGearSection(sheet, loadout, nil)
		AddEquipmentSection(sheet, loadout)
		sheet:SetColumn(3)
		AddChampionSection(sheet, loadout)
	end

	-- Y picks you or a group member.
	local function GetLoadoutActions(_, record)
		if not (record.detail and record.detail.roster and next(record.detail.roster) ~= nil) then
			return {}
		end
		return { [2] = UI.CharacterAction(record, MODE_LOADOUT) }
	end

	Loadout.SkillLines = AddSkillLines
	KPUI_FIGHT_STATS.Pages = KPUI_FIGHT_STATS.Pages or {}
	KPUI_FIGHT_STATS.Pages.Loadout = { name = KELA_FIGHT_STATS_LOADOUT, Build = BuildLoadoutPage, Actions = GetLoadoutActions }
end

