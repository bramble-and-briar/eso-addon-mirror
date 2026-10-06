local LCCC = LibCodesCommonCode
local LEJ = LibExtendedJournal
local RCR = Raidificator


--------------------------------------------------------------------------------
-- Extended Journal
--------------------------------------------------------------------------------

local TAB_NAME = "Raidificator"
local FRAME = RaidificatorFrame
local DATA_TYPE = 1
local SORT_TYPE = 1

local Initialized = false
local Dirtiness = 0
local ContextMenuItems = { }

function RCR.InitializeHistory( )
	LEJ.RegisterTab(TAB_NAME, {
		title = SI_RCR_TITLE,
		subtitle = SI_RCR_SUBTITLE_HISTORY,
		order = 510,
		iconPrefix = "/esoui/art/journal/journal_tabicon_leaderboard_",
		control = FRAME,
		settingsPanel = RCR.settingsPanel,
		binding = "RCR_HISTORY",
		slashCommands = { "/raidificator", "/rcr" },
		callbackShow = function( )
			RCR.LazyInitializeHistory()
			RCR.RefreshHistory(true)
		end,
	})

	LCCC.RegisterLinkHandler("rcr", function() LEJ.Show(TAB_NAME) end)
end

function RCR.LazyInitializeHistory( )
	if (not Initialized) then
		Initialized = true

		-- Refresh character names, in case any were renamed
		for i = 1, GetNumCharacters() do
			local name, _, _, classId, _, _, id = GetCharacterInfo(i)
			if (RCR.GetCharacterData(id)) then
				RCR.UpdateCharacterData(id, zo_strformat(SI_PLAYER_NAME, name), classId)
			end
		end

		RCR.InitializeNoteEditor()

		RCR.list = RaidificatorList:New(FRAME, ContextMenuItems)
	end
end

function RCR.RefreshHistory( noActiveCheck )
	if (Initialized and Dirtiness > 0 and (noActiveCheck or LEJ.IsTabActive(TAB_NAME))) then
		RCR.list:RefreshData()
		Dirtiness = 0 -- Redundant fail-safe; this should already be set to 0 by the refresh
	end
end

function RCR.NewClearAdded( contentId )
	RCR.vars.contentId = contentId
	if (Initialized) then
		Dirtiness = 1
		RCR.RefreshHistory()
	end
end


--------------------------------------------------------------------------------
-- Register Context Menu
--------------------------------------------------------------------------------

function RCR.RegisterContextMenuItem( func )
	table.insert(ContextMenuItems, func)
end

RCR.RegisterContextMenuItem(function( data )
	return SI_SOCIAL_MENU_EDIT_NOTE, function( )
		ZO_Dialogs_ShowDialog("RCR_EDIT_NOTE", data)
	end
end)

RCR.RegisterContextMenuItem(function( data )
	local raidId = RCR.GetRaidIdFromContentId(data.contentId)
	if (raidId and not RCR.IsTimestampFromSoulReservoirScoringSystem(data.timestamp)) then
		return {
			{ label = GetString(SI_RCR_DISPLAY_SCORE_BANNER), action = function() RCR.DisplayScoreBanner(raidId, data.score, data.duration, unpack(data.extraRaw)) end },
			{ label = string.format("%s (%s)", GetString(SI_RCR_DISPLAY_SCORE_BANNER), GetString(SI_SETTING_ENTER_SCREENSHOT_MODE)), action = function() RCR.DisplayScoreBannerForScreenshot(raidId, data.score, data.duration, unpack(data.extraRaw)) end },
		}
	end
end)

RCR.RegisterContextMenuItem(function( data )
	local raidId = RCR.GetRaidIdFromContentId(data.contentId)
	if (raidId and not RCR.IsTimestampFromSoulReservoirScoringSystem(data.timestamp)) then
		return SI_RCR_UNADJUSTED_SCORE, RCR.RemoveTimeAdjustmentFromScore(raidId, data.score, data.duration)
	end
end)


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetRoleIcon( role )
	role = tonumber(role)
	if (role == LFG_ROLE_TANK) then
		return "/esoui/art/lfg/lfg_icon_tank.dds"
	elseif (role == LFG_ROLE_HEAL) then
		return "/esoui/art/lfg/lfg_icon_healer.dds"
	else
		return "/esoui/art/lfg/lfg_icon_dps.dds"
	end
end

