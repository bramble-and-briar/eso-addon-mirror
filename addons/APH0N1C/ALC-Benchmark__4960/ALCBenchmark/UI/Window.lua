--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local view, FONT_FACE, FONT_SIZE, tabs, THEME, SCREEN_EDGE = AB.view, AB.FONT_FACE, AB.FONT_SIZE, AB.tabs, AB.THEME, AB.SCREEN_EDGE
local TLC, Font, PAD, DrawTimeline, tl, SummaryLines = AB.TLC, AB.Font, AB.PAD, AB.DrawTimeline, AB.tl, AB.SummaryLines
local Lines, LABEL_W, VALUE_W, STATUS_H, HEADER_H, FIT = AB.Lines, AB.LABEL_W, AB.VALUE_W, AB.STATUS_H, AB.HEADER_H, AB.FIT
local MAX_COLUMNS, MIN_SCALE, MAX_SCALE, SCROLL_H, cells, UI = AB.MAX_COLUMNS, AB.MIN_SCALE, AB.MAX_SCALE, AB.SCROLL_H, AB.cells, AB.UI
local PAGE_NAMES, Pad, PAGES, WIN, TITLE_BAR, Label = AB.PAGE_NAMES, AB.Pad, AB.PAGES, AB.WIN, AB.TITLE_BAR, AB.Label
local ROWS, HEADER_LINES, MIN_FONT, MAX_FONT = AB.ROWS, AB.HEADER_LINES, AB.MIN_FONT, AB.MAX_FONT

local WRAP_SLACK = 8
local NOTE_WRAP_SHARE = 0.94
local NOTE_ROW_SHARE = 1.1
local WRAP_LIMIT = 4000
local NOTE_SIDE_MIN = 320
local NOTE_GAP = 20
local BAR_W = 4
local BAR_GAP = 3
local PAD_SCROLL_LINES = 3
local BAR_TRACK = { 1, 1, 1, 0.08 }
local BAR_THUMB = { 1, 1, 1, 0.45 }
local wrap = { text = {}, lines = {}, size = 0 }

local function Measure()
	if not AB.measure then
		AB.measure = WINDOW_MANAGER:CreateControl(WIN .. "Measure", AB.win, CT_LABEL)
		AB.measure:SetFont(FONT_FACE .. "|" .. FONT_SIZE .. "|soft-shadow-thin")
		AB.measure:SetHidden(true)
	end
	return AB.measure
end

local function Wrap(text, width)
	if text == nil or text == "" then return "", 1 end
	local texts = wrap.text[width]
	if not texts then
		texts = {}
		wrap.text[width], wrap.lines[width] = texts, {}
	end
	local done = texts[text]
	if done then return done, wrap.lines[width][text] end
	if wrap.size >= WRAP_LIMIT then
		wrap.text, wrap.lines, wrap.size = {}, {}, 0
		return Wrap(text, width)
	end
	local wrapped, count = LibAPH.WrapText(Measure(), text, width)
	texts[text], wrap.lines[width][text], wrap.size = wrapped, count, wrap.size + 1
	return wrapped, count
end

local widest = { text = {}, size = 0 }

local function Widest(text)
	local known = widest.text[text]
	if known then return known end
	if widest.size >= WRAP_LIMIT then widest.text, widest.size = {}, 0 end
	local measure, most = Measure(), 0
	for part in (text .. "\n"):gmatch("(.-)\n") do
		local width = measure:GetStringWidth((part:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))) / GetUIGlobalScale()
		if width > most then most = width end
	end
	widest.text[text], widest.size = most, widest.size + 1
	return most
end

local function CellWidth(c, col_w)
	return (c == 1 and (view.label_w or LABEL_W) or col_w[c - 1] or VALUE_W) - 6 - WRAP_SLACK
end

