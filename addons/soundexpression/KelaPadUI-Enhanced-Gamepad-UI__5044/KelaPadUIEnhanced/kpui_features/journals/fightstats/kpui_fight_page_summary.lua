-- KelaPadUI Fight Stats: Summary page. The fight at a glance, on one screen:
--
--   1. the totals LibCombat gives, how your damage split, and your top skills;
--   2. what our own calculations say about how it was played: offense against
--      the caps, rotation, and resources that ran low;
--   3. the group (or your targets), the essential effects that were missing
--      most of the fight, and your mundus stone and food.
--
-- Every block is a few rows with a fixed limit, so the page fits without
-- scrolling; the other pages have the detail.

local UI = KPUI_FIGHT_STATS.UI
local Effects = KPUI_FIGHT_STATS.Effects
local STYLES, COLORS, DIM_STYLE = UI.STYLES, UI.COLORS, UI.DIM_STYLE
local STYLE_BAD, STYLE_WARN = UI.STYLE_BAD, UI.STYLE_WARN
local FormatNumber, FormatPercent, FormatDuration = UI.FormatNumber, UI.FormatPercent, UI.FormatDuration
local GetTotalWithRate, EnumText, Join = UI.GetTotalWithRate, UI.EnumText, UI.Join
local GetSkillRows, GetDamageProfile = UI.GetSkillRows, UI.GetDamageProfile
local GetUptimes, AddOffenseSection = UI.GetUptimes, UI.AddOffenseSection
local CountEssential, EssentialRow = UI.CountEssential, UI.EssentialRow
local GetMemberNames, GetSharedDps = UI.GetMemberNames, UI.GetSharedDps
local DEBUFFS, BUFFS, STATE_DEAD, KIND_MATCH = UI.DEBUFFS, UI.BUFFS, UI.STATE_DEAD, UI.KIND_MATCH
local ROLE_HEAL = UI.ROLE_HEAL

local MAX_TOP_SKILLS = 3
local MAX_TOP_DPS = 4
local MAX_TARGETS = 3
local MAX_MISSING = 4
-- An essential effect up for less than this share of the fight is named.
local MISSING_UPTIME = 0.5
-- A resource under a tenth of its maximum for more than this share is named.
local LOW_RESOURCE_SHARE = 0.1

local function CountDeaths(detail, characterName)
	local you, group = 0, 0
	for _, death in ipairs(detail and detail.deaths or {}) do
		if death.state == STATE_DEAD then
			if death.name == characterName then
				you = you + 1
			else
				group = group + 1
			end
		end
	end
	return you, group
end

-- Column 1 --------------------------------------------------------------------------

local function AddPerformance(sheet, record)
	sheet:Heading(GetString(KELA_FIGHT_STATS_PERFORMANCE))
	sheet:Row(GetString(KELA_FIGHT_STATS_DAMAGE), GetTotalWithRate(record.damageOut, record.dpsOut), STYLES.ValueTimer)
	if record.singleDamage and (record.singleBoss or record.singleDamage < record.damageOut) then
		sheet:Row(GetString(record.singleBoss and KELA_FIGHT_STATS_BOSS_DAMAGE or KELA_FIGHT_STATS_SINGLE_TARGET),
			GetTotalWithRate(record.singleDamage, record.singleDps))
	end
	if (record.healingOut or 0) > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_HEALING), GetTotalWithRate(record.healingOut, record.hpsOut))
	end
	sheet:Row(GetString(KELA_FIGHT_STATS_DAMAGE_TAKEN), GetTotalWithRate(record.damageIn, record.dpsIn))
	sheet:Row(GetString(KELA_FIGHT_STATS_DURATION), FormatDuration(record.duration))
	if record.detail then
		local you, group = CountDeaths(record.detail, record.character)
		local text = group > 0 and (you .. "  (" .. GetString(KELA_FIGHT_STATS_GROUP) .. " " .. group .. ")") or tostring(you)
		sheet:Row(GetString(KELA_FIGHT_STATS_DEATHS), text, you > 0 and STYLE_BAD or nil)
	end
	if record.kind == KIND_MATCH then
		sheet:Row(GetString(KELA_FIGHT_STATS_FIGHTS), tostring(record.fights or 1))
	end
