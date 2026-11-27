-- KelaPadUI Collectibles Tracker: the collectibles Collectibles Tracker (by
-- code65536) follows, in the gamepad data browser
-- (kpui_core/kpui_gamepad_browser.lua). Two pages, switched with L1/R1:
-- Collectibles (Crown Store and other sources, by season) and Event
-- Collectibles. Each has filters for the source, the collection state, the
-- category, and hidden entries, and the collectible's tooltip.
--
-- The add-on has no data API, so this reads its own tables:
-- `CollectiblesTracker.data[key]` (the lists) and
-- `CollectiblesTracker.vars[key]` (the entries the player hid). Hiding and
-- unhiding here changes the same saved list, so the keyboard window agrees.
-- Names, icons, categories and ownership come from the game.
--
-- A list is an array of sources: `{ name, entries..., premium = entries }`.
-- An entry is a collectible id; a negative id means the range from the id
-- after the previous one up to it; a table is `{ id, fragment ids..., true }`
-- (a collectible made of fragments, `true` marking a base morph). The first
-- premium entry is the season's Tome, never listed itself: the other premium
-- entries are hidden until the player owns it.

local SCENE_NAME = "KelaCollectiblesTracker"
local EVENT_NAMESPACE = "KelaPadUI_CollectiblesTracker"

local STATUS_YES, STATUS_NO, STATUS_PARTIAL = "yes", "no", "partial"

-- The first source is an empty "All" placeholder in the add-on's own filter.
local FIRST_REAL_SOURCE = 2

function KelaIsCollectiblesTrackerAvailable()
	return type(CollectiblesTracker) == "table"
		and type(CollectiblesTracker.data) == "table"
		and type(CollectiblesTracker.vars) == "table"
		and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FEATURES_COLLECTIBLES_TRACKER)
end

-- ---------------------------------------------------------------------------
-- Reading a list
-- ---------------------------------------------------------------------------

-- Calls callback(value, index) for each entry of a list, expanding ranges.
local function ForEachEntry(list, callback)
	local index, previous = 0, 0
	for _, value in ipairs(list) do
		if type(value) == "number" and value < 0 then
			for id = previous + 1, -value do
				index = index + 1
				callback(id, index)
			end
		else
			index = index + 1
			callback(value, index)
			if type(value) == "number" then
				previous = value
			end
		end
	end
end

