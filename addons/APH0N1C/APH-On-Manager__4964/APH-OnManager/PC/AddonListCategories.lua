--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
if not ADD_ON_MANAGER then return end
local AoM = APHOnManagerCore
local LibAPH = LibAPH

local LIBRARIES = "Libraries"

local function EntryMatchesFilter(entry, category)
	return AoM.CategoryMatchesFilter(entry.isLibrary, entry.addOnEnabled, category, entry.index)
end

local function RegroupByCategory(self)
	local flat = {}
	for _, is_lib in ipairs({ true, false }) do
		for _, entry in ipairs(self.addonTypes[is_lib] or {}) do
			table.insert(flat, entry)
		end
	end

	local groups, order, display_to_internal = {}, {}, {}

	if AoM.IsSavedVariablesSortActive() then
		local with_saves = AoM.FilterEntriesWithSavedVariables(flat, function(entry) return entry.index end)
		local sorted = AoM.SortEntriesBySavedVariables(with_saves,
			function(entry) return entry.index end,
			function(entry) return entry.addOnFileName end)
		self.aom_category_groups = { [AoM.FILTER_SAVED_VARIABLES] = sorted }
		self.aom_category_order = { AoM.FILTER_SAVED_VARIABLES }
		self.aom_category_display_to_internal = { [AoM.FILTER_SAVED_VARIABLES] = AoM.FILTER_SAVED_VARIABLES }
		if AoM.RefreshAddonCounters then AoM.RefreshAddonCounters() end
		return
	end

	for _, entry in ipairs(flat) do
		local category = AoM.GetAddonCategory(entry.addOnFileName)
		if EntryMatchesFilter(entry, category) then
			if not groups[category] then
				groups[category] = {}
				table.insert(order, category)
				display_to_internal[AoM.GetCategoryDisplayName(category)] = category
			end
			table.insert(groups[category], entry)
		end
	end
	table.sort(order, function(a, b) return string.lower(a) < string.lower(b) end)

	self.aom_category_groups = groups
	self.aom_category_order = order
	self.aom_category_display_to_internal = display_to_internal

	if AoM.RefreshAddonCounters then AoM.RefreshAddonCounters() end
end

ZO_PostHook(ADD_ON_MANAGER, "BuildMasterList", RegroupByCategory)

ZO_PreHook(ADD_ON_MANAGER, "SortScrollList", function(self)
	self:ResetDataTypes()
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)

	local original_sort = self.sortCallback
	if AoM.IsSavedVariablesSortActive() then
		self.sortCallback = AoM.GetSavedVariablesSortCallback()
	end
	for _, category in ipairs(self.aom_category_order or {}) do
		local is_lib_group = (category == LIBRARIES)
		self.addonTypes[is_lib_group] = self.aom_category_groups[category]
		self:AddAddonTypeSection(is_lib_group, AoM.GetCategoryDisplayName(category))
	end
	self.sortCallback = original_sort
	return true
end)

ZO_PostHook(ADD_ON_MANAGER, "SetupSectionHeaderRow", function(self, control, data)
	local internal_category = (self.aom_category_display_to_internal and self.aom_category_display_to_internal[data.text]) or data.text

	if control.checkboxControl then
		if not control.aom_rename_btn then
			control.aom_rename_btn = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "SavingEditBoxModifyButton")
			control.aom_rename_btn:SetDimensions(18, 18)
			control.aom_rename_btn:SetHandler("OnClicked", function()
				if control.aom_current_category then AoM.ShowRenameCategoryDialog(control.aom_current_category) end
			end)

			control.aom_delete_btn = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "SavingEditBoxCancelButton")
			control.aom_delete_btn:SetDimensions(18, 18)
			control.aom_delete_btn:SetHandler("OnMouseEnter", function(btn)
				InitializeTooltip(InformationTooltip, btn, BOTTOM, 0, -2)
				SetTooltipText(InformationTooltip, "Delete")
			end)
			control.aom_delete_btn:SetHandler("OnMouseExit", function()
				ClearTooltip(InformationTooltip)
			end)
			control.aom_delete_btn:SetHandler("OnClicked", function()
				if control.aom_current_category then AoM.ConfirmDeleteCategory(control.aom_current_category) end
			end)
		end

		control.aom_current_category = internal_category
		local generated = internal_category == AoM.FILTER_SAVED_VARIABLES
		control.aom_rename_btn:ClearAnchors()
		control.aom_rename_btn:SetAnchor(LEFT, control.checkboxControl, LEFT, 70, 0)
		control.aom_rename_btn:SetHidden(generated)

		control.aom_delete_btn:ClearAnchors()
		control.aom_delete_btn:SetAnchor(LEFT, control.aom_rename_btn, RIGHT, 6, 0)
		control.aom_delete_btn:SetHidden(generated or AoM.IsDefaultCategory(internal_category))
	end

	if data.isLibrary then return end
	local group = self.aom_category_groups and self.aom_category_groups[internal_category]
	if not group or not control.checkboxControl then return end

	local am = GetAddOnManager()
	local all_enabled = true
	for _, entry in ipairs(group) do
		local _, _, _, _, isEnabled = am:GetAddOnInfo(entry.index)
		if not isEnabled then
			all_enabled = false
			break
		end
	end
	ZO_CheckButton_SetCheckState(control.checkboxControl, all_enabled)

	ZO_CheckButton_SetToggleFunction(control.checkboxControl, function(_, isBoxChecked)
		AoM.SetCategoryAddonsEnabled(group, isBoxChecked)
		self.isDirty = true
		self:RefreshKeybinds()
		self:RefreshData()
	end)
