--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
local GetAuthorFilterEntries, GetCategoryFilterGroups, PopulateCategoryFilterCombos, RefreshCategoryManagerWindow
local RegisterCategoryFilterCombo
local LibAPH = LibAPH
local SuggestedCategories = AoM.SuggestedCategories
local ConsoleSuggestedCategories = AoM.ConsoleSuggestedCategories or {}
local KnownConsoleLibraries = AoM.KnownConsoleLibraries or {}

local UNCATEGORIZED = "Uncategorized"
local LIBRARIES = "Libraries"

local function IsLibraryAddon(am, index)
	local name, _, _, _, _, _, _, isLibrary = am:GetAddOnInfo(index)
	if isLibrary or string.sub(name, 1, 3) == "Lib" then return true end
	return IsConsoleUI() and KnownConsoleLibraries[name] ~= nil
end

local function TrimName(name)
	if type(name) ~= "string" then return name end
	return (string.gsub(name, "^%s*(.-)%s*$", "%1"))
end

local DEFAULT_CATEGORY_NAMES = { [LIBRARIES] = true, [UNCATEGORIZED] = true }
for _, category in pairs(SuggestedCategories or {}) do
	DEFAULT_CATEGORY_NAMES[TrimName(category)] = true
end

local function IsDefaultCategory(name)
	return DEFAULT_CATEGORY_NAMES[name] == true
end
AoM.IsDefaultCategory = IsDefaultCategory

local function EnsureSavedTables()
	if not AoM.saved then return false end
	AoM.saved.categories = AoM.saved.categories or {}
	AoM.saved.addon_category_assignment = AoM.saved.addon_category_assignment or {}
	return true
end

local function EnsureDisplayNameTable()
	if not AoM.saved then return false end
	AoM.saved.default_category_display_names = AoM.saved.default_category_display_names or {}
	return true
end

function AoM.GetCategoryDisplayName(name)
	if IsDefaultCategory(name) and EnsureDisplayNameTable() then
		return AoM.saved.default_category_display_names[name] or name
	end
	return name
end

local function IsCategoryDisplayNameTaken(displayName, excludeInternalName)
	for _, internal in ipairs(AoM.GetAllCategories()) do
		if internal ~= excludeInternalName and AoM.GetCategoryDisplayName(internal) == displayName then
			return true
		end
	end
	return false
end

function AoM.GetAllCategories()
	local list = { LIBRARIES }
	if EnsureSavedTables() then
		for _, name in ipairs(AoM.saved.categories) do
			table.insert(list, name)
		end
	end
	table.insert(list, UNCATEGORIZED)
	return list
end

local function CreateCategory(name)
	EnsureSavedTables()
	name = TrimName(name)
	if not name or name == "" then return false, "empty" end
	if IsDefaultCategory(name) then return false, "reserved" end
	for _, existing in ipairs(AoM.saved.categories) do
		if existing == name then return false, "duplicate" end
	end
	table.insert(AoM.saved.categories, name)
	if AoM.NoteSavedVariablesChanged then AoM.NoteSavedVariablesChanged() end
	return true
end

local function RenameCategory(oldName, newName)
	EnsureSavedTables()
	newName = TrimName(newName)
	if not newName or newName == "" then return false, "invalid" end

	if IsDefaultCategory(oldName) then
		if IsCategoryDisplayNameTaken(newName, oldName) then return false, "duplicate" end
		EnsureDisplayNameTable()
		AoM.saved.default_category_display_names[oldName] = newName
		return true
	end

	if IsDefaultCategory(newName) then return false, "invalid" end
	local found
	for i, existing in ipairs(AoM.saved.categories) do
		if existing == oldName then found = i end
		if existing == newName then return false, "duplicate" end
	end
	if not found then return false, "notfound" end
	if IsCategoryDisplayNameTaken(newName, oldName) then return false, "duplicate" end
	AoM.saved.categories[found] = newName
	for addonName, cat in pairs(AoM.saved.addon_category_assignment) do
		if cat == oldName then AoM.saved.addon_category_assignment[addonName] = newName end
	end
	return true
end

local function DeleteCategory(name)
	EnsureSavedTables()
	if IsDefaultCategory(name) then return false, "reserved" end
	local found
	for i, existing in ipairs(AoM.saved.categories) do
		if existing == name then found = i end
	end
	if not found then return false, "notfound" end
	table.remove(AoM.saved.categories, found)
	for addonName, cat in pairs(AoM.saved.addon_category_assignment) do
		if cat == name then AoM.saved.addon_category_assignment[addonName] = nil end
	end
	if AoM.NoteSavedVariablesChanged then AoM.NoteSavedVariablesChanged() end
	return true
end

