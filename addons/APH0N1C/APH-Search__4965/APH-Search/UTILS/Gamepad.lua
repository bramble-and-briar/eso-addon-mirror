--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local SS = APHSearchCore

local SKIPPED_MENU_IDS = {
	["APHSearch"] = true,
	LibHarvensAddonSettings = true,
	[ZO_MENU_MAIN_ENTRIES.QUIT] = true,
	[ZO_MENU_MAIN_ENTRIES.LOG_OUT] = true,
}

local ROUTES = {
	GoToKeybinds = "keybindings_gamepad",
}

local CONSOLE_HIDDEN_SCOPES = {
	[SS.SCOPE_KEYBINDS] = true,
	[SS.SCOPE_CROWN] = true,
	[SS.SCOPE_CHAMPION] = true,
}

local CONSOLE_SCOPES = {
	[SS.SCOPE_SET_ITEMS] = true,
	[SS.SCOPE_ACHIEVEMENTS] = true,
	[SS.SCOPE_MAP] = true,
	[SS.SCOPE_WAYSHRINES] = true,
	[SS.SCOPE_DUNGEONS] = true,
	[SS.SCOPE_ARENAS] = true,
	[SS.SCOPE_TRIALS] = true,
	[SS.SCOPE_HOUSES] = true,
	[SS.SCOPE_QUESTS] = true,
	[SS.SCOPE_FRIENDS] = true,
	[SS.SCOPE_PANELS] = true,
	[SS.SCOPE_ADDONS] = true,
}

local SET_WAIT_RETRIES = 30

local function Uncolor(text)
	return (string.gsub(string.gsub(text, "|c%x%x%x%x%x%x", ""), "|r", ""))
end

local function MenuName(entry)
	local name = entry.data.name
	if type(name) == "function" then name = name() end
	return type(name) == "string" and name or nil
end

