local LCCC = LibCodesCommonCode
local LCK = LibCharacterKnowledge
local LEJ = LibExtendedJournal
local CharacterKnowledge = CharacterKnowledge


--------------------------------------------------------------------------------
-- Extended Journal
--------------------------------------------------------------------------------

local TAB_NAME = "CharacterKnowledge"
local FRAME = CharacterKnowledgeFrame
local DATA_TYPE = 1
local SORT_TYPE = 1

local Initialized = false
local Dirtiness = 0
local ContextMenuItems = { }

function CharacterKnowledge.InitializeBrowser( )
	LEJ.RegisterTab(TAB_NAME, {
		title = SI_CK_TITLE,
		order = 300,
		iconPrefix = "/esoui/art/journal/journal_tabicon_lorelibrary_",
		control = FRAME,
		settingsPanel = CharacterKnowledge.settingsPanel,
		binding = "CHARACTERKNOWLEDGE",
		slashCommands = { "/characterknowledge", "/ck" },
		callbackShow = function( )
			CharacterKnowledge.LazyInitializeBrowser()
			CharacterKnowledge.RefreshBrowser(true)
		end,
	})

	LCCC.RegisterLinkHandler("ckbrowser", function() LEJ.Show(TAB_NAME) end)
end

function CharacterKnowledge.LazyInitializeBrowser( )
	if (not Initialized and CharacterKnowledge.libReady) then
		Initialized = true
		CharacterKnowledge.list = CharacterKnowledgeList:New(FRAME, ContextMenuItems)
		LCK.RegisterForCallback(CharacterKnowledge.name, LCK.EVENT_UPDATE_REFRESH, function( eventCode, refreshCharacters )
			if (refreshCharacters) then
				Dirtiness = 2
			elseif (Dirtiness == 0) then
				Dirtiness = 1
			end
			CharacterKnowledge.RefreshBrowser()
		end)
	end
end

function CharacterKnowledge.RefreshBrowser( noActiveCheck, refreshResearch )
	if (Initialized and Dirtiness > 0 and (noActiveCheck or LEJ.IsTabActive(TAB_NAME))) then
		if (Dirtiness == 1) then
			CharacterKnowledge.list:RefreshKnowledge(false, true)
		else
			CharacterKnowledge.list:RefreshCharacterList()
		end
		Dirtiness = 0
	elseif (Initialized and refreshResearch and CharacterKnowledge.list.researchModeIsSelected) then
		CharacterKnowledge.list:ResearchRefresh()
	end
end


--------------------------------------------------------------------------------
-- Local Utilities
--------------------------------------------------------------------------------

local function GetAchievementCategoryName( achievementId )
	local name = GetAchievementSubCategoryInfo(GetCategoryInfoFromAchievementId(achievementId))
	return name
end

local SPECIAL_RECIPES = {
	{	-- Experience
		GetString(SI_LOOT_HISTORY_EXPERIENCE_GAIN),
		64223, 115029, 120077, 171324, 171331, 171435,
	},
	{	-- Wrothgar
		LCCC.GetZoneName(684),
		71060, 71061, 71062, 71063,
	},
	{	-- Witches Festival
		GetAchievementCategoryName(1546),
		87682, 87683, 87684, 87688, 87689, 87692, 87693, 87694, 87698, 153624, 153626, 153628,
	},
	{	-- New Life Festival
		GetAchievementCategoryName(1677),
		96960, 96961, 96962, 96963, 96964, 96965, 96966, 96967, 96968,
	},
	{	-- Jester's Festival
		GetAchievementCategoryName(1723),
		120767, 120768, 120769, 120770,
	},
	{	-- Clockwork City
		LCCC.GetZoneName(980),
		133551, 133552, 133553,
	},
	{	-- Artaeum
		LCCC.GetZoneName(1027),
		139012, 139017,
	},
	{	-- Night Market
		LCCC.GetZoneName(1559),
		224835,
	},
	{	-- Stonefalls
		LCCC.GetZoneName(41),
		225208,
	},
}

local QUEST_GRIMOIRES = { 2, 8 }

local QUEST_SCRIPTS = {
	5, 24, 64, -- The Second Era of Scribing
	18, 32, 44, 48, -- The Wing of the Indrik
}

local GUILD_SCRIPTS = {
	 1, 16, 20, -- Focus
	25, 34, 41, -- Signature
	50, 59, 60, -- Affix
}