function AoM.AssignAddonToCategory(addonName, categoryName)
	EnsureSavedTables()
	if categoryName == nil then
		AoM.saved.addon_category_assignment[addonName] = nil
		if AoM.NoteSavedVariablesChanged then AoM.NoteSavedVariablesChanged() end
		return true
	end
	if categoryName ~= LIBRARIES and categoryName ~= UNCATEGORIZED then
		local exists = false
		for _, existing in ipairs(AoM.saved.categories) do
			if existing == categoryName then exists = true; break end
		end
		if not exists then return false, "notfound" end
	end
	AoM.saved.addon_category_assignment[addonName] = categoryName
	if AoM.NoteSavedVariablesChanged then AoM.NoteSavedVariablesChanged() end
	return true
end

function AoM.GetAddonCategory(addonName)
	local assigned = EnsureSavedTables() and AoM.saved.addon_category_assignment[addonName]
	if assigned then return assigned end

	local suggested
	if AoM.GetDataPlatform(addonName) == "console" then
		suggested = ConsoleSuggestedCategories[addonName]
	end
	suggested = suggested or (SuggestedCategories and SuggestedCategories[addonName])
	if suggested then return suggested end

	local am = GetAddOnManager()
	for i = 1, am:GetNumAddOns() do
		local name = am:GetAddOnInfo(i)
		if name == addonName then
			if IsLibraryAddon(am, i) then return LIBRARIES end
			break
		end
	end
	return UNCATEGORIZED
end

function AoM.GetAddonCounts()
	local am = GetAddOnManager()
	local addons_on, addons_total, libs_on, libs_total = 0, 0, 0, 0
	for i = 1, am:GetNumAddOns() do
		local enabled = select(5, am:GetAddOnInfo(i))
		if IsLibraryAddon(am, i) then
			libs_total = libs_total + 1
			if enabled then libs_on = libs_on + 1 end
		else
			addons_total = addons_total + 1
			if enabled then addons_on = addons_on + 1 end
		end
	end
	return addons_on, addons_total, libs_on, libs_total
end

function AoM.GetAddonCountLines()
	local addons_on, addons_total, libs_on, libs_total = AoM.GetAddonCounts()
	return string.format(AoM.L("ADD_ONS"), addons_on, addons_total),
		string.format(AoM.L("LIBRARIES"), libs_on, libs_total)
end


function AoM.GetAddonCountText()
	local addons_line, libraries_line = AoM.GetAddonCountLines()
	local text = addons_line .. "   " .. libraries_line
	local save_size_line = AoM.GetSaveSizeLine()
	if save_size_line then text = text .. "   " .. save_size_line end
	return text
end

function AoM.GetAddonsInCategory(categoryName)
	EnsureSavedTables()
	local am = GetAddOnManager()
	local list = {}
	for i = 1, am:GetNumAddOns() do
		local name = am:GetAddOnInfo(i)
		if AoM.GetAddonCategory(name) == categoryName then
			table.insert(list, name)
		end
	end
	table.sort(list)
	return list
end

local function ResetAddonCategoryAssignments()
	if not EnsureSavedTables() then return end
	AoM.saved.addon_category_assignment = {}
end

local function ResetCategories()
	if not EnsureSavedTables() then return 0 end
	local removed = 0
	for i = #AoM.saved.categories, 1, -1 do
		local name = AoM.saved.categories[i]
		if not IsDefaultCategory(name) then
			DeleteCategory(name)
			removed = removed + 1
		end
	end
	return removed
end

local function GetInstalledAddonNames()
	local am = GetAddOnManager()
	local installed = {}
	for i = 1, am:GetNumAddOns() do
		installed[am:GetAddOnInfo(i)] = true
	end
	return installed
end

function AoM.PruneUninstalledCategoryAssignments()
	if not EnsureSavedTables() then return 0 end
	local installed = GetInstalledAddonNames()
	local removed = 0
	for addonName in pairs(AoM.saved.addon_category_assignment) do
		if not installed[addonName] then
			AoM.saved.addon_category_assignment[addonName] = nil
			removed = removed + 1
		end
	end
	return removed
end

function AoM.ApplySuggestedCategories(suggestions, overwriteExisting)
	EnsureSavedTables()
	local installed = GetInstalledAddonNames()
	local applied = 0
	for addonName, categoryName in pairs(suggestions) do
		if installed[addonName] and (overwriteExisting or AoM.saved.addon_category_assignment[addonName] == nil) then
			if categoryName ~= LIBRARIES and categoryName ~= UNCATEGORIZED then
				local exists = false
				for _, existing in ipairs(AoM.saved.categories) do
					if existing == categoryName then exists = true; break end
				end
				if not exists then table.insert(AoM.saved.categories, categoryName) end
			end
			AoM.saved.addon_category_assignment[addonName] = categoryName
			applied = applied + 1
		end
	end
	return applied
end

local category_window
local RefreshCategoryWindow