-- Fragment ids of a table entry (everything after the first id).
local function GetFragmentIds(entry)
	local ids = {}
	ForEachEntry(entry, function(id, index)
		if index > 1 and type(id) == "number" then
			ids[#ids + 1] = id
		end
	end)
	return ids
end

-- The static part of every row of a list: names and categories do not change
-- while the game runs, so they are read once. The state is read per refresh.
local function BuildRows(key)
	local rows = {}
	local list = CollectiblesTracker.data[key]
	if type(list) ~= "table" then
		return rows
	end
	local function AddEntry(entry, sourceId, sourceName, premium)
		local id, fragments = entry, nil
		if type(entry) == "table" then
			id = entry[1]
			if #entry > 1 then
				fragments = GetFragmentIds(entry)
			end
		end
		if type(id) ~= "number" then
			return
		end
		local name, _, icon, _, _, _, _, categoryType = GetCollectibleInfo(id)
		if name == "" then
			return
		end
		if premium and premium.first then
			-- The Tome: owning it decides whether the rest of the list shows.
			premium.first = false
			premium.tomeId = id
			return
		end
		name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
		rows[#rows + 1] =
		{
			id = id,
			name = name,
			sortName = zo_strlower(name),
			icon = icon,
			fragments = fragments,
			categoryType = categoryType,
			categoryName = GetString("SI_COLLECTIBLECATEGORYTYPE", categoryType),
			sourceId = sourceId,
			sourceName = sourceName,
			tomeId = premium and premium.tomeId or nil,
		}
	end
	for sourceId, source in ipairs(list) do
		if sourceId >= FIRST_REAL_SOURCE and type(source) == "table" then
			for index = 2, #source do
				if type(source[index]) == "table" then
					ForEachEntry(source[index], function(entry)
						AddEntry(entry, sourceId, source[1], nil)
					end)
				end
			end
			if type(source.premium) == "table" then
				local premium = { first = true }
				ForEachEntry(source.premium, function(entry)
					AddEntry(entry, sourceId, source[1], premium)
				end)
			end
		end
	end
	return rows
end

-- ---------------------------------------------------------------------------
-- A list as a browser source
-- ---------------------------------------------------------------------------

local function GetLabel(options, value)
	for _, option in ipairs(options) do
		if option.value == value then
			return option.label
		end
	end
	return ""
end

local function GetStatusOptions()
	return
	{
		{ label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) },
		{ label = GetString(KELA_COLLECTIBLES_COLLECTED), value = STATUS_YES },
		{ label = GetString(KELA_COLLECTIBLES_NOT_COLLECTED), value = STATUS_NO },
		{ label = GetString(KELA_COLLECTIBLES_IN_PROGRESS), value = STATUS_PARTIAL },
	}
end

local function GetHideTable(key)
	local vars = CollectiblesTracker.vars[key]
	return type(vars) == "table" and type(vars.hide) == "table" and vars.hide or nil
end

local function CreateSource(key, GetName)
	local source = { name = GetName, key = key, search = "", records = nil, initialized = false }

	function source:Activate()
		if not self.initialized then
			self.initialized = true
		end
		self.records = self.records or BuildRows(key)
	end

	function source:GetColumns()
		return
		{
			{ title = KELA_COLLECTIBLES_NAME, key = "sortName", width = 5 },
			{ title = KELA_COLLECTIBLES_STATUS, key = "status", width = 1.7 },
			{ title = KELA_COLLECTIBLES_CATEGORY, key = "categoryName", width = 2.6 },
			{ title = KELA_COLLECTIBLES_SOURCE, key = "sourceId", width = 3.4 },
		}
	end

	-- Sources in the add-on's order: oldest first.
	function source:GetSortState()
		return "sourceId", ZO_SORT_ORDER_UP
	end

	function source:GetRows()
		self.records = self.records or BuildRows(key)
		local hideTable = GetHideTable(key) or {}
		local needle = zo_strlower(self.search)
		local rows = {}
		local collected = 0
		self.hiddenCount = 0
		for _, record in ipairs(self.records) do
			local owned = IsCollectibleOwnedByDefId(record.id)
			local ownedFragments = 0
			if record.fragments then
				for _, fragmentId in ipairs(record.fragments) do
					if IsCollectibleOwnedByDefId(fragmentId) then
						ownedFragments = ownedFragments + 1
					end
				end
			end
			record.owned = owned
			record.ownedFragments = ownedFragments
			if owned then
				record.status = 2
			elseif record.fragments and #record.fragments > 0 then
				record.status = ownedFragments / #record.fragments
			else
				record.status = 0
			end
			record.premiumHidden = record.tomeId ~= nil and not IsCollectibleOwnedByDefId(record.tomeId)
			record.manuallyHidden = hideTable[record.id] == true
			record.hidden = record.manuallyHidden or record.premiumHidden
			if record.hidden then
				self.hiddenCount = self.hiddenCount + 1
			end
			local statusKey = owned and STATUS_YES or (record.status > 0 and STATUS_PARTIAL or STATUS_NO)
			if (needle == "" or zo_plainstrfind(record.sortName, needle) or zo_plainstrfind(zo_strlower(record.sourceName), needle))
				and (self.sourceId == nil or record.sourceId == self.sourceId)
				and (self.categoryType == nil or record.categoryType == self.categoryType)
				and (self.status == nil or statusKey == self.status or (self.status == STATUS_NO and statusKey == STATUS_PARTIAL))
				and (self.showPremium or not record.premiumHidden)
				and (self.showManual or not record.manuallyHidden) then
				rows[#rows + 1] = record
				if owned then
					collected = collected + 1
				end
			end
		end
		self.collectedCount = collected
		self.shownCount = #rows
		return rows
	end

	function source:GetCellTexts(record)
		local statusText
		if record.owned then
			statusText = kpuiConst.Colors.COLOR_LIGHT_GREEN:Colorize(GetString(SI_YES))
		elseif record.fragments and #record.fragments > 0 then
			local text = string.format("%d / %d", record.ownedFragments, #record.fragments)
			statusText = (record.ownedFragments > 0 and kpuiConst.Colors.COLOR_LIGHT_ORANGE or kpuiConst.Colors.COLOR_LIGHT_RED):Colorize(text)
		else
			statusText = kpuiConst.Colors.COLOR_LIGHT_RED:Colorize(GetString(SI_NO))
		end
		local nameText = record.name
		if record.hidden then
			nameText = kpuiConst.Colors.COLOR_GREY:Colorize(nameText)
		end
		return { nameText, statusText, record.categoryName, record.sourceName }, record.icon
	end

	function source:GetTooltip(record)
		return "collectible", record.id
	end

	function source:GetActions(record)
		local actions =
		{
			{
				label = GetString(SI_ITEM_ACTION_LINK_TO_CHAT),
				action = function()
					ZO_LinkHandler_InsertLink(GetCollectibleLink(record.id, LINK_STYLE_BRACKETS))
				end,
			},
		}
		local hideTable = GetHideTable(key)
		-- A premium entry is hidden by the Tome, not by the player.
		if hideTable and not record.premiumHidden then
			local isHidden = hideTable[record.id] == true
			actions[#actions + 1] =
			{
				label = GetString(isHidden and KELA_COLLECTIBLES_UNHIDE or KELA_COLLECTIBLES_HIDE),
				action = function()
					hideTable[record.id] = (not isHidden) and true or nil
					KelaGamepadBrowser.Changed(self)
				end,
			}
		end
		return actions
	end

	function source:GetFilters()
		local Filter = KelaGamepadBrowser
		return
		{
			Filter.SearchFilter(self, "search"),
			Filter.ChoiceFilter(self, "sourceId", GetString(KELA_COLLECTIBLES_SOURCE), function()
				return self:GetSourceOptions()
			end),
			Filter.ChoiceFilter(self, "status", GetString(KELA_COLLECTIBLES_STATUS), GetStatusOptions),
			Filter.ChoiceFilter(self, "categoryType", GetString(KELA_COLLECTIBLES_CATEGORY), function()
				return self:GetCategoryOptions()
			end),
			Filter.WithHeader(Filter.ToggleFilter(self, "showPremium", GetString(KELA_COLLECTIBLES_SHOW_PREMIUM)), GetString(KELA_COLLECTIBLES_HIDDEN)),
			Filter.ToggleFilter(self, "showManual", GetString(KELA_COLLECTIBLES_SHOW_MANUAL)),
		}
	end

	-- The list's sources in its order, then "All".
	function source:GetSourceOptions()
		local options = { { label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) } }
		local list = CollectiblesTracker.data[key]
		if type(list) == "table" then
			for sourceId = FIRST_REAL_SOURCE, #list do
				local entry = list[sourceId]
				if type(entry) == "table" and type(entry[1]) == "string" then
					options[#options + 1] = { label = entry[1], value = sourceId }
				end
			end
		end
		return options
	end

	-- The categories present in the list, by name.
	function source:GetCategoryOptions()
		local options, seen = {}, {}
		for _, record in ipairs(self.records or {}) do
			if not seen[record.categoryType] then
				seen[record.categoryType] = true
				options[#options + 1] = { label = record.categoryName, value = record.categoryType }
			end
		end
		table.sort(options, function(a, b)
			return a.label < b.label
		end)
		table.insert(options, 1, { label = GetString(KELA_ACHIEVEMENT_FILTER_ALL) })
		return options
	end

	function source:GetSummary()
		local shown = self.shownCount or 0
		local collected = shown > 0 and string.format("%d / %d (%d%%)", self.collectedCount or 0, shown, zo_round(100 * (self.collectedCount or 0) / shown)) or ""
		return
		{
			{ GetString(KELA_COLLECTIBLES_COLLECTED), collected },
			{ GetString(KELA_COLLECTIBLES_SOURCE), GetLabel(self:GetSourceOptions(), self.sourceId) },
			{ GetString(KELA_COLLECTIBLES_STATUS), GetLabel(GetStatusOptions(), self.status) },
			{ GetString(KELA_COLLECTIBLES_HIDDEN), string.format("%d", self.hiddenCount or 0) },
		}
	end

	return source
end

local sources =
{
	CreateSource("ct", function() return GetString(KELA_COLLECTIBLES_TRACKER_COLLECTIBLES) end),
	CreateSource("ec", function() return GetString(KELA_COLLECTIBLES_TRACKER_EVENTS) end),
}

-- ---------------------------------------------------------------------------
-- Screen
-- ---------------------------------------------------------------------------

local browser

function KelaShowCollectiblesTracker()
	if not KelaIsCollectiblesTrackerAvailable() then
		return
	end
	if not browser then
		browser = KelaGamepadBrowser:New(SCENE_NAME)
		browser:SetSources(sources, 1)
	end
	SCENE_MANAGER:Push(SCENE_NAME)
end

local setupDone = false

-- Refreshes the table when a collectible is unlocked.
function KelaSetupCollectiblesTracker()
	if setupDone then
		return
	end
	setupDone = true
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, function()
		for _, source in ipairs(sources) do
			KelaGamepadBrowser.Changed(source)
		end
	end)
end
