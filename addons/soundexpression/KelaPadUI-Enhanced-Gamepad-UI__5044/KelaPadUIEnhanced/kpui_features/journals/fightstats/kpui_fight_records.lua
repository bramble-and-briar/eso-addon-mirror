-- KelaPadUI Fight Stats: recording. Your recent fights and the loadout you
-- used, from LibCombat (by Solinur, the library Combat Metrics is built on).
-- The screen and its pages live beside this file:
--
--   kpui_fight_tally.lua        what LibCombat's summary does not carry
--   kpui_fight_effect_match.lua which buffs and debuffs the pages know
--   kpui_fight_ui.lua           shared formatting and sheet sections
--   kpui_fight_page_*.lua       Summary, Stats, Group and Loadout
--   kpui_fight_screen.lua       the list, the filters and deleting
--
-- This only listens to LibCombat's public fight-summary callback, which fires
-- once when a fight ends with the totals LibCombat already tallied, and keeps a
-- small copy of each fight (never LibCombat's own fight object, which holds
-- every unit). It never asks Combat Metrics to calculate anything; Combat
-- Metrics keeps its own history. LibCombat tracks combat events for as long as
-- anything listens to it, so the callback is only registered where recording
-- is wanted:
--
--   * PvE: every fight;
--   * battlegrounds: the fights of one match are added together and the match
--     is recorded as a single entry when it ends (or when you leave it);
--   * Cyrodiil, Imperial City, Vengeance and Jerall Pass: never.
--
-- "Fights kept" is Fight Stats' own; Combat Metrics' fight history is its own
-- setting and is never read or changed here.

-- Shared by the Fight Stats files; filled in as they load.
KPUI_FIGHT_STATS = KPUI_FIGHT_STATS or {}

local EVENT_NAMESPACE = "KelaPadUI_FightStats"
local SETTINGS_CHANGED_EVENT = "KELA_FIGHT_STATS_SETTINGS_CHANGED"

-- The range of the "Fights kept" slider.
local KEPT_MIN, KEPT_MAX, KEPT_DEFAULT = 1, 40, 10

-- What one kept entry costs, in bytes, as a rough estimate for the setting's
-- help text: a few tables of ids, numbers and item links.
local BYTES_PER_ENTRY = 40 * 1024

-- A match is recorded this long after the game reports it finished, and this
-- long after you leave it; fights that LibCombat reports later than that are
-- added to the same entry.
local BG_FINISH_SETTLE_MS = 15000
local BG_LEAVE_SETTLE_MS = 8000
local MAX_ENEMIES = 5

local CONTEXT_PVE, CONTEXT_BATTLEGROUND, CONTEXT_LARGE_PVP = "pve", "bg", "large"
local KIND_FIGHT, KIND_MATCH = "fight", "match"

-- What kind of place a fight happened in. Saved codes, never shown directly.
local CONTENT_OVERLAND, CONTENT_DUNGEON, CONTENT_TRIAL, CONTENT_ARENA = "overland", "dungeon", "trial", "arena"
local CONTENT_ENDLESS, CONTENT_HOME, CONTENT_BATTLEGROUND = "endless", "home", "battleground"
local CONTENT_NAMES =
{
	[CONTENT_OVERLAND] = KELA_FIGHT_STATS_CONTENT_OVERLAND,
	[CONTENT_DUNGEON] = KELA_FIGHT_STATS_CONTENT_DUNGEON,
	[CONTENT_TRIAL] = KELA_FIGHT_STATS_CONTENT_TRIAL,
	[CONTENT_ARENA] = KELA_FIGHT_STATS_CONTENT_ARENA,
	[CONTENT_ENDLESS] = KELA_FIGHT_STATS_CONTENT_ENDLESS,
	[CONTENT_HOME] = KELA_FIGHT_STATS_CONTENT_HOME,
	[CONTENT_BATTLEGROUND] = KELA_FIGHT_STATS_CONTENT_BATTLEGROUND,
}

-- The fights are kept in the saved variables, account-wide, so they survive a
-- reload. Only codes, numbers and game names are saved; the class icon is
-- looked up again on load.
local SAVED_KEY = "fightStatsHistory"
local SAVED_VERSION = 1