local function GetCategoryManagerWindow()
	if category_window then return category_window end
	category_window = LibAPH.CreateScrollListWindow({
		name = "AoM_CategoryManagerWindow",
		widthPct = 0.36, heightPct = 0.6,
		minWidth = 620, maxWidth = 950,
		minHeight = 460, maxHeight = 860,
		footerHeight = 44,
		titleText = AoM.L("APH_ON_MANAGER_CATEGORY_MANAGER"),
		enableSearch = true,
		toolbarHeight = 30,
	})
	category_window:SetSubtitle(AoM.L("CLICK_AN_ADD_ON_TO_PICK"))

	category_window.new_btn = LibAPH.CreateKeybindLabelButton(category_window.footer, {
		action = "AOM_NEW_CATEGORY",
		layer = AoM.KEYBIND_LAYER,
		name = AoM.L("NEW_CATEGORY"),
	})
	category_window.new_btn:SetAnchor(TOPRIGHT, category_window.footer, TOPRIGHT, 0, 0)

	category_window.reset_btn = LibAPH.CreateKeybindLabelButton(category_window.footer, {
		action = "AOM_RESET_LIST",
		layer = AoM.KEYBIND_LAYER,
		name = AoM.L("RESET_LIST"),
	})
	category_window.reset_btn:SetAnchor(TOPRIGHT, category_window.new_btn, TOPLEFT, -10, 0)

	category_window.reset_categories_btn = LibAPH.CreateKeybindLabelButton(category_window.footer, {
		action = "AOM_RESET_CATEGORIES",
		layer = AoM.KEYBIND_LAYER,
		name = AoM.L("RESET_CATEGORIES"),
	})
	category_window.reset_categories_btn:SetAnchor(TOPRIGHT, category_window.reset_btn, TOPLEFT, -10, 0)

	local toolbar = category_window.toolbar

	local filter_container = WINDOW_MANAGER:CreateControlFromVirtual("AoM_CategoryManagerFilter", toolbar, "ZO_ComboBox")
	filter_container:SetDimensions(150, 26)
	filter_container:SetAnchor(LEFT, toolbar, LEFT, 0, 0)
	local filter_combo = ZO_ComboBox_ObjectFromContainer(filter_container)
	filter_combo:SetSortsItems(false)
	LibAPH.UseGreenSelection(filter_combo)
	RegisterCategoryFilterCombo(filter_combo)
	LibAPH.UseContextMenuForCombo(filter_container, AoM.CategoryFilterMenuEntries)

	local profile_container = WINDOW_MANAGER:CreateControlFromVirtual("AoM_CategoryManagerProfile", toolbar, "ZO_ComboBox")
	profile_container:SetDimensions(150, 26)
	profile_container:SetAnchor(LEFT, filter_container, RIGHT, 10, 0)
	local profile_combo = ZO_ComboBox_ObjectFromContainer(profile_container)
	profile_combo:SetSortsItems(false)
	AoM.RegisterProfileCombo(profile_combo, profile_container)

	local new_profile_btn = WINDOW_MANAGER:CreateControlFromVirtual("AoM_CategoryManagerNewProfile", toolbar, "ZO_DefaultButton")
	new_profile_btn:SetDimensions(110, 28)
	new_profile_btn:SetFont("ZoFontGameSmall")
	new_profile_btn:SetText(AoM.L("NEW_PROFILE"))
	new_profile_btn:SetAnchor(LEFT, profile_container, RIGHT, 10, 0)
	new_profile_btn:SetHandler("OnClicked", function() AoM.ShowNewProfileDialog() end)

	local save_profile_btn = WINDOW_MANAGER:CreateControlFromVirtual("AoM_CategoryManagerSaveProfile", toolbar, "ZO_DefaultButton")
	save_profile_btn:SetDimensions(110, 28)
	save_profile_btn:SetFont("ZoFontGameSmall")
	save_profile_btn:SetText(AoM.L("SAVE_PROFILE"))
	save_profile_btn:SetAnchor(LEFT, new_profile_btn, RIGHT, 10, 0)
	save_profile_btn:SetHandler("OnClicked", function() AoM.ConfirmSaveProfile() end)

	category_window.settings_btn = AoM.CreateProfileSettingsButton(toolbar, "AoM_CategoryManagerProfileSettings")
	if category_window.settings_btn then
		category_window.settings_btn:SetAnchor(LEFT, save_profile_btn, RIGHT, 10, 0)
	end

	category_window:FitButtons()
	return category_window
end

local function HidePopupForDialog()
	local was_visible = category_window ~= nil and not category_window.window:IsHidden()
	if was_visible then category_window.window:SetHidden(true) end
	return was_visible
end
AoM.HidePopupForDialog = HidePopupForDialog

local function RestorePopupAfterDialog(was_visible)
	if was_visible and category_window then category_window.window:SetHidden(false) end
end
AoM.RestorePopupAfterDialog = RestorePopupAfterDialog

