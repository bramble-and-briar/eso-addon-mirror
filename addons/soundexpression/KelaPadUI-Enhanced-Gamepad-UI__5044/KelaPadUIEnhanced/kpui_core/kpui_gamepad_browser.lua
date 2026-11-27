-- KelaPadUI gamepad data browser: a reusable "filters on the left, sortable
-- table on the right" screen for any data source, built only from core gamepad
-- classes, as the Sets browser is:
--
--   * left: a ZO_Gamepad_ParametricList_Screen with a tab bar (L1/R1 switch
--     sources) and the source's filters, search first;
--   * right: one ZO_GamepadInteractiveSortFilterList per source across
--     quadrants 2-4, with the core column headers (up from the first row, A
--     sorts), row focus, triggers to the first and last row, and Back to the
--     filters.
--
-- A source is a plain table; every function is optional except GetColumns and
-- GetRows. `record` is whatever GetRows returns, passed back unchanged.
--
--   name                      string, or function returning it (tab text)
--   Activate(source)          called before the source is shown
--   GetColumns(source)        { { title, key, width, align } } left to right;
--                             `width` is relative, `key` is the sort key
--   GetRows(source)           array of records, already filtered
--   GetCellTexts(source, record)  { text per column }, icon path (drawn in
--                                 column source.iconColumn, default 1)
--   GetSortState(source)      key, order of the current sort
--   Sort(source, key, order)  sorts the source; without it the table sorts
--                             records by record[key]
--   GetFilters(source)        { filter } where filter is one of
--                               { kind = "search", Get(), Set(text) }
--                               { kind = "choice", caption, GetChoices() ->
--                                 labels, GetSelected() -> index, Select(index) }
--                               { kind = "toggle", caption, Get(), Set(bool) }
--   GetActions(source, record)    { { label, action } }
--   GetTooltip(source, record)    "item", link | "collectible", id |
--                             "antiquity", id | "text", s
--   GetSummary(source)        { { label, value } }, up to four, above the table
--
-- Rows with equal sort values keep the order GetRows returned them in, so a
-- source orders its rows sensibly and the sort only reorders by the column.
--
-- A source calls browser:RefreshSource(source) when its data changes, or
-- KelaGamepadBrowser.Changed(source) from anywhere (SetSources stores the
-- browser on each source). The filter builders below keep their state on the
-- source, as `source[field]`, and call Changed themselves.

local CHOICE_DIALOG = "KELA_GAMEPAD_BROWSER_CHOICE"
local ROW_HEIGHT = 44
local ROW_FONT = "ZoFontGamepad27"
local ICON_SIZE = 32
local DATA_TYPE = 1

local FILTER_SEARCH = "search"
local FILTER_CHOICE = "choice"
local FILTER_TOGGLE = "toggle"

local function ResolveText(value, ...)
	if type(value) == "function" then
		return value(...)
	elseif type(value) == "number" then
		return GetString(value)
	end
	return value or ""
end

-- ---------------------------------------------------------------------------
-- Choice dialog (choice filters and row actions)
-- ---------------------------------------------------------------------------

local choiceDialogRegistered = false

