-- FindMyStuff_UI.lua
-- Shared tab data plus the keyboard (mouse) window.

FindMyStuff = FindMyStuff or {}

---------------------------------------------------------------------------
-- Tabs shared by the window and the gamepad screen
---------------------------------------------------------------------------
FindMyStuff.UITabs = {
	{
		key = "items",
		name = "My Items",
		hint = "Searches every character's bags, bank and craft bag. Example: night mother",
	},
	{
		key = "traders",
		name = "Guild Traders",
		hint = "Open a guild store and pick a category first. Words plus trait:x quality:epic max:gold unit:gold pages:N unknown all. Set Look for to a lead option to find antiquity leads.",
	},
	{
		key = "leads",
		name = "Leads",
		hint = "Words match an antiquity, its set or its zone. Pick mythic / have / missing below, or type all to include every antiquity.",
	},
}

---------------------------------------------------------------------------
-- Dropdown choices shared by the window and the gamepad dialog
---------------------------------------------------------------------------
-- "Look for" on the Guild Traders tab
FindMyStuff.TraderTypeOptions = {
	{name = "Items", lead = false, flag = ""},
	{name = "All leads", lead = true, flag = ""},
	{name = "Mythic leads", lead = true, flag = "mythic"},
}
-- "Look for" on the Leads tab
FindMyStuff.LeadTypeOptions = {
	{name = "All leads", lead = true, flag = ""},
	{name = "Mythic leads", lead = true, flag = "mythic"},
}
-- "Show" for any lead search
FindMyStuff.LeadShowOptions = {
	{name = "Any lead", flag = ""},
	{name = "Leads I have", flag = "have"},
	{name = "Leads I'm missing", flag = "missing"},
	{name = "Never found", flag = "new"},
}

