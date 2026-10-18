--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHCR = APHCodeRunnerCore

local history_owner

local function SelectFile(index)
	if history_owner then history_owner.undo_state = APHCR.editor.history:TakeState() end
	APHCR.selected = zo_clamp(index, 1, #APHCR.files)
	APHCR.title_box:SetText(APHCR.files[APHCR.selected].title)
	APHCR.editor:SetText(APHCR.files[APHCR.selected].text, false, true)
	APHCR.editor.history:SetState(APHCR.files[APHCR.selected].undo_state)
	history_owner = APHCR.files[APHCR.selected]
	APHCR.reset_code_search()
	APHCR.RefreshCharCount()
	APHCR.RefreshList()
end

local function ToggleViewer()
	if not APHCR.viewer then APHCR.BuildViewer() end
	if APHCR.viewer:IsHidden() then LibAPH.DockWindowBeside(APHCR.viewer, APHCR.win, APHCR.STACK_GAP, "left") end
	APHCR.viewer:SetHidden(not APHCR.viewer:IsHidden())
	if not APHCR.viewer:IsHidden() and APHCR.errors_window and not APHCR.errors_window:IsHidden() then
		zo_callLater(APHCR.Safe("restack errors", APHCR.PlaceErrorsWindow), 50)
	end
	APHCR.LeaveUIModeIfIdle()
end

local function ApplyMenuMode()
	local scenes = { "hud", "hudui" }
	if APHCR.sv.show_in_menus then
		LibAPH.RemoveFragmentFromScenes(APHCR.menu_fragment, scenes)
		APHCR.win:SetHidden(not APHCR.wanted_open)
	else
		LibAPH.AddFragmentToScenes(APHCR.menu_fragment, scenes)
		local scene = SCENE_MANAGER:GetCurrentScene()
		APHCR.win:SetHidden(not (APHCR.wanted_open and scene and scene:HasFragment(APHCR.menu_fragment)))
	end
end

local function EnterUIMode()
	if not SCENE_MANAGER:IsInUIMode() then SCENE_MANAGER:SetInUIMode(true) end
end

APHCR.LeaveUIModeIfIdle = function()
	if APHCR.wanted_open then return end
	if (APHCR.viewer and not APHCR.viewer:IsHidden()) or (APHCR.errors_window and not APHCR.errors_window:IsHidden()) then return end
	local scene = SCENE_MANAGER:GetCurrentScene()
	local scene_name = scene and scene:GetName()
	if (scene_name == "hud" or scene_name == "hudui") and SCENE_MANAGER:IsInUIMode() then
		SCENE_MANAGER:SetInUIMode(false)
	end
end

local function SetWindowOpen(open)
	APHCR.wanted_open = open
	APHCR.menu_fragment:SetHiddenForReason(APHCR.CLOSED_REASON, not open)
	ApplyMenuMode()
	if open then EnterUIMode() else APHCR.LeaveUIModeIfIdle() end
end

local function JumpToLocation(location)
	if not location or not APHCR.win then return false end
	local index
	if APHCR.files[location.index] and APHCR.files[location.index].title == location.title then
		index = location.index
	else
		for file_index, file in ipairs(APHCR.files) do
			if file.title == location.title then
				index = file_index
				break
			end
		end
	end
	if not index then return false end
	SetWindowOpen(true)
	SelectFile(index)
	APHCR.editor:HighlightLine(location.line)
	APHCR.SetStatus(false, string.format("%s line %d", location.title, location.line))
	return true
end

local function Build()
	APHCR.win = WINDOW_MANAGER:CreateTopLevelWindow("APHCodeRunnerWindow")
	APHCR.win:SetDimensions(780, 540)
	APHCR.win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	APHCR.win:SetClampedToScreen(true)
	APHCR.win:SetMouseEnabled(true)
	APHCR.win:SetMovable(true)
	APHCR.win:SetDrawTier(DT_MEDIUM)
	APHCR.win:SetDrawLayer(DL_OVERLAY)
	APHCR.win:SetDrawLevel(9100)
	APHCR.win:SetHidden(true)
	APHCR.On(APHCR.win, "OnHide", APHCR.PersistAll, "window hide")
	APHCR.On(APHCR.win, "OnShow", function()
		for _, view in ipairs(APHCR.views) do view:Relayout() end
	end, "window show")

	APHCR.menu_fragment = ZO_HUDFadeSceneFragment:New(APHCR.win)
	APHCR.menu_fragment:SetHiddenForReason(APHCR.CLOSED_REASON, true)

	LibAPH.ApplyPanelBackdrop(APHCR.win, "APHCodeRunnerWindowBG", LibAPH.THEME.BG)
	LibAPH.CreateHeaderStrip(APHCR.win, "APHCodeRunnerWindowHeader", 30)
	local close = LibAPH.CreateThemedCloseButton(APHCR.win, "APHCodeRunnerWindowClose", function() SetWindowOpen(false) end, 12, 10)
	LibAPH.MakeWindowResizable(APHCR.win, { minWidth = 620, minHeight = 420 })

	APHCR.MakeLabel(APHCR.win, "APH Code Runner", 16):SetAnchor(TOPLEFT, APHCR.win, TOPLEFT, 12, 8)

	local font_items = {}
	local font_index = 1
	for index, size in ipairs(APHCR.FONT_SIZES) do
		font_items[index] = "Font " .. size
		if size == APHCR.sv.font_size then font_index = index end
	end
	local font_container = APHCR.MakeCombo("APHCodeRunnerFontCombo", APHCR.win, 76, font_items, font_index, function(index)
		APHCR.sv.font_size = APHCR.FONT_SIZES[index]
		for _, view in ipairs(APHCR.views) do view:ApplyFont() end
	end)
	font_container:SetAnchor(RIGHT, close, LEFT, -12, 0)

	local menu_label = APHCR.MakeLabel(APHCR.win, "Show in menus", 13, nil, "APHCodeRunnerMenuLabel")
	menu_label:SetMouseEnabled(true)
	menu_label:SetAnchor(RIGHT, font_container, LEFT, -14, 0)
	local menu_check = WINDOW_MANAGER:CreateControlFromVirtual("APHCodeRunnerMenuCheck", APHCR.win, "ZO_CheckButton")
	menu_check:SetAnchor(RIGHT, menu_label, LEFT, -6, 0)
	ZO_CheckButton_SetCheckState(menu_check, APHCR.sv.show_in_menus)
	local function SetShowInMenus(show)
		APHCR.sv.show_in_menus = show
		ZO_CheckButton_SetCheckState(menu_check, show)
		ApplyMenuMode()
	end
	ZO_CheckButton_SetToggleFunction(menu_check, APHCR.Safe("menu toggle", function(_, checked) SetShowInMenus(checked) end))
	APHCR.On(menu_label, "OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_LEFT then SetShowInMenus(not APHCR.sv.show_in_menus) end
	end, "menu label")

	local chat_label = APHCR.MakeLabel(APHCR.win, "Chat Logs", 13, nil, "APHCodeRunnerChatLabel")
	chat_label:SetMouseEnabled(true)
	chat_label:SetAnchor(RIGHT, menu_check, LEFT, -14, 0)
	local chat_check = WINDOW_MANAGER:CreateControlFromVirtual("APHCodeRunnerChatCheck", APHCR.win, "ZO_CheckButton")
	chat_check:SetAnchor(RIGHT, chat_label, LEFT, -6, 0)
	ZO_CheckButton_SetCheckState(chat_check, APHCR.sv.chat_logs ~= false)
	local function SetChatLogs(on)
		APHCR.sv.chat_logs = on
		ZO_CheckButton_SetCheckState(chat_check, on)
	end
	ZO_CheckButton_SetToggleFunction(chat_check, APHCR.Safe("chat toggle", function(_, checked) SetChatLogs(checked) end))
	APHCR.On(chat_label, "OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_LEFT then SetChatLogs(APHCR.sv.chat_logs == false) end
	end, "chat label")

	local footer = WINDOW_MANAGER:CreateControl(nil, APHCR.win, CT_CONTROL)
	footer:SetHeight(30)
	footer:SetAnchor(BOTTOMLEFT, APHCR.win, BOTTOMLEFT, 12, -10)
	footer:SetAnchor(BOTTOMRIGHT, APHCR.win, BOTTOMRIGHT, -12, -10)

	local run_btn = APHCR.MakeButton("APHCodeRunnerRunBtn", footer, "Run All", 90, function()
		APHCR.PersistAll()
		local ok, message, location = APHCR.RunFiles(APHCR.files, APHCR.addon_box:GetText(), APHCR.saved_box:GetText())
		APHCR.SetStatus(ok, message)
		APHCR.editor:UpdateGutter()
		if location then JumpToLocation(location) end
	end)
	run_btn:SetAnchor(BOTTOMLEFT, footer, BOTTOMLEFT, 0, 0)
	local stop_btn = APHCR.MakeButton("APHCodeRunnerStopBtn", footer, "Stop", 70, function()
		APHCR.PersistAll()
		APHCR.StopLast()
		ReloadUI("ingame")
	end)
	stop_btn:SetAnchor(BOTTOMLEFT, run_btn, BOTTOMRIGHT, 6, 0)
	local stop_all_btn = APHCR.MakeButton("APHCodeRunnerStopAllBtn", footer, "Terminate All", 110, function()
		APHCR.PersistAll()
		APHCR.StopAll()
		ReloadUI("ingame")
	end)
	stop_all_btn:SetAnchor(BOTTOMLEFT, stop_btn, BOTTOMRIGHT, 6, 0)
	local viewer_btn = APHCR.MakeButton("APHCodeRunnerViewerBtn", footer, "SavedVars", 100, ToggleViewer)
	viewer_btn:SetAnchor(BOTTOMLEFT, stop_all_btn, BOTTOMRIGHT, 6, 0)
	APHCR.errors_btn = APHCR.MakeButton("APHCodeRunnerErrorsBtn", footer, "Errors", 100, APHCR.ToggleErrors)
	APHCR.errors_btn:SetAnchor(BOTTOMLEFT, viewer_btn, BOTTOMRIGHT, 6, 0)
	APHCR.UpdateErrorsBadge()

	APHCR.status_lbl = APHCR.MakeLabel(footer, "", 13, LibAPH.THEME.MUTED)
	APHCR.status_lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	APHCR.status_lbl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	APHCR.status_lbl:SetAnchor(TOPLEFT, APHCR.errors_btn, TOPRIGHT, 10, 0)
	APHCR.status_lbl:SetAnchor(BOTTOMRIGHT, footer, BOTTOMRIGHT, 0, 0)

	local side = WINDOW_MANAGER:CreateControl(nil, APHCR.win, CT_CONTROL)
	side:SetWidth(190)
	side:SetAnchor(TOPLEFT, APHCR.win, TOPLEFT, 12, 40)
	side:SetAnchor(BOTTOMLEFT, footer, TOPLEFT, 0, -10)

	APHCR.MakeLabel(side, "Files, in load order", 13, LibAPH.THEME.MUTED):SetAnchor(TOPLEFT, side, TOPLEFT, 0, 0)

	local add_btn = APHCR.MakeButton("APHCodeRunnerAddBtn", side, "Add", 92, function()
		APHCR.files[#APHCR.files + 1] = { title = "file" .. (#APHCR.files + 1) .. ".lua", enabled = true, text = "" }
		APHCR.PersistAll()
		APHCR.list_offset = #APHCR.files
		SelectFile(#APHCR.files)
	end)
	local remove_btn = APHCR.MakeButton("APHCodeRunnerRemoveBtn", side, "Remove", 92, function()
		if #APHCR.files <= 1 then
			APHCR.files[1] = { title = "main.lua", enabled = true, text = "" }
		else
			table.remove(APHCR.files, APHCR.selected)
		end
		APHCR.PersistAll()
		SelectFile(APHCR.selected)
	end)
	local up_btn = APHCR.MakeButton("APHCodeRunnerUpBtn", side, "Up", 92, function()
		if APHCR.selected <= 1 then return end
		APHCR.files[APHCR.selected], APHCR.files[APHCR.selected - 1] = APHCR.files[APHCR.selected - 1], APHCR.files[APHCR.selected]
		APHCR.PersistAll()
		SelectFile(APHCR.selected - 1)
	end)
	local down_btn = APHCR.MakeButton("APHCodeRunnerDownBtn", side, "Down", 92, function()
		if APHCR.selected >= #APHCR.files then return end
		APHCR.files[APHCR.selected], APHCR.files[APHCR.selected + 1] = APHCR.files[APHCR.selected + 1], APHCR.files[APHCR.selected]
		APHCR.PersistAll()
		SelectFile(APHCR.selected + 1)
	end)
	up_btn:SetAnchor(BOTTOMLEFT, side, BOTTOMLEFT, 0, 0)
	down_btn:SetAnchor(LEFT, up_btn, RIGHT, 6, 0)
	add_btn:SetAnchor(BOTTOMLEFT, up_btn, TOPLEFT, 0, -6)
	remove_btn:SetAnchor(LEFT, add_btn, RIGHT, 6, 0)

	local list = WINDOW_MANAGER:CreateControl(nil, side, CT_CONTROL)
	list:SetAnchor(TOPLEFT, side, TOPLEFT, 0, 22)
	list:SetAnchor(BOTTOMRIGHT, add_btn, TOPLEFT, 190, -8)
	list:SetMouseEnabled(true)
	local function ScrollList(_, delta)
		APHCR.list_offset = APHCR.list_offset - delta
		APHCR.RefreshList()
	end
	APHCR.On(list, "OnMouseWheel", ScrollList, "file list wheel")
	LibAPH.ApplyPanelBackdrop(list, "APHCodeRunnerListBG", LibAPH.THEME.INSET)
	APHCR.list_bar = APHCR.MakeScrollbar(side, "APHCodeRunnerList", list, {
		inside = true,
		set_position = function(value)
			APHCR.list_offset = math.floor(value + 0.5)
			APHCR.RefreshList()
		end,
		page = function() return math.max(#APHCR.list_rows - 1, 1) end,
		wheel_step = 1,
	})

	APHCR.list_rows = {}
	local function BuildRows()
		local wanted = math.max(math.floor((list:GetHeight() - 8) / APHCR.ROW_HEIGHT), 1)
		for index = #APHCR.row_pool + 1, wanted do
			local row = WINDOW_MANAGER:CreateControl(nil, list, CT_CONTROL)
			row:SetHeight(APHCR.ROW_HEIGHT)
			row:SetAnchor(TOPLEFT, list, TOPLEFT, 6, 4 + (index - 1) * APHCR.ROW_HEIGHT)
			row:SetAnchor(TOPRIGHT, list, TOPRIGHT, -(6 + APHCR.BAR_HIT_WIDTH), 4 + (index - 1) * APHCR.ROW_HEIGHT)
			row:SetMouseEnabled(true)
			APHCR.On(row, "OnMouseUp", function(self, button, upInside)
				if upInside and button == MOUSE_BUTTON_INDEX_LEFT and APHCR.files[self.file_index] then SelectFile(self.file_index) end
			end, "file row")
			APHCR.On(row, "OnMouseWheel", ScrollList, "file row wheel")

			local check = WINDOW_MANAGER:CreateControlFromVirtual("APHCodeRunnerRowCheck" .. index, row, "ZO_CheckButton")
			check:SetAnchor(LEFT, row, LEFT, 0, 0)
			APHCR.On(check, "OnMouseWheel", ScrollList, "file check wheel")
			ZO_CheckButton_SetToggleFunction(check, APHCR.Safe("file check", function(_, checked)
				local file = APHCR.files[row.file_index]
				if not file then return end
				file.enabled = checked
				APHCR.PersistFile(row.file_index)
				APHCR.RefreshList()
			end))

			local label = APHCR.MakeLabel(row, "", 13)
			label:SetHeight(APHCR.ROW_HEIGHT)
			label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
			label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
			label:SetAnchor(LEFT, check, RIGHT, 6, 0)
			label:SetAnchor(RIGHT, row, RIGHT, 0, 0)

			row.check, row.label = check, label
			APHCR.row_pool[index] = row
		end
		APHCR.list_rows = {}
		for index, row in ipairs(APHCR.row_pool) do
			if index <= wanted then APHCR.list_rows[index] = row else row:SetHidden(true) end
		end
		APHCR.RefreshList()
	end
	APHCR.On(list, "OnRectChanged", BuildRows, "file list resize")

	local header_row = WINDOW_MANAGER:CreateControl(nil, APHCR.win, CT_CONTROL)
	header_row:SetHeight(26)
	header_row:SetAnchor(TOPLEFT, side, TOPRIGHT, 12, 0)
	header_row:SetAnchor(TOPRIGHT, APHCR.win, TOPRIGHT, -12, 40)

	local addon_bg
	addon_bg, APHCR.addon_box = APHCR.MakeLineEdit("APHCodeRunnerAddonName", header_row, "Add-on name (sent with EVENT_ADD_ON_LOADED)", function(self)
		APHCR.sv.addon_name = self:GetText()
	end)
	addon_bg:SetAnchor(TOPLEFT, header_row, TOPLEFT, 0, 0)
	addon_bg:SetAnchor(TOPRIGHT, header_row, TOP, -4, 0)
	APHCR.addon_box:SetText(APHCR.sv.addon_name)

	local saved_bg
	saved_bg, APHCR.saved_box = APHCR.MakeLineEdit("APHCodeRunnerSavedNames", header_row, "SavedVariables names, from the manifest", function(self)
		APHCR.sv.saved_names = self:GetText()
	end)
	saved_bg:SetAnchor(TOPLEFT, header_row, TOP, 4, 0)
	saved_bg:SetAnchor(TOPRIGHT, header_row, TOPRIGHT, 0, 0)
	APHCR.saved_box:SetText(APHCR.sv.saved_names)

	local title_bg
	title_bg, APHCR.title_box = APHCR.MakeLineEdit("APHCodeRunnerFileTitle", APHCR.win, "File name, e.g. Core/ALC_Core.lua", function(self)
		if not APHCR.files[APHCR.selected] or (APHCR.editor and APHCR.editor.loading) then return end
		APHCR.files[APHCR.selected].title = self:GetText()
		APHCR.PersistFile(APHCR.selected)
		APHCR.RefreshList()
	end)
	title_bg:SetAnchor(TOPLEFT, header_row, BOTTOMLEFT, 0, 8)
	title_bg:SetAnchor(TOPRIGHT, header_row, BOTTOMRIGHT, -200, 8)
	APHCR.chars_lbl = APHCR.MakeLabel(APHCR.win, "", 13, LibAPH.THEME.MUTED)
	APHCR.chars_lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	APHCR.chars_lbl:SetAnchor(RIGHT, header_row, BOTTOMRIGHT, 0, 21)

	local search_bg
	search_bg, APHCR.search_box = APHCR.MakeLineEdit("APHCodeRunnerSearch", APHCR.win, "Search this file - Enter next, Shift+Enter previous", function()
		if APHCR.reset_code_search then APHCR.reset_code_search() end
	end)
	search_bg:SetAnchor(TOPLEFT, title_bg, BOTTOMLEFT, 0, 8)
	search_bg:SetAnchor(TOPRIGHT, title_bg, BOTTOMRIGHT, 0, 8)
	APHCR.search_status = APHCR.MakeLabel(APHCR.win, "", 13, LibAPH.THEME.MUTED)
	APHCR.search_status:SetAnchor(LEFT, search_bg, RIGHT, 8, 0)
	local undo_btn = APHCR.MakeButton("APHCodeRunnerUndoBtn", APHCR.win, "Undo", 52, function()
		APHCR.editor.history:Undo()
		APHCR.editor.box:TakeFocus()
	end)
	undo_btn:SetAnchor(TOPRIGHT, header_row, BOTTOMRIGHT, 0, 42)

	APHCR.suggest_bar = WINDOW_MANAGER:CreateControl("APHCodeRunnerSuggest", APHCR.win, CT_CONTROL)
	APHCR.suggest_bar:SetHeight(24)
	APHCR.suggest_bar:SetAnchor(BOTTOMLEFT, footer, TOPLEFT, 190 + 12, -8)
	APHCR.suggest_bar:SetAnchor(BOTTOMRIGHT, footer, TOPRIGHT, 0, -8)
	LibAPH.ApplyPanelBackdrop(APHCR.suggest_bar, "APHCodeRunnerSuggestBG", LibAPH.THEME.INSET)
	APHCR.suggest_hint = APHCR.MakeLabel(APHCR.suggest_bar, APHCR.SUGGEST_IDLE_TEXT, 13, LibAPH.THEME.MUTED)
	APHCR.suggest_hint:SetAnchor(LEFT, APHCR.suggest_bar, LEFT, 8, 0)

	APHCR.editor = APHCR.MakeScrollText(APHCR.win, "APHCodeRunnerCode", {
		box_name = "APHCodeRunnerCodeBox",
		gutter = true,
		follow_cursor = true,
		undo = true,
		after_edit = APHCR.UpdateSuggestions,
		marks = function()
			local file = APHCR.files[APHCR.selected]
			return file and file.error_lines or {}
		end,
		on_change = function(text)
			local file = APHCR.files[APHCR.selected]
			if not file then return end
			file.text = text
			file.error_lines = nil
			APHCR.PersistFile(APHCR.selected)
			APHCR.RefreshCharCount()
		end,
	})
	APHCR.editor.area:SetAnchor(TOPLEFT, search_bg, BOTTOMLEFT, 0, 8)
	APHCR.editor.area:SetAnchor(BOTTOMRIGHT, APHCR.suggest_bar, TOPRIGHT, 0, -6)
	APHCR.reset_code_search = APHCR.AttachSearch(APHCR.search_box, APHCR.search_status, APHCR.editor.box, function(line)
		APHCR.editor:ScrollToLine(line)
	end)

	ZO_PreHookHandler(APHCR.editor.box, "OnTab", APHCR.Safe("autocomplete tab", function()
		if #APHCR.suggestions > 0 then
			APHCR.AcceptSuggestion(1)
			return true
		end
	end))
	ZO_PostHookHandler(APHCR.editor.box, "OnFocusLost", APHCR.Safe("autocomplete blur", function()
		if not MouseIsOver(APHCR.suggest_bar) then APHCR.HideSuggestions() end
	end))
	for index = 1, APHCR.SUGGEST_MAX do
		local label = APHCR.MakeLabel(APHCR.suggest_bar, "", 13)
		label:SetMouseEnabled(true)
		label:SetHidden(true)
		APHCR.On(label, "OnMouseUp", function(_, button, upInside)
			if upInside and button == MOUSE_BUTTON_INDEX_LEFT then APHCR.AcceptSuggestion(index) end
		end, "suggestion " .. index)
		APHCR.suggest_labels[index] = label
	end

	BuildRows()
	SelectFile(APHCR.selected)
	ApplyMenuMode()
end

function APHCR.Toggle()
	if not APHCR.win then Build() end
	SetWindowOpen(not APHCR.wanted_open)
end