function RefreshCategoryManagerWindow()
	if category_window and RefreshCategoryWindow then RefreshCategoryWindow() end
end

local function ShowNameEntryDialog(dialogId, titleText, mainText, onConfirm)
	if not ESO_Dialogs[dialogId] then
		ESO_Dialogs[dialogId] = {
			canQueue = true,
			gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
			title = { text = titleText },
			mainText = function(dialog) return { text = dialog.data.mainText } end,
			editBox = {},
			buttons = {
				{
					requiresTextInput = true,
					text = SI_DIALOG_CONFIRM,
					callback = function(dialog)
						local new_name = ZO_Dialogs_GetEditBoxText(dialog)
						if new_name and new_name ~= "" then dialog.data.onConfirm(new_name) end
					end,
				},
				{ text = SI_DIALOG_CANCEL },
			},
			finishedCallback = function(dialog)
				RestorePopupAfterDialog(dialog.data.was_visible)
			end,
		}
	end

	local was_visible = HidePopupForDialog()
	local data = { mainText = mainText, onConfirm = onConfirm, was_visible = was_visible }
	if IsConsoleUI() or IsInGamepadPreferredMode() then
		if AoM.ShowGamepadTextEntryDialog then
			AoM.ShowGamepadTextEntryDialog(titleText, mainText, "", function(new_name)
				RestorePopupAfterDialog(was_visible)
				onConfirm(new_name)
			end, function() RestorePopupAfterDialog(was_visible) end)
		else
			ZO_Dialogs_ShowGamepadDialog(dialogId, data)
		end
	else
		ZO_Dialogs_ShowDialog(dialogId, data)
	end
end

local function RefreshGamepadAddonList()
	if ADDON_MANAGER_GAMEPAD and ADDON_MANAGER_GAMEPAD.list then
		ADDON_MANAGER_GAMEPAD:RefreshData()
	end
end

local function RefreshAllCategoryUI()
	if category_window then RefreshCategoryWindow() end
	if AoM.PopulateCategoryFilterDropdown then AoM.PopulateCategoryFilterDropdown() end
	PopulateCategoryFilterCombos()
	if ADD_ON_MANAGER then
		ADD_ON_MANAGER.isDirty = true
		ADD_ON_MANAGER:RefreshData()
	end
	RefreshGamepadAddonList()
end
AoM.RefreshAllCategoryUI = RefreshAllCategoryUI

local function OpenCategoryPickerMenu(control, addonName)
	LibAPH.ShowScrollableMenu(control, AoM.CategoryPickerEntries(addonName, RefreshAllCategoryUI))
end

local function ConfirmDeleteCategory(categoryName)
	local was_visible = HidePopupForDialog()
	LibAPH.ShowDialogChained("AoM_DELETE_CATEGORY_" .. categoryName, AoM.L("DELETE_CATEGORY"),
		string.format(AoM.L("DELETE_ADD_ONS_IN_IT_FALL"), categoryName), {
		{
			text = SI_DIALOG_CONFIRM,
			callback = function()
				DeleteCategory(categoryName)
				RestorePopupAfterDialog(was_visible)
				RefreshAllCategoryUI()
			end,
		},
		{
			text = SI_DIALOG_CANCEL,
			callback = function()
				RestorePopupAfterDialog(was_visible)
			end,
		},
	}, nil, function() RestorePopupAfterDialog(was_visible) end)
end

local function ShowRenameCategoryDialog(categoryName)
	local display_name = AoM.GetCategoryDisplayName(categoryName)
	ShowNameEntryDialog("AoM_RENAME_CATEGORY", AoM.L("RENAME_CATEGORY"), AoM.L("ENTER_A_NEW_NAME_FOR_2") .. display_name .. "\".", function(new_name)
		if RenameCategory(categoryName, new_name) then
			RefreshAllCategoryUI()
		end
	end)
end
AoM.ShowRenameCategoryDialog = ShowRenameCategoryDialog
AoM.ConfirmDeleteCategory = ConfirmDeleteCategory

AoM.ShowNameEntryDialog = ShowNameEntryDialog

local function ShowNewCategoryDialog()
	ShowNameEntryDialog("AoM_NEW_CATEGORY", AoM.L("NEW_CATEGORY"), AoM.L("ENTER_A_NAME_FOR_THE_NEW"), function(new_name)
		if CreateCategory(new_name) then RefreshAllCategoryUI() end
	end)
end
AoM.ShowNewCategoryDialog = ShowNewCategoryDialog

local function OpenCategoryHeaderMenu(control, categoryName)
	ClearMenu()
	AddMenuItem(AoM.L("RENAME_CATEGORY"), function()
		ShowRenameCategoryDialog(categoryName)
	end)
	if not IsDefaultCategory(categoryName) then
		AddMenuItem(AoM.L("DELETE_CATEGORY"), function()
			ConfirmDeleteCategory(categoryName)
		end)
	end
	ShowMenu(control)
