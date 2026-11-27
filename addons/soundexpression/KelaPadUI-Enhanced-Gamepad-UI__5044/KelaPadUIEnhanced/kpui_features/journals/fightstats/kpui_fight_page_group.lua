-- KelaPadUI Fight Stats: Group page, shown when LibGroupCombatStats is
-- installed. The game does not name the source of another player's hit, so
-- each member's own numbers are the DPS and HPS their add-ons share through
-- that library (rounded, and only for members who run one); everything else
-- here is what the game does show: the group's total damage per enemy (from
-- LibCombat), the buffs on each member, the damage they took, and who died.
--
-- Y picks the whole group or one member; X picks a target for the whole group.

local UI = KPUI_FIGHT_STATS.UI
local STYLES, COLORS, DIM_STYLE = UI.STYLES, UI.COLORS, UI.DIM_STYLE
local STYLE_BAD = UI.STYLE_BAD
local FormatNumber, FormatPercent, Join = UI.FormatNumber, UI.FormatPercent, UI.Join
local GetTotalWithRate, GetNameWithAccount = UI.GetTotalWithRate, UI.GetNameWithAccount
local GetRoleName, GetClassIcon = UI.GetRoleName, UI.GetClassIcon
local GetSkillRows, AddSkillBars = UI.GetSkillRows, UI.AddSkillBars
local AddEffectSection, Sections = UI.AddEffectSection, UI.Sections
local DEBUFFS, BUFFS, STATE_DEAD, MODE_GROUP = UI.DEBUFFS, UI.BUFFS, UI.STATE_DEAD, UI.MODE_GROUP

