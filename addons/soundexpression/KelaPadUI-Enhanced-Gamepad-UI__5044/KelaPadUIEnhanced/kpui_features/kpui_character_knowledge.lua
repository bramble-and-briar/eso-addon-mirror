-- KelaPadUI Character Knowledge: what each character knows of recipes,
-- furnishing plans, motifs, and scribing, from LibCharacterKnowledge (by
-- code65536, embedded in several add-ons), in the gamepad data browser
-- (kpui_core/kpui_gamepad_browser.lua): filters on the left, a sortable table
-- with item icons on the right, and the selected item's tooltip.
--
-- Only the library's public API is used: GetFilteredServerList,
-- GetCharacterList, GetItemIdsForCategory, GetItemLinkFromItemId,
-- GetItemKnowledgeForCharacter, ITEM_CATEGORIES, and its refresh callbacks.

-- Control prefix and scene name.
local SCENE_NAME = "KelaCharacterKnowledge"
local CALLBACK_NAME = "KelaPadUI_CharacterKnowledge"

local KNOWN_ALL, KNOWN_YES, KNOWN_NO = 1, 2, 3

-- Qualities offered by the Quality filter, after "All".
local QUALITIES =
{
	ITEM_DISPLAY_QUALITY_NORMAL,
	ITEM_DISPLAY_QUALITY_MAGIC,
	ITEM_DISPLAY_QUALITY_ARCANE,
	ITEM_DISPLAY_QUALITY_ARTIFACT,
	ITEM_DISPLAY_QUALITY_LEGENDARY,
}

-- The library's item categories in the order shown.
local function GetCategories()
	local LCK = LibCharacterKnowledge
	return { LCK.ITEM_CATEGORY_RECIPE, LCK.ITEM_CATEGORY_PLAN, LCK.ITEM_CATEGORY_MOTIF, LCK.ITEM_CATEGORY_SCRIBING }
end

function KelaIsCharacterKnowledgeAvailable()
	local LCK = LibCharacterKnowledge
	return LCK ~= nil
		and type(LCK.GetItemIdsForCategory) == "function"
		and type(LCK.GetItemKnowledgeForCharacter) == "function"
		and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FEATURES_CHARACTER_KNOWLEDGE)
end

-- ---------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------

