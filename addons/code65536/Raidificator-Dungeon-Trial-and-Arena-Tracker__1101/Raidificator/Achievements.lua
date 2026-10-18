local LCCC = LibCodesCommonCode
local LMAA = LibMultiAccountAchievements
local LUP = LibUndauntedPledges
local LEJ = LibExtendedJournal
local RCR = Raidificator


--------------------------------------------------------------------------------
-- Extended Journal
--------------------------------------------------------------------------------

local TAB_NAME = "RaidificatorAchievements"
local FRAME = RaidificatorAchievementsFrame
local DATA_TYPE = 1
local SORT_TYPE = 1

local Initialized = false
local Dirtiness = 0
local AlwaysRefreshOnShow = false
local ContextMenuItems = { }

function RCR.InitializeAchievements( )
	local buttons = {
		{
			name = GetString(SI_SETTING_ENTER_SCREENSHOT_MODE),
			keybind = "UI_SHORTCUT_SECONDARY",
			callback = RaidificatorAchievementScreenshotMode,
		},
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
	}

	if (RCR.PledgesEnabled()) then
		table.insert(buttons, RCR.GetPledgesButton())
	end

	LEJ.RegisterTab(TAB_NAME, {
		title = SI_RCR_TITLE,
		subtitle = SI_RCR_SUBTITLE_ACHIEVEMENTS,
		order = 500,
		iconPrefix = "/esoui/art/journal/journal_tabicon_achievements_",
		control = FRAME,
		settingsPanel = RCR.settingsPanel,
		binding = "RCR_ACHIEVEMENTS",
		slashCommands = { "/rat" },
		callbackShow = function( )
			RCR.LazyInitializeAchievements()
			RCR.RefreshAchievements(true)
			KEYBIND_STRIP:AddKeybindButtonGroup(buttons)
		end,
		callbackHide = function( )
			KEYBIND_STRIP:RemoveKeybindButtonGroup(buttons)
		end,
	})
end

function RCR.LazyInitializeAchievements( )
	if (not Initialized) then
		Initialized = true

		RCR.achList = RaidificatorAchievementsList:New(FRAME, ContextMenuItems)

		local refresh = function( )
			Dirtiness = 1
			RCR.RefreshAchievements()
		end

		EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_ACHIEVEMENTS_UPDATED, refresh)
		EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_ACHIEVEMENT_AWARDED, refresh)
		EVENT_MANAGER:RegisterForEvent(RCR.name, EVENT_ACHIEVEMENT_UPDATED, refresh)
	end
end

function RCR.RefreshAchievements( noActiveCheck )
	if (Initialized and (Dirtiness > 0 or AlwaysRefreshOnShow) and (noActiveCheck or LEJ.IsTabActive(TAB_NAME))) then
		if (Dirtiness == 0 and AlwaysRefreshOnShow) then
			RCR.achList:RefreshFilters()
		else
			RCR.achList:RefreshAchievementState()
			Dirtiness = 0
		end
	end
end


--------------------------------------------------------------------------------
-- API Acesss (overridden later if LMAA is present)
--------------------------------------------------------------------------------

local GetAchTimestamp = GetAchievementTimestamp
local IsAchComplete = IsAchievementComplete
local GetAchCriterion = GetAchievementCriterion
local GetAchLink = GetAchievementLink


--------------------------------------------------------------------------------
-- Register Context Menu
--------------------------------------------------------------------------------

function RCR.RegisterAchievementContextMenuItem( func )
	table.insert(ContextMenuItems, func)
end

