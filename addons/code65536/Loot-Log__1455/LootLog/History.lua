local LCCC = LibCodesCommonCode
local LMAC = LibMultiAccountCollectibles
local LEJ = LibExtendedJournal
local LootLog = LootLog
local LootLogMulti = LootLog.modules.multi
local LootLogTrade = LootLog.modules.trade


--------------------------------------------------------------------------------
-- Extended Journal
--------------------------------------------------------------------------------

local TAB_NAME = "LootLogHistory"
local FRAME = LootLogListFrame
local DATA_TYPE = 1
local SORT_TYPE = 1

local Initialized = false
local Dirtiness = 0
local ContextMenuItems = { }

function LootLog.InitializeHistory( )
	local buttons = {
		{
			name = GetString(SI_LOOTLOG_CHATCOMMANDS),
			keybind = "UI_SHORTCUT_QUINARY",
			callback = LootLog.ChatCommandsReference,
		},
		{
			name = GetString(SI_LOOTLOG_LINKTRADE),
			keybind = "UI_SHORTCUT_SECONDARY",
			callback = LootLogTrade.LinkTrade,
		},
		{
			name = GetString(SI_LOOTLOG_BINDUNCOLLECTED),
			keybind = "UI_SHORTCUT_QUATERNARY",
			callback = LootLogTrade.BindUncollected,
		},
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
	}

	LEJ.RegisterTab(TAB_NAME, {
		title = SI_LOOTLOG_TITLE,
		subtitle = SI_LOOTLOG_SUBTITLE_LIST,
		order = 100,
		iconPrefix = "/esoui/art/vendor/vendor_tabicon_sell_",
		control = FRAME,
		settingsPanel = LootLog.settingsPanel,
		binding = "LOOTLOG",
		slashCommands = { "/lootlog", "/ll" },
		callbackShow = function( )
			LootLog.LazyInitializeHistory()
			LootLog.RefreshHistory(true)
			LootLog.SetRetentionText(FRAME:GetNamedChild("History"))
			FRAME:GetNamedChild("ChatCommands"):SetText((LootLog.vars.tradeCommandsCount < 4) and GetString(SI_LOOTLOG_CHATCOMMANDS_LINK) or "")
			KEYBIND_STRIP:AddKeybindButtonGroup(buttons)
		end,
		callbackHide = function( )
			KEYBIND_STRIP:RemoveKeybindButtonGroup(buttons)
		end,
	})

	LCCC.RegisterLinkHandler("lootlog", function() LEJ.Show(TAB_NAME) end)
end

function LootLog.LazyInitializeHistory( )
	if (not Initialized) then
		Initialized = true
		LootLog.list = LootLogList:New(FRAME, ContextMenuItems)
		table.insert(LootLog.refreshCallbacks, function( refreshLevel )
			if (Dirtiness < refreshLevel) then
				Dirtiness = refreshLevel
			end
			LootLog.RefreshHistory()
		end)
	end
end

function LootLog.RefreshHistory( noActiveCheck )
	if (Initialized and Dirtiness > 0 and (noActiveCheck or LEJ.IsTabActive(TAB_NAME))) then
		if (Dirtiness == 1) then
			LootLog.list:RefreshFilters()
		else
			LootLog.list:RefreshData()
		end
		Dirtiness = 0
	end
end


--------------------------------------------------------------------------------
-- Register Context Menu
--------------------------------------------------------------------------------

function LootLog.RegisterContextMenuItem( func )
	table.insert(ContextMenuItems, func)
end

LootLog.RegisterContextMenuItem(function( data )
	if (type(data.itemLink) == "string") then
		return SI_ITEM_ACTION_LINK_TO_CHAT, function( )
			ZO_LinkHandler_InsertLink(data.itemLink:gsub("^|H0", "|H1", 1))
		end
	end
end)

LootLog.RegisterContextMenuItem(function( data )
	return SI_CHAT_PLAYER_CONTEXT_WHISPER, function( )
		StartChatInput(nil, CHAT_CHANNEL_WHISPER, data.contact)
	end
end)


--------------------------------------------------------------------------------
-- LootLogList
--------------------------------------------------------------------------------

LootLogList = ExtendedJournalSortFilterList:Subclass()
local LootLogList = LootLogList