local records = {}
local recordsLoaded = false
-- The current battleground match, or the last one until the next begins.
local session = nil
local registered = false

-- Tells the screen (kpui_fight_screen.lua) when the records change.
local function NotifyChanged()
	if KPUI_FIGHT_STATS.OnRecordsChanged then
		KPUI_FIGHT_STATS.OnRecordsChanged()
	end
end

-- ---------------------------------------------------------------------------
-- Availability and settings
-- ---------------------------------------------------------------------------

local function IsLibCombatLoaded()
	return type(LibCombat) == "table"
		and type(LibCombat.RegisterCallbackType) == "function"
		and type(LibCombat.UnregisterCallbackType) == "function"
		and LIBCOMBAT_EVENT_FIGHTSUMMARY ~= nil
end

function KelaIsFightStatsAvailable()
	return IsLibCombatLoaded()
		and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FEATURES_FIGHT_STATS)
end

local function GetKept()
	local value = KelaGetSetting_Number(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FIGHT_STATS_KEPT) or KEPT_DEFAULT
	return zo_clamp(zo_round(value), KEPT_MIN, KEPT_MAX)
end

local function FormatMemory(bytes)
	if bytes >= 1024 * 1024 then
		return string.format("%.0f MB", bytes / (1024 * 1024))
	end
	return string.format("%.0f KB", bytes / 1024)
end

-- The help text of the "Fights kept" slider: what the current value costs.
function KelaGetFightStatsKeptTooltip()
	local kept = GetKept()
	return zo_strformat(GetString(KELA_SETTINGS_FIGHT_STATS_KEPT_TOOLTIP), FormatMemory(kept * BYTES_PER_ENTRY))
end

-- ---------------------------------------------------------------------------
-- Records
-- ---------------------------------------------------------------------------

local function GetContext()
	if IsActiveWorldBattleground() then
		return CONTEXT_BATTLEGROUND
	end
	if IsPlayerInAvAWorld() or IsInImperialCity() or IsInCyrodiil() then
		return CONTEXT_LARGE_PVP
	end
	return CONTEXT_PVE
end

-- Where the player is now, as a content code. A battleground is reported by
-- the game; the game counts arenas as raids like trials, so the few arenas are
-- known by zone (KELA_ARENA_ZONE_IDS); any other instance is a dungeon (a
-- delve or public dungeon counts as one).
local function GetContentType()
	if IsActiveWorldBattleground() then
		return CONTENT_BATTLEGROUND
	end
	if GetCurrentZoneHouseId() ~= 0 then
		return CONTENT_HOME
	end
	if IsInstanceEndlessDungeon() then
		return CONTENT_ENDLESS
	end
	local zoneId = GetZoneId(GetUnitZoneIndex("player"))
	if KELA_ARENA_ZONE_IDS and KELA_ARENA_ZONE_IDS[zoneId] then
		return CONTENT_ARENA
	end
	if IsPlayerInRaid() then
		return CONTENT_TRIAL
	end
	if IsUnitInDungeon("player") then
		return CONTENT_DUNGEON
	end
	return CONTENT_OVERLAND
end

local function CopyBars(bars)
	local copy = {}
	if type(bars) == "table" then
		for bar, slots in pairs(bars) do
			if type(slots) == "table" then
				local ids = {}
				for slot = 1, 8 do
					ids[slot] = slots[slot] or 0
				end
				copy[bar] = ids
			end
		end
	end
	return copy
end

local function CopyScribed(scribed)
	local copy = {}
	if type(scribed) == "table" then
		for abilityId, scripts in pairs(scribed) do
			if type(scripts) == "table" then
				copy[abilityId] = { scripts[1], scripts[2], scripts[3] }
			end
		end
	end
	return copy
end

