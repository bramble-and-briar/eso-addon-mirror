-- KelaPadUI Extended Journal: every Extended Journal tab as a gamepad browser
-- source (kpui_core/kpui_gamepad_browser.lua), found at run time with no
-- add-on-specific code.
--
-- Extended Journal (LibExtendedJournal by code65536) is the shared keyboard
-- window that Loot Log, Collectibles Tracker, Item Set Browser and others add
-- tabs to. The library has no data API, so each tab is read through what every
-- tab must have:
--
--   * tabs: the library's tab bar buttons (its tab list is removed from the
--     global namespace once it loads);
--   * data: the tab's ZO_SortFilterList (`tabControl.object`), whose scroll
--     data is the add-on's filtered and sorted records;
--   * columns: the list's sort headers (title, width, sort key);
--   * cell text: the add-on's own row setup, run on a hidden row;
--   * filters: the dropdowns, checkboxes and search box on the tab;
--   * actions: the list's context-menu items.
--
-- Add-ons build their lists only when the library shows their tab in its own
-- scene, so the browser runs inside that scene: while it shows from the
-- gamepad entry, its keyboard fragments are swapped for the browser's. The
-- library's frame stays (transparent) so it keeps running the tab callbacks.
-- The keyboard main menu and the library's keybind open the keyboard window as
-- usual, with a controller Back button added in gamepad mode.

local LEJ_SCENE_NAME = "ExtendedJournalScene"
local JOURNAL_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_journal.dds"

-- ---------------------------------------------------------------------------
-- Availability and names
-- ---------------------------------------------------------------------------

-- The library's own (translated) name; our string is the fallback.
function KelaGetExtendedJournalName()
	if SI_LEJ_NAME then
		local name = GetString(SI_LEJ_NAME)
		if name ~= "" then
			return name
		end
	end
	return GetString(KELA_MAINMENU_EXTENDED_JOURNAL)
end

-- True when an installed add-on uses Extended Journal (each one sets `Used`)
-- and the setting is on.
function KelaIsExtendedJournalAvailable()
	return LibExtendedJournal ~= nil
		and LibExtendedJournal.Used == true
		and type(LibExtendedJournal.Show) == "function"
		and type(LibExtendedJournal.GetFrame) == "function"
		and KelaGetSetting_Bool(SETTING_TYPE_KELA, KELA_SETTING_PANEL_FEATURES_EXTENDED_JOURNAL)
end

local function ResolveText(value)
	if type(value) == "number" then
		return GetString(value)
	end
	return type(value) == "string" and value or ""
end

-- "ShowUncollected" -> "Show Uncollected"
local function Prettify(name)
	return (name:gsub("(%l)(%u)", "%1 %2"))
end

