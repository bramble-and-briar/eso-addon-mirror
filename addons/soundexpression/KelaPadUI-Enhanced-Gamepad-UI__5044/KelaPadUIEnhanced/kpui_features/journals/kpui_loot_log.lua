-- KelaPadUI Loot Log: the items you and your group looted, from Loot Log (by
-- code65536), in the gamepad data browser (kpui_core/kpui_gamepad_browser.lua).
-- Two pages, switched with L1/R1:
--
--   * Loot History: every logged item, with filters for who looted it, the
--     item category and quality, set, notable and uncollected items, and how
--     recent it is;
--   * Materials: the crafting materials you looted and how many you own.
--
-- Loot Log has no data API, so this reads the add-on's own tables: the history
-- (`LootLog.history`, hour buckets of packed entries, unpacked with
-- `LootLog.Unpack`), the flag values and the current account (`LootLog.flags`,
-- `LootLog.self`). Everything else comes from the game: item names, icons,
-- set and trait info, and collection status. Loot Log calls the functions in
-- `LootLog.refreshCallbacks` when the history or collections change.

local SCENE_NAME = "KelaLootLog"

local CATEGORY_GEAR = 1
local CATEGORY_MATERIAL = 2
local CATEGORY_RECIPE = 3
local CATEGORY_COLLECTIBLE = 4
local CATEGORY_ANTIQUITY = 5
local CATEGORY_OTHER = 6

local COLLECTION_NONE, COLLECTION_UNCOLLECTED, COLLECTION_COLLECTED = 0, 1, 2

local LOOTED_BY_ME, LOOTED_BY_OTHERS = "me", "others"
local STOCK_IN, STOCK_OUT = "in", "out"

local SECONDS_PER_MINUTE = 60

local QUALITIES =
{
	ITEM_DISPLAY_QUALITY_NORMAL,
	ITEM_DISPLAY_QUALITY_MAGIC,
	ITEM_DISPLAY_QUALITY_ARCANE,
	ITEM_DISPLAY_QUALITY_ARTIFACT,
	ITEM_DISPLAY_QUALITY_LEGENDARY,
}

function KelaIsLootLogAvailable()
	return type(LootLog) == "table"
		and type(LootLog.history) == "table"
		and type(LootLog.Unpack) == "function"
		and type(LootLog.flags) == "table"
		and type(LootLog.self) == "table"
		and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FEATURES_LOOT_LOG)
end

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

-- What an item link looks like, read once per link. A history entry is an item
-- link, a collectible link, or the id (a number) of an antiquity lead.
local itemInfoByLink = {}

local function GetItemInfo(link)
	local info = itemInfoByLink[link]
	if info then
		return info
	end
	info = { trait = "", setName = "", typeName = "" }
	if type(link) == "number" then
		info.antiquityId = link
		info.name = zo_strformat(SI_ANTIQUITY_LEAD_NAME_FORMATTER, GetAntiquityName(link))
		info.icon = GetAntiquityLeadIcon()
		local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ANTIQUITY_QUALITY_COLORS, GetAntiquityQuality(link))
		info.color = ZO_ColorDef:New(r, g, b)
		info.category = CATEGORY_ANTIQUITY
	elseif GetLinkType(link) == LINK_TYPE_COLLECTIBLE then
		local collectibleId = GetCollectibleIdFromLink(link)
		info.collectibleId = collectibleId
		info.name = collectibleId and zo_strformat(SI_TOOLTIP_ITEM_NAME, GetCollectibleName(collectibleId)) or ""
		info.icon = collectibleId and GetCollectibleIcon(collectibleId) or nil
		info.color = GetItemQualityColor(ITEM_DISPLAY_QUALITY_NORMAL)
		info.category = CATEGORY_COLLECTIBLE
	else
		local itemType = GetItemLinkItemType(link)
		info.name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))
		info.icon = GetItemLinkIcon(link)
		info.quality = GetItemLinkDisplayQuality(link)
		info.color = GetItemQualityColor(info.quality)
		info.typeName = GetString("SI_ITEMTYPE", itemType)
		if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR then
			info.category = CATEGORY_GEAR
			local traitType = GetItemLinkTraitType(link)
			if traitType ~= ITEM_TRAIT_TYPE_NONE then
				info.trait = GetString("SI_ITEMTRAITTYPE", traitType)
			end
		elseif itemType == ITEMTYPE_RECIPE or itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
			info.category = CATEGORY_RECIPE
		elseif GetItemLinkContainerCollectibleId(link) > 0 then
			info.category = CATEGORY_COLLECTIBLE
		elseif CanItemLinkBeVirtual(link) then
			info.category = CATEGORY_MATERIAL
		else
			info.category = CATEGORY_OTHER
		end
		local hasSet, setName = GetItemLinkSetInfo(link, false)
		if hasSet then
			info.setName = zo_strformat("<<C:1>>", setName)
		end
	end
	info.sortName = zo_strlower(info.name)
	itemInfoByLink[link] = info
	return info
