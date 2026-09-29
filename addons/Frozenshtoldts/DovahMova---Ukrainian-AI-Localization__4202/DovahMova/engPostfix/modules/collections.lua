-- =================================================================================================
-- Колекції сетів: англійські назви сетів і підземель, пошук сетів англійською.
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util

local Collections = {}
DovahMova.Collections = Collections

local STRING_OVERRIDE_VERSION = 10
local MAX_CATEGORY_LINE_BYTES = 40

--- Переносить довгу назву на кілька рядків по словах.
local function WrapText(text, maxLineBytes)
	if #text <= maxLineBytes then
		return text
	end
	local lines, currentLine = {}, ""
	for _, word in ipairs(Util.SplitWords(text)) do
		if currentLine ~= "" and #currentLine + 1 + #word > maxLineBytes then
			lines[#lines + 1] = currentLine
			currentLine = word
		else
			currentLine = currentLine == "" and word or (currentLine .. " " .. word)
		end
	end
	lines[#lines + 1] = currentLine
	return table.concat(lines, "\n")
end

local function HookSetNames()
	local sets = DovahMova.db.Sets
	local locations = DovahMova.db.Locations
	for _, itemSetCollection in pairs(ITEM_SET_COLLECTIONS_DATA_MANAGER.itemSetCollections) do
		local originalGetRawName = itemSetCollection.GetRawName
		itemSetCollection.GetRawName = function(...)
			local ukrainianName = originalGetRawName(...)
			local englishName = sets[itemSetCollection.itemSetId] or locations[Util.ToKey(ukrainianName)]
			return Util.FormatBilingual(ukrainianName, englishName, DovahMova.settings.ShowCollectionsSetsMenu)
		end
	end
end

local function HookCategoryNames()
	local dungeonNames = DovahMova.StaticData.DungeonNames
	local original = GetItemSetCollectionCategoryName
	GetItemSetCollectionCategoryName = function(categoryId)
		local ukrainianName = original(categoryId)
		local mode = DovahMova.settings.ShowLocations
		if not ukrainianName or mode == DovahMova.MODE_UA then
			return ukrainianName
		end
		local englishName = dungeonNames[Util.ToKey(ukrainianName)]
		if not englishName then
			return ukrainianName
		end
		return WrapText(Util.FormatBilingual(ukrainianName, englishName, mode), MAX_CATEGORY_LINE_BYTES)
	end
end

--- Пошук у колекціях сетів за англійською назвою.
local function HookEnglishSearch()
	local sets = DovahMova.db.Sets
	ZO_PreHook(TEXT_SEARCH_MANAGER, "OnBackgroundListFilterComplete", function(_, taskId)
		if not DovahMova.settings.EnglishSearch then
			return
		end
		local context, filterTarget = TEXT_SEARCH_MANAGER:GetInProgressTaskInfoById(taskId)
		if context ~= "itemSetTextSearch" or filterTarget ~= BACKGROUND_LIST_FILTER_TARGET_ITEM_SET_ID then
			return
		end
		local contextSearch = TEXT_SEARCH_MANAGER.contextSearches[context]
		local searchText = zo_strlower(contextSearch.searchText or "")
		if searchText == "" or not zo_strmatch(searchText, "[a-z]") then
			return
		end
		local results = contextSearch.searchResults[filterTarget] or {}
		contextSearch.searchResults[filterTarget] = results
		for itemSetId, englishName in pairs(sets) do
			if zo_plainstrfind(zo_strlower(englishName), searchText) then
				results[itemSetId] = true
			end
		end
	end)

	-- Адон Item Set Browser
	if ItemBrowserList then
		local originalProcessItemEntry = ItemBrowserList.ProcessItemEntry
		function ItemBrowserList:ProcessItemEntry(stringSearch, data, searchTerm, ...)
			local englishName = sets[data.setId]
			if englishName and zo_plainstrfind(zo_strlower(englishName), searchTerm) then
				return true
			end
			return originalProcessItemEntry(self, stringSearch, data, searchTerm, ...)
		end
	end
end

--- Назва сету в підказці «загального» сету (вкладка колекцій).
local function HookSetTooltip()
	local originalFormat = GetString(SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT)
	local originalSetGenericItemSet = ItemTooltip.SetGenericItemSet
	ItemTooltip.SetGenericItemSet = function(self, itemSetId, ...)
		local mode = DovahMova.settings.ShowItemsSetsTooltip
		local englishName = DovahMova.db.Sets[itemSetId]
		if mode ~= DovahMova.MODE_UA and englishName then
			local text = Util.FormatBilingual(GetItemSetName(itemSetId), englishName, mode)
			SafeAddString(SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT, ZO_CachedStrFormat(originalFormat, text), STRING_OVERRIDE_VERSION)
		end
		originalSetGenericItemSet(self, itemSetId, ...)
		SafeAddString(SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT, originalFormat, STRING_OVERRIDE_VERSION)
	end
end

local installed = false

function Collections.Install()
	if installed then
		return
	end
	installed = true
	HookSetNames()
	HookCategoryNames()
	HookEnglishSearch()
	HookSetTooltip()
	Collections.Refresh()
end

function Collections.Refresh()
	ITEM_SET_COLLECTIONS_DATA_MANAGER:SortTopLevelCategories()
	ITEM_SET_COLLECTIONS_DATA_MANAGER:FireCallbacks("CollectionsUpdated")
end
