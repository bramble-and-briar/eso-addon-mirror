--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHCR = APHCodeRunnerCore

APHCR.wanted_open = false
APHCR.row_pool = {}
APHCR.list_offset = 0
APHCR.views = {}

local WHEEL_STEP = 48
local SCROLLBAR_SPACE = 18
APHCR.BAR_HIT_WIDTH = 16
local GUTTER_WIDTH = 48
local RELAYOUT_DELAY_MS = 120
local HUGE_INPUT_CHARS = 10000000
APHCR.FONT_SIZES = { 10, 11, 12, 13, 14, 16, 18, 20 }
APHCR.CLOSED_REASON = "APHCodeRunnerClosed"
local SEARCH_HIGHLIGHT = { 1, 0.5, 0.05, 0.55 }

local function Font(size)
	return string.format(IsConsoleUI() and "$(GAMEPAD_MEDIUM_FONT)|%d|soft-shadow-thin" or "$(MEDIUM_FONT)|%d|soft-shadow-thin", size or 14)
end

local function EditorFont()
	return Font(APHCR.sv.font_size)
end

local function ReportInternal(label, err)
	local message = label .. ": " .. tostring(err)
	if APHCR.LogError(0, message) then APHCR.ChatLine(message) end
end

function APHCR.Safe(label, fn)
	return function(...)
		local ok, first, second = pcall(fn, ...)
		if not ok then
			ReportInternal(label, first)
			return
		end
		return first, second
	end
end

function APHCR.On(control, event, fn, label)
	control:SetHandler(event, APHCR.Safe(label or event, fn))
end

function APHCR.Every(name, ms, fn)
	EVENT_MANAGER:RegisterForUpdate(name, ms, APHCR.Safe(name, fn))
end

local function SplitLines(text)
	local lines, count, from = {}, 0, 1
	while true do
		local stop = text:find("\n", from, true)
		count = count + 1
		lines[count] = text:sub(from, stop and (stop - 1) or nil)
		if not stop then break end
		from = stop + 1
	end
	return lines
end

function APHCR.SetStatus(ok, message)
	APHCR.status_lbl:SetColor(ok and 0.4 or 1, ok and 1 or 0.3, 0.4, 1)
	LibAPH.FitLabelText(APHCR.status_lbl, message, { font = Font(13) })
end