RCR.RegisterAchievementContextMenuItem(function( data )
	return SI_RCR_LINK_INCOMPLETE, function( )
		local results = { }
		local remaining = 346
		local skipped = 0

		for _, ach in ipairs(data.achs) do
			if (not IsAchComplete(ach.id)) then
				local link = GetAchLink(ach.id, LINK_STYLE_BRACKETS)
				local newRemaining = remaining - zo_strlen(link)
				if (newRemaining >= 0) then
					table.insert(results, link)
					remaining = newRemaining
				else
					skipped = skipped + 1
				end
			end
		end

		if (#results > 0) then
			local message = table.concat(results, "")
			if (skipped > 0) then
				message = string.format("%s +%d", message, skipped)
			end
			ZO_LinkHandler_InsertLink(message)
		end
	end
end)

RCR.RegisterAchievementContextMenuItem(function( data )
	if (data.contentId) then
		return SI_RCR_SUBTITLE_HISTORY, function( )
			RCR.NewClearAdded(data.contentId)
			LEJ.Show("Raidificator")
		end
	end
end)


--------------------------------------------------------------------------------
-- Achievement Data
--------------------------------------------------------------------------------

RCR.ACHIEVEMENT_FIELD_SIZE = 3
RCR.FLAGS_FIELD_SIZE = 2
RCR.ACHIEVEMENT_FLAGS = {
	V = 0x01, -- Veteran
	C = 0x02, -- Clear
	H = 0x04, -- Hard Mode
	S = 0x08, -- Speed Run
	N = 0x10, -- No Death
	T = 0x20, -- Trifecta
	-- The following flags are used only for ESO Clears Bot
	F = 0x40, -- Hard Mode (final boss)
	M = 0x80, -- Misc
}

local CATEGORY_DUNGEONS = 1
local CATEGORY_TRIALS = 2
local CATEGORY_ARENAS = 3
local CATEGORY_SOLO_DUNGEONS = 4

do
	local Data

	local function CheckCategory( zoneId, code, category, offset )
		local zone = RCR.ZONES[code][zoneId]
		if (zone) then
			return {
				category = category,
				year = zone[offset],
				trophy = zone[offset + 1]
			}
		end
	end

	function RCR.GetAchievementData( )
		if (not Data) then
			Data = { }

			for _, encoded in ipairs({ zo_strsplit(",", LCCC.Unchunk(RCR.ACHIEVEMENT_DATA())) }) do
				local length = zo_strlen(encoded)
				local zoneId, i = LCCC.ReadAndDecode(encoded, 1, RCR.ACHIEVEMENT_FIELD_SIZE)
				local zoneName = LCCC.GetZoneName(zoneId)

				if (zoneName ~= "") then
					local entry = CheckCategory(zoneId, "D", CATEGORY_DUNGEONS, 3) or CheckCategory(zoneId, "T", CATEGORY_TRIALS, 1) or CheckCategory(zoneId, "A", CATEGORY_ARENAS, 1) or CheckCategory(zoneId, "S", CATEGORY_SOLO_DUNGEONS, 1)

					if (entry) then
						entry.zoneId = zoneId
						entry.name = zoneName
						entry.achs = { }

						while (i < length) do
							local achievementId, flags
							achievementId, i = LCCC.ReadAndDecode(encoded, i, RCR.ACHIEVEMENT_FIELD_SIZE)
							flags, i = LCCC.ReadAndDecode(encoded, i, RCR.FLAGS_FIELD_SIZE)
							if (GetAchievementNumCriteria(achievementId) > 0) then
								table.insert(entry.achs, { id = achievementId, flags = flags })
							end
						end

						if (entry.category ~= CATEGORY_DUNGEONS) then
							for _, content in ipairs(RCR.SCORED_CONTENT) do
								if (entry.zoneId == content[2]) then
									entry.contentId = content[1]
								end
							end
						end

						table.insert(Data, entry)
					end
				end
			end
		end

		return Data
	end
end


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function CheckFlag( value, flag )
	flag = RCR.ACHIEVEMENT_FLAGS[flag]
	return BitAnd(value, flag) == flag
end

local function AddToTally( tallies, flags )
	for k in pairs(tallies) do
		if (RCR.ACHIEVEMENT_FLAGS[k] and CheckFlag(flags, k)) then
			tallies[k] = tallies[k] + 1
		end
	end
end

local function GetAchName( achievementId )
	return LocalizeString(GetAchievementName(achievementId))
end

local function SearchAchievementNames( haystack, needle )
	for _, ach in ipairs(haystack) do
		if (zo_plainstrfind(GetAchName(ach.id):lower(), needle)) then
			return true
		end
	end
	return false
end


--------------------------------------------------------------------------------
-- Functions to display and format data
--------------------------------------------------------------------------------

local COLOR_COMPLETE = 0x00FF00FF
local COLOR_INCOMPLETE = 0x666666CC
local COLOR_DIVIDER = 0xCCCC9966
RCR.COLOR_DIVIDER = COLOR_DIVIDER

local function SetRatioColor( control, ratio )
	control.nonRecolorable = true
	if (ratio == 1) then
		control:SetColor(LCCC.Int32ToRGBA(COLOR_COMPLETE))
	elseif (ratio == 0) then
		control:SetColor(LCCC.Int32ToRGBA(COLOR_INCOMPLETE))
	elseif (ratio > 0) then
		control:SetColor(LCCC.HSLToRGB((1 / 3 + ratio) / 6, 1, 0.5, 1))
	end
	control:SetAlpha(ratio < 0 and 0 or 1)
end

local function SetFieldText( control, name, field, data )
	local element = control:GetNamedChild(name)
	local value = data[field]

	if (field == "clear") then
		if (data.clearMax == 0) then
			element:SetText("")
		else
			local text
			if (value == 0) then
				text = GetString(SI_ALLIANCE0)
			elseif (data.clearMax == 1) then
				text = GetString(SI_ACHIEVEMENTS_TOOLTIP_COMPLETE)
			else
				text = GetString("SI_DUNGEONDIFFICULTY", value)
			end
			element:SetText(text)
			SetRatioColor(element, value / data.clearMax)
		end
	elseif (field == "hard" or field == "count") then
		local key = (field == "hard") and "H" or "A"
		if (data.totals[key] > 1) then
			element:SetText(string.format("%d / %d", data.earned[key], data.totals[key]))
			SetRatioColor(element, value)
		else
			element:SetText("")
		end
	end
end

local function SetFieldTexture( control, name, texture, value )
	local element = control:GetNamedChild(name)
	element:SetTexture(RCR.GetTexture(texture))
	SetRatioColor(element, value)
end

local function PopulateStats( control, data )
	SetFieldText(control, "Clear", "clear", data)
	SetFieldText(control, "HardText", "hard", data)
	SetFieldTexture(control, "HardIcon", "ach-hm", data.hard)
	SetFieldTexture(control, "SpeedIcon", "ach-sr", data.speed)
	SetFieldTexture(control, "VitIcon", "ach-nd", data.vit)
	SetFieldTexture(control, "TriIcon", "ach-tri", data.tri)
	SetFieldText(control, "Count", "count", data)
end

local function SetClearState( state, flags )
	return zo_max(state, CheckFlag(flags, "V") and DUNGEON_DIFFICULTY_VETERAN or DUNGEON_DIFFICULTY_NORMAL)
end


--------------------------------------------------------------------------------
-- Completion Stats
--------------------------------------------------------------------------------

local Stats
Stats = {
	Reset = function( )
		Stats.seen = { }
		Stats.total = 0
		Stats.completed = 0
	end,

	Add = function( achs )
		for _, ach in ipairs(achs) do
			if (not Stats.seen[ach.id]) then
				Stats.seen[ach.id] = true
				Stats.total = Stats.total + 1
				if (IsAchComplete(ach.id)) then
					Stats.completed = Stats.completed + 1
				end
			end
		end
	end,

	Format = function( )
		return string.format(GetString(SI_RCR_COMPLETED_COUNT), Stats.completed, Stats.total, 100 * Stats.completed / Stats.total)
	end,
}


--------------------------------------------------------------------------------
-- RaidificatorAchievementsList
--------------------------------------------------------------------------------

RaidificatorAchievementsList = ExtendedJournalSortFilterList:Subclass()
local RaidificatorAchievementsList = RaidificatorAchievementsList

function RaidificatorAchievementsList:Setup( )
	ZO_ScrollList_AddDataType(self.list, DATA_TYPE, "RaidificatorAchievementRow", 30, function(...) self:SetupItemRow(...) end)
	ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")
	self:SetAlternateRowBackgrounds(true)

	local sortKeys = {
		["release"] = { isNumeric = true },
		["name"]    = { tiebreaker = "release", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["clear"]   = { isNumeric = true, tiebreaker = "release", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["hard"]    = { isNumeric = true, tiebreaker = "release", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["speed"]   = { isNumeric = true, tiebreaker = "release", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["vit"]     = { isNumeric = true, tiebreaker = "release", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["tri"]     = { isNumeric = true, tiebreaker = "release", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["count"]   = { isNumeric = true, tiebreaker = "release", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
	}

	self.currentSortKey = "release"
	self.currentSortOrder = ZO_SORT_ORDER_DOWN
	self.sortHeaderGroup:SelectAndResetSortForKey(self.currentSortKey)
	self.sortFunction = function( listEntry1, listEntry2 )
		return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sortKeys, self.currentSortOrder)
	end

	self.filterPledges = self.frame:GetNamedChild("FilterPledges")
	if (LUP) then
		if (RCR.vars.filterPledges) then
			ZO_CheckButton_SetChecked(self.filterPledges)
		else
			ZO_CheckButton_SetUnchecked(self.filterPledges)
		end
		ZO_CheckButton_SetLabelText(self.filterPledges, GetString(SI_RCR_FILTER_PLEDGES))
		ZO_CheckButton_SetToggleFunction(self.filterPledges, function( )
			RCR.vars.filterPledges = ZO_CheckButton_IsChecked(self.filterPledges)
			self:RefreshFilters()
		end)
	else
		self.filterPledges:SetHidden(true)
	end

	self.filterDrop = ZO_ComboBox_ObjectFromContainer(self.frame:GetNamedChild("FilterDrop"))
	self:InitializeComboBox(self.filterDrop, { prefix = "SI_RCR_ACHIEVEMENT_CATEGORY", max = (GetAPIVersion() >= 101051) and 4 or 3 }, RCR.vars.achCategoryId) -- TODO: temporary version check

	self.searchBox = self.frame:GetNamedChild("SearchFieldBox")
	self.searchBox:SetHandler("OnTextChanged", function() self:RefreshFilters() end)
	self.search = self:InitializeSearch(SORT_TYPE)

	self:InitializeDataSources()

	self:RefreshData()
end

function RaidificatorAchievementsList:BuildMasterList( )
	self.masterList = { }

	for idx, entry in ipairs(RCR.GetAchievementData()) do
		table.insert(self.masterList, {
			type = SORT_TYPE,
			release = idx,
			category = entry.category,
			year = entry.year,
			trophy = entry.trophy,
			zoneId = entry.zoneId,
			name = entry.name,
			achs = entry.achs,
			contentId = entry.contentId,
		})
	end

	self:RefreshAchievementState(true)
end

function RaidificatorAchievementsList:RefreshAchievementState( initial )
	if (not self.masterList) then return end

	for _, data in ipairs(self.masterList) do
		local totals = { A = 0, H = 0, S = 0, N = 0, T = 0 }
		local earned = { A = 0, H = 0, S = 0, N = 0, T = 0 }
		local clear = 0
		local clearMax = 0

		local ratio = function(k) return (totals[k] > 0) and (earned[k] / totals[k]) or -1 end

		for _, ach in ipairs(data.achs) do
			totals.A = totals.A + 1
			AddToTally(totals, ach.flags)
			if (CheckFlag(ach.flags, "C")) then
				clearMax = SetClearState(clearMax, ach.flags)
			end

			if (IsAchComplete(ach.id)) then
				earned.A = earned.A + 1
				AddToTally(earned, ach.flags)
				if (CheckFlag(ach.flags, "C")) then
					clear = SetClearState(clear, ach.flags)
				end
			end
		end

		data.clear = clear
		data.clearMax = clearMax
		data.hard = ratio("H")
		data.speed = ratio("S")
		data.vit = ratio("N")
		data.tri = ratio("T")
		data.count = ratio("A")
		data.totals = totals
		data.earned = earned
	end

	if (not initial) then
		self:RefreshFilters()
	end
end

function RaidificatorAchievementsList:FilterScrollList( )
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)

	Stats.Reset()

	local filterId = self.filterDrop:GetSelectedItemData().id
	RCR.vars.achCategoryId = filterId

	local searchInput = self.searchBox:GetText()

	if (LUP) then
		self.filterPledges:SetHidden(filterId ~= CATEGORY_DUNGEONS)
		AlwaysRefreshOnShow = filterId == CATEGORY_DUNGEONS and RCR.vars.filterPledges
	end

	for _, data in ipairs(self.masterList or { }) do
		if (filterId == data.category and (searchInput == "" or self.search:IsMatch(searchInput, data)) and self:CheckForPledge(data.zoneId)) then
			table.insert(scrollData, ZO_ScrollList_CreateDataEntry(DATA_TYPE, data))
			Stats.Add(data.achs)
		end
	end

	self.frame:GetNamedChild("CompletedCount"):SetText(Stats.Format())
	self.frame:GetNamedChild("Counter"):SetText(#scrollData)
end

function RaidificatorAchievementsList:SetupItemRow( control, data )
	local cell

	cell = control:GetNamedChild("Release")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(data.year)

	cell = control:GetNamedChild("Trophy")
	cell:SetTexture(GetCollectibleIcon(data.trophy))

	cell = control:GetNamedChild("Name")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(data.name)

	PopulateStats(control, data)

	self:SetupRow(control, data)
end

function RaidificatorAchievementsList:ProcessItemEntry( stringSearch, data, searchTerm, cache )
	if ( zo_plainstrfind(data.name:lower(), searchTerm) or
	     zo_plainstrfind(tostring(data.year), searchTerm) or
	     SearchAchievementNames(data.achs, searchTerm) ) then
		return true
	end

	return false
end

function RaidificatorAchievementsList:InitializeDataSources( )
	local server = LCCC.GetServerName()
	local userId = GetDisplayName()
	local accountLists = { [server] = { userId } }
	local servers = { server }

	self.server = server
	self.account = userId
	self.accountLists = accountLists

	if (LMAA) then
		for _, account in ipairs(LMAA.GetAccounts()) do
			if (account[1] ~= server or account[2] ~= userId) then
				if (not accountLists[account[1]]) then
					accountLists[account[1]] = { }
					table.insert(servers, account[1])
				end
				table.insert(accountLists[account[1]], account[2])
			end
		end

		GetAchTimestamp = function( achievementId )
			if (GetAchievementPersistenceLevel(achievementId) == ACHIEVEMENT_PERSISTENCE_CHARACTER) then
				local earliestTimestamp
				for _, character in ipairs(LMAA.GetCharacters(self.server, self.account)) do
					local timestamp = LMAA.GetAchievementTimestamp(character[1], achievementId)
					if (timestamp > 0 and (not earliestTimestamp or earliestTimestamp > timestamp)) then
						earliestTimestamp = timestamp
					end
				end
				return earliestTimestamp or 0
			else
				return LMAA.GetAchievementTimestamp({ self.server, self.account }, achievementId)
			end
		end

		IsAchComplete = function( achievementId )
			if (GetAchievementPersistenceLevel(achievementId) == ACHIEVEMENT_PERSISTENCE_CHARACTER) then
				for _, character in ipairs(LMAA.GetCharacters(self.server, self.account)) do
					if (LMAA.IsAchievementComplete(character[1], achievementId)) then
						return true
					end
				end
				return false
			else
				return LMAA.IsAchievementComplete({ self.server, self.account }, achievementId)
			end
		end

		GetAchCriterion = function(...) return LMAA.GetAchievementCriterion({ self.server, self.account }, ...) end
		GetAchLink = function(...) return LMAA.GetAchievementLink({ self.server, self.account }, ...) end
	end

	local control = self.frame:GetNamedChild("AccountDrop")
	control:GetNamedChild("Caption"):SetText(GetString(SI_LEJ_ACCOUNT))
	self.accountDrop = ZO_ComboBox_ObjectFromContainer(control)

	local control = self.frame:GetNamedChild("ServerDrop")
	control:GetNamedChild("Caption"):SetText(GetString(SI_LEJ_SERVER))
	self.serverDrop = ZO_ComboBox_ObjectFromContainer(control)
	self:InitializeComboBox(self.serverDrop, { list = servers }, nil, true, function( comboBox, entryText, entry, selectionChanged )
		self.server = entryText
		self:RefreshAccountList()
	end)

	if (RCR.ESOCB) then
		RCR.ESOCB.Initialize(CheckFlag, IsAchComplete, function() return self.server, self.account end)
	end
end

function RaidificatorAchievementsList:RefreshAccountList( )
	local accounts = self.accountLists[self.server]

	-- Try to keep the same account selected when changing servers
	local initialIndex
	for i, account in ipairs(accounts) do
		if (self.account == account) then
			initialIndex = i
		end
	end

	self:InitializeComboBox(self.accountDrop, { list = accounts }, initialIndex, true, function( comboBox, entryText, entry, selectionChanged )
		self.account = entryText
		self:RefreshAchievementState()
	end)
end

function RaidificatorAchievementsList:CheckForPledge( zoneId )
	if (LUP and RCR.vars.achCategoryId == CATEGORY_DUNGEONS and RCR.vars.filterPledges) then
		return LUP.IsPledge(zoneId, 0, self.server)
	else
		return true
	end
end


--------------------------------------------------------------------------------
-- Screenshot Mode
--------------------------------------------------------------------------------

local RaidificatorAchievementScreenshot = ZO_Object:Subclass()

function RaidificatorAchievementScreenshot:New( )
	local obj = ZO_Object.New(self)
	obj.window = RaidificatorAchievementScreenshotTopLevel
	obj.PADDING = 12
	obj.HEADER = 40
	obj.LINE = 2
	obj.WIDTH = 600
	obj.HEIGHT = 24
	obj.entries = { }
	obj.index = 1

	local initDivider = function( name )
		local control = obj.window:GetNamedChild(name)
		control:SetEdgeColor(0, 0, 0, 0)
		control:SetCenterColor(LCCC.Int32ToRGBA(COLOR_DIVIDER))
		return control
	end
	obj.divH = initDivider("DividerH")
	obj.divV = initDivider("DividerV")

	return obj
end

function RaidificatorAchievementScreenshot:GetNewEntry( )
	local entries = self.entries
	local index = self.index
	self.index = index + 1

	-- Create new entries lazily, only as needed
	while (index > #entries) do
		table.insert(entries, WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Entry" .. tostring(#entries + 1), self.window, "RaidificatorAchievementScreenshotEntry"))
	end

	return entries[index]
end

function RaidificatorAchievementScreenshot:Show( categoryId, server, account, summary )
	local window = self.window
	local entries = self.entries
	local count = self.index - 1

	local isWide = count > 0x20
	local getRow = function(r) return isWide and zo_ceil(r / 2) or r end

	self.categoryId = categoryId
	self.divV:SetHidden(not isWide)
	window:GetNamedChild("Title"):SetText(GetString("SI_RCR_ACHIEVEMENT_CATEGORY", categoryId))
	window:GetNamedChild("Server"):SetTexture(RCR.GetTexture(server))
	window:GetNamedChild("Account"):SetText(account)
	window:GetNamedChild("Summary"):SetText(summary)

	for i, entry in ipairs(entries) do
		if (i <= count) then
			if (i == 1) then
				entry:SetAnchor(TOPLEFT, self.divH, BOTTOMLEFT, 0, self.PADDING)
			elseif (isWide and i == 2) then
				entry:SetAnchor(TOPLEFT, entries[i - 1], TOPRIGHT, self.PADDING * 2 + self.LINE, 0)
			else
				entry:SetAnchor(TOPLEFT, entries[i - (isWide and 2 or 1)], BOTTOMLEFT)
			end
			entry:GetNamedChild("BG"):SetHidden(getRow(i) % 2 == 1)
		end
		entry:SetHidden(i > count)
	end

	window:SetDimensions(
		(self.WIDTH + self.PADDING * 2) * (isWide and 2 or 1) + (isWide and self.LINE or 0) + 4,
		self.HEIGHT * getRow(count) + self.PADDING * 4 + self.HEADER + self.LINE
	)

	if (RCR.ESOCB) then
		local control = window:GetNamedChild("Supplement")
		control:SetHidden(not RCR.ESOCB.DisplayQRCode(categoryId, control:GetNamedChild("QR")))
	end

	window:ClearAnchors()
	if (isWide) then
		window:SetAnchor(CENTER, GuiRoot, CENTER)
	else
		local frame = LEJ.GetFrame()
		window:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, frame:GetLeft() - 100, frame:GetTop())
	end
	window:SetHidden(false)
end

function RaidificatorAchievementScreenshot:Reset( )
	self.window:SetHidden(true)
	self.index = 1
end

function RaidificatorAchievementScreenshot:IsHidden( )
	return self.window:IsHidden()
end

local ScreenshotMode = nil

function RaidificatorAchievementsList:ScreenshotMode()
	if (not ScreenshotMode) then
		ScreenshotMode = RaidificatorAchievementScreenshot:New()
	end

	local categoryId = RCR.vars.achCategoryId
	local shouldShow = ScreenshotMode:IsHidden() or ScreenshotMode.categoryId ~= categoryId
	ScreenshotMode:Reset()
	if (not shouldShow) then return end

	Stats.Reset()

	for _, data in ipairs(self.masterList or { }) do
		if (categoryId == data.category) then
			local entry = ScreenshotMode:GetNewEntry()
			entry:GetNamedChild("Name"):SetText(data.name)
			PopulateStats(entry, data)
			Stats.Add(data.achs)
		end
	end

	ScreenshotMode:Show(categoryId, self.server, self.account, Stats.Format())
end

function RaidificatorAchievementScreenshotMode( )
	RCR.achList:ScreenshotMode()
end


--------------------------------------------------------------------------------
-- Achievement Info Popup
--------------------------------------------------------------------------------

local RaidificatorAchievementInfo = ZO_Object:Subclass()

function RaidificatorAchievementInfo:New( )
	local obj = ZO_Object.New(self)
	obj.window = RaidificatorAchievementInfoTopLevel
	obj.MAX_ROWS = 32
	obj.PADDING = 12
	obj.WIDTH = 640
	obj.HEIGHT = 20
	obj.rows = { }
	obj.index = 1
	return obj
end

function RaidificatorAchievementInfo:GetNewRow( )
	local rows = self.rows
	local index = self.index
	self.index = index + 1

	-- Create new rows lazily, only as needed
	while (index > #rows) do
		local row = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Row" .. tostring(#rows + 1), self.window, "RaidificatorAchievementInfoRow")
		if (#rows == 0) then
			row:SetAnchor(TOPLEFT, nil, nil, self.PADDING, self.PADDING)
		elseif (#rows % self.MAX_ROWS == 0) then
			row:SetAnchor(TOPLEFT, rows[#rows - self.MAX_ROWS + 1], TOPRIGHT, self.PADDING, 0)
		else
			row:SetAnchor(TOPLEFT, rows[#rows], BOTTOMLEFT)
		end
		row:GetNamedChild("BG"):SetHidden(#rows % 2 == 0)
		row.elements = {
			icon = row:GetNamedChild("Icon"),
			name = row:GetNamedChild("Name"),
			progress = row:GetNamedChild("Progress"),
			rewards = row:GetNamedChild("Rewards"),
		}
		table.insert(rows, row)
	end

	return rows[index].elements
end

function RaidificatorAchievementInfo:Show( )
	local window = self.window
	local count = self.index - 1

	for i, row in ipairs(self.rows) do
		row:SetHidden(i > count)
	end

	window:SetDimensions(
		(self.WIDTH + self.PADDING) * zo_ceil(count / self.MAX_ROWS) + self.PADDING + 4,
		self.HEIGHT * zo_min(count, self.MAX_ROWS) + self.PADDING * 2
	)
	window:ClearAnchors()
	window:SetAnchor(TOPRIGHT, LEJ.GetFrame(), TOPLEFT, -100, 0)
	window:SetHidden(false)
end

function RaidificatorAchievementInfo:Reset( )
	self.window:SetHidden(true)
	self.index = 1
end


--------------------------------------------------------------------------------
-- XML Handlers
--------------------------------------------------------------------------------

local Popup = RaidificatorAchievementInfo:New()

function RaidificatorAchievementRow_OnMouseEnter( control )
	local data = ZO_ScrollList_GetData(control)
	RCR.achList:Row_OnMouseEnter(control)

	local results = { }

	for _, ach in ipairs(data.achs) do
		local icon = RCR.GetTexture()
		if (CheckFlag(ach.flags, "H")) then
			icon = RCR.GetTexture("ach-hm")
		elseif (CheckFlag(ach.flags, "S")) then
			icon = RCR.GetTexture("ach-sr")
		elseif (CheckFlag(ach.flags, "N")) then
			icon = RCR.GetTexture("ach-nd")
		elseif (CheckFlag(ach.flags, "T")) then
			icon = RCR.GetTexture("ach-tri")
		elseif (CheckFlag(ach.flags, "V")) then
			icon = "/esoui/art/lfg/gamepad/gp_lfg_menuicon_veterandungeon.dds"
		end

		local rewards = { }
		if (GetAchievementRewardTitle(ach.id)) then
			table.insert(rewards, LocalizeString("<<1>>|cFFFFFF<<2>>|r", GetString(SI_ACHIEVEMENTS_TITLE), select(2, GetAchievementRewardTitle(ach.id))))
		end
		if (GetAchievementRewardCollectible(ach.id)) then
			local name, _, _, _, _, _, _, categoryType = GetCollectibleInfo(select(2, GetAchievementRewardCollectible(ach.id)))
			table.insert(rewards, LocalizeString("<<1>>|cFFFFFF<<t:2>>|r", LocalizeString(GetString(SI_ACHIEVEMENTS_COLLECTIBLE_CATEGORY), GetString("SI_COLLECTIBLECATEGORYTYPE", categoryType)), name))
		end
		if (GetAchievementRewardDye(ach.id)) then
			local name, _, _, _, _, r, g, b = GetDyeInfoById(select(2, GetAchievementRewardDye(ach.id)))
			table.insert(rewards, LocalizeString("<<1>>|c<<3>><<2>>|r", GetString(SI_ACHIEVEMENTS_DYE), name, string.format("%06X", LCCC.RGBToInt24(r, g, b))))
		end

		local time, completed, totalRequired = GetAchTimestamp(ach.id)
		if (time == 0) then
			completed, totalRequired = 0, 0
			for i = 1, GetAchievementNumCriteria(ach.id) do
				local _, numCompleted, numRequired = GetAchCriterion(ach.id, i)
				completed = completed + numCompleted
				totalRequired = totalRequired + numRequired
			end
			if (totalRequired > 0 and completed < totalRequired) then -- Sanity check
				time = completed / totalRequired
			end
		end

		table.insert(results, {
			name = GetAchName(ach.id),
			time = time,
			completed = completed,
			required = totalRequired,
			icon = icon,
			rewards = rewards,
		})
	end

	table.sort(results, function( a, b )
		if (a.time == b.time) then
			return a.name < b.name
		else
			return b.time < a.time
		end
	end)

	Popup:Reset()

	for i, result in ipairs(results) do
		local row = Popup:GetNewRow()
		row.icon:SetTexture(result.icon)
		row.name:SetText(result.name)
		if (result.time > 1) then
			row.name:SetColor(LEJ.GetTooltipColorUnpacked(2, 1))
			row.progress:SetText(RCR.FormatTimestamp(result.time))
			row.progress:SetColor(ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB())
		else
			row.name:SetColor(LEJ.GetTooltipColorUnpacked(2, 2))
			row.progress:SetText((result.required > 1) and string.format("%d / %d", result.completed, result.required) or "—")
			row.progress:SetColor(LEJ.GetTooltipColorUnpacked(2, 2))
		end
		row.rewards:SetText(table.concat(result.rewards, ", "))
	end

	Popup:Show()
end

function RaidificatorAchievementRow_OnMouseExit( control )
	RCR.achList:Row_OnMouseExit(control)

	Popup:Reset()
end

function RaidificatorAchievementRow_OnMouseUp( ... )
	RCR.achList:Row_OnMouseUp(...)
end