end

-- Whether the account has the set piece or collectible an item gives. Not
-- cached: it changes as the player collects.
local function GetCollectionStatus(link)
	if type(link) ~= "string" then
		return COLLECTION_NONE
	end
	if IsItemLinkSetCollectionPiece(link) then
		return IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(link)) and COLLECTION_COLLECTED or COLLECTION_UNCOLLECTED
	end
	local collectibleId = GetItemLinkContainerCollectibleId(link)
	if collectibleId > 0 then
		if IsCollectibleOwnedByDefId(collectibleId) then
			return COLLECTION_COLLECTED
		end
		-- A combination fragment that can no longer be unlocked counts as done.
		if GetCollectibleCategoryType(collectibleId) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT
			and not CanCombinationFragmentBeUnlocked(collectibleId) then
			return COLLECTION_COLLECTED
		end
		return COLLECTION_UNCOLLECTED
	end
	return COLLECTION_NONE
end

local function GetCategoryOptions()
	return
	{
		{ label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ label = GetString(KELA_LOOTLOG_CATEGORY_GEAR), value = CATEGORY_GEAR },
		{ label = GetString(KELA_LOOTLOG_CATEGORY_MATERIAL), value = CATEGORY_MATERIAL },
		{ label = GetString(KELA_LOOTLOG_CATEGORY_RECIPE), value = CATEGORY_RECIPE },
		{ label = GetString(KELA_LOOTLOG_CATEGORY_COLLECTIBLE), value = CATEGORY_COLLECTIBLE },
		{ label = GetString(KELA_LOOTLOG_CATEGORY_ANTIQUITY), value = CATEGORY_ANTIQUITY },
		{ label = GetString(KELA_LOOTLOG_CATEGORY_OTHER), value = CATEGORY_OTHER },
	}
end