-- The part of a control's name after its root's name ("FilterDrop").
local function ChildSuffix(control, root)
	local name, prefix = control:GetName(), root:GetName()
	if name:sub(1, #prefix) == prefix then
		return name:sub(#prefix + 1)
	end
	return name
end

-- ---------------------------------------------------------------------------
-- Reading a tab
-- ---------------------------------------------------------------------------

local function GetLibraryFrame()
	local frame = LibExtendedJournal and LibExtendedJournal.GetFrame()
	return frame, frame and frame:GetNamedChild("MenuBar")
end

-- Tabs in the library's order, from its tab bar buttons.
local function GetTabs()
	local tabs = {}
	local _, menuBar = GetLibraryFrame()
	if menuBar and menuBar.m_object then
		for _, button in ZO_MenuBar_ButtonControlIterator(menuBar) do
			local data = ZO_MenuBarButtonTemplate_GetData(button)
			if data and data.descriptor ~= nil then
				local name = ResolveText(data.categoryName)
				if name == "" then
					local title, subtitle = ResolveText(data.title), ResolveText(data.subtitle)
					name = subtitle ~= "" and (title .. ": " .. subtitle) or title
				end
				tabs[#tabs + 1] = { descriptor = data.descriptor, name = name }
			end
		end
	end
	return tabs
end

-- The shown tab's control: the frame's visible child with a sort-filter list.
local function GetActiveTabControl()
	local frame = GetLibraryFrame()
	if frame then
		for index = 1, frame:GetNumChildren() do
			local child = frame:GetChild(index)
			if not child:IsHidden() and type(child.object) == "table" and child.object.list then
				return child
			end
		end
	end
	return nil
end

-- Columns from the list's sort headers, in screen order.
local function CollectColumns(list)
	local columns = {}
	local container = list.headersContainer
	if container then
		for index = 1, container:GetNumChildren() do
			local header = container:GetChild(index)
			local nameLabel = header:GetNamedChild("Name")
			if nameLabel and nameLabel.GetText and not header:IsHidden() and header:GetWidth() > 0 then
				columns[#columns + 1] =
				{
					name = ChildSuffix(header, container),
					title = nameLabel:GetText() or "",
					key = header.key,
					width = header:GetWidth(),
					align = nameLabel:GetHorizontalAlignment(),
					left = header:GetLeft() - container:GetLeft(),
				}
			end
		end
	end
	table.sort(columns, function(a, b)
		return a.left < b.left
	end)
	return columns
end

-- The tab's filters: search box, dropdowns and checkboxes, as browser filters
-- that drive the add-on's own controls (and so its own filtering).
local function CollectFilters(tabControl)
	local filters = {}
	local function Walk(control)
		for index = 1, control:GetNumChildren() do
			local child = control:GetChild(index)
			local suffix = ChildSuffix(child, tabControl)
			if suffix ~= "List" and suffix ~= "Headers" and not child:IsHidden() then
				local combo = child.m_comboBox
				if combo then
					local caption = child:GetNamedChild("Caption")
					local captionText = caption and caption.GetText and caption:GetText() or ""
					if captionText == "" then
						captionText = Prettify((suffix:gsub("Dropdown$", ""):gsub("Drop$", "")))
					end
					filters[#filters + 1] =
					{
						kind = "choice",
						caption = captionText,
						GetChoices = function()
							local labels = {}
							for itemIndex, item in ipairs(combo:GetItems()) do
								labels[itemIndex] = item.name
							end
							return labels
						end,
						GetSelected = function()
							local selected = combo:GetSelectedItem()
							for itemIndex, item in ipairs(combo:GetItems()) do
								if item.name == selected then
									return itemIndex
								end
							end
							return nil
						end,
						Select = function(itemIndex)
							combo:SelectItem(combo:GetItems()[itemIndex])
						end,
					}
				elseif child:GetType() == CT_EDITBOX then
					filters[#filters + 1] =
					{
						kind = "search",
						Get = function() return child:GetText() end,
						Set = function(text) child:SetText(text) end,
					}
				elseif child:GetType() == CT_BUTTON and child.toggleFunction then
					local labelText = child.label and child.label:GetText() or ""
					filters[#filters + 1] =
					{
						kind = "toggle",
						caption = labelText ~= "" and labelText or Prettify(suffix),
						Get = function() return ZO_CheckButton_IsChecked(child) end,
						Set = function(checked)
							if ZO_CheckButton_IsChecked(child) ~= checked then
								ZO_CheckButton_OnClicked(child)
							end
						end,
					}
				else
					Walk(child)
				end
			end
		end
	end
	Walk(tabControl)
	return filters
end

-- A hidden copy of the list's row, built with the row pool's own factory
-- (ZO_ScrollList keeps no template name), to run the add-on's row setup on.
local probeRows = {}

-- Returns the row's cells, or nil and why.
local function ReadRow(listControl, entry)
	local dataType = ZO_ScrollList_GetDataTypeTable(listControl, entry.typeId)
	local pool = dataType and dataType.pool
	if not (pool and dataType.setupCallback and type(pool.m_Factory) == "function") then
		return nil, "no row pool factory or setup for type " .. tostring(entry.typeId)
	end
	local key = listControl:GetName() .. "#" .. tostring(entry.typeId)
	local row = probeRows[key]
	if not row then
		local ok, created = pcall(pool.m_Factory, pool)
		if not ok or not created then
			return nil, "row factory failed: " .. tostring(created)
		end
		row = created
		row:SetHidden(true)
		probeRows[key] = row
	end
	local ok, err = pcall(dataType.setupCallback, row, entry.data, listControl)
	if not ok then
		return nil, "row setup failed: " .. tostring(err)
	end
	-- The copy row is hidden, and IsHidden() reports that for every child, so
	-- each child's own flag is read with IsControlHidden() (checked in game:
	-- false for drawn cells, true for an unused marker).
	local cells = {}
	local function Collect(control)
		for index = 1, control:GetNumChildren() do
			local child = control:GetChild(index)
			local controlType = child:GetType()
			if controlType == CT_LABEL then
				local text = child:GetText()
				if text and text ~= "" and not child:IsControlHidden() then
					local r, g, b = child:GetColor()
					cells[#cells + 1] =
					{
						name = ChildSuffix(child, row),
						text = ZO_ColorDef:New(r, g, b):Colorize(text),
						left = child:GetLeft() - row:GetLeft(),
					}
				end
			elseif controlType == CT_TEXTURE then
				-- Rows also hold background strips and markers; the icon is named so.
				if not cells.icon and not child:IsControlHidden() and zo_plainstrfind(ChildSuffix(child, row), "Icon") then
					local texture = child:GetTextureFileName()
					if texture and texture ~= "" then
						cells.icon = texture
					end
				end
			else
				Collect(child)
			end
		end
	end
	Collect(row)
	return cells
end

-- Puts each label in its column: by control name ("Name" under the "Name"
-- header), then by a name that starts the same ("ItemExtended" under "Item"),
-- then by position (Loot Log's count sits under the Item header).
local function MapCells(cells, columns)
	local columnByName = {}
	for index, column in ipairs(columns) do
		columnByName[column.name] = index
	end
	local texts = {}
	for _, cell in ipairs(cells) do
		local index = columnByName[cell.name]
		if not index then
			for columnIndex, column in ipairs(columns) do
				if cell.name:sub(1, #column.name) == column.name then
					index = columnIndex
					break
				end
			end
		end
		if not index then
			index = 1
			for columnIndex, column in ipairs(columns) do
				if column.left <= cell.left + 1 then
					index = columnIndex
				end
			end
		end
		texts[index] = texts[index] and (texts[index] .. " " .. cell.text) or cell.text
	end
	return texts
end

-- Context-menu actions: { label, action } where action is a function.
local function GetRowActions(list, data)
	local actions = {}
	for _, item in ipairs(list.contextMenuItems or {}) do
		local ok, label, action = pcall(item, data)
		if ok then
			if type(action) == "function" and label then
				actions[#actions + 1] = { label = ResolveText(label), action = action }
			elseif type(label) == "table" then
				for _, subItem in ipairs(label) do
					if type(subItem.action) == "function" then
						actions[#actions + 1] = { label = ResolveText(subItem.label), action = subItem.action }
					end
				end
			end
		end
	end
	return actions
end

-- ---------------------------------------------------------------------------
-- A tab as a browser source
-- ---------------------------------------------------------------------------

local browser
local TabSource = {}
TabSource.__index = TabSource

-- One source per tab for the whole session, so each keeps its table.
local sourcesByDescriptor = {}

local function GetTabSource(tab)
	local source = sourcesByDescriptor[tab.descriptor]
	if not source then
		source = setmetatable({ descriptor = tab.descriptor }, TabSource)
		sourcesByDescriptor[tab.descriptor] = source
	end
	source.name = tab.name
	return source
end

-- Shows the tab through the library, which runs its callbacks, then finds its
-- list and refreshes the browser whenever the add-on re-commits it.
function TabSource:Activate()
	if LibExtendedJournal.GetActiveTab() ~= self.descriptor then
		LibExtendedJournal.Show(self.descriptor)
	end
	local tabControl = GetActiveTabControl()
	self.tabControl = tabControl
	self.list = tabControl and tabControl.object
	if self.list and not self.list.kelaBrowserHooked then
		self.list.kelaBrowserHooked = true
		local source = self
		ZO_PostHook(self.list, "CommitScrollList", function()
			if browser then
				browser:RefreshSource(source)
			end
		end)
	end
end

function TabSource:GetColumns()
	if not self.columns then
		self.columns = self.list and CollectColumns(self.list) or {}
	end
	return self.columns
end

function TabSource:GetRows()
	return self.list and ZO_ScrollList_GetDataList(self.list.list) or {}
end

-- The add-on's own row text; when its row setup cannot run, the record's
-- field for each column's sort key (logged once per tab).
function TabSource:GetCellTexts(entry)
	if not self.list then
		return nil
	end
	local cells, reason = ReadRow(self.list.list, entry)
	if cells and #cells > 0 then
		return MapCells(cells, self:GetColumns()), cells.icon
	end
	if not self.readFailureLogged and KelaPadUI.log then
		self.readFailureLogged = true
		KelaPadUI.log:Warn("Extended Journal tab %s: rows read from data fields (%s)", tostring(self.descriptor), tostring(reason or "no labels with text"))
	end
	local data = type(entry.data) == "table" and entry.data or {}
	local texts = {}
	for index, column in ipairs(self:GetColumns()) do
		local value = column.key ~= nil and data[column.key]
		texts[index] = (type(value) == "string" or type(value) == "number") and tostring(value) or ""
	end
	return texts
end

function TabSource:GetSortState()
	if self.list then
		return self.list.currentSortKey, self.list.currentSortOrder
	end
end

-- Sorts through the tab's own header, so the add-on's sort (with its
-- tiebreakers) runs and the keyboard window keeps the same order.
function TabSource:Sort(key, order)
	local headerGroup = self.list and self.list.sortHeaderGroup
	if headerGroup and headerGroup:HeaderForKey(key) then
		local FORCE_RESELECT = true
		headerGroup:SelectHeaderByKey(key, false, FORCE_RESELECT, order)
	end
end

function TabSource:GetFilters()
	return self.tabControl and CollectFilters(self.tabControl) or {}
end

function TabSource:GetActions(entry)
	return self.list and GetRowActions(self.list, entry.data) or {}
end

function TabSource:GetTooltip(entry)
	local data = entry.data or {}
	local link = data.itemLink or data.link
	if type(link) == "string" and link ~= "" then
		-- Collectibles Tracker stores collectible links in `itemLink`.
		if GetLinkType(link) == LINK_TYPE_COLLECTIBLE then
			return "collectible", GetCollectibleIdFromLink(link)
		end
		return "item", link
	end
	local collectibleId = data.collectibleId or data.id
	if type(collectibleId) == "number" and ZO_COLLECTIBLE_DATA_MANAGER then
		local collectibleData = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleId)
		-- A bare `id` is only trusted when it names the same collectible.
		if collectibleData and (data.collectibleId or collectibleData:GetName() == data.name) then
			return "collectible", collectibleId
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Hosting the browser in the library's scene
-- ---------------------------------------------------------------------------

-- Set by the gamepad entry; stays set while the scene is on the stack, so the
-- browser comes back after a scene pushed over it.
local gamepadRequested = false
local keyboardFragments

local function EnterGamepadMode(scene)
	if not browser then
		browser = KelaGamepadBrowser:New("KelaExtendedJournal", scene)
	end
	local frame = GetLibraryFrame()
	local temporary = scene.temporaryFragments or {}
	keyboardFragments = {}
	for _, fragment in ipairs(scene:GetFragments()) do
		if fragment.control ~= frame and not temporary[fragment] then
			keyboardFragments[#keyboardFragments + 1] = fragment
		end
	end
	for _, fragment in ipairs(keyboardFragments) do
		scene:RemoveFragment(fragment)
	end
	for _, fragment in ipairs(browser.fragments) do
		scene:AddFragment(fragment)
	end
	if frame then
		frame:SetAlpha(0)
	end

	local sources, activeIndex = {}, 1
	local activeDescriptor = LibExtendedJournal.GetActiveTab()
	for index, tab in ipairs(GetTabs()) do
		sources[index] = GetTabSource(tab)
		if tab.descriptor == activeDescriptor then
			activeIndex = index
		end
	end
	browser:SetSources(sources, activeIndex)
end

local function LeaveGamepadMode(scene)
	for _, fragment in ipairs(browser.fragments) do
		scene:RemoveFragment(fragment)
	end
	for _, fragment in ipairs(keyboardFragments or {}) do
		scene:AddFragment(fragment)
	end
	keyboardFragments = nil
	local frame = GetLibraryFrame()
	if frame then
		frame:SetAlpha(1)
	end
end

-- The keyboard window has no controller Back button; add one while it shows
-- in gamepad mode.
local nativeBackGroup =
{
	alignment = KEYBIND_STRIP_ALIGN_LEFT,
	{
		name = GetString(SI_GAMEPAD_BACK_OPTION),
		keybind = "UI_SHORTCUT_NEGATIVE",
		callback = function()
			SCENE_MANAGER:HideCurrentScene()
		end,
	},
}
local nativeBackShown = false

local function UpdateNativeBack(newState)
	if newState == SCENE_SHOWN and IsInGamepadPreferredMode() and not nativeBackShown then
		KEYBIND_STRIP:AddKeybindButtonGroup(nativeBackGroup)
		nativeBackShown = true
	elseif newState == SCENE_HIDING and nativeBackShown then
		KEYBIND_STRIP:RemoveKeybindButtonGroup(nativeBackGroup)
		nativeBackShown = false
	end
end

-- Runs before the scene refreshes its fragments, so the keyboard window never
-- flashes before the browser.
local function OnSceneStateChanged(scene, _, newState)
	if scene:GetName() ~= LEJ_SCENE_NAME then
		return
	end
	if newState == SCENE_SHOWING and not keyboardFragments
		and gamepadRequested and IsInGamepadPreferredMode() and KelaIsExtendedJournalAvailable() then
		EnterGamepadMode(scene)
	end
	if keyboardFragments then
		browser:OnSceneStateChanged(newState)
		if newState == SCENE_HIDDEN then
			LeaveGamepadMode(scene)
			gamepadRequested = SCENE_MANAGER:IsSceneOnStack(LEJ_SCENE_NAME)
		end
	else
		UpdateNativeBack(newState)
		if newState == SCENE_HIDDEN then
			gamepadRequested = false
		end
	end
end

function KelaShowExtendedJournal()
	if KelaIsExtendedJournalAvailable() then
		gamepadRequested = true
		LibExtendedJournal.Show()
	end
end

-- ---------------------------------------------------------------------------
-- Journal menu entries
-- ---------------------------------------------------------------------------

local setupDone = false

-- Adds the entry to the end of the gamepad Journal submenu. Existing entries
-- keep their ids; the new one takes the next free id, as the KelaPadUI main
-- menu entry does.
function KelaSetupExtendedJournal()
	if setupDone then
		return
	end
	setupDone = true
	SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
	if not ZO_MENU_MAIN_ENTRIES or not KelaCreateMainMenuEntry then
		return
	end
	for _, mainEntry in ipairs(ZO_MENU_ENTRIES) do
		if mainEntry.id == ZO_MENU_MAIN_ENTRIES.JOURNAL and mainEntry.subMenu then
			local entry = KelaCreateMainMenuEntry(
			{
				name = KelaGetExtendedJournalName,
				icon = JOURNAL_ICON,
				isVisibleCallback = KelaIsExtendedJournalAvailable,
				activatedCallback = KelaShowExtendedJournal,
			})
			entry.id = #mainEntry.subMenu + 1
			table.insert(mainEntry.subMenu, entry)
			return
		end
	end
end