local AUXILIARY_RESERVED = -1
local SCRIBING_ICON_GUILD = -2
local SCRIBING_ICON_QUEST = -3
local ICONS = {
	cp = "/esoui/art/champion/champion_icon_32.dds",
	crown = "/esoui/art/currency/crowns_mipmap.dds",
	[SCRIBING_ICON_GUILD] = "/esoui/art/icons/mapkey/mapkey_magesguild.dds",
	[SCRIBING_ICON_QUEST] = "/esoui/art/compass/quest_icon_assisted.dds",
}

local MAX_LEVEL = GetMaxLevel()

local function SetRatioColor( control, ratio )
	control.nonRecolorable = true
	control:SetColor(CharacterKnowledge.GetRatioColorUnpacked(ratio))
end

local function GetGrimoireFilter( text )
	local result = select(3, string.find(text, "^%s*grimoire:(%d+)%s*$"))
	return result and tonumber(result)
end


--------------------------------------------------------------------------------
-- Register Context Menu
--------------------------------------------------------------------------------

function CharacterKnowledge.RegisterContextMenuItem( func )
	table.insert(ContextMenuItems, func)
end

local function LinkToChat( itemId )
	return SI_ITEM_ACTION_LINK_TO_CHAT, function( )
		ZO_LinkHandler_InsertLink(LCK.GetItemLinkFromItemId(itemId, LINK_STYLE_BRACKETS))
	end
end

CharacterKnowledge.RegisterContextMenuItem(function( data )
	if (data.grimoireId) then
		return SI_CK_GRIMOIRE_FILTER, function( )
			local searchBox = CharacterKnowledge.list.searchBox
			searchBox:SetText(GetGrimoireFilter(searchBox:GetText()) and "" or string.format("grimoire:%d", data.grimoireId))
		end
	elseif (data.itemId) then
		return LinkToChat(data.itemId)
	end
end)

CharacterKnowledge.RegisterContextMenuItem(function( data )
	if (data.resultId) then
		return SI_CK_LINK_RESULT, function( )
			ZO_LinkHandler_InsertLink(LCK.GetItemLinkFromItemId(data.resultId, LINK_STYLE_BRACKETS))
		end
	elseif (data.grimoireId) then
		return LinkToChat(data.itemId)
	end
end)

CharacterKnowledge.RegisterContextMenuItem(function( data )
	if (data.bookIds) then
		local results = nil
		for chapterId = ITEM_STYLE_CHAPTER_MIN_VALUE, ITEM_STYLE_CHAPTER_MAX_VALUE do
			local bookId = data.bookIds[chapterId]
			if (bookId and LCK.IsBookIdKnownByCurrentCharacter(bookId)) then
				results = results or { }
				local title, icon = GetLoreBookInfo(GetLoreBookIndicesFromBookId(bookId))
				table.insert(results, {
					label = string.format("%s: %s", GetString(SI_LORE_LIBRARY_READ), zo_iconTextFormat(icon, "100%", "100%", title)),
					action = function() CharacterKnowledge.ReadBookId(bookId) end
				})
			end
		end
		return results
	end
end)

CharacterKnowledge.RegisterContextMenuItem(function( data )
	return "ID", data.styleId or data.grimoireId or data.scriptId or data.itemId
end)


--------------------------------------------------------------------------------
-- Auxiliary Column
-- GetAuxiliaryData( itemId, category )
-- GetAuxiliaryLabel( auxData )
--------------------------------------------------------------------------------

local GetAuxiliaryData, GetAuxiliaryLabel

function CharacterKnowledge.ConfigureAuxiliaryColumn( ... )
	GetAuxiliaryData, GetAuxiliaryLabel = ...
end


--------------------------------------------------------------------------------
-- CharacterKnowledgeList
--------------------------------------------------------------------------------

CharacterKnowledgeList = ExtendedJournalSortFilterList:Subclass()
local CharacterKnowledgeList = CharacterKnowledgeList