-- LibCombat's champion table: [disciplineId] = { total, stars = [starId] =
-- { points, type }, slotted = [starId] = true }, beside a `version` field.
local function CopyChampion(cp)
	local copy = {}
	if type(cp) == "table" then
		for disciplineId, discipline in pairs(cp) do
			if type(disciplineId) == "number" and type(discipline) == "table" then
				local stars = {}
				for starId, star in pairs(type(discipline.stars) == "table" and discipline.stars or {}) do
					if type(star) == "table" then
						stars[#stars + 1] =
						{
							id = starId,
							points = star[1] or 0,
							slotted = type(discipline.slotted) == "table" and discipline.slotted[starId] == true,
						}
					end
				end
				table.sort(stars, function(a, b)
					if a.slotted ~= b.slotted then
						return a.slotted
					end
					return a.id < b.id
				end)
				copy[#copy + 1] = { id = disciplineId, total = discipline.total or 0, stars = stars }
			end
		end
		table.sort(copy, function(a, b)
			return a.id < b.id
		end)
	end
	return copy
end

-- The sets the worn gear belongs to, with how many pieces count: armor and
-- jewelry, plus the weapons of the front bar.
local function CountSets(equip)
	local counts = {}
	for slot, link in pairs(equip) do
		local countsHere = slot ~= EQUIP_SLOT_BACKUP_MAIN and slot ~= EQUIP_SLOT_BACKUP_OFF and slot ~= EQUIP_SLOT_COSTUME
		if countsHere and type(link) == "string" and link ~= "" then
			local hasSet, setName = GetItemLinkSetInfo(link, false)
			if hasSet and setName and setName ~= "" then
				local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, setName)
				counts[name] = (counts[name] or 0) + 1
			end
		end
	end
	local sets = {}
	for name, count in pairs(counts) do
		sets[#sets + 1] = { name = name, count = count }
	end
	table.sort(sets, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.name < b.name
	end)
	return sets
end

-- The class mastery passives the character has (up to three), which Combat
-- Metrics shows in the class slots when no other class's lines are used.
local MAX_MASTERY = 3

local function GetMasteryPassives(passiveIds)
	local result = {}
	if type(passiveIds) == "table" and SKILLS_DATA_MANAGER then
		for _, abilityId in ipairs(passiveIds) do
			local progression = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
			local skillData = progression and progression:GetSkillData()
			local lineData = skillData and skillData:GetSkillLineData()
			if lineData and lineData:IsClassMastery() then
				result[#result + 1] = abilityId
				if #result >= MAX_MASTERY then
					break
				end
			end
		end
	end
	return result
end

-- The skills data is the game's own and recording must never fail over it.
local function GetMasteryPassivesSafe(passiveIds)
	local ok, result = pcall(GetMasteryPassives, passiveIds)
	return ok and type(result) == "table" and result or {}
end

local function CopyLoadout(charData, cp)
	if type(charData) ~= "table" then
		return nil
	end
	local equip = {}
	if type(charData.equip) == "table" then
		for slot, link in pairs(charData.equip) do
			if type(link) == "string" and link ~= "" then
				equip[slot] = link
			end
		end
	end
	local skillLines = {}
	if type(charData.SkillLines) == "table" then
		for index = 1, 3 do
			skillLines[index] = charData.SkillLines[index]
		end
	end
	return
	{
		equip = equip,
		sets = CountSets(equip),
		bars = CopyBars(charData.skillBars),
		scribed = CopyScribed(charData.scribedSkills),
		passives = type(charData.passiveSkills) == "table" and #charData.passiveSkills or 0,
		mastery = GetMasteryPassivesSafe(charData.passiveSkills),
		skillLines = skillLines,
		champion = CopyChampion(cp),
		health = charData.APHealth, magicka = charData.APMagicka, stamina = charData.APStam,
	}
end

local function GetClassIcon(classId)
	local classIndex = classId and GetClassIndexById(classId)
	if classIndex then
		return select(8, GetClassInfo(classIndex))
	end
	return nil
end

-- The enemies that took the most damage, by name, from LibCombat's units.
local function GetEnemies(units, into)
	into = into or {}
	if type(units) == "table" then
		for _, unit in pairs(units) do
			if type(unit) == "table" and unit.isFriendly == false and (unit.damageOutTotal or 0) > 0 and type(unit.name) == "string" then
				into[unit.name] = (into[unit.name] or 0) + unit.damageOutTotal
			end
		end
	end
	return into
end

local function RankEnemies(byName)
	local list = {}
	for name, damage in pairs(byName) do
		list[#list + 1] = { name = name, damage = damage }
	end
	table.sort(list, function(a, b)
		if a.damage ~= b.damage then
			return a.damage > b.damage
		end
		return a.name < b.name
	end)
	local top = {}
	for index = 1, zo_min(#list, MAX_ENEMIES) do
		top[index] = list[index]
	end
	return top, #list
end

local function Finish(record)
	record.classIcon = GetClassIcon(record.classId)
	return record
end

-- The character fields every record carries, from LibCombat's character data.
local function CharacterFields(charData)
	return
	{
		-- Formatted like LibCombat's own, so it matches the names in the fight.
		character = charData.name or ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName("player")),
		account = GetUnitDisplayName("player"),
		classId = charData.classId, raceId = charData.raceId, gender = charData.gender,
		roleId = charData.roleId, level = charData.level, championPoints = charData.CPtotal,
	}
end

local function Merge(record, fields)
	for key, value in pairs(fields) do
		record[key] = value
	end
	return record
end

local function Rate(total, seconds)
	return zo_floor((total or 0) / zo_max(seconds or 0, 1) + 0.5)
end

-- The damage to the bosses of a boss fight, or else to the one enemy that took
-- the most, with the time it was attacked, read from LibCombat's units.
local function GetSingleTargetDamage(fight)
	local units = type(fight.units) == "table" and fight.units or {}
	local damage, first, last, isBoss = 0, nil, 0, false
	if fight.bossfight == true then
		for _, unit in pairs(units) do
			if type(unit) == "table" and unit.bossId ~= nil and (unit.damageOutTotal or 0) > 0 then
				damage = damage + unit.damageOutTotal
				if unit.dpsstart then
					first = first and zo_min(first, unit.dpsstart) or unit.dpsstart
				end
				last = zo_max(last, unit.dpsend or 0)
			end
		end
		isBoss = damage > 0
	end
	if damage <= 0 then
		first, last = nil, 0
		for _, unit in pairs(units) do
			if type(unit) == "table" and unit.isFriendly == false and (unit.damageOutTotal or 0) > damage then
				damage = unit.damageOutTotal
				first, last = unit.dpsstart, unit.dpsend or 0
			end
		end
	end
	if damage <= 0 then
		return nil
	end
	local seconds = first and last > first and (last - first) / 1000 or fight.dpstime or 0
	return damage, Rate(damage, seconds), isBoss
end

local function BuildFightRecord(fight, detail)
	local damageOut, damageIn, healingOut = fight.damageOutTotal or 0, fight.damageInTotal or 0, fight.healingOutTotal or 0
	if damageOut + healingOut == 0 then
		return nil
	end
	local charData = type(fight.charData) == "table" and fight.charData or {}
	local topEnemies, enemyCount = RankEnemies(GetEnemies(fight.units))
	local singleDamage, singleDps, singleBoss = GetSingleTargetDamage(fight)
	local target = fight.bossfight and type(fight.bossname) == "string" and fight.bossname ~= "" and fight.bossname
		or (topEnemies[1] and topEnemies[1].name)
		or zo_strformat(SI_ZONE_NAME, fight.zone or "")
	return Finish(Merge(
	{
		kind = KIND_FIGHT,
		-- Where the fight began, when the tally saw it begin.
		content = detail and CONTENT_NAMES[detail.context] and detail.context or GetContentType(),
		timestamp = fight.date or GetTimeStamp(),
		zone = zo_strformat(SI_ZONE_NAME, fight.zone or ""),
		target = target,
		bossFight = fight.bossfight == true,
		singleDamage = singleDamage, singleDps = singleDps, singleBoss = singleBoss,
		damageOut = damageOut, damageIn = damageIn, healingOut = healingOut,
		dpsOut = fight.DPSOut or Rate(damageOut, fight.dpstime),
		dpsIn = fight.DPSIn or Rate(damageIn, fight.dpstime),
		hpsOut = fight.HPSOut or Rate(healingOut, fight.hpstime),
		duration = fight.combattime or fight.dpstime or 0,
		dpsSeconds = fight.dpstime or 0,
		group = fight.group == true,
		groupDps = fight.groupDPSOut or 0,
		groupDamage = fight.groupDamageOut or 0,
		enemies = topEnemies, enemyCount = enemyCount,
		loadout = CopyLoadout(charData, fight.CP),
		detail = detail,
	}, CharacterFields(charData)))
end

local function SaveRecords()
	if type(kpuiSavedVariables) ~= "table" then
		return
	end
	local saved = {}
	for index, record in ipairs(records) do
		local copy = {}
		for key, value in pairs(record) do
			if key ~= "classIcon" then
				copy[key] = value
			end
		end
		saved[index] = copy
	end
	kpuiSavedVariables[SAVED_KEY] = { version = SAVED_VERSION, records = saved }
	if KelaPadUI.log then
		KelaPadUI.log:Debug("Fight Stats: saved %d fights", #saved)
	end
end

-- Reads the saved fights once, after the saved variables exist. Anything that
-- is not a table of the expected shape is skipped.
-- Boss fights and battleground matches are what a run is for, so trash pulls
-- never push them out: when the list is over "Fights kept", the oldest other
-- fight goes first, as Combat Metrics does with "keep boss fights". Only when
-- every older entry is a boss fight or a match does the oldest of those go.
-- The newest entry (index 1) is never the one removed for its own sake.
local function IsKeptFirst(record)
	return record.bossFight == true or record.kind == KIND_MATCH
end

local function TrimRecords()
	local kept = GetKept()
	while #records > kept do
		local victim = #records
		for index = #records, 2, -1 do
			if not IsKeptFirst(records[index]) then
				victim = index
				break
			end
		end
		table.remove(records, victim)
	end
end

local function LoadRecords()
	if recordsLoaded or type(kpuiSavedVariables) ~= "table" then
		return
	end
	recordsLoaded = true
	local saved = kpuiSavedVariables[SAVED_KEY]
	if type(saved) ~= "table" or saved.version ~= SAVED_VERSION or type(saved.records) ~= "table" then
		if KelaPadUI.log then
			KelaPadUI.log:Info("Fight Stats: no saved fights found (%s)", type(saved))
		end
		return
	end
	for index = 1, #saved.records do
		local record = saved.records[index]
		if type(record) == "table" and type(record.target) == "string" and type(record.zone) == "string"
			and type(record.timestamp) == "number" and type(record.enemies) == "table" then
			records[#records + 1] = Finish(record)
		end
	end
	TrimRecords()
	if KelaPadUI.log then
		KelaPadUI.log:Info("Fight Stats: loaded %d of %d saved fights", #records, #saved.records)
	end
end

local function AddRecord(record)
	if not record then
		return
	end
	LoadRecords()
	table.insert(records, 1, record)
	TrimRecords()
	SaveRecords()
	NotifyChanged()
end

-- ---------------------------------------------------------------------------
-- Battlegrounds: one entry per match
-- ---------------------------------------------------------------------------

local function AddToSession(fight, detail)
	if not session then
		session =
		{
			bgId = GetCurrentBattlegroundId(),
			zoneId = fight.zoneId,
			startedAt = fight.date or GetTimeStamp(),
			zone = zo_strformat(SI_ZONE_NAME, fight.zone or ""),
			fights = 0, damageOut = 0, damageIn = 0, healingOut = 0, dpsTime = 0, hpsTime = 0, combatTime = 0,
			groupDamage = 0, enemies = {},
		}
	end
	local s = session
	s.fights = s.fights + 1
	s.damageOut = s.damageOut + (fight.damageOutTotal or 0)
	s.damageIn = s.damageIn + (fight.damageInTotal or 0)
	s.healingOut = s.healingOut + (fight.healingOutTotal or 0)
	s.dpsTime = s.dpsTime + (fight.dpstime or 0)
	s.hpsTime = s.hpsTime + (fight.hpstime or 0)
	s.combatTime = s.combatTime + (fight.combattime or 0)
	s.groupDamage = s.groupDamage + (fight.groupDamageOut or 0)
	GetEnemies(fight.units, s.enemies)
	s.detail = KPUI_FIGHT_TALLY.Merge(s.detail, detail)
	if type(fight.charData) == "table" then
		-- The character and loadout of the latest fight stand for the match;
		-- only copies are kept, never LibCombat's own tables.
		s.character = CharacterFields(fight.charData)
		s.loadout = CopyLoadout(fight.charData, fight.CP)
	end
end

local function BuildMatchRecord(s)
	local topEnemies, enemyCount = RankEnemies(s.enemies)
	local name = ""
	if s.bgId and s.bgId ~= 0 then
		name = GetBattlegroundName(s.bgId) or ""
	end
	return Finish(Merge(
	{
		kind = KIND_MATCH,
		content = CONTENT_BATTLEGROUND,
		timestamp = s.startedAt,
		zone = s.zone,
		target = name ~= "" and zo_strformat(SI_ZONE_NAME, name) or s.zone,
		bossFight = false,
		damageOut = s.damageOut, damageIn = s.damageIn, healingOut = s.healingOut,
		dpsOut = Rate(s.damageOut, s.dpsTime),
		dpsIn = Rate(s.damageIn, s.dpsTime),
		hpsOut = Rate(s.healingOut, s.hpsTime),
		duration = s.combatTime,
		dpsSeconds = s.dpsTime,
		group = true,
		groupDps = Rate(s.groupDamage, s.dpsTime),
		groupDamage = s.groupDamage,
		fights = s.fights,
		enemies = topEnemies, enemyCount = enemyCount,
		loadout = s.loadout,
		detail = s.detail,
	}, s.character or CharacterFields({})))
end

-- Writes the match to the list, or updates its entry when it is already there:
-- LibCombat can report the last fight after the match was first recorded.
local function PublishSession()
	local s = session
	if not s or s.damageOut + s.healingOut == 0 then
		return
	end
	local record = BuildMatchRecord(s)
	if s.record then
		for index, existing in ipairs(records) do
			if existing == s.record then
				records[index] = record
				break
			end
		end
		s.record = record
		SaveRecords()
		NotifyChanged()
	else
		s.record = record
		AddRecord(record)
	end
end

-- ---------------------------------------------------------------------------
-- Recording
-- ---------------------------------------------------------------------------

-- Group members send their own DPS and HPS every couple of seconds, so their
-- last figures can arrive after the fight is recorded: read them once more.
local SHARED_STATS_SETTLE_MS = 3000

local function RefreshSharedStatsLater(record)
	local roster = record and record.detail and record.detail.roster
	if not roster or next(roster) == nil or not KPUI_FIGHT_TALLY.HasGroupStats() then
		return
	end
	zo_callLater(function()
		local changed = false
		for name, stats in pairs(KPUI_FIGHT_TALLY.ReadGroupStats()) do
			if roster[name] then
				roster[name].shared = stats
				changed = true
			end
		end
		if changed then
			SaveRecords()
			NotifyChanged()
		end
	end, SHARED_STATS_SETTLE_MS)
end

local function OnFightSummary(_, fight)
	if type(fight) ~= "table" then
		return
	end
	-- Always taken, so the counters start over for the next fight.
	local detail = KPUI_FIGHT_TALLY.Take(fight)
	local context = GetContext()
	-- A fight that finishes after you left the match still belongs to it.
	local inMatch = context == CONTEXT_BATTLEGROUND
		or (session ~= nil and fight.zoneId ~= nil and fight.zoneId == session.zoneId)
	if inMatch then
		if KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FIGHT_STATS_BATTLEGROUNDS) then
			AddToSession(fight, detail)
			if session.record then
				PublishSession()
			end
		end
	elseif context == CONTEXT_PVE then
		if KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FIGHT_STATS_PVE) then
			local record = BuildFightRecord(fight, detail)
			AddRecord(record)
			RefreshSharedStatsLater(record)
		end
	end
end

-- True for a short while after leaving a match, so its last fight is not lost
-- when only battlegrounds are recorded.
local function IsMatchSettling()
	return session ~= nil and session.leftAt ~= nil
		and GetGameTimeMilliseconds() - session.leftAt < BG_LEAVE_SETTLE_MS * 2
end

local function ShouldRecord()
	if not KelaIsFightStatsAvailable() then
		return false
	end
	local battlegrounds = KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FIGHT_STATS_BATTLEGROUNDS)
	local context = GetContext()
	if context == CONTEXT_BATTLEGROUND then
		return battlegrounds
	elseif context == CONTEXT_PVE then
		return KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FIGHT_STATS_PVE)
			or (battlegrounds and IsMatchSettling())
	end
	return false
end

-- Listen to LibCombat only where recording is wanted.
local function UpdateRegistration()
	if not IsLibCombatLoaded() then
		return
	end
	local wanted = ShouldRecord()
	if wanted and not registered then
		registered = true
		LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_FIGHTSUMMARY, OnFightSummary, EVENT_NAMESPACE)
		KPUI_FIGHT_TALLY.Start()
	elseif not wanted and registered then
		registered = false
		LibCombat:UnregisterCallbackType(LIBCOMBAT_EVENT_FIGHTSUMMARY, OnFightSummary, EVENT_NAMESPACE)
		KPUI_FIGHT_TALLY.Stop()
	end
end

local function OnPlayerActivated()
	LoadRecords()
	local context = GetContext()
	if context == CONTEXT_BATTLEGROUND then
		-- Entering a match ends the previous one.
		local current = GetCurrentBattlegroundId()
		if session and (session.leftAt or (session.bgId ~= 0 and current ~= 0 and session.bgId ~= current)) then
			PublishSession()
			session = nil
		end
	elseif session and not session.leftAt then
		local s = session
		s.leftAt = GetGameTimeMilliseconds()
		zo_callLater(function()
			if session == s then
				PublishSession()
			end
		end, BG_LEAVE_SETTLE_MS)
		zo_callLater(UpdateRegistration, BG_LEAVE_SETTLE_MS * 2 + 1000)
	end
	UpdateRegistration()
end

local function OnBattlegroundStateChanged(_, _, currentState)
	if currentState == BATTLEGROUND_STATE_FINISHED then
		-- The last fight's summary arrives a few seconds after combat ends.
		local s = session
		zo_callLater(function()
			if session == s then
				PublishSession()
			end
		end, BG_FINISH_SETTLE_MS)
	end
end

local function OnSettingsChanged()
	LoadRecords()
	TrimRecords()
	SaveRecords()
	UpdateRegistration()
	NotifyChanged()
end

local setupDone = false

function KelaSetupFightStats()
	if setupDone then
		return
	end
	setupDone = true
	-- What the tally needs from the effect lists (kpui_fight_effect_match.lua).
	KPUI_FIGHT_STATS.InstallEffectFilter()
	-- The content type of a fight is where it began.
	KPUI_FIGHT_TALLY.SetContextProvider(GetContentType)
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "Battleground", EVENT_BATTLEGROUND_STATE_CHANGED, OnBattlegroundStateChanged)
	CALLBACK_MANAGER:RegisterCallback(SETTINGS_CHANGED_EVENT, OnSettingsChanged)
end


-- ---------------------------------------------------------------------------
-- Deleting
-- ---------------------------------------------------------------------------

local function DeleteRecord(record)
	for index, existing in ipairs(records) do
		if existing == record then
			table.remove(records, index)
			break
		end
	end
	-- A battleground match still being collected must not bring it back.
	if session and session.record == record then
		session = nil
	end
	SaveRecords()
	NotifyChanged()
end

local function DeleteAllRecords()
	ZO_ClearNumericallyIndexedTable(records)
	session = nil
	SaveRecords()
	NotifyChanged()
end

-- ---------------------------------------------------------------------------
-- Shared with the screen
-- ---------------------------------------------------------------------------

KPUI_FIGHT_STATS.KIND_MATCH = KIND_MATCH
KPUI_FIGHT_STATS.CONTENT_BATTLEGROUND = CONTENT_BATTLEGROUND
KPUI_FIGHT_STATS.CONTENT_NAMES = CONTENT_NAMES
KPUI_FIGHT_STATS.GetClassIcon = GetClassIcon
KPUI_FIGHT_STATS.DeleteRecord = DeleteRecord
KPUI_FIGHT_STATS.DeleteAllRecords = DeleteAllRecords

function KPUI_FIGHT_STATS.GetRecords()
	LoadRecords()
	return records
end