-- You and each member, with the DPS and HPS that are known: yours from your
-- own fight, theirs as shared. Best DPS first; unshared members last.
local function GetMembers(record)
	local detail = record.detail
	local members =
	{
		{
			name = record.character, account = record.account, you = true, classId = record.classId, roleId = record.roleId,
			dps = record.dpsOut or 0, bossDps = record.singleBoss and record.singleDps or nil,
			hps = record.hpsOut, shared = true,
		},
	}
	for name, info in pairs(detail.roster or {}) do
		local shared = info.shared
		members[#members + 1] =
		{
			name = name, account = info.account, classId = info.classId, roleId = info.roleId,
			dps = shared and shared.dps or nil, bossDps = shared and shared.bossDps or nil, damage = shared and shared.damage or nil,
			hps = shared and shared.hps or nil, shared = shared ~= nil,
		}
	end
	table.sort(members, function(a, b)
		if (a.dps ~= nil) ~= (b.dps ~= nil) then
			return a.dps ~= nil
		end
		if (a.dps or 0) ~= (b.dps or 0) then
			return (a.dps or 0) > (b.dps or 0)
		end
		return a.name < b.name
	end)
	return members
end

local function GetMemberSubText(member)
	local parts = { GetRoleName(member.roleId) }
	if member.bossDps then
		parts[#parts + 1] = GetString(KELA_FIGHT_STATS_BOSS_DPS) .. " " .. FormatNumber(member.bossDps)
	elseif member.damage then
		parts[#parts + 1] = GetString(KELA_FIGHT_STATS_DAMAGE) .. " " .. FormatNumber(member.damage)
	end
	if (member.hps or 0) > 0 then
		parts[#parts + 1] = GetString(KELA_FIGHT_STATS_HPS) .. " " .. FormatNumber(member.hps)
	end
	if not member.shared then
		parts[#parts + 1] = GetString(KELA_FIGHT_STATS_NOT_SHARED)
	end
	return Join(parts)
end

-- The group's damage, your share, and each member's DPS as a bar.
local function AddGroupDamage(sheet, record)
	sheet:Heading(GetString(KELA_FIGHT_STATS_GROUP_TOTALS))
	if (record.groupDamage or 0) > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_GROUP_DAMAGE), GetTotalWithRate(record.groupDamage, record.groupDps or 0), STYLES.ValueTimer)
		sheet:Row(GetString(KELA_FIGHT_STATS_SHARE), FormatPercent(record.damageOut / zo_max(record.groupDamage, 1)))
	end
	local members = GetMembers(record)
	local top = 1
	for _, member in ipairs(members) do
		top = zo_max(top, member.dps or 0)
	end
	sheet:Heading(GetString(KELA_FIGHT_STATS_MEMBERS))
	for _, member in ipairs(members) do
		local label = GetNameWithAccount(member.you and COLORS.COLOR_GOLD:Colorize(member.name) or member.name, member.account)
		local value = member.dps and (FormatNumber(member.dps) .. " " .. GetString(KELA_FIGHT_STATS_DPS)) or "-"
		sheet:Bar(label, value, (member.dps or 0) / top, nil, GetMemberSubText(member), GetClassIcon(member.classId))
	end
	sheet:Paragraph(GetString(KELA_FIGHT_STATS_SHARED_NOTE), DIM_STYLE)
end

-- The whole group, all targets.
local function BuildWholeGroup(sheet, record, detail)
	AddGroupDamage(sheet, record)

	sheet:SetColumn(2)
	Sections.BuffCoverage(sheet, record, detail)
	Sections.DeathLog(sheet, record, detail)

	sheet:SetColumn(3)
	Sections.Timeline(sheet, detail)
	AddSkillBars(sheet, GetString(KELA_FIGHT_STATS_GROUP_TAKEN), GetSkillRows(detail.groupTaken))
	Sections.AmountBars(sheet, GetString(KELA_FIGHT_STATS_TAKEN_BY_MEMBER), detail.takenBy)
end

-- The whole group on one target: its total from LibCombat, your part, and the
-- debuffs it carried.
local function BuildGroupTarget(sheet, record, detail, target)
	local seconds = zo_max(target.seconds or 0, 1)
	sheet:Heading(target.name)
	if target.group then
		sheet:Row(GetString(KELA_FIGHT_STATS_GROUP_DAMAGE), GetTotalWithRate(target.group, target.group / seconds), STYLES.ValueTimer)
	end
	sheet:Row(GetString(KELA_FIGHT_STATS_YOUR_DAMAGE), GetTotalWithRate(target.you or 0, (target.you or 0) / seconds))
	if target.group and target.group > 0 then
		sheet:Row(GetString(KELA_FIGHT_STATS_SHARE), FormatPercent((target.you or 0) / target.group))
	end
	sheet:Paragraph(GetString(KELA_FIGHT_STATS_TARGET_GROUP_NOTE), DIM_STYLE)

	sheet:SetColumn(2)
	AddEffectSection(sheet, GetString(KELA_FIGHT_STATS_ESSENTIAL_DEBUFFS), GetString(KELA_FIGHT_STATS_DEBUFFS_ENEMY),
		DEBUFFS, target.debuffs, target.seconds, record.roleId, record.content)

	sheet:SetColumn(3)
	Sections.DeathLog(sheet, record, detail)
end

-- One member: what they share, the buffs that were on them, and what their
-- buffs say about their gear.
local function BuildMember(sheet, record, detail, name)
	local info = detail.roster[name] or {}
	local shared = info.shared
	sheet:Heading(GetNameWithAccount(name, info.account))
	local parts = { GetRoleName(info.roleId) }
	if info.classId and info.classId > 0 then
		parts[#parts + 1] = zo_strformat(SI_CLASS_NAME, GetClassName(info.gender or GENDER_MALE, info.classId))
	end
	if info.championPoints and info.championPoints > 0 then
		parts[#parts + 1] = GetString(KELA_FIGHT_STATS_CP) .. " " .. info.championPoints
	end
	sheet:Text(Join(parts), DIM_STYLE)
	if shared then
		if shared.dps then
			sheet:Row(GetString(KELA_FIGHT_STATS_DPS), FormatNumber(shared.dps), STYLES.ValueTimer)
		end
		if shared.bossDps then
			sheet:Row(GetString(KELA_FIGHT_STATS_BOSS_DPS), FormatNumber(shared.bossDps))
		elseif shared.damage then
			sheet:Row(GetString(KELA_FIGHT_STATS_DAMAGE), FormatNumber(shared.damage))
		end
		if (shared.hps or 0) > 0 or (shared.rawHps or 0) > 0 then
			sheet:Row(GetString(KELA_FIGHT_STATS_HPS), FormatNumber(shared.hps or 0))
			sheet:Row(GetString(KELA_FIGHT_STATS_RAW_HPS), FormatNumber(shared.rawHps or 0))
		end
	else
		sheet:Row(GetString(KELA_FIGHT_STATS_DPS), GetString(KELA_FIGHT_STATS_NOT_SHARED))
	end
	if detail.takenBy and detail.takenBy[name] then
		sheet:Row(GetString(KELA_FIGHT_STATS_DAMAGE_TAKEN), FormatNumber(detail.takenBy[name]))
	end
	local deaths = 0
	for _, death in ipairs(detail.deaths or {}) do
		if death.state == STATE_DEAD and death.name == name then
			deaths = deaths + 1
		end
	end
	sheet:Row(GetString(KELA_FIGHT_STATS_DEATHS), tostring(deaths), deaths > 0 and STYLE_BAD or nil)
	if not shared then
		sheet:Paragraph(GetString(KELA_FIGHT_STATS_SHARED_NOTE), DIM_STYLE)
	end

	sheet:SetColumn(2)
	AddEffectSection(sheet, GetString(KELA_FIGHT_STATS_ESSENTIAL_BUFFS), GetString(KELA_FIGHT_STATS_BUFFS_MEMBER),
		BUFFS, detail.memberBuffs and detail.memberBuffs[name], detail.seconds, info.roleId, record.content)

	sheet:SetColumn(3)
	if info.skillLines then
		KPUI_FIGHT_STATS.Loadout.SkillLines(sheet, info.skillLines)
	end
	UI.AddSetsSeen(sheet, detail, name)
end

local function BuildGroupPage(_, sheet, record)
	sheet:Clear({ 1, 1.1, 1 })
	UI.AddFightTitle(sheet, record)
	local detail = record.detail
	if not detail or not detail.roster or next(detail.roster) == nil then
		sheet:Text(GetString(detail and KELA_FIGHT_STATS_GROUP_NONE or KELA_FIGHT_STATS_NO_DETAIL), DIM_STYLE)
		return
	end
	local target, member, targetLabel, characterLabel = UI.GetSelection(record, MODE_GROUP)
	local filters = { { label = GetString(KELA_FIGHT_STATS_CHARACTER), value = characterLabel } }
	if not member then
		table.insert(filters, 1, { label = GetString(KELA_FIGHT_STATS_TARGET), value = targetLabel })
	end
	sheet:FilterBar(filters)
	if member then
		BuildMember(sheet, record, detail, member)
	elseif target then
		BuildGroupTarget(sheet, record, detail, target)
	else
		BuildWholeGroup(sheet, record, detail)
	end
end

-- X picks a target while the whole group is shown; Y always picks the
-- character (the screen reads actions by button, not in order).
local function GetGroupActions(_, record)
	local detail = record.detail
	if not detail or not detail.roster or next(detail.roster) == nil then
		return {}
	end
	local _, member = UI.GetSelection(record, MODE_GROUP)
	return
	{
		[1] = not member and UI.TargetAction(record) or nil,
		[2] = UI.CharacterAction(record, MODE_GROUP),
	}
end

KPUI_FIGHT_STATS.Pages = KPUI_FIGHT_STATS.Pages or {}
KPUI_FIGHT_STATS.Pages.Group = { name = KELA_FIGHT_STATS_GROUP, Build = BuildGroupPage, Actions = GetGroupActions }