function APHCR.RefreshList()
	local max_offset = math.max(#APHCR.files - #APHCR.list_rows, 0)
	APHCR.list_offset = zo_clamp(APHCR.list_offset, 0, max_offset)
	for row_index, row in ipairs(APHCR.list_rows) do
		local file_index = row_index + APHCR.list_offset
		local file = APHCR.files[file_index]
		row.file_index = file_index
		row:SetHidden(file == nil)
		if file then
			local enabled = file.enabled ~= false
			ZO_CheckButton_SetCheckState(row.check, enabled)
			LibAPH.FitLabelText(row.label, string.format("%d. %s", file_index, file.title), { font = Font(13) })
			local color = LibAPH.THEME.TEXT
			if file_index == APHCR.selected then color = LibAPH.THEME.ACCENT elseif not enabled then color = LibAPH.THEME.MUTED end
			row.label:SetColor(unpack(color))
		end
	end
	if APHCR.list_bar then APHCR.list_bar:Update(APHCR.list_offset, max_offset, #APHCR.list_rows / math.max(#APHCR.files, 1)) end
end

function APHCR.RefreshCharCount()
	local count = #(APHCR.files[APHCR.selected] and APHCR.files[APHCR.selected].text or "")
	local limit = APHCR.editor and APHCR.editor.max_chars or APHCR.edit_limit
	APHCR.chars_lbl:SetText(string.format("%d / %d", count, limit))
	APHCR.chars_lbl:SetColor(unpack(count >= limit - 1500 and { 1, 0.35, 0.35, 1 } or LibAPH.THEME.MUTED))
end

function APHCR.MakeButton(name, parent, text, width, onClick)
	local button = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
	button:SetDimensions(width, 26)
	button:SetText(text)
	LibAPH.FitButtonText(button, { font = IsConsoleUI() and "ZoFontGamepad22" or "ZoFontGameBold" })
	APHCR.On(button, "OnClicked", onClick, name)
	return button
end

function APHCR.MakeLabel(parent, text, size, color, name)
	local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
	label:SetFont(Font(size))
	label:SetColor(unpack(color or LibAPH.THEME.TEXT))
	label:SetText(text)
	return label
end

function APHCR.MakeLineEdit(name, parent, ghost, on_changed)
	local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(name .. "BG", parent, "ZO_EditBackdrop")
	backdrop:SetHeight(26)
	local edit = WINDOW_MANAGER:CreateControlFromVirtual(name, backdrop, "ZO_DefaultEditForBackdrop")
	edit:SetFont(Font(13))
	APHCR.On(edit, "OnTextChanged", on_changed, name)
	LibAPH.AddGhostText(edit, ghost)
	return backdrop, edit
end

function APHCR.MakeCombo(name, parent, width, items, selected_index, on_select)
	local container = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
	container:SetDimensions(width, 24)
	local combo = ZO_ComboBox_ObjectFromContainer(container)
	combo:SetSortsItems(false)
	for index, text in ipairs(items) do
		combo:AddItem(combo:CreateItemEntry(text, APHCR.Safe(name, function() on_select(index) end)))
	end
	combo:SelectItemByIndex(selected_index, true)
	LibAPH.UseGreenSelection(combo)
	return container, combo
end

function APHCR.MakeScrollbar(parent, name, anchor_to, opts)
	local THEME = LibAPH.THEME
	local bar = { position = 0, range = 0, fraction = 1, thumb_height = 0, height = 0 }
	local inset = (APHCR.BAR_HIT_WIDTH - THEME.SCROLLBAR_W) / 2
	local drag_event = "APHCodeRunnerDrag" .. name

	local hit = WINDOW_MANAGER:CreateControl(name .. "Bar", parent, CT_CONTROL)
	hit:SetWidth(APHCR.BAR_HIT_WIDTH)
	if opts.inside then
		hit:SetAnchor(TOPRIGHT, anchor_to, TOPRIGHT, -2, 4)
		hit:SetAnchor(BOTTOMRIGHT, anchor_to, BOTTOMRIGHT, -2, -4)
	else
		hit:SetAnchor(TOPLEFT, anchor_to, TOPRIGHT, 2, 0)
		hit:SetAnchor(BOTTOMLEFT, anchor_to, BOTTOMRIGHT, 2, 0)
	end
	hit:SetMouseEnabled(true)
	hit:SetHidden(true)

	local track = WINDOW_MANAGER:CreateControl(name .. "Track", hit, CT_TEXTURE)
	track:SetColor(unpack(THEME.TRACK))
	track:SetWidth(THEME.SCROLLBAR_W)
	track:SetAnchor(TOPRIGHT, hit, TOPRIGHT, -inset, 0)
	track:SetAnchor(BOTTOMRIGHT, hit, BOTTOMRIGHT, -inset, 0)
	local thumb = WINDOW_MANAGER:CreateControl(name .. "Thumb", hit, CT_TEXTURE)
	thumb:SetColor(unpack(THEME.THUMB))
	thumb:SetDrawLevel(2)

	function bar:Update(position, range, fraction)
		self.position, self.range, self.fraction = position, range, fraction
		local height = hit:GetHeight()
		local shown = range > 0 and height > 0
		hit:SetHidden(not shown)
		if not shown then return end
		local thumb_height = zo_clamp(height * fraction, THEME.MIN_THUMB_H, height)
		self.thumb_height, self.height = thumb_height, height
		thumb:SetDimensions(THEME.SCROLLBAR_W, thumb_height)
		thumb:ClearAnchors()
		thumb:SetAnchor(TOPRIGHT, hit, TOPRIGHT, -inset, (height - thumb_height) * (position / range))
	end

	local locked_window
	local function StopDrag()
		hit:SetHandler("OnUpdate", nil)
		EVENT_MANAGER:UnregisterForEvent(drag_event, EVENT_GLOBAL_MOUSE_UP)
		if locked_window then
			locked_window:SetMovable(true)
			locked_window = nil
		end
	end

	APHCR.On(hit, "OnMouseDown", function(_, button)
		if button ~= MOUSE_BUTTON_INDEX_LEFT or bar.range <= 0 then return end
		local _, y = GetUIMousePosition()
		local thumb_top = hit:GetTop() + (bar.height - bar.thumb_height) * (bar.position / bar.range)
		if y >= thumb_top and y <= thumb_top + bar.thumb_height then
			local start_y, start_position = y, bar.position
			locked_window = hit:GetOwningWindow()
			if locked_window then locked_window:SetMovable(false) end
			EVENT_MANAGER:RegisterForEvent(drag_event, EVENT_GLOBAL_MOUSE_UP, APHCR.Safe(name .. " release", StopDrag))
			hit:SetHandler("OnUpdate", APHCR.Safe(name .. " drag", function()
				local _, now_y = GetUIMousePosition()
				local travel = bar.height - bar.thumb_height
				if travel > 0 then opts.set_position(start_position + (now_y - start_y) / travel * bar.range) end
			end))
		elseif y < thumb_top then
			opts.set_position(bar.position - opts.page())
		else
			opts.set_position(bar.position + opts.page())
		end
	end, name .. " bar down")
	APHCR.On(hit, "OnMouseUp", StopDrag, name .. " bar up")
	APHCR.On(hit, "OnMouseWheel", function(_, delta) opts.set_position(bar.position - delta * opts.wheel_step) end, name .. " bar wheel")
	bar.hit = hit
	return bar
end

function APHCR.MakeScrollText(parent, name, opts)
	opts = opts or {}
	local THEME = LibAPH.THEME
	local gutter_width = opts.gutter and GUTTER_WIDTH or 0
	local view = {
		offset = 0, content_height = 0, pitch = 16, text_width = 400,
		loading = false, line_visual = {}, line_rows = {}, max_chars = APHCR.edit_limit,
	}
	APHCR.views[#APHCR.views + 1] = view

	local area = WINDOW_MANAGER:CreateControl(name .. "Area", parent, CT_CONTROL)
	LibAPH.ApplyPanelBackdrop(area, name .. "AreaBG", THEME.INSET)

	local viewport = WINDOW_MANAGER:CreateControl(name .. "View", area, CT_SCROLL)
	viewport:SetAnchor(TOPLEFT, area, TOPLEFT, 8, 8)
	viewport:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, -8 - SCROLLBAR_SPACE, -8)
	viewport:SetMouseEnabled(true)

	local content = WINDOW_MANAGER:CreateControl(name .. "Content", viewport, CT_CONTROL)
	content:SetHeight(100)
	content:SetAnchor(TOPLEFT, viewport, TOPLEFT, 0, 0)
	content:SetAnchor(TOPRIGHT, viewport, TOPRIGHT, 0, 0)

	local gutter
	if opts.gutter then
		gutter = WINDOW_MANAGER:CreateControl(name .. "Gutter", content, CT_LABEL)
		gutter:SetFont(EditorFont())
		gutter:SetColor(0.52, 0.52, 0.52, 1)
		gutter:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		gutter:SetVerticalAlignment(TEXT_ALIGN_TOP)
		gutter:SetMouseEnabled(false)
		gutter:SetWidth(gutter_width - 10)
		gutter:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 0)
	end

	local box = WINDOW_MANAGER:CreateControlFromVirtual(opts.box_name or (name .. "Text"), content, "ZO_DefaultEditMultiLineForBackdrop")
	box:ClearAnchors()
	box:SetAnchor(TOPLEFT, content, TOPLEFT, gutter_width, 0)
	box:SetAnchor(BOTTOMRIGHT, content, BOTTOMRIGHT, 0, 0)
	box:SetFont(EditorFont())
	box:SetMaxInputChars(HUGE_INPUT_CHARS)
	local reported_limit = box:GetMaxInputChars()
	if type(reported_limit) == "number" and reported_limit > 0 then view.max_chars = reported_limit end
	if opts.gutter then APHCR.edit_limit = view.max_chars end
	box:SetSelectionColor(unpack(SEARCH_HIGHLIGHT))
	if opts.read_only then
		box:SetEditEnabled(false)
		box:SetCopyEnabled(true)
	end

	local measure = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
	measure:SetAlpha(0)
	measure:SetMouseEnabled(false)
	measure:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)

	view.area, view.box = area, box
	local bar

	function view:Range()
		return math.max(self.content_height - viewport:GetHeight(), 0)
	end

	function view:UpdateScrollbar()
		if not bar then return end
		local viewport_height = viewport:GetHeight()
		local fraction = self.content_height > 0 and (viewport_height / self.content_height) or 1
		bar:Update(self.offset, self:Range(), fraction)
	end

	function view:SetOffset(value)
		self.offset = zo_clamp(value, 0, self:Range())
		content:ClearAnchors()
		content:SetAnchor(TOPLEFT, viewport, TOPLEFT, 0, -self.offset)
		content:SetAnchor(TOPRIGHT, viewport, TOPRIGHT, 0, -self.offset)
		self:UpdateScrollbar()
	end

	local function Wheel(_, delta) view:SetOffset(view.offset - delta * WHEEL_STEP) end
	APHCR.On(box, "OnMouseWheel", Wheel, name .. " wheel")
	APHCR.On(viewport, "OnMouseWheel", Wheel, name .. " view wheel")
	bar = APHCR.MakeScrollbar(area, name, viewport, {
		set_position = function(value) view:SetOffset(value) end,
		page = function() return math.max(viewport:GetHeight() - view.pitch * 2, view.pitch) end,
		wheel_step = WHEEL_STEP,
	})

	function view:UpdateGutter()
		if not gutter then return end
		local marks = opts.marks and opts.marks() or {}
		local numbers = {}
		for line, rows in ipairs(self.line_rows) do
			numbers[#numbers + 1] = marks[line] and ("|cFF5555" .. line .. "|r") or tostring(line)
			for _ = 2, rows do numbers[#numbers + 1] = " " end
		end
		gutter:SetFont(EditorFont())
		gutter:SetText(table.concat(numbers, "\n"))
	end

	function view:ComputeLines(text)
		local lines = SplitLines(text)
		local index = 0
		self.line_visual, self.line_rows = {}, {}
		for line_number, line in ipairs(lines) do
			local rows = 1
			if line ~= "" and measure:GetStringWidth(line) / GetUIGlobalScale() > self.text_width then
				measure:SetText(line)
				rows = math.max(1, math.floor(measure:GetTextHeight() / self.pitch + 0.5))
			end
			self.line_visual[line_number] = index
			self.line_rows[line_number] = rows
			index = index + rows
		end
		self.visual_lines = index
	end

	function view:Relayout()
		local font = EditorFont()
		self.text_width = math.max(50, viewport:GetWidth() - gutter_width)
		measure:SetFont(font)
		measure:SetWidth(self.text_width)
		measure:SetText("Ag")
		self.pitch = math.max(measure:GetTextHeight(), 1)
		local text = box:GetText():gsub("[\r\t]", "")
		measure:SetText(text)
		local wrapped_height = measure:GetTextHeight()
		self:ComputeLines(text)
		self.content_height = math.max(math.max(wrapped_height, self.visual_lines * self.pitch) + self.pitch * 2, viewport:GetHeight())
		content:SetHeight(self.content_height)
		self:UpdateGutter()
		self:SetOffset(self.offset)
	end

	function view:SetText(text, keep_scroll, force)
		if not force and box:GetText() == text then return end
		local previous_offset = self.offset
		self.loading = true
		if self.history then
			self.history:RunSilently(function() box:SetText(text) end)
		else
			box:SetText(text)
		end
		self.loading = false
		self:Relayout()
		self:SetOffset(keep_scroll and previous_offset or 0)
	end

	function view:ApplyFont()
		box:SetFont(EditorFont())
		self:Relayout()
	end

	function view:ScrollToLine(line)
		local visual = self.line_visual[line] or (line - 1)
		self:SetOffset(math.max(0, (visual - 3) * self.pitch))
	end

	function view:ReplaceText(text, cursor)
		self.loading = true
		box:SetText(text)
		self.loading = false
		box:SetCursorPosition(cursor)
		if opts.on_change then opts.on_change(text) end
		self:OnEdited()
	end

	function view:HighlightLine(line)
		local text = box:GetText()
		local start, current = 1, 1
		while current < line do
			local newline = text:find("\n", start, true)
			if not newline then break end
			start = newline + 1
			current = current + 1
		end
		local stop = (text:find("\n", start, true) or (#text + 1)) - 1
		if text:sub(stop, stop) == "\r" then stop = stop - 1 end
		box:SetCursorPosition(start - 1)
		box:SetSelection(start - 1, math.max(stop, start - 1))
		self:ScrollToLine(line)
	end

	function view:KeepCursorVisible()
		local cursor = box:GetCursorPosition()
		local before = box:GetText():sub(1, cursor):gsub("[\r\t]", "")
		measure:SetFont(EditorFont())
		measure:SetWidth(self.text_width)
		measure:SetText(before .. "x")
		local caret_top = measure:GetTextHeight() - self.pitch
		local viewport_height = viewport:GetHeight()
		if caret_top < self.offset then
			self:SetOffset(caret_top)
		elseif caret_top + self.pitch * 2 > self.offset + viewport_height then
			self:SetOffset(caret_top + self.pitch * 2 - viewport_height)
		end
	end

	local relayout_timer = name .. "Relayout"
	function view:OnEdited()
		APHCR.Every(relayout_timer, RELAYOUT_DELAY_MS, function()
			EVENT_MANAGER:UnregisterForUpdate(relayout_timer)
			self:Relayout()
			if opts.follow_cursor then self:KeepCursorVisible() end
			if opts.after_edit then opts.after_edit(self) end
		end)
	end

	APHCR.On(box, "OnTextChanged", function(self)
		if view.loading then return end
		if opts.on_change then opts.on_change(self:GetText()) end
		view:OnEdited()
	end, name .. " text changed")
	APHCR.On(viewport, "OnRectChanged", function() view:Relayout() end, name .. " resize")
	if opts.undo then view.history = LibAPH.EnableUndoRedo(box) end
	return view
end

function APHCR.AttachSearch(input, status, target, scroll_to_line)
	local search_pos = 1
	local function Search(forward)
		local needle = input:GetText():lower()
		if needle == "" then
			status:SetText("")
			return
		end
		local haystack = target:GetText():lower()
		local total, index_of, pos = 0, {}, 1
		while true do
			local found = haystack:find(needle, pos, true)
			if not found then break end
			total = total + 1
			index_of[found] = total
			pos = found + 1
		end
		if total == 0 then
			status:SetColor(1, 0.4, 0.4, 1)
			status:SetText("No matches")
			return
		end
		local match_start, match_end
		if forward then
			match_start, match_end = haystack:find(needle, search_pos, true)
			if not match_start then match_start, match_end = haystack:find(needle, 1, true) end
		else
			pos = 1
			local wrap_start, wrap_end
			while true do
				local found, found_end = haystack:find(needle, pos, true)
				if not found then break end
				if found < search_pos then match_start, match_end = found, found_end end
				wrap_start, wrap_end = found, found_end
				pos = found + 1
			end
			if not match_start then match_start, match_end = wrap_start, wrap_end end
		end
		target:SetCursorPosition(match_start - 1)
		target:SetSelection(match_start - 1, match_end)
		local _, newlines = haystack:sub(1, match_start):gsub("\n", "")
		scroll_to_line(newlines + 1)
		search_pos = forward and (match_end + 1) or match_start
		status:SetColor(0.6, 1, 0.6, 1)
		status:SetText(string.format("%d/%d", index_of[match_start], total))
	end
	APHCR.On(input, "OnEnter", function() Search(not IsShiftKeyDown()) end, "search enter")
	APHCR.On(input, "OnUpArrow", function() Search(false) end, "search up")
	APHCR.On(input, "OnDownArrow", function() Search(true) end, "search down")
	return function()
		search_pos = 1
		status:SetText("")
	end
end