-- Adds the dropdown flags to the typed words
function FindMyStuff.BuildLeadQuery(text, typeOption, showOption)
	local parts = {FindMyStuff.Trim(text or "")}
	if typeOption and typeOption.flag ~= "" then parts[#parts + 1] = typeOption.flag end
	if showOption and showOption.flag ~= "" then parts[#parts + 1] = showOption.flag end
	return FindMyStuff.Trim(table.concat(parts, " "))
end

-- Runs a trader search from the dropdown choices
function FindMyStuff.RunTraderSearch(text, typeOption, showOption)
	if typeOption and typeOption.lead then
		return FindMyStuff.StartTraderLeadSearch(FindMyStuff.BuildLeadQuery(text, typeOption, showOption))
	end
	return FindMyStuff.StartTraderFilter(text)
end

function FindMyStuff.GetTabInfo(key)
	for _, tab in ipairs(FindMyStuff.UITabs) do
		if tab.key == key then return tab end
	end
	return FindMyStuff.UITabs[1]
end

-- Returns rows, statusText for a tab
function FindMyStuff.GetTabRows(key, text)
	text = FindMyStuff.Trim(text)
	if key == "items" then
		if text == "" then return {}, "Type an item name and search." end
		local rows, summary, err = FindMyStuff.SearchInventory(text)
		return rows or {}, err or summary
	elseif key == "traders" then
		return FindMyStuff.GetTraderRows(), FindMyStuff.GetTraderStatus()
	elseif key == "leads" then
		local rows, summary, err = FindMyStuff.SearchLeads(text)
		return rows or {}, err or summary
	end
	return {}, ""
end

---------------------------------------------------------------------------
-- Keyboard window
---------------------------------------------------------------------------
local W = {
	tab = "items",
	text = {items = "", traders = "", leads = ""},
	-- selected dropdown index per tab
	choice = {traders = {type = 1, show = 1}, leads = {type = 1, show = 1}},
}
FindMyStuff.Window = W

local ROW_TYPE = 1
local TAB_BUTTONS = {items = "TabItems", traders = "TabTraders", leads = "TabLeads"}

local function TypeOptions(tab)
	return tab == "traders" and FindMyStuff.TraderTypeOptions or FindMyStuff.LeadTypeOptions
end

local function CurrentChoice()
	local c = W.choice[W.tab]
	if not c then return nil, nil end
	return TypeOptions(W.tab)[c.type], FindMyStuff.LeadShowOptions[c.show]
end

-- The query the Leads tab lists with
local function LeadsQuery()
	local typeOption, showOption = CurrentChoice()
	return FindMyStuff.BuildLeadQuery(W.text.leads, typeOption, showOption)
end

local function FillCombo(combo, options, selected, onPick)
	if not combo then return end
	combo:ClearItems()
	if combo.SetSortsItems then combo:SetSortsItems(false) end
	for i, o in ipairs(options) do
		combo:AddItem(combo:CreateItemEntry(o.name, function() onPick(i) end), ZO_COMBOBOX_SUPPRESS_UPDATE)
	end
	if combo.UpdateItems then pcall(combo.UpdateItems, combo) end
	local entry = options[selected] or options[1]
	if entry then combo:SetSelectedItemText(entry.name) end
end

-- Shows the dropdowns that apply to the current tab
function W.RefreshOptions()
	if not W.options then return end
	local c = W.choice[W.tab]
	W.options:SetHidden(c == nil)
	if not c then return end
	local typeOption = TypeOptions(W.tab)[c.type]
	local showsLeads = typeOption and typeOption.lead
	W.showLabel:SetHidden(not showsLeads)
	W.showCombo:SetHidden(not showsLeads)
	W.findInTraders:SetHidden(W.tab ~= "leads")

	local ok, err = pcall(function()
		FillCombo(W.typeBox, TypeOptions(W.tab), c.type, function(i)
			c.type = i
			W.RefreshOptions()
			if W.tab == "leads" then W.Refresh() end
		end)
		FillCombo(W.showBox, FindMyStuff.LeadShowOptions, c.show, function(i)
			c.show = i
			if W.tab == "leads" then W.Refresh() end
		end)
	end)
	if not ok and not W.comboErrorShown then
		W.comboErrorShown = true
		d("|cFF7700FindMyStuff:|r Dropdown error: " .. tostring(err))
	end
end

-- Leads tab: scan guild stores for the leads currently listed
function W.FindInTraders()
	if not W.control then return end
	W.text.leads = W.edit:GetText()
	local lc = W.choice.leads
	if FindMyStuff.StartTraderLeadSearch(LeadsQuery()) then
		-- carry the choices over to the Guild Traders tab (All leads / Mythic leads)
		local leadType = FindMyStuff.LeadTypeOptions[lc.type]
		for i, o in ipairs(FindMyStuff.TraderTypeOptions) do
			if o.lead and o.flag == leadType.flag then W.choice.traders.type = i end
		end
		W.choice.traders.show = lc.show
		W.text.traders = W.text.leads
		W.SetTab("traders")
	end
end

function W.Refresh()
	if not W.control then return end
	local query = W.tab == "leads" and LeadsQuery() or W.text[W.tab]
	local rows, status = FindMyStuff.GetTabRows(W.tab, query)
	W.status:SetText(status and ("|cffff00" .. status .. "|r") or "")
	ZO_ScrollList_Clear(W.list)
	local dataList = ZO_ScrollList_GetDataList(W.list)
	for i = 1, #rows do
		dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, rows[i])
	end
	ZO_ScrollList_Commit(W.list)
end

function W.SetTab(key)
	if not W.control then return end
	W.tab = FindMyStuff.GetTabInfo(key).key
	for tabKey, childName in pairs(TAB_BUTTONS) do
		local button = W.control:GetNamedChild(childName)
		-- the active tab is shown pressed / disabled
		button:SetEnabled(tabKey ~= W.tab)
	end
	W.hint:SetText(FindMyStuff.GetTabInfo(W.tab).hint)
	local text = W.text[W.tab]
	if W.tab == "traders" and text == "" and not FindMyStuff.IsTraderLeadSearch() then
		text = FindMyStuff.GetTraderFilterText()
	end
	W.edit:SetText(text)
	W.stop:SetHidden(W.tab ~= "traders")
	W.RefreshOptions()
	W.Refresh()
end

function W.RunSearch()
	if not W.control then return end
	local text = W.edit:GetText()
	W.text[W.tab] = text
	if W.tab == "traders" then
		FindMyStuff.RunTraderSearch(text, CurrentChoice())
	end
	W.Refresh()
end

function W.Stop()
	FindMyStuff.StopTrader()
	W.Refresh()
end

function W.OnRowEnter(control)
	local data = ZO_ScrollList_GetData and ZO_ScrollList_GetData(control) or control.dataEntry and control.dataEntry.data
	if not data then return end
	if data.link and data.link ~= "" then
		InitializeTooltip(ItemTooltip, control, RIGHT, -10, 0, LEFT)
		ItemTooltip:SetLink(data.link)
	elseif data.detail and data.detail ~= "" then
		InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
		SetTooltipText(InformationTooltip, data.detail)
	end
end

function W.OnRowExit()
	ClearTooltip(ItemTooltip)
	ClearTooltip(InformationTooltip)
end

function W.SavePosition()
	if not W.control then return end
	FindMyStuff.SavedVariables.windowPos = {x = W.control:GetLeft(), y = W.control:GetTop()}
end

function W.ApplyLock()
	if W.control then
		W.control:SetMovable(not FindMyStuff.GetSetting("windowLocked"))
	end
end

function W.Show(tab)
	if not W.control then return end
	W.control:SetHidden(false)
	SCENE_MANAGER:SetInUIMode(true)
	W.SetTab(tab or W.tab)
	W.edit:TakeFocus()
end

function W.Hide()
	if W.control then W.control:SetHidden(true) end
	W.OnRowExit()
end

function FindMyStuff.ToggleWindow(tab)
	if not W.control then return end
	if W.control:IsHidden() or (tab and tab ~= W.tab) then
		W.Show(tab)
	else
		W.Hide()
	end
end

function FindMyStuff.InitWindow()
	local control = FindMyStuffWindow
	if not control then return end
	W.control = control
	W.edit = control:GetNamedChild("SearchBox")
	W.list = control:GetNamedChild("List")
	W.hint = control:GetNamedChild("Hint")
	W.status = control:GetNamedChild("Status")
	W.stop = control:GetNamedChild("Stop")
	W.options = control:GetNamedChild("Options")
	W.typeCombo = W.options:GetNamedChild("Type")
	W.showCombo = W.options:GetNamedChild("Show")
	W.showLabel = W.options:GetNamedChild("ShowLabel")
	W.findInTraders = W.options:GetNamedChild("FindInTraders")
	local okType, typeBox = pcall(ZO_ComboBox_ObjectFromContainer, W.typeCombo)
	local okShow, showBox = pcall(ZO_ComboBox_ObjectFromContainer, W.showCombo)
	W.typeBox = okType and typeBox or nil
	W.showBox = okShow and showBox or nil

	ZO_ScrollList_AddDataType(W.list, ROW_TYPE, "FindMyStuffRow", 26, function(row, data)
		row:SetText(data.line or data.title or "")
	end)

	local pos = FindMyStuff.SavedVariables.windowPos
	if pos and pos.x and pos.y then
		control:ClearAnchors()
		control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
	end
	W.ApplyLock()

	-- Live trader updates
	CALLBACK_MANAGER:RegisterCallback(FindMyStuff.TRADER_CALLBACK, function()
		if W.tab == "traders" and not control:IsHidden() then W.Refresh() end
	end)
	-- Hide with the cursor (Esc / leaving UI mode) and when switching to gamepad mode
	EVENT_MANAGER:RegisterForEvent(FindMyStuff.Name .. "_Window", EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
		if not IsGameCameraUIModeActive() then W.Hide() end
	end)
	EVENT_MANAGER:RegisterForEvent(FindMyStuff.Name .. "_Window", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
		W.Hide()
	end)
end