end)

local COUNTER_GAP_PLAIN = 20
local UNUSED_SAVES_MIN_WIDTH = 170
local BUTTON_TEXT_PADDING = 24

local function FitButtonToText(button, minWidth)
	local label = type(button.GetLabelControl) == "function" and button:GetLabelControl()
	if not label or type(label.GetTextDimensions) ~= "function" then return end
	local text_width = label:GetTextDimensions()
	if type(text_width) ~= "number" or text_width <= 0 then return end
	button:SetWidth(math.max(minWidth, math.ceil(text_width) + BUTTON_TEXT_PADDING))
end

local category_filter_combo
local native_new_category_btn
local auto_disable_checkbox
local suppress_errors_checkbox
local priority_save_checkbox
local unused_saved_variables_btn
local ghost_btn_ref
local native_reset_btn
local native_reset_categories_btn
local addon_count_lbl
local library_count_lbl
local save_size_lbl

local TITLE_WATCH_NAME = "AoM_TitleCounters"
local TITLE_WATCH_MS = 250
local expected_title

local PLAIN_TITLE = "ADD-ONS"

local function ApplyTitleCounters()
	if not ADD_ON_MANAGER or not ADD_ON_MANAGER.control then return end
	local title = ADD_ON_MANAGER.control:GetNamedChild("Title")
	if not title then return end
	expected_title = PLAIN_TITLE
	title:SetText(expected_title)
end
AoM.ApplyTitleCounters = ApplyTitleCounters

local function KeepTitleCounters()
	if not expected_title or not ADD_ON_MANAGER or not ADD_ON_MANAGER.control then return end
	local title = ADD_ON_MANAGER.control:GetNamedChild("Title")
	if not title or title:GetText() == expected_title then return end
	title:SetText(expected_title)
end

local function StartTitleWatch()
	if not AoM.IsAddonSelectorRunning() then return end
	ApplyTitleCounters()
	EVENT_MANAGER:RegisterForUpdate(TITLE_WATCH_NAME, TITLE_WATCH_MS, KeepTitleCounters)
end
AoM.StartTitleWatch = StartTitleWatch

local function StopTitleWatch()
	EVENT_MANAGER:UnregisterForUpdate(TITLE_WATCH_NAME)
end
AoM.StopTitleWatch = StopTitleWatch

local function RefreshAddonCounters()
	if not addon_count_lbl then return end
	local addons_line, libraries_line = AoM.GetAddonCountLines()
	addon_count_lbl:SetText(addons_line)
	library_count_lbl:SetText(libraries_line)
	if save_size_lbl then
		local save_size_line = AoM.GetSaveSizeLine and AoM.GetSaveSizeLine()
		save_size_lbl:SetText(save_size_line or "")
		save_size_lbl:SetHidden(save_size_line == nil)
	end
	if AoM.IsAddonSelectorRunning and AoM.IsAddonSelectorRunning() then
		ApplyTitleCounters()
	end
end
AoM.RefreshAddonCounters = RefreshAddonCounters


local function IsAddonSelectorRunning()
	return _G["AddonSelectorSave"] ~= nil and _G["AddonSelectorDelete"] ~= nil
end
AoM.IsAddonSelectorRunning = IsAddonSelectorRunning

local added_controls = {}
local added_controls_refreshed = false

local function RefreshAddedControlsOnFirstShow()
	if added_controls_refreshed or #added_controls == 0 then return end
	added_controls_refreshed = true
	for _, control in ipairs(added_controls) do control:SetHidden(true) end
	zo_callLater(function()
		for _, control in ipairs(added_controls) do control:SetHidden(false) end
	end, 0)
end