end

RefreshCategoryWindow = function()
	local win = GetCategoryManagerWindow()
	local am = GetAddOnManager()

	local by_category = {}
	for i = 1, am:GetNumAddOns() do
		local name, title, _, _, is_enabled = am:GetAddOnInfo(i)
		local category = AoM.GetAddonCategory(name)
		if AoM.CategoryMatchesFilter(IsLibraryAddon(am, i), is_enabled, category, i) then
			by_category[category] = by_category[category] or {}
			table.insert(by_category[category], { name = name, title = (title ~= "" and title or name) })
		end
	end

	local categories = AoM.GetAllCategories()
	table.sort(categories, function(a, b)
		return string.lower(AoM.GetCategoryDisplayName(a)) < string.lower(AoM.GetCategoryDisplayName(b))
	end)

	local rows = {}
	local shown_filter = AoM.GetCategoryFilter()
	for _, category in ipairs(categories) do
		local members = by_category[category] or {}
		if #members == 0 and shown_filter ~= "All Add-Ons" then
			members = nil
		end
		if members then
			table.sort(members, function(a, b) return a.title < b.title end)

		local is_default_category = IsDefaultCategory(category)
		table.insert(rows, {
			text = string.format("%s (%d)", AoM.GetCategoryDisplayName(category), #members),
			is_header = true,
			onClick = function(control)
				OpenCategoryHeaderMenu(control, category)
			end,
			renameButton = {
				onClick = function()
					ShowRenameCategoryDialog(category)
				end,
			},
			closeButton = not is_default_category and {
				onClick = function()
					ConfirmDeleteCategory(category)
				end,
			} or nil,
		})
		for _, member in ipairs(members) do
			table.insert(rows, {
				text = member.title,
				color = { 0.85, 0.85, 0.85, 1 },
				statusIcons = AoM.GetStatusIconsForAddonByName(am, member.name),
				populateTooltip = function(tooltip)
					AoM.PopulateAddonInfoTooltipByName(tooltip, member.name)
				end,
				onClick = function(control)
					OpenCategoryPickerMenu(control, member.name, category)
				end,
			})
		end
		end
	end

	if #rows == 0 then
		rows[1] = { text = AoM.L("NOTHING_MATCHES_THIS_FILTER"), is_header = true }
	end

	win:SetTitle(AoM.L("APH_ON_MANAGER_CATEGORY_MANAGER"))
	win:SetCounts(AoM.GetAddonCountText())
	win:SetRows(rows)
end

local function ConfirmResetAddonCategoryAssignments()
	local was_visible = HidePopupForDialog()
	LibAPH.ShowDialogChained("AoM_RESET_CATEGORY_ASSIGNMENTS", AoM.L("RESET_LIST"),
		AoM.L("MOVE_EVERY_ADD_ON_AND_LIBRARY"), {
		{
			text = SI_DIALOG_CONFIRM,
			callback = function()
				ResetAddonCategoryAssignments()
				RestorePopupAfterDialog(was_visible)
				RefreshAllCategoryUI()
			end,
		},
		{
			text = SI_DIALOG_CANCEL,
			callback = function()
				RestorePopupAfterDialog(was_visible)
			end,
		},
	}, nil, function() RestorePopupAfterDialog(was_visible) end)
end

AoM.ConfirmResetAddonCategoryAssignments = ConfirmResetAddonCategoryAssignments

local function ConfirmResetCategories()
	local was_visible = HidePopupForDialog()
	LibAPH.ShowDialogChained("AoM_RESET_CATEGORIES", AoM.L("RESET_CATEGORIES"),
		AoM.L("DELETE_EVERY_CATEGORY_YOU_VE_CREATED"), {
		{
			text = SI_DIALOG_CONFIRM,
			callback = function()
				ResetCategories()
				RestorePopupAfterDialog(was_visible)
				RefreshAllCategoryUI()
			end,
		},
		{
			text = SI_DIALOG_CANCEL,
			callback = function()
				RestorePopupAfterDialog(was_visible)
			end,
		},
	}, nil, function() RestorePopupAfterDialog(was_visible) end)
end

AoM.ConfirmResetCategories = ConfirmResetCategories

local function OpenCategoryManager()
	local win = GetCategoryManagerWindow()

	win.new_btn.libaph_click_action = ShowNewCategoryDialog
	win.reset_btn.libaph_click_action = ConfirmResetAddonCategoryAssignments
	win.reset_categories_btn.libaph_click_action = ConfirmResetCategories

	RefreshCategoryWindow()
	win:Show()
end

AoM.OpenCategoryManager = OpenCategoryManager

local FILTER_ALL = "All Add-Ons"
local FILTER_ENABLED_ADDONS = "Enabled Add-Ons"
local FILTER_ENABLED_LIBRARIES = "Enabled Libraries"
local FILTER_SHOW_ENABLED = "Show Enabled"
local FILTER_ERRORS = "With Errors"
local FILTER_SAVED_VARIABLES = "Save Size"
local FILTER_API_OUT_OF_DATE = "Out of Date API"
local FILTER_MISSING_DEPENDENCIES = "Missing Dependencies"
local FILTER_NO_VERSION = "No Version"
local FILTER_NO_ADDONVERSION = "No AddOnVersion"
local FILTER_OUTDATED_VERSION = "Outdated Version"
local FILTER_OUTDATED_ADDONVERSION = "Outdated AddOnVersion"
local AUTHOR_PREFIX = "author:"
local current_filter = FILTER_ALL

AoM.FILTER_ALL = FILTER_ALL
AoM.FILTER_API_OUT_OF_DATE = FILTER_API_OUT_OF_DATE
AoM.FILTER_MISSING_DEPENDENCIES = FILTER_MISSING_DEPENDENCIES
AoM.FILTER_NO_VERSION = FILTER_NO_VERSION
AoM.FILTER_NO_ADDONVERSION = FILTER_NO_ADDONVERSION
AoM.FILTER_OUTDATED_VERSION = FILTER_OUTDATED_VERSION
AoM.FILTER_OUTDATED_ADDONVERSION = FILTER_OUTDATED_ADDONVERSION
AoM.FILTER_SAVED_VARIABLES = FILTER_SAVED_VARIABLES

function AoM.IsSavedVariablesSortActive()
	return current_filter == FILTER_SAVED_VARIABLES
end

local function SavedVariablesUsage(addonIndex)
	if type(LibAPH.GetSavedVariablesDiskUsageMB) ~= "function" then return 0 end
	local usage = LibAPH.GetSavedVariablesDiskUsageMB(addonIndex)
	if type(usage) ~= "number" then return 0 end
	return usage
end

AoM.GetSavedVariablesUsageForSort = SavedVariablesUsage

local UNLIMITED_CAPACITY_MB = 1024 * 1024
local SAVE_SIZE_CACHE_MS = 5000
local save_size_sum, save_size_sum_ms = nil, 0

local function SumSavedVariablesUsage()
	local now = GetFrameTimeMilliseconds()
	if save_size_sum and (now - save_size_sum_ms) < SAVE_SIZE_CACHE_MS then return save_size_sum end
	local am = GetAddOnManager()
	local total = 0
	for index = 1, am:GetNumAddOns() do
		total = total + SavedVariablesUsage(index)
	end
	save_size_sum, save_size_sum_ms = total, now
	return total
end

function AoM.GetSaveSizeUsage()
	local capacity = type(LibAPH.GetSavedVariablesDiskCapacityMB) == "function"
		and LibAPH.GetSavedVariablesDiskCapacityMB() or nil
	if type(capacity) ~= "number" or capacity <= 0 or capacity >= UNLIMITED_CAPACITY_MB then
		capacity = nil
	end
	local used = type(LibAPH.GetTotalSavedVariablesDiskUsageMB) == "function"
		and LibAPH.GetTotalSavedVariablesDiskUsageMB() or nil
	if type(used) ~= "number" or used <= 0 then used = SumSavedVariablesUsage() end
	if type(used) ~= "number" then return nil end
	return used, capacity
end

function AoM.GetSaveSizeValue()
	local used, capacity = AoM.GetSaveSizeUsage()
	if not used then return nil end
	return LibAPH.FormatDiskUsageRangeMB(used, capacity)
end

function AoM.GetSaveSizeLine()
	local value = AoM.GetSaveSizeValue()
	if not value then return nil end
	return AoM.L("SAVE_SIZE") .. value
end

function AoM.GetSavedVariablesSortCallback()
	local usage = {}
	local function UsageFor(entry)
		local index = entry.index or entry.addOnIndex
		if not index then return 0 end
		if usage[index] == nil then usage[index] = SavedVariablesUsage(index) end
		return usage[index]
	end
	return function(a, b)
		local usage_a, usage_b = UsageFor(a), UsageFor(b)
		if usage_a ~= usage_b then return usage_a > usage_b end
		return string.lower(a.addOnFileName or "") < string.lower(b.addOnFileName or "")
	end
end

function AoM.FilterEntriesWithSavedVariables(entries, getIndex)
	local kept = {}
	for _, entry in ipairs(entries) do
		local index = getIndex(entry)
		if index and SavedVariablesUsage(index) > 0 then kept[#kept + 1] = entry end
	end
	return kept
end

function AoM.SortEntriesBySavedVariables(entries, getIndex, getName)
	local usage, name = {}, {}
	for _, entry in ipairs(entries) do
		usage[entry] = SavedVariablesUsage(getIndex(entry))
		name[entry] = string.lower(getName(entry) or "")
	end
	table.sort(entries, function(a, b)
		if usage[a] ~= usage[b] then return usage[a] > usage[b] end
		return name[a] < name[b]
	end)
	return entries
end

local VERSION_FILTERS = {
	[FILTER_API_OUT_OF_DATE] = function(status)
		return status.api_out_of_date == true or status.api_invalid == true
	end,
	[FILTER_NO_VERSION] = function(status)
		return status.known == nil or status.known.displayVersion == nil
	end,
	[FILTER_NO_ADDONVERSION] = function(status)
		return (status.installed or 0) <= 0
	end,
	[FILTER_OUTDATED_VERSION] = function(status)
		return status.newer_on_esoui == true and status.known ~= nil and status.known.displayVersion ~= nil
	end,
	[FILTER_OUTDATED_ADDONVERSION] = function(status)
		return status.newer_on_esoui == true
	end,
}

local function CleanAuthor(author)
	local text = LibAPH.StripColors(tostring(author or ""))
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function AuthorOfFilter(filter)
	if type(filter) ~= "string" or filter:sub(1, #AUTHOR_PREFIX) ~= AUTHOR_PREFIX then return nil end
	return filter:sub(#AUTHOR_PREFIX + 1)
end

function GetAuthorFilterEntries()
	local am = GetAddOnManager()
	local seen, entries = {}, {}
	for index = 1, am:GetNumAddOns() do
		local _, _, author = am:GetAddOnInfo(index)
		local name = CleanAuthor(author)
		if name ~= "" and not seen[name] then
			seen[name] = true
			entries[#entries + 1] = { display = name, internal = AUTHOR_PREFIX .. name }
		end
	end
	local function SortKey(text) return string.lower((string.gsub(text, "^@", ""))) end
	table.sort(entries, function(a, b)
		local ka, kb = SortKey(a.display), SortKey(b.display)
		if ka == kb then return a.display < b.display end
		return ka < kb
	end)
	return entries
end

function AoM.CategoryMatchesFilter(isLibrary, isEnabled, category, addonIndex)
	if current_filter == FILTER_ALL then return true end
	local author = AuthorOfFilter(current_filter)
	if author then
		if addonIndex == nil then return false end
		local _, _, raw = GetAddOnManager():GetAddOnInfo(addonIndex)
		return CleanAuthor(raw) == author
	end
	if current_filter == FILTER_ENABLED_ADDONS then return not isLibrary and isEnabled end
	if current_filter == FILTER_ENABLED_LIBRARIES then return isLibrary and isEnabled end
	if current_filter == FILTER_SHOW_ENABLED then return isEnabled end
	if current_filter == FILTER_ERRORS then return AoM.HasAddonError(GetAddOnManager(), addonIndex) end
	if current_filter == FILTER_SAVED_VARIABLES then
		return addonIndex ~= nil and SavedVariablesUsage(addonIndex) > 0
	end
	if current_filter == FILTER_MISSING_DEPENDENCIES then
		return addonIndex ~= nil and AoM.HasMissingDependency ~= nil
			and AoM.HasMissingDependency(GetAddOnManager(), addonIndex)
	end
	if VERSION_FILTERS[current_filter] then
		if addonIndex == nil or type(AoM.GetAddonUpdateStatus) ~= "function" then return false end
		local status = AoM.GetAddonUpdateStatus(GetAddOnManager(), addonIndex)
		return VERSION_FILTERS[current_filter](status)
	end
	return category == current_filter
end

function AoM.GetCategoryFilter()
	return current_filter
end

function AoM.GetCategoryFilterDisplayName(filter)
	local author = AuthorOfFilter(filter)
	if author then return "By " .. author end
	if filter == FILTER_ALL or filter == FILTER_ENABLED_ADDONS or filter == FILTER_ENABLED_LIBRARIES
		or filter == FILTER_SHOW_ENABLED or filter == FILTER_ERRORS or filter == FILTER_SAVED_VARIABLES
		or filter == FILTER_API_OUT_OF_DATE or filter == FILTER_MISSING_DEPENDENCIES
		or filter == FILTER_NO_VERSION or filter == FILTER_NO_ADDONVERSION
		or filter == FILTER_OUTDATED_VERSION or filter == FILTER_OUTDATED_ADDONVERSION then
		return filter
	end
	return AoM.GetCategoryDisplayName(filter)
end

local function StatusFilterEntries()
	return {
		{ display = FILTER_ALL, internal = FILTER_ALL },
		{ display = FILTER_ENABLED_ADDONS, internal = FILTER_ENABLED_ADDONS },
		{ display = FILTER_ENABLED_LIBRARIES, internal = FILTER_ENABLED_LIBRARIES },
		{ display = FILTER_SHOW_ENABLED, internal = FILTER_SHOW_ENABLED },
		{ display = FILTER_ERRORS, internal = FILTER_ERRORS },
		{ display = FILTER_SAVED_VARIABLES, internal = FILTER_SAVED_VARIABLES },
		{ display = FILTER_MISSING_DEPENDENCIES, internal = FILTER_MISSING_DEPENDENCIES },
		{ display = FILTER_API_OUT_OF_DATE, internal = FILTER_API_OUT_OF_DATE },
		{ display = FILTER_OUTDATED_VERSION, internal = FILTER_OUTDATED_VERSION },
		{ display = FILTER_OUTDATED_ADDONVERSION, internal = FILTER_OUTDATED_ADDONVERSION },
		{ display = FILTER_NO_VERSION, internal = FILTER_NO_VERSION },
		{ display = FILTER_NO_ADDONVERSION, internal = FILTER_NO_ADDONVERSION },
	}
end

function AoM.GetCategoryFilterEntries()
	local entries = StatusFilterEntries()
	for _, category in ipairs(AoM.GetAllCategories()) do
		table.insert(entries, { display = AoM.GetCategoryDisplayName(category), internal = category })
	end
	return entries
end

function GetCategoryFilterGroups()
	local defaults, users = {}, {}
	for _, category in ipairs(AoM.GetAllCategories()) do
		local item = { display = AoM.GetCategoryDisplayName(category), internal = category }
		if IsDefaultCategory(category) then defaults[#defaults + 1] = item else users[#users + 1] = item end
	end
	return StatusFilterEntries(), defaults, users
end

local function AsChoices(items)
	local out = {}
	for _, item in ipairs(items) do out[#out + 1] = { text = item.display, value = item.internal } end
	return out
end

function AoM.CategoryFilterMenuEntries()
	local current = current_filter
	local statuses, defaults, users = GetCategoryFilterGroups()
	local by_author = AuthorOfFilter(current) ~= nil
	local author_entry = {
		text = AoM.L("BY_AUTHOR"),
		color = by_author and LibAPH.THEME.GREEN or nil,
		submenuFilter = true,
		submenu = function()
			return LibAPH.GroupedChoiceEntries({ { items = AsChoices(GetAuthorFilterEntries()) } }, {
				current = current, onPick = AoM.SetCategoryFilter,
			})[1].submenu()
		end,
	}
	return LibAPH.GroupedChoiceEntries({
		{ title = "Filter", items = AsChoices(statuses), extra = { author_entry }, holds = by_author },
		{ title = "Default Categories", items = AsChoices(defaults) },
		{ title = "User Categories", items = AsChoices(users) },
	}, { current = current, onPick = AoM.SetCategoryFilter })
end

function AoM.CategoryPickerEntries(addonName, onPicked)
	local _, defaults, users = GetCategoryFilterGroups()
	return LibAPH.GroupedChoiceEntries({
		{ title = "Default Categories", items = AsChoices(defaults) },
		{ title = "User Categories", items = AsChoices(users) },
	}, {
		current = AoM.GetAddonCategory(addonName),
		onPick = function(category)
			AoM.AssignAddonToCategory(addonName, category)
			if onPicked then onPicked() end
		end,
	})
end

local filter_combos = {}

function RegisterCategoryFilterCombo(combo)
	local entry = { combo = combo }
	filter_combos[#filter_combos + 1] = entry
	PopulateCategoryFilterCombos()
	return entry
end

function PopulateCategoryFilterCombos()
	for _, entry in ipairs(filter_combos) do
		local combo = entry.combo
		combo:ClearItems()
		combo:SetSelectedItemText(AoM.GetCategoryFilterDisplayName(AoM.GetCategoryFilter()))
	end
end

function AoM.SetCategoryFilter(filter)
	current_filter = filter or FILTER_ALL
	local display = AoM.GetCategoryFilterDisplayName(current_filter)
	if AoM.category_filter_combo then
		AoM.category_filter_combo:SetSelectedItemText(display)
	end
	for _, entry in ipairs(filter_combos) do
		entry.combo:SetSelectedItemText(display)
	end
	if ADD_ON_MANAGER then
		ADD_ON_MANAGER.isDirty = true
		ADD_ON_MANAGER:RefreshData()
	end
	if RefreshCategoryManagerWindow then RefreshCategoryManagerWindow() end
	RefreshGamepadAddonList()
end

function AoM.SetCategoryAddonsEnabled(entries, isEnabled)
	local am = GetAddOnManager()
	for _, entry in ipairs(entries) do
		if entry.index then
			if isEnabled and AoM.EnableAddonWithDependencies then
				AoM.EnableAddonWithDependencies(entry.index)
			else
				am:SetAddOnEnabled(entry.index, isEnabled)
			end
		end
	end
	if not isEnabled then
		AoM.DisableUnused({ quiet = true, librariesOnly = true })
	end
end

if not ZO_AddOnManager.AreAddOnsEnabled then
	function ZO_AddOnManager:AreAddOnsEnabled()
		return GetAddOnManager():AreAddOnsEnabled()
	end
end
