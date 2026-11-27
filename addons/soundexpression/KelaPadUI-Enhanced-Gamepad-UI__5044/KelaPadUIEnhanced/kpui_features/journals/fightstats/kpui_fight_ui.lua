-- KelaPadUI Fight Stats: what the pages share, formatting, effect uptimes,
-- offense against the caps, and the sheet sections more than one page draws.
-- Everything is handed to the pages through KPUI_FIGHT_STATS.UI.

local KIND_MATCH = KPUI_FIGHT_STATS.KIND_MATCH
local CONTENT_BATTLEGROUND = KPUI_FIGHT_STATS.CONTENT_BATTLEGROUND
local CONTENT_NAMES = KPUI_FIGHT_STATS.CONTENT_NAMES
local GetClassIcon = KPUI_FIGHT_STATS.GetClassIcon
local Effects = KPUI_FIGHT_STATS.Effects

local STYLES = kpuiConst.TextStyles
local COLORS = kpuiConst.Colors
-- Second lines and notes: a colour only, so the sheet keeps its own font.
local DIM_STYLE = { color = ZO_ColorDef:New("D8D8D8") }

local SEPARATOR = "  -  "

local function FormatDuration(seconds)
	seconds = zo_floor(seconds or 0)
	return string.format("%d:%02d", zo_floor(seconds / 60), seconds % 60)
end

local function FormatNumber(value)
	return KelaLocalizedFormatNumber(zo_round(value or 0), 0)
end

local function FormatPercent(fraction)
	return string.format("%.1f%%", (fraction or 0) * 100)
end

local function GetContentName(record)
	local id = CONTENT_NAMES[record.content]
	return id and GetString(id) or ""
end

local ACCOUNT_COLOR = ZO_ColorDef:New("9A9A9A")

-- A character name followed by its @account, the account in grey.
local function GetNameWithAccount(name, account)
	if account and account ~= "" then
		return name .. " " .. ACCOUNT_COLOR:Colorize(account)
	end
	return name
end

-- The same without colours, for lists and filters.
local function GetPlainNameWithAccount(name, account)
	if account and account ~= "" then
		return name .. " " .. account
	end
	return name
end