function CharacterKnowledgeList:Setup( )
	ZO_ScrollList_AddDataType(self.list, DATA_TYPE, "CharacterKnowledgeListRow", 30, function(...) self:SetupItemRow(...) end)
	ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")
	self:SetAlternateRowBackgrounds(true)

	self.masterList = { }

	local sortKeys = {
		["name"]       = { caseInsensitive = true },
		["auxiliary"]  = { isNumeric = true, tiebreaker = "extended", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["quality"]    = { isNumeric = true, tiebreaker = "extended", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["extended"]   = { caseInsensitive = true, tiebreaker = "name", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["ratioKnown"] = { isNumeric = true, tiebreaker = "extended", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["totalChars"] = { isNumeric = true, tiebreaker = "extended", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
		["ratioChars"] = { isNumeric = true, tiebreaker = "totalChars" },
	}

	self.currentSortKey = "extended"
	self.currentSortOrder = ZO_SORT_ORDER_UP
	self.sortHeaderGroup:SelectAndResetSortForKey(self.currentSortKey)
	self.sortFunction = function( listEntry1, listEntry2 )
		return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sortKeys, self.currentSortOrder)
	end

	self.singleAccount = self.frame:GetNamedChild("SingleAccount")
	if (CharacterKnowledge.vars.singleAccount) then
		ZO_CheckButton_SetChecked(self.singleAccount)
	else
		ZO_CheckButton_SetUnchecked(self.singleAccount)
	end
	ZO_CheckButton_SetLabelText(self.singleAccount, GetString(SI_CK_SINGLE_ACCOUNT))
	ZO_CheckButton_SetToggleFunction(self.singleAccount, function( )
		CharacterKnowledge.vars.singleAccount = ZO_CheckButton_IsChecked(self.singleAccount)
		self:RefreshKnowledge(false, true)
	end)

	self.filterDrop = ZO_ComboBox_ObjectFromContainer(self.frame:GetNamedChild("FilterDrop"))
	self:InitializeComboBox(self.filterDrop, { list = self:ResearchInitializeAndGetCategoryList() }, CharacterKnowledge.vars.filterId)

	self.searchBox = self.frame:GetNamedChild("SearchFieldBox")
	self.searchBox:SetHandler("OnTextChanged", function() self:RefreshFilters() end)
	self.search = self:InitializeSearch(SORT_TYPE)

	local control = self.frame:GetNamedChild("ServerDrop")
	control:GetNamedChild("Caption"):SetText(GetString(SI_LEJ_SERVER))
	self.serverDrop = ZO_ComboBox_ObjectFromContainer(control)
	self:InitializeComboBox(self.serverDrop, { list = LCK.GetFilteredServerList() }, nil, nil, function() self:RefreshCharacterList() end)

	local control = self.frame:GetNamedChild("CharacterDrop")
	control:GetNamedChild("Caption"):SetText(GetString(SI_LEJ_CHARACTER))
	self.characterDrop = ZO_ComboBox_ObjectFromContainer(control)
	self:RefreshCharacterList(true)

	self.headers = self.frame:GetNamedChild("Headers")

	self:UpdateState()
end

function CharacterKnowledgeList:UpdateState( )
	self.filterId = self.filterDrop:GetSelectedItemData().id
	CharacterKnowledge.vars.filterId = self.filterId
	if (self:ResearchToggleState()) then
		-- Already handled
	elseif (#self.masterList == 0) then
		self:RefreshData()
	else
		self:RefreshFilters()
	end
end

function CharacterKnowledgeList:BuildMasterList( )
	ZO_ClearTable(self.masterList)

	--------
	-- Motifs
	--------

	for _, styleId in ipairs(LCK.GetMotifStyles()) do
		if (GetItemStyleMaterialLink(styleId) ~= "") then
			local items = LCK.GetMotifItemsFromStyle(styleId)

			table.insert(self.masterList, {
				type = SORT_TYPE,
				category = LCK.ITEM_CATEGORY_MOTIF,
				styleId = styleId,
				itemId = items.books[1],
				name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemStyleName(styleId)),
				motifNumber = items.number,
				motifCrown = items.crown,
				extended = string.format("%03d", items.number),
				quality = LCK.GetMotifStyleQuality(styleId),
				chapters = (#items.chapters > 0) and items.chapters or nil,
				auxiliary = AUXILIARY_RESERVED, -- Unused
				bookIds = items.bookIds,
			})
		end
	end

	--------
	-- Recipes and plans
	--------

	-- Sourcing information for special recipes
	local special = { }
	for _, group in ipairs(SPECIAL_RECIPES) do
		local label
		for i, id in ipairs(group) do
			if (i == 1) then
				label = id
			else
				special[id] = label
			end
		end
	end

	-- Blueprints, Praxis, etc.
	local planTypes = { }
	for i = 1, CRAFTING_TYPE_MAX_VALUE do
		planTypes[i] = zo_strformat("<<z:1>>", GetString("SI_RECIPECRAFTINGSYSTEM", GetTradeskillRecipeCraftingSystem(i)))
	end

	local unique = { }
	for _, category in ipairs({ LCK.ITEM_CATEGORY_RECIPE, LCK.ITEM_CATEGORY_PLAN }) do
		for _, itemId in ipairs(LCK.GetItemIdsForCategory(category)) do
			local itemLink = LCK.GetItemLinkFromItemId(itemId)
			local resultLink = GetItemLinkRecipeResultItemLink(itemLink)
			local resultId = GetItemLinkItemId(resultLink)

			if (resultId > 0 and not unique[resultId]) then
				unique[resultId] = true

				local extended, level, planType
				if (category == LCK.ITEM_CATEGORY_RECIPE) then
					extended = special[itemId]
					if (not extended) then
						level = GetItemLinkRequiredLevel(resultLink)
						if (level == MAX_LEVEL) then
							level = level + GetItemLinkRequiredChampionPoints(resultLink)
						end
						extended = string.format("%03d", level)
					end
				else
					extended = GetFurnitureCategoryName(select(2, GetFurnitureDataCategoryInfo(GetItemLinkFurnitureDataId(resultLink))))
					planType = planTypes[GetItemLinkRecipeCraftingSkillType(itemLink)]
				end

				table.insert(self.masterList, {
					type = SORT_TYPE,
					category = category,
					itemId = itemId,
					resultId = resultId,
					name = LCK.GetItemName(resultLink),
					extended = extended,
					planType = planType,
					level = level,
					quality = GetItemLinkFunctionalQuality(itemLink),
					auxiliary = GetAuxiliaryData and GetAuxiliaryData(itemId, category) or AUXILIARY_RESERVED,
				})
			end
		end
	end

	--------
	-- Scribing
	--------

	local types = { }
	for i = 0, 3 do
		local name = (i == 0) and GetString(SI_SCRIBING_CRAFTED_ABILITY_SLOT_NAME) or GetString("SI_SCRIBINGSLOT_SHORT", i)
		types[i] = { name, string.format("%d:%s", i, name) }
	end

	local scribingIcons = { }
	for _, id in ipairs(QUEST_GRIMOIRES) do
		scribingIcons[id] = SCRIBING_ICON_QUEST
	end

	for id = 1, LCK.GetMaxCraftedAbilityId() do
		local itemId = LCK.GetItemForCraftedAbility(id)
		if (itemId > 0) then
			table.insert(self.masterList, {
				type = SORT_TYPE,
				category = LCK.ITEM_CATEGORY_SCRIBING,
				itemId = itemId,
				grimoireId = id,
				name = zo_strformat(SI_CRAFTED_ABILITY_NAME_FORMATTER, GetCraftedAbilityDisplayName(id)),
				extendedText = types[SCRIBING_SLOT_NONE][1],
				extended = types[SCRIBING_SLOT_NONE][2],
				auxiliary = scribingIcons[id] or AUXILIARY_RESERVED,
				quality = 0, -- Unused
			})
		end
	end

	ZO_ClearTable(scribingIcons)
	for _, id in ipairs(QUEST_SCRIPTS) do
		scribingIcons[id] = SCRIBING_ICON_QUEST
	end
	for _, id in ipairs(GUILD_SCRIPTS) do
		scribingIcons[id] = SCRIBING_ICON_GUILD
	end

	for id = 1, LCK.GetMaxCraftedAbilityScriptId() do
		local itemId = LCK.GetItemForCraftedAbilityScript(id)
		local slot = GetCraftedAbilityScriptScribingSlot(id)
		if (itemId > 0 and slot ~= SCRIBING_SLOT_NONE) then
			table.insert(self.masterList, {
				type = SORT_TYPE,
				category = LCK.ITEM_CATEGORY_SCRIBING,
				itemId = itemId,
				scriptId = id,
				name = zo_strformat(SI_CRAFTED_ABILITY_SCRIPT_NAME_FORMATTER, GetCraftedAbilityScriptDisplayName(id)),
				extendedText = types[slot][1],
				extended = types[slot][2],
				auxiliary = scribingIcons[id] or AUXILIARY_RESERVED,
				quality = 0, -- Unused
			})
		end
	end

	self:RefreshKnowledge(true)
end

function CharacterKnowledgeList:RefreshKnowledge( initial, invalidateCharColumn )
	if (invalidateCharColumn) then
		self.charColumnValid = false
	end

	for _, data in ipairs(self.masterList) do
		if (data.chapters) then
			data.known = 0
			for _, itemId in ipairs(data.chapters) do
				if (LCK.GetItemKnowledgeForCharacter(itemId, self.server, self.charId) == LCK.KNOWLEDGE_KNOWN) then
					data.known = data.known + 1
				end
			end
			data.ratioKnown = data.known / #data.chapters
		else
			data.ratioKnown = (LCK.GetItemKnowledgeForCharacter(data.itemId, self.server, self.charId) == LCK.KNOWLEDGE_KNOWN) and 1 or 0
		end
	end

	self:RefreshCharactersColumn()

	if (not initial) then
		self:UpdateState()
	end
end

function CharacterKnowledgeList:RefreshCharactersColumn( )
	if (self.charColumnValid or self.charColumnScanning or #self.masterList == 0) then return end
	self.charColumnScanning = true

	-- The characters column update is expensive and needs to happen asynchronously
	local identifier = CharacterKnowledge.name .. "Async"
	local blockSize = 1000
	local startIndex = 1

	EVENT_MANAGER:RegisterForUpdate(identifier, 0, function( )
		local stopIndex = startIndex + blockSize
		for i = startIndex, stopIndex - 1 do
			local data = self.masterList[i]
			data.totalChars = 0
			data.knownChars = 0
			for _, character in ipairs(LCK.GetItemKnowledgeList(data.itemId or { styleId = data.styleId }, self.server, nil, CharacterKnowledge.vars.singleAccount and self.account or nil)) do
				data.totalChars = data.totalChars + 1
				if (character.knowledge == LCK.KNOWLEDGE_KNOWN) then
					data.knownChars = data.knownChars + 1
				end
			end
			data.ratioChars = (data.totalChars > 0) and data.knownChars / data.totalChars or 1

			if (i >= #self.masterList) then
				EVENT_MANAGER:UnregisterForUpdate(identifier)
				self.charColumnValid = true
				self.charColumnScanning = false
				if (not self.researchModeIsSelected) then
					self:RefreshFilters()
				end
				return
			end
		end
		startIndex = stopIndex
	end)
end

function CharacterKnowledgeList:RefreshCharacterList( initial )
	-- Always invalidate the character column when the character list is changed
	self.charColumnValid = false

	self.server = self.serverDrop:GetSelectedItemData().name

	local accounts = 0
	local accountSeen = { }
	local characters = { }
	local initialIndex = 0

	for i, character in ipairs(LCK.GetCharacterList(self.server)) do
		table.insert(characters, { character.name, { character.id, character.account } })
		if (character.id == CharacterKnowledge.charId) then
			initialIndex = i
		end
		if (not accountSeen[character.account]) then
			accountSeen[character.account] = true
			accounts = accounts + 1
		end
	end

	if (initialIndex == 0) then
		if (self.serverDrop:GetSelectedItemData().id == 1) then
			-- Manually add the current character, if they are not in the character list (i.e., disabled in LCK)
			table.insert(characters, { GetUnitName("player"), { CharacterKnowledge.charId, CharacterKnowledge.userId } })
			initialIndex = #characters
			if (not accountSeen[CharacterKnowledge.userId]) then
				accounts = accounts + 1
			end
		elseif (#characters == 0) then
			-- Fall back to the current server, which should never be empty
			return self.serverDrop:SelectItemByIndex(1)
		else
			initialIndex = 1
		end
	end

	self.singleAccount:SetHidden(accounts <= 1)

	if (initial) then
		self.charId, self.account = unpack(characters[initialIndex][2])
	end

	self:InitializeComboBox(self.characterDrop, { list = characters, key = 1, dataKey = 2 }, initialIndex, not initial, function( comboBox, entryText, entry, selectionChanged )
		local prevAccount = self.account
		self.charId, self.account = unpack(entry.data)
		self:RefreshKnowledge(false, CharacterKnowledge.vars.singleAccount and prevAccount ~= self.account)
	end)
end

function CharacterKnowledgeList:UpdateStatusBarKnownCount( known, total )
	self.frame:GetNamedChild("CollectedCount"):SetText((total > 0) and string.format(GetString(SI_CK_KNOWN_COUNT), known, total, 100 * known / total) or "")
end

function CharacterKnowledgeList:FilterScrollList( )
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)

	local filterId = self.filterId

	if (filterId == LCK.ITEM_CATEGORY_SCRIBING) then
		self.headers:GetNamedChild("Quality"):SetHidden(true)
		self.headers:GetNamedChild("Auxiliary"):SetHidden(false)
	elseif (GetAuxiliaryLabel and (filterId == LCK.ITEM_CATEGORY_RECIPE or filterId == LCK.ITEM_CATEGORY_PLAN)) then
		self.headers:GetNamedChild("Quality"):SetHidden(false)
		self.headers:GetNamedChild("Auxiliary"):SetHidden(false)
	else
		self.headers:GetNamedChild("Quality"):SetHidden(false)
		self.headers:GetNamedChild("Auxiliary"):SetHidden(true)
	end

	local searchInput = self.searchBox:GetText()

	local collected = 0

	for _, data in ipairs(self.masterList) do
		if ( (filterId == data.category) and
		     (searchInput == "" or self.search:IsMatch(searchInput, data)) ) then
			table.insert(scrollData, ZO_ScrollList_CreateDataEntry(DATA_TYPE, data))
			if (data.ratioKnown == 1) then
				collected = collected + 1
			end
		end
	end

	self:UpdateStatusBarKnownCount(collected, #scrollData)
end

function CharacterKnowledgeList:SetupItemRow( control, data )
	local cell, cell2, cell3

	cell = control:GetNamedChild("Name")
	cell2 = control:GetNamedChild("Icon")
	cell.normalColor = ZO_DEFAULT_TEXT
	if (data.resultId) then
		local itemLink = LCK.GetItemLinkFromItemId(data.resultId)
		cell:SetText(itemLink)
		cell2:SetTexture(GetItemLinkIcon(itemLink))
	elseif (data.styleId) then
		local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, data.quality)
		cell:SetText(string.format("|c%02X%02X%02X%s|r", r * 255, g * 255, b * 255, data.name))
		cell2:SetTexture(GetItemLinkIcon(GetItemStyleMaterialLink(data.styleId)))
	elseif (data.grimoireId) then
		cell:SetText(data.name)
		cell2:SetTexture(GetCraftedAbilityIcon(data.grimoireId))
	elseif (data.scriptId) then
		cell:SetText(data.name)
		cell2:SetTexture(GetCraftedAbilityScriptIcon(data.scriptId))
	end

	cell = control:GetNamedChild("AuxIcon")
	cell2 = control:GetNamedChild("AuxLabel")
	cell2.normalColor = ZO_DEFAULT_TEXT
	if (data.auxiliary < AUXILIARY_RESERVED) then
		cell:SetTexture(ICONS[data.auxiliary])
		cell:SetHidden(false)
		cell2:SetHidden(true)
	elseif (data.auxiliary > AUXILIARY_RESERVED and GetAuxiliaryLabel) then
		cell:SetHidden(true)
		cell2:SetText(GetAuxiliaryLabel(data.auxiliary))
		cell2:SetHidden(false)
	else
		cell:SetHidden(true)
		cell2:SetHidden(true)
	end

	cell = control:GetNamedChild("Extended")
	cell2 = control:GetNamedChild("ExtNumber")
	cell3 = control:GetNamedChild("ExtIcon")
	cell.normalColor = ZO_DEFAULT_TEXT
	cell2.normalColor = ZO_DEFAULT_TEXT
	if (data.level) then
		cell:SetText("")
		cell2:SetHidden(false)
		if (data.level > MAX_LEVEL) then
			cell2:SetText(data.level - MAX_LEVEL)
			cell3:SetTexture(ICONS.cp)
			cell3:SetHidden(false)
		else
			cell2:SetText(data.level)
			cell3:SetHidden(true)
		end
	elseif (data.motifNumber) then
		cell:SetText("")
		cell2:SetText(data.motifNumber)
		cell2:SetHidden(false)
		if (data.motifCrown) then
			cell3:SetTexture(ICONS.crown)
			cell3:SetHidden(false)
		else
			cell3:SetHidden(true)
		end
	else
		cell:SetText(data.extendedText or data.extended)
		cell2:SetHidden(true)
		cell3:SetHidden(true)
	end

	cell = control:GetNamedChild("Known")
	SetRatioColor(cell, data.ratioKnown)
	if (data.ratioKnown == 1) then
		cell:SetText(GetString(SI_YES))
	elseif (data.ratioKnown == 0) then
		cell:SetText(GetString(SI_NO))
	else
		cell:SetText(string.format("%d / %d", data.known, #data.chapters))
	end

	cell = control:GetNamedChild("Characters")
	if (self.charColumnValid) then
		SetRatioColor(cell, data.ratioChars)
		cell:SetText(string.format("%d / %d", data.knownChars, data.totalChars))
	else
		cell:SetText("")
	end

	self:SetupRow(control, data)
end

function CharacterKnowledgeList:ProcessItemEntry( stringSearch, data, searchTerm, cache )
	if (searchTerm == "+") then
		return data.ratioKnown == 1
	elseif (searchTerm == "-") then
		return data.ratioKnown < 1
	end

	local grimoireId = GetGrimoireFilter(searchTerm)
	if (grimoireId) then
		return data.category ~= LCK.ITEM_CATEGORY_SCRIBING or data.grimoireId == grimoireId or (data.scriptId and IsCraftedAbilityScriptCompatibleWithSelections(data.scriptId, grimoireId))
	end

	if ( zo_plainstrfind(data.name:lower(), searchTerm) or
	     (not data.level and zo_plainstrfind(data.extended:lower(), searchTerm)) or
	     (data.planType and zo_plainstrfind(data.planType, searchTerm)) ) then
		return true
	end

	return false
end


--------------------------------------------------------------------------------
-- XML Handlers
--------------------------------------------------------------------------------

local PrimaryTooltip = ItemTooltip
local SecondaryTooltip = ItemTooltip

local function InitSecondaryTooltip( )
	InitializeTooltip(SecondaryTooltip, PrimaryTooltip, TOPRIGHT, 0, 0, TOPLEFT)
	return SecondaryTooltip
end

function CharacterKnowledgeListRow_OnMouseEnter( control )
	local data = ZO_ScrollList_GetData(control)
	local list = CharacterKnowledge.list
	list:Row_OnMouseEnter(control)

	-- Passing false for account signals that BoP should be ignored, since this is a browser invocation
	local account = CharacterKnowledge.vars.singleAccount and list.account or false

	if (LCK.GetItemCategory(data.itemId) ~= LCK.ITEM_CATEGORY_NONE) then
		local itemLink = LCK.GetItemLinkFromItemId(data.itemId)
		PrimaryTooltip = LEJ.ItemTooltip(itemLink)
		CharacterKnowledge.AddTooltipExtension(PrimaryTooltip, itemLink, list.server, account, list.charId, data.scriptId or 0, GetGrimoireFilter(CharacterKnowledge.list.searchBox:GetText()))
		if (data.resultId) then
			InitSecondaryTooltip():SetLink(LCK.GetItemLinkFromItemId(data.resultId))
		elseif (data.styleId) then
			InitSecondaryTooltip():SetLink(GetItemStyleMaterialLink(data.styleId))
		elseif (data.grimoireId) then
			ZO_ItemTooltip_UpdateVisualStyle(SecondaryTooltip)
			InitSecondaryTooltip():SetCraftedAbility(data.grimoireId)
		end
	elseif (data.styleId) then
		local itemLink = GetItemStyleMaterialLink(data.styleId)
		PrimaryTooltip = LEJ.ItemTooltip(itemLink)
		CharacterKnowledge.AddTooltipExtension(PrimaryTooltip, { styleId = data.styleId }, list.server, account, list.charId, 0)
	end
end

function CharacterKnowledgeListRow_OnMouseExit( control )
	CharacterKnowledge.list:Row_OnMouseExit(control)

	ClearTooltip(PrimaryTooltip)
	ClearTooltip(SecondaryTooltip)
end

function CharacterKnowledgeListRow_OnMouseUp( ... )
	CharacterKnowledge.list:Row_OnMouseUp(...)
end
