--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
if not ADD_ON_MANAGER then return end
local AoM = APHOnManagerCore
local STATUS_ICON_SIZE = 24
local LibAPH = LibAPH

local current_addon_search_match

local function ShowAddonRowTooltip(control)
	local data = control.data
	if not data or not data.addOnFileName then return end

	local list_edge = (ADD_ON_MANAGER and ADD_ON_MANAGER.list) or control:GetParent()
	local screen_w = GuiRoot:GetWidth()
	local ESTIMATED_TOOLTIP_WIDTH = 320
	local GAP
	if LibAPH.IsAddonActiveAndRunning("PerfectPixel") then
		GAP = 20
	elseif AoM.IsAddonSelectorRunning() then
		GAP = 80
	else
		GAP = 60
	end
	if list_edge:GetRight() + GAP + ESTIMATED_TOOLTIP_WIDTH <= screen_w then
		InitializeTooltip(ItemTooltip, list_edge, TOPLEFT, GAP, control:GetTop() - list_edge:GetTop(), TOPRIGHT)
	else
		InitializeTooltip(ItemTooltip, GuiRoot, TOPRIGHT, -GAP, control:GetTop(), TOPRIGHT)
	end
	AoM.PopulateAddonInfoTooltip(ItemTooltip, data)
end

local function OnAddonManagerRowMouseEnter(control)
	ShowAddonRowTooltip(control)
end

local function OnAddonManagerNameMouseEnter(nameControl)
	OnAddonManagerRowMouseEnter(nameControl:GetParent())
end

local function OnAddonManagerMouseExit(control)
	ClearTooltip(ItemTooltip)
end

local function OnAddonManagerRowMouseUp(control, button, upInside)
	if button ~= MOUSE_BUTTON_INDEX_RIGHT or not upInside then return end
	local data = control.data
	if not data or not data.addOnFileName then return end
	if not AoM.CategoryPickerEntries then return end

	LibAPH.ShowScrollableMenu(control, AoM.CategoryPickerEntries(data.addOnFileName, function()
		ADD_ON_MANAGER.isDirty = true
		ADD_ON_MANAGER:RefreshData()
	end))
end

local function OnAddonManagerNameMouseUp(nameControl, button, upInside)
	OnAddonManagerRowMouseUp(nameControl:GetParent(), button, upInside)
end

local function EnsureStatusIcons(control)
	if control.aom_status_icons then return control.aom_status_icons end
	control.aom_status_icons = LibAPH.CreateStatusIconStrip(control, true, nil, STATUS_ICON_SIZE)
	return control.aom_status_icons
end

local function UpdateStatusIcons(control, data)
	local state = control:GetNamedChild("State")
	if not state or not data or not data.addOnFileName or not data.index then return end
	state:SetText("")
	state:SetMouseEnabled(false)

	local icons = EnsureStatusIcons(control)
	local am = GetAddOnManager()
	LibAPH.UpdateStatusIconStrip(icons, state, AoM.GetStatusIconsForAddon(am, data.index))
end

local orig_GetRowSetupFunction = ZO_AddOnManager.GetRowSetupFunction
function ZO_AddOnManager:GetRowSetupFunction()
	local orig_setup = orig_GetRowSetupFunction(self)
	return function(control, data)
		orig_setup(control, data)
		UpdateStatusIcons(control, data)
		if not control.aom_tooltip_hooked then
			control.aom_tooltip_hooked = true
			control:SetMouseEnabled(true)
			ZO_PostHookHandler(control, "OnMouseEnter", OnAddonManagerRowMouseEnter)
			ZO_PostHookHandler(control, "OnMouseExit", OnAddonManagerMouseExit)
			local name = control:GetNamedChild("Name")
			if name then
				ZO_PostHookHandler(name, "OnMouseEnter", OnAddonManagerNameMouseEnter)
				ZO_PostHookHandler(name, "OnMouseExit", OnAddonManagerMouseExit)
				ZO_PostHookHandler(name, "OnMouseUp", OnAddonManagerNameMouseUp)
			end

			control.aom_search_highlight = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
			control.aom_search_highlight:SetCenterColor(0.2, 1, 0.2, 0.3)
			control.aom_search_highlight:SetEdgeColor(0, 0, 0, 0)
			control.aom_search_highlight:SetDrawLevel(0)
			control.aom_search_highlight:SetAnchorFill(control)
			control.aom_search_highlight:SetHidden(true)
		end

		if control:GetHandler("OnMouseUp") ~= control.aom_mouseup_handler then
			ZO_PostHookHandler(control, "OnMouseUp", OnAddonManagerRowMouseUp)
			control.aom_mouseup_handler = control:GetHandler("OnMouseUp")
		end

		control.aom_search_highlight:SetHidden(not data or data.addOnFileName ~= current_addon_search_match)
	end
end

do
	local data_type = ADD_ON_MANAGER and ADD_ON_MANAGER.list and ZO_ScrollList_GetDataTypeTable(ADD_ON_MANAGER.list, 1)
	if data_type then
		data_type.setupCallback = ADD_ON_MANAGER:GetRowSetupFunction()
	end
end