function AoM.EnsureCategoryFilterDropdown()
	if category_filter_combo then return category_filter_combo end
	if not ADD_ON_MANAGER or not ADD_ON_MANAGER.control then return nil end
	local title = ADD_ON_MANAGER.control:GetNamedChild("Title")
	if not title then return nil end


	local container = WINDOW_MANAGER:CreateControlFromVirtual("AoMCategoryFilterDropdown", ADD_ON_MANAGER.control, "ZO_ComboBox")
	container:SetDimensions(140, 26)
	container:SetAnchor(LEFT, title, RIGHT, 220, 0)

	added_controls[#added_controls + 1] = container
	category_filter_combo = ZO_ComboBox_ObjectFromContainer(container)
	category_filter_combo:SetSortsItems(false)
	LibAPH.UseGreenSelection(category_filter_combo)
	AoM.category_filter_combo = category_filter_combo
	AoM.category_filter_dropdown_container = container
	LibAPH.UseContextMenuForCombo(container, AoM.CategoryFilterMenuEntries)

	native_new_category_btn = WINDOW_MANAGER:CreateControlFromVirtual("AoMNewCategoryButton", ADD_ON_MANAGER.control, "ZO_DefaultButton")
	native_new_category_btn:SetDimensions(140, 30)
	native_new_category_btn:SetFont("ZoFontWinH4")
	native_new_category_btn:SetText(AoM.L("NEW_CATEGORY"))
	native_new_category_btn:SetHandler("OnClicked", function() AoM.ShowNewCategoryDialog() end)
	native_new_category_btn:SetAnchor(LEFT, container, RIGHT, 20, 0)
	added_controls[#added_controls + 1] = native_new_category_btn

	local ghost_btn = WINDOW_MANAGER:CreateControlFromVirtual("AoMDisableUnusedButton", ADD_ON_MANAGER.control, "ZO_DefaultButton")
	ghost_btn:SetDimensions(140, 30)
	ghost_btn:SetFont("ZoFontWinH4")
	ghost_btn:SetText(AoM.L("DISABLE_UNUSED"))
	ghost_btn:SetHandler("OnClicked", function() AoM.DisableUnused() end)
	ghost_btn:SetAnchor(LEFT, native_new_category_btn, RIGHT, 10, 0)
	added_controls[#added_controls + 1] = ghost_btn
	ghost_btn_ref = ghost_btn

	unused_saved_variables_btn = WINDOW_MANAGER:CreateControlFromVirtual("AoMClearUnusedSavedVariablesButton", ADD_ON_MANAGER.control, "ZO_DefaultButton")
	unused_saved_variables_btn:SetDimensions(170, 30)
	unused_saved_variables_btn:SetFont("ZoFontWinH4")
	unused_saved_variables_btn:SetText(AoM.L("ORPHANED_SAVES_2"))
	unused_saved_variables_btn:SetHandler("OnClicked", function()
		AoM.ConfirmClearUnusedSavedVariables(AoM.RefreshUnusedSavedVariablesButton)
	end)
	unused_saved_variables_btn:SetHidden(true)
	unused_saved_variables_btn:SetAnchor(LEFT, ghost_btn, RIGHT, 10, 0)
	added_controls[#added_controls + 1] = unused_saved_variables_btn

	auto_disable_checkbox = WINDOW_MANAGER:CreateControlFromVirtual("AoMAutoDisableUnusedCheckbox", ADD_ON_MANAGER.control, "ZO_CheckButton")
	ZO_CheckButton_SetLabelText(auto_disable_checkbox, AoM.L("AUTO_DISABLE_UNUSED"))
	ZO_CheckButton_SetToggleFunction(auto_disable_checkbox, function(_, checked) AoM.SetAutoDisableUnusedEnabled(checked) end)
	ZO_CheckButton_SetCheckState(auto_disable_checkbox, AoM.IsAutoDisableUnusedEnabled())
	added_controls[#added_controls + 1] = auto_disable_checkbox

	suppress_errors_checkbox = WINDOW_MANAGER:CreateControlFromVirtual("AoMSuppressLuaErrorsCheckbox", ADD_ON_MANAGER.control, "ZO_CheckButton")
	ZO_CheckButton_SetLabelText(suppress_errors_checkbox, AoM.L("SUPPRESS_LUA_ERRORS"))
	ZO_CheckButton_SetToggleFunction(suppress_errors_checkbox, function(_, checked) AoM.SetSuppressingLuaErrors(checked) end)
	ZO_CheckButton_SetCheckState(suppress_errors_checkbox, AoM.IsSuppressingLuaErrors())
	added_controls[#added_controls + 1] = suppress_errors_checkbox

	priority_save_checkbox = WINDOW_MANAGER:CreateControlFromVirtual("AoMPrioritySaveCheckbox", ADD_ON_MANAGER.control, "ZO_CheckButton")
	ZO_CheckButton_SetLabelText(priority_save_checkbox, AoM.L("PRIORITY_SAVE_ON_DEMAND"))
	ZO_CheckButton_SetToggleFunction(priority_save_checkbox, function(_, checked) AoM.SetPrioritySaveEnabled(checked) end)
	ZO_CheckButton_SetCheckState(priority_save_checkbox, AoM.IsPrioritySaveEnabled())
	added_controls[#added_controls + 1] = priority_save_checkbox

	local settings_btn = AoM.CreateProfileSettingsButton(ADD_ON_MANAGER.control, "AoMProfileSettingsButton", function()
		AoM.ShowProfileTriggerMenu(AoM.profile_settings_button)
	end)
	if settings_btn then
		AoM.profile_settings_button = settings_btn
		settings_btn:SetAnchor(LEFT, ghost_btn, RIGHT, 8, 0)
		added_controls[#added_controls + 1] = settings_btn
	end

	local profile_arrow
	profile_arrow = LibAPH.CreateToggleArrowButton(ADD_ON_MANAGER.control, "AoMProfileArrow", function(wants_open)
		if not wants_open then
			LibAPH.CloseScrollableMenu()
			return false
		end
		AoM.ShowProfileMenu(profile_arrow, function()
			LibAPH.SetToggleArrowOpen(profile_arrow, false)
		end)
		return true
	end, "Profiles")
	if profile_arrow then
		AoM.profile_arrow = profile_arrow
		added_controls[#added_controls + 1] = profile_arrow
	end

	addon_count_lbl = WINDOW_MANAGER:CreateControl("AoMAddonCountLabel", ADD_ON_MANAGER.control, CT_LABEL)
	addon_count_lbl:SetFont("ZoFontGameSmall")
	addon_count_lbl:SetColor(0.75, 0.75, 0.75, 1)

	library_count_lbl = WINDOW_MANAGER:CreateControl("AoMLibraryCountLabel", ADD_ON_MANAGER.control, CT_LABEL)
	library_count_lbl:SetFont("ZoFontGameSmall")
	library_count_lbl:SetColor(0.75, 0.75, 0.75, 1)

	save_size_lbl = WINDOW_MANAGER:CreateControl("AoMSaveSizeLabel", ADD_ON_MANAGER.control, CT_LABEL)
	save_size_lbl:SetFont("ZoFontGameSmall")
	save_size_lbl:SetColor(0.75, 0.75, 0.75, 1)

	addon_count_lbl:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 2, 8)
	library_count_lbl:SetAnchor(LEFT, addon_count_lbl, RIGHT, COUNTER_GAP_PLAIN, 0)
	save_size_lbl:SetAnchor(LEFT, library_count_lbl, RIGHT, COUNTER_GAP_PLAIN, 0)
	added_controls[#added_controls + 1] = addon_count_lbl
	added_controls[#added_controls + 1] = library_count_lbl
	added_controls[#added_controls + 1] = save_size_lbl
	RefreshAddonCounters()
	AoM.RefreshProfileControls()

	local secondary_btn = ADD_ON_MANAGER.control:GetNamedChild("SecondaryButton")
	if secondary_btn then
		native_reset_btn = LibAPH.CreateKeybindLabelButton(ADD_ON_MANAGER.control, {
			action = "AOM_RESET_LIST",
			layer = AoM.KEYBIND_LAYER,
			name = AoM.L("RESET_LIST"),
		})
		native_reset_btn:SetAnchor(LEFT, secondary_btn, RIGHT, 30, 0)
		native_reset_btn.libaph_click_action = AoM.ConfirmResetAddonCategoryAssignments

		native_reset_categories_btn = LibAPH.CreateKeybindLabelButton(ADD_ON_MANAGER.control, {
			action = "AOM_RESET_CATEGORIES",
			layer = AoM.KEYBIND_LAYER,
			name = AoM.L("RESET_CATEGORIES"),
		})
		native_reset_categories_btn:SetAnchor(LEFT, native_reset_btn, RIGHT, 20, 0)
		native_reset_categories_btn.libaph_click_action = AoM.ConfirmResetCategories
		added_controls[#added_controls + 1] = native_reset_btn
		added_controls[#added_controls + 1] = native_reset_categories_btn
		LibAPH.FitButtonRow(ADD_ON_MANAGER.control, { native_reset_btn, native_reset_categories_btn }, { gap = 20, room = function()
			return ADD_ON_MANAGER.control:GetRight() - secondary_btn:GetRight() - 50
		end })
	end
	for _, btn in ipairs({ native_new_category_btn, ghost_btn_ref, unused_saved_variables_btn }) do
		LibAPH.FitButtonText(btn, { font = "ZoFontWinH4" })
	end

	return category_filter_combo
end

local function PopulateCategoryFilterDropdown()
	local combo = category_filter_combo
	if not combo then return end
	combo:ClearItems()
	combo:SetSelectedItemText(AoM.GetCategoryFilterDisplayName(AoM.GetCategoryFilter()))
end
AoM.PopulateCategoryFilterDropdown = PopulateCategoryFilterDropdown

EVENT_MANAGER:RegisterForEvent("AoM_CategoryFilterBuild", EVENT_PLAYER_ACTIVATED, function()
	EVENT_MANAGER:UnregisterForEvent("AoM_CategoryFilterBuild", EVENT_PLAYER_ACTIVATED)
	if AoM.EnsureCategoryFilterDropdown() then
		PopulateCategoryFilterDropdown()
	end
end)

local placing_advanced_ui_errors = false
local LAYOUTS = {
	vanilla = {
		footerStyle = "stacked", footerGap = 24, rowDrop = 35, stackGap = 10,
		checkboxGap = 25, minCheckboxGap = 10, edgeInset = 54,
		hideTitle = true, hideDivider = false,
		titleRowInset = 0, titleRowLift = 0, searchRowDrop = 0,
		containerLift = 0, counterGap = 24,
		labelDrop = 22, checkboxDrop = 48, reloadDrop = 41, keybindDrop = 76,
		reloadFollowsCheckboxes = true, reloadEdgeInset = 20, reloadExtraRight = 10,
	},
	perfectpixel = {
		footerStyle = "stacked", footerAnchorTo = "window",
		footerGap = 24, rowDrop = 35, stackGap = 10,
		checkboxGap = 25, minCheckboxGap = 10, edgeInset = 14,
		hideTitle = true, hideDivider = false,
		titleRowInset = 0, titleRowLift = 0, searchRowDrop = 0,
		containerLift = 0, counterGap = 24,
		labelDrop = -19, checkboxDrop = 7, reloadDrop = -2, keybindDrop = 35,
		labelUnderReload = true, labelUnderReloadGap = 6,
		reloadFollowsCheckboxes = true, reloadEdgeInset = 20,
	},
	addonselector = {
		footerStyle = "stacked", footerGap = 24, rowDrop = 35, stackGap = 10,
		checkboxGap = 25, minCheckboxGap = 10, edgeInset = 49,
		hideTitle = true, hideDivider = true, alignFilterToPackBox = "right",
		titleRowInset = 39, titleRowLift = -14, searchRowDrop = 4,
		containerLift = -16, counterGap = 24,
		labelDrop = 22, checkboxDrop = 48, reloadDrop = 41, keybindDrop = 76,
	},
	addonselector_perfectpixel = {
		footerStyle = "stacked", footerGap = 24, rowDrop = 35, stackGap = 10,
		checkboxGap = 25, minCheckboxGap = 10, edgeInset = 21,
		hideTitle = true, hideDivider = true, asCogwheelNudge = 10,
		titleRowInset = 40, titleRowLift = -11, searchRowDrop = 2,
		containerLift = -13, counterGap = 24,
		labelDrop = 22, checkboxDrop = 48, reloadDrop = 41, keybindDrop = 76,
	},
}

local function ActiveLayout()
	local addon_selector = IsAddonSelectorRunning()
	local perfect_pixel = LibAPH.IsAddonActiveAndRunning("PerfectPixel")
	if addon_selector and perfect_pixel then return LAYOUTS.addonselector_perfectpixel end
	if addon_selector then return LAYOUTS.addonselector end
	if perfect_pixel then return LAYOUTS.perfectpixel end
	return LAYOUTS.vanilla
end

AoM.ActiveLayout = ActiveLayout
AoM.LAYOUTS = LAYOUTS
local CHECKBOX_BUTTON_AND_LABEL_PADDING = 16 + 8


local function CheckboxBlockWidth(checkbox)
	local label_width = (checkbox.label and checkbox.label:GetTextWidth()) or 150
	return CHECKBOX_BUTTON_AND_LABEL_PADDING + label_width
end

local FOOTER_FONT = "ZoFontDialogKeybindDescription"
local MAX_SANE_LABEL_WIDTH = 600

local function BindingsLabelWidth(label)
	local width
	if type(label.GetTextWidth) == "function" then width = label:GetTextWidth() end
	if (not width or width <= 0) and type(label.GetWidth) == "function" then width = label:GetWidth() end
	if not width or width <= 0 or width > MAX_SANE_LABEL_WIDTH then return nil end
	return width
end

local function SetKeybindFont(button)
	if not button then return end
	if type(button.SetNameFont) == "function" then
		button:SetNameFont(FOOTER_FONT)
		return
	end
	local label = button:GetNamedChild("NameLabel")
	if label then label:SetFont(FOOTER_FONT) end
end

local function FitsOnRow(last_control, button, list)
	if not last_control or not button or not list then return false end
	if type(last_control.GetRight) ~= "function" or type(button.GetWidth) ~= "function" then return false end
	local row_right = last_control:GetRight()
	local button_width = button:GetWidth()
	local limit = list:GetRight()
	if not row_right or not button_width or not limit then return false end
	if row_right <= 0 or button_width <= 0 or limit <= 0 then return false end
	return row_right + ActiveLayout().footerGap + button_width <= limit
end

local function PlaceFooterRow(win)
	local bindings_lbl = win:GetNamedChild("CurrentBindingsSaved")
	local secondary_btn = win:GetNamedChild("SecondaryButton")
	local primary_btn = win:GetNamedChild("PrimaryButton")
	local list = win:GetNamedChild("List")
	if not bindings_lbl or not secondary_btn then return end

	SetKeybindFont(secondary_btn)
	SetKeybindFont(primary_btn)
	SetKeybindFont(native_reset_btn)
	SetKeybindFont(native_reset_categories_btn)

	local label_width = BindingsLabelWidth(bindings_lbl)
	if not list or not label_width then
		local row_height = suppress_errors_checkbox and suppress_errors_checkbox:GetHeight()
		if not row_height or row_height < 20 then row_height = 20 end
		bindings_lbl:ClearAnchors()
		bindings_lbl:SetAnchor(BOTTOMLEFT, secondary_btn, TOPLEFT, 0, -5 - (row_height + 10))
		return
	end

	secondary_btn:ClearAnchors()
	local layout = ActiveLayout()
	secondary_btn:SetAnchor(TOPLEFT, list, BOTTOMLEFT, label_width + layout.footerGap, layout.rowDrop)
	bindings_lbl:ClearAnchors()
	bindings_lbl:SetAnchor(RIGHT, secondary_btn, LEFT, -layout.footerGap, 0)

	local row_end = secondary_btn
	if native_reset_btn then
		native_reset_btn:ClearAnchors()
		native_reset_btn:SetAnchor(LEFT, row_end, RIGHT, layout.footerGap, 0)
		row_end = native_reset_btn
	end
	if native_reset_categories_btn then
		native_reset_categories_btn:ClearAnchors()
		native_reset_categories_btn:SetAnchor(LEFT, row_end, RIGHT, layout.footerGap, 0)
		row_end = native_reset_categories_btn
	end

	if primary_btn then
		primary_btn:ClearAnchors()
		if FitsOnRow(row_end, primary_btn, list) then
			primary_btn:SetAnchor(LEFT, row_end, RIGHT, layout.footerGap, 0)
		else
			primary_btn:SetAnchor(TOPLEFT, row_end, BOTTOMLEFT, 0, layout.stackGap)
		end
	end

end

local MAX_KEYBIND_BUTTON_WIDTH = 400
local MAX_FOOTER_SHIFT = 200
local MAX_FILTER_ALIGN_SHIFT = 200

local function ReloadRightOffset(win, list)
	local edge_inset = ActiveLayout().reloadEdgeInset
	if not edge_inset or not win or not list then return 0 end
	if type(list.GetRight) ~= "function" or type(win.GetRight) ~= "function" then return 0 end
	local list_right, win_right = list:GetRight(), win:GetRight()
	if type(list_right) ~= "number" or type(win_right) ~= "number" then return 0 end
	local shift = (win_right - edge_inset) - list_right
	if math.abs(shift) > MAX_FOOTER_SHIFT then return 0 end
	return shift
end

local function FooterReference(win, list)
	local layout = ActiveLayout()
	if layout.footerAnchorTo == "window" and win then
		return win, layout.edgeInset
	end
	return list, nil
end

local function FooterRowLeftOffset(win, list)
	local edge_inset = ActiveLayout().edgeInset
	if not win or not list or edge_inset <= 0 then return 0 end
	if type(list.GetLeft) ~= "function" or type(win.GetLeft) ~= "function" then return 0 end
	local list_left, win_left = list:GetLeft(), win:GetLeft()
	if type(list_left) ~= "number" or type(win_left) ~= "number" then return 0 end
	local shift = edge_inset - (list_left - win_left)
	if math.abs(shift) > MAX_FOOTER_SHIFT then return 0 end
	return shift
end
local FALLBACK_KEYBIND_BUTTON_WIDTH = 120

local function PlaceFooterRowAddonSelector(win)
	local bindings_lbl = win:GetNamedChild("CurrentBindingsSaved")
	local secondary_btn = win:GetNamedChild("SecondaryButton")
	local primary_btn = win:GetNamedChild("PrimaryButton")
	local list = win:GetNamedChild("List")
	if not list or not primary_btn or not secondary_btn then return end

	local search_btn = _G["AddonSelectorStartAddonSearchButton"]
	local toggle_btn = _G["AddonSelectorToggleAddonStateButton"]
	if search_btn then search_btn:SetHidden(true) end
	if toggle_btn then toggle_btn:SetHidden(true) end

	local layout = ActiveLayout()
	local anchor_to, fixed_x = FooterReference(win, list)
	local row_x = fixed_x or FooterRowLeftOffset(win, list)

	SetKeybindFont(primary_btn)
	primary_btn:ClearAnchors()
	local reload_x = ReloadRightOffset(win, list)
	local last_checkbox = AoM.last_footer_checkbox
	local follows = layout.reloadFollowsCheckboxes and last_checkbox
		and type(last_checkbox.GetRight) == "function" and type(primary_btn.GetWidth) == "function"
		and type(list.GetRight) == "function" and type(win.GetRight) == "function"
	local extra = layout.reloadExtraRight or 0
	local label_run = 0
	if follows then
		label_run = CheckboxBlockWidth(last_checkbox) - CHECKBOX_BUTTON_AND_LABEL_PADDING
		local right_edge = last_checkbox:GetRight() + label_run + layout.checkboxGap + extra
			+ primary_btn:GetWidth()
		local limit = win:GetRight() - (layout.reloadEdgeInset or 0)
		follows = type(right_edge) == "number" and type(limit) == "number" and right_edge <= limit
	end
	if follows then
		primary_btn:SetAnchor(LEFT, last_checkbox, RIGHT, label_run + layout.checkboxGap + extra, 0)
	elseif fixed_x then
		primary_btn:SetAnchor(TOPRIGHT, anchor_to, BOTTOMRIGHT, -(layout.reloadEdgeInset or 0) + extra,
			layout.reloadDrop)
	else
		primary_btn:SetAnchor(TOPRIGHT, list, BOTTOMRIGHT, reload_x + extra, layout.reloadDrop)
	end

	if bindings_lbl then
		bindings_lbl:ClearAnchors()
		if layout.labelUnderReload then
			bindings_lbl:SetAnchor(TOPRIGHT, primary_btn, BOTTOMRIGHT, 0, layout.labelUnderReloadGap or 6)
		else
			bindings_lbl:SetAnchor(LEFT, anchor_to, BOTTOMLEFT, row_x, layout.labelDrop)
		end
	end

	local select_all = _G["AddonSelectorSelectAddonsButton"]
	local deselect_all = _G["AddonSelectorDeselectAddonsButton"]
	local row_start

	if select_all then
		SetKeybindFont(select_all)
		select_all:ClearAnchors()
		select_all:SetAnchor(TOPLEFT, anchor_to, BOTTOMLEFT, row_x, layout.keybindDrop)
		row_start = select_all
	end

	if deselect_all then
		SetKeybindFont(deselect_all)
		deselect_all:ClearAnchors()
		local offset = row_x
		if select_all then
			local width = type(select_all.GetWidth) == "function" and select_all:GetWidth() or nil
			if type(width) ~= "number" or width <= 0 or width > MAX_KEYBIND_BUTTON_WIDTH then
				width = FALLBACK_KEYBIND_BUTTON_WIDTH
			end
			offset = row_x + width + layout.footerGap
		end
		deselect_all:SetAnchor(TOPLEFT, anchor_to, BOTTOMLEFT, offset, layout.keybindDrop)
		row_start = deselect_all
	end

	local previous = row_start
	for _, button in ipairs({ secondary_btn, native_reset_btn, native_reset_categories_btn }) do
		if button then
			SetKeybindFont(button)
			button:ClearAnchors()
			if previous then
				button:SetAnchor(LEFT, previous, RIGHT, layout.footerGap, 0)
			else
				button:SetAnchor(TOPLEFT, anchor_to, BOTTOMLEFT, row_x, layout.keybindDrop)
			end
			previous = button
		end
	end
end

local function PlaceBottomCheckboxes()
	local win = ADD_ON_MANAGER.control
	local primary_btn = win:GetNamedChild("PrimaryButton")
	if not primary_btn or not auto_disable_checkbox or not suppress_errors_checkbox then return end

	local layout = ActiveLayout()
	local chain = { suppress_errors_checkbox }
	if priority_save_checkbox then chain[#chain + 1] = priority_save_checkbox end
	chain[#chain + 1] = auto_disable_checkbox
	local native = win:GetNamedChild("AdvancedUIErrors")
	if native and not native:IsHidden() then chain[#chain + 1] = native end

	local total = 0
	for index, checkbox in ipairs(chain) do
		total = total + CheckboxBlockWidth(checkbox)
		if index > 1 then total = total + layout.checkboxGap end
	end

	placing_advanced_ui_errors = true
	local list = win:GetNamedChild("List")
	local anchor_to, fixed_x = FooterReference(win, list)
	local from_left = layout.footerStyle == "stacked" and anchor_to ~= nil
	local row_x = from_left and (fixed_x or FooterRowLeftOffset(win, list)) or 0
	local gap = layout.checkboxGap

	if from_left and #chain > 1 and type(primary_btn.GetLeft) == "function"
		and type(list.GetLeft) == "function" then
		local reload_limit = primary_btn:GetLeft()
		if layout.reloadEdgeInset and type(win.GetRight) == "function" and type(primary_btn.GetWidth) == "function" then
			local edge = win:GetRight() - layout.reloadEdgeInset - primary_btn:GetWidth()
			if type(edge) == "number" and edge > 0 then reload_limit = edge end
		end
		local row_left = fixed_x and (win:GetLeft() + row_x) or (list:GetLeft() + row_x)
		local room = reload_limit - layout.footerGap - row_left
		local widths = total - layout.checkboxGap * (#chain - 1)
		if type(room) == "number" and room > 0 and widths > 0 and room < total then
			gap = math.max(layout.minCheckboxGap, math.floor((room - widths) / (#chain - 1)))
		end
	end

	local offset = from_left and row_x or -total
	for _, checkbox in ipairs(chain) do
		checkbox:SetHidden(false)
		checkbox:ClearAnchors()
		if from_left then
			checkbox:SetAnchor(TOPLEFT, anchor_to, BOTTOMLEFT, offset, layout.checkboxDrop)
		else
			checkbox:SetAnchor(BOTTOMLEFT, primary_btn, TOPRIGHT, offset, -2)
		end
		offset = offset + CheckboxBlockWidth(checkbox) + gap
		AoM.last_footer_checkbox = checkbox
	end
	placing_advanced_ui_errors = false

	if layout.footerStyle == "stacked" then
		PlaceFooterRowAddonSelector(win)
	else
		PlaceFooterRow(win)
	end
end

local LIST_BOTTOM_MARGIN = 100
local list_reanchored = false

local function ReserveListSpace()
	if list_reanchored or IsAddonSelectorRunning() then return end
	local win = ADD_ON_MANAGER.control
	local list = win:GetNamedChild("List")
	if not list or not addon_count_lbl then return end
	if addon_count_lbl:GetBottom() <= 0 then return end

	local has_second, point, relative_to, relative_point, offset_x, offset_y = list:GetAnchor(1)
	list:ClearAnchors()
	list:SetAnchor(TOPLEFT, addon_count_lbl, BOTTOMLEFT, -2, 14)
	if has_second and relative_to ~= win:GetNamedChild("PrimaryButton") then
		list:SetAnchor(point, relative_to, relative_point, offset_x, offset_y)
	else
		list:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -20, -LIST_BOTTOM_MARGIN)
	end
	list_reanchored = true
end

local addon_selector_count_hooked = false

local function HookAddonSelectorCounter()
	if addon_selector_count_hooked then return end
	local global_table = _G["AddonSelectorGlobal"]
	local utility = global_table and global_table.utility
	if not utility or type(utility.AddonSelectorUpdateCount) ~= "function" then return end
	addon_selector_count_hooked = true
	ZO_PostHook(utility, "AddonSelectorUpdateCount", function(delay)
		zo_callLater(ApplyTitleCounters, (tonumber(delay) or 0) + 100)
	end)
end

local function MoveAddonSelectorCogwheel()
	local as_cogwheel = _G["AddonSelectorSettingsOpenDropdown"]
	if not as_cogwheel or not ADD_ON_MANAGER or not ADD_ON_MANAGER.control then return end
	as_cogwheel:ClearAnchors()
	local title = ADD_ON_MANAGER.control:GetNamedChild("Title")
	local search_box = _G["AoMAddonSearchBox"]
	if search_box then
		as_cogwheel:SetAnchor(RIGHT, search_box, LEFT, -14 + (ActiveLayout().asCogwheelNudge or 0), 0)
	elseif title then
		as_cogwheel:SetAnchor(LEFT, title, RIGHT, 40, 0)
	else
		as_cogwheel:SetAnchor(TOPRIGHT, ADD_ON_MANAGER.control, TOPRIGHT, -10, 32)
	end
end

function AoM.RefreshUnusedSavedVariablesButton()
	if not unused_saved_variables_btn then return end
	local unused = AoM.GetUnusedSavedVariablesMB and AoM.GetUnusedSavedVariablesMB() or 0
	unused_saved_variables_btn:SetHidden(unused <= 0)
	if unused > 0 then
		unused_saved_variables_btn:SetText(AoM.L("ORPHANED_SAVES") .. AoM.FormatSavedVariablesUsageShort(unused))
		FitButtonToText(unused_saved_variables_btn, UNUSED_SAVES_MIN_WIDTH)
	end
	AoM.PlaceProfileControls()
end


local function PlaceHeaderRow()
	local win = ADD_ON_MANAGER and ADD_ON_MANAGER.control
	local title = win and win:GetNamedChild("Title")
	local search_box = _G["AoMAddonSearchBox"]
	local container = AoM.category_filter_dropdown_container
	if not title or not search_box or not container then return end

	local layout = ActiveLayout()
	if not layout.hideTitle then
		title:SetHidden(false)
		return
	end

	title:SetHidden(true)
	search_box:ClearAnchors()
	search_box:SetAnchor(LEFT, title, LEFT, layout.titleRowInset, layout.titleRowLift + layout.searchRowDrop)
	container:ClearAnchors()
	container:SetAnchor(LEFT, search_box, RIGHT, 10, 0)
	local align_x = 0
	if layout.alignFilterToPackBox then
		local pack_box = _G["AddonSelectorEditBoxBg"] or _G["AddonSelectorEditBox"]
		local edge = layout.alignFilterToPackBox == "left" and "GetLeft" or "GetRight"
		if pack_box and type(pack_box[edge]) == "function" and type(container[edge]) == "function" then
			local delta = pack_box[edge](pack_box) - container[edge](container)
			if type(delta) == "number" and math.abs(delta) <= MAX_FILTER_ALIGN_SHIFT then
				align_x = delta
				container:ClearAnchors()
				container:SetAnchor(LEFT, search_box, RIGHT, 10 + align_x, 0)
			end
		end
	end

	if native_new_category_btn then
		native_new_category_btn:ClearAnchors()
		native_new_category_btn:SetAnchor(LEFT, container, RIGHT, 20 - align_x, -layout.searchRowDrop)
	end

	local divider = layout.hideDivider and win:GetNamedChild("Divider") or nil
	if divider then
		divider:SetHidden(true)
	end

	local as_container = _G["AddonSelector"]
	if as_container and divider and type(as_container.SetAnchor) == "function" then
		as_container:ClearAnchors()
		as_container:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 10, layout.containerLift)
	end
end

AoM.PlaceHeaderRow = PlaceHeaderRow

local function PlaceCounterRow()
	if not addon_count_lbl or not library_count_lbl then return end
	local selected_lbl = _G["AddonSelectorSelectedPackNameLabel"]
	local select_lbl = _G["AddonSelectorSelectLabel"]
	if not IsAddonSelectorRunning() or not selected_lbl or not select_lbl then
		addon_count_lbl:SetFont("ZoFontGameSmall")
		library_count_lbl:SetFont("ZoFontGameSmall")
		if save_size_lbl then save_size_lbl:SetFont("ZoFontGameSmall") end
		return
	end

	local gap = ActiveLayout().counterGap
	addon_count_lbl:SetFont("ZoFontWinH5")
	library_count_lbl:SetFont("ZoFontWinH5")
	addon_count_lbl:ClearAnchors()
	addon_count_lbl:SetAnchor(TOPLEFT, select_lbl, BOTTOMLEFT, 0, 5)
	library_count_lbl:ClearAnchors()
	library_count_lbl:SetAnchor(LEFT, addon_count_lbl, RIGHT, gap, 0)
	local last = library_count_lbl
	if save_size_lbl then
		save_size_lbl:SetFont("ZoFontWinH5")
		save_size_lbl:ClearAnchors()
		save_size_lbl:SetAnchor(LEFT, library_count_lbl, RIGHT, gap, 0)
		if not save_size_lbl:IsHidden() then last = save_size_lbl end
	end
	selected_lbl:ClearAnchors()
	selected_lbl:SetAnchor(LEFT, last, RIGHT, gap, 0)
end

AoM.PlaceCounterRow = PlaceCounterRow

function AoM.PlaceProfileControls()
	local arrow = AoM.profile_arrow
	local cogwheel = AoM.profile_settings_button
	local win = ADD_ON_MANAGER and ADD_ON_MANAGER.control
	if not win or not arrow then return end

	arrow:ClearAnchors()
	if not cogwheel then
		arrow:SetAnchor(TOPRIGHT, win, TOPRIGHT, -14, 14)
		return
	end

	cogwheel:ClearAnchors()
	local row_end = _G["AoMDisableUnusedButton"]
	if unused_saved_variables_btn and not unused_saved_variables_btn:IsHidden() then
		row_end = unused_saved_variables_btn
	end
	if row_end then
		cogwheel:SetAnchor(LEFT, row_end, RIGHT, 8, 0)
	else
		cogwheel:SetAnchor(TOPRIGHT, win, TOPRIGHT, -44, 14)
	end
	arrow:SetAnchor(LEFT, cogwheel, RIGHT, 8, 0)
end

local function LayoutAddonWindow()
	ReserveListSpace()
	PlaceBottomCheckboxes()
	AoM.RefreshUnusedSavedVariablesButton()
	PlaceHeaderRow()
	PlaceCounterRow()
	if IsAddonSelectorRunning() then
		HookAddonSelectorCounter()
		StartTitleWatch()
		MoveAddonSelectorCogwheel()
		zo_callLater(function()
			if ADD_ON_MANAGER and ADD_ON_MANAGER.control then PlaceFooterRowAddonSelector(ADD_ON_MANAGER.control) end
			PlaceHeaderRow()
			PlaceCounterRow()
		end, 0)
	end
end
AoM.LayoutAddonWindow = LayoutAddonWindow

do
	local checkbox = ADD_ON_MANAGER.control and ADD_ON_MANAGER.control:GetNamedChild("AdvancedUIErrors")
	if checkbox then
		ZO_PostHookHandler(checkbox, "OnRectChanged", function()
			if placing_advanced_ui_errors then return end
			PlaceBottomCheckboxes()
		end)
	end
end

if ADDONS_FRAGMENT then
	ADDONS_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWING then
			if auto_disable_checkbox then ZO_CheckButton_SetCheckState(auto_disable_checkbox, AoM.IsAutoDisableUnusedEnabled()) end
			if suppress_errors_checkbox then ZO_CheckButton_SetCheckState(suppress_errors_checkbox, AoM.IsSuppressingLuaErrors()) end
			if priority_save_checkbox then ZO_CheckButton_SetCheckState(priority_save_checkbox, AoM.IsPrioritySaveEnabled()) end
			PopulateCategoryFilterDropdown()
			RefreshAddonCounters()
			AoM.RefreshProfileControls()
			RefreshAddedControlsOnFirstShow()
			LayoutAddonWindow()
		elseif newState == SCENE_FRAGMENT_SHOWN then
			LayoutAddonWindow()
		elseif newState == SCENE_FRAGMENT_HIDING then
			StopTitleWatch()
		elseif newState == SCENE_FRAGMENT_HIDDEN then
			LibAPH.StepCleanup(1)
		end
	end)
end
