-- KelaPadUI Fight Stats: Stats page. Your own fight, for every target or one
-- (the filter on X): your totals and share of the group's damage, your bars,
-- what matters for your role (offense, rotation, resources, healing,
-- mitigation), the essential buffs and debuffs, how your damage splits, and
-- damage, healing and damage taken by skill.

local UI = KPUI_FIGHT_STATS.UI
local STYLES, DIM_STYLE = UI.STYLES, UI.DIM_STYLE
local FormatNumber, FormatPercent = UI.FormatNumber, UI.FormatPercent
local GetSkillRows, GetDamageProfile, AddSkillBars = UI.GetSkillRows, UI.GetDamageProfile, UI.AddSkillBars
local AddDamageTypes, AddDamageMix, AddDeliverySection = UI.AddDamageTypes, UI.AddDamageMix, UI.AddDeliverySection
local GetUptimes, AddEffectSection, AddOffenseSection = UI.GetUptimes, UI.AddEffectSection, UI.AddOffenseSection
local AddResourcesSection, Sections = UI.AddResourcesSection, UI.Sections
local DEBUFFS, BUFFS, ROLE_TANK, ROLE_HEAL = UI.DEBUFFS, UI.BUFFS, UI.ROLE_TANK, UI.ROLE_HEAL

-- What you did, for the selection; with the group's total when it is known.
local function AddYourSummary(sheet, record, target, seconds)
	seconds = zo_max(seconds, 1)
	local damage = target and target.you or record.damageOut
	sheet:Heading(GetString(KELA_FIGHT_STATS_PERFORMANCE))
	sheet:Row(GetString(KELA_FIGHT_STATS_DAMAGE), FormatNumber(damage))
	sheet:Row(GetString(KELA_FIGHT_STATS_DPS), FormatNumber(damage / seconds), STYLES.ValueTimer)
	if not target and (record.healingOut or 0) > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_HEALING), FormatNumber(record.healingOut))
		sheet:Row(GetString(KELA_FIGHT_STATS_HPS), FormatNumber(record.hpsOut or record.healingOut / seconds))
	end
	local groupDamage = target and target.group or (not target and record.groupDamage) or nil
	if groupDamage and groupDamage > damage then
		sheet:Row(GetString(KELA_FIGHT_STATS_SHARE), FormatPercent(damage / groupDamage))
	end
end

-- Your healing by who received it.
local function AddYourHealing(sheet, detail)
	local healed = {}
	for name, entry in pairs(detail.yourHealing or {}) do
		healed[name] = entry.heal
	end
	Sections.AmountBars(sheet, GetString(KELA_FIGHT_STATS_YOUR_HEALING_BY_TARGET), healed, function(name)
		local entry = detail.yourHealing[name]
		if entry and entry.over > 0 then
			return FormatPercent(entry.over / (entry.heal + entry.over)) .. " " .. GetString(KELA_FIGHT_STATS_OVERHEALED)
		end
		return nil
	end)
end

local function BuildStatsPage(_, sheet, record)
	sheet:Clear({ 1, 1, 1.3 })
	UI.AddFightTitle(sheet, record)
	local detail = record.detail
	if not detail then
		sheet:Text(GetString(KELA_FIGHT_STATS_NO_DETAIL), DIM_STYLE)
		return
	end
	local target, _, targetLabel = UI.GetSelection(record)
	sheet:FilterBar({ { label = GetString(KELA_FIGHT_STATS_TARGET), value = targetLabel } })

	local fightSeconds = zo_max(record.dpsSeconds or detail.seconds or 1, 1)
	local seconds = target and target.seconds or fightSeconds
	-- Debuffs on the selected target; a target without its own tally (a fight
	-- saved before targets were tallied) uses the whole fight's.
	local debuffList, debuffSeconds = detail.effects and detail.effects.enemyDebuffs, detail.seconds
	if target and target.debuffs then
		debuffList, debuffSeconds = target.debuffs, target.seconds
	end
	local uptimes = GetUptimes(debuffList, debuffSeconds, DEBUFFS)

	-- Column 1: your totals, the bars, then what matters most for the role.
	AddYourSummary(sheet, record, target, seconds)
	Sections.Bars(sheet, detail)
	local offense = target and target.offense
	if not offense or next(offense) == nil then
		offense = detail.offense
	end
	local sections =
	{
		offense = function() AddOffenseSection(sheet, detail, offense, uptimes, true) end,
		mitigation = function() Sections.Mitigation(sheet, detail) end,
		healing = function() Sections.Healing(sheet, detail) end,
		rotation = function() Sections.Rotation(sheet, detail) end,
		resources = function() AddResourcesSection(sheet, detail) end,
	}
	local order = { "offense", "rotation", "resources", "healing", "mitigation" }
	if record.roleId == ROLE_TANK then
		order = { "mitigation", "offense", "rotation", "resources", "healing" }
	elseif record.roleId == ROLE_HEAL then
		order = { "healing", "resources", "rotation", "offense", "mitigation" }
	end
	for _, key in ipairs(order) do
		sections[key]()
	end

	-- Column 2: the effects that should be up.
	sheet:SetColumn(2)
	AddEffectSection(sheet, GetString(KELA_FIGHT_STATS_ESSENTIAL_DEBUFFS), GetString(KELA_FIGHT_STATS_DEBUFFS_ENEMY),
		DEBUFFS, debuffList, debuffSeconds, record.roleId, record.content)
	AddEffectSection(sheet, GetString(KELA_FIGHT_STATS_ESSENTIAL_BUFFS), GetString(KELA_FIGHT_STATS_BUFFS_SELF),
		BUFFS, detail.effects and detail.effects.selfBuffs, detail.seconds, record.roleId, record.content)

	-- Column 3: where your damage came from, by kind and by skill, then
	-- healing and damage taken.
	sheet:SetColumn(3)
	local skills = target and target.skills or detail.skills
	local rows = GetSkillRows(skills)
	local profile = GetDamageProfile(rows)
	if profile.total > 0 then
		AddDamageTypes(sheet, { skills = skills }, profile.total)
		AddDamageMix(sheet, profile)
		AddDeliverySection(sheet, profile)
	end
	AddSkillBars(sheet, GetString(KELA_FIGHT_STATS_DAMAGE_BY_SKILL), rows)
	if target and target.legacy then
		sheet:Paragraph(GetString(KELA_FIGHT_STATS_SKILLS_ALL_TARGETS), DIM_STYLE)
	end
	if not target then
		AddSkillBars(sheet, GetString(KELA_FIGHT_STATS_HEALING_BY_SKILL), GetSkillRows(detail.healSkills))
		AddYourHealing(sheet, detail)
		AddSkillBars(sheet, GetString(KELA_FIGHT_STATS_DAMAGE_TAKEN_BY_SKILL), GetSkillRows(detail.takenSkills))
	end
end

local function GetStatsActions(_, record)
	if not record.detail then
		return {}
	end
	return { UI.TargetAction(record) }
end

KPUI_FIGHT_STATS.Pages = KPUI_FIGHT_STATS.Pages or {}
KPUI_FIGHT_STATS.Pages.Stats = { name = KELA_FIGHT_STATS_STATS, Build = BuildStatsPage, Actions = GetStatsActions }
