--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
local LibAPH = LibAPH

local ADDON_DATA = 1
local HEADER_DATA = 2
local LIBRARIES = "Libraries"
local GAMEPAD_STATUS_ICON_SIZE = ZO_GAMEPAD_LIST_ICON_SIZE or 64
local GAMEPAD_STATUS_ICON_FOCUS_SCALE = 1.15
local GAMEPAD_STATUS_ICON_GAP = 2
local GAMEPAD_STATUS_STRIP_INSET = 6
local GAMEPAD_AUTHOR_MIN_WIDTH = 120
local GAMEPAD_AUTHOR_GAP = 8
local OPTIONS_DIALOG = "ADDON_MANAGER_OPTIONS_GAMEPAD"

local am = GetAddOnManager()

local SORT_KEYS = {
	addOnFileName = {},
	strippedAddOnName = { tiebreaker = "addOnFileName" },
}

local function SortAddons(entry1, entry2)
	return ZO_TableOrderingFunction(entry1, entry2, "strippedAddOnName", SORT_KEYS, ZO_SORT_ORDER_UP)
end

local function IsAddonEnabled(index)
	local _, _, _, _, enabled = am:GetAddOnInfo(index)
	return enabled
end

local function ColorToHex(color)
	return string.format("%02X%02X%02X", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

local function ReleaseDialog(dialogId)
	ZO_Dialogs_ReleaseDialogOnButtonPress(dialogId)
end

function AoM.ShowGamepadTextEntryDialog(title, prompt, initialText, onConfirm, onCancel)
	LibAPH.ShowGamepadTextEntry({ title = title, prompt = prompt, initialText = initialText, onConfirm = onConfirm, onCancel = onCancel })
end

local function ShowGamepadPickerDialog(title, choices)
	LibAPH.ShowGamepadPicker({ title = title, choices = choices })
end

local function GamepadTitleLabel(manager)
	local control = manager and manager.control
	if not control or type(control.GetNamedChild) ~= "function" then return nil end
	local container = control:GetNamedChild("TitleContainer")
	if not container or type(container.GetNamedChild) ~= "function" then return nil end
	local label = container:GetNamedChild("Title")
	if not label or type(label.SetText) ~= "function" then return nil end
	return label
end

local function RefreshGamepadTitle(manager)
	if not manager then return end
	local filter = AoM.GetCategoryFilter and AoM.GetCategoryFilter()
	local title = GetString(SI_WINDOW_TITLE_ADDON_MANAGER)
	if filter and filter ~= AoM.FILTER_ALL then
		title = AoM.GetCategoryFilterDisplayName(filter)
	end
	if manager.headerData and manager.headerData.titleText ~= title then
		manager.headerData.titleText = title
		if manager.header then ZO_GamepadGenericHeader_Refresh(manager.header, manager.headerData) end
	end
	local label = GamepadTitleLabel(manager)
	if label and label:GetText() ~= title then label:SetText(title) end
end
AoM.RefreshGamepadTitle = RefreshGamepadTitle

local function BuildCategoryGroups(manager)
	local groups, order = {}, {}

	if AoM.IsSavedVariablesSortActive() then
		local flat = {}
		for _, list in ipairs({ manager.addonList, manager.libraryList }) do
			for _, data in ipairs(list) do flat[#flat + 1] = data end
		end
		flat = AoM.FilterEntriesWithSavedVariables(flat, function(data) return data.addOnIndex end)
		AoM.SortEntriesBySavedVariables(flat,
			function(data) return data.addOnIndex end,
			function(data) return data.addOnFileName end)
		return { [AoM.FILTER_SAVED_VARIABLES] = flat }, { AoM.FILTER_SAVED_VARIABLES }
	end

	for _, list in ipairs({ manager.addonList, manager.libraryList }) do
		for _, data in ipairs(list) do
			local category = AoM.GetAddonCategory(data.addOnFileName)
			if AoM.CategoryMatchesFilter(data.isLibrary, IsAddonEnabled(data.addOnIndex), category, data.addOnIndex) then
				if not groups[category] then
					groups[category] = {}
					table.insert(order, category)
				end
				table.insert(groups[category], data)
			end
		end
	end
	table.sort(order, function(a, b)
		return string.lower(AoM.GetCategoryDisplayName(a)) < string.lower(AoM.GetCategoryDisplayName(b))
	end)
	return groups, order
end

ZO_PreHook(ZO_AddOnManager_Gamepad, "FilterScrollList", function(self)
	RefreshGamepadTitle(self)
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)
	local groups, order = BuildCategoryGroups(self)

	for _, category in ipairs(order) do
		local members = groups[category]
		table.sort(members, SortAddons)
		local header_name = AoM.GetCategoryDisplayName(category)
		table.insert(scrollData, ZO_ScrollList_CreateDataEntry(HEADER_DATA, ZO_EntryData:New({ name = header_name })))
		for i, data in ipairs(members) do
			local entryData = ZO_EntryData:New(data)
			entryData.headerText = (i == 1) and header_name or nil
			entryData.aom_category = category
			table.insert(scrollData, ZO_ScrollList_CreateDataEntry(ADDON_DATA, entryData))
		end
	end

	self.emptyLabel:SetHidden(#order > 0)
	return true
end)

ZO_PreHook(ZO_AddOnManager_Gamepad, "RefreshFooter", function(self)
	RefreshGamepadTitle(self)
	if not IsConsoleUI() then return end
	local addons_on, addons_total, libs_on, libs_total = AoM.GetAddonCounts()
	self.footerData = self.footerData or {}
	self.footerData.data1HeaderText = "Add-ons"
	self.footerData.data1Text = string.format("%d/%d", addons_on, addons_total)
	self.footerData.data2HeaderText = "Libraries"
	self.footerData.data2Text = string.format("%d/%d", libs_on, libs_total)
	local save_size = AoM.GetSaveSizeValue and AoM.GetSaveSizeValue()
	self.footerData.data3HeaderText = save_size and "Save Size" or nil
	self.footerData.data3Text = save_size
end)

local icon_focus = { data = nil, slot = 0 }

local function GetFocusSlot(data)
	if data and icon_focus.data == data then return icon_focus.slot end
	return 0
end

local function ApplyIconFocus(control, data)
	if not control or not control.aom_status_icons then return end
	local slot = GetFocusSlot(data)
	for i, icon in ipairs(control.aom_status_icons) do
		LibAPH.SetStatusIconFocused(icon, i == slot, GAMEPAD_STATUS_ICON_FOCUS_SCALE)
	end
end

local function DependencyRowOffset()
	local pad = ZO_GAMEPAD_INTERACTIVE_FILTER_LIST_HEADER_DOUBLE_PADDING_X or 0
	return (ZO_GAMEPAD_INTERACTIVE_FILTER_HIGHLIGHT_PADDING or 0)
		+ (ZO_GAMEPAD_ADDON_MANAGER_ENABLED_WIDTH or 0) + pad
		+ (ZO_GAMEPAD_ADDON_MANAGER_ADDON_NAME_WIDTH or 0) + pad
		+ (ZO_GAMEPAD_ADDON_MANAGER_AUTHOR_WIDTH or 0) + pad
end

local function PinDependencySlot(control)
	if control.aom_dependency_pinned then return end
	local offset = DependencyRowOffset()
	if offset <= 0 then return end
	control.aom_dependency_pinned = true
	control.dependencyIcon:ClearAnchors()
	control.dependencyIcon:SetAnchor(LEFT, control, LEFT, offset, 0)
end

local function TrimAuthorForIcons(control, iconCount)
	local author = control.authorNameLabel
	if type(author) ~= "table" and type(author) ~= "userdata" then return end
	if type(author.SetWidth) ~= "function" or type(author.GetWidth) ~= "function" then return end
	control.aom_author_width = control.aom_author_width or author:GetWidth()
	if not control.aom_author_width or control.aom_author_width <= 0 then return end
	local reserved = 0
	if iconCount > 0 then
		local strip = iconCount * GAMEPAD_STATUS_ICON_SIZE + (iconCount - 1) * GAMEPAD_STATUS_ICON_GAP
		reserved = strip + GAMEPAD_STATUS_STRIP_INSET + GAMEPAD_AUTHOR_GAP
			- (ZO_GAMEPAD_ADDON_MANAGER_EXTRA_INFO_WIDTH or 0)
			- (ZO_GAMEPAD_INTERACTIVE_FILTER_LIST_HEADER_DOUBLE_PADDING_X or 0)
		if reserved < 0 then reserved = 0 end
	end
	author:SetWidth(math.max(GAMEPAD_AUTHOR_MIN_WIDTH, control.aom_author_width - reserved))
end

local function UpdateGamepadStatusIcons(control, data)
	if not control.dependencyIcon then return end
	if not control.aom_status_icons then
		control.aom_status_icons = LibAPH.CreateStatusIconStrip(control, false, 7, GAMEPAD_STATUS_ICON_SIZE)
		for _, icon in ipairs(control.aom_status_icons) do
			icon:SetMouseEnabled(false)
		end
	end
	PinDependencySlot(control)
	control.dependencyIcon:SetHidden(true)
	local icons = data.addOnIndex and AoM.GetStatusIconsForAddon(am, data.addOnIndex) or {}
	LibAPH.UpdateStatusIconStrip(control.aom_status_icons, control.dependencyIcon, icons, true, -GAMEPAD_STATUS_STRIP_INSET, RIGHT)
	control.aom_icon_count = #icons
	TrimAuthorForIcons(control, #icons)
	ApplyIconFocus(control, data)
end

local function MoveIconFocus(manager, direction)
	local data = manager:GetSelectedData()
	local control = ZO_ScrollList_GetSelectedControl(manager.list)
	local count = control and control.aom_icon_count or 0
	if not data or not data.addOnIndex or count == 0 then return end
	local slot = GetFocusSlot(data)
	if direction > 0 then
		slot = (slot == 0) and count or slot - 1
	else
		slot = (slot == 0) and 1 or slot + 1
		if slot > count then slot = 0 end
	end
	icon_focus.data, icon_focus.slot = data, slot
	ApplyIconFocus(control, data)
	manager:UpdateTooltip()
	manager:UpdateKeybinds()
end

local function GetFocusedIcon(manager)
	local data = manager:GetSelectedData()
	local slot = GetFocusSlot(data)
	if slot == 0 or not data.addOnIndex then return nil end
	return AoM.GetStatusIconsForAddon(am, data.addOnIndex)[slot]
end

local function SelectedRowHasIcons(manager)
	local control = ZO_ScrollList_GetSelectedControl(manager.list)
	return control ~= nil and (control.aom_icon_count or 0) > 0
end

local function RefreshSelectedRowIcons(manager)
	local data = manager:GetSelectedData()
	local control = ZO_ScrollList_GetSelectedControl(manager.list)
	icon_focus.data, icon_focus.slot = nil, 0
	if control and data then UpdateGamepadStatusIcons(control, data) end
	manager:UpdateTooltip()
	manager:UpdateKeybinds()
end

local ICON_ACTIONS = {
	error = {
		name = AoM.L("SHOW_ERROR"),
		consoleOnly = true,
		callback = function(manager, data)
			local _ = manager
			AoM.ShowNativeErrorsForAddon(am, data.addOnIndex)
		end,
	},
	toggle = {
		name = function(icon) return icon.action_name end,
		callback = function(manager, _, icon)
			icon.onClick()
			manager:MarkDirty()
			RefreshSelectedRowIcons(manager)
		end,
	},
	savedvariables = {
		name = AoM.L("DELETE_SETTINGS"),
		callback = function(manager, data)
			local name, title = am:GetAddOnInfo(data.addOnIndex)
			local display_name = LibAPH.StripColors(title or name)
			AoM.ConfirmDeleteSavedVariables(data.addOnIndex, display_name, function()
				RefreshSelectedRowIcons(manager)
			end)
		end,
	},
}

local function GetFocusedIconAction(manager)
	local icon = GetFocusedIcon(manager)
	local action = icon and icon.kind and ICON_ACTIONS[icon.kind]
	if not action then return nil end
	if action.consoleOnly and not IsConsoleUI() then return nil end
	return action, icon
end

local function AddIconFocusKeybinds(manager)
	local strip = manager.keybindStripDescriptor
	if not strip or strip.aom_icon_focus_keybinds then return end
	strip.aom_icon_focus_keybinds = true
	table.insert(strip, {
		name = AoM.L("STATUS_ICONS"),
		keybind = "UI_SHORTCUT_INPUT_RIGHT",
		visible = function() return SelectedRowHasIcons(manager) end,
		callback = function() MoveIconFocus(manager, 1) end,
	})
	table.insert(strip, {
		keybind = "UI_SHORTCUT_INPUT_LEFT",
		visible = function() return SelectedRowHasIcons(manager) end,
		callback = function() MoveIconFocus(manager, -1) end,
	})
	table.insert(strip, {
		name = function()
			local action, icon = GetFocusedIconAction(manager)
			if not action then return "" end
			if type(action.name) == "function" then return action.name(icon) or "" end
			return action.name
		end,
		keybind = "UI_SHORTCUT_RIGHT_STICK",
		visible = function() return GetFocusedIconAction(manager) ~= nil end,
		callback = function()
			local action, icon = GetFocusedIconAction(manager)
			local data = manager:GetSelectedData()
			if action and data and data.addOnIndex then action.callback(manager, data, icon) end
		end,
	})
end

ZO_PreHook(ZO_AddOnManager_Gamepad, "OnSelectionChanged", function(manager, oldData, newData)
	if icon_focus.data and icon_focus.data ~= newData then
		local old_data = icon_focus.data
		icon_focus.data, icon_focus.slot = nil, 0
		ApplyIconFocus(ZO_ScrollList_GetDataControl(manager.list, old_data), old_data)
	end
end)

ZO_PostHook(ZO_AddOnManager_Gamepad, "OnSelectionChanged", function(manager)
	manager:UpdateKeybinds()
end)

ZO_PostHook(ZO_AddOnManager_Gamepad, "SetupRow", function(self, control, data)
	UpdateGamepadStatusIcons(control, data)
end)

local function AddVersionSection(tooltip, data)
	if not data.addOnIndex then return end
	local is_out_of_date = select(7, am:GetAddOnInfo(data.addOnIndex))
	local lines, status = AoM.GetVersionLines(am, data.addOnIndex, data.addOnFileName, is_out_of_date)
	local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
	section:AddLine("Version", tooltip:GetStyle("bodyHeader"))
	for _, line in ipairs(lines) do
		section:AddLine(line, tooltip:GetStyle("bodyDescription"))
	end
	section:AddLine(AoM.GetApiLine(status), tooltip:GetStyle("bodyDescription"))
	tooltip:AddSection(section)
end

local function AddStatusSection(tooltip, data)
	if not data.addOnIndex then return end
	local icons = AoM.GetStatusIconsForAddon(am, data.addOnIndex)
	local lines = {}
	for _, icon in ipairs(icons) do
		table.insert(lines, "|c" .. ColorToHex(icon.color) .. icon.tooltip .. "|r")
	end
	if #lines > 0 then
		local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
		section:AddLine("Status", tooltip:GetStyle("bodyHeader"))
		for _, line in ipairs(lines) do
			section:AddLine(line, tooltip:GetStyle("bodyDescription"))
		end
		tooltip:AddSection(section)
	end
end

local function LayoutFocusedIcon(tooltip, data)
	local slot = GetFocusSlot(data)
	if slot == 0 or not data.addOnIndex then return false end
	local icons = AoM.GetStatusIconsForAddon(am, data.addOnIndex)
	local icon = icons[slot]
	if not icon then return false end
	local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
	section:AddLine(string.format(AoM.L("STATUS"), #icons - slot + 1, #icons), tooltip:GetStyle("bodyHeader"))
	section:AddLine("|c" .. ColorToHex(icon.color) .. icon.tooltip .. "|r", tooltip:GetStyle("bodyDescription"))
	tooltip:AddSection(section)
	return true
end

local function AddLibrarySection(tooltip, data)
	for _, entry in ipairs(AoM.GetLibrarySections(am, data.addOnIndex, data.addOnFileName)) do
		local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
		section:AddLine(entry.title, tooltip:GetStyle("bodyHeader"))
		section:AddLine(entry.text, tooltip:GetStyle("bodyDescription"))
		tooltip:AddSection(section)
	end
end

local function HookGamepadTooltip()
	local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
	if not tooltip or tooltip.aom_tooltip_hooked then return end
	tooltip.aom_tooltip_hooked = true
	ZO_PreHook(tooltip, "LayoutAddOnTooltip", function(tt, data)
		if data and data.addOnDependencyText and data.addOnDependencyText ~= "" then
			data.aom_stashed_dependency_text = data.addOnDependencyText
			data.addOnDependencyText = ""
		end
		tt.aom_focused_layout = data ~= nil and LayoutFocusedIcon(tt, data)
		return tt.aom_focused_layout
	end)
	ZO_PostHook(tooltip, "LayoutAddOnTooltip", function(tt, data)
		if data and data.aom_stashed_dependency_text then
			data.addOnDependencyText = data.aom_stashed_dependency_text
			data.aom_stashed_dependency_text = nil
		end
	end)
	ZO_PostHook(tooltip, "LayoutAddOnTooltip", function(tt, data)
		if tt.aom_focused_layout or not data or not data.addOnFileName then return end
		AddVersionSection(tt, data)
		AddLibrarySection(tt, data)
		AddStatusSection(tt, data)
	end)
end

local function SuppressVotanUsedBySection()
	local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
	if not tooltip or tooltip.aom_votan_suppressed then return end
	if not LibAPH.IsAddonActiveAndRunning("LibVotansAddonList") then return end
	tooltip.aom_votan_suppressed = true
	ZO_PostHook(tooltip, "LayoutAddOnTooltip", function(tt, data)
		if data and data.aom_stashed_used_by ~= nil then
			data.usedBy = data.aom_stashed_used_by
			data.aom_stashed_used_by = nil
		end
	end)
	ZO_PreHook(tooltip, "LayoutAddOnTooltip", function(tt, data)
		if data and data.usedBy ~= nil then
			data.aom_stashed_used_by = data.usedBy
			data.usedBy = nil
		end
	end)
end

local function GetAddonIndexMap()
	local map = {}
	for i = 1, am:GetNumAddOns() do
		map[am:GetAddOnInfo(i)] = i
	end
	return map
end

local function GetCategoryEntries(category)
	local index_by_name = GetAddonIndexMap()
	local entries = {}
	for _, name in ipairs(AoM.GetAddonsInCategory(category)) do
		if index_by_name[name] then table.insert(entries, { index = index_by_name[name] }) end
	end
	return entries
end

local function IsCategoryFullyEnabled(category)
	for _, entry in ipairs(GetCategoryEntries(category)) do
		if not IsAddonEnabled(entry.index) then return false end
	end
	return true
end

local search = { needle = nil, pos = 0 }

local function Notify(sound, text)
	if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, text) end
end

local function FindSearchMatches(manager)
	local matches = {}
	if not search.needle or search.needle == "" then return matches end
	local scrollData = ZO_ScrollList_GetDataList(manager.list)
	for i, entry in ipairs(scrollData) do
		local data = entry.data
		if data and data.addOnFileName and string.find(string.lower(data.strippedAddOnName or data.addOnName or ""), search.needle, 1, true) then
			table.insert(matches, i)
		end
	end
	return matches
end

local function SelectSearchMatch(manager, step)
	local matches = FindSearchMatches(manager)
	if #matches == 0 then
		Notify(SOUNDS.NEGATIVE_CLICK, AoM.L("NO_ADD_ON_OR_LIBRARY_NAME") .. (search.needle or "") .. "\".")
		search.needle = nil
		search.pos = 0
		manager:UpdateKeybinds()
		return
	end
	search.pos = ((search.pos - 1 + step) % #matches) + 1
	local scrollData = ZO_ScrollList_GetDataList(manager.list)
	local data = scrollData[matches[search.pos]].data
	if not manager:IsActivated() then manager:Activate(true) end
	local ANIMATE_INSTANTLY = true
	ZO_ScrollList_SelectDataAndScrollIntoView(manager.list, data, nil, ANIMATE_INSTANTLY)
	manager:UpdateKeybinds()
	Notify(SOUNDS.DEFAULT_CLICK, string.format(AoM.L("MATCH_OF"), search.pos, #matches, data.strippedAddOnName or data.addOnName or data.addOnFileName))
end

local function WhenDialogsHidden(fn)
	if not ZO_Dialogs_IsShowingDialog() then
		fn()
		return
	end
	local function handler()
		CALLBACK_MANAGER:UnregisterCallback("AllDialogsHidden", handler)
		fn()
	end
	CALLBACK_MANAGER:RegisterCallback("AllDialogsHidden", handler)
end

local function StartSearch(manager, text)
	search.needle = string.lower(text or "")
	search.pos = 0
	if search.needle == "" then return end
	WhenDialogsHidden(function() SelectSearchMatch(manager, 1) end)
end

local function HasSearchMatches(manager)
	return search.needle ~= nil and #FindSearchMatches(manager) > 0
end

local function AddSearchKeybinds(manager)
	local strip = manager.keybindStripDescriptor
	if not strip or strip.aom_search_keybinds then return end
	strip.aom_search_keybinds = true
	table.insert(strip, {
		name = AoM.L("PREVIOUS_MATCH"),
		keybind = "UI_SHORTCUT_LEFT_SHOULDER",
		visible = function() return HasSearchMatches(manager) end,
		callback = function() SelectSearchMatch(manager, -1) end,
	})
	table.insert(strip, {
		name = AoM.L("NEXT_MATCH"),
		keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
		visible = function() return HasSearchMatches(manager) end,
		callback = function() SelectSearchMatch(manager, 1) end,
	})
end

local function MakeEntry(text, callback, opts)
	local entry = {
		template = "ZO_GamepadFullWidthLeftLabelEntryTemplate",
		templateData = {
			text = text,
			setup = ZO_SharedGamepadEntry_OnSetup,
			callback = function(dialog)
				ReleaseDialog(OPTIONS_DIALOG)
				callback(dialog)
			end,
		},
	}
	if opts then
		if opts.header then
			entry.headerTemplate = "ZO_GamepadMenuEntryFullWidthHeaderTemplate"
			entry.header = opts.header
		end
		if opts.tooltipText then entry.templateData.tooltipText = opts.tooltipText end
		if opts.tooltipText then entry.templateData.narrationTooltip = GAMEPAD_LEFT_DIALOG_TOOLTIP end
	end
	return entry
end

local function AfterCategoryChange(manager)
	manager:MarkDirty()
	AoM.RefreshAllCategoryUI()
	manager:UpdateTooltip()
	manager:UpdateKeybinds()
end

local function MakeCheckboxEntry(text, isChecked, onToggle)
	return {
		template = "ZO_CheckBoxTemplate_WithoutIndent_Gamepad",
		text = text,
		templateData = {
			text = text,
			setup = ZO_GamepadCheckBoxTemplate_Setup,
			checked = isChecked,
			narrationText = ZO_GetDefaultParametricListToggleNarrationText,
			callback = function(dialog)
				local target = dialog.entryList and dialog.entryList:GetTargetControl()
				if not target then return end
				ZO_GamepadCheckBoxTemplate_OnClicked(target)
				onToggle(ZO_GamepadCheckBoxTemplate_IsChecked(target))
				SCREEN_NARRATION_MANAGER:QueueDialog(dialog)
			end,
		},
	}
end

local function AfterErrorsCleared(manager)
	manager:RefreshData()
	manager:UpdateTooltip()
end

local ShowProfileTriggerPicker
ShowProfileTriggerPicker = function(profileName)
	local choices = {}
	for _, trigger in ipairs(AoM.GetProfileTriggers()) do
		local on = AoM.GetProfileTriggerState(profileName, trigger.id)
		table.insert(choices, {
			text = (on and "[x] " or "[  ] ") .. trigger.label,
			callback = function()
				AoM.SetProfileTriggerState(profileName, trigger.id, not on)
				zo_callLater(function() ShowProfileTriggerPicker(profileName) end, 100)
			end,
		})
	end
	if AoM.GetProfileTriggerState(profileName, "group_friend") then
		for _, display_name in ipairs(AoM.GetFriendDisplayNames()) do
			local on = AoM.GetProfileTriggerFriend(profileName, display_name)
			table.insert(choices, {
				text = (on and "[x] " or "[  ] ") .. "Friend: " .. display_name,
				callback = function()
					AoM.SetProfileTriggerFriend(profileName, display_name, not on)
					zo_callLater(function() ShowProfileTriggerPicker(profileName) end, 100)
				end,
			})
		end
	end
	ShowGamepadPickerDialog(AoM.L("TRIGGERS_FOR") .. profileName, choices)
end

local function BuildOptionEntries(manager, addOnData)
	local entries = {}
	local first_header = "APH-On Manager"

	table.insert(entries, MakeEntry(AoM.L("SEARCH_ADD_ONS"), function()
		AoM.ShowGamepadTextEntryDialog(AoM.L("SEARCH_ADD_ONS_2"), AoM.L("ADD_ON_NAME"), search.needle or "", function(text)
			StartSearch(manager, text)
		end)
	end, { header = first_header, tooltipText = function() return AoM.L("JUMPS_TO_THE_FIRST_ADD_ON") end }))

	table.insert(entries, MakeEntry(AoM.L("FILTER") .. AoM.GetCategoryFilterDisplayName(AoM.GetCategoryFilter()), function()
		local choices = {}
		for _, entry in ipairs(AoM.GetCategoryFilterEntries()) do
			table.insert(choices, { text = entry.display, callback = function() AoM.SetCategoryFilter(entry.internal) end })
		end
		ShowGamepadPickerDialog("Filter", choices)
	end))

	local active_profile = AoM.GetActiveProfileName()
	table.insert(entries, MakeEntry(AoM.L("NEW_PROFILE_3"), function() AoM.ShowNewProfileDialog() end,
		{ header = "Profiles", tooltipText = function() return AoM.L("A_PROFILE_STORES_WHAT_IS_ENABLED") end }))

	table.insert(entries, MakeEntry(AoM.L("LOAD_PROFILE_2") .. (active_profile or "none"), function()
		local names = AoM.GetProfileNames()
		if #names == 0 then
			AoM.ShowNewProfileDialog()
			return
		end
		local choices = {}
		for _, name in ipairs(names) do
			table.insert(choices, { text = name, callback = function() AoM.ConfirmLoadProfile(name) end })
		end
		ShowGamepadPickerDialog(AoM.L("LOAD_PROFILE"), choices)
	end))
	table.insert(entries, MakeEntry(AoM.L("SAVE_PROFILE_2") .. (active_profile and (": " .. active_profile) or "..."), function() AoM.ConfirmSaveProfile() end,
		{ tooltipText = function() return AoM.L("OVERWRITE_THE_ACTIVE_PROFILE_WITH_WHAT") end }))
	if active_profile then
		table.insert(entries, MakeEntry(AoM.L("RENAME_PROFILE_2"), function() AoM.ShowRenameProfileDialog(active_profile) end))
		table.insert(entries, MakeEntry(AoM.L("DELETE_PROFILE_2"), function() AoM.ConfirmDeleteProfile(active_profile) end))
	end
	table.insert(entries, MakeCheckboxEntry(AoM.L("ENABLE_SWITCHING"), AoM.IsProfileAutoSwitchEnabled, function(checked)
		AoM.SetProfileAutoSwitchEnabled(checked)
	end))
	if active_profile then
		table.insert(entries, MakeEntry(AoM.L("PROFILE_TRIGGERS_2"), function() ShowProfileTriggerPicker(active_profile) end,
			{ tooltipText = function() return AoM.L("PICK_WHAT_HAS_TO_BE_TRUE") end }))
	end

	if addOnData and addOnData.addOnFileName then
		local addon_name = addOnData.strippedAddOnName or addOnData.addOnFileName
		local current_category = AoM.GetAddonCategory(addOnData.addOnFileName)
		local current_display = AoM.GetCategoryDisplayName(current_category)

		table.insert(entries, MakeEntry(AoM.L("MOVE_TO_CATEGORY"), function()
			local choices = {}
			for _, category in ipairs(AoM.GetAllCategories()) do
				if category ~= current_category then
					table.insert(choices, { text = AoM.GetCategoryDisplayName(category), callback = function()
						AoM.AssignAddonToCategory(addOnData.addOnFileName, category)
						AfterCategoryChange(manager)
					end })
				end
			end
			ShowGamepadPickerDialog(AoM.L("MOVE") .. addon_name .. " to", choices)
		end, { header = addon_name .. " (" .. current_display .. ")" }))

		if addOnData.addOnIndex and AoM.GetCapturedErrorCountForAddon(am, addOnData.addOnIndex) > 0 then
			table.insert(entries, MakeEntry(AoM.L("DISMISS_BUG"), function()
				AoM.ClearCapturedErrorsForAddon(am, addOnData.addOnIndex)
				AfterErrorsCleared(manager)
			end, { tooltipText = function() return AoM.L("CLEAR_THE_LUA_ERRORS_CAPTURED_FOR") .. addon_name .. AoM.L("THIS_SESSION") end }))
		end

		if current_category ~= LIBRARIES then
			local all_enabled = IsCategoryFullyEnabled(current_category)
			table.insert(entries, MakeEntry((all_enabled and AoM.L("DISABLE_EVERY_ADD_ON_IN") or AoM.L("ENABLE_EVERY_ADD_ON_IN")) .. current_display, function()
				AoM.SetCategoryAddonsEnabled(GetCategoryEntries(current_category), not all_enabled)
				AfterCategoryChange(manager)
			end))
		end

		table.insert(entries, MakeEntry(AoM.L("RENAME_CATEGORY_2") .. current_display .. "...", function()
			AoM.ShowRenameCategoryDialog(current_category)
		end))

		if not AoM.IsDefaultCategory(current_category) then
			table.insert(entries, MakeEntry(AoM.L("DELETE_CATEGORY_2") .. current_display, function()
				AoM.ConfirmDeleteCategory(current_category)
			end))
		end
	end

	if AoM.GetCapturedErrorTotal() > 0 then
		table.insert(entries, MakeEntry(AoM.L("WIPE_ALL_BUGS"), function()
			AoM.ClearAllCapturedErrors()
			AfterErrorsCleared(manager)
		end, { tooltipText = function() return AoM.L("CLEAR_EVERY_LUA_ERROR_CAPTURED_THIS") end }))
	end
	table.insert(entries, MakeEntry(AoM.L("NEW_CATEGORY_2"), function() AoM.ShowNewCategoryDialog() end))
	table.insert(entries, MakeCheckboxEntry(AoM.L("SUPPRESS_LUA_ERRORS"), AoM.IsSuppressingLuaErrors, function(checked)
		AoM.SetSuppressingLuaErrors(checked)
	end))
	table.insert(entries, MakeCheckboxEntry(AoM.L("PRIORITY_SAVE_ON_DEMAND"), AoM.IsPrioritySaveEnabled, function(checked)
		AoM.SetPrioritySaveEnabled(checked)
	end))
	table.insert(entries, MakeCheckboxEntry(AoM.L("SAVED_VARIABLE_ALERTS"), AoM.IsPrioritySaveAlertEnabled, function(checked)
		AoM.SetPrioritySaveAlertEnabled(checked)
	end))
	table.insert(entries, MakeCheckboxEntry(AoM.L("AUTO_DISABLE_UNUSED"), AoM.IsAutoDisableUnusedEnabled, function(checked)
		AoM.SetAutoDisableUnusedEnabled(checked)
	end))
	table.insert(entries, MakeEntry(AoM.L("DISABLE_UNUSED"), function() AoM.DisableUnused() end,
		{ tooltipText = function() return AoM.L("DISABLE_EVERY_LIBRARY_NOTHING_ENABLED_USES") end }))
	table.insert(entries, MakeEntry(AoM.L("RESET_LIST_2"), function() AoM.ConfirmResetAddonCategoryAssignments() end,
		{ tooltipText = function() return AoM.L("MOVE_EVERY_ADD_ON_AND_LIBRARY_2") end }))
	table.insert(entries, MakeEntry(AoM.L("RESET_CATEGORIES_2"), function() AoM.ConfirmResetCategories() end,
		{ tooltipText = function() return AoM.L("DELETE_EVERY_CATEGORY_YOU_CREATED_ADD") end }))
	return entries
end

local function RenameUnusedSavedVariablesEntry(list)
	local native_text = GetString(SI_GAMEPAD_ADDON_MANAGER_DELETE_UNUSED_SAVED_VARIABLES)
	if not native_text or native_text == "" then return end
	local unused = AoM.GetUnusedSavedVariablesMB and AoM.GetUnusedSavedVariablesMB() or 0
	if unused <= 0 then return end
	local label = AoM.L("ORPHANED_SAVES") .. AoM.FormatSavedVariablesUsageShort(unused)
	for _, entry in ipairs(list or {}) do
		local data = entry.templateData
		if data and data.text == native_text then
			data.text = label
			return
		end
	end
end

local function HookOptionsDialog(manager)
	local info = ESO_Dialogs[OPTIONS_DIALOG]
	if not info or info.aom_hooked then return end
	info.aom_hooked = true
	ZO_PostHook(info, "setup", function(dialogControl, addOnData)
		local list = dialogControl.info.parametricList
		RenameUnusedSavedVariablesEntry(list)
		for _, entry in ipairs(BuildOptionEntries(manager, addOnData)) do
			table.insert(list, entry)
		end
		ZO_GenericParametricListGamepadDialogTemplate_RebuildEntryList(dialogControl)
	end)
end

local function WrapToggleForCascade(manager)
	for _, descriptor in ipairs(manager.keybindStripDescriptor or {}) do
		if descriptor.keybind == "UI_SHORTCUT_PRIMARY" and descriptor.callback and not descriptor.aom_cascade_wrapped then
			descriptor.aom_cascade_wrapped = true
			local original = descriptor.callback
			descriptor.callback = function(...)
				local data = manager:GetSelectedData()
				local index = data and data.addOnIndex
				local addon_manager = GetAddOnManager()
				local was_enabled = index and select(5, addon_manager:GetAddOnInfo(index))
				local enabled_deps = 0
				if index and not was_enabled then
					enabled_deps = AoM.EnableRequiredDependencies(index)
				end
				original(...)
				local now_enabled = index and select(5, addon_manager:GetAddOnInfo(index))
				if index and was_enabled and not now_enabled and #AoM.CascadeDisableUnused(index) > 0 then
					manager:MarkDirty()
					manager:RefreshData()
				elseif enabled_deps > 0 then
					manager:MarkDirty()
					manager:RefreshData()
					manager:UpdateTooltip()
				end
			end
		end
	end
end

ZO_PostHook(ZO_AddOnManager_Gamepad, "OnDeferredInitialize", function(manager)
	HookGamepadTooltip()
	AddIconFocusKeybinds(manager)
	HookOptionsDialog(manager)
	AddSearchKeybinds(manager)
	WrapToggleForCascade(manager)
end)

local CHAT_AUTO_HIDE_MS = 1000
local CHAT_AUTO_HIDE_UPDATE = "AoM_ChatAutoHide"
local chat_hidden_by_aom = {}
local chat_idle_since_ms = 0

local function ForEachChatContainer(fn)
	for _, system in ipairs({ KEYBOARD_CHAT_SYSTEM, GAMEPAD_CHAT_SYSTEM }) do
		if type(system) == "table" and system.containers then
			for _, container in ipairs(system.containers) do
				if container.control then fn(container) end
			end
		end
	end
end

local function IsChatTyping()
	for _, system in ipairs({ KEYBOARD_CHAT_SYSTEM, GAMEPAD_CHAT_SYSTEM }) do
		if type(system) == "table" and system.textEntry and system:IsTextEntryOpen() then return true end
	end
	return false
end

local function SetChatHiddenByAoM(hidden)
	ForEachChatContainer(function(container)
		if hidden and not container.control:IsHidden() then
			container.control:SetHidden(true)
			chat_hidden_by_aom[container] = true
		elseif not hidden and chat_hidden_by_aom[container] then
			container.control:SetHidden(false)
			chat_hidden_by_aom[container] = nil
		end
	end)
end

local function UpdateChatAutoHide()
	local now = GetFrameTimeMilliseconds()
	if IsChatTyping() then
		chat_idle_since_ms = now
		SetChatHiddenByAoM(false)
	elseif now - chat_idle_since_ms >= CHAT_AUTO_HIDE_MS then
		SetChatHiddenByAoM(true)
	end
end

ZO_PostHook(ZO_AddOnManager_Gamepad, "OnShowing", function()
	SuppressVotanUsedBySection()
	chat_idle_since_ms = GetFrameTimeMilliseconds()
	EVENT_MANAGER:RegisterForUpdate(CHAT_AUTO_HIDE_UPDATE, 200, UpdateChatAutoHide)
end)

ZO_PostHook(ZO_AddOnManager_Gamepad, "OnHiding", function()
	search.needle = nil
	search.pos = 0
	EVENT_MANAGER:UnregisterForUpdate(CHAT_AUTO_HIDE_UPDATE)
	SetChatHiddenByAoM(false)
	LibAPH.StepCleanup(1)
end)