local function CollapseAllAddonRows()
	if not ADD_ON_MANAGER or not ADD_ON_MANAGER.list then return end
	local scrollData = ZO_ScrollList_GetDataList(ADD_ON_MANAGER.list)
	local didCollapse = false
	for _, entry in ipairs(scrollData) do
		local data = entry.data
		if data and data.expandable and data.expanded then
			ADD_ON_MANAGER:ToggleExpandedData(data)
			didCollapse = true
		end
	end
	if didCollapse then
		ADD_ON_MANAGER:CommitScrollList()
	end
end

local addon_search_ui
local addon_search_replaces_selector = false

local function HideAddonSelectorOwnSearchBox()
	local box = _G["AddonSelectorSearchBox"]
	if box then box:SetHidden(true) end
end

local function EnsureAddonSearchBox(force_vanilla_layout)
	if addon_search_ui then return addon_search_ui end
	if not ADD_ON_MANAGER or not ADD_ON_MANAGER.control then return nil end

	if not AoM.category_filter_dropdown_container then return nil end
	addon_search_replaces_selector = not force_vanilla_layout and AoM.IsAddonSelectorRunning()

	local search_bg = WINDOW_MANAGER:CreateControlFromVirtual("AoMAddonSearchBox", ADD_ON_MANAGER.control, "ZO_EditBackdrop")
	search_bg:SetDimensions(140, 26)
	search_bg:SetAnchor(RIGHT, AoM.category_filter_dropdown_container, LEFT, -10, 0)

	if AoM.PlaceProfileControls then AoM.PlaceProfileControls() end

	local search_box = WINDOW_MANAGER:CreateControlFromVirtual(nil, search_bg, "ZO_DefaultEdit")
	search_box:SetAnchor(TOPLEFT, search_bg, TOPLEFT, 6, 2)
	search_box:SetAnchor(BOTTOMRIGHT, search_bg, BOTTOMRIGHT, -6, -2)
	search_box:SetFont("ZoFontGameSmall")
	LibAPH.AddGhostText(search_box, "Search")

	local search_matches = {}
	local search_match_pos = 0

	local function GoToSearchMatch(pos)
		if #search_matches == 0 then
			current_addon_search_match = nil
			ZO_ScrollList_RefreshVisible(ADD_ON_MANAGER.list)
			return
		end
		pos = ((pos - 1) % #search_matches) + 1
		search_match_pos = pos
		local scrollData = ZO_ScrollList_GetDataList(ADD_ON_MANAGER.list)
		local i = search_matches[pos]
		current_addon_search_match = scrollData[i].data.addOnFileName
		ZO_ScrollList_ScrollDataIntoView(ADD_ON_MANAGER.list, i)
		ZO_ScrollList_RefreshVisible(ADD_ON_MANAGER.list)
	end

	local function OnSearchTextChanged()
		local needle = string.lower(search_box:GetText())
		search_matches = {}
		if needle ~= "" then
			local scrollData = ZO_ScrollList_GetDataList(ADD_ON_MANAGER.list)
			for i, entry in ipairs(scrollData) do
				local data = entry.data
				if data and data.addOnFileName then
					local haystack = string.lower(data.addOnName or "")
					if string.find(haystack, needle, 1, true) then
						table.insert(search_matches, i)
					end
				end
			end
		end
		search_match_pos = 0
		GoToSearchMatch(1)
	end

	ZO_PostHookHandler(search_box, "OnTextChanged", OnSearchTextChanged)
	search_box:SetHandler("OnUpArrow", function() GoToSearchMatch(search_match_pos - 1) end)
	search_box:SetHandler("OnDownArrow", function() GoToSearchMatch(search_match_pos + 1) end)
	search_box:SetHandler("OnEnter", function() GoToSearchMatch(search_match_pos + 1) end)

	addon_search_ui = { container = search_bg }
	return addon_search_ui
end

local search_box_forced_refresh = false

local function UpdateAddonSearchBoxVisibility()
	if not addon_search_ui then return end
	if addon_search_replaces_selector then
		HideAddonSelectorOwnSearchBox()
	end
	if not search_box_forced_refresh then
		search_box_forced_refresh = true
		local container = addon_search_ui.container
		container:SetHidden(true)
		zo_callLater(function() container:SetHidden(false) end, 0)
		return
	end
	addon_search_ui.container:SetHidden(false)
end

EVENT_MANAGER:RegisterForEvent("AoM_SearchBoxBuild", EVENT_PLAYER_ACTIVATED, function()
	EVENT_MANAGER:UnregisterForEvent("AoM_SearchBoxBuild", EVENT_PLAYER_ACTIVATED)
	AoM.EnsureCategoryFilterDropdown()
	if not EnsureAddonSearchBox(false) then
		EnsureAddonSearchBox(true)
	end
end)

if ADDONS_FRAGMENT then
	ADDONS_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWING then
			if not AoM.IsAddonSelectorRunning() then
				CollapseAllAddonRows()
			end
			UpdateAddonSearchBoxVisibility()
		elseif newState == SCENE_FRAGMENT_HIDING then
			ClearTooltip(ItemTooltip)
			ClearTooltip(InformationTooltip)
		end
	end)
end
