--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore
local THEME = LibAPH.THEME

local NAME = "APHProfilerLoadTimes"
local PAD = 12
local HEADER_H = 30
local DRAW_LEVEL = 9100
local TEXT_LEVEL = 10
local BASE_FONT = 14
local PAD_BASE_FONT = 18
local MIN_FONT, MAX_FONT = 10, 30
local NATURAL_W, NATURAL_H = 560, 520
local MIN_W, MIN_H = 360, 260
local TYPE_W, TIME_W = 90, 110
local LINE_SPACING = 1.35
local STATUS_LINES = 3
local WHEEL_ROWS = 3
local BAR_W, BAR_GAP = 4, 3
local ROW_TINT = { 1, 1, 1, 0.035 }
local BAR_TRACK = { 1, 1, 1, 0.08 }
local BAR_THUMB = { 1, 1, 1, 0.45 }
local TEXT = { 0.85, 0.85, 0.85, 1 }
local SORTS = { "time", "name", "order" }
local SORT_TEXT = { time = "LOAD_SORT_TIME", name = "LOAD_SORT_NAME", order = "LOAD_SORT_ORDER" }
local SHOWS = { "all", "addons", "libraries", "game" }
local SHOW_TEXT = { all = "LOAD_SHOW_ALL", addons = "LOAD_SHOW_ADDONS", libraries = "LOAD_SHOW_LIBRARIES", game = "LOAD_SHOW_GAME" }

local win, title_lbl, status_lbl, heads, track, thumb
local rows = {}
local top = 0
local visible_rows = 0
local shown_count = 0

local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end

local function FontSize()
	local base = IsPad() and PAD_BASE_FONT or BASE_FONT
	if not win then return base end
	local size = math.floor(base * win:GetWidth() / NATURAL_W + 1e-6)
	return zo_clamp(size, MIN_FONT, MAX_FONT)
end

local function Font(size)
	local face = IsConsoleUI() and "$(GAMEPAD_MEDIUM_FONT)" or "$(MEDIUM_FONT)"
	return string.format("%s|%d|soft-shadow-thin", face, size)
end

local function Label(name, parent, color)
	local lbl = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
	local c = color or TEXT
	lbl:SetColor(c[1], c[2], c[3], c[4] or 1)
	lbl:SetMaxLineCount(1)
	lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	if LibAPH.RaiseLabel then LibAPH.RaiseLabel(lbl, { level = TEXT_LEVEL, backdrop = false }) end
	return lbl
end

local function Rect(name, color)
	local tex = WINDOW_MANAGER:CreateControl(name, win, CT_TEXTURE)
	tex:SetColor(color[1], color[2], color[3], color[4])
	return tex
end

local function Saved(key, list)
	local value = APHP.saved[key]
	for _, known in ipairs(list) do
		if known == value then return value end
	end
	return list[1]
end

local function TimeText(entry)
	if entry.unmeasured then return APHP.L("LOAD_NOT_MEASURED") end
	local ms = entry.ms
	if ms < 1 then return APHP.L("LOAD_UNDER_1_MS") end
	return string.format("|c%s%s|r", APHP.SeverityColor(ms), APHP.Format(ms))
end

local function ByTime(a, b)
	local x, y = a.unmeasured and -1 or a.ms, b.unmeasured and -1 or b.ms
	if x == y then return a.order < b.order end
	return x > y
end

local function ByName(a, b)
	local x, y = string.lower(a.name), string.lower(b.name)
	if x == y then return a.order < b.order end
	return x < y
end

local function ByOrder(a, b) return a.order < b.order end

local SORTERS = { time = ByTime, name = ByName, order = ByOrder }

local function Kind(row)
	if row.game then return "game" end
	return row.library and "libraries" or "addons"
end