local function NoteLines(width)
	local list = {}
	for line in (view.notes .. "\n"):gmatch("(.-)\n") do
		if line == "" then
			list[#list + 1] = ""
		else
			local wrapped = Wrap(line, width)
			for part in (wrapped .. "\n"):gmatch("(.-)\n") do list[#list + 1] = part end
		end
	end
	return list
end

local function Snap(scale)
	return zo_clamp(math.floor(FONT_SIZE * scale + 1e-6), MIN_FONT, MAX_FONT) / FONT_SIZE
end

local function ScrollBar(top, max_top, fit_lines, content, x, y, height)
	if not AB.vtrack then
		AB.vtrack = WINDOW_MANAGER:CreateControl(WIN .. "RowTrack", AB.win, CT_TEXTURE)
		AB.vtrack:SetColor(BAR_TRACK[1], BAR_TRACK[2], BAR_TRACK[3], BAR_TRACK[4])
		AB.vthumb = WINDOW_MANAGER:CreateControl(WIN .. "RowThumb", AB.win, CT_TEXTURE)
		AB.vthumb:SetColor(BAR_THUMB[1], BAR_THUMB[2], BAR_THUMB[3], BAR_THUMB[4])
	end
	local shown = max_top > 0
	AB.vtrack:SetHidden(not shown)
	AB.vthumb:SetHidden(not shown)
	if not shown then return end
	local thumb_h = math.max(height * fit_lines / content, BAR_W * 3)
	AB.vtrack:ClearAnchors()
	AB.vtrack:SetAnchor(TOPLEFT, AB.win, TOPLEFT, x, y)
	AB.vtrack:SetDimensions(BAR_W, height)
	AB.vthumb:ClearAnchors()
	AB.vthumb:SetAnchor(TOPLEFT, AB.win, TOPLEFT, x, y + (height - thumb_h) * top / max_top)
	AB.vthumb:SetDimensions(BAR_W, thumb_h)
end

local function WindowSize(first_w, first_h)
	local max_w = GuiRoot:GetWidth() - SCREEN_EDGE * 2
	local max_h = GuiRoot:GetHeight() - SCREEN_EDGE * 2
	local size = AB.saved.window
	if not (size and size.w and size.h) then
		size = AB.saved.window or {}
		size.w, size.h = math.floor(first_w + 0.5), math.floor(first_h + 0.5)
		AB.saved.window = size
	end
	if view.resizing then return AB.win:GetWidth(), AB.win:GetHeight() end
	return zo_clamp(size.w, FIT.min_w, max_w), zo_clamp(size.h, FIT.min_h, max_h)
end

local function Draw()
	if not AB.win or AB.win:IsHidden() then return false end
	local page = view.page or "results"
	for name, tab in pairs(tabs) do
		local color = name == page and THEME.ACCENT or THEME.MUTED
		tab:SetColor(color[1], color[2], color[3], 1)
	end
	if page == "timeline" then
		local w, h = WindowSize(TLC.w, TLC.h)
		AB.scale = 1
		AB.title:SetFont(Font())
		AB.status:SetFont(Font())
		AB.status:SetWidth(w - PAD * 2)
		if not view.resizing then AB.win:SetDimensions(w, h) end
		DrawTimeline(w, h)
		return true
	end
	if tl.area then tl.area:SetHidden(true) end
	local lines, count, data_cols
	if page == "summary" then
		lines, count, data_cols = SummaryLines()
	elseif page == "loading" then
		lines, count, data_cols = AB.LOAD.Lines()
	else
		lines, count = Lines()
		data_cols = math.max(1, #view.columns)
		view.notes, view.notes_lines = nil, 0
	end
	local col_w = view.col_w or {}
	view.col_w = col_w
	for d = 1, data_cols do col_w[d] = VALUE_W end
	for d = data_cols + 1, #col_w do col_w[d] = nil end
	if page == "summary" or page == "loading" then
		for i = 1, count do
			for c, text in pairs(lines[i]) do
				if type(c) == "number" and c > 1 and text ~= "" and col_w[c - 1] then
					local need = Widest(text) + 6 + WRAP_SLACK
					if need > col_w[c - 1] then col_w[c - 1] = math.min(math.ceil(need), VALUE_W * FIT.max_widen) end
				end
			end
		end
	end
	local label_base = LABEL_W
	for i = 1, count do
		local text = lines[i][1]
		if text and text ~= "" then
			local need = Widest(text) + 6 + WRAP_SLACK
			if need > label_base then label_base = math.min(math.ceil(need), LABEL_W * FIT.max_widen) end
		end
	end
	view.label_w = label_base
	local all_w = 0
	for d = 1, data_cols do all_w = all_w + col_w[d] end
	local natural_w = PAD * 2 + label_base + all_w
	local row_lines = view.row_lines or {}
	view.row_lines = row_lines
	local total_lines, lines_sig = 0, all_w + label_base
	for i = 1, count do
		local most = 1
		for c, text in pairs(lines[i]) do
			if type(c) == "number" and text ~= "" then
				local _, used = Wrap(text, CellWidth(c, col_w))
				if used > most then most = used end
			end
		end
		row_lines[i] = most
		total_lines, lines_sig = total_lines + most, lines_sig + i * most
	end
	for i = count + 1, #row_lines do row_lines[i] = nil end
	local note_rows = view.notes_lines or 0
	local has_notes = note_rows > 0 and view.notes ~= nil and view.notes ~= ""
	local note_lines, note_side, note_x, note_w = nil, false, PAD, 0
	local status_rows = view.status_rows or 1
	local function StatusH() return STATUS_H + (status_rows - 1) * (FONT_SIZE + 5) end
	local function BodyLines(share)
		local notes = note_rows * (share or 1)
		if note_side then return math.max(total_lines, notes) end
		return total_lines + notes + (note_rows > 0 and 1 or 0)
	end
	local function UnitH() return StatusH() + BodyLines(NOTE_ROW_SHARE) * (FONT_SIZE + 5) end
	local function Notes(width_px, scale)
		note_lines = NoteLines(math.max(math.floor(width_px / scale * NOTE_WRAP_SHARE) - WRAP_SLACK, 40))
		note_rows = #note_lines
	end
	local unit_h = UnitH()
	local natural_h = HEADER_H + PAD + unit_h
	local w, h = WindowSize(natural_w, natural_h)
	local most = math.min(data_cols, MAX_COLUMNS - 1)
	local start = zo_clamp(view.first or 1, 1, data_cols)
	local function Fit(room_h, cap)
		local fit = zo_clamp(math.min((room_h - HEADER_H - PAD) / unit_h, (w - PAD * 2) / (label_base + all_w), cap or MAX_SCALE), MIN_SCALE, MAX_SCALE)
		fit = Snap(fit)
		local room, k, first = w + 1 - PAD * 2 - label_base * fit, 0, start
		for d = start, data_cols do
			if k >= most or (k >= 1 and room < col_w[d] * fit) then break end
			room, k = room - col_w[d] * fit, k + 1
		end
		while first > 1 and k < most and room >= col_w[first - 1] * fit do
			first, k, room = first - 1, k + 1, room - col_w[first - 1] * fit
		end
		return fit, math.max(k, 1), first
	end
	local visible, scrolling, fit_w, first_col
	for pass = 1, 3 do
		unit_h = UnitH()
		AB.scale, visible, first_col = Fit(h)
		scrolling = visible < data_cols
		if scrolling then
			AB.scale, visible, first_col = Fit(h - SCROLL_H)
			scrolling = visible < data_cols
		end
		fit_w = w
		local _, rows_needed = Wrap(view.status or "", math.max(math.floor((fit_w - PAD * 2) / AB.scale) - WRAP_SLACK, 40))
		local status_changed = rows_needed ~= status_rows
		status_rows = rows_needed
		if has_notes then Notes(fit_w - PAD * 2, AB.scale) end
		if pass == 3 or (not has_notes and not status_changed) then break end
	end
	if has_notes and (page == "summary" or page == "loading") and not scrolling and data_cols <= most then
		local side_cap = (w - PAD * 2 - NOTE_GAP) / (label_base + all_w + NOTE_SIDE_MIN)
		if side_cap >= MIN_SCALE then
			local below_scale = AB.scale
			note_side = true
			local scale = Snap(math.min(below_scale, side_cap))
			for _ = 1, 2 do
				Notes(w - PAD * 2 - NOTE_GAP - (label_base + all_w) * scale, scale)
				unit_h = UnitH()
				scale = Snap(zo_clamp(math.min((h - HEADER_H - PAD) / unit_h, side_cap), MIN_SCALE, MAX_SCALE))
			end
			if Snap(side_cap) < scale then scale = Snap(side_cap) end
			if scale >= below_scale then
				AB.scale, visible, first_col = scale, data_cols, 1
				note_x = PAD + (label_base + all_w) * AB.scale + NOTE_GAP
				note_w = w - PAD - note_x
				Notes(note_w, AB.scale)
			else
				note_side = false
				Notes(fit_w - PAD * 2, AB.scale)
			end
		end
	end
	if has_notes and not note_side then note_w = fit_w - PAD * 2 end
	unit_h = UnitH()
	view.status_rows = status_rows
	view.notes_side = note_side
	local status_h = StatusH() * AB.scale
	local row_h = (FONT_SIZE + 5) * AB.scale
	local label_w = label_base * AB.scale
	local fit_h = h
	view.max_first = data_cols - visible + 1
	view.first = zo_clamp(first_col or view.first or 1, 1, view.max_first)
	local shown_cols = 1 + visible
	local body_top = HEADER_H + status_h
	local body_h = h - body_top - PAD / 2 - (scrolling and SCROLL_H or 0)
	local fit_lines = math.max(math.floor(body_h / row_h), 1)
	local head_lines = count > 0 and (row_lines[1] or 1) or 0
	local content = BodyLines()
	local max_top = math.max(content - fit_lines, 0)
	view.max_top = max_top
	view.top = zo_clamp(view.top or 0, 0, max_top)
	local top = view.top
	local font = Font()
	local relayout = AB.laid_out.scale ~= AB.scale or AB.laid_out.columns ~= shown_cols or AB.laid_out.count ~= count or AB.laid_out.w ~= w or AB.laid_out.h ~= h or AB.laid_out.lines ~= lines_sig or AB.laid_out.page ~= page or AB.laid_out.notes ~= note_rows or AB.laid_out.status ~= status_rows or AB.laid_out.top ~= top or AB.laid_out.side ~= note_side
	if relayout then
		AB.laid_out.status, AB.laid_out.top, AB.laid_out.side = status_rows, top, note_side
		AB.laid_out.scale, AB.laid_out.columns, AB.laid_out.count, AB.laid_out.w, AB.laid_out.h, AB.laid_out.lines = AB.scale, shown_cols, count, w, h, lines_sig
		AB.laid_out.page, AB.laid_out.notes = page, note_rows
		AB.title:SetFont(font)
		AB.status:SetFont(font)
		AB.status:SetWidth(fit_w - PAD * 2)
	end
	AB.status:SetMaxLineCount(status_rows)
	AB.status:SetText((Wrap(view.status or "", math.max(math.floor((fit_w - PAD * 2) / AB.scale) - WRAP_SLACK, 40))))
	local above = 0
	for i = 1, #cells do
		local line = i <= count and lines[i] or nil
		local rows = row_lines[i] or 1
		local at = i == 1 and 0 or above - top
		local in_view = line ~= nil and (i == 1 or (at >= head_lines and at + rows <= fit_lines))
		local x = label_w
		for c = 1, MAX_COLUMNS do
			local cell = cells[i][c]
			local hidden = not in_view or c > shown_cols
			local column = (c == 1 or (line and line.sticky)) and c or view.first + c - 1
			local cell_w = c == 1 and label_w or (col_w[column - 1] or VALUE_W) * AB.scale
			if relayout then
				cell:SetHidden(hidden)
				if not hidden then
					cell:SetFont(font)
					cell:SetMaxLineCount(rows)
					cell:ClearAnchors()
					cell:SetAnchor(TOPLEFT, AB.win, TOPLEFT, PAD + (c == 1 and 0 or x), body_top + at * row_h)
					cell:SetWidth(cell_w - 6)
				end
			end
			if not hidden then
				local shown = Wrap(line[column] or "", CellWidth(column, col_w))
				cell:SetText(shown)
			end
			if c > 1 then x = x + cell_w end
		end
		if line then above = above + rows end
	end
	AB.scroller:SetHidden(not scrolling)
	if scrolling then
		AB.scroller:SetMinMax(1, view.max_first)
		AB.scroller:SetValue(view.first)
	end
	local first_note, last_note, note_at
	if has_notes and note_lines then
		local base = note_side and 0 or total_lines + 1
		local floor_at = note_side and 0 or head_lines
		for j = 1, #note_lines do
			local at = base + j - 1 - top
			if at >= floor_at and at < fit_lines then
				first_note = first_note or j
				note_at = note_at or at
				last_note = j
			end
		end
	end
	AB.notes:SetHidden(first_note == nil)
	if first_note then
		AB.notes:SetFont(font)
		AB.notes:SetMaxLineCount(last_note - first_note + 1)
		AB.notes:SetText(table.concat(note_lines, "\n", first_note, last_note))
		AB.notes:ClearAnchors()
		AB.notes:SetAnchor(TOPLEFT, AB.win, TOPLEFT, note_side and note_x or PAD, body_top + note_at * row_h)
		AB.notes:SetWidth(note_w)
	end
	ScrollBar(top, max_top, fit_lines, content, w - BAR_W - BAR_GAP, body_top, fit_lines * row_h)
	if (relayout or AB.laid_out.scrolling ~= scrolling) and not view.resizing then
		AB.laid_out.scrolling = scrolling
		AB.win:SetDimensions(fit_w, fit_h)
	end
	return true
end

function UI.ScrollRows(delta)
	if not view.max_top or view.max_top <= 0 then return false end
	local top = zo_clamp((view.top or 0) + delta, 0, view.max_top)
	if top ~= view.top then
		view.top = top
		Draw()
	end
	return true
end

function UI.SetWindowStatus(text)
	view.status = text or ""
	if not (AB.win and AB.status) or AB.win:IsHidden() then return end
	if (view.page or "results") == "timeline" then return Draw() end
	local width = math.max(math.floor((AB.status:GetWidth() or 0) / AB.scale) - WRAP_SLACK, 40)
	local wrapped, rows = Wrap(view.status, width)
	if rows ~= (view.status_rows or 1) then return Draw() end
	AB.status:SetText(wrapped)
end
AB.WrapCell = Wrap

function UI.SetPage(page)
	if not PAGE_NAMES[page] then return end
	view.page = page
	view.top = 0
	AB.saved.page = page
	AB.laid_out = {}
	Draw()
	if Pad.Refresh then Pad.Refresh() end
end

function UI.StepPage(delta)
	local current = 1
	for index, page in ipairs(PAGES) do if page == (view.page or "results") then current = index end end
	UI.SetPage(PAGES[(current - 1 + delta) % #PAGES + 1])
	return true
end

function UI.ZoomTimeline(delta)
	if view.page ~= "timeline" then return false end
	view.tl_zoom = zo_clamp((view.tl_zoom or 1) + delta, 1, #TLC.zooms)
	Draw()
	return true
end

function UI.MoveCursor(delta)
	if view.page ~= "timeline" then return false end
	local total = tl.Total()
	if total == 0 then return false end
	local cursor = zo_clamp((view.tl_cursor or 1) + delta, 1, total)
	if cursor == view.tl_cursor then return false end
	view.tl_cursor = cursor
	Draw()
	return true
end

function UI.ScrollColumns(delta)
	if not view.max_first or view.max_first <= 1 then return false end
	local first = zo_clamp((view.first or 1) + delta, 1, view.max_first)
	if first ~= view.first then
		view.first = first
		Draw()
	end
	return true
end

UI.Draw = Draw

local function SaveSize()
	AB.saved.window = AB.saved.window or {}
	AB.saved.window.w, AB.saved.window.h = math.floor(AB.win:GetWidth() + 0.5), math.floor(AB.win:GetHeight() + 0.5)
end

local function Build()
	if AB.win then return AB.win end
	AB.win = WINDOW_MANAGER:CreateTopLevelWindow(WIN)
	AB.win:SetClampedToScreen(true)
	AB.win:SetMouseEnabled(true)
	AB.win:SetMovable(true)
	AB.win:SetHidden(true)
	AB.win:SetDrawTier(DT_HIGH)
	LibAPH.ApplyPanelBackdrop(AB.win, WIN .. "BG", THEME.BG_HUD)
	local header = LibAPH.CreateHeaderStrip(AB.win, WIN .. "Header", HEADER_H)
	header:SetColor(TITLE_BAR[1], TITLE_BAR[2], TITLE_BAR[3], TITLE_BAR[4])
	AB.title = Label(AB.win, "Title")
	AB.title:SetText("|c" .. THEME.TITLE_HEX .. "ALC Benchmark|r")
	AB.title:SetAnchor(LEFT, AB.win, TOPLEFT, PAD, HEADER_H / 2)
	AB.status = Label(AB.win, "Status")
	AB.status:SetColor(THEME.MUTED[1], THEME.MUTED[2], THEME.MUTED[3], 1)
	AB.status:SetAnchor(TOPLEFT, AB.win, TOPLEFT, PAD, HEADER_H + 2)
	LibAPH.CreateThemedCloseButton(AB.win, WIN .. "Close", function() UI.Hide() end, 4, 2)
	AB.scroller = WINDOW_MANAGER:CreateControlFromVirtual(WIN .. "Scroll", AB.win, "ZO_Slider")
	AB.scroller:SetAnchor(BOTTOMLEFT, AB.win, BOTTOMLEFT, PAD, -4)
	AB.scroller:SetAnchor(BOTTOMRIGHT, AB.win, BOTTOMRIGHT, -PAD, -4)
	AB.scroller:SetHeight(16)
	AB.scroller:SetValueStep(1)
	AB.scroller:SetHidden(true)
	AB.scroller:SetHandler("OnValueChanged", function(_, value)
		local first = zo_round(value)
		if view.page == "timeline" then
			if first ~= view.tl_from then
				local shift = first - (view.tl_from or 1)
				view.tl_from = first
				view.tl_cursor = (view.tl_cursor or 1) + shift
				Draw()
			end
		elseif first ~= view.first then
			view.first = first
			Draw()
		end
	end)
	AB.win:SetHandler("OnMouseWheel", function(_, delta)
		if view.page == "timeline" then return UI.ZoomTimeline(delta > 0 and 1 or -1) end
		if (view.max_top or 0) > 0 and not IsShiftKeyDown() then return UI.ScrollRows(delta > 0 and -PAD_SCROLL_LINES or PAD_SCROLL_LINES) end
		UI.ScrollColumns(delta > 0 and -1 or 1)
	end)
	local right = -36
	for index = #PAGES, 1, -1 do
		local page = PAGES[index]
		local tab = Label(AB.win, "Tab" .. PAGE_NAMES[page])
		tab:SetText(PAGE_NAMES[page])
		tab:SetMouseEnabled(true)
		tab:SetAnchor(RIGHT, AB.win, TOPRIGHT, right, HEADER_H / 2)
		tab:SetHandler("OnMouseUp", function(_, button, upInside) if upInside and button == MOUSE_BUTTON_INDEX_LEFT then UI.SetPage(page) end end)
		tabs[page] = tab
		local width = tab:GetTextWidth()
		right = right - (type(width) == "number" and width or 60) - 16
	end
	AB.notes = Label(AB.win, "Notes")
	AB.notes:SetColor(THEME.TEXT[1], THEME.TEXT[2], THEME.TEXT[3], 1)
	AB.notes:SetHidden(true)
	tl.area = WINDOW_MANAGER:CreateControl(WIN .. "Timeline", AB.win, CT_CONTROL)
	tl.area:SetMouseEnabled(true)
	tl.area:SetHidden(true)
	tl.area:SetHandler("OnMouseWheel", function(_, delta) UI.ZoomTimeline(delta > 0 and 1 or -1) end)
	tl.area:SetHandler("OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT and UI.OpenMenu then UI.OpenMenu() end
	end)
	tl.area:SetHandler("OnMouseEnter", function(area)
		area:SetHandler("OnUpdate", function()
			local total = tl.Total()
			if total == 0 or not view.tl_span then return end
			local x = GetUIMousePosition() - area:GetLeft() - (tl.plot_x or TLC.axis_w)
			local plot_w = tl.plot_w or (area:GetWidth() - TLC.axis_w)
			if plot_w <= 0 then return end
			local second = zo_clamp(math.floor((view.tl_from or 1) + x / plot_w * view.tl_span), 1, total)
			if second ~= view.tl_cursor then
				view.tl_cursor = second
				Draw()
			end
		end)
	end)
	tl.area:SetHandler("OnMouseExit", function(area) area:SetHandler("OnUpdate", nil) end)
	for i = 1, #ROWS + 1 do
		cells[i] = {}
		for c = 1, MAX_COLUMNS do
			cells[i][c] = Label(AB.win, "Row" .. i .. string.char(96 + c))
			if i == 1 then cells[i][c]:SetMaxLineCount(HEADER_LINES) end
		end
	end
	LibAPH.MakeWindowResizable(AB.win, {
		handleSize = 8, minWidth = FIT.min_w, minHeight = FIT.min_h,
		onResizing = function() view.resizing = true SaveSize() Draw() end,
		onResizeStop = function() view.resizing = nil AB.laid_out = {} SaveSize() Draw() Pad.Refresh() end,
	})
	AB.mover = LibAPH.CreateGamepadMover(AB.win)
	AB.resizer = LibAPH.CreateGamepadResizer(AB.win, {
		minWidth = 240, minHeight = 200,
		onResizing = function() view.resizing = true SaveSize() Draw() Pad.Refresh() end,
		onResizeStop = function() view.resizing = nil AB.laid_out = {} SaveSize() Draw() Pad.Refresh() end,
	})
	AB.position = LibAPH.CreateWindowPosition(AB.win, {
		get = function()
			local spot = AB.saved.window or {}
			return spot.x, spot.y, spot.point
		end,
		set = function(x, y, point)
			AB.saved.window = AB.saved.window or {}
			AB.saved.window.x, AB.saved.window.y, AB.saved.window.point = x, y, point
		end,
		placeDefault = function(control)
			control:ClearAnchors()
			control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
		end,
		mover = AB.mover,
	})
	AB.win:SetHandler("OnMoveStop", function() AB.position:Save() end)
	AB.win:SetHandler("OnMouseUp", function(_, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT and UI.OpenMenu then UI.OpenMenu() end
	end)
	AB.sticky = LibAPH.CreateStickyFragment(AB.win, { "hud", "hudui" })
	return AB.win
end

function UI.Show()
	if not UI.IsShown() then Pad.dismissed = false end
	Build()
	view.page = view.page or AB.saved.page or "results"
	AB.position:Apply()
	AB.sticky:Open()
	Draw()
	Pad.Refresh()
	if Pad.Ensure then Pad.Ensure() end
end

function UI.Hide()
	if not AB.win then return end
	Pad.Stop(true)
	AB.sticky:Close()
	if AB.mover then AB.mover:ToggleGamepadMove(false) end
	if AB.resizer then AB.resizer:ToggleGamepadResize(false) end
end

function UI.IsShown()
	return AB.win ~= nil and AB.sticky:IsOpen()
end

function UI.LiveSet(columns, compare, text)
	local page = view.page or "results"
	local same = AB.test and UI.live_index == AB.test.index and UI.live_state == AB.test.state
	if page ~= "results" and same then
		view.columns, view.compare, view.status = columns, compare or {}, text or ""
		if page == "summary" then UI.SetWindowStatus(view.status) end
		return
	end
	if AB.test then UI.live_index, UI.live_state = AB.test.index, AB.test.state end
	UI.Set(columns, compare, text)
end

function UI.Set(columns, compare, text)
	view.columns, view.compare, view.status = columns, compare or {}, text or ""
	Draw()
end
AB.Build = Build
