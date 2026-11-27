-- KelaPadUI Raidificator: the trial, arena and dungeon records Raidificator
-- (by code65536) keeps, in the gamepad data browser
-- (kpui_core/kpui_gamepad_browser.lua). Two pages, switched with L1/R1:
--
--   * Achievements: dungeon, trial, arena and solo progress per zone (clear,
--     hard mode, speed run, no death, trifecta), with filters for the
--     category, how far along it is, and what you are still missing.
--   * Score History: every recorded clear, with filters for the content, the
--     account, character and server, how recent it is, and each character's
--     best clear.
--
-- Raidificator has no data API, so this reads its own tables:
-- `Raidificator.history` (clears are comma-separated strings, characters and
-- notes beside them), `Raidificator.SCORED_CONTENT`,
-- `Raidificator.GetAchievementData()` and `Raidificator.ACHIEVEMENT_FLAGS`.
-- It only reads: notes and score banners stay in the keyboard window. The
-- current account's achievements are shown; multi-account data from
-- LibMultiAccountAchievements is not.

local SCENE_NAME = "KelaRaidificator"
local EVENT_NAMESPACE = "KelaPadUI_Raidificator"

local CATEGORY_DUNGEONS, CATEGORY_TRIALS, CATEGORY_ARENAS, CATEGORY_SOLO = 1, 2, 3, 4

local INFINITE_ARCHIVE = "1E"
-- Infinite Archive clears of Arc 1 and the start of Arc 2 sort at or below this
-- (Raidificator's own "Hide Arc 1" cut-off).
local ARC_ONE_SORT_LIMIT = "00211"

local SECONDS_PER_DAY = 86400

local TIME_TODAY = "today"
local PROGRESS_COMPLETE, PROGRESS_STARTED, PROGRESS_NOT_STARTED = "complete", "started", "none"
local MISSING_CLEAR = "C"

local VITALITY_ICON = "/esoui/art/trials/vitalitydepletion.dds"
local ARC_ICON = "/esoui/art/endlessdungeon/thick_outline_icon_progression_arc.dds"

function KelaIsRaidificatorAvailable()
	return type(Raidificator) == "table"
		and type(Raidificator.history) == "table"
		and type(Raidificator.history.clears) == "table"
		and type(Raidificator.SCORED_CONTENT) == "table"
		and type(Raidificator.GetCharacterData) == "function"
		and type(Raidificator.GetAchievementData) == "function"
		and type(Raidificator.ACHIEVEMENT_FLAGS) == "table"
		and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FEATURES_RAIDIFICATOR)
end

local function GetLabel(options, value)
	for _, option in ipairs(options) do
		if option.value == value then
			return option.label
		end
	end
	return ""
end

-- A ratio of 0 to 1 as a colour: done, in progress, not started.
local function ColorizeByRatio(text, ratio)
	if ratio >= 1 then
		return kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(text)
	elseif ratio > 0 then
		return kpuiConst.Colors.COLOR_LIGHT_ORANGE:Colorize(text)
	end
	return kpuiConst.Colors.COLOR_GREY:Colorize(text)
end

-- ---------------------------------------------------------------------------
-- Score History
-- ---------------------------------------------------------------------------

local history = { name = function() return GetString(KELA_RAIDIFICATOR_HISTORY) end, search = "", records = {}, initialized = false }

local function FormatDuration(milliseconds)
	local seconds = zo_floor(milliseconds / 1000)
	local hours = zo_floor(seconds / 3600)
	local minutes = zo_floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