local function GetOrSetNote( data, note )
	local notes = RCR.history.notes
	local oldNote = notes[data.index] or ""
	if (not note) then
		return oldNote
	else
		note = string.match(note, "^%s*(.-)%s*$")
		if (oldNote ~= note) then
			notes[data.index] = (note ~= "") and note or nil
			RCR.list:RefreshFilters()
		end
		return note
	end
end

local function AppendTooltip( tooltip, text )
	local r, g, b = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB()
	tooltip:AddLine(text, nil, r, g, b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
end

function RCR.InitializeNoteEditor( )
	local control = ZO_EditNoteDialog
	ZO_Dialogs_RegisterCustomDialog("RCR_EDIT_NOTE", {
		customControl = control,
		setup = function( dialog, data )
			dialog:GetNamedChild("DisplayName"):SetText(string.format("%s\n%d   •   %s   •   %s", RCR.FormatTimestamp(data.timestamp), data.score, RCR.FormatTime(data.duration, 3), RCR.FormatExtra(unpack(data.extraRaw))))
			dialog:GetNamedChild("NoteEdit"):SetText(GetOrSetNote(data))
		end,
		title = { text = SI_EDIT_NOTE_DIALOG_TITLE },
		buttons = {
			{
				text = SI_SAVE,
				control = control:GetNamedChild("Save"),
				callback = function( dialog )
					GetOrSetNote(dialog.data, dialog:GetNamedChild("NoteEdit"):GetText())
				end,
			},
			{
				text = SI_DIALOG_CANCEL,
				control = control:GetNamedChild("Cancel"),
			},
		},
	})
end


--------------------------------------------------------------------------------
-- RaidificatorList
--------------------------------------------------------------------------------

RaidificatorList = ExtendedJournalSortFilterList:Subclass()
local RaidificatorList = RaidificatorList

function RaidificatorList:Setup( )
	ZO_ScrollList_AddDataType(self.list, DATA_TYPE, "RaidificatorListRow", 30, function(...) self:SetupItemRow(...) end)
	ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")
	self:SetAlternateRowBackgrounds(true)

	local sortKeys = {
		["server"]    = { tiebreaker = "timestamp", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
		["timestamp"] = { isNumeric = true },
		["character"] = { caseInsensitive = true, tiebreaker = "timestamp", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
		["score"]     = { sNumeric = true, tiebreaker = "timestamp", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
		["duration"]  = { sNumeric = true, tiebreaker = "timestamp", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
		["extra"]     = { tiebreaker = "timestamp", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
	}

	self.currentSortKey = "timestamp"
	self.currentSortOrder = ZO_SORT_ORDER_DOWN
	self.sortHeaderGroup:SelectAndResetSortForKey(self.currentSortKey)
	self.sortFunction = function( listEntry1, listEntry2 )
		return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sortKeys, self.currentSortOrder)
	end

	self.contentIdToIndex = { }
	local contentList = { }
	for _, content in ipairs(RCR.SCORED_CONTENT) do
		local name = LCCC.GetZoneName(content[2])
		if (name ~= "") then
			table.insert(contentList, { name, content[1] })
			self.contentIdToIndex[content[1]] = #contentList
		end
	end

	self.hideArc1 = self.frame:GetNamedChild("HideArc1")
	if (RCR.vars.hideArc1) then
		ZO_CheckButton_SetChecked(self.hideArc1)
	else
		ZO_CheckButton_SetUnchecked(self.hideArc1)
	end
	ZO_CheckButton_SetLabelText(self.hideArc1, GetString(SI_RCR_FILTER_HIDE_ARC_1))
	ZO_CheckButton_SetToggleFunction(self.hideArc1, function( )
		RCR.vars.hideArc1 = ZO_CheckButton_IsChecked(self.hideArc1)
		self:RefreshFilters()
	end)

	self.filterDrop = ZO_ComboBox_ObjectFromContainer(self.frame:GetNamedChild("FilterDrop"))
	self:InitializeComboBox(self.filterDrop, { list = contentList, key = 1, dataKey = 2 }, self.contentIdToIndex[RCR.vars.contentId])

	self.accounts = { }
	self.accountsInitialized = false
	local control = self.frame:GetNamedChild("AccountDrop")
	control:GetNamedChild("Caption"):SetText(GetString(SI_LEJ_ACCOUNT))
	self.accountDrop = ZO_ComboBox_ObjectFromContainer(control)

	self:RefreshData()
end

function RaidificatorList:BuildMasterList( )
	self.masterList = { }

	for index, entry in pairs(RCR.history.clears) do
		local contentId, server, timestamp, character, score, duration, extra, group = zo_strsplit(",", entry)
		local userId, charName, classId = RCR.GetCharacterData(character)
		if (charName) then
			extra = { zo_strsplit(";", extra) }
			if (#extra == 3 and group and group ~= "") then
				-- Legacy data: Set to duo is there were others in the group
				extra[4] = ENDLESS_DUNGEON_GROUP_TYPE_DUO
			end
			table.insert(self.masterList, {
				type = SORT_TYPE,
				index = index,
				contentId = contentId,
				server = server,
				timestamp = tonumber(timestamp),
				userId = userId,
				character = charName,
				classIndex = GetClassIndexById(classId),
				score = tonumber(score),
				duration = tonumber(duration),
				extra = string.format((#extra < 3) and "%02d%02d" or "%03d%d%d", unpack(extra)), -- The text here is used only for the sort algorithm and is padded with leading zeros for that
				extraRaw = extra,
				group = group,
			})
			if (not self.accountsInitialized) then
				self.accounts[userId] = true
			end
		end
	end

	if (not self.accountsInitialized) then
		self.accountsInitialized = true
		self:InitializeAccounts()
	end
end

function RaidificatorList:FilterScrollList( )
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)

	if (Dirtiness > 0) then
		-- New clear added to history
		LEJ.SelectComboBoxItemByIndex(self.filterDrop, self.contentIdToIndex[RCR.vars.contentId], true)
		Dirtiness = 0
	else
		RCR.vars.contentId = self.filterDrop:GetSelectedItemData().data
	end

	local notIA = RCR.vars.contentId ~= "1E"
	self.hideArc1:SetHidden(notIA)

	local selectedAccount = self.accountDrop:GetSelectedItemData()
	local userId = selectedAccount.name
	local accountIndex = selectedAccount.id
	RCR.vars.allAccounts = accountIndex == 1

	for _, data in ipairs(self.masterList or { }) do
		if (RCR.vars.contentId == data.contentId and (accountIndex == 1 or userId == data.userId) and (notIA or not RCR.vars.hideArc1 or data.extra > "00211")) then
			table.insert(scrollData, ZO_ScrollList_CreateDataEntry(DATA_TYPE, data))
		end
	end

	self.frame:GetNamedChild("Counter"):SetText(string.format("%d", #scrollData))
end

function RaidificatorList:SetupItemRow( control, data )
	local cell

	cell = control:GetNamedChild("Server")
	cell:SetTexture(RCR.GetTexture(data.server))

	cell = control:GetNamedChild("Timestamp")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(RCR.FormatTimestamp(data.timestamp))

	cell = control:GetNamedChild("Class")
	cell:SetTexture(data.classIndex and select(8, GetClassInfo(data.classIndex)) or RCR.GetTexture())

	cell = control:GetNamedChild("Character")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(data.character)

	cell = control:GetNamedChild("Note")
	if (GetOrSetNote(data) ~= "") then
		cell:SetTexture(RCR.GetTexture("note"))
		cell:SetHidden(false)
	else
		cell:SetHidden(true)
	end

	cell = control:GetNamedChild("Score")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(data.score)

	cell = control:GetNamedChild("Duration")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(RCR.FormatTime(data.duration, 2))

	cell = control:GetNamedChild("Extra")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(RCR.FormatExtra(unpack(data.extraRaw)))

	cell = control:GetNamedChild("ExtraIcon")
	cell:SetTexture((#data.extraRaw < 3) and "/esoui/art/trials/vitalitydepletion.dds" or "/esoui/art/endlessdungeon/thick_outline_icon_progression_arc.dds")

	cell = control:GetNamedChild("ExtraIconOverlay")
	if (#data.extraRaw > 3) then
		local groupType = RCR.ENDLESS_TYPES[tonumber(data.extraRaw[4])]
		if (groupType) then
			cell:SetTexture(RCR.GetTexture(groupType[1]))
			cell:SetColor(LCCC.Int24ToRGBA(groupType[2]))
		end
		cell.nonRecolorable = true
		cell:SetHidden(false)
	else
		cell:SetHidden(true)
	end

	local extendedCharInfo = { zo_strsplit(":", zo_strsplit(";", data.group)) }
	if (not (extendedCharInfo[1] and extendedCharInfo[4] and string.match(extendedCharInfo[1], "^~%d$"))) then
		-- Old format, so ignore it
		extendedCharInfo = nil
	end
	for i = 1, 3 do
		local skillLineId = extendedCharInfo and tonumber(extendedCharInfo[i + 1])
		cell = control:GetNamedChild("SkillLine" .. i)
		if (skillLineId) then
			cell:SetTexture(GetCollectibleIcon(GetSkillLineMasteryCollectibleId(skillLineId)))
			cell:SetHidden(false)
		else
			cell:SetHidden(true)
		end
	end

	self:SetupRow(control, data)
end

function RaidificatorList:InitializeAccounts( )
	local userId = GetDisplayName()
	self.accounts[userId] = true
	local accountNames = LCCC.GetSortedKeys(self.accounts, userId)
	table.insert(accountNames, 1, GetString(SI_RCR_ALL_ACCOUNTS))
	self:InitializeComboBox(self.accountDrop, { list = accountNames }, RCR.vars.allAccounts and 1 or 2)
end


--------------------------------------------------------------------------------
-- XML Handlers
--------------------------------------------------------------------------------

local Tooltip = ExtendedJournalTextTooltip

function RaidificatorListRow_OnMouseEnter( control )
	local data = ZO_ScrollList_GetData(control)
	RCR.list:Row_OnMouseEnter(control)

	local roster = { }
	local note = GetOrSetNote(data)

	if (data.group and data.group ~= "") then
		local iconSize = 22
		local atSize = control:GetNamedChild("Character"):GetStringWidth("@") / GetUIGlobalScale()

		for _, member in ipairs({ zo_strsplit(";", data.group) }) do
			local charName, userId, classId, role = zo_strsplit(":", member)
			local classSkillLineIds = nil

			-- Special handling for the self entry
			local role2 = string.match(charName, "^~(%d)$")
			if (role2) then
				classSkillLineIds = { tonumber(userId), tonumber(classId), tonumber(role) }
				charName = data.character
				userId = data.userId
				classId = GetClassInfo(data.classIndex)
				role = role2
			end

			if (role) then
				table.insert(roster, zo_iconFormat(GetRoleIcon(role), iconSize, iconSize) .. zo_iconTextFormat(select(8, GetClassInfo(GetClassIndexById(classId))), iconSize, iconSize, DecorateDisplayName(userId)))
				table.insert(roster, zo_iconTextFormat(RCR.GetTexture(), iconSize + iconSize + atSize, iconSize, charName))
				if (classSkillLineIds) then
					for _, skillLineId in ipairs(classSkillLineIds) do
						table.insert(roster, zo_iconTextFormat(RCR.GetTexture(), iconSize + iconSize + atSize, iconSize, zo_iconTextFormat(GetCollectibleIcon(GetSkillLineMasteryCollectibleId(skillLineId)), iconSize, iconSize, RCR.GetClassSkillLineFormattedName(skillLineId))))
					end
				end
			elseif (classId) then
				table.insert(roster, zo_iconTextFormat(select(8, GetClassInfo(GetClassIndexById(classId))), iconSize, iconSize, DecorateDisplayName(userId)))
				table.insert(roster, zo_iconTextFormat(RCR.GetTexture(), iconSize + atSize, iconSize, charName))
			else
				table.insert(roster, charName)
			end
		end
	end

	local hasRoster = #roster > 0
	local hasNote = note ~= ""

	if (hasRoster or hasNote) then
		Tooltip = LEJ.InitializeTooltip(Tooltip)
	end

	if (hasRoster) then
		Tooltip:AddLine(GetString(SI_RCR_GROUP_MEMBERS), "ZoFontWinH2")
		AppendTooltip(Tooltip, table.concat(roster, "\n"))
	end

	if (hasNote) then
		if (hasRoster) then
			Tooltip:AddLine("")
			ZO_Tooltip_AddDivider(Tooltip)
			Tooltip:AddLine("")
		end
		Tooltip:AddLine(GetString(SI_GAMEPAD_CONTACTS_NOTES_TITLE), "ZoFontWinH2")
		AppendTooltip(Tooltip, note)
	end
end

function RaidificatorListRow_OnMouseExit( control )
	RCR.list:Row_OnMouseExit(control)

	ClearTooltip(Tooltip)
end

function RaidificatorListRow_OnMouseUp( ... )
	RCR.list:Row_OnMouseUp(...)
end