local function ShownRows(data)
	local show = Saved("load_show", SHOWS)
	local list = {}
	for _, row in ipairs(data.rows) do
		if show == "all" or show == Kind(row) then list[#list + 1] = row end
	end
	table.sort(list, SORTERS[Saved("load_sort", SORTS)])
	return list
end

local function Row(index)
	local row = rows[index]
	if row then return row end
	local prefix = NAME .. "Row" .. index
	row = {
		tint = Rect(prefix .. "Tint", ROW_TINT),
		name = Label(prefix .. "Name", win),
		kind = Label(prefix .. "Type", win, THEME.MUTED),
		time = Label(prefix .. "Time", win),
	}
	row.time:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	row.name:SetMouseEnabled(true)
	row.name:SetHandler("OnMouseEnter", function(control)
		if control.aphp_tip then APHP.ShowTip(control, control.aphp_tip, win) end
	end)
	row.name:SetHandler("OnMouseExit", function() APHP.HideTip() end)
	rows[index] = row
	return row
end

local function HideRow(row)
	row.tint:SetHidden(true)
	row.name:SetHidden(true)
	row.kind:SetHidden(true)
	row.time:SetHidden(true)
end

local function Place(label, x, y, width, font)
	label:SetFont(font)
	label:ClearAnchors()
	label:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
	label:SetWidth(width)
	label:SetHidden(false)
end

local COUNT_KINDS = { "addons", "libraries", "game" }
local COUNT_TEXT = {
	addons = { "LOAD_COUNT_ADDON", "LOAD_COUNT_ADDONS" },
	libraries = { "LOAD_COUNT_LIBRARY", "LOAD_COUNT_LIBRARIES" },
	game = { "LOAD_COUNT_GAME", "LOAD_COUNT_GAME" },
}

local function StatusText(data, list)
	if not data then return APHP.L("LOAD_NOTHING_YET") end
	local counts, total = { addons = 0, libraries = 0, game = 0 }, 0
	for _, row in ipairs(list) do
		local kind = Kind(row)
		counts[kind] = counts[kind] + 1
		if not row.unmeasured then total = total + (row.ms or 0) end
	end
	local show = Saved("load_show", SHOWS)
	local parts = {}
	for _, kind in ipairs(COUNT_KINDS) do
		if show == kind or (show == "all" and counts[kind] > 0) then
			local keys = COUNT_TEXT[kind]
			parts[#parts + 1] = string.format(APHP.L(counts[kind] == 1 and keys[1] or keys[2]), counts[kind])
		end
	end
	if #parts == 0 then parts[1] = string.format(APHP.L("LOAD_COUNT_ADDONS"), 0) end
	local text = string.format(APHP.L("LOAD_STATUS"), table.concat(parts, ", "), APHP.Format(total))
	if not IsPad() then text = text .. "  " .. APHP.L("LOAD_MOUSE_HINT") end
	return text
end

local function Draw()
	if not win or win:IsHidden() then return false end
	local data = APHP.GetLoadTimes()
	local list = data and ShownRows(data) or {}
	shown_count = #list
	local size = FontSize()
	local font = Font(size)
	local scale = size / (IsPad() and PAD_BASE_FONT or BASE_FONT)
	local row_h = math.ceil(size * LINE_SPACING)
	local w, h = win:GetWidth(), win:GetHeight()
	local inner = w - PAD * 2 - BAR_W - BAR_GAP

	title_lbl:SetFont(Font(math.max(size + 2, MIN_FONT)))
	status_lbl:SetFont(font)
	status_lbl:SetWidth(w - PAD * 2)
	status_lbl:SetText(StatusText(data, list))
	local status_h = math.min(status_lbl:GetTextHeight() or row_h, row_h * STATUS_LINES)
	local y = HEADER_H + PAD / 2 + status_h + PAD / 2

	local time_w, type_w = TIME_W * scale, TYPE_W * scale
	local name_w = math.max(inner - time_w - type_w, 40)
	Place(heads.name, PAD, y, name_w, font)
	Place(heads.kind, PAD + name_w, y, type_w, font)
	Place(heads.time, PAD + name_w + type_w, y, time_w, font)
	heads.name:SetHidden(data == nil)
	heads.kind:SetHidden(data == nil)
	heads.time:SetHidden(data == nil)
	y = y + row_h

	visible_rows = math.max(math.floor((h - y - PAD / 2) / row_h), 1)
	local max_top = math.max(#list - visible_rows, 0)
	top = zo_clamp(top, 0, max_top)
	local used = 0
	for slot = 1, visible_rows do
		local entry = list[top + slot]
		if entry then
			used = slot
			local row = Row(slot)
			local row_y = y + (slot - 1) * row_h
			row.tint:ClearAnchors()
			row.tint:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, row_y)
			row.tint:SetDimensions(inner, row_h)
			row.tint:SetHidden((top + slot) % 2 == 1)
			Place(row.name, PAD, row_y, name_w - 6, font)
			LibAPH.FitLabelText(row.name, entry.name, { font = font, minSize = MIN_FONT, width = name_w - 6 })
			row.name.aphp_tip = string.format(APHP.L(entry.unmeasured and "LOAD_ROW_TIP_FIRST" or "LOAD_ROW_TIP"), entry.title or entry.name, entry.order)
			Place(row.kind, PAD + name_w, row_y, type_w - 6, font)
			row.kind:SetText(APHP.L(entry.game and "LOAD_GAME" or entry.library and "LOAD_LIBRARY" or "LOAD_ADDON"))
			Place(row.time, PAD + name_w + type_w, row_y, time_w, font)
			row.time:SetText(TimeText(entry))
		end
	end
	for slot = used + 1, #rows do HideRow(rows[slot]) end

	track:SetHidden(max_top == 0)
	thumb:SetHidden(max_top == 0)
	if max_top > 0 then
		local track_h = visible_rows * row_h
		local thumb_h = math.max(track_h * visible_rows / #list, BAR_W * 3)
		track:ClearAnchors()
		track:SetAnchor(TOPLEFT, win, TOPLEFT, w - PAD - BAR_W, y)
		track:SetDimensions(BAR_W, track_h)
		thumb:ClearAnchors()
		thumb:SetAnchor(TOPLEFT, win, TOPLEFT, w - PAD - BAR_W, y + (track_h - thumb_h) * top / max_top)
		thumb:SetDimensions(BAR_W, thumb_h)
	end
	return true
end

local function SaveSize()
	APHP.saved.load_w, APHP.saved.load_h = win:GetWidth(), win:GetHeight()
end

local function Resized()
	SaveSize()
	Draw()
	if APHP.RefreshPadHints then APHP.RefreshPadHints() end
end

local function Build()
	win = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	win:SetClampedToScreen(true)
	win:SetMouseEnabled(true)
	win:SetMovable(true)
	win:SetDrawTier(DT_HIGH)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetDrawLevel(DRAW_LEVEL)
	win:SetHidden(true)
	win:SetDimensions(APHP.saved.load_w or NATURAL_W, APHP.saved.load_h or NATURAL_H)
	LibAPH.MakeWindowResizable(win, { handleSize = 8, minWidth = MIN_W, minHeight = MIN_H, onResizing = Resized, onResizeStop = Resized })
	win:SetHandler("OnMoveStop", function()
		APHP.saved.load_x, APHP.saved.load_y = win:GetLeft(), win:GetTop()
	end)
	win:SetHandler("OnMouseUp", function(control, button, upInside)
		if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then APHP.OpenLoadTimesMenu(control) end
	end)
	win:SetHandler("OnMouseWheel", function(_, delta) APHP.ScrollLoadTimes(delta > 0 and -WHEEL_ROWS or WHEEL_ROWS) end)

	LibAPH.ApplyPanelBackdrop(win, NAME .. "BG", THEME.BG)
	LibAPH.CreateHeaderStrip(win, NAME .. "Header", HEADER_H)
	title_lbl = Label(NAME .. "Title", win)
	title_lbl:SetText("|c9CD04CAPH-Profiler|r  " .. APHP.L("LOAD_TIMES"))
	title_lbl:SetAnchor(LEFT, win, TOPLEFT, PAD, HEADER_H / 2)
	LibAPH.CreateThemedCloseButton(win, NAME .. "Close", function() APHP.HideLoadTimes() end, 4, 2)

	status_lbl = Label(NAME .. "Status", win, THEME.MUTED)
	status_lbl:SetMaxLineCount(STATUS_LINES)
	status_lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	status_lbl:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, HEADER_H + PAD / 2)

	heads = {
		name = Label(NAME .. "HeadName", win, THEME.ACCENT),
		kind = Label(NAME .. "HeadType", win, THEME.ACCENT),
		time = Label(NAME .. "HeadTime", win, THEME.ACCENT),
	}
	heads.name:SetText(APHP.L("LOAD_HEAD_ADDON"))
	heads.kind:SetText(APHP.L("LOAD_HEAD_TYPE"))
	heads.time:SetText(APHP.L("LOAD_HEAD_TIME"))
	heads.time:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

	track = Rect(NAME .. "Track", BAR_TRACK)
	thumb = Rect(NAME .. "Thumb", BAR_THUMB)

	win:ClearAnchors()
	if APHP.saved.load_x and APHP.saved.load_y then
		win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, APHP.saved.load_x, APHP.saved.load_y)
	else
		win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	end

	APHP.load_mover = LibAPH.CreateGamepadMover(win)
	APHP.load_mover:RegisterCallback(APHP.name .. "_LoadTimes", 2, function(pos)
		if type(pos.left) == "number" then APHP.saved.load_x = pos.left end
		if type(pos.top) == "number" then APHP.saved.load_y = pos.top end
		if APHP.OnPadStickStopped then APHP.OnPadStickStopped() end
	end)
	APHP.load_resizer = LibAPH.CreateGamepadResizer(win, {
		minWidth = MIN_W,
		minHeight = MIN_H,
		onResizing = Resized,
		onResizeStop = function()
			SaveSize()
			if APHP.OnPadStickStopped then APHP.OnPadStickStopped() end
		end,
	})
	APHP.load_sticky = LibAPH.CreateStickyFragment(win, { "hud", "hudui" })
end

function APHP.OpenLoadTimesAfterScan()
	APHP.Print(APHP.L("LOAD_TIMES_READY"), true)
	if IsPad() then APHP.StartPadControl() end
	return APHP.ShowLoadTimes()
end

function APHP.GetLoadTimesWindow() return win end

function APHP.IsLoadTimesShown()
	return win ~= nil and not win:IsHidden()
end

function APHP.ShowLoadTimes()
	if not win then Build() end
	if APHP.IsTimelineShown and APHP.IsTimelineShown() then APHP.HideTimeline() end
	APHP.HideTip()
	APHP.load_sticky:Open()
	Draw()
	if APHP.RefreshPadHints then APHP.RefreshPadHints() end
	return true
end

function APHP.HideLoadTimes()
	if not win then return false end
	APHP.HideTip()
	APHP.load_mover:ToggleGamepadMove(false)
	APHP.load_resizer:ToggleGamepadResize(false)
	APHP.load_sticky:Close()
	if APHP.RefreshPadHints then APHP.RefreshPadHints() end
	if APHP.IsHudFocused and APHP.IsHudFocused() then APHP.RefreshHud() end
	return true
end

function APHP.ToggleLoadTimes()
	if APHP.IsLoadTimesShown() then return APHP.HideLoadTimes() end
	return APHP.ShowLoadTimes()
end

function APHP.ScrollLoadTimes(delta)
	if not APHP.IsLoadTimesShown() then return false end
	top = top + delta
	Draw()
	return true
end

function APHP.LoadTimesPage()
	return math.max(visible_rows - 1, 1)
end

function APHP.LoadTimesRowCount()
	return shown_count
end

function APHP.RefreshLoadTimes()
	return Draw()
end

local function Pick(key, value)
	APHP.saved[key] = value
	top = 0
	Draw()
end

function APHP.BuildLoadTimesMenuEntries()
	local entries = { { text = APHP.L("LOAD_TIMES"), header = true } }
	local sort, show = Saved("load_sort", SORTS), Saved("load_show", SHOWS)
	for _, key in ipairs(SORTS) do
		local text = APHP.L(SORT_TEXT[key])
		entries[#entries + 1] = { text = key == sort and ("|c66FF66" .. text .. "|r") or text, onClick = function() Pick("load_sort", key) end }
	end
	entries[#entries + 1] = { divider = true }
	for _, key in ipairs(SHOWS) do
		local text = APHP.L(SHOW_TEXT[key])
		entries[#entries + 1] = { text = key == show and ("|c66FF66" .. text .. "|r") or text, onClick = function() Pick("load_show", key) end }
	end
	entries[#entries + 1] = { divider = true }
	entries[#entries + 1] = { text = APHP.L("CLOSE_LOAD_TIMES"), onClick = function() APHP.HideLoadTimes() end }
	return entries
end

function APHP.OpenLoadTimesMenu(control)
	if not APHP.IsLoadTimesShown() then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		LibAPH.CloseContextMenu()
		if APHP.RefreshPadHints then APHP.RefreshPadHints() end
		return true
	end
	APHP.ShowMenu(control or win, APHP.BuildLoadTimesMenuEntries, win)
	if APHP.IsHudFocused() and IsPad() then LibAPH.MoveContextMenuFocus(1) end
	if APHP.RefreshPadHints then APHP.RefreshPadHints() end
	return true
end