local function RegisterChoiceDialog()
	if choiceDialogRegistered then
		return
	end
	choiceDialogRegistered = true
	KelaRegisterGamepadDialog(CHOICE_DIALOG,
	{
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
		title = { text = function(dialog) return dialog.data and dialog.data.title or "" end },
		setup = function(dialog)
			local entries = dialog.info.parametricList
			ZO_ClearNumericallyIndexedTable(entries)
			for index, label in ipairs(dialog.data.labels) do
				entries[#entries + 1] =
				{
					template = "ZO_GamepadMenuEntryTemplate",
					templateData =
					{
						text = index == dialog.data.selectedIndex and ZO_SELECTED_TEXT:Colorize(label) or label,
						setup = ZO_SharedGamepadEntry_OnSetup,
						callback = function()
							local onPick = dialog.data.onPick
							ZO_Dialogs_ReleaseDialogOnButtonPress(CHOICE_DIALOG)
							onPick(index)
						end,
					},
				}
			end
			dialog:setupFunc()
			if dialog.data.selectedIndex then
				dialog.entryList:SetSelectedIndexWithoutAnimation(dialog.data.selectedIndex)
			end
		end,
		parametricList = {},
		blockDialogReleaseOnPress = true,
		buttons = KelaParametricSelectBackButtons(CHOICE_DIALOG),
	})
end

local function ShowChoices(title, labels, selectedIndex, onPick)
	if #labels > 0 then
		RegisterChoiceDialog()
		ZO_Dialogs_ShowGamepadDialog(CHOICE_DIALOG, { title = title, labels = labels, selectedIndex = selectedIndex, onPick = onPick })
	end
end

-- Shared with the other Kela gamepad screens (Fight Stats filters).
KelaShowChoiceDialog = ShowChoices

local function RunActions(actions)
	if #actions == 1 then
		actions[1].action()
	elseif #actions > 1 then
		local labels = {}
		for index, action in ipairs(actions) do
			labels[index] = action.label
		end
		ShowChoices(GetString(KELA_BROWSER_ACTIONS), labels, nil, function(index)
			actions[index].action()
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Table: one core gamepad sort-filter list per source
-- ---------------------------------------------------------------------------

local BrowserTable = ZO_GamepadInteractiveSortFilterList:Subclass()

function BrowserTable:New(...)
	return ZO_GamepadInteractiveSortFilterList.New(self, ...)
end

-- `control` comes from ZO_GamepadInteractiveSortFilterListControl with one
-- header per column already in ContainerHeaders (the core class reads them
-- when it initializes).
function BrowserTable:Initialize(control, browser, source, columns)
	self.browser = browser
	self.source = source
	self.columns = columns
	ZO_GamepadInteractiveSortFilterList.Initialize(self, control)
	self:RemoveFilters()
	self:SetEmptyText(GetString(KELA_BROWSER_NO_RESULTS))
	-- The header above the table grows once its summary is filled in, which
	-- shrinks the list after its scroll range was set: without a recommit the
	-- last rows could not be scrolled into view.
	ZO_ScrollList_AddCommitOnHeightChange(self.list)
	ZO_ScrollList_AddDataType(self.list, DATA_TYPE, "ZO_GamepadInteractiveSortFilterListRow", ROW_HEIGHT, function(row, rowData)
		self:SetupRow(row, rowData)
	end)

	local key, order = nil, nil
	if source.GetSortState then
		key, order = source:GetSortState()
	end
	if key ~= nil and self.sortHeaderGroup:HeaderForKey(key) then
		-- Show the source's current sort without sorting again.
		local SUPPRESS_CALLBACKS = true
		local FORCE_RESELECT = true
		self.sortHeaderGroup:SelectHeaderByKey(key, SUPPRESS_CALLBACKS, FORCE_RESELECT, order)
		self.currentSortKey = key
		self.currentSortOrder = order
	end
end

function BrowserTable:InitializeKeybinds()
	local browser = self.browser
	local descriptor =
	{
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		-- The row's action, or a menu of its actions.
		{
			name = function()
				local actions = self:GetSelectedActions()
				return #actions == 1 and actions[1].label or GetString(KELA_BROWSER_ACTIONS)
			end,
			keybind = "UI_SHORTCUT_PRIMARY",
			visible = function()
				return #self:GetSelectedActions() > 0
			end,
			callback = function()
				RunActions(self:GetSelectedActions())
			end,
		},
		-- An action that names a `keybind` gets that button of its own.
		self:CreateActionKeybind("UI_SHORTCUT_SECONDARY"),
		self:CreateActionKeybind("UI_SHORTCUT_TERTIARY"),
		-- Show or hide the row's tooltip, as the Sets browser does.
		{
			alignment = KEYBIND_STRIP_ALIGN_RIGHT,
			name = function()
				return GetString(browser.showDetails and SI_WORLD_MAP_ACTION_HIDE_INFORMATION or SI_WORLD_MAP_ACTION_SHOW_INFORMATION)
			end,
			keybind = "UI_SHORTCUT_RIGHT_STICK",
			callback = function()
				browser.showDetails = not browser.showDetails
				browser:ShowDetails(self:GetSelectedRecord())
				self:UpdateKeybinds()
			end,
		},
		-- Left goes back to the filters, like Back.
		{
			name = "Kela Gamepad Browser Filters",
			keybind = "UI_SHORTCUT_INPUT_LEFT",
			ethereal = true,
			callback = self:GetBackKeybindCallback(),
		},
	}
	ZO_Gamepad_AddBackNavigationKeybindDescriptorsWithSound(descriptor, GAME_NAVIGATION_TYPE_BUTTON, self:GetBackKeybindCallback())
	self:SetKeybindStripDescriptor(descriptor)
	ZO_GamepadInteractiveSortFilterList.InitializeKeybinds(self)
end

function BrowserTable:CreateActionKeybind(keybind)
	local function GetAction()
		for _, action in ipairs(self:GetSelectedActions(keybind)) do
			return action
		end
	end
	return
	{
		name = function()
			local action = GetAction()
			return action and action.label or ""
		end,
		keybind = keybind,
		visible = function()
			return GetAction() ~= nil
		end,
		callback = function()
			local action = GetAction()
			if action then
				action.action()
			end
		end,
	}
end

function BrowserTable:GetBackKeybindCallback()
	return function()
		self.browser:FocusFilters()
	end
end

function BrowserTable:BuildMasterList()
	self.masterList = {}
	for index, record in ipairs(self.source:GetRows() or {}) do
		-- Rows are wrapped: the core list writes sortIndex into row data, and the
		-- record belongs to the source.
		self.masterList[index] = { record = record, order = index }
	end
end

function BrowserTable:FilterScrollList()
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)
	for _, rowData in ipairs(self.masterList) do
		scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(DATA_TYPE, rowData)
	end
end

-- Sources that sort themselves return their rows in order already.
function BrowserTable:SortScrollList()
	if self.source.Sort or self.currentSortKey == nil then
		return
	end
	local key, ascending = self.currentSortKey, self.currentSortOrder ~= ZO_SORT_ORDER_DOWN
	table.sort(ZO_ScrollList_GetDataList(self.list), function(a, b)
		local valueA, valueB = a.data.record[key], b.data.record[key]
		if type(valueA) ~= type(valueB) or type(valueA) == "table" or type(valueA) == "boolean" then
			valueA, valueB = tostring(valueA), tostring(valueB)
		end
		if valueA == valueB then
			-- table.sort is not stable: ties keep the order the source gave.
			return a.data.order < b.data.order
		end
		if ascending then
			return valueA < valueB
		end
		return valueA > valueB
	end)
end

function BrowserTable:OnSortHeaderClicked(key, order)
	self.currentSortKey = key
	self.currentSortOrder = order
	if self.source.Sort then
		self.browser:RunSourceCall(function()
			self.source:Sort(key, order)
		end)
		self:RefreshData()
	else
		self:RefreshSort()
	end
end

function BrowserTable:CommitScrollList()
	ZO_GamepadInteractiveSortFilterList.CommitScrollList(self)
	self.browser:RefreshTableHeader(self)
end

function BrowserTable:GetRowCells(rowData)
	if not rowData.texts then
		local texts, icon = nil, nil
		if self.source.GetCellTexts then
			texts, icon = self.source:GetCellTexts(rowData.record)
		end
		if not texts then
			texts = {}
			for index, column in ipairs(self.columns) do
				local value = column.key ~= nil and type(rowData.record) == "table" and rowData.record[column.key]
				texts[index] = value and tostring(value) or ""
			end
		end
		rowData.texts = texts
		rowData.icon = icon
	end
	return rowData.texts, rowData.icon
end

function BrowserTable:SetupRow(row, rowData)
	row:SetHeight(ROW_HEIGHT)
	if not row.kelaCells then
		row.kelaCells = {}
		row.kelaIcon = WINDOW_MANAGER:CreateControl(row:GetName() .. "KelaIcon", row, CT_TEXTURE)
		row.kelaIcon:SetDimensions(ICON_SIZE, ICON_SIZE)
	end
	local texts, icon = self:GetRowCells(rowData)
	row.kelaIcon:SetHidden(not icon)
	for index, column in ipairs(self.columns) do
		local label = row.kelaCells[index]
		if not label then
			label = CreateControlFromVirtual(row:GetName() .. "KelaCell" .. index, row, "ZO_GamepadInteractiveSortFilterListRowLabel")
			label:SetFont(ROW_FONT)
			row.kelaCells[index] = label
		end
		local indent = 0
		if index == (self.source.iconColumn or 1) and icon then
			indent = ICON_SIZE + 8
			row.kelaIcon:ClearAnchors()
			row.kelaIcon:SetAnchor(LEFT, row, LEFT, column.offset, 0)
			row.kelaIcon:SetTexture(icon)
		end
		label:ClearAnchors()
		label:SetAnchor(LEFT, row, LEFT, column.offset + indent, 0)
		label:SetDimensions(column.drawWidth - indent, ROW_HEIGHT)
		label:SetHorizontalAlignment(column.align or TEXT_ALIGN_LEFT)
		-- An explicit opaque colour: the core row colouring copies the label's
		-- on-screen alpha, which is 0 while the table fades in, so rows set up
		-- then stayed invisible. Colour markup in the text still wins.
		label:SetColor(ZO_WHITE:UnpackRGBA())
		label:SetText(texts[index] or "")
		label:SetHidden(false)
	end
end

function BrowserTable:OnSelectionChanged(oldData, newData)
	ZO_GamepadInteractiveSortFilterList.OnSelectionChanged(self, oldData, newData)
	self.browser:ShowDetails(newData and newData.record)
	self:UpdateKeybinds()
end

function BrowserTable:GetSelectedRecord()
	local rowData = ZO_ScrollList_GetSelectedData(self.list)
	return rowData and rowData.record
end

-- The selected row's actions: those with no button of their own for A (the
-- default), or the ones bound to `keybind`.
function BrowserTable:GetSelectedActions(keybind)
	local record = self:GetSelectedRecord()
	if record == nil or not self.source.GetActions then
		return {}
	end
	local actions = {}
	for _, action in ipairs(self.source:GetActions(record) or {}) do
		if action.keybind == keybind then
			actions[#actions + 1] = action
		end
	end
	return actions
end

-- ---------------------------------------------------------------------------
-- Screen: filters and tab bar on the left
-- ---------------------------------------------------------------------------

KelaGamepadBrowser = ZO_Gamepad_ParametricList_Screen:Subclass()

-- `name` prefixes every control and names the browser's own scene, ready to
-- push.
function KelaGamepadBrowser:New(name)
	local root = CreateTopLevelWindow(name .. "Root")
	root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
	root:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
	local control = CreateControlFromVirtual(name, root, "ZO_Gamepad_ParametricList_Screen")
	local browser = ZO_Object.New(self)
	browser:Initialize(control, name, root)
	return browser
end

function KelaGamepadBrowser:Initialize(control, name, root)
	self.name = name
	self.root = root
	self.sources = {}
	self.tables = {}
	self.showDetails = true
	self.headerData = { tabBarEntries = {} }
	ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_CREATE, true)

	self.fragments = { ZO_FadeSceneFragment:New(control) }
	for _, group in ipairs({ FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW, FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_RIGHT }) do
		for _, fragment in pairs(group) do
			self.fragments[#self.fragments + 1] = fragment
		end
	end
	self.fragments[#self.fragments + 1] = GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT
	self.fragments[#self.fragments + 1] = GAMEPAD_NAV_QUADRANT_2_3_4_BACKGROUND_FRAGMENT
	self.fragments[#self.fragments + 1] = MINIMIZE_CHAT_FRAGMENT
	self.fragments[#self.fragments + 1] = GAMEPAD_MENU_SOUND_FRAGMENT

	local scene = ZO_Scene:New(name, SCENE_MANAGER)
	for _, fragment in ipairs(self.fragments) do
		scene:AddFragment(fragment)
	end
	scene:RegisterCallback("StateChange", function(oldState, newState)
		self:OnSceneStateChanged(newState)
	end)
	self.scene = scene
end

-- `sources` is an array; `index` the one to show first.
function KelaGamepadBrowser:SetSources(sources, index)
	self.sources = sources
	for _, source in ipairs(sources) do
		source.browser = self
	end
	self.sourceIndex = zo_clamp(index or self.sourceIndex or 1, 1, zo_max(#sources, 1))
end

function KelaGamepadBrowser:OnSceneStateChanged(newState)
	self:OnStateChanged(self.scene, newState)
end

-- Calls into a source while ignoring the refreshes it causes.
function KelaGamepadBrowser:RunSourceCall(fn)
	self.inSourceCall = true
	local ok, err = pcall(fn)
	self.inSourceCall = false
	if not ok and KelaPadUI.log then
		KelaPadUI.log:Warn("Gamepad browser source call failed: %s", tostring(err))
	end
end

function KelaGamepadBrowser:SetupList(list)
	list:AddDataTemplate("ZO_GamepadMenuEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
	list:AddDataTemplateWithHeader("ZO_GamepadMenuEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")
	-- The search box shows "Search" itself, so it has no header.
	list:AddDataTemplate("ZO_GamepadTextFieldItem", function(control, data, selected)
		self:SetupSearchField(control, data, selected)
	end, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

function KelaGamepadBrowser:InitializeKeybindStripDescriptors()
	self.keybindStripDescriptor =
	{
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		{
			name = GetString(SI_GAMEPAD_SELECT_OPTION),
			keybind = "UI_SHORTCUT_PRIMARY",
			visible = function()
				return self:GetMainList():GetTargetData() ~= nil
			end,
			callback = function()
				self:ActivateFilter(self:GetMainList():GetTargetData())
			end,
		},
		-- Right moves into the table, as in the Sets browser.
		{
			alignment = KEYBIND_STRIP_ALIGN_CENTER,
			name = GetString(KELA_SETSKEY_VIEW),
			keybind = "UI_SHORTCUT_INPUT_RIGHT",
			visible = function()
				local browserTable = self:GetCurrentTable()
				return browserTable ~= nil and browserTable:HasEntries()
			end,
			callback = function()
				self:FocusTable()
			end,
		},
	}
	ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, function()
		SCENE_MANAGER:HideCurrentScene()
	end)
end

-- ---- sources and tables ------------------------------------------------------

function KelaGamepadBrowser:GetCurrentSource()
	return self.sources[self.sourceIndex]
end

function KelaGamepadBrowser:GetCurrentTable()
	local source = self:GetCurrentSource()
	return source and self.tables[source]
end

-- The table's control in quadrants 2-4, with one core header per column,
-- widths proportional to the source's.
function KelaGamepadBrowser:CreateTable(source)
	local columns = {}
	for index, column in ipairs(source:GetColumns() or {}) do
		columns[index] =
		{
			title = ResolveText(column.title),
			key = column.key,
			width = column.width or 1,
			align = column.align,
		}
	end
	local tableCount = 0
	for _ in pairs(self.tables) do
		tableCount = tableCount + 1
	end
	local name = self.name .. "Table" .. (tableCount + 1)
	local left = ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET
	local control = CreateControlFromVirtual(name, self.root, "ZO_GamepadInteractiveSortFilterListControl")
	control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, ZO_GAMEPAD_QUADRANT_TOP_OFFSET)
	control:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, left, ZO_GAMEPAD_QUADRANT_BOTTOM_OFFSET)
	control:SetWidth(ZO_GAMEPAD_QUADRANT_2_3_4_WIDTH)
	control:SetHidden(true)

	local container = control:GetNamedChild("Container")
	local headers = container:GetNamedChild("Headers")
	-- The headers row's real width (the container insets the quadrant on both
	-- sides), less the gaps between columns and the highlight padding at the
	-- right edge, so the last column ends inside the table.
	local rowWidth = headers:GetWidth()
	if rowWidth <= 0 then
		rowWidth = ZO_GAMEPAD_QUADRANT_2_3_4_WIDTH - 2 * ZO_GAMEPAD_CONTENT_INSET_X
	end
	local available = rowWidth - ZO_GAMEPAD_INTERACTIVE_FILTER_HIGHLIGHT_PADDING * (#columns + 1)
		- ZO_GAMEPAD_INTERACTIVE_FILTER_ARROW_PADDING
	local totalWidth = 0
	for _, column in ipairs(columns) do
		totalWidth = totalWidth + column.width
	end
	local offset = ZO_GAMEPAD_INTERACTIVE_FILTER_HIGHLIGHT_PADDING
	for index, column in ipairs(columns) do
		column.drawWidth = zo_floor(column.width / zo_max(totalWidth, 1) * available)
		column.offset = offset
		local header = CreateControlFromVirtual(headers:GetName() .. "Column" .. index, headers, "ZO_GamepadInteractiveFilterHeader")
		header:SetAnchor(TOPLEFT, headers, TOPLEFT, offset, 0)
		header:SetWidth(column.drawWidth)
		-- Columns without a key still need one for the header group; they sort
		-- by their position.
		ZO_GamepadInteractiveSortFilterHeader_Initialize(header, column.title, column.key or index, column.align or TEXT_ALIGN_LEFT)
		offset = offset + column.drawWidth + ZO_GAMEPAD_INTERACTIVE_FILTER_HIGHLIGHT_PADDING
	end

	local browserTable = BrowserTable:New(control, self, source, columns)
	self.tables[source] = browserTable
	return browserTable
end

-- Title and count above the table. A source with GetSummary shows up to four
-- label/value pairs there (its current filters), with the count in the title.
function KelaGamepadBrowser:RefreshTableHeader(browserTable)
	local source = browserTable.source
	local name = ResolveText(source.name, source)
	local count = zo_strformat(GetString(KELA_BROWSER_COUNT), #ZO_ScrollList_GetDataList(browserTable.list))
	local data = browserTable:GetContentHeaderData()
	local summary = source.GetSummary and source:GetSummary() or nil
	if summary then
		browserTable:SetTitle(name .. " (" .. count .. ")")
		for index = 1, 4 do
			local pair = summary[index]
			data["data" .. index .. "HeaderText"] = pair and pair[1] or nil
			data["data" .. index .. "Text"] = pair and pair[2] or nil
		end
	else
		browserTable:SetTitle(name)
		data.data1HeaderText = ""
		data.data1Text = count
	end
	browserTable:RefreshHeader()
end

-- Called by a source when its data changed.
function KelaGamepadBrowser:RefreshSource(source)
	local browserTable = self.tables[source]
	if browserTable and not self.inSourceCall and self:IsShowing() then
		browserTable:RefreshData()
		self:GetMainList():RefreshVisible()
		self:RefreshKeybinds()
	end
end

function KelaGamepadBrowser:RefreshTabs()
	local entries = {}
	for index, source in ipairs(self.sources) do
		entries[index] =
		{
			text = ResolveText(source.name, source),
			callback = function()
				self:SelectSource(index)
			end,
		}
	end
	self.headerData.tabBarEntries = entries
	ZO_GamepadGenericHeader_Refresh(self.header, self.headerData, true)
	if self.sources[self.sourceIndex] then
		ZO_GamepadGenericHeader_SetActiveTabIndex(self.header, self.sourceIndex, nil, true)
	end
end

function KelaGamepadBrowser:SelectSource(index)
	local source = self.sources[index]
	if not source then
		return
	end
	local oldTable = self:GetCurrentTable()
	if oldTable then
		oldTable:Deactivate()
		SCENE_MANAGER:RemoveFragment(oldTable:GetListFragment())
	end
	self.sourceIndex = index
	if source.Activate then
		self:RunSourceCall(function()
			source:Activate()
		end)
	end
	local browserTable = self.tables[source] or self:CreateTable(source)
	SCENE_MANAGER:AddFragment(browserTable:GetListFragment())
	browserTable:RefreshData()
	self:RefreshFilters()
	self:FocusFilters()
end

-- ---- filters ---------------------------------------------------------------

function KelaGamepadBrowser:RefreshFilters()
	local list = self:GetMainList()
	list:Clear()
	local source = self:GetCurrentSource()
	local filters = source and source.GetFilters and source:GetFilters() or {}
	-- Search first, then the rest in the source's order.
	local ordered = {}
	for _, filter in ipairs(filters) do
		if filter.kind == FILTER_SEARCH then
			ordered[#ordered + 1] = filter
		end
	end
	for _, filter in ipairs(filters) do
		if filter.kind ~= FILTER_SEARCH then
			ordered[#ordered + 1] = filter
		end
	end
	-- The first filter opens the "Filters" section; one with a `header` opens
	-- a section of that name.
	local headerAdded = false
	for _, filter in ipairs(ordered) do
		if filter.kind == FILTER_SEARCH then
			local data = ZO_GamepadEntryData:New("")
			data.narrationText = ZO_GetDefaultParametricListEditBoxNarrationText
			data.filter = filter
			list:AddEntry("ZO_GamepadTextFieldItem", data)
		else
			local data = ZO_GamepadEntryData:New(ResolveText(filter.caption))
			data.filter = filter
			data:AddSubLabel(function()
				return self:GetFilterValueText(filter)
			end)
			if headerAdded and not filter.header then
				list:AddEntry("ZO_GamepadMenuEntryTemplate", data)
			else
				data:SetHeader(filter.header and ResolveText(filter.header) or GetString(KELA_BROWSER_FILTERS))
				list:AddEntryWithHeader("ZO_GamepadMenuEntryTemplate", data)
				headerAdded = true
			end
		end
	end
	list:Commit()
end

function KelaGamepadBrowser:GetFilterValueText(filter)
	if filter.kind == FILTER_CHOICE then
		return filter.GetChoices()[filter.GetSelected()] or ""
	elseif filter.kind == FILTER_TOGGLE then
		return GetString(filter.Get() and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
	end
	return ""
end

function KelaGamepadBrowser:SetupSearchField(control, data, selected)
	control.highlight:SetHidden(not selected)
	local editBox = control.editBoxControl
	local filter = data.filter
	data.editBoxControl = editBox
	editBox:SetDefaultText(GetString(KELA_SETS_SEARCHFIELD_DEFAULTTEXT))
	editBox.focusLostCallback = function(edit)
		if edit:GetText() ~= filter.Get() then
			filter.Set(edit:GetText())
		end
		self:RefreshKeybinds()
	end
	if editBox:GetText() ~= filter.Get() then
		editBox:SetText(filter.Get())
	end
end

function KelaGamepadBrowser:ActivateFilter(data)
	local filter = data and data.filter
	if not filter then
		return
	end
	if filter.kind == FILTER_SEARCH then
		local editBox = data.editBoxControl
		if editBox then
			if editBox:HasFocus() then
				editBox:LoseFocus()
			else
				editBox:TakeFocus()
			end
		end
	elseif filter.kind == FILTER_TOGGLE then
		filter.Set(not filter.Get())
		self:GetMainList():RefreshVisible()
	elseif filter.kind == FILTER_CHOICE then
		ShowChoices(ResolveText(filter.caption), filter.GetChoices(), filter.GetSelected(), function(index)
			filter.Select(index)
			self:GetMainList():RefreshVisible()
		end)
	end
end

-- ---- details ---------------------------------------------------------------

-- Right tooltip for a record: an item, a collectible, or text.
function KelaGamepadBrowser:ShowDetails(record)
	GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
	local source = self:GetCurrentSource()
	if record == nil or not self.showDetails or not (source and source.GetTooltip) then
		return
	end
	local kind, value = source:GetTooltip(record)
	if kind == "item" then
		GAMEPAD_TOOLTIPS:LayoutItem(GAMEPAD_RIGHT_TOOLTIP, value)
	elseif kind == "collectible" and ZO_COLLECTIBLE_DATA_MANAGER then
		local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(value)
		if collectibleData then
			GAMEPAD_TOOLTIPS:LayoutCollectibleFromData(GAMEPAD_RIGHT_TOOLTIP, collectibleData)
		end
	elseif kind == "antiquity" then
		GAMEPAD_TOOLTIPS:LayoutAntiquityLead(GAMEPAD_RIGHT_TOOLTIP, value)
	elseif kind == "text" and value and value ~= "" then
		GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(GAMEPAD_RIGHT_TOOLTIP, value)
	end
end

-- ---- focus -----------------------------------------------------------------

function KelaGamepadBrowser:FocusTable()
	local browserTable = self:GetCurrentTable()
	if not (browserTable and browserTable:HasEntries()) then
		return
	end
	self:DeactivateCurrentList()
	KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
	browserTable:Activate()
	self.tableFocused = true
end

function KelaGamepadBrowser:FocusFilters()
	local browserTable = self:GetCurrentTable()
	if browserTable then
		browserTable:Deactivate()
	end
	GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
	if self.tableFocused then
		self.tableFocused = false
		KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
	end
	if self:IsShowing() then
		self:ActivateCurrentList()
	end
	self:RefreshKeybinds()
end

-- ---- lifecycle -------------------------------------------------------------

function KelaGamepadBrowser:PerformUpdate()
	self.dirty = false
end

function KelaGamepadBrowser:OnShowing()
	self.tableFocused = false
	self:RefreshTabs()
	ZO_GamepadGenericHeader_Activate(self.header)
end

-- Sources get the scene shown before their first table is built, so one that
-- needs to load its data can do it in Activate.
function KelaGamepadBrowser:OnShow()
	self:SelectSource(self.sourceIndex or 1)
end

function KelaGamepadBrowser:OnHiding()
	ZO_GamepadGenericHeader_Deactivate(self.header)
	local browserTable = self:GetCurrentTable()
	if browserTable then
		browserTable:Deactivate()
	end
	self.tableFocused = false
	GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
end

-- ---------------------------------------------------------------------------
-- Filter builders
-- ---------------------------------------------------------------------------

-- Tells the browser a source's data or filters changed.
function KelaGamepadBrowser.Changed(source)
	if source.browser then
		source.browser:RefreshSource(source)
	end
end

-- A search box over source[field].
function KelaGamepadBrowser.SearchFilter(source, field)
	return
	{
		kind = FILTER_SEARCH,
		Get = function() return source[field] or "" end,
		Set = function(text)
			source[field] = text or ""
			KelaGamepadBrowser.Changed(source)
		end,
	}
end

-- A choice over source[field]. `GetOptions()` returns { { label, value } } with
-- the first entry the unfiltered one; source[field] holds the chosen value
-- (nil for the first entry when its value is nil), never an index, so a list
-- that changes under the player keeps the choice. A chosen value that fell out
-- of the list stays listed, so what shows is what filters.
function KelaGamepadBrowser.ChoiceFilter(source, field, caption, GetOptions)
	local function Options()
		local options = GetOptions()
		local current = source[field]
		if current ~= nil then
			local found = false
			for _, option in ipairs(options) do
				if option.value == current then
					found = true
					break
				end
			end
			if not found then
				options[#options + 1] = { label = tostring(current), value = current }
			end
		end
		return options
	end
	return
	{
		kind = FILTER_CHOICE,
		caption = caption,
		GetChoices = function()
			local labels = {}
			for index, option in ipairs(Options()) do
				labels[index] = option.label
			end
			return labels
		end,
		GetSelected = function()
			for index, option in ipairs(Options()) do
				if option.value == source[field] then
					return index
				end
			end
			return 1
		end,
		Select = function(index)
			local option = Options()[index]
			if option and option.value ~= source[field] then
				source[field] = option.value
				KelaGamepadBrowser.Changed(source)
			end
		end,
	}
end

-- Starts a new section of the filter list, named `header`, at this filter.
function KelaGamepadBrowser.WithHeader(filter, header)
	filter.header = header
	return filter
end

-- An on/off toggle over source[field].
function KelaGamepadBrowser.ToggleFilter(source, field, caption)
	return
	{
		kind = FILTER_TOGGLE,
		caption = caption,
		Get = function() return source[field] == true end,
		Set = function(checked)
			source[field] = checked == true
			KelaGamepadBrowser.Changed(source)
		end,
	}
end
