--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH


function LibAPH.MakeWindowResizable(control, opts)
	opts = opts or {}
	control:SetResizeHandleSize(opts.handleSize or 8)
	control:SetDimensionConstraints(opts.minWidth or 0, opts.minHeight or 0, opts.maxWidth or 0, opts.maxHeight or 0)
	if opts.onResizing or opts.onResizeStop then
		control:SetHandler("OnResizeStart", function(self)
			if opts.onResizing then self:SetHandler("OnUpdate", opts.onResizing, "LibAPH_Resizing") end
		end)
		control:SetHandler("OnResizeStop", function(self)
			self:SetHandler("OnUpdate", nil, "LibAPH_Resizing")
			if opts.onResizeStop then opts.onResizeStop() end
		end)
	end
end

function LibAPH.CreateStatusWindow(opts)
	opts = opts or {}
	local parent = opts.parent or GuiRoot
	local win = WINDOW_MANAGER:CreateControl(opts.name, parent, CT_TOPLEVELCONTROL)
	win:SetClampedToScreen(true)
	win:SetMouseEnabled(true)
	win:SetMovable(opts.movable ~= false)
	win:SetHidden(true)
	win:SetAutoRectClipChildren(true)

	win:SetDrawTier(DT_HIGH)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetDrawLevel(9000)

	win:SetDimensions(opts.width or 150, opts.height or 40)

	if opts.onMoveStop then
		win:SetHandler("OnMoveStop", function(ctrl)
			opts.onMoveStop(ctrl:GetLeft(), ctrl:GetTop())
		end)
	end

	local bg_name = opts.name and (opts.name .. "BG") or nil
	local bg_tex = WINDOW_MANAGER:CreateControl(bg_name, win, CT_BACKDROP)
	bg_tex:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
	bg_tex:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 0, 0)
	local bg = opts.bgColor or LibAPH.THEME.BG_HUD
	bg_tex:SetCenterColor(unpack(bg))
	bg_tex:SetEdgeColor(0, 0, 0, 0)
	bg_tex:SetDrawTier(DT_HIGH); bg_tex:SetDrawLayer(DL_OVERLAY); bg_tex:SetDrawLevel(0)

	local border_color = opts.borderColor or LibAPH.THEME.EDGE
	local border_thickness = (opts.borderThickness or 1) * LibAPH.PixelSize()

	local border_top = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
	border_top:SetCenterColor(unpack(border_color)); border_top:SetEdgeColor(0, 0, 0, 0)
	border_top:SetDrawTier(DT_HIGH); border_top:SetDrawLayer(DL_OVERLAY); border_top:SetDrawLevel(1)
	border_top:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
	border_top:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 0)
	border_top:SetHeight(border_thickness)

	local border_bottom = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
	border_bottom:SetCenterColor(unpack(border_color)); border_bottom:SetEdgeColor(0, 0, 0, 0)
	border_bottom:SetDrawTier(DT_HIGH); border_bottom:SetDrawLayer(DL_OVERLAY); border_bottom:SetDrawLevel(1)
	border_bottom:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 0, 0)
	border_bottom:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 0, 0)
	border_bottom:SetHeight(border_thickness)

	local border_left = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
	border_left:SetCenterColor(unpack(border_color)); border_left:SetEdgeColor(0, 0, 0, 0)
	border_left:SetDrawTier(DT_HIGH); border_left:SetDrawLayer(DL_OVERLAY); border_left:SetDrawLevel(1)
	border_left:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
	border_left:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 0, 0)
	border_left:SetWidth(border_thickness)

	local border_right = WINDOW_MANAGER:CreateControl(nil, win, CT_BACKDROP)
	border_right:SetCenterColor(unpack(border_color)); border_right:SetEdgeColor(0, 0, 0, 0)
	border_right:SetDrawTier(DT_HIGH); border_right:SetDrawLayer(DL_OVERLAY); border_right:SetDrawLevel(1)
	border_right:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 0)
	border_right:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 0, 0)
	border_right:SetWidth(border_thickness)

	local font = opts.isGamepad and (opts.fontGamepad or "ZoFontGamepad22") or (opts.fontPC or "ZoFontGameSmall")
	local label_name = opts.name and (opts.name .. "Label") or nil
	local label = WINDOW_MANAGER:CreateControl(label_name, win, CT_LABEL)
	label:SetFont(font)
	label:SetColor(1, 1, 1, 1)
	label:SetText(opts.initialText or LibAPH.L("LOADING"))
	label:SetAnchor(CENTER, win, CENTER, 0, 0)
	if opts.centerAlign ~= false then
		label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	end
	label:SetDrawTier(DT_HIGH)
	label:SetDrawLayer(DL_OVERLAY)
	label:SetDrawLevel(2)

	if opts.resizable ~= false then
		local font_face = opts.isGamepad and "EsoUI/Common/Fonts/FTN57.slug" or "EsoUI/Common/Fonts/Univers67.slug"
		local font_style = opts.isGamepad and "soft-shadow-thick" or "soft-shadow-thin"
		local base_size = opts.baseFontSize or (opts.isGamepad and 22 or 13)
		local min_size = opts.minFontSize or (opts.isGamepad and 16 or 10)
		local max_size = opts.maxFontSize or (opts.isGamepad and 40 or 32)
		local base_width = opts.width or 150
		local base_height = opts.height or 40

		local function apply_font_scale()
			local scale = math.min(win:GetWidth() / base_width, win:GetHeight() / base_height)
			local size = zo_clamp(zo_round(base_size * scale), min_size, max_size)
			label:SetFont(font_face .. "|" .. size .. "|" .. font_style)
		end
		win.libaph_apply_font_scale = apply_font_scale

		LibAPH.MakeWindowResizable(win, {
			minWidth = opts.minWidth or 100,
			minHeight = opts.minHeight or 30,
			maxWidth = opts.maxWidth or 600,
			maxHeight = opts.maxHeight or 90,
			onResizing = apply_font_scale,
			onResizeStop = function()
				apply_font_scale()
				if opts.onResizeStop then opts.onResizeStop(win:GetWidth(), win:GetHeight()) end
			end,
		})
	end

	return win, label
end