end

-- "62%  /  38%".
local function SplitText(first, second, total)
	return FormatPercent(first / total) .. "  /  " .. FormatPercent(second / total)
end

-- How the damage split, in three rows instead of the Stats page's bars.
local function AddDamageMix(sheet, profile)
	if profile.total <= 0 then
		return
	end
	sheet:Heading(GetString(KELA_FIGHT_STATS_DAMAGE_MIX))
	sheet:Row(GetString(KELA_FIGHT_STATS_DIRECT_VS_DOT), SplitText(profile.direct, profile.dot, profile.total))
	sheet:Row(GetString(KELA_FIGHT_STATS_SINGLE_VS_AREA), SplitText(profile.single, profile.area, profile.total))
	if profile.hits > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_CRIT_RATE), FormatPercent(profile.crits / profile.hits))
	end
end

-- The skills that did the most, as their share of the total (healing skills
-- for a healer).
local function AddTopSkills(sheet, record, detail, damageRows)
	local healing = record.roleId == ROLE_HEAL and detail.healSkills and next(detail.healSkills) ~= nil
	local rows = healing and GetSkillRows(detail.healSkills) or damageRows
	local total = 0
	for _, row in ipairs(rows) do
		total = total + row.damage
	end
	if total <= 0 then
		return
	end
	sheet:Heading(GetString(healing and KELA_FIGHT_STATS_TOP_HEALING or KELA_FIGHT_STATS_TOP_SKILLS))
	for index = 1, zo_min(#rows, MAX_TOP_SKILLS) do
		local row = rows[index]
		sheet:IconRow(row.icon, row.name, nil, FormatPercent(row.damage / total))
	end
end

-- Column 2 --------------------------------------------------------------------------

-- The damage type that did the most of your damage, as "Flame 62%".
local function GetMainDamageType(detail)
	local byType, total = {}, 0
	for _, skill in pairs(detail.skills or {}) do
		if skill.damageType and skill.damage > 0 then
			byType[skill.damageType] = (byType[skill.damageType] or 0) + skill.damage
			total = total + skill.damage
		end
	end
	local best, bestDamage = nil, 0
	for damageType, damage in pairs(byType) do
		if damage > bestDamage then
			best, bestDamage = damageType, damage
		end
	end
	if not best or total <= 0 then
		return nil
	end
	return EnumText("SI_DAMAGETYPE", best) .. "  " .. FormatPercent(bestDamage / total)
end

local function AddRotation(sheet, detail)
	sheet:Heading(GetString(KELA_FIGHT_STATS_ROTATION))
	local seconds = detail.seconds or 0
	if seconds > 0 and detail.idleSeconds ~= nil then
		local active = zo_clamp(1 - detail.idleSeconds / seconds, 0, 1)
		sheet:Row(GetString(KELA_FIGHT_STATS_ACTIVE_TIME), FormatPercent(active), active < 0.8 and STYLE_WARN or nil)
	end
	if (detail.weaveCount or 0) > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_WEAVE_TIME), string.format("%.3f s", detail.weaveSum / detail.weaveCount / 1000))
	end
	if detail.bars and next(detail.bars) ~= nil then
		local errors = 0
		for _, stats in pairs(detail.bars) do
			errors = errors + (stats.errors or 0)
		end
		sheet:Row(GetString(KELA_FIGHT_STATS_WEAVE_ERRORS), tostring(errors), errors > 0 and STYLE_WARN or nil)
	end
	if (detail.peakBurst or 0) > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_BEST_BURST), FormatNumber(detail.peakBurst / 10) .. "/s")
	end
	if (detail.ultimateCasts or 0) > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_ULTIMATES_CAST), tostring(detail.ultimateCasts))
	end
	local mainType = GetMainDamageType(detail)
	if mainType then
		sheet:Row(GetString(KELA_FIGHT_STATS_MAIN_DAMAGE_TYPE), mainType)
	end
	-- Magicka or stamina that sat under a tenth of its maximum, only when it did.
	for _, flag in ipairs({ COMBAT_MECHANIC_FLAGS_MAGICKA, COMBAT_MECHANIC_FLAGS_STAMINA }) do
		local entry = detail.resourceTime and detail.resourceTime[flag]
		if entry and entry.total > 10 and entry.low / entry.total > LOW_RESOURCE_SHARE then
			sheet:Row(zo_strformat(GetString(KELA_FIGHT_STATS_RESOURCE_LOW), EnumText("SI_COMBATMECHANICFLAGS", flag)),
				FormatPercent(entry.low / entry.total), STYLE_WARN)
		end
	end