function SS.GamepadMenuRows()
	local rows = {}
	local function Add(entry, where)
		local data = entry.data
		if not data or SKIPPED_MENU_IDS[entry.id] then return end
		if data.isVisibleCallback and not data.isVisibleCallback() then return end
		local name = MenuName(entry)
		if not name or name == "" then return end

		if entry.subMenu then
			for _, sub in ipairs(entry.subMenu) do Add(sub, name) end
			return
		end
		rows[#rows + 1] = { label = name, detail = where or SS.L("MAIN_MENU"), where = where or SS.L("MAIN_MENU"), menuEntry = entry }
	end
	for _, entry in ipairs(ZO_MENU_ENTRIES) do Add(entry) end
	return rows
end

function SS.OpenGamepadMenuEntry(entry)
	local list = { GetTargetData = function() return entry end, SetActive = function() end }
	MAIN_MENU_GAMEPAD:SwitchToSelectedScene(list)
	return true
end

local function WhereText(row)
	return row.where or row.detail or row.category or SS.L("THAT_SCREEN")
end

local function OpenInstead(scene, row)
	if not SS.SceneExists(scene) then
		SS.Print(string.format(SS.L("CANNOT_BE_OPENED_WITH_A_CONTROLLER"), row.label or "That", WhereText(row)))
		return false
	end
	SCENE_MANAGER:Show(scene)
	SS.Print(string.format(SS.L("LIVES_UNDER"), row.label or "That", WhereText(row)))
	return true
end

local function OnGamepad(name, handler)
	local keyboard = SS[name]
	SS[name] = function(row, ...)
		if IsInGamepadPreferredMode() then return handler(row, ...) end
		return keyboard(row, ...)
	end
end

local function RowLabel(control)
	if not control then return nil end
	local label = control.label or control.titleLabel or control.nameLabel
	if label or not control.GetNamedChild then return label end
	return control:GetNamedChild("Label") or control:GetNamedChild("Name") or control:GetNamedChild("Title")
end
local EntryLabel = RowLabel

local function SceneShown(name)
	local scene = SCENE_MANAGER:GetScene(name)
	return scene ~= nil and scene:GetState() == SCENE_SHOWN
end

local function AfterShown(scene, fn)
	SS.WaitUntil(function() return SceneShown(scene) end, fn, SET_WAIT_RETRIES)
end

local function SourceOf(data)
	if type(data) ~= "table" then return nil end
	if data.GetDataSource then return data:GetDataSource() end
	return data.dataSource or data
end

local function FlashTarget(list, matches, label_of)
	local function Find()
		local data = list:GetTargetData()
		if data and matches(data) then return list:GetTargetControl() end
		return nil
	end
	SS.WhenSettled(Find, function() SS.FlashAndFollow(Find, label_of or RowLabel) end)
	return true
end

local function IndexIn(list, matches)
	for index = 1, list:GetNumEntries() do
		local data = list:GetEntryData(index)
		if data and matches(data) then return index end
	end
	return nil
end

local function SelectInList(list, matches, label_of)
	local index = IndexIn(list, matches)
	if not index then return false end
	list:SetSelectedIndexWithoutAnimation(index)
	return FlashTarget(list, matches, label_of)
end

local function SelectWhenListed(list_of, matches, label_of, missing)
	SS.WaitUntil(function()
		local list = list_of()
		return list ~= nil and IndexIn(list, matches) ~= nil
	end, function() SelectInList(list_of(), matches, label_of) end, SET_WAIT_RETRIES)
	if missing then
		zo_callLater(function()
			local list = list_of()
			if not list or not IndexIn(list, matches) then missing() end
		end, SET_WAIT_RETRIES * 200)
	end
end

local function ScrollEntry(list, matches)
	for _, entry in ipairs(list and ZO_ScrollList_GetDataList(list) or {}) do
		if entry.data and matches(entry.data) then return entry.data end
	end
	return nil
end

local function ScrollControl(list, matches)
	for _, control in pairs(list and list.activeControls or {}) do
		local data = control.dataEntry and control.dataEntry.data
		if data and matches(data) then return control end
	end
	return nil
end

local function FlashScrollRow(list, matches, label_of)
	local function Find() return ScrollControl(list, matches) end
	SS.WhenSettled(Find, function() SS.FlashAndFollow(Find, label_of or RowLabel) end)
end

local function Named(child)
	return function(control) return control.GetNamedChild and control:GetNamedChild(child) or nil end
end

for name, scene in pairs(ROUTES) do
	OnGamepad(name, function(row) return OpenInstead(scene, row or {}) end)
end

function SS.IsConsoleScope(scope)
	return scope == nil or scope == SS.SCOPE_ALL or CONSOLE_SCOPES[scope] == true
end

function SS.DefaultScopeOn(scope)
	if IsConsoleUI() then return CONSOLE_SCOPES[scope] == true end
	return not SS.DEFAULTS.scopes_off[scope]
end

local scope_enabled = SS.IsScopeEnabled
SS.IsScopeEnabled = function(scope)
	if not IsConsoleUI() then return scope_enabled(scope) end
	if scope == nil or scope == SS.SCOPE_ALL then return true end
	local chosen = SS.saved and SS.saved.console_scopes and SS.saved.console_scopes[scope]
	if chosen ~= nil then return chosen end
	return CONSOLE_SCOPES[scope] == true
end

local set_scope = SS.SetScopeEnabled
SS.SetScopeEnabled = function(scope, enabled)
	if not IsConsoleUI() then return set_scope(scope, enabled) end
	if scope == nil or scope == SS.SCOPE_ALL or not SS.saved then return false end
	SS.saved.console_scopes = SS.saved.console_scopes or {}
	SS.saved.console_scopes[scope] = enabled == true
	if not enabled then SS.ClearIndex(scope) end
	return true
end

OnGamepad("GoToAddons", function(row)
	if not row or not SS.SceneExists("gamepad_addons") then return false end
	SCENE_MANAGER:Push("gamepad_addons")
	SS.WaitUntil(function()
		return SCENE_MANAGER:IsShowing("gamepad_addons") and #ZO_ScrollList_GetDataList(ADDON_MANAGER_GAMEPAD.list) > 0
	end, function()
		local manager = ADDON_MANAGER_GAMEPAD
		for _, entry in ipairs(ZO_ScrollList_GetDataList(manager.list)) do
			if entry.data and entry.data.addOnIndex == row.addonIndex then
				if not manager:IsActivated() then manager:Activate(true) end
				ZO_ScrollList_SelectDataAndScrollIntoView(manager.list, entry.data, nil, true)
				FlashScrollRow(manager.list, function(data) return data.addOnIndex == row.addonIndex end, Named("AddonName"))
				return
			end
		end
	end)
	return true
end)

function SS.ConsolePanelRows()
	local rows = {}
	local lhas = LibHarvensAddonSettings
	if not lhas then return rows end
	for _, addon in ipairs(lhas.addons) do
		rows[#rows + 1] = { label = addon.name, detail = "", where = "Add-Ons", lhasAddon = addon }
		local section
		for _, setting in ipairs(addon.settings) do
			local text = setting.labelText
			if type(text) == "function" then text = text(setting) end
			if type(text) == "number" then text = GetString(text) end
			if type(text) == "string" and text ~= "" then
				text = Uncolor(text)
				if setting.type == lhas.ST_SECTION then
					section = text
				elseif setting.type ~= lhas.ST_LABEL then
					rows[#rows + 1] = {
						label = text,
						detail = "",
						where = section and (addon.name .. ", " .. section) or addon.name,
						lhasAddon = addon,
					}
				end
			end
		end
	end
	return rows
end

local function FindLhasMenuEntry(addon)
	for _, entry in ipairs(ZO_MENU_ENTRIES) do
		if entry.id == "LibHarvensAddonSettings" then
			for _, sub in ipairs(entry.subMenu or {}) do
				if sub.data and sub.data.addon == addon then return sub end
			end
		end
	end
	return nil
end

OnGamepad("GoToPanelControl", function(row)
	local entry = row and row.lhasAddon and FindLhasMenuEntry(row.lhasAddon)
	if not entry then
		SS.Print(string.format(SS.L("IS_ONLY_REACHABLE_FROM_THE_KEYBOARD"), (row and row.label) or "That"))
		return false
	end
	SS.OpenGamepadMenuEntry(entry)
	if row.label ~= row.lhasAddon.name then SS.Print(string.format(SS.L("LIVES_UNDER"), row.label, row.where)) end
	return true
end)

OnGamepad("GoToAchievement", function(row)
	if not row or not row.achievementId then return false end
	local id = row.achievementId
	ACHIEVEMENTS_GAMEPAD:ShowAchievement(id)
	SS.WaitUntil(function() return SceneShown("achievementsGamepad") end, function()
		if ACHIEVEMENTS_GAMEPAD.achievementId ~= id then ACHIEVEMENTS_GAMEPAD:ShowAchievement(id) end
		local list = ACHIEVEMENTS_GAMEPAD.itemList
		local function Find()
			local data = list:GetTargetData()
			if data and data.achievementId == id then return list:GetTargetControl() end
			return nil
		end
		SS.WhenSettled(Find, function() SS.FlashAndFollow(Find, EntryLabel) end)
	end, SET_WAIT_RETRIES)
	return true
end)

local function IndexOfCategory(list, category)
	local id = category:GetId()
	for index = 1, list:GetNumEntries() do
		local entry = list:GetEntryData(index)
		local source = entry and (entry.GetDataSource and entry:GetDataSource() or entry.dataSource)
		if source and source.GetId and source:GetId() == id then return index end
	end
	return nil
end

function SS.OpenSetCategory(book, category)
	local parent = category:GetParentCategoryData()
	local top = parent or category
	local list = book.categoryListDescriptor.list
	local top_index = IndexOfCategory(list, top)
	if not top_index then return false end
	book:ShowListDescriptor(book.categoryListDescriptor)
	list:SetSelectedIndexWithoutAnimation(top_index)
	if not parent then return true end

	book:BuildSubcategoryList(top)
	local sub_list = book.subcategoryListDescriptor.list
	local sub_index = IndexOfCategory(sub_list, category)
	if not sub_index then return false end
	book:ShowListDescriptor(book.subcategoryListDescriptor)
	sub_list:SetSelectedIndexWithoutAnimation(sub_index)
	return true
end

local function FindSetPiece(book, setId)
	for _, entry in ipairs(book.gridListPanelList:GetData()) do
		local header = entry.data and entry.data.gridHeaderData
		if header and header.GetId and header:GetId() == setId then return entry.data end
	end
	return nil
end

local function VisibleSetHeader(book, setId)
	local list = book.gridListPanelList and book.gridListPanelList.list
	for _, control in pairs(list and list.activeControls or {}) do
		local header = control.dataEntry and control.dataEntry.data and control.dataEntry.data.header
		if header and header.GetId and header:GetId() == setId then return control end
	end
	return nil
end

local function SetHeaderLabel(control)
	return control.nameLabel or (control.GetNamedChild and control:GetNamedChild("Name")) or nil
end

OnGamepad("GoToItemSet", function(row)
	local setData = row and row.itemSetId and ITEM_SET_COLLECTIONS_DATA_MANAGER:GetItemSetCollectionData(row.itemSetId)
	if not setData then return false end
	local book = GAMEPAD_ITEM_SETS_BOOK
	local scene = book:GetSceneName()
	SCENE_MANAGER:Show(scene)
	SS.WaitUntil(function() return SceneShown(scene) and book.categoryListDescriptor.list:GetNumEntries() > 0 end, function()
		if not SS.OpenSetCategory(book, setData:GetCategoryData()) then
			SS.Print(string.format(SS.L("IS_UNDER_COLLECTIONS"), row.label, row.where))
			return
		end
		SS.WaitUntil(function() return FindSetPiece(book, row.itemSetId) ~= nil end, function()
			book:EnterGridList()
			book.gridListPanelList:ScrollDataToCenter(FindSetPiece(book, row.itemSetId))
			local function Find() return VisibleSetHeader(book, row.itemSetId) end
			SS.WhenSettled(Find, function() SS.FlashAndFollow(Find, SetHeaderLabel) end)
		end, SET_WAIT_RETRIES)
	end, SET_WAIT_RETRIES)
	return true
end)

OnGamepad("GoToScene", function(row)
	if row and row.menuEntry then return SS.OpenGamepadMenuEntry(row.menuEntry) end
	SS.Print(string.format(SS.L("CANNOT_BE_OPENED_WITH_A_CONTROLLER_2"), (row and row.label) or "That"))
	return false
end)

OnGamepad("ShowAntiquity", function(row)
	local data = row and row.antiquityId and ANTIQUITY_DATA_MANAGER:GetAntiquityData(row.antiquityId)
	if not data then return false end
	local set = data:GetAntiquitySetData()
	local function Matches(entry)
		local source = SourceOf(entry)
		return source == data or (set ~= nil and source == set)
	end
	MAIN_MENU_GAMEPAD:ShowAntiquityInJournal(data)
	AfterShown("gamepad_antiquity_journal", function()
		local list = ANTIQUITY_JOURNAL_LIST_GAMEPAD.list
		SS.WaitUntil(function() return ScrollEntry(list, Matches) ~= nil end, function()
			local entry = ScrollEntry(list, Matches)
			if ZO_ScrollList_GetSelectedData(list) ~= entry then ZO_ScrollList_SelectDataAndScrollIntoView(list, entry) end
			FlashScrollRow(list, function(candidate) return candidate == entry end)
		end, SET_WAIT_RETRIES)
	end)
	return true
end)

OnGamepad("BrowseToSkillLine", function(row)
	local line = row and row.skillLineData
	if not line then return false end
	SCENE_MANAGER:Show("gamepad_skills_root")
	AfterShown("gamepad_skills_root", function()
		SelectWhenListed(function() return GAMEPAD_SKILLS.categoryList end, function(data) return data.skillLineData == line end)
	end)
	return true
end)

OnGamepad("BrowseToSkill", function(row)
	local skill = row and row.skillData
	if not skill then return false end
	local function Matches(data) return data.skillData == skill end
	SCENE_MANAGER:Show("gamepad_skills_root")
	AfterShown("gamepad_skills_root", function()
		GAMEPAD_SKILLS:SelectSkillLineBySkillData(skill)
		local line = skill:GetSkillLineData()
		if line and not line:IsAvailable() then
			SelectWhenListed(function() return GAMEPAD_SKILLS.categoryList end, function(data) return data.skillLineData == line end)
			return
		end
		AfterShown("gamepad_skills_line_filter", function()
			SelectWhenListed(function() return GAMEPAD_SKILLS.lineFilterList end, Matches)
		end)
	end)
	return true
end)

local function CollectionsMatch(id)
	return function(data)
		local source = SourceOf(data)
		return source ~= nil and type(source.GetId) == "function" and source:GetId() == id
			and (type(source.IsInstanceOf) ~= "function" or source:IsInstanceOf(ZO_CollectibleData))
	end
end

local function PatronFor(collectibleId)
	if not TRIBUTE_DATA_MANAGER or not GAMEPAD_TRIBUTE_PATRON_BOOK then return nil end
	for _, patron in TRIBUTE_DATA_MANAGER:TributePatronIterator() do
		if patron:GetPatronCollectibleId() == collectibleId then return patron end
	end
	return nil
end

local function BrowseToPatron(patron)
	local book = GAMEPAD_TRIBUTE_PATRON_BOOK
	book:BrowseToPatron(patron:GetId())
	AfterShown(book:GetSceneName(), function()
		SelectWhenListed(function() return book.patronListDescriptor.list end, function(data)
			return SourceOf(data) == patron or data.patronId == patron:GetId()
		end)
	end)
	return true
end

local function OutfitEntry(book, collectible)
	for _, entry in ipairs(book.gridListPanelList:GetData()) do
		local source = entry.data and SourceOf(entry.data)
		if source and type(source.GetId) == "function" and source:GetId() == collectible:GetId() then return entry.data end
	end
	return nil
end

local function BrowseToOutfitStyle(collectible)
	if collectible:IsLocked() and ZO_OUTFIT_MANAGER and not ZO_OUTFIT_MANAGER:GetShowLocked() then
		ZO_OUTFIT_MANAGER:SetShowLocked(true)
	end
	local book = GAMEPAD_COLLECTIONS_BOOK
	COLLECTIONS_BOOK_SINGLETON:BrowseToCollectible(collectible:GetId())
	AfterShown("gamepadCollectionsBook", function()
		SS.WaitUntil(function() return OutfitEntry(book, collectible) ~= nil end, function()
			local target = OutfitEntry(book, collectible)
			book:EnterGridList()
			book.gridListPanelList:ScrollDataToCenter(target)
			FlashScrollRow(book.gridListPanelList.list, function(data) return data == target end, Named("Icon"))
		end, SET_WAIT_RETRIES)
	end)
	return true
end

OnGamepad("BrowseToCollectible", function(row)
	local collectible = row and row.collectibleId and ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(row.collectibleId)
	if not collectible then return false end
	local patron = PatronFor(row.collectibleId)
	if patron then return BrowseToPatron(patron) end
	local category = collectible:GetCategoryData()
	if category and category:IsSpecializedCategory(COLLECTIBLE_CATEGORY_SPECIALIZATION_OUTFIT_STYLES) then
		return BrowseToOutfitStyle(collectible)
	end
	COLLECTIONS_BOOK_SINGLETON:BrowseToCollectible(row.collectibleId)
	AfterShown("gamepadCollectionsBook", function()
		SelectWhenListed(function() return GAMEPAD_COLLECTIONS_BOOK.collectionList.list end, CollectionsMatch(row.collectibleId))
	end)
	return true
end)

OnGamepad("GoToHelp", function(row)
	if not row or not row.helpCategory or not row.helpIndex then return false end
	HELP_TUTORIALS_ENTRIES_GAMEPAD:Show(row.helpCategory, row.helpIndex)
	AfterShown("helpTutorialsEntriesGamepad", function()
		SelectWhenListed(function() return HELP_TUTORIALS_ENTRIES_GAMEPAD.itemList end, function(data)
			return data.helpIndex == row.helpIndex
		end)
	end)
	return true
end)

local HELP_ROOT_ROWS = {
	{ text = SI_GAMEPAD_HELP_CUSTOMER_SERVICE },
	{ text = SI_GAMEPAD_HELP_GET_ME_UNSTUCK },
	{ text = SI_HELP_TUTORIALS },
	{ text = SI_GAMEPAD_HELP_LEGAL_MENU },
	{ text = SI_CUSTOMER_SERVICE_SUBMIT_FEEDBACK, shown = function() return IsSubmitFeedbackSupported() end },
	{ text = SI_CUSTOMER_SERVICE_QUEST_ASSISTANCE },
	{ text = SI_CUSTOMER_SERVICE_ITEM_ASSISTANCE },
}

function SS.GamepadHelpRows(rows)
	for _, entry in ipairs(HELP_ROOT_ROWS) do
		if not entry.shown or entry.shown() then
			local label = GetString(entry.text)
			rows[#rows + 1] = {
				label = label,
				tier = 1,
				where = "Help",
				helpRootText = label,
				go = function(found) return SS.GoToHelpRoot(found) end,
			}
		end
	end
	return rows
end

function SS.GoToHelpRoot(row)
	if not row or not row.helpRootText then return false end
	SCENE_MANAGER:Show("helpRootGamepad")
	AfterShown("helpRootGamepad", function()
		SelectWhenListed(function() return HELP_ROOT_GAMEPAD:GetMainList() end, function(data)
			return data.text == row.helpRootText
		end)
	end)
	return true
end

local INVENTORY_SCENE = "gamepad_inventory_root"

local function TabIndex(inventory, text)
	for index, tab in ipairs(inventory:GetTabBarEntries()) do
		if tab.text == text then return index end
	end
	return nil
end

local function InventoryCategoryFor(inventory, item)
	local list = inventory.categoryList
	for index = 1, list:GetNumEntries() do
		local data = list:GetEntryData(index)
		local plain = data and not data.data and not data.isCurrencyEntry and not data.isBagSpaceEntry
			and data.filterType ~= ITEMFILTERTYPE_QUEST
		if plain and inventory:GetItemDataFilterComparator(data.equipSlot, data.filterType)(item) then return index end
	end
	return nil
end

OnGamepad("ShowInventoryItem", function(row)
	if not row or not row.bagId or not row.slotIndex then return false end
	local function Matches(data) return data.bagId == row.bagId and data.slotIndex == row.slotIndex end
	SCENE_MANAGER:Show(INVENTORY_SCENE)
	AfterShown(INVENTORY_SCENE, function()
		local inventory = GAMEPAD_INVENTORY
		if row.bagId == BAG_VIRTUAL then
			ZO_GamepadGenericHeader_SetActiveTabIndex(inventory.header, TabIndex(inventory, GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER)))
			SelectWhenListed(function() return inventory.craftBagList:GetParametricList() end, Matches)
			return
		end
		ZO_GamepadGenericHeader_SetActiveTabIndex(inventory.header, TabIndex(inventory, GetString(SI_GAMEPAD_INVENTORY_CATEGORY_HEADER)))
		local item = SHARED_INVENTORY:GenerateSingleSlotData(row.bagId, row.slotIndex)
		SS.WaitUntil(function() return item ~= nil and InventoryCategoryFor(inventory, item) ~= nil end, function()
			inventory.categoryList:SetSelectedIndexWithoutAnimation(InventoryCategoryFor(inventory, item))
			inventory:Select()
			SelectWhenListed(function() return inventory.itemList end, Matches)
		end, SET_WAIT_RETRIES)
	end)
	return true
end)

function SS.GamepadLeaderboardRows()
	local rows = {}
	local boards = GAMEPAD_LEADERBOARDS
	if not boards then return rows end
	if #boards.categoryListData == 0 then boards:UpdateCategories() end
	for _, data in ipairs(boards.categoryListData) do
		local name = type(data.titleName) == "string" and data.titleName or data.name
		local group = type(data.group) == "string" and data.group or nil
		if type(name) == "string" and name ~= "" then
			rows[#rows + 1] = {
				label = name,
				detail = group or "",
				where = group and (SS.L("LEADERBOARD") .. group) or "Leaderboard",
				leaderboardName = data.name,
				leaderboardGroup = data.group,
			}
		end
	end
	return rows
end

OnGamepad("GoToLeaderboard", function(row)
	if not row or not row.leaderboardName then return false end
	SCENE_MANAGER:Show("gamepad_leaderboards")
	AfterShown("gamepad_leaderboards", function()
		SelectWhenListed(function() return GAMEPAD_LEADERBOARDS.categoryList end, function(data)
			return data.name == row.leaderboardName and data.group == row.leaderboardGroup
		end)
	end)
	return true
end)

function SS.GamepadSettingsRows()
	local rows = {}
	local options, by_panel, shared = GAMEPAD_OPTIONS, GAMEPAD_SETTINGS_DATA, ZO_SharedOptions_SettingsData
	if not options or type(by_panel) ~= "table" or type(shared) ~= "table" then return rows end
	for panelId, settings in pairs(by_panel) do
		local reachable = panelId ~= SETTING_PANEL_ACCOUNT or ZO_OptionsPanel_IsAccountManagementAvailable()
		if type(panelId) == "number" and reachable then
			local panel_name = GetString("SI_SETTINGSYSTEMPANEL", panelId)
			for _, setting in ipairs(settings) do
				local systems = shared[setting.panel]
				local data = systems and systems[setting.system] and systems[setting.system][setting.settingId]
				local shown = data ~= nil and options:DoesSettingExist(data)
				if shown and type(data.visible) == "function" then shown = data.visible() end
				if shown and data.visible ~= false then
					local label = SS.ResolveText(data.gamepadTextOverride or data.text)
					if label and label ~= "" then
						rows[#rows + 1] = {
							label = Uncolor(label),
							detail = Uncolor(SS.ResolveText(data.gamepadTooltipText or data.tooltipText) or ""),
							where = panel_name,
							panel = setting.panel,
							system = setting.system,
							settingId = setting.settingId,
						}
					end
				end
			end
		end
	end
	return rows
end

OnGamepad("GoToSetting", function(row)
	if not row or not row.panel then return false end
	local function Matches(data) return data.system == row.system and data.settingId == row.settingId end
	SCENE_MANAGER:Show("gamepad_options_root")
	AfterShown("gamepad_options_root", function()
		GAMEPAD_OPTIONS:SetCategory(row.panel)
		SCENE_MANAGER:Push("gamepad_options_panel")
		AfterShown("gamepad_options_panel", function()
			SelectWhenListed(function() return GAMEPAD_OPTIONS.optionsList end, Matches, Named("Name"))
		end)
	end)
	return true
end)

local friend_keyboard = SS.GoToFriend
SS.GoToFriend = function(row, ...)
	if not (IsInGamepadPreferredMode() and row and not row.friendAction) then return friend_keyboard(row, ...) end
	if not IsConsoleUI() then return OpenInstead("gamepad_friends", row) end

	local name = row.friendName
	local choices = {}
	local function Offer(text, action)
		choices[#choices + 1] = { text = text, callback = function() friend_keyboard({ friendName = name, friendAction = action }) end }
	end
	if string.find(row.where or "", "online", 1, true) then
		if IsChatSystemAvailableForCurrentPlatform() then Offer("Whisper", "whisper") end
		if not IsPlayerInGroup(name) then Offer(SS.L("INVITE_TO_GROUP_2"), "invite") end
		Offer(SS.L("TRAVEL_TO_THEM"), "jump")
	end
	if #choices == 0 then
		SS.Print(string.format(SS.L("IS_OFFLINE_YOUR_FRIENDS_LIST_IS"), ZO_FormatUserFacingDisplayName(name)))
		return true
	end
	LibAPH.ShowGamepadPicker({ title = ZO_FormatUserFacingDisplayName(name), choices = choices })
	return true
end

local TRIGGER_NAMESPACE = SS.name .. "Trigger"
local TRIGGER_POLL_MS = 100
local TRIGGER_HOLD_MS = 1000
local TRIGGER_DOWN = 0.9
local trigger_held_ms, trigger_fired = 0, false

local function TriggerReady()
	return SS.saved and SS.saved.hold_trigger_search and IsInGamepadPreferredMode()
		and not IsUnitInCombat("player") and not IsUnitDead("player")
		and SCENE_MANAGER:IsShowingBaseScene() and not ZO_Dialogs_IsShowingDialog()
end

function SS.PollTrigger()
	if GetGamepadLeftTriggerMagnitude() < TRIGGER_DOWN then
		trigger_held_ms, trigger_fired = 0, false
		return false
	end
	if trigger_fired or not TriggerReady() then
		trigger_held_ms = 0
		return false
	end
	trigger_held_ms = trigger_held_ms + TRIGGER_POLL_MS
	if trigger_held_ms < TRIGGER_HOLD_MS then return false end
	trigger_fired = true
	SS.ShowBar()
	return true
end

function SS.WatchTrigger()
	EVENT_MANAGER:UnregisterForUpdate(TRIGGER_NAMESPACE)
	trigger_held_ms, trigger_fired = 0, false
	if not IsInGamepadPreferredMode() or IsUnitInCombat("player") then return false end
	EVENT_MANAGER:RegisterForUpdate(TRIGGER_NAMESPACE, TRIGGER_POLL_MS, SS.PollTrigger)
	return true
end

EVENT_MANAGER:RegisterForEvent(TRIGGER_NAMESPACE, EVENT_PLAYER_COMBAT_STATE, function() SS.WatchTrigger() end)

local RELEASE_AFTER_MS = 120000
local RELEASE_NAMESPACE = SS.name .. "Release"

local function ReleaseLater()
	EVENT_MANAGER:UnregisterForUpdate(RELEASE_NAMESPACE)
	EVENT_MANAGER:RegisterForUpdate(RELEASE_NAMESPACE, RELEASE_AFTER_MS, function()
		EVENT_MANAGER:UnregisterForUpdate(RELEASE_NAMESPACE)
		SS.ClearIndex()
		LibAPH.StepCleanup(1)
	end)
end

local prebuild = SS.StartPrebuild
SS.StartPrebuild = function(...)
	if not SS.search_opened then return false end
	return prebuild(...)
end

local search = SS.Search
SS.Search = function(...)
	if IsConsoleUI() then ReleaseLater() end
	return search(...)
end

local search_async = SS.SearchAsync
SS.SearchAsync = function(...)
	if IsConsoleUI() then ReleaseLater() end
	return search_async(...)
end

local go_to = SS.GoTo
SS.GoTo = function(...)
	local result = go_to(...)
	if IsConsoleUI() then
		SS.ClearIndex()
		LibAPH.StepCleanup(1)
	end
	return result
end

function SS.ApplyConsoleScopes()
	SS.INDEX_BUDGET_ALL_KB = SS.INDEX_BUDGET_KB
	local providers = SS.GetProviders()
	for index = #providers, 1, -1 do
		if CONSOLE_HIDDEN_SCOPES[providers[index].scope] then table.remove(providers, index) end
	end
	local groups = SS.GetScopeGroups
	SS.GetScopeGroups = function()
		local kept = {}
		for _, group in ipairs(groups()) do
			local scopes = {}
			for _, scope in ipairs(group.scopes or {}) do
				if not CONSOLE_HIDDEN_SCOPES[scope] then scopes[#scopes + 1] = scope end
			end
			kept[#kept + 1] = { title = group.title, scopes = scopes }
		end
		return kept
	end
end

if IsConsoleUI() then SS.ApplyConsoleScopes() end

function SS.OnSearchOpened()
	local first = not SS.search_opened
	SS.search_opened = true
	if IsConsoleUI() then
		SS.StartPrebuild()
		ReleaseLater()
	elseif first then
		SS.StartPrebuild()
	end
end

EVENT_MANAGER:RegisterForEvent(SS.name .. "Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
	for _, scope in ipairs({ SS.SCOPE_MENUS, SS.SCOPE_SETTINGS, SS.SCOPE_HELP, SS.SCOPE_LEADERBOARDS }) do SS.ClearIndex(scope) end
	SS.WatchTrigger()
end)