function LibAPH.CreateRowList(parent, opts)
	opts = opts or {}
	local orientation = (opts.orientation == "horizontal") and "horizontal" or "vertical"
	local spacing = opts.spacing or 4
	local maxRows = opts.maxRows or 20
	local padding = opts.padding or 6
	local minWidth = opts.minWidth or 40
	local minHeight = opts.minHeight or 20
	local font = opts.isGamepad and (opts.fontGamepad or "ZoFontGamepad22") or (opts.fontPC or "ZoFontGameSmall")
	local color = opts.color or { 1, 1, 1, 1 }
	local pname = parent.GetName and parent:GetName()

	local pool = {}
	local list = {}

	local function get_label(i)
		local label = pool[i]
		if label then return label end
		label = WINDOW_MANAGER:CreateControl(pname and (pname .. "Row" .. i) or nil, parent, CT_LABEL)
		label:SetFont(font)
		label:SetColor(unpack(color))
		label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		label:SetDrawTier(DT_HIGH); label:SetDrawLayer(DL_OVERLAY); label:SetDrawLevel(2)
		pool[i] = label
		return label
	end

	function list:SetRows(texts)
		local n = zo_min(#texts, maxRows)
		local offset, cross = 0, 0
		for i = 1, n do
			local label = get_label(i)
			label:SetText(texts[i])
			local w, h = label:GetTextDimensions()
			w = zo_max(w, 1); h = zo_max(h, 1)
			label:ClearAnchors()
			if orientation == "vertical" then
				label:SetAnchor(TOPLEFT, parent, TOPLEFT, padding, padding + offset)
				offset = offset + h + spacing
				cross = zo_max(cross, w)
			else
				label:SetAnchor(TOPLEFT, parent, TOPLEFT, padding + offset, padding)
				offset = offset + w + spacing
				cross = zo_max(cross, h)
			end
			label:SetHidden(false)
		end
		for i = n + 1, #pool do
			pool[i]:SetHidden(true)
		end

		local extent = zo_max(offset - spacing, 0)
		if orientation == "vertical" then
			parent:SetDimensions(zo_max(minWidth, cross + padding * 2), zo_max(minHeight, extent + padding * 2))
		else
			parent:SetDimensions(zo_max(minWidth, extent + padding * 2), zo_max(minHeight, cross + padding * 2))
		end
	end

	function list:Clear()
		self:SetRows({})
	end

	return list
end

LibAPH.PASTEBIN_URL = "https://pastebin.com/"

function LibAPH.OpenPastebin()
	RequestOpenUnsafeURL(LibAPH.PASTEBIN_URL)
end

function LibAPH.ConfirmOpenPastebin(win)
	LibAPH.ShowDialogHidingWindows({ win }, "LibAPH_OPEN_PASTEBIN", "Pastebin",
		LibAPH.L("OPEN_PASTEBIN_COM_IN_YOUR_BROWSER"), {
		{ text = SI_DIALOG_CONFIRM, callback = LibAPH.OpenPastebin },
		{ text = SI_DIALOG_CANCEL },
	}, 0)
end

local SEARCH_LAYER = "LibAPH_Search"
local active_search_step

function LibAPH.StepActiveSearch(direction)
	if not active_search_step then return false end
	active_search_step(direction)
	return true
end

local function SetActiveSearch(step)
	active_search_step = step
	local active = IsActionLayerActiveByName(SEARCH_LAYER)
	if step and not active then
		PushActionLayerByName(SEARCH_LAYER)
	elseif not step and active then
		RemoveActionLayerByName(SEARCH_LAYER)
	end
end

local COPY_BOX_TEXT_ROW = 1
local COPY_BOX_WHEEL_STEP = 60
local COPY_BOX_SCROLLBAR_SPACE = 24
local COPY_BOX_SECTIONS_WIDTH = 170
local COPY_BOX_SELECTION_COLOR = { 1, 0.5, 0.05, 0.55 }

function LibAPH.CreateCopyTextBox(opts)
	opts = opts or {}
	local footer_h = (opts.dismissBug or opts.wipeAllBugs or opts.pastebin) and 44 or 0
	local screen_w, screen_h = GuiRoot:GetWidth(), GuiRoot:GetHeight()
	local width = opts.width or zo_clamp(screen_w * (opts.widthPct or 0.31), opts.startMinWidth or 500, opts.startMaxWidth or 800)
	local height = opts.height or zo_clamp(screen_h * (opts.heightPct or 0.35), opts.startMinHeight or 320, opts.startMaxHeight or 600) + footer_h
	local win = WINDOW_MANAGER:CreateControl(opts.name, GuiRoot, CT_TOPLEVELCONTROL)
	win:SetDimensions(width, height)
	win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	win:SetDrawTier(DT_MEDIUM)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetDrawLevel(ZO_MEDIUM_TIER_KEYBOARD_STANDARD_DIALOG - 1)
	win:SetMouseEnabled(true)
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:SetHidden(true)

	LibAPH.ApplyPanelBackdrop(win, opts.name .. "BG")
	LibAPH.CreateHeaderStrip(win, opts.name .. "Header", 36)

	local close_btn = LibAPH.CreateThemedCloseButton(win, opts.name .. "Close", nil, 8, 8)
	close_btn:SetHandler("OnClicked", function()
		win:SetHidden(true)
		if opts.onClose then opts.onClose() end
	end)

	local title_lbl = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
	title_lbl:SetFont("ZoFontGameBold")
	title_lbl:SetColor(1, 1, 1, 1)
	title_lbl:SetText(opts.titleText or "")
	title_lbl:SetAnchor(TOPLEFT, win, TOPLEFT, 15, 12)
	title_lbl:SetAnchor(TOPRIGHT, close_btn, TOPLEFT, -10, 0)
	title_lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

	local copy_lbl = WINDOW_MANAGER:CreateControlFromVirtual(nil, win, "ZO_DefaultButton")
	copy_lbl:SetDimensions(120, 28)
	copy_lbl:SetFont("ZoFontWinH4")
	copy_lbl:SetText(opts.copyText or LibAPH.L("SELECT_ALL"))
	copy_lbl:SetAnchor(TOPRIGHT, close_btn, BOTTOMRIGHT, 0, 6)

	local sections_container, sections_combo
	if opts.sections then
		sections_container = WINDOW_MANAGER:CreateControlFromVirtual(opts.name .. "Sections", win, "ZO_ComboBox")
		sections_container:SetDimensions(COPY_BOX_SECTIONS_WIDTH, 28)
		sections_container:SetAnchor(TOPRIGHT, copy_lbl, TOPLEFT, -10, 0)
		sections_combo = ZO_ComboBox_ObjectFromContainer(sections_container)
		sections_combo:SetSortsItems(false)
		sections_combo:EnableMultiSelect(opts.sectionsText or LibAPH.L("MORE_INFO"), opts.noSectionsText or LibAPH.L("MORE_INFO_0"))
		LibAPH.UseGreenSelection(sections_combo)
	end
	local top_row_left = sections_container or copy_lbl

	local dev_lbl
	if opts.devButton then
		dev_lbl = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
		dev_lbl:SetFont("ZoFontWinH5")
		dev_lbl:SetColor(1, 0.65, 0, 1)
		dev_lbl:SetText(opts.devButton.text or "Simulate Error")
		dev_lbl:SetAnchor(TOPRIGHT, top_row_left, TOPLEFT, -20, 0)
		dev_lbl:SetMouseEnabled(true)
		LibAPH.AddButtonHoverEffects(dev_lbl, { 1, 0.65, 0, 1 })
		dev_lbl.libaph_click_action = opts.devButton.onClick
	end

	local reserved_width = 8 + 120
	if sections_container then
		reserved_width = reserved_width + 10 + COPY_BOX_SECTIONS_WIDTH
	end
	if dev_lbl then
		reserved_width = reserved_width + 20 + dev_lbl:GetTextWidth()
	end
	reserved_width = reserved_width + 15

	local search_bg = WINDOW_MANAGER:CreateControlFromVirtual(nil, win, "ZO_EditBackdrop")
	search_bg:SetAnchor(TOPLEFT, win, TOPLEFT, 15, 48)
	search_bg:SetAnchor(TOPRIGHT, win, TOPRIGHT, -reserved_width, 43)
	search_bg:SetHeight(24)

	local search_box = WINDOW_MANAGER:CreateControlFromVirtual(nil, search_bg, "ZO_DefaultEdit")
	search_box:SetAnchor(TOPLEFT, search_bg, TOPLEFT, 6, 2)
	search_box:SetAnchor(BOTTOMRIGHT, search_bg, BOTTOMRIGHT, -6, -2)
	search_box:SetFont("ZoFontGameSmall")
	LibAPH.AddGhostText(search_box, opts.searchLabel or "Search")

	local status_lbl = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
	status_lbl:SetFont("ZoFontGameSmall")
	status_lbl:SetColor(0.7, 0.7, 0.7, 1)
	status_lbl:SetAnchor(TOPLEFT, search_bg, TOPRIGHT, 10, 5)
	status_lbl:SetText("")

	local edit_bg = WINDOW_MANAGER:CreateControl(opts.name .. "TextArea", win, CT_CONTROL)
	LibAPH.ApplyPanelBackdrop(edit_bg, opts.name .. "TextAreaBG", LibAPH.THEME.INSET)
	edit_bg:SetAnchor(TOPLEFT, win, TOPLEFT, 15, 80)
	edit_bg:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -15, -(15 + footer_h))

	local text_list = WINDOW_MANAGER:CreateControlFromVirtual(opts.name .. "TextList", edit_bg, "ZO_ScrollList")
	ZO_ScrollList_AddCommitOnHeightChange(text_list)
	text_list:SetAnchor(TOPLEFT, edit_bg, TOPLEFT, 8, 8)
	text_list:SetAnchor(BOTTOMRIGHT, edit_bg, BOTTOMRIGHT, -8, -8)
	local text_scroll = LibAPH.StyleScrollList(text_list, opts.name .. "TextScroll")

	local eb = WINDOW_MANAGER:CreateControlFromVirtual(nil, text_list.contents, "ZO_DefaultEditMultiLineForBackdrop")
	eb:SetMaxInputChars(opts.maxInputChars or 4000)
	eb:SetSelectionColor(unpack(COPY_BOX_SELECTION_COLOR))
	eb:SetHandler("OnMouseWheel", function(_, delta)
		ZO_ScrollList_ScrollRelative(text_list, -delta * COPY_BOX_WHEEL_STEP)
	end)

	local measure = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
	measure:SetAlpha(0)
	measure:SetMouseEnabled(false)
	measure:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)

	local text_height = 30
	ZO_ScrollList_AddDataType(text_list, COPY_BOX_TEXT_ROW, "LibAPH_ScrollListTextRow", text_height, function(row)
		row:SetHeight(text_height)
		eb:SetParent(row)
		eb:ClearAnchors()
		eb:SetAnchorFill(row)
	end)

	local layout_text = ""
	local function relayout()
		local text_width = zo_max(50, text_list:GetWidth() - COPY_BOX_SCROLLBAR_SPACE)
		measure:SetFont(eb:GetFont())
		measure:SetWidth(text_width)
		measure:SetText(layout_text)
		text_height = measure:GetTextHeight() + eb:GetFontHeight() * 2
		ZO_ScrollList_UpdateDataTypeHeight(text_list, COPY_BOX_TEXT_ROW, text_height)
		ZO_ScrollList_Clear(text_list)
		local data_list = ZO_ScrollList_GetDataList(text_list)
		data_list[1] = ZO_ScrollList_CreateDataEntry(COPY_BOX_TEXT_ROW, {})
		ZO_ScrollList_Commit(text_list)
		if text_scroll then text_scroll:Sync() end
	end

	LibAPH.MakeWindowResizable(win, {
		minWidth = 400, minHeight = 300, maxWidth = 1200, maxHeight = 900,
		onResizeStop = relayout,
	})

	local strip = opts.stripColors or LibAPH.StripColors
	local box = { window = win, editbox = eb, search_box = search_box }
	local plain_text, lower_text = "", ""
	local search_pos = 1

	local function count_matches(needle_lower)
		if needle_lower == "" then return 0 end
		local count, pos = 0, 1
		while true do
			local s = string.find(lower_text, needle_lower, pos, true)
			if not s then break end
			count = count + 1
			pos = s + 1
		end
		return count
	end

	local function match_index(needle_lower, match_start)
		local count, pos = 0, 1
		while true do
			local s = string.find(lower_text, needle_lower, pos, true)
			if not s then break end
			count = count + 1
			if s == match_start then return count end
			pos = s + 1
		end
		return count
	end

	local function jump_to(match_start, match_end)
		eb:SetCursorPosition(match_start - 1)
		eb:SetSelection(match_start - 1, match_end)
		local line = 1
		for _ in string.gmatch(string.sub(plain_text, 1, match_start), "\n") do
			line = line + 1
		end
		ZO_ScrollList_ScrollAbsolute(text_list, zo_max(0, (line - 3) * eb:GetFontHeight()))
	end

	local function do_search(forward)
		local needle = search_box:GetText()
		if needle == "" then
			status_lbl:SetText("")
			return
		end
		local needle_lower = string.lower(needle)
		local total = count_matches(needle_lower)
		if total == 0 then
			status_lbl:SetColor(1, 0.4, 0.4, 1)
			status_lbl:SetText(opts.noMatchesText or LibAPH.L("NO_MATCHES"))
			return
		end

		local match_start, match_end
		if forward then
			match_start, match_end = string.find(lower_text, needle_lower, search_pos, true)
			if not match_start then
				match_start, match_end = string.find(lower_text, needle_lower, 1, true)
			end
		else
			local pos, last_s, last_e = 1, nil, nil
			while true do
				local s, e = string.find(lower_text, needle_lower, pos, true)
				if not s or s >= search_pos then break end
				last_s, last_e = s, e
				pos = s + 1
			end
			if not last_s then
				pos = 1
				while true do
					local s, e = string.find(lower_text, needle_lower, pos, true)
					if not s then break end
					last_s, last_e = s, e
					pos = s + 1
				end
			end
			match_start, match_end = last_s, last_e
		end

		if match_start then
			jump_to(match_start, match_end)
			search_pos = forward and (match_end + 1) or match_start
			status_lbl:SetColor(0.6, 1, 0.6, 1)
			status_lbl:SetText(string.format("%d/%d", match_index(needle_lower, match_start), total))
		end
	end

	ZO_PostHookHandler(search_box, "OnTextChanged", function()
		search_pos = 1
	end)
	search_box:SetHandler("OnEnter", function()
		do_search(not IsShiftKeyDown())
	end)
	search_box:SetHandler("OnUpArrow", function() do_search(false) end)
	search_box:SetHandler("OnDownArrow", function() do_search(true) end)
	local function StepSearch(direction) do_search(direction > 0) end
	ZO_PostHookHandler(win, "OnHide", function()
		if active_search_step == StepSearch then SetActiveSearch(nil) end
	end)
	box.step_search = StepSearch

	copy_lbl:SetHandler("OnClicked", function()
		eb:SelectAll()
		eb:TakeFocus()
	end)

	local function FooterButton(text, point, offsetX, onClick)
		local btn = WINDOW_MANAGER:CreateControlFromVirtual(nil, win, "ZO_DefaultButton")
		btn:SetDimensions(150, 30)
		btn:SetFont("ZoFontWinH4")
		btn:SetText(text)
		btn:SetAnchor(point, win, point, offsetX, -10)
		btn:SetHandler("OnClicked", function() onClick() end)
		return btn
	end

	if opts.dismissBug then
		box.dismiss_lbl = FooterButton(opts.dismissBug.text or LibAPH.L("DISMISS_BUG"), BOTTOMLEFT, 15, opts.dismissBug.onClick)
	end

	if opts.pastebin then
		box.pastebin_btn = FooterButton(opts.pastebinText or "Pastebin", BOTTOM, 0, function() LibAPH.ConfirmOpenPastebin(win) end)
	end

	if opts.wipeAllBugs then
		box.wipe_lbl = FooterButton(opts.wipeAllBugs.text or LibAPH.L("WIPE_ALL_BUGS"), BOTTOMRIGHT, -15, opts.wipeAllBugs.onClick)
	end

	local footer_buttons = {}
	for _, btn in ipairs({ box.dismiss_lbl, box.pastebin_btn, box.wipe_lbl }) do footer_buttons[#footer_buttons + 1] = btn end
	if #footer_buttons > 0 then
		LibAPH.FitButtonRow(win, footer_buttons, { margin = 15, font = "ZoFontWinH4" })
	end
	LibAPH.FitButtonText(copy_lbl, { font = "ZoFontWinH4" })

	function box:Hide()
		win:SetHidden(true)
		local scene_name = SCENE_MANAGER.currentScene and SCENE_MANAGER.currentScene:GetName()
		if (scene_name == "hud" or scene_name == "hudui") and SCENE_MANAGER:IsInUIMode() then
			SCENE_MANAGER:SetInUIMode(false)
		end
	end

	local function SetBoxText(text)
		plain_text = string.gsub(strip(text), "|", "/")
		lower_text = string.lower(plain_text)
		search_pos = 1
		status_lbl:SetText("")
		eb:SetText(plain_text)
		layout_text = plain_text
	end

	local report_sections
	local enabled_sections = {}
	local sections_touched = false

	local function RenderSections()
		return LibAPH.RenderBugReport(report_sections, enabled_sections)
	end

	function box:ShowReport(sections, hasErrors)
		report_sections = sections
		if not sections_touched then enabled_sections = LibAPH.DefaultBugReportSections(hasErrors) end
		if sections_combo then
			sections_combo:ClearItems()
			for _, def in ipairs(LibAPH.BUG_REPORT_SECTIONS) do
				if sections[def.key] and sections[def.key] ~= "" then
					local key = def.key
					local item = sections_combo:CreateItemEntry(def.label, function(combo, _, entry)
						sections_touched = true
						enabled_sections[key] = combo:IsItemSelected(entry)
						SetBoxText(RenderSections())
						relayout()
					end)
					sections_combo:AddItem(item)
					if enabled_sections[key] then sections_combo:AddItemToSelected(item) end
				end
			end
			sections_combo:RefreshSelectedItemText()
		end
		box:Show(RenderSections())
	end

	function box:Show(text)
		SetBoxText(text)
		search_box:SetText("")
		win:SetHidden(false)
		if IsInGamepadPreferredMode() then SetActiveSearch(box.step_search) end
		if not SCENE_MANAGER:IsInUIMode() then
			SCENE_MANAGER:SetInUIMode(true)
		end
		relayout()
		ZO_ScrollList_ResetToTop(text_list)
		zo_callLater(relayout, 0)
		eb:SetCursorPosition(0)
		eb:SelectAll()
		eb:TakeFocus()
	end
	return box
end

local function LightenColor(color, amount)
	return {
		color[1] + (1 - color[1]) * amount,
		color[2] + (1 - color[2]) * amount,
		color[3] + (1 - color[3]) * amount,
		color[4] or 1,
	}
end

local function DarkenColor(color, amount)
	return { color[1] * (1 - amount), color[2] * (1 - amount), color[3] * (1 - amount), color[4] or 1 }
end

function LibAPH.AddButtonHoverEffects(control, baseColor)
	local hoverColor = LightenColor(baseColor, 0.4)
	local pressedColor = DarkenColor(baseColor, 0.35)
	control:SetHandler("OnMouseEnter", function(self) self:SetColor(unpack(hoverColor)) end)
	control:SetHandler("OnMouseExit", function(self) self:SetColor(unpack(baseColor)) end)
	control:SetHandler("OnMouseDown", function(self) self:SetColor(unpack(pressedColor)) end)
	control:SetHandler("OnMouseUp", function(self, button, upInside)
		self:SetColor(unpack(upInside and hoverColor or baseColor))
		if upInside then
			PlaySound(SOUNDS.DEFAULT_CLICK)
			if self.libaph_click_action then self.libaph_click_action() end
		end
	end)
end

local keybind_btn_counter = 0

function LibAPH.AddGhostText(editBox, ghostText)
	local ghost = WINDOW_MANAGER:CreateControl(nil, editBox, CT_LABEL)
	ghost:SetFont("ZoFontGameSmall")
	ghost:SetColor(0.5, 0.5, 0.5, 1)
	ghost:SetText(ghostText)
	ghost:SetAnchor(LEFT, editBox, LEFT, 2, 0)
	ghost:SetMouseEnabled(false)

	local function UpdateGhost()
		ghost:SetHidden(editBox:GetText() ~= "")
	end
	ZO_PostHookHandler(editBox, "OnTextChanged", UpdateGhost)
	UpdateGhost()
	return ghost
end

local keybind_buttons = {}
local keybind_windows = {}
local shown_windows_by_layer = {}

local function SetKeybindWindowShown(win, shown)
	local layers = keybind_windows[win]
	if not layers then return end
	for layer in pairs(layers) do
		local shown_set = shown_windows_by_layer[layer]
		if not shown_set then
			shown_set = {}
			shown_windows_by_layer[layer] = shown_set
		end
		shown_set[win] = shown or nil
		local any_shown = next(shown_set) ~= nil
		local active = IsActionLayerActiveByName(layer)
		if any_shown and not active then
			PushActionLayerByName(layer)
		elseif not any_shown and active then
			RemoveActionLayerByName(layer)
		end
	end
end

local function TrackKeybindWindow(btn, layer)
	local win = layer and btn:GetOwningWindow()
	if not win then return end
	local layers = keybind_windows[win]
	if not layers then
		layers = {}
		keybind_windows[win] = layers
		ZO_PostHookHandler(win, "OnShow", function() SetKeybindWindowShown(win, true) end)
		ZO_PostHookHandler(win, "OnHide", function() SetKeybindWindowShown(win, false) end)
	end
	layers[layer] = true
	if not win:IsHidden() then SetKeybindWindowShown(win, true) end
end

function LibAPH.HandleKeybindButtonKey(keybind)
	for _, btn in ipairs(keybind_buttons) do
		if btn.libaph_keybind == keybind and btn.libaph_click_action and not btn:IsControlHidden() and btn:IsEnabled() ~= false then
			btn.libaph_click_action(btn)
			return true
		end
	end
	return false
end

function LibAPH.RegisterKeybindDefaults(namespace, store, defaults, modifiers)
	if not IsKeyboardUISupported() then return end
	store.touched_keybinds = store.touched_keybinds or {}
	local touched = store.touched_keybinds
	local function ForgetTouched()
		for action in pairs(defaults) do touched[action] = nil end
	end
	ZO_PreHook("ResetAllBindsToDefault", ForgetTouched)
	ZO_PreHook("ResetKeyboardBindsToDefault", ForgetTouched)
	local function OnKeybindingTouched(_, layerIndex, categoryIndex, actionIndex, bindingIndex)
		local action = GetActionInfo(layerIndex, categoryIndex, actionIndex)
		if defaults[action] and bindingIndex == 1 then touched[action] = true end
	end
	EVENT_MANAGER:RegisterForEvent(namespace .. "_KeybindSet", EVENT_KEYBINDING_SET, OnKeybindingTouched)
	EVENT_MANAGER:RegisterForEvent(namespace .. "_KeybindCleared", EVENT_KEYBINDING_CLEARED, OnKeybindingTouched)
	for action, key in pairs(defaults) do
		if not touched[action] then
			local modifier = modifiers and modifiers[action]
			if modifier then
				CreateDefaultActionBind(action, key, modifier)
			else
				CreateDefaultActionBind(action, key)
			end
		end
	end
end

function LibAPH.CreateKeybindLabelButton(parent, opts)
	opts = opts or {}
	keybind_btn_counter = keybind_btn_counter + 1
	local btn = WINDOW_MANAGER:CreateControlFromVirtual("LibAPH_KeybindBtn" .. keybind_btn_counter, parent, "ZO_KeybindButton")
	btn:SetKeybindButtonDescriptor({
		keybind = opts.action,
		name = opts.name or "",
		callback = function(...)
			if btn.libaph_click_action then btn.libaph_click_action(...) end
		end,
	})
	btn.libaph_click_action = opts.callback

	local name_label = btn:GetNamedChild("NameLabel")
	if name_label then name_label:SetFont("ZoFontDialogKeybindDescription") end

	btn.libaph_keybind = opts.action
	keybind_buttons[#keybind_buttons + 1] = btn
	TrackKeybindWindow(btn, opts.layer)

	return btn
end

function LibAPH.CreateScrollListWindow(opts)
	opts = opts or {}
	local screen_w, screen_h = GuiRoot:GetWidth(), GuiRoot:GetHeight()
	local width = opts.width or zo_clamp(screen_w * (opts.widthPct or 0.34), opts.minWidth or 480, opts.maxWidth or 900)
	local height = opts.height or zo_clamp(screen_h * (opts.heightPct or 0.55), opts.minHeight or 420, opts.maxHeight or 820)

	local win = WINDOW_MANAGER:CreateControl(opts.name, GuiRoot, CT_TOPLEVELCONTROL)
	win:SetDimensions(width, height)
	win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	win:SetDrawTier(DT_MEDIUM)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetDrawLevel(10)
	win:SetMouseEnabled(true)
	win:SetMovable(true)
	win:SetClampedToScreen(true)
	win:SetHidden(true)

	LibAPH.ApplyPanelBackdrop(win, opts.name and (opts.name .. "BG") or nil)
	LibAPH.CreateHeaderStrip(win, opts.name and (opts.name .. "Header") or nil, 40)

	local close_btn = LibAPH.CreateThemedCloseButton(win, opts.name and (opts.name .. "Close") or nil, nil, 8, 8)

	local title_lbl = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
	title_lbl:SetFont("ZoFontWinH4")
	title_lbl:SetColor(1, 1, 1, 1)
	title_lbl:SetText(opts.titleText or "")
	title_lbl:SetAnchor(TOPLEFT, win, TOPLEFT, 15, 12)

	local subtitle_lbl = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
	subtitle_lbl:SetFont("ZoFontGameSmall")
	subtitle_lbl:SetColor(0.75, 0.75, 0.75, 1)
	subtitle_lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	subtitle_lbl:SetMaxLineCount(1)
	subtitle_lbl:SetAnchor(TOPLEFT, title_lbl, TOPRIGHT, 12, 3)
	subtitle_lbl:SetAnchor(TOPRIGHT, close_btn, TOPLEFT, -10, 7)

	local measure_lbl = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
	measure_lbl:SetAlpha(0)
	measure_lbl:SetMouseEnabled(false)
	measure_lbl:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)

	local function TextWidth(label)
		local text = label:GetText()
		if not text or text == "" then return 0 end
		measure_lbl:SetFont(label:GetFont())
		measure_lbl:SetText(text)
		return measure_lbl:GetTextWidth()
	end

	local footer_height = opts.footerHeight or 44
	local content_top = 45
	local SEARCH_X, SEARCH_W, SEARCH_GAP, COUNTS_RIGHT = 15, 200, 20, 30
	local search_box
	local toolbar

	if opts.enableSearch then
		content_top = 78
		local search_bg = WINDOW_MANAGER:CreateControlFromVirtual(opts.name and (opts.name .. "SearchBG") or nil, win, "ZO_EditBackdrop")
		search_bg:SetDimensions(SEARCH_W, 26)
		search_bg:SetAnchor(TOPLEFT, win, TOPLEFT, SEARCH_X, 48)

		search_box = WINDOW_MANAGER:CreateControlFromVirtual(nil, search_bg, "ZO_DefaultEdit")
		search_box:SetAnchor(TOPLEFT, search_bg, TOPLEFT, 6, 2)
		search_box:SetAnchor(BOTTOMRIGHT, search_bg, BOTTOMRIGHT, -6, -2)
		search_box:SetFont("ZoFontGameSmall")
		LibAPH.AddGhostText(search_box, "Search")
		end

	if opts.toolbarHeight then
		toolbar = WINDOW_MANAGER:CreateControl(opts.name and (opts.name .. "Toolbar") or nil, win, CT_CONTROL)
		toolbar:SetAnchor(TOPLEFT, win, TOPLEFT, 15, content_top)
		toolbar:SetAnchor(TOPRIGHT, win, TOPRIGHT, -30, content_top)
		toolbar:SetHeight(opts.toolbarHeight)
		content_top = content_top + opts.toolbarHeight + 6
	end

	local list = WINDOW_MANAGER:CreateControlFromVirtual(opts.name and (opts.name .. "List") or nil, win, "ZO_ScrollList")
	ZO_ScrollList_AddCommitOnHeightChange(list)
	list:SetAnchor(TOPLEFT, win, TOPLEFT, 15, content_top)
	list:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -30, -footer_height)
	local list_scroll = LibAPH.StyleScrollList(list, opts.name and (opts.name .. "Scroll") or nil)

	local ROW_TYPE = 1
	local row_height = opts.rowHeight or 26
	local row_font = opts.isGamepad and (opts.fontGamepad or "ZoFontGamepad22") or (opts.fontPC or "ZoFontGame")

	local highlight = WINDOW_MANAGER:CreateControl(nil, list.contents, CT_BACKDROP)
	highlight:SetCenterColor(0.2, 1, 0.2, 0.16)
	highlight:SetEdgeColor(0, 0, 0, 0)
	highlight:SetDrawLevel(0)
	highlight:SetHidden(true)
	local highlighted_control

	local search_highlight = WINDOW_MANAGER:CreateControl(nil, list.contents, CT_BACKDROP)
	search_highlight:SetCenterColor(0.2, 1, 0.2, 0.3)
	search_highlight:SetEdgeColor(0, 0, 0, 0)
	search_highlight:SetDrawLevel(0)
	search_highlight:SetHidden(true)
	local search_highlight_control
	local current_search_match_data

	local function OnRowMouseEnter(control)
		highlighted_control = control
		highlight:ClearAnchors()
		highlight:SetAnchor(TOPLEFT, control, TOPLEFT, -4, 0)
		highlight:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 4, 0)
		highlight:SetHidden(false)

		local data = ZO_ScrollList_GetData(control)
		if not data then return end
		local edge_offset = win:GetRight() - control:GetRight()
		if data.populateTooltip then
			InitializeTooltip(ItemTooltip, control, LEFT, edge_offset, 0, RIGHT)
			data.populateTooltip(ItemTooltip)
		elseif data.tooltip then
			InitializeTooltip(ItemTooltip, control, LEFT, edge_offset, 0, RIGHT)
			SetTooltipText(ItemTooltip, data.tooltip)
		end
	end
	local function OnRowMouseExit(control)
		if highlighted_control == control then
			highlighted_control = nil
			highlight:SetHidden(true)
		end
		ClearTooltip(ItemTooltip)
	end
	local CHECKBOX_TEXT_INDENT = 26
	local ARROW_TEXT_INDENT = 24
	local header_font = opts.isGamepad and (opts.headerFontGamepad or "ZoFontGamepad27") or (opts.headerFontPC or "ZoFontWinH4")

	local function ApplyRowToggle(control, data, checked)
		data.checked = checked
		ZO_CheckButton_SetCheckState(control.checkbox, checked)
		if data.onToggle then data.onToggle(checked) end

		control.text_lbl:SetColor(1, 1, 1, 1)
		zo_callLater(function()
			if ZO_ScrollList_GetData(control) == data then
				control.text_lbl:SetColor(unpack(data.color or { 1, 1, 1, 1 }))
			end
		end, 150)
	end

	local function OnRowMouseUp(control, button, upInside)
		if not upInside then return end
		local data = ZO_ScrollList_GetData(control)
		if not data then return end
		if data.checkable then
			PlaySound(SOUNDS.DEFAULT_CLICK)
			ApplyRowToggle(control, data, not data.checked)
		elseif data.onClick then
			PlaySound(SOUNDS.DEFAULT_CLICK)
			data.onClick(control)
		end
	end

	local function SetupRow(control, data)
		if not control.libaph_row_initialized then
			control.libaph_row_initialized = true
			control:SetHeight(row_height)
			control:SetHandler("OnMouseEnter", OnRowMouseEnter)
			control:SetHandler("OnMouseExit", OnRowMouseExit)
			control:SetHandler("OnMouseUp", OnRowMouseUp)

			control.arrow = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_TreeButtonArrow")
			control.arrow:SetDimensions(20, 20)
			control.arrow:SetAnchor(LEFT, control, LEFT, 2, 0)
			control.arrow:SetDrawLayer(DL_OVERLAY)
			control.arrow:SetDrawLevel(5)
			control.arrow:SetHandler("OnClicked", function()
				local row_data = ZO_ScrollList_GetData(control)
				if row_data and row_data.onClick then row_data.onClick(control) end
			end)

			control.stripe = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
			control.stripe:SetMouseEnabled(false)
			control.stripe:SetDrawLevel(0)
			control.stripe:SetAnchor(TOPLEFT, control, TOPLEFT, -4, 0)
			control.stripe:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 4, 0)

			control.header_bg = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
			local section = LibAPH.THEME.SECTION
			control.header_bg:SetCenterColor(section[1], section[2], section[3], section[4])
			control.header_bg:SetEdgeColor(0, 0, 0, 0)
			control.header_bg:SetDrawLevel(0)
			control.header_bg:SetAnchor(TOPLEFT, control, TOPLEFT, -4, 0)
			control.header_bg:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 4, 0)

			control.text_lbl = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
			control.text_lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
			control.text_lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
			control.text_lbl:SetMouseEnabled(false)

			control.checkbox = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_CheckButton")
			control.checkbox:SetAnchor(LEFT, control, LEFT, 4, 0)
			control.checkbox:SetDrawLayer(DL_OVERLAY)
			control.checkbox:SetDrawLevel(5)
			ZO_CheckButton_SetToggleFunction(control.checkbox, function(_, checked)
				local row_data = ZO_ScrollList_GetData(control)
				if row_data then ApplyRowToggle(control, row_data, checked) end
			end)

			control.close_btn = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "SavingEditBoxCancelButton")
			control.close_btn:SetDimensions(18, 18)
			control.close_btn:SetDrawLayer(DL_OVERLAY)
			control.close_btn:SetDrawLevel(5)
			control.close_btn:SetHandler("OnMouseEnter", function(self)
				InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -2)
				SetTooltipText(InformationTooltip, "Delete")
			end)
			control.close_btn:SetHandler("OnMouseExit", function()
				ClearTooltip(InformationTooltip)
			end)
			control.close_btn:SetHandler("OnClicked", function()
				local row_data = ZO_ScrollList_GetData(control)
				if row_data and row_data.closeButton and row_data.closeButton.onClick then
					row_data.closeButton.onClick(control)
				end
			end)

			control.rename_btn = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "SavingEditBoxModifyButton")
			control.rename_btn:SetDimensions(18, 18)
			control.rename_btn:SetDrawLayer(DL_OVERLAY)
			control.rename_btn:SetDrawLevel(5)
			control.rename_btn:SetHandler("OnClicked", function()
				local row_data = ZO_ScrollList_GetData(control)
				if row_data and row_data.renameButton and row_data.renameButton.onClick then
					row_data.renameButton.onClick(control)
				end
			end)

			control.status_icons = LibAPH.CreateStatusIconStrip(control, true)
			for _, icon in ipairs(control.status_icons) do
				icon:SetDrawLayer(DL_OVERLAY)
			end
		end

		control:SetText("")
		control.header_bg:SetHidden(not data.is_header)
		if data.is_header then
			control.stripe:SetHidden(true)
		else
			LibAPH.StyleRowBackground(control.stripe, data.libaph_row_index or 1, false)
		end
		control.arrow:SetHidden(not data.collapsible)
		if data.collapsible then
			ZO_ToggleButton_SetState(control.arrow, data.collapsed and TOGGLE_BUTTON_CLOSED or TOGGLE_BUTTON_OPEN)
		end
		control.text_lbl:SetFont((opts.nativeStyle and data.is_header) and header_font or row_font)
		control.text_lbl:SetColor(unpack(data.color or { 1, 1, 1, 1 }))
		control.text_lbl:SetText(data.text)
		control.text_lbl:ClearAnchors()
		control.checkbox:SetHidden(not data.checkable)
		control.close_btn:SetHidden(not data.closeButton)
		control.rename_btn:SetHidden(not data.renameButton)
		control.close_btn:ClearAnchors()
		control.rename_btn:ClearAnchors()
		if data.closeButton then
			control.close_btn:SetAnchor(RIGHT, control, RIGHT, -4, 0)
			if data.renameButton then
				control.rename_btn:SetAnchor(RIGHT, control.close_btn, LEFT, -2, 0)
			end
		elseif data.renameButton then
			control.rename_btn:SetAnchor(RIGHT, control, RIGHT, -4, 0)
		end
		if data.checkable then
			ZO_CheckButton_SetCheckState(control.checkbox, data.checked)
			control.text_lbl:SetAnchor(TOPLEFT, control, TOPLEFT, CHECKBOX_TEXT_INDENT, 0)
		elseif data.collapsible then
			control.text_lbl:SetAnchor(TOPLEFT, control, TOPLEFT, ARROW_TEXT_INDENT, 0)
		else
			control.text_lbl:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
		end
		local status_icons = data.statusIcons or {}
		LibAPH.UpdateStatusIconStrip(control.status_icons, control, status_icons, true)
		local status_icon_count = #status_icons

		local right_margin = 4
		if data.closeButton then right_margin = right_margin + 22 end
		if data.renameButton then right_margin = right_margin + 22 end
		if status_icon_count > 0 then right_margin = right_margin + status_icon_count * 20 end
		control.text_lbl:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -right_margin, 0)

		if data == current_search_match_data then
			search_highlight_control = control
			search_highlight:ClearAnchors()
			search_highlight:SetAnchor(TOPLEFT, control, TOPLEFT, -4, 0)
			search_highlight:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 4, 0)
			search_highlight:SetHidden(false)
		elseif search_highlight_control == control then
			search_highlight_control = nil
			search_highlight:SetHidden(true)
		end
	end
	ZO_ScrollList_AddDataType(list, ROW_TYPE, "ZO_SelectableLabel", row_height, SetupRow)

	local footer = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
	footer:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 15, -10)
	footer:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -15, -10)
	footer:SetHeight(footer_height - 10)

	local api = { window = win, list = list, footer = footer, toolbar = toolbar, subtitle_lbl = subtitle_lbl }

	local counts_lbl

	local function RowWidth(container, gap)
		local total = 0
		for i = 1, container:GetNumChildren() do
			local child = container:GetChild(i)
			if child ~= counts_lbl and not child:IsHidden() then
				total = total + child:GetWidth() + gap
			end
		end
		return total
	end

	function api:FitToContent()
		local header = 15 + TextWidth(title_lbl) + 12 + TextWidth(subtitle_lbl) + 12 + 42
		local footer_row = RowWidth(footer, 20) + 30
		if counts_lbl and not counts_lbl:IsHidden() then
			local counts_width = TextWidth(counts_lbl) + 20
			if opts.countsInFooter then
				footer_row = footer_row + counts_width
			elseif search_box then
				header = math.max(header, SEARCH_X + SEARCH_W + SEARCH_GAP + counts_width + COUNTS_RIGHT)
			else
				header = header + counts_width
			end
		end
		local needed = math.max(header, footer_row, toolbar and (RowWidth(toolbar, 10) + 45) or 0)
		local room = GuiRoot:GetWidth() - 40
		if needed > room then needed = room end
		if win:GetWidth() < needed then win:SetWidth(needed) end
	end

	function api:FitButtons()
		if self.libaph_buttons_fitted then return end
		self.libaph_buttons_fitted = true
		local function Split(container, gap)
			local buttons, fixed = {}, 0
			for i = 1, container:GetNumChildren() do
				local child = container:GetChild(i)
				if child ~= counts_lbl and not child:IsHidden() then
					local label = child.GetLabelControl and child:GetLabelControl()
					local has_text = label and (label:GetText() or "") ~= ""
					if has_text or child:GetNamedChild("NameLabel") then
						buttons[#buttons + 1] = child
					else
						fixed = fixed + child:GetWidth() + gap
					end
				end
			end
			return buttons, fixed
		end
		local footer_buttons, footer_fixed = Split(footer, 20)
		if #footer_buttons > 0 then
			LibAPH.FitButtonRow(footer, footer_buttons, { gap = 20, room = function()
				local counts = opts.countsInFooter and counts_lbl and not counts_lbl:IsHidden() and (TextWidth(counts_lbl) + 20) or 0
				return footer:GetWidth() - footer_fixed - counts
			end })
		end
		if toolbar then
			local toolbar_buttons, toolbar_fixed = Split(toolbar, 10)
			if #toolbar_buttons > 0 then
				LibAPH.FitButtonRow(toolbar, toolbar_buttons, { gap = 10, font = "ZoFontGameSmall", room = function()
					return toolbar:GetWidth() - toolbar_fixed
				end })
			end
		end
	end

	function api:MeasureRowWidth(text)
		measure_lbl:SetFont(row_font)
		measure_lbl:SetText(text or "")
		return measure_lbl:GetTextWidth()
	end

	function api:SetTitle(text)
		title_lbl:SetText(text)
		self:FitToContent()
	end

	function api:SetSubtitle(text)
		subtitle_lbl:SetText(text or "")
		self:FitToContent()
	end

	function api:SetCounts(text)
		if not text or text == "" then
			if counts_lbl then counts_lbl:SetHidden(true) end
			return
		end
		if not counts_lbl then
			counts_lbl = WINDOW_MANAGER:CreateControl(opts.name and (opts.name .. "Counts") or nil, win, CT_LABEL)
			counts_lbl:SetFont("ZoFontGameSmall")
			counts_lbl:SetColor(0.75, 0.75, 0.75, 1)
			counts_lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
			counts_lbl:SetMaxLineCount(1)
			if opts.countsInFooter then
				counts_lbl:SetAnchor(RIGHT, footer, RIGHT, 0, 0)
			elseif search_box then
				counts_lbl:SetAnchor(RIGHT, win, TOPRIGHT, -COUNTS_RIGHT, 61)
			else
				counts_lbl:SetAnchor(TOPRIGHT, close_btn, TOPLEFT, -10, 7)
				subtitle_lbl:ClearAnchors()
				subtitle_lbl:SetAnchor(TOPLEFT, title_lbl, TOPRIGHT, 12, 3)
				subtitle_lbl:SetAnchor(TOPRIGHT, counts_lbl, TOPLEFT, -12, 0)
			end
			self.counts_lbl = counts_lbl
		end
		counts_lbl:SetText(text)
		counts_lbl:SetHidden(false)
		self:FitToContent()
	end

	function api:SetAllChecked(checked)
		local scrollData = ZO_ScrollList_GetDataList(list)
		for _, entry in ipairs(scrollData) do
			if entry.data.checkable then
				entry.data.checked = checked
				if entry.data.onToggle then entry.data.onToggle(checked) end
			end
		end
		ZO_ScrollList_RefreshVisible(list)
	end

	function api:SetRows(rows)
		ZO_ScrollList_Clear(list)
		local scrollData = ZO_ScrollList_GetDataList(list)
		for index, row in ipairs(rows) do
			row.libaph_row_index = index
			scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, row)
		end
		ZO_ScrollList_Commit(list)
		if list_scroll then list_scroll:Sync() end
	end

	local search_matches = {}
	local search_match_pos = 0

	function api:JumpToSearchMatch(pos)
		if #search_matches == 0 then
			current_search_match_data = nil
			ZO_ScrollList_RefreshVisible(list)
			return
		end
		pos = ((pos - 1) % #search_matches) + 1
		search_match_pos = pos
		local scrollData = ZO_ScrollList_GetDataList(list)
		local i = search_matches[pos]
		current_search_match_data = scrollData[i].data
		ZO_ScrollList_ScrollDataIntoView(list, i)
		ZO_ScrollList_RefreshVisible(list)
	end

	function api:JumpToText(needle)
		needle = string.lower(needle or "")
		search_matches = {}
		if needle ~= "" then
			local scrollData = ZO_ScrollList_GetDataList(list)
			for i, entry in ipairs(scrollData) do
				local data = entry.data
				if data.text and string.find(string.lower(data.text), needle, 1, true) then
					table.insert(search_matches, i)
				end
			end
		end
		search_match_pos = 0
		self:JumpToSearchMatch(1)
	end

	if search_box then
		api.search_box = search_box
		ZO_PostHookHandler(search_box, "OnTextChanged", function()
			if opts.onSearchTextChanged then
				opts.onSearchTextChanged(search_box:GetText())
			else
				api:JumpToText(search_box:GetText())
			end
		end)
		search_box:SetHandler("OnUpArrow", function() api:JumpToSearchMatch(search_match_pos - 1) end)
		search_box:SetHandler("OnDownArrow", function() api:JumpToSearchMatch(search_match_pos + 1) end)
		search_box:SetHandler("OnEnter", function() api:JumpToSearchMatch(search_match_pos + 1) end)
	end

	LibAPH.MakeWindowResizable(win, {
		minWidth = opts.minWidth or 480, minHeight = opts.minHeight or 420,
		maxWidth = opts.maxWidth or 900, maxHeight = opts.maxHeight or 820,
		onResizing = function() ZO_ScrollList_Commit(list) end,
		onResizeStop = function() ZO_ScrollList_Commit(list) end,
	})

	function api:Show()
		self:FitToContent()
		win:SetHidden(false)
		if not SCENE_MANAGER:IsInUIMode() then
			SCENE_MANAGER:SetInUIMode(true)
		end
	end

	function api:Hide()
		win:SetHidden(true)
		local scene_name = SCENE_MANAGER.currentScene and SCENE_MANAGER.currentScene:GetName()
		if (scene_name == "hud" or scene_name == "hudui") and SCENE_MANAGER:IsInUIMode() then
			SCENE_MANAGER:SetInUIMode(false)
		end
	end

	close_btn:SetHandler("OnClicked", function()
		api:Hide()
		if opts.onClose then opts.onClose() end
	end)

	return api
end

function LibAPH.SetWindowActive(window, label, isActive, opts)
	opts = opts or {}
	if not isActive then
		window:SetAlpha(0)
		window:SetMouseEnabled(false)
		label:SetText(opts.emptyText or "")
		if opts.onResize then opts.onResize() end
		return false
	end
	window:SetAlpha(1)
	window:SetMouseEnabled(true)
	return true
end

function LibAPH.RemoveFragmentFromScenes(fragment, sceneNames)
	for _, name in ipairs(sceneNames) do
		local scene = SCENE_MANAGER:GetScene(name)
		if scene and scene:HasFragment(fragment) then
			scene:RemoveFragment(fragment)
		end
	end
end

function LibAPH.AddFragmentToScenes(fragment, sceneNames)
	for _, name in ipairs(sceneNames) do
		local scene = SCENE_MANAGER:GetScene(name)
		if scene then scene:AddFragment(fragment) end
	end
end

local cogwheel_count = 0

function LibAPH.CreateCogwheelButton(parent, name, onClicked, tooltipText)
	cogwheel_count = cogwheel_count + 1
	name = name or ("LibAPH_Cogwheel" .. cogwheel_count)
	if _G[name] then name = name .. "_" .. cogwheel_count end
	local button = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_DropdownButton")
	if not button then return nil end
	button:SetDimensions(28, 28)
	button:SetNormalTexture("esoui/art/chatwindow/chat_options_up.dds")
	button:SetPressedTexture("esoui/art/chatwindow/chat_options_down.dds")
	button:SetMouseOverTexture("esoui/art/chatwindow/chat_options_over.dds")
	if onClicked then button:SetHandler("OnClicked", function() onClicked(button) end) end
	if tooltipText then
		button:SetHandler("OnMouseEnter", function(self)
			InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
			SetTooltipText(InformationTooltip, tooltipText)
		end)
		button:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
	end
	return button
end

function LibAPH.IsScrollableMenuAvailable()
	return type(LibAPH.ShowContextMenu) == "function"
end

function LibAPH.RefreshScrollableMenu()
	if type(LibAPH.RefreshContextMenu) == "function" then LibAPH.RefreshContextMenu() end
end

local arrow_button_count = 0

function LibAPH.CreateToggleArrowButton(parent, name, onToggle, tooltipText)
	arrow_button_count = arrow_button_count + 1
	name = name or ("LibAPH_ToggleArrow" .. arrow_button_count)
	if _G[name] then name = name .. "_" .. arrow_button_count end
	local button = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_TreeButtonArrow")
	if not button then return nil end
	button.libaph_open = false
	button:SetHandler("OnClicked", function(self)
		local wants_open = not self.libaph_open
		local is_open = wants_open
		if onToggle then
			local result = onToggle(wants_open)
			if result ~= nil then is_open = result == true end
		end
		LibAPH.SetToggleArrowOpen(self, is_open)
	end)
	if tooltipText then
		button:SetHandler("OnMouseEnter", function(self)
			InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
			SetTooltipText(InformationTooltip, tooltipText)
		end)
		button:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
	end
	ZO_ToggleButton_SetState(button, TOGGLE_BUTTON_CLOSED)
	return button
end

function LibAPH.SetToggleArrowOpen(button, open)
	if not button then return end
	button.libaph_open = open == true
	ZO_ToggleButton_SetState(button, open and TOGGLE_BUTTON_OPEN or TOGGLE_BUTTON_CLOSED)
end

local DOCK_SNAP_DISTANCE = 24

local function PlaceDocked(win)
	local dock = win.libaph_dock
	local other = dock.other
	win:ClearAnchors()
	if dock.side == "left" then
		win:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, other:GetLeft() - dock.gap, other:GetTop())
	else
		win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, other:GetRight() + dock.gap, other:GetTop())
	end