-- Item ids per category. The library lists recipes, plans and motifs by
-- category; scribing items come from its grimoire and script tables.
local function GetItemIds(category)
	local LCK = LibCharacterKnowledge
	if category ~= LCK.ITEM_CATEGORY_SCRIBING then
		return LCK.GetItemIdsForCategory(category)
	end
	local ids = {}
	for abilityId = 1, LCK.GetMaxCraftedAbilityId() do
		local itemId = LCK.GetItemForCraftedAbility(abilityId)
		if itemId and itemId > 0 then
			ids[#ids + 1] = itemId
		end
	end
	for scriptId = 1, LCK.GetMaxCraftedAbilityScriptId() do
		local itemId = LCK.GetItemForCraftedAbilityScript(scriptId)
		if itemId and itemId > 0 then
			ids[#ids + 1] = itemId
		end
	end
	return ids
end

-- The item's own type ("Food Recipe", "Blacksmithing Diagram", "Grimoire"),
-- or the library's category name.
local function GetItemTypeText(link, categoryName)
	local itemType, specializedType = GetItemLinkItemType(link)
	if specializedType and specializedType ~= SPECIALIZED_ITEMTYPE_NONE then
		local text = GetString("SI_SPECIALIZEDITEMTYPE", specializedType)
		if text ~= "" then
			return text
		end
	end
	local text = itemType and GetString("SI_ITEMTYPE", itemType) or ""
	return text ~= "" and text or categoryName
end

local CHAMPION_ICON = "EsoUI/Art/Champion/champion_icon.dds"

-- A recipe's level is its result's level: "50", or the champion icon and
-- "150". Other items have none. The second value sorts champion levels after
-- level 50.
local function GetLevel(link)
	local resultLink = GetItemLinkRecipeResultItemLink(link)
	if not resultLink or resultLink == "" then
		return "", 0
	end
	local championPoints = GetItemLinkRequiredChampionPoints(resultLink)
	if championPoints and championPoints > 0 then
		return zo_iconFormat(CHAMPION_ICON, 24, 24) .. championPoints, 50 + championPoints
	end
	local level = GetItemLinkRequiredLevel(resultLink)
	if level and level > 0 then
		return tostring(level), level
	end
	return "", 0
end

-- Items per category, built once: link, name, icon, type, quality, level.
-- Knowledge is read per character when rows are built.
local itemsByCategory = {}

local function GetItems(category)
	local items = itemsByCategory[category]
	if not items then
		local LCK = LibCharacterKnowledge
		local categoryName = LCK.ITEM_CATEGORIES[category] or ""
		items = {}
		for _, itemId in ipairs(GetItemIds(category)) do
			local link = LCK.GetItemLinkFromItemId(itemId)
			local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))
			if name ~= "" then
				local quality = GetItemLinkDisplayQuality(link)
				local levelText, levelSort = GetLevel(link)
				items[#items + 1] =
				{
					itemId = itemId,
					link = link,
					name = name,
					lowerName = zo_strlower(name),
					icon = GetItemLinkIcon(link),
					quality = quality,
					qualityText = GetItemQualityColor(quality):Colorize(GetString("SI_ITEMDISPLAYQUALITY", quality)),
					typeName = GetItemTypeText(link, categoryName),
					levelText = levelText,
					level = levelSort,
				}
			end
		end
		-- The library returns no ids until it has loaded; ask again later.
		if #items > 0 then
			itemsByCategory[category] = items
		end
	end
	return items
end

-- How many of the server's characters know each item, cached per server until
-- the library rescans: { known, total }, counting characters with data.
local characterCounts = {}

local function GetCharacterCount(server, itemId)
	local byServer = characterCounts[server]
	if not byServer then
		byServer = {}
		characterCounts[server] = byServer
	end
	local count = byServer[itemId]
	if not count then
		local LCK = LibCharacterKnowledge
		local known, total = 0, 0
		for _, entry in ipairs(LCK.GetItemKnowledgeList(itemId, server)) do
			if LCK.IsKnowledgeUsable(entry.knowledge) then
				total = total + 1
				if entry.knowledge == LCK.KNOWLEDGE_KNOWN then
					known = known + 1
				end
			end
		end
		count = { known, total }
		byServer[itemId] = count
	end
	return count[1], count[2]
end

-- The source: filter state and the rows it produces.
local source =
{
	name = function() return GetString(KELA_MAINMENU_CHARACTER_KNOWLEDGE) end,
	search = "",
	typeIndex = 1,       -- 1 = all types, then GetCategories() order
	knownIndex = KNOWN_ALL,
	qualityIndex = 1,    -- 1 = all qualities, then QUALITIES order
}

local function GetServers()
	return LibCharacterKnowledge.GetFilteredServerList() or {}
end

local function GetCharacters()
	return source.server and LibCharacterKnowledge.GetCharacterList(source.server) or {}
end

-- The current server and character until the player picks others.
local function EnsureSelection()
	local servers = GetServers()
	local serverValid = false
	for _, server in ipairs(servers) do
		if server == source.server then
			serverValid = true
		end
	end
	if not serverValid then
		source.server = servers[1]
		source.charId = nil
	end
	local characters = GetCharacters()
	for _, character in ipairs(characters) do
		if character.id == source.charId then
			return
		end
	end
	source.charId = nil
	local currentId = GetCurrentCharacterId()
	for _, character in ipairs(characters) do
		if character.id == currentId then
			source.charId = currentId
		end
	end
	if not source.charId and characters[1] then
		source.charId = characters[1].id
	end
end

local function GetKnowledgeText(knowledge)
	local LCK = LibCharacterKnowledge
	if knowledge == LCK.KNOWLEDGE_KNOWN then
		return kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(GetString(SI_YES)), GetString(SI_YES)
	elseif knowledge == LCK.KNOWLEDGE_UNKNOWN then
		return kpuiConst.Colors.COLOR_LIGHT_RED:Colorize(GetString(SI_NO)), GetString(SI_NO)
	end
	return kpuiConst.Colors.COLOR_GREY:Colorize(GetString(KELA_CHARACTER_KNOWLEDGE_NODATA)), GetString(KELA_CHARACTER_KNOWLEDGE_NODATA)
end

function source:Activate()
	EnsureSelection()
end

function source:GetColumns()
	return
	{
		{ title = SI_ADDON_MANAGER_NAME, key = "name", width = 5 },
		{ title = KELA_CHARACTER_KNOWLEDGE_TYPE, key = "typeName", width = 2.6 },
		{ title = KELA_CHARACTER_KNOWLEDGE_QUALITY, key = "quality", width = 1.6 },
		{ title = KELA_CHARACTER_KNOWLEDGE_LEVEL, key = "level", width = 1.2 },
		{ title = KELA_CHARACTER_KNOWLEDGE_CHARACTERS, key = "characters", width = 1.5 },
		{ title = KELA_CHARACTER_KNOWLEDGE_KNOWN, key = "known", width = 1.2 },
	}
end

-- Rows for the selected server, character, type, knowledge and search.
function source:GetRows()
	local LCK = LibCharacterKnowledge
	local rows = {}
	if not (self.server and self.charId) then
		return rows
	end
	local categories = GetCategories()
	local wanted = self.typeIndex > 1 and { categories[self.typeIndex - 1] } or categories
	local needle = zo_strlower(self.search)
	local wantedQuality = self.qualityIndex > 1 and QUALITIES[self.qualityIndex - 1] or nil
	for _, category in ipairs(wanted) do
		for _, item in ipairs(GetItems(category)) do
			if (needle == "" or zo_plainstrfind(item.lowerName, needle))
				and (not wantedQuality or item.quality == wantedQuality) then
				local knowledge = LCK.GetItemKnowledgeForCharacter(item.itemId, self.server, self.charId)
				local keep = self.knownIndex == KNOWN_ALL
					or (self.knownIndex == KNOWN_YES and knowledge == LCK.KNOWLEDGE_KNOWN)
					or (self.knownIndex == KNOWN_NO and knowledge == LCK.KNOWLEDGE_UNKNOWN)
				if keep then
					local knownText, knownPlain = GetKnowledgeText(knowledge)
					local knownCount, totalCount = GetCharacterCount(self.server, item.itemId)
					rows[#rows + 1] =
					{
						item = item,
						name = item.name,
						typeName = item.typeName,
						quality = item.quality,
						level = item.level,
						-- Sorts by how many know it, then by how many have data.
						characters = knownCount * 1000 + totalCount,
						charactersText = string.format("%d / %d", knownCount, totalCount),
						known = knownPlain,
						knownText = knownText,
					}
				end
			end
		end
	end
	return rows
end

-- Sorted by name when the screen first opens.
function source:GetSortState()
	return "name", ZO_SORT_ORDER_UP
end

function source:GetCellTexts(row)
	local item = row.item
	return
	{
		GetItemQualityColor(item.quality):Colorize(item.name),
		item.typeName,
		item.qualityText,
		item.levelText,
		row.charactersText,
		row.knownText,
	}, item.icon
end

function source:GetTooltip(row)
	return "item", row.item.link
end

-- The filters in use, above the table.
function source:GetSummary()
	local characterName = ""
	for _, character in ipairs(GetCharacters()) do
		if character.id == self.charId then
			characterName = zo_strformat(SI_UNIT_NAME, character.name)
		end
	end
	local categories = GetCategories()
	local typeText = self.typeIndex > 1 and (LibCharacterKnowledge.ITEM_CATEGORIES[categories[self.typeIndex - 1]] or "")
		or GetString(KELA_ACHIEVEMENT_FILTER_ALL)
	-- The header has four places; a chosen quality joins the type.
	if self.qualityIndex > 1 then
		local quality = QUALITIES[self.qualityIndex - 1]
		typeText = typeText .. ", " .. GetItemQualityColor(quality):Colorize(GetString("SI_ITEMDISPLAYQUALITY", quality))
	end
	local knownLabels = { GetString(KELA_ACHIEVEMENT_FILTER_ALL), GetString(SI_YES), GetString(SI_NO) }
	return
	{
		{ GetString(KELA_CHARACTER_KNOWLEDGE_CHARACTER), characterName },
		{ GetString(KELA_CHARACTER_KNOWLEDGE_SERVER), self.server or "" },
		{ GetString(KELA_CHARACTER_KNOWLEDGE_TYPE), typeText },
		{ GetString(KELA_CHARACTER_KNOWLEDGE_KNOWN), knownLabels[self.knownIndex] or "" },
	}
end

-- ---------------------------------------------------------------------------
-- Filters
-- ---------------------------------------------------------------------------

local browser

local function Refresh()
	if browser then
		browser:RefreshSource(source)
	end
end

function source:GetFilters()
	local LCK = LibCharacterKnowledge
	return
	{
		{
			kind = "search",
			Get = function() return source.search end,
			Set = function(text)
				source.search = text or ""
				Refresh()
			end,
		},
		{
			kind = "choice",
			caption = GetString(KELA_CHARACTER_KNOWLEDGE_SERVER),
			GetChoices = function()
				return GetServers()
			end,
			GetSelected = function()
				for index, server in ipairs(GetServers()) do
					if server == source.server then
						return index
					end
				end
				return 1
			end,
			Select = function(index)
				local server = GetServers()[index]
				if server and server ~= source.server then
					source.server = server
					source.charId = nil
					EnsureSelection()
					Refresh()
				end
			end,
		},
		{
			kind = "choice",
			caption = GetString(KELA_CHARACTER_KNOWLEDGE_CHARACTER),
			GetChoices = function()
				local labels = {}
				for index, character in ipairs(GetCharacters()) do
					labels[index] = zo_strformat(SI_UNIT_NAME, character.name)
				end
				return labels
			end,
			GetSelected = function()
				for index, character in ipairs(GetCharacters()) do
					if character.id == source.charId then
						return index
					end
				end
				return 1
			end,
			Select = function(index)
				local character = GetCharacters()[index]
				if character and character.id ~= source.charId then
					source.charId = character.id
					Refresh()
				end
			end,
		},
		{
			kind = "choice",
			caption = GetString(KELA_CHARACTER_KNOWLEDGE_TYPE),
			GetChoices = function()
				local labels = { GetString(KELA_ACHIEVEMENT_FILTER_ALL) }
				for _, category in ipairs(GetCategories()) do
					labels[#labels + 1] = LCK.ITEM_CATEGORIES[category] or tostring(category)
				end
				return labels
			end,
			GetSelected = function() return source.typeIndex end,
			Select = function(index)
				if index ~= source.typeIndex then
					source.typeIndex = index
					Refresh()
				end
			end,
		},
		{
			kind = "choice",
			caption = GetString(KELA_CHARACTER_KNOWLEDGE_QUALITY),
			GetChoices = function()
				local labels = { GetString(KELA_ACHIEVEMENT_FILTER_ALL) }
				for _, quality in ipairs(QUALITIES) do
					labels[#labels + 1] = GetItemQualityColor(quality):Colorize(GetString("SI_ITEMDISPLAYQUALITY", quality))
				end
				return labels
			end,
			GetSelected = function() return source.qualityIndex end,
			Select = function(index)
				if index ~= source.qualityIndex then
					source.qualityIndex = index
					Refresh()
				end
			end,
		},
		{
			kind = "choice",
			caption = GetString(KELA_CHARACTER_KNOWLEDGE_KNOWN),
			GetChoices = function()
				return { GetString(KELA_ACHIEVEMENT_FILTER_ALL), GetString(SI_YES), GetString(SI_NO) }
			end,
			GetSelected = function() return source.knownIndex end,
			Select = function(index)
				if index ~= source.knownIndex then
					source.knownIndex = index
					Refresh()
				end
			end,
		},
	}
end

-- ---------------------------------------------------------------------------
-- Screen
-- ---------------------------------------------------------------------------

function KelaShowCharacterKnowledge()
	if not KelaIsCharacterKnowledgeAvailable() then
		return
	end
	if not browser then
		browser = KelaGamepadBrowser:New(SCENE_NAME)
		browser:SetSources({ source }, 1)
	end
	SCENE_MANAGER:Push(SCENE_NAME)
end

local setupDone = false

-- Refreshes the table when the library rescans a character (its data is
-- ready after the first load screen).
function KelaSetupCharacterKnowledge()
	local LCK = LibCharacterKnowledge
	if setupDone or not (LCK and type(LCK.RegisterForCallback) == "function") then
		return
	end
	setupDone = true
	local function OnLibraryUpdate()
		-- A rescan can change any character's knowledge.
		characterCounts = {}
		Refresh()
	end
	LCK.RegisterForCallback(CALLBACK_NAME, LCK.EVENT_INITIALIZED, OnLibraryUpdate)
	LCK.RegisterForCallback(CALLBACK_NAME, LCK.EVENT_UPDATE_REFRESH, OnLibraryUpdate)
end