local function GetQualityOptions()
	local options = { { label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) } }
	for _, quality in ipairs(QUALITIES) do
		options[#options + 1] =
		{
			label = GetItemQualityColor(quality):Colorize(GetString("SI_ITEMDISPLAYQUALITY", quality)),
			value = quality,
		}
	end
	return options
end

local function GetLabel(options, value)
	for _, option in ipairs(options) do
		if option.value == value then
			return option.label
		end
	end
	return ""
end

-- The item as the player sees it in a table: coloured name, with its set.
local function GetItemText(info)
	local text = info.color:Colorize(info.name)
	if info.setName ~= "" then
		text = text .. " " .. kpuiConst.Colors.COLOR_GREY:Colorize(info.setName)
	end
	return text
end

local function GetItemTooltip(link, info)
	if info.antiquityId then
		return "antiquity", info.antiquityId
	elseif info.collectibleId then
		return "collectible", info.collectibleId
	end
	return "item", link
end

local function GetLinkActions(link)
	if type(link) ~= "string" then
		return {}
	end
	return
	{
		{
			label = GetString(SI_ITEM_ACTION_LINK_TO_CHAT),
			action = function()
				ZO_LinkHandler_InsertLink((link:gsub("^|H0", "|H1", 1)))
			end,
		},
	}
end

-- ---------------------------------------------------------------------------
-- Loot History
-- ---------------------------------------------------------------------------

local history =
{
	name = function() return GetString(KELA_LOOTLOG_HISTORY) end,
	search = "",
	records = {},
}

-- Every logged item as a record. Loot Log keeps a few hours, so rebuilding on
-- each refresh is cheap; the item lookups are cached.
local function BuildHistory()
	local records = {}
	local notableFlag, setFlag = LootLog.flags.notable, LootLog.flags.set
	local userId = LootLog.self.userId
	for _, group in pairs(LootLog.history) do
		for _, packed in ipairs(group) do
			local entry = LootLog.Unpack(packed)
			if type(entry) == "table" and entry[1] and entry[2] ~= nil then
				local link = entry[2]
				local info = GetItemInfo(link)
				local account, charName = entry[4], entry[5] or ""
				local personal = account == userId
				local recipient = personal and charName or (account and account ~= "@" and (charName .. " (" .. account .. ")")) or charName
				local flags = entry[6] or 1
				records[#records + 1] =
				{
					time = entry[1],
					link = link,
					info = info,
					count = entry[3] or 1,
					personal = personal,
					notable = flags % notableFlag == 0,
					isSet = flags % setFlag == 0,
					contact = (account and account ~= "@") and account or charName,
					recipient = recipient,
					recipientSort = zo_strlower(recipient),
					status = GetCollectionStatus(link),
					itemSort = info.sortName,
					traitSort = zo_strlower(info.trait),
					searchText = zo_strlower(table.concat({ info.name, info.setName, info.trait, recipient }, " ")),
				}
			end
		end
	end
	-- Newest first; the table re-sorts by the column the player picks.
	table.sort(records, function(a, b)
		return a.time > b.time
	end)
	return records
end

function history:Activate()
	self.records = BuildHistory()
end

history.iconColumn = 2

function history:GetColumns()
	return
	{
		{ title = KELA_LOOTLOG_TIME, key = "time", width = 2 },
		{ title = KELA_LOOTLOG_ITEM, key = "itemSort", width = 5 },
		{ title = KELA_LOOTLOG_QUANTITY, key = "count", width = 0.9, align = TEXT_ALIGN_RIGHT },
		{ title = KELA_LOOTLOG_TRAIT, key = "traitSort", width = 2 },
		{ title = KELA_LOOTLOG_LOOTED_BY, key = "recipientSort", width = 3.2 },
		{ title = KELA_LOOTLOG_COLLECTION, key = "status", width = 1.8 },
	}
end

function history:GetSortState()
	return "time", ZO_SORT_ORDER_DOWN
end

function history:GetRows()
	self.records = BuildHistory()
	local needle = zo_strlower(self.search)
	local cutoff = self.seconds and (GetTimeStamp() - self.seconds) or nil
	local rows = {}
	for _, record in ipairs(self.records) do
		if (needle == "" or zo_plainstrfind(record.searchText, needle))
			and (self.lootedBy == nil
				or (self.lootedBy == LOOTED_BY_ME and record.personal)
				or (self.lootedBy == LOOTED_BY_OTHERS and not record.personal))
			and (self.player == nil or record.contact == self.player)
			and (self.category == nil or record.info.category == self.category)
			and (self.quality == nil or record.info.quality == self.quality)
			and (cutoff == nil or record.time >= cutoff)
			and (not self.setOnly or record.isSet)
			and (not self.notableOnly or record.notable)
			and (not self.uncollectedOnly or record.status == COLLECTION_UNCOLLECTED) then
			rows[#rows + 1] = record
		end
	end
	return rows
end

local COLLECTION_TEXT =
{
	[COLLECTION_UNCOLLECTED] = function() return kpuiConst.Colors.COLOR_LIGHT_RED:Colorize(GetString(KELA_LOOTLOG_UNCOLLECTED)) end,
	[COLLECTION_COLLECTED] = function() return kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(GetString(KELA_LOOTLOG_COLLECTED)) end,
}

function history:GetCellTexts(record)
	local info = record.info
	local collection = COLLECTION_TEXT[record.status]
	return
	{
		os.date("%H:%M:%S", record.time),
		GetItemText(info),
		record.count > 1 and tostring(record.count) or "",
		info.trait,
		record.personal and ZO_SELECTED_TEXT:Colorize(record.recipient) or record.recipient,
		collection and collection() or "",
	}, info.icon
end

function history:GetTooltip(record)
	return GetItemTooltip(record.link, record.info)
end

function history:GetActions(record)
	return GetLinkActions(record.link)
end

local function GetLootedByOptions()
	return
	{
		{ label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ label = GetString(KELA_LOOTLOG_ME), value = LOOTED_BY_ME },
		{ label = GetString(KELA_LOOTLOG_OTHERS), value = LOOTED_BY_OTHERS },
	}
end

local function GetTimeOptions()
	return
	{
		{ label = GetString(KELA_LOOTLOG_ANY_TIME) },
		{ label = GetString(KELA_LOOTLOG_LAST_15_MINUTES), value = 15 * SECONDS_PER_MINUTE },
		{ label = GetString(KELA_LOOTLOG_LAST_30_MINUTES), value = 30 * SECONDS_PER_MINUTE },
		{ label = GetString(KELA_LOOTLOG_LAST_HOUR), value = 60 * SECONDS_PER_MINUTE },
	}
end

-- Everyone in the history, by name.
local function GetPlayerOptions()
	local options, seen = {}, {}
	for _, record in ipairs(history.records) do
		if not seen[record.contact] then
			seen[record.contact] = true
			options[#options + 1] = { label = record.recipient, value = record.contact, sort = record.recipientSort }
		end
	end
	table.sort(options, function(a, b)
		return a.sort < b.sort
	end)
	table.insert(options, 1, { label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) })
	return options
end

function history:GetFilters()
	local Filter = KelaGamepadBrowser
	return
	{
		Filter.SearchFilter(self, "search"),
		Filter.ChoiceFilter(self, "lootedBy", GetString(KELA_LOOTLOG_LOOTED_BY), GetLootedByOptions),
		Filter.ChoiceFilter(self, "player", GetString(KELA_LOOTLOG_PLAYER), GetPlayerOptions),
		Filter.ChoiceFilter(self, "category", GetString(KELA_LOOTLOG_CATEGORY), GetCategoryOptions),
		Filter.ChoiceFilter(self, "quality", GetString(KELA_BROWSER_QUALITY), GetQualityOptions),
		Filter.ChoiceFilter(self, "seconds", GetString(KELA_LOOTLOG_TIME_RANGE), GetTimeOptions),
		Filter.ToggleFilter(self, "setOnly", GetString(KELA_LOOTLOG_SET_ONLY)),
		Filter.ToggleFilter(self, "notableOnly", GetString(KELA_LOOTLOG_NOTABLE_ONLY)),
		Filter.ToggleFilter(self, "uncollectedOnly", GetString(KELA_LOOTLOG_UNCOLLECTED_ONLY)),
	}
end

function history:GetSummary()
	return
	{
		{ GetString(KELA_LOOTLOG_LOOTED_BY), GetLabel(GetLootedByOptions(), self.lootedBy) },
		{ GetString(KELA_LOOTLOG_CATEGORY), GetLabel(GetCategoryOptions(), self.category) },
		{ GetString(KELA_BROWSER_QUALITY), GetLabel(GetQualityOptions(), self.quality) },
		{ GetString(KELA_LOOTLOG_TIME_RANGE), GetLabel(GetTimeOptions(), self.seconds) },
	}
end

-- ---------------------------------------------------------------------------
-- Materials
-- ---------------------------------------------------------------------------

local materials =
{
	name = function() return GetString(KELA_LOOTLOG_MATERIALS) end,
	search = "",
	records = {},
	since = 0,
}

-- The materials you looted, one record per item with the amount looted and the
-- amount you own now (backpack, bank, and craft bag).
local function BuildMaterials()
	local byLink, records = {}, {}
	local userId = LootLog.self.userId
	local since = 0
	for _, group in pairs(LootLog.history) do
		for _, packed in ipairs(group) do
			local entry = LootLog.Unpack(packed)
			if type(entry) == "table" and entry[4] == userId and type(entry[2]) == "string" and CanItemLinkBeVirtual(entry[2]) then
				local record = byLink[entry[2]]
				if not record then
					local info = GetItemInfo(entry[2])
					record =
					{
						link = entry[2],
						info = info,
						count = 0,
						itemSort = info.sortName,
						typeSort = zo_strlower(info.typeName),
					}
					byLink[entry[2]] = record
					records[#records + 1] = record
				end
				record.count = record.count + (entry[3] or 1)
				if entry[1] and (since == 0 or entry[1] < since) then
					since = entry[1]
				end
			end
		end
	end
	for _, record in ipairs(records) do
		local backpack, bank, craftBag = GetItemLinkStacks(record.link)
		record.total = backpack + bank + craftBag
	end
	table.sort(records, function(a, b)
		return a.itemSort < b.itemSort
	end)
	return records, since
end

function materials:Activate()
	self.records, self.since = BuildMaterials()
end

function materials:GetColumns()
	return
	{
		{ title = KELA_LOOTLOG_ITEM, key = "itemSort", width = 5.5 },
		{ title = KELA_LOOTLOG_TYPE, key = "typeSort", width = 3 },
		{ title = KELA_LOOTLOG_LOOTED, key = "count", width = 1.5, align = TEXT_ALIGN_RIGHT },
		{ title = KELA_LOOTLOG_OWNED, key = "total", width = 1.5, align = TEXT_ALIGN_RIGHT },
	}
end

function materials:GetSortState()
	return "itemSort", ZO_SORT_ORDER_UP
end

function materials:GetRows()
	self.records, self.since = BuildMaterials()
	local needle = zo_strlower(self.search)
	local rows = {}
	for _, record in ipairs(self.records) do
		if (needle == "" or zo_plainstrfind(record.itemSort, needle) or zo_plainstrfind(record.typeSort, needle))
			and (self.typeName == nil or record.info.typeName == self.typeName)
			and (self.quality == nil or record.info.quality == self.quality)
			and (self.stock == nil or (self.stock == STOCK_IN and record.total > 0) or (self.stock == STOCK_OUT and record.total == 0)) then
			rows[#rows + 1] = record
		end
	end
	return rows
end

function materials:GetCellTexts(record)
	local info = record.info
	local owned = tostring(record.total)
	if record.total == 0 then
		owned = kpuiConst.Colors.COLOR_GREY:Colorize(owned)
	end
	return { info.color:Colorize(info.name), info.typeName, tostring(record.count), owned }, info.icon
end

function materials:GetTooltip(record)
	return "item", record.link
end

function materials:GetActions(record)
	return GetLinkActions(record.link)
end

-- The item types present, by name.
local function GetTypeOptions()
	local options, seen = {}, {}
	for _, record in ipairs(materials.records) do
		local typeName = record.info.typeName
		if typeName ~= "" and not seen[typeName] then
			seen[typeName] = true
			options[#options + 1] = { label = typeName, value = typeName }
		end
	end
	table.sort(options, function(a, b)
		return a.label < b.label
	end)
	table.insert(options, 1, { label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) })
	return options
end

local function GetStockOptions()
	return
	{
		{ label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ label = GetString(KELA_LOOTLOG_IN_STOCK), value = STOCK_IN },
		{ label = GetString(KELA_LOOTLOG_OUT_OF_STOCK), value = STOCK_OUT },
	}
end

function materials:GetFilters()
	local Filter = KelaGamepadBrowser
	return
	{
		Filter.SearchFilter(self, "search"),
		Filter.ChoiceFilter(self, "typeName", GetString(KELA_LOOTLOG_TYPE), GetTypeOptions),
		Filter.ChoiceFilter(self, "quality", GetString(KELA_BROWSER_QUALITY), GetQualityOptions),
		Filter.ChoiceFilter(self, "stock", GetString(KELA_LOOTLOG_STOCK), GetStockOptions),
	}
end

function materials:GetSummary()
	return
	{
		{ GetString(KELA_LOOTLOG_TYPE), GetLabel(GetTypeOptions(), self.typeName) },
		{ GetString(KELA_BROWSER_QUALITY), GetLabel(GetQualityOptions(), self.quality) },
		{ GetString(KELA_LOOTLOG_STOCK), GetLabel(GetStockOptions(), self.stock) },
		{ GetString(KELA_LOOTLOG_SINCE), self.since > 0 and os.date("%H:%M:%S", self.since) or "" },
	}
end

-- ---------------------------------------------------------------------------
-- Screen
-- ---------------------------------------------------------------------------

local sources = { history, materials }
local browser
local callbackRegistered = false

-- Loot Log calls these when an item is looted or a collection changes.
local function RegisterRefreshCallback()
	if callbackRegistered or type(LootLog.refreshCallbacks) ~= "table" then
		return
	end
	callbackRegistered = true
	table.insert(LootLog.refreshCallbacks, function()
		-- Runs inside Loot Log's own refresh loop: never raise into it.
		local ok, err = pcall(function()
			for _, source in ipairs(sources) do
				KelaGamepadBrowser.Changed(source)
			end
		end)
		if not ok and KelaPadUI.log then
			KelaPadUI.log:Warn("Loot Log refresh failed: %s", tostring(err))
		end
	end)
end

function KelaShowLootLog()
	if not KelaIsLootLogAvailable() then
		return
	end
	RegisterRefreshCallback()
	if not browser then
		browser = KelaGamepadBrowser:New(SCENE_NAME)
		browser:SetSources(sources, 1)
	end
	SCENE_MANAGER:Push(SCENE_NAME)
end