end

-- Column 3 --------------------------------------------------------------------------

-- In a group: the group's damage, your share, and the best DPS that is known
-- (yours and what members share).
local function AddGroupSummary(sheet, record, detail)
	sheet:Heading(GetString(KELA_FIGHT_STATS_GROUP))
	if (record.groupDamage or 0) > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_GROUP_DAMAGE), GetTotalWithRate(record.groupDamage, record.groupDps or 0))
		sheet:Row(GetString(KELA_FIGHT_STATS_SHARE), FormatPercent(record.damageOut / zo_max(record.groupDamage, 1)))
	end
	local members = { { name = record.character, dps = record.dpsOut or 0, you = true } }
	for _, name in ipairs(GetMemberNames(record)) do
		local dps = GetSharedDps(detail.roster[name])
		if dps then
			members[#members + 1] = { name = name, dps = dps }
		end
	end
	table.sort(members, function(a, b)
		if a.dps ~= b.dps then
			return a.dps > b.dps
		end
		return a.name < b.name
	end)
	if #members > 1 then
		sheet:Heading(GetString(KELA_FIGHT_STATS_TOP_DPS))
		for index = 1, zo_min(#members, MAX_TOP_DPS) do
			local member = members[index]
			sheet:Row(member.you and COLORS.COLOR_GOLD:Colorize(member.name) or member.name, FormatNumber(member.dps))
		end
	end
end

-- Alone: the targets that took the most from you.
local function AddTargetSummary(sheet, record)
	local targets = record.detail and record.detail.targets or {}
	if #targets == 0 then
		return
	end
	sheet:Heading(GetString(KELA_FIGHT_STATS_TARGETS))
	for index = 1, zo_min(#targets, MAX_TARGETS) do
		local target = targets[index]
		local seconds = zo_max(target.seconds or 0, 1)
		local damage = target.you or target.damage or 0
		sheet:Row(target.name, FormatNumber(damage) .. "  (" .. FormatNumber(damage / seconds) .. "/s)")
	end
end

-- The essential buffs on you and debuffs on the main target, counted, then the
-- ones that were up less than half the fight by name: what to fix first.
local function AddEssentials(sheet, record, detail)
	local seconds = detail.seconds
	local selfBuffs = detail.effects and detail.effects.selfBuffs
	local targetDebuffs, targetSeconds = detail.effects and detail.effects.enemyDebuffs, seconds
	local mainTarget = detail.targets and detail.targets[1]
	if mainTarget and mainTarget.debuffs then
		targetDebuffs, targetSeconds = mainTarget.debuffs, mainTarget.seconds
	end
	sheet:Heading(GetString(KELA_FIGHT_STATS_ESSENTIALS))
	EssentialRow(sheet, GetString(KELA_FIGHT_STATS_ESSENTIAL_BUFFS),
		CountEssential(selfBuffs, seconds, BUFFS, record.roleId, record.content))
	EssentialRow(sheet, GetString(KELA_FIGHT_STATS_ESSENTIAL_DEBUFFS),
		CountEssential(targetDebuffs, targetSeconds, DEBUFFS, record.roleId, record.content))

	local missing = {}
	local function Collect(list, listSeconds, entries)
		local uptimes = GetUptimes(list, listSeconds, entries)
		for _, entry in ipairs(entries) do
			if entry.essential and Effects.IsForRole(entry, record.roleId, record.content) then
				local fraction = uptimes[entry] or 0
				if fraction < MISSING_UPTIME then
					missing[#missing + 1] = { entry = entry, fraction = fraction }
				end
			end
		end
	end
	Collect(selfBuffs, seconds, BUFFS)
	Collect(targetDebuffs, targetSeconds, DEBUFFS)
	table.sort(missing, function(a, b)
		return a.fraction < b.fraction
	end)
	for index = 1, zo_min(#missing, MAX_MISSING) do
		local item = missing[index]
		local text = item.fraction > 0 and FormatPercent(item.fraction) or GetString(KELA_FIGHT_STATS_MISSING)
		sheet:IconRow(Effects.GetIcon(item.entry), Effects.GetName(item.entry), nil, STYLE_BAD.color:Colorize(text))
	end
	if #missing > MAX_MISSING then
		sheet:Text("+" .. (#missing - MAX_MISSING), DIM_STYLE)
	end
end

-- Mundus stone and food, always shown; red when there was none.
local function AddPreparation(sheet, detail)
	local prep = detail.prep
	if not prep then
		return
	end
	local function Names(list, idOf)
		local names = {}
		for _, item in ipairs(list or {}) do
			names[#names + 1] = zo_strformat(SI_ABILITY_NAME, GetAbilityName(idOf(item)))
		end
		return Join(names)
	end
	sheet:Heading(GetString(KELA_FIGHT_STATS_PREP))
	local mundus = Names(prep.mundus, function(id) return id end)
	sheet:Row(GetString(KELA_FIGHT_STATS_MUNDUS), mundus ~= "" and mundus or GetString(KELA_FIGHT_STATS_NONE), mundus == "" and STYLE_BAD or nil)
	if prep.foodKnown then
		local food = Names(prep.food, function(item) return item.id end)
		sheet:Row(GetString(KELA_FIGHT_STATS_FOOD_DRINK), food ~= "" and food or GetString(KELA_FIGHT_STATS_NONE), food == "" and STYLE_BAD or nil)
	end
	local potions = 0
	for _, entry in ipairs(prep.potions or {}) do
		potions = potions + (entry.count or 0)
	end
	if potions > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_POTIONS), tostring(potions))
	end
end

local function BuildSummaryPage(_, sheet, record)
	sheet:Clear({ 1, 1, 1 })
	UI.AddFightTitle(sheet, record)
	AddPerformance(sheet, record)
	local detail = record.detail
	if not detail then
		sheet:SetColumn(2)
		sheet:Text(GetString(KELA_FIGHT_STATS_NO_DETAIL), DIM_STYLE)
		return
	end
	local rows = GetSkillRows(detail.skills)
	AddDamageMix(sheet, GetDamageProfile(rows))
	AddTopSkills(sheet, record, detail, rows)

	sheet:SetColumn(2)
	local uptimes = GetUptimes(detail.effects and detail.effects.enemyDebuffs, detail.seconds, DEBUFFS)
	AddOffenseSection(sheet, detail, detail.offense, uptimes, false)
	AddRotation(sheet, detail)

	sheet:SetColumn(3)
	if detail.roster and next(detail.roster) ~= nil then
		AddGroupSummary(sheet, record, detail)
	else
		AddTargetSummary(sheet, record)
	end
	AddEssentials(sheet, record, detail)
	AddPreparation(sheet, detail)
end

KPUI_FIGHT_STATS.Pages = KPUI_FIGHT_STATS.Pages or {}
KPUI_FIGHT_STATS.Pages.Summary = { name = KELA_FIGHT_STATS_SUMMARY, Build = BuildSummaryPage }