end

local function SnapSide(win, other, gap)
	if win:GetBottom() < other:GetTop() or win:GetTop() > other:GetBottom() then return nil end
	if math.abs(win:GetLeft() - (other:GetRight() + gap)) <= DOCK_SNAP_DISTANCE then return "right" end
	if math.abs(win:GetRight() - (other:GetLeft() - gap)) <= DOCK_SNAP_DISTANCE then return "left" end
	return nil
end

function LibAPH.DockWindowBeside(win, other, gap, prefer)
	if not win or not other or other:IsHidden() then return false end
	gap = gap or 10
	local width = win:GetWidth()
	local room_left = other:GetLeft() >= width + gap
	local room_right = (GuiRoot:GetWidth() - other:GetRight()) >= width + gap
	local side
	if prefer == "right" then
		side = room_right and "right" or (room_left and "left" or nil)
	else
		side = room_left and "left" or (room_right and "right" or nil)
	end
	win.libaph_dock = { other = other, gap = gap, side = side }
	if side then
		PlaceDocked(win)
	else
		win:ClearAnchors()
		win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	end

	local handler_name = "LibAPH_Dock_" .. tostring(win)
	win:SetHandler("OnMoveStop", function()
		local dock = win.libaph_dock
		if not dock then return end
		dock.side = SnapSide(win, dock.other, dock.gap)
		if dock.side then PlaceDocked(win) end
	end, handler_name)
	other:SetHandler("OnRectChanged", function()
		local dock = win.libaph_dock
		if dock and dock.other == other and dock.side then PlaceDocked(win) end
	end, handler_name)
	return true
end

function LibAPH.ShowScrollableMenu(control, entries, opts)
	if not LibAPH.IsScrollableMenuAvailable() then return false end
	return LibAPH.ShowContextMenu(control, entries, opts)
end

function LibAPH.CloseScrollableMenu()
	if type(LibAPH.CloseContextMenu) == "function" then LibAPH.CloseContextMenu() end
end