-- The zone name of each scored content, in Raidificator's order.
local function GetContentNames()
	local names, order = {}, {}
	for _, content in ipairs(Raidificator.SCORED_CONTENT) do
		local name = zo_strformat(SI_ZONE_NAME, GetZoneNameById(content[2]))
		if name ~= "" then
			names[content[1]] = name
			order[#order + 1] = content[1]
		end
	end
	return names, order
end

-- The text Raidificator sorts its Details column by, and its Arc 1 test uses:
-- values padded with zeros so that a text compare orders them.
local function GetExtraSort(extra)
	local values = {}
	for index, value in ipairs(extra) do
		values[index] = tonumber(value) or 0
	end
	if #values < 3 then
		return string.format("%02d%02d", values[1] or 0, values[2] or 0)
	end
	return string.format("%03d%d%d", values[1], values[2], values[3])
end

local function BuildHistory()
	local records = {}
	local contentNames = GetContentNames()
	local notes = type(Raidificator.history.notes) == "table" and Raidificator.history.notes or {}
	for index, entry in pairs(Raidificator.history.clears) do
		local contentId, server, timestamp, character, score, duration, extraText, group = zo_strsplit(",", entry)
		local userId, charName, classId = Raidificator.GetCharacterData(character)
		if charName and contentId then
			local extra = { zo_strsplit(";", extraText or "") }
			local classIcon = nil
			local classIndex = GetClassIndexById(tonumber(classId) or 0)
			if classIndex then
				classIcon = select(8, GetClassInfo(classIndex))
			end
			local contentName = contentNames[contentId] or contentId
			local note = notes[index] or ""
			records[#records + 1] =
			{
				contentId = contentId,
				contentName = contentName,
				contentSort = zo_strlower(contentName),
				server = server,
				timestamp = tonumber(timestamp) or 0,
				userId = userId,
				character = charName,
				characterSort = zo_strlower(charName),
				classIcon = classIcon,
				score = tonumber(score) or 0,
				duration = tonumber(duration) or 0,
				extra = extra,
				extraSort = GetExtraSort(extra),
				group = group or "",
				note = note,
				bestKey = contentId .. ":" .. tostring(userId) .. ":" .. charName,
				searchText = zo_strlower(table.concat({ charName, tostring(userId), contentName, note }, " ")),
			}
		end
	end
	table.sort(records, function(a, b)
		return a.timestamp > b.timestamp
	end)
	return records
end

function history:Activate()
	if not self.initialized then
		self.initialized = true
		-- Start on the content the keyboard window last showed.
		local vars = Raidificator.vars
		if type(vars) == "table" and type(vars.contentId) == "string" then
			self.contentId = vars.contentId
		end
	end
	self.records = BuildHistory()
end

function history:GetColumns()
	return
	{
		{ title = KELA_RAIDIFICATOR_DATE, key = "timestamp", width = 2.2 },
		{ title = KELA_RAIDIFICATOR_CONTENT, key = "contentSort", width = 3.4 },
		{ title = KELA_RAIDIFICATOR_CHARACTER, key = "characterSort", width = 3 },
		{ title = KELA_RAIDIFICATOR_SCORE, key = "score", width = 1.4, align = TEXT_ALIGN_RIGHT },
		{ title = KELA_RAIDIFICATOR_TIME, key = "duration", width = 1.3, align = TEXT_ALIGN_RIGHT },
		{ title = KELA_RAIDIFICATOR_DETAILS, key = "extraSort", width = 1.8 },
	}
end

function history:GetSortState()
	return "timestamp", ZO_SORT_ORDER_DOWN
end

local function GetTimeCutoff(range)
	if range == nil then
		return nil
	elseif range == TIME_TODAY then
		-- The daily reset that just passed.
		if KelaGetDailyResetBoundary then
			return KelaGetDailyResetBoundary(GetTimeStamp()) - SECONDS_PER_DAY
		end
		return GetTimeStamp() - SECONDS_PER_DAY
	end
	return GetTimeStamp() - range * SECONDS_PER_DAY
end

function history:GetRows()
	self.records = BuildHistory()
	local needle = zo_strlower(self.search)
	local cutoff = GetTimeCutoff(self.range)
	local rows = {}
	for _, record in ipairs(self.records) do
		if (needle == "" or zo_plainstrfind(record.searchText, needle))
			and (self.contentId == nil or record.contentId == self.contentId)
			and (self.userId == nil or record.userId == self.userId)
			and (self.character == nil or record.character == self.character)
			and (self.server == nil or record.server == self.server)
			and (cutoff == nil or record.timestamp >= cutoff)
			and (not self.notesOnly or record.note ~= "")
			and (not (self.hideArcOne and record.contentId == INFINITE_ARCHIVE) or record.extraSort > ARC_ONE_SORT_LIMIT) then
			rows[#rows + 1] = record
		end
	end
	if self.bestOnly then
		-- Each character's highest score per content.
		local best = {}
		for _, record in ipairs(rows) do
			local current = best[record.bestKey]
			if not current or record.score > current.score then
				best[record.bestKey] = record
			end
		end
		local kept = {}
		for _, record in ipairs(rows) do
			if best[record.bestKey] == record then
				kept[#kept + 1] = record
			end
		end
		rows = kept
	end
	return rows
end

function history:GetCellTexts(record)
	local character = record.character
	if record.classIcon then
		character = zo_iconFormat(record.classIcon, 24, 24) .. " " .. character
	end
	local details = ""
	if #record.extra > 0 then
		local formatted = type(Raidificator.FormatExtra) == "function" and Raidificator.FormatExtra(unpack(record.extra))
			or table.concat(record.extra, "/")
		details = zo_iconFormat(#record.extra < 3 and VITALITY_ICON or ARC_ICON, 22, 22) .. " " .. formatted
	end
	local date = os.date("%Y-%m-%d %H:%M", record.timestamp)
	if record.note ~= "" then
		date = date .. " " .. kpuiConst.Colors.COLOR_GOLD:Colorize("*")
	end
	return { date, record.contentName, character, tostring(record.score), FormatDuration(record.duration), details }
end

-- The group, then the note: the keyboard window's tooltip.
function history:GetTooltip(record)
	local lines = {}
	if record.group ~= "" then
		lines[#lines + 1] = ZO_SELECTED_TEXT:Colorize(GetString(KELA_RAIDIFICATOR_GROUP_MEMBERS))
		for _, member in ipairs({ zo_strsplit(";", record.group) }) do
			local charName, userId, classId, role = zo_strsplit(":", member)
			-- The recording character: "~role" in place of a name.
			local ownRole = charName and string.match(charName, "^~(%d)$")
			if ownRole then
				charName, userId, role = record.character, record.userId, ownRole
			end
			if charName and charName ~= "" then
				local line = charName
				if userId and userId ~= "" then
					line = line .. " (" .. DecorateDisplayName(userId) .. ")"
				end
				if tonumber(role) then
					line = line .. " - " .. GetString("SI_LFGROLE", tonumber(role))
				end
				lines[#lines + 1] = line
			end
		end
	end
	if record.note ~= "" then
		if #lines > 0 then
			lines[#lines + 1] = ""
		end
		lines[#lines + 1] = ZO_SELECTED_TEXT:Colorize(GetString(SI_GAMEPAD_CONTACTS_NOTES_TITLE))
		lines[#lines + 1] = record.note
	end
	if #lines == 0 then
		return nil
	end
	return "text", table.concat(lines, "\n")
end

local function GetContentOptions()
	local names, order = GetContentNames()
	local options = { { label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) } }
	for _, contentId in ipairs(order) do
		options[#options + 1] = { label = names[contentId], value = contentId }
	end
	return options
end

-- The distinct values of a record field, by name, after "All".
local function GetFieldOptions(records, field)
	local options, seen = {}, {}
	for _, record in ipairs(records) do
		local value = record[field]
		if value ~= nil and not seen[value] then
			seen[value] = true
			options[#options + 1] = { label = tostring(value), value = value, sort = zo_strlower(tostring(value)) }
		end
	end
	table.sort(options, function(a, b)
		return a.sort < b.sort
	end)
	table.insert(options, 1, { label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) })
	return options
end

local function GetRangeOptions()
	return
	{
		{ label = GetString(KELA_RAIDIFICATOR_ANY_TIME) },
		{ label = GetString(KELA_RAIDIFICATOR_TODAY), value = TIME_TODAY },
		{ label = GetString(KELA_RAIDIFICATOR_LAST_7_DAYS), value = 7 },
		{ label = GetString(KELA_RAIDIFICATOR_LAST_30_DAYS), value = 30 },
		{ label = GetString(KELA_RAIDIFICATOR_LAST_YEAR), value = 365 },
	}
end

function history:GetFilters()
	local Filter = KelaGamepadBrowser
	local filters =
	{
		Filter.SearchFilter(self, "search"),
		Filter.ChoiceFilter(self, "contentId", GetString(KELA_RAIDIFICATOR_CONTENT), GetContentOptions),
		Filter.ChoiceFilter(self, "userId", GetString(KELA_RAIDIFICATOR_ACCOUNT), function()
			return GetFieldOptions(self.records, "userId")
		end),
		Filter.ChoiceFilter(self, "character", GetString(KELA_RAIDIFICATOR_CHARACTER), function()
			return GetFieldOptions(self.records, "character")
		end),
		Filter.ChoiceFilter(self, "server", GetString(KELA_RAIDIFICATOR_SERVER), function()
			return GetFieldOptions(self.records, "server")
		end),
		Filter.ChoiceFilter(self, "range", GetString(KELA_RAIDIFICATOR_TIME_RANGE), GetRangeOptions),
		Filter.ToggleFilter(self, "bestOnly", GetString(KELA_RAIDIFICATOR_BEST_ONLY)),
		Filter.ToggleFilter(self, "notesOnly", GetString(KELA_RAIDIFICATOR_NOTES_ONLY)),
		-- Only Infinite Archive has arcs; the toggle leaves other content alone.
		Filter.ToggleFilter(self, "hideArcOne", GetString(KELA_RAIDIFICATOR_HIDE_ARC_ONE)),
	}
	return filters
end

function history:GetSummary()
	local names = GetContentNames()
	return
	{
		{ GetString(KELA_RAIDIFICATOR_CONTENT), self.contentId and (names[self.contentId] or self.contentId) or GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ GetString(KELA_RAIDIFICATOR_ACCOUNT), self.userId or GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ GetString(KELA_RAIDIFICATOR_CHARACTER), self.character or GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ GetString(KELA_RAIDIFICATOR_TIME_RANGE), GetLabel(GetRangeOptions(), self.range) },
	}
end

-- ---------------------------------------------------------------------------
-- Achievements
-- ---------------------------------------------------------------------------

local achievements = { name = function() return GetString(KELA_RAIDIFICATOR_ACHIEVEMENTS) end, search = "", records = nil }

-- The achievement-type flags Raidificator tags each achievement with; the keys
-- are the letters of Raidificator.ACHIEVEMENT_FLAGS.
local FLAG_VETERAN, FLAG_CLEAR = "V", "C"
local TALLIES = { "H", "S", "N", "T" }

local function HasFlag(flags, letter)
	local flag = Raidificator.ACHIEVEMENT_FLAGS[letter]
	return flag ~= nil and BitAnd(flags, flag) == flag
end

local failureLogged = false

-- The static part of each record: the zone and its achievements.
local function BuildAchievements()
	local ok, data = pcall(Raidificator.GetAchievementData)
	if not ok or type(data) ~= "table" then
		if not failureLogged and KelaPadUI.log then
			failureLogged = true
			KelaPadUI.log:Warn("Raidificator achievement data unavailable: %s", tostring(data))
		end
		return {}
	end
	local records = {}
	for index, entry in ipairs(data) do
		local names = {}
		for _, achievement in ipairs(entry.achs) do
			names[#names + 1] = GetAchievementName(achievement.id)
		end
		records[#records + 1] =
		{
			release = index,
			category = entry.category,
			year = entry.year,
			name = entry.name,
			sortName = zo_strlower(entry.name),
			icon = GetCollectibleIcon(entry.trophy),
			achs = entry.achs,
			searchText = zo_strlower(entry.name .. " " .. tostring(entry.year) .. " " .. table.concat(names, " ")),
		}
	end
	return records
end

-- The state of each record: how much of each achievement type is earned.
local function UpdateAchievementState(record)
	local totals, earned = { A = 0, H = 0, S = 0, N = 0, T = 0 }, { A = 0, H = 0, S = 0, N = 0, T = 0 }
	local clear, clearMax = 0, 0
	local function Tally(counts, flags)
		for _, letter in ipairs(TALLIES) do
			if HasFlag(flags, letter) then
				counts[letter] = counts[letter] + 1
			end
		end
	end
	for _, achievement in ipairs(record.achs) do
		local difficulty = HasFlag(achievement.flags, FLAG_VETERAN) and DUNGEON_DIFFICULTY_VETERAN or DUNGEON_DIFFICULTY_NORMAL
		totals.A = totals.A + 1
		Tally(totals, achievement.flags)
		if HasFlag(achievement.flags, FLAG_CLEAR) then
			clearMax = zo_max(clearMax, difficulty)
		end
		if IsAchievementComplete(achievement.id) then
			earned.A = earned.A + 1
			Tally(earned, achievement.flags)
			if HasFlag(achievement.flags, FLAG_CLEAR) then
				clear = zo_max(clear, difficulty)
			end
		end
	end
	record.totals, record.earned = totals, earned
	record.clear, record.clearMax = clear, clearMax
	-- Sort keys: the ratio, or -1 for a type the zone has none of.
	local function Ratio(letter)
		return totals[letter] > 0 and earned[letter] / totals[letter] or -1
	end
	record.clearRatio = clearMax > 0 and clear / clearMax or -1
	record.hardRatio, record.speedRatio, record.noDeathRatio, record.trifectaRatio = Ratio("H"), Ratio("S"), Ratio("N"), Ratio("T")
	record.countRatio = totals.A > 0 and earned.A / totals.A or -1
end

-- Built once it has rows: the data is empty until Raidificator has decoded it.
function achievements:EnsureRecords()
	if not self.records or #self.records == 0 then
		self.records = BuildAchievements()
	end
end

function achievements:Activate()
	self:EnsureRecords()
end

function achievements:GetColumns()
	return
	{
		{ title = KELA_RAIDIFICATOR_RELEASE, key = "release", width = 1.1 },
		{ title = KELA_RAIDIFICATOR_NAME, key = "sortName", width = 4 },
		{ title = KELA_RAIDIFICATOR_CLEAR, key = "clearRatio", width = 1.6 },
		{ title = KELA_RAIDIFICATOR_HARD_MODE, key = "hardRatio", width = 1.4 },
		{ title = KELA_RAIDIFICATOR_SPEED_RUN, key = "speedRatio", width = 1.4 },
		{ title = KELA_RAIDIFICATOR_NO_DEATH, key = "noDeathRatio", width = 1.4 },
		{ title = KELA_RAIDIFICATOR_TRIFECTA, key = "trifectaRatio", width = 1.4 },
		{ title = KELA_RAIDIFICATOR_COMPLETED, key = "countRatio", width = 1.5 },
	}
end

-- Newest zone first, as Raidificator lists them.
function achievements:GetSortState()
	return "release", ZO_SORT_ORDER_DOWN
end

-- True when the zone still has something to earn of the missing type.
local function IsMissing(record, missing)
	if missing == MISSING_CLEAR then
		return record.clearMax > 0 and record.clear < record.clearMax
	end
	return record.totals[missing] > record.earned[missing]
end

function achievements:GetRows()
	self:EnsureRecords()
	local needle = zo_strlower(self.search)
	local rows = {}
	local seen, total, completed = {}, 0, 0
	for _, record in ipairs(self.records) do
		UpdateAchievementState(record)
		local progress = PROGRESS_NOT_STARTED
		if record.totals.A > 0 and record.earned.A == record.totals.A then
			progress = PROGRESS_COMPLETE
		elseif record.earned.A > 0 then
			progress = PROGRESS_STARTED
		end
		if (needle == "" or zo_plainstrfind(record.searchText, needle))
			and (self.category == nil or record.category == self.category)
			and (self.progress == nil or progress == self.progress)
			and (self.missing == nil or IsMissing(record, self.missing)) then
			rows[#rows + 1] = record
			for _, achievement in ipairs(record.achs) do
				if not seen[achievement.id] then
					seen[achievement.id] = true
					total = total + 1
					if IsAchievementComplete(achievement.id) then
						completed = completed + 1
					end
				end
			end
		end
	end
	self.completedCount, self.totalCount = completed, total
	return rows
end

local function FormatRatio(earned, total)
	if total == 0 then
		return ""
	end
	return ColorizeByRatio(string.format("%d / %d", earned, total), earned / total)
end

function achievements:GetCellTexts(record)
	local clearText = ""
	if record.clearMax > 0 then
		if record.clear == 0 then
			clearText = GetString(SI_ALLIANCE0)
		elseif record.clearMax == DUNGEON_DIFFICULTY_NORMAL then
			clearText = GetString(SI_ACHIEVEMENTS_TOOLTIP_COMPLETE)
		else
			clearText = GetString("SI_DUNGEONDIFFICULTY", record.clear)
		end
		clearText = ColorizeByRatio(clearText, record.clear / record.clearMax)
	end
	local earned, totals = record.earned, record.totals
	return
	{
		tostring(record.year),
		record.name,
		clearText,
		FormatRatio(earned.H, totals.H),
		FormatRatio(earned.S, totals.S),
		FormatRatio(earned.N, totals.N),
		FormatRatio(earned.T, totals.T),
		FormatRatio(earned.A, totals.A),
	}, record.icon
end

-- Every achievement of the zone, earned ones in green.
function achievements:GetTooltip(record)
	local lines = {}
	for _, achievement in ipairs(record.achs) do
		local name = GetAchievementName(achievement.id)
		lines[#lines + 1] = IsAchievementComplete(achievement.id) and kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(name) or name
	end
	return "text", table.concat(lines, "\n")
end

-- Puts achievement links in the chat box, as many as fit.
local function LinkAchievements(ids)
	local MAX_CHAT_LENGTH = 346
	local links, skipped, left = {}, 0, MAX_CHAT_LENGTH
	for _, achievementId in ipairs(ids) do
		local link = GetAchievementLink(achievementId, LINK_STYLE_BRACKETS)
		if left - zo_strlen(link) >= 0 then
			links[#links + 1] = link
			left = left - zo_strlen(link)
		else
			skipped = skipped + 1
		end
	end
	if #links > 0 then
		local message = table.concat(links, "")
		if skipped > 0 then
			message = message .. " +" .. skipped
		end
		ZO_LinkHandler_InsertLink(message)
	end
end

-- X links the zone's earned achievements, Y the ones still to earn.
function achievements:GetActions(record)
	local cleared, uncleared = {}, {}
	for _, achievement in ipairs(record.achs) do
		local list = IsAchievementComplete(achievement.id) and cleared or uncleared
		list[#list + 1] = achievement.id
	end
	local actions = {}
	if #cleared > 0 then
		actions[#actions + 1] =
		{
			label = GetString(KELA_RAIDIFICATOR_LINK_CLEARED),
			keybind = "UI_SHORTCUT_SECONDARY",
			action = function()
				LinkAchievements(cleared)
			end,
		}
	end
	if #uncleared > 0 then
		actions[#actions + 1] =
		{
			label = GetString(KELA_RAIDIFICATOR_LINK_INCOMPLETE),
			keybind = "UI_SHORTCUT_TERTIARY",
			action = function()
				LinkAchievements(uncleared)
			end,
		}
	end
	return actions
end

-- An achievement category's name, from the achievement the game files it under.
local function GetCategoryName(achievementId, useSubCategory)
	local topLevel, subCategory = GetCategoryInfoFromAchievementId(achievementId)
	if not topLevel then
		return ""
	end
	if useSubCategory and subCategory then
		return (GetAchievementSubCategoryInfo(topLevel, subCategory))
	end
	return (GetAchievementCategoryInfo(topLevel))
end

local function GetCategoryOptions()
	return
	{
		{ label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ label = GetString("SI_GUILDACTIVITYATTRIBUTEVALUE", GUILD_ACTIVITY_ATTRIBUTE_VALUE_DUNGEONS), value = CATEGORY_DUNGEONS },
		{ label = GetString("SI_GUILDACTIVITYATTRIBUTEVALUE", GUILD_ACTIVITY_ATTRIBUTE_VALUE_TRIALS), value = CATEGORY_TRIALS },
		{ label = GetCategoryName(992), value = CATEGORY_ARENAS },
		{ label = GetCategoryName(4693, true), value = CATEGORY_SOLO },
	}
end

local function GetProgressOptions()
	return
	{
		{ label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ label = GetString(KELA_RAIDIFICATOR_PROGRESS_COMPLETE), value = PROGRESS_COMPLETE },
		{ label = GetString(KELA_RAIDIFICATOR_PROGRESS_STARTED), value = PROGRESS_STARTED },
		{ label = GetString(KELA_RAIDIFICATOR_PROGRESS_NOT_STARTED), value = PROGRESS_NOT_STARTED },
	}
end

local function GetMissingOptions()
	return
	{
		{ label = GetString(KELA_RAIDIFICATOR_MISSING_ANY) },
		{ label = GetString(KELA_RAIDIFICATOR_CLEAR), value = MISSING_CLEAR },
		{ label = GetString(KELA_RAIDIFICATOR_HARD_MODE), value = "H" },
		{ label = GetString(KELA_RAIDIFICATOR_SPEED_RUN), value = "S" },
		{ label = GetString(KELA_RAIDIFICATOR_NO_DEATH), value = "N" },
		{ label = GetString(KELA_RAIDIFICATOR_TRIFECTA), value = "T" },
	}
end

function achievements:GetFilters()
	local Filter = KelaGamepadBrowser
	return
	{
		Filter.SearchFilter(self, "search"),
		Filter.ChoiceFilter(self, "category", GetString(KELA_RAIDIFICATOR_CATEGORY), GetCategoryOptions),
		Filter.ChoiceFilter(self, "progress", GetString(KELA_RAIDIFICATOR_PROGRESS), GetProgressOptions),
		Filter.ChoiceFilter(self, "missing", GetString(KELA_RAIDIFICATOR_MISSING), GetMissingOptions),
	}
end

function achievements:GetSummary()
	local percent = (self.totalCount or 0) > 0 and zo_round(100 * self.completedCount / self.totalCount) or 0
	return
	{
		{ GetString(KELA_RAIDIFICATOR_COMPLETED), string.format("%d / %d (%d%%)", self.completedCount or 0, self.totalCount or 0, percent) },
		{ GetString(KELA_RAIDIFICATOR_CATEGORY), GetLabel(GetCategoryOptions(), self.category) },
		{ GetString(KELA_RAIDIFICATOR_PROGRESS), GetLabel(GetProgressOptions(), self.progress) },
		{ GetString(KELA_RAIDIFICATOR_MISSING), GetLabel(GetMissingOptions(), self.missing) },
	}
end

-- ---------------------------------------------------------------------------
-- Screen
-- ---------------------------------------------------------------------------

local sources = { achievements, history }
local browser
local hooked = false

-- Raidificator tells the clear list when it records a clear.
local function HookNewClear()
	if hooked or type(Raidificator.NewClearAdded) ~= "function" then
		return
	end
	hooked = true
	ZO_PostHook(Raidificator, "NewClearAdded", function()
		KelaGamepadBrowser.Changed(history)
	end)
end

function KelaShowRaidificator()
	if not KelaIsRaidificatorAvailable() then
		return
	end
	HookNewClear()
	if not browser then
		browser = KelaGamepadBrowser:New(SCENE_NAME)
		browser:SetSources(sources, 1)
	end
	SCENE_MANAGER:Push(SCENE_NAME)
end

local setupDone = false

-- Refreshes the achievements page when one is earned.
function KelaSetupRaidificator()
	if setupDone then
		return
	end
	setupDone = true
	local function OnAchievementChanged()
		KelaGamepadBrowser.Changed(achievements)
	end
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "Awarded", EVENT_ACHIEVEMENT_AWARDED, OnAchievementChanged)
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "Updated", EVENT_ACHIEVEMENT_UPDATED, OnAchievementChanged)
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "All", EVENT_ACHIEVEMENTS_UPDATED, OnAchievementChanged)
end