local function Join(parts)
	local used = {}
	for _, part in ipairs(parts) do
		if part and part ~= "" then
			used[#used + 1] = part
		end
	end
	return table.concat(used, SEPARATOR)
end

local function GetSetsText(sets)
	local names = {}
	for index, set in ipairs(sets) do
		names[index] = set.name .. " x" .. set.count
	end
	return table.concat(names, ", ")
end

-- The name of an enum value from the game's own strings, or "" without one.
local function EnumText(prefix, value)
	if value == nil then
		return ""
	end
	return GetString(prefix, value)
end

local function GetRaceText(record)
	if record.raceId and record.raceId > 0 then
		return zo_strformat(SI_RACE_NAME, GetRaceName(record.gender or GENDER_MALE, record.raceId))
	end
	return ""
end

local function GetClassText(record)
	if record.classId and record.classId > 0 then
		return zo_strformat(SI_CLASS_NAME, GetClassName(record.gender or GENDER_MALE, record.classId))
	end
	return ""
end

local function GetRoleText(record)
	if record.roleId and record.roleId > 0 then
		return EnumText("SI_LFGROLE", record.roleId)
	end
	return ""
end

-- Detail helpers: skills, damage profile, effects, caps ------------------------

local function GetAbilityText(id)
	return zo_strformat(SI_ABILITY_NAME, GetAbilityName(id))
end

-- A skill that hits an area (a radius or a cone) rather than a single target.
local function IsAreaAbility(id)
	local radius = GetAbilityRadius(id)
	if radius and radius > 0 then
		return true
	end
	return (GetAbilityAngleDistance(id) or 0) > 0
end

-- The skills of a table of counters, one row per ability name (a skill's cast,
-- hit and damage-over-time abilities share a name), best damage first. A row is
-- an area skill when any of its abilities is.
local function GetSkillRows(skills)
	local byName, rows = {}, {}
	for id, skill in pairs(skills or {}) do
		local name = GetAbilityText(id)
		if name ~= "" then
			local row = byName[name]
			if not row then
				row = { name = name, icon = GetAbilityIcon(id), best = -1, damage = 0, dotDamage = 0, hits = 0, crits = 0, casts = 0, area = false }
				byName[name] = row
				rows[#rows + 1] = row
			end
			row.damage = row.damage + skill.damage
			row.dotDamage = row.dotDamage + skill.dotDamage
			row.overheal = (row.overheal or 0) + (skill.overheal or 0)
			row.hits = row.hits + skill.hits
			row.crits = row.crits + skill.crits
			row.casts = row.casts + (skill.casts or 0)
			row.area = row.area or IsAreaAbility(id)
			if skill.damage > row.best then
				row.best = skill.damage
				row.icon = GetAbilityIcon(id)
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.damage ~= b.damage then
			return a.damage > b.damage
		end
		if a.casts ~= b.casts then
			return a.casts > b.casts
		end
		return a.name < b.name
	end)
	return rows
end

-- How the damage splits: direct or over time, single target or area, and both
-- together. Totals are in damage; `hits` and `crits` are counts.
local function GetDamageProfile(rows)
	local profile = { total = 0, dot = 0, area = 0, areaDot = 0, hits = 0, crits = 0 }
	for _, row in ipairs(rows) do
		profile.total = profile.total + row.damage
		profile.dot = profile.dot + row.dotDamage
		profile.hits = profile.hits + row.hits
		profile.crits = profile.crits + row.crits
		if row.area then
			profile.area = profile.area + row.damage
			profile.areaDot = profile.areaDot + row.dotDamage
		end
	end
	profile.direct = profile.total - profile.dot
	profile.single = profile.total - profile.area
	profile.areaDirect = profile.area - profile.areaDot
	profile.singleDot = profile.dot - profile.areaDot
	profile.singleDirect = profile.single - profile.singleDot
	return profile
end

local function GetSkillSubText(row)
	local parts = {}
	if row.casts > 0 then
		parts[#parts + 1] = zo_strformat(GetString(KELA_FIGHT_STATS_SKILL_CASTS), row.casts)
	end
	if row.hits > 0 then
		parts[#parts + 1] = zo_strformat(GetString(KELA_FIGHT_STATS_SKILL_HITS), row.hits)
		parts[#parts + 1] = zo_strformat(GetString(KELA_FIGHT_STATS_SKILL_CRITS), zo_round(row.crits / row.hits * 100))
		parts[#parts + 1] = zo_strformat(GetString(KELA_FIGHT_STATS_SKILL_AVERAGE), FormatNumber(row.damage / row.hits))
	end
	return Join(parts)
end

local function AddFightTitle(sheet, record)
	local title = record.target
	if record.kind == KIND_MATCH then
		title = title .. "  " .. COLORS.COLOR_GREY:Colorize("(" .. zo_strformat(GetString(KELA_FIGHT_STATS_FIGHTS_IN_MATCH), record.fights or 1) .. ")")
	end
	sheet:Title(title, Join({ GetContentName(record), record.zone, os.date("%Y-%m-%d %H:%M", record.timestamp) }), record.classIcon)
end

-- "1,234,567  (12,345/s)": a total and what it came to per second.
local function GetTotalWithRate(total, perSecond)
	return FormatNumber(total) .. "  (" .. FormatNumber(perSecond) .. "/s)"
end

local function ShareText(damage, total)
	return FormatNumber(damage) .. "  " .. FormatPercent(damage / zo_max(total, 1))
end

-- Direct, over time, single target and area damage as bars, and the four
-- combinations of those below.
local function AddDamageMix(sheet, profile)
	local function Line(label, damage)
		sheet:Bar(label, ShareText(damage, profile.total), damage / profile.total)
	end
	sheet:Heading(GetString(KELA_FIGHT_STATS_DAMAGE_MIX))
	Line(GetString(KELA_FIGHT_STATS_DAMAGE_DIRECT), profile.direct)
	Line(GetString(KELA_FIGHT_STATS_DAMAGE_DOT), profile.dot)
	Line(GetString(KELA_FIGHT_STATS_DAMAGE_SINGLE), profile.single)
	Line(GetString(KELA_FIGHT_STATS_DAMAGE_AREA), profile.area)
	if profile.hits > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_CRIT_RATE), FormatPercent(profile.crits / profile.hits))
	end
end

local function AddDeliverySection(sheet, profile)
	local function Line(label, damage)
		sheet:Bar(label, ShareText(damage, profile.total), damage / profile.total)
	end
	sheet:Heading(GetString(KELA_FIGHT_STATS_DAMAGE_COMBINED))
	Line(GetString(KELA_FIGHT_STATS_COMBO_SINGLE_DIRECT), profile.singleDirect)
	Line(GetString(KELA_FIGHT_STATS_COMBO_SINGLE_DOT), profile.singleDot)
	Line(GetString(KELA_FIGHT_STATS_COMBO_AREA_DIRECT), profile.areaDirect)
	Line(GetString(KELA_FIGHT_STATS_COMBO_AREA_DOT), profile.areaDot)
end

local function AddDamageTypes(sheet, detail, totalDamage)
	local byType, types = {}, {}
	for _, skill in pairs(detail.skills or {}) do
		local damageType = skill.damageType
		if damageType and skill.damage > 0 then
			if not byType[damageType] then
				byType[damageType] = 0
				types[#types + 1] = damageType
			end
			byType[damageType] = byType[damageType] + skill.damage
		end
	end
	if #types == 0 then
		return
	end
	table.sort(types, function(a, b)
		if byType[a] ~= byType[b] then
			return byType[a] > byType[b]
		end
		return a < b
	end)
	sheet:Heading(GetString(KELA_FIGHT_STATS_DAMAGE_TYPES))
	for _, damageType in ipairs(types) do
		sheet:Row(EnumText("SI_DAMAGETYPE", damageType), ShareText(byType[damageType], totalDamage))
	end
end

-- Skill bars, best first, with the share of `total` and a bar relative to the
-- best skill.
local function AddSkillBars(sheet, heading, rows, totalOverride)
	if #rows == 0 then
		return
	end
	local total = 0
	for _, row in ipairs(rows) do
		total = total + row.damage
	end
	total = zo_max(totalOverride or total, 1)
	local top = zo_max(rows[1].damage, 1)
	sheet:Heading(heading)
	for _, row in ipairs(rows) do
		local value = row.damage > 0 and (FormatNumber(row.damage) .. "  " .. FormatPercent(row.damage / total)) or "-"
		local subText = GetSkillSubText(row)
		if (row.overheal or 0) > 0 then
			-- Healing that was not needed, as a share of everything the skill healed.
			subText = Join({ subText, FormatPercent(row.overheal / (row.damage + row.overheal)) .. " " .. GetString(KELA_FIGHT_STATS_OVERHEALED) })
		end
		sheet:Bar(row.name, value, row.damage / top, nil, subText, row.icon)
	end
end

-- Stats: averages against the caps -------------------------------------------------

local COLOR_GOOD = ZO_ColorDef:New("6CC66A")
local COLOR_WARN = ZO_ColorDef:New("E0B040")
local COLOR_BAD = ZO_ColorDef:New("E05555")
local STYLE_GOOD, STYLE_WARN, STYLE_BAD = { color = COLOR_GOOD }, { color = COLOR_WARN }, { color = COLOR_BAD }

-- Past these, extra penetration and critical damage do nothing: a trial boss
-- has 18200 resistance (Combat Metrics uses the same figure), and critical
-- damage is capped at 125% (155% with the critical damage mastery passive).
local PENETRATION_CAP = 18200
local CRIT_DAMAGE_CAP, CRIT_DAMAGE_CAP_MASTERY = 125, 155
local CRIT_CHANCE_CAP = 100

-- Time-weighted average and maximum of the first of these stats that was seen.
-- LibCombat tracks spell and weapon values separately and they can differ a
-- lot (a Sharpened weapon raises only physical penetration), so callers say
-- which kind they want first.
local function GetStat(detail, statIds)
	if not detail.stats or not detail.seconds or detail.seconds <= 0 then
		return nil
	end
	for _, statId in ipairs(statIds) do
		local stat = detail.stats[statId]
		if stat then
			return stat.sum / detail.seconds, stat.max
		end
	end
	return nil
end

local function FormatChance(rating)
	-- LibCombat reports critical as a rating; the game converts it to a chance.
	return string.format("%.1f%%", zo_min(GetCriticalStrikeChance(rating), 100))
end

local function FormatBonus(value)
	return string.format("%.0f%%", value)
end

local function FormatStat(format, average, maximum)
	local text = format(average)
	if maximum and zo_round(maximum) ~= zo_round(average) then
		text = text .. " (" .. GetString(KELA_FIGHT_STATS_MAX) .. " " .. format(maximum) .. ")"
	end
	return text
end

-- The game's own name for one of the character sheet stats.
local function GetStatName(stat)
	return GetString("SI_DERIVEDSTATS", stat)
end

-- Green at the cap or above, amber close to it, red further below.
local function GetCapStyle(value, cap)
	if value >= cap then
		return STYLE_GOOD
	elseif value >= cap * 0.9 then
		return STYLE_WARN
	end
	return STYLE_BAD
end

-- Essential effects ----------------------------------------------------------------

local ROLE_DD, ROLE_TANK, ROLE_HEAL = LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL
-- LibCombat's state for a unit that died.
local STATE_DEAD = LIBCOMBAT_STATE_DEAD or 1

local DEBUFFS = KPUI_FIGHT_EFFECTS.debuffs
local BUFFS = KPUI_FIGHT_EFFECTS.buffs

-- How much of `seconds` each known effect was up, from one effect list of
-- { [abilityId] = seconds }. An effect with several sources, or a weapon and a
-- spell version, counts at the best of them. Also returns the effects no entry
-- knows.
local function GetUptimes(list, seconds, entries)
	local uptimes, unknown = {}, {}
	seconds = zo_max(seconds or 0, 0.1)
	for id, effectSeconds in pairs(list or {}) do
		local entry = Effects.Find(entries, id)
		if entry then
			local fraction = zo_min(effectSeconds / seconds, 1)
			if fraction > (uptimes[entry] or 0) then
				uptimes[entry] = fraction
			end
		else
			unknown[#unknown + 1] = { id = id, seconds = effectSeconds }
		end
	end
	table.sort(unknown, function(a, b)
		if a.seconds ~= b.seconds then
			return a.seconds > b.seconds
		end
		return a.id < b.id
	end)
	return uptimes, unknown
end

local function GetUptimeStyle(fraction)
	if fraction >= 0.85 then
		return STYLE_GOOD
	elseif fraction >= 0.5 then
		return STYLE_WARN
	end
	return STYLE_BAD
end

local MAX_OTHER_EFFECTS = 8

-- One list of essential effects (green when up most of the fight, red when
-- missing), then the other effects that were seen, longest first.
local function AddEffectSection(sheet, essentialHeading, otherHeading, entries, list, seconds, roleId, content)
	local uptimes, unknown = GetUptimes(list, seconds, entries)
	local shown = {}
	local any = false
	for _, entry in ipairs(entries) do
		if entry.essential and Effects.IsForRole(entry, roleId, content) then
			if not any then
				sheet:Heading(essentialHeading)
				any = true
			end
			shown[entry] = true
			local fraction = uptimes[entry] or 0
			local text = fraction > 0 and FormatPercent(fraction) or GetString(KELA_FIGHT_STATS_MISSING)
			local style = GetUptimeStyle(fraction)
			sheet:IconRow(Effects.GetIcon(entry), Effects.GetName(entry), nil, style.color:Colorize(text))
		end
	end
	local others = {}
	for _, item in ipairs(unknown) do
		others[#others + 1] = { icon = GetAbilityIcon(item.id), name = GetAbilityText(item.id), fraction = zo_min(item.seconds / zo_max(seconds or 0, 0.1), 1) }
	end
	for entry, fraction in pairs(uptimes) do
		if not shown[entry] then
			others[#others + 1] = { icon = Effects.GetIcon(entry), name = Effects.GetName(entry), fraction = fraction }
		end
	end
	table.sort(others, function(a, b)
		if a.fraction ~= b.fraction then
			return a.fraction > b.fraction
		end
		return a.name < b.name
	end)
	if #others > 0 then
		sheet:Heading(otherHeading)
		for index = 1, zo_min(#others, MAX_OTHER_EFFECTS) do
			local other = others[index]
			sheet:IconRow(other.icon, other.name, nil, FormatPercent(other.fraction))
		end
	end
	return uptimes
end

-- Offense, weighed by the damage ------------------------------------------------
-- The tally adds each hit with the stat as it stood and what the target's
-- debuffs took off it, so these figures are what the damage really met. The
-- game's own stat tooltips say how weapon and spell stats combine: weapon and
-- spell damage and critical count when they are the higher of the two, for every
-- ability, so those are shown once. Penetration follows the damage type
-- (physical, bleed, disease and poison against the physical penetration; flame,
-- frost, magic and shock against the spell penetration), so it is shown for each
-- kind that did real damage.

local HIT_SUM_FIELDS =
{
	"damage", "hits", "powerSum", "powerDamage", "chanceSum", "chanceHits",
	"penDamage", "penSum", "penSumWrath", "penOver", "penOverWrath", "critDamage", "critSum",
	"penMax", "penMaxWrath", "critMax",
}

local function NewHitSums()
	local sums = {}
	for _, field in ipairs(HIT_SUM_FIELDS) do
		sums[field] = 0
	end
	return sums
end

local PENETRATION_KINDS =
{
	{ key = "weapon", penetration = STAT_PHYSICAL_PENETRATION },
	{ key = "spell", penetration = STAT_SPELL_PENETRATION },
}
local MIN_KIND_SHARE = 0.05

-- The game's name for the combined weapon and spell damage stat.
local function GetPowerName()
	if SI_DERIVEDSTATS2 then
		return GetString(SI_DERIVEDSTATS2)
	end
	return GetStatName(STAT_POWER)
end

-- Returns false when there is nothing tallied (a fight saved before this).
local function AddOffenseFromHits(sheet, detail, offense, detailed)
	local total = 0
	local combined = NewHitSums()
	for _, kind in ipairs(PENETRATION_KINDS) do
		local sums = offense and offense[kind.key]
		if sums then
			total = total + sums.damage
			for field, value in pairs(sums) do
				if field ~= "penMax" and field ~= "penMaxWrath" and field ~= "critMax" then
					combined[field] = (combined[field] or 0) + value
				else
					combined[field] = zo_max(combined[field] or 0, value)
				end
			end
		end
	end
	if total <= 0 then
		return false
	end
	local wrath = detail.wrathCP == true
	sheet:Heading(GetString(KELA_FIGHT_STATS_OFFENSE))

	local shown = {}
	for _, kind in ipairs(PENETRATION_KINDS) do
		local sums = offense[kind.key]
		if sums and sums.penDamage > 0 and sums.damage >= total * MIN_KIND_SHARE then
			shown[#shown + 1] = { kind = kind, sums = sums }
		end
	end
	table.sort(shown, function(a, b)
		return a.sums.damage > b.sums.damage
	end)
	-- The game reports one value for physical and spell penetration (they read
	-- the same on the character sheet), so when the two kinds met practically the
	-- same figure they are one row, the way the game's own stat is named.
	if #shown > 1 then
		local function Average(sums)
			return (wrath and sums.penSumWrath or sums.penSum) / sums.penDamage
		end
		local first, second = Average(shown[1].sums), Average(shown[2].sums)
		if math.abs(first - second) <= zo_max(first, second) * 0.02 then
			shown = { { kind = { penetration = STAT_OFFENSIVE_PENETRATION }, sums = combined } }
		end
	end
	for _, item in ipairs(shown) do
		local sums = item.sums
		local average = (wrath and sums.penSumWrath or sums.penSum) / sums.penDamage
		local over = (wrath and sums.penOverWrath or sums.penOver) / sums.penDamage
		local highest = wrath and sums.penMaxWrath or sums.penMax
		-- One row is the single penetration stat; two rows name their kind.
		local label = GetStatName(#shown > 1 and item.kind.penetration or STAT_OFFENSIVE_PENETRATION)
		if #shown > 1 then
			label = label .. " " .. FormatPercent(sums.damage / total)
		end
		sheet:Row(label, FormatNumber(average) .. " / " .. FormatNumber(PENETRATION_CAP), GetCapStyle(average, PENETRATION_CAP))
		if detailed then
			sheet:Row(GetString(KELA_FIGHT_STATS_OVER_CAP), FormatPercent(over))
			sheet:Row(GetString(KELA_FIGHT_STATS_HIGHEST), FormatNumber(highest))
		end
	end

	if combined.critDamage > 0 then
		local cap = detail.critMastery and CRIT_DAMAGE_CAP_MASTERY or CRIT_DAMAGE_CAP
		local average = combined.critSum / combined.critDamage
		sheet:Row(GetString(KELA_FIGHT_STATS_CRIT_DAMAGE), string.format("%.1f%% / %.0f%%", average, cap), GetCapStyle(average, cap))
		if detailed then
			sheet:Row(GetString(KELA_FIGHT_STATS_HIGHEST), string.format("%.1f%%", combined.critMax))
		end
	end
	if combined.chanceHits > 0 then
		local chance = zo_min(GetCriticalStrikeChance(combined.chanceSum / combined.chanceHits), 100)
		sheet:Row(GetStatName(STAT_CRITICAL_CHANCE), string.format("%.1f%% / %d%%", chance, CRIT_CHANCE_CAP), GetCapStyle(chance, CRIT_CHANCE_CAP))
	end
	if combined.powerDamage > 0 then
		sheet:Row(GetPowerName(), FormatNumber(combined.powerSum / combined.powerDamage))
	end
	return true
end

-- Damage that meets the physical penetration (physical, bleed, disease, poison).
local PHYSICAL_DAMAGE_TYPES =
{
	[DAMAGE_TYPE_PHYSICAL] = true, [DAMAGE_TYPE_BLEED] = true,
	[DAMAGE_TYPE_DISEASE] = true, [DAMAGE_TYPE_POISON] = true,
}

-- A fight saved before hits were weighed has only time-weighted sheet values,
-- and the enemy debuffs at their uptime on top. The higher of weapon and spell
-- damage and critical applies to everything, and the penetration of whichever
-- kind of damage was done more stands for the rest.
local function AddLegacyOffenseSection(sheet, detail, uptimes, detailed)
	local physicalDamage, otherDamage = 0, 0
	for _, skill in pairs(detail.skills or {}) do
		if PHYSICAL_DAMAGE_TYPES[skill.damageType] then
			physicalDamage = physicalDamage + skill.damage
		else
			otherDamage = otherDamage + skill.damage
		end
	end
	local function Higher(weaponStat, spellStat)
		local weapon, weaponMax = GetStat(detail, { weaponStat })
		local spell, spellMax = GetStat(detail, { spellStat })
		if weapon and spell then
			if weapon >= spell then
				return weapon, weaponMax
			end
			return spell, spellMax
		end
		return weapon or spell, weaponMax or spellMax
	end
	local penetration, penetrationMax
	if physicalDamage >= otherDamage then
		penetration, penetrationMax = GetStat(detail, { LIBCOMBAT_STAT_WEAPONPENETRATION, LIBCOMBAT_STAT_SPELLPENETRATION })
	else
		penetration, penetrationMax = GetStat(detail, { LIBCOMBAT_STAT_SPELLPENETRATION, LIBCOMBAT_STAT_WEAPONPENETRATION })
	end
	local critChance = Higher(LIBCOMBAT_STAT_WEAPONCRIT, LIBCOMBAT_STAT_SPELLCRIT)
	local critDamage, critDamageMax = Higher(LIBCOMBAT_STAT_WEAPONCRITBONUS, LIBCOMBAT_STAT_SPELLCRITBONUS)
	local power, powerMax = Higher(LIBCOMBAT_STAT_WEAPONPOWER, LIBCOMBAT_STAT_SPELLPOWER)
	if not (penetration or critChance or critDamage or power) then
		return
	end
	local debuffPenetration, debuffCrit = 0, 0
	for entry, fraction in pairs(uptimes) do
		if not entry.status then
			debuffPenetration = debuffPenetration + (entry.pen or 0) * fraction
			debuffCrit = debuffCrit + (entry.crit or 0) * fraction
		end
	end

	sheet:Heading(GetString(KELA_FIGHT_STATS_OFFENSE))
	if penetration then
		local effective = penetration + debuffPenetration
		local text = FormatNumber(effective) .. " / " .. FormatNumber(PENETRATION_CAP)
		if detailed then
			sheet:Row(GetStatName(STAT_OFFENSIVE_PENETRATION), FormatStat(FormatNumber, penetration, penetrationMax))
			sheet:Row(GetString(KELA_FIGHT_STATS_FROM_DEBUFFS), "+" .. FormatNumber(debuffPenetration))
			sheet:Row(GetString(KELA_FIGHT_STATS_WITH_DEBUFFS), text, GetCapStyle(effective, PENETRATION_CAP))
		else
			sheet:Row(GetStatName(STAT_OFFENSIVE_PENETRATION), text, GetCapStyle(effective, PENETRATION_CAP))
		end
	end
	if critDamage then
		local cap = detail.critMastery and CRIT_DAMAGE_CAP_MASTERY or CRIT_DAMAGE_CAP
		local effective = critDamage + debuffCrit
		local text = FormatBonus(effective) .. " / " .. FormatBonus(cap)
		if detailed then
			sheet:Row(GetString(KELA_FIGHT_STATS_CRIT_DAMAGE), FormatStat(FormatBonus, critDamage, critDamageMax))
			sheet:Row(GetString(KELA_FIGHT_STATS_FROM_DEBUFFS), "+" .. FormatBonus(debuffCrit))
			sheet:Row(GetString(KELA_FIGHT_STATS_WITH_DEBUFFS), text, GetCapStyle(effective, cap))
		else
			sheet:Row(GetString(KELA_FIGHT_STATS_CRIT_DAMAGE), text, GetCapStyle(effective, cap))
		end
	end
	if critChance then
		local chance = zo_min(GetCriticalStrikeChance(critChance), 100)
		sheet:Row(GetStatName(STAT_CRITICAL_CHANCE), string.format("%.1f%% / %d%%", chance, CRIT_CHANCE_CAP), GetCapStyle(chance, CRIT_CHANCE_CAP))
	end
	if power then
		sheet:Row(GetPowerName(), FormatStat(FormatNumber, power, powerMax))
	end
end

-- `offense` is the tallied offense of the selection (a target or the whole
-- fight); `uptimes` the target's debuff uptimes, for fights saved without it.
local function AddOffenseSection(sheet, detail, offense, uptimes, detailed)
	if not AddOffenseFromHits(sheet, detail, offense, detailed) then
		AddLegacyOffenseSection(sheet, detail, uptimes, detailed)
	end
end

-- Maximum resources, then what each resource recovered and spent per second.
local function AddResourcesSection(sheet, detail)
	local added = false
	local function Heading()
		if not added then
			sheet:Heading(GetString(KELA_FIGHT_STATS_RESOURCES))
			added = true
		end
	end
	local maxima =
	{
		{ LIBCOMBAT_STAT_MAXHEALTH, STAT_HEALTH_MAX },
		{ LIBCOMBAT_STAT_MAXMAGICKA, STAT_MAGICKA_MAX },
		{ LIBCOMBAT_STAT_MAXSTAMINA, STAT_STAMINA_MAX },
	}
	for _, row in ipairs(maxima) do
		local average = GetStat(detail, { row[1] })
		if average then
			Heading()
			sheet:Row(GetStatName(row[2]), FormatNumber(average))
		end
	end
	local recovery =
	{
		{ COMBAT_MECHANIC_FLAGS_HEALTH, GetStatName(STAT_HEALTH_REGEN_COMBAT) },
		{ COMBAT_MECHANIC_FLAGS_MAGICKA, GetStatName(STAT_MAGICKA_REGEN_COMBAT) },
		{ COMBAT_MECHANIC_FLAGS_STAMINA, GetStatName(STAT_STAMINA_REGEN_COMBAT) },
		{ COMBAT_MECHANIC_FLAGS_ULTIMATE, GetString(KELA_FIGHT_STATS_ULTIMATE_RECOVERY) },
	}
	for _, row in ipairs(recovery) do
		local resource = detail.resources and detail.resources[row[1]]
		if resource and detail.seconds > 0 then
			Heading()
			if row[1] == COMBAT_MECHANIC_FLAGS_ULTIMATE then
				-- Ultimate comes in small amounts per second.
				sheet:Row(row[2], string.format("+%.1f/s  -%.1f/s", resource.gain / detail.seconds, resource.drain / detail.seconds))
			else
				sheet:Row(row[2], "+" .. FormatNumber(resource.gain / detail.seconds) .. "/s  -" .. FormatNumber(resource.drain / detail.seconds) .. "/s")
			end
		end
	end
end

local function GetRoleName(roleId)
	if roleId and roleId > 0 then
		return EnumText("SI_LFGROLE", roleId)
	end
	return ""
end

local Sections = {}
do
	-- Bars, mitigation and healing ----------------------------------------------------

	-- Both bars side by side: time, damage, casts and weave.
	local function AddBarsSection(sheet, detail)
		local bars = {}
		local totalSeconds = 0
		for bar, stats in pairs(detail.bars or {}) do
			bars[#bars + 1] = bar
			totalSeconds = totalSeconds + (stats.seconds or 0)
		end
		if #bars == 0 then
			return
		end
		table.sort(bars)
		local headers = {}
		local rows =
		{
			{ GetString(KELA_FIGHT_STATS_BAR_TIME), styles = {} },
			{ GetString(KELA_FIGHT_STATS_DAMAGE), styles = {} },
			{ GetString(KELA_FIGHT_STATS_DPS), styles = {} },
			{ GetString(KELA_FIGHT_STATS_SKILLS_CAST), styles = {} },
			{ GetString(KELA_FIGHT_STATS_ATTACKS), styles = {} },
			{ GetString(KELA_FIGHT_STATS_WEAVE_TIME), styles = {} },
			{ GetString(KELA_FIGHT_STATS_WEAVE_ERRORS), styles = {} },
		}
		for index, bar in ipairs(bars) do
			local stats = detail.bars[bar]
			local seconds = zo_max(stats.seconds or 0, 1)
			headers[index] = zo_strformat(GetString(KELA_FIGHT_STATS_BAR), bar)
			rows[1][index + 1] = FormatDuration(stats.seconds) .. " " .. FormatPercent(stats.seconds / zo_max(totalSeconds, 1))
			rows[2][index + 1] = FormatNumber(stats.damage)
			rows[3][index + 1] = FormatNumber(stats.damage / seconds)
			rows[4][index + 1] = tostring(stats.skills)
			rows[5][index + 1] = tostring(stats.attacks)
			rows[6][index + 1] = (stats.weaveCount or 0) > 0 and string.format("%.3f s", stats.weaveSum / stats.weaveCount / 1000) or "-"
			rows[7][index + 1] = tostring(stats.errors or 0)
			if (stats.errors or 0) > 0 then
				rows[7].styles[index] = STYLE_WARN
			end
		end
		sheet:Heading(GetString(KELA_FIGHT_STATS_BARS))
		sheet:Grid(headers, rows)
	end

	-- The resistance where mitigation reaches 50%. It is a soft cap: more still
	-- helps, with diminishing returns, so it is marked but never treated as a limit.
	local RESISTANCE_CAP = 33100

	local function AddMitigationSection(sheet, detail)
		local mitigation = detail.mitigation
		local hasHits = mitigation and (mitigation.hits or 0) > 0
		local physical = GetStat(detail, { LIBCOMBAT_STAT_PHYSICALRESISTANCE })
		local spell = GetStat(detail, { LIBCOMBAT_STAT_SPELLRESISTANCE })
		local crit = GetStat(detail, { LIBCOMBAT_STAT_CRITICALRESISTANCE })
		if not (hasHits or physical or spell or crit) then
			return
		end
		sheet:Heading(GetString(KELA_FIGHT_STATS_MITIGATION))
		if hasHits then
			sheet:Row(GetString(KELA_FIGHT_STATS_HITS_TAKEN), FormatNumber(mitigation.hits))
			if (mitigation.blockedHits or 0) > 0 then
				sheet:Row(GetString(KELA_FIGHT_STATS_BLOCKED), FormatPercent(mitigation.blockedHits / mitigation.hits) .. "  (" .. FormatNumber(mitigation.blockedHits) .. ")")
			end
			if (mitigation.shielded or 0) > 0 then
				sheet:Row(GetString(KELA_FIGHT_STATS_SHIELDED), FormatNumber(mitigation.shielded))
			end
			if (mitigation.dodges or 0) > 0 then
				sheet:Row(GetString(KELA_FIGHT_STATS_DODGED), FormatNumber(mitigation.dodges))
			end
		end
		if physical then
			sheet:Row(GetStatName(STAT_PHYSICAL_RESIST), FormatNumber(physical) .. " / " .. FormatNumber(RESISTANCE_CAP), GetCapStyle(physical, RESISTANCE_CAP))
		end
		if spell then
			sheet:Row(GetStatName(STAT_SPELL_RESIST), FormatNumber(spell) .. " / " .. FormatNumber(RESISTANCE_CAP), GetCapStyle(spell, RESISTANCE_CAP))
		end
		if crit then
			sheet:Row(GetStatName(STAT_CRITICAL_RESISTANCE), FormatNumber(crit))
		end
		if physical or spell then
			sheet:Text(GetString(KELA_FIGHT_STATS_RESISTANCE_NOTE), DIM_STYLE)
		end
	end

	-- Effective healing against what was wasted, and how much came over time.
	local function AddHealingDetail(sheet, detail)
		local effective, overhealed, overTime = 0, 0, 0
		for _, skill in pairs(detail.healSkills or {}) do
			effective = effective + skill.damage
			overhealed = overhealed + (skill.overheal or 0)
			overTime = overTime + (skill.dotDamage or 0)
		end
		if effective <= 0 then
			return
		end
		sheet:Heading(GetString(KELA_FIGHT_STATS_HEALING_DETAIL))
		sheet:Row(GetString(KELA_FIGHT_STATS_EFFECTIVE), FormatNumber(effective))
		if overhealed > 0 then
			local share = overhealed / (effective + overhealed)
			sheet:Row(GetString(KELA_FIGHT_STATS_OVERHEAL), FormatNumber(overhealed) .. "  " .. FormatPercent(share), share > 0.5 and STYLE_WARN or nil)
		end
		sheet:Row(GetString(KELA_FIGHT_STATS_OVER_TIME), FormatPercent(overTime / effective))
	end

	-- How the fight was played besides the damage: time with nothing happening, the
	-- best burst, ultimates and time spent short of resources.
	local function AddRotationSection(sheet, detail)
		local seconds = detail.seconds or 0
		if seconds <= 0 or (detail.peakBurst == nil and detail.idleSeconds == nil) then
			return
		end
		sheet:Heading(GetString(KELA_FIGHT_STATS_ROTATION))
		local active = zo_clamp(1 - (detail.idleSeconds or 0) / seconds, 0, 1)
		sheet:Row(GetString(KELA_FIGHT_STATS_ACTIVE_TIME), FormatPercent(active), active < 0.8 and STYLE_WARN or nil)
		if (detail.peakBurst or 0) > 0 then
			sheet:Row(GetString(KELA_FIGHT_STATS_BEST_BURST), GetTotalWithRate(detail.peakBurst, detail.peakBurst / 10))
			sheet:Row(GetString(KELA_FIGHT_STATS_BEST_BURST_AT), FormatDuration(zo_max((detail.peakAt or 0) - 10, 0)))
		end
		local ultimate = detail.resources and detail.resources[COMBAT_MECHANIC_FLAGS_ULTIMATE]
		if (detail.ultimateCasts or 0) > 0 or ultimate then
			sheet:Row(GetString(KELA_FIGHT_STATS_ULTIMATES_CAST), tostring(detail.ultimateCasts or 0))
		end
		if ultimate then
			sheet:Row(GetString(KELA_FIGHT_STATS_ULTIMATE_GAINED), FormatNumber(ultimate.gain))
			sheet:Row(GetString(KELA_FIGHT_STATS_ULTIMATE_SPENT), FormatNumber(ultimate.drain))
		end
		for _, flag in ipairs({ COMBAT_MECHANIC_FLAGS_MAGICKA, COMBAT_MECHANIC_FLAGS_STAMINA }) do
			local entry = detail.resourceTime and detail.resourceTime[flag]
			if entry and entry.total > 10 then
				local share = entry.low / entry.total
				sheet:Row(zo_strformat(GetString(KELA_FIGHT_STATS_RESOURCE_LOW), EnumText("SI_COMBATMECHANICFLAGS", flag)), FormatPercent(share), share > 0.1 and STYLE_WARN or nil)
			end
		end
	end

	-- Group page ---------------------------------------------------------------------
	-- The whole group at once: the fight over time, who died, which essential buffs
	-- the group kept up, what hurt the group and who was healed.

	local function GetPeak(values, count)
		local peak = 0
		for index = 1, count do
			peak = zo_max(peak, values[index] or 0)
		end
		return peak
	end

	local function AddTimeline(sheet, detail)
		local timeline = detail.timeline
		local count = timeline and timeline.n or 0
		if count < 1 then
			return
		end
		local step = timeline.step or 10
		local total = count * step
		local marks = {}
		for _, death in ipairs(detail.deaths or {}) do
			if death.state == STATE_DEAD then
				marks[#marks + 1] = death.t / total
			end
		end
		local function Rates(series)
			local rates = {}
			for index = 1, count do
				rates[index] = (series[index] or 0) / step
			end
			return rates
		end
		sheet:Heading(GetString(KELA_FIGHT_STATS_TIMELINE))
		for _, item in ipairs({
			{ GetString(KELA_FIGHT_STATS_DAMAGE), timeline.damage, nil },
			{ GetString(KELA_FIGHT_STATS_HEALING), timeline.healing, COLOR_GOOD },
			{ GetString(KELA_FIGHT_STATS_DAMAGE_TAKEN), timeline.taken, COLOR_BAD },
		}) do
			local rates = Rates(item[2])
			local peak = GetPeak(rates, count)
			if peak > 0 then
				sheet:Graph(item[1], zo_strformat(GetString(KELA_FIGHT_STATS_PEAK), FormatNumber(peak)), rates, count, item[3], marks)
			end
		end
		-- The boss health line, which starts full.
		local health, seen = {}, false
		local last = 100
		for index = 1, count do
			if timeline.boss and timeline.boss[index] then
				last = timeline.boss[index]
				seen = true
			end
			health[index] = last
		end
		if seen then
			sheet:Graph(GetString(KELA_FIGHT_STATS_BOSS_HEALTH), string.format("%d%%", last), health, count, COLOR_WARN, marks)
		end
		sheet:Text("0:00 - " .. FormatDuration(total), DIM_STYLE)
	end

	local function AddDeathLog(sheet, record, detail)
		sheet:Heading(GetString(KELA_FIGHT_STATS_DEATH_LOG))
		local events = {}
		for _, death in ipairs(detail.deaths or {}) do
			events[#events + 1] = death
		end
		table.sort(events, function(a, b)
			return a.t < b.t
		end)
		-- The game can report one revive twice; the repeat is dropped.
		local shown, previous = 0, {}
		for _, death in ipairs(events) do
			local died = death.state == STATE_DEAD
			local key = death.name .. (died and ":d" or ":r")
			if not previous[key] or death.t - previous[key] > 2 then
				previous[key] = death.t
				shown = shown + 1
				local text = zo_strformat(GetString(died and KELA_FIGHT_STATS_DIED or KELA_FIGHT_STATS_REVIVED), death.name)
				if death.name == record.character then
					text = COLORS.COLOR_GOLD:Colorize(text)
				end
				local killer = died and death.ability and death.ability > 0 and GetAbilityText(death.ability) or ""
				local subText = killer ~= "" and zo_strformat(GetString(KELA_FIGHT_STATS_KILLED_BY), killer) or nil
				sheet:IconRow(nil, text, subText, FormatDuration(death.t))
			end
		end
		if shown == 0 then
			sheet:Text(GetString(KELA_FIGHT_STATS_NO_DEATHS), DIM_STYLE)
		end
	end

	-- Each essential buff: how much of the fight the group had it (those it matters
	-- to, by role), and who had it for under half.
	local function AddBuffCoverage(sheet, record, detail)
		local seconds = zo_max(detail.seconds or 0, 0.1)
		local people = {}
		people[1] = { name = record.character, roleId = record.roleId, list = detail.effects and detail.effects.selfBuffs }
		local names = {}
		for name in pairs(detail.roster or {}) do
			names[#names + 1] = name
		end
		table.sort(names)
		for _, name in ipairs(names) do
			people[#people + 1] = { name = name, roleId = detail.roster[name].roleId, list = detail.memberBuffs and detail.memberBuffs[name] }
		end
		for _, person in ipairs(people) do
			person.uptimes = GetUptimes(person.list, seconds, BUFFS)
		end
		sheet:Heading(GetString(KELA_FIGHT_STATS_BUFF_COVERAGE))
		local any = false
		for _, entry in ipairs(BUFFS) do
			if entry.essential then
				local sum, count, low = 0, 0, {}
				for _, person in ipairs(people) do
					if Effects.IsForRole(entry, person.roleId, record.content) then
						local fraction = person.uptimes[entry] or 0
						count = count + 1
						sum = sum + fraction
						if fraction < 0.5 then
							low[#low + 1] = person.name
						end
					end
				end
				if count > 0 then
					any = true
					local average = sum / count
					local subText
					if #low > 0 then
						local shownNames = {}
						for index = 1, zo_min(#low, 4) do
							shownNames[index] = low[index]
						end
						subText = zo_strformat(GetString(KELA_FIGHT_STATS_UNDER_HALF), table.concat(shownNames, ", ") .. (#low > 4 and (" +" .. (#low - 4)) or ""))
					end
					sheet:IconRow(Effects.GetIcon(entry), Effects.GetName(entry), subText, GetUptimeStyle(average).color:Colorize(FormatPercent(average)))
				end
			end
		end
		if not any then
			sheet:Text(GetString(KELA_FIGHT_STATS_NO_BUFF_DATA), DIM_STYLE)
		end
	end

	-- Bars of name -> amount, biggest first.
	local function AddAmountBars(sheet, heading, amounts, subTextOf)
		local list, top, total = {}, 0, 0
		for name, amount in pairs(amounts or {}) do
			if amount > 0 then
				list[#list + 1] = { name = name, amount = amount }
				top = zo_max(top, amount)
				total = total + amount
			end
		end
		if #list == 0 then
			return
		end
		table.sort(list, function(a, b)
			if a.amount ~= b.amount then
				return a.amount > b.amount
			end
			return a.name < b.name
		end)
		sheet:Heading(heading)
		for _, item in ipairs(list) do
			sheet:Bar(item.name, ShareText(item.amount, total), item.amount / top, nil, subTextOf and subTextOf(item.name) or nil)
		end
	end

	Sections.Bars = AddBarsSection
	Sections.Mitigation = AddMitigationSection
	Sections.Healing = AddHealingDetail
	Sections.Rotation = AddRotationSection
	Sections.Timeline = AddTimeline
	Sections.DeathLog = AddDeathLog
	Sections.BuffCoverage = AddBuffCoverage
	Sections.AmountBars = AddAmountBars
end


-- Filters ------------------------------------------------------------------------
-- The target and character choices are kept per fight while the screen is open
-- and shared by the pages: a member picked on the Group page is the one the
-- Loadout page shows.

local CHARACTER_YOU, CHARACTER_GROUP = "@you", "@group"
local CHARACTER_MEMBER_PREFIX = "m:"
local MODE_GROUP, MODE_LOADOUT = "group", "loadout"

local views = setmetatable({}, { __mode = "k" })

local function GetView(record)
	local view = views[record]
	if not view then
		view = { target = nil, character = nil }
		views[record] = view
	end
	return view
end

-- The tallied targets. A fight saved before targets were tallied falls back to
-- the enemies its record lists, with only your damage to each.
local function GetTargets(record)
	local detail = record.detail
	if detail and detail.targets and #detail.targets > 0 then
		return detail.targets
	end
	local targets = {}
	for _, enemy in ipairs(record.enemies or {}) do
		targets[#targets + 1] = { name = enemy.name, damage = enemy.damage, you = enemy.damage, legacy = true }
	end
	return targets
end

local function GetTargetOptions(record)
	local options = { { key = nil, label = GetString(KELA_FIGHT_STATS_ALL_TARGETS) } }
	for _, target in ipairs(GetTargets(record)) do
		options[#options + 1] = { key = target.name, label = target.name, target = target }
	end
	return options
end

-- The group members of a fight, by name.
local function GetMemberNames(record)
	local names = {}
	for name in pairs(record.detail and record.detail.roster or {}) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- The Group page offers the whole group and each member; the Loadout page
-- offers you and each member.
local function GetCharacterOptions(record, mode)
	local options = {}
	if mode == MODE_GROUP then
		options[1] = { key = CHARACTER_GROUP, label = GetString(KELA_FIGHT_STATS_WHOLE_GROUP) }
	else
		options[1] = { key = CHARACTER_YOU, label = GetPlainNameWithAccount(record.character, record.account) }
	end
	local roster = record.detail and record.detail.roster or {}
	for _, name in ipairs(GetMemberNames(record)) do
		options[#options + 1] = { key = CHARACTER_MEMBER_PREFIX .. name, label = GetPlainNameWithAccount(name, roster[name].account), member = name }
	end
	return options
end

local function FindOption(options, key)
	for index, option in ipairs(options) do
		if option.key == key then
			return index, option
		end
	end
	return 1, options[1]
end

-- The picked target (or nil for all) and member name (or nil), with the
-- option labels, after checking the choices still exist in this fight.
local function GetSelection(record, mode)
	local view = GetView(record)
	local _, targetOption = FindOption(GetTargetOptions(record), view.target)
	local _, characterOption = FindOption(GetCharacterOptions(record, mode), view.character)
	return targetOption.target, characterOption.member, targetOption.label, characterOption.label
end

local function PickFilter(screen, title, options, currentKey, apply)
	local labels = {}
	for index, option in ipairs(options) do
		labels[index] = option.label
	end
	local selected = FindOption(options, currentKey)
	KelaShowChoiceDialog(title, labels, selected, function(index)
		apply(options[index].key)
		screen:Rerender()
	end)
end

-- The X and Y actions of a page: { name, callback(screen) }.
local function TargetAction(record)
	local view = GetView(record)
	local options = GetTargetOptions(record)
	local _, option = FindOption(options, view.target)
	return
	{
		name = function()
			return GetString(KELA_FIGHT_STATS_TARGET) .. ": " .. option.label
		end,
		callback = function(screen)
			PickFilter(screen, GetString(KELA_FIGHT_STATS_TARGET), options, view.target, function(key)
				view.target = key
			end)
		end,
	}
end

local function CharacterAction(record, mode)
	local view = GetView(record)
	local options = GetCharacterOptions(record, mode)
	if #options < 2 then
		return nil
	end
	local _, option = FindOption(options, view.character)
	return
	{
		name = function()
			return GetString(KELA_FIGHT_STATS_CHARACTER) .. ": " .. option.label
		end,
		callback = function(screen)
			PickFilter(screen, GetString(KELA_FIGHT_STATS_CHARACTER), options, view.character, function(key)
				view.character = key
			end)
		end,
	}
end

-- How many of the essential effects that matter for the role were up for at
-- least half of the fight, and how many there are.
local function CountEssential(list, seconds, entries, roleId, content)
	local uptimes = GetUptimes(list, seconds, entries)
	local up, total = 0, 0
	for _, entry in ipairs(entries) do
		if entry.essential and Effects.IsForRole(entry, roleId, content) then
			total = total + 1
			if (uptimes[entry] or 0) >= 0.5 then
				up = up + 1
			end
		end
	end
	return up, total
end

-- "7 of 9 up", green when all are, amber from half, red below.
local function EssentialRow(sheet, label, up, total)
	if total <= 0 then
		return
	end
	local fraction = up / total
	local style = fraction >= 1 and STYLE_GOOD or (fraction >= 0.5 and STYLE_WARN or STYLE_BAD)
	sheet:Row(label, zo_strformat(GetString(KELA_FIGHT_STATS_ESSENTIAL_UP), up, total), style)
end

-- The gear sets a member's buffs point to. A hint at what they wear, not what
-- they wear, so it says so.
local function AddSetsSeen(sheet, detail, name)
	local setIds = detail.memberSets and detail.memberSets[name]
	if not setIds or #setIds == 0 or type(LibSets) ~= "table" then
		return false
	end
	local names = {}
	for _, setId in ipairs(setIds) do
		local setName = LibSets.GetSetName(setId)
		if type(setName) == "string" and setName ~= "" then
			names[#names + 1] = zo_strformat(SI_TOOLTIP_ITEM_NAME, setName)
		end
	end
	table.sort(names)
	if #names == 0 then
		return false
	end
	sheet:Heading(GetString(KELA_FIGHT_STATS_SETS_SEEN))
	for _, setName in ipairs(names) do
		sheet:Text(setName)
	end
	sheet:Paragraph(GetString(KELA_FIGHT_STATS_INFERRED), DIM_STYLE)
	return true
end

-- A member's DPS as they share it, "65,200", or nil.
local function GetSharedDps(info)
	local shared = info and info.shared
	return shared and shared.dps or nil
end


KPUI_FIGHT_STATS.UI =
{
	STYLES = STYLES,
	COLORS = COLORS,
	DIM_STYLE = DIM_STYLE,
	SEPARATOR = SEPARATOR,
	FormatDuration = FormatDuration,
	FormatNumber = FormatNumber,
	FormatPercent = FormatPercent,
	GetContentName = GetContentName,
	GetNameWithAccount = GetNameWithAccount,
	GetPlainNameWithAccount = GetPlainNameWithAccount,
	Join = Join,
	GetSetsText = GetSetsText,
	EnumText = EnumText,
	GetRaceText = GetRaceText,
	GetClassText = GetClassText,
	GetRoleText = GetRoleText,
	GetAbilityText = GetAbilityText,
	GetSkillRows = GetSkillRows,
	GetDamageProfile = GetDamageProfile,
	GetSkillSubText = GetSkillSubText,
	AddFightTitle = AddFightTitle,
	ShareText = ShareText,
	GetTotalWithRate = GetTotalWithRate,
	AddDamageMix = AddDamageMix,
	AddDeliverySection = AddDeliverySection,
	AddDamageTypes = AddDamageTypes,
	AddSkillBars = AddSkillBars,
	COLOR_GOOD = COLOR_GOOD,
	COLOR_WARN = COLOR_WARN,
	COLOR_BAD = COLOR_BAD,
	STYLE_GOOD = STYLE_GOOD,
	STYLE_WARN = STYLE_WARN,
	STYLE_BAD = STYLE_BAD,
	PENETRATION_CAP = PENETRATION_CAP,
	GetStat = GetStat,
	FormatBonus = FormatBonus,
	GetStatName = GetStatName,
	GetCapStyle = GetCapStyle,
	ROLE_DD = ROLE_DD,
	ROLE_TANK = ROLE_TANK,
	ROLE_HEAL = ROLE_HEAL,
	STATE_DEAD = STATE_DEAD,
	DEBUFFS = DEBUFFS,
	BUFFS = BUFFS,
	GetUptimes = GetUptimes,
	GetUptimeStyle = GetUptimeStyle,
	AddEffectSection = AddEffectSection,
	AddOffenseSection = AddOffenseSection,
	AddResourcesSection = AddResourcesSection,
	GetRoleName = GetRoleName,
	Sections = Sections,
	GetClassIcon = GetClassIcon,
	KIND_MATCH = KIND_MATCH,
	CONTENT_BATTLEGROUND = CONTENT_BATTLEGROUND,
	GetView = GetView,
	GetTargets = GetTargets,
	GetSelection = GetSelection,
	TargetAction = TargetAction,
	CharacterAction = CharacterAction,
	CountEssential = CountEssential,
	EssentialRow = EssentialRow,
	AddSetsSeen = AddSetsSeen,
	GetSharedDps = GetSharedDps,
	MODE_GROUP = MODE_GROUP,
	MODE_LOADOUT = MODE_LOADOUT,
	GetMemberNames = GetMemberNames,
	FormatStat = FormatStat,
	FormatChance = FormatChance,
}