function LootLogList:Setup( )
	ZO_ScrollList_AddDataType(self.list, DATA_TYPE, "LootLogListRow", 30, function(...) self:SetupItemRow(...) end)
	ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")
	self:SetAlternateRowBackgrounds(true)

	self.masterList = { }
	self.scratch = {
		processed = { },
	}

	local sortKeys = {
		["time"]      = { isNumeric = true },
		["item"]      = { caseInsensitive = true, tiebreaker = "time", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
		["trait"]     = { caseInsensitive = true, tiebreaker = "time", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
		["recipient"] = { caseInsensitive = true, tiebreaker = "time", tieBreakerSortOrder = ZO_SORT_ORDER_DOWN },
	}

	self.currentSortKey = "time"
	self.currentSortOrder = ZO_SORT_ORDER_DOWN
	self.sortHeaderGroup:SelectAndResetSortForKey(self.currentSortKey)
	self.sortFunction = function( listEntry1, listEntry2 )
		return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sortKeys, self.currentSortOrder)
	end

	self.showUncollected = self.frame:GetNamedChild("ShowUncollected")
	if (LootLog.vars.historyShowUncollected) then
		ZO_CheckButton_SetChecked(self.showUncollected)
	else
		ZO_CheckButton_SetUnchecked(self.showUncollected)
	end
	ZO_CheckButton_SetLabelText(self.showUncollected, GetString(SI_LOOTLOG_SHOW_UNCOLLECTED))
	ZO_CheckButton_SetToggleFunction(self.showUncollected, function() self:RefreshFilters() end)

	self.filterDrop = ZO_ComboBox_ObjectFromContainer(self.frame:GetNamedChild("FilterDrop"))
	self:InitializeComboBox(self.filterDrop, { prefix = "SI_LOOTLOG_MODE", max = 6 }, LootLog.vars.historyMode)

	self.searchBox = self.frame:GetNamedChild("SearchFieldBox")
	self.searchBox:SetHandler("OnTextChanged", function() self:RefreshFilters() end)
	self.search = self:InitializeSearch(SORT_TYPE)

	self:RefreshData()
end

function LootLogList:BuildMasterList( )
	if (Dirtiness == 3) then
		self.masterList = { }
		self.scratch = {
			processed = { },
		}
	end

	for key, group in pairs(LootLog.history) do
		if (not self.scratch.processed[key]) then
			self.scratch.processed[key] = 0
		end
		for i = self.scratch.processed[key] + 1, #group do
			self.scratch.processed[key] = i
			local entry = LootLog.Unpack(group[i])

			local set = entry[6] % LootLog.flags.set == 0
			local setName = set and zo_strformat(" <<C:1>>", select(2, GetItemLinkSetInfo(entry[2]))) or ""

			table.insert(self.masterList, {
				type = SORT_TYPE,
				time = entry[1],
				itemLink = entry[2],
				item = LootLog.GetLinkName(entry[2]) .. setName,
				trait = LootLog.GetGearTraitName(entry[2]),
				count = entry[3],
				recipient = entry[4] and string.format("%s (%s)", entry[4], entry[5]) or entry[5],
				contact = entry[4] or entry[5],
				personal = entry[4] == LootLog.self.userId,
				notable = entry[6] % LootLog.flags.notable == 0,
				set = set,
			})
		end
	end
end

function LootLogList:FilterScrollList( )
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)

	LootLog.vars.historyShowUncollected = ZO_CheckButton_IsChecked(self.showUncollected)

	local filterId = self.filterDrop:GetSelectedItemData().id
	LootLog.vars.historyMode = filterId

	local searchInput = self.searchBox:GetText()

	for _, data in ipairs(self.masterList) do
		if ( (filterId == 1 and data.set and data.personal) or
		     (filterId == 2 and data.set) or
		     (filterId == 3 and data.notable and data.personal) or
		     (filterId == 4 and data.notable) or
		     (filterId == 5 and data.personal) or
		     (filterId == 6) ) then
			if (not LootLog.vars.historyShowUncollected or LootLogMulti.ShouldFlagAsUncollected(data.itemLink, LootLogMulti.CONTEXT_HISTORY_FILTER, nil, data.personal)) then
				if (searchInput == "" or self.search:IsMatch(searchInput, data)) then
					table.insert(scrollData, ZO_ScrollList_CreateDataEntry(DATA_TYPE, data))
				end
			end
		end
	end

	if (#scrollData ~= #self.masterList) then
		self.frame:GetNamedChild("Counter"):SetText(string.format("%d / %d", #scrollData, #self.masterList))
	else
		self.frame:GetNamedChild("Counter"):SetText(string.format("%d", #self.masterList))
	end
end

function LootLogList:SetupItemRow( control, data )
	local cell

	cell = control:GetNamedChild("Time")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(os.date("%H:%M:%S", data.time))

	local activeLabel, inactiveLabel = "Item", "ItemExtended"
	if (data.trait == "") then
		-- Extend into the space reserved for the trait, if there is no trait
		activeLabel = "ItemExtended"
		inactiveLabel = "Item"
	end

	cell = control:GetNamedChild(activeLabel)
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText((type(data.itemLink) == "string") and data.itemLink or LootLog.FormatAntiquityLead(data.itemLink, false))
	control:GetNamedChild(inactiveLabel):SetText("")
	control:GetNamedChild("Icon"):SetTexture(LootLog.GetLinkIcon(data.itemLink))

	cell = control:GetNamedChild("Indicator")
	local isUncollected, uncollectedColor, uncollectedIcon = LootLogMulti.ShouldFlagAsUncollected(data.itemLink, data.personal)
	if (isUncollected) then
		cell.nonRecolorable = true
		cell:SetTexture(uncollectedIcon)
		cell:SetColor(LCCC.Int24ToRGBA(uncollectedColor))
		cell:SetHidden(false)
	else
		cell:SetHidden(true)
	end

	cell = control:GetNamedChild("Count")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText((data.count > 1) and string.format("%d×", data.count) or "")

	cell = control:GetNamedChild("Trait")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(data.trait)

	cell = control:GetNamedChild("Recipient")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell:SetText(data.recipient)

	self:SetupRow(control, data)
end

function LootLogList:ProcessItemEntry( stringSearch, data, searchTerm, cache )
	if (searchTerm == "~") then
		if (LibServerResetTime) then
			return data.time >= LibServerResetTime.GetResetTimestamp(true)
		else
			local currentTime = GetGameTimeMilliseconds()
			if (currentTime - (self.lsrtPrev or 0) >= 60000) then
				self.lsrtPrev = currentTime
				LootLog.Msg(string.format("|cFF0000%s:|r %s", GetString(SI_PROMPT_TITLE_ERROR), zo_strformat(SI_ADDON_MANAGER_DEPENDENCY_MISSING, "LibServerResetTime")))
			end
			return true
		end
 	end

	if ( zo_plainstrfind(data.item:lower(), searchTerm) or
	     zo_plainstrfind(data.trait:lower(), searchTerm) or
	     zo_plainstrfind(data.recipient:lower(), searchTerm) ) then
		return true
	end

	return false
end


--------------------------------------------------------------------------------
-- XML Handlers
--------------------------------------------------------------------------------

local PrimaryTooltip = ItemTooltip
local SecondaryTooltip = ItemTooltip

local function AddTooltipExtension( module, ... )
	if (module and module.AddTooltipExtension) then
		module.AddTooltipExtension(PrimaryTooltip, ...)
	end
end

local function DisplayAntiquity( antiquityId, itemLink )
	PrimaryTooltip = LEJ.ItemTooltip(itemLink or { antiquityId = antiquityId })
	LootLog.AddAntiquityTooltipExtension(PrimaryTooltip, antiquityId)
	InitializeTooltip(SecondaryTooltip, PrimaryTooltip, TOPRIGHT, 0, 0, TOPLEFT)
	SecondaryTooltip:SetLink(LootLog.GetAntiquityRewardLink(antiquityId))
end

function LootLogListRow_OnMouseEnter( control )
	local data = ZO_ScrollList_GetData(control)
	LootLog.list:Row_OnMouseEnter(control)

	local itemLink = data.itemLink
	if (type(itemLink) == "number") then
		-- itemLink is actually antiquityId
		DisplayAntiquity(itemLink)
	elseif (IsItemLinkSetCollectionPiece(itemLink)) then
		PrimaryTooltip = LEJ.ItemTooltip(itemLink)
		AddTooltipExtension(ItemBrowser, itemLink, nil, 0x0F)
		AddTooltipExtension(CharacterKnowledge, itemLink)
	else
		local itemType = GetItemLinkItemType(itemLink)
		local collectibleId = GetItemLinkContainerCollectibleId(itemLink)
		local antiquityId = LootLog.GetAntiquityIdFromItem(itemLink)
		if (itemType == ITEMTYPE_RECIPE or itemType == ITEMTYPE_RACIAL_STYLE_MOTIF) then
			PrimaryTooltip = LEJ.ItemTooltip(itemLink)
			AddTooltipExtension(CharacterKnowledge, itemLink)
			if (itemType == ITEMTYPE_RECIPE) then
				InitializeTooltip(SecondaryTooltip, PrimaryTooltip, TOPRIGHT, 0, 0, TOPLEFT)
				SecondaryTooltip:SetLink(GetItemLinkRecipeResultItemLink(itemLink))
			end
		elseif (collectibleId > 0) then
			PrimaryTooltip = LEJ.ItemTooltip(itemLink)
			InitializeTooltip(SecondaryTooltip, PrimaryTooltip, TOPRIGHT, 0, 0, TOPLEFT)
			SecondaryTooltip:SetCollectible(collectibleId)
			AddTooltipExtension(LMAC, collectibleId)
		elseif (antiquityId > 0) then
			DisplayAntiquity(antiquityId, itemLink)
		else
			PrimaryTooltip = LEJ.ItemTooltip(itemLink, ItemTooltip)
		end
	end
end

function LootLogListRow_OnMouseExit( control )
	LootLog.list:Row_OnMouseExit(control)

	ClearTooltip(PrimaryTooltip)
	ClearTooltip(SecondaryTooltip)
end

function LootLogListRow_OnMouseUp( ... )
	LootLog.list:Row_OnMouseUp(...)
end
